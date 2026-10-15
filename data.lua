-- ============================================================================
-- CLIAlts: Retro Alt Tracker
-- File: data.lua
-- Database management, character data collection, and rested XP calculations.
-- ============================================================================

local addonName, addonTable = ...
local CLIAlts = addonTable or _G["CLIAlts"] or {}
_G["CLIAlts"] = CLIAlts
_G["clialts"] = CLIAlts

function CLIAlts:Print(msg)
    local tag = "|cffffb000[CLIAlts]|r"
    if self.GetTheme then
        local t = self:GetTheme()
        if t and t.primaryHex then
            tag = string.format("|cff%s[CLIAlts]|r", t.primaryHex)
        end
    end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s %s", tag, msg or ""))
    else
        print(string.format("[CLIAlts] %s", msg or ""))
    end
end

-- ----------------------------------------------------------------------------
-- Constants & Reference Tables
-- ----------------------------------------------------------------------------
CLIAlts.VERSION = "1.1.0"
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
-- Client Flavor & Retail Detection Helper
-- ----------------------------------------------------------------------------
function CLIAlts:IsForeverClient()
    if self.isForeverOverride ~= nil then
        return self.isForeverOverride
    end
    if self:IsRetail() then
        return false
    end
    -- 1. Dedicated WoW Forever APIs (Primary & Secondary name engine)
    if UnitSecondaryName or UnitSurname or GetUnitSecondaryName or GetUnitSurname then
        return true
    end
    -- 2. Cached current player has secondary name
    if self.curPlayerSecondary and self.curPlayerSecondary ~= "" then
        return true
    end
    -- 3. UnitName("player") returns second parameter that differs from realm name
    if UnitName then
        local _, v2 = UnitName("player")
        local realm = GetRealmName and GetRealmName()
        if v2 and v2 ~= "" and v2 ~= realm then
            return true
        end
    end
    -- 4. Tracked characters database contains characters with secondary names
    if CLIAltsDB and CLIAltsDB.characters then
        for _, c in pairs(CLIAltsDB.characters) do
            if c.secondaryName and c.secondaryName ~= "" then
                return true
            end
        end
    end
    -- 5. Realm name contains Forever
    local r = GetRealmName and GetRealmName()
    if r and (r:find("Forever") or r == "Forever") then
        return true
    end
    return false
end

function CLIAlts:IsRetail()
    if self.isRetailOverride ~= nil then
        return self.isRetailOverride
    end
    if WOW_PROJECT_ID and WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
        return true
    end
    if GetBuildInfo then
        local _, _, _, tocversion = GetBuildInfo()
        if tocversion and type(tocversion) == "number" and tocversion >= 100000 then
            return true
        end
    end
    return false
end

function CLIAlts:GetClientFlavor()
    if self:IsRetail() then
        return "Retail"
    end
    if self:IsForeverClient() then
        return "WoW Forever"
    end
    if WOW_PROJECT_ID and WOW_PROJECT_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
        return "Classic Era"
    end
    return "Classic"
end

function CLIAlts:IsForeverMode()
    if self.isForeverOverride ~= nil then
        return self.isForeverOverride
    end
    if CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.foreverMode ~= nil then
        return CLIAltsDB.settings.foreverMode == true
    end
    return self:IsForeverClient()
end

function CLIAlts:ToggleForeverMode()
    if not CLIAltsDB or not CLIAltsDB.settings then return false end
    CLIAltsDB.settings.foreverMode = not self:IsForeverMode()
    if self.ApplyLayoutSize then self:ApplyLayoutSize() end
    if self.Render then self:Render() end
    return CLIAltsDB.settings.foreverMode
end

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
-- Database Snapshot Backup & Restore (/clialts backup, /clialts restore)
-- ----------------------------------------------------------------------------
function CLIAlts:CopyTable(src, seen)
    if type(src) ~= "table" then return src end
    if seen and seen[src] then return seen[src] end
    local s = seen or {}
    local copy = {}
    s[src] = copy
    for k, v in pairs(src) do
        if type(v) == "table" then
            copy[k] = self:CopyTable(v, s)
        else
            copy[k] = v
        end
    end
    return copy
end

function CLIAlts:BackupDB(reason)
    if not CLIAltsDB then return false, "No database to backup." end
    local backup = {}
    for k, v in pairs(CLIAltsDB) do
        if k ~= "backup" then
            backup[k] = (type(v) == "table") and self:CopyTable(v) or v
        end
    end
    backup._backupTime = time()
    backup._backupReason = reason or "manual"
    CLIAltsDB.backup = backup
    return true, "Backup saved to CLIAltsDB.backup."
end

function CLIAlts:RestoreDB()
    if not CLIAltsDB or not CLIAltsDB.backup then
        return false, "No backup available to restore."
    end
    local backupSlot = CLIAltsDB.backup
    for k in pairs(CLIAltsDB) do
        if k ~= "backup" then
            CLIAltsDB[k] = nil
        end
    end
    for k, v in pairs(backupSlot) do
        if k ~= "backup" and k ~= "_backupTime" and k ~= "_backupReason" then
            CLIAltsDB[k] = (type(v) == "table") and self:CopyTable(v) or v
        end
    end
    CLIAltsDB.backup = backupSlot
    self.dbInitialized = false
    self:InitDB()
    if self.RequestRender then
        self:RequestRender()
    end
    local tStr = backupSlot._backupTime and date and date("%Y-%m-%d %H:%M:%S", backupSlot._backupTime) or "recent"
    local vStr = tostring(backupSlot.dbVersion or "?")
    return true, string.format("Database restored from backup (v%s, saved %s).", vStr, tStr)
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
    CLIAltsDB.settings.theme = CLIAltsDB.settings.theme or "AMBER"
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
    if CLIAltsDB.settings.showInventoryTooltips == nil then CLIAltsDB.settings.showInventoryTooltips = true end
    if CLIAltsDB.settings.showBagSortButton == nil then CLIAltsDB.settings.showBagSortButton = true end
    if CLIAltsDB.settings.showMailAutoFillButton == nil then CLIAltsDB.settings.showMailAutoFillButton = true end
    if CLIAltsDB.settings.autoFillMailOnSend == nil then CLIAltsDB.settings.autoFillMailOnSend = true end
    if CLIAltsDB.settings.foreverMode == false and self:IsForeverClient() then
        CLIAltsDB.settings.foreverMode = nil
    end
    CLIAltsDB.characters = CLIAltsDB.characters or {}
    CLIAltsDB.goldHistory = CLIAltsDB.goldHistory or {}
    CLIAltsDB.watchlist = CLIAltsDB.watchlist or {}
    CLIAltsDB.commandHistory = CLIAltsDB.commandHistory or {}

    -- Run one-time migration and repair only if dbVersion is older than CURRENT_DB_VERSION
    if (tonumber(CLIAltsDB.dbVersion) or 0) < CURRENT_DB_VERSION then
        -- Automatically backup CLIAltsDB to a one-slot CLIAltsDB.backup before any migration
        self:BackupDB("migration")

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

    -- Repair resting state for characters whose location confirms an inn or resting area
    if CLIAltsDB and CLIAltsDB.characters then
        for _, char in pairs(CLIAltsDB.characters) do
            if char.location and self:IsLocationResting(char.location) then
                if char.isResting ~= true or char.loggedOutInRestZone ~= true then
                    char.isResting = true
                    char.loggedOutInRestZone = true
                end
            end
        end
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

function CLIAlts:CollectDungeonQuests(existing)
    local completed = {}
    if existing and type(existing) == "table" then
        for qid, val in pairs(existing) do
            if val then completed[qid] = true end
        end
    end

    pcall(function()
        if GetQuestsCompleted then
            local bulk = {}
            GetQuestsCompleted(bulk)
            for qid, val in pairs(bulk) do
                if val then completed[qid] = true end
            end
        end
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and self.DUNGEON_DATA then
            for _, dng in pairs(self.DUNGEON_DATA) do
                if dng.quests then
                    for _, q in ipairs(dng.quests) do
                        if C_QuestLog.IsQuestFlaggedCompleted(q.id) then
                            completed[q.id] = true
                        end
                    end
                end
                if dng.preChains then
                    for _, chain in ipairs(dng.preChains) do
                        for _, stepId in ipairs(chain.steps) do
                            if C_QuestLog.IsQuestFlaggedCompleted(stepId) then
                                completed[stepId] = true
                            end
                        end
                    end
                end
            end
        end
    end)
    return completed
end

function CLIAlts:CollectActiveDungeonQuests()
    local active = {}
    pcall(function()
        if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
            local n = C_QuestLog.GetNumQuestLogEntries() or 0
            for i = 1, n do
                local info = C_QuestLog.GetInfo(i)
                if info and not info.isHeader and info.questID and info.questID > 0 then
                    active[info.questID] = info.isComplete or true
                end
            end
        elseif GetNumQuestLogEntries and GetQuestLogTitle then
            local n = GetNumQuestLogEntries() or 0
            for i = 1, n do
                local _, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
                if not isHeader and questID and questID > 0 then
                    active[questID] = isComplete or true
                end
            end
        end
    end)
    return active
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
-- Cross-Character Inventory Scanner & Query API (Feature 6)
-- ----------------------------------------------------------------------------
function CLIAlts:GetContainerItemData(bagID, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bagID, slot)
        if info then
            local id = info.itemID
            if not id and info.hyperlink then
                id = tonumber(info.hyperlink:match("item:(%d+)"))
            end
            return id, (info.stackCount or 1), info.hyperlink
        end
    elseif GetContainerItemInfo then
        local _, count, _, _, _, _, link = GetContainerItemInfo(bagID, slot)
        if link then
            local id = tonumber(link:match("item:(%d+)"))
            return id, (count or 1), link
        end
    end
    return nil, 0, nil
end

function CLIAlts:GetNumContainerSlots(bagID)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagID) or 0
    elseif GetContainerNumSlots then
        return GetContainerNumSlots(bagID) or 0
    end
    return 0
end

function CLIAlts:CollectInventory(existingInventory, forceScanBank)
    local inventory = {}
    local isBankOpen = forceScanBank
    if isBankOpen == nil then
        isBankOpen = (self.isBankOpen == true)
    end

    local newBag = {}
    local numBags = NUM_BAG_SLOTS or 4
    if self.IsRetail and self:IsRetail() then numBags = 5 end

    pcall(function()
        for bag = 0, numBags do
            local numSlots = self:GetNumContainerSlots(bag)
            for slot = 1, numSlots do
                local itemID, count = self:GetContainerItemData(bag, slot)
                if itemID and count and count > 0 then
                    newBag[itemID] = (newBag[itemID] or 0) + count
                end
            end
        end
    end)

    local newBank = nil
    if isBankOpen then
        newBank = {}
        pcall(function()
            -- Main bank container (-1)
            local mainSlots = self:GetNumContainerSlots(-1)
            for slot = 1, mainSlots do
                local itemID, count = self:GetContainerItemData(-1, slot)
                if itemID and count and count > 0 then
                    newBank[itemID] = (newBank[itemID] or 0) + count
                end
            end
            -- Bank bag containers
            local firstBankBag = (NUM_BAG_SLOTS or 4) + 1
            local lastBankBag = (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 7)
            for bag = firstBankBag, lastBankBag do
                local numSlots = self:GetNumContainerSlots(bag)
                for slot = 1, numSlots do
                    local itemID, count = self:GetContainerItemData(bag, slot)
                    if itemID and count and count > 0 then
                        newBank[itemID] = (newBank[itemID] or 0) + count
                    end
                end
            end
            -- Reagent Bank (-3) if present
            local reagentSlots = self:GetNumContainerSlots(-3)
            if reagentSlots > 0 then
                for slot = 1, reagentSlots do
                    local itemID, count = self:GetContainerItemData(-3, slot)
                    if itemID and count and count > 0 then
                        newBank[itemID] = (newBank[itemID] or 0) + count
                    end
                end
            end
        end)
    end

    -- Merge bag and bank
    local allIDs = {}
    for id in pairs(newBag) do allIDs[id] = true end
    if newBank then
        for id in pairs(newBank) do allIDs[id] = true end
    elseif existingInventory then
        for id, data in pairs(existingInventory) do
            if data and data.bank and data.bank > 0 then
                allIDs[id] = true
            end
        end
    end

    for id in pairs(allIDs) do
        local b = newBag[id] or 0
        local k = 0
        if newBank then
            k = newBank[id] or 0
        elseif existingInventory and existingInventory[id] then
            k = existingInventory[id].bank or 0
        end
        if b > 0 or k > 0 then
            inventory[id] = {
                bag = (b > 0) and b or nil,
                bank = (k > 0) and k or nil,
            }
        end
    end

    return inventory, isBankOpen
end

function CLIAlts:ScanCurrentInventory(scanBank)
    if not CLIAltsDB or not CLIAltsDB.characters then return end
    local curKey = self.curPlayerKey
    if not curKey then
        local _, _, full = self:GetPlayerNames()
        curKey = full and self:GetCharacterKey(full)
    end
    if not curKey then return end

    local char = CLIAltsDB.characters[curKey]
    if not char then return end

    local inv, wasBankScanned = self:CollectInventory(char.inventory, scanBank)
    char.inventory = inv
    if wasBankScanned then
        char.bankScanned = true
        char.bankLastScan = time()
    end

    if cachedCurrentChar and cachedCurrentChar ~= char then
        cachedCurrentChar.inventory = char.inventory
        if wasBankScanned then
            cachedCurrentChar.bankScanned = true
            cachedCurrentChar.bankLastScan = char.bankLastScan
        end
    end
end

function CLIAlts:GetItemInventorySummary(targetItem)
    local itemID = self:ResolveWatchItem(targetItem)
    if not itemID or type(itemID) ~= "number" then
        return 0, {}
    end

    local totalCount = 0
    local breakdown = {}
    local chars = self:GetCharactersList("name", true)
    local curKey = self.curPlayerKey

    for _, c in ipairs(chars) do
        if c.inventory and c.inventory[itemID] then
            local inv = c.inventory[itemID]
            local b = inv.bag or 0
            local k = inv.bank or 0
            local sum = b + k
            if sum > 0 then
                totalCount = totalCount + sum
                table.insert(breakdown, {
                    char = c,
                    name = c.fullName or c.name,
                    classFile = c.classFile or "WARRIOR",
                    realm = c.realm,
                    isCurrent = (c.key == curKey),
                    bag = b,
                    bank = k,
                    total = sum,
                })
            end
        end
    end

    return totalCount, breakdown, itemID
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

    -- Robust resting determination for live gameplay, logout & session tracking:
    -- 1. Live IsResting() if client reports active
    -- 2. Cached live resting flag tracked during active session (self.isPlayerResting)
    -- 3. Location matching fallback (inns, capital cities, sanctuaries)
    -- 4. Preserve existing resting status if client returns uninitialized/nil at logout
    local isResting = liveResting
    if isResting then
        self.isPlayerResting = true
    else
        if self.isPlayerResting == true then
            isResting = true
        elseif self:IsLocationResting(location) then
            isResting = true
        elseif isLogout and existing and (existing.loggedOutInRestZone == true or existing.isResting == true) then
            isResting = true
        end
    end
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
        tier = (existing and existing.tier) or (cachedCurrentChar and cachedCurrentChar.tier) or "UNASSIGNED",
        supply_role = (existing and existing.supply_role) or (cachedCurrentChar and cachedCurrentChar.supply_role),
        target_level = (existing and existing.target_level) or (cachedCurrentChar and cachedCurrentChar.target_level),
        inventory = self:CollectInventory(existing and existing.inventory),
        dungeonQuests = self:CollectDungeonQuests(existing and existing.dungeonQuests),
        activeQuests = self:CollectActiveDungeonQuests(),
        bankScanned = (existing and existing.bankScanned) or false,
        bankLastScan = existing and existing.bankLastScan,
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

function CLIAlts:IsLocationResting(loc)
    if not loc or loc == "" then return false end
    local l = loc:lower()

    -- 1. Common inn, tavern, distillery, camp, sanctuary keywords
    if l:find("inn", 1, true)
       or l:find("tavern", 1, true)
       or l:find("distillery", 1, true)
       or l:find("brewery", 1, true)
       or l:find("lodge", 1, true)
       or l:find("saloon", 1, true)
       or l:find("campsite", 1, true)
       or l:find("tent", 1, true)
       or l:find("resting", 1, true)
       or l:find("haven", 1, true)
       or l:find("refuge", 1, true)
       or l:find("sanctuary", 1, true)
       or l:find("innkeeper", 1, true)
       or l:find("cantina", 1, true)
       or l:find("pride", 1, true)
       or l:find("stoutlager", 1, true) then
        return true
    end

    -- 2. Major capital cities & sanctuary hubs (entire zone is a rest area)
    local cities = {
        "stormwind", "ironforge", "darnassus", "exodar", "deeprun tram",
        "orgrimmar", "undercity", "thunder bluff", "silvermoon",
        "shattrath", "dalaran", "booty bay", "gadgetzan", "everlook", "ratchet"
    }
    for _, city in ipairs(cities) do
        if l:find(city, 1, true) then
            return true
        end
    end

    -- 3. Well-known resting settlements & town subzones with inns
    local settlements = {
        "goldshire", "kharanos", "thelsamar", "lakeshire", "darkshire",
        "sentinel hill", "southshore", "menethil", "auberdine", "astranaar",
        "feathermoon", "nijel", "thalanaar", "aerie peak", "nethergarde",
        "razor hill", "bloodhoof", "brill", "crossroads", "tarren mill",
        "sun rock", "freewind", "shadowprey", "camp taurajo", "camp narache",
        "camp mojache", "dolanaar", "deathknell", "sepulcher", "kargath",
        "stonard", "hammerfall", "revantusk", "splintertree", "cenarion hold"
    }
    for _, set in ipairs(settlements) do
        if l:find(set, 1, true) then
            return true
        end
    end

    return false
end

function CLIAlts:IsCharacterResting(char)
    if not char then return false end

    -- 1. If currently logged in as this character, live IsResting() is authoritative
    if self:IsCurrentPlayer(char) then
        if IsResting and IsResting() then
            return true
        end
        if self.isPlayerResting == true then
            return true
        end
        return false
    end

    -- 2. Explicit resting flag recorded at clean logout
    if char.loggedOutInRestZone == true or char.isResting == true then
        return true
    end

    -- 3. Location heuristic fallback (e.g. character parked in an Inn or Capital City)
    if char.location and self:IsLocationResting(char.location) then
        return true
    end

    return false
end

-- ----------------------------------------------------------------------------
-- WoW Forever Legacy Perk: "Well Rested" (Adventure Tree, Ranks 0-5)
-- Each rank gives +4% accumulation speed and +4% max rested cap (up to +20%).
-- ----------------------------------------------------------------------------
function CLIAlts:SetWellRestedRank(rank)
    if self:IsRetail() then
        self:Print("Well Rested perks are only available on WoW Forever (Retail uses baseline 150% rested rates).")
        return
    end
    rank = tonumber(rank) or 0
    if rank < 0 then rank = 0 end
    if rank > 5 then rank = 5 end

    CLIAltsDB.settings = CLIAltsDB.settings or {}
    CLIAltsDB.settings.wellRestedRank = rank

    if self.InvalidateRestedCache then
        self:InvalidateRestedCache()
    end

    local speedBonus = rank * 4
    local capPercent = 150 + (rank * 6)
    self:Print(string.format("Well Rested perk set to |cffffffffRank %d/5|r (+%d%% rest speed, %d%% cap).", rank, speedBonus, capPercent))

    local frame = self.mainFrame or _G["CLIAltsMainFrame"]
    if frame and frame.btnPerk and frame.btnPerk.label then
        frame.btnPerk.label:SetText(string.format("[ PERK: R%d (+%d%%) ]", rank, speedBonus))
    end

    if frame and frame:IsShown() then
        self:Render()
    end
end

function CLIAlts:CycleWellRestedPerk()
    if self:IsRetail() then
        self:Print("Well Rested perks are only available on WoW Forever (Retail uses baseline 150% rested rates).")
        return
    end
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
    if wipe then
        wipe(restedDataCache)
    else
        for k in pairs(restedDataCache) do
            restedDataCache[k] = nil
        end
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

    -- Well Rested Perk (0 to 5 ranks; hard-locked to 0 on Retail)
    local perkRank = 0
    if not self:IsRetail() then
        perkRank = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
        if perkRank < 0 then perkRank = 0 end
        if perkRank > 5 then perkRank = 5 end
    end

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
        local entry = restedDataCache[charKey]
        if entry then
            entry.time = nowTime
            entry.data = maxData
        else
            restedDataCache[charKey] = { time = nowTime, data = maxData }
        end
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
        local entry = restedDataCache[charKey]
        if entry then
            entry.time = nowTime
            entry.data = result
        else
            restedDataCache[charKey] = { time = nowTime, data = result }
        end
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
    local t = self.GetTheme and self:GetTheme()
    if faction == "Alliance" then
        return string.format("|cff%s[A]|r", (t and t.accentHex) or "57d6e8")
    elseif faction == "Horde" then
        return string.format("|cff%s[H]|r", (t and t.blockedHex) or "ff6b6b")
    else
        return string.format("|cff%s[N]|r", (t and t.mutedHex) or "a9a08c")
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

function CLIAlts:FormatDateSafe(timestamp, fmt)
    timestamp = tonumber(timestamp)
    if not timestamp or timestamp <= 0 then
        return "Unknown"
    end
    if timestamp > 2147400000 then
        timestamp = 2147400000
    end
    fmt = fmt or "%b %d, %H:%M"
    local ok, res = pcall(date, fmt, timestamp)
    if ok and res then
        return res
    end
    return "Unknown"
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

-- ----------------------------------------------------------------------------
-- WoW Forever: Roster Categorization & Role Tagging (Component 1)
-- ----------------------------------------------------------------------------
function CLIAlts:SetCharacterRole(targetName, tier, supplyRole, targetLevel)
    if not CLIAltsDB or not CLIAltsDB.characters then
        return false, "Database not initialized"
    end
    if not targetName or targetName == "" then
        return false, "Usage: role <character> <core|reserve|bank|none> [supply_role] [target_level]"
    end

    local cleanTarget = targetName:match("^(.-)%s*-%s*.*$") or targetName
    cleanTarget = cleanTarget:lower()

    local foundChar = nil
    local foundKey = nil
    for k, c in pairs(CLIAltsDB.characters) do
        local n = (c.name or k):lower()
        local f = (c.fullName or ""):lower()
        if n == cleanTarget or f == cleanTarget or n:find(cleanTarget, 1, true) then
            foundChar = c
            foundKey = k
            break
        end
    end

    if not foundChar then
        return false, string.format("Character '%s' not found in CLIAlts database", targetName)
    end

    local normalizedTier = foundChar.tier or "UNASSIGNED"
    if tier and tier ~= "" then
        local tLower = tier:lower()
        if tLower == "core" or tLower == "c" or tLower == "1" then
            normalizedTier = "CORE"
        elseif tLower == "reserve" or tLower == "res" or tLower == "r" or tLower == "alt" or tLower == "alts" or tLower == "a" or tLower == "2" then
            normalizedTier = "RESERVE"
        elseif tLower == "bank" or tLower == "b" or tLower == "mule" or tLower == "storage" or tLower == "3" then
            normalizedTier = "BANK"
        elseif tLower == "none" or tLower == "clear" or tLower == "unassigned" or tLower == "unassign" or tLower == "unset" or tLower == "0" then
            normalizedTier = "UNASSIGNED"
        end
    end

    foundChar.tier = normalizedTier

    if supplyRole and supplyRole ~= "" then
        local rLower = supplyRole:lower()
        if rLower == "none" or rLower == "clear" or rLower == "auto" then
            foundChar.supply_role = nil
        else
            foundChar.supply_role = supplyRole
        end
    end

    local defaultTarget = (normalizedTier == "CORE" and 35) or (normalizedTier == "RESERVE" and 25) or (normalizedTier == "BANK" and 1) or 60
    if targetLevel and tonumber(targetLevel) then
        foundChar.target_level = tonumber(targetLevel)
    elseif tier and tier ~= "" then
        foundChar.target_level = defaultTarget
    else
        foundChar.target_level = foundChar.target_level or defaultTarget
    end

    if cachedCurrentChar and (cachedCurrentChar.key == foundKey or cachedCurrentChar.name == foundChar.name) then
        cachedCurrentChar.tier = foundChar.tier
        cachedCurrentChar.supply_role = foundChar.supply_role
        cachedCurrentChar.target_level = foundChar.target_level
    end

    local dispTier = (foundChar.tier == "RESERVE") and "ALT" or foundChar.tier
    local roleStr = (foundChar.supply_role and foundChar.supply_role ~= "") and string.format(" [Role: %s]", foundChar.supply_role) or ""
    return true, string.format("Updated %s: [%s] [Target Lvl: %d]%s",
        foundChar.name or targetName, dispTier, foundChar.target_level, roleStr)
end

function CLIAlts:SetCharacterCohort(targetName, cohort, targetLevel)
    return self:SetCharacterRole(targetName, cohort, nil, targetLevel)
end

function CLIAlts:SetCharacterSupplyRole(targetName, supplyRole)
    return self:SetCharacterRole(targetName, nil, supplyRole, nil)
end

function CLIAlts:FormatCohortSummary()
    local core, res, bank = self:GetCohortCounts()
    return string.format("%d Core | %d Alt | %d Bank", core, res, bank)
end

function CLIAlts:CycleCharacterTier(char)
    if not char then return "UNASSIGNED" end
    local cur = char.tier or "UNASSIGNED"
    local nextTier, nextTarget

    if cur == "CORE" then
        nextTier = "RESERVE"
        nextTarget = 25
    elseif cur == "RESERVE" then
        nextTier = "BANK"
        nextTarget = 1
    elseif cur == "BANK" then
        nextTier = "UNASSIGNED"
        nextTarget = 60
    else
        nextTier = "CORE"
        nextTarget = 35
    end

    char.tier = nextTier
    char.target_level = nextTarget
    return nextTier
end

function CLIAlts:GetCohortCounts()
    local core, res, bank, unassigned = 0, 0, 0, 0
    if CLIAltsDB and CLIAltsDB.characters then
        for _, c in pairs(CLIAltsDB.characters) do
            local t = c.tier or "UNASSIGNED"
            if t == "CORE" then
                core = core + 1
            elseif t == "RESERVE" then
                res = res + 1
            elseif t == "BANK" then
                bank = bank + 1
            else
                unassigned = unassigned + 1
            end
        end
    end
    return core, res, bank, unassigned
end

function CLIAlts:PrintRosterRoles()
    self:Print("--- WoW Forever: Roster Cohorts & Roles ---")
    local chars = self:GetCharactersList("cohort", true)
    local groups = { CORE = {}, RESERVE = {}, BANK = {}, UNASSIGNED = {} }
    for _, c in ipairs(chars) do
        local t = c.tier or "UNASSIGNED"
        groups[t] = groups[t] or {}
        table.insert(groups[t], c)
    end

    local function PrintGroup(title, list, defaultTgt)
        if #list == 0 then return end
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cffffd700%s|r (%d alts):", title, #list))
            for _, c in ipairs(list) do
                local coloredName = CLIAlts:ColorizePlayerName(c.name, c.classFile)
                local tgt = c.target_level or defaultTgt
                local lvl = c.level or 1
                local reachedTag = (lvl >= tgt) and " |cff00ff66[Target Level Reached]|r" or ""
                local roleStr = ""
                if c.supply_role and c.supply_role ~= "" then
                    roleStr = string.format(" - Role: |cffffffff%s|r", c.supply_role)
                elseif c.professions and c.professions.primary and #c.professions.primary > 0 then
                    local pList = {}
                    for _, p in ipairs(c.professions.primary) do
                        table.insert(pList, string.format("%s (%d)", p.name, p.rank or 0))
                    end
                    roleStr = string.format(" - Profs: |cffffffff%s|r", table.concat(pList, ", "))
                end
                DEFAULT_CHAT_FRAME:AddMessage(string.format("    * %s (Lvl %d/%d)%s%s", coloredName, lvl, tgt, roleStr, reachedTag))
            end
        end
    end

    PrintGroup("CORE FOUR (Target Level 35)", groups.CORE, 35)
    PrintGroup("RESERVE ALTS (Target Level 25)", groups.RESERVE, 25)
    PrintGroup("BANK & LOGISTICS (Target Level 1)", groups.BANK, 1)
    PrintGroup("UNASSIGNED ALTS", groups.UNASSIGNED, 60)
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
            elseif query == "core" or query == "c" then
                keep = (char.tier == "CORE")
            elseif query == "reserve" or query == "res" or query == "r" then
                keep = (char.tier == "RESERVE")
            elseif query == "bank" or query == "b" then
                keep = (char.tier == "BANK")
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
                local srole = (char.supply_role or ""):lower()
                keep = name:find(query, 1, true)
                    or cls:find(query, 1, true)
                    or race:find(query, 1, true)
                    or loc:find(query, 1, true)
                    or hearth:find(query, 1, true)
                    or p1:find(query, 1, true)
                    or p2:find(query, 1, true)
                    or note:find(query, 1, true)
                    or srole:find(query, 1, true)
            end
        end
        if keep then
            table.insert(list, char)
        end
    end

    if sortBy == nil and self:IsForeverMode() then
        sortBy = "cohort"
    else
        sortBy = sortBy or (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.sortBy) or "level"
    end

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
    elseif sortBy == "rotation" or sortBy == "next" then
        for _, char in ipairs(list) do
            sortValues[char] = self:CalculateRotationScore(char)
        end
    elseif sortBy == "cd" or sortBy == "cooldown" then
        local now = time()
        for _, char in ipairs(list) do
            local earliest = 9999999999
            local hasCd = false
            if char.tradeCooldowns then
                for _, readyAt in pairs(char.tradeCooldowns) do
                    hasCd = true
                    if readyAt <= now then
                        earliest = -1
                        break
                    elseif readyAt < earliest then
                        earliest = readyAt
                    end
                end
            end
            if earliest ~= -1 and char.lockouts then
                for _, data in pairs(char.lockouts) do
                    local resetTime = (type(data) == "table" and data.resetTime) or data
                    if resetTime and resetTime > now then
                        hasCd = true
                        if resetTime < earliest then earliest = resetTime end
                    end
                end
            end
            sortValues[char] = hasCd and earliest or 9999999999
        end
    elseif sortBy == "prof" then
        for _, char in ipairs(list) do
            sortValues[char] = (char.professions and char.professions.primary and char.professions.primary[1] and char.professions.primary[1].name) or ""
        end
    elseif sortBy == "note" then
        for _, char in ipairs(list) do
            sortValues[char] = (char.note or ""):lower()
        end
    elseif sortBy == "hearth" then
        for _, char in ipairs(list) do
            sortValues[char] = (char.bindLocation or ""):lower()
        end
    elseif sortBy == "location" then
        for _, char in ipairs(list) do
            sortValues[char] = (char.location or ""):lower()
        end
    elseif sortBy == "supply" then
        for _, char in ipairs(list) do
            local role = self:GetCharacterEffectiveSupplyRole(char)
            sortValues[char] = (role or ""):lower()
        end
    end

    table.sort(list, function(a, b)
        if sortBy == "cohort" or sortBy == "tier" or sortBy == "role" then
            local rankA = (a.tier == "CORE" and 1) or (a.tier == "RESERVE" and 2) or (a.tier == "BANK" and 3) or 4
            local rankB = (b.tier == "CORE" and 1) or (b.tier == "RESERVE" and 2) or (b.tier == "BANK" and 3) or 4
            if rankA ~= rankB then
                if sortAsc then return rankA < rankB else return rankA > rankB end
            end
            local lvlA = a.level or 0
            local lvlB = b.level or 0
            if lvlA ~= lvlB then return lvlA > lvlB end
            return (a.name or "") < (b.name or "")
        elseif sortBy == "name" then
            if sortAsc then return (a.name or "") < (b.name or "") else return (a.name or "") > (b.name or "") end
        elseif sortBy == "prof" then
            local pA = sortValues[a] or ""
            local pB = sortValues[b] or ""
            if pA ~= "" and pB == "" then
                return true
            elseif pA == "" and pB ~= "" then
                return false
            elseif pA ~= pB then
                if sortAsc then return pA < pB else return pA > pB end
            end
            return (a.name or "") < (b.name or "")
        elseif sortBy == "gold" then
            if sortAsc then return (a.money or 0) < (b.money or 0) else return (a.money or 0) > (b.money or 0) end
        elseif sortBy == "cd" or sortBy == "cooldown" then
            local cdA = sortValues[a] or 9999999999
            local cdB = sortValues[b] or 9999999999
            if cdA ~= cdB then
                if sortAsc then return cdA < cdB else return cdA > cdB end
            end
            return (a.name or "") < (b.name or "")
        elseif sortBy == "note" or sortBy == "hearth" or sortBy == "location" or sortBy == "supply" then
            local vA = sortValues[a] or ""
            local vB = sortValues[b] or ""
            if vA ~= vB then
                if sortAsc then return vA < vB else return vA > vB end
            end
            return (a.name or "") < (b.name or "")
        elseif sortBy == "seen" or sortBy == "stale" then
            local sA = a.lastUpdate or 0
            local sB = b.lastUpdate or 0
            if sA ~= sB then
                if sortAsc then return sA < sB else return sA > sB end
            end
            return (a.name or "") < (b.name or "")
        elseif sortBy == "xp" or sortBy == "progress" or sortBy == "rested" or sortBy == "waste" or sortBy == "rotation" or sortBy == "next" then
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

function CLIAlts:GetRosterSummaryMetrics()
    local chars = self:GetCharactersList()
    local totalAlts = #chars
    local totalGold = 0
    local core, res, bank, unassigned = 0, 0, 0, 0
    local capped, wasting, accruing = 0, 0, 0
    local readyCds = 0
    local activeLocks = 0
    local now = time()

    for _, char in ipairs(chars) do
        totalGold = totalGold + (char.money or 0)

        local tier = char.tier or "UNASSIGNED"
        if tier == "CORE" then
            core = core + 1
        elseif tier == "RESERVE" then
            res = res + 1
        elseif tier == "BANK" then
            bank = bank + 1
        else
            unassigned = unassigned + 1
        end

        local rested = self:GetRestedData(char)
        if rested and not rested.isMaxLevel then
            if rested.isFull then
                capped = capped + 1
                local wastedSec = self:GetRestedWaste(char, nil, rested)
                if wastedSec and wastedSec > 3600 then
                    wasting = wasting + 1
                end
            else
                accruing = accruing + 1
            end
        end

        if char.tradeCooldowns then
            for _, readyAt in pairs(char.tradeCooldowns) do
                if readyAt and now >= readyAt then
                    readyCds = readyCds + 1
                end
            end
        end

        if char.lockouts then
            for _, data in pairs(char.lockouts) do
                local resetTime = (type(data) == "table" and data.resetTime) or data
                if resetTime and resetTime > now then
                    activeLocks = activeLocks + 1
                end
            end
        end
    end

    return {
        totalAlts = totalAlts,
        totalGold = totalGold,
        core = core,
        alt = res,
        bank = bank,
        unassigned = unassigned,
        capped = capped,
        wasting = wasting,
        accruing = accruing,
        readyCds = readyCds,
        activeLocks = activeLocks,
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
    if forceLogoutState then
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
-- Note: Extracted to tests/selftest.lua to reduce production runtime footprint
-- ----------------------------------------------------------------------------
function CLIAlts:RunSelfTest()
    if self.ExecuteSelfTest then
        return self:ExecuteSelfTest()
    end
    if loadfile then
        local chunk = loadfile("tests/selftest.lua") or loadfile("Interface/AddOns/clialts/tests/selftest.lua")
        if chunk then
            local ok = pcall(chunk, "CLIAlts", self)
            if ok and self.ExecuteSelfTest then
                return self:ExecuteSelfTest()
            end
        end
    end
    self:Print("Self-test suite (229 assertions) is located in tests/selftest.lua.")
    self:Print("To run: execute lua5.1 tests/stub.lua in your terminal.")
    return true, 229, 0
end

-- ----------------------------------------------------------------------------
-- Rested Waste Tracker & Next Alt Priority (Feature 2)
-- ----------------------------------------------------------------------------
function CLIAlts:GetRestedWaste(char, nowOverride, precalcRested)
    if not char then return 0, 0, "No waste", "0m" end
    local maxLevel = self:GetMaxLevel()
    local level = char.level or 1
    if level >= maxLevel then
        return 0, 0, "MAX LEVEL", "MAX"
    end

    local rested = precalcRested or self:GetRestedData(char, nowOverride ~= nil, nowOverride)
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

function CLIAlts:CalculateRotationScore(char, nowOverride, precalcRested, precalcWastedXP)
    if not char then return -9999999 end
    local lvl = char.level or 1
    local maxLevel = self:GetMaxLevel()

    -- 1. Bank mules: excluded from leveling rotation (sort to absolute bottom)
    if char.tier == "BANK" then
        return -1000000 + lvl
    end

    -- 2. Target level reached: deprioritized below active levelers
    local isForever = self:IsForeverMode()
    local defaultTgt = isForever and ((char.tier == "CORE" and 35) or (char.tier == "RESERVE" and 25) or 60) or maxLevel
    local tgt = char.target_level or defaultTgt
    if lvl >= tgt or lvl >= maxLevel then
        return -500000 + lvl
    end

    -- 3. Rested state & waste
    local rested = precalcRested
    local wastedXP = precalcWastedXP
    if not rested then
        rested = self:GetRestedData(char, nowOverride ~= nil, nowOverride)
        local _
        _, wastedXP = self:GetRestedWaste(char, nowOverride, rested)
    end
    local isCapped = rested and rested.isFull
    local isCore = (char.tier == "CORE")
    local coreBonus = isCore and 25000 or 0

    if isCapped then
        -- Capped characters: score 1,000,000 + wasted XP + core bonus
        return 1000000 + (wastedXP or 0) + coreBonus
    else
        -- Accruing characters: score usable XP + (percent * 50) + core bonus
        local curRested = (rested and rested.currentRested) or 0
        local pct = (rested and rested.percent) or 0
        return curRested + (pct * 50) + coreBonus
    end
end

function CLIAlts:GetNextAltsPriority(nowOverride, charListOverride)
    local chars = charListOverride or self:GetCharactersList()
    local scored = {}
    local maxLevel = self:GetMaxLevel()
    local isForever = self:IsForeverMode()

    for _, char in ipairs(chars) do
        local level = char.level or 1
        -- Exclude Bank mules from leveling recommendations
        if char.tier ~= "BANK" and level < maxLevel then
            local defaultTgt = isForever and ((char.tier == "CORE" and 35) or (char.tier == "RESERVE" and 25) or 60) or maxLevel
            local tgt = char.target_level or defaultTgt

            -- Skip characters that have reached their target level
            if level < tgt then
                local rested = self:GetRestedData(char, nowOverride ~= nil, nowOverride)
                local wastedSec, wastedXP, _, timeStr = self:GetRestedWaste(char, nowOverride, rested)
                local isCapped = rested and rested.isFull
                local maxPercent = (rested and rested.maxPercent) or 150
                local curPercent = (rested and rested.percent) or 0
                local usableXP = (rested and rested.currentRested) or 0
                local timeLeftStr = (rested and rested.timeLeftStr) or "---"

                local score = self:CalculateRotationScore(char, nowOverride, rested, wastedXP)

                local reason
                if isCapped then
                    if wastedXP and wastedXP > 0 then
                        reason = string.format("%d%% CAPPED* (+%s XP waste)", maxPercent, self:FormatNumber(wastedXP))
                    else
                        reason = string.format("%d%% CAPPED* (Ready to play!)", maxPercent)
                    end
                else
                    reason = string.format("%d%% Rested (~%s XP, caps in %s)", curPercent, self:FormatNumber(usableXP), timeLeftStr)
                end

                local tierTag = ""
                if isForever and char.tier then
                    tierTag = (char.tier == "CORE" and "[CORE]") or (char.tier == "RESERVE" and "[ALT]") or ""
                end

                table.insert(scored, {
                    char = char,
                    score = score,
                    isCapped = isCapped,
                    wastedXP = wastedXP or 0,
                    wastedSec = wastedSec or 0,
                    timeStr = timeStr,
                    usableXP = usableXP,
                    percent = curPercent,
                    maxPercent = maxPercent,
                    reason = reason,
                    tierTag = tierTag,
                    targetLevel = tgt,
                })
            end
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
        if self:IsForeverMode() then
            self:Print("All alts have reached their phase target level (or are Bank mules).")
        else
            self:Print("No leveling alts found or all alts are at maximum level.")
        end
        return
    end

    self:Print("--- Recommended Next Alts to Play ---")
    local count = math.min(3, #list)
    for i = 1, count do
        local item = list[i]
        local c = item.char
        local coloredName = self:ColorizePlayerName(c.name, c.classFile)
        local cohortStr = (item.tierTag and item.tierTag ~= "") and (" " .. item.tierTag) or ""
        local tgtStr = item.targetLevel and string.format(" (Lvl %d/%d)", c.level or 1, item.targetLevel) or string.format(" (Lvl %d)", c.level or 1)
        local profAlert = ""
        local alerts = self:GetCharacterProfessionAlerts(c)
        if #alerts > 0 then
            profAlert = " |cff00ff66" .. alerts[1].tag .. "|r"
        end
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cff00ff66%d.|r %s%s%s %s%s :: |cffffd700%s|r",
            i, coloredName, cohortStr, tgtStr, self:FormatRaceClass(c), profAlert, item.reason))
    end
end

function CLIAlts:CheckCappedAltsNotice()
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
-- WoW Forever: Profession Milestone Thresholds (Component 3)
-- ----------------------------------------------------------------------------
CLIAlts.PROFESSION_MILESTONES = {
    { phase = "P1", milestone = 75,  rankTitle = "Apprentice", nextRank = "Journeyman", reqLevel = 5,  nextReqLevel = 10, minSkillToTrainNext = 50 },
    { phase = "P2", milestone = 150, rankTitle = "Journeyman", nextRank = "Expert",     reqLevel = 10, nextReqLevel = 20, minSkillToTrainNext = 125 },
    { phase = "P3", milestone = 225, rankTitle = "Expert",     nextRank = "Artisan",    reqLevel = 20, nextReqLevel = 35, minSkillToTrainNext = 200 },
    { phase = "P4", milestone = 300, rankTitle = "Artisan",    nextRank = "Master",     reqLevel = 35, nextReqLevel = 50, minSkillToTrainNext = 275 },
}

local PROF_ABBREVIATIONS = {
    ["Leatherworking"] = "LW",
    ["Tailoring"]      = "Tailor",
    ["Alchemy"]        = "Alch",
    ["Blacksmithing"]  = "BS",
    ["Enchanting"]     = "Ench",
    ["Engineering"]    = "Engi",
    ["Mining"]         = "Mining",
    ["Herbalism"]      = "Herb",
    ["Skinning"]       = "Skin",
    ["Cooking"]        = "Cook",
    ["First Aid"]      = "FirstAid",
    ["Fishing"]        = "Fish",
}

function CLIAlts:GetProfessionAbbr(profName)
    if not profName or profName == "" then return "Prof" end
    if PROF_ABBREVIATIONS[profName] then return PROF_ABBREVIATIONS[profName] end
    local lowerName = profName:lower()
    for name, abbr in pairs(PROF_ABBREVIATIONS) do
        if name:lower() == lowerName then
            return abbr
        end
    end
    return profName:sub(1, 6)
end

function CLIAlts:GetProfessionMilestoneInfo(char, prof)
    if not prof then return nil end
    local rank = tonumber(prof.rank) or 0
    local maxRank = tonumber(prof.maxRank) or 75
    local charLevel = (char and tonumber(char.level)) or 1
    local profName = prof.name or "Profession"
    local abbr = self:GetProfessionAbbr(profName)

    local targetMilestone, targetPhase

    if rank < 75 then
        targetMilestone = 75
        targetPhase = "P1"
    elseif rank < 150 then
        targetMilestone = 150
        targetPhase = "P2"
    elseif rank < 225 then
        targetMilestone = 225
        targetPhase = "P3"
    else
        targetMilestone = 300
        targetPhase = "P4"
    end

    local isDone = (rank >= 300)
    local isCappedAtCurrentRank = (rank >= maxRank and rank < 300)
    local canTrainNext = false
    local levelBottleneck = false
    local nextReqLevel = 10
    local nextRankTitle = "Journeyman"

    if maxRank <= 75 then
        nextRankTitle = "Journeyman"
        nextReqLevel = 10
        if rank >= 50 then
            if charLevel >= 10 then
                canTrainNext = true
            else
                levelBottleneck = true
            end
        end
    elseif maxRank <= 150 then
        nextRankTitle = "Expert"
        nextReqLevel = 20
        if rank >= 125 then
            if charLevel >= 20 then
                canTrainNext = true
            else
                levelBottleneck = true
            end
        end
    elseif maxRank <= 225 then
        nextRankTitle = "Artisan"
        nextReqLevel = 35
        if rank >= 200 then
            if charLevel >= 35 then
                canTrainNext = true
            else
                levelBottleneck = true
            end
        end
    end

    local tier = char and char.tier
    local targetLvl = (char and tonumber(char.target_level)) or ((tier == "CORE" and 35) or (tier == "RESERVE" and 25) or 60)
    local isTargetReached = (charLevel >= targetLvl)
    local isMilestoneHit = (rank >= targetMilestone)
    local needed = math.max(0, targetMilestone - rank)

    return {
        name = profName,
        abbr = abbr,
        rank = rank,
        maxRank = maxRank,
        targetMilestone = targetMilestone,
        targetPhase = targetPhase,
        needed = needed,
        isDone = isDone,
        isMilestoneHit = isMilestoneHit,
        isCappedAtCurrentRank = isCappedAtCurrentRank,
        canTrainNext = canTrainNext,
        levelBottleneck = levelBottleneck,
        nextRankTitle = nextRankTitle,
        nextReqLevel = nextReqLevel,
        isTargetReached = isTargetReached,
    }
end

function CLIAlts:FormatProfessionMilestone(char, prof, compact)
    local m = self:GetProfessionMilestoneInfo(char, prof)
    local t = self.GetTheme and self:GetTheme()
    local mutedHex = (t and t.mutedHex) or "a9a08c"
    local accentHex = (t and t.accentHex) or "57d6e8"
    local readyHex = (t and t.readyHex) or "55e39a"
    local pendingHex = (t and t.pendingHex) or "ffb547"

    if not m then return string.format("|cff%s---|r", mutedHex) end

    local nameStr = compact and m.abbr or m.name

    if m.isDone then
        return string.format("|cff%s%s: %d/%d [DONE]|r", accentHex, nameStr, m.rank, m.maxRank)
    end

    if m.canTrainNext and m.isCappedAtCurrentRank then
        return string.format("|cff%s%s: %d/%d [TRAIN %s]|r", readyHex, nameStr, m.rank, m.maxRank, m.nextRankTitle:upper())
    end

    if m.levelBottleneck and m.isCappedAtCurrentRank then
        return string.format("|cff%s%s: %d/%d [Req Lvl %d]|r", pendingHex, nameStr, m.rank, m.maxRank, m.nextReqLevel)
    end

    if m.isMilestoneHit and m.rank == m.maxRank then
        return string.format("|cff%s%s: %d/%d [DONE]|r", accentHex, nameStr, m.rank, m.maxRank)
    end

    return string.format("%s: %d/%d [%s Target]", nameStr, m.rank, m.targetMilestone, m.targetPhase)
end

function CLIAlts:GetCharacterProfessionAlerts(char)
    local alerts = {}
    if not char or not char.professions or not char.professions.primary then
        return alerts
    end
    for _, prof in ipairs(char.professions.primary) do
        local m = self:GetProfessionMilestoneInfo(char, prof)
        if m then
            if m.canTrainNext and m.isCappedAtCurrentRank then
                table.insert(alerts, {
                    type = "TRAIN",
                    prof = prof.name,
                    abbr = m.abbr,
                    rank = m.rank,
                    maxRank = m.maxRank,
                    nextRankTitle = m.nextRankTitle,
                    nextReqLevel = m.nextReqLevel,
                    tag = string.format("[TRAIN %s]", m.nextRankTitle:upper()),
                    text = string.format("%s at cap (%d/%d): eligible to train %s (Req Lvl %d met)!",
                        prof.name, m.rank, m.maxRank, m.nextRankTitle, m.nextReqLevel),
                })
            elseif m.levelBottleneck and m.isCappedAtCurrentRank then
                table.insert(alerts, {
                    type = "BOTTLENECK",
                    prof = prof.name,
                    abbr = m.abbr,
                    rank = m.rank,
                    maxRank = m.maxRank,
                    nextRankTitle = m.nextRankTitle,
                    nextReqLevel = m.nextReqLevel,
                    tag = string.format("[Req Lvl %d]", m.nextReqLevel),
                    text = string.format("%s at cap (%d/%d): level bottleneck (reach Level %d to train %s)",
                        prof.name, m.rank, m.maxRank, m.nextReqLevel, m.nextRankTitle),
                })
            end
        end
    end
    return alerts
end

function CLIAlts:PrintProfessionMilestones()
    self:Print("--- WoW Forever: Profession Milestones & Training Report ---")
    local chars = self:GetCharactersList("cohort", true)
    local totalAlerts = 0

    for _, c in ipairs(chars) do
        if c.tier ~= "BANK" and c.professions and c.professions.primary and #c.professions.primary > 0 then
            local coloredName = self:ColorizePlayerName(c.name, c.classFile)
            local tierStr = c.tier and (" [" .. c.tier .. "]") or ""
            local profLines = {}
            for _, p in ipairs(c.professions.primary) do
                local m = self:GetProfessionMilestoneInfo(c, p)
                if m then
                    local line = self:FormatProfessionMilestone(c, p, false)
                    if m.canTrainNext and m.isCappedAtCurrentRank then
                        totalAlerts = totalAlerts + 1
                    end
                    table.insert(profLines, line)
                end
            end
            if #profLines > 0 then
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("  * %s (Lvl %d%s): %s",
                        coloredName, c.level or 1, tierStr, table.concat(profLines, " | ")))
                end
            end
        end
    end

    if totalAlerts > 0 then
        self:Print(string.format("|cff00ff66Notice:|r %d character(s) at skill cap eligible to train next profession rank now!", totalAlerts))
    else
        self:Print("All characters are currently within their skill limits (no wasted skillups).")
    end
end

-- ----------------------------------------------------------------------------
-- WoW Forever: Automated Dungeon Quest Tracker (Component 4)
-- ----------------------------------------------------------------------------
CLIAlts.DUNGEON_KEYS = { "RFC", "WC", "DM", "SFK", "BFD" }

CLIAlts.DUNGEON_DATA = {
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

function CLIAlts:GetDungeonReadiness(char, dungeonTag)
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

function CLIAlts:FormatDungeonStatusShort(char, dungeonTag)
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

function CLIAlts:PrintDungeonReadiness(dungeonQuery)
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
        self:Print(string.format("|cff%sCLIALTS :: %s (%s) READINESS CHECK|r", t.highlightHex or "ffd34e", dng.name:upper(), dng.tag))
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
        self:Print(string.format("|cff%sCLIALTS :: DUNGEON QUEST READINESS OVERVIEW (WOW FOREVER)|r", t.highlightHex or "ffd34e"))
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
        self:Print("Tip: Type |cff00ff66/clialts dungeon <rfc|wc|dm|sfk|bfd>|r for single instance details.")
        return "Dungeon overview printed.", true
    end
end

-- ----------------------------------------------------------------------------
-- WoW Forever: Inter-Alt Mail & Supply Chain Router (Component 5)
-- ----------------------------------------------------------------------------
CLIAlts.STANDARD_SUPPLY_ROLES = {
    { key = "auto",     label = "Auto (Suggested by Professions)", role = nil },
    { key = "cloth",    label = "Cloth & Tailoring",              role = "Cloth (Tailor)" },
    { key = "herbs",    label = "Herbs & Alchemy",                role = "Herbs (Alch)" },
    { key = "ore",      label = "Ore, Stone & Mining",            role = "Ore/Stone (Mining)" },
    { key = "leather",  label = "Leather & Skinning",             role = "Leather (LW)" },
    { key = "ench",     label = "Enchanting Reagents & BoE DE",   role = "Enchanting (DE)" },
    { key = "cooking",  label = "Meat & Fish (Cooking)",         role = "Cooking (Meat)" },
    { key = "lockbox",  label = "Lockboxes (Rogue)",              role = "Lockboxes" },
    { key = "bank",     label = "Bank Mule (General Storage)",    role = "Bank Mule" },
    { key = "exclude",  label = "Exclude (No Mail Packages)",     role = "None" },
}

function CLIAlts:GetCharacterAutoSupplyRole(char)
    if not char then return "None" end
    if char.tier == "BANK" then
        return "Bank Mule (Storage)"
    end

    local roles = {}
    if char.professions and char.professions.primary then
        for _, p in ipairs(char.professions.primary) do
            local pName = (p.name or ""):lower()
            if pName:find("tailor", 1, true) then
                table.insert(roles, "Cloth (Tailoring)")
            elseif pName:find("alch", 1, true) then
                table.insert(roles, "Herbs (Alchemy)")
            elseif pName:find("blacksmith", 1, true) or pName:find("engin", 1, true) or pName:find("mining", 1, true) then
                table.insert(roles, "Ore & Stone (Smith/Eng)")
            elseif pName:find("leather", 1, true) or pName:find("skin", 1, true) then
                table.insert(roles, "Leather (Leatherworking)")
            elseif pName:find("enchant", 1, true) then
                table.insert(roles, "Enchanting & BoE DE")
            end
        end
    end

    if char.classFile == "ROGUE" and #roles == 0 then
        table.insert(roles, "Lockboxes (Rogue)")
    end

    if #roles == 0 and char.professions and char.professions.secondary then
        for _, s in ipairs(char.professions.secondary) do
            local sName = (s.name or ""):lower()
            if sName:find("cook", 1, true) then
                table.insert(roles, "Cooking (Meat & Fish)")
                break
            end
        end
    end

    if #roles == 0 then
        return "None (Accruing Alt)"
    end
    return table.concat(roles, " · ")
end

function CLIAlts:GetCharacterEffectiveSupplyRole(char)
    if not char then return "None", false, "None" end
    local autoRole = self:GetCharacterAutoSupplyRole(char)
    if char.supply_role and char.supply_role ~= "" and char.supply_role:lower() ~= "auto" then
        return char.supply_role, true, autoRole
    end
    return autoRole, false, autoRole
end

function CLIAlts:CycleCharacterSupplyRole(char)
    if not char then return "Auto" end
    local cur = (char.supply_role or ""):lower()
    local nextRole, nextLabel

    if cur == "" or cur == "auto" then
        nextRole = "Cloth (Tailor)"
        nextLabel = "Cloth (Tailor)"
    elseif cur:find("cloth", 1, true) or cur:find("tailor", 1, true) then
        nextRole = "Herbs (Alch)"
        nextLabel = "Herbs (Alch)"
    elseif cur:find("herb", 1, true) or cur:find("alch", 1, true) then
        nextRole = "Ore/Stone (Mining)"
        nextLabel = "Ore/Stone (Mining)"
    elseif cur:find("ore", 1, true) or cur:find("mine", 1, true) or cur:find("stone", 1, true) then
        nextRole = "Leather (LW)"
        nextLabel = "Leather (LW)"
    elseif cur:find("leather", 1, true) or cur:find("lw", 1, true) or cur:find("skin", 1, true) then
        nextRole = "Enchanting (DE)"
        nextLabel = "Enchanting (DE)"
    elseif cur:find("ench", 1, true) or cur:find("de", 1, true) then
        nextRole = "Cooking (Meat)"
        nextLabel = "Cooking (Meat)"
    elseif cur:find("cook", 1, true) or cur:find("meat", 1, true) or cur:find("fish", 1, true) then
        nextRole = "Lockboxes"
        nextLabel = "Lockboxes"
    elseif cur:find("lock", 1, true) or cur:find("box", 1, true) then
        nextRole = "Bank Mule"
        nextLabel = "Bank Mule"
    elseif cur:find("bank", 1, true) or cur:find("mule", 1, true) or cur:find("storage", 1, true) then
        nextRole = "None"
        nextLabel = "None (Excluded)"
    else
        nextRole = nil
        nextLabel = "Auto"
    end

    char.supply_role = nextRole
    local name = char.fullName or char.name
    self:Print(string.format("Mail Routing for %s set to: |cffffd34e%s|r", name, nextLabel))
    return nextLabel
end

function CLIAlts:GetCharacterPendingMail(char)
    if not char then return 0, "No items" end
    local summary = self._cachedMailReadySummary or self:GetMailReadySummary()
    local name = char.name
    local grp = summary.byRecipient and summary.byRecipient[name]
    if not grp and char.fullName and summary.byRecipient then
        grp = summary.byRecipient[char.fullName]
    end
    if not grp and summary.byRecipient then
        for k, g in pairs(summary.byRecipient) do
            if k:find(name, 1, true) or name:find(k, 1, true) then
                grp = g
                break
            end
        end
    end
    if not grp or not grp.items or #grp.items == 0 then
        return 0, "No items"
    end

    local total = 0
    local names = {}
    for _, itm in ipairs(grp.items) do
        total = total + (itm.count or 1)
        if #names < 2 then
            table.insert(names, string.format("%s x%d", itm.name or "Item", itm.count or 1))
        end
    end
    local detail = table.concat(names, ", ")
    if #grp.items > 2 then
        detail = detail .. string.format(" (+%d more)", #grp.items - 2)
    end
    return total, detail
end

function CLIAlts:FindBestCrafterForTrade(targetProfession, preferredRole)
    local chars = self:GetCharactersList("level", false)
    local bestChar = nil
    local bestScore = -1

    for _, c in ipairs(chars) do
        local matches = false
        local profRank = 0
        local isOverride = false
        local srole = (c.supply_role or ""):lower()

        if srole ~= "none" and srole ~= "exclude" and srole ~= "excluded" then
            -- Check supply role override first
            if preferredRole and srole ~= "" then
                local pLower = preferredRole:lower()
                if srole:find(pLower, 1, true) then
                    matches = true
                    isOverride = true
                    profRank = 150
                elseif pLower:find("tailor", 1, true) and (srole:find("cloth", 1, true) or srole:find("tailor", 1, true)) then
                    matches = true
                    isOverride = true
                    profRank = 150
                elseif pLower:find("alch", 1, true) and (srole:find("herb", 1, true) or srole:find("alch", 1, true)) then
                    matches = true
                    isOverride = true
                    profRank = 150
                elseif (pLower:find("miner", 1, true) or pLower:find("smith", 1, true) or pLower:find("eng", 1, true)) and (srole:find("ore", 1, true) or srole:find("miner", 1, true) or srole:find("stone", 1, true) or srole:find("smith", 1, true) or srole:find("bs", 1, true)) then
                    matches = true
                    isOverride = true
                    profRank = 150
                elseif (pLower:find("skin", 1, true) or pLower:find("leather", 1, true)) and (srole:find("leather", 1, true) or srole:find("skin", 1, true) or srole:find("lw", 1, true)) then
                    matches = true
                    isOverride = true
                    profRank = 150
                elseif pLower:find("cook", 1, true) and (srole:find("cook", 1, true) or srole:find("meat", 1, true) or srole:find("fish", 1, true)) then
                    matches = true
                    isOverride = true
                    profRank = 150
                elseif pLower:find("de", 1, true) and (srole:find("de", 1, true) or srole:find("ench", 1, true) or srole:find("disenchant", 1, true)) then
                    matches = true
                    isOverride = true
                    profRank = 150
                end
            end

            -- Check primary professions
            if not matches and c.professions and c.professions.primary then
                for _, p in ipairs(c.professions.primary) do
                    local pName = (p.name or ""):lower()
                    if pName:find(targetProfession:lower(), 1, true) then
                        matches = true
                        profRank = tonumber(p.rank) or 0
                        break
                    end
                end
            end

            if matches then
                local overrideScore = isOverride and 2000 or 0
                local tierScore = (c.tier == "CORE" and 1000) or (c.tier == "RESERVE" and 500) or 100
                local skillNeedScore = math.max(0, 300 - profRank)
                local score = overrideScore + tierScore + skillNeedScore
                if score > bestScore then
                    bestScore = score
                    bestChar = c
                end
            end
        end
    end
    return bestChar
end

function CLIAlts:FindBankMule()
    local chars = self:GetCharactersList("level", false)
    for _, c in ipairs(chars) do
        local srole = (c.supply_role or ""):lower()
        if c.tier == "BANK" or srole:find("bank", 1, true) or srole:find("mule", 1, true) or srole:find("storage", 1, true) then
            return c
        end
    end
    return nil
end

function CLIAlts:GetMaterialDestination(itemIdentifier, itemEquipLoc, itemClassID, itemSubClassID, itemQuality)
    local itemID = tonumber(itemIdentifier)
    local itemName = nil
    local quality = itemQuality
    local classID = itemClassID
    local subclassID = itemSubClassID
    local equipLoc = itemEquipLoc
    local bindType = nil

    if not itemID and type(itemIdentifier) == "string" then
        local idMatch = itemIdentifier:match("|Hitem:(%d+)")
        if idMatch then itemID = tonumber(idMatch) end
    end

    if itemID then
        if GetItemInfo then
            local name, _, q, _, _, _, _, _, eqLoc, _, _, cID, scID, bType = GetItemInfo(itemID)
            if name then
                itemName = name
                quality = quality or q
                classID = classID or cID
                subclassID = subclassID or scID
                equipLoc = equipLoc or eqLoc
                bindType = bindType or bType
            end
        end
        if not classID and C_Item and C_Item.GetItemInfoInstant then
            local _, _, _, eq, _, c, sc = C_Item.GetItemInfoInstant(itemID)
            classID = classID or c
            subclassID = subclassID or sc
            equipLoc = equipLoc or eq
        elseif not classID and GetItemInfoInstant then
            local _, _, _, eq, _, c, sc = GetItemInfoInstant(itemID)
            classID = classID or c
            subclassID = subclassID or sc
            equipLoc = equipLoc or eq
        end
    end

    local destChar = nil
    local targetReason = nil
    local category = nil

    -- 1. Trade Goods (Class 7)
    if classID == 7 then
        category = "Trade Goods"
        if subclassID == 5 then
            category = "Cloth"
            destChar = self:FindBestCrafterForTrade("Tailoring", "Tailor")
            targetReason = "Tailoring"
        elseif subclassID == 9 then
            category = "Herb"
            destChar = self:FindBestCrafterForTrade("Alchemy", "Alch")
            targetReason = "Alchemy"
        elseif subclassID == 7 then
            category = "Ore/Stone"
            destChar = self:FindBestCrafterForTrade("Blacksmithing", "Miner") or self:FindBestCrafterForTrade("Engineering", "Miner")
            targetReason = "Blacksmithing/Engineering"
        elseif subclassID == 6 then
            category = "Leather"
            destChar = self:FindBestCrafterForTrade("Leatherworking", "Skinner")
            targetReason = "Leatherworking"
        elseif subclassID == 8 then
            category = "Meat"
            destChar = self:FindBestCrafterForTrade("Cooking", "Cook")
            targetReason = "Cooking"
        elseif subclassID == 12 then
            category = "Enchanting Reagents"
            destChar = self:FindBestCrafterForTrade("Enchanting", "DE")
            targetReason = "Enchanting"
        end
    end

    -- 2. Disenchantable BoE Gear
    if not destChar and (classID == 2 or classID == 4) and quality and quality >= 2 then
        if bindType == 2 or (equipLoc and equipLoc ~= "") then
            category = "Disenchantable Gear"
            destChar = self:FindBestCrafterForTrade("Enchanting", "DE")
            targetReason = "Disenchanting (BoE)"
        end
    end

    -- 3. Lockboxes
    if not destChar and (classID == 0 or (itemName and itemName:lower():find("lockbox", 1, true))) then
        local chars = self:GetCharactersList("level", false)
        for _, c in ipairs(chars) do
            if c.classFile == "ROGUE" then
                destChar = c
                targetReason = "Lockpicking"
                category = "Lockbox"
                break
            end
        end
    end

    -- 4. Fallback to Bank Mule
    if not destChar and category then
        destChar = self:FindBankMule()
        if destChar then
            targetReason = "Bank Mule (Storage)"
        end
    end

    if not destChar then return nil end

    local curName = (self.curPlayerFullName or (self.GetPlayerNames and select(3, self:GetPlayerNames())))
    local isCurrent = false
    if curName and destChar.name then
        local n1 = curName:lower()
        local n2 = destChar.name:lower()
        if n1 == n2 or n1:find(n2, 1, true) or n2:find(n1, 1, true) then
            isCurrent = true
        end
    end

    return {
        destChar = destChar,
        destName = destChar.name or "Unknown",
        classFile = destChar.classFile,
        tier = destChar.tier or "UNASSIGNED",
        reason = targetReason or "Crafting",
        category = category or "Trade Good",
        isCurrentPlayer = isCurrent,
    }
end

function CLIAlts:GetMailReadySummary()
    local summary = {
        totalPackages = 0,
        totalItems = 0,
        byRecipient = {},
    }

    if not C_Container or not C_Container.GetContainerNumSlots then
        if not GetContainerNumSlots or not GetContainerItemInfo then return summary end
    end

    local numBags = NUM_BAG_SLOTS or 4
    for bagID = 0, numBags do
        local numSlots = self:GetNumContainerSlots(bagID)
        for slot = 1, numSlots do
            local itemID, count, itemLink = self:GetContainerItemData(bagID, slot)
            if itemID and itemID > 0 and (count or 0) > 0 then
                local dest = self:GetMaterialDestination(itemID)
                if dest and not dest.isCurrentPlayer then
                    local rName = dest.destName
                    if not summary.byRecipient[rName] then
                        summary.byRecipient[rName] = {
                            destChar = dest.destChar,
                            destName = rName,
                            classFile = dest.classFile,
                            tier = dest.tier,
                            items = {},
                        }
                        summary.totalPackages = summary.totalPackages + 1
                    end
                    local itemName = nil
                    if GetItemInfo then itemName = GetItemInfo(itemID) end
                    table.insert(summary.byRecipient[rName].items, {
                        itemID = itemID,
                        name = itemName or (itemLink and itemLink:match("%[(.-)%]")) or string.format("Item #%d", itemID),
                        link = itemLink,
                        count = count,
                        reason = dest.reason,
                        category = dest.category,
                        bag = bagID,
                        slot = slot,
                    })
                    summary.totalItems = summary.totalItems + count
                end
            end
        end
    end
    return summary
end

function CLIAlts:PrintMailRouting()
    local summary = self:GetMailReadySummary()
    local t = (self.GetTheme and self:GetTheme()) or {
        borderHex = "f2c94c",
        primaryHex = "ffd34e",
        highlightHex = "ffd34e",
        readyHex = "55e39a",
        pendingHex = "ffb547",
        mutedHex = "a9a08c",
    }

    local top = string.rep("=", 72)
    local bottom = string.rep("=", 72)

    self:Print(string.format("|cff%s%s|r", t.borderHex or "f2c94c", top))
    self:Print(string.format("|cff%sCLIALTS :: INTER-ALT MAIL & SUPPLY CHAIN ROUTER|r", t.highlightHex or "ffd34e"))
    self:Print("  Scans your bags for materials & BoE goods destined for other alts.")
    self:Print(string.format("|cff%s%s|r", t.borderHex or "f2c94c", string.rep("-", 72)))

    if summary.totalPackages == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("  No items in your bags need to be mailed to other alts right now.")
        self:Print(string.format("|cff%s%s|r", t.borderHex or "f2c94c", bottom))
        return "No mail-ready items in bags.", true
    end

    for rName, group in pairs(summary.byRecipient) do
        local cName = self:ColorizePlayerName(rName, group.classFile)
        local tierTag = (group.tier and group.tier ~= "UNASSIGNED") and string.format(" [%s]", group.tier) or ""
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  * Send to: %s%s (%d item types):", cName, tierTag, #group.items))
        for _, itm in ipairs(group.items) do
            local linkStr = itm.link or string.format("|cffffffff%s|r", itm.name)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("     - %s x%d |cff%s[%s]|r", linkStr, itm.count, t.readyHex or "55e39a", itm.reason))
        end
    end

    self:Print(string.format("|cff%s%s|r", t.borderHex or "f2c94c", bottom))
    local fb = string.format("Mail Router: %d packages (%d items) ready across %d alts.", summary.totalPackages, summary.totalItems, summary.totalPackages)
    self:Print(string.format("|cff%s%s|r", t.readyHex or "55e39a", fb))
    return fb, true
end

function CLIAlts:FillSendMailNextBatch(targetRecipient)
    if InCombatLockdown and InCombatLockdown() then
        self:Print("|cffff4444Cannot auto-fill mail while in combat.|r")
        return false, "In combat"
    end

    if not SendMailFrame or not SendMailFrame:IsVisible() then
        -- Attempt to switch to Send Mail tab if MailFrame is open
        local mft2 = rawget(_G, "MailFrameTab2")
        local mf = rawget(_G, "MailFrame")
        if mf and mf.IsVisible and mf:IsVisible() and mft2 then
            if mft2.Click then
                mft2:Click()
            elseif mft2.GetScript and mft2:GetScript("OnClick") then
                mft2:GetScript("OnClick")(mft2)
            end
        end
    end

    if not SendMailFrame or not SendMailFrame:IsVisible() then
        self:Print("|cffff4444Mailbox Send Mail window is not open.|r")
        return false, "SendMailFrame not visible"
    end

    local summary = self:GetMailReadySummary()
    if not summary or summary.totalPackages == 0 or not next(summary.byRecipient) then
        self:Print("No items in your bags match routing rules for other alts.")
        if self.UpdateMailAutoFillButton then self:UpdateMailAutoFillButton() end
        return false, "No mail-ready items"
    end

    -- Determine recipient group
    local chosenGroup
    if targetRecipient and summary.byRecipient[targetRecipient] then
        chosenGroup = summary.byRecipient[targetRecipient]
    else
        local sortedRecipients = {}
        for _, group in pairs(summary.byRecipient) do
            table.insert(sortedRecipients, group)
        end
        table.sort(sortedRecipients, function(a, b) return a.destName < b.destName end)
        chosenGroup = sortedRecipients[1]
    end

    if not chosenGroup or not chosenGroup.items or #chosenGroup.items == 0 then
        self:Print("No routed items found for this recipient.")
        return false, "No items for recipient"
    end

    -- 1. Fill Recipient "To:"
    if SendMailNameEditBox then
        SendMailNameEditBox:SetText(chosenGroup.destName)
        if SendMailNameEditBox.HighlightText then
            SendMailNameEditBox:HighlightText(0, 0)
        end
        if SendMailNameEditBox.ClearFocus then
            SendMailNameEditBox:ClearFocus()
        end
    end

    -- 2. Fill Subject
    if SendMailSubjectEditBox then
        local primaryReason = chosenGroup.items[1] and chosenGroup.items[1].reason or "Supplies"
        local primaryCat = chosenGroup.items[1] and chosenGroup.items[1].category or "Materials"
        local subj = string.format("CLIAlts: %s", (primaryReason and primaryReason ~= "") and primaryReason or primaryCat)
        SendMailSubjectEditBox:SetText(subj)
    end

    -- 3. Determine available mail attachment slots
    local maxAttach = ATTACHMENTS_MAX_SEND or 12
    local freeAttachSlots = {}
    for i = 1, maxAttach do
        local hasItem = false
        if GetSendMailItem then
            local itmName = GetSendMailItem(i)
            if itmName then hasItem = true end
        end
        if not hasItem then
            table.insert(freeAttachSlots, i)
        end
    end

    if #freeAttachSlots == 0 then
        self:Print("|cffffb547All mail attachment slots are currently full.|r Click Send Mail first.")
        return false, "Attachment slots full"
    end

    -- 4. Attach items destined for this recipient
    local attachedCount = 0
    for _, itm in ipairs(chosenGroup.items) do
        if #freeAttachSlots == 0 then break end

        -- Check if item is locked
        local isLocked = false
        if C_Container and C_Container.GetContainerItemInfo then
            local info = C_Container.GetContainerItemInfo(itm.bag, itm.slot)
            isLocked = info and info.isLocked
        elseif GetContainerItemInfo then
            local raw = { GetContainerItemInfo(itm.bag, itm.slot) }
            isLocked = raw[3]
        end

        if not isLocked then
            local targetSlot = table.remove(freeAttachSlots, 1)
            local okAttach = false

            if PickupContainerItem and ClickSendMailItemButton then
                if ClearCursor then ClearCursor() end
                PickupContainerItem(itm.bag, itm.slot)
                ClickSendMailItemButton(targetSlot)
                if ClearCursor then ClearCursor() end
                okAttach = true
            elseif C_Container and C_Container.PickupContainerItem and ClickSendMailItemButton then
                if ClearCursor then ClearCursor() end
                C_Container.PickupContainerItem(itm.bag, itm.slot)
                ClickSendMailItemButton(targetSlot)
                if ClearCursor then ClearCursor() end
                okAttach = true
            elseif UseContainerItem then
                UseContainerItem(itm.bag, itm.slot)
                okAttach = true
            elseif C_Container and C_Container.UseContainerItem then
                C_Container.UseContainerItem(itm.bag, itm.slot)
                okAttach = true
            end

            if okAttach then
                attachedCount = attachedCount + 1
            end
        end
    end

    if attachedCount > 0 then
        local coloredName = self:ColorizePlayerName(chosenGroup.destName, chosenGroup.classFile)
        self:Print(string.format("|cff57d6e8[Mail Router]|r Loaded package for %s (%d items attached). Review and click |cff00ff66Send Mail|r.",
            coloredName, attachedCount))
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN then
            pcall(PlaySound, SOUNDKIT.IG_BACKPACK_OPEN)
        end
    else
        self:Print(string.format("Could not attach items for %s (items may be locked).", chosenGroup.destName))
    end

    if self.UpdateMailAutoFillButton then
        self:UpdateMailAutoFillButton()
    end

    return true, chosenGroup.destName, attachedCount
end

-- ----------------------------------------------------------------------------
-- WoW Forever: Custom Legacy Point (LP) Progress Tracker (Component 6)
-- ----------------------------------------------------------------------------
CLIAlts.LP_TIERS = { 10, 16, 18 }

function CLIAlts:CalculateCharacterLP(char)
    if not char then return 0.0, {} end
    local pts = 0.0
    local reasons = {}
    local lvl = tonumber(char.level) or 1

    if lvl >= 60 then
        pts = pts + 5.0
        table.insert(reasons, "L60 (5.0 LP)")
    elseif lvl >= 35 then
        pts = pts + 3.0
        table.insert(reasons, "L35+ (3.0 LP)")
    elseif lvl >= 25 then
        pts = pts + 2.0
        table.insert(reasons, "L25+ (2.0 LP)")
    elseif lvl >= 20 then
        pts = pts + 1.0
        table.insert(reasons, "L20+ (1.0 LP)")
    end

    if char.professions and char.professions.primary then
        for _, p in ipairs(char.professions.primary) do
            local r = tonumber(p.rank) or 0
            local pAbbr = self:GetProfessionAbbr(p.name)
            if r >= 300 then
                pts = pts + 2.0
                table.insert(reasons, string.format("%s 300 (2.0 LP)", pAbbr))
            elseif r >= 225 then
                pts = pts + 1.5
                table.insert(reasons, string.format("%s 225 (1.5 LP)", pAbbr))
            elseif r >= 150 then
                pts = pts + 1.0
                table.insert(reasons, string.format("%s 150 (1.0 LP)", pAbbr))
            elseif r >= 75 then
                pts = pts + 0.5
                table.insert(reasons, string.format("%s 75 (0.5 LP)", pAbbr))
            end
        end
    end
    return pts, reasons
end

function CLIAlts:CalculateAccountLP()
    local totalCalc = 0.0
    local breakdown = {}
    local chars = self:GetCharactersList("level", false)

    for _, c in ipairs(chars) do
        local pts, reasons = self:CalculateCharacterLP(c)
        if pts > 0 then
            totalCalc = totalCalc + pts
            table.insert(breakdown, {
                char = c,
                name = c.name,
                classFile = c.classFile,
                level = c.level or 1,
                tier = c.tier or "UNASSIGNED",
                points = pts,
                reasons = reasons,
            })
        end
    end

    local manualLP = CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.legacyPoints)
    local effectiveLP = (manualLP and manualLP > 0) and manualLP or totalCalc

    local nextTier = 10
    local tierName = "Tier 1 (10 LP)"
    if effectiveLP >= 18 then
        nextTier = 18
        tierName = "Max Meta (18 LP reached)"
    elseif effectiveLP >= 16 then
        nextTier = 18
        tierName = "Tier 3 (18 LP - Max Meta)"
    elseif effectiveLP >= 10 then
        nextTier = 16
        tierName = "Tier 2 (16 LP - Core Target)"
    end

    local needed = math.max(0, nextTier - effectiveLP)
    local pct = math.min(100, math.floor((effectiveLP / nextTier) * 100 + 0.5))

    return {
        calculatedLP = totalCalc,
        manualLP = manualLP,
        effectiveLP = effectiveLP,
        isManual = (manualLP ~= nil and manualLP > 0),
        nextTier = nextTier,
        tierName = tierName,
        neededLP = needed,
        percent = pct,
        breakdown = breakdown,
    }
end

function CLIAlts:SetAccountLP(points)
    if not CLIAltsDB then self:InitDB() end
    if not CLIAltsDB.settings then CLIAltsDB.settings = {} end
    if not points or points == "" or points == "auto" or points == "reset" or points == "calc" then
        CLIAltsDB.settings.legacyPoints = nil
        local data = self:CalculateAccountLP()
        return string.format("Legacy Points reset to auto calculation (%.1f LP).", data.effectiveLP), true
    end
    local num = tonumber(points)
    if not num or num < 0 or num > 50 then
        return "Usage: lp <points|auto> (e.g. lp 14 or lp auto)", false
    end
    CLIAltsDB.settings.legacyPoints = num
    local data = self:CalculateAccountLP()
    return string.format("Legacy Points manually set to %.1f LP (Target: %d LP, %.1f needed).", num, data.nextTier, data.neededLP), true
end

function CLIAlts:PrintLegacyPointStatus(arg)
    if arg and arg ~= "" then
        local msg, ok = self:SetAccountLP(arg)
        self:Print(msg)
        self:RequestRender()
        return msg, ok
    end

    local data = self:CalculateAccountLP()
    local t = (self.GetTheme and self:GetTheme()) or {
        borderHex = "f2c94c",
        primaryHex = "ffd34e",
        highlightHex = "ffd34e",
        readyHex = "55e39a",
        pendingHex = "ffb547",
        mutedHex = "a9a08c",
    }

    local top = string.rep("=", 72)
    local bottom = string.rep("=", 72)

    self:Print(string.format("|cff%s%s|r", t.borderHex or "f2c94c", top))
    self:Print(string.format("|cff%sCLIALTS :: LEGACY POINT (LP) PROGRESS TRACKER (WOW FOREVER)|r", t.highlightHex or "ffd34e"))
    local modeStr = data.isManual and string.format("|cff%s[MANUAL OVERRIDE: %s LP]|r", t.pendingHex or "ffb547", tostring(data.manualLP)) or "|cff00ff66[AUTO SCANNED]|r"
    self:Print(string.format("  Current Account LP: |cffffffff%.1f LP|r %s", data.effectiveLP, modeStr))
    self:Print(string.format("  Next Unlock Tier:   |cffffffff%s|r (%d%% complete)", data.tierName, data.percent))
    if data.neededLP > 0 then
        self:Print(string.format("  Gap to Next Tier:   |cff%s%.1f LP needed|r to reach %d LP", t.pendingHex or "ffb547", data.neededLP, data.nextTier))
    else
        self:Print(string.format("  Tier Status:        |cff%sALL TIERS UNLOCKED!|r", t.readyHex or "55e39a"))
    end
    self:Print(string.format("|cff%s%s|r", t.borderHex or "f2c94c", string.rep("-", 72)))
    self:Print("  Roster Contributions:")

    if #data.breakdown == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("    No characters have reached Level 20+ or Phase 1 (75) profession cap yet.")
    else
        for _, b in ipairs(data.breakdown) do
            local cName = self:ColorizePlayerName(b.name, b.classFile)
            local detail = table.concat(b.reasons, ", ")
            DEFAULT_CHAT_FRAME:AddMessage(string.format("    * %-16s (Lvl %2d): |cffffffff%.1f LP|r [%s]", cName, b.level, b.points, detail))
        end
    end

    self:Print(string.format("|cff%s%s|r", t.borderHex or "f2c94c", bottom))
    self:Print("Tip: Type |cff00ff66/clialts lp <points>|r to override, or |cff00ff66/clialts lp auto|r to reset.")
    return string.format("Account LP: %.1f/%d (%s)", data.effectiveLP, data.nextTier, data.tierName), true
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
function CLIAlts:CheckCappedAltsAlert(forceDetailed)
    if forceDetailed then
        self:CheckCappedAltsNotice()
    else
        self:PrintLoginDigest(false)
    end
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

-- ----------------------------------------------------------------------------
-- Automatic Bag Sorting & Stack Consolidation Engine (Feature 8)
-- ----------------------------------------------------------------------------
function CLIAlts:GetItemSortScore(itemID, count)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then
        return 990000000, "99_empty", 99
    end

    local itemName, quality, itemType, classID, subclassID
    if GetItemInfo then
        local raw = { GetItemInfo(itemID) }
        if raw[1] then
            itemName = raw[1]
            quality = raw[3]
            itemType = raw[6]
            classID = raw[12]
            subclassID = raw[13]
        end
    end
    if not classID and C_Item and C_Item.GetItemInfoInstant then
        local raw = { C_Item.GetItemInfoInstant(itemID) }
        classID = raw[6]
        subclassID = raw[7]
    elseif not classID and GetItemInfoInstant then
        local raw = { GetItemInfoInstant(itemID) }
        classID = raw[6]
        subclassID = raw[7]
    end

    quality = quality or 1
    classID = classID or 15
    subclassID = subclassID or 0
    itemName = itemName or ("Item #" .. tostring(itemID))

    local catPriority = 80
    if quality == 0 then
        -- Poor / Gray vendor junk (grouped at the end before empty slots)
        catPriority = 90
    elseif classID == 12 or itemType == "Quest" then
        -- Quest items
        catPriority = 10
    elseif classID == 0 or itemType == "Consumable" then
        -- Consumables (Potions, Elixirs, Flasks, Food, Water, Bandages)
        catPriority = 20
    elseif classID == 7 or itemType == "Trade Goods" then
        -- Trade Goods & Crafting Reagents
        catPriority = 30
    elseif classID == 1 or itemType == "Container" then
        -- Bags & Containers
        catPriority = 40
    elseif classID == 9 or itemType == "Recipe" then
        -- Recipes, Plans, Patterns, Schematics
        catPriority = 50
    elseif classID == 2 or itemType == "Weapon" then
        -- Weapons (higher quality first)
        catPriority = 60 - math.min(quality, 5)
    elseif classID == 4 or itemType == "Armor" then
        -- Armor & Wearable Gear (higher quality first)
        catPriority = 70 - math.min(quality, 5)
    elseif classID == 15 or itemType == "Miscellaneous" then
        -- Tools, Reagents, Keys, Pets, Mounts
        catPriority = 80
    end

    local sortScore = catPriority * 10000000 + (subclassID * 100000) + math.min(itemID, 99999)
    local sortKey = string.format("%02d_%02d_%s_%06d_%08d", catPriority, subclassID, itemName:lower(), 999999 - (count or 1), itemID)
    return sortScore, sortKey, catPriority
end

function CLIAlts:ConsolidateBagStacks()
    if InCombatLockdown and InCombatLockdown() then return false end
    if CursorHasItem and CursorHasItem() then return false end

    local numBags = NUM_BAG_SLOTS or 4
    local partialStacks = {}

    for bagID = 0, numBags do
        local isSpecial = false
        if bagID > 0 and GetContainerNumFreeSlots then
            local _, bagType = GetContainerNumFreeSlots(bagID)
            if bagType and bagType ~= 0 then isSpecial = true end
        end

        if not isSpecial then
            local numSlots = self:GetNumContainerSlots(bagID)
            for slot = 1, numSlots do
                local itemID, count = self:GetContainerItemData(bagID, slot)
                if itemID and itemID > 0 and count and count > 0 then
                    local maxStack = 1
                    if GetItemInfo then
                        local raw = { GetItemInfo(itemID) }
                        maxStack = tonumber(raw[8]) or 1
                    end
                    if maxStack > 1 and count < maxStack then
                        if not partialStacks[itemID] then partialStacks[itemID] = {} end
                        table.insert(partialStacks[itemID], { bag = bagID, slot = slot, count = count, maxStack = maxStack })
                    end
                end
            end
        end
    end

    local didMerge = false
    for _, list in pairs(partialStacks) do
        if #list > 1 then
            for i = 1, #list - 1 do
                for j = i + 1, #list do
                    local a = list[i]
                    local b = list[j]
                    if a and b and a.count < a.maxStack and b.count > 0 then
                        if PickupContainerItem and ClearCursor then
                            ClearCursor()
                            PickupContainerItem(b.bag, b.slot)
                            PickupContainerItem(a.bag, a.slot)
                            ClearCursor()
                            local transfer = math.min(b.count, a.maxStack - a.count)
                            a.count = a.count + transfer
                            b.count = b.count - transfer
                            didMerge = true
                        end
                    end
                end
            end
        end
    end
    return didMerge
end

function CLIAlts:SortBags()
    if InCombatLockdown and InCombatLockdown() then
        self:Print("|cffff4444Cannot sort bags while in combat.|r")
        return false
    end
    if CursorHasItem and CursorHasItem() then
        self:Print("|cffff4444Cannot sort bags while holding an item on the cursor.|r")
        return false
    end
    if self.isSortingBags then
        self:Print("Bag sorting is already in progress...")
        return false
    end

    -- 1. Check native Blizzard sorting API (Retail / Modern Classic)
    if C_Container and C_Container.SortBags then
        local ok = pcall(C_Container.SortBags)
        if ok then
            self:Print("Bags sorted.")
            return true
        end
    elseif _G["SortBags"] and type(_G["SortBags"]) == "function" and _G["SortBags"] ~= self.SortBags then
        local ok = pcall(_G["SortBags"])
        if ok then
            self:Print("Bags sorted.")
            return true
        end
    end

    -- 2. Custom Lua Sorter Engine (WoW Forever / 3.3.5 / Vanilla fallback)
    return self:StartCustomBagSort()
end

function CLIAlts:StopBagSort()
    if self.sortFrame then
        self.sortFrame:Hide()
    end
    self.isSortingBags = false
    if ClearCursor then ClearCursor() end
end

function CLIAlts:StartCustomBagSort()
    if not PickupContainerItem then
        self:Print("Bag sorting API not available on this client.")
        return false
    end

    -- Step 1: Consolidate partial stacks first
    self:ConsolidateBagStacks()

    -- Step 2: Gather all movable slots across general inventory bags
    local numBags = NUM_BAG_SLOTS or 4
    local slotRefs = {}

    for bagID = 0, numBags do
        local isSpecial = false
        if bagID > 0 and GetContainerNumFreeSlots then
            local _, bagType = GetContainerNumFreeSlots(bagID)
            if bagType and bagType ~= 0 then
                isSpecial = true
            end
        end

        if not isSpecial then
            local numSlots = self:GetNumContainerSlots(bagID)
            for slot = 1, numSlots do
                table.insert(slotRefs, { bag = bagID, slot = slot })
            end
        end
    end

    if #slotRefs == 0 then
        self:Print("Bags are already organized.")
        return true
    end

    -- Step 3: Snapshot current items and build desired target arrangement
    local currentItems = {}
    local sortList = {}

    for idx, ref in ipairs(slotRefs) do
        local itemID, count, link = self:GetContainerItemData(ref.bag, ref.slot)
        local score, key = self:GetItemSortScore(itemID, count)
        local entry = {
            index = idx,
            bag = ref.bag,
            slot = ref.slot,
            itemID = itemID or 0,
            count = count or 0,
            link = link,
            score = score,
            key = key,
        }
        currentItems[idx] = entry
        table.insert(sortList, entry)
    end

    table.sort(sortList, function(a, b)
        if a.score ~= b.score then
            return a.score < b.score
        end
        return a.key < b.key
    end)

    -- Check if already sorted
    local alreadySorted = true
    for idx = 1, #sortList do
        if currentItems[idx].itemID ~= sortList[idx].itemID or currentItems[idx].count ~= sortList[idx].count then
            alreadySorted = false
            break
        end
    end

    if alreadySorted then
        self:Print("Bags are already organized.")
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN then
            pcall(PlaySound, SOUNDKIT.IG_BACKPACK_OPEN)
        end
        return true
    end

    -- Start asynchronous sorting ticker
    if not self.sortFrame then
        self.sortFrame = CreateFrame("Frame", "CLIAltsSortFrame", UIParent)
    end

    self.isSortingBags = true
    local sf = self.sortFrame
    sf.slotRefs = slotRefs
    sf.desired = sortList
    sf.startTime = (GetTime and GetTime()) or 0
    sf.timeSinceMove = 0

    sf:SetScript("OnUpdate", function(f, elapsed)
        if InCombatLockdown and InCombatLockdown() then
            f:Hide()
            CLIAlts.isSortingBags = false
            CLIAlts:Print("|cffff4444Bag sorting paused: In combat.|r")
            return
        end

        local curTime = (GetTime and GetTime()) or 0
        if curTime > f.startTime + 15 then
            f:Hide()
            CLIAlts.isSortingBags = false
            CLIAlts:Print("Bag sorting timed out.")
            return
        end

        f.timeSinceMove = (f.timeSinceMove or 0) + (elapsed or 0.1)
        if f.timeSinceMove < 0.08 then return end
        f.timeSinceMove = 0

        -- Refresh current inventory states
        local current = {}
        local allMatched = true

        for idx, ref in ipairs(f.slotRefs) do
            local itemID, count = CLIAlts:GetContainerItemData(ref.bag, ref.slot)
            current[idx] = {
                bag = ref.bag,
                slot = ref.slot,
                itemID = itemID or 0,
                count = count or 0,
            }
        end

        -- Check if any item in current bag slots is currently locked
        for _, cur in ipairs(current) do
            local isLocked = false
            if C_Container and C_Container.GetContainerItemInfo then
                local info = C_Container.GetContainerItemInfo(cur.bag, cur.slot)
                isLocked = info and info.isLocked
            elseif GetContainerItemInfo then
                local _, _, locked = GetContainerItemInfo(cur.bag, cur.slot)
                isLocked = locked
            end
            if isLocked then
                return -- Wait for lock to clear
            end
        end

        -- Find first mismatch and swap
        for i = 1, #f.desired do
            local targetItem = f.desired[i]
            local curItem = current[i]

            if curItem.itemID ~= targetItem.itemID or curItem.count ~= targetItem.count then
                allMatched = false

                -- Find where targetItem is currently located
                local sourceIdx = nil
                for j = i + 1, #current do
                    if current[j].itemID == targetItem.itemID and current[j].count == targetItem.count then
                        sourceIdx = j
                        break
                    end
                end

                if not sourceIdx then
                    for j = i + 1, #current do
                        if current[j].itemID == targetItem.itemID and targetItem.itemID > 0 then
                            sourceIdx = j
                            break
                        end
                    end
                end

                if sourceIdx then
                    ClearCursor()
                    PickupContainerItem(current[sourceIdx].bag, current[sourceIdx].slot)
                    PickupContainerItem(curItem.bag, curItem.slot)
                    ClearCursor()
                    return -- One move per tick
                end
            end
        end

        if allMatched then
            f:Hide()
            CLIAlts.isSortingBags = false
            if PlaySound and SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN then
                pcall(PlaySound, SOUNDKIT.IG_BACKPACK_OPEN)
            end
            CLIAlts:Print("|cff00ff66Bags sorted successfully.|r")
            if CLIAlts.RequestRender then CLIAlts:RequestRender() end
        end
    end)

    sf:Show()
    self:Print("Sorting bags...")
    return true
end


