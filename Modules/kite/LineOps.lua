local MODULE_VERSION = "1.5.3"
local LineOps = { VERSION = MODULE_VERSION, version = MODULE_VERSION }
local unpack = table.unpack or unpack
local MAX_ROUND_DECIMALS = 12
local RESTORE_CHUNK_SIZE = 500

local function safeRequire(name)
    local ok, value = pcall(require, name)
    if ok then return value end
    return nil
end

local util = safeRequire("aegisub.util")
local DependencyControl = safeRequire("l0.DependencyControl")
local depctrl
if DependencyControl then
    depctrl = DependencyControl({
        name = "kite.LineOps",
        version = MODULE_VERSION,
        description = "Shared line, selection and lightweight ASS operations for Kite macros",
        author = "Kiterow",
        url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
        moduleName = "kite.LineOps",
        feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    })
end

local function trim(value)
    return (tostring(value == nil and "" or value):match("^%s*(.-)%s*$")) or ""
end

local VIRAMA = {
    [0x094D] = true, [0x09CD] = true, [0x0A4D] = true, [0x0ACD] = true,
    [0x0B4D] = true, [0x0BCD] = true, [0x0C4D] = true, [0x0CCD] = true,
    [0x0D3B] = true, [0x0D3C] = true, [0x0D4D] = true, [0x0DCA] = true,
    [0x0E3A] = true, [0x0EBA] = true, [0x0F84] = true, [0x1039] = true,
    [0x103A] = true, [0x1714] = true, [0x1734] = true, [0x17D2] = true,
    [0x1A60] = true, [0x1B44] = true, [0x1BAA] = true, [0x1BAB] = true,
    [0x1BF2] = true, [0x1BF3] = true, [0x2D7F] = true, [0xA806] = true,
    [0xA82C] = true, [0xA8C4] = true, [0xA953] = true, [0xA9C0] = true,
    [0xAAF6] = true, [0xABED] = true, [0x10A3F] = true, [0x11046] = true,
    [0x11070] = true, [0x11133] = true, [0x11134] = true, [0x111C0] = true,
    [0x11235] = true, [0x112EA] = true, [0x1134D] = true, [0x11442] = true,
    [0x11446] = true, [0x114C2] = true, [0x115BF] = true, [0x1163F] = true,
    [0x116B6] = true, [0x1172B] = true, [0x11839] = true, [0x1193D] = true,
    [0x1193E] = true, [0x119E0] = true, [0x11A34] = true, [0x11A47] = true,
    [0x11A99] = true, [0x11C3F] = true, [0x11D44] = true, [0x11D45] = true,
    [0x11D97] = true, [0x11F41] = true, [0x11F42] = true,
}

local PREPEND_RANGES = {
    {0x0600, 0x0605}, {0x06DD, 0x06DD}, {0x070F, 0x070F}, {0x0890, 0x0891},
    {0x08E2, 0x08E2}, {0x0D4E, 0x0D4E}, {0x110BD, 0x110BD}, {0x110CD, 0x110CD},
    {0x111C2, 0x111C3}, {0x113D1, 0x113D1}, {0x1193F, 0x1193F}, {0x11941, 0x11941},
    {0x11A3A, 0x11A3A}, {0x11A84, 0x11A89}, {0x11D46, 0x11D46}, {0x11F02, 0x11F02},
}

local SENTENCE_TERMINAL_RANGES = {
    0x0021,0x0021, 0x002E,0x002E, 0x003F,0x003F, 0x0589,0x0589, 0x061D,0x061F,
    0x06D4,0x06D4, 0x0700,0x0702, 0x07F9,0x07F9, 0x0837,0x0837, 0x0839,0x0839,
    0x083D,0x083E, 0x0964,0x0965, 0x104A,0x104B, 0x1362,0x1362, 0x1367,0x1368,
    0x166E,0x166E, 0x1735,0x1736, 0x17D4,0x17D5, 0x1803,0x1803, 0x1809,0x1809,
    0x1944,0x1945, 0x1AA8,0x1AAB, 0x1B4E,0x1B4F, 0x1B5A,0x1B5B, 0x1B5E,0x1B5F,
    0x1B7D,0x1B7F, 0x1C3B,0x1C3C, 0x1C7E,0x1C7F, 0x2024,0x2024, 0x203C,0x203D,
    0x2047,0x2049, 0x2CF9,0x2CFB, 0x2E2E,0x2E2E, 0x2E3C,0x2E3C, 0x2E53,0x2E54,
    0x3002,0x3002, 0xA4FF,0xA4FF, 0xA60E,0xA60F, 0xA6F3,0xA6F3, 0xA6F7,0xA6F7,
    0xA876,0xA877, 0xA8CE,0xA8CF, 0xA92F,0xA92F, 0xA9C8,0xA9C9, 0xAA5D,0xAA5F,
    0xAAF0,0xAAF1, 0xABEB,0xABEB, 0xFE12,0xFE12, 0xFE15,0xFE16, 0xFE52,0xFE52,
    0xFE56,0xFE57, 0xFF01,0xFF01, 0xFF0E,0xFF0E, 0xFF1F,0xFF1F, 0xFF61,0xFF61,
    0x10A56,0x10A57, 0x10F55,0x10F59, 0x10F86,0x10F89, 0x11047,0x11048,
    0x110BE,0x110C1, 0x11141,0x11143, 0x111C5,0x111C6, 0x111CD,0x111CD,
    0x111DE,0x111DF, 0x11238,0x11239, 0x1123B,0x1123C, 0x112A9,0x112A9,
    0x113D4,0x113D5, 0x1144B,0x1144C, 0x115C2,0x115C3, 0x115C9,0x115D7,
    0x11641,0x11642, 0x1173C,0x1173E, 0x11944,0x11944, 0x11946,0x11946,
    0x11A42,0x11A43, 0x11A9B,0x11A9C, 0x11C41,0x11C42, 0x11EF7,0x11EF8,
    0x11F43,0x11F44, 0x16A6E,0x16A6F, 0x16AF5,0x16AF5, 0x16B37,0x16B38,
    0x16B44,0x16B44, 0x16D6E,0x16D6F, 0x16E98,0x16E98, 0x1BC9F,0x1BC9F,
    0x1DA88,0x1DA88,
}

local function inRanges(codepoint, ranges)
    for _, range in ipairs(ranges) do
        if codepoint >= range[1] and codepoint <= range[2] then return true end
    end
    return false
end

local function utf8Next(text, position)
    local first = text:byte(position)
    if not first then return nil, position end
    if first < 0x80 then return first, position + 1 end
    local second = text:byte(position + 1)
    if first >= 0xC2 and first <= 0xDF and second and second >= 0x80 and second <= 0xBF then
        return (first - 0xC0) * 0x40 + second - 0x80, position + 2
    end
    local third = text:byte(position + 2)
    if first >= 0xE0 and first <= 0xEF and second and third
        and second >= (first == 0xE0 and 0xA0 or 0x80)
        and second <= (first == 0xED and 0x9F or 0xBF)
        and third >= 0x80 and third <= 0xBF then
        return (first - 0xE0) * 0x1000 + (second - 0x80) * 0x40 + third - 0x80, position + 3
    end
    local fourth = text:byte(position + 3)
    if first >= 0xF0 and first <= 0xF4 and second and third and fourth
        and second >= (first == 0xF0 and 0x90 or 0x80)
        and second <= (first == 0xF4 and 0x8F or 0xBF)
        and third >= 0x80 and third <= 0xBF
        and fourth >= 0x80 and fourth <= 0xBF then
        return (first - 0xF0) * 0x40000 + (second - 0x80) * 0x1000
            + (third - 0x80) * 0x40 + fourth - 0x80, position + 4
    end
    return first, position + 1
end

local function firstCodepoint(text)
    return utf8Next(tostring(text or ""), 1)
end

local function isSentenceTerminal(text)
    local codepoint = firstCodepoint(text)
    if not codepoint then return false end
    for index = 1, #SENTENCE_TERMINAL_RANGES, 2 do
        if codepoint >= SENTENCE_TERMINAL_RANGES[index]
            and codepoint <= SENTENCE_TERMINAL_RANGES[index + 1] then return true end
    end
    return false
end

local function lastCodepoint(text)
    local codepoint, position = nil, 1
    while position <= #text do codepoint, position = utf8Next(text, position) end
    return codepoint
end

local function isFallbackMark(codepoint)
    return (codepoint >= 0x0300 and codepoint <= 0x036F)
        or (codepoint >= 0x1AB0 and codepoint <= 0x1AFF)
        or (codepoint >= 0x1DC0 and codepoint <= 0x1DFF)
        or (codepoint >= 0x20D0 and codepoint <= 0x20FF)
        or (codepoint >= 0xFE00 and codepoint <= 0xFE0F)
        or (codepoint >= 0xE0100 and codepoint <= 0xE01EF)
end

local function hangulType(codepoint)
    if (codepoint >= 0x1100 and codepoint <= 0x115F)
        or (codepoint >= 0xA960 and codepoint <= 0xA97C) then return "L" end
    if (codepoint >= 0x1160 and codepoint <= 0x11A7)
        or (codepoint >= 0xD7B0 and codepoint <= 0xD7C6) then return "V" end
    if (codepoint >= 0x11A8 and codepoint <= 0x11FF)
        or (codepoint >= 0xD7CB and codepoint <= 0xD7FB) then return "T" end
    if codepoint >= 0xAC00 and codepoint <= 0xD7A3 then
        return (codepoint - 0xAC00) % 28 == 0 and "LV" or "LVT"
    end
end

local function joinsHangul(left, right)
    local leftType, rightType = hangulType(left), hangulType(right)
    return leftType == "L" and (rightType == "L" or rightType == "V"
            or rightType == "LV" or rightType == "LVT")
        or (leftType == "LV" or leftType == "V") and (rightType == "V" or rightType == "T")
        or (leftType == "LVT" or leftType == "T") and rightType == "T"
end

local function regexHas(regex, text, pattern)
    if not regex or type(regex.find) ~= "function" then return false end
    local ok, matches = pcall(regex.find, text, pattern)
    return ok and type(matches) == "table" and #matches > 0
end

local function rawGraphemes(text, regex)
    if regex and type(regex.find) == "function" then
        local ok, matches = pcall(regex.find, text, "\\\\[Nnh]|\\X")
        if ok and type(matches) == "table" then
            local units = {}
            for _, match in ipairs(matches) do units[#units + 1] = match.str end
            if table.concat(units) == text then return units end
        end
    end
    local units, position = {}, 1
    while position <= #text do
        local escape = text:sub(position, position + 1)
        if escape == "\\N" or escape == "\\n" or escape == "\\h" then
            units[#units + 1], position = escape, position + 2
        else
            local start = position
            _, position = utf8Next(text, position)
            units[#units + 1] = text:sub(start, position - 1)
        end
    end
    return units
end

local function graphemes(text, regex)
    text = tostring(text or "")
    local result, regionalRun = {}, 0
    for _, unit in ipairs(rawGraphemes(text, regex)) do
        local isEscape = unit == "\\N" or unit == "\\n" or unit == "\\h"
        local first = not isEscape and utf8Next(unit, 1) or nil
        local previous = result[#result]
        local previousEscape = previous == "\\N" or previous == "\\n" or previous == "\\h"
        local last = previous and not previousEscape and lastCodepoint(previous) or nil
        local regional = first and first >= 0x1F1E6 and first <= 0x1F1FF
        local join = previous and not isEscape and not previousEscape and (
            (last == 0x0D and first == 0x0A)
            or first == 0x200C or first == 0x200D or last == 0x200D
            or isFallbackMark(first) or regexHas(regex, unit, "^\\p{M}+$")
            or (first >= 0x1F3FB and first <= 0x1F3FF)
            or (first >= 0xE0020 and first <= 0xE007F)
            or VIRAMA[last] or inRanges(last, PREPEND_RANGES)
            or joinsHangul(last, first)
            or (regional and regionalRun % 2 == 1)
        )
        if join then result[#result] = previous .. unit else result[#result + 1] = unit end
        regionalRun = regional and regionalRun + 1 or 0
    end
    return result
end

local function copy(value)
    if type(value) ~= "table" then return value end
    if util and type(util.copy) == "function" then
        local ok, result = pcall(util.copy, value)
        if ok then return result end
    end
    local result = {}
    for key, item in pairs(value) do result[key] = item end
    return setmetatable(result, getmetatable(value))
end

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    if util and type(util.deep_copy) == "function" then
        local ok, result = pcall(util.deep_copy, value)
        if ok then return result end
    end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do
        result[deepCopy(key, seen)] = deepCopy(item, seen)
    end
    return setmetatable(result, getmetatable(value))
end

local function finiteNumber(value)
    local number = tonumber(value)
    if not number or number ~= number or math.abs(number) == math.huge then return nil end
    return number
end

local function round(value)
    value = finiteNumber(value) or 0
    if value >= 0 then return math.floor(value + 0.5) end
    return math.ceil(value - 0.5)
end


local function roundTo(value, decimals)
    value = finiteNumber(value) or 0
    decimals = math.max(0, math.min(MAX_ROUND_DECIMALS, round(finiteNumber(decimals) or 0)))
    local factor = 10 ^ decimals
    if value >= 0 then return math.floor(value * factor + 0.5) / factor end
    return math.ceil(value * factor - 0.5) / factor
end

local function shallowEqual(left, right)
    left = type(left) == "table" and left or {}
    right = type(right) == "table" and right or {}
    for key, value in pairs(left) do if right[key] ~= value then return false end end
    for key, value in pairs(right) do if left[key] ~= value then return false end end
    return true
end
local function clamp(value, minimum, maximum)
    value = finiteNumber(value) or 0
    if minimum ~= nil and value < minimum then return minimum end
    if maximum ~= nil and value > maximum then return maximum end
    return value
end

local function checkCancelled()
    if aegisub and aegisub.progress and type(aegisub.progress.is_cancelled) == "function" then
        local ok, cancelled = pcall(aegisub.progress.is_cancelled)
        if ok and cancelled then
            if type(aegisub.cancel) == "function" then return aegisub.cancel() end
            error("cancelled", 0)
        end
    end
    return false
end

local function progress(task, percent)
    if aegisub and aegisub.progress then
        if task ~= nil and type(aegisub.progress.task) == "function" then pcall(aegisub.progress.task, tostring(task)) end
        if percent ~= nil and type(aegisub.progress.set) == "function" then pcall(aegisub.progress.set, clamp(percent, 0, 100)) end
    end
    checkCancelled()
end

local function decodedPath(specification)
    if not aegisub or type(aegisub.decode_path) ~= "function" then return nil end
    local ok, value = pcall(aegisub.decode_path, specification)
    if not ok or type(value) ~= "string" or value == "" or value == specification then return nil end
    return value
end

local function projectProperties()
    if not aegisub or type(aegisub.project_properties) ~= "function" then return {} end
    local ok, value = pcall(aegisub.project_properties)
    if ok and type(value) == "table" then return value end
    return {}
end

local subtitleLength, subtitleLine

local function positiveNumber(value)
    local number = finiteNumber(value)
    if number and number > 0 then return number end
    return nil
end

local function objectMember(object, key)
    if object == nil then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok then return value end
    return nil
end

local function resolutionFields(object)
    if object == nil then return nil, nil end
    local x = positiveNumber(objectMember(object, "PlayResX"))
        or positiveNumber(objectMember(object, "playresx"))
        or positiveNumber(objectMember(object, "res_x"))
    local y = positiveNumber(objectMember(object, "PlayResY"))
        or positiveNumber(objectMember(object, "playresy"))
        or positiveNumber(objectMember(object, "res_y"))
    return x, y
end

local function methodResolution(object)
    local method = objectMember(object, "script_resolution") or objectMember(object, "scriptResolution")
    if type(method) ~= "function" then return nil, nil end
    local ok, x, y = pcall(method, object)
    if not ok then return nil, nil end
    return positiveNumber(x), positiveNumber(y)
end

-- Resolve PlayRes from an ASS subtitle object, a LineCollection/ASS object, a
-- line belonging to one, or a metadata table. Missing axes independently use
-- the optional positive fallbacks. The third result is true only when both
-- axes came from the source rather than a fallback.
local function scriptResolution(source, fallbackX, fallbackY)
    local x, y
    local seen = {}
    local candidates = {}
    local function inspect(object)
        local kind = type(object)
        if (kind ~= "table" and kind ~= "userdata") or seen[object] then return end
        seen[object] = true
        candidates[#candidates + 1] = object
        local rx, ry = methodResolution(object)
        x, y = x or rx, y or ry
        rx, ry = resolutionFields(object)
        x, y = x or rx, y or ry
    end

    inspect(source)
    local parent = objectMember(source, "parentCollection")
    inspect(parent)
    inspect(objectMember(source, "meta"))
    inspect(objectMember(source, "scriptInfo"))
    inspect(objectMember(parent, "meta"))
    inspect(objectMember(source, "sub"))
    inspect(objectMember(parent, "sub"))

    if not x or not y then
        for _, candidate in ipairs(candidates) do
            local count = subtitleLength(candidate)
            for index = 1, count do
                local line = subtitleLine(candidate, index)
                if line and line.class == "info" then
                    local key = tostring(line.key or ""):lower()
                    if key == "playresx" then x = x or positiveNumber(line.value)
                    elseif key == "playresy" then y = y or positiveNumber(line.value) end
                    if x and y then break end
                end
            end
            if x and y then break end
        end
    end

    local resolved = x ~= nil and y ~= nil
    return x or positiveNumber(fallbackX), y or positiveNumber(fallbackY), resolved
end

local separator = package.config:sub(1, 1)

local function joinPath(left, right)
    left = tostring(left or "")
    right = tostring(right or "")
    if left == "" then return right end
    if right == "" then return left end
    if left:sub(-1) == "/" or left:sub(-1) == "\\" then return left .. right end
    return left .. separator .. right
end

local function subtitlePath()
    if not aegisub or type(aegisub.file_name) ~= "function" then return nil end
    local ok, name = pcall(aegisub.file_name)
    if not ok or type(name) ~= "string" then return nil end
    name = trim(name)
    if name == "" or name:lower() == "untitled" then return nil end
    if name:match("^[/\\]") or name:match("^[A-Za-z]:[/\\]") then return name end
    local folder = decodedPath("?script")
    if not folder then return name end
    return joinPath(folder, name)
end

local function subtitleFolder(requireSaved)
    local path = subtitlePath()
    if path then
        local folder = path:match("^(.*)[/\\][^/\\]+$")
        if folder and folder ~= "" then return folder end
    end
    if requireSaved then return nil end
    return decodedPath("?script")
end

local knownTags = {
    "fscx", "fscy", "fsp", "xbord", "ybord", "xshad", "yshad", "alpha", "iclip", "clip",
    "move", "fade", "pos", "org", "frz", "frx", "fry", "fax", "fay", "bord", "shad",
    "blur", "be", "fn", "fs", "fe", "an", "a", "q", "pbo", "p", "r", "k", "K", "kf",
    "ko", "kt", "b", "i", "u", "s", "c",
}

table.sort(knownTags, function(left, right) return #left > #right end)

local function wantedSet(wanted)
    if wanted == nil then return nil end
    local set = {}
    if type(wanted) == "string" then
        set[wanted:lower()] = true
    elseif type(wanted) == "table" then
        for key, value in pairs(wanted) do
            if type(key) == "number" then set[tostring(value):lower()] = true
            elseif value then set[tostring(key):lower()] = true end
        end
    end
    return set
end

local function identifyTag(block, index)
    local tail = block:sub(index)
    local numeric, identifier = tail:match("^(%d?)([_%a][_%w]*)")
    if not identifier then return nil end
    for _, name in ipairs(knownTags) do
        local prefix = numeric .. name
        if tail:sub(1, #prefix):lower() == prefix:lower() then
            return prefix, (numeric .. name):lower(), index + #prefix
        end
    end
    return numeric .. identifier, (numeric .. identifier):lower(), index + #numeric + #identifier
end

local function tagCalls(text, wanted)
    text = tostring(text or "")
    local wantedNames = wantedSet(wanted)
    local calls = {}
    local cursor = 1
    while true do
        local openStart = text:find("{", cursor, true)
        if not openStart then break end
        local closeStart = text:find("}", openStart + 1, true)
        if not closeStart then break end
        local block = text:sub(openStart + 1, closeStart - 1)
        if block:match("^%s*\\") then
            local index = 1
            local depth = 0
            while index <= #block do
                local char = block:sub(index, index)
                if char == "(" then
                    depth = depth + 1
                    index = index + 1
                elseif char == ")" then
                    if depth > 0 then depth = depth - 1 end
                    index = index + 1
                elseif char == "\\" then
                    local rawName, name, valueStart = identifyTag(block, index + 1)
                    if not name then
                        index = index + 1
                    else
                        local valueEnd = valueStart - 1
                        local parenthesized = block:sub(valueStart, valueStart) == "("
                        if parenthesized then
                            local nested = 0
                            local scan = valueStart
                            while scan <= #block do
                                local current = block:sub(scan, scan)
                                if current == "(" then nested = nested + 1
                                elseif current == ")" then
                                    nested = nested - 1
                                    if nested == 0 then
                                        valueEnd = scan
                                        break
                                    end
                                end
                                scan = scan + 1
                            end
                            if nested ~= 0 then valueEnd = #block end
                        else
                            local scan = valueStart
                            while scan <= #block do
                                local current = block:sub(scan, scan)
                                if current == "\\" or (current == ")" and depth > 0) then break end
                                scan = scan + 1
                            end
                            valueEnd = scan - 1
                        end
                        local startPosition = openStart + index
                        local finishPosition = openStart + valueEnd
                        if wantedNames == nil or wantedNames[name] or wantedNames[rawName:lower()] then
                            calls[#calls + 1] = {
                                name = name,
                                raw_name = rawName,
                                raw = text:sub(startPosition, finishPosition),
                                value = block:sub(valueStart, valueEnd),
                                start = startPosition,
                                finish = finishPosition,
                                block_start = openStart,
                                block_finish = closeStart,
                                top_level = depth == 0,
                            }
                        end
                        index = parenthesized and valueStart or math.max(valueEnd + 1, index + 1)
                    end
                else
                    index = index + 1
                end
            end
        end
        cursor = closeStart + 1
    end
    return calls
end

local function overrideTokens(content)
    content = tostring(content or "")
    local tokens = {}
    for _, call in ipairs(tagCalls("{" .. content .. "}")) do
        if call.top_level then
            tokens[#tokens + 1] = {
                name = call.name,
                raw_name = call.raw_name,
                raw = call.raw,
                value = call.value,
                start_position = call.start - 1,
                end_position = call.finish - 1,
            }
        end
    end
    return tokens
end

local function splitArguments(value)
    local text = trim(value)
    if text:sub(1, 1) == "(" and text:sub(-1) == ")" then text = text:sub(2, -2) end
    local result = {}
    local depth = 0
    local start = 1
    for index = 1, #text do
        local char = text:sub(index, index)
        if char == "(" then depth = depth + 1
        elseif char == ")" then
            if depth > 0 then depth = depth - 1 end
        elseif char == "," and depth == 0 then
            result[#result + 1] = trim(text:sub(start, index - 1))
            start = index + 1
        end
    end
    result[#result + 1] = trim(text:sub(start))
    return result
end

local function lastTagCall(text, wanted, topLevelOnly)
    local calls = tagCalls(text, wanted)
    for index = #calls, 1, -1 do
        if topLevelOnly == false or calls[index].top_level then return calls[index] end
    end
    return nil
end

local function tagArguments(text, wanted, topLevelOnly)
    local call = lastTagCall(text, wanted, topLevelOnly)
    if not call then return nil, nil end
    return splitArguments(call.value), call
end

local function tagNumber(text, wanted, defaultValue, topLevelOnly)
    local call = lastTagCall(text, wanted, topLevelOnly)
    if not call then return defaultValue, nil end
    local value = tonumber(trim(call.value))
    if value == nil then return defaultValue, call end
    return value, call
end

local function tagPair(text, wanted, defaultX, defaultY, topLevelOnly)
    local arguments, call = tagArguments(text, wanted, topLevelOnly)
    if not arguments then return defaultX, defaultY, nil end
    local x, y = tonumber(arguments[1]), tonumber(arguments[2])
    return x == nil and defaultX or x, y == nil and defaultY or y, call
end

local function position(text)
    local x, y, call = tagPair(text, "pos", nil, nil, true)
    if call and x ~= nil and y ~= nil then return { x = x, y = y }, call end
    return nil, call
end

local function hasTag(text, wanted, topLevelOnly)
    return lastTagCall(text, wanted, topLevelOnly) ~= nil
end

local function replaceTagCall(text, wanted, replacement, topLevelOnly)
    text = tostring(text or "")
    local call = lastTagCall(text, wanted, topLevelOnly)
    if not call then return text, false, nil end
    replacement = type(replacement) == "function" and replacement(call) or replacement
    if replacement == false or replacement == nil then replacement = "" end
    replacement = tostring(replacement)
    return text:sub(1, call.start - 1) .. replacement .. text:sub(call.finish + 1), true, call
end

local function mapTagCalls(text, wanted, callback, options)
    text = tostring(text or "")
    if type(callback) ~= "function" then return text, 0 end
    options = options or {}
    local topLevelOnly = options.top_level_only ~= false
    local calls = tagCalls(text, wanted)
    local changed = 0
    for index = #calls, 1, -1 do
        local call = calls[index]
        if not topLevelOnly or call.top_level then
            local replacement = callback(call, index, calls)
            if replacement ~= nil then
                if replacement == false then replacement = "" else replacement = tostring(replacement) end
                text = text:sub(1, call.start - 1) .. replacement .. text:sub(call.finish + 1)
                changed = changed + 1
            end
        end
    end
    return text, changed
end

local function scanSections(text)
    text = tostring(text or "")
    local sections = {}
    local drawing = 0
    local cursor = 1
    local function append(kind, value, first, last, state)
        sections[#sections + 1] = { type = kind, text = value, start = first, finish = last, drawing = state or 0 }
    end
    while cursor <= #text do
        local open = text:find("{", cursor, true)
        if not open then
            if cursor <= #text then append(drawing > 0 and "drawing" or "text", text:sub(cursor), cursor, #text, drawing) end
            break
        end
        if open > cursor then append(drawing > 0 and "drawing" or "text", text:sub(cursor, open - 1), cursor, open - 1, drawing) end
        local close = text:find("}", open + 1, true)
        if not close then
            append(drawing > 0 and "drawing" or "text", text:sub(open), open, #text, drawing)
            break
        end
        local block = text:sub(open + 1, close - 1)
        local isTag = block:match("^%s*\\") ~= nil
        append(isTag and "override" or "comment", block, open, close, drawing)
        if isTag then
            for _, call in ipairs(tagCalls("{" .. block .. "}", {p = true, r = true})) do
                if call.top_level then
                    local base = call.name:gsub("^%d", "")
                    if base == "r" then drawing = 0
                    elseif base == "p" then drawing = math.max(0, tonumber(call.value) or 0) end
                end
            end
        end
        cursor = close + 1
    end
    return sections
end

local function normalizeVisible(value)
    return trim(tostring(value or ""):gsub("\\[Nn]", " "):gsub("\\h", " "))
end

local function alphaValue(value)
    local hexadecimal = tostring(value or ""):match("&[Hh]([%x][%x])&")
    return hexadecimal and tonumber(hexadecimal, 16) or nil
end

local function newAlphaState()
    return { channels = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 } }
end

local function updateAlphaState(state, section)
    for _, call in ipairs(tagCalls("{" .. section .. "}", { alpha = true, ["1a"] = true, ["2a"] = true, ["3a"] = true, ["4a"] = true, r = true })) do
        if call.top_level then
            local name = call.name:lower()
            if name == "r" then
                state = newAlphaState()
            else
                local alpha = alphaValue(call.value)
                if alpha ~= nil then
                    if name == "alpha" then
                        for channel = 1, 4 do state.channels[channel] = alpha end
                    else
                        local channel = tonumber(name:sub(1, 1))
                        if channel then state.channels[channel] = alpha end
                    end
                end
            end
        end
    end
    return state
end

local function textIsVisible(state)
    for channel = 1, 4 do
        if state.channels[channel] < 255 then return true end
    end
    return false
end

local function analyzeText(text)
    local sections = scanSections(text)
    local plainParts = {}
    local visibleParts = {}
    local drawingParts = {}
    local hasDrawing = false
    local alpha = newAlphaState()
    for _, section in ipairs(sections) do
        if section.type == "override" then
            alpha = updateAlphaState(alpha, section.text)
        elseif section.type == "text" then
            plainParts[#plainParts + 1] = section.text
            if textIsVisible(alpha) then visibleParts[#visibleParts + 1] = section.text end
        elseif section.type == "drawing" then
            if trim(section.text) ~= "" then hasDrawing = true end
            drawingParts[#drawingParts + 1] = section.text
        end
    end
    return {
        sections = sections,
        plain = normalizeVisible(table.concat(plainParts)),
        visible = normalizeVisible(table.concat(visibleParts)),
        drawing = table.concat(drawingParts, " "),
        has_drawing = hasDrawing,
    }
end
local function overrideBlocks(text)
    local result = {}
    for _, section in ipairs(scanSections(text)) do
        if section.type == "override" then result[#result + 1] = section end
    end
    return result
end

local function visibleText(text)
    return analyzeText(text).visible
end

local function visibleLines(text)
    local parts = {}
    local alpha = newAlphaState()
    for _, section in ipairs(scanSections(text)) do
        if section.type == "override" then
            alpha = updateAlphaState(alpha, section.text)
        elseif section.type == "text" and textIsVisible(alpha) then
            parts[#parts + 1] = section.text
        end
    end
    local value = table.concat(parts):gsub("\\[Nn]", "\n"):gsub("\\h", " ")
    local lines = {}
    for line in (value .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = trim(line) end
    if #lines == 0 then lines[1] = "" end
    return lines
end
local function hasDrawing(text)
    return analyzeText(text).has_drawing
end

local function removeTagCalls(text, names)
    text = tostring(text or "")
    local calls = tagCalls(text, names)
    table.sort(calls, function(left, right)
        if left.start == right.start then return left.finish > right.finish end
        return left.start < right.start
    end)
    local spans = {}
    for _, call in ipairs(calls) do
        local previous = spans[#spans]
        if not previous or call.start > previous.finish then
            spans[#spans + 1] = { start = call.start, finish = call.finish }
        elseif call.finish > previous.finish then
            previous.finish = call.finish
        end
    end
    for index = #spans, 1, -1 do
        local span = spans[index]
        text = text:sub(1, span.start - 1) .. text:sub(span.finish + 1)
    end
    text = text:gsub("{%s*}", "")
    return text
end

local function stripClips(text)
    return removeTagCalls(text, {clip = true, iclip = true})
end

local function prependTag(text, tag)
    text = tostring(text or "")
    tag = tostring(tag or "")
    if tag == "" then return text end
    if tag:sub(1, 1) ~= "\\" then tag = "\\" .. tag end
    local leading = text:match("^%{%s*(\\)")
    if leading then return "{" .. tag .. text:sub(2) end
    return "{" .. tag .. "}" .. text
end

subtitleLength = function(subtitles)
    if type(subtitles) == "number" then return math.max(0, math.floor(subtitles)) end
    if subtitles == nil then return 0 end
    local ok, count = pcall(function() return #subtitles end)
    if ok and type(count) == "number" then return math.max(0, math.floor(count)) end
    local fallback = type(subtitles) == "table" and tonumber(subtitles.n) or nil
    return fallback and math.max(0, math.floor(fallback)) or 0
end

subtitleLine = function(subtitles, index)
    if subtitles == nil then return nil end
    local ok, line = pcall(function() return subtitles[index] end)
    if ok then return line end
    return nil
end

local function normalizeIndices(subtitles, selection, predicate)
    local maximum = subtitleLength(subtitles)
    local seen = {}
    local result = {}
    for _, value in ipairs(type(selection) == "table" and selection or {}) do
        local index = tonumber(value)
        if index and index == math.floor(index) and index >= 1 and index <= maximum and not seen[index] then
            local line = subtitleLine(subtitles, index)
            if not predicate or predicate(line, index) then
                seen[index] = true
                result[#result + 1] = index
            end
        end
    end
    table.sort(result)
    return result
end
local function selectedLines(subtitles, selection, predicate, requireAll)
    local records = {}
    local rejected = {}
    local seen = {}
    local maximum = subtitleLength(subtitles)
    for _, value in ipairs(type(selection) == "table" and selection or {}) do
        local index = tonumber(value)
        if not index or index ~= math.floor(index) or index < 1 or index > maximum then
            rejected[#rejected + 1] = value
        elseif not seen[index] then
            seen[index] = true
            local line = subtitleLine(subtitles, index)
            if not predicate or predicate(line, index) then
                records[#records + 1] = { index = index, line = line }
            else
                rejected[#rejected + 1] = index
            end
        end
    end
    table.sort(records, function(left, right) return left.index < right.index end)
    if requireAll and #rejected > 0 then return nil, rejected end
    return records, rejected
end
local function deleteIndices(subtitles, indices)
    local normalized = normalizeIndices(subtitles, indices)
    for position = #normalized, 1, -1 do subtitles.delete(normalized[position]) end
    return normalized
end

local function insertLines(subtitles, operations)
    local grouped = {}
    local order = {}
    for operationIndex, operation in ipairs(operations or {}) do
        local index = tonumber(operation.index or operation[1])
        local lines = operation.lines or operation[2] or {}
        if index and index == math.floor(index) and index >= 1 and index <= #subtitles + 1 then
            if grouped[index] == nil then grouped[index] = {}; order[#order + 1] = index end
            if type(lines) ~= "table" or lines.class then lines = {lines} end
            for _, line in ipairs(lines) do
                grouped[index][#grouped[index] + 1] = { line = line, order = operationIndex }
            end
        end
    end
    table.sort(order, function(left, right) return left > right end)
    for _, index in ipairs(order) do
        local arguments = {}
        for _, record in ipairs(grouped[index]) do arguments[#arguments + 1] = record.line end
        if #arguments > 0 then subtitles.insert(index, unpack(arguments)) end
    end
    table.sort(order)
    local inserted = {}
    local shift = 0
    for _, index in ipairs(order) do
        local count = #grouped[index]
        local first = index + shift
        for offset = 0, count - 1 do inserted[#inserted + 1] = first + offset end
        shift = shift + count
    end
    return inserted
end

local function snapshot(subtitles)
    local result = {}
    for index = 1, #subtitles do result[index] = deepCopy(subtitles[index]) end
    return result
end

local function restore(subtitles, state)
    for index = #subtitles, 1, -1 do subtitles.delete(index) end
    for first = 1, #state, RESTORE_CHUNK_SIZE do
        local last = math.min(#state, first + RESTORE_CHUNK_SIZE - 1)
        local chunk = {}
        for index = first, last do chunk[#chunk + 1] = deepCopy(state[index]) end
        if #chunk > 0 then subtitles.insert(#subtitles + 1, unpack(chunk)) end
    end
    return true
end

local function transaction(subtitles, undoName, callback)
    if type(undoName) == "function" then callback, undoName = undoName, callback end
    assert(type(callback) == "function", "transaction callback required")
    local state = snapshot(subtitles)
    local function pack(...)
        return { n = select("#", ...), ... }
    end
    local packed = pack(pcall(callback))
    if not packed[1] then
        pcall(restore, subtitles, state)
        error(packed[2], 0)
    end
    if aegisub and type(aegisub.set_undo_point) == "function" and trim(undoName) ~= "" then
        pcall(aegisub.set_undo_point, tostring(undoName))
    end
    return unpack(packed, 2, packed.n)
end

LineOps.trim = trim
LineOps.graphemes = graphemes
LineOps.firstCodepoint = firstCodepoint
LineOps.isSentenceTerminal = isSentenceTerminal
LineOps.copy = copy
LineOps.deepCopy = deepCopy
LineOps.round = round
LineOps.roundTo = roundTo
LineOps.shallowEqual = shallowEqual
LineOps.clamp = clamp
LineOps.checkCancelled = checkCancelled
LineOps.progress = progress
LineOps.projectProperties = projectProperties
LineOps.scriptResolution = scriptResolution
LineOps.decodedPath = decodedPath
LineOps.subtitlePath = subtitlePath
LineOps.subtitleFolder = subtitleFolder
LineOps.scanSections = scanSections
LineOps.analyzeText = analyzeText
LineOps.overrideBlocks = overrideBlocks
LineOps.visibleText = visibleText
LineOps.visibleLines = visibleLines
LineOps.hasDrawing = hasDrawing
LineOps.tagCalls = tagCalls
LineOps.overrideTokens = overrideTokens
LineOps.splitArguments = splitArguments
LineOps.lastTagCall = lastTagCall
LineOps.tagArguments = tagArguments
LineOps.tagNumber = tagNumber
LineOps.tagPair = tagPair
LineOps.position = position
LineOps.hasTag = hasTag
LineOps.replaceTagCall = replaceTagCall
LineOps.mapTagCalls = mapTagCalls
LineOps.removeTagCalls = removeTagCalls
LineOps.stripClips = stripClips
LineOps.prependTag = prependTag
LineOps.subtitleLength = subtitleLength
LineOps.subtitleLine = subtitleLine
LineOps.normalizeIndices = normalizeIndices
LineOps.selectedLines = selectedLines
LineOps.deleteIndices = deleteIndices
LineOps.insertLines = insertLines
LineOps.snapshot = snapshot
LineOps.restore = restore
LineOps.transaction = transaction

if depctrl then
    LineOps.version = depctrl
    return depctrl:register(LineOps)
end
return LineOps
