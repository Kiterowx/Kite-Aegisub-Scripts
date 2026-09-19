script_name        = "Zheus Colormanager"
script_description = "Gestor de color por actor, VSF y paletas accesibles"
script_author      = "Kiterow"
script_version     = "4.7.3"
script_namespace   = "kite.Zheus"

local DependencyControl = require("l0.DependencyControl")
local depRec = DependencyControl{
    name = script_name,
    description = script_description,
    author = script_author,
    version = script_version,
    namespace = script_namespace,
    feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    {
        { "kite.PyBridge", version = "1.7.2",
          url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
        { "kite.Core", version = "1.1.0",
          url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
        { "kite.LineOps", version = "1.7.4",
          url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
        {"kite.Color", version = "1.2.2"},
        {"kite.UI", version = "1.5.1"},
        {"kite.AssContext", version = "1.1.3"},
        {"kite.Settings", version = "1.0.1"},
    },
}
local PyBridge, Core, LineOps = depRec:requireModules()
local AssContext = require("kite.AssContext")
local Color = require("kite.Color")
local KiteUI = require("kite.UI")
local Settings = require("kite.Settings")

local menuPath = "Zheus Colormanager"
local hotkeyMenuRoot = ": Kite Hotkeys :"
local hotkeyMenuScript = script_name
local hotkeyMenuPath = hotkeyMenuRoot .. "/" .. hotkeyMenuScript

local colorWhite = "&HFFFFFF&"
local colorBlack = "&H000000&"
local assColorModulo = 0x1000000
local assAlphaModulo = 4294967296
local assSignedColorMin = -2147483648
local assUnsignedColorMax = assAlphaModulo - 1
local uiActorsPerPage = 8
local wcagFail = 3.0
local wcagAa   = 4.5
local contrastCritical = 2.5
local intervalSummaryLimit = 10
local colorCacheLimit = 4096
local actorPaletteFormatVersion = 3
local maxTimelineFrame = 2147483647
local maxFadeDurationMs = 2147483647
local emptyActorLabel = "[Actor vacío]"

local UI = {
    dashboard_width = 6,
    audit_height = 5,
    report_width = 36,
    report_height = 12,
    help_width = 36,
    help_height = 14,
    actor_label_chars = 12,
    vsf_actor_label_chars = 10,
}



local paletteScaleFactors = { 1.15, 1.35, 1.55, 0.85, 0.70, 0.55 }
local paletteScoreWeights = {
    contrast = 100,
    collision = 80,
    mono = 60,
    hue_drift = 20,
    luma_drift = 20,
}

local finiteNumber = Core.finiteNumber
local trim = Core.trim

local function actorLabel(actor)
    actor = tostring(actor or "")
    return actor == "" and emptyActorLabel or actor
end

local function actorPreview(actor,limit)
    local units=LineOps.graphemes(actorLabel(actor))
    if #units<=limit then return table.concat(units) end
    return table.concat(units,"",1,limit).."…"
end

local function isDialogueLine(line)
    return type(line) == "table" and (line.class == nil or line.class == "dialogue")
end

local function collectStyles(subs)
    local styles = {}
    for i = 1, #subs do
        local l = subs[i]
        if l.class == "style" then styles[l.name] = l end
    end
    return styles
end

local ColorUtil = Color

local patHexToken  = "&[Hh]%x+&?"

local slotKeys = { "1", "2", "3", "4" }
local slotLabels = { ["1"] = "\\c", ["2"] = "\\2c", ["3"] = "\\3c", ["4"] = "\\4c" }
local vsfTags   = { "1vc", "2vc", "3vc", "4vc" }
local quickVsfTags = vsfTags
local colorKeys = { ["1"] = "c", ["2"] = "2c", ["3"] = "3c", ["4"] = "4c" }

local function defaultSlotFilter()
    return { ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true }
end

local function slotFilterFromConfig(cfg, prefix)
    cfg = cfg or {}
    prefix = prefix or "replace_slot_"
    local out = {}
    for _, slot in ipairs(slotKeys) do
        local v = cfg[prefix .. slot]
        out[slot] = (v == nil) and true or v == true
    end
    return out
end

local function writeSlotFilterToTable(t, slots, prefix)
    t = t or {}
    slots = slots or defaultSlotFilter()
    prefix = prefix or "replace_slot_"
    for _, slot in ipairs(slotKeys) do
        t[prefix .. slot] = slots[slot] == true
    end
    return t
end

local function sameSlotFilter(a, b)
    a = a or {}
    b = b or {}
    for _, slot in ipairs(slotKeys) do
        if (a[slot] == true) ~= (b[slot] == true) then return false end
    end
    return true
end

local function anySlotSelected(slots)
    slots = slots or {}
    for _, slot in ipairs(slotKeys) do
        if slots[slot] then return true end
    end
    return false
end

local function slotFilterLabel(slots)
    slots = slots or {}
    local out = {}
    for _, slot in ipairs(slotKeys) do
        if slots[slot] then table.insert(out, slotLabels[slot]) end
    end
    return #out > 0 and table.concat(out, ", ") or "ninguno"
end

local function cleanupTransforms(text)
    return LineOps.mapTagCalls(text, nil, function(call)
        if call.name ~= "t" then return nil end
        local body = cleanupTransforms("{\\" .. call.value:sub(2, -2) .. "}"):sub(3, -2)
        if not body:find("\\", 1, true) then return "" end
        return "\\t(" .. body .. ")"
    end)
end



local TagStripper = {}

function TagStripper.colorSlot(name)
    local slot = name:match("^([1-4]?)c$") or name:match("^([1-4]?)vc$")
    if slot then return slot == "" and "1" or slot end
end

function TagStripper.clearSlots(text, slots, firstBlock)
    text = LineOps.mapTagCalls(tostring(text or ""), nil, function(call)
        local slot = TagStripper.colorSlot(call.name)
        if slot and (not slots or slots[slot]) and (not firstBlock or call.block_start == firstBlock) then
            return ""
        end
    end, {top_level_only=false})
    return (cleanupTransforms(text):gsub("{%s*}", ""))
end

function TagStripper.clearColors(text)
    return TagStripper.clearSlots(text)
end

local injectFirstTags = LineOps.prependTag

function TagStripper.afterResets(text, payload)
    return LineOps.mapTagCalls(text, nil, function(call)
        if call.name == "r" then return call.raw .. payload end
    end)
end

function TagStripper.setPalette(text, payload)
    return injectFirstTags(TagStripper.afterResets(text, payload), payload)
end

local function stripSolidSlotsFromFirstBlock(text)
    for _, part in ipairs(LineOps.scanSections(text)) do
        if part.type == "override" then
            return TagStripper.clearSlots(text, {["1"]=true,["3"]=true,["4"]=true}, part.start)
        elseif (part.type == "text" or part.type == "drawing") and part.text ~= "" then break end
    end
    return text
end

local function stripSpecificColor(text, slot)
    return TagStripper.clearSlots(text, {[slot]=true})
end

function TagStripper.dedupeColors(text)
    local previous, removed, block = {}, {}, nil
    for _, call in ipairs(LineOps.tagCalls(text)) do
        if call.top_level then
            if call.block_start ~= block or call.name == "r" or call.name == "t" then previous = {} end
            block = call.block_start
            local slot = TagStripper.colorSlot(call.name)
            if slot then
                local key = slot .. (call.name:find("vc", 1, true) and "vc" or "c")
                if previous[key] then removed[previous[key]] = true end
                previous[key] = call.start
                previous[slot .. (key:find("vc", 1, true) and "c" or "vc")] = nil
            end
        end
    end
    return LineOps.mapTagCalls(text, nil, function(call)
        if removed[call.start] then return "" end
    end)
end

function TagStripper.replaceSolidColors(text, fill, outline, shadow)
    local colors = {["1"]=Color.normalize(fill),["3"]=Color.normalize(outline),["4"]=Color.normalize(shadow)}
    text = LineOps.mapTagCalls(text, nil, function(call)
        local slot = call.name:match("^([1-4]?)c$")
        slot = slot == "" and "1" or slot
        if colors[slot] then return "\\" .. call.name .. colors[slot] end
    end, {top_level_only=false})
    return text
end

function UI.textHeight(text, maximum)
    local rows = 0
    for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
        rows = rows + math.max(1, math.ceil(#line / 90))
    end
    return math.max(3, math.min(maximum, rows))
end

local ColorDialogs = {}

function ColorDialogs.editMapping(title,colors,pending,options)
    options=options or {}
    local page=1
    local slots=options.slots and Core.copy(options.slots)
    local fade=options.fade
    local pages=math.max(1,math.ceil(#colors/uiActorsPerPage))
    while true do
        local ui={
            {class="label",label=title,x=0,y=0,width=8},
            {class="label",label="Página "..page.."/"..pages.." · "..#colors.." colores",x=0,y=1,width=8},
        }
        local row=2
        if slots then
            for index,slot in ipairs(slotKeys) do
                ui[#ui+1]={class="checkbox",name="replace_slot_"..slot,label=slotLabels[slot],value=slots[slot],x=(index-1)*2,y=row,width=2}
            end
            row=row+1
        end
        if fade then
            ui[#ui+1]={class="label",label="Fundido (ms o Nf)",x=0,y=row,width=4}
            ui[#ui+1]={class="edit",name="fade",text=fade,x=4,y=row,width=4}
            row=row+1
        end
        ui[#ui+1]={class="label",label="Actual",x=0,y=row,width=4}
        ui[#ui+1]={class="label",label="Nuevo",x=4,y=row,width=4}
        local first,last=(page-1)*uiActorsPerPage+1,math.min(page*uiActorsPerPage,#colors)
        for index=first,last do
            local color=colors[index]
            row=row+1
            ui[#ui+1]={class="label",label=Color.toHex(color),x=0,y=row,width=4}
            ui[#ui+1]={class="color",name="color"..index,value=Color.toHex(pending[color] or color),x=4,y=row,width=4}
        end
        if #colors==0 then ui[#ui+1]={class="label",label="No se detectaron colores en los canales activos.",x=0,y=row+1,width=8} end
        local buttons={"Aplicar"}
        if pages>1 then buttons[#buttons+1]="Anterior";buttons[#buttons+1]="Siguiente" end
        if slots then buttons[#buttons+1]="Actualizar" end
        buttons[#buttons+1]="Volver"
        if options.skip then buttons[#buttons+1]="Omitir" end
        buttons[#buttons+1]="Cancelar"
        local button,result=aegisub.dialog.display(ui,buttons,{ok="Aplicar",cancel="Cancelar",close="Cancelar"})
        result=result or {}
        if not button or button=="Cancelar" then return "Cancelar",pending,{slots=slots,fade=fade} end
        for index=first,last do
            local color=Color.normalizeStrict(result["color"..index])
            if color then pending[colors[index]]=color end
        end
        fade=result.fade or fade
        if slots then
            local changed=slotFilterFromConfig(result)
            if not sameSlotFilter(slots,changed) then button="Actualizar" end
            slots=changed
        end
        if button=="Anterior" then page=math.max(1,page-1)
        elseif button=="Siguiente" then page=math.min(pages,page+1)
        elseif button=="Aplicar" or button=="Actualizar" or button=="Volver" or button=="Omitir" then
            return button,pending,{slots=slots,fade=fade}
        else return "Cancelar",pending,{slots=slots,fade=fade} end
    end
end

local ColorRelay = { name = "ColorRelay", menu_name = "ColorRelay" }

function ColorRelay.showMessage(title, msg)
    return KiteUI.message(msg, {title=title or ColorRelay.name, button="Aceptar", width=36, height=UI.textHeight(msg,14)})
end

function ColorRelay.normalizeColor(c, fallback)
    return ColorUtil.normalizeStrict(c) or fallback or colorWhite
end

function ColorRelay.styleState(style)
    return {
        ColorRelay.normalizeColor(style and style.color1, colorWhite),
        ColorRelay.normalizeColor(style and style.color2, colorBlack),
        ColorRelay.normalizeColor(style and style.color3, colorBlack),
        ColorRelay.normalizeColor(style and style.color4, colorBlack),
    }
end

function ColorRelay.copyState(state)
    return { state[1], state[2], state[3], state[4] }
end

function ColorRelay.slotTag(slot)
    if slot == 1 then return "\\c" end
    return "\\" .. tostring(slot) .. "c"
end

function ColorRelay.tagsFromState(state, slots)
    local out = {}
    for slot = 1, 4 do
        if (not slots) or slots[slot] then
            out[#out + 1] = ColorRelay.slotTag(slot) ..
                ColorRelay.normalizeColor(state[slot], slot == 1 and colorWhite or colorBlack)
        end
    end
    return table.concat(out)
end

function ColorRelay.defaultSlotFilter()
    return { [1] = true, [2] = true, [3] = true, [4] = true }
end

function ColorRelay.copySlotFilter(slots)
    slots = slots or ColorRelay.defaultSlotFilter()
    return {
        [1] = slots[1] == true,
        [2] = slots[2] == true,
        [3] = slots[3] == true,
        [4] = slots[4] == true,
    }
end

function ColorRelay.toZheusSlotFilter(slots)
    slots = slots or ColorRelay.defaultSlotFilter()
    return {
        ["1"] = slots[1] == true,
        ["2"] = slots[2] == true,
        ["3"] = slots[3] == true,
        ["4"] = slots[4] == true,
    }
end

function ColorRelay.anySlotSelected(slots)
    return anySlotSelected(ColorRelay.toZheusSlotFilter(slots))
end

function ColorRelay.slotFilterLabel(slots)
    return slotFilterLabel(ColorRelay.toZheusSlotFilter(slots))
end

function ColorRelay.cleanEmptyBlocks(text)
    return (tostring(text or ""):gsub("{%s*}", ""))
end

function ColorRelay.stripColorSlots(text, slots)
    return TagStripper.clearSlots(text, ColorRelay.toZheusSlotFilter(slots))
end

function ColorRelay.originalStateAt(line, style, absMs, styles)
    local state = ColorRelay.styleState(style)
    local lineDur = math.max(0, (line.end_time or 0) - (line.start_time or 0))
    local offset = math.max(0, math.min(lineDur, (absMs or line.start_time or 0) - (line.start_time or 0)))
    local currentStyle = style
    AssContext.visitTags(line.text, lineDur, offset, function(token, factor, nested)
        if token.name == "r" and not nested then
            currentStyle = (styles and styles[trim(token.value)]) or style
            state = ColorRelay.styleState(currentStyle)
        else
            local rawSlot = token.name:match("^([1-4]?)c$")
            if rawSlot then
                local slot = tonumber(rawSlot) or 1
                local target = Color.parseTag(token.value)
                    or ColorUtil.fromStyle(currentStyle and currentStyle["color" .. slot])
                state[slot] = Color.interpolateAss(state[slot], target, factor)
            end
        end
    end)
    return state
end

function ColorRelay.applyReplacementsToState(state, replacements, slots)
    local changed = {}
    local any = false
    for slot = 1, 4 do
        if (not slots) or slots[slot] then
            local old = ColorRelay.normalizeColor(state[slot], slot == 1 and colorWhite or colorBlack)
            local new = replacements and replacements[old]
            if new and new ~= old then
                state[slot] = new
                changed[slot] = true
                any = true
            end
        end
    end
    return state, changed, any
end

function ColorRelay.frameFromMs(ms)
    if not aegisub or type(aegisub.frame_from_ms) ~= "function" then return nil end
    ms = finiteNumber(ms)
    if not ms then return nil end
    local ok, frame = pcall(aegisub.frame_from_ms, ms)
    frame = ok and finiteNumber(frame) or nil
    if frame and frame >= 0 and frame <= maxTimelineFrame then return math.floor(frame) end
    return nil
end

function ColorRelay.msFromFrame(frame)
    if not aegisub or type(aegisub.ms_from_frame) ~= "function" then return nil end
    frame = finiteNumber(frame)
    if not frame or frame < 0 or frame > maxTimelineFrame then return nil end
    frame = math.floor(frame)
    local ok, ms = pcall(aegisub.ms_from_frame, frame)
    ms = ok and finiteNumber(ms) or nil
    if ms then return ms end
    return nil
end

function ColorRelay.currentVideoFrame()
    if not aegisub or type(aegisub.project_properties) ~= "function" then return nil end
    local ok, props = pcall(aegisub.project_properties)
    if not ok or not props then return nil end
    if props.video_position == nil then return nil end
    local frame = finiteNumber(props.video_position)
    if not frame or frame < 0 or frame > maxTimelineFrame then return nil end
    return math.floor(frame)
end

function ColorRelay.collectDialogueSelection(subs, sel)
    local out = {}
    local records = LineOps.selectedLines(subs, sel, isDialogueLine)
    for _, record in ipairs(records) do
        if (record.line.end_time or 0) > (record.line.start_time or 0) then
            out[#out + 1] = record
        end
    end
    return out
end

function ColorRelay.collectIntervals(lines)
    local raw = {}
    for _, item in ipairs(lines) do
        local line = item.line
        local sf = ColorRelay.frameFromMs(line.start_time)
        local ef = ColorRelay.frameFromMs(math.max(line.start_time, line.end_time - 1))
        if sf and ef then
            if ef < sf then ef = sf end
            raw[#raw + 1] = { first = sf, last = ef }
        end
    end
    table.sort(raw, function(a, b)
        if a.first == b.first then return a.last < b.last end
        return a.first < b.first
    end)
    local merged = {}
    for _, it in ipairs(raw) do
        local last = merged[#merged]
        if last and it.first <= last.last + 1 then
            if it.last > last.last then last.last = it.last end
        else
            merged[#merged + 1] = { first = it.first, last = it.last }
        end
    end
    return merged
end

function ColorRelay.frameInIntervals(frame, intervals)
    for _, it in ipairs(intervals or {}) do
        if frame >= it.first and frame <= it.last then return true end
    end
    return false
end

function ColorRelay.intervalsSummary(intervals)
    local out = {}
    for i, it in ipairs(intervals or {}) do
        if i > intervalSummaryLimit then
            out[#out + 1] = "..."
            break
        end
        if it.first == it.last then
            out[#out + 1] = tostring(it.first)
        else
            out[#out + 1] = tostring(it.first) .. "-" .. tostring(it.last)
        end
    end
    return table.concat(out, ", ")
end

function ColorRelay.collectEffectFrames(lines, intervals)
    local seen, out = {}, {}
    for _, item in ipairs(lines) do
        local effect = tostring(item.line.effect or "")
        for tok in effect:gmatch("[^;,%s]+") do
            local raw = tok:match("^[Ff]?(%d+)$")
            if raw then
                local frame = tonumber(raw)
                if frame and ColorRelay.frameInIntervals(frame, intervals) and not seen[frame] then
                    seen[frame] = true
                    out[#out + 1] = frame
                end
            end
        end
    end
    table.sort(out)
    return out
end

function ColorRelay.defaultFrameList(lines, intervals)
    local effectFrames = ColorRelay.collectEffectFrames(lines, intervals)
    if #effectFrames > 0 then return effectFrames end
    local cur = ColorRelay.currentVideoFrame()
    if cur and ColorRelay.frameInIntervals(cur, intervals) then return { cur } end
    local out = {}
    for _, it in ipairs(intervals or {}) do out[#out + 1] = it.first end
    return out
end

function ColorRelay.parseFrameToken(token)
    token = trim(token)
    if token == "" then return nil end
    local raw = token:match("^[Ff]?(%d+)[Ff]?$")
    local frame = raw and finiteNumber(raw) or nil
    if frame and frame >= 0 and frame <= maxTimelineFrame then return math.floor(frame) end
    return nil
end

function ColorRelay.parseFadeToMs(raw, frame)
    raw = trim(raw or "")
    if raw == "" then return 0, "0" end
    local frames = raw:match("^(%d+)[Ff]$")
    if frames then
        frames = finiteNumber(frames)
        if not frames or frames ~= math.floor(frames) or frames > maxTimelineFrame then return nil, nil end
        local a = ColorRelay.msFromFrame(frame)
        local b = ColorRelay.msFromFrame(frame + frames)
        local duration = a and b and (b - a)
        duration = finiteNumber(duration)
        if not duration or duration < 0 or duration > maxFadeDurationMs then return nil, nil end
        return math.floor(duration + 0.5), tostring(frames) .. "f"
    end
    local ms = raw:match("^(%d+)%s*[Mm][Ss]$")
    if ms then
        ms = finiteNumber(ms)
        if not ms or ms > maxFadeDurationMs then return nil, nil end
        return ms, tostring(ms)
    end
    local numeric = finiteNumber(raw)
    if numeric and numeric >= 0 and numeric <= maxFadeDurationMs then return numeric, tostring(numeric) end
    return nil, nil
end

function ColorRelay.parseControlFrames(text, defaultFadeRaw, intervals)
    local events, seen, errors = {}, {}, {}
    defaultFadeRaw = trim(defaultFadeRaw or "0")

    local function addEvent(frame, fadeRaw, source)
        if not frame then errors[#errors + 1] = "Fotograma inválido: " .. tostring(source); return end
        if not ColorRelay.frameInIntervals(frame, intervals) then
            errors[#errors + 1] = "Fotograma fuera de la selección: " .. tostring(frame) .. " (" .. tostring(source or "") .. ")"
            return
        end
        if seen[frame] then errors[#errors + 1] = "Fotograma repetido: " .. tostring(frame); return end
        local ms = ColorRelay.msFromFrame(frame)
        if not ms then
            errors[#errors + 1] = "No se pudo convertir el fotograma a ms: " .. tostring(frame)
            return
        end
        local fadeMs, fadeLabel = ColorRelay.parseFadeToMs(fadeRaw or defaultFadeRaw, frame)
        if not fadeMs then
            errors[#errors + 1] = "Fundido inválido en fotograma " .. tostring(frame) .. ": " .. tostring(fadeRaw or defaultFadeRaw)
            return
        end
        seen[frame] = true
        events[#events + 1] = {
            frame = frame,
            time = ms,
            fade_ms = fadeMs,
            fade_label = fadeLabel,
            replacements = {},
        }
    end

    for rawLine in tostring(text or ""):gmatch("[^\n]+") do
        local line = trim(rawLine:gsub("^%-%-%s*", ""))
        if line ~= "" then
            local fadeRaw = line:match("%f[%a][Ff][Aa][Dd][Ee]%f[%A]%s+([^%s,;]+)")
            local withoutFade = line:gsub("%f[%a][Ff][Aa][Dd][Ee]%f[%A]%s+[^%s,;]+", "")
            if not fadeRaw then
                fadeRaw = line:match("%f[%a][Ff][Uu][Nn][Dd][Ii][Dd][Oo]%f[%A]%s+([^%s,;]+)")
            end
            withoutFade = withoutFade:gsub("%f[%a][Ff][Uu][Nn][Dd][Ii][Dd][Oo]%f[%A]%s+[^%s,;]+", "")
            local lhs = withoutFade:match("^(.-)>") or withoutFade
            if fadeRaw or line:find(">", 1, true) then
                local token = lhs:match("%S+")
                addEvent(ColorRelay.parseFrameToken(token), fadeRaw, rawLine)
            else
                for token in lhs:gmatch("[^,%s;]+") do
                    addEvent(ColorRelay.parseFrameToken(token), nil, rawLine)
                end
            end
        end
    end

    table.sort(events, function(a, b) return a.time < b.time end)
    return events, errors
end

function ColorRelay.buildFrameDefaults(defaultFrames)
    local items = {}
    for _, frame in ipairs(defaultFrames or {}) do items[#items + 1] = tostring(frame) .. "f" end
    return table.concat(items, " ")
end

function ColorRelay.promptControls(defaultFrames, intervals, state)
    state = state or {}
    local frameValue = state.frame_text or ColorRelay.buildFrameDefaults(defaultFrames)
    local fadeValue = state.default_fade or "0"
    local slotFilter = ColorRelay.copySlotFilter(state.slots)

    while true do
        local frameHeight = UI.textHeight(frameValue, 6)
        local btn, res = aegisub.dialog.display({
            { class = "label", label = "ColorRelay - fotogramas de control", x = 0, y = 0, width = 8 },
            { class = "label", label = "Selección: " .. ColorRelay.intervalsSummary(intervals), x = 0, y = 1, width = 8 },
            { class = "label", label = "Ejemplos: 120f, 130f | 120f fundido 6f | 120f > P1 fundido 6f", x = 0, y = 2, width = 8 },
            { class = "textbox", name = "frames", text = frameValue, x = 0, y = 3, width = 8, height = frameHeight },
            { class = "label", label = "Fundido (ms o Nf):", x = 0, y = 3 + frameHeight, width = 4 },
            { class = "edit", name = "fade", text = fadeValue, x = 4, y = 3 + frameHeight, width = 4 },
            { class = "checkbox", name = "slot1", label = "Relleno \\c", value = slotFilter[1], x = 0, y = 4 + frameHeight, width = 2 },
            { class = "checkbox", name = "slot2", label = "2c", value = slotFilter[2], x = 2, y = 4 + frameHeight, width = 2 },
            { class = "checkbox", name = "slot3", label = "Borde \\3c", value = slotFilter[3], x = 4, y = 4 + frameHeight, width = 2 },
            { class = "checkbox", name = "slot4", label = "Sombra \\4c", value = slotFilter[4], x = 6, y = 4 + frameHeight, width = 2 },
        }, { "Siguiente", "Cancelar" })

        if not btn or btn == "Cancelar" then return nil end
        res = res or {}
        frameValue = res.frames or ""
        fadeValue = res.fade or "0"
        slotFilter = {
            [1] = res.slot1 == true,
            [2] = res.slot2 == true,
            [3] = res.slot3 == true,
            [4] = res.slot4 == true,
        }

        if btn == "Siguiente" then
            if not ColorRelay.anySlotSelected(slotFilter) then
                ColorRelay.showMessage(ColorRelay.name, "Marca al menos un color: \\c, \\2c, \\3c o \\4c.")
            else
                return {
                    frame_text = frameValue,
                    default_fade = fadeValue,
                    slots = ColorRelay.copySlotFilter(slotFilter),
                }
            end
        end
    end
end

function ColorRelay.applyPreviousEventsToState(state, events, absMs)
    for _, ev in ipairs(events or {}) do
        if ev.time <= absMs then
            ColorRelay.applyReplacementsToState(state, ev.replacements, ev.slots)
        end
    end
    return state
end

function ColorRelay.collectActiveColors(lines, styles, event, previousEvents, slots)
    local seen, colors = {}, {}
    for _, item in ipairs(lines) do
        local line = item.line
        if event.time >= line.start_time and event.time < line.end_time then
            local state = ColorRelay.originalStateAt(line, styles[line.style], event.time, styles)
            ColorRelay.applyPreviousEventsToState(state, previousEvents, event.time)
            for slot = 1, 4 do
                if (not slots) or slots[slot] then
                    local color = ColorRelay.normalizeColor(state[slot], slot == 1 and colorWhite or colorBlack)
                    if not seen[color] then
                        seen[color] = true
                        colors[#colors + 1] = color
                    end
                end
            end
        end
    end
    return colors
end

function ColorRelay.promptReplacements(event,colors,slotFilter,index,total)
    local pending=Core.copy(event.replacements or {})
    local action,values,result=ColorDialogs.editMapping(
        string.format("ColorRelay · %sf · control %d/%d · %s",tostring(event.frame),index or 1,total or 1,ColorRelay.slotFilterLabel(slotFilter)),
        colors,pending,{fade=event.fade_label or "0",skip=true})
    if action=="Cancelar" then return "cancel" end
    event.replacements={}
    for _, color in ipairs(colors) do
        if values[color] and values[color]~=color then event.replacements[color]=values[color] end
    end
    if action=="Volver" then return "back" end
    if action=="Omitir" then return "skip" end
    local duration,label=ColorRelay.parseFadeToMs(result.fade,event.frame)
    if not duration then
        event.fade_label=result.fade
        ColorRelay.showMessage(ColorRelay.name,"Fundido inválido: "..tostring(result.fade))
        return "retry"
    end
    event.fade_ms,event.fade_label=duration,label
    return next(event.replacements) and "ok" or "skip"
end

function ColorRelay.eventWindow(event)
    local fade = math.max(0, tonumber(event.fade_ms) or 0)
    if fade <= 0 then return event.time, event.time end
    return event.time - math.floor(fade / 2), event.time + math.ceil(fade / 2)
end

function ColorRelay.sortedEffectiveEvents(events)
    local out = {}
    for _, event in ipairs(events or {}) do
        if event.replacements and next(event.replacements) then out[#out + 1] = event end
    end
    table.sort(out, function(a, b) return a.time < b.time end)
    return out
end

function ColorRelay.validateEventWindows(events)
    local bySlot = { {}, {}, {}, {} }
    for _, event in ipairs(events or {}) do
        local winStart, winEnd = ColorRelay.eventWindow(event)
        for slot = 1, 4 do
            if (not event.slots) or event.slots[slot] then
                bySlot[slot][#bySlot[slot] + 1] = { first = winStart, last = winEnd }
            end
        end
    end
    for slot = 1, 4 do
        table.sort(bySlot[slot], function(a, b)
            if a.first == b.first then return a.last < b.last end
            return a.first < b.first
        end)
        for index = 2, #bySlot[slot] do
            if bySlot[slot][index].first < bySlot[slot][index - 1].last then
                return nil, "Los fundidos de ColorRelay se solapan en el canal " .. tostring(slot) .. ". Ajusta su duración o separa los fotogramas de control."
            end
        end
    end
    return true
end

function ColorRelay.transformTouchesSlots(text, slots)
    for _, call in ipairs(LineOps.tagCalls(text)) do
        local slot = TagStripper.colorSlot(call.name)
        if slot and not call.top_level and slots[tonumber(slot)] then return true, tonumber(slot) end
    end
    return false
end

function ColorRelay.hasLateColorRun(text, slots)
    local visible = false
    for _, part in ipairs(LineOps.scanSections(text)) do
        if part.type == "text" or part.type == "drawing" then
            if part.text ~= "" then visible = true end
        elseif part.type == "override" then
            for _, call in ipairs(LineOps.tagCalls("{" .. part.text .. "}")) do
                if call.top_level then
                    local slot = TagStripper.colorSlot(call.name)
                    if visible and (call.name == "r" or (slot and slots[tonumber(slot)])) then return true end
                    if slot and slots[tonumber(slot)] and call.name:find("vc", 1, true) then return true end
                end
            end
        end
    end
    return false
end

function ColorRelay.applyEventsToSelection(subs, sel, events)
    local styles = collectStyles(subs)
    local effective = ColorRelay.sortedEffectiveEvents(events)
    if #effective == 0 then return 0 end
    local windowsOk, windowsError = ColorRelay.validateEventWindows(effective)
    if not windowsOk then return nil, windowsError end
    local selectedSlots = { false, false, false, false }
    for _, event in ipairs(effective) do
        for slot = 1, 4 do
            if (not event.slots) or event.slots[slot] then selectedSlots[slot] = true end
        end
    end
    for _, idx in ipairs(LineOps.normalizeIndices(subs, sel)) do
        local line = subs[idx]
        if isDialogueLine(line) then
            local touches, slot = ColorRelay.transformTouchesSlots(line.text, selectedSlots)
            if touches then
                return nil, "La línea " .. tostring(idx) .. " ya anima el canal de color " .. tostring(slot) .. " dentro de \\t. Divídela o fija ese color antes de usar ColorRelay."
            end
            if ColorRelay.hasLateColorRun(line.text, selectedSlots) then
                return nil, "La línea " .. tostring(idx) .. " cambia color después de iniciar el texto. Divide los runs antes de usar ColorRelay para no aplanar sus colores."
            end
        end
    end

    return LineOps.transaction(subs, function()
        local count = 0
        for _, idx in ipairs(LineOps.normalizeIndices(subs, sel)) do
            LineOps.checkCancelled()
            local source = subs[idx]
            if isDialogueLine(source) and source.end_time > source.start_time then
                local base = ColorRelay.originalStateAt(source, styles[source.style], source.start_time, styles)
                local state, touched, transforms = ColorRelay.copyState(base), {}, {}
                for _, event in ipairs(effective) do
                    local first, last = ColorRelay.eventWindow(event)
                    local _, changed, any = ColorRelay.applyReplacementsToState(state, event.replacements, event.slots)
                    if any and first < source.end_time then
                        for slot in pairs(changed) do touched[slot] = true end
                        if last <= source.start_time then
                            for slot in pairs(changed) do base[slot] = state[slot] end
                        else
                            transforms[#transforms + 1] = "\\t(" .. Core.formatNumber(first-source.start_time,6) .. "," ..
                                Core.formatNumber(last-source.start_time,6) .. ",1," .. ColorRelay.tagsFromState(state,changed) .. ")"
                        end
                    end
                end
                if next(touched) then
                    local line = Core.copy(source)
                    local payload = ColorRelay.tagsFromState(base,touched) .. table.concat(transforms)
                    line.text = TagStripper.setPalette(ColorRelay.stripColorSlots(line.text,touched),payload)
                    subs[idx] = line
                    count = count + 1
                end
            end
        end
        return count
    end)
end



function ColorRelay.run(subs, sel)
    if not sel or #sel == 0 then
        ColorRelay.showMessage(ColorRelay.name, "Selecciona líneas de diálogo.")
        return nil, "cancel"
    end
    if type(aegisub.frame_from_ms) ~= "function" or type(aegisub.ms_from_frame) ~= "function" then
        ColorRelay.showMessage(ColorRelay.name, "ColorRelay necesita vídeo cargado para convertir fotogramas y milisegundos.")
        return nil, "cancel"
    end

    local lines = ColorRelay.collectDialogueSelection(subs, sel)
    if #lines == 0 then
        ColorRelay.showMessage(ColorRelay.name, "La selección no contiene líneas de diálogo con duración.")
        return nil, "cancel"
    end

    local intervals = ColorRelay.collectIntervals(lines)
    if #intervals == 0 then
        ColorRelay.showMessage(ColorRelay.name, "No se pudo construir la línea temporal de fotogramas de la selección.")
        return nil, "cancel"
    end

    local defaults = ColorRelay.defaultFrameList(lines, intervals)
    local controlState = nil

    while true do
        controlState = ColorRelay.promptControls(defaults, intervals, controlState)
        if not controlState then return nil, "cancel" end

        local events, errors = ColorRelay.parseControlFrames(controlState.frame_text, controlState.default_fade, intervals)
        if #errors > 0 then
            ColorRelay.showMessage("ColorRelay - controles inválidos", table.concat(errors, "\n"))
        elseif #events == 0 then
            ColorRelay.showMessage(ColorRelay.name, "No hay fotogramas de control válidos.")
        else
            local styles = collectStyles(subs)
            local processed = {}
            local idx = 1
            local backToControls = false

            while idx <= #events do
                local event = events[idx]
                event.slots = ColorRelay.copySlotFilter(controlState.slots)

                local previous = {}
                for i = 1, idx - 1 do
                    if processed[i] then previous[#previous + 1] = processed[i] end
                end

                local colors = ColorRelay.collectActiveColors(lines, styles, event, previous, controlState.slots)
                local action
                repeat
                    action = ColorRelay.promptReplacements(event, colors, controlState.slots, idx, #events)
                until action ~= "retry"

                if action == "cancel" then return nil, "cancel" end
                if action == "back" then
                    event.replacements = event.replacements or {}
                    if idx == 1 then
                        backToControls = true
                        break
                    end
                    processed[idx - 1] = nil
                    idx = idx - 1
                else
                    if action == "skip" then event.replacements = {} end
                    processed[idx] = event
                    idx = idx + 1
                end
            end

            if backToControls then
            else
                local approved = {}
                for i = 1, #events do
                    local event = processed[i]
                    if event and event.replacements and next(event.replacements) then
                        approved[#approved + 1] = event
                    end
                end

                local changed, applyError = ColorRelay.applyEventsToSelection(subs, sel, approved)
                if not changed then
                    ColorRelay.showMessage(ColorRelay.name, applyError or "No se pudieron aplicar los cambios de ColorRelay.")
                    return nil, "cancel"
                end
                if changed > 0 then
                    aegisub.set_undo_point(ColorRelay.name)
                    ColorRelay.showMessage(ColorRelay.name, tostring(changed) .. " líneas actualizadas.")
                else
                    ColorRelay.showMessage(ColorRelay.name, "Cambios aplicados: 0.")
                end
                return changed, "done"
            end
        end
    end
end

local StyleScanner = {}



local function styleColors(style)
    return {
        c = style and ColorUtil.fromStyle(style.color1) or colorWhite,
        ["2c"] = style and ColorUtil.fromStyle(style.color2) or colorBlack,
        ["3c"] = style and ColorUtil.fromStyle(style.color3) or colorBlack,
        ["4c"] = style and ColorUtil.fromStyle(style.color4) or colorBlack,
    }
end

local function addCount(counts, key, lineNo)
    if not key then return end
    local item = counts[key]
    if item then
        item.count = item.count + 1
    else
        counts[key] = { count = 1, first = lineNo or 0 }
    end
end

local function countSize(counts)
    local n = 0
    for _ in pairs(counts or {}) do n = n + 1 end
    return n
end

local function dominantKey(counts, fallback)
    local best, bestData = nil, nil
    for key, data in pairs(counts or {}) do
        if not bestData
            or data.count > bestData.count
            or (data.count == bestData.count and data.first < bestData.first)
            or (data.count == bestData.count and data.first == bestData.first and tostring(key) < tostring(best)) then
            best, bestData = key, data
        end
    end
    return best or fallback
end

local function tupleKey(cols)
    if not cols then return nil end
    return table.concat(cols, "|")
end

local function tupleFromKey(key)
    local out = {}
    for col in tostring(key or ""):gmatch("[^|]+") do table.insert(out, col) end
    return #out >= 4 and { out[1], out[2], out[3], out[4] } or nil
end

local function parseVSFTuple(parens)
    local cols = {}
    for col in tostring(parens or ""):sub(2, -2):gmatch(patHexToken) do
        local n = ColorUtil.normalizeStrict(col)
        if n then table.insert(cols, n) end
    end
    if #cols == 0 then return nil end
    local last = cols[#cols]
    return {
        cols[1] or last,
        cols[2] or last,
        cols[3] or last,
        cols[4] or last,
    }
end

function StyleScanner.scanActors(subs, sel, styleMap)
    styleMap = styleMap or collectStyles(subs)
    local data, actors = {}, {}
    for _, index in ipairs(LineOps.normalizeIndices(subs,sel)) do
        LineOps.checkCancelled()
        local line = subs[index]
        if isDialogueLine(line) then
            local actor = tostring(line.actor or "")
            local baseStyle = styleMap[line.style] or styleMap.Default
            local currentStyle, colors, corners = baseStyle, styleColors(baseStyle), {}
            local entry = data[actor]
            if not entry then
                entry = {ids={}, colors=Core.copy(colors), vsf_corners={}, has_vsf=false, has_mixed=false,
                    has_vsf_mixed=false, line_count=0, conflicts={}, vsf_conflicts={}, color_runs={},vsf_present={},
                    colorCounts={}, vsfCounts={}}
                for _, slot in ipairs(slotKeys) do
                    local color = colors[colorKeys[slot]]
                    entry.vsf_corners[slot.."vc"] = {color,color,color,color}
                    entry.colorCounts[slot],entry.vsfCounts[slot.."vc"] = {},{}
                end
                data[actor],actors[#actors+1] = entry,actor
            end
            entry.ids[#entry.ids+1],entry.line_count = index,entry.line_count+1
            local recorded = false
            local function record()
                recorded = true
                entry.color_runs[#entry.color_runs+1] = {line=index,colors=Core.copy(colors),vsf=Core.deepCopy(corners),style=currentStyle}
                for _, slot in ipairs(slotKeys) do addCount(entry.colorCounts[slot],colors[colorKeys[slot]],index) end
                for tag, tuple in pairs(corners) do addCount(entry.vsfCounts[tag],tupleKey(tuple),index) end
            end
            for _, part in ipairs(LineOps.scanSections(line.text)) do
                if part.type == "override" then
                    for _, call in ipairs(LineOps.tagCalls("{"..part.text.."}")) do
                        if call.top_level then
                            if call.name == "r" then
                                currentStyle = styleMap[call.value] or baseStyle
                                colors,corners = styleColors(currentStyle),{}
                            else
                                local slot = TagStripper.colorSlot(call.name)
                                if slot then
                                    if call.name:find("vc",1,true) then
                                        local tuple = parseVSFTuple(call.value)
                                        if tuple then
                                            corners[slot.."vc"],entry.has_vsf=tuple,true
                                            entry.vsf_present[slot.."vc"]=true
                                        end
                                    else
                                        colors[colorKeys[slot]] = Color.parseTag(call.value) or styleColors(currentStyle)[colorKeys[slot]]
                                    end
                                end
                            end
                        elseif TagStripper.colorSlot(call.name) then entry.has_animated = true end
                    end
                elseif (part.type == "text" or part.type == "drawing") and part.text ~= "" then record() end
            end
            if not recorded then record() end
        end
    end
    table.sort(actors)
    for _, actor in ipairs(actors) do
        local entry = data[actor]
        for _, slot in ipairs(slotKeys) do
            local key = colorKeys[slot]
            entry.colors[key] = dominantKey(entry.colorCounts[slot],entry.colors[key])
            if countSize(entry.colorCounts[slot]) > 1 then
                entry.has_mixed = true
                for _, run in ipairs(entry.color_runs) do
                    if run.colors[key] ~= entry.colors[key] then
                        entry.conflicts[#entry.conflicts+1] = {ln=run.line,tag=slotLabels[slot],old=entry.colors[key],new=run.colors[key]}
                    end
                end
            end
        end
        for _, tag in ipairs(vsfTags) do
            local tuple = tupleFromKey(dominantKey(entry.vsfCounts[tag]))
            if tuple then entry.vsf_corners[tag] = tuple end
            if countSize(entry.vsfCounts[tag]) > 1 then
                entry.has_vsf_mixed = true
                for _, run in ipairs(entry.color_runs) do
                    if run.vsf[tag] and tupleKey(run.vsf[tag]) ~= tupleKey(tuple) then
                        entry.vsf_conflicts[#entry.vsf_conflicts+1] = {ln=run.line,tag="\\"..tag,old=tuple,new=run.vsf[tag]}
                    end
                end
            end
        end
        entry.colorCounts,entry.vsfCounts = nil,nil
    end
    return data,actors
end

local ActorReport = {}

function ActorReport.summary(actors, data)
    local lines = { "#  RESUMEN DE ACTORES", "" }
    for _, a in ipairs(actors) do
        local info = data[a]
        local ratio = ColorUtil.contrastRatio(info.colors.c, info.colors["3c"])
        local flag = info.has_mixed and "MIXTO " or ""
        if ratio < contrastCritical then
            flag = flag .. "URGENTE RC:" .. string.format("%.1f", ratio)
        elseif ratio < wcagAa then
            flag = flag .. "REVISAR RC:" .. string.format("%.1f", ratio)
        else
            flag = flag .. "BIEN RC:" .. string.format("%.1f", ratio)
        end
        table.insert(lines, string.format("%-15s  c:%s  3c:%s  [%s]",
            actorLabel(a), ColorUtil.toHex(info.colors.c), ColorUtil.toHex(info.colors["3c"]), flag))
    end
    return table.concat(lines, "\n")
end

function ActorReport.conflicts(actors, data)
    local lines = {}
    local totalChanges, totalLowCR, totalVSF, totalDup, totalVSFChanges = 0, 0, 0, 0, 0
    local function tupleText(cols)
        local out = {}
        for _, col in ipairs(cols or {}) do table.insert(out, ColorUtil.toHex(col)) end
        return table.concat(out, ",")
    end
    table.insert(lines, "# REPORTE DE CONFLICTOS")
    table.insert(lines, "")
    table.insert(lines, "== COLORES SOLIDOS ==")
    table.insert(lines, "")
    local hasChanges = false
    for _, a in ipairs(actors) do
        local info = data[a]
        if info.has_mixed and #info.conflicts > 0 then
            hasChanges = true
            table.insert(lines, "- " .. actorLabel(a) .. " (" .. info.line_count .. " líneas):")
            for _, c in ipairs(info.conflicts) do
                table.insert(lines, string.format("   Linea %d: %s cambio %s -> %s",
                    c.ln, c.tag, ColorUtil.toHex(c.old or colorWhite), ColorUtil.toHex(c.new)))
                totalChanges = totalChanges + 1
            end
            table.insert(lines, "")
        end
    end
    if not hasChanges then
        table.insert(lines, "  Cambios de color detectados: 0.")
        table.insert(lines, "")
    end
    table.insert(lines, "== VSFILTERMOD ==")
    table.insert(lines, "")
    local hasVSFChanges = false
    for _, a in ipairs(actors) do
        local info = data[a]
        if info.has_vsf_mixed and #info.vsf_conflicts > 0 then
            hasVSFChanges = true
            table.insert(lines, "- " .. actorLabel(a) .. " (" .. info.line_count .. " líneas):")
            for _, c in ipairs(info.vsf_conflicts) do
                table.insert(lines, string.format("   Linea %d: %s cambio %s -> %s",
                    c.ln, c.tag, tupleText(c.old), tupleText(c.new)))
                totalVSFChanges = totalVSFChanges + 1
            end
            table.insert(lines, "")
        end
    end
    if not hasVSFChanges then
        table.insert(lines, "  Conflictos VSF detectados: 0.")
        table.insert(lines, "")
    end
    table.insert(lines, "== CONTRASTE (c vs 3c) ==")
    table.insert(lines, "")
    for _, a in ipairs(actors) do
        local info = data[a]
        local ratio = ColorUtil.contrastRatio(info.colors.c, info.colors["3c"])
        local label
        if ratio < contrastCritical then
            label = "URGENTE"; totalLowCR = totalLowCR + 1
        elseif ratio < wcagAa then
            label = "AJUSTAR"; totalLowCR = totalLowCR + 1
        else
            label = "BIEN"
        end
        local dup = ""
        if info.colors.c == info.colors["3c"] then dup = " [c = 3c DUPLICADO]"; totalDup = totalDup + 1 end
        if info.colors.c == info.colors["4c"] then dup = dup .. " [c = 4c]" end
        table.insert(lines, string.format("  %-12s  CR:%.1f %s%s", actorLabel(a), ratio, label, dup))
    end
    table.insert(lines, "")
    table.insert(lines, "== VSF ==")
    table.insert(lines, "")
    local vsfActors, plainActors = {}, {}
    for _, a in ipairs(actors) do
        if data[a].has_vsf then table.insert(vsfActors, actorLabel(a)); totalVSF = totalVSF + 1
        else table.insert(plainActors, actorLabel(a)) end
    end
    if #vsfActors > 0 and #plainActors > 0 then
        table.insert(lines, "  Compatibilidad mixta de VSFilterMod:")
        table.insert(lines, "  Con VSF: " .. table.concat(vsfActors, ", "))
        table.insert(lines, "  Actores base: " .. table.concat(plainActors, ", "))
    elseif #vsfActors > 0 then
        table.insert(lines, "  Todos usan VSFilterMod (" .. #vsfActors .. ")")
    else
        table.insert(lines, "  VSFilterMod ausente en la selección.")
    end
    table.insert(lines, "")
    table.insert(lines, "== RESUMEN ==")
    table.insert(lines, "")
    table.insert(lines, "  Actores: " .. #actors)
    table.insert(lines, "  Cambios de color: " .. totalChanges)
    table.insert(lines, "  Cambios VSF: " .. totalVSFChanges)
    table.insert(lines, "  Contraste crítico: " .. totalLowCR)
    table.insert(lines, "  Color duplicado c=3c: " .. totalDup)
    table.insert(lines, "  Con VSFilterMod: " .. totalVSF)
    return table.concat(lines, "\n")
end

local ManagerDialog = {}

function ManagerDialog.build(page, perPage, actors, data, view, vsfTag)
    local total = #actors
    local pages = math.max(1, math.ceil(total / perPage))

    if view == "summary" then
        local text = ActorReport.summary(actors, data)
        local height = UI.textHeight(text, UI.report_height)
        return {
            { class = "label",   label = "Lista de actores", x = 0, y = 0, width = UI.report_width },
            { class = "textbox", name = "tb", text = text, x = 0, y = 1, width = UI.report_width, height = height, readonly = true },
            { class = "label",   label = "Formato: Actor  c:#RRGGBB  3c:#RRGGBB  [Estado]", x = 0, y = height + 1, width = UI.report_width },
        }, 0
    elseif view == "conflicts" then
        local text = ActorReport.conflicts(actors, data)
        local height = UI.textHeight(text, UI.report_height)
        return {
            { class = "label",   label = "Reporte de conflictos", x = 0, y = 0, width = UI.report_width },
            { class = "textbox", name = "tb", text = text, x = 0, y = 1, width = UI.report_width, height = height, readonly = true },
            { class = "label",   label = "Dominante por actor: color más frecuente; empates por primera aparición.", x = 0, y = height + 1, width = UI.report_width },
        }, 0
    elseif view == "vsf" then
        local activeTag = vsfTag or "1vc"
        local g = {
            { class = "label",    label = "4 esquinas", x = 0, y = 0, width = 6 },
            { class = "label",    label = "Pág " .. page .. "/" .. pages .. "  |  " .. total .. " actores", x = 0, y = 1, width = 4 },
            { class = "dropdown", name = "vctag", items = vsfTags, value = activeTag, x = 4, y = 1, width = 2, hint = "Etiqueta a editar" },
            { class = "label",    label = "Actor", x = 0, y = 2 },
            { class = "label",    label = "Esq1", x = 1, y = 2, hint = "Esquina sup-izq" },
            { class = "label",    label = "Esq2", x = 2, y = 2, hint = "Esquina sup-der" },
            { class = "label",    label = "Esq3", x = 3, y = 2, hint = "Esquina inf-izq" },
            { class = "label",    label = "Esq4", x = 4, y = 2, hint = "Esquina inf-der" },
            { class = "label",    label = "Info", x = 5, y = 2 },
        }
        local s, e = (page - 1) * perPage + 1, math.min(total, page * perPage)
        for k = s, e do
            local a = actors[k]
            local r = k - s + 3
            local info = data[a]
            local vc = info.vsf_corners[activeTag]
            table.insert(g, { class = "label",      label = actorPreview(a,UI.vsf_actor_label_chars), x = 0, y = r, hint = actorLabel(a) })
            table.insert(g, { class = "color", name = "V_" .. k .. "_1", value = ColorUtil.toHex(vc[1]), x = 1, y = r })
            table.insert(g, { class = "color", name = "V_" .. k .. "_2", value = ColorUtil.toHex(vc[2]), x = 2, y = r })
            table.insert(g, { class = "color", name = "V_" .. k .. "_3", value = ColorUtil.toHex(vc[3]), x = 3, y = r })
            table.insert(g, { class = "color", name = "V_" .. k .. "_4", value = ColorUtil.toHex(vc[4]), x = 4, y = r })
            table.insert(g, { class = "label",      label = info.has_vsf and "VSF" or "", x = 5, y = r })
        end
        return g, e - s + 1
    end

    local g = {
        { class = "label", label = "Colores", x = 0, y = 0, width = 5 },
        { class = "label", label = "Pág " .. page .. "/" .. pages .. "  |  " .. total .. " actores", x = 0, y = 1, width = 3 },
        { class = "label", label = "Actor", x = 0, y = 2 },
        { class = "label", label = "\\c",  x = 1, y = 2 },
        { class = "label", label = "\\3c", x = 2, y = 2 },
        { class = "label", label = "\\4c", x = 3, y = 2 },
        { class = "label", label = "Info", x = 4, y = 2 },
    }
    local s, e = (page - 1) * perPage + 1, math.min(total, page * perPage)
    for k = s, e do
        local a = actors[k]
        local r = k - s + 3
        local info = data[a]
        table.insert(g, { class = "label",      label = actorPreview(a,UI.actor_label_chars), x = 0, y = r, hint = actorLabel(a) .. " (" .. info.line_count .. " líneas)" })
        table.insert(g, { class = "color", name = "C_" .. k .. "_c",  value = ColorUtil.toHex(info.colors.c),     x = 1, y = r })
        table.insert(g, { class = "color", name = "C_" .. k .. "_3c", value = ColorUtil.toHex(info.colors["3c"]), x = 2, y = r })
        table.insert(g, { class = "color", name = "C_" .. k .. "_4c", value = ColorUtil.toHex(info.colors["4c"]), x = 3, y = r })
        local ratio = ColorUtil.contrastRatio(info.colors.c, info.colors["3c"])
        local status = info.has_mixed and "MIXTO " or ""
        if info.has_vsf then status = status .. "VSF " end
        if info.has_vsf_mixed then status = status .. "VSF-MIXTO " end
        if ratio < contrastCritical then status = status .. "URGENTE " .. string.format("%.1f", ratio)
        elseif ratio < wcagAa then status = status .. string.format("%.1f", ratio)
        else status = status .. "BIEN " .. string.format("%.1f", ratio) end
        table.insert(g, { class = "label", label = status, x = 4, y = r })
    end
    return g, e - s + 1
end

function ManagerDialog.sync(data, actors, res, page, perPage, mode, vsfTag)
    local s, e = (page - 1) * perPage + 1, math.min(#actors, page * perPage)
    for k = s, e do
        local a = actors[k]
        if mode == "vsf" and vsfTag then
            local v1 = res["V_" .. k .. "_1"]
            if v1 then
                local vc = data[a].vsf_corners[vsfTag]
                local previous=table.concat(vc,"|")
                vc[1] = ColorUtil.normalizeStrict(v1) or vc[1]
                vc[2] = ColorUtil.normalizeStrict(res["V_" .. k .. "_2"]) or vc[2]
                vc[3] = ColorUtil.normalizeStrict(res["V_" .. k .. "_3"]) or vc[3]
                vc[4] = ColorUtil.normalizeStrict(res["V_" .. k .. "_4"]) or vc[4]
                if previous~=table.concat(vc,"|") then data[a].has_vsf=true end
            end
        elseif not mode then
            local cv = res["C_" .. k .. "_c"]
            if cv then
                data[a].colors.c     = ColorUtil.normalizeStrict(cv) or data[a].colors.c
                data[a].colors["3c"] = ColorUtil.normalizeStrict(res["C_" .. k .. "_3c"]) or data[a].colors["3c"]
                data[a].colors["4c"] = ColorUtil.normalizeStrict(res["C_" .. k .. "_4c"]) or data[a].colors["4c"]
            end
        end
    end
end

local function buildVSFTag(vsfTag, vc)
    vc = vc or {}
    return "\\" .. vsfTag .. "(" ..
        ColorUtil.normalize(vc[1]) .. "," ..
        ColorUtil.normalize(vc[2]) .. "," ..
        ColorUtil.normalize(vc[3]) .. "," ..
        ColorUtil.normalize(vc[4]) .. ")"
end

local function generatedStyleInventory(subs)
    local styleIndex, usage = {}, {}
    for i = 1, #subs do
        local item = subs[i]
        if item.class == "style" and type(item.name) == "string" then
            styleIndex[item.name] = i
        elseif isDialogueLine(item) and type(item.style) == "string" then
            usage[item.style] = usage[item.style] or {}
            usage[item.style][i] = true
            for _,call in ipairs(LineOps.tagCalls(item.text,{"r"})) do
                local name=trim(call.value)
                if call.top_level and name~="" then
                    usage[name]=usage[name] or {}
                    usage[name][i]=true
                end
            end
        end
    end
    return styleIndex, usage
end

local function idsAsSet(ids)
    local out = {}
    for _, id in ipairs(ids or {}) do
        if type(id) == "number" then out[id] = true end
    end
    return out
end

local function usageIsContained(usage, targets)
    local any = false
    for id in pairs(usage or {}) do
        any = true
        if not targets[id] then return false, any end
    end
    return true, any
end

local function generatedStyleCandidate(rawName, suffix)
    if suffix == 1 then return rawName end
    return rawName .. "_" .. tostring(suffix)
end

local function chooseGeneratedStyleName(rawName, subs, styleIndex, usage, targets, claimed)
    local unusedName
    for suffix = 1, #subs + 1 do
        local name = generatedStyleCandidate(rawName, suffix)
        if not claimed[name] then
            local contained, any = usageIsContained(usage[name], targets)
            if styleIndex[name] and contained and any then
                return name, styleIndex[name]
            elseif not styleIndex[name] and contained and not unusedName then
                unusedName = name
            end
        end
    end
    local name = unusedName
    if not name then return nil, nil end
    return name, styleIndex[name]
end

local function styleColorWithInheritedAlpha(color, inherited, preserveAlpha)
    local alpha = "00"
    if preserveAlpha then
        if type(inherited) == "number" then
            local numeric = finiteNumber(inherited)
            if numeric and numeric == math.floor(numeric) and numeric >= assSignedColorMin and numeric <= assUnsignedColorMax then
                if numeric < 0 then numeric = numeric + assAlphaModulo end
                alpha = string.format("%02X", math.floor(numeric / assColorModulo) % 256)
            end
        else
            local hex = tostring(inherited or ""):match("^&[Hh](%x+)&?$")
            if hex and #hex == 8 then alpha = hex:sub(1, 2):upper() end
        end
    end
    return string.format("&H%s%06X&", alpha, ColorUtil.toNumber(color))
end

local function applyActorPalettes(subs, data, actors, styleMap, options)
    local plans, groups, groupOrder, selection = {}, {}, {}, {}
    local skipped = 0
    for _, actor in ipairs(actors) do
        local info = data[actor]
        local palette = options.palette(info)
        for _, id in ipairs(info.ids or {}) do
            local source = subs[id]
            if isDialogueLine(source) then
                selection[#selection+1] = id
                if palette and (options.includeDrawings ~= false or not LineOps.hasDrawing(source.text)) then
                    LineOps.checkCancelled()
                    local line = Core.copy(source)
                    local text = tostring(line.text or "")
                    if options.cleanOnly then text = TagStripper.clearColors(text)
                    else
                        if options.autoClean or options.styles then
                            text = TagStripper.clearSlots(text,options.slots)
                        elseif not options.vsfTag then
                            text = stripSolidSlotsFromFirstBlock(text)
                        end
                        if options.vsfTag then text=stripSpecificColor(text,options.vsfTag:sub(1,1)) end
                        if options.harmonize then
                            text=TagStripper.replaceSolidColors(text,palette.c,palette["3c"],palette["4c"])
                        end
                        if options.vsfRemap then
                            text=LineOps.mapTagCalls(text, nil, function(call)
                                local tuple=palette.vsf and palette.vsf[call.name]
                                if tuple then return buildVSFTag(call.name,tuple) end
                            end,{top_level_only=false})
                        elseif not options.vsfTag then
                            text=cleanupTransforms(LineOps.mapTagCalls(text, nil, function(call)
                                local slot=call.name:match("^([1-4]?)vc$")
                                slot=slot=="" and "1" or slot
                                if slot and options.slots[slot] then return "" end
                            end,{top_level_only=false}))
                        end
                        local payload = options.vsfTag and buildVSFTag(options.vsfTag,palette.vsf[options.vsfTag]) or
                            ("\\c"..palette.c.."\\3c"..palette["3c"].."\\4c"..palette["4c"])
                        if options.opaque then
                            text=cleanupTransforms(LineOps.removeTagCalls(text,{"alpha","1a","2a","3a","4a"},{top_level_only=false}))
                            payload=payload.."\\alpha&H00&"
                        end
                        if options.bord ~= nil then
                            text=cleanupTransforms(LineOps.removeTagCalls(text,{"bord","xbord","ybord","shad","xshad","yshad"},{top_level_only=false}))
                            payload=payload.."\\bord"..Core.formatNumber(options.bord,6).."\\shad"..Core.formatNumber(options.shad,6)
                        end
                        if options.styles then
                            text=TagStripper.afterResets(text,payload)
                            groups[actor]=groups[actor] or {}
                            local group=groups[actor][source.style]
                            if not group then
                                local base=styleMap[source.style] or styleMap.Default
                                if not base then return 0,0,"Falta el estilo de la línea "..id..": "..tostring(source.style) end
                                group={actor=actor,base=base,ids={},palette=palette}
                                groups[actor][source.style]=group
                                groupOrder[#groupOrder+1]=group
                            end
                            group.ids[#group.ids+1]=id
                        else text=TagStripper.setPalette(text,payload) end
                    end
                    line.text=TagStripper.dedupeColors(text):gsub("{%s*}","")
                    plans[#plans+1]={id=id,line=line}
                else skipped=skipped+1 end
            end
        end
    end
    local newStyles, replacements, claimed, names = {}, {}, {}, {}
    local styleIndex,usage=generatedStyleInventory(subs)
    local insertAt=1
    for i=1,#subs do if subs[i].class=="style" then insertAt=i+1 end end
    if insertAt==1 then
        while insertAt<=#subs and not isDialogueLine(subs[insertAt]) do insertAt=insertAt+1 end
    end
    for _, group in ipairs(groupOrder) do
        local rawName=(actorLabel(group.actor):gsub("[^%w_]","_"))..options.suffix
        local name,existing=chooseGeneratedStyleName(rawName,subs,styleIndex,usage,idsAsSet(group.ids),claimed)
        if not name then return 0,0,"No se pudo reservar un estilo para "..actorLabel(group.actor) end
        claimed[name]=true
        local style=Core.copy(group.base)
        style.name=name
        for _, slot in ipairs({1,3,4}) do
            local field="color"..slot
            local value=group.palette[slot==1 and "c" or slot.."c"]
            style[field]=styleColorWithInheritedAlpha(value,group.base[field],not options.opaque)
        end
        if options.opaque then
            style.color2=styleColorWithInheritedAlpha(Color.fromStyle(group.base.color2),nil,false)
            for slot=1,4 do style["alpha"..slot]=0 end
        end
        if options.bord~=nil then style.outline,style.shadow=options.bord,options.shad end
        if existing then replacements[existing]=style else newStyles[#newStyles+1]=style end
        for _, id in ipairs(group.ids) do names[id]=name end
    end
    return LineOps.transaction(subs,function()
        for id, style in pairs(replacements) do subs[id]=style end
        for i=#newStyles,1,-1 do subs.insert(insertAt,newStyles[i]) end
        for _, plan in ipairs(plans) do
            LineOps.checkCancelled()
            if names[plan.id] then plan.line.style=names[plan.id] end
            subs[plan.id>=insertAt and plan.id+#newStyles or plan.id]=plan.line
        end
        for i,id in ipairs(selection) do if id>=insertAt then selection[i]=id+#newStyles end end
        table.sort(selection)
        return #plans,skipped,nil,selection
    end)
end

local ManagerApply = {}

function ManagerApply.execute(subs,data,actors,styleMap,op,autoClean,vsfMode,vsfTag)
    if op=="Estilos" and vsfMode then return nil,"Los colores VSFilterMod requieren el modo Etiquetas." end
    if op~="Estilos" and op~="Limpiar" and op~="Etiquetas" and op~="Tags" then return nil,"Operación desconocida." end
    local count,_,err,selection=applyActorPalettes(subs,data,actors,styleMap or {},{
        styles=op=="Estilos",suffix="_Z",autoClean=autoClean,cleanOnly=op=="Limpiar",
        slots=vsfMode and {[vsfTag:sub(1,1)]=true} or {["1"]=true,["3"]=true,["4"]=true},
        vsfTag=vsfMode and vsfTag or nil,
        palette=function(info)
            return {c=Color.normalize(info.colors.c),["3c"]=Color.normalize(info.colors["3c"]),
                ["4c"]=Color.normalize(info.colors["4c"]),vsf=info.vsf_corners}
        end,
    })
    return not err and count or nil,err,selection
end

local ActorColorFile = {}

local function encodePaletteField(value)
    return (tostring(value or ""):gsub("([^%w%._%-%~ ])", function(char)
        return string.format("%%%02X", string.byte(char))
    end))
end

local function decodePaletteField(value)
    value = tostring(value or "")
    local unescaped = value:gsub("%%(%x%x)", "")
    if unescaped:find("%", 1, true) then return nil end
    return (value:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

function ActorColorFile.io(data, actors, mode)
    if mode == "Export" then
        local fp = aegisub.dialog.save("Exportar paleta de colores - Zheus Colormanager", "", "", "*.txt", false)
        if not fp then return nil end
        local hasAnyVSF = false
        for _, a in ipairs(actors) do
            if data[a].has_vsf then hasAnyVSF = true; break end
        end
        local ok, err = PyBridge.withAtomicFile(fp, function(f)
            assert(f:write("# Zheus Colormanager\n"))
            assert(f:write("# Exportación de paleta de color por actor\n"))
            assert(f:write("# Versión de formato: " .. actorPaletteFormatVersion .. "\n"))
            assert(f:write("# Tipo de contenido: " .. (hasAnyVSF and "VSF" or "NORMAL") .. "\n"))
            assert(f:write("# Esquema: Actor-porcentaje-codificado|c,3c,4c[|1vc:c1,c2,c3,c4|...]\n\n"))
            for _, a in ipairs(actors) do
                local info = data[a]
                local line = encodePaletteField(a) .. "|" .. info.colors.c .. "," .. info.colors["3c"] .. "," .. info.colors["4c"]
                if info.has_vsf then
                    for _, tag in ipairs(vsfTags) do
                        local vc = info.vsf_corners[tag]
                        if vc then
                            line = line .. "|" .. tag .. ":" .. vc[1] .. "," .. vc[2] .. "," .. vc[3] .. "," .. vc[4]
                        end
                    end
                end
                assert(f:write(line .. "\n"))
            end
            return true
        end, "wb")
        if not ok then return "Error al escribir: " .. tostring(err) end
        return "Exportados " .. #actors .. " actores"
    end

    local fn = aegisub.dialog.open("Importar paleta de colores - Zheus Colormanager", "", "", "*.txt", false, true)
    if not fn then return nil end
    local content, readError = PyBridge.readFile(fn)
    if not content then return "Error al leer: " .. tostring(readError) end
    local fileVersion = tonumber(content:match("#%s*Versión de formato:%s*(%d+)")) or 2
    if fileVersion < 2 or fileVersion > actorPaletteFormatVersion then
        return "Versión de paleta no compatible: " .. tostring(fileVersion)
    end
    local imported, missing, invalid, hasVsfData = 0, {}, {}, false
    local updated = {}
    for row in content:gmatch("[^\r\n]+") do
        if not row:match("^%s*#") and trim(row) ~= "" then
            LineOps.checkCancelled()
            local field,body=row:match("^(.-)|(.*)$")
            local actor
            if field then
                if fileVersion>=3 then actor=decodePaletteField(field) else actor=trim(field) end
            end
            if actor==nil then invalid[#invalid+1]="actor codificado"
            elseif not data[actor] then missing[#missing+1]=actorLabel(actor)
            else
                local parts={}
                for part in (body.."|"):gmatch("(.-)|") do parts[#parts+1]=part end
                local colors=LineOps.splitArguments(parts[1] or "")
                local solid,vsf,valid={},{},#colors==3
                for index=1,3 do
                    solid[index]=Color.normalizeStrict(colors[index])
                    if not solid[index] then valid=false end
                end
                for index=2,#parts do
                    local tag,values=parts[index]:match("^([1-4]vc):(.+)$")
                    local tuple=values and LineOps.splitArguments(values) or {}
                    if not tag or #tuple~=4 then valid=false
                    else
                        for corner=1,4 do tuple[corner]=Color.normalizeStrict(tuple[corner]);if not tuple[corner] then valid=false end end
                        vsf[tag]=tuple
                    end
                end
                if valid then
                    local info=data[actor]
                    info.colors.c,info.colors["3c"],info.colors["4c"]=solid[1],solid[2],solid[3]
                    for tag,tuple in pairs(vsf) do info.vsf_corners[tag]=tuple;info.has_vsf=true;hasVsfData=true end
                    if not updated[actor] then imported=imported+1 end
                    updated[actor]=true
                else invalid[#invalid+1]=actorLabel(actor) end
            end
        end
    end
    local noData = {}
    for _, a in ipairs(actors) do
        if not updated[a] then table.insert(noData, a) end
    end
    local msg = "Importados: " .. imported .. "/" .. #actors
    if #invalid > 0 then
        local il = table.concat(invalid, ", ")
        msg = msg .. "\nEntradas inválidas omitidas: " .. il
    end
    if #missing > 0 then
        local ml = table.concat(missing, ", ")
        msg = msg .. "\nArchivo con actores fuera de selección: " .. ml
    end
    if #noData > 0 then
        local nl = table.concat(noData, ", ")
        msg = msg .. "\nActores pendientes en archivo: " .. nl
    end
    return msg, hasVsfData
end

local VSFCornerEditor = {}

function VSFCornerEditor.applyGradient(subs, sel, cfg)
    local payload = {}
    local activeSlots = {}
    for _, tagName in ipairs(quickVsfTags) do
        local prefix = "vc" .. tagName:sub(1, 1)
        if cfg[prefix .. "_use"] then
            local c1 = ColorUtil.normalizeStrict(cfg[prefix .. "_1"])
            local c2 = ColorUtil.normalizeStrict(cfg[prefix .. "_2"])
            local c3 = ColorUtil.normalizeStrict(cfg[prefix .. "_3"])
            local c4 = ColorUtil.normalizeStrict(cfg[prefix .. "_4"])
            if not (c1 and c2 and c3 and c4) then
                return 0, "Color inválido en \\" .. tagName .. "."
            end
            payload[#payload + 1] = "\\" .. tagName .. "(" .. c1 .. "," .. c2 .. "," .. c3 .. "," .. c4 .. ")"
            table.insert(activeSlots, tagName:sub(1, 1))
        end
    end
    if #payload == 0 then return 0, "Selecciona al menos un tag VSF." end
    local tag = table.concat(payload)
    return LineOps.transaction(subs,function()
    local count, linesWithSolid = 0, 0

    for _, i in ipairs(LineOps.normalizeIndices(subs, sel)) do
        local l = Core.copy(subs[i])
        LineOps.checkCancelled()
        if isDialogueLine(l) then
            l.text = tostring(l.text or "")
            local hadSolidConflict = false

            if cfg.vcl then
                l.text = cleanupTransforms(LineOps.removeTagCalls(l.text,{"vc","1vc","2vc","3vc","4vc"}))
                l.text = l.text:gsub("{%s*}", "")
            end

            for _, slot in ipairs(activeSlots) do
                local before = l.text
                l.text = stripSpecificColor(l.text, slot)
                if l.text ~= before then hadSolidConflict = true end
            end

            l.text = TagStripper.setPalette(l.text, tag)
            l.text = TagStripper.dedupeColors(l.text)
            l.text = l.text:gsub("{%s*}", "")
            subs[i] = l
            count = count + 1
            if hadSolidConflict then linesWithSolid = linesWithSolid + 1 end
        end
    end

    if linesWithSolid > 0 then
        return count, nil, linesWithSolid
    end
    return count
    end)
end

local ColorReplacer = {}

function ColorReplacer.collect(subs,sel,slots)
    local seen,found={},{}
    for _,id in ipairs(LineOps.normalizeIndices(subs,sel)) do
        local line=subs[id]
        if isDialogueLine(line) then
            for _,call in ipairs(LineOps.tagCalls(line.text)) do
                local slot=TagStripper.colorSlot(call.name)
                if slot and slots[slot] then
                    for raw in call.value:gmatch(patHexToken) do
                        local color=Color.parseTag(raw)
                        if color and not seen[color] then seen[color]=true;found[#found+1]=color end
                    end
                end
            end
        end
    end
    table.sort(found)
    return found
end

function ColorReplacer.apply(subs,sel,replacements,slots)
    return LineOps.transaction(subs,function()
        local count=0
        for _,id in ipairs(LineOps.normalizeIndices(subs,sel)) do
            LineOps.checkCancelled()
            local source=subs[id]
            if isDialogueLine(source) then
                local text=LineOps.mapTagCalls(source.text,nil,function(call)
                    local slot=TagStripper.colorSlot(call.name)
                    if not slot or not slots[slot] then return nil end
                    local value=call.value:gsub(patHexToken,function(raw)
                        local target=replacements[Color.parseTag(raw)]
                        if not target then return raw end
                        return target
                    end)
                    if value~=call.value then return "\\"..call.raw_name..value end
                end,{top_level_only=false})
                if text~=source.text then
                    local line=Core.copy(source)
                    line.text=TagStripper.dedupeColors(text)
                    subs[id]=line;count=count+1
                end
            end
        end
        return count
    end)
end

function ColorReplacer.run(subs,sel,cfg)
    local slots,pending=slotFilterFromConfig(cfg),{}
    while true do
        local colors=ColorReplacer.collect(subs,sel,slots)
        local action,_,result=ColorDialogs.editMapping("Cambiar colores",colors,pending,{slots=slots})
        slots=result.slots
        if action=="Cancelar" then return 0,nil,"cancel",writeSlotFilterToTable({},slots) end
        if action=="Volver" then return 0,nil,"back",writeSlotFilterToTable({},slots) end
        if action=="Aplicar" then
            local replacements={}
            for _,color in ipairs(colors) do if pending[color] and pending[color]~=color then replacements[color]=pending[color] end end
            if next(replacements) then
                return ColorReplacer.apply(subs,sel,replacements,slots),nil,"applied",writeSlotFilterToTable({},slots)
            end
            return 0,nil,"nochange",writeSlotFilterToTable({},slots)
        end
    end
end

local ColorSpace = {}

ColorSpace.srgb8ToLinear = Color.srgb8ToLinear
ColorSpace.linearToSrgb8 = Color.linearToSrgb8
ColorSpace.rgbToOklab = Color.rgbToOklab

local oklabMemo, oklabMemoCount = {}, 0

function ColorSpace.colorToOklab(c)
    local key = Color.normalize(c)
    local hit = oklabMemo[key]
    if hit then return hit[1], hit[2], hit[3] end
    local r, g, b = ColorUtil.toRGB(c)
    local L, A, B = ColorSpace.rgbToOklab(r, g, b)
    if oklabMemoCount >= colorCacheLimit then oklabMemo, oklabMemoCount = {}, 0 end
    oklabMemo[key] = { L, A, B }
    oklabMemoCount = oklabMemoCount + 1
    return L, A, B
end

function ColorSpace.deltaOklab(c1, c2)
    local L1, A1, B1 = ColorSpace.colorToOklab(c1)
    local L2, A2, B2 = ColorSpace.colorToOklab(c2)
    local dL, dA, dB = L1 - L2, A1 - A2, B1 - B2
    return math.sqrt(dL * dL + dA * dA + dB * dB)
end

function ColorSpace.lumaDelta(c1, c2)
    return math.abs(ColorUtil.luminance(c1) - ColorUtil.luminance(c2))
end

local CVDSim = {}

CVDSim.matrices = {
    protan = {
        { 0.152286,  1.052583, -0.204868 },
        { 0.114503,  0.786281,  0.099216 },
        { -0.003882, -0.048116, 1.051998 },
    },
    deutan = {
        { 0.367322,  0.860646, -0.227968 },
        { 0.280085,  0.672501,  0.047413 },
        { -0.011820, 0.042940,  0.968881 },
    },
    tritan = {
        { 1.255528, -0.076749, -0.178779 },
        { -0.078411, 0.930809,  0.147602 },
        { 0.004733,  0.691367,  0.303900 },
    },
}

local function applyMatrix(r, g, b, m, severity)
    local lr = ColorSpace.srgb8ToLinear(r)
    local lg = ColorSpace.srgb8ToLinear(g)
    local lb = ColorSpace.srgb8ToLinear(b)
    local rr = m[1][1] * lr + m[1][2] * lg + m[1][3] * lb
    local gg = m[2][1] * lr + m[2][2] * lg + m[2][3] * lb
    local bb = m[3][1] * lr + m[3][2] * lg + m[3][3] * lb
    if severity < 1 then
        rr = lr + (rr - lr) * severity
        gg = lg + (gg - lg) * severity
        bb = lb + (bb - lb) * severity
    end
    return ColorSpace.linearToSrgb8(rr), ColorSpace.linearToSrgb8(gg), ColorSpace.linearToSrgb8(bb)
end

local cvdMemo, cvdMemoCount = {}, 0

function CVDSim.simulate(color, cvdType, severity)
    if color == nil or color == "" then return colorWhite end
    severity = finiteNumber(severity)
    if severity == nil then severity = 1.0 end
    if severity < 0 then severity = 0 end
    if severity > 1 then severity = 1 end
    local key = Color.normalize(color) .. "|" .. tostring(cvdType) .. "|" .. string.format("%.17g", severity)
    local hit = cvdMemo[key]
    if hit then return hit end
    local result
    if cvdType == "mono" then
        result = CVDSim.monochrome(color, severity)
    else
        local m = CVDSim.matrices[cvdType]
        if not m then
            result = ColorUtil.normalize(color)
        else
            local r, g, b = ColorUtil.toRGB(color)
            local r2, g2, b2 = applyMatrix(r, g, b, m, severity)
            result = ColorUtil.fromRGB(r2, g2, b2)
        end
    end
    if cvdMemoCount >= colorCacheLimit then cvdMemo, cvdMemoCount = {}, 0 end
    cvdMemo[key] = result
    cvdMemoCount = cvdMemoCount + 1
    return result
end

function CVDSim.monochrome(color, severity)
    local r, g, b = ColorUtil.toRGB(color)
    local y = ColorUtil.luminance(color)
    local v = ColorSpace.linearToSrgb8(y)
    severity = tonumber(severity) or 1
    if severity < 1 then
        return ColorUtil.fromRGB(r + (v - r) * severity, g + (v - g) * severity, b + (v - b) * severity)
    end
    return ColorUtil.fromRGB(v, v, v)
end

local AccessibilityProfiles = {}

AccessibilityProfiles.list = {
    NORMAL = {
        id = "NORMAL", label = "Auditar",
        description = "Genera el informe completo de accesibilidad (no remapea colores).",
        criteria = "Contraste, colisiones, CVD, alfa, dibujos y VSF.",
        simulate = { protan = 1.0, deutan = 1.0, tritan = 1.0, mono = 1.0 },
        thresholds = { min_text_contrast = 4.5, min_actor_delta = 0.055, min_mono_luma_delta = 0.10 },
        policy = { destructive = false, audit_only = true, preserve_hue = true },
    },
    DALTONICO = {
        id = "DALTONICO", label = "Daltonismo",
        description = "Ajusta la paleta para lectura estable en protanopia, deuteranopia, tritanopia y monocromo.",
        criteria = "Prioriza contorno, contraste y separación entre actores.",
        simulate = { protan = 1.0, deutan = 1.0, tritan = 1.0, mono = 0.8 },
        thresholds = { min_text_contrast = 4.5, min_cvd_text_contrast = 4.0, min_actor_delta = 0.085, min_mono_luma_delta = 0.16 },
        policy = { preserve_hue = false, destructive = false, use_palette = "subtitle_cvd", add_bord_shad = true, bord = 3, shad = 1 },
    },
    UNIVERSAL_SAFE = {
        id = "UNIVERSAL_SAFE", label = "Universal accesible",
        description = "Mantiene identidad cromática con colores de lectura amplia.",
        criteria = "Paleta Okabe-Ito/CUD con validación CVD.",
        simulate = { protan = 1.0, deutan = 1.0, tritan = 1.0, mono = 1.0 },
        thresholds = { min_text_contrast = 4.5, min_cvd_text_contrast = 4.0, min_actor_delta = 0.075, min_mono_luma_delta = 0.14 },
        policy = { preserve_hue = true, allow_bord_shad_override = true, destructive = false, use_palette = "okabe_ito", add_bord_shad = true, bord = 3, shad = 1 },
    },
    PROTAN_SAFE = {
        id = "PROTAN_SAFE", label = "Protanopía",
        description = "Refuerza pares rojo/verde y tonos oscuros sensibles al canal L.",
        criteria = "Contraste tonal y distancia entre actores bajo protanopia.",
        simulate = { protan = 1.0, deutan = 0.0, tritan = 0.0, mono = 0.5 },
        thresholds = { min_text_contrast = 4.5, min_cvd_text_contrast = 4.0, min_actor_delta = 0.080, min_mono_luma_delta = 0.14 },
        policy = { preserve_hue = false, destructive = false, use_palette = "protan_palette", add_bord_shad = true, bord = 3, shad = 1 },
    },
    DEUTAN_SAFE = {
        id = "DEUTAN_SAFE", label = "Deuteranopía",
        description = "Refuerza pares rojo/verde sensibles al canal M.",
        criteria = "Luminancia, contorno y distancia entre actores bajo deuteranopía.",
        simulate = { protan = 0.0, deutan = 1.0, tritan = 0.0, mono = 0.5 },
        thresholds = { min_text_contrast = 4.5, min_cvd_text_contrast = 4.0, min_actor_delta = 0.080, min_mono_luma_delta = 0.14 },
        policy = { preserve_hue = false, destructive = false, use_palette = "deutan_palette", add_bord_shad = true, bord = 3, shad = 1 },
    },
    TRITAN_SAFE = {
        id = "TRITAN_SAFE", label = "Tritanopía",
        description = "Refuerza pares azul/violeta y amarillo/blanco sensibles al canal S.",
        criteria = "Contraste de texto y distancia entre actores bajo tritanopía.",
        simulate = { protan = 0.0, deutan = 0.0, tritan = 1.0, mono = 0.5 },
        thresholds = { min_text_contrast = 4.5, min_cvd_text_contrast = 4.0, min_actor_delta = 0.080, min_mono_luma_delta = 0.14 },
        policy = { preserve_hue = false, destructive = false, use_palette = "tritan_palette", add_bord_shad = true, bord = 3, shad = 1 },
    },
    MONOCHROME = {
        id = "MONOCHROME", label = "Monocromo",
        description = "Convierte la paleta a valores de luminancia.",
        criteria = "Contraste AAA y separación tonal.",
        simulate = { protan = 0.0, deutan = 0.0, tritan = 0.0, mono = 1.0 },
        thresholds = { min_text_contrast = 7.0, min_actor_delta = 0.0, min_mono_luma_delta = 0.18 },
        policy = { preserve_hue = false, destructive = true, force_mono = true },
    },
    HIGH_CONTRAST = {
        id = "HIGH_CONTRAST", label = "Alto contraste",
        description = "Usa relleno blanco con borde y sombra negros.",
        criteria = "Lectura máxima sobre fondos variables.",
        simulate = { protan = 1.0, deutan = 1.0, tritan = 1.0, mono = 1.0 },
        thresholds = { min_text_contrast = 7.0, min_actor_delta = 0.0, min_mono_luma_delta = 0.0 },
        policy = {
            preserve_hue = false, destructive = true,
            force_fill = colorWhite, force_outline = colorBlack, force_shadow = colorBlack,
            add_bord_shad = true, bord = 3, shad = 1,
        },
    },
}

local builtinProfileIds = {
    NORMAL = true, DALTONICO = true, UNIVERSAL_SAFE = true,
    PROTAN_SAFE = true, DEUTAN_SAFE = true, TRITAN_SAFE = true,
    MONOCHROME = true, HIGH_CONTRAST = true,
}

function AccessibilityProfiles.get(id)
    if type(id) == "table" and id.id then return id end
    return AccessibilityProfiles.list[id] or AccessibilityProfiles.list.DALTONICO or AccessibilityProfiles.list.UNIVERSAL_SAFE
end

local function profileString(value, fallback)
    if value == nil then return fallback end
    if type(value) ~= "string" then return nil end
    return value
end

local function boundedProfileNumber(value, fallback, minimum, maximum)
    if value == nil then return fallback end
    local number = finiteNumber(value)
    if not number or number < minimum or number > maximum then return nil end
    return number
end

function AccessibilityProfiles.sanitize(p, forcedId)
    if type(p) ~= "table" then return nil end
    local id = forcedId or p.id
    if type(id) ~= "string" or id == "" or not id:match("^[%w_.%-]+$") then return nil end
    local label = profileString(p.label, id)
    local description = profileString(p.description, "")
    local criteria = profileString(p.criteria, "")
    if not label or not description or not criteria or (p.simulate ~= nil and type(p.simulate) ~= "table") or
        (p.thresholds ~= nil and type(p.thresholds) ~= "table") or
        (p.policy ~= nil and type(p.policy) ~= "table") then return nil end

    local simulate, sourceSim = {}, p.simulate or {}
    for _, key in ipairs({ "protan", "deutan", "tritan", "mono" }) do
        simulate[key] = boundedProfileNumber(sourceSim[key], 0, 0, 1)
        if simulate[key] == nil then return nil end
    end
    local sourceThresholds = p.thresholds or {}
    local thresholds = {
        min_text_contrast = boundedProfileNumber(sourceThresholds.min_text_contrast, 4.5, 1, 21),
        min_cvd_text_contrast = boundedProfileNumber(sourceThresholds.min_cvd_text_contrast, 4.0, 1, 21),
        min_actor_delta = boundedProfileNumber(sourceThresholds.min_actor_delta, 0.055, 0, 1),
        min_mono_luma_delta = boundedProfileNumber(sourceThresholds.min_mono_luma_delta, 0.12, 0, 1),
    }
    for _, key in ipairs({"min_text_contrast","min_cvd_text_contrast","min_actor_delta","min_mono_luma_delta"}) do
        if thresholds[key] == nil then return nil end
    end

    local sourcePolicy, policy = p.policy or {}, {}
    for _, key in ipairs({
        "preserve_hue", "destructive", "audit_only", "allow_bord_shad_override",
        "add_bord_shad", "force_mono", "calibrated"
    }) do
        if sourcePolicy[key] ~= nil then
            if type(sourcePolicy[key]) ~= "boolean" then return nil end
            policy[key] = sourcePolicy[key]
        end
    end
    for _, key in ipairs({ "bord", "shad" }) do
        if sourcePolicy[key] ~= nil then
            policy[key] = boundedProfileNumber(sourcePolicy[key], nil, 0, math.huge)
            if policy[key] == nil then return nil end
        end
    end
    if sourcePolicy.use_palette ~= nil then
        policy.use_palette = profileString(sourcePolicy.use_palette, nil)
        if not policy.use_palette then return nil end
    end
    for _, key in ipairs({ "force_fill", "force_outline", "force_shadow" }) do
        if sourcePolicy[key] ~= nil then
            policy[key] = ColorUtil.normalizeStrict(sourcePolicy[key])
            if not policy[key] then return nil end
        end
    end
    return {
        id = id,
        label = label,
        description = description,
        criteria = criteria,
        simulate = simulate,
        thresholds = thresholds,
        policy = policy,
    }
end

function AccessibilityProfiles.register(p, forcedId)
    local sanitized = AccessibilityProfiles.sanitize(p, forcedId)
    if not sanitized then return false end
    AccessibilityProfiles.list[sanitized.id] = sanitized
    return true, sanitized
end

local builtinProfileOrder = {
    "NORMAL",
    "DALTONICO", "UNIVERSAL_SAFE", "PROTAN_SAFE", "DEUTAN_SAFE",
    "TRITAN_SAFE", "MONOCHROME", "HIGH_CONTRAST",
}

function AccessibilityProfiles.ids()
    local out, seen = {}, {}
    for _, id in ipairs(builtinProfileOrder) do
        if AccessibilityProfiles.list[id] then
            table.insert(out, id); seen[id] = true
        end
    end
    local extras = {}
    for id, p in pairs(AccessibilityProfiles.list) do

        local hidden = type(p) == "table" and p.policy and p.policy.audit_only
        if not seen[id] and not hidden then table.insert(extras, id) end
    end
    table.sort(extras)
    for _, id in ipairs(extras) do table.insert(out, id) end
    return out
end

function AccessibilityProfiles.label(id)
    local profile = AccessibilityProfiles.get(id)
    return tostring(profile.label or profile.id or id or "")
end

function AccessibilityProfiles.choices()
    local out = {}
    for _, id in ipairs(AccessibilityProfiles.ids()) do
        table.insert(out, AccessibilityProfiles.label(id))
    end
    return out
end

function AccessibilityProfiles.choiceFromId(id)
    return AccessibilityProfiles.label(id)
end

function AccessibilityProfiles.idFromChoice(choice)
    if AccessibilityProfiles.list[choice] then return choice end
    for id, profile in pairs(AccessibilityProfiles.list) do
        if profile.label == choice then return id end
    end
    return AccessibilityProfiles.get(choice).id
end

local profileSimLabels = {
    { "protan", "protanopia" },
    { "deutan", "deuteranopia" },
    { "tritan", "tritanopia" },
    { "mono", "monocromo" },
}

function AccessibilityProfiles.simulationText(profile)
    profile = AccessibilityProfiles.get(profile)
    local simulate = profile.simulate or {}
    local parts = {}
    for _, item in ipairs(profileSimLabels) do
        local sev = tonumber(simulate[item[1]]) or 0
        if sev > 0 then table.insert(parts, string.format("%s %.0f%%", item[2], sev * 100)) end
    end
    if #parts == 0 then return "auditoría base" end
    return table.concat(parts, ", ")
end

local paletteLabels = {
    okabe_ito           = "Okabe-Ito (CUD)",
    subtitle_cvd        = "Subtítulos CVD",
    protan_palette      = "Optimizada para protanopia",
    deutan_palette      = "Optimizada para deuteranopia",
    tritan_palette      = "Optimizada para tritanopia",
    subtitle_safe_light = "Subtítulos claros",
    subtitle_safe_dark  = "Subtítulos oscuros",
}

function AccessibilityProfiles.describe(id)
    local profile = AccessibilityProfiles.get(id)
    local pol = profile.policy or {}
    local thr = profile.thresholds or {}
    local lines = {
        "Hace: " .. tostring(profile.description or "Ajusta la paleta accesible."),
        "Prioriza: " .. tostring(profile.criteria or "Contraste, simulación CVD y separación perceptual."),
        "Vista: " .. AccessibilityProfiles.simulationText(profile),
        string.format("Mínimos: texto %.1f:1, actores %.3f, luminancia %.2f.",
            thr.min_text_contrast or 4.5, thr.min_actor_delta or 0, thr.min_mono_luma_delta or 0),
    }
    if pol.audit_only then table.insert(lines, "Modo: evaluación.") end
    if pol.force_mono then table.insert(lines, "Salida: relleno monocromo.") end
    if pol.force_fill then table.insert(lines, "Salida: relleno blanco, borde y sombra negros.") end
    if pol.use_palette then
        local label = paletteLabels[pol.use_palette] or pol.use_palette
        table.insert(lines, "Paleta: " .. label .. ".")
    end
    if pol.calibrated then table.insert(lines, "Calibración: personalizada.") end
    return table.concat(lines, "\n")
end

function AccessibilityProfiles.describeAll(activeId)
    local lines = {
        "Elige un perfil para adaptar la paleta de la selección.",
        "Lectura: contraste WCAG, simulación CVD Machado y distancia Oklab.",
        "Calibración: ajusta un perfil propio para la escena actual.",
        "",
    }
    for _, id in ipairs(AccessibilityProfiles.ids()) do
        local profile = AccessibilityProfiles.get(id)
        local title = AccessibilityProfiles.label(id)
        if profile.id == activeId then title = title .. " (activo)" end
        table.insert(lines, "-- " .. title .. " --")
        table.insert(lines, AccessibilityProfiles.describe(id))
        table.insert(lines, "")
    end
    return table.concat(lines, "\n")
end

local AccessibilityMetrics = {}

local cvdKinds = { "protan", "deutan", "tritan", "mono" }

local function pickWorst(t)
    local worst, name = math.huge, nil
    for k, v in pairs(t) do
        if v < worst then worst, name = v, k end
    end
    return worst, name
end

function AccessibilityMetrics.auditTextContrast(colors, profile)
    profile = AccessibilityProfiles.get(profile)
    local thr = profile.thresholds or {}
    local minC = thr.min_text_contrast or 7.0
    local minCvd = thr.min_cvd_text_contrast or minC

    local c  = ColorUtil.normalize(colors.c or colorWhite)
    local c2 = ColorUtil.normalize(colors["2c"] or colorBlack)
    local c3 = ColorUtil.normalize(colors["3c"] or colorBlack)
    local c4 = ColorUtil.normalize(colors["4c"] or colorBlack)

    local lum = {
        [c]  = ColorUtil.luminance(c)  + 0.05,
        [c2] = ColorUtil.luminance(c2) + 0.05,
        [c3] = ColorUtil.luminance(c3) + 0.05,
        [c4] = ColorUtil.luminance(c4) + 0.05,
    }
    local function ratioFromLum(x, y)
        local lx, ly = lum[x], lum[y]
        return lx > ly and lx / ly or ly / lx
    end

    local result = { status = "OK", flags = {}, contrast = {} }
    result.contrast.c_3c     = ratioFromLum(c, c3)
    result.contrast.c_4c     = ratioFromLum(c, c4)
    result.contrast["2c_3c"] = ratioFromLum(c2, c3)
    result.contrast["2c_c"]  = ratioFromLum(c2, c)

    local simulate = profile.simulate or {}
    for _, cvd in ipairs(cvdKinds) do
        local sev = simulate[cvd] or 0
        if sev > 0 then
            local sc  = CVDSim.simulate(c,  cvd, sev)
            local s3  = CVDSim.simulate(c3, cvd, sev)
            result.contrast[cvd .. "_c_3c"] = ColorUtil.contrastRatio(sc, s3)
        end
    end

    if c == c3 then table.insert(result.flags, "C_EQUALS_3C") end
    if c == c4 then table.insert(result.flags, "C_EQUALS_4C") end

    local function bump(s)
        local order = { OK = 0, WARN = 1, FAIL = 2, CRITICAL = 3 }
        if (order[s] or 0) > (order[result.status] or 0) then result.status = s end
    end

    local v = result.contrast.c_3c
    if v < wcagFail then
        table.insert(result.flags, "LOW_C_3C_CONTRAST"); bump("CRITICAL")
    elseif v < wcagAa then
        table.insert(result.flags, "LOW_C_3C_CONTRAST"); bump("FAIL")
    elseif v < minC then
        table.insert(result.flags, "LOW_C_3C_CONTRAST"); bump("WARN")
    end

    v = result.contrast.c_4c
    if v < wcagFail then table.insert(result.flags, "LOW_C_4C_CONTRAST"); bump("FAIL") end

    v = result.contrast["2c_3c"]
    if v < wcagFail then table.insert(result.flags, "LOW_2C_3C_CONTRAST"); bump("WARN") end

    for _, cvd in ipairs(cvdKinds) do
        local key = cvd .. "_c_3c"
        local cv = result.contrast[key]
        if cv then
            local flag = cvd:upper() .. "_CONTRAST_RISK"
            if cv < wcagFail then
                table.insert(result.flags, flag); bump("FAIL")
            elseif cv < minCvd then
                table.insert(result.flags, flag); bump("WARN")
            end
        end
    end

    return result
end

local AccessibilityAudit = {}

local hasDrawing = LineOps.hasDrawing

local function hasAlphaTag(text,style)
    for _, call in ipairs(LineOps.tagCalls(text)) do
        if call.name=="alpha" or call.name:match("^[1-4]a$") then return true end
    end
    for slot=1,4 do
        if style then
            local alpha=finiteNumber(style["alpha"..slot])
            if alpha and alpha~=0 then return true end
            local color=style["color"..slot]
            if type(color)=="number" and math.floor(color/assColorModulo)%256~=0 then return true end
            local hex=tostring(color or ""):match("^&[Hh](%x+)&?$")
            if hex and #hex==8 and tonumber(hex:sub(1,2),16)~=0 then return true end
        end
    end
    return false
end

function AccessibilityAudit.run(subs, sel, profileId)
    local styleMap = collectStyles(subs)
    local data, actors = StyleScanner.scanActors(subs, sel, styleMap)
    local profile = AccessibilityProfiles.get(profileId or "DALTONICO")
    local minD = (profile.thresholds and profile.thresholds.min_actor_delta) or 0.055
    local minMono = (profile.thresholds and profile.thresholds.min_mono_luma_delta) or 0.12

    local report = {
        profile = profile,
        actors = {},
        pairs = {},
        vsf = {},
        alphaRisks = {},
        drawingActors = {},
    }

    local lineCount = 0
    for _, a in ipairs(actors) do
        local info = data[a]
        lineCount = lineCount + (info.line_count or 0)

        local metrics=AccessibilityMetrics.auditTextContrast(info.colors,profile)
        local flags={}
        for _,flag in ipairs(metrics.flags) do flags[flag]=true end
        local rank={OK=0,WARN=1,FAIL=2,CRITICAL=3}
        for _,run in ipairs(info.color_runs or {}) do
            local current=AccessibilityMetrics.auditTextContrast(run.colors,profile)
            for key,value in pairs(current.contrast) do metrics.contrast[key]=math.min(metrics.contrast[key] or value,value) end
            if rank[current.status]>rank[metrics.status] then metrics.status=current.status end
            for _,flag in ipairs(current.flags) do if not flags[flag] then flags[flag]=true;metrics.flags[#metrics.flags+1]=flag end end
            if hasAlphaTag("",run.style) then report.alphaRisks[a]=true end
        end
        if info.has_animated then metrics.flags[#metrics.flags+1]="ANIMATED_COLOR" end
        report.actors[a] = metrics

        for _, lid in ipairs(info.ids or {}) do
            if report.drawingActors[a] and report.alphaRisks[a] then break end
            local l = subs[lid]
            if l and isDialogueLine(l) then
                local txt = tostring(l.text or "")
                if not report.drawingActors[a] and hasDrawing(txt) then
                    report.drawingActors[a] = true
                end
                if not report.alphaRisks[a] and hasAlphaTag(txt,styleMap[l.style]) then
                    report.alphaRisks[a] = true
                end
            end
        end
    end

    local simulate = profile.simulate or {}
    local cvdActive = {}
    for _, cvd in ipairs(cvdKinds) do
        local sev = simulate[cvd] or 0
        if sev > 0 then cvdActive[#cvdActive + 1] = { kind = cvd, sev = sev } end
    end
    local oklabPerActor = {}
    for _, a in ipairs(actors) do
        local ca = data[a].colors.c
        local row = {}
        local Lb, Ab, Bb = ColorSpace.colorToOklab(ca)
        row.base = { Lb, Ab, Bb }
        for _, c in ipairs(cvdActive) do
            local sim = CVDSim.simulate(ca, c.kind, c.sev)
            local Ls, As, Bs = ColorSpace.colorToOklab(sim)
            row[c.kind] = { Ls, As, Bs }
        end
        oklabPerActor[a] = row
    end
    local function deltaFrom(ka, kb)
        local dL = ka[1] - kb[1]
        local dA = ka[2] - kb[2]
        local dB = ka[3] - kb[3]
        return math.sqrt(dL * dL + dA * dA + dB * dB)
    end

    for i = 1, #actors do
        LineOps.checkCancelled()
        local labA = oklabPerActor[actors[i]]
        for j = i + 1, #actors do
            local labB = oklabPerActor[actors[j]]
            local deltas = { normal = deltaFrom(labA.base, labB.base) }
            for _, c in ipairs(cvdActive) do
                deltas[c.kind] = deltaFrom(labA[c.kind], labB[c.kind])
            end
            local worst, kind = pickWorst(deltas)
            if worst < minD then
                table.insert(report.pairs, { a = actors[i], b = actors[j], worst = worst, kind = kind, deltas = deltas })
            end
        end
    end

    for _, a in ipairs(actors) do
        local info = data[a]
        if info.has_vsf then
            for _, tag in ipairs(vsfTags) do
                local vc = info.vsf_corners[tag]
                if vc and (not info.vsf_present or info.vsf_present[tag]) then
                    local lo, hi = math.huge, -math.huge
                    for k = 1, 4 do
                        local lum = ColorUtil.luminance(vc[k])
                        if lum < lo then lo = lum end
                        if lum > hi then hi = lum end
                    end
                    if (hi - lo) < minMono then
                        table.insert(report.vsf, { a = a, tag = tag, kind = "mono_collapse", value = hi - lo })
                    end
                    local cr = ColorUtil.contrastRatio(vc[1], info.colors["3c"] or colorBlack)
                    if cr < wcagFail then
                        table.insert(report.vsf, { a = a, tag = tag, kind = "outline_low", value = cr })
                    end
                end
            end
        end
    end

    local sum = { actors = #actors, lines = lineCount, failContrast = 0, warnContrast = 0,
                  actorCollisions = #report.pairs, vsfRisks = #report.vsf, alphaRisks = 0 }
    for _, m in pairs(report.actors) do
        if m.status == "FAIL" or m.status == "CRITICAL" then sum.failContrast = sum.failContrast + 1
        elseif m.status == "WARN" then sum.warnContrast = sum.warnContrast + 1 end
    end
    for _ in pairs(report.alphaRisks) do sum.alphaRisks = sum.alphaRisks + 1 end
    report.summary = sum

    return report, data, actors
end

local AccessibilityReport = {}

local reportFlagText = {
    ANIMATED_COLOR = "Hay colores animados; el informe describe los tramos estáticos y no evalúa cada instante del fundido.",
    C_EQUALS_3C = "Relleno y borde comparten color; el contorno pierde separación.",
    C_EQUALS_4C = "Relleno y sombra comparten color; la profundidad queda plana.",
    LOW_C_3C_CONTRAST = "Relleno y borde quedan por debajo del objetivo de contraste.",
    LOW_C_4C_CONTRAST = "Relleno y sombra necesitan mayor separación tonal.",
    LOW_2C_3C_CONTRAST = "Karaoke/2c queda muy cerca del borde; el resaltado pierde presencia.",
    PROTAN_CONTRAST_RISK = "Lectura sensible bajo protanopia.",
    DEUTAN_CONTRAST_RISK = "Lectura sensible bajo deuteranopia.",
    TRITAN_CONTRAST_RISK = "Lectura sensible bajo tritanopia.",
    MONO_CONTRAST_RISK = "Lectura sensible en monocromo o baja saturación.",
}

local reportKindText = {
    normal = "visión normal",
    protan = "protanopia",
    deutan = "deuteranopia",
    tritan = "tritanopia",
    mono = "monocromo",
    mono_collapse = "poca diferencia de luminancia entre esquinas",
    outline_low = "bajo contraste contra el borde",
}

function AccessibilityReport.flagText(code)
    local text = reportFlagText[code]
    if text then return text end
    return tostring(code or ""):gsub("_", " "):lower()
end

function AccessibilityReport.kindText(kind)
    return reportKindText[kind] or tostring(kind or "")
end

function AccessibilityReport.format(report, actors)
    local s = {}
    local function w(line) table.insert(s, line) end
    local statusLabels = { OK = "BIEN", WARN = "REVISAR", FAIL = "AJUSTAR", CRITICAL = "URGENTE" }

    w("# INFORME DE ACCESIBILIDAD DE COLOR")
    w("Contraste entre colores de tramos estáticos. Las simulaciones son aproximadas; el fondo del vídeo, la opacidad y el grosor visible requieren revisión de la escena.")
    w("")
    w("Perfil: " .. AccessibilityProfiles.label(report.profile.id))
    w("Actores: " .. report.summary.actors)
    w("Lineas:  " .. report.summary.lines)
    w("")
    w("== CONTRASTE DE TEXTO POR ACTOR ==")
    if #actors == 0 then w("  (selección vacía de actores)") end
    for _, a in ipairs(actors) do
        local m = report.actors[a]
        if m then
            local line = string.format("  %-14s CR:%-5.1f", actorLabel(a), m.contrast.c_3c or 0)
            for _, cvd in ipairs(cvdKinds) do
                local v = m.contrast[cvd .. "_c_3c"]
                if v then
                    local tag = cvd:sub(1, 1):upper() .. cvd:sub(2, 3)
                    line = line .. string.format("  %s:%-4.1f", tag, v)
                end
            end
            line = line .. "  " .. (statusLabels[m.status] or tostring(m.status or ""))
            w(line)
            for _, flag in ipairs(m.flags) do
                w("      - " .. AccessibilityReport.flagText(flag))
            end
        end
    end
    w("")
    w("== COLISIONES DE COLOR ENTRE ACTORES ==")
    if #report.pairs == 0 then
        w("  Estado estable.")
    else
        for _, p in ipairs(report.pairs) do
            w(string.format("  %s / %s: se parecen en %s (delta %.3f).",
                actorLabel(p.a), actorLabel(p.b), AccessibilityReport.kindText(p.kind), p.worst))
        end
    end
    w("")
    w("== VSF ==")
    if #report.vsf == 0 then
        w("  Estado estable.")
    else
        for _, v in ipairs(report.vsf) do
            w(string.format("  %s \\%s: %s (%.2f)",
                actorLabel(v.a), v.tag, AccessibilityReport.kindText(v.kind), v.value or 0))
        end
    end
    w("")
    if next(report.drawingActors) then
        w("== DIBUJOS DETECTADOS ==")
        for a in pairs(report.drawingActors) do
            w("  " .. actorLabel(a) .. "  (la opción Incluir dibujos controla su aplicación)")
        end
        w("")
    end
    if next(report.alphaRisks) then
        w("== ETIQUETAS ALFA DETECTADAS ==")
        for a in pairs(report.alphaRisks) do
            w("  " .. actorLabel(a) .. "  (Preservar alfa mantiene la transparencia original)")
        end
        w("")
    end
    w("== RESUMEN ==")
    w(string.format("  Casos críticos de contraste: %d", report.summary.failContrast))
    w(string.format("  Observaciones de contraste: %d", report.summary.warnContrast))
    w(string.format("  Colisiones entre actores:  %d", report.summary.actorCollisions))
    w(string.format("  Riesgos VSF:               %d", report.summary.vsfRisks))
    w(string.format("  Riesgos de alfa:           %d", report.summary.alphaRisks))
    w("")
    w("== ACCION ==")
    if report.profile.id == "NORMAL" then
        w("  Usa Daltonismo, Universal o Alto contraste para remapear colores.")
    else
        w("  Aplicar perfil: " .. AccessibilityProfiles.label(report.profile.id))
        if report.summary.failContrast > 0 or report.summary.actorCollisions > 0 then
            w("  Borde oscuro y colores de actor como relleno mejoran la lectura.")
        end
    end
    return table.concat(s, "\n")
end

local PaletteEngine = {}

PaletteEngine.palettes = {
    okabe_ito = {
        "#E69F00", "#56B4E9", "#009E73", "#F0E442",
        "#0072B2", "#D55E00", "#CC79A7", "#000000",
    },
    subtitle_cvd = {
        "#E69F00", "#56B4E9", "#D55E00", "#009E73",
        "#F0E442", "#0072B2", "#CC79A7", "#000000",
        "#FFFFFF",
    },

    protan_palette = {
        "#FFE800", "#0099E0", "#FFFFFF", "#003B73",
        "#FFC000", "#80E0FF", "#000000", "#FFEB80",
        "#5B5B5B", "#FFC0CB",
    },

    deutan_palette = {
        "#FFD300", "#0080CC", "#FFFFFF", "#1A2D7A",
        "#FF8C00", "#66B2FF", "#000000", "#FFF0A0",
        "#606060", "#E0B5FF",
    },

    tritan_palette = {
        "#FF4040", "#00C0C0", "#FFFFFF", "#A00000",
        "#FF7060", "#A0FFFF", "#000000", "#FFB0B0",
        "#202020", "#E020E0",
    },
    subtitle_safe_light = {
        "#FFFFFF", "#F2F2F2", "#FFE6A8", "#AEE6FF",
        "#D9C2FF", "#FFB6C8", "#B8F2D0", "#FFD1A3",
    },
    subtitle_safe_dark = {
        "#000000", "#101010", "#151520", "#1A1025",
        "#102025", "#251010", "#102510", "#2A210D",
    },
}

function PaletteEngine.contrastAcrossVision(c1, c2, profile)
    profile = AccessibilityProfiles.get(profile)
    local worst = ColorUtil.contrastRatio(c1, c2)
    for _, cvd in ipairs(cvdKinds) do
        local sev = (profile.simulate or {})[cvd] or 0
        if sev > 0 then
            local cr = ColorUtil.contrastRatio(CVDSim.simulate(c1, cvd, sev), CVDSim.simulate(c2, cvd, sev))
            if cr < worst then worst = cr end
        end
    end
    return worst
end

function PaletteEngine.pickOutline(fill,profile)
    return PaletteEngine.contrastAcrossVision(fill,colorBlack,profile)>=PaletteEngine.contrastAcrossVision(fill,colorWhite,profile)
        and colorBlack or colorWhite
end

local function scaleRgb(color,factor)
    local r,g,b=Color.toRGB(color)
    return Color.fromRGB(r*factor,g*factor,b*factor)
end

function PaletteEngine.makeCandidates(actorInfo, profile)
    profile = AccessibilityProfiles.get(profile)
    local pol = profile.policy or {}
    local cands = {}
    local seen = {}
    local function add(c)
        local n = ColorUtil.normalize(c)
        if not seen[n] then seen[n] = true; table.insert(cands, n) end
    end

    local palette = PaletteEngine.palettes[pol.use_palette or ""]
    if palette then
        for _, hex in ipairs(palette) do add(hex) end
    end
    if pol.preserve_hue ~= false then
        add(actorInfo.colors.c)
        for _, hex in ipairs(PaletteEngine.palettes.subtitle_safe_light) do add(hex) end
        for _, hex in ipairs(PaletteEngine.palettes.okabe_ito) do add(hex) end
        for _, k in ipairs(paletteScaleFactors) do
            add(scaleRgb(actorInfo.colors.c, k))
        end
    end
    return cands
end

function PaletteEngine.scoreCandidate(cand, actor, actorInfo, assigned, profile)
    profile = AccessibilityProfiles.get(profile)
    local thr = profile.thresholds or {}
    local minC = thr.min_text_contrast or 4.5
    local minCvd = thr.min_cvd_text_contrast or math.min(minC, 4.5)
    local minD = thr.min_actor_delta or 0.055
    local minM = thr.min_mono_luma_delta or 0.12

    local outline = PaletteEngine.pickOutline(cand, profile)
    local cr = ColorUtil.contrastRatio(cand, outline)
    local cvdCr = PaletteEngine.contrastAcrossVision(cand, outline, profile)
    if cr < wcagFail or cvdCr < wcagFail then return math.huge end

    local contrastPenalty = 0
    if cr < wcagAa then contrastPenalty = 2 + (wcagAa - cr)
    elseif cr < minC then contrastPenalty = (minC - cr) / minC end
    if cvdCr < minCvd then
        contrastPenalty = contrastPenalty + 2 + ((minCvd - cvdCr) / minCvd)
    end

    local collisionPenalty = 0
    for other, otherCand in pairs(assigned) do
        if other ~= actor then
            if ColorUtil.normalize(otherCand) == ColorUtil.normalize(cand) then
                collisionPenalty = collisionPenalty + 10
            end
            local d = ColorSpace.deltaOklab(cand, otherCand)
            if d < minD then collisionPenalty = collisionPenalty + (minD - d) / minD end
            for _, cvd in ipairs({ "protan", "deutan", "tritan" }) do
                local sev = (profile.simulate or {})[cvd] or 0
                if sev > 0 then
                    local dd = ColorSpace.deltaOklab(
                        CVDSim.simulate(cand, cvd, sev),
                        CVDSim.simulate(otherCand, cvd, sev))
                    if dd < minD then collisionPenalty = collisionPenalty + (minD - dd) / minD end
                end
            end
        end
    end

    local monoPenalty = 0
    for other, otherCand in pairs(assigned) do
        if other ~= actor then
            local d = ColorSpace.lumaDelta(cand, otherCand)
            if d < minM then monoPenalty = monoPenalty + (minM - d) / minM end
        end
    end

    local hueDrift  = ColorSpace.deltaOklab(cand, actorInfo.colors.c)
    local lumaDrift = math.abs(ColorUtil.luminance(cand) - ColorUtil.luminance(actorInfo.colors.c))

    return contrastPenalty * paletteScoreWeights.contrast
        + collisionPenalty * paletteScoreWeights.collision
        + monoPenalty * paletteScoreWeights.mono
        + hueDrift * paletteScoreWeights.hue_drift
        + lumaDrift * paletteScoreWeights.luma_drift
end

function PaletteEngine.sortActors(data, actors)
    local sorted = {}
    for _, a in ipairs(actors) do table.insert(sorted, a) end
    table.sort(sorted, function(x, y)
        local lx = (data[x] and data[x].line_count) or 0
        local ly = (data[y] and data[y].line_count) or 0
        if lx ~= ly then return lx > ly end
        local xn = (x == "") and 1 or 0
        local yn = (y == "") and 1 or 0
        if xn ~= yn then return xn < yn end
        return x < y
    end)
    return sorted
end

function PaletteEngine.highContrastFallback(actorInfo)
    local origLum = ColorUtil.luminance(actorInfo.colors.c)
    return origLum > 0.4 and colorBlack or colorWhite
end

function PaletteEngine.remapVSFCorners(actorInfo, profile)
    profile = AccessibilityProfiles.get(profile)
    local acc = actorInfo.accessibility
    if not acc then return nil end
    local pol = profile.policy or {}
    local thr = profile.thresholds or {}
    local minMono = thr.min_mono_luma_delta or 0.12

    local result = {}
    for tag, vc in pairs(actorInfo.vsf_corners or {}) do
        local targetColor=tag=="3vc" and acc.outline or tag=="4vc" and acc.shadow or
            tag=="2vc" and actorInfo.colors["2c"] or acc.fill
        if pol.force_fill then
            local f = ColorUtil.normalize(targetColor)
            result[tag] = { f, f, f, f }
        elseif pol.force_mono then
            local out = {}
            for i = 1, 4 do out[i] = CVDSim.monochrome(vc[i], 1.0) end
            result[tag] = out
        else
            local lums, lo, hi = {}, math.huge, -math.huge
            for i = 1, 4 do
                lums[i] = ColorUtil.luminance(vc[i])
                if lums[i] < lo then lo = lums[i] end
                if lums[i] > hi then hi = lums[i] end
            end
            local origRange = hi - lo
            local varies = origRange > 1e-4

            if not varies then
                local f = targetColor
                result[tag] = { f, f, f, f }
            else
                local baseLum = ColorUtil.luminance(targetColor)
                local desiredRange = math.max(origRange, minMono * 1.5)
                local lowL = baseLum - desiredRange / 2
                local highL = baseLum + desiredRange / 2
                if lowL < 0 then highL = math.min(1, highL + (-lowL)); lowL = 0 end
                if highL > 1 then lowL = math.max(0, lowL - (highL - 1)); highL = 1 end
                if highL - lowL < minMono then
                    if baseLum > 0.5 then lowL = math.max(0, highL - minMono * 1.5)
                    else                  highL = math.min(1, lowL + minMono * 1.5) end
                end

                local r, g, b = ColorUtil.toRGB(targetColor)
                r,g,b=Color.srgb8ToLinear(r),Color.srgb8ToLinear(g),Color.srgb8ToLinear(b)
                local out = {}
                for i = 1, 4 do
                    local t = (lums[i] - lo) / origRange
                    local targetL = lowL + t * (highL - lowL)
                    local function channel(value)
                        if targetL<=baseLum then return Color.linearToSrgb8(baseLum>0 and value*targetL/baseLum or 0) end
                        return Color.linearToSrgb8(value+(1-value)*(targetL-baseLum)/(1-baseLum))
                    end
                    out[i] = ColorUtil.fromRGB(channel(r),channel(g),channel(b))
                end
                result[tag] = out
            end
        end
    end
    return result
end

function PaletteEngine.remapActors(data, actors, profile)
    profile = AccessibilityProfiles.get(profile)
    local pol = profile.policy or {}

    if pol.audit_only then
        return data
    end

    if pol.force_fill then
        local fill    = ColorUtil.normalize(pol.force_fill)
        local outline = ColorUtil.normalize(pol.force_outline or colorBlack)
        local shadow  = ColorUtil.normalize(pol.force_shadow or outline)
        for _, a in ipairs(actors) do
            data[a].accessibility = {
                fill = fill, outline = outline, shadow = shadow,
                contrast = ColorUtil.contrastRatio(fill, outline),
                contrast_worst = PaletteEngine.contrastAcrossVision(fill, outline, profile),
                source = "forced",
            }
            if data[a].has_vsf then
                data[a].accessibility.vsf = PaletteEngine.remapVSFCorners(data[a], profile)
            end
        end
        return data
    end

    if pol.force_mono then
        for _, a in ipairs(actors) do
            local mono = CVDSim.monochrome(data[a].colors.c, 1.0)
            local outline = PaletteEngine.pickOutline(mono, profile)
            data[a].accessibility = {
                fill = mono, outline = outline, shadow = outline,
                contrast = ColorUtil.contrastRatio(mono, outline),
                contrast_worst = PaletteEngine.contrastAcrossVision(mono, outline, profile),
                source = "mono",
            }
            if data[a].has_vsf then
                data[a].accessibility.vsf = PaletteEngine.remapVSFCorners(data[a], profile)
            end
        end
        return data
    end

    local sorted = PaletteEngine.sortActors(data, actors)
    local assigned = {}
    for _, a in ipairs(sorted) do
        local cands = PaletteEngine.makeCandidates(data[a], profile)
        local best, bestCost = nil, math.huge
        for _, c in ipairs(cands) do
            local cost = PaletteEngine.scoreCandidate(c, a, data[a], assigned, profile)
            if cost < bestCost then best, bestCost = c, cost end
        end
        if not best or bestCost == math.huge then
            best = PaletteEngine.highContrastFallback(data[a])
        end
        local outline = PaletteEngine.pickOutline(best, profile)
        data[a].accessibility = {
            fill = best, outline = outline, shadow = outline,
            contrast = ColorUtil.contrastRatio(best, outline),
            contrast_worst = PaletteEngine.contrastAcrossVision(best, outline, profile),
            source = (best == data[a].colors.c) and "kept" or "remap",
        }
        assigned[a] = best
        if data[a].has_vsf then
            data[a].accessibility.vsf = PaletteEngine.remapVSFCorners(data[a], profile)
        end
    end
    return data
end

local AccessibilityApply = {}

local function lineHasAnyVsf(text)
    for _, call in ipairs(LineOps.tagCalls(text)) do
        if call.name:match("^[1-4]?vc$") then return true end
    end
    return false
end

function AccessibilityApply.execute(subs,data,actors,styleMap,profile,options)
    profile=AccessibilityProfiles.get(profile)
    options=options or {}
    local policy=profile.policy or {}
    if policy.audit_only then return 0,0,"El perfil "..profile.id.." genera informe de evaluación." end
    local styles=options.apply_mode=="Styles"
    if styles then
        for _, actor in ipairs(actors) do
            for _, id in ipairs(data[actor].ids or {}) do
                local line=subs[id]
                if isDialogueLine(line) and (options.include_drawings or not LineOps.hasDrawing(line.text)) and lineHasAnyVsf(line.text) then
                    return 0,0,"El actor '"..actorLabel(actor).."' usa colores VSF; aplica como Etiquetas."
                end
            end
        end
    end
    local addBord=options.add_bord_shad
    if addBord==nil then addBord=policy.add_bord_shad end
    return applyActorPalettes(subs,data,actors,styleMap or {},{
        styles=styles,suffix=profile.id=="HIGH_CONTRAST" and "_Z_ACC_HC" or "_Z_ACC",
        autoClean=styles,harmonize=not styles,vsfRemap=true,
        slots={["1"]=true,["3"]=true,["4"]=true},opaque=options.preserve_alpha==false,
        bord=addBord and (policy.bord or 3) or nil,shad=policy.shad or 1,
        includeDrawings=options.include_drawings==true,
        palette=function(info)
            local acc=info.accessibility
            if acc then return {c=Color.normalize(acc.fill),["3c"]=Color.normalize(acc.outline),
                ["4c"]=Color.normalize(acc.shadow),vsf=acc.vsf} end
        end,
    })
end

local AccessibilityConfig = {}
local getSettings

local accessConfigDefaults = {
    custom_profiles = {},
    active_profile   = "DALTONICO",
    apply_mode       = "Tags",
    preserve_alpha   = true,
    add_bord_shad    = false,
    include_drawings = false,
}

local validApplyModes = { Tags = true, Styles = true }

local function accessibilityConfigPath()
    return aegisub.decode_path("?user") .. "/zheus_accessibility.lua"
end

local function serializeLua(v, indent)
    indent = indent or ""
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t == "nil" then return "nil" end
    if t ~= "table" then return string.format("%q", tostring(v)) end
    local nextIndent = indent .. "  "
    local parts = { "{" }
    local isArray = (#v > 0)
    if isArray then
        for _, x in ipairs(v) do
            table.insert(parts, nextIndent .. serializeLua(x, nextIndent) .. ",")
        end
    else
        local keys = {}
        for k in pairs(v) do table.insert(keys, k) end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            local key
            if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                key = k
            else
                key = "[" .. serializeLua(k, nextIndent) .. "]"
            end
            table.insert(parts, nextIndent .. key .. " = " .. serializeLua(v[k], nextIndent) .. ",")
        end
    end
    table.insert(parts, indent .. "}")
    return table.concat(parts, "\n")
end

local safeLoadLuaTable = Settings.parseLiteralTable

function AccessibilityConfig.load()
    local merged = {}
    for k, v in pairs(accessConfigDefaults) do merged[k] = v end
    local stored = getSettings():values("accessibility")

    if type(stored.custom_profiles) == "table" then
        local validProfiles = {}
        for id, p in pairs(stored.custom_profiles) do
            if type(p) == "table" and not builtinProfileIds[id] then
                local registered, sanitized = AccessibilityProfiles.register(p, id)
                if registered then validProfiles[id] = sanitized end
            end
        end
        merged.custom_profiles = validProfiles
    end
    for k, def in pairs(accessConfigDefaults) do
        local v = stored[k]
        if k ~= "custom_profiles" and v ~= nil and type(v) == type(def) then
            if k == "active_profile" then
                if AccessibilityProfiles.list[v] then merged[k] = v end
            elseif k == "apply_mode" then
                if validApplyModes[v] then merged[k] = v end
            else
                merged[k] = v
            end
        end
    end
    return merged
end

function AccessibilityConfig.save(t)
    local current = AccessibilityConfig.load()

    if type(t.custom_profiles) == "table" then
        local validProfiles = {}
        for id, p in pairs(t.custom_profiles) do
            if type(p) == "table" and not builtinProfileIds[id] then
                local registered, sanitized = AccessibilityProfiles.register(p, id)
                if registered then validProfiles[id] = sanitized end
            end
        end
        current.custom_profiles = validProfiles
    end
    for k, def in pairs(accessConfigDefaults) do
        local v = t[k]
        if k ~= "custom_profiles" and v ~= nil and type(v) == type(def) then
            if k == "active_profile" then
                if AccessibilityProfiles.list[v] then current[k] = v end
            elseif k == "apply_mode" then
                if validApplyModes[v] then current[k] = v end
            else
                current[k] = v
            end
        end
    end
    getSettings():update("accessibility",current)
    return getSettings():write()
end



local AccessibilityExportFile = {}

function AccessibilityExportFile.export(data, actors, profile)
    profile = AccessibilityProfiles.get(profile)

    local fp = aegisub.dialog.save("Exportar paleta accesible - Zheus Colormanager", "", "", "*.txt", false)
    if not fp then return nil end
    if not (fp:match("%.txt$") or fp:match("%.lua$")) then fp = fp .. ".txt" end

    local out = {
        version = 3,
        type = "ACCESSIBILITY",
        application = "Zheus Colormanager",
        script_version = script_version,
        format = "Zheus Colormanager - Paleta accesible",
        format_version = 3,
        profile = profile.id,
        profile_label = AccessibilityProfiles.label(profile.id),
        actors = {},
    }
    for _, a in ipairs(actors) do
        local info = data[a]
        local acc = info.accessibility
        local row = {
            original = {
                c    = info.colors.c,
                ["2c"] = info.colors["2c"],
                ["3c"] = info.colors["3c"],
                ["4c"] = info.colors["4c"],
            },
        }
        if acc then
            row.remap = {
                c    = acc.fill,
                ["2c"] = info.colors["2c"],
                ["3c"] = acc.outline,
                ["4c"] = acc.shadow,
            }
            row.score = { contrast = acc.contrast or 0, contrast_worst = acc.contrast_worst or acc.contrast or 0, source = acc.source or "" }
        end
        if info.has_vsf then
            row.vsf = {}
            for _, tag in ipairs(vsfTags) do
                local vc = acc and acc.vsf and acc.vsf[tag] or info.vsf_corners[tag]
                if vc then row.vsf[tag] = { vc[1], vc[2], vc[3], vc[4] } end
            end
        end
        out.actors[a] = row
    end

    local serialized = "return " .. serializeLua(out)
    local ok, err = PyBridge.writeFile(fp, serialized)
    if not ok then return "Error al escribir: " .. tostring(err) end
    return "Exportados " .. #actors .. " actores -> " .. fp
end

function AccessibilityExportFile.import(data, actors)
    local fp = aegisub.dialog.open("Importar paleta accesible - Zheus Colormanager", "", "", "*.txt;*.lua", false, true)
    if not fp then return nil end
    local content, readError = PyBridge.readFile(fp)
    if not content then return "Error al leer el archivo: " .. tostring(readError) end

    local imported, invalid, missing = 0, 0, {}

    local v3 = safeLoadLuaTable(content)
    if type(v3) == "table" then
        if v3.version ~= 3 then
            return "Versión de paleta accesible no compatible: " .. tostring(v3.version)
        end
        if type(v3.actors) ~= "table" then
            return "La paleta accesible v3 no contiene una tabla de actores válida."
        end
        for actor, row in pairs(v3.actors) do
            if type(actor) == "string" and data[actor] and type(row) == "table" then
                local src = type(row.remap) == "table" and row.remap or row.original
                local c1 = type(src) == "table" and ColorUtil.normalizeStrict(src.c) or nil
                local c2 = type(src) == "table" and src["2c"] ~= nil and ColorUtil.normalizeStrict(src["2c"]) or nil
                local c3 = type(src) == "table" and src["3c"] ~= nil and ColorUtil.normalizeStrict(src["3c"]) or nil
                local c4 = type(src) == "table" and src["4c"] ~= nil and ColorUtil.normalizeStrict(src["4c"]) or nil
                local valid2 = type(src) == "table" and (src["2c"] == nil or c2 ~= nil)
                local valid3 = type(src) == "table" and (src["3c"] == nil or c3 ~= nil)
                local valid4 = type(src) == "table" and (src["4c"] == nil or c4 ~= nil)
                local validVSF, normalizedVSF = true, {}
                if row.vsf ~= nil and type(row.vsf) ~= "table" then
                    validVSF = false
                elseif type(row.vsf) == "table" then
                    for tag, vc in pairs(row.vsf) do
                        local tuple = {}
                        local tupleValid = data[actor].vsf_corners[tag] ~= nil and type(vc) == "table"
                        local tupleCount = 0
                        if tupleValid then
                            for key in pairs(vc) do
                                if type(key) ~= "number" or key ~= math.floor(key) or key < 1 or key > 4 then
                                    tupleValid = false
                                    break
                                end
                                tupleCount = tupleCount + 1
                            end
                        end
                        if tupleValid and tupleCount == 4 then
                            for corner = 1, 4 do
                                tuple[corner] = ColorUtil.normalizeStrict(vc[corner])
                                if not tuple[corner] then tupleValid = false; break end
                            end
                        else
                            tupleValid = false
                        end
                        if not tupleValid then
                            validVSF = false
                            break
                        end
                        normalizedVSF[tag] = tuple
                    end
                end
                if c1 and valid2 and valid3 and valid4 and validVSF then
                    data[actor].colors.c = c1
                    data[actor].colors["2c"] = c2 or data[actor].colors["2c"]
                    data[actor].colors["3c"] = c3 or data[actor].colors["3c"]
                    data[actor].colors["4c"] = c4 or data[actor].colors["4c"]
                    for tag, tuple in pairs(normalizedVSF) do
                        data[actor].vsf_corners[tag] = tuple
                        data[actor].has_vsf = true
                    end
                    imported = imported + 1
                else
                    invalid = invalid + 1
                end
            elseif type(actor) == "string" and not data[actor] then
                table.insert(missing, actor)
            else
                invalid = invalid + 1
            end
        end
        local msg = "Importados (v3): " .. imported .. " / " .. #actors
        if invalid > 0 then msg = msg .. "\nEntradas inválidas omitidas: " .. tostring(invalid) end
        if #missing > 0 then
            msg = msg .. "\nFuera de selección: " .. table.concat(missing, ", "):sub(1, 80)
        end
        return msg
    end

    if not content:find("|", 1, true) then
        return "El archivo no contiene una paleta accesible v2 o v3 reconocible."
    end

    for l in content:gmatch("[^\r\n]+") do
        if not l:match("^#") and l ~= "" then
            local parts = {}
            for part in (l.."|"):gmatch("(.-)|") do table.insert(parts,part) end
            if #parts >= 2 then
                local actor = trim(parts[1])
                if data[actor] then
                    local t = {}
                    for x in parts[2]:gmatch("[^,]+") do table.insert(t, x) end
                    local c1 = #t == 3 and ColorUtil.normalizeStrict(t[1]) or nil
                    local c3 = c1 and ColorUtil.normalizeStrict(t[2]) or nil
                    local c4 = c3 and ColorUtil.normalizeStrict(t[3]) or nil
                    if c1 and c3 and c4 then
                        data[actor].colors.c = c1
                        data[actor].colors["3c"] = c3
                        data[actor].colors["4c"] = c4
                        imported = imported + 1
                    else
                        invalid = invalid + 1
                    end
                else
                    table.insert(missing, actor)
                end
            end
        end
    end
    local msg = "Importados (v2): " .. imported .. " / " .. #actors
    if invalid > 0 then msg = msg .. "\nEntradas inválidas omitidas: " .. tostring(invalid) end
    if #missing > 0 then msg = msg .. "\nFuera de selección: " .. table.concat(missing, ", "):sub(1, 80) end
    return msg
end

local CalibrationWizard = {}

CalibrationWizard.answers = { "diferentes", "iguales", "duda" }

CalibrationWizard.questions = {
    {
        id = "red_green_dark", label = "Rojo oscuro vs verde oscuro",
        left = "&H000080&", right = "&H008000&",
        weights = { protan = 0.50, deutan = 0.50 },
    },
    {
        id = "red_vs_brown", label = "Rojo vs marrón",
        left = "&H0000FF&", right = "&H13458B&",
        weights = { deutan = 0.40, protan = 0.20 },
    },
    {
        id = "blue_vs_purple", label = "Azul vs morado",
        left = "&HFF0000&", right = "&H800080&",
        weights = { tritan = 0.40, protan = 0.10 },
    },
    {
        id = "yellow_vs_white", label = "Amarillo vs blanco",
        left = "&H00FFFF&", right = "&HFFFFFF&",
        weights = { tritan = 0.50 },
    },
    {
        id = "cyan_vs_light_gray", label = "Cian vs gris claro",
        left = "&HFFFF00&", right = "&HD0D0D0&",
        weights = { mono = 0.70 },
    },
}

function CalibrationWizard.computeProfile(responses)
    local sev = { protan = 0, deutan = 0, tritan = 0, mono = 0 }
    for _, q in ipairs(CalibrationWizard.questions) do
        local ans = responses[q.id]
        local factor = 0.0
        if ans == "iguales" then factor = 1.0
        elseif ans == "duda" then factor = 0.5 end
        for k, w in pairs(q.weights) do
            sev[k] = (sev[k] or 0) + w * factor
        end
    end
    for k, v in pairs(sev) do
        if v < 0 then sev[k] = 0 elseif v > 1 then sev[k] = 1 end
    end
    local maxSev = math.max(sev.protan or 0, sev.deutan or 0, sev.tritan or 0, sev.mono or 0)
    local calibratedPalette = maxSev >= 0.35 and "subtitle_cvd" or nil
    return {
        id = "CUSTOM",
        label = "Personalizado",
        description = "Ajusta la paleta con los pares calibrados.",
        criteria = "Preferencias de simulación y contraste según los pares seleccionados.",
        simulate = sev,
        thresholds = {
            min_text_contrast     = maxSev >= 0.50 and 7.0 or 4.5,
            min_cvd_text_contrast = 4.0,
            min_actor_delta       = 0.060 + maxSev * 0.025,
            min_mono_luma_delta   = 0.12 + (sev.mono or 0) * 0.06,
        },
        policy = {
            preserve_hue  = maxSev < 0.35,
            destructive   = false,
            calibrated    = true,
            use_palette   = calibratedPalette,
            add_bord_shad = maxSev >= 0.35,
            bord          = 3,
            shad          = 1,
        },
    }
end

function CalibrationWizard.run()
    local ui = {
        { class = "label", label = "Calibración visual", x = 0, y = 0, width = 6 },
        { class = "label", label = "Ajusta la lectura de color para esta escena.", x = 0, y = 1, width = 6 },
        { class = "label", label = "Para cada par, registra tu percepción.", x = 0, y = 2, width = 6 },
        { class = "label", label = "Pregunta",     x = 0, y = 3, width = 2 },
        { class = "label", label = "Color A",      x = 2, y = 3 },
        { class = "label", label = "Color B",      x = 3, y = 3 },
        { class = "label", label = "Respuesta",    x = 4, y = 3, width = 2 },
    }
    local y = 4
    for _, q in ipairs(CalibrationWizard.questions) do
        table.insert(ui, { class = "label",      label = q.label, x = 0, y = y, width = 2, hint = q.id })
        table.insert(ui, { class = "color", name = "_ref_" .. q.id .. "_a", value = ColorUtil.toHex(q.left),  x = 2, y = y, hint = "Referencia visual" })
        table.insert(ui, { class = "color", name = "_ref_" .. q.id .. "_b", value = ColorUtil.toHex(q.right), x = 3, y = y, hint = "Referencia visual" })
        table.insert(ui, { class = "dropdown",   name = q.id, items = CalibrationWizard.answers, value = "diferentes", x = 4, y = y, width = 2 })
        y = y + 1
    end
    table.insert(ui, { class = "label", label = "Destino: perfil Personalizado.", x = 0, y = y, width = 6 })

    local btn, res = aegisub.dialog.display(ui, { "Calibrar", "Cancelar" })
    if btn ~= "Calibrar" then return nil end

    local custom = CalibrationWizard.computeProfile(res or {})
    local cfg = AccessibilityConfig.load()
    cfg.custom_profiles = cfg.custom_profiles or {}
    cfg.custom_profiles.CUSTOM = custom
    cfg.active_profile = "CUSTOM"
    local ok, err = AccessibilityConfig.save(cfg)
    AccessibilityProfiles.register(custom)
    return custom, ok, err
end

local Config = {}
local configDefaults = {
    vcl = false,
    vc1_use = true,
    vc2_use = false,
    vc3_use = false,
    vc4_use = false,
    vc1_1 = "&HFFCC00&", vc1_2 = "&HFF6600&",
    vc1_3 = "&HFF0066&", vc1_4 = "&HFF00CC&",
    vc2_1 = "&HFFFFFF&", vc2_2 = "&HCCCCCC&",
    vc2_3 = "&H999999&", vc2_4 = "&H666666&",
    vc3_1 = "&H0033CC&", vc3_2 = "&H0066FF&",
    vc3_3 = "&H00CCFF&", vc3_4 = "&H66FFFF&",
    vc4_1 = "&H6622CC&", vc4_2 = "&H9933FF&",
    vc4_3 = "&HCC33FF&", vc4_4 = "&HFF66FF&",
    replace_slot_1 = true,
    replace_slot_2 = true,
    replace_slot_3 = true,
    replace_slot_4 = true,
}

local function configPath()
    return aegisub.decode_path("?user") .. "/zheus_color_manager.lua"
end

local settingsStore
getSettings = function()
    if not settingsStore then
        settingsStore = Settings.open(script_namespace,script_version,{main=configDefaults,accessibility=accessConfigDefaults},{
            {path=configPath(),format="lua_literal",target="main"},
            {path=accessibilityConfigPath(),format="lua_literal",target="accessibility"},
        })
    end
    return settingsStore
end

function Config.load()
    return getSettings():values("main")
end

function Config.save(values)
    getSettings():update("main",values)
    local ok,err=getSettings():write()
    if not ok then KiteUI.message("No se pudo guardar la configuración: "..tostring(err),{button="Aceptar",width=36,height=UI.textHeight(err,14)}) end
    return ok,err
end

pcall(AccessibilityConfig.load)

local helpText = "ZHEUS COLORMANAGER " .. script_version .. [[

Panel principal
Gestores:
- Colores por Actor: edita relleno, borde y sombra por actor.
- Actores: renombra o fusiona actores.

Cambios:
- De colores: reemplaza colores detectados en los canales marcados.
- De colores en secuencia: abre ColorRelay para cambios por fotograma.

Botones:
- Gestor ejecuta el selector Gestores.
- Cambio ejecuta el selector Cambios.
- VSF aplica los degradados \1vc, \2vc, \3vc y \4vc del panel.
- Daltonismo abre auditoría y remapeo accesible.

Comportamiento
Cancelar o Volver regresa al panel cuando la acción no aplicó cambios.
Las acciones aplicadas cierran el macro y registran deshacer.

Notas
Los canales \c, \2c, \3c y \4c son colores ASS.
Las etiquetas \vc requieren VSFilterMod.
El informe superior solo resume la selección actual.
]]

local function showMsg(msg)
    return KiteUI.message(msg, {button="Aceptar", width=36, height=UI.textHeight(msg,14)})
end

local function gestorDeActores(subs,sel)
    local actors,seen,targets={},{},{}
    for _,id in ipairs(LineOps.normalizeIndices(subs,sel)) do
        local line=subs[id]
        if isDialogueLine(line) then
            local actor=tostring(line.actor or "")
            if not seen[actor] then actors[#actors+1]=actor;seen[actor]=true;targets[actor]=actor end
        end
    end
    table.sort(actors)
    local page,pages=1,math.max(1,math.ceil(#actors/uiActorsPerPage))
    while true do
        local ui={
            {class="label",label="Actores · página "..page.."/"..pages,x=0,y=0,width=8},
            {class="label",label="Escribe el mismo destino para fusionar. Vacío quita el actor.",x=0,y=1,width=8},
            {class="label",label="Original",x=0,y=2,width=4},
            {class="label",label="Destino",x=4,y=2,width=4},
        }
        local first,last=(page-1)*uiActorsPerPage+1,math.min(page*uiActorsPerPage,#actors)
        for index=first,last do
            ui[#ui+1]={class="label",label=actorPreview(actors[index],28),hint=actorLabel(actors[index]),x=0,y=index-first+3,width=4}
            ui[#ui+1]={class="edit",name="actor"..index,text=targets[actors[index]],x=4,y=index-first+3,width=4}
        end
        local buttons={"Aplicar"}
        if pages>1 then buttons[#buttons+1]="Anterior";buttons[#buttons+1]="Siguiente" end
        buttons[#buttons+1]="Cancelar"
        local action,result=aegisub.dialog.display(ui,buttons,{ok="Aplicar",cancel="Cancelar",close="Cancelar"})
        if not action or action=="Cancelar" then return "cancel" end
        result=result or {}
        for index=first,last do
            local target=result["actor"..index]
            if type(target)=="string" then targets[actors[index]]=target end
        end
        if action=="Anterior" then page=math.max(1,page-1)
        elseif action=="Siguiente" then page=math.min(pages,page+1)
        elseif action=="Aplicar" then
            local count=LineOps.transaction(subs,function()
                local changed=0
                for _,id in ipairs(LineOps.normalizeIndices(subs,sel)) do
                    LineOps.checkCancelled()
                    local source=subs[id]
                    if isDialogueLine(source) then
                        local target=targets[tostring(source.actor or "")]
                        if target~=source.actor then
                            local line=Core.copy(source);line.actor=target;subs[id]=line;changed=changed+1
                        end
                    end
                end
                return changed
            end)
            return count>0 and "applied" or "nochange",count
        else return "cancel" end
    end
end

local function ejecutarGestorDeActores(subs, sel)
    if not sel or #sel == 0 then
        showMsg("Selecciona líneas para editar actores.")
        return false, "empty"
    end
    local action, changed = gestorDeActores(subs, sel)
    if action ~= "done" then return false, action end
    if not changed or changed == 0 then return false, "nochange" end
    aegisub.set_undo_point("Zheus Colormanager - Actores")
    return true, "done"
end

local SelectionReport = {}

function SelectionReport.collect(subs, sel)
    local stats = {
        lineCount       = 0,
        emptyActorLines = 0,
        actorLines      = {},
        solidColors     = {},
        vsfColors       = {},
        anyVSF          = false,
        anySolid        = false,
    }
    for _, i in ipairs(LineOps.normalizeIndices(subs, sel)) do
        local l = subs[i]
        if isDialogueLine(l) then
            stats.lineCount = stats.lineCount + 1
            local actor = tostring(l.actor or "")
            if actor == "" then
                stats.emptyActorLines = stats.emptyActorLines + 1
            end
            stats.actorLines[actor] = (stats.actorLines[actor] or 0) + 1
            local text = tostring(l.text or "")
            for _,call in ipairs(LineOps.tagCalls(text)) do
                local slot=TagStripper.colorSlot(call.name)
                if slot then
                    local vsf=call.name:find("vc",1,true)~=nil
                    for raw in call.value:gmatch(patHexToken) do
                        local color=Color.parseTag(raw)
                        if color then
                            if vsf then stats.vsfColors[color],stats.anyVSF=true,true
                            else stats.solidColors[color],stats.anySolid=true,true end
                        end
                    end
                end
            end
        end
    end
    return stats
end

local function contrastStatus(minCR)
    if minCR < wcagFail then return "AJUSTAR" end
    if minCR < wcagAa   then return "REVISAR" end
    return "OK"
end

function SelectionReport.format(subs, sel)
    local styleMap     = collectStyles(subs)
    local data, actors = StyleScanner.scanActors(subs, sel, styleMap)
    local stats        = SelectionReport.collect(subs, sel)

    local solidCount, vsfCount = 0, 0
    for _ in pairs(stats.solidColors) do solidCount = solidCount + 1 end
    for _ in pairs(stats.vsfColors)   do vsfCount   = vsfCount   + 1 end

    local out = {}
    local function w(s) table.insert(out, s) end

    w("# INFORME DE SELECCIÓN")
    w("")
    w("Actores            : " .. #actors)
    w("Líneas             : " .. stats.lineCount)
    if stats.emptyActorLines > 0 then
        w("Líneas sin actor   : " .. stats.emptyActorLines)
    end
    w("")
    w("COLORES DETECTADOS")
    w("--------------------------------------------------")
    w(string.format("  Sólidos (\\c, \\2c, \\3c, \\4c)  : %d", solidCount))
    w(string.format("  VSFilterMod (\\vc)            : %d", vsfCount))
    w(string.format("  Total único                  : %d", solidCount + vsfCount))
    if stats.anyVSF and stats.anySolid then
        w("  Selección mixta: conviven colores sólidos y VSF.")
    elseif stats.anyVSF then
        w("  Selección 100% VSFilterMod.")
    elseif stats.anySolid then
        w("  Selección 100% colores sólidos.")
    else
        w("  Sin etiquetas de color: se leen del estilo.")
    end
    w("")
    w("CONTRASTE POR ACTOR (relleno vs borde y sombra)")
    w("--------------------------------------------------")
    w(string.format("  %-18s %7s %7s   %s", "Actor", "c<->3c", "c<->4c", "Estado"))
    local nOK, nWarn, nFail = 0, 0, 0
    for _, a in ipairs(actors) do
        local info = data[a]
        local cr3 = ColorUtil.contrastRatio(info.colors.c, info.colors["3c"])
        local cr4 = ColorUtil.contrastRatio(info.colors.c, info.colors["4c"])
        local status = contrastStatus(math.min(cr3, cr4))
        if     status == "OK"      then nOK   = nOK   + 1
        elseif status == "REVISAR" then nWarn = nWarn + 1
        else                            nFail = nFail + 1 end
        local visibleStatus = status == "OK" and "BIEN" or status
        w(string.format("  %-18s %7.1f %7.1f   %s",
            actorLabel(a), cr3, cr4, visibleStatus))
    end
    w("")
    w(string.format("  %d BIEN   ·   %d REVISAR   ·   %d AJUSTAR",
        nOK, nWarn, nFail))
    w("")
    w("La auditoría completa de accesibilidad está en")
    w("Daltonismo > selector 'Auditar' > Aplicar.")

    return table.concat(out, "\n")
end

local function dashboardAuditText(subs, sel)
    local ok, result = pcall(SelectionReport.format, subs, sel)
    return ok and result or "Informe pendiente de actualización."
end

local function addVSFBlock(ui, cfg, tagName, label, x, baseY)
    local prefix = "vc" .. tagName:sub(1, 1)
    local enabledName = prefix .. "_use"
    table.insert(ui, { class = "checkbox", name = enabledName, label = label, value = cfg[enabledName], x = x, y = baseY, width = 3 })
    table.insert(ui, { class = "label", label = "Sup:", x = x, y = baseY + 1, width = 1 })
    table.insert(ui, { class = "color", name = prefix .. "_1", value = ColorUtil.toHex(cfg[prefix .. "_1"]), x = x + 1, y = baseY + 1, hint = "\\" .. tagName .. " superior izq" })
    table.insert(ui, { class = "color", name = prefix .. "_2", value = ColorUtil.toHex(cfg[prefix .. "_2"]), x = x + 2, y = baseY + 1, hint = "\\" .. tagName .. " superior der" })
    table.insert(ui, { class = "label", label = "Inf:", x = x, y = baseY + 2, width = 1 })
    table.insert(ui, { class = "color", name = prefix .. "_3", value = ColorUtil.toHex(cfg[prefix .. "_3"]), x = x + 1, y = baseY + 2, hint = "\\" .. tagName .. " inferior izq" })
    table.insert(ui, { class = "color", name = prefix .. "_4", value = ColorUtil.toHex(cfg[prefix .. "_4"]), x = x + 2, y = baseY + 2, hint = "\\" .. tagName .. " inferior der" })
end

local function addReplaceSlotControls(ui, cfg, baseY)
    local slots = slotFilterFromConfig(cfg)
    table.insert(ui, { class = "label", label = "Canales para cambiar:", x = 0, y = baseY, width = 2 })
    table.insert(ui, { class = "checkbox", name = "replace_slot_1", label = "\\c",  value = slots["1"], x = 2, y = baseY, width = 1 })
    table.insert(ui, { class = "checkbox", name = "replace_slot_2", label = "\\2c", value = slots["2"], x = 3, y = baseY, width = 1 })
    table.insert(ui, { class = "checkbox", name = "replace_slot_3", label = "\\3c", value = slots["3"], x = 4, y = baseY, width = 1 })
    table.insert(ui, { class = "checkbox", name = "replace_slot_4", label = "\\4c", value = slots["4"], x = 5, y = baseY, width = 1 })
end

local function buildVSFGradientPanel(cfg, auditText, status)
    local vsfY = 3 + UI.audit_height
    local ui = {
        { class = "label",   label = "Zheus Colormanager v" .. script_version .. " - selección", x = 0, y = 0, width = UI.dashboard_width },
        { class = "label",    label = "Gestores:", x = 0, y = 1, width = 2 },
        { class = "dropdown", name = "gestores", items = { "Colores por Actor", "Actores" }, value = "Colores por Actor", x = 2, y = 1, width = 4 },
        { class = "label",    label = "Cambios:", x = 0, y = 2, width = 2 },
        { class = "dropdown", name = "cambios", items = { "De colores", "De colores en secuencia", "Por tramos" }, value = "De colores", x = 2, y = 2, width = 4 },
        { class = "textbox", name = "audit_preview", text = auditText or "", x = 0, y = 3, width = UI.dashboard_width, height = UI.audit_height, readonly = true },
        { class = "label",    label = "Degradados VSFilterMod", x = 0, y = vsfY, width = 3, hint = "Requiere VSFilterMod para renderizar \\vc." },
        { class = "checkbox", name = "vcl", label = "Limpiar \\vc previos", value = cfg.vcl, x = 3, y = vsfY, width = 3 },
    }
    addVSFBlock(ui, cfg, "1vc", "\\1vc relleno", 0, vsfY + 1)
    addVSFBlock(ui, cfg, "2vc", "\\2vc secund.", 3, vsfY + 1)
    addVSFBlock(ui, cfg, "3vc", "\\3vc borde",   0, vsfY + 4)
    addVSFBlock(ui, cfg, "4vc", "\\4vc sombra",  3, vsfY + 4)
    addReplaceSlotControls(ui, cfg, vsfY + 7)
    if status and status ~= "" then
        table.insert(ui, { class = "label", label = status, x = 0, y = vsfY + 8, width = UI.dashboard_width })
    end
    return ui
end

local openAccessibilityAudit
local openAccessibilityApply
local openCalibrationWizard
local openAccessibilityExport

local function mainController(subs, sel, initMode, dataIn, actorsIn)
    if not sel or #sel == 0 then
        showMsg("Selecciona líneas.")
        return
    end

    local styleMap = collectStyles(subs)
    local cfg      = Config.load()
    local mode     = (type(initMode) == "string" and initMode) or "DASH"
    local data, actors = dataIn, actorsIn
    local page, status = 1, ""
    local editorOptions={ARCH={op="Etiquetas",cl=true},ARCHVSF={op="Etiquetas",cl=true}}
    local vsfTag = "1vc"

    local auditCache = nil
    local function getAuditText()
        if not auditCache then auditCache = dashboardAuditText(subs, sel) end
        return auditCache
    end
    local function invalidateAudit() auditCache = nil end
    local function rescan()
        styleMap = collectStyles(subs)
        data, actors = StyleScanner.scanActors(subs, sel, styleMap)
        invalidateAudit()
        local maxPage = math.max(1, math.ceil((actors and #actors or 1) / uiActorsPerPage))
        if page > maxPage then page = maxPage end
    end

    while true do
        local ui, btns, shown, displayedVSFTag

        if mode == "DASH" then
            ui = buildVSFGradientPanel(cfg, getAuditText(), status)
            btns = { "Gestor", "Cambio", "VSF", "Daltonismo", "Ayuda", "Cancelar" }
        elseif mode == "ARCH" then
            ui, shown = ManagerDialog.build(page, uiActorsPerPage, actors, data, nil, nil)
            local y = 3 + (shown or 0)
            table.insert(ui, { class = "dropdown", name = "op", items = { "Etiquetas", "Estilos", "Limpiar" }, value = editorOptions[mode].op, x = 0, y = y, width = 2 })
            table.insert(ui, { class = "checkbox", name = "cl", label = "Auto-limpiar (forzado en Estilos)", value = editorOptions[mode].cl, x = 2, y = y, width = 3 })
            if status ~= "" then
                table.insert(ui, { class = "label", label = status, x = 0, y = y + 1, width = 5 })
                y = y + 1
            end
            table.insert(ui,{class="dropdown",name="more",items={"VSF","Lista","Conflictos","Exportar","Importar"},value="Lista",x=0,y=y+1,width=5})
            btns = #actors>uiActorsPerPage and { "Aplicar", "←", "→", "Abrir", "Volver", "Cancelar" }
                or { "Aplicar", "Abrir", "Volver", "Cancelar" }
        elseif mode == "ARCHVSF" then
            displayedVSFTag = vsfTag
            ui, shown = ManagerDialog.build(page, uiActorsPerPage, actors, data, "vsf", displayedVSFTag)
            local y = 3 + (shown or 0)
            table.insert(ui, { class = "label",    label = "VSF (\\" .. displayedVSFTag .. ") - modo Etiquetas", x = 0, y = y, width = 6 })
            table.insert(ui, { class = "dropdown", name = "op", items = { "Etiquetas", "Limpiar" }, value = editorOptions[mode].op, x = 0, y = y + 1, width = 2 })
            table.insert(ui, { class = "checkbox", name = "cl", label = "Auto-limpiar", value = editorOptions[mode].cl, x = 2, y = y + 1, width = 2 })
            if status ~= "" then
                table.insert(ui, { class = "label", label = status, x = 0, y = y + 2, width = 6 })
                y = y + 1
            end
            table.insert(ui,{class="dropdown",name="more",items={"Exportar","Importar","Normal"},value="Normal",x=0,y=y+2,width=6})
            btns = #actors>uiActorsPerPage and { "Aplicar", "←", "→", "Abrir", "Volver", "Cancelar" }
                or { "Aplicar", "Abrir", "Volver", "Cancelar" }
        elseif mode == "LIST" then
            ui = ManagerDialog.build(page, uiActorsPerPage, actors, data, "summary", nil)
            btns = { "Volver" }
        elseif mode == "CONF" then
            ui = ManagerDialog.build(page, uiActorsPerPage, actors, data, "conflicts", nil)
            btns = { "Volver" }
        elseif mode == "HELP" then
            ui = { { class = "textbox", text = helpText, x = 0, y = 0, width = UI.help_width, height = UI.help_height, readonly = true } }
            btns = { "Volver" }
        end

        local btn, res = aegisub.dialog.display(ui, btns)
        if not btn or btn == "Cancelar" then break end
        res = res or {}
        if btn=="Abrir" then btn=res.more end

        if mode=="DASH" then
            for key,default in pairs(configDefaults) do if type(res[key])==type(default) then cfg[key]=res[key] end end
        elseif editorOptions[mode] then
            if res.op then editorOptions[mode].op=res.op end
            if res.cl~=nil then editorOptions[mode].cl=res.cl end
        end

        if mode == "ARCHVSF" and res.vctag and res.vctag ~= displayedVSFTag then
            ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, "vsf", displayedVSFTag)
            vsfTag = res.vctag
            status = "Editando \\" .. vsfTag .. "."
        elseif btn == "Gestor" then
            if res.gestores == "Actores" then
                local applied, actorAction = ejecutarGestorDeActores(subs, sel)
                if applied then
                    return
                end
                status = actorAction == "nochange" and "Actores: sin cambios." or "Actores: cancelado."
            end
            if res.gestores ~= "Actores" then
                rescan()
                if #actors == 0 then
                    status = "La selección está vacía de actores."
                else
                    mode = "ARCH"
                    status = #actors .. " actores cargados."
                end
            end
        elseif btn == "Ayuda" then
            mode = "HELP"
        elseif btn == "Lista" then
            ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, nil, nil)
            mode = "LIST"
        elseif btn == "Conflictos" then
            ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, nil, nil)
            mode = "CONF"
        elseif btn == "VSF" and mode == "ARCH" then
            ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, nil, nil)
            mode = "ARCHVSF"
        elseif btn == "Normal" then
            ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, "vsf", vsfTag)
            mode = "ARCH"
        elseif btn == "Volver" then
            if mode == "ARCH" then
                ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, nil, nil)
                mode = "DASH"
            elseif mode == "ARCHVSF" then
                ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, "vsf", vsfTag)
                mode = "ARCH"
            elseif mode == "LIST" or mode == "CONF" then
                mode = "ARCH"
            else
                mode = "DASH"
            end
        elseif btn == "←" or btn == "◁" then
            if mode == "ARCHVSF" then
                ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, "vsf", vsfTag)
            else
                ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, nil, nil)
            end
            page = math.max(1, page - 1)
        elseif btn == "→" or btn == "▷" then
            if mode == "ARCHVSF" then
                ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, "vsf", vsfTag)
            else
                ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, nil, nil)
            end
            local totalActors = actors and #actors or 0
            page = math.min(math.max(1, math.ceil(math.max(1, totalActors) / uiActorsPerPage)), page + 1)
        elseif btn == "Aplicar" then

            local applied, changedSelection = false, nil
            if mode == "ARCHVSF" then
                ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, "vsf", vsfTag)
                local cnt, err, selected = ManagerApply.execute(subs, data, actors, styleMap, res.op, res.cl, true, vsfTag)
                if not cnt then
                    showMsg(err)
                    status = "Error: " .. (err or "Error al aplicar VSF.")
                else
                    aegisub.set_undo_point("Zheus Colormanager VSF")
                    status = cnt .. " líneas con \\" .. vsfTag .. " aplicadas."
                    applied = cnt > 0
                    changedSelection = selected
                end
            else
                ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, nil, nil)
                local cnt, err, selected = ManagerApply.execute(subs, data, actors, styleMap, res.op, res.cl, false, nil)
                if not cnt then
                    showMsg(err)
                    status = "Error: " .. (err or "Error al aplicar.")
                else
                    aegisub.set_undo_point("Zheus Colormanager")
                    status = cnt .. " líneas procesadas."
                    applied = cnt > 0
                    changedSelection = selected
                end
            end
            if applied then return changedSelection end
        elseif btn == "Exportar" then
            if mode == "ARCHVSF" then
                ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, "vsf", vsfTag)
            else
                ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, nil, nil)
            end
            local msg = ActorColorFile.io(data, actors, "Export")
            if msg then status = msg end
        elseif btn == "Importar" then
            if mode == "ARCHVSF" then
                ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, "vsf", vsfTag)
            else
                ManagerDialog.sync(data, actors, res, page, uiActorsPerPage, nil, nil)
            end
            local msg, hasVsfData = ActorColorFile.io(data, actors, "Import")
            if msg then
                status = msg
                if hasVsfData and mode ~= "ARCHVSF" then
                    status = msg .. " · cambiando a VSF."
                    mode = "ARCHVSF"
                end
            end
        elseif btn == "VSF" then
            local n, err = VSFCornerEditor.applyGradient(subs, sel, res)
            if err then
                status = "Error: " .. err
                cfg = Config.load()
            else
                Config.save(res)
                aegisub.set_undo_point("Zheus Colormanager VSF")

                if n and n > 0 then return end
                invalidateAudit()
                cfg = Config.load()
                status = (n or 0) .. " líneas con etiquetas VSF aplicadas."
            end
        elseif btn == "Cambio" then
            if res.cambios == "Por tramos" then
                return ColorUtil.segments.run(subs, sel)
            elseif res.cambios == "De colores en secuencia" then
                local _, relayAction = ColorRelay.run(subs, sel)
                if relayAction == "done" then
                    return
                end
                status = "ColorRelay: cancelado."
            else
                local n, err, action, replaceCfg = ColorReplacer.run(subs, sel, res)
                if replaceCfg then
                    Config.save(replaceCfg)
                    cfg = Config.load()
                end
                if err then
                    status = "Cambiar colores: " .. err
                elseif n > 0 then
                    aegisub.set_undo_point("Zheus Colormanager - Cambiar colores")
                    return
                elseif action == "back" then
                    status = "Cambiar colores: volvió sin aplicar."
                elseif action == "cancel" then
                    status = "Cambiar colores: cancelado."
                elseif action == "nochange" then
                    status = "Cambiar colores: sin cambios."
                else
                    status = "Cambios aplicados: 0."
                end
            end
        elseif btn == "Daltonismo" then
            local action, _, _, label, selected = openAccessibilityApply(subs, sel, nil, true)
            if action == "done" then
                if label then return selected end
                invalidateAudit()
                status = "Daltonismo: operación completada."
            end
        end
    end
end

local function openChromaManagerDirect(subs, sel)
    if not sel or #sel == 0 then showMsg("Selecciona líneas para abrir el gestor."); return end
    local styleMap = collectStyles(subs)
    local data, actors = StyleScanner.scanActors(subs, sel, styleMap)
    if #actors == 0 then
        showMsg("La selección está vacía de actores.")
    else
        return mainController(subs, sel, "ARCH", data, actors)
    end
end

local function openVSFManagerDirect(subs, sel)
    if not sel or #sel == 0 then showMsg("Selecciona líneas para abrir VSF."); return end
    local styleMap = collectStyles(subs)
    local data, actors = StyleScanner.scanActors(subs, sel, styleMap)
    if #actors == 0 then
        showMsg("La selección está vacía de actores.")
    else
        return mainController(subs, sel, "ARCHVSF", data, actors)
    end
end

local function runColorReplaceDirect(subs, sel)
    if not sel or #sel == 0 then showMsg("Selecciona líneas para cambiar colores."); return end
    local cfg = Config.load()
    local n, err, action, replaceCfg = ColorReplacer.run(subs, sel, cfg)
    if replaceCfg then Config.save(replaceCfg) end
    if err then showMsg("Cambiar colores: " .. err); return end
    if n and n > 0 then
        aegisub.set_undo_point("Zheus Colormanager - Cambiar colores")
        showMsg(n .. " líneas actualizadas.")
    elseif action == "nochange" then
        showMsg("Cambiar colores: sin cambios.")
    end
end

openAccessibilityAudit = function(subs, sel)
    if not sel or #sel == 0 then showMsg("Selecciona líneas para auditar."); return end
    local cfg = AccessibilityConfig.load()
    local report = AccessibilityAudit.run(subs, sel, cfg.active_profile)
    local text = AccessibilityReport.format(report, (function()
        local out = {}
        for a in pairs(report.actors) do table.insert(out, a) end
        table.sort(out)
        return out
    end)())
    aegisub.dialog.display({
        { class = "label",   label = "Auditoría de accesibilidad de color", x = 0, y = 0, width = 36 },
        { class = "textbox", name = "audit", text = text, x = 0, y = 1, width = 36, height = UI.textHeight(text, 16), readonly = true },
    }, { "Aceptar" })
end

local function profileApplyPanel(cfg, profileId, audit, viewMode)
    local profileChoices = AccessibilityProfiles.choices()
    if profileId and not AccessibilityProfiles.list[profileId] then profileId = nil end
    profileId = profileId or cfg.active_profile or "DALTONICO"
    local profileChoice = AccessibilityProfiles.choiceFromId(profileId)

    local headerLabel, bodyText
    if viewMode == "audit" then
        headerLabel = "Auditoría de accesibilidad (perfil Auditar):"
        local sortedActors = {}
        for a in pairs(audit.actors) do table.insert(sortedActors, a) end
        table.sort(sortedActors)
        bodyText = AccessibilityReport.format(audit, sortedActors)
    else
        headerLabel = "Guía de perfiles:"
        bodyText = AccessibilityProfiles.describeAll(profileId)
    end

    local pol = audit.profile.policy or {}
    local defaultBordShad = cfg.add_bord_shad
    if defaultBordShad==nil then defaultBordShad=pol.add_bord_shad==true end

    return {
        { class = "label",      label = "Paleta accesible",              x = 0, y = 0, width = 12 },
        { class = "label",      label = "Perfil:",                       x = 0, y = 1, width = 2 },
        { class = "dropdown",   name = "profile", items = profileChoices, value = profileChoice, x = 2, y = 1, width = 3 },
        { class = "label",      label = "Aplicar como:",                 x = 5, y = 1, width = 3 },
        { class = "dropdown",   name = "apply_mode", items = { "Etiquetas", "Estilos" }, value = cfg.apply_mode == "Styles" and "Estilos" or "Etiquetas", x = 8, y = 1, width = 3 },
        { class = "checkbox",   name = "preserve_alpha",   label = "Preservar alfa",       value = cfg.preserve_alpha,   x = 0, y = 2, width = 3 },
        { class = "checkbox",   name = "add_bord_shad",    label = "Forzar bord y shad",   value = defaultBordShad,      x = 3, y = 2, width = 4 },
        { class = "checkbox",   name = "include_drawings", label = "Incluir dibujos",      value = cfg.include_drawings, x = 7, y = 2, width = 3 },
        { class = "label",      label = headerLabel,                     x = 0, y = 3, width = 12 },
        { class = "textbox",    name = "profiles", text = bodyText,       x = 0, y = 4, width = 12, height = UI.textHeight(bodyText, 12), readonly = true },
    }
end

openAccessibilityApply = function(subs, sel, profileId, silent)
    if not sel or #sel == 0 then showMsg("Selecciona líneas para aplicar Daltonismo."); return end
    local cfg = AccessibilityConfig.load()
    local styleMap = collectStyles(subs)

    local viewMode = "guide"
    local importOverlay = nil

    local function runCycle(currentProfileId)
        local audit, data, actors = AccessibilityAudit.run(subs, sel, currentProfileId)
        if #actors == 0 then
            showMsg("La selección está vacía de actores.")
            return nil
        end
        if importOverlay then
            for actor, row in pairs(importOverlay) do
                local entry = data[actor]
                if entry then
                    for k, v in pairs(row.colors) do entry.colors[k] = v end
                    if row.vsf then
                        for tag, vc in pairs(row.vsf) do
                            entry.vsf_corners[tag] = { vc[1], vc[2], vc[3], vc[4] }
                        end
                        entry.has_vsf = true
                    end
                end
            end
        end
        local panel = profileApplyPanel(cfg, currentProfileId, audit, viewMode)
        local btn, res = aegisub.dialog.display(panel, { "Aplicar", "Calibrar", "Exportar", "Importar", "Cancelar" })
        if not btn or btn == "Cancelar" then return nil end
        res = res or {}

        local chosenProfileId = AccessibilityProfiles.idFromChoice(res.profile)
        local chosenApplyMode = res.apply_mode == "Estilos" and "Styles" or "Tags"
        cfg.active_profile = chosenProfileId
        cfg.apply_mode = chosenApplyMode
        cfg.preserve_alpha = res.preserve_alpha == true
        cfg.add_bord_shad = res.add_bord_shad == true
        cfg.include_drawings = res.include_drawings == true
        local configSaved, configError = AccessibilityConfig.save(cfg)
        if not configSaved then
            showMsg("No se pudo guardar la configuración de Daltonismo: " .. tostring(configError))
        end

        if btn == "Calibrar" then
            openCalibrationWizard()
            cfg = AccessibilityConfig.load()
            viewMode = "guide"
            return "retry", cfg.active_profile or chosenProfileId
        end

        if btn == "Importar" then
            local msg = AccessibilityExportFile.import(data, actors)
            if msg then
                showMsg(msg)
                importOverlay = {}
                for _, a in ipairs(actors) do
                    local entry = data[a]
                    local row = { colors = {} }
                    for k, v in pairs(entry.colors) do row.colors[k] = v end
                    if entry.has_vsf then
                        row.vsf = {}
                        for _, tag in ipairs(vsfTags) do
                            local vc = entry.vsf_corners[tag]
                            if vc then row.vsf[tag] = { vc[1], vc[2], vc[3], vc[4] } end
                        end
                    end
                    importOverlay[a] = row
                end
            end
            viewMode = "guide"
            return "retry", chosenProfileId
        end

        if btn == "Exportar" then
            local profile = AccessibilityProfiles.get(chosenProfileId)
            local exportData = PaletteEngine.remapActors(data, actors, profile)
            local msg = AccessibilityExportFile.export(exportData, actors, profile)
            if msg then showMsg(msg) end
            if msg and not tostring(msg):match("^Error") then return "done", 0 end
            viewMode = "guide"
            return "retry", chosenProfileId
        end

        local profile = AccessibilityProfiles.get(chosenProfileId)
        if profile.policy and profile.policy.audit_only then

            viewMode = "audit"
            return "retry", chosenProfileId
        end
        viewMode = "guide"
        if chosenApplyMode == "Styles" then
            for _, a in ipairs(actors) do
                if data[a].has_vsf then
                    showMsg("El actor '" .. actorLabel(a) .. "' usa colores VSF. Para este caso, aplica como Etiquetas.")
                    return "retry", chosenProfileId
                end
            end
        end

        data = PaletteEngine.remapActors(data, actors, profile)
        local options = {
            apply_mode       = chosenApplyMode,
            preserve_alpha   = res.preserve_alpha and true or false,
            add_bord_shad    = res.add_bord_shad and true or false,
            include_drawings = res.include_drawings and true or false,
        }
        local count, skipped, applyErr, selected = AccessibilityApply.execute(subs, data, actors, styleMap, profile, options)
        if applyErr then
            showMsg(applyErr)
            return "retry", chosenProfileId
        end
        aegisub.set_undo_point("Zheus Daltonismo " .. AccessibilityProfiles.label(profile.id))
        if not silent then
            local msg = count .. " líneas actualizadas (" .. AccessibilityProfiles.label(profile.id) .. ")."
            if skipped and skipped > 0 then msg = msg .. "\n" .. skipped .. " línea(s) de dibujo gestionadas por la opción Incluir dibujos." end
            showMsg(msg)
        end
        return "done", count, skipped, AccessibilityProfiles.label(profile.id), selected
    end

    local current = profileId or cfg.active_profile or "DALTONICO"
    while true do
        local action, p1, p2, p3, selected = runCycle(current)
        if action == "retry" then current = p1
        else return action, p1, p2, p3, selected end
    end
end

openCalibrationWizard = function()
    local custom, ok, err = CalibrationWizard.run()
    if not custom then return end
    local lines = {
        "Personalizado activado:",
        string.format("  protan: %.2f", custom.simulate.protan),
        string.format("  deutan: %.2f", custom.simulate.deutan),
        string.format("  tritan: %.2f", custom.simulate.tritan),
        string.format("  mono:   %.2f", custom.simulate.mono),
        "",
        ok and ("Guardado como perfil activo en:\n  " .. accessibilityConfigPath())
            or ("Error al guardar: " .. tostring(err)),
        "",
        "Comprueba la escena con el perfil activo.",
    }
    showMsg(table.concat(lines, "\n"))
end

openAccessibilityExport = function(subs, sel)
    if not sel or #sel == 0 then showMsg("Selecciona líneas para exportar."); return end
    local cfg = AccessibilityConfig.load()
    local _, data, actors = AccessibilityAudit.run(subs, sel, cfg.active_profile)
    if #actors == 0 then showMsg("La selección está vacía de actores."); return end

    local profileChoices = AccessibilityProfiles.choices()
    local profileChoice = AccessibilityProfiles.choiceFromId(cfg.active_profile)
    local btn, res = aegisub.dialog.display({
        { class = "label",    label = "Exportar paleta accesible v3", x = 0, y = 0, width = 4 },
        { class = "label",    label = "Perfil:",                 x = 0, y = 1, width = 1 },
        { class = "dropdown", name = "profile", items = profileChoices, value = profileChoice, x = 1, y = 1, width = 3 },
        { class = "label",    label = "Actores en selección: " .. #actors, x = 0, y = 2, width = 4 },
    }, { "Exportar", "Cancelar" })
    if btn ~= "Exportar" then return end

    local profile = AccessibilityProfiles.get(AccessibilityProfiles.idFromChoice(res.profile))
    data = PaletteEngine.remapActors(data, actors, profile)
    local msg = AccessibilityExportFile.export(data, actors, profile)
    if msg then showMsg(msg) end
end

local function macroApply(profileId)
    return function(subs, sel) return openAccessibilityApply(subs, sel, profileId) end
end

local macroEntries = {
    { menuPath,                                   script_description,                    mainController },
}

local hotkeyMacroEntries = {
    { "Editor de tramos", "Editar colores por tramos conservando texto y tags", ColorUtil.segments.run },
    { "Colores",            "Atajo: abrir gestor de color por actor",       openChromaManagerDirect },
    { "VSF",                "Atajo: abrir gestor de 4 esquinas por actor",  openVSFManagerDirect },
    { "Actores",            "Atajo: renombrar o fusionar actores",          ejecutarGestorDeActores },
    { "Cambiar colores",    "Atajo: buscar y cambiar colores",              runColorReplaceDirect },
    { "ColorRelay",         "Atajo: cambios de color persistentes por \\t",  ColorRelay.run },
    { "Daltonismo",                  "Atajo: abrir panel de Daltonismo",            openAccessibilityApply },
    { "Daltonismo/Auditar",          "Atajo: auditar accesibilidad de color",        openAccessibilityAudit },
    { "Daltonismo/Aplicar Daltonismo", "Atajo: aplicar perfil Daltonismo",           macroApply("DALTONICO") },
    { "Daltonismo/Universal",        "Atajo: aplicar perfil Universal accesible",    macroApply("UNIVERSAL_SAFE") },
    { "Daltonismo/Protanopia",       "Atajo: aplicar perfil Protanopia",             macroApply("PROTAN_SAFE") },
    { "Daltonismo/Deuteranopia",     "Atajo: aplicar perfil Deuteranopia",           macroApply("DEUTAN_SAFE") },
    { "Daltonismo/Tritanopia",       "Atajo: aplicar perfil Tritanopia",             macroApply("TRITAN_SAFE") },
    { "Daltonismo/Monocromo",        "Atajo: aplicar perfil Monocromo",              macroApply("MONOCHROME") },
    { "Daltonismo/Alto contraste",   "Atajo: aplicar perfil Alto contraste",         macroApply("HIGH_CONTRAST") },
    { "Daltonismo/Calibrar perfil",  "Atajo: crear perfil Personalizado",            openCalibrationWizard },
    { "Daltonismo/Exportar accesible", "Atajo: exportar paleta accesible v3",        openAccessibilityExport },
}

for _, entry in ipairs(hotkeyMacroEntries) do
    macroEntries[#macroEntries + 1] = {
        hotkeyMenuPath .. "/" .. entry[1],
        entry[2],
        entry[3],
    }
end

for _, entry in ipairs(macroEntries) do
    local callback=entry[3]
    entry[3]=function(subs,selection)
        local result,_,_,_,selected=callback(subs,selection)
        if type(selected)=="table" then return selected end
        if type(result)=="table" then return result end
    end
end

depRec:registerMacros(macroEntries, false)

require("kite.UI").publishActions()
