-- ============================================================================
-- CLIAlts: Retro Alt Tracker
-- File: data.lua
-- Database management, character data collection, and rested XP calculations.
-- ============================================================================

local addonName, addonTable = ...
local CLIAlts = addonTable
_G["CLIAlts"] = CLIAlts
_G["clialts"] = CLIAlts
_G["Nasalts"] = CLIAlts

-- ----------------------------------------------------------------------------
-- Constants & Reference Tables
-- ----------------------------------------------------------------------------
CLIAlts.VERSION = "1.0.0"

-- Fallback RAID_CLASS_COLORS if not present in client
local FALLBACK_CLASS_COLORS = {
    ["WARRIOR"]     = { r = 0.78, g = 0.61, b = 0.43, hex = "c79c6e" },
    ["PALADIN"]     = { r = 0.96, g = 0.55, b = 0.73, hex = "f58cba" },
    ["HUNTER"]      = { r = 0.67, g = 0.83, b = 0.45, hex = "abd473" },
    ["ROGUE"]       = { r = 1.00, g = 0.96, b = 0.41, hex = "fff569" },
    ["PRIEST"]      = { r = 1.00, g = 1.00, b = 1.00, hex = "ffffff" },
    ["SHAMAN"]      = { r = 0.00, g = 0.44, b = 0.87, hex = "0070de" },
    ["MAGE"]        = { r = 0.41, g = 0.80, b = 0.94, hex = "69ccf0" },
    ["WARLOCK"]     = { r = 0.58, g = 0.51, b = 0.79, hex = "9482c9" },
    ["DRUID"]       = { r = 1.00, g = 0.49, b = 0.04, hex = "ff7d0a" },
    ["DEATHKNIGHT"] = { r = 0.77, g = 0.12, b = 0.23, hex = "c41f3b" },
    ["MONK"]        = { r = 0.00, g = 1.00, b = 0.59, hex = "00ff96" },
    ["DEMONHUNTER"] = { r = 0.64, g = 0.19, b = 0.79, hex = "a330c9" },
    ["EVOKER"]      = { r = 0.20, g = 0.58, b = 0.50, hex = "33937f" },
}

-- Standard Classic / Vanilla XP required per level (Levels 1 to 59)
-- Fallback in case client UnitXPMax returns 0 before server sync
CLIAlts.XP_TABLE = {
    [1] = 400,    [2] = 900,    [3] = 1400,   [4] = 2100,   [5] = 2800,
    [6] = 3600,   [7] = 4500,   [8] = 5400,   [9] = 6500,   [10] = 7600,
    [11] = 8700,  [12] = 9800,  [13] = 11000, [14] = 12300, [15] = 13600,
    [16] = 15000, [17] = 16400, [18] = 17900, [19] = 19500, [20] = 21100,
    [21] = 22800, [22] = 24600, [23] = 26500, [24] = 28500, [25] = 30500,
    [26] = 32600, [27] = 34800, [28] = 37000, [29] = 39400, [30] = 41800,
    [31] = 44300, [32] = 46900, [33] = 49600, [34] = 52400, [35] = 55300,
    [36] = 58300, [37] = 61400, [38] = 64600, [39] = 67900, [40] = 71300,
    [41] = 74800, [42] = 78400, [43] = 82100, [44] = 85900, [45] = 89800,
    [46] = 93800, [47] = 97900, [48] = 102100, [49] = 106400, [50] = 110800,
    [51] = 115300, [52] = 119900, [53] = 124600, [54] = 129400, [55] = 134300,
    [56] = 139300, [57] = 144400, [58] = 149600, [59] = 154900,
}

local KNOWN_PRIMARY_PROFS = {
    ["Alchemy"]        = true,
    ["Blacksmithing"]  = true,
    ["Enchanting"]     = true,
    ["Engineering"]    = true,
    ["Herbalism"]      = true,
    ["Leatherworking"] = true,
    ["Mining"]         = true,
    ["Skinning"]       = true,
    ["Tailoring"]      = true,
    ["Jewelcrafting"]  = true,
    ["Inscription"]    = true,
}

local KNOWN_SECONDARY_PROFS = {
    ["Cooking"]      = true,
    ["First Aid"]    = true,
    ["Fishing"]      = true,
    ["Archaeology"]  = true,
}

-- ----------------------------------------------------------------------------
-- Format Helper: Race and Class Clean Display
-- ----------------------------------------------------------------------------
function CLIAlts:FormatRaceClass(char)
    if not char then return "Unknown" end

    -- Extract clean race (prefer raceFile or simplified name over long titles)
    local race = char.raceFile or char.race or "Unknown"
    if race == "Unknown" and char.race and char.race ~= "" then
        race = char.race
    end

    -- Simplify long multi-word races cleanly
    if race:find("Skyborne") then
        race = "Skyborne"
    elseif race:find("Scourge") or race:find("Undead") then
        race = "Undead"
    end

    local class = char.class or "Unknown"
    return string.format("%s %s", race, class)
end

-- ----------------------------------------------------------------------------
-- Database Initialization & Two-Name Migration
-- ----------------------------------------------------------------------------
function CLIAlts:InitDB()
    if not CLIAltsDB and NasaltsDB then
        CLIAltsDB = NasaltsDB
    end
    if not CLIAltsDB then
        CLIAltsDB = {}
    end
    NasaltsDB = CLIAltsDB -- backward compatibility alias
    CLIAltsDB.settings = CLIAltsDB.settings or {}
    CLIAltsDB.settings.theme = CLIAltsDB.settings.theme or "AMBER"
    CLIAltsDB.settings.minimapPos = CLIAltsDB.settings.minimapPos or 45
    CLIAltsDB.settings.minimapShow = (CLIAltsDB.settings.minimapShow ~= false)
    CLIAltsDB.settings.sortBy = CLIAltsDB.settings.sortBy or "name"
    CLIAltsDB.settings.sortAsc = (CLIAltsDB.settings.sortAsc == true)
    CLIAltsDB.settings.activeTab = CLIAltsDB.settings.activeTab or 1
    CLIAltsDB.settings.wellRestedRank = tonumber(CLIAltsDB.settings.wellRestedRank) or 0
    CLIAltsDB.characters = CLIAltsDB.characters or {}

    -- Migrate old "Name - Realm" keys to clean two-name keys & repair resting flags
    local migrated = {}
    for key, char in pairs(CLIAltsDB.characters) do
        local cleanKey = char.fullName
        if not cleanKey or cleanKey == "" then
            if char.primaryName and char.secondaryName and char.secondaryName ~= "" then
                cleanKey = char.primaryName .. " " .. char.secondaryName
            elseif char.name and char.name ~= "" then
                cleanKey = char.name:match("^(.-)%s*-%s*.*$") or char.name
            else
                cleanKey = key:match("^(.-)%s*-%s*.*$") or key
            end
        end
        char.key = cleanKey
        char.fullName = cleanKey
        char.name = cleanKey

        -- Repair isResting & loggedOutInRestZone if location indicates an inn, camp, or resting zone
        if self:IsLocationResting(char.location) then
            char.isResting = true
            char.loggedOutInRestZone = true
        elseif char.isResting == true and char.loggedOutInRestZone == nil then
            char.loggedOutInRestZone = true
        end
        -- Ensure fallback maxXP is populated if 0
        if (not char.maxXP or char.maxXP <= 0) and char.level and char.level < 60 then
            char.maxXP = self.XP_TABLE[char.level] or (char.level * 1000)
        end

        migrated[cleanKey] = char
    end
    CLIAltsDB.characters = migrated
end

-- ----------------------------------------------------------------------------
-- Helper: Primary Name & Secondary Name (WoW Forever Support)
-- ----------------------------------------------------------------------------
function CLIAlts:GetPlayerNames()
    local primaryName, secondaryName = nil, nil

    -- 1. In WoW Forever, UnitName("player") returns (primaryName, secondaryName)
    if UnitName then
        local v1, v2 = UnitName("player")
        if v1 and v1 ~= "" then
            primaryName = v1
        end
        local realm = GetRealmName and GetRealmName()
        -- In WoW Forever, v2 is the Secondary Name (Surname), NOT the realm
        if v2 and v2 ~= "" and v2 ~= realm then
            secondaryName = v2
        end
    end

    -- 2. Check GetUnitName("player", false) which returns full composite name
    if GetUnitName then
        local full = GetUnitName("player", false)
        if full and full ~= "" then
            if full:find(" ") then
                local f, l = full:match("^(%S+)%s+(.+)$")
                if f and l then
                    primaryName = primaryName or f
                    secondaryName = secondaryName or l
                end
            elseif not primaryName then
                primaryName = full
            end
        end
    end

    -- 3. Dedicated API if present in WoW Forever client build
    if not secondaryName then
        if UnitSecondaryName then
            secondaryName = UnitSecondaryName("player")
        elseif GetUnitSecondaryName then
            secondaryName = GetUnitSecondaryName("player")
        elseif UnitSurname then
            secondaryName = UnitSurname("player")
        elseif GetUnitSurname then
            secondaryName = GetUnitSurname("player")
        end
    end

    primaryName = primaryName or (UnitName and UnitName("player")) or "Unknown"

    local fullName = primaryName
    if secondaryName and secondaryName ~= "" and secondaryName ~= primaryName then
        fullName = primaryName .. " " .. secondaryName
    end

    return primaryName, secondaryName, fullName
end

function CLIAlts:GetCharacterKey(name, realm)
    if not name or name == "" then
        local _, _, full = self:GetPlayerNames()
        name = full or "Unknown"
    end
    -- In WoW Forever, characters are identified purely by their two names
    return name
end

-- ----------------------------------------------------------------------------
-- Data Collection: Professions
-- ----------------------------------------------------------------------------
function CLIAlts:CollectProfessions()
    local primary = {}
    local secondary = {}
    local seen = {}

    -- Wrap in pcall to guarantee no crash halts character collection
    pcall(function()
        -- Method 1: Modern API (GetProfessions & GetProfessionInfo)
        if GetProfessions and GetProfessionInfo then
            local p1, p2, arch, fish, cook, firstAid = GetProfessions()
            local list = {
                { slot = p1, category = "primary" },
                { slot = p2, category = "primary" },
                { slot = cook, category = "secondary" },
                { slot = firstAid, category = "secondary" },
                { slot = fish, category = "secondary" },
                { slot = arch, category = "secondary" },
            }
            for _, item in ipairs(list) do
                if item.slot then
                    local name, icon, skillLevel, maxSkillLevel = GetProfessionInfo(item.slot)
                    if name and skillLevel and not seen[name] then
                        seen[name] = true
                        local data = {
                            name = name,
                            rank = skillLevel,
                            maxRank = maxSkillLevel or 300,
                        }
                        if item.category == "primary" then
                            table.insert(primary, data)
                        else
                            table.insert(secondary, data)
                        end
                    end
                end
            end
        end

        -- Method 2: Classic Skill Lines (GetNumSkillLines & GetSkillLineInfo)
        if (#primary == 0 or #secondary == 0) and GetNumSkillLines and GetSkillLineInfo then
            local numSkills = GetNumSkillLines() or 0
            local currentHeader = ""
            for i = 1, numSkills do
                local skillName, isHeader, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(i)
                if isHeader then
                    currentHeader = skillName or ""
                elseif skillName and skillRank and not seen[skillName] then
                    local isPrimary = KNOWN_PRIMARY_PROFS[skillName] or (currentHeader == "Professions")
                    local isSecondary = KNOWN_SECONDARY_PROFS[skillName] or (currentHeader == "Secondary Skills")

                    if isPrimary and #primary < 2 then
                        seen[skillName] = true
                        table.insert(primary, {
                            name = skillName,
                            rank = skillRank,
                            maxRank = skillMaxRank or 300,
                        })
                    elseif isSecondary then
                        seen[skillName] = true
                        table.insert(secondary, {
                            name = skillName,
                            rank = skillRank,
                            maxRank = skillMaxRank or 300,
                        })
                    end
                end
            end
        end
    end)

    return {
        primary = primary,
        secondary = secondary,
    }
end

-- ----------------------------------------------------------------------------
-- Data Collection: Current Logged-in Character
-- ----------------------------------------------------------------------------
function CLIAlts:CollectCurrentCharacter(isLogout)
    self:InitDB()

    local primaryName, secondaryName, fullName = self:GetPlayerNames()
    if not primaryName or primaryName == "" or primaryName == "Unknown" then
        return nil
    end

    local realm = (GetRealmName and GetRealmName()) or ""
    if realm == "" then
        realm = "Forever"
    end

    local charKey = self:GetCharacterKey(fullName, realm)
    local englishFaction, locFaction
    if UnitFactionGroup then
        englishFaction, locFaction = UnitFactionGroup("player")
    end

    local locRace, raceFile
    if UnitRace then
        locRace, raceFile = UnitRace("player")
    end

    local locClass, classFile
    if UnitClass then
        locClass, classFile = UnitClass("player")
    end

    local existing = CLIAltsDB.characters and (CLIAltsDB.characters[charKey] or CLIAltsDB.characters[fullName])

    local level = (UnitLevel and UnitLevel("player")) or 1
    local curXP = (UnitXP and UnitXP("player")) or 0
    local maxXP = (UnitXPMax and UnitXPMax("player")) or 0
    local restedXP = (GetXPExhaustion and GetXPExhaustion()) or 0
    local liveResting = (IsResting and IsResting() and true or false)
    local money = (GetMoney and GetMoney()) or 0

    -- Prevent early login uninitialized 0s from wiping out valid saved data
    if maxXP <= 0 and existing and existing.maxXP and existing.maxXP > 0 then
        maxXP = existing.maxXP
    end
    if maxXP <= 0 and level < 60 then
        maxXP = self.XP_TABLE[level] or (level * 1000)
    end
    if existing and existing.level and level > existing.level then
        -- Leveled up: start fresh at current level
    elseif curXP <= 0 and existing and existing.xp and existing.xp > 0 then
        curXP = existing.xp
    end
    if money <= 0 and existing and existing.money and existing.money > 0 then
        money = existing.money
    end
    if restedXP <= 0 and existing and existing.restedXP and existing.restedXP > 0 and not liveResting then
        restedXP = existing.restedXP
    end

    local zone = (GetZoneText and GetZoneText()) or ""
    local subZone = (GetSubZoneText and GetSubZoneText()) or ""
    local location = zone
    if subZone and subZone ~= "" and subZone ~= zone then
        location = zone .. " (" .. subZone .. ")"
    end

    -- Preserve existing location if client zone API returned empty during logout
    if (not location or location == "") and existing and existing.location and existing.location ~= "" then
        location = existing.location
    end

    -- Robust resting determination for logout / session tracking
    local isResting = liveResting
    if not isResting then
        if self.isPlayerResting == true then
            isResting = true
        elseif self:IsLocationResting(location) then
            isResting = true
        elseif isLogout and existing and existing.isResting and (location == (existing.location or "")) then
            isResting = true
        end
    else
        self.isPlayerResting = true
    end

    local professions = self:CollectProfessions()
    local now = time()

    local charData = {
        name = fullName,
        primaryName = primaryName,
        secondaryName = secondaryName,
        fullName = fullName,
        realm = realm,
        faction = englishFaction or "Neutral",
        factionLoc = locFaction or englishFaction or "Neutral",
        race = locRace or "Unknown",
        raceFile = raceFile or "Unknown",
        class = locClass or "Unknown",
        classFile = classFile or "WARRIOR",
        level = level,
        xp = curXP,
        maxXP = maxXP,
        restedXP = restedXP,
        isResting = isResting,
        loggedOutInRestZone = isResting,
        money = money,
        location = location,
        professions = professions,
        lastUpdate = now,
        logoutTime = (isLogout and now) or (existing and existing.logoutTime) or now,
    }

    if not CLIAltsDB.characters then
        CLIAltsDB.characters = {}
    end
    CLIAltsDB.characters[charKey] = charData

    return charData
end

-- ----------------------------------------------------------------------------
-- Rested Zone & Location Detection Helpers
-- ----------------------------------------------------------------------------
function CLIAlts:IsLocationResting(loc)
    if not loc or loc == "" then return false end
    local l = loc:lower()

    -- Common inn/tavern/camp/tent keywords
    if l:find("inn") or l:find("tavern") or l:find("lodge") or l:find("saloon")
       or l:find("camp") or l:find("campsite") or l:find("tent") or l:find("resting")
       or l:find("haven") or l:find("refuge") or l:find("sanctuary") then
        return true
    end

    -- Major cities & sanctuary hubs
    local cities = {
        "stormwind", "ironforge", "darnassus", "exodar", "deeprun tram",
        "orgrimmar", "undercity", "thunder bluff", "silvermoon",
        "shattrath", "dalaran", "booty bay", "gadgetzan", "everlook", "ratchet"
    }
    for _, city in ipairs(cities) do
        if l:find(city) then
            return true
        end
    end

    -- Well-known resting subzones & settlements
    local settlements = {
        "goldshire", "kharanos", "thelsamar", "lakeshire", "darkshire",
        "sentinel hill", "southshore", "menethil", "auberdine", "astranaar",
        "feathermoon", "nijel", "thalanaar", "aerie peak", "nethergarde",
        "stoutlager", "pride", "razor hill", "bloodhoof", "brill",
        "the crossroads", "crossroads", "tarren mill", "sun rock", "freewind",
        "shadowprey", "camp taurajo", "camp narache", "camp mojache",
        "kargath", "hammerfall", "stonard", "revantusk", "light's hope",
        "thorium point", "cenarion"
    }
    for _, town in ipairs(settlements) do
        if l:find(town) then
            return true
        end
    end

    return false
end

function CLIAlts:IsCharacterResting(char)
    if not char then return false end

    -- 1. If currently logged in as this character, live IsResting() is authoritative
    local curPrimary, curSecondary, curFull = self:GetPlayerNames()
    local isCurrent = (char.fullName and char.fullName == curFull)
        or (char.name and char.name == curFull)
        or (char.primaryName and char.primaryName == curPrimary)
        or (char.name and char.name == curPrimary)

    if isCurrent then
        if IsResting and IsResting() then
            return true
        end
        if self.isPlayerResting == true then
            return true
        end
    end

    -- 2. Explicit logged-out resting flag recorded at logout
    if char.loggedOutInRestZone ~= nil then
        if char.loggedOutInRestZone == true then
            return true
        end
    elseif char.isResting == true then
        return true
    end

    -- 3. Location string pattern match (inn, tavern, city, camp, tent)
    if self:IsLocationResting(char.location) then
        return true
    end

    return false
end

-- ----------------------------------------------------------------------------
-- WoW Forever Legacy Perk: "Well Rested" (Adventure Tree, Ranks 0-5)
-- Each rank gives +4% accumulation speed and +4% max rested cap (up to +20%).
-- ----------------------------------------------------------------------------
function CLIAlts:SetWellRestedRank(rank)
    rank = tonumber(rank) or 0
    if rank < 0 then rank = 0 end
    if rank > 5 then rank = 5 end

    CLIAltsDB.settings = CLIAltsDB.settings or {}
    CLIAltsDB.settings.wellRestedRank = rank

    local speedBonus = rank * 4
    local capPercent = 150 + (rank * 6)
    self:Print(string.format("Well Rested perk set to |cffffffffRank %d/5|r (+%d%% rest speed, %d%% cap).", rank, speedBonus, capPercent))

    if CLIAltsMainFrame and CLIAltsMainFrame:IsShown() then
        self:Render()
    end
end

function CLIAlts:CycleWellRestedPerk()
    local currentRank = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
    local nextRank = (currentRank + 1) % 6
    self:SetWellRestedRank(nextRank)
end

-- ----------------------------------------------------------------------------
-- Level Experience Progress (Current XP, Max XP, %, and ASCII Progress Bar)
-- ----------------------------------------------------------------------------
function CLIAlts:GetLevelProgressData(char)
    if not char then return nil end

    local level = char.level or 1
    local isMaxLevel = (level >= 60)
    local curXP = char.xp or 0
    local maxXP = char.maxXP or 0

    -- If currently logged in as this character, read live client values
    local curPrimary, curSecondary, curFull = self:GetPlayerNames()
    local isCurrent = (char.fullName and char.fullName == curFull)
        or (char.name and char.name == curFull)
        or (char.primaryName and char.primaryName == curPrimary)
        or (char.name and char.name == curPrimary)

    if isCurrent and not isMaxLevel then
        if UnitXP and UnitXPMax then
            local liveCur = UnitXP("player") or 0
            local liveMax = UnitXPMax("player") or 0
            if liveMax > 0 then
                curXP = liveCur
                maxXP = liveMax
                char.xp = liveCur
                char.maxXP = liveMax
            end
        end
    end

    if maxXP <= 0 and not isMaxLevel then
        maxXP = self.XP_TABLE[level] or (level * 1000)
    end

    if isMaxLevel then
        return {
            isMaxLevel = true,
            curXP = 0,
            maxXP = 0,
            remainingXP = 0,
            percent = 100,
            percentExact = 100,
            ratio = 1.0,
            barStr = "[============]",
            text = "MAX LEVEL",
            shortText = "MAX",
        }
    end

    local percentExact = (maxXP > 0) and ((curXP / maxXP) * 100) or 0
    local percent = math.min(100, math.floor(percentExact))
    local remainingXP = math.max(0, maxXP - curXP)
    local ratio = (maxXP > 0) and math.min(1.0, curXP / maxXP) or 0

    -- 12-char ASCII Progress Bar
    local barLength = 12
    local fillCount = (maxXP > 0) and math.min(barLength, math.floor((curXP / maxXP) * barLength)) or 0
    local emptyCount = barLength - fillCount
    local barStr = "[" .. string.rep("=", fillCount) .. string.rep(".", emptyCount) .. "]"

    return {
        isMaxLevel = false,
        curXP = curXP,
        maxXP = maxXP,
        remainingXP = remainingXP,
        percent = percent,
        percentExact = percentExact,
        ratio = ratio,
        barStr = barStr,
        text = string.format("%s / %s (%d%%)", self:FormatNumber(curXP), self:FormatNumber(maxXP), percent),
        shortText = string.format("%d%%", percent),
    }
end

-- ----------------------------------------------------------------------------
-- Rested XP Calculator & Offline Projection (WoW Forever Enhanced)
-- ----------------------------------------------------------------------------
function CLIAlts:GetRestedData(char)
    if not char then return nil end

    local currentLevel = char.level or 1
    local maxXP = char.maxXP or 0
    local baseRested = char.restedXP or 0
    local lastUpdate = char.lastUpdate or time()

    -- Well Rested Perk (0 to 5 ranks)
    local perkRank = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
    if perkRank < 0 then perkRank = 0 end
    if perkRank > 5 then perkRank = 5 end

    local speedMult = 1 + (perkRank * 0.04)   -- +4% speed per rank (1.00 to 1.20)
    local capMult = 1.5 * speedMult           -- +4% cap per rank (1.50 to 1.80)
    local maxPercent = math.floor((capMult * 100) + 0.5) -- 150 to 180

    -- Max level characters
    if currentLevel >= 60 then
        return {
            isMaxLevel = true,
            currentRested = 0,
            maxRested = 0,
            percent = 0,
            maxPercent = maxPercent,
            ratio = 1.0,
            perkRank = perkRank,
            speedMult = speedMult,
            isFull = false,
            timeToFull = 0,
            fullDate = "N/A",
            timeLeftStr = "MAX LEVEL",
            statusStr = "[ MAX LVL ]",
            barStr = "[============]",
            isResting = false,
            ratePerSec = 0,
        }
    end

    -- Fallback to standard Classic XP if maxXP is not yet initialized
    if maxXP <= 0 and currentLevel < 60 then
        maxXP = self.XP_TABLE[currentLevel] or (currentLevel * 1000)
    end

    local maxRested = maxXP * capMult

    -- Check if currently logged in as this character
    local isCurrentPlayer = false
    local curPrimary, curSecondary, curFull = self:GetPlayerNames()
    if (char.fullName and char.fullName == curFull) or (char.name == curFull) or (char.primaryName and char.primaryName == curPrimary) or (char.name == curPrimary) then
        isCurrentPlayer = true
    end

    -- Robust resting determination (evaluated BEFORE rate calculation)
    local isResting = self:IsCharacterResting(char)

    local now = time()
    local elapsed = math.max(0, now - lastUpdate)

    -- Rested XP rates:
    -- In Inn/City/Camp/Tent: 1 bubble (5% of maxXP) per 8 hours = maxXP / 576,000 sec
    -- In Wilderness: 1.25% of maxXP per 8 hours = maxXP / 2,304,000 sec
    -- Multiplied by Well Rested speed bonus
    local baseRate = isResting and (maxXP / 576000) or (maxXP / 2304000)
    local ratePerSec = baseRate * speedMult

    local currentRested
    if isCurrentPlayer then
        currentRested = (GetXPExhaustion and GetXPExhaustion()) or 0
    else
        currentRested = math.min(maxRested, baseRested + (elapsed * ratePerSec))
    end

    -- Percentage of current level's max XP
    local percent = (maxXP > 0) and math.floor((currentRested / maxXP) * 100) or 0
    local isFull = (currentRested >= maxRested)

    local timeToFull = 0
    local fullDate = "N/A"
    local timeLeftStr = string.format("FULL (%d%%)", maxPercent)

    if isFull then
        timeLeftStr = string.format("FULL (%d%%)", maxPercent)
        fullDate = "Ready Now"
    else
        local remainingXP = math.max(0, maxRested - currentRested)
        timeToFull = (ratePerSec > 0) and math.ceil(remainingXP / ratePerSec) or 0

        local days = math.floor(timeToFull / 86400)
        local hours = math.floor((timeToFull % 86400) / 3600)
        local mins = math.floor((timeToFull % 3600) / 60)

        if days > 0 then
            timeLeftStr = string.format("%dd %dh", days, hours)
        elseif hours > 0 then
            timeLeftStr = string.format("%dh %dm", hours, mins)
        else
            timeLeftStr = string.format("%dm", mins)
        end

        fullDate = date("%b %d, %H:%M", now + timeToFull)
    end

    -- Status string
    local statusStr
    if isFull then
        statusStr = "[ FULL ]"
    elseif isResting then
        statusStr = "[ INN ]"
    else
        statusStr = "[ WILD ]"
    end

    -- ASCII Progress Bar (12 characters wide)
    local barLength = 12
    local fillCount = (maxRested > 0) and math.min(barLength, math.floor((currentRested / maxRested) * barLength)) or 0
    local emptyCount = barLength - fillCount
    local barStr = "[" .. string.rep("=", fillCount) .. string.rep(".", emptyCount) .. "]"

    -- Rested ratio toward cap (0.0 to 1.0)
    local ratio = (maxRested > 0) and math.min(1.0, currentRested / maxRested) or 0

    return {
        isMaxLevel = false,
        currentRested = math.floor(currentRested),
        maxRested = math.floor(maxRested),
        percent = percent,
        maxPercent = maxPercent,
        ratio = ratio,
        perkRank = perkRank,
        speedMult = speedMult,
        isFull = isFull,
        timeToFull = timeToFull,
        fullDate = fullDate,
        timeLeftStr = timeLeftStr,
        statusStr = statusStr,
        barStr = barStr,
        isResting = isResting,
        ratePerSec = ratePerSec,
    }
end

-- ----------------------------------------------------------------------------
-- Formatting Helpers
-- ----------------------------------------------------------------------------
function CLIAlts:FormatNumber(n)
    n = tonumber(n) or 0
    local formatted = tostring(math.floor(math.abs(n)))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    if n < 0 then
        return "-" .. formatted
    end
    return formatted
end

function CLIAlts:FormatMoney(copper, colorize)
    copper = tonumber(copper) or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperRem = math.floor(copper % 100)

    if colorize then
        local parts = {}
        if gold > 0 then
            table.insert(parts, string.format("|cffffd700%dg|r", gold))
        end
        if silver > 0 or gold > 0 then
            table.insert(parts, string.format("|cffc7c7cf%ds|r", silver))
        end
        table.insert(parts, string.format("|cffeda55f%dc|r", copperRem))
        return table.concat(parts, " ")
    else
        return string.format("%dg %ds %dc", gold, silver, copperRem)
    end
end

function CLIAlts:GetClassColor(classFile)
    local r, g, b = 1, 1, 1
    if RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        r = c.r or 1
        g = c.g or 1
        b = c.b or 1
    elseif classFile and FALLBACK_CLASS_COLORS[classFile] then
        local c = FALLBACK_CLASS_COLORS[classFile]
        r = c.r or 1
        g = c.g or 1
        b = c.b or 1
    end

    -- Strictly compute a 6-digit hex string (RRGGBB) without alpha channel
    local hex = string.format("%02x%02x%02x",
        math.min(255, math.max(0, math.floor(r * 255 + 0.5))),
        math.min(255, math.max(0, math.floor(g * 255 + 0.5))),
        math.min(255, math.max(0, math.floor(b * 255 + 0.5)))
    )
    return r, g, b, hex
end

function CLIAlts:ColorizePlayerName(name, classFile)
    local _, _, _, hex = self:GetClassColor(classFile)
    return string.format("|cff%s%s|r", hex or "ffffff", name or "Unknown")
end

function CLIAlts:GetFactionTag(faction)
    if faction == "Alliance" then
        return "|cff0070dd[A]|r"
    elseif faction == "Horde" then
        return "|cffc41e3a[H]|r"
    else
        return "|cffffff00[N]|r"
    end
end

function CLIAlts:GetTimeAgo(timestamp)
    if not timestamp or timestamp == 0 then return "Unknown" end
    local elapsed = math.max(0, time() - timestamp)
    if elapsed < 60 then
        return "Just now"
    elseif elapsed < 3600 then
        return string.format("%dm ago", math.floor(elapsed / 60))
    elseif elapsed < 86400 then
        return string.format("%dh ago", math.floor(elapsed / 3600))
    else
        return string.format("%dd ago", math.floor(elapsed / 86400))
    end
end

-- ----------------------------------------------------------------------------
-- CRUD Operations & Querying
-- ----------------------------------------------------------------------------
function CLIAlts:DeleteCharacter(charKey)
    if not CLIAltsDB or not CLIAltsDB.characters or not charKey then return false end
    if CLIAltsDB.characters[charKey] then
        CLIAltsDB.characters[charKey] = nil
        return true
    end
    -- Fallback: check if char.fullName or char.name or key matches
    for k, char in pairs(CLIAltsDB.characters) do
        if k == charKey or char.fullName == charKey or char.name == charKey then
            CLIAltsDB.characters[k] = nil
            return true
        end
    end
    return false
end

function CLIAlts:GetCharactersList(sortBy, sortAsc)
    local list = {}
    if not CLIAltsDB or not CLIAltsDB.characters then
        return list
    end

    for key, char in pairs(CLIAltsDB.characters) do
        char.key = key
        table.insert(list, char)
    end

    sortBy = sortBy or CLIAltsDB.settings.sortBy or "level"
    if sortAsc == nil then
        sortAsc = CLIAltsDB.settings.sortAsc or false
    end

    table.sort(list, function(a, b)
        if sortBy == "name" then
            if sortAsc then return (a.name or "") < (b.name or "") else return (a.name or "") > (b.name or "") end
        elseif sortBy == "gold" then
            if sortAsc then return (a.money or 0) < (b.money or 0) else return (a.money or 0) > (b.money or 0) end
        elseif sortBy == "xp" or sortBy == "progress" then
            local pA = (a.maxXP and a.maxXP > 0) and ((a.xp or 0) / a.maxXP) or 0
            local pB = (b.maxXP and b.maxXP > 0) and ((b.xp or 0) / b.maxXP) or 0
            if pA == pB then
                return (a.level or 0) > (b.level or 0)
            end
            if sortAsc then return pA < pB else return pA > pB end
        elseif sortBy == "rested" then
            local rA = CLIAlts:GetRestedData(a)
            local rB = CLIAlts:GetRestedData(b)
            local pA = rA and rA.percent or 0
            local pB = rB and rB.percent or 0
            if sortAsc then return pA < pB else return pA > pB end
        else -- default "level"
            local lvlA = a.level or 0
            local lvlB = b.level or 0
            if lvlA == lvlB then
                return (a.name or "") < (b.name or "")
            end
            if sortAsc then return lvlA < lvlB else return lvlA > lvlB end
        end
    end)

    return list
end

function CLIAlts:GetAccountSummary()
    local totalGold = 0
    local totalAlts = 0
    local fullyRested = 0
    local nextFullAlt = nil
    local lowestTimeToFull = 999999999

    local chars = self:GetCharactersList()
    totalAlts = #chars

    for _, char in ipairs(chars) do
        totalGold = totalGold + (char.money or 0)
        local rested = self:GetRestedData(char)
        if rested then
            if rested.isFull then
                fullyRested = fullyRested + 1
            elseif not rested.isMaxLevel and rested.timeToFull > 0 then
                if rested.timeToFull < lowestTimeToFull then
                    lowestTimeToFull = rested.timeToFull
                    nextFullAlt = {
                        name = char.name,
                        classFile = char.classFile,
                        timeLeftStr = rested.timeLeftStr,
                        fullDate = rested.fullDate,
                    }
                end
            end
        end
    end

    return {
        totalGold = totalGold,
        totalAlts = totalAlts,
        fullyRested = fullyRested,
        nextFullAlt = nextFullAlt,
    }
end
