-- ============================================================================
-- ForeverAlts: Chat Layout Cloner Engine
-- File: modules/chat_cloner.lua
-- ============================================================================

local addonName, addonTable = ...
local ForeverAlts = addonTable or _G["ForeverAlts"] or _G["CLIAlts"] or {}

-- ----------------------------------------------------------------------------
-- Chat Layout Cloner Engine (Feature 16)
-- ----------------------------------------------------------------------------

function ForeverAlts:CaptureChatSettings(charKey)
    local targetKey = charKey or self.curPlayerKey
    if not targetKey then
        local _, _, full = self:GetPlayerNames()
        targetKey = full and self:GetCharacterKey(full)
    end
    if not targetKey then return false, "No character identified." end
    if not ForeverAltsDB or not ForeverAltsDB.characters then return false, "DB not initialized." end

    local char = ForeverAltsDB.characters[targetKey]
    if not char then
        -- Find or initialize record if collecting during early login
        local found = self:FindCharacter(targetKey)
        if found then
            char = found
        else
            return false, "Character record not found."
        end
    end

    if not GetChatWindowInfo then
        return false, "Chat API not available."
    end

    local numWins = NUM_CHAT_WINDOWS or 10
    local windows = {}
    local winCount = 0

    for i = 1, numWins do
        local ok, name, fontSize, r, g, b, alpha, shown, locked, docked, uninteractable = pcall(GetChatWindowInfo, i)
        if ok and name and name ~= "" then
            winCount = winCount + 1

            -- Registered message groups (SAY, YELL, GUILD, PARTY, RAID, etc.)
            local messages = {}
            if GetChatWindowMessages then
                local okMsg, msgList = pcall(function() return { GetChatWindowMessages(i) } end)
                if okMsg and msgList then
                    messages = msgList
                end
            end

            -- Registered channels (e.g. General, Trade, LocalDefense)
            local channels = {}
            if GetChatWindowChannels then
                local okChan, chanList = pcall(function() return { GetChatWindowChannels(i) } end)
                if okChan and chanList then
                    for c = 1, #chanList, 2 do
                        local chName = chanList[c]
                        if chName and chName ~= "" then
                            table.insert(channels, chName)
                        end
                    end
                end
            end

            -- Window position & dimensions
            local point, relName, relativePoint, x, y, width, height
            local cf = _G["ChatFrame" .. i]
            if cf then
                if cf.GetPoint then
                    local okPt, pt, relTo, relPt, px, py = pcall(cf.GetPoint, cf, 1)
                    if okPt and pt then
                        point = pt
                        relativePoint = relPt or pt
                        x = px or 0
                        y = py or 0
                        if type(relTo) == "table" and relTo.GetName then
                            relName = relTo:GetName()
                        elseif type(relTo) == "string" then
                            relName = relTo
                        end
                        relName = relName or "UIParent"
                    end
                end
                if cf.GetWidth then
                    local okW, w = pcall(cf.GetWidth, cf)
                    if okW and w and w > 0 then width = math.floor(w + 0.5) end
                end
                if cf.GetHeight then
                    local okH, h = pcall(cf.GetHeight, cf)
                    if okH and h and h > 0 then height = math.floor(h + 0.5) end
                end
            end

            windows[i] = {
                index = i,
                name = name,
                fontSize = fontSize or 14,
                r = r or 1,
                g = g or 1,
                b = b or 1,
                alpha = alpha or 1,
                shown = (shown == true or shown == 1),
                locked = (locked == true or locked == 1),
                docked = (docked == true or docked == 1),
                uninteractable = (uninteractable == true or uninteractable == 1),
                messages = messages,
                channels = channels,
                point = point,
                relativeTo = relName,
                relativePoint = relativePoint,
                x = x,
                y = y,
                width = width,
                height = height,
            }
        end
    end

    local snapshot = {
        timestamp = time(),
        numWindows = winCount,
        windows = windows,
    }

    char.chatSettings = snapshot
    local cached = self.cachedCurrentChar
    if cached and (cached.key == targetKey or cached.name == targetKey or cached.fullName == targetKey) then
        cached.chatSettings = snapshot
    end

    return true, winCount
end

function ForeverAlts:CopyChatSettings(sourceCharKey, targetCharKey)
    if not sourceCharKey or sourceCharKey == "" then
        return false, "No source character selected."
    end

    if not ForeverAltsDB or not ForeverAltsDB.characters then
        return false, "Database not initialized."
    end

    local sourceChar = ForeverAltsDB.characters[sourceCharKey]
    if not sourceChar then
        local found = self:FindCharacter(sourceCharKey)
        if found then
            sourceChar = found
            sourceCharKey = found.fullName or found.name or sourceCharKey
        end
    end

    if not sourceChar then
        return false, string.format("Source character '%s' not found.", tostring(sourceCharKey))
    end

    local snapshot = sourceChar.chatSettings
    if not snapshot or not snapshot.windows or not next(snapshot.windows) then
        local displayName = sourceChar.fullName or sourceChar.name or sourceCharKey
        return false, string.format("No chat snapshot found for %s. Log in to %s first to capture.", displayName, displayName)
    end

    local targetKey = targetCharKey or self.curPlayerKey
    if not targetKey then
        local _, _, full = self:GetPlayerNames()
        targetKey = full and self:GetCharacterKey(full)
    end

    local copiedCount = 0

    for i, win in pairs(snapshot.windows) do
        local cf = _G["ChatFrame" .. i]
        if cf then
            copiedCount = copiedCount + 1

            if SetChatWindowName and win.name then
                pcall(SetChatWindowName, i, win.name)
            end
            if SetChatWindowSize and win.fontSize then
                pcall(SetChatWindowSize, i, win.fontSize)
            end
            if SetChatWindowColor and win.r and win.g and win.b then
                pcall(SetChatWindowColor, i, win.r, win.g, win.b)
            end
            if SetChatWindowAlpha and win.alpha then
                pcall(SetChatWindowAlpha, i, win.alpha)
            end
            if SetChatWindowShown and win.shown ~= nil then
                pcall(SetChatWindowShown, i, win.shown and 1 or 0)
            end
            if SetChatWindowLocked and win.locked ~= nil then
                pcall(SetChatWindowLocked, i, win.locked and 1 or 0)
            end
            if SetChatWindowUninteractable and win.uninteractable ~= nil then
                pcall(SetChatWindowUninteractable, i, win.uninteractable and 1 or 0)
            end

            -- Message groups
            if ChatFrame_RemoveAllMessageGroups and ChatFrame_AddMessageGroup and win.messages then
                pcall(ChatFrame_RemoveAllMessageGroups, cf)
                for _, grp in ipairs(win.messages) do
                    pcall(ChatFrame_AddMessageGroup, cf, grp)
                end
            end

            -- Channels
            if ChatFrame_RemoveAllChannels and ChatFrame_AddChannel and win.channels then
                pcall(ChatFrame_RemoveAllChannels, cf)
                for _, ch in ipairs(win.channels) do
                    pcall(ChatFrame_AddChannel, cf, ch)
                end
            end

            -- Screen positioning & dimensions
            if win.point and win.relativePoint and win.x and win.y and cf.ClearAllPoints and cf.SetPoint then
                pcall(function()
                    cf:ClearAllPoints()
                    local rel = _G[win.relativeTo] or UIParent
                    cf:SetPoint(win.point, rel, win.relativePoint, win.x, win.y)
                    if win.width and win.width > 0 and cf.SetWidth then
                        cf:SetWidth(win.width)
                    end
                    if win.height and win.height > 0 and cf.SetHeight then
                        cf:SetHeight(win.height)
                    end
                    if FCF_SavePositionAndDimensions then
                        FCF_SavePositionAndDimensions(cf)
                    end
                end)
            end
        end
    end

    if FCF_DockUpdate then
        pcall(FCF_DockUpdate)
    end

    -- Re-capture current character's new layout so DB reflects the applied changes
    self:CaptureChatSettings(targetKey)

    local srcName = sourceChar.fullName or sourceChar.name or sourceCharKey
    return true, string.format("Copied chat layout from %s (%d windows updated).", srcName, copiedCount)
end

function ForeverAlts:GetChatProfilesList()
    local list = {}
    if not ForeverAltsDB or not ForeverAltsDB.characters then
        return list
    end

    for k, c in pairs(ForeverAltsDB.characters) do
        if c.chatSettings and c.chatSettings.windows and next(c.chatSettings.windows) then
            local isCur = self:IsCurrentPlayer(c)
            table.insert(list, {
                key = k,
                name = c.fullName or c.name or k,
                realm = c.realm or "Forever",
                class = c.classFile or c.class or "WARRIOR",
                numWindows = c.chatSettings.numWindows or 0,
                timestamp = c.chatSettings.timestamp or 0,
                isCurrent = isCur,
            })
        end
    end

    table.sort(list, function(a, b)
        if a.isCurrent ~= b.isCurrent then
            return not a.isCurrent
        end
        return (a.name or "") < (b.name or "")
    end)

    return list
end



