script_name        = "Zheus Colormanager"
script_description = "Gestor de color por actor, VSF y paletas accesibles"
script_author      = "Kiterow"
script_version     = "4.5.3"
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
        { "kite.PyBridge", version = "1.4.4",
          url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
    },
}
local PyBridge = depRec:requireModules()

local MENU_PATH = "Zheus Colormanager"
local HOTKEY_MENU_ROOT = ": Kite Hotkeys :"
local HOTKEY_MENU_SCRIPT = script_name
local HOTKEY_MENU_PATH = HOTKEY_MENU_ROOT .. "/" .. HOTKEY_MENU_SCRIPT

local COLOR_WHITE = "&HFFFFFF&"
local COLOR_BLACK = "&H000000&"
local ASS_COLOR_MODULO = 0x1000000
local ASS_ALPHA_MODULO = 4294967296
local ASS_SIGNED_COLOR_MIN = -2147483648
local ASS_UNSIGNED_COLOR_MAX = ASS_ALPHA_MODULO - 1
local RGB_CHANNEL_MAX  = 255
local UI_ACTORS_PER_PAGE = 8
local PER_PAGE = UI_ACTORS_PER_PAGE
local WCAG_FAIL = 3.0
local WCAG_AA   = 4.5
local CONTRAST_CRITICAL = 2.5
local FALLBACK_FRAME_RATE = 24000 / 1001
local INTERVAL_SUMMARY_LIMIT = 10
local COLOR_CACHE_LIMIT = 4096
local CONFIG_FILE_LIMIT = 512 * 1024
local PALETTE_FILE_LIMIT = 4 * 1024 * 1024
local CONFIG_HOOK_GRANULARITY = 1000
local CONFIG_INSTRUCTION_LIMIT = 100000
local CONFIG_MAX_DEPTH = 16
local CONFIG_MAX_NODES = 10000
local PALETTE_MAX_NODES = 200000
local ACTOR_PALETTE_FORMAT_VERSION = 3
local TRANSFORM_MIN_ACCEL = 0.000001
local MAX_TIMELINE_FRAME = 2147483647
local MAX_FADE_DURATION_MS = 2147483647
local PROFILE_ID_LIMIT = 64
local PROFILE_LABEL_LIMIT = 96
local PROFILE_TEXT_LIMIT = 512
local EMPTY_ACTOR_LABEL = "[Actor vacío]"

local UI = {
    dashboard_width = 12,
    audit_height = 6,
    report_width = 8,
    report_height = 12,
    help_width = 44,
    help_height = 16,
    actor_label_chars = 12,
    vsf_actor_label_chars = 10,
}

local FALLBACK_STYLE = {
    fontname = "Arial", fontsize = 48,
    bold = false, italic = false, underline = false, strikeout = false,
    scale_x = 100, scale_y = 100,
    spacing = 0, angle = 0,
    borderstyle = 1, outline = 2, shadow = 2, align = 2,
    margin_l = 10, margin_r = 10, margin_t = 10, margin_b = 10,
    encoding = 1,
}

local PALETTE_SCALE_FACTORS = { 1.15, 1.35, 1.55, 0.85, 0.70, 0.55 }
local PALETTE_SCORE_WEIGHTS = {
    contrast = 100,
    collision = 80,
    mono = 60,
    hue_drift = 20,
    luma_drift = 20,
}

local function finiteNumber(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

local function trim(s)
    s = tostring(s or "")
    return (s:match("^%s*(.-)%s*$")) or ""
end

local function actorLabel(actor)
    actor = tostring(actor or "")
    return actor == "" and EMPTY_ACTOR_LABEL or actor
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

local ColorUtil = {}

function ColorUtil.normalizeStrict(c)
    if c == nil or c == "" then return nil end
    if type(c) == "number" then
        if not finiteNumber(c) then return nil end
        if c ~= math.floor(c) then return nil end
        if c < ASS_SIGNED_COLOR_MIN or c > ASS_UNSIGNED_COLOR_MAX then return nil end
        if c < 0 then c = c + ASS_ALPHA_MODULO end
        return string.format("&H%06X&", c % ASS_COLOR_MODULO)
    end
    c = trim(c)
    local hex = c:match("^&[Hh](%x+)&?$")
    if hex and (#hex == 6 or #hex == 8) then
        if #hex == 8 then hex = hex:sub(-6) end
        return "&H" .. hex:upper() .. "&"
    end
    local r, g, b = c:match("^#?(%x%x)(%x%x)(%x%x)$")
    if not r then r, g, b = c:match("^#(%x%x)(%x%x)(%x%x)%x%x$") end
    if r then
        return string.format("&H%s%s%s&", b:upper(), g:upper(), r:upper())
    end
    return nil
end

function ColorUtil.normalize(c)
    local n = ColorUtil.normalizeStrict(c)
    if n then return n end
    return COLOR_WHITE
end

function ColorUtil.fromStyle(n)
    if type(n) == "string" then return ColorUtil.normalize(n) end
    if type(n) ~= "number" or not finiteNumber(n) then return COLOR_WHITE end
    n = math.floor(n)
    if n < ASS_SIGNED_COLOR_MIN or n > ASS_UNSIGNED_COLOR_MAX then return COLOR_WHITE end
    if n < 0 then n = n + ASS_ALPHA_MODULO end
    return string.format("&H%06X&", n % ASS_COLOR_MODULO)
end

function ColorUtil.toNumber(c)
    local hex = ColorUtil.normalize(c):match("&H(%x+)&")
    if not hex then return 0xFFFFFF end
    return tonumber(hex, 16) or 0xFFFFFF
end

function ColorUtil.toHex(c)
    local n = ColorUtil.toNumber(c)
    local b = math.floor(n / 0x10000) % (RGB_CHANNEL_MAX + 1)
    local g = math.floor(n / 0x100) % (RGB_CHANNEL_MAX + 1)
    local r = n % (RGB_CHANNEL_MAX + 1)
    return string.format("#%02X%02X%02X", r, g, b)
end

function ColorUtil.luminance(c)
    local n = ColorUtil.toNumber(c)
    local b = (math.floor(n / 0x10000) % (RGB_CHANNEL_MAX + 1)) / RGB_CHANNEL_MAX
    local g = (math.floor(n / 0x100) % (RGB_CHANNEL_MAX + 1)) / RGB_CHANNEL_MAX
    local r = (n % (RGB_CHANNEL_MAX + 1)) / RGB_CHANNEL_MAX
    local function f(v) return v <= 0.04045 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)
end

function ColorUtil.contrastRatio(c1, c2)
    local l1 = ColorUtil.luminance(c1) + 0.05
    local l2 = ColorUtil.luminance(c2) + 0.05
    return (l1 > l2) and l1 / l2 or l2 / l1
end

function ColorUtil.toRGB(c)
    local n = ColorUtil.toNumber(c)
    local b = math.floor(n / 0x10000) % (RGB_CHANNEL_MAX + 1)
    local g = math.floor(n / 0x100) % (RGB_CHANNEL_MAX + 1)
    local r = n % (RGB_CHANNEL_MAX + 1)
    return r, g, b
end

function ColorUtil.fromRGB(r, g, b)
    local function clamp(v)
        v = tonumber(v) or 0
        if v ~= v then v = 0 end
        v = math.floor(v + 0.5)
        if v < 0 then return 0 end
        if v > RGB_CHANNEL_MAX then return RGB_CHANNEL_MAX end
        return v
    end
    return string.format("&H%02X%02X%02X&", clamp(b), clamp(g), clamp(r))
end

function ColorUtil.interpolate(c1, c2, factor)
    factor = finiteNumber(factor) or 0
    if factor <= 0 then return ColorUtil.normalize(c1) end
    if factor >= 1 then return ColorUtil.normalize(c2) end
    local r1, g1, b1 = ColorUtil.toRGB(c1)
    local r2, g2, b2 = ColorUtil.toRGB(c2)
    return ColorUtil.fromRGB(
        r1 + (r2 - r1) * factor,
        g1 + (g2 - g1) * factor,
        b1 + (b2 - b1) * factor)
end

local PAT_COLOR_ANY  = "\\[1-4]?c&[Hh]%x+&?"
local PAT_VC_ANY     = "\\[1-4]?vc%b()"
local PAT_COLOR_CAP  = "\\([1-4]?)c(&[Hh]%x+&?)"
local PAT_VC_CAP     = "\\([1-4]?)vc(%b())"
local PAT_HEX_TOKEN  = "&[Hh]%x+&?"

local SLOT_KEYS = { "1", "2", "3", "4" }
local SLOT_LABELS = { ["1"] = "\\c", ["2"] = "\\2c", ["3"] = "\\3c", ["4"] = "\\4c" }
local VSF_TAGS   = { "1vc", "2vc", "3vc", "4vc" }
local QUICK_VSF_TAGS = VSF_TAGS
local COLOR_KEYS = { ["1"] = "c", ["2"] = "2c", ["3"] = "3c", ["4"] = "4c" }

local function defaultSlotFilter()
    return { ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true }
end

local function slotFilterFromConfig(cfg, prefix)
    cfg = cfg or {}
    prefix = prefix or "replace_slot_"
    local out = {}
    for _, slot in ipairs(SLOT_KEYS) do
        local v = cfg[prefix .. slot]
        out[slot] = (v == nil) and true or v == true
    end
    return out
end

local function writeSlotFilterToTable(t, slots, prefix)
    t = t or {}
    slots = slots or defaultSlotFilter()
    prefix = prefix or "replace_slot_"
    for _, slot in ipairs(SLOT_KEYS) do
        t[prefix .. slot] = slots[slot] == true
    end
    return t
end

local function sameSlotFilter(a, b)
    a = a or {}
    b = b or {}
    for _, slot in ipairs(SLOT_KEYS) do
        if (a[slot] == true) ~= (b[slot] == true) then return false end
    end
    return true
end

local function anySlotSelected(slots)
    slots = slots or {}
    for _, slot in ipairs(SLOT_KEYS) do
        if slots[slot] then return true end
    end
    return false
end

local function slotFilterLabel(slots)
    slots = slots or {}
    local out = {}
    for _, slot in ipairs(SLOT_KEYS) do
        if slots[slot] then table.insert(out, SLOT_LABELS[slot]) end
    end
    return #out > 0 and table.concat(out, ", ") or "ninguno"
end

local function tidyTBody(body)
    local n
    repeat
        body, n = body:gsub(",%s*,", ",")
    until n == 0
    body = body:gsub("^%s*,", "")
    body = body:gsub(",%s*$", "")
    return trim(body)
end

local function cleanupTransforms(text)
    return (text:gsub("\\t(%b())", function(parens)
        local inner = tidyTBody(parens:sub(2, -2))
        if not inner:find("\\") then return "" end
        return "\\t(" .. inner .. ")"
    end))
end

local function withoutTransforms(text)
    return (tostring(text or ""):gsub("\\t%s*%b()", ""))
end

local function hasTopLevelStyleReset(text)
    for block in tostring(text or ""):gmatch("{([^}]*)}") do
        if block:match("^%s*\\") and withoutTransforms(block):find("\\r", 1, true) then
            return true
        end
    end
    return false
end

local function firstSelectedStyleReset(subs, sel)
    for _, index in ipairs(sel or {}) do
        local line = subs[index]
        if isDialogueLine(line) and hasTopLevelStyleReset(line.text) then return index end
    end
    return nil
end

local function stripColorsFromBody(body)
    body = body:gsub(PAT_VC_ANY, "")
    body = body:gsub(PAT_COLOR_ANY, "")
    return cleanupTransforms(body)
end

local TagStripper = {}

function TagStripper.clearColors(text)
    if not text then return "" end
    text = tostring(text)
    text = text:gsub("{([^}]*)}", function(block)
        block = trim(stripColorsFromBody(block))
        return block == "" and "" or "{" .. block .. "}"
    end)
    return text
end

local function injectFirstTags(text, payload)
    text = tostring(text or "")
    if not payload or payload == "" then return text end
    local head = text:match("^({[^}]*})")
    if head then
        return "{" .. payload .. head:sub(2, -2) .. "}" .. text:sub(#head + 1)
    end
    return "{" .. payload .. "}" .. text
end


local function stripSolidSlotsFromFirstBlock(text)
    text = tostring(text or "")
    local head = text:match("^({[^}]*})")
    if not head then return text end
    local body = head:sub(2, -2)
    body = body:gsub("\\1?c&[Hh]%x+&?", "")
    body = body:gsub("\\3c&[Hh]%x+&?", "")
    body = body:gsub("\\4c&[Hh]%x+&?", "")
    body = body:gsub("\\1?vc%b()", "")
    body = body:gsub("\\3vc%b()", "")
    body = body:gsub("\\4vc%b()", "")
    body = cleanupTransforms(body)
    if body:match("^%s*$") then
        return text:sub(#head + 1)
    end
    return "{" .. body .. "}" .. text:sub(#head + 1)
end

local function stripSpecificColor(text, n)
    local vcPat = (n == "1") and "\\1?vc%b()"      or ("\\" .. n .. "vc%b()")
    local cPat  = (n == "1") and "\\1?c&[Hh]%x+&?" or ("\\" .. n .. "c&[Hh]%x+&?")
    text = text:gsub(vcPat, "")
    text = text:gsub(cPat, "")
    text = cleanupTransforms(text)
    text = text:gsub("{%s*}", "")
    return text
end

function TagStripper.dedupeColors(text)
    text = tostring(text or "")
    return (text:gsub("{([^}]*)}", function(block)

        local placeholders, pi = {}, 0
        local protected = block:gsub("\\t%b()", function(match)
            pi = pi + 1
            placeholders[pi] = match
            return "\1T" .. pi .. "\1"
        end)

        local lastC, lastV = {}, {}
        for n, raw in protected:gmatch("\\([1-4]?)c(&[Hh]%x+&?)") do
            if n == "" then n = "1" end
            lastC[n] = raw
        end
        for n, parens in protected:gmatch("\\([1-4]?)vc(%b())") do
            if n == "" then n = "1" end
            lastV[n] = parens
        end

        if next(lastC) == nil and next(lastV) == nil then
            return "{" .. block .. "}"
        end

        protected = protected:gsub("\\[1-4]?vc%b()", "")
        protected = protected:gsub("\\[1-4]?c&[Hh]%x+&?", "")

        protected = protected:gsub("\1T(%d+)\1", function(idx)
            return placeholders[tonumber(idx)] or ""
        end)

        local prefix = ""
        for _, n in ipairs({ "1", "2", "3", "4" }) do
            if lastC[n] then
                local p = (n == "1") and "\\c" or ("\\" .. n .. "c")
                prefix = prefix .. p .. lastC[n]
            end
        end
        for _, n in ipairs({ "1", "2", "3", "4" }) do
            if lastV[n] then
                prefix = prefix .. "\\" .. n .. "vc" .. lastV[n]
            end
        end

        local final = trim(prefix .. trim(protected))
        if final == "" then return "" end
        return "{" .. final .. "}"
    end))
end

function TagStripper.harmonizeColors(text, newFill, newOutline, newShadow)
    text = tostring(text or "")
    local nF = ColorUtil.normalize(newFill)
    local nO = ColorUtil.normalize(newOutline)
    local nS = ColorUtil.normalize(newShadow)
    local hasC, has3, has4 = false, false, false
    text = text:gsub("(\\)([1-4]?)c(&[Hh]%x+&?)", function(slash, n, raw)
        if n == "" then n = "1" end
        if n == "1" then hasC = true; return slash .. "c" .. nF end
        if n == "3" then has3 = true; return slash .. "3c" .. nO end
        if n == "4" then has4 = true; return slash .. "4c" .. nS end
        return slash .. n .. "c" .. raw
    end)
    local missing = ""
    if not hasC then missing = missing .. "\\c" .. nF end
    if not has3 then missing = missing .. "\\3c" .. nO end
    if not has4 then missing = missing .. "\\4c" .. nS end
    if missing ~= "" then
        text = injectFirstTags(text, missing)
    end
    return text
end

local ColorRelay = { name = "ColorRelay", menu_name = "ColorRelay" }

function ColorRelay.showMessage(title, msg)
    aegisub.dialog.display({
        { class = "label", label = tostring(title or ColorRelay.name), x = 0, y = 0, width = 60 },
        { class = "textbox", name = "msg", text = tostring(msg or ""), x = 0, y = 1, width = 60, height = 10 },
    }, { "Aceptar" })
end

function ColorRelay.normalizeColor(c, fallback)
    return ColorUtil.normalizeStrict(c) or fallback or COLOR_WHITE
end

function ColorRelay.styleState(style)
    return {
        ColorRelay.normalizeColor(style and style.color1, COLOR_WHITE),
        ColorRelay.normalizeColor(style and style.color2, COLOR_BLACK),
        ColorRelay.normalizeColor(style and style.color3, COLOR_BLACK),
        ColorRelay.normalizeColor(style and style.color4, COLOR_BLACK),
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
                ColorRelay.normalizeColor(state[slot], slot == 1 and COLOR_WHITE or COLOR_BLACK)
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
    if not slots then return text end
    text = tostring(text or "")
    text = text:gsub("{([^}]*)}", function(block)
        local cleaned = block:gsub("(\\)([1-4]?)c(&[Hh]%x+&?)", function(slash, rawSlot, color)
            local slot = tonumber(rawSlot)
            if rawSlot == "" then slot = 1 end
            if slots[slot] then return "" end
            return slash .. rawSlot .. "c" .. color
        end)
        cleaned = cleanupTransforms(cleaned)
        cleaned = trim(cleaned)
        if cleaned == "" then return "" end
        return "{" .. cleaned .. "}"
    end)
    return ColorRelay.cleanEmptyBlocks(text)
end

function ColorRelay.applyColorTagsToState(state, text)
    for rawSlot, rawColor in tostring(text or ""):gmatch("\\([1-4]?)c(&[Hh]%x+&?)") do
        local slot = tonumber(rawSlot)
        if rawSlot == "" then slot = 1 end
        if slot and slot >= 1 and slot <= 4 then
            state[slot] = ColorRelay.normalizeColor(rawColor, state[slot])
        end
    end
end

function ColorRelay.parseTransform(inner, lineDur)
    local num = "([%+%-]?%d*%.?%d+)"
    inner = trim(inner)
    lineDur = math.max(0, finiteNumber(lineDur) or 0)
    local t1, t2, accel, tags = inner:match("^" .. num .. "%s*,%s*" .. num .. "%s*,%s*" .. num .. "%s*,%s*(.+)$")
    if t1 then
        return finiteNumber(t1) or 0, finiteNumber(t2) or lineDur,
            math.max(finiteNumber(accel) or 1, TRANSFORM_MIN_ACCEL), tags or ""
    end
    t1, t2, tags = inner:match("^" .. num .. "%s*,%s*" .. num .. "%s*,%s*(.+)$")
    if t1 then
        return finiteNumber(t1) or 0, finiteNumber(t2) or lineDur, 1, tags or ""
    end
    accel, tags = inner:match("^" .. num .. "%s*,%s*(.+)$")
    if accel and tags and tags:find("\\", 1, true) then
        return 0, lineDur, math.max(finiteNumber(accel) or 1, TRANSFORM_MIN_ACCEL), tags
    end
    return 0, lineDur, 1, inner
end

function ColorRelay.applyTransformAt(state, tags, offset, t1, t2, accel)
    if offset < t1 then return end
    local target = ColorRelay.copyState(state)
    ColorRelay.applyColorTagsToState(target, tags)
    if t2 <= t1 or offset >= t2 then
        for slot = 1, 4 do state[slot] = target[slot] end
        return
    end
    local factor = math.max(0, math.min(1, (offset - t1) / (t2 - t1)))
    factor = factor ^ math.max(finiteNumber(accel) or 1, TRANSFORM_MIN_ACCEL)
    for slot = 1, 4 do
        state[slot] = ColorUtil.interpolate(state[slot], target[slot], factor)
    end
end

function ColorRelay.originalStateAt(line, style, absMs)
    local state = ColorRelay.styleState(style)
    local text = tostring(line.text or "")
    local lineDur = math.max(0, (line.end_time or 0) - (line.start_time or 0))
    local offset = math.max(0, math.min(lineDur, (absMs or line.start_time or 0) - (line.start_time or 0)))

    for block in text:gmatch("{([^}]*)}") do
        local transforms = {}
        local base = block:gsub("\\t(%b())", function(paren)
            transforms[#transforms + 1] = paren:sub(2, -2)
            return ""
        end)
        ColorRelay.applyColorTagsToState(state, base)
        for _, inner in ipairs(transforms) do
            local t1, t2, accel, tags = ColorRelay.parseTransform(inner, lineDur)
            t1 = math.max(0, math.min(lineDur, t1))
            t2 = math.max(0, math.min(lineDur, t2))
            if t2 < t1 then t1, t2 = t2, t1 end
            ColorRelay.applyTransformAt(state, tags, offset, t1, t2, accel)
        end
    end

    return state
end

function ColorRelay.applyReplacementsToState(state, replacements, slots)
    local changed = {}
    local any = false
    for slot = 1, 4 do
        if (not slots) or slots[slot] then
            local old = ColorRelay.normalizeColor(state[slot], slot == 1 and COLOR_WHITE or COLOR_BLACK)
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
    if frame and frame >= 0 and frame <= MAX_TIMELINE_FRAME then return math.floor(frame) end
    return nil
end

function ColorRelay.msFromFrame(frame)
    if not aegisub or type(aegisub.ms_from_frame) ~= "function" then return nil end
    frame = finiteNumber(frame)
    if not frame or frame < 0 or frame > MAX_TIMELINE_FRAME then return nil end
    frame = math.floor(frame)
    local ok, ms = pcall(aegisub.ms_from_frame, frame)
    ms = ok and finiteNumber(ms) or nil
    if ms then return ms end
    return nil
end

function ColorRelay.frameDurationMs(frame)
    frame = finiteNumber(frame)
    if not frame then return 1000 / FALLBACK_FRAME_RATE end
    frame = math.floor(frame)
    local a = ColorRelay.msFromFrame(frame)
    local b = ColorRelay.msFromFrame(frame + 1)
    if a and b and b > a then return b - a end
    return 1000 / FALLBACK_FRAME_RATE
end

function ColorRelay.currentVideoFrame()
    if not aegisub or type(aegisub.project_properties) ~= "function" then return nil end
    local ok, props = pcall(aegisub.project_properties)
    if not ok or not props then return nil end
    if props.video_position == nil then return nil end
    local frame = finiteNumber(props.video_position)
    if not frame or frame < 0 or frame > MAX_TIMELINE_FRAME then return nil end
    return math.floor(frame)
end

function ColorRelay.collectDialogueSelection(subs, sel)
    local out = {}
    for _, idx in ipairs(sel or {}) do
        local line = subs[idx]
        if isDialogueLine(line) and (line.end_time or 0) > (line.start_time or 0) then
            out[#out + 1] = { index = idx, line = line }
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
        if i > INTERVAL_SUMMARY_LIMIT then
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
    if frame and frame >= 0 and frame <= MAX_TIMELINE_FRAME then return math.floor(frame) end
    return nil
end

function ColorRelay.parseFadeToMs(raw, frame)
    raw = trim(raw or "")
    if raw == "" then return 0, "0" end
    local frames = raw:match("^(%d+)[Ff]$")
    if frames then
        frames = finiteNumber(frames)
        if not frames or frames ~= math.floor(frames) or frames > MAX_TIMELINE_FRAME then return nil, nil end
        local a = ColorRelay.msFromFrame(frame)
        local b = ColorRelay.msFromFrame(frame + frames)
        local duration = a and b and (b - a) or (frames * ColorRelay.frameDurationMs(frame))
        duration = finiteNumber(duration)
        if not duration or duration < 0 or duration > MAX_FADE_DURATION_MS then return nil, nil end
        return math.floor(duration + 0.5), tostring(frames) .. "f"
    end
    local ms = raw:match("^(%d+)%s*[Mm][Ss]$")
    if ms then
        ms = finiteNumber(ms)
        if not ms or ms > MAX_FADE_DURATION_MS then return nil, nil end
        return ms, tostring(ms)
    end
    local numeric = finiteNumber(raw)
    if numeric and numeric >= 0 and numeric <= MAX_FADE_DURATION_MS then return numeric, tostring(numeric) end
    return nil, nil
end

function ColorRelay.parseControlFrames(text, defaultFadeRaw, intervals)
    local events, seen, errors = {}, {}, {}
    defaultFadeRaw = trim(defaultFadeRaw or "0")

    local function addEvent(frame, fadeRaw, source)
        if not frame then return end
        if not ColorRelay.frameInIntervals(frame, intervals) then
            errors[#errors + 1] = "Fotograma fuera de la selección: " .. tostring(frame) .. " (" .. tostring(source or "") .. ")"
            return
        end
        if seen[frame] then return end
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
        local btn, res = aegisub.dialog.display({
            { class = "label", label = "ColorRelay - fotogramas de control", x = 0, y = 0, width = 50 },
            { class = "label", label = "Línea temporal seleccionada: " .. ColorRelay.intervalsSummary(intervals), x = 0, y = 1, width = 50 },
            { class = "label", label = "Lista: 120f, 130f o 120f fundido 6f. También acepta líneas tipo cadena: 120f > P1 fundido 6f.", x = 0, y = 2, width = 50 },
            { class = "textbox", name = "frames", text = frameValue, x = 0, y = 3, width = 50, height = 8 },
            { class = "label", label = "Fundido por defecto (ms o Nf):", x = 0, y = 11, width = 20 },
            { class = "edit", name = "fade", text = fadeValue, x = 20, y = 11, width = 8 },
            { class = "label", label = "Colores a cambiar:", x = 0, y = 13, width = 14 },
            { class = "checkbox", name = "slot1", label = "Relleno \\c", value = slotFilter[1], x = 14, y = 13, width = 9 },
            { class = "checkbox", name = "slot2", label = "2c", value = slotFilter[2], x = 23, y = 13, width = 5 },
            { class = "checkbox", name = "slot3", label = "Borde \\3c", value = slotFilter[3], x = 28, y = 13, width = 9 },
            { class = "checkbox", name = "slot4", label = "Sombra \\4c", value = slotFilter[4], x = 37, y = 13, width = 10 },
        }, { "Siguiente", "Cancel" })

        if not btn or btn == "Cancel" then return nil end
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
            local state = ColorRelay.originalStateAt(line, styles[line.style], event.time)
            ColorRelay.applyPreviousEventsToState(state, previousEvents, event.time)
            for slot = 1, 4 do
                if (not slots) or slots[slot] then
                    local color = ColorRelay.normalizeColor(state[slot], slot == 1 and COLOR_WHITE or COLOR_BLACK)
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

function ColorRelay.promptReplacements(event, colors, slotFilter, index, total)
    if #colors == 0 then
        local btn = aegisub.dialog.display({
            { class = "label", label = string.format("ColorRelay - fotograma %sf (%d/%d)", tostring(event.frame), index or 1, total or 1), x = 0, y = 0, width = 28 },
        { class = "label", label = "Canales activos: " .. ColorRelay.slotFilterLabel(slotFilter), x = 0, y = 1, width = 28 },
            { class = "label", label = "No hay colores activos para esos canales en este fotograma.", x = 0, y = 2, width = 28 },
        }, { "Volver", "Omitir", "Cancel" })
        if not btn or btn == "Cancel" then return "cancel" end
        if btn == "Volver" then return "back" end
        return "skip"
    end
    local ui = {
        { class = "label", label = string.format("ColorRelay - fotograma %sf (%d/%d)", tostring(event.frame), index or 1, total or 1), x = 0, y = 0, width = 10 },
        { class = "label", label = "Fundido (ms o Nf):", x = 10, y = 0, width = 8 },
        { class = "edit", name = "fade", text = event.fade_label or "0", x = 18, y = 0, width = 6 },
        { class = "label", label = "Canales activos: " .. ColorRelay.slotFilterLabel(slotFilter), x = 0, y = 1, width = 24 },
        { class = "label", label = "Actual", x = 0, y = 2, width = 4 },
        { class = "label", label = "Nuevo", x = 5, y = 2, width = 4 },
    }
    for i, color in ipairs(colors) do
        local y = i + 2
        local current = event.replacements and event.replacements[color] or color
        ui[#ui + 1] = { class = "label", label = ColorUtil.toHex(color), x = 0, y = y, width = 4 }
        ui[#ui + 1] = { class = "label", label = ">", x = 4, y = y, width = 1 }
        ui[#ui + 1] = { class = "color", name = "new" .. i, value = ColorUtil.toHex(current), x = 5, y = y, width = 4 }
    end

    local btn, res = aegisub.dialog.display(ui, { "Execute", "Volver", "Omitir", "Cancel" })
    if not btn or btn == "Cancel" then return "cancel" end
    if btn == "Volver" then return "back" end
    if btn == "Omitir" then return "skip" end
    res = res or {}

    local fadeMs, fadeLabel = ColorRelay.parseFadeToMs(res.fade or event.fade_label or "0", event.frame)
    if not fadeMs then
        ColorRelay.showMessage(ColorRelay.name, "Fundido inválido: " .. tostring(res.fade))
        return "retry"
    end
    event.fade_ms = fadeMs
    event.fade_label = fadeLabel

    local replacements, any = {}, false
    for i, oldColor in ipairs(colors) do
        local newColor = ColorUtil.normalizeStrict(res["new" .. i])
        if not newColor then
            ColorRelay.showMessage(ColorRelay.name, "Color inválido: " .. tostring(res["new" .. i]))
            return "retry"
        end
        if newColor ~= oldColor then
            replacements[oldColor] = newColor
            any = true
        end
    end
    event.replacements = replacements
    if not any then return "skip" end
    return "ok"
end

function ColorRelay.eventWindow(event)
    local fade = math.max(0, tonumber(event.fade_ms) or 0)
    if fade <= 0 then return event.time, event.time + 1 end
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
    for parens in tostring(text or ""):gmatch("\\t%s*(%b())") do
        for rawSlot in parens:gmatch("\\([1-4]?)c%s*&[Hh]%x+&?") do
            local slot = rawSlot == "" and 1 or tonumber(rawSlot)
            if slot and slots[slot] then return true, slot end
        end
    end
    return false, nil
end

function ColorRelay.hasLateColorRun(text, slots)
    text = tostring(text or "")
    local cursor, visibleStarted = 1, false
    while cursor <= #text do
        local open = text:find("{", cursor, true)
        local segmentEnd = open and (open - 1) or #text
        local segment = text:sub(cursor, segmentEnd)
        if segment:gsub("\\[Nnh]", ""):match("%S") then visibleStarted = true end
        if not open then break end
        local close = text:find("}", open + 1, true)
        if not close then return true end
        local block = text:sub(open + 1, close - 1)
        if block:match("^%s*\\") then
            local static = block:gsub("\\t%s*%b()", "")
            if static:find("\\r", 1, true) then return true end
            if visibleStarted then
                for rawSlot in static:gmatch("\\([1-4]?)c%s*&[Hh]%x+&?") do
                    local slot = rawSlot == "" and 1 or tonumber(rawSlot)
                    if slot and slots[slot] then return true end
                end
            end
        end
        cursor = close + 1
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
    for _, idx in ipairs(sel or {}) do
        local line = subs[idx]
        if isDialogueLine(line) then
            if hasTopLevelStyleReset(line.text) then
                return nil, "La línea " .. tostring(idx) .. " usa \\r. ColorRelay no puede resolver todavía colores de estilos reiniciados; divide la línea en runs uniformes."
            end
            local touches, slot = ColorRelay.transformTouchesSlots(line.text, selectedSlots)
            if touches then
                return nil, "La línea " .. tostring(idx) .. " ya anima el canal de color " .. tostring(slot) .. " dentro de \\t. Divídela o fija ese color antes de usar ColorRelay."
            end
            if ColorRelay.hasLateColorRun(line.text, selectedSlots) then
                return nil, "La línea " .. tostring(idx) .. " cambia color después de iniciar el texto. Divide los runs antes de usar ColorRelay para no aplanar sus colores."
            end
        end
    end

    local count = 0
    for _, idx in ipairs(sel or {}) do
        local line = subs[idx]
        if isDialogueLine(line) and (line.end_time or 0) > (line.start_time or 0) then
            local lineStart = line.start_time
            local lineEnd = line.end_time
            local lineDur = lineEnd - lineStart
            local originalStartState = ColorRelay.originalStateAt(line, styles[line.style], lineStart)
            local touchedSlots = {}
            local transforms = {}
            local plans = {}
            local previousEvents = {}

            for _, event in ipairs(effective) do
                local winStart, winEnd = ColorRelay.eventWindow(event)
                local sampledAt = math.max(lineStart, math.min(lineEnd, event.time))
                local before = ColorRelay.originalStateAt(line, styles[line.style], sampledAt)
                ColorRelay.applyPreviousEventsToState(before, previousEvents, event.time)
                local after = ColorRelay.copyState(before)
                local _, changed, anyChanged = ColorRelay.applyReplacementsToState(
                    after, event.replacements, event.slots
                )

                if anyChanged then
                    plans[#plans + 1] = {
                        event = event,
                        winStart = winStart,
                        winEnd = winEnd,
                        before = before,
                        after = after,
                        changed = changed,
                    }
                    if winEnd <= lineStart then
                        for slot = 1, 4 do
                            if changed[slot] then touchedSlots[slot] = true end
                        end
                    elseif winStart < lineEnd and winEnd > lineStart then
                        local relStart = math.max(0, winStart - lineStart)
                        local relEnd = math.min(lineDur, winEnd - lineStart)
                        if relEnd <= relStart then relEnd = math.min(lineDur, relStart + 1) end
                        if relEnd <= relStart then relEnd = relStart + 1 end

                        local payloadSlots = {}
                        for slot = 1, 4 do
                            if changed[slot] then
                                payloadSlots[slot] = true
                                touchedSlots[slot] = true
                            end
                        end
                        local target = ColorRelay.copyState(after)
                        if winEnd > winStart and lineEnd < winEnd then
                            local targetFactor = math.max(0, math.min(1, (lineEnd - winStart) / (winEnd - winStart)))
                            for slot = 1, 4 do
                                if changed[slot] then
                                    target[slot] = ColorUtil.interpolate(before[slot], after[slot], targetFactor)
                                end
                            end
                        end
                        transforms[#transforms + 1] = {
                            t1 = relStart,
                            t2 = relEnd,
                            tags = ColorRelay.tagsFromState(target, payloadSlots),
                        }
                    elseif event.time < lineStart then
                        for slot = 1, 4 do
                            if changed[slot] then touchedSlots[slot] = true end
                        end
                    end
                end
                previousEvents[#previousEvents + 1] = event
            end

            if next(touchedSlots) then
                local base = ColorRelay.copyState(originalStartState)
                for _, plan in ipairs(plans) do
                    if plan.winEnd <= lineStart or plan.winEnd <= plan.winStart then
                        for slot = 1, 4 do
                            if plan.changed[slot] then base[slot] = plan.after[slot] end
                        end
                    elseif plan.winStart < lineStart then
                        local factor = math.max(0, math.min(1,
                            (lineStart - plan.winStart) / (plan.winEnd - plan.winStart)))
                        for slot = 1, 4 do
                            if plan.changed[slot] then
                                base[slot] = ColorUtil.interpolate(plan.before[slot], plan.after[slot], factor)
                            end
                        end
                    end
                end

                local payload = ColorRelay.tagsFromState(base, touchedSlots)
                table.sort(transforms, function(a, b)
                    if a.t1 == b.t1 then return a.t2 < b.t2 end
                    return a.t1 < b.t1
                end)
                for _, tr in ipairs(transforms) do
                    local t1 = math.max(0, math.floor(tr.t1 + 0.5))
                    local t2 = math.max(t1 + 1, math.floor(tr.t2 + 0.5))
                    payload = payload .. string.format("\\t(%d,%d,1,%s)", t1, t2, tr.tags)
                end

                line.text = ColorRelay.stripColorSlots(line.text, touchedSlots)
                line.text = injectFirstTags(line.text, payload)
                line.text = ColorRelay.cleanEmptyBlocks(line.text)
                subs[idx] = line
                count = count + 1
            end
        end
    end

    return count
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

local function copyFallbackStyle(ns)
    for k, v in pairs(FALLBACK_STYLE) do ns[k] = v end
end

local function styleColors(style)
    return {
        c = style and ColorUtil.fromStyle(style.color1) or COLOR_WHITE,
        ["2c"] = style and ColorUtil.fromStyle(style.color2) or COLOR_BLACK,
        ["3c"] = style and ColorUtil.fromStyle(style.color3) or COLOR_BLACK,
        ["4c"] = style and ColorUtil.fromStyle(style.color4) or COLOR_BLACK,
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
    for col in tostring(parens or ""):sub(2, -2):gmatch(PAT_HEX_TOKEN) do
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
    styleMap = styleMap or {}
    local data, actors = {}, {}
    for _, i in ipairs(sel) do
        local l = subs[i]
        if isDialogueLine(l) then
            local actor = trim(l.actor)
            if not data[actor] then
                local s   = styleMap[l.style] or styleMap["Default"]
                local baseColors = styleColors(s)
                data[actor] = {
                    ids        = {},
                    colors     = { c = baseColors.c, ["2c"] = baseColors["2c"], ["3c"] = baseColors["3c"], ["4c"] = baseColors["4c"] },
                    vsf_corners = {
                        ["1vc"] = { baseColors.c, baseColors.c, baseColors.c, baseColors.c },
                        ["2vc"] = { baseColors["2c"], baseColors["2c"], baseColors["2c"], baseColors["2c"] },
                        ["3vc"] = { baseColors["3c"], baseColors["3c"], baseColors["3c"], baseColors["3c"] },
                        ["4vc"] = { baseColors["4c"], baseColors["4c"], baseColors["4c"], baseColors["4c"] },
                    },
                    has_vsf     = false,
                    has_mixed   = false,
                    has_vsf_mixed = false,
                    line_count = 0,
                    conflicts  = {},
                    vsf_conflicts = {},
                    _line_colors = {},
                    _line_vsf = {},
                    _color_counts = { ["1"] = {}, ["2"] = {}, ["3"] = {}, ["4"] = {} },
                    _vsf_counts = { ["1vc"] = {}, ["2vc"] = {}, ["3vc"] = {}, ["4vc"] = {} },
                }
                table.insert(actors, actor)
            end
            local entry = data[actor]
            table.insert(entry.ids, i)
            entry.line_count = entry.line_count + 1
            local text = tostring(l.text or "")
            local staticText = withoutTransforms(text)
            local s = styleMap[l.style] or styleMap["Default"]
            local lineColors = styleColors(s)
            local lineVSF = {}

            for n, raw in staticText:gmatch(PAT_COLOR_CAP) do
                if n == "" then n = "1" end
                local k = COLOR_KEYS[n]
                local v = ColorUtil.normalizeStrict(raw)
                if k and v then lineColors[k] = v end
            end

            for n, parens in staticText:gmatch(PAT_VC_CAP) do
                if n == "" then n = "1" end
                local key = n .. "vc"
                entry.has_vsf = true
                local tuple = parseVSFTuple(parens)
                if tuple and entry.vsf_corners[key] then lineVSF[key] = tuple end
            end

            entry._line_colors[i] = lineColors
            entry._line_vsf[i] = lineVSF
            for _, slot in ipairs(SLOT_KEYS) do
                addCount(entry._color_counts[slot], lineColors[COLOR_KEYS[slot]], i)
            end
            for _, tag in ipairs(VSF_TAGS) do
                if lineVSF[tag] then addCount(entry._vsf_counts[tag], tupleKey(lineVSF[tag]), i) end
            end
        end
    end
    table.sort(actors)
    for _, actor in ipairs(actors) do
        local entry = data[actor]
        for _, slot in ipairs(SLOT_KEYS) do
            local key = COLOR_KEYS[slot]
            local dom = dominantKey(entry._color_counts[slot], entry.colors[key])
            entry.colors[key] = dom
            if countSize(entry._color_counts[slot]) > 1 then
                entry.has_mixed = true
                for _, id in ipairs(entry.ids) do
                    local lineColors = entry._line_colors[id]
                    local value = lineColors and lineColors[key]
                    if value and value ~= dom then
                        table.insert(entry.conflicts, {
                            ln = id,
                            tag = SLOT_LABELS[slot],
                            old = dom,
                            new = value,
                        })
                    end
                end
            end
        end
        for _, tag in ipairs(VSF_TAGS) do
            local domTuple = tupleFromKey(dominantKey(entry._vsf_counts[tag], nil))
            if domTuple then entry.vsf_corners[tag] = domTuple end
            if countSize(entry._vsf_counts[tag]) > 1 then
                entry.has_vsf_mixed = true
                for _, id in ipairs(entry.ids) do
                    local lineVSF = entry._line_vsf[id]
                    local tuple = lineVSF and lineVSF[tag]
                    if tuple and domTuple and tupleKey(tuple) ~= tupleKey(domTuple) then
                        table.insert(entry.vsf_conflicts, {
                            ln = id,
                            tag = "\\" .. tag,
                            old = domTuple,
                            new = tuple,
                        })
                    end
                end
            end
        end
        entry._line_colors = nil
        entry._line_vsf = nil
        entry._color_counts = nil
        entry._vsf_counts = nil
    end
    return data, actors
end

local ActorReport = {}

function ActorReport.summary(actors, data)
    local lines = { "#  RESUMEN DE ACTORES", "" }
    for _, a in ipairs(actors) do
        local info = data[a]
        local ratio = ColorUtil.contrastRatio(info.colors.c, info.colors["3c"])
        local flag = info.has_mixed and "MIXTO " or ""
        if ratio < CONTRAST_CRITICAL then
            flag = flag .. "URGENTE RC:" .. string.format("%.1f", ratio)
        elseif ratio < WCAG_AA then
            flag = flag .. "REVISAR RC:" .. string.format("%.1f", ratio)
        else
            flag = flag .. "BIEN RC:" .. string.format("%.1f", ratio)
        end
        table.insert(lines, string.format("%-15s  c:%s  3c:%s  [%s]",
            actorLabel(a):sub(1, 15), ColorUtil.toHex(info.colors.c), ColorUtil.toHex(info.colors["3c"]), flag))
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
                    c.ln, c.tag, ColorUtil.toHex(c.old or COLOR_WHITE), ColorUtil.toHex(c.new)))
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
        if ratio < CONTRAST_CRITICAL then
            label = "URGENTE"; totalLowCR = totalLowCR + 1
        elseif ratio < WCAG_AA then
            label = "AJUSTAR"; totalLowCR = totalLowCR + 1
        else
            label = "BIEN"
        end
        local dup = ""
        if info.colors.c == info.colors["3c"] then dup = " [c = 3c DUPLICADO]"; totalDup = totalDup + 1 end
        if info.colors.c == info.colors["4c"] then dup = dup .. " [c = 4c]" end
        table.insert(lines, string.format("  %-12s  CR:%.1f %s%s", actorLabel(a):sub(1, 12), ratio, label, dup))
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
        return {
            { class = "label",   label = "Lista de actores", x = 0, y = 0, width = UI.report_width },
            { class = "textbox", name = "tb", text = ActorReport.summary(actors, data), x = 0, y = 1, width = UI.report_width, height = UI.report_height },
            { class = "label",   label = "Formato: Actor  c:#RRGGBB  3c:#RRGGBB  [Estado]", x = 0, y = 13, width = UI.report_width },
        }, 0
    elseif view == "conflicts" then
        return {
            { class = "label",   label = "Reporte de conflictos", x = 0, y = 0, width = UI.report_width },
            { class = "textbox", name = "tb", text = ActorReport.conflicts(actors, data), x = 0, y = 1, width = UI.report_width, height = UI.report_height },
            { class = "label",   label = "Dominante por actor: color más frecuente; empates por primera aparición.", x = 0, y = 13, width = UI.report_width },
        }, 0
    elseif view == "vsf" then
        local activeTag = vsfTag or "1vc"
        local g = {
            { class = "label",    label = "4 esquinas", x = 0, y = 0, width = 6 },
            { class = "label",    label = "Pág " .. page .. "/" .. pages .. "  |  " .. total .. " actores", x = 0, y = 1, width = 4 },
            { class = "dropdown", name = "vctag", items = VSF_TAGS, value = activeTag, x = 4, y = 1, width = 2, hint = "Etiqueta a editar" },
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
            table.insert(g, { class = "label",      label = actorLabel(a):sub(1, UI.vsf_actor_label_chars), x = 0, y = r, hint = actorLabel(a) })
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
        table.insert(g, { class = "label",      label = actorLabel(a):sub(1, UI.actor_label_chars), x = 0, y = r, hint = actorLabel(a) .. " (" .. info.line_count .. " líneas)" })
        table.insert(g, { class = "color", name = "C_" .. k .. "_c",  value = ColorUtil.toHex(info.colors.c),     x = 1, y = r })
        table.insert(g, { class = "color", name = "C_" .. k .. "_3c", value = ColorUtil.toHex(info.colors["3c"]), x = 2, y = r })
        table.insert(g, { class = "color", name = "C_" .. k .. "_4c", value = ColorUtil.toHex(info.colors["4c"]), x = 3, y = r })
        local ratio = ColorUtil.contrastRatio(info.colors.c, info.colors["3c"])
        local status = info.has_mixed and "MIXTO " or ""
        if info.has_vsf then status = status .. "VSF " end
        if info.has_vsf_mixed then status = status .. "VSF-MIXTO " end
        if ratio < CONTRAST_CRITICAL then status = status .. "URGENTE " .. string.format("%.1f", ratio)
        elseif ratio < WCAG_AA then status = status .. string.format("%.1f", ratio)
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
                vc[1] = ColorUtil.normalizeStrict(v1) or vc[1]
                vc[2] = ColorUtil.normalizeStrict(res["V_" .. k .. "_2"]) or vc[2]
                vc[3] = ColorUtil.normalizeStrict(res["V_" .. k .. "_3"]) or vc[3]
                vc[4] = ColorUtil.normalizeStrict(res["V_" .. k .. "_4"]) or vc[4]
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

-- Prefer the style already used exclusively by the actor's target lines. This
-- makes repeated runs idempotent without modifying a style shared elsewhere.
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
            if numeric and numeric == math.floor(numeric) and numeric >= ASS_SIGNED_COLOR_MIN and numeric <= ASS_UNSIGNED_COLOR_MAX then
                if numeric < 0 then numeric = numeric + ASS_ALPHA_MODULO end
                alpha = string.format("%02X", math.floor(numeric / ASS_COLOR_MODULO) % 256)
            end
        else
            local hex = tostring(inherited or ""):match("^&[Hh](%x+)&?$")
            if hex and #hex == 8 then alpha = hex:sub(1, 2):upper() end
        end
    end
    return string.format("&H%s%06X&", alpha, ColorUtil.toNumber(color))
end

local ManagerApply = {}

function ManagerApply.execute(subs, data, actors, styleMap, op, autoClean, vsfMode, vsfTag)
    styleMap = styleMap or {}
    local count = 0

    for _, actor in ipairs(actors or {}) do
        for _, index in ipairs((data[actor] and data[actor].ids) or {}) do
            local line = subs[index]
            if isDialogueLine(line) and hasTopLevelStyleReset(line.text) then
                return nil, "La línea " .. tostring(index) .. " usa \\r. El gestor no modifica líneas con reinicios de estilo hasta poder resolver sus colores por run."
            end
        end
    end

    if op == "Estilos" and vsfMode then
        return nil, "Los colores VSFilterMod requieren el modo Etiquetas."
    end

    if op == "Estilos" then
        local nameMap, newStyles, claimedNames = {}, {}, {}
        local styleIndex, styleUsage = generatedStyleInventory(subs)
        local insertPos, lastNonDialoguePos, foundStyle = 1, 0, false
        for si = 1, #subs do
            local cls = subs[si].class
            if cls == "style" then
                insertPos = si + 1
                foundStyle = true
            elseif cls ~= "dialogue" then
                lastNonDialoguePos = si
            end
        end

        if not foundStyle and lastNonDialoguePos > 0 then
            insertPos = lastNonDialoguePos + 1
        end
        for _, a in ipairs(actors) do
            local sc1 = ColorUtil.normalize(data[a].colors.c)
            local sc2 = ColorUtil.normalize(data[a].colors["2c"])
            local sc3 = ColorUtil.normalize(data[a].colors["3c"])
            local sc4 = ColorUtil.normalize(data[a].colors["4c"])
            local firstId = data[a].ids[1]
            if firstId and isDialogueLine(subs[firstId]) then
                local base    = styleMap[subs[firstId].style]
                local rawName = (actorLabel(a):gsub("[^%w_]", "_")) .. "_Z"
                local name, existingIndex = chooseGeneratedStyleName(
                    rawName, subs, styleIndex, styleUsage,
                    idsAsSet(data[a].ids), claimedNames
                )
                if not name then return nil, "No se pudo reservar un nombre de estilo para '" .. tostring(a) .. "'." end
                claimedNames[name] = true
                local ns = { class = "style", name = name }
                if base then
                    for k, v in pairs(base) do
                        if k ~= "name" and k ~= "class" then ns[k] = v end
                    end
                else
                    copyFallbackStyle(ns)
                end
                ns.color1 = styleColorWithInheritedAlpha(sc1, base and base.color1, true)
                ns.color2 = styleColorWithInheritedAlpha(sc2, base and base.color2, true)
                ns.color3 = styleColorWithInheritedAlpha(sc3, base and base.color3, true)
                ns.color4 = styleColorWithInheritedAlpha(sc4, base and base.color4, true)

                if existingIndex then
                    subs[existingIndex] = ns
                else
                    table.insert(newStyles, ns)
                end
                nameMap[a] = name
            end
        end
        for si = #newStyles, 1, -1 do subs.insert(insertPos, newStyles[si]) end
        local offset = #newStyles
        for _, a in ipairs(actors) do
            local sname = nameMap[a]
            if sname then
                for _, id in ipairs(data[a].ids) do
                    local idx = id >= insertPos and id + offset or id
                    local l = subs[idx]
                    if isDialogueLine(l) then
                        l.style = sname

                        l.text = TagStripper.clearColors(l.text)
                        subs[idx] = l
                        count = count + 1
                    end
                end
            end
        end
        return count
    end

    for _, a in ipairs(actors) do
        local c1 = ColorUtil.normalize(data[a].colors.c)
        local c3 = ColorUtil.normalize(data[a].colors["3c"])
        local c4 = ColorUtil.normalize(data[a].colors["4c"])

        if op == "Etiquetas" or op == "Tags" then
            for _, id in ipairs(data[a].ids) do
                local l = subs[id]
                if isDialogueLine(l) then
                    l.text = tostring(l.text or "")
                    if autoClean then
                        l.text = TagStripper.clearColors(l.text)
                    end

                    local tags
                    if vsfMode and vsfTag then
                        tags = buildVSFTag(vsfTag, data[a].vsf_corners[vsfTag])

                        l.text = stripSpecificColor(l.text, vsfTag:sub(1, 1))
                    else
                        tags = "\\c" .. c1 .. "\\3c" .. c3 .. "\\4c" .. c4
                        if not autoClean then
                            l.text = stripSolidSlotsFromFirstBlock(l.text)
                        end

                        l.text = (l.text:gsub("{([^}]*)}", function(block)
                            block = block:gsub("\\1?vc%b()", "")
                            block = block:gsub("\\3vc%b()", "")
                            block = block:gsub("\\4vc%b()", "")
                            block = cleanupTransforms(block)
                            block = trim(block)
                            if block == "" then return "" end
                            return "{" .. block .. "}"
                        end))
                    end

                    l.text = injectFirstTags(l.text, tags)
                    l.text = TagStripper.dedupeColors(l.text)
                    l.text = l.text:gsub("{%s*}", "")
                    subs[id] = l
                    count = count + 1
                end
            end
        elseif op == "Limpiar" then
            for _, id in ipairs(data[a].ids) do
                local l = subs[id]
                if isDialogueLine(l) then
                    l.text = TagStripper.clearColors(l.text)
                    subs[id] = l
                    count = count + 1
                end
            end
        end
    end
    return count
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
            f:write("# Zheus Colormanager\n")
            f:write("# Exportación de paleta de color por actor\n")
            f:write("# Versión de formato: " .. ACTOR_PALETTE_FORMAT_VERSION .. "\n")
            f:write("# Tipo de contenido: " .. (hasAnyVSF and "VSF" or "NORMAL") .. "\n")
            f:write("# Esquema: Actor-porcentaje-codificado|c,3c,4c[|1vc:c1,c2,c3,c4|...]\n\n")
            for _, a in ipairs(actors) do
                local info = data[a]
                local line = encodePaletteField(a) .. "|" .. info.colors.c .. "," .. info.colors["3c"] .. "," .. info.colors["4c"]
                if info.has_vsf then
                    for _, tag in ipairs(VSF_TAGS) do
                        local vc = info.vsf_corners[tag]
                        if vc then
                            line = line .. "|" .. tag .. ":" .. vc[1] .. "," .. vc[2] .. "," .. vc[3] .. "," .. vc[4]
                        end
                    end
                end
                f:write(line .. "\n")
            end
            return true
        end, "wb")
        if not ok then return "Error al escribir: " .. tostring(err) end
        return "Exportados " .. #actors .. " actores"
    end

    local fn = aegisub.dialog.open("Importar paleta de colores - Zheus Colormanager", "", "", "*.txt", false, true)
    if not fn then return nil end
    local content, readError = PyBridge.readFile(fn, PALETTE_FILE_LIMIT + 1)
    if not content then return "Error al leer: " .. tostring(readError) end
    if #content > PALETTE_FILE_LIMIT then return "La paleta supera el límite de tamaño permitido." end
    local fileVersion = tonumber(content:match("#%s*Versión de formato:%s*(%d+)")) or 2
    if fileVersion < 2 or fileVersion > ACTOR_PALETTE_FORMAT_VERSION then
        return "Versión de paleta no compatible: " .. tostring(fileVersion)
    end
    local imported, missing, invalid, has_vsf_data = 0, {}, {}, false
    local updated = {}
    for l in content:gmatch("[^\r\n]+") do
        if not l:match("^#") and l ~= "" then
            local actorField, remainder = l:match("^(.-)|(.+)$")
            local parts = actorField and { actorField } or {}
            for p in tostring(remainder or ""):gmatch("[^|]+") do table.insert(parts, p) end
            if #parts >= 2 then
                local actor = fileVersion >= 3 and decodePaletteField(parts[1]) or trim(parts[1])
                if not actor then
                    table.insert(invalid, "actor codificado")
                    actor = ""
                end
                if data[actor] then
                    local t = {}
                    for x in parts[2]:gmatch("[^,]+") do table.insert(t, x) end
                    if #t == 3 then
                        local c1 = ColorUtil.normalizeStrict(t[1])
                        local c3 = ColorUtil.normalizeStrict(t[2])
                        local c4 = ColorUtil.normalizeStrict(t[3])
                        if c1 and c3 and c4 then
                            data[actor].colors.c     = c1
                            data[actor].colors["3c"] = c3
                            data[actor].colors["4c"] = c4
                            imported = imported + 1
                            updated[actor] = true
                        else
                            table.insert(invalid, actor .. " sólidos")
                        end
                    end
                    for pi = 3, #parts do
                        local tag, cols = parts[pi]:match("^([1-4]vc):(.+)$")
                        if tag and cols and data[actor].vsf_corners[tag] then
                            local vc = {}
                            local okTuple = true
                            for x in cols:gmatch("[^,]+") do
                                local n = ColorUtil.normalizeStrict(x)
                                if n then table.insert(vc, n) else okTuple = false end
                            end
                            if okTuple and #vc == 4 then
                                data[actor].vsf_corners[tag] = { vc[1], vc[2], vc[3], vc[4] }
                                data[actor].has_vsf = true
                                has_vsf_data = true
                            else
                                table.insert(invalid, actor .. " " .. tag)
                            end
                        end
                    end
                else
                    table.insert(missing, actor)
                end
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
        msg = msg .. "\nEntradas inválidas omitidas: " .. il:sub(1, 80)
        if #il > 80 then msg = msg .. "..." end
    end
    if #missing > 0 then
        local ml = table.concat(missing, ", ")
        msg = msg .. "\nArchivo con actores fuera de selección: " .. ml:sub(1, 60)
        if #ml > 60 then msg = msg .. "..." end
    end
    if #noData > 0 then
        local nl = table.concat(noData, ", ")
        msg = msg .. "\nActores pendientes en archivo: " .. nl:sub(1, 60)
        if #nl > 60 then msg = msg .. "..." end
    end
    return msg, has_vsf_data
end

local VSFCornerEditor = {}

function VSFCornerEditor.applyGradient(subs, sel, cfg)
    local payload = {}
    local activeSlots = {}
    for _, tagName in ipairs(QUICK_VSF_TAGS) do
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
    local count, linesWithSolid = 0, 0

    for _, i in ipairs(sel) do
        local l = subs[i]
        if isDialogueLine(l) then
            l.text = tostring(l.text or "")
            local hadSolidConflict = false

            if cfg.vcl then
                l.text = l.text:gsub(PAT_VC_ANY, "")
                l.text = l.text:gsub("{%s*}", "")
            end

            for _, slot in ipairs(activeSlots) do
                local before = l.text
                l.text = stripSpecificColor(l.text, slot)
                if l.text ~= before then hadSolidConflict = true end
            end

            l.text = injectFirstTags(l.text, tag)
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
end

local ColorReplacer = {}

function ColorReplacer.collect(subs, sel, slots)
    local seen, found = {}, {}
    for _, i in ipairs(sel) do
        local line = subs[i]
        if isDialogueLine(line) then
            local txt = tostring(line.text or "")
            for n, raw in txt:gmatch(PAT_COLOR_CAP) do
                if n == "" then n = "1" end
                local norm = slots[n] and ColorUtil.normalizeStrict(raw) or nil
                if norm and not seen[norm] then seen[norm] = true; table.insert(found, norm) end
            end
            for n, parens in txt:gmatch(PAT_VC_CAP) do
                if n == "" then n = "1" end
                if slots[n] then
                    for col in parens:gmatch(PAT_HEX_TOKEN) do
                        local norm = ColorUtil.normalizeStrict(col)
                        if norm and not seen[norm] then seen[norm] = true; table.insert(found, norm) end
                    end
                end
            end
        end
    end
    table.sort(found)
    return found
end

function ColorReplacer.run(subs, sel, cfg)
    local slots = slotFilterFromConfig(cfg)
    local status = ""
    local pending = {}
    while true do
        local found = anySlotSelected(slots) and ColorReplacer.collect(subs, sel, slots) or {}
        local g = {
            { class = "label", label = "Cambiar colores", x = 0, y = 0, width = 8 },
            { class = "label", label = "Canales activos: " .. slotFilterLabel(slots), x = 0, y = 1, width = 8 },
            { class = "checkbox", name = "replace_slot_1", label = "\\c",  value = slots["1"], x = 0, y = 2, width = 2 },
            { class = "checkbox", name = "replace_slot_2", label = "\\2c", value = slots["2"], x = 2, y = 2, width = 2 },
            { class = "checkbox", name = "replace_slot_3", label = "\\3c", value = slots["3"], x = 4, y = 2, width = 2 },
            { class = "checkbox", name = "replace_slot_4", label = "\\4c", value = slots["4"], x = 6, y = 2, width = 2 },
        }
        local baseY = 3
        if status ~= "" then
            table.insert(g, { class = "label", label = status, x = 0, y = baseY, width = 8 })
            baseY = baseY + 1
        end

        if #found == 0 then
            table.insert(g, { class = "label", label = anySlotSelected(slots) and "Colores detectados: 0" or "Selecciona al menos un canal.", x = 0, y = baseY, width = 8 })
            local btn, res = aegisub.dialog.display(g, { "Actualizar", "Volver", "Cancel" })
            res = res or {}
            local nextSlots = slotFilterFromConfig(res)
            if btn == "Volver" then return 0, nil, "back", writeSlotFilterToTable({}, nextSlots) end
            if btn ~= "Actualizar" then return 0, nil, "cancel", writeSlotFilterToTable({}, nextSlots) end
            slots = nextSlots
            status = "Filtros actualizados."
        else
            table.insert(g, { class = "label", label = "Actual", x = 0, y = baseY, width = 3 })
            table.insert(g, { class = "label", label = "Nuevo",  x = 4, y = baseY, width = 3 })
            for i, v in ipairs(found) do
                local y = baseY + i
                table.insert(g, { class = "label", label = ColorUtil.toHex(v), x = 0, y = y, width = 3 })
                table.insert(g, { class = "label",      label = ">", x = 3, y = y, width = 1 })
                table.insert(g, { class = "color", name = "n" .. i, value = ColorUtil.toHex(pending[v] or v), x = 4, y = y, width = 3 })
            end
            local btn, res = aegisub.dialog.display(g, { "Execute", "Actualizar", "Volver", "Cancel" })
            res = res or {}
            local nextSlots = slotFilterFromConfig(res)
            if btn == "Volver" then return 0, nil, "back", writeSlotFilterToTable({}, nextSlots) end
            if btn == "Cancel" or not btn then return 0, nil, "cancel", writeSlotFilterToTable({}, nextSlots) end
            local parsed, invalid = {}, nil
            for i, v in ipairs(found) do
                local nv = ColorUtil.normalizeStrict(res["n" .. i])
                if not nv then
                    invalid = "Color inválido: " .. tostring(res["n" .. i])
                    break
                end
                parsed[v] = nv
            end
            if invalid then
                status = invalid
            else
                for v, nv in pairs(parsed) do pending[v] = nv end
                if btn == "Actualizar" or not sameSlotFilter(slots, nextSlots) then
                    slots = nextSlots
                    status = "Filtros actualizados; revisa los colores y ejecuta de nuevo."
                else
                    local replacements, anyChange = {}, false
                    for _, v in ipairs(found) do
                        local nv = pending[v] or v
                        if v ~= nv then replacements[v] = nv; anyChange = true end
                    end
                    if not anyChange then
                        status = "No hay cambios de color por aplicar."
                    else
                        local count = 0
                        local function replaceToken(color)
                            local rep = replacements[ColorUtil.normalize(color)]
                            if not rep then return nil end
                            local hex = tostring(color):match("&[Hh](%x+)&?")
                            if hex and #hex > 6 then
                                local alpha = hex:sub(1, #hex - 6):upper()
                                local rgb = rep:match("&H(%x+)&")
                                return "&H" .. alpha .. rgb .. "&"
                            end
                            return rep
                        end
                        for _, i in ipairs(sel) do
                            local l = subs[i]
                            if isDialogueLine(l) then
                                l.text = tostring(l.text or "")
                                local changed = false
                                l.text = l.text:gsub("(\\)([1-4]?)c(&[Hh]%x+&?)", function(slash, rawSlot, color)
                                    local slot = rawSlot == "" and "1" or rawSlot
                                    if not slots[slot] then return slash .. rawSlot .. "c" .. color end
                                    local rep = replaceToken(color)
                                    if rep then changed = true; return slash .. rawSlot .. "c" .. rep end
                                    return slash .. rawSlot .. "c" .. color
                                end)
                                l.text = l.text:gsub("\\([1-4]?)vc(%b())", function(rawSlot, parens)
                                    local slot = rawSlot == "" and "1" or rawSlot
                                    if not slots[slot] then return "\\" .. rawSlot .. "vc" .. parens end
                                    local newParens = parens:gsub(PAT_HEX_TOKEN, function(color)
                                        local rep = replaceToken(color)
                                        if rep then changed = true; return rep end
                                        return color
                                    end)
                                    return "\\" .. rawSlot .. "vc" .. newParens
                                end)
                                if changed then
                                    l.text = TagStripper.dedupeColors(l.text)
                                    subs[i] = l
                                    count = count + 1
                                end
                            end
                        end
                        return count, nil, "applied", writeSlotFilterToTable({}, slots)
                    end
                end
            end
        end
    end
end

local AlphaUtil = {}

function AlphaUtil.expandEmbeddedColorAlpha(text)
    return (tostring(text or ""):gsub("\\([1-4]?)c&[Hh](%x%x)(%x%x%x%x%x%x)&?", function(rawSlot, alpha, rgb)
        local alphaSlot = rawSlot == "" and "1" or rawSlot
        return "\\" .. alphaSlot .. "a&H" .. alpha:upper() .. "&\\" .. rawSlot .. "c&H" .. rgb:upper() .. "&"
    end))
end

local ColorSpace = {}

function ColorSpace.srgb8ToLinear(v)
    v = (tonumber(v) or 0) / RGB_CHANNEL_MAX
    if v <= 0 then return 0 end
    if v >= 1 then return 1 end
    if v <= 0.04045 then return v / 12.92 end
    return ((v + 0.055) / 1.055) ^ 2.4
end

function ColorSpace.linearToSrgb8(v)
    v = tonumber(v) or 0
    if v <= 0 then return 0 end
    if v >= 1 then return RGB_CHANNEL_MAX end
    local s
    if v <= 0.0031308 then s = v * 12.92
    else s = 1.055 * (v ^ (1.0 / 2.4)) - 0.055 end
    s = math.floor(s * RGB_CHANNEL_MAX + 0.5)
    if s < 0 then return 0 end
    if s > RGB_CHANNEL_MAX then return RGB_CHANNEL_MAX end
    return s
end

local function _cbrt(x)
    if x >= 0 then return x ^ (1.0 / 3.0) end
    return -((-x) ^ (1.0 / 3.0))
end

function ColorSpace.rgbToOklab(r, g, b)
    local lr = ColorSpace.srgb8ToLinear(r)
    local lg = ColorSpace.srgb8ToLinear(g)
    local lb = ColorSpace.srgb8ToLinear(b)
    local lp = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
    local mp = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
    local sp = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb
    local lc, mc, sc = _cbrt(lp), _cbrt(mp), _cbrt(sp)
    local L = 0.2104542553 * lc + 0.7936177850 * mc - 0.0040720468 * sc
    local A = 1.9779984951 * lc - 2.4285922050 * mc + 0.4505937099 * sc
    local B = 0.0259040371 * lc + 0.7827717662 * mc - 0.8086757660 * sc
    return L, A, B
end

local _oklabMemo, _oklabMemoN = {}, 0

function ColorSpace.colorToOklab(c)
    local key = tostring(c)
    local hit = _oklabMemo[key]
    if hit then return hit[1], hit[2], hit[3] end
    local r, g, b = ColorUtil.toRGB(c)
    local L, A, B = ColorSpace.rgbToOklab(r, g, b)
    if _oklabMemoN >= COLOR_CACHE_LIMIT then _oklabMemo, _oklabMemoN = {}, 0 end
    _oklabMemo[key] = { L, A, B }
    _oklabMemoN = _oklabMemoN + 1
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

local function _applyMatrix(r, g, b, m, severity)
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

local _cvdMemo, _cvdMemoN = {}, 0

function CVDSim.simulate(color, cvdType, severity)
    if color == nil or color == "" then return COLOR_WHITE end
    severity = finiteNumber(severity)
    if severity == nil then severity = 1.0 end
    if severity < 0 then severity = 0 end
    if severity > 1 then severity = 1 end
    local key = tostring(color) .. "|" .. tostring(cvdType) .. "|" .. string.format("%.4f", severity)
    local hit = _cvdMemo[key]
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
            local r2, g2, b2 = _applyMatrix(r, g, b, m, severity)
            result = ColorUtil.fromRGB(r2, g2, b2)
        end
    end
    if _cvdMemoN >= COLOR_CACHE_LIMIT then _cvdMemo, _cvdMemoN = {}, 0 end
    _cvdMemo[key] = result
    _cvdMemoN = _cvdMemoN + 1
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
            force_fill = COLOR_WHITE, force_outline = COLOR_BLACK, force_shadow = COLOR_BLACK,
            add_bord_shad = true, bord = 3, shad = 1,
        },
    },
}

local BUILTIN_PROFILE_IDS = {
    NORMAL = true, DALTONICO = true, UNIVERSAL_SAFE = true,
    PROTAN_SAFE = true, DEUTAN_SAFE = true, TRITAN_SAFE = true,
    MONOCHROME = true, HIGH_CONTRAST = true,
}

function AccessibilityProfiles.get(id)
    if type(id) == "table" and id.id then return id end
    return AccessibilityProfiles.list[id] or AccessibilityProfiles.list.DALTONICO or AccessibilityProfiles.list.UNIVERSAL_SAFE
end

local function boundedProfileString(value, fallback, limit)
    if value == nil then return fallback end
    if type(value) ~= "string" or #value > limit then return nil end
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
    if type(id) ~= "string" or id == "" or #id > PROFILE_ID_LIMIT or not id:match("^[%w_.%-]+$") then return nil end
    local label = boundedProfileString(p.label, id, PROFILE_LABEL_LIMIT)
    local description = boundedProfileString(p.description, "", PROFILE_TEXT_LIMIT)
    local criteria = boundedProfileString(p.criteria, "", PROFILE_TEXT_LIMIT)
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
    for _, value in pairs(thresholds) do if value == nil then return nil end end

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
            policy[key] = boundedProfileNumber(sourcePolicy[key], nil, 0, 100)
            if policy[key] == nil then return nil end
        end
    end
    if sourcePolicy.use_palette ~= nil then
        policy.use_palette = boundedProfileString(sourcePolicy.use_palette, nil, PROFILE_ID_LIMIT)
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

local _BUILTIN_PROFILE_ORDER = {
    "NORMAL",
    "DALTONICO", "UNIVERSAL_SAFE", "PROTAN_SAFE", "DEUTAN_SAFE",
    "TRITAN_SAFE", "MONOCHROME", "HIGH_CONTRAST",
}

function AccessibilityProfiles.ids()
    local out, seen = {}, {}
    for _, id in ipairs(_BUILTIN_PROFILE_ORDER) do
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

local PROFILE_SIM_LABELS = {
    { "protan", "protanopia" },
    { "deutan", "deuteranopia" },
    { "tritan", "tritanopia" },
    { "mono", "monocromo" },
}

function AccessibilityProfiles.simulationText(profile)
    profile = AccessibilityProfiles.get(profile)
    local simulate = profile.simulate or {}
    local parts = {}
    for _, item in ipairs(PROFILE_SIM_LABELS) do
        local sev = tonumber(simulate[item[1]]) or 0
        if sev > 0 then table.insert(parts, string.format("%s %.0f%%", item[2], sev * 100)) end
    end
    if #parts == 0 then return "auditoría base" end
    return table.concat(parts, ", ")
end

local PALETTE_LABELS = {
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
        local label = PALETTE_LABELS[pol.use_palette] or pol.use_palette
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

local CVD_KINDS = { "protan", "deutan", "tritan", "mono" }

local function _pickWorst(t)
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

    local c  = ColorUtil.normalize(colors.c or COLOR_WHITE)
    local c2 = ColorUtil.normalize(colors["2c"] or COLOR_BLACK)
    local c3 = ColorUtil.normalize(colors["3c"] or COLOR_BLACK)
    local c4 = ColorUtil.normalize(colors["4c"] or COLOR_BLACK)

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
    for _, cvd in ipairs(CVD_KINDS) do
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
    if v < WCAG_FAIL then
        table.insert(result.flags, "LOW_C_3C_CONTRAST"); bump("CRITICAL")
    elseif v < WCAG_AA then
        table.insert(result.flags, "LOW_C_3C_CONTRAST"); bump("FAIL")
    elseif v < minC then
        table.insert(result.flags, "LOW_C_3C_CONTRAST"); bump("WARN")
    end

    v = result.contrast.c_4c
    if v < WCAG_FAIL then table.insert(result.flags, "LOW_C_4C_CONTRAST"); bump("FAIL") end

    v = result.contrast["2c_3c"]
    if v < WCAG_FAIL then table.insert(result.flags, "LOW_2C_3C_CONTRAST"); bump("WARN") end

    for _, cvd in ipairs(CVD_KINDS) do
        local key = cvd .. "_c_3c"
        local cv = result.contrast[key]
        if cv then
            local flag = cvd:upper() .. "_CONTRAST_RISK"
            if cv < WCAG_FAIL then
                table.insert(result.flags, flag); bump("FAIL")
            elseif cv < minC then
                table.insert(result.flags, flag); bump("WARN")
            end
        end
    end

    return result
end

local AccessibilityAudit = {}

local function _hasDrawing(text)
    if not text then return false end
    return tostring(text):find("\\p%s*[1-9]") ~= nil
end

local function _hasAlphaTag(text)
    if not text then return false end
    text = tostring(text)
    if text:find("{[^}]*\\[1-4]?a&[Hh]%x+&") then return true end
    if text:find("\\alpha&[Hh]%x+&") then return true end
    for slot in text:gmatch("\\[1-4]?c(&[Hh]%x+)") do
        if #slot > 8 then return true end
    end
    return false
end

function AccessibilityAudit.run(subs, sel, profileId, options)
    options = options or {}
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

        report.actors[a] = AccessibilityMetrics.auditTextContrast(info.colors, profile)

        for _, lid in ipairs(info.ids or {}) do
            if report.drawingActors[a] and report.alphaRisks[a] then break end
            local l = subs[lid]
            if l and isDialogueLine(l) then
                local txt = tostring(l.text or "")
                if not report.drawingActors[a] and _hasDrawing(txt) then
                    report.drawingActors[a] = true
                end
                if not report.alphaRisks[a] and _hasAlphaTag(txt) then
                    report.alphaRisks[a] = true
                end
            end
        end
    end

    local simulate = profile.simulate or {}
    local cvdActive = {}
    for _, cvd in ipairs(CVD_KINDS) do
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
        local labA = oklabPerActor[actors[i]]
        for j = i + 1, #actors do
            local labB = oklabPerActor[actors[j]]
            local deltas = { normal = deltaFrom(labA.base, labB.base) }
            for _, c in ipairs(cvdActive) do
                deltas[c.kind] = deltaFrom(labA[c.kind], labB[c.kind])
            end
            local worst, kind = _pickWorst(deltas)
            if worst < minD then
                table.insert(report.pairs, { a = actors[i], b = actors[j], worst = worst, kind = kind, deltas = deltas })
            end
        end
    end

    for _, a in ipairs(actors) do
        local info = data[a]
        if info.has_vsf then
            for _, tag in ipairs(VSF_TAGS) do
                local vc = info.vsf_corners[tag]
                if vc then
                    local lo, hi = math.huge, -math.huge
                    for k = 1, 4 do
                        local lum = ColorUtil.luminance(vc[k])
                        if lum < lo then lo = lum end
                        if lum > hi then hi = lum end
                    end
                    if (hi - lo) < minMono then
                        table.insert(report.vsf, { a = a, tag = tag, kind = "mono_collapse", value = hi - lo })
                    end
                    local cr = ColorUtil.contrastRatio(vc[1], info.colors["3c"] or COLOR_BLACK)
                    if cr < WCAG_FAIL then
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

local REPORT_FLAG_TEXT = {
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

local REPORT_KIND_TEXT = {
    normal = "visión normal",
    protan = "protanopia",
    deutan = "deuteranopia",
    tritan = "tritanopia",
    mono = "monocromo",
    mono_collapse = "poca diferencia de luminancia entre esquinas",
    outline_low = "bajo contraste contra el borde",
}

function AccessibilityReport.flagText(code)
    local text = REPORT_FLAG_TEXT[code]
    if text then return text end
    return tostring(code or ""):gsub("_", " "):lower()
end

function AccessibilityReport.kindText(kind)
    return REPORT_KIND_TEXT[kind] or tostring(kind or "")
end

function AccessibilityReport.format(report, actors)
    local s = {}
    local function w(line) table.insert(s, line) end
    local statusLabels = { OK = "BIEN", WARN = "REVISAR", FAIL = "AJUSTAR", CRITICAL = "URGENTE" }

    w("# INFORME DE ACCESIBILIDAD DE COLOR")
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
            local line = string.format("  %-14s CR:%-5.1f", actorLabel(a):sub(1, 14), m.contrast.c_3c or 0)
            for _, cvd in ipairs(CVD_KINDS) do
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
    for _, cvd in ipairs(CVD_KINDS) do
        local sev = (profile.simulate or {})[cvd] or 0
        if sev > 0 then
            local cr = ColorUtil.contrastRatio(CVDSim.simulate(c1, cvd, sev), CVDSim.simulate(c2, cvd, sev))
            if cr < worst then worst = cr end
        end
    end
    return worst
end

function PaletteEngine.pickOutline(fill, profile)
    profile = AccessibilityProfiles.get(profile)
    local minC = (profile.thresholds and profile.thresholds.min_text_contrast) or 4.5
    local black, white = COLOR_BLACK, COLOR_WHITE
    local crB = PaletteEngine.contrastAcrossVision(fill, black, profile)
    local crW = PaletteEngine.contrastAcrossVision(fill, white, profile)
    if crB >= minC and crW >= minC then return crB >= crW and black or white end
    if crB >= minC then return black end
    if crW >= minC then return white end
    if crB >= crW then return black end
    return white
end

local function _scaleRGB(c, k)
    local r, g, b = ColorUtil.toRGB(c)
    return ColorUtil.fromRGB(r * k, g * k, b * k)
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
        for _, k in ipairs(PALETTE_SCALE_FACTORS) do
            add(_scaleRGB(actorInfo.colors.c, k))
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
    if cr < WCAG_FAIL or cvdCr < WCAG_FAIL then return math.huge end

    local contrastPenalty = 0
    if cr < WCAG_AA then contrastPenalty = 2 + (WCAG_AA - cr)
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

    return contrastPenalty * PALETTE_SCORE_WEIGHTS.contrast
        + collisionPenalty * PALETTE_SCORE_WEIGHTS.collision
        + monoPenalty * PALETTE_SCORE_WEIGHTS.mono
        + hueDrift * PALETTE_SCORE_WEIGHTS.hue_drift
        + lumaDrift * PALETTE_SCORE_WEIGHTS.luma_drift
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

function PaletteEngine.highContrastFallback(actorInfo, profile)
    local origLum = ColorUtil.luminance(actorInfo.colors.c)
    return origLum > 0.4 and COLOR_BLACK or COLOR_WHITE
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
        if pol.force_fill then
            local f = ColorUtil.normalize(pol.force_fill)
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
                local f = acc.fill
                result[tag] = { f, f, f, f }
            else
                local baseLum = ColorUtil.luminance(acc.fill)
                local desiredRange = math.max(origRange, minMono * 1.5)
                local lowL = baseLum - desiredRange / 2
                local highL = baseLum + desiredRange / 2
                if lowL < 0 then highL = math.min(1, highL + (-lowL)); lowL = 0 end
                if highL > 1 then lowL = math.max(0, lowL - (highL - 1)); highL = 1 end
                if highL - lowL < minMono then
                    if baseLum > 0.5 then lowL = math.max(0, highL - minMono * 1.5)
                    else                  highL = math.min(1, lowL + minMono * 1.5) end
                end

                local r, g, b = ColorUtil.toRGB(acc.fill)
                local out = {}
                for i = 1, 4 do
                    local t = (lums[i] - lo) / origRange
                    local targetL = lowL + t * (highL - lowL)
                    local k = (baseLum > 1e-3) and (targetL / baseLum) or (targetL > 0.5 and 2 or 1)
                    out[i] = ColorUtil.fromRGB(r * k, g * k, b * k)
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
        local outline = ColorUtil.normalize(pol.force_outline or COLOR_BLACK)
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
            best = PaletteEngine.highContrastFallback(data[a], profile)
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

local function _replaceVSFInLine(text, vsfRemap)
    if not vsfRemap then return text end
    return (text:gsub("\\([1-4]?)vc(%b())", function(n, parens)
        if n == "" then n = "1" end
        local key = n .. "vc"
        local vc = vsfRemap[key]
        if not vc then return nil end
        return "\\" .. n .. "vc(" .. vc[1] .. "," .. vc[2] .. "," .. vc[3] .. "," .. vc[4] .. ")"
    end))
end

local function _lineHasAnyVSF(text)
    if not text then return false end
    return tostring(text):find("\\[1-4]?vc%b()") ~= nil
end

local function _stripAlphaTags(text)
    if not text then return "" end
    return (tostring(text):gsub("{([^}]*)}", function(block)
        block = block:gsub("\\alpha&[Hh]%x+&", "")
        block = block:gsub("\\[1-4]a&[Hh]%x+&", "")
        block = cleanupTransforms(block)
        block = trim(block)
        if block == "" then return "" end
        return "{" .. block .. "}"
    end))
end

local function _sanitizeStyleName(actor)
    local s = tostring(actor or ""):gsub("[^%w_]", "_")
    s = s:gsub("^_+", ""):gsub("_+$", "")
    if s == "" then s = "Actor" end
    return s
end

local function _styleColorFromAss(c, inherited, preserveAlpha)
    return styleColorWithInheritedAlpha(c, inherited, preserveAlpha)
end

function AccessibilityApply.execute(subs, data, actors, styleMap, profile, options)
    profile = AccessibilityProfiles.get(profile)
    options = options or {}
    styleMap = styleMap or {}

    for _, actor in ipairs(actors or {}) do
        for _, index in ipairs((data[actor] and data[actor].ids) or {}) do
            local line = subs[index]
            if isDialogueLine(line) and hasTopLevelStyleReset(line.text) then
                return 0, 0, "La línea " .. tostring(index) .. " usa \\r. La paleta accesible no se aplicó porque aún no resuelve colores por run de estilo."
            end
        end
    end

    local applyMode      = options.apply_mode or "Tags"
    local preserveAlpha  = options.preserve_alpha ~= false
    local addBordShad    = options.add_bord_shad
    local includeDraw    = options.include_drawings == true
    local profileBord    = (profile.policy and profile.policy.bord) or 3
    local profileShad    = (profile.policy and profile.policy.shad) or 1
    if addBordShad == nil then
        addBordShad = (profile.policy and profile.policy.add_bord_shad) or false
    end

    if profile.policy and profile.policy.audit_only then
        return 0, 0, "El perfil " .. tostring(profile.id) .. " genera informe de evaluación."
    end

    local count, skipped = 0, 0

    if applyMode == "Styles" then
        for _, a in ipairs(actors) do
            local rawVSF = false
            for _, id in ipairs((data[a] and data[a].ids) or {}) do
                local candidate = subs[id]
                if isDialogueLine(candidate) and _lineHasAnyVSF(candidate.text) then
                    rawVSF = true
                    break
                end
            end
            if data[a] and (data[a].has_vsf or rawVSF) then
                return 0, 0, "El actor '" .. actorLabel(a) .. "' usa colores VSF; aplica como Etiquetas."
            end
        end
        local suffix = "_Z_ACC"
        if profile.id == "HIGH_CONTRAST" then suffix = "_Z_ACC_HC" end
        local nameMap, newStyles, claimedNames = {}, {}, {}
        local styleIndex, styleUsage = generatedStyleInventory(subs)
        local insertPos, lastNonDialoguePos, foundStyle = 1, 0, false
        for si = 1, #subs do
            local cls = subs[si].class
            if cls == "style" then
                insertPos = si + 1
                foundStyle = true
            elseif cls ~= "dialogue" then
                lastNonDialoguePos = si
            end
        end
        if not foundStyle and lastNonDialoguePos > 0 then insertPos = lastNonDialoguePos + 1 end

        for _, a in ipairs(actors) do
            local acc = data[a].accessibility
            local modifiableIds = {}
            for _, id in ipairs(data[a].ids or {}) do
                local candidate = subs[id]
                if isDialogueLine(candidate) and (includeDraw or not _hasDrawing(candidate.text)) then
                    modifiableIds[#modifiableIds + 1] = id
                end
            end
            local firstId = modifiableIds[1]
            if acc and firstId and isDialogueLine(subs[firstId]) then
                local base = styleMap[subs[firstId].style]
                local rawName = _sanitizeStyleName(a) .. suffix
                local name, existingIndex = chooseGeneratedStyleName(
                    rawName, subs, styleIndex, styleUsage,
                    idsAsSet(modifiableIds), claimedNames
                )
                if not name then
                    return 0, 0, "No se pudo reservar un nombre de estilo para '" .. tostring(a) .. "'."
                end
                claimedNames[name] = true

                local ns = { class = "style", name = name }
                if base then
                    for k, v in pairs(base) do
                        if k ~= "name" and k ~= "class" then ns[k] = v end
                    end
                else
                    copyFallbackStyle(ns)
                end

                ns.color1 = _styleColorFromAss(acc.fill, base and base.color1, preserveAlpha)
                ns.color3 = _styleColorFromAss(acc.outline, base and base.color3, preserveAlpha)
                ns.color4 = _styleColorFromAss(acc.shadow, base and base.color4, preserveAlpha)
                if addBordShad then
                    ns.outline = profileBord
                    ns.shadow  = profileShad
                end

                if existingIndex then
                    subs[existingIndex] = ns
                else
                    table.insert(newStyles, ns)
                end
                nameMap[a] = name
            end
        end

        for si = #newStyles, 1, -1 do subs.insert(insertPos, newStyles[si]) end
        local offset = #newStyles
        for _, a in ipairs(actors) do
            local sname = nameMap[a]
            if sname then
                for _, id in ipairs(data[a].ids or {}) do
                    local idx = id >= insertPos and id + offset or id
                    local l = subs[idx]
                    if isDialogueLine(l) then
                        if (not includeDraw) and _hasDrawing(l.text) then
                            skipped = skipped + 1
                        else
                            local origText = tostring(l.text or "")
                            if preserveAlpha then origText = AlphaUtil.expandEmbeddedColorAlpha(origText) end
                            l.style = sname
                            l.text  = TagStripper.clearColors(origText)
                            if not preserveAlpha then

                                l.text = _stripAlphaTags(l.text)
                            end
                            subs[idx] = l
                            count = count + 1
                        end
                    end
                end
            end
        end
        return count, skipped
    end

    for _, a in ipairs(actors) do
        local acc = data[a].accessibility
        if acc then
            local vsfRemap = acc.vsf
            for _, id in ipairs(data[a].ids or {}) do
                local l = subs[id]
                if isDialogueLine(l) then
                    local txt = tostring(l.text or "")
                    if (not includeDraw) and _hasDrawing(txt) then
                        skipped = skipped + 1
                    else

                        local fill, outline, shadow = acc.fill, acc.outline, acc.shadow
                        if preserveAlpha then
                            txt = AlphaUtil.expandEmbeddedColorAlpha(txt)
                        else

                            txt = _stripAlphaTags(txt)
                        end

                        if _lineHasAnyVSF(txt) and vsfRemap then
                            txt = _replaceVSFInLine(txt, vsfRemap)
                        end

                        txt = TagStripper.harmonizeColors(txt, fill, outline, shadow)

                        if addBordShad then
                            txt = txt:gsub("{([^}]*)}", function(block)
                                block = block:gsub("\\bord[%d%.]+", "")
                                block = block:gsub("\\shad[%d%.]+", "")
                                if block:match("^%s*$") then return "" end
                                return "{" .. block .. "}"
                            end, 1)
                            txt = injectFirstTags(txt, "\\bord" .. profileBord .. "\\shad" .. profileShad)
                        end

                        txt = TagStripper.dedupeColors(txt)
                        txt = txt:gsub("{%s*}", "")
                        l.text = txt
                        subs[id] = l
                        count = count + 1
                    end
                end
            end
        end
    end
    return count, skipped
end

local AccessibilityConfig = {}

local ACCESS_CONFIG_DEFAULTS = {
    active_profile   = "DALTONICO",
    apply_mode       = "Tags",
    preserve_alpha   = true,
    add_bord_shad    = false,
    include_drawings = false,
}

local VALID_APPLY_MODES = { Tags = true, Styles = true }

local function _accessConfigPath()
    return aegisub.decode_path("?user") .. "/zheus_accessibility.lua"
end

local function _serializeLua(v, indent)
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
            table.insert(parts, nextIndent .. _serializeLua(x, nextIndent) .. ",")
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
                key = "[" .. _serializeLua(k, nextIndent) .. "]"
            end
            table.insert(parts, nextIndent .. key .. " = " .. _serializeLua(v[k], nextIndent) .. ",")
        end
    end
    table.insert(parts, indent .. "}")
    return table.concat(parts, "\n")
end

local function _safeLoadLuaTable(content, sizeLimit, maxNodes)
    if not content or content == "" then return nil end
    if #content > (sizeLimit or CONFIG_FILE_LIMIT) then return nil end

    local stripped = tostring(content):gsub("^%s+", ""):gsub("%s+$", "")
    if stripped == "" then return nil end
    local src = stripped:match("^return[%s%c]") and stripped or ("return " .. stripped)
    local chunk
    if setfenv and loadstring then
        chunk = loadstring(src, "zheus_access_cfg")
        if chunk then setfenv(chunk, {}) end
    elseif load then
        chunk = load(src, "zheus_access_cfg", "t", {})
    end
    if not chunk then return nil end
    if not debug or type(debug.sethook) ~= "function" then return nil end

    local oldHook, oldMask, oldCount
    if type(debug.gethook) == "function" then
        oldHook, oldMask, oldCount = debug.gethook()
    end
    local instructions = 0
    local hookActive = true
    local function instructionGuard()
        if not hookActive then return end
        instructions = instructions + CONFIG_HOOK_GRANULARITY
        if instructions > CONFIG_INSTRUCTION_LIMIT then error("configuration instruction limit exceeded", 0) end
    end
    local hookOk = pcall(debug.sethook, instructionGuard, "", CONFIG_HOOK_GRANULARITY)
    if not hookOk then return nil end
    local ok, t = pcall(chunk)
    hookActive = false
    if oldHook then
        pcall(debug.sethook, oldHook, oldMask or "", oldCount or 0)
    else
        pcall(debug.sethook)
    end
    if not ok or type(t) ~= "table" then return nil end

    local seen, nodes = {}, 0
    local function plain(value, depth)
        local valueType = type(value)
        if valueType == "nil" or valueType == "string" or valueType == "boolean" then return true end
        if valueType == "number" then return finiteNumber(value) ~= nil end
        if valueType ~= "table" or depth > CONFIG_MAX_DEPTH or seen[value] then return false end
        seen[value] = true
        for key, child in pairs(value) do
            nodes = nodes + 1
            if nodes > (maxNodes or CONFIG_MAX_NODES) then return false end
            local keyType = type(key)
            if (keyType ~= "string" and keyType ~= "number") or
                (keyType == "number" and not finiteNumber(key)) or
                not plain(child, depth + 1) then return false end
        end
        seen[value] = nil
        return true
    end
    if not plain(t, 1) then return nil end
    return t
end

function AccessibilityConfig.load()
    local merged = {}
    for k, v in pairs(ACCESS_CONFIG_DEFAULTS) do merged[k] = v end
    local content = PyBridge.readFile(_accessConfigPath(), CONFIG_FILE_LIMIT + 1)
    if not content then return merged end
    local stored = _safeLoadLuaTable(content)
    if not stored then return merged end

    if type(stored.custom_profiles) == "table" then
        local validProfiles = {}
        for id, p in pairs(stored.custom_profiles) do
            if type(p) == "table" and not BUILTIN_PROFILE_IDS[id] then
                local registered, sanitized = AccessibilityProfiles.register(p, id)
                if registered then validProfiles[id] = sanitized end
            end
        end
        merged.custom_profiles = validProfiles
    end
    for k, def in pairs(ACCESS_CONFIG_DEFAULTS) do
        local v = stored[k]
        if v ~= nil and type(v) == type(def) then
            if k == "active_profile" then
                if AccessibilityProfiles.list[v] then merged[k] = v end
            elseif k == "apply_mode" then
                if VALID_APPLY_MODES[v] then merged[k] = v end
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
            if type(p) == "table" and not BUILTIN_PROFILE_IDS[id] then
                local registered, sanitized = AccessibilityProfiles.register(p, id)
                if registered then validProfiles[id] = sanitized end
            end
        end
        current.custom_profiles = validProfiles
    end
    for k, def in pairs(ACCESS_CONFIG_DEFAULTS) do
        local v = t[k]
        if v ~= nil and type(v) == type(def) then
            if k == "active_profile" then
                if AccessibilityProfiles.list[v] then current[k] = v end
            elseif k == "apply_mode" then
                if VALID_APPLY_MODES[v] then current[k] = v end
            else
                current[k] = v
            end
        end
    end
    local serialized = "return " .. _serializeLua(current)
    if #serialized > CONFIG_FILE_LIMIT then return false, "configuration exceeds the size limit" end
    return PyBridge.writeFile(_accessConfigPath(), serialized)
end

local function _registerCustomProfilesFromDisk()
    local ok, cfg = pcall(AccessibilityConfig.load)
    if not ok or type(cfg) ~= "table" then return end
    if type(cfg.custom_profiles) ~= "table" then return end
    for id, p in pairs(cfg.custom_profiles) do
        if type(p) == "table" and not BUILTIN_PROFILE_IDS[id] then
            AccessibilityProfiles.register(p, id)
        end
    end
end
_registerCustomProfilesFromDisk()

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
            for _, tag in ipairs(VSF_TAGS) do
                local vc = info.vsf_corners[tag]
                if vc then row.vsf[tag] = { vc[1], vc[2], vc[3], vc[4] } end
            end
        end
        out.actors[a] = row
    end

    local serialized = "return " .. _serializeLua(out)
    if #serialized > PALETTE_FILE_LIMIT then return "La paleta accesible supera el límite de tamaño." end
    local ok, err = PyBridge.writeFile(fp, serialized)
    if not ok then return "Error al escribir: " .. tostring(err) end
    return "Exportados " .. #actors .. " actores -> " .. fp
end

function AccessibilityExportFile.import(data, actors)
    local fp = aegisub.dialog.open("Importar paleta accesible - Zheus Colormanager", "", "", "*.txt;*.lua", false, true)
    if not fp then return nil end
    local content, readError = PyBridge.readFile(fp, PALETTE_FILE_LIMIT + 1)
    if not content then return "Error al leer el archivo: " .. tostring(readError) end
    if #content > PALETTE_FILE_LIMIT then return "La paleta accesible supera el límite de tamaño." end

    local imported, invalid, missing, updated = 0, 0, {}, {}

    local v3 = _safeLoadLuaTable(content, PALETTE_FILE_LIMIT, PALETTE_MAX_NODES)
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
                    updated[actor] = true
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
            for p in l:gmatch("[^|]+") do table.insert(parts, p) end
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
                        updated[actor] = true
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
        criteria = "Severidad CVD y contraste desde la calibración registrada.",
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

    local btn, res = aegisub.dialog.display(ui, { "Calibrar", "Cancel" })
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
local CONFIG_DEFAULTS = {
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

local function readConfigFile()
    local content = PyBridge.readFile(configPath(), CONFIG_FILE_LIMIT + 1)
    return content and (_safeLoadLuaTable(content) or {}) or {}
end

local function writeConfigFile(t)
    local parts = {"return {\n"}
    local keys = {}
    for key in pairs(t) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        local v = t[k]
        if type(v) == "string" then
            parts[#parts + 1] = string.format("  [%q] = %q,\n", k, v)
        elseif type(v) == "boolean" or type(v) == "number" then
            parts[#parts + 1] = string.format("  [%q] = %s,\n", k, tostring(v))
        end
    end
    parts[#parts + 1] = "}\n"
    return PyBridge.writeFile(configPath(), table.concat(parts))
end

function Config.load()
    local stored = readConfigFile()
    local merged = {}
    for k, v in pairs(CONFIG_DEFAULTS) do merged[k] = v end
    for k, v in pairs(stored) do
        local def = CONFIG_DEFAULTS[k]
        if def ~= nil and type(v) == type(def) then merged[k] = v end
    end
    return merged
end

function Config.save(t)
    local current = Config.load()
    for k, def in pairs(CONFIG_DEFAULTS) do
        local v = t[k]
        if v ~= nil and type(v) == type(def) then
            current[k] = v
        end
    end
    return writeConfigFile(current)
end

local HELP_TEXT = "ZHEUS COLORMANAGER " .. script_version .. [[

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
    aegisub.dialog.display({ { class = "label", label = tostring(msg or ""), x = 0, y = 0, width = 40, height = 4 } }, { "Aceptar" })
end

local function textoNormalizado(v)
    if type(v) == "string" then return v end
    if v == nil then return "" end
    return tostring(v)
end

local function gestorDeActores(subs, sel)
    local unique, seen = {}, {}
    for _, i in ipairs(sel) do
        local line = subs[i]
        if isDialogueLine(line) then
            local a = textoNormalizado(line.actor)
            if not seen[a] then seen[a] = true; table.insert(unique, a) end
        end
    end
    table.sort(unique)
    local originalText = table.concat(unique, "\n")
    local dlg = {
        { class = "label",   label = "Original",                  x = 0,  y = 0, width = 15, height = 1 },
        { class = "label",   label = "Nuevo (vacío = conservar)", x = 15, y = 0, width = 15, height = 1 },
        { class = "textbox", name = "src",  text = originalText,  x = 0,  y = 1, width = 15, height = 20, readonly = true },
        { class = "textbox", name = "dest", text = originalText,  x = 15, y = 1, width = 15, height = 20 },
    }
    local btn, res = aegisub.dialog.display(dlg, { "Execute", "Cancel" })
    if btn ~= "Execute" then return "cancel" end
    local function parseMl(s)
        local t = {}; s = s:gsub("\r\n", "\n"):gsub("\r", "\n")
        local i = 1
        while true do
            local n = s:find("\n", i)
            if not n then table.insert(t, s:sub(i)); break end
            table.insert(t, s:sub(i, n - 1)); i = n + 1
        end
        return t
    end
    local newActors = parseMl(res.dest)
    local map = {}
    for i, original in ipairs(unique) do
        local new = newActors[i]
        if new ~= nil and trim(new) ~= "" and new ~= original then map[original] = new end
    end
    local changed = 0
    for _, idx in ipairs(sel) do
        local l = subs[idx]
        if isDialogueLine(l) then
            local original = textoNormalizado(l.actor)
            if map[original] ~= nil then l.actor = map[original]; subs[idx] = l; changed = changed + 1 end
        end
    end
    local uc = 0; for _ in pairs(map) do uc = uc + 1 end
    showMsg(string.format("Se actualizaron %d actores en %d líneas.", uc, changed))
    return "done", changed, uc
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
    for _, i in ipairs(sel or {}) do
        local l = subs[i]
        if isDialogueLine(l) then
            stats.lineCount = stats.lineCount + 1
            local actor = trim(l.actor or "")
            if actor == "" then
                stats.emptyActorLines = stats.emptyActorLines + 1
            end
            stats.actorLines[actor] = (stats.actorLines[actor] or 0) + 1
            local text = tostring(l.text or "")
            for _, raw in text:gmatch(PAT_COLOR_CAP) do
                stats.solidColors[ColorUtil.normalize(raw)] = true
                stats.anySolid = true
            end
            for _, parens in text:gmatch(PAT_VC_CAP) do
                for col in parens:sub(2, -2):gmatch(PAT_HEX_TOKEN) do
                    stats.vsfColors[ColorUtil.normalize(col)] = true
                end
                stats.anyVSF = true
            end
        end
    end
    return stats
end

local function _contrastStatus(minCR)
    if minCR < WCAG_FAIL then return "AJUSTAR" end
    if minCR < WCAG_AA   then return "REVISAR" end
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
        local status = _contrastStatus(math.min(cr3, cr4))
        if     status == "OK"      then nOK   = nOK   + 1
        elseif status == "REVISAR" then nWarn = nWarn + 1
        else                            nFail = nFail + 1 end
        local visibleStatus = status == "OK" and "BIEN" or status
        w(string.format("  %-18s %7.1f %7.1f   %s",
            actorLabel(a):sub(1, 18), cr3, cr4, visibleStatus))
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
    table.insert(ui, { class = "label", label = "Canales para cambiar:", x = 0, y = baseY, width = 3 })
    table.insert(ui, { class = "checkbox", name = "replace_slot_1", label = "\\c",  value = slots["1"], x = 3, y = baseY, width = 2 })
    table.insert(ui, { class = "checkbox", name = "replace_slot_2", label = "\\2c", value = slots["2"], x = 5, y = baseY, width = 2 })
    table.insert(ui, { class = "checkbox", name = "replace_slot_3", label = "\\3c", value = slots["3"], x = 7, y = baseY, width = 2 })
    table.insert(ui, { class = "checkbox", name = "replace_slot_4", label = "\\4c", value = slots["4"], x = 9, y = baseY, width = 3 })
end

local function buildVSFGradientPanel(cfg, auditText, status)
    local vsfY = 3 + UI.audit_height
    local ui = {
        { class = "label",   label = "Zheus Colormanager v" .. script_version .. " - selección", x = 0, y = 0, width = UI.dashboard_width },
        { class = "label",    label = "Gestores:", x = 0, y = 1, width = 2 },
        { class = "dropdown", name = "gestores", items = { "Colores por Actor", "Actores" }, value = "Colores por Actor", x = 2, y = 1, width = 4 },
        { class = "label",    label = "Cambios:", x = 0, y = 2, width = 2 },
        { class = "dropdown", name = "cambios", items = { "De colores", "De colores en secuencia" }, value = "De colores", x = 2, y = 2, width = 4 },
        { class = "textbox", name = "audit_preview", text = auditText or "", x = 0, y = 3, width = UI.dashboard_width, height = UI.audit_height, readonly = true },
        { class = "label",    label = "Degradados VSFilterMod", x = 0, y = vsfY, width = 4 },
        { class = "checkbox", name = "vcl", label = "Limpiar \\vc previos", value = cfg.vcl, x = 4, y = vsfY, width = 4 },
        { class = "label",    label = "Requiere VSFilterMod para renderizar \\vc.", x = 8, y = vsfY, width = 4 },
    }
    addVSFBlock(ui, cfg, "1vc", "\\1vc relleno", 0, vsfY + 1)
    addVSFBlock(ui, cfg, "2vc", "\\2vc secund.", 3, vsfY + 1)
    addVSFBlock(ui, cfg, "3vc", "\\3vc borde",   6, vsfY + 1)
    addVSFBlock(ui, cfg, "4vc", "\\4vc sombra",  9, vsfY + 1)
    addReplaceSlotControls(ui, cfg, vsfY + 4)
    table.insert(ui, { class = "label", label = status or "", x = 0, y = vsfY + 5, width = UI.dashboard_width })
    return ui
end

local openAccessibilityAudit
local openAccessibilityApply
local openCalibrationWizard
local openAccessibilityExport

local function MainController(subs, sel, init_mode, data_in, actors_in)
    if not sel or #sel == 0 then
        showMsg("Selecciona líneas.")
        return
    end
    local resetLine = firstSelectedStyleReset(subs, sel)
    if resetLine then
        showMsg("La línea " .. tostring(resetLine) .. " usa \\r. Zheus no puede auditar ni reasignar fielmente colores de estilos reiniciados; divide la línea en runs uniformes.")
        return
    end

    local styleMap = collectStyles(subs)
    local cfg      = Config.load()
    local mode     = (type(init_mode) == "string" and init_mode) or "DASH"
    local data, actors = data_in, actors_in
    local page, status = 1, ""
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
        local maxPage = math.max(1, math.ceil((actors and #actors or 1) / PER_PAGE))
        if page > maxPage then page = maxPage end
    end

    while true do
        local ui, btns, shown, displayedVSFTag

        if mode == "DASH" then
            ui = buildVSFGradientPanel(cfg, getAuditText(), status)
            btns = { "Gestor", "Cambio", "VSF", "Daltonismo", "Ayuda", "Cancel" }
        elseif mode == "ARCH" then
            ui, shown = ManagerDialog.build(page, PER_PAGE, actors, data, nil, nil)
            local y = 3 + (shown or 0)
            table.insert(ui, { class = "dropdown", name = "op", items = { "Etiquetas", "Estilos", "Limpiar" }, value = "Etiquetas", x = 0, y = y, width = 2 })
            table.insert(ui, { class = "checkbox", name = "cl", label = "Auto-limpiar (forzado en Estilos)", value = true, x = 2, y = y, width = 3 })
            table.insert(ui, { class = "label",    label = status, x = 0, y = y + 1, width = 5 })
            btns = { "Execute", "←", "→", "VSF", "Lista", "Conflictos", "Exportar", "Importar", "Volver" }
        elseif mode == "ARCHVSF" then
            displayedVSFTag = vsfTag
            ui, shown = ManagerDialog.build(page, PER_PAGE, actors, data, "vsf", displayedVSFTag)
            local y = 3 + (shown or 0)
            table.insert(ui, { class = "label",    label = "VSF (\\" .. displayedVSFTag .. ") - modo Etiquetas", x = 0, y = y, width = 6 })
            table.insert(ui, { class = "dropdown", name = "op", items = { "Etiquetas", "Limpiar" }, value = "Etiquetas", x = 0, y = y + 1, width = 2 })
            table.insert(ui, { class = "checkbox", name = "cl", label = "Auto-limpiar", value = true, x = 2, y = y + 1, width = 2 })
            table.insert(ui, { class = "label",    label = status, x = 0, y = y + 2, width = 6 })
            btns = { "Execute", "←", "→", "Exportar", "Importar", "Normal", "Volver" }
        elseif mode == "LIST" then
            ui = ManagerDialog.build(page, PER_PAGE, actors, data, "summary", nil)
            btns = { "Volver" }
        elseif mode == "CONF" then
            ui = ManagerDialog.build(page, PER_PAGE, actors, data, "conflicts", nil)
            btns = { "Volver" }
        elseif mode == "HELP" then
            ui = { { class = "textbox", text = HELP_TEXT, x = 0, y = 0, width = UI.help_width, height = UI.help_height, readonly = true } }
            btns = { "Volver" }
        end

        local btn, res = aegisub.dialog.display(ui, btns)
        if not btn or btn == "Cancel" then break end
        res = res or {}

        if mode == "ARCHVSF" and res.vctag and res.vctag ~= displayedVSFTag then
            ManagerDialog.sync(data, actors, res, page, PER_PAGE, "vsf", displayedVSFTag)
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
            ManagerDialog.sync(data, actors, res, page, PER_PAGE, nil, nil)
            mode = "LIST"
        elseif btn == "Conflictos" then
            ManagerDialog.sync(data, actors, res, page, PER_PAGE, nil, nil)
            mode = "CONF"
        elseif btn == "VSF" and mode == "ARCH" then
            ManagerDialog.sync(data, actors, res, page, PER_PAGE, nil, nil)
            mode = "ARCHVSF"
        elseif btn == "Normal" then
            ManagerDialog.sync(data, actors, res, page, PER_PAGE, "vsf", vsfTag)
            mode = "ARCH"
        elseif btn == "Volver" then
            if mode == "ARCH" then
                ManagerDialog.sync(data, actors, res, page, PER_PAGE, nil, nil)
                mode = "DASH"
            elseif mode == "ARCHVSF" then
                ManagerDialog.sync(data, actors, res, page, PER_PAGE, "vsf", vsfTag)
                mode = "ARCH"
            elseif mode == "LIST" or mode == "CONF" then
                mode = "ARCH"
            else
                mode = "DASH"
            end
        elseif btn == "←" or btn == "◁" then
            if mode == "ARCHVSF" then
                ManagerDialog.sync(data, actors, res, page, PER_PAGE, "vsf", vsfTag)
            else
                ManagerDialog.sync(data, actors, res, page, PER_PAGE, nil, nil)
            end
            page = math.max(1, page - 1)
        elseif btn == "→" or btn == "▷" then
            if mode == "ARCHVSF" then
                ManagerDialog.sync(data, actors, res, page, PER_PAGE, "vsf", vsfTag)
            else
                ManagerDialog.sync(data, actors, res, page, PER_PAGE, nil, nil)
            end
            local totalActors = actors and #actors or 0
            page = math.min(math.max(1, math.ceil(math.max(1, totalActors) / PER_PAGE)), page + 1)
        elseif btn == "Execute" then

            local applied = false
            if mode == "ARCHVSF" then
                ManagerDialog.sync(data, actors, res, page, PER_PAGE, "vsf", vsfTag)
                local cnt, err = ManagerApply.execute(subs, data, actors, styleMap, res.op, res.cl, true, vsfTag)
                if not cnt then
                    showMsg(err)
                    status = "Error: " .. (err or "Error al aplicar VSF.")
                else
                    aegisub.set_undo_point("Zheus Colormanager VSF")
                    status = cnt .. " líneas con \\" .. vsfTag .. " aplicadas."
                    applied = cnt > 0
                end
            else
                ManagerDialog.sync(data, actors, res, page, PER_PAGE, nil, nil)
                local cnt, err = ManagerApply.execute(subs, data, actors, styleMap, res.op, res.cl, false, nil)
                if not cnt then
                    showMsg(err)
                    status = "Error: " .. (err or "Error al aplicar.")
                else
                    aegisub.set_undo_point("Zheus Colormanager")
                    status = cnt .. " líneas procesadas."
                    applied = cnt > 0
                end
            end
            if applied then return end
            rescan()
        elseif btn == "Exportar" then
            if mode == "ARCHVSF" then
                ManagerDialog.sync(data, actors, res, page, PER_PAGE, "vsf", vsfTag)
            else
                ManagerDialog.sync(data, actors, res, page, PER_PAGE, nil, nil)
            end
            local msg = ActorColorFile.io(data, actors, "Export")
            if msg then status = msg end
        elseif btn == "Importar" then
            if mode == "ARCHVSF" then
                ManagerDialog.sync(data, actors, res, page, PER_PAGE, "vsf", vsfTag)
            else
                ManagerDialog.sync(data, actors, res, page, PER_PAGE, nil, nil)
            end
            local msg, has_vsf_data = ActorColorFile.io(data, actors, "Import")
            if msg then
                status = msg
                if has_vsf_data and mode ~= "ARCHVSF" then
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
            if res.cambios == "De colores en secuencia" then
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
            local action, count, skipped, label = openAccessibilityApply(subs, sel, nil, true)
            if action == "done" then
                if label then return end
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
        MainController(subs, sel, "ARCH", data, actors)
    end
end

local function openVSFManagerDirect(subs, sel)
    if not sel or #sel == 0 then showMsg("Selecciona líneas para abrir VSF."); return end
    local styleMap = collectStyles(subs)
    local data, actors = StyleScanner.scanActors(subs, sel, styleMap)
    if #actors == 0 then
        showMsg("La selección está vacía de actores.")
    else
        MainController(subs, sel, "ARCHVSF", data, actors)
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
    local resetLine = firstSelectedStyleReset(subs, sel)
    if resetLine then showMsg("La línea " .. tostring(resetLine) .. " usa \\r; la auditoría no puede resolver aún colores por run de estilo."); return end
    local cfg = AccessibilityConfig.load()
    local report = AccessibilityAudit.run(subs, sel, cfg.active_profile)
    local text = AccessibilityReport.format(report, (function()
        local out = {}
        for a in pairs(report.actors) do table.insert(out, a) end
        table.sort(out)
        return out
    end)())
    aegisub.dialog.display({
        { class = "label",   label = "Auditoría de accesibilidad de color", x = 0, y = 0, width = 80 },
        { class = "textbox", name = "audit", text = text, x = 0, y = 1, width = 80, height = 28 },
    }, { "Aceptar" })
end

local function _profileApplyPanel(cfg, profileId, audit, viewMode, subs, sel)
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
    if pol.add_bord_shad then defaultBordShad = true end

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
        { class = "textbox",    name = "profiles", text = bodyText,       x = 0, y = 4, width = 12, height = 18, readonly = true },
    }
end

openAccessibilityApply = function(subs, sel, profileId, silent)
    if not sel or #sel == 0 then showMsg("Selecciona líneas para aplicar Daltonismo."); return end
    local resetLine = firstSelectedStyleReset(subs, sel)
    if resetLine then showMsg("La línea " .. tostring(resetLine) .. " usa \\r; la paleta no se aplicó porque aún no resuelve colores por run de estilo."); return end
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
        local panel = _profileApplyPanel(cfg, currentProfileId, audit, viewMode, subs, sel)
        local btn, res = aegisub.dialog.display(panel, { "Execute", "Calibrar", "Exportar", "Importar", "Cancel" })
        if not btn or btn == "Cancel" then return nil end
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
                        for _, tag in ipairs(VSF_TAGS) do
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
        local count, skipped, applyErr = AccessibilityApply.execute(subs, data, actors, styleMap, profile, options)
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
        return "done", count, skipped, AccessibilityProfiles.label(profile.id)
    end

    local current = profileId or cfg.active_profile or "DALTONICO"
    while true do
        local action, p1, p2, p3 = runCycle(current)
        if action == "retry" then current = p1
        else return action, p1, p2, p3 end
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
        ok and ("Guardado como perfil activo en:\n  " .. _accessConfigPath())
            or ("Error al guardar: " .. tostring(err)),
        "",
        "Comprueba la escena con el perfil activo.",
    }
    showMsg(table.concat(lines, "\n"))
end

openAccessibilityExport = function(subs, sel)
    if not sel or #sel == 0 then showMsg("Selecciona líneas para exportar."); return end
    local resetLine = firstSelectedStyleReset(subs, sel)
    if resetLine then showMsg("La línea " .. tostring(resetLine) .. " usa \\r; no se exportó una paleta potencialmente incorrecta."); return end
    local cfg = AccessibilityConfig.load()
    local audit, data, actors = AccessibilityAudit.run(subs, sel, cfg.active_profile)
    if #actors == 0 then showMsg("La selección está vacía de actores."); return end

    local profileChoices = AccessibilityProfiles.choices()
    local profileChoice = AccessibilityProfiles.choiceFromId(cfg.active_profile)
    local btn, res = aegisub.dialog.display({
        { class = "label",    label = "Exportar paleta accesible v3", x = 0, y = 0, width = 4 },
        { class = "label",    label = "Perfil:",                 x = 0, y = 1, width = 1 },
        { class = "dropdown", name = "profile", items = profileChoices, value = profileChoice, x = 1, y = 1, width = 3 },
        { class = "label",    label = "Actores en selección: " .. #actors, x = 0, y = 2, width = 4 },
    }, { "Exportar", "Cancel" })
    if btn ~= "Exportar" then return end

    local profile = AccessibilityProfiles.get(AccessibilityProfiles.idFromChoice(res.profile))
    data = PaletteEngine.remapActors(data, actors, profile)
    local msg = AccessibilityExportFile.export(data, actors, profile)
    if msg then showMsg(msg) end
end

local function _macroApply(profileId)
    return function(subs, sel) openAccessibilityApply(subs, sel, profileId) end
end

local macroEntries = {
    { MENU_PATH,                                   script_description,                    MainController },
}

local hotkeyMacroEntries = {
    { "Colores",            "Atajo: abrir gestor de color por actor",       openChromaManagerDirect },
    { "VSF",                "Atajo: abrir gestor de 4 esquinas por actor",  openVSFManagerDirect },
    { "Actores",            "Atajo: renombrar o fusionar actores",          ejecutarGestorDeActores },
    { "Cambiar colores",    "Atajo: buscar y cambiar colores",              runColorReplaceDirect },
    { "ColorRelay",         "Atajo: cambios de color persistentes por \\t",  ColorRelay.run },
    { "Daltonismo",                  "Atajo: abrir panel de Daltonismo",            openAccessibilityApply },
    { "Daltonismo/Auditar",          "Atajo: auditar accesibilidad de color",        openAccessibilityAudit },
    { "Daltonismo/Aplicar Daltonismo", "Atajo: aplicar perfil Daltonismo",           _macroApply("DALTONICO") },
    { "Daltonismo/Universal",        "Atajo: aplicar perfil Universal accesible",    _macroApply("UNIVERSAL_SAFE") },
    { "Daltonismo/Protanopia",       "Atajo: aplicar perfil Protanopia",             _macroApply("PROTAN_SAFE") },
    { "Daltonismo/Deuteranopia",     "Atajo: aplicar perfil Deuteranopia",           _macroApply("DEUTAN_SAFE") },
    { "Daltonismo/Tritanopia",       "Atajo: aplicar perfil Tritanopia",             _macroApply("TRITAN_SAFE") },
    { "Daltonismo/Monocromo",        "Atajo: aplicar perfil Monocromo",              _macroApply("MONOCHROME") },
    { "Daltonismo/Alto contraste",   "Atajo: aplicar perfil Alto contraste",         _macroApply("HIGH_CONTRAST") },
    { "Daltonismo/Calibrar perfil",  "Atajo: crear perfil Personalizado",            openCalibrationWizard },
    { "Daltonismo/Exportar accesible", "Atajo: exportar paleta accesible v3",        openAccessibilityExport },
}

for _, entry in ipairs(hotkeyMacroEntries) do
    macroEntries[#macroEntries + 1] = {
        HOTKEY_MENU_PATH .. "/" .. entry[1],
        entry[2],
        entry[3],
    }
end

depRec:registerMacros(macroEntries, false)
