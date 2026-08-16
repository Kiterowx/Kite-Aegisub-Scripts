script_name = "MakeupnPosing"
script_description = "Reusable ASS styling and rigid sign posing"
script_author = "Kiterow"
script_version = "1.0.0"
script_namespace = "kite.MakeupnPosing"

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
        { "kite.LineOps", version = "1.5.3",
          url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
        { "kite.PyBridge", version = "1.4.5",
          url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
        { "l0.dkjson", version = "0.8.0",
          url = "https://github.com/TypesettingTools/DependencyControl",
          feed = "https://raw.githubusercontent.com/TypesettingTools/DependencyControl/master/DependencyControl.json" },
        { "aegisub.re" },
        { "kite.UI", version = "1.1.2",
          url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
    },
})
local LineOps, PyBridge, json, Re, KiteUI = depRec:requireModules()
local Makeup = { version = "2.1.3" }
local Core, Store = {}, {}

local STYLE_FIELDS = {
    "fontname", "fontsize",
    "color1", "color2", "color3", "color4",
    "bold", "italic", "underline", "strikeout",
    "scale_x", "scale_y", "spacing", "angle",
    "borderstyle", "outline", "shadow", "align",
    "margin_l", "margin_r", "margin_t", "margin_v", "encoding", "relative_to",
}

local NUMERIC_STYLE_FIELDS = {
    fontsize = true, scale_x = true, scale_y = true, spacing = true, angle = true,
    borderstyle = true, outline = true, shadow = true, align = true,
    margin_l = true, margin_r = true, margin_t = true, margin_v = true, encoding = true,
    relative_to = true,
}

local BOOLEAN_STYLE_FIELDS = {
    bold = true, italic = true, underline = true, strikeout = true,
}

local PROTECTED_GEOMETRY = {
    pos = true, move = true, org = true,
    clip = true, iclip = true,
    an = true, _persp = true,
}

local NUM_PATTERN = "([%+%-]?%d*%.?%d+)"
local GEOMETRY_POINT_TAGS = { pos = 1, org = 1, move = 2, _persp = 4 }
local CLIP_TAGS = { clip = true, iclip = true }
local PHRASE_SEPARATORS = {
    ["."] = true, ["!"] = true, ["?"] = true, [":"] = true, [";"] = true,
    ["："] = true, ["；"] = true,
}
local SEMANTIC_LEVELS = {
    { key = "token", field = "tokens", signature = true },
    { key = "punctuation", field = "punctuation", exact = true },
    { key = "word", field = "words" },
    { key = "phrase", field = "phrases" },
}
local PATTERN_SCOPES = {
    { name = "punctuation", field = "punctuation", include_first = true },
    { name = "word", field = "words" },
    { name = "phrase", field = "phrases" },
    { name = "structure", field = "tokens", sparse = true },
}

local trim = LineOps.trim
local parse_tag_tokens = LineOps.overrideTokens

local function is_dialogue(line)
    return type(line) == "table" and (line.class == nil or line.class == "dialogue")
end

local clone_table = LineOps.deepCopy

local function clone_line(line)
    if type(line) == "table" and type(line.copy) == "function" then
        return line:copy()
    end
    return clone_table(line)
end

local function format_number(value)
    local number = tonumber(value) or 0
    if math.abs(number) < 0.0000001 then number = 0 end
    if number == math.floor(number) then return string.format("%d", number) end
    local formatted = string.format("%.3f", number):gsub("0+$", "")
    formatted = formatted:gsub("%.$", "")
    return formatted
end

local function value_type(value)
    local kind = type(value)
    if kind == "boolean" then return "b", value and "1" or "0" end
    if kind == "number" then return "n", tostring(value) end
    return "s", tostring(value or "")
end

local function regex_find(text, pattern)
    local ok, matches = pcall(Re.find, tostring(text or ""), pattern)
    if ok and type(matches) == "table" then return matches end
    return nil
end

local function regex_has(text, pattern)
    local matches = regex_find(text, pattern)
    return matches ~= nil and #matches > 0
end

local function visible_units(text)
    return LineOps.graphemes(text, Re)
end

local function unit_codepoint(unit)
    if unit == "\\N" or unit == "\\n" or unit == "\\h" then return nil end
    return LineOps.firstCodepoint(unit)
end

local function is_space_unit(unit)
    unit = tostring(unit or "")
    return unit == "\\h" or unit:match("^%s+$") ~= nil or regex_has(unit, "^\\p{Z}+$")
end

local function is_break_unit(unit)
    return unit == "\\N" or unit == "\\n"
end

local function is_punctuation_unit(unit)
    if is_break_unit(unit) or is_space_unit(unit) then return false end
    if #unit == 1 and unit:match("^%p$") then return true end
    if regex_has(unit, "^\\p{P}+$") then return true end
    local codepoint = unit_codepoint(unit)
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

local function phrase_break_unit(unit)
    if is_break_unit(unit) then return true end
    return PHRASE_SEPARATORS[unit]
        or LineOps.isSentenceTerminal(unit)
end

local function analyze_structure(plain)
    local structure = {
        units = visible_units(plain),
        tokens = {},
        words = {},
        phrases = {},
        punctuation = {},
    }
    structure.length = #structure.units

    local position = 1
    while position <= structure.length do
        local unit = structure.units[position]
        local kind = is_break_unit(unit) and "break"
            or (is_space_unit(unit) and "space")
            or (is_punctuation_unit(unit) and "punct")
            or "word"
        local last = position
        if kind == "word" or kind == "space" then
            while last + 1 <= structure.length do
                local next_unit = structure.units[last + 1]
                local same = kind == "word"
                    and not is_break_unit(next_unit)
                    and not is_space_unit(next_unit)
                    and not is_punctuation_unit(next_unit)
                if kind == "space" then
                    same = is_space_unit(next_unit) and not is_break_unit(next_unit)
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

    local phrase_start = 0
    for index, unit in ipairs(structure.units) do
        if phrase_break_unit(unit) then
            structure.phrases[#structure.phrases + 1] = {
                kind = "phrase", start = phrase_start, finish = index,
            }
            phrase_start = index
        end
    end
    if phrase_start < structure.length or #structure.phrases == 0 then
        structure.phrases[#structure.phrases + 1] = {
            kind = "phrase", start = phrase_start, finish = structure.length,
        }
    end

    local signature = {}
    for _, token in ipairs(structure.tokens) do signature[#signature + 1] = token.kind:sub(1, 1) end
    structure.signature = table.concat(signature)
    return structure
end

local function span_anchor(spans, offset)
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

local function is_span_start(spans, offset)
    for _, span in ipairs(spans or {}) do
        if span.start == offset then return true end
    end
    return false
end

local function semantic_anchor(structure, offset)
    offset = math.max(0, math.min(tonumber(offset) or 0, structure.length or 0))
    local anchor = {
        offset = offset,
        ratio = structure.length > 0 and offset / structure.length or 0,
    }
    for _, level in ipairs(SEMANTIC_LEVELS) do
        local spans = structure[level.field] or {}
        local index, ratio = span_anchor(spans, offset)
        anchor[level.key .. "_index"] = index
        anchor[level.key .. "_ratio"] = ratio
        if level.exact then anchor[level.key .. "_exact"] = is_span_start(spans, offset) end
    end
    return anchor
end

local function infer_pattern_scope(program, structure)
    local offsets, seen = {}, {}
    for _, block in ipairs(program or {}) do
        local offset = tonumber(block.offset) or 0
        if offset > 0 and offset < structure.length and not seen[offset] then
            offsets[#offsets + 1], seen[offset] = offset, true
        end
    end
    if #offsets == 0 then return "percent" end

    if structure.length > 1 and #offsets >= structure.length - 1 then return "char" end
    for _, branch in ipairs(PATTERN_SCOPES) do
        local spans = structure[branch.field] or {}
        local matches = #spans > 0
        for _, offset in ipairs(offsets) do
            if not is_span_start(spans, offset) then matches = false break end
        end
        local minimum = branch.include_first and #spans or math.max(1, #spans - 1)
        if matches and (branch.sparse or #offsets >= minimum) then return branch.name end
    end
    return "percent"
end

local function mapped_span_offset(spans, index, ratio)
    local span = spans[math.max(1, math.min(tonumber(index) or 1, #spans))]
    if not span then return nil end
    ratio = math.max(0, math.min(tonumber(ratio) or 0, 1))
    return math.floor(span.start + (span.finish - span.start) * ratio + 0.5)
end

local function map_semantic_anchor(anchor, source, target)
    if type(anchor) ~= "table" or anchor.offset == nil then
        anchor = semantic_anchor(source, 0)
    end
    if anchor.offset <= 0 then return 0 end
    if anchor.offset >= (source.length or 0) then return target.length or 0 end

    local mapped
    for _, branch in ipairs(SEMANTIC_LEVELS) do
        local source_spans = source[branch.field] or {}
        local target_spans = target[branch.field] or {}
        local compatible = #source_spans > 0 and #source_spans == #target_spans
        if branch.signature then compatible = compatible and source.signature == target.signature end
        if branch.exact then compatible = compatible and anchor[branch.key .. "_exact"] end
        if compatible then
            mapped = mapped_span_offset(target_spans,
                anchor[branch.key .. "_index"], anchor[branch.key .. "_ratio"])
            if mapped ~= nil then break end
        end
    end
    if mapped == nil and source.length == target.length then mapped = anchor.offset end
    if mapped == nil then mapped = math.floor((anchor.ratio or 0) * target.length + 0.5) end
    return math.max(0, math.min(mapped, target.length))
end

local function split_tag_program(text)
    local program, plain = {}, {}
    local visible_count = 0
    for _, section in ipairs(LineOps.scanSections(text)) do
        if section.type == "override" then
            program[#program + 1] = { offset = visible_count, content = section.text }
        elseif section.type == "text" or section.type == "drawing" then
            plain[#plain + 1] = section.text
            visible_count = visible_count + #visible_units(section.text)
        end
    end

    local plain_text = table.concat(plain)
    local structure = analyze_structure(plain_text)
    for _, block in ipairs(program) do
        block.anchor = semantic_anchor(structure, block.offset)
    end
    return program, visible_count, plain_text, structure
end

local function tag_program_only(text)
    local program = {}
    for _, section in ipairs(LineOps.overrideBlocks(text)) do
        program[#program + 1] = { offset = 0, content = section.text }
    end
    return program
end

local function remove_program_names(program, names)
    local result = {}
    for _, block in ipairs(program or {}) do
        local pieces, cursor = {}, 1
        for _, token in ipairs(parse_tag_tokens(block.content)) do
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
                anchor = clone_table(block.anchor),
            }
        end
    end
    return result
end

local function collect_protected(program)
    local result = { present = {}, tokens = {} }
    for _, block in ipairs(program or {}) do
        for _, token in ipairs(parse_tag_tokens(block.content)) do
            if PROTECTED_GEOMETRY[token.name] then
                result.present[token.name] = true
                result.tokens[#result.tokens + 1] = token.raw
            end
        end
    end
    return result
end

local function program_has_name(program, name)
    for _, block in ipairs(program or {}) do
        for _, token in ipairs(parse_tag_tokens(block.content)) do
            if token.name == name then return true end
        end
    end
    return false
end

local function inject_program_prefix(program, payload)
    if not payload or payload == "" then return program end
    local result = clone_table(program or {})
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

local function overlay_target_geometry(source_program, target_program)
    local target = collect_protected(target_program)
    if #target.tokens == 0 then return source_program end

    local remove = {}
    for name in pairs(target.present) do remove[name] = true end
    if target.present.pos or target.present.move then
        remove.pos, remove.move = true, true
    end
    local result = remove_program_names(source_program, remove)
    return inject_program_prefix(result, table.concat(target.tokens))
end

local function inherit_missing_geometry(source_program, target_program, inherit_alignment)
    local target = collect_protected(target_program)
    local payload = {}
    if inherit_alignment and target.present.an then
        source_program = remove_program_names(source_program, { an = true })
    end
    local source_has_position = program_has_name(source_program, "pos")
        or program_has_name(source_program, "move")

    for _, raw in ipairs(target.tokens) do
        local token = parse_tag_tokens(raw)[1]
        if token then
            local missing
            if token.name == "pos" or token.name == "move" then
                missing = not source_has_position
            else
                missing = not program_has_name(source_program, token.name)
            end
            if missing then payload[#payload + 1] = raw end
        end
    end
    return inject_program_prefix(source_program, table.concat(payload))
end

local function shift_pair(x, y, dx, dy, scale)
    scale = scale or 1
    return format_number((tonumber(x) or 0) + dx * scale),
        format_number((tonumber(y) or 0) + dy * scale)
end

local function map_drawing_coordinates(path, scale, mapper)
    local factor, count = 2 ^ ((tonumber(scale) or 1) - 1), 0
    local mapped = tostring(path or ""):gsub(NUM_PATTERN .. "%s+" .. NUM_PATTERN, function(x, y)
        local next_x, next_y = mapper((tonumber(x) or 0) / factor, (tonumber(y) or 0) / factor)
        count = count + 1
        return format_number(next_x * factor) .. " " .. format_number(next_y * factor)
    end)
    return mapped, count
end

local function map_clip_call(call, mapper)
    local arguments = LineOps.splitArguments(call.value)
    if #arguments == 4 then
        local values = {}
        for index = 1, 4 do values[index] = tonumber(arguments[index]) end
        if values[1] and values[2] and values[3] and values[4] then
            local x1, y1 = mapper(values[1], values[2])
            local x2, y2 = mapper(values[3], values[4])
            return "\\" .. call.raw_name .. "(" .. table.concat({
                format_number(x1), format_number(y1), format_number(x2), format_number(y2),
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
    local mapped, count = map_drawing_coordinates(path, scale, mapper)
    if count == 0 then return nil end
    return "\\" .. call.raw_name .. "(" .. (scale and scale .. "," or "") .. mapped .. ")"
end

local function map_geometry_calls(content, mapper, point_tags)
    local names = clone_table(CLIP_TAGS)
    for name in pairs(point_tags or {}) do names[name] = true end
    local wrapped = "{" .. tostring(content or "") .. "}"
    wrapped = LineOps.mapTagCalls(wrapped, names, function(call)
        if CLIP_TAGS[call.name] then return map_clip_call(call, mapper) end
        local pair_count = point_tags and point_tags[call.name]
        if not pair_count then return nil end
        local arguments = LineOps.splitArguments(call.value)
        if #arguments < pair_count * 2 then return nil end
        for pair = 1, pair_count do
            local index = pair * 2 - 1
            local x, y = tonumber(arguments[index]), tonumber(arguments[index + 1])
            if not x or not y then return nil end
            x, y = mapper(x, y)
            arguments[index], arguments[index + 1] = format_number(x), format_number(y)
        end
        return "\\" .. call.raw_name .. "(" .. table.concat(arguments, ",") .. ")"
    end, { top_level_only = false })
    return wrapped:sub(2, -2)
end

local function translate_geometry(content, dx, dy)
    if dx == 0 and dy == 0 then return tostring(content or "") end
    return map_geometry_calls(content, function(x, y) return x + dx, y + dy end, GEOMETRY_POINT_TAGS)
end

local function translate_program(program, dx, dy)
    local result = {}
    for _, block in ipairs(program or {}) do
        result[#result + 1] = {
            offset = block.offset,
            content = translate_geometry(block.content, dx, dy),
            anchor = clone_table(block.anchor),
        }
    end
    return result
end

local function translate_geometry_text(text, dx, dy)
    return (tostring(text or ""):gsub("{([^}]*)}", function(content)
        if not content:find("\\", 1, true) then return "{" .. content .. "}" end
        return "{" .. translate_geometry(content, dx, dy) .. "}"
    end))
end

local function first_program_point(program)
    for _, block in ipairs(program or {}) do
        local x, y = block.content:match("\\pos%(%s*" .. NUM_PATTERN .. "%s*,%s*" .. NUM_PATTERN .. "%s*%)")
        if x and y then return tonumber(x), tonumber(y) end
    end
    for _, block in ipairs(program or {}) do
        local x, y = block.content:match("\\move%(%s*" .. NUM_PATTERN .. "%s*,%s*" .. NUM_PATTERN)
        if x and y then return tonumber(x), tonumber(y) end
    end
    return nil, nil
end

local function first_program_tag_value(program, name)
    for _, block in ipairs(program or {}) do
        for _, token in ipairs(parse_tag_tokens(block.content)) do
            if token.name == name then return trim(token.value) end
        end
    end
    return nil
end

local function collect_script_info(subs)
    local x, y = LineOps.scriptResolution(subs)
    if (not x or not y) and aegisub and type(aegisub.video_size) == "function" then
        local ok, video_x, video_y = pcall(aegisub.video_size)
        if ok then x, y = x or tonumber(video_x), y or tonumber(video_y) end
    end
    return { play_res_x = x or 384, play_res_y = y or 288 }
end

local function copy_style(style)
    local result = {}
    for key, value in pairs(style or {}) do
        if type(value) ~= "function" then result[key] = value end
    end
    return result
end

local function apply_style_block(state, content, base_style, styles)
    for _, token in ipairs(parse_tag_tokens(content)) do
        local name = tostring(token.name or ""):lower()
        local value = trim(token.value)
        if name == "r" then
            state = copy_style((value ~= "" and styles[value]) or base_style)
        elseif name == "fn" then
            state.fontname = value ~= "" and value or base_style.fontname
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

local function text_extent(style, text)
    text = tostring(text or ""):gsub("\\h", " ")
    if aegisub and aegisub.text_extents then
        local ok, width, height, descent, extlead = pcall(aegisub.text_extents, style, text)
        if ok and tonumber(width) and tonumber(height) then
            return math.max(0, tonumber(width) or 0),
                math.max(1, (tonumber(height) or 0) + (tonumber(descent) or 0)
                    + (tonumber(extlead) or 0))
        end
    end
    local count = #visible_units(text)
    local size = tonumber(style and style.fontsize) or 40
    local scale_x = (tonumber(style and style.scale_x) or 100) / 100
    local scale_y = (tonumber(style and style.scale_y) or 100) / 100
    local spacing = tonumber(style and style.spacing) or 0
    return math.max(1, count * size * 0.55 * scale_x + math.max(0, count - 1) * spacing),
        math.max(1, size * scale_y)
end

local function measure_program_text(plain, program, base_style, styles)
    local units = visible_units(plain)
    local at_offset = {}
    for _, block in ipairs(program or {}) do
        local offset = math.max(0, math.min(tonumber(block.offset) or 0, #units))
        at_offset[offset] = at_offset[offset] or {}
        at_offset[offset][#at_offset[offset] + 1] = block.content
    end

    local state = copy_style(base_style)
    local width, line_width, height, line_height = 0, 0, 0, 0
    local segment = {}
    local function flush_segment()
        if #segment == 0 then return end
        local segment_width, segment_height = text_extent(state, table.concat(segment))
        line_width = line_width + segment_width
        line_height = math.max(line_height, segment_height)
        segment = {}
    end
    local function line_break()
        flush_segment()
        width = math.max(width, line_width)
        height = height + math.max(1, line_height)
        line_width, line_height = 0, 0
    end

    for offset = 0, #units do
        if at_offset[offset] then
            flush_segment()
            for _, content in ipairs(at_offset[offset]) do
                state = apply_style_block(state, content, base_style, styles)
            end
        end
        if offset < #units then
            local unit = units[offset + 1]
            if is_break_unit(unit) then line_break() else segment[#segment + 1] = unit end
        end
    end
    flush_segment()
    width = math.max(width, line_width)
    height = height + math.max(1, line_height)
    return math.max(1, width), math.max(1, height), tonumber(state.align) or tonumber(base_style.align) or 2
end

local function default_line_anchor(line, style, info, alignment)
    alignment = tonumber(alignment) or tonumber(style and style.align) or 2
    local margin_l = tonumber(line and line.margin_l) or 0
    local margin_r = tonumber(line and line.margin_r) or 0
    local margin_t = tonumber(line and (line.margin_t or line.margin_v)) or 0
    if margin_l == 0 then margin_l = tonumber(style and style.margin_l) or 0 end
    if margin_r == 0 then margin_r = tonumber(style and style.margin_r) or 0 end
    if margin_t == 0 then
        margin_t = tonumber(style and (style.margin_t or style.margin_v)) or 0
    end

    local horizontal = alignment % 3
    local x = horizontal == 1 and margin_l
        or (horizontal == 2 and info.play_res_x / 2 or info.play_res_x - margin_r)
    local vertical = math.ceil(alignment / 3)
    local y = vertical == 3 and margin_t
        or (vertical == 2 and info.play_res_y / 2 or info.play_res_y - margin_t)
    return x, y
end

local function line_anchor_position(line, program, style, info, alignment)
    local x, y = first_program_point(program)
    if x then return x, y end
    return default_line_anchor(line, style, info, alignment)
end

local function point_to_box(x, y, alignment, width, height)
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

local function text_box_for_line(line, plain, program, style, styles, info)
    style = style or {}
    local width, height, alignment = measure_program_text(plain, program, style, styles)
    local explicit_alignment = tonumber(first_program_tag_value(program, "an"))
    alignment = explicit_alignment or tonumber(style.align) or alignment or 2
    local x, y = line_anchor_position(line, program, style, info, alignment)
    local box = point_to_box(x, y, alignment, width, height)
    box.anchor_x, box.anchor_y, box.alignment = x, y, alignment
    return box
end

local function clip_box_from_program(program)
    for _, block in ipairs(program or {}) do
        for _, token in ipairs(parse_tag_tokens(block.content)) do
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
                    local scale_text, path = args:match("^%s*(%d+)%s*,%s*(.*)$")
                    if not path then path = args end
                    local factor = 2 ^ ((tonumber(scale_text) or 1) - 1)
                    local points = {}
                    tostring(path or ""):gsub(NUM_PATTERN .. "%s+" .. NUM_PATTERN, function(x, y)
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

local function union_box(boxes)
    local result
    for _, box in ipairs(boxes or {}) do
        if box then
            if not result then
                result = clone_table(box)
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

local function boxes_overlap(left, right)
    if not left or not right then return false end
    local width = math.max(0, math.min(left.right, right.right) - math.max(left.left, right.left))
    local height = math.max(0, math.min(left.bottom, right.bottom) - math.max(left.top, right.top))
    return width > 0 and height > 0
end

local function detect_clip_families(preset)
    local groups = {}
    for _, line in ipairs(preset.lines or {}) do
        line.clip_rect, line.clip_kind = clip_box_from_program(line.program)
        if line.slot > 0 and line.clip_rect and line.clip_kind == "rect" then
            groups[line.slot] = groups[line.slot] or {}
            groups[line.slot][#groups[line.slot] + 1] = line
        elseif line.slot > 0 and line.clip_rect and line.source_box
            and boxes_overlap(line.clip_rect, line.source_box)
            and line.clip_rect.width <= line.source_box.width * 2.5
            and line.clip_rect.height <= line.source_box.height * 2.5 then
            line.clip_relative = true
            line.clip_source_box = clone_table(line.source_box)
            line.clip_family = "vector-box"
        end
    end

    for _, lines in pairs(groups) do
        local rects = {}
        for _, line in ipairs(lines) do rects[#rects + 1] = line.clip_rect end
        local union = union_box(rects)
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
                line.clip_source_box = clone_table(union)
                line.clip_family = horizontal >= vertical and "horizontal" or "vertical"
            elseif line.source_box and boxes_overlap(line.clip_rect, line.source_box)
                and line.clip_rect.width <= line.source_box.width * 2.5
                and line.clip_rect.height <= line.source_box.height * 2.5 then
                line.clip_relative = true
                line.clip_source_box = clone_table(line.source_box)
                line.clip_family = "box"
            end
        end
    end
end

local function map_box_coordinate(value, source_min, source_size, target_min, target_size)
    if math.abs(source_size or 0) < 0.000001 then return value end
    return target_min + (value - source_min) / source_size * target_size
end

local function affine_remap_clips(content, source, target)
    if not source or not target then return content end
    return map_geometry_calls(content, function(x, y)
        return map_box_coordinate(x, source.left, source.width, target.left, target.width),
            map_box_coordinate(y, source.top, source.height, target.top, target.height)
    end)
end

local function remap_translated_program_clips(program, clip_source_box, target_box, dx, dy)
    if not clip_source_box or not target_box then return program end
    local shifted_source = clone_table(clip_source_box)
    shifted_source.left, shifted_source.right =
        shifted_source.left + dx, shifted_source.right + dx
    shifted_source.top, shifted_source.bottom =
        shifted_source.top + dy, shifted_source.bottom + dy
    local result = {}
    for _, block in ipairs(program or {}) do
        result[#result + 1] = {
            offset = block.offset,
            anchor = clone_table(block.anchor),
            content = affine_remap_clips(block.content, shifted_source, target_box),
        }
    end
    return result
end

local function rewrite_reset_content(content, resolved_styles)
    local pieces, cursor = {}, 1
    for _, token in ipairs(parse_tag_tokens(content)) do
        if token.name == "r" then
            local source_name = trim(token.value)
            local target_name = resolved_styles[source_name]
            if source_name ~= "" and target_name and target_name ~= source_name then
                pieces[#pieces + 1] = content:sub(cursor, token.start_position - 1)
                pieces[#pieces + 1] = "\\r" .. target_name
                cursor = token.end_position + 1
            end
        end
    end
    pieces[#pieces + 1] = content:sub(cursor)
    return table.concat(pieces)
end

local function rewrite_style_resets(program, resolved_styles)
    local result = {}
    for _, block in ipairs(program or {}) do
        result[#result + 1] = {
            offset = block.offset,
            content = rewrite_reset_content(block.content, resolved_styles),
            anchor = clone_table(block.anchor),
        }
    end
    return result
end

local function rewrite_style_resets_text(text, resolved_styles)
    return (tostring(text or ""):gsub("{([^}]*)}", function(content)
        if not content:find("\\", 1, true) then return "{" .. content .. "}" end
        return "{" .. rewrite_reset_content(content, resolved_styles) .. "}"
    end))
end

local function pattern_boundaries(structure, scope)
    local boundaries = {}
    if scope == "char" then
        for offset = 1, math.max(0, structure.length - 1) do boundaries[#boundaries + 1] = offset end
        return boundaries
    end
    for _, branch in ipairs(PATTERN_SCOPES) do
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

local function mapped_program(program, source, target, scope)
    local result = {}
    local source_boundaries = pattern_boundaries(source, scope)
    local target_boundaries = pattern_boundaries(target, scope)
    local inline, source_boundary_set = {}, {}
    for _, offset in ipairs(source_boundaries) do source_boundary_set[offset] = true end
    if #source_boundaries > 0 and #target_boundaries > 0
        and (source.length ~= target.length or #source_boundaries ~= #target_boundaries) then
        for _, block in ipairs(program or {}) do
            if source_boundary_set[tonumber(block.offset) or 0] then inline[#inline + 1] = block end
        end
    end

    if #inline > 0 then
        for _, block in ipairs(program or {}) do
            if not source_boundary_set[tonumber(block.offset) or 0] then
                local copy = clone_table(block)
                copy.offset = map_semantic_anchor(block.anchor, source, target)
                result[#result + 1] = copy
            end
        end
        for index, offset in ipairs(target_boundaries) do
            local ratio = #target_boundaries > 1 and (index - 1) / (#target_boundaries - 1) or 0
            local source_index = math.floor(ratio * math.max(0, #inline - 1) + 1.5)
            source_index = math.max(1, math.min(source_index, #inline))
            result[#result + 1] = {
                offset = offset,
                content = inline[source_index].content,
                anchor = semantic_anchor(target, offset),
            }
        end
    else
        for _, block in ipairs(program or {}) do
            local copy = clone_table(block)
            copy.offset = map_semantic_anchor(block.anchor, source, target)
            result[#result + 1] = copy
        end
    end

    for index, block in ipairs(result) do block._makeup_order = index end
    table.sort(result, function(left, right)
        local left_offset, right_offset = tonumber(left.offset) or 0, tonumber(right.offset) or 0
        if left_offset == right_offset then
            return (left._makeup_order or 0) < (right._makeup_order or 0)
        end
        return left_offset < right_offset
    end)
    for _, block in ipairs(result) do block._makeup_order = nil end
    return result
end

local function render_program(program, source_structure, target_plain, scope)
    local target = analyze_structure(target_plain)
    local source = type(source_structure) == "table" and source_structure or {
        length = tonumber(source_structure) or 0,
        tokens = {}, words = {}, phrases = {}, punctuation = {}, signature = "",
    }
    local insertions = {}

    for _, block in ipairs(mapped_program(program, source, target, scope or "percent")) do
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

local function is_drawing_program(program)
    for _, block in ipairs(program or {}) do
        for _, token in ipairs(parse_tag_tokens(block.content)) do
            if token.name == "p" and (tonumber(token.value) or 0) > 0 then return true end
        end
    end
    return false
end

local function visible_key(plain)
    return trim(tostring(plain or ""):gsub("\\[Nnh]", " "):gsub("%s+", " "))
end

local function collect_styles(subs)
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

local function simple_hash(value)
    local hash = 5381
    value = tostring(value or "")
    for position = 1, #value do
        hash = (hash * 33 + value:byte(position)) % 2147483647
    end
    return string.format("%08x", hash)
end

local function style_fingerprint(snapshot)
    local material = {}
    for _, field in ipairs(STYLE_FIELDS) do
        local value = snapshot.fields and snapshot.fields[field]
        if value ~= nil then
            local kind, raw = value_type(value)
            material[#material + 1] = field .. "=" .. kind .. ":" .. raw
        end
    end
    return simple_hash(table.concat(material, "\31"))
end

local function snapshot_style(style)
    local snapshot = { name = tostring(style and style.name or ""), fields = {} }
    for _, field in ipairs(STYLE_FIELDS) do
        if style and style[field] ~= nil then snapshot.fields[field] = style[field] end

    end
    snapshot.fingerprint = style_fingerprint(snapshot)
    return snapshot
end

local function remember_style(preset, styles, name)
    name = trim(name)
    if name == "" or preset.styles_by_name[name] then return end
    local snapshot = snapshot_style(styles[name])
    snapshot.name = name
    preset.styles[#preset.styles + 1] = snapshot
    preset.styles_by_name[name] = snapshot
end


local function capture_safe_extra(line)
    local extra = {}
    if type(line.extra) == "table" then
        local value = line.extra["_aegi_perspective_ambient_plane"]
        if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
            extra["_aegi_perspective_ambient_plane"] = value
        end
    end
    return extra
end

local function capture_preset(subs, selection, active, name, kind)
    kind = kind == "exact" and "exact" or "adaptive"
    local indices = LineOps.normalizeIndices(subs, selection, is_dialogue)
    if #indices == 0 then return nil, "Select at least one dialogue line." end

    local anchor = 1
    for ordinal, index in ipairs(indices) do
        if index == active then anchor = ordinal break end
    end

    local styles = collect_styles(subs)
    local script_info = collect_script_info(subs)
    local preset = {
        name = trim(name),
        kind = kind,
        anchor = anchor,
        slot_count = 0,
        styles = {},
        styles_by_name = {},
        lines = {},
    }
    local slot_by_text = {}
    local anchor_line = subs[indices[anchor]]
    local anchor_layer = tonumber(anchor_line.layer) or 0
    local anchor_start = tonumber(anchor_line.start_time) or 0
    local anchor_end = tonumber(anchor_line.end_time) or 0

    for ordinal, index in ipairs(indices) do
        local line = subs[index]
        local program, source_length, plain, structure
        if kind == "exact" then
            program = tag_program_only(line.text)
            if not is_drawing_program(program) then
                program, source_length, plain, structure = split_tag_program(line.text)
            else
                source_length, plain = 0, ""
                structure = {
                    length = 0, tokens = {}, words = {}, phrases = {}, punctuation = {}, signature = "",
                }
            end
        else
            program, source_length, plain, structure = split_tag_program(line.text)
        end
        local drawing = is_drawing_program(program)
        local slot = 0
        if not drawing then
            local key = visible_key(plain)
            if key ~= "" then
                if not slot_by_text[key] then
                    preset.slot_count = preset.slot_count + 1
                    slot_by_text[key] = preset.slot_count
                end
                slot = slot_by_text[key]
            end
        end

        local style_name = tostring(line.style or "Default")
        remember_style(preset, styles, style_name)
        for _, block in ipairs(program) do
            for _, token in ipairs(parse_tag_tokens(block.content)) do
                if token.name == "r" and trim(token.value) ~= "" then
                    remember_style(preset, styles, token.value)
                end
            end
        end

        local source_box
        if not drawing then
            source_box = text_box_for_line(
                line, plain, program, styles[style_name] or {}, styles, script_info)
        end
        local alignment = tonumber(first_program_tag_value(program, "an"))
            or tonumber((styles[style_name] or {}).align) or 2
        local source_anchor_x, source_anchor_y = line_anchor_position(
            line, program, styles[style_name] or {}, script_info, alignment)
        local style_snapshot = preset.styles_by_name[style_name]
        local captured = {
            ordinal = ordinal,
            style = style_name,
            layer = tonumber(line.layer) or 0,
            layer_delta = (tonumber(line.layer) or 0) - anchor_layer,
            start_delta = (tonumber(line.start_time) or 0) - anchor_start,
            end_delta = (tonumber(line.end_time) or 0) - anchor_end,
            duration = math.max(0, (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0)),
            margin_l = tonumber(line.margin_l) or 0,
            margin_r = tonumber(line.margin_r) or 0,
            margin_t = tonumber(line.margin_t) or 0,
            source_box = source_box,
            source_anchor = { x = source_anchor_x, y = source_anchor_y, alignment = alignment },
            drawing = drawing,
        }
        if kind == "exact" then
            captured.exact_text = tostring(line.text or "")
            captured.event = {
                actor = tostring(line.actor or ""),
                effect = tostring(line.effect or ""),
                comment = line.comment and true or false,
                extra = clone_table(line.extra or {}),
            }
        else
            captured.slot = slot
            captured.source_length = source_length
            captured.source_structure = structure
            captured.pattern_scope = infer_pattern_scope(program, structure)
            captured.source_style_fingerprint = style_snapshot and style_snapshot.fingerprint or ""
            captured.drawing_text = drawing and plain or ""
            captured.program = program
            captured.extra = capture_safe_extra(line)
        end
        preset.lines[#preset.lines + 1] = captured
    end

    if kind == "adaptive" and preset.slot_count == 0 then
        return nil, "The selection has no reusable text layer. Use Save group for drawing-only signs."
    end
    if kind == "adaptive" then detect_clip_families(preset) end
    return preset
end

local function hydrate_preset(preset)
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
        if style.fingerprint == "" then style.fingerprint = style_fingerprint(style) end
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

local function style_values_equal(field, left, right)
    if BOOLEAN_STYLE_FIELDS[field] then
        local function boolean_value(value)
            if type(value) == "boolean" then return value end
            local number = tonumber(value)
            if number ~= nil then return number ~= 0 end
            return tostring(value or ""):lower() == "true"
        end
        return boolean_value(left) == boolean_value(right)
    end
    if NUMERIC_STYLE_FIELDS[field] then
        local left_number, right_number = tonumber(left), tonumber(right)
        return left_number and right_number and math.abs(left_number - right_number) < 0.000001
    end
    return tostring(left or "") == tostring(right or "")
end

local function styles_equal(existing, snapshot)
    if not existing or not snapshot then return false end
    for field, value in pairs(snapshot.fields or {}) do
        if not style_values_equal(field, existing[field], value) then return false end
    end
    return next(snapshot.fields or {}) ~= nil
end

local function style_from_snapshot(snapshot, name)
    local style = { class = "style", name = name }
    for field, value in pairs(snapshot.fields or {}) do style[field] = value end
    return style
end

local function ensure_preset_styles(subs, preset)
    local styles = collect_styles(subs)
    local resolved, additions = {}, {}
    local reserved = {}
    for name in pairs(styles) do reserved[name] = true end

    for _, snapshot in ipairs(preset.styles or {}) do
        local original = snapshot.name
        local fingerprint = snapshot.fingerprint ~= "" and snapshot.fingerprint
            or style_fingerprint(snapshot)
        local matching_name
        for existing_name, existing in pairs(styles) do
            if styles_equal(existing, snapshot) then
                matching_name = existing_name
                if existing_name == original then break end
            end
        end
        if styles_equal(styles[original], snapshot) then
            resolved[original] = original
        elseif matching_name then
            resolved[original] = matching_name
        elseif next(snapshot.fields or {}) == nil then
            resolved[original] = styles[original] and original or nil
        elseif not styles[original] then
            resolved[original] = original
            additions[#additions + 1] = style_from_snapshot(snapshot, original)
            styles[original] = additions[#additions]
            reserved[original] = true
        else
            local stem = original .. " [Makeup " .. fingerprint .. "]"
            local candidate, number = stem, 2
            while reserved[candidate] and not styles_equal(styles[candidate], snapshot) do
                candidate = stem .. " " .. tostring(number)
                number = number + 1
            end
            resolved[original] = candidate
            if not reserved[candidate] then
                additions[#additions + 1] = style_from_snapshot(snapshot, candidate)
                styles[candidate] = additions[#additions]
                reserved[candidate] = true
            end
        end
    end

    if #additions == 0 then return resolved, nil, 0 end

    local insert_position, last_non_dialogue = 1, 0
    for index = 1, #subs do
        local class = subs[index] and subs[index].class
        if class == "style" then
            insert_position = index + 1
        elseif class ~= "dialogue" then
            last_non_dialogue = index
        end
    end
    if insert_position == 1 and last_non_dialogue > 0 then
        insert_position = last_non_dialogue + 1
    end
    for offset, style in ipairs(additions) do
        subs.insert(insert_position + offset - 1, style)
    end
    return resolved, insert_position, #additions
end

local function shift_plane_extra(value, dx, dy)
    local count = 0
    local shifted = tostring(value or ""):gsub(NUM_PATTERN .. "%s*;%s*" .. NUM_PATTERN, function(x, y)
        count = count + 1
        local next_x, next_y = shift_pair(x, y, dx, dy)
        return next_x .. ";" .. next_y
    end)
    if count >= 4 then return shifted end
    return value
end

local function line_plain(line)
    local program, length, plain = split_tag_program(line and line.text or "")
    return program, length, plain
end

local function effective_line_box(line, context)
    local program, _, plain = line_plain(line)
    local style = context.styles[tostring(line and line.style or "")] or {}
    return text_box_for_line(line, plain, program, style, context.styles, context.info)
end

local function slot_anchor_ordinals(preset)
    local result = {}
    local anchor_line = preset.lines[preset.anchor]
    if anchor_line and anchor_line.slot and anchor_line.slot > 0 then
        result[anchor_line.slot] = preset.anchor
    end
    for ordinal, line in ipairs(preset.lines) do
        if line.slot and line.slot > 0 and not result[line.slot] then result[line.slot] = ordinal end
    end
    return result
end

local function source_reference_line(preset, slot, slot_anchors)
    local ordinal = slot and slot > 0 and slot_anchors[slot] or preset.anchor
    return preset.lines[ordinal] or preset.lines[preset.anchor] or preset.lines[1]
end

local function source_geometry_reference(preset, slot, slot_anchors)
    local preferred = source_reference_line(preset, slot, slot_anchors)
    local x = preferred and first_program_point(preferred.program)

    if x then return preferred end
    if slot and slot > 0 then
        for _, line in ipairs(preset.lines) do
            if line.slot == slot and first_program_point(line.program) then return line end
        end
    end
    for _, line in ipairs(preset.lines) do
        if first_program_point(line.program) then return line end
    end
    return preferred
end

local function relative_margin(template_value, source_reference_value, target_value)
    return (tonumber(target_value) or 0)
        + (tonumber(template_value) or 0)
        - (tonumber(source_reference_value) or 0)
end

local function apply_template_to_line(template, target, options)
    local out = clone_line(target)
    local _, _, target_plain = line_plain(target)
    local program = translate_program(template.program, options.dx or 0, options.dy or 0)
    program = rewrite_style_resets(program, options.resolved_styles or {})

    local target_program = line_plain(target)
    if template.clip_relative then
        target_program = remove_program_names(target_program, { clip = true, iclip = true })
    end
    if options.overlay_geometry then
        program = overlay_target_geometry(program, target_program)
    else
        program = inherit_missing_geometry(
            program,
            options.inherit_geometry_program or target_program,
            options.inherit_alignment)
    end

    out.style = options.resolved_styles[template.style] or template.style or target.style
    if options.generated then
        out.layer = options.layer
        out.start_time = options.start_time
        out.end_time = options.end_time
        out.margin_l = options.margin_l
        out.margin_r = options.margin_r
        out.margin_t = options.margin_t
    end

    local plain = template.drawing and template.drawing_text or target_plain
    if template.clip_relative and options.context then
        local target_style = options.context.styles[tostring(out.style or "")] or {}
        local target_box = text_box_for_line(
            out, plain, program, target_style, options.context.styles, options.context.info)
        program = remap_translated_program_clips(
            program, template.clip_source_box or template.source_box, target_box,
            options.dx or 0, options.dy or 0)
    end
    out.text = render_program(
        program, template.source_structure or template.source_length, plain, template.pattern_scope)

    out.extra = clone_table(target.extra or {})
    local target_plane = out.extra["_aegi_perspective_ambient_plane"]
    local source_plane = template.extra and template.extra["_aegi_perspective_ambient_plane"]
    if not (options.overlay_geometry and target_plane ~= nil) and source_plane ~= nil then
        out.extra["_aegi_perspective_ambient_plane"] =
            shift_plane_extra(source_plane, options.dx or 0, options.dy or 0)
    end
    return out
end

local function template_anchor(template)
    if template and template.source_box then
        return template.source_box.anchor_x, template.source_box.anchor_y
    end
    if template and template.source_anchor then
        return tonumber(template.source_anchor.x), tonumber(template.source_anchor.y)
    end
    return template and first_program_point(template.program)
end

local function nonnegative_layer_shift(templates, target_layer)
    local base = tonumber(target_layer) or 0
    local minimum = base
    for _, template in ipairs(templates or {}) do
        minimum = math.min(minimum, base + (tonumber(template.layer_delta) or 0))
    end
    return minimum < 0 and -minimum or 0
end

local function build_generated_outputs(preset, targets, resolved_styles, context)
    local outputs = {}
    local slot_anchors = slot_anchor_ordinals(preset)
    local preset_anchor = preset.lines[preset.anchor] or preset.lines[1]
    local overall_target = targets[preset_anchor.slot] or targets[1]
    local layer_base = tonumber(overall_target.layer) or 0
    local layer_shift = nonnegative_layer_shift(preset.lines, layer_base)
    local overall_target_program = line_plain(overall_target)
    local overall_source_reference = source_reference_line(preset, preset_anchor.slot, slot_anchors)
    local overall_geometry_reference =
        source_geometry_reference(preset, preset_anchor.slot, slot_anchors)
    local overall_source_x, overall_source_y = template_anchor(overall_geometry_reference)
    local overall_target_box = effective_line_box(overall_target, context)
    local overall_target_x, overall_target_y =
        overall_target_box.anchor_x, overall_target_box.anchor_y
    local overall_dx, overall_dy = 0, 0
    if overall_source_x and overall_target_x then
        overall_dx, overall_dy = overall_target_x - overall_source_x, overall_target_y - overall_source_y
    end

    for ordinal, template in ipairs(preset.lines) do
        local target = targets[template.slot] or overall_target
        local target_program = line_plain(target)
        local source_reference = source_reference_line(preset, template.slot, slot_anchors)
        local geometry_reference = source_geometry_reference(preset, template.slot, slot_anchors)
        local source_x, source_y = template_anchor(geometry_reference)
        local target_box = effective_line_box(target, context)
        local target_x, target_y = target_box.anchor_x, target_box.anchor_y
        local dx, dy = overall_dx, overall_dy
        if source_x and target_x then dx, dy = target_x - source_x, target_y - source_y end

        local overlay = template.slot > 0 and slot_anchors[template.slot] == ordinal
        local template_alignment = first_program_tag_value(template.program, "an")
        local reference_alignment = first_program_tag_value(source_reference.program, "an")

        outputs[#outputs + 1] = apply_template_to_line(template, target, {
            resolved_styles = resolved_styles,
            context = context,
            dx = dx, dy = dy,
            overlay_geometry = overlay,
            inherit_geometry_program = template.slot > 0 and target_program or overall_target_program,
            inherit_alignment = template.slot > 0
                and template_alignment == reference_alignment,
            generated = true,
            layer = layer_base + (tonumber(template.layer_delta) or 0) + layer_shift,
            start_time = math.max(0, (tonumber(overall_target.start_time) or 0)
                + (tonumber(template.start_delta) or 0)),
            end_time = math.max(0, (tonumber(overall_target.end_time) or 0)
                + (tonumber(template.end_delta) or 0)),
            margin_l = relative_margin(template.margin_l, source_reference.margin_l, target.margin_l),
            margin_r = relative_margin(template.margin_r, source_reference.margin_r, target.margin_r),
            margin_t = relative_margin(template.margin_t, source_reference.margin_t, target.margin_t),
        })
    end
    return outputs
end

local function build_existing_outputs(preset, targets, resolved_styles, context)
    local outputs = {}
    local preset_anchor = preset.lines[preset.anchor] or preset.lines[1]
    local target_anchor = targets[preset.anchor] or targets[1]
    local source_anchor_x, source_anchor_y = template_anchor(preset_anchor)
    local target_anchor_box = effective_line_box(target_anchor, context)
    local target_anchor_x, target_anchor_y =
        target_anchor_box.anchor_x, target_anchor_box.anchor_y
    local fallback_dx, fallback_dy = 0, 0
    if source_anchor_x and target_anchor_x then
        fallback_dx = target_anchor_x - source_anchor_x
        fallback_dy = target_anchor_y - source_anchor_y
    end

    for ordinal, template in ipairs(preset.lines) do
        local target = targets[ordinal]
        local target_program = line_plain(target)
        local source_x, source_y = template_anchor(template)
        local target_box = effective_line_box(target, context)
        local target_x, target_y = target_box.anchor_x, target_box.anchor_y
        local dx, dy = fallback_dx, fallback_dy
        if source_x and target_x then dx, dy = target_x - source_x, target_y - source_y end
        outputs[#outputs + 1] = apply_template_to_line(template, target, {
            resolved_styles = resolved_styles,
            context = context,
            dx = dx, dy = dy,
            overlay_geometry = true,
            generated = false,
        })
    end
    return outputs
end

local function build_exact_outputs(preset, target, resolved_styles, context)
    local outputs = {}
    local anchor = preset.lines[preset.anchor] or preset.lines[1]
    local source_x, source_y = template_anchor(anchor)
    local target_box = effective_line_box(target, context)
    local dx, dy = 0, 0
    if source_x and source_y and target_box then
        dx, dy = target_box.anchor_x - source_x, target_box.anchor_y - source_y
    end
    local layer_base = tonumber(target.layer) or 0
    local layer_shift = nonnegative_layer_shift(preset.lines, layer_base)

    for _, template in ipairs(preset.lines) do
        local out = clone_line(target)
        local event = type(template.event) == "table" and template.event or {}
        out.class = "dialogue"
        out.comment = event.comment and true or false
        out.actor = tostring(event.actor or "")
        out.effect = tostring(event.effect or "")
        out.style = resolved_styles[template.style] or template.style or target.style
        out.layer = layer_base + (tonumber(template.layer_delta) or 0) + layer_shift
        out.start_time = tonumber(target.start_time) or 0
        out.end_time = tonumber(target.end_time) or out.start_time
        out.margin_l = relative_margin(template.margin_l, anchor.margin_l, target.margin_l)
        out.margin_r = relative_margin(template.margin_r, anchor.margin_r, target.margin_r)
        out.margin_t = relative_margin(template.margin_t, anchor.margin_t, target.margin_t)
        out.text = rewrite_style_resets_text(
            translate_geometry_text(template.exact_text, dx, dy), resolved_styles)
        out.extra = clone_table(type(event.extra) == "table" and event.extra or template.extra or {})
        local plane = out.extra["_aegi_perspective_ambient_plane"]
        if plane ~= nil then out.extra["_aegi_perspective_ambient_plane"] = shift_plane_extra(plane, dx, dy) end
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

local function chunk_indices(indices, size)
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

local function classify_units(subs, selection, preset, mode)
    local indices = LineOps.normalizeIndices(subs, selection, is_dialogue)
    if #indices == 0 then return nil, "Select at least one target line." end

    local line_count = #preset.lines
    local slot_count = math.max(1, tonumber(preset.slot_count) or 1)
    local units = {}

    if mode == "replace" then
        if line_count == 0 or #indices % line_count ~= 0 then
            return nil, string.format("Select a multiple of %d existing layers.", line_count)
        end
        for _, chunk in ipairs(chunk_indices(indices, line_count)) do
            if not contiguous(chunk) then return nil, "Each layer group must be contiguous." end
            units[#units + 1] = { kind = "existing", indices = chunk }
        end
        return units
    end

    if mode ~= "create" then return nil, "Choose Create from targets or Replace selected layers." end
    if slot_count == 1 then
        for _, index in ipairs(indices) do
            units[#units + 1] = { kind = "generated", indices = {index} }
        end
        return units
    end

    if #indices % slot_count ~= 0 then
        return nil, string.format("Select a multiple of %d target text lines.", slot_count)
    end
    for _, chunk in ipairs(chunk_indices(indices, slot_count)) do
        if not contiguous(chunk) then return nil, "Each target group must be contiguous." end
        units[#units + 1] = { kind = "generated", indices = chunk }
    end
    return units
end

local function apply_exact_preset(subs, selection, preset)
    local indices = LineOps.normalizeIndices(subs, selection, is_dialogue)
    if #indices == 0 then return nil, "Select at least one target line." end
    local resolved_styles, insert_position, added_styles = ensure_preset_styles(subs, preset)
    if added_styles > 0 then
        for position, index in ipairs(indices) do
            if index >= insert_position then indices[position] = index + added_styles end
        end
    end
    local context = { styles = collect_styles(subs), info = collect_script_info(subs) }
    local new_selection, cumulative_shift = {}, 0
    for _, index in ipairs(indices) do
        local current = index + cumulative_shift
        local outputs = build_exact_outputs(preset, subs[current], resolved_styles, context)
        subs.delete(current)
        for position, output in ipairs(outputs) do
            subs.insert(current + position - 1, output)
            new_selection[#new_selection + 1] = current + position - 1
        end
        cumulative_shift = cumulative_shift + #outputs - 1
    end
    return new_selection, nil, {
        styles_added = added_styles,
        lines_selected = #new_selection,
        groups = #indices,
    }
end

local function apply_preset(subs, selection, active, preset, mode)
    local hydrated, preset_error = hydrate_preset(preset)
    if not hydrated then return nil, preset_error end
    preset = hydrated
    if preset.kind == "exact" then return apply_exact_preset(subs, selection, preset) end
    local units, classify_err = classify_units(subs, selection, preset, mode or "create")
    if not units then return nil, classify_err end

    local resolved_styles, insert_position, added_styles = ensure_preset_styles(subs, preset)
    if added_styles > 0 then
        for _, unit in ipairs(units) do
            for position, index in ipairs(unit.indices) do
                if index >= insert_position then unit.indices[position] = index + added_styles end
            end
        end

        if active and active >= insert_position then active = active + added_styles end
    end
    local geometry_context = {
        styles = collect_styles(subs),
        info = collect_script_info(subs),
    }

    local new_selection, cumulative_shift = {}, 0
    for _, unit in ipairs(units) do
        local current_indices, targets = {}, {}
        for position, index in ipairs(unit.indices) do
            current_indices[position] = index + cumulative_shift
            targets[position] = subs[current_indices[position]]
        end

        local outputs
        if unit.kind == "existing" then
            outputs = build_existing_outputs(preset, targets, resolved_styles, geometry_context)
            for position, index in ipairs(current_indices) do
                subs[index] = outputs[position]
                new_selection[#new_selection + 1] = index
            end
        else
            local slot_targets = {}
            for slot, target in ipairs(targets) do slot_targets[slot] = target end
            outputs = build_generated_outputs(preset, slot_targets, resolved_styles, geometry_context)
            local first_index = current_indices[1]
            for position = #current_indices, 1, -1 do subs.delete(current_indices[position]) end
            for position, output in ipairs(outputs) do
                subs.insert(first_index + position - 1, output)
                new_selection[#new_selection + 1] = first_index + position - 1
            end
            cumulative_shift = cumulative_shift + #outputs - #current_indices
        end
    end

    return new_selection, nil, {
        styles_added = added_styles,
        lines_selected = #new_selection,
        groups = #units,
    }
end

Core.analyze_structure = analyze_structure
Core.semantic_anchor = semantic_anchor
Core.map_semantic_anchor = map_semantic_anchor
Core.infer_pattern_scope = infer_pattern_scope
Core.split_tag_program = split_tag_program
Core.parse_tag_tokens = parse_tag_tokens
Core.translate_geometry = translate_geometry
Core.affine_remap_clips = affine_remap_clips
Core.detect_clip_families = detect_clip_families
Core.render_program = render_program
Core.capture_preset = capture_preset
Core.hydrate_preset = hydrate_preset
Core.classify_units = classify_units
Core.apply_preset = apply_preset

local INDEX_FILE_NAME = "Makeup Library.index.json"
local DATA_DIRECTORY_NAME = "Makeup Library"
local INDEX_FORMAT = "kite.makeup.index"
local PRESET_FORMAT = "kite.makeup.preset"
local FORMAT_VERSION = 3

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
    local data = PyBridge.joinPath(folder, DATA_DIRECTORY_NAME)
    return {
        folder = folder,
        index = PyBridge.joinPath(folder, INDEX_FILE_NAME),
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
    if type(value) ~= "table" or value.format ~= INDEX_FORMAT or tonumber(value.version) ~= FORMAT_VERSION then
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
    return { format = INDEX_FORMAT, version = FORMAT_VERSION, entries = array(entries) }
end

local function emptyIndex()
    return { format = INDEX_FORMAT, version = FORMAT_VERSION, entries = array({}) }
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
    local identifier = existing and existing.id or uniqueIdentifier(index, name)
    local path, recordPathError = recordPath(libraryPaths, identifier)
    if not path then return nil, recordPathError end
    local record = {
        format = PRESET_FORMAT,
        version = FORMAT_VERSION,
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
        if not existing then PyBridge.removeFile(path) end
        return nil, indexError
    end
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
    if type(record) ~= "table" or record.format ~= PRESET_FORMAT
        or tonumber(record.version) ~= FORMAT_VERSION or type(record.payload) ~= "table" then
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

Store.INDEX_FILE_NAME = INDEX_FILE_NAME
Store.DATA_DIRECTORY_NAME = DATA_DIRECTORY_NAME
Store.FORMAT_VERSION = FORMAT_VERSION
Store.paths = paths
Store.loadIndex = loadIndex
Store.findEntry = findEntry
Store.save = save
Store.load = load
Store.remove = remove
Store.cleanCopy = cleanCopy

local function createPosing(showError, setUndoPoint)
    local NUM_PATTERN = "[%+%-]?%d*%.?%d+"
    local EPSILON = 0.0000001
    local ROTATE_GROUP = "Conjunto seleccionado"
    local ROTATE_INDIVIDUAL = "Cada línea sobre su centro"
    local PIVOT_CENTER = "Centro del conjunto"
    local PIVOT_FIRST = "Primera línea"
    local PIVOT_CUSTOM = "Personalizado"
    local ASS_TAG_NAMES = {
        "iclip", "clip", "xbord", "ybord", "xshad", "yshad", "fscx", "fscy",
        "alpha", "blur", "bord", "shad", "move", "fade", "frx", "fry", "frz", "fax", "fay",
        "pos", "org", "fad", "fsp", "fn", "fs", "be", "an", "fr", "ko", "kf", "kt",
        "1a", "2a", "3a", "4a", "1c", "2c", "3c", "4c", "c", "p", "b", "i", "u", "s", "r", "t", "q", "k", "K", "a"
    }

    local function trim(value)
        return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    end

    local function finite(value)
        value = tonumber(value)
        if not value or value ~= value or value == math.huge or value == -math.huge then
            return nil
        end
        return value
    end

    local function format_number(value, precision)
        value = finite(value) or 0
        if math.abs(value) < EPSILON then value = 0 end
        local text = string.format("%." .. tostring(precision or 3) .. "f", value)
        text = text:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
        if text == "-0" then text = "0" end
        return text
    end

    local function show_error(message)
        showError(message)
    end

    local function editable_selection(subs, sel)
        local indices, seen = {}, {}
        for _, value in ipairs(sel or {}) do
            local index = tonumber(value)
            if index and index == math.floor(index) and index >= 1 and index <= #subs and not seen[index] then
                local line = subs[index]
                if type(line) == "table" and line.class == "dialogue" and not line.comment then
                    seen[index] = true
                    indices[#indices + 1] = index
                end
            end
        end
        table.sort(indices)
        return indices
    end

    local function looks_like_override(inner)
        return tostring(inner or ""):match("^%s*\\") ~= nil
    end

    local function balanced_parenthesis_end(text, opening)
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

    local function tag_name_at(text, slash)
        local rest = text:sub(slash + 1)
        for _, name in ipairs(ASS_TAG_NAMES) do
            if rest:sub(1, #name) == name then
                return name, slash + 1 + #name
            end
        end
        local name = rest:match("^[1-4]?%a+")
        if not name then return nil end
        return name, slash + 1 + #name
    end

    local function map_override_blocks(text, callback)
        local failure
        local mapped = tostring(text or ""):gsub("%b{}", function(block)
            if failure then return block end
            local inner = block:sub(2, -2)
            if not looks_like_override(inner) then return block end
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

    local function scan_calls_in_inner(inner, callback)
        local index, depth = 1, 0
        while index <= #inner do
            local char = inner:sub(index, index)
            if char == "\\" then
                local name, name_end = tag_name_at(inner, index)
                if name then
                    local argument_start = name_end
                    while inner:sub(argument_start, argument_start):match("%s") do
                        argument_start = argument_start + 1
                    end
                    if inner:sub(argument_start, argument_start) == "(" then
                        local argument_end = balanced_parenthesis_end(inner, argument_start)
                        if not argument_end then
                            return nil, "Hay un tag con paréntesis incompletos."
                        end
                        local ok, err = callback(name:lower(), inner:sub(argument_start + 1, argument_end - 1), depth)
                        if ok == false then return nil, err end
                        if name:lower() ~= "t" then
                            index = argument_end + 1
                        else
                            index = index + 1
                        end
                    else
                        index = name_end
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

    local function analyze_text(text)
        local analysis = {has_clip = false}
        local failure
        local mapped, err = map_override_blocks(text, function(inner)
            local ok, scan_err = scan_calls_in_inner(inner, function(name, args, depth)
                if name == "clip" or name == "iclip" then
                    analysis.has_clip = true
                elseif depth == 0 and not analysis[name] and (name == "pos" or name == "move" or name == "org") then
                    analysis[name] = args
                end
                return true
            end)
            if not ok then return nil, scan_err end
            return inner
        end)
        if not mapped then failure = err end
        if failure then return nil, failure end
        return analysis
    end

    local function split_csv_numbers(arguments)
        local values = {}
        local start = 1
        local text = tostring(arguments or "")
        while true do
            local comma = text:find(",", start, true)
            local part = trim(text:sub(start, comma and comma - 1 or #text))
            if part == "" or not part:match("^" .. NUM_PATTERN .. "$") then return nil end
            values[#values + 1] = tonumber(part)
            if not comma then break end
            start = comma + 1
        end
        return values
    end

    local function parse_point(arguments, label)
        local values = split_csv_numbers(arguments)
        if not values or #values ~= 2 then
            return nil, "El tag \\" .. label .. " debe tener dos coordenadas numéricas."
        end
        return {x = values[1], y = values[2]}
    end

    local function parse_move_start(arguments)
        local values = split_csv_numbers(arguments)
        if not values or (#values ~= 4 and #values ~= 6) then
            return nil, "El tag \\move debe tener cuatro o seis valores numéricos."
        end
        return {x = values[1], y = values[2]}
    end

    local function tokenize_path(path)
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
                local number = fragment:match("^(" .. NUM_PATTERN .. ")")
                if not number then
                    return nil, "El clip vectorial contiene datos que no se pudieron interpretar."
                end
                tokens[#tokens + 1] = {kind = "number", value = tonumber(number)}
                index = index + #number
            end
        end
        return tokens
    end

    local function validate_path_tokens(tokens)
        local command, count
        local function validate_group()
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
                if not validate_group() then return false end
                command, count = token.value, 0
            else
                if not command then return false end
                count = count + 1
            end
        end
        return validate_group()
    end

    local function parse_clip(arguments)
        local text = trim(arguments)
        local rectangle = split_csv_numbers(text)
        if rectangle and #rectangle == 4 then
            return {kind = "rect", values = rectangle}
        end
        local explicit_scale = false
        local scale, path = text:match("^(" .. NUM_PATTERN .. ")%s*,%s*(.*)$")
        if scale and trim(path):match("^[mnlbspcMNLBSPC]") then
            explicit_scale = true
            scale = tonumber(scale)
        else
            scale, path = 1, text
        end
        if scale ~= math.floor(scale) or scale < 1 or scale > 10 or not trim(path):match("^[mnlbspcMNLBSPC]") then
            return nil, "El clip no es rectangular ni un vector ASS compatible."
        end
        local tokens, token_err = tokenize_path(path)
        if not tokens then return nil, token_err end
        if not validate_path_tokens(tokens) then
            return nil, "El clip vectorial tiene una cantidad inválida de coordenadas."
        end
        return {kind = "vector", scale = scale, explicit_scale = explicit_scale, tokens = tokens}
    end

    local function transform_point(x, y, pivot_x, pivot_y, dx, dy, radians)
        local cosine, sine = math.cos(radians), math.sin(radians)
        local relative_x, relative_y = x - pivot_x, y - pivot_y
        return pivot_x + cosine * relative_x + sine * relative_y + dx,
               pivot_y - sine * relative_x + cosine * relative_y + dy
    end

    local function transform_vector_path(clip, pivot, dx, dy, radians)
        local factor = 2 ^ (clip.scale - 1)
        local pivot_x, pivot_y = pivot.x * factor, pivot.y * factor
        local shift_x, shift_y = dx * factor, dy * factor
        local output, pending = {}, {}
        local function flush_pending()
            for index = 1, #pending, 2 do
                local x, y = transform_point(pending[index], pending[index + 1], pivot_x, pivot_y, shift_x, shift_y, radians)
                output[#output + 1] = format_number(x, 3)
                output[#output + 1] = format_number(y, 3)
            end
            pending = {}
        end
        for _, token in ipairs(clip.tokens) do
            if token.kind == "command" then
                flush_pending()
                output[#output + 1] = token.value
            else
                pending[#pending + 1] = token.value
            end
        end
        flush_pending()
        local path = table.concat(output, " ")
        if clip.explicit_scale then
            return tostring(clip.scale) .. "," .. path
        end
        return path
    end

    local function transform_rect_clip(clip, pivot, dx, dy, radians)
        local x1 = math.min(clip.values[1], clip.values[3])
        local y1 = math.min(clip.values[2], clip.values[4])
        local x2 = math.max(clip.values[1], clip.values[3])
        local y2 = math.max(clip.values[2], clip.values[4])
        if math.abs(radians) < EPSILON then
            return table.concat({
                format_number(x1 + dx, 3), format_number(y1 + dy, 3),
                format_number(x2 + dx, 3), format_number(y2 + dy, 3)
            }, ",")
        end
        local corners = {{x1, y1}, {x2, y1}, {x2, y2}, {x1, y2}}
        local path = {"m"}
        for index, point in ipairs(corners) do
            local x, y = transform_point(point[1], point[2], pivot.x, pivot.y, dx, dy, radians)
            path[#path + 1] = format_number(x, 3)
            path[#path + 1] = format_number(y, 3)
            if index == 1 then path[#path + 1] = "l" end
        end
        return table.concat(path, " ")
    end

    local function transform_geometry_inner(inner, pivot, dx, dy, radians, rotate_anchors)
        local parts, cursor, index, depth = {}, 1, 1, 0
        while index <= #inner do
            local char = inner:sub(index, index)
            if char == "\\" then
                local name, name_end = tag_name_at(inner, index)
                if name then
                    local lower = name:lower()
                    local argument_start = name_end
                    while inner:sub(argument_start, argument_start):match("%s") do
                        argument_start = argument_start + 1
                    end
                    if inner:sub(argument_start, argument_start) == "(" then
                        local argument_end = balanced_parenthesis_end(inner, argument_start)
                        if not argument_end then return nil, "Hay un tag con paréntesis incompletos." end
                        if lower == "pos" or lower == "org" or lower == "move" or lower == "clip" or lower == "iclip" then
                            local arguments = inner:sub(argument_start + 1, argument_end - 1)
                            local replacement
                            if lower == "pos" or lower == "org" then
                                local point, point_err = parse_point(arguments, lower)
                                if not point then return nil, point_err end
                                local x, y
                                if rotate_anchors then
                                    x, y = transform_point(point.x, point.y, pivot.x, pivot.y, dx, dy, radians)
                                else
                                    x, y = point.x + dx, point.y + dy
                                end
                                replacement = "\\" .. name .. "(" .. format_number(x, 3) .. "," .. format_number(y, 3) .. ")"
                            elseif lower == "move" then
                                local values = split_csv_numbers(arguments)
                                if not values or (#values ~= 4 and #values ~= 6) then
                                    return nil, "El tag \\move debe tener cuatro o seis valores numéricos."
                                end
                                if rotate_anchors then
                                    values[1], values[2] = transform_point(values[1], values[2], pivot.x, pivot.y, dx, dy, radians)
                                    values[3], values[4] = transform_point(values[3], values[4], pivot.x, pivot.y, dx, dy, radians)
                                else
                                    values[1], values[2] = values[1] + dx, values[2] + dy
                                    values[3], values[4] = values[3] + dx, values[4] + dy
                                end
                                local formatted = {}
                                for value_index, value in ipairs(values) do
                                    formatted[value_index] = format_number(value, value_index <= 4 and 3 or 0)
                                end
                                replacement = "\\" .. name .. "(" .. table.concat(formatted, ",") .. ")"
                            else
                                local clip, clip_err = parse_clip(arguments)
                                if not clip then return nil, clip_err end
                                if clip.kind == "rect" and depth > 0 and math.abs(radians) >= EPSILON then
                                    return nil, "No se puede rotar exactamente un clip rectangular animado dentro de \\t; hornéalo FBF primero."
                                end
                                local clip_inner
                                if clip.kind == "rect" then
                                    clip_inner = transform_rect_clip(clip, pivot, dx, dy, radians)
                                else
                                    clip_inner = transform_vector_path(clip, pivot, dx, dy, radians)
                                end
                                replacement = "\\" .. name .. "(" .. clip_inner .. ")"
                            end
                            parts[#parts + 1] = inner:sub(cursor, index - 1)
                            parts[#parts + 1] = replacement
                            cursor = argument_end + 1
                            index = argument_end + 1
                        else
                            index = index + 1
                        end
                    else
                        index = name_end
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

    local function map_existing_frz(inner, delta)
        local parts, cursor, index = {}, 1, 1
        while index <= #inner do
            if inner:sub(index, index) == "\\" then
                local name, name_end = tag_name_at(inner, index)
                if name and name:lower() == "frz" then
                    local value_start = name_end
                    while inner:sub(value_start, value_start):match("%s") do
                        value_start = value_start + 1
                    end
                    local number = inner:sub(value_start):match("^(" .. NUM_PATTERN .. ")")
                    if not number then return nil, "Hay un tag \\frz sin un valor numerico." end
                    parts[#parts + 1] = inner:sub(cursor, value_start - 1)
                    parts[#parts + 1] = format_number(tonumber(number) + delta, 3)
                    cursor = value_start + #number
                    index = cursor
                else
                    index = name_end or index + 1
                end
            else
                index = index + 1
            end
        end
        parts[#parts + 1] = inner:sub(cursor)
        return table.concat(parts)
    end

    local function build_context(subs)
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

    local function style_for(context, name, fallback)
        name = trim(name)
        if name ~= "" then
            return context.styles[name] or context.styles_lower[name:lower()] or fallback
        end
        return fallback
    end

    local function style_angle(style)
        return finite(style and (style.angle or style.rotation)) or 0
    end

    local function inject_reset_rotations(inner, context, line_style, delta)
        local parts, cursor, index, depth = {}, 1, 1, 0
        while index <= #inner do
            local char = inner:sub(index, index)
            if char == "\\" and depth == 0 then
                local name, name_end = tag_name_at(inner, index)
                if name and name:lower() == "r" then
                    local next_slash = inner:find("\\", name_end, true) or (#inner + 1)
                    local reset_name = trim(inner:sub(name_end, next_slash - 1))
                    local reset_style = style_for(context, reset_name, line_style)
                    parts[#parts + 1] = inner:sub(cursor, next_slash - 1)
                    parts[#parts + 1] = "\\frz" .. format_number(style_angle(reset_style) + delta, 3)
                    cursor, index = next_slash, next_slash
                else
                    index = name_end or index + 1
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

    local function scan_top_level_tag_names(inner, callback)
        local index, depth = 1, 0
        while index <= #inner do
            local char = inner:sub(index, index)
            if char == "\\" and depth == 0 then
                local name, name_end = tag_name_at(inner, index)
                if name then
                    callback(name:lower())
                    index = name_end
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

    local function leading_has_frz(text)
        local position, has_frz = 1, false
        text = tostring(text or "")
        while text:sub(position, position) == "{" do
            local close = text:find("}", position, true)
            if not close then break end
            local inner = text:sub(position + 1, close - 1)
            if looks_like_override(inner) then
                scan_top_level_tag_names(inner, function(name)
                    if name == "r" then has_frz = false end
                    if name == "frz" then has_frz = true end
                end)
            end
            position = close + 1
        end
        return has_frz
    end

    local function insert_leading_tag(text, tag)
        text = tostring(text or "")
        local position = 1
        while text:sub(position, position) == "{" do
            local close = text:find("}", position, true)
            if not close then break end
            local inner = text:sub(position + 1, close - 1)
            if looks_like_override(inner) then
                return text:sub(1, position) .. tag .. text:sub(position + 1)
            end
            position = close + 1
        end
        return text:sub(1, position - 1) .. "{" .. tag .. "}" .. text:sub(position)
    end

    local function explicit_alignment(text)
        local alignment
        map_override_blocks(text, function(inner)
            if not alignment then
                local value = inner:match("\\an([1-9])")
                if value then alignment = tonumber(value) end
            end
            return inner
        end)
        return alignment
    end

    local function effective_margin(line_value, style_value)
        local value = tonumber(line_value)
        if not value or value == 0 then value = tonumber(style_value) or 0 end
        return value
    end

    local function default_position(line, style, context)
        if not context.play_x or not context.play_y then
            return nil, "No se pudo obtener PlayResX/PlayResY para calcular la posición implícita."
        end
        local align = explicit_alignment(line.text) or tonumber(style and (style.align or style.alignment)) or 2
        if align < 1 or align > 9 then align = 2 end
        local margin_l = effective_margin(line.margin_l, style and style.margin_l)
        local margin_r = effective_margin(line.margin_r, style and style.margin_r)
        local margin_t = effective_margin(line.margin_t or line.margin_v, style and (style.margin_t or style.margin_v))
        local margin_b = effective_margin(line.margin_b or line.margin_v, style and (style.margin_b or style.margin_v))
        local x
        if align == 1 or align == 4 or align == 7 then
            x = margin_l
        elseif align == 3 or align == 6 or align == 9 then
            x = context.play_x - margin_r
        else
            x = context.play_x / 2
        end
        local y
        if align >= 7 then
            y = margin_t
        elseif align >= 4 then
            y = context.play_y / 2
        else
            y = context.play_y - margin_b
        end
        return {x = x, y = y}
    end

    local function anchor_points_for_line(line, context)
        local analysis, err = analyze_text(line.text)
        if not analysis then return nil, err end
        if analysis.pos and analysis.move then
            return nil, "La línea contiene \\pos y \\move a la vez; deja una sola posición antes de transformarla."
        end
        if analysis.pos then
            local point, point_err = parse_point(analysis.pos, "pos")
            if not point then return nil, point_err end
            return {point}
        end
        if analysis.move then
            local values = split_csv_numbers(analysis.move)
            if not values or (#values ~= 4 and #values ~= 6) then
                return nil, "El tag \\move debe tener cuatro o seis valores numéricos."
            end
            return {{x = values[1], y = values[2]}, {x = values[3], y = values[4]}}
        end
        local style = style_for(context, line.style, context.styles.Default or context.styles_lower.default)
        local point, point_err = default_position(line, style, context)
        if not point then return nil, point_err end
        return {point}
    end

    local function resolve_group_pivot(subs, indices, context, config)
        local mode = config.pivot_mode or PIVOT_CENTER
        if mode == PIVOT_CUSTOM or mode == "custom" then
            local x, y = finite(config.pivot_x), finite(config.pivot_y)
            if not x or not y then return nil, "El pivote personalizado necesita X e Y numéricos." end
            return {x = x, y = y}
        end
        local min_x, min_y, max_x, max_y
        for _, index in ipairs(indices) do
            local points, err = anchor_points_for_line(subs[index], context)
            if not points then return nil, "Línea " .. tostring(index) .. ": " .. tostring(err) end
            for _, point in ipairs(points) do
                if mode == PIVOT_FIRST or mode == "first" then return {x = point.x, y = point.y} end
                min_x = not min_x and point.x or math.min(min_x, point.x)
                min_y = not min_y and point.y or math.min(min_y, point.y)
                max_x = not max_x and point.x or math.max(max_x, point.x)
                max_y = not max_y and point.y or math.max(max_y, point.y)
            end
        end
        if not min_x then return nil, "No se pudo calcular el centro del conjunto." end
        return {x = (min_x + max_x) / 2, y = (min_y + max_y) / 2}
    end

    local function transform_line(line, context, dx, dy, rotation, shared_pivot)
        local analysis, analysis_err = analyze_text(line.text)
        if not analysis then return nil, analysis_err end
        if analysis.pos and analysis.move then
            return nil, "La línea contiene \\pos y \\move a la vez; deja una sola posición antes de transformarla."
        end
        local style = style_for(context, line.style, context.styles.Default or context.styles_lower.default)
        local implicit_position
        if not analysis.pos and not analysis.move then
            implicit_position, analysis_err = default_position(line, style, context)
            if not implicit_position then return nil, analysis_err end
        end
        local rotate_anchors = shared_pivot ~= nil
        local pivot
        if shared_pivot then
            pivot = shared_pivot
        elseif analysis.org then
            pivot, analysis_err = parse_point(analysis.org, "org")
        elseif analysis.pos then
            pivot, analysis_err = parse_point(analysis.pos, "pos")
        elseif analysis.move then
            pivot, analysis_err = parse_move_start(analysis.move)
        else
            pivot = implicit_position
        end
        if not pivot then return nil, analysis_err end
        if not rotate_anchors and math.abs(rotation) >= EPSILON and analysis.has_clip and analysis.move and not analysis.org then
            return nil, "Una línea con \\move y clip necesita \\org para conservar un pivote único al rotar; hornéala FBF o agrega el origen."
        end
        local radians = math.rad(rotation)
        local text, geometry_err = map_override_blocks(line.text, function(inner)
            return transform_geometry_inner(inner, pivot, dx, dy, radians, rotate_anchors)
        end)
        if not text then return nil, geometry_err end
        if not analysis.pos and not analysis.move then
            local x, y
            if rotate_anchors then
                x, y = transform_point(implicit_position.x, implicit_position.y, pivot.x, pivot.y, dx, dy, radians)
            else
                x, y = implicit_position.x + dx, implicit_position.y + dy
            end
            text = insert_leading_tag(text, "\\pos(" .. format_number(x, 3) .. "," .. format_number(y, 3) .. ")")
        end
        if math.abs(rotation) >= EPSILON then
            text, geometry_err = map_override_blocks(text, function(inner)
                local mapped, frz_err = map_existing_frz(inner, rotation)
                if not mapped then return nil, frz_err end
                return inject_reset_rotations(mapped, context, style, rotation)
            end)
            if not text then return nil, geometry_err end
            if not leading_has_frz(text) then
                text = insert_leading_tag(text, "\\frz" .. format_number(style_angle(style) + rotation, 3))
            end
        end
        local copy = {}
        for key, value in pairs(line) do copy[key] = value end
        copy.text = text
        return copy
    end

    local function apply_transform(subs, sel, config)
        local dx = finite(config.dx) or 0
        local dy = finite(config.dy) or 0
        local rotation = finite(config.rotation) or 0
        if math.abs(dx) < EPSILON and math.abs(dy) < EPSILON and math.abs(rotation) < EPSILON then
            show_error("Introduce un desplazamiento o una rotación distintos de cero.")
            return sel
        end
        local indices = editable_selection(subs, sel)
        if #indices == 0 then
            show_error("Selecciona al menos una línea de diálogo.")
            return sel
        end
        local context = build_context(subs)
        local shared_pivot
        if config.rotation_mode == ROTATE_GROUP and math.abs(rotation) >= EPSILON then
            local pivot_err
            shared_pivot, pivot_err = resolve_group_pivot(subs, indices, context, config)
            if not shared_pivot then
                show_error(pivot_err)
                return sel
            end
        end
        local updates = {}
        for _, index in ipairs(indices) do
            local transformed, err = transform_line(subs[index], context, dx, dy, rotation, shared_pivot)
            if not transformed then
                show_error("Línea " .. tostring(index) .. ": " .. tostring(err))
                return sel
            end
            updates[#updates + 1] = {index = index, line = transformed}
        end
        for _, update in ipairs(updates) do
            subs[update.index] = update.line
        end
        setUndoPoint()
        return sel
    end

    return {
        parse_clip = parse_clip,
        transform_point = transform_point,
        transform_line = transform_line,
        build_context = build_context,
        anchor_points_for_line = anchor_points_for_line,
        resolve_group_pivot = resolve_group_pivot,
        rotation_modes = {group = ROTATE_GROUP, individual = ROTATE_INDIVIDUAL},
        pivot_modes = {center = PIVOT_CENTER, first = PIVOT_FIRST, custom = PIVOT_CUSTOM},
        apply_transform = apply_transform
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
        hint_pivot = "Custom X/Y only apply to a custom pivot. Positive degrees rotate counterclockwise.",
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
        undo_makeup = "MakeupnPosing - Makeup: %s",
        undo_posing = "MakeupnPosing - Posing",
    },
    es = {
        section_posing = "POSING",
        section_makeup = "MAKEUP",
        label_action = "Acción:",
        label_move_x = "Mover X:",
        label_move_y = "Mover Y:",
        label_rotation = "Rotación Z relativa:",
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
        hint_pivot = "X/Y solo se usan con pivote personalizado. Los grados positivos giran en sentido antihorario.",
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
        undo_makeup = "MakeupnPosing - Makeup: %s",
        undo_posing = "MakeupnPosing - Posing",
    },
}

local HELP_TEXTS = {
    en = [[MAKEUPNPOSING - USER GUIDE

Posing:
Transform selection applies one rigid translation and relative Z rotation to
the complete selected sign stack. It preserves the shared geometry of \pos,
both \move endpoints, \org, rectangular or vector \clip/\iclip, drawings, and
implicit positions. Group rotation uses one shared pivot. A moving line with a
clip needs \org before individual rotation because it has no fixed pivot.

The six quick actions use the X, Y, and rotation steps saved in Config. The same
steps power the assignable commands under : Kite Hotkeys :/MakeupnPosing/Posing.

Makeup:
Insert restores a [TAG] adaptive style preset or an exact [GROUP] sign stack.
Save style, Save group, Save both, and Delete preset are Action choices instead
of dialog buttons. Presets remain in the Makeup library beside the subtitle.

Config:
Stores the language, three hotkey steps, hotkey rotation mode, and hotkey pivot.
Positive Z values rotate counterclockwise.]],
    es = [[MAKEUPNPOSING - GUÍA DE USO

Posing:
Transformar selección aplica una traslación y una rotación Z relativa rígidas a
todo el cartel seleccionado. Conserva la geometría compartida de \pos, ambos
extremos de \move, \org, \clip/\iclip rectangulares o vectoriales, dibujos y
posiciones implícitas. La rotación del conjunto utiliza un único pivote. Una
línea con movimiento y clip necesita \org para rotarse individualmente, pues no
tiene un pivote fijo.

Las seis acciones rápidas usan los pasos X, Y y de rotación guardados en Config.
Los mismos pasos alimentan los comandos asignables de
: Kite Hotkeys :/MakeupnPosing/Posing.

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

local CONFIG_DEFAULTS = {
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
    local copy = {}
    for key, value in pairs(CONFIG_DEFAULTS) do copy[key] = value end
    return copy
end

local function normalizeConfig(values)
    local normalized = copyDefaults()
    for key in pairs(normalized) do
        if values and values[key] ~= nil then normalized[key] = values[key] end
    end
    if normalized.language ~= "es" then normalized.language = "en" end
    normalized.x_step = tonumber(normalized.x_step) or CONFIG_DEFAULTS.x_step
    normalized.y_step = tonumber(normalized.y_step) or CONFIG_DEFAULTS.y_step
    normalized.rotation_step = tonumber(normalized.rotation_step) or CONFIG_DEFAULTS.rotation_step
    if normalized.x_step <= 0 then normalized.x_step = CONFIG_DEFAULTS.x_step end
    if normalized.y_step <= 0 then normalized.y_step = CONFIG_DEFAULTS.y_step end
    if normalized.rotation_step <= 0 then normalized.rotation_step = CONFIG_DEFAULTS.rotation_step end
    if normalized.hotkey_rotation_mode ~= "individual" then normalized.hotkey_rotation_mode = "group" end
    if normalized.hotkey_pivot_mode ~= "first" and normalized.hotkey_pivot_mode ~= "custom" then
        normalized.hotkey_pivot_mode = "center"
    end
    normalized.hotkey_pivot_x = tonumber(normalized.hotkey_pivot_x) or 0
    normalized.hotkey_pivot_y = tonumber(normalized.hotkey_pivot_y) or 0
    return normalized
end

local function loadConfig()
    if configLoaded then return currentConfig end
    local section = {}
    for key, value in pairs(CONFIG_DEFAULTS) do
        section[key] = { value = value, config = true, name = key, class = "edit" }
    end
    configHandler = KiteUI.dialogHandler({ main = section }, script_namespace, script_version, {
        { path = "?user/makeupnposing_config.json", format = "json_sections" },
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
    if not aegisub or not aegisub.dialog then return nil end
    return aegisub.dialog.display({
        { class = "label", label = tostring(message or ""), x = 0, y = 0, width = 36, height = 3 },
    }, buttons or { L("button_ok") })
end

local function confirm(message)
    return notice(message, { L("button_yes"), L("button_no") }) == L("button_yes")
end

local POSING_ERROR_EN = {
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
    ["Introduce un desplazamiento o una rotación distintos de cero."] = "Enter a non-zero translation or rotation.",
    ["Selecciona al menos una línea de diálogo."] = "Select at least one dialogue line.",
}

local function translatePosingError(message)
    message = tostring(message or "Error desconocido.")
    if currentLanguage == "es" then return message end
    local line, detail = message:match("^Línea (%d+): (.*)$")
    if line then return "Line " .. line .. ": " .. translatePosingError(detail) end
    local tag = message:match("^El tag \\([^ ]+) debe tener dos coordenadas numéricas%.$")
    if tag then return "The \\" .. tag .. " tag must contain two numeric coordinates." end
    local command = message:match("^El clip vectorial contiene el comando no compatible '(.)'%.$")
    if command then return "The vector clip contains the unsupported command '" .. command .. "'." end
    return POSING_ERROR_EN[message] or message
end

local MAKEUP_ERROR_ES = {
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

local MAKEUP_PREFIX_ES = {
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
    if MAKEUP_ERROR_ES[message] then return MAKEUP_ERROR_ES[message] end
    for english, spanish in pairs(MAKEUP_PREFIX_ES) do
        if message:sub(1, #english) == english then
            message = spanish .. message:sub(#english + 1)
            break
        end
    end
    message = message:gsub("The filesystem returned no error details%.", MAKEUP_ERROR_ES["The filesystem returned no error details."])
    return message
end

local Posing = createPosing(
    function(message) notice(translatePosingError(message)) end,
    function() aegisub.set_undo_point(L("undo_posing")) end)

local LABEL_PREFIX = { adaptive = "[TAG] ", exact = "[GROUP] " }

local function libraryFolder()
    local folder = LineOps.subtitleFolder(true)
    if folder then return folder end
    return nil, L("save_subtitle")
end

local function indexedItems(index)
    local items, entries = {}, {}
    for _, entry in ipairs(index and index.entries or {}) do
        local label = (LABEL_PREFIX[entry.kind] or "[?] ") .. entry.name
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
        local preset, captureError = Core.capture_preset(subs, selection, active, name, kind)
        if not preset then return nil, translateMakeupError(captureError) end
        presets[#presets + 1] = preset
        if Store.findEntry(index, name, kind) then replacing[#replacing + 1] = LABEL_PREFIX[kind] .. name end
    end
    local conjunction = currentLanguage == "es" and " y " or " and "
    if #replacing > 0 and not confirm(L("replace_presets", table.concat(replacing, conjunction))) then return false end
    local saved = {}
    for _, preset in ipairs(presets) do
        local entry, saveError = Store.save(folder, preset)
        if not entry then return nil, translateMakeupError(saveError) end
        saved[#saved + 1] = LABEL_PREFIX[entry.kind] .. entry.name
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

local POSING_ACTIONS = { "posing_custom", "posing_x_plus", "posing_x_minus", "posing_y_plus", "posing_y_minus", "posing_rotation_plus", "posing_rotation_minus" }
local MAKEUP_ACTIONS = { "makeup_insert", "makeup_save_style", "makeup_save_group", "makeup_save_both", "makeup_delete" }
local ROTATION_MODES = { "rotation_group", "rotation_individual" }
local PIVOT_MODES = { "pivot_center", "pivot_first", "pivot_custom" }
local INSERT_MODES = { "insert_create", "insert_replace" }

local function posingActionLabel(key)
    local amount = currentConfig.x_step
    if key == "posing_y_plus" or key == "posing_y_minus" then amount = currentConfig.y_step end
    if key == "posing_rotation_plus" or key == "posing_rotation_minus" then amount = currentConfig.rotation_step end
    return L(key, format_number(amount))
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
        rotation_mode = hotkey and currentConfig.hotkey_rotation_mode or rotationKey(state.rotation_mode),
        pivot_mode = hotkey and currentConfig.hotkey_pivot_mode or pivotKey(state.pivot_mode),
        pivot_x = hotkey and currentConfig.hotkey_pivot_x or state.pivot_x,
        pivot_y = hotkey and currentConfig.hotkey_pivot_y or state.pivot_y,
    }
    if action ~= "posing_custom" then values.dx, values.dy, values.rotation = 0, 0, 0 end
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
        local label = (LABEL_PREFIX[entry.kind] or "") .. entry.name
        if not confirm(L("delete_confirm", label)) then return selection end
        local removed, removeError = Store.remove(folder, entry)
        if not removed then notice(L("delete_failed", translateMakeupError(removeError)))
        elseif removeError then notice(translateMakeupError(removeError)) end
        return selection
    end
    local preset, loadError = Store.load(folder, entry)
    if not preset then notice(L("load_failed", translateMakeupError(loadError))); return selection end
    local mode = state.insert_mode == "insert_replace" and "replace" or "create"
    local newSelection, applyError = Core.apply_preset(subs, selection, active, preset, mode)
    if not newSelection then notice(L("insert_failed", translateMakeupError(applyError))); return selection end
    aegisub.set_undo_point(L("undo_makeup", entry.name))
    return newSelection
end

local function configGui()
    local languageItems, languageMap, languageLabels = optionData({ "en", "es" }, function(key)
        return key == "es" and "Español" or "English"
    end)
    local rotationItems, rotationMap, rotationLabels = optionData(ROTATION_MODES)
    local pivotItems, pivotMap, pivotLabels = optionData(PIVOT_MODES)
    local values = currentConfig
    local dialog = {
        { class = "label", label = sectionTitle("button_config"), x = 0, y = 0, width = 8, height = 1 },
        { class = "label", label = L("label_language"), x = 0, y = 1, width = 3, height = 1 },
        { class = "dropdown", name = "language", items = languageItems, value = languageLabels[values.language], x = 3, y = 1, width = 5, height = 1 },
        { class = "label", label = L("label_x_step"), x = 0, y = 2, width = 3, height = 1 },
        { class = "floatedit", name = "x_step", value = values.x_step, min = 0.001, x = 3, y = 2, width = 2, height = 1 },
        { class = "label", label = L("label_y_step"), x = 0, y = 3, width = 3, height = 1 },
        { class = "floatedit", name = "y_step", value = values.y_step, min = 0.001, x = 3, y = 3, width = 2, height = 1 },
        { class = "label", label = L("label_rotation_step"), x = 0, y = 4, width = 3, height = 1 },
        { class = "floatedit", name = "rotation_step", value = values.rotation_step, min = 0.001, x = 3, y = 4, width = 2, height = 1 },
        { class = "label", label = L("label_hotkey_rotation_mode"), x = 0, y = 5, width = 3, height = 1 },
        { class = "dropdown", name = "hotkey_rotation_mode", items = rotationItems, value = rotationLabels[values.hotkey_rotation_mode == "individual" and "rotation_individual" or "rotation_group"], x = 3, y = 5, width = 5, height = 1 },
        { class = "label", label = L("label_hotkey_pivot_mode"), x = 0, y = 6, width = 3, height = 1 },
        { class = "dropdown", name = "hotkey_pivot_mode", items = pivotItems, value = pivotLabels[values.hotkey_pivot_mode == "first" and "pivot_first" or values.hotkey_pivot_mode == "custom" and "pivot_custom" or "pivot_center"], x = 3, y = 6, width = 5, height = 1 },
        { class = "label", label = L("label_pivot_x"), x = 0, y = 7, width = 2, height = 1 },
        { class = "floatedit", name = "hotkey_pivot_x", value = values.hotkey_pivot_x, x = 2, y = 7, width = 2, height = 1 },
        { class = "label", label = L("label_pivot_y"), x = 4, y = 7, width = 2, height = 1 },
        { class = "floatedit", name = "hotkey_pivot_y", value = values.hotkey_pivot_y, x = 6, y = 7, width = 2, height = 1 },
    }
    local button, result = aegisub.dialog.display(dialog, { L("button_save"), L("button_cancel") })
    if button ~= L("button_save") then return false end
    local xStep, yStep, rotationStep = tonumber(result.x_step), tonumber(result.y_step), tonumber(result.rotation_step)
    if not xStep or xStep <= 0 or not yStep or yStep <= 0 or not rotationStep or rotationStep <= 0 then
        notice(L("config_invalid_steps"))
        return false
    end
    result.language = languageMap[result.language]
    result.hotkey_rotation_mode = rotationKey(rotationMap[result.hotkey_rotation_mode])
    result.hotkey_pivot_mode = pivotKey(pivotMap[result.hotkey_pivot_mode])
    saveConfig(result)
    return true
end

local function main(subs, selection, active)
    loadConfig()
    local state = {
        posing_action = "posing_custom",
        dx = 0,
        dy = 0,
        rotation = 0,
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
        local posingItems, posingMap, posingLabels = optionData(POSING_ACTIONS, posingActionLabel)
        local makeupItems, makeupMap, makeupLabels = optionData(MAKEUP_ACTIONS)
        local rotationItems, rotationMap, rotationLabels = optionData(ROTATION_MODES)
        local pivotItems, pivotMap, pivotLabels = optionData(PIVOT_MODES)
        local insertItems, insertMap, insertLabels = optionData(INSERT_MODES)
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
            { class = "label", label = L("label_rotation_mode"), x = 0, y = 3, width = 2, height = 1 },
            { class = "dropdown", name = "rotation_mode", items = rotationItems, value = rotationLabels[state.rotation_mode], x = 2, y = 3, width = 6, height = 1 },
            { class = "label", label = L("label_pivot_mode"), x = 0, y = 4, width = 2, height = 1 },
            { class = "dropdown", name = "pivot_mode", items = pivotItems, value = pivotLabels[state.pivot_mode], x = 2, y = 4, width = 6, height = 1 },
            { class = "label", label = L("label_pivot_x"), x = 0, y = 5, width = 1, height = 1 },
            { class = "floatedit", name = "pivot_x", value = state.pivot_x, x = 1, y = 5, width = 2, height = 1 },
            { class = "label", label = L("label_pivot_y"), x = 4, y = 5, width = 1, height = 1 },
            { class = "floatedit", name = "pivot_y", value = state.pivot_y, x = 5, y = 5, width = 2, height = 1 },
            { class = "label", label = L("hint_pivot"), x = 0, y = 6, width = 8, height = 1 },
            { class = "label", label = sectionTitle("section_makeup"), x = 0, y = 8, width = 8, height = 1 },
            { class = "label", label = L("label_action"), x = 0, y = 9, width = 2, height = 1 },
            { class = "dropdown", name = "makeup_action", items = makeupItems, value = makeupLabels[state.makeup_action], x = 2, y = 9, width = 6, height = 1 },
            { class = "label", label = L("label_preset"), x = 0, y = 10, width = 2, height = 1 },
            { class = "dropdown", name = "preset", items = presetItems, value = state.preset, x = 2, y = 10, width = 6, height = 1 },
            { class = "label", label = L("label_name"), x = 0, y = 11, width = 2, height = 1 },
            { class = "edit", name = "name", value = state.name, x = 2, y = 11, width = 6, height = 1 },
            { class = "label", label = L("label_insert_mode"), x = 0, y = 12, width = 2, height = 1 },
            { class = "dropdown", name = "insert_mode", items = insertItems, value = insertLabels[state.insert_mode], x = 2, y = 12, width = 6, height = 1 },
            { class = "label", label = L("hint_insert"), x = 0, y = 13, width = 8, height = 1 },
        }
        local button, result = aegisub.dialog.display(dialog, {
            L("button_makeup"), L("button_posing"), L("button_config"), L("button_help"), L("button_cancel")
        })
        if not button or button == L("button_cancel") then return selection end
        state.posing_action = posingMap[result.posing_action] or state.posing_action
        state.makeup_action = makeupMap[result.makeup_action] or state.makeup_action
        state.rotation_mode = rotationMap[result.rotation_mode] or state.rotation_mode
        state.pivot_mode = pivotMap[result.pivot_mode] or state.pivot_mode
        state.insert_mode = insertMap[result.insert_mode] or state.insert_mode
        state.preset = result.preset
        state.name = result.name
        state.dx, state.dy, state.rotation = result.dx, result.dy, result.rotation
        state.pivot_x, state.pivot_y = result.pivot_x, result.pivot_y
        if button == L("button_help") then
            aegisub.dialog.display({
                { class = "textbox", text = HELP_TEXTS[currentLanguage] or HELP_TEXTS.en, x = 0, y = 0, width = 70, height = 22 },
            }, { L("button_ok") })
        elseif button == L("button_config") then
            configGui()
        elseif button == L("button_posing") then
            return Posing.apply_transform(subs, selection, posingValues(state.posing_action, state, false))
        elseif button == L("button_makeup") then
            return runMakeup(subs, selection, active, state, index, byLabel, folder, folderError, indexError)
        end
    end
end

local function posingHotkey(action)
    return function(subs, selection)
        loadConfig()
        local state = { dx = 0, dy = 0, rotation = 0, rotation_mode = "rotation_group", pivot_mode = "pivot_center", pivot_x = 0, pivot_y = 0 }
        return Posing.apply_transform(subs, selection, posingValues(action, state, true))
    end
end

local HOTKEY_PATH = ": Kite Hotkeys :/" .. script_name
local function hotkeyPath(section, action)
    return HOTKEY_PATH .. "/" .. section .. "/" .. action
end

local MakeupnPosing = {
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

return MakeupnPosing
