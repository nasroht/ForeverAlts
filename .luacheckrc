-- ============================================================================
-- Luacheck Configuration for CLIAlts World of Warcraft Addon
-- ============================================================================

std = "lua51"

-- Addon callbacks frequently declare unused parameters (self, event, ...)
unused_args = false
self = false

-- Files or directories to exclude from linting
exclude_files = {
    ".github/",
    "media/",
}

-- Code style rules to ignore
ignore = {
    "631", -- line is too long
    "211/addonName", -- unused addonName in standard addon file headers
    "212", -- unused argument in standard event/callback signatures
    "411", -- variable shadows global
    "412", -- variable shadows global
    "421", -- variable shadows local
    "422", -- argument shadows local
    "423", -- loop variable shadows local
    "431", -- variable shadows upvalue
    "432", -- argument shadows upvalue
    "433", -- loop variable shadows upvalue
    "542", -- empty if branch
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
    "MouseIsOver",
    "ChatFrame_OpenChat",
    "RAID_CLASS_COLORS",
    "ITEM_QUALITY_COLORS",
    "UISpecialFrames",
    "BackdropTemplateMixin",
    "GetCursorPosition",

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
    "UnitSecondaryName",
    "UnitSurname",
    "GetBindLocation",

    -- WoW Skills, Craft & Trade APIs
    "GetProfessions",
    "GetProfessionInfo",
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
    "GetItemInfoInstant",
    "C_Item",
    "GetInboxNumItems",
    "GetInboxHeaderInfo",
    "ChatEdit_InsertLink",

    -- WoW Hooking, Libraries & Profiling
    "hooksecurefunc",
    "LibStub",
    "utf8",
    "GetAddOnMemoryUsage",
    "UpdateAddOnMemoryUsage",
    "debugprofilestop",
    "debugprofilestart",
    "C_Timer",

    -- WoW-exposed standard Lua extensions / globals
    "time",
    "date",
    "tinsert",
    "tremove",
    "strtrim",
    "strsplit",
    "strlenutf8",
    "wipe",
}
