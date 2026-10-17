-- ============================================================================
-- ForeverAlts: Onboarding Tour Engine
-- File: modules/tour.lua
-- ============================================================================

local addonName, addonTable = ...
local ForeverAlts = addonTable or _G["ForeverAlts"] or _G["CLIAlts"] or {}

local function CreateRetroButton(...)
    if ForeverAlts.CreateRetroButton then
        return ForeverAlts.CreateRetroButton(...)
    end
end

-- ============================================================================
-- 28. Onboarding Tour Engine (/ca tour)
-- Highlights key features across 3 steps: Banner, Status Pill, Command Bar
-- ============================================================================

ForeverAlts.TOUR_STEPS = {
    {
        badge = "STEP 1 OF 3",
        title = "Play Next Priority",
        desc = "ForeverAlts identifies alts at danger of wasting rested XP or with urgent cooldowns and ranks them here. Click any hero card to inspect.",
        target = function()
            local mf = ForeverAlts.mainFrame or _G["ForeverAltsMainFrame"]
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
            local rowFrames = ForeverAlts:GetRowFrames()
            if rowFrames and rowFrames[1] then
                if rowFrames[1].statusPill and rowFrames[1].statusPill:IsShown() then
                    return rowFrames[1].statusPill
                end
                return rowFrames[1]
            end
            local mf = ForeverAlts.mainFrame or _G["ForeverAltsMainFrame"]
            return mf
        end,
        position = "LEFT_OR_BELOW",
    },
    {
        badge = "STEP 3 OF 3",
        title = "Command Bar & Quick Chips",
        desc = "Type commands or click quick hint chips (like 'next', 'plan 2', 'unlocked mc', 'digest') to control your roster. Use Up/Down for history and Tab to autocomplete.",
        target = function()
            local mf = ForeverAlts.mainFrame or _G["ForeverAltsMainFrame"]
            if mf and mf.cmdBar and mf.cmdBar:IsShown() then
                return mf.cmdBar
            end
            return mf
        end,
        position = "ABOVE",
    },
}

function ForeverAlts:GetTourHighlight()
    if self.tourHighlight then return self.tourHighlight end
    local hl = CreateFrame("Frame", "ForeverAltsTourHighlight", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
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

function ForeverAlts:GetTourCard()
    if self.tourCard then return self.tourCard end
    local card = CreateFrame("Frame", "ForeverAltsTourCard", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    card:SetSize(360, 140)
    card:SetFrameStrata("DIALOG")
    card:SetFrameLevel(100)
    card:EnableMouse(true)
    card:SetMovable(true)
    card:RegisterForDrag("LeftButton")
    card:SetScript("OnDragStart", function(self) self:StartMoving() end)
    card:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    tinsert(UISpecialFrames, "ForeverAltsTourCard")

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
        ForeverAlts:EndTour()
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
        if ForeverAlts.currentTourStep and ForeverAlts.currentTourStep > 1 then
            ForeverAlts:ShowTourStep(ForeverAlts.currentTourStep - 1)
        end
    end)
    btnBack:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 14, 12)
    card.btnBack = btnBack

    local btnNext = CreateRetroButton(card, "Next >", 75, 20, function()
        if ForeverAlts.currentTourStep and ForeverAlts.currentTourStep < #ForeverAlts.TOUR_STEPS then
            ForeverAlts:ShowTourStep(ForeverAlts.currentTourStep + 1)
        else
            ForeverAlts:EndTour()
        end
    end)
    btnNext:SetPoint("LEFT", btnBack, "RIGHT", 8, 0)
    card.btnNext = btnNext

    local btnSkip = CreateRetroButton(card, "Skip Tour", 75, 20, function()
        ForeverAlts:EndTour()
    end)
    btnSkip:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -14, 12)
    card.btnSkip = btnSkip

    self.tourCard = card
    return card
end

function ForeverAlts:ShowTourStep(stepIndex)
    stepIndex = tonumber(stepIndex) or 1
    if stepIndex < 1 then stepIndex = 1 end
    if stepIndex > #self.TOUR_STEPS then stepIndex = #self.TOUR_STEPS end
    self.currentTourStep = stepIndex

    local step = self.TOUR_STEPS[stepIndex]
    if not step then return end

    local hl = self:GetTourHighlight()
    local card = self:GetTourCard()
    local mf = self.mainFrame or _G["ForeverAltsMainFrame"]

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

function ForeverAlts:StartTour()
    local ok, err = pcall(function()
        if InCombatLockdown and InCombatLockdown() then
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff3333[ForeverAlts]|r Cannot start onboarding tour while in combat.")
            end
            return
        end

        if ForeverAltsDB and ForeverAltsDB.settings then
            ForeverAltsDB.settings.tourDone = true
        end

        if self.SwitchTab then
            self:SwitchTab(1)
        end

        local mf = self.mainFrame or _G["ForeverAltsMainFrame"]
        if not mf or not mf:IsShown() then
            self:Toggle(true)
        end

        self:ShowTourStep(1)
    end)
    if not ok then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff3333[ForeverAlts]|r StartTour error: %s", tostring(err)))
        end
    end
end

function ForeverAlts:EndTour()
    self.currentTourStep = nil
    if self.tourHighlight then
        self.tourHighlight:Hide()
    end
    if self.tourCard then
        self.tourCard:Hide()
    end
    if ForeverAltsDB and ForeverAltsDB.settings then
        ForeverAltsDB.settings.tourDone = true
    end
end


