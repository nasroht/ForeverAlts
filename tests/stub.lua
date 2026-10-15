-- ============================================================================
-- CLIAlts: Minimal WoW API Stubs & Plain Lua 5.1 CI Test Runner
-- File: tests/stub.lua
-- ============================================================================

-- 1. Standard Lua / WoW Global Aliases
time = time or os.time
date = date or os.date

-- 2. Mock WoW Frame & Widget Hierarchy
local function CreateDummyFrame(frameType, name, parent)
    local frame = {
        name = name,
        type = frameType,
        parent = parent,
        scripts = {},
        scale = 1,
        shown = true,
    }
    function frame:SetScript(handler, fn) self.scripts[handler] = fn end
    function frame:GetScript(handler) return self.scripts[handler] end
    function frame:HookScript(handler, fn) end
    function frame:RegisterEvent(event) end
    function frame:UnregisterEvent(event) end
    function frame:SetPoint(...) end
    function frame:SetSize(...) end
    function frame:SetWidth(...) end
    function frame:SetHeight(...) end
    function frame:GetWidth() return 140 end
    function frame:GetHeight() return 140 end
    function frame:GetCenter() return 100, 100 end
    function frame:GetEffectiveScale() return 1 end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown == true end
    function frame:IsVisible() return self.shown == true end
    function frame:SetText(txt)
        if self.type == "FontString" and not self.font then
            error("FontString:SetText(): Font not set")
        end
        self.text = txt
    end
    function frame:GetText() return self.text or "" end
    function frame:SetScale(s) self.scale = s end
    function frame:GetScale() return self.scale or 1 end
    function frame:EnableMouse(...) end
    function frame:EnableMouseWheel(...) end
    function frame:SetMovable(...) end
    function frame:SetClampedToScreen(...) end
    function frame:RegisterForClicks(...) end
    function frame:RegisterForDrag(...) end
    function frame:SetFrameStrata(...) end
    function frame:SetFrameLevel(...) end
    function frame:SetBackdrop(...) end
    function frame:SetBackdropColor(...) end
    function frame:SetBackdropBorderColor(...) end
    function frame:ClearAllPoints(...) end
    function frame:SetAllPoints(...) end
    function frame:GetPoint(...) return "CENTER", nil, "CENTER", 0, 0 end
    function frame:SetPropagateKeyboardInput(...) end
    function frame:EnableKeyboard(...) end
    frame.lines = {}
    function frame:SetOwner(...) end
    function frame:AddLine(left, r, g, b) table.insert(self.lines, { left = left }) end
    function frame:AddDoubleLine(left, right, ...) table.insert(self.lines, { left = left, right = right }) end
    function frame:GetItem() return self.itemName, self.itemLink end
    function frame:ClearLines() self.lines = {} end
    function frame:LockHighlight(...) end
    function frame:UnlockHighlight(...) end
    function frame:SetHighlightTexture(...) end
    function frame:SetTextColor(...) end
    function frame:SetFont(fontPath, size, flags)
        if flags == "BOLD" then
            return nil
        end
        self.font = fontPath or "Fonts\\FRIZQT__.TTF"
        self.fontSize = size or 12
        self.fontFlags = flags or ""
        return true
    end
    function frame:GetFont()
        if not self.font then return nil end
        return self.font, self.fontSize, self.fontFlags
    end
    function frame:SetFontObject(obj)
        self.font = "Fonts\\FRIZQT__.TTF"
        self.fontSize = 12
        self.fontFlags = ""
        self.fontObject = obj
    end
    function frame:SetAutoFocus(...) end
    function frame:SetTextInsets(...) end
    function frame:SetMultiLine(...) end
    function frame:SetEnabled(...) end
    function frame:SetFocus(...) self.focused = true end
    function frame:ClearFocus(...) self.focused = false end
    function frame:HasFocus(...) return self.focused == true end
    function frame:HighlightText(...) end
    function frame:SetCursorPosition(...) end
    function frame:Insert(...) end
    function frame:StartMoving(...) end
    function frame:StopMovingOrSizing(...) end
    function frame:SetAlpha(a) self.alpha = a end
    function frame:GetAlpha() return self.alpha or 1 end
    function frame:CreateFontString(...)
        local fs = CreateDummyFrame("FontString")
        fs.GetStringWidth = function() return 100 end
        fs.SetJustifyH = function() end
        fs.SetJustifyV = function() end
        fs.SetWordWrap = function() end
        return fs
    end
    function frame:CreateTexture(...)
        local tex = CreateDummyFrame("Texture")
        tex.SetTexture = function() end
        tex.SetTexCoord = function() end
        tex.SetVertexColor = function() end
        return tex
    end
    return frame
end

CreateFrame = CreateFrame or CreateDummyFrame
UIParent = UIParent or CreateDummyFrame("Frame", "UIParent")
Minimap = Minimap or CreateDummyFrame("Frame", "Minimap")
GameTooltip = GameTooltip or CreateDummyFrame("Frame", "GameTooltip")
DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME or {
    AddMessage = function(self, msg)
        print(msg)
    end
}
ChatFrame_OpenChat = ChatFrame_OpenChat or function() end
STANDARD_TEXT_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
SlashCmdList = SlashCmdList or {}
UISpecialFrames = UISpecialFrames or {}
tinsert = tinsert or table.insert
MouseIsOver = MouseIsOver or function() return true end
PlaySound = PlaySound or function() end
hooksecurefunc = hooksecurefunc or function() end
SetOverrideBindingClick = SetOverrideBindingClick or function() end
ClearOverrideBindings = ClearOverrideBindings or function() end
GetCursorPosition = GetCursorPosition or function() return 100, 100 end
ItemRefTooltip = ItemRefTooltip or CreateDummyFrame("Frame", "ItemRefTooltip")
TooltipDataProcessor = TooltipDataProcessor or {
    AddTooltipPostCall = function(dataType, callback) end,
}
Enum = Enum or {
    TooltipDataType = { Item = 0 },
}
NUM_BAG_SLOTS = NUM_BAG_SLOTS or 4
NUM_BANKBAGSLOTS = NUM_BANKBAGSLOTS or 6
BANK_CONTAINER = BANK_CONTAINER or -1
InCombatLockdown = InCombatLockdown or function() return false end
CursorHasItem = CursorHasItem or function() return false end
ClearCursor = ClearCursor or function() end
PickupContainerItem = PickupContainerItem or function(bag, slot) end
GetContainerNumFreeSlots = GetContainerNumFreeSlots or function(bag) return 0, 0 end
ContainerFrame1 = ContainerFrame1 or CreateDummyFrame("Frame", "ContainerFrame1")
ContainerFrame1CloseButton = ContainerFrame1CloseButton or CreateDummyFrame("Button", "ContainerFrame1CloseButton", ContainerFrame1)
ContainerFrameCombinedBags = ContainerFrameCombinedBags or CreateDummyFrame("Frame", "ContainerFrameCombinedBags")
ContainerFrameCombinedBagsCloseButton = ContainerFrameCombinedBagsCloseButton or CreateDummyFrame("Button", "ContainerFrameCombinedBagsCloseButton", ContainerFrameCombinedBags)

ATTACHMENTS_MAX_SEND = ATTACHMENTS_MAX_SEND or 12
SendMailFrame = SendMailFrame or CreateDummyFrame("Frame", "SendMailFrame")
SendMailNameEditBox = SendMailNameEditBox or CreateDummyFrame("EditBox", "SendMailNameEditBox", SendMailFrame)
SendMailSubjectEditBox = SendMailSubjectEditBox or CreateDummyFrame("EditBox", "SendMailSubjectEditBox", SendMailFrame)
SendMailMailButton = SendMailMailButton or CreateDummyFrame("Button", "SendMailMailButton", SendMailFrame)
ClickSendMailItemButton = ClickSendMailItemButton or function(index, clear) end
GetSendMailItem = GetSendMailItem or function(index) return nil end
UseContainerItem = UseContainerItem or function(bag, slot) end

C_Container = C_Container or {
    GetContainerNumSlots = function(bagID) return 0 end,
    GetContainerItemInfo = function(bagID, slot) return nil end,
}
C_QuestLog = C_QuestLog or {
    IsQuestFlaggedCompleted = function(questID) return false end,
    GetNumQuestLogEntries = function() return 0 end,
    GetInfo = function(index) return nil end,
}
GetQuestsCompleted = GetQuestsCompleted or function(tbl) end
GetItemInfo = GetItemInfo or function(id) return nil end
GetItemInfoInstant = GetItemInfoInstant or function(id) return nil end
C_Item = C_Item or {
    GetItemInfoInstant = function(id) return nil end,
}

-- 3. WoW System & Timer APIs
GetTime = GetTime or function() return os.time() end
WOW_PROJECT_ID = WOW_PROJECT_ID or nil
WOW_PROJECT_MAINLINE = WOW_PROJECT_MAINLINE or 1
WOW_PROJECT_CLASSIC = WOW_PROJECT_CLASSIC or 2
GetBuildInfo = GetBuildInfo or function() return "1.15.5", "58238", "Jan 1 2026", 11505 end
C_AddOns = C_AddOns or {
    GetAddOnMemoryUsage = function(name) return 150.5 end,
    UpdateAddOnMemoryUsage = function() end,
}
C_Timer = C_Timer or {
    After = function(sec, cb) if cb then cb() end end,
    NewTicker = function(sec, cb) return { Cancel = function() end } end,
}

-- 4. Load CLIAlts Addon Files in TOC order
local addon = {}
local files = { "data.lua", "minimap.lua", "ui.lua", "core.lua", "tests/selftest.lua" }

print("============================================================")
print("CLIAlts CI Test Runner: Loading files under plain Lua 5.1...")
print("============================================================")

for _, file in ipairs(files) do
    local chunk, err = loadfile(file)
    if not chunk then
        io.stderr:write(string.format("FATAL: Failed to parse %s: %s\n", file, tostring(err)))
        os.exit(1)
    end
    local ok, runErr = pcall(chunk, "CLIAlts", addon)
    if not ok then
        io.stderr:write(string.format("FATAL: Runtime error loading %s: %s\n", file, tostring(runErr)))
        os.exit(1)
    end
    print(string.format("  [OK] %s loaded successfully.", file))
end

-- 5. Initialize Addon Database
if addon.InitDB then
    addon:InitDB()
    print("  [OK] Database initialized.")
end

-- 6. Execute Full Self-Test Verification Suite
print("============================================================")
print("Executing CLIAlts:RunSelfTest()...")
print("============================================================")

local success, passed, failed = addon:RunSelfTest()

print("============================================================")
if success and (failed == 0) and (passed and passed > 0) then
    print(string.format("SUCCESS: All %d assertions passed cleanly under Lua 5.1!", passed))
    print("============================================================")
    os.exit(0)
else
    io.stderr:write(string.format("FAILURE: Self-test failed! Passed: %s, Failed: %s\n",
        tostring(passed or 0), tostring(failed or 1)))
    print("============================================================")
    os.exit(1)
end
