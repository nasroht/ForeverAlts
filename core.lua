-- ============================================================================
-- ForeverAlts: Retro Alt Tracker
-- File: core.lua
-- Event dispatcher, slash commands, auto-tracking on login, and background ticker.
-- ============================================================================

local addonName, addonTable = ...
local ForeverAlts = addonTable or _G["ForeverAlts"] or _G["CLIAlts"] or {}
_G["ForeverAlts"] = ForeverAlts
_G["foreveralts"] = ForeverAlts
_G["CLIAlts"] = ForeverAlts
_G["clialts"] = ForeverAlts

-- ForeverAlts:Print is canonical in data.lua

local SafeAfter = ForeverAlts.SafeAfter or function(delay, callback)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, callback)
    end
end

local hasRequestedRaidInfo = false

-- ----------------------------------------------------------------------------
-- Performance Profiling Metrics (/clialts perf)
-- ----------------------------------------------------------------------------
ForeverAlts.perfData = {
    collectMs = 0,
    renderMs = 0,
    collectCount = 0,
    renderCount = 0,
}

local function RecordPerfMetric(name, elapsedMs)
    local p = ForeverAlts.perfData
    if not p then return end
    local countKey = name .. "Count"
    local msKey = name .. "Ms"
    p[countKey] = (p[countKey] or 0) + 1
    if p[countKey] == 1 or p[msKey] == 0 then
        p[msKey] = elapsedMs
    else
        local alpha = 0.2
        p[msKey] = (p[msKey] * (1 - alpha)) + (elapsedMs * alpha)
    end
end

local origCollect = ForeverAlts.CollectCurrentCharacter
if origCollect then
    ForeverAlts.CollectCurrentCharacter = function(self, ...)
        local t0 = (debugprofilestop and debugprofilestop()) or 0
        local r1, r2, r3 = origCollect(self, ...)
        if debugprofilestop then
            local dt = debugprofilestop() - t0
            RecordPerfMetric("collect", dt)
        end
        return r1, r2, r3
    end
end

local origRender = ForeverAlts.Render
if origRender then
    ForeverAlts.Render = function(self, force, ...)
        local t0 = (debugprofilestop and debugprofilestop()) or 0
        local r1, r2, r3 = origRender(self, force, ...)
        if debugprofilestop then
            local dt = debugprofilestop() - t0
            if (self.mainFrame and self.mainFrame:IsShown()) or force or dt > 0.05 then
                RecordPerfMetric("render", dt)
            end
        end
        return r1, r2, r3
    end
end

function ForeverAlts:MeasureRenderPerf(samples)
    samples = samples or 5
    if not self.mainFrame and self.CreateModernMainFrame then
        self:CreateModernMainFrame()
    end
    -- Warmup pass (forcing render even if frame hidden)
    if self.Render then
        self:Render(true)
    end

    local totalMs = 0
    local minMs = 999999
    local maxMs = 0
    for _ = 1, samples do
        local t0 = (debugprofilestop and debugprofilestop()) or 0
        if self.Render then
            self:Render(true)
        end
        local t1 = (debugprofilestop and debugprofilestop()) or 0
        local dt = t1 - t0
        totalMs = totalMs + dt
        if dt < minMs then minMs = dt end
        if dt > maxMs then maxMs = dt end
    end
    local avgMs = totalMs / samples
    RecordPerfMetric("render", avgMs)
    return avgMs, minMs, maxMs, samples
end

function ForeverAlts:PrintPerf(liveAvg, liveMin, liveMax, samples)
    if not liveAvg and self.MeasureRenderPerf then
        liveAvg, liveMin, liveMax, samples = self:MeasureRenderPerf(5)
    end
    if UpdateAddOnMemoryUsage then
        pcall(UpdateAddOnMemoryUsage)
    elseif C_AddOns and C_AddOns.UpdateAddOnMemoryUsage then
        pcall(C_AddOns.UpdateAddOnMemoryUsage)
    end
    local addonId = addonName or "ForeverAlts"
    local memKB = (GetAddOnMemoryUsage and GetAddOnMemoryUsage(addonId))
        or (C_AddOns and C_AddOns.GetAddOnMemoryUsage and C_AddOns.GetAddOnMemoryUsage(addonId))
        or (GetAddOnMemoryUsage and GetAddOnMemoryUsage("clialts"))
        or 0
    local p = self.perfData or {}
    local collectStr = (p.collectCount and p.collectCount > 0)
        and string.format("%.2f ms (%d samples)", p.collectMs or 0, p.collectCount)
        or "N/A (no samples)"
    local renderStr = (p.renderCount and p.renderCount > 0)
        and string.format("%.2f ms (EMA across %d calls)", p.renderMs or 0, p.renderCount)
        or "N/A (no samples)"

    self:Print("--- Performance Benchmark (debugprofilestop) ---")
    if liveAvg then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  * Active Render() Benchmark: %.3f ms (min: %.3f ms, max: %.3f ms over %d runs)",
            liveAvg, liveMin or liveAvg, liveMax or liveAvg, samples or 1))
    end
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  * Moving Average Render:     %s", renderStr))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  * Data Collection:           %s", collectStr))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  * Addon Memory:              %.1f KB (%.2f MB)", memKB, memKB / 1024))

    if liveAvg and liveAvg > 16.0 then
        DEFAULT_CHAT_FRAME:AddMessage("  * Recommendation: Per-row derived caching advised (frame time exceeds 16ms budget).")
    elseif liveAvg then
        DEFAULT_CHAT_FRAME:AddMessage("  * Efficiency: Excellent (< 1ms). Per-row derived caching not needed.")
    end
end

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
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
    "PLAYERBANKSLOTS_CHANGED",
    "MAIL_INBOX_UPDATE",
    "MAIL_SHOW",
    "MAIL_CLOSED",
    "MAIL_SEND_SUCCESS",
    "MAIL_SUCCESS",
    "BAG_OPEN",
    "BAG_CLOSED",
    "HEARTHSTONE_BOUND",
    "QUEST_TURNED_IN",
    "QUEST_LOG_UPDATE",
    "QUEST_FINISHED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
}
for _, ev in ipairs(safeEvents) do
    pcall(function() eventFrame:RegisterEvent(ev) end)
end

do
    local ok = pcall(eventFrame.RegisterEvent, eventFrame, "BAG_UPDATE_DELAYED")
    if not ok then pcall(eventFrame.RegisterEvent, eventFrame, "BAG_UPDATE") end
end

local invScanTimer = nil
local pendingBankScan = false

function ForeverAlts:ScheduleInventoryScan(scanBank)
    if scanBank then
        pendingBankScan = true
    end
    if invScanTimer then return end
    invScanTimer = true
    SafeAfter(0.5, function()
        invScanTimer = nil
        local doBank = pendingBankScan or (ForeverAlts.isBankOpen == true)
        pendingBankScan = false
        if ForeverAlts.ScanCurrentInventory then
            ForeverAlts:ScanCurrentInventory(doBank)
        end
        if ForeverAlts.UpdateWatchCounts then
            ForeverAlts:UpdateWatchCounts()
        end
        if ForeverAlts.RequestRender then
            ForeverAlts:RequestRender()
        end
    end)
end

local zoneChangeTimer = nil

function ForeverAlts:ScheduleZoneChange()
    if zoneChangeTimer then return end
    zoneChangeTimer = true
    self:CollectCurrentCharacter()
    self:RequestRender()
    SafeAfter(1.0, function()
        zoneChangeTimer = nil
        ForeverAlts:CollectCurrentCharacter(false, true)
        ForeverAlts:RequestRender()
    end)
end

local questLogTimer = nil

function ForeverAlts:ScheduleQuestLogUpdate()
    if questLogTimer then return end
    questLogTimer = true
    SafeAfter(0.3, function()
        questLogTimer = nil
        ForeverAlts:CollectCurrentCharacter()
        ForeverAlts:RequestRender()
    end)
end

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" then
        local loaded = (arg1 or ""):lower()
        if not arg1 or loaded == (addonName or ""):lower() or loaded == "foreveralts" or loaded == "clialts" then
            ForeverAlts:InitDB()
            ForeverAlts:CacheCurrentPlayer()
            ForeverAlts:CreateMinimapButton()
            if ForeverAlts.InitLDB then ForeverAlts:InitLDB() end
            if ForeverAlts.UpdateLDB then ForeverAlts:UpdateLDB() end
        end

    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        ForeverAlts.exhaustionReceived = false
        SafeAfter(2.0, function()
            ForeverAlts.exhaustionReceived = true
        end)
        ForeverAlts:InitDB()
        ForeverAlts:CacheCurrentPlayer()
        ForeverAlts:CreateMinimapButton()
        if ForeverAlts.InitLDB then ForeverAlts:InitLDB() end
        if ForeverAlts.UpdateLDB then ForeverAlts:UpdateLDB() end
        ForeverAlts.isPlayerResting = (IsResting and IsResting() and true or false)

        -- Self-calibrating rested model check against last clean logout
        ForeverAlts:CalibrateRestedModel()

        -- Record daily gold history snapshot (capped at 90 days)
        ForeverAlts:RecordGoldSnapshot()

        -- Scan watchlist item counts across bags & bank
        ForeverAlts:UpdateWatchCounts()

        -- Initialize session XP tracking (Feature 10: > plan)
        ForeverAlts:InitSessionXP()

        -- Initialize item hover tooltip hooks & initial inventory scan (Feature 6)
        if ForeverAlts.InitTooltipHooks then ForeverAlts:InitTooltipHooks() end
        if ForeverAlts.ScanCurrentInventory then ForeverAlts:ScanCurrentInventory(false) end
        if ForeverAlts.CheckBagAddonConflict then ForeverAlts:CheckBagAddonConflict(false) end
        if ForeverAlts.InitBagSortButton then ForeverAlts:InitBagSortButton() end

        -- Immediate snapshot
        local char = ForeverAlts:CollectCurrentCharacter(false, true)
        if char and not self.hasAnnounced then
            self.hasAnnounced = true
            local coloredName = ForeverAlts:ColorizePlayerName(char.name, char.classFile)
            local summary = ForeverAlts:GetAccountSummary()
            ForeverAlts:Print(string.format("Tracking %s (Level %d %s). Total tracked: %d. Type |cff00ff66/fa|r to view.",
                coloredName, char.level or 1, ForeverAlts:FormatRaceClass(char), summary.totalAlts or 1))

            -- Unified boxed login digest (at most 5 lines)
            ForeverAlts:PrintLoginDigest()
        end

        -- Request raid/instance lockouts ONCE per session 2s after entering the world
        if event == "PLAYER_ENTERING_WORLD" and not hasRequestedRaidInfo then
            hasRequestedRaidInfo = true
            SafeAfter(2.0, function()
                if RequestRaidInfo then pcall(RequestRaidInfo) end
            end)
        end

        -- Check onboarding tour for first login
        if ForeverAltsDB and ForeverAltsDB.settings and not ForeverAltsDB.settings.tourDone then
            SafeAfter(2.5, function()
                if not (ForeverAltsDB and ForeverAltsDB.settings and ForeverAltsDB.settings.tourDone) then
                    if ForeverAlts.StartTour then
                        ForeverAlts:StartTour()
                    end
                end
            end)
        end

        -- Delayed sync after 1.5s, 3.0s, and 5.0s to ensure server-synced money, XP, and resting state
        SafeAfter(1.5, function()
            ForeverAlts.isPlayerResting = (IsResting and IsResting() and true or false)
            ForeverAlts:UpdateWatchCounts()
            if ForeverAlts.ScanCurrentInventory then ForeverAlts:ScanCurrentInventory(false) end
            ForeverAlts:CollectCurrentCharacter()
            if ForeverAlts.CaptureChatSettings then ForeverAlts:CaptureChatSettings() end
            ForeverAlts:RequestRender()
        end)

        SafeAfter(3.0, function()
            ForeverAlts.isPlayerResting = (IsResting and IsResting() and true or false)
            ForeverAlts:UpdateWatchCounts()
            ForeverAlts:CollectCurrentCharacter()
            ForeverAlts:RequestRender()
        end)

        SafeAfter(5.0, function()
            ForeverAlts.isPlayerResting = (IsResting and IsResting() and true or false)
            ForeverAlts:UpdateWatchCounts()
            ForeverAlts:CollectCurrentCharacter()
            ForeverAlts:RequestRender()
        end)

        ForeverAlts:RequestRender()

    elseif event == "PLAYER_LOGOUT" then
        -- Final snapshot before logout: preserve cached resting state if client strips world flags
        if IsResting and IsResting() then
            ForeverAlts.isPlayerResting = true
        end
        ForeverAlts:CollectCurrentCharacter(true)
        if ForeverAlts.CaptureChatSettings then ForeverAlts:CaptureChatSettings() end
        ForeverAlts:RecordGoldSnapshot()

    elseif event == "PLAYER_CAMPING" or event == "PLAYER_QUITING" then
        -- Camping / logout countdown initiated
        if IsResting and IsResting() then
            ForeverAlts.isPlayerResting = true
        end
        ForeverAlts:CollectCurrentCharacter(true)

    elseif event == "LOGOUT_CANCEL" then
        -- Logout cancelled
        if ForeverAlts.sessionXP then
            ForeverAlts.sessionXP.finalized = nil
        end
        ForeverAlts.isPlayerResting = (IsResting and IsResting() and true or false)
        ForeverAlts:CollectCurrentCharacter(false, true)

    elseif event == "PLAYER_UPDATE_RESTING" then
        ForeverAlts.isPlayerResting = (IsResting and IsResting() and true or false)
        ForeverAlts:CollectCurrentCharacter(false)
        ForeverAlts:RequestRender()

    elseif event == "PLAYER_XP_UPDATE" or event == "UPDATE_EXHAUSTION" or event == "PLAYER_LEVEL_UP" then
        if event == "UPDATE_EXHAUSTION" then
            ForeverAlts.exhaustionReceived = true
        end
        ForeverAlts:UpdateSessionXP()
        ForeverAlts:CollectCurrentCharacter()
        ForeverAlts:RequestRender()

    elseif event == "PLAYER_MONEY" then
        ForeverAlts:CollectCurrentCharacter()
        ForeverAlts:RequestRender()

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        ForeverAlts:ScheduleZoneChange()

    elseif event == "SKILL_LINES_CHANGED" or event == "SPELLS_CHANGED" or event == "CHAT_MSG_SKILL" or event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" or event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then
        ForeverAlts:CollectCurrentCharacter()
        ForeverAlts:RequestRender()

    elseif event == "UPDATE_INSTANCE_INFO" then
        ForeverAlts:CollectCurrentCharacter()
        ForeverAlts:RequestRender()

    elseif event == "QUEST_TURNED_IN" or event == "QUEST_LOG_UPDATE" or event == "QUEST_FINISHED" then
        ForeverAlts:ScheduleQuestLogUpdate()

    elseif event == "BANKFRAME_OPENED" then
        ForeverAlts.isBankOpen = true
        ForeverAlts:ScheduleInventoryScan(true)
        ForeverAlts:UpdateWatchCounts()
        ForeverAlts:RequestRender()

    elseif event == "BANKFRAME_CLOSED" then
        ForeverAlts.isBankOpen = false
        ForeverAlts:ScheduleInventoryScan(false)
        ForeverAlts:UpdateWatchCounts()
        ForeverAlts:RequestRender()

    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        ForeverAlts:ScheduleInventoryScan(true)

    elseif event == "BAG_UPDATE_DELAYED" or event == "BAG_UPDATE" then
        ForeverAlts:ScheduleInventoryScan(ForeverAlts.isBankOpen == true)
        if ForeverAlts.UpdateBagSortButtonAnchor and not (InCombatLockdown and InCombatLockdown()) then
            ForeverAlts:UpdateBagSortButtonAnchor()
        end

    elseif event == "BAG_OPEN" or event == "BAG_CLOSED" then
        if ForeverAlts.UpdateBagSortButtonAnchor and not (InCombatLockdown and InCombatLockdown()) then
            ForeverAlts:UpdateBagSortButtonAnchor()
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat: UISpecialFrames and OnKeyDown handle ESC/navigation cleanly without protected bindings

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Exiting combat: refresh anchors once safe
        if ForeverAlts.UpdateBagSortButtonAnchor then
            ForeverAlts:UpdateBagSortButtonAnchor()
        end

    elseif event == "MAIL_SHOW" then
        ForeverAlts:ScanMailInbox()
        ForeverAlts:RequestRender()
        if ForeverAlts.InitMailAutoFillButton then ForeverAlts:InitMailAutoFillButton() end
        if ForeverAlts.UpdateMailAutoFillButton then ForeverAlts:UpdateMailAutoFillButton() end
        if ForeverAlts.GetMailReadySummary and not ForeverAlts.hasAnnouncedMailThisSession then
            local mailSum = ForeverAlts:GetMailReadySummary()
            if mailSum and mailSum.totalPackages > 0 then
                ForeverAlts.hasAnnouncedMailThisSession = true
                ForeverAlts:Print(string.format("|cff57d6e8[Mail Router]|r %d package(s) (%d items) in your bags ready to send to alts! Type |cff00ff66/fa mail|r to view.", mailSum.totalPackages, mailSum.totalItems))
            end
        end

    elseif event == "MAIL_INBOX_UPDATE" then
        ForeverAlts:ScanMailInbox()
        ForeverAlts:RequestRender()

    elseif event == "MAIL_SEND_SUCCESS" or event == "MAIL_SUCCESS" then
        if ForeverAltsDB and ForeverAltsDB.settings and ForeverAltsDB.settings.autoFillMailOnSend then
            SafeAfter(0.35, function()
                local isVisible = SendMailFrame and ((SendMailFrame.IsVisible and SendMailFrame:IsVisible()) or (SendMailFrame.IsShown and SendMailFrame:IsShown()))
                if isVisible then
                    local summary = ForeverAlts:GetMailReadySummary()
                    if summary and summary.totalPackages > 0 then
                        ForeverAlts:FillSendMailNextBatch()
                    else
                        ForeverAlts:Print("|cff00ff66[Mail Router]|r All routed alt mail packages sent!")
                        if ForeverAlts.UpdateMailAutoFillButton then
                            ForeverAlts:UpdateMailAutoFillButton()
                        end
                    end
                end
            end)
        else
            if ForeverAlts.UpdateMailAutoFillButton then
                SafeAfter(0.35, function()
                    ForeverAlts:UpdateMailAutoFillButton()
                end)
            end
        end

    elseif event == "MAIL_CLOSED" then
        ForeverAlts.hasAnnouncedMailThisSession = nil

    elseif event == "HEARTHSTONE_BOUND" then
        ForeverAlts:CollectCurrentCharacter()
        ForeverAlts:RequestRender()
    end
end)

local function SafeStrTrim(str)
    if strtrim then return strtrim(str) end
    return (str or ""):match("^%s*(.-)%s*$") or ""
end

local function SlashHandler(msg)
    msg = SafeStrTrim(msg or "")
    local cmd, arg = msg:match("^(%S+)%s*(.*)$")
    cmd = (cmd or ""):lower()
    arg = SafeStrTrim(arg or "")

    if cmd == "" or cmd == "toggle" then
        ForeverAlts:CollectCurrentCharacter()
        ForeverAlts:Toggle()

    elseif cmd == "version" or cmd == "ver" or cmd == "-v" or cmd == "--version" then
        ForeverAlts:PrintVersion()

    elseif cmd == "beta" or (cmd == "8" and not (cmd == "tab" and arg == "8")) then
        ForeverAlts:Print("Beta dashboard has been integrated into Overview (Tab 1). Redirecting to Overview... (Settings is now Tab 8, use /fa settings)")
        ForeverAlts:CollectCurrentCharacter()
        ForeverAlts:Toggle(true)
        if ForeverAlts.SwitchTab then
            ForeverAlts:SwitchTab(1)
        end

    elseif cmd == "1" or cmd == "2" or cmd == "3" or cmd == "4" or cmd == "5" or cmd == "6" or cmd == "7" or cmd == "8" or cmd == "9" or cmd == "tab" then
        local tabId = tonumber(cmd)
        if cmd == "tab" and arg and arg ~= "" then
            tabId = tonumber(arg)
        end
        if tabId == 9 then
            tabId = 8
        end
        if tabId and tabId >= 1 and tabId <= 8 then
            ForeverAlts:CollectCurrentCharacter()
            ForeverAlts:Toggle(true)
            if ForeverAlts.SwitchTab then
                ForeverAlts:SwitchTab(tabId)
            else
                if ForeverAltsDB and ForeverAltsDB.settings then
                    ForeverAltsDB.settings.activeTab = tabId
                end
                if ForeverAlts.SetPage then ForeverAlts:SetPage(1) end
                ForeverAlts:Render()
            end
        else
            ForeverAlts:Print("Usage: |cff00ff66/fa [1-8]|r (Switches to specified tab)")
        end

    elseif cmd == "next" then
        ForeverAlts:PrintNextAlts()

    elseif cmd == "sortbags" or cmd == "cleanup" then
        ForeverAlts:SortBags()

    elseif cmd == "sortbtn" or cmd == "sortbutton" then
        if arg and (arg:lower() == "reset" or arg:lower() == "auto") then
            if ForeverAltsDB and ForeverAltsDB.settings then
                ForeverAltsDB.settings.bagSortManualOverride = nil
                ForeverAltsDB.settings.bagAddonNotified = nil
            end
            local detected = ForeverAlts:CheckBagAddonConflict(false)
            if not detected then
                ForeverAlts:ToggleBagSortButton(true, false)
                ForeverAlts:Print("Bag sort button reset to automatic detection (|cff00ff66ENABLED|r - no bag addon detected).")
            else
                ForeverAlts:Print(string.format("Bag sort button reset to automatic detection (|cffff8800DISABLED|r - %s detected).", detected))
            end
        else
            local newState = ForeverAlts:ToggleBagSortButton(nil, true)
            local stateStr = newState and "|cff00ff66ENABLED|r" or "|cffff8800DISABLED|r"
            local detected = ForeverAlts.detectedBagAddon or (ForeverAlts.DetectThirdPartyBagAddon and ForeverAlts:DetectThirdPartyBagAddon())
            if detected and newState then
                ForeverAlts:Print(string.format("Bag auto-sort button is now %s (manual override with %s loaded).", stateStr, detected))
            else
                ForeverAlts:Print(string.format("Bag auto-sort button is now %s.", stateStr))
            end
        end

    elseif cmd == "fillmail" or cmd == "autofillmail" or cmd == "mailfill" then
        ForeverAlts:FillSendMailNextBatch()

    elseif cmd == "mailbtn" or cmd == "mailbutton" then
        local newState = ForeverAlts:ToggleMailAutoFillButton()
        local stateStr = newState and "|cff00ff66ENABLED|r" or "|cffff8800DISABLED|r"
        ForeverAlts:Print(string.format("Mail auto-fill button is now %s.", stateStr))

    elseif cmd == "sort" then
        if arg and (arg:lower() == "bags" or arg:lower() == "bag") then
            ForeverAlts:SortBags()
        elseif arg and arg ~= "" then
            ForeverAlts:Toggle(true)
            local map = {
                name = "name",
                char = "name",
                lvl = "level",
                level = "level",
                gold = "gold",
                money = "gold",
                rest = "rested",
                rested = "rested",
                pct = "rested",
                pool = "pool",
                timetocap = "timetocap",
                time = "timetocap",
                ttc = "timetocap",
                waste = "timetocap",
                wst = "timetocap",
                cohort = "cohort",
                tier = "cohort",
                role = "cohort",
                xp = "xp",
                exp = "xp",
                progress = "xp",
                rotation = "rotation",
                rot = "rotation",
                next = "rotation",
                status = "rotation",
                location = "location",
                loc = "location",
                hearth = "hearth",
                seen = "seen",
            }
            local key = map[arg:lower()] or arg:lower()
            if ForeverAlts.ToggleSortKey then
                ForeverAlts:ToggleSortKey(key)
            end
        else
            ForeverAlts:Print("Usage: |cff00ff66/fa sort <name|level|rotation|cohort|gold|rested|timetocap|xp|bags>|r")
        end

    elseif cmd == "watch" then
        if arg and arg ~= "" then
            local ok, item = ForeverAlts:AddWatchItem(arg)
            if ok then
                local name = ForeverAlts:GetWatchItemDisplayName(item)
                ForeverAlts:Print(string.format("Added %s to watchlist.", name:find("|c") and name or ("|cffffd700" .. name .. "|r")))
            else
                local name = ForeverAlts:GetWatchItemPlainName(item or arg)
                ForeverAlts:Print(string.format("Item '%s' is already in watchlist.", name))
            end
            ForeverAlts:RequestRender()
        else
            ForeverAlts:Print("Usage: |cff00ff66/fa watch <Item Link, ID, or Name>|r")
        end

    elseif cmd == "unwatch" then
        if arg and arg ~= "" then
            local ok, item = ForeverAlts:RemoveWatchItem(arg)
            if ok then
                local name = ForeverAlts:GetWatchItemDisplayName(item)
                ForeverAlts:Print(string.format("Removed %s from watchlist.", name:find("|c") and name or ("|cffffd700" .. name .. "|r")))
            else
                ForeverAlts:Print(string.format("Item '%s' was not found in watchlist.", arg))
            end
            ForeverAlts:RequestRender()
        else
            ForeverAlts:Print("Usage: |cff00ff66/fa unwatch <Item Link, ID, or Name>|r")
        end

    elseif cmd == "watchlist" then
        ForeverAlts:PrintWatchlist()

    elseif cmd == "export" or cmd == "csv" then
        ForeverAlts:Toggle(true)
        ForeverAlts:ShowExportPopup()

    elseif cmd == "compact" or cmd == "c" then
        ForeverAlts:ToggleCompact()
        local isComp = ForeverAlts:IsCompact()
        ForeverAlts:Print(string.format("Compact mode: %s (XP bar columns %s).", isComp and "|cff00ff66ENABLED|r" or "|cffff8800DISABLED|r", isComp and "hidden" or "visible"))

    elseif cmd == "filter" or cmd == "find" then
        ForeverAlts:Toggle(true)
        if ForeverAlts.SetFilter then
            ForeverAlts:SetFilter(arg)
        end

    elseif cmd == "clear" then
        if ForeverAlts.SetFilter then
            ForeverAlts:SetFilter(nil)
        end
        ForeverAlts:Print("Active filter cleared.")

    elseif cmd == "calibrate" then
        ForeverAlts:CalibrateRestedModel()

    elseif cmd == "show" then
        ForeverAlts:CollectCurrentCharacter()
        ForeverAlts:Toggle(true)

    elseif cmd == "track" or cmd == "save" or cmd == "scan" then
        local char = ForeverAlts:CollectCurrentCharacter()
        if char then
            local summary = ForeverAlts:GetAccountSummary()
            ForeverAlts:Print(string.format("Recorded %s. Total characters tracked: %d.", char.name, summary.totalAlts))
        end

    elseif cmd == "hide" then
        ForeverAlts:Toggle(false)

    elseif cmd == "minimap" then
        ForeverAlts:ToggleMinimap()
        local state = ForeverAltsDB.settings.minimapShow and "visible" or "hidden"
        ForeverAlts:Print(string.format("Minimap icon is now %s.", state))

    elseif cmd == "reset" then
        if ForeverAltsDB and ForeverAltsDB.settings then
            ForeverAltsDB.settings.windowPos = nil
        end
        if CLIAltsMainFrame then
            CLIAltsMainFrame:ClearAllPoints()
            CLIAltsMainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        ForeverAlts:Print("Window position reset to center.")

    elseif cmd == "legacy" or cmd == "legacyui" then
        if ForeverAltsDB and ForeverAltsDB.settings then
            ForeverAltsDB.settings.legacyUI = nil
        end
        ForeverAlts:Print("ForeverAlts now uses Modern v2 exclusively. The legacy ASCII UI has been deprecated.")
        if ForeverAlts.RecreateMainFrame then
            local wasShown = CLIAltsMainFrame and CLIAltsMainFrame:IsShown()
            ForeverAlts:RecreateMainFrame()
            if wasShown and CLIAltsMainFrame then
                CLIAltsMainFrame:Show()
                ForeverAlts:Render()
            end
        end

    elseif cmd == "settings" or cmd == "config" or cmd == "options" or cmd == "pref" or cmd == "preferences" then
        if ForeverAlts.ShowSettingsDialog then
            ForeverAlts:ShowSettingsDialog()
        end

    elseif cmd == "scale" then
        if arg and arg ~= "" then
            local clean = arg:gsub("%%", "")
            local val = tonumber(clean)
            if val then
                if val > 5 then val = val / 100 end
                ForeverAlts:SetScale(val)
                ForeverAlts:Print(string.format("UI scale set to %.2fx (%d%%).", val, math.floor(val * 100 + 0.5)))
            else
                ForeverAlts:Print("Usage: |cff00ff66/fa scale <0.7 - 1.8>|r (e.g. 1.2 or 120%)")
            end
        else
            ForeverAlts:CycleScale()
        end

    elseif cmd == "theme" then
        if arg and arg ~= "" then
            local map = ForeverAlts.THEME_MAP or {
                default = "DEFAULT",
                def = "DEFAULT",
                blizzard = "BLIZZARD",
                blizz = "BLIZZARD",
                wow = "BLIZZARD",
                dark = "DARK",
                drk = "DARK",
                amber = "AMBER",
                amb = "AMBER",
                green = "GREEN",
                grn = "GREEN",
                cyan = "CYAN",
                cyn = "CYAN",
                mono = "MONO",
                safe = "COLORBLIND",
                colorblind = "COLORBLIND",
                cb = "COLORBLIND",
                synthwave = "SYNTHWAVE",
                syn = "SYNTHWAVE",
                dracula = "DRACULA",
                dra = "DRACULA",
            }
            local choice = map[arg:lower()]
            if choice and ForeverAlts.THEMES and ForeverAlts.THEMES[choice] then
                if ForeverAltsDB and ForeverAltsDB.settings then
                    ForeverAltsDB.settings.theme = choice
                    ForeverAltsDB.settings.themeExplicit = true
                end
                if ForeverAlts.ApplyTheme then ForeverAlts:ApplyTheme() end
                if ForeverAlts.Render then ForeverAlts:Render() end
                ForeverAlts:Print(string.format("Theme set to %s (%s).", choice, ForeverAlts.THEMES[choice].tag or choice))
            else
                ForeverAlts:Print("Usage: |cff00ff66/fa theme <default|blizzard|amber|green|cyan|mono|safe|synthwave|dracula>|r")
            end
        else
            if ForeverAlts.CycleTheme then
                ForeverAlts:CycleTheme()
                local curTheme = (ForeverAltsDB and ForeverAltsDB.settings and ForeverAltsDB.settings.theme) or "DEFAULT"
                ForeverAlts:Print(string.format("Theme cycled: %s", curTheme))
            end
        end

    elseif cmd == "font" or cmd == "fontsize" then
        if arg and arg ~= "" then
            local sz = tonumber(arg)
            if sz and sz >= 12 and sz <= 24 then
                ForeverAlts:SetFontSize(sz)
                local sc = (ForeverAltsDB and ForeverAltsDB.settings and ForeverAltsDB.settings.scale) or 1.0
                ForeverAlts:Print(string.format("Interface font size set to %dpx (panel scale: %d%%).", sz, math.floor(sc * 100 + 0.5)))
            else
                ForeverAlts:Print("Usage: |cff00ff66/fa font <12-24>|r")
            end
        else
            local cur = (ForeverAltsDB and ForeverAltsDB.settings and ForeverAltsDB.settings.fontSize) or 18
            ForeverAlts:Print(string.format("Current font size: %dpx. Usage: |cff00ff66/fa font <12-24>|r", cur))
        end

    elseif cmd == "gold" then
        local summary = ForeverAlts:GetAccountSummary()
        local moneyStr = ForeverAlts:FormatMoney(summary.totalGold, true)
        ForeverAlts:Print(string.format("Total Account Wealth: %s across %d alts.", moneyStr, summary.totalAlts))

    elseif cmd == "perk" or cmd == "wellrested" then
        if ForeverAlts:IsRetail() then
            ForeverAlts:Print("Well Rested perks are only available on WoW Forever (Retail uses baseline 150% rested rates).")
            return
        end
        local selChar = (ForeverAlts.GetSelectedOrCurChar and ForeverAlts:GetSelectedOrCurChar()) or (ForeverAlts.GetMainFrame and ForeverAlts:GetMainFrame() and ForeverAlts:GetMainFrame().detailPanel and ForeverAlts:GetMainFrame().detailPanel.currentChar) or ForeverAlts:GetCurrentPlayer()
        if arg and arg ~= "" then
            local rank = tonumber(arg)
            if rank and rank >= 0 and rank <= 5 then
                ForeverAlts:SetWellRestedRank(rank, selChar)
            else
                local a1, a2 = arg:match("^(%S+)%s+(%S+)$")
                if a1 and a2 then
                    local r1, r2 = tonumber(a1), tonumber(a2)
                    if r1 and r1 >= 0 and r1 <= 5 then
                        ForeverAlts:SetWellRestedRank(r1, a2)
                    elseif r2 and r2 >= 0 and r2 <= 5 then
                        ForeverAlts:SetWellRestedRank(r2, a1)
                    else
                        ForeverAlts:Print("Usage: |cff00ff66/fa perk [character] <0-5>|r")
                    end
                else
                    local foundChar = ForeverAlts:FindCharacter(arg)
                    if foundChar then
                        local curRank = ForeverAlts:GetWellRestedRank(foundChar)
                        ForeverAlts:Print(string.format("Well Rested perk for |cffffffff%s|r: Rank %d/5 (+%d%% speed, %d%% cap).",
                            foundChar.fullName or foundChar.name, curRank, curRank * 4, 150 + (curRank * 6)))
                    else
                        ForeverAlts:Print("Usage: |cff00ff66/fa perk [character] <0-5>|r (Sets or inspects Well Rested perk rank)")
                    end
                end
            end
        else
            ForeverAlts:CycleWellRestedPerk(selChar)
        end

    elseif cmd == "rested" then
        if ForeverAlts:IsRetail() then
            ForeverAlts:Print("--- Rested XP Summary (Retail: Standard 150% Cap) ---")
        else
            local selChar = (ForeverAlts.GetSelectedOrCurChar and ForeverAlts:GetSelectedOrCurChar()) or (ForeverAlts.GetMainFrame and ForeverAlts:GetMainFrame() and ForeverAlts:GetMainFrame().detailPanel and ForeverAlts:GetMainFrame().detailPanel.currentChar) or ForeverAlts:GetCurrentPlayer()
            local r = ForeverAlts:GetWellRestedRank(selChar)
            local cName = (selChar and (selChar.fullName or selChar.name)) or "Active"
            ForeverAlts:Print(string.format("--- Rested XP Summary (Well Rested Perk: %s R%d/5 +%d%%) ---", cName, r, r * 4))
        end
        local chars = ForeverAlts:GetCharactersList("rested", false)
        for _, char in ipairs(chars) do
            local rested = ForeverAlts:GetRestedData(char)
            local coloredName = ForeverAlts:ColorizePlayerName(char.name, char.classFile)
            local charRank = ForeverAlts:GetWellRestedRank(char)
            local rankTag = (not ForeverAlts:IsRetail() and charRank > 0) and string.format(" [R%d, %d%% cap]", charRank, 150 + (charRank * 6)) or ""
            if rested and not rested.isMaxLevel then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  * %s (Lvl %d)%s: %s %d%% - %s (%s)",
                    coloredName, char.level or 1, rankTag, rested.statusStr, rested.percent, rested.timeLeftStr, rested.fullDate))
            else
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  * %s (Lvl %d)%s: [ MAX LEVEL ]", coloredName, char.level or 1, rankTag))
            end
        end

    elseif cmd == "perf" then
        ForeverAlts:PrintPerf()

    elseif cmd == "selftest" or cmd == "test" then
        if InCombatLockdown and InCombatLockdown() then
            ForeverAlts:Print("|cffff4444Cannot run selftest while in combat.|r")
            return
        end
        ForeverAlts:RunSelfTest()

    elseif cmd == "alerts" or cmd == "alert" then
        ForeverAlts:HandleAlertsCommand(arg)

    elseif cmd == "digest" then
        ForeverAlts:PrintLoginDigest(true)

    elseif cmd == "plan" then
        ForeverAlts:PrintPlan(arg)

    elseif cmd == "note" then
        local targetName, noteText = (arg or ""):match("^(%S+)%s*(.*)$")
        ForeverAlts:SetCharacterNote(targetName, noteText, true)

    elseif cmd == "unlocked" or cmd == "lockout" or cmd == "lockouts" then
        ForeverAlts:PrintUnlockedAlts(arg)

    elseif cmd == "prune" then
        local daysStr, optConfirm = (arg or ""):match("^(%d+)%s*(.*)$")
        local days = tonumber(daysStr)
        if not days or days < 1 then
            ForeverAlts:Print("Usage: |cff00ff66/fa prune <days> [confirm]|r (e.g. /fa prune 30)")
        else
            local count, names = ForeverAlts:GetPrunableCharacters(days)
            if count == 0 then
                ForeverAlts:Print(string.format("No alts found inactive for %d+ days.", days))
            elseif optConfirm and (optConfirm:lower() == "confirm" or optConfirm:lower() == "now" or optConfirm:lower() == "yes") then
                local prunedCount, prunedNames = ForeverAlts:PruneCharacters(days)
                local sample = table.concat(prunedNames, ", ")
                ForeverAlts:Print(string.format("Pruned %d alts inactive for %d+ days: |cffffd700%s|r", prunedCount, sample))
                ForeverAlts:RequestRender()
            else
                ForeverAlts:Toggle(true)
                local sample = table.concat(names, ", ", 1, math.min(5, #names))
                if #names > 5 then sample = sample .. "..." end
                ForeverAlts:Print(string.format("Found %d alts inactive for %d+ days (%s). Confirm in popup or run: |cff00ff66/fa prune %d confirm|r",
                    count, sample, days))
                ForeverAlts:ShowConfirmPrunePopup(days, count, names)
            end
        end

    elseif cmd == "backup" then
        local ok, msg = ForeverAlts:BackupDB("manual")
        ForeverAlts:Print(ok and "|cff00ff66Database backup created in ForeverAltsDB.backup.|r" or msg)

    elseif cmd == "restore" then
        local ok, msg = ForeverAlts:RestoreDB()
        ForeverAlts:Print(ok and ("|cff00ff66" .. msg .. "|r") or ("|cffff4444" .. msg .. "|r"))

    elseif cmd == "tooltips" or cmd == "tooltip" or cmd == "inv" then
        if arg and (arg:lower() == "reset" or arg:lower() == "auto") then
            if ForeverAltsDB and ForeverAltsDB.settings then
                ForeverAltsDB.settings.tooltipCountManualOverride = nil
                ForeverAltsDB.settings.tooltipAddonNotified = nil
            end
            local detected = ForeverAlts:CheckBagAddonConflict(false)
            if not detected then
                if ForeverAlts.ToggleAltCountTooltips then ForeverAlts:ToggleAltCountTooltips(true, false) end
                ForeverAlts:Print("Alt count tooltips reset to automatic detection (|cff00ff66ENABLED|r - no conflict detected).")
            else
                ForeverAlts:Print(string.format("Alt count tooltips reset to automatic detection (|cffff8800DISABLED|r - %s detected).", detected))
            end
        elseif arg and (arg:lower() == "mail" or arg:lower() == "route") then
            local newState = ForeverAlts.ToggleMailRouteTooltips and ForeverAlts:ToggleMailRouteTooltips()
            local stateStr = newState and "|cff00ff66ENABLED|r" or "|cffff8800DISABLED|r"
            ForeverAlts:Print(string.format("Mail router hover tags on tooltips are now %s.", stateStr))
        else
            local newState = ForeverAlts.ToggleAltCountTooltips and ForeverAlts:ToggleAltCountTooltips(nil, true)
            if newState == nil then
                ForeverAltsDB.settings.showAltCountTooltips = (ForeverAltsDB.settings.showAltCountTooltips == false)
                newState = ForeverAltsDB.settings.showAltCountTooltips
            end
            local stateStr = newState and "|cff00ff66ENABLED|r" or "|cffff8800DISABLED|r"
            local detected = ForeverAlts.detectedAltCountAddon or (ForeverAlts.DetectAltCountTooltipAddon and ForeverAlts:DetectAltCountTooltipAddon())
            if detected and newState then
                ForeverAlts:Print(string.format("Alt item count tooltips are now %s (manual override with %s loaded). Mail router tags remain |cff00ff66ENABLED|r.", stateStr, detected))
            else
                ForeverAlts:Print(string.format("Alt item count tooltips are now %s. Mail router tags remain |cff00ff66ENABLED|r.", stateStr))
            end
        end

    elseif cmd == "view" or cmd == "mode" or cmd == "overview" then
        if arg == "table" or arg == "gauges" then
            ForeverAlts:SetOverviewMode(arg)
            ForeverAlts:Print(string.format("Overview view mode set to: |cff00ff66%s|r", arg:upper()))
        else
            ForeverAlts:ToggleOverviewMode()
            local cur = (ForeverAltsDB and ForeverAltsDB.settings and ForeverAltsDB.settings.overviewMode) or "gauges"
            ForeverAlts:Print(string.format("Overview view mode toggled to: |cff00ff66%s|r", cur:upper()))
        end

    elseif cmd == "forever" or cmd == "wf" then
        ForeverAlts:ToggleForeverMode()
        local isForever = ForeverAlts:IsForeverMode()
        if isForever then
            ForeverAltsDB.settings.activeTab = 1
            ForeverAlts:Print("WoW Forever Mode: |cff00ff66ENABLED|r. Cohort routing & roles active.")
        else
            ForeverAlts:Print("WoW Forever Mode: |cffff8800DISABLED|r. Standard alt monitor active.")
        end
        ForeverAlts:RequestRender()

    elseif cmd == "core" then
        if not arg or arg == "" then
            ForeverAlts:Print("Usage: |cff00ff66/fa core <name> [target_level]|r (defaults to target level 35)")
        else
            local targetName, targetLvl = arg:match("^(%S+)%s*(%d*)$")
            local ok, msg = ForeverAlts:SetCharacterCohort(targetName, "CORE", tonumber(targetLvl))
            ForeverAlts:Print((ok and "|cff00ff66" or "|cffff4444") .. msg .. "|r")
            ForeverAlts:RequestRender()
        end

    elseif cmd == "alt" or cmd == "alts" or cmd == "reserve" then
        if not arg or arg == "" then
            ForeverAlts:Print("Usage: |cff00ff66/fa alt <name> [target_level]|r (defaults to target level 25)")
        else
            local targetName, targetLvl = arg:match("^(%S+)%s*(%d*)$")
            local ok, msg = ForeverAlts:SetCharacterCohort(targetName, "RESERVE", tonumber(targetLvl))
            ForeverAlts:Print((ok and "|cff00ff66" or "|cffff4444") .. msg .. "|r")
            ForeverAlts:RequestRender()
        end

    elseif cmd == "bank" or cmd == "mule" then
        if not arg or arg == "" then
            ForeverAlts:Print("Usage: |cff00ff66/fa bank <name>|r")
        else
            local targetName = arg:match("^(%S+)")
            local ok, msg = ForeverAlts:SetCharacterCohort(targetName, "BANK", 1)
            ForeverAlts:Print((ok and "|cff00ff66" or "|cffff4444") .. msg .. "|r")
            ForeverAlts:RequestRender()
        end

    elseif cmd == "unassign" or cmd == "unset" then
        if not arg or arg == "" then
            ForeverAlts:Print("Usage: |cff00ff66/fa unassign <name>|r")
        else
            local targetName = arg:match("^(%S+)")
            local ok, msg = ForeverAlts:SetCharacterCohort(targetName, "UNASSIGNED", 60)
            ForeverAlts:Print((ok and "|cff00ff66" or "|cffff4444") .. msg .. "|r")
            ForeverAlts:RequestRender()
        end

    elseif cmd == "role" or cmd == "tier" or cmd == "cohort" then
        if not arg or arg == "" then
            ForeverAlts:PrintRosterRoles()
        else
            local targetName, tier, remaining = arg:match("^(%S+)%s+(%S+)%s*(.*)$")
            if not targetName or not tier then
                ForeverAlts:Print("Usage: |cff00ff66/fa role <name> <core|reserve|bank|none> [supply_role] [target_level]|r")
            else
                local supplyRole, targetLvl = remaining:match("^(.-)%s+(%d+)$")
                if not supplyRole then
                    if tonumber(remaining) then
                        targetLvl = tonumber(remaining)
                        supplyRole = nil
                    else
                        supplyRole = (remaining ~= "") and remaining or nil
                        targetLvl = nil
                    end
                end
                local ok, msg = ForeverAlts:SetCharacterRole(targetName, tier, supplyRole, targetLvl)
                ForeverAlts:Print((ok and "|cff00ff66" or "|cffff4444") .. msg .. "|r")
                ForeverAlts:RequestRender()
            end
        end

    elseif cmd == "supply" then
        if not arg or arg == "" then
            ForeverAlts:Print("Usage: |cff00ff66/fa supply <name> [role]|r (e.g. /fa supply Grok Tailor/Bags, or /fa supply Grok auto)")
        else
            local targetName, supplyRole = arg:match("^(%S+)%s*(.*)$")
            if not supplyRole or supplyRole == "" then supplyRole = "clear" end
            local ok, msg = ForeverAlts:SetCharacterSupplyRole(targetName, supplyRole)
            ForeverAlts:Print((ok and "|cff00ff66" or "|cffff4444") .. msg .. "|r")
            ForeverAlts:RequestRender()
        end

    elseif cmd == "prof" or cmd == "milestones" or cmd == "professions" then
        ForeverAlts:PrintProfessionMilestones()

    elseif cmd == "dungeon" or cmd == "dungeons" or cmd == "dng" then
        ForeverAlts:PrintDungeonReadiness(arg)

    elseif cmd == "mail" or cmd == "router" or cmd == "supplychain" then
        ForeverAlts:PrintMailRouting()

    elseif cmd == "mailignore" or cmd == "ignoremail" then
        ForeverAlts:IgnoreMailItem(arg)

    elseif cmd == "mailunignore" or cmd == "unignoremail" then
        ForeverAlts:UnignoreMailItem(arg)

    elseif cmd == "mailignores" or cmd == "ignoredmail" then
        ForeverAlts:ListIgnoredMailItems()

    elseif cmd == "mailconsumables" then
        ForeverAlts:ToggleAutoMailConsumables()

    elseif cmd == "cook" or cmd == "cooking" then
        ForeverAlts:ToggleCharacterCooking(arg)

    elseif cmd == "firstaid" or cmd == "fa" then
        ForeverAlts:ToggleCharacterFirstAid(arg)

    elseif cmd == "lp" or cmd == "legacypoints" or cmd == "legacypoint" then
        ForeverAlts:PrintLegacyPointStatus(arg)

    elseif cmd == "copychat" or cmd == "chatcopy" or cmd == "clonechat" then
        if not arg or arg == "" then
            ForeverAlts:Print("Usage: |cff00ff66/fa copychat <character_name>|r (or configure in Settings Dialog)")
            local profiles = ForeverAlts:GetChatProfilesList()
            if #profiles > 0 then
                local names = {}
                for _, p in ipairs(profiles) do
                    table.insert(names, p.name)
                end
                ForeverAlts:Print("Available chat snapshots: " .. table.concat(names, ", "))
            else
                ForeverAlts:Print("No chat profiles saved yet. Log in to an alt to snapshot their chat layout.")
            end
        else
            local ok, msg = ForeverAlts:CopyChatSettings(arg)
            ForeverAlts:Print(ok and ("|cff00ff66" .. msg .. "|r") or ("|cffff4444" .. msg .. "|r"))
        end

    elseif cmd == "savechat" then
        local ok, count = ForeverAlts:CaptureChatSettings()
        if ok then
            ForeverAlts:Print(string.format("|cff00ff66Chat layout saved (%d windows captured).|r", count))
        else
            ForeverAlts:Print("|cffff4444" .. tostring(count or "Failed to capture chat.") .. "|r")
        end

    elseif cmd == "tour" or cmd == "onboarding" then
        if ForeverAlts.StartTour then
            ForeverAlts:StartTour()
        end

    elseif cmd == "help" or cmd == "?" then
        ForeverAlts:ShowHelpPopup()
        ForeverAlts:Print("Showing Quick Guide. Type |cff00ff66/fa|r to toggle alt monitor.")

    else
        ForeverAlts:Print("Unknown command. Type |cff00ff66/fa help|r for available options.")
    end
end

SLASH_FOREVERALTS1 = "/foreveralts"
SLASH_FOREVERALTS2 = "/fa"
SLASH_FOREVERALTS3 = "/forever"
SlashCmdList["FOREVERALTS"] = SlashHandler

SLASH_CLIALTS1 = "/clialts"
SLASH_CLIALTS2 = "/cli"
SLASH_CLIALTS3 = "/ca"
SlashCmdList["CLIALTS"] = SlashHandler

SLASH_CLIALTS_SORT1 = "/sortbags"
SlashCmdList["CLIALTS_SORT"] = function()
    ForeverAlts:SortBags()
end

SLASH_CLIALTS_FILLMAIL1 = "/fillmail"
SlashCmdList["CLIALTS_FILLMAIL"] = function()
    ForeverAlts:FillSendMailNextBatch()
end

SLASH_CLIALTS_MAILIGNORE1 = "/mailignore"
SLASH_CLIALTS_MAILIGNORE2 = "/ignoremail"
SlashCmdList["CLIALTS_MAILIGNORE"] = function(msg)
    ForeverAlts:IgnoreMailItem(msg)
end

SLASH_CLIALTS_MAILUNIGNORE1 = "/mailunignore"
SLASH_CLIALTS_MAILUNIGNORE2 = "/unignoremail"
SlashCmdList["CLIALTS_MAILUNIGNORE"] = function(msg)
    ForeverAlts:UnignoreMailItem(msg)
end

