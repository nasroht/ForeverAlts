-- ============================================================================
-- CLIAlts: Retro Alt Tracker
-- File: data.lua
-- Database management, character data collection, and rested XP calculations.
-- ============================================================================

local addonName, addonTable = ...
local CLIAlts = addonTable
_G["CLIAlts"] = CLIAlts
_G["clialts"] = CLIAlts

-- ----------------------------------------------------------------------------
-- Constants & Reference Tables
-- ----------------------------------------------------------------------------
CLIAlts.VERSION = "1.0.0"
CLIAlts.DB_VERSION = 3
local CURRENT_DB_VERSION = 3

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

-- ----------------------------------------------------------------------------
-- Level Cap Helper (WoW Forever / Classic / Expansion Dynamic Cap)
-- ----------------------------------------------------------------------------
function CLIAlts:GetMaxLevel()
    if GetMaxPlayerLevel then
        local ml = GetMaxPlayerLevel()
        if ml and type(ml) == "number" and ml > 0 then
            if CLIAltsDB and CLIAltsDB.settings then
                CLIAltsDB.settings.maxLevel = ml
            end
            return ml
        end
    end
    return (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.maxLevel) or 60
end

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
-- Format Helper: Race and Class Clean Display (3-Letter Retro TUI Codes)
-- ----------------------------------------------------------------------------
local RACE_CODES = {
    ["Human"]               = "HUM",
    ["HUMAN"]               = "HUM",
    ["Dwarf"]               = "DWA",
    ["DWARF"]               = "DWA",
    ["Night Elf"]           = "NEL",
    ["NightElf"]            = "NEL",
    ["NIGHTELF"]            = "NEL",
    ["Gnome"]               = "GNO",
    ["GNOME"]               = "GNO",
    ["Draenei"]             = "DRA",
    ["DRAENEI"]             = "DRA",
    ["Orc"]                 = "ORC",
    ["ORC"]                 = "ORC",
    ["Undead"]              = "UND",
    ["Scourge"]             = "UND",
    ["SCOURGE"]             = "UND",
    ["Tauren"]              = "TAU",
    ["TAUREN"]              = "TAU",
    ["Troll"]               = "TRO",
    ["TROLL"]               = "TRO",
    ["Blood Elf"]           = "BEL",
    ["BloodElf"]            = "BEL",
    ["BLOODELF"]            = "BEL",
    ["Goblin"]              = "GOB",
    ["GOBLIN"]              = "GOB",
    ["Worgen"]              = "WOR",
    ["WORGEN"]              = "WOR",
    ["Pandaren"]            = "PAN",
    ["PANDAREN"]            = "PAN",
    ["Dracthyr"]            = "DTH",
    ["DRACTHYR"]            = "DTH",
    ["Skyborne"]            = "SKY",
    ["SKYBORNE"]            = "SKY",
    ["High Order Skyborne"] = "SKY",
    ["HIGHORDERSKYBORNE"]   = "SKY",
}

function CLIAlts:GetRaceCode(char)
    if not char then return "UNK" end

    -- Prefer stored localized race over internal engine raceFile token
    local r = (char.race and char.race ~= "" and char.race ~= "Unknown") and char.race or char.raceFile
    if not r or r == "" or r == "Unknown" then
        return "UNK"
    end

    if RACE_CODES[r] then
        return RACE_CODES[r]
    end

    local upper = string.upper(r)
    if RACE_CODES[upper] then
        return RACE_CODES[upper]
    end

    -- Pattern matches for custom / composite race names
    if upper:find("SKYBORNE") then return "SKY" end
    if upper:find("NIGHT") then return "NEL" end
    if upper:find("BLOOD") then return "BEL" end
    if upper:find("SCOURGE") or upper:find("UNDEAD") then return "UND" end
    if upper:find("DWARF") then return "DWA" end
    if upper:find("GNOME") then return "GNO" end
    if upper:find("HUMAN") then return "HUM" end
    if upper:find("DRAENEI") then return "DRA" end
    if upper:find("TAUREN") then return "TAU" end
    if upper:find("TROLL") then return "TRO" end
    if upper:find("ORC") then return "ORC" end
    if upper:find("GOBLIN") then return "GOB" end
    if upper:find("WORGEN") then return "WOR" end
    if upper:find("PANDA") then return "PAN" end
    if upper:find("DRAC") then return "DTH" end

    -- Fallback: first 3 non-whitespace characters uppercased
    local clean = upper:gsub("%s+", "")
    if #clean >= 3 then
        return string.sub(clean, 1, 3)
    elseif #clean > 0 then
        return clean
    end
    return "UNK"
end

function CLIAlts:FormatRace(char)
    if not char then return "Unknown" end

    -- Prefer stored localized race
    local race = (char.race and char.race ~= "" and char.race ~= "Unknown") and char.race or nil
    if not race then
        local rf = char.raceFile
        if rf == "Scourge" then
            race = "Undead"
        elseif rf == "NightElf" then
            race = "Night Elf"
        elseif rf == "BloodElf" then
            race = "Blood Elf"
        else
            race = rf or "Unknown"
        end
    end

    if race:find("Skyborne") then
        race = "Skyborne"
    end

    return race
end

function CLIAlts:FormatRaceClass(char)
    if not char then return "Unknown" end
    local code = self:GetRaceCode(char)
    local class = char.class or "Unknown"
    return string.format("%s %s", code, class)
end

-- ----------------------------------------------------------------------------
-- Database Initialization & Two-Name Migration
-- ----------------------------------------------------------------------------
function CLIAlts:InitDB()
    if self.dbInitialized and CLIAltsDB and CLIAltsDB.characters and CLIAltsDB.settings and CLIAltsDB.dbVersion == CURRENT_DB_VERSION then
        return
    end

    local oldDB = rawget(_G, "NasaltsDB")
    if not CLIAltsDB and oldDB then
        CLIAltsDB = oldDB
    end
    if not CLIAltsDB then
        CLIAltsDB = {}
    end
    CLIAltsDB.settings = CLIAltsDB.settings or {}
    CLIAltsDB.settings.theme = CLIAltsDB.settings.theme or "GREEN"
    CLIAltsDB.settings.minimapPos = CLIAltsDB.settings.minimapPos or 45
    CLIAltsDB.settings.minimapShow = (CLIAltsDB.settings.minimapShow ~= false)
    CLIAltsDB.settings.sortBy = CLIAltsDB.settings.sortBy or "name"
    CLIAltsDB.settings.sortAsc = (CLIAltsDB.settings.sortAsc == true)
    CLIAltsDB.settings.activeTab = CLIAltsDB.settings.activeTab or 1
    CLIAltsDB.settings.wellRestedRank = tonumber(CLIAltsDB.settings.wellRestedRank) or 0
    CLIAltsDB.characters = CLIAltsDB.characters or {}
    CLIAltsDB.goldHistory = CLIAltsDB.goldHistory or {}
    CLIAltsDB.watchlist = CLIAltsDB.watchlist or {}
    CLIAltsDB.commandHistory = CLIAltsDB.commandHistory or {}

    -- Run one-time migration and repair only if dbVersion is older than CURRENT_DB_VERSION
    if (tonumber(CLIAltsDB.dbVersion) or 0) < CURRENT_DB_VERSION then
        -- Merge / restore character data and professions from old NasaltsDB if available
        if oldDB and oldDB ~= CLIAltsDB and oldDB.characters then
            for oldKey, oldChar in pairs(oldDB.characters) do
                local cleanOldKey = oldChar.fullName or oldChar.name or oldKey
                cleanOldKey = cleanOldKey:match("^(.-)%s*-%s*.*$") or cleanOldKey

                -- Find if this character already exists in CLIAltsDB
                local target = CLIAltsDB.characters[cleanOldKey] or CLIAltsDB.characters[oldKey]
                if not target then
                    for k, c in pairs(CLIAltsDB.characters) do
                        local n = c.fullName or c.name or k
                        if n == cleanOldKey or (n and cleanOldKey and (n:find(cleanOldKey, 1, true) or cleanOldKey:find(n, 1, true))) then
                            target = c
                            break
                        end
                    end
                end

                if not target then
                    -- Import character that was tracked in NasaltsDB but missing in CLIAltsDB
                    CLIAltsDB.characters[cleanOldKey] = oldChar
                else
                    -- Restore professions if current character has empty professions but old character has recorded ones
                    local curProf = target.professions
                    local oldProf = oldChar.professions
                    local hasCur = curProf and ((curProf.primary and #curProf.primary > 0) or (curProf.secondary and #curProf.secondary > 0))
                    local hasOld = oldProf and ((oldProf.primary and #oldProf.primary > 0) or (oldProf.secondary and #oldProf.secondary > 0))
                    if not hasCur and hasOld then
                        target.professions = oldProf
                    end
                end
            end
        end

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

            -- Initialize cleanLogout for pre-existing character records
            if char.cleanLogout == nil then
                char.cleanLogout = true
            end

            -- Ensure char.maxXP is initialized (populated dynamically from UnitXPMax snapshots)
            char.maxXP = char.maxXP or 0

            migrated[cleanKey] = char
        end
        CLIAltsDB.characters = migrated
        CLIAltsDB.dbVersion = CURRENT_DB_VERSION
    end

    if rawget(_G, "NasaltsDB") then
        _G["NasaltsDB"] = nil
    end
    self.dbInitialized = true
end

-- ----------------------------------------------------------------------------
-- Timer Helper
-- ----------------------------------------------------------------------------
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
CLIAlts.SafeAfter = SafeAfter

-- ----------------------------------------------------------------------------
-- Helper: Primary Name & Secondary Name (WoW Forever Support & Identity Cache)
-- ----------------------------------------------------------------------------
function CLIAlts:CacheCurrentPlayer()
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

    if primaryName and primaryName ~= "Unknown" and primaryName ~= "" then
        self.curPlayerPrimary = primaryName
        self.curPlayerSecondary = secondaryName
        self.curPlayerFullName = fullName

        local realm = (GetRealmName and GetRealmName()) or ""
        if realm == "" then realm = "Forever" end
        self.curPlayerRealm = realm
        self.curPlayerKey = self:GetCharacterKey(fullName, realm)
    end

    return primaryName, secondaryName, fullName
end

function CLIAlts:GetPlayerNames(force)
    if not force and self.curPlayerPrimary and self.curPlayerFullName then
        return self.curPlayerPrimary, self.curPlayerSecondary, self.curPlayerFullName
    end
    return self:CacheCurrentPlayer()
end

function CLIAlts:IsCurrentPlayer(char)
    if not char then return false end
    if not self.curPlayerKey then
        self:CacheCurrentPlayer()
    end
    local curKey = self.curPlayerKey
    if not curKey then return false end
    return (char.key == curKey) or (char.fullName == curKey) or (char.name == curKey)
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
            if ExpandSkillHeader then
                pcall(ExpandSkillHeader, 0)
            end
            local numSkills = GetNumSkillLines() or 0
            local currentHeader = ""
            for i = 1, numSkills do
                local skillName, isHeader, _, skillRank, _, _, skillMaxRank, isAbandonable = GetSkillLineInfo(i)
                if isHeader then
                    currentHeader = skillName or ""
                elseif skillName and skillRank and not seen[skillName] then
                    local canAbandon = (isAbandonable == true or isAbandonable == 1)
                    local isSecondary = KNOWN_SECONDARY_PROFS[skillName] or (currentHeader == "Secondary Skills")
                    local isPrimary = (not isSecondary) and (KNOWN_PRIMARY_PROFS[skillName] or (currentHeader == "Professions") or canAbandon)

                    if isSecondary then
                        seen[skillName] = true
                        table.insert(secondary, {
                            name = skillName,
                            rank = skillRank,
                            maxRank = skillMaxRank or 300,
                        })
                    elseif isPrimary and #primary < 2 then
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
-- Cooldowns, Lockouts, Mail & Watchlist Collectors
-- ----------------------------------------------------------------------------
local liveMailCount = nil
local liveMinMailDays = nil
local liveMailCheckedTime = nil

function CLIAlts:ScanMailInbox()
    pcall(function()
        if GetInboxNumItems and GetInboxHeaderInfo then
            local n = GetInboxNumItems() or 0
            liveMailCount = n
            liveMailCheckedTime = time()
            local minDays = 999
            for i = 1, n do
                local _, _, _, _, _, _, daysLeft = GetInboxHeaderInfo(i)
                if daysLeft and daysLeft < minDays then
                    minDays = daysLeft
                end
            end
            liveMinMailDays = (n > 0 and minDays < 999) and minDays or nil

            local curFull = self.curPlayerFullName or (select(3, self:GetPlayerNames()))
            if curFull and CLIAltsDB and CLIAltsDB.characters then
                local char = CLIAltsDB.characters[curFull] or CLIAltsDB.characters[self:GetCharacterKey(curFull)]
                if char then
                    char.mailCount = liveMailCount
                    char.minMailDays = liveMinMailDays
                    char.mailCheckedTime = liveMailCheckedTime
                end
            end
        end
    end)
end

function CLIAlts:CollectTradeCooldowns(existing)
    local cds = {}
    if existing then
        for k, v in pairs(existing) do cds[k] = v end
    end
    pcall(function()
        if GetNumTradeSkills and GetTradeSkillInfo and GetTradeSkillCooldown then
            local n = GetNumTradeSkills() or 0
            for i = 1, n do
                local name, skillType = GetTradeSkillInfo(i)
                if name and skillType ~= "header" then
                    local cd = GetTradeSkillCooldown(i)
                    if cd and cd > 0 then
                        cds[name] = time() + cd
                    elseif cd == 0 and cds[name] then
                        cds[name] = nil
                    end
                end
            end
        end
    end)
    return cds
end

function CLIAlts:CollectLockouts(existing)
    local locks = {}
    if existing then
        for k, v in pairs(existing) do locks[k] = v end
    end
    pcall(function()
        if GetNumSavedInstances and GetSavedInstanceInfo then
            local n = GetNumSavedInstances() or 0
            local now = time()
            local activeLocks = {}
            for i = 1, n do
                local name, id, reset, diff, locked, isExtended, isRaid, maxPlayers, diffName = GetSavedInstanceInfo(i)
                if locked and reset and reset > 0 then
                    activeLocks[name] = {
                        resetTime = now + reset,
                        id = id,
                        difficulty = diffName or diff or "Normal",
                        isRaid = isRaid,
                    }
                end
            end
            if n > 0 or not existing then
                locks = activeLocks
            end
        end
    end)
    return locks
end

function CLIAlts:CollectWatchlistCounts(existing)
    local counts = {}
    if existing then
        for k, v in pairs(existing) do counts[k] = v end
    end
    if not CLIAltsDB or not CLIAltsDB.watchlist then return counts end
    pcall(function()
        if GetItemCount then
            for _, item in ipairs(CLIAltsDB.watchlist) do
                if item and item ~= "" then
                    local count = GetItemCount(item, true)
                    counts[item] = count or 0
                end
            end
        end
    end)
    return counts
end

function CLIAlts:UpdateWatchCounts()
    if not CLIAltsDB or not CLIAltsDB.characters then return end
    local curKey = self.curPlayerKey
    if not curKey then
        local _, _, full = self:GetPlayerNames()
        curKey = full and self:GetCharacterKey(full)
    end
    local char = curKey and CLIAltsDB.characters[curKey]
    if char then
        char.watchlistCounts = self:CollectWatchlistCounts(char.watchlistCounts)
    end
end

-- ----------------------------------------------------------------------------
-- Data Collection: Current Logged-in Character (Throttled to 1s)
-- ----------------------------------------------------------------------------
local lastCollectTime = 0
local cachedCurrentChar = nil
local collectPending = false

function CLIAlts:CollectCurrentCharacter(isLogout, force)
    self:InitDB()

    local nowTime = (GetTime and GetTime()) or time()
    if not isLogout and not force and cachedCurrentChar and (nowTime - lastCollectTime < 1.0) then
        if not collectPending then
            collectPending = true
            local safeAfter = self.SafeAfter or (C_Timer and C_Timer.After)
            if safeAfter then
                safeAfter(1.0, function()
                    collectPending = false
                    CLIAlts:CollectCurrentCharacter(false, true)
                    if CLIAlts.RequestRender then
                        CLIAlts:RequestRender()
                    end
                end)
            end
        end
        return cachedCurrentChar
    end

    lastCollectTime = nowTime

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

    -- Trust only IsResting() at logout and live gameplay without fuzzy location matching
    local isResting = liveResting
    local cleanLogout = (isLogout == true)

    local professions = self:CollectProfessions()
    local hasNewPrimary = (professions and professions.primary and #professions.primary > 0)
    local hasNewSecondary = (professions and professions.secondary and #professions.secondary > 0)

    -- Prevent logout or uninitialized skill lines from wiping out valid saved professions
    if existing and existing.professions then
        if not hasNewPrimary and existing.professions.primary and #existing.professions.primary > 0 then
            professions.primary = existing.professions.primary
        end
        if not hasNewSecondary and existing.professions.secondary and #existing.professions.secondary > 0 then
            professions.secondary = existing.professions.secondary
        end
    end

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
        cleanLogout = cleanLogout,
        money = money,
        location = location,
        professions = professions,
        tradeCooldowns = self:CollectTradeCooldowns(existing and existing.tradeCooldowns),
        lockouts = self:CollectLockouts(existing and existing.lockouts),
        mailCount = liveMailCount or (existing and existing.mailCount),
        minMailDays = liveMinMailDays or (existing and existing.minMailDays),
        mailCheckedTime = liveMailCheckedTime or (existing and existing.mailCheckedTime),
        watchlistCounts = self:CollectWatchlistCounts(existing and existing.watchlistCounts),
        lastUpdate = now,
        logoutTime = (isLogout and now) or (existing and existing.logoutTime) or now,
    }

    if not CLIAltsDB.characters then
        CLIAltsDB.characters = {}
    end
    CLIAltsDB.characters[charKey] = charData
    cachedCurrentChar = charData
    if self.InvalidateRestedCache then
        self:InvalidateRestedCache()
    end

    return charData
end

-- ----------------------------------------------------------------------------
-- Rested Zone & Location Detection Helpers
-- ----------------------------------------------------------------------------

function CLIAlts:IsCharacterResting(char)
    if not char then return false end

    -- 1. If currently logged in as this character, live IsResting() is authoritative
    if self:IsCurrentPlayer(char) then
        return (IsResting and IsResting() and true or false)
    end

    -- 2. Explicit resting flag recorded at logout (trust only what client reported)
    if char.loggedOutInRestZone ~= nil then
        return (char.loggedOutInRestZone == true)
    end
    if char.isResting ~= nil then
        return (char.isResting == true)
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

    local maxLevel = self:GetMaxLevel()
    local level = char.level or 1
    local isMaxLevel = (level >= maxLevel)
    local curXP = char.xp or 0
    local maxXP = char.maxXP or 0

    -- If currently logged in as this character, read live client values
    local isCurrent = self:IsCurrentPlayer(char)

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
-- Rested XP Calculator & Offline Projection (With In-Memory Render Cache)
-- ----------------------------------------------------------------------------
local RESTED_CACHE_TTL = 1.0
local restedDataCache = {}

function CLIAlts:InvalidateRestedCache()
    for k in pairs(restedDataCache) do
        restedDataCache[k] = nil
    end
end

function CLIAlts:GetRestedData(char, force, nowOverride)
    if not char then return nil end

    local charKey = char.key or char.fullName or char.name or tostring(char)
    local nowTime = nowOverride or (GetTime and GetTime()) or time()

    if not force and not nowOverride and restedDataCache[charKey] then
        local entry = restedDataCache[charKey]
        if entry.time and (nowTime - entry.time < RESTED_CACHE_TTL) then
            return entry.data
        end
    end

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

    local maxLevel = self:GetMaxLevel()

    -- Max level characters
    if currentLevel >= maxLevel then
        local maxData = {
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
        restedDataCache[charKey] = { time = nowTime, data = maxData }
        return maxData
    end

    local maxRested = (maxXP > 0) and (maxXP * capMult) or 0

    -- Check if currently logged in as this character
    local isCurrentPlayer = self:IsCurrentPlayer(char)

    -- Robust resting determination (evaluated BEFORE rate calculation)
    local isResting = self:IsCharacterResting(char)

    local now = nowOverride or time()
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

    -- If alt experienced an unclean logout (disconnect or crash), flag projection as estimated
    local isEstimate = (not isCurrentPlayer and char.cleanLogout == false)
    if isEstimate then
        if isFull then
            timeLeftStr = string.format("~FULL (%d%%)", maxPercent)
        else
            timeLeftStr = "~" .. timeLeftStr
            if fullDate ~= "N/A" and fullDate ~= "Ready Now" then
                fullDate = "~" .. fullDate
            end
        end
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

    local result = {
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
        isEstimate = isEstimate,
    }

    if not nowOverride then
        restedDataCache[charKey] = { time = nowTime, data = result }
    end
    return result
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

function CLIAlts:StripColors(str)
    if not str then return "" end
    str = tostring(str)
    str = str:gsub("|c%x%x%x%x%x%x%x%x", "")
    str = str:gsub("|r", "")
    str = str:gsub("|T.-|t", "")
    return str
end

local function SafeStrLenUtf8(s)
    if not s then return 0 end
    if strlenutf8 then return strlenutf8(s) end
    if utf8 and utf8.len then
        local l = utf8.len(s)
        if l then return l end
    end
    return string.len(s)
end

local function Utf8Sub(str, startChar, numChars)
    if not str then return "" end
    local curChar = 0
    local startByte = 1
    local endByte = #str
    local i = 1
    local len = #str
    while i <= len do
        curChar = curChar + 1
        if curChar == startChar then
            startByte = i
        end
        if curChar == startChar + numChars then
            endByte = i - 1
            break
        end
        local b = str:byte(i)
        if b < 128 then
            i = i + 1
        elseif b < 224 then
            i = i + 2
        elseif b < 240 then
            i = i + 3
        else
            i = i + 4
        end
    end
    return str:sub(startByte, endByte)
end

function CLIAlts:VisibleLen(str)
    if not str then return 0 end
    return SafeStrLenUtf8(self:StripColors(str))
end

function CLIAlts:Pad(text, width, align, colorHex)
    text = tostring(text or "")
    if colorHex and not text:find("|c") then
        text = string.format("|cff%s%s|r", colorHex, text)
    end

    local visLen = self:VisibleLen(text)
    if visLen >= width then
        if visLen > width then
            local clean = Utf8Sub(self:StripColors(text), 1, width)
            if colorHex then
                return string.format("|cff%s%s|r", colorHex, clean)
            else
                return clean
            end
        end
        return text
    end

    local diff = width - visLen
    align = align or "LEFT"
    if align == "RIGHT" then
        return string.rep(" ", diff) .. text
    elseif align == "CENTER" then
        local left = math.floor(diff / 2)
        local right = diff - left
        return string.rep(" ", left) .. text .. string.rep(" ", right)
    else
        return text .. string.rep(" ", diff)
    end
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

function CLIAlts:GetCharactersList(sortBy, sortAsc, filterQuery)
    local list = {}
    if not CLIAltsDB or not CLIAltsDB.characters then
        return list
    end

    local query = filterQuery
    if query then query = query:lower():match("^%s*(.-)%s*$") end
    if query == "" then query = nil end

    for key, char in pairs(CLIAltsDB.characters) do
        char.key = key
        local keep = true
        if query then
            if query == "alliance" or query == "ally" or query == "a" then
                keep = (char.faction == "Alliance")
            elseif query == "horde" or query == "h" then
                keep = (char.faction == "Horde")
            elseif query:sub(1, 1) == "<" then
                local maxLvl = tonumber(query:sub(2))
                keep = maxLvl and ((char.level or 1) < maxLvl)
            elseif query:sub(1, 1) == ">" then
                local minLvl = tonumber(query:sub(2))
                keep = minLvl and ((char.level or 1) > minLvl)
            else
                local name = (char.fullName or char.name or ""):lower()
                local cls = (char.class or ""):lower()
                local race = (char.race or ""):lower()
                local loc = (char.location or ""):lower()
                local p1 = (char.professions and char.professions.primary and char.professions.primary[1] and char.professions.primary[1].name or ""):lower()
                local p2 = (char.professions and char.professions.primary and char.professions.primary[2] and char.professions.primary[2].name or ""):lower()
                keep = name:find(query, 1, true)
                    or cls:find(query, 1, true)
                    or race:find(query, 1, true)
                    or loc:find(query, 1, true)
                    or p1:find(query, 1, true)
                    or p2:find(query, 1, true)
            end
        end
        if keep then
            table.insert(list, char)
        end
    end

    sortBy = sortBy or CLIAltsDB.settings.sortBy or "level"
    local sortValues = {}
    if sortBy == "rested" then
        for _, char in ipairs(list) do
            local r = self:GetRestedData(char)
            sortValues[char] = (r and r.percent) or 0
        end
    elseif sortBy == "xp" or sortBy == "progress" then
        for _, char in ipairs(list) do
            sortValues[char] = (char.maxXP and char.maxXP > 0) and ((char.xp or 0) / char.maxXP) or 0
        end
    elseif sortBy == "waste" then
        for _, char in ipairs(list) do
            local wastedSec, wastedXP = self:GetRestedWaste(char)
            local frac = (char.maxXP and char.maxXP > 0) and (wastedXP / char.maxXP) or 0
            sortValues[char] = (wastedSec or 0) * 1000 + frac
        end
    end

    table.sort(list, function(a, b)
        if sortBy == "name" then
            if sortAsc then return (a.name or "") < (b.name or "") else return (a.name or "") > (b.name or "") end
        elseif sortBy == "gold" then
            if sortAsc then return (a.money or 0) < (b.money or 0) else return (a.money or 0) > (b.money or 0) end
        elseif sortBy == "xp" or sortBy == "progress" or sortBy == "rested" or sortBy == "waste" then
            local valA = sortValues[a] or 0
            local valB = sortValues[b] or 0
            if valA == valB then
                return (a.level or 0) > (b.level or 0)
            end
            if sortAsc then return valA < valB else return valA > valB end
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

-- ----------------------------------------------------------------------------
-- Self-Calibrating Rested Model (Feature 1)
-- ----------------------------------------------------------------------------
function CLIAlts:ProjectRested(char, targetTimestamp, rankOverride, forceLogoutState)
    if not char then return 0 end
    local maxXP = char.maxXP or 0
    if maxXP <= 0 then return char.restedXP or 0 end

    local rank = rankOverride or (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
    if rank < 0 then rank = 0 end
    if rank > 5 then rank = 5 end

    local speedMult = 1 + (rank * 0.04)
    local capMult = 1.5 * speedMult
    local maxRested = maxXP * capMult

    local isResting
    if forceLogoutState or (char.loggedOutInRestZone ~= nil) then
        isResting = (char.loggedOutInRestZone == true)
    else
        isResting = self:IsCharacterResting(char)
    end
    local baseRate = isResting and (maxXP / 576000) or (maxXP / 2304000)
    local ratePerSec = baseRate * speedMult

    local lastUpdate = char.lastUpdate or (char.logoutTime or targetTimestamp)
    local elapsed = math.max(0, targetTimestamp - lastUpdate)

    local projected = (char.restedXP or 0) + (elapsed * ratePerSec)
    return math.min(maxRested, projected)
end

-- ----------------------------------------------------------------------------
-- Self-Calibrating Rested Model (Feature 1)
-- ----------------------------------------------------------------------------
function CLIAlts:EvaluateCalibration(old, actualRested, curLevel, nowTimestamp, curRank, pendingRank)
    if not old or not old.cleanLogout or not old.lastUpdate then
        return nil, 0, "NO_DATA"
    end
    curLevel = curLevel or old.level or 1
    if old.level and curLevel ~= old.level then
        return nil, 0, "LEVEL_CHANGED"
    end

    local maxXP = old.maxXP or 0
    if maxXP <= 0 then
        return nil, 0, "INVALID_MAX_XP"
    end

    curRank = curRank or 0
    local speedMult = 1 + (curRank * 0.04)
    local maxRested = maxXP * 1.5 * speedMult

    actualRested = actualRested or 0
    -- Skip sample if old or actual rested XP is at or near cap (truncated offline delta)
    if (old.restedXP or 0) >= maxRested * 0.98 or actualRested >= maxRested * 0.98 then
        return nil, 0, "NEAR_CAP"
    end

    nowTimestamp = nowTimestamp or time()
    local elapsed = nowTimestamp - old.lastUpdate
    -- Require at least 10 minutes (600s) of offline time for a meaningful calibration sample
    if elapsed < 600 then
        return nil, 0, "SHORT_DURATION"
    end

    local predicted = self:ProjectRested(old, nowTimestamp, curRank, true)
    local drift = (actualRested - predicted) / maxXP

    -- Only calibrate if drift exceeds 2% of level max XP
    if math.abs(drift) <= 0.02 then
        return curRank, drift, "MATCH"
    end

    local observedDelta = actualRested - (old.restedXP or 0)
    if observedDelta <= 0 or elapsed <= 0 then
        return nil, drift, "INVALID_DELTA"
    end

    local observedRate = observedDelta / elapsed
    local baseInnRate = maxXP / 576000
    local baseWildRate = maxXP / 2304000
    local isInn = (old.loggedOutInRestZone == true)
    local baseRate = isInn and baseInnRate or baseWildRate

    local inferredSpeedMult = observedRate / baseRate
    local inferredRank = math.floor(((inferredSpeedMult - 1.0) / 0.04) + 0.5)
    if inferredRank < 0 then inferredRank = 0 end
    if inferredRank > 5 then inferredRank = 5 end

    if inferredRank == curRank then
        return curRank, drift, "MATCH"
    end

    local confirmed = (pendingRank == inferredRank)
    return inferredRank, drift, confirmed and "CONFIRMED" or "PENDING"
end

function CLIAlts:CalibrateRestedModel()
    if not GetXPExhaustion or not UnitXPMax then return end
    local curFull = self.curPlayerFullName or (select(3, self:GetPlayerNames()))
    if not curFull or not CLIAltsDB or not CLIAltsDB.characters then return end

    local charKey = self:GetCharacterKey(curFull)
    local old = CLIAltsDB.characters[charKey]
    if not old then return end

    local curLevel = (UnitLevel and UnitLevel("player")) or 1
    local actualRested = GetXPExhaustion() or 0
    local curRank = (CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
    local pendingRank = CLIAltsDB.settings and CLIAltsDB.settings.pendingCalibratedRank

    local inferredRank, drift, status = self:EvaluateCalibration(old, actualRested, curLevel, time(), curRank, pendingRank)
    if status == "MATCH" then
        if CLIAltsDB.settings then
            CLIAltsDB.settings.pendingCalibratedRank = nil
        end
    elseif status == "PENDING" then
        if CLIAltsDB.settings then
            CLIAltsDB.settings.pendingCalibratedRank = inferredRank
        end
    elseif status == "CONFIRMED" then
        if CLIAltsDB.settings then
            CLIAltsDB.settings.wellRestedRank = inferredRank
            CLIAltsDB.settings.calibrated = true
            CLIAltsDB.settings.pendingCalibratedRank = nil
        end
        self:InvalidateRestedCache()
        self:Print(string.format("Rested model self-calibrated (confirmed): Well Rested Rank %d (+%d%% speed, drift was %+.1f%%).",
            inferredRank, inferredRank * 4, drift * 100))
    end
end

-- ----------------------------------------------------------------------------
-- Self-Test Verification Suite (/clialts selftest)
-- ----------------------------------------------------------------------------
function CLIAlts:RunSelfTest()
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

    if failed == 0 then
        self:Print(string.format("|cff00ff66Self-test passed: all %d assertions OK.|r (ProjectRested, GetRestedWaste, Calibration)", passed))
    else
        self:Print(string.format("|cffff3333Self-test FAILED: %d passed, %d failed!|r", passed, failed))
        for _, err in ipairs(errors) do
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cffff3333* FAILED:|r %s", err))
        end
    end

    return failed == 0, passed, failed
end

-- ----------------------------------------------------------------------------
-- Rested Waste Tracker & Next Alt Priority (Feature 2)
-- ----------------------------------------------------------------------------
function CLIAlts:GetRestedWaste(char, nowOverride)
    if not char then return 0, 0, "No waste", "0m" end
    local maxLevel = self:GetMaxLevel()
    local level = char.level or 1
    if level >= maxLevel then
        return 0, 0, "MAX LEVEL", "MAX"
    end

    local rested = self:GetRestedData(char, nowOverride ~= nil, nowOverride)
    if not rested or not rested.isFull then
        return 0, 0, "Accruing", "0m"
    end

    local maxXP = char.maxXP or 0
    local ratePerSec = rested.ratePerSec or (maxXP / 576000)
    if ratePerSec <= 0 then ratePerSec = 1 end

    local now = nowOverride or time()
    local lastUpdate = char.lastUpdate or now
    local elapsed = math.max(0, now - lastUpdate)

    local baseRested = char.restedXP or 0
    local maxRested = rested.maxRested or 0
    local neededToCap = math.max(0, maxRested - baseRested)
    local secondsToCap = (ratePerSec > 0) and (neededToCap / ratePerSec) or 0

    local wastedSeconds = 0
    if elapsed >= secondsToCap then
        wastedSeconds = elapsed - secondsToCap
    end

    local wastedXP = math.floor(wastedSeconds * ratePerSec)

    local days = math.floor(wastedSeconds / 86400)
    local hours = math.floor((wastedSeconds % 86400) / 3600)
    local mins = math.floor((wastedSeconds % 3600) / 60)

    local timeStr
    if days > 0 then
        timeStr = string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        timeStr = string.format("%dh %dm", hours, mins)
    elseif mins > 0 then
        timeStr = string.format("%dm", mins)
    else
        timeStr = "Just capped"
    end

    local formattedWaste = string.format("Capped %s (~%s XP lost)", timeStr, self:FormatNumber(wastedXP))
    return wastedSeconds, wastedXP, formattedWaste, timeStr
end

function CLIAlts:GetNextAltsPriority()
    local chars = self:GetCharactersList()
    local scored = {}
    local maxLevel = self:GetMaxLevel()

    for _, char in ipairs(chars) do
        local level = char.level or 1
        if level < maxLevel then
            local wastedSec, wastedXP, formattedWaste, timeStr = self:GetRestedWaste(char)
            local rested = self:GetRestedData(char)
            local isCapped = rested and rested.isFull

            local score = 0
            local reason = ""
            if isCapped then
                score = 100000000 + (wastedSec or 0)
                reason = string.format("Capped for %s (%s XP wasted)", timeStr, self:FormatNumber(wastedXP))
            else
                local timeToFull = (rested and rested.timeToFull) or 9999999
                score = math.max(1, 10000000 - timeToFull)
                reason = string.format("%d%% rested (Caps in %s)", rested and rested.percent or 0, rested and rested.timeLeftStr or "---")
            end

            table.insert(scored, {
                char = char,
                score = score,
                isCapped = isCapped,
                wastedXP = wastedXP,
                timeStr = timeStr,
                reason = reason,
            })
        end
    end

    table.sort(scored, function(a, b)
        return a.score > b.score
    end)

    return scored
end

function CLIAlts:PrintNextAlts()
    local list = self:GetNextAltsPriority()
    if #list == 0 then
        self:Print("No leveling alts found or all alts are at maximum level.")
        return
    end

    self:Print("--- Recommended Next Alts to Play ---")
    local count = math.min(3, #list)
    for i = 1, count do
        local item = list[i]
        local c = item.char
        local coloredName = self:ColorizePlayerName(c.name, c.classFile)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cff00ff66%d.|r %s (Lvl %d %s) :: |cffffd700%s|r",
            i, coloredName, c.level or 1, self:FormatRaceClass(c), item.reason))
    end
end

function CLIAlts:CheckCappedAltsAlert()
    local list = self:GetNextAltsPriority()
    local capped = {}
    for _, item in ipairs(list) do
        if item.isCapped and item.wastedXP and item.wastedXP > 1000 then
            table.insert(capped, item)
        end
    end
    if #capped > 0 then
        local parts = {}
        for i = 1, math.min(2, #capped) do
            local c = capped[i].char
            local coloredName = self:ColorizePlayerName(c.name, c.classFile)
            table.insert(parts, string.format("%s (~%s XP lost)", coloredName, self:FormatNumber(capped[i].wastedXP)))
        end
        self:Print(string.format("|cffffaa00Notice:|r %d alts capped (%s). Type |cff00ff66/ca next|r for priority.",
            #capped, table.concat(parts, ", ")))
    end
end

-- ----------------------------------------------------------------------------
-- Watchlist System (Feature 5)
-- ----------------------------------------------------------------------------
function CLIAlts:AddWatchItem(itemName)
    if not itemName or itemName == "" then return false end
    CLIAltsDB.watchlist = CLIAltsDB.watchlist or {}
    for _, existing in ipairs(CLIAltsDB.watchlist) do
        if existing:lower() == itemName:lower() then
            return false
        end
    end
    table.insert(CLIAltsDB.watchlist, itemName)
    self:UpdateWatchCounts()
    return true
end

function CLIAlts:RemoveWatchItem(itemName)
    if not itemName or not CLIAltsDB or not CLIAltsDB.watchlist then return false end
    local found = false
    local newWatch = {}
    for _, existing in ipairs(CLIAltsDB.watchlist) do
        if existing:lower() == itemName:lower() then
            found = true
        else
            table.insert(newWatch, existing)
        end
    end
    CLIAltsDB.watchlist = newWatch
    if found then
        self:UpdateWatchCounts()
    end
    return found
end

function CLIAlts:GetWatchlistSummary()
    local watchlist = (CLIAltsDB and CLIAltsDB.watchlist) or {}
    local summary = {}
    local chars = self:GetCharactersList("name", true)

    for _, item in ipairs(watchlist) do
        local total = 0
        local breakdown = {}
        for _, c in ipairs(chars) do
            local cnt = (c.watchlistCounts and c.watchlistCounts[item]) or 0
            if cnt > 0 then
                total = total + cnt
                table.insert(breakdown, { name = c.name, count = cnt, classFile = c.classFile })
            end
        end
        table.insert(summary, {
            item = item,
            total = total,
            breakdown = breakdown,
        })
    end
    return summary
end

function CLIAlts:PrintWatchlist()
    local summary = self:GetWatchlistSummary()
    if #summary == 0 then
        self:Print("Watchlist is empty. Use |cff00ff66/ca watch <Item Name>|r to track specific items across alts.")
        return
    end
    self:Print("--- CLIAlts Watchlist Summary ---")
    for _, entry in ipairs(summary) do
        local parts = {}
        for _, b in ipairs(entry.breakdown) do
            table.insert(parts, string.format("%s: %s", b.name, self:FormatNumber(b.count)))
        end
        local detail = #parts > 0 and (" (" .. table.concat(parts, ", ") .. ")") or ""
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  * |cffffd700%s|r :: |cff00ff66%s total|r%s",
            entry.item, self:FormatNumber(entry.total), detail))
    end
end

-- ----------------------------------------------------------------------------
-- Gold History & ASCII Sparkline (Feature 6)
-- ----------------------------------------------------------------------------
function CLIAlts:RecordGoldSnapshot()
    if not CLIAltsDB then return end
    CLIAltsDB.goldHistory = CLIAltsDB.goldHistory or {}

    local summary = self:GetAccountSummary()
    local totalGold = math.floor((summary.totalGold or 0) / 10000)
    local today = date("%Y-%m-%d")
    local now = time()

    local last = CLIAltsDB.goldHistory[#CLIAltsDB.goldHistory]
    if last and last.date == today then
        last.gold = totalGold
        last.time = now
    else
        table.insert(CLIAltsDB.goldHistory, {
            date = today,
            time = now,
            gold = totalGold,
        })
        while #CLIAltsDB.goldHistory > 90 do
            table.remove(CLIAltsDB.goldHistory, 1)
        end
    end
end

function CLIAlts:GetGoldHistoryDeltas()
    local summary = self:GetAccountSummary()
    local curGold = math.floor((summary.totalGold or 0) / 10000)
    local hist = (CLIAltsDB and CLIAltsDB.goldHistory) or {}
    local now = time()

    local g1d, g7d, g30d = curGold, curGold, curGold
    for i = #hist, 1, -1 do
        local entry = hist[i]
        local ageDays = (now - entry.time) / 86400
        if ageDays >= 1 and g1d == curGold then
            g1d = entry.gold
        end
        if ageDays >= 7 and g7d == curGold then
            g7d = entry.gold
        end
        if ageDays >= 30 and g30d == curGold then
            g30d = entry.gold
            break
        end
    end

    return (curGold - g1d), (curGold - g7d), (curGold - g30d)
end

function CLIAlts:GenerateAsciiSparkline(numChars)
    numChars = numChars or 14
    local hist = (CLIAltsDB and CLIAltsDB.goldHistory) or {}
    local ramp = { "_", ".", "-", "=", "*", "#" }

    if #hist == 0 then
        return string.rep("-", numChars)
    end

    local points = {}
    local startIdx = math.max(1, #hist - numChars + 1)
    for i = startIdx, #hist do
        table.insert(points, hist[i].gold)
    end

    while #points < numChars do
        table.insert(points, 1, points[1] or 0)
    end

    local minG = points[1]
    local maxG = points[1]
    for _, g in ipairs(points) do
        if g < minG then minG = g end
        if g > maxG then maxG = g end
    end

    local range = maxG - minG
    local chars = {}
    for _, g in ipairs(points) do
        local rIdx = 3
        if range > 0 then
            local ratio = (g - minG) / range
            rIdx = math.min(6, math.max(1, math.floor(ratio * 5.99) + 1))
        end
        table.insert(chars, ramp[rIdx])
    end

    return table.concat(chars, "")
end

-- ----------------------------------------------------------------------------
-- Mail Expiry Alert (Feature 7)
-- ----------------------------------------------------------------------------
function CLIAlts:CheckMailExpiryAlert()
    if not CLIAltsDB or not CLIAltsDB.characters then return end
    local now = time()
    local expiring = {}

    for _, c in ipairs(self:GetCharactersList()) do
        if c.minMailDays and c.mailCheckedTime and (c.mailCount or 0) > 0 then
            local elapsedDays = (now - c.mailCheckedTime) / 86400
            local daysRemaining = c.minMailDays - elapsedDays
            if daysRemaining <= 3.0 then
                table.insert(expiring, {
                    name = c.name,
                    classFile = c.classFile,
                    days = math.max(0, daysRemaining),
                    count = c.mailCount,
                })
            end
        end
    end

    if #expiring > 0 then
        for _, entry in ipairs(expiring) do
            local coloredName = self:ColorizePlayerName(entry.name, entry.classFile)
            local daysText = (entry.days < 1.0) and string.format("%.0fh", entry.days * 24) or string.format("%.1fd", entry.days)
            self:Print(string.format("|cffff4444[MAIL WARNING]|r %s has %d mail(s) expiring in |cffffffff%s|r! Log in to retrieve.",
                coloredName, entry.count, daysText))
        end
    end
end

-- ----------------------------------------------------------------------------
-- CSV Data Export (Feature 8)
-- ----------------------------------------------------------------------------
local function CsvQuote(val)
    local s = tostring(val or "")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    return '"' .. s:gsub('"', '""') .. '"'
end

function CLIAlts:GenerateExportCSV()
    local lines = {}
    table.insert(lines, "Name,Realm,Faction,Race,Class,Level,XP,MaxXP,RestedXP,RestedPct,RestedStatus,WastedXP,Gold,Silver,Copper,Prof1,Prof1Rank,Prof2,Prof2Rank,Location,LastSeen")

    local chars = self:GetCharactersList("name", true)
    for _, c in ipairs(chars) do
        local rested = self:GetRestedData(c)
        local wastedSec, wastedXP = self:GetRestedWaste(c)
        local money = c.money or 0
        local gold = math.floor(money / 10000)
        local silver = math.floor((money % 10000) / 100)
        local copper = money % 100

        local profs = c.professions and c.professions.primary or {}
        local p1Name = (profs[1] and profs[1].name) or ""
        local p1Rank = (profs[1] and profs[1].rank) or 0
        local p2Name = (profs[2] and profs[2].name) or ""
        local p2Rank = (profs[2] and profs[2].rank) or 0

        local lastSeenStr = ""
        if c.lastUpdate and c.lastUpdate > 0 then
            lastSeenStr = date("%Y-%m-%d %H:%M:%S", c.lastUpdate)
        end

        local row = table.concat({
            CsvQuote(c.fullName or c.name or "Unknown"),
            CsvQuote(c.realm or "Forever"),
            CsvQuote(c.faction or "Neutral"),
            CsvQuote(c.race or "Unknown"),
            CsvQuote(c.class or "Unknown"),
            tostring(c.level or 1),
            tostring(c.xp or 0),
            tostring(c.maxXP or 0),
            tostring(c.restedXP or 0),
            tostring((rested and rested.percent) or 0),
            CsvQuote((rested and rested.statusStr) or "Unknown"),
            tostring(wastedXP or 0),
            tostring(gold),
            tostring(silver),
            tostring(copper),
            CsvQuote(p1Name),
            tostring(p1Rank),
            CsvQuote(p2Name),
            tostring(p2Rank),
            CsvQuote(c.location or "Unknown"),
            CsvQuote(lastSeenStr),
        }, ",")
        table.insert(lines, row)
    end

    return table.concat(lines, "\n")
end
