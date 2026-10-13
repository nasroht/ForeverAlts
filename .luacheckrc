-- ============================================================================
-- Luacheck Configuration for CLIAlts World of Warcraft Addon
-- ============================================================================

std = "lua51"

-- Addon callbacks frequently declare unused parameters (self, event, ...)
unused_args = false

-- Files or directories to exclude from linting
exclude_files = {
    ".github/",
    "media/",
}

-- Code style rules to ignore
ignore = {
    "631", -- line is too long
}

-- Global environment: WoW API Globals & Addon Global Variables
globals = {
    -- Addon Globals & SavedVariables
    "CLIAltsDB",
    "CLIAltsMainFrame",
    "CLIAltsFocusEnterBtn",
    "CLIAltsFocusSlashBtn",
    "SLASH_CLIALTS1",
    "SLASH_CLIALTS2",
    "SLASH_CLIALTS3",
    "SlashCmdList",

    -- WoW Frame & UI APIs
    "CreateFrame",
    "UIParent",
    "Minimap",
    "DEFAULT_CHAT_FRAME",
    "GameTooltip",
    "UIErrorsFrame",
    "PlaySound",
    "SOUNDKIT",
    "SetOverrideBindingClick",
    "ClearOverrideBindings",
    "RAID_CLASS_COLORS",
    "ITEM_QUALITY_COLORS",
    "UISpecialFrames",

    -- WoW Player & Character APIs
    "GetTime",
    "GetXPExhaustion",
    "UnitXPMax",
    "UnitXP",
    "UnitLevel",
    "UnitName",
    "UnitClass",
    "UnitRace",
    "UnitFactionGroup",
    "UnitSex",
    "GetMoney",
    "GetRealmName",
    "GetMaxPlayerLevel",
    "IsResting",
    "GetZoneText",
    "GetSubZoneText",
    "GetUnitName",
    "GetUnitSecondaryName",
    "GetUnitSurname",

    -- WoW Skills, Craft & Trade APIs
    "GetNumSkillLines",
    "GetSkillLineInfo",
    "ExpandSkillHeader",
    "GetNumSpellTabs",
    "GetSpellTabInfo",
    "GetSpellBookItemName",
    "GetSpellBookItemInfo",
    "GetNumTradeSkills",
    "GetTradeSkillInfo",
    "GetTradeSkillCooldown",
    "TRADE_SKILL_SHOW",
    "TRADE_SKILL_UPDATE",
    "CRAFT_SHOW",
    "CRAFT_UPDATE",
    "C_TradeSkillUI",
    "C_CraftUI",

    -- WoW Instances & Raids
    "GetNumSavedInstances",
    "GetSavedInstanceInfo",
    "RequestRaidInfo",

    -- WoW Items, Bags & Mail
    "GetItemCount",
    "GetItemInfo",
    "C_Item",
    "GetInboxNumItems",
    "GetInboxHeaderInfo",

    -- WoW Profiling, System & Utilities
    "GetAddOnMemoryUsage",
    "UpdateAddOnMemoryUsage",
    "debugprofilestop",
    "debugprofilestart",
    "C_Timer",
    "strtrim",
    "strsplit",
    "strlenutf8",
    "wipe",
}
