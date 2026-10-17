-- ============================================================================
-- ForeverAlts: Automated Dungeon Quest Tracker & Instance Data
-- File: modules/dungeon_data.lua
-- ============================================================================

local addonName, addonTable = ...
local ForeverAlts = addonTable or _G["ForeverAlts"] or _G["CLIAlts"] or {}

-- WoW Forever: Automated Dungeon Quest Tracker (Component 4)
-- ----------------------------------------------------------------------------
ForeverAlts.DUNGEON_KEYS = { "RFC", "WC", "DM", "SFK", "BFD" }

ForeverAlts.DUNGEON_DATA = {
    RFC = {
        tag = "RFC",
        name = "Ragefire Chasm",
        zone = "Orgrimmar",
        faction = "Horde",
        minLevel = 13,
        recLevel = 15,
        maxLevel = 18,
        preChains = {
            {
                name = "Hidden Enemies",
                finalQuestId = 5728,
                giver = "Thrall (Orgrimmar)",
                steps = { 5722, 5723, 5724, 5725, 5726, 5727, 5728 },
                stepNames = {
                    "Hidden Enemies (Part 1)",
                    "Hidden Enemies (Part 2)",
                    "Hidden Enemies (Part 3)",
                    "Hidden Enemies (Part 4)",
                    "Hidden Enemies (Part 5)",
                    "Hidden Enemies (Part 6)",
                    "Hidden Enemies (Dungeon)",
                },
            },
        },
        quests = {
            { id = 5728, name = "Hidden Enemies", giver = "Thrall (Orgrimmar)", isFinalChain = true },
            { id = 5721, name = "Slaying the Beast", giver = "Neeru Fireblade (Orgrimmar)" },
            { id = 5729, name = "Searching for the Lost Sack", giver = "Rahauro (Thunder Bluff)" },
            { id = 5730, name = "Testing an Enemy's Strength", giver = "Rahauro (Thunder Bluff)" },
            { id = 5761, name = "The Power to Destroy...", giver = "Varimathras (Undercity)" },
        },
    },
    WC = {
        tag = "WC",
        name = "Wailing Caverns",
        zone = "The Barrens",
        faction = "Any",
        minLevel = 17,
        recLevel = 19,
        maxLevel = 24,
        preChains = {
            {
                name = "Leaders of the Fang",
                finalQuestId = 957,
                giver = "Crossroads -> Thunder Bluff",
                faction = "Horde",
                steps = { 870, 871, 872, 875, 876, 957 },
                stepNames = {
                    "The Forgotten Pools",
                    "The Stagnant Oasis",
                    "Altered Beings",
                    "Hamuul Runetotem",
                    "Nara Wildmane",
                    "Leaders of the Fang",
                },
            },
        },
        quests = {
            { id = 957, name = "Leaders of the Fang", giver = "Nara Wildmane (Thunder Bluff)", isFinalChain = true, faction = "Horde" },
            { id = 881, name = "Cleansing the Water", giver = "Tonga Runetotem (Crossroads)", preReq = 871, faction = "Horde" },
            { id = 848, name = "Deviate Eradication", giver = "Ebru (WC Eye Cave)" },
            { id = 844, name = "Deviate Hides", giver = "Nalpak (WC Eye Cave)" },
            { id = 959, name = "Smart Drinks", giver = "Mangletooth (Ratchet)" },
            { id = 849, name = "Trouble at the Docks", giver = "Crane Operator Bigglefuzz (Ratchet)" },
        },
    },
    DM = {
        tag = "DM",
        name = "The Deadmines",
        zone = "Westfall",
        faction = "Alliance",
        minLevel = 17,
        recLevel = 19,
        maxLevel = 24,
        preChains = {
            {
                name = "The Defias Brotherhood",
                finalQuestId = 154,
                giver = "Sentinel Hill (Westfall)",
                steps = { 155, 166, 167, 168, 148, 151, 152, 153, 154 },
                stepNames = {
                    "The Defias Brotherhood (Part 1)",
                    "The Defias Brotherhood (Part 2)",
                    "The Defias Brotherhood (Part 3)",
                    "The Defias Brotherhood (Part 4)",
                    "The Defias Brotherhood (Part 5)",
                    "The Defias Brotherhood (Part 6)",
                    "The Defias Brotherhood (Escort)",
                    "The Defias Brotherhood (Tower)",
                    "The Defias Brotherhood (Dungeon)",
                },
            },
        },
        quests = {
            { id = 154, name = "The Defias Brotherhood", giver = "Gryan Stoutmantle (Westfall)", isFinalChain = true },
            { id = 169, name = "Collecting Memories", giver = "Wilder Thistlenettle (Stormwind)" },
            { id = 164, name = "Oh Brother. . .", giver = "Wilder Thistlenettle (Stormwind)" },
            { id = 165, name = "Underground Assault", giver = "Shoni the Silencer (Stormwind)" },
            { id = 214, name = "Red Silk Bandanas", giver = "Scout Riell (Westfall)" },
        },
    },
    SFK = {
        tag = "SFK",
        name = "Shadowfang Keep",
        zone = "Silverpine Forest",
        faction = "Horde",
        minLevel = 22,
        recLevel = 24,
        maxLevel = 30,
        quests = {
            { id = 1014, name = "Arugal Must Die", giver = "Dalar Dawnweaver (Sepulcher)" },
            { id = 1013, name = "Deathstalkers in Shadowfang", giver = "High Executor Hadrec (Sepulcher)" },
            { id = 1011, name = "The Book of Ur", giver = "Keeper Bel'dugur (Undercity)" },
        },
    },
    BFD = {
        tag = "BFD",
        name = "Blackfathom Deeps",
        zone = "Ashenvale",
        faction = "Any",
        minLevel = 22,
        recLevel = 24,
        maxLevel = 30,
        quests = {
            { id = 1275, name = "Blackfathom Villainy", giver = "Bashana Runetotem (TB)", faction = "Horde" },
            { id = 1274, name = "Blackfathom Villainy", giver = "Dawnstrider (Darnassus)", faction = "Alliance" },
            { id = 1270, name = "The Twilight Falls", giver = "Argent Dawn (Ashenvale)" },
            { id = 1198, name = "Allegiance to the Old Gods", giver = "Je'neu Sancrea (Zoram'gar)", faction = "Horde" },
            { id = 1276, name = "Researching the Corruption", giver = "Gershala Nightwhisper (Auberdine)", faction = "Alliance" },
        },
    },
}

function ForeverAlts:GetDungeonReadiness(char, dungeonTag)
    if not char or not dungeonTag then return nil end
    local dng = self.DUNGEON_DATA and self.DUNGEON_DATA[dungeonTag:upper()]
    if not dng then return nil end

    local charLevel = tonumber(char.level) or 1
    local charFaction = char.faction or "Neutral"
    local cDone = char.dungeonQuests or {}
    local cActive = char.activeQuests or {}

    local factionMatch = (dng.faction == "Any") or (dng.faction == charFaction)

    local relevantQuests = {}
    for _, q in ipairs(dng.quests) do
        if not q.faction or q.faction == "Any" or q.faction == charFaction then
            local isDone = cDone[q.id] == true
            local isActive = cActive[q.id] == true
            table.insert(relevantQuests, {
                id = q.id,
                name = q.name,
                giver = q.giver,
                isDone = isDone,
                isActive = isActive,
                isFinalChain = q.isFinalChain or false,
            })
        end
    end

    local preChainStatus = {}
    local allPreChainsDone = true
    if dng.preChains then
        for _, chain in ipairs(dng.preChains) do
            if not chain.faction or chain.faction == "Any" or chain.faction == charFaction then
                local totalSteps = #chain.steps
                local currentStep = 0
                for idx, qid in ipairs(chain.steps) do
                    if cDone[qid] then
                        currentStep = idx
                    end
                end
                local completedChain = (currentStep >= totalSteps)
                if not completedChain then
                    allPreChainsDone = false
                end
                local nextStepName
                if completedChain then
                    nextStepName = "Complete"
                else
                    nextStepName = (chain.stepNames and chain.stepNames[currentStep + 1])
                        or string.format("Step %d/%d", currentStep + 1, totalSteps)
                end
                table.insert(preChainStatus, {
                    name = chain.name,
                    finalQuestId = chain.finalQuestId,
                    totalSteps = totalSteps,
                    currentStep = currentStep,
                    completed = completedChain,
                    nextStepName = nextStepName,
                })
            end
        end
    end

    local completedCount = 0
    local activeCount = 0
    for _, q in ipairs(relevantQuests) do
        if q.isDone then completedCount = completedCount + 1 end
        if q.isActive then activeCount = activeCount + 1 end
    end

    local inLevelRange = (charLevel >= dng.minLevel and charLevel <= (dng.maxLevel + 4))
    local isLevelMet = (charLevel >= dng.minLevel)
    local isRecMet = (charLevel >= dng.recLevel)
    local isDone = (#relevantQuests > 0) and (completedCount == #relevantQuests)
    local isReady = factionMatch and isLevelMet and allPreChainsDone and not isDone

    return {
        tag = dng.tag,
        name = dng.name,
        zone = dng.zone,
        minLevel = dng.minLevel,
        recLevel = dng.recLevel,
        maxLevel = dng.maxLevel,
        faction = dng.faction,
        factionMatch = factionMatch,
        charLevel = charLevel,
        inLevelRange = inLevelRange,
        isLevelMet = isLevelMet,
        isRecMet = isRecMet,
        isDone = isDone,
        isReady = isReady,
        allPreChainsDone = allPreChainsDone,
        preChains = preChainStatus,
        totalQuests = #relevantQuests,
        completedQuests = completedCount,
        activeQuests = activeCount,
        quests = relevantQuests,
    }
end

function ForeverAlts:FormatDungeonStatusShort(char, dungeonTag)
    local r = self:GetDungeonReadiness(char, dungeonTag)
    if not r then return "---" end
    local t = (self.GetTheme and self:GetTheme()) or {
        mutedHex = "a9a08c",
        readyHex = "55e39a",
        accentHex = "57d6e8",
        pendingHex = "ffb547",
        blockedHex = "ff6b6b",
    }

    if not r.factionMatch then
        return string.format("|cff%sWrong Faction|r", t.mutedHex or "a9a08c")
    end
    if not r.isLevelMet then
        return string.format("|cff%sReq Lvl %d (Cur: %d)|r", t.mutedHex or "a9a08c", r.minLevel, r.charLevel)
    end
    if r.isDone then
        return string.format("|cff%s[ALL DONE %d/%d]|r", t.accentHex or "57d6e8", r.completedQuests, r.totalQuests)
    end
    if not r.allPreChainsDone and r.preChains and #r.preChains > 0 then
        local firstChain = r.preChains[1]
        return string.format("|cff%s[PRE-REQ: %s]|r", t.pendingHex or "ffb547", firstChain.nextStepName)
    end
    if r.isReady then
        local activeStr = (r.activeQuests > 0) and string.format(" (%d in log)", r.activeQuests) or ""
        return string.format("|cff%s[READY %d/%d]%s|r", t.readyHex or "55e39a", r.completedQuests, r.totalQuests, activeStr)
    end
    return string.format("[%d/%d Quests]", r.completedQuests, r.totalQuests)
end

function ForeverAlts:PrintDungeonReadiness(dungeonQuery)
    local t = (self.GetTheme and self:GetTheme()) or {
        borderHex = "f2c94c",
        primaryHex = "ffd34e",
        highlightHex = "ffd34e",
        readyHex = "55e39a",
        pendingHex = "ffb547",
        mutedHex = "a9a08c",
    }

    local query = (dungeonQuery and dungeonQuery:match("^%s*(.-)%s*$"):upper()) or ""
    local validTag = self.DUNGEON_DATA and self.DUNGEON_DATA[query] and query

    local chars = self:GetCharactersList("level", false)
    if #chars == 0 then
        self:Print("No characters tracked yet.")
        return "No characters tracked.", false
    end

    local top = string.rep("=", 72)
    local bottom = string.rep("=", 72)
    local sep = string.rep("-", 72)

    if validTag then
        local dng = self.DUNGEON_DATA[validTag]
        self:Print(string.format("|cff%s%s|r", t.borderHex or "f2c94c", top))
        self:Print(string.format("|cff%sFOREVERALTS :: %s (%s) READINESS CHECK|r", t.highlightHex or "ffd34e", dng.name:upper(), dng.tag))
        self:Print(string.format("  Zone: %s | Faction: %s | Level Range: %d-%d (Rec: %d)", dng.zone, dng.faction, dng.minLevel, dng.maxLevel, dng.recLevel))
        self:Print(string.format("|cff%s%s|r", t.borderHex or "f2c94c", sep))

        local readyCount = 0
        local eligibleCount = 0
        for _, char in ipairs(chars) do
            local r = self:GetDungeonReadiness(char, validTag)
            if r and r.factionMatch then
                eligibleCount = eligibleCount + 1
                local cName = self:ColorizePlayerName(char.name or "Unknown", char.classFile)
                local st = self:FormatDungeonStatusShort(char, validTag)
                if r.isReady then
                    readyCount = readyCount + 1
                end
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  * %-16s (Lvl %2d %-7s): %s", cName, r.charLevel, self:GetRaceCode(char), st))
            end
        end

        self:Print(string.format("|cff%s%s|r", t.borderHex or "f2c94c", bottom))
        local summary = string.format("%s: %d/%d alts ready to run.", dng.tag, readyCount, eligibleCount)
        self:Print(string.format("|cff%s%s|r", t.readyHex or "55e39a", summary))
        return summary, true
    else
        self:Print(string.format("|cff%s%s|r", t.borderHex or "f2c94c", top))
        self:Print(string.format("|cff%sFOREVERALTS :: DUNGEON QUEST READINESS OVERVIEW (WOW FOREVER)|r", t.highlightHex or "ffd34e"))
        self:Print("  Instances: RFC (13-18), WC (17-24), DM (17-24), SFK (22-30), BFD (22-30)")
        self:Print(string.format("|cff%s%s|r", t.borderHex or "f2c94c", sep))

        local printed = 0
        for _, char in ipairs(chars) do
            local parts = {}
            for _, dKey in ipairs(self.DUNGEON_KEYS) do
                local r = self:GetDungeonReadiness(char, dKey)
                if r and r.factionMatch and (char.level or 1) >= (r.minLevel - 3) then
                    local st = self:FormatDungeonStatusShort(char, dKey)
                    table.insert(parts, string.format("%s: %s", dKey, st))
                end
            end
            if #parts > 0 then
                printed = printed + 1
                local cName = self:ColorizePlayerName(char.name or "Unknown", char.classFile)
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  * %-16s (Lvl %2d): %s", cName, char.level or 1, table.concat(parts, " | ")))
            end
        end

        if printed == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("  No characters currently in low-level dungeon range (10-34).")
        end

        self:Print(string.format("|cff%s%s|r", t.borderHex or "f2c94c", bottom))
        self:Print("Tip: Type |cff00ff66/fa dungeon <rfc|wc|dm|sfk|bfd>|r for single instance details.")
        return "Dungeon overview printed.", true
    end
end
