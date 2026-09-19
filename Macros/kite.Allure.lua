script_name = "Allure"
script_description = "Reusable ASS styling and pivot-aware sign posing"
script_author = "Kiterow"
script_version = "1.2.4"
script_namespace = "kite.Allure"

local DependencyControl = require("l0.DependencyControl")
local depRec = DependencyControl({
    name = script_name,
    description = script_description,
    author = script_author,
    version = script_version,
    namespace = script_namespace,
    url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
    feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    {
        { "kite.Core", version = "1.1.0",
          url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
        { "kite.LineOps", version = "1.7.0",
          url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
        { "kite.PyBridge", version = "1.7.1",
          url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
        { "l0.dkjson", version = "0.8.0",
          url = "https://github.com/TypesettingTools/DependencyControl",
          feed = "https://raw.githubusercontent.com/TypesettingTools/DependencyControl/master/DependencyControl.json" },
        { "aegisub.re" },
        { "kite.UI", version = "1.5.0",
          url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
        { "kite.AssContext", version = "1.1.1" },
    },
})
local KiteCore, LineOps, PyBridge, json, Re, KiteUI = depRec:requireModules()
local AssContext = require("kite.AssContext")
local AllureCore, Store = {}, {}

local styleFields = {
    "fontname", "fontsize",
    "color1", "color2", "color3", "color4",
    "bold", "italic", "underline", "strikeout",
    "scale_x", "scale_y", "spacing", "angle",
    "borderstyle", "outline", "shadow", "align",
    "margin_l", "margin_r", "margin_t", "margin_v", "encoding", "relative_to",
}

local numericStyleFields = {
    fontsize = true, scale_x = true, scale_y = true, spacing = true, angle = true,
    borderstyle = true, outline = true, shadow = true, align = true,
    margin_l = true, margin_r = true, margin_t = true, margin_v = true, encoding = true,
    relative_to = true,
}

local booleanStyleFields = {
    bold = true, italic = true, underline = true, strikeout = true,
}

local protectedGeometry = {
    pos = true, move = true, org = true,
    clip = true, iclip = true,
    an = true, _persp = true,
}

local numPattern = "([%+%-]?%d*%.?%d+)"
local geometryPointTags = { pos = 1, org = 1, move = 2, _persp = 4 }
local clipTags = { clip = true, iclip = true }
local phraseSeparators = {
    ["."] = true, ["!"] = true, ["?"] = true, [":"] = true, [";"] = true,
    ["："] = true, ["；"] = true,
}
local semanticLevels = {
    { key = "token", field = "tokens", signature = true },
    { key = "punctuation", field = "punctuation", exact = true },
    { key = "word", field = "words" },
    { key = "phrase", field = "phrases" },
}
local patternScopes = {
    { name = "punctuation", field = "punctuation", include_first = true },
    { name = "word", field = "words" },
    { name = "phrase", field = "phrases" },
    { name = "structure", field = "tokens", sparse = true },
}

local trim = LineOps.trim
local parseTagTokens = LineOps.overrideTokens

local function isDialogue(line)
    return type(line) == "table" and (line.class == nil or line.class == "dialogue")
end

local cloneTable = LineOps.deepCopy

local function cloneLine(line)
    if type(line) == "table" and type(line.copy) == "function" then
        return line:copy()
    end
    return cloneTable(line)
end

local formatNumber = KiteCore.formatNumber

local function valueType(value)
    local kind = type(value)
    if kind == "boolean" then return "b", value and "1" or "0" end
    if kind == "number" then return "n", tostring(value) end
    return "s", tostring(value or "")
end

local function regexFind(text, pattern)
    local ok, matches = pcall(Re.find, tostring(text or ""), pattern)
    if ok and type(matches) == "table" then return matches end
    return nil
end

local function regexHas(text, pattern)
    local matches = regexFind(text, pattern)
    return matches ~= nil and #matches > 0
end

local function visibleUnits(text)
    return LineOps.graphemes(text, Re)
end

local function unitCodepoint(unit)
    if unit == "\\N" or unit == "\\n" or unit == "\\h" then return nil end
    return LineOps.firstCodepoint(unit)
end

local function isSpaceUnit(unit)
    unit = tostring(unit or "")
    return unit == "\\h" or unit:match("^%s+$") ~= nil or regexHas(unit, "^\\p{Z}+$")
end

local function isBreakUnit(unit)
    return unit == "\\N" or unit == "\\n"
end

local function isPunctuationUnit(unit)
    if isBreakUnit(unit) or isSpaceUnit(unit) then return false end
    if #unit == 1 and unit:match("^%p$") then return true end
    if regexHas(unit, "^\\p{P}+$") then return true end
    local codepoint = unitCodepoint(unit)
    return codepoint and (
        (codepoint >= 0x2000 and codepoint <= 0x206F)
        or (codepoint >= 0x2E00 and codepoint <= 0x2E7F)
        or (codepoint >= 0x3000 and codepoint <= 0x303F)
        or (codepoint >= 0xFE10 and codepoint <= 0xFE1F)
        or (codepoint >= 0xFE30 and codepoint <= 0xFE4F)
        or (codepoint >= 0xFF01 and codepoint <= 0xFF0F)
        or (codepoint >= 0xFF1A and codepoint <= 0xFF20)
        or (codepoint >= 0xFF3B and codepoint <= 0xFF40)
        or (codepoint >= 0xFF5B and codepoint <= 0xFF65)
    ) or false
end

local function phraseBreakUnit(unit)
    if isBreakUnit(unit) then return true end
    return phraseSeparators[unit]
        or LineOps.isSentenceTerminal(unit)
end

local function analyzeStructure(plain)
    local structure = {
        units = visibleUnits(plain),
        tokens = {},
        words = {},
        phrases = {},
        punctuation = {},
    }
    structure.length = #structure.units

    local position = 1
    while position <= structure.length do
        local unit = structure.units[position]
        local kind = isBreakUnit(unit) and "break"
            or (isSpaceUnit(unit) and "space")
            or (isPunctuationUnit(unit) and "punct")
            or "word"
        local last = position
        if kind == "word" or kind == "space" then
            while last + 1 <= structure.length do
                local nextUnit = structure.units[last + 1]
                local same = kind == "word"
                    and not isBreakUnit(nextUnit)
                    and not isSpaceUnit(nextUnit)
                    and not isPunctuationUnit(nextUnit)
                if kind == "space" then
                    same = isSpaceUnit(nextUnit) and not isBreakUnit(nextUnit)
                end
                if not same then break end
                last = last + 1
            end
        end
        local span = { kind = kind, start = position - 1, finish = last }
        structure.tokens[#structure.tokens + 1] = span
        if kind == "word" then
            structure.words[#structure.words + 1] = {
                kind = kind, start = span.start, finish = span.finish,
            }
        elseif kind == "punct" then
            structure.punctuation[#structure.punctuation + 1] = {
                kind = kind, start = span.start, finish = span.finish,
            }
        end
        position = last + 1
    end

    local phraseStart = 0
    for index, unit in ipairs(structure.units) do
        if phraseBreakUnit(unit) then
            structure.phrases[#structure.phrases + 1] = {
                kind = "phrase", start = phraseStart, finish = index,
            }
            phraseStart = index
        end
    end
    if phraseStart < structure.length or #structure.phrases == 0 then
        structure.phrases[#structure.phrases + 1] = {
            kind = "phrase", start = phraseStart, finish = structure.length,
        }
    end

    local signature = {}
    for _, token in ipairs(structure.tokens) do signature[#signature + 1] = token.kind:sub(1, 1) end
    structure.signature = table.concat(signature)
    return structure
end

local function spanAnchor(spans, offset)
    spans = spans or {}
    if #spans == 0 then return 0, 0 end
    for index, span in ipairs(spans) do
        if offset < span.start then
            if index == 1 then return 1, 0 end
            local previous = spans[index - 1]
            if offset - previous.finish < span.start - offset then return index - 1, 1 end
            return index, 0
        end
        if offset >= span.start and offset <= span.finish then
            local width = span.finish - span.start
            return index, width > 0 and (offset - span.start) / width or 0
        end

    end

    if offset <= spans[1].start then return 1, 0 end
    return #spans, 1
end

local function isSpanStart(spans, offset)
    for _, span in ipairs(spans or {}) do
        if span.start == offset then return true end
    end
    return false
end

local function semanticAnchor(structure, offset)
    offset = math.max(0, math.min(tonumber(offset) or 0, structure.length or 0))
    local anchor = {
        offset = offset,
        ratio = structure.length > 0 and offset / structure.length or 0,
    }
    for _, level in ipairs(semanticLevels) do
        local spans = structure[level.field] or {}
        local index, ratio = spanAnchor(spans, offset)
        anchor[level.key .. "_index"] = index
        anchor[level.key .. "_ratio"] = ratio
        if level.exact then anchor[level.key .. "_exact"] = isSpanStart(spans, offset) end
    end
    return anchor
end

local function inferPatternScope(program, structure)
    local offsets, seen = {}, {}
    for _, block in ipairs(program or {}) do
        local offset = tonumber(block.offset) or 0
        if offset > 0 and offset < structure.length and not seen[offset] then
            offsets[#offsets + 1], seen[offset] = offset, true
        end
    end
    if #offsets == 0 then return "percent" end

    if structure.length > 1 and #offsets >= structure.length - 1 then return "char" end
    for _, branch in ipairs(patternScopes) do
        local spans = structure[branch.field] or {}
        local matches = #spans > 0
        for _, offset in ipairs(offsets) do
            if not isSpanStart(spans, offset) then matches = false break end
        end
        local minimum = branch.include_first and #spans or math.max(1, #spans - 1)
        if matches and (branch.sparse or #offsets >= minimum) then return branch.name end
    end
    return "percent"
end

local function mappedSpanOffset(spans, index, ratio)
    local span = spans[math.max(1, math.min(tonumber(index) or 1, #spans))]
    if not span then return nil end
    ratio = math.max(0, math.min(tonumber(ratio) or 0, 1))
    return math.floor(span.start + (span.finish - span.start) * ratio + 0.5)
end

local function mapSemanticAnchor(anchor, source, target)
    if type(anchor) ~= "table" or anchor.offset == nil then
        anchor = semanticAnchor(source, 0)
    end
    if anchor.offset <= 0 then return 0 end
    if anchor.offset >= (source.length or 0) then return target.length or 0 end

    local mapped
    for _, branch in ipairs(semanticLevels) do
        local sourceSpans = source[branch.field] or {}
        local targetSpans = target[branch.field] or {}
        local compatible = #sourceSpans > 0 and #sourceSpans == #targetSpans
        if branch.signature then compatible = compatible and source.signature == target.signature end
        if branch.exact then compatible = compatible and anchor[branch.key .. "_exact"] end
        if compatible then
            mapped = mappedSpanOffset(targetSpans,
                anchor[branch.key .. "_index"], anchor[branch.key .. "_ratio"])
            if mapped ~= nil then break end
        end
    end
    if mapped == nil and source.length == target.length then mapped = anchor.offset end
    if mapped == nil then mapped = math.floor((anchor.ratio or 0) * target.length + 0.5) end
    return math.max(0, math.min(mapped, target.length))
end

local function splitTagProgram(text)
    local program, plain = {}, {}
    local visibleCount = 0
    for _, section in ipairs(LineOps.scanSections(text)) do
        if section.type == "override" then
            program[#program + 1] = { offset = visibleCount, content = section.text }
        elseif section.type == "text" or section.type == "drawing" then
            plain[#plain + 1] = section.text
            visibleCount = visibleCount + #visibleUnits(section.text)
        end
    end

    local plainText = table.concat(plain)
    local structure = analyzeStructure(plainText)
    for _, block in ipairs(program) do
        block.anchor = semanticAnchor(structure, block.offset)
    end
    return program, visibleCount, plainText, structure
end

local function tagProgramOnly(text)
    local program = {}
    for _, section in ipairs(LineOps.overrideBlocks(text)) do
        program[#program + 1] = { offset = 0, content = section.text }
    end
    return program
end

local function removeProgramNames(program, names)
    local result = {}
    for _, block in ipairs(program or {}) do
        local pieces, cursor = {}, 1
        for _, token in ipairs(parseTagTokens(block.content)) do
            if names[token.name] then
                pieces[#pieces + 1] = block.content:sub(cursor, token.start_position - 1)
                cursor = token.end_position + 1
            end
        end
        pieces[#pieces + 1] = block.content:sub(cursor)
        local content = table.concat(pieces)
        if content:find("\\", 1, true) then
            result[#result + 1] = {
                offset = block.offset,
                content = content,
                anchor = cloneTable(block.anchor),
            }
        end
    end
    return result
end

local function collectProtected(program)
    local result = { present = {}, tokens = {} }
    for _, block in ipairs(program or {}) do
        for _, token in ipairs(parseTagTokens(block.content)) do
            if protectedGeometry[token.name] then
                result.present[token.name] = true
                result.tokens[#result.tokens + 1] = token.raw
            end
        end
    end
    return result
end

local function programHasName(program, name)
    for _, block in ipairs(program or {}) do
        for _, token in ipairs(parseTagTokens(block.content)) do
            if token.name == name then return true end
        end
    end
    return false
end

local function injectProgramPrefix(program, payload)
    if not payload or payload == "" then return program end
    local result = cloneTable(program or {})
    for _, block in ipairs(result) do
        if tonumber(block.offset) == 0 then
            block.content = payload .. block.content
            return result
        end
    end
    table.insert(result, 1, {
        offset = 0,
        content = payload,
        anchor = { offset = 0, ratio = 0 },
    })
    return result
end

local function overlayTargetGeometry(sourceProgram, targetProgram)
    local target = collectProtected(targetProgram)
    if #target.tokens == 0 then return sourceProgram end

    local remove = {}
    for name in pairs(target.present) do remove[name] = true end
    if target.present.pos or target.present.move then
        remove.pos, remove.move = true, true
    end
    local result = removeProgramNames(sourceProgram, remove)
    return injectProgramPrefix(result, table.concat(target.tokens))
end

local function inheritMissingGeometry(sourceProgram, targetProgram, inheritAlignment)
    local target = collectProtected(targetProgram)
    local payload = {}
    if inheritAlignment and target.present.an then
        sourceProgram = removeProgramNames(sourceProgram, { an = true })
    end
    local sourceHasPosition = programHasName(sourceProgram, "pos")
        or programHasName(sourceProgram, "move")

    for _, raw in ipairs(target.tokens) do
        local token = parseTagTokens(raw)[1]
        if token then
            local missing
            if token.name == "pos" or token.name == "move" then
                missing = not sourceHasPosition
            else
                missing = not programHasName(sourceProgram, token.name)
            end
            if missing then payload[#payload + 1] = raw end
        end
    end
    return injectProgramPrefix(sourceProgram, table.concat(payload))
end

local function shiftPair(x, y, dx, dy, scale)
    scale = scale or 1
    return formatNumber((tonumber(x) or 0) + dx * scale),
        formatNumber((tonumber(y) or 0) + dy * scale)
end

local function mapDrawingCoordinates(path, scale, mapper)
    local factor, count = 2 ^ ((tonumber(scale) or 1) - 1), 0
    local mapped = tostring(path or ""):gsub(numPattern .. "%s+" .. numPattern, function(x, y)
        local nextX, nextY = mapper((tonumber(x) or 0) / factor, (tonumber(y) or 0) / factor)
        count = count + 1
        return formatNumber(nextX * factor) .. " " .. formatNumber(nextY * factor)
    end)
    return mapped, count
end

local function mapClipCall(call, mapper)
    local arguments = LineOps.splitArguments(call.value)
    if #arguments == 4 then
        local values = {}
        for index = 1, 4 do values[index] = tonumber(arguments[index]) end
        if values[1] and values[2] and values[3] and values[4] then
            local x1, y1 = mapper(values[1], values[2])
            local x2, y2 = mapper(values[3], values[4])
            return "\\" .. call.raw_name .. "(" .. table.concat({
                formatNumber(x1), formatNumber(y1), formatNumber(x2), formatNumber(y2),
            }, ",") .. ")"
        end
    end

    local scale, path
    if #arguments > 1 and tonumber(arguments[1]) then
        scale, path = arguments[1], table.concat(arguments, ",", 2)
    else
        path = table.concat(arguments, ",")
    end
    if not path:match("^%s*[mnlbspcMNLBSPC]%s") then return nil end
    local mapped, count = mapDrawingCoordinates(path, scale, mapper)
    if count == 0 then return nil end
    return "\\" .. call.raw_name .. "(" .. (scale and scale .. "," or "") .. mapped .. ")"
end

local function mapGeometryCalls(content, mapper, pointTags)
    local names = cloneTable(clipTags)
    for name in pairs(pointTags or {}) do names[name] = true end
    local wrapped = "{" .. tostring(content or "") .. "}"
    wrapped = LineOps.mapTagCalls(wrapped, names, function(call)
        if clipTags[call.name] then return mapClipCall(call, mapper) end
        local pairCount = pointTags and pointTags[call.name]
        if not pairCount then return nil end
        local arguments = LineOps.splitArguments(call.value)
        if #arguments < pairCount * 2 then return nil end
        for pair = 1, pairCount do
            local index = pair * 2 - 1
            local x, y = tonumber(arguments[index]), tonumber(arguments[index + 1])
            if not x or not y then return nil end
            x, y = mapper(x, y)
            arguments[index], arguments[index + 1] = formatNumber(x), formatNumber(y)
        end
        return "\\" .. call.raw_name .. "(" .. table.concat(arguments, ",") .. ")"
    end, { top_level_only = false })
    return wrapped:sub(2, -2)
end

local function translateGeometry(content, dx, dy)
    if dx == 0 and dy == 0 then return tostring(content or "") end
    return mapGeometryCalls(content, function(x, y) return x + dx, y + dy end, geometryPointTags)
end

local function translateProgram(program, dx, dy)
    local result = {}
    for _, block in ipairs(program or {}) do
        result[#result + 1] = {
            offset = block.offset,
            content = translateGeometry(block.content, dx, dy),
            anchor = cloneTable(block.anchor),
        }
    end
    return result
end

local function translateGeometryText(text, dx, dy)
    return (tostring(text or ""):gsub("{([^}]*)}", function(content)
        if not content:find("\\", 1, true) then return "{" .. content .. "}" end
        return "{" .. translateGeometry(content, dx, dy) .. "}"
    end))
end

local function firstProgramPoint(program)
    local blocks = {}
    for _, entry in ipairs(program or {}) do blocks[#blocks + 1] = "{" .. entry.content .. "}" end
    return AssContext.explicitPosition(table.concat(blocks))
end

local function firstProgramTagValue(program, name)
    for _, block in ipairs(program or {}) do
        for _, token in ipairs(parseTagTokens(block.content)) do
            if token.name == name then return trim(token.value) end
        end
    end
    return nil
end

local function collectScriptInfo(subs)
    local x, y = LineOps.scriptResolution(subs)
    if (not x or not y) and aegisub and type(aegisub.video_size) == "function" then
        local ok, videoX, videoY = pcall(aegisub.video_size)
        if ok then x, y = x or tonumber(videoX), y or tonumber(videoY) end
    end
    return { play_res_x = x or 384, play_res_y = y or 288 }
end

local function copyStyle(style)
    local result = {}
    for key, value in pairs(style or {}) do
        if type(value) ~= "function" then result[key] = value end
    end
    return result
end

local function applyStyleBlock(state, content, baseStyle, styles)
    for _, token in ipairs(parseTagTokens(content)) do
        local name = tostring(token.name or ""):lower()
        local value = trim(token.value)
        if name == "r" then
            state = copyStyle((value ~= "" and styles[value]) or baseStyle)
        elseif name == "fn" then
            state.fontname = value ~= "" and value or baseStyle.fontname
        elseif name == "fs" then
            state.fontsize = tonumber(value) or state.fontsize
        elseif name == "fscx" then
            state.scale_x = tonumber(value) or state.scale_x
        elseif name == "fscy" then
            state.scale_y = tonumber(value) or state.scale_y
        elseif name == "fsp" then
            state.spacing = tonumber(value) or state.spacing
        elseif name == "b" then
            state.bold = (tonumber(value) or 0) ~= 0
        elseif name == "i" then
            state.italic = (tonumber(value) or 0) ~= 0
        elseif name == "u" then
            state.underline = (tonumber(value) or 0) ~= 0
        elseif name == "s" then
            state.strikeout = (tonumber(value) or 0) ~= 0
        elseif name == "an" then
            state.align = tonumber(value) or state.align
        end
    end
    return state
end

local function textExtent(style, text)
    text = tostring(text or ""):gsub("\\h", " ")
    if aegisub and aegisub.text_extents then
        local ok, width, height, descent, extlead = pcall(aegisub.text_extents, style, text)
        if ok and tonumber(width) and tonumber(height) then
            return math.max(0, tonumber(width) or 0),
                math.max(1, (tonumber(height) or 0) + (tonumber(descent) or 0)
                    + (tonumber(extlead) or 0))
        end
    end
    local count = #visibleUnits(text)
    local size = tonumber(style and style.fontsize) or 40
    local scaleX = (tonumber(style and style.scale_x) or 100) / 100
    local scaleY = (tonumber(style and style.scale_y) or 100) / 100
    local spacing = tonumber(style and style.spacing) or 0
    return math.max(1, count * size * 0.55 * scaleX + math.max(0, count - 1) * spacing),
        math.max(1, size * scaleY)
end

local function measureProgramText(plain, program, baseStyle, styles)
    local units = visibleUnits(plain)
    local atOffset = {}
    for _, block in ipairs(program or {}) do
        local offset = math.max(0, math.min(tonumber(block.offset) or 0, #units))
        atOffset[offset] = atOffset[offset] or {}
        atOffset[offset][#atOffset[offset] + 1] = block.content
    end

    local state = copyStyle(baseStyle)
    local width, lineWidth, height, lineHeight = 0, 0, 0, 0
    local segment = {}
    local function flushSegment()
        if #segment == 0 then return end
        local segmentWidth, segmentHeight = textExtent(state, table.concat(segment))
        lineWidth = lineWidth + segmentWidth
        lineHeight = math.max(lineHeight, segmentHeight)
        segment = {}
    end
    local function lineBreak()
        flushSegment()
        width = math.max(width, lineWidth)
        height = height + math.max(1, lineHeight)
        lineWidth, lineHeight = 0, 0
    end

    for offset = 0, #units do
        if atOffset[offset] then
            flushSegment()
            for _, content in ipairs(atOffset[offset]) do
                state = applyStyleBlock(state, content, baseStyle, styles)
            end
        end
        if offset < #units then
            local unit = units[offset + 1]
            if isBreakUnit(unit) then lineBreak() else segment[#segment + 1] = unit end
        end
    end
    flushSegment()
    width = math.max(width, lineWidth)
    height = height + math.max(1, lineHeight)
    return math.max(1, width), math.max(1, height), tonumber(state.align) or tonumber(baseStyle.align) or 2
end

local function defaultLineAnchor(line, style, info, alignment)
    local resolved = copyStyle(style)
    resolved.align = alignment or resolved.align
    local x, y, err = AssContext.defaultPosition(line, {style=resolved, meta=info})
    assert(x and y, err)
    return x, y
end

local function lineAnchorPosition(line, program, style, info, alignment)
    local x, y = firstProgramPoint(program)
    if x then return x, y end
    return defaultLineAnchor(line, style, info, alignment)
end

local function pointToBox(x, y, alignment, width, height)
    alignment = tonumber(alignment) or 2
    local horizontal = alignment % 3
    local left = horizontal == 1 and x or (horizontal == 2 and x - width / 2 or x - width)
    local vertical = math.ceil(alignment / 3)
    local top = vertical == 3 and y or (vertical == 2 and y - height / 2 or y - height)
    return {
        left = left, top = top, right = left + width, bottom = top + height,
        width = width, height = height,
    }
end

local function textBoxForLine(line, plain, program, style, styles, info)
    style = style or {}
    local width, height, alignment = measureProgramText(plain, program, style, styles)
    local explicitAlignment = tonumber(firstProgramTagValue(program, "an"))
    alignment = explicitAlignment or tonumber(style.align) or alignment or 2
    local x, y = lineAnchorPosition(line, program, style, info, alignment)
    local box = pointToBox(x, y, alignment, width, height)
    box.anchor_x, box.anchor_y, box.alignment = x, y, alignment
    return box
end

local function clipBoxFromProgram(program)
    for _, block in ipairs(program or {}) do
        for _, token in ipairs(parseTagTokens(block.content)) do
            if token.name == "clip" or token.name == "iclip" then
                local args = tostring(token.value or ""):match("^%((.*)%)$")
                if args and not args:lower():find("[mnlbspc]") then
                    local values = {}
                    for number in args:gmatch("[%+%-]?%d*%.?%d+") do values[#values + 1] = tonumber(number) end
                    if #values == 4 then
                        return {
                            left = math.min(values[1], values[3]),
                            top = math.min(values[2], values[4]),
                            right = math.max(values[1], values[3]),
                            bottom = math.max(values[2], values[4]),
                            width = math.abs(values[3] - values[1]),
                            height = math.abs(values[4] - values[2]),
                        }, "rect"
                    end
                elseif args then
                    local scaleText, path = args:match("^%s*(%d+)%s*,%s*(.*)$")
                    if not path then path = args end
                    local factor = 2 ^ ((tonumber(scaleText) or 1) - 1)
                    local points = {}
                    tostring(path or ""):gsub(numPattern .. "%s+" .. numPattern, function(x, y)
                        points[#points + 1] = {
                            x = (tonumber(x) or 0) / factor,
                            y = (tonumber(y) or 0) / factor,
                        }
                    end)
                    if #points > 0 then
                        local box = {
                            left = points[1].x, right = points[1].x,
                            top = points[1].y, bottom = points[1].y,
                        }
                        for _, point in ipairs(points) do
                            box.left, box.right = math.min(box.left, point.x), math.max(box.right, point.x)
                            box.top, box.bottom = math.min(box.top, point.y), math.max(box.bottom, point.y)
                        end
                        box.width, box.height = box.right - box.left, box.bottom - box.top
                        return box, "vector"
                    end
                end
            end
        end
    end
    return nil
end

local function unionBox(boxes)
    local result
    for _, box in ipairs(boxes or {}) do
        if box then
            if not result then
                result = cloneTable(box)
            else
                result.left = math.min(result.left, box.left)

                result.top = math.min(result.top, box.top)
                result.right = math.max(result.right, box.right)
                result.bottom = math.max(result.bottom, box.bottom)

                result.width = result.right - result.left
                result.height = result.bottom - result.top
            end
        end
    end
    return result
end

local function boxesOverlap(left, right)
    if not left or not right then return false end
    local width = math.max(0, math.min(left.right, right.right) - math.max(left.left, right.left))
    local height = math.max(0, math.min(left.bottom, right.bottom) - math.max(left.top, right.top))
    return width > 0 and height > 0
end

local function detectClipFamilies(preset)
    local groups = {}
    for _, line in ipairs(preset.lines or {}) do
        line.clip_rect, line.clip_kind = clipBoxFromProgram(line.program)
        if line.slot > 0 and line.clip_rect and line.clip_kind == "rect" then
            groups[line.slot] = groups[line.slot] or {}
            groups[line.slot][#groups[line.slot] + 1] = line
        elseif line.slot > 0 and line.clip_rect and line.source_box
            and boxesOverlap(line.clip_rect, line.source_box)
            and line.clip_rect.width <= line.source_box.width * 2.5
            and line.clip_rect.height <= line.source_box.height * 2.5 then
            line.clip_relative = true
            line.clip_source_box = cloneTable(line.source_box)
            line.clip_family = "vector-box"
        end
    end

    for _, lines in pairs(groups) do
        local rects = {}
        for _, line in ipairs(lines) do rects[#rects + 1] = line.clip_rect end
        local union = unionBox(rects)
        local horizontal, vertical = 0, 0
        if union and #lines >= 3 then
            for _, line in ipairs(lines) do
                local rect = line.clip_rect
                if rect.width >= union.width * 0.75 and rect.height <= union.height * 0.5 then
                    horizontal = horizontal + 1
                end
                if rect.height >= union.height * 0.75 and rect.width <= union.width * 0.5 then
                    vertical = vertical + 1
                end
            end
        end
        local family = #lines >= 3 and math.max(horizontal, vertical) >= math.ceil(#lines * 0.75)
        for _, line in ipairs(lines) do
            if family then
                line.clip_relative = true
                line.clip_source_box = cloneTable(union)
                line.clip_family = horizontal >= vertical and "horizontal" or "vertical"
            elseif line.source_box and boxesOverlap(line.clip_rect, line.source_box)
                and line.clip_rect.width <= line.source_box.width * 2.5
                and line.clip_rect.height <= line.source_box.height * 2.5 then
                line.clip_relative = true
                line.clip_source_box = cloneTable(line.source_box)
                line.clip_family = "box"
            end
        end
    end
end

local function mapBoxCoordinate(value, sourceMin, sourceSize, targetMin, targetSize)
    if math.abs(sourceSize or 0) < 0.000001 then return value end
    return targetMin + (value - sourceMin) / sourceSize * targetSize
end

local function affineRemapClips(content, source, target)
    if not source or not target then return content end
    return mapGeometryCalls(content, function(x, y)
        return mapBoxCoordinate(x, source.left, source.width, target.left, target.width),
            mapBoxCoordinate(y, source.top, source.height, target.top, target.height)
    end)
end

local function remapTranslatedProgramClips(program, clipSourceBox, targetBox, dx, dy)
    if not clipSourceBox or not targetBox then return program end
    local shiftedSource = cloneTable(clipSourceBox)
    shiftedSource.left, shiftedSource.right =
        shiftedSource.left + dx, shiftedSource.right + dx
    shiftedSource.top, shiftedSource.bottom =
        shiftedSource.top + dy, shiftedSource.bottom + dy
    local result = {}
    for _, block in ipairs(program or {}) do
        result[#result + 1] = {
            offset = block.offset,
            anchor = cloneTable(block.anchor),
            content = affineRemapClips(block.content, shiftedSource, targetBox),
        }
    end
    return result
end

local function rewriteResetContent(content, resolvedStyles)
    local pieces, cursor = {}, 1
    for _, token in ipairs(parseTagTokens(content)) do
        if token.name == "r" then
            local sourceName = trim(token.value)
            local targetName = resolvedStyles[sourceName]
            if sourceName ~= "" and targetName and targetName ~= sourceName then
                pieces[#pieces + 1] = content:sub(cursor, token.start_position - 1)
                pieces[#pieces + 1] = "\\r" .. targetName
                cursor = token.end_position + 1
            end
        end
    end
    pieces[#pieces + 1] = content:sub(cursor)
    return table.concat(pieces)
end

local function rewriteStyleResets(program, resolvedStyles)
    local result = {}
    for _, block in ipairs(program or {}) do
        result[#result + 1] = {
            offset = block.offset,
            content = rewriteResetContent(block.content, resolvedStyles),
            anchor = cloneTable(block.anchor),
        }
    end
    return result
end

local function rewriteStyleResetsText(text, resolvedStyles)
    return (tostring(text or ""):gsub("{([^}]*)}", function(content)
        if not content:find("\\", 1, true) then return "{" .. content .. "}" end
        return "{" .. rewriteResetContent(content, resolvedStyles) .. "}"
    end))
end

local function patternBoundaries(structure, scope)
    local boundaries = {}
    if scope == "char" then
        for offset = 1, math.max(0, structure.length - 1) do boundaries[#boundaries + 1] = offset end
        return boundaries
    end
    for _, branch in ipairs(patternScopes) do
        if branch.name == scope and not branch.sparse then
            local spans = structure[branch.field] or {}
            for index = branch.include_first and 1 or 2, #spans do
                boundaries[#boundaries + 1] = spans[index].start
            end
            break
        end
    end
    return boundaries
end

local function mappedProgram(program, source, target, scope)
    local result = {}
    local sourceBoundaries = patternBoundaries(source, scope)
    local targetBoundaries = patternBoundaries(target, scope)
    local inline, sourceBoundarySet = {}, {}
    for _, offset in ipairs(sourceBoundaries) do sourceBoundarySet[offset] = true end
    if #sourceBoundaries > 0 and #targetBoundaries > 0
        and (source.length ~= target.length or #sourceBoundaries ~= #targetBoundaries) then
        for _, block in ipairs(program or {}) do
            if sourceBoundarySet[tonumber(block.offset) or 0] then inline[#inline + 1] = block end
        end
    end

    if #inline > 0 then
        for _, block in ipairs(program or {}) do
            if not sourceBoundarySet[tonumber(block.offset) or 0] then
                local copy = cloneTable(block)
                copy.offset = mapSemanticAnchor(block.anchor, source, target)
                result[#result + 1] = copy
            end
        end
        for index, offset in ipairs(targetBoundaries) do
            local ratio = #targetBoundaries > 1 and (index - 1) / (#targetBoundaries - 1) or 0
            local sourceIndex = math.floor(ratio * math.max(0, #inline - 1) + 1.5)
            sourceIndex = math.max(1, math.min(sourceIndex, #inline))
            result[#result + 1] = {
                offset = offset,
                content = inline[sourceIndex].content,
                anchor = semanticAnchor(target, offset),
            }
        end
    else
        for _, block in ipairs(program or {}) do
            local copy = cloneTable(block)
            copy.offset = mapSemanticAnchor(block.anchor, source, target)
            result[#result + 1] = copy
        end
    end

    for index, block in ipairs(result) do block._makeup_order = index end
    table.sort(result, function(left, right)
        local leftOffset, rightOffset = tonumber(left.offset) or 0, tonumber(right.offset) or 0
        if leftOffset == rightOffset then
            return (left._makeup_order or 0) < (right._makeup_order or 0)
        end
        return leftOffset < rightOffset
    end)
    for _, block in ipairs(result) do block._makeup_order = nil end
    return result
end

local function renderProgram(program, sourceStructure, targetPlain, scope)
    local target = analyzeStructure(targetPlain)
    local source = type(sourceStructure) == "table" and sourceStructure or {
        length = tonumber(sourceStructure) or 0,
        tokens = {}, words = {}, phrases = {}, punctuation = {}, signature = "",
    }
    local insertions = {}

    for _, block in ipairs(mappedProgram(program, source, target, scope or "percent")) do
        if block.content and block.content:find("\\", 1, true) then
            local offset = math.max(0, math.min(tonumber(block.offset) or 0, target.length))
            insertions[offset] = insertions[offset] or {}
            insertions[offset][#insertions[offset] + 1] = "{" .. block.content .. "}"
        end
    end

    local result = {}
    for position = 0, target.length do
        if insertions[position] then
            for _, block in ipairs(insertions[position]) do result[#result + 1] = block end
        end
        if position < target.length then result[#result + 1] = target.units[position + 1] end
    end
    return table.concat(result)
end

local function isDrawingProgram(program)
    for _, block in ipairs(program or {}) do
        for _, token in ipairs(parseTagTokens(block.content)) do
            if token.name == "p" and (tonumber(token.value) or 0) > 0 then return true end
        end
    end
    return false
end

local function visibleKey(plain)
    return trim(tostring(plain or ""):gsub("\\[Nnh]", " "):gsub("%s+", " "))
end

local function collectStyles(subs)
    local styles, indices = {}, {}
    for index = 1, #subs do
        local line = subs[index]
        if type(line) == "table" and line.class == "style" then
            styles[line.name] = line
            indices[line.name] = index
        end
    end
    return styles, indices
end

local function simpleHash(value)
    local hash = 5381
    value = tostring(value or "")
    for position = 1, #value do
        hash = (hash * 33 + value:byte(position)) % 2147483647
    end
    return string.format("%08x", hash)
end

local function styleFingerprint(snapshot)
    local material = {}
    for _, field in ipairs(styleFields) do
        local value = snapshot.fields and snapshot.fields[field]
        if value ~= nil then
            local kind, raw = valueType(value)
            material[#material + 1] = field .. "=" .. kind .. ":" .. raw
        end
    end
    return simpleHash(table.concat(material, "\31"))
end

local function snapshotStyle(style)
    local snapshot = { name = tostring(style and style.name or ""), fields = {} }
    for _, field in ipairs(styleFields) do
        if style and style[field] ~= nil then snapshot.fields[field] = style[field] end

    end
    snapshot.fingerprint = styleFingerprint(snapshot)
    return snapshot
end

local function rememberStyle(preset, styles, name)
    name = trim(name)
    if name == "" or preset.styles_by_name[name] then return end
    local snapshot = snapshotStyle(styles[name])
    snapshot.name = name
    preset.styles[#preset.styles + 1] = snapshot
    preset.styles_by_name[name] = snapshot
end

local function captureSafeExtra(line)
    local extra = {}
    if type(line.extra) == "table" then
        local value = line.extra["_aegi_perspective_ambient_plane"]
        if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
            extra["_aegi_perspective_ambient_plane"] = value
        end
    end
    return extra
end

local function capturePreset(subs, selection, active, name, kind)
    kind = kind == "exact" and "exact" or "adaptive"
    local indices = LineOps.normalizeIndices(subs, selection, isDialogue)
    if #indices == 0 then return nil, "Select at least one dialogue line." end

    local anchor = 1
    for ordinal, index in ipairs(indices) do
        if index == active then anchor = ordinal break end
    end

    local styles = collectStyles(subs)
    local scriptInfo = collectScriptInfo(subs)
    local preset = {
        name = trim(name),
        kind = kind,
        anchor = anchor,
        slot_count = 0,
        styles = {},
        styles_by_name = {},
        lines = {},
    }
    local slotByText = {}
    local anchorLine = subs[indices[anchor]]
    local anchorLayer = tonumber(anchorLine.layer) or 0
    local anchorStart = tonumber(anchorLine.start_time) or 0
    local anchorEnd = tonumber(anchorLine.end_time) or 0

    for ordinal, index in ipairs(indices) do
        local line = subs[index]
        local program, sourceLength, plain, structure
        if kind == "exact" then
            program = tagProgramOnly(line.text)
            if not isDrawingProgram(program) then
                program, sourceLength, plain, structure = splitTagProgram(line.text)
            else
                sourceLength, plain = 0, ""
                structure = {
                    length = 0, tokens = {}, words = {}, phrases = {}, punctuation = {}, signature = "",
                }
            end
        else
            program, sourceLength, plain, structure = splitTagProgram(line.text)
        end
        local drawing = isDrawingProgram(program)
        local slot = 0
        if not drawing then
            local key = visibleKey(plain)
            if key ~= "" then
                if not slotByText[key] then
                    preset.slot_count = preset.slot_count + 1
                    slotByText[key] = preset.slot_count
                end
                slot = slotByText[key]
            end
        end

        local styleName = tostring(line.style or "Default")
        rememberStyle(preset, styles, styleName)
        for _, block in ipairs(program) do
            for _, token in ipairs(parseTagTokens(block.content)) do
                if token.name == "r" and trim(token.value) ~= "" then
                    rememberStyle(preset, styles, token.value)
                end
            end
        end

        local sourceBox
        if not drawing then
            sourceBox = textBoxForLine(
                line, plain, program, styles[styleName] or {}, styles, scriptInfo)
        end
        local alignment = tonumber(firstProgramTagValue(program, "an"))
            or tonumber((styles[styleName] or {}).align) or 2
        local sourceAnchorX, sourceAnchorY = lineAnchorPosition(
            line, program, styles[styleName] or {}, scriptInfo, alignment)
        local styleSnapshot = preset.styles_by_name[styleName]
        local captured = {
            ordinal = ordinal,
            style = styleName,
            layer = tonumber(line.layer) or 0,
            layer_delta = (tonumber(line.layer) or 0) - anchorLayer,
            start_delta = (tonumber(line.start_time) or 0) - anchorStart,
            end_delta = (tonumber(line.end_time) or 0) - anchorEnd,
            duration = math.max(0, (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0)),
            margin_l = tonumber(line.margin_l) or 0,
            margin_r = tonumber(line.margin_r) or 0,
            margin_t = tonumber(line.margin_t) or 0,
            source_box = sourceBox,
            source_anchor = { x = sourceAnchorX, y = sourceAnchorY, alignment = alignment },
            drawing = drawing,
        }
        if kind == "exact" then
            captured.exact_text = tostring(line.text or "")
            captured.event = {
                actor = tostring(line.actor or ""),
                effect = tostring(line.effect or ""),
                comment = line.comment and true or false,
                extra = cloneTable(line.extra or {}),
            }
        else
            captured.slot = slot
            captured.source_length = sourceLength
            captured.source_structure = structure
            captured.pattern_scope = inferPatternScope(program, structure)
            captured.source_style_fingerprint = styleSnapshot and styleSnapshot.fingerprint or ""
            captured.drawing_text = drawing and plain or ""
            captured.program = program
            captured.extra = captureSafeExtra(line)
        end
        preset.lines[#preset.lines + 1] = captured
    end

    if kind == "adaptive" and preset.slot_count == 0 then
        return nil, "The selection has no reusable text layer. Use Save group for drawing-only signs."
    end
    if kind == "adaptive" then detectClipFamilies(preset) end
    return preset
end

local function hydratePreset(preset)
    if type(preset) ~= "table" or type(preset.lines) ~= "table" or #preset.lines == 0 then
        return nil, "The preset has no lines."
    end
    preset.kind = preset.kind == "exact" and "exact" or preset.kind == "adaptive" and "adaptive" or nil
    if not preset.kind then return nil, "Unknown preset type." end
    preset.name = trim(preset.name)
    if preset.name == "" then return nil, "The preset has no name." end
    preset.styles = type(preset.styles) == "table" and preset.styles or {}
    preset.styles_by_name = {}
    for _, style in ipairs(preset.styles) do
        style.fields = type(style.fields) == "table" and style.fields or {}
        style.fingerprint = trim(style.fingerprint)
        if style.fingerprint == "" then style.fingerprint = styleFingerprint(style) end
        preset.styles_by_name[tostring(style.name or "")] = style
    end
    preset.anchor = math.max(1, math.min(tonumber(preset.anchor) or 1, #preset.lines))
    preset.slot_count = math.max(0, tonumber(preset.slot_count) or 0)
    for ordinal, line in ipairs(preset.lines) do
        if type(line) ~= "table" then return nil, "The preset contains an invalid line." end
        line.ordinal = ordinal
        line.program = type(line.program) == "table" and line.program or {}
        line.source_structure = type(line.source_structure) == "table" and line.source_structure
            or {
                length = tonumber(line.source_length) or 0,
                tokens = {}, words = {}, phrases = {}, punctuation = {},
            }
        line.source_structure.punctuation = line.source_structure.punctuation or {}
        line.extra = type(line.extra) == "table" and line.extra or {}
        if preset.kind == "exact" and type(line.exact_text) ~= "string" then
            return nil, "An exact group is missing line text."
        end
    end
    return preset
end

local function styleValuesEqual(field, left, right)
    if booleanStyleFields[field] then
        local function booleanValue(value)
            if type(value) == "boolean" then return value end
            local number = tonumber(value)
            if number ~= nil then return number ~= 0 end
            return tostring(value or ""):lower() == "true"
        end
        return booleanValue(left) == booleanValue(right)
    end
    if numericStyleFields[field] then
        local leftNumber, rightNumber = tonumber(left), tonumber(right)
        return leftNumber and rightNumber and math.abs(leftNumber - rightNumber) < 0.000001
    end
    return tostring(left or "") == tostring(right or "")
end

local function stylesEqual(existing, snapshot)
    if not existing or not snapshot then return false end
    for field, value in pairs(snapshot.fields or {}) do
        if not styleValuesEqual(field, existing[field], value) then return false end
    end
    return next(snapshot.fields or {}) ~= nil
end

local function styleFromSnapshot(snapshot, name)
    local style = { class = "style", name = name }
    for field, value in pairs(snapshot.fields or {}) do style[field] = value end
    return style
end

local function ensurePresetStyles(subs, preset)
    local styles = collectStyles(subs)
    local resolved, additions = {}, {}
    local reserved = {}
    for name in pairs(styles) do reserved[name] = true end

    for _, snapshot in ipairs(preset.styles or {}) do
        local original = snapshot.name
        local fingerprint = snapshot.fingerprint ~= "" and snapshot.fingerprint
            or styleFingerprint(snapshot)
        local matchingName
        for existingName, existing in pairs(styles) do
            if stylesEqual(existing, snapshot) then
                matchingName = existingName
                if existingName == original then break end
            end
        end
        if stylesEqual(styles[original], snapshot) then
            resolved[original] = original
        elseif matchingName then
            resolved[original] = matchingName
        elseif next(snapshot.fields or {}) == nil then
            resolved[original] = styles[original] and original or nil
        elseif not styles[original] then
            resolved[original] = original
            additions[#additions + 1] = styleFromSnapshot(snapshot, original)
            styles[original] = additions[#additions]
            reserved[original] = true
        else
            local stem = original .. " [Makeup " .. fingerprint .. "]"
            local candidate, number = stem, 2
            while reserved[candidate] and not stylesEqual(styles[candidate], snapshot) do
                candidate = stem .. " " .. tostring(number)
                number = number + 1
            end
            resolved[original] = candidate
            if not reserved[candidate] then
                additions[#additions + 1] = styleFromSnapshot(snapshot, candidate)
                styles[candidate] = additions[#additions]
                reserved[candidate] = true
            end
        end
    end

    if #additions == 0 then return resolved, nil, 0 end

    local insertPosition, lastNonDialogue = 1, 0
    for index = 1, #subs do
        local class = subs[index] and subs[index].class
        if class == "style" then
            insertPosition = index + 1
        elseif class ~= "dialogue" then
            lastNonDialogue = index
        end
    end
    if insertPosition == 1 and lastNonDialogue > 0 then
        insertPosition = lastNonDialogue + 1
    end
    for offset, style in ipairs(additions) do
        subs.insert(insertPosition + offset - 1, style)
    end
    return resolved, insertPosition, #additions
end

local function shiftPlaneExtra(value, dx, dy)
    local count = 0
    local shifted = tostring(value or ""):gsub(numPattern .. "%s*;%s*" .. numPattern, function(x, y)
        count = count + 1
        local nextX, nextY = shiftPair(x, y, dx, dy)
        return nextX .. ";" .. nextY
    end)
    if count >= 4 then return shifted end
    return value
end

local function linePlain(line)
    local program, length, plain = splitTagProgram(line and line.text or "")
    return program, length, plain
end

local function effectiveLineBox(line, context)
    local program, _, plain = linePlain(line)
    local style = context.styles[tostring(line and line.style or "")] or {}
    return textBoxForLine(line, plain, program, style, context.styles, context.info)
end

local function slotAnchorOrdinals(preset)
    local result = {}
    local anchorLine = preset.lines[preset.anchor]
    if anchorLine and anchorLine.slot and anchorLine.slot > 0 then
        result[anchorLine.slot] = preset.anchor
    end
    for ordinal, line in ipairs(preset.lines) do
        if line.slot and line.slot > 0 and not result[line.slot] then result[line.slot] = ordinal end
    end
    return result
end

local function sourceReferenceLine(preset, slot, slotAnchors)
    local ordinal = slot and slot > 0 and slotAnchors[slot] or preset.anchor
    return preset.lines[ordinal] or preset.lines[preset.anchor] or preset.lines[1]
end

local function sourceGeometryReference(preset, slot, slotAnchors)
    local preferred = sourceReferenceLine(preset, slot, slotAnchors)
    local x = preferred and firstProgramPoint(preferred.program)

    if x then return preferred end
    if slot and slot > 0 then
        for _, line in ipairs(preset.lines) do
            if line.slot == slot and firstProgramPoint(line.program) then return line end
        end
    end
    for _, line in ipairs(preset.lines) do
        if firstProgramPoint(line.program) then return line end
    end
    return preferred
end

local function relativeMargin(templateValue, sourceReferenceValue, targetValue)
    return (tonumber(targetValue) or 0)
        + (tonumber(templateValue) or 0)
        - (tonumber(sourceReferenceValue) or 0)
end

local function applyTemplateToLine(template, target, options)
    local out = cloneLine(target)
    local _, _, targetPlain = linePlain(target)
    local program = translateProgram(template.program, options.dx or 0, options.dy or 0)
    program = rewriteStyleResets(program, options.resolved_styles or {})

    local targetProgram = linePlain(target)
    if template.clip_relative then
        targetProgram = removeProgramNames(targetProgram, { clip = true, iclip = true })
    end
    if options.overlay_geometry then
        program = overlayTargetGeometry(program, targetProgram)
    else
        program = inheritMissingGeometry(
            program,
            options.inherit_geometry_program or targetProgram,
            options.inherit_alignment)
    end

    out.style = options.resolved_styles[template.style] or template.style or target.style
    if options.generated then
        out.layer = options.layer
        out.start_time = options.start_time
        out.end_time = options.end_time
        assert(out.end_time > out.start_time, "The target duration is too short for the saved timing offsets.")
        out.margin_l = options.margin_l
        out.margin_r = options.margin_r
        out.margin_t = options.margin_t
    end

    local plain = template.drawing and template.drawing_text or targetPlain
    if template.clip_relative and options.context then
        local targetStyle = options.context.styles[tostring(out.style or "")] or {}
        local targetBox = textBoxForLine(
            out, plain, program, targetStyle, options.context.styles, options.context.info)
        program = remapTranslatedProgramClips(
            program, template.clip_source_box or template.source_box, targetBox,
            options.dx or 0, options.dy or 0)
    end
    out.text = renderProgram(
        program, template.source_structure or template.source_length, plain, template.pattern_scope)

    out.extra = cloneTable(target.extra or {})
    local targetPlane = out.extra["_aegi_perspective_ambient_plane"]
    local sourcePlane = template.extra and template.extra["_aegi_perspective_ambient_plane"]
    if not (options.overlay_geometry and targetPlane ~= nil) and sourcePlane ~= nil then
        out.extra["_aegi_perspective_ambient_plane"] =
            shiftPlaneExtra(sourcePlane, options.dx or 0, options.dy or 0)
    end
    return out
end

local function templateAnchor(template)
    if template and template.source_box then
        return template.source_box.anchor_x, template.source_box.anchor_y
    end
    if template and template.source_anchor then
        return tonumber(template.source_anchor.x), tonumber(template.source_anchor.y)
    end
    return template and firstProgramPoint(template.program)
end

local function nonnegativeLayerShift(templates, targetLayer)
    local base = tonumber(targetLayer) or 0
    local minimum = base
    for _, template in ipairs(templates or {}) do
        minimum = math.min(minimum, base + (tonumber(template.layer_delta) or 0))
    end
    return minimum < 0 and -minimum or 0
end

local function buildGeneratedOutputs(preset, targets, resolvedStyles, context)
    local outputs = {}
    local slotAnchors = slotAnchorOrdinals(preset)
    local presetAnchor = preset.lines[preset.anchor] or preset.lines[1]
    local overallTarget = targets[presetAnchor.slot] or targets[1]
    local layerBase = tonumber(overallTarget.layer) or 0
    local layerShift = nonnegativeLayerShift(preset.lines, layerBase)
    local overallTargetProgram = linePlain(overallTarget)
    local overallGeometryReference =
        sourceGeometryReference(preset, presetAnchor.slot, slotAnchors)
    local overallSourceX, overallSourceY = templateAnchor(overallGeometryReference)
    local overallTargetBox = effectiveLineBox(overallTarget, context)
    local overallTargetX, overallTargetY =
        overallTargetBox.anchor_x, overallTargetBox.anchor_y
    local overallDx, overallDy = 0, 0
    if overallSourceX and overallTargetX then
        overallDx, overallDy = overallTargetX - overallSourceX, overallTargetY - overallSourceY
    end

    for ordinal, template in ipairs(preset.lines) do
        local target = targets[template.slot] or overallTarget
        local targetProgram = linePlain(target)
        local sourceReference = sourceReferenceLine(preset, template.slot, slotAnchors)
        local geometryReference = sourceGeometryReference(preset, template.slot, slotAnchors)
        local sourceX, sourceY = templateAnchor(geometryReference)
        local targetBox = effectiveLineBox(target, context)
        local targetX, targetY = targetBox.anchor_x, targetBox.anchor_y
        local dx, dy = overallDx, overallDy
        if sourceX and targetX then dx, dy = targetX - sourceX, targetY - sourceY end

        local overlay = template.slot > 0 and slotAnchors[template.slot] == ordinal
        local templateAlignment = firstProgramTagValue(template.program, "an")
        local referenceAlignment = firstProgramTagValue(sourceReference.program, "an")

        outputs[#outputs + 1] = applyTemplateToLine(template, target, {
            resolved_styles = resolvedStyles,
            context = context,
            dx = dx, dy = dy,
            overlay_geometry = overlay,
            inherit_geometry_program = template.slot > 0 and targetProgram or overallTargetProgram,
            inherit_alignment = template.slot > 0
                and templateAlignment == referenceAlignment,
            generated = true,
            layer = layerBase + (tonumber(template.layer_delta) or 0) + layerShift,
            start_time = math.max(0, (tonumber(overallTarget.start_time) or 0)
                + (tonumber(template.start_delta) or 0)),
            end_time = math.max(0, (tonumber(overallTarget.end_time) or 0)
                + (tonumber(template.end_delta) or 0)),
            margin_l = relativeMargin(template.margin_l, sourceReference.margin_l, target.margin_l),
            margin_r = relativeMargin(template.margin_r, sourceReference.margin_r, target.margin_r),
            margin_t = relativeMargin(template.margin_t, sourceReference.margin_t, target.margin_t),
        })
    end
    return outputs
end

local function buildExistingOutputs(preset, targets, resolvedStyles, context)
    local outputs = {}
    local presetAnchor = preset.lines[preset.anchor] or preset.lines[1]
    local targetAnchor = targets[preset.anchor] or targets[1]
    local sourceAnchorX, sourceAnchorY = templateAnchor(presetAnchor)
    local targetAnchorBox = effectiveLineBox(targetAnchor, context)
    local targetAnchorX, targetAnchorY =
        targetAnchorBox.anchor_x, targetAnchorBox.anchor_y
    local fallbackDx, fallbackDy = 0, 0
    if sourceAnchorX and targetAnchorX then
        fallbackDx = targetAnchorX - sourceAnchorX
        fallbackDy = targetAnchorY - sourceAnchorY
    end

    for ordinal, template in ipairs(preset.lines) do
        local target = targets[ordinal]
        local sourceX, sourceY = templateAnchor(template)
        local targetBox = effectiveLineBox(target, context)
        local targetX, targetY = targetBox.anchor_x, targetBox.anchor_y
        local dx, dy = fallbackDx, fallbackDy
        if sourceX and targetX then dx, dy = targetX - sourceX, targetY - sourceY end
        outputs[#outputs + 1] = applyTemplateToLine(template, target, {
            resolved_styles = resolvedStyles,
            context = context,
            dx = dx, dy = dy,
            overlay_geometry = true,
            generated = false,
        })
    end
    return outputs
end

local function buildExactOutputs(preset, target, resolvedStyles, context)
    local outputs = {}
    local anchor = preset.lines[preset.anchor] or preset.lines[1]
    local sourceX, sourceY = templateAnchor(anchor)
    local targetBox = effectiveLineBox(target, context)
    local dx, dy = 0, 0
    if sourceX and sourceY and targetBox then
        dx, dy = targetBox.anchor_x - sourceX, targetBox.anchor_y - sourceY
    end
    local layerBase = tonumber(target.layer) or 0
    local layerShift = nonnegativeLayerShift(preset.lines, layerBase)

    for _, template in ipairs(preset.lines) do
        local out = cloneLine(target)
        local event = type(template.event) == "table" and template.event or {}
        out.class = "dialogue"
        out.comment = event.comment and true or false
        out.actor = tostring(event.actor or "")
        out.effect = tostring(event.effect or "")
        out.style = resolvedStyles[template.style] or template.style or target.style
        out.layer = layerBase + (tonumber(template.layer_delta) or 0) + layerShift
        out.start_time = math.max(0, (tonumber(target.start_time) or 0) + (tonumber(template.start_delta) or 0))
        out.end_time = math.max(0, (tonumber(target.end_time) or 0) + (tonumber(template.end_delta) or 0))
        assert(out.end_time > out.start_time, "The target duration is too short for the saved timing offsets.")
        out.margin_l = relativeMargin(template.margin_l, anchor.margin_l, target.margin_l)
        out.margin_r = relativeMargin(template.margin_r, anchor.margin_r, target.margin_r)
        out.margin_t = relativeMargin(template.margin_t, anchor.margin_t, target.margin_t)
        out.text = rewriteStyleResetsText(
            translateGeometryText(template.exact_text, dx, dy), resolvedStyles)
        out.extra = cloneTable(type(event.extra) == "table" and event.extra or template.extra or {})
        local plane = out.extra["_aegi_perspective_ambient_plane"]
        if plane ~= nil then out.extra["_aegi_perspective_ambient_plane"] = shiftPlaneExtra(plane, dx, dy) end
        outputs[#outputs + 1] = out
    end
    return outputs
end

local function contiguous(indices)
    for position = 2, #indices do
        if indices[position] ~= indices[position - 1] + 1 then return false end
    end
    return true
end

local function chunkIndices(indices, size)
    local chunks = {}
    for start = 1, #indices, size do
        local chunk = {}
        for position = start, math.min(start + size - 1, #indices) do
            chunk[#chunk + 1] = indices[position]
        end
        chunks[#chunks + 1] = chunk
    end
    return chunks
end

local function classifyUnits(subs, selection, preset, mode)
    local indices = LineOps.normalizeIndices(subs, selection, isDialogue)
    if #indices == 0 then return nil, "Select at least one target line." end

    local lineCount = #preset.lines
    local slotCount = math.max(1, tonumber(preset.slot_count) or 1)
    local units = {}

    if mode == "replace" then
        if lineCount == 0 or #indices % lineCount ~= 0 then
            return nil, string.format("Select a multiple of %d existing layers.", lineCount)
        end
        for _, chunk in ipairs(chunkIndices(indices, lineCount)) do
            if not contiguous(chunk) then return nil, "Each layer group must be contiguous." end
            units[#units + 1] = { kind = "existing", indices = chunk }
        end
        return units
    end

    if mode ~= "create" then return nil, "Choose Create from targets or Replace selected layers." end
    if slotCount == 1 then
        for _, index in ipairs(indices) do
            units[#units + 1] = { kind = "generated", indices = {index} }
        end
        return units
    end

    if #indices % slotCount ~= 0 then
        return nil, string.format("Select a multiple of %d target text lines.", slotCount)
    end
    for _, chunk in ipairs(chunkIndices(indices, slotCount)) do
        if not contiguous(chunk) then return nil, "Each target group must be contiguous." end
        units[#units + 1] = { kind = "generated", indices = chunk }
    end
    return units
end

local function applyExactPreset(subs, selection, preset)
    local indices = LineOps.normalizeIndices(subs, selection, isDialogue)
    if #indices == 0 then return nil, "Select at least one target line." end
    local resolvedStyles, insertPosition, addedStyles = ensurePresetStyles(subs, preset)
    if addedStyles > 0 then
        for position, index in ipairs(indices) do
            if index >= insertPosition then indices[position] = index + addedStyles end
        end
    end
    local context = { styles = collectStyles(subs), info = collectScriptInfo(subs) }
    local new_selection, cumulativeShift = {}, 0
    for _, index in ipairs(indices) do
        LineOps.checkCancelled()
        local current = index + cumulativeShift
        local outputs = buildExactOutputs(preset, subs[current], resolvedStyles, context)
        subs.delete(current)
        for position, output in ipairs(outputs) do
            subs.insert(current + position - 1, output)
            new_selection[#new_selection + 1] = current + position - 1
        end
        cumulativeShift = cumulativeShift + #outputs - 1
    end
    return new_selection, nil, {
        styles_added = addedStyles,
        lines_selected = #new_selection,
        groups = #indices,
    }
end

local function applyPresetImpl(subs, selection, active, preset, mode)
    local hydrated, presetError = hydratePreset(preset)
    if not hydrated then return nil, presetError end
    preset = hydrated
    if preset.kind == "exact" then return applyExactPreset(subs, selection, preset) end
    local units, classifyErr = classifyUnits(subs, selection, preset, mode or "create")
    if not units then return nil, classifyErr end

    local resolvedStyles, insertPosition, addedStyles = ensurePresetStyles(subs, preset)
    if addedStyles > 0 then
        for _, unit in ipairs(units) do
            for position, index in ipairs(unit.indices) do
                if index >= insertPosition then unit.indices[position] = index + addedStyles end
            end
        end

    end
    local geometryContext = {
        styles = collectStyles(subs),
        info = collectScriptInfo(subs),
    }

    local new_selection, cumulativeShift = {}, 0
    for _, unit in ipairs(units) do
        LineOps.checkCancelled()
        local currentIndices, targets = {}, {}
        for position, index in ipairs(unit.indices) do
            currentIndices[position] = index + cumulativeShift
            targets[position] = subs[currentIndices[position]]
        end

        local outputs
        if unit.kind == "existing" then
            outputs = buildExistingOutputs(preset, targets, resolvedStyles, geometryContext)
            for position, index in ipairs(currentIndices) do
                subs[index] = outputs[position]
                new_selection[#new_selection + 1] = index
            end
        else
            local slotTargets = {}
            for slot, target in ipairs(targets) do slotTargets[slot] = target end
            outputs = buildGeneratedOutputs(preset, slotTargets, resolvedStyles, geometryContext)
            local firstIndex = currentIndices[1]
            for position = #currentIndices, 1, -1 do subs.delete(currentIndices[position]) end
            for position, output in ipairs(outputs) do
                subs.insert(firstIndex + position - 1, output)
                new_selection[#new_selection + 1] = firstIndex + position - 1
            end
            cumulativeShift = cumulativeShift + #outputs - #currentIndices
        end
    end

    return new_selection, nil, {
        styles_added = addedStyles,
        lines_selected = #new_selection,
        groups = #units,
    }
end

local function applyPreset(subs, selection, active, preset, mode)
    local ok, updated, message, info = pcall(LineOps.transaction, subs, function()
        return applyPresetImpl(subs, selection, active, preset, mode)
    end)
    if not ok then return nil, tostring(updated) end
    return updated, message, info
end

AllureCore.analyzeStructure = analyzeStructure
AllureCore.semanticAnchor = semanticAnchor
AllureCore.mapSemanticAnchor = mapSemanticAnchor
AllureCore.inferPatternScope = inferPatternScope
AllureCore.splitTagProgram = splitTagProgram
AllureCore.parseTagTokens = parseTagTokens
AllureCore.translateGeometry = translateGeometry
AllureCore.affineRemapClips = affineRemapClips
AllureCore.detectClipFamilies = detectClipFamilies
AllureCore.renderProgram = renderProgram
AllureCore.capturePreset = capturePreset
AllureCore.hydratePreset = hydratePreset
AllureCore.classifyUnits = classifyUnits
AllureCore.applyPreset = applyPreset

AllureCore.analyze_structure = analyzeStructure
AllureCore.semantic_anchor = semanticAnchor
AllureCore.map_semantic_anchor = mapSemanticAnchor
AllureCore.infer_pattern_scope = inferPatternScope
AllureCore.split_tag_program = splitTagProgram
AllureCore.parse_tag_tokens = parseTagTokens
AllureCore.translate_geometry = translateGeometry
AllureCore.affine_remap_clips = affineRemapClips
AllureCore.detect_clip_families = detectClipFamilies
AllureCore.render_program = renderProgram
AllureCore.capture_preset = capturePreset
AllureCore.hydrate_preset = hydratePreset
AllureCore.classify_units = classifyUnits
AllureCore.apply_preset = applyPreset

local indexFileName = "Makeup Library.index.json"
local dataDirectoryName = "Makeup Library"
local indexFormat = "kite.makeup.index"
local presetFormat = "kite.makeup.preset"
local formatVersion = 3

local function array(value)
    return setmetatable(value or {}, { __jsontype = "array" })
end

local function cleanCopy(value, seen)
    local kind = type(value)
    if kind == "string" or kind == "boolean" then return value end
    if kind == "number" then
        if value == value and math.abs(value) ~= math.huge then return value end
        return nil
    end
    if kind ~= "table" then return nil end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local result = {}
    local maximum, count = 0, 0
    for key, item in pairs(value) do
        if key ~= "styles_by_name" and (type(key) == "string" or type(key) == "number") then
            local copied = cleanCopy(item, seen)
            if copied ~= nil then
                result[key] = copied
                count = count + 1
                if type(key) == "number" and key > maximum and key == math.floor(key) then maximum = key end
            end
        end
    end
    seen[value] = nil
    if maximum > 0 and maximum == count then array(result) end
    return result
end

local function encode(value)
    local ok, content = pcall(json.encode, value)
    if not ok then return nil, content end
    if type(content) ~= "string" then return nil, "JSON encoder returned no text" end
    return content
end

local function decode(content)
    local ok, value, _, message = pcall(json.decode, tostring(content or ""), 1, nil)
    if not ok then return nil, value end
    if value == nil then return nil, message or "invalid JSON" end
    return value
end

local function validIdentifier(value)
    return type(value) == "string" and value:match("^[a-f0-9]+$") ~= nil and #value >= 8 and #value <= 80
end

local function hash(value)
    local state = 5381
    value = tostring(value or "")
    for index = 1, #value do state = (state * 33 + value:byte(index)) % 2147483647 end
    return string.format("%08x", state)
end

local function paths(folder)
    folder = LineOps.trim(folder)
    if folder == "" then return nil, "library folder is empty" end
    local data = PyBridge.joinPath(folder, dataDirectoryName)
    return {
        folder = folder,
        index = PyBridge.joinPath(folder, indexFileName),
        data = data,
    }
end

local function recordPath(libraryPaths, identifier)
    if not validIdentifier(identifier) then return nil, "invalid preset identifier" end
    return PyBridge.joinPath(libraryPaths.data, identifier .. ".json")
end

local function normalizeEntry(value)
    if type(value) ~= "table" or not validIdentifier(value.id) then return nil end
    local name = LineOps.trim(value.name)
    local kind = value.kind == "exact" and "exact" or value.kind == "adaptive" and "adaptive" or nil
    if name == "" or not kind then return nil end
    return { id = value.id, name = name, kind = kind }
end

local function normalizeIndex(value)
    if type(value) ~= "table" or value.format ~= indexFormat or tonumber(value.version) ~= formatVersion then
        return nil, "This is not a valid Makeup library index."
    end
    local entries, seenIds, seenNames = {}, {}, {}
    for _, raw in ipairs(type(value.entries) == "table" and value.entries or {}) do
        local entry = normalizeEntry(raw)
        local folded = entry and (entry.kind .. "\31" .. entry.name:lower()) or nil
        if entry and not seenIds[entry.id] and not seenNames[folded] then
            seenIds[entry.id], seenNames[folded] = true, true
            entries[#entries + 1] = entry
        end
    end
    table.sort(entries, function(left, right)
        local a, b = left.name:lower(), right.name:lower()
        return a == b and left.name < right.name or a < b
    end)
    return { format = indexFormat, version = formatVersion, entries = array(entries) }
end

local function emptyIndex()
    return { format = indexFormat, version = formatVersion, entries = array({}) }
end

local function storageError(action, path, message)
    local reason = LineOps.trim(message)
    if reason == "" then reason = "The filesystem returned no error details." end
    return action .. ": " .. reason .. "\n" .. tostring(path or "")
end

local function loadIndex(folder)
    local libraryPaths, pathError = paths(folder)
    if not libraryPaths then return nil, pathError end
    if not PyBridge.fileExists(libraryPaths.index) then return emptyIndex(), libraryPaths end
    local content, readError = PyBridge.readFile(libraryPaths.index)
    if not content then return nil, storageError("Could not read the library index", libraryPaths.index, readError) end
    local decoded, decodeError = decode(content)
    if not decoded then return nil, decodeError end
    local index, indexError = normalizeIndex(decoded)
    if not index then return nil, indexError end
    return index, libraryPaths
end

local function saveIndex(libraryPaths, index)
    local normalized, normalizeError = normalizeIndex(index)
    if not normalized then return false, normalizeError end
    local content, encodeError = encode(normalized)
    if not content then return false, encodeError end
    local wrote, writeError = PyBridge.writeFile(libraryPaths.index, content)
    if not wrote then
        return false, storageError("Could not write the library index", libraryPaths.index, writeError)
    end
    return true
end

local function findEntry(index, nameOrId, kind)
    local value = LineOps.trim(nameOrId)
    local folded = value:lower()
    for position, entry in ipairs(index and index.entries or {}) do
        if entry.id == value or (entry.name:lower() == folded and (kind == nil or entry.kind == kind)) then
            return entry, position
        end
    end
    return nil, nil
end

local function uniqueIdentifier(index, name)
    local occupied = {}
    for _, entry in ipairs(index.entries) do occupied[entry.id] = true end
    local seed = table.concat({ name, tostring(os.time()), PyBridge.uniqueSuffix() }, "\31")
    local identifier = hash(seed) .. hash(seed:reverse())
    local suffix = 2
    while occupied[identifier] do
        identifier = hash(seed .. "\31" .. tostring(suffix)) .. hash(tostring(suffix) .. seed)
        suffix = suffix + 1
    end
    return identifier
end

local function save(folder, preset)
    if type(preset) ~= "table" then return nil, "Preset data is missing." end
    local name = LineOps.trim(preset.name)
    local kind = preset.kind == "exact" and "exact" or preset.kind == "adaptive" and "adaptive" or nil
    if name == "" then return nil, "Enter a preset name." end
    if not kind then return nil, "Unknown preset type." end

    local index, libraryPaths = loadIndex(folder)
    if not index then return nil, libraryPaths end
    local createdDirectory, directoryError = PyBridge.ensureDir(libraryPaths.data)
    if not createdDirectory then
        return nil, storageError("Could not create the preset folder", libraryPaths.data, directoryError)
    end

    local existing, position = findEntry(index, name, kind)
    local identifier = uniqueIdentifier(index, name)
    local path, recordPathError = recordPath(libraryPaths, identifier)
    if not path then return nil, recordPathError end
    local record = {
        format = presetFormat,
        version = formatVersion,
        kind = kind,
        name = name,
        saved_at = os.time(),
        payload = cleanCopy(preset),
    }
    local content, encodeError = encode(record)
    if not content then return nil, encodeError end
    local wrote, writeError = PyBridge.writeFile(path, content)
    if not wrote then return nil, storageError("Could not write the preset", path, writeError) end

    local entry = { id = identifier, name = name, kind = kind }
    if position then index.entries[position] = entry else index.entries[#index.entries + 1] = entry end
    local savedIndex, indexError = saveIndex(libraryPaths, index)
    if not savedIndex then
        PyBridge.removeFile(path)
        return nil, indexError
    end
    if existing then PyBridge.removeFile(recordPath(libraryPaths, existing.id)) end
    return entry, { bytes = #content, replaced = existing ~= nil, paths = libraryPaths }
end

local function load(folder, entryOrId)
    local index, libraryPaths = loadIndex(folder)
    if not index then return nil, libraryPaths end
    local identifier = type(entryOrId) == "table" and entryOrId.id or entryOrId
    local entry = findEntry(index, identifier)
    if not entry then return nil, "The preset is no longer indexed." end
    local path, pathError = recordPath(libraryPaths, entry.id)
    if not path then return nil, pathError end
    local content, readError = PyBridge.readFile(path)
    if not content then return nil, storageError("Could not read the preset", path, readError) end
    local record, decodeError = decode(content)
    if not record then return nil, decodeError end
    if type(record) ~= "table" or record.format ~= presetFormat
        or tonumber(record.version) ~= formatVersion or type(record.payload) ~= "table" then
        return nil, "The selected file is not a valid Makeup preset."
    end
    if record.kind ~= entry.kind or LineOps.trim(record.name) ~= entry.name then
        return nil, "Preset index and data do not match."
    end
    record.payload.name, record.payload.kind = entry.name, entry.kind
    return record.payload, { bytes = #content, entry = entry, paths = libraryPaths }
end

local function remove(folder, entryOrId)
    local index, libraryPaths = loadIndex(folder)
    if not index then return false, libraryPaths end
    local identifier = type(entryOrId) == "table" and entryOrId.id or entryOrId
    local entry, position = findEntry(index, identifier)
    if not entry then return false, "The preset is no longer indexed." end
    table.remove(index.entries, position)
    local saved, saveError = saveIndex(libraryPaths, index)
    if not saved then return false, saveError end
    local path = recordPath(libraryPaths, entry.id)
    local deleted, deleteError = PyBridge.removeFile(path)
    if not deleted then return true, "Index updated; one orphaned file remains: " .. tostring(deleteError) end
    return true
end

Store.INDEX_FILE_NAME = indexFileName
Store.DATA_DIRECTORY_NAME = dataDirectoryName
Store.FORMAT_VERSION = formatVersion
Store.paths = paths
Store.loadIndex = loadIndex
Store.findEntry = findEntry
Store.save = save
Store.load = load
Store.remove = remove
Store.cleanCopy = cleanCopy

local function createPosing(showError, setUndoPoint)
    local numPattern = "[%+%-]?%d*%.?%d+"
    local EPSILON = 0.0000001
    local rotateGroup = "Conjunto seleccionado"
    local rotateIndividual = "Cada línea sobre su centro"
    local pivotCenter = "Centro del conjunto"
    local pivotFirst = "Primera línea"
    local pivotCustom = "Personalizado"
    local assTagNames = {
        "iclip", "clip", "xbord", "ybord", "xshad", "yshad", "fscx", "fscy",
        "alpha", "blur", "bord", "shad", "move", "fade", "frx", "fry", "frz", "fax", "fay",
        "pos", "org", "fad", "fsp", "fn", "fs", "be", "an", "fr", "ko", "kf", "kt",
        "1a", "2a", "3a", "4a", "1c", "2c", "3c", "4c", "c", "p", "b", "i", "u", "s", "r", "t", "q", "k", "K", "a"
    }

    local finite = KiteCore.finiteNumber

    local function formatNumber(value, precision)
        value = finite(value) or 0
        if math.abs(value) < EPSILON then value = 0 end
        local text = string.format("%." .. tostring(precision or 3) .. "f", value)
        text = text:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
        if text == "-0" then text = "0" end
        return text
    end

    local function editableSelection(subs, sel)
        return LineOps.normalizeIndices(subs, sel, function(line)
            return type(line) == "table" and line.class == "dialogue" and not line.comment
        end)
    end

    local function looksLikeOverride(inner)
        return tostring(inner or ""):match("^%s*\\") ~= nil
    end

    local function balancedParenthesisEnd(text, opening)
        local depth = 0
        for index = opening, #text do
            local char = text:sub(index, index)
            if char == "(" then
                depth = depth + 1
            elseif char == ")" then
                depth = depth - 1
                if depth == 0 then return index end
            end
        end
        return nil
    end

    local function tagNameAt(text, slash)
        local rest = text:sub(slash + 1)
        for _, name in ipairs(assTagNames) do
            if rest:sub(1, #name) == name then
                return name, slash + 1 + #name
            end
        end
        local name = rest:match("^[1-4]?%a+")
        if not name then return nil end
        return name, slash + 1 + #name
    end

    local function mapOverrideBlocks(text, callback)
        local failure
        local mapped = tostring(text or ""):gsub("%b{}", function(block)
            if failure then return block end
            local inner = block:sub(2, -2)
            if not looksLikeOverride(inner) then return block end
            local replacement, err = callback(inner)
            if not replacement then
                failure = err or "No se pudo procesar un bloque de tags."
                return block
            end
            return "{" .. replacement .. "}"
        end)
        if failure then return nil, failure end
        return mapped
    end

    local function scanCallsInInner(inner, callback)
        local index, depth = 1, 0
        while index <= #inner do
            local char = inner:sub(index, index)
            if char == "\\" then
                local name, nameEnd = tagNameAt(inner, index)
                if name then
                    local argumentStart = nameEnd
                    while inner:sub(argumentStart, argumentStart):match("%s") do
                        argumentStart = argumentStart + 1
                    end
                    if inner:sub(argumentStart, argumentStart) == "(" then
                        local argumentEnd = balancedParenthesisEnd(inner, argumentStart)
                        if not argumentEnd then
                            return nil, "Hay un tag con paréntesis incompletos."
                        end
                        local ok, err = callback(name:lower(), inner:sub(argumentStart + 1, argumentEnd - 1), depth)
                        if ok == false then return nil, err end
                        if name:lower() ~= "t" then
                            index = argumentEnd + 1
                        else
                            index = index + 1
                        end
                    else
                        index = nameEnd
                    end
                else
                    index = index + 1
                end
            else
                if char == "(" then
                    depth = depth + 1
                elseif char == ")" and depth > 0 then
                    depth = depth - 1
                end
                index = index + 1
            end
        end
        return true
    end

    local function analyzeText(text)
        local analysis = {has_clip = false}
        local failure
        local mapped, err = mapOverrideBlocks(text, function(inner)
            local ok, scanErr = scanCallsInInner(inner, function(name, args, depth)
                if name == "clip" or name == "iclip" then
                    analysis.has_clip = true
                elseif depth == 0 and not analysis[name] and (name == "pos" or name == "move" or name == "org") then
                    analysis[name] = args
                end
                return true
            end)
            if not ok then return nil, scanErr end
            return inner
        end)
        if not mapped then failure = err end
        if failure then return nil, failure end
        return analysis
    end

    local function splitCsvNumbers(arguments)
        local values = {}
        local start = 1
        local text = tostring(arguments or "")
        while true do
            local comma = text:find(",", start, true)
            local part = trim(text:sub(start, comma and comma - 1 or #text))
            if part == "" or not part:match("^" .. numPattern .. "$") then return nil end
            local number = finite(part)
            if not number then return nil end
            values[#values + 1] = number
            if not comma then break end
            start = comma + 1
        end
        return values
    end

    local function parsePoint(arguments, label)
        local values = splitCsvNumbers(arguments)
        if not values or #values ~= 2 then
            return nil, "El tag \\" .. label .. " debe tener dos coordenadas numéricas."
        end
        return {x = values[1], y = values[2]}
    end

    local function parseMoveStart(arguments)
        local values = splitCsvNumbers(arguments)
        if not values or (#values ~= 4 and #values ~= 6) then
            return nil, "El tag \\move debe tener cuatro o seis valores numéricos."
        end
        return {x = values[1], y = values[2]}
    end

    local function tokenizePath(path)
        local tokens = {}
        local index = 1
        local commands = {m = true, n = true, l = true, b = true, s = true, p = true, c = true}
        while index <= #path do
            local char = path:sub(index, index)
            if char:match("[%s,]") then
                index = index + 1
            elseif char:match("[%a]") then
                local command = char:lower()
                if not commands[command] then
                    return nil, "El clip vectorial contiene el comando no compatible '" .. char .. "'."
                end
                tokens[#tokens + 1] = {kind = "command", value = command}
                index = index + 1
            else
                local fragment = path:sub(index)
                local number = fragment:match("^(" .. numPattern .. ")")
                if not number then
                    return nil, "El clip vectorial contiene datos que no se pudieron interpretar."
                end
                if not finite(number) then return nil, "El clip contiene coordenadas fuera del rango numérico." end
                tokens[#tokens + 1] = {kind = "number", value = tonumber(number)}
                index = index + #number
            end
        end
        return tokens
    end

    local function validatePathTokens(tokens)
        local command, count
        local function validateGroup()
            if not command then return true end
            if command == "c" then
                return count == 0
            elseif command == "b" then
                return count >= 6 and count % 6 == 0
            elseif command == "s" then
                return count >= 6 and count % 2 == 0
            end
            return count >= 2 and count % 2 == 0
        end
        for _, token in ipairs(tokens) do
            if token.kind == "command" then
                if not validateGroup() then return false end
                command, count = token.value, 0
            else
                if not command then return false end
                count = count + 1
            end
        end
        return validateGroup()
    end

    local function parseClip(arguments)
        local text = trim(arguments)
        local rectangle = splitCsvNumbers(text)
        if rectangle and #rectangle == 4 then
            return {kind = "rect", values = rectangle}
        end
        local explicitScale = false
        local scale, path = text:match("^(" .. numPattern .. ")%s*,%s*(.*)$")
        if scale and trim(path):match("^[mnlbspcMNLBSPC]") then
            explicitScale = true
            scale = tonumber(scale)
        else
            scale, path = 1, text
        end
        if scale ~= math.floor(scale) or scale < 1 or not finite(2 ^ (scale - 1)) or not trim(path):match("^[mnlbspcMNLBSPC]") then
            return nil, "El clip no es rectangular ni un vector ASS compatible."
        end
        local tokens, tokenErr = tokenizePath(path)
        if not tokens then return nil, tokenErr end
        if not validatePathTokens(tokens) then
            return nil, "El clip vectorial tiene una cantidad inválida de coordenadas."
        end
        return {kind = "vector", scale = scale, explicit_scale = explicitScale, tokens = tokens}
    end

    local function transformPoint(x, y, pivotX, pivotY, dx, dy, radians, resizeFactor)
        resizeFactor = resizeFactor or 1
        local cosine, sine = math.cos(radians), math.sin(radians)
        local relativeX, relativeY = x - pivotX, y - pivotY
        return pivotX + resizeFactor * (cosine * relativeX + sine * relativeY) + dx,
               pivotY + resizeFactor * (-sine * relativeX + cosine * relativeY) + dy
    end

    local function transformVectorPath(clip, pivot, dx, dy, radians, resizeFactor)
        local factor = 2 ^ (clip.scale - 1)
        local pivotX, pivotY = pivot.x * factor, pivot.y * factor
        local shiftX, shiftY = dx * factor, dy * factor
        local output, pending = {}, {}
        local function flushPending()
            for index = 1, #pending, 2 do
                local x, y = transformPoint(pending[index], pending[index + 1], pivotX, pivotY,
                    shiftX, shiftY, radians, resizeFactor)
                output[#output + 1] = formatNumber(x, 3)
                output[#output + 1] = formatNumber(y, 3)
            end
            pending = {}
        end
        for _, token in ipairs(clip.tokens) do
            if token.kind == "command" then
                flushPending()
                output[#output + 1] = token.value
            else
                pending[#pending + 1] = token.value
            end
        end
        flushPending()
        local path = table.concat(output, " ")
        if clip.explicit_scale then
            return tostring(clip.scale) .. "," .. path
        end
        return path
    end

    local function transformRectClip(clip, pivot, dx, dy, radians, resizeFactor)
        local x1 = math.min(clip.values[1], clip.values[3])
        local y1 = math.min(clip.values[2], clip.values[4])
        local x2 = math.max(clip.values[1], clip.values[3])
        local y2 = math.max(clip.values[2], clip.values[4])
        if math.abs(radians) < EPSILON then
            local nx1, ny1 = transformPoint(x1, y1, pivot.x, pivot.y, dx, dy, 0, resizeFactor)
            local nx2, ny2 = transformPoint(x2, y2, pivot.x, pivot.y, dx, dy, 0, resizeFactor)
            return table.concat({
                formatNumber(math.min(nx1, nx2), 3), formatNumber(math.min(ny1, ny2), 3),
                formatNumber(math.max(nx1, nx2), 3), formatNumber(math.max(ny1, ny2), 3)
            }, ",")
        end
        local corners = {{x1, y1}, {x2, y1}, {x2, y2}, {x1, y2}}
        local path = {"m"}
        for index, point in ipairs(corners) do
            local x, y = transformPoint(point[1], point[2], pivot.x, pivot.y,
                dx, dy, radians, resizeFactor)
            path[#path + 1] = formatNumber(x, 3)
            path[#path + 1] = formatNumber(y, 3)
            if index == 1 then path[#path + 1] = "l" end
        end
        return table.concat(path, " ")
    end

    local function transformGeometryInner(inner, pivot, dx, dy, radians, resizeFactor, transformAnchors)
        local parts, cursor, index, depth = {}, 1, 1, 0
        while index <= #inner do
            local char = inner:sub(index, index)
            if char == "\\" then
                local name, nameEnd = tagNameAt(inner, index)
                if name then
                    local lower = name:lower()
                    local argumentStart = nameEnd
                    while inner:sub(argumentStart, argumentStart):match("%s") do
                        argumentStart = argumentStart + 1
                    end
                    if inner:sub(argumentStart, argumentStart) == "(" then
                        local argumentEnd = balancedParenthesisEnd(inner, argumentStart)
                        if not argumentEnd then return nil, "Hay un tag con paréntesis incompletos." end
                        if lower == "pos" or lower == "org" or lower == "move" or lower == "clip" or lower == "iclip" then
                            local arguments = inner:sub(argumentStart + 1, argumentEnd - 1)
                            local replacement
                            if lower == "pos" or lower == "org" then
                                local point, pointErr = parsePoint(arguments, lower)
                                if not point then return nil, pointErr end
                                local x, y
                                if transformAnchors then
                                    x, y = transformPoint(point.x, point.y, pivot.x, pivot.y,
                                        dx, dy, radians, resizeFactor)
                                else
                                    x, y = point.x + dx, point.y + dy
                                end
                                replacement = "\\" .. name .. "(" .. formatNumber(x, 3) .. "," .. formatNumber(y, 3) .. ")"
                            elseif lower == "move" then
                                local values = splitCsvNumbers(arguments)
                                if not values or (#values ~= 4 and #values ~= 6) then
                                    return nil, "El tag \\move debe tener cuatro o seis valores numéricos."
                                end
                                if transformAnchors then
                                    values[1], values[2] = transformPoint(values[1], values[2], pivot.x, pivot.y,
                                        dx, dy, radians, resizeFactor)
                                    values[3], values[4] = transformPoint(values[3], values[4], pivot.x, pivot.y,
                                        dx, dy, radians, resizeFactor)
                                else
                                    values[1], values[2] = values[1] + dx, values[2] + dy
                                    values[3], values[4] = values[3] + dx, values[4] + dy
                                end
                                local formatted = {}
                                for valueIndex, value in ipairs(values) do
                                    formatted[valueIndex] = formatNumber(value, valueIndex <= 4 and 3 or 0)
                                end
                                replacement = "\\" .. name .. "(" .. table.concat(formatted, ",") .. ")"
                            else
                                local clip, clipErr = parseClip(arguments)
                                if not clip then return nil, clipErr end
                                if clip.kind == "rect" and depth > 0 and math.abs(radians) >= EPSILON then
                                    return nil, "No se puede rotar exactamente un clip rectangular animado dentro de \\t; hornéalo FBF primero."
                                end
                                local clipInner
                                if clip.kind == "rect" then
                                    clipInner = transformRectClip(clip, pivot, dx, dy, radians, resizeFactor)
                                else
                                    clipInner = transformVectorPath(clip, pivot, dx, dy, radians, resizeFactor)
                                end
                                replacement = "\\" .. name .. "(" .. clipInner .. ")"
                            end
                            parts[#parts + 1] = inner:sub(cursor, index - 1)
                            parts[#parts + 1] = replacement
                            cursor = argumentEnd + 1
                            index = argumentEnd + 1
                        else
                            index = index + 1
                        end
                    else
                        index = nameEnd
                    end
                else
                    index = index + 1
                end
            else
                if char == "(" then
                    depth = depth + 1
                elseif char == ")" and depth > 0 then
                    depth = depth - 1
                end
                index = index + 1
            end
        end
        parts[#parts + 1] = inner:sub(cursor)
        return table.concat(parts)
    end

    local function mapNumericTags(inner, names, mapper)
        local failure
        local mapped = LineOps.mapTagCalls("{" .. inner .. "}", names, function(call)
            local value = finite(trim(call.value))
            if not value then
                failure = "Hay un tag " .. call.raw_name .. " sin un valor numérico finito."
                return nil
            end
            return "\\" .. call.raw_name .. formatNumber(mapper(value), 3)
        end, {top_level_only = false})
        if failure then return nil, failure end
        return mapped:sub(2, -2)
    end

    local function mapExistingFrz(inner, delta)
        return mapNumericTags(inner, {frz = true}, function(value) return value + delta end)
    end

    local function buildContext(subs)
        local context = {styles = {}, styles_lower = {}}
        for index = 1, #subs do
            local item = subs[index]
            if type(item) == "table" and item.class == "style" then
                local name = tostring(item.name or item.style or "")
                if name ~= "" then
                    context.styles[name] = item
                    context.styles_lower[name:lower()] = item
                end
            elseif type(item) == "table" and item.class == "info" then
                local key = tostring(item.key or ""):lower()
                if key == "playresx" then context.play_x = tonumber(item.value) end
                if key == "playresy" then context.play_y = tonumber(item.value) end
            end
        end
        if (not context.play_x or not context.play_y) and aegisub.video_size then
            local ok, width, height = pcall(aegisub.video_size)
            if ok then
                context.play_x = context.play_x or tonumber(width)
                context.play_y = context.play_y or tonumber(height)
            end
        end
        return context
    end

    local function styleFor(context, name, fallback)
        name = trim(name)
        if name ~= "" then
            return context.styles[name] or context.styles_lower[name:lower()] or fallback
        end
        return fallback
    end

    local function styleAngle(style)
        return finite(style and (style.angle or style.rotation)) or 0
    end

    local function mapResets(inner, context, lineStyle, suffix)
        local mapped = LineOps.mapTagCalls("{" .. inner .. "}", {r = true}, function(call)
            return call.raw .. suffix(styleFor(context, call.value, lineStyle))
        end)
        return mapped:sub(2, -2)
    end

    local function injectResetRotations(inner, context, lineStyle, delta)
        return mapResets(inner, context, lineStyle, function(style)
            return "\\frz" .. formatNumber(styleAngle(style) + delta, 3)
        end)
    end

    local function styleScale(style, field)
        return finite(style and style[field]) or 100
    end

    local function mapExistingScales(inner, resizeFactor)
        return mapNumericTags(inner, {fscx = true, fscy = true}, function(value) return value * resizeFactor end)
    end

    local function injectResetScales(inner, context, lineStyle, resizeFactor)
        return mapResets(inner, context, lineStyle, function(style)
            return "\\fscx" .. formatNumber(styleScale(style, "scale_x") * resizeFactor, 3)
                .. "\\fscy" .. formatNumber(styleScale(style, "scale_y") * resizeFactor, 3)
        end)
    end

    local function scanTopLevelTagNames(inner, callback)
        local index, depth = 1, 0
        while index <= #inner do
            local char = inner:sub(index, index)
            if char == "\\" and depth == 0 then
                local name, nameEnd = tagNameAt(inner, index)
                if name then
                    callback(name:lower())
                    index = nameEnd
                else
                    index = index + 1
                end
            else
                if char == "(" then
                    depth = depth + 1
                elseif char == ")" and depth > 0 then
                    depth = depth - 1
                end
                index = index + 1
            end
        end
    end

    local function leadingHasFrz(text)
        local position, hasFrz = 1, false
        text = tostring(text or "")
        while text:sub(position, position) == "{" do
            local close = text:find("}", position, true)
            if not close then break end
            local inner = text:sub(position + 1, close - 1)
            if looksLikeOverride(inner) then
                scanTopLevelTagNames(inner, function(name)
                    if name == "r" then hasFrz = false end
                    if name == "frz" then hasFrz = true end
                end)
            end
            position = close + 1
        end
        return hasFrz
    end

    local function leadingScaleTags(text)
        local hasX, hasY = false, false
        local position = 1
        text = tostring(text or "")
        while text:sub(position, position) == "{" do
            local close = text:find("}", position, true)
            if not close then break end
            local inner = text:sub(position + 1, close - 1)
            if looksLikeOverride(inner) then
                scanTopLevelTagNames(inner, function(name)
                    if name == "r" then hasX, hasY = false, false end
                    if name == "fscx" then hasX = true end
                    if name == "fscy" then hasY = true end
                end)
            end
            position = close + 1
        end
        return hasX, hasY
    end

    local function insertLeadingTag(text, tag)
        text = tostring(text or "")
        local position = 1
        while text:sub(position, position) == "{" do
            local close = text:find("}", position, true)
            if not close then break end
            local inner = text:sub(position + 1, close - 1)
            if looksLikeOverride(inner) then
                return text:sub(1, position) .. tag .. text:sub(position + 1)
            end
            position = close + 1
        end
        return text:sub(1, position - 1) .. "{" .. tag .. "}" .. text:sub(position)
    end

    local function resizeAppearance(text, context, lineStyle, resizeFactor)
        if math.abs(resizeFactor - 1) < EPSILON then return text end
        local mapped, err = mapOverrideBlocks(text, function(inner)
            local scaled, scaleErr = mapExistingScales(inner, resizeFactor)
            if not scaled then return nil, scaleErr end
            return injectResetScales(scaled, context, lineStyle, resizeFactor)
        end)
        if not mapped then return nil, err end
        local hasX, hasY = leadingScaleTags(mapped)
        local leading = ""
        if not hasX then
            leading = leading .. "\\fscx" .. formatNumber(styleScale(lineStyle, "scale_x") * resizeFactor, 3)
        end
        if not hasY then
            leading = leading .. "\\fscy" .. formatNumber(styleScale(lineStyle, "scale_y") * resizeFactor, 3)
        end
        if leading == "" then return mapped end
        return insertLeadingTag(mapped, leading)
    end

    local function defaultPosition(line, style, context)
        local x, y, message = AssContext.defaultPosition(line, {
            style = style,
            meta = {play_res_x = context.play_x, play_res_y = context.play_y},
        })
        if not x then return nil, message end
        return {x = x, y = y}
    end

    local function anchorPointsForLine(line, context)
        local analysis, err = analyzeText(line.text)
        if not analysis then return nil, err end
        if analysis.pos and analysis.move then
            return nil, "La línea contiene \\pos y \\move a la vez; deja una sola posición antes de transformarla."
        end
        if analysis.pos then
            local point, pointErr = parsePoint(analysis.pos, "pos")
            if not point then return nil, pointErr end
            return {point}
        end
        if analysis.move then
            local values = splitCsvNumbers(analysis.move)
            if not values or (#values ~= 4 and #values ~= 6) then
                return nil, "El tag \\move debe tener cuatro o seis valores numéricos."
            end
            return {{x = values[1], y = values[2]}, {x = values[3], y = values[4]}}
        end
        local style = styleFor(context, line.style, context.styles.Default or context.styles_lower.default)
        local point, pointErr = defaultPosition(line, style, context)
        if not point then return nil, pointErr end
        return {point}
    end

    local function resolveGroupPivot(subs, indices, context, config)
        local mode = config.pivot_mode or pivotCenter
        if mode == pivotCustom or mode == "custom" then
            local x, y = finite(config.pivot_x), finite(config.pivot_y)
            if not x or not y then return nil, "El pivote personalizado necesita X e Y numéricos." end
            return {x = x, y = y}
        end
        local minX, minY, maxX, maxY
        for _, index in ipairs(indices) do
            local points, err = anchorPointsForLine(subs[index], context)
            if not points then return nil, "Línea " .. tostring(index) .. ": " .. tostring(err) end
            for _, point in ipairs(points) do
                if mode == pivotFirst or mode == "first" then return {x = point.x, y = point.y} end
                minX = not minX and point.x or math.min(minX, point.x)
                minY = not minY and point.y or math.min(minY, point.y)
                maxX = not maxX and point.x or math.max(maxX, point.x)
                maxY = not maxY and point.y or math.max(maxY, point.y)
            end
        end
        if not minX then return nil, "No se pudo calcular el centro del conjunto." end
        return {x = (minX + maxX) / 2, y = (minY + maxY) / 2}
    end

    local function transformLine(line, context, dx, dy, rotation, resizeFactor, sharedPivot, groupRotation)
        local analysis, analysisErr = analyzeText(line.text)
        if not analysis then return nil, analysisErr end
        if analysis.pos and analysis.move then
            return nil, "La línea contiene \\pos y \\move a la vez; deja una sola posición antes de transformarla."
        end
        local style = styleFor(context, line.style, context.styles.Default or context.styles_lower.default)
        local implicitPosition
        if not analysis.pos and not analysis.move then
            implicitPosition, analysisErr = defaultPosition(line, style, context)
            if not implicitPosition then return nil, analysisErr end
        end
        local linePivot
        if analysis.org then
            linePivot, analysisErr = parsePoint(analysis.org, "org")
        elseif analysis.pos then
            linePivot, analysisErr = parsePoint(analysis.pos, "pos")
        elseif analysis.move then
            linePivot, analysisErr = parseMoveStart(analysis.move)
        else
            linePivot = implicitPosition
        end
        if not linePivot then return nil, analysisErr end
        if not groupRotation and math.abs(rotation) >= EPSILON and analysis.has_clip and analysis.move and not analysis.org then
            return nil, "Una línea con \\move y clip necesita \\org para conservar un pivote único al rotar; hornéala FBF o agrega el origen."
        end
        local groupRadians = groupRotation and math.rad(rotation) or 0
        local individualRadians = groupRotation and 0 or math.rad(rotation)
        local transformAnchors = sharedPivot ~= nil
        local primaryPivot = sharedPivot or linePivot
        local primaryRadians = transformAnchors and groupRadians or individualRadians
        local primaryResize = transformAnchors and resizeFactor or 1
        local text, geometryErr = mapOverrideBlocks(line.text, function(inner)
            return transformGeometryInner(inner, primaryPivot, dx, dy,
                primaryRadians, primaryResize, transformAnchors)
        end)
        if not text then return nil, geometryErr end
        if transformAnchors and math.abs(individualRadians) >= EPSILON then
            local pivotX, pivotY = transformPoint(linePivot.x, linePivot.y,
                sharedPivot.x, sharedPivot.y, dx, dy, groupRadians, resizeFactor)
            local individualPivot = {x = pivotX, y = pivotY}
            text, geometryErr = mapOverrideBlocks(text, function(inner)
                return transformGeometryInner(inner, individualPivot, 0, 0,
                    individualRadians, 1, false)
            end)
            if not text then return nil, geometryErr end
        end
        if not analysis.pos and not analysis.move then
            local x, y
            if transformAnchors then
                x, y = transformPoint(implicitPosition.x, implicitPosition.y,
                    sharedPivot.x, sharedPivot.y, dx, dy, groupRadians, resizeFactor)
            else
                x, y = implicitPosition.x + dx, implicitPosition.y + dy
            end
            text = insertLeadingTag(text, "\\pos(" .. formatNumber(x, 3) .. "," .. formatNumber(y, 3) .. ")")
        end
        text, geometryErr = resizeAppearance(text, context, style, resizeFactor)
        if not text then return nil, geometryErr end
        if math.abs(rotation) >= EPSILON then
            text, geometryErr = mapOverrideBlocks(text, function(inner)
                local mapped, frzErr = mapExistingFrz(inner, rotation)
                if not mapped then return nil, frzErr end
                return injectResetRotations(mapped, context, style, rotation)
            end)
            if not text then return nil, geometryErr end
            if not leadingHasFrz(text) then
                text = insertLeadingTag(text, "\\frz" .. formatNumber(styleAngle(style) + rotation, 3))
            end
        end
        local copy = KiteCore.copy(line)
        copy.text = text
        return copy
    end

    local function applyTransform(subs, sel, config)
        local dx = finite(config.dx) or 0
        local dy = finite(config.dy) or 0
        local rotation = finite(config.rotation) or 0
        local resize = finite(config.resize) or 0
        local resizeFactor = 1 + resize / 100
        if resizeFactor <= EPSILON then
            showError("El resize relativo debe dejar un tamaño mayor que cero.")
            return sel
        end
        if math.abs(dx) < EPSILON and math.abs(dy) < EPSILON and math.abs(rotation) < EPSILON
            and math.abs(resize) < EPSILON then
            showError("Introduce un desplazamiento, una rotación o un resize distintos de cero.")
            return sel
        end
        local indices = editableSelection(subs, sel)
        if #indices == 0 then
            showError("Selecciona al menos una línea de diálogo.")
            return sel
        end
        local context = buildContext(subs)
        local sharedPivot
        local groupRotation = config.rotation_mode == rotateGroup
        if math.abs(resize) >= EPSILON or (groupRotation and math.abs(rotation) >= EPSILON) then
            local pivotErr
            sharedPivot, pivotErr = resolveGroupPivot(subs, indices, context, config)
            if not sharedPivot then
                showError(pivotErr)
                return sel
            end
        end
        local updates = {}
        for _, index in ipairs(indices) do
            LineOps.checkCancelled()
            local transformed, err = transformLine(subs[index], context, dx, dy, rotation,
                resizeFactor, sharedPivot, groupRotation)
            if not transformed then
                showError("Línea " .. tostring(index) .. ": " .. tostring(err))
                return sel
            end
            updates[#updates + 1] = {index = index, line = transformed}
        end
        LineOps.transaction(subs, function()
            for _, update in ipairs(updates) do
                LineOps.checkCancelled()
                subs[update.index] = update.line
            end
        end)
        setUndoPoint()
        return indices, indices[1]
    end

    return {
        parseClip = parseClip,
        parse_clip = parseClip,
        transformPoint = transformPoint,
        transform_point = transformPoint,
        transformLine = transformLine,
        transform_line = transformLine,
        buildContext = buildContext,
        build_context = buildContext,
        anchorPointsForLine = anchorPointsForLine,
        anchor_points_for_line = anchorPointsForLine,
        resolveGroupPivot = resolveGroupPivot,
        resolve_group_pivot = resolveGroupPivot,
        rotation_modes = {group = rotateGroup, individual = rotateIndividual},
        pivot_modes = {center = pivotCenter, first = pivotFirst, custom = pivotCustom},
        applyTransform = applyTransform,
        apply_transform = applyTransform
    }
end

local TEXT = {
    en = {
        section_posing = "POSING",
        section_makeup = "MAKEUP",
        label_action = "Action:",
        label_move_x = "Move X:",
        label_move_y = "Move Y:",
        label_rotation = "Relative Z rotation:",
        label_resize = "Relative resize (%):",
        label_rotation_mode = "Rotate as:",
        label_pivot_mode = "Group pivot:",
        label_pivot_x = "Pivot X:",
        label_pivot_y = "Pivot Y:",
        label_preset = "Preset:",
        label_name = "Name:",
        label_insert_mode = "Insert mode:",
        label_language = "Language:",
        label_x_step = "Hotkey X step:",
        label_y_step = "Hotkey Y step:",
        label_rotation_step = "Hotkey rotation step:",
        label_hotkey_rotation_mode = "Hotkey rotation mode:",
        label_hotkey_pivot_mode = "Hotkey pivot:",
        posing_custom = "Transform selection",
        posing_x_plus = "Move X +%s",
        posing_x_minus = "Move X -%s",
        posing_y_plus = "Move Y +%s",
        posing_y_minus = "Move Y -%s",
        posing_rotation_plus = "Rotate Z +%s",
        posing_rotation_minus = "Rotate Z -%s",
        makeup_insert = "Insert preset",
        makeup_save_style = "Save style",
        makeup_save_group = "Save group",
        makeup_save_both = "Save both",
        makeup_delete = "Delete preset",
        rotation_group = "Selected group",
        rotation_individual = "Each line around its center",
        pivot_center = "Center of selection",
        pivot_first = "First line",
        pivot_custom = "Custom",
        insert_create = "Create from targets",
        insert_replace = "Replace selected layers",
        hint_pivot = "Resize uses this pivot: -40 gives 60%. Positive degrees rotate counterclockwise.",
        hint_insert = "Insert mode applies to [TAG] presets.",
        no_presets = "(no presets)",
        button_makeup = "Makeup",
        button_posing = "Posing",
        button_config = "Config",
        button_help = "Help",
        button_cancel = "Cancel",
        button_save = "Save",
        button_ok = "OK",
        button_yes = "Yes",
        button_no = "No",
        save_subtitle = "Save the subtitle file first.",
        library_error = "Library error\n%s",
        enter_name = "Enter a name.",
        replace_presets = "Replace %s?",
        save_failed = "Save failed\n%s",
        saved = "Saved %s",
        select_preset = "Select a preset.",
        delete_confirm = "Delete %s?",
        delete_failed = "Delete failed\n%s",
        load_failed = "Load failed\n%s",
        insert_failed = "Insert failed\n%s",
        config_invalid_steps = "Hotkey steps must be numbers greater than zero.",
        undo_makeup = "Allure - Makeup: %s",
        undo_posing = "Allure - Posing",
    },
    es = {
        section_posing = "POSING",
        section_makeup = "MAKEUP",
        label_action = "Acción:",
        label_move_x = "Mover X:",
        label_move_y = "Mover Y:",
        label_rotation = "Rotación Z relativa:",
        label_resize = "Resize relativo (%):",
        label_rotation_mode = "Rotar como:",
        label_pivot_mode = "Pivote del conjunto:",
        label_pivot_x = "Pivote X:",
        label_pivot_y = "Pivote Y:",
        label_preset = "Preset:",
        label_name = "Nombre:",
        label_insert_mode = "Modo de inserción:",
        label_language = "Idioma:",
        label_x_step = "Paso X de hotkeys:",
        label_y_step = "Paso Y de hotkeys:",
        label_rotation_step = "Paso de rotación de hotkeys:",
        label_hotkey_rotation_mode = "Rotación de hotkeys:",
        label_hotkey_pivot_mode = "Pivote de hotkeys:",
        posing_custom = "Transformar selección",
        posing_x_plus = "Mover X +%s",
        posing_x_minus = "Mover X -%s",
        posing_y_plus = "Mover Y +%s",
        posing_y_minus = "Mover Y -%s",
        posing_rotation_plus = "Rotar Z +%s",
        posing_rotation_minus = "Rotar Z -%s",
        makeup_insert = "Insertar preset",
        makeup_save_style = "Guardar estilo",
        makeup_save_group = "Guardar grupo",
        makeup_save_both = "Guardar ambos",
        makeup_delete = "Eliminar preset",
        rotation_group = "Conjunto seleccionado",
        rotation_individual = "Cada línea sobre su centro",
        pivot_center = "Centro de la selección",
        pivot_first = "Primera línea",
        pivot_custom = "Personalizado",
        insert_create = "Crear desde destinos",
        insert_replace = "Reemplazar capas seleccionadas",
        hint_pivot = "El resize usa este pivote: -40 deja 60 %. Los grados positivos giran en sentido antihorario.",
        hint_insert = "El modo de inserción solo se aplica a presets [TAG].",
        no_presets = "(sin presets)",
        button_makeup = "Makeup",
        button_posing = "Posing",
        button_config = "Config",
        button_help = "Ayuda",
        button_cancel = "Cancelar",
        button_save = "Guardar",
        button_ok = "OK",
        button_yes = "Sí",
        button_no = "No",
        save_subtitle = "Guarda primero el archivo de subtítulos.",
        library_error = "Error de biblioteca\n%s",
        enter_name = "Escribe un nombre.",
        replace_presets = "¿Reemplazar %s?",
        save_failed = "No se pudo guardar\n%s",
        saved = "Guardado: %s",
        select_preset = "Selecciona un preset.",
        delete_confirm = "¿Eliminar %s?",
        delete_failed = "No se pudo eliminar\n%s",
        load_failed = "No se pudo cargar\n%s",
        insert_failed = "No se pudo insertar\n%s",
        config_invalid_steps = "Los pasos de hotkeys deben ser números mayores que cero.",
        undo_makeup = "Allure - Makeup: %s",
        undo_posing = "Allure - Posing",
    },
}

local helpTexts = {
    en = [[ALLURE - USER GUIDE

Posing:
Transform selection applies translation, relative Z rotation, and uniform
relative resize to the complete selected sign stack. Resize -40 produces 60%
of the current size. It preserves the shared geometry of \pos, both \move
endpoints, \org, rectangular or vector \clip/\iclip, drawings, and implicit
positions. Group rotation and every resize use the selected group pivot. A
moving line with a clip needs \org before individual rotation because it has no
fixed pivot.

The six quick actions use the X, Y, and rotation steps saved in Config. The same
steps power the assignable commands under : Kite Hotkeys :/Allure/Posing.

Makeup:
Insert restores a [TAG] adaptive style preset or an exact [GROUP] sign stack.
Save style, Save group, Save both, and Delete preset are Action choices instead
of dialog buttons. Presets remain in the Makeup library beside the subtitle.

Config:
Stores the language, three hotkey steps, hotkey rotation mode, and hotkey pivot.
Positive Z values rotate counterclockwise.]],
    es = [[ALLURE - GUÍA DE USO

Posing:
Transformar selección aplica traslación, rotación Z relativa y resize uniforme
a todo el cartel seleccionado. Un resize de -40 deja 60 % del tamaño actual.
Conserva la geometría compartida de \pos, ambos extremos de \move, \org,
\clip/\iclip rectangulares o vectoriales, dibujos y posiciones implícitas. La
rotación del conjunto y todo resize usan el pivote elegido. Una línea con
movimiento y clip necesita \org para rotarse individualmente, pues no tiene un
pivote fijo.

Las seis acciones rápidas usan los pasos X, Y y de rotación guardados en Config.
Los mismos pasos alimentan los comandos asignables de
: Kite Hotkeys :/Allure/Posing.

Makeup:
Insertar restaura un preset adaptativo [TAG] o un cartel exacto [GROUP]. Guardar
estilo, Guardar grupo, Guardar ambos y Eliminar preset son opciones de Acción en
vez de botones. Los presets permanecen en la biblioteca de Makeup junto al
subtítulo.

Config:
Guarda el idioma, los tres pasos de hotkeys, su modo de rotación y su pivote.
Los valores Z positivos giran en sentido antihorario.]],
}

local currentLanguage = "en"

local function L(key, ...)
    local language = TEXT[currentLanguage] or TEXT.en
    local value = language[key] or TEXT.en[key] or key
    if select("#", ...) > 0 then return string.format(value, ...) end
    return value
end

local function sectionTitle(key)
    return "=== " .. L(key) .. " ==="
end

local configDefaults = {
    language = "en",
    x_step = 10,
    y_step = 10,
    rotation_step = 10,
    hotkey_rotation_mode = "group",
    hotkey_pivot_mode = "center",
    hotkey_pivot_x = 0,
    hotkey_pivot_y = 0,
}

local configHandler, configLoaded
local currentConfig = {}

local function copyDefaults()
    return KiteCore.copy(configDefaults)
end

local function normalizeConfig(values)
    local normalized = copyDefaults()
    for key in pairs(normalized) do
        if values and values[key] ~= nil then normalized[key] = values[key] end
    end
    if normalized.language ~= "es" then normalized.language = "en" end
    normalized.x_step = KiteCore.finiteNumber(normalized.x_step) or configDefaults.x_step
    normalized.y_step = KiteCore.finiteNumber(normalized.y_step) or configDefaults.y_step
    normalized.rotation_step = KiteCore.finiteNumber(normalized.rotation_step) or configDefaults.rotation_step
    if normalized.x_step <= 0 then normalized.x_step = configDefaults.x_step end
    if normalized.y_step <= 0 then normalized.y_step = configDefaults.y_step end
    if normalized.rotation_step <= 0 then normalized.rotation_step = configDefaults.rotation_step end
    if normalized.hotkey_rotation_mode ~= "individual" then normalized.hotkey_rotation_mode = "group" end
    if normalized.hotkey_pivot_mode ~= "first" and normalized.hotkey_pivot_mode ~= "custom" then
        normalized.hotkey_pivot_mode = "center"
    end
    normalized.hotkey_pivot_x = KiteCore.finiteNumber(normalized.hotkey_pivot_x) or 0
    normalized.hotkey_pivot_y = KiteCore.finiteNumber(normalized.hotkey_pivot_y) or 0
    return normalized
end

local function loadConfig()
    if configLoaded then return currentConfig end
    local section = {}
    for key, value in pairs(configDefaults) do
        section[key] = { value = value, config = true, name = key, class = "edit" }
    end
    configHandler = KiteUI.dialogHandler({ main = section }, script_namespace, script_version, {
        { path = "?user/allure_config.json", format = "json_sections" },
    })
    local handle = io.open(configHandler.fileName, "r")
    if handle then handle:close() else configHandler:write() end
    configHandler:read()
    currentConfig = normalizeConfig(configHandler.configuration.main)
    for key, value in pairs(currentConfig) do configHandler.configuration.main[key] = value end
    currentLanguage = currentConfig.language
    configLoaded = true
    return currentConfig
end

local function saveConfig(values)
    currentConfig = normalizeConfig(values)
    for key, value in pairs(currentConfig) do configHandler.configuration.main[key] = value end
    currentLanguage = currentConfig.language
    configHandler:write()
end

local function notice(message, buttons)
    return KiteUI.message(message, {buttons=buttons or {L("button_ok")}})
end

local function confirm(message)
    return notice(message, { L("button_yes"), L("button_no") }) == L("button_yes")
end

local posingErrorEn = {
    ["No se pudo procesar un bloque de tags."] = "Could not process an override-tag block.",
    ["Hay un tag con paréntesis incompletos."] = "An override tag has unbalanced parentheses.",
    ["El tag \\move debe tener cuatro o seis valores numéricos."] = "The \\move tag must contain four or six numeric values.",
    ["El clip vectorial contiene datos que no se pudieron interpretar."] = "The vector clip contains data that could not be parsed.",
    ["El clip no es rectangular ni un vector ASS compatible."] = "The clip is neither rectangular nor a compatible ASS vector.",
    ["El clip vectorial tiene una cantidad inválida de coordenadas."] = "The vector clip has an invalid coordinate count.",
    ["No se puede rotar exactamente un clip rectangular animado dentro de \\t; hornéalo FBF primero."] = "An animated rectangular clip inside \\t cannot be rotated exactly; bake it frame by frame first.",
    ["Hay un tag \\frz sin un valor numerico."] = "A \\frz tag has no numeric value.",
    ["No se pudo obtener PlayResX/PlayResY para calcular la posición implícita."] = "PlayResX/PlayResY is unavailable, so the implicit position cannot be calculated.",
    ["La línea contiene \\pos y \\move a la vez; deja una sola posición antes de transformarla."] = "The line contains both \\pos and \\move; keep only one position before transforming it.",
    ["El pivote personalizado necesita X e Y numéricos."] = "The custom pivot requires numeric X and Y values.",
    ["No se pudo calcular el centro del conjunto."] = "The center of the selection could not be calculated.",
    ["Una línea con \\move y clip necesita \\org para conservar un pivote único al rotar; hornéala FBF o agrega el origen."] = "A line with \\move and a clip needs \\org to keep one rotation pivot; bake it frame by frame or add the origin.",
    ["El resize relativo debe dejar un tamaño mayor que cero."] = "Relative resize must leave a size greater than zero.",
    ["Introduce un desplazamiento, una rotación o un resize distintos de cero."] = "Enter a non-zero translation, rotation, or resize.",
    ["Selecciona al menos una línea de diálogo."] = "Select at least one dialogue line.",
}

local function translatePosingError(message)
    message = tostring(message or "Error desconocido.")
    if currentLanguage == "es" then return message end
    local line, detail = message:match("^Línea (%d+): (.*)$")
    if line then return "Line " .. line .. ": " .. translatePosingError(detail) end
    local tag = message:match("^El tag \\([^ ]+) debe tener dos coordenadas numéricas%.$")
    if tag then return "The \\" .. tag .. " tag must contain two numeric coordinates." end
    local scaleTag = message:match("^Hay un tag \\(fsc[xy]) sin un valor numérico%.$")
    if scaleTag then return "The \\" .. scaleTag .. " tag has no numeric value." end
    local command = message:match("^El clip vectorial contiene el comando no compatible '(.)'%.$")
    if command then return "The vector clip contains the unsupported command '" .. command .. "'." end
    return posingErrorEn[message] or message
end

local makeupErrorEs = {
    ["Select at least one dialogue line."] = "Selecciona al menos una línea de diálogo.",
    ["The selection has no reusable text layer. Use Save group for drawing-only signs."] = "La selección no tiene una capa de texto reutilizable. Usa Guardar grupo para carteles formados solo por dibujos.",
    ["The preset has no lines."] = "El preset no contiene líneas.",
    ["Unknown preset type."] = "El tipo de preset es desconocido.",
    ["The preset has no name."] = "El preset no tiene nombre.",
    ["The preset contains an invalid line."] = "El preset contiene una línea no válida.",
    ["An exact group is missing line text."] = "A un grupo exacto le falta el texto de una línea.",
    ["Select at least one target line."] = "Selecciona al menos una línea de destino.",
    ["Each layer group must be contiguous."] = "Cada grupo de capas debe ser contiguo.",
    ["Choose Create from targets or Replace selected layers."] = "Elige Crear desde destinos o Reemplazar capas seleccionadas.",
    ["Each target group must be contiguous."] = "Cada grupo de destino debe ser contiguo.",
    ["JSON encoder returned no text"] = "El codificador JSON no devolvió texto.",
    ["library folder is empty"] = "La carpeta de la biblioteca está vacía.",
    ["invalid preset identifier"] = "El identificador del preset no es válido.",
    ["This is not a valid Makeup library index."] = "Este no es un índice válido de la biblioteca de Makeup.",
    ["Preset data is missing."] = "Faltan los datos del preset.",
    ["Enter a preset name."] = "Escribe un nombre para el preset.",
    ["The preset is no longer indexed."] = "El preset ya no figura en el índice.",
    ["The selected file is not a valid Makeup preset."] = "El archivo seleccionado no es un preset válido de Makeup.",
    ["Preset index and data do not match."] = "El índice y los datos del preset no coinciden.",
    ["The filesystem returned no error details."] = "El sistema de archivos no devolvió detalles del error.",
}

local makeupPrefixEs = {
    ["Could not read the library index"] = "No se pudo leer el índice de la biblioteca",
    ["Could not write the library index"] = "No se pudo escribir el índice de la biblioteca",
    ["Could not create the preset folder"] = "No se pudo crear la carpeta de presets",
    ["Could not write the preset"] = "No se pudo escribir el preset",
    ["Could not read the preset"] = "No se pudo leer el preset",
    ["Index updated; one orphaned file remains"] = "El índice se actualizó, pero queda un archivo huérfano",
}

local function translateMakeupError(message)
    message = tostring(message or "")
    if currentLanguage ~= "es" then return message end
    if makeupErrorEs[message] then return makeupErrorEs[message] end
    for english, spanish in pairs(makeupPrefixEs) do
        if message:sub(1, #english) == english then
            message = spanish .. message:sub(#english + 1)
            break
        end
    end
    message = message:gsub("The filesystem returned no error details%.", makeupErrorEs["The filesystem returned no error details."])
    return message
end

local Posing = createPosing(
    function(message) notice(translatePosingError(message)) end,
    function() aegisub.set_undo_point(L("undo_posing")) end)

local labelPrefix = { adaptive = "[TAG] ", exact = "[GROUP] " }

local function libraryFolder()
    local folder = LineOps.subtitleFolder(true)
    if folder then return folder end
    return nil, L("save_subtitle")
end

local function indexedItems(index)
    local items, entries = {}, {}
    for _, entry in ipairs(index and index.entries or {}) do
        local label = (labelPrefix[entry.kind] or "[?] ") .. entry.name
        items[#items + 1], entries[label] = label, entry
    end
    if #items == 0 then items[1] = L("no_presets") end
    return items, entries
end

local function saveKinds(subs, selection, active, folder, index, name, kinds)
    name = LineOps.trim(name)
    if name == "" then return nil, L("enter_name") end
    local presets, replacing = {}, {}
    for _, kind in ipairs(kinds) do
        local preset, captureError = AllureCore.capturePreset(subs, selection, active, name, kind)
        if not preset then return nil, translateMakeupError(captureError) end
        presets[#presets + 1] = preset
        if Store.findEntry(index, name, kind) then replacing[#replacing + 1] = labelPrefix[kind] .. name end
    end
    local conjunction = currentLanguage == "es" and " y " or " and "
    if #replacing > 0 and not confirm(L("replace_presets", table.concat(replacing, conjunction))) then return false end
    local saved = {}
    for _, preset in ipairs(presets) do
        local entry, saveError = Store.save(folder, preset)
        if not entry then return nil, translateMakeupError(saveError) end
        saved[#saved + 1] = labelPrefix[entry.kind] .. entry.name
    end
    return saved
end

local function optionData(keys, labelFunction)
    local items, toKey, toLabel = {}, {}, {}
    for _, key in ipairs(keys) do
        local label = labelFunction and labelFunction(key) or L(key)
        items[#items + 1] = label
        toKey[label], toLabel[key] = key, label
    end
    return items, toKey, toLabel
end

local posingActions = { "posing_custom", "posing_x_plus", "posing_x_minus", "posing_y_plus", "posing_y_minus", "posing_rotation_plus", "posing_rotation_minus" }
local makeupActions = { "makeup_insert", "makeup_save_style", "makeup_save_group", "makeup_save_both", "makeup_delete" }
local rotationModes = { "rotation_group", "rotation_individual" }
local pivotModes = { "pivot_center", "pivot_first", "pivot_custom" }
local insertModes = { "insert_create", "insert_replace" }

local function posingActionLabel(key)
    local amount = currentConfig.x_step
    if key == "posing_y_plus" or key == "posing_y_minus" then amount = currentConfig.y_step end
    if key == "posing_rotation_plus" or key == "posing_rotation_minus" then amount = currentConfig.rotation_step end
    return L(key, formatNumber(amount))
end

local function rotationKey(value)
    return value == "rotation_individual" and "individual" or "group"
end

local function pivotKey(value)
    if value == "pivot_first" then return "first" end
    if value == "pivot_custom" then return "custom" end
    return "center"
end

local function engineConfig(values)
    local rotationMode = values.rotation_mode == "individual" and Posing.rotation_modes.individual or Posing.rotation_modes.group
    local pivotMode = Posing.pivot_modes[values.pivot_mode] or Posing.pivot_modes.center
    return {
        dx = values.dx,
        dy = values.dy,
        rotation = values.rotation,
        resize = values.resize,
        rotation_mode = rotationMode,
        pivot_mode = pivotMode,
        pivot_x = values.pivot_x,
        pivot_y = values.pivot_y,
    }
end

local function posingValues(action, state, hotkey)
    local values = {
        dx = tonumber(state.dx) or 0,
        dy = tonumber(state.dy) or 0,
        rotation = tonumber(state.rotation) or 0,
        resize = tonumber(state.resize) or 0,
        rotation_mode = hotkey and currentConfig.hotkey_rotation_mode or rotationKey(state.rotation_mode),
        pivot_mode = hotkey and currentConfig.hotkey_pivot_mode or pivotKey(state.pivot_mode),
        pivot_x = hotkey and currentConfig.hotkey_pivot_x or state.pivot_x,
        pivot_y = hotkey and currentConfig.hotkey_pivot_y or state.pivot_y,
    }
    if action ~= "posing_custom" then values.dx, values.dy, values.rotation, values.resize = 0, 0, 0, 0 end
    if action == "posing_x_plus" then values.dx = currentConfig.x_step
    elseif action == "posing_x_minus" then values.dx = -currentConfig.x_step
    elseif action == "posing_y_plus" then values.dy = currentConfig.y_step
    elseif action == "posing_y_minus" then values.dy = -currentConfig.y_step
    elseif action == "posing_rotation_plus" then values.rotation = currentConfig.rotation_step
    elseif action == "posing_rotation_minus" then values.rotation = -currentConfig.rotation_step end
    return engineConfig(values)
end

local function runMakeup(subs, selection, active, state, index, byLabel, folder, folderError, indexError)
    if not folder then notice(folderError); return selection end
    if not index then notice(L("library_error", translateMakeupError(indexError))); return selection end
    local saveMap = {
        makeup_save_style = { "adaptive" },
        makeup_save_group = { "exact" },
        makeup_save_both = { "adaptive", "exact" },
    }
    local kinds = saveMap[state.makeup_action]
    if kinds then
        local saved, saveError = saveKinds(subs, selection, active, folder, index, state.name, kinds)
        if saved == nil then notice(L("save_failed", tostring(saveError)))
        elseif saved ~= false then
            local conjunction = currentLanguage == "es" and " y " or " and "
            notice(L("saved", table.concat(saved, conjunction)))
        end
        return selection
    end
    local entry = byLabel[state.preset]
    if not entry then notice(L("select_preset")); return selection end
    if state.makeup_action == "makeup_delete" then
        local label = (labelPrefix[entry.kind] or "") .. entry.name
        if not confirm(L("delete_confirm", label)) then return selection end
        local removed, removeError = Store.remove(folder, entry)
        if not removed then notice(L("delete_failed", translateMakeupError(removeError)))
        elseif removeError then notice(translateMakeupError(removeError)) end
        return selection
    end
    local preset, loadError = Store.load(folder, entry)
    if not preset then notice(L("load_failed", translateMakeupError(loadError))); return selection end
    local mode = state.insert_mode == "insert_replace" and "replace" or "create"
    local newSelection, applyError = AllureCore.applyPreset(subs, selection, active, preset, mode)
    if not newSelection then notice(L("insert_failed", translateMakeupError(applyError))); return selection end
    aegisub.set_undo_point(L("undo_makeup", entry.name))
    return newSelection, true
end

local function configGui()
    local languageItems, languageMap, languageLabels = optionData({ "en", "es" }, function(key)
        return key == "es" and "Español" or "English"
    end)
    local rotationItems, rotationMap, rotationLabels = optionData(rotationModes)
    local pivotItems, pivotMap, pivotLabels = optionData(pivotModes)
    local values = currentConfig
    local dialog = {
        { class = "label", label = sectionTitle("button_config"), x = 0, y = 0, width = 8, height = 1 },
        { class = "label", label = L("label_language"), x = 0, y = 1, width = 3, height = 1 },
        { class = "dropdown", name = "language", items = languageItems, value = languageLabels[values.language], x = 3, y = 1, width = 5, height = 1 },
        { class = "label", label = L("label_x_step"), x = 0, y = 2, width = 3, height = 1 },
        { class = "floatedit", name = "x_step", value = values.x_step, min = 0, x = 3, y = 2, width = 2, height = 1 },
        { class = "label", label = L("label_y_step"), x = 0, y = 3, width = 3, height = 1 },
        { class = "floatedit", name = "y_step", value = values.y_step, min = 0, x = 3, y = 3, width = 2, height = 1 },
        { class = "label", label = L("label_rotation_step"), x = 0, y = 4, width = 3, height = 1 },
        { class = "floatedit", name = "rotation_step", value = values.rotation_step, min = 0, x = 3, y = 4, width = 2, height = 1 },
        { class = "label", label = L("label_hotkey_rotation_mode"), x = 0, y = 5, width = 3, height = 1 },
        { class = "dropdown", name = "hotkey_rotation_mode", items = rotationItems, value = rotationLabels[values.hotkey_rotation_mode == "individual" and "rotation_individual" or "rotation_group"], x = 3, y = 5, width = 5, height = 1 },
        { class = "label", label = L("label_hotkey_pivot_mode"), x = 0, y = 6, width = 3, height = 1 },
        { class = "dropdown", name = "hotkey_pivot_mode", items = pivotItems, value = pivotLabels[values.hotkey_pivot_mode == "first" and "pivot_first" or values.hotkey_pivot_mode == "custom" and "pivot_custom" or "pivot_center"], x = 3, y = 6, width = 5, height = 1 },
        { class = "label", label = L("label_pivot_x"), x = 0, y = 7, width = 2, height = 1 },
        { class = "floatedit", name = "hotkey_pivot_x", value = values.hotkey_pivot_x, x = 2, y = 7, width = 2, height = 1 },
        { class = "label", label = L("label_pivot_y"), x = 4, y = 7, width = 2, height = 1 },
        { class = "floatedit", name = "hotkey_pivot_y", value = values.hotkey_pivot_y, x = 6, y = 7, width = 2, height = 1 },
    }
    while true do
        local button, result = aegisub.dialog.display(dialog, { L("button_save"), L("button_cancel") },
            {ok = L("button_save"), close = L("button_cancel")})
        if button ~= L("button_save") then return false end
        local xStep = KiteCore.finiteNumber(result.x_step)
        local yStep = KiteCore.finiteNumber(result.y_step)
        local rotationStep = KiteCore.finiteNumber(result.rotation_step)
        if xStep and xStep > 0 and yStep and yStep > 0 and rotationStep and rotationStep > 0 then
            result.language = languageMap[result.language]
            result.hotkey_rotation_mode = rotationKey(rotationMap[result.hotkey_rotation_mode])
            result.hotkey_pivot_mode = pivotKey(pivotMap[result.hotkey_pivot_mode])
            saveConfig(result)
            return true
        end
        for _, control in ipairs(dialog) do
            if control.name then control.value = result[control.name] end
        end
        notice(L("config_invalid_steps"))
    end
end

local function main(subs, selection, active)
    loadConfig()
    local state = {
        posing_action = "posing_custom",
        dx = 0,
        dy = 0,
        rotation = 0,
        resize = 0,
        rotation_mode = "rotation_group",
        pivot_mode = "pivot_center",
        pivot_x = 0,
        pivot_y = 0,
        makeup_action = "makeup_insert",
        preset = nil,
        name = "",
        insert_mode = "insert_create",
    }
    while true do
        local folder, folderError = libraryFolder()
        local index, indexError
        if folder then index, indexError = Store.loadIndex(folder) end
        local presetItems, byLabel = indexedItems(index)
        if not state.preset or not byLabel[state.preset] then state.preset = presetItems[1] end
        local posingItems, posingMap, posingLabels = optionData(posingActions, posingActionLabel)
        local makeupItems, makeupMap, makeupLabels = optionData(makeupActions)
        local rotationItems, rotationMap, rotationLabels = optionData(rotationModes)
        local pivotItems, pivotMap, pivotLabels = optionData(pivotModes)
        local insertItems, insertMap, insertLabels = optionData(insertModes)
        local dialog = {
            { class = "label", label = sectionTitle("section_posing"), x = 0, y = 0, width = 8, height = 1 },
            { class = "label", label = L("label_action"), x = 0, y = 1, width = 2, height = 1 },
            { class = "dropdown", name = "posing_action", items = posingItems, value = posingLabels[state.posing_action], x = 2, y = 1, width = 6, height = 1 },
            { class = "label", label = L("label_move_x"), x = 0, y = 2, width = 1, height = 1 },
            { class = "floatedit", name = "dx", value = state.dx, x = 1, y = 2, width = 1, height = 1 },
            { class = "label", label = L("label_move_y"), x = 2, y = 2, width = 1, height = 1 },
            { class = "floatedit", name = "dy", value = state.dy, x = 3, y = 2, width = 1, height = 1 },
            { class = "label", label = L("label_rotation"), x = 4, y = 2, width = 2, height = 1 },
            { class = "floatedit", name = "rotation", value = state.rotation, x = 6, y = 2, width = 2, height = 1 },
            { class = "label", label = L("label_resize"), x = 0, y = 3, width = 2, height = 1 },
            { class = "floatedit", name = "resize", value = state.resize, x = 2, y = 3, width = 2, height = 1 },
            { class = "label", label = L("label_rotation_mode"), x = 0, y = 4, width = 2, height = 1 },
            { class = "dropdown", name = "rotation_mode", items = rotationItems, value = rotationLabels[state.rotation_mode], x = 2, y = 4, width = 6, height = 1 },
            { class = "label", label = L("label_pivot_mode"), x = 0, y = 5, width = 2, height = 1 },
            { class = "dropdown", name = "pivot_mode", items = pivotItems, value = pivotLabels[state.pivot_mode], x = 2, y = 5, width = 6, height = 1 },
            { class = "label", label = L("label_pivot_x"), x = 0, y = 6, width = 1, height = 1 },
            { class = "floatedit", name = "pivot_x", value = state.pivot_x, x = 1, y = 6, width = 2, height = 1 },
            { class = "label", label = L("label_pivot_y"), x = 4, y = 6, width = 1, height = 1 },
            { class = "floatedit", name = "pivot_y", value = state.pivot_y, x = 5, y = 6, width = 2, height = 1 },
            { class = "label", label = L("hint_pivot"), x = 0, y = 7, width = 8, height = 1 },
            { class = "label", label = sectionTitle("section_makeup"), x = 0, y = 9, width = 8, height = 1 },
            { class = "label", label = L("label_action"), x = 0, y = 10, width = 2, height = 1 },
            { class = "dropdown", name = "makeup_action", items = makeupItems, value = makeupLabels[state.makeup_action], x = 2, y = 10, width = 6, height = 1 },
            { class = "label", label = L("label_preset"), x = 0, y = 11, width = 2, height = 1 },
            { class = "dropdown", name = "preset", items = presetItems, value = state.preset, x = 2, y = 11, width = 6, height = 1 },
            { class = "label", label = L("label_name"), x = 0, y = 12, width = 2, height = 1 },
            { class = "edit", name = "name", value = state.name, x = 2, y = 12, width = 6, height = 1 },
            { class = "label", label = L("label_insert_mode"), x = 0, y = 13, width = 2, height = 1 },
            { class = "dropdown", name = "insert_mode", items = insertItems, value = insertLabels[state.insert_mode], x = 2, y = 13, width = 6, height = 1 },
            { class = "label", label = L("hint_insert"), x = 0, y = 14, width = 8, height = 1 },
        }
        local button, result = aegisub.dialog.display(dialog, {
            L("button_makeup"), L("button_posing"), L("button_config"), L("button_help"), L("button_cancel")
        }, {close = L("button_cancel")})
        if not button or button == L("button_cancel") then return selection end
        state.posing_action = posingMap[result.posing_action] or state.posing_action
        state.makeup_action = makeupMap[result.makeup_action] or state.makeup_action
        state.rotation_mode = rotationMap[result.rotation_mode] or state.rotation_mode
        state.pivot_mode = pivotMap[result.pivot_mode] or state.pivot_mode
        state.insert_mode = insertMap[result.insert_mode] or state.insert_mode
        state.preset = result.preset
        state.name = result.name
        state.dx, state.dy, state.rotation, state.resize = result.dx, result.dy, result.rotation, result.resize
        state.pivot_x, state.pivot_y = result.pivot_x, result.pivot_y
        if button == L("button_help") then
            aegisub.dialog.display({
                { class = "textbox", text = helpTexts[currentLanguage] or helpTexts.en, x = 0, y = 0, width = 70, height = 22 },
            }, { L("button_ok") })
        elseif button == L("button_config") then
            configGui()
        elseif button == L("button_posing") then
            return Posing.applyTransform(subs, selection, posingValues(state.posing_action, state, false))
        elseif button == L("button_makeup") then
            local updated, applied = runMakeup(subs, selection, active, state, index, byLabel, folder, folderError, indexError)
            if applied then return updated, updated[1] end
        end
    end
end

local function posingHotkey(action)
    return function(subs, selection)
        loadConfig()
        local state = { dx = 0, dy = 0, rotation = 0, resize = 0,
            rotation_mode = "rotation_group", pivot_mode = "pivot_center", pivot_x = 0, pivot_y = 0 }
        return Posing.applyTransform(subs, selection, posingValues(action, state, true))
    end
end

local HOTKEY_PATH = ": Kite Hotkeys :/" .. script_name
local function hotkeyPath(section, action)
    return HOTKEY_PATH .. "/" .. section .. "/" .. action
end

local Allure = {
    version = script_version,
    main = main,
}

depRec:registerMacros({
    { script_name, script_description, main },
    { hotkeyPath("Makeup", "Open"), "Open the Makeup section", main },
    { hotkeyPath("Posing", "Open"), "Open the Posing section", main },
    { hotkeyPath("Posing", "Move X +"), "Move the selected sign right by the configured X step", posingHotkey("posing_x_plus") },
    { hotkeyPath("Posing", "Move X -"), "Move the selected sign left by the configured X step", posingHotkey("posing_x_minus") },
    { hotkeyPath("Posing", "Move Y +"), "Move the selected sign down by the configured Y step", posingHotkey("posing_y_plus") },
    { hotkeyPath("Posing", "Move Y -"), "Move the selected sign up by the configured Y step", posingHotkey("posing_y_minus") },
    { hotkeyPath("Posing", "Rotate Z +"), "Rotate the selected sign by the configured positive step", posingHotkey("posing_rotation_plus") },
    { hotkeyPath("Posing", "Rotate Z -"), "Rotate the selected sign by the configured negative step", posingHotkey("posing_rotation_minus") },
}, false)

require("kite.UI").publishActions()

return Allure
