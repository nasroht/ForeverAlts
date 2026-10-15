-- ============================================================================
-- CLIAlts: Retro Alt Tracker
-- File: ui.lua
-- Pure Monospace ASCII / TUI Terminal Interface with data-driven columns,
-- single FontString rows, VT323 CRT terminal typography, and SetScale support.
-- ============================================================================

local addonName, addonTable = ...
local CLIAlts = addonTable or _G["CLIAlts"] or {}

-- ----------------------------------------------------------------------------
-- Constants & Terminal Configuration
-- ----------------------------------------------------------------------------
local FONT_PATH = "Interface\\AddOns\\" .. (addonName or "clialts") .. "\\media\\VT323-Regular.ttf"
local DEFAULT_FONT_SIZE = 18
local LINE_WIDTH = 110
local BORDER_LINE   = "+" .. string.rep("-", LINE_WIDTH - 2) .. "+"

local ROWS_COUNT = 8
local rowFrames = {}
local headerButtons = {}
local currentPage = 1
local totalPages = 1
local mainFrame = nil
local dossierPopup = nil
local customRolePopup = nil
local confirmPopup = nil
local helpPopup = nil
local exportPopup = nil
local settingsDialog = nil
local probeString = nil
local renderDirty = false

-- ----------------------------------------------------------------------------
-- CRT Theme Definitions (With Syntax Coloring Hex Codes)
-- ----------------------------------------------------------------------------
CLIAlts.THEMES = {
    ["BLIZZARD"] = {
        name = "World of Warcraft Best Practice",
        tag = "WOW",
        bg = { 0.043, 0.055, 0.078, 0.96 }, -- deep neutral charcoal slate #0B0E14
        panelBg = { 0.075, 0.090, 0.133, 0.92 }, -- elevated slate panel #131722
        border = { 0.165, 0.200, 0.278, 0.85 }, -- clean 1px border #2A3347
        primary = { 1.0, 0.820, 0.0 }, -- Blizzard Gold (NORMAL_FONT_COLOR) #FFD100
        dim = { 0.690, 0.722, 0.784 }, -- high-contrast readable cool silver #B0B8C8
        highlight = { 1.0, 0.90, 0.40 }, -- bright gold highlight #FFE566
        accent = { 0.20, 0.85, 1.0 }, -- Blizzard cyan #33D9FF
        ready = { 0.20, 1.0, 0.40 }, -- Blizzard green (GREEN_FONT_COLOR) #33FF66
        pending = { 1.0, 0.69, 0.20 }, -- Blizzard orange (ORANGE_FONT_COLOR) #FFB033
        blocked = { 1.0, 0.27, 0.27 }, -- Blizzard red (RED_FONT_COLOR) #FF4444
        rowOdd = { 0.071, 0.082, 0.122, 0.40 },
        rowEven = { 0.094, 0.114, 0.161, 0.60 },
        rowHover = { 0.145, 0.176, 0.239, 0.75 },
        borderHex = "2a3347",
        primaryHex = "ffd100", -- Blizzard Gold
        dimHex = "b0b8c8", -- readable cool silver
        highlightHex = "ffe566",
        textHex = "ffffff", -- crisp pure white
        mutedHex = "b0b8c8", -- secondary text silver
        accentHex = "33d9ff",
        readyHex = "33ff66",
        pendingHex = "ffb033",
        blockedHex = "ff4444",
        barFill = "|cff33d9ff",
        barEmpty = "|cff1c2230",
    },
    ["DARK"] = {
        name = "Dark Slate (Phase 1)",
        tag = "DRK",
        bg = { 0.059, 0.075, 0.102, 0.96 }, -- #0F131A
        panelBg = { 0.090, 0.110, 0.149, 0.92 }, -- #171C26
        border = { 0.169, 0.204, 0.271, 0.85 }, -- #2B3445
        primary = { 0.910, 0.714, 0.290 }, -- #E8B64A
        dim = { 0.604, 0.651, 0.722 }, -- #9AA6B8
        highlight = { 1.0, 0.85, 0.40 },
        accent = { 0.30, 0.76, 0.84 }, -- #4CC2D6
        ready = { 0.20, 1.0, 0.40 },
        pending = { 0.95, 0.72, 0.29 }, -- #F2B84B
        blocked = { 1.0, 0.27, 0.27 },
        rowOdd = { 0.090, 0.110, 0.149, 0.40 },
        rowEven = { 0.137, 0.169, 0.227, 0.60 },
        rowHover = { 0.169, 0.204, 0.271, 0.75 },
        borderHex = "2b3445",
        primaryHex = "e8b64a",
        dimHex = "9aa6b8",
        highlightHex = "ffd966",
        textHex = "f3f5f8",
        mutedHex = "9aa6b8",
        accentHex = "4cc2d6",
        readyHex = "33ff66",
        pendingHex = "f2b84b",
        blockedHex = "ff4444",
        barFill = "|cff4cc2d6",
        barEmpty = "|cff1a2230",
    },
    ["AMBER"] = {
        name = "VT220 Amber",
        tag = "AMB",
        bg = { 0.063, 0.055, 0.031, 0.96 }, -- near-black brown #100E08
        panelBg = { 0.098, 0.082, 0.047, 0.90 }, -- panel background #19150C
        border = { 0.949, 0.788, 0.298, 0.85 }, -- primary amber #F2C94C
        primary = { 0.949, 0.788, 0.298 }, -- #F2C94C
        dim = { 0.663, 0.627, 0.549 }, -- secondary text #A9A08C
        highlight = { 1.0, 0.827, 0.306 }, -- bright amber #FFD34E
        accent = { 0.341, 0.839, 0.910 }, -- cyan #57D6E8
        ready = { 0.333, 0.890, 0.604 }, -- green #55E39A
        pending = { 1.0, 0.710, 0.278 }, -- orange #FFB547
        blocked = { 1.0, 0.420, 0.420 }, -- red #FF6B6B
        rowOdd = { 0.098, 0.082, 0.047, 0.12 },
        rowEven = { 0.098, 0.082, 0.047, 0.32 },
        rowHover = { 0.949, 0.788, 0.298, 0.25 },
        borderHex = "f2c94c",
        primaryHex = "f2c94c",
        dimHex = "a9a08c",
        highlightHex = "ffd34e",
        textHex = "f4ead2", -- primary text #F4EAD2
        mutedHex = "a9a08c", -- secondary text #A9A08C
        accentHex = "57d6e8", -- cyan #57D6E8
        readyHex = "55e39a", -- green #55E39A
        pendingHex = "ffb547", -- orange #FFB547
        blockedHex = "ff6b6b", -- red #FF6B6B
        barFill = "|cfff2c94c",
        barEmpty = "|cff4d3d19",
    },
    ["GREEN"] = {
        name = "Phosphor CRT",
        tag = "GRN",
        bg = { 0.02, 0.05, 0.03, 0.96 },
        panelBg = { 0.04, 0.08, 0.05, 0.90 },
        border = { 0.0, 1.0, 0.4, 0.85 },
        primary = { 0.0, 1.0, 0.4 },
        dim = { 0.25, 0.65, 0.35 },
        highlight = { 0.6, 1.0, 0.7 },
        accent = { 0.341, 0.839, 0.910 },
        ready = { 0.333, 0.890, 0.604 },
        pending = { 1.0, 0.710, 0.278 },
        blocked = { 1.0, 0.420, 0.420 },
        rowOdd = { 0.04, 0.08, 0.05, 0.12 },
        rowEven = { 0.04, 0.08, 0.05, 0.32 },
        rowHover = { 0.0, 0.35, 0.15, 0.35 },
        borderHex = "00ff66",
        primaryHex = "00ff66",
        dimHex = "3fa859",
        highlightHex = "99ffb2",
        textHex = "e8ffe8",
        mutedHex = "5da671",
        accentHex = "57d6e8",
        readyHex = "55e39a",
        pendingHex = "ffb547",
        blockedHex = "ff6b6b",
        barFill = "|cff00ff66",
        barEmpty = "|cff1a6633",
    },
    ["CYAN"] = {
        name = "Cyberdeck Cyan",
        tag = "CYN",
        bg = { 0.02, 0.05, 0.07, 0.96 },
        panelBg = { 0.03, 0.08, 0.11, 0.90 },
        border = { 0.0, 0.85, 1.0, 0.85 },
        primary = { 0.2, 0.9, 1.0 },
        dim = { 0.2, 0.55, 0.75 },
        highlight = { 0.7, 1.0, 1.0 },
        accent = { 0.341, 0.839, 0.910 },
        ready = { 0.333, 0.890, 0.604 },
        pending = { 1.0, 0.710, 0.278 },
        blocked = { 1.0, 0.420, 0.420 },
        rowOdd = { 0.03, 0.08, 0.11, 0.12 },
        rowEven = { 0.03, 0.08, 0.11, 0.32 },
        rowHover = { 0.05, 0.25, 0.35, 0.35 },
        borderHex = "00d9ff",
        primaryHex = "33e6ff",
        dimHex = "338cbf",
        highlightHex = "b3ffff",
        textHex = "e0f7fc",
        mutedHex = "5695ab",
        accentHex = "57d6e8",
        readyHex = "55e39a",
        pendingHex = "ffb547",
        blockedHex = "ff6b6b",
        barFill = "|cff00e5ff",
        barEmpty = "|cff004f66",
    },
    ["MONO"] = {
        name = "VT100 Monochrome",
        tag = "MON",
        bg = { 0.04, 0.04, 0.04, 0.96 },
        panelBg = { 0.08, 0.08, 0.08, 0.90 },
        border = { 0.8, 0.8, 0.8, 0.85 },
        primary = { 0.9, 0.9, 0.9 },
        dim = { 0.5, 0.5, 0.5 },
        highlight = { 1.0, 1.0, 1.0 },
        accent = { 0.85, 0.85, 0.85 },
        ready = { 0.8, 0.95, 0.8 },
        pending = { 0.95, 0.85, 0.7 },
        blocked = { 0.95, 0.7, 0.7 },
        rowOdd = { 0.08, 0.08, 0.08, 0.12 },
        rowEven = { 0.08, 0.08, 0.08, 0.32 },
        rowHover = { 0.25, 0.25, 0.25, 0.35 },
        borderHex = "cccccc",
        primaryHex = "e6e6e6",
        dimHex = "808080",
        highlightHex = "ffffff",
        textHex = "f0f0f0",
        mutedHex = "999999",
        accentHex = "d9d9d9",
        readyHex = "55e39a",
        pendingHex = "ffb547",
        blockedHex = "ff6b6b",
        barFill = "|cffd8d8d8",
        barEmpty = "|cff555555",
    },
    ["COLORBLIND"] = {
        name = "Phosphor Safe",
        tag = "SAFE",
        bg = { 0.02, 0.04, 0.08, 0.96 },
        panelBg = { 0.04, 0.07, 0.14, 0.90 },
        border = { 0.25, 0.65, 1.0, 0.85 },
        primary = { 0.35, 0.75, 1.0 },
        dim = { 0.40, 0.58, 0.78 },
        highlight = { 1.0, 0.85, 0.2 },
        accent = { 1.0, 0.85, 0.2 },
        ready = { 0.35, 0.75, 1.0 },
        pending = { 1.0, 0.85, 0.2 },
        blocked = { 0.95, 0.45, 0.2 },
        rowOdd = { 0.04, 0.07, 0.14, 0.12 },
        rowEven = { 0.04, 0.07, 0.14, 0.32 },
        rowHover = { 0.08, 0.20, 0.38, 0.35 },
        borderHex = "40a6ff",
        primaryHex = "59bfff",
        dimHex = "6694c7",
        highlightHex = "ffd933",
        textHex = "e6f2ff",
        mutedHex = "7aa3cc",
        accentHex = "ffd933",
        readyHex = "59bfff",
        pendingHex = "ffd933",
        blockedHex = "f27333",
        barFill = "|cff40a6ff",
        barEmpty = "|cff14334d",
    },
    ["SYNTHWAVE"] = {
        name = "Synthwave CRT",
        tag = "SYN",
        bg = { 0.06, 0.02, 0.08, 0.96 },
        panelBg = { 0.10, 0.03, 0.13, 0.90 },
        border = { 1.0, 0.20, 0.60, 0.85 },
        primary = { 1.0, 0.35, 0.70 },
        dim = { 0.65, 0.25, 0.65 },
        highlight = { 0.20, 0.95, 1.0 },
        accent = { 0.20, 0.95, 1.0 },
        ready = { 0.20, 0.95, 1.0 },
        pending = { 1.0, 0.75, 0.20 },
        blocked = { 1.0, 0.25, 0.35 },
        rowOdd = { 0.10, 0.03, 0.13, 0.12 },
        rowEven = { 0.10, 0.03, 0.13, 0.32 },
        rowHover = { 0.35, 0.12, 0.35, 0.35 },
        borderHex = "ff3399",
        primaryHex = "ff59b2",
        dimHex = "a640a6",
        highlightHex = "33f2ff",
        textHex = "ffe6f2",
        mutedHex = "b36b9e",
        accentHex = "33f2ff",
        readyHex = "33f2ff",
        pendingHex = "ffc033",
        blockedHex = "ff4059",
        barFill = "|cffff3399",
        barEmpty = "|cff4d1433",
    },
    ["DRACULA"] = {
        name = "Dracula Terminal",
        tag = "DRA",
        bg = { 0.05, 0.05, 0.08, 0.96 },
        panelBg = { 0.09, 0.09, 0.14, 0.90 },
        border = { 0.74, 0.58, 0.98, 0.85 },
        primary = { 0.95, 0.95, 0.96 },
        dim = { 0.38, 0.44, 0.64 },
        highlight = { 0.31, 0.98, 0.48 },
        accent = { 0.55, 0.91, 0.99 },
        ready = { 0.31, 0.98, 0.48 },
        pending = { 1.0, 0.72, 0.42 },
        blocked = { 1.0, 0.33, 0.33 },
        rowOdd = { 0.09, 0.09, 0.14, 0.12 },
        rowEven = { 0.09, 0.09, 0.14, 0.32 },
        rowHover = { 0.28, 0.30, 0.42, 0.35 },
        borderHex = "bd93f9",
        primaryHex = "f8f8f2",
        dimHex = "6272a4",
        highlightHex = "50fa7b",
        textHex = "f8f8f2",
        mutedHex = "6272a4",
        accentHex = "8be9fd",
        readyHex = "50fa7b",
        pendingHex = "ffb86c",
        blockedHex = "ff5555",
        barFill = "|cffbd93f9",
        barEmpty = "|cff382b4a",
    },
}

CLIAlts.THEME_MAP = {
    blizzard = "BLIZZARD",
    blizz = "BLIZZARD",
    wow = "BLIZZARD",
    dark = "DARK",
    drk = "DARK",
    default = "BLIZZARD",
    amber = "AMBER",
    amb = "AMBER",
    green = "GREEN",
    grn = "GREEN",
    cyan = "CYAN",
    cyn = "CYAN",
    mono = "MONO",
    safe = "COLORBLIND",
    colorblind = "COLORBLIND",
    cb = "COLORBLIND",
    synthwave = "SYNTHWAVE",
    syn = "SYNTHWAVE",
    dracula = "DRACULA",
    dra = "DRACULA",
}

local THEME_ORDER = { "BLIZZARD", "AMBER", "GREEN", "CYAN", "MONO", "COLORBLIND", "SYNTHWAVE", "DRACULA" }
local SCALES = { 0.8, 0.9, 1.0, 1.15, 1.3, 1.45 }

function CLIAlts:GetTheme()
    local key = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.theme) or "BLIZZARD"
    local t = self.THEMES[key] or self.THEMES["BLIZZARD"] or self.THEMES["AMBER"]
    -- Ensure non-nil fallbacks for design tokens
    t.text = t.text or { 1.0, 1.0, 1.0 }
    t.muted = t.muted or t.dim or { 0.690, 0.722, 0.784 }
    t.textHex = t.textHex or "ffffff"
    t.mutedHex = t.mutedHex or t.dimHex or "b0b8c8"
    t.dimHex = t.dimHex or "b0b8c8"
    t.accentHex = t.accentHex or "33d9ff"
    t.readyHex = t.readyHex or "33ff66"
    t.pendingHex = t.pendingHex or "ffb033"
    t.blockedHex = t.blockedHex or "ff4444"
    t.panelBg = t.panelBg or { 0.075, 0.090, 0.133, 0.92 }
    t.rowOdd = t.rowOdd or { 0.071, 0.082, 0.122, 0.40 }
    t.rowEven = t.rowEven or { 0.094, 0.114, 0.161, 0.60 }
    t.rowHover = t.rowHover or { 0.145, 0.176, 0.239, 0.75 }
    return t
end

function CLIAlts:CycleTheme()
    local current = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.theme) or "BLIZZARD"
    local nextTheme = "BLIZZARD"
    for i, name in ipairs(THEME_ORDER) do
        if name == current then
            nextTheme = THEME_ORDER[(i % #THEME_ORDER) + 1]
            break
        end
    end
    CLIAltsDB.settings.theme = nextTheme
    CLIAltsDB.settings.themeExplicit = true
    self:ApplyTheme()
    self:Render()
end

-- ----------------------------------------------------------------------------
-- Typography & Monospace Helpers
-- ----------------------------------------------------------------------------
function CLIAlts:SetWidgetFont(fontString, size, flags)
    if not fontString or not fontString.SetFont then return end
    size = size or (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.fontSize) or DEFAULT_FONT_SIZE
    if not flags or type(flags) ~= "string" or flags == "BOLD" then
        flags = ""
    end
    local setOk = false
    pcall(function()
        setOk = fontString:SetFont(FONT_PATH, size, flags)
    end)
    if not setOk then
        pcall(function()
            local fallback = _G["STANDARD_TEXT_FONT"] or "Fonts\\FRIZQT__.TTF"
            setOk = fontString:SetFont(fallback, size, flags)
        end)
    end
    if not setOk then
        pcall(function()
            local fallback = _G["STANDARD_TEXT_FONT"] or "Fonts\\FRIZQT__.TTF"
            fontString:SetFont(fallback, size, "")
        end)
    end
    local hasFont = false
    pcall(function()
        if fontString.GetFont and fontString:GetFont() then
            hasFont = true
        end
    end)
    if not hasFont and fontString.SetFontObject then
        pcall(function()
            fontString:SetFontObject("GameFontHighlight")
        end)
    end
end

function CLIAlts:GetCharWidth(fontSize)
    local sz = fontSize or (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.fontSize) or DEFAULT_FONT_SIZE
    if not probeString and mainFrame then
        probeString = mainFrame:CreateFontString(nil, "BACKGROUND")
        probeString:Hide()
    end
    if probeString then
        self:SetWidgetFont(probeString, sz)
        probeString:SetText("==================================================")
        local w = probeString:GetStringWidth()
        if w and w > 0 then
            local perChar = w / 50
            if perChar >= 4 and perChar <= 25 then
                return perChar
            end
        end
    end
    return sz * 0.54
end

function CLIAlts:GetBarString(charPattern, targetPixelWidth, fontSize)
    targetPixelWidth = targetPixelWidth or (mainFrame and (mainFrame:GetWidth() - 24)) or 1126
    local sz = fontSize or (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.fontSize) or DEFAULT_FONT_SIZE
    local charW = self:GetCharWidth(sz)
    if not charW or charW < 4 or charW > 25 then
        charW = sz * 0.54
    end
    local count = math.floor(targetPixelWidth / charW)
    if count < 10 then count = 10 end
    return "+" .. string.rep(charPattern, math.max(2, count - 2)) .. "+"
end

-- ----------------------------------------------------------------------------
-- Audio & Button Helpers
-- ----------------------------------------------------------------------------
local function PlayRetroSound()
    if CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.soundDisabled then return end
    pcall(function()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        elseif PlaySound then
            pcall(PlaySound, 856)
        end
    end)
end

local function CreateRetroButton(parent, text, width, height, onClick, fontSz)
    local btn = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    btn:SetSize(width or 80, height or 20)

    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    local t = CLIAlts:GetTheme()
    local pBg = t.panelBg or { 0.098, 0.082, 0.047, 0.90 }
    if btn.SetBackdropColor then
        btn:SetBackdropColor(pBg[1], pBg[2], pBg[3], 0.75)
    end
    if btn.SetBackdropBorderColor then
        btn:SetBackdropBorderColor(t.dim[1], t.dim[2], t.dim[3], 0.8)
    end

    local label = btn:CreateFontString(nil, "OVERLAY")
    CLIAlts:SetWidgetFont(label, fontSz or 12, "")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text or "")
    label:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        local curT = CLIAlts:GetTheme()
        if self.SetBackdropColor then
            self:SetBackdropColor(curT.border[1], curT.border[2], curT.border[3], 0.25)
        end
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(curT.primary[1], curT.primary[2], curT.primary[3], 1)
        end
        self.label:SetTextColor(curT.highlight[1], curT.highlight[2], curT.highlight[3])
    end)

    btn:SetScript("OnLeave", function(self)
        local curT = CLIAlts:GetTheme()
        local curBg = curT.panelBg or { 0.098, 0.082, 0.047, 0.90 }
        if self.isSelected then
            if self.SetBackdropColor then
                self:SetBackdropColor(curT.border[1], curT.border[2], curT.border[3], 0.35)
            end
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(curT.primary[1], curT.primary[2], curT.primary[3], 1)
            end
            self.label:SetTextColor(curT.highlight[1], curT.highlight[2], curT.highlight[3])
        else
            if self.SetBackdropColor then
                self:SetBackdropColor(curBg[1], curBg[2], curBg[3], 0.75)
            end
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(curT.dim[1], curT.dim[2], curT.dim[3], 0.8)
            end
            self.label:SetTextColor(curT.primary[1], curT.primary[2], curT.primary[3])
        end
    end)

    if onClick then
        btn:SetScript("OnClick", function(self, button)
            PlayRetroSound()
            onClick(self, button)
        end)
    end

    return btn
end

-- ----------------------------------------------------------------------------
-- UTF-8 Initial Extraction Helper
-- Handles multi-byte characters such as Å in Åse, ö in östen
-- ----------------------------------------------------------------------------
function CLIAlts:GetFirstLetter(name)
    if not name or name == "" then return "?" end
    local b = name:byte(1)
    if not b then return "?" end
    if b < 128 then
        return name:sub(1, 1):upper()
    elseif b >= 192 and b <= 223 then
        return name:sub(1, 2)
    elseif b >= 224 and b <= 239 then
        return name:sub(1, 3)
    elseif b >= 240 then
        return name:sub(1, 4)
    end
    return name:sub(1, 1):upper()
end

-- ----------------------------------------------------------------------------
-- Status Pill Formatter (Phase 2/3 Modern Rows)
-- Returns text and style ("warn_fill", "info_outline", "muted_outline", "dashed_muted")
-- ----------------------------------------------------------------------------
function CLIAlts:FmtStatus(char, t)
    -- Allow call with either dot or colon syntax
    if self ~= CLIAlts and char == nil and type(self) == "table" and (self.name or self.level) then
        char = self
        self = CLIAlts
    end
    if not char then return "---", "muted_outline" end
    local maxLevel = self.GetMaxLevel and self:GetMaxLevel() or 60
    local level = char.level or 1
    if level >= maxLevel then
        return "No rest XP", "muted_outline"
    end

    local now = time()
    local lastSeen = char.lastUpdate or char.logoutTime or char.lastSeen or now
    local unseenDays = math.floor((now - lastSeen) / 86400)
    local staleDays = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.staleDays)) or 30

    if unseenDays >= staleDays or char.isStale then
        return string.format("Unseen %dd", math.max(unseenDays, 1)), "dashed_muted"
    end

    local wastedSec, _, _, timeStr = self:GetRestedWaste(char, now)
    local rested = self:GetRestedData(char, false, now)

    if (wastedSec and wastedSec > 0) or (rested and rested.isFull) then
        local dur = timeStr or "0m"
        dur = dur:gsub(" 0h$", ""):gsub(" 0m$", "")
        if dur == "Just capped" then dur = "0m" end
        return "Losing " .. dur, "warn_fill"
    end

    if rested and not rested.isMaxLevel then
        local sec = rested.timeToFull or rested.timeLeftSec or 0
        local dur
        if sec > 0 then
            local days = math.floor(sec / 86400)
            local hours = math.floor((sec % 86400) / 3600)
            local mins = math.floor((sec % 3600) / 60)
            if days > 0 then
                dur = string.format("%dd", days)
            elseif hours > 0 then
                dur = string.format("%dh", hours)
            elseif mins > 0 then
                dur = string.format("%dm", mins)
            else
                dur = "<1m"
            end
        else
            dur = rested.timeLeftStr or "---"
        end

        if sec > 0 and sec < 86400 then
            return "Cap in " .. dur, "info_outline"
        elseif sec >= 86400 then
            return "Cap in " .. dur, "muted_outline"
        end
    end

    return "No rest XP", "muted_outline"
end

-- ----------------------------------------------------------------------------
-- Rows Per Page Helper
-- ----------------------------------------------------------------------------
function CLIAlts:GetRowsPerPage()
    if mainFrame and mainFrame.isLegacyUI then
        return 8
    end
    local activeTab = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.activeTab) or 1
    if activeTab > 1 then
        return 10
    end
    return 8
end

function CLIAlts:GetRowFrames()
    return rowFrames
end

-- ----------------------------------------------------------------------------
-- Play Next Banner (Phase 4 Modern Overview)
-- ----------------------------------------------------------------------------
function CLIAlts:UpdatePlayNextBanner()
    local banner = mainFrame and mainFrame.nextBanner
    if not banner or not banner:IsShown() then return end

    local brandR, brandG, brandB = self:Hex("brand")
    local warnR, warnG, warnB = self:Hex("warn")
    local fillR, fillG, fillB = self:Hex("fill")
    local textR, textG, textB = self:Hex("text")
    local mutedR, mutedG, mutedB = self:Hex("muted")

    local bannerW = banner:GetWidth() or 700
    local cardW = math.floor((bannerW - 24 - 16) / 3)
    if cardW < 120 then cardW = 120 end

    local priorityList = self:GetNextAltsPriority()
    local losingCount = 0
    local allChars = self:GetCharactersList()
    for _, c in ipairs(allChars) do
        local wastedSec = self:GetRestedWaste(c)
        if wastedSec and wastedSec > 0 then
            losingCount = losingCount + 1
        end
    end

    if banner.title then
        banner.title:SetTextColor(brandR, brandG, brandB)
    end

    -- 1. Headline ("<n> alts are losing rested XP right now", hides when n is 0)
    if banner.headline then
        if losingCount > 0 then
            local headStr = (losingCount == 1) and "1 alt is losing rested XP right now" or string.format("%d alts are losing rested XP right now", losingCount)
            banner.headline:SetText(headStr)
            banner.headline:SetTextColor(warnR, warnG, warnB)
            banner.headline:Show()
        else
            banner.headline:Hide()
        end
    end

    -- 2. Cards & Empty State ("Nothing is being wasted")
    if #priorityList == 0 then
        if banner.emptyText then
            banner.emptyText:SetText("Nothing is being wasted")
            banner.emptyText:SetTextColor(mutedR, mutedG, mutedB)
            banner.emptyText:Show()
        end
        if banner.cards then
            for i = 1, 3 do
                banner.cards[i]:Hide()
            end
        end
        if banner.planLine then
            banner.planLine:Hide()
        end
        return
    else
        if banner.emptyText then
            banner.emptyText:Hide()
        end
    end

    for i = 1, 3 do
        local card = banner.cards and banner.cards[i]
        local item = priorityList[i]
        if card then
            card:SetWidth(cardW)
            if item and item.char then
                local char = item.char
                card.charData = char

                local classFile = char.classFile or "WARRIOR"
                local cr, cg, cb = self:GetClassColor(classFile)
                local class = char.class or char.className or classFile

                if card.title then
                    card.title:SetText(string.format("%d. %s", i, char.name or "Unknown"))
                    card.title:SetTextColor(cr, cg, cb)
                end

                if card.meta then
                    card.meta:SetText(string.format("%d %s", char.level or 1, class))
                    card.meta:SetTextColor(mutedR, mutedG, mutedB)
                end

                if card.reason then
                    if item.wastedSec and item.wastedSec > 0 then
                        local dur = item.timeStr or "0m"
                        dur = dur:gsub(" 0h$", ""):gsub(" 0m$", "")
                        if dur == "Just capped" then dur = "0m" end
                        local lostXP = self:FormatWasteShort(item.wastedXP) .. " XP"
                        card.reason:SetText(string.format("Capped %s · ~%s lost", dur, lostXP))
                        card.reason:SetTextColor(warnR, warnG, warnB)
                    elseif item.isCapped then
                        card.reason:SetText(string.format("Capped (%d%%) · Ready to play", item.maxPercent or 150))
                        card.reason:SetTextColor(warnR, warnG, warnB)
                    else
                        local rested = self:GetRestedData(char)
                        local timeLeftStr = (rested and rested.timeLeftStr) or "---"
                        card.reason:SetText(string.format("Caps in %s", timeLeftStr))
                        card.reason:SetTextColor(fillR, fillG, fillB)
                    end
                end

                card:Show()
            else
                card.charData = nil
                card:Hide()
            end
        end
    end

    -- 3. Plan Line (default 2h, hidden in compact mode)
    if banner.planLine then
        if self:IsCompact() then
            banner.planLine:Hide()
        else
            local schedule = self:GenerateLevelingPlan(2)
            if schedule and #schedule > 0 then
                local planParts = {}
                local totalPlanXP = 0
                for _, cand in ipairs(schedule) do
                    table.insert(planParts, string.format("%s %dm", cand.name, cand.mins))
                    local xpHour = cand.xpHour or 35000
                    totalPlanXP = totalPlanXP + math.floor((xpHour * (cand.mins / 60)) * 2)
                end
                local planAltsStr = table.concat(planParts, ", then ")
                local xpStr = self:FormatWasteShort(totalPlanXP) .. " XP"
                banner.planLine:SetText(string.format("2h plan: %s · about %s, none wasted", planAltsStr, xpStr))
                banner.planLine:SetTextColor(textR, textG, textB)
                banner.planLine:Show()
            else
                banner.planLine:SetText("2h plan: All active alts rested · Nothing is being wasted")
                banner.planLine:SetTextColor(mutedR, mutedG, mutedB)
                banner.planLine:Show()
            end
        end
    end
end

-- ----------------------------------------------------------------------------
-- Sidebar Badges Engine (Phase 5)
-- ----------------------------------------------------------------------------
function CLIAlts:GetSidebarBadgeCounts(nowOverride)
    if self._cachedSidebarBadges then
        return self._cachedSidebarBadges
    end
    local now = nowOverride or time()
    local digest = self.GetLoginDigestItems and self:GetLoginDigestItems(now)
    local chars = self.GetCharactersList and self:GetCharactersList() or {}
    local mailSummary = self._cachedMailReadySummary or (self.GetMailReadySummary and self:GetMailReadySummary())
    local counts = {
        overview = #chars,
        rested = (digest and digest.losingAlts) or 0,
        cooldowns = (digest and ((digest.readyCooldowns or 0) + (digest.unlockedRaids or 0))) or 0,
        mail = (mailSummary and mailSummary.totalPackages) or 0,
    }
    self._cachedSidebarBadges = counts
    return counts
end

-- ----------------------------------------------------------------------------
-- Filter Chips & Sort Engine (Phase 5)
-- ----------------------------------------------------------------------------
local SORT_CYCLE = { "rested", "level", "name", "waste", "gold" }

function CLIAlts:CycleSort()
    local cur = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.sortBy) or "rested"
    local nextKey = "rested"
    for i, k in ipairs(SORT_CYCLE) do
        if k == cur then
            nextKey = SORT_CYCLE[(i % #SORT_CYCLE) + 1]
            break
        end
    end
    self:ToggleSortKey(nextKey)
end

function CLIAlts:UpdateFilterChips()
    if not mainFrame or not mainFrame.filterChips then return end

    local activeTab = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.activeTab) or 1
    if activeTab == 7 then
        if mainFrame.filterChipsBar then mainFrame.filterChipsBar:Hide() end
        if mainFrame.mailActionBar then mainFrame.mailActionBar:Show() end
        return
    else
        if mainFrame.mailActionBar then mainFrame.mailActionBar:Hide() end
        if mainFrame.filterChipsBar then mainFrame.filterChipsBar:Show() end
    end

    local brandR, brandG, brandB = self:Hex("brand")
    local raisedR, raisedG, raisedB = self:Hex("raised")
    local panelR, panelG, panelB = self:Hex("panel")
    local lineR, lineG, lineB = self:Hex("line")
    local mutedR, mutedG, mutedB = self:Hex("muted")

    -- Character counts for each filter chip
    local allChars = self.GetCharactersList and self:GetCharactersList(nil, nil, nil) or {}
    local countAll = #allChars
    local countHorde = 0
    local countAlliance = 0
    local countCapped = 0
    local countUnder60 = 0
    local countHasNote = 0
    local maxLvl = self.GetMaxLevel and self:GetMaxLevel() or 60

    for _, c in ipairs(allChars) do
        if c.faction == "Horde" then countHorde = countHorde + 1 end
        if c.faction == "Alliance" then countAlliance = countAlliance + 1 end
        local r = self.GetRestedData and self:GetRestedData(c)
        if r and r.isFull then countCapped = countCapped + 1 end
        if (c.level or 1) < maxLvl then countUnder60 = countUnder60 + 1 end
        if c.note and c.note ~= "" and c.note:match("%S") then countHasNote = countHasNote + 1 end
    end

    local counts = {
        [1] = countAll,
        [2] = countHorde,
        [3] = countAlliance,
        [4] = countCapped,
        [5] = countUnder60,
        [6] = countHasNote,
    }

    local curFilter = self.activeFilter
    local q = curFilter and curFilter:lower():match("^%s*(.-)%s*$") or ""

    for i, chip in ipairs(mainFrame.filterChips) do
        local count = counts[i] or 0
        local chipLabel = string.format("%s %d", chip.baseLabel, count)
        chip.label:SetText(chipLabel)
        local strW = (chip.label.GetStringWidth and chip.label:GetStringWidth()) or 40
        chip:SetWidth(math.max(48, math.floor(strW + 16)))

        -- Determine if this chip is active
        local isActive = false
        if i == 1 then
            isActive = (q == "" or curFilter == nil)
        elseif i == 2 then
            isActive = (q == "horde" or q == "h")
        elseif i == 3 then
            isActive = (q == "alliance" or q == "ally" or q == "a")
        elseif i == 4 then
            isActive = (q == "capped" or q == "cap")
        elseif i == 5 then
            isActive = (q == "under 60" or q == "under60" or q == "<60")
        elseif i == 6 then
            isActive = (q == "has note" or q == "hasnote" or q == "with note")
        end
        chip.isActive = isActive

        if isActive then
            if chip.SetBackdropColor then chip:SetBackdropColor(raisedR, raisedG, raisedB, 1.0) end
            if chip.SetBackdropBorderColor then chip:SetBackdropBorderColor(brandR, brandG, brandB, 1.0) end
            chip.label:SetTextColor(brandR, brandG, brandB)
        else
            if chip.SetBackdropColor then chip:SetBackdropColor(panelR, panelG, panelB, 0.8) end
            if chip.SetBackdropBorderColor then chip:SetBackdropBorderColor(lineR, lineG, lineB, 0.8) end
            chip.label:SetTextColor(mutedR, mutedG, mutedB)
        end
    end

    -- Update Sort Button Text
    if mainFrame.btnSort and mainFrame.btnSort.label then
        local curSort = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.sortBy) or "Rested"
        local sortTitle = curSort:sub(1,1):upper() .. curSort:sub(2)
        mainFrame.btnSort.label:SetText(string.format("Sort: %s ▾", sortTitle))
    end
end

-- ----------------------------------------------------------------------------
-- Window Position Persistence
-- ----------------------------------------------------------------------------
function CLIAlts:SaveWindowPosition(frame)
    frame = frame or mainFrame
    if not frame then return end
    if not CLIAltsDB then return end
    CLIAltsDB.settings = CLIAltsDB.settings or {}

    local point, _, relPoint, x, y = frame:GetPoint(1)
    if point and x and y then
        CLIAltsDB.settings.windowPos = {
            point = point,
            relPoint = relPoint or point,
            x = math.floor(x + 0.5),
            y = math.floor(y + 0.5),
        }
    end
end

function CLIAlts:RestoreWindowPosition(frame)
    frame = frame or mainFrame
    if not frame then return end

    frame:ClearAllPoints()
    local pos = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.windowPos
    local valid = false
    if pos and type(pos) == "table" and pos.point and type(pos.x) == "number" and type(pos.y) == "number" then
        if pos.x == pos.x and pos.y == pos.y and math.abs(pos.x) < 5000 and math.abs(pos.y) < 5000 then
            local ok = pcall(function()
                frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)
            end)
            if ok then valid = true end
        end
    end
    if not valid then
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- ----------------------------------------------------------------------------
-- Scale & Font Size API
-- ----------------------------------------------------------------------------
function CLIAlts:SetScale(scale)
    scale = tonumber(scale) or 1.0
    scale = math.min(1.8, math.max(0.7, scale))
    if CLIAltsDB and CLIAltsDB.settings then
        CLIAltsDB.settings.scale = scale
    end
    if mainFrame then
        mainFrame:SetScale(scale)
        if mainFrame.btnScale then
            mainFrame.btnScale.label:SetText(string.format("[ SCALE: %d%% ]", math.floor(scale * 100 + 0.5)))
        end
    end
end

function CLIAlts:CycleScale()
    local cur = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.scale) or 1.0
    local nextScale = 1.0
    for i, s in ipairs(SCALES) do
        if math.abs(s - cur) < 0.05 then
            nextScale = SCALES[(i % #SCALES) + 1]
            break
        end
    end
    self:SetScale(nextScale)
    self:Render()
end

function CLIAlts:SetFontSize(size)
    size = tonumber(size) or DEFAULT_FONT_SIZE
    size = math.min(24, math.max(12, size))
    if CLIAltsDB and CLIAltsDB.settings then
        CLIAltsDB.settings.fontSize = size
    end
    if mainFrame then
        self:UpdateAllFonts(size)
        self:Render()
    end
end

function CLIAlts:UpdateAllFonts(fontSize)
    if not mainFrame then return end
    fontSize = fontSize or (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.fontSize) or DEFAULT_FONT_SIZE

    self:SetWidgetFont(mainFrame.topAscii, fontSize)
    self:SetWidgetFont(mainFrame.titleText, fontSize + 1, "OUTLINE")
    self:SetWidgetFont(mainFrame.midAscii1, fontSize)
    self:SetWidgetFont(mainFrame.statusBarText, fontSize)
    self:SetWidgetFont(mainFrame.midAscii2, fontSize)
    self:SetWidgetFont(mainFrame.tableTopAscii, fontSize)
    if mainFrame.headerBorderL then self:SetWidgetFont(mainFrame.headerBorderL, fontSize) end
    if mainFrame.headerBorderR then self:SetWidgetFont(mainFrame.headerBorderR, fontSize) end
    for _, hCell in ipairs(mainFrame.headerCells or {}) do
        self:SetWidgetFont(hCell, fontSize)
    end
    self:SetWidgetFont(mainFrame.tableSepAscii, fontSize)
    self:SetWidgetFont(mainFrame.tableBotAscii, fontSize)
    self:SetWidgetFont(mainFrame.botAscii, fontSize)
    self:SetWidgetFont(mainFrame.pageText, fontSize)
    self:SetWidgetFont(mainFrame.statusTip, fontSize)

    for _, row in ipairs(rowFrames) do
        if row.borderL then self:SetWidgetFont(row.borderL, fontSize) end
        if row.borderR then self:SetWidgetFont(row.borderR, fontSize) end
        for _, cell in ipairs(row.cells or {}) do
            self:SetWidgetFont(cell, fontSize)
        end
    end
end

-- ----------------------------------------------------------------------------
-- Data-Driven Column Formatters (fmt)
-- ----------------------------------------------------------------------------
local function FmtFaction(char, t)
    t = t or CLIAlts:GetTheme()
    local fac = char.faction or "Neutral"
    if fac == "Alliance" then
        return string.format("|cff%s[A]|r", t.accentHex or "57d6e8")
    elseif fac == "Horde" then
        return string.format("|cff%s[H]|r", t.blockedHex or "ff6b6b")
    else
        return string.format("|cff%s[-]|r", t.mutedHex or "a9a08c")
    end
end

local function FmtName(char, t)
    t = t or CLIAlts:GetTheme()
    local name = char.name or char.fullName or "Unknown"
    local _, _, _, hex = CLIAlts:GetClassColor(char.classFile)
    local isStale = CLIAlts.IsCharStale and CLIAlts:IsCharStale(char)
    local isCur = (char.fullName and char.fullName == CLIAlts.curPlayerFullName) or (char.name and char.name == CLIAlts.curPlayerName)
    local curPrefix = isCur and string.format("|cff%s*|r", t.accentHex or "57d6e8") or ""
    local classTag = ""
    if char.class and char.class ~= "" and (#name + #char.class <= 15) then
        classTag = string.format(" |cff%s%s|r", t.mutedHex or "a9a08c", char.class:sub(1, 4))
    end
    if isStale then
        return string.format("%s|cff%s%s|r%s |cff%s[S]|r", curPrefix, hex, name, classTag, t.blockedHex or "ff6b6b")
    end
    return string.format("%s|cff%s%s|r%s", curPrefix, hex, name, classTag)
end

local function FmtLevel(char, t)
    t = t or CLIAlts:GetTheme()
    local lvl = char.level or 1
    local isMax = lvl >= CLIAlts:GetMaxLevel()
    if isMax then
        return string.format("|cff%s%d|r", t.highlightHex or "ffd34e", lvl)
    end
    return string.format("|cff%s%d|r", t.textHex or "f4ead2", lvl)
end

local function FmtGold(char)
    local gold = math.floor((char.money or 0) / 10000)
    return "|cffffd700" .. CLIAlts:FormatNumber(gold) .. "g|r"
end
CLIAlts.FmtGold = FmtGold

local function FmtRested(char, t)
    t = t or CLIAlts:GetTheme()
    local rested = CLIAlts:GetRestedData(char)
    if not rested then return string.format("|cff%s---|r", t.mutedHex or "a9a08c") end
    if rested.isMaxLevel then return string.format("|cff%sMAX|r", t.mutedHex or "a9a08c") end

    local est = rested.isEstimate and "~" or ""
    if rested.isFull then
        return string.format("|cff%s%d%%* [CAP]|r", t.highlightHex, rested.percent)
    else
        return string.format("|cff%s%d%%%s|r", t.primaryHex, rested.percent, est)
    end
end

local function FmtETA(char, t)
    t = t or CLIAlts:GetTheme()
    local text, style = CLIAlts:FmtStatus(char, t)
    if style == "warn_fill" or style == "warn" then
        return string.format("|cff%s%s|r", t.pendingHex or "ffb547", text)
    elseif style == "info_outline" or style == "info" then
        return string.format("|cff%s%s|r", t.accentHex or "7fdbff", text)
    else -- muted_outline or dashed_muted
        return string.format("|cff%s%s|r", t.mutedHex or "a9a08c", text)
    end
end
CLIAlts.FmtETA = FmtETA

-- Tab 2 Forever Route & Rotation Formatters
local function FmtRouteOrder(char, t)
    t = t or CLIAlts:GetTheme()
    local priorityList = CLIAlts._cachedPriorityList or CLIAlts:GetNextAltsPriority()
    local charKey = char.fullName or char.name
    for idx, item in ipairs(priorityList) do
        local k = item.char and (item.char.fullName or item.char.name)
        if k == charKey then
            if idx == 1 then
                return string.format("|cff%s[#1]|r", t.highlightHex or "ffd34e")
            elseif idx <= 3 then
                return string.format("|cff%s#%d|r", t.primaryHex or "f2c94c", idx)
            else
                return string.format("|cff%s#%d|r", t.textHex or "f4ead2", idx)
            end
        end
    end
    if char.tier == "BANK" then
        return string.format("|cff%s[B]|r", t.dimHex or "736953")
    end
    local maxLvl = CLIAlts:GetMaxLevel()
    local tgt = char.target_level or (char.tier == "CORE" and 35) or (char.tier == "RESERVE" and 25) or maxLvl
    if (char.level or 1) >= tgt then
        return string.format("|cff%s[OK]|r", t.readyHex or "55e39a")
    end
    return string.format("|cff%s[-]|r", t.mutedHex or "a9a08c")
end

local function FmtRotationScore(char, t)
    t = t or CLIAlts:GetTheme()
    if char.tier == "BANK" then
        return string.format("|cff%sEXCLUDED|r", t.dimHex or "736953")
    end
    local score = CLIAlts:CalculateRotationScore(char)
    if score < -400000 and score > -600000 then
        return string.format("|cff%sTARGET HIT|r", t.readyHex or "55e39a")
    elseif score < -900000 then
        return string.format("|cff%sBANK MULE|r", t.dimHex or "736953")
    elseif score >= 1000000 then
        local kScore = math.floor(score / 1000)
        return string.format("|cff%s+%sk|r", t.highlightHex or "ffd34e", CLIAlts:FormatNumber(kScore))
    elseif score > 0 then
        local kScore = math.floor(score / 1000)
        return string.format("|cff%s+%sk|r", t.primaryHex or "f2c94c", CLIAlts:FormatNumber(kScore))
    else
        return string.format("|cff%s%d|r", t.mutedHex or "a9a08c", score)
    end
end

local function FmtRouteReason(char, t)
    t = t or CLIAlts:GetTheme()
    if char.tier == "BANK" then
        if mainFrame and not mainFrame.isLegacyUI then
            return string.format("|cff%sBank Mule (Excluded)|r", t.dimHex or "736953")
        end
        return string.format("|cff%sDesignated Bank Mule (Excluded from leveling)|r", t.dimHex or "736953")
    end
    local maxLvl = CLIAlts:GetMaxLevel()
    local defaultTgt = (char.tier == "CORE" and 35) or (char.tier == "RESERVE" and 25) or maxLvl
    local tgt = char.target_level or defaultTgt
    if (char.level or 1) >= tgt then
        if mainFrame and not mainFrame.isLegacyUI then
            return string.format("|cff%sTarget Level Reached (L%d >= %d)|r", t.readyHex or "55e39a", char.level or 1, tgt)
        end
        return string.format("|cff%sTarget Level Reached (Lvl %d >= %d) - rotation complete|r", t.readyHex or "55e39a", char.level or 1, tgt)
    end

    local rested = CLIAlts:GetRestedData(char)
    local _, wastedXP = CLIAlts:GetRestedWaste(char, nil, rested)
    if rested and rested.isFull then
        if wastedXP and wastedXP > 0 then
            if mainFrame and not mainFrame.isLegacyUI then
                return string.format("|cff%s! CAPPED: +%s XP waste!|r", t.pendingHex or "ffb547", CLIAlts:FormatNumber(wastedXP))
            end
            return string.format("|cff%s! CAPPED: Overflowing (+%s XP waste) - Play now!|r", t.pendingHex or "ffb547", CLIAlts:FormatNumber(wastedXP))
        else
            if mainFrame and not mainFrame.isLegacyUI then
                return string.format("|cff%s* CAPPED: %d%% Rested pool ready|r", t.highlightHex or "ffd34e", rested.maxPercent or 150)
            end
            return string.format("|cff%s* CAPPED: %d%% Rested pool ready for double XP|r", t.highlightHex or "ffd34e", rested.maxPercent or 150)
        end
    elseif char.tier == "CORE" then
        local xpStr = rested and CLIAlts:FormatNumber(rested.currentRested) or "0"
        if mainFrame and not mainFrame.isLegacyUI then
            return string.format("|cff%sCORE: ~%s Rested (Caps: %s)|r", t.primaryHex or "f2c94c", xpStr, rested and rested.timeLeftStr or "---")
        end
        return string.format("|cff%sCORE PRIORITY: ~%s Rested XP (Caps in %s)|r", t.primaryHex or "f2c94c", xpStr, rested and rested.timeLeftStr or "---")
    else
        local xpStr = rested and CLIAlts:FormatNumber(rested.currentRested) or "0"
        if mainFrame and not mainFrame.isLegacyUI then
            return string.format("|cff%sRESERVE: ~%s Rested XP|r", t.mutedHex or "a9a08c", xpStr)
        end
        return string.format("|cff%sRESERVE ALT: ~%s Rested XP (Accruing toward cap)|r", t.mutedHex or "a9a08c", xpStr)
    end
end

-- Tab 3 Rested Monitor Formatters
local function FmtCurXP(char, t)
    t = t or CLIAlts:GetTheme()
    local xpData = CLIAlts:GetLevelProgressData(char)
    if not xpData or xpData.isMaxLevel then
        return string.format("|cff%sMAX LEVEL|r", t.mutedHex or "a9a08c")
    end
    if mainFrame and not mainFrame.isLegacyUI then
        local curK = (xpData.curXP or 0) >= 1000 and string.format("%.1fk", (xpData.curXP or 0) / 1000) or tostring(xpData.curXP or 0)
        local maxK = (xpData.maxXP or 0) >= 1000 and string.format("%.1fk", (xpData.maxXP or 0) / 1000) or tostring(xpData.maxXP or 0)
        return string.format("|cff%s%s/%s (%d%%)|r", t.textHex or "f4ead2", curK, maxK, xpData.percent or 0)
    end
    return string.format("|cff%s%s|r |cff%s/ %s (%d%%)|r",
        t.textHex or "f4ead2", CLIAlts:FormatNumber(xpData.curXP),
        t.dimHex or "736953", CLIAlts:FormatNumber(xpData.maxXP), xpData.percent)
end

local function FmtRestedPool(char, t)
    t = t or CLIAlts:GetTheme()
    local rested = CLIAlts:GetRestedData(char)
    if not rested or rested.isMaxLevel then
        return string.format("|cff%sMAX LEVEL|r", t.mutedHex or "a9a08c")
    end
    if mainFrame and not mainFrame.isLegacyUI then
        local curK = (rested.currentRested or 0) >= 1000 and string.format("%.1fk", (rested.currentRested or 0) / 1000) or tostring(rested.currentRested or 0)
        local capStr = rested.isFull and (string.format("|cff%s%d%%*|r", t.highlightHex, rested.maxPercent or 150)) or (string.format("%d%%", rested.percent or 0))
        return string.format("|cff%s%s XP (%s)|r", t.textHex or t.primaryHex, curK, capStr)
    end
    local capStr = rested.isFull and (string.format("|cff%s%d%%*|r", t.highlightHex, rested.maxPercent or 150)) or (string.format("%d%%", rested.percent or 0))
    return string.format("|cff%s%s|r |cff%s/ %s (%s)|r",
        t.textHex or t.primaryHex, CLIAlts:FormatNumber(rested.currentRested),
        t.dimHex, CLIAlts:FormatNumber(rested.maxRested), capStr)
end

local function FmtRestedBar(char, t)
    t = t or CLIAlts:GetTheme()
    local rested = CLIAlts:GetRestedData(char)
    if not rested or rested.isMaxLevel then
        return string.format("|cff%s[==========]|r |cff%sMAX|r", t.dimHex, t.highlightHex)
    end

    local isFull = rested.isFull
    local ratio = math.min(1.0, math.max(0, rested.ratio or 0))
    local fill = math.min(8, math.max(0, math.floor(ratio * 8)))
    local empty = 8 - fill
    local fillChar = isFull and "#" or "="
    local fillStr = string.rep(fillChar, fill)
    local emptyStr = string.rep(".", empty)
    local est = rested.isEstimate and "~" or ""
    local capMark = isFull and "*" or ""
    local capPct = math.floor(ratio * 100)
    local barColor = isFull and t.highlightHex or (t.accentHex or t.primaryHex)
    local labelColor = isFull and t.highlightHex or (t.textHex or t.primaryHex)

    if mainFrame and not mainFrame.isLegacyUI then
        return string.format("|cff%s[|r|cff%s%s|r|cff%s%s|r|cff%s]|r |cff%s%s%d%%%s cap|r",
            t.dimHex, barColor, fillStr, t.dimHex, emptyStr, t.dimHex, labelColor, est, capPct, capMark)
    end

    local lvlPct = rested.percent or 0
    return string.format("|cff%s[|r|cff%s%s|r|cff%s%s|r|cff%s]|r |cff%s%s%d%%%s cap (%d%% lvl)|r",
        t.dimHex, barColor, fillStr, t.dimHex, emptyStr, t.dimHex, labelColor, est, capPct, capMark, lvlPct)
end

local function FmtRate(char, t)
    t = t or CLIAlts:GetTheme()
    local rested = CLIAlts:GetRestedData(char)
    if not rested or rested.isMaxLevel then
        return string.format("|cff%s---|r", t.mutedHex or "a9a08c")
    end
    local s = rested.isResting and "+5.0%/8h" or "+1.25%/8h"
    return string.format("|cff%s%s|r", t.dimHex, s)
end

-- Tab 4 Profession Formatters
local function FmtProf1(char, t)
    t = t or CLIAlts:GetTheme()
    local profs = char.professions and char.professions.primary
    local p = profs and profs[1]
    if not p then return string.format("|cff%s---|r", t.mutedHex or "a9a08c") end
    local m = CLIAlts:GetProfessionMilestoneInfo(char, p)
    if m and m.canTrainNext and m.isCappedAtCurrentRank then
        return string.format("|cff%s%s: %d / %d [TRAIN]|r", t.readyHex or "55e39a", p.name or "Prof", p.rank or 0, p.maxRank or 0)
    elseif m and m.levelBottleneck then
        return string.format("|cff%s%s: %d / %d [Req Lvl %d]|r", t.pendingHex or "ffb547", p.name or "Prof", p.rank or 0, p.maxRank or 0, m.nextReqLevel or 20)
    elseif m and (m.isDone or (m.isMilestoneHit and m.rank == m.maxRank)) then
        return string.format("|cff%s%s: %d / %d [DONE]|r", t.accentHex or "57d6e8", p.name or "Prof", p.rank or 0, p.maxRank or 0)
    else
        return string.format("|cff%s%s: %d / %d|r", t.textHex or t.primaryHex, p.name or "Prof", p.rank or 0, p.maxRank or 0)
    end
end

local function FmtProf2(char, t)
    t = t or CLIAlts:GetTheme()
    local profs = char.professions and char.professions.primary
    local p = profs and profs[2]
    if not p then return string.format("|cff%s---|r", t.mutedHex or "a9a08c") end
    local m = CLIAlts:GetProfessionMilestoneInfo(char, p)
    if m and m.canTrainNext and m.isCappedAtCurrentRank then
        return string.format("|cff%s%s: %d / %d [TRAIN]|r", t.readyHex or "55e39a", p.name or "Prof", p.rank or 0, p.maxRank or 0)
    elseif m and m.levelBottleneck then
        return string.format("|cff%s%s: %d / %d [Req Lvl %d]|r", t.pendingHex or "ffb547", p.name or "Prof", p.rank or 0, p.maxRank or 0, m.nextReqLevel or 20)
    elseif m and (m.isDone or (m.isMilestoneHit and m.rank == m.maxRank)) then
        return string.format("|cff%s%s: %d / %d [DONE]|r", t.accentHex or "57d6e8", p.name or "Prof", p.rank or 0, p.maxRank or 0)
    else
        return string.format("|cff%s%s: %d / %d|r", t.textHex or t.primaryHex, p.name or "Prof", p.rank or 0, p.maxRank or 0)
    end
end

local function FmtSecProf(char, t)
    t = t or CLIAlts:GetTheme()
    local secs = char.professions and char.professions.secondary
    if not secs or #secs == 0 then return string.format("|cff%s---|r", t.mutedHex or "a9a08c") end
    local parts = {}
    for _, s in ipairs(secs) do
        local shortName = s.name:sub(1, 4)
        table.insert(parts, string.format("%s: %d / %d", shortName, s.rank or 0, s.maxRank or 75))
    end
    return string.format("|cff%s%s|r", t.dimHex, table.concat(parts, ", "))
end

-- Tab 5 Economy & Location Formatters
local function FmtGoldLong(char, t)
    t = t or CLIAlts:GetTheme()
    local money = char.money or 0
    local isStale = CLIAlts.IsCharStale and CLIAlts:IsCharStale(char)
    local formatted = CLIAlts:FormatMoney(money, true)
    if isStale then
        return string.format("%s |cff%s[STALE]|r", formatted, t.blockedHex or "ff6b6b")
    end
    return formatted
end

local function FmtWealthShare(char, t)
    t = t or CLIAlts:GetTheme()
    local summary = CLIAlts:GetAccountSummary()
    local total = summary.totalGold or 0
    local money = char.money or 0
    local pct = total > 0 and (money / total * 100) or 0
    return string.format("|cff%s%.1f%%|r", t.primaryHex, pct)
end
CLIAlts.FmtWealthShare = FmtWealthShare

local function FmtLocation(char, t)
    t = t or CLIAlts:GetTheme()
    local loc = char.location or "Unknown"
    return string.format("|cff%s%s|r", t.dimHex, loc)
end

local function FmtHearth(char, t)
    t = t or CLIAlts:GetTheme()
    local bind = char.bindLocation or "Unknown"
    return string.format("|cff%s%s|r", t.textHex or t.highlightHex, bind)
end

-- Tab 6 Cooldowns & Lockouts Formatters
local function FmtTradeCooldowns(char, t)
    t = t or CLIAlts:GetTheme()
    local cds = char.tradeCooldowns
    if not cds or not next(cds) then
        return string.format("|cff%sNO TRADE CDS|r", t.mutedHex or "a9a08c")
    end
    local parts = {}
    local now = time()
    for name, readyAt in pairs(cds) do
        local short = name:gsub("^Transmute: ", "Xm:"):gsub("^Refined ", "")
        short = short:sub(1, 10)
        local rem = readyAt - now
        if rem <= 0 then
            table.insert(parts, string.format("|cff%s%s: READY|r", t.readyHex or "55e39a", short))
        else
            local d = math.floor(rem / 86400)
            local h = math.floor((rem % 86400) / 3600)
            local m = math.floor((rem % 3600) / 60)
            local timStr
            if d > 0 then
                timStr = string.format("%dd %dh", d, h)
            elseif h > 0 then
                timStr = string.format("%dh %dm", h, m)
            else
                timStr = string.format("%dm", m)
            end
            table.insert(parts, string.format("%s: in %s", short, timStr))
        end
    end
    if #parts == 0 then return string.format("|cff%sREADY|r", t.readyHex or "55e39a") end
    return string.format("|cff%s%s|r", t.textHex or t.primaryHex, table.concat(parts, " | "))
end

local function FmtRaidLocks(char, t)
    t = t or CLIAlts:GetTheme()
    local locks = char.lockouts
    if not locks or not next(locks) then
        return string.format("|cff%sNO ACTIVE LOCKS|r", t.mutedHex or "a9a08c")
    end
    local parts = {}
    local now = time()
    for name, data in pairs(locks) do
        local resetTime = (type(data) == "table" and data.resetTime) or data
        local rem = (resetTime or now) - now
        if rem > 0 then
            local short = name:gsub("^Molten Core", "MC"):gsub("^Blackwing Lair", "BWL"):gsub("^Onyxia's Lair", "Ony"):gsub("^Zul'Gurub", "ZG"):gsub("^Ruins of Ahn'Qiraj", "AQ20"):gsub("^Temple of Ahn'Qiraj", "AQ40"):gsub("^Naxxramas", "Naxx")
            short = short:sub(1, 8)
            local d = math.floor(rem / 86400)
            local h = math.floor((rem % 86400) / 3600)
            local tStr = (d > 0) and string.format("%dd", d) or string.format("%dh", h)
            table.insert(parts, string.format("%s: in %s", short, tStr))
        end
    end
    if #parts == 0 then return string.format("|cff%sNO ACTIVE LOCKS|r", t.mutedHex or "a9a08c") end
    return string.format("|cff%s%s|r", t.dimHex, table.concat(parts, " | "))
end

-- Tab 1 WoW Forever Route Formatters
local function FmtTier(char, t)
    t = t or CLIAlts:GetTheme()
    local tier = char.tier or "UNASSIGNED"
    if tier == "CORE" then
        return string.format("|cff%s[CORE]|r", t.highlightHex or "ffd34e")
    elseif tier == "RESERVE" then
        return string.format("|cff%s[ALT]|r", t.accentHex or "57d6e8")
    elseif tier == "BANK" then
        return string.format("|cff%s[BANK]|r", t.pendingHex or "ffb547")
    else
        return string.format("|cff%s[---]|r", t.mutedHex or "a9a08c")
    end
end

local function FmtLevelTarget(char, t)
    t = t or CLIAlts:GetTheme()
    local lvl = char.level or 1
    local tgt = char.target_level or ((char.tier == "CORE" and 35) or (char.tier == "RESERVE" and 25) or (char.tier == "BANK" and 1) or 60)
    if lvl >= tgt then
        return string.format("|cff%s%d/%d*|r", t.readyHex or "55e39a", lvl, tgt)
    else
        return string.format("|cff%s%d|r|cff%s/%d|r", t.textHex or t.primaryHex, lvl, t.dimHex, tgt)
    end
end

local function FmtProfessionsAuto(char, t)
    t = t or CLIAlts:GetTheme()
    if char.tier == "BANK" then
        return string.format("|cff%sBank Mule|r", t.pendingHex or "ffb547")
    end

    local alertTag = ""
    local alerts = CLIAlts:GetCharacterProfessionAlerts(char)
    if #alerts > 0 then
        for _, a in ipairs(alerts) do
            if a.type == "TRAIN" then
                alertTag = string.format(" |cff%s%s|r", t.readyHex or "55e39a", a.tag)
                break
            end
        end
    end

    if char.supply_role and char.supply_role ~= "" then
        return string.format("|cff%s%s|r%s", t.textHex or "f4ead2", char.supply_role, alertTag)
    end

    local profs = char.professions and char.professions.primary
    if profs and #profs > 0 then
        local parts = {}
        for _, p in ipairs(profs) do
            local m = CLIAlts:GetProfessionMilestoneInfo(char, p)
            if m then
                if m.canTrainNext and m.isCappedAtCurrentRank then
                    table.insert(parts, string.format("|cff%s%s %d/%d [TRAIN]|r", t.readyHex or "55e39a", m.abbr, m.rank, m.maxRank))
                elseif m.isDone or (m.isMilestoneHit and m.rank == m.maxRank) then
                    table.insert(parts, string.format("|cff%s%s %d [DONE]|r", t.accentHex or "57d6e8", m.abbr, m.rank))
                else
                    table.insert(parts, string.format("%s %d/%d [%s]", m.abbr, m.rank, m.targetMilestone, m.targetPhase))
                end
            else
                local short = p.name:sub(1, 6)
                table.insert(parts, string.format("%s %d", short, p.rank or 0))
            end
        end
        return table.concat(parts, ", ") .. alertTag
    end
    return string.format("|cff%s---|r", t.mutedHex or "a9a08c")
end
CLIAlts.FmtProfessionsAuto = FmtProfessionsAuto

local function FmtForeverStatus(char, t)
    t = t or CLIAlts:GetTheme()
    if char.tier == "BANK" then
        return string.format("|cff%sBank Mule|r", t.pendingHex or "ffb547")
    end
    local lvl = char.level or 1
    local tgt = char.target_level or ((char.tier == "CORE" and 35) or (char.tier == "RESERVE" and 25) or 60)
    if lvl >= tgt then
        return string.format("|cff%sTarget Met (%d)|r", t.readyHex or "55e39a", tgt)
    end
    local rested = CLIAlts:GetRestedData(char)
    if not rested then return string.format("|cff%sAccruing|r", t.mutedHex or "a9a08c") end
    if rested.isMaxLevel then return string.format("|cff%sMAX LEVEL|r", t.mutedHex or "a9a08c") end
    if rested.isFull then
        local capPct = rested.maxPercent or 150
        local _, wastedXP = CLIAlts:GetRestedWaste(char, nil, rested)
        if wastedXP and wastedXP > 0 then
            return string.format("|cff%s%d%% Capped* (+%s)|r", t.pendingHex or "ffb547", capPct, CLIAlts:FormatWasteShort(wastedXP))
        else
            return string.format("|cff%s%d%% Capped*|r", t.highlightHex, capPct)
        end
    end
    local pct = rested.percent or 0
    local est = rested.isEstimate and "~" or ""
    return string.format("|cff%s%d%%%s Rested|r", t.primaryHex, pct, est)
end
CLIAlts.FmtForeverStatus = FmtForeverStatus

-- Tab 7 Mail Routing & Supply Chain Formatters
local function FmtMailProfessions(char, t)
    t = t or CLIAlts:GetTheme()
    local profs = char.professions and char.professions.primary
    if not profs or #profs == 0 then
        return string.format("|cff%sNo Primary Skills|r", t.mutedHex or "a9a08c")
    end
    local parts = {}
    for _, p in ipairs(profs) do
        local short = p.name:sub(1, 8)
        table.insert(parts, string.format("%s %d", short, p.rank or 0))
    end
    return table.concat(parts, " · ")
end
CLIAlts.FmtMailProfessions = FmtMailProfessions

local function FmtMailRoute(char, t)
    t = t or CLIAlts:GetTheme()
    local role, isOverride, autoRole = CLIAlts:GetCharacterEffectiveSupplyRole(char)
    if isOverride then
        return string.format("|cff%s%s|r", t.highlightHex or "ffd34e", role)
    else
        return string.format("|cff%s%s|r", t.textHex or "f4ead2", autoRole)
    end
end
CLIAlts.FmtMailRoute = FmtMailRoute

local function FmtMailMode(char, t)
    t = t or CLIAlts:GetTheme()
    local _, isOverride = CLIAlts:GetCharacterEffectiveSupplyRole(char)
    if isOverride then
        return string.format("|cff%s[OVERRIDE]|r", t.pendingHex or "ffb547")
    else
        return string.format("|cff%s[AUTO]|r", t.accentHex or "57d6e8")
    end
end
CLIAlts.FmtMailMode = FmtMailMode

local function FmtMailPending(char, t)
    t = t or CLIAlts:GetTheme()
    if CLIAlts:IsCurrentPlayer(char) then
        return string.format("|cff%s(Logged In)|r", t.mutedHex or "a9a08c")
    end
    local count, detail = CLIAlts:GetCharacterPendingMail(char)
    if count > 0 then
        return string.format("|cff%s%d items (%s)|r", t.readyHex or "55e39a", count, detail)
    else
        return string.format("|cff%s---|r", t.mutedHex or "a9a08c")
    end
end
CLIAlts.FmtMailPending = FmtMailPending

local COLS = {
    [1] = { -- 1: OVERVIEW
        { key = "name",      title = "CHARACTER",         w = 26, pw = 360, cpw = 300, mpw = 310, align = "LEFT",   sort = "name",     fmt = FmtName },
        { key = "lvl",       title = "LEVEL",             w = 8,  pw = 80,  cpw = 70,  mpw = 70,  align = "CENTER", sort = "level",    fmt = FmtLevel },
        { key = "rested",    title = "RESTED XP",         w = 32, pw = 450, cpw = 380, mpw = 305, align = "LEFT",   sort = "rested",   fmt = FmtRested },
        { key = "eta",       title = "STATUS",            w = 14, pw = 200, cpw = 0,   mpw = 130, align = "RIGHT",  sort = "waste",    fmt = FmtETA },
    },
    [2] = { -- 2: FOREVER ROUTE
        { key = "order",     title = "ORDER",             w = 5,  pw = 48,  cpw = 40,  mpw = 38,  align = "CENTER", sort = "rotation", fmt = FmtRouteOrder },
        { key = "name",      title = "CHARACTER",         w = 15, pw = 140, cpw = 125, mpw = 130, align = "LEFT",   sort = "name",     fmt = FmtName },
        { key = "tier",      title = "ROLE",              w = 8,  pw = 65,  cpw = 55,  mpw = 54,  align = "CENTER", sort = "cohort",   fmt = FmtTier },
        { key = "lvlTgt",    title = "LEVEL",             w = 8,  pw = 65,  cpw = 55,  mpw = 54,  align = "CENTER", sort = "level",    fmt = FmtLevelTarget },
        { key = "rested",    title = "RESTED XP",         w = 11, pw = 100, cpw = 85,  mpw = 95,  align = "RIGHT",  sort = "rested",   fmt = FmtRested },
        { key = "score",     title = "PRIORITY",          w = 9,  pw = 80,  cpw = 70,  mpw = 75,  align = "RIGHT",  sort = "rotation", fmt = FmtRotationScore },
        { key = "eta",       title = "ETA",               w = 8,  pw = 80,  cpw = 0,   mpw = 0,   padRight = 16, cpadRight = 0, align = "RIGHT",  sort = "waste",    fmt = FmtETA },
        { key = "reason",    title = "RECOMMENDATION REASON", w = 30, pw = 525, cpw = 410, mpw = 370, align = "LEFT", sort = "rotation", fmt = FmtRouteReason },
    },
    [3] = { -- 3: RESTED XP MONITOR
        { key = "fac",       title = "FAC",               w = 3,  pw = 40,  cpw = 36,  mpw = 30,  align = "CENTER", fmt = FmtFaction },
        { key = "name",      title = "CHARACTER",         w = 15, pw = 160, cpw = 135, mpw = 145, align = "LEFT",   sort = "name",     fmt = FmtName },
        { key = "lvl",       title = "LVL",               w = 3,  pw = 50,  cpw = 40,  mpw = 40,  align = "CENTER", sort = "level",    fmt = FmtLevel },
        { key = "curXP",     title = "CURRENT XP",        w = 14, pw = 180, cpw = 0,   mpw = 135, padRight = 10, mpadRight = 10, align = "RIGHT",  sort = "xp",       fmt = FmtCurXP },
        { key = "pool",      title = "RESTED / CAP",      w = 14, pw = 175, cpw = 145, mpw = 140, padRight = 14, cpadRight = 10, mpadRight = 10, align = "RIGHT",  sort = "rested",   fmt = FmtRestedPool },
        { key = "restBar",   title = "RESTED PROGRESS",   w = 18, pw = 225, cpw = 180, mpw = 150, align = "LEFT",   fmt = FmtRestedBar },
        { key = "rate",      title = "RATE",              w = 8,  pw = 110, cpw = 95,  mpw = 85,  padRight = 8, mpadRight = 8, align = "RIGHT",  fmt = FmtRate },
        { key = "eta",       title = "STATUS",            w = 12, pw = 150, cpw = 120, mpw = 90,  padRight = 8, mpadRight = 8, align = "RIGHT",  sort = "waste",    fmt = FmtETA },
    },
    [4] = { -- 4: PROFESSIONS & MILESTONES
        { key = "fac",       title = "FAC",               w = 3,  pw = 40,  cpw = 36,  mpw = 30,  align = "CENTER", fmt = FmtFaction },
        { key = "name",      title = "CHARACTER",         w = 16, pw = 160, cpw = 135, mpw = 155, align = "LEFT",   sort = "name",     fmt = FmtName },
        { key = "lvl",       title = "LVL",               w = 3,  pw = 50,  cpw = 40,  mpw = 40,  align = "CENTER", sort = "level",    fmt = FmtLevel },
        { key = "prof1",     title = "PRIMARY PROF 1",    w = 23, pw = 300, cpw = 220, mpw = 205, align = "LEFT",   sort = "prof",     fmt = FmtProf1 },
        { key = "prof2",     title = "PRIMARY PROF 2",    w = 22, pw = 295, cpw = 220, mpw = 205, align = "LEFT",   fmt = FmtProf2 },
        { key = "sec",       title = "SECONDARY SKILLS",  w = 18, pw = 250, cpw = 180, mpw = 180, align = "LEFT",   fmt = FmtSecProf },
    },
    [5] = { -- 5: ECONOMY & WEALTH
        { key = "fac",       title = "FAC",               w = 3,  pw = 40,  cpw = 36,  mpw = 30,  align = "CENTER", fmt = FmtFaction },
        { key = "name",      title = "CHARACTER",         w = 16, pw = 160, cpw = 135, mpw = 155, align = "LEFT",   sort = "name",     fmt = FmtName },
        { key = "lvl",       title = "LVL",               w = 3,  pw = 50,  cpw = 40,  mpw = 40,  align = "CENTER", sort = "level",    fmt = FmtLevel },
        { key = "gold",      title = "GOLD & SILVER",     w = 14, pw = 200, cpw = 160, mpw = 175, padRight = 32, cpadRight = 20, align = "RIGHT",  sort = "gold",     fmt = FmtGoldLong },
        { key = "location",  title = "LAST ZONE",         w = 18, pw = 310, cpw = 220, mpw = 205, align = "LEFT",   sort = "location", fmt = FmtLocation },
        { key = "hearth",    title = "HEARTHSTONE",       w = 18, pw = 330, cpw = 230, mpw = 210, align = "LEFT",   sort = "hearth",   fmt = FmtHearth },
    },
    [6] = { -- 6: COOLDOWNS & INSTANCE LOCKS
        { key = "fac",       title = "FAC",               w = 3,  pw = 40,  cpw = 36,  mpw = 30,  align = "CENTER", fmt = FmtFaction },
        { key = "name",      title = "CHARACTER",         w = 16, pw = 160, cpw = 135, mpw = 155, align = "LEFT",   sort = "name",     fmt = FmtName },
        { key = "lvl",       title = "LVL",               w = 3,  pw = 50,  cpw = 40,  mpw = 40,  align = "CENTER", sort = "level",    fmt = FmtLevel },
        { key = "tradeCd",   title = "TRADE COOLDOWNS",   w = 26, pw = 425, cpw = 310, mpw = 295, align = "LEFT",   sort = "cooldown", fmt = FmtTradeCooldowns },
        { key = "raidLocks", title = "SAVED INSTANCES / LOCKS", w = 26, pw = 425, cpw = 310, mpw = 295, align = "LEFT", sort = "cooldown", fmt = FmtRaidLocks },
    },
    [7] = { -- 7: MAIL ROUTING & SUPPLY CHAIN
        { key = "fac",       title = "FAC",                 w = 3,  pw = 40,  cpw = 36,  mpw = 30,  align = "CENTER", fmt = FmtFaction },
        { key = "name",      title = "CHARACTER",           w = 16, pw = 160, cpw = 130, mpw = 150, align = "LEFT",   sort = "name",     fmt = FmtName },
        { key = "tier",      title = "ROLE",                w = 8,  pw = 65,  cpw = 55,  mpw = 54,  align = "CENTER", sort = "cohort",   fmt = FmtTier },
        { key = "profs",     title = "PROFESSIONS",         w = 20, pw = 240, cpw = 175, mpw = 160, align = "LEFT",   sort = "prof",     fmt = FmtMailProfessions },
        { key = "route",     title = "ASSIGNED MATERIALS",  w = 24, pw = 280, cpw = 210, mpw = 195, align = "LEFT",   sort = "supply",   fmt = FmtMailRoute },
        { key = "mode",      title = "MODE",                w = 8,  pw = 110, cpw = 90,  mpw = 85,  align = "CENTER", fmt = FmtMailMode },
        { key = "pending",   title = "BAGS READY",          w = 15, pw = 205, cpw = 145, mpw = 140, align = "RIGHT",  fmt = FmtMailPending },
    },
}

function CLIAlts:GetColumns(activeTab)
    activeTab = tonumber(activeTab) or 1
    local tabCols = COLS[activeTab] or COLS[1]
    local isModern = (mainFrame and not mainFrame.isLegacyUI)
    if not self:IsCompact() and not isModern then
        return tabCols
    end

    local filtered = {}
    for _, col in ipairs(tabCols) do
        if isModern then
            if col.mpw and col.mpw > 0 then
                table.insert(filtered, col)
            elseif col.mpw == nil and (col.cpw == nil or col.cpw > 0) then
                table.insert(filtered, col)
            end
        elseif self:IsCompact() then
            if col.cpw and col.cpw > 0 then
                table.insert(filtered, col)
            elseif col.cpw == nil and col.key ~= "xp" and col.key ~= "curXP" and col.key ~= "eta" then
                table.insert(filtered, col)
            end
        end
    end
    return filtered
end

function CLIAlts:GetLineWidth()
    local targetW = (mainFrame and (mainFrame:GetWidth() - 24)) or (self:IsCompact() and 876 or 1126)
    local charW = self:GetCharWidth()
    if not charW or charW < 4 or charW > 25 then
        charW = DEFAULT_FONT_SIZE * 0.54
    end
    return math.max(20, math.floor(targetW / charW))
end

function CLIAlts:GetBorderLine(isDouble)
    local char = isDouble and "=" or "-"
    local targetW = (mainFrame and (mainFrame:GetWidth() - 24)) or (self:IsCompact() and 876 or 1126)
    return self:GetBarString(char, targetW)
end

function CLIAlts:UpdateBorders()
    if not mainFrame then return end
    local doubleBar = self:GetBorderLine(true)
    local singleBar = self:GetBorderLine(false)

    if mainFrame.topAscii then mainFrame.topAscii:SetText(doubleBar) end
    if mainFrame.midAscii1 then mainFrame.midAscii1:SetText("") end
    if mainFrame.midAscii2 then mainFrame.midAscii2:SetText("") end
    if mainFrame.tableTopAscii then mainFrame.tableTopAscii:SetText("") end
    if mainFrame.tableSepAscii then mainFrame.tableSepAscii:SetText(singleBar) end
    if mainFrame.tableBotAscii then mainFrame.tableBotAscii:SetText(singleBar) end
    if mainFrame.promptSepAscii then mainFrame.promptSepAscii:SetText("") end
    if mainFrame.botAscii then mainFrame.botAscii:SetText(singleBar) end
end

-- ----------------------------------------------------------------------------
-- Compact Mode Layout & Width Adjustment
-- ----------------------------------------------------------------------------
function CLIAlts:ApplyLayoutSize()
    if not mainFrame then return end
    if not mainFrame.isLegacyUI then
        mainFrame:SetSize(1440, 800)
        return
    end
    local isComp = self:IsCompact()
    local targetWidth = isComp and 900 or 1150
    mainFrame:SetWidth(targetWidth)
    mainFrame:SetHeight(600)

    -- Top bar layout
    if mainFrame.titleText then
        mainFrame.titleText:SetText("CLIAlts")
    end
    if mainFrame.subTitleText then
        mainFrame.subTitleText:SetText("/ ALT MONITOR")
    end
    if mainFrame.subtitleText then
        mainFrame.subtitleText:SetText("/ ALT MONITOR")
    end
    if mainFrame.btnCompact then
        mainFrame.btnCompact.label:SetText(isComp and "[ COMPACT* ]" or "[ COMPACT ]")
    end

    -- Tab buttons: Clean Nav Bar at Y = -56
    local tabCount = #(mainFrame.tabButtons or {})
    local tabW = math.floor((targetWidth - 36 - ((tabCount - 1) * 8)) / math.max(1, tabCount))
    local prevTab = nil
    for _, tabBtn in ipairs(mainFrame.tabButtons or {}) do
        local w = isComp and tabW or (tabBtn.stdWidth or 80)
        tabBtn:SetWidth(w)
        tabBtn:ClearAllPoints()
        if not prevTab then
            tabBtn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, -56)
        else
            tabBtn:SetPoint("LEFT", prevTab, "RIGHT", 8, 0)
        end
        prevTab = tabBtn
    end

    -- Hero Recommendation Card geometry (recPanel)
    local recY = -84
    if mainFrame.recPanel then
        mainFrame.recPanel:ClearAllPoints()
        mainFrame.recPanel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14, recY)
        mainFrame.recPanel:SetSize(targetWidth - 28, 74)
    end
    if mainFrame.summaryBar then
        mainFrame.summaryBar:SetWidth(targetWidth - 28)
    end

    -- 3 KPI Metric Cards
    if mainFrame.kpiContainer then
        mainFrame.kpiContainer:ClearAllPoints()
        mainFrame.kpiContainer:SetPoint("TOPLEFT", mainFrame.recPanel, "BOTTOMLEFT", 0, -8)
        mainFrame.kpiContainer:SetSize(targetWidth - 28, 52)
        local cardW = math.floor((targetWidth - 28 - 16) / 3)
        for _, card in pairs(mainFrame.kpiCards or {}) do
            card:SetWidth(cardW)
        end
    end

    -- Sub-header view bar
    local subY = -226
    if mainFrame.subViewTitle then
        mainFrame.subViewTitle:ClearAllPoints()
        mainFrame.subViewTitle:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, subY)
    end
    if mainFrame.subViewFilters then
        mainFrame.subViewFilters:ClearAllPoints()
        mainFrame.subViewFilters:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -18, subY)
    end

    -- Table header & rows geometry
    local headerY = -246
    if mainFrame.headerFrame then
        mainFrame.headerFrame:ClearAllPoints()
        mainFrame.headerFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 12, headerY)
        mainFrame.headerFrame:SetWidth(targetWidth - 24)
    end
    if mainFrame.tableSepAscii then
        mainFrame.tableSepAscii:ClearAllPoints()
        mainFrame.tableSepAscii:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 12, headerY - 18)
    end
    local rowsY = headerY - 22
    if mainFrame.rowsContainer then
        mainFrame.rowsContainer:ClearAllPoints()
        mainFrame.rowsContainer:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 12, rowsY)
        mainFrame.rowsContainer:SetWidth(targetWidth - 24)
        mainFrame.rowsContainer:SetHeight(ROWS_COUNT * 36)
    end
    local lvlCenter = isComp and 340 or 416
    local restLeft = isComp and 385 or 470
    local barWidth = isComp and 190 or 280
    for _, row in ipairs(rowFrames) do
        row:SetWidth(targetWidth - 24)
        row:SetHeight(34)
        if row.levelText then
            row.levelText:ClearAllPoints()
            row.levelText:SetPoint("CENTER", row, "LEFT", lvlCenter, 0)
        end
        if row.restPercentText then
            row.restPercentText:ClearAllPoints()
            row.restPercentText:SetPoint("LEFT", row, "LEFT", restLeft, 0)
        end
        if row.barBg then
            row.barBg:SetWidth(barWidth)
        end
    end
    if mainFrame.tableBotAscii then
        mainFrame.tableBotAscii:ClearAllPoints()
        mainFrame.tableBotAscii:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 12, rowsY - (ROWS_COUNT * 36) - 4)
    end

    -- Footer elements
    if mainFrame.btnPrev then
        mainFrame.btnPrev:ClearAllPoints()
        mainFrame.btnPrev:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 18, 12)
    end
    if mainFrame.statusTip then
        mainFrame.statusTip:ClearAllPoints()
        mainFrame.statusTip:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -18, 14)
    end

    -- Bottom prompt box width adjustment
    if mainFrame.promptBox and mainFrame.promptLabel then
        mainFrame.promptBox:ClearAllPoints()
        mainFrame.promptBox:SetPoint("LEFT", mainFrame.promptLabel, "RIGHT", 4, 0)
        mainFrame.promptBox:SetPoint("RIGHT", mainFrame, "RIGHT", isComp and -280 or -420, 0)
    end

    self:UpdateBorders()
end

-- ----------------------------------------------------------------------------
-- Legacy Main Frame Construction (ASCII Table UI)
-- ----------------------------------------------------------------------------
function CLIAlts:CreateLegacyMainFrame()
    if mainFrame then return mainFrame end
    if _G["CLIAltsMainFrame"] then
        mainFrame = _G["CLIAltsMainFrame"]
        self.mainFrame = mainFrame
        return mainFrame
    end

    local frame = CreateFrame("Frame", "CLIAltsMainFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame.isLegacyUI = true
    frame:Hide()
    frame:SetSize(1150, 600)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    tinsert(UISpecialFrames, "CLIAltsMainFrame")

    -- Restore saved window scale & position
    local s = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.scale) or 1.0
    frame:SetScale(s)
    self:RestoreWindowPosition(frame)

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        CLIAlts:SaveWindowPosition(self)
    end)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })

    mainFrame = frame
    self.mainFrame = frame
    _G["CLIAltsMainFrame"] = frame

    local fontSize = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.fontSize) or DEFAULT_FONT_SIZE

    -- Top border ASCII line (kept empty for clean modern border)
    local topAscii = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(topAscii, fontSize)
    topAscii:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -8)
    topAscii:SetText("")
    frame.topAscii = topAscii

    -- 1. Modern Header Title & Subtitle Block (Side-by-side title and subtitle)
    local titleText = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(titleText, 17, "OUTLINE")
    titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -14)
    titleText:SetText("CLIAlts")
    frame.titleText = titleText

    local subtitleText = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(subtitleText, 11, "OUTLINE")
    subtitleText:SetPoint("LEFT", titleText, "RIGHT", 8, -1)
    subtitleText:SetText("/ ALT MONITOR")
    frame.subtitleText = subtitleText
    frame.subTitleText = subtitleText

    local metaText = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(metaText, 10, "")
    metaText:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -35)
    metaText:SetText("4 characters · Forever · Updated recently")
    frame.metaText = metaText

    -- Window Controls on Title Bar (Close, Help, Theme, Scale, Compact)
    local btnClose = CreateRetroButton(frame, "[ X ]", 28, 18, function()
        CLIAlts:Toggle(false)
    end)
    btnClose:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -15)

    local btnHelp = CreateRetroButton(frame, "[ ? ]", 28, 18, function()
        CLIAlts:ShowHelpPopup()
    end)
    btnHelp:SetPoint("RIGHT", btnClose, "LEFT", -5, 0)

    local curTag = (self.GetTheme and self:GetTheme().tag) or "AMB"
    local btnTheme = CreateRetroButton(frame, string.format("[ THEME: %s ]", curTag), 92, 18, function()
        CLIAlts:CycleTheme()
    end)
    btnTheme:SetPoint("RIGHT", btnHelp, "LEFT", -5, 0)
    frame.btnTheme = btnTheme

    local btnScale = CreateRetroButton(frame, string.format("[ SCALE: %d%% ]", math.floor(s * 100 + 0.5)), 88, 18, function()
        CLIAlts:CycleScale()
    end)
    btnScale:SetPoint("RIGHT", btnTheme, "LEFT", -5, 0)
    frame.btnScale = btnScale

    local btnCompact = CreateRetroButton(frame, "[ COMPACT ]", 85, 18, function()
        CLIAlts:ToggleCompact()
    end)
    btnCompact:SetPoint("RIGHT", btnScale, "LEFT", -5, 0)
    btnCompact:SetScript("OnEnter", function(self)
        local t = CLIAlts:GetTheme()
        if self.SetBackdropColor then self:SetBackdropColor(t.rowHover[1], t.rowHover[2], t.rowHover[3], 0.8) end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Compact Mode", 1, 1, 1)
        GameTooltip:AddLine("Hides XP bar columns for narrow windows or high scales.", 0.8, 0.8, 0.8)
        local isComp = CLIAlts:IsCompact()
        GameTooltip:AddLine(string.format("Status: %s", isComp and "|cff00ff66ENABLED|r" or "|cff888888DISABLED|r"), 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Command: Type |cffffd700compact|r or |cffffd700c|r in prompt.", 0.4, 0.8, 0.5)
        GameTooltip:Show()
    end)
    btnCompact:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then self:SetBackdropColor(0, 0, 0, 0.6) end
        GameTooltip:Hide()
    end)
    frame.btnCompact = btnCompact

    -- Status Pill Badge in Top Right
    local badgeTracking = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    badgeTracking:SetSize(82, 18)
    badgeTracking:SetPoint("RIGHT", btnCompact, "LEFT", -8, 0)
    badgeTracking:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if badgeTracking.SetBackdropColor then
        badgeTracking:SetBackdropColor(0.04, 0.14, 0.08, 0.90)
    end
    if badgeTracking.SetBackdropBorderColor then
        badgeTracking:SetBackdropBorderColor(0.0, 0.8, 0.35, 0.8)
    end
    local badgeText = badgeTracking:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(badgeText, 10, "OUTLINE")
    badgeText:SetPoint("CENTER", 0, 0)
    badgeText:SetText("|cff00ff66TRACKING|r")
    badgeTracking.text = badgeText
    frame.badgeTracking = badgeTracking

    -- 2. Modern Navigation Tab Strip (Clean text links with active amber box pill)
    local tabs = {
        { id = 1, text = "Overview",    compact = "Overview", viewTitle = "OVERVIEW",                 stdWidth = 82 },
        { id = 2, text = "Route",       compact = "Route",    viewTitle = "FOREVER ROUTE",          stdWidth = 64 },
        { id = 3, text = "Rested XP",   compact = "Rested",   viewTitle = "RESTED XP MONITOR",       stdWidth = 84 },
        { id = 4, text = "Professions", compact = "Profs",    viewTitle = "PROFESSIONS & MILESTONES", stdWidth = 96 },
        { id = 5, text = "Economy",     compact = "Econ",     viewTitle = "ECONOMY & WEALTH",        stdWidth = 76 },
        { id = 6, text = "Cooldowns",   compact = "CDs",      viewTitle = "COOLDOWNS & LOCKS",       stdWidth = 86 },
        { id = 7, text = "Mail Routes", compact = "Mail",     viewTitle = "MAIL ROUTING & SUPPLY CHAIN", stdWidth = 96 },
    }
    frame.tabButtons = {}
    local prevTab = nil
    for _, tabData in ipairs(tabs) do
        local thisTabId = tabData.id
        local tabBtn = CreateRetroButton(frame, tabData.text, tabData.stdWidth, 20, function()
            CLIAlts:SwitchTab(thisTabId)
        end)
        if not prevTab then
            tabBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -56)
        else
            tabBtn:SetPoint("LEFT", prevTab, "RIGHT", 8, 0)
        end
        tabBtn.tabId = tabData.id
        tabBtn.baseText = tabData.text
        tabBtn.compactText = tabData.compact
        tabBtn.viewTitle = tabData.viewTitle
        tabBtn.stdWidth = tabData.stdWidth

        tabBtn:SetScript("OnEnter", function(self)
            if self.tabId ~= (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.activeTab) then
                local curT = CLIAlts:GetTheme()
                self.label:SetTextColor(curT.primary[1], curT.primary[2], curT.primary[3])
                if self.SetBackdropBorderColor then
                    self:SetBackdropBorderColor(curT.dim[1], curT.dim[2], curT.dim[3], 0.4)
                end
            end
        end)
        tabBtn:SetScript("OnLeave", function(self)
            if self.tabId ~= (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.activeTab) then
                local curT = CLIAlts:GetTheme()
                self.label:SetTextColor(curT.muted[1], curT.muted[2], curT.muted[3])
                if self.SetBackdropBorderColor then
                    self:SetBackdropBorderColor(0, 0, 0, 0)
                end
                if self.SetBackdropColor then
                    self:SetBackdropColor(0, 0, 0, 0)
                end
            end
        end)

        table.insert(frame.tabButtons, tabBtn)
        prevTab = tabBtn
    end

    -- Subheader border ASCII line (empty for clean breathing room)
    local midAscii1 = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(midAscii1, fontSize)
    midAscii1:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -90)
    midAscii1:SetText("")
    frame.midAscii1 = midAscii1

    local t = self:GetTheme()
    local pBg = t.panelBg or { 0.098, 0.082, 0.047, 0.90 }

    -- Level 1: Modern Hero Recommendation Card (RECOMMENDED NEXT)
    local recPanel = CreateFrame("Frame", "CLIAltsRecPanel", frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    recPanel:SetSize(1122, 74)
    recPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -94)
    recPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if recPanel.SetBackdropColor then
        recPanel:SetBackdropColor(pBg[1], pBg[2], pBg[3], 0.95)
        recPanel:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 0.55)
    end
    frame.recPanel = recPanel

    local recBadge = recPanel:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(recBadge, 10, "OUTLINE")
    recBadge:SetPoint("TOPLEFT", recPanel, "TOPLEFT", 12, -8)
    recBadge:SetText("RECOMMENDED NEXT")
    recBadge:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
    frame.recBadge = recBadge

    -- Cohort Pill Badge on top right of Hero card (e.g. CORE, ALT, BANK)
    local recCohortBadge = CreateFrame("Frame", nil, recPanel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    recCohortBadge:SetSize(54, 18)
    recCohortBadge:SetPoint("TOPRIGHT", recPanel, "TOPRIGHT", -12, -7)
    recCohortBadge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if recCohortBadge.SetBackdropColor then
        recCohortBadge:SetBackdropColor(0.22, 0.11, 0.05, 0.90)
        recCohortBadge:SetBackdropBorderColor(0.85, 0.45, 0.20, 0.8)
    end
    local recCohortBadgeText = recCohortBadge:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(recCohortBadgeText, 10, "OUTLINE")
    recCohortBadgeText:SetPoint("CENTER", 0, 0)
    recCohortBadgeText:SetText("|cffffb547CORE|r")
    recCohortBadge.text = recCohortBadgeText
    frame.recCohortBadge = recCohortBadge
    frame.recCohortBadgeText = recCohortBadgeText

    local recBtnDossier = CreateRetroButton(recPanel, "[ DOSSIER ]", 78, 18, function()
        if frame.recChar then
            CLIAlts:ShowDossierPopup(frame.recChar)
        end
    end)
    recBtnDossier:SetPoint("RIGHT", recCohortBadge, "LEFT", -8, 0)
    frame.recBtnDossier = recBtnDossier

    local recBtnSetup = CreateRetroButton(recPanel, "[ GUIDE ]", 74, 18, function()
        CLIAlts:ShowHelpPopup()
    end)
    recBtnSetup:SetPoint("RIGHT", recBtnDossier, "LEFT", -6, 0)
    recBtnSetup:Hide()
    frame.recBtnSetup = recBtnSetup

    -- Hero Alt Name & Level (Line 1)
    local recHeroTitle = recPanel:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(recHeroTitle, 15, "OUTLINE")
    recHeroTitle:SetPoint("TOPLEFT", recPanel, "TOPLEFT", 12, -24)
    recHeroTitle:SetText("No characters tracked")
    recHeroTitle:SetTextColor(t.text[1], t.text[2], t.text[3])
    frame.recHeroTitle = recHeroTitle

    -- Hero Alt Professions / Roles (Line 2)
    local recProfLine = recPanel:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(recProfLine, 11, "")
    recProfLine:SetPoint("TOPLEFT", recPanel, "TOPLEFT", 12, -42)
    recProfLine:SetText("")
    recProfLine:SetTextColor(t.text[1], t.text[2], t.text[3])
    frame.recProfLine = recProfLine

    -- Hero Alt Rested Opportunity & Countdown (Line 3)
    local recRestLine = recPanel:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(recRestLine, 11, "")
    recRestLine:SetPoint("TOPLEFT", recPanel, "TOPLEFT", 12, -56)
    recRestLine:SetText("")
    recRestLine:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
    frame.recRestLine = recRestLine

    -- Recommendation Rationale Note (Bottom Right)
    local recReasonLine = recPanel:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(recReasonLine, 10, "")
    recReasonLine:SetPoint("BOTTOMRIGHT", recPanel, "BOTTOMRIGHT", -12, 6)
    recReasonLine:SetJustifyH("RIGHT")
    recReasonLine:SetText("Suggested by your current route and rested XP rules")
    recReasonLine:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
    frame.recReasonLine = recReasonLine

    -- Backward compatibility aliases
    local summaryBar = CreateFrame("Frame", "CLIAltsSummaryBar", recPanel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    summaryBar:SetPoint("TOPLEFT", recPanel, "TOPLEFT", 0, 0)
    summaryBar:SetPoint("BOTTOMRIGHT", recPanel, "BOTTOMRIGHT", 0, 0)
    frame.summaryBar = summaryBar

    local summaryText = summaryBar:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(summaryText, fontSize, "")
    summaryText:SetPoint("TOPRIGHT", recBtnDossier, "LEFT", -10, -1)
    summaryText:SetText("")
    summaryText:Hide()
    frame.summaryText = summaryText
    frame.statusBarText = summaryText

    local recPrimary = recPanel:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(recPrimary, fontSize, "")
    recPrimary:SetText("")
    recPrimary:Hide()
    frame.recPrimary = recPrimary

    local recDetail = recPanel:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(recDetail, fontSize - 1, "")
    recDetail:SetText("")
    recDetail:Hide()
    frame.recDetail = recDetail

    -- Well Rested Perk quick toggle button
    local initPerkRank = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
    local btnPerk = CreateRetroButton(recPanel, string.format("[ PERK: R%d (+%d%%) ]", initPerkRank, initPerkRank * 4), 130, 18, function(self)
        CLIAlts:CycleWellRestedPerk()
        if MouseIsOver(self) and self:GetScript("OnEnter") then
            self:GetScript("OnEnter")(self)
        end
    end)
    btnPerk:SetPoint("RIGHT", recBtnSetup, "LEFT", -6, 0)
    btnPerk:SetScript("OnEnter", function(self)
        local curT = CLIAlts:GetTheme()
        if self.SetBackdropColor then self:SetBackdropColor(curT.rowHover[1], curT.rowHover[2], curT.rowHover[3], 0.8) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("WoW Forever: Well Rested Perk", 1, 1, 1)
        local r = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
        GameTooltip:AddLine(string.format("Current Rank: |cffffffff%d / 5|r", r), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(string.format("Rest Speed: |cff00ff66+%d%%|r", r * 4), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(string.format("Rested Cap: |cff00ff66%d%%|r", 150 + (r * 6)), 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Click to cycle rank (0-5).", 1, 0.82, 0)
        GameTooltip:AddLine("Slash cmd: |cff00ff66/clialts perk <0-5>|r", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btnPerk:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then self:SetBackdropColor(0, 0, 0, 0.6) end
        GameTooltip:Hide()
    end)
    if CLIAlts:IsRetail() then
        btnPerk:Hide()
    end
    frame.btnPerk = btnPerk

    -- 3. Modern KPI Metric Cards Grid (RESTED | PROFESSIONS | GOLD)
    local kpiContainer = CreateFrame("Frame", "CLIAltsKPIContainer", frame)
    kpiContainer:SetSize(1122, 52)
    kpiContainer:SetPoint("TOPLEFT", recPanel, "BOTTOMLEFT", 0, -8)
    frame.kpiContainer = kpiContainer

    local cardDefs = {
        { key = "rested", title = "RESTED", sub = "Characters" },
        { key = "profs",  title = "PROFESSIONS", sub = "Tracked roles" },
        { key = "gold",   title = "GOLD", sub = "Combined wealth" },
    }
    frame.kpiCards = {}
    local cardW = math.floor((1122 - 16) / 3)
    local prevCard = nil
    for _, def in ipairs(cardDefs) do
        local card = CreateFrame("Frame", nil, kpiContainer, BackdropTemplateMixin and "BackdropTemplate" or nil)
        card:SetSize(cardW, 52)
        if not prevCard then
            card:SetPoint("TOPLEFT", kpiContainer, "TOPLEFT", 0, 0)
        else
            card:SetPoint("LEFT", prevCard, "RIGHT", 8, 0)
        end
        card:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        if card.SetBackdropColor then
            card:SetBackdropColor(pBg[1], pBg[2], pBg[3], 0.70)
            card:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 0.3)
        end

        local title = card:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(title, 10, "")
        title:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -6)
        title:SetText(def.title)
        title:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
        card.title = title

        local val = card:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(val, 18, "OUTLINE")
        val:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
        val:SetText("0")
        val:SetTextColor(t.text[1], t.text[2], t.text[3])
        card.val = val

        local sub = card:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(sub, 9, "")
        sub:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 6)
        sub:SetText(def.sub)
        sub:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
        card.sub = sub

        frame.kpiCards[def.key] = card
        prevCard = card
    end

    -- 4. Sub-Header & Sub-Navigation Strip (OVERVIEW | RESTED XP PROFESSIONS ECONOMY)
    local subViewTitle = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(subViewTitle, 11, "OUTLINE")
    subViewTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -236)
    subViewTitle:SetText("OVERVIEW")
    subViewTitle:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
    frame.subViewTitle = subViewTitle

    local subViewFilters = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(subViewFilters, 10, "")
    subViewFilters:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -236)
    subViewFilters:SetText("RESTED XP    PROFESSIONS    ECONOMY")
    subViewFilters:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
    frame.subViewFilters = subViewFilters

    local midAscii2 = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(midAscii2, fontSize)
    midAscii2:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -246)
    midAscii2:SetText("")
    frame.midAscii2 = midAscii2

    local tableTopAscii = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(tableTopAscii, fontSize)
    tableTopAscii:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -248)
    tableTopAscii:SetText("")
    frame.tableTopAscii = tableTopAscii

    -- Column Header Line (Individual Cells) & Clickable Hit Frame
    local headerFrame = CreateFrame("Frame", nil, frame)
    headerFrame:SetSize(1126, 18)
    headerFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -252)
    frame.headerFrame = headerFrame

    local headerBorderL = headerFrame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(headerBorderL, fontSize)
    headerBorderL:SetPoint("LEFT", headerFrame, "LEFT", 4, 0)
    headerBorderL:SetText("")
    frame.headerBorderL = headerBorderL

    local headerBorderR = headerFrame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(headerBorderR, fontSize)
    headerBorderR:SetPoint("RIGHT", headerFrame, "RIGHT", -4, 0)
    headerBorderR:SetText("")
    frame.headerBorderR = headerBorderR

    frame.headerCells = {}
    for i = 1, 8 do
        local hCell = headerFrame:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(hCell, fontSize)
        hCell:SetWordWrap(false)
        hCell:SetHeight(18)
        frame.headerCells[i] = hCell

        local btn = CreateFrame("Button", nil, headerFrame)
        btn:SetHeight(18)
        btn:EnableMouse(true)
        btn:SetScript("OnClick", function(self)
            if self.sortKey then
                CLIAlts:ToggleSortKey(self.sortKey)
            end
        end)
        btn:SetScript("OnEnter", function(self)
            if self.colTitle then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(string.format("Sort by %s", self.colTitle), 1, 1, 1)
                GameTooltip:AddLine("Click to toggle ascending / descending.", 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        btn:Hide()
        headerButtons[i] = btn
    end

    -- Header separator ASCII line
    local tableSepAscii = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(tableSepAscii, fontSize)
    tableSepAscii:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -248)
    tableSepAscii:SetText(BORDER_LINE)
    frame.tableSepAscii = tableSepAscii

    -- Rows Container
    local rowsContainer = CreateFrame("Frame", nil, frame)
    rowsContainer:SetSize(1126, ROWS_COUNT * 36)
    rowsContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -268)
    frame.rowsContainer = rowsContainer

    -- Mousewheel pagination
    rowsContainer:EnableMouseWheel(true)
    rowsContainer:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            if currentPage > 1 then
                currentPage = currentPage - 1
                PlayRetroSound()
                CLIAlts:Render()
            end
        else
            if currentPage < totalPages then
                currentPage = currentPage + 1
                PlayRetroSound()
                CLIAlts:Render()
            end
        end
    end)

    -- Create 8 Modern 2-Line Row Buttons (with graphic status bars)
    for i = 1, ROWS_COUNT do
        local row = CreateFrame("Button", nil, rowsContainer, BackdropTemplateMixin and "BackdropTemplate" or nil)
        row:SetSize(1126, 34)
        row:SetPoint("TOPLEFT", rowsContainer, "TOPLEFT", 0, -((i - 1) * 36))
        row.rowIndex = i

        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        local t = CLIAlts:GetTheme()
        local rowBg = (i % 2 == 0) and (t.rowEven or { 0.098, 0.082, 0.047, 0.32 }) or (t.rowOdd or { 0.098, 0.082, 0.047, 0.12 })
        if row.SetBackdropColor then
            row:SetBackdropColor(rowBg[1], rowBg[2], rowBg[3], rowBg[4])
        end
        if row.SetBackdropBorderColor then
            row:SetBackdropBorderColor(0, 0, 0, 0)
        end

        local borderL = row:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(borderL, fontSize)
        borderL:SetPoint("LEFT", row, "LEFT", 4, 0)
        borderL:SetText("")
        row.borderL = borderL

        local borderR = row:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(borderR, fontSize)
        borderR:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        borderR:SetText("")
        row.borderR = borderR

        -- Modern Tab 1 (Overview) Two-Line Elements:
        local nameLine = row:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(nameLine, fontSize + 1, "OUTLINE")
        nameLine:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -4)
        nameLine:SetJustifyH("LEFT")
        nameLine:SetText("")
        row.nameLine = nameLine

        local subLine = row:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(subLine, fontSize - 2, "")
        subLine:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 16, 4)
        subLine:SetJustifyH("LEFT")
        subLine:SetText("")
        row.subLine = subLine

        local levelText = row:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(levelText, fontSize + 1, "OUTLINE")
        levelText:SetPoint("CENTER", row, "LEFT", 416, 0)
        levelText:SetJustifyH("CENTER")
        levelText:SetText("")
        row.levelText = levelText

        local restPercentText = row:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(restPercentText, fontSize, "OUTLINE")
        restPercentText:SetPoint("LEFT", row, "LEFT", 470, 0)
        restPercentText:SetJustifyH("RIGHT")
        restPercentText:SetWidth(46)
        restPercentText:SetText("")
        row.restPercentText = restPercentText

        local barBg = CreateFrame("Frame", nil, row, BackdropTemplateMixin and "BackdropTemplate" or nil)
        barBg:SetSize(280, 8)
        barBg:SetPoint("LEFT", restPercentText, "RIGHT", 10, 0)
        barBg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        if barBg.SetBackdropColor then
            barBg:SetBackdropColor(0.04, 0.03, 0.02, 0.8)
        end
        if barBg.SetBackdropBorderColor then
            barBg:SetBackdropBorderColor(0.3, 0.25, 0.15, 0.5)
        end
        row.barBg = barBg

        local barFill = barBg:CreateTexture(nil, "ARTWORK")
        barFill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        barFill:SetPoint("TOPLEFT", barBg, "TOPLEFT", 1, -1)
        barFill:SetPoint("BOTTOMLEFT", barBg, "BOTTOMLEFT", 1, 1)
        barFill:SetWidth(0)
        row.barFill = barFill

        local etaText = row:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(etaText, fontSize - 1, "")
        etaText:SetPoint("RIGHT", row, "RIGHT", -24, 0)
        etaText:SetJustifyH("RIGHT")
        etaText:SetText("")
        row.etaText = etaText

        -- Multi-column cells for Tabs 2 to 6
        row.cells = {}
        for j = 1, 8 do
            local cell = row:CreateFontString(nil, "OVERLAY")
            self:SetWidgetFont(cell, fontSize)
            cell:SetWordWrap(false)
            cell:SetHeight(18)
            cell:SetText("")
            row.cells[j] = cell
        end

        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, button)
            if self.charData then
                CLIAlts.selectedCharKey = self.charData.fullName or self.charData.name
                CLIAlts:Render()
                local curTab = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.activeTab
                if button == "RightButton" then
                    CLIAlts:ShowRowContextMenu(self, self.charData)
                elseif curTab == 7 then
                    if IsShiftKeyDown and IsShiftKeyDown() then
                        CLIAlts:CycleCharacterSupplyRole(self.charData)
                        CLIAlts:RequestRender()
                    else
                        CLIAlts:ShowMailRouteDialog(self.charData)
                    end
                elseif IsShiftKeyDown and IsShiftKeyDown() and CLIAlts:IsForeverMode() then
                    CLIAlts:CycleCharacterTier(self.charData)
                    CLIAlts:RequestRender()
                else
                    CLIAlts:ShowDossierPopup(self.charData)
                end
            end
        end)

        row:SetScript("OnEnter", function(self)
            local t = CLIAlts:GetTheme()
            local hov = t.rowHover or { 0.949, 0.788, 0.298, 0.25 }
            if self.SetBackdropColor then
                self:SetBackdropColor(hov[1], hov[2], hov[3], 0.45)
            end
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(t.primary[1], t.primary[2], t.primary[3], 0.6)
            end
            if self.borderL then
                self.borderL:SetText(string.format("|cff%s>|r", t.primaryHex or "f2c94c"))
            end
            if self.charData then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local coloredName = CLIAlts:ColorizePlayerName(self.charData.fullName or self.charData.name, self.charData.classFile)
                GameTooltip:AddLine(string.format("%s - %s", coloredName, self.charData.location or "Unknown"), 1, 1, 1)
                if self.charData.realm and self.charData.realm ~= "" and self.charData.realm ~= "Forever" then
                    GameTooltip:AddLine(string.format("Realm: |cffffffff%s|r", self.charData.realm), 0.8, 0.8, 0.8)
                end
                if self.charData.bindLocation and self.charData.bindLocation ~= "" then
                    GameTooltip:AddLine(string.format("Hearth: |cffffffff%s|r", self.charData.bindLocation), 0.8, 0.8, 0.8)
                end
                local isStale, daysInactive = CLIAlts:IsCharStale(self.charData)
                if isStale then
                    GameTooltip:AddLine(string.format("|cff%s[STALE]|r Inactive for %d days", t.blockedHex or "ff6b6b", daysInactive), 1, 0.3, 0.3)
                end

                local xpData = CLIAlts:GetLevelProgressData(self.charData)
                if xpData and not xpData.isMaxLevel then
                    GameTooltip:AddLine(string.format("Level %d Progress: |cffffffff%s / %s XP|r (%5.1f%%)",
                        self.charData.level or 1, CLIAlts:FormatNumber(xpData.curXP), CLIAlts:FormatNumber(xpData.maxXP), xpData.percentExact), 0.8, 0.8, 0.8)
                    GameTooltip:AddLine(string.format("XP to Level %d: |cff%s%s XP needed|r",
                        (self.charData.level or 1) + 1, t.readyHex or "55e39a", CLIAlts:FormatNumber(xpData.remainingXP)), 0.8, 0.8, 0.8)
                else
                    local maxLvl = (self.charData and self.charData.level) or CLIAlts:GetMaxLevel()
                    GameTooltip:AddLine(string.format("Level: |cff%s%d (MAX LEVEL)|r", t.readyHex or "55e39a", maxLvl), 0.8, 0.8, 0.8)
                end

                local rested = CLIAlts:GetRestedData(self.charData)
                if rested and not rested.isMaxLevel then
                    local est = rested.isEstimate and "~" or ""
                    local capTarget = rested.maxPercent or 150
                    GameTooltip:AddLine(string.format("Rested Pool: |cffffffff%s%s XP|r (%s%d%% of level, %s)",
                        est, CLIAlts:FormatNumber(rested.currentRested), est, rested.percent, rested.statusStr), 0.8, 0.8, 0.8)
                    GameTooltip:AddLine(string.format("Time to Capped (%d%%): |cffffffff%s|r (%s)", capTarget, rested.timeLeftStr, rested.fullDate), 0.8, 0.8, 0.8)
                    if rested.isEstimate then
                        GameTooltip:AddLine(string.format("|cff%s* Rested values are estimated (~disconnect / crash)|r", t.pendingHex or "ffb547"), 1, 0.8, 0)
                    end
                end

                if self.charData.note and self.charData.note ~= "" then
                    GameTooltip:AddLine(string.format("Note: |cffffd700%s|r", self.charData.note), 1, 0.85, 0.2)
                end

                local curTab = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.activeTab
                if curTab == 7 then
                    local role, isOv, autoRole = CLIAlts:GetCharacterEffectiveSupplyRole(self.charData)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Mail Routing & Material Stream:", 1, 0.82, 0)
                    GameTooltip:AddLine(string.format("Assigned Stream: |cffffffff%s|r (%s)", role, isOv and "|cffffb547OVERRIDE|r" or "|cff57d6e8AUTO|r"), 0.8, 0.8, 0.8)
                    GameTooltip:AddLine(string.format("Auto Suggestion: |cffa9a08c%s|r", autoRole), 0.7, 0.7, 0.7)
                    local pCount, pDetail = CLIAlts:GetCharacterPendingMail(self.charData)
                    if pCount > 0 then
                        GameTooltip:AddLine(string.format("Pending in Bags: |cff55e39a%d items (%s)|r", pCount, pDetail), 0.8, 0.8, 0.8)
                    end
                    GameTooltip:AddLine("Left-Click: Configure Route | Shift-Click: Cycle Stream | Right-Click: Menu", 0.7, 0.7, 0.7)
                elseif CLIAlts:IsForeverMode() then
                    local pAlerts = CLIAlts:GetCharacterProfessionAlerts(self.charData)
                    for _, a in ipairs(pAlerts) do
                        if a.type == "TRAIN" then
                            GameTooltip:AddLine(string.format("|cff%s* %s|r", t.readyHex or "55e39a", a.text), 1, 1, 1)
                        elseif a.type == "BOTTLENECK" then
                            GameTooltip:AddLine(string.format("|cff%s* %s|r", t.pendingHex or "ffb547", a.text), 1, 0.8, 0)
                        end
                    end
                    GameTooltip:AddLine("Left-Click: Dossier | Shift-Click: Cycle Role | Right-Click: Context Menu", 0.7, 0.7, 0.7)
                else
                    GameTooltip:AddLine("Left-Click: Open Alt Dossier | Right-Click: Context Menu", 0.7, 0.7, 0.7)
                end
                GameTooltip:Show()
            end
        end)

        row:SetScript("OnLeave", function(self)
            local t = CLIAlts:GetTheme()
            local isSelected = (CLIAlts.selectedCharKey and self.charData and (self.charData.fullName == CLIAlts.selectedCharKey or self.charData.name == CLIAlts.selectedCharKey))
            if isSelected then
                local hov = t.rowHover or { 0.949, 0.788, 0.298, 0.25 }
                if self.SetBackdropColor then
                    self:SetBackdropColor(hov[1], hov[2], hov[3], 0.35)
                end
                if self.SetBackdropBorderColor then
                    self:SetBackdropBorderColor(t.highlight[1], t.highlight[2], t.highlight[3], 0.8)
                end
                if self.borderL then
                    self.borderL:SetText(string.format("|cff%s>|r", t.highlightHex or "ffd34e"))
                end
            else
                local rowBg = (self.rowIndex and self.rowIndex % 2 == 0) and (t.rowEven or { 0.098, 0.082, 0.047, 0.32 }) or (t.rowOdd or { 0.098, 0.082, 0.047, 0.12 })
                if self.SetBackdropColor then
                    self:SetBackdropColor(rowBg[1], rowBg[2], rowBg[3], rowBg[4])
                end
                if self.SetBackdropBorderColor then
                    self:SetBackdropBorderColor(0, 0, 0, 0)
                end
                if self.borderL then
                    self.borderL:SetText("")
                end
            end
            GameTooltip:Hide()
        end)

        rowFrames[i] = row
    end
    frame.rowFrames = rowFrames

    -- Bottom border ASCII line
    local tableBotAscii = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(tableBotAscii, fontSize)
    tableBotAscii:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -558)
    tableBotAscii:SetText(BORDER_LINE)
    frame.tableBotAscii = tableBotAscii

    -- Footer: Pagination controls and helper tips
    local btnPrev = CreateRetroButton(frame, "[<< PREV]", 75, 18, function()
        if currentPage > 1 then
            currentPage = currentPage - 1
            CLIAlts:Render()
        end
    end)
    btnPrev:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 12)
    frame.btnPrev = btnPrev

    local btnNext = CreateRetroButton(frame, "[NEXT >>]", 75, 18, function()
        if currentPage < totalPages then
            currentPage = currentPage + 1
            CLIAlts:Render()
        end
    end)
    btnNext:SetPoint("LEFT", btnPrev, "RIGHT", 6, 0)
    frame.btnNext = btnNext

    local pageText = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(pageText, fontSize)
    pageText:SetPoint("LEFT", btnNext, "RIGHT", 10, 0)
    pageText:SetText("PAGE 1 OF 1")
    frame.pageText = pageText

    local statusTip = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(statusTip, fontSize - 1)
    statusTip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
    statusTip:SetJustifyH("RIGHT")
    statusTip:SetText("|cff888888Select a character for details · Right-click for management|r")
    frame.statusTip = statusTip

    -- Command Prompt Separator Line (empty)
    local promptSepAscii = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(promptSepAscii, fontSize)
    promptSepAscii:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 24)
    promptSepAscii:SetText("")
    frame.promptSepAscii = promptSepAscii

    -- Interactive Command Prompt (EditBox with > prompt)
    local promptLabel = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(promptLabel, fontSize, "")
    promptLabel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 12)
    promptLabel:SetText("> ")
    promptLabel:Hide()
    frame.promptLabel = promptLabel

    local promptBox = CreateFrame("EditBox", "CLIAltsPromptEditBox", frame)
    self:SetWidgetFont(promptBox, fontSize)
    promptBox:SetPoint("LEFT", promptLabel, "RIGHT", 2, 0)
    promptBox:SetPoint("RIGHT", frame, "RIGHT", -340, 0)
    promptBox:SetHeight(16)
    promptBox:SetAutoFocus(false)
    promptBox:EnableMouse(true)
    promptBox:SetTextInsets(2, 2, 2, 2)
    promptBox:Hide()
    frame.promptBox = promptBox

    local historyIndex = 0

    promptBox:SetScript("OnEnterPressed", function(self)
        local text = self:GetText() or ""
        self:SetText("")
        historyIndex = 0
        self:ClearFocus()
        CLIAlts:ExecutePromptCommand(text)
    end)

    promptBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    promptBox:SetScript("OnTabPressed", function(self)
        CLIAlts:AutoCompletePrompt(self)
    end)

    promptBox:SetScript("OnArrowPressed", function(self, key)
        local hist = (CLIAltsDB and CLIAltsDB.commandHistory) or {}
        if #hist == 0 then return end
        if key == "UP" then
            if historyIndex == 0 then
                historyIndex = #hist
            elseif historyIndex > 1 then
                historyIndex = historyIndex - 1
            end
            self:SetText(hist[historyIndex] or "")
            self:SetCursorPosition(string.len(self:GetText()))
        elseif key == "DOWN" then
            if historyIndex > 0 and historyIndex < #hist then
                historyIndex = historyIndex + 1
                self:SetText(hist[historyIndex] or "")
                self:SetCursorPosition(string.len(self:GetText()))
            else
                historyIndex = 0
                self:SetText("")
            end
        end
    end)

    -- Prompt Hint & Feedback Line
    local promptStatusTip = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(promptStatusTip, fontSize - 2)
    promptStatusTip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
    promptStatusTip:SetJustifyH("RIGHT")
    promptStatusTip:SetText("|cff888888[Type: sort <col>, filter <text>, role <tier>, next, export, help]|r")
    promptStatusTip:Hide()
    frame.promptStatusTip = promptStatusTip

    -- Hook ChatEdit_InsertLink so Shift-clicking items into prompt works
    if hooksecurefunc then
        pcall(hooksecurefunc, "ChatEdit_InsertLink", function(text)
            if InCombatLockdown and InCombatLockdown() then return end
            if text and promptBox:HasFocus() then
                promptBox:Insert(text)
            end
        end)
    end

    -- Hidden Buttons for Enter and / keyboard overrides
    -- Passes through to standard WoW chat when the mouse is NOT hovering over CLIAlts
    local btnFocusEnter = CreateFrame("Button", "CLIAltsFocusEnterBtn", frame)
    btnFocusEnter:SetScript("OnClick", function()
        if MouseIsOver and MouseIsOver(frame) then
            if frame:IsShown() and frame.promptBox and not frame.promptBox:HasFocus() then
                frame.promptLabel:Show()
                frame.promptBox:Show()
                if frame.statusTip then frame.statusTip:Hide() end
                if frame.promptStatusTip then frame.promptStatusTip:Show() end
                frame.promptBox:SetFocus()
            end
        else
            if ChatFrame_OpenChat then
                ChatFrame_OpenChat("")
            end
        end
    end)

    local btnFocusSlash = CreateFrame("Button", "CLIAltsFocusSlashBtn", frame)
    btnFocusSlash:SetScript("OnClick", function()
        if MouseIsOver and MouseIsOver(frame) then
            if frame:IsShown() and frame.promptBox and not frame.promptBox:HasFocus() then
                frame.promptLabel:Show()
                frame.promptBox:Show()
                if frame.statusTip then frame.statusTip:Hide() end
                if frame.promptStatusTip then frame.promptStatusTip:Show() end
                frame.promptBox:SetFocus()
                frame.promptBox:SetText("")
            end
        else
            if ChatFrame_OpenChat then
                ChatFrame_OpenChat("/")
            end
        end
    end)

    promptBox:SetScript("OnEditFocusGained", function()
        pcall(function()
            if InCombatLockdown and InCombatLockdown() then return end
            if ClearOverrideBindings then
                ClearOverrideBindings(frame)
            end
        end)
    end)
    promptBox:SetScript("OnEditFocusLost", function(self)
        pcall(function()
            if InCombatLockdown and InCombatLockdown() then return end
            if frame:IsShown() and SetOverrideBindingClick then
                SetOverrideBindingClick(frame, false, "ENTER", "CLIAltsFocusEnterBtn")
                SetOverrideBindingClick(frame, false, "/", "CLIAltsFocusSlashBtn")
            end
        end)
        self:Hide()
        if frame.promptLabel then frame.promptLabel:Hide() end
        if frame.promptStatusTip then frame.promptStatusTip:Hide() end
        if frame.statusTip then frame.statusTip:Show() end
    end)

    local botAscii = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(botAscii, fontSize)
    botAscii:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 1)
    botAscii:SetText(BORDER_LINE)
    frame.botAscii = botAscii

    -- 60s Periodic Refresh Ticker: Runs ONLY while mainFrame is visible
    local tickerElapsed = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        tickerElapsed = tickerElapsed + (elapsed or 0)
        if tickerElapsed >= 60 then
            tickerElapsed = 0
            CLIAlts:Render()
        end
    end)
    frame:SetScript("OnShow", function(self)
        tickerElapsed = 0
        pcall(function()
            if InCombatLockdown and InCombatLockdown() then return end
            if SetOverrideBindingClick then
                SetOverrideBindingClick(self, false, "ENTER", "CLIAltsFocusEnterBtn")
                SetOverrideBindingClick(self, false, "/", "CLIAltsFocusSlashBtn")
            end
        end)
        CLIAlts:ApplyLayoutSize()
        if renderDirty then
            CLIAlts:Render()
        end
    end)
    frame:SetScript("OnHide", function(self)
        pcall(function()
            if InCombatLockdown and InCombatLockdown() then return end
            if ClearOverrideBindings then
                ClearOverrideBindings(self)
            end
        end)
        if frame.promptBox then
            frame.promptBox:ClearFocus()
        end
        if CLIAlts.EndTour then
            CLIAlts:EndTour()
        end
    end)

    return frame
end

-- ============================================================================
-- Modern v2 Main Frame Construction (Design System v2: 1440x800)
-- ============================================================================
function CLIAlts:CreateModernMainFrame()
    if mainFrame then return mainFrame end
    if _G["CLIAltsMainFrame"] then
        mainFrame = _G["CLIAltsMainFrame"]
        self.mainFrame = mainFrame
        return mainFrame
    end

    local frame = CreateFrame("Frame", "CLIAltsMainFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame.isLegacyUI = false
    frame:Hide()
    frame:SetSize(1440, 800)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    tinsert(UISpecialFrames, "CLIAltsMainFrame")

    -- Restore saved window scale & position
    local s = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.scale) or 1.0
    frame:SetScale(s)
    self:RestoreWindowPosition(frame)

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        CLIAlts:SaveWindowPosition(self)
    end)

    -- Keyboard Navigation (Phase 6: Up/Down arrow selection and Enter)
    frame:EnableKeyboard(true)
    if frame.SetPropagateKeyboardInput then
        frame:SetPropagateKeyboardInput(true)
    end
    frame:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown and InCombatLockdown() then return end
        if (self.searchBox and self.searchBox:HasFocus())
            or (self.promptBox and self.promptBox:HasFocus()) then
            return
        end

        if key == "UP" or key == "DOWN" then
            CLIAlts:NavigateSelection(key == "UP" and -1 or 1)
        elseif key == "ENTER" then
            local char = CLIAlts:GetSelectedOrCurChar()
            if char then
                if CLIAlts:IsCompact() then
                    CLIAlts:ShowDossierPopup(char)
                else
                    CLIAlts:UpdateDetailPanel()
                    CLIAlts:Render()
                end
            end
        end
    end)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    local bgR, bgG, bgB, bgA = self:Hex("bg")
    local lineR, lineG, lineB, lineA = self:Hex("line")
    local panelR, panelG, panelB, panelA = self:Hex("panel")
    local raisedR, raisedG, raisedB, raisedA = self:Hex("raised")
    local brandR, brandG, brandB = self:Hex("brand")
    local warnR, warnG, warnB = self:Hex("warn")
    local fillR, fillG, fillB = self:Hex("fill")
    local textR, textG, textB = self:Hex("text")
    local mutedR, mutedG, mutedB = self:Hex("muted")

    if frame.SetBackdropColor then frame:SetBackdropColor(bgR, bgG, bgB, bgA) end
    if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end

    mainFrame = frame
    self.mainFrame = frame
    _G["CLIAltsMainFrame"] = frame

    -- 1. Top Bar (48px)
    local topBar = CreateFrame("Frame", "CLIAltsTopBar", frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    topBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    topBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    topBar:SetHeight(48)
    topBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if topBar.SetBackdropColor then topBar:SetBackdropColor(panelR, panelG, panelB, panelA) end
    if topBar.SetBackdropBorderColor then topBar:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
    frame.topBar = topBar

    -- Logo text
    local logoText = topBar:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(logoText, 19, "OUTLINE")
    logoText:SetPoint("LEFT", topBar, "LEFT", 18, 0)
    logoText:SetText("CLIAlts")
    logoText:SetTextColor(brandR, brandG, brandB)
    frame.logoText = logoText
    frame.titleText = logoText

    -- Search EditBox
    local searchBox = CreateFrame("EditBox", "CLIAltsSearchEditBox", topBar, BackdropTemplateMixin and "BackdropTemplate" or nil)
    searchBox:SetSize(340, 28)
    searchBox:SetPoint("LEFT", logoText, "RIGHT", 24, 0)
    searchBox:SetAutoFocus(false)
    searchBox:EnableMouse(true)
    searchBox:SetTextInsets(8, 8, 2, 2)
    self:SetWidgetFont(searchBox, 13)
    searchBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if searchBox.SetBackdropColor then searchBox:SetBackdropColor(raisedR, raisedG, raisedB, raisedA) end
    if searchBox.SetBackdropBorderColor then searchBox:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end

    local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(searchPlaceholder, 13, "")
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
    searchPlaceholder:SetText("Search name, class, profession...")
    searchPlaceholder:SetTextColor(mutedR, mutedG, mutedB)
    searchBox.placeholder = searchPlaceholder

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if #text > 0 then
            self.placeholder:Hide()
        else
            self.placeholder:Show()
        end
        if CLIAlts.SetFilter then
            CLIAlts:SetFilter(text)
        end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        if CLIAlts.SetFilter then
            CLIAlts:SetFilter("")
        end
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    frame.searchBox = searchBox

    -- Top Bar Action Buttons
    local btnClose = CreateRetroButton(topBar, "[ X ]", 28, 22, function()
        CLIAlts:Toggle(false)
    end)
    btnClose:SetPoint("RIGHT", topBar, "RIGHT", -14, 0)
    frame.btnClose = btnClose

    local btnHelp = CreateRetroButton(topBar, "Help", 50, 22, function()
        CLIAlts:ShowHelpPopup()
    end)
    btnHelp:SetPoint("RIGHT", btnClose, "LEFT", -8, 0)
    frame.btnHelp = btnHelp

    local btnSettings = CreateRetroButton(topBar, "Settings", 66, 22, function()
        CLIAlts:ShowSettingsDialog()
    end)
    btnSettings:SetPoint("RIGHT", btnHelp, "LEFT", -8, 0)
    btnSettings:SetScript("OnEnter", function(self)
        local curT = CLIAlts:GetTheme()
        if self.SetBackdropColor then self:SetBackdropColor(curT.border[1], curT.border[2], curT.border[3], 0.25) end
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(curT.primary[1], curT.primary[2], curT.primary[3], 1) end
        self.label:SetTextColor(curT.highlight[1], curT.highlight[2], curT.highlight[3])
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine("CLIAlts Settings & Preferences", 1, 0.82, 0)
        GameTooltip:AddLine("Configure themes, font sizes, UI scale, and automations.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btnSettings:SetScript("OnLeave", function(self)
        local curT = CLIAlts:GetTheme()
        local curBg = curT.panelBg or { 0.098, 0.082, 0.047, 0.90 }
        if self.SetBackdropColor then self:SetBackdropColor(curBg[1], curBg[2], curBg[3], 0.75) end
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(curT.dim[1], curT.dim[2], curT.dim[3], 0.8) end
        self.label:SetTextColor(curT.primary[1], curT.primary[2], curT.primary[3])
        GameTooltip:Hide()
    end)
    frame.btnSettings = btnSettings

    local initPerkRank = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
    local initLpData = CLIAlts:CalculateAccountLP()
    local initLpVal = (initLpData and initLpData.effectiveLP) or 0
    local btnPerk = CreateRetroButton(topBar, string.format("[ WELL RESTED: R%d · %.1f LP ]", initPerkRank, initLpVal), 170, 22, function(self)
        CLIAlts:CycleWellRestedPerk()
        if MouseIsOver and MouseIsOver(self) and self:GetScript("OnEnter") then
            self:GetScript("OnEnter")(self)
        end
        CLIAlts:Render()
    end)
    btnPerk:SetPoint("RIGHT", btnSettings, "LEFT", -8, 0)
    btnPerk:SetScript("OnEnter", function(self)
        local curT = CLIAlts:GetTheme()
        if self.SetBackdropColor then self:SetBackdropColor(curT.rowHover[1], curT.rowHover[2], curT.rowHover[3], 0.8) end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine("WoW Forever: Well Rested & Legacy Points", 1, 0.82, 0)
        local r = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
        local lpData = CLIAlts:CalculateAccountLP()
        GameTooltip:AddLine(string.format("Well Rested Perk: |cffffffffRank %d / 5|r", r), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(string.format("Rest Speed Bonus: |cff00ff66+%d%%|r (accumulates %d%% faster)", r * 4, r * 4), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(string.format("Rested XP Cap: |cff00ff66%d%%|r (standard 150%% + %d%%)", 150 + (r * 6), r * 6), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("Account Legacy Points: |cffe8b64a%.1f LP|r", lpData.effectiveLP), 1, 1, 1)
        GameTooltip:AddLine(string.format("Next Unlock Tier: |cffffffff%s|r (%.1f LP needed)", lpData.tierName, lpData.neededLP), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to cycle perk rank (0-5).", 1, 0.82, 0)
        GameTooltip:AddLine("Commands: |cff00ff66/ca perk <0-5>|r  |cff00ff66/ca lp|r", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btnPerk:SetScript("OnLeave", function(self)
        local curT = CLIAlts:GetTheme()
        local curBg = curT.panelBg or { 0.098, 0.082, 0.047, 0.90 }
        if self.SetBackdropColor then self:SetBackdropColor(curBg[1], curBg[2], curBg[3], 0.75) end
        GameTooltip:Hide()
    end)
    if CLIAlts:IsRetail() then
        btnPerk:Hide()
    end
    frame.btnPerk = btnPerk

    -- 2. Left Sidebar (210px)
    local sidebar = CreateFrame("Frame", "CLIAltsSidebar", frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -48)
    sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 34)
    sidebar:SetWidth(210)
    sidebar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if sidebar.SetBackdropColor then sidebar:SetBackdropColor(panelR, panelG, panelB, panelA) end
    if sidebar.SetBackdropBorderColor then sidebar:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
    frame.sidebar = sidebar

    local navDefs = {
        { id = 1, text = "Overview", badge = "7", isOverview = true },
        { id = 3, text = "Rested XP", badge = "2", isWarn = true },
        { id = 4, text = "Professions", badge = nil },
        { id = 5, text = "Economy", badge = nil },
        { id = 6, text = "Cooldowns & Locks", badge = "3", isWarn = true },
        { id = 7, text = "Mail Routing", badge = "0", isMail = true },
    }
    frame.tabButtons = {}
    frame.sidebarNavButtons = {}
    local prevNavBtn = nil
    for _, def in ipairs(navDefs) do
        local thisTabId = def.id
        local navBtn = CreateFrame("Button", nil, sidebar, BackdropTemplateMixin and "BackdropTemplate" or nil)
        navBtn:SetSize(190, 34)
        if not prevNavBtn then
            navBtn:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 10, -14)
        else
            navBtn:SetPoint("TOPLEFT", prevNavBtn, "BOTTOMLEFT", 0, -6)
        end
        navBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })

        local label = navBtn:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(label, 14, "")
        label:SetPoint("LEFT", navBtn, "LEFT", 12, 0)
        label:SetText(def.text)
        navBtn.label = label
        navBtn.tabId = thisTabId
        navBtn.baseText = def.text

        if def.badge or def.isMail then
            local badge = CreateFrame("Frame", nil, navBtn, BackdropTemplateMixin and "BackdropTemplate" or nil)
            badge:SetSize(22, 18)
            badge:SetPoint("RIGHT", navBtn, "RIGHT", -10, 0)
            badge:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            if badge.SetBackdropColor then
                if def.isOverview or def.isMail then
                    badge:SetBackdropColor(fillR, fillG, fillB, 0.25)
                    badge:SetBackdropBorderColor(fillR, fillG, fillB, 0.6)
                else
                    badge:SetBackdropColor(warnR, warnG, warnB, 0.9)
                    badge:SetBackdropBorderColor(warnR, warnG, warnB, 1.0)
                end
            end
            local badgeText = badge:CreateFontString(nil, "OVERLAY")
            self:SetWidgetFont(badgeText, 11, "OUTLINE")
            badgeText:SetPoint("CENTER", 0, 0)
            badgeText:SetText(def.badge or "0")
            if def.isOverview or def.isMail then
                badgeText:SetTextColor(fillR, fillG, fillB)
            else
                badgeText:SetTextColor(0.1, 0.08, 0.02)
            end
            badge.text = badgeText
            navBtn.badge = badge
        end

        navBtn:SetScript("OnClick", function()
            CLIAlts:SwitchTab(thisTabId)
        end)
        navBtn:SetScript("OnEnter", function(self)
            if self.SetBackdropColor then self:SetBackdropColor(raisedR, raisedG, raisedB, 0.6) end
            self.label:SetTextColor(1, 1, 1)
        end)
        navBtn:SetScript("OnLeave", function(self)
            local curTab = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.activeTab) or 1
            local active = (curTab == self.tabId)
            if self.SetBackdropColor then
                self:SetBackdropColor(active and raisedR or 0, active and raisedG or 0, active and raisedB or 0, active and 0.85 or 0)
            end
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(active and lineR or 0, active and lineG or 0, active and lineB or 0, active and 0.8 or 0)
            end
            self.label:SetTextColor(active and 1 or mutedR, active and 1 or mutedG, active and 1 or mutedB)
        end)

        table.insert(frame.tabButtons, navBtn)
        table.insert(frame.sidebarNavButtons, navBtn)
        prevNavBtn = navBtn
    end

    -- Pinned Account Wealth Widget at bottom of sidebar
    local wealthWidget = CreateFrame("Frame", "CLIAltsWealthWidget", sidebar)
    wealthWidget:SetSize(186, 68)
    wealthWidget:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 12, 16)
    wealthWidget:EnableMouse(true)
    frame.wealthWidget = wealthWidget

    local wealthTitle = wealthWidget:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(wealthTitle, 11, "")
    wealthTitle:SetPoint("TOPLEFT", wealthWidget, "TOPLEFT", 0, 0)
    wealthTitle:SetText("Account wealth")
    wealthTitle:SetTextColor(mutedR, mutedG, mutedB)
    wealthWidget.title = wealthTitle

    local wealthTotal = wealthWidget:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(wealthTotal, 16, "OUTLINE")
    wealthTotal:SetPoint("TOPLEFT", wealthTitle, "BOTTOMLEFT", 0, -4)
    wealthTotal:SetText("0c")
    wealthTotal:SetTextColor(textR, textG, textB)
    wealthWidget.total = wealthTotal

    local wealthDelta = wealthWidget:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(wealthDelta, 11, "")
    wealthDelta:SetPoint("TOPLEFT", wealthTotal, "BOTTOMLEFT", 0, -2)
    wealthDelta:SetText("Calculating...")
    wealthDelta:SetTextColor(mutedR, mutedG, mutedB)
    wealthWidget.delta = wealthDelta

    wealthWidget:SetScript("OnEnter", function(wSelf)
        if not GameTooltip then return end
        GameTooltip:SetOwner(wSelf, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Account Wealth Summary", 1, 0.82, 0)
        GameTooltip:AddLine("Sum of liquid currency (Gold, Silver, Copper) across all characters.", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("Does NOT include inventory or item valuation.", 0.45, 0.75, 1, true)
        GameTooltip:AddLine(" ")

        local chars = CLIAlts:GetCharactersList()
        for _, c in ipairs(chars) do
            local cMoney = c.money or 0
            local cName = CLIAlts:ColorizePlayerName(c.name, c.classFile)
            local moneyStr = CLIAlts:FormatMoney(cMoney, true)
            local lvlInfo = c.level and string.format(" |cffa9a08c(L%d)|r", c.level) or ""
            GameTooltip:AddDoubleLine(cName .. lvlInfo, moneyStr, 1, 1, 1, 1, 1, 1)
        end

        GameTooltip:AddLine(" ")
        local summary = CLIAlts:GetAccountSummary()
        GameTooltip:AddDoubleLine("Total Combined:", CLIAlts:FormatMoney(summary.totalGold or 0, true), 1, 0.82, 0, 1, 1, 1)

        local d1, d7, d30 = CLIAlts:GetGoldHistoryDeltas()
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Gold Trend History:", 0.85, 0.85, 0.85)

        local function formatDelta(val)
            if val > 0 then
                return string.format("|cff55e39a+%sg|r", CLIAlts:FormatNumber(val))
            elseif val < 0 then
                return string.format("|cffff4444-%sg|r", CLIAlts:FormatNumber(math.abs(val)))
            else
                return "|cffa9a08c±0g|r"
            end
        end

        GameTooltip:AddDoubleLine("Past 24 Hours:", formatDelta(d1), 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine("Past 7 Days:", formatDelta(d7), 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine("Past 30 Days:", formatDelta(d30), 0.7, 0.7, 0.7, 1, 1, 1)

        GameTooltip:Show()
    end)
    wealthWidget:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    -- 3. Bottom Command Bar (34px)
    local cmdBar = CreateFrame("Frame", "CLIAltsCmdBar", frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    cmdBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    cmdBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    cmdBar:SetHeight(34)
    cmdBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if cmdBar.SetBackdropColor then cmdBar:SetBackdropColor(panelR, panelG, panelB, panelA) end
    if cmdBar.SetBackdropBorderColor then cmdBar:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
    frame.cmdBar = cmdBar

    local cmdPromptIndicator = cmdBar:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(cmdPromptIndicator, 12, "")
    cmdPromptIndicator:SetPoint("LEFT", cmdBar, "LEFT", 14, 0)
    cmdPromptIndicator:SetText("> Type a command, or try:")
    cmdPromptIndicator:SetTextColor(mutedR, mutedG, mutedB)
    frame.cmdPromptIndicator = cmdPromptIndicator

    local hintChips = {
        { text = "next", cmd = "next" },
        { text = "plan 2", cmd = "plan 2" },
        { text = "unlocked mc", cmd = "unlocked mc" },
        { text = "digest", cmd = "digest" },
    }
    local prevChip = nil
    frame.hintChips = {}
    for _, hc in ipairs(hintChips) do
        local chip = CreateRetroButton(cmdBar, hc.text, #hc.text * 8 + 14, 20, function()
            CLIAlts:ExecutePromptCommand(hc.cmd)
        end)
        chip.cmd = hc.cmd
        chip.text = hc.text
        if not prevChip then
            chip:SetPoint("LEFT", cmdPromptIndicator, "RIGHT", 8, 0)
        else
            chip:SetPoint("LEFT", prevChip, "RIGHT", 6, 0)
        end
        table.insert(frame.hintChips, chip)
        prevChip = chip
    end

    local legendText = cmdBar:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(legendText, 11, "")
    legendText:SetPoint("RIGHT", cmdBar, "RIGHT", -14, 0)
    legendText:SetText("Capped means at the XP cap. Losing means XP is being wasted.")
    legendText:SetTextColor(mutedR, mutedG, mutedB)
    frame.legendText = legendText

    local promptBox = CreateFrame("EditBox", "CLIAltsPromptEditBox", cmdBar, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self:SetWidgetFont(promptBox, 12)
    promptBox:SetPoint("LEFT", prevChip, "RIGHT", 10, 0)
    promptBox:SetPoint("RIGHT", legendText, "LEFT", -14, 0)
    promptBox:SetHeight(22)
    promptBox:SetAutoFocus(false)
    promptBox:EnableMouse(true)
    promptBox:SetTextInsets(6, 6, 2, 2)
    promptBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if promptBox.SetBackdropColor then promptBox:SetBackdropColor(raisedR, raisedG, raisedB, 0.75) end
    if promptBox.SetBackdropBorderColor then promptBox:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
    promptBox:SetTextColor(textR, textG, textB)
    frame.promptBox = promptBox

    promptBox:SetScript("OnEditFocusGained", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(brandR, brandG, brandB, 0.9)
        end
    end)
    promptBox:SetScript("OnEditFocusLost", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(lineR, lineG, lineB, lineA)
        end
    end)

    local historyIndex = 0
    promptBox:SetScript("OnEnterPressed", function(self)
        local text = self:GetText() or ""
        self:SetText("")
        historyIndex = 0
        self:ClearFocus()
        CLIAlts:ExecutePromptCommand(text)
    end)
    promptBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    promptBox:SetScript("OnTabPressed", function(self)
        CLIAlts:AutoCompletePrompt(self)
    end)
    promptBox:SetScript("OnArrowPressed", function(self, key)
        local hist = (CLIAltsDB and CLIAltsDB.commandHistory) or {}
        if #hist == 0 then return end
        if key == "UP" then
            if historyIndex == 0 then
                historyIndex = #hist
            elseif historyIndex > 1 then
                historyIndex = historyIndex - 1
            end
            self:SetText(hist[historyIndex] or "")
            self:SetCursorPosition(#self:GetText())
        elseif key == "DOWN" then
            if historyIndex > 0 and historyIndex < #hist then
                historyIndex = historyIndex + 1
                self:SetText(hist[historyIndex] or "")
                self:SetCursorPosition(#self:GetText())
            elseif historyIndex == #hist then
                historyIndex = 0
                self:SetText("")
            end
        end
    end)

    -- 4. Right Detail Panel (340px)
    local detailPanel = CreateFrame("Frame", "CLIAltsDetailPanel", frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    detailPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -56)
    detailPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 42)
    detailPanel:SetWidth(340)
    detailPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if detailPanel.SetBackdropColor then detailPanel:SetBackdropColor(panelR, panelG, panelB, panelA) end
    if detailPanel.SetBackdropBorderColor then detailPanel:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
    frame.detailPanel = detailPanel

    local detailAvatar = CreateFrame("Frame", nil, detailPanel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    detailAvatar:SetSize(44, 44)
    detailAvatar:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 14, -14)
    detailAvatar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if detailAvatar.SetBackdropColor then detailAvatar:SetBackdropColor(raisedR, raisedG, raisedB, 0.8) end
    if detailAvatar.SetBackdropBorderColor then detailAvatar:SetBackdropBorderColor(brandR, brandG, brandB, 0.8) end
    local detailAvatarText = detailAvatar:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(detailAvatarText, 20, "OUTLINE")
    detailAvatarText:SetPoint("CENTER", 0, 0)
    detailAvatarText:SetText("T")
    detailAvatarText:SetTextColor(brandR, brandG, brandB)
    detailAvatar.text = detailAvatarText
    detailPanel.avatar = detailAvatar

    local detailName = detailPanel:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(detailName, 20, "OUTLINE")
    detailName:SetPoint("TOPLEFT", detailAvatar, "TOPRIGHT", 10, -2)
    detailName:SetText("Thor")
    detailName:SetTextColor(textR, textG, textB)
    detailPanel.name = detailName

    local detailSub = detailPanel:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(detailSub, 14, "")
    detailSub:SetPoint("TOPLEFT", detailName, "BOTTOMLEFT", 0, -3)
    detailSub:SetText("47 Orc Warrior · Horde")
    detailSub:SetTextColor(mutedR, mutedG, mutedB)
    detailPanel.sub = detailSub

    local restedCard = CreateFrame("Frame", nil, detailPanel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    restedCard:SetPoint("TOPLEFT", detailAvatar, "BOTTOMLEFT", 0, -14)
    restedCard:SetPoint("RIGHT", detailPanel, "RIGHT", -14, 0)
    restedCard:SetHeight(112)
    restedCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if restedCard.SetBackdropColor then restedCard:SetBackdropColor(raisedR, raisedG, raisedB, 0.8) end
    if restedCard.SetBackdropBorderColor then restedCard:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
    detailPanel.restedCard = restedCard

    local rcHeader = restedCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(rcHeader, 12, "")
    rcHeader:SetPoint("TOPLEFT", restedCard, "TOPLEFT", 10, -8)
    rcHeader:SetText("RESTED XP")
    rcHeader:SetTextColor(mutedR, mutedG, mutedB)
    restedCard.header = rcHeader

    local rcLP = restedCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(rcLP, 12, "OUTLINE")
    rcLP:SetPoint("TOPRIGHT", restedCard, "TOPRIGHT", -10, -8)
    rcLP:SetText("")
    rcLP:SetTextColor(brandR, brandG, brandB)
    restedCard.lpText = rcLP

    local rcStatus = restedCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(rcStatus, 15, "OUTLINE")
    rcStatus:SetPoint("TOPLEFT", rcHeader, "BOTTOMLEFT", 0, -3)
    rcStatus:SetText("Capped 3d 4h, ~52k XP wasted")
    rcStatus:SetTextColor(warnR, warnG, warnB)
    restedCard.status = rcStatus

    local rcBarBg = CreateFrame("Frame", nil, restedCard, BackdropTemplateMixin and "BackdropTemplate" or nil)
    rcBarBg:SetHeight(8)
    rcBarBg:SetPoint("TOPLEFT", rcStatus, "BOTTOMLEFT", 0, -4)
    rcBarBg:SetPoint("RIGHT", restedCard, "RIGHT", -10, 0)
    rcBarBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    if rcBarBg.SetBackdropColor then rcBarBg:SetBackdropColor(lineR, lineG, lineB, 1.0) end
    if rcBarBg.SetBackdropBorderColor then rcBarBg:SetBackdropBorderColor(0, 0, 0, 0) end
    restedCard.barBg = rcBarBg

    local rcBarFill = rcBarBg:CreateTexture(nil, "ARTWORK")
    rcBarFill:SetTexture("Interface\\Buttons\\WHITE8X8")
    rcBarFill:SetPoint("TOPLEFT", rcBarBg, "TOPLEFT", 0, 0)
    rcBarFill:SetPoint("BOTTOMLEFT", rcBarBg, "BOTTOMLEFT", 0, 0)
    rcBarFill:SetWidth(0)
    restedCard.barFill = rcBarFill

    local rcRate = restedCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(rcRate, 13, "")
    rcRate:SetPoint("TOPLEFT", rcBarBg, "BOTTOMLEFT", 0, -4)
    rcRate:SetPoint("RIGHT", restedCard, "RIGHT", -10, 0)
    rcRate:SetJustifyH("LEFT")
    rcRate:SetWordWrap(false)
    rcRate:SetText("Logging in now banks about 38k XP per hour.")
    rcRate:SetTextColor(mutedR, mutedG, mutedB)
    restedCard.rate = rcRate

    local rcPerk = restedCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(rcPerk, 12, "")
    rcPerk:SetPoint("TOPLEFT", rcRate, "BOTTOMLEFT", 0, -3)
    rcPerk:SetText("")
    rcPerk:SetTextColor(mutedR, mutedG, mutedB)
    restedCard.perkLine = rcPerk

    restedCard:EnableMouse(true)
    restedCard:SetScript("OnEnter", function(self)
        local curT = CLIAlts:GetTheme()
        if self.SetBackdropColor then self:SetBackdropColor(curT.rowHover[1], curT.rowHover[2], curT.rowHover[3], 0.45) end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("WoW Forever: Well Rested & Legacy Points", 1, 0.82, 0)
        local r = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
        local lpData = CLIAlts:CalculateAccountLP()
        GameTooltip:AddLine(string.format("Well Rested Perk: |cffffffffRank %d / 5|r", r), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(string.format("Rest Speed Bonus: |cff00ff66+%d%%|r (accumulates %d%% faster)", r * 4, r * 4), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(string.format("Rested XP Cap: |cff00ff66%d%%|r (standard 150%% + %d%%)", 150 + (r * 6), r * 6), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("Account Legacy Points: |cffe8b64a%.1f LP|r", lpData.effectiveLP), 1, 1, 1)
        GameTooltip:AddLine(string.format("Next Unlock Tier: |cffffffff%s|r (%.1f LP needed)", lpData.tierName, lpData.neededLP), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to cycle perk rank (0-5).", 1, 0.82, 0)
        GameTooltip:AddLine("Commands: |cff00ff66/ca perk <0-5>|r  |cff00ff66/ca lp|r", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    restedCard:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then self:SetBackdropColor(raisedR, raisedG, raisedB, 0.8) end
        GameTooltip:Hide()
    end)
    restedCard:SetScript("OnMouseDown", function()
        CLIAlts:CycleWellRestedPerk()
        CLIAlts:UpdateDetailPanel()
        CLIAlts:Render()
    end)

    -- 2b. Location, Hearth, Last Seen, Note Card (Phase 6)
    local infoCard = CreateFrame("Frame", nil, detailPanel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    infoCard:SetPoint("TOPLEFT", restedCard, "BOTTOMLEFT", 0, -8)
    infoCard:SetPoint("RIGHT", detailPanel, "RIGHT", -14, 0)
    infoCard:SetHeight(106)
    infoCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if infoCard.SetBackdropColor then infoCard:SetBackdropColor(raisedR, raisedG, raisedB, 0.8) end
    if infoCard.SetBackdropBorderColor then infoCard:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
    detailPanel.infoCard = infoCard

    local icHeader = infoCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(icHeader, 12, "")
    icHeader:SetPoint("TOPLEFT", infoCard, "TOPLEFT", 10, -8)
    icHeader:SetText("LOCATION & STATUS")
    icHeader:SetTextColor(mutedR, mutedG, mutedB)
    infoCard.header = icHeader

    local icLoc = infoCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(icLoc, 13, "")
    icLoc:SetPoint("TOPLEFT", icHeader, "BOTTOMLEFT", 0, -3)
    icLoc:SetPoint("RIGHT", infoCard, "RIGHT", -10, 0)
    icLoc:SetJustifyH("LEFT")
    icLoc:SetText("Location: Unknown")
    icLoc:SetTextColor(textR, textG, textB)
    infoCard.loc = icLoc

    local icHearth = infoCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(icHearth, 13, "")
    icHearth:SetPoint("TOPLEFT", icLoc, "BOTTOMLEFT", 0, -3)
    icHearth:SetPoint("RIGHT", infoCard, "RIGHT", -10, 0)
    icHearth:SetJustifyH("LEFT")
    icHearth:SetText("Hearth: Unknown")
    icHearth:SetTextColor(textR, textG, textB)
    infoCard.hearth = icHearth

    local icSeen = infoCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(icSeen, 13, "")
    icSeen:SetPoint("TOPLEFT", icHearth, "BOTTOMLEFT", 0, -3)
    icSeen:SetPoint("RIGHT", infoCard, "RIGHT", -10, 0)
    icSeen:SetJustifyH("LEFT")
    icSeen:SetText("Last seen: Unknown")
    icSeen:SetTextColor(textR, textG, textB)
    infoCard.seen = icSeen

    local icNote = infoCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(icNote, 13, "")
    icNote:SetPoint("TOPLEFT", icSeen, "BOTTOMLEFT", 0, -3)
    icNote:SetPoint("RIGHT", infoCard, "RIGHT", -10, 0)
    icNote:SetJustifyH("LEFT")
    icNote:SetText("Note: None")
    icNote:SetTextColor(textR, textG, textB)
    infoCard.note = icNote

    -- 2c. Professions & Cooldowns Card (Phase 6)
    local profCard = CreateFrame("Frame", nil, detailPanel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    profCard:SetPoint("TOPLEFT", infoCard, "BOTTOMLEFT", 0, -8)
    profCard:SetPoint("RIGHT", detailPanel, "RIGHT", -14, 0)
    profCard:SetHeight(104)
    profCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if profCard.SetBackdropColor then profCard:SetBackdropColor(raisedR, raisedG, raisedB, 0.8) end
    if profCard.SetBackdropBorderColor then profCard:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
    detailPanel.profCard = profCard

    local pcHeader = profCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(pcHeader, 12, "")
    pcHeader:SetPoint("TOPLEFT", profCard, "TOPLEFT", 10, -8)
    pcHeader:SetText("PROFESSIONS & COOLDOWNS")
    pcHeader:SetTextColor(mutedR, mutedG, mutedB)
    profCard.header = pcHeader

    local pcPrimary = profCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(pcPrimary, 13, "")
    pcPrimary:SetPoint("TOPLEFT", pcHeader, "BOTTOMLEFT", 0, -3)
    pcPrimary:SetPoint("RIGHT", profCard, "RIGHT", -10, 0)
    pcPrimary:SetJustifyH("LEFT")
    pcPrimary:SetText("Primary: None learned")
    pcPrimary:SetTextColor(textR, textG, textB)
    profCard.primary = pcPrimary

    local pcSecondary = profCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(pcSecondary, 13, "")
    pcSecondary:SetPoint("TOPLEFT", pcPrimary, "BOTTOMLEFT", 0, -3)
    pcSecondary:SetPoint("RIGHT", profCard, "RIGHT", -10, 0)
    pcSecondary:SetJustifyH("LEFT")
    pcSecondary:SetText("Secondary: None learned")
    pcSecondary:SetTextColor(textR, textG, textB)
    profCard.secondary = pcSecondary

    local pcCooldowns = profCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(pcCooldowns, 13, "")
    pcCooldowns:SetPoint("TOPLEFT", pcSecondary, "BOTTOMLEFT", 0, -3)
    pcCooldowns:SetPoint("RIGHT", profCard, "RIGHT", -10, 0)
    pcCooldowns:SetJustifyH("LEFT")
    pcCooldowns:SetText("Cooldowns: None ready")
    pcCooldowns:SetTextColor(textR, textG, textB)
    profCard.cooldowns = pcCooldowns

    -- 2d. Saved Instances & Lockouts Card (Phase 6)
    local lockCard = CreateFrame("Frame", nil, detailPanel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    lockCard:SetPoint("TOPLEFT", profCard, "BOTTOMLEFT", 0, -8)
    lockCard:SetPoint("RIGHT", detailPanel, "RIGHT", -14, 0)
    lockCard:SetHeight(64)
    lockCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if lockCard.SetBackdropColor then lockCard:SetBackdropColor(raisedR, raisedG, raisedB, 0.8) end
    if lockCard.SetBackdropBorderColor then lockCard:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
    detailPanel.lockCard = lockCard

    local lcHeader = lockCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(lcHeader, 12, "")
    lcHeader:SetPoint("TOPLEFT", lockCard, "TOPLEFT", 10, -8)
    lcHeader:SetText("SAVED INSTANCES & LOCKOUTS")
    lcHeader:SetTextColor(mutedR, mutedG, mutedB)
    lockCard.header = lcHeader

    local lcLocks = lockCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(lcLocks, 13, "")
    lcLocks:SetPoint("TOPLEFT", lcHeader, "BOTTOMLEFT", 0, -3)
    lcLocks:SetPoint("RIGHT", lockCard, "RIGHT", -10, 0)
    lcLocks:SetJustifyH("LEFT")
    lcLocks:SetText("Lockouts: No active locks")
    lcLocks:SetTextColor(textR, textG, textB)
    lockCard.locks = lcLocks

    -- 3. Mail & Supply Stream Card
    local mailCard = CreateFrame("Frame", nil, detailPanel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    mailCard:SetPoint("TOPLEFT", lockCard, "BOTTOMLEFT", 0, -8)
    mailCard:SetPoint("RIGHT", detailPanel, "RIGHT", -14, 0)
    mailCard:SetHeight(106)
    mailCard:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if mailCard.SetBackdropColor then mailCard:SetBackdropColor(raisedR, raisedG, raisedB, 0.8) end
    if mailCard.SetBackdropBorderColor then mailCard:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
    detailPanel.mailCard = mailCard

    local mcHeader = mailCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(mcHeader, 12, "")
    mcHeader:SetPoint("TOPLEFT", mailCard, "TOPLEFT", 10, -8)
    mcHeader:SetText("MAIL & SUPPLY STREAM")
    mcHeader:SetTextColor(mutedR, mutedG, mutedB)
    mailCard.header = mcHeader

    local mcModeBadge = mailCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(mcModeBadge, 12, "OUTLINE")
    mcModeBadge:SetPoint("TOPRIGHT", mailCard, "TOPRIGHT", -10, -8)
    mcModeBadge:SetText("[AUTO]")
    mcModeBadge:SetTextColor(fillR, fillG, fillB)
    mailCard.modeBadge = mcModeBadge

    local mcStream = mailCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(mcStream, 15, "OUTLINE")
    mcStream:SetPoint("TOPLEFT", mcHeader, "BOTTOMLEFT", 0, -3)
    mcStream:SetText("Cloth (Tailor)")
    mcStream:SetTextColor(brandR, brandG, brandB)
    mailCard.stream = mcStream

    local mcPending = mailCard:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(mcPending, 13, "")
    mcPending:SetPoint("TOPLEFT", mcStream, "BOTTOMLEFT", 0, -3)
    mcPending:SetText("No pending materials in bags")
    mcPending:SetTextColor(mutedR, mutedG, mutedB)
    mailCard.pending = mcPending

    local btnConfigRoute = CreateRetroButton(mailCard, "Configure Stream", 130, 22, function()
        local char = CLIAlts:GetSelectedOrCurChar()
        if char then
            CLIAlts:ShowMailRouteDialog(char)
        end
    end)
    btnConfigRoute:SetPoint("BOTTOMLEFT", mailCard, "BOTTOMLEFT", 10, 8)
    mailCard.btnConfig = btnConfigRoute

    local btnCycleRoute = CreateRetroButton(mailCard, "Cycle", 56, 22, function()
        local char = CLIAlts:GetSelectedOrCurChar()
        if char then
            CLIAlts:CycleCharacterSupplyRole(char)
            CLIAlts:Render()
        end
    end)
    btnCycleRoute:SetPoint("LEFT", btnConfigRoute, "RIGHT", 6, 0)
    mailCard.btnCycle = btnCycleRoute

    local btnRemove = CreateRetroButton(detailPanel, "Remove", 76, 24, function()
        local char = CLIAlts:GetSelectedOrCurChar()
        if char then
            CLIAlts:ShowConfirmDelete(char)
        end
    end)
    btnRemove:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -12, 12)
    detailPanel.btnRemove = btnRemove

    local btnPlan = CreateRetroButton(detailPanel, "Plan session", 98, 24, function()
        CLIAlts:ExecutePromptCommand("plan 2")
    end)
    btnPlan:SetPoint("RIGHT", btnRemove, "LEFT", -6, 0)
    detailPanel.btnPlan = btnPlan

    local btnEditNote = CreateRetroButton(detailPanel, "Edit note", 80, 24, function()
        local char = CLIAlts:GetSelectedOrCurChar()
        if char and frame.promptBox then
            local name = char.name or char.fullName
            frame.promptBox:SetText("note " .. name .. " ")
            frame.promptBox:SetFocus()
            frame.promptBox:SetCursorPosition(#frame.promptBox:GetText())
        end
    end)
    btnEditNote:SetPoint("RIGHT", btnPlan, "LEFT", -6, 0)
    detailPanel.btnEditNote = btnEditNote

    -- 5. Center Main Column
    local mainCol = CreateFrame("Frame", "CLIAltsMainCol", frame)
    mainCol:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 12, -8)
    mainCol:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMLEFT", -12, 0)
    frame.mainCol = mainCol

    -- Play Next Banner (Phase 4 placeholder)
    local nextBanner = CreateFrame("Frame", "CLIAltsPlayNextBanner", mainCol, BackdropTemplateMixin and "BackdropTemplate" or nil)
    nextBanner:SetPoint("TOPLEFT", mainCol, "TOPLEFT", 0, 0)
    nextBanner:SetPoint("TOPRIGHT", mainCol, "TOPRIGHT", 0, 0)
    nextBanner:SetHeight(110)
    nextBanner:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if nextBanner.SetBackdropColor then nextBanner:SetBackdropColor(panelR, panelG, panelB, panelA) end
    if nextBanner.SetBackdropBorderColor then nextBanner:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
    frame.nextBanner = nextBanner
    frame.recPanel = nextBanner

    -- 1. Title ("Play next")
    local bannerTitle = nextBanner:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(bannerTitle, 15, "OUTLINE")
    bannerTitle:SetPoint("TOPLEFT", nextBanner, "TOPLEFT", 12, -10)
    bannerTitle:SetText("Play next")
    bannerTitle:SetTextColor(brandR, brandG, brandB)
    nextBanner.title = bannerTitle
    frame.recHeroTitle = bannerTitle

    -- 2. Headline ("<n> alts are losing rested XP right now", hides when n is 0)
    local bannerHeadline = nextBanner:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(bannerHeadline, 12, "OUTLINE")
    bannerHeadline:SetPoint("TOPRIGHT", nextBanner, "TOPRIGHT", -12, -12)
    bannerHeadline:SetText("")
    bannerHeadline:SetTextColor(warnR, warnG, warnB)
    nextBanner.headline = bannerHeadline
    frame.recReasonLine = bannerHeadline

    -- 3. Empty State Text ("Nothing is being wasted")
    local bannerEmpty = nextBanner:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(bannerEmpty, 13, "OUTLINE")
    bannerEmpty:SetPoint("CENTER", nextBanner, "CENTER", 0, -4)
    bannerEmpty:SetText("Nothing is being wasted")
    bannerEmpty:SetTextColor(mutedR, mutedG, mutedB)
    bannerEmpty:Hide()
    nextBanner.emptyText = bannerEmpty

    -- 4. Three Cards (name, level class, one reason line)
    nextBanner.cards = {}
    for i = 1, 3 do
        local card = CreateFrame("Button", "CLIAltsPlayNextCard" .. i, nextBanner, BackdropTemplateMixin and "BackdropTemplate" or nil)
        card:SetHeight(44)
        if i == 1 then
            card:SetPoint("TOPLEFT", nextBanner, "TOPLEFT", 12, -32)
        else
            card:SetPoint("TOPLEFT", nextBanner.cards[i - 1], "TOPRIGHT", 8, 0)
        end
        card:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        if card.SetBackdropColor then card:SetBackdropColor(raisedR, raisedG, raisedB, 0.70) end
        if card.SetBackdropBorderColor then card:SetBackdropBorderColor(lineR, lineG, lineB, 0.50) end

        local cardTitle = card:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(cardTitle, 12, "OUTLINE")
        cardTitle:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -6)
        cardTitle:SetText("")
        card.title = cardTitle

        local cardMeta = card:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(cardMeta, 11, "")
        cardMeta:SetPoint("LEFT", cardTitle, "RIGHT", 5, 0)
        cardMeta:SetText("")
        cardMeta:SetTextColor(mutedR, mutedG, mutedB)
        card.meta = cardMeta

        local cardReason = card:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(cardReason, 10, "")
        cardReason:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -24)
        cardReason:SetPoint("RIGHT", card, "RIGHT", -6, 0)
        cardReason:SetJustifyH("LEFT")
        cardReason:SetText("")
        card.reason = cardReason

        card:SetScript("OnClick", function(cSelf)
            if cSelf.charData then
                CLIAlts.selectedCharKey = cSelf.charData.fullName or cSelf.charData.name
                local charsList = CLIAlts:GetCharactersList()
                local rowsPerPage = CLIAlts:GetRowsPerPage()
                for idx, c in ipairs(charsList) do
                    if (c.fullName and c.fullName == CLIAlts.selectedCharKey) or (c.name and c.name == CLIAlts.selectedCharKey) then
                        currentPage = math.floor((idx - 1) / rowsPerPage) + 1
                        break
                    end
                end
                PlayRetroSound()
                CLIAlts:Render()
            end
        end)
        card:SetScript("OnEnter", function(cSelf)
            if cSelf.SetBackdropBorderColor then
                cSelf:SetBackdropBorderColor(brandR, brandG, brandB, 0.90)
            end
            if cSelf.SetBackdropColor then
                cSelf:SetBackdropColor(raisedR, raisedG, raisedB, 1.0)
            end
        end)
        card:SetScript("OnLeave", function(cSelf)
            if cSelf.SetBackdropBorderColor then
                cSelf:SetBackdropBorderColor(lineR, lineG, lineB, 0.50)
            end
            if cSelf.SetBackdropColor then
                cSelf:SetBackdropColor(raisedR, raisedG, raisedB, 0.70)
            end
        end)

        nextBanner.cards[i] = card
    end

    -- 5. Plan Line (from existing planner, default 2h, hidden in compact mode)
    local bannerPlanLine = nextBanner:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(bannerPlanLine, 11, "")
    bannerPlanLine:SetPoint("BOTTOMLEFT", nextBanner, "BOTTOMLEFT", 12, 8)
    bannerPlanLine:SetPoint("BOTTOMRIGHT", nextBanner, "BOTTOMRIGHT", -12, 8)
    bannerPlanLine:SetText("")
    bannerPlanLine:SetTextColor(textR, textG, textB)
    nextBanner.planLine = bannerPlanLine

    nextBanner:SetScript("OnSizeChanged", function(bSelf)
        local bw = bSelf:GetWidth() or 700
        local cw = math.floor((bw - 24 - 16) / 3)
        if cw < 120 then cw = 120 end
        if bSelf.cards then
            for i = 1, 3 do
                bSelf.cards[i]:SetWidth(cw)
            end
        end
    end)

    -- Filter Bar (Phase 5)
    local filterBar = CreateFrame("Frame", "CLIAltsFilterBar", mainCol)
    filterBar:SetPoint("TOPLEFT", nextBanner, "BOTTOMLEFT", 0, -8)
    filterBar:SetPoint("TOPRIGHT", nextBanner, "BOTTOMRIGHT", 0, -8)
    filterBar:SetHeight(28)
    frame.filterBar = filterBar

    local filterChipsBar = CreateFrame("Frame", "CLIAltsFilterChipsBar", filterBar)
    filterChipsBar:SetAllPoints(filterBar)
    frame.filterChipsBar = filterChipsBar

    local chipDefs = {
        { key = nil,        label = "All" },
        { key = "horde",    label = "Horde" },
        { key = "alliance", label = "Alliance" },
        { key = "capped",   label = "Capped" },
        { key = "under 60", label = "Under 60" },
        { key = "has note", label = "Has note" },
    }

    local filterChips = {}
    local prevChip = nil
    for i, def in ipairs(chipDefs) do
        local chip = CreateFrame("Button", "CLIAltsFilterChip" .. i, filterChipsBar, BackdropTemplateMixin and "BackdropTemplate" or nil)
        chip:SetHeight(22)
        chip:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        if chip.SetBackdropColor then chip:SetBackdropColor(panelR, panelG, panelB, 0.8) end
        if chip.SetBackdropBorderColor then chip:SetBackdropBorderColor(lineR, lineG, lineB, 0.8) end

        local chipText = chip:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(chipText, 11, "")
        chipText:SetPoint("CENTER", chip, "CENTER", 0, 0)
        chipText:SetText(def.label)
        chipText:SetTextColor(mutedR, mutedG, mutedB)
        chip.label = chipText
        chip.filterKey = def.key
        chip.baseLabel = def.label

        if not prevChip then
            chip:SetPoint("LEFT", filterChipsBar, "LEFT", 0, 0)
        else
            chip:SetPoint("LEFT", prevChip, "RIGHT", 6, 0)
        end

        chip:SetScript("OnClick", function(cSelf)
            PlayRetroSound()
            CLIAlts:SetFilter(cSelf.filterKey)
        end)
        chip:SetScript("OnEnter", function(cSelf)
            if not cSelf.isActive then
                if cSelf.SetBackdropColor then cSelf:SetBackdropColor(raisedR, raisedG, raisedB, 0.9) end
                cSelf.label:SetTextColor(textR, textG, textB)
            end
        end)
        chip:SetScript("OnLeave", function(cSelf)
            if not cSelf.isActive then
                if cSelf.SetBackdropColor then cSelf:SetBackdropColor(panelR, panelG, panelB, 0.8) end
                if cSelf.SetBackdropBorderColor then cSelf:SetBackdropBorderColor(lineR, lineG, lineB, 0.8) end
                cSelf.label:SetTextColor(mutedR, mutedG, mutedB)
            else
                if cSelf.SetBackdropColor then cSelf:SetBackdropColor(raisedR, raisedG, raisedB, 1.0) end
                if cSelf.SetBackdropBorderColor then cSelf:SetBackdropBorderColor(brandR, brandG, brandB, 1.0) end
                cSelf.label:SetTextColor(brandR, brandG, brandB)
            end
        end)

        filterChips[i] = chip
        prevChip = chip
    end
    frame.filterChips = filterChips

    -- Right-aligned Sort Dropdown Button (Phase 5 / Artboard B)
    local btnSort = CreateFrame("Button", "CLIAltsSortButton", filterChipsBar, BackdropTemplateMixin and "BackdropTemplate" or nil)
    btnSort:SetHeight(22)
    btnSort:SetWidth(120)
    btnSort:SetPoint("RIGHT", filterChipsBar, "RIGHT", 0, 0)
    btnSort:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if btnSort.SetBackdropColor then btnSort:SetBackdropColor(panelR, panelG, panelB, 0.8) end
    if btnSort.SetBackdropBorderColor then btnSort:SetBackdropBorderColor(lineR, lineG, lineB, 0.8) end

    local btnSortText = btnSort:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(btnSortText, 11, "")
    btnSortText:SetPoint("CENTER", btnSort, "CENTER", 0, 0)
    btnSortText:SetText("Sort: Rested ▾")
    btnSortText:SetTextColor(mutedR, mutedG, mutedB)
    btnSort.label = btnSortText
    btnSort:SetScript("OnClick", function()
        PlayRetroSound()
        CLIAlts:CycleSort()
    end)
    btnSort:SetScript("OnEnter", function(bSelf)
        if bSelf.SetBackdropColor then bSelf:SetBackdropColor(raisedR, raisedG, raisedB, 0.9) end
        bSelf.label:SetTextColor(textR, textG, textB)
    end)
    btnSort:SetScript("OnLeave", function(bSelf)
        if bSelf.SetBackdropColor then bSelf:SetBackdropColor(panelR, panelG, panelB, 0.8) end
        bSelf.label:SetTextColor(mutedR, mutedG, mutedB)
    end)
    frame.btnSort = btnSort

    -- Prominent Well Rested & LP Badge for Rested XP view
    local wellRestedBadge = CreateFrame("Button", "CLIAltsWellRestedBadge", filterChipsBar, BackdropTemplateMixin and "BackdropTemplate" or nil)
    wellRestedBadge:SetHeight(22)
    wellRestedBadge:SetWidth(220)
    wellRestedBadge:SetPoint("RIGHT", btnSort, "LEFT", -10, 0)
    wellRestedBadge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if wellRestedBadge.SetBackdropColor then wellRestedBadge:SetBackdropColor(panelR, panelG, panelB, 0.85) end
    if wellRestedBadge.SetBackdropBorderColor then wellRestedBadge:SetBackdropBorderColor(brandR, brandG, brandB, 0.85) end

    local wellRestedBadgeText = wellRestedBadge:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(wellRestedBadgeText, 11, "OUTLINE")
    wellRestedBadgeText:SetPoint("CENTER", wellRestedBadge, "CENTER", 0, 0)
    wellRestedBadgeText:SetTextColor(brandR, brandG, brandB)
    wellRestedBadge.text = wellRestedBadgeText
    wellRestedBadge:Hide()
    frame.wellRestedBadge = wellRestedBadge

    wellRestedBadge:SetScript("OnClick", function()
        CLIAlts:CycleWellRestedPerk()
        CLIAlts:Render()
    end)
    wellRestedBadge:SetScript("OnEnter", function(self)
        if self.SetBackdropColor then self:SetBackdropColor(raisedR, raisedG, raisedB, 0.95) end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("WoW Forever: Well Rested & Legacy Points", 1, 0.82, 0)
        local r = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
        local lpData = CLIAlts:CalculateAccountLP()
        GameTooltip:AddLine(string.format("Well Rested Perk: |cffffffffRank %d / 5|r", r), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(string.format("Rest Speed Bonus: |cff00ff66+%d%%|r (accumulates %d%% faster)", r * 4, r * 4), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(string.format("Rested XP Cap: |cff00ff66%d%%|r (standard 150%% + %d%%)", 150 + (r * 6), r * 6), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("Account Legacy Points: |cffe8b64a%.1f LP|r", lpData.effectiveLP), 1, 1, 1)
        GameTooltip:AddLine(string.format("Next Unlock Tier: |cffffffff%s|r (%.1f LP needed)", lpData.tierName, lpData.neededLP), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to cycle perk rank (0-5).", 1, 0.82, 0)
        GameTooltip:AddLine("Commands: |cff00ff66/ca perk <0-5>|r  |cff00ff66/ca lp|r", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    wellRestedBadge:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then self:SetBackdropColor(panelR, panelG, panelB, 0.85) end
        GameTooltip:Hide()
    end)

    local mailActionBar = CreateFrame("Frame", "CLIAltsMailActionBar", filterBar)
    mailActionBar:SetAllPoints(filterBar)
    mailActionBar:Hide()
    frame.mailActionBar = mailActionBar

    local btnConsumables = CreateRetroButton(mailActionBar, "Auto-Mail Consumables: ON", 185, 22, function()
        CLIAlts:ToggleAutoMailConsumables()
        CLIAlts:Render()
    end)
    btnConsumables:SetPoint("LEFT", mailActionBar, "LEFT", 0, 3)
    mailActionBar.btnConsumables = btnConsumables

    local btnIgnored = CreateRetroButton(mailActionBar, "Ignored Items", 105, 22, function()
        CLIAlts:ListIgnoredMailItems()
    end)
    btnIgnored:SetPoint("LEFT", btnConsumables, "RIGHT", 6, 0)
    mailActionBar.btnIgnored = btnIgnored

    local btnPrintRoute = CreateRetroButton(mailActionBar, "Print in Chat", 95, 22, function()
        CLIAlts:PrintMailRouting()
    end)
    btnPrintRoute:SetPoint("LEFT", btnIgnored, "RIGHT", 6, 0)
    mailActionBar.btnPrintRoute = btnPrintRoute

    local mailHintText = mailActionBar:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(mailHintText, 11, "")
    mailHintText:SetPoint("RIGHT", mailActionBar, "RIGHT", -6, 3)
    mailHintText:SetText("Click an alt to configure · Shift-click to cycle")
    mailHintText:SetTextColor(mutedR, mutedG, mutedB)
    mailActionBar.hint = mailHintText

    -- Modern Table Column Headers (Tabs 2-7)
    local headerFrame = CreateFrame("Frame", "CLIAltsModernHeaderFrame", mainCol)
    headerFrame:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -4)
    headerFrame:SetPoint("RIGHT", mainCol, "RIGHT", 0, 0)
    headerFrame:SetHeight(20)
    headerFrame:Hide()
    frame.headerFrame = headerFrame

    frame.headerCells = {}
    for i = 1, 8 do
        local hCell = headerFrame:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(hCell, 12, "OUTLINE")
        hCell:SetWordWrap(false)
        hCell:SetHeight(18)
        frame.headerCells[i] = hCell

        local btn = CreateFrame("Button", nil, headerFrame)
        btn:SetHeight(18)
        btn:EnableMouse(true)
        btn:SetScript("OnClick", function(self)
            if self.sortKey then
                CLIAlts:ToggleSortKey(self.sortKey)
            end
        end)
        btn:SetScript("OnEnter", function(self)
            if self.colTitle then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(string.format("Sort by %s", self.colTitle), 1, 1, 1)
                GameTooltip:AddLine("Click to toggle ascending / descending.", 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        btn:Hide()
        headerButtons[i] = btn
    end

    -- Rows List Container
    local rowsContainer = CreateFrame("Frame", "CLIAltsRowsContainer", mainCol)
    rowsContainer:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)
    rowsContainer:SetPoint("BOTTOMRIGHT", mainCol, "BOTTOMRIGHT", 0, 0)
    rowsContainer:EnableMouseWheel(true)
    rowsContainer:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            if currentPage > 1 then
                currentPage = currentPage - 1
                PlayRetroSound()
                CLIAlts:Render()
            end
        else
            if currentPage < totalPages then
                currentPage = currentPage + 1
                PlayRetroSound()
                CLIAlts:Render()
            end
        end
    end)
    frame.rowsContainer = rowsContainer

    -- Hidden Button for Enter keyboard override (details on Enter)
    local btnFocusEnter = _G["CLIAltsFocusEnterBtn"] or CreateFrame("Button", "CLIAltsFocusEnterBtn", frame)
    btnFocusEnter:SetScript("OnClick", function()
        if MouseIsOver and MouseIsOver(frame) then
            if not (frame.searchBox and frame.searchBox:HasFocus()) and not (frame.promptBox and frame.promptBox:HasFocus()) then
                local selChar = CLIAlts:GetSelectedOrCurChar()
                if selChar then
                    CLIAlts:ShowDossierPopup(selChar)
                end
            end
        end
    end)

    -- Initialize 12 pooled row frames for Modern UI (Phase 2: Row List)
    local MODERN_ROWS_COUNT = 12
    for i = 1, MODERN_ROWS_COUNT do
        local row = CreateFrame("Button", "CLIAltsModernRow" .. i, rowsContainer, BackdropTemplateMixin and "BackdropTemplate" or nil)
        row:SetHeight(54)
        row:SetPoint("TOPLEFT", rowsContainer, "TOPLEFT", 0, -((i - 1) * 62))
        row:SetPoint("RIGHT", rowsContainer, "RIGHT", 0, 0)
        row.rowIndex = i
        if row.SetClipsChildren then row:SetClipsChildren(true) end
        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        if row.SetBackdropColor then row:SetBackdropColor(panelR, panelG, panelB, 0.65) end
        if row.SetBackdropBorderColor then row:SetBackdropBorderColor(lineR, lineG, lineB, 0.35) end

        -- 34px Class-Coloured Ring with Alt Initial
        local classRing = CreateFrame("Frame", nil, row, BackdropTemplateMixin and "BackdropTemplate" or nil)
        classRing:SetSize(34, 34)
        classRing:SetPoint("LEFT", row, "LEFT", 12, 0)
        classRing:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        row.classRing = classRing

        local classRingInitial = classRing:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(classRingInitial, 16, "OUTLINE")
        classRingInitial:SetPoint("CENTER", classRing, "CENTER", 0, 0)
        row.classRingInitial = classRingInitial

        -- Name & Subline (level race class · faction)
        -- Separated cleanly with vertical clearance and generous horizontal width (up to x=385)
        local nameLine = row:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(nameLine, 16, "OUTLINE")
        nameLine:SetPoint("TOPLEFT", classRing, "TOPRIGHT", 12, 1)
        nameLine:SetPoint("RIGHT", row, "LEFT", 385, 0)
        nameLine:SetJustifyH("LEFT")
        nameLine:SetWordWrap(false)
        nameLine:SetText("")
        row.nameLine = nameLine

        local subLine = row:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(subLine, 13, "")
        subLine:SetPoint("BOTTOMLEFT", classRing, "BOTTOMRIGHT", 12, 0)
        subLine:SetPoint("RIGHT", row, "LEFT", 385, 0)
        subLine:SetJustifyH("LEFT")
        subLine:SetWordWrap(false)
        subLine:SetText("")
        row.subLine = subLine

        -- Level XP Progress Bar & Label (anchored with generous room at x=405)
        local restLabel = row:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(restLabel, 13, "OUTLINE")
        restLabel:SetPoint("BOTTOMLEFT", row, "LEFT", 405, 4)
        restLabel:SetJustifyH("LEFT")
        restLabel:SetWordWrap(false)
        restLabel:SetText("")
        row.restLabel = restLabel
        row.restPercentText = restLabel

        local restBarBg = CreateFrame("Frame", nil, row, BackdropTemplateMixin and "BackdropTemplate" or nil)
        restBarBg:SetSize(180, 7)
        restBarBg:SetPoint("TOPLEFT", restLabel, "BOTTOMLEFT", 0, -3)
        restBarBg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        if restBarBg.SetBackdropColor then restBarBg:SetBackdropColor(lineR, lineG, lineB, 1.0) end
        if restBarBg.SetBackdropBorderColor then restBarBg:SetBackdropBorderColor(0, 0, 0, 0) end
        row.restBarBg = restBarBg
        row.barBg = restBarBg

        local restBarFill = restBarBg:CreateTexture(nil, "ARTWORK")
        restBarFill:SetTexture("Interface\\Buttons\\WHITE8X8")
        restBarFill:SetPoint("TOPLEFT", restBarBg, "TOPLEFT", 0, 0)
        restBarFill:SetPoint("BOTTOMLEFT", restBarBg, "BOTTOMLEFT", 0, 0)
        restBarFill:SetWidth(0)
        row.restBarFill = restBarFill
        row.barFill = restBarFill

        restBarBg:EnableMouse(true)
        restBarBg:SetScript("OnEnter", function(self)
            if row.charData then
                local xpData = CLIAlts:GetLevelProgressData(row.charData)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(string.format("Level %d Progress: %s", row.charData.level or 1, row.charData.name or ""), 1, 1, 1)
                if xpData and not xpData.isMaxLevel then
                    GameTooltip:AddLine(string.format("XP Gained: |cffffffff%s / %s|r (|cff00ff66%d%%|r)", CLIAlts:FormatNumber(xpData.curXP), CLIAlts:FormatNumber(xpData.maxXP), xpData.percent), 0.8, 0.8, 0.8)
                    GameTooltip:AddLine(string.format("Remaining to Level %d: |cffffd700%s XP|r", (row.charData.level or 1) + 1, CLIAlts:FormatNumber(xpData.remainingXP)), 0.8, 0.8, 0.8)
                    local rested = CLIAlts:GetRestedData(row.charData)
                    if rested and not rested.isMaxLevel then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(string.format("Rested XP Pool: |cffffffff%s XP|r (%d%%)", CLIAlts:FormatNumber(rested.currentRested or 0), rested.percent or 0), 0.7, 0.7, 0.7)
                    end
                else
                    GameTooltip:AddLine("Level cap reached.", 0.8, 0.8, 0.8)
                end
                GameTooltip:Show()
            end
        end)
        restBarBg:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Status Pill
        local statusPill = CreateFrame("Frame", nil, row, BackdropTemplateMixin and "BackdropTemplate" or nil)
        statusPill:SetSize(120, 24)
        statusPill:SetPoint("LEFT", restBarBg, "RIGHT", 20, 6)
        restLabel:SetPoint("RIGHT", statusPill, "LEFT", -10, 0)
        statusPill:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        row.statusPill = statusPill

        local statusPillText = statusPill:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(statusPillText, 12, "OUTLINE")
        statusPillText:SetPoint("CENTER", statusPill, "CENTER", 0, 0)
        statusPillText:SetText("")
        row.statusPillText = statusPillText
        row.etaText = statusPillText

        -- Right-Aligned Gold Value
        local goldText = row:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(goldText, 16, "OUTLINE")
        goldText:SetPoint("RIGHT", row, "RIGHT", -16, 0)
        goldText:SetJustifyH("RIGHT")
        goldText:SetText("")
        row.goldText = goldText

        -- Multi-column cells for Tabs 2 to 7
        row.cells = {}
        for j = 1, 8 do
            local cell = row:CreateFontString(nil, "OVERLAY")
            self:SetWidgetFont(cell, 13)
            cell:SetWordWrap(false)
            cell:SetHeight(20)
            cell:SetText("")
            row.cells[j] = cell
        end

        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, button)
            if self.charData then
                CLIAlts.selectedCharKey = self.charData.fullName or self.charData.name
                local curTab = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.activeTab
                if button == "RightButton" then
                    CLIAlts:ShowRowContextMenu(self, self.charData)
                elseif curTab == 7 then
                    if IsShiftKeyDown and IsShiftKeyDown() then
                        CLIAlts:CycleCharacterSupplyRole(self.charData)
                        CLIAlts:RequestRender()
                    else
                        CLIAlts:ShowMailRouteDialog(self.charData)
                    end
                elseif IsShiftKeyDown and IsShiftKeyDown() and CLIAlts:IsForeverMode() then
                    CLIAlts:CycleCharacterTier(self.charData)
                    CLIAlts:RequestRender()
                else
                    local now = (GetTime and GetTime()) or time()
                    if self.lastClickTime and (now - self.lastClickTime) < 0.35 then
                        CLIAlts:ShowDossierPopup(self.charData)
                    end
                    self.lastClickTime = now
                    CLIAlts:Render()
                end
            end
        end)

        row:SetScript("OnEnter", function(self)
            local isSelected = (CLIAlts.selectedCharKey and self.charData and (self.charData.fullName == CLIAlts.selectedCharKey or self.charData.name == CLIAlts.selectedCharKey))
            if not isSelected then
                if self.SetBackdropColor then self:SetBackdropColor(raisedR, raisedG, raisedB, 0.95) end
                if self.SetBackdropBorderColor then self:SetBackdropBorderColor(lineR, lineG, lineB, 0.65) end
            end
        end)

        row:SetScript("OnLeave", function(self)
            local isSelected = (CLIAlts.selectedCharKey and self.charData and (self.charData.fullName == CLIAlts.selectedCharKey or self.charData.name == CLIAlts.selectedCharKey))
            if isSelected then
                if self.SetBackdropColor then self:SetBackdropColor(raisedR, raisedG, raisedB, 0.95) end
                if self.SetBackdropBorderColor then self:SetBackdropBorderColor(brandR, brandG, brandB, 1.0) end
            else
                if self.SetBackdropColor then self:SetBackdropColor(panelR, panelG, panelB, 0.65) end
                if self.SetBackdropBorderColor then self:SetBackdropBorderColor(lineR, lineG, lineB, 0.35) end
            end
        end)

        rowFrames[i] = row
    end
    frame.rowFrames = rowFrames

    frame:SetScript("OnShow", function(self)
        pcall(function()
            if SetOverrideBindingClick then
                SetOverrideBindingClick(self, false, "ENTER", "CLIAltsFocusEnterBtn")
                SetOverrideBindingClick(self, false, "/", "CLIAltsFocusSlashBtn")
            end
        end)
        CLIAlts:ApplyLayoutSize()
        CLIAlts:Render()
    end)
    frame:SetScript("OnHide", function(self)
        pcall(function()
            if ClearOverrideBindings then
                ClearOverrideBindings(self)
            end
        end)
        if frame.promptBox then
            frame.promptBox:ClearFocus()
        end
        if CLIAlts.EndTour then
            CLIAlts:EndTour()
        end
    end)

    return frame
end

function CLIAlts:CreateMainFrame()
    if mainFrame then return mainFrame end
    if _G["CLIAltsMainFrame"] then
        mainFrame = _G["CLIAltsMainFrame"]
        self.mainFrame = mainFrame
        return mainFrame
    end

    if CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.legacyUI then
        return self:CreateLegacyMainFrame()
    end

    return self:CreateModernMainFrame()
end

function CLIAlts:RecreateMainFrame()
    if mainFrame then
        mainFrame:Hide()
        mainFrame:ClearAllPoints()
    end
    for _, r in ipairs(rowFrames) do
        if r.Hide then r:Hide() end
    end
    rowFrames = {}
    mainFrame = nil
    self.mainFrame = nil
    _G["CLIAltsMainFrame"] = nil
    return self:CreateMainFrame()
end

function CLIAlts:GetVisibleCharactersList()
    local activeTab = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.activeTab) or 1
    local activeSortBy = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.sortBy) or "rested"
    local activeSortAsc = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.sortAsc ~= nil) and CLIAltsDB.settings.sortAsc or false
    if mainFrame and mainFrame.isLegacyUI then
        if activeTab == 2 then
            activeSortBy = "rotation"
            activeSortAsc = false
        elseif activeTab == 3 then
            activeSortBy = "rested"
            activeSortAsc = false
        elseif activeTab == 4 then
            activeSortBy = "prof"
            activeSortAsc = true
        elseif activeTab == 5 then
            activeSortBy = "gold"
            activeSortAsc = false
        elseif activeTab == 6 then
            activeSortBy = "cooldown"
            activeSortAsc = true
        elseif activeTab == 7 then
            activeSortBy = "name"
            activeSortAsc = true
        end
    end
    return self:GetCharactersList(activeSortBy, activeSortAsc, self.activeFilter)
end

function CLIAlts:GetSelectedOrCurChar()
    local selectedKey = self.selectedCharKey
    local charList = self:GetVisibleCharactersList()
    if selectedKey then
        for _, c in ipairs(charList) do
            if (c.fullName and c.fullName == selectedKey) or (c.name and c.name == selectedKey) then
                return c
            end
        end
    end
    for _, c in ipairs(charList) do
        if (c.fullName and c.fullName == self.curPlayerFullName) or (c.name and c.name == self.curPlayerName) then
            return c
        end
    end
    return charList[1]
end

function CLIAlts:UpdateDetailPanel()
    if not mainFrame or not mainFrame.detailPanel then return end
    local dp = mainFrame.detailPanel
    local char = self:GetSelectedOrCurChar()
    if not char then
        dp:Hide()
        return
    end
    dp:Show()

    local brandR, brandG, brandB = self:Hex("brand")
    local textR, textG, textB = self:Hex("text")
    local mutedR, mutedG, mutedB = self:Hex("muted")
    local warnR, warnG, warnB = self:Hex("warn")
    local fillR, fillG, fillB = self:Hex("fill")

    -- 1. Avatar & Identity
    local rawName = char.name or char.fullName or "Unknown"
    local initial = rawName:sub(1, 1):upper()
    local classFile = char.classFile or "WARRIOR"
    local cr, cg, cb = self:GetClassColor(classFile)

    if dp.avatar then
        if dp.avatar.SetBackdropBorderColor then
            dp.avatar:SetBackdropBorderColor(cr, cg, cb, 0.9)
        end
        if dp.avatar.text then
            dp.avatar.text:SetText(initial)
            dp.avatar.text:SetTextColor(cr, cg, cb)
        end
    end

    if dp.name then
        local coloredName = self:ColorizePlayerName(rawName, char.classFile)
        dp.name:SetText(coloredName)
    end

    if dp.sub then
        local raceStr = char.race or ""
        local classStr = char.class or ""
        local facStr = char.faction or ""
        local tierStr = (char.tier == "CORE" and "Core") or (char.tier == "RESERVE" and "Alt") or (char.tier == "BANK" and "Bank Mule") or "Alt"
        dp.sub:SetText(string.format("%d %s %s · %s (%s)", char.level or 1, raceStr, classStr, facStr, tierStr))
        dp.sub:SetTextColor(mutedR, mutedG, mutedB)
    end

    -- 2. Rested XP Card
    if dp.restedCard then
        local rested = self:GetRestedData(char)
        local estRate = char.xpHour or 38000
        local r = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
        local lpData = self:CalculateAccountLP()

        if dp.restedCard.header then
            if not self:IsRetail() and r > 0 then
                dp.restedCard.header:SetText(string.format("RESTED XP · WELL RESTED R%d (+%d%%)", r, r * 4))
            else
                dp.restedCard.header:SetText("RESTED XP")
            end
        end
        if dp.restedCard.lpText then
            if not self:IsRetail() and lpData and lpData.effectiveLP then
                dp.restedCard.lpText:SetText(string.format("|cffe8b64a%.1f LP|r", lpData.effectiveLP))
                dp.restedCard.lpText:Show()
            else
                dp.restedCard.lpText:Hide()
            end
        end
        if dp.restedCard.perkLine then
            if not self:IsRetail() then
                dp.restedCard.perkLine:SetText(string.format("Well Rested: |cffffffffR%d/5 (+%d%%)|r · Cap: |cffffffff%d%%|r · LP: |cffe8b64a%.1f LP|r", r, r * 4, 150 + (r * 6), lpData.effectiveLP))
                dp.restedCard.perkLine:Show()
            else
                dp.restedCard.perkLine:Hide()
            end
        end

        if rested and not rested.isMaxLevel then
            local pct = rested.percent or 0
            local maxPct = rested.maxPercent or 150
            local poolXP = rested.currentRested or rested.usableXP or 0
            local est = rested.isEstimate and "~" or ""
            local wastedSec, wastedXP, _, timeStr = self:GetRestedWaste(char)

            if dp.restedCard.barBg and dp.restedCard.barFill then
                local ratio = math.min(1.0, math.max(0, pct / maxPct))
                local maxBarW = dp.restedCard.barBg:GetWidth()
                if not maxBarW or maxBarW <= 0 then maxBarW = 312 end
                local barW = math.floor(maxBarW * ratio)
                dp.restedCard.barFill:SetWidth(math.max(1, barW))
                dp.restedCard.barBg:Show()
            end

            if pct >= maxPct then
                if wastedSec and wastedSec > 0 then
                    local dur = timeStr or "0m"
                    dur = dur:gsub(" 0h$", ""):gsub(" 0m$", "")
                    if dur == "Just capped" then dur = "0m" end
                    dp.restedCard.status:SetText(string.format("Capped %s, ~%s XP wasted", dur, self:FormatNumber(wastedXP)))
                    dp.restedCard.status:SetTextColor(warnR, warnG, warnB)
                else
                    dp.restedCard.status:SetText(string.format("At Rested Cap (%d%%)", maxPct))
                    dp.restedCard.status:SetTextColor(fillR, fillG, fillB)
                end
                if dp.restedCard.barFill then
                    dp.restedCard.barFill:SetVertexColor(warnR, warnG, warnB, 1.0)
                end
                if dp.restedCard.rate then
                    dp.restedCard.rate:SetText(string.format("Logging in now banks about %s XP per hour.", self:FormatNumber(estRate)))
                    dp.restedCard.rate:SetTextColor(mutedR, mutedG, mutedB)
                end
            else
                dp.restedCard.status:SetText(string.format("%s%d%% Rested (%s XP pool)", est, pct, self:FormatNumber(poolXP)))
                dp.restedCard.status:SetTextColor(brandR, brandG, brandB)
                if dp.restedCard.barFill then
                    dp.restedCard.barFill:SetVertexColor(fillR, fillG, fillB, 1.0)
                end
                if dp.restedCard.rate then
                    dp.restedCard.rate:SetText(string.format("Caps in %s · Banks about %s XP per hour", rested.timeLeftStr or "---", self:FormatNumber(estRate)))
                    dp.restedCard.rate:SetTextColor(mutedR, mutedG, mutedB)
                end
            end
        else
            if dp.restedCard.status then
                dp.restedCard.status:SetText("Target Level Reached")
                dp.restedCard.status:SetTextColor(fillR, fillG, fillB)
            end
            if dp.restedCard.barBg then
                dp.restedCard.barBg:Hide()
            end
            if dp.restedCard.rate then
                dp.restedCard.rate:SetText("Level cap reached - Rested XP no longer accumulates.")
                dp.restedCard.rate:SetTextColor(mutedR, mutedG, mutedB)
            end
        end
    end

    -- 2b. Location & Status Card (Phase 6)
    if dp.infoCard then
        local restTag = char.loggedOutInRestZone and "|cff4CC2D6[Resting]|r" or "|cffF2B84B[Wild]|r"
        if dp.infoCard.loc then
            dp.infoCard.loc:SetText(string.format("Location: |cffffffff%s|r %s", tostring(char.location or "Unknown"), restTag))
        end
        if dp.infoCard.hearth then
            dp.infoCard.hearth:SetText(string.format("Hearth: |cffffffff%s|r", tostring(char.bindLocation or "Unknown")))
        end
        if dp.infoCard.seen then
            local isStale, daysInactive = self:IsCharStale(char)
            local staleTag = (isStale and daysInactive) and string.format(" |cffF2B84B[STALE: %dd]|r", tonumber(daysInactive) or 0) or ""
            local seenDate = self:FormatDateSafe(char.lastUpdate)
            dp.infoCard.seen:SetText(string.format("Last seen: |cffffffff%s|r (%s)%s", self:GetTimeAgo(char.lastUpdate), seenDate, staleTag))
        end
        if dp.infoCard.note then
            local noteStr = (char.note and char.note ~= "") and string.format("|cffffd700%s|r", tostring(char.note)) or "|cff9AA6B8None|r"
            dp.infoCard.note:SetText(string.format("Note: %s", noteStr))
        end
    end

    -- 2c. Professions & Cooldowns Card (Phase 6)
    if dp.profCard then
        if dp.profCard.primary then
            local primList = {}
            if char.professions and char.professions.primary and #char.professions.primary > 0 then
                for _, p in ipairs(char.professions.primary) do
                    table.insert(primList, string.format("%s (%d/%d)", p.name or "Unknown", p.rank or 0, p.maxRank or 0))
                end
            end
            local primStr = (#primList > 0) and table.concat(primList, ", ") or "None learned"
            dp.profCard.primary:SetText(string.format("Primary: |cffffffff%s|r", primStr))
        end
        if dp.profCard.secondary then
            local secList = {}
            if char.professions and char.professions.secondary and #char.professions.secondary > 0 then
                for _, s in ipairs(char.professions.secondary) do
                    table.insert(secList, string.format("%s (%d/%d)", s.name or "Unknown", s.rank or 0, s.maxRank or 0))
                end
            end
            local secStr = (#secList > 0) and table.concat(secList, ", ") or "None learned"
            dp.profCard.secondary:SetText(string.format("Secondary: |cffffffff%s|r", secStr))
        end
        if dp.profCard.cooldowns then
            local cdText = FmtTradeCooldowns(char)
            if not char.tradeCooldowns or not next(char.tradeCooldowns) then
                dp.profCard.cooldowns:SetText("Cooldowns: |cff9AA6B8None ready|r")
            else
                dp.profCard.cooldowns:SetText(string.format("Cooldowns: %s", cdText))
            end
        end
    end

    -- 2d. Saved Instances & Lockouts Card (Phase 6)
    if dp.lockCard then
        if dp.lockCard.locks then
            local lockText = FmtRaidLocks(char)
            if not char.lockouts or not next(char.lockouts) then
                dp.lockCard.locks:SetText("Lockouts: |cff9AA6B8No active locks|r")
            else
                dp.lockCard.locks:SetText(string.format("Lockouts: %s", lockText))
            end
        end
    end

    -- 3. Mail & Supply Stream Card
    if dp.mailCard then
        local curRole, isOverride, autoRole = self:GetCharacterEffectiveSupplyRole(char)
        if isOverride then
            dp.mailCard.modeBadge:SetText("[OVERRIDE]")
            dp.mailCard.modeBadge:SetTextColor(warnR, warnG, warnB)
            dp.mailCard.stream:SetText(curRole)
            dp.mailCard.stream:SetTextColor(brandR, brandG, brandB)
        else
            dp.mailCard.modeBadge:SetText("[AUTO]")
            dp.mailCard.modeBadge:SetTextColor(fillR, fillG, fillB)
            dp.mailCard.stream:SetText(autoRole or curRole or "General Mule")
            dp.mailCard.stream:SetTextColor(textR, textG, textB)
        end

        local pCount, pDetail = self:GetCharacterPendingMail(char)
        if pCount > 0 then
            dp.mailCard.pending:SetText(string.format("%d items pending (%s)", pCount, pDetail))
            dp.mailCard.pending:SetTextColor(fillR, fillG, fillB)
        else
            dp.mailCard.pending:SetText("No pending materials in bags")
            dp.mailCard.pending:SetTextColor(mutedR, mutedG, mutedB)
        end
    end
end

function CLIAlts:NavigateSelection(delta)
    local chars = self:GetVisibleCharactersList()
    if not chars or #chars == 0 then return end
    local curChar = self:GetSelectedOrCurChar()
    local curIndex = 1
    if curChar then
        for i, c in ipairs(chars) do
            if (c.fullName and curChar.fullName and c.fullName == curChar.fullName)
                or (c.name and curChar.name and c.name == curChar.name) then
                curIndex = i
                break
            end
        end
    end
    local newIndex = math.max(1, math.min(#chars, curIndex + delta))
    local sel = chars[newIndex]
    if sel then
        self.selectedCharKey = sel.fullName or sel.name
        local rpp = (self.GetRowsPerPage and self:GetRowsPerPage()) or 12
        local page = math.floor((newIndex - 1) / rpp) + 1
        if page ~= currentPage then
            currentPage = page
        end
        PlayRetroSound()
        self:Render()
    end
end

-- ----------------------------------------------------------------------------
-- Terminal Render Engine (Coalesced with Dirty Flag)
-- ----------------------------------------------------------------------------
local renderTimerPending = false

function CLIAlts:RequestRender()
    self._cachedSidebarBadges = nil
    renderDirty = true
    if self.UpdateLDB then
        self:UpdateLDB()
    end
    if not mainFrame or not mainFrame:IsShown() then
        return
    end
    if not renderTimerPending then
        renderTimerPending = true
        local safeAfter = self.SafeAfter or (C_Timer and C_Timer.After)
        if safeAfter then
            safeAfter(0.1, function()
                renderTimerPending = false
                if renderDirty and mainFrame and mainFrame:IsShown() then
                    renderDirty = false
                    CLIAlts:Render()
                end
            end)
        else
            renderTimerPending = false
            renderDirty = false
            CLIAlts:Render()
        end
    end
end

function CLIAlts:Render()
    renderDirty = false
    if self.UpdateLDB then
        self:UpdateLDB()
    end
    if not mainFrame or not mainFrame:IsShown() then return end

    local ok, err = pcall(function()
        local activeTab = CLIAltsDB.settings.activeTab or 1
        if activeTab == 7 then
            self._cachedMailReadySummary = self:GetMailReadySummary()
        else
            self._cachedMailReadySummary = nil
        end
        local t = self:GetTheme()

    -- Highlight active tab button
    local isComp = self:IsCompact()
    local tabTitles = {
        [1] = "OVERVIEW",
        [2] = "FOREVER ROUTE",
        [3] = "RESTED XP MONITOR",
        [4] = "PROFESSIONS & MILESTONES",
        [5] = "ECONOMY & WEALTH",
        [6] = "COOLDOWNS & INSTANCE LOCKS",
        [7] = "MAIL ROUTING & SUPPLY CHAIN",
    }
    local curTabTitle = tabTitles[activeTab] or "OVERVIEW"
    if mainFrame.titleText then
        mainFrame.titleText:SetText("CLIAlts")
    end
    if mainFrame.subTitleText then
        mainFrame.subTitleText:SetText(isComp and "/ ALT MONITOR" or "/ ALT MONITOR")
    end
    if mainFrame.subViewTitle then
        mainFrame.subViewTitle:SetText(curTabTitle)
        mainFrame.subViewTitle:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
    end
    if mainFrame.subViewFilters then
        if activeTab == 7 then
            mainFrame.subViewFilters:SetText("CLICK ALT TO CONFIGURE ROUTING · SHIFT-CLICK TO CYCLE")
        elseif activeTab == 3 then
            local r = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
            local lpData = self:CalculateAccountLP()
            local lpVal = (lpData and lpData.effectiveLP) or 0
            mainFrame.subViewFilters:SetText(string.format("WELL RESTED: RANK %d (+%d%%) · ACCOUNT LP: %.1f LP", r, r * 4, lpVal))
        else
            mainFrame.subViewFilters:SetText("RESTED XP    PROFESSIONS    ECONOMY")
        end
    end

    -- Highlight active tab button with clear amber pill outline
    for _, tabBtn in ipairs(mainFrame.tabButtons or {}) do
        local base = isComp and tabBtn.compactText or tabBtn.baseText
        local isActive = (tabBtn.tabId == activeTab)
        tabBtn.label:SetText(base)
        if not mainFrame.isLegacyUI then
            local raisedR, raisedG, raisedB = self:Hex("raised")
            local lineR, lineG, lineB, lineA = self:Hex("line")
            local mutedR, mutedG, mutedB = self:Hex("muted")
            local brandR, brandG, brandB = self:Hex("brand")
            if tabBtn.SetBackdropColor then
                tabBtn:SetBackdropColor(isActive and raisedR or 0, isActive and raisedG or 0, isActive and raisedB or 0, isActive and 0.85 or 0)
            end
            if tabBtn.SetBackdropBorderColor then
                tabBtn:SetBackdropBorderColor(isActive and lineR or 0, isActive and lineG or 0, isActive and lineB or 0, isActive and lineA or 0)
            end
            tabBtn.label:SetTextColor(isActive and brandR or mutedR, isActive and brandG or mutedG, isActive and brandB or mutedB)
        else
            if isActive then
                tabBtn.label:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
                local hov = t.rowHover or { 0.949, 0.788, 0.298, 0.25 }
                if tabBtn.SetBackdropColor then
                    tabBtn:SetBackdropColor(hov[1], hov[2], hov[3], 0.22)
                end
                if tabBtn.SetBackdropBorderColor then
                    tabBtn:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 0.9)
                end
            else
                local m = t.muted or t.dim or { 0.663, 0.627, 0.549 }
                tabBtn.label:SetTextColor(m[1], m[2], m[3])
                if tabBtn.SetBackdropColor then
                    tabBtn:SetBackdropColor(0, 0, 0, 0)
                end
                if tabBtn.SetBackdropBorderColor then
                    tabBtn:SetBackdropBorderColor(0, 0, 0, 0)
                end
            end
        end
    end

    if mainFrame.mailActionBar then
        if activeTab == 7 then
            mainFrame.mailActionBar:Show()
            local isCons = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.autoMailConsumables
            if mainFrame.mailActionBar.btnConsumables and mainFrame.mailActionBar.btnConsumables.label then
                mainFrame.mailActionBar.btnConsumables.label:SetText(isCons and "Auto-Mail Consumables: ON" or "Auto-Mail Consumables: OFF")
            end
        else
            mainFrame.mailActionBar:Hide()
        end
    end

    if mainFrame.wellRestedBadge then
        if activeTab == 3 and not self:IsRetail() then
            local r = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
            local lpData = self:CalculateAccountLP()
            local lpVal = (lpData and lpData.effectiveLP) or 0
            local badgeStr = string.format("Well Rested: Rank %d (+%d%%) · %.1f LP", r, r * 4, lpVal)
            mainFrame.wellRestedBadge.text:SetText(badgeStr)
            mainFrame.wellRestedBadge:SetWidth(math.max(160, #badgeStr * 7 + 20))
            mainFrame.wellRestedBadge:Show()
        else
            mainFrame.wellRestedBadge:Hide()
        end
    end

    if mainFrame.headerFrame then
        if activeTab == 1 then
            mainFrame.headerFrame:Hide()
        else
            mainFrame.headerFrame:Show()
        end
    end

    -- Update dynamic ASCII border lines based on active frame width
    self:UpdateBorders()
    if mainFrame.btnCompact then
        mainFrame.btnCompact.label:SetText(isComp and "[ COMPACT* ]" or "[ COMPACT ]")
    end
    if mainFrame.btnPerk then
        if self:IsRetail() then
            mainFrame.btnPerk:Hide()
        else
            mainFrame.btnPerk:Show()
            if mainFrame.btnPerk.label then
                local r = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
                local lpData = self:CalculateAccountLP()
                local lpVal = (lpData and lpData.effectiveLP) or 0
                mainFrame.btnPerk.label:SetText(string.format("[ WELL RESTED: R%d · %.1f LP ]", r, lpVal))
                mainFrame.btnPerk:SetWidth(170)
            end
        end
    end

    -- ------------------------------------------------------------------------
    -- Level 1: Recommended Next Action Hero Card / Mail Dispatch Hero Card
    -- ------------------------------------------------------------------------
    local nextList = self:GetNextAltsPriority()
    self._cachedPriorityList = nextList
    local topNext = nextList and nextList[1]

    if not mainFrame.isLegacyUI then
        if activeTab == 1 then
            if mainFrame.nextBanner then
                mainFrame.nextBanner:Show()
                self:UpdatePlayNextBanner()
            end
            if mainFrame.filterBar then
                mainFrame.filterBar:ClearAllPoints()
                mainFrame.filterBar:SetPoint("TOPLEFT", mainFrame.nextBanner, "BOTTOMLEFT", 0, -8)
                mainFrame.filterBar:SetPoint("TOPRIGHT", mainFrame.nextBanner, "BOTTOMRIGHT", 0, -8)
            end
        else
            if mainFrame.nextBanner then
                mainFrame.nextBanner:Hide()
            end
            if mainFrame.filterBar then
                mainFrame.filterBar:ClearAllPoints()
                mainFrame.filterBar:SetPoint("TOPLEFT", mainFrame.mainCol, "TOPLEFT", 0, 0)
                mainFrame.filterBar:SetPoint("TOPRIGHT", mainFrame.mainCol, "TOPRIGHT", 0, 0)
            end
        end
    else
        if activeTab == 7 then
        mainFrame.recChar = nil
        if mainFrame.recCohortBadge then mainFrame.recCohortBadge:Hide() end
        if mainFrame.recBadge then
            mainFrame.recBadge:SetText("MAIL DISPATCH & SUPPLY CHAIN")
        end
        local mailSummary = self._cachedMailReadySummary or self:GetMailReadySummary()
        if mailSummary.totalPackages > 0 then
            if mainFrame.recHeroTitle then
                mainFrame.recHeroTitle:SetText(string.format("%d Pending In-Bag Packages Ready (%d items)", mailSummary.totalPackages, mailSummary.totalItems))
            end
            if mainFrame.recProfLine then
                mainFrame.recProfLine:SetText("Materials & BoE goods found in bags destined for specialized crafters & mules.")
                mainFrame.recProfLine:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
            end
            if mainFrame.recRestLine then
                mainFrame.recRestLine:SetText(string.format("Send to: %d recipients ready for dispatch", mailSummary.totalPackages))
                mainFrame.recRestLine:SetTextColor(t.ready[1], t.ready[2], t.ready[3])
            end
            if mainFrame.recReasonLine then
                mainFrame.recReasonLine:SetText("Click an alt below to configure routing, or click [ VIEW CHAT ] for bag mail breakdown.")
                mainFrame.recReasonLine:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
            end
        else
            if mainFrame.recHeroTitle then
                mainFrame.recHeroTitle:SetText("All Bag Materials Dispatched")
            end
            if mainFrame.recProfLine then
                mainFrame.recProfLine:SetText("No pending trade goods or profession materials in your bags need mailing.")
                mainFrame.recProfLine:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
            end
            if mainFrame.recRestLine then
                mainFrame.recRestLine:SetText("Supply routes active across all tracked characters.")
                mainFrame.recRestLine:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
            end
            if mainFrame.recReasonLine then
                mainFrame.recReasonLine:SetText("Configure auto-suggested or custom material streams for any character below.")
                mainFrame.recReasonLine:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
            end
        end
        if mainFrame.recBtnDossier then mainFrame.recBtnDossier:Hide() end
        if mainFrame.recBtnSetup then
            mainFrame.recBtnSetup:Show()
            if mainFrame.recBtnSetup.label then
                mainFrame.recBtnSetup.label:SetText("[ VIEW CHAT ]")
            end
            mainFrame.recBtnSetup:SetScript("OnClick", function()
                CLIAlts:PrintMailRouting()
            end)
        end
    else
        if mainFrame.recBadge then
            mainFrame.recBadge:SetText("RECOMMENDED NEXT")
        end
        if mainFrame.recBtnSetup and mainFrame.recBtnSetup.label then
            mainFrame.recBtnSetup.label:SetText("[ GUIDE ]")
        end
        if topNext then
            local tc = topNext.char
            mainFrame.recChar = tc
            local cName = self:ColorizePlayerName(tc.fullName or tc.name, tc.classFile)
            local isCur = (tc.fullName and tc.fullName == self.curPlayerFullName) or (tc.name and tc.name == self.curPlayerName)
            local curPrefix = isCur and string.format("|cff%s*|r ", t.accentHex or "57d6e8") or ""
            local tgtLvl = topNext.targetLevel or ((tc.tier == "CORE" and 35) or (tc.tier == "RESERVE" and 25) or 60)
            local lvlStr = string.format("Level %d/%d %s", tc.level or 1, tgtLvl, tc.class or "")

            if mainFrame.recCohortBadge then
                mainFrame.recCohortBadge:Show()
                if mainFrame.recCohortBadgeText then
                    if tc.tier == "CORE" then
                        mainFrame.recCohortBadgeText:SetText("|cffffb547CORE|r")
                    elseif tc.tier == "RESERVE" then
                        mainFrame.recCohortBadgeText:SetText("|cff57d6e8ALT|r")
                    elseif tc.tier == "BANK" then
                        mainFrame.recCohortBadgeText:SetText("|cffa9a08cBANK|r")
                    else
                        mainFrame.recCohortBadgeText:SetText("|cffffffffALT|r")
                    end
                end
            end

            local profParts = {}
            if tc.supply_role and tc.supply_role ~= "" then
                table.insert(profParts, tc.supply_role)
            end
            if tc.professions and tc.professions.primary and #tc.professions.primary > 0 then
                for _, p in ipairs(tc.professions.primary) do
                    table.insert(profParts, string.format("%s %d", p.name or "", p.rank or 0))
                end
            end
            local profSummary = (#profParts > 0) and table.concat(profParts, " · ") or "No primary professions tracked"

            local restStr
            if topNext.isCapped then
                restStr = string.format("%d%% Capped", topNext.maxPercent or 150)
                if topNext.wastedXP and topNext.wastedXP > 0 then
                    restStr = restStr .. string.format(" (+%s XP waste)", self:FormatNumber(topNext.wastedXP))
                end
            else
                restStr = string.format("%d%% Rested (~%s XP)", topNext.percent or 0, self:FormatNumber(topNext.usableXP or 0))
            end

            local whyText
            if topNext.isCapped and topNext.wastedXP and topNext.wastedXP > 0 then
                whyText = string.format("Rested cap reached with XP overflow (+%s wasted) - play now to prevent XP waste.", self:FormatNumber(topNext.wastedXP))
            elseif topNext.isCapped then
                whyText = string.format("At %d%% Rested cap with double XP active - optimal time to level.", topNext.maxPercent or 150)
            elseif tc.tier == "CORE" then
                whyText = string.format("Core cohort priority with largest available rested pool (~%s XP).", self:FormatNumber(topNext.usableXP or 0))
            else
                whyText = string.format("Highest available rested XP pool (~%s XP) ready for progression.", self:FormatNumber(topNext.usableXP or 0))
            end

            if mainFrame.recHeroTitle then
                mainFrame.recHeroTitle:SetText(string.format("%s%s · %s", curPrefix, cName, lvlStr))
            end
            if mainFrame.recProfLine then
                mainFrame.recProfLine:SetText(profSummary)
                mainFrame.recProfLine:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
            end
            if mainFrame.recRestLine then
                mainFrame.recRestLine:SetText(string.format("%s · Rested XP opportunity", restStr))
                mainFrame.recRestLine:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
            end
            if mainFrame.recReasonLine then
                mainFrame.recReasonLine:SetText(whyText)
                mainFrame.recReasonLine:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
            end
            if mainFrame.recBtnDossier then
                mainFrame.recBtnDossier:Show()
                mainFrame.recBtnDossier:SetScript("OnClick", function()
                    CLIAlts:ShowDossierPopup(tc)
                end)
            end
            if mainFrame.recBtnSetup then mainFrame.recBtnSetup:Hide() end
        else
            mainFrame.recChar = nil
            if mainFrame.recCohortBadge then mainFrame.recCohortBadge:Hide() end
            if mainFrame.recHeroTitle then
                mainFrame.recHeroTitle:SetText("All characters up to date")
            end
            if mainFrame.recProfLine then
                mainFrame.recProfLine:SetText("Target level reached for all active cohorts.")
                mainFrame.recProfLine:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
            end
            if mainFrame.recRestLine then
                mainFrame.recRestLine:SetText("")
            end
            if mainFrame.recReasonLine then
                mainFrame.recReasonLine:SetText("Setup: Assign Core (L35) or Alt (L25) cohorts below to activate recommendations.")
                mainFrame.recReasonLine:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
            end
            if mainFrame.recBtnDossier then mainFrame.recBtnDossier:Hide() end
            if mainFrame.recBtnSetup then
                mainFrame.recBtnSetup:Show()
                mainFrame.recBtnSetup:SetScript("OnClick", function()
                    CLIAlts:ShowHelpPopup()
                end)
            end
        end
    end
    end

    -- ------------------------------------------------------------------------
    -- Level 2: 3 Modern KPI Metric Cards (RESTED | PROFESSIONS | GOLD)
    -- ------------------------------------------------------------------------
    local metrics = self:GetRosterSummaryMetrics()
    local charList = self:GetCharactersList()

    if mainFrame.metaText then
        local realmName = (GetRealmName and GetRealmName()) or "Forever"
        mainFrame.metaText:SetText(string.format("%d CHARACTERS · RESTED RECOVERY ACTIVE · REALM: %s", metrics.totalAlts or #charList, realmName:upper()))
        mainFrame.metaText:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
    end

    if mainFrame.kpiCards then
        if activeTab == 7 then
            local mailSummary = self._cachedMailReadySummary or self:GetMailReadySummary()
            local autoCount = 0
            local overrideCount = 0
            for _, c in ipairs(charList) do
                local _, isOv = self:GetCharacterEffectiveSupplyRole(c)
                if isOv then
                    overrideCount = overrideCount + 1
                else
                    autoCount = autoCount + 1
                end
            end
            if mainFrame.kpiCards.rested then
                if mainFrame.kpiCards.rested.title then mainFrame.kpiCards.rested.title:SetText("ROUTED ALTS") end
                if mainFrame.kpiCards.rested.val then
                    mainFrame.kpiCards.rested.val:SetText(tostring(#charList))
                    mainFrame.kpiCards.rested.val:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
                end
                if mainFrame.kpiCards.rested.sub then mainFrame.kpiCards.rested.sub:SetText("Supply network alts") end
            end
            if mainFrame.kpiCards.profs then
                if mainFrame.kpiCards.profs.title then mainFrame.kpiCards.profs.title:SetText("ROUTING MODES") end
                if mainFrame.kpiCards.profs.val then
                    mainFrame.kpiCards.profs.val:SetText(string.format("%d OVR · %d AUTO", overrideCount, autoCount))
                    mainFrame.kpiCards.profs.val:SetTextColor(t.accent[1], t.accent[2], t.accent[3])
                end
                if mainFrame.kpiCards.profs.sub then mainFrame.kpiCards.profs.sub:SetText("Custom overrides vs auto") end
            end
            if mainFrame.kpiCards.gold then
                if mainFrame.kpiCards.gold.title then mainFrame.kpiCards.gold.title:SetText("BAG PACKAGES") end
                if mainFrame.kpiCards.gold.val then
                    mainFrame.kpiCards.gold.val:SetText(tostring(mailSummary.totalPackages or 0))
                    mainFrame.kpiCards.gold.val:SetTextColor(t.ready[1], t.ready[2], t.ready[3])
                end
                if mainFrame.kpiCards.gold.sub then mainFrame.kpiCards.gold.sub:SetText(string.format("%d items ready", mailSummary.totalItems or 0)) end
            end
        else
            if mainFrame.kpiCards.rested and mainFrame.kpiCards.rested.title then
                mainFrame.kpiCards.rested.title:SetText("RESTED")
                mainFrame.kpiCards.rested.sub:SetText("Characters")
            end
            if mainFrame.kpiCards.profs and mainFrame.kpiCards.profs.title then
                mainFrame.kpiCards.profs.title:SetText("PROFESSIONS")
                mainFrame.kpiCards.profs.sub:SetText("Tracked roles")
            end
            if mainFrame.kpiCards.gold and mainFrame.kpiCards.gold.title then
                mainFrame.kpiCards.gold.title:SetText("GOLD")
                mainFrame.kpiCards.gold.sub:SetText("Combined wealth")
            end

            -- 1. RESTED characters count
            local restedCount = 0
            for _, c in ipairs(charList) do
                local r = self:GetRestedData(c)
                if r and not r.isMaxLevel and (r.currentRested or 0) > 0 then
                    restedCount = restedCount + 1
                end
            end
            if mainFrame.kpiCards.rested and mainFrame.kpiCards.rested.val then
                mainFrame.kpiCards.rested.val:SetText(tostring(restedCount))
                mainFrame.kpiCards.rested.val:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
            end

            -- 2. PROFESSIONS / Tracked roles
            local profCount = 0
            for _, c in ipairs(charList) do
                if (c.professions and c.professions.primary and #c.professions.primary > 0) or (c.supply_role and c.supply_role ~= "") then
                    profCount = profCount + 1
                end
            end
            if mainFrame.kpiCards.profs and mainFrame.kpiCards.profs.val then
                mainFrame.kpiCards.profs.val:SetText(tostring(profCount))
                mainFrame.kpiCards.profs.val:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
            end

            -- 3. GOLD / Combined wealth
            if mainFrame.kpiCards.gold and mainFrame.kpiCards.gold.val then
                local g = math.floor((metrics.totalGold or 0) / 10000)
                local s = math.floor(((metrics.totalGold or 0) % 10000) / 100)
                local goldStr = (g > 0) and string.format("%sg", self:FormatNumber(g)) or string.format("%ds", s)
                mainFrame.kpiCards.gold.val:SetText(goldStr)
                mainFrame.kpiCards.gold.val:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
            end
        end
    end

    -- Pinned Sidebar Account Wealth Dynamic Update
    if mainFrame.wealthWidget then
        local copper = metrics.totalGold or 0
        local g = math.floor(copper / 10000)
        local s = math.floor((copper % 10000) / 100)
        local c = math.floor(copper % 100)

        local formattedWealth
        if g > 0 then
            if g >= 10000 then
                formattedWealth = string.format("|cffffd700%sg|r |cffc7c7cf%ds|r", self:FormatNumber(g), s)
            else
                formattedWealth = string.format("|cffffd700%sg|r |cffc7c7cf%ds|r |cffeda55f%dc|r", self:FormatNumber(g), s, c)
            end
        elseif s > 0 then
            formattedWealth = string.format("|cffc7c7cf%ds|r |cffeda55f%dc|r", s, c)
        else
            formattedWealth = string.format("|cffeda55f%dc|r", c)
        end
        if mainFrame.wealthWidget.total then
            mainFrame.wealthWidget.total:SetText(formattedWealth)
        end

        local d1, d7, _, hasHistory, baselineDays = self:GetGoldHistoryDeltas()
        local deltaText
        local readyC = t.ready or { 0.33, 0.89, 0.60 }
        local blockedC = t.blocked or { 1.0, 0.27, 0.27 }
        local dimC = t.dim or t.muted or { 0.663, 0.627, 0.549 }
        local deltaR, deltaG, deltaB = dimC[1], dimC[2], dimC[3]

        if hasHistory then
            local dVal = (baselineDays and baselineDays >= 7) and d7 or ((baselineDays and baselineDays >= 1) and d1 or d7)
            local periodStr = (baselineDays and baselineDays >= 7) and "this week" or "recently"
            if dVal > 0 then
                deltaText = string.format("+%sg %s", self:FormatNumber(dVal), periodStr)
                deltaR, deltaG, deltaB = readyC[1], readyC[2], readyC[3]
            elseif dVal < 0 then
                deltaText = string.format("-%sg %s", self:FormatNumber(math.abs(dVal)), periodStr)
                deltaR, deltaG, deltaB = blockedC[1], blockedC[2], blockedC[3]
            else
                if d1 > 0 then
                    deltaText = string.format("+%sg today", self:FormatNumber(d1))
                    deltaR, deltaG, deltaB = readyC[1], readyC[2], readyC[3]
                elseif d1 < 0 then
                    deltaText = string.format("-%sg today", self:FormatNumber(math.abs(d1)))
                    deltaR, deltaG, deltaB = blockedC[1], blockedC[2], blockedC[3]
                else
                    deltaText = string.format("±0g %s", periodStr)
                end
            end
        else
            local sessInit = self.sessionInitialCopper or copper
            local sessDiff = copper - sessInit
            local sessG = math.floor(math.abs(sessDiff) / 10000)
            local sessS = math.floor((math.abs(sessDiff) % 10000) / 100)
            if sessDiff > 0 then
                deltaR, deltaG, deltaB = readyC[1], readyC[2], readyC[3]
                if sessG > 0 then
                    deltaText = string.format("+%sg today", self:FormatNumber(sessG))
                else
                    deltaText = string.format("+%ds today", sessS > 0 and sessS or 1)
                end
            elseif sessDiff < 0 then
                deltaR, deltaG, deltaB = blockedC[1], blockedC[2], blockedC[3]
                if sessG > 0 then
                    deltaText = string.format("-%sg today", self:FormatNumber(sessG))
                else
                    deltaText = string.format("-%ds today", sessS > 0 and sessS or 1)
                end
            else
                deltaText = "No change today"
            end
        end

        if mainFrame.wealthWidget.delta then
            mainFrame.wealthWidget.delta:SetText(deltaText)
            mainFrame.wealthWidget.delta:SetTextColor(deltaR, deltaG, deltaB)
        end
    end

    -- Render Table Header Cells & Clickable Header Buttons
    local cols = self:GetColumns(activeTab)
    local xOffset = 16
    local sortBy = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.sortBy
    local sortAsc = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.sortAsc
    local isMod = (mainFrame and not mainFrame.isLegacyUI) and "mod" or "leg"
    local headerLayoutKey = (activeTab or 1) .. ":" .. (isComp and "1" or "0") .. ":" .. isMod .. ":v7"
    local relayoutHeaders = not (mainFrame.headerFrame and mainFrame.headerFrame.lastLayoutKey) or (mainFrame.headerFrame.lastLayoutKey ~= headerLayoutKey)
    if relayoutHeaders and mainFrame.headerFrame then
        mainFrame.headerFrame.lastLayoutKey = headerLayoutKey
    end

    for idx = 1, 8 do
        local hCell = mainFrame.headerCells and mainFrame.headerCells[idx]
        local btn = headerButtons[idx]
        local col = cols[idx]

        if col then
            local colW = (mainFrame and not mainFrame.isLegacyUI and col.mpw) or (isComp and (col.cpw or col.pw)) or col.pw
            local padR = (mainFrame and not mainFrame.isLegacyUI and col.mpadRight) or (isComp and (col.cpadRight or col.padRight or 0)) or (col.padRight or 0)
            local cellW = math.max(1, colW - padR)
            if hCell then
                if relayoutHeaders then
                    hCell:ClearAllPoints()
                    hCell:SetPoint("LEFT", mainFrame.headerFrame, "LEFT", xOffset, 0)
                    hCell:SetWidth(cellW)
                    hCell:SetJustifyH(col.align or "LEFT")
                end

                local title = col.title
                if col.sort and col.sort == sortBy then
                    local arrow = sortAsc and " ^" or " v"
                    if col.align == "RIGHT" then
                        title = (sortAsc and "^ " or "v ") .. title
                    else
                        title = title .. arrow
                    end
                    hCell:SetText(string.format("|cff%s%s|r", t.highlightHex, title))
                else
                    hCell:SetText(string.format("|cff%s%s|r", t.primaryHex, title))
                end
                hCell:Show()
            end

            if btn and col.sort then
                if relayoutHeaders then
                    btn:ClearAllPoints()
                    btn:SetPoint("LEFT", mainFrame.headerFrame, "LEFT", xOffset, 0)
                    btn:SetSize(colW, 18)
                end
                btn.sortKey = col.sort
                btn.colTitle = col.title
                btn:Show()
            elseif btn then
                btn:Hide()
            end

            xOffset = xOffset + colW
        else
            if hCell then
                hCell:SetText("")
                hCell:Hide()
            end
            if btn then
                btn:Hide()
            end
        end
    end

    -- Retrieve Sorted Characters (with view-based defaults)
    local activeSortBy = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.sortBy
    local activeSortAsc = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.sortAsc
    if not activeSortBy then
        if activeTab == 2 then
            activeSortBy = "rotation"
            activeSortAsc = false
        elseif activeTab == 5 then
            activeSortBy = "gold"
            activeSortAsc = false
        elseif activeTab == 6 then
            activeSortBy = "cooldown"
            activeSortAsc = true
        elseif activeTab == 7 then
            activeSortBy = "name"
            activeSortAsc = true
        end
    end
    local chars = self:GetCharactersList(activeSortBy, activeSortAsc, self.activeFilter)
    local numRows = (self.GetRowsPerPage and self:GetRowsPerPage()) or ROWS_COUNT
    totalPages = math.max(1, math.ceil(#chars / numRows))
    if currentPage > totalPages then currentPage = totalPages end
    if currentPage < 1 then currentPage = 1 end

    local filterSuffix = self.activeFilter and " FILTERED" or ""
    if mainFrame.btnPrev and mainFrame.btnNext and mainFrame.pageText then
        if totalPages > 1 then
            mainFrame.btnPrev:Show()
            mainFrame.btnNext:Show()
            mainFrame.btnPrev:SetEnabled(currentPage > 1)
            mainFrame.btnNext:SetEnabled(currentPage < totalPages)
            if mainFrame.btnPrev.label then
                if currentPage > 1 then
                    mainFrame.btnPrev.label:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
                else
                    mainFrame.btnPrev.label:SetTextColor(t.dim[1], t.dim[2], t.dim[3], 0.5)
                end
            end
            if mainFrame.btnNext.label then
                if currentPage < totalPages then
                    mainFrame.btnNext.label:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
                else
                    mainFrame.btnNext.label:SetTextColor(t.dim[1], t.dim[2], t.dim[3], 0.5)
                end
            end
            mainFrame.pageText:ClearAllPoints()
            mainFrame.pageText:SetPoint("LEFT", mainFrame.btnNext, "RIGHT", 10, 0)
            mainFrame.pageText:SetText(string.format("PAGE %d OF %d (%d ALTS%s)", currentPage, totalPages, #chars, filterSuffix))
        else
            mainFrame.btnPrev:Hide()
            mainFrame.btnNext:Hide()
            mainFrame.pageText:ClearAllPoints()
            mainFrame.pageText:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 18, 12)
            mainFrame.pageText:SetText(string.format("TRACKED: %d ALTS%s", #chars, filterSuffix))
        end
    end

    if mainFrame.statusTip then
        mainFrame.statusTip:SetText("|cff888888Select a character for details · Right-click for management|r")
    end

    if mainFrame.sidebarNavButtons then
        local badgeCounts = self:GetSidebarBadgeCounts()
        for _, navBtn in ipairs(mainFrame.sidebarNavButtons) do
            if navBtn.badge then
                if navBtn.tabId == 1 then
                    navBtn.badge.text:SetText(tostring(badgeCounts.overview or #chars))
                    navBtn.badge:Show()
                elseif navBtn.tabId == 3 then
                    local count = badgeCounts.rested or 0
                    if count > 0 then
                        navBtn.badge.text:SetText(tostring(count))
                        navBtn.badge:Show()
                    else
                        navBtn.badge:Hide()
                    end
                elseif navBtn.tabId == 6 then
                    local count = badgeCounts.cooldowns or 0
                    if count > 0 then
                        navBtn.badge.text:SetText(tostring(count))
                        navBtn.badge:Show()
                    else
                        navBtn.badge:Hide()
                    end
                elseif navBtn.tabId == 7 then
                    local count = badgeCounts.mail or 0
                    if count > 0 then
                        navBtn.badge.text:SetText(tostring(count))
                        navBtn.badge:Show()
                    else
                        navBtn.badge:Hide()
                    end
                end
            end
        end
    end

    if self.UpdateFilterChips then
        self:UpdateFilterChips()
    end

    -- Render Rows (Overview Phase 2 Component or Multi-Column Rows across Tabs)
    local raisedR, raisedG, raisedB = self:Hex("raised")
    local lineR, lineG, lineB = self:Hex("line")
    local panelR, panelG, panelB = self:Hex("panel")
    local brandR, brandG, brandB = self:Hex("brand")
    local warnR, warnG, warnB = self:Hex("warn")
    local fillR, fillG, fillB = self:Hex("fill")
    local textR, textG, textB = self:Hex("text")
    local mutedR, mutedG, mutedB = self:Hex("muted")

    for rowIndex = 1, #rowFrames do
        local row = rowFrames[rowIndex]
        if rowIndex <= numRows then
            local charIndex = (currentPage - 1) * numRows + rowIndex
            local char = chars[charIndex]

            if char then
                row.charData = char
                local isSelected = (CLIAlts.selectedCharKey and (char.fullName == CLIAlts.selectedCharKey or char.name == CLIAlts.selectedCharKey))

                if not mainFrame.isLegacyUI then
                    -- Modern UI row styling
                    if isSelected then
                        if row.SetBackdropColor then row:SetBackdropColor(raisedR, raisedG, raisedB, 0.95) end
                        if row.SetBackdropBorderColor then row:SetBackdropBorderColor(brandR, brandG, brandB, 1.0) end
                    else
                        local rowBgR = (rowIndex % 2 == 0) and raisedR or panelR
                        local rowBgG = (rowIndex % 2 == 0) and raisedG or panelG
                        local rowBgB = (rowIndex % 2 == 0) and raisedB or panelB
                        if row.SetBackdropColor then row:SetBackdropColor(rowBgR, rowBgG, rowBgB, 0.65) end
                        if row.SetBackdropBorderColor then row:SetBackdropBorderColor(lineR, lineG, lineB, 0.35) end
                    end

                    if activeTab == 1 then
                        -- --------------------------------------------------------
                        -- Tab 1 (Overview): Phase 2 Modern Row Component
                        -- --------------------------------------------------------
                        local classFile = char.classFile or "WARRIOR"
                        local cr, cg, cb = self:GetClassColor(classFile)

                        -- 1. 34px Class-Coloured Ring with Alt Initial
                        if row.classRing then
                            if row.classRing.SetBackdropBorderColor then
                                row.classRing:SetBackdropBorderColor(cr, cg, cb, 0.95)
                            end
                            if row.classRing.SetBackdropColor then
                                row.classRing:SetBackdropColor(cr * 0.15, cg * 0.15, cb * 0.15, 0.70)
                            end
                            if row.classRingInitial then
                                local initial = self:GetFirstLetter(char.name or "?")
                                row.classRingInitial:SetText(initial)
                                row.classRingInitial:SetTextColor(cr, cg, cb)
                            end
                            row.classRing:Show()
                        end

                        -- 2. Name Line
                        if row.nameLine then
                            row.nameLine:SetText(char.name or "Unknown")
                            row.nameLine:SetTextColor(cr, cg, cb)
                            row.nameLine:Show()
                        end

                        -- 3. Subline (level race class · faction)
                        if row.subLine then
                            local race = (char.race and char.race ~= "" and char.race ~= "Unknown") and char.race or (char.raceFile == "Scourge" and "Undead") or char.raceFile or "Unknown"
                            local faction = char.faction or "Neutral"
                            local class = char.class or char.className or classFile
                            row.subLine:SetText(string.format("%d %s %s · %s", char.level or 1, race, class, faction))
                            row.subLine:SetTextColor(mutedR, mutedG, mutedB)
                            row.subLine:Show()
                        end

                        -- 4. Level Progress Bar & Label (XP gained out of required for next level)
                        local xpData = self:GetLevelProgressData(char)
                        if xpData and not xpData.isMaxLevel then
                            local ratio = xpData.ratio or 0
                            local maxBarW = (row.restBarBg and row.restBarBg.GetWidth and row.restBarBg:GetWidth()) or 180
                            if not maxBarW or maxBarW <= 0 then maxBarW = 180 end
                            local barW = math.floor(maxBarW * ratio)
                            if row.restBarFill then
                                row.restBarFill:SetWidth(math.max(1, barW))
                                row.restBarFill:SetVertexColor(brandR, brandG, brandB, 1.0)
                            end
                            if row.restBarBg then
                                row.restBarBg:Show()
                            end

                            if row.restLabel then
                                if xpData.maxXP and xpData.maxXP > 0 then
                                    row.restLabel:SetText(string.format("%d%% XP (%s / %s)", xpData.percent, self:FormatNumber(xpData.curXP), self:FormatNumber(xpData.maxXP)))
                                else
                                    row.restLabel:SetText(string.format("%d%% XP", xpData.percent))
                                end
                                row.restLabel:SetTextColor(textR, textG, textB)
                                row.restLabel:Show()
                            end
                        else
                            if row.restLabel then
                                row.restLabel:SetText("Max Level")
                                row.restLabel:SetTextColor(mutedR, mutedG, mutedB)
                                row.restLabel:Show()
                            end
                            if row.restBarBg then
                                row.restBarBg:Hide()
                            end
                        end

                        -- 5. Status Pill
                        local statusText, statusStyle = self:FmtStatus(char, t)
                        if row.statusPill and row.statusPillText then
                            row.statusPillText:SetText(statusText)
                            if statusStyle == "warn_fill" or statusStyle == "warn" then
                                if row.statusPill.SetBackdropColor then row.statusPill:SetBackdropColor(warnR, warnG, warnB, 1.0) end
                                if row.statusPill.SetBackdropBorderColor then row.statusPill:SetBackdropBorderColor(warnR, warnG, warnB, 1.0) end
                                row.statusPillText:SetTextColor(0.05, 0.04, 0.02)
                            elseif statusStyle == "info_outline" or statusStyle == "info" then
                                if row.statusPill.SetBackdropColor then row.statusPill:SetBackdropColor(fillR, fillG, fillB, 0.12) end
                                if row.statusPill.SetBackdropBorderColor then row.statusPill:SetBackdropBorderColor(fillR, fillG, fillB, 0.85) end
                                row.statusPillText:SetTextColor(fillR, fillG, fillB)
                            elseif statusStyle == "dashed_muted" or statusStyle == "dashed" then
                                if row.statusPill.SetBackdropColor then row.statusPill:SetBackdropColor(panelR, panelG, panelB, 0.35) end
                                if row.statusPill.SetBackdropBorderColor then row.statusPill:SetBackdropBorderColor(lineR, lineG, lineB, 0.50) end
                                row.statusPillText:SetTextColor(mutedR, mutedG, mutedB)
                            else -- muted_outline
                                if row.statusPill.SetBackdropColor then row.statusPill:SetBackdropColor(panelR, panelG, panelB, 0.50) end
                                if row.statusPill.SetBackdropBorderColor then row.statusPill:SetBackdropBorderColor(lineR, lineG, lineB, 0.75) end
                                row.statusPillText:SetTextColor(mutedR, mutedG, mutedB)
                            end
                            row.statusPill:Show()
                        end

                        -- 6. Right-Aligned Gold Value
                        if row.goldText then
                            local copper = char.money or 0
                            local gold = math.floor(copper / 10000)
                            row.goldText:SetText(self:FormatNumber(gold) .. "g")
                            row.goldText:SetTextColor(textR, textG, textB)
                            row.goldText:Show()
                        end

                        -- Hide multi-column cells on Tab 1
                        for idx = 1, 8 do
                            local cell = row.cells and row.cells[idx]
                            if cell then
                                cell:SetText("")
                                cell:Hide()
                            end
                        end
                    else
                        -- --------------------------------------------------------
                        -- Tabs 2 to 7: Multi-Column Cells
                        -- --------------------------------------------------------
                        if row.classRing then row.classRing:Hide() end
                        if row.nameLine then row.nameLine:Hide() end
                        if row.subLine then row.subLine:Hide() end
                        if row.restLabel then row.restLabel:Hide() end
                        if row.restBarBg then row.restBarBg:Hide() end
                        if row.statusPill then row.statusPill:Hide() end
                        if row.goldText then row.goldText:Hide() end

                        local isMod = (mainFrame and not mainFrame.isLegacyUI) and "mod" or "leg"
                        local rowLayoutKey = (activeTab or 1) .. ":" .. (isComp and "1" or "0") .. ":" .. isMod .. ":v7"
                        local relayoutRow = not row.lastLayoutKey or (row.lastLayoutKey ~= rowLayoutKey)
                        if relayoutRow then
                            row.lastLayoutKey = rowLayoutKey
                        end

                        local rowXOffset = 16
                        for idx = 1, 8 do
                            local cell = row.cells and row.cells[idx]
                            local col = cols[idx]
                            if cell then
                                if col then
                                    local colW = (mainFrame and not mainFrame.isLegacyUI and col.mpw) or (isComp and (col.cpw or col.pw)) or col.pw
                                    local padR = (mainFrame and not mainFrame.isLegacyUI and col.mpadRight) or (isComp and (col.cpadRight or col.padRight or 0)) or (col.padRight or 0)
                                    local cellW = math.max(1, colW - padR)
                                    if relayoutRow then
                                        cell:ClearAllPoints()
                                        cell:SetPoint("LEFT", row, "LEFT", rowXOffset, 0)
                                        cell:SetWidth(cellW)
                                        cell:SetJustifyH(col.align or "LEFT")
                                    end
                                    cell:SetText(col.fmt(char, t) or "")
                                    cell:Show()
                                    rowXOffset = rowXOffset + colW
                                else
                                    cell:SetText("")
                                    cell:Hide()
                                end
                            end
                        end
                    end
                else
                    -- Legacy UI row rendering
                    if isSelected then
                        local hov = t.rowHover or { 0.949, 0.788, 0.298, 0.25 }
                        if row.SetBackdropColor then row:SetBackdropColor(hov[1], hov[2], hov[3], 0.35) end
                        if row.SetBackdropBorderColor then row:SetBackdropBorderColor(t.highlight[1], t.highlight[2], t.highlight[3], 0.8) end
                        if row.borderL then row.borderL:SetText(string.format("|cff%s>|r", t.highlightHex or "ffd34e")) end
                    else
                        local rowBg = (rowIndex % 2 == 0) and (t.rowEven or { 0.098, 0.082, 0.047, 0.32 }) or (t.rowOdd or { 0.098, 0.082, 0.047, 0.12 })
                        if row.SetBackdropColor then row:SetBackdropColor(rowBg[1], rowBg[2], rowBg[3], rowBg[4]) end
                        if row.SetBackdropBorderColor then row:SetBackdropBorderColor(0, 0, 0, 0) end
                        if row.borderL then row.borderL:SetText("") end
                    end

                    if activeTab == 1 then
                        local coloredName = self:ColorizePlayerName(char.fullName or char.name, char.classFile)
                        local isCur = (char.fullName and char.fullName == self.curPlayerFullName) or (char.name and char.name == self.curPlayerName)
                        local curPrefix = isCur and string.format("|cff%s*|r ", t.accentHex or "57d6e8") or ""
                        if row.nameLine then
                            row.nameLine:SetText(curPrefix .. coloredName)
                            row.nameLine:Show()
                        end
                        if row.subLine then
                            local roleTag = (char.tier == "CORE" and string.format("|cff%sCORE|r", t.highlightHex or "ffd34e"))
                                or (char.tier == "RESERVE" and string.format("|cff%sALT|r", t.accentHex or "57d6e8"))
                                or (char.tier == "BANK" and string.format("|cff%sBANK|r", t.pendingHex or "ffb547"))
                                or string.format("|cff%sALT|r", t.mutedHex or "a9a08c")
                            local isTopNext = (topNext and topNext.char and ((topNext.char.fullName or topNext.char.name) == (char.fullName or char.name)))
                            if isTopNext then
                                roleTag = roleTag .. string.format(" · |cff%sNEXT|r", t.highlightHex or "ffd34e")
                            end
                            local statusDetail = ""
                            if char.supply_role and char.supply_role ~= "" then
                                statusDetail = " · " .. char.supply_role
                            elseif char.level and char.level >= self:GetMaxLevel() then
                                statusDetail = " · Target Level Reached"
                            elseif char.tier == "BANK" then
                                statusDetail = " · Storage Mule"
                            end
                            row.subLine:SetText(roleTag .. statusDetail)
                            row.subLine:Show()
                        end
                        if row.levelText then
                            row.levelText:SetText(string.format("|cffffffff%d|r", char.level or 1))
                            row.levelText:Show()
                        end
                        local rested = self:GetRestedData(char)
                        if rested and not rested.isMaxLevel then
                            local pct = rested.percent or 0
                            local maxPct = rested.maxPercent or 150
                            local est = rested.isEstimate and "~" or ""
                            if row.restPercentText then
                                row.restPercentText:SetText(string.format("|cff%s%s%d%%|r", t.highlightHex or "ffd34e", est, pct))
                                row.restPercentText:Show()
                            end
                            local ratio = math.min(1.0, math.max(0, pct / maxPct))
                            local maxBarW = isComp and 170 or 220
                            local barW = math.floor(maxBarW * ratio)
                            if row.barFill then
                                row.barFill:SetWidth(math.max(1, barW))
                                row.barFill:SetVertexColor(t.primary[1], t.primary[2], t.primary[3], 0.95)
                            end
                            if row.barBg then row.barBg:Show() end
                            if row.etaText then
                                if pct >= maxPct then
                                    row.etaText:SetText(string.format("|cff%sAt Cap|r", t.readyHex or "55e39a"))
                                else
                                    row.etaText:SetText(string.format("|cff%s%s|r", t.dimHex or "a9a08c", rested.timeLeftStr or "---"))
                                end
                                row.etaText:Show()
                            end
                        else
                            if row.restPercentText then
                                row.restPercentText:SetText(string.format("|cff%s---|r", t.dimHex or "a9a08c"))
                                row.restPercentText:Show()
                            end
                            if row.barBg then row.barBg:Hide() end
                            if row.etaText then
                                row.etaText:SetText(string.format("|cff%sMax Level|r", t.readyHex or "55e39a"))
                                row.etaText:Show()
                            end
                        end
                        for idx = 1, 8 do
                            if row.cells and row.cells[idx] then
                                row.cells[idx]:SetText("")
                                row.cells[idx]:Hide()
                            end
                        end
                    else
                        if row.nameLine then row.nameLine:Hide() end
                        if row.subLine then row.subLine:Hide() end
                        if row.levelText then row.levelText:Hide() end
                        if row.restPercentText then row.restPercentText:Hide() end
                        if row.barBg then row.barBg:Hide() end
                        if row.etaText then row.etaText:Hide() end

                        local rowXOffset = 16
                        for idx = 1, 8 do
                            local cell = row.cells and row.cells[idx]
                            local col = cols[idx]
                            if cell then
                                if col then
                                    local colW = (isComp and (col.cpw or col.pw)) or col.pw
                                    local padR = (isComp and (col.cpadRight or col.padRight or 0)) or (col.padRight or 0)
                                    local cellW = math.max(1, colW - padR)
                                    cell:ClearAllPoints()
                                    cell:SetPoint("LEFT", row, "LEFT", rowXOffset, 0)
                                    cell:SetWidth(cellW)
                                    cell:SetJustifyH(col.align or "LEFT")
                                    cell:SetText(col.fmt(char, t) or "")
                                    cell:Show()
                                    rowXOffset = rowXOffset + colW
                                else
                                    cell:SetText("")
                                    cell:Hide()
                                end
                            end
                        end
                    end
                end

                row:Show()
            else
                row.charData = nil
                if row.borderL then row.borderL:SetText("") end
                if row.classRing then row.classRing:Hide() end
                if row.nameLine then row.nameLine:Hide() end
                if row.subLine then row.subLine:Hide() end
                if row.restLabel then row.restLabel:Hide() end
                if row.restBarBg then row.restBarBg:Hide() end
                if row.statusPill then row.statusPill:Hide() end
                if row.goldText then row.goldText:Hide() end
                if row.levelText then row.levelText:Hide() end
                if row.restPercentText then row.restPercentText:Hide() end
                if row.barBg then row.barBg:Hide() end
                if row.etaText then row.etaText:Hide() end
                for idx = 1, 8 do
                    local cell = row.cells and row.cells[idx]
                    if cell then
                        cell:SetText("")
                        cell:Hide()
                    end
                end
                row:Hide()
            end
        else
            row.charData = nil
            row:Hide()
        end
    end
        if not mainFrame.isLegacyUI then
            self:UpdateDetailPanel()
        end
        self._cachedPriorityList = nil
        self._cachedMailReadySummary = nil
    end)
    self._cachedPriorityList = nil
    self._cachedMailReadySummary = nil
    if not ok then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff3333[CLIAlts]|r UI Render error: %s", tostring(err)))
        end
    end
end

-- ----------------------------------------------------------------------------
-- Theme Application
-- ----------------------------------------------------------------------------
function CLIAlts:ApplyTheme()
    if not mainFrame then return end
    local t = self:GetTheme()

    if not mainFrame.isLegacyUI then
        local bgR, bgG, bgB, bgA = self:Hex("bg")
        local lineR, lineG, lineB, lineA = self:Hex("line")
        local panelR, panelG, panelB, panelA = self:Hex("panel")
        local raisedR, raisedG, raisedB, raisedA = self:Hex("raised")
        local brandR, brandG, brandB = self:Hex("brand")
        local textR, textG, textB = self:Hex("text")
        local mutedR, mutedG, mutedB = self:Hex("muted")
        local fillR, fillG, fillB = self:Hex("fill")

        if mainFrame.SetBackdropColor then mainFrame:SetBackdropColor(bgR, bgG, bgB, bgA) end
        if mainFrame.SetBackdropBorderColor then mainFrame:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end

        if mainFrame.topBar then
            if mainFrame.topBar.SetBackdropColor then mainFrame.topBar:SetBackdropColor(panelR, panelG, panelB, panelA) end
            if mainFrame.topBar.SetBackdropBorderColor then mainFrame.topBar:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
        end
        if mainFrame.logoText then mainFrame.logoText:SetTextColor(brandR, brandG, brandB) end
        if mainFrame.searchBox then
            if mainFrame.searchBox.SetBackdropColor then mainFrame.searchBox:SetBackdropColor(raisedR, raisedG, raisedB, raisedA) end
            if mainFrame.searchBox.SetBackdropBorderColor then mainFrame.searchBox:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
            if mainFrame.searchBox.placeholder then mainFrame.searchBox.placeholder:SetTextColor(mutedR, mutedG, mutedB) end
            if mainFrame.searchBox.SetTextColor then mainFrame.searchBox:SetTextColor(textR, textG, textB) end
        end
        if mainFrame.sidebar then
            if mainFrame.sidebar.SetBackdropColor then mainFrame.sidebar:SetBackdropColor(panelR, panelG, panelB, panelA) end
            if mainFrame.sidebar.SetBackdropBorderColor then mainFrame.sidebar:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
        end
        if mainFrame.wealthWidget then
            if mainFrame.wealthWidget.title then mainFrame.wealthWidget.title:SetTextColor(mutedR, mutedG, mutedB) end
            if mainFrame.wealthWidget.total then mainFrame.wealthWidget.total:SetTextColor(textR, textG, textB) end
            if mainFrame.wealthWidget.delta then mainFrame.wealthWidget.delta:SetTextColor(fillR, fillG, fillB) end
        end
        if mainFrame.detailPanel then
            local dp = mainFrame.detailPanel
            if dp.SetBackdropColor then dp:SetBackdropColor(panelR, panelG, panelB, panelA) end
            if dp.SetBackdropBorderColor then dp:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
            local cards = { dp.restedCard, dp.infoCard, dp.profCard, dp.lockCard, dp.mailCard }
            for _, card in ipairs(cards) do
                if card then
                    if card.SetBackdropColor then card:SetBackdropColor(raisedR, raisedG, raisedB, 0.8) end
                    if card.SetBackdropBorderColor then card:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
                end
            end
            if dp.restedCard and dp.restedCard.barBg and dp.restedCard.barBg.SetBackdropColor then
                dp.restedCard.barBg:SetBackdropColor(lineR, lineG, lineB, 1.0)
            end
            for _, r in ipairs(rowFrames) do
                if r.restBarBg and r.restBarBg.SetBackdropColor then
                    r.restBarBg:SetBackdropColor(lineR, lineG, lineB, 1.0)
                end
            end
        end
        if mainFrame.cmdBar then
            if mainFrame.cmdBar.SetBackdropColor then mainFrame.cmdBar:SetBackdropColor(panelR, panelG, panelB, panelA) end
            if mainFrame.cmdBar.SetBackdropBorderColor then mainFrame.cmdBar:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
        end
        if mainFrame.promptBox then
            if mainFrame.promptBox.SetBackdropColor then mainFrame.promptBox:SetBackdropColor(raisedR, raisedG, raisedB, 0.75) end
            if mainFrame.promptBox.SetBackdropBorderColor then mainFrame.promptBox:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
            if mainFrame.promptBox.SetTextColor then mainFrame.promptBox:SetTextColor(textR, textG, textB) end
        end
        if mainFrame.cmdPromptIndicator then mainFrame.cmdPromptIndicator:SetTextColor(mutedR, mutedG, mutedB) end
        if mainFrame.legendText then mainFrame.legendText:SetTextColor(mutedR, mutedG, mutedB) end
    end

    if mainFrame.isLegacyUI then
        if mainFrame.SetBackdropColor then
            mainFrame:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], t.bg[4])
        end
        if mainFrame.SetBackdropBorderColor then
            mainFrame:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], t.border[4])
        end

        if mainFrame.topAscii then mainFrame.topAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
        if mainFrame.titleText then mainFrame.titleText:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3]) end
        if mainFrame.midAscii1 then mainFrame.midAscii1:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
        if mainFrame.recPanel then
            local pBg = t.panelBg or { 0.098, 0.082, 0.047, 0.90 }
            if mainFrame.recPanel.SetBackdropColor then
                mainFrame.recPanel:SetBackdropColor(pBg[1], pBg[2], pBg[3], 0.95)
            end
            if mainFrame.recPanel.SetBackdropBorderColor then
                mainFrame.recPanel:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 0.55)
            end
        end
        if mainFrame.recBadge then mainFrame.recBadge:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3]) end
        if mainFrame.recHeroTitle then mainFrame.recHeroTitle:SetTextColor(t.text[1], t.text[2], t.text[3]) end
        if mainFrame.recProfLine then mainFrame.recProfLine:SetTextColor(t.dim[1], t.dim[2], t.dim[3]) end
        if mainFrame.recRestLine then mainFrame.recRestLine:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3]) end
        if mainFrame.recReasonLine then mainFrame.recReasonLine:SetTextColor(t.dim[1], t.dim[2], t.dim[3]) end
        if mainFrame.subViewTitle then mainFrame.subViewTitle:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3]) end
        if mainFrame.subViewFilters then mainFrame.subViewFilters:SetTextColor(t.dim[1], t.dim[2], t.dim[3]) end
        if mainFrame.summaryBar and mainFrame.summaryBar.SetBackdropColor then
            local pBg = t.panelBg or { 0.098, 0.082, 0.047, 0.90 }
            mainFrame.summaryBar:SetBackdropColor(pBg[1], pBg[2], pBg[3], 0.70)
            if mainFrame.summaryBar.SetBackdropBorderColor then
                mainFrame.summaryBar:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 0.3)
            end
        end
        if mainFrame.summaryText then mainFrame.summaryText:SetTextColor(t.primary[1], t.primary[2], t.primary[3]) end
        if mainFrame.statusBarText and mainFrame.statusBarText ~= mainFrame.summaryText then
            mainFrame.statusBarText:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
        end
        if mainFrame.midAscii2 then mainFrame.midAscii2:SetText("") end
        if mainFrame.tableTopAscii then mainFrame.tableTopAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
    else
        -- Modern UI: Restyle recPanel, kpiCards, and subview texts using modern design tokens
        local panelR, panelG, panelB, panelA = self:Hex("panel")
        local lineR, lineG, lineB, lineA = self:Hex("line")
        local brandR, brandG, brandB = self:Hex("brand")
        local textR, textG, textB = self:Hex("text")
        local mutedR, mutedG, mutedB = self:Hex("muted")
        local warnR, warnG, warnB = self:Hex("warn")
        local readyR, readyG, readyB = self:Hex("ready")

        if mainFrame.recPanel then
            if mainFrame.recPanel.SetBackdropColor then mainFrame.recPanel:SetBackdropColor(panelR, panelG, panelB, panelA) end
            if mainFrame.recPanel.SetBackdropBorderColor then mainFrame.recPanel:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
        end
        if mainFrame.recBadge then mainFrame.recBadge:SetTextColor(brandR, brandG, brandB) end
        if mainFrame.recHeroTitle then mainFrame.recHeroTitle:SetTextColor(textR, textG, textB) end
        if mainFrame.recProfLine then mainFrame.recProfLine:SetTextColor(mutedR, mutedG, mutedB) end
        if mainFrame.recRestLine then mainFrame.recRestLine:SetTextColor(readyR, readyG, readyB) end
        if mainFrame.recReasonLine then mainFrame.recReasonLine:SetTextColor(warnR, warnG, warnB) end

        if mainFrame.subViewTitle then mainFrame.subViewTitle:SetTextColor(brandR, brandG, brandB) end
        if mainFrame.subViewFilters then mainFrame.subViewFilters:SetTextColor(mutedR, mutedG, mutedB) end

        if mainFrame.kpiCards then
            for _, card in pairs(mainFrame.kpiCards) do
                if card.SetBackdropColor then card:SetBackdropColor(panelR, panelG, panelB, panelA) end
                if card.SetBackdropBorderColor then card:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
                if card.title then card.title:SetTextColor(brandR, brandG, brandB) end
                if card.val then card.val:SetTextColor(textR, textG, textB) end
                if card.sub then card.sub:SetTextColor(mutedR, mutedG, mutedB) end
            end
        end
    end
    if mainFrame.tableSepAscii then mainFrame.tableSepAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
    if mainFrame.tableBotAscii then mainFrame.tableBotAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
    if mainFrame.botAscii then mainFrame.botAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
    if mainFrame.headerBorderL then mainFrame.headerBorderL:SetText("") end
    if mainFrame.headerBorderR then mainFrame.headerBorderR:SetText("") end
    for _, row in ipairs(rowFrames) do
        if row.borderL then row.borderL:SetText("") end
        if row.borderR then row.borderR:SetText("") end
    end
    if mainFrame.pageText then mainFrame.pageText:SetTextColor(t.primary[1], t.primary[2], t.primary[3]) end

    if mainFrame.btnTheme then
        mainFrame.btnTheme.label:SetText(string.format("[ THEME: %s ]", t.tag))
        mainFrame.btnTheme.label:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
    end

    if mainFrame.btnPerk then
        if self:IsRetail() then
            mainFrame.btnPerk:Hide()
        else
            mainFrame.btnPerk:Show()
            local r = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
            mainFrame.btnPerk.label:SetText(string.format("[ PERK: R%d (+%d%%) ]", r, r * 4))
            mainFrame.btnPerk.label:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
        end
    end

    if mainFrame.btnScale then
        local s = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.scale) or 1.0
        mainFrame.btnScale.label:SetText(string.format("[ SCALE: %d%% ]", math.floor(s * 100 + 0.5)))
        mainFrame.btnScale.label:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
    end

    if mainFrame.btnCompact then
        local isComp = self:IsCompact()
        mainFrame.btnCompact.label:SetText(isComp and "[ COMPACT* ]" or "[ COMPACT ]")
        mainFrame.btnCompact.label:SetTextColor(isComp and t.highlight[1] or t.primary[1], isComp and t.highlight[2] or t.primary[2], isComp and t.highlight[3] or t.primary[3])
    end

    if mainFrame.promptLabel and mainFrame.promptLabel.SetTextColor then
        mainFrame.promptLabel:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
    end
    if mainFrame.promptBox and mainFrame.promptBox.SetTextColor then
        mainFrame.promptBox:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
    end
    if mainFrame.promptSepAscii and mainFrame.promptSepAscii.SetTextColor then
        mainFrame.promptSepAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8)
    end
    if mainFrame.promptStatusTip and mainFrame.promptStatusTip.SetTextColor then
        mainFrame.promptStatusTip:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
    end

    if self.UpdateMinimapTheme then
        self:UpdateMinimapTheme()
    end
    if self.ApplyThemeToBagButton then
        self:ApplyThemeToBagButton()
    end
    if self.UpdateMailAutoFillButton then
        self:UpdateMailAutoFillButton()
    end
    if settingsDialog and settingsDialog:IsShown() and self.UpdateSettingsDialog then
        self:UpdateSettingsDialog()
    end
end

-- ----------------------------------------------------------------------------
-- Tab Switching, Sorting & Filtering Controls
-- ----------------------------------------------------------------------------
function CLIAlts:ToggleSortKey(key)
    if not key then return end
    if CLIAltsDB and CLIAltsDB.settings then
        if CLIAltsDB.settings.sortBy == key then
            CLIAltsDB.settings.sortAsc = not CLIAltsDB.settings.sortAsc
        else
            CLIAltsDB.settings.sortBy = key
            CLIAltsDB.settings.sortAsc = (key == "name" or key == "level" or key == "prof" or key == "role")
        end
    end
    PlayRetroSound()
    currentPage = 1
    self:Render()
end

function CLIAlts:SwitchTab(tabId)
    tabId = tonumber(tabId)
    if not tabId or tabId < 1 or tabId > 7 then return end
    if CLIAltsDB and CLIAltsDB.settings then
        CLIAltsDB.settings.activeTab = tabId
    end
    currentPage = 1
    PlayRetroSound()
    self:Render()
end

function CLIAlts:SetFilter(filterStr)
    if not filterStr or filterStr == "" then
        self.activeFilter = nil
    else
        self.activeFilter = filterStr:match("^%s*(.-)%s*$")
        if self.activeFilter == "" then
            self.activeFilter = nil
        end
    end

    -- Bidirectional sync with search edit box
    if mainFrame and mainFrame.searchBox and not mainFrame.searchBox:HasFocus() then
        local targetText = self.activeFilter or ""
        if mainFrame.searchBox:GetText() ~= targetText then
            mainFrame.searchBox:SetText(targetText)
        end
        if mainFrame.searchBox.placeholder then
            if #targetText > 0 then
                mainFrame.searchBox.placeholder:Hide()
            else
                mainFrame.searchBox.placeholder:Show()
            end
        end
    end

    currentPage = 1
    self:Render()
end

function CLIAlts:SetPage(page)
    local p = tonumber(page)
    if p and p >= 1 and p <= (totalPages or 1) then
        currentPage = p
        self:Render()
    end
end

-- ----------------------------------------------------------------------------
-- Interactive Terminal Command Prompt Methods
-- ----------------------------------------------------------------------------
function CLIAlts:SetPromptFeedback(msg, isError)
    self.lastFeedbackText = msg
    local target = (mainFrame and mainFrame.promptStatusTip) or (mainFrame and mainFrame.legendText)
    if not target then return end
    local t = self:GetTheme()
    local color = isError and "|cffff4444" or ((t and t.highlightHex) or "|cffffd100")
    target:SetText(string.format("%s>> %s|r", color, msg or ""))

    local safeAfter = self.SafeAfter or (C_Timer and C_Timer.After)
    if safeAfter then
        safeAfter(4.0, function()
            if mainFrame then
                if mainFrame.legendText then
                    mainFrame.legendText:SetText("Capped means at the XP cap. Losing means XP is being wasted.")
                    local mutedR, mutedG, mutedB = CLIAlts:Hex("muted")
                    mainFrame.legendText:SetTextColor(mutedR, mutedG, mutedB)
                elseif mainFrame.promptStatusTip then
                    mainFrame.promptStatusTip:SetText("|cff888888[Commands: 1-6, sort <col>, filter <query>, find <text>, watch <item>, next, export, help]|r")
                end
            end
        end)
    end
end

function CLIAlts:ExecutePromptCommand(input)
    if not input then return end
    local clean = input:match("^%s*(.-)%s*$") or ""
    if clean == "" then return end

    if not CLIAltsDB.commandHistory then
        CLIAltsDB.commandHistory = {}
    end
    local hist = CLIAltsDB.commandHistory
    if hist[#hist] ~= clean then
        table.insert(hist, clean)
        if #hist > 50 then
            table.remove(hist, 1)
        end
    end

    local cmd, args = clean:match("^(%S+)%s*(.*)$")
    if not cmd then return end
    cmd = cmd:lower()
    args = args and args:match("^%s*(.-)%s*$") or ""

    if cmd == "1" or cmd == "2" or cmd == "3" or cmd == "4" or cmd == "5" or cmd == "6" or cmd == "7" then
        local tNum = tonumber(cmd)
        self:SwitchTab(tNum)
        self:SetPromptFeedback(string.format("Switched to Tab %d", tNum))

    elseif cmd == "tab" then
        local tNum = tonumber(args)
        if tNum and tNum >= 1 and tNum <= 7 then
            self:SwitchTab(tNum)
            self:SetPromptFeedback(string.format("Switched to Tab %d", tNum))
        else
            self:SetPromptFeedback("Usage: tab <1-7>", true)
        end

    elseif cmd == "sort" then
        if args and args ~= "" then
            local map = {
                name = "name",
                char = "name",
                lvl = "level",
                level = "level",
                gold = "gold",
                money = "gold",
                rest = "rested",
                rested = "rested",
                cohort = "cohort",
                tier = "cohort",
                role = "cohort",
                xp = "xp",
                exp = "xp",
                progress = "xp",
                waste = "waste",
                wst = "waste",
                fac = "name",
                cd = "cooldown",
                cooldown = "cooldown",
                lock = "cooldown",
                locks = "cooldown",
                loc = "location",
                location = "location",
                zone = "location",
                hearth = "hearth",
                inn = "hearth",
                bind = "hearth",
                seen = "seen",
                last = "seen",
                stale = "seen",
                rotation = "rotation",
                rot = "rotation",
                next = "rotation",
                status = "rotation",
            }
            local key = map[args:lower()] or args:lower()
            self:ToggleSortKey(key)
            local dir = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.sortAsc) and "ASC" or "DESC"
            self:SetPromptFeedback(string.format("Sorted by %s (%s)", key:upper(), dir))
        else
            self:SetPromptFeedback("Usage: sort <name|level|gold|rested|waste|xp|location|hearth|seen>", true)
        end

    elseif cmd == "filter" or cmd == "find" then
        if args and args ~= "" and args:lower() ~= "clear" then
            self:SetFilter(args)
            self:SetPromptFeedback(string.format("Filter applied: '%s'", args))
        else
            self:SetFilter(nil)
            self:SetPromptFeedback("Filter cleared.")
        end

    elseif cmd == "clear" then
        self:SetFilter(nil)
        self:SetPromptFeedback("Filter cleared.")

    elseif cmd == "goto" or cmd == "page" then
        local num = tonumber(args)
        if num and num >= 1 and num <= totalPages then
            currentPage = num
            self:Render()
            self:SetPromptFeedback(string.format("Jumped to Page %d", num))
        elseif num and num >= 1 and num <= ROWS_COUNT and rowFrames[num] and rowFrames[num].charData then
            self:ShowDossierPopup(rowFrames[num].charData)
            self:SetPromptFeedback(string.format("Opened Dossier: %s", rowFrames[num].charData.name or ""))
        else
            self:SetPromptFeedback(string.format("Usage: goto <page 1-%d or row 1-%d>", totalPages or 1, ROWS_COUNT), true)
        end

    elseif cmd == "next" then
        self:PrintNextAlts()
        self:SetPromptFeedback("Next recommended alts printed to chat.")

    elseif cmd == "watch" then
        if args and args ~= "" then
            local ok, item = self:AddWatchItem(args)
            if ok then
                local name = self:GetWatchItemPlainName(item)
                self:SetPromptFeedback(string.format("Added '%s' to watchlist", name))
            else
                local name = self:GetWatchItemPlainName(item or args)
                self:SetPromptFeedback(string.format("Already watched: '%s'", name), true)
            end
            self:Render()
        else
            self:SetPromptFeedback("Usage: watch <Item Link, ID, or Name>", true)
        end

    elseif cmd == "unwatch" then
        if args and args ~= "" then
            local ok, item = self:RemoveWatchItem(args)
            if ok then
                local name = self:GetWatchItemPlainName(item)
                self:SetPromptFeedback(string.format("Removed '%s' from watchlist", name))
            else
                self:SetPromptFeedback(string.format("Item '%s' not in watchlist", args), true)
            end
            self:Render()
        else
            self:SetPromptFeedback("Usage: unwatch <Item Link, ID, or Name>", true)
        end

    elseif cmd == "watchlist" then
        self:PrintWatchlist()
        self:SetPromptFeedback("Watchlist printed to chat.")

    elseif cmd == "export" or cmd == "csv" then
        self:ShowExportPopup()
        self:SetPromptFeedback("CSV Export window opened.")

    elseif cmd == "settings" or cmd == "config" or cmd == "options" or cmd == "pref" then
        self:ShowSettingsDialog()
        self:SetPromptFeedback("Settings dialog opened.")

    elseif cmd == "compact" or cmd == "c" then
        self:ToggleCompact()
        local isComp = self:IsCompact()
        self:SetPromptFeedback(string.format("Compact mode: %s (XP bars %s)", isComp and "ENABLED" or "DISABLED", isComp and "hidden" or "shown"))

    elseif cmd == "legacy" or cmd == "legacyui" then
        CLIAltsDB.settings.legacyUI = not CLIAltsDB.settings.legacyUI
        local state = CLIAltsDB.settings.legacyUI and "ENABLED (ASCII Table UI)" or "DISABLED (Modern v2 UI)"
        self:SetPromptFeedback(string.format("Legacy UI: %s", state))
        if self.RecreateMainFrame then
            local wasShown = mainFrame and mainFrame:IsShown()
            self:RecreateMainFrame()
            if wasShown and mainFrame then
                mainFrame:Show()
                self:Render()
            end
        end

    elseif cmd == "tooltips" or cmd == "tooltip" or cmd == "inv" then
        CLIAltsDB.settings.showInventoryTooltips = (CLIAltsDB.settings.showInventoryTooltips == false)
        local isEnabled = CLIAltsDB.settings.showInventoryTooltips
        self:SetPromptFeedback(string.format("Inventory hover tooltips: %s", isEnabled and "ENABLED" or "DISABLED"))

    elseif cmd == "theme" then
        if args and args ~= "" then
            local map = self.THEME_MAP or CLIAlts.THEME_MAP
            local choice = map and map[args:lower()]
            if choice and self.THEMES and self.THEMES[choice] then
                CLIAltsDB.settings.theme = choice
                CLIAltsDB.settings.themeExplicit = true
                self:ApplyTheme()
                self:Render()
                self:SetPromptFeedback(string.format("Theme set to %s (%s)", choice, self.THEMES[choice] and self.THEMES[choice].tag or choice))
            else
                self:SetPromptFeedback("Themes: blizzard, amber, green, cyan, mono, safe, synthwave, dracula", true)
            end
        else
            self:CycleTheme()
            self:SetPromptFeedback(string.format("Theme cycled: %s", CLIAltsDB.settings.theme))
        end

    elseif cmd == "scale" then
        if args and args ~= "" then
            local cleanVal = args:gsub("%%", "")
            local val = tonumber(cleanVal)
            if val then
                if val > 5 then val = val / 100 end
                self:SetScale(val)
                self:SetPromptFeedback(string.format("Scale set to %d%%", math.floor(val * 100 + 0.5)))
            else
                self:SetPromptFeedback("Usage: scale <0.7 - 1.8>", true)
            end
        else
            self:CycleScale()
            local curScale = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.scale) or 1.0
            self:SetPromptFeedback(string.format("Scale: %d%%", math.floor(curScale * 100 + 0.5)))
        end

    elseif cmd == "perk" then
        if self:IsRetail() then
            self:SetPromptFeedback("Perks are not applicable on Retail WoW", true)
            return
        end
        if args and args ~= "" then
            local r = tonumber(args)
            if r and r >= 0 and r <= 5 then
                self:SetWellRestedRank(r)
                self:SetPromptFeedback(string.format("Well Rested perk set to Rank %d", r))
            else
                self:SetPromptFeedback("Usage: perk <0-5>", true)
            end
        else
            self:CycleWellRestedPerk()
            local curR = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.wellRestedRank) or 0
            self:SetPromptFeedback(string.format("Well Rested perk rank: %d", curR))
        end

    elseif cmd == "refresh" then
        self:Refresh()
        self:SetPromptFeedback("Database refreshed.")

    elseif cmd == "perf" then
        self:PrintPerf()
        self:SetPromptFeedback("Performance metrics printed to chat.")

    elseif cmd == "selftest" or cmd == "test" then
        local ok, passed, failed = self:RunSelfTest()
        self:SetPromptFeedback(string.format("Self-test: %d passed, %d failed", passed or 0, failed or 0), not ok)

    elseif cmd == "alerts" or cmd == "alert" then
        local fb = self:HandleAlertsCommand(args)
        self:SetPromptFeedback(fb or "Alert settings updated.")

    elseif cmd == "digest" then
        self:PrintLoginDigest(true)
        self:SetPromptFeedback("Login digest printed to chat.")

    elseif cmd == "plan" then
        local planText = self:PrintPlan(args)
        self:SetPromptFeedback(planText or "Session plan generated.")

    elseif cmd == "note" then
        local targetName, noteText = (args or ""):match("^(%S+)%s*(.*)$")
        local msg, ok = self:SetCharacterNote(targetName, noteText, false)
        self:SetPromptFeedback(msg or "Note updated.", not ok)

    elseif cmd == "unlocked" or cmd == "lockout" or cmd == "lockouts" then
        local fb, ok = self:PrintUnlockedAlts(args)
        self:SetPromptFeedback(fb or "Lockout check complete.", not ok)

    elseif cmd == "prune" then
        local daysStr, optConfirm = args:match("^(%d+)%s*(.*)$")
        local days = tonumber(daysStr)
        if not days or days < 1 then
            self:SetPromptFeedback("Usage: prune <days> [confirm] (e.g. prune 30)", true)
        else
            local count, names = self:GetPrunableCharacters(days)
            if count == 0 then
                self:SetPromptFeedback(string.format("No alts found inactive for %d+ days.", days))
            elseif optConfirm and (optConfirm:lower() == "confirm" or optConfirm:lower() == "now" or optConfirm:lower() == "yes") then
                local prunedCount, prunedNames = self:PruneCharacters(days)
                local sample = table.concat(prunedNames, ", ", 1, math.min(3, #prunedNames))
                if #prunedNames > 3 then sample = sample .. "..." end
                self:SetPromptFeedback(string.format("Pruned %d alts (%s)", prunedCount, sample))
                self:Render()
            else
                self:ShowConfirmPrunePopup(days, count, names)
                self:SetPromptFeedback(string.format("Found %d alts inactive for %d+ days. Confirm in popup.", count, days))
            end
        end

    elseif cmd == "backup" then
        local ok, msg = self:BackupDB("manual")
        self:SetPromptFeedback(ok and "Backup saved to CLIAltsDB.backup." or msg, not ok)

    elseif cmd == "restore" then
        local ok, msg = self:RestoreDB()
        self:SetPromptFeedback(msg, not ok)

    elseif cmd == "forever" or cmd == "wf" then
        self:ToggleForeverMode()
        local isForever = self:IsForeverMode()
        if isForever then
            CLIAltsDB.settings.activeTab = 1
            self:SetPromptFeedback("WoW Forever Mode: ENABLED (Tab 1 Cohorts active)")
        else
            self:SetPromptFeedback("WoW Forever Mode: DISABLED (Standard view restored)")
        end
        self:Render()

    elseif cmd == "role" or cmd == "tier" or cmd == "cohort" then
        if not args or args == "" then
            self:PrintRosterRoles()
            self:SetPromptFeedback("Printed roster cohorts to chat. Usage: role <name> <core|reserve|bank|none> [role] [tgt]")
        else
            local targetName, tier, remaining = args:match("^(%S+)%s+(%S+)%s*(.*)$")
            if not targetName or not tier then
                local singleName = args:match("^(%S+)$")
                local foundChar = nil
                if singleName and CLIAltsDB and CLIAltsDB.characters then
                    for _, c in pairs(CLIAltsDB.characters) do
                        local n = (c.name or ""):lower()
                        if n == singleName:lower() or n:find(singleName:lower(), 1, true) then
                            foundChar = c
                            break
                        end
                    end
                end
                if foundChar then
                    local newT = self:CycleCharacterTier(foundChar)
                    self:Render()
                    self:SetPromptFeedback(string.format("Cycled %s -> %s (Target Level %d)", foundChar.name, newT, foundChar.target_level))
                else
                    self:SetPromptFeedback("Usage: role <name> <core|reserve|bank|none> [supply_role] [target_level]", true)
                end
            else
                local supplyRole, targetLvl = remaining:match("^(.-)%s+(%d+)$")
                if not supplyRole then
                    if tonumber(remaining) then
                        targetLvl = tonumber(remaining)
                        supplyRole = nil
                    else
                        supplyRole = (remaining ~= "") and remaining or nil
                        targetLvl = nil
                    end
                end
                local ok, msg = self:SetCharacterRole(targetName, tier, supplyRole, targetLvl)
                self:Render()
                self:SetPromptFeedback(msg, not ok)
            end
        end

    elseif cmd == "core" then
        if not args or args == "" then
            self:SetPromptFeedback("Usage: core <character>", true)
        else
            local ok, msg = self:SetCharacterRole(args, "CORE")
            self:Render()
            self:SetPromptFeedback(msg, not ok)
        end

    elseif cmd == "alt" or cmd == "reserve" then
        if not args or args == "" then
            self:SetPromptFeedback("Usage: alt <character>", true)
        else
            local ok, msg = self:SetCharacterRole(args, "RESERVE")
            self:Render()
            self:SetPromptFeedback(msg, not ok)
        end

    elseif cmd == "bank" then
        if not args or args == "" then
            self:SetPromptFeedback("Usage: bank <character>", true)
        else
            local ok, msg = self:SetCharacterRole(args, "BANK")
            self:Render()
            self:SetPromptFeedback(msg, not ok)
        end

    elseif cmd == "unassign" or cmd == "unset" then
        if not args or args == "" then
            self:SetPromptFeedback("Usage: unassign <character>", true)
        else
            local ok, msg = self:SetCharacterRole(args, "UNASSIGNED")
            self:Render()
            self:SetPromptFeedback(msg, not ok)
        end

    elseif cmd == "prof" or cmd == "milestones" or cmd == "professions" then
        self:PrintProfessionMilestones()
        self:SetPromptFeedback("Profession milestones printed to chat.")

    elseif cmd == "dungeon" or cmd == "dungeons" or cmd == "dng" then
        local fb, ok = self:PrintDungeonReadiness(args)
        self:SetPromptFeedback(fb or "Dungeon readiness check printed to chat.", not ok)

    elseif cmd == "mail" or cmd == "router" or cmd == "supplychain" then
        local fb, ok = self:PrintMailRouting()
        self:SetPromptFeedback(fb or "Mail packages printed to chat.", not ok)

    elseif cmd == "lp" or cmd == "legacypoints" or cmd == "legacypoint" then
        local fb, ok = self:PrintLegacyPointStatus(args)
        self:SetPromptFeedback(fb or "Legacy Point status printed to chat.", not ok)

    elseif cmd == "sortbags" or cmd == "cleanup" then
        self:SortBags()
        self:SetPromptFeedback("Bag sort started.")

    elseif cmd == "sortbtn" or cmd == "sortbutton" then
        local newState = self:ToggleBagSortButton()
        self:SetPromptFeedback(string.format("Bag auto-sort button: %s", newState and "ENABLED" or "DISABLED"))

    elseif cmd == "fillmail" or cmd == "mailfill" or cmd == "autofillmail" then
        local ok, who, cnt = self:FillSendMailNextBatch()
        if ok then
            self:SetPromptFeedback(string.format("Loaded mail for %s (%d items)", who, cnt))
        else
            self:SetPromptFeedback(who or "Could not fill mail.", true)
        end

    elseif cmd == "mailbtn" or cmd == "mailbutton" then
        local newState = self:ToggleMailAutoFillButton()
        self:SetPromptFeedback(string.format("Mail auto-fill button: %s", newState and "ENABLED" or "DISABLED"))

    elseif cmd == "mailignore" or cmd == "ignoremail" then
        local ok, itm = self:IgnoreMailItem(arg)
        if ok then
            self:SetPromptFeedback(string.format("Ignored for mail: %s", itm))
        else
            self:SetPromptFeedback("Usage: mailignore <[Item Link] or Name or ID>", true)
        end

    elseif cmd == "mailunignore" or cmd == "unignoremail" then
        local ok, itm = self:UnignoreMailItem(arg)
        if ok then
            self:SetPromptFeedback(string.format("Removed from mail ignore: %s", itm))
        else
            self:SetPromptFeedback(string.format("Item not found in ignore list: %s", arg or ""), true)
        end

    elseif cmd == "mailignores" or cmd == "ignoredmail" then
        local count = self:ListIgnoredMailItems()
        self:SetPromptFeedback(string.format("%d items in mail ignore list.", count))

    elseif cmd == "mailconsumables" then
        local newState = self:ToggleAutoMailConsumables()
        self:SetPromptFeedback(string.format("Auto-mail consumables: %s", newState and "ENABLED" or "DISABLED"))

    elseif cmd == "tour" or cmd == "onboarding" then
        self:StartTour()
        self:SetPromptFeedback("Onboarding tour started.")

    elseif cmd == "help" then
        self:ShowHelpPopup()
        self:SetPromptFeedback("Help manual opened.")

    elseif cmd == "exit" or cmd == "quit" or cmd == "close" then
        if mainFrame then mainFrame:Hide() end

    else
        self:SetPromptFeedback(string.format("Unknown command: '%s'. Type 'help' for manual.", cmd), true)
    end
end

function CLIAlts:AutoCompletePrompt(editBox)
    if not editBox then return end
    local text = editBox:GetText() or ""
    local trimmed = text:match("^%s*(.-)%s*$") or ""

    local commands = {
        "1", "2", "3", "4", "5", "6", "7",
        "tab", "mail", "fillmail", "mailbtn", "mailignore", "mailunignore", "mailignores", "mailconsumables",
        "sort", "sortbags", "sortbtn", "filter", "find", "clear",
        "goto", "page", "next", "export", "compact",
        "watch", "unwatch", "watchlist",
        "theme", "scale", "perk", "perf", "selftest",
        "alerts", "digest", "plan", "note", "unlocked", "prune",
        "backup", "restore", "tour", "onboarding", "tooltips", "inv",
        "core", "alt", "bank", "unassign", "prof", "milestones",
        "forever", "role",
        "refresh", "help", "exit", "close"
    }

    local cmd, arg = trimmed:match("^(%S+)%s+(.*)$")
    if cmd then
        cmd = cmd:lower()
        if cmd == "sort" then
            local sortKeys = { "name", "level", "cohort", "role", "gold", "rested", "waste", "xp", "rotation", "next", "location", "hearth", "seen", "note", "prof", "cd", "cooldown" }
            for _, k in ipairs(sortKeys) do
                if k:sub(1, #arg) == arg:lower() and k ~= arg:lower() then
                    editBox:SetText("sort " .. k)
                    editBox:SetCursorPosition(#editBox:GetText())
                    return
                end
            end
        elseif cmd == "note" then
            if CLIAltsDB and CLIAltsDB.characters and not arg:find("%s") then
                for _, c in pairs(CLIAltsDB.characters) do
                    local name = c.name or ""
                    if name:lower():sub(1, #arg) == arg:lower() and name:lower() ~= arg:lower() then
                        editBox:SetText("note " .. name .. " ")
                        editBox:SetCursorPosition(#editBox:GetText())
                        return
                    end
                end
            end
        elseif cmd == "unlocked" then
            local raidNames = {
                '"Molten Core"', '"Onyxia\'s Lair"', '"Blackwing Lair"',
                '"Zul\'Gurub"', '"Ruins of Ahn\'Qiraj"', '"Temple of Ahn\'Qiraj"',
                '"Naxxramas"', '"Upper Blackrock Spire"', '"Stratholme"', '"Scholomance"', '"Dire Maul"'
            }
            local cleanArg = arg:gsub('^["\']', ''):lower()
            for _, r in ipairs(raidNames) do
                local rClean = r:gsub('^["\']', ''):gsub('["\']$', ''):lower()
                if rClean:sub(1, #cleanArg) == cleanArg and rClean ~= cleanArg then
                    editBox:SetText("unlocked " .. r)
                    editBox:SetCursorPosition(#editBox:GetText())
                    return
                end
            end
        elseif cmd == "unwatch" then
            if CLIAltsDB and CLIAltsDB.watchlist and #CLIAltsDB.watchlist > 0 then
                for _, item in ipairs(CLIAltsDB.watchlist) do
                    local name = CLIAlts.GetWatchItemPlainName and CLIAlts:GetWatchItemPlainName(item) or tostring(item)
                    if name:lower():sub(1, #arg) == arg:lower() and name:lower() ~= arg:lower() then
                        editBox:SetText("unwatch " .. name)
                        editBox:SetCursorPosition(#editBox:GetText())
                        return
                    end
                end
            end
        elseif cmd == "theme" then
            local themes = { "blizzard", "wow", "amber", "green", "cyan", "mono", "safe", "colorblind", "synthwave", "dracula" }
            for _, th in ipairs(themes) do
                if th:sub(1, #arg) == arg:lower() and th ~= arg:lower() then
                    editBox:SetText("theme " .. th)
                    editBox:SetCursorPosition(#editBox:GetText())
                    return
                end
            end
        end
        return
    end

    for _, c in ipairs(commands) do
        if c:sub(1, #trimmed) == trimmed:lower() and c ~= trimmed:lower() then
            editBox:SetText(c .. " ")
            editBox:SetCursorPosition(#editBox:GetText())
            return
        end
    end
end

-- ----------------------------------------------------------------------------
-- Alt Dossier Modal (Detailed Character Inspection)
-- ----------------------------------------------------------------------------
function CLIAlts:GetDossierPopup()
    return dossierPopup
end

function CLIAlts:GetCustomRolePopup()
    return customRolePopup
end

function CLIAlts:ShowDossierPopup(char, forcePopup)
    if not char then return end

    if type(char) == "string" then
        local found = nil
        for _, c in ipairs(self:GetCharactersList() or {}) do
            if (c.fullName and c.fullName == char) or (c.name and c.name == char) then
                found = c
                break
            end
        end
        char = found or { name = char }
    end

    self.selectedCharKey = char.fullName or char.name

    if not forcePopup and not self:IsCompact() and not (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.legacyUI) then
        if dossierPopup and dossierPopup.Hide then dossierPopup:Hide() end
        if not mainFrame or not mainFrame:IsShown() then
            self:Toggle(true)
        end
        self:UpdateDetailPanel()
        self:Render()
        return
    end

    if not dossierPopup then
        local t = self:GetTheme()
        local dp = CreateFrame("Frame", "CLIAltsDossierPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        dp:Hide()
        dp:SetSize(680, 660)
        dp:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        dp:SetFrameStrata("DIALOG")
        dp:EnableMouse(true)
        dp:SetMovable(true)
        dp:RegisterForDrag("LeftButton")
        dp:SetScript("OnDragStart", function(self) self:StartMoving() end)
        dp:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        tinsert(UISpecialFrames, "CLIAltsDossierPopup")

        dp:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        dp:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
        dp:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 1)

        local body = dp:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(body, 12)
        body:SetPoint("TOPLEFT", dp, "TOPLEFT", 16, -16)
        body:SetPoint("BOTTOMRIGHT", dp, "BOTTOMRIGHT", -16, 72)
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        body:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
        dp.body = body

        -- Row 1 (Bottom, y=14): Cohort Assignment & Management Controls
        local btnDel = CreateRetroButton(dp, "[ PURGE ]", 72, 20, function()
            dp:Hide()
            if dp.charData then
                CLIAlts:ShowConfirmDelete(dp.charData)
            end
        end, 11)
        btnDel:SetPoint("BOTTOMLEFT", dp, "BOTTOMLEFT", 16, 14)
        dp.btnDel = btnDel

        local btnSetCore = CreateRetroButton(dp, "[ SET CORE (35) ]", 116, 20, function()
            if dp.charData then
                local charName = dp.charData.fullName or dp.charData.name or (dp.charData.fullName and dp.charData.fullName:match("^(%S+)"))
                if charName then
                    CLIAlts:SetCharacterCohort(charName, "CORE")
                    CLIAlts:ShowDossierPopup(dp.charData)
                    CLIAlts:RequestRender()
                end
            end
        end, 11)
        btnSetCore:SetPoint("LEFT", btnDel, "RIGHT", 6, 0)
        dp.btnSetCore = btnSetCore

        local btnSetAlt = CreateRetroButton(dp, "[ SET ALT (25) ]", 110, 20, function()
            if dp.charData then
                local charName = dp.charData.fullName or dp.charData.name or (dp.charData.fullName and dp.charData.fullName:match("^(%S+)"))
                if charName then
                    CLIAlts:SetCharacterCohort(charName, "RESERVE")
                    CLIAlts:ShowDossierPopup(dp.charData)
                    CLIAlts:RequestRender()
                end
            end
        end, 11)
        btnSetAlt:SetPoint("LEFT", btnSetCore, "RIGHT", 6, 0)
        dp.btnSetAlt = btnSetAlt

        local btnSetBank = CreateRetroButton(dp, "[ SET BANK (1) ]", 108, 20, function()
            if dp.charData then
                local charName = dp.charData.fullName or dp.charData.name or (dp.charData.fullName and dp.charData.fullName:match("^(%S+)"))
                if charName then
                    CLIAlts:SetCharacterCohort(charName, "BANK")
                    CLIAlts:ShowDossierPopup(dp.charData)
                    CLIAlts:RequestRender()
                end
            end
        end, 11)
        btnSetBank:SetPoint("LEFT", btnSetAlt, "RIGHT", 6, 0)
        dp.btnSetBank = btnSetBank

        local btnUnset = CreateRetroButton(dp, "[ UNSET ]", 72, 20, function()
            if dp.charData then
                local charName = dp.charData.fullName or dp.charData.name or (dp.charData.fullName and dp.charData.fullName:match("^(%S+)"))
                if charName then
                    CLIAlts:SetCharacterCohort(charName, "UNASSIGNED")
                    CLIAlts:ShowDossierPopup(dp.charData)
                    CLIAlts:RequestRender()
                end
            end
        end, 11)
        btnUnset:SetPoint("LEFT", btnSetBank, "RIGHT", 6, 0)
        dp.btnUnset = btnUnset

        local btnClose = CreateRetroButton(dp, "[ CLOSE ]", 75, 20, function()
            dp:Hide()
        end, 11)
        btnClose:SetPoint("BOTTOMRIGHT", dp, "BOTTOMRIGHT", -16, 14)
        dp.btnClose = btnClose

        -- Row 2 (Middle, y=42): 1-Click Supply Role Configuration Bar
        local roleLabel = dp:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(roleLabel, 11, "")
        roleLabel:SetPoint("BOTTOMLEFT", dp, "BOTTOMLEFT", 16, 42)
        roleLabel:SetText("ROLE:")
        dp.roleLabel = roleLabel

        local function OnRoleClick(roleName)
            if dp.charData then
                local charName = dp.charData.fullName or dp.charData.name or (dp.charData.fullName and dp.charData.fullName:match("^(%S+)"))
                if charName then
                    CLIAlts:SetCharacterSupplyRole(charName, roleName)
                    CLIAlts:ShowDossierPopup(dp.charData)
                    CLIAlts:RequestRender()
                end
            end
        end

        local btnRoleTailor = CreateRetroButton(dp, "[ Tailor/Bags ]", 92, 19, function() OnRoleClick("Tailor/Bags") end, 11)
        btnRoleTailor:SetPoint("LEFT", roleLabel, "RIGHT", 6, 0)
        dp.btnRoleTailor = btnRoleTailor

        local btnRoleAlch = CreateRetroButton(dp, "[ Alch/DE ]", 76, 19, function() OnRoleClick("Alch/DE") end, 11)
        btnRoleAlch:SetPoint("LEFT", btnRoleTailor, "RIGHT", 4, 0)
        dp.btnRoleAlch = btnRoleAlch

        local btnRoleMiner = CreateRetroButton(dp, "[ Miner/BS ]", 80, 19, function() OnRoleClick("Miner/BS") end, 11)
        btnRoleMiner:SetPoint("LEFT", btnRoleAlch, "RIGHT", 4, 0)
        dp.btnRoleMiner = btnRoleMiner

        local btnRoleLW = CreateRetroButton(dp, "[ Skinner/LW ]", 88, 19, function() OnRoleClick("Skinner/LW") end, 11)
        btnRoleLW:SetPoint("LEFT", btnRoleMiner, "RIGHT", 4, 0)
        dp.btnRoleLW = btnRoleLW

        local btnRolePassive = CreateRetroButton(dp, "[ Passive LP ]", 84, 19, function() OnRoleClick("Passive LP") end, 11)
        btnRolePassive:SetPoint("LEFT", btnRoleLW, "RIGHT", 4, 0)
        dp.btnRolePassive = btnRolePassive

        local btnRoleAuto = CreateRetroButton(dp, "[ Auto ]", 62, 19, function() OnRoleClick("clear") end, 11)
        btnRoleAuto:SetPoint("LEFT", btnRolePassive, "RIGHT", 4, 0)
        dp.btnRoleAuto = btnRoleAuto

        local btnRoleCustom = CreateRetroButton(dp, "[ Custom... ]", 78, 19, function()
            if dp.charData then
                CLIAlts:ShowCustomRolePrompt(dp.charData)
            end
        end, 11)
        btnRoleCustom:SetPoint("LEFT", btnRoleAuto, "RIGHT", 4, 0)
        dp.btnRoleCustom = btnRoleCustom

        dossierPopup = dp
        self.dossierPopup = dp
    end

    dossierPopup.charData = char
    local t = self:GetTheme()
    dossierPopup:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
    dossierPopup:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 1)

    if dossierPopup.body then
        dossierPopup.body:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
    end
    if dossierPopup.roleLabel then
        dossierPopup.roleLabel:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
    end

    -- Highlight active Cohort
    local activeTier = char.tier or "UNASSIGNED"
    local activeHex = t.readyHex or "55e39a"
    if dossierPopup.btnSetCore then
        dossierPopup.btnSetCore.label:SetText(activeTier == "CORE" and string.format("|cff%s*CORE (35)*|r", activeHex) or "[ SET CORE (35) ]")
        dossierPopup.btnSetAlt.label:SetText(activeTier == "RESERVE" and string.format("|cff%s*ALT (25)*|r", activeHex) or "[ SET ALT (25) ]")
        dossierPopup.btnSetBank.label:SetText(activeTier == "BANK" and string.format("|cff%s*BANK (1)*|r", activeHex) or "[ SET BANK (1) ]")
        dossierPopup.btnUnset.label:SetText(activeTier == "UNASSIGNED" and string.format("|cff%s*UNASSIGNED*|r", activeHex) or "[ UNSET ]")
    end

    -- Highlight active Supply Role
    local activeRole = char.supply_role or ""
    if dossierPopup.btnRoleTailor then
        dossierPopup.btnRoleTailor.label:SetText(activeRole == "Tailor/Bags" and string.format("|cff%s*Tailor/Bags*|r", activeHex) or "[ Tailor/Bags ]")
        dossierPopup.btnRoleAlch.label:SetText(activeRole == "Alch/DE" and string.format("|cff%s*Alch/DE*|r", activeHex) or "[ Alch/DE ]")
        dossierPopup.btnRoleMiner.label:SetText(activeRole == "Miner/BS" and string.format("|cff%s*Miner/BS*|r", activeHex) or "[ Miner/BS ]")
        dossierPopup.btnRoleLW.label:SetText(activeRole == "Skinner/LW" and string.format("|cff%s*Skinner/LW*|r", activeHex) or "[ Skinner/LW ]")
        dossierPopup.btnRolePassive.label:SetText(activeRole == "Passive LP" and string.format("|cff%s*Passive LP*|r", activeHex) or "[ Passive LP ]")
        dossierPopup.btnRoleAuto.label:SetText(activeRole == "" and string.format("|cff%s*Auto*|r", activeHex) or "[ Auto ]")
        if activeRole ~= "" and activeRole ~= "Tailor/Bags" and activeRole ~= "Alch/DE" and activeRole ~= "Miner/BS" and activeRole ~= "Skinner/LW" and activeRole ~= "Passive LP" then
            local trunc = (#activeRole > 9) and (activeRole:sub(1, 8) .. "..") or activeRole
            dossierPopup.btnRoleCustom.label:SetText(string.format("|cff%s*%s*|r", activeHex, trunc))
        else
            dossierPopup.btnRoleCustom.label:SetText("[ Custom... ]")
        end
    end

    local ok, renderErr = pcall(function()
        local lines = {}
        table.insert(lines, string.format("|cff%sCLIALTS :: ALT DOSSIER & RECORD|r", t.highlightHex or "ffd34e"))
        table.insert(lines, string.format("|cff%s%s|r", t.borderHex or "f2c94c", string.rep("=", 68)))

        if char.secondaryName and char.secondaryName ~= "" then
            table.insert(lines, string.format("Full Name:      %s", self:ColorizePlayerName(char.fullName or char.name or "Unknown", char.classFile)))
            table.insert(lines, string.format("  * First Name: |cffffffff%s|r", char.primaryName or char.name or "Unknown"))
            table.insert(lines, string.format("  * Surname:    |cffffffff%s|r", tostring(char.secondaryName)))
        else
            table.insert(lines, string.format("Character Name: %s", self:ColorizePlayerName(char.name or "Unknown", char.classFile)))
        end
        table.insert(lines, string.format("System:         |cffffffff%s|r", tostring(self:GetClientFlavor() or "Classic")))
        if char.realm and char.realm ~= "" and char.realm ~= "Forever" then
            table.insert(lines, string.format("Realm:          |cffffffff%s|r", tostring(char.realm)))
        end
        table.insert(lines, string.format("Faction / Race: %s |cffffffff%s (%s)|r", self:GetFactionTag(char.faction), tostring(self:FormatRace(char)), tostring(self:GetRaceCode(char))))
        table.insert(lines, string.format("Class / Level:  %s (Level |cffffffff%d|r)", self:ColorizePlayerName(char.class or "Unknown", char.classFile), tonumber(char.level) or 1))
        table.insert(lines, string.format("Current Gold:   %s", self:FormatMoney(char.money, true)))

        local logoutZoneTag = char.loggedOutInRestZone and string.format("|cff%s[REST AREA AT LOGOUT]|r", t.readyHex or "55e39a") or string.format("|cff%s[WILD AT LOGOUT]|r", t.pendingHex or "ffb547")
        table.insert(lines, string.format("Location:       |cffffffff%s|r %s", tostring(char.location or "Unknown"), logoutZoneTag))
        table.insert(lines, string.format("Hearthstone:    |cffffffff%s|r", tostring(char.bindLocation or "Unknown")))
        local isStale, daysInactive = self:IsCharStale(char)
        local staleTag = (isStale and daysInactive) and string.format(" |cff%s[STALE: %dd inactive]|r", t.blockedHex or "ff6b6b", tonumber(daysInactive) or 0) or ""
        local lastActiveDate = self:FormatDateSafe(char.lastUpdate)
        table.insert(lines, string.format("Last Active:    |cffffffff%s|r (%s)%s", self:GetTimeAgo(char.lastUpdate), lastActiveDate, staleTag))
        local noteStr = (char.note and char.note ~= "") and string.format("|cffffd700%s|r", tostring(char.note)) or string.format("|cff%sNone (set with > note <name> <text>)|r", t.mutedHex or "a9a08c")
        table.insert(lines, string.format("Player Note:    %s", noteStr))
        table.insert(lines, string.format("|cff%s%s|r", t.borderHex or "f2c94c", string.rep("-", 68)))
        table.insert(lines, string.format("|cff%sLEVEL EXPERIENCE PROGRESS|r", t.primaryHex or "f2c94c"))

        local xpData = self:GetLevelProgressData(char)
        if xpData and not xpData.isMaxLevel then
            local curXP = tonumber(xpData.curXP) or 0
            local maxXP = tonumber(xpData.maxXP) or 0
            local pctEx = tonumber(xpData.percentExact) or 0
            local remXP = tonumber(xpData.remainingXP) or 0
            local cLvl = tonumber(char.level) or 1
            table.insert(lines, string.format("Current XP:     |cffffffff%s / %s XP|r (%5.1f%% of Level %d)", self:FormatNumber(curXP), self:FormatNumber(maxXP), pctEx, cLvl))
            table.insert(lines, string.format("Next Level:     |cffffffff%s XP needed|r to reach Level %d", self:FormatNumber(remXP), cLvl + 1))
            table.insert(lines, string.format("Progress Bar:   %s%s|r %d%%", t.barFill, tostring(xpData.barStr or "[............]"), tonumber(xpData.percent) or 0))
        else
            table.insert(lines, string.format("Status:         |cff%sMAX LEVEL (Level %d reached)|r", t.mutedHex or "a9a08c", tonumber(char.level) or self:GetMaxLevel()))
        end

        table.insert(lines, string.format("|cff%s%s|r", t.borderHex or "f2c94c", string.rep("-", 68)))
        table.insert(lines, string.format("|cff%sRESTED EXPERIENCE (%s)|r", t.primaryHex or "f2c94c", tostring(self:GetClientFlavor() or "Classic")))

        local rested = self:GetRestedData(char)
        if rested and not rested.isMaxLevel then
            local est = rested.isEstimate and "~" or ""
            local restModeStr = rested.isResting and "+5.0% every 8h (Resting)" or "+1.25% every 8h (Wilderness)"
            local curRest = tonumber(rested.currentRested) or 0
            local maxRest = tonumber(rested.maxRested) or 0
            local rPct = tonumber(rested.percent) or 0
            table.insert(lines, string.format("Rested Points:  |cffffffff%s%s / %s XP|r (%s%d%% of Level)", est, self:FormatNumber(curRest), self:FormatNumber(maxRest), est, rPct))
            if not self:IsRetail() and rested.perkRank and rested.perkRank > 0 then
                local pRank = tonumber(rested.perkRank) or 0
                table.insert(lines, string.format("Rest Status:    %s (%s | Perk: R%d/5)", tostring(rested.statusStr or "[ REST ]"), restModeStr, pRank))
                table.insert(lines, string.format("Accumulation:   |cffffffff%s%s XP/hr|r (+%d%% speed bonus)", est, self:FormatNumber(math.floor((tonumber(rested.ratePerSec) or 0) * 3600)), pRank * 4))
            else
                table.insert(lines, string.format("Rest Status:    %s (%s)", tostring(rested.statusStr or "[ REST ]"), restModeStr))
                table.insert(lines, string.format("Accumulation:   |cffffffff%s%s XP/hr|r", est, self:FormatNumber(math.floor((tonumber(rested.ratePerSec) or 0) * 3600))))
            end
            table.insert(lines, string.format("Progress Bar:   %s%s|r %s%d%%", t.barFill, tostring(rested.barStr or "[............]"), est, rPct))
            table.insert(lines, string.format("Time to %d%%:   |cffffffff%s|r", tonumber(rested.maxPercent) or 150, tostring(rested.timeLeftStr or "---")))
            table.insert(lines, string.format("Projected Date: |cffffffff%s|r", tostring(rested.fullDate or "---")))
            if rested.isEstimate then
                table.insert(lines, string.format("Note:           |cff%sEstimated projection (~disconnect / crash)|r", t.pendingHex or "ffb547"))
            end
        else
            table.insert(lines, string.format("Rest Status:    |cff%sN/A (Max Level characters do not accumulate Rested XP)|r", t.mutedHex or "a9a08c"))
        end

        if self:IsForeverMode() or (char.tier and char.tier ~= "UNASSIGNED") then
            table.insert(lines, string.format("|cff%s%s|r", t.borderHex or "f2c94c", string.rep("-", 68)))
            local tierStr = tostring(char.tier or "UNASSIGNED")
            local tgtLvl = tonumber(char.target_level) or ((tierStr == "CORE" and 35) or (tierStr == "RESERVE" and 25) or (tierStr == "BANK" and 1) or 60)
            local curLvl = tonumber(char.level) or 1
            local statusTag = (curLvl >= tgtLvl) and string.format(" |cff%s[Target Level Reached]|r", t.readyHex or "55e39a") or ""
            table.insert(lines, string.format("ROSTER COHORT:  |cffffd700[%s]|r (Target Level: |cffffffff%d|r)%s", tierStr, tgtLvl, statusTag))
            local roleStr = (char.supply_role and char.supply_role ~= "") and string.format("|cffffffff%s|r", tostring(char.supply_role)) or string.format("|cff%sAuto (detecting learned professions)|r", t.mutedHex or "a9a08c")
            table.insert(lines, string.format("Supply Role:    %s", roleStr))
            if self.CalculateCharacterLP then
                local altLP, lpReasons = self:CalculateCharacterLP(char)
                local lpDetail = (#lpReasons > 0) and (" (" .. table.concat(lpReasons, ", ") .. ")") or ""
                table.insert(lines, string.format("Legacy Points:  |cffffffff%.1f LP contributed|r%s", altLP, lpDetail))
            end
        end

        table.insert(lines, string.format("|cff%s%s|r", t.borderHex or "f2c94c", string.rep("-", 68)))
        table.insert(lines, string.format("|cff%sPROFESSIONS & CRAFTING (WOW FOREVER MILESTONES)|r", t.primaryHex or "f2c94c"))
        if char.professions and char.professions.primary and #char.professions.primary > 0 then
            for _, p in ipairs(char.professions.primary) do
                local pName = tostring(p.name or "Unknown")
                local pRank = tonumber(p.rank) or 0
                local pMax = tonumber(p.maxRank) or 0
                local m = self:GetProfessionMilestoneInfo(char, p)
                if m then
                    local statusText
                    if m.isDone then
                        statusText = string.format("|cff%s[P4 DONE - MAX]|r", t.accentHex or "57d6e8")
                    elseif m.canTrainNext and m.isCappedAtCurrentRank then
                        statusText = string.format("|cff%s[TRAIN %s AVAILABLE]|r (Req Lvl %d met)", t.readyHex or "55e39a", m.nextRankTitle:upper(), m.nextReqLevel)
                    elseif m.levelBottleneck and m.isCappedAtCurrentRank then
                        statusText = string.format("|cff%s[LEVEL BOTTLENECK: Req Lvl %d to train %s]|r", t.pendingHex or "ffb547", m.nextReqLevel, m.nextRankTitle)
                    elseif m.isMilestoneHit then
                        statusText = string.format("|cff%s[%s DONE]|r", t.accentHex or "57d6e8", m.targetPhase)
                    else
                        statusText = string.format("[%s Target: %d/%d] (%d skillups needed)", m.targetPhase, m.rank, m.targetMilestone, m.needed)
                    end
                    table.insert(lines, string.format(" * Primary:     |cffffffff%-15s|r %3d / %-3d  %s", pName, pRank, pMax, statusText))
                else
                    table.insert(lines, string.format(" * Primary:     |cffffffff%-15s|r %3d / %-3d", pName, pRank, pMax))
                end
            end
        else
            table.insert(lines, string.format(" * Primary:     |cff%sNone learned|r", t.mutedHex or "a9a08c"))
        end
        if char.professions and char.professions.secondary and #char.professions.secondary > 0 then
            for _, s in ipairs(char.professions.secondary) do
                local sName = tostring(s.name or "Unknown")
                local sRank = tonumber(s.rank) or 0
                local sMax = tonumber(s.maxRank) or 0
                table.insert(lines, string.format(" * Secondary:   |cffffffff%-15s|r %3d / %-3d", sName, sRank, sMax))
            end
        end

        -- Dungeon Quest Readiness (WoW Forever Component 4)
        local dngKeys = self.DUNGEON_KEYS or { "RFC", "WC", "DM", "SFK", "BFD" }
        local dngLines = {}
        for _, dKey in ipairs(dngKeys) do
            local r = self:GetDungeonReadiness(char, dKey)
            if r and r.factionMatch and (char.level or 1) >= (r.minLevel - 3) then
                local st = self:FormatDungeonStatusShort(char, dKey)
                table.insert(dngLines, string.format(" * %-4s (L%d-%d): %-18s %s", r.tag, r.minLevel, r.maxLevel, r.name, st))
                if r.preChains then
                    for _, pc in ipairs(r.preChains) do
                        if not pc.completed then
                            table.insert(dngLines, string.format("    |cff%s-> Missing Pre-chain: %s (%s)|r", t.pendingHex or "ffb547", pc.name, pc.nextStepName))
                        end
                    end
                end
            end
        end
        if #dngLines > 0 then
            table.insert(lines, string.format("|cff%s%s|r", t.borderHex or "f2c94c", string.rep("-", 68)))
            table.insert(lines, string.format("|cff%sDUNGEON QUEST READINESS & CHAINS (WOW FOREVER)|r", t.primaryHex or "f2c94c"))
            for _, dl in ipairs(dngLines) do
                table.insert(lines, dl)
            end
        end

        table.insert(lines, string.format("|cff%s%s|r", t.borderHex or "f2c94c", string.rep("=", 68)))

        dossierPopup.body:SetText(table.concat(lines, "\n"))
    end)

    if not ok then
        dossierPopup.body:SetText(string.format("|cffff4444Error rendering Alt Dossier:|r\n%s", tostring(renderErr)))
    end

    dossierPopup:Show()
end

function CLIAlts:ShowCustomRolePrompt(char)
    if not char then return end
    local cleanName = char.fullName or char.name

    if not customRolePopup then
        local cp = CreateFrame("Frame", "CLIAltsCustomRolePopup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        cp:Hide()
        cp:SetSize(380, 140)
        cp:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        cp:SetFrameStrata("FULLSCREEN_DIALOG")
        cp:EnableMouse(true)
        tinsert(UISpecialFrames, "CLIAltsCustomRolePopup")

        cp:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        local t = self:GetTheme()
        cp:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
        cp:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 1)

        local title = cp:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(title, 13, "")
        title:SetPoint("TOPLEFT", cp, "TOPLEFT", 16, -14)
        title:SetPoint("TOPRIGHT", cp, "TOPRIGHT", -16, -14)
        title:SetJustifyH("LEFT")
        cp.title = title

        local subtitle = cp:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(subtitle, 11)
        subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        subtitle:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -4)
        subtitle:SetJustifyH("LEFT")
        subtitle:SetText("Enter role (or leave empty to auto-detect professions):")
        cp.subtitle = subtitle

        local eb = CreateFrame("EditBox", "CLIAltsCustomRoleEditBox", cp)
        self:SetWidgetFont(eb, 13)
        eb:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -8)
        eb:SetPoint("RIGHT", cp, "RIGHT", -16, 0)
        eb:SetHeight(22)
        eb:SetAutoFocus(true)
        eb:EnableMouse(true)
        eb:SetTextInsets(6, 6, 2, 2)
        cp.editBox = eb

        local function SaveRole()
            local text = (eb:GetText() or ""):match("^%s*(.-)%s*$")
            if cp.targetChar then
                local charName = cp.targetChar.fullName or cp.targetChar.name or (cp.targetChar.fullName and cp.targetChar.fullName:match("^(%S+)"))
                if charName then
                    CLIAlts:SetCharacterSupplyRole(charName, text)
                    CLIAlts:ShowDossierPopup(cp.targetChar)
                    CLIAlts:RequestRender()
                end
            end
            cp:Hide()
        end

        eb:SetScript("OnEnterPressed", SaveRole)
        eb:SetScript("OnEscapePressed", function() cp:Hide() end)

        local btnSave = CreateRetroButton(cp, "[ SAVE ]", 80, 20, SaveRole)
        btnSave:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT", -90, 14)

        local btnCancel = CreateRetroButton(cp, "[ CANCEL ]", 70, 20, function() cp:Hide() end)
        btnCancel:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT", -16, 14)

        customRolePopup = cp
        self.customRolePopup = cp
    end

    customRolePopup.targetChar = char
    local t = self:GetTheme()
    customRolePopup:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
    customRolePopup:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 1)
    customRolePopup.title:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
    customRolePopup.subtitle:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
    customRolePopup.title:SetText(string.format("SET SUPPLY ROLE: %s", cleanName))
    customRolePopup.editBox:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
    customRolePopup.editBox:SetText(char.supply_role or "")
    customRolePopup:Show()
    customRolePopup.editBox:SetFocus()
    customRolePopup.editBox:HighlightText()
end

-- ----------------------------------------------------------------------------
-- Row Context Menu (Transient Modal for Alt Interactions)
-- ----------------------------------------------------------------------------
local contextMenu = nil

function CLIAlts:GetContextMenu()
    return contextMenu
end

function CLIAlts:ShowRowContextMenu(anchorFrame, charData)
    if not charData then return end

    if not contextMenu then
        local cm = CreateFrame("Frame", "CLIAltsContextMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        cm:Hide()
        cm:SetSize(216, 230)
        cm:SetFrameStrata("DIALOG")
        cm:EnableMouse(true)
        tinsert(UISpecialFrames, "CLIAltsContextMenu")

        cm:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })

        local title = cm:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(title, 11)
        title:SetPoint("TOPLEFT", cm, "TOPLEFT", 10, -8)
        title:SetPoint("TOPRIGHT", cm, "TOPRIGHT", -10, -8)
        title:SetJustifyH("LEFT")
        cm.title = title

        local sep = cm:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(sep, 10)
        sep:SetPoint("TOPLEFT", cm, "TOPLEFT", 6, -22)
        sep:SetPoint("TOPRIGHT", cm, "TOPRIGHT", -6, -22)
        sep:SetText("----------------------------------------")
        cm.sep = sep

        cm.buttons = {}
        local actions = {
            { key = "dossier", label = "1. Open Dossier", fn = function(c)
                cm:Hide()
                CLIAlts:ShowDossierPopup(c)
            end },
            { key = "core", label = "2. Set Role: Core (L35)", fn = function(c)
                cm:Hide()
                local name = c.fullName or c.name
                CLIAlts:SetCharacterCohort(name, "CORE")
                CLIAlts:Render()
            end },
            { key = "alt", label = "3. Set Role: Alt (L25)", fn = function(c)
                cm:Hide()
                local name = c.fullName or c.name
                CLIAlts:SetCharacterCohort(name, "RESERVE")
                CLIAlts:Render()
            end },
            { key = "bank", label = "4. Set Role: Bank Mule", fn = function(c)
                cm:Hide()
                local name = c.fullName or c.name
                CLIAlts:SetCharacterCohort(name, "BANK")
                CLIAlts:Render()
            end },
            { key = "route", label = "5. Configure Mail Route...", fn = function(c)
                cm:Hide()
                CLIAlts:ShowMailRouteDialog(c)
            end },
            { key = "watch", label = "6. Toggle Watchlist", fn = function(c)
                cm:Hide()
                local name = c.fullName or c.name
                if CLIAlts.ToggleWatchlist then
                    CLIAlts:ToggleWatchlist(name)
                end
                CLIAlts:Render()
            end },
            { key = "delete", label = "7. Remove Alt...", fn = function(c)
                cm:Hide()
                CLIAlts:ShowConfirmDelete(c)
            end },
            { key = "cancel", label = "8. Cancel", fn = function()
                cm:Hide()
            end },
        }

        local y = -34
        for _, act in ipairs(actions) do
            local btn = CreateFrame("Button", nil, cm, BackdropTemplateMixin and "BackdropTemplate" or nil)
            btn:SetSize(200, 20)
            btn:SetPoint("TOPLEFT", cm, "TOPLEFT", 8, y)
            btn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            btn:SetBackdropColor(0, 0, 0, 0)
            btn:SetBackdropBorderColor(0, 0, 0, 0)

            local lbl = btn:CreateFontString(nil, "OVERLAY")
            self:SetWidgetFont(lbl, 11)
            lbl:SetPoint("LEFT", btn, "LEFT", 6, 0)
            lbl:SetText(act.label)
            btn.label = lbl
            btn.actFn = act.fn
            btn.actKey = act.key

            btn:SetScript("OnEnter", function(self)
                local t = CLIAlts:GetTheme()
                self:SetBackdropColor(t.border[1], t.border[2], t.border[3], 0.35)
                self:SetBackdropBorderColor(t.highlight[1], t.highlight[2], t.highlight[3], 0.8)
                if self.actKey == "delete" then
                    self.label:SetTextColor(1, 0.4, 0.4)
                else
                    self.label:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
                end
            end)
            btn:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0, 0, 0, 0)
                self:SetBackdropBorderColor(0, 0, 0, 0)
                local t = CLIAlts:GetTheme()
                if self.actKey == "delete" then
                    self.label:SetTextColor(0.9, 0.5, 0.5)
                else
                    local txt = t.text or { 0.957, 0.918, 0.824 }
                    self.label:SetTextColor(txt[1], txt[2], txt[3])
                end
            end)
            btn:SetScript("OnClick", function(self)
                if self.actFn and cm.targetChar then
                    self.actFn(cm.targetChar)
                end
            end)

            table.insert(cm.buttons, btn)
            y = y - 23
        end

        contextMenu = cm
    end

    local t = self:GetTheme()
    contextMenu:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
    contextMenu:SetBackdropBorderColor(t.highlight[1], t.highlight[2], t.highlight[3], 1)
    contextMenu.targetChar = charData

    local charName = charData.fullName or charData.name or "Character"
    contextMenu.title:SetText(string.format("|cff%s[#] %s|r", t.highlightHex or "ffd34e", charName:upper()))
    contextMenu.sep:SetTextColor(t.dim[1], t.dim[2], t.dim[3])

    for _, btn in ipairs(contextMenu.buttons) do
        btn:SetBackdropColor(0, 0, 0, 0)
        btn:SetBackdropBorderColor(0, 0, 0, 0)
        if btn.actKey == "delete" then
            btn.label:SetTextColor(0.9, 0.5, 0.5)
        else
            local txt = t.text or { 0.957, 0.918, 0.824 }
            btn.label:SetTextColor(txt[1], txt[2], txt[3])
        end
    end

    contextMenu:ClearAllPoints()
    local uiScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    local x, y = 0, 0
    if GetCursorPosition then
        x, y = GetCursorPosition()
        x = x / uiScale
        y = y / uiScale
    end
    if anchorFrame and (x == 0 and y == 0) then
        contextMenu:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 20, 0)
    else
        contextMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + 8, y + 8)
    end
    contextMenu:Show()
end

-- ----------------------------------------------------------------------------
-- Mail Routing & Material Stream Configuration Dialog
-- ----------------------------------------------------------------------------
local mailRouteDialog = nil

function CLIAlts:GetMailRouteDialog()
    return mailRouteDialog
end

function CLIAlts:ShowMailRouteDialog(charData)
    if not charData then return end

    if not mailRouteDialog then
        local dlg = CreateFrame("Frame", "CLIAltsMailRouteDialog", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        dlg:Hide()
        dlg:SetSize(480, 360)
        dlg:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        dlg:SetFrameStrata("DIALOG")
        dlg:EnableMouse(true)
        tinsert(UISpecialFrames, "CLIAltsMailRouteDialog")

        dlg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })

        -- Title
        local title = dlg:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(title, 13, "OUTLINE")
        title:SetPoint("TOPLEFT", dlg, "TOPLEFT", 16, -14)
        dlg.title = title

        -- Subtitle (Char info)
        local subtitle = dlg:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(subtitle, 11)
        subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        dlg.subtitle = subtitle

        -- Status panel container for Current Routing & Auto Suggestion
        local statusBox = CreateFrame("Frame", nil, dlg, BackdropTemplateMixin and "BackdropTemplate" or nil)
        statusBox:SetSize(448, 70)
        statusBox:SetPoint("TOPLEFT", dlg, "TOPLEFT", 16, -56)
        statusBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        dlg.statusBox = statusBox

        local autoLabel = statusBox:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(autoLabel, 10, "")
        autoLabel:SetPoint("TOPLEFT", statusBox, "TOPLEFT", 10, -8)
        dlg.autoLabel = autoLabel

        local currentLabel = statusBox:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(currentLabel, 11, "OUTLINE")
        currentLabel:SetPoint("TOPLEFT", autoLabel, "BOTTOMLEFT", 0, -4)
        dlg.currentLabel = currentLabel

        local modeBadge = statusBox:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(modeBadge, 10, "OUTLINE")
        modeBadge:SetPoint("TOPRIGHT", statusBox, "TOPRIGHT", -10, -8)
        dlg.modeBadge = modeBadge

        -- Revert to Auto button
        local btnRevert = CreateRetroButton(statusBox, "[ REVERT TO AUTO SUGGESTION ]", 230, 20, function()
            if dlg.targetChar then
                local cName = dlg.targetChar.fullName or dlg.targetChar.name
                CLIAlts:SetCharacterSupplyRole(cName, "auto")
                CLIAlts:ShowMailRouteDialog(dlg.targetChar)
                CLIAlts:RequestRender()
            end
        end)
        btnRevert:SetPoint("BOTTOMLEFT", statusBox, "BOTTOMLEFT", 10, 8)
        dlg.btnRevert = btnRevert

        local secHeader = dlg:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(secHeader, 10, "OUTLINE")
        secHeader:SetPoint("TOPLEFT", statusBox, "BOTTOMLEFT", 0, -10)
        secHeader:SetText("ASSIGN PRESET DESTINATION STREAM:")
        dlg.secHeader = secHeader

        -- Presets container (2 columns x 5 rows)
        local presets = {
            { label = "Cloth (Tailoring)",             role = "Cloth (Tailor)" },
            { label = "Herbs (Alchemy)",                role = "Herbs (Alch)" },
            { label = "Ore & Stone (Smith / Eng)",      role = "Ore/Stone (Mining)" },
            { label = "Leather & Hides (LW)",          role = "Leather (LW)" },
            { label = "Enchanting Reagents & DE",       role = "Enchanting (DE)" },
            { label = "Cooking (Meat & Fish)",          role = "Cooking (Meat)" },
            { label = "Lockboxes (Rogue)",              role = "Lockboxes" },
            { label = "Bank Mule (General Storage)",    role = "Bank Mule" },
            { label = "Exclude (Do Not Mail)",          role = "Exclude" },
        }

        dlg.presetButtons = {}
        for pIdx, pDef in ipairs(presets) do
            local col = ((pIdx - 1) % 2)
            local row = math.floor((pIdx - 1) / 2)
            local btnX = 16 + (col * 228)
            local btnY = -152 - (row * 24)

            local pBtn = CreateRetroButton(dlg, "[ " .. pDef.label .. " ]", 220, 20, function()
                if dlg.targetChar then
                    local cName = dlg.targetChar.fullName or dlg.targetChar.name
                    CLIAlts:SetCharacterSupplyRole(cName, pDef.role)
                    CLIAlts:ShowMailRouteDialog(dlg.targetChar)
                    CLIAlts:RequestRender()
                end
            end, 10)
            pBtn:SetPoint("TOPLEFT", dlg, "TOPLEFT", btnX, btnY)
            pBtn.roleValue = pDef.role
            dlg.presetButtons[pIdx] = pBtn
        end

        -- Custom EditBox Stream Input
        local customLabel = dlg:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(customLabel, 10, "")
        customLabel:SetPoint("TOPLEFT", dlg, "TOPLEFT", 16, -276)
        customLabel:SetText("Custom stream keyword:")
        dlg.customLabel = customLabel

        local editBox = CreateFrame("EditBox", "CLIAltsMailCustomEdit", dlg, BackdropTemplateMixin and "BackdropTemplate" or nil)
        editBox:SetSize(260, 20)
        editBox:SetPoint("TOPLEFT", customLabel, "BOTTOMLEFT", 0, -4)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("GameFontHighlightSmall")
        self:SetWidgetFont(editBox, 11)
        editBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 4, right = 4, top = 2, bottom = 2 }
        })
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        dlg.editBox = editBox

        local btnSetCustom = CreateRetroButton(dlg, "[ SET CUSTOM ]", 110, 20, function()
            if dlg.targetChar and dlg.editBox then
                local txt = dlg.editBox:GetText()
                if txt and txt:gsub("%s+", "") ~= "" then
                    local cName = dlg.targetChar.fullName or dlg.targetChar.name
                    CLIAlts:SetCharacterSupplyRole(cName, txt)
                    dlg.editBox:ClearFocus()
                    CLIAlts:ShowMailRouteDialog(dlg.targetChar)
                    CLIAlts:RequestRender()
                end
            end
        end)
        btnSetCustom:SetPoint("LEFT", editBox, "RIGHT", 8, 0)
        dlg.btnSetCustom = btnSetCustom

        -- Ignored Items button
        local btnIgnored = CreateRetroButton(dlg, "[ IGNORED ITEMS ]", 140, 20, function()
            CLIAlts:ListIgnoredMailItems()
        end)
        btnIgnored:SetPoint("BOTTOMLEFT", dlg, "BOTTOMLEFT", 16, 12)
        dlg.btnIgnored = btnIgnored

        -- Bottom Close button
        local btnClose = CreateRetroButton(dlg, "[ CLOSE ]", 80, 20, function()
            dlg:Hide()
        end)
        btnClose:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -16, 12)
        dlg.btnClose = btnClose

        mailRouteDialog = dlg
    end

    local dlg = mailRouteDialog
    dlg.targetChar = charData
    local t = self:GetTheme()
    local isLegacy = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.legacyUI

    if not isLegacy then
        local bgR, bgG, bgB, bgA = self:Hex("bg")
        local lineR, lineG, lineB, lineA = self:Hex("line")
        local panelR, panelG, panelB, panelA = self:Hex("panel")
        local raisedR, raisedG, raisedB, raisedA = self:Hex("raised")
        local textR, textG, textB = self:Hex("text")

        if dlg.SetBackdropColor then dlg:SetBackdropColor(bgR, bgG, bgB, bgA) end
        if dlg.SetBackdropBorderColor then dlg:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end

        if dlg.statusBox then
            if dlg.statusBox.SetBackdropColor then dlg.statusBox:SetBackdropColor(panelR, panelG, panelB, panelA) end
            if dlg.statusBox.SetBackdropBorderColor then dlg.statusBox:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
        end

        if dlg.editBox then
            if dlg.editBox.SetBackdropColor then dlg.editBox:SetBackdropColor(raisedR, raisedG, raisedB, raisedA) end
            if dlg.editBox.SetBackdropBorderColor then dlg.editBox:SetBackdropBorderColor(lineR, lineG, lineB, lineA) end
            dlg.editBox:SetTextColor(textR, textG, textB)
        end
    else
        if dlg.SetBackdropColor then
            dlg:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
        end
        if dlg.SetBackdropBorderColor then
            dlg:SetBackdropBorderColor(t.highlight[1], t.highlight[2], t.highlight[3], 0.9)
        end

        if dlg.statusBox then
            local pBg = t.panelBg or { 0.098, 0.082, 0.047, 0.90 }
            if dlg.statusBox.SetBackdropColor then
                dlg.statusBox:SetBackdropColor(pBg[1], pBg[2], pBg[3], 0.85)
            end
            if dlg.statusBox.SetBackdropBorderColor then
                dlg.statusBox:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 0.4)
            end
        end

        if dlg.editBox then
            if dlg.editBox.SetBackdropColor then
                dlg.editBox:SetBackdropColor(0.04, 0.03, 0.02, 0.9)
            end
            if dlg.editBox.SetBackdropBorderColor then
                dlg.editBox:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 0.6)
            end
            dlg.editBox:SetTextColor(t.text[1], t.text[2], t.text[3])
        end
    end

    local cName = charData.fullName or charData.name or "Character"
    local coloredName = self:ColorizePlayerName(cName, charData.classFile)
    local tierStr = (charData.tier == "CORE" and "CORE") or (charData.tier == "RESERVE" and "ALT") or (charData.tier == "BANK" and "BANK") or "ALT"
    local lvlStr = string.format("Level %d %s [%s]", charData.level or 1, charData.class or "", tierStr)

    local profParts = {}
    if charData.professions and charData.professions.primary then
        for _, p in ipairs(charData.professions.primary) do
            table.insert(profParts, string.format("%s (%d)", p.name, p.rank or 0))
        end
    end
    local profText = (#profParts > 0) and table.concat(profParts, " · ") or "No primary professions"

    dlg.title:SetText(string.format("|cff%sCLIAlts :: MAIL ROUTING & SUPPLY CHAIN|r", t.highlightHex or "ffd34e"))
    dlg.subtitle:SetText(string.format("%s · %s · %s", coloredName, lvlStr, profText))

    local curRole, isOverride, autoRole = self:GetCharacterEffectiveSupplyRole(charData)

    dlg.autoLabel:SetText(string.format("|cff%sAuto Suggestion: %s|r", t.dimHex or "a9a08c", autoRole))
    if isOverride then
        dlg.currentLabel:SetText(string.format("Active Stream: |cff%s%s|r", t.highlightHex or "ffd34e", curRole))
        dlg.modeBadge:SetText(string.format("|cff%s[MANUAL OVERRIDE]|r", t.pendingHex or "ffb547"))
        if dlg.btnRevert then
            dlg.btnRevert:Show()
            if dlg.btnRevert.label then
                dlg.btnRevert.label:SetTextColor(t.accent[1], t.accent[2], t.accent[3])
            end
        end
    else
        dlg.currentLabel:SetText(string.format("Active Stream: |cff%s%s|r", t.textHex or "f4ead2", autoRole))
        dlg.modeBadge:SetText(string.format("|cff%s[AUTO ROUTED]|r", t.accentHex or "57d6e8"))
        if dlg.btnRevert then
            dlg.btnRevert:Hide()
        end
    end

    if dlg.editBox then
        dlg.editBox:SetText(charData.supply_role or "")
    end

    dlg:Show()
end

-- ----------------------------------------------------------------------------
-- Confirmation Modal (Delete Character)
-- ----------------------------------------------------------------------------
function CLIAlts:ShowConfirmDelete(char)
    if not char then return end

    if not confirmPopup then
        local cp = CreateFrame("Frame", "CLIAltsConfirmPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        cp:Hide()
        cp:SetSize(360, 160)
        cp:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        cp:SetFrameStrata("DIALOG")
        cp:EnableMouse(true)
        tinsert(UISpecialFrames, "CLIAltsConfirmPopup")

        cp:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        local t = self:GetTheme()
        cp:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
        cp:SetBackdropBorderColor(1, 0.2, 0.2, 1)

        local body = cp:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(body, 14)
        body:SetPoint("TOPLEFT", cp, "TOPLEFT", 16, -16)
        body:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT", -16, 45)
        body:SetJustifyH("CENTER")
        body:SetJustifyV("TOP")
        cp.body = body

        local btnConfirm = CreateRetroButton(cp, "[ YES, PURGE ]", 110, 20, function()
            if cp.onConfirm then
                cp.onConfirm()
            elseif cp.charKey then
                CLIAlts:DeleteCharacter(cp.charKey)
                CLIAlts:Render()
            end
            cp:Hide()
        end)
        btnConfirm:SetPoint("BOTTOMLEFT", cp, "BOTTOMLEFT", 40, 16)

        local btnCancel = CreateRetroButton(cp, "[ CANCEL ]", 90, 20, function()
            cp:Hide()
        end)
        btnCancel:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT", -40, 16)

        confirmPopup = cp
    end

    local cleanKey = char.fullName or char.name or char.key
    confirmPopup.charKey = cleanKey
    confirmPopup.onConfirm = nil
    local t = self:GetTheme()
    confirmPopup:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
    confirmPopup:SetBackdropBorderColor(1, 0.2, 0.2, 1)

    local msg = {
        string.format("|cff%sPURGE CHARACTER RECORD|r", t.blockedHex or "ff6b6b"),
        string.format("|cff%s%s|r", t.borderHex or "f2c94c", string.rep("-", 34)),
        "",
        "Are you sure you want to delete",
        string.format("|cff%s%s|r", t.blockedHex or "ff6b6b", cleanKey),
        "from the local CLIAlts database?",
        "",
    }
    confirmPopup.body:SetText(table.concat(msg, "\n"))
    confirmPopup:Show()
end

function CLIAlts:ShowConfirmPrunePopup(days, count, names)
    if not confirmPopup then
        self:ShowConfirmDelete({ name = "dummy" })
        confirmPopup:Hide()
    end

    local sampleStr = table.concat(names, ", ", 1, math.min(4, #names))
    if #names > 4 then
        sampleStr = sampleStr .. string.format(" (+%d more)", #names - 4)
    end

    local t = self:GetTheme()
    confirmPopup:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
    confirmPopup:SetBackdropBorderColor(1, 0.2, 0.2, 1)

    confirmPopup.charKey = nil
    confirmPopup.onConfirm = function()
        local prunedCount = CLIAlts:PruneCharacters(days)
        CLIAlts:SetPromptFeedback(string.format("Pruned %d alts inactive for %d+ days", prunedCount, days))
        CLIAlts:Render()
    end

    local msg = {
        string.format("|cff%sBULK PRUNE STALE ALTS|r", t.blockedHex or "ff6b6b"),
        string.format("|cff%s%s|r", t.borderHex or "f2c94c", string.rep("-", 34)),
        "",
        string.format("Delete |cff%s%d characters|r inactive for %d+ days?", t.blockedHex or "ff6b6b", count, days),
        string.format("|cff%s%s|r", t.pendingHex or "ffb547", sampleStr),
        "from the local CLIAlts database?",
    }
    confirmPopup.body:SetText(table.concat(msg, "\n"))
    confirmPopup:Show()
end

-- ----------------------------------------------------------------------------
-- Help / Info Modal
-- ----------------------------------------------------------------------------
function CLIAlts:ShowHelpPopup()
    if not helpPopup then
        local hp = CreateFrame("Frame", "CLIAltsHelpPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        hp:Hide()
        hp:SetSize(620, 660)
        hp:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        hp:SetFrameStrata("DIALOG")
        hp:EnableMouse(true)
        tinsert(UISpecialFrames, "CLIAltsHelpPopup")

        hp:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        local t = self:GetTheme()
        hp:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
        hp:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 1)

        local body = hp:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(body, 11)
        body:SetPoint("TOPLEFT", hp, "TOPLEFT", 16, -16)
        body:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", -16, 45)
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        hp.body = body

        local btnClose = CreateRetroButton(hp, "[ CLOSE ]", 80, 20, function()
            hp:Hide()
        end)
        btnClose:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", -16, 16)

        helpPopup = hp
    end

    local t = self:GetTheme()
    helpPopup:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
    helpPopup:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 1)

    local sep = string.rep("-", 68)
    local helpText = {
        string.format("|cff%s%s|r", t.highlightHex or "ffd34e", "CLIALTS :: QUICK GUIDE & COMMANDS"),
        string.format("|cff%s%s|r", t.borderHex or "f2c94c", sep),
        string.format("|cff%sSlash Commands:|r", t.primaryHex or "f2c94c"),
        "  /clialts            - Toggle the main TUI monitor",
        "  /clialts [1-5]      - Open directly to specific tab (1-5)",
        "  /clialts compact    - Toggle compact view (hide XP bar, slim)",
        "  /clialts next       - Recommend top 3 alts with rested XP waste",
        "  /clialts watch <it> - Track item count in bags & bank (e.g. ore)",
        "  /clialts watchlist  - Print tracked items summary",
        "  /clialts export     - Open CSV export dialog for spreadsheets",
        "  /clialts scale <val>- Set UI scale (0.7 to 1.8, e.g. 1.2 / 120%)",
        "  /clialts font <sz>  - Set terminal font size (12 to 22)",
        "  /clialts track      - Force save current character to tracker",
        "  /clialts rested     - Print quick rested XP report to chat",
        "  /clialts perk <0-5> - Set Well Rested legacy perk rank (0-5)",
        "  /clialts gold       - Print total account gold summary",
        "  /clialts perf       - Print smoothed Collect/Render ms & memory",
        "  /clialts selftest   - Run unit assertions with fake timestamps",
        "  /clialts alerts     - Toggle login alert categories (cd/rest/mail)",
        "  /clialts digest     - Display boxed login summary digest now",
        "  /clialts plan [hrs] - Print leveling plan schedule (default: 2h)",
        "  /clialts note <who> <txt> - Set/view alt note (clear to remove)",
        "  /clialts unlocked <inst> - List alts with no active lock (gap finder)",
        "  /clialts prune <days> [confirm] - Bulk purge alts inactive for N days",
        "  /clialts tooltips   - Toggle item hover tooltips (bags/bank alts)",
        "  /clialts sortbags   - Auto-sort inventory & stack items (/sortbags)",
        "  /clialts sortbtn    - Toggle [S] bag sort button on backpack",
        "  /clialts fillmail   - Auto-fill next alt mail & attach items (/fillmail)",
        "  /clialts mailbtn    - Toggle auto-fill button on Send Mail frame",
        "  /clialts mailignore <item> - Exclude item from auto-mail (or hold on cursor)",
        "  /clialts mailunignore <item> - Remove item from mail ignore list",
        "  /clialts mailignores - List all currently ignored items for mail",
        "  /clialts forever    - Toggle WoW Forever Cohort mode (auto-active)",
        "  /clialts core <who> - Set Core cohort (Target Level 35)",
        "  /clialts alt <who>  - Set Alt/Reserve cohort (Target Level 25)",
        "  /clialts bank <who> - Set Bank mule (Target Level 1)",
        "  /clialts prof       - Print profession milestones & train alerts",
        "  /clialts backup     - Save one-slot snapshot to CLIAltsDB.backup",
        "  /clialts restore    - Restore database from CLIAltsDB.backup",
        "  /clialts reset      - Reset window position to center",
        string.format("|cff%s%s|r", t.mutedHex or "a9a08c", sep),
        string.format("|cff%sInteractive Terminal Command Prompt (>):|r", t.primaryHex or "f2c94c"),
        "  > 1 .. 5            - Switch tab (Overview, Rest, Prof, Econ, Cd)",
        "  > compact           - Toggle compact view (hide XP bar, slim)",
        "  > sort <column>     - Sort table (name, lvl, cohort, gold, rest)",
        "  > filter <query>    - Filter alts (alliance, horde, stale, <60)",
        "  > find <text>       - Search character names, classes, or zones",
        "  > clear             - Clear active filter query",
        "  > next              - Print alts with highest rested waste",
        "  > watch <item>      - Add item to bag/bank inventory tracker",
        "  > tooltips / inv    - Toggle item hover tooltips (bags/bank alts)",
        "  > sortbags          - Auto-sort inventory & consolidate stacks",
        "  > sortbtn           - Toggle [S] button on backpack window",
        "  > fillmail          - Auto-fill next alt mail package & attach items",
        "  > mailbtn           - Toggle mail auto-fill button on mailbox",
        "  > core <who> [tgt]  - Set Core cohort (Target 35)",
        "  > alt <who> [tgt]   - Set Alt/Reserve cohort (Target 25)",
        "  > bank <who>        - Set Bank mule (Target 1)",
        "  > unassign <who>    - Unassign cohort / restore Target 60",
        "  > export            - Open CSV export modal dialog",
        "  > theme [name]      - Cycle or set color theme (incl. safe/cb)",
        "  > perf              - Output profiling exponential moving average",
        "  > selftest          - Execute automated test suite in chat",
        "  > alerts [cat]      - Configure login alert category toggles",
        "  > digest            - Render boxed login alert digest in chat",
        "  > plan [hours]      - Compute ordered leveling session schedule",
        "  > note <who> <text> - Set/view alt note (e.g. farm mooncloth)",
        "  > unlocked <inst>   - List alts with no active lock (gap finder)",
        "  > prune <days>      - Bulk purge alts inactive for N days",
        "  > backup / restore  - Create database snapshot or roll back",
        "  > Up / Down arrows  - Browse terminal command history",
        "  > Tab key           - Auto-complete commands and column names",
        string.format("|cff%s%s|r", t.mutedHex or "a9a08c", sep),
        string.format("|cff%sInteractions:|r", t.primaryHex or "f2c94c"),
        "  - Click [COMPACT] on title bar or type > compact in prompt",
        "  - Click [SCALE] on title bar to cycle 100%, 115%, 130%, 145%, 90%",
        "  - Click [THEME] on title bar to cycle CRT retro color palettes",
        "  - Click column title in header line to sort ascending/descending",
        "  - Left-Click any character row to inspect full Dossier",
        "  - Shift-Click any character row to cycle Cohort (Core/Alt/Bank)",
        "  - Right-Click any character row to delete character record",
        "  - Mouse wheel over table to scroll pages",
        "  - Drag Minimap icon to move outside of minimap",
        string.format("|cff%s%s|r", t.mutedHex or "a9a08c", sep),
    }
    if self:IsRetail() then
        table.insert(helpText, string.format("|cff%sRested XP Mechanics (Retail):|r", t.primaryHex or "f2c94c"))
        table.insert(helpText, "  - Resting in Inn/City/Camp: +5% of level every 8h (10 days base)")
        table.insert(helpText, "  - Logged in Wilderness:     +1.25% every 8h (40 days base)")
        table.insert(helpText, "  - Maximum Rested Cap:       150% of level (1.5 bars)")
    else
        table.insert(helpText, string.format("|cff%sRested XP Mechanics (WoW Forever):|r", t.primaryHex or "f2c94c"))
        table.insert(helpText, "  - Resting in Inn/City/Camp: +5% of level every 8h (10 days base)")
        table.insert(helpText, "  - Logged in Wilderness:     +1.25% every 8h (40 days base)")
        table.insert(helpText, "  - Well Rested Legacy Perk:  +4% speed & +4% cap per rank (max 5)")
    end
    table.insert(helpText, string.format("|cff%s%s|r", t.borderHex or "f2c94c", sep))

    helpPopup.body:SetText(table.concat(helpText, "\n"))
    helpPopup:Show()
end

-- ----------------------------------------------------------------------------
-- CSV Export Modal (Copyable Multi-Line Dialog)
-- ----------------------------------------------------------------------------
function CLIAlts:ShowExportPopup()
    if not exportPopup then
        local ep = CreateFrame("Frame", "CLIAltsExportPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        ep:Hide()
        ep:SetSize(640, 440)
        ep:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        ep:SetFrameStrata("DIALOG")
        ep:EnableMouse(true)
        tinsert(UISpecialFrames, "CLIAltsExportPopup")

        ep:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        local t = self:GetTheme()
        ep:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
        ep:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 1)

        local title = ep:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(title, 14, "OUTLINE")
        title:SetPoint("TOPLEFT", ep, "TOPLEFT", 16, -14)
        title:SetText("CLIALTS :: CSV EXPORT (PRESS CTRL+C TO COPY)")
        ep.title = title

        local scrollFrame = CreateFrame("ScrollFrame", "CLIAltsExportScrollFrame", ep, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", ep, "TOPLEFT", 16, -42)
        scrollFrame:SetPoint("BOTTOMRIGHT", ep, "BOTTOMRIGHT", -36, 45)

        local editBox = CreateFrame("EditBox", "CLIAltsExportEditBox", scrollFrame)
        self:SetWidgetFont(editBox, 12)
        editBox:SetWidth(580)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:EnableMouse(true)
        editBox:SetScript("OnEscapePressed", function() ep:Hide() end)
        scrollFrame:SetScrollChild(editBox)
        ep.editBox = editBox

        local btnSelectAll = CreateRetroButton(ep, "[ SELECT ALL ]", 110, 20, function()
            if ep.editBox then
                ep.editBox:SetFocus()
                ep.editBox:HighlightText()
            end
        end)
        btnSelectAll:SetPoint("BOTTOMLEFT", ep, "BOTTOMLEFT", 16, 14)

        local btnClose = CreateRetroButton(ep, "[ CLOSE ]", 80, 20, function()
            ep:Hide()
        end)
        btnClose:SetPoint("BOTTOMRIGHT", ep, "BOTTOMRIGHT", -16, 14)

        exportPopup = ep
    end

    local t = self:GetTheme()
    exportPopup:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
    exportPopup:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 1)
    if exportPopup.title then
        exportPopup.title:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
    end
    if exportPopup.editBox then
        exportPopup.editBox:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
        local csv = self:GenerateExportCSV()
        exportPopup.editBox:SetText(csv or "")
    end

    exportPopup:Show()
    if exportPopup.editBox then
        exportPopup.editBox:SetFocus()
        exportPopup.editBox:HighlightText()
    end
end

-- ----------------------------------------------------------------------------
-- Interactive Settings & Preferences Modal Dialog
-- ----------------------------------------------------------------------------
function CLIAlts:GetSettingsDialog()
    return settingsDialog
end

function CLIAlts:ShowSettingsDialog()
    if not settingsDialog then
        local sd = CreateFrame("Frame", "CLIAltsSettingsDialog", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        sd:Hide()
        sd:SetSize(680, 520)
        sd:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        sd:SetFrameStrata("DIALOG")
        sd:EnableMouse(true)
        sd:SetMovable(true)
        sd:RegisterForDrag("LeftButton")
        sd:SetScript("OnDragStart", function(self) self:StartMoving() end)
        sd:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        tinsert(UISpecialFrames, "CLIAltsSettingsDialog")

        sd:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })

        -- Title & Subtitle
        local title = sd:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(title, 15, "OUTLINE")
        title:SetPoint("TOPLEFT", sd, "TOPLEFT", 20, -16)
        title:SetText("CLIALTS :: SETTINGS & PREFERENCES")
        sd.title = title

        local sub = sd:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(sub, 12, "")
        sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        sub:SetText("Configure visual themes, typography size, UI scale, and addon automations.")
        sd.sub = sub

        local topClose = CreateRetroButton(sd, "[X]", 32, 20, function()
            sd:Hide()
        end)
        topClose:SetPoint("TOPRIGHT", sd, "TOPRIGHT", -16, -16)
        sd.topClose = topClose

        -- Section 1: Themes
        local secTheme = sd:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(secTheme, 13, "OUTLINE")
        secTheme:SetPoint("TOPLEFT", sd, "TOPLEFT", 20, -68)
        secTheme:SetText("[ COLOR THEMES ]")
        sd.secTheme = secTheme

        local themes = {
            { key = "BLIZZARD", name = "Blizzard Gold" },
            { key = "AMBER", name = "VT220 Amber" },
            { key = "GREEN", name = "Phosphor CRT" },
            { key = "CYAN", name = "Cyberdeck Cyan" },
            { key = "MONO", name = "Monochrome" },
            { key = "COLORBLIND", name = "Phosphor Safe" },
            { key = "SYNTHWAVE", name = "Synthwave CRT" },
            { key = "DRACULA", name = "Dracula Terminal" },
        }
        sd.themeButtons = {}
        for i, info in ipairs(themes) do
            local col = (i - 1) % 4
            local row = math.floor((i - 1) / 4)
            local btn = CreateRetroButton(sd, info.name, 150, 24, function()
                CLIAltsDB.settings = CLIAltsDB.settings or {}
                CLIAltsDB.settings.theme = info.key
                CLIAltsDB.settings.themeExplicit = true
                CLIAlts:ApplyTheme()
                CLIAlts:Render()
                CLIAlts:UpdateSettingsDialog()
            end, 11)
            btn:SetPoint("TOPLEFT", sd, "TOPLEFT", 20 + (col * 160), -92 - (row * 30))
            btn.themeKey = info.key
            btn.themeName = info.name
            table.insert(sd.themeButtons, btn)
        end

        -- Section 2: Terminal Font Size
        local secFont = sd:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(secFont, 13, "OUTLINE")
        secFont:SetPoint("TOPLEFT", sd, "TOPLEFT", 20, -164)
        secFont:SetText("[ TERMINAL FONT SIZE ]")
        sd.secFont = secFont

        local fontSizes = { 12, 14, 16, 18, 20, 22, 24 }
        sd.fontButtons = {}
        for i, sz in ipairs(fontSizes) do
            local label = (sz == 18) and string.format("%dpx*", sz) or string.format("%dpx", sz)
            local btn = CreateRetroButton(sd, label, 85, 24, function()
                CLIAlts:SetFontSize(sz)
                CLIAlts:UpdateSettingsDialog()
            end, 11)
            btn:SetPoint("TOPLEFT", sd, "TOPLEFT", 20 + ((i - 1) * 92), -188)
            btn.fontSize = sz
            table.insert(sd.fontButtons, btn)
        end

        -- Section 3: Display Scale
        local secScale = sd:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(secScale, 13, "OUTLINE")
        secScale:SetPoint("TOPLEFT", sd, "TOPLEFT", 20, -224)
        secScale:SetText("[ DISPLAY SCALE ]")
        sd.secScale = secScale

        local scaleList = { 0.8, 0.9, 1.0, 1.15, 1.3, 1.45 }
        sd.scaleButtons = {}
        for i, sc in ipairs(scaleList) do
            local pct = math.floor(sc * 100 + 0.5)
            local label = (math.abs(sc - 1.0) < 0.05) and string.format("%d%%*", pct) or string.format("%d%%", pct)
            local btn = CreateRetroButton(sd, label, 100, 24, function()
                CLIAlts:SetScale(sc)
                CLIAlts:Render()
                CLIAlts:UpdateSettingsDialog()
            end, 11)
            btn:SetPoint("TOPLEFT", sd, "TOPLEFT", 20 + ((i - 1) * 108), -248)
            btn.scaleVal = sc
            table.insert(sd.scaleButtons, btn)
        end

        -- Section 4: Interface & Automation Toggles
        local secToggles = sd:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(secToggles, 13, "OUTLINE")
        secToggles:SetPoint("TOPLEFT", sd, "TOPLEFT", 20, -284)
        secToggles:SetText("[ INTERFACE & AUTOMATION ]")
        sd.secToggles = secToggles

        -- Col 1 toggles (x = 20, width = 310)
        local btnAudio = CreateRetroButton(sd, "Audio SFX: ENABLED", 310, 26, function()
            CLIAltsDB.settings = CLIAltsDB.settings or {}
            CLIAltsDB.settings.soundDisabled = not CLIAltsDB.settings.soundDisabled
            CLIAlts:UpdateSettingsDialog()
        end, 11)
        btnAudio:SetPoint("TOPLEFT", sd, "TOPLEFT", 20, -308)
        sd.btnAudio = btnAudio

        local btnSort = CreateRetroButton(sd, "Bag Sort Button: ENABLED", 310, 26, function()
            local cur = not (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.showBagSortButton == false)
            CLIAlts:ToggleBagSortButton(not cur)
            CLIAlts:UpdateSettingsDialog()
        end, 11)
        btnSort:SetPoint("TOPLEFT", sd, "TOPLEFT", 20, -338)
        sd.btnSort = btnSort

        local btnTip = CreateRetroButton(sd, "Cross-Alt Tooltips: ENABLED", 310, 26, function()
            CLIAltsDB.settings = CLIAltsDB.settings or {}
            CLIAltsDB.settings.showInventoryTooltips = (CLIAltsDB.settings.showInventoryTooltips == false)
            CLIAlts:UpdateSettingsDialog()
        end, 11)
        btnTip:SetPoint("TOPLEFT", sd, "TOPLEFT", 20, -368)
        sd.btnTip = btnTip

        -- Col 2 toggles (x = 345, width = 310)
        local btnMail = CreateRetroButton(sd, "Mail Auto-Fill: ENABLED", 310, 26, function()
            local cur = not (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.showMailAutoFillButton == false)
            CLIAlts:ToggleMailAutoFillButton(not cur)
            CLIAlts:UpdateSettingsDialog()
        end, 11)
        btnMail:SetPoint("TOPLEFT", sd, "TOPLEFT", 345, -308)
        sd.btnMail = btnMail

        local btnCons = CreateRetroButton(sd, "Route Consumables: DISABLED", 310, 26, function()
            CLIAltsDB.settings = CLIAltsDB.settings or {}
            CLIAltsDB.settings.autoMailConsumables = not CLIAltsDB.settings.autoMailConsumables
            CLIAlts:UpdateSettingsDialog()
        end, 11)
        btnCons:SetPoint("TOPLEFT", sd, "TOPLEFT", 345, -338)
        sd.btnCons = btnCons

        local btnMode = CreateRetroButton(sd, "UI Style: Modern v2", 310, 26, function()
            CLIAltsDB.settings = CLIAltsDB.settings or {}
            CLIAltsDB.settings.legacyUI = not CLIAltsDB.settings.legacyUI
            if CLIAlts.RecreateMainFrame then
                local wasShown = mainFrame and mainFrame:IsShown()
                CLIAlts:RecreateMainFrame()
                if wasShown and mainFrame then
                    mainFrame:Show()
                    CLIAlts:Render()
                end
            end
            CLIAlts:UpdateSettingsDialog()
        end, 11)
        btnMode:SetPoint("TOPLEFT", sd, "TOPLEFT", 345, -368)
        sd.btnMode = btnMode

        -- Tip Note
        local tip = sd:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(tip, 11, "")
        tip:SetPoint("TOPLEFT", sd, "TOPLEFT", 20, -408)
        tip:SetText("Tip: Chat commands /clialts theme <name>, /clialts font <12-24>, /clialts scale <val> also work.")
        sd.tip = tip

        -- Bottom utility buttons
        local btnCenter = CreateRetroButton(sd, "[ Center Window ]", 150, 26, function()
            if mainFrame then
                mainFrame:ClearAllPoints()
                mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                if CLIAltsDB and CLIAltsDB.settings then
                    CLIAltsDB.settings.windowPos = nil
                end
                CLIAlts:Print("Main window centered on screen.")
            end
        end, 11)
        btnCenter:SetPoint("BOTTOMLEFT", sd, "BOTTOMLEFT", 20, 18)
        sd.btnCenter = btnCenter

        local btnReset = CreateRetroButton(sd, "[ Reset Defaults ]", 140, 26, function()
            CLIAltsDB.settings = CLIAltsDB.settings or {}
            CLIAltsDB.settings.theme = "BLIZZARD"
            CLIAltsDB.settings.themeExplicit = true
            CLIAlts:SetScale(1.0)
            CLIAlts:SetFontSize(18)
            CLIAlts:ApplyTheme()
            CLIAlts:Render()
            CLIAlts:UpdateSettingsDialog()
            CLIAlts:Print("Visual settings reset to defaults.")
        end, 11)
        btnReset:SetPoint("LEFT", btnCenter, "RIGHT", 12, 0)
        sd.btnReset = btnReset

        local btnClose = CreateRetroButton(sd, "[ Close ]", 90, 26, function()
            sd:Hide()
        end, 11)
        btnClose:SetPoint("BOTTOMRIGHT", sd, "BOTTOMRIGHT", -20, 18)
        sd.btnClose = btnClose

        settingsDialog = sd
    end

    self:UpdateSettingsDialog()
    settingsDialog:Show()
end

function CLIAlts:UpdateSettingsDialog()
    if not settingsDialog then return end
    local t = self:GetTheme()

    if settingsDialog.SetBackdropColor then
        settingsDialog:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
    end
    if settingsDialog.SetBackdropBorderColor then
        settingsDialog:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 1)
    end

    if settingsDialog.title then settingsDialog.title:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3]) end
    if settingsDialog.sub then settingsDialog.sub:SetTextColor(t.dim[1], t.dim[2], t.dim[3]) end
    if settingsDialog.secTheme then settingsDialog.secTheme:SetTextColor(t.primary[1], t.primary[2], t.primary[3]) end
    if settingsDialog.secFont then settingsDialog.secFont:SetTextColor(t.primary[1], t.primary[2], t.primary[3]) end
    if settingsDialog.secScale then settingsDialog.secScale:SetTextColor(t.primary[1], t.primary[2], t.primary[3]) end
    if settingsDialog.secToggles then settingsDialog.secToggles:SetTextColor(t.primary[1], t.primary[2], t.primary[3]) end
    if settingsDialog.tip then settingsDialog.tip:SetTextColor(t.dim[1], t.dim[2], t.dim[3]) end

    -- Theme buttons
    local curTheme = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.theme) or "BLIZZARD"
    for _, btn in ipairs(settingsDialog.themeButtons or {}) do
        local isSel = (btn.themeKey == curTheme)
        btn.isSelected = isSel
        btn.label:SetText(string.format("%s %s", isSel and "[●]" or "[ ]", btn.themeName or ""))
        if isSel then
            btn.label:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
            if btn.SetBackdropBorderColor then btn:SetBackdropBorderColor(t.primary[1], t.primary[2], t.primary[3], 1) end
            if btn.SetBackdropColor then btn:SetBackdropColor(t.border[1], t.border[2], t.border[3], 0.35) end
        else
            btn.label:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
            if btn.SetBackdropBorderColor then btn:SetBackdropBorderColor(t.dim[1], t.dim[2], t.dim[3], 0.4) end
            local pBg = t.panelBg or { 0.098, 0.082, 0.047, 0.90 }
            if btn.SetBackdropColor then btn:SetBackdropColor(pBg[1], pBg[2], pBg[3], 0.75) end
        end
    end

    -- Font size buttons
    local curFont = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.fontSize) or 18
    for _, btn in ipairs(settingsDialog.fontButtons or {}) do
        local isSel = (btn.fontSize == curFont)
        btn.isSelected = isSel
        local base = (btn.fontSize == 18) and string.format("%dpx*", btn.fontSize) or string.format("%dpx", btn.fontSize)
        btn.label:SetText(string.format("%s %s", isSel and "[●]" or "[ ]", base))
        if isSel then
            btn.label:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
            if btn.SetBackdropBorderColor then btn:SetBackdropBorderColor(t.primary[1], t.primary[2], t.primary[3], 1) end
            if btn.SetBackdropColor then btn:SetBackdropColor(t.border[1], t.border[2], t.border[3], 0.35) end
        else
            btn.label:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
            if btn.SetBackdropBorderColor then btn:SetBackdropBorderColor(t.dim[1], t.dim[2], t.dim[3], 0.4) end
            local pBg = t.panelBg or { 0.098, 0.082, 0.047, 0.90 }
            if btn.SetBackdropColor then btn:SetBackdropColor(pBg[1], pBg[2], pBg[3], 0.75) end
        end
    end

    -- Scale buttons
    local curScale = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.scale) or 1.0
    for _, btn in ipairs(settingsDialog.scaleButtons or {}) do
        local isSel = (math.abs(btn.scaleVal - curScale) < 0.05)
        btn.isSelected = isSel
        local pct = math.floor(btn.scaleVal * 100 + 0.5)
        local base = (math.abs(btn.scaleVal - 1.0) < 0.05) and string.format("%d%%*", pct) or string.format("%d%%", pct)
        btn.label:SetText(string.format("%s %s", isSel and "[●]" or "[ ]", base))
        if isSel then
            btn.label:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
            if btn.SetBackdropBorderColor then btn:SetBackdropBorderColor(t.primary[1], t.primary[2], t.primary[3], 1) end
            if btn.SetBackdropColor then btn:SetBackdropColor(t.border[1], t.border[2], t.border[3], 0.35) end
        else
            btn.label:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
            if btn.SetBackdropBorderColor then btn:SetBackdropBorderColor(t.dim[1], t.dim[2], t.dim[3], 0.4) end
            local pBg = t.panelBg or { 0.098, 0.082, 0.047, 0.90 }
            if btn.SetBackdropColor then btn:SetBackdropColor(pBg[1], pBg[2], pBg[3], 0.75) end
        end
    end

    -- Toggles
    local sfxOn = not (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.soundDisabled)
    if settingsDialog.btnAudio then
        settingsDialog.btnAudio.label:SetText(string.format("Audio SFX: %s", sfxOn and "|cff00ff66ENABLED|r" or "|cffff4444MUTED|r"))
    end

    local sortOn = not (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.showBagSortButton == false)
    if settingsDialog.btnSort then
        settingsDialog.btnSort.label:SetText(string.format("Bag Sort Button: %s", sortOn and "|cff00ff66ENABLED|r" or "|cffff4444DISABLED|r"))
    end

    local tipOn = not (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.showInventoryTooltips == false)
    if settingsDialog.btnTip then
        settingsDialog.btnTip.label:SetText(string.format("Cross-Alt Tooltips: %s", tipOn and "|cff00ff66ENABLED|r" or "|cffff4444DISABLED|r"))
    end

    local mailOn = not (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.showMailAutoFillButton == false)
    if settingsDialog.btnMail then
        settingsDialog.btnMail.label:SetText(string.format("Mail Auto-Fill: %s", mailOn and "|cff00ff66ENABLED|r" or "|cffff4444DISABLED|r"))
    end

    local consOn = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.autoMailConsumables == true)
    if settingsDialog.btnCons then
        settingsDialog.btnCons.label:SetText(string.format("Route Consumables: %s", consOn and "|cff00ff66ON (Active)|r" or "|cffffb033OFF (Protected)|r"))
    end

    local isLegacy = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.legacyUI == true)
    if settingsDialog.btnMode then
        settingsDialog.btnMode.label:SetText(string.format("UI Style: %s", isLegacy and "|cffffd100Classic Retro Table|r" or "|cff33d9ffModern v2 (Cards)|r"))
    end
end

-- ----------------------------------------------------------------------------
-- Window Toggle & Refresh
-- ----------------------------------------------------------------------------
function CLIAlts:Toggle(show)
    local ok, err = pcall(function()
        if not mainFrame then
            mainFrame = self:CreateMainFrame()
        end
        if not mainFrame then return end

        if show == nil then
            if mainFrame:IsShown() then
                mainFrame:Hide()
            else
                self:CollectCurrentCharacter()
                self:ApplyTheme()
                mainFrame:Show()
                self:Render()
                PlayRetroSound()
            end
        elseif show then
            self:CollectCurrentCharacter()
            self:ApplyTheme()
            mainFrame:Show()
            self:Render()
            PlayRetroSound()
        else
            mainFrame:Hide()
            PlayRetroSound()
        end
    end)
    if not ok then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff3333[CLIAlts]|r UI Toggle error: %s", tostring(err)))
        end
    end
end

function CLIAlts:Refresh()
    local ok, err = pcall(function()
        self:CollectCurrentCharacter()
        self:ApplyTheme()
        self:Render()
        self:Print("Database refreshed.")
    end)
    if not ok then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff3333[CLIAlts]|r Refresh error: %s", tostring(err)))
        end
    end
end

-- ----------------------------------------------------------------------------
-- Cross-Character Inventory Tooltip Hooks & Formatter (Feature 6)
-- ----------------------------------------------------------------------------
function CLIAlts:AddInventoryInfoToTooltip(tooltip, itemID)
    if not tooltip or not itemID then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if not CLIAltsDB or not CLIAltsDB.settings or CLIAltsDB.settings.showInventoryTooltips == false then
        return
    end

    -- Guard against duplicate additions within the same tooltip rendering pass
    self.processedTooltips = self.processedTooltips or setmetatable({}, { __mode = "k" })
    if self.processedTooltips[tooltip] == itemID or tooltip._clialtsProcessed == itemID then
        return
    end

    -- Check if the tooltip already has CLIAlts lines to prevent stacking
    local numLines = (tooltip.NumLines and tooltip:NumLines()) or 0
    if numLines > 0 and tooltip.GetName then
        local tipName = tooltip:GetName()
        if tipName then
            for i = 1, numLines do
                local line = _G[tipName .. "TextLeft" .. i]
                local text = line and line:GetText()
                if text and text:find("%[CLIAlts%]") then
                    self.processedTooltips[tooltip] = itemID
                    return
                end
            end
        end
    end

    local didAdd = false

    local totalCount, breakdown = self:GetItemInventorySummary(itemID)
    if totalCount > 0 and breakdown and #breakdown > 0 then
        tooltip:AddDoubleLine("|cff00ff66[CLIAlts] Alts with Item:|r", string.format("|cffffffffTotal: %d|r", totalCount))
        for _, entry in ipairs(breakdown) do
            local _, _, _, colorHex = self:GetClassColor(entry.classFile)
            colorHex = colorHex or "ffffff"
            local nameStr = string.format("|cff%s%s|r", colorHex, entry.name)
            if entry.isCurrent then
                nameStr = nameStr .. " |cff888888(you)|r"
            elseif entry.realm and self.curPlayerRealm and entry.realm ~= self.curPlayerRealm then
                nameStr = nameStr .. string.format(" |cff888888(%s)|r", entry.realm)
            end

            local countDetail
            if entry.bag > 0 and entry.bank > 0 then
                countDetail = string.format("%d (Bags: %d, Bank: %d)", entry.total, entry.bag, entry.bank)
            elseif entry.bag > 0 then
                countDetail = string.format("%d (Bags)", entry.bag)
            else
                countDetail = string.format("%d (Bank)", entry.bank)
            end

            tooltip:AddDoubleLine("  " .. nameStr, string.format("|cffffd700%s|r", countDetail))
        end
        didAdd = true
    end

    if self.GetMaterialDestination then
        local isIgnored = self.IsItemMailIgnored and self:IsItemMailIgnored(itemID)
        if isIgnored then
            tooltip:AddDoubleLine("|cff57d6e8[Mail Router]|r Status:", "|cffff4444IGNORED (Not Mailed)|r")
            didAdd = true
        else
            local dest = self:GetMaterialDestination(itemID)
            if dest and not dest.isCurrentPlayer and not self:IsCurrentPlayer(dest.destName) and not self:IsCurrentPlayer(dest.destChar) then
                local _, _, _, cHex = self:GetClassColor(dest.classFile)
                cHex = cHex or "55e39a"
                tooltip:AddDoubleLine("|cff57d6e8[Mail Router]|r Send to:", string.format("|cff%s%s|r (|cffffd700%s|r)", cHex, dest.destName, dest.reason))
                didAdd = true
            end
        end
    end

    if didAdd then
        self.processedTooltips[tooltip] = itemID
        if type(tooltip) == "table" and not tooltip.GetName then
            tooltip._clialtsProcessed = itemID
        end
    end
end

function CLIAlts:InitTooltipHooks()
    if self.tooltipHooksInitialized then return end
    self.tooltipHooksInitialized = true

    local function ResetTooltipFlag(tooltip)
        if tooltip then
            if self.processedTooltips then
                self.processedTooltips[tooltip] = nil
            end
            if type(tooltip) == "table" and not tooltip.GetName then
                tooltip._clialtsProcessed = nil
            end
        end
    end

    if GameTooltip and GameTooltip.HookScript then
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipCleared", ResetTooltipFlag)
    end
    if ItemRefTooltip and ItemRefTooltip.HookScript then
        pcall(ItemRefTooltip.HookScript, ItemRefTooltip, "OnTooltipCleared", ResetTooltipFlag)
    end

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if InCombatLockdown and InCombatLockdown() then return end
            if not tooltip or not data then return end
            local itemID = data.id
            if not itemID and tooltip.GetItem then
                local _, link = tooltip:GetItem()
                if link then itemID = tonumber(link:match("item:(%d+)")) end
            end
            if itemID then
                pcall(function() CLIAlts:AddInventoryInfoToTooltip(tooltip, itemID) end)
            end
        end)
    else
        local function OnTooltipSetItem(tooltip)
            if InCombatLockdown and InCombatLockdown() then return end
            if not tooltip or not tooltip.GetItem then return end
            local _, link = tooltip:GetItem()
            if link then
                local itemID = tonumber(link:match("item:(%d+)"))
                if itemID then
                    pcall(function() CLIAlts:AddInventoryInfoToTooltip(tooltip, itemID) end)
                end
            end
        end

        if GameTooltip and GameTooltip.HookScript then
            pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", OnTooltipSetItem)
        end
        if ItemRefTooltip and ItemRefTooltip.HookScript then
            pcall(ItemRefTooltip.HookScript, ItemRefTooltip, "OnTooltipSetItem", OnTooltipSetItem)
        end
    end
end

-- ----------------------------------------------------------------------------
-- Bag Auto-Sort Button Integration (ContainerFrame1 / Combined Bags)
-- ----------------------------------------------------------------------------
function CLIAlts:ApplyThemeToBagButton()
    local btn = self.bagSortButton
    if not btn then return end
    local t = self:GetTheme()
    if btn.SetBackdropBorderColor then
        btn:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 0.9)
    end
    if btn.label then
        btn.label:SetText(string.format("|cff%s[S]|r", t.highlightHex or "f2c94c"))
    end
end

function CLIAlts:UpdateBagSortButtonAnchor(testCombinedFrame, testSingleFrame)
    if InCombatLockdown and InCombatLockdown() then return end
    local btn = self.bagSortButton
    if not btn then return end
    if CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.showBagSortButton == false then
        btn:Hide()
        return
    end

    local combinedFrame = testCombinedFrame or rawget(_G, "ContainerFrameCombinedBags")
    local singleFrame = testSingleFrame or rawget(_G, "ContainerFrame1")

    -- Safely hook container frame OnShow/OnHide so bag toggling updates button immediately
    self.hookedBagFrames = self.hookedBagFrames or {}
    local function HookContainerFrame(f)
        if f and f.HookScript and not self.hookedBagFrames[f] then
            self.hookedBagFrames[f] = true
            pcall(f.HookScript, f, "OnShow", function()
                if InCombatLockdown and InCombatLockdown() then return end
                CLIAlts:UpdateBagSortButtonAnchor()
            end)
            pcall(f.HookScript, f, "OnHide", function()
                if InCombatLockdown and InCombatLockdown() then return end
                CLIAlts:UpdateBagSortButtonAnchor()
            end)
        end
    end

    if not testCombinedFrame and combinedFrame then HookContainerFrame(combinedFrame) end
    if not testSingleFrame and singleFrame then HookContainerFrame(singleFrame) end

    local combinedShown = combinedFrame and ((combinedFrame.IsVisible and combinedFrame:IsVisible()) or (combinedFrame.IsShown and combinedFrame:IsShown()))
    local singleShown = singleFrame and ((singleFrame.IsVisible and singleFrame:IsVisible()) or (singleFrame.IsShown and singleFrame:IsShown()))

    local targetParent
    local isCombined

    if combinedShown then
        targetParent = combinedFrame
        isCombined = true
    elseif singleShown then
        targetParent = singleFrame
        isCombined = false
    else
        -- Check CVar setting to pre-anchor to expected frame
        local cvar = (GetCVar and GetCVar("combinedBags")) or (GetCVarBool and GetCVarBool("combinedBags") and "1" or "0")
        if cvar == "1" and combinedFrame then
            targetParent = combinedFrame
            isCombined = true
        else
            targetParent = singleFrame or combinedFrame
            isCombined = (targetParent == combinedFrame)
        end
    end

    if not targetParent then return end

    local closeBtn
    if isCombined and combinedFrame then
        closeBtn = combinedFrame.CloseButton
            or (combinedFrame.TitleContainer and combinedFrame.TitleContainer.CloseButton)
            or rawget(_G, "ContainerFrameCombinedBagsCloseButton")
    elseif singleFrame then
        closeBtn = singleFrame.CloseButton
            or (singleFrame.TitleContainer and singleFrame.TitleContainer.CloseButton)
            or rawget(_G, "ContainerFrame1CloseButton")
    end

    btn.anchorTarget = targetParent
    btn:SetParent(targetParent)

    btn:ClearAllPoints()
    if closeBtn then
        btn:SetPoint("RIGHT", closeBtn, "LEFT", -3, 0)
    else
        btn:SetPoint("TOPRIGHT", targetParent, "TOPRIGHT", -28, -6)
    end

    local strata = (targetParent.GetFrameStrata and targetParent:GetFrameStrata()) or "HIGH"
    if btn.SetFrameStrata then btn:SetFrameStrata(strata) end
    local fl = (targetParent.GetFrameLevel and targetParent:GetFrameLevel()) or 10
    if closeBtn and closeBtn.GetFrameLevel then
        fl = math.max(fl, closeBtn:GetFrameLevel() or 10)
    end
    if btn.SetFrameLevel then btn:SetFrameLevel(fl + 5) end

    if combinedShown or singleShown then
        btn:Show()
    else
        btn:Hide()
    end
end

function CLIAlts:InitBagSortButton()
    if InCombatLockdown and InCombatLockdown() then return nil end
    if self.bagSortButton then
        self:UpdateBagSortButtonAnchor()
        return self.bagSortButton
    end
    if CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.showBagSortButton == false then
        return nil
    end

    local combinedFrame = rawget(_G, "ContainerFrameCombinedBags")
    local singleFrame = rawget(_G, "ContainerFrame1")
    local defaultParent = combinedFrame or singleFrame or UIParent

    local btn = CreateFrame("Button", "CLIAltsBagSortBtn", defaultParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    btn:SetSize(18, 18)
    if btn.SetFrameStrata then btn:SetFrameStrata("HIGH") end

    if btn.SetBackdrop then
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        if btn.SetBackdropColor then
            btn:SetBackdropColor(0.08, 0.08, 0.08, 0.85)
        end
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.95, 0.79, 0.30, 0.9)
        end
    end

    local label = btn:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(label, 13, "OUTLINE")
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    label:SetText("|cfff2c94c[S]|r")
    btn.label = label

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn:SetScript("OnEnter", function(s)
        if GameTooltip then
            GameTooltip:SetOwner(s, "ANCHOR_TOPRIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("|cfff2c94cCLIAlts: Bag Auto-Sort|r")
            GameTooltip:AddLine("|cff55e39aLeft-Click|r: Auto-sort and consolidate bags", 0.9, 0.9, 0.9)
            GameTooltip:AddLine("|cff57d6e8Right-Click|r: Open CLIAlts Dashboard", 0.9, 0.9, 0.9)
            GameTooltip:AddLine("|cffa9a08cSupports both Combined Bags & Separate Bags|r", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("|cffa9a08c/sortbags or /clialts sortbtn to toggle|r", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
        if s.SetBackdropColor then
            s:SetBackdropColor(0.2, 0.2, 0.1, 0.95)
        end
    end)

    btn:SetScript("OnLeave", function(s)
        if GameTooltip then GameTooltip:Hide() end
        if s.SetBackdropColor then
            s:SetBackdropColor(0.08, 0.08, 0.08, 0.85)
        end
    end)

    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            CLIAlts:Toggle()
        else
            CLIAlts:SortBags()
        end
    end)

    self.bagSortButton = btn
    self:ApplyThemeToBagButton()

    -- Hook standard Blizzard bag toggle functions if available
    if not self.hasHookedBagFunctions and hooksecurefunc then
        self.hasHookedBagFunctions = true
        local safeUpdate = function()
            if InCombatLockdown and InCombatLockdown() then return end
            CLIAlts:UpdateBagSortButtonAnchor()
        end
        local bagFuncs = { "ToggleAllBags", "OpenAllBags", "CloseAllBags", "ToggleBackpack", "OpenBag", "CloseBag" }
        for _, fnName in ipairs(bagFuncs) do
            if rawget(_G, fnName) then
                pcall(hooksecurefunc, fnName, safeUpdate)
            end
        end
    end

    -- Event watcher: monitors bag visibility without touching Blizzard secure bag functions or container scripts
    if not self.bagSortWatcher then
        local watcher = CreateFrame("Frame", "CLIAltsBagSortWatcher", UIParent)
        self.bagSortWatcher = watcher
        if watcher.RegisterEvent then
            pcall(watcher.RegisterEvent, watcher, "BAG_UPDATE_DELAYED")
            pcall(watcher.RegisterEvent, watcher, "BAG_CONTAINER_UPDATE")
            pcall(watcher.RegisterEvent, watcher, "PLAYER_REGEN_ENABLED")
            pcall(watcher.RegisterEvent, watcher, "PLAYER_REGEN_DISABLED")
        end
        watcher:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_REGEN_DISABLED" then
                if CLIAlts.bagSortButton and InCombatLockdown and InCombatLockdown() then
                    CLIAlts.bagSortButton:Hide()
                end
                return
            end
            if InCombatLockdown and InCombatLockdown() then return end
            CLIAlts:UpdateBagSortButtonAnchor()
        end)

        local elapsed = 0
        watcher:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + (dt or 0.1)
            if elapsed >= 0.25 then
                elapsed = 0
                if InCombatLockdown and InCombatLockdown() then return end
                CLIAlts:UpdateBagSortButtonAnchor()
            end
        end)
    end

    self:UpdateBagSortButtonAnchor()
    return btn
end

function CLIAlts:ToggleBagSortButton(enable)
    if enable == nil then
        if CLIAltsDB and CLIAltsDB.settings then
            enable = not CLIAltsDB.settings.showBagSortButton
        else
            enable = true
        end
    end

    if CLIAltsDB and CLIAltsDB.settings then
        CLIAltsDB.settings.showBagSortButton = enable
    end

    if enable then
        if not self.bagSortButton then
            self:InitBagSortButton()
        else
            self:UpdateBagSortButtonAnchor()
        end
    else
        if self.bagSortButton then
            self.bagSortButton:Hide()
        end
    end
    return enable
end

-- ----------------------------------------------------------------------------
-- Send Mail Auto-Fill Button Integration (SendMailFrame)
-- ----------------------------------------------------------------------------
function CLIAlts:UpdateMailAutoFillButton()
    local btn = self.mailAutoFillButton
    if not btn then return end
    local t = self:GetTheme()

    local summary = self:GetMailReadySummary()
    local count = summary and summary.totalPackages or 0

    if count > 0 then
        if btn.label then
            btn.label:SetText(string.format("|cff%s[ AUTO-FILL (%d) ]|r", t.highlightHex or "ffd34e", count))
        end
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 0.9)
        end
    else
        if btn.label then
            btn.label:SetText(string.format("|cff%s[ NO ROUTED MAIL ]|r", t.mutedHex or "a9a08c"))
        end
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 0.4)
        end
    end
end

function CLIAlts:InitMailAutoFillButton()
    if self.mailAutoFillButton then return self.mailAutoFillButton end
    if CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.showMailAutoFillButton == false then
        return nil
    end

    local parent = SendMailFrame
    if not parent then return nil end

    local btn = CreateFrame("Button", "CLIAltsMailAutoFillBtn", parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    btn:SetSize(115, 20)

    if SendMailNameEditBox then
        btn:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", 6, 0)
    else
        btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -40, -34)
    end
    btn:SetFrameStrata("HIGH")

    if btn.SetBackdrop then
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        if btn.SetBackdropColor then
            btn:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
        end
        if btn.SetBackdropBorderColor then
            btn:SetBackdropBorderColor(0.95, 0.79, 0.30, 0.9)
        end
    end

    local label = btn:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(label, 12, "OUTLINE")
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    label:SetText("|cfff2c94c[ AUTO-FILL ]|r")
    btn.label = label

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn:SetScript("OnEnter", function(s)
        if GameTooltip then
            GameTooltip:SetOwner(s, "ANCHOR_TOPRIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("|cfff2c94cCLIAlts: Mail Auto-Fill|r")
            GameTooltip:AddLine("|cff55e39aLeft-Click|r: Fill next alt recipient & attach items", 0.9, 0.9, 0.9)
            local autoSend = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.autoFillMailOnSend
            GameTooltip:AddLine(string.format("|cff57d6e8Right-Click|r: Auto-load next on Send (|cffffd700%s|r)", autoSend and "ENABLED" or "DISABLED"), 0.9, 0.9, 0.9)
            GameTooltip:AddLine("|cffa9a08cYou review items and manually click Send Mail.|r", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
        if s.SetBackdropColor then
            s:SetBackdropColor(0.2, 0.2, 0.1, 0.95)
        end
    end)

    btn:SetScript("OnLeave", function(s)
        if GameTooltip then GameTooltip:Hide() end
        if s.SetBackdropColor then
            s:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
        end
    end)

    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if CLIAltsDB and CLIAltsDB.settings then
                CLIAltsDB.settings.autoFillMailOnSend = not CLIAltsDB.settings.autoFillMailOnSend
                local state = CLIAltsDB.settings.autoFillMailOnSend and "|cff00ff66ENABLED|r" or "|cffff8800DISABLED|r"
                CLIAlts:Print(string.format("Auto-load next package on Send: %s.", state))
                CLIAlts:UpdateMailAutoFillButton()
            end
        else
            CLIAlts:FillSendMailNextBatch()
        end
    end)

    if parent and parent.HookScript then
        pcall(parent.HookScript, parent, "OnShow", function()
            if CLIAlts.UpdateMailAutoFillButton then
                CLIAlts:UpdateMailAutoFillButton()
            end
        end)
    end

    self.mailAutoFillButton = btn
    self:UpdateMailAutoFillButton()
    return btn
end

function CLIAlts:ToggleMailAutoFillButton(enable)
    if enable == nil then
        if CLIAltsDB and CLIAltsDB.settings then
            enable = not CLIAltsDB.settings.showMailAutoFillButton
        else
            enable = true
        end
    end

    if CLIAltsDB and CLIAltsDB.settings then
        CLIAltsDB.settings.showMailAutoFillButton = enable
    end

    if enable then
        if not self.mailAutoFillButton then
            self:InitMailAutoFillButton()
        end
        if self.mailAutoFillButton then
            self.mailAutoFillButton:Show()
            self:UpdateMailAutoFillButton()
        end
    else
        if self.mailAutoFillButton then
            self.mailAutoFillButton:Hide()
        end
    end
    return enable
end

-- ============================================================================
-- 28. Onboarding Tour Engine (/ca tour)
-- Highlights key features across 3 steps: Banner, Status Pill, Command Bar
-- ============================================================================

CLIAlts.TOUR_STEPS = {
    {
        badge = "STEP 1 OF 3",
        title = "Play Next Priority",
        desc = "CLIAlts identifies alts at danger of wasting rested XP or with urgent cooldowns and ranks them here. Click any hero card to inspect.",
        target = function()
            local mf = CLIAlts.mainFrame or _G["CLIAltsMainFrame"]
            if mf and mf.nextBanner and mf.nextBanner:IsShown() then
                return mf.nextBanner
            end
            return mf
        end,
        position = "BELOW",
    },
    {
        badge = "STEP 2 OF 3",
        title = "Real-Time Status Pills",
        desc = "Status pills show whether each character is Resting, Capped, Losing XP, or Ready to play at a glance. Rested XP and progress calculate continuously.",
        target = function()
            local rowFrames = CLIAlts:GetRowFrames()
            if rowFrames and rowFrames[1] then
                if rowFrames[1].statusPill and rowFrames[1].statusPill:IsShown() then
                    return rowFrames[1].statusPill
                end
                return rowFrames[1]
            end
            local mf = CLIAlts.mainFrame or _G["CLIAltsMainFrame"]
            return mf
        end,
        position = "LEFT_OR_BELOW",
    },
    {
        badge = "STEP 3 OF 3",
        title = "Command Bar & Quick Chips",
        desc = "Type commands or click quick hint chips (like 'next', 'plan 2', 'unlocked mc', 'digest') to control your roster. Use Up/Down for history and Tab to autocomplete.",
        target = function()
            local mf = CLIAlts.mainFrame or _G["CLIAltsMainFrame"]
            if mf and mf.cmdBar and mf.cmdBar:IsShown() then
                return mf.cmdBar
            end
            return mf
        end,
        position = "ABOVE",
    },
}

function CLIAlts:GetTourHighlight()
    if self.tourHighlight then return self.tourHighlight end
    local hl = CreateFrame("Frame", "CLIAltsTourHighlight", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    hl:SetFrameStrata("DIALOG")
    hl:SetFrameLevel(90)
    hl:EnableMouse(false)
    hl:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    if hl.SetBackdropBorderColor then
        hl:SetBackdropBorderColor(0.91, 0.71, 0.29, 1.0) -- Brand Gold #E8B64A
    end
    self.tourHighlight = hl
    return hl
end

function CLIAlts:GetTourCard()
    if self.tourCard then return self.tourCard end
    local card = CreateFrame("Frame", "CLIAltsTourCard", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    card:SetSize(360, 140)
    card:SetFrameStrata("DIALOG")
    card:SetFrameLevel(100)
    card:EnableMouse(true)
    card:SetMovable(true)
    card:RegisterForDrag("LeftButton")
    card:SetScript("OnDragStart", function(self) self:StartMoving() end)
    card:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    tinsert(UISpecialFrames, "CLIAltsTourCard")

    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    if card.SetBackdropColor then
        card:SetBackdropColor(0.08, 0.10, 0.15, 0.98)
    end
    if card.SetBackdropBorderColor then
        card:SetBackdropBorderColor(0.91, 0.71, 0.29, 0.8)
    end

    local stepBadge = card:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(stepBadge, 10, "OUTLINE")
    stepBadge:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12)
    stepBadge:SetText("|cffe8b64aSTEP 1 OF 3|r")
    card.stepBadge = stepBadge

    local btnClose = CreateRetroButton(card, "X", 20, 20, function()
        CLIAlts:EndTour()
    end, 10)
    btnClose:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -8)
    card.btnClose = btnClose

    local titleText = card:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(titleText, 13, "BOLD")
    titleText:SetPoint("TOPLEFT", stepBadge, "BOTTOMLEFT", 0, -4)
    titleText:SetPoint("RIGHT", card, "RIGHT", -36, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetTextColor(1, 1, 1)
    card.titleText = titleText

    local descText = card:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(descText, 11, "")
    descText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -6)
    descText:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    descText:SetJustifyH("LEFT")
    descText:SetJustifyV("TOP")
    descText:SetWordWrap(true)
    descText:SetTextColor(0.78, 0.82, 0.88)
    card.descText = descText

    local btnBack = CreateRetroButton(card, "< Back", 65, 20, function()
        if CLIAlts.currentTourStep and CLIAlts.currentTourStep > 1 then
            CLIAlts:ShowTourStep(CLIAlts.currentTourStep - 1)
        end
    end)
    btnBack:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 14, 12)
    card.btnBack = btnBack

    local btnNext = CreateRetroButton(card, "Next >", 75, 20, function()
        if CLIAlts.currentTourStep and CLIAlts.currentTourStep < #CLIAlts.TOUR_STEPS then
            CLIAlts:ShowTourStep(CLIAlts.currentTourStep + 1)
        else
            CLIAlts:EndTour()
        end
    end)
    btnNext:SetPoint("LEFT", btnBack, "RIGHT", 8, 0)
    card.btnNext = btnNext

    local btnSkip = CreateRetroButton(card, "Skip Tour", 75, 20, function()
        CLIAlts:EndTour()
    end)
    btnSkip:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -14, 12)
    card.btnSkip = btnSkip

    self.tourCard = card
    return card
end

function CLIAlts:ShowTourStep(stepIndex)
    stepIndex = tonumber(stepIndex) or 1
    if stepIndex < 1 then stepIndex = 1 end
    if stepIndex > #self.TOUR_STEPS then stepIndex = #self.TOUR_STEPS end
    self.currentTourStep = stepIndex

    local step = self.TOUR_STEPS[stepIndex]
    if not step then return end

    local hl = self:GetTourHighlight()
    local card = self:GetTourCard()
    local mf = self.mainFrame or _G["CLIAltsMainFrame"]

    -- Find target frame
    local target = nil
    if type(step.target) == "function" then
        local ok, res = pcall(step.target)
        if ok and res then target = res end
    elseif step.target then
        target = step.target
    end
    if not target or not target.IsShown or not target:IsShown() then
        target = mf
    end

    if hl and target then
        hl:ClearAllPoints()
        hl:SetPoint("TOPLEFT", target, "TOPLEFT", -4, 4)
        hl:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 4, -4)
        hl:Show()
    end

    if card then
        if card.stepBadge then
            card.stepBadge:SetText(string.format("|cffe8b64a%s|r", step.badge or string.format("STEP %d OF %d", stepIndex, #self.TOUR_STEPS)))
        end
        if card.titleText then
            card.titleText:SetText(step.title or "")
        end
        if card.descText then
            card.descText:SetText(step.desc or "")
        end

        if card.btnBack then
            if stepIndex == 1 then
                if card.btnBack.Disable then card.btnBack:Disable() end
                if card.btnBack.SetEnabled then card.btnBack:SetEnabled(false) end
                card.btnBack:SetAlpha(0.35)
            else
                if card.btnBack.Enable then card.btnBack:Enable() end
                if card.btnBack.SetEnabled then card.btnBack:SetEnabled(true) end
                card.btnBack:SetAlpha(1.0)
            end
        end

        if card.btnNext then
            local nextTxt = (stepIndex == #self.TOUR_STEPS) and "Finish" or "Next >"
            if card.btnNext.label then
                card.btnNext.label:SetText(nextTxt)
            end
            if card.btnNext.SetText then
                card.btnNext:SetText(nextTxt)
            end
        end

        card:ClearAllPoints()
        if target and target ~= mf then
            if step.position == "BELOW" then
                card:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 10, -12)
            elseif step.position == "LEFT_OR_BELOW" then
                card:SetPoint("TOPLEFT", target, "BOTTOMLEFT", -120, -12)
            elseif step.position == "ABOVE" then
                card:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 14, 12)
            else
                card:SetPoint("CENTER", mf or UIParent, "CENTER", 0, 0)
            end
        else
            card:SetPoint("CENTER", mf or UIParent, "CENTER", 0, 0)
        end

        card:Show()
    end
end

function CLIAlts:StartTour()
    local ok, err = pcall(function()
        if InCombatLockdown and InCombatLockdown() then
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff3333[CLIAlts]|r Cannot start onboarding tour while in combat.")
            end
            return
        end

        if CLIAltsDB and CLIAltsDB.settings then
            CLIAltsDB.settings.tourDone = true
        end

        if self.SwitchTab then
            self:SwitchTab(1)
        end

        local mf = self.mainFrame or _G["CLIAltsMainFrame"]
        if not mf or not mf:IsShown() then
            self:Toggle(true)
        end

        self:ShowTourStep(1)
    end)
    if not ok then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff3333[CLIAlts]|r StartTour error: %s", tostring(err)))
        end
    end
end

function CLIAlts:EndTour()
    self.currentTourStep = nil
    if self.tourHighlight then
        self.tourHighlight:Hide()
    end
    if self.tourCard then
        self.tourCard:Hide()
    end
    if CLIAltsDB and CLIAltsDB.settings then
        CLIAltsDB.settings.tourDone = true
    end
end


