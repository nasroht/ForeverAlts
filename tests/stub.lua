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
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown == true end
    function frame:SetText(txt) self.text = txt end
    function frame:GetText() return self.text or "" end
    function frame:SetScale(s) self.scale = s end
    function frame:GetScale() return self.scale or 1 end
    function frame:EnableMouse(...) end
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
    function frame:GetPoint(...) return "CENTER", nil, "CENTER", 0, 0 end
    function frame:SetPropagateKeyboardInput(...) end
    function frame:EnableKeyboard(...) end
    function frame:SetOwner(...) end
    function frame:AddLine(...) end
    function frame:AddDoubleLine(...) end
    function frame:LockHighlight(...) end
    function frame:UnlockHighlight(...) end
    function frame:SetHighlightTexture(...) end
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
    function frame:CreateFontString(...)
        return {
            SetFont = function() end,
            GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end,
            SetPoint = function() end,
            SetText = function(s, txt) s.text = txt end,
            GetText = function(s) return s.text or "" end,
            SetTextColor = function() end,
            GetStringWidth = function() return 100 end,
            SetJustifyH = function() end,
            SetJustifyV = function() end,
            SetWordWrap = function() end,
        }
    end
    function frame:CreateTexture(...)
        return {
            SetTexture = function() end,
            SetPoint = function() end,
            SetSize = function() end,
            SetTexCoord = function() end,
            SetVertexColor = function() end,
        }
    end
    return frame
end

CreateFrame = CreateFrame or CreateDummyFrame
UIParent = UIParent or CreateDummyFrame("Frame", "UIParent")
Minimap = Minimap or CreateDummyFrame("Frame", "Minimap")
DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME or {
    AddMessage = function(self, msg)
        print(msg)
    end
}
SlashCmdList = SlashCmdList or {}
UISpecialFrames = UISpecialFrames or {}
tinsert = tinsert or table.insert
MouseIsOver = MouseIsOver or function() return true end
PlaySound = PlaySound or function() end
hooksecurefunc = hooksecurefunc or function() end
SetOverrideBindingClick = SetOverrideBindingClick or function() end
ClearOverrideBindings = ClearOverrideBindings or function() end

-- 3. WoW System & Timer APIs
GetTime = GetTime or function() return os.time() end
C_Timer = C_Timer or {
    After = function(sec, cb) if cb then cb() end end,
    NewTicker = function(sec, cb) return { Cancel = function() end } end,
}

-- 4. Load CLIAlts Addon Files in TOC order
local addon = {}
local files = { "data.lua", "minimap.lua", "ui.lua", "core.lua" }

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
