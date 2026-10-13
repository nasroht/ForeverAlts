-- ============================================================================
-- CLIAlts: Retro Alt Tracker
-- File: ui.lua
-- Pure Monospace ASCII / TUI Terminal Interface with data-driven columns,
-- single FontString rows, VT323 CRT terminal typography, and SetScale support.
-- ============================================================================

local addonName, addonTable = ...
local CLIAlts = addonTable

-- ----------------------------------------------------------------------------
-- Constants & Terminal Configuration
-- ----------------------------------------------------------------------------
local FONT_PATH = "Interface\\AddOns\\clialts\\media\\VT323-Regular.ttf"
local DEFAULT_FONT_SIZE = 15
local LINE_WIDTH = 85
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
}

local THEME_ORDER = { "GREEN", "AMBER", "CYAN", "MONO" }
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
    if not fontString then return end
    size = size or (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.fontSize) or DEFAULT_FONT_SIZE
    flags = flags or ""
    local success = pcall(function()
        fontString:SetFont(FONT_PATH, size, flags)
    end)
    if not success or not fontString:GetFont() then
        fontString:SetFont("Fonts\\ARIALN.TTF", size, flags)
    end
end

function CLIAlts:GetCharWidth(fontSize)
    if not probeString and mainFrame then
        probeString = mainFrame:CreateFontString(nil, "BACKGROUND")
        probeString:Hide()
    end
    if probeString then
        self:SetWidgetFont(probeString, fontSize or DEFAULT_FONT_SIZE)
        probeString:SetText(string.rep("X", LINE_WIDTH))
        local w = probeString:GetStringWidth()
        if w and w > 0 then
            return w / LINE_WIDTH
        end
    end
    return (fontSize or DEFAULT_FONT_SIZE) * 0.52
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
    self:SetWidgetFont(mainFrame.tableHeaderString, fontSize)
    self:SetWidgetFont(mainFrame.tableSepAscii, fontSize)
    self:SetWidgetFont(mainFrame.tableBotAscii, fontSize)
    self:SetWidgetFont(mainFrame.botAscii, fontSize)
    self:SetWidgetFont(mainFrame.pageText, fontSize)
    self:SetWidgetFont(mainFrame.statusTip, fontSize)

    for _, row in ipairs(rowFrames) do
        self:SetWidgetFont(row.text, fontSize)
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
    return CLIAlts:Pad(name, 16, "LEFT", hex)
end

local function FmtLevel(char)
    local lvl = tostring(char.level or 1)
    return CLIAlts:Pad(lvl, 3, "RIGHT", "ffffff")
end

local function FmtRaceClass(char)
    local code = CLIAlts:GetRaceCode(char)
    local class = char.class or "Unknown"
    local str = string.format("%s %s", code, class)
    return CLIAlts:Pad(str, 11, "LEFT", "cccccc")
end

local function FmtLevelProgress(char, t)
    local xpData = CLIAlts:GetLevelProgressData(char)
    if not xpData or xpData.isMaxLevel then
        return string.format("|cff%s[|r|cff%s%s|r|cff%s]|r |cff%sMAX |r",
            t.borderHex, t.dimHex, string.rep("=", 10), t.borderHex, t.highlightHex)
    end

    local fill = math.min(10, math.max(0, math.floor((xpData.ratio or 0) * 10)))
    local empty = 10 - fill
    local fillStr = string.rep("=", fill)
    local emptyStr = string.rep(".", empty)
    local pctStr = string.format("%3d%%", xpData.percent)

    return string.format("|cff%s[|r|cff%s%s|r|cff%s%s|r|cff%s]|r |cff%s%s|r",
        t.borderHex, t.highlightHex, fillStr, t.dimHex, emptyStr, t.borderHex, t.primaryHex, pctStr)
end

local function FmtGold(char)
    local gold = math.floor((char.money or 0) / 10000)
    local str = CLIAlts:FormatNumber(gold) .. "g"
    return CLIAlts:Pad(str, 10, "RIGHT", "ffd700")
end

local function FmtRested(char, t)
    local rested = CLIAlts:GetRestedData(char)
    if not rested then return CLIAlts:Pad("---", 8, "RIGHT", "666666") end
    if rested.isMaxLevel then return CLIAlts:Pad("MAX", 8, "RIGHT", "888888") end

    local est = rested.isEstimate and "~" or " "
    local pct = string.format("%3d%%%s", rested.percent, est)
    local color = rested.isFull and t.highlightHex or t.primaryHex
    return CLIAlts:Pad(pct, 8, "RIGHT", color)
end

local function FmtETA(char, t)
    local rested = CLIAlts:GetRestedData(char)
    if not rested then return CLIAlts:Pad("---", 7, "RIGHT", "666666") end
    if rested.isMaxLevel then return CLIAlts:Pad("MAX", 7, "RIGHT", "888888") end
    if rested.isFull then
        local wastedSec, wastedXP, _, timeStr = CLIAlts:GetRestedWaste(char)
        if wastedSec and wastedSec > 3600 then
            return CLIAlts:Pad("+" .. (timeStr or "1h"), 7, "RIGHT", "ff5555")
        else
            return CLIAlts:Pad("FULL", 7, "RIGHT", t.highlightHex)
        end
    end

    local s = rested.timeLeftStr or "---"
    return CLIAlts:Pad(s, 7, "RIGHT", t.dimHex)
end

-- Tab 2 Rested Monitor Formatters
local function FmtRestedPool(char, t)
    local rested = CLIAlts:GetRestedData(char)
    if not rested or rested.isMaxLevel then
        return CLIAlts:Pad("MAX LEVEL", 17, "RIGHT", "888888")
    end
    local s = string.format("%s / %s", CLIAlts:FormatNumber(rested.currentRested), CLIAlts:FormatNumber(rested.maxRested))
    return CLIAlts:Pad(s, 17, "RIGHT", t.primaryHex)
end

local function FmtRestedBar(char, t)
    local rested = CLIAlts:GetRestedData(char)
    if not rested or rested.isMaxLevel then
        return string.format("|cff%s[|r|cff%s%s|r|cff%s]|r |cff%sMAX  |r",
            t.borderHex, t.dimHex, string.rep("=", 10), t.borderHex, t.highlightHex)
    end

    local ratio = math.min(1.0, math.max(0, rested.ratio or 0))
    local fill = math.min(10, math.max(0, math.floor(ratio * 10)))
    local empty = 10 - fill
    local fillStr = string.rep("=", fill)
    local emptyStr = string.rep(".", empty)
    local est = rested.isEstimate and "~" or " "
    local pctStr = string.format("%3d%%%s", rested.percent, est)

    return string.format("|cff%s[|r|cff%s%s|r|cff%s%s|r|cff%s]|r |cff%s%s|r",
        t.borderHex, rested.isFull and t.highlightHex or t.primaryHex, fillStr, t.dimHex, emptyStr, t.borderHex, t.primaryHex, pctStr)
end

local function FmtRate(char, t)
    local rested = CLIAlts:GetRestedData(char)
    if not rested or rested.isMaxLevel then
        return CLIAlts:Pad("---", 8, "RIGHT", "666666")
    end
    local s = rested.isResting and "+5.0%/8h" or "+1.25%/8h"
    return CLIAlts:Pad(s, 8, "RIGHT", t.dimHex)
end

local function FmtState(char, t)
    local rested = CLIAlts:GetRestedData(char)
    if not rested or rested.isMaxLevel then
        return CLIAlts:Pad("---", 7, "CENTER", "666666")
    end
    if rested.isResting then
        return "|cff00ff66[REST]|r "
    else
        return "|cffffaa00[WILD]|r "
    end
end

-- Tab 3 Profession Formatters
local function FmtProf1(char, t)
    local profs = char.professions and char.professions.primary
    local p = profs and profs[1]
    if not p then return CLIAlts:Pad("---", 23, "LEFT", "666666") end
    local str = string.format("%s %d/%d", p.name or "Prof", p.rank or 0, p.maxRank or 0)
    return CLIAlts:Pad(str, 23, "LEFT", t.primaryHex)
end

local function FmtProf2(char, t)
    local profs = char.professions and char.professions.primary
    local p = profs and profs[2]
    if not p then return CLIAlts:Pad("---", 20, "LEFT", "666666") end
    local str = string.format("%s %d/%d", p.name or "Prof", p.rank or 0, p.maxRank or 0)
    return CLIAlts:Pad(str, 20, "LEFT", t.primaryHex)
end

local function FmtSecProf(char, t)
    local secs = char.professions and char.professions.secondary
    if not secs or #secs == 0 then return CLIAlts:Pad("---", 14, "LEFT", "666666") end
    local parts = {}
    for _, s in ipairs(secs) do
        local shortName = s.name:sub(1, 4)
        table.insert(parts, string.format("%s %d", shortName, s.rank or 0))
    end
    local str = table.concat(parts, ", ")
    return CLIAlts:Pad(str, 14, "LEFT", t.dimHex)
end

-- Tab 4 Economy Formatters
local function FmtGoldLong(char)
    local gold = math.floor((char.money or 0) / 10000)
    local str = CLIAlts:FormatNumber(gold) .. "g"
    return CLIAlts:Pad(str, 12, "RIGHT", "ffd700")
end

local function FmtWealthShare(char, t)
    local summary = CLIAlts:GetAccountSummary()
    local total = summary.totalGold or 0
    local money = char.money or 0
    local pct = total > 0 and (money / total * 100) or 0
    local str = string.format("%5.1f%%", pct)
    return CLIAlts:Pad(str, 8, "RIGHT", t.primaryHex)
end

local function FmtWealthBar(char, t)
    local summary = CLIAlts:GetAccountSummary()
    local total = summary.totalGold or 0
    local money = char.money or 0
    local ratio = total > 0 and math.min(1.0, math.max(0, money / total)) or 0
    local fill = math.min(10, math.max(0, math.floor(ratio * 10)))
    local empty = 10 - fill
    local fillStr = string.rep("=", fill)
    local emptyStr = string.rep(".", empty)
    return string.format("|cff%s[|r|cffffd700%s|r|cff%s%s|r|cff%s]|r  ",
        t.borderHex, fillStr, t.dimHex, emptyStr, t.borderHex)
end

local function FmtLocation(char, t)
    local loc = char.location or "Unknown"
    return CLIAlts:Pad(loc, 23, "LEFT", t.dimHex)
end

-- Tab 5 Cooldowns & Lockouts Formatters
local function FmtTradeCooldowns(char, t)
    local cds = char.tradeCooldowns
    if not cds or not next(cds) then
        return CLIAlts:Pad("NO COOLDOWNS", 25, "LEFT", "666666")
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
    if #parts == 0 then return CLIAlts:Pad("READY", 25, "LEFT", "00ff66") end
    local str = table.concat(parts, ", ")
    return CLIAlts:Pad(str, 25, "LEFT", t.primaryHex)
end

local function FmtRaidLocks(char, t)
    local locks = char.lockouts
    if not locks or not next(locks) then
        return CLIAlts:Pad("NO SAVED LOCKS", 30, "LEFT", "666666")
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
    if #parts == 0 then return CLIAlts:Pad("NO ACTIVE LOCKS", 30, "LEFT", "666666") end
    local str = table.concat(parts, ", ")
    return CLIAlts:Pad(str, 30, "LEFT", t.dimHex)
end

-- ----------------------------------------------------------------------------
-- Data-Driven Columns Table (COLS) - Exactly 85 Characters Per Tab
-- ----------------------------------------------------------------------------
local COLS = {
    [1] = { -- ALTS OVERVIEW (Width = 85 chars)
        { key = "fac",       title = "FAC",            w = 3,  align = "CENTER", fmt = FmtFaction },
        { key = "name",      title = "NAME",           w = 16, align = "LEFT",   sort = "name",    fmt = FmtName },
        { key = "lvl",       title = "LVL",            w = 3,  align = "RIGHT",  sort = "level",   fmt = FmtLevel },
        { key = "raceClass", title = "RACE/CLASS",     w = 11, align = "LEFT",   fmt = FmtRaceClass },
        { key = "xp",        title = "LEVEL PROGRESS", w = 16, align = "LEFT",   sort = "xp",      fmt = FmtLevelProgress },
        { key = "gold",      title = "GOLD",           w = 10, align = "RIGHT",  sort = "gold",    fmt = FmtGold },
        { key = "rested",    title = "RESTED",         w = 8,  align = "RIGHT",  sort = "rested",  fmt = FmtRested },
        { key = "eta",       title = "ETA",            w = 7,  align = "RIGHT",  fmt = FmtETA },
    },
    [2] = { -- RESTED XP MONITOR (Width = 85 chars)
        { key = "fac",       title = "FAC",             w = 3,  align = "CENTER", fmt = FmtFaction },
        { key = "name",      title = "NAME",            w = 16, align = "LEFT",   sort = "name",   fmt = FmtName },
        { key = "lvl",       title = "LVL",             w = 3,  align = "RIGHT",  sort = "level",  fmt = FmtLevel },
        { key = "pool",      title = "RESTED / CAP",    w = 17, align = "RIGHT",  sort = "rested", fmt = FmtRestedPool },
        { key = "restBar",   title = "RESTED PROGRESS", w = 17, align = "LEFT",   fmt = FmtRestedBar },
        { key = "rate",      title = "RATE",            w = 8,  align = "RIGHT",  fmt = FmtRate },
        { key = "state",     title = "STATE",           w = 7,  align = "CENTER", fmt = FmtState },
        { key = "eta",       title = "ETA/WST",         w = 7,  align = "RIGHT",  sort = "waste",  fmt = FmtETA },
    },
    [3] = { -- PROFESSIONS (Width = 85 chars)
        { key = "fac",       title = "FAC",             w = 3,  align = "CENTER", fmt = FmtFaction },
        { key = "name",      title = "NAME",            w = 16, align = "LEFT",   sort = "name",   fmt = FmtName },
        { key = "lvl",       title = "LVL",             w = 3,  align = "RIGHT",  sort = "level",  fmt = FmtLevel },
        { key = "prof1",     title = "PRIMARY PROF 1",  w = 23, align = "LEFT",   fmt = FmtProf1 },
        { key = "prof2",     title = "PRIMARY PROF 2",  w = 20, align = "LEFT",   fmt = FmtProf2 },
        { key = "sec",       title = "SECONDARY",       w = 14, align = "LEFT",   fmt = FmtSecProf },
    },
    [4] = { -- ECONOMY / WEALTH (Width = 85 chars)
        { key = "fac",       title = "FAC",             w = 3,  align = "CENTER", fmt = FmtFaction },
        { key = "name",      title = "NAME",            w = 16, align = "LEFT",   sort = "name",   fmt = FmtName },
        { key = "lvl",       title = "LVL",             w = 3,  align = "RIGHT",  sort = "level",  fmt = FmtLevel },
        { key = "gold",      title = "GOLD",            w = 12, align = "RIGHT",  sort = "gold",   fmt = FmtGoldLong },
        { key = "share",     title = "SHARE",           w = 8,  align = "RIGHT",  fmt = FmtWealthShare },
        { key = "bar",       title = "WEALTH SHARE",    w = 14, align = "LEFT",   fmt = FmtWealthBar },
        { key = "location",  title = "LAST LOCATION",   w = 23, align = "LEFT",   fmt = FmtLocation },
    },
    [5] = { -- COOLDOWNS & SAVED LOCKS (Width = 85 chars)
        { key = "fac",       title = "FAC",             w = 3,  align = "CENTER", fmt = FmtFaction },
        { key = "name",      title = "NAME",            w = 16, align = "LEFT",   sort = "name",   fmt = FmtName },
        { key = "lvl",       title = "LVL",             w = 3,  align = "RIGHT",  sort = "level",  fmt = FmtLevel },
        { key = "tradeCd",   title = "TRADE COOLDOWNS", w = 25, align = "LEFT",   fmt = FmtTradeCooldowns },
        { key = "raidLocks", title = "SAVED INSTANCES / LOCKS", w = 30, align = "LEFT", fmt = FmtRaidLocks },
    },
}

function CLIAlts:BuildHeaderLine(activeTab, t)
    local cols = COLS[activeTab] or COLS[1]
    local sortBy = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.sortBy
    local sortAsc = CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.sortAsc
    local parts = {}

    for _, col in ipairs(cols) do
        local title = col.title
        if col.sort and col.sort == sortBy then
            local arrow = sortAsc and "^" or "v"
            if col.align == "RIGHT" then
                title = arrow .. title
            else
                title = title .. arrow
            end
        end
        local padded = self:Pad(title, col.w, col.align or "LEFT", t.highlightHex)
        table.insert(parts, padded)
    end

    return "| " .. table.concat(parts, " ") .. " |"
end

-- ----------------------------------------------------------------------------
-- Main Frame Construction
-- ----------------------------------------------------------------------------
function CLIAlts:CreateMainFrame()
    if mainFrame then return mainFrame end

    local frame = CreateFrame("Frame", "CLIAltsMainFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:Hide()
    frame:SetSize(780, 535)
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
    titleText:SetText("[#] CLIALTS :: RETRO TERMINAL ALT MONITOR v" .. CLIAlts.VERSION)
    frame.titleText = titleText

    -- Window Controls on Title Bar (Scale, Theme, Help, Refresh, Close)
    local btnClose = CreateRetroButton(frame, "[ X ]", 34, 18, function()
        CLIAlts:Toggle(false)
    end)
    btnClose:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -20)

    local btnHelp = CreateRetroButton(frame, "[ ? ]", 34, 18, function()
        CLIAlts:ShowHelpPopup()
    end)
    btnHelp:SetPoint("RIGHT", btnClose, "LEFT", -6, 0)

    local btnScale = CreateRetroButton(frame, string.format("[ SCALE: %d%% ]", math.floor(s * 100 + 0.5)), 95, 18, function()
        CLIAlts:CycleScale()
    end)
    btnScale:SetPoint("RIGHT", btnHelp, "LEFT", -6, 0)
    frame.btnScale = btnScale

    local btnTheme = CreateRetroButton(frame, "[ THEME: GRN ]", 100, 18, function()
        CLIAlts:CycleTheme()
    end)
    btnTheme:SetPoint("RIGHT", btnScale, "LEFT", -6, 0)
    frame.btnTheme = btnTheme

    local btnRefresh = CreateRetroButton(frame, "[ REFRESH ]", 80, 18, function()
        CLIAlts:Refresh()
    end)
    btnRefresh:SetPoint("RIGHT", btnTheme, "LEFT", -6, 0)

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
    local btnPerk = CreateRetroButton(frame, "[ PERK: R0 (+0%) ]", 145, 18, function()
        CLIAlts:CycleWellRestedPerk()
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
        local t = CLIAlts:GetTheme()
        self:SetBackdropColor(0, 0, 0, 0.6)
        GameTooltip:Hide()
    end)
    frame.btnPerk = btnPerk

    local midAscii2 = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(midAscii2, fontSize)
    midAscii2:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -66)
    midAscii2:SetText(BORDER_LINE)
    frame.midAscii2 = midAscii2

    -- Retro Tabs
    local tabs = {
        { id = 1, text = "[ ALTS OVERVIEW ]" },
        { id = 2, text = "[ RESTED XP ]" },
        { id = 3, text = "[ PROFESSIONS ]" },
        { id = 4, text = "[ ECONOMY ]" },
        { id = 5, text = "[ COOLDOWNS ]" },
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
        table.insert(frame.tabButtons, tabBtn)
        prevTab = tabBtn
    end

    -- Header top border ASCII line
    local tableTopAscii = frame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(tableTopAscii, fontSize)
    tableTopAscii:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -106)
    tableTopAscii:SetText(DOUBLE_BORDER)
    frame.tableTopAscii = tableTopAscii

    -- Column Header Line (Monospace Text) & Clickable Hit Frame
    local headerFrame = CreateFrame("Frame", nil, frame)
    headerFrame:SetSize(756, 18)
    headerFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -120)
    frame.headerFrame = headerFrame

    local tableHeaderString = headerFrame:CreateFontString(nil, "OVERLAY")
    self:SetWidgetFont(tableHeaderString, fontSize)
    tableHeaderString:SetPoint("LEFT", headerFrame, "LEFT", 0, 0)
    tableHeaderString:SetJustifyH("LEFT")
    frame.tableHeaderString = tableHeaderString

    -- Clickable Header Buttons for Sorting
    for i = 1, 8 do
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
    rowsContainer:SetSize(756, ROWS_COUNT * 21)
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

    -- Create 12 Monospace Row Buttons (One FontString Per Row)
    for i = 1, ROWS_COUNT do
        local row = CreateFrame("Button", nil, rowsContainer, BackdropTemplateMixin and "BackdropTemplate" or nil)
        row:SetSize(756, 20)
        row:SetPoint("TOPLEFT", rowsContainer, "TOPLEFT", 0, -((i - 1) * 21))

        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        row:SetBackdropColor(0, 0, 0, 0.2)
        row:SetBackdropBorderColor(0, 0, 0, 0)

        local rowText = row:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(rowText, fontSize)
        rowText:SetPoint("LEFT", row, "LEFT", 0, 0)
        rowText:SetJustifyH("LEFT")
        rowText:SetWordWrap(false)
        row.text = rowText

        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, button)
            if self.charData then
                if button == "RightButton" then
                    CLIAlts:ShowConfirmDelete(self.charData)
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
                    GameTooltip:AddLine(string.format("Rested Pool: |cffffffff%s%s XP|r (%s%d%% of level, %s)",
                        est, CLIAlts:FormatNumber(rested.currentRested), est, rested.percent, rested.statusStr), 0.8, 0.8, 0.8)
                    GameTooltip:AddLine(string.format("Time to Capped: |cffffffff%s|r (%s)", rested.timeLeftStr, rested.fullDate), 0.8, 0.8, 0.8)
                    if rested.isEstimate then
                        GameTooltip:AddLine("|cffffaa00* Rested values are estimated (~disconnect / crash)|r", 1, 0.8, 0)
                    end
                end

                GameTooltip:AddLine("Left-Click: Open Alt Dossier | Right-Click: Delete Character", 0.7, 0.7, 0.7)
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

    -- Hidden Buttons for Enter and / keyboard focus overrides
    local btnFocusEnter = CreateFrame("Button", "CLIAltsFocusEnterBtn", frame)
    btnFocusEnter:SetScript("OnClick", function()
        if frame:IsShown() and frame.promptBox and not frame.promptBox:HasFocus() then
            frame.promptBox:SetFocus()
        end
    end)

    local btnFocusSlash = CreateFrame("Button", "CLIAltsFocusSlashBtn", frame)
    btnFocusSlash:SetScript("OnClick", function()
        if frame:IsShown() and frame.promptBox and not frame.promptBox:HasFocus() then
            frame.promptBox:SetFocus()
            frame.promptBox:SetText("")
        end
    end)

    -- Propagate keyboard input support (WoW Classic Era / modern client)
    if frame.SetPropagateKeyboardInput then
        frame:SetPropagateKeyboardInput(true)
        frame:EnableKeyboard(true)
        frame:SetScript("OnKeyDown", function(self, key)
            if frame.promptBox and not frame.promptBox:HasFocus() then
                if key == "ENTER" or key == "SLASH" or key == "/" then
                    frame.promptBox:SetFocus()
                    if key == "SLASH" or key == "/" then
                        frame.promptBox:SetText("")
                    end
                end
            end
        end)
    end

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
local renderDirty = false
local renderTimerPending = false

function CLIAlts:RequestRender()
    renderDirty = true
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
    if not mainFrame or not mainFrame:IsShown() then return end

    local t = self:GetTheme()
    local activeTab = CLIAltsDB.settings.activeTab or 1
    local fontSize = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.fontSize) or DEFAULT_FONT_SIZE

    -- Highlight active tab button
    for _, tabBtn in ipairs(mainFrame.tabButtons) do
        if tabBtn.tabId == activeTab then
            tabBtn.label:SetText(string.format(">> %s <<", tabBtn.baseText))
            tabBtn.label:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
            tabBtn:SetBackdropColor(t.border[1], t.border[2], t.border[3], 0.3)
            tabBtn:SetBackdropBorderColor(t.highlight[1], t.highlight[2], t.highlight[3], 1)
        else
            tabBtn.label:SetText(tabBtn.baseText)
            tabBtn.label:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
            tabBtn:SetBackdropColor(0, 0, 0, 0.6)
            tabBtn:SetBackdropBorderColor(t.dim[1], t.dim[2], t.dim[3], 0.8)
        end
    end

    -- Update Status Bar
    local summary = self:GetAccountSummary()
    local totalGold = summary.totalGold or 0
    local goldOnly = math.floor(totalGold / 10000)
    local curFull = self.curPlayerFullName or (select(3, self:GetPlayerNames()))

    if activeTab == 4 then
        local spark = self:GenerateAsciiSparkline(14)
        local d1, d7, d30 = self:GetGoldHistoryDeltas()
        local d1Sign = d1 >= 0 and "+" or ""
        local d7Sign = d7 >= 0 and "+" or ""
        local d30Sign = d30 >= 0 and "+" or ""
        mainFrame.statusBarText:SetText(string.format("WEALTH [%s] | 24H: %s%dg | 7D: %s%dg | 30D: %s%dg | TOTAL: %sg",
            spark, d1Sign, d1, d7Sign, d7, d30Sign, d30, self:FormatNumber(goldOnly)))
    else
        local filterTag = self.activeFilter and string.format(" [FILTER: %s]", self.activeFilter:upper()) or ""
        mainFrame.statusBarText:SetText(string.format("SYSTEM: WOW FOREVER | ACTIVE: %s | TRACKED: %d ALTS%s | WEALTH: %sg",
            curFull or "Unknown", summary.totalAlts or 0, filterTag, self:FormatNumber(goldOnly)))
    end

    -- Render Table Header (Monospace Text)
    mainFrame.tableHeaderString:SetText(self:BuildHeaderLine(activeTab, t))

    -- Position Clickable Header Buttons
    local charW = self:GetCharWidth(fontSize)
    local cols = COLS[activeTab] or COLS[1]
    local curCharOffset = 3 -- after "| "

    for idx = 1, 8 do
        local btn = headerButtons[idx]
        local col = cols[idx]
        if col and col.sort then
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", mainFrame.headerFrame, "LEFT", (curCharOffset - 1) * charW, 0)
            btn:SetSize(col.w * charW, 18)
            btn.sortKey = col.sort
            btn.colTitle = col.title
            btn:Show()
        else
            btn:Hide()
        end
        if col then
            curCharOffset = curCharOffset + col.w + 1
        end
    end

    -- Retrieve Sorted Characters
    local chars = self:GetCharactersList(CLIAltsDB.settings.sortBy, CLIAltsDB.settings.sortAsc, self.activeFilter)
    totalPages = math.max(1, math.ceil(#chars / ROWS_COUNT))
    if currentPage > totalPages then currentPage = totalPages end
    if currentPage < 1 then currentPage = 1 end

    local filterSuffix = self.activeFilter and " FILTERED" or ""
    mainFrame.pageText:SetText(string.format("PAGE %d OF %d (%d ALTS%s)", currentPage, totalPages, #chars, filterSuffix))
    mainFrame.btnPrev:SetEnabled(currentPage > 1)
    mainFrame.btnNext:SetEnabled(currentPage < totalPages)

    -- Render 12 Monospace Rows (Single FontString Per Row)
    for rowIndex = 1, ROWS_COUNT do
        local row = rowFrames[rowIndex]
        local charIndex = (currentPage - 1) * ROWS_COUNT + rowIndex
        local char = chars[charIndex]

        if char then
            row.charData = char
            row:SetBackdropColor(0, 0, 0, (rowIndex % 2 == 0) and 0.25 or 0.1)

            local parts = {}
            for _, col in ipairs(cols) do
                table.insert(parts, col.fmt(char, t))
            end
            local line = "| " .. table.concat(parts, " ") .. " |"
            row.text:SetText(line)
            row:Show()
        else
            row.charData = nil
            row.text:SetText("")
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

    mainFrame.topAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8)
    mainFrame.titleText:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
    mainFrame.midAscii1:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8)
    mainFrame.statusBarText:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
    mainFrame.midAscii2:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8)
    mainFrame.tableTopAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8)
    mainFrame.tableSepAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8)
    mainFrame.tableBotAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8)
    mainFrame.botAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8)
    mainFrame.pageText:SetTextColor(t.primary[1], t.primary[2], t.primary[3])

    if mainFrame.btnTheme then
        mainFrame.btnTheme.label:SetText(string.format("[ THEME: %s ]", t.tag))
        mainFrame.btnTheme.label:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
    end

    if mainFrame.btnPerk then
        local r = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
        mainFrame.btnPerk.label:SetText(string.format("[ PERK: R%d (+%d%%) ]", r, r * 4))
        mainFrame.btnPerk.label:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
    end

    if mainFrame.btnScale then
        local s = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.scale) or 1.0
        mainFrame.btnScale.label:SetText(string.format("[ SCALE: %d%% ]", math.floor(s * 100 + 0.5)))
        mainFrame.btnScale.label:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
    end

    if mainFrame.promptLabel then
        mainFrame.promptLabel:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
    end
    if mainFrame.promptBox then
        mainFrame.promptBox:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
    end
    if mainFrame.promptSepAscii then
        mainFrame.promptSepAscii:SetTextColor(t.border[1], t.border[2], t.border[3], 0.8)
    end
    if mainFrame.promptStatusTip then
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
                xp = "xp",
                exp = "xp",
                progress = "xp",
                waste = "waste",
                wst = "waste",
                fac = "name",
                loc = "location",
                location = "location",
            }
            local key = map[args:lower()] or args:lower()
            self:ToggleSortKey(key)
            local dir = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.sortAsc) and "ASC" or "DESC"
            self:SetPromptFeedback(string.format("Sorted by %s (%s)", key:upper(), dir))
        else
            self:SetPromptFeedback("Usage: sort <name|level|gold|rested|waste|xp>", true)
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
            self:AddWatchItem(args)
            self:SetPromptFeedback(string.format("Added '%s' to watchlist", args))
            self:Render()
        else
            self:SetPromptFeedback("Usage: watch <Item Name or ID>", true)
        end

    elseif cmd == "unwatch" then
        if args and args ~= "" then
            self:RemoveWatchItem(args)
            self:SetPromptFeedback(string.format("Removed '%s' from watchlist", args))
            self:Render()
        else
            self:SetPromptFeedback("Usage: unwatch <Item Name>", true)
        end

    elseif cmd == "watchlist" then
        self:PrintWatchlist()
        self:SetPromptFeedback("Watchlist printed to chat.")

    elseif cmd == "export" or cmd == "csv" then
        self:ShowExportPopup()
        self:SetPromptFeedback("CSV Export window opened.")

    elseif cmd == "theme" then
        if args and args ~= "" then
            local map = {
                green = "GREEN",
                amber = "AMBER",
                cyan = "CYAN",
                mono = "MONO",
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
                self:SetPromptFeedback("Themes: green, amber, cyan, mono, synthwave, dracula", true)
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
        "goto", "page", "next", "export",
        "watch", "unwatch", "watchlist",
        "theme", "scale", "perk", "perf", "selftest",
        "refresh", "help", "exit", "close"
    }

    local cmd, arg = trimmed:match("^(%S+)%s+(.*)$")
    if cmd then
        cmd = cmd:lower()
        if cmd == "sort" then
            local sortKeys = { "name", "level", "gold", "rested", "waste", "xp", "location" }
            for _, k in ipairs(sortKeys) do
                if k:sub(1, #arg) == arg:lower() and k ~= arg:lower() then
                    editBox:SetText("sort " .. k)
                    editBox:SetCursorPosition(#editBox:GetText())
                    return
                end
            end
        elseif cmd == "theme" then
            local themes = { "green", "amber", "cyan", "mono", "synthwave", "dracula" }
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
        local dp = CreateFrame("Frame", "CLIAltsDossierPopup", mainFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
        dp:SetSize(660, 480)
        dp:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
        dp:SetFrameStrata("DIALOG")
        dp:EnableMouse(true)

        dp:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })

        local body = dp:CreateFontString(nil, "OVERLAY")
        self:SetWidgetFont(body, 14)
        body:SetPoint("TOPLEFT", dp, "TOPLEFT", 16, -16)
        body:SetPoint("BOTTOMRIGHT", dp, "BOTTOMRIGHT", -16, 45)
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        dp.body = body

        local btnDel = CreateRetroButton(dp, "[ DELETE CHARACTER ]", 140, 20, function()
            dp:Hide()
            if dp.charData then
                CLIAlts:ShowConfirmDelete(dp.charData)
            end
        end)
        btnDel:SetPoint("BOTTOMLEFT", dp, "BOTTOMLEFT", 16, 16)

        local btnClose = CreateRetroButton(dp, "[ CLOSE ]", 80, 20, function()
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
    table.insert(lines, "| System:         |cffffffffWoW Forever|r")
    table.insert(lines, string.format("| Faction / Race: %s |cffffffff%s (%s)|r", self:GetFactionTag(char.faction), self:FormatRace(char), self:GetRaceCode(char)))
    table.insert(lines, string.format("| Class / Level:  %s (Level |cffffffff%d|r)", self:ColorizePlayerName(char.class or "Unknown", char.classFile), char.level or 1))
    table.insert(lines, string.format("| Current Gold:   %s", self:FormatMoney(char.money, true)))

    local isResting = self:IsCharacterResting(char)
    local logoutZoneTag = char.loggedOutInRestZone and "|cff00ff66[REST AREA AT LOGOUT]|r" or "|cffffaa00[WILD AT LOGOUT]|r"
    table.insert(lines, string.format("| Location:       |cffffffff%s|r %s", char.location or "Unknown", logoutZoneTag))
    table.insert(lines, string.format("| Last Active:    |cffffffff%s|r (%s)", self:GetTimeAgo(char.lastUpdate), date("%b %d, %H:%M", char.lastUpdate or time())))
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
    table.insert(lines, "| RESTED EXPERIENCE (WoW Forever):")

    local rested = self:GetRestedData(char)
    if rested and not rested.isMaxLevel then
        local est = rested.isEstimate and "~" or ""
        local restModeStr = rested.isResting and "+5.0% every 8h (Resting)" or "+1.25% every 8h (Wilderness)"
        table.insert(lines, string.format("| Rested Points:  |cffffffff%s%s / %s XP|r (%s%d%% of Level)", est, self:FormatNumber(rested.currentRested), self:FormatNumber(rested.maxRested), est, rested.percent))
        table.insert(lines, string.format("| Rest Status:    %s (%s | Perk: R%d/5)", rested.statusStr, restModeStr, rested.perkRank))
        table.insert(lines, string.format("| Accumulation:   |cffffffff%s%s XP/hr|r (+%d%% speed bonus)", est, self:FormatNumber(math.floor((rested.ratePerSec or 0) * 3600)), rested.perkRank * 4))
        table.insert(lines, string.format("| Progress Bar:   %s%s|r %s%d%%", t.barFill, rested.barStr, est, rested.percent))
        table.insert(lines, string.format("| Time to %d%%:   |cffffffff%s|r", rested.maxPercent or 150, rested.timeLeftStr))
        table.insert(lines, string.format("| Projected Date: |cffffffff%s|r", rested.fullDate))
        if rested.isEstimate then
            table.insert(lines, "| Note:           |cffffaa00Estimated projection (~disconnect / crash)|r")
        end
    else
        table.insert(lines, "| Rest Status:    |cff888888N/A (Max Level characters do not accumulate Rested XP)|r")
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
        local cp = CreateFrame("Frame", "CLIAltsConfirmPopup", mainFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
        cp:SetSize(360, 160)
        cp:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
        cp:SetFrameStrata("DIALOG")
        cp:EnableMouse(true)

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
            if cp.charKey then
                CLIAlts:DeleteCharacter(cp.charKey)
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

-- ----------------------------------------------------------------------------
-- Help / Info Modal
-- ----------------------------------------------------------------------------
function CLIAlts:ShowHelpPopup()
    if not helpPopup then
        local hp = CreateFrame("Frame", "CLIAltsHelpPopup", mainFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
        hp:SetSize(560, 520)
        hp:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
        hp:SetFrameStrata("DIALOG")
        hp:EnableMouse(true)

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
        "|   /clialts reset      - Reset window position to center            |",
        "+--------------------------------------------------------------------+",
        "| Interactive Terminal Command Prompt (>):                           |",
        "|   > 1 .. 5            - Switch tab (Overview, Rest, Prof, Econ, Cd)|",
        "|   > sort <column>     - Sort table (name, lvl, gold, rest, waste)  |",
        "|   > filter <query>    - Filter alts (alliance, horde, <60, mining) |",
        "|   > find <text>       - Search character names, classes, or zones  |",
        "|   > clear             - Clear active filter query                  |",
        "|   > next              - Print alts with highest rested waste       |",
        "|   > watch <item>      - Add item to bag/bank inventory tracker     |",
        "|   > export            - Open CSV export modal dialog               |",
        "|   > theme [name]      - Cycle or set color theme                   |",
        "|   > perf              - Output profiling exponential moving average|",
        "|   > selftest          - Execute automated test suite in chat       |",
        "|   > Up / Down arrows  - Browse terminal command history            |",
        "|   > Tab key           - Auto-complete commands and column names    |",
        "+--------------------------------------------------------------------+",
        "| Interactions:                                                      |",
        "|   - Click [SCALE] on title bar to cycle 100%, 115%, 130%, 145%, 90%|",
        "|   - Click [THEME] on title bar to cycle CRT retro color palettes   |",
        "|   - Click column title in header line to sort ascending/descending |",
        "|   - Left-Click any character row to inspect full Dossier           |",
        "|   - Right-Click any character row to delete character record       |",
        "|   - Mouse wheel over table to scroll pages                         |",
        "|   - Drag Minimap icon to move outside of minimap                   |",
        "+--------------------------------------------------------------------+",
        "| Rested XP Mechanics (WoW Forever):                                 |",
        "|   - Resting in Inn/City/Camp: +5% of level every 8h (10 days base) |",
        "|   - Logged in Wilderness:     +1.25% every 8h (40 days base)       |",
        "|   - Well Rested Legacy Perk:  +4% speed & +4% cap per rank (max 5) |",
        "+====================================================================+",
    }

    helpPopup.body:SetText(table.concat(helpText, "\n"))
    helpPopup:Show()
end

-- ----------------------------------------------------------------------------
-- CSV Export Modal (Copyable Multi-Line Dialog)
-- ----------------------------------------------------------------------------
local exportPopup = nil
function CLIAlts:ShowExportPopup()
    if not exportPopup then
        local ep = CreateFrame("Frame", "CLIAltsExportPopup", mainFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
        ep:SetSize(640, 440)
        ep:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
        ep:SetFrameStrata("DIALOG")
        ep:EnableMouse(true)

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
        self:CreateMainFrame()
    end

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
