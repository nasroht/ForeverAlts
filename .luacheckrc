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
    "tests/",
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
    "CLIAltsSettingsDialog",
    "CLIAltsFocusEnterBtn",
    "CLIAltsFocusSlashBtn",
    "SLASH_CLIALTS1",
    "SLASH_CLIALTS2",
    "SLASH_CLIALTS3",
    "SLASH_CLIALTS_SORT1",
    "SLASH_CLIALTS_FILLMAIL1",
    "SLASH_CLIALTS_MAILIGNORE1",
    "SLASH_CLIALTS_MAILIGNORE2",
    "SLASH_CLIALTS_MAILUNIGNORE1",
    "SLASH_CLIALTS_MAILUNIGNORE2",
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
    "IsShiftKeyDown",
    "IsControlKeyDown",
    "IsAltKeyDown",

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

    -- WoW Client & Flavor Globals
    "WOW_PROJECT_ID",
    "WOW_PROJECT_MAINLINE",
    "WOW_PROJECT_CLASSIC",
    "GetBuildInfo",
    "C_AddOns",
    "GetAddOnMetadata",
    "GetCVar",
    "GetCVarBool",
    "SetCVar",

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
    "GetNumCrafts",
    "GetCraftInfo",
    "C_TooltipInfo",

    -- WoW Instances & Raids
    "GetNumSavedInstances",
    "GetSavedInstanceInfo",
    "RequestRaidInfo",

    -- WoW Quests & Log APIs
    "C_QuestLog",
    "GetQuestsCompleted",
    "GetNumQuestLogEntries",
    "GetQuestLogTitle",

    -- WoW Items, Bags & Mail
    "GetItemCount",
    "GetItemInfo",
    "GetItemInfoInstant",
    "C_Item",
    "C_Container",
    "GetContainerNumSlots",
    "GetContainerItemInfo",
    "GetContainerItemLink",
    "NUM_BAG_SLOTS",
    "NUM_BANKBAGSLOTS",
    "BANK_CONTAINER",
    "REAGENTBANK_CONTAINER",
    "GetInboxNumItems",
    "GetInboxHeaderInfo",
    "ChatEdit_InsertLink",
    "TooltipDataProcessor",
    "ItemRefTooltip",
    "Enum",
    "GetCursorInfo",
    "PickupContainerItem",
    "ClearCursor",
    "CursorHasItem",
    "GetContainerNumFreeSlots",
    "InCombatLockdown",
    "ContainerFrame1",
    "ContainerFrame1CloseButton",
    "ContainerFrameCombinedBags",
    "ContainerFrameCombinedBagsCloseButton",
    "BagItemAutoSortButton",
    "SendMailFrame",
    "SendMailNameEditBox",
    "SendMailSubjectEditBox",
    "SendMailMailButton",
    "ClickSendMailItemButton",
    "GetSendMailItem",
    "ATTACHMENTS_MAX_SEND",
    "UseContainerItem",
    "ToggleAllBags",
    "OpenAllBags",
    "CloseAllBags",
    "OpenBag",
    "CloseBag",

    -- WoW Hooking, Libraries & Profiling
    "hooksecurefunc",
    "LibStub",
    "utf8",
    "GetAddOnMemoryUsage",
    "UpdateAddOnMemoryUsage",
    "debugprofilestop",
    "debugprofilestart",
    "C_Timer",

    -- WoW Chat APIs & FrameXML
    "NUM_CHAT_WINDOWS",
    "GetChatWindowInfo",
    "GetChatWindowMessages",
    "GetChatWindowChannels",
    "SetChatWindowName",
    "SetChatWindowSize",
    "SetChatWindowColor",
    "SetChatWindowAlpha",
    "SetChatWindowShown",
    "SetChatWindowLocked",
    "SetChatWindowUninteractable",
    "ChatFrame_RemoveAllMessageGroups",
    "ChatFrame_AddMessageGroup",
    "ChatFrame_RemoveAllChannels",
    "ChatFrame_AddChannel",
    "FCF_SavePositionAndDimensions",
    "FCF_DockUpdate",

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

