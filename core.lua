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

local function SafeAfter(delay, callback)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, callback)
        return
    end
    local timerFrame = CreateFrame("Frame")
    local elapsed = 0
    timerFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            callback()
        end
    end)
end

-- ----------------------------------------------------------------------------
-- Event Handler Frame
-- ----------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_CAMPING")
eventFrame:RegisterEvent("PLAYER_QUITING")
eventFrame:RegisterEvent("LOGOUT_CANCEL")
eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
eventFrame:RegisterEvent("UPDATE_EXHAUSTION")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")

if TRADE_SKILL_SHOW then
    eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
end
if TRADE_SKILL_UPDATE then
    eventFrame:RegisterEvent("TRADE_SKILL_UPDATE")
end

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" then
        local loaded = (arg1 or ""):lower()
        if not arg1 or loaded == (addonName or ""):lower() or loaded == "clialts" or loaded == "nasalts" then
            CLIAlts:InitDB()
            CLIAlts:CreateMinimapButton()
            CLIAlts:CreateMainFrame()
            CLIAlts:ApplyTheme()
        end

    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        CLIAlts:InitDB()
        CLIAlts:CreateMinimapButton()
        CLIAlts:CreateMainFrame()
        CLIAlts:ApplyTheme()
        CLIAlts.isPlayerResting = (IsResting and IsResting() and true or false)

        -- Immediate snapshot
        local char = CLIAlts:CollectCurrentCharacter()
        if char and not self.hasAnnounced then
            self.hasAnnounced = true
            local coloredName = CLIAlts:ColorizePlayerName(char.name, char.classFile)
            local summary = CLIAlts:GetAccountSummary()
            CLIAlts:Print(string.format("Tracking %s (Level %d %s). Total tracked: %d. Type |cff00ff66/clialts|r to view.",
                coloredName, char.level or 1, CLIAlts:FormatRaceClass(char), summary.totalAlts or 1))
        end

        -- Delayed sync after 1.5s and 3.0s to ensure server-synced money, XP, and resting state
        SafeAfter(1.5, function()
            CLIAlts.isPlayerResting = (IsResting and IsResting() and true or false)
            CLIAlts:CollectCurrentCharacter()
            if CLIAltsMainFrame and CLIAltsMainFrame:IsShown() then
                CLIAlts:Render()
            end
        end)

        SafeAfter(3.0, function()
            CLIAlts.isPlayerResting = (IsResting and IsResting() and true or false)
            CLIAlts:CollectCurrentCharacter()
            if CLIAltsMainFrame and CLIAltsMainFrame:IsShown() then
                CLIAlts:Render()
            end
        end)

        if CLIAltsMainFrame and CLIAltsMainFrame:IsShown() then
            CLIAlts:Render()
        end

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
        CLIAlts:CollectCurrentCharacter(false)

    elseif event == "PLAYER_UPDATE_RESTING" then
        CLIAlts.isPlayerResting = (IsResting and IsResting() and true or false)
        CLIAlts:CollectCurrentCharacter(false)
        if CLIAltsMainFrame and CLIAltsMainFrame:IsShown() then
            CLIAlts:Render()
        end

    elseif event == "PLAYER_XP_UPDATE" or event == "UPDATE_EXHAUSTION" or event == "PLAYER_LEVEL_UP" then
        CLIAlts:CollectCurrentCharacter()
        if CLIAltsMainFrame and CLIAltsMainFrame:IsShown() then
            CLIAlts:Render()
        end

    elseif event == "PLAYER_MONEY" then
        CLIAlts:CollectCurrentCharacter()
        if CLIAltsMainFrame and CLIAltsMainFrame:IsShown() then
            CLIAlts:Render()
        end

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        CLIAlts:CollectCurrentCharacter()
        SafeAfter(1.0, function()
            CLIAlts:CollectCurrentCharacter()
            if CLIAltsMainFrame and CLIAltsMainFrame:IsShown() then
                CLIAlts:Render()
            end
        end)

    elseif event == "SKILL_LINES_CHANGED" or event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
        CLIAlts:CollectCurrentCharacter()
        if CLIAltsMainFrame and CLIAltsMainFrame:IsShown() then
            CLIAlts:Render()
        end
    end
end)

-- ----------------------------------------------------------------------------
-- Periodic Refresh Ticker (Every 60s to keep offline resting countdowns fresh)
-- ----------------------------------------------------------------------------
local tickerElapsed = 0
local tickerFrame = CreateFrame("Frame")
tickerFrame:SetScript("OnUpdate", function(self, elapsed)
    tickerElapsed = tickerElapsed + elapsed
    if tickerElapsed >= 60 then
        tickerElapsed = 0
        if CLIAltsMainFrame and CLIAltsMainFrame:IsShown() then
            CLIAlts:Render()
        end
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
        if CLIAltsMainFrame then
            CLIAltsMainFrame:ClearAllPoints()
            CLIAltsMainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            CLIAlts:Print("Window position reset to center.")
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
SLASH_CLIALTS4 = "/alts"
SLASH_CLIALTS5 = "/nasalts"
SLASH_CLIALTS6 = "/nas"
SlashCmdList["CLIALTS"] = SlashHandler
SlashCmdList["NASALTS"] = SlashHandler
