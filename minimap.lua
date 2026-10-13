-- ============================================================================
-- CLIAlts: Retro Alt Tracker
-- File: minimap.lua
-- Moveable minimap button with retro ASCII quick-status tooltip.
-- Anchors dynamically to the outside of the minimap circle with smooth dragging.
-- ============================================================================

local addonName, addonTable = ...
local CLIAlts = addonTable

local minimapBtn = nil

function CLIAlts:CreateMinimapButton()
    if self.InitLDB then
        self:InitLDB()
    end
    if minimapBtn then return minimapBtn end

    minimapBtn = CreateFrame("Button", "CLIAltsMinimapButton", Minimap)
    minimapBtn:SetFrameStrata("HIGH")
    minimapBtn:SetSize(32, 32)
    minimapBtn:SetFrameLevel(25)
    minimapBtn:EnableMouse(true)
    minimapBtn:SetMovable(true)
    minimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapBtn:RegisterForDrag("LeftButton", "RightButton")
    minimapBtn:SetClampedToScreen(true)

    local t = (CLIAlts.GetTheme and CLIAlts:GetTheme()) or {
        bg = { 0.04, 0.08, 0.06 },
        barFill = "|cff00ff66"
    }

    -- Background disc
    local bg = minimapBtn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(21, 21)
    bg:SetPoint("CENTER", 0, 0)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetVertexColor(t.bg[1], t.bg[2], t.bg[3], 1)
    minimapBtn.bg = bg

    -- Retro ASCII Icon text in center "[A]"
    local iconText = minimapBtn:CreateFontString(nil, "ARTWORK")
    iconText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    iconText:SetPoint("CENTER", 0, 0)
    iconText:SetText(string.format("%s[A]|r", t.barFill))
    minimapBtn.iconText = iconText

    -- Circular tracking border
    local border = minimapBtn:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    minimapBtn.border = border

    -- Mouse highlight
    minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-Button-Highlight")

    -- Dragging handling (supports dragging around minimap and adjusting distance)
    minimapBtn:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self:LockHighlight()
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            if not mx or not my then return end

            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale() or 1
            cx, cy = cx / scale, cy / scale

            local dx = cx - mx
            local dy = cy - my
            local angle = math.deg(math.atan2(dy, dx))
            if angle < 0 then angle = angle + 360 end

            local dist = math.sqrt(dx * dx + dy * dy)
            local mWidth = Minimap:GetWidth() or 140
            local mHeight = Minimap:GetHeight() or 140
            local minRadius = (math.max(mWidth, mHeight) / 2) + 6
            local maxRadius = minRadius + 70

            -- Keep outside the minimap circle
            if dist < minRadius then dist = minRadius end
            if dist > maxRadius then dist = maxRadius end

            if CLIAltsDB and CLIAltsDB.settings then
                CLIAltsDB.settings.minimapPos = angle
                CLIAltsDB.settings.minimapDist = dist
            end
            CLIAlts:UpdateMinimapPosition()
        end)
    end)

    minimapBtn:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self:SetScript("OnUpdate", nil)

        -- Delay resetting isDragging slightly so OnClick does not trigger upon mouse release
        local timerFrame = CreateFrame("Frame")
        local elapsed = 0
        timerFrame:SetScript("OnUpdate", function(f, e)
            elapsed = elapsed + e
            if elapsed > 0.1 then
                self.isDragging = false
                timerFrame:SetScript("OnUpdate", nil)
            end
        end)
    end)

    -- Click handlers
    minimapBtn:SetScript("OnClick", function(self, button)
        if self.isDragging then return end

        if button == "LeftButton" then
            CLIAlts:CollectCurrentCharacter()
            CLIAlts:Toggle()
        elseif button == "RightButton" then
            CLIAlts:Refresh()
            local summary = CLIAlts:GetAccountSummary()
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff66[CLIAlts]|r Data refreshed. Tracked alts: %d.", summary.totalAlts))
        end
    end)

    -- Tooltip with Retro ASCII look
    minimapBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()

        local summary = CLIAlts:GetAccountSummary()
        local moneyStr = CLIAlts:FormatMoney(summary.totalGold, true)

        local themeData = (CLIAlts.GetTheme and CLIAlts:GetTheme())
        local br = themeData and themeData.border[1] or 0
        local bgCol = themeData and themeData.border[2] or 1
        local bb = themeData and themeData.border[3] or 0.4
        local hr = themeData and themeData.highlight[1] or 0.2
        local hg = themeData and themeData.highlight[2] or 1
        local hb = themeData and themeData.highlight[3] or 0.6

        GameTooltip:AddLine("+-----------------------------------------------+", br, bgCol, bb)
        GameTooltip:AddLine("|  .:: [ CLIALTS ] - RETRO ALT MONITOR ::.     |", hr, hg, hb)
        GameTooltip:AddLine("+-----------------------------------------------+", br, bgCol, bb)
        GameTooltip:AddDoubleLine("| Total Tracked Alts:", string.format("%d alts |", summary.totalAlts), 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine("| Total Account Wealth:", string.format("%s |", moneyStr), 0.7, 0.7, 0.7, 1, 1, 1)

        local fullyStr = summary.fullyRested > 0 and string.format("%d of %d [*] |", summary.fullyRested, summary.totalAlts) or string.format("%d of %d |", summary.fullyRested, summary.totalAlts)
        local frR, frG, frB = summary.fullyRested > 0 and 1.0 or 0.7, summary.fullyRested > 0 and 0.85 or 0.7, summary.fullyRested > 0 and 0.2 or 0.7
        GameTooltip:AddDoubleLine("| Fully Rested (150%):", fullyStr, 0.7, 0.7, 0.7, frR, frG, frB)

        if summary.nextFullAlt then
            local coloredName = CLIAlts:ColorizePlayerName(summary.nextFullAlt.name, summary.nextFullAlt.classFile)
            GameTooltip:AddDoubleLine("| Next Full Alt:", string.format("%s (%s) |", coloredName, summary.nextFullAlt.timeLeftStr), 0.7, 0.7, 0.7, 1, 0.85, 0.2)
        end

        GameTooltip:AddLine("+-----------------------------------------------+", br, bgCol, bb)
        GameTooltip:AddDoubleLine("| <Left-Click>", "Toggle Alt Monitor |", 0.6, 0.8, 0.7, 0.9, 0.9, 0.9)
        GameTooltip:AddDoubleLine("| <Right-Click>", "Refresh Timers |", 0.6, 0.8, 0.7, 0.9, 0.9, 0.9)
        GameTooltip:AddDoubleLine("| <Drag Left/Right>", "Move Around Minimap |", 0.6, 0.8, 0.7, 0.9, 0.9, 0.9)
        GameTooltip:AddLine("+-----------------------------------------------+", br, bgCol, bb)

        GameTooltip:Show()
    end)

    minimapBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    CLIAlts:UpdateMinimapPosition()
    if CLIAlts.ApplyTheme then
        CLIAlts:ApplyTheme()
    end

    if CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.minimapShow == false then
        minimapBtn:Hide()
    else
        minimapBtn:Show()
    end

    return minimapBtn
end

function CLIAlts:UpdateMinimapPosition()
    if not minimapBtn then return end

    local angle = 45
    if CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.minimapPos then
        angle = CLIAltsDB.settings.minimapPos
    end

    local mWidth = (Minimap and Minimap:GetWidth()) or 140
    local mHeight = (Minimap and Minimap:GetHeight()) or 140
    local defaultRadius = (math.max(mWidth, mHeight) / 2) + 12

    local radius = defaultRadius
    if CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.minimapDist then
        radius = CLIAltsDB.settings.minimapDist
    end

    -- Safeguard: Ensure button is never placed inside the minimap
    local minRadius = (math.max(mWidth, mHeight) / 2) + 6
    if radius < minRadius then
        radius = minRadius
    end

    local rad = math.rad(angle)
    local x = math.cos(rad) * radius
    local y = math.sin(rad) * radius

    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function CLIAlts:ToggleMinimap(show)
    if not minimapBtn then
        self:CreateMinimapButton()
    end
    if show == nil then
        if minimapBtn:IsShown() then
            minimapBtn:Hide()
            CLIAltsDB.settings.minimapShow = false
        else
            minimapBtn:Show()
            CLIAltsDB.settings.minimapShow = true
        end
    elseif show then
        minimapBtn:Show()
        CLIAltsDB.settings.minimapShow = true
    else
        minimapBtn:Hide()
        CLIAltsDB.settings.minimapShow = false
    end
end

-- ============================================================================
-- LibDataBroker-1.1 Integration (Feature 10)
-- Optional data broker plugin for display bars (Titan Panel, Bazooka, ChocolateBar).
-- Guarded with LibStub("LibDataBroker-1.1", true) so zero cost if absent.
-- ============================================================================
function CLIAlts:InitLDB()
    if self.ldbObject then return self.ldbObject end
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    if not LDB then return nil end

    self.ldbObject = LDB:NewDataObject("CLIAlts", {
        type = "data source",
        text = self.GetLDBText and self:GetLDBText() or "CLIAlts",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        label = "CLIAlts",
        OnClick = function(clickedframe, button)
            if button == "LeftButton" then
                if CLIAlts.Toggle then CLIAlts:Toggle() end
            elseif button == "RightButton" then
                if CLIAlts.CycleTheme then CLIAlts:CycleTheme() end
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            local t = (CLIAlts.GetTheme and CLIAlts:GetTheme())
            local hr, hg, hb = t and t.highlight[1] or 0.2, t and t.highlight[2] or 1, t and t.highlight[3] or 0.6
            tooltip:AddLine("CLIAlts", hr, hg, hb)
            local cappedCount, totalWastedXP
            if CLIAlts.GetLDBText then
                local _
                _, cappedCount, totalWastedXP = CLIAlts:GetLDBText()
            end
            local summary = CLIAlts.GetAccountSummary and CLIAlts:GetAccountSummary()
            if summary then
                tooltip:AddDoubleLine("Total Alts:", tostring(summary.totalAlts), 0.7, 0.7, 0.7, 1, 1, 1)
                tooltip:AddDoubleLine("Total Gold:", CLIAlts:FormatMoney(summary.totalGold, true), 0.7, 0.7, 0.7, 1, 1, 1)
            end
            if cappedCount then
                local cappedStr = cappedCount > 0 and string.format("%d [!]", cappedCount) or string.format("%d", cappedCount)
                local cr, cg, cb = cappedCount > 0 and 1.0 or 0.7, cappedCount > 0 and 0.85 or 0.7, cappedCount > 0 and 0.2 or 0.7
                tooltip:AddDoubleLine("Capped Alts:", cappedStr, 0.7, 0.7, 0.7, cr, cg, cb)
            end
            if totalWastedXP and totalWastedXP > 0 then
                tooltip:AddDoubleLine("XP Wasted:", string.format("!%s XP", CLIAlts:FormatNumber(totalWastedXP)), 0.7, 0.7, 0.7, 1.0, 0.65, 0.0)
            end
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff888888Left-Click:|r Toggle window", 0.8, 0.8, 0.8)
            tooltip:AddLine("|cff888888Right-Click:|r Cycle theme", 0.8, 0.8, 0.8)
        end,
    })
    return self.ldbObject
end

function CLIAlts:UpdateLDB()
    if not self.ldbObject then
        self:InitLDB()
    end
    if not self.ldbObject then return end
    if self.GetLDBText then
        self.ldbObject.text = self:GetLDBText()
    end
end

-- Periodic LDB refresh ticker (every 30s) so display bars stay updated when window is closed
local ldbTicker = CreateFrame("Frame")
local ldbElapsed = 0
ldbTicker:SetScript("OnUpdate", function(self, elapsed)
    ldbElapsed = ldbElapsed + (elapsed or 0)
    if ldbElapsed >= 30 then
        ldbElapsed = 0
        if CLIAlts.ldbObject and CLIAlts.UpdateLDB then
            CLIAlts:UpdateLDB()
        end
    end
end)

