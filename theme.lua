-- ============================================================================
-- CLIAlts: Design Tokens and Color System
-- File: theme.lua
-- ============================================================================

local addonName, addonTable = ...
local CLIAlts = addonTable or _G["CLIAlts"] or {}
_G["CLIAlts"] = CLIAlts
_G["clialts"] = CLIAlts

-- Design Tokens (Default Modern v2 Dark Theme)
CLIAlts.TOKENS = {
    bg     = "0F131A",
    panel  = "171C26",
    raised = "232B3A",
    line   = "2B3445",
    text   = "F3F5F8",
    muted  = "9AA6B8",
    brand  = "E8B64A",
    warn   = "F2B84B",
    fill   = "4CC2D6",
    info   = "7FDBEA",
    radius = { row = 6, card = 10, window = 12 },
    space  = { 4, 8, 12, 16 },
    rowH   = 52,
    minClick = 28,
    font   = { title = 19, body = 14, small = 12, num = 14 },
}

-- Alternative Theme Token Sets
CLIAlts.THEME_TOKENS = {
    ["DARK"] = CLIAlts.TOKENS,
    ["AMBER"] = {
        bg     = "100E08",
        panel  = "19150C",
        raised = "282114",
        line   = "42361F",
        text   = "F4EAD2",
        muted  = "A9A08C",
        brand  = "F2C94C",
        warn   = "FFB547",
        fill   = "F2C94C",
        info   = "57D6E8",
        radius = { row = 6, card = 10, window = 12 },
        space  = { 4, 8, 12, 16 },
        rowH   = 52,
        minClick = 28,
        font   = { title = 19, body = 14, small = 12, num = 14 },
    },
    ["LIGHT"] = {
        bg     = "F4F6F9",
        panel  = "FFFFFF",
        raised = "E5E9F0",
        line   = "D1D7E0",
        text   = "1A202C",
        muted  = "718096",
        brand  = "D97706",
        warn   = "DD6B20",
        fill   = "0284C7",
        info   = "0284C7",
        radius = { row = 6, card = 10, window = 12 },
        space  = { 4, 8, 12, 16 },
        rowH   = 52,
        minClick = 28,
        font   = { title = 19, body = 14, small = 12, num = 14 },
    },
    ["MONO"] = {
        bg     = "0A0A0A",
        panel  = "141414",
        raised = "222222",
        line   = "383838",
        text   = "F0F0F0",
        muted  = "888888",
        brand  = "CCCCCC",
        warn   = "FFAA00",
        fill   = "AAAAAA",
        info   = "CCCCCC",
        radius = { row = 6, card = 10, window = 12 },
        space  = { 4, 8, 12, 16 },
        rowH   = 52,
        minClick = 28,
        font   = { title = 19, body = 14, small = 12, num = 14 },
    },
    ["COLORBLIND"] = {
        bg     = "080F1D",
        panel  = "0E1B33",
        raised = "172B52",
        line   = "25437E",
        text   = "E6F2FF",
        muted  = "7AA3CC",
        brand  = "FFD933",
        warn   = "F27333",
        fill   = "59BFFF",
        info   = "FFD933",
        radius = { row = 6, card = 10, window = 12 },
        space  = { 4, 8, 12, 16 },
        rowH   = 52,
        minClick = 28,
        font   = { title = 19, body = 14, small = 12, num = 14 },
    },
    ["SYNTHWAVE"] = {
        bg     = "0F0514",
        panel  = "1A0A24",
        raised = "2B103C",
        line   = "441A5E",
        text   = "FFE6F2",
        muted  = "B36B9E",
        brand  = "FF3399",
        warn   = "FFB86C",
        fill   = "33F2FF",
        info   = "33F2FF",
        radius = { row = 6, card = 10, window = 12 },
        space  = { 4, 8, 12, 16 },
        rowH   = 52,
        minClick = 28,
        font   = { title = 19, body = 14, small = 12, num = 14 },
    },
    ["DRACULA"] = {
        bg     = "14151F",
        panel  = "1E1F2E",
        raised = "282A36",
        line   = "44475A",
        text   = "F8F8F2",
        muted  = "6272A4",
        brand  = "BD93F9",
        warn   = "FFB86C",
        fill   = "50FA7B",
        info   = "8BE9FD",
        radius = { row = 6, card = 10, window = 12 },
        space  = { 4, 8, 12, 16 },
        rowH   = 52,
        minClick = 28,
        font   = { title = 19, body = 14, small = 12, num = 14 },
    },
}

function CLIAlts:GetTokens()
    local themeKey = (CLIAltsDB and CLIAltsDB.settings and CLIAltsDB.settings.theme) or "DARK"
    return self.THEME_TOKENS[themeKey] or self.TOKENS
end

function CLIAlts:Hex(token, alpha)
    if type(token) == "table" then
        if token.r and token.g and token.b then
            return token.r, token.g, token.b, alpha or token.a or 1
        elseif token[1] and token[2] and token[3] then
            return token[1], token[2], token[3], alpha or token[4] or 1
        end
    end
    local hexStr = token
    if type(token) == "string" then
        local activeTokens = (self.GetTokens and self:GetTokens()) or self.TOKENS
        if activeTokens and activeTokens[token] and type(activeTokens[token]) == "string" then
            hexStr = activeTokens[token]
        elseif self.TOKENS and self.TOKENS[token] and type(self.TOKENS[token]) == "string" then
            hexStr = self.TOKENS[token]
        end
        hexStr = hexStr:gsub("^#", ""):gsub("^|c%x%x", "")
        if #hexStr == 6 then
            local r = tonumber(hexStr:sub(1, 2), 16) or 255
            local g = tonumber(hexStr:sub(3, 4), 16) or 255
            local b = tonumber(hexStr:sub(5, 6), 16) or 255
            return r / 255, g / 255, b / 255, alpha or 1
        elseif #hexStr == 8 then
            local a = tonumber(hexStr:sub(1, 2), 16) or 255
            local r = tonumber(hexStr:sub(3, 4), 16) or 255
            local g = tonumber(hexStr:sub(5, 6), 16) or 255
            local b = tonumber(hexStr:sub(7, 8), 16) or 255
            return r / 255, g / 255, b / 255, alpha or (a / 255)
        end
    end
    return 1, 1, 1, alpha or 1
end
