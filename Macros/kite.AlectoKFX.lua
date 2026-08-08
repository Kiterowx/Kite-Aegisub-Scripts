script_name = "Alecto KFX"
script_description = "Compila karaokes y textos desde guias intro/active/outro, con re-proyeccion espacial y temporal"
script_author = "Kiterow"
script_version = "3.2.3"
script_namespace = "kite.AlectoKFX"

local karaskel_load_error
if not karaskel then
    local include_error, require_error
    if type(include) == "function" then
        local ok, result = pcall(include, "karaskel.lua")
        if ok and not karaskel and type(result) == "table" then karaskel = result end
        if not ok then include_error = result end
    end
    if not karaskel then
        local ok, result = pcall(require, "karaskel")
        if ok and type(result) == "table" then karaskel = result end
        if not ok then require_error = result end
    end
    if not karaskel then
        local errors = {}
        if include_error then errors[#errors + 1] = "include: " .. tostring(include_error) end
        if require_error then errors[#errors + 1] = "require: " .. tostring(require_error) end
        karaskel_load_error = #errors > 0 and table.concat(errors, " | ") or "modulo no disponible"
    end
end

local depctrl
local ok_depctrl, DependencyControl = pcall(require, "l0.DependencyControl")
if ok_depctrl and DependencyControl then
    local ok_record, record = pcall(DependencyControl, {
        name = script_name,
        description = script_description,
        author = script_author,
        version = script_version,
        namespace = script_namespace,
        feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
        {
            {
                "kite.LineOps",
                version = "1.5.2",
                url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
                feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
            },
        },
    })
    if ok_record then depctrl = record end
end

local LineOps
if depctrl and depctrl.requireModules then
    local ok, value = pcall(function() return depctrl:requireModules() end)
    if ok then LineOps = value end
end
if not LineOps then
    local ok, value = pcall(require, "kite.LineOps")
    if ok then LineOps = value end
end

local CONFIG_DEFAULT = {
    lead_ms = 300,
    stagger_ms = 40,
    fade_ms = 200,
    tail_ms = 200,
    respiro_ms = 20,
    min_dur_ms = 10,
    max_generated_events = 20000,
    inherit_target_tags = true,
    default_order = "ltr",
    fx_marker = "alecto-fx",
    base_len_ms = 3000,
    base_gap_ms = 100,
    base_offset_ms = 500,
    base_block_gap_ms = 400,
    fallback_space_width = 6,
    fallback_char_width = 8,
}
local CONFIG = {}
for key, value in pairs(CONFIG_DEFAULT) do CONFIG[key] = value end

local Core = {}
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local function trim(s)
    return (tostring(s or ""):match("^%s*(.-)%s*$")) or ""
end
Core.trim = trim

local function clamp(v, lo, hi)
    v = tonumber(v) or 0
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
Core.clamp = clamp

local function round(v)
    v = tonumber(v) or 0
    if v >= 0 then return floor(v + 0.5) end
    return -floor(-v + 0.5)
end
Core.round = round

local function fmt_num(v)
    v = tonumber(v) or 0
    if v > -0.005 and v < 0.005 then v = 0 end
    local t = string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", "")
    if t == "-0" then t = "0" end
    return t
end
Core.fmt_num = fmt_num

local function shallow_copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end
Core.shallow_copy = shallow_copy

local function utf8_next(s, i)
    local b1 = s:byte(i)
    if not b1 then return nil, i end
    if b1 < 0x80 then return b1, i + 1 end
    local b2 = s:byte(i + 1)
    if b1 >= 0xC2 and b1 <= 0xDF and b2 and b2 >= 0x80 and b2 <= 0xBF then
        return (b1 - 0xC0) * 0x40 + (b2 - 0x80), i + 2
    end
    local b3 = s:byte(i + 2)
    if b1 >= 0xE0 and b1 <= 0xEF and b2 and b3
        and b2 >= 0x80 and b2 <= 0xBF and b3 >= 0x80 and b3 <= 0xBF then
        local cp = (b1 - 0xE0) * 0x1000 + (b2 - 0x80) * 0x40 + (b3 - 0x80)
        if cp >= 0x800 and not (cp >= 0xD800 and cp <= 0xDFFF) then
            return cp, i + 3
        end
    end
    local b4 = s:byte(i + 3)
    if b1 >= 0xF0 and b1 <= 0xF4 and b2 and b3 and b4
        and b2 >= 0x80 and b2 <= 0xBF and b3 >= 0x80 and b3 <= 0xBF
        and b4 >= 0x80 and b4 <= 0xBF then
        local cp = (b1 - 0xF0) * 0x40000 + (b2 - 0x80) * 0x1000
            + (b3 - 0x80) * 0x40 + (b4 - 0x80)
        if cp >= 0x10000 and cp <= 0x10FFFF then return cp, i + 4 end
    end
    return b1, i + 1
end

local function is_combining(cp)
    return (cp >= 0x0300 and cp <= 0x036F)
        or (cp >= 0x1AB0 and cp <= 0x1AFF)
        or (cp >= 0x1DC0 and cp <= 0x1DFF)
        or (cp >= 0x20D0 and cp <= 0x20FF)
        or (cp >= 0xFE20 and cp <= 0xFE2F)
        or (cp >= 0xFE00 and cp <= 0xFE0F)
        or (cp >= 0xE0100 and cp <= 0xE01EF)
        or (cp >= 0x1F3FB and cp <= 0x1F3FF)
end

function Core.ass_tokens(s)
    s = tostring(s or "")
    local out = {}
    local i, n = 1, #s
    while i <= n do
        local two = s:sub(i, i + 1)
        if two == "\\N" or two == "\\n" or two == "\\h" then
            out[#out + 1] = {
                text = two,
                control = two ~= "\\h",
                whitespace = true,
                sampleable = false,
            }
            i = i + 2
        else
            local start = i
            local cp, ni = utf8_next(s, i)
            i = ni
            local prev_zwj = cp == 0x200D
            while i <= n do
                local cp2, ni2 = utf8_next(s, i)
                if is_combining(cp2) or prev_zwj or cp2 == 0x200D then
                    i = ni2
                    prev_zwj = cp2 == 0x200D
                else
                    break
                end
            end
            local text = s:sub(start, i - 1)
            local ws = text:match("^%s+$") ~= nil
            out[#out + 1] = {
                text = text,
                control = false,
                whitespace = ws,
                sampleable = not ws,
            }
        end
    end
    return out
end

local function utf8_chars(s)
    local out = {}
    for _, tok in ipairs(Core.ass_tokens(s)) do out[#out + 1] = tok.text end
    return out
end
Core.utf8_chars = utf8_chars

function Core.point_to_bbox(px, py, an, w, h)
    an = tonumber(an) or 5
    w, h = tonumber(w) or 0, tonumber(h) or 0
    local ha = an % 3
    local left
    if ha == 1 then left = px elseif ha == 2 then left = px - w / 2 else left = px - w end
    local va = math.ceil(an / 3)
    local top
    if va == 3 then top = py elseif va == 2 then top = py - h / 2 else top = py - h end
    return {
        left = left, right = left + w, top = top, bottom = top + h,
        width = w, height = h, cx = left + w / 2, cy = top + h / 2,
    }
end

function Core.legacy_a_to_an(a)
    a = tonumber(a)
    local map = { [1] = 1, [2] = 2, [3] = 3, [5] = 7, [6] = 8, [7] = 9,
        [9] = 4, [10] = 5, [11] = 6 }
    return map[a]
end

local function split_runs(text)
    local runs = {}
    local pos = 1
    local s = tostring(text or "")
    local pending = ""
    while true do
        local a, b, blk = s:find("{(.-)}", pos)
        if not a then
            local rest = s:sub(pos)
            if rest ~= "" or pending ~= "" then
                runs[#runs + 1] = { tags = pending, text = rest }
            end
            break
        end
        local before = s:sub(pos, a - 1)
        if before ~= "" then
            runs[#runs + 1] = { tags = pending, text = before }
            pending = ""
        end
        pending = pending == "" and blk or (pending .. blk)
        pos = b + 1
    end
    if #runs == 0 then runs[1] = { tags = "", text = s } end
    return runs
end
Core.split_runs = split_runs

local function parse_tags(s)
    local out = {}
    s = tostring(s or "")
    local i, n = 1, #s
    while i <= n do
        if s:sub(i, i) ~= "\\" then
            i = i + 1
        else
            local tail = s:sub(i + 1)
            local lower = tail:lower()
            local name
            if lower:sub(1, 2) == "fn" then
                name = tail:sub(1, 2)
            elseif lower:sub(1, 1) == "r" then
                name = tail:sub(1, 1)
            else
                name = s:match("^\\([%d]?[%a]+)", i)
            end
            if not name then
                i = i + 1
            else
                local j = i + 1 + #name
                local tag = { name = name, lname = name:lower() }
                if s:sub(j, j) == "(" then
                    local blk = s:match("^%b()", j)
                    if blk then
                        tag.args = blk:sub(2, -2)
                        i = j + #blk
                    else
                        tag.args = s:sub(j + 1)
                        i = n + 1
                    end
                else
                    local val = s:match("^[^\\{}]*", j) or ""
                    tag.val = val
                    i = j + #val
                end
                out[#out + 1] = tag
            end
        end
    end
    return out
end
Core.parse_tags = parse_tags

local function parse_nums(a)
    local nums = {}
    for num in tostring(a or ""):gmatch("[+-]?%d*%.?%d+") do
        local v = tonumber(num)
        if v then nums[#nums + 1] = v end
    end
    return nums
end
Core.parse_nums = parse_nums

local function parse_strict_numbers(a)
    a = trim(a)
    if a == "" then return nil end
    local nums, cursor = {}, 1
    while true do
        local comma = a:find(",", cursor, true)
        local piece = trim(a:sub(cursor, comma and comma - 1 or #a))
        if not piece:match("^[+-]?%d*%.?%d+$") then return nil end
        local value = tonumber(piece)
        if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
        nums[#nums + 1] = value
        if not comma then break end
        cursor = comma + 1
        if cursor > #a then return nil end
    end
    return nums
end

local function parse_pair(a)
    local n = parse_strict_numbers(a)
    if not n or #n ~= 2 then return nil end
    return n[1], n[2]
end
Core.parse_pair = parse_pair

local function parse_t_args(a)
    a = tostring(a or "")
    local nums, rest = {}, a
    while #nums < 3 do
        local num, r = rest:match("^%s*([+-]?%d*%.?%d+)%s*,%s*(.*)$")
        if not num or num == "" or num == "." or num == "+." or num == "-." then break end
        nums[#nums + 1] = tonumber(num)
        rest = r
    end
    local t1, t2, accel
    if #nums >= 2 then t1, t2 = nums[1], nums[2] end
    if #nums == 1 then accel = nums[1] end
    if #nums == 3 then accel = nums[3] end
    return t1, t2, accel, rest
end
Core.parse_t_args = parse_t_args

local function parse_move_args(a)
    local n = parse_strict_numbers(a)
    if not n or (#n ~= 4 and #n ~= 6) then return nil end
    return { x1 = n[1], y1 = n[2], x2 = n[3], y2 = n[4], t1 = n[5], t2 = n[6] }
end
Core.parse_move_args = parse_move_args

local function color_rgb(v)
    local hex = tostring(v or ""):match("[Hh](%x+)")
    if not hex then return nil end
    hex = hex:sub(-6)
    while #hex < 6 do hex = "0" .. hex end
    local num = tonumber(hex, 16) or 0
    return num % 256, floor(num / 256) % 256, floor(num / 65536) % 256
end

local function color_str(r, g, b)
    local function cl(x) return max(0, min(255, floor(x + 0.5))) end
    return string.format("&H%02X%02X%02X&", cl(b), cl(g), cl(r))
end
Core.color_rgb, Core.color_str = color_rgb, color_str

local function alpha_byte(v)
    local hex = tostring(v or ""):match("[Hh](%x+)")
    if hex then return tonumber(hex:sub(-2), 16) end
    return tonumber(v)
end

local function alpha_str(v)
    return string.format("&H%02X&", max(0, min(255, floor((v or 0) + 0.5))))
end

local function lerp(a, b, t) return a + (b - a) * t end

local function axis_map(g1, g2, s1, s2)
    return function(v)
        v = tonumber(v) or 0
        if g2 <= g1 then return s1 + (v - g1) end
        if v < g1 then return s1 + (v - g1) end
        if v > g2 then return s2 + (v - g2) end
        return s1 + (v - g1) / (g2 - g1) * (s2 - s1)
    end
end
Core.axis_map = axis_map

local function map_drawing(draw, mx, my)
    local idx = 0
    return (tostring(draw or ""):gsub("%S+", function(tok)
        local num = tonumber(tok)
        if num then
            idx = idx + 1
            if idx % 2 == 1 then return fmt_num(mx(num)) end
            return fmt_num(my(num))
        end
        idx = 0
        return tok
    end))
end
Core.map_drawing = map_drawing

function Core.map_clip_args(args, mx, my)
    local a = tostring(args or "")
    local nums = parse_nums(a)
    if not a:lower():find("[mnlbspc]") and #nums == 4 then
        return table.concat({ fmt_num(mx(nums[1])), fmt_num(my(nums[2])),
            fmt_num(mx(nums[3])), fmt_num(my(nums[4])) }, ",")
    end
    local scale, drawing = a:match("^%s*(%d+)%s*,%s*(.*)$")
    if scale and drawing and drawing:lower():find("[mnlbspc]") then
        local sf = 2 ^ (max(1, tonumber(scale) or 1) - 1)
        local function smx(v) return mx((tonumber(v) or 0) / sf) * sf end
        local function smy(v) return my((tonumber(v) or 0) / sf) * sf end
        return scale .. "," .. map_drawing(drawing, smx, smy)
    end
    return map_drawing(a, mx, my)
end

function Core.drawing_bbox(draw, p)
    local scale = 2 ^ ((tonumber(p) or 1) - 1)
    local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
    local idx = 0
    for tok in tostring(draw or ""):gmatch("%S+") do
        local num = tonumber(tok)
        if num then
            idx = idx + 1
            num = num / scale
            if idx % 2 == 1 then
                if num < x1 then x1 = num end
                if num > x2 then x2 = num end
            else
                if num < y1 then y1 = num end
                if num > y2 then y2 = num end
            end
        else
            idx = 0
        end
    end
    if x1 == math.huge then return nil end
    return { left = x1, top = y1, right = x2, bottom = y2,
        width = x2 - x1, height = y2 - y1 }
end

local VALID_ORDERS = { ltr = true, rtl = true, center = true, edges = true }
local VALID_INHERIT = { static = true, none = true }

local function parse_nonneg(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return max(0, n)
end

function Core.parse_flags(actor)
    local flags = {
        unit = "syl",
        nobase = false,
        nofade = false,
        nostagger = false,
        stagger_ms = nil,
        fade_ms = nil,
        lead_ms = nil,
        tail_ms = nil,
        respiro_ms = nil,
        order = CONFIG.default_order,
        group = nil,
        channel = nil,
        inherit = CONFIG.inherit_target_tags and "static" or "none",
        explicit = {},
        unknown = {},
    }
    local seen_any = false
    local normalized = tostring(actor or ""):gsub(";", " ")
    for raw in normalized:gmatch("%S+") do
        local tok = raw:lower()
        local key, val = tok:match("^([%a_]+)=(.+)$")
        if tok == "char" or tok == "grapheme" then flags.unit = "char"; flags.explicit.unit = true; seen_any = true
        elseif tok == "syl" or tok == "syllable" then flags.unit = "syl"; flags.explicit.unit = true; seen_any = true
        elseif tok == "word" then flags.unit = "word"; flags.explicit.unit = true; seen_any = true
        elseif tok == "line" then flags.unit = "line"; flags.explicit.unit = true; seen_any = true
        elseif tok == "nobase" then
            flags.nobase, flags.nofade, flags.nostagger = true, true, true
            seen_any = true
        elseif tok == "nofade" then flags.nofade = true; seen_any = true
        elseif tok == "nostagger" then flags.nostagger = true; seen_any = true
        elseif tok == "base" then
            flags.nobase, flags.nofade, flags.nostagger = false, false, false
            seen_any = true
        elseif tok == "reverse" or tok == "rtl" then flags.order = "rtl"; flags.explicit.order = true; seen_any = true
        elseif tok == "ltr" then flags.order = "ltr"; flags.explicit.order = true; seen_any = true
        elseif tok == "center" then flags.order = "center"; flags.explicit.order = true; seen_any = true
        elseif tok == "edges" then flags.order = "edges"; flags.explicit.order = true; seen_any = true
        elseif key == "stagger" then
            flags.stagger_ms = parse_nonneg(val)
            if flags.stagger_ms ~= nil then flags.explicit.stagger_ms = true; seen_any = true else flags.unknown[#flags.unknown + 1] = raw end
        elseif key == "fade" then
            flags.fade_ms = parse_nonneg(val)
            if flags.fade_ms ~= nil then flags.explicit.fade_ms = true; seen_any = true else flags.unknown[#flags.unknown + 1] = raw end
        elseif key == "lead" then
            flags.lead_ms = parse_nonneg(val)
            if flags.lead_ms ~= nil then flags.explicit.lead_ms = true; seen_any = true else flags.unknown[#flags.unknown + 1] = raw end
        elseif key == "tail" then
            flags.tail_ms = parse_nonneg(val)
            if flags.tail_ms ~= nil then flags.explicit.tail_ms = true; seen_any = true else flags.unknown[#flags.unknown + 1] = raw end
        elseif key == "gap" or key == "respiro" then
            flags.respiro_ms = parse_nonneg(val)
            if flags.respiro_ms ~= nil then flags.explicit.respiro_ms = true; seen_any = true else flags.unknown[#flags.unknown + 1] = raw end
        elseif key == "order" and VALID_ORDERS[val] then flags.order = val; flags.explicit.order = true; seen_any = true
        elseif key == "group" and val ~= "" then flags.group = val; flags.explicit.group = true; seen_any = true
        elseif key == "channel" and val ~= "" then flags.channel = val; flags.explicit.channel = true; seen_any = true
        elseif key == "inherit" and VALID_INHERIT[val] then flags.inherit = val; flags.explicit.inherit = true; seen_any = true
        elseif tok:match("^akfx:") then
            local inner = tok:sub(6)
            local ik, iv = inner:match("^([%a_]+)=(.+)$")
            if ik == "channel" and iv ~= "" then flags.channel = iv; flags.explicit.channel = true; seen_any = true
            elseif ik == "group" and iv ~= "" then flags.group = iv; flags.explicit.group = true; seen_any = true
            elseif ik == "inherit" and VALID_INHERIT[iv] then flags.inherit = iv; flags.explicit.inherit = true; seen_any = true
            else flags.unknown[#flags.unknown + 1] = raw end
        elseif key or tok == "nobase" or tok == "nofade" or tok == "nostagger" then
            flags.unknown[#flags.unknown + 1] = raw
        end
    end
    flags.has_options = seen_any
    return flags
end

function Core.order_rank(i, n, order)
    order = VALID_ORDERS[order] and order or "ltr"
    if order == "rtl" then return n - i end
    if order == "center" then return floor(abs(i - (n + 1) / 2)) end
    if order == "edges" then return min(i - 1, n - i) end
    return i - 1
end

function Core.order_max_rank(n, order)
    n = max(1, tonumber(n) or 1)
    order = VALID_ORDERS[order] and order or "ltr"
    if order == "center" or order == "edges" then return floor((n - 1) / 2) end
    return n - 1
end

local LINE_WIDE = {
    pos = true, move = true, org = true, an = true, a = true,
}
local NON_SAMPLE_TAG = {
    pos = true, move = true, org = true, an = true, a = true,
    p = true, k = true, kf = true, ko = true, kt = true,
}

local ALPHA_TAG = { alpha = true, ["1a"] = true, ["2a"] = true, ["3a"] = true, ["4a"] = true }
local COLOR_TAG = { c = true, ["1c"] = true, ["2c"] = true, ["3c"] = true, ["4c"] = true }

local function tag_has_alpha(tag)
    local name = tag.lname or tostring(tag.name or ""):lower()
    if ALPHA_TAG[name] or name == "fad" or name == "fade" then return true end
    if name == "t" then
        local body = tostring(tag.args or ""):lower()
        return body:find("\\alpha", 1, true) ~= nil
            or body:find("\\1a", 1, true) ~= nil
            or body:find("\\2a", 1, true) ~= nil
            or body:find("\\3a", 1, true) ~= nil
            or body:find("\\4a", 1, true) ~= nil
    end
    return false
end

function Core.parse_guide(effect, layer, text, geom, actor)
    local runs = split_runs(text)
    for _, r in ipairs(runs) do r.taglist = parse_tags(r.tags or "") end
    local flags = Core.parse_flags(actor)
    local guide = {
        phase = effect,
        layer = layer or 0,
        geom = geom,
        unit = flags.unit,
        nobase = flags.nobase,
        nofade = flags.nofade,
        nostagger = flags.nostagger,
        flags = flags,
        runs = runs,
        move = nil,
        org = nil,
        header = {},
        has_alpha_anim = false,
        is_drawing = false,
        warnings = {},
    }

    for ri, run in ipairs(runs) do
        for _, tag in ipairs(run.taglist) do
            local name = tag.lname
            if ri == 1 then
                if name == "move" then
                    guide.move = guide.move or parse_move_args(tag.args)
                elseif name == "org" then
                    local x, y = parse_pair(tag.args)
                    if x then guide.org = { x = x, y = y } end
                elseif not LINE_WIDE[name] then
                    guide.header[#guide.header + 1] = tag
                end
            end
            if name == "p" and (tonumber(tag.val) or 0) > 0 then guide.is_drawing = true end
            if name == "fad" or name == "fade" or (name == "t" and tag_has_alpha(tag)) then
                guide.has_alpha_anim = true
            end
        end
    end
    if guide.move == nil then
        for ri = 2, #runs do
            for _, tag in ipairs(runs[ri].taglist) do
                if tag.lname == "move" then
                    guide.warnings[#guide.warnings + 1] = "\\move debe estar en el primer bloque de tags; se ignoro uno posterior."
                end
            end
        end
    end
    guide.samples = guide.is_drawing and nil or Core.build_samples(runs)
    return guide
end

local function copy_state(state)
    local out = {}
    for k, v in pairs(state) do out[k] = v end
    return out
end

function Core.build_samples(runs)
    if #runs < 2 then return nil end
    local snapshots, state = {}, {}
    local total = 0
    for ri, r in ipairs(runs) do
        local fns = {}
        for _, tag in ipairs(r.taglist or {}) do
            local name = tag.lname or tostring(tag.name or ""):lower()
            if name == "r" then
                state = {}
                if ri > 1 then fns[#fns + 1] = tag end
            elseif tag.val ~= nil and not NON_SAMPLE_TAG[name] then
                state[name] = tag.val
            elseif tag.args ~= nil and ri > 1 and not NON_SAMPLE_TAG[name] then
                fns[#fns + 1] = tag
            end
        end
        local tokens = Core.ass_tokens(r.text or "")
        local count = 0
        for _, tok in ipairs(tokens) do if tok.sampleable then count = count + 1 end end
        if count > 0 then
            snapshots[#snapshots + 1] = {
                first = total,
                count = count,
                vals = copy_state(state),
                fns = fns,
            }
            total = total + count
        end
    end
    if #snapshots < 2 or total < 2 then return nil end

    local union = {}
    local any_fns = false
    for _, s in ipairs(snapshots) do
        if #s.fns > 0 then any_fns = true end
        for k in pairs(s.vals) do union[k] = true end
    end
    local props = {}
    local NIL = {}
    for prop in pairs(union) do
        local first = snapshots[1].vals[prop]
        if first == nil then first = NIL end
        local varies = false
        for i = 2, #snapshots do
            local v = snapshots[i].vals[prop]
            if v == nil then v = NIL end
            if v ~= first then varies = true; break end
        end
        if varies then props[#props + 1] = prop end
    end
    if #props == 0 and not any_fns then return nil end
    table.sort(props)

    local list = {}
    for _, s in ipairs(snapshots) do
        local vals = {}
        for _, p in ipairs(props) do vals[p] = s.vals[p] end
        list[#list + 1] = {
            u = (s.first + s.count / 2) / total,
            vals = vals,
            fns = s.fns,
        }
    end
    return { props = props, list = list }
end

local CONTINUOUS_NUMERIC = {
    fs = true, fscx = true, fscy = true, fsp = true,
    fr = true, frx = true, fry = true, frz = true,
    fax = true, fay = true, bord = true, xbord = true, ybord = true,
    shad = true, xshad = true, yshad = true, blur = true, be = true,
    pbo = true,
}

function Core.sample_prop(samples, prop, u)
    local list = samples.list
    if u <= list[1].u then return list[1].vals[prop] end
    if u >= list[#list].u then return list[#list].vals[prop] end
    for i = 1, #list - 1 do
        local a, b = list[i], list[i + 1]
        if u >= a.u and u <= b.u then
            local t = (b.u - a.u) > 0 and (u - a.u) / (b.u - a.u) or 0
            local va, vb = a.vals[prop], b.vals[prop]
            if va == nil or vb == nil then
                if t < 0.5 then return va end
                return vb
            end
            if COLOR_TAG[prop] then
                local r1, g1, b1 = color_rgb(va)
                local r2, g2, b2 = color_rgb(vb)
                if r1 and r2 then
                    return color_str(lerp(r1, r2, t), lerp(g1, g2, t), lerp(b1, b2, t))
                end
            end
            if ALPHA_TAG[prop] then
                local a1, a2 = alpha_byte(va), alpha_byte(vb)
                if a1 and a2 then return alpha_str(lerp(a1, a2, t)) end
            end
            local n1, n2 = tonumber(va), tonumber(vb)
            if n1 and n2 and CONTINUOUS_NUMERIC[prop] then return fmt_num(lerp(n1, n2, t)) end
            return t < 0.5 and va or vb
        end
    end
    return list[#list].vals[prop]
end

function Core.sample_fns(samples, u)
    local list = samples.list
    local best, dist = nil, math.huge
    for _, s in ipairs(list) do
        local d = abs(s.u - u)
        if d < dist then best, dist = s, d end
    end
    return best and best.fns or {}
end

function Core.render_event(guide, ctx)
    local g = guide.geom
    local mx = axis_map(g.left, g.right, ctx.bx1, ctx.bx2)
    local my = axis_map(g.top, g.bottom, ctx.by1, ctx.by2)
    local p_dur = max(1, tonumber(ctx.p_dur) or 1)
    local t_dur = max(1, tonumber(ctx.t_dur) or p_dur)
    local t_off = max(0, tonumber(ctx.t_off) or 0)
    local ratio = t_dur / max(1, tonumber(g.dur) or 1)

    local function scale_time(t)
        local v = round((tonumber(t) or 0) * ratio) + t_off
        return clamp(v, 0, p_dur)
    end

    local transform_list
    transform_list = function(list, inside_t)
        local out = {}
        for _, tag in ipairs(list or {}) do
            local name = tag.lname or tostring(tag.name or ""):lower()
            if name == "clip" or name == "iclip" then
                out[#out + 1] = "\\" .. name .. "(" .. Core.map_clip_args(tag.args, mx, my) .. ")"
            elseif name == "t" and not inside_t then
                local t1, t2, accel, body = parse_t_args(tag.args)
                local inner = transform_list(parse_tags(body), true)
                local head = ""
                if t1 and t2 then
                    local s1, s2 = scale_time(t1), scale_time(t2)
                    if s2 <= s1 then s2 = min(p_dur, s1 + 1) end
                    if s2 <= s1 then s1 = max(0, s2 - 1) end
                    head = round(s1) .. "," .. round(s2) .. ","
                elseif t_off > 0 or t_dur ~= p_dur then
                    local s1 = clamp(t_off, 0, p_dur)
                    local s2 = clamp(t_off + t_dur, 0, p_dur)
                    if s2 <= s1 then s2 = min(p_dur, s1 + 1) end
                    if s2 <= s1 then s1 = max(0, s2 - 1) end
                    head = round(s1) .. "," .. round(s2) .. ","
                end
                if accel and accel ~= 1 then head = head .. fmt_num(accel) .. "," end
                out[#out + 1] = "\\t(" .. head .. table.concat(inner) .. ")"
            elseif name == "fad" then
                local nums = parse_nums(tag.args)
                local fa = max(0, round((nums[1] or 0) * ratio))
                local fb = max(0, round((nums[2] or 0) * ratio))
                if fa + fb > p_dur then
                    local k = p_dur / max(1, fa + fb)
                    fa, fb = round(fa * k), round(fb * k)
                end
                out[#out + 1] = "\\fad(" .. fa .. "," .. fb .. ")"
            elseif name == "fade" then
                local nums = parse_nums(tag.args)
                if #nums >= 7 then
                    local times = {}
                    for i = 4, 7 do times[#times + 1] = scale_time(nums[i]) end
                    for i = 2, #times do if times[i] < times[i - 1] then times[i] = times[i - 1] end end
                    out[#out + 1] = string.format("\\fade(%d,%d,%d,%d,%d,%d,%d)",
                        clamp(round(nums[1]), 0, 255), clamp(round(nums[2]), 0, 255),
                        clamp(round(nums[3]), 0, 255), round(times[1]), round(times[2]),
                        round(times[3]), round(times[4]))
                end
            elseif LINE_WIDE[name] or name == "p" or name == "k" or name == "kf"
                or name == "ko" or name == "kt" then
            else
                if tag.args ~= nil then
                    out[#out + 1] = "\\" .. name .. "(" .. tostring(tag.args or "") .. ")"
                else
                    out[#out + 1] = "\\" .. name .. tostring(tag.val or "")
                end
            end
        end
        return out
    end

    local anchor
    if guide.move then
        local m = guide.move
        local rx, ry
        if guide.phase == "intro" then rx, ry = m.x2, m.y2 else rx, ry = m.x1, m.y1 end
        local d1x, d1y = m.x1 - rx, m.y1 - ry
        local d2x, d2y = m.x2 - rx, m.y2 - ry
        local times = ""
        if m.t1 and m.t2 then
            local s1, s2 = scale_time(m.t1), scale_time(m.t2)
            if s2 <= s1 then s2 = min(p_dur, s1 + 1) end
            if s2 <= s1 then s1 = max(0, s2 - 1) end
            times = "," .. round(s1) .. "," .. round(s2)
        end
        anchor = string.format("\\move(%s,%s,%s,%s%s)",
            fmt_num(ctx.ax + d1x), fmt_num(ctx.ay + d1y),
            fmt_num(ctx.ax + d2x), fmt_num(ctx.ay + d2y), times)
    else
        anchor = "\\pos(" .. fmt_num(ctx.ax) .. "," .. fmt_num(ctx.ay) .. ")"
    end

    local org = ""
    if guide.org then
        org = "\\org(" .. fmt_num(mx(guide.org.x)) .. "," .. fmt_num(my(guide.org.y)) .. ")"
    end

    local sampled = {}
    if guide.samples then
        for _, p in ipairs(guide.samples.props) do sampled[p] = true end
    end
    local statics, dynamics = {}, {}
    for _, tag in ipairs(guide.header) do
        local name = tag.lname or tostring(tag.name or ""):lower()
        if name == "t" or name == "fad" or name == "fade" then
            dynamics[#dynamics + 1] = tag
        elseif not sampled[name] then
            statics[#statics + 1] = tag
        end
    end

    local inherit = tostring(ctx.inherit_tags or "")
    local head = "\\an5" .. anchor .. org .. inherit .. table.concat(transform_list(statics))

    local base_fade = ""
    if ctx.base_fade and not guide.has_alpha_anim and not guide.nofade then
        local bf = ctx.base_fade
        local t1 = clamp(round(bf.t1 or 0), 0, p_dur)
        local t2 = clamp(round(bf.t2 or p_dur), 0, p_dur)
        if t2 <= t1 then t2 = min(p_dur, t1 + 1) end
        if t2 <= t1 then t1 = max(0, t2 - 1) end
        if bf.dir == "in" then
            base_fade = string.format("\\fade(255,0,0,%d,%d,%d,%d)", t1, t2, p_dur, p_dur)
        else
            base_fade = string.format("\\fade(0,0,255,0,0,%d,%d)", t1, t2)
        end
    end

    head = head .. table.concat(transform_list(dynamics)) .. base_fade

    local body
    local tokens = ctx.tokens or Core.ass_tokens(ctx.text or "")
    if guide.samples and not ctx.is_drawing then
        local sample_count = 0
        for _, tok in ipairs(tokens) do if tok.sampleable then sample_count = sample_count + 1 end end
        if sample_count > 0 then
            local parts, si = {}, 0
            for _, tok in ipairs(tokens) do
                if tok.sampleable then
                    si = si + 1
                    local u = sample_count > 1 and (si - 0.5) / sample_count or 0.5
                    local blk = {}
                    for _, p in ipairs(guide.samples.props) do
                        local v = Core.sample_prop(guide.samples, p, u)
                        if v ~= nil then blk[#blk + 1] = "\\" .. p .. tostring(v) end
                    end
                    for _, part in ipairs(transform_list(Core.sample_fns(guide.samples, u))) do
                        blk[#blk + 1] = part
                    end
                    if #blk > 0 then parts[#parts + 1] = "{" .. table.concat(blk) .. "}" end
                    parts[#parts + 1] = tok.text
                else
                    parts[#parts + 1] = tok.text
                end
            end
            body = table.concat(parts)
        else
            body = ctx.text or ""
        end
    else
        body = ctx.text or ""
    end

    return "{" .. head .. "}" .. body
end

local function show_message(msg)
    if aegisub and aegisub.log then pcall(aegisub.log, script_name .. ": " .. tostring(msg) .. "\n") end
end

local function show_report(title, text)
    text = tostring(text or "")
    if aegisub and aegisub.dialog and aegisub.dialog.display then
        pcall(aegisub.dialog.display, {
            { class = "label", label = tostring(title or script_name), x = 0, y = 0, width = 1, height = 1 },
            { class = "textbox", name = "report", text = text, x = 0, y = 1, width = 1, height = 16 },
        }, { "Cerrar" }, { close = "Cerrar" })
    else
        show_message((title or "Informe") .. "\n" .. text)
    end
end

local HELP_TEXT = table.concat({
    "COMANDOS DEL MENU",
    "",
    "Aplicar: compila las guias intro/active/outro sobre los targets seleccionados.",
    "Generar lineas base: crea guias editables desde los targets.",
    "Validar seleccion: diagnostica guias, targets, huecos y cantidad de eventos sin modificar.",
    "Limpiar FX seleccionados: elimina el FX asociado y restaura los targets originales.",
    "Configurar: cambia los valores predeterminados de la sesion.",
    "Ayuda y comandos: muestra este resumen.",
    "",
    "OPCIONES DEL CAMPO ACTOR",
    "",
    "Unidades: char | grapheme | syl | syllable | word | line",
    "Control: nobase | nofade | nostagger | base",
    "Tiempos (ms): lead= | tail= | fade= | stagger= | gap= | respiro=",
    "Orden: order=ltr|rtl|center|edges (tambien ltr, rtl, reverse, center o edges)",
    "Agrupacion: group=nombre",
    "Canal de huecos: channel=nombre (tambien akfx:channel=nombre)",
    "Herencia: inherit=static|none (tambien akfx:inherit=static|none)",
    "Alias de grupo: akfx:group=nombre",
    "",
    "Las opciones de la guia tienen prioridad sobre las del target; las del target, sobre Configurar.",
    "Ejemplo: char fade=240 stagger=50 order=edges group=borde inherit=none",
}, "\n")

local function show_help()
    show_report(script_name .. " - ayuda y comandos", HELP_TEXT)
end

local function copy_line(line)
    local out = {}
    for k, v in pairs(line or {}) do out[k] = v end
    return out
end

local function visible_text(text)
    if LineOps then return LineOps.visibleText(text) end
    return (tostring(text or ""):gsub("{[^}]*}", "")):gsub("\\[Nnh]", " ")
end

local function drawing_text(text)
    if LineOps then return LineOps.analyzeText(text).drawing end
    return tostring(text or ""):gsub("{[^}]*}", "")
end

local PHASES = { intro = true, active = true, outro = true }
local SOURCE_EXTRA_KEY = "_aegi_alecto_kfx_source"

local function line_phase(line)
    local e = trim(line and line.effect or ""):lower()
    if PHASES[e] then return e end
    return nil
end

local function is_fx_line(line)
    if not line or line.class ~= "dialogue" then return false end
    local e = trim(line.effect or ""):lower()
    return e == CONFIG.fx_marker or e:sub(1, #CONFIG.fx_marker + 1) == CONFIG.fx_marker .. ":"
end

local function clone_extra(extra)
    local out = {}
    if type(extra) == "table" then
        for k, v in pairs(extra) do out[k] = v end
    end
    return out
end

local function parse_source_record(line)
    local raw = type(line and line.extra) == "table" and line.extra[SOURCE_EXTRA_KEY] or nil
    local uid, bit
    if type(raw) == "string" then uid, bit = raw:match("^v1:([^:]+):c([01])$") end
    if not uid then return nil end
    return uid, bit == "1"
end

local function encode_source_record(uid, original_comment)
    return "v1:" .. tostring(uid) .. ":c" .. (original_comment and "1" or "0")
end

local function parse_fx_marker(line)
    if not is_fx_line(line) then return nil end
    local effect = trim(line.effect or "")
    local payload = effect:sub(#CONFIG.fx_marker + 2)
    if effect == CONFIG.fx_marker then return { version = 0 } end
    local uid, key, phase, bit = payload:match("^([^:]+):(%x+):([^:]+):c([01])$")
    if uid and not uid:sub(1, 1):match("%x") then
        return {
            version = 2,
            uid = uid,
            key = key,
            phase = phase,
            original_comment = bit == "1",
        }
    end
    key, phase, bit = payload:match("^(%x+):([^:]+):c([01])$")
    if key then
        return {
            version = 1,
            key = key,
            phase = phase,
            original_comment = bit == "1",
        }
    end
    key, phase = payload:match("^([^:]+):([^:]+)$")
    if key then return { version = 1, key = key, phase = phase } end
    return nil
end


local function fx_source_uid(line)
    local marker = parse_fx_marker(line)
    return marker and marker.uid or nil
end


local function has_kara(text)
    return tostring(text or ""):lower():find("\\k[fot]?%s*%d") ~= nil
end

local function first_tag_block(text)
    local runs = split_runs(text)
    return (runs[1] and runs[1].tags) or ""
end

local function pos_of(text, phase)
    local tags = parse_tags(first_tag_block(text))
    for _, tag in ipairs(tags) do
        if tag.lname == "pos" then return parse_pair(tag.args) end
    end
    for _, tag in ipairs(tags) do
        if tag.lname == "move" then
            local m = parse_move_args(tag.args)
            if m then
                if phase == "intro" then return m.x2, m.y2 end
                return m.x1, m.y1
            end
        end
    end
    return nil
end

local function line_align(line)
    local tags = parse_tags(first_tag_block(line and line.text or ""))
    for _, tag in ipairs(tags) do
        if tag.lname == "an" then
            local an = tonumber(tag.val)
            if an and an >= 1 and an <= 9 then return an end
        elseif tag.lname == "a" then
            local an = Core.legacy_a_to_an(tag.val)
            if an then return an end
        end
    end
    return (line and line.styleref and tonumber(line.styleref.align)) or 2
end

local function line_anchor(line)
    local px, py = pos_of(line.text)
    if px == nil then
        return tonumber(line.left) or 0, tonumber(line.middle) or 0
    end
    local bb = Core.point_to_bbox(px, py, line_align(line),
        tonumber(line.width) or 0, tonumber(line.height) or 0)
    return bb.left, bb.cy
end

local function channel_name(line)
    local flags = Core.parse_flags(line and line.actor or "")
    if flags.channel then return "actor:" .. flags.channel end
    local px, py = pos_of(line and line.text or "")
    local an = line_align(line)
    if px ~= nil then
        return string.format("pos:%d:%d:an%d", round(px), round(py), an)
    end
    return "auto:an" .. tostring(an)
end

local function same_channel(a, b)
    return channel_name(a) == channel_name(b)
end

local function simple_hash(s)
    local h = 5381
    s = tostring(s or "")
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
    return string.format("%08x", h)
end

local function source_key(line)
    return simple_hash(table.concat({
        tostring(round(line.start_time or 0)),
        tostring(round(line.end_time or 0)),
        tostring(line.layer or 0),
        tostring(line.style or ""),
        tostring(line.actor or ""),
        tostring(line.margin_l or 0),
        tostring(line.margin_r or 0),
        tostring(line.margin_t or line.margin_v or 0),
        tostring(line.effect or ""),
        tostring(line.text or ""),
    }, "\31"))
end

local function allocate_source_uid(line, index, used)
    local material = table.concat({
        source_key(line),
        tostring(index or 0),
        tostring(line.start_time or 0),
        tostring(line.end_time or 0),
        tostring(line.style or ""),
    }, "\31")
    local base = "u" .. simple_hash(material) .. simple_hash(material .. "\30alecto")
    local uid, suffix = base, 1
    while used[uid] do
        suffix = suffix + 1
        uid = base .. "-" .. suffix
    end
    used[uid] = true
    return uid
end

local INHERIT_EXCLUDE = {
    pos = true, move = true, org = true, an = true, a = true,
    k = true, K = true, kf = true, ko = true, kt = true,
    fad = true, fade = true, t = true, p = true,
}

local function extract_inherit_tags(text, mode)
    if mode == "none" then return "" end
    local out = {}
    for _, tag in ipairs(parse_tags(first_tag_block(text))) do
        local name = tag.lname
        if not INHERIT_EXCLUDE[name] then
            if tag.args ~= nil then out[#out + 1] = "\\" .. name .. "(" .. tostring(tag.args) .. ")"
            else out[#out + 1] = "\\" .. name .. tostring(tag.val or "") end
        end
    end
    return table.concat(out)
end

local function guide_geometry(line)
    local w = max(1, tonumber(line.width) or 1)
    local h = max(1, tonumber(line.height) or 1)
    local an = line_align(line)
    local tags = parse_tags(first_tag_block(line.text))
    local pval
    for _, tag in ipairs(tags) do
        if tag.lname == "p" and (tonumber(tag.val) or 0) > 0 then pval = tonumber(tag.val) end
    end
    if pval then
        local db = Core.drawing_bbox(drawing_text(line.text), pval)
        if db then w, h = max(1, db.width), max(1, db.height) end
    end

    local px, py = pos_of(line.text, line_phase(line))
    local bb
    if px ~= nil then
        bb = Core.point_to_bbox(px, py, an, w, h)
    else
        local left = tonumber(line.left) or 0
        local mid = tonumber(line.middle) or 0
        bb = {
            left = left, right = left + w,
            top = mid - h / 2, bottom = mid + h / 2,
            width = w, height = h, cx = left + w / 2, cy = mid,
        }
    end
    bb.dur = max(1, (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0))
    return bb
end

local function token_render_text(tok)
    if tok.text == "\\h" then return " " end
    if tok.control then return "" end
    return tok.text
end

local function char_boxes(styleref, text, total_width)
    local tokens = Core.ass_tokens(text)
    local widths, sum = {}, 0
    for i, tok in ipairs(tokens) do
        local sample = token_render_text(tok)
        local w = 0
        if sample ~= "" then
            if aegisub and aegisub.text_extents and styleref then
                local ok, ww = pcall(aegisub.text_extents, styleref, sample)
                if ok and tonumber(ww) and ww >= 0 then w = tonumber(ww) end
            end
            if w <= 0 then
                if tok.whitespace then w = CONFIG.fallback_space_width else w = CONFIG.fallback_char_width end
            end
        end
        widths[i] = w
        sum = sum + w
    end
    total_width = tonumber(total_width)
    if total_width and total_width > 0 and sum > 0 then
        local k = total_width / sum
        for i = 1, #widths do widths[i] = widths[i] * k end
    elseif total_width and total_width > 0 and sum == 0 and #widths > 0 then
        local each = total_width / #widths
        for i = 1, #widths do widths[i] = each end
    end
    local out, x = {}, 0
    for i, tok in ipairs(tokens) do
        out[#out + 1] = {
            text = tok.text,
            token = tok,
            left = x,
            right = x + widths[i],
            width = widths[i],
        }
        x = x + widths[i]
    end
    return out
end

local function fallback_kara_syls(line)
    local segments, cursor = {}, 0
    local runs = split_runs(line.text)
    for _, run in ipairs(runs) do
        local start_override, dur
        for _, tag in ipairs(parse_tags(run.tags)) do
            if tag.lname == "kt" then start_override = (tonumber(tag.val) or 0) * 10
            elseif tag.lname == "k" or tag.lname == "kf" or tag.lname == "ko" then
                dur = (tonumber(tag.val) or 0) * 10
            end
        end
        if start_override then cursor = start_override end
        local text = tostring(run.text or "")
        if text ~= "" then
            local d = max(0, dur or 0)
            segments[#segments + 1] = {
                text = text,
                start_rel = cursor,
                end_rel = cursor + d,
            }
            cursor = cursor + d
        elseif dur then
            cursor = cursor + max(0, dur)
        end
    end
    if #segments == 0 then return {} end
    local total_width = max(1, tonumber(line.width) or 1)
    local raw_widths, sum = {}, 0
    for i, s in ipairs(segments) do
        local w = 0
        for _, b in ipairs(char_boxes(line.styleref, s.text)) do w = w + b.width end
        raw_widths[i] = w
        sum = sum + w
    end
    local x = 0
    for i, s in ipairs(segments) do
        local w = sum > 0 and raw_widths[i] / sum * total_width or total_width / #segments
        s.left_rel, s.right_rel = x, x + w
        x = x + w
    end
    return segments
end

local function collect_syls(line)
    if tostring(line.text or ""):lower():find("\\kt%s*%d") then
        return fallback_kara_syls(line)
    end
    local raw = {}
    local kara = line.kara
    if type(kara) ~= "table" then return fallback_kara_syls(line) end
    local last = tonumber(kara.n) or #kara
    for i = 0, last do
        local syl = kara[i]
        if syl then
            local text = tostring(syl.text_stripped or "")
            if text ~= "" then
                raw[#raw + 1] = {
                    text = text,
                    start_rel = tonumber(syl.start_time) or 0,
                    end_rel = tonumber(syl.end_time) or 0,
                    left_rel = tonumber(syl.left) or 0,
                    right_rel = tonumber(syl.right) or 0,
                }
            end
        end
    end

    local out, pending = {}, nil
    for _, s in ipairs(raw) do
        if s.end_rel > s.start_rel then
            if pending then
                s.text = pending.text .. s.text
                s.left_rel = min(pending.left_rel, s.left_rel)
                pending = nil
            end
            out[#out + 1] = s
        else
            if pending then
                pending.text = pending.text .. s.text
                pending.right_rel = max(pending.right_rel, s.right_rel)
            else
                pending = shallow_copy(s)
            end
        end
    end
    if pending and #out > 0 then
        local last_out = out[#out]
        last_out.text = last_out.text .. pending.text
        last_out.right_rel = max(last_out.right_rel, pending.right_rel)
    elseif pending then
        pending.end_rel = pending.start_rel + max(1, (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0))
        out[1] = pending
    end
    return out
end

local function append_text(a, b)
    if a == nil or a == "" then return tostring(b or "") end
    return a .. tostring(b or "")
end

local function build_units(line, syls, unit, styleref)
    if #syls == 0 then return {} end
    if unit == "syl" then
        local out = {}
        for _, s in ipairs(syls) do out[#out + 1] = shallow_copy(s) end
        return out
    end
    if unit == "line" then
        local first, last = syls[1], syls[#syls]
        local text = ""
        for _, s in ipairs(syls) do text = append_text(text, s.text) end
        return { {
            text = text,
            start_rel = first.start_rel,
            end_rel = last.end_rel,
            left_rel = first.left_rel,
            right_rel = last.right_rel,
        } }
    end
    if unit == "word" then
        local out, cur = {}, nil
        local function flush()
            if cur and trim(cur.text) ~= "" then out[#out + 1] = cur end
            cur = nil
        end
        for _, s in ipairs(syls) do
            local boxes = char_boxes(styleref, s.text, s.right_rel - s.left_rel)
            for _, b in ipairs(boxes) do
                local tok = b.token
                if tok.whitespace or tok.control then
                    flush()
                else
                    local l, r = s.left_rel + b.left, s.left_rel + b.right
                    if not cur then
                        cur = {
                            text = tok.text,
                            start_rel = s.start_rel,
                            end_rel = s.end_rel,
                            left_rel = l,
                            right_rel = r,
                        }
                    else
                        cur.text = cur.text .. tok.text
                        cur.start_rel = min(cur.start_rel, s.start_rel)
                        cur.end_rel = max(cur.end_rel, s.end_rel)
                        cur.left_rel = min(cur.left_rel, l)
                        cur.right_rel = max(cur.right_rel, r)
                    end
                end
            end
        end
        flush()
        return out
    end

    local out = {}
    for _, s in ipairs(syls) do
        local boxes = char_boxes(styleref, s.text, s.right_rel - s.left_rel)
        for _, b in ipairs(boxes) do
            if b.token.sampleable then
                out[#out + 1] = {
                    text = b.text,
                    start_rel = s.start_rel,
                    end_rel = s.end_rel,
                    left_rel = s.left_rel + b.left,
                    right_rel = s.left_rel + b.right,
                }
            end
        end
    end
    return out
end

local function scan_gaps(subs, line, source_index)
    local gp, gn = math.huge, math.huge
    for i = 1, #subs do
        local s = subs[i]
        if s.class == "dialogue" and s.style == line.style
            and not is_fx_line(s)
            and not line_phase(s)
            and same_channel(s, line)
            and ((not s.comment) or trim(s.effect or ""):lower() == "karaoke" or has_kara(s.text))
            and i ~= source_index then
            if s.end_time <= line.start_time then
                gp = min(gp, line.start_time - s.end_time)
            elseif s.start_time >= line.end_time then
                gn = min(gn, s.start_time - line.end_time)
            else
                gp, gn = 0, 0
            end
        end
    end
    return gp, gn
end

local function make_line(base, guide, start_ms, end_ms, text, key, phase)
    local s = max(0, round(start_ms))
    local e = round(end_ms)
    if e <= s then return nil end
    local l = copy_line(base)
    for _, k in ipairs({ "styleref", "kara", "text_stripped", "duration", "width", "height",
        "left", "center", "right", "top", "middle", "bottom" }) do l[k] = nil end
    l.layer = tonumber(guide.layer) or tonumber(base.layer) or 0
    l.comment = false
    l.start_time = s
    l.end_time = e
    local cbit = base._alecto_original_comment and "1" or "0"
    local uid = base._alecto_source_uid
    l.extra = clone_extra(base.extra)
    l.extra[SOURCE_EXTRA_KEY] = nil
    l._alecto_original_comment = nil
    l._alecto_source_key = nil
    l._alecto_source_uid = nil
    if uid then
        l.effect = CONFIG.fx_marker .. ":" .. tostring(uid) .. ":" .. tostring(key) .. ":" .. tostring(phase) .. ":c" .. cbit
    else
        l.effect = CONFIG.fx_marker .. ":" .. tostring(key) .. ":" .. tostring(phase) .. ":c" .. cbit
    end
    l.text = text
    return l
end

local function neutral_guide(phase, layer)
    return Core.parse_guide(phase, tonumber(layer) or 0, "", {
        left = 0, right = 1, top = 0, bottom = 1,
        width = 1, height = 1, cx = 0, cy = 0, dur = 1000,
    }, "")
end

local function resolve_ms(guide, target_flags, name, fallback)
    local gv = guide.flags and guide.flags[name]
    if gv ~= nil then return gv end
    local tv = target_flags and target_flags[name]
    if tv ~= nil then return tv end
    return fallback
end

local function guide_applies(guide, target_flags)
    local gg = guide.flags and guide.flags.group or nil
    local tg = target_flags and target_flags.group or nil
    if tg then return gg == nil or gg == tg end
    return gg == nil
end

local function target_is_drawing(line)
    for _, tag in ipairs(parse_tags(first_tag_block(line.text))) do
        if tag.lname == "p" and (tonumber(tag.val) or 0) > 0 then return true end
    end
    return false
end

local GENERATION_CANCELLED = {}
local GENERATION_LIMIT = {}

local function check_generation_cancel(control)
    if control and type(control.is_cancelled) == "function" and control.is_cancelled() then
        error(GENERATION_CANCELLED, 0)
    end
end

local function check_generation_capacity(control, count)
    local limit = control and tonumber(control.max_events)
    if limit and count >= max(0, floor(limit)) then error(GENERATION_LIMIT, 0) end
end

local function generate_for_line(line, guides, gp, gn, control)
    check_generation_cancel(control)
    if target_is_drawing(line) then
        error("Los targets vectoriales (\\p) no se compilan como texto. Usa el dibujo en un clip de guia o conviertelo en un target de texto.")
    end
    local out = {}
    local L0 = tonumber(line.start_time) or 0
    local L1 = tonumber(line.end_time) or L0
    if L1 <= L0 then return out end
    local lx, lmid = line_anchor(line)
    local lh = max(1, tonumber(line.height) or 1)
    local target_flags = Core.parse_flags(line.actor)
    local is_kara = has_kara(line.text)
    local syls
    if is_kara then
        syls = collect_syls(line)
    else
        local plain = tostring(line.text_stripped or visible_text(line.text))
        syls = { {
            text = plain,
            start_rel = 0,
            end_rel = L1 - L0,
            left_rel = 0,
            right_rel = max(1, tonumber(line.width) or 1),
        } }
    end
    if #syls == 0 then return out end

    local unit_cache = {}
    local function units_for(unit)
        if not unit_cache[unit] then unit_cache[unit] = build_units(line, syls, unit, line.styleref) end
        return unit_cache[unit]
    end

    local key = line._alecto_source_key or source_key(line)
    local function append_event(guide, phase, start_ms, end_ms, ctx)
        if end_ms <= start_ms then return end
        check_generation_cancel(control)
        check_generation_capacity(control, #out)
        ctx.p_dur = max(1, end_ms - start_ms)
        local rendered = Core.render_event(guide, ctx)
        local l = make_line(line, guide, start_ms, end_ms, rendered, key, phase)
        if l then out[#out + 1] = l end
    end

    local function emit(guide, phase)
        check_generation_cancel(control)
        if not guide_applies(guide, target_flags) then return end
        local defunit = guide.unit
        if not is_kara and defunit == "syl" then defunit = "char" end
        local units = units_for(defunit)
        local n = #units
        if n == 0 then return end

        local nofade = guide.nofade or target_flags.nofade
        local nostagger = guide.nostagger or target_flags.nostagger
        local stag = nostagger and 0 or resolve_ms(guide, target_flags, "stagger_ms", CONFIG.stagger_ms)
        local fade = resolve_ms(guide, target_flags, "fade_ms", CONFIG.fade_ms)
        local lead = resolve_ms(guide, target_flags, "lead_ms", CONFIG.lead_ms)
        local tail = resolve_ms(guide, target_flags, "tail_ms", CONFIG.tail_ms)
        local gap = resolve_ms(guide, target_flags, "respiro_ms", CONFIG.respiro_ms)
        local lead_cap = gp == math.huge and lead or gp - gap
        local tail_cap = gn == math.huge and tail or gn - gap
        local lead_eff = max(0, min(lead, lead_cap))
        local tail_eff = max(0, min(tail, tail_cap))
        local order
        if guide.flags and guide.flags.explicit and guide.flags.explicit.order then order = guide.flags.order
        elseif target_flags.explicit and target_flags.explicit.order then order = target_flags.order
        else order = CONFIG.default_order end
        local inherit_mode
        if guide.flags and guide.flags.explicit and guide.flags.explicit.inherit then inherit_mode = guide.flags.inherit
        elseif target_flags.explicit and target_flags.explicit.inherit then inherit_mode = target_flags.inherit
        else inherit_mode = CONFIG.inherit_target_tags and "static" or "none" end
        local inherit_tags = extract_inherit_tags(line.text, inherit_mode)
        local max_rank = Core.order_max_rank(n, order)

        for i, u in ipairs(units) do
            check_generation_cancel(control)
            local rank = Core.order_rank(i, n, order)
            local ax = lx + (u.left_rel + u.right_rel) / 2
            local ay = lmid
            local ctx = {
                ax = ax, ay = ay,
                bx1 = lx + u.left_rel, by1 = lmid - lh / 2,
                bx2 = lx + u.right_rel, by2 = lmid + lh / 2,
                text = u.text,
                tokens = Core.ass_tokens(u.text),
                is_drawing = false,
                inherit_tags = inherit_tags,
            }

            if is_kara then
                local S0 = clamp(L0 + (tonumber(u.start_rel) or 0), L0, L1)
                local S1 = clamp(L0 + (tonumber(u.end_rel) or 0), S0, L1)
                if phase == "intro" then
                    local start_ms = max(0, L0 - lead_eff + rank * stag)
                    if S0 - start_ms >= CONFIG.min_dur_ms then
                        ctx.t_off = 0
                        ctx.t_dur = S0 - start_ms
                        if not nofade then
                            ctx.base_fade = { dir = "in", t1 = 0, t2 = min(fade, ctx.t_dur) }
                        end
                        append_event(guide, phase, start_ms, S0, ctx)
                    end
                elseif phase == "active" then
                    ctx.t_off = 0
                    ctx.t_dur = max(1, S1 - S0)
                    append_event(guide, phase, S0, S1, ctx)
                else
                    local end_ms = L1 + tail_eff
                    local pdur = max(1, end_ms - S1)
                    local fade_end = max(1, pdur - (max_rank - rank) * stag)
                    ctx.t_off = 0
                    ctx.t_dur = pdur
                    if not nofade then
                        ctx.base_fade = { dir = "out", t1 = max(0, fade_end - fade), t2 = fade_end }
                    end
                    append_event(guide, phase, S1, end_ms, ctx)
                end
            else
                local total_end = L1 + tail_eff
                local dur = max(1, L1 - L0)
                local fade_eff = min(fade, max(CONFIG.min_dur_ms, floor(dur / 4)))
                local span = max_rank * stag
                local exitw = min(max(CONFIG.min_dur_ms, (total_end - L0) / 2), fade_eff * 2 + span)
                local split = clamp(total_end - exitw, L0, total_end - 1)
                if phase == "intro" then
                    local start_ms = max(0, L0 - lead_eff + rank * stag)
                    if split - start_ms >= CONFIG.min_dur_ms then
                        ctx.t_off = 0
                        ctx.t_dur = fade_eff
                        if not nofade then
                            ctx.base_fade = { dir = "in", t1 = 0, t2 = fade_eff }
                        end
                        append_event(guide, phase, start_ms, split, ctx)
                    end
                elseif phase == "outro" then
                    local D = max(1, total_end - split)
                    local slot = max(0, D - fade_eff - (max_rank - rank) * stag)
                    ctx.t_off = slot
                    ctx.t_dur = fade_eff
                    if not nofade then
                        ctx.base_fade = { dir = "out", t1 = slot, t2 = min(D, slot + fade_eff) }
                    end
                    append_event(guide, phase, split, total_end, ctx)
                end
            end
        end
    end

    local phase_list = is_kara and { "intro", "active", "outro" } or { "intro", "outro" }
    for _, phase in ipairs(phase_list) do
        check_generation_cancel(control)
        local set, applied = guides[phase] or {}, 0
        for _, guide in ipairs(set) do
            check_generation_cancel(control)
            if guide_applies(guide, target_flags) then emit(guide, phase); applied = applied + 1 end
        end
        if applied == 0 then emit(neutral_guide(phase, line.layer), phase) end
    end
    return out
end

local function collect_head_checked(subs)
    if not karaskel or type(karaskel.collect_head) ~= "function" then
        return nil, nil, "No se pudo cargar karaskel: " .. tostring(karaskel_load_error or "modulo incompatible")
    end
    local ok, meta, styles = pcall(karaskel.collect_head, subs, false)
    if not ok then return nil, nil, "No se pudo leer la cabecera de estilos: " .. tostring(meta) end
    return meta, styles
end

local function add_unique(list, seen, idx)
    idx = tonumber(idx)
    if idx and not seen[idx] then seen[idx] = true; list[#list + 1] = idx end
end

local function add_index(map, key, index)
    if not key then return end
    local list = map[key]
    if not list then list = {}; map[key] = list end
    list[#list + 1] = index
end

local function build_source_index(subs)
    local index = { by_uid = {}, by_key = {} }
    for i = 1, #subs do
        local l = subs[i]
        if l and l.class == "dialogue" and not is_fx_line(l) and not line_phase(l) then
            local uid = parse_source_record(l)
            add_index(index.by_uid, uid, i)
            add_index(index.by_key, source_key(l), i)
        end
    end
    return index
end

local function unique_index(map, key)
    local list = key and map[key] or nil
    if list and #list == 1 then return list[1] end
    return nil
end

local function adjacent_source_index(subs, fx_index, marker)
    local j = (tonumber(fx_index) or 0) - 1
    while j >= 1 and is_fx_line(subs[j]) do j = j - 1 end
    local source = j >= 1 and subs[j] or nil
    if source and source.class == "dialogue" and not line_phase(source) and marker then
        local source_uid = parse_source_record(source)
        if marker.uid and source_uid == marker.uid then return j end
        if not marker.uid and marker.key and marker.key == source_key(source) then return j end
        if marker.version == 0 and source.comment then return j end
    end
    return nil
end

local function resolve_selection(subs, sel)
    local guide_idx, target_idx = {}, {}
    local seen_g, seen_t = {}, {}
    local errors = {}
    local source_index = build_source_index(subs)
    for _, idx in ipairs(sel or {}) do
        local l = subs[idx]
        if l and l.class == "dialogue" then
            if line_phase(l) then
                add_unique(guide_idx, seen_g, idx)
            elseif is_fx_line(l) then
                local marker = parse_fx_marker(l)
                local src_idx = marker and unique_index(source_index.by_uid, marker.uid) or nil
                if not src_idx then src_idx = adjacent_source_index(subs, idx, marker) end
                if not src_idx and marker and not marker.uid then
                    src_idx = unique_index(source_index.by_key, marker.key)
                end
                if src_idx then add_unique(target_idx, seen_t, src_idx) end
                if not src_idx then
                    errors[#errors + 1] = "Linea " .. idx .. ": no se pudo resolver el source del FX sin ambiguedad."
                end
            else
                add_unique(target_idx, seen_t, idx)
            end
        end
    end
    table.sort(guide_idx)
    table.sort(target_idx)
    return guide_idx, target_idx, errors
end

local function discover_guides_above(subs, target_idx)
    local out, found = {}, false
    local i = (target_idx or 1) - 1
    while i >= 1 do
        local l = subs[i]
        if l and l.class == "dialogue" then
            if is_fx_line(l) then
            elseif line_phase(l) then
                out[#out + 1] = i
                found = true
            elseif found then
                break
            else
                break
            end
        end
        i = i - 1
    end
    table.sort(out)
    return out
end

local function preprocess_copy(subs, meta, styles, idx)
    local src = copy_line(subs[idx])
    src.comment = false
    local ok, err = pcall(karaskel.preproc_line, subs, meta, styles, src)
    if not ok then return nil, tostring(err) end
    return src
end

local function compile_guides(subs, meta, styles, guide_idx)
    local guides = { intro = {}, active = {}, outro = {} }
    local warnings, errors = {}, {}
    for _, idx in ipairs(guide_idx) do
        local src, err = preprocess_copy(subs, meta, styles, idx)
        if not src then
            errors[#errors + 1] = "Guia en linea " .. idx .. ": " .. tostring(err)
        else
            local phase = line_phase(src)
            local geom = guide_geometry(src)
            local g = Core.parse_guide(phase, tonumber(src.layer) or 0, src.text, geom, src.actor)
            g.source_index = idx
            guides[phase][#guides[phase] + 1] = g
            for _, w in ipairs(g.warnings or {}) do
                warnings[#warnings + 1] = "Guia " .. idx .. " (" .. phase .. "): " .. w
            end
            for _, tok in ipairs(g.flags.unknown or {}) do
                warnings[#warnings + 1] = "Guia " .. idx .. ": flag desconocido '" .. tok .. "'."
            end
            if g.is_drawing then
                warnings[#warnings + 1] = "Guia " .. idx .. ": \\p se usa solo para calcular geometria; el cuerpo vectorial no sustituye el texto target."
            end
        end
    end
    return guides, warnings, errors
end

local function progress_is_cancelled()
    if not aegisub or not aegisub.progress or type(aegisub.progress.is_cancelled) ~= "function" then return false end
    local ok, cancelled = pcall(aegisub.progress.is_cancelled)
    return ok and cancelled and true or false
end

local function progress_cancelled(done, total, label)
    if not aegisub or not aegisub.progress then return false end
    if aegisub.progress.set then pcall(aegisub.progress.set, total > 0 and done / total * 100 or 0) end
    if aegisub.progress.task then pcall(aegisub.progress.task, script_name .. ": " .. tostring(label or "") .. " " .. done .. "/" .. total) end
    return progress_is_cancelled()
end

local function adjacent_fx_marker(subs, index)
    local source = subs[index]
    local source_uid = parse_source_record(source)
    local key = source_key(source)
    local j = (tonumber(index) or 0) + 1
    while j <= #subs and is_fx_line(subs[j]) do
        local marker = parse_fx_marker(subs[j])
        if marker and marker.uid then
            if (source_uid and marker.uid == source_uid)
                or (not source_uid and marker.key == key) then
                return marker
            end
        elseif marker and marker.version == 0 then
            if source.comment then return marker end
        elseif marker and (marker.key == key or source.comment) then
            return marker
        end
        j = j + 1
    end
    return nil
end

local function collect_used_uids(subs)
    local used = {}
    for i = 1, #subs do
        local source_uid = parse_source_record(subs[i])
        local output_uid = fx_source_uid(subs[i])
        if source_uid then used[source_uid] = true end
        if output_uid then used[output_uid] = true end
    end
    return used
end

local function build_identity_plan(subs, index, source_index, used, reserved)
    local source = subs[index]
    local key = source_key(source)
    local stored_uid, stored_comment = parse_source_record(source)
    local marker = adjacent_fx_marker(subs, index)
    local marker_owners = marker and marker.uid and source_index.by_uid[marker.uid] or nil
    if marker and marker.uid and marker_owners
        and (#marker_owners ~= 1 or marker_owners[1] ~= index) then
        marker = nil
        marker_owners = nil
    end
    local uid, cleanup_uid, global_uid
    local owners = stored_uid and source_index.by_uid[stored_uid] or nil
    if stored_uid and owners and #owners == 1 and owners[1] == index and not reserved[stored_uid] then
        uid = stored_uid
        cleanup_uid = stored_uid
        global_uid = true
    elseif marker and marker.uid then
        owners = marker_owners
        if not reserved[marker.uid] and (not owners or (#owners == 1 and owners[1] == index)) then
            uid = marker.uid
            cleanup_uid = marker.uid
            global_uid = owners ~= nil
        end
    end
    if not uid then uid = allocate_source_uid(source, index, used) end
    used[uid] = true
    reserved[uid] = true
    return {
        index = index,
        key = key,
        uid = uid,
        cleanup_uid = cleanup_uid,
        adjacent_uid = marker and marker.uid or nil,
        adjacent_key = marker and marker.key or nil,
        adjacent_version = marker and marker.version or nil,
        global_uid = global_uid and true or false,
        stored_comment = stored_comment,
    }
end

local function infer_original_comment(subs, plan, source_index)
    if plan.stored_comment ~= nil then return plan.stored_comment end
    local saw_adjacent = false
    local j = (tonumber(plan.index) or 0) + 1
    while j <= #subs and is_fx_line(subs[j]) do
        local marker = parse_fx_marker(subs[j])
        if marker and (
            (marker.version == 0 and plan.adjacent_version == 0)
            or (marker.uid and (marker.uid == plan.cleanup_uid or marker.uid == plan.adjacent_uid))
            or (not marker.uid and marker.key and marker.key == plan.adjacent_key)
        ) then
            saw_adjacent = true
            if marker.original_comment ~= nil then return marker.original_comment end
        end
        j = j + 1
    end
    if saw_adjacent then return false end
    if plan.global_uid and plan.cleanup_uid then
        for i = 1, #subs do
            local marker = parse_fx_marker(subs[i])
            if marker and marker.uid == plan.cleanup_uid and marker.original_comment ~= nil then
                return marker.original_comment
            end
        end
    end
    local owners = source_index.by_key[plan.key]
    if owners and #owners == 1 then
        for i = 1, #subs do
            local marker = parse_fx_marker(subs[i])
            if marker and not marker.uid and marker.key == plan.key and marker.original_comment ~= nil then
                return marker.original_comment
            end
        end
    else
        for i = 1, #subs do
            local marker = parse_fx_marker(subs[i])
            if marker and marker.key == plan.key and not marker.uid then
                return nil, "las marcas 3.1 de este target son ambiguas porque existen sources identicos y el FX no esta junto a su origen"
            elseif marker and marker.key == plan.key and marker.uid then
                local uid_owners = source_index.by_uid[marker.uid]
                if not uid_owners or #uid_owners ~= 1 then
                    return nil, "la procedencia UID de este target es ambigua porque el FX no esta junto a un source identificable"
                end
            end
        end
    end
    return subs[plan.index] and subs[plan.index].comment and true or false
end

local function collect_cleanup_indices(subs, plans)
    local remove = {}
    local source_index = build_source_index(subs)
    for _, plan in ipairs(plans) do
        local j = plan.index + 1
        while j <= #subs and is_fx_line(subs[j]) do
            local marker = parse_fx_marker(subs[j])
            if marker and (
                (marker.version == 0 and plan.adjacent_version == 0)
                or (marker.uid and (marker.uid == plan.cleanup_uid or marker.uid == plan.adjacent_uid))
                or (not marker.uid and marker.key and marker.key == plan.adjacent_key)
            ) then
                remove[j] = true
            end
            j = j + 1
        end
        if plan.global_uid and plan.cleanup_uid then
            for i = 1, #subs do
                if fx_source_uid(subs[i]) == plan.cleanup_uid then remove[i] = true end
            end
        end
        local owners = source_index.by_key[plan.key]
        if owners and #owners == 1 then
            for i = 1, #subs do
                local marker = parse_fx_marker(subs[i])
                if marker and not marker.uid and marker.key == plan.key then remove[i] = true end
            end
        end
    end
    local out = {}
    for i in pairs(remove) do out[#out + 1] = i end
    table.sort(out, function(a, b) return a > b end)
    return out
end

local function shift_indices_after_delete(plans, guide_idx, deleted)
    for _, plan in ipairs(plans) do if plan.index > deleted then plan.index = plan.index - 1 end end
    for i = 1, #guide_idx do if guide_idx[i] > deleted then guide_idx[i] = guide_idx[i] - 1 end end
end

local function apply(subs, sel)
    sel = sel or {}
    if not LineOps or type(LineOps.transaction) ~= "function" then
        show_message("Falta kite.LineOps 1.5.0 o superior; no se puede aplicar de forma transaccional.")
        return
    end
    if #sel == 0 then
        show_message("Selecciona las guias intro/active/outro y/o las lineas objetivo.")
        return
    end
    local meta, styles, head_err = collect_head_checked(subs)
    if not meta then show_message(head_err); return end

    local guide_idx, target_idx, selection_errors = resolve_selection(subs, sel)
    if #selection_errors > 0 then
        show_report("Alecto KFX - seleccion ambigua", table.concat(selection_errors, "\n"))
        return
    end
    if #target_idx == 0 then show_message("No hay lineas objetivo validas en la seleccion."); return end
    if #guide_idx == 0 then guide_idx = discover_guides_above(subs, target_idx[1]) end

    local guides, guide_warnings, guide_errors = compile_guides(subs, meta, styles, guide_idx)
    if #guide_errors > 0 then show_report("Alecto KFX - error de guias", table.concat(guide_errors, "\n")); return end

    local plans, errors = {}, {}
    local total_events = 0
    local source_index = build_source_index(subs)
    local used_uids, reserved_uids = collect_used_uids(subs), {}
    for ni, idx in ipairs(target_idx) do
        if progress_cancelled(ni - 1, #target_idx, "analizando") then
            show_message("Operacion cancelada sin cambios.")
            return
        end
        local plan = build_identity_plan(subs, idx, source_index, used_uids, reserved_uids)
        local original_comment, identity_error = infer_original_comment(subs, plan, source_index)
        if identity_error then
            show_report("Alecto KFX - procedencia ambigua", "Linea " .. idx .. ": " .. identity_error .. ".\nNo se modifico el archivo.")
            return
        end
        local src, err = preprocess_copy(subs, meta, styles, idx)
        if src then
            src._alecto_original_comment = original_comment
            src._alecto_source_uid = plan.uid
        end
        if not src then
            errors[#errors + 1] = "Linea " .. idx .. ": fallo el preprocesado: " .. tostring(err)
        else
            local gp, gn = scan_gaps(subs, src, idx)
            local control = {
                max_events = CONFIG.max_generated_events - total_events,
                is_cancelled = progress_is_cancelled,
            }
            local okg, lines = pcall(generate_for_line, src, guides, gp, gn, control)
            if not okg then
                if lines == GENERATION_CANCELLED then
                    show_message("Operacion cancelada sin cambios.")
                    return
                elseif lines == GENERATION_LIMIT then
                    show_message("Se aborta antes de modificar el archivo: la seleccion produciria mas de "
                        .. CONFIG.max_generated_events .. " eventos. Reduce targets/unidades o aumenta el limite en Configurar.")
                    return
                else
                    errors[#errors + 1] = "Linea " .. idx .. ": " .. tostring(lines)
                end
            elseif #lines == 0 then
                errors[#errors + 1] = "Linea " .. idx .. ": no produjo eventos; revisa texto, tiempos y unidades."
            else
                total_events = total_events + #lines
                plan.original_comment = original_comment
                plan.lines = lines
                plans[#plans + 1] = plan
            end
        end
    end
    if progress_cancelled(#target_idx, #target_idx, "listo") then
        show_message("Operacion cancelada sin cambios.")
        return
    end
    if #plans == 0 then
        local msg = #errors > 0 and table.concat(errors, "\n") or "No se genero nada."
        show_report("Alecto KFX - sin cambios", msg)
        return
    end

    local cleanup = collect_cleanup_indices(subs, plans)
    LineOps.transaction(subs, script_name .. " (aplicar)", function()
        for _, idx in ipairs(cleanup) do
            subs.delete(idx)
            shift_indices_after_delete(plans, guide_idx, idx)
        end

        for _, idx in ipairs(guide_idx) do
            local g = subs[idx]
            if g and g.class == "dialogue" and not g.comment then
                g.comment = true
                subs[idx] = g
            end
        end

        table.sort(plans, function(a, b) return a.index > b.index end)
        for _, plan in ipairs(plans) do
            local src = subs[plan.index]
            src.comment = true
            src.extra = clone_extra(src.extra)
            src.extra[SOURCE_EXTRA_KEY] = encode_source_record(plan.uid, plan.original_comment)
            subs[plan.index] = src
            for i = #plan.lines, 1, -1 do subs.insert(plan.index + 1, plan.lines[i]) end
        end
    end)

    local report = {
        "Targets compilados: " .. #plans,
        "Eventos generados: " .. total_events,
        "Eventos previos reemplazados: " .. #cleanup,
    }
    for _, w in ipairs(guide_warnings) do report[#report + 1] = "AVISO: " .. w end
    for _, e in ipairs(errors) do report[#report + 1] = "ERROR NO APLICADO: " .. e end
    if #guide_warnings > 0 or #errors > 0 then show_report("Alecto KFX - resultado", table.concat(report, "\n"))
    else show_message(table.concat(report, " | ")) end
end

local function remove_generated(subs, sel)
    sel = sel or {}
    if not LineOps or type(LineOps.transaction) ~= "function" then
        show_message("Falta kite.LineOps 1.5.0 o superior; no se puede limpiar de forma transaccional.")
        return
    end
    if #sel == 0 then show_message("Selecciona targets originales o eventos Alecto generados."); return end
    local _, target_idx, selection_errors = resolve_selection(subs, sel)
    if #selection_errors > 0 then
        show_report("Alecto KFX - seleccion ambigua", table.concat(selection_errors, "\n"))
        return
    end
    if #target_idx == 0 then show_message("No se pudo localizar ningun target de origen."); return end
    local plans = {}
    local source_index = build_source_index(subs)
    local used_uids, reserved_uids = collect_used_uids(subs), {}
    for _, idx in ipairs(target_idx) do
        local plan = build_identity_plan(subs, idx, source_index, used_uids, reserved_uids)
        local original_comment, identity_error = infer_original_comment(subs, plan, source_index)
        if identity_error then
            show_report("Alecto KFX - procedencia ambigua", "Linea " .. idx .. ": " .. identity_error .. ".\nNo se modifico el archivo.")
            return
        end
        plan.original_comment = original_comment
        plans[#plans + 1] = plan
    end
    local cleanup = collect_cleanup_indices(subs, plans)
    if #cleanup == 0 then show_message("No hay eventos Alecto asociados a la seleccion."); return end
    LineOps.transaction(subs, script_name .. " (limpiar seleccion)", function()
        for _, idx in ipairs(cleanup) do
            subs.delete(idx)
            shift_indices_after_delete(plans, {}, idx)
        end
        for _, plan in ipairs(plans) do
            local l = subs[plan.index]
            if l and l.class == "dialogue" then
                l.comment = plan.original_comment and true or false
                l.extra = clone_extra(l.extra)
                l.extra[SOURCE_EXTRA_KEY] = nil
                subs[plan.index] = l
            end
        end
    end)
    show_message("Eventos eliminados: " .. #cleanup .. ". Targets restaurados: " .. #plans .. ".")
end

local function generate_bases(subs, sel)
    sel = sel or {}
    if not LineOps or type(LineOps.transaction) ~= "function" then
        show_message("Falta kite.LineOps 1.5.0 o superior; no se pueden insertar bases de forma transaccional.")
        return
    end
    if #sel == 0 then show_message("Selecciona una o mas lineas target."); return end
    local meta, styles, head_err = collect_head_checked(subs)
    if not meta then show_message(head_err); return end
    local _, targets, selection_errors = resolve_selection(subs, sel)
    if #selection_errors > 0 then
        show_report("Alecto KFX - seleccion ambigua", table.concat(selection_errors, "\n"))
        return
    end
    if #targets == 0 then show_message("No hay targets validos."); return end

    local last_end = 0
    for i = 1, #subs do
        local l = subs[i]
        if l.class == "dialogue" and (not l.comment or line_phase(l)) and not is_fx_line(l) then
            last_end = max(last_end, tonumber(l.end_time) or 0)
        end
    end

    table.sort(targets, function(a, b)
        local left, right = subs[a], subs[b]
        local left_start = tonumber(left and left.start_time) or 0
        local right_start = tonumber(right and right.start_time) or 0
        if left_start == right_start then return a < b end
        return left_start < right_start
    end)
    local t0, plans, errors = last_end + CONFIG.base_offset_ms, {}, {}
    for ti, idx in ipairs(targets) do
        if progress_cancelled(ti - 1, #targets, "preparando bases") then
            show_message("Operacion cancelada sin cambios.")
            return
        end
        local src, err = preprocess_copy(subs, meta, styles, idx)
        if not src then
            errors[#errors + 1] = "Linea " .. idx .. ": " .. tostring(err)
        else
            local lx, lmid = line_anchor(src)
            local cx = lx + (tonumber(src.width) or 0) / 2
            local text = tostring(src.text_stripped or visible_text(src.text))
            text = trim(text:gsub("\\[Nnh]", " "))
            if text ~= "" then
                local kara = has_kara(src.text)
                local phases = kara and { "intro", "active", "outro" } or { "intro", "outro" }
                local tf = Core.parse_flags(src.actor)
                local actor = kara and "syl" or "char"
                if tf.group then actor = actor .. " group=" .. tf.group end
                if tf.channel then actor = actor .. " channel=" .. tf.channel end
                local new_lines = {}
                for pi, phase in ipairs(phases) do
                    if progress_is_cancelled() then
                        show_message("Operacion cancelada sin cambios.")
                        return
                    end
                    local g = copy_line(subs[idx])
                    g.extra = clone_extra(g.extra)
                    g.extra[SOURCE_EXTRA_KEY] = nil
                    g.comment = false
                    g.layer = tonumber(src.layer) or 0
                    g.actor = actor
                    g.effect = phase
                    g.start_time = t0 + (pi - 1) * (CONFIG.base_len_ms + CONFIG.base_gap_ms)
                    g.end_time = g.start_time + CONFIG.base_len_ms
                    g.text = "{\\an5\\pos(" .. fmt_num(cx) .. "," .. fmt_num(lmid) .. ")}" .. text
                    new_lines[#new_lines + 1] = g
                end
                plans[#plans + 1] = { index = idx, lines = new_lines }
                t0 = t0 + #phases * (CONFIG.base_len_ms + CONFIG.base_gap_ms) + CONFIG.base_block_gap_ms
            else
                errors[#errors + 1] = "Linea " .. idx .. ": texto vacio tras quitar tags."
            end
        end
    end
    if #errors > 0 then
        show_report("Alecto KFX - generar bases", table.concat(errors, "\n") .. "\nNo se modifico el archivo.")
        return
    end
    if progress_cancelled(#targets, #targets, "bases listas") then
        show_message("Operacion cancelada sin cambios.")
        return
    end
    table.sort(plans, function(a, b) return a.index > b.index end)
    if #plans > 0 then
        LineOps.transaction(subs, script_name .. " (bases)", function()
            for _, plan in ipairs(plans) do
                for i = #plan.lines, 1, -1 do subs.insert(plan.index + 1, plan.lines[i]) end
            end
        end)
    end
    show_message("Bloques de guias creados: " .. #plans .. ".")
end

local function format_ms(ms)
    ms = tonumber(ms) or 0
    return string.format("%.3fs", ms / 1000)
end

local function guide_flag_summary(g)
    local f = g.flags or {}
    local parts = { "unit=" .. tostring(g.unit), "order=" .. tostring(f.order or "ltr") }
    if g.nobase then parts[#parts + 1] = "nobase"
    else
        if g.nofade then parts[#parts + 1] = "nofade" end
        if g.nostagger then parts[#parts + 1] = "nostagger" end
    end
    for _, k in ipairs({ "lead_ms", "tail_ms", "fade_ms", "stagger_ms", "respiro_ms" }) do
        if f[k] ~= nil then parts[#parts + 1] = k .. "=" .. tostring(f[k]) end
    end
    if f.group then parts[#parts + 1] = "group=" .. f.group end
    if f.channel then parts[#parts + 1] = "channel=" .. f.channel end
    parts[#parts + 1] = "inherit=" .. tostring(f.inherit or "static")
    return table.concat(parts, ", ")
end

local function check_guide_syntax(src, idx, report)
    local tags = parse_tags(first_tag_block(src.text))
    local pos_count, move_count, org_count = 0, 0, 0
    for _, tag in ipairs(tags) do
        if tag.lname == "pos" then pos_count = pos_count + 1
        elseif tag.lname == "move" then
            move_count = move_count + 1
            if not parse_move_args(tag.args) then report[#report + 1] = "  AVISO: linea " .. idx .. " tiene \\move invalido." end
        elseif tag.lname == "org" then org_count = org_count + 1
        elseif tag.lname == "fade" and #parse_nums(tag.args) ~= 7 then
            report[#report + 1] = "  AVISO: linea " .. idx .. " tiene \\fade sin 7 argumentos; se omitira."
        elseif tag.lname == "fad" and #parse_nums(tag.args) < 2 then
            report[#report + 1] = "  AVISO: linea " .. idx .. " tiene \\fad incompleto."
        end
    end
    if pos_count + move_count > 1 then report[#report + 1] = "  AVISO: usa solo un \\pos o \\move por guia." end
    if org_count > 1 then report[#report + 1] = "  AVISO: solo el primer \\org es util." end
end

local function validate_selection(subs, sel)
    sel = sel or {}
    if #sel == 0 then show_message("Selecciona guias y/o targets para diagnosticar."); return end
    local meta, styles, head_err = collect_head_checked(subs)
    if not meta then show_message(head_err); return end
    local guide_idx, target_idx, selection_errors = resolve_selection(subs, sel)
    if #selection_errors > 0 then
        show_report("Alecto KFX - seleccion ambigua", table.concat(selection_errors, "\n"))
        return
    end
    if #guide_idx == 0 and #target_idx > 0 then guide_idx = discover_guides_above(subs, target_idx[1]) end
    local guides, guide_warnings, guide_errors = compile_guides(subs, meta, styles, guide_idx)

    local report = {
        "Alecto KFX " .. script_version,
        "Resolucion: " .. tostring(meta.res_x or "?") .. "x" .. tostring(meta.res_y or "?"),
        "Configuracion: lead=" .. CONFIG.lead_ms .. "ms, tail=" .. CONFIG.tail_ms
            .. "ms, fade=" .. CONFIG.fade_ms .. "ms, stagger=" .. CONFIG.stagger_ms
            .. "ms, gap=" .. CONFIG.respiro_ms .. "ms",
        "Guias: " .. #guide_idx .. " | Targets: " .. #target_idx,
        "",
    }

    if #guide_idx == 0 then
        report[#report + 1] = "GUIAS: ninguna; se usaran guias neutras para las fases aplicables."
    else
        report[#report + 1] = "GUIAS"
        for _, phase in ipairs({ "intro", "active", "outro" }) do
            for _, g in ipairs(guides[phase]) do
                local geom = g.geom
                report[#report + 1] = string.format("- L%d %s | %s | dur=%s | bbox=%.1fx%.1f",
                    g.source_index or 0, phase, guide_flag_summary(g), format_ms(geom.dur), geom.width, geom.height)
                if g.samples then
                    report[#report + 1] = "  Curvas: " .. table.concat(g.samples.props, ", ")
                end
                local src = subs[g.source_index]
                if src then check_guide_syntax(src, g.source_index, report) end
            end
        end
    end
    for _, w in ipairs(guide_warnings) do report[#report + 1] = "  AVISO: " .. w end
    for _, e in ipairs(guide_errors) do report[#report + 1] = "  ERROR: " .. e end

    report[#report + 1] = ""
    report[#report + 1] = "TARGETS"
    local total, limit_reached = 0, false
    for ni, idx in ipairs(target_idx) do
        if progress_cancelled(ni - 1, #target_idx, "validando") then
            show_message("Diagnostico cancelado sin cambios.")
            return
        end
        local src, err = preprocess_copy(subs, meta, styles, idx)
        if not src then
            report[#report + 1] = "- L" .. idx .. " ERROR preprocesando: " .. tostring(err)
        else
            local kind = has_kara(src.text) and "karaoke" or "TL"
            local units = has_kara(src.text) and collect_syls(src) or {}
            local extra = has_kara(src.text) and (" | silabas=" .. #units) or ""
            report[#report + 1] = "- L" .. idx .. " " .. kind .. " | " .. format_ms(src.end_time - src.start_time)
                .. " | style=" .. tostring(src.style) .. " | key=" .. source_key(src) .. extra
            if trim(src.text_stripped or visible_text(src.text)) == "" then
                report[#report + 1] = "  ERROR: texto visible vacio."
            end
            if target_is_drawing(src) then report[#report + 1] = "  ERROR: target vectorial \\p no soportado." end
            if tostring(src.text):find("\\[Nn]") then
                report[#report + 1] = "  AVISO: target multilinea; para geometria fiable usa unit=line o divide el texto en eventos separados."
            end
            local target_options = Core.parse_flags(src.actor)
            for _, tok in ipairs(target_options.unknown or {}) do
                report[#report + 1] = "  AVISO: variable de Actor desconocida '" .. tok .. "'."
            end
            if tostring(src.text):lower():find("\\kt%s*%d") then
                report[#report + 1] = "  AVISO: contiene \\kt; Alecto usa su parser alternativo porque karaskel no lo procesa de forma nativa."
            end
            local gp, gn = scan_gaps(subs, src, idx)
            report[#report + 1] = "  Hueco previo=" .. (gp == math.huge and "libre" or (gp .. "ms"))
                .. " | siguiente=" .. (gn == math.huge and "libre" or (gn .. "ms"))
            local control = {
                max_events = CONFIG.max_generated_events - total,
                is_cancelled = progress_is_cancelled,
            }
            local okg, lines = pcall(generate_for_line, src, guides, gp, gn, control)
            if okg then
                total = total + #lines
                local bad = 0
                for _, l in ipairs(lines) do if l.end_time <= l.start_time then bad = bad + 1 end end
                report[#report + 1] = "  Estimacion: " .. #lines .. " eventos" .. (bad > 0 and (" | INVALIDOS=" .. bad) or "")
            elseif lines == GENERATION_CANCELLED then
                show_message("Diagnostico cancelado sin cambios.")
                return
            elseif lines == GENERATION_LIMIT then
                total = CONFIG.max_generated_events + 1
                limit_reached = true
                report[#report + 1] = "  ERROR: la estimacion supera el limite configurado."
            else
                report[#report + 1] = "  ERROR generando: " .. tostring(lines)
            end
        end
        if limit_reached then break end
    end
    report[#report + 1] = ""
    report[#report + 1] = "TOTAL ESTIMADO: " .. total .. " eventos (limite configurado: " .. CONFIG.max_generated_events .. ")."
    if total > CONFIG.max_generated_events then report[#report + 1] = "ERROR: excede el limite; Aplicar abortaria antes de modificar el archivo." end
    show_report("Alecto KFX - diagnostico", table.concat(report, "\n"))
end

local function restore_default_config()
    for k, v in pairs(CONFIG_DEFAULT) do CONFIG[k] = v end
end

local function configure()
    if not aegisub or not aegisub.dialog or not aegisub.dialog.display then
        show_message("Dialogos no disponibles. Edita la tabla CONFIG al inicio del script.")
        return
    end
    local dialog = {
        { class = "label", label = "Entrada (lead)", x = 0, y = 0 },
        { class = "intedit", name = "lead", value = CONFIG.lead_ms, min = 0, max = 10000, x = 1, y = 0 },
        { class = "label", label = "Salida (tail)", x = 0, y = 1 },
        { class = "intedit", name = "tail", value = CONFIG.tail_ms, min = 0, max = 10000, x = 1, y = 1 },
        { class = "label", label = "Fade base", x = 0, y = 2 },
        { class = "intedit", name = "fade", value = CONFIG.fade_ms, min = 0, max = 10000, x = 1, y = 2 },
        { class = "label", label = "Stagger", x = 0, y = 3 },
        { class = "intedit", name = "stagger", value = CONFIG.stagger_ms, min = 0, max = 5000, x = 1, y = 3 },
        { class = "label", label = "Respiro entre lineas", x = 0, y = 4 },
        { class = "intedit", name = "gap", value = CONFIG.respiro_ms, min = 0, max = 2000, x = 1, y = 4 },
        { class = "label", label = "Duracion minima", x = 0, y = 5 },
        { class = "intedit", name = "mindur", value = CONFIG.min_dur_ms, min = 1, max = 1000, x = 1, y = 5 },
        { class = "label", label = "Limite de eventos", x = 0, y = 6 },
        { class = "intedit", name = "maxevents", value = CONFIG.max_generated_events, min = 100, max = 200000, x = 1, y = 6 },
        { class = "label", label = "Orden por defecto", x = 0, y = 7 },
        { class = "dropdown", name = "order", items = { "ltr", "rtl", "center", "edges" }, value = CONFIG.default_order, x = 1, y = 7 },
        { class = "checkbox", name = "inherit", label = "Heredar tags estaticos iniciales del target", value = CONFIG.inherit_target_tags, x = 0, y = 8, width = 2 },
        { class = "label", label = "Los valores del Actor (fade=, stagger=, etc.) tienen prioridad sobre esta configuracion.", x = 0, y = 9, width = 2 },
    }
    local button, result = aegisub.dialog.display(dialog,
        { "Guardar", "Ayuda", "Restaurar", "Cancelar" }, { ok = "Guardar", cancel = "Cancelar" })
    if not button or button == "Cancelar" then return end
    if button == "Ayuda" then show_help(); return end
    if button == "Restaurar" then
        restore_default_config()
        show_message("Configuracion restaurada para esta sesion.")
        return
    end
    CONFIG.lead_ms = max(0, tonumber(result.lead) or CONFIG.lead_ms)
    CONFIG.tail_ms = max(0, tonumber(result.tail) or CONFIG.tail_ms)
    CONFIG.fade_ms = max(0, tonumber(result.fade) or CONFIG.fade_ms)
    CONFIG.stagger_ms = max(0, tonumber(result.stagger) or CONFIG.stagger_ms)
    CONFIG.respiro_ms = max(0, tonumber(result.gap) or CONFIG.respiro_ms)
    CONFIG.min_dur_ms = max(1, tonumber(result.mindur) or CONFIG.min_dur_ms)
    CONFIG.max_generated_events = max(100, tonumber(result.maxevents) or CONFIG.max_generated_events)
    CONFIG.default_order = VALID_ORDERS[result.order] and result.order or CONFIG.default_order
    CONFIG.inherit_target_tags = result.inherit and true or false
    show_message("Configuracion actualizada para esta sesion de Aegisub.")
end

if aegisub and aegisub.register_macro then
    local entries = {
        { script_name .. "/Aplicar", "Compila las guias intro/active/outro sobre los targets seleccionados", apply },
        { script_name .. "/Generar lineas base", "Crea guias editables a partir de los targets seleccionados", generate_bases },
        { script_name .. "/Validar seleccion", "Diagnostica guias, targets, tags, huecos y numero de eventos sin modificar", validate_selection },
        { script_name .. "/Limpiar FX seleccionados", "Elimina solo el FX asociado a los targets seleccionados y restaura los originales", remove_generated },
        { script_name .. "/Configurar", "Ajusta valores globales para la sesion actual", configure },
        { script_name .. "/Ayuda y comandos", "Muestra los comandos del menu y todas las opciones disponibles en Actor", show_help },
    }
    for _, e in ipairs(entries) do
        if depctrl and depctrl.registerMacro then
            depctrl:registerMacro(e[1], e[2], e[3], nil, nil, false)
        else
            aegisub.register_macro(e[1], e[2], e[3])
        end
    end
end
