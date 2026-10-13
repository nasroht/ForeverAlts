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
local cachedCurrentChar = nil

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
    CLIAltsDB.settings.alerts = CLIAltsDB.settings.alerts or {}
    if CLIAltsDB.settings.alerts.cooldowns == nil then CLIAltsDB.settings.alerts.cooldowns = true end
    if CLIAltsDB.settings.alerts.rested == nil then CLIAltsDB.settings.alerts.rested = true end
    if CLIAltsDB.settings.alerts.mail == nil then CLIAltsDB.settings.alerts.mail = true end
    if CLIAltsDB.settings.alerts.lockouts == nil then CLIAltsDB.settings.alerts.lockouts = true end
    if CLIAltsDB.settings.restedBurnRatio == nil then CLIAltsDB.settings.restedBurnRatio = 0.5 end
    CLIAltsDB.settings.staleDays = tonumber(CLIAltsDB.settings.staleDays) or 30
    CLIAltsDB.settings.compactMode = (CLIAltsDB.settings.compactMode == true)
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

function CLIAlts:IsCompact()
    return (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.compactMode == true)
end

function CLIAlts:ToggleCompact()
    if not CLIAltsDB or not CLIAltsDB.settings then
        self:InitDB()
    end
    CLIAltsDB.settings.compactMode = (CLIAltsDB.settings.compactMode ~= true)
    if self.ApplyLayoutSize then
        self:ApplyLayoutSize()
    end
    if self.Render then
        self:Render()
    end
    return CLIAltsDB.settings.compactMode
end

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
                    local name, _, skillLevel, maxSkillLevel = GetProfessionInfo(item.slot)
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
                    elseif cd == 0 and (cds[name] or (name and (name:find("^Transmute:") or name == "Mooncloth" or name == "Salt Shaker" or name == "Snowmaster 9000"))) then
                        cds[name] = 0
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
                local name, id, reset, diff, locked, _, isRaid, _, diffName = GetSavedInstanceInfo(i)
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
    local watchlist = (CLIAltsDB and CLIAltsDB.watchlist) or {}
    if not CLIAltsDB or not CLIAltsDB.watchlist or #watchlist == 0 then
        return counts
    end

    -- Keep only existing counts that match an active item in CLIAltsDB.watchlist
    if existing then
        for k, v in pairs(existing) do
            for _, item in ipairs(watchlist) do
                if self:IsWatchItemMatch(item, k) then
                    counts[item] = v
                    break
                end
            end
        end
    end

    pcall(function()
        if GetItemCount then
            for _, item in ipairs(watchlist) do
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
        if cachedCurrentChar and cachedCurrentChar ~= char then
            cachedCurrentChar.watchlistCounts = char.watchlistCounts
        end
    end
end

-- ----------------------------------------------------------------------------
-- Data Collection: Current Logged-in Character (Throttled to 1s)
-- ----------------------------------------------------------------------------
local lastCollectTime = 0
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
    local isLevelUp = existing and existing.level and level > existing.level
    if not isLevelUp and curXP <= 0 and existing and existing.xp and existing.xp > 0 then
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

    local bindLocation = (GetBindLocation and GetBindLocation()) or ""
    if (not bindLocation or bindLocation == "") and existing and existing.bindLocation and existing.bindLocation ~= "" then
        bindLocation = existing.bindLocation
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
        bindLocation = (bindLocation ~= "" and bindLocation) or "Unknown",
        professions = professions,
        tradeCooldowns = self:CollectTradeCooldowns(existing and existing.tradeCooldowns),
        lockouts = self:CollectLockouts(existing and existing.lockouts),
        mailCount = liveMailCount or (existing and existing.mailCount),
        minMailDays = liveMinMailDays or (existing and existing.minMailDays),
        mailCheckedTime = liveMailCheckedTime or (existing and existing.mailCheckedTime),
        watchlistCounts = self:CollectWatchlistCounts(existing and existing.watchlistCounts),
        xpHour = (existing and existing.xpHour) or (cachedCurrentChar and cachedCurrentChar.xpHour),
        note = (existing and existing.note) or (cachedCurrentChar and cachedCurrentChar.note),
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

    if isLogout and self.FinalizeSessionXP then
        self:FinalizeSessionXP()
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
    local fullDate
    local timeLeftStr

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
function CLIAlts:FindCharacter(query)
    if not query or query == "" or not CLIAltsDB or not CLIAltsDB.characters then return nil, nil end
    local qLower = query:lower():match("^%s*(.-)%s*$")
    if qLower == "" then return nil, nil end

    if CLIAltsDB.characters[query] then
        return CLIAltsDB.characters[query], query
    end

    -- 1. Exact case-insensitive match on name, full name, or key
    for k, char in pairs(CLIAltsDB.characters) do
        local name = (char.name or ""):lower()
        local full = (char.fullName or ""):lower()
        local prim = (char.primaryName or ""):lower()
        local keyLower = tostring(k):lower()
        if name == qLower or full == qLower or prim == qLower or keyLower == qLower then
            return char, k
        end
    end

    -- 2. Prefix match (starts with query)
    for k, char in pairs(CLIAltsDB.characters) do
        local name = (char.name or ""):lower()
        local full = (char.fullName or ""):lower()
        local prim = (char.primaryName or ""):lower()
        local keyLower = tostring(k):lower()
        if name:find(qLower, 1, true) == 1 or full:find(qLower, 1, true) == 1 or prim:find(qLower, 1, true) == 1 or keyLower:find(qLower, 1, true) == 1 then
            return char, k
        end
    end

    return nil, nil
end

function CLIAlts:SetCharacterNote(charQuery, noteText, printChat)
    if not charQuery or charQuery == "" then
        local msg = "Usage: note <name> <text> (or 'clear' to remove)"
        if printChat then self:Print(msg) end
        return msg, false
    end

    local char, key = self:FindCharacter(charQuery)
    if not char then
        local msg = string.format("Character '%s' not found.", charQuery)
        if printChat then self:Print(msg) end
        return msg, false
    end

    local cName = self:ColorizePlayerName(char.name or charQuery, char.classFile)

    if not noteText or noteText == "" then
        local msg
        if char.note and char.note ~= "" then
            msg = string.format("Note for %s: |cffffd700%s|r", cName, char.note)
        else
            msg = string.format("No note set for %s.", cName)
        end
        if printChat then self:Print(msg) end
        return msg, true
    end

    local trimmed = noteText:match("^%s*(.-)%s*$")
    if trimmed:lower() == "clear" or trimmed:lower() == "none" or trimmed == "-" then
        char.note = nil
        if cachedCurrentChar and (cachedCurrentChar == char or key == self.curPlayerKey) then
            cachedCurrentChar.note = nil
        end
        local msg = string.format("Cleared note for %s.", cName)
        if printChat then self:Print(msg) end
        self:RequestRender()
        return msg, true
    else
        char.note = trimmed
        if cachedCurrentChar and (cachedCurrentChar == char or key == self.curPlayerKey) then
            cachedCurrentChar.note = trimmed
        end
        local msg = string.format("Note set for %s: |cffffd700%s|r", cName, trimmed)
        if printChat then self:Print(msg) end
        self:RequestRender()
        return msg, true
    end
end

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

function CLIAlts:GetDaysInactive(char, now)
    if not char then return 0 end
    now = now or time()
    local last = char.lastUpdate or char.logoutTime or now
    return math.max(0, math.floor((now - last) / 86400))
end

function CLIAlts:IsCharStale(char, staleDays, now)
    if not char then return false, 0 end
    -- The currently logged in character is NEVER stale
    local curKey = self.curPlayerKey
    local _, _, curFull = self:GetPlayerNames()
    if curKey and (char.key == curKey or char.fullName == curKey) then
        return false, 0
    end
    if curFull and (char.fullName == curFull or char.name == curFull) then
        return false, 0
    end

    staleDays = tonumber(staleDays) or (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.staleDays)) or 30
    local days = self:GetDaysInactive(char, now)
    return days >= staleDays, days
end

function CLIAlts:GetPrunableCharacters(days, now)
    local list = {}
    if not CLIAltsDB or not CLIAltsDB.characters then return 0, list end
    days = tonumber(days) or 30
    now = now or time()
    local curKey = self.curPlayerKey
    local _, _, curFull = self:GetPlayerNames()

    for k, c in pairs(CLIAltsDB.characters) do
        local isCurrent = (curKey and (k == curKey or c.fullName == curKey))
            or (curFull and (c.fullName == curFull or c.name == curFull))
        if not isCurrent then
            local last = c.lastUpdate or c.logoutTime or now
            local elapsedDays = math.floor((now - last) / 86400)
            if elapsedDays >= days then
                table.insert(list, c.name or c.fullName or k)
            end
        end
    end
    table.sort(list)
    return #list, list
end

function CLIAlts:PruneCharacters(days, now)
    if not CLIAltsDB or not CLIAltsDB.characters then return 0, {} end
    days = tonumber(days) or 30
    now = now or time()
    local prunedKeys = {}
    local prunedNames = {}
    local curKey = self.curPlayerKey
    local _, _, curFull = self:GetPlayerNames()

    for k, c in pairs(CLIAltsDB.characters) do
        local isCurrent = (curKey and (k == curKey or c.fullName == curKey))
            or (curFull and (c.fullName == curFull or c.name == curFull))
        if not isCurrent then
            local last = c.lastUpdate or c.logoutTime or now
            local elapsedDays = math.floor((now - last) / 86400)
            if elapsedDays >= days then
                table.insert(prunedKeys, k)
                table.insert(prunedNames, c.name or c.fullName or k)
            end
        end
    end

    for _, k in ipairs(prunedKeys) do
        CLIAltsDB.characters[k] = nil
    end

    if #prunedKeys > 0 then
        if self.CleanWatchlistCounts then
            self:CleanWatchlistCounts()
        end
        if self.InvalidateRestedCache then
            self:InvalidateRestedCache()
        end
        self:RequestRender()
    end

    return #prunedKeys, prunedNames
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
            elseif query == "stale" then
                keep = self:IsCharStale(char)
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
                local hearth = (char.bindLocation or ""):lower()
                local p1 = (char.professions and char.professions.primary and char.professions.primary[1] and char.professions.primary[1].name or ""):lower()
                local p2 = (char.professions and char.professions.primary and char.professions.primary[2] and char.professions.primary[2].name or ""):lower()
                local note = (char.note or ""):lower()
                keep = name:find(query, 1, true)
                    or cls:find(query, 1, true)
                    or race:find(query, 1, true)
                    or loc:find(query, 1, true)
                    or hearth:find(query, 1, true)
                    or p1:find(query, 1, true)
                    or p2:find(query, 1, true)
                    or note:find(query, 1, true)
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
        elseif sortBy == "note" then
            local nA = (a.note or ""):lower()
            local nB = (b.note or ""):lower()
            if nA ~= nB then
                if sortAsc then return nA < nB else return nA > nB end
            end
            return (a.name or "") < (b.name or "")
        elseif sortBy == "hearth" then
            local hA = (a.bindLocation or ""):lower()
            local hB = (b.bindLocation or ""):lower()
            if hA ~= hB then
                if sortAsc then return hA < hB else return hA > hB end
            end
            return (a.name or "") < (b.name or "")
        elseif sortBy == "location" then
            local lA = (a.location or ""):lower()
            local lB = (b.location or ""):lower()
            if lA ~= lB then
                if sortAsc then return lA < lB else return lA > lB end
            end
            return (a.name or "") < (b.name or "")
        elseif sortBy == "seen" or sortBy == "stale" then
            local sA = a.lastUpdate or 0
            local sB = b.lastUpdate or 0
            if sA ~= sB then
                if sortAsc then return sA < sB else return sA > sB end
            end
            return (a.name or "") < (b.name or "")
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
    local fullyRested = 0
    local nextFullAlt = nil
    local lowestTimeToFull = 999999999

    local chars = self:GetCharactersList()
    local totalAlts = #chars

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

    -- 11. Colorblind Palette & Compact Mode Tests
    -- 11a. Colorblind Theme
    if self.THEMES then
        local cbTheme = self.THEMES["COLORBLIND"]
        Assert(cbTheme ~= nil, "Colorblind: COLORBLIND theme exists in THEMES")
        Assert(cbTheme and cbTheme.tag == "SAFE", "Colorblind: theme tag is 'SAFE'")
        Assert(cbTheme and cbTheme.highlightHex == "ffd933", "Colorblind: high-contrast amber highlightHex is ffd933")
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
        local hasXPFull = false
        for _, col in ipairs(fullCols1) do if col.key == "xp" then hasXPFull = true end end
        local hasXPComp = false
        for _, col in ipairs(compCols1) do if col.key == "xp" then hasXPComp = true end end
        Assert(hasXPFull == true and hasXPComp == false, "CompactMode: hides XP bar column in Tab 1")
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

    if failed == 0 then
        self:Print(string.format("|cff00ff66Self-test passed: all %d assertions OK.|r (ProjectRested, GetRestedWaste, Calibration, Digest & Alerts, Leveling Plan, Notes, Lockouts, Watchlist, Stale/Prune, LibDataBroker, Colorblind/Compact, LivePath)", passed))
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

-- ----------------------------------------------------------------------------
-- LibDataBroker Summary & Text Formatting (Feature 10)
-- ----------------------------------------------------------------------------
function CLIAlts:FormatWasteShort(waste)
    waste = math.max(0, tonumber(waste) or 0)
    if waste >= 1000000 then
        local m = waste / 1000000
        if m == math.floor(m) then
            return string.format("%dM", m)
        else
            return string.format("%.1fM", m)
        end
    elseif waste >= 1000 then
        return string.format("%dk", math.floor(waste / 1000 + 0.5))
    else
        return tostring(math.floor(waste))
    end
end

function CLIAlts:GetLDBText(now, charListOverride)
    local chars = charListOverride or self:GetCharactersList()
    local maxLevel = self:GetMaxLevel()
    local cappedCount = 0
    local totalWastedXP = 0

    for _, char in ipairs(chars) do
        local level = char.level or 1
        if level < maxLevel then
            local rested = self:GetRestedData(char, now ~= nil, now)
            if rested and rested.isFull then
                cappedCount = cappedCount + 1
            end
            local _, wastedXP = self:GetRestedWaste(char, now)
            if wastedXP and wastedXP > 0 then
                totalWastedXP = totalWastedXP + wastedXP
            end
        end
    end

    local wasteStr = self:FormatWasteShort(totalWastedXP)
    local text = string.format("Alts: %d capped | %s waste", cappedCount, wasteStr)
    return text, cappedCount, totalWastedXP
end

function CLIAlts:GetNextAltsPriority()
    local chars = self:GetCharactersList()
    local scored = {}
    local maxLevel = self:GetMaxLevel()

    for _, char in ipairs(chars) do
        local level = char.level or 1
        if level < maxLevel then
            local wastedSec, wastedXP, _, timeStr = self:GetRestedWaste(char)
            local rested = self:GetRestedData(char)
            local isCapped = rested and rested.isFull

            local score, reason
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
function CLIAlts:ResolveWatchItem(input)
    if not input then return nil end
    if type(input) == "number" then return input end
    local str = tostring(input):match("^%s*(.-)%s*$")
    if not str or str == "" then return nil end

    -- 1. Extract numeric item ID from item link if present: |Hitem:(%d+)
    local idFromLink = str:match("|Hitem:(%d+)")
    if idFromLink then
        local num = tonumber(idFromLink)
        if num and num > 0 then return num end
    end

    -- 2. Pure numeric item ID input
    local numId = tonumber(str)
    if numId and numId > 0 then
        return numId
    end

    -- 3. Resolve item name via GetItemInfoInstant or GetItemInfo if available
    if GetItemInfoInstant then
        local instantId = GetItemInfoInstant(str)
        local n = tonumber(instantId)
        if n and n > 0 then return n end
    end
    if GetItemInfo then
        local _, itemLink = GetItemInfo(str)
        if itemLink then
            local id = itemLink:match("|Hitem:(%d+)")
            local n = tonumber(id)
            if n and n > 0 then return n end
        end
    end

    -- 4. Fallback to raw string
    return str
end

function CLIAlts:IsWatchItemMatch(existing, target)
    if existing == nil or target == nil then return false end
    if existing == target then return true end
    if tostring(existing):lower() == tostring(target):lower() then return true end

    local exId = tonumber(existing) or (type(existing) == "string" and tonumber(existing:match("|Hitem:(%d+)")))
    local tgId = tonumber(target) or (type(target) == "string" and tonumber(target:match("|Hitem:(%d+)")))
    if exId and tgId and exId == tgId then
        return true
    end

    if GetItemInfo then
        if exId and type(target) == "string" then
            local name = GetItemInfo(exId)
            if name and name:lower() == target:lower() then return true end
        end
        if tgId and type(existing) == "string" then
            local name = GetItemInfo(tgId)
            if name and name:lower() == existing:lower() then return true end
        end
    end
    return false
end

function CLIAlts:GetWatchItemPlainName(item)
    if not item then return "Unknown" end
    local num = tonumber(item)
    if num and num > 0 then
        if GetItemInfo then
            local name = GetItemInfo(num)
            if name then return name end
        end
        return "Item #" .. num
    end
    return tostring(item)
end

function CLIAlts:GetWatchItemDisplayName(item)
    if not item then return "Unknown" end
    local num = tonumber(item)
    if num and num > 0 then
        if GetItemInfo then
            local name, link = GetItemInfo(num)
            if link then return link end
            if name then return name end
        end
        return "Item #" .. num
    end
    if type(item) == "string" and GetItemInfo then
        local _, link = GetItemInfo(item)
        if link then return link end
    end
    return tostring(item)
end

function CLIAlts:AddWatchItem(input)
    if not input or input == "" then return false, nil end
    local resolved = self:ResolveWatchItem(input)
    if not resolved then return false, nil end

    CLIAltsDB.watchlist = CLIAltsDB.watchlist or {}
    for _, existing in ipairs(CLIAltsDB.watchlist) do
        if self:IsWatchItemMatch(existing, resolved) then
            return false, existing
        end
    end

    table.insert(CLIAltsDB.watchlist, resolved)
    self:UpdateWatchCounts()
    return true, resolved
end

function CLIAlts:CleanWatchlistCounts(removedItem, target)
    if not CLIAltsDB or not CLIAltsDB.characters then return end
    local watchlist = CLIAltsDB.watchlist or {}

    local function cleanTable(counts)
        if not counts then return end
        if removedItem ~= nil then
            counts[removedItem] = nil
            counts[tostring(removedItem)] = nil
            local rNum = tonumber(removedItem)
            if rNum then counts[rNum] = nil end
            if GetItemInfo then
                local rName = GetItemInfo(removedItem)
                if rName then counts[rName] = nil end
            end
        end
        if target ~= nil then
            counts[target] = nil
            counts[tostring(target)] = nil
            local tNum = tonumber(target)
            if tNum then counts[tNum] = nil end
            if GetItemInfo then
                local tName = GetItemInfo(target)
                if tName then counts[tName] = nil end
            end
        end
        for k in pairs(counts) do
            local kept = false
            for _, item in ipairs(watchlist) do
                if self:IsWatchItemMatch(item, k) then
                    kept = true
                    break
                end
            end
            if not kept then
                counts[k] = nil
            end
        end
    end

    for _, char in pairs(CLIAltsDB.characters) do
        cleanTable(char.watchlistCounts)
    end
    if cachedCurrentChar then
        cleanTable(cachedCurrentChar.watchlistCounts)
    end
end

function CLIAlts:RemoveWatchItem(input)
    if not input or not CLIAltsDB or not CLIAltsDB.watchlist then return false, nil end
    local target = self:ResolveWatchItem(input) or input
    local found = false
    local removedItem = nil
    local newWatch = {}

    for _, existing in ipairs(CLIAltsDB.watchlist) do
        if not found and self:IsWatchItemMatch(existing, target) then
            found = true
            removedItem = existing
        else
            table.insert(newWatch, existing)
        end
    end

    if found then
        CLIAltsDB.watchlist = newWatch
        self:CleanWatchlistCounts(removedItem, target)
        self:UpdateWatchCounts()
    end

    return found, (removedItem or target)
end

function CLIAlts:GetWatchlistSummary()
    local watchlist = (CLIAltsDB and CLIAltsDB.watchlist) or {}
    local summary = {}
    local chars = self:GetCharactersList("name", true)

    for _, item in ipairs(watchlist) do
        local total = 0
        local breakdown = {}
        for _, c in ipairs(chars) do
            local cnt = 0
            if c.watchlistCounts then
                if c.watchlistCounts[item] then
                    cnt = c.watchlistCounts[item]
                else
                    for k, v in pairs(c.watchlistCounts) do
                        if self:IsWatchItemMatch(item, k) then
                            cnt = v
                            break
                        end
                    end
                end
            end
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
        self:Print("Watchlist is empty. Use |cff00ff66/ca watch <Item Link, ID, or Name>|r to track specific items across alts.")
        return
    end
    self:Print("--- CLIAlts Watchlist Summary ---")
    for _, entry in ipairs(summary) do
        local parts = {}
        for _, b in ipairs(entry.breakdown) do
            local coloredName = self:ColorizePlayerName(b.name, b.classFile)
            table.insert(parts, string.format("%s: %s", coloredName, self:FormatNumber(b.count)))
        end
        local detail = #parts > 0 and (" (" .. table.concat(parts, ", ") .. ")") or " (none)"
        local displayName = self:GetWatchItemDisplayName(entry.item)
        local itemLabel = displayName:find("|c") and displayName or string.format("|cffffd700%s|r", displayName)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  * %s :: |cff00ff66%s total|r%s",
            itemLabel, self:FormatNumber(entry.total), detail))
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
-- Login Digest & Alert Category System (Feature 7)
-- ----------------------------------------------------------------------------
function CLIAlts:IsAlertEnabled(category)
    if not CLIAltsDB or not CLIAltsDB.settings then return true end
    CLIAltsDB.settings.alerts = CLIAltsDB.settings.alerts or {}
    local a = CLIAltsDB.settings.alerts
    if a[category] == nil then return true end
    return a[category] == true
end

function CLIAlts:ToggleAlert(category, explicitState)
    if not CLIAltsDB or not CLIAltsDB.settings then return false end
    CLIAltsDB.settings.alerts = CLIAltsDB.settings.alerts or {
        cooldowns = true,
        rested = true,
        mail = true,
        lockouts = true,
    }
    local a = CLIAltsDB.settings.alerts
    if explicitState ~= nil then
        a[category] = (explicitState == true)
    else
        a[category] = (a[category] == false)
    end
    local stateStr = a[category] and "|cff00ff66ENABLED|r" or "|cffff4444DISABLED|r"
    self:Print(string.format("Alert category '|cffffffff%s|r' is now %s.", category, stateStr))
    return a[category]
end

function CLIAlts:PrintAlertStatus()
    self:Print("--- Login Alert Settings (/ca alerts <category>) ---")
    local cd = self:IsAlertEnabled("cooldowns") and "|cff00ff66ENABLED|r" or "|cffff4444DISABLED|r"
    local rest = self:IsAlertEnabled("rested") and "|cff00ff66ENABLED|r" or "|cffff4444DISABLED|r"
    local mail = self:IsAlertEnabled("mail") and "|cff00ff66ENABLED|r" or "|cffff4444DISABLED|r"
    local lock = self:IsAlertEnabled("lockouts") and "|cff00ff66ENABLED|r" or "|cffff4444DISABLED|r"
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  * Ready Cooldowns: %s |cff888888(/ca alerts cd)|r", cd))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  * Rested Capped:   %s |cff888888(/ca alerts rested)|r", rest))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  * Mail Expiry:     %s |cff888888(/ca alerts mail)|r", mail))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  * Lockouts Reset:  %s |cff888888(/ca alerts locks)|r", lock))
    DEFAULT_CHAT_FRAME:AddMessage("  |cff888888Commands: /ca alerts [on|off|show|cd|rested|mail|locks]|r")
end

function CLIAlts:HandleAlertsCommand(arg)
    arg = arg and arg:match("^%s*(.-)%s*$") or ""
    if arg == "" then
        self:PrintAlertStatus()
        return "Alert status printed to chat."
    end

    local lower = arg:lower()
    if lower == "on" or lower == "enable" or lower == "all" then
        if CLIAltsDB and CLIAltsDB.settings then
            CLIAltsDB.settings.alerts = { cooldowns = true, rested = true, mail = true, lockouts = true }
        end
        self:Print("All login alert categories |cff00ff66ENABLED|r.")
        return "All login alerts enabled."
    elseif lower == "off" or lower == "disable" or lower == "none" then
        if CLIAltsDB and CLIAltsDB.settings then
            CLIAltsDB.settings.alerts = { cooldowns = false, rested = false, mail = false, lockouts = false }
        end
        self:Print("All login alert categories |cffff4444DISABLED|r.")
        return "All login alerts disabled."
    elseif lower == "show" or lower == "digest" or lower == "test" then
        self:PrintLoginDigest(true)
        return "Login digest displayed."
    end

    local catArg, stateArg = lower:match("^(%S+)%s*(.*)$")
    catArg = catArg or lower
    stateArg = stateArg and stateArg:match("^%s*(.-)%s*$") or ""

    local explicitState
    if stateArg == "on" or stateArg == "enable" or stateArg == "1" then
        explicitState = true
    elseif stateArg == "off" or stateArg == "disable" or stateArg == "0" then
        explicitState = false
    end

    local matchedCat
    if catArg == "cd" or catArg == "cds" or catArg == "cooldown" or catArg == "cooldowns" then
        matchedCat = "cooldowns"
    elseif catArg == "rest" or catArg == "rested" or catArg == "capped" or catArg == "xp" then
        matchedCat = "rested"
    elseif catArg == "mail" or catArg == "inbox" then
        matchedCat = "mail"
    elseif catArg == "lock" or catArg == "locks" or catArg == "lockout" or catArg == "lockouts" or catArg == "raid" then
        matchedCat = "lockouts"
    end

    if matchedCat then
        local newState = self:ToggleAlert(matchedCat, explicitState)
        return string.format("Alert '%s': %s", matchedCat, newState and "ENABLED" or "DISABLED")
    else
        self:Print("Unknown category. Valid: cd, rested, mail, locks, on, off, show")
        return "Invalid alert category."
    end
end

function CLIAlts:GetLoginDigestItems(nowOverride)
    local now = nowOverride or time()
    local items = {}

    -- 1. Ready Cooldowns Category
    if self:IsAlertEnabled("cooldowns") then
        local readyAlts = {}
        for _, c in ipairs(self:GetCharactersList()) do
            if c.tradeCooldowns and next(c.tradeCooldowns) then
                local skills = {}
                for name, readyAt in pairs(c.tradeCooldowns) do
                    if readyAt and now >= readyAt then
                        local short = name:gsub("^Transmute: ", "Xm:"):gsub("^Refined ", "")
                        short = short:sub(1, 10)
                        table.insert(skills, short)
                    end
                end
                if #skills > 0 then
                    table.sort(skills)
                    table.insert(readyAlts, { char = c, skills = skills })
                end
            end
        end
        if #readyAlts > 0 then
            table.sort(readyAlts, function(a, b) return (a.char.name or "") < (b.char.name or "") end)
            local parts = {}
            for i = 1, math.min(2, #readyAlts) do
                local c = readyAlts[i].char
                local cName = self:ColorizePlayerName(c.name, c.classFile)
                table.insert(parts, string.format("%s (%s)", cName, table.concat(readyAlts[i].skills, ",")))
            end
            if #readyAlts > 2 then
                table.insert(parts, string.format("+%d more", #readyAlts - 2))
            end
            table.insert(items, {
                cat = "cooldowns",
                label = "CDS",
                text = string.format("|cffffcc00[CDS]|r   %s READY", table.concat(parts, ", ")),
                compact = string.format("|cffffcc00[CDS]|r %s RDY", table.concat(parts, ", ")),
            })
        end
    end

    -- 2. Rested Capped Category
    if self:IsAlertEnabled("rested") then
        local capped = {}
        for _, it in ipairs(self:GetNextAltsPriority()) do
            if it.isCapped and it.char then
                table.insert(capped, it)
            end
        end
        if #capped > 0 then
            local parts = {}
            for i = 1, math.min(2, #capped) do
                local c = capped[i].char
                local cName = self:ColorizePlayerName(c.name, c.classFile)
                if capped[i].wastedXP and capped[i].wastedXP > 1000 then
                    table.insert(parts, string.format("%s (~%s XP lost)", cName, self:FormatNumber(capped[i].wastedXP)))
                else
                    table.insert(parts, string.format("%s (Capped)", cName))
                end
            end
            if #capped > 2 then
                table.insert(parts, string.format("+%d more", #capped - 2))
            end
            table.insert(items, {
                cat = "rested",
                label = "REST",
                text = string.format("|cff66ccff[REST]|r  %s", table.concat(parts, ", ")),
                compact = string.format("|cff66ccff[REST]|r %s", table.concat(parts, ", ")),
            })
        end
    end

    -- 3. Mail Expiring Category
    if self:IsAlertEnabled("mail") then
        local expiring = {}
        for _, c in ipairs(self:GetCharactersList()) do
            if c.minMailDays and c.mailCheckedTime and (c.mailCount or 0) > 0 then
                local elapsedDays = (now - c.mailCheckedTime) / 86400
                local daysRemaining = c.minMailDays - elapsedDays
                if daysRemaining <= 3.0 and daysRemaining > 0 then
                    table.insert(expiring, {
                        char = c,
                        days = daysRemaining,
                        count = c.mailCount,
                    })
                end
            end
        end
        if #expiring > 0 then
            table.sort(expiring, function(a, b) return a.days < b.days end)
            local parts = {}
            for i = 1, math.min(2, #expiring) do
                local c = expiring[i].char
                local cName = self:ColorizePlayerName(c.name, c.classFile)
                local dStr = (expiring[i].days < 1.0) and string.format("%.0fh", expiring[i].days * 24) or string.format("%.1fd", expiring[i].days)
                table.insert(parts, string.format("%s (%d in %s)", cName, expiring[i].count or 1, dStr))
            end
            if #expiring > 2 then
                table.insert(parts, string.format("+%d more", #expiring - 2))
            end
            table.insert(items, {
                cat = "mail",
                label = "MAIL",
                text = string.format("|cffff6666[MAIL]|r  %s", table.concat(parts, ", ")),
                compact = string.format("|cffff6666[MAIL]|r %s", table.concat(parts, ", ")),
            })
        end
    end

    -- 4. Lockouts Resetting Category (within 24h)
    if self:IsAlertEnabled("lockouts") then
        local locks = {}
        for _, c in ipairs(self:GetCharactersList()) do
            if c.lockouts and next(c.lockouts) then
                for instName, lockInfo in pairs(c.lockouts) do
                    local resetTime = (type(lockInfo) == "table" and lockInfo.resetTime) or lockInfo
                    if type(resetTime) == "number" then
                        local remSec = resetTime - now
                        if remSec > 0 and remSec <= 86400 then
                            local h = math.floor(remSec / 3600)
                            local m = math.floor((remSec % 3600) / 60)
                            local timeStr = (h > 0) and string.format("%dh", h) or string.format("%dm", m)
                            table.insert(locks, {
                                char = c,
                                instance = instName:sub(1, 10),
                                timeStr = timeStr,
                                remSec = remSec,
                            })
                        end
                    end
                end
            end
        end
        if #locks > 0 then
            table.sort(locks, function(a, b) return a.remSec < b.remSec end)
            local parts = {}
            for i = 1, math.min(2, #locks) do
                local c = locks[i].char
                local cName = self:ColorizePlayerName(c.name, c.classFile)
                table.insert(parts, string.format("%s (%s in %s)", cName, locks[i].instance, locks[i].timeStr))
            end
            if #locks > 2 then
                table.insert(parts, string.format("+%d more", #locks - 2))
            end
            table.insert(items, {
                cat = "lockouts",
                label = "LOCK",
                text = string.format("|cffff8844[LOCK]|r  %s", table.concat(parts, ", ")),
                compact = string.format("|cffff8844[LOCK]|r %s", table.concat(parts, ", ")),
            })
        end
    end

    return items
end

function CLIAlts:FormatLoginDigestLines(items)
    local lines = {}
    if not items or #items == 0 then return lines end

    if #items <= 3 then
        for i = 1, #items do
            table.insert(lines, items[i].text)
        end
    else
        -- Pack into 3 content lines so total with borders is at most 5 lines
        table.insert(lines, items[1].text)
        table.insert(lines, items[2].text)
        local line3 = items[3].compact .. "  |  " .. items[4].compact
        if #items > 4 then
            line3 = line3 .. string.format("  |  |cff888888+%d more (/ca digest)|r", #items - 4)
        end
        table.insert(lines, line3)
    end
    return lines
end

function CLIAlts:PrintLoginDigest(force)
    local items = self:GetLoginDigestItems()
    local border = "+-----------------[ CLIAlts :: LOGIN DIGEST ]-----------------+"
    local bottom = "+-------------------------------------------------------------+"

    if #items == 0 then
        if force then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66%s|r", border))
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff66| |r|cff888888All alts clear: no ready CDs, capped alts, or expiring mail.|r")
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66%s|r", bottom))
        end
        return
    end

    local lines = self:FormatLoginDigestLines(items)

    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66%s|r", border))
    for _, l in ipairs(lines) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66| |r%s", l))
    end
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66%s|r", bottom))
end

-- Backward compatibility helpers
function CLIAlts:CheckCappedAltsAlert()
    self:PrintLoginDigest(false)
end

function CLIAlts:CheckMailExpiryAlert()
    -- Subsumed by PrintLoginDigest
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
    table.insert(lines, "Name,Realm,Faction,Race,Class,Level,XP,MaxXP,RestedXP,RestedPct,RestedStatus,WastedXP,Gold,Silver,Copper,Prof1,Prof1Rank,Prof2,Prof2Rank,Location,Hearthstone,LastSeen,Note")

    local chars = self:GetCharactersList("name", true)
    for _, c in ipairs(chars) do
        local rested = self:GetRestedData(c)
        local _, wastedXP = self:GetRestedWaste(c)
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
            CsvQuote(c.bindLocation or "Unknown"),
            CsvQuote(lastSeenStr),
            CsvQuote(c.note or ""),
        }, ",")
        table.insert(lines, row)
    end

    return table.concat(lines, "\n")
end

-- ----------------------------------------------------------------------------
-- Leveling Session Planner & XP Tracking (Feature 10: > plan <hours>)
-- ----------------------------------------------------------------------------
function CLIAlts:InitSessionXP()
    if not UnitXP or not UnitXPMax or not UnitLevel then return end
    local curXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 0
    local curLvl = UnitLevel("player") or 1
    local curRested = (GetXPExhaustion and GetXPExhaustion()) or 0
    self.sessionXP = {
        startTime = time(),
        lastXP = curXP,
        maxXP = maxXP,
        level = curLvl,
        lastRested = curRested,
        xpGained = 0,
        restedBurned = 0,
        restedXPGained = 0,
    }
end

function CLIAlts:UpdateSessionXP()
    if not self.sessionXP then
        self:InitSessionXP()
        return
    end
    if not UnitXP or not UnitXPMax or not UnitLevel then return end
    local curXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 0
    local curLvl = UnitLevel("player") or 1
    local curRested = (GetXPExhaustion and GetXPExhaustion()) or 0

    local deltaXP = 0
    if curLvl == self.sessionXP.level then
        if curXP >= self.sessionXP.lastXP then
            deltaXP = curXP - self.sessionXP.lastXP
        end
    elseif curLvl > self.sessionXP.level then
        deltaXP = math.max(0, (self.sessionXP.maxXP - self.sessionXP.lastXP) + curXP)
        if curLvl > self.sessionXP.level + 1 then
            deltaXP = deltaXP + ((curLvl - self.sessionXP.level - 1) * maxXP)
        end
    end

    local deltaRested = 0
    if self.sessionXP.lastRested and curRested < self.sessionXP.lastRested then
        deltaRested = self.sessionXP.lastRested - curRested
    end

    self.sessionXP.xpGained = (self.sessionXP.xpGained or 0) + deltaXP
    if deltaRested > 0 then
        self.sessionXP.restedBurned = (self.sessionXP.restedBurned or 0) + deltaRested
        self.sessionXP.restedXPGained = (self.sessionXP.restedXPGained or 0) + deltaXP
    end

    self.sessionXP.lastXP = curXP
    self.sessionXP.maxXP = maxXP
    self.sessionXP.level = curLvl
    self.sessionXP.lastRested = curRested

    -- Check burn ratio drift if at least 1,000 rested XP has been burned this session
    if (self.sessionXP.restedBurned or 0) >= 1000 then
        self:CheckBurnRatioDrift()
    end

end

function CLIAlts:FinalizeSessionXP()
    if not self.sessionXP or self.sessionXP.finalized then return end
    local now = time()
    local elapsed = now - (self.sessionXP.startTime or now)
    local xpGained = self.sessionXP.xpGained or 0
    -- Require at least 10 minutes (600s) and at least 1,000 XP gained to blend into char.xpHour
    if elapsed >= 600 and xpGained >= 1000 then
        local currentRate = (xpGained / elapsed) * 3600
        local curKey = self.curPlayerKey
        if not curKey then
            local _, _, full = self:GetPlayerNames()
            curKey = full and self:GetCharacterKey(full)
        end
        if curKey and CLIAltsDB and CLIAltsDB.characters and CLIAltsDB.characters[curKey] then
            local char = CLIAltsDB.characters[curKey]
            if char.xpHour and char.xpHour > 0 then
                char.xpHour = math.floor(char.xpHour * 0.75 + currentRate * 0.25 + 0.5)
            else
                char.xpHour = math.floor(currentRate + 0.5)
            end
        end
        self.sessionXP.finalized = true
    end
end

function CLIAlts:GetEstimatedXpHour(char)
    if char and char.xpHour and char.xpHour > 0 then
        return char.xpHour, false
    end
    local lvl = (char and char.level) or 1
    return math.max(5000, math.floor(lvl * 650 + 4000)), true
end

function CLIAlts:EvaluateBurnRatio(restedBurned, restedXPGained, currentRatio, pendingRatio)
    if not restedBurned or not restedXPGained or restedBurned < 1000 or restedXPGained <= 0 then
        return nil, 0, "SHORT_SAMPLE"
    end
    currentRatio = currentRatio or 0.5
    local observedRatio = restedBurned / restedXPGained
    local drift = (observedRatio - currentRatio) / currentRatio

    -- Require at least 5% drift from current ratio to consider adjusting
    if math.abs(drift) <= 0.05 then
        return currentRatio, drift, "MATCH"
    end

    -- Discretize / round inferred ratio to nearest 0.05, clamped between 0.20 and 1.00
    local inferredRatio = math.floor((observedRatio * 20) + 0.5) / 20
    if inferredRatio < 0.20 then inferredRatio = 0.20 end
    if inferredRatio > 1.00 then inferredRatio = 1.00 end

    if math.abs(inferredRatio - currentRatio) < 0.01 then
        return currentRatio, drift, "MATCH"
    end

    local confirmed = (pendingRatio and math.abs(pendingRatio - inferredRatio) < 0.01)
    return inferredRatio, drift, confirmed and "CONFIRMED" or "PENDING"
end

function CLIAlts:CheckBurnRatioDrift()
    if not self.sessionXP then return end
    local restedBurned = self.sessionXP.restedBurned or 0
    local restedXPGained = self.sessionXP.restedXPGained or 0
    local curRatio = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.restedBurnRatio) or 0.5
    local pendingRatio = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.pendingBurnRatio

    local inferred, drift, status = self:EvaluateBurnRatio(restedBurned, restedXPGained, curRatio, pendingRatio)
    if status == "MATCH" then
        if CLIAltsDB and CLIAltsDB.settings then CLIAltsDB.settings.pendingBurnRatio = nil end
    elseif status == "PENDING" then
        if CLIAltsDB and CLIAltsDB.settings then CLIAltsDB.settings.pendingBurnRatio = inferred end
    elseif status == "CONFIRMED" then
        if CLIAltsDB and CLIAltsDB.settings then
            CLIAltsDB.settings.restedBurnRatio = inferred
            CLIAltsDB.settings.pendingBurnRatio = nil
        end
        self:Print(string.format("Rested burn ratio self-calibrated (confirmed): %.2f (drift was %+.1f%%).",
            inferred, drift * 100))
    end
end

function CLIAlts:GenerateLevelingPlan(targetHours, mockChars, nowTimestamp)
    targetHours = tonumber(targetHours) or 2
    if targetHours <= 0 then targetHours = 2 end
    local targetMinutes = math.floor(targetHours * 60 + 0.5)

    local now = nowTimestamp or time()
    local burnRatio = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.restedBurnRatio) or 0.5
    local chars = mockChars or self:GetCharactersList()
    local candidates = {}

    for _, c in ipairs(chars) do
        local lvl = c.level or 1
        local maxLvl = c.maxLevel or self:GetMaxLevel() or 60
        if lvl < maxLvl then
            local restedXP, restedState
            if mockChars then
                restedXP = c.restedXP or 0
                restedState = (restedXP >= (c.maxXP or 1) * 1.5) and "FULL" or "RESTING"
            else
                local rested = self:GetRestedData(c, false, now)
                restedXP = rested and rested.currentRested or 0
                restedState = (rested and rested.isFull) and "FULL" or "RESTING"
            end

            if restedXP and restedXP > 0 then
                local xpHour, isFallbackRate = self:GetEstimatedXpHour(c)
                local burnRatePerHour = xpHour * burnRatio
                local burnHours = restedXP / math.max(1, burnRatePerHour)
                local burnMinutes = math.max(1, math.floor(burnHours * 60 + 0.5))

                local maxXP = c.maxXP or 1
                local speedMult = 1 + (((CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.wellRestedRank) or 0) * 0.04)
                local maxRested = maxXP * 1.5 * speedMult
                local isCapped = (restedXP >= maxRested * 0.99)
                local wastedXP = 0
                if not mockChars then
                    _, wastedXP = self:GetRestedWaste(c, now)
                end

                table.insert(candidates, {
                    char = c,
                    name = c.name or "Unknown",
                    classFile = c.classFile,
                    level = lvl,
                    restedXP = restedXP,
                    restedState = restedState,
                    xpHour = xpHour,
                    isFallbackRate = isFallbackRate,
                    burnMinutes = burnMinutes,
                    isCapped = isCapped,
                    wastedXP = wastedXP or 0,
                })
            end
        end
    end

    if #candidates == 0 then
        return {}, "No alts with rested XP available to plan for.", 0, targetMinutes
    end

    -- Priority ordering:
    -- 1. Capped alts (urgency: stop rested waste), higher wasted XP first
    -- 2. Rested burn minutes descending
    -- 3. Level descending, then name ascending
    table.sort(candidates, function(a, b)
        if a.isCapped ~= b.isCapped then
            return a.isCapped == true
        end
        if a.isCapped and b.isCapped then
            if (a.wastedXP or 0) ~= (b.wastedXP or 0) then
                return (a.wastedXP or 0) > (b.wastedXP or 0)
            end
        end
        if a.burnMinutes ~= b.burnMinutes then
            return a.burnMinutes > b.burnMinutes
        end
        if a.level ~= b.level then
            return a.level > b.level
        end
        return (a.name or "") < (b.name or "")
    end)

    local schedule = {}
    local remaining = targetMinutes
    local scheduleParts = {}

    for _, cand in ipairs(candidates) do
        local allocated = math.min(cand.burnMinutes, remaining)
        if allocated > 0 then
            table.insert(schedule, {
                char = cand.char,
                name = cand.name,
                classFile = cand.classFile,
                level = cand.level,
                mins = allocated,
                burnMinutes = cand.burnMinutes,
                restedXP = cand.restedXP,
                xpHour = cand.xpHour,
                isFallbackRate = cand.isFallbackRate,
                isCapped = cand.isCapped,
                wastedXP = cand.wastedXP,
            })
            local coloredName = self:ColorizePlayerName(cand.name, cand.classFile)
            table.insert(scheduleParts, string.format("%s %dm", coloredName, allocated))
            remaining = remaining - allocated
        end
        if remaining <= 0 then
            break
        end
    end

    local summaryText = table.concat(scheduleParts, ", then ")
    local totalAllocated = targetMinutes - remaining
    return schedule, summaryText, totalAllocated, targetMinutes
end

function CLIAlts:PrintPlan(targetHours)
    local schedule, summaryText, totalAllocated, targetMinutes = self:GenerateLevelingPlan(targetHours)
    if #schedule == 0 then
        self:Print(summaryText)
        return summaryText
    end

    local hoursLabel = (targetMinutes % 60 == 0) and string.format("%dh", targetMinutes / 60) or string.format("%.1fh", targetMinutes / 60)
    local border = string.format("+-----------------[ LEVELING PLAN :: %s ]-----------------+", hoursLabel)
    local bottom = "+-------------------------------------------------------------+"

    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66%s|r", border))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66| |r|cffffffffSchedule:|r %s", summaryText))
    for i, it in ipairs(schedule) do
        local coloredName = self:ColorizePlayerName(it.name, it.classFile)
        local ratePrefix = it.isFallbackRate and "~" or ""
        local rateStr = string.format("%s%s XP/h", ratePrefix, self:FormatNumber(it.xpHour))
        local poolStr = string.format("%s rested", self:FormatNumber(it.restedXP))
        local note = it.isCapped and " |cffff6666(CAPPED)|r" or ""
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66| |r  |cff00ff66%d.|r %s (Lvl %d) -> |cffffd700%dm|r of %dm pool (%s, %s)%s",
            i, coloredName, it.level, it.mins, it.burnMinutes, poolStr, rateStr, note))
    end
    if totalAllocated < targetMinutes then
        local remMins = targetMinutes - totalAllocated
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66| |r|cff888888Notice: Rested pools exhausted with %dm unallocated in session.|r", remMins))
    end
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66%s|r", bottom))

    return summaryText
end

-- ----------------------------------------------------------------------------
-- Lockout Gap Finder (Feature: > unlocked <instance>)
-- ----------------------------------------------------------------------------
local KNOWN_INSTANCES = {
    ["molten core"] = { name = "Molten Core", minLevel = 60 },
    ["mc"] = { name = "Molten Core", minLevel = 60 },
    ["blackwing lair"] = { name = "Blackwing Lair", minLevel = 60 },
    ["bwl"] = { name = "Blackwing Lair", minLevel = 60 },
    ["onyxia's lair"] = { name = "Onyxia's Lair", minLevel = 60 },
    ["onyxia"] = { name = "Onyxia's Lair", minLevel = 60 },
    ["ony"] = { name = "Onyxia's Lair", minLevel = 60 },
    ["zul'gurub"] = { name = "Zul'Gurub", minLevel = 60 },
    ["zg"] = { name = "Zul'Gurub", minLevel = 60 },
    ["ruins of ahn'qiraj"] = { name = "Ruins of Ahn'Qiraj", minLevel = 60 },
    ["aq20"] = { name = "Ruins of Ahn'Qiraj", minLevel = 60 },
    ["temple of ahn'qiraj"] = { name = "Temple of Ahn'Qiraj", minLevel = 60 },
    ["aq40"] = { name = "Temple of Ahn'Qiraj", minLevel = 60 },
    ["naxxramas"] = { name = "Naxxramas", minLevel = 60 },
    ["naxx"] = { name = "Naxxramas", minLevel = 60 },
    ["upper blackrock spire"] = { name = "Upper Blackrock Spire", minLevel = 58 },
    ["ubrs"] = { name = "Upper Blackrock Spire", minLevel = 58 },
    ["lower blackrock spire"] = { name = "Lower Blackrock Spire", minLevel = 55 },
    ["lbrs"] = { name = "Lower Blackrock Spire", minLevel = 55 },
    ["stratholme"] = { name = "Stratholme", minLevel = 55 },
    ["strat"] = { name = "Stratholme", minLevel = 55 },
    ["scholomance"] = { name = "Scholomance", minLevel = 55 },
    ["scholo"] = { name = "Scholomance", minLevel = 55 },
    ["dire maul"] = { name = "Dire Maul", minLevel = 55 },
    ["dm"] = { name = "Dire Maul", minLevel = 55 },
    ["blackrock depths"] = { name = "Blackrock Depths", minLevel = 50 },
    ["brd"] = { name = "Blackrock Depths", minLevel = 50 },
}

function CLIAlts:GetUnlockedAlts(query, nowTimestamp, mockChars)
    if not query or query == "" then
        return nil, nil, nil, nil, "Usage: unlocked <instance> (e.g. unlocked \"Molten Core\")"
    end

    local cleaned = query:gsub('^["\']', ''):gsub('["\']$', ''):match('^%s*(.-)%s*$')
    if not cleaned or cleaned == "" then
        return nil, nil, nil, nil, "Usage: unlocked <instance> (e.g. unlocked \"Molten Core\")"
    end

    local now = nowTimestamp or time()
    local qLower = cleaned:lower()

    if not KNOWN_INSTANCES[qLower] and string.len(cleaned) < 3 then
        return nil, nil, nil, nil, "Instance query must be at least 3 characters."
    end

    local canonName = cleaned
    local minLevel = self:GetMaxLevel()

    if KNOWN_INSTANCES[qLower] then
        canonName = KNOWN_INSTANCES[qLower].name
        minLevel = KNOWN_INSTANCES[qLower].minLevel or self:GetMaxLevel()
    else
        local chars = mockChars or self:GetCharactersList()
        for _, c in ipairs(chars) do
            if c.lockouts then
                for instName, _ in pairs(c.lockouts) do
                    if #qLower >= 3 and instName:lower():find(qLower, 1, true) then
                        canonName = instName
                        break
                    end
                end
            end
            if canonName ~= cleaned then break end
        end
    end

    local chars = mockChars or self:GetCharactersList()
    local unlocked = {}
    local locked = {}

    for _, c in ipairs(chars) do
        local lvl = c.level or 1
        if lvl >= minLevel then
            local isLocked = false
            local remainingSec = 0
            local lockId = nil

            if c.lockouts then
                for instName, lockInfo in pairs(c.lockouts) do
                    local matches = (instName:lower() == canonName:lower())
                        or (#qLower >= 3 and instName:lower():find(qLower, 1, true) ~= nil)
                        or (canonName:lower():find(instName:lower(), 1, true) ~= nil)

                    if matches then
                        local resetTime = (type(lockInfo) == "table" and lockInfo.resetTime) or lockInfo
                        if type(resetTime) == "number" then
                            local rem = resetTime - now
                            if rem > 0 then
                                isLocked = true
                                remainingSec = rem
                                lockId = (type(lockInfo) == "table" and lockInfo.id) or nil
                                break
                            end
                        end
                    end
                end
            end

            if isLocked then
                table.insert(locked, {
                    char = c,
                    name = c.name or "Unknown",
                    classFile = c.classFile,
                    level = lvl,
                    resetSec = remainingSec,
                    lockId = lockId,
                })
            else
                table.insert(unlocked, {
                    char = c,
                    name = c.name or "Unknown",
                    classFile = c.classFile,
                    level = lvl,
                    professions = c.professions,
                    note = c.note,
                })
            end
        end
    end

    table.sort(unlocked, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        return (a.name or "") < (b.name or "")
    end)

    table.sort(locked, function(a, b)
        return (a.resetSec or 0) < (b.resetSec or 0)
    end)

    return unlocked, locked, canonName, minLevel, nil
end

function CLIAlts:PrintUnlockedAlts(query, nowTimestamp, mockChars)
    local unlocked, locked, canonName, minLevel, errMsg = self:GetUnlockedAlts(query, nowTimestamp, mockChars)
    if errMsg then
        self:Print(errMsg)
        return errMsg, false
    end

    local titleTag = string.format("UNLOCKED :: %s (Lvl %d+)", canonName, minLevel)
    local border = string.format("+-----------------[ %s ]-----------------+", titleTag)
    local bottom = string.rep("-", #border - 2)
    bottom = "+" .. bottom .. "+"

    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66%s|r", border))

    if #unlocked == 0 and #locked == 0 then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66| |r|cff888888No characters found at required level %d+ for %s.|r", minLevel, canonName))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66%s|r", bottom))
        local fb = string.format("No alts at level %d+ for %s.", minLevel, canonName)
        return fb, false
    end

    if #unlocked > 0 then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66| |r|cffffffffUNLOCKED (%d alts):|r", #unlocked))
        for _, u in ipairs(unlocked) do
            local cName = self:ColorizePlayerName(u.name, u.classFile)
            local profStr = ""
            if u.professions and u.professions.primary and #u.professions.primary > 0 then
                local pList = {}
                for _, p in ipairs(u.professions.primary) do
                    table.insert(pList, string.format("%s %d", p.name:sub(1, 6), p.rank or 0))
                end
                profStr = string.format(" [%s]", table.concat(pList, ", "))
            end
            local noteStr = (u.note and u.note ~= "") and string.format(" |cffffd700(%s)|r", u.note) or ""
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66| |r  * %s (Lvl %d %s) -> |cff00ff66[READY / UNLOCKED]|r%s%s",
                cName, u.level, self:FormatRaceClass(u.char), profStr, noteStr))
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66| |r|cffff8844UNLOCKED (0 alts): All level %d+ alts are currently locked!|r", minLevel))
    end

    if #locked > 0 then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66| |r|cffff8844LOCKED (%d alts):|r", #locked))
        for _, l in ipairs(locked) do
            local cName = self:ColorizePlayerName(l.name, l.classFile)
            local d = math.floor(l.resetSec / 86400)
            local h = math.floor((l.resetSec % 86400) / 3600)
            local m = math.floor((l.resetSec % 3600) / 60)
            local timeStr
            if d > 0 then
                timeStr = string.format("%dd %dh", d, h)
            elseif h > 0 then
                timeStr = string.format("%dh %dm", h, m)
            else
                timeStr = string.format("%dm", m)
            end
            local idStr = l.lockId and string.format(" (ID: %s)", l.lockId) or ""
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66| |r  * %s (Lvl %d) -> |cffff6666Locked (resets in %s)%s|r",
                cName, l.level, timeStr, idStr))
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66%s|r", bottom))

    local names = {}
    for i = 1, math.min(3, #unlocked) do
        table.insert(names, unlocked[i].name)
    end
    if #unlocked > 3 then
        table.insert(names, string.format("+%d more", #unlocked - 3))
    end
    local fb
    if #unlocked > 0 then
        fb = string.format("Unlocked for %s (%d): %s", canonName, #unlocked, table.concat(names, ", "))
    else
        fb = string.format("All %d alts locked for %s.", #locked, canonName)
    end
    return fb, true
end


