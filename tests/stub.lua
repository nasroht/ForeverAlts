-- ============================================================================
-- CLIAlts: Minimal WoW API Stubs & Plain Lua 5.1 CI Test Runner
-- File: tests/stub.lua
-- ============================================================================

-- 1. Standard Lua / WoW Global Aliases
time = time or os.time
date = date or os.date
unpack = unpack or (table and table.unpack)

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
    if name then
        _G[name] = frame
    end
    function frame:SetScript(handler, fn) self.scripts[handler] = fn end
    function frame:GetScript(handler) return self.scripts[handler] end
    function frame:HookScript(handler, fn) end
    function frame:RegisterEvent(event) end
    function frame:UnregisterEvent(event) end
    function frame:SetPoint(...) end
    function frame:SetSize(w, h) self.width = w; self.height = h end
    function frame:SetWidth(w) self.width = w end
    function frame:SetHeight(h) self.height = h end
    function frame:GetWidth() return self.width or 140 end
    function frame:GetHeight() return self.height or 140 end
    function frame:GetCenter() return 100, 100 end
    function frame:GetEffectiveScale() return 1 end
    function frame:Show()
        local wasShown = (self.shown == true)
        self.shown = true
        if not wasShown and self.scripts["OnShow"] then
            self.scripts["OnShow"](self)
        end
    end
    function frame:Hide()
        local wasShown = (self.shown == true)
        self.shown = false
        if wasShown and self.scripts["OnHide"] then
            self.scripts["OnHide"](self)
        end
    end
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
    function frame:SetParent(p) self.parent = p end
    function frame:GetParent() return self.parent end
    function frame:RegisterForClicks(...) end
    function frame:RegisterForDrag(...) end
    function frame:SetFrameStrata(s) self.strata = s end
    function frame:GetFrameStrata() return self.strata or "HIGH" end
    function frame:SetFrameLevel(l) self.level = l end
    function frame:GetFrameLevel() return self.level or 10 end
    function frame:SetBackdrop(...) end
    function frame:SetBackdropColor(r, g, b, a)
        if r == nil then error("bad argument #1 to 'SetVertexColor' (Usage: self:SetVertexColor(color [, a]))", 2) end
        self.backdropColor = { r, g, b, a }
    end
    function frame:SetBackdropBorderColor(r, g, b, a)
        if r == nil then error("bad argument #1 to 'SetVertexColor' (Usage: self:SetVertexColor(color [, a]))", 2) end
        self.backdropBorderColor = { r, g, b, a }
    end
    function frame:ClearAllPoints(...) end
    function frame:SetAllPoints(...) end
    function frame:GetPoint(...) return "CENTER", nil, "CENTER", 0, 0 end
    function frame:SetPropagateKeyboardInput(...) end
    function frame:EnableKeyboard(...) end
    function frame:SetSwipeTexture(...) end
    function frame:SetSwipeColor(...) end
    function frame:SetDrawEdge(...) end
    function frame:SetDrawBling(...) end
    function frame:SetHideCountdownNumbers(...) end
    function frame:SetDrawSwipe(...) end
    function frame:SetCooldown(...) end
    function frame:Clear(...) end
    function frame:Pause(...) end
    frame.lines = {}
    function frame:SetOwner(...) end
    function frame:AddLine(left, r, g, b)
        table.insert(self.lines, { left = left })
        if self.name then
            local idx = #self.lines
            local fs = _G[self.name .. "TextLeft" .. idx]
            if not fs then
                fs = CreateDummyFrame("FontString", self.name .. "TextLeft" .. idx)
                fs.font = "Fonts\\FRIZQT__.TTF"
            end
            fs.text = left
        end
    end
    function frame:AddDoubleLine(left, right, ...)
        table.insert(self.lines, { left = left, right = right })
        if self.name then
            local idx = #self.lines
            local fs = _G[self.name .. "TextLeft" .. idx]
            if not fs then
                fs = CreateDummyFrame("FontString", self.name .. "TextLeft" .. idx)
                fs.font = "Fonts\\FRIZQT__.TTF"
            end
            fs.text = left
        end
    end
    function frame:GetItem() return self.itemName, self.itemLink end
    function frame:ClearLines() self.lines = {} end
    function frame:NumLines() return #(self.lines or {}) end
    function frame:SetBagItem(bag, slot)
        local key = tostring(bag) .. ":" .. tostring(slot)
        if self.mockBagItems and self.mockBagItems[key] then
            for _, line in ipairs(self.mockBagItems[key]) do
                self:AddLine(line)
            end
        end
    end
    function frame:SetItemByID(id)
        if self.mockItems and self.mockItems[id] then
            for _, line in ipairs(self.mockItems[id]) do
                self:AddLine(line)
            end
        end
    end
    function frame:SetHyperlink(link) end
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
    function frame:SetEnabled(val) self.enabled = (val ~= false) end
    function frame:Enable() self:SetEnabled(true) end
    function frame:Disable() self:SetEnabled(false) end
    function frame:IsEnabled() return self.enabled ~= false end
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
NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS or 10
mockChatState = mockChatState or {}
for i = 1, NUM_CHAT_WINDOWS do
    local cf = _G["ChatFrame" .. i] or CreateDummyFrame("Frame", "ChatFrame" .. i, UIParent)
    cf.width = 420
    cf.height = 200
    mockChatState[i] = mockChatState[i] or {
        name = (i == 1 and "General") or (i == 2 and "Combat Log") or (i == 3 and "Voice") or "",
        fontSize = 14,
        r = 1, g = 1, b = 1, alpha = 1,
        shown = (i <= 2),
        locked = true,
        docked = (i == 1),
        uninteractable = false,
        messages = (i == 1 and { "SAY", "EMOTE", "YELL", "GUILD", "PARTY" }) or (i == 2 and { "COMBAT" }) or {},
        channels = (i == 1 and { "General - Zone", "Trade - City", "LocalDefense" }) or {},
    }
end

GetChatWindowInfo = GetChatWindowInfo or function(i)
    local s = mockChatState[i]
    if not s or s.name == "" then return nil end
    return s.name, s.fontSize, s.r, s.g, s.b, s.alpha, s.shown, s.locked, s.docked, s.uninteractable
end

GetChatWindowMessages = GetChatWindowMessages or function(i)
    local s = mockChatState[i]
    if not s or not s.messages then return end
    return unpack(s.messages)
end

GetChatWindowChannels = GetChatWindowChannels or function(i)
    local s = mockChatState[i]
    if not s or not s.channels then return end
    local res = {}
    for _, ch in ipairs(s.channels) do
        table.insert(res, ch)
        table.insert(res, 0)
    end
    return unpack(res)
end

SetChatWindowName = SetChatWindowName or function(i, name)
    if mockChatState[i] then mockChatState[i].name = name end
end
SetChatWindowSize = SetChatWindowSize or function(i, sz)
    if mockChatState[i] then mockChatState[i].fontSize = sz end
end
SetChatWindowColor = SetChatWindowColor or function(i, r, g, b)
    if mockChatState[i] then mockChatState[i].r = r; mockChatState[i].g = g; mockChatState[i].b = b end
end
SetChatWindowAlpha = SetChatWindowAlpha or function(i, a)
    if mockChatState[i] then mockChatState[i].alpha = a end
end
SetChatWindowShown = SetChatWindowShown or function(i, shown)
    if mockChatState[i] then mockChatState[i].shown = (shown == 1 or shown == true) end
end
SetChatWindowLocked = SetChatWindowLocked or function(i, locked)
    if mockChatState[i] then mockChatState[i].locked = (locked == 1 or locked == true) end
end
SetChatWindowUninteractable = SetChatWindowUninteractable or function(i, u)
    if mockChatState[i] then mockChatState[i].uninteractable = (u == 1 or u == true) end
end
ChatFrame_RemoveAllMessageGroups = ChatFrame_RemoveAllMessageGroups or function(cf)
    local idx = tonumber(cf and cf.name and cf.name:match("ChatFrame(%d+)"))
    if idx and mockChatState[idx] then mockChatState[idx].messages = {} end
end
ChatFrame_AddMessageGroup = ChatFrame_AddMessageGroup or function(cf, grp)
    local idx = tonumber(cf and cf.name and cf.name:match("ChatFrame(%d+)"))
    if idx and mockChatState[idx] then table.insert(mockChatState[idx].messages, grp) end
end
ChatFrame_RemoveAllChannels = ChatFrame_RemoveAllChannels or function(cf)
    local idx = tonumber(cf and cf.name and cf.name:match("ChatFrame(%d+)"))
    if idx and mockChatState[idx] then mockChatState[idx].channels = {} end
end
ChatFrame_AddChannel = ChatFrame_AddChannel or function(cf, ch)
    local idx = tonumber(cf and cf.name and cf.name:match("ChatFrame(%d+)"))
    if idx and mockChatState[idx] then table.insert(mockChatState[idx].channels, ch) end
end
FCF_SavePositionAndDimensions = FCF_SavePositionAndDimensions or function(cf) end
FCF_DockUpdate = FCF_DockUpdate or function() end
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
GetCursorInfo = GetCursorInfo or function() return nil end
PickupContainerItem = PickupContainerItem or function(bag, slot) end
GetContainerItemLink = GetContainerItemLink or function(bag, slot) return nil end
GetContainerItemID = GetContainerItemID or function(bag, slot) return nil end
GetContainerItemInfo = GetContainerItemInfo or function(bag, slot) return nil end
GetContainerNumSlots = GetContainerNumSlots or function(bag) return 0 end
GetContainerNumFreeSlots = GetContainerNumFreeSlots or function(bag) return 0, 0 end
ContainerFrame1 = ContainerFrame1 or CreateDummyFrame("Frame", "ContainerFrame1")
ContainerFrame1CloseButton = ContainerFrame1CloseButton or CreateDummyFrame("Button", "ContainerFrame1CloseButton", ContainerFrame1)
ContainerFrame1.CloseButton = ContainerFrame1CloseButton
ContainerFrameCombinedBags = ContainerFrameCombinedBags or CreateDummyFrame("Frame", "ContainerFrameCombinedBags")
ContainerFrameCombinedBagsCloseButton = ContainerFrameCombinedBagsCloseButton or CreateDummyFrame("Button", "ContainerFrameCombinedBagsCloseButton", ContainerFrameCombinedBags)
ContainerFrameCombinedBags.CloseButton = ContainerFrameCombinedBagsCloseButton
BagItemAutoSortButton = BagItemAutoSortButton or CreateDummyFrame("Button", "BagItemAutoSortButton")
BagItemAutoSortButton.Click = function(self) if C_Container and C_Container.SortBags then C_Container.SortBags() end end

local mockCVars = { combinedBags = "0" }
GetCVar = GetCVar or function(cvar) return mockCVars[cvar] or "0" end
GetCVarBool = GetCVarBool or function(cvar) return mockCVars[cvar] == "1" end
SetCVar = SetCVar or function(cvar, val) mockCVars[cvar] = tostring(val) end

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
    PickupContainerItem = function(bagID, slot) end,
    SortBags = function() end,
}
C_Container.PickupContainerItem = C_Container.PickupContainerItem or PickupContainerItem
C_Container.SortBags = C_Container.SortBags or function() end
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
debugprofilestop = debugprofilestop or function()
    if os and os.clock then
        return os.clock() * 1000
    end
    return ((os and os.time and os.time()) or 0) * 1000
end
WOW_PROJECT_ID = WOW_PROJECT_ID or nil
WOW_PROJECT_MAINLINE = WOW_PROJECT_MAINLINE or 1
WOW_PROJECT_CLASSIC = WOW_PROJECT_CLASSIC or 2
GetBuildInfo = GetBuildInfo or function() return "1.15.5", "58238", "Jan 1 2026", 11505 end
C_AddOns = C_AddOns or {
    GetAddOnMemoryUsage = function(name) return 150.5 end,
    UpdateAddOnMemoryUsage = function() end,
}
GetAddOnMetadata = GetAddOnMetadata or function(addon, field)
    if field == "Version" then return "1.2.1" end
    return nil
end
if C_AddOns and not C_AddOns.GetAddOnMetadata then
    C_AddOns.GetAddOnMetadata = GetAddOnMetadata
end
C_Timer = C_Timer or {
    After = function(sec, cb) if cb then cb() end end,
    NewTicker = function(sec, cb) return { Cancel = function() end } end,
}

-- 4. Load CLIAlts Addon Files in TOC order
local addon = {}
local files = { "data.lua", "theme.lua", "minimap.lua", "ui.lua", "core.lua", "tests/selftest.lua" }

print("============================================================")
print("CLIAlts CI Test Runner: Loading files under plain Lua 5.1...")
print("============================================================")

for _, file in ipairs(files) do
    local chunk, err = loadfile(file)
    if not chunk then
        io.stderr:write(string.format("FATAL: Failed to parse %s: %s\n", file, tostring(err)))
        os.exit(1)
    end
    local ok, runErr = pcall(chunk, "ForeverAlts", addon)
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
