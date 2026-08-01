local EventOps = { version = "1.0.0" }

local function safeRequire(name)
    local ok, value = pcall(require, name)
    if ok then return value end
    return nil
end

local DependencyControl = safeRequire("l0.DependencyControl")
local LineOps = safeRequire("kite.LineOps")
local depctrl
if DependencyControl then
    depctrl = DependencyControl({
        name = "kite.EventOps",
        version = EventOps.version,
        description = "Shared dialogue-event transformations for Kite macros",
        author = "Kiterow",
        url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
        moduleName = "kite.EventOps",
        feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
        {
            { "kite.LineOps", version = "1.5.0" },
        },
    })
end

local function trim(value)
    if LineOps and LineOps.trim then return LineOps.trim(value) end
    return (tostring(value == nil and "" or value):match("^%s*(.-)%s*$")) or ""
end

local function copy(value)
    if LineOps and LineOps.deepCopy then return LineOps.deepCopy(value) end
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = copy(item) end
    return out
end

local function subtitleLength(subtitles)
    if LineOps and LineOps.subtitleLength then return LineOps.subtitleLength(subtitles) end
    local ok, value = pcall(function() return #subtitles end)
    return ok and tonumber(value) or 0
end

local function dialogueIndices(subtitles, selection)
    if LineOps and LineOps.normalizeIndices then
        return LineOps.normalizeIndices(subtitles, selection, function(line)
            return line and line.class == "dialogue"
        end)
    end
    local seen, out = {}, {}
    local maximum = subtitleLength(subtitles)
    for _, raw in ipairs(type(selection) == "table" and selection or {}) do
        local index = tonumber(raw)
        if index and index == math.floor(index) and index >= 1 and index <= maximum and not seen[index] then
            local line = subtitles[index]
            if line and line.class == "dialogue" then
                seen[index] = true
                out[#out + 1] = index
            end
        end
    end
    table.sort(out)
    return out
end

local function leadingPrefix(text)
    text = tostring(text or "")
    if not LineOps or not LineOps.scanSections then
        local prefix, cursor = {}, 1
        while text:sub(cursor, cursor) == "{" do
            local close = text:find("}", cursor + 1, true)
            if not close then break end
            local block = text:sub(cursor, close)
            if block:find("\\", 1, true) then prefix[#prefix + 1] = block end
            cursor = close + 1
        end
        return table.concat(prefix)
    end
    local parts = {}
    for _, section in ipairs(LineOps.scanSections(text)) do
        if section.type == "text" or section.type == "drawing" then break end
        local raw = text:sub(section.start, section.finish)
        if section.type == "override" then
            raw = LineOps.removeTagCalls(raw, { p = true, pbo = true })
            if raw ~= "" then parts[#parts + 1] = raw end
        elseif section.type == "comment" then
            parts[#parts + 1] = raw
        end
    end
    return table.concat(parts)
end

local function cloneWithVisibleText(subtitles, selection, replacement)
    local indices = dialogueIndices(subtitles, selection)
    local operations = {}
    for _, index in ipairs(indices) do
        local clone = copy(subtitles[index])
        clone.text = leadingPrefix(clone.text) .. tostring(replacement or "")
        operations[#operations + 1] = { index = index + 1, lines = { clone } }
    end
    if #operations == 0 then return {}, 0 end
    local inserted
    if LineOps and LineOps.insertLines then
        inserted = LineOps.insertLines(subtitles, operations)
    else
        inserted = {}
        for position = #operations, 1, -1 do
            local operation = operations[position]
            subtitles.insert(operation.index, operation.lines[1])
        end
        local shift = 0
        for _, operation in ipairs(operations) do
            inserted[#inserted + 1] = operation.index + shift
            shift = shift + 1
        end
    end
    return inserted, #inserted
end

local lowerMap = {
    ["Á"] = "á", ["É"] = "é", ["Í"] = "í", ["Ó"] = "ó", ["Ú"] = "ú", ["Ü"] = "ü", ["Ñ"] = "ñ",
    ["À"] = "à", ["È"] = "è", ["Ì"] = "ì", ["Ò"] = "ò", ["Ù"] = "ù", ["Ç"] = "ç",
}

local letterSet = {
    ["á"] = true, ["é"] = true, ["í"] = true, ["ó"] = true, ["ú"] = true, ["ü"] = true, ["ñ"] = true,
    ["à"] = true, ["è"] = true, ["ì"] = true, ["ò"] = true, ["ù"] = true, ["ç"] = true,
}

local function utf8Characters(text)
    local out = {}
    for char in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = char end
    return out
end

local function lowerCharacter(char)
    return lowerMap[char] or tostring(char or ""):lower()
end

local function isLetter(char)
    if tostring(char or ""):match("^%a$") then return true end
    return letterSet[lowerCharacter(char)] == true
end

local hyphens = { ["-"] = true, ["‐"] = true, ["‑"] = true }

local function hasStutter(text)
    local visible = LineOps and LineOps.visibleText and LineOps.visibleText(text) or tostring(text or ""):gsub("{[^}]*}", "")
    local chars = utf8Characters(visible)
    for index = 1, #chars - 2 do
        local left, separator, right = chars[index], chars[index + 1], chars[index + 2]
        if hyphens[separator] and isLetter(left) and isLetter(right) and lowerCharacter(left) == lowerCharacter(right) then
            return true, index
        end
    end
    return false
end

local function addEffectMarker(effect, marker)
    effect = trim(effect)
    marker = trim(marker)
    if marker == "" then return effect, false end
    for token in effect:gmatch("%S+") do
        if token:lower() == marker:lower() then return effect, false end
    end
    if effect == "" then return marker, true end
    return effect .. " " .. marker, true
end

local function markStutter(subtitles, selection, marker)
    local changed = 0
    for _, index in ipairs(dialogueIndices(subtitles, selection)) do
        local line = subtitles[index]
        if hasStutter(line.text) then
            local effect, modified = addEffectMarker(line.effect, marker or "Komari")
            if modified then
                line.effect = effect
                subtitles[index] = line
                changed = changed + 1
            end
        end
    end
    return selection, changed
end

local function zero(value)
    local number = tonumber(trim(value))
    return number ~= nil and number == 0
end

local function adjustFade(text, removeIn, removeOut)
    if not LineOps or not LineOps.mapTagCalls then return tostring(text or ""), 0 end
    local result, changed = LineOps.mapTagCalls(text, "fad", function(call)
        local args = LineOps.splitArguments(call.value)
        if #args ~= 2 then return nil end
        local first, second = trim(args[1]), trim(args[2])
        local modified = false
        if removeIn and not zero(first) then first, modified = "0", true end
        if removeOut and not zero(second) then second, modified = "0", true end
        if not modified then return nil end
        if zero(first) and zero(second) then return false end
        return "\\fad(" .. first .. "," .. second .. ")"
    end, { top_level_only = true })
    if changed > 0 then result = result:gsub("{%s*}", "") end
    return result, changed
end

local function continuousFadeCleanup(subtitles, selection)
    local groups, byTime = {}, {}
    for _, index in ipairs(dialogueIndices(subtitles, selection)) do
        local line = subtitles[index]
        local key = tostring(line.start_time) .. "\31" .. tostring(line.end_time)
        local group = byTime[key]
        if not group then
            group = { start_time = line.start_time, end_time = line.end_time, first_index = index, indices = {} }
            byTime[key] = group
            groups[#groups + 1] = group
        end
        if index < group.first_index then group.first_index = index end
        group.indices[#group.indices + 1] = index
    end
    if #groups < 2 then return selection, 0 end
    table.sort(groups, function(left, right)
        if left.start_time ~= right.start_time then return left.start_time < right.start_time end
        if left.end_time ~= right.end_time then return left.end_time < right.end_time end
        return left.first_index < right.first_index
    end)
    local removeIn, removeOut = {}, {}
    for index = 1, #groups - 1 do
        if groups[index].end_time == groups[index + 1].start_time then
            removeOut[index] = true
            removeIn[index + 1] = true
        end
    end
    local modified = 0
    for groupIndex, group in ipairs(groups) do
        if removeIn[groupIndex] or removeOut[groupIndex] then
            for _, lineIndex in ipairs(group.indices) do
                local line = subtitles[lineIndex]
                local text, count = adjustFade(line.text, removeIn[groupIndex], removeOut[groupIndex])
                if count > 0 then
                    line.text = text
                    subtitles[lineIndex] = line
                    modified = modified + 1
                end
            end
        end
    end
    return selection, modified
end

local function randomIndex(state, maximum)
    state = (1103515245 * state + 12345) % 2147483648
    return state, math.floor(state % maximum) + 1
end

local function shuffleLineText(subtitles, selection, seed)
    local indices = dialogueIndices(subtitles, selection)
    if #indices < 2 then return selection, 0 end
    local original, shuffled = {}, {}
    for position, index in ipairs(indices) do
        original[position] = tostring(subtitles[index].text or "")
        shuffled[position] = original[position]
    end
    local state = math.floor(tonumber(seed) or (os.time() + #indices * 7919)) % 2147483648
    for index = #shuffled, 2, -1 do
        local swap
        state, swap = randomIndex(state, index)
        shuffled[index], shuffled[swap] = shuffled[swap], shuffled[index]
    end
    local same = true
    for index = 1, #shuffled do if shuffled[index] ~= original[index] then same = false; break end end
    if same then
        local first = table.remove(shuffled, 1)
        shuffled[#shuffled + 1] = first
    end
    local modified = 0
    for position, index in ipairs(indices) do
        if shuffled[position] ~= original[position] then
            local line = subtitles[index]
            line.text = shuffled[position]
            subtitles[index] = line
            modified = modified + 1
        end
    end
    return selection, modified
end

EventOps.dialogueIndices = dialogueIndices
EventOps.leadingPrefix = leadingPrefix
EventOps.cloneWithVisibleText = cloneWithVisibleText
EventOps.hasStutter = hasStutter
EventOps.addEffectMarker = addEffectMarker
EventOps.markStutter = markStutter
EventOps.adjustFade = adjustFade
EventOps.continuousFadeCleanup = continuousFadeCleanup
EventOps.shuffleLineText = shuffleLineText

if depctrl then return depctrl:register(EventOps) end
return EventOps
