script_name = "Alecto KFX"
script_description = "Compila karaokes y textos desde guias intro/active/outro, con re-proyeccion espacial y temporal"
script_author = "Kiterow"
script_version = "3.4.3"
script_namespace = "kite.AlectoKFX"

local karaskelLoadError
if not karaskel then
    local includeError, requireError
    if type(include) == "function" then
        local ok, result = pcall(include, "karaskel.lua")
        if ok and not karaskel and type(result) == "table" then karaskel = result end
        if not ok then includeError = result end
    end
    if not karaskel then
        local ok, result = pcall(require, "karaskel")
        if ok and type(result) == "table" then karaskel = result end
        if not ok then requireError = result end
    end
    if not karaskel then
        local errors = {}
        if includeError then errors[#errors + 1] = "include: " .. tostring(includeError) end
        if requireError then errors[#errors + 1] = "require: " .. tostring(requireError) end
        karaskelLoadError = #errors > 0 and table.concat(errors, " | ") or "modulo no disponible"
    end
end

local depctrl
local okDepctrl, DependencyControl = pcall(require, "l0.DependencyControl")
if okDepctrl and DependencyControl then
    local okRecord, record = pcall(DependencyControl, {
        name = script_name,
        description = script_description,
        author = script_author,
        version = script_version,
        namespace = script_namespace,
        feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
        {
            {
                "kite.Core",
                version = "1.1.0",
                url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
                feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
            },
            {
                "kite.LineOps",
                version = "1.7.1",
                url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
                feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
            },
        {"kite.UI", version = "1.5.0"},
        },
    })
    if okRecord then depctrl = record end
end

local KiteCore, LineOps
if depctrl and depctrl.requireModules then
    local ok, coreModule, lineOpsModule = pcall(function() return depctrl:requireModules() end)
    if ok then KiteCore, LineOps = coreModule, lineOpsModule end
end
if not KiteCore then
    local ok, value = pcall(require, "kite.Core")
    if ok then KiteCore = value end
end
if not LineOps then
    local ok, value = pcall(require, "kite.LineOps")
    if ok then LineOps = value end
end

if not KiteCore then
    error("kite.AlectoKFX requires kite.Core 1.0.0 or newer", 0)
end

local SharedUI = require("kite.UI")

local configDefault = {
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
local configStore = SharedUI.settings(script_namespace,script_version,{main=configDefault})
local config = configStore:values("main")

local AlectoCore = {}
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local trim = KiteCore.trim
AlectoCore.trim = trim

local clamp = KiteCore.clamp
AlectoCore.clamp = clamp

local round = KiteCore.round
AlectoCore.round = round

local function fmtNum(v)
    v = tonumber(v) or 0
    if v > -0.005 and v < 0.005 then v = 0 end
    local t = string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", "")
    if t == "-0" then t = "0" end
    return t
end
AlectoCore.fmtNum = fmtNum

local function shallowCopy(value)
    return KiteCore.copy(type(value) == "table" and value or {})
end
AlectoCore.shallowCopy = shallowCopy

function AlectoCore.assTokens(s)
    local out = {}
    for _, text in ipairs(LineOps.graphemes(s)) do
        local control = text == "\\N" or text == "\\n"
        local whitespace = control or text == "\\h" or text:match("^%s+$") ~= nil
        out[#out + 1] = {
            text = text,
            control = control,
            whitespace = whitespace,
            sampleable = not whitespace,
        }
    end
    return out
end

local function utf8Chars(s)
    local out = {}
    for _, tok in ipairs(AlectoCore.assTokens(s)) do out[#out + 1] = tok.text end
    return out
end
AlectoCore.utf8Chars = utf8Chars

function AlectoCore.pointToBbox(px, py, an, w, h)
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

function AlectoCore.legacyAToAn(a)
    a = tonumber(a)
    local map = { [1] = 1, [2] = 2, [3] = 3, [5] = 7, [6] = 8, [7] = 9,
        [9] = 4, [10] = 5, [11] = 6 }
    return map[a]
end

local function splitRuns(text)
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
AlectoCore.splitRuns = splitRuns

local function parseTags(s)
    local out = {}
    for _, token in ipairs(LineOps.overrideTokens(s)) do
        local name = token.raw:sub(2, #token.raw_name + 1)
        local tag = { name = name, lname = name:lower() }
        if token.value:sub(1, 1) == "(" then
            tag.args = token.value:sub(2, token.value:sub(-1) == ")" and -2 or -1)
        else
            tag.val = token.value
        end
        out[#out + 1] = tag
    end
    return out
end
AlectoCore.parseTags = parseTags

local function parseNums(a)
    local nums = {}
    for num in tostring(a or ""):gmatch("[+-]?%d*%.?%d+") do
        local v = tonumber(num)
        if v then nums[#nums + 1] = v end
    end
    return nums
end
AlectoCore.parseNums = parseNums

local function parseStrictNumbers(a)
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

local function parsePair(a)
    local n = parseStrictNumbers(a)
    if not n or #n ~= 2 then return nil end
    return n[1], n[2]
end
AlectoCore.parsePair = parsePair

local function parseTArgs(a)
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
AlectoCore.parseTArgs = parseTArgs

local function parseMoveArgs(a)
    local n = parseStrictNumbers(a)
    if not n or (#n ~= 4 and #n ~= 6) then return nil end
    return { x1 = n[1], y1 = n[2], x2 = n[3], y2 = n[4], t1 = n[5], t2 = n[6] }
end
AlectoCore.parseMoveArgs = parseMoveArgs

local function colorRgb(v)
    local hex = tostring(v or ""):match("[Hh](%x+)")
    if not hex then return nil end
    hex = hex:sub(-6)
    while #hex < 6 do hex = "0" .. hex end
    local num = tonumber(hex, 16) or 0
    return num % 256, floor(num / 256) % 256, floor(num / 65536) % 256
end

local function colorStr(r, g, b)
    local function cl(x) return max(0, min(255, floor(x + 0.5))) end
    return string.format("&H%02X%02X%02X&", cl(b), cl(g), cl(r))
end
AlectoCore.colorRgb, AlectoCore.colorStr = colorRgb, colorStr

local function alphaByte(v)
    local hex = tostring(v or ""):match("[Hh](%x+)")
    if hex then return tonumber(hex:sub(-2), 16) end
    return tonumber(v)
end

local function alphaStr(v)
    return string.format("&H%02X&", max(0, min(255, floor((v or 0) + 0.5))))
end

local function lerp(a, b, t) return a + (b - a) * t end

local function axisMap(g1, g2, s1, s2)
    return function(v)
        v = tonumber(v) or 0
        if g2 <= g1 then return s1 + (v - g1) end
        if v < g1 then return s1 + (v - g1) end
        if v > g2 then return s2 + (v - g2) end
        return s1 + (v - g1) / (g2 - g1) * (s2 - s1)
    end
end
AlectoCore.axisMap = axisMap

local function mapDrawing(draw, mx, my)
    local idx = 0
    return (tostring(draw or ""):gsub("%S+", function(tok)
        local num = tonumber(tok)
        if num then
            idx = idx + 1
            if idx % 2 == 1 then return fmtNum(mx(num)) end
            return fmtNum(my(num))
        end
        idx = 0
        return tok
    end))
end
AlectoCore.mapDrawing = mapDrawing

function AlectoCore.mapClipArgs(args, mx, my)
    local a = tostring(args or "")
    local nums = parseNums(a)
    if not a:lower():find("[mnlbspc]") and #nums == 4 then
        return table.concat({ fmtNum(mx(nums[1])), fmtNum(my(nums[2])),
            fmtNum(mx(nums[3])), fmtNum(my(nums[4])) }, ",")
    end
    local scale, drawing = a:match("^%s*(%d+)%s*,%s*(.*)$")
    if scale and drawing and drawing:lower():find("[mnlbspc]") then
        local sf = 2 ^ (max(1, tonumber(scale) or 1) - 1)
        local function smx(v) return mx((tonumber(v) or 0) / sf) * sf end
        local function smy(v) return my((tonumber(v) or 0) / sf) * sf end
        return scale .. "," .. mapDrawing(drawing, smx, smy)
    end
    return mapDrawing(a, mx, my)
end

function AlectoCore.drawingBbox(draw, p)
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

local validOrders = { ltr = true, rtl = true, center = true, edges = true }
local validInherit = { static = true, none = true }

local function parseNonneg(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return max(0, n)
end

function AlectoCore.parseFlags(actor)
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
        order = config.default_order,
        group = nil,
        channel = nil,
        inherit = config.inherit_target_tags and "static" or "none",
        explicit = {},
        unknown = {},
    }
    local seenAny = false
    local normalized = tostring(actor or ""):gsub(";", " ")
    for raw in normalized:gmatch("%S+") do
        local tok = raw:lower()
        local key, val = tok:match("^([%a_]+)=(.+)$")
        if tok == "char" or tok == "grapheme" then flags.unit = "char"; flags.explicit.unit = true; seenAny = true
        elseif tok == "syl" or tok == "syllable" then flags.unit = "syl"; flags.explicit.unit = true; seenAny = true
        elseif tok == "word" then flags.unit = "word"; flags.explicit.unit = true; seenAny = true
        elseif tok == "line" then flags.unit = "line"; flags.explicit.unit = true; seenAny = true
        elseif tok == "nobase" then
            flags.nobase, flags.nofade, flags.nostagger = true, true, true
            seenAny = true
        elseif tok == "nofade" then flags.nofade = true; seenAny = true
        elseif tok == "nostagger" then flags.nostagger = true; seenAny = true
        elseif tok == "base" then
            flags.nobase, flags.nofade, flags.nostagger = false, false, false
            seenAny = true
        elseif tok == "reverse" or tok == "rtl" then flags.order = "rtl"; flags.explicit.order = true; seenAny = true
        elseif tok == "ltr" then flags.order = "ltr"; flags.explicit.order = true; seenAny = true
        elseif tok == "center" then flags.order = "center"; flags.explicit.order = true; seenAny = true
        elseif tok == "edges" then flags.order = "edges"; flags.explicit.order = true; seenAny = true
        elseif key == "stagger" then
            flags.stagger_ms = parseNonneg(val)
            if flags.stagger_ms ~= nil then flags.explicit.stagger_ms = true; seenAny = true else flags.unknown[#flags.unknown + 1] = raw end
        elseif key == "fade" then
            flags.fade_ms = parseNonneg(val)
            if flags.fade_ms ~= nil then flags.explicit.fade_ms = true; seenAny = true else flags.unknown[#flags.unknown + 1] = raw end
        elseif key == "lead" then
            flags.lead_ms = parseNonneg(val)
            if flags.lead_ms ~= nil then flags.explicit.lead_ms = true; seenAny = true else flags.unknown[#flags.unknown + 1] = raw end
        elseif key == "tail" then
            flags.tail_ms = parseNonneg(val)
            if flags.tail_ms ~= nil then flags.explicit.tail_ms = true; seenAny = true else flags.unknown[#flags.unknown + 1] = raw end
        elseif key == "gap" or key == "respiro" then
            flags.respiro_ms = parseNonneg(val)
            if flags.respiro_ms ~= nil then flags.explicit.respiro_ms = true; seenAny = true else flags.unknown[#flags.unknown + 1] = raw end
        elseif key == "order" and validOrders[val] then flags.order = val; flags.explicit.order = true; seenAny = true
        elseif key == "group" and val ~= "" then flags.group = val; flags.explicit.group = true; seenAny = true
        elseif key == "channel" and val ~= "" then flags.channel = val; flags.explicit.channel = true; seenAny = true
        elseif key == "inherit" and validInherit[val] then flags.inherit = val; flags.explicit.inherit = true; seenAny = true
        elseif tok:match("^akfx:") then
            local inner = tok:sub(6)
            local ik, iv = inner:match("^([%a_]+)=(.+)$")
            if ik == "channel" and iv ~= "" then flags.channel = iv; flags.explicit.channel = true; seenAny = true
            elseif ik == "group" and iv ~= "" then flags.group = iv; flags.explicit.group = true; seenAny = true
            elseif ik == "inherit" and validInherit[iv] then flags.inherit = iv; flags.explicit.inherit = true; seenAny = true
            else flags.unknown[#flags.unknown + 1] = raw end
        elseif key or tok == "nobase" or tok == "nofade" or tok == "nostagger" then
            flags.unknown[#flags.unknown + 1] = raw
        end
    end
    flags.has_options = seenAny
    return flags
end

function AlectoCore.orderRank(i, n, order)
    order = validOrders[order] and order or "ltr"
    if order == "rtl" then return n - i end
    if order == "center" then return floor(abs(i - (n + 1) / 2)) end
    if order == "edges" then return min(i - 1, n - i) end
    return i - 1
end

function AlectoCore.orderMaxRank(n, order)
    n = max(1, tonumber(n) or 1)
    order = validOrders[order] and order or "ltr"
    if order == "center" or order == "edges" then return floor((n - 1) / 2) end
    return n - 1
end

local lineWide = {
    pos = true, move = true, org = true, an = true, a = true,
}
local nonSampleTag = {
    pos = true, move = true, org = true, an = true, a = true,
    p = true, k = true, kf = true, ko = true, kt = true,
}

local alphaTag = { alpha = true, ["1a"] = true, ["2a"] = true, ["3a"] = true, ["4a"] = true }
local colorTag = { c = true, ["1c"] = true, ["2c"] = true, ["3c"] = true, ["4c"] = true }

local function tagHasAlpha(tag)
    local name = tag.lname or tostring(tag.name or ""):lower()
    if alphaTag[name] or name == "fad" or name == "fade" then return true end
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

function AlectoCore.parseGuide(effect, layer, text, geom, actor)
    local runs = splitRuns(text)
    for _, r in ipairs(runs) do r.taglist = parseTags(r.tags or "") end
    local flags = AlectoCore.parseFlags(actor)
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
                    guide.move = guide.move or parseMoveArgs(tag.args)
                elseif name == "org" then
                    local x, y = parsePair(tag.args)
                    if x then guide.org = { x = x, y = y } end
                elseif not lineWide[name] then
                    guide.header[#guide.header + 1] = tag
                end
            end
            if name == "p" and (tonumber(tag.val) or 0) > 0 then guide.is_drawing = true end
            if name == "fad" or name == "fade" or (name == "t" and tagHasAlpha(tag)) then
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
    guide.samples = guide.is_drawing and nil or AlectoCore.buildSamples(runs)
    return guide
end

function AlectoCore.buildSamples(runs)
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
            elseif tag.val ~= nil and not nonSampleTag[name] then
                state[name] = tag.val
            elseif tag.args ~= nil and ri > 1 and not nonSampleTag[name] then
                fns[#fns + 1] = tag
            end
        end
        local tokens = AlectoCore.assTokens(r.text or "")
        local count = 0
        for _, tok in ipairs(tokens) do if tok.sampleable then count = count + 1 end end
        if count > 0 then
            snapshots[#snapshots + 1] = {
                first = total,
                count = count,
                vals = shallowCopy(state),
                fns = fns,
            }
            total = total + count
        end
    end
    if #snapshots < 2 or total < 2 then return nil end

    local union = {}
    local anyFns = false
    for _, s in ipairs(snapshots) do
        if #s.fns > 0 then anyFns = true end
        for k in pairs(s.vals) do union[k] = true end
    end
    local props = {}
    local nilSentinel = {}
    for prop in pairs(union) do
        local first = snapshots[1].vals[prop]
        if first == nil then first = nilSentinel end
        local varies = false
        for i = 2, #snapshots do
            local v = snapshots[i].vals[prop]
            if v == nil then v = nilSentinel end
            if v ~= first then varies = true; break end
        end
        if varies then props[#props + 1] = prop end
    end
    if #props == 0 and not anyFns then return nil end
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

local continuousNumeric = {
    fs = true, fscx = true, fscy = true, fsp = true,
    fr = true, frx = true, fry = true, frz = true,
    fax = true, fay = true, bord = true, xbord = true, ybord = true,
    shad = true, xshad = true, yshad = true, blur = true, be = true,
    pbo = true,
}

function AlectoCore.sampleProp(samples, prop, u)
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
            if colorTag[prop] then
                local r1, g1, b1 = colorRgb(va)
                local r2, g2, b2 = colorRgb(vb)
                if r1 and r2 then
                    return colorStr(lerp(r1, r2, t), lerp(g1, g2, t), lerp(b1, b2, t))
                end
            end
            if alphaTag[prop] then
                local a1, a2 = alphaByte(va), alphaByte(vb)
                if a1 and a2 then return alphaStr(lerp(a1, a2, t)) end
            end
            local n1, n2 = tonumber(va), tonumber(vb)
            if n1 and n2 and continuousNumeric[prop] then return fmtNum(lerp(n1, n2, t)) end
            return t < 0.5 and va or vb
        end
    end
    return list[#list].vals[prop]
end

function AlectoCore.sampleFns(samples, u)
    local list = samples.list
    local best, dist = nil, math.huge
    for _, s in ipairs(list) do
        local d = abs(s.u - u)
        if d < dist then best, dist = s, d end
    end
    return best and best.fns or {}
end

function AlectoCore.renderEvent(guide, ctx)
    local g = guide.geom
    local mx = axisMap(g.left, g.right, ctx.bx1, ctx.bx2)
    local my = axisMap(g.top, g.bottom, ctx.by1, ctx.by2)
    local pDur = max(1, tonumber(ctx.p_dur) or 1)
    local tDur = max(1, tonumber(ctx.t_dur) or pDur)
    local tOff = max(0, tonumber(ctx.t_off) or 0)
    local ratio = tDur / max(1, tonumber(g.dur) or 1)

    local function scaleTime(t)
        local v = round((tonumber(t) or 0) * ratio) + tOff
        return clamp(v, 0, pDur)
    end

    local transformList
    transformList = function(list, insideT)
        local out = {}
        for _, tag in ipairs(list or {}) do
            local name = tag.lname or tostring(tag.name or ""):lower()
            if name == "clip" or name == "iclip" then
                out[#out + 1] = "\\" .. name .. "(" .. AlectoCore.mapClipArgs(tag.args, mx, my) .. ")"
            elseif name == "t" and not insideT then
                local t1, t2, accel, body = parseTArgs(tag.args)
                local inner = transformList(parseTags(body), true)
                local head = ""
                if t1 and t2 then
                    local s1, s2 = scaleTime(t1), scaleTime(t2)
                    if s2 <= s1 then s2 = min(pDur, s1 + 1) end
                    if s2 <= s1 then s1 = max(0, s2 - 1) end
                    head = round(s1) .. "," .. round(s2) .. ","
                elseif tOff > 0 or tDur ~= pDur then
                    local s1 = clamp(tOff, 0, pDur)
                    local s2 = clamp(tOff + tDur, 0, pDur)
                    if s2 <= s1 then s2 = min(pDur, s1 + 1) end
                    if s2 <= s1 then s1 = max(0, s2 - 1) end
                    head = round(s1) .. "," .. round(s2) .. ","
                end
                if accel and accel ~= 1 then head = head .. fmtNum(accel) .. "," end
                out[#out + 1] = "\\t(" .. head .. table.concat(inner) .. ")"
            elseif name == "fad" then
                local nums = parseNums(tag.args)
                local fa = max(0, round((nums[1] or 0) * ratio))
                local fb = max(0, round((nums[2] or 0) * ratio))
                if fa + fb > pDur then
                    local k = pDur / max(1, fa + fb)
                    fa, fb = round(fa * k), round(fb * k)
                end
                out[#out + 1] = "\\fad(" .. fa .. "," .. fb .. ")"
            elseif name == "fade" then
                local nums = parseNums(tag.args)
                if #nums >= 7 then
                    local times = {}
                    for i = 4, 7 do times[#times + 1] = scaleTime(nums[i]) end
                    for i = 2, #times do if times[i] < times[i - 1] then times[i] = times[i - 1] end end
                    out[#out + 1] = string.format("\\fade(%d,%d,%d,%d,%d,%d,%d)",
                        clamp(round(nums[1]), 0, 255), clamp(round(nums[2]), 0, 255),
                        clamp(round(nums[3]), 0, 255), round(times[1]), round(times[2]),
                        round(times[3]), round(times[4]))
                end
            elseif lineWide[name] or name == "p" or name == "k" or name == "kf"
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
            local s1, s2 = scaleTime(m.t1), scaleTime(m.t2)
            if s2 <= s1 then s2 = min(pDur, s1 + 1) end
            if s2 <= s1 then s1 = max(0, s2 - 1) end
            times = "," .. round(s1) .. "," .. round(s2)
        end
        anchor = string.format("\\move(%s,%s,%s,%s%s)",
            fmtNum(ctx.ax + d1x), fmtNum(ctx.ay + d1y),
            fmtNum(ctx.ax + d2x), fmtNum(ctx.ay + d2y), times)
    else
        anchor = "\\pos(" .. fmtNum(ctx.ax) .. "," .. fmtNum(ctx.ay) .. ")"
    end

    local org = ""
    if guide.org then
        org = "\\org(" .. fmtNum(mx(guide.org.x)) .. "," .. fmtNum(my(guide.org.y)) .. ")"
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
    local head = "\\an5" .. anchor .. org .. inherit .. table.concat(transformList(statics))

    local baseFade = ""
    if ctx.base_fade and not guide.has_alpha_anim and not guide.nofade then
        local bf = ctx.base_fade
        local t1 = clamp(round(bf.t1 or 0), 0, pDur)
        local t2 = clamp(round(bf.t2 or pDur), 0, pDur)
        if t2 <= t1 then t2 = min(pDur, t1 + 1) end
        if t2 <= t1 then t1 = max(0, t2 - 1) end
        if bf.dir == "in" then
            baseFade = string.format("\\fade(255,0,0,%d,%d,%d,%d)", t1, t2, pDur, pDur)
        else
            baseFade = string.format("\\fade(0,0,255,0,0,%d,%d)", t1, t2)
        end
    end

    head = head .. table.concat(transformList(dynamics)) .. baseFade

    local body
    local tokens = ctx.tokens or AlectoCore.assTokens(ctx.text or "")
    if guide.samples and not ctx.is_drawing then
        local sampleCount = 0
        for _, tok in ipairs(tokens) do if tok.sampleable then sampleCount = sampleCount + 1 end end
        if sampleCount > 0 then
            local parts, si = {}, 0
            for _, tok in ipairs(tokens) do
                if tok.sampleable then
                    si = si + 1
                    local u = sampleCount > 1 and (si - 0.5) / sampleCount or 0.5
                    local blk = {}
                    for _, p in ipairs(guide.samples.props) do
                        local v = AlectoCore.sampleProp(guide.samples, p, u)
                        if v ~= nil then blk[#blk + 1] = "\\" .. p .. tostring(v) end
                    end
                    for _, part in ipairs(transformList(AlectoCore.sampleFns(guide.samples, u))) do
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

local legacyEngineAliases = {
    fmt_num = "fmtNum",
    shallow_copy = "shallowCopy",
    utf8_chars = "utf8Chars",
    ass_tokens = "assTokens",
    point_to_bbox = "pointToBbox",
    legacy_a_to_an = "legacyAToAn",
    split_runs = "splitRuns",
    parse_tags = "parseTags",
    parse_nums = "parseNums",
    parse_pair = "parsePair",
    parse_t_args = "parseTArgs",
    parse_move_args = "parseMoveArgs",
    color_rgb = "colorRgb",
    color_str = "colorStr",
    axis_map = "axisMap",
    map_drawing = "mapDrawing",
    map_clip_args = "mapClipArgs",
    drawing_bbox = "drawingBbox",
    parse_flags = "parseFlags",
    order_rank = "orderRank",
    order_max_rank = "orderMaxRank",
    parse_guide = "parseGuide",
    build_samples = "buildSamples",
    sample_prop = "sampleProp",
    sample_fns = "sampleFns",
    render_event = "renderEvent",
}
for legacyName, currentName in pairs(legacyEngineAliases) do
    AlectoCore[legacyName] = AlectoCore[currentName]
end

local function showMessage(msg)
    return SharedUI.log(msg, script_name)
end
local function showReport(title, text)
    text = tostring(text or "")
    local rows = 0
    for line in (text .. "\n"):gmatch("(.-)\n") do rows = rows + math.max(1, math.ceil(#line / 90)) end
    local height = math.max(3, math.min(16, rows))
    if aegisub and aegisub.dialog and aegisub.dialog.display then
        pcall(aegisub.dialog.display, {
            { class = "label", label = tostring(title or script_name), x = 0, y = 0, width = 36, height = 1 },
            { class = "textbox", name = "report", text = text, x = 0, y = 1, width = 36, height = height, readonly = true },
        }, { "Cerrar" }, { close = "Cerrar" })
    else
        showMessage((title or "Informe") .. "\n" .. text)
    end
end

local helpText = table.concat({
    "COMANDOS DEL MENU",
    "",
    "Aplicar: compila las guias intro/active/outro sobre los targets seleccionados.",
    "Generar lineas base: crea guias editables desde los targets.",
    "Validar seleccion: diagnostica guias, targets, huecos y cantidad de eventos sin modificar.",
    "Limpiar FX seleccionados: elimina el FX asociado y restaura los targets originales.",
    "Configurar: guarda los valores predeterminados para próximas sesiones.",
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

local function showHelp()
    showReport(script_name .. " - ayuda y comandos", helpText)
end

local copyLine = shallowCopy

local function visibleText(text)
    if LineOps then return LineOps.visibleText(text) end
    return (tostring(text or ""):gsub("{[^}]*}", "")):gsub("\\[Nnh]", " ")
end

local function drawingText(text)
    if LineOps then return LineOps.analyzeText(text).drawing end
    return tostring(text or ""):gsub("{[^}]*}", "")
end

local phases = { intro = true, active = true, outro = true }
local sourceExtraKey = "_aegi_alecto_kfx_source"

local function linePhase(line)
    local e = trim(line and line.effect or ""):lower()
    if phases[e] then return e end
    return nil
end

local function isFxLine(line)
    if not line or line.class ~= "dialogue" then return false end
    local e = trim(line.effect or ""):lower()
    return e == config.fx_marker or e:sub(1, #config.fx_marker + 1) == config.fx_marker .. ":"
end

local function cloneExtra(extra)
    return shallowCopy(type(extra) == "table" and extra or {})
end

local function parseSourceRecord(line)
    local raw = type(line and line.extra) == "table" and line.extra[sourceExtraKey] or nil
    local uid, bit
    if type(raw) == "string" then uid, bit = raw:match("^v1:([^:]+):c([01])$") end
    if not uid then return nil end
    return uid, bit == "1"
end

local function encodeSourceRecord(uid, originalComment)
    return "v1:" .. tostring(uid) .. ":c" .. (originalComment and "1" or "0")
end

local function parseFxMarker(line)
    if not isFxLine(line) then return nil end
    local effect = trim(line.effect or "")
    local payload = effect:sub(#config.fx_marker + 2)
    if effect == config.fx_marker then return { version = 0 } end
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

local function fxSourceUid(line)
    local marker = parseFxMarker(line)
    return marker and marker.uid or nil
end

local function hasKara(text)
    return tostring(text or ""):lower():find("\\k[fot]?%s*%d") ~= nil
end

local function firstTagBlock(text)
    local runs = splitRuns(text)
    return (runs[1] and runs[1].tags) or ""
end

local function posOf(text, phase)
    local tags = parseTags(firstTagBlock(text))
    for _, tag in ipairs(tags) do
        if tag.lname == "pos" then return parsePair(tag.args) end
    end
    for _, tag in ipairs(tags) do
        if tag.lname == "move" then
            local m = parseMoveArgs(tag.args)
            if m then
                if phase == "intro" then return m.x2, m.y2 end
                return m.x1, m.y1
            end
        end
    end
    return nil
end

local function lineAlign(line)
    local tags = parseTags(firstTagBlock(line and line.text or ""))
    for _, tag in ipairs(tags) do
        if tag.lname == "an" then
            local an = tonumber(tag.val)
            if an and an >= 1 and an <= 9 then return an end
        elseif tag.lname == "a" then
            local an = AlectoCore.legacyAToAn(tag.val)
            if an then return an end
        end
    end
    return (line and line.styleref and tonumber(line.styleref.align)) or 2
end

local function lineAnchor(line)
    local px, py = posOf(line.text)
    if px == nil then
        return tonumber(line.left) or 0, tonumber(line.middle) or 0
    end
    local bb = AlectoCore.pointToBbox(px, py, lineAlign(line),
        tonumber(line.width) or 0, tonumber(line.height) or 0)
    return bb.left, bb.cy
end

local function channelName(line)
    local flags = AlectoCore.parseFlags(line and line.actor or "")
    if flags.channel then return "actor:" .. flags.channel end
    local px, py = posOf(line and line.text or "")
    local an = lineAlign(line)
    if px ~= nil then
        return string.format("pos:%d:%d:an%d", round(px), round(py), an)
    end
    return "auto:an" .. tostring(an)
end

local function sameChannel(a, b)
    return channelName(a) == channelName(b)
end

local function simpleHash(s)
    local h = 5381
    s = tostring(s or "")
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
    return string.format("%08x", h)
end

local function sourceKey(line)
    return simpleHash(table.concat({
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

local function allocateSourceUid(line, index, used)
    local material = table.concat({
        sourceKey(line),
        tostring(index or 0),
        tostring(line.start_time or 0),
        tostring(line.end_time or 0),
        tostring(line.style or ""),
    }, "\31")
    local base = "u" .. simpleHash(material) .. simpleHash(material .. "\30alecto")
    local uid, suffix = base, 1
    while used[uid] do
        suffix = suffix + 1
        uid = base .. "-" .. suffix
    end
    used[uid] = true
    return uid
end

local inheritExclude = {
    pos = true, move = true, org = true, an = true, a = true,
    k = true, K = true, kf = true, ko = true, kt = true,
    fad = true, fade = true, t = true, p = true,
}

local function extractInheritTags(text, mode)
    if mode == "none" then return "" end
    local out = {}
    for _, tag in ipairs(parseTags(firstTagBlock(text))) do
        local name = tag.lname
        if not inheritExclude[name] then
            if tag.args ~= nil then out[#out + 1] = "\\" .. name .. "(" .. tostring(tag.args) .. ")"
            else out[#out + 1] = "\\" .. name .. tostring(tag.val or "") end
        end
    end
    return table.concat(out)
end

local function guideGeometry(line)
    local w = max(1, tonumber(line.width) or 1)
    local h = max(1, tonumber(line.height) or 1)
    local an = lineAlign(line)
    local tags = parseTags(firstTagBlock(line.text))
    local pval
    for _, tag in ipairs(tags) do
        if tag.lname == "p" and (tonumber(tag.val) or 0) > 0 then pval = tonumber(tag.val) end
    end
    if pval then
        local db = AlectoCore.drawingBbox(drawingText(line.text), pval)
        if db then w, h = max(1, db.width), max(1, db.height) end
    end

    local px, py = posOf(line.text, linePhase(line))
    local bb
    if px ~= nil then
        bb = AlectoCore.pointToBbox(px, py, an, w, h)
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

local function tokenRenderText(tok)
    if tok.text == "\\h" then return " " end
    if tok.control then return "" end
    return tok.text
end

local function charBoxes(styleref, text, totalWidth)
    local tokens = AlectoCore.assTokens(text)
    local widths, sum = {}, 0
    for i, tok in ipairs(tokens) do
        local sample = tokenRenderText(tok)
        local w = 0
        if sample ~= "" then
            if aegisub and aegisub.text_extents and styleref then
                local ok, ww = pcall(aegisub.text_extents, styleref, sample)
                if ok and tonumber(ww) and ww >= 0 then w = tonumber(ww) end
            end
            if w <= 0 then
                if tok.whitespace then w = config.fallback_space_width else w = config.fallback_char_width end
            end
        end
        widths[i] = w
        sum = sum + w
    end
    totalWidth = tonumber(totalWidth)
    if totalWidth and totalWidth > 0 and sum > 0 then
        local k = totalWidth / sum
        for i = 1, #widths do widths[i] = widths[i] * k end
    elseif totalWidth and totalWidth > 0 and sum == 0 and #widths > 0 then
        local each = totalWidth / #widths
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

local function fallbackKaraSyls(line)
    local segments, cursor = {}, 0
    local runs = splitRuns(line.text)
    for _, run in ipairs(runs) do
        local startOverride, dur
        for _, tag in ipairs(parseTags(run.tags)) do
            if tag.lname == "kt" then startOverride = (tonumber(tag.val) or 0) * 10
            elseif tag.lname == "k" or tag.lname == "kf" or tag.lname == "ko" then
                dur = (tonumber(tag.val) or 0) * 10
            end
        end
        if startOverride then cursor = startOverride end
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
    local totalWidth = max(1, tonumber(line.width) or 1)
    local rawWidths, sum = {}, 0
    for i, s in ipairs(segments) do
        local w = 0
        for _, b in ipairs(charBoxes(line.styleref, s.text)) do w = w + b.width end
        rawWidths[i] = w
        sum = sum + w
    end
    local x = 0
    for i, s in ipairs(segments) do
        local w = sum > 0 and rawWidths[i] / sum * totalWidth or totalWidth / #segments
        s.left_rel, s.right_rel = x, x + w
        x = x + w
    end
    return segments
end

local function collectSyls(line)
    if tostring(line.text or ""):lower():find("\\kt%s*%d") then
        return fallbackKaraSyls(line)
    end
    local raw = {}
    local kara = line.kara
    if type(kara) ~= "table" then return fallbackKaraSyls(line) end
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
                pending = shallowCopy(s)
            end
        end
    end
    if pending and #out > 0 then
        local lastOut = out[#out]
        lastOut.text = lastOut.text .. pending.text
        lastOut.right_rel = max(lastOut.right_rel, pending.right_rel)
    elseif pending then
        pending.end_rel = pending.start_rel + max(1, (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0))
        out[1] = pending
    end
    return out
end

local function appendText(a, b)
    if a == nil or a == "" then return tostring(b or "") end
    return a .. tostring(b or "")
end

local function buildUnits(line, syls, unit, styleref)
    if #syls == 0 then return {} end
    if unit == "syl" then
        local out = {}
        for _, s in ipairs(syls) do out[#out + 1] = shallowCopy(s) end
        return out
    end
    if unit == "line" then
        local first, last = syls[1], syls[#syls]
        local text = ""
        for _, s in ipairs(syls) do text = appendText(text, s.text) end
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
            local boxes = charBoxes(styleref, s.text, s.right_rel - s.left_rel)
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
        local boxes = charBoxes(styleref, s.text, s.right_rel - s.left_rel)
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

local function scanGaps(subs, line, sourceIndex)
    local gp, gn = math.huge, math.huge
    for i = 1, #subs do
        local s = subs[i]
        if s.class == "dialogue" and s.style == line.style
            and not isFxLine(s)
            and not linePhase(s)
            and sameChannel(s, line)
            and ((not s.comment) or trim(s.effect or ""):lower() == "karaoke" or hasKara(s.text))
            and i ~= sourceIndex then
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

local function makeLine(base, guide, startMs, endMs, text, key, phase)
    local s = max(0, round(startMs))
    local e = round(endMs)
    if e <= s then return nil end
    local l = copyLine(base)
    for _, k in ipairs({ "styleref", "kara", "text_stripped", "duration", "width", "height",
        "left", "center", "right", "top", "middle", "bottom" }) do l[k] = nil end
    l.layer = tonumber(guide.layer) or tonumber(base.layer) or 0
    l.comment = false
    l.start_time = s
    l.end_time = e
    local cbit = base._alecto_original_comment and "1" or "0"
    local uid = base._alecto_source_uid
    l.extra = cloneExtra(base.extra)
    l.extra[sourceExtraKey] = nil
    l._alecto_original_comment = nil
    l._alecto_source_key = nil
    l._alecto_source_uid = nil
    if uid then
        l.effect = config.fx_marker .. ":" .. tostring(uid) .. ":" .. tostring(key) .. ":" .. tostring(phase) .. ":c" .. cbit
    else
        l.effect = config.fx_marker .. ":" .. tostring(key) .. ":" .. tostring(phase) .. ":c" .. cbit
    end
    l.text = text
    return l
end

local function neutralGuide(phase, layer)
    return AlectoCore.parseGuide(phase, tonumber(layer) or 0, "", {
        left = 0, right = 1, top = 0, bottom = 1,
        width = 1, height = 1, cx = 0, cy = 0, dur = 1000,
    }, "")
end

local function resolveMs(guide, targetFlags, name, fallback)
    local gv = guide.flags and guide.flags[name]
    if gv ~= nil then return gv end
    local tv = targetFlags and targetFlags[name]
    if tv ~= nil then return tv end
    return fallback
end

local function guideApplies(guide, targetFlags)
    local gg = guide.flags and guide.flags.group or nil
    local tg = targetFlags and targetFlags.group or nil
    if tg then return gg == nil or gg == tg end
    return gg == nil
end

local function targetIsDrawing(line)
    for _, tag in ipairs(parseTags(firstTagBlock(line.text))) do
        if tag.lname == "p" and (tonumber(tag.val) or 0) > 0 then return true end
    end
    return false
end

local generationCancelled = {}
local generationLimit = {}

local function checkGenerationCancel(control)
    if control and type(control.is_cancelled) == "function" and control.is_cancelled() then
        error(generationCancelled, 0)
    end
end

local function checkGenerationCapacity(control, count)
    local limit = control and tonumber(control.max_events)
    if limit and count >= max(0, floor(limit)) then error(generationLimit, 0) end
end

local function generateForLine(line, guides, gp, gn, control)
    checkGenerationCancel(control)
    if targetIsDrawing(line) then
        error("Los targets vectoriales (\\p) no se compilan como texto. Usa el dibujo en un clip de guia o conviertelo en un target de texto.")
    end
    local out = {}
    local l0 = tonumber(line.start_time) or 0
    local l1 = tonumber(line.end_time) or l0
    if l1 <= l0 then return out end
    local lx, lmid = lineAnchor(line)
    local lh = max(1, tonumber(line.height) or 1)
    local targetFlags = AlectoCore.parseFlags(line.actor)
    local isKara = hasKara(line.text)
    local syls
    if isKara then
        syls = collectSyls(line)
    else
        local plain = tostring(line.text_stripped or visibleText(line.text))
        syls = { {
            text = plain,
            start_rel = 0,
            end_rel = l1 - l0,
            left_rel = 0,
            right_rel = max(1, tonumber(line.width) or 1),
        } }
    end
    if #syls == 0 then return out end

    local unitCache = {}
    local function unitsFor(unit)
        if not unitCache[unit] then unitCache[unit] = buildUnits(line, syls, unit, line.styleref) end
        return unitCache[unit]
    end

    local key = line._alecto_source_key or sourceKey(line)
    local function appendEvent(guide, phase, startMs, endMs, ctx)
        if endMs <= startMs then return end
        checkGenerationCancel(control)
        checkGenerationCapacity(control, #out)
        ctx.p_dur = max(1, endMs - startMs)
        local rendered = AlectoCore.renderEvent(guide, ctx)
        local l = makeLine(line, guide, startMs, endMs, rendered, key, phase)
        if l then out[#out + 1] = l end
    end

    local function emit(guide, phase)
        checkGenerationCancel(control)
        if not guideApplies(guide, targetFlags) then return end
        local defunit = guide.unit
        if not isKara and defunit == "syl" then defunit = "char" end
        local units = unitsFor(defunit)
        local n = #units
        if n == 0 then return end

        local nofade = guide.nofade or targetFlags.nofade
        local nostagger = guide.nostagger or targetFlags.nostagger
        local stag = nostagger and 0 or resolveMs(guide, targetFlags, "stagger_ms", config.stagger_ms)
        local fade = resolveMs(guide, targetFlags, "fade_ms", config.fade_ms)
        local lead = resolveMs(guide, targetFlags, "lead_ms", config.lead_ms)
        local tail = resolveMs(guide, targetFlags, "tail_ms", config.tail_ms)
        local gap = resolveMs(guide, targetFlags, "respiro_ms", config.respiro_ms)
        local leadCap = gp == math.huge and lead or gp - gap
        local tailCap = gn == math.huge and tail or gn - gap
        local leadEff = max(0, min(lead, leadCap))
        local tailEff = max(0, min(tail, tailCap))
        local order
        if guide.flags and guide.flags.explicit and guide.flags.explicit.order then order = guide.flags.order
        elseif targetFlags.explicit and targetFlags.explicit.order then order = targetFlags.order
        else order = config.default_order end
        local inheritMode
        if guide.flags and guide.flags.explicit and guide.flags.explicit.inherit then inheritMode = guide.flags.inherit
        elseif targetFlags.explicit and targetFlags.explicit.inherit then inheritMode = targetFlags.inherit
        else inheritMode = config.inherit_target_tags and "static" or "none" end
        local inheritTags = extractInheritTags(line.text, inheritMode)
        local maxRank = AlectoCore.orderMaxRank(n, order)

        for i, u in ipairs(units) do
            checkGenerationCancel(control)
            local rank = AlectoCore.orderRank(i, n, order)
            local ax = lx + (u.left_rel + u.right_rel) / 2
            local ay = lmid
            local ctx = {
                ax = ax, ay = ay,
                bx1 = lx + u.left_rel, by1 = lmid - lh / 2,
                bx2 = lx + u.right_rel, by2 = lmid + lh / 2,
                text = u.text,
                tokens = AlectoCore.assTokens(u.text),
                is_drawing = false,
                inherit_tags = inheritTags,
            }

            if isKara then
                local s0 = clamp(l0 + (tonumber(u.start_rel) or 0), l0, l1)
                local s1 = clamp(l0 + (tonumber(u.end_rel) or 0), s0, l1)
                if phase == "intro" then
                    local startMs = max(0, l0 - leadEff + rank * stag)
                    if s0 - startMs >= config.min_dur_ms then
                        ctx.t_off = 0
                        ctx.t_dur = s0 - startMs
                        if not nofade then
                            ctx.base_fade = { dir = "in", t1 = 0, t2 = min(fade, ctx.t_dur) }
                        end
                        appendEvent(guide, phase, startMs, s0, ctx)
                    end
                elseif phase == "active" then
                    ctx.t_off = 0
                    ctx.t_dur = max(1, s1 - s0)
                    appendEvent(guide, phase, s0, s1, ctx)
                else
                    local endMs = l1 + tailEff
                    local pdur = max(1, endMs - s1)
                    local fadeEnd = max(1, pdur - (maxRank - rank) * stag)
                    ctx.t_off = 0
                    ctx.t_dur = pdur
                    if not nofade then
                        ctx.base_fade = { dir = "out", t1 = max(0, fadeEnd - fade), t2 = fadeEnd }
                    end
                    appendEvent(guide, phase, s1, endMs, ctx)
                end
            else
                local totalEnd = l1 + tailEff
                local dur = max(1, l1 - l0)
                local fadeEff = min(fade, max(config.min_dur_ms, floor(dur / 4)))
                local span = maxRank * stag
                local exitw = min(max(config.min_dur_ms, (totalEnd - l0) / 2), fadeEff * 2 + span)
                local split = clamp(totalEnd - exitw, l0, totalEnd - 1)
                if phase == "intro" then
                    local startMs = max(0, l0 - leadEff + rank * stag)
                    if split - startMs >= config.min_dur_ms then
                        ctx.t_off = 0
                        ctx.t_dur = fadeEff
                        if not nofade then
                            ctx.base_fade = { dir = "in", t1 = 0, t2 = fadeEff }
                        end
                        appendEvent(guide, phase, startMs, split, ctx)
                    end
                elseif phase == "outro" then
                    local D = max(1, totalEnd - split)
                    local slot = max(0, D - fadeEff - (maxRank - rank) * stag)
                    ctx.t_off = slot
                    ctx.t_dur = fadeEff
                    if not nofade then
                        ctx.base_fade = { dir = "out", t1 = slot, t2 = min(D, slot + fadeEff) }
                    end
                    appendEvent(guide, phase, split, totalEnd, ctx)
                end
            end
        end
    end

    local phaseList = isKara and { "intro", "active", "outro" } or { "intro", "outro" }
    for _, phase in ipairs(phaseList) do
        checkGenerationCancel(control)
        local set, applied = guides[phase] or {}, 0
        for _, guide in ipairs(set) do
            checkGenerationCancel(control)
            if guideApplies(guide, targetFlags) then emit(guide, phase); applied = applied + 1 end
        end
        if applied == 0 then emit(neutralGuide(phase, line.layer), phase) end
    end
    return out
end

local function collectHeadChecked(subs)
    if not karaskel or type(karaskel.collect_head) ~= "function" then
        return nil, nil, "No se pudo cargar karaskel: " .. tostring(karaskelLoadError or "modulo incompatible")
    end
    local ok, meta, styles = pcall(karaskel.collect_head, subs, false)
    if not ok then return nil, nil, "No se pudo leer la cabecera de estilos: " .. tostring(meta) end
    return meta, styles
end

local function addUnique(list, seen, idx)
    idx = tonumber(idx)
    if idx and not seen[idx] then seen[idx] = true; list[#list + 1] = idx end
end

local function addIndex(map, key, index)
    if not key then return end
    local list = map[key]
    if not list then list = {}; map[key] = list end
    list[#list + 1] = index
end

local function buildSourceIndex(subs)
    local index = { by_uid = {}, by_key = {} }
    for i = 1, #subs do
        local l = subs[i]
        if l and l.class == "dialogue" and not isFxLine(l) and not linePhase(l) then
            local uid = parseSourceRecord(l)
            addIndex(index.by_uid, uid, i)
            addIndex(index.by_key, sourceKey(l), i)
        end
    end
    return index
end

local function uniqueIndex(map, key)
    local list = key and map[key] or nil
    if list and #list == 1 then return list[1] end
    return nil
end

local function adjacentSourceIndex(subs, fxIndex, marker)
    local j = (tonumber(fxIndex) or 0) - 1
    while j >= 1 and isFxLine(subs[j]) do j = j - 1 end
    local source = j >= 1 and subs[j] or nil
    if source and source.class == "dialogue" and not linePhase(source) and marker then
        local sourceUid = parseSourceRecord(source)
        if marker.uid and sourceUid == marker.uid then return j end
        if not marker.uid and marker.key and marker.key == sourceKey(source) then return j end
        if marker.version == 0 and source.comment then return j end
    end
    return nil
end

local function resolveSelection(subs, sel)
    local guideIdx, targetIdx = {}, {}
    local seenG, seenT = {}, {}
    local errors = {}
    local sourceIndex = buildSourceIndex(subs)
    for _, idx in ipairs(sel or {}) do
        local l = subs[idx]
        if l and l.class == "dialogue" then
            if linePhase(l) then
                addUnique(guideIdx, seenG, idx)
            elseif isFxLine(l) then
                local marker = parseFxMarker(l)
                local srcIdx = marker and uniqueIndex(sourceIndex.by_uid, marker.uid) or nil
                if not srcIdx then srcIdx = adjacentSourceIndex(subs, idx, marker) end
                if not srcIdx and marker and not marker.uid then
                    srcIdx = uniqueIndex(sourceIndex.by_key, marker.key)
                end
                if srcIdx then addUnique(targetIdx, seenT, srcIdx) end
                if not srcIdx then
                    errors[#errors + 1] = "Linea " .. idx .. ": no se pudo resolver el source del FX sin ambiguedad."
                end
            else
                addUnique(targetIdx, seenT, idx)
            end
        end
    end
    table.sort(guideIdx)
    table.sort(targetIdx)
    return guideIdx, targetIdx, errors
end

local function discoverGuidesAbove(subs, targetIdx)
    local out, found = {}, false
    local i = (targetIdx or 1) - 1
    while i >= 1 do
        local l = subs[i]
        if l and l.class == "dialogue" then
            if isFxLine(l) then
            elseif linePhase(l) then
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

local function preprocessCopy(subs, meta, styles, idx)
    local src = copyLine(subs[idx])
    src.comment = false
    local ok, err = pcall(karaskel.preproc_line, subs, meta, styles, src)
    if not ok then return nil, tostring(err) end
    return src
end

local function compileGuides(subs, meta, styles, guideIdx)
    local guides = { intro = {}, active = {}, outro = {} }
    local warnings, errors = {}, {}
    for _, idx in ipairs(guideIdx) do
        local src, err = preprocessCopy(subs, meta, styles, idx)
        if not src then
            errors[#errors + 1] = "Guia en linea " .. idx .. ": " .. tostring(err)
        else
            local phase = linePhase(src)
            local geom = guideGeometry(src)
            local g = AlectoCore.parseGuide(phase, tonumber(src.layer) or 0, src.text, geom, src.actor)
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

local function progressIsCancelled()
    if not aegisub or not aegisub.progress or type(aegisub.progress.is_cancelled) ~= "function" then return false end
    local ok, cancelled = pcall(aegisub.progress.is_cancelled)
    return ok and cancelled and true or false
end

local function progressCancelled(done, total, label)
    if not aegisub or not aegisub.progress then return false end
    if aegisub.progress.set then pcall(aegisub.progress.set, total > 0 and done / total * 100 or 0) end
    if aegisub.progress.task then pcall(aegisub.progress.task, script_name .. ": " .. tostring(label or "") .. " " .. done .. "/" .. total) end
    return progressIsCancelled()
end

local function adjacentFxMarker(subs, index)
    local source = subs[index]
    local sourceUid = parseSourceRecord(source)
    local key = sourceKey(source)
    local j = (tonumber(index) or 0) + 1
    while j <= #subs and isFxLine(subs[j]) do
        local marker = parseFxMarker(subs[j])
        if marker and marker.uid then
            if (sourceUid and marker.uid == sourceUid)
                or (not sourceUid and marker.key == key) then
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

local function collectUsedUids(subs)
    local used = {}
    for i = 1, #subs do
        local sourceUid = parseSourceRecord(subs[i])
        local outputUid = fxSourceUid(subs[i])
        if sourceUid then used[sourceUid] = true end
        if outputUid then used[outputUid] = true end
    end
    return used
end

local function buildIdentityPlan(subs, index, sourceIndex, used, reserved)
    local source = subs[index]
    local key = sourceKey(source)
    local storedUid, storedComment = parseSourceRecord(source)
    local marker = adjacentFxMarker(subs, index)
    local markerOwners = marker and marker.uid and sourceIndex.by_uid[marker.uid] or nil
    if marker and marker.uid and markerOwners
        and (#markerOwners ~= 1 or markerOwners[1] ~= index) then
        marker = nil
        markerOwners = nil
    end
    local uid, cleanupUid, globalUid
    local owners = storedUid and sourceIndex.by_uid[storedUid] or nil
    if storedUid and owners and #owners == 1 and owners[1] == index and not reserved[storedUid] then
        uid = storedUid
        cleanupUid = storedUid
        globalUid = true
    elseif marker and marker.uid then
        owners = markerOwners
        if not reserved[marker.uid] and (not owners or (#owners == 1 and owners[1] == index)) then
            uid = marker.uid
            cleanupUid = marker.uid
            globalUid = owners ~= nil
        end
    end
    if not uid then uid = allocateSourceUid(source, index, used) end
    used[uid] = true
    reserved[uid] = true
    return {
        index = index,
        key = key,
        uid = uid,
        cleanup_uid = cleanupUid,
        adjacent_uid = marker and marker.uid or nil,
        adjacent_key = marker and marker.key or nil,
        adjacent_version = marker and marker.version or nil,
        global_uid = globalUid and true or false,
        stored_comment = storedComment,
    }
end

local function inferOriginalComment(subs, plan, sourceIndex)
    if plan.stored_comment ~= nil then return plan.stored_comment end
    local sawAdjacent = false
    local j = (tonumber(plan.index) or 0) + 1
    while j <= #subs and isFxLine(subs[j]) do
        local marker = parseFxMarker(subs[j])
        if marker and (
            (marker.version == 0 and plan.adjacent_version == 0)
            or (marker.uid and (marker.uid == plan.cleanup_uid or marker.uid == plan.adjacent_uid))
            or (not marker.uid and marker.key and marker.key == plan.adjacent_key)
        ) then
            sawAdjacent = true
            if marker.original_comment ~= nil then return marker.original_comment end
        end
        j = j + 1
    end
    if sawAdjacent then return false end
    if plan.global_uid and plan.cleanup_uid then
        for i = 1, #subs do
            local marker = parseFxMarker(subs[i])
            if marker and marker.uid == plan.cleanup_uid and marker.original_comment ~= nil then
                return marker.original_comment
            end
        end
    end
    local owners = sourceIndex.by_key[plan.key]
    if owners and #owners == 1 then
        for i = 1, #subs do
            local marker = parseFxMarker(subs[i])
            if marker and not marker.uid and marker.key == plan.key and marker.original_comment ~= nil then
                return marker.original_comment
            end
        end
    else
        for i = 1, #subs do
            local marker = parseFxMarker(subs[i])
            if marker and marker.key == plan.key and not marker.uid then
                return nil, "las marcas 3.1 de este target son ambiguas porque existen sources identicos y el FX no esta junto a su origen"
            elseif marker and marker.key == plan.key and marker.uid then
                local uidOwners = sourceIndex.by_uid[marker.uid]
                if not uidOwners or #uidOwners ~= 1 then
                    return nil, "la procedencia UID de este target es ambigua porque el FX no esta junto a un source identificable"
                end
            end
        end
    end
    return subs[plan.index] and subs[plan.index].comment and true or false
end

local function collectCleanupIndices(subs, plans)
    local remove = {}
    local sourceIndex = buildSourceIndex(subs)
    for _, plan in ipairs(plans) do
        local j = plan.index + 1
        while j <= #subs and isFxLine(subs[j]) do
            local marker = parseFxMarker(subs[j])
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
                if fxSourceUid(subs[i]) == plan.cleanup_uid then remove[i] = true end
            end
        end
        local owners = sourceIndex.by_key[plan.key]
        if owners and #owners == 1 then
            for i = 1, #subs do
                local marker = parseFxMarker(subs[i])
                if marker and not marker.uid and marker.key == plan.key then remove[i] = true end
            end
        end
    end
    local out = {}
    for i in pairs(remove) do out[#out + 1] = i end
    table.sort(out, function(a, b) return a > b end)
    return out
end

local function shiftIndicesAfterDelete(plans, guideIdx, deleted)
    for _, plan in ipairs(plans) do if plan.index > deleted then plan.index = plan.index - 1 end end
    for i = 1, #guideIdx do if guideIdx[i] > deleted then guideIdx[i] = guideIdx[i] - 1 end end
end

local function selectionFromPlans(plans, generated)
    table.sort(plans, function(a, b) return a.index < b.index end)
    local selected, shift = {}, 0
    for _, plan in ipairs(plans) do
        if generated then
            for i = 1, #plan.lines do selected[#selected + 1] = plan.index + shift + i end
            shift = shift + #plan.lines
        else
            selected[#selected + 1] = plan.index
        end
    end
    return selected, selected[1]
end

local function apply(subs, sel)
    sel = sel or {}
    if not LineOps or type(LineOps.transaction) ~= "function" then
        showMessage("Falta kite.LineOps 1.5.0 o superior; no se puede aplicar de forma transaccional.")
        return
    end
    if #sel == 0 then
        showMessage("Selecciona las guias intro/active/outro y/o las lineas objetivo.")
        return
    end
    local meta, styles, headErr = collectHeadChecked(subs)
    if not meta then showMessage(headErr); return end

    local guideIdx, targetIdx, selectionErrors = resolveSelection(subs, sel)
    if #selectionErrors > 0 then
        showReport("Alecto KFX - seleccion ambigua", table.concat(selectionErrors, "\n"))
        return
    end
    if #targetIdx == 0 then showMessage("No hay lineas objetivo validas en la seleccion."); return end
    if #guideIdx == 0 then guideIdx = discoverGuidesAbove(subs, targetIdx[1]) end

    local guides, guideWarnings, guideErrors = compileGuides(subs, meta, styles, guideIdx)
    if #guideErrors > 0 then showReport("Alecto KFX - error de guias", table.concat(guideErrors, "\n")); return end

    local plans, errors = {}, {}
    local totalEvents = 0
    local sourceIndex = buildSourceIndex(subs)
    local usedUids, reservedUids = collectUsedUids(subs), {}
    for ni, idx in ipairs(targetIdx) do
        if progressCancelled(ni - 1, #targetIdx, "analizando") then
            showMessage("Operacion cancelada sin cambios.")
            return
        end
        local plan = buildIdentityPlan(subs, idx, sourceIndex, usedUids, reservedUids)
        local originalComment, identityError = inferOriginalComment(subs, plan, sourceIndex)
        if identityError then
            showReport("Alecto KFX - procedencia ambigua", "Linea " .. idx .. ": " .. identityError .. ".\nNo se modifico el archivo.")
            return
        end
        local src, err = preprocessCopy(subs, meta, styles, idx)
        if src then
            src._alecto_original_comment = originalComment
            src._alecto_source_uid = plan.uid
        end
        if not src then
            errors[#errors + 1] = "Linea " .. idx .. ": fallo el preprocesado: " .. tostring(err)
        else
            local gp, gn = scanGaps(subs, src, idx)
            local control = {
                max_events = config.max_generated_events > 0 and config.max_generated_events - totalEvents or nil,
                is_cancelled = progressIsCancelled,
            }
            local okg, lines = pcall(generateForLine, src, guides, gp, gn, control)
            if not okg then
                if lines == generationCancelled then
                    showMessage("Operacion cancelada sin cambios.")
                    return
                elseif lines == generationLimit then
                    showMessage("Se aborta antes de modificar el archivo: la seleccion produciria mas de "
                        .. config.max_generated_events .. " eventos. Reduce targets/unidades o aumenta el limite en Configurar.")
                    return
                else
                    errors[#errors + 1] = "Linea " .. idx .. ": " .. tostring(lines)
                end
            elseif #lines == 0 then
                errors[#errors + 1] = "Linea " .. idx .. ": no produjo eventos; revisa texto, tiempos y unidades."
            else
                totalEvents = totalEvents + #lines
                plan.original_comment = originalComment
                plan.lines = lines
                plans[#plans + 1] = plan
            end
        end
    end
    if progressCancelled(#targetIdx, #targetIdx, "listo") then
        showMessage("Operacion cancelada sin cambios.")
        return
    end
    if #plans == 0 then
        local msg = #errors > 0 and table.concat(errors, "\n") or "No se genero nada."
        showReport("Alecto KFX - sin cambios", msg)
        return
    end

    local cleanup = collectCleanupIndices(subs, plans)
    LineOps.transaction(subs, script_name .. " (aplicar)", function()
        for _, idx in ipairs(cleanup) do
            LineOps.checkCancelled()
            subs.delete(idx)
            shiftIndicesAfterDelete(plans, guideIdx, idx)
        end

        for _, idx in ipairs(guideIdx) do
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
            src.extra = cloneExtra(src.extra)
            src.extra[sourceExtraKey] = encodeSourceRecord(plan.uid, plan.original_comment)
            subs[plan.index] = src
            for i = #plan.lines, 1, -1 do
                LineOps.checkCancelled()
                subs.insert(plan.index + 1, plan.lines[i])
            end
        end
    end)

    local report = {
        "Targets compilados: " .. #plans,
        "Eventos generados: " .. totalEvents,
        "Eventos previos reemplazados: " .. #cleanup,
    }
    for _, w in ipairs(guideWarnings) do report[#report + 1] = "AVISO: " .. w end
    for _, e in ipairs(errors) do report[#report + 1] = "ERROR NO APLICADO: " .. e end
    if #guideWarnings > 0 or #errors > 0 then showReport("Alecto KFX - resultado", table.concat(report, "\n"))
    else showMessage(table.concat(report, " | ")) end
    return selectionFromPlans(plans, true)
end

local function removeGenerated(subs, sel)
    sel = sel or {}
    if not LineOps or type(LineOps.transaction) ~= "function" then
        showMessage("Falta kite.LineOps 1.5.0 o superior; no se puede limpiar de forma transaccional.")
        return
    end
    if #sel == 0 then showMessage("Selecciona targets originales o eventos Alecto generados."); return end
    local _, targetIdx, selectionErrors = resolveSelection(subs, sel)
    if #selectionErrors > 0 then
        showReport("Alecto KFX - seleccion ambigua", table.concat(selectionErrors, "\n"))
        return
    end
    if #targetIdx == 0 then showMessage("No se pudo localizar ningun target de origen."); return end
    local plans = {}
    local sourceIndex = buildSourceIndex(subs)
    local usedUids, reservedUids = collectUsedUids(subs), {}
    for _, idx in ipairs(targetIdx) do
        local plan = buildIdentityPlan(subs, idx, sourceIndex, usedUids, reservedUids)
        local originalComment, identityError = inferOriginalComment(subs, plan, sourceIndex)
        if identityError then
            showReport("Alecto KFX - procedencia ambigua", "Linea " .. idx .. ": " .. identityError .. ".\nNo se modifico el archivo.")
            return
        end
        plan.original_comment = originalComment
        plans[#plans + 1] = plan
    end
    local cleanup = collectCleanupIndices(subs, plans)
    if #cleanup == 0 then showMessage("No hay eventos Alecto asociados a la seleccion."); return end
    LineOps.transaction(subs, script_name .. " (limpiar seleccion)", function()
        for _, idx in ipairs(cleanup) do
            LineOps.checkCancelled()
            subs.delete(idx)
            shiftIndicesAfterDelete(plans, {}, idx)
        end
        for _, plan in ipairs(plans) do
            local l = subs[plan.index]
            if l and l.class == "dialogue" then
                l.comment = plan.original_comment and true or false
                l.extra = cloneExtra(l.extra)
                l.extra[sourceExtraKey] = nil
                subs[plan.index] = l
            end
        end
    end)
    showMessage("Eventos eliminados: " .. #cleanup .. ". Targets restaurados: " .. #plans .. ".")
    return selectionFromPlans(plans)
end

local function generateBases(subs, sel)
    sel = sel or {}
    if not LineOps or type(LineOps.transaction) ~= "function" then
        showMessage("Falta kite.LineOps 1.5.0 o superior; no se pueden insertar bases de forma transaccional.")
        return
    end
    if #sel == 0 then showMessage("Selecciona una o mas lineas target."); return end
    local meta, styles, headErr = collectHeadChecked(subs)
    if not meta then showMessage(headErr); return end
    local _, targets, selectionErrors = resolveSelection(subs, sel)
    if #selectionErrors > 0 then
        showReport("Alecto KFX - seleccion ambigua", table.concat(selectionErrors, "\n"))
        return
    end
    if #targets == 0 then showMessage("No hay targets validos."); return end

    local lastEnd = 0
    for i = 1, #subs do
        local l = subs[i]
        if l.class == "dialogue" and (not l.comment or linePhase(l)) and not isFxLine(l) then
            lastEnd = max(lastEnd, tonumber(l.end_time) or 0)
        end
    end

    table.sort(targets, function(a, b)
        local left, right = subs[a], subs[b]
        local leftStart = tonumber(left and left.start_time) or 0
        local rightStart = tonumber(right and right.start_time) or 0
        if leftStart == rightStart then return a < b end
        return leftStart < rightStart
    end)
    local t0, plans, errors = lastEnd + config.base_offset_ms, {}, {}
    for ti, idx in ipairs(targets) do
        if progressCancelled(ti - 1, #targets, "preparando bases") then
            showMessage("Operacion cancelada sin cambios.")
            return
        end
        local src, err = preprocessCopy(subs, meta, styles, idx)
        if not src then
            errors[#errors + 1] = "Linea " .. idx .. ": " .. tostring(err)
        else
            local lx, lmid = lineAnchor(src)
            local cx = lx + (tonumber(src.width) or 0) / 2
            local text = tostring(src.text_stripped or visibleText(src.text))
            text = trim(text:gsub("\\[Nnh]", " "))
            if text ~= "" then
                local kara = hasKara(src.text)
                local phases = kara and { "intro", "active", "outro" } or { "intro", "outro" }
                local tf = AlectoCore.parseFlags(src.actor)
                local actor = kara and "syl" or "char"
                if tf.group then actor = actor .. " group=" .. tf.group end
                if tf.channel then actor = actor .. " channel=" .. tf.channel end
                local newLines = {}
                for pi, phase in ipairs(phases) do
                    if progressIsCancelled() then
                        showMessage("Operacion cancelada sin cambios.")
                        return
                    end
                    local g = copyLine(subs[idx])
                    g.extra = cloneExtra(g.extra)
                    g.extra[sourceExtraKey] = nil
                    g.comment = false
                    g.layer = tonumber(src.layer) or 0
                    g.actor = actor
                    g.effect = phase
                    g.start_time = t0 + (pi - 1) * (config.base_len_ms + config.base_gap_ms)
                    g.end_time = g.start_time + config.base_len_ms
                    g.text = "{\\an5\\pos(" .. fmtNum(cx) .. "," .. fmtNum(lmid) .. ")}" .. text
                    newLines[#newLines + 1] = g
                end
                plans[#plans + 1] = { index = idx, lines = newLines }
                t0 = t0 + #phases * (config.base_len_ms + config.base_gap_ms) + config.base_block_gap_ms
            else
                errors[#errors + 1] = "Linea " .. idx .. ": texto vacio tras quitar tags."
            end
        end
    end
    if #errors > 0 then
        showReport("Alecto KFX - generar bases", table.concat(errors, "\n") .. "\nNo se modifico el archivo.")
        return
    end
    if progressCancelled(#targets, #targets, "bases listas") then
        showMessage("Operacion cancelada sin cambios.")
        return
    end
    table.sort(plans, function(a, b) return a.index > b.index end)
    if #plans > 0 then
        LineOps.transaction(subs, script_name .. " (bases)", function()
            for _, plan in ipairs(plans) do
                for i = #plan.lines, 1, -1 do
                    LineOps.checkCancelled()
                    subs.insert(plan.index + 1, plan.lines[i])
                end
            end
        end)
    end
    showMessage("Bloques de guias creados: " .. #plans .. ".")
    return selectionFromPlans(plans, true)
end

local function formatMs(ms)
    ms = tonumber(ms) or 0
    return string.format("%.3fs", ms / 1000)
end

local function guideFlagSummary(g)
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

local function checkGuideSyntax(src, idx, report)
    local tags = parseTags(firstTagBlock(src.text))
    local posCount, moveCount, orgCount = 0, 0, 0
    for _, tag in ipairs(tags) do
        if tag.lname == "pos" then posCount = posCount + 1
        elseif tag.lname == "move" then
            moveCount = moveCount + 1
            if not parseMoveArgs(tag.args) then report[#report + 1] = "  AVISO: linea " .. idx .. " tiene \\move invalido." end
        elseif tag.lname == "org" then orgCount = orgCount + 1
        elseif tag.lname == "fade" and #parseNums(tag.args) ~= 7 then
            report[#report + 1] = "  AVISO: linea " .. idx .. " tiene \\fade sin 7 argumentos; se omitira."
        elseif tag.lname == "fad" and #parseNums(tag.args) < 2 then
            report[#report + 1] = "  AVISO: linea " .. idx .. " tiene \\fad incompleto."
        end
    end
    if posCount + moveCount > 1 then report[#report + 1] = "  AVISO: usa solo un \\pos o \\move por guia." end
    if orgCount > 1 then report[#report + 1] = "  AVISO: solo el primer \\org es util." end
end

local function validateSelection(subs, sel)
    sel = sel or {}
    if #sel == 0 then showMessage("Selecciona guias y/o targets para diagnosticar."); return end
    local meta, styles, headErr = collectHeadChecked(subs)
    if not meta then showMessage(headErr); return end
    local guideIdx, targetIdx, selectionErrors = resolveSelection(subs, sel)
    if #selectionErrors > 0 then
        showReport("Alecto KFX - seleccion ambigua", table.concat(selectionErrors, "\n"))
        return
    end
    if #guideIdx == 0 and #targetIdx > 0 then guideIdx = discoverGuidesAbove(subs, targetIdx[1]) end
    local guides, guideWarnings, guideErrors = compileGuides(subs, meta, styles, guideIdx)

    local report = {
        "Alecto KFX " .. script_version,
        "Resolucion: " .. tostring(meta.res_x or "?") .. "x" .. tostring(meta.res_y or "?"),
        "Configuracion: lead=" .. config.lead_ms .. "ms, tail=" .. config.tail_ms
            .. "ms, fade=" .. config.fade_ms .. "ms, stagger=" .. config.stagger_ms
            .. "ms, gap=" .. config.respiro_ms .. "ms",
        "Guias: " .. #guideIdx .. " | Targets: " .. #targetIdx,
        "",
    }

    if #guideIdx == 0 then
        report[#report + 1] = "GUIAS: ninguna; se usaran guias neutras para las fases aplicables."
    else
        report[#report + 1] = "GUIAS"
        for _, phase in ipairs({ "intro", "active", "outro" }) do
            for _, g in ipairs(guides[phase]) do
                local geom = g.geom
                report[#report + 1] = string.format("- L%d %s | %s | dur=%s | bbox=%.1fx%.1f",
                    g.source_index or 0, phase, guideFlagSummary(g), formatMs(geom.dur), geom.width, geom.height)
                if g.samples then
                    report[#report + 1] = "  Curvas: " .. table.concat(g.samples.props, ", ")
                end
                local src = subs[g.source_index]
                if src then checkGuideSyntax(src, g.source_index, report) end
            end
        end
    end
    for _, w in ipairs(guideWarnings) do report[#report + 1] = "  AVISO: " .. w end
    for _, e in ipairs(guideErrors) do report[#report + 1] = "  ERROR: " .. e end

    report[#report + 1] = ""
    report[#report + 1] = "TARGETS"
    local total, limitReached = 0, false
    for ni, idx in ipairs(targetIdx) do
        if progressCancelled(ni - 1, #targetIdx, "validando") then
            showMessage("Diagnostico cancelado sin cambios.")
            return
        end
        local src, err = preprocessCopy(subs, meta, styles, idx)
        if not src then
            report[#report + 1] = "- L" .. idx .. " ERROR preprocesando: " .. tostring(err)
        else
            local kind = hasKara(src.text) and "karaoke" or "TL"
            local units = hasKara(src.text) and collectSyls(src) or {}
            local extra = hasKara(src.text) and (" | silabas=" .. #units) or ""
            report[#report + 1] = "- L" .. idx .. " " .. kind .. " | " .. formatMs(src.end_time - src.start_time)
                .. " | style=" .. tostring(src.style) .. " | key=" .. sourceKey(src) .. extra
            if trim(src.text_stripped or visibleText(src.text)) == "" then
                report[#report + 1] = "  ERROR: texto visible vacio."
            end
            if targetIsDrawing(src) then report[#report + 1] = "  ERROR: target vectorial \\p no soportado." end
            if tostring(src.text):find("\\[Nn]") then
                report[#report + 1] = "  AVISO: target multilinea; para geometria fiable usa unit=line o divide el texto en eventos separados."
            end
            local targetOptions = AlectoCore.parseFlags(src.actor)
            for _, tok in ipairs(targetOptions.unknown or {}) do
                report[#report + 1] = "  AVISO: variable de Actor desconocida '" .. tok .. "'."
            end
            if tostring(src.text):lower():find("\\kt%s*%d") then
                report[#report + 1] = "  AVISO: contiene \\kt; Alecto usa su parser alternativo porque karaskel no lo procesa de forma nativa."
            end
            local gp, gn = scanGaps(subs, src, idx)
            report[#report + 1] = "  Hueco previo=" .. (gp == math.huge and "libre" or (gp .. "ms"))
                .. " | siguiente=" .. (gn == math.huge and "libre" or (gn .. "ms"))
            local control = {
                max_events = config.max_generated_events > 0 and config.max_generated_events - total or nil,
                is_cancelled = progressIsCancelled,
            }
            local okg, lines = pcall(generateForLine, src, guides, gp, gn, control)
            if okg then
                total = total + #lines
                local bad = 0
                for _, l in ipairs(lines) do if l.end_time <= l.start_time then bad = bad + 1 end end
                report[#report + 1] = "  Estimacion: " .. #lines .. " eventos" .. (bad > 0 and (" | INVALIDOS=" .. bad) or "")
            elseif lines == generationCancelled then
                showMessage("Diagnostico cancelado sin cambios.")
                return
            elseif lines == generationLimit then
                total = config.max_generated_events + 1
                limitReached = true
                report[#report + 1] = "  ERROR: la estimacion supera el limite configurado."
            else
                report[#report + 1] = "  ERROR generando: " .. tostring(lines)
            end
        end
        if limitReached then break end
    end
    report[#report + 1] = ""
    report[#report + 1] = "TOTAL ESTIMADO: " .. total .. " eventos (limite configurado: " .. config.max_generated_events .. ")."
    if config.max_generated_events > 0 and total > config.max_generated_events then report[#report + 1] = "ERROR: excede el limite; Aplicar abortaria antes de modificar el archivo." end
    showReport("Alecto KFX - diagnostico", table.concat(report, "\n"))
end

local function restoreDefaultConfig()
    for k, v in pairs(configDefault) do config[k] = v end
end

local function configure()
    if not aegisub or not aegisub.dialog or not aegisub.dialog.display then
        showMessage("Los diálogos de Aegisub no están disponibles.")
        return
    end
    local dialog = {
        { class = "label", label = "Alecto KFX - configuración (tiempos en ms)", x = 0, y = 0, width = 4 },
        { class = "label", label = "Entrada (lead)", x = 0, y = 1 },
        { class = "intedit", name = "lead", value = config.lead_ms, min = 0, x = 1, y = 1 },
        { class = "label", label = "Salida (tail)", x = 2, y = 1 },
        { class = "intedit", name = "tail", value = config.tail_ms, min = 0, x = 3, y = 1 },
        { class = "label", label = "Fade base", x = 0, y = 2 },
        { class = "intedit", name = "fade", value = config.fade_ms, min = 0, x = 1, y = 2 },
        { class = "label", label = "Stagger", x = 2, y = 2 },
        { class = "intedit", name = "stagger", value = config.stagger_ms, min = 0, x = 3, y = 2 },
        { class = "label", label = "Respiro entre líneas", x = 0, y = 3 },
        { class = "intedit", name = "gap", value = config.respiro_ms, min = 0, x = 1, y = 3 },
        { class = "label", label = "Duración mínima", x = 2, y = 3 },
        { class = "intedit", name = "mindur", value = config.min_dur_ms, min = 1, x = 3, y = 3 },
        { class = "label", label = "Límite de eventos", x = 0, y = 4, hint = "0: sin límite" },
        { class = "intedit", name = "maxevents", value = config.max_generated_events, min = 0, x = 1, y = 4, hint = "0: sin límite" },
        { class = "label", label = "Orden por defecto", x = 2, y = 4 },
        { class = "dropdown", name = "order", items = { "ltr", "rtl", "center", "edges" }, value = config.default_order, x = 3, y = 4 },
        { class = "checkbox", name = "inherit", label = "Heredar tags estáticos iniciales del target", value = config.inherit_target_tags, x = 0, y = 5, width = 4 },
        { class = "label", label = "Los valores del Actor (fade=, stagger=, etc.) tienen prioridad.", x = 0, y = 6, width = 4 },
    }
    local button, result
    repeat
        button, result = aegisub.dialog.display(dialog,
            { "Guardar", "Ayuda", "Restaurar", "Cancelar" }, { ok = "Guardar", close = "Cancelar" })
        if not button or button == "Cancelar" then return end
        if button == "Ayuda" then
            for _, control in ipairs(dialog) do
                if control.name then control.value = result[control.name] end
            end
            showHelp()
        end
    until button ~= "Ayuda"
    if button == "Restaurar" then
        restoreDefaultConfig()
        configStore:update("main",config)
        local saved,message=configStore:write()
        showMessage(saved and "Configuración restaurada y guardada." or tostring(message))
        return
    end
    if button ~= "Guardar" then return end
    config.lead_ms = max(0, tonumber(result.lead) or config.lead_ms)
    config.tail_ms = max(0, tonumber(result.tail) or config.tail_ms)
    config.fade_ms = max(0, tonumber(result.fade) or config.fade_ms)
    config.stagger_ms = max(0, tonumber(result.stagger) or config.stagger_ms)
    config.respiro_ms = max(0, tonumber(result.gap) or config.respiro_ms)
    config.min_dur_ms = max(1, tonumber(result.mindur) or config.min_dur_ms)
    config.max_generated_events = max(0, tonumber(result.maxevents) or config.max_generated_events)
    config.default_order = validOrders[result.order] and result.order or config.default_order
    config.inherit_target_tags = result.inherit and true or false
    configStore:update("main",config)
    local saved,message=configStore:write()
    showMessage(saved and "Configuración guardada." or tostring(message))
end

local function mainDialog(subs, selection)
    local operations={"Aplicar guías","Generar líneas base","Validar selección","Limpiar FX seleccionados","Configurar"}
    local functions={apply,generateBases,validateSelection,removeGenerated,configure}
    local button,result=aegisub.dialog.display({
        {class="label",label=script_name.." - guías intro, active y outro",x=0,y=0,width=4},
        {class="label",label="Operación",x=0,y=1},
        {class="dropdown",name="operation",items=operations,value=operations[1],x=1,y=1,width=3},
        {class="label",label=tostring(#(selection or {})).." líneas seleccionadas",x=0,y=2,width=4},
    },{"Ejecutar","Cancelar"},{ok="Ejecutar",close="Cancelar"})
    if button~="Ejecutar" then return selection end
    for index,name in ipairs(operations) do if result.operation==name then return functions[index](subs,selection) end end
end

if aegisub and aegisub.register_macro then
    local entries = {
        { script_name, script_description, mainDialog },
        { script_name .. "/Aplicar", "Compila las guias intro/active/outro sobre los targets seleccionados", apply },
        { script_name .. "/Generar lineas base", "Crea guias editables a partir de los targets seleccionados", generateBases },
        { script_name .. "/Validar seleccion", "Diagnostica guias, targets, tags, huecos y numero de eventos sin modificar", validateSelection },
        { script_name .. "/Limpiar FX seleccionados", "Elimina solo el FX asociado a los targets seleccionados y restaura los originales", removeGenerated },
        { script_name .. "/Configurar", "Guarda los valores predeterminados de Alecto", configure },
        { script_name .. "/Ayuda y comandos", "Muestra los comandos del menu y todas las opciones disponibles en Actor", showHelp },
    }
    for _, e in ipairs(entries) do
        if depctrl and depctrl.registerMacro then
            depctrl:registerMacro(e[1], e[2], e[3], nil, nil, false)
        else
            aegisub.register_macro(e[1], e[2], e[3])
        end
    end
end

require("kite.UI").publishActions()
