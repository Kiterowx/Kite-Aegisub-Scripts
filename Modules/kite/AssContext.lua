local moduleVersion = "1.1.3"
local Context = {VERSION = moduleVersion, version = moduleVersion}
local Core = require("kite.Core")
local LineOps = require("kite.LineOps")
local Color = require("kite.Color")
local finite, copy = Core.finiteNumber, Core.copy
local okDep, DependencyControl = pcall(require, "l0.DependencyControl")
local depctrl
if okDep then
    depctrl = DependencyControl{
        name = "kite.AssContext", moduleName = "kite.AssContext", version = moduleVersion,
        description = "Shared ASS line context, placement and ordered temporal evaluation",
        author = "Kiterow", url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
        feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
        {{"kite.Core", version = "1.1.0"}, {"kite.LineOps", version = "1.7.0"}, {"kite.Media", version = "1.4.0"},{"kite.UI",version="1.5.0"},{"kite.Settings",version="1.0.0"},{"kite.Color",version="1.2.1"}},
    }
end

function Context.fromSubtitles(subs)
    local styles, meta = {}, {}
    for index = 1, #subs do
        local line = subs[index]
        if line.class == "style" then styles[line.name] = line
        elseif line.class == "info" then meta[line.key] = line.value end
    end
    local x, y = LineOps.scriptResolution(subs)
    meta.PlayResX, meta.PlayResY = x or meta.PlayResX, y or meta.PlayResY
    return {sub = subs, styles = styles, meta = meta}
end

function Context.firstTag(text, names)
    for _, call in ipairs(LineOps.tagCalls(text, names)) do
        if call.top_level then return call end
    end
end

function Context.explicitPosition(text, duration, offset)
    for _, call in ipairs(LineOps.tagCalls(text, {"pos", "move"})) do
        if call.top_level then
            local args, values = LineOps.splitArguments(call.value), {}
            for i, value in ipairs(args) do values[i] = finite(value) end
            if call.name == "pos" and #args == 2 and values[1] and values[2] then
                return values[1], values[2], call
            elseif call.name == "move" and (#args == 4 or #args == 6)
                and values[1] and values[2] and values[3] and values[4]
                and (#args == 4 or (values[5] and values[6])) then
                local t1, t2 = values[5] or 0, values[6] or 0
                if t1 > t2 then t1, t2 = t2, t1 end
                if t1 <= 0 and t2 <= 0 then t1, t2 = 0, finite(duration) or 0 end
                local now = finite(offset) or 0
                local factor = now <= t1 and 0 or (now >= t2 and 1 or (now - t1) / (t2 - t1))
                return values[1] + (values[3] - values[1]) * factor,
                    values[2] + (values[4] - values[2]) * factor, call
            end
        end
    end
end

local legacyAlign = {[1]=1, [2]=2, [3]=3, [5]=7, [6]=8, [7]=9, [9]=4, [10]=5, [11]=6}
function Context.alignment(text, style)
    for _, call in ipairs(LineOps.tagCalls(text, {"an", "a"})) do
        if call.top_level then
            local value = finite(call.value)
            if call.name == "a" then value = legacyAlign[value] end
            if value and value >= 1 and value <= 9 and value == math.floor(value) then return value end
        end
    end
    return finite(style and style.align) or 2
end

function Context.resolve(line, options)
    line, options = line or {}, options or {}
    local collection = options.collection or line.parentCollection or {}
    local styles = options.styles or collection.styles or {}
    local style = options.style or styles[line.style] or line.styleRef or line.styleref or styles.Default
    local meta = options.meta or options.info or collection.meta or {}
    local sub = options.sub or collection.sub
    if not style and sub then
        local gathered = Context.fromSubtitles(sub)
        styles, meta = gathered.styles, gathered.meta
        style = styles[line.style] or styles.Default
    end
    return {line = line, style = style, styles = styles, meta = meta, sub = sub}
end

function Context.defaultPosition(line, options)
    local ctx = Context.resolve(line, options)
    if not ctx.style then return nil, nil, "The line style could not be resolved." end
    local meta = ctx.meta
    local x = finite(meta.PlayResX or meta.playresx or meta.res_x or meta.play_res_x)
    local y = finite(meta.PlayResY or meta.playresy or meta.res_y or meta.play_res_y)
    if (not x or not y) and ctx.sub then x, y = LineOps.scriptResolution(ctx.sub) end
    if not x or not y or x <= 0 or y <= 0 then return nil, nil, "The script resolution could not be resolved." end
    local style = ctx.style
    local align = Context.alignment(line.text, style)
    local function margin(value, fallback)
        value = finite(value)
        return value and value ~= 0 and value or finite(fallback) or 0
    end
    local left = margin(line.margin_l, style.margin_l)
    local right = margin(line.margin_r, style.margin_r)
    local vertical = margin(line.margin_t or line.margin_v, style.margin_t or style.margin_v)
    local horizontal = align % 3
    return horizontal == 1 and left or horizontal == 2 and (left + x - right) / 2 or x - right,
        align >= 7 and vertical or align >= 4 and y / 2 or y - vertical
end

function Context.position(line, options, offset)
    line = line or {}
    local duration = (finite(line.end_time) or 0) - (finite(line.start_time) or 0)
    local x, y, call = Context.explicitPosition(line.text, duration, offset)
    if call then return x, y, call end
    return Context.defaultPosition(line, options)
end

function Context.origin(line, options, offset)
    local call = Context.firstTag(line.text, "org")
    if call then
        local args = LineOps.splitArguments(call.value)
        local x, y = finite(args[1]), finite(args[2])
        if #args == 2 and x and y then return x, y, call end
    end
    return Context.position(line, options, offset)
end

function Context.layoutScale(line, options, videoHeight)
    local meta = Context.resolve(line, options).meta
    local play = finite(meta.PlayResY or meta.playresy or meta.res_y)
    local layout = finite(meta.LayoutResY or meta.layoutresy) or finite(videoHeight)
    if play and layout and play > 0 and layout > 0 then return play / layout end
    return 1
end

local lineDefaults = {class="dialogue", comment=false, layer=0, start_time=0, end_time=0,
    style="Default", actor="", margin_l=0, margin_r=0, margin_t=0, effect="", text=""}
function Context.toLine(source, lineClass, options)
    if type(source) == "table" and source.__class and not options then return source end
    source = type(source) == "table" and source or {text=tostring(source or "")}
    local line = copy(lineDefaults)
    for key, value in pairs(source) do line[key] = value end
    line.text = tostring(line.text or "")
    line.extra = type(line.extra) == "table" and line.extra or {}
    local ctx = Context.resolve(source, options)
    local collection = source.parentCollection
    if options or not collection then
        collection = {sub=ctx.sub, styles=ctx.styles, meta=ctx.meta}
    end
    line.styleRef, line.styleref = ctx.style, ctx.style
    return lineClass(line, collection, {})
end

function Context.transform(value, duration, offset)
    local args = LineOps.splitArguments(value)
    local count = #args
    local payload = args[count] or ""
    local t1, t2, accel = 0, duration, 1
    if count == 2 then accel = finite(args[1])
    elseif count == 3 or count == 4 then
        t1, t2 = finite(args[1]), finite(args[2])
        if count == 4 then accel = finite(args[3]) end
    elseif count ~= 1 then return nil, "Invalid transform arguments." end
    if not t1 or not t2 or not accel or not payload:find("\\", 1, true) then return nil, "Invalid transform arguments." end
    if t2 == 0 then t2 = duration end
    local factor = offset < t1 and 0 or offset >= t2 and 1 or ((offset - t1) / (t2 - t1)) ^ accel
    return {startTime=t1, endTime=t2, accel=accel, payload=payload, factor=factor}
end

function Context.visitTags(text, duration, offset, callback)
    local function visit(content, factor, nested)
        for _, token in ipairs(LineOps.overrideTokens(content)) do
            if token.name == "t" then
                local transform, err = Context.transform(token.value, duration, offset)
                assert(transform, err)
                visit(transform.payload, transform.factor, true)
            else callback(token, factor, nested) end
        end
    end
    for _, section in ipairs(LineOps.scanSections(text)) do
        if section.type == "override" then visit(section.text, 1, false) end
    end
end

function Context.frameRange(line)
    local startTime, endTime = finite(line.start_time), finite(line.end_time)
    if not startTime or not endTime or endTime <= startTime then return nil end
    local explicitFirst, explicitEnd = finite(line.startFrame), finite(line.endFrame)
    if explicitFirst and explicitEnd and explicitFirst == math.floor(explicitFirst)
        and explicitEnd == math.floor(explicitEnd) and explicitEnd > explicitFirst then
        return explicitFirst, explicitEnd
    end

    local Media = require("kite.Media")
    local first = Media.frameFromMs(startTime)
    local finish = Media.frameFromMs(endTime)
    if first and finish then return first, math.max(first + 1, finish) end
end

function Context.needsFullBake(text)
    for _, call in ipairs(LineOps.tagCalls(text)) do
        if call.top_level and (call.name == "move" or call.name == "fad" or call.name == "fade"
            or call.name == "k" or call.name == "kf" or call.name == "ko" or call.name == "kt") then return true end
        if not call.top_level and call.name ~= "clip" and call.name ~= "iclip" and call.name ~= "t" then return true end
    end
    return false
end

function Context.shiftFrameKaraoke(line, sourceStart, frameStart)
    if not line then return end
    local shift = ((finite(frameStart) or 0) - (finite(sourceStart) or 0)) / 10
    if shift == 0 then return end
    local text, chunks, cursor, first = tostring(line.text or ""), {}, 1, true
    for _, call in ipairs(LineOps.tagCalls(text, {"k", "kf", "ko", "kt"})) do
        if call.top_level then
            chunks[#chunks + 1] = text:sub(cursor, call.start - 1)
            if call.name == "kt" then
                chunks[#chunks + 1] = "\\kt" .. string.format("%.3f", (finite(call.value) or 0) - shift)
            else

                if first then chunks[#chunks + 1] = "\\k" .. string.format("%.3f", -shift) end
                chunks[#chunks + 1] = call.raw
            end
            first, cursor = false, call.finish + 1
        end
    end
    chunks[#chunks + 1] = text:sub(cursor)
    line.text = table.concat(chunks)
end

function Context.samplePosition(text, duration, offset)
    local x, y, position = Context.explicitPosition(text, duration, offset)
    if not position then return text end
    local chunks, cursor = {}, 1
    for _, call in ipairs(LineOps.tagCalls(text, {"pos", "move"})) do
        if call.top_level then
            chunks[#chunks + 1] = text:sub(cursor, call.start - 1)
            if call.start == position.start then
                chunks[#chunks + 1] = string.format("\\pos(%.3f,%.3f)", x, y)
            end
            cursor = call.finish + 1
        end
    end
    chunks[#chunks + 1] = text:sub(cursor)
    return table.concat(chunks)
end

local function offsetTimedCall(call, duration, offset)
    if call.name == "t" then
        local transform, err = Context.transform(call.value, duration, 0)
        assert(transform, err)
        local payload = Context.retimeText("{" .. transform.payload .. "}", duration, offset):sub(2, -2)
        if transform.endTime <= offset then return payload end
        return "\\t(" .. Core.formatNumber(transform.startTime - offset, 6) .. ","
            .. Core.formatNumber(transform.endTime - offset, 6) .. ","
            .. Core.formatNumber(transform.accel, 9) .. "," .. payload .. ")"
    end
    local values = LineOps.splitArguments(call.value)
    for i, value in ipairs(values) do
        values[i] = finite(value)
        if not values[i] then return end
    end
    if call.name == "move" and (#values == 4 or #values == 6) then
        local t1, t2 = values[5] or 0, values[6] or 0
        if t1 > t2 then t1, t2 = t2, t1 end
        if t1 <= 0 and t2 <= 0 then t1, t2 = 0, duration end
        if t2 <= offset then
            return "\\pos(" .. Core.formatNumber(values[3], 6) .. "," .. Core.formatNumber(values[4], 6) .. ")"
        end
        values[5], values[6] = t1 - offset, t2 - offset
    elseif call.name == "fad" and #values == 2 then
        values = {255, 0, 255, -offset, values[1] - offset, duration - values[2] - offset, duration - offset}
    elseif call.name == "fade" and #values == 7 then
        for i = 4, 7 do values[i] = values[i] - offset end
    else return end
    for i, value in ipairs(values) do values[i] = Core.formatNumber(value, 6) end
    return "\\" .. (call.name == "fad" and "fade" or call.name) .. "(" .. table.concat(values, ",") .. ")"
end

function Context.retimeText(text, duration, offset)
    assert(finite(duration) and duration > 0 and finite(offset), "Invalid source duration or time offset.")
    return (LineOps.mapTagCalls(text, {"t", "move", "fad", "fade"}, function(call)
        return offsetTimedCall(call, duration, offset)
    end))
end

function Context.offsetFades(text, duration, offset)
    assert(finite(duration) and duration > 0 and finite(offset), "Invalid source duration or fade offset.")
    return (LineOps.mapTagCalls(text, {"fad", "fade"}, function(call)
        return offsetTimedCall(call, duration, offset)
    end))
end

function Context.retimeSlice(line, source)
    line.text = Context.retimeText(line.text, source.end_time - source.start_time, line.start_time - source.start_time)
    Context.shiftFrameKaraoke(line, source.start_time, line.start_time)
    return line
end

function Context.applyInlineStyleTags(style, tags, styles, baseStyle, originalStyle)
    local fields = {fn = "fontname", fs = "fontsize", fscx = "scale_x", fscy = "scale_y",
        fsp = "spacing", b = "bold", i = "italic", u = "underline", s = "strikeout", bord = "outline"}
    local booleans = {b = true, i = true, u = true, s = true}
    local relativeFontDivisor = 10
    local resetStyle = baseStyle
    local text = tostring(tags or "")
    if not text:find("{", 1, true) then text = "{" .. text .. "}" end
    for _, call in ipairs(LineOps.tagCalls(text)) do
        if call.top_level then
            if call.name == "r" then
                resetStyle = (styles or {})[call.value] or originalStyle or baseStyle
                if resetStyle then for _, key in pairs(fields) do style[key] = resetStyle[key] end end
            elseif fields[call.name] then
                local value = call.name == "fn" and call.value or Core.finiteNumber(call.value)
                if call.name == "fs" and value and call.value:match("^[+-]") then
                    value = (Core.finiteNumber(style.fontsize) or 0) * (1 + value / relativeFontDivisor)
                end
                if (call.name == "fs" and (not value or value <= 0)) or (call.name == "fn" and (value == "" or value == "0")) then
                    value = resetStyle and resetStyle[fields[call.name]]
                end
                if value ~= nil then
                    if booleans[call.name] then value = value ~= 0 end
                    style[fields[call.name]] = value
                end
            end
        end
    end
    return style, resetStyle
end
function Context.effectiveTags(line, ASS, lineClass, options)
    local probe = copy(line)

    local chunks, cursor = {}, 1
    local source = tostring(line.text or "")
    for _, call in ipairs(LineOps.tagCalls(source, {"bord", "shad", "alpha"})) do
        if call.top_level then
            chunks[#chunks + 1] = source:sub(cursor, call.start - 1)
            if call.name == "alpha" then
                for channel = 1, 4 do chunks[#chunks + 1] = "\\" .. channel .. "a" .. call.value end
            else
                chunks[#chunks + 1] = "\\x" .. call.name .. call.value .. "\\y" .. call.name .. call.value
            end
            cursor = call.finish + 1
        end
    end
    chunks[#chunks + 1] = source:sub(cursor)
    probe.text = table.concat(chunks)
    local parsed = ASS:parse(Context.toLine(probe, lineClass, options))
    local effectiveTags = parsed:getEffectiveTags(-1, true, true, true)
    local tags = parsed:getDefaultTags(effectiveTags.reset).tags
    for name, tag in pairs(effectiveTags.tags) do tags[name] = tag end
    return tags
end

function Context.sampleTransforms(line, offset, ASS, lineClass, options)
    local text = tostring(line.text or "")
    local duration = (finite(line.end_time) or 0) - (finite(line.start_time) or 0)
    local function effective(prefix)
        local probe = copy(line)
        probe.text = prefix .. "}"
        return Context.effectiveTags(probe, ASS, lineClass, options)
    end
    local function interpolate(target, base, factor)
        assert(base, "No effective value for transform tag " .. tostring(target.__tag.name))
        if target.class == ASS.Tag.Color then
            local result = base:copy()
            for _, channel in ipairs({"r", "g", "b"}) do
                result[channel] = base[channel]:lerp(target[channel], factor):floor()
            end
            return result
        elseif target.class == ASS.Tag.ClipRect then
            local result = base:copy()
            result.topLeft = base.topLeft:lerp(target.topLeft, factor)
            result.bottomRight = base.bottomRight:lerp(target.bottomRight, factor)
            return result
        end
        assert(type(base.lerp) == "function", "Unsupported transform tag " .. tostring(target.__tag.name))
        local result = base:lerp(target, factor)
        if target.__tag.name:match("^alpha") then result:floor() end
        if target.__tag.name == "blur_edges" then result.value = math.floor(result.value + 0.5) end
        return result
    end
    local function serialize(tag)
        local name = tag.__tag.name
        local spelling = ASS.tagMap[name].overrideName
        if tag.class == ASS.Tag.ClipRect then
            return string.format("%s(%.9f,%.9f,%.9f,%.9f)", spelling,
                tag.topLeft.x, tag.topLeft.y, tag.bottomRight.x, tag.bottomRight.y)
        elseif type(tag.value) == "number" and not name:match("^alpha") then
            return spelling .. string.format("%.9f", tag.value):gsub("0+$", ""):gsub("%.$", "")
        end
        return tostring(tag)
    end
    local evaluate
    evaluate = function(value, prefix)
        local transform, err = Context.transform(value, duration, offset)
        assert(transform, err)
        local result = {}
        for _, token in ipairs(LineOps.overrideTokens(transform.payload)) do
            if token.name == "t" then
                result[#result + 1] = evaluate(token.value, prefix .. table.concat(result))
            else
                local parsed = ASS.Section.Tag(token.raw)
                for _, target in ipairs(parsed.tags) do
                    local props = target.__tag
                    if props.transformable then
                        local initial = effective(prefix .. table.concat(result))
                        local children = props.name == "outline" and {"outline_x", "outline_y"}
                            or props.name == "shadow" and {"shadow_x", "shadow_y"} or props.children
                        if children then
                            for _, child in ipairs(children) do
                                local childTarget = ASS:createTag(child, target:get())
                                result[#result + 1] = serialize(interpolate(childTarget, initial[child], transform.factor))
                            end
                        else
                            result[#result + 1] = serialize(interpolate(target, initial[props.name], transform.factor))
                        end
                    else
                        result[#result + 1] = tostring(target)
                    end
                end
            end
        end
        return table.concat(result)
    end
    local output, cursor = {}, 1
    for _, call in ipairs(LineOps.tagCalls(text, "t")) do
        if call.top_level then
            output[#output + 1] = text:sub(cursor, call.start - 1)
            output[#output + 1] = evaluate(call.value, table.concat(output))
            cursor = call.finish + 1
        end
    end
    output[#output + 1] = text:sub(cursor)
    return table.concat(output)
end

function Context.sampleFade(line, text, offset)
    local duration = line.end_time - line.start_time
    local fade
    for _, call in ipairs(LineOps.tagCalls(text, {"fad", "fade"})) do
        if call.top_level then
            local values, valid = {}, true
            for i, value in ipairs(LineOps.splitArguments(call.value)) do
                values[i] = finite(value)
                if not values[i] then valid = false end
            end
            if valid and ((call.name == "fad" and #values == 2) or (call.name == "fade" and #values == 7)) then
                if call.name == "fad" then values = {255, 0, 255, 0, values[1], duration - values[2], duration} end
                local a1,a2,a3,t1,t2,t3,t4 = unpack(values)
                if offset < t1 then fade = a1
                elseif offset < t2 then fade = a1 + (a2 - a1) * (offset - t1) / (t2 - t1)
                elseif offset < t3 then fade = a2
                elseif offset < t4 then fade = a2 + (a3 - a2) * (offset - t3) / (t4 - t3)
                else fade = a3 end
                fade = math.floor(fade)
                break
            end
        end
    end
    if not fade then return text end
    local ctx = Context.resolve(line)
    local style = ctx.style
    local function alpha(value)
        return math.max(0, math.min(255, value - math.floor((value * fade + 127) / 255) + fade))
    end
    local function defaults(channel)
        assert(style, "The line style is required to sample its fade.")
        local chunks = {}
        for i = channel or 1, channel or 4 do
            local value = tonumber(tostring(style["color" .. i] or ""):match("&[Hh](%x%x)%x%x%x%x%x%x"), 16) or 0
            chunks[#chunks + 1] = string.format("\\%da&H%02X&", i, alpha(value))
        end
        return table.concat(chunks)
    end
    local chunks, cursor = {}, 1
    if fade > 0 then chunks[1] = "{" .. defaults() .. "}" end
    for _, call in ipairs(LineOps.tagCalls(text, {"fad", "fade", "alpha", "1a", "2a", "3a", "4a", "r"})) do
        if call.top_level then
            chunks[#chunks + 1] = text:sub(cursor, call.start - 1)
            if call.name == "r" then
                style = ctx.styles[call.value] or ctx.style
                chunks[#chunks + 1] = call.raw .. (fade > 0 and defaults() or "")
            elseif call.name ~= "fad" and call.name ~= "fade" then
                local value = tonumber(call.value:match("&[Hh](%x+)"), 16)
                if fade <= 0 then chunks[#chunks + 1] = call.raw
                elseif value then chunks[#chunks + 1] = string.format("\\%s&H%02X&", call.name, alpha(value % 256))
                else chunks[#chunks + 1] = defaults(tonumber(call.name:sub(1, 1))) end
            end
            cursor = call.finish + 1
        end
    end
    chunks[#chunks + 1] = text:sub(cursor)
    return table.concat(chunks)
end

function Context.line2fbf(data, util, ASS)
    local Media = require("kite.Media")
    local line = data.line
    local first, finish = Context.frameRange(line)
    assert(first and finish, "The line covers no loaded video frames.")
    local lineClass = assert(line.__class, "FBF requires an a-mo.Line instance.")
    local output = {}
    local sourceStart = math.floor(((finite(line.start_time) or 0) + 5) / 10) * 10
    for frame = first, finish - 1 do
        local sample = lineClass(line, line.parentCollection, {})
        sample.extra = type(sample.extra) == "table" and sample.extra or {}
        local now = util.exact_ms_from_frame(frame) - sourceStart
        sample.text = Context.sampleTransforms(line, now, ASS, lineClass)
        sample.text = Context.samplePosition(sample.text, line.end_time - line.start_time, now)
        sample.text = Context.sampleFade(line, sample.text, now)
        sample.startFrame, sample.endFrame = frame, frame + 1
        sample.start_time, sample.end_time = Media.msFromFrame(frame), Media.msFromFrame(frame + 1)
        sample.duration = sample.end_time - sample.start_time
        output[#output + 1] = sample
    end
    return output
end

Context.styleBake = (function()
local styleDefaults = {
    fontname = "Arial",
    fontsize = 20,
    color1 = "&H00FFFFFF&",
    color2 = "&H000000FF&",
    color3 = "&H00000000&",
    color4 = "&H00000000&",
    bold = false,
    italic = false,
    underline = false,
    strikeout = false,
    scale_x = 100,
    scale_y = 100,
    spacing = 0,
    angle = 0,
    outline = 2,
    shadow = 0,
    align = 2,
    encoding = 1,
}

local tagOptions = {
    { key = "fontname", default = false },
    { key = "fontsize", default = false },
    { key = "bold", default = true },
    { key = "italic", default = true },
    { key = "underline", default = true },
    { key = "strikeout", default = true },
    { key = "scale_x", default = false },
    { key = "scale_y", default = false },
    { key = "spacing", default = true },
    { key = "angle", default = true },
    { key = "outline", default = true },
    { key = "shadow", default = true },
    { key = "color1", default = true },
    { key = "color2", default = false },
    { key = "color3", default = true },
    { key = "color4", default = true },
    { key = "alpha1", default = true },
    { key = "alpha2", default = true },
    { key = "alpha3", default = true },
    { key = "alpha4", default = true },
    { key = "align", default = true },
    { key = "encoding", default = false },
}

local function styleKey(value)
    return LineOps.trim(value):lower()
end

local function styleValue(style, field)
    local value = style[field]
    if value == nil then value = styleDefaults[field] end
    return value
end

local function formatNumber(value, fallback)
    local styleDecimals = 6
    return Core.formatNumber(value, styleDecimals, fallback)
end

local function formatBoolean(value)
    if type(value) == "boolean" then return value and "1" or "0" end
    local number = tonumber(value)
    if number ~= nil then return number ~= 0 and "1" or "0" end
    local normalized = tostring(value or ""):lower()
    return (normalized == "true" or normalized == "yes" or normalized == "on") and "1" or "0"
end

local function colorAndAlpha(value, fallback)
    local color = Color.normalizeStrict(value)
    if not color then value, color = fallback, Color.normalize(fallback) end
    local alpha = tostring(value or ""):match("^&[Hh](%x%x)%x%x%x%x%x%x&?$")
    if type(value) == "number" then
        local byteBase, colorBytes = 256, 3
        alpha = string.format("%02X", math.floor(value / byteBase ^ colorBytes) % byteBase)
    end
    return color, "&H" .. (alpha or "00"):upper() .. "&"
end

local function collectStyles(subs)
    local exact, folded = {}, {}
    for index = 1, #subs do
        local line = subs[index]
        if type(line) == "table" and line.class == "style" then
            exact[tostring(line.name or "")] = line
            folded[styleKey(line.name)] = line
        end
    end
    return exact, folded
end

local function findStyle(exact, folded, name)
    return exact[tostring(name or "")] or folded[styleKey(name)]
end

local function scanLineTags(text)
    local present = {}
    local flags = { transform = false, reset = false }

    local tagFamilies = {
        fn = "fontname",
        fs = "fontsize",
        b = "bold",
        i = "italic",
        u = "underline",
        s = "strikeout",
        fscx = "scale_x",
        fscy = "scale_y",
        fsp = "spacing",
        fr = "angle",
        frz = "angle",
        bord = "outline",
        xbord = "outline",
        ybord = "outline",
        shad = "shadow",
        xshad = "shadow",
        yshad = "shadow",
        c = "color1",
        ["1c"] = "color1",
        ["2c"] = "color2",
        ["3c"] = "color3",
        ["4c"] = "color4",
        ["1a"] = "alpha1",
        ["2a"] = "alpha2",
        ["3a"] = "alpha3",
        ["4a"] = "alpha4",
        a = "align",
        an = "align",
        fe = "encoding",
    }

    for _, call in ipairs(LineOps.tagCalls(text)) do
        local name = call.name
        if name == "t" then flags.transform = true end
        if name == "r" and call.top_level then flags.reset = true end

        local family = tagFamilies[name]
        if family then present[family] = true end

        if name == "alpha" or name == "fad" or name == "fade" then
            present.alpha1 = true
            present.alpha2 = true
            present.alpha3 = true
            present.alpha4 = true
        end
    end

    return present, flags
end

local function scanSelection(selectedLines)
    local stats = {lines = #selectedLines, transforms = 0, resets = 0}
    for _, item in ipairs(selectedLines) do
        LineOps.checkCancelled()
        local flags
        item.present, flags = scanLineTags(item.line.text)
        if flags.transform then stats.transforms = stats.transforms + 1 end
        if flags.reset then stats.resets = stats.resets + 1 end
    end
    return stats
end

local function parseIgnoredAlignments(value)
    local ignored = {}
    for token in tostring(value or ""):gmatch("[^,%s;]+") do
        local number = finite(token)
        if not number or number < 1 or number > 9 or number ~= math.floor(number) then return nil end
        ignored[tostring(number)] = true
    end
    return ignored
end

local function styleTags(style, options, present, ignoredAlignments)
    local colors, alphas = {}, {}
    for channel = 1, 4 do
        colors[channel], alphas[channel] = colorAndAlpha(
            styleValue(style, "color" .. channel),
            styleDefaults["color" .. channel]
        )
    end

    present = present or {}
    local tags = {}

    local function add(key, tag, value, zero)
        if not options[key] then return end
        if key == "align" and present.align then return end
        if options.protect_existing and present[key] then return end
        if options.omit_zero and zero then return end
        tags[#tags + 1] = "\\" .. tag .. value
    end

    local fontname = tostring(styleValue(style, "fontname"))
    add("fontname", "fn", fontname, LineOps.trim(fontname) == "")

    local function addNumber(key, tag, field)
        local raw = styleValue(style, field)
        local number = formatNumber(finite(raw) or styleDefaults[field], styleDefaults[field])
        add(key, tag, number, number == "0")
    end

    local function addBoolean(key, tag, field)
        local value = formatBoolean(styleValue(style, field))
        add(key, tag, value, value == "0")
    end

    addNumber("fontsize", "fs", "fontsize")
    addBoolean("bold", "b", "bold")
    addBoolean("italic", "i", "italic")
    addBoolean("underline", "u", "underline")
    addBoolean("strikeout", "s", "strikeout")
    addNumber("scale_x", "fscx", "scale_x")
    addNumber("scale_y", "fscy", "scale_y")
    addNumber("spacing", "fsp", "spacing")
    addNumber("angle", "frz", "angle")
    addNumber("outline", "bord", "outline")
    addNumber("shadow", "shad", "shadow")

    for channel = 1, 4 do
        local colorKey = "color" .. channel
        local alphaKey = "alpha" .. channel
        add(colorKey, channel .. "c", colors[channel], false)
        add(alphaKey, channel .. "a", alphas[channel], alphas[channel] == "&H00&")
    end

    local alignment = formatNumber(styleValue(style, "align"), styleDefaults.align)
    if not ignoredAlignments[alignment] then
        add("align", "an", alignment, alignment == "0")
    end
    addNumber("encoding", "fe", "encoding")

    return table.concat(tags)
end

local function eachReset(text, callback)
    for _, call in ipairs(LineOps.tagCalls(text, "r")) do
        if call.top_level then callback(LineOps.trim(call.value)) end
    end
end

local function expandResets(text, baseStyle, exact, folded, options, present, ignoredAlignments)
    if not options.expand_resets then return tostring(text or "") end
    local resetOptions = copy(options)
    resetOptions.align = false
    local expanded = LineOps.mapTagCalls(text, "r", function(call)
        local requested = LineOps.trim(call.value)
        local resetStyle = requested == "" and baseStyle or findStyle(exact, folded, requested)
        return call.raw .. styleTags(resetStyle, resetOptions, present, ignoredAlignments)
    end)
    return expanded
end

local function showError(message)
    return require("kite.UI").message(message)
end

local labels = {
    en={title="Style to Tags", summary="%d lines  |  %d transforms  |  %d resets", fields="Style values", rules="Existing effects", protect="Keep families already used by the line", zero="Omit zero values", resets="Apply selected values after style resets", align="Skip these style alignments", apply="Apply",cancel="Cancel",empty="Select at least one style value.",invalid="Use alignment integers from 1 to 9, separated by spaces or commas.",save="Could not save preferences.",hint="Existing override tags keep their priority. Margins and BorderStyle remain style properties."},
    es={title="Estilo a tags",summary="%d líneas  |  %d transformaciones  |  %d resets",fields="Valores del estilo",rules="Efectos existentes",protect="Conservar familias que la línea ya utiliza",zero="Omitir valores cero",resets="Aplicar los valores elegidos después de resets",align="Omitir estas alineaciones del estilo",apply="Aplicar",cancel="Cancelar",empty="Selecciona al menos un valor del estilo.",invalid="Usa alineaciones enteras de 1 a 9, separadas por espacios o comas.",save="No se pudieron guardar las preferencias.",hint="Los tags existentes conservan su prioridad. Los márgenes y BorderStyle siguen perteneciendo al estilo."},
    pt={title="Estilo para tags",summary="%d linhas  |  %d transformações  |  %d resets",fields="Valores do estilo",rules="Efeitos existentes",protect="Preservar famílias já usadas pela linha",zero="Omitir valores zero",resets="Aplicar os valores após resets de estilo",align="Ignorar estes alinhamentos do estilo",apply="Aplicar",cancel="Cancelar",empty="Selecione pelo menos um valor do estilo.",invalid="Use alinhamentos inteiros de 1 a 9, separados por espaços ou vírgulas.",save="Não foi possível salvar as preferências.",hint="As tags existentes mantêm prioridade. Margens e BorderStyle continuam no estilo."},
}
local fieldLabels = {
    en={"Font","Size","Bold","Italic","Underline","Strikeout","Scale X","Scale Y","Spacing","Rotation","Outline","Shadow","Primary color","Secondary color","Outline color","Shadow color","Primary alpha","Secondary alpha","Outline alpha","Shadow alpha","Alignment","Encoding"},
    es={"Fuente","Tamaño","Negrita","Cursiva","Subrayado","Tachado","Escala X","Escala Y","Espaciado","Rotación","Borde","Sombra","Color primario","Color secundario","Color de borde","Color de sombra","Alfa primario","Alfa secundario","Alfa de borde","Alfa de sombra","Alineación","Codificación"},
    pt={"Fonte","Tamanho","Negrito","Itálico","Sublinhado","Riscado","Escala X","Escala Y","Espaçamento","Rotação","Borda","Sombra","Cor primária","Cor secundária","Cor da borda","Cor da sombra","Alfa primário","Alfa secundário","Alfa da borda","Alfa da sombra","Alinhamento","Codificação"},
}

local function chooseOptions(stats, context)
    context=context or {}
    local language=labels[context.language] and context.language or "en"
    local text=labels[language]
    local defaults={protect_existing=true,omit_zero=true,expand_resets=true,ignored_alignments="3"}
    for _,option in ipairs(tagOptions) do defaults[option.key]=option.default end
    local store=require("kite.Settings").open("kite.RheaSigns","2.1.0",{styleTags=defaults})
    local state=store:values("styleTags")
    local columns,columnWidth=4,10
    local width=columns*columnWidth
    while true do
        local dialog={
            {class="label",label=text.title,x=0,y=0,width=width,height=1},
            {class="label",label=string.format(text.summary,stats.lines,stats.transforms,stats.resets),x=0,y=1,width=width,height=1},
            {class="label",label=text.fields,x=0,y=3,width=width,height=1},
        }
        for index,option in ipairs(tagOptions) do
            dialog[#dialog+1]={class="checkbox",name=option.key,label=fieldLabels[language][index],value=state[option.key],x=(index-1)%columns*columnWidth,y=4+math.floor((index-1)/columns),width=columnWidth,height=1}
        end
        local row=5+math.ceil(#tagOptions/columns)
        dialog[#dialog+1]={class="label",label=text.rules,x=0,y=row,width=width,height=1}
        for index,rule in ipairs({{"protect_existing","protect"},{"omit_zero","zero"},{"expand_resets","resets"}}) do
            dialog[#dialog+1]={class="checkbox",name=rule[1],label=text[rule[2]],value=state[rule[1]],x=0,y=row+index,width=width,height=1}
        end
        dialog[#dialog+1]={class="label",label=text.align,x=0,y=row+4,width=width-columnWidth,height=1}
        dialog[#dialog+1]={class="edit",name="ignored_alignments",value=state.ignored_alignments,x=width-columnWidth,y=row+4,width=columnWidth,height=1}
        dialog[#dialog+1]={class="label",label=text.hint,x=0,y=row+6,width=width,height=2}
        local display=context.dialog or aegisub.dialog.display
        local button,result=display(dialog,{text.apply,text.cancel},{ok=text.apply,close=text.cancel})
        if button~=text.apply then return nil end
        for key,value in pairs(result or {}) do state[key]=value end
        local selected=false
        for _,option in ipairs(tagOptions) do if state[option.key] then selected=true;break end end
        local ignored=parseIgnoredAlignments(state.ignored_alignments)
        if selected and ignored then
            store:update("styleTags",state)
            local ok,written,err=pcall(store.write,store)
            if not ok or written==false then require("kite.UI").message(text.save .. "\n" .. tostring(ok and err or written)) end
            return state,ignored
        end
        require("kite.UI").message(selected and text.invalid or text.empty,{button=text.apply})
    end
end

local function taggerize(subs, selection, context)
    local exact, folded = collectStyles(subs)
    local records = LineOps.selectedLines(subs, selection, function(line)
        return type(line) == "table" and line.class == "dialogue"
    end)
    local selectedLines, selectedIndices = {}, {}
    local missing, missingSeen = {}, {}

    local function requireStyle(name)
        local style = findStyle(exact, folded, name)
        if not style then
            local key = styleKey(name)
            if not missingSeen[key] then
                local cleanName = LineOps.trim(name)
                missing[#missing + 1] = cleanName ~= "" and cleanName or "Default"
                missingSeen[key] = true
            end
        end
        return style
    end

    for _, record in ipairs(records) do
        LineOps.checkCancelled()
        local line = record.line
        local baseName = LineOps.trim(line.style)
        if baseName == "" then baseName = "Default" end
        local baseStyle = requireStyle(baseName)
        selectedIndices[#selectedIndices + 1] = record.index
        selectedLines[#selectedLines + 1] = {
            index = record.index,
            line = line,
            style = baseStyle,
        }
    end

    if #selectedLines == 0 then
        return {}
    end

    if #missing > 0 then
        table.sort(missing)
        showError(((context and context.language=="es") and "No se encontraron estos estilos:\n\n" or (context and context.language=="pt") and "Estilos não encontrados:\n\n" or "Styles were not found:\n\n") .. table.concat(missing, "\n"))
        aegisub.cancel()
    end

    local stats = scanSelection(selectedLines)
    local options, ignoredAlignments = chooseOptions(stats, context)
    if not options then return selectedIndices end
    if options.expand_resets then
        for _, item in ipairs(selectedLines) do
            eachReset(item.line.text, function(name) if name ~= "" then requireStyle(name) end end)
        end
        if #missing > 0 then
            table.sort(missing)
            local language = context and context.language
            local message = language == "es" and "No se encontraron estos estilos:" or language == "pt" and "Estilos não encontrados:" or "Styles were not found:"
            showError(message .. "\n\n" .. table.concat(missing, "\n"))
            return selectedIndices
        end
    end
    local updates = {}

    for _, item in ipairs(selectedLines) do
        LineOps.checkCancelled()
        local line = item.line
        local original = tostring(line.text or "")
        local text = expandResets(
            original, item.style, exact, folded,
            options, item.present, ignoredAlignments
        )
        local tags = styleTags(item.style, options, item.present, ignoredAlignments)
        local updated = LineOps.prependTag(text, tags)
        if updated ~= original then
            local changedLine = LineOps.copy(line)
            changedLine.text = updated
            updates[#updates + 1] = {
                index = item.index,
                line = changedLine,
            }
        end
    end

    if #updates > 0 then
        LineOps.transaction(subs, "Style to Tags", function()
            for _, update in ipairs(updates) do
                LineOps.checkCancelled()
                subs[update.index] = update.line
            end
        end)
    end

    return selectedIndices
end

local function canRun(subs, selection)
    return #LineOps.normalizeIndices(subs, selection, function(line)
        return type(line) == "table" and line.class == "dialogue"
    end) > 0
end

return {run=taggerize,canRun=canRun,fromStyle=styleTags,collectStyles=collectStyles}
end)()

if depctrl then Context.version = depctrl; return depctrl:register(Context) end
return Context
