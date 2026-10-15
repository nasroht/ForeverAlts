-- ============================================================================
-- CLIAlts: Automated Verification Suite (229 Assertions)
-- File: tests/selftest.lua
-- ============================================================================
local _, CLIAlts = ...
CLIAlts = CLIAlts or _G.CLIAlts or {}

function CLIAlts:RunSelfTest()
    if self.InitDB then
        self:InitDB()
    end
    local passed = 0
    local failed = 0
    local errors = {}

    local function Assert(cond, name)
        if cond then
            passed = passed + 1
        else
            failed = failed + 1
            table.insert(errors, name)
        end
    end

    local T0 = 1000000

    -- 1. ProjectRested tests
    -- 1a. Rest zone accrual at rank 0 (5% of maxXP per 8 hours = 1000 XP on 20k maxXP)
    local charInn = { maxXP = 20000, restedXP = 0, lastUpdate = T0, loggedOutInRestZone = true }
    local p1 = self:ProjectRested(charInn, T0 + 28800, 0)
    Assert(math.abs(p1 - 1000) < 0.01, "ProjectRested: 8h inn accrual at rank 0 equals 1000 XP")

    -- 1b. Wilderness accrual at rank 0 (1.25% of maxXP per 8 hours = 250 XP on 20k maxXP)
    local charWild = { maxXP = 20000, restedXP = 0, lastUpdate = T0, loggedOutInRestZone = false }
    local p2 = self:ProjectRested(charWild, T0 + 28800, 0)
    Assert(math.abs(p2 - 250) < 0.01, "ProjectRested: 8h wild accrual at rank 0 equals 250 XP")

    -- 1c. Cap enforcement at rank 0 (150% cap = 30000 XP on 20k maxXP)
    local p3 = self:ProjectRested(charInn, T0 + 10000000, 0)
    Assert(p3 == 30000, "ProjectRested: 150% cap enforced at rank 0")

    -- 1d. Perk rank 5 bonus (+20% speed -> 1200 XP per 8h, 180% cap -> 36000 XP)
    local p4 = self:ProjectRested(charInn, T0 + 28800, 5)
    Assert(math.abs(p4 - 1200) < 0.01, "ProjectRested: 8h inn accrual at rank 5 equals 1200 XP")
    local p5 = self:ProjectRested(charInn, T0 + 10000000, 5)
    Assert(p5 == 36000, "ProjectRested: 180% cap enforced at rank 5")

    -- 2. GetRestedWaste tests
    -- 2a. Uncapped character yields 0 waste and 'Accruing'
    local wSec1, wXP1, desc1 = self:GetRestedWaste(charInn, T0 + 28800)
    Assert(wSec1 == 0 and wXP1 == 0 and desc1 == "Accruing", "GetRestedWaste: uncapped char yields 0 waste and 'Accruing'")

    -- 2b. Max level character yields 0 waste and 'MAX LEVEL'
    local charMax = { level = self:GetMaxLevel(), maxXP = 0, restedXP = 0, lastUpdate = T0 }
    local wSec2, wXP2, desc2 = self:GetRestedWaste(charMax, T0 + 100000)
    Assert(wSec2 == 0 and wXP2 == 0 and desc2 == "MAX LEVEL", "GetRestedWaste: max level char yields 0 waste and 'MAX LEVEL'")

    -- 2c. Capped character after 24h offline past cap (86400s * (20000 / 576000) = 3000 wasted XP)
    local charCapped = { level = 20, maxXP = 20000, restedXP = 30000, lastUpdate = T0, loggedOutInRestZone = true }
    local wSec3, wXP3, _, timeStr3 = self:GetRestedWaste(charCapped, T0 + 86400)
    Assert(wSec3 == 86400 and wXP3 == 3000 and timeStr3 == "1d 0h", "GetRestedWaste: capped char 24h post-cap wastes 3000 XP with '1d 0h'")

    -- 3. Calibration Input tests
    local oldSnap = { cleanLogout = true, level = 20, maxXP = 20000, restedXP = 1000, lastUpdate = T0, loggedOutInRestZone = true }

    -- 3a. Level changed guard
    local _, _, st1 = self:EvaluateCalibration(oldSnap, 5000, 21, T0 + 3600, 0, nil)
    Assert(st1 == "LEVEL_CHANGED", "EvaluateCalibration: guards against level changes")

    -- 3b. Near-cap guard
    local oldNearCap = { cleanLogout = true, level = 20, maxXP = 20000, restedXP = 29600, lastUpdate = T0, loggedOutInRestZone = true }
    local _, _, st2 = self:EvaluateCalibration(oldNearCap, 30000, 20, T0 + 3600, 0, nil)
    Assert(st2 == "NEAR_CAP", "EvaluateCalibration: guards against near-cap snapshots")

    -- 3c. Short duration guard (< 600s)
    local _, _, st3 = self:EvaluateCalibration(oldSnap, 1050, 20, T0 + 300, 0, nil)
    Assert(st3 == "SHORT_DURATION", "EvaluateCalibration: guards against short offline durations (<600s)")

    -- 3d. No-drift match (within 2% threshold)
    local _, _, st4 = self:EvaluateCalibration(oldSnap, 2010, 20, T0 + 28800, 0, nil)
    Assert(st4 == "MATCH", "EvaluateCalibration: accepts consistent rate within 2% drift")

    -- 3e. Significant drift (observed rate matches rank 3 over 40h) -> PENDING on first sample
    -- At rank 3 (+12%), 40h accrues 5600 XP (predicted rank 0 was 5000 XP). Total = 6600 XP.
    local infRank1, _, st5 = self:EvaluateCalibration(oldSnap, 6600, 20, T0 + 144000, 0, nil)
    Assert(infRank1 == 3 and st5 == "PENDING", "EvaluateCalibration: infers rank 3 and holds PENDING on 1st sample")

    -- 3f. Second consistent sample confirms rank change
    local infRank2, _, st6 = self:EvaluateCalibration(oldSnap, 6600, 20, T0 + 144000, 0, 3)
    Assert(infRank2 == 3 and st6 == "CONFIRMED", "EvaluateCalibration: confirms rank 3 on 2nd consistent sample")

    -- 4. Login Digest & Alert Category Tests
    -- 4a. IsAlertEnabled defaults to true
    Assert(self:IsAlertEnabled("cooldowns") == true, "Alerts: cooldowns category enabled by default")
    Assert(self:IsAlertEnabled("rested") == true, "Alerts: rested category enabled by default")

    -- 4b. ToggleAlert disables and reenables
    self:ToggleAlert("cooldowns", false)
    Assert(self:IsAlertEnabled("cooldowns") == false, "Alerts: toggle cooldowns category to false")
    self:ToggleAlert("cooldowns", true)
    Assert(self:IsAlertEnabled("cooldowns") == true, "Alerts: toggle cooldowns category back to true")

    -- 4c. Ready cooldown detection with fake timestamp
    local testCharCD = {
        name = "TestCrafter",
        classFile = "MAGE",
        tradeCooldowns = { ["Mooncloth"] = T0 - 100 }
    }
    local oldChars = CLIAltsDB and CLIAltsDB.characters
    CLIAltsDB.characters = { ["TestCrafter"] = testCharCD }
    local digestItems = self:GetLoginDigestItems(T0)
    local foundCD = false
    for _, it in ipairs(digestItems) do
        if it.cat == "cooldowns" then foundCD = true end
    end
    Assert(foundCD == true, "LoginDigest: ready cooldown detected when now >= readyAt")

    -- 4d. Toggling cooldowns off omits it from digest
    self:ToggleAlert("cooldowns", false)
    local digestItemsOff = self:GetLoginDigestItems(T0)
    local foundCDOff = false
    for _, it in ipairs(digestItemsOff) do
        if it.cat == "cooldowns" then foundCDOff = true end
    end
    Assert(foundCDOff == false, "LoginDigest: disabled category omitted from digest")
    self:ToggleAlert("cooldowns", true)
    CLIAltsDB.characters = oldChars

    -- 4e. FormatLoginDigestLines appends +N more (/ca digest) when items > 4
    local mock6Items = {
        { text = "Item 1", compact = "I1" },
        { text = "Item 2", compact = "I2" },
        { text = "Item 3", compact = "I3" },
        { text = "Item 4", compact = "I4" },
        { text = "Item 5", compact = "I5" },
        { text = "Item 6", compact = "I6" },
    }
    local formatted6 = self:FormatLoginDigestLines(mock6Items)
    Assert(#formatted6 == 3, "FormatLoginDigestLines: packs into 3 content lines (at most 5 boxed)")
    Assert(formatted6[3]:find("+2 more %(/ca digest%)") ~= nil, "FormatLoginDigestLines: appends +2 more (/ca digest)")

    -- 5. Leveling Session Planner & Burn Ratio Tests
    -- 5a. Short sample guard (< 1000 rested burned)
    local _, _, stBurn1 = self:EvaluateBurnRatio(500, 1000, 0.5, nil)
    Assert(stBurn1 == "SHORT_SAMPLE", "EvaluateBurnRatio: guards against short samples (<1000 rested)")

    -- 5b. Match within 5% drift
    local infB2, driftB2, stBurn2 = self:EvaluateBurnRatio(2000, 4000, 0.5, nil)
    Assert(stBurn2 == "MATCH" and infB2 == 0.5 and math.abs(driftB2) < 0.001, "EvaluateBurnRatio: matches standard 0.50 burn ratio")

    -- 5c. Drift detected (observed 0.75, current 0.50) -> PENDING on 1st sample
    local infB3, _, stBurn3 = self:EvaluateBurnRatio(3000, 4000, 0.5, nil)
    Assert(stBurn3 == "PENDING" and infB3 == 0.75, "EvaluateBurnRatio: detects drift to 0.75 and sets PENDING on 1st sample")

    -- 5d. Second consistent sample confirms burn ratio change
    local infB4, _, stBurn4 = self:EvaluateBurnRatio(3000, 4000, 0.5, 0.75)
    Assert(stBurn4 == "CONFIRMED" and infB4 == 0.75, "EvaluateBurnRatio: confirms burn ratio 0.75 on 2nd sample")

    -- 5e. GenerateLevelingPlan allocation & ordering
    local mockAlts = {
        {
            name = "Thor",
            classFile = "WARRIOR",
            level = 30,
            maxLevel = 60,
            maxXP = 20000,
            restedXP = 10000,
            xpHour = 20000,
            lastUpdate = T0,
            loggedOutInRestZone = true,
        },
        {
            name = "Ase",
            classFile = "PRIEST",
            level = 20,
            maxLevel = 60,
            maxXP = 15000,
            restedXP = 5000,
            xpHour = 10000,
            lastUpdate = T0,
            loggedOutInRestZone = true,
        },
    }
    local planSched, planSummary, totalAlloc, targetMins = self:GenerateLevelingPlan(1.5, mockAlts, T0)
    Assert(#planSched == 2, "GenerateLevelingPlan: allocates across both mock alts")
    Assert(totalAlloc == 90 and targetMins == 90, "GenerateLevelingPlan: allocates exactly requested 90 minutes")
    Assert(planSched[1].name == "Thor" and planSched[1].mins == 60, "GenerateLevelingPlan: Thor allocated 60m")
    Assert(planSched[2].name == "Ase" and planSched[2].mins == 30, "GenerateLevelingPlan: Ase allocated 30m")
    Assert(planSummary:find("Thor", 1, true) ~= nil and planSummary:find("60m", 1, true) ~= nil and planSummary:find("Ase", 1, true) ~= nil and planSummary:find("30m", 1, true) ~= nil, "GenerateLevelingPlan: formatted summary contains 'Thor 60m, then Ase 30m'")

    -- 6. Per-Alt Notes Tests
    local testNoteChar = { name = "Thorin", classFile = "WARRIOR", level = 60 }
    local oldCharsN = CLIAltsDB and CLIAltsDB.characters
    CLIAltsDB.characters = CLIAltsDB.characters or {}
    CLIAltsDB.characters["Thorin"] = testNoteChar
    local _, okN1 = self:SetCharacterNote("thor", "farm mooncloth", false)
    Assert(okN1 == true and testNoteChar.note == "farm mooncloth", "SetCharacterNote: sets note using prefix match 'thor'")
    local msgN2, okN2 = self:SetCharacterNote("Thorin", nil, false)
    Assert(okN2 == true and msgN2:find("farm mooncloth", 1, true) ~= nil, "SetCharacterNote: queries existing note")
    local _, okN3 = self:SetCharacterNote("thor", "clear", false)
    Assert(okN3 == true and testNoteChar.note == nil, "SetCharacterNote: clears note with 'clear'")
    CLIAltsDB.characters["Thorin"] = nil
    CLIAltsDB.characters = oldCharsN

    -- 7. Lockout Gap Finder Tests
    local mockLockAlts = {
        {
            name = "RaidWarrior",
            classFile = "WARRIOR",
            level = 60,
            lockouts = {},
        },
        {
            name = "RaidRogue",
            classFile = "ROGUE",
            level = 60,
            lockouts = {
                ["Molten Core"] = { resetTime = T0 + 86400, id = 12345 }
            },
        },
        {
            name = "LowLevelAlt",
            classFile = "HUNTER",
            level = 45,
            lockouts = {},
        },
    }
    local uList, lList, cNameU, minLvlU, errU = self:GetUnlockedAlts('"Molten Core"', T0, mockLockAlts)
    Assert(errU == nil and cNameU == "Molten Core" and minLvlU == 60, "GetUnlockedAlts: resolves Molten Core and level 60")
    Assert(#uList == 1 and uList[1].name == "RaidWarrior", "GetUnlockedAlts: identifies RaidWarrior as unlocked")
    Assert(#lList == 1 and lList[1].name == "RaidRogue", "GetUnlockedAlts: identifies RaidRogue as locked")
    local uList2, _, cNameU2 = self:GetUnlockedAlts("mc", T0, mockLockAlts)
    Assert(cNameU2 == "Molten Core" and #uList2 == 1, "GetUnlockedAlts: alias 'mc' resolves to Molten Core")

    -- 7d. Substring query shorter than 3 characters rejected unless in KNOWN_INSTANCES
    local _, _, _, _, errShort = self:GetUnlockedAlts("a", T0, mockLockAlts)
    Assert(errShort ~= nil, "GetUnlockedAlts: rejects query shorter than 3 characters")

    -- 7e. Unknown instance fallback minLevel respects GetMaxLevel()
    local _, _, _, minLvlUnknown = self:GetUnlockedAlts("UnknownInstance", T0, mockLockAlts)
    Assert(minLvlUnknown == self:GetMaxLevel(), "GetUnlockedAlts: fallback minLevel respects GetMaxLevel()")

    -- 8. Watchlist Item ID Parsing & Dropping Counts Tests
    -- 8a. Item link parsing: extracts numeric item ID 14047
    local rawLink = "|cffffffff|Hitem:14047:0:0:0:0:0:0:0:0|h[Runecloth]|h|r"
    local resolvedId = self:ResolveWatchItem(rawLink)
    Assert(resolvedId == 14047 and type(resolvedId) == "number", "ResolveWatchItem: parses numeric ID 14047 from item link")

    -- 8b. Numeric string parsing
    local resolvedNum = self:ResolveWatchItem("14047")
    Assert(resolvedNum == 14047 and type(resolvedNum) == "number", "ResolveWatchItem: parses numeric string '14047' to number")

    -- 8c. AddWatchItem stores item ID
    local oldWatchlist = CLIAltsDB and CLIAltsDB.watchlist
    local oldCharsW = CLIAltsDB and CLIAltsDB.characters
    CLIAltsDB.watchlist = {}
    CLIAltsDB.characters = {}

    local okAdd1, itemAdd1 = self:AddWatchItem(rawLink)
    Assert(okAdd1 == true and itemAdd1 == 14047 and CLIAltsDB.watchlist[1] == 14047, "AddWatchItem: stores item ID 14047 in watchlist")

    -- 8d. Duplicate check matches ID vs link
    local okAddDup, _ = self:AddWatchItem(14047)
    Assert(okAddDup == false, "AddWatchItem: rejects duplicate watch item by ID")

    -- 8e. Dropping counts on RemoveWatchItem across alts
    local mockAltW = {
        name = "TailorAlt",
        classFile = "MAGE",
        watchlistCounts = { [14047] = 80, ["Iron Ore"] = 25 }
    }
    CLIAltsDB.characters["TailorAlt"] = mockAltW

    -- Before removal, CollectWatchlistCounts preserves 14047 but drops untracked "Iron Ore"
    local collectedCounts = self:CollectWatchlistCounts(mockAltW.watchlistCounts)
    Assert(collectedCounts[14047] == 80 and collectedCounts["Iron Ore"] == nil, "CollectWatchlistCounts: drops untracked 'Iron Ore' key")

    -- Remove 14047: drops from watchlist and wipes count from mockAltW
    local okRem1, _ = self:RemoveWatchItem(rawLink)
    Assert(okRem1 == true and #CLIAltsDB.watchlist == 0, "RemoveWatchItem: removes item using link")
    Assert(mockAltW.watchlistCounts[14047] == nil, "CleanWatchlistCounts: dropped removed item 14047 from character record")

    CLIAltsDB.watchlist = oldWatchlist
    CLIAltsDB.characters = oldCharsW

    -- 9. Hearthstone Location, Stale Flag & Prune Tests
    -- 9a. Inactive calculation
    local charOld = { name = "OldAlt", classFile = "WARRIOR", lastUpdate = T0 - (45 * 86400) }
    local daysOld = self:GetDaysInactive(charOld, T0)
    Assert(daysOld == 45, "GetDaysInactive: calculates 45 days inactive")

    -- 9b. Stale threshold check
    local isStale1 = self:IsCharStale(charOld, 30, T0)
    Assert(isStale1 == true, "IsCharStale: flags alt inactive for 45 days as stale at 30d threshold")
    local isStale2 = self:IsCharStale(charOld, 60, T0)
    Assert(isStale2 == false, "IsCharStale: does not flag alt inactive for 45 days when threshold is 60d")

    -- 9c. Current player protection
    self.curPlayerKey = "LiveChar"
    local charLive = { key = "LiveChar", name = "LiveChar", lastUpdate = T0 - (100 * 86400) }
    local isStaleLive = self:IsCharStale(charLive, 30, T0)
    Assert(isStaleLive == false, "IsCharStale: current player is NEVER flagged stale")

    -- 9d. Bulk prune identification
    local oldCharsP = CLIAltsDB and CLIAltsDB.characters
    CLIAltsDB.characters = { ["OldAlt"] = charOld, ["LiveChar"] = charLive }
    local pruneCount, pruneList = self:GetPrunableCharacters(30, T0)
    Assert(pruneCount == 1 and pruneList[1] == "OldAlt", "GetPrunableCharacters: identifies only OldAlt for pruning")

    -- 9e. Bulk prune execution
    local prunedCount, prunedNames = self:PruneCharacters(30, T0)
    Assert(prunedCount == 1 and prunedNames[1] == "OldAlt", "PruneCharacters: prunes OldAlt")
    Assert(CLIAltsDB.characters["OldAlt"] == nil and CLIAltsDB.characters["LiveChar"] ~= nil, "PruneCharacters: removes OldAlt while preserving current player LiveChar")

    -- 9f. Hearthstone location field
    local mockCharH = { name = "HearthAlt", bindLocation = "The Crossroads" }
    Assert(mockCharH.bindLocation == "The Crossroads", "Hearthstone: preserves bindLocation field")

    CLIAltsDB.characters = oldCharsP
    self.curPlayerKey = nil

    -- 10. LibDataBroker Tests
    -- 10a. FormatWasteShort tests
    Assert(self:FormatWasteShort(0) == "0", "FormatWasteShort: 0 yields '0'")
    Assert(self:FormatWasteShort(500) == "500", "FormatWasteShort: 500 yields '500'")
    Assert(self:FormatWasteShort(12000) == "12k", "FormatWasteShort: 12000 yields '12k'")
    Assert(self:FormatWasteShort(1500000) == "1.5M", "FormatWasteShort: 1500000 yields '1.5M'")

    -- 10b. GetLDBText with uncapped characters -> "Alts: 0 capped | 0 waste"
    local mockUncapped = {
        { name = "Alt1", level = 20, maxXP = 20000, restedXP = 1000, lastUpdate = T0, loggedOutInRestZone = true }
    }
    local ldbText1, cap1, waste1 = self:GetLDBText(T0, mockUncapped)
    Assert(ldbText1 == "Alts: 0 capped | 0 waste" and cap1 == 0 and waste1 == 0, "GetLDBText: uncapped chars yield 'Alts: 0 capped | 0 waste'")

    -- 10c. GetLDBText with 3 capped characters with 12k total waste -> "Alts: 3 capped | 12k waste"
    local mockCapped3 = {
        { name = "Capped1", level = 20, maxXP = 20000, restedXP = 30000, lastUpdate = T0, loggedOutInRestZone = true },
        { name = "Capped2", level = 20, maxXP = 20000, restedXP = 30000, lastUpdate = T0, loggedOutInRestZone = true },
        { name = "Capped3", level = 20, maxXP = 20000, restedXP = 30000, lastUpdate = T0, loggedOutInRestZone = true },
    }
    local ldbText2, cap2, waste2 = self:GetLDBText(T0 + 115200, mockCapped3)
    Assert(ldbText2 == "Alts: 3 capped | 12k waste" and cap2 == 3 and waste2 == 12000, "GetLDBText: 3 capped alts with 12k waste yield 'Alts: 3 capped | 12k waste'")

    -- 10d. LibDataBroker silent fallback when absent
    if self.InitLDB and not (LibStub and LibStub("LibDataBroker-1.1", true)) then
        local ldbObj = self:InitLDB()
        Assert(ldbObj == nil, "InitLDB: returns nil cleanly when LibDataBroker-1.1 is absent")
    end

    -- 11. Theme Verification & Compact Mode Tests
    -- 11a. Colorblind, Amber, Synthwave, Dracula Themes
    if self.THEMES then
        local cbTheme = self.THEMES["COLORBLIND"]
        Assert(cbTheme ~= nil, "Colorblind: COLORBLIND theme exists in THEMES")
        Assert(cbTheme and cbTheme.tag == "SAFE", "Colorblind: theme tag is 'SAFE'")
        Assert(cbTheme and cbTheme.highlightHex == "ffd933", "Colorblind: high-contrast amber highlightHex is ffd933")

        local ambTheme = self.THEMES["AMBER"]
        Assert(ambTheme ~= nil, "Theme: AMBER theme exists in THEMES")
        Assert(ambTheme and ambTheme.tag == "AMB", "Theme: AMBER tag is 'AMB'")

        local synTheme = self.THEMES["SYNTHWAVE"]
        Assert(synTheme ~= nil, "Theme: SYNTHWAVE theme exists in THEMES")
        Assert(synTheme and synTheme.tag == "SYN", "Theme: SYNTHWAVE tag is 'SYN'")

        local draTheme = self.THEMES["DRACULA"]
        Assert(draTheme ~= nil, "Theme: DRACULA theme exists in THEMES")
        Assert(draTheme and draTheme.tag == "DRA", "Theme: DRACULA tag is 'DRA'")
    end

    -- 11b. Compact Mode Toggle & Column Filtering
    local oldCompact = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.compactMode
    CLIAltsDB.settings.compactMode = false
    Assert(self:IsCompact() == false, "CompactMode: IsCompact reports false when disabled")
    self:ToggleCompact()
    Assert(self:IsCompact() == true, "CompactMode: ToggleCompact flips state to true")

    if self.GetColumns then
        CLIAltsDB.settings.compactMode = false
        local fullCols1 = self:GetColumns(1)
        CLIAltsDB.settings.compactMode = true
        local compCols1 = self:GetColumns(1)
        local hasEtaFull = false
        for _, col in ipairs(fullCols1) do if col.key == "eta" then hasEtaFull = true end end
        local hasEtaComp = false
        for _, col in ipairs(compCols1) do if col.key == "eta" then hasEtaComp = true end end
        Assert(hasEtaFull == true and hasEtaComp == false, "CompactMode: hides ETA column in Tab 1")
    end

    CLIAltsDB.settings.compactMode = oldCompact

    -- 12. Live Path Integration Test (Fake CLIAltsDB: GetCharactersList -> GetRestedData -> GenerateLevelingPlan)
    local backupDB = CLIAltsDB
    local liveTestOk, liveTestErr = pcall(function()
        local testTime = 1700000000
        CLIAltsDB = {
            settings = {
                restedBurnRatio = 0.5,
                wellRestedRank = 0,
                maxLevel = 60,
                sortBy = "name",
                sortAsc = true,
            },
            characters = {
                ["Thor-Pyrewood"] = {
                    name = "Thor",
                    realm = "Pyrewood",
                    faction = "Alliance",
                    race = "Dwarf",
                    class = "Paladin",
                    classFile = "PALADIN",
                    level = 30,
                    xp = 10000,
                    maxXP = 20000,
                    restedXP = 15000,
                    lastUpdate = testTime - 86400,
                    isResting = true,
                    cleanLogout = true,
                    xpHour = 20000,
                    money = 50000,
                },
                ["Ase-Pyrewood"] = {
                    name = "Ase",
                    realm = "Pyrewood",
                    faction = "Alliance",
                    race = "Human",
                    class = "Mage",
                    classFile = "MAGE",
                    level = 45,
                    xp = 5000,
                    maxXP = 50000,
                    restedXP = 25000,
                    lastUpdate = testTime - 43200,
                    isResting = false,
                    cleanLogout = true,
                    xpHour = 0,
                    money = 120000,
                },
                ["Max-Pyrewood"] = {
                    name = "Max",
                    realm = "Pyrewood",
                    faction = "Alliance",
                    race = "Gnome",
                    class = "Warlock",
                    classFile = "WARLOCK",
                    level = 60,
                    xp = 0,
                    maxXP = 100000,
                    restedXP = 0,
                    lastUpdate = testTime,
                    money = 999999,
                }
            }
        }

        local list = self:GetCharactersList()
        Assert(#list == 3, "LivePath: GetCharactersList retrieves all 3 characters from fake CLIAltsDB")

        local thorChar = list[3]
        local restedThor = self:GetRestedData(thorChar, false, testTime)
        Assert(type(restedThor) == "table", "LivePath: GetRestedData returns table for character")
        Assert(type(restedThor.currentRested) == "number", "LivePath: GetRestedData currentRested is numeric")

        -- Generate leveling plan through live path (mockChars = nil)
        local planSchedule, planSummary, allocated = self:GenerateLevelingPlan(2, nil, testTime)
        Assert(type(planSchedule) == "table", "LivePath: GenerateLevelingPlan live path succeeds without error")
        Assert(#planSchedule >= 1, "LivePath: GenerateLevelingPlan generates schedule for eligible alts")
        Assert(type(allocated) == "number" and allocated > 0, "LivePath: Session minutes allocated successfully")
        Assert(type(planSummary) == "string", "LivePath: Plan summary text returned")

        local aseFound = nil
        for _, it in ipairs(planSchedule) do
            if it.name == "Ase" then aseFound = it end
        end
        Assert(aseFound ~= nil and aseFound.isFallbackRate == true, "LivePath: Unobserved alt marked as fallback rate (~)")
    end)
    CLIAltsDB = backupDB
    if not liveTestOk then
        Assert(false, "LivePath: Exception during live path integration test: " .. tostring(liveTestErr))
    end

    -- 13. Backup & Restore Tests (/clialts backup, /clialts restore)
    local testBackupDB = {
        characters = {
            ["TestHero"] = { name = "TestHero", level = 20, maxXP = 20000, restedXP = 5000 },
        },
        settings = { theme = "AMBER" },
        dbVersion = 3,
    }
    local oldLiveDB = CLIAltsDB
    CLIAltsDB = testBackupDB

    -- 13a. Create backup
    local okB1, _ = self:BackupDB("test")
    Assert(okB1 == true and CLIAltsDB.backup ~= nil, "BackupDB: creates backup slot in CLIAltsDB.backup")
    Assert(CLIAltsDB.backup.characters ~= nil and CLIAltsDB.backup.characters["TestHero"] ~= nil, "BackupDB: backup contains copy of character data")

    -- 13b. Modifying live DB does not mutate backup slot (deep copy isolation)
    CLIAltsDB.characters["TestHero"].level = 25
    CLIAltsDB.characters["NewAlt"] = { name = "NewAlt", level = 1 }
    Assert(CLIAltsDB.backup.characters["TestHero"].level == 20, "BackupDB: deep copy isolates backup from live character mutation")
    Assert(CLIAltsDB.backup.characters["NewAlt"] == nil, "BackupDB: deep copy isolates backup from new alt additions")

    -- 13c. RestoreDB restores previous state and preserves backup slot
    local okR1, _ = self:RestoreDB()
    Assert(okR1 == true, "RestoreDB: executes restore cleanly")
    Assert(CLIAltsDB.characters["TestHero"].level == 20, "RestoreDB: character restored to backup level 20")
    Assert(CLIAltsDB.characters["NewAlt"] == nil, "RestoreDB: removed unbacked alt upon restore")
    Assert(CLIAltsDB.backup ~= nil, "RestoreDB: preserves one-slot backup after restore")

    -- 14. UI & Slash Command Integration Tests (/clialts, /clialts help, minimap click)
    if SlashCmdList and SlashCmdList["CLIALTS"] then
        -- 14a. Slash command with no args toggles main window
        local slashOk, slashErr = pcall(function()
            SlashCmdList["CLIALTS"]("")
        end)
        Assert(slashOk == true, "SlashCommand: /clialts with empty arg toggles main window without error: " .. tostring(slashErr))

        -- 14b. Slash command with 'help' opens guide popup
        local helpOk, _ = pcall(function()
            SlashCmdList["CLIALTS"]("help")
        end)
        Assert(helpOk == true, "SlashCommand: /clialts help opens help popup without error")
    end

    -- 14c. Minimap button click handlers
    local btn = self.CreateMinimapButton and self:CreateMinimapButton()
    if btn and btn.GetScript then
        local clickFn = btn:GetScript("OnClick")
        Assert(type(clickFn) == "function", "Minimap: OnClick handler registered on minimap button")
        if clickFn then
            local clickOk, _ = pcall(clickFn, btn, "LeftButton")
            Assert(clickOk == true, "Minimap: LeftButton click executes cleanly")
        end

        local dragStopFn = btn:GetScript("OnDragStop")
        if dragStopFn then
            local dragOk, _ = pcall(dragStopFn, btn)
            Assert(dragOk == true, "Minimap: OnDragStop executes cleanly")
        end
    end

    -- 15. Resting Zone & Location Detection Tests
    -- 15a. Location pattern matching for inns, cities, and resting subzones
    Assert(self:IsLocationResting("Lion's Pride Inn") == true, "IsLocationResting: 'Lion's Pride Inn' is resting")
    Assert(self:IsLocationResting("Stormwind City (Cathedral Square)") == true, "IsLocationResting: 'Stormwind City (Cathedral Square)' is resting")
    Assert(self:IsLocationResting("Dun Morogh (Thunderbrew Distillery)") == true, "IsLocationResting: 'Thunderbrew Distillery' is resting")
    Assert(self:IsLocationResting("Loch Modan (Stoutlager Inn)") == true, "IsLocationResting: 'Stoutlager Inn' is resting")
    Assert(self:IsLocationResting("Westfall") == false, "IsLocationResting: 'Westfall' is not resting")
    Assert(self:IsLocationResting("Elwynn Forest") == false, "IsLocationResting: 'Elwynn Forest' is not resting")

    -- 15b. Offline character resting determination with location fallback
    local altRestLocation = { name = "InnAlt", location = "Lion's Pride Inn", loggedOutInRestZone = false, isResting = false }
    Assert(self:IsCharacterResting(altRestLocation) == true, "IsCharacterResting: recognizes resting via location fallback")
    local altWildLocation = { name = "WildAlt", location = "Westfall", loggedOutInRestZone = false, isResting = false }
    Assert(self:IsCharacterResting(altWildLocation) == false, "IsCharacterResting: preserves wilderness when location is wild")
    local altExplicitInn = { name = "ExplicitInnAlt", loggedOutInRestZone = true }
    Assert(self:IsCharacterResting(altExplicitInn) == true, "IsCharacterResting: respects loggedOutInRestZone = true")

    -- 16. Retail Flavor Detection & Rested Math Guard Tests
    -- 16a. Classic / Default Flavor
    Assert(self:IsRetail() == false, "IsRetail: defaults to false in test environment")

    -- 16b. Retail Override and Perk Hard-Lock
    self.isRetailOverride = true
    Assert(self:IsRetail() == true, "IsRetail: returns true when isRetailOverride is true")
    Assert(self:GetClientFlavor() == "Retail", "GetClientFlavor: returns 'Retail' when overridden")

    local oldR = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.wellRestedRank
    if CLIAltsDB and CLIAltsDB.settings then
        CLIAltsDB.settings.wellRestedRank = 5
    end
    local restedRetail = self:GetRestedData(charInn, true, T0 + 28800)
    Assert(restedRetail.perkRank == 0, "IsRetail: enforces perkRank = 0 on Retail even if wellRestedRank is 5")
    Assert(restedRetail.maxPercent == 150, "IsRetail: enforces 150% rested cap on Retail")
    Assert(restedRetail.speedMult == 1.0, "IsRetail: enforces 1.0x baseline speed multiplier on Retail")

    -- 16c. Guard against perk rank modification in Retail
    self:SetWellRestedRank(3)
    Assert(CLIAltsDB.settings.wellRestedRank == 5, "SetWellRestedRank: guards against modifying perk rank on Retail")

    if CLIAltsDB and CLIAltsDB.settings then
        CLIAltsDB.settings.wellRestedRank = oldR
    end
    self.isRetailOverride = nil
    Assert(self:IsRetail() == false, "IsRetail: resets cleanly when isRetailOverride is cleared")

    CLIAltsDB = oldLiveDB

    -- 17. Cross-Character Inventory Scanner & Tooltip Summary Tests (Feature 6)
    local testInvDB = {
        settings = {
            showInventoryTooltips = true,
            sortBy = "name",
            sortAsc = true,
        },
        characters = {
            ["CharA-Realm1"] = {
                name = "CharA",
                realm = "Realm1",
                classFile = "MAGE",
                inventory = {
                    [14047] = { bag = 40, bank = 100 }, -- Runecloth: 40 in bags, 100 in bank
                    [2447]  = { bag = 15 },             -- Peacebloom: 15 in bags
                },
            },
            ["CharB-Realm1"] = {
                name = "CharB",
                realm = "Realm1",
                classFile = "ROGUE",
                inventory = {
                    [14047] = { bag = 20, bank = 30 },  -- Runecloth: 20 in bags, 30 in bank
                    [7005]  = { bank = 5 },             -- Skinning Knife in bank
                },
            },
            ["CharC-Realm2"] = {
                name = "CharC",
                realm = "Realm2",
                classFile = "PRIEST",
                inventory = {
                    [14047] = { bank = 50 },            -- Runecloth: 50 in bank
                },
            },
        },
    }
    local oldInvTestDB = CLIAltsDB
    CLIAltsDB = testInvDB

    -- 17a. GetItemInventorySummary aggregates all alts
    local totRune, breakRune, idRune = self:GetItemInventorySummary(14047)
    Assert(totRune == 240, "GetItemInventorySummary: Runecloth total equals 240 across 3 alts")
    Assert(#breakRune == 3, "GetItemInventorySummary: Runecloth returns 3 character entries")
    Assert(idRune == 14047, "GetItemInventorySummary: returns resolved itemID 14047")

    -- 17b. Character breakdown verifies bag and bank counts
    local charAEntry, charBEntry, charCEntry
    for _, b in ipairs(breakRune) do
        if b.name == "CharA" then charAEntry = b end
        if b.name == "CharB" then charBEntry = b end
        if b.name == "CharC" then charCEntry = b end
    end
    Assert(charAEntry and charAEntry.bag == 40 and charAEntry.bank == 100 and charAEntry.total == 140,
        "GetItemInventorySummary: CharA has 40 bags, 100 bank, 140 total")
    Assert(charBEntry and charBEntry.bag == 20 and charBEntry.bank == 30 and charBEntry.total == 50,
        "GetItemInventorySummary: CharB has 20 bags, 30 bank, 50 total")
    Assert(charCEntry and (charCEntry.bag == 0 or not charCEntry.bag) and charCEntry.bank == 50 and charCEntry.total == 50,
        "GetItemInventorySummary: CharC has 0 bags, 50 bank, 50 total")

    -- 17c. Item present on only one character
    local totPeace, breakPeace = self:GetItemInventorySummary(2447)
    Assert(totPeace == 15 and #breakPeace == 1 and breakPeace[1].name == "CharA",
        "GetItemInventorySummary: Peacebloom found only on CharA (15 in bags)")

    -- 17d. Item not present on any alt yields 0 and empty table
    local totNone, breakNone = self:GetItemInventorySummary(999999)
    Assert(totNone == 0 and #breakNone == 0, "GetItemInventorySummary: non-existent item yields 0 and empty breakdown")

    -- 17e. AddInventoryInfoToTooltip formatting
    if self.AddInventoryInfoToTooltip then
        local mockTooltip = {
            lines = {},
            AddDoubleLine = function(self, left, right)
                table.insert(self.lines, { left = left, right = right })
            end,
        }
        self:AddInventoryInfoToTooltip(mockTooltip, 14047)
        Assert(#mockTooltip.lines >= 4, "AddInventoryInfoToTooltip: appends header line plus 3 alt lines")
        Assert(mockTooltip.lines[1].left:find("%[CLIAlts%]"), "AddInventoryInfoToTooltip: header contains '[CLIAlts]'")

        -- Verify idempotency / deduplication (no stacking if invoked again on same draw)
        self:AddInventoryInfoToTooltip(mockTooltip, 14047)
        Assert(#mockTooltip.lines == 4, "AddInventoryInfoToTooltip: prevents duplicate lines on re-entry")

        -- 17f. Settings toggle showInventoryTooltips = false disables tooltip lines
        CLIAltsDB.settings.showInventoryTooltips = false
        local mockTooltip2 = {
            lines = {},
            shown = false,
            AddDoubleLine = function(self, left, right)
                table.insert(self.lines, { left = left, right = right })
            end,
            Show = function(self) self.shown = true end,
        }
        self:AddInventoryInfoToTooltip(mockTooltip2, 14047)
        Assert(#mockTooltip2.lines == 0, "AddInventoryInfoToTooltip: does not add lines when showInventoryTooltips is false")
        CLIAltsDB.settings.showInventoryTooltips = true
    end

    -- 17g. CollectInventory bank preservation
    local existingCharInv = {
        [14047] = { bag = 10, bank = 80 },
        [2447]  = { bank = 20 },
    }
    local mergedInv, wasBank = self:CollectInventory(existingCharInv, false)
    Assert(wasBank == false, "CollectInventory: wasBank returns false when bank is not open")
    Assert(mergedInv[14047] and mergedInv[14047].bank == 80, "CollectInventory: preserves existing bank count for item 14047")
    Assert(mergedInv[2447] and mergedInv[2447].bank == 20, "CollectInventory: preserves existing bank count for item 2447")

    CLIAltsDB = oldInvTestDB

    do -- 18. WoW Forever Cohort & Role Categorization Tests (Component 1)
    local testCohortDB = {
        settings = {
            foreverMode = true,
            sortBy = "cohort",
            sortAsc = true,
        },
        characters = {
            ["Main-Realm"] = { name = "Main", level = 30, tier = "CORE", target_level = 35, supply_role = "Tailor/Bags" },
            ["Alt2-Realm"] = { name = "Alt2", level = 25, tier = "RESERVE", target_level = 25, supply_role = "Alch/DE" },
            ["Bank-Realm"] = { name = "Bank", level = 1, tier = "BANK", target_level = 1, supply_role = "Storage" },
            ["New-Realm"]  = { name = "New",  level = 10, tier = "UNASSIGNED", target_level = 60 },
        },
    }
    local oldCohortDB = CLIAltsDB
    CLIAltsDB = testCohortDB

    -- 18a. IsForeverMode and ToggleForeverMode
    Assert(self:IsForeverMode() == true, "Cohort: IsForeverMode returns true when enabled")
    self:ToggleForeverMode()
    Assert(self:IsForeverMode() == false, "Cohort: ToggleForeverMode flips to false")
    self:ToggleForeverMode()
    Assert(self:IsForeverMode() == true, "Cohort: ToggleForeverMode flips back to true")

    -- 18b. GetCohortCounts
    local cCore, cRes, cBank, cUnassigned = self:GetCohortCounts()
    Assert(cCore == 1 and cRes == 1 and cBank == 1 and cUnassigned == 1, "Cohort: GetCohortCounts returns 1 Core, 1 Res, 1 Bank, 1 Unassigned")

    -- 18c. SetCharacterRole and default targets
    local okRole1, _ = self:SetCharacterRole("New", "CORE", "Miner/BS", nil)
    Assert(okRole1 == true and testCohortDB.characters["New-Realm"].tier == "CORE", "Cohort: SetCharacterRole updates tier to CORE")
    Assert(testCohortDB.characters["New-Realm"].target_level == 35, "Cohort: CORE tier defaults target_level to 35")
    Assert(testCohortDB.characters["New-Realm"].supply_role == "Miner/BS", "Cohort: SetCharacterRole updates supply_role")

    -- 18c2. SetCharacterSupplyRole and FormatCohortSummary
    local okSupply1, _ = self:SetCharacterSupplyRole("New", "Tailor/Bags")
    Assert(okSupply1 == true and testCohortDB.characters["New-Realm"].supply_role == "Tailor/Bags", "Cohort: SetCharacterSupplyRole updates supply_role")
    local okSupplyClear, _ = self:SetCharacterSupplyRole("New", "auto")
    Assert(okSupplyClear == true and testCohortDB.characters["New-Realm"].supply_role == nil, "Cohort: SetCharacterSupplyRole 'auto' clears supply_role")
    Assert(self:FormatCohortSummary() == "2 Core | 1 Alt | 1 Bank", "Cohort: FormatCohortSummary returns human-readable '2 Core | 1 Alt | 1 Bank'")

    -- 18d. CycleCharacterTier
    local cycledTier = self:CycleCharacterTier(testCohortDB.characters["New-Realm"])
    Assert(cycledTier == "RESERVE" and testCohortDB.characters["New-Realm"].target_level == 25, "Cohort: CycleCharacterTier advances CORE -> RESERVE with target 25")

    -- 18e. Target Level Reached detection (User constraint: UI wording must not show 'Parked')
    local charReached = testCohortDB.characters["Alt2-Realm"]
    local isReached = (charReached.level >= charReached.target_level)
    Assert(isReached == true, "Cohort: Alt2 (Lvl 25/25) satisfies target level reached")

    -- 18f. Cohort sorting (CORE -> RESERVE -> BANK -> UNASSIGNED)
    local sortedCohorts = self:GetCharactersList("cohort", true)
    Assert(#sortedCohorts == 4, "Cohort: GetCharactersList returns all 4 test alts")
    Assert(sortedCohorts[1].name == "Main" and sortedCohorts[1].tier == "CORE", "Cohort: 1st sorted alt is Core")
    Assert(sortedCohorts[2].name == "Alt2" or sortedCohorts[2].name == "New", "Cohort: 2nd sorted alt is Reserve")

    -- 18g. Cohort query filter
    local coreFiltered = self:GetCharactersList("name", true, "core")
    Assert(#coreFiltered == 1 and coreFiltered[1].name == "Main", "Cohort: filter 'core' returns only Core alts")
    local resFiltered = self:GetCharactersList("name", true, "reserve")
    Assert(#resFiltered == 2, "Cohort: filter 'reserve' returns both Reserve alts")

    -- 18h. Automatic Forever client detection via secondaryName
    local charWithSurname = { name = "Arthas", secondaryName = "Menethil", level = 10 }
    testCohortDB.characters["Arthas-Forever"] = charWithSurname
    Assert(self:IsForeverClient() == true, "Cohort: IsForeverClient detects presence of character with secondaryName")
    Assert(self:GetClientFlavor() == "WoW Forever", "Cohort: GetClientFlavor returns 'WoW Forever' when client has secondaryName")

    -- 18i. Cohort aliases (alt -> RESERVE, bank -> BANK, unassign -> UNASSIGNED)
    local okAltAlias, _ = self:SetCharacterCohort("Arthas", "alt")
    Assert(okAltAlias == true and charWithSurname.tier == "RESERVE" and charWithSurname.target_level == 25,
        "Cohort: SetCharacterCohort 'alt' alias maps to RESERVE with default target level 25")

    local okBankAlias, _ = self:SetCharacterCohort("Arthas", "bank")
    Assert(okBankAlias == true and charWithSurname.tier == "BANK" and charWithSurname.target_level == 1,
        "Cohort: SetCharacterCohort 'bank' alias maps to BANK with default target level 1")

    local okUnassignAlias, _ = self:SetCharacterCohort("Arthas", "unassign")
    Assert(okUnassignAlias == true and charWithSurname.tier == "UNASSIGNED" and charWithSurname.target_level == 60,
        "Cohort: SetCharacterCohort 'unassign' alias maps to UNASSIGNED with default target level 60")
    testCohortDB.characters["Arthas-Forever"] = nil

    CLIAltsDB = oldCohortDB
    end

    do -- 19. WoW Forever Smart Rotation Recommendation & Usable Rested Ranking Tests (Component 2)
    local testRotDB = {
        settings = {
            foreverMode = true,
            wellRestedRank = 5, -- 180% cap (+20%)
        },
        characters = {
            ["CoreLeveling"] = { name = "CoreLeveling", level = 28, maxXP = 20000, restedXP = 10000, lastUpdate = 1000000, tier = "CORE", target_level = 35, isResting = true },
            ["CoreCapped"]   = { name = "CoreCapped",   level = 30, maxXP = 20000, restedXP = 36000, lastUpdate = 1000000, tier = "CORE", target_level = 35, isResting = true },
            ["ReserveAccr"]  = { name = "ReserveAccr",  level = 20, maxXP = 15000, restedXP = 5000,  lastUpdate = 1000000, tier = "RESERVE", target_level = 25, isResting = true },
            ["TargetHit"]    = { name = "TargetHit",    level = 25, maxXP = 20000, restedXP = 20000, lastUpdate = 1000000, tier = "RESERVE", target_level = 25, isResting = true },
            ["BankMule"]     = { name = "BankMule",     level = 1,  maxXP = 400,   restedXP = 600,   lastUpdate = 1000000, tier = "BANK", target_level = 1, isResting = true },
        },
    }
    local oldRotDB = CLIAltsDB
    CLIAltsDB = testRotDB

    -- 19a. CalculateRotationScore classifications
    local scoreBank = self:CalculateRotationScore(testRotDB.characters["BankMule"], 1000000)
    Assert(scoreBank < -900000, "Rotation: Bank mule score is < -900,000 (" .. tostring(scoreBank) .. ")")

    local scoreHit = self:CalculateRotationScore(testRotDB.characters["TargetHit"], 1000000)
    Assert(scoreHit < -400000 and scoreHit > -600000, "Rotation: Target reached alt score is around -500,000 (" .. tostring(scoreHit) .. ")")

    local scoreCapped = self:CalculateRotationScore(testRotDB.characters["CoreCapped"], 1000000)
    Assert(scoreCapped >= 1000000, "Rotation: Capped alt score is >= 1,000,000 (" .. tostring(scoreCapped) .. ")")

    local scoreAccr = self:CalculateRotationScore(testRotDB.characters["CoreLeveling"], 1000000)
    Assert(scoreAccr > 0 and scoreAccr < 1000000, "Rotation: Accruing alt score is positive and < 1,000,000 (" .. tostring(scoreAccr) .. ")")

    -- 19b. GetNextAltsPriority excludes Bank and Target Hit alts
    local nextList = self:GetNextAltsPriority(1000000)
    Assert(#nextList == 3, "Rotation: GetNextAltsPriority returns exactly 3 active leveling alts (excludes Bank and TargetHit)")
    Assert(nextList[1].char.name == "CoreCapped", "Rotation: 1st priority is capped alt")
    Assert(nextList[1].maxPercent == 180, "Rotation: 180% cap reflected with Well Rested rank 5")
    Assert(nextList[1].tierTag == "[CORE]", "Rotation: Core cohort tag attached to priority item")

    -- 19c. Sorting by rotation in GetCharactersList
    local sortedRot = self:GetCharactersList("rotation", false)
    Assert(#sortedRot == 5, "Rotation: GetCharactersList returns all 5 alts")
    Assert(sortedRot[1].name == "CoreCapped", "Rotation sort: 1st is CoreCapped")
    Assert(sortedRot[4].name == "TargetHit", "Rotation sort: 4th (above bank) is TargetHit")
    Assert(sortedRot[5].name == "BankMule", "Rotation sort: 5th (last) is BankMule")

    -- 19d. FormatDateSafe resilience
    Assert(self:FormatDateSafe(0) == "Unknown", "FormatDateSafe: 0 returns Unknown")
    Assert(self:FormatDateSafe(nil) == "Unknown", "FormatDateSafe: nil returns Unknown")
    Assert(self:FormatDateSafe(-50) == "Unknown", "FormatDateSafe: negative returns Unknown")
    Assert(self:FormatDateSafe(1000000000) ~= "Unknown", "FormatDateSafe: valid timestamp returns date string")

    -- 19e. Dossier Popup modal rendering resilience
    if self.ShowDossierPopup then
        self:ShowDossierPopup(testRotDB.characters["CoreLeveling"])
        local dp = self.GetDossierPopup and self:GetDossierPopup()
        Assert(dp ~= nil, "Dossier: dossierPopup frame created")
        if dp then
            Assert(dp:IsShown() == true, "Dossier: popup is shown")
            local bodyTxt = dp.body and dp.body:GetText() or ""
            Assert(bodyTxt:find("CLIALTS :: ALT DOSSIER") ~= nil, "Dossier: header rendered in body text")
            Assert(bodyTxt:find("ROSTER COHORT") ~= nil, "Dossier: ROSTER COHORT rendered in body text")
            Assert(dp.btnRoleTailor ~= nil, "Dossier: btnRoleTailor created")
            Assert(dp.btnRoleAlch ~= nil, "Dossier: btnRoleAlch created")
            Assert(dp.btnRoleMiner ~= nil, "Dossier: btnRoleMiner created")
            Assert(dp.btnRoleLW ~= nil, "Dossier: btnRoleLW created")
            Assert(dp.btnRolePassive ~= nil, "Dossier: btnRolePassive created")
            Assert(dp.btnRoleAuto ~= nil, "Dossier: btnRoleAuto created")
            Assert(dp.btnRoleCustom ~= nil, "Dossier: btnRoleCustom created")
            Assert(dp.btnSetCore ~= nil, "Dossier: btnSetCore created")
            Assert(dp.btnSetAlt ~= nil, "Dossier: btnSetAlt created")
            Assert(dp.btnSetBank ~= nil, "Dossier: btnSetBank created")

            -- Test with minimal character (nil/sparse fields)
            self:ShowDossierPopup({ name = "SparseAlt" })
            local sparseTxt = dp.body and dp.body:GetText() or ""
            Assert(sparseTxt:find("SparseAlt") ~= nil, "Dossier: sparse alt rendered without crashing")
            dp:Hide()
            Assert(dp:IsShown() == false, "Dossier: popup successfully closed")
        end
    end

    CLIAltsDB = oldRotDB
    end

    do
    -- 20. WoW Forever Profession Milestone Thresholds & Training Alerts (Component 3)
    -- 20a. Profession abbreviations
    Assert(self:GetProfessionAbbr("Leatherworking") == "LW", "Professions: Leatherworking abbreviated to LW")
    Assert(self:GetProfessionAbbr("Tailoring") == "Tailor", "Professions: Tailoring abbreviated to Tailor")
    Assert(self:GetProfessionAbbr("Blacksmithing") == "BS", "Professions: Blacksmithing abbreviated to BS")
    Assert(self:GetProfessionAbbr("Alchemy") == "Alch", "Professions: Alchemy abbreviated to Alch")

    -- 20b. P2 Progress target (e.g. LW: 112/150 [P2 Target])
    local testCharLW = { name = "SkinnerAlt", level = 22, tier = "RESERVE" }
    local testProfLW = { name = "Leatherworking", rank = 112, maxRank = 150 }
    local mLW = self:GetProfessionMilestoneInfo(testCharLW, testProfLW)
    Assert(mLW ~= nil and mLW.targetMilestone == 150, "Professions: LW 112 target milestone is 150")
    Assert(mLW.targetPhase == "P2", "Professions: LW 112 target phase is P2")
    Assert(mLW.needed == 38, "Professions: LW 112 needs 38 skillups")
    Assert(mLW.canTrainNext == false, "Professions: LW 112 not ready to train next rank yet")
    local fmtLW = self:FormatProfessionMilestone(testCharLW, testProfLW, true)
    Assert(fmtLW == "LW: 112/150 [P2 Target]", "Professions: FormatProfessionMilestone compact matches user format 'LW: 112/150 [P2 Target]'")

    -- 20c. Capped alt eligible to train next rank (e.g. Tailor: 150/150 [TRAIN EXPERT])
    local testCharTailor = { name = "TailorAlt", level = 20, tier = "CORE" }
    local testProfTailor = { name = "Tailoring", rank = 150, maxRank = 150 }
    local mTailor = self:GetProfessionMilestoneInfo(testCharTailor, testProfTailor)
    Assert(mTailor.isCappedAtCurrentRank == true, "Professions: Tailor 150/150 is capped at Journeyman")
    Assert(mTailor.canTrainNext == true, "Professions: Tailor 150/150 at level 20 is eligible to train Expert")
    Assert(mTailor.nextRankTitle == "Expert", "Professions: Next rank title is Expert")
    local fmtTailor = self:FormatProfessionMilestone(testCharTailor, testProfTailor, true)
    Assert(fmtTailor:find("%[TRAIN EXPERT%]") ~= nil, "Professions: Tailor 150/150 formats with [TRAIN EXPERT] alert")

    -- 20d. Capped alt with character level bottleneck (e.g. Tailor: 150/150 [Req Lvl 20])
    local testCharLowLvl = { name = "LowLvlTailor", level = 16, tier = "RESERVE" }
    local mLowLvl = self:GetProfessionMilestoneInfo(testCharLowLvl, testProfTailor)
    Assert(mLowLvl.levelBottleneck == true, "Professions: Level 16 alt with 150/150 has level bottleneck")
    Assert(mLowLvl.nextReqLevel == 20, "Professions: Next required level is 20")
    local fmtLow = self:FormatProfessionMilestone(testCharLowLvl, testProfTailor, true)
    Assert(fmtLow:find("%[Req Lvl 20%]") ~= nil, "Professions: Level bottleneck formats with [Req Lvl 20]")

    -- 20e. Max rank profession (300/300 [DONE])
    local testCharMax = { name = "MaxCrafter", level = 60, tier = "CORE" }
    local testProfMax = { name = "Tailoring", rank = 300, maxRank = 300 }
    local fmtMax = self:FormatProfessionMilestone(testCharMax, testProfMax, true)
    Assert(fmtMax:find("%[DONE%]") ~= nil, "Professions: 300/300 formats with [DONE]")

    -- 20f. GetCharacterProfessionAlerts returns train alerts
    local alertsChar = { name = "AlertAlt", level = 20, professions = { primary = { testProfTailor } } }
    local profAlerts = self:GetCharacterProfessionAlerts(alertsChar)
    Assert(#profAlerts == 1 and profAlerts[1].type == "TRAIN", "Professions: GetCharacterProfessionAlerts returns TRAIN alert")
    Assert(profAlerts[1].tag == "[TRAIN EXPERT]", "Professions: Alert tag is [TRAIN EXPERT]")
    end

    do
    -- 21. Main Dashboard Redesign: Roster Summary Metrics and Profession Sorting
    local oldDashDB = CLIAltsDB
    local testDashDB = {
        settings = {
            sortBy = "level",
            sortAsc = false,
            theme = "amber",
        },
        characters = {
            ["AlphaCore"] = {
                name = "AlphaCore",
                level = 20,
                tier = "CORE",
                money = 125000,
                maxXP = 15000,
                restedXP = 27000,
                lastUpdate = time() - 7200,
                isResting = true,
                professions = { primary = { { name = "Tailoring", rank = 150, maxRank = 150 } } },
                tradeCooldowns = { ["Mooncloth"] = time() - 100 },
                lockouts = { ["RFC"] = time() + 3600 },
            },
            ["BetaAlt"] = {
                name = "BetaAlt",
                level = 15,
                tier = "RESERVE",
                money = 45000,
                maxXP = 10000,
                restedXP = 4000,
                lastUpdate = time(),
                isResting = true,
                professions = { primary = { { name = "Alchemy", rank = 75, maxRank = 150 } } },
            },
            ["GammaBank"] = {
                name = "GammaBank",
                level = 1,
                tier = "BANK",
                money = 500000,
                maxXP = 400,
                restedXP = 600,
                lastUpdate = time(),
                isResting = true,
            },
        },
    }
    CLIAltsDB = testDashDB

    -- 21a. GetRosterSummaryMetrics calculation accuracy
    local metrics = self:GetRosterSummaryMetrics()
    Assert(metrics ~= nil, "Dashboard: GetRosterSummaryMetrics returns non-nil table")
    Assert(metrics.totalAlts == 3, "Dashboard: totalAlts count is 3 (" .. tostring(metrics.totalAlts) .. ")")
    Assert(metrics.core == 1, "Dashboard: core count is 1")
    Assert(metrics.alt == 1, "Dashboard: reserve/alt count is 1")
    Assert(metrics.bank == 1, "Dashboard: bank count is 1")
    Assert(metrics.unassigned == 0, "Dashboard: unassigned count is 0")
    Assert(metrics.totalGold == (125000 + 45000 + 500000), "Dashboard: totalGold matches sum without double-counting (" .. tostring(metrics.totalGold) .. ")")
    Assert(metrics.readyCds == 1, "Dashboard: ready trade cooldowns counted accurately")
    Assert(metrics.activeLocks == 1, "Dashboard: active dungeon lockouts counted accurately")

    -- 21b. Profession column sorting in GetCharactersList
    local sortedByProf = self:GetCharactersList("prof", true)
    Assert(#sortedByProf == 3, "Dashboard: GetCharactersList with prof sort returns all alts")
    Assert(sortedByProf[1].name == "BetaAlt", "Dashboard: BetaAlt (Alchemy) sorted first alphabetically")
    Assert(sortedByProf[2].name == "AlphaCore", "Dashboard: AlphaCore (Tailoring) sorted second alphabetically")
    Assert(sortedByProf[3].name == "GammaBank", "Dashboard: GammaBank (No profs) sorted last")

    -- 21c. Cooldown sorting in GetCharactersList
    local sortedByCd = self:GetCharactersList("cooldown", true)
    Assert(#sortedByCd == 3, "Dashboard: GetCharactersList with cooldown sort returns all alts")
    Assert(sortedByCd[1].name == "AlphaCore", "Dashboard: AlphaCore (Ready cooldown) sorted first")

    -- 21d. Role sorting in GetCharactersList
    local sortedByRole = self:GetCharactersList("role", true)
    Assert(#sortedByRole == 3, "Dashboard: GetCharactersList with role sort returns all alts")
    Assert(sortedByRole[1].tier == "CORE", "Dashboard: CORE role sorted first")
    Assert(sortedByRole[2].tier == "RESERVE", "Dashboard: RESERVE/ALT role sorted second")
    Assert(sortedByRole[3].tier == "BANK", "Dashboard: BANK role sorted third")

    -- 21e. Context Menu & 7-Tab View Architectures
    if self.GetColumns then
        for tabId = 1, 7 do
            local cols = self:GetColumns(tabId)
            Assert(cols ~= nil and #cols > 0, "Navigation: Tab " .. tabId .. " returns valid column definitions")
        end
        local econCols = self:GetColumns(5)
        local goldCol = nil
        for _, c in ipairs(econCols) do
            if c.key == "gold" then goldCol = c break end
        end
        Assert(goldCol ~= nil and (goldCol.padRight or 0) >= 20, "EconomyTab: Gold column has at least 20px right padding before Last Zone")
    end
    if self.ShowRowContextMenu then
        self:ShowRowContextMenu(nil, testDashDB.characters["AlphaCore"])
        local cm = self.GetContextMenu and self:GetContextMenu()
        Assert(cm ~= nil, "Interactions: Context menu frame created successfully")
        if cm then
            Assert(cm:IsShown() == true, "Interactions: Context menu is shown on invocation")
            Assert(cm.buttons ~= nil and #cm.buttons == 8, "Interactions: Context menu has 8 actionable buttons")
            cm:Hide()
            Assert(cm:IsShown() == false, "Interactions: Context menu dismissed safely")
        end
    end

    CLIAltsDB = oldDashDB
    end

    do -- 22. WoW Forever Automated Dungeon Quest Tracker Tests (Component 4)
    local oldDngDB = CLIAltsDB
    local testDngDB = {
        settings = {
            foreverMode = true,
            activeTab = 1,
        },
        characters = {
            ["Grom-Forever"] = {
                name = "Grom-Forever",
                faction = "Horde",
                class = "Warrior",
                classFile = "WARRIOR",
                level = 10,
                tier = "CORE",
                dungeonQuests = {},
                activeQuests = {},
            },
            ["Thrall-Forever"] = {
                name = "Thrall-Forever",
                faction = "Horde",
                class = "Shaman",
                classFile = "SHAMAN",
                level = 15,
                tier = "CORE",
                dungeonQuests = {},
                activeQuests = {},
            },
            ["Baine-Forever"] = {
                name = "Baine-Forever",
                faction = "Horde",
                class = "Druid",
                classFile = "DRUID",
                level = 20,
                tier = "RESERVE",
                dungeonQuests = {
                    [870] = true,
                },
                activeQuests = {
                    [871] = true,
                },
            },
            ["Anduin-Forever"] = {
                name = "Anduin-Forever",
                faction = "Alliance",
                class = "Priest",
                classFile = "PRIEST",
                level = 20,
                tier = "CORE",
                dungeonQuests = {
                    [155] = true,
                    [166] = true,
                    [167] = true,
                },
                activeQuests = {},
            },
            ["Rexxar-Forever"] = {
                name = "Rexxar-Forever",
                faction = "Horde",
                class = "Hunter",
                classFile = "HUNTER",
                level = 16,
                tier = "CORE",
                dungeonQuests = {
                    [5722] = true, [5723] = true, [5724] = true, [5725] = true, [5726] = true, [5727] = true, [5728] = true,
                    [5721] = true, [5729] = true, [5730] = true, [5761] = true,
                },
                activeQuests = {},
            },
        },
    }
    CLIAltsDB = testDngDB

    -- 22a. Dungeon static data structure
    Assert(self.DUNGEON_DATA ~= nil, "Dungeons: DUNGEON_DATA table defined")
    Assert(self.DUNGEON_DATA.RFC ~= nil and self.DUNGEON_DATA.RFC.minLevel == 13, "Dungeons: RFC defined with minLevel 13")
    Assert(self.DUNGEON_DATA.WC ~= nil and self.DUNGEON_DATA.WC.minLevel == 17, "Dungeons: WC defined with minLevel 17")
    Assert(self.DUNGEON_DATA.DM ~= nil and self.DUNGEON_DATA.DM.faction == "Alliance", "Dungeons: DM defined for Alliance")

    -- 22b. RFC level gating
    local rfcLow = self:GetDungeonReadiness(testDngDB.characters["Grom-Forever"], "RFC")
    Assert(rfcLow ~= nil and rfcLow.isLevelMet == false, "Dungeons: Level 10 Grom is not level-eligible for RFC")
    Assert(rfcLow.isReady == false, "Dungeons: Level 10 Grom is not ready for RFC")

    -- 22c. RFC pre-chain requirement (Hidden Enemies)
    local rfcMid = self:GetDungeonReadiness(testDngDB.characters["Thrall-Forever"], "RFC")
    Assert(rfcMid ~= nil and rfcMid.isLevelMet == true, "Dungeons: Level 15 Thrall meets level requirement for RFC")
    Assert(rfcMid.allPreChainsDone == false, "Dungeons: Thrall has not completed Hidden Enemies pre-chain")
    Assert(rfcMid.isReady == false, "Dungeons: Thrall is not ready without pre-chain")
    Assert(rfcMid.preChains[1].nextStepName == "Hidden Enemies (Part 1)", "Dungeons: Thrall next pre-chain step is Part 1")

    -- 22d. WC pre-chain progression (Forgotten Pools -> Stagnant Oasis)
    local wcBaine = self:GetDungeonReadiness(testDngDB.characters["Baine-Forever"], "WC")
    Assert(wcBaine ~= nil and wcBaine.isLevelMet == true, "Dungeons: Level 20 Baine meets level requirement for WC")
    Assert(wcBaine.allPreChainsDone == false, "Dungeons: Baine has not completed Leaders of the Fang pre-chain")
    Assert(wcBaine.preChains[1].currentStep == 1, "Dungeons: Baine completed step 1 (Forgotten Pools)")
    Assert(wcBaine.preChains[1].nextStepName == "The Stagnant Oasis", "Dungeons: Baine next step is The Stagnant Oasis")

    -- 22e. Faction exclusion & Deadmines chain
    local rfcAnduin = self:GetDungeonReadiness(testDngDB.characters["Anduin-Forever"], "RFC")
    Assert(rfcAnduin ~= nil and rfcAnduin.factionMatch == false, "Dungeons: Alliance Priest does not match RFC Horde faction")

    local dmAnduin = self:GetDungeonReadiness(testDngDB.characters["Anduin-Forever"], "DM")
    Assert(dmAnduin ~= nil and dmAnduin.factionMatch == true, "Dungeons: Alliance Priest matches DM faction")
    Assert(dmAnduin.preChains[1].currentStep == 3, "Dungeons: Anduin completed 3 steps of Defias chain")
    Assert(dmAnduin.allPreChainsDone == false, "Dungeons: Anduin not ready until full Defias chain complete")

    -- 22f. Fully ready & fully cleared states
    local rfcRexxar = self:GetDungeonReadiness(testDngDB.characters["Rexxar-Forever"], "RFC")
    Assert(rfcRexxar ~= nil and rfcRexxar.allPreChainsDone == true, "Dungeons: Rexxar completed all pre-chains for RFC")
    Assert(rfcRexxar.completedQuests == 5, "Dungeons: Rexxar completed all 5 RFC quests")
    Assert(rfcRexxar.isDone == true, "Dungeons: Rexxar isDone is true for RFC")
    Assert(rfcRexxar.isReady == false, "Dungeons: Rexxar isReady is false because already completed all quests")

    -- 22g. FormatDungeonStatusShort output
    local stLow = self:FormatDungeonStatusShort(testDngDB.characters["Grom-Forever"], "RFC")
    Assert(stLow:find("Req Lvl 13") ~= nil, "Dungeons: FormatDungeonStatusShort mentions Req Lvl 13 for Grom")

    local stPre = self:FormatDungeonStatusShort(testDngDB.characters["Baine-Forever"], "WC")
    Assert(stPre:find("The Stagnant Oasis") ~= nil, "Dungeons: FormatDungeonStatusShort mentions next pre-req step for Baine")

    local stDone = self:FormatDungeonStatusShort(testDngDB.characters["Rexxar-Forever"], "RFC")
    Assert(stDone:find("ALL DONE") ~= nil, "Dungeons: FormatDungeonStatusShort displays ALL DONE for Rexxar")

    -- 22h. PrintDungeonReadiness execution
    local fbSpec, okSpec = self:PrintDungeonReadiness("RFC")
    Assert(okSpec == true and fbSpec:find("RFC:") ~= nil, "Dungeons: PrintDungeonReadiness('RFC') returns success and summary")

    local fbAll, okAll = self:PrintDungeonReadiness("")
    Assert(okAll == true and fbAll == "Dungeon overview printed.", "Dungeons: PrintDungeonReadiness('') prints general overview")

    CLIAltsDB = oldDngDB
    end

    do -- 23. WoW Forever Inter-Alt Mail & Supply Chain Router Tests (Component 5)
    local oldMailDB = CLIAltsDB
    local testMailDB = {
        settings = {
            foreverMode = true,
            activeTab = 1,
        },
        characters = {
            ["Morvath-Forever"] = {
                name = "Morvath-Forever",
                faction = "Horde",
                class = "Warlock",
                classFile = "WARLOCK",
                level = 35,
                tier = "CORE",
                professions = {
                    primary = {
                        { name = "Tailoring", rank = 150, maxRank = 150 },
                    },
                },
            },
            ["Thorne-Forever"] = {
                name = "Thorne-Forever",
                faction = "Horde",
                class = "Druid",
                classFile = "DRUID",
                level = 25,
                tier = "RESERVE",
                professions = {
                    primary = {
                        { name = "Alchemy", rank = 125, maxRank = 150 },
                    },
                },
            },
            ["Maxcraft-Forever"] = {
                name = "Maxcraft-Forever",
                faction = "Horde",
                class = "Warrior",
                classFile = "WARRIOR",
                level = 35,
                tier = "CORE",
                professions = {
                    primary = {
                        { name = "Blacksmithing", rank = 150, maxRank = 150 },
                    },
                },
            },
            ["Vane-Forever"] = {
                name = "Vane-Forever",
                faction = "Horde",
                class = "Rogue",
                classFile = "ROGUE",
                level = 24,
                tier = "CORE",
                professions = {
                    primary = {
                        { name = "Leatherworking", rank = 140, maxRank = 150 },
                    },
                },
            },
            ["Mule-Forever"] = {
                name = "Mule-Forever",
                faction = "Horde",
                class = "Hunter",
                classFile = "HUNTER",
                level = 1,
                tier = "BANK",
            },
        },
    }
    CLIAltsDB = testMailDB

    -- 23a. Crafter lookup
    local tailor = self:FindBestCrafterForTrade("Tailoring")
    Assert(tailor ~= nil and tailor.name == "Morvath-Forever", "Mail: FindBestCrafterForTrade finds Morvath for Tailoring")

    local alch = self:FindBestCrafterForTrade("Alchemy")
    Assert(alch ~= nil and alch.name == "Thorne-Forever", "Mail: FindBestCrafterForTrade finds Thorne for Alchemy")

    local mule = self:FindBankMule()
    Assert(mule ~= nil and mule.name == "Mule-Forever", "Mail: FindBankMule finds Mule-Forever")

    -- 23b. Material destination resolution: Cloth -> Tailoring
    local destCloth = self:GetMaterialDestination(nil, nil, 7, 5)
    Assert(destCloth ~= nil, "Mail: GetMaterialDestination resolves cloth")
    Assert(destCloth.destName == "Morvath-Forever", "Mail: Cloth routes to Morvath")
    Assert(destCloth.reason == "Tailoring", "Mail: Cloth routing reason is Tailoring")

    -- 23c. Material destination resolution: Herb -> Alchemy
    local destHerb = self:GetMaterialDestination(nil, nil, 7, 9)
    Assert(destHerb ~= nil and destHerb.destName == "Thorne-Forever", "Mail: Herb routes to Thorne")
    Assert(destHerb.reason == "Alchemy", "Mail: Herb routing reason is Alchemy")

    -- 23d. Material destination resolution: Metal & Stone -> Blacksmithing
    local destOre = self:GetMaterialDestination(nil, nil, 7, 7)
    Assert(destOre ~= nil and destOre.destName == "Maxcraft-Forever", "Mail: Ore/Stone routes to Maxcraft")

    -- 23e. Material destination resolution: Leather -> Leatherworking
    local destLeather = self:GetMaterialDestination(nil, nil, 7, 6)
    Assert(destLeather ~= nil and destLeather.destName == "Vane-Forever", "Mail: Leather routes to Vane")

    -- 23f. BoE green gear -> Disenchanting fallback or Bank
    local destGear = self:GetMaterialDestination(nil, "INVTYPE_CHEST", 4, 1, 2)
    Assert(destGear ~= nil, "Mail: BoE green gear finds destination")

    -- 23g. Unmatched item routes to Bank Mule
    local destMisc = self:GetMaterialDestination(nil, nil, 7, 10)
    Assert(destMisc ~= nil and destMisc.destName == "Mule-Forever", "Mail: Unmatched trade goods route to Bank Mule")

    -- 23h. PrintMailRouting execution
    local fbMail, okMail = self:PrintMailRouting()
    Assert(okMail == true and fbMail ~= nil, "Mail: PrintMailRouting executes cleanly")

    -- 23i. Auto supply role deduction
    local autoTailor = self:GetCharacterAutoSupplyRole(testMailDB.characters["Morvath-Forever"])
    Assert(autoTailor:find("Cloth", 1, true) ~= nil, "Mail: Morvath auto suggests Cloth stream")
    local autoAlch = self:GetCharacterAutoSupplyRole(testMailDB.characters["Thorne-Forever"])
    Assert(autoAlch:find("Herb", 1, true) ~= nil, "Mail: Thorne auto suggests Herbs stream")
    local autoMule = self:GetCharacterAutoSupplyRole(testMailDB.characters["Mule-Forever"])
    Assert(autoMule:find("Bank", 1, true) ~= nil, "Mail: Mule auto suggests Bank Mule stream")

    -- 23j. Effective supply role (Auto vs Manual Override)
    local effRole, isOverride, autoSuggested = self:GetCharacterEffectiveSupplyRole(testMailDB.characters["Morvath-Forever"])
    Assert(isOverride == false, "Mail: Morvath has no override initially")
    Assert(effRole == autoSuggested, "Mail: Effective role matches auto-suggested role")

    -- Set manual override
    local setOk, setMsg = self:SetCharacterSupplyRole("Morvath-Forever", "Herbs (Alch)")
    Assert(setOk == true and setMsg:find("Herbs") ~= nil, "Mail: SetCharacterSupplyRole overrides Morvath to Herbs")
    local effRole2, isOverride2, _ = self:GetCharacterEffectiveSupplyRole(testMailDB.characters["Morvath-Forever"])
    Assert(isOverride2 == true and effRole2 == "Herbs (Alch)", "Mail: Morvath now has manual override active")

    -- Revert back to auto
    local revOk, _ = self:SetCharacterSupplyRole("Morvath-Forever", "auto")
    Assert(revOk == true, "Mail: SetCharacterSupplyRole with 'auto' clears override")
    local effRole3, isOverride3, _ = self:GetCharacterEffectiveSupplyRole(testMailDB.characters["Morvath-Forever"])
    Assert(isOverride3 == false and effRole3:find("Cloth", 1, true) ~= nil, "Mail: Morvath reverted back to auto Cloth")

    -- 23k. CycleCharacterSupplyRole
    local nextRole1 = self:CycleCharacterSupplyRole(testMailDB.characters["Mule-Forever"])
    Assert(nextRole1 == "Cloth (Tailor)", "Mail: First cycle from auto is Cloth (Tailor)")
    local nextRole2 = self:CycleCharacterSupplyRole(testMailDB.characters["Mule-Forever"])
    Assert(nextRole2 == "Herbs (Alch)", "Mail: Second cycle is Herbs (Alch)")

    -- 23l. Mail Route Configuration Dialog
    if self.ShowMailRouteDialog then
        self:ShowMailRouteDialog(testMailDB.characters["Morvath-Forever"])
        local dlg = self.GetMailRouteDialog and self:GetMailRouteDialog()
        Assert(dlg ~= nil, "MailUI: MailRouteDialog created successfully")
        if dlg then
            Assert(dlg:IsShown() == true, "MailUI: MailRouteDialog is visible on invocation")
            Assert(dlg.statusBox ~= nil, "MailUI: MailRouteDialog has status panel")
            Assert(dlg.presetButtons ~= nil and #dlg.presetButtons >= 9, "MailUI: MailRouteDialog has 9 preset stream buttons")
            dlg:Hide()
            Assert(dlg:IsShown() == false, "MailUI: MailRouteDialog dismissed cleanly")
        end
    end

    -- 23m. In-bag items scanning with multi-value return & Tab 7 rendering
    testMailDB.characters["Mule-Forever"].supply_role = nil
    testMailDB.characters["Morvath-Forever"].supply_role = nil

    local oldGetItemInfo = GetItemInfo
    local oldNumSlots = C_Container and C_Container.GetContainerNumSlots
    local oldItemInfo = C_Container and C_Container.GetContainerItemInfo

    GetItemInfo = function(id)
        if id == 2589 then
            return "Linen Cloth", "item:2589", 1, 0, 0, "Trade Goods", "Cloth", 20, "", "", 10, 7, 5, 0
        elseif id == 2447 then
            return "Peacebloom", "item:2447", 1, 0, 0, "Trade Goods", "Herb", 20, "", "", 10, 7, 9, 0
        end
        return nil
    end

    if C_Container then
        C_Container.GetContainerNumSlots = function(bagID)
            return bagID == 0 and 2 or 0
        end

        C_Container.GetContainerItemInfo = function(bagID, slot)
            if bagID == 0 then
                if slot == 1 then
                    return { itemID = 2589, stackCount = 20, hyperlink = "|cffffffff|Hitem:2589:0:0:0:0:0:0:0:80:0:0:0:0|h[Linen Cloth]|h|r" }
                elseif slot == 2 then
                    return { itemID = 2447, stackCount = 15, hyperlink = "|cffffffff|Hitem:2447:0:0:0:0:0:0:0:80:0:0:0:0|h[Peacebloom]|h|r" }
                end
            end
            return nil
        end
    end

    local bagSummary = self:GetMailReadySummary()
    Assert(bagSummary.totalPackages == 2, "Mail: In-bag item scanner finds 2 destination packages")
    Assert(bagSummary.totalItems == 35, "Mail: In-bag item scanner sums 35 total items")
    Assert(bagSummary.byRecipient["Morvath-Forever"] ~= nil, "Mail: Morvath receives Linen Cloth")
    Assert(bagSummary.byRecipient["Thorne-Forever"] ~= nil, "Mail: Thorne receives Peacebloom")

    local pCount, pDetail = self:GetCharacterPendingMail(testMailDB.characters["Morvath-Forever"])
    Assert(pCount == 20, "Mail: Morvath has 20 pending items")
    Assert(pDetail:find("Linen Cloth") ~= nil, "Mail: Morvath pending detail mentions Linen Cloth")

    if self.SwitchTab and self.Render then
        self:SwitchTab(7)
        local renderOk, renderErr = pcall(function() self:Render() end)
        Assert(renderOk == true, "MailUI: Tab 7 Render completes without error when bags have items: " .. tostring(renderErr))
    end

    GetItemInfo = oldGetItemInfo
    if C_Container then
        C_Container.GetContainerNumSlots = oldNumSlots
        C_Container.GetContainerItemInfo = oldItemInfo
    end

    CLIAltsDB = oldMailDB
    end

    do -- 24. WoW Forever Legacy Point (LP) Progress Tracker Tests (Component 6)
    local oldLpDB = CLIAltsDB
    local testLpDB = {
        settings = {
            foreverMode = true,
            activeTab = 1,
            legacyPoints = nil,
        },
        characters = {
            ["Novice-Forever"] = {
                name = "Novice-Forever",
                faction = "Horde",
                class = "Warrior",
                classFile = "WARRIOR",
                level = 15,
                tier = "UNASSIGNED",
                professions = {
                    primary = {
                        { name = "Mining", rank = 50, maxRank = 75 },
                    },
                },
            },
            ["Journeyman-Forever"] = {
                name = "Journeyman-Forever",
                faction = "Horde",
                class = "Shaman",
                classFile = "SHAMAN",
                level = 20,
                tier = "RESERVE",
                professions = {
                    primary = {
                        { name = "Leatherworking", rank = 75, maxRank = 75 },
                    },
                },
            },
            ["Expert-Forever"] = {
                name = "Expert-Forever",
                faction = "Horde",
                class = "Mage",
                classFile = "MAGE",
                level = 35,
                tier = "CORE",
                professions = {
                    primary = {
                        { name = "Tailoring", rank = 150, maxRank = 150 },
                        { name = "Enchanting", rank = 150, maxRank = 150 },
                    },
                },
            },
            ["Champion-Forever"] = {
                name = "Champion-Forever",
                faction = "Horde",
                class = "Hunter",
                classFile = "HUNTER",
                level = 60,
                tier = "CORE",
                professions = {
                    primary = {
                        { name = "Skinning", rank = 300, maxRank = 300 },
                        { name = "Leatherworking", rank = 300, maxRank = 300 },
                    },
                },
            },
        },
    }
    CLIAltsDB = testLpDB

    -- 24a. Character LP calculations
    local novPts, _ = self:CalculateCharacterLP(testLpDB.characters["Novice-Forever"])
    Assert(novPts == 0.0, "LP: Level 15 character with <75 profs earns 0.0 LP")

    local jrnPts, jrnReasons = self:CalculateCharacterLP(testLpDB.characters["Journeyman-Forever"])
    Assert(jrnPts == 1.5, "LP: Level 20 character with P1 prof cap earns 1.5 LP (1.0 + 0.5)")
    Assert(#jrnReasons == 2, "LP: Journeyman has 2 LP award reasons")

    local expPts, _ = self:CalculateCharacterLP(testLpDB.characters["Expert-Forever"])
    Assert(expPts == 5.0, "LP: Level 35 character with 2x P2 prof caps earns 5.0 LP (3.0 + 1.0 + 1.0)")

    local chmPts, _ = self:CalculateCharacterLP(testLpDB.characters["Champion-Forever"])
    Assert(chmPts == 9.0, "LP: Level 60 character with 2x 300 caps earns 9.0 LP (5.0 + 2.0 + 2.0)")

    -- 24b. Account LP calculations
    local lpData = self:CalculateAccountLP()
    Assert(lpData ~= nil, "LP: CalculateAccountLP returns data table")
    local expectedTotal = 1.5 + 5.0 + 9.0
    Assert(math.abs(lpData.calculatedLP - expectedTotal) < 0.001, "LP: Account calculated LP sum is 15.5 LP")
    Assert(lpData.effectiveLP == expectedTotal, "LP: Effective LP matches calculated when no manual override")
    Assert(lpData.nextTier == 16, "LP: Next tier target for 15.5 LP is Tier 2 (16 LP)")
    Assert(math.abs(lpData.neededLP - 0.5) < 0.001, "LP: Needed points to Tier 2 is 0.5 LP")

    -- 24c. Manual LP overrides & Reset
    local setMsg, setOk = self:SetAccountLP(14)
    Assert(setOk == true and setMsg:find("14.0 LP") ~= nil, "LP: SetAccountLP(14) succeeds")
    local lpManual = self:CalculateAccountLP()
    Assert(lpManual.isManual == true and lpManual.effectiveLP == 14, "LP: Effective LP is now 14 (manual override)")
    Assert(lpManual.neededLP == 2, "LP: Needed points to 16 LP tier is now 2.0 LP")

    local resetMsg, resetOk = self:SetAccountLP("auto")
    Assert(resetOk == true and resetMsg:find("reset") ~= nil, "LP: SetAccountLP('auto') resets override")
    local lpReset = self:CalculateAccountLP()
    Assert(lpReset.isManual == false and lpReset.effectiveLP == expectedTotal, "LP: Reset restores calculated total (15.5 LP)")

    -- 24d. PrintLegacyPointStatus execution
    local fbLp, okLp = self:PrintLegacyPointStatus()
    Assert(okLp == true and fbLp:find("Account LP:") ~= nil, "LP: PrintLegacyPointStatus executes and returns summary")

    CLIAltsDB = oldLpDB
    end

    do -- 25. Bag Auto-Sort & Consolidation Engine Tests
    local oldSortDB = CLIAltsDB
    local testSortDB = {
        settings = {
            showBagSortButton = true,
        },
        characters = {},
    }
    CLIAltsDB = testSortDB

    -- 25a. Item sorting scores and categories
    local _, _, emptyScore = self:GetItemSortScore(nil, 0)
    Assert(emptyScore == 99, "SortBags: Empty/nil item receives score 99")

    -- Test item scores: Quest (10), Consumable (20), Trade Goods (30), Bags (40), Recipes (50), Weapons (60), Armor (70), Junk (90)
    local mockItemData = {
        [1001] = { name = "Quest Note", itemClass = 12, itemSubClass = 0, quality = 1 }, -- Quest
        [1002] = { name = "Healing Potion", itemClass = 0, itemSubClass = 1, quality = 1 }, -- Consumable
        [1003] = { name = "Copper Ore", itemClass = 7, itemSubClass = 0, quality = 1 }, -- Trade Goods
        [1004] = { name = "Silk Bag", itemClass = 1, itemSubClass = 0, quality = 1 }, -- Container
        [1005] = { name = "Recipe: Elixir", itemClass = 9, itemSubClass = 0, quality = 1 }, -- Recipe
        [1006] = { name = "Iron Sword", itemClass = 2, itemSubClass = 7, quality = 2 }, -- Weapon
        [1007] = { name = "Leather Belt", itemClass = 4, itemSubClass = 1, quality = 2 }, -- Armor
        [1008] = { name = "Ruined Pelt", itemClass = 15, itemSubClass = 0, quality = 0 }, -- Poor (Junk)
    }

    local oldGetItemInfoInstant = GetItemInfoInstant
    local oldGetItemInfo = GetItemInfo
    GetItemInfoInstant = function(id)
        local d = mockItemData[id]
        if d then
            return id, d.name, nil, nil, d.quality, d.itemClass, d.itemSubClass
        end
        return nil
    end
    GetItemInfo = function(id)
        local d = mockItemData[id]
        if d then
            return d.name, nil, d.quality, nil, nil, nil, nil, nil, nil, nil, nil, d.itemClass, d.itemSubClass
        end
        return nil
    end

    local _, _, qScore = self:GetItemSortScore(1001, 1)
    Assert(qScore == 10, "SortBags: Quest item receives score 10")
    local _, _, cScore = self:GetItemSortScore(1002, 5)
    Assert(cScore == 20, "SortBags: Consumable receives score 20")
    local _, _, tgScore = self:GetItemSortScore(1003, 20)
    Assert(tgScore == 30, "SortBags: Trade Goods receive score 30")
    local _, _, bagScore = self:GetItemSortScore(1004, 1)
    Assert(bagScore == 40, "SortBags: Bag receives score 40")
    local _, _, rcpScore = self:GetItemSortScore(1005, 1)
    Assert(rcpScore == 50, "SortBags: Recipe receives score 50")
    local _, _, wpnScore = self:GetItemSortScore(1006, 1)
    Assert(wpnScore >= 55 and wpnScore <= 60, "SortBags: Weapon receives weapon tier score")
    local _, _, armScore = self:GetItemSortScore(1007, 1)
    Assert(armScore >= 65 and armScore <= 70, "SortBags: Armor receives armor tier score")
    local _, _, jnkScore = self:GetItemSortScore(1008, 1)
    Assert(jnkScore == 90, "SortBags: Junk item receives score 90")

    -- 25b. Stack consolidation execution
    local stackCalled = false
    local oldConsolidate = self.ConsolidateBagStacks
    self.ConsolidateBagStacks = function(s)
        stackCalled = true
        return oldConsolidate(s)
    end
    self:ConsolidateBagStacks()
    Assert(stackCalled == true, "SortBags: ConsolidateBagStacks executes without errors")
    self.ConsolidateBagStacks = oldConsolidate

    -- 25c. SortBags execution and combat guard
    local oldCombat = InCombatLockdown
    InCombatLockdown = function() return true end
    local combatSort = self:SortBags()
    Assert(combatSort == false, "SortBags: Refuses to sort in combat")
    InCombatLockdown = function() return false end

    local normalSort = self:SortBags()
    Assert(normalSort == true, "SortBags: Executes bag sort outside of combat")

    -- 25d. Bag Sort Button UI initialization and toggle
    local sortBtn = self:InitBagSortButton()
    Assert(sortBtn ~= nil, "InitBagSortButton: Creates bag sort button")
    Assert(sortBtn.label ~= nil, "InitBagSortButton: Button contains label fontstring")

    local toggleOff = self:ToggleBagSortButton(false)
    Assert(toggleOff == false and CLIAltsDB.settings.showBagSortButton == false, "ToggleBagSortButton(false) disables setting")
    Assert(sortBtn:IsShown() == false, "ToggleBagSortButton(false) hides button")

    local toggleOn = self:ToggleBagSortButton(true)
    Assert(toggleOn == true and CLIAltsDB.settings.showBagSortButton == true, "ToggleBagSortButton(true) enables setting")
    Assert(sortBtn:IsShown() == true, "ToggleBagSortButton(true) shows button")

    -- 25e. Bag Sort Button anchor switching between Combined Bags and Separate Bags
    ContainerFrameCombinedBags:Show()
    ContainerFrame1:Hide()
    self:UpdateBagSortButtonAnchor()
    Assert(sortBtn.parent == ContainerFrameCombinedBags, "UpdateBagSortButtonAnchor: Anchors to ContainerFrameCombinedBags when combined bags shown")
    Assert(sortBtn:IsShown() == true, "UpdateBagSortButtonAnchor: Button visible on ContainerFrameCombinedBags")

    ContainerFrameCombinedBags:Hide()
    ContainerFrame1:Show()
    self:UpdateBagSortButtonAnchor()
    Assert(sortBtn.parent == ContainerFrame1, "UpdateBagSortButtonAnchor: Anchors to ContainerFrame1 when separate bags shown")
    Assert(sortBtn:IsShown() == true, "UpdateBagSortButtonAnchor: Button visible on ContainerFrame1")

    ContainerFrameCombinedBags:Hide()
    ContainerFrame1:Hide()
    self:UpdateBagSortButtonAnchor()
    Assert(sortBtn:IsShown() == false, "UpdateBagSortButtonAnchor: Hides when all bag frames hidden")

    -- Restore frames
    ContainerFrameCombinedBags:Show()
    ContainerFrame1:Show()
    self:UpdateBagSortButtonAnchor()

    -- Clean up mocks
    GetItemInfoInstant = oldGetItemInfoInstant
    GetItemInfo = oldGetItemInfo
    InCombatLockdown = oldCombat
    CLIAltsDB = oldSortDB
    end

    do -- 26. Mail Supply Chain Auto-Fill Engine Tests
    local oldMailDB = CLIAltsDB
    local testMailDB = {
        settings = {
            showMailAutoFillButton = true,
            autoFillMailOnSend = true,
        },
        characters = {
            ["Sender-Forever"] = {
                name = "Sender-Forever",
                class = "Warrior",
                classFile = "WARRIOR",
                level = 30,
            },
            ["TailorAlt-Forever"] = {
                name = "TailorAlt-Forever",
                class = "Mage",
                classFile = "MAGE",
                level = 35,
                tier = "CORE",
                professions = {
                    primary = {
                        { name = "Tailoring", rank = 150, maxRank = 150 },
                    },
                },
            },
        },
    }
    CLIAltsDB = testMailDB
    self.curPlayerFullName = "Sender-Forever"

    -- Mock items in bags: Wool Cloth (itemID 2592) in bag 0 slot 1
    local mockBagItems = {
        [0] = {
            [1] = { itemID = 2592, count = 20, link = "|cffffffff[Wool Cloth]|r" },
        },
    }
    local oldGetItemData = self.GetContainerItemData
    local oldGetNumSlots = self.GetNumContainerSlots
    local oldGetItemInfo = GetItemInfo
    GetItemInfo = function(id)
        if id == 2592 then
            return "Wool Cloth", "item:2592", 1, 0, 0, "Trade Goods", "Cloth", 20, "", "", 10, 7, 5, 0
        end
        return nil
    end
    self.GetContainerItemData = function(_, bag, slot)
        if mockBagItems[bag] and mockBagItems[bag][slot] then
            local itm = mockBagItems[bag][slot]
            return itm.itemID, itm.count, itm.link
        end
        return nil
    end
    self.GetNumContainerSlots = function(_, bag)
        if bag == 0 then return 1 end
        return 0
    end

    -- 26a. GetMailReadySummary includes bag and slot information
    local summary = self:GetMailReadySummary()
    Assert(summary.totalPackages > 0, "MailAutoFill: Detected packages ready for alts")
    local tailorPkg = summary.byRecipient["TailorAlt-Forever"]
    Assert(tailorPkg ~= nil, "MailAutoFill: Wool Cloth routed to TailorAlt-Forever")
    Assert(tailorPkg.items[1].bag == 0 and tailorPkg.items[1].slot == 1, "MailAutoFill: Item entry contains bag 0 slot 1")

    -- 26b. FillSendMailNextBatch execution and UI setup
    local mailItemsAttached = 0
    local oldClickSendMail = ClickSendMailItemButton
    local oldGetSendMailItem = GetSendMailItem
    ClickSendMailItemButton = function(slot, clear)
        mailItemsAttached = mailItemsAttached + 1
    end
    GetSendMailItem = function(slot)
        if slot <= mailItemsAttached then return "Item" end
        return nil
    end

    SendMailFrame:Show()
    local fillOk, fillWho, fillCount = self:FillSendMailNextBatch()
    Assert(fillOk == true, "MailAutoFill: FillSendMailNextBatch succeeds")
    Assert(fillWho == "TailorAlt-Forever", "MailAutoFill: Filled recipient TailorAlt-Forever")
    Assert(fillCount == 1, "MailAutoFill: Attached 1 item")
    Assert(SendMailNameEditBox:GetText() == "TailorAlt-Forever", "MailAutoFill: SendMailNameEditBox contains TailorAlt-Forever")
    Assert(SendMailSubjectEditBox:GetText():find("CLIAlts:") ~= nil, "MailAutoFill: SendMailSubjectEditBox set with CLIAlts prefix")

    -- 26c. AutoFill Mail Button creation and toggle
    local mailBtn = self:InitMailAutoFillButton()
    Assert(mailBtn ~= nil, "InitMailAutoFillButton: Button created on SendMailFrame")
    Assert(mailBtn.label ~= nil, "InitMailAutoFillButton: Button has label fontstring")

    local toggleOff = self:ToggleMailAutoFillButton(false)
    Assert(toggleOff == false and CLIAltsDB.settings.showMailAutoFillButton == false, "ToggleMailAutoFillButton(false) disables setting")
    Assert(mailBtn:IsShown() == false, "ToggleMailAutoFillButton(false) hides button")

    local toggleOn = self:ToggleMailAutoFillButton(true)
    Assert(toggleOn == true and CLIAltsDB.settings.showMailAutoFillButton == true, "ToggleMailAutoFillButton(true) enables setting")
    Assert(mailBtn:IsShown() == true, "ToggleMailAutoFillButton(true) shows button")

    -- Clean up mocks
    self.GetContainerItemData = oldGetItemData
    self.GetNumContainerSlots = oldGetNumSlots
    ClickSendMailItemButton = oldClickSendMail
    GetSendMailItem = oldGetSendMailItem
    GetItemInfo = oldGetItemInfo
    SendMailFrame:Hide()
    CLIAltsDB = oldMailDB
    end

    do -- 27. Consumable Filtering & Mail Ignore List Engine Tests
    local oldIgnoreDB = CLIAltsDB
    local testIgnoreDB = {
        settings = {
            ignoredMailItems = {},
            autoMailConsumables = false,
        },
        characters = {
            ["SenderMain"] = {
                name = "SenderMain",
                class = "Warrior",
                classFile = "WARRIOR",
                level = 30,
            },
            ["RogueAlt"] = {
                name = "RogueAlt",
                class = "Rogue",
                classFile = "ROGUE",
                level = 30,
                tier = "CORE",
            },
            ["TailorAlt"] = {
                name = "TailorAlt",
                class = "Mage",
                classFile = "MAGE",
                level = 35,
                tier = "CORE",
                professions = {
                    primary = {
                        { name = "Tailoring", rank = 150, maxRank = 150 },
                    },
                },
            },
        },
    }
    CLIAltsDB = testIgnoreDB
    self.curPlayerFullName = "SenderMain"

    local oldGetItemInfo = GetItemInfo
    GetItemInfo = function(id)
        if id == 4540 or id == "Tough Hunk of Bread" then
            -- Tough Hunk of Bread (Consumable: classID 0, subclassID 5)
            return "Tough Hunk of Bread", "item:4540", 1, 1, 1, "Consumable", "Food & Drink", 20, "", "", 10, 0, 5, 0
        elseif id == 4636 or id == "Heavy Lockbox" then
            -- Heavy Lockbox (Junk/Misc: classID 15, subclassID 0)
            return "Heavy Lockbox", "item:4636", 1, 1, 1, "Miscellaneous", "Junk", 1, "", "", 0, 15, 0, 0
        elseif id == 2592 or id == "Wool Cloth" then
            -- Wool Cloth (Trade Goods: classID 7, subclassID 5)
            return "Wool Cloth", "item:2592", 1, 1, 1, "Trade Goods", "Cloth", 20, "", "", 10, 7, 5, 0
        end
        return nil
    end

    -- 27a. Consumables (Food/Drink classID 0) are NOT routed to Rogues or any alt by default
    local breadDest = self:GetMaterialDestination(4540)
    Assert(breadDest == nil, "MailIgnore: Consumable (Tough Hunk of Bread) destination is nil, not routed to Rogue")

    -- 27b. Actual Lockboxes ARE routed to Rogues
    local boxDest = self:GetMaterialDestination(4636)
    Assert(boxDest ~= nil, "MailIgnore: Heavy Lockbox has valid destination")
    Assert(boxDest.destName == "RogueAlt", "MailIgnore: Heavy Lockbox routed to RogueAlt")
    Assert(boxDest.reason == "Lockpicking", "MailIgnore: Routing reason is Lockpicking")

    -- 27c. Trade Goods routed normally prior to ignoring
    local clothDest = self:GetMaterialDestination(2592)
    Assert(clothDest ~= nil and clothDest.destName == "TailorAlt", "MailIgnore: Wool Cloth initially routed to TailorAlt")

    -- 27d. Adding item to mail ignore list blocks routing
    local ignOk, _ = self:IgnoreMailItem("Wool Cloth")
    Assert(ignOk == true, "MailIgnore: IgnoreMailItem succeeds for Wool Cloth")
    Assert(self:IsItemMailIgnored(2592) == true, "MailIgnore: IsItemMailIgnored returns true by itemID")
    Assert(self:IsItemMailIgnored(nil, "Wool Cloth") == true, "MailIgnore: IsItemMailIgnored returns true by itemName")
    local clothDestAfter = self:GetMaterialDestination(2592)
    Assert(clothDestAfter == nil, "MailIgnore: Wool Cloth routing returns nil when ignored")

    -- 27e. List ignored mail items
    local count = self:ListIgnoredMailItems()
    Assert(count >= 1, "MailIgnore: ListIgnoredMailItems lists at least 1 item")

    -- 27f. Unignoring item restores routing
    local unignOk = self:UnignoreMailItem("Wool Cloth")
    Assert(unignOk == true, "MailIgnore: UnignoreMailItem succeeds")
    Assert(self:IsItemMailIgnored(2592) == false, "MailIgnore: IsItemMailIgnored returns false after unignoring")
    local clothDestRestored = self:GetMaterialDestination(2592)
    Assert(clothDestRestored ~= nil and clothDestRestored.destName == "TailorAlt", "MailIgnore: Routing restored to TailorAlt")

    -- 27g. Cursor pickup support in IgnoreMailItem
    local oldGetCursorInfo = GetCursorInfo
    GetCursorInfo = function()
        return "item", 2592, "|cffffffff[Wool Cloth]|r"
    end
    local cursorOk, _ = self:IgnoreMailItem()
    Assert(cursorOk == true, "MailIgnore: IgnoreMailItem without arguments grabs item from cursor")
    Assert(self:IsItemMailIgnored(2592) == true, "MailIgnore: Cursor-picked item is marked as ignored")
    self:UnignoreMailItem(2592)
    GetCursorInfo = oldGetCursorInfo

    -- 27h. ToggleAutoMailConsumables
    local enabled = self:ToggleAutoMailConsumables(true)
    Assert(enabled == true and CLIAltsDB.settings.autoMailConsumables == true, "ToggleAutoMailConsumables(true) enables setting")
    local disabled = self:ToggleAutoMailConsumables(false)
    Assert(disabled == false and CLIAltsDB.settings.autoMailConsumables == false, "ToggleAutoMailConsumables(false) disables setting")

    -- Clean up mocks
    GetItemInfo = oldGetItemInfo
    CLIAltsDB = oldIgnoreDB
    end

    if failed == 0 then
        self:Print(string.format("|cff00ff66Self-test passed: all %d assertions OK.|r (ProjectRested, GetRestedWaste, Calibration, Digest & Alerts, Leveling Plan, Notes, Lockouts, Watchlist, Stale/Prune, LibDataBroker, Colorblind/Compact, LivePath, Backup/Restore, UI/Slash, Cross-Character Inventory & Tooltips, WoW Forever Cohorts & Roles, Smart Rotation, Profession Milestones, Dashboard Roster Summary, Navigation & Context Menu, Dungeon Quest Tracker & Attunements, Supply Chain & Mail Router, Legacy Point Tracker, Bag Auto-Sort & Consolidation Engine, Mail Supply Chain Auto-Fill Engine, Consumable & Mail Ignore Filter Engine)", passed))
    else
        self:Print(string.format("|cffff3333Self-test FAILED: %d passed, %d failed!|r", passed, failed))
        for _, err in ipairs(errors) do
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cffff3333* FAILED:|r %s", err))
            else
                print(string.format("  * FAILED: %s", err))
            end
        end
    end

    return failed == 0, passed, failed
end

CLIAlts.ExecuteSelfTest = CLIAlts.RunSelfTest
