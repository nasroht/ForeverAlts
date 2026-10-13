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
local DEFAULT_FONT_SIZE = 15
local LINE_WIDTH = 110
local BORDER_LINE   = "+" .. string.rep("-", LINE_WIDTH - 2) .. "+"
local DOUBLE_BORDER = "+" .. string.rep("=", LINE_WIDTH - 2) .. "+"

local ROWS_COUNT = 12
local rowFrames = {}
local headerButtons = {}
local currentPage = 1
local totalPages = 1
local mainFrame = nil
local dossierPopup = nil
local confirmPopup = nil
local helpPopup = nil
local probeString = nil
local renderDirty = false

-- ----------------------------------------------------------------------------
-- CRT Theme Definitions (With Syntax Coloring Hex Codes)
-- ----------------------------------------------------------------------------
CLIAlts.THEMES = {
    ["GREEN"] = {
        name = "Phosphor CRT",
        tag = "GRN",
        bg = { 0.03, 0.06, 0.04, 0.96 },
        border = { 0.0, 1.0, 0.4, 0.85 },
        primary = { 0.0, 1.0, 0.4 },
        dim = { 0.25, 0.65, 0.35 },
        highlight = { 0.6, 1.0, 0.7 },
        rowHover = { 0.0, 0.3, 0.15, 0.35 },
        borderHex = "00ff66",
        primaryHex = "00ff66",
        dimHex = "3fa859",
        highlightHex = "99ffb2",
        barFill = "|cff00ff66",
        barEmpty = "|cff1a6633",
    },
    ["AMBER"] = {
        name = "VT220 Amber",
        tag = "AMB",
        bg = { 0.06, 0.04, 0.01, 0.96 },
        border = { 1.0, 0.7, 0.0, 0.85 },
        primary = { 1.0, 0.75, 0.1 },
        dim = { 0.75, 0.5, 0.15 },
        highlight = { 1.0, 0.9, 0.4 },
        rowHover = { 0.3, 0.2, 0.05, 0.35 },
        borderHex = "ffb000",
        primaryHex = "ffb000",
        dimHex = "bf8026",
        highlightHex = "ffe666",
        barFill = "|cffffb000",
        barEmpty = "|cff664400",
    },
    ["CYAN"] = {
        name = "Cyberdeck Cyan",
        tag = "CYN",
        bg = { 0.02, 0.05, 0.07, 0.96 },
        border = { 0.0, 0.85, 1.0, 0.85 },
        primary = { 0.2, 0.9, 1.0 },
        dim = { 0.2, 0.55, 0.75 },
        highlight = { 0.7, 1.0, 1.0 },
        rowHover = { 0.05, 0.2, 0.3, 0.35 },
        borderHex = "00d9ff",
        primaryHex = "33e6ff",
        dimHex = "338cbf",
        highlightHex = "b3ffff",
        barFill = "|cff00e5ff",
        barEmpty = "|cff004f66",
    },
    ["MONO"] = {
        name = "VT100 Monochrome",
        tag = "MON",
        bg = { 0.04, 0.04, 0.04, 0.96 },
        border = { 0.8, 0.8, 0.8, 0.85 },
        primary = { 0.9, 0.9, 0.9 },
        dim = { 0.5, 0.5, 0.5 },
        highlight = { 1.0, 1.0, 1.0 },
        rowHover = { 0.2, 0.2, 0.2, 0.35 },
        borderHex = "cccccc",
        primaryHex = "e6e6e6",
        dimHex = "808080",
        highlightHex = "ffffff",
        barFill = "|cffd8d8d8",
        barEmpty = "|cff555555",
    },
    ["COLORBLIND"] = {
        name = "Phosphor Safe",
        tag = "SAFE",
        bg = { 0.02, 0.04, 0.08, 0.96 },
        border = { 0.25, 0.65, 1.0, 0.85 },
        primary = { 0.35, 0.75, 1.0 },
        dim = { 0.40, 0.58, 0.78 },
        highlight = { 1.0, 0.85, 0.2 },
        rowHover = { 0.08, 0.20, 0.38, 0.35 },
        borderHex = "40a6ff",
        primaryHex = "59bfff",
        dimHex = "6694c7",
        highlightHex = "ffd933",
        barFill = "|cff40a6ff",
        barEmpty = "|cff14334d",
    },
}

local THEME_ORDER = { "GREEN", "AMBER", "CYAN", "MONO", "COLORBLIND" }
local SCALES = { 0.8, 0.9, 1.0, 1.15, 1.3, 1.45 }

function CLIAlts:GetTheme()
    local key = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.theme) or "GREEN"
    return self.THEMES[key] or self.THEMES["GREEN"]
end

function CLIAlts:CycleTheme()
    local current = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.theme) or "GREEN"
    local nextTheme = "GREEN"
    for i, name in ipairs(THEME_ORDER) do
        if name == current then
            nextTheme = THEME_ORDER[(i % #THEME_ORDER) + 1]
            break
        end
    end
    CLIAltsDB.settings.theme = nextTheme
    self:ApplyTheme()
    self:Render()
end

-- ----------------------------------------------------------------------------
-- Typography & Monospace Helpers
-- ----------------------------------------------------------------------------
function CLIAlts:SetWidgetFont(fontString, size, flags)
    if not fontString or not fontString.SetFont then return end
    size = size or (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.fontSize) or DEFAULT_FONT_SIZE
    flags = flags or ""
    local setOk = false
    pcall(function()
        setOk = fontString:SetFont(FONT_PATH, size, flags)
    end)
    if not setOk then
        pcall(function()
            local fallback = _G["STANDARD_TEXT_FONT"] or "Fonts\\FRIZQT__.TTF"
            fontString:SetFont(fallback, size, flags)
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
    targetPixelWidth = targetPixelWidth or (mainFrame and (mainFrame:GetWidth() - 24)) or 896
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
    if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    else
        pcall(PlaySound, 856)
    end
end

local function CreateRetroButton(parent, text, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    btn:SetSize(width or 80, height or 20)

    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    btn:SetBackdropColor(0, 0, 0, 0.6)
    btn:SetBackdropBorderColor(0.2, 0.6, 0.3, 0.8)

    local label = btn:CreateFontString(nil, "OVERLAY")
    CLIAlts:SetWidgetFont(label, 14, "")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text or "")
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        local t = CLIAlts:GetTheme()
        self:SetBackdropColor(t.border[1], t.border[2], t.border[3], 0.25)
        self:SetBackdropBorderColor(t.primary[1], t.primary[2], t.primary[3], 1)
        self.label:SetTextColor(1, 1, 1)
    end)

    btn:SetScript("OnLeave", function(self)
        local t = CLIAlts:GetTheme()
        self:SetBackdropColor(0, 0, 0, 0.6)
        self:SetBackdropBorderColor(t.dim[1], t.dim[2], t.dim[3], 0.8)
        self.label:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
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
    if pos and pos.point and type(pos.x) == "number" and type(pos.y) == "number" then
        frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)
    else
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
    size = math.min(22, math.max(12, size))
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
local function FmtFaction(char)
    local fac = char.faction or "Neutral"
    if fac == "Alliance" then
        return "|cff00aaff[A]|r"
    elseif fac == "Horde" then
        return "|cffff3333[H]|r"
    else
        return "|cffaaaaaa[-]|r"
    end
end

local function FmtName(char)
    local name = char.fullName or char.name or "Unknown"
    local _, _, _, hex = CLIAlts:GetClassColor(char.classFile)
    local isStale = CLIAlts.IsCharStale and CLIAlts:IsCharStale(char)
    if isStale then
        return string.format("|cff%s%s|r |cffff5555[S]|r", hex, name)
    end
    return string.format("|cff%s%s|r", hex, name)
end

local function FmtLevel(char)
    return tostring(char.level or 1)
end

local function FmtRaceClass(char)
    local code = CLIAlts:GetRaceCode(char)
    local class = char.class or "Unknown"
    return string.format("|cffcccccc%s %s|r", code, class)
end

local function FmtLevelProgress(char, t)
    local xpData = CLIAlts:GetLevelProgressData(char)
    if not xpData or xpData.isMaxLevel then
        return string.format("|cff%s[==========]|r |cff%sMAX|r", t.dimHex, t.highlightHex)
    end

    local fill = math.min(10, math.max(0, math.floor((xpData.ratio or 0) * 10)))
    local empty = 10 - fill
    local fillStr = string.rep("=", fill)
    local emptyStr = string.rep(".", empty)
    local pctStr = string.format("%d%%", xpData.percent)

    return string.format("|cff%s[|r|cff%s%s|r|cff%s%s|r|cff%s]|r |cff%s%s|r",
        t.borderHex, t.highlightHex, fillStr, t.dimHex, emptyStr, t.borderHex, t.primaryHex, pctStr)
end

local function FmtGold(char)
    local gold = math.floor((char.money or 0) / 10000)
    return "|cffffd700" .. CLIAlts:FormatNumber(gold) .. "g|r"
end

local function FmtRested(char, t)
    local rested = CLIAlts:GetRestedData(char)
    if not rested then return "|cff666666---|r" end
    if rested.isMaxLevel then return "|cff888888MAX|r" end

    local est = rested.isEstimate and "~" or ""
    local capMark = rested.isFull and "*" or ""
    local pct = string.format("%d%%%s%s", rested.percent, capMark, est)
    local color = rested.isFull and t.highlightHex or t.primaryHex
    return string.format("|cff%s%s|r", color, pct)
end

local function FmtETA(char, t)
    local rested = CLIAlts:GetRestedData(char)
    if not rested then return "|cff666666---|r" end
    if rested.isMaxLevel then return "|cff888888MAX|r" end
    if rested.isFull then
        local wastedSec, _, _, timeStr = CLIAlts:GetRestedWaste(char)
        if wastedSec and wastedSec > 3600 then
            return string.format("|cffffaa00!%s|r", timeStr or "1h")
        else
            return string.format("|cff%s[CAP]|r", t.highlightHex)
        end
    end
    return string.format("|cff%s%s|r", t.dimHex, rested.timeLeftStr or "---")
end

-- Tab 2 Rested Monitor Formatters
local function FmtRestedPool(char, t)
    local rested = CLIAlts:GetRestedData(char)
    if not rested or rested.isMaxLevel then
        return "|cff888888MAX LEVEL|r"
    end
    return string.format("|cff%s%s / %s|r", t.primaryHex, CLIAlts:FormatNumber(rested.currentRested), CLIAlts:FormatNumber(rested.maxRested))
end

local function FmtRestedBar(char, t)
    local rested = CLIAlts:GetRestedData(char)
    if not rested or rested.isMaxLevel then
        return string.format("|cff%s[==========]|r |cff%sMAX|r", t.dimHex, t.highlightHex)
    end

    local isFull = rested.isFull
    local ratio = math.min(1.0, math.max(0, rested.ratio or 0))
    local fill = math.min(10, math.max(0, math.floor(ratio * 10)))
    local empty = 10 - fill
    local fillChar = isFull and "#" or "="
    local fillStr = string.rep(fillChar, fill)
    local emptyStr = string.rep(".", empty)
    local est = rested.isEstimate and "~" or ""
    local capMark = isFull and "*" or ""
    local pctStr = string.format("%d%%%s%s", rested.percent, capMark, est)
    local color = isFull and t.highlightHex or t.primaryHex

    return string.format("|cff%s[|r|cff%s%s|r|cff%s%s|r|cff%s]|r |cff%s%s|r",
        t.borderHex, color, fillStr, t.dimHex, emptyStr, t.borderHex, color, pctStr)
end

local function FmtRate(char, t)
    local rested = CLIAlts:GetRestedData(char)
    if not rested or rested.isMaxLevel then
        return "|cff666666---|r"
    end
    local s = rested.isResting and "+5.0%/8h" or "+1.25%/8h"
    return string.format("|cff%s%s|r", t.dimHex, s)
end

local function FmtState(char)
    local rested = CLIAlts:GetRestedData(char)
    if not rested or rested.isMaxLevel then
        return "|cff666666---|r"
    end
    if rested.isResting then
        return "|cff00ff66[REST]|r"
    else
        return "|cffffaa00[WILD]|r"
    end
end

-- Tab 3 Profession Formatters
local function FmtProf1(char, t)
    local profs = char.professions and char.professions.primary
    local p = profs and profs[1]
    if not p then return "|cff666666---|r" end
    return string.format("|cff%s%s %d/%d|r", t.primaryHex, p.name or "Prof", p.rank or 0, p.maxRank or 0)
end

local function FmtProf2(char, t)
    local profs = char.professions and char.professions.primary
    local p = profs and profs[2]
    if not p then return "|cff666666---|r" end
    return string.format("|cff%s%s %d/%d|r", t.primaryHex, p.name or "Prof", p.rank or 0, p.maxRank or 0)
end

local function FmtSecProf(char, t)
    local secs = char.professions and char.professions.secondary
    if not secs or #secs == 0 then return "|cff666666---|r" end
    local parts = {}
    for _, s in ipairs(secs) do
        local shortName = s.name:sub(1, 4)
        table.insert(parts, string.format("%s %d", shortName, s.rank or 0))
    end
    return string.format("|cff%s%s|r", t.dimHex, table.concat(parts, ", "))
end

-- Tab 4 Economy & Location Formatters
local function FmtGoldLong(char)
    local gold = math.floor((char.money or 0) / 10000)
    return "|cffffd700" .. CLIAlts:FormatNumber(gold) .. "g|r"
end

local function FmtWealthShare(char, t)
    local summary = CLIAlts:GetAccountSummary()
    local total = summary.totalGold or 0
    local money = char.money or 0
    local pct = total > 0 and (money / total * 100) or 0
    return string.format("|cff%s%.1f%%|r", t.primaryHex, pct)
end

local function FmtLocation(char, t)
    local loc = char.location or "Unknown"
    return string.format("|cff%s%s|r", t.dimHex, loc)
end

local function FmtHearth(char, t)
    local bind = char.bindLocation or "Unknown"
    return string.format("|cff%s%s|r", t.highlightHex, bind)
end

-- Tab 5 Cooldowns & Lockouts Formatters
local function FmtTradeCooldowns(char, t)
    local cds = char.tradeCooldowns
    if not cds or not next(cds) then
        return "|cff666666NO COOLDOWNS|r"
    end
    local parts = {}
    local now = time()
    for name, readyAt in pairs(cds) do
        local short = name:gsub("^Transmute: ", "Xm:"):gsub("^Refined ", "")
        short = short:sub(1, 9)
        local rem = readyAt - now
        if rem <= 0 then
            table.insert(parts, string.format("|cff00ff66%s:RDY|r", short))
        else
            local h = math.floor(rem / 3600)
            local m = math.floor((rem % 3600) / 60)
            local timStr = (h > 0) and string.format("%dh", h) or string.format("%dm", m)
            table.insert(parts, string.format("%s:%s", short, timStr))
        end
    end
    if #parts == 0 then return "|cff00ff66READY|r" end
    return string.format("|cff%s%s|r", t.primaryHex, table.concat(parts, ", "))
end

local function FmtRaidLocks(char, t)
    local locks = char.lockouts
    if not locks or not next(locks) then
        return "|cff666666NO SAVED LOCKS|r"
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
            table.insert(parts, string.format("%s:%s", short, tStr))
        end
    end
    if #parts == 0 then return "|cff666666NO ACTIVE LOCKS|r" end
    return string.format("|cff%s%s|r", t.dimHex, table.concat(parts, ", "))
end

-- Tab 1 WoW Forever Route Formatters
local function FmtTier(char)
    local tier = char.tier or "UNASSIGNED"
    if tier == "CORE" then
        return "|cffffd700[CORE]|r"
    elseif tier == "RESERVE" then
        return "|cff00ccff[ALT]|r"
    elseif tier == "BANK" then
        return "|cffff9900[BANK]|r"
    else
        return "|cff666666[---]|r"
    end
end

local function FmtLevelTarget(char, t)
    local lvl = char.level or 1
    local tgt = char.target_level or ((char.tier == "CORE" and 35) or (char.tier == "RESERVE" and 25) or (char.tier == "BANK" and 1) or 60)
    if lvl >= tgt then
        return string.format("|cff00ff66%d/%d|r", lvl, tgt)
    else
        return string.format("|cff%s%d|r|cff%s/%d|r", t.primaryHex, lvl, t.dimHex, tgt)
    end
end

local function FmtProfessionsAuto(char)
    if char.supply_role and char.supply_role ~= "" then
        return string.format("|cffffffff%s|r", char.supply_role)
    end
    if char.tier == "BANK" then
        return "|cffff9900Bank Mule|r"
    end
    local profs = char.professions and char.professions.primary
    if profs and #profs > 0 then
        local parts = {}
        for _, p in ipairs(profs) do
            local short = p.name:sub(1, 6)
            table.insert(parts, string.format("%s %d", short, p.rank or 0))
        end
        return string.format("|cffffffff%s|r", table.concat(parts, ", "))
    end
    return "|cff666666---|r"
end

local function FmtForeverStatus(char, t)
    if char.tier == "BANK" then
        return "|cffff9900Bank Mule|r"
    end
    local lvl = char.level or 1
    local tgt = char.target_level or ((char.tier == "CORE" and 35) or (char.tier == "RESERVE" and 25) or 60)
    if lvl >= tgt then
        return "|cff00ff66Target Level Reached|r"
    end
    local rested = CLIAlts:GetRestedData(char)
    if not rested then return "|cff666666Accruing|r" end
    if rested.isMaxLevel then return "|cff888888MAX LEVEL|r" end
    if rested.isFull then
        local capPct = rested.maxPercent or 150
        return string.format("|cff%s%d%% Capped*|r", t.highlightHex, capPct)
    end
    local pct = rested.percent or 0
    local est = rested.isEstimate and "~" or ""
    return string.format("|cff%s%d%%%s Rested|r", t.primaryHex, pct, est)
end

local FOREVER_COLS = {
    { key = "tier",     title = "COHORT",      w = 8,  pw = 75,  cpw = 70,  align = "CENTER", sort = "cohort", fmt = FmtTier },
    { key = "name",     title = "NAME",        w = 15, pw = 140, cpw = 125, align = "LEFT",   sort = "name",   fmt = FmtName },
    { key = "lvlTgt",   title = "LVL/TGT",     w = 8,  pw = 75,  cpw = 65,  align = "CENTER", sort = "level",  fmt = FmtLevelTarget },
    { key = "prof",     title = "PROFESSIONS", w = 18, pw = 185, cpw = 140, align = "LEFT",                    fmt = FmtProfessionsAuto },
    { key = "status",   title = "STATUS",      w = 18, pw = 175, cpw = 140, align = "LEFT",   sort = "rotation", fmt = FmtForeverStatus },
    { key = "gold",     title = "GOLD",        w = 9,  pw = 110, cpw = 80,  align = "RIGHT",  sort = "gold",   fmt = FmtGold },
    { key = "eta",      title = "ETA",         w = 7,  pw = 100, cpw = 0,   align = "RIGHT",                   fmt = FmtETA },
}

-- ----------------------------------------------------------------------------
-- Data-Driven Columns Table (COLS) - Explicit Pixel Widths (Sum = 860px / 620px)
-- ----------------------------------------------------------------------------
local COLS = {
    [1] = { -- ALTS OVERVIEW
        { key = "fac",       title = "FAC",            w = 3,  pw = 36,  cpw = 34,  align = "CENTER", fmt = FmtFaction },
        { key = "name",      title = "NAME",           w = 16, pw = 145, cpw = 125, align = "LEFT",   sort = "name",    fmt = FmtName },
        { key = "lvl",       title = "LVL",            w = 3,  pw = 40,  cpw = 36,  align = "CENTER", sort = "level",   fmt = FmtLevel },
        { key = "raceClass", title = "RACE/CLASS",     w = 11, pw = 125, cpw = 110, align = "LEFT",   fmt = FmtRaceClass },
        { key = "xp",        title = "LEVEL PROGRESS", w = 16, pw = 180, cpw = 0,   align = "LEFT",   sort = "xp",      fmt = FmtLevelProgress },
        { key = "gold",      title = "GOLD",           w = 10, pw = 115, cpw = 100, align = "RIGHT",  sort = "gold",    fmt = FmtGold },
        { key = "rested",    title = "RESTED",         w = 8,  pw = 110, cpw = 95,  align = "RIGHT",  sort = "rested",  fmt = FmtRested },
        { key = "eta",       title = "ETA",            w = 7,  pw = 109, cpw = 90,  align = "RIGHT",  fmt = FmtETA },
    },
    [2] = { -- RESTED XP MONITOR
        { key = "fac",       title = "FAC",             w = 3,  pw = 36,  cpw = 34,  align = "CENTER", fmt = FmtFaction },
        { key = "name",      title = "NAME",            w = 16, pw = 145, cpw = 125, align = "LEFT",   sort = "name",   fmt = FmtName },
        { key = "lvl",       title = "LVL",             w = 3,  pw = 40,  cpw = 36,  align = "CENTER", sort = "level",  fmt = FmtLevel },
        { key = "pool",      title = "RESTED / CAP",    w = 17, pw = 165, cpw = 150, align = "RIGHT",  sort = "rested", fmt = FmtRestedPool },
        { key = "restBar",   title = "RESTED PROGRESS", w = 17, pw = 180, cpw = 0,   align = "LEFT",   fmt = FmtRestedBar },
        { key = "rate",      title = "RATE",            w = 8,  pw = 95,  cpw = 80,  align = "RIGHT",  fmt = FmtRate },
        { key = "state",     title = "STATE",           w = 7,  pw = 85,  cpw = 75,  align = "CENTER", fmt = FmtState },
        { key = "eta",       title = "ETA/WST",         w = 7,  pw = 114, cpw = 90,  align = "RIGHT",  sort = "waste",  fmt = FmtETA },
    },
    [3] = { -- PROFESSIONS
        { key = "fac",       title = "FAC",             w = 3,  pw = 36,  cpw = 34,  align = "CENTER", fmt = FmtFaction },
        { key = "name",      title = "NAME",            w = 16, pw = 145, cpw = 125, align = "LEFT",   sort = "name",   fmt = FmtName },
        { key = "lvl",       title = "LVL",             w = 3,  pw = 40,  cpw = 36,  align = "CENTER", sort = "level",  fmt = FmtLevel },
        { key = "prof1",     title = "PRIMARY PROF 1",  w = 23, pw = 250, cpw = 180, align = "LEFT",   fmt = FmtProf1 },
        { key = "prof2",     title = "PRIMARY PROF 2",  w = 20, pw = 230, cpw = 165, align = "LEFT",   fmt = FmtProf2 },
        { key = "sec",       title = "SECONDARY",       w = 14, pw = 159, cpw = 80,  align = "LEFT",   fmt = FmtSecProf },
    },
    [4] = { -- ECONOMY & LOCATIONS
        { key = "fac",       title = "FAC",             w = 3,  pw = 36,  cpw = 34,  align = "CENTER", fmt = FmtFaction },
        { key = "name",      title = "NAME",            w = 16, pw = 145, cpw = 125, align = "LEFT",   sort = "name",     fmt = FmtName },
        { key = "lvl",       title = "LVL",             w = 3,  pw = 40,  cpw = 36,  align = "CENTER", sort = "level",    fmt = FmtLevel },
        { key = "gold",      title = "GOLD",            w = 11, pw = 120, cpw = 100, align = "RIGHT",  sort = "gold",     fmt = FmtGoldLong },
        { key = "share",     title = "SHARE",           w = 6,  pw = 65,  cpw = 55,  align = "RIGHT",  fmt = FmtWealthShare },
        { key = "location",  title = "LAST ZONE",       w = 18, pw = 230, cpw = 140, align = "LEFT",   sort = "location", fmt = FmtLocation },
        { key = "hearth",    title = "HEARTHSTONE",     w = 18, pw = 224, cpw = 130, align = "LEFT",   sort = "hearth",   fmt = FmtHearth },
    },
    [5] = { -- COOLDOWNS & SAVED LOCKS
        { key = "fac",       title = "FAC",             w = 3,  pw = 36,  cpw = 34,  align = "CENTER", fmt = FmtFaction },
        { key = "name",      title = "NAME",            w = 16, pw = 145, cpw = 125, align = "LEFT",   sort = "name",   fmt = FmtName },
        { key = "lvl",       title = "LVL",             w = 3,  pw = 40,  cpw = 36,  align = "CENTER", sort = "level",  fmt = FmtLevel },
        { key = "tradeCd",   title = "TRADE COOLDOWNS", w = 25, pw = 340, cpw = 230, align = "LEFT",   fmt = FmtTradeCooldowns },
        { key = "raidLocks", title = "SAVED INSTANCES / LOCKS", w = 30, pw = 299, cpw = 205, align = "LEFT", fmt = FmtRaidLocks },
    },
}

function CLIAlts:GetColumns(activeTab)
    local tabCols
    if (activeTab == 1 or activeTab == nil) and self:IsForeverMode() then
        tabCols = FOREVER_COLS
    else
        tabCols = COLS[activeTab] or COLS[1]
    end
    if not self:IsCompact() then
        return tabCols
    end

    local filtered = {}
    for _, col in ipairs(tabCols) do
        -- In compact mode, hide columns with cpw == 0 or nil/disabled
        if col.cpw and col.cpw > 0 then
            table.insert(filtered, col)
        elseif col.cpw == nil and col.key ~= "xp" and col.key ~= "restBar" and col.key ~= "eta" then
            table.insert(filtered, col)
        end
    end
    return filtered
end

function CLIAlts:GetLineWidth()
    local targetW = (mainFrame and (mainFrame:GetWidth() - 24)) or (self:IsCompact() and 696 or 896)
    local charW = self:GetCharWidth()
    if not charW or charW < 4 or charW > 25 then
        charW = DEFAULT_FONT_SIZE * 0.54
    end
    return math.max(20, math.floor(targetW / charW))
end

function CLIAlts:GetBorderLine(isDouble)
    local char = isDouble and "=" or "-"
    local targetW = (mainFrame and (mainFrame:GetWidth() - 24)) or (self:IsCompact() and 696 or 896)
    return self:GetBarString(char, targetW)
end

function CLIAlts:UpdateBorders()
    if not mainFrame then return end
    local doubleBar = self:GetBorderLine(true)
    local singleBar = self:GetBorderLine(false)

    if mainFrame.topAscii then mainFrame.topAscii:SetText(doubleBar) end
    if mainFrame.midAscii1 then mainFrame.midAscii1:SetText(singleBar) end
    if mainFrame.midAscii2 then mainFrame.midAscii2:SetText(singleBar) end
    if mainFrame.tableTopAscii then mainFrame.tableTopAscii:SetText(doubleBar) end
    if mainFrame.tableSepAscii then mainFrame.tableSepAscii:SetText(singleBar) end
    if mainFrame.tableBotAscii then mainFrame.tableBotAscii:SetText(doubleBar) end
    if mainFrame.promptSepAscii then mainFrame.promptSepAscii:SetText(singleBar) end
    if mainFrame.botAscii then mainFrame.botAscii:SetText(singleBar) end
end

-- ----------------------------------------------------------------------------
-- Compact Mode Layout & Width Adjustment
-- ----------------------------------------------------------------------------
function CLIAlts:ApplyLayoutSize()
    if not mainFrame then return end
    local isComp = self:IsCompact()
    local targetWidth = isComp and 720 or 920
    mainFrame:SetWidth(targetWidth)
    if mainFrame.headerFrame then
        mainFrame.headerFrame:SetWidth(targetWidth - 24)
    end
    if mainFrame.rowsContainer then
        mainFrame.rowsContainer:SetWidth(targetWidth - 24)
    end
    for _, row in ipairs(rowFrames) do
        row:SetWidth(targetWidth - 24)
    end

    local tabW = isComp and 125 or 168
    local spacing = isComp and 6 or 8
    local prevTab = nil
    for _, tabBtn in ipairs(mainFrame.tabButtons or {}) do
        tabBtn:SetWidth(tabW)
        tabBtn:ClearAllPoints()
        if not prevTab then
            tabBtn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, -80)
        else
            tabBtn:SetPoint("LEFT", prevTab, "RIGHT", spacing, 0)
        end
        prevTab = tabBtn
    end

    if mainFrame.titleText then
        mainFrame.titleText:SetText(isComp and ("[#] CLIALTS v" .. (self.VERSION or "1.0.0")) or ("[#] CLIALTS :: ALT MONITOR v" .. (self.VERSION or "1.0.0")))
    end
    if mainFrame.btnCompact then
        mainFrame.btnCompact.label:SetText(isComp and "[ COMPACT* ]" or "[ COMPACT ]")
    end

    self:UpdateBorders()
end

-- ----------------------------------------------------------------------------
-- Main Frame Construction
-- ----------------------------------------------------------------------------
function CLIAlts:CreateMainFrame()
    if mainFrame then return mainFrame end

    local frame = CreateFrame("Frame", "CLIAltsMainFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:Hide()
    frame:SetSize(920, 535)
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
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })

    mainFrame = frame
    self.mainFrame = frame
    _G["CLIAltsMainFrame"] = frame

    local fontSize = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.fontSize) or DEFAULT_FONT_SIZE

    -- Top border ASCII line
    local topAscii = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(topAscii, fontSize)
    topAscii:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -8)
    topAscii:SetText(DOUBLE_BORDER)
    frame.topAscii = topAscii

    -- Title Bar
    local titleText = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(titleText, fontSize + 1, "OUTLINE")
    titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -22)
    titleText:SetText("[#] CLIALTS :: ALT MONITOR v" .. (self.VERSION or "1.0.0"))
    frame.titleText = titleText

    -- Window Controls on Title Bar (Scale, Compact, Theme, Help, Close)
    local btnClose = CreateRetroButton(frame, "[ X ]", 28, 18, function()
        CLIAlts:Toggle(false)
    end)
    btnClose:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -20)

    local btnHelp = CreateRetroButton(frame, "[ ? ]", 28, 18, function()
        CLIAlts:ShowHelpPopup()
    end)
    btnHelp:SetPoint("RIGHT", btnClose, "LEFT", -5, 0)

    local btnScale = CreateRetroButton(frame, string.format("[ SCALE: %d%% ]", math.floor(s * 100 + 0.5)), 90, 18, function()
        CLIAlts:CycleScale()
    end)
    btnScale:SetPoint("RIGHT", btnHelp, "LEFT", -5, 0)
    frame.btnScale = btnScale

    local btnCompact = CreateRetroButton(frame, "[ COMPACT ]", 85, 18, function()
        CLIAlts:ToggleCompact()
    end)
    btnCompact:SetPoint("RIGHT", btnScale, "LEFT", -5, 0)
    btnCompact:SetScript("OnEnter", function(self)
        local t = CLIAlts:GetTheme()
        self:SetBackdropColor(t.rowHover[1], t.rowHover[2], t.rowHover[3], 0.8)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Compact Mode", 1, 1, 1)
        GameTooltip:AddLine("Hides XP bar columns for narrow windows or high scales.", 0.8, 0.8, 0.8)
        local isComp = CLIAlts:IsCompact()
        GameTooltip:AddLine(string.format("Status: %s", isComp and "|cff00ff66ENABLED|r" or "|cff888888DISABLED|r"), 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Command: Type |cffffd700compact|r or |cffffd700c|r in prompt.", 0.4, 0.8, 0.5)
        GameTooltip:Show()
    end)
    btnCompact:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0, 0, 0, 0.6)
        GameTooltip:Hide()
    end)
    frame.btnCompact = btnCompact

    local btnTheme = CreateRetroButton(frame, "[ THEME: GRN ]", 95, 18, function()
        CLIAlts:CycleTheme()
    end)
    btnTheme:SetPoint("RIGHT", btnCompact, "LEFT", -5, 0)
    frame.btnTheme = btnTheme

    -- Subheader border ASCII line
    local midAscii1 = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(midAscii1, fontSize)
    midAscii1:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -40)
    midAscii1:SetText(BORDER_LINE)
    frame.midAscii1 = midAscii1

    -- Status bar line (Realm, Alts count, Wealth)
    local statusBarText = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(statusBarText, fontSize)
    statusBarText:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -53)
    statusBarText:SetText("SYSTEM: WOW FOREVER | TRACKED CHARACTERS: 0 | TOTAL WEALTH: 0g")
    frame.statusBarText = statusBarText

    -- Well Rested Perk quick toggle button
    local initPerkRank = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
    local btnPerk = CreateRetroButton(frame, string.format("[ PERK: R%d (+%d%%) ]", initPerkRank, initPerkRank * 4), 145, 18, function(self)
        CLIAlts:CycleWellRestedPerk()
        if MouseIsOver(self) and self:GetScript("OnEnter") then
            self:GetScript("OnEnter")(self)
        end
    end)
    btnPerk:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -51)
    btnPerk:SetScript("OnEnter", function(self)
        local t = CLIAlts:GetTheme()
        self:SetBackdropColor(t.rowHover[1], t.rowHover[2], t.rowHover[3], 0.8)
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
        self:SetBackdropColor(0, 0, 0, 0.6)
        GameTooltip:Hide()
    end)
    if CLIAlts:IsRetail() then
        btnPerk:Hide()
    end
    frame.btnPerk = btnPerk

    local midAscii2 = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(midAscii2, fontSize)
    midAscii2:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -66)
    midAscii2:SetText(BORDER_LINE)
    frame.midAscii2 = midAscii2

    -- Retro Tabs
    local tabs = {
        { id = 1, text = "[ ALTS OVERVIEW ]", compact = "[ 1: ALTS ]" },
        { id = 2, text = "[ RESTED XP ]",     compact = "[ 2: REST ]" },
        { id = 3, text = "[ PROFESSIONS ]",   compact = "[ 3: PROF ]" },
        { id = 4, text = "[ ECONOMY ]",       compact = "[ 4: ECON ]" },
        { id = 5, text = "[ COOLDOWNS ]",     compact = "[ 5: LOCK ]" },
    }
    frame.tabButtons = {}
    local prevTab = nil
    for _, tabData in ipairs(tabs) do
        local tabBtn = CreateRetroButton(frame, tabData.text, 142, 22, function()
            CLIAltsDB.settings.activeTab = tabData.id
            currentPage = 1
            CLIAlts:Render()
        end)
        if not prevTab then
            tabBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -80)
        else
            tabBtn:SetPoint("LEFT", prevTab, "RIGHT", 7, 0)
        end
        tabBtn.tabId = tabData.id
        tabBtn.baseText = tabData.text
        tabBtn.compactText = tabData.compact
        table.insert(frame.tabButtons, tabBtn)
        prevTab = tabBtn
    end

    -- Header top border ASCII line
    local tableTopAscii = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(tableTopAscii, fontSize)
    tableTopAscii:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -106)
    tableTopAscii:SetText(DOUBLE_BORDER)
    frame.tableTopAscii = tableTopAscii

    -- Column Header Line (Individual Cells) & Clickable Hit Frame
    local headerFrame = CreateFrame("Frame", nil, frame)
    headerFrame:SetSize(896, 18)
    headerFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -120)
    frame.headerFrame = headerFrame

    local headerBorderL = headerFrame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(headerBorderL, fontSize)
    headerBorderL:SetPoint("LEFT", headerFrame, "LEFT", 4, 0)
    headerBorderL:SetText("|")
    frame.headerBorderL = headerBorderL

    local headerBorderR = headerFrame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(headerBorderR, fontSize)
    headerBorderR:SetPoint("RIGHT", headerFrame, "RIGHT", -4, 0)
    headerBorderR:SetText("|")
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
    tableSepAscii:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -136)
    tableSepAscii:SetText(BORDER_LINE)
    frame.tableSepAscii = tableSepAscii

    -- Rows Container
    local rowsContainer = CreateFrame("Frame", nil, frame)
    rowsContainer:SetSize(896, ROWS_COUNT * 21)
    rowsContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -150)
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

    -- Create 12 Monospace Row Buttons (Each with explicit column cells)
    for i = 1, ROWS_COUNT do
        local row = CreateFrame("Button", nil, rowsContainer, BackdropTemplateMixin and "BackdropTemplate" or nil)
        row:SetSize(896, 20)
        row:SetPoint("TOPLEFT", rowsContainer, "TOPLEFT", 0, -((i - 1) * 21))

        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        row:SetBackdropColor(0, 0, 0, 0.2)
        row:SetBackdropBorderColor(0, 0, 0, 0)

        local borderL = row:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(borderL, fontSize)
        borderL:SetPoint("LEFT", row, "LEFT", 4, 0)
        borderL:SetText("|")
        row.borderL = borderL

        local borderR = row:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(borderR, fontSize)
        borderR:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        borderR:SetText("|")
        row.borderR = borderR

        row.cells = {}
        for j = 1, 8 do
            local cell = row:CreateFontString(nil, "OVERLAY")
            self:SetWidgetFont(cell, fontSize)
            cell:SetWordWrap(false)
            cell:SetHeight(18)
            row.cells[j] = cell
        end

        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, button)
            if self.charData then
                if button == "RightButton" then
                    CLIAlts:ShowConfirmDelete(self.charData)
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
            self:SetBackdropColor(t.rowHover[1], t.rowHover[2], t.rowHover[3], 0.4)
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
                    GameTooltip:AddLine(string.format("|cffff4444[STALE]|r Inactive for %d days", daysInactive), 1, 0.3, 0.3)
                end

                local xpData = CLIAlts:GetLevelProgressData(self.charData)
                if xpData and not xpData.isMaxLevel then
                    GameTooltip:AddLine(string.format("Level %d Progress: |cffffffff%s / %s XP|r (%5.1f%%)",
                        self.charData.level or 1, CLIAlts:FormatNumber(xpData.curXP), CLIAlts:FormatNumber(xpData.maxXP), xpData.percentExact), 0.8, 0.8, 0.8)
                    GameTooltip:AddLine(string.format("XP to Level %d: |cff00ff66%s XP needed|r",
                        (self.charData.level or 1) + 1, CLIAlts:FormatNumber(xpData.remainingXP)), 0.8, 0.8, 0.8)
                else
                    local maxLvl = (self.charData and self.charData.level) or CLIAlts:GetMaxLevel()
                    GameTooltip:AddLine(string.format("Level: |cff00ff66%d (MAX LEVEL)|r", maxLvl), 0.8, 0.8, 0.8)
                end

                local rested = CLIAlts:GetRestedData(self.charData)
                if rested and not rested.isMaxLevel then
                    local est = rested.isEstimate and "~" or ""
                    local capTarget = rested.maxPercent or 150
                    GameTooltip:AddLine(string.format("Rested Pool: |cffffffff%s%s XP|r (%s%d%% of level, %s)",
                        est, CLIAlts:FormatNumber(rested.currentRested), est, rested.percent, rested.statusStr), 0.8, 0.8, 0.8)
                    GameTooltip:AddLine(string.format("Time to Capped (%d%%): |cffffffff%s|r (%s)", capTarget, rested.timeLeftStr, rested.fullDate), 0.8, 0.8, 0.8)
                    if rested.isEstimate then
                        GameTooltip:AddLine("|cffffaa00* Rested values are estimated (~disconnect / crash)|r", 1, 0.8, 0)
                    end
                end

                if self.charData.note and self.charData.note ~= "" then
                    GameTooltip:AddLine(string.format("Note: |cffffd700%s|r", self.charData.note), 1, 0.85, 0.2)
                end

                if CLIAlts:IsForeverMode() then
                    GameTooltip:AddLine("Left-Click: Dossier | Shift-Click: Cycle Cohort | Right-Click: Delete", 0.7, 0.7, 0.7)
                else
                    GameTooltip:AddLine("Left-Click: Open Alt Dossier | Right-Click: Delete Character", 0.7, 0.7, 0.7)
                end
                GameTooltip:Show()
            end
        end)

        row:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, (i % 2 == 0) and 0.25 or 0.1)
            GameTooltip:Hide()
        end)

        rowFrames[i] = row
    end

    -- Bottom border ASCII line
    local tableBotAscii = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(tableBotAscii, fontSize)
    tableBotAscii:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -406)
    tableBotAscii:SetText(DOUBLE_BORDER)
    frame.tableBotAscii = tableBotAscii

    -- Footer: Pagination controls and helper tips
    local btnPrev = CreateRetroButton(frame, "[<< PREV]", 75, 18, function()
        if currentPage > 1 then
            currentPage = currentPage - 1
            CLIAlts:Render()
        end
    end)
    btnPrev:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 68)
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
    statusTip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 70)
    statusTip:SetText("|cff888888[Left-Click: Dossier | Right-Click: Delete | Click Col: Sort]|r")
    frame.statusTip = statusTip

    -- Command Prompt Separator Line
    local promptSepAscii = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(promptSepAscii, fontSize)
    promptSepAscii:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 50)
    promptSepAscii:SetText(BORDER_LINE)
    frame.promptSepAscii = promptSepAscii

    -- Interactive Command Prompt (EditBox with > prompt)
    local promptLabel = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(promptLabel, fontSize, "BOLD")
    promptLabel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 30)
    promptLabel:SetText("> ")
    frame.promptLabel = promptLabel

    local promptBox = CreateFrame("EditBox", "CLIAltsPromptEditBox", frame)
    self:SetWidgetFont(promptBox, fontSize)
    promptBox:SetPoint("LEFT", promptLabel, "RIGHT", 2, 0)
    promptBox:SetPoint("RIGHT", frame, "RIGHT", -18, 0)
    promptBox:SetHeight(18)
    promptBox:SetAutoFocus(false)
    promptBox:EnableMouse(true)
    promptBox:SetTextInsets(2, 2, 2, 2)
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

    -- Hook ChatEdit_InsertLink so Shift-clicking items into prompt works
    if hooksecurefunc then
        pcall(hooksecurefunc, "ChatEdit_InsertLink", function(text)
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
            if ClearOverrideBindings then
                ClearOverrideBindings(frame)
            end
        end)
    end)
    promptBox:SetScript("OnEditFocusLost", function()
        pcall(function()
            if frame:IsShown() and SetOverrideBindingClick then
                SetOverrideBindingClick(frame, false, "ENTER", "CLIAltsFocusEnterBtn")
                SetOverrideBindingClick(frame, false, "/", "CLIAltsFocusSlashBtn")
            end
        end)
    end)

    -- Prompt Hint & Feedback Line
    local promptStatusTip = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(promptStatusTip, fontSize - 2)
    promptStatusTip:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 14)
    promptStatusTip:SetText("|cff888888[Press Enter or / to type: 1-5, sort <col>, filter <query>, next, export, help]|r")
    frame.promptStatusTip = promptStatusTip

    local botAscii = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(botAscii, fontSize)
    botAscii:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 2)
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
            if ClearOverrideBindings then
                ClearOverrideBindings(self)
            end
        end)
        if frame.promptBox then
            frame.promptBox:ClearFocus()
        end
    end)

    return frame
end

-- ----------------------------------------------------------------------------
-- Terminal Render Engine (Coalesced with Dirty Flag)
-- ----------------------------------------------------------------------------
local renderTimerPending = false

function CLIAlts:RequestRender()
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

    local t = self:GetTheme()
    local activeTab = CLIAltsDB.settings.activeTab or 1

    -- Highlight active tab button
    local isComp = self:IsCompact()
    for _, tabBtn in ipairs(mainFrame.tabButtons) do
        local base = isComp and tabBtn.compactText or tabBtn.baseText
        if tabBtn.tabId == 1 and self:IsForeverMode() then
            base = isComp and "[ 1: ROUTE ]" or "[ FOREVER ROUTE ]"
        end
        if tabBtn.tabId == activeTab then
            tabBtn.label:SetText(string.format(">> %s <<", base))
            tabBtn.label:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
            tabBtn:SetBackdropColor(t.border[1], t.border[2], t.border[3], 0.3)
            tabBtn:SetBackdropBorderColor(t.highlight[1], t.highlight[2], t.highlight[3], 1)
        else
            tabBtn.label:SetText(base)
            tabBtn.label:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
            tabBtn:SetBackdropColor(0, 0, 0, 0.6)
            tabBtn:SetBackdropBorderColor(t.dim[1], t.dim[2], t.dim[3], 0.8)
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
                mainFrame.btnPerk.label:SetText(string.format("[ PERK: R%d (+%d%%) ]", r, r * 4))
            end
        end
    end

    -- Update Status Bar
    local summary = self:GetAccountSummary()
    local totalGold = summary.totalGold or 0
    local goldOnly = math.floor(totalGold / 10000)
    local curFull = self.curPlayerFullName or (select(3, self:GetPlayerNames()))

    if isComp then
        local filterTag = self.activeFilter and string.format(" [%s]", self.activeFilter:upper()) or ""
        if self:IsForeverMode() then
            local coreC, resC, bankC = self:GetCohortCounts()
            local nextList = self:GetNextAltsPriority()
            local topNext = nextList and nextList[1]
            if topNext then
                local tc = topNext.char
                local capStr = topNext.isCapped and string.format("%d%%*", topNext.maxPercent) or string.format("%d%%", topNext.percent)
                local tag = (tc.tier == "CORE" and " [C]") or (tc.tier == "RESERVE" and " [A]") or ""
                mainFrame.statusBarText:SetText(string.format("NEXT: %s%s (L%d) %s | %dC/%dR/%dB%s",
                    tc.name or "Unknown", tag, tc.level or 1, capStr, coreC, resC, bankC, filterTag))
            else
                mainFrame.statusBarText:SetText(string.format("ROUTE: %dC/%dR/%dB | ALL TARGETS REACHED%s",
                    coreC, resC, bankC, filterTag))
            end
        else
            mainFrame.statusBarText:SetText(string.format("ALTS: %d%s | WEALTH: %sg",
                summary.totalAlts or 0, filterTag, self:FormatNumber(goldOnly)))
        end
    elseif activeTab == 4 then
        local spark = self:GenerateAsciiSparkline(14)
        local d1, d7, d30 = self:GetGoldHistoryDeltas()
        local d1Sign = d1 >= 0 and "+" or ""
        local d7Sign = d7 >= 0 and "+" or ""
        local d30Sign = d30 >= 0 and "+" or ""
        mainFrame.statusBarText:SetText(string.format("WEALTH [%s] | 24H: %s%dg | 7D: %s%dg | 30D: %s%dg | TOTAL: %sg",
            spark, d1Sign, d1, d7Sign, d7, d30Sign, d30, self:FormatNumber(goldOnly)))
    else
        local filterTag = self.activeFilter and string.format(" [FILTER: %s]", self.activeFilter:upper()) or ""
        local sysLabel = self:IsRetail() and "SYSTEM: RETAIL" or "SYSTEM: WOW FOREVER"
        if self:IsForeverMode() then
            local coreC, resC, bankC = self:GetCohortCounts()
            local nextList = self:GetNextAltsPriority()
            local topNext = nextList and nextList[1]
            if topNext then
                local tc = topNext.char
                local tag = (tc.tier == "CORE" and " [CORE]") or (tc.tier == "RESERVE" and " [ALT]") or ""
                local tgtStr = topNext.targetLevel and string.format(" (%d/%d)", tc.level or 1, topNext.targetLevel) or string.format(" (Lvl %d)", tc.level or 1)
                local restDetail
                if topNext.isCapped then
                    if topNext.wastedXP and topNext.wastedXP > 0 then
                        restDetail = string.format("[%d%% CAPPED* (+%s)]", topNext.maxPercent, self:FormatWasteShort(topNext.wastedXP))
                    else
                        restDetail = string.format("[%d%% CAPPED*]", topNext.maxPercent)
                    end
                else
                    restDetail = string.format("[%d%% Rested (~%s)]", topNext.percent, self:FormatWasteShort(topNext.usableXP))
                end
                mainFrame.statusBarText:SetText(string.format("PLAY NEXT: >> %s%s%s %s << | ROUTE: %dC/%dR/%dB | WEALTH: %sg%s",
                    tc.name or "Unknown", tag, tgtStr, restDetail, coreC, resC, bankC, self:FormatNumber(goldOnly), filterTag))
            else
                mainFrame.statusBarText:SetText(string.format("ROUTE: %dC/%dR/%dB | ALL TARGET LEVELS REACHED | TRACKED: %d ALTS%s | WEALTH: %sg",
                    coreC, resC, bankC, summary.totalAlts or 0, filterTag, self:FormatNumber(goldOnly)))
            end
        else
            mainFrame.statusBarText:SetText(string.format("%s | ACTIVE: %s | TRACKED: %d ALTS%s | WEALTH: %sg",
                sysLabel, curFull or "Unknown", summary.totalAlts or 0, filterTag, self:FormatNumber(goldOnly)))
        end
    end

    -- Render Table Header Cells & Clickable Header Buttons
    local cols = self:GetColumns(activeTab)
    local isComp = self:IsCompact()
    local xOffset = 16
    local sortBy = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.sortBy
    local sortAsc = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.sortAsc

    for idx = 1, 8 do
        local hCell = mainFrame.headerCells and mainFrame.headerCells[idx]
        local btn = headerButtons[idx]
        local col = cols[idx]

        if col then
            local colW = isComp and (col.cpw or col.pw) or col.pw
            if hCell then
                hCell:ClearAllPoints()
                hCell:SetPoint("LEFT", mainFrame.headerFrame, "LEFT", xOffset, 0)
                hCell:SetWidth(colW)
                hCell:SetJustifyH(col.align or "LEFT")

                local title = col.title
                if col.sort and col.sort == sortBy then
                    local arrow = sortAsc and "^" or "v"
                    if col.align == "RIGHT" then
                        title = arrow .. title
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
                btn:ClearAllPoints()
                btn:SetPoint("LEFT", mainFrame.headerFrame, "LEFT", xOffset, 0)
                btn:SetSize(colW, 18)
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

    -- Retrieve Sorted Characters
    local chars = self:GetCharactersList(CLIAltsDB.settings.sortBy, CLIAltsDB.settings.sortAsc, self.activeFilter)
    totalPages = math.max(1, math.ceil(#chars / ROWS_COUNT))
    if currentPage > totalPages then currentPage = totalPages end
    if currentPage < 1 then currentPage = 1 end

    local filterSuffix = self.activeFilter and " FILTERED" or ""
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
        mainFrame.pageText:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 18, 68)
        mainFrame.pageText:SetText(string.format("TRACKED: %d ALTS%s", #chars, filterSuffix))
    end

    -- Render 12 Monospace Rows (Each with dedicated column cells)
    for rowIndex = 1, ROWS_COUNT do
        local row = rowFrames[rowIndex]
        local charIndex = (currentPage - 1) * ROWS_COUNT + rowIndex
        local char = chars[charIndex]

        if char then
            row.charData = char
            row:SetBackdropColor(0, 0, 0, (rowIndex % 2 == 0) and 0.25 or 0.1)

            local rowXOffset = 16
            for idx = 1, 8 do
                local cell = row.cells and row.cells[idx]
                local col = cols[idx]
                if cell then
                    if col then
                        local colW = isComp and (col.cpw or col.pw) or col.pw
                        cell:ClearAllPoints()
                        cell:SetPoint("LEFT", row, "LEFT", rowXOffset, 0)
                        cell:SetWidth(colW)
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
            row:Show()
        else
            row.charData = nil
            for idx = 1, 8 do
                local cell = row.cells and row.cells[idx]
                if cell then
                    cell:SetText("")
                    cell:Hide()
                end
            end
            row:Hide()
        end
    end
end

-- ----------------------------------------------------------------------------
-- Theme Application
-- ----------------------------------------------------------------------------
function CLIAlts:ApplyTheme()
    if not mainFrame then return end
    local t = self:GetTheme()

    mainFrame:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], t.bg[4])
    mainFrame:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], t.border[4])

    if mainFrame.topAscii then mainFrame.topAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
    if mainFrame.titleText then mainFrame.titleText:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3]) end
    if mainFrame.midAscii1 then mainFrame.midAscii1:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
    if mainFrame.statusBarText then mainFrame.statusBarText:SetTextColor(t.dim[1], t.dim[2], t.dim[3]) end
    if mainFrame.midAscii2 then mainFrame.midAscii2:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
    if mainFrame.tableTopAscii then mainFrame.tableTopAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
    if mainFrame.tableSepAscii then mainFrame.tableSepAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
    if mainFrame.tableBotAscii then mainFrame.tableBotAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
    if mainFrame.botAscii then mainFrame.botAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
    if mainFrame.headerBorderL then mainFrame.headerBorderL:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
    if mainFrame.headerBorderR then mainFrame.headerBorderR:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
    for _, row in ipairs(rowFrames) do
        if row.borderL then row.borderL:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
        if row.borderR then row.borderR:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8) end
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
            CLIAltsDB.settings.sortAsc = (key == "name" or key == "level")
        end
    end
    PlayRetroSound()
    currentPage = 1
    self:Render()
end

function CLIAlts:SwitchTab(tabId)
    tabId = tonumber(tabId)
    if not tabId or tabId < 1 or tabId > 5 then return end
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
    if not mainFrame or not mainFrame.promptStatusTip then return end
    local t = self:GetTheme()
    local color = isError and "|cffff4444" or t.highlightHex
    mainFrame.promptStatusTip:SetText(string.format("%s>> %s|r", color, msg or ""))

    local safeAfter = self.SafeAfter or (C_Timer and C_Timer.After)
    if safeAfter then
        safeAfter(4.0, function()
            if mainFrame and mainFrame.promptStatusTip then
                mainFrame.promptStatusTip:SetText("|cff888888[Commands: 1-5, sort <col>, filter <query>, find <text>, watch <item>, next, export, help]|r")
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

    if cmd == "1" or cmd == "2" or cmd == "3" or cmd == "4" or cmd == "5" then
        local tNum = tonumber(cmd)
        self:SwitchTab(tNum)
        self:SetPromptFeedback(string.format("Switched to Tab %d", tNum))

    elseif cmd == "tab" then
        local tNum = tonumber(args)
        if tNum and tNum >= 1 and tNum <= 5 then
            self:SwitchTab(tNum)
            self:SetPromptFeedback(string.format("Switched to Tab %d", tNum))
        else
            self:SetPromptFeedback("Usage: tab <1-5>", true)
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

    elseif cmd == "compact" or cmd == "c" then
        self:ToggleCompact()
        local isComp = self:IsCompact()
        self:SetPromptFeedback(string.format("Compact mode: %s (XP bars %s)", isComp and "ENABLED" or "DISABLED", isComp and "hidden" or "shown"))

    elseif cmd == "tooltips" or cmd == "tooltip" or cmd == "inv" then
        CLIAltsDB.settings.showInventoryTooltips = (CLIAltsDB.settings.showInventoryTooltips == false)
        local isEnabled = CLIAltsDB.settings.showInventoryTooltips
        self:SetPromptFeedback(string.format("Inventory hover tooltips: %s", isEnabled and "ENABLED" or "DISABLED"))

    elseif cmd == "theme" then
        if args and args ~= "" then
            local map = {
                green = "GREEN",
                amber = "AMBER",
                cyan = "CYAN",
                mono = "MONO",
                safe = "COLORBLIND",
                colorblind = "COLORBLIND",
                cb = "COLORBLIND",
                synthwave = "SYNTHWAVE",
                dracula = "DRACULA",
            }
            local choice = map[args:lower()]
            if choice then
                CLIAltsDB.settings.theme = choice
                self:ApplyTheme()
                self:Render()
                self:SetPromptFeedback(string.format("Theme set to %s", choice))
            else
                self:SetPromptFeedback("Themes: green, amber, cyan, mono, safe (colorblind)", true)
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
        "1", "2", "3", "4", "5",
        "sort", "filter", "find", "clear",
        "goto", "page", "next", "export", "compact",
        "watch", "unwatch", "watchlist",
        "theme", "scale", "perk", "perf", "selftest",
        "alerts", "digest", "plan", "note", "unlocked", "prune",
        "backup", "restore", "tooltips", "inv",
        "core", "alt", "bank", "unassign",
        "forever", "role",
        "refresh", "help", "exit", "close"
    }

    local cmd, arg = trimmed:match("^(%S+)%s+(.*)$")
    if cmd then
        cmd = cmd:lower()
        if cmd == "sort" then
            local sortKeys = { "name", "level", "cohort", "gold", "rested", "waste", "xp", "rotation", "next", "location", "hearth", "seen", "note" }
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
            local themes = { "green", "amber", "cyan", "mono", "safe", "colorblind", "synthwave", "dracula" }
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
function CLIAlts:ShowDossierPopup(char)
    if not char then return end

    if not dossierPopup then
        local dp = CreateFrame("Frame", "CLIAltsDossierPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        dp:SetSize(660, 520)
        dp:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        dp:SetFrameStrata("DIALOG")
        dp:EnableMouse(true)
        tinsert(UISpecialFrames, "CLIAltsDossierPopup")

        dp:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })

        local body = dp:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(body, 13)
        body:SetPoint("TOPLEFT", dp, "TOPLEFT", 16, -16)
        body:SetPoint("BOTTOMRIGHT", dp, "BOTTOMRIGHT", -16, 45)
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        dp.body = body

        local btnDel = CreateRetroButton(dp, "[ PURGE ]", 72, 20, function()
            dp:Hide()
            if dp.charData then
                CLIAlts:ShowConfirmDelete(dp.charData)
            end
        end)
        btnDel:SetPoint("BOTTOMLEFT", dp, "BOTTOMLEFT", 16, 16)

        local btnSetCore = CreateRetroButton(dp, "[ SET CORE (35) ]", 115, 20, function()
            if dp.charData then
                CLIAlts:SetCharacterRole(dp.charData.name, "CORE")
                CLIAlts:ShowDossierPopup(dp.charData)
                CLIAlts:RequestRender()
            end
        end)
        btnSetCore:SetPoint("LEFT", btnDel, "RIGHT", 6, 0)

        local btnSetAlt = CreateRetroButton(dp, "[ SET ALT (25) ]", 108, 20, function()
            if dp.charData then
                CLIAlts:SetCharacterRole(dp.charData.name, "RESERVE")
                CLIAlts:ShowDossierPopup(dp.charData)
                CLIAlts:RequestRender()
            end
        end)
        btnSetAlt:SetPoint("LEFT", btnSetCore, "RIGHT", 6, 0)

        local btnSetBank = CreateRetroButton(dp, "[ SET BANK (1) ]", 105, 20, function()
            if dp.charData then
                CLIAlts:SetCharacterRole(dp.charData.name, "BANK")
                CLIAlts:ShowDossierPopup(dp.charData)
                CLIAlts:RequestRender()
            end
        end)
        btnSetBank:SetPoint("LEFT", btnSetAlt, "RIGHT", 6, 0)

        local btnUnset = CreateRetroButton(dp, "[ UNSET ]", 70, 20, function()
            if dp.charData then
                CLIAlts:SetCharacterRole(dp.charData.name, "UNASSIGNED")
                CLIAlts:ShowDossierPopup(dp.charData)
                CLIAlts:RequestRender()
            end
        end)
        btnUnset:SetPoint("LEFT", btnSetBank, "RIGHT", 6, 0)

        local btnClose = CreateRetroButton(dp, "[ CLOSE ]", 75, 20, function()
            dp:Hide()
        end)
        btnClose:SetPoint("BOTTOMRIGHT", dp, "BOTTOMRIGHT", -16, 16)

        dossierPopup = dp
    end

    dossierPopup.charData = char
    local t = self:GetTheme()
    dossierPopup:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
    dossierPopup:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 1)

    local lines = {}
    table.insert(lines, "+==============================================================================+")
    table.insert(lines, "|                    CLIALTS :: ALT DOSSIER & RECORD                           |")
    table.insert(lines, "+==============================================================================+")

    if char.secondaryName and char.secondaryName ~= "" then
        table.insert(lines, string.format("| Full Name:      %s", self:ColorizePlayerName(char.fullName or char.name, char.classFile)))
        table.insert(lines, string.format("|   * First Name: |cffffffff%s|r", char.primaryName or char.name))
        table.insert(lines, string.format("|   * Surname:    |cffffffff%s|r", char.secondaryName))
    else
        table.insert(lines, string.format("| Character Name: %s", self:ColorizePlayerName(char.name, char.classFile)))
    end
    table.insert(lines, string.format("| System:         |cffffffff%s|r", self:GetClientFlavor()))
    if char.realm and char.realm ~= "" and char.realm ~= "Forever" then
        table.insert(lines, string.format("| Realm:          |cffffffff%s|r", char.realm))
    end
    table.insert(lines, string.format("| Faction / Race: %s |cffffffff%s (%s)|r", self:GetFactionTag(char.faction), self:FormatRace(char), self:GetRaceCode(char)))
    table.insert(lines, string.format("| Class / Level:  %s (Level |cffffffff%d|r)", self:ColorizePlayerName(char.class or "Unknown", char.classFile), char.level or 1))
    table.insert(lines, string.format("| Current Gold:   %s", self:FormatMoney(char.money, true)))

    local logoutZoneTag = char.loggedOutInRestZone and "|cff00ff66[REST AREA AT LOGOUT]|r" or "|cffffaa00[WILD AT LOGOUT]|r"
    table.insert(lines, string.format("| Location:       |cffffffff%s|r %s", char.location or "Unknown", logoutZoneTag))
    table.insert(lines, string.format("| Hearthstone:    |cffffffff%s|r", char.bindLocation or "Unknown"))
    local isStale, daysInactive = self:IsCharStale(char)
    local staleTag = isStale and string.format(" |cffff4444[STALE: %dd inactive]|r", daysInactive) or ""
    table.insert(lines, string.format("| Last Active:    |cffffffff%s|r (%s)%s", self:GetTimeAgo(char.lastUpdate), date("%b %d, %H:%M", char.lastUpdate or time()), staleTag))
    local noteStr = (char.note and char.note ~= "") and string.format("|cffffd700%s|r", char.note) or "|cff888888None (set with > note <name> <text>)|r"
    table.insert(lines, string.format("| Player Note:    %s", noteStr))
    table.insert(lines, "+------------------------------------------------------------------------------+")
    table.insert(lines, "| LEVEL EXPERIENCE PROGRESS:")

    local xpData = self:GetLevelProgressData(char)
    if xpData and not xpData.isMaxLevel then
        table.insert(lines, string.format("| Current XP:     |cffffffff%s / %s XP|r (%5.1f%% of Level %d)", self:FormatNumber(xpData.curXP), self:FormatNumber(xpData.maxXP), xpData.percentExact, char.level or 1))
        table.insert(lines, string.format("| Next Level:     |cffffffff%s XP needed|r to reach Level %d", self:FormatNumber(xpData.remainingXP), (char.level or 1) + 1))
        table.insert(lines, string.format("| Progress Bar:   %s%s|r %d%%", t.barFill, xpData.barStr, xpData.percent))
    else
        table.insert(lines, string.format("| Status:         |cff888888MAX LEVEL (Level %d reached)|r", char.level or self:GetMaxLevel()))
    end

    table.insert(lines, "+------------------------------------------------------------------------------+")
    table.insert(lines, string.format("| RESTED EXPERIENCE (%s):", self:GetClientFlavor()))

    local rested = self:GetRestedData(char)
    if rested and not rested.isMaxLevel then
        local est = rested.isEstimate and "~" or ""
        local restModeStr = rested.isResting and "+5.0% every 8h (Resting)" or "+1.25% every 8h (Wilderness)"
        table.insert(lines, string.format("| Rested Points:  |cffffffff%s%s / %s XP|r (%s%d%% of Level)", est, self:FormatNumber(rested.currentRested), self:FormatNumber(rested.maxRested), est, rested.percent))
        if not self:IsRetail() and rested.perkRank and rested.perkRank > 0 then
            table.insert(lines, string.format("| Rest Status:    %s (%s | Perk: R%d/5)", rested.statusStr, restModeStr, rested.perkRank))
            table.insert(lines, string.format("| Accumulation:   |cffffffff%s%s XP/hr|r (+%d%% speed bonus)", est, self:FormatNumber(math.floor((rested.ratePerSec or 0) * 3600)), rested.perkRank * 4))
        else
            table.insert(lines, string.format("| Rest Status:    %s (%s)", rested.statusStr, restModeStr))
            table.insert(lines, string.format("| Accumulation:   |cffffffff%s%s XP/hr|r", est, self:FormatNumber(math.floor((rested.ratePerSec or 0) * 3600))))
        end
        table.insert(lines, string.format("| Progress Bar:   %s%s|r %s%d%%", t.barFill, rested.barStr, est, rested.percent))
        table.insert(lines, string.format("| Time to %d%%:   |cffffffff%s|r", rested.maxPercent or 150, rested.timeLeftStr))
        table.insert(lines, string.format("| Projected Date: |cffffffff%s|r", rested.fullDate))
        if rested.isEstimate then
            table.insert(lines, "| Note:           |cffffaa00Estimated projection (~disconnect / crash)|r")
        end
    else
        table.insert(lines, "| Rest Status:    |cff888888N/A (Max Level characters do not accumulate Rested XP)|r")
    end

    if self:IsForeverMode() or (char.tier and char.tier ~= "UNASSIGNED") then
        table.insert(lines, "+------------------------------------------------------------------------------+")
        local tierStr = char.tier or "UNASSIGNED"
        local tgtLvl = char.target_level or ((tierStr == "CORE" and 35) or (tierStr == "RESERVE" and 25) or (tierStr == "BANK" and 1) or 60)
        local curLvl = char.level or 1
        local statusTag = (curLvl >= tgtLvl) and " |cff00ff66[Target Level Reached]|r" or ""
        table.insert(lines, string.format("| WOW FOREVER ROUTE: |cffffd700[%s]|r (Target Level: |cffffffff%d|r)%s", tierStr, tgtLvl, statusTag))
        local roleStr = (char.supply_role and char.supply_role ~= "") and string.format("|cffffffff%s|r", char.supply_role) or "|cff888888None (set via > role <name> <tier> [role])|r"
        table.insert(lines, string.format("| Supply Role:       %s", roleStr))
    end

    table.insert(lines, "+------------------------------------------------------------------------------+")
    table.insert(lines, "| PROFESSIONS & CRAFTING:")
    if char.professions and char.professions.primary and #char.professions.primary > 0 then
        for _, p in ipairs(char.professions.primary) do
            table.insert(lines, string.format("|  * Primary:   |cffffffff%-16s|r %3d / %-3d", p.name or "Unknown", p.rank or 0, p.maxRank or 0))
        end
    else
        table.insert(lines, "|  * Primary:   |cff888888None learned|r")
    end
    if char.professions and char.professions.secondary and #char.professions.secondary > 0 then
        for _, s in ipairs(char.professions.secondary) do
            table.insert(lines, string.format("|  * Secondary: |cffffffff%-16s|r %3d / %-3d", s.name or "Unknown", s.rank or 0, s.maxRank or 0))
        end
    end
    table.insert(lines, "+==============================================================================+")

    dossierPopup.body:SetText(table.concat(lines, "\n"))
    dossierPopup:Show()
end

-- ----------------------------------------------------------------------------
-- Confirmation Modal (Delete Character)
-- ----------------------------------------------------------------------------
function CLIAlts:ShowConfirmDelete(char)
    if not char then return end

    if not confirmPopup then
        local cp = CreateFrame("Frame", "CLIAltsConfirmPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
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
        "+=======================================+",
        "|       PURGE CHARACTER RECORD?         |",
        "+=======================================+",
        "",
        string.format("Are you sure you want to delete"),
        string.format("|cffff4444%s|r", cleanKey),
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
        "+=======================================+",
        "|         BULK PRUNE STALE ALTS?        |",
        "+=======================================+",
        "",
        string.format("Delete |cffff4444%d characters|r inactive for %d+ days?", count, days),
        string.format("|cffffaa00%s|r", sampleStr),
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
        hp:SetSize(560, 560)
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

        local body = hp:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(body, 13)
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

    local helpText = {
        "+====================================================================+",
        "|                 CLIALTS :: QUICK GUIDE & COMMANDS                  |",
        "+====================================================================+",
        "| Slash Commands:                                                    |",
        "|   /clialts            - Toggle the main TUI monitor                |",
        "|   /clialts [1-5]      - Open directly to specific tab (1-5)        |",
        "|   /clialts compact    - Toggle compact view (hide XP bar, slim)    |",
        "|   /clialts next       - Recommend top 3 alts with rested XP waste  |",
        "|   /clialts watch <it> - Track item count in bags & bank (e.g. ore) |",
        "|   /clialts watchlist  - Print tracked items summary                |",
        "|   /clialts export     - Open CSV export dialog for spreadsheets    |",
        "|   /clialts scale <val>- Set UI scale (0.7 to 1.8, e.g. 1.2 / 120%) |",
        "|   /clialts font <sz>  - Set terminal font size (12 to 22)          |",
        "|   /clialts track      - Force save current character to tracker    |",
        "|   /clialts rested     - Print quick rested XP report to chat       |",
        "|   /clialts perk <0-5> - Set Well Rested legacy perk rank (0-5)     |",
        "|   /clialts gold       - Print total account gold summary           |",
        "|   /clialts perf       - Print smoothed Collect/Render ms & memory  |",
        "|   /clialts selftest   - Run unit assertions with fake timestamps   |",
        "|   /clialts alerts     - Toggle login alert categories (cd/rest/mail|",
        "|   /clialts digest     - Display boxed login summary digest now     |",
        "|   /clialts plan [hrs] - Print leveling plan schedule (default: 2h) |",
        "|   /clialts note <who> <txt> - Set/view alt note (clear to remove)   |",
        "|   /clialts unlocked <inst> - List alts with no active lock (gap finder)|",
        "|   /clialts prune <days> [confirm] - Bulk purge alts inactive for N days|",
        "|   /clialts tooltips   - Toggle item hover tooltips (bags/bank alts)|",
        "|   /clialts forever    - Toggle WoW Forever Cohort mode (auto-active)|",
        "|   /clialts core <who> - Set Core cohort (Target Level 35)          |",
        "|   /clialts alt <who>  - Set Alt/Reserve cohort (Target Level 25)   |",
        "|   /clialts bank <who> - Set Bank mule (Target Level 1)             |",
        "|   /clialts backup     - Save one-slot snapshot to CLIAltsDB.backup |",
        "|   /clialts restore    - Restore database from CLIAltsDB.backup     |",
        "|   /clialts reset      - Reset window position to center            |",
        "+--------------------------------------------------------------------+",
        "| Interactive Terminal Command Prompt (>):                           |",
        "|   > 1 .. 5            - Switch tab (Overview, Rest, Prof, Econ, Cd)|",
        "|   > compact           - Toggle compact view (hide XP bar, slim)    |",
        "|   > sort <column>     - Sort table (name, lvl, cohort, gold, rest) |",
        "|   > filter <query>    - Filter alts (alliance, horde, stale, <60)  |",
        "|   > find <text>       - Search character names, classes, or zones  |",
        "|   > clear             - Clear active filter query                  |",
        "|   > next              - Print alts with highest rested waste       |",
        "|   > watch <item>      - Add item to bag/bank inventory tracker     |",
        "|   > tooltips / inv    - Toggle item hover tooltips (bags/bank alts)|",
        "|   > core <who> [tgt]  - Set Core cohort (Target 35)                |",
        "|   > alt <who> [tgt]   - Set Alt/Reserve cohort (Target 25)         |",
        "|   > bank <who>        - Set Bank mule (Target 1)                   |",
        "|   > unassign <who>    - Unassign cohort / restore Target 60        |",
        "|   > export            - Open CSV export modal dialog               |",
        "|   > theme [name]      - Cycle or set color theme (incl. safe/cb)   |",
        "|   > perf              - Output profiling exponential moving average|",
        "|   > selftest          - Execute automated test suite in chat       |",
        "|   > alerts [cat]      - Configure login alert category toggles     |",
        "|   > digest            - Render boxed login alert digest in chat    |",
        "|   > plan [hours]      - Compute ordered leveling session schedule  |",
        "|   > note <who> <text>  - Set/view alt note (e.g. farm mooncloth)   |",
        "|   > unlocked <inst>   - List alts with no active lock (gap finder)     |",
        "|   > prune <days>      - Bulk purge alts inactive for N days        |",
        "|   > backup / restore  - Create database snapshot or roll back      |",
        "|   > Up / Down arrows  - Browse terminal command history            |",
        "|   > Tab key           - Auto-complete commands and column names    |",
        "+--------------------------------------------------------------------+",
        "| Interactions:                                                      |",
        "|   - Click [COMPACT] on title bar or type > compact in prompt       |",
        "|   - Click [SCALE] on title bar to cycle 100%, 115%, 130%, 145%, 90%|",
        "|   - Click [THEME] on title bar to cycle CRT retro color palettes   |",
        "|   - Click column title in header line to sort ascending/descending |",
        "|   - Left-Click any character row to inspect full Dossier           |",
        "|   - Shift-Click any character row to cycle Cohort (Core/Alt/Bank)  |",
        "|   - Right-Click any character row to delete character record       |",
        "|   - Mouse wheel over table to scroll pages                         |",
        "|   - Drag Minimap icon to move outside of minimap                   |",
        "+--------------------------------------------------------------------+",
    }
    if self:IsRetail() then
        table.insert(helpText, "| Rested XP Mechanics (Retail):                                       |")
        table.insert(helpText, "|   - Resting in Inn/City/Camp: +5% of level every 8h (10 days base) |")
        table.insert(helpText, "|   - Logged in Wilderness:     +1.25% every 8h (40 days base)       |")
        table.insert(helpText, "|   - Maximum Rested Cap:       150% of level (1.5 bars)             |")
    else
        table.insert(helpText, "| Rested XP Mechanics (WoW Forever):                                 |")
        table.insert(helpText, "|   - Resting in Inn/City/Camp: +5% of level every 8h (10 days base) |")
        table.insert(helpText, "|   - Logged in Wilderness:     +1.25% every 8h (40 days base)       |")
        table.insert(helpText, "|   - Well Rested Legacy Perk:  +4% speed & +4% cap per rank (max 5) |")
    end
    table.insert(helpText, "+====================================================================+")

    helpPopup.body:SetText(table.concat(helpText, "\n"))
    helpPopup:Show()
end

-- ----------------------------------------------------------------------------
-- CSV Export Modal (Copyable Multi-Line Dialog)
-- ----------------------------------------------------------------------------
local exportPopup = nil
function CLIAlts:ShowExportPopup()
    if not exportPopup then
        local ep = CreateFrame("Frame", "CLIAltsExportPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
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

        local title = ep:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(title, 14, "BOLD")
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
-- Window Toggle & Refresh
-- ----------------------------------------------------------------------------
function CLIAlts:Toggle(show)
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
end

function CLIAlts:Refresh()
    self:CollectCurrentCharacter()
    self:ApplyTheme()
    self:Render()
    self:Print("Database refreshed.")
end

-- ----------------------------------------------------------------------------
-- Cross-Character Inventory Tooltip Hooks & Formatter (Feature 6)
-- ----------------------------------------------------------------------------
function CLIAlts:AddInventoryInfoToTooltip(tooltip, itemID)
    if not tooltip or not itemID then return end
    if not CLIAltsDB or not CLIAltsDB.settings or CLIAltsDB.settings.showInventoryTooltips == false then
        return
    end

    -- Guard against duplicate additions within the same tooltip rendering pass
    if tooltip._clialtsProcessed == itemID then
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
                    tooltip._clialtsProcessed = itemID
                    return
                end
            end
        end
    end

    local totalCount, breakdown = self:GetItemInventorySummary(itemID)
    if totalCount <= 0 or not breakdown or #breakdown == 0 then
        return
    end

    tooltip._clialtsProcessed = itemID

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
end

function CLIAlts:InitTooltipHooks()
    if self.tooltipHooksInitialized then return end
    self.tooltipHooksInitialized = true

    local function ResetTooltipFlag(tooltip)
        if tooltip then
            tooltip._clialtsProcessed = nil
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
            if not tooltip or not data then return end
            local itemID = data.id
            if not itemID and tooltip.GetItem then
                local _, link = tooltip:GetItem()
                if link then itemID = tonumber(link:match("item:(%d+)")) end
            end
            if itemID then
                CLIAlts:AddInventoryInfoToTooltip(tooltip, itemID)
            end
        end)
    else
        local function OnTooltipSetItem(tooltip)
            if not tooltip or not tooltip.GetItem then return end
            local _, link = tooltip:GetItem()
            if link then
                local itemID = tonumber(link:match("item:(%d+)"))
                if itemID then
                    CLIAlts:AddInventoryInfoToTooltip(tooltip, itemID)
                end
            end
        end

        if GameTooltip and GameTooltip.HookScript then
            GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
        end
        if ItemRefTooltip and ItemRefTooltip.HookScript then
            ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
        end
    end
end

