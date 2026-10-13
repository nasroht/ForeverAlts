-- ============================================================================
-- CLIAlts: Retro Alt Tracker
-- File: core.lua
-- Event dispatcher, slash commands, auto-tracking on login, and background ticker.
-- ============================================================================

local addonName, addonTable = ...
local CLIAlts = addonTable

-- ----------------------------------------------------------------------------
-- Chat Output Helper
-- ----------------------------------------------------------------------------
function CLIAlts:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66[CLIAlts]|r %s", msg or ""))
end

local SafeAfter = CLIAlts.SafeAfter or function(delay, callback)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, callback)
    end
end

local hasRequestedRaidInfo = false

-- ----------------------------------------------------------------------------
-- Event Handler Frame
-- ----------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")

local safeEvents = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_LOGOUT",
    "PLAYER_CAMPING",
    "PLAYER_QUITING",
    "LOGOUT_CANCEL",
    "PLAYER_XP_UPDATE",
    "UPDATE_EXHAUSTION",
    "PLAYER_MONEY",
    "PLAYER_LEVEL_UP",
    "PLAYER_UPDATE_RESTING",
    "ZONE_CHANGED_NEW_AREA",
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "SKILL_LINES_CHANGED",
    "SPELLS_CHANGED",
    "CHAT_MSG_SKILL",
    "TRADE_SKILL_SHOW",
    "TRADE_SKILL_UPDATE",
    "CRAFT_SHOW",
    "CRAFT_UPDATE",
    "UPDATE_INSTANCE_INFO",
    "BANKFRAME_CLOSED",
    "MAIL_INBOX_UPDATE",
    "MAIL_SHOW",
}
for _, ev in ipairs(safeEvents) do
    pcall(function() eventFrame:RegisterEvent(ev) end)
end

local ok = pcall(eventFrame.RegisterEvent, eventFrame, "BAG_UPDATE_DELAYED")
if not ok then pcall(eventFrame.RegisterEvent, eventFrame, "BAG_UPDATE") end

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" then
        local loaded = (arg1 or ""):lower()
        if not arg1 or loaded == (addonName or ""):lower() or loaded == "clialts" then
            CLIAlts:InitDB()
            CLIAlts:CacheCurrentPlayer()
            CLIAlts:CreateMinimapButton()
            CLIAlts:CreateMainFrame()
            CLIAlts:ApplyTheme()
        end

    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        CLIAlts:InitDB()
        CLIAlts:CacheCurrentPlayer()
        CLIAlts:CreateMinimapButton()
        CLIAlts:CreateMainFrame()
        CLIAlts:ApplyTheme()
        CLIAlts.isPlayerResting = (IsResting and IsResting() and true or false)

        -- Self-calibrating rested model check against last clean logout
        CLIAlts:CalibrateRestedModel()

        -- Record daily gold history snapshot (capped at 90 days)
        CLIAlts:RecordGoldSnapshot()

        -- Scan watchlist item counts across bags & bank
        CLIAlts:UpdateWatchCounts()

        -- Immediate snapshot
        local char = CLIAlts:CollectCurrentCharacter(false, true)
        if char and not self.hasAnnounced then
            self.hasAnnounced = true
            local coloredName = CLIAlts:ColorizePlayerName(char.name, char.classFile)
            local summary = CLIAlts:GetAccountSummary()
            CLIAlts:Print(string.format("Tracking %s (Level %d %s). Total tracked: %d. Type |cff00ff66/clialts|r to view.",
                coloredName, char.level or 1, CLIAlts:FormatRaceClass(char), summary.totalAlts or 1))

            -- Alert if any alts are rested capped (Rested Waste Tracker)
            CLIAlts:CheckCappedAltsAlert()

            -- Alert if mail expires in <= 3 days on any alt
            CLIAlts:CheckMailExpiryAlert()
        end

        -- Request raid/instance lockouts ONCE per session 2s after entering the world
        if event == "PLAYER_ENTERING_WORLD" and not hasRequestedRaidInfo then
            hasRequestedRaidInfo = true
            SafeAfter(2.0, function()
                if RequestRaidInfo then pcall(RequestRaidInfo) end
            end)
        end

        -- Delayed sync after 1.5s, 3.0s, and 5.0s to ensure server-synced money, XP, and resting state
        SafeAfter(1.5, function()
            CLIAlts.isPlayerResting = (IsResting and IsResting() and true or false)
            CLIAlts:UpdateWatchCounts()
            CLIAlts:CollectCurrentCharacter()
            CLIAlts:RequestRender()
        end)

        SafeAfter(3.0, function()
            CLIAlts.isPlayerResting = (IsResting and IsResting() and true or false)
            CLIAlts:UpdateWatchCounts()
            CLIAlts:CollectCurrentCharacter()
            CLIAlts:RequestRender()
        end)

        SafeAfter(5.0, function()
            CLIAlts.isPlayerResting = (IsResting and IsResting() and true or false)
            CLIAlts:UpdateWatchCounts()
            CLIAlts:CollectCurrentCharacter()
            CLIAlts:RequestRender()
        end)

        CLIAlts:RequestRender()

    elseif event == "PLAYER_LOGOUT" then
        -- Final snapshot before logout
        CLIAlts.isPlayerResting = (IsResting and IsResting() and true or false)
        CLIAlts:CollectCurrentCharacter(true)

    elseif event == "PLAYER_CAMPING" or event == "PLAYER_QUITING" then
        -- Camping / logout countdown initiated
        CLIAlts.isPlayerResting = (IsResting and IsResting() and true or false)
        CLIAlts:CollectCurrentCharacter(true)

    elseif event == "LOGOUT_CANCEL" then
        -- Logout cancelled
        CLIAlts.isPlayerResting = (IsResting and IsResting() and true or false)
        CLIAlts:CollectCurrentCharacter(false, true)

    elseif event == "PLAYER_UPDATE_RESTING" then
        CLIAlts.isPlayerResting = (IsResting and IsResting() and true or false)
        CLIAlts:CollectCurrentCharacter(false)
        CLIAlts:RequestRender()

    elseif event == "PLAYER_XP_UPDATE" or event == "UPDATE_EXHAUSTION" or event == "PLAYER_LEVEL_UP" then
        CLIAlts:CollectCurrentCharacter()
        CLIAlts:RequestRender()

    elseif event == "PLAYER_MONEY" then
        CLIAlts:CollectCurrentCharacter()
        CLIAlts:RequestRender()

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        CLIAlts:CollectCurrentCharacter()
        SafeAfter(1.0, function()
            CLIAlts:CollectCurrentCharacter(false, true)
            CLIAlts:RequestRender()
        end)

    elseif event == "SKILL_LINES_CHANGED" or event == "SPELLS_CHANGED" or event == "CHAT_MSG_SKILL" or event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" or event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then
        CLIAlts:CollectCurrentCharacter()
        CLIAlts:RequestRender()

    elseif event == "UPDATE_INSTANCE_INFO" then
        CLIAlts:CollectCurrentCharacter()
        CLIAlts:RequestRender()

    elseif event == "BAG_UPDATE_DELAYED" or event == "BAG_UPDATE" or event == "BANKFRAME_CLOSED" then
        CLIAlts:UpdateWatchCounts()
        CLIAlts:RequestRender()

    elseif event == "MAIL_INBOX_UPDATE" or event == "MAIL_SHOW" then
        CLIAlts:ScanMailInbox()
        CLIAlts:RequestRender()
    end
end)

local function SafeStrTrim(str)
    if strtrim then return strtrim(str) end
    return (str or ""):match("^%s*(.-)%s*$") or ""
end

local function SafeStrSplit(delim, text)
    if strsplit then return strsplit(delim, text) end
    local first, rest = text:match("^(%S+)%s*(.*)$")
    return first or text, rest or ""
end

local function SlashHandler(msg)
    msg = SafeStrTrim(msg):lower()
    local cmd, arg = SafeStrSplit(" ", msg)

    if cmd == "" then
        CLIAlts:CollectCurrentCharacter()
        CLIAlts:Toggle()

    elseif cmd == "1" or cmd == "2" or cmd == "3" or cmd == "4" or cmd == "5" or cmd == "tab" then
        local tabId = tonumber(cmd)
        if cmd == "tab" and arg and arg ~= "" then
            tabId = tonumber(arg)
        end
        if tabId and tabId >= 1 and tabId <= 5 then
            if CLIAltsDB and CLIAltsDB.settings then
                CLIAltsDB.settings.activeTab = tabId
            end
            CLIAlts:CollectCurrentCharacter()
            CLIAlts:Toggle(true)
            if CLIAlts.SetPage then CLIAlts:SetPage(1) end
            CLIAlts:Render()
        else
            CLIAlts:Print("Usage: |cff00ff66/clialts [1-5]|r (Switches to specified tab)")
        end

    elseif cmd == "next" then
        CLIAlts:PrintNextAlts()

    elseif cmd == "watch" then
        if arg and arg ~= "" then
            CLIAlts:AddWatchItem(arg)
            CLIAlts:CollectWatchlistCounts()
            CLIAlts:RequestRender()
        else
            CLIAlts:Print("Usage: |cff00ff66/clialts watch <Item Name or ID>|r")
        end

    elseif cmd == "unwatch" then
        if arg and arg ~= "" then
            CLIAlts:RemoveWatchItem(arg)
            CLIAlts:RequestRender()
        else
            CLIAlts:Print("Usage: |cff00ff66/clialts unwatch <Item Name>|r")
        end

    elseif cmd == "watchlist" then
        CLIAlts:PrintWatchlist()

    elseif cmd == "export" or cmd == "csv" then
        CLIAlts:Toggle(true)
        CLIAlts:ShowExportPopup()

    elseif cmd == "filter" or cmd == "find" then
        CLIAlts:Toggle(true)
        if CLIAlts.SetFilter then
            CLIAlts:SetFilter(arg)
        end

    elseif cmd == "clear" then
        if CLIAlts.SetFilter then
            CLIAlts:SetFilter(nil)
        end
        CLIAlts:Print("Active filter cleared.")

    elseif cmd == "calibrate" then
        CLIAlts:CalibrateRestedModel()

    elseif cmd == "show" then
        CLIAlts:CollectCurrentCharacter()
        CLIAlts:Toggle(true)

    elseif cmd == "track" or cmd == "save" or cmd == "scan" then
        local char = CLIAlts:CollectCurrentCharacter()
        if char then
            local summary = CLIAlts:GetAccountSummary()
            CLIAlts:Print(string.format("Recorded %s. Total characters tracked: %d.", char.name, summary.totalAlts))
        end

    elseif cmd == "hide" then
        CLIAlts:Toggle(false)

    elseif cmd == "minimap" then
        CLIAlts:ToggleMinimap()
        local state = CLIAltsDB.settings.minimapShow and "visible" or "hidden"
        CLIAlts:Print(string.format("Minimap icon is now %s.", state))

    elseif cmd == "reset" then
        if CLIAltsDB and CLIAltsDB.settings then
            CLIAltsDB.settings.windowPos = nil
        end
        if CLIAltsMainFrame then
            CLIAltsMainFrame:ClearAllPoints()
            CLIAltsMainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        CLIAlts:Print("Window position reset to center.")

    elseif cmd == "scale" then
        if arg and arg ~= "" then
            local clean = arg:gsub("%%", "")
            local val = tonumber(clean)
            if val then
                if val > 5 then val = val / 100 end
                CLIAlts:SetScale(val)
                CLIAlts:Print(string.format("UI scale set to %.2fx (%d%%).", val, math.floor(val * 100 + 0.5)))
            else
                CLIAlts:Print("Usage: |cff00ff66/clialts scale <0.7 - 1.8>|r (e.g. 1.2 or 120%)")
            end
        else
            CLIAlts:CycleScale()
        end

    elseif cmd == "font" or cmd == "fontsize" then
        if arg and arg ~= "" then
            local sz = tonumber(arg)
            if sz and sz >= 12 and sz <= 22 then
                CLIAlts:SetFontSize(sz)
                CLIAlts:Print(string.format("Terminal font size set to %dpx.", sz))
            else
                CLIAlts:Print("Usage: |cff00ff66/clialts font <12-22>|r")
            end
        else
            local cur = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.fontSize) or 15
            CLIAlts:Print(string.format("Current font size: %dpx. Usage: |cff00ff66/clialts font <12-22>|r", cur))
        end

    elseif cmd == "gold" then
        local summary = CLIAlts:GetAccountSummary()
        local moneyStr = CLIAlts:FormatMoney(summary.totalGold, true)
        CLIAlts:Print(string.format("Total Account Wealth: %s across %d alts.", moneyStr, summary.totalAlts))

    elseif cmd == "perk" or cmd == "wellrested" then
        if arg and arg ~= "" then
            local rank = tonumber(arg)
            if rank and rank >= 0 and rank <= 5 then
                CLIAlts:SetWellRestedRank(rank)
            else
                CLIAlts:Print("Usage: |cff00ff66/CLIAlts perk <0-5>|r (Sets your Well Rested perk rank)")
            end
        else
            CLIAlts:CycleWellRestedPerk()
        end

    elseif cmd == "rested" then
        local r = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.wellRestedRank) or 0
        CLIAlts:Print(string.format("--- Rested XP Summary (Well Rested Perk: Rank %d/5 +%d%%) ---", r, r * 4))
        local chars = CLIAlts:GetCharactersList("rested", false)
        for _, char in ipairs(chars) do
            local rested = CLIAlts:GetRestedData(char)
            local coloredName = CLIAlts:ColorizePlayerName(char.name, char.classFile)
            if rested and not rested.isMaxLevel then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  * %s (Lvl %d): %s %d%% - %s (%s)",
                    coloredName, char.level or 1, rested.statusStr, rested.percent, rested.timeLeftStr, rested.fullDate))
            else
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  * %s (Lvl %d): [ MAX LEVEL ]", coloredName, char.level or 1))
            end
        end

    elseif cmd == "help" then
        CLIAlts:ShowHelpPopup()

    else
        CLIAlts:Print("Unknown command. Type |cff00ff66/clialts help|r for available options.")
    end
end

SLASH_CLIALTS1 = "/clialts"
SLASH_CLIALTS2 = "/cli"
SLASH_CLIALTS3 = "/ca"
SlashCmdList["CLIALTS"] = SlashHandler
