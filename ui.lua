-- ============================================================================
-- CLIAlts: Retro Alt Tracker
-- File: ui.lua
-- Retro ASCII / TUI interface with mouse support, clickable tabs, sorting,
-- character dossiers, rested XP bars, and theme customization.
-- ============================================================================

local addonName, addonTable = ...
local CLIAlts = addonTable

-- ----------------------------------------------------------------------------
-- Theme Definitions
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
        barFill = "|cffd8d8d8",
        barEmpty = "|cff555555",
    },
}

local THEME_ORDER = { "GREEN", "AMBER", "CYAN", "MONO" }

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
-- UI Sound Helper
-- ----------------------------------------------------------------------------
local function PlayRetroSound()
    if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    else
        pcall(PlaySound, 856)
    end
end

-- ----------------------------------------------------------------------------
-- Retro Button Creator Helper
-- ----------------------------------------------------------------------------
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
    label:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
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
-- Main Frame Creation
-- ----------------------------------------------------------------------------
local mainFrame = nil
local dossierPopup = nil
local confirmPopup = nil
local helpPopup = nil

local ROWS_COUNT = 12
local rowFrames = {}
local currentPage = 1
local totalPages = 1
local headerPool = {} -- [tabId] = { btn1, btn2, ... }

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

function CLIAlts:CreateMainFrame()
    if mainFrame then return mainFrame end

    local frame = CreateFrame("Frame", "CLIAltsMainFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:Hide()
    frame:SetSize(780, 520)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    tinsert(UISpecialFrames, "CLIAltsMainFrame")

    -- Restore saved window position or default to center
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
    _G["CLIAltsMainFrame"] = frame

    -- Top border ASCII line
    local topAscii = frame:CreateFontString(nil, "OVERLAY")
    topAscii:SetFont("Fonts\\ARIALN.TTF", 11, "")
    topAscii:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -8)
    topAscii:SetText("+==================================================================================================+")
    frame.topAscii = topAscii

    -- Title Bar
    local titleText = frame:CreateFontString(nil, "OVERLAY")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -22)
    titleText:SetText("[#] CLIALTS :: RETRO ALT & RESTED XP MONITOR v" .. CLIAlts.VERSION)
    frame.titleText = titleText

    -- Window Controls on Title Bar (Theme, Help, Refresh, Close)
    local btnClose = CreateRetroButton(frame, "[ X ]", 34, 18, function()
        CLIAlts:Toggle(false)
    end)
    btnClose:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -20)

    local btnHelp = CreateRetroButton(frame, "[ ? ]", 34, 18, function()
        CLIAlts:ShowHelpPopup()
    end)
    btnHelp:SetPoint("RIGHT", btnClose, "LEFT", -6, 0)

    local btnTheme = CreateRetroButton(frame, "[ THEME: GRN ]", 100, 18, function()
        CLIAlts:CycleTheme()
    end)
    btnTheme:SetPoint("RIGHT", btnHelp, "LEFT", -6, 0)
    frame.btnTheme = btnTheme

    local btnRefresh = CreateRetroButton(frame, "[ REFRESH ]", 80, 18, function()
        CLIAlts:Refresh()
    end)
    btnRefresh:SetPoint("RIGHT", btnTheme, "LEFT", -6, 0)

    -- Subheader border ASCII line
    local midAscii1 = frame:CreateFontString(nil, "OVERLAY")
    midAscii1:SetFont("Fonts\\ARIALN.TTF", 11, "")
    midAscii1:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -40)
    midAscii1:SetText("+--------------------------------------------------------------------------------------------------+")
    frame.midAscii1 = midAscii1

    -- Status bar line (Realm, Alts count, Wealth)
    local statusBarText = frame:CreateFontString(nil, "OVERLAY")
    statusBarText:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
    statusBarText:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -53)
    statusBarText:SetText("SYSTEM: WOW FOREVER | TRACKED CHARACTERS: 0 | TOTAL WEALTH: 0g 0s 0c")
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
        GameTooltip:AddLine("Slash cmd: |cff00ff66/CLIAlts perk <0-5>|r", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btnPerk:SetScript("OnLeave", function(self)
        local t = CLIAlts:GetTheme()
        self:SetBackdropColor(0, 0, 0, 0.6)
        GameTooltip:Hide()
    end)
    frame.btnPerk = btnPerk

    local midAscii2 = frame:CreateFontString(nil, "OVERLAY")
    midAscii2:SetFont("Fonts\\ARIALN.TTF", 11, "")
    midAscii2:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -66)
    midAscii2:SetText("+--------------------------------------------------------------------------------------------------+")
    frame.midAscii2 = midAscii2

    -- Retro Tabs
    local tabs = {
        { id = 1, text = "[ ALTS OVERVIEW ]" },
        { id = 2, text = "[ RESTED XP MONITOR ]" },
        { id = 3, text = "[ PROFESSIONS ]" },
        { id = 4, text = "[ ECONOMY / WEALTH ]" },
    }
    frame.tabButtons = {}
    local prevTab = nil
    for _, tabData in ipairs(tabs) do
        local tabBtn = CreateRetroButton(frame, tabData.text, 170, 22, function()
            CLIAltsDB.settings.activeTab = tabData.id
            currentPage = 1
            CLIAlts:Render()
        end)
        if not prevTab then
            tabBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -80)
        else
            tabBtn:SetPoint("LEFT", prevTab, "RIGHT", 8, 0)
        end
        tabBtn.tabId = tabData.id
        tabBtn.baseText = tabData.text
        table.insert(frame.tabButtons, tabBtn)
        prevTab = tabBtn
    end

    -- Header row border ASCII line
    local tableTopAscii = frame:CreateFontString(nil, "OVERLAY")
    tableTopAscii:SetFont("Fonts\\ARIALN.TTF", 11, "")
    tableTopAscii:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -106)
    tableTopAscii:SetText("+==================================================================================================+")
    frame.tableTopAscii = tableTopAscii

    -- Column Header Frame (Clickable for sorting)
    local headerFrame = CreateFrame("Frame", nil, frame)
    headerFrame:SetSize(746, 20)
    headerFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -120)
    frame.headerFrame = headerFrame

    -- Container for Rows
    local rowsContainer = CreateFrame("Frame", nil, frame)
    rowsContainer:SetSize(746, 280)
    rowsContainer:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)
    frame.rowsContainer = rowsContainer

    -- Enable mousewheel scrolling on row container
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

    -- Create 12 reusable row frames
    for i = 1, ROWS_COUNT do
        local row = CreateFrame("Button", nil, rowsContainer, BackdropTemplateMixin and "BackdropTemplate" or nil)
        row:SetSize(746, 22)
        row:SetPoint("TOPLEFT", rowsContainer, "TOPLEFT", 0, -((i - 1) * 23))

        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        row:SetBackdropColor(0, 0, 0, 0.2)
        row:SetBackdropBorderColor(0, 0, 0, 0)

        -- Cell 1 (Faction / Prompt arrow)
        row.col1 = row:CreateFontString(nil, "OVERLAY")
        row.col1:SetFont("Fonts\\ARIALN.TTF", 11, "")
        row.col1:SetJustifyH("LEFT")
        row.col1:SetWordWrap(false)
        row.col1:SetPoint("LEFT", row, "LEFT", 6, 0)

        -- Cell 2 (Name)
        row.col2 = row:CreateFontString(nil, "OVERLAY")
        row.col2:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        row.col2:SetJustifyH("LEFT")
        row.col2:SetWordWrap(false)
        row.col2:SetPoint("LEFT", row, "LEFT", 44, 0)

        -- Cell 3 (Level)
        row.col3 = row:CreateFontString(nil, "OVERLAY")
        row.col3:SetFont("Fonts\\ARIALN.TTF", 11, "")
        row.col3:SetJustifyH("LEFT")
        row.col3:SetWordWrap(false)
        row.col3:SetPoint("LEFT", row, "LEFT", 170, 0)

        -- Cell 4 (Race/Class or Rested or Prof1)
        row.col4 = row:CreateFontString(nil, "OVERLAY")
        row.col4:SetFont("Fonts\\ARIALN.TTF", 11, "")
        row.col4:SetJustifyH("LEFT")
        row.col4:SetWordWrap(false)
        row.col4:SetPoint("LEFT", row, "LEFT", 215, 0)

        -- Cell 5 (Gold or Rested Bar or Prof2)
        row.col5 = row:CreateFontString(nil, "OVERLAY")
        row.col5:SetFont("Fonts\\ARIALN.TTF", 11, "")
        row.col5:SetJustifyH("LEFT")
        row.col5:SetWordWrap(false)
        row.col5:SetPoint("LEFT", row, "LEFT", 355, 0)

        -- Cell 6 (Rested Info or Secondary or Wealth Share)
        row.col6 = row:CreateFontString(nil, "OVERLAY")
        row.col6:SetFont("Fonts\\ARIALN.TTF", 11, "")
        row.col6:SetJustifyH("LEFT")
        row.col6:SetWordWrap(false)
        row.col6:SetPoint("LEFT", row, "LEFT", 495, 0)

        -- Cell 7 (Status / ETA / Timestamp)
        row.col7 = row:CreateFontString(nil, "OVERLAY")
        row.col7:SetFont("Fonts\\ARIALN.TTF", 11, "")
        row.col7:SetJustifyH("LEFT")
        row.col7:SetWordWrap(false)
        row.col7:SetPoint("LEFT", row, "LEFT", 625, 0)

        -- Cell 8 (Extra Info / Date)
        row.col8 = row:CreateFontString(nil, "OVERLAY")
        row.col8:SetFont("Fonts\\ARIALN.TTF", 11, "")
        row.col8:SetJustifyH("LEFT")
        row.col8:SetWordWrap(false)
        row.col8:SetPoint("LEFT", row, "LEFT", 665, 0)

        -- Row Action Button [DEL]
        local btnDel = CreateRetroButton(row, "[X]", 24, 16, function()
            if row.charData then
                CLIAlts:ShowConfirmDelete(row.charData)
            end
        end)
        btnDel:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.btnDel = btnDel

        -- Fixed-width Retro TUI Progress Bar Widget (Identical pixel width across all rows)
        local TRACK_WIDTH = 76
        local pBar = CreateFrame("Frame", nil, row)
        pBar:SetSize(130, 20)
        pBar:EnableMouse(false) -- Allow mouse events to pass through to row

        local leftBracket = pBar:CreateFontString(nil, "OVERLAY")
        leftBracket:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
        leftBracket:SetPoint("LEFT", pBar, "LEFT", 0, 0)
        leftBracket:SetText("[")
        pBar.leftBracket = leftBracket

        local trackBg = pBar:CreateTexture(nil, "BACKGROUND")
        trackBg:SetPoint("LEFT", leftBracket, "RIGHT", 1, 0)
        trackBg:SetSize(TRACK_WIDTH, 8)
        trackBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        trackBg:SetVertexColor(0.10, 0.10, 0.10, 0.9)
        pBar.trackBg = trackBg

        local trackFill = pBar:CreateTexture(nil, "BORDER")
        trackFill:SetPoint("TOPLEFT", trackBg, "TOPLEFT", 0, 0)
        trackFill:SetPoint("BOTTOMLEFT", trackBg, "BOTTOMLEFT", 0, 0)
        trackFill:SetWidth(0)
        trackFill:SetTexture("Interface\\Buttons\\WHITE8X8")
        pBar.trackFill = trackFill

        -- 50% Midpoint Notch: calibrated indicator to easily gauge "Half Full"
        local midTick = pBar:CreateTexture(nil, "ARTWORK")
        midTick:SetPoint("TOPLEFT", trackBg, "TOPLEFT", math.floor(TRACK_WIDTH / 2), 0)
        midTick:SetPoint("BOTTOMLEFT", trackBg, "BOTTOMLEFT", math.floor(TRACK_WIDTH / 2), 0)
        midTick:SetWidth(1)
        midTick:SetTexture("Interface\\Buttons\\WHITE8X8")
        midTick:SetVertexColor(0.40, 0.40, 0.40, 0.85)
        pBar.midTick = midTick

        local rightBracket = pBar:CreateFontString(nil, "OVERLAY")
        rightBracket:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
        rightBracket:SetPoint("LEFT", trackBg, "RIGHT", 1, 0)
        rightBracket:SetText("]")
        pBar.rightBracket = rightBracket

        local pctText = pBar:CreateFontString(nil, "OVERLAY")
        pctText:SetFont("Fonts\\ARIALN.TTF", 11, "")
        pctText:SetJustifyH("LEFT")
        pctText:SetPoint("LEFT", rightBracket, "RIGHT", 4, 0)
        pBar.pctText = pctText

        pBar:Hide()
        row.pBar = pBar

        -- Hover behavior
        row:SetScript("OnEnter", function(self)
            local t = CLIAlts:GetTheme()
            self:SetBackdropColor(t.rowHover[1], t.rowHover[2], t.rowHover[3], t.rowHover[4])
            self:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 0.6)
            self.col1:SetText("|cff" .. (t.barFill:sub(5) or "ffffff") .. ">|r")

            if self.pBar and self.pBar:IsShown() then
                self.pBar.leftBracket:SetTextColor(1, 1, 1)
                self.pBar.rightBracket:SetTextColor(1, 1, 1)
            end

            if self.charData then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local coloredName = CLIAlts:ColorizePlayerName(self.charData.name, self.charData.classFile)
                GameTooltip:AddLine(coloredName, 1, 1, 1)

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

                GameTooltip:AddLine(string.format("Gold: %s", CLIAlts:FormatMoney(self.charData.money, true)), 1, 1, 1)
                GameTooltip:AddLine(string.format("Location: |cffffffff%s|r", self.charData.location or "Unknown"), 0.7, 0.7, 0.7)
                GameTooltip:AddLine("Click row to view Alt Dossier.", 1, 0.82, 0)
                GameTooltip:Show()
            end
        end)

        row:SetScript("OnLeave", function(self)
            local t = CLIAlts:GetTheme()
            self:SetBackdropColor(0, 0, 0, (i % 2 == 0) and 0.25 or 0.1)
            self:SetBackdropBorderColor(0, 0, 0, 0)
            if self.facText then
                self.col1:SetText(self.facText)
            end
            if self.pBar and self.pBar:IsShown() then
                self.pBar.leftBracket:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
                self.pBar.rightBracket:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
            end
            GameTooltip:Hide()
        end)

        -- Click to inspect character dossier
        row:SetScript("OnClick", function(self)
            if self.charData then
                PlayRetroSound()
                CLIAlts:ShowDossierPopup(self.charData)
            end
        end)

        table.insert(rowFrames, row)
    end

    -- Bottom border ASCII line
    local botAscii = frame:CreateFontString(nil, "OVERLAY")
    botAscii:SetFont("Fonts\\ARIALN.TTF", 11, "")
    botAscii:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 42)
    botAscii:SetText("+==================================================================================================+")
    frame.botAscii = botAscii

    -- Footer: Pagination controls and helper tips
    local btnPrev = CreateRetroButton(frame, "[<< PREV]", 75, 18, function()
        if currentPage > 1 then
            currentPage = currentPage - 1
            CLIAlts:Render()
        end
    end)
    btnPrev:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 16)
    frame.btnPrev = btnPrev

    local pageLabel = frame:CreateFontString(nil, "OVERLAY")
    pageLabel:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
    pageLabel:SetPoint("LEFT", btnPrev, "RIGHT", 12, 0)
    pageLabel:SetText("[ PAGE 1 / 1 ]")
    frame.pageLabel = pageLabel

    local btnNext = CreateRetroButton(frame, "[NEXT >>]", 75, 18, function()
        if currentPage < totalPages then
            currentPage = currentPage + 1
            CLIAlts:Render()
        end
    end)
    btnNext:SetPoint("LEFT", pageLabel, "RIGHT", 12, 0)
    frame.btnNext = btnNext

    local tipText = frame:CreateFontString(nil, "OVERLAY")
    tipText:SetFont("Fonts\\ARIALN.TTF", 11, "")
    tipText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -90, 19)
    tipText:SetText("|cff888888>> Click row to inspect Alt Dossier | Click headers to sort | /CLIAlts|r")
    frame.tipText = tipText

    local btnBottomClose = CreateRetroButton(frame, "[ CLOSE ]", 65, 18, function()
        CLIAlts:Toggle(false)
    end)
    btnBottomClose:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)

    CLIAlts:ApplyTheme()
    frame:Hide()
    return frame
end

-- ----------------------------------------------------------------------------
-- Apply Visual Themes
-- ----------------------------------------------------------------------------
function CLIAlts:ApplyTheme()
    local t = self:GetTheme()

    if mainFrame then
        mainFrame:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], t.bg[4])
        mainFrame:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], t.border[4])

        mainFrame.topAscii:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
        mainFrame.midAscii1:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
        mainFrame.midAscii2:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
        mainFrame.tableTopAscii:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
        mainFrame.botAscii:SetTextColor(t.dim[1], t.dim[2], t.dim[3])

        mainFrame.titleText:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
        mainFrame.statusBarText:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])

        if mainFrame.btnTheme then
            mainFrame.btnTheme.label:SetText(string.format("[ THEME: %s ]", t.tag))
        end

        if mainFrame.btnPerk then
            local r = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
            mainFrame.btnPerk.label:SetText(string.format("[ PERK: R%d (+%d%%) ]", r, r * 4))
            mainFrame.btnPerk.label:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
            mainFrame.btnPerk:SetBackdropBorderColor(t.dim[1], t.dim[2], t.dim[3], 0.8)
        end

        if next(headerPool) then
            for _, btns in pairs(headerPool) do
                for _, btn in ipairs(btns) do
                    if btn:IsShown() and btn.str then
                        btn.str:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
                    end
                end
            end
        end
    end

    -- Update minimap disc if loaded
    local mBtn = minimapBtn or CLIAltsMinimapButton
    if mBtn and mBtn.bg then
        mBtn.bg:SetVertexColor(t.bg[1], t.bg[2], t.bg[3], 1)
        if mBtn.iconText then
            mBtn.iconText:SetText(string.format("%s[A]|r", t.barFill))
        end
    end
end

-- ----------------------------------------------------------------------------
-- Table Header Definitions & Pool (Zero Garbage / Frame Leak Fix)
-- ----------------------------------------------------------------------------
local HEADER_DEFS = {
    [1] = {
        { name = "FAC", offset = 6, width = 26 },
        { name = "NAME", offset = 34, width = 120, sortKey = "name" },
        { name = "LVL", offset = 158, width = 45, sortKey = "level" },
        { name = "RACE / CLASS", offset = 206, width = 115 },
        { name = "LEVEL XP", offset = 325, width = 135, sortKey = "xp" },
        { name = "GOLD", offset = 464, width = 115, sortKey = "gold" },
        { name = "RESTED", offset = 583, width = 80, sortKey = "rested" },
        { name = "ETA FULL", offset = 667, width = 75 },
    },
    [2] = {
        { name = "NAME", offset = 12, width = 135, sortKey = "name" },
        { name = "LVL", offset = 152, width = 45, sortKey = "level" },
        { name = "RESTED / CAP", offset = 202, width = 125, sortKey = "rested" },
        { name = "RESTED BAR", offset = 332, width = 145 },
        { name = "STATUS", offset = 482, width = 65 },
        {
            name = "TIME TO %d%%",
            offset = 552,
            width = 85,
            getText = function()
                local r = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
                return string.format("[TIME TO %d%%]", 150 + (r * 6))
            end
        },
        { name = "CAPPED DATE", offset = 642, width = 75 },
    },
    [3] = {
        { name = "NAME", offset = 12, width = 135, sortKey = "name" },
        { name = "LVL", offset = 152, width = 45, sortKey = "level" },
        { name = "PRIMARY PROF 1", offset = 202, width = 125 },
        { name = "PRIMARY PROF 2", offset = 332, width = 125 },
        { name = "COOKING", offset = 462, width = 80 },
        { name = "FIRST AID", offset = 547, width = 80 },
        { name = "FISHING", offset = 632, width = 80 },
    },
    [4] = {
        { name = "NAME", offset = 12, width = 135, sortKey = "name" },
        { name = "LVL", offset = 152, width = 45, sortKey = "level" },
        { name = "WEALTH SHARE / BAR", offset = 202, width = 155, sortKey = "gold" },
        { name = "EXACT WEALTH", offset = 362, width = 145, sortKey = "gold" },
        { name = "SHARE %", offset = 512, width = 75 },
        { name = "LAST ACTIVE", offset = 592, width = 115 },
    },
}

local function InitHeaderPool(parent)
    if not parent or next(headerPool) then return end

    for tabId = 1, 4 do
        local defs = HEADER_DEFS[tabId]
        headerPool[tabId] = {}
        if defs then
            for _, def in ipairs(defs) do
                local btn = CreateFrame("Button", nil, parent)
                btn:SetSize(def.width, 18)
                btn:SetPoint("LEFT", parent, "LEFT", def.offset, 0)

                local str = btn:CreateFontString(nil, "OVERLAY")
                str:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
                str:SetPoint("LEFT", btn, "LEFT", 0, 0)
                btn.str = str
                btn.labelName = def.name
                btn.sortKey = def.sortKey
                btn.getText = def.getText

                btn:SetScript("OnEnter", function(self)
                    self.str:SetTextColor(1, 1, 1)
                end)
                btn:SetScript("OnLeave", function(self)
                    local t = CLIAlts:GetTheme()
                    self.str:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
                end)

                if def.sortKey then
                    btn:SetScript("OnClick", function()
                        PlayRetroSound()
                        if CLIAltsDB.settings.sortBy == def.sortKey then
                            CLIAltsDB.settings.sortAsc = not CLIAltsDB.settings.sortAsc
                        else
                            CLIAltsDB.settings.sortBy = def.sortKey
                            CLIAltsDB.settings.sortAsc = false
                        end
                        CLIAlts:Render()
                    end)
                end

                btn:Hide()
                table.insert(headerPool[tabId], btn)
            end
        end
    end
end

function CLIAlts:RenderHeaders(activeTab)
    local hf = mainFrame and mainFrame.headerFrame
    if not hf then return end

    if not next(headerPool) then
        InitHeaderPool(hf)
    end

    local t = self:GetTheme()
    local sortBy = CLIAltsDB.settings.sortBy
    local sortAsc = CLIAltsDB.settings.sortAsc

    -- Hide all header pools for inactive tabs
    for tabId, btns in pairs(headerPool) do
        if tabId ~= activeTab then
            for _, btn in ipairs(btns) do
                btn:Hide()
            end
        end
    end

    -- Show and update only active tab's headers
    local activeBtns = headerPool[activeTab]
    if activeBtns then
        for _, btn in ipairs(activeBtns) do
            local text
            if btn.getText then
                text = btn.getText()
            elseif btn.sortKey then
                local indicator = (sortBy == btn.sortKey) and (sortAsc and " ^" or " v") or ""
                text = string.format("[%s%s]", btn.labelName, indicator)
            else
                text = string.format("[%s]", btn.labelName)
            end

            btn.str:SetText(text)
            btn.str:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
            btn:Show()
        end
    end
end

-- ----------------------------------------------------------------------------
-- Retro TUI Fixed-Width Progress Bar Update Helper
-- ----------------------------------------------------------------------------
local TRACK_WIDTH = 76

function CLIAlts:UpdateRowProgressBar(row, ratio, textStr, r, g, b, isMaxLevel)
    local pBar = row.pBar
    if not pBar then return end
    pBar:Show()

    local t = self:GetTheme()
    r = r or t.primary[1]
    g = g or t.primary[2]
    b = b or t.primary[3]

    pBar.leftBracket:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
    pBar.rightBracket:SetTextColor(t.dim[1], t.dim[2], t.dim[3])

    if isMaxLevel then
        pBar.trackFill:SetWidth(TRACK_WIDTH)
        pBar.trackFill:SetVertexColor(0.35, 0.35, 0.35, 0.8)
        pBar.pctText:SetText(textStr or " MAX")
        pBar.pctText:SetTextColor(0.6, 0.6, 0.6)
        pBar.midTick:Hide()
    else
        ratio = math.max(0, math.min(1, ratio or 0))
        local fillW = math.floor(ratio * TRACK_WIDTH)
        pBar.trackFill:SetWidth(fillW)
        pBar.trackFill:SetVertexColor(r, g, b, 0.95)
        pBar.pctText:SetText(textStr or "")
        pBar.pctText:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
        pBar.midTick:Show()
        -- Dynamic contrast for the 50% midpoint notch (gauge indicator for "half full")
        if fillW >= math.floor(TRACK_WIDTH / 2) then
            pBar.midTick:SetVertexColor(0, 0, 0, 0.85)
        else
            pBar.midTick:SetVertexColor(0.40, 0.40, 0.40, 0.85)
        end
    end
end

-- ----------------------------------------------------------------------------
-- Tab 3 Profession Format Helpers
-- ----------------------------------------------------------------------------
local function FormatProf(p)
    if not p then return "|cff555555---|r" end
    local isMax = p.rank >= (p.maxRank or 300)
    local color = isMax and "|cff00ff66" or "|cffffffff"
    return string.format("%s: %s%d/%d|r", p.name:sub(1, 8), color, p.rank, p.maxRank or 300)
end

local function FormatSec(p)
    if not p then return "|cff555555---|r" end
    local isMax = p.rank >= (p.maxRank or 300)
    local color = isMax and "|cff00ff66" or "|cffffffff"
    return string.format("%s%d/%d|r", color, p.rank, p.maxRank or 300)
end

-- ----------------------------------------------------------------------------
-- Render Main Content
-- ----------------------------------------------------------------------------
function CLIAlts:Render()
    if not mainFrame or not mainFrame:IsShown() then return end

    local t = self:GetTheme()
    local activeTab = CLIAltsDB.settings.activeTab or 1

    -- Highlight active tab button
    for _, tabBtn in ipairs(mainFrame.tabButtons) do
        if tabBtn.tabId == activeTab then
            tabBtn.label:SetText(string.format(">> %s <<", tabBtn.baseText))
            tabBtn.label:SetTextColor(t.highlight[1], t.highlight[2], t.highlight[3])
            tabBtn:SetBackdropColor(t.border[1], t.border[2], t.border[3], 0.3)
            tabBtn:SetBackdropBorderColor(t.primary[1], t.primary[2], t.primary[3], 1)
        else
            tabBtn.label:SetText(tabBtn.baseText)
            tabBtn.label:SetTextColor(t.dim[1], t.dim[2], t.dim[3])
            tabBtn:SetBackdropColor(0, 0, 0, 0.6)
            tabBtn:SetBackdropBorderColor(t.dim[1], t.dim[2], t.dim[3], 0.6)
        end
    end

    -- Update Status Bar & Perk Button
    local summary = self:GetAccountSummary()
    local moneyStr = self:FormatMoney(summary.totalGold, true)
    mainFrame.statusBarText:SetText(string.format("SYSTEM: |cffffffffWOW FOREVER|r  |  TRACKED CHARACTERS: |cffffffff%d|r  |  TOTAL WEALTH: %s",
        summary.totalAlts, moneyStr))

    if mainFrame.btnPerk then
        local r = (CLIAltsDB and CLIAltsDB.settings and tonumber(CLIAltsDB.settings.wellRestedRank)) or 0
        mainFrame.btnPerk.label:SetText(string.format("[ PERK: R%d (+%d%%) ]", r, r * 4))
        mainFrame.btnPerk.label:SetTextColor(t.primary[1], t.primary[2], t.primary[3])
    end

    -- Render Headers for Active Tab
    self:RenderHeaders(activeTab)

    -- Get Sorted Characters
    local chars = self:GetCharactersList(CLIAltsDB.settings.sortBy, CLIAltsDB.settings.sortAsc)
    totalPages = math.max(1, math.ceil(#chars / ROWS_COUNT))
    if currentPage > totalPages then currentPage = totalPages end
    if currentPage < 1 then currentPage = 1 end

    mainFrame.pageLabel:SetText(string.format("[ PAGE %d / %d ]", currentPage, totalPages))
    mainFrame.pageLabel:SetTextColor(t.primary[1], t.primary[2], t.primary[3])

    local startIndex = (currentPage - 1) * ROWS_COUNT + 1
    local endIndex = math.min(#chars, startIndex + ROWS_COUNT - 1)

    -- Render Rows
    for rowIndex = 1, ROWS_COUNT do
        local row = rowFrames[rowIndex]
        local charIndex = startIndex + (rowIndex - 1)

        if charIndex <= endIndex then
            local char = chars[charIndex]
            row.charData = char
            row:Show()

            local coloredName = self:ColorizePlayerName(char.name, char.classFile)
            local rested = self:GetRestedData(char)

            -- Base alternating background
            row:SetBackdropColor(0, 0, 0, (rowIndex % 2 == 0) and 0.25 or 0.1)
            row:SetBackdropBorderColor(0, 0, 0, 0)

            if activeTab == 1 then
                -- ALTS OVERVIEW
                local facTag = self:GetFactionTag(char.faction)
                row.facText = facTag
                row.col1:SetText(facTag)
                row.col1:SetWidth(26)
                row.col1:SetPoint("LEFT", row, "LEFT", 6, 0)

                row.col2:SetText(coloredName)
                row.col2:SetWidth(120)
                row.col2:SetPoint("LEFT", row, "LEFT", 34, 0)

                row.col3:SetText(string.format("Lvl %d", char.level or 1))
                row.col3:SetWidth(45)
                row.col3:SetPoint("LEFT", row, "LEFT", 158, 0)

                row.col4:SetText(self:FormatRaceClass(char))
                row.col4:SetWidth(115)
                row.col4:SetPoint("LEFT", row, "LEFT", 206, 0)

                -- Col 5: LEVEL EXPERIENCE PROGRESS (Fixed-width retro TUI bar)
                local xpData = self:GetLevelProgressData(char)
                row.col5:SetText("")
                row.pBar:ClearAllPoints()
                row.pBar:SetPoint("LEFT", row, "LEFT", 325, 0)
                if xpData and not xpData.isMaxLevel then
                    self:UpdateRowProgressBar(row, xpData.ratio, string.format("%2d%%", xpData.percent), t.primary[1], t.primary[2], t.primary[3], false)
                else
                    self:UpdateRowProgressBar(row, 1.0, " MAX", 0.35, 0.35, 0.35, true)
                end

                -- Col 6: GOLD
                row.col6:SetText(self:FormatMoney(char.money, true))
                row.col6:SetWidth(115)
                row.col6:SetPoint("LEFT", row, "LEFT", 464, 0)

                -- Col 7: RESTED STATUS & POOL %
                if rested and not rested.isMaxLevel then
                    local est = rested.isEstimate and "~" or ""
                    row.col7:SetText(string.format("%s %s%d%%", rested.statusStr, est, rested.percent))
                else
                    row.col7:SetText("|cff888888--- |r")
                end
                row.col7:SetWidth(80)
                row.col7:SetPoint("LEFT", row, "LEFT", 583, 0)

                -- Col 8: TIME TO FULL RESTED
                if rested and not rested.isMaxLevel then
                    row.col8:SetText(rested.timeLeftStr)
                else
                    row.col8:SetText("")
                end
                row.col8:SetWidth(46)
                row.col8:SetPoint("LEFT", row, "LEFT", 667, 0)

            elseif activeTab == 2 then
                -- RESTED XP MONITOR
                row.facText = ""
                row.col1:SetText("")

                row.col2:SetText(coloredName)
                row.col2:SetWidth(135)
                row.col2:SetPoint("LEFT", row, "LEFT", 12, 0)

                row.col3:SetText(string.format("Lvl %d", char.level or 1))
                row.col3:SetWidth(45)
                row.col3:SetPoint("LEFT", row, "LEFT", 152, 0)

                row.col5:SetText("")
                row.pBar:ClearAllPoints()
                row.pBar:SetPoint("LEFT", row, "LEFT", 332, 0)

                if rested and not rested.isMaxLevel then
                    local est = rested.isEstimate and "~" or ""
                    row.col4:SetText(string.format("%s%s / %s", est, self:FormatNumber(rested.currentRested), self:FormatNumber(rested.maxRested)))
                    local restRatio = (rested.maxRested > 0) and (rested.currentRested / rested.maxRested) or 0
                    self:UpdateRowProgressBar(row, restRatio, string.format("%s%2d%%", est, rested.percent), t.primary[1], t.primary[2], t.primary[3], false)
                    row.col6:SetText(rested.statusStr)
                    row.col7:SetText(rested.timeLeftStr)
                    row.col8:SetText(rested.fullDate)
                else
                    row.col4:SetText("|cff888888MAX LEVEL|r")
                    self:UpdateRowProgressBar(row, 1.0, " MAX", 0.35, 0.35, 0.35, true)
                    row.col6:SetText("|cff888888--- |r")
                    row.col7:SetText("|cff888888--- |r")
                    row.col8:SetText("|cff888888--- |r")
                end
                row.col4:SetWidth(125)
                row.col4:SetPoint("LEFT", row, "LEFT", 202, 0)
                row.col6:SetWidth(65)
                row.col6:SetPoint("LEFT", row, "LEFT", 482, 0)
                row.col7:SetWidth(80)
                row.col7:SetPoint("LEFT", row, "LEFT", 552, 0)
                row.col8:SetWidth(75)
                row.col8:SetPoint("LEFT", row, "LEFT", 637, 0)

            elseif activeTab == 3 then
                -- PROFESSIONS
                row.pBar:Hide()
                row.facText = ""
                row.col1:SetText("")

                row.col2:SetText(coloredName)
                row.col2:SetWidth(135)
                row.col2:SetPoint("LEFT", row, "LEFT", 12, 0)

                row.col3:SetText(string.format("Lvl %d", char.level or 1))
                row.col3:SetWidth(45)
                row.col3:SetPoint("LEFT", row, "LEFT", 152, 0)

                local p1 = char.professions and char.professions.primary and char.professions.primary[1]
                local p2 = char.professions and char.professions.primary and char.professions.primary[2]
                local cooking, firstAid, fishing = nil, nil, nil
                if char.professions and char.professions.secondary then
                    for _, sec in ipairs(char.professions.secondary) do
                        if sec.name == "Cooking" then cooking = sec
                        elseif sec.name == "First Aid" then firstAid = sec
                        elseif sec.name == "Fishing" then fishing = sec end
                    end
                end

                row.col4:SetText(FormatProf(p1))
                row.col4:SetWidth(125)
                row.col4:SetPoint("LEFT", row, "LEFT", 202, 0)

                row.col5:SetText(FormatProf(p2))
                row.col5:SetWidth(125)
                row.col5:SetPoint("LEFT", row, "LEFT", 332, 0)

                row.col6:SetText(FormatSec(cooking))
                row.col6:SetWidth(80)
                row.col6:SetPoint("LEFT", row, "LEFT", 462, 0)

                row.col7:SetText(FormatSec(firstAid))
                row.col7:SetWidth(80)
                row.col7:SetPoint("LEFT", row, "LEFT", 547, 0)

                row.col8:SetText(FormatSec(fishing))
                row.col8:SetWidth(80)
                row.col8:SetPoint("LEFT", row, "LEFT", 632, 0)

            elseif activeTab == 4 then
                -- ECONOMY / WEALTH
                row.facText = ""
                row.col1:SetText("")

                row.col2:SetText(coloredName)
                row.col2:SetWidth(135)
                row.col2:SetPoint("LEFT", row, "LEFT", 12, 0)

                row.col3:SetText(string.format("Lvl %d", char.level or 1))
                row.col3:SetWidth(45)
                row.col3:SetPoint("LEFT", row, "LEFT", 152, 0)

                local totalWealth = summary.totalGold
                local share = (totalWealth > 0) and ((char.money or 0) / totalWealth) or 0
                local sharePct = share * 100

                row.col4:SetText("")
                row.pBar:ClearAllPoints()
                row.pBar:SetPoint("LEFT", row, "LEFT", 202, 0)
                self:UpdateRowProgressBar(row, share, string.format("%4.1f%%", sharePct), t.primary[1], t.primary[2], t.primary[3], false)

                row.col5:SetText(self:FormatMoney(char.money, true))
                row.col5:SetWidth(145)
                row.col5:SetPoint("LEFT", row, "LEFT", 362, 0)

                row.col6:SetText(string.format("%5.1f%%", sharePct))
                row.col6:SetWidth(75)
                row.col6:SetPoint("LEFT", row, "LEFT", 512, 0)

                row.col7:SetText(self:GetTimeAgo(char.lastUpdate))
                row.col7:SetWidth(115)
                row.col7:SetPoint("LEFT", row, "LEFT", 592, 0)

                row.col8:SetText("")
            end
        else
            row.charData = nil
            if row.pBar then row.pBar:Hide() end
            row:Hide()
        end
    end
end

-- ----------------------------------------------------------------------------
-- Alt Dossier Popup (Inspect Alt Details)
-- ----------------------------------------------------------------------------
function CLIAlts:ShowDossierPopup(char)
    if not char then return end

    if not dossierPopup then
        local p = CreateFrame("Frame", "CLIAltsDossierPopup", mainFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
        p:SetSize(500, 530)
        p:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
        p:SetFrameStrata("TOOLTIP")
        p:EnableMouse(true)

        p:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })

        local title = p:CreateFontString(nil, "OVERLAY")
        title:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        title:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -16)
        p.title = title

        local btnClose = CreateRetroButton(p, "[ X ]", 34, 18, function()
            p:Hide()
        end)
        btnClose:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16, -14)

        local body = p:CreateFontString(nil, "OVERLAY")
        body:SetFont("Fonts\\ARIALN.TTF", 11, "")
        body:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -42)
        body:SetJustifyH("LEFT")
        body:SetSpacing(3)
        p.body = body

        local btnDel = CreateRetroButton(p, "[ DELETE ALT RECORD ]", 150, 22, function()
            p:Hide()
            CLIAlts:ShowConfirmDelete(p.currentChar)
        end)
        btnDel:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 16)

        local btnDone = CreateRetroButton(p, "[ CLOSE ]", 80, 22, function()
            p:Hide()
        end)
        btnDone:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 16)

        dossierPopup = p
    end

    local t = self:GetTheme()
    dossierPopup:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
    dossierPopup:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 1)

    dossierPopup.currentChar = char
    dossierPopup.title:SetText(string.format(".:: DOSSIER: %s ::.", self:ColorizePlayerName(char.name, char.classFile)))
    dossierPopup.title:SetTextColor(t.primary[1], t.primary[2], t.primary[3])

    local rested = self:GetRestedData(char)
    local lines = {}

    table.insert(lines, "+------------------------------------------------------------------------------+")
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
    local logoutZoneTag
    if char.loggedOutInRestZone ~= nil then
        logoutZoneTag = char.loggedOutInRestZone and "|cff00ff66[REST AREA AT LOGOUT]|r" or "|cffffaa00[WILD AT LOGOUT]|r"
    elseif isResting then
        logoutZoneTag = "|cff00ff66[REST AREA]|r"
    else
        logoutZoneTag = "|cffffaa00[WILD]|r"
    end
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
        table.insert(lines, "| Status:         |cff888888MAX LEVEL (No Rested Required)|r")
    end

    table.insert(lines, "+------------------------------------------------------------------------------+")
    table.insert(lines, "| PROFESSIONS:")
    if char.professions and char.professions.primary and #char.professions.primary > 0 then
        for _, p in ipairs(char.professions.primary) do
            table.insert(lines, string.format("|   * Primary:   |cffffffff%-14s|r (%d / %d)", p.name, p.rank, p.maxRank or 300))
        end
    else
        table.insert(lines, "|   * Primary:   |cff777777None recorded|r")
    end

    if char.professions and char.professions.secondary and #char.professions.secondary > 0 then
        for _, s in ipairs(char.professions.secondary) do
            table.insert(lines, string.format("|   * Secondary: |cffffffff%-14s|r (%d / %d)", s.name, s.rank, s.maxRank or 300))
        end
    end

    table.insert(lines, "+------------------------------------------------------------------------------+")

    dossierPopup.body:SetText(table.concat(lines, "\n"))
    dossierPopup:Show()
end

-- ----------------------------------------------------------------------------
-- Delete Confirmation Modal
-- ----------------------------------------------------------------------------
function CLIAlts:ShowConfirmDelete(char)
    if not char then return end

    if not confirmPopup then
        local cp = CreateFrame("Frame", "CLIAltsConfirmDelete", mainFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
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

        local txt = cp:CreateFontString(nil, "OVERLAY")
        txt:SetFont("Fonts\\ARIALN.TTF", 11, "")
        txt:SetPoint("CENTER", cp, "CENTER", 0, 15)
        txt:SetJustifyH("CENTER")
        cp.txt = txt

        local btnConfirm = CreateRetroButton(cp, "[ CONFIRM DELETE ]", 130, 22, function()
            if cp.targetChar and cp.targetChar.key then
                CLIAlts:DeleteCharacter(cp.targetChar.key)
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66[CLIAlts]|r Deleted alt record for %s.", cp.targetChar.name))
                cp:Hide()
                CLIAlts:Render()
            end
        end)
        btnConfirm:SetPoint("BOTTOMLEFT", cp, "BOTTOMLEFT", 30, 20)

        local btnCancel = CreateRetroButton(cp, "[ CANCEL ]", 90, 22, function()
            cp:Hide()
        end)
        btnCancel:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT", -30, 20)

        confirmPopup = cp
    end

    local t = self:GetTheme()
    confirmPopup:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.98)
    confirmPopup:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 1)

    confirmPopup.targetChar = char
    confirmPopup.txt:SetText(string.format("+----------------------------------------+\n| DELETE ALT RECORD CONFIRMATION         |\n+----------------------------------------+\nAre you sure you want to remove\n%s from tracking?\n+----------------------------------------+",
        self:ColorizePlayerName(char.name, char.classFile)))

    confirmPopup:Show()
end

-- ----------------------------------------------------------------------------
-- Help / Info Modal
-- ----------------------------------------------------------------------------
function CLIAlts:ShowHelpPopup()
    if not helpPopup then
        local hp = CreateFrame("Frame", "CLIAltsHelpPopup", mainFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
        hp:SetSize(520, 420)
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
        body:SetFont("Fonts\\ARIALN.TTF", 11, "")
        body:SetPoint("TOPLEFT", hp, "TOPLEFT", 16, -16)
        body:SetJustifyH("LEFT")
        body:SetSpacing(2)
        hp.body = body

        local btnClose = CreateRetroButton(hp, "[ CLOSE ]", 80, 22, function()
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
        "|   /CLIAlts            - Toggle the main TUI monitor                |",
        "|   /CLIAlts [1-4]      - Open directly to specific tab (1-4)        |",
        "|   /CLIAlts show       - Open window                                |",
        "|   /CLIAlts track      - Force save current character to tracker    |",
        "|   /CLIAlts rested     - Print quick rested XP report to chat       |",
        "|   /CLIAlts perk <0-5> - Set Well Rested legacy perk rank (0-5)     |",
        "|   /CLIAlts gold       - Print total account gold summary           |",
        "|   /CLIAlts reset      - Reset window position to center            |",
        "+--------------------------------------------------------------------+",
        "| Mouse Interactions:                                                |",
        "|   - Click [PERK: R#] on status bar to cycle Well Rested perk rank  |",
        "|   - Drag header bar to move window                                 |",
        "|   - Click any column header to sort ascending / descending         |",
        "|   - Click any character row to view detailed Dossier               |",
        "|   - Click [THEME] on title bar to cycle CRT retro color palettes   |",
        "|   - Mouse wheel over table to scroll pages                         |",
        "|   - Drag Minimap icon to move around outside of minimap            |",
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
            mainFrame:Show()
            PlayRetroSound()
            self:Render()
        end
    elseif show then
        self:CollectCurrentCharacter()
        mainFrame:Show()
        PlayRetroSound()
        self:Render()
    else
        mainFrame:Hide()
    end
end

function CLIAlts:Refresh()
    self:CollectCurrentCharacter()
    self:Render()
end
