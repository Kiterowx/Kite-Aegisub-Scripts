local DependencyControl = require("l0.DependencyControl")
local depctrl = DependencyControl({
    name = "kite.Timing",
    version = "1.5.0",
    description = "Voice-timing engines: multi-signal/waveform onset detection and legacy silence timing",
    author = "Kiterow",
    url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
    moduleName = "kite.Timing",
    feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    {
        {"kite.Core", version = "2.0.0", feed= "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.PyBridge", version = "2.0.1", feed= "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.UI", version = "2.0.1", feed= "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.AssContext", version = "2.0.1", feed= "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
    },
})
depctrl:requireModules()

local moduleVersion = "1.5.0"
local function tryRequire(name) local ok, value = pcall(require, name); if ok then return value end end
local Core = assert(tryRequire("kite.Core"), "kite.Core is required")
local LineOps = assert(tryRequire("kite.Core"), "kite.Core is required").LineOps
local Media = assert(tryRequire("kite.PyBridge"), "kite.PyBridge is required").Media
local lfs = tryRequire("lfs")


local tune = {
    vote_fraction = 0.5,
    w_vad = 1.0,
    w_sil30 = 0.9,
    w_sil40 = 0.85,
    w_sil50 = 0.6,
    w_flux = 0.7,
    min_voice_run_ms = 50,
    bridge_gap_ms = 320,
    max_pause_ms = 900,
    tiny_span_ms = 120,
    flux_start_ms = 160,
    flux_end_ms = 200,
    spread_search_ms = 450,
    spread_flag_ms = 350,
    min_voice_ms = 80,
    stack_eps_ms = 40,
    keep_min_out_ms = 200,
    flash_gap_ms = 250,
    cap_grace_ms = 120,
    frame_grace_ms = 45,
    orig_end_cut_ms = 150,

    max_sane_cps = 40,
    relax_vote = 0.38,
    relax_bridge_ms = 480,
    relax_tiny_ms = 60,
    relax_pause_ms = 1200,
    relax_run_ms = 30,

    onset_soft_ms = 140,
    loud_tail_ms = 300,
    tail_keep_ms = 80,

    w_env = 1.0,
    env_refine_ms = 220,
    env_min_range_db = 6,
    env_thr_frac = 0.35,
}
local defaultFrameRate = 24000 / 1001
local auxAlignmentWindowMs = 40
local trim = Core.trim
local finiteNumber = Core.finiteNumber
local round = Core.round
local clamp = Core.clamp

local function lowerBound(list, value)
    local lo, hi = 1, #list + 1
    while lo < hi do
        local mid = math.floor((lo + hi) / 2)
        if list[mid] < value then lo = mid + 1 else hi = mid end
    end
    return lo
end

local function overlapLen(a0, a1, b0, b1)
    return math.min(a1, b1) - math.max(a0, b0)
end

local progress = LineOps.progress

local pathKeys = { "sil30", "sil40", "sil50", "vad", "flux", "env", "keyframes" }
local isWindows = package.config:sub(1, 1) == "\\"

local function scriptDirAndBase()
    local dir, name = LineOps.decodedPath("?script")
    if aegisub and aegisub.file_name then
        local ok, n = pcall(aegisub.file_name)
        if ok and n and n ~= "" then name = n end
    end
    local base = name and name:gsub("%.[^%.]+$", "") or nil
    return dir, base, name
end

local function listDir(dir)
    if not dir then return {} end
    local out = {}
    if lfs then
        local ok, iterator, state = pcall(lfs.dir, dir)
        if ok and iterator then
            for name in iterator, state do
                if name ~= "." and name ~= ".." then out[#out + 1] = name end
            end
            table.sort(out)
            return out
        end
    end
    return out
end

local function classifyDataFile(name)
    local n = tostring(name or ""):lower()
    if not (n:match("%.txt$") or n:match("%.log$") or n:match("%.tsv$") or n:match("%.csv$")) then return nil end
    if n:find("key", 1, true) or n:find("kf", 1, true) or n:find("scene", 1, true) then return "keyframes" end
    if n:find("vad", 1, true) then return "vad" end
    if n:find("flux", 1, true) or n:find("onset", 1, true) then return "flux" end
    if n:find("env", 1, true) or n:find("rms", 1, true) or n:find("loud", 1, true) then return "env" end
    if n:match("_spectrum%.tsv$") then return nil end
    if n:find("sil", 1, true) or n:find("silence", 1, true) or n:find("retime", 1, true) then
        if n:find("30", 1, true) then return "sil30" end
        if n:find("40", 1, true) then return "sil40" end
        if n:find("50", 1, true) then return "sil50" end
        return "sil30"
    end
    local th = n:match("[_%-]([345]0)%.%w+$")
    if th then return "sil" .. th end
    return nil
end

local function chapterOf(name)
    local digits = tostring(name or ""):match("^(%d+)")
    if digits then return tonumber(digits) end
    return nil
end

local function discoverPaths(paths)
    paths = type(paths) == "table" and paths or {}
    local dir, base = scriptDirAndBase()
    if not dir then return paths end
    local sep = isWindows and "\\" or "/"
    local subsCh = base and tonumber(base:match("(%d+)")) or nil
    local best = {}
    for _, fname in ipairs(listDir(dir)) do
        local slot = classifyDataFile(fname)
        if slot and (paths[slot] == nil or paths[slot] == "") then
            local score = 1
            if base and fname:lower():find(base:lower(), 1, true) then score = score + 2 end
            if subsCh and chapterOf(fname) == subsCh then score = score + 3 end
            if not best[slot] or score > best[slot].score then
                best[slot] = { name = fname, score = score }
            end
        end
    end
    for slot, rec in pairs(best) do
        paths[slot] = dir .. sep .. rec.name
    end
    return paths
end
local visibleText = LineOps.visibleText
local hasDrawing = LineOps.hasDrawing

local function utf8Len(s)
    s = tostring(s or "")
    local _, continuation = s:gsub("[\128-\191]", "")
    return #s - continuation
end

local function readableChars(text)
    local clean = visibleText(text)
    clean = clean:gsub("[%s%p]", "")
    clean = clean:gsub("\194\191", ""):gsub("\194\161", ""):gsub("\226\128\166", "")
    return utf8Len(clean)
end

local function styleOk(style, flt, extra)
    flt = tostring(flt or "All")
    if flt == "" or flt == "All" then return true end
    style = tostring(style or "")
    local extraHit = extra ~= nil and extra ~= "" and style == extra
    if flt == "All Default" then return style:find("Defa", 1, true) ~= nil or extraHit end
    if flt == "Default+Alt" then
        return style:find("Defa", 1, true) ~= nil or style:find("Alt", 1, true) ~= nil or extraHit
    end
    return style == flt or extraHit
end

local function isSpoken(line, cfg)
    cfg = cfg or {}
    if not line or line.comment then return false end
    local raw = tostring(line.text or "")
    if hasDrawing(raw) then return false end
    if visibleText(raw) == "" then return false end
    local effect = tostring(line.effect or ""):lower()
    if effect:find("template", 1, true) or effect:find("karaoke", 1, true) or effect:find("code", 1, true) then return false end
    if cfg.skip_signs then
        local style = tostring(line.style or ""):lower()
        if style:find("sign", 1, true) or style:find("kara", 1, true) or style:find("fx", 1, true) then return false end
    end
    if not styleOk(line.style, cfg.style_filter, cfg.extra_style) then return false end
    return true
end

local function splitFields(line)
    local fields = {}
    line = tostring(line or "")
    if line:find("\t", 1, true) then
        for f in line:gmatch("[^\t]+") do fields[#fields + 1] = trim(f) end
    elseif line:find(",", 1, true) then
        for f in line:gmatch("[^,]+") do fields[#fields + 1] = trim(f) end
    else
        for f in line:gmatch("%S+") do fields[#fields + 1] = trim(f) end
    end
    return fields
end

local function detectTimeScale(header, values)
    header = tostring(header or ""):lower()
    if header:find("ms", 1, true) or header:find("millisecond", 1, true) then return 1 end
    if header:find("sec", 1, true) or header:find("time_s", 1, true) then return 1000 end
    local maxAbs, n, fractional = 0, 0, false
    for _, v in ipairs(values) do
        local x = finiteNumber(v)
        if x then
            n = n + 1
            maxAbs = math.max(maxAbs, math.abs(x))
            if x ~= math.floor(x) then fractional = true end
        end
    end
    if fractional then return 1000 end
    if n >= 4 then return 1 end
    if maxAbs > 100000 then return 1 end
    return 1000
end

local function mergeIntervals(list)
    table.sort(list, function(a, b) return a.b < b.b end)
    local out = {}
    for _, iv in ipairs(list) do
        if iv.e > iv.b then
            local last = out[#out]
            if last and iv.b <= last.e then
                if iv.e > last.e then last.e = iv.e end
            else
                out[#out + 1] = { b = iv.b, e = iv.e }
            end
        end
    end
    return out
end

local function parseIntervalRows(path)
    local rows, nums, header = {}, {}, nil
    local f = io.open(path, "r")
    if not f then return rows end
    local first = true
    for line in f:lines() do
        local fields = splitFields(line)
        local s, e = tonumber(fields[1]), tonumber(fields[2])
        if first then
            first = false
            header = line
            if s and e then rows[#rows + 1] = { b = s, e = e }; nums[#nums + 1] = s; nums[#nums + 1] = e end
        elseif s and e and e > s then
            rows[#rows + 1] = { b = s, e = e }; nums[#nums + 1] = s; nums[#nums + 1] = e
        end
    end
    f:close()
    local scale = detectTimeScale(header, nums)
    for _, r in ipairs(rows) do r.b = r.b * scale; r.e = r.e * scale end
    return mergeIntervals(rows)
end

local function parseSilenceFile(path)
    if not path or path == "" then return {} end
    local out = {}
    local f = io.open(path, "r")
    if not f then return out end
    local cur = nil
    for line in f:lines() do
        local ss = line:match("silence_start:%s*(-?[%d%.]+)")
        if ss then cur = tonumber(ss) and tonumber(ss) * 1000 or nil end
        local se = line:match("silence_end:%s*(-?[%d%.]+)")
        if se and cur then
            local e = tonumber(se) * 1000
            if e > cur then out[#out + 1] = { b = cur, e = e } end
            cur = nil
        end
    end
    f:close()
    if #out == 0 then

        return parseIntervalRows(path)
    end
    return mergeIntervals(out)
end

local function parseVadFile(path)
    if not path or path == "" then return {} end
    return parseIntervalRows(path)
end

local function parseFluxFile(path)
    local on, off = {}, {}
    if not path or path == "" then return on, off end
    local rows, nums, header = {}, {}, nil
    local f = io.open(path, "r")
    if not f then return on, off end
    local first = true
    for line in f:lines() do
        local fields = splitFields(line)
        local t = tonumber(fields[1])
        if first then
            first = false
            header = line
        end
        if t then
            rows[#rows + 1] = { t = t, kind = tostring(fields[2] or "onset"):lower() }
            nums[#nums + 1] = t
        end
    end
    f:close()
    local scale = detectTimeScale(header, nums)
    for _, r in ipairs(rows) do
        local t = r.t * scale
        if r.kind == "offset" or r.kind == "end" then off[#off + 1] = t else on[#on + 1] = t end
    end
    table.sort(on); table.sort(off)
    return on, off
end

local function parseEnvFile(path)
    if not path or path == "" then return nil end
    local f = io.open(path, "r")
    if not f then return nil end
    local rows, nums, header, first = {}, {}, nil, true
    for line in f:lines() do
        local fields = splitFields(line)
        local t, v = tonumber(fields[1]), tonumber(fields[2])
        if first then first = false; header = line end
        if t and v then
            rows[#rows + 1] = { t = t, v = v }
            nums[#nums + 1] = t
        end
    end
    f:close()
    if #rows < 8 then return nil end
    local scale = detectTimeScale(header, nums)
    table.sort(rows, function(x, y) return x.t < y.t end)
    local ts, vs = {}, {}
    for i, r in ipairs(rows) do ts[i] = r.t * scale; vs[i] = r.v end
    return { t = ts, v = vs }
end

local function envWindow(env, w0, w1)
    local i0 = lowerBound(env.t, w0)
    local i1 = lowerBound(env.t, w1) - 1
    return i0, i1
end

local function envThreshold(env, i0, i1)
    if i1 - i0 < 7 then return nil end
    local vals = {}
    for i = i0, i1 do vals[#vals + 1] = env.v[i] end
    table.sort(vals)
    local floorDb = vals[math.max(1, math.floor(#vals * 0.10))]
    local peakDb = vals[math.max(1, math.floor(#vals * 0.90))]
    if peakDb - floorDb < tune.env_min_range_db then return nil end
    return floorDb + (peakDb - floorDb) * tune.env_thr_frac
end

local function envActs(env, w0, w1)
    local i0, i1 = envWindow(env, w0, w1)
    local thr = envThreshold(env, i0, i1)
    if not thr then return nil end
    local out, since = {}, nil
    for i = i0, i1 do
        local active = env.v[i] >= thr
        if active and not since then
            since = env.t[i]
        elseif not active and since then
            out[#out + 1] = { b = since, e = env.t[i] }
            since = nil
        end
    end
    if since then out[#out + 1] = { b = since, e = w1 } end
    return out
end

local function envRefineEdge(env, t, which, w0, w1)
    local i0, i1 = envWindow(env, w0, w1)
    local thr = envThreshold(env, i0, i1)
    if not thr then return nil end
    local best, bestd
    for i = math.max(i0 + 1, 2), i1 do
        local up = env.v[i - 1] < thr and env.v[i] >= thr
        local down = env.v[i - 1] >= thr and env.v[i] < thr
        if (which == "start" and up) or (which == "end" and down) then
            local d = math.abs(env.t[i] - t)
            if d <= tune.env_refine_ms and (not bestd or d < bestd) then
                best, bestd = env.t[i], d
            end
        end
    end
    return best
end

local function frameToMs(frame, cfg)
    frame = finiteNumber(frame)
    if not frame then return nil end
    local milliseconds = Media.msFromFrame(frame)
    if milliseconds then return milliseconds end
    local fps = finiteNumber(cfg and cfg.fps) or defaultFrameRate
    if fps <= 0 then fps = defaultFrameRate end
    return round(frame * 1000 / fps)
end

local function parseKeyframeFile(path, cfg)
    local rawLines = {}
    if not path or path == "" then return {} end
    local f = io.open(path, "r")
    if not f then return {} end
    local hasFrameTokens = false
    for line in f:lines() do
        local raw = trim(line)
        if raw ~= "" and not raw:match("^#") then
            rawLines[#rawLines + 1] = raw
            local kind = tostring(raw:match("^(%S+)") or ""):lower()
            if kind == "i" or kind == "p" or kind == "b" then hasFrameTokens = true end
        end
    end
    f:close()
    local frames = {}
    if hasFrameTokens then

        local frame = 0
        for _, raw in ipairs(rawLines) do
            local kind = tostring(raw:match("^(%S+)") or ""):lower()
            if kind == "i" or kind == "p" or kind == "b" then
                if kind == "i" then frames[#frames + 1] = frame end
                frame = frame + 1
            end
        end
    else
        for _, raw in ipairs(rawLines) do
            local n = tonumber(raw:match("^(-?%d+%.?%d*)"))
            if n then frames[#frames + 1] = round(n) end
        end
    end
    local ms, seen = {}, {}
    for _, fr in ipairs(frames) do
        local t = frameToMs(fr, cfg)
        if t and not seen[t] then seen[t] = true; ms[#ms + 1] = t end
    end
    table.sort(ms)
    return ms
end

local function getKeyframes(cfg)
    cfg = cfg or {}
    local ms
    if aegisub and type(aegisub.keyframes) == "function" then
        local ok, kf = pcall(aegisub.keyframes)
        if ok and type(kf) == "table" and #kf > 0 then
            local seen = {}
            ms = {}
            for _, fr in ipairs(kf) do
                local t = frameToMs(fr, cfg)
                if t and not seen[t] then seen[t] = true; ms[#ms + 1] = t end
            end
            table.sort(ms)
        end
    end
    if not ms then ms = parseKeyframeFile(cfg.keyframes, cfg) end
    local set = {}
    for _, t in ipairs(ms) do set[t] = true end
    return ms, set
end

local function kfIn(kfs, lo, hi, target)
    if not kfs or #kfs == 0 or hi < lo then return nil end
    local pos = lowerBound(kfs, lo)
    local best, bestd
    while pos <= #kfs do
        local t = kfs[pos]
        if t > hi then break end
        local d = math.abs(t - target)
        if not bestd or d < bestd then best, bestd = t, d end
        pos = pos + 1
    end
    return best
end

local function nearestIn(arr, target, maxD)
    if not arr or #arr == 0 then return nil end
    local pos = lowerBound(arr, target)
    local best, bestd
    for off = -1, 0 do
        local t = arr[pos + off]
        if t then
            local d = math.abs(t - target)
            if d <= maxD and (not bestd or d < bestd) then best, bestd = t, d end
        end
    end
    return best
end

local function makeIntervalSource(kind, label, weight, list)
    local starts, ends = {}, {}
    for _, iv in ipairs(list) do
        if kind == "sil" then
            starts[#starts + 1] = iv.e
            ends[#ends + 1] = iv.b
        else
            starts[#starts + 1] = iv.b
            ends[#ends + 1] = iv.e
        end
    end
    table.sort(starts); table.sort(ends)
    return { kind = kind, label = label, weight = weight, list = list, starts = starts, ends = ends, cur = 1 }
end

local function fluxIntervals(on, off)
    local out, oi = {}, 1
    for _, t in ipairs(on) do
        while off[oi] and off[oi] <= t do oi = oi + 1 end
        if off[oi] then out[#out + 1] = { b = t, e = off[oi] } end
    end
    return mergeIntervals(out)
end

local function buildSignals(paths)
    paths = type(paths) == "table" and paths or {}
    local sig = { sources = {}, flux_on = {}, flux_off = {} }
    local silspecs = {
        { paths.sil30, tune.w_sil30, "sil30" },
        { paths.sil40, tune.w_sil40, "sil40" },
        { paths.sil50, tune.w_sil50, "sil50" },
    }
    for _, sp in ipairs(silspecs) do
        if sp[1] ~= "" then
            local list = parseSilenceFile(sp[1])
            if #list > 0 then
                sig.sources[#sig.sources + 1] = makeIntervalSource("sil", sp[3], sp[2], list)
            end
        end
    end
    if paths.vad ~= "" then
        local list = parseVadFile(paths.vad)
        if #list > 0 then
            sig.sources[#sig.sources + 1] = makeIntervalSource("vad", "vad", tune.w_vad, list)
        end
    end
    if paths.flux ~= "" then
        sig.flux_on, sig.flux_off = parseFluxFile(paths.flux)
    end
    if paths.env ~= "" then
        sig.env = parseEnvFile(paths.env)
    end
    if paths.waveEnv then sig.env = paths.waveEnv end
    if #sig.sources == 0 and #sig.flux_on > 0 and #sig.flux_off > 0 then
        local list = fluxIntervals(sig.flux_on, sig.flux_off)
        if #list > 0 then
            sig.sources[#sig.sources + 1] = makeIntervalSource("vad", "flux-span", tune.w_flux, list)
        end
    end
    return sig
end

local function windowOverlaps(src, w0, w1)
    local list = src.list
    local cur = src.cur or 1
    if src.last_w0 and w0 < src.last_w0 then cur = 1 end
    src.last_w0 = w0
    while cur <= #list and list[cur].e <= w0 do cur = cur + 1 end
    src.cur = cur
    local out, i = {}, cur
    while i <= #list and list[i].b < w1 do
        if list[i].e > w0 then out[#out + 1] = list[i] end
        i = i + 1
    end
    return out
end

local function clipIntervals(list, w0, w1)
    local out = {}
    for _, iv in ipairs(list) do
        local b, e = math.max(iv.b, w0), math.min(iv.e, w1)
        if e > b then out[#out + 1] = { b = b, e = e } end
    end
    return out
end

local function complementIntervals(list, w0, w1)
    local out, cur = {}, w0
    for _, iv in ipairs(list) do
        local b, e = math.max(iv.b, w0), math.min(iv.e, w1)
        if e > b then
            if b > cur then out[#out + 1] = { b = cur, e = b } end
            if e > cur then cur = e end
        end
    end
    if cur < w1 then out[#out + 1] = { b = cur, e = w1 } end
    return out
end

local function voteActivity(sources, need, w0, w1)
    local events = {}
    for _, src in ipairs(sources) do
        for _, iv in ipairs(src.acts) do
            local b, e = math.max(iv.b, w0), math.min(iv.e, w1)
            if e > b then
                events[#events + 1] = { t = b, d = src.weight }
                events[#events + 1] = { t = e, d = -src.weight }
            end
        end
    end
    if #events == 0 or need <= 0 then return {} end
    table.sort(events, function(x, y) return x.t < y.t end)
    need = need - 1e-9
    local out, level, since = {}, 0, nil
    local i, n = 1, #events
    while i <= n do
        local t = events[i].t
        while i <= n and events[i].t == t do
            level = level + events[i].d
            i = i + 1
        end
        local active = level >= need
        if active and not since then
            since = t
        elseif not active and since then
            if t > since then out[#out + 1] = { b = since, e = t } end
            since = nil
        end
    end
    if since and w1 > since then out[#out + 1] = { b = since, e = w1 } end
    return out
end

local function edgeSpread(sig, t, which)
    local vals = {}
    for _, src in ipairs(sig.sources) do
        local arr = (which == "start") and src.starts or src.ends
        local v = nearestIn(arr, t, tune.spread_search_ms)
        if v then vals[#vals + 1] = v end
    end
    local f = nearestIn(which == "start" and sig.flux_on or sig.flux_off, t, tune.spread_search_ms)
    if f then vals[#vals + 1] = f end
    if #vals < 2 then return false end
    local mn, mx = vals[1], vals[1]
    for _, v in ipairs(vals) do
        if v < mn then mn = v end
        if v > mx then mx = v end
    end
    return (mx - mn) > tune.spread_flag_ms
end

local function detectVoice(it, sig, cfg, kfs, relax)
    local fraction = relax and tune.relax_vote or tune.vote_fraction
    local bridge = relax and tune.relax_bridge_ms or tune.bridge_gap_ms
    local tiny = relax and tune.relax_tiny_ms or tune.tiny_span_ms
    local pause = relax and tune.relax_pause_ms or tune.max_pause_ms
    local minRun = relax and tune.relax_run_ms or tune.min_voice_run_ms

    local w0 = math.max(it.os, 0)
    local w1 = it.oe
    if w1 <= w0 then return nil end

    local sources, total = {}, 0
    for _, src in ipairs(sig.sources) do
        local within = windowOverlaps(src, w0, w1)
        local acts
        if src.kind == "sil" then
            acts = complementIntervals(within, w0, w1)
        else
            acts = clipIntervals(within, w0, w1)
        end
        sources[#sources + 1] = { weight = src.weight, acts = acts }
        total = total + src.weight
    end
    if sig.env then
        local acts = envActs(sig.env, w0, w1)
        if acts then
            sources[#sources + 1] = { weight = tune.w_env, acts = acts }
            total = total + tune.w_env
        end
    end
    if total <= 0 then return nil end

    local voted = voteActivity(sources, total * fraction, w0, w1)
    local runs = {}
    for _, r in ipairs(voted) do
        if r.e - r.b >= minRun then runs[#runs + 1] = r end
    end
    if #runs == 0 then runs = voted end
    if #runs == 0 then return nil end

    local spans = {}
    for _, r in ipairs(runs) do
        local last = spans[#spans]
        if last and r.b - last.e <= bridge then
            if r.e > last.e then last.e = r.e end
        else
            spans[#spans + 1] = { b = r.b, e = r.e }
        end
    end

    local cands = {}
    for _, sp in ipairs(spans) do
        if sp.e > it.os and sp.b < it.oe then cands[#cands + 1] = sp end
    end
    if #cands == 0 then return nil end

    local anchor, best = 1, nil
    for i, sp in ipairs(cands) do
        local score = overlapLen(sp.b, sp.e, it.os, it.oe) + 0.2 * (sp.e - sp.b)
        if not best or score > best then best, anchor = score, i end
    end
    local lo, hi = anchor, anchor
    while lo > 1 do
        local prev = cands[lo - 1]
        if cands[lo].b - prev.e <= pause and prev.e - prev.b >= tiny then
            lo = lo - 1
        else break end
    end
    while hi < #cands do
        local nxt = cands[hi + 1]
        if nxt.b - cands[hi].e <= pause and nxt.e - nxt.b >= tiny then
            hi = hi + 1
        else break end
    end
    local vs, ve = cands[lo].b, cands[hi].e

    for _, src in ipairs(sig.sources) do
        if src.label == "sil40" or src.label == "sil50" then
            local v = nearestIn(src.starts, vs, tune.onset_soft_ms)
            if v and v < vs then vs = v end
        end
    end

    for _, src in ipairs(sig.sources) do
        if src.label == "sil30" then
            local loudEnd = nearestIn(src.ends, ve, tune.loud_tail_ms)
            if loudEnd and loudEnd < ve - tune.tail_keep_ms and loudEnd > vs then
                ve = loudEnd + tune.tail_keep_ms
            end
        end
    end

    if sig.env then
        local r = envRefineEdge(sig.env, vs, "start", w0, w1)
        if r and r < ve then vs = r end
        r = envRefineEdge(sig.env, ve, "end", w0, w1)
        if r and r > vs then ve = r end
    end
    local on = nearestIn(sig.flux_on, vs, tune.flux_start_ms)
    if on and on < ve then vs = on end
    local off = nearestIn(sig.flux_off, ve, tune.flux_end_ms)
    if off and off > vs then ve = off end

    local hitLo = vs <= w0 + 1
    local hitHi = ve >= w1 - 1
    vs = clamp(vs, it.os, it.oe)
    ve = clamp(ve, it.os, it.oe)

    if hitHi and kfs then
        local k = kfIn(kfs, it.oe - tune.orig_end_cut_ms, it.oe, it.oe)
        if k and k > vs then ve = k end
    end
    if ve - vs < tune.min_voice_ms then return nil end

    local weak = hitLo or hitHi
        or edgeSpread(sig, vs, "start") or edgeSpread(sig, ve, "end")
    return { vs = round(vs), ve = round(ve), weak = weak }
end
local Lzt = {}

Lzt.lazyConfig = {
    weights = { proximity = 0.30, silence_q = 0.22, source_c = 0.13, clarity = 0.08, vad = 0.30, flux = 0.30 },
    cluster_max_dist = 120, min_cluster_mass = 0.6, min_score_threshold = 0.25,
    min_duration = 200, max_duration = 8000, epsilon = 50,
    thresholds = {
        [30] = { min_silence_dur = 350, reliability = 1.0 },
        [40] = { min_silence_dur = 120, reliability = 0.9 },
        [50] = { min_silence_dur = 120, reliability = 0.6 },
    },
}
Lzt.tableConfig = {
    merge_gap_ms = 120, min_noise_ms = 80, edge_drop_ms = 60,
    w_cov = 0.65, w_prox = 0.25, w_frag = 0.10, sigma_ms = 200, eps = 1,
}
local legacyActivityPaddingMs = 15
local legacyActivityEdgeToleranceMs = 30
local defaultLegacyLimitMs = 500
Lzt.auxVad  = nil
Lzt.auxFlux = nil

function Lzt.normalizeProximity(d, w) if w <= 0 then return 0 end; return math.exp(-(d*d)/(w*w)) end
function Lzt.normalizeSilenceQuality(d)
    if d < 100 then return 0.1
    elseif d < 500 then return 0.3 + 0.4 * (d - 100) / 400
    elseif d < 1500 then return 0.7 + 0.2 * (d - 500) / 1000
    else return 0.9 + 0.1 * (1 - math.exp(-(d - 1500) / 1000)) end
end
function Lzt.getSourceConfidence(t) return (Lzt.lazyConfig.thresholds[t] and Lzt.lazyConfig.thresholds[t].reliability) or 0.5 end
function Lzt.normalizeContextClarity(d) return 1 / (1 + d * d) end
function Lzt.calculateScore(c, rt, sw, sd)
    local d = math.abs(c.time - rt)
    local fp = Lzt.normalizeProximity(d, sw)
    local fq = Lzt.normalizeSilenceQuality(c.duration or 0)
    local fc = Lzt.getSourceConfidence(c.threshold)
    local fl = Lzt.normalizeContextClarity(sd)
    local fflux, fvad = (c.flux_boost or 0), (c.vad_align or 0)
    local weights = Lzt.lazyConfig.weights
    return (fp*weights.proximity)+(fq*weights.silence_q)+(fc*weights.source_c)+(fl*weights.clarity)+(fflux*weights.flux)+(fvad*weights.vad)
end
function Lzt.findClusters(cs, md)
    if not cs or #cs == 0 then return {} end
    if #cs < 2 then return { cs } end
    table.sort(cs, function(a, b) return a.time < b.time end)
    local cls, ccl = {}, { cs[1] }
    for i = 2, #cs do
        if cs[i].time - ccl[#ccl].time <= md then table.insert(ccl, cs[i])
        else table.insert(cls, ccl); ccl = { cs[i] } end
    end
    table.insert(cls, ccl); return cls
end
function Lzt.weightedMedianTime(cl)
    table.sort(cl, function(a, b) return a.time < b.time end)
    local sum = 0; for _, p in ipairs(cl) do sum = sum + (p.score or 0) end
    if sum <= 0 then local mid = math.floor((#cl + 1) / 2); return cl[mid].time end
    local acc = 0
    for _, p in ipairs(cl) do acc = acc + (p.score or 0); if acc >= sum * 0.5 then return p.time end end
    return cl[#cl].time
end
function Lzt.addLazyTag(l, t)
    local tag = "[LZ " .. t .. "]"
    local e = l.effect or ""
    if e:find(tag, 1, true) then return end
    l.effect = (e == "") and tag or (e .. " " .. tag)
end
function Lzt.lowerBound(arr, t)
    local lo, hi = 1, #arr + 1
    while lo < hi do
        local mid = math.floor((lo + hi) / 2)
        if arr[mid].time < t then lo = mid + 1 else hi = mid end
    end
    return lo
end
function Lzt.validateIntra(ns, ne, os, oe)
    ns, ne, os, oe = finiteNumber(ns), finiteNumber(ne), finiteNumber(os), finiteNumber(oe)
    if not ns or not ne or not os or not oe then return false, "invalid_time" end
    if ns < os or ne > oe then return false, "out_of_range" end
    if ne - ns < Lzt.lazyConfig.min_duration then return false, "min_dur" end
    if ne - ns > Lzt.lazyConfig.max_duration then return false, "max_dur" end
    return true
end
function Lzt.clampIntra(ns, ne, os, oe)
    ns, ne, os, oe = finiteNumber(ns), finiteNumber(ne), finiteNumber(os), finiteNumber(oe)
    if not ns or not ne or not os or not oe then return false, "invalid_time", ns, ne end
    local ns2, ne2 = math.max(ns, os), math.min(ne, oe)
    if ne2 - ns2 < Lzt.lazyConfig.min_duration then return false, "min_dur", ns, ne end
    if ne2 - ns2 > Lzt.lazyConfig.max_duration then return false, "max_dur", ns, ne end
    return true, nil, ns2, ne2
end
function Lzt.getDensity(t, s, ws)
    ws = ws or 5000
    local c, sw, ew = 0, t - ws/2, t + ws/2
    for _, seg in ipairs(s) do
        if not (seg["end"] <= sw or seg.start >= ew) then c = c + 1 end
    end
    return c / (ws / 1000)
end

function Lzt.parseLazyFile(fp, t)
    local segs = {}; local fh = io.open(fp, "r"); if not fh then return segs end
    local cs = nil
    for l in fh:lines() do
        local ss = l:match("silence_start:%s*([%d%.]+)")
        if ss then cs = tonumber(ss) * 1000 end
        local se, sd = l:match("silence_end:%s*([%d%.]+)%s*|%s*silence_duration:%s*([%d%.]+)")
        if se and cs then
            local dms = tonumber(sd) * 1000
            if dms >= ((Lzt.lazyConfig.thresholds[t] and Lzt.lazyConfig.thresholds[t].min_silence_dur) or 100) then
                table.insert(segs, { start = cs, ["end"] = tonumber(se) * 1000, duration = dms, threshold = t })
            end
            cs = nil
        end
    end
    fh:close(); return segs
end

function Lzt.parseVADtsv(path)
    local segs, nums, header = {}, {}, nil
    if type(path) ~= "string" or path == "" then return segs end
    local f = io.open(path, "r"); if not f then return segs end
    for line in f:lines() do
        local fields = splitFields(line)
        local a, b = finiteNumber(fields[1]), finiteNumber(fields[2])
        if a and b and b > a then
            segs[#segs + 1] = { start = a, ["end"] = b }
            nums[#nums + 1], nums[#nums + 2] = a, b
        elseif not header then
            header = line
        end
    end
    f:close()
    segs.time_scale = detectTimeScale(header, nums)
    table.sort(segs, function(a, b) return a.start < b.start end)
    return segs
end

function Lzt.parseFLUXtsv(path)
    local cands, nums, header = {}, {}, nil
    if type(path) ~= "string" or path == "" then return cands end
    local f = io.open(path, "r"); if not f then return cands end
    for line in f:lines() do
        local fields = splitFields(line)
        local t, ty, sc = finiteNumber(fields[1]), tostring(fields[2] or ""), finiteNumber(fields[3])
        if t and ty ~= "" and sc then
            cands[#cands + 1] = { time = t, type = ty:lower(), score = sc }
            nums[#nums + 1] = t
        elseif not header then
            header = line
        end
    end
    f:close()
    cands.time_scale = detectTimeScale(header, nums)
    table.sort(cands, function(a, b) return a.time < b.time end)
    return cands
end

local fluxIndexCache = setmetatable({}, { __mode = "k" })
local vadIndexCache = setmetatable({}, { __mode = "k" })

local function indexedFlux(flux)
    if type(flux) ~= "table" then return {} end
    local cached = fluxIndexCache[flux]
    if cached then return cached end
    local byType = {}
    for order, candidate in ipairs(flux) do
        local time = type(candidate) == "table" and finiteNumber(candidate.time) or nil
        local kind = type(candidate) == "table" and tostring(candidate.type or ""):lower() or ""
        if time and kind ~= "" then
            byType[kind] = byType[kind] or {}
            byType[kind][#byType[kind] + 1] = {
                time = time,
                score = finiteNumber(candidate.score) or 0,
                order = order,
            }
        end
    end
    for kind, records in pairs(byType) do
        table.sort(records, function(left, right)
            if left.time ~= right.time then return left.time < right.time end
            return left.order < right.order
        end)
        local compact = {}
        for _, record in ipairs(records) do
            local previous = compact[#compact]
            if previous and previous.time == record.time then
                if record.score > previous.score then previous.score = record.score end
            else
                compact[#compact + 1] = record
            end
        end
        byType[kind] = compact
    end
    fluxIndexCache[flux] = byType
    return byType
end

local function indexedVad(vad)
    if type(vad) ~= "table" then return {} end
    local cached = vadIndexCache[vad]
    if cached then return cached end
    local boundaries = {}
    for _, segment in ipairs(vad) do
        local startTime = type(segment) == "table" and finiteNumber(segment.start) or nil
        local endTime = type(segment) == "table" and finiteNumber(segment["end"]) or nil
        if startTime then boundaries[#boundaries + 1] = startTime end
        if endTime then boundaries[#boundaries + 1] = endTime end
    end
    table.sort(boundaries)
    local compact = {}
    for _, time in ipairs(boundaries) do
        if compact[#compact] ~= time then compact[#compact + 1] = time end
    end
    vadIndexCache[vad] = compact
    return compact
end

function Lzt.enrichWithAux(cands, flux, vad, wantType)
    local fluxRecords = indexedFlux(flux)[tostring(wantType or ""):lower()] or {}
    local vadBoundaries = indexedVad(vad)
    local function nearestFlux(t)
        local lo, hi = 1, #fluxRecords + 1
        while lo < hi do
            local mid = math.floor((lo + hi) / 2)
            if fluxRecords[mid].time < t then lo = mid + 1 else hi = mid end
        end
        local bestD, bestS = math.huge, 0
        for _, index in ipairs({ lo - 1, lo }) do
            local record = fluxRecords[index]
            if record then
                local distance = math.abs(record.time - t)
                if distance < bestD or (distance == bestD and record.score > bestS) then
                    bestD, bestS = distance, record.score
                end
            end
        end
        if bestD <= auxAlignmentWindowMs then
            return (1 - bestD / auxAlignmentWindowMs) * bestS
        end
        return 0
    end
    local function vadMargin(t)
        local position = lowerBound(vadBoundaries, t)
        local best = math.huge
        for _, index in ipairs({ position - 1, position }) do
            local boundary = vadBoundaries[index]
            if boundary then best = math.min(best, math.abs(boundary - t)) end
        end
        if best == math.huge then return 0 end
        return math.exp(-(best * best) / (auxAlignmentWindowMs * auxAlignmentWindowMs))
    end
    for _, candidate in ipairs(type(cands) == "table" and cands or {}) do
        if type(candidate) == "table" then
            local time = finiteNumber(candidate.time)
            candidate.flux_boost = time and nearestFlux(time) or 0
            candidate.vad_align = time and vadMargin(time) or 0
        end
    end
end

function Lzt.loadLazyData(fps)
    local rs = {}
    for t, p in pairs(fps) do for _, s in ipairs(Lzt.parseLazyFile(p, t)) do table.insert(rs, s) end end
    table.sort(rs, function(a, b) return a.start < b.start end)
    local ss, se = {}, {}
    for _, s in ipairs(rs) do
        table.insert(ss, { time = s["end"],   duration = s.duration, threshold = s.threshold })
        table.insert(se, { time = s.start,    duration = s.duration, threshold = s.threshold })
    end
    local byTime = function(a, b) return a.time < b.time end
    table.sort(ss, byTime); table.sort(se, byTime)
    return ss, se, rs
end

function Lzt.copyCandidate(ev) return { time = ev.time, duration = ev.duration, threshold = ev.threshold } end
function Lzt.roundMs(x) return math.floor(x + 0.5) end
function Lzt.orderedByStart(subs, sel)
    local arr = {}
    local seen = {}
    for _, raw in ipairs(type(sel) == "table" and sel or {}) do
        local i = tonumber(raw)
        if i and i == math.floor(i) and i >= 1 and not seen[i] then
            local ok, line = pcall(function() return subs[i] end)
            local startTime = ok and line and finiteNumber(line.start_time) or nil
            if startTime then
                seen[i] = true
                arr[#arr + 1] = { i = i, st = startTime }
            end
        end
    end
    table.sort(arr, function(a, b)
        if a.st ~= b.st then return a.st < b.st end
        return a.i < b.i
    end)
    local out = {}; for _, e in ipairs(arr) do table.insert(out, e.i) end; return out
end
function Lzt.stripLZ(effect) effect = effect or ""; return (effect:gsub("%s*%[LZ[^%]]*%]", "")) end

function Lzt.tagDecider(l, os, oe, ns, ne, applyStart, applyEnd, enableTagging, tagMode, tagScope)
    if not enableTagging or tagMode == "None" then return end
    local chs = (applyStart and ns ~= os)
    local che = (applyEnd and ne ~= oe)
    local scopeS = (tagScope == "Both" or tagScope == "Start only")
    local scopeE = (tagScope == "Both" or tagScope == "End only")
    if tagMode == "Only 0ms" then
        if scopeS and applyStart and not chs then Lzt.addLazyTag(l, "~0ms-s") end
        if scopeE and applyEnd   and not che then Lzt.addLazyTag(l, "~0ms-e") end
    elseif tagMode == "Only changes" then
        if scopeS and chs then Lzt.addLazyTag(l, string.format("Δs=%+dms", ns - os)) end
        if scopeE and che then Lzt.addLazyTag(l, string.format("Δe=%+dms", ne - oe)) end
    elseif tagMode == "Both" then
        if scopeS and applyStart then Lzt.addLazyTag(l, chs and string.format("Δs=%+dms", ns - os) or "~0ms-s") end
        if scopeE and applyEnd   then Lzt.addLazyTag(l, che and string.format("Δe=%+dms", ne - oe) or "~0ms-e") end
    end
end

function Lzt.rankFusionPick(cands, rt, isStart)
    local candidateCount = #cands
    if candidateCount == 0 then return nil end
    if candidateCount == 1 then return cands[1] end
    local function rankBy(fn, desc)
        local t = {}; for i, c in ipairs(cands) do t[i] = { i = i, v = fn(c) } end
        table.sort(t, function(a, b) if desc then return a.v > b.v else return a.v < b.v end end)
        local r = {}; for k, rec in ipairs(t) do r[rec.i] = k end; return r
    end
    local rFlux = rankBy(function(c) return c.flux_boost or 0 end, true)
    local rVad  = rankBy(function(c) return c.vad_align  or 0 end, true)
    local rProx = rankBy(function(c) return math.abs(c.time - rt) end, false)
    local rDur  = rankBy(function(c) return c.duration or 0 end, true)
    local rSrc  = rankBy(function(c) return Lzt.getSourceConfidence(c.threshold) end, true)
    local bestI, bestSum = 1, 1e9
    for i = 1, candidateCount do
        local s = (rFlux[i] / candidateCount) + (rVad[i] / candidateCount)
            + (rProx[i] / candidateCount) + (rDur[i] / candidateCount) + (rSrc[i] / candidateCount)
        if s < bestSum then bestSum = s; bestI = i end
    end
    return cands[bestI]
end

function Lzt.pickTime(cands, ref, isStart)
    local cls = Lzt.findClusters(cands, Lzt.lazyConfig.cluster_max_dist)
    local bc, bcm = nil, 0
    for _, cl in ipairs(cls) do
        local cm = 0; for _, p in ipairs(cl) do cm = cm + (p.score or 0) end
        if cm > bcm then bcm = cm; bc = cl end
    end
    if bc then
        local k = math.min(3, #bc); local nm = bcm / k
        if nm > Lzt.lazyConfig.min_cluster_mass then return Lzt.weightedMedianTime(bc), true end
    end
    table.sort(cands, function(a, b) return (a.score or 0) > (b.score or 0) end)
    if cands[1] and (cands[1].score or 0) > Lzt.lazyConfig.min_score_threshold then return cands[1].time, true end
    local alt = Lzt.rankFusionPick(cands, ref, isStart); if alt then return alt.time, true end
    return ref, false
end

function Lzt.runClusterAnalysis(subs, sel, lim, files, opts)
    local ss, se, asg = Lzt.loadLazyData(files); if #ss == 0 then return 0 end
    local modified = 0
    local applyStart, applyEnd = opts.apply_start, opts.apply_end
    local enableTagging, tagMode, tagScope = opts.enable_tagging, opts.tag_mode, opts.tag_scope
    local seq = Lzt.orderedByStart(subs, sel)
    for idx, ii in ipairs(seq) do
        progress("Analyzing (Cluster, intra ±" .. tostring(lim) .. " ms)...", idx / math.max(#seq, 1) * 100)
        local l = subs[ii]
        if l.class == "dialogue" then
            local os, oe = l.start_time, l.end_time
            local ns, ne = os, oe
            local den = Lzt.getDensity((os + oe) / 2, asg)
            if applyStart then
                local sc = {}
                local hi = math.min(os + lim, oe - Lzt.lazyConfig.min_duration)
                local k = Lzt.lowerBound(ss, os)
                while ss[k] and ss[k].time <= hi do
                    table.insert(sc, Lzt.copyCandidate(ss[k])); k = k + 1
                end
                if Lzt.auxFlux or Lzt.auxVad then Lzt.enrichWithAux(sc, Lzt.auxFlux, Lzt.auxVad, "onset") end
                for _, cv in ipairs(sc) do cv.score = Lzt.calculateScore(cv, os, lim, den) end
                if #sc > 0 then
                    local pt, ok = Lzt.pickTime(sc, os, true)
                    if ok then ns = Lzt.roundMs(pt) end
                end
            end
            if applyEnd then
                local ec = {}
                local lo = math.max(oe - lim, os + Lzt.lazyConfig.min_duration)
                local k = Lzt.lowerBound(se, lo)
                while se[k] and se[k].time <= oe do
                    table.insert(ec, Lzt.copyCandidate(se[k])); k = k + 1
                end
                if Lzt.auxFlux or Lzt.auxVad then Lzt.enrichWithAux(ec, Lzt.auxFlux, Lzt.auxVad, "offset") end
                for _, cv in ipairs(ec) do cv.score = Lzt.calculateScore(cv, oe, lim, den) end
                if #ec > 0 then
                    local pt, ok = Lzt.pickTime(ec, oe, false)
                    if ok then ne = Lzt.roundMs(pt) end
                end
            end
            if applyStart or applyEnd then
                local changed = (ns ~= os) or (ne ~= oe)
                if changed then
                    local ok, why = Lzt.validateIntra(ns, ne, os, oe)
                    if not ok then
                        local ok2, why2, ns2, ne2 = Lzt.clampIntra(ns, ne, os, oe)
                        if ok2 then
                            l.start_time = ns2; l.end_time = ne2; modified = modified + 1
                            Lzt.tagDecider(l, os, oe, ns2, ne2, applyStart, applyEnd, enableTagging, tagMode, tagScope)
                        else
                            if enableTagging then Lzt.addLazyTag(l, "Reject:" .. (why2 or why)) end
                        end
                    else
                        l.start_time = ns; l.end_time = ne; modified = modified + 1
                        Lzt.tagDecider(l, os, oe, ns, ne, applyStart, applyEnd, enableTagging, tagMode, tagScope)
                    end
                else
                    Lzt.tagDecider(l, os, oe, ns, ne, applyStart, applyEnd, enableTagging, tagMode, tagScope)
                end
                subs[ii] = l
            end
        end
    end
    return modified
end

function Lzt.normalizeVadToMs(vadData)
    if not vadData or #vadData == 0 then return {} end
    local scale = finiteNumber(vadData.time_scale)
    if not scale or scale <= 0 then
        local vmax = 0
        for _, s in ipairs(vadData) do
            local endTime = finiteNumber(s["end"])
            if endTime and endTime > vmax then vmax = endTime end
        end
        scale = vmax > 10000 and 1 or 1000
    end
    local out = {}
    for _, s in ipairs(vadData) do
        local startTime, endTime = finiteNumber(s.start), finiteNumber(s["end"])
        if startTime and endTime and endTime > startTime then
            table.insert(out, { start = startTime * scale, ["end"] = endTime * scale })
        end
    end
    table.sort(out, function(a, b) return a.start < b.start end)
    return out
end

function Lzt.normalizeFluxToMs(fluxData)
    if not fluxData or #fluxData == 0 then return fluxData end
    local scale = finiteNumber(fluxData.time_scale)
    if not scale or scale <= 0 then
        local fmax = 0
        for _, c in ipairs(fluxData) do
            local time = finiteNumber(c.time)
            if time and time > fmax then fmax = time end
        end
        scale = fmax > 10000 and 1 or 1000
    end
    if scale == 1 then return fluxData end
    local out = {}
    for _, c in ipairs(fluxData) do
        local time = finiteNumber(c.time)
        if time then out[#out+1] = { time = time * scale, type = c.type, score = c.score } end
    end
    return out
end

function Lzt.containingSilence(t, silences)
    local lo, hi, cand = 1, #silences, nil
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        if silences[mid].start <= t then cand = silences[mid]; lo = mid + 1
        else hi = mid - 1 end
    end
    if cand and t <= cand["end"] then return cand end
end

function Lzt.mergeSilenceToIntervals(files)
    local all = {}
    for threshold, path in pairs(files or {}) do
        local fh = io.open(path, "r")
        if fh then
            local cur
            for line in fh:lines() do
                local ss = line:match("silence_start:%s*([%d%.]+)")
                if ss then cur = tonumber(ss) * 1000 end
                local se = line:match("silence_end:%s*([%d%.]+)")
                if se and cur then
                    table.insert(all, { start = cur, ["end"] = tonumber(se) * 1000, threshold = threshold })
                    cur = nil
                end
            end
            fh:close()
        end
    end
    table.sort(all, function(a, b) return a.start < b.start end)
    local merged = {}
    for _, sil in ipairs(all) do
        if #merged == 0 then
            table.insert(merged, { start = sil.start, ["end"] = sil["end"], count = 1 })
        else
            local last = merged[#merged]
            if sil.start <= last["end"] + Lzt.lazyConfig.epsilon then
                last["end"] = math.max(last["end"], sil["end"])
                last.count = (last.count or 1) + 1
            else
                table.insert(merged, { start = sil.start, ["end"] = sil["end"], count = 1 })
            end
        end
    end
    return merged
end

function Lzt.findFluxExact(t, fluxData, wantType, tol)
    tol = tol or 20
    for _, f in ipairs(fluxData or {}) do
        if f.type == wantType and math.abs((f.time or 0) - t) <= tol then return f.time end
    end
end
function Lzt.findActivityBounds(osMs, oeMs, silences, fluxData)
    local tStart, tEnd, hasFs, hasFe = nil, nil, false, false
    local s0 = Lzt.containingSilence(osMs, silences)
    local cand = s0 and (s0["end"] + 1) or osMs
    if cand <= oeMs then
        tStart = cand
        local fx = Lzt.findFluxExact(tStart, fluxData, "onset", legacyActivityEdgeToleranceMs)
        if fx and fx >= osMs then tStart = fx; hasFs = true end
    end
    local s1 = Lzt.containingSilence(oeMs, silences)
    cand = s1 and (s1.start - 1) or oeMs
    if cand >= osMs then
        tEnd = cand
        local fx = Lzt.findFluxExact(tEnd, fluxData, "offset", legacyActivityEdgeToleranceMs)
        if fx and fx <= oeMs then tEnd = fx; hasFe = true end
    end
    return tStart, tEnd, hasFs, hasFe
end

function Lzt.runLazyFusionAnalysis(subs, sel, files, opts, fluxData)
    local silences = Lzt.mergeSilenceToIntervals(files)
    local applyStart, applyEnd = opts.apply_start, opts.apply_end
    local enableTagging, tagMode, tagScope = opts.enable_tagging, opts.tag_mode, opts.tag_scope
    local modified = 0
    local seq = Lzt.orderedByStart(subs, sel)
    for idx, ii in ipairs(seq) do
        progress("Analyzing (LazyFusion v2 EFS)...", idx / math.max(#seq, 1) * 100)
        local l = subs[ii]
        if l.class == "dialogue" then
            local osMs, oeMs = l.start_time, l.end_time
            local ns, ne = osMs, oeMs
            local tS, tE, hasFs, hasFe = Lzt.findActivityBounds(osMs, oeMs, silences, fluxData)
            if tS and tE then
                local ps = hasFs and 0 or legacyActivityPaddingMs
                local pe = hasFe and 0 or legacyActivityPaddingMs
                if applyStart then ns = tS - ps; if ns < 0 then ns = 0 end end
                if applyEnd   then ne = tE + pe end
                if ne - ns < Lzt.lazyConfig.min_duration then
                    local minimum = Lzt.lazyConfig.min_duration
                    if applyStart and applyEnd and oeMs - osMs >= minimum then
                        local center, half = (tS + tE) / 2, minimum / 2
                        ns, ne = center - half, center + half
                        if ns < osMs then ns, ne = osMs, osMs + minimum end
                        if ne > oeMs then ns, ne = oeMs - minimum, oeMs end
                    elseif applyStart and not applyEnd then
                        ns = math.max(osMs, ne - minimum)
                    elseif applyEnd and not applyStart then
                        ne = math.min(oeMs, ns + minimum)
                    end
                end
            else
                if enableTagging then Lzt.addLazyTag(l, "NoActivity") end
            end
            local changed = (math.abs(ns - osMs) > 1) or (math.abs(ne - oeMs) > 1)
            if changed then
                local ok, why = Lzt.validateIntra(ns, ne, osMs, oeMs)
                if not ok then
                    local ok2, why2, ns2, ne2 = Lzt.clampIntra(ns, ne, osMs, oeMs)
                    if ok2 then
                        l.start_time = Lzt.roundMs(ns2); l.end_time = Lzt.roundMs(ne2)
                        modified = modified + 1
                        Lzt.tagDecider(l, osMs, oeMs, ns2, ne2, applyStart, applyEnd, enableTagging, tagMode, tagScope)
                    else
                        if enableTagging then Lzt.addLazyTag(l, "Reject:" .. (why2 or why)) end
                    end
                else
                    l.start_time = Lzt.roundMs(ns); l.end_time = Lzt.roundMs(ne)
                    modified = modified + 1
                    Lzt.tagDecider(l, osMs, oeMs, ns, ne, applyStart, applyEnd, enableTagging, tagMode, tagScope)
                end
            else
                Lzt.tagDecider(l, osMs, oeMs, ns, ne, applyStart, applyEnd, enableTagging, tagMode, tagScope)
            end
            subs[ii] = l
        end
    end
    return modified
end

Lzt.clamp = Core.clamp
function Lzt.mergeIntervals(ints, eps)
    table.sort(ints, function(a, b) return a.start < b.start end)
    local out = {}
    for _, it in ipairs(ints) do
        if #out == 0 then out[1] = { start = it.start, ["end"] = it["end"] }
        else
            local last = out[#out]
            if it.start <= last["end"] + (eps or 0) then
                if it["end"] > last["end"] then last["end"] = it["end"] end
            else
                out[#out+1] = { start = it.start, ["end"] = it["end"] }
            end
        end
    end
    return out
end
function Lzt.intersect(a1, a2, b1, b2) local s = math.max(a1, b1); local e = math.min(a2, b2); if s < e then return s, e end end
function Lzt.noiseInWindow(mergedSilence, windowStart, windowEnd, eps)
    local cut = {}
    for _, si in ipairs(mergedSilence) do
        local s, e = Lzt.intersect(windowStart, windowEnd, si.start, si["end"])
        if s and e then cut[#cut+1] = { start = s, ["end"] = e } end
    end
    cut = Lzt.mergeIntervals(cut, eps)
    local noise = {}; local cur = windowStart
    for _, si in ipairs(cut) do
        if si.start > cur + (eps or 0) then noise[#noise+1] = { start = cur, ["end"] = si.start } end
        cur = math.max(cur, si["end"])
    end
    if cur < windowEnd - (eps or 0) then noise[#noise+1] = { start = cur, ["end"] = windowEnd } end
    return noise
end
function Lzt.totalMs(ints) local s = 0; for _, x in ipairs(ints) do s = s + (x["end"] - x.start) end; return s end
function Lzt.mergeNoiseSmallGaps(noise, gapMs)
    if #noise <= 1 then return noise end
    local out = { { start = noise[1].start, ["end"] = noise[1]["end"] } }
    for i = 2, #noise do
        local last = out[#out]
        local g = noise[i].start - last["end"]
        if g <= gapMs then if noise[i]["end"] > last["end"] then last["end"] = noise[i]["end"] end
        else out[#out+1] = { start = noise[i].start, ["end"] = noise[i]["end"] } end
    end
    return out
end
function Lzt.dropEdgeInconclusives(noise, windowStart, windowEnd, edgeMs)
    if #noise == 0 then return noise end
    local hasInner = false
    for _, n in ipairs(noise) do if n.start > windowStart and n["end"] < windowEnd then hasInner = true; break end end
    if not hasInner then return noise end
    local out = {}
    for _, n in ipairs(noise) do
        local len = n["end"] - n.start
        local el = (n.start <= windowStart + Lzt.tableConfig.eps); local er = (n["end"] >= windowEnd - Lzt.tableConfig.eps)
        if (el or er) and len <= edgeMs then else out[#out+1] = n end
    end
    return (#out > 0) and out or noise
end
function Lzt.center(t1, t2) return (t1 + t2) / 2 end
function Lzt.groupNoise(noise, mergeGapMs)
    if #noise == 0 then return {} end
    local groups, cur = {}, { noise[1] }
    for i = 2, #noise do
        local g = noise[i].start - noise[i-1]["end"]
        if g <= mergeGapMs then cur[#cur+1] = noise[i]
        else groups[#groups+1] = cur; cur = { noise[i] } end
    end
    groups[#groups+1] = cur; return groups
end
function Lzt.clusterSpan(group) return group[1].start, group[#group]["end"] end
function Lzt.clusterScore(group, windowStart, windowEnd)
    local gs = Lzt.totalMs(group); local s, e = Lzt.clusterSpan(group); local width = math.max(1, e - s)
    local cov = gs / width
    local prox = math.exp(-((Lzt.center(s, e) - Lzt.center(windowStart, windowEnd))^2) / (Lzt.tableConfig.sigma_ms^2))
    local frag = (#group - 1) / #group
    return Lzt.tableConfig.w_cov * cov + Lzt.tableConfig.w_prox * prox - Lzt.tableConfig.w_frag * frag
end
function Lzt.parseLazyFileTable(fp, t)
    local segs, dur = {}, nil
    local fh = io.open(fp, "r"); if not fh then return segs, dur end
    local cur
    for l in fh:lines() do
        local hours, minutes, seconds = l:match("Duration:%s*(%d+):(%d+):([%d%.]+)")
        if hours then dur = (tonumber(hours) * 3600 + tonumber(minutes) * 60 + tonumber(seconds)) * 1000 end
        local ss = l:match("silence_start:%s*([%d%.]+)"); if ss then cur = tonumber(ss) * 1000 end
        local se, sd = l:match("silence_end:%s*([%d%.]+)%s*|%s*silence_duration:%s*([%d%.]+)")
        if se and cur then
            local dms = tonumber(sd) * 1000
            if dms >= ((Lzt.lazyConfig.thresholds[t] and Lzt.lazyConfig.thresholds[t].min_silence_dur) or 100) then
                table.insert(segs, { start = cur, ["end"] = tonumber(se) * 1000, duration = dms, threshold = t })
            end
            cur = nil
        end
    end
    fh:close(); return segs, dur
end
function Lzt.loadLazyDataTable(fps)
    local rs, maxdur = {}, 0
    for t, p in pairs(fps) do
        local lst, dur = Lzt.parseLazyFileTable(p, t)
        if dur and dur > maxdur then maxdur = dur end
        for _, s in ipairs(lst) do table.insert(rs, s) end
    end
    table.sort(rs, function(a, b) return a.start < b.start end)
    local ss, se = {}, {}
    for _, s in ipairs(rs) do
        table.insert(ss, { time = s["end"],  duration = s.duration, threshold = s.threshold })
        table.insert(se, { time = s.start,   duration = s.duration, threshold = s.threshold })
    end
    return ss, se, rs, maxdur
end
function Lzt.buildNoiseTable(mergedSilences, windowStart, windowEnd, savePath)
    local noise = Lzt.noiseInWindow(mergedSilences, windowStart, windowEnd, Lzt.tableConfig.eps)
    noise = Lzt.mergeNoiseSmallGaps(noise, Lzt.tableConfig.merge_gap_ms)
    if savePath then
        local f = io.open(savePath, "w")
        if f then
            f:write("start_ms,end_ms,duration_ms\n")
            for _, n in ipairs(noise) do f:write(string.format("%d,%d,%d\n", n.start, n["end"], n["end"] - n.start)) end
            f:close()
        end
    end
    return noise
end

function Lzt.runTableAnalysis(subs, sel, lim, files, opts)
    local _, _, rs, maxdur = Lzt.loadLazyDataTable(files)
    if not rs or #rs == 0 then return 0 end
    local raw = {}
    for _, s in ipairs(rs) do raw[#raw+1] = { start = s.start, ["end"] = s["end"] } end
    local merged = Lzt.mergeIntervals(raw, Lzt.tableConfig.eps)
    local base = files[40] or files[30] or files[50]
    if opts.table_csv and base and maxdur and maxdur > 0 then
        local folder = base:gsub("[^\\/]+$", "")
        Lzt.buildNoiseTable(merged, 0, maxdur, folder .. "noise_table_global.csv")
    end
    local applyStart, applyEnd = opts.apply_start, opts.apply_end
    local enableTag, tagMode, tagScope = opts.enable_tagging, opts.tag_mode, opts.tag_scope
    local modified = 0
    local seq = Lzt.orderedByStart(subs, sel)
    for idx, ii in ipairs(seq) do
        progress("Analyzing (Table, intra ±" .. tostring(lim) .. " ms)...", idx / math.max(#seq, 1) * 100)
        local l = subs[ii]
        if l.class == "dialogue" then
            local os, oe = l.start_time, l.end_time
            local minD = Lzt.lazyConfig.min_duration
            local startLower, startUpper = os, math.min(oe - minD, os + lim)
            local endLower, endUpper = math.max(os + minD, oe - lim), oe
            if startUpper < startLower then startUpper = startLower end
            if endUpper < endLower then endLower = endUpper end
            local noise = Lzt.noiseInWindow(merged, os, oe, Lzt.tableConfig.eps)
            noise = Lzt.mergeNoiseSmallGaps(noise, Lzt.tableConfig.merge_gap_ms)
            noise = Lzt.dropEdgeInconclusives(noise, os, oe, Lzt.tableConfig.edge_drop_ms)
            if #noise > 1 then
                local pruned = {}
                for _, n in ipairs(noise) do if (n["end"] - n.start) >= Lzt.tableConfig.min_noise_ms then pruned[#pruned+1] = n end end
                if #pruned > 0 then noise = pruned end
            end
            local ns, ne = os, oe; local changed = false
            if #noise == 0 then
            elseif #noise == 1 then
                local n = noise[1]
                if applyStart then ns = Lzt.clamp(n.start, startLower, startUpper) end
                if applyEnd   then ne = Lzt.clamp(n["end"], endLower, endUpper) end
                if ne - ns < minD then
                    if applyStart and applyEnd then
                        local c = Lzt.center(n.start, n["end"])
                        ns = Lzt.clamp(math.floor(c - minD/2 + 0.5), startLower, startUpper)
                        ne = Lzt.clamp(ns + minD, endLower, endUpper)
                    elseif applyStart then
                        ns = Lzt.clamp(ne - minD, startLower, startUpper)
                    elseif applyEnd then
                        ne = Lzt.clamp(ns + minD, endLower, endUpper)
                    end
                end
                changed = (ns ~= os) or (ne ~= oe)
            else
                local groups = Lzt.groupNoise(noise, Lzt.tableConfig.merge_gap_ms)
                local bestG, bestScore = groups[1], -1e9
                for _, group in ipairs(groups) do
                    local sc = Lzt.clusterScore(group, os, oe)
                    if sc > bestScore then bestScore = sc; bestG = group end
                end
                local cs, ce = Lzt.clusterSpan(bestG)
                if bestG[1].start <= os + Lzt.tableConfig.eps and (bestG[1]["end"] - bestG[1].start) <= Lzt.tableConfig.edge_drop_ms and #bestG > 1 then
                    cs = bestG[2].start
                end
                if bestG[#bestG]["end"] >= oe - Lzt.tableConfig.eps and (bestG[#bestG]["end"] - bestG[#bestG].start) <= Lzt.tableConfig.edge_drop_ms and #bestG > 1 then
                    ce = bestG[#bestG-1]["end"]
                end
                if applyStart then ns = Lzt.clamp(cs, startLower, startUpper) end
                if applyEnd   then ne = Lzt.clamp(ce, endLower, endUpper) end
                if ne - ns < minD then
                    local big = bestG[1]; local blen = big["end"] - big.start
                    for _, n in ipairs(bestG) do
                        local len = n["end"] - n.start
                        if len > blen then big = n; blen = len end
                    end
                    if applyStart then ns = Lzt.clamp(big.start, startLower, startUpper) end
                    if applyEnd then ne = Lzt.clamp(big["end"], endLower, endUpper) end
                    if ne - ns < minD then
                        if applyStart and applyEnd then
                            local c = Lzt.center(ns, ne)
                            ns = Lzt.clamp(math.floor(c - minD/2 + 0.5), startLower, startUpper)
                            ne = Lzt.clamp(ns + minD, endLower, endUpper)
                        elseif applyStart then
                            ns = Lzt.clamp(ne - minD, startLower, startUpper)
                        elseif applyEnd then
                            ne = Lzt.clamp(ns + minD, endLower, endUpper)
                        end
                    end
                end
                changed = (ns ~= os) or (ne ~= oe)
            end
            if applyStart or applyEnd then
                if changed then
                    local ok, why = Lzt.validateIntra(ns, ne, os, oe)
                    if not ok then
                        local ok2, why2, ns2, ne2 = Lzt.clampIntra(ns, ne, os, oe)
                        if ok2 then
                            l.start_time, l.end_time = ns2, ne2
                            modified = modified + 1
                            Lzt.tagDecider(l, os, oe, ns2, ne2, applyStart, applyEnd, enableTag, tagMode, tagScope)
                        else
                            if enableTag then Lzt.addLazyTag(l, "Reject:" .. (why2 or why)) end
                        end
                    else
                        l.start_time, l.end_time = ns, ne
                        modified = modified + 1
                        Lzt.tagDecider(l, os, oe, ns, ne, applyStart, applyEnd, enableTag, tagMode, tagScope)
                    end
                    subs[ii] = l
                else
                    Lzt.tagDecider(l, os, oe, ns, ne, applyStart, applyEnd, enableTag, tagMode, tagScope)
                    subs[ii] = l
                end
            end
        end
    end
    return modified
end

function Lzt.run(subs, sel, paths, opts)
    opts = type(opts) == "table" and opts or {}
    paths = type(paths) == "table" and paths or {}
    Lzt.auxVad, Lzt.auxFlux = nil, nil
    local files = {}
    local function addFile(threshold, path)
        if type(path) ~= "string" or path == "" then return end
        local handle = io.open(path, "r")
        if not handle then return end
        local hasData = handle:read(1) ~= nil
        handle:close()
        if hasData then files[threshold] = path end
    end
    addFile(30, paths.sil30)
    addFile(40, paths.sil40)
    addFile(50, paths.sil50)
    if not (files[30] or files[40] or files[50]) then return nil end
    local selected = Lzt.orderedByStart(subs, sel)
    local originals = {}
    for _, i in ipairs(selected) do
        local line = subs[i]
        if line and line.class == "dialogue" then
            originals[i] = Core.deepCopy(line)
            line.effect = Lzt.stripLZ(line.effect)
            subs[i] = line
        end
    end
    local function execute()
        if opts.silences_only then
            return Lzt.runLazyFusionAnalysis(subs, selected, files, opts, nil)
        end
        local method = opts.method
        local flux = (type(paths.flux) == "string" and paths.flux ~= "")
            and Lzt.normalizeFluxToMs(Lzt.parseFLUXtsv(paths.flux)) or nil
        if method == "LazyFusion" then
            return Lzt.runLazyFusionAnalysis(subs, selected, files, opts, flux)
        elseif method == "Table (±ms)" then
            local single = {}
            if files[40] then single[40] = files[40]
            elseif files[30] then single[30] = files[30]
            else single[50] = files[50] end
            local lim = math.max(0, finiteNumber(opts.limit) or defaultLegacyLimitMs)
            return Lzt.runTableAnalysis(subs, selected, lim, single, opts)
        end
        Lzt.auxVad = (type(paths.vad) == "string" and paths.vad ~= "")
            and Lzt.normalizeVadToMs(Lzt.parseVADtsv(paths.vad)) or nil
        Lzt.auxFlux = flux
        local lim = math.max(0, finiteNumber(opts.limit) or defaultLegacyLimitMs)
        return Lzt.runClusterAnalysis(subs, selected, lim, files, opts)
    end
    local ok, result = pcall(execute)
    Lzt.auxVad, Lzt.auxFlux = nil, nil
    if not ok then
        for index, line in pairs(originals) do subs[index] = line end
        error(result, 0)
    end
    return result
end

local Timing = {
    VERSION = moduleVersion,
    version = moduleVersion,
    trim = trim, round = round, clamp = clamp, lowerBound = lowerBound, overlapLen = overlapLen,
    progress = progress, visibleText = visibleText, hasDrawing = hasDrawing,
    utf8Len = utf8Len, readableChars = readableChars,
    styleOk = styleOk, isSpoken = isSpoken, frameToMs = frameToMs,
    mergeIntervals = mergeIntervals,
    parseSilenceFile = parseSilenceFile, parseVadFile = parseVadFile,
    parseFluxFile = parseFluxFile, parseEnvFile = parseEnvFile,
    parseKeyframeFile = parseKeyframeFile, getKeyframes = getKeyframes,
    scriptDirAndBase = scriptDirAndBase, listDir = listDir,
    classifyDataFile = classifyDataFile, chapterOf = chapterOf,
    discoverPaths = discoverPaths, pathKeys = pathKeys,
    buildSignals = buildSignals, detectVoice = detectVoice, tune = tune,
    lzt = Lzt,
}

Timing.reconstructor = (function()
local Reconstructor = {
    _NAME = "kite.MacariaRevert",
    _VERSION = "1.0.0",
}

local Context = require("kite.AssContext")
local checkCancelled = LineOps.checkCancelled
local spacingWidthIterations = 32
local spacingClusterIterations = 12
local minimumActiveCopies = 3
local minimumSpaceSeparation = 4
local defaults = {
    position_tolerance = 4,
    row_tolerance = 20,
    time_tolerance_ms = 10,
    minimum_chain_units = 2,
    minimum_timing_coverage = 0.45,
    maximum_timing_coverage = 2.00,
    anchor_support_ratio = 0.12,
    infer_spaces = true,
    emit_alignment = true,
    default_alignment = 2,
    res_x = 1280,
    res_y = 720,
}

local abs, floor, max, min = math.abs, math.floor, math.max, math.min

local shallowCopy = Core.copy

local function mergedOptions(opts)
    local out = shallowCopy(defaults)
    for key, value in pairs(opts or {}) do out[key] = value end
    for key, value in pairs(defaults) do
        if type(value) == "number" then
            out[key] = max(0, finiteNumber(out[key]) or value)
        elseif type(out[key]) ~= type(value) then out[key] = value end
    end
    out.minimum_chain_units = math.max(1, math.floor(out.minimum_chain_units))
    out.maximum_timing_coverage = math.max(out.minimum_timing_coverage, out.maximum_timing_coverage)
    if out.res_x <= 0 then out.res_x = defaults.res_x end
    if out.res_y <= 0 then out.res_y = defaults.res_y end
    return out
end

local function median(values) return Core.median(values, true) end

local function splitCsv(s, limit)
    local out, at = {}, 1
    while (not limit or #out < limit - 1) do
        local comma = s:find(",", at, true)
        if not comma then break end
        out[#out + 1] = s:sub(at, comma - 1)
        at = comma + 1
    end
    out[#out + 1] = s:sub(at)
    return out
end

local function parseTime(value)
    local hours, minutes, seconds, fraction = tostring(value or ""):match("^(%d+):(%d+):(%d+)%.(%d+)$")
    hours, minutes, seconds = finiteNumber(hours), finiteNumber(minutes), finiteNumber(seconds)
    if not hours or not minutes or not seconds or minutes >= 60 or seconds >= 60 then return nil end
    return finiteNumber(((hours * 60 + minutes) * 60 + seconds) * 1000 + round(tonumber("0." .. fraction) * 1000))
end

local function formatTime(ms)
    local cs = max(0, floor((finiteNumber(ms) or 0) / 10 + 0.5))
    local h = floor(cs / 360000)
    cs = cs - h * 360000
    local m = floor(cs / 6000)
    cs = cs - m * 6000
    local s = floor(cs / 100)
    cs = cs - s * 100
    return string.format("%d:%02d:%02d.%02d", h, m, s, cs)
end

local function visibleText(text)
    local parts, hadDrawing = {}, false
    for _, section in ipairs(LineOps.scanSections(text)) do
        if section.type == "text" then parts[#parts + 1] = section.text
        elseif section.type == "drawing" then hadDrawing = true end
    end
    return table.concat(parts), hadDrawing
end

local function transformDuration(text, duration)
    local best
    for _, call in ipairs(LineOps.tagCalls(text, "t")) do
        if call.top_level then
            local transform = Context.transform(call.value, duration, 0)
            local span = transform and finiteNumber(transform.endTime - transform.startTime)
            if span and span > 0 then best = best and max(best, span) or span end
        end
    end
    return best and round(best) or nil
end

local function horizontalAlignment(an)
    if not an then return nil end
    local h = an % 3
    if h == 1 then return 1 end
    if h == 2 then return 2 end
    return 3
end

function Reconstructor.parseAssEvent(line)
    local kind, body = tostring(line or ""):match("^%s*(Dialogue):%s*(.*)$")
    if not kind then kind, body = tostring(line or ""):match("^%s*(Comment):%s*(.*)$") end
    if not kind then return nil end
    local f = splitCsv(body, 10)
    if #f ~= 10 then return nil, "Incomplete ASS event" end
    local start_time, end_time = parseTime(f[2]), parseTime(f[3])
    if not start_time or not end_time then return nil, "Invalid ASS time" end
    return {
        class = "dialogue",
        comment = kind == "Comment",
        layer = tonumber(f[1]) or 0,
        start_time = start_time,
        end_time = end_time,
        style = f[4],
        actor = f[5],
        margin_l = tonumber(f[6]) or 0,
        margin_r = tonumber(f[7]) or 0,
        margin_t = tonumber(f[8]) or 0,
        effect = f[9],
        text = f[10],
    }
end

function Reconstructor.formatEvent(line)
    local kind = line.comment == false and "Dialogue" or "Comment"
    return string.format("%s: %d,%s,%s,%s,%s,%d,%d,%d,%s,%s",
        kind,
        tonumber(line.layer) or 0,
        formatTime(line.start_time),
        formatTime(line.end_time),
        tostring(line.style or "Default"),
        tostring(line.actor or ""),
        tonumber(line.margin_l) or 0,
        tonumber(line.margin_r) or 0,
        tonumber(line.margin_t or line.margin_v) or 0,
        tostring(line.effect or ""),
        tostring(line.text or ""))
end

local function normalizeEvent(value, opts)
    local event, err
    if type(value) == "string" then
        event, err = Reconstructor.parseAssEvent(value)
    elseif type(value) == "table" and value.class == "dialogue" then
        event = value
    end
    if not event then return nil, err end
    local start_time = finiteNumber(event.start_time)
    local end_time = finiteNumber(event.end_time)
    local text, hadDrawing = visibleText(event.text)
    if not start_time or not end_time or end_time <= start_time then
        return nil, "Non-positive or invalid duration"
    end
    if text == "" then
        if hadDrawing then return nil, "ASS drawing \\p skipped" end
        return nil, "empty visible text"
    end
    local x, y = Context.explicitPosition(event.text, end_time - start_time, 0)
    if not finiteNumber(x) or not finiteNumber(y) then return nil, "no usable position or movement" end
    local style = opts.styles and opts.styles[event.style]
    local an = Context.alignment(event.text, {align=style and (style.align or style.alignment) or opts.default_alignment})
    return {
        source = event,
        layer = tonumber(event.layer) or 0,
        start_time = start_time,
        end_time = end_time,
        style = tostring(event.style or "Default"),
        actor = tostring(event.actor or ""),
        effect = tostring(event.effect or ""),
        text = text,
        x = x,
        y = y,
        an = an,
        h_align = horizontalAlignment(an),
        transform_duration = transformDuration(event.text, end_time - start_time),
        has_pos = Context.firstTag(event.text, "pos") ~= nil,
        has_move = Context.firstTag(event.text, "move") ~= nil,
    }
end

local function groupKey(style, text)
    return style .. "\0" .. text
end

local function observationsByText(observations)
    local buckets = {}
    for _, observation in ipairs(observations) do
        checkCancelled()
        local key = groupKey(observation.style, observation.text)
        if not buckets[key] then buckets[key] = {} end
        local bucket = buckets[key]
        bucket[#bucket + 1] = observation
    end
    return buckets
end

local function dominantHorizontalAlignment(observations)
    local counts, best, bestCount = {}, nil, 0
    for _, o in ipairs(observations) do
        checkCancelled()
        if o.h_align then
            counts[o.h_align] = (counts[o.h_align] or 0) + 1
            if counts[o.h_align] > bestCount then
                best, bestCount = o.h_align, counts[o.h_align]
            end
        end
    end
    return best
end

local function clusterPrimary(observations, hAlign, opts)
    local primary = {}
    for _, o in ipairs(observations) do
        checkCancelled()
        if not hAlign or o.h_align == hAlign then primary[#primary + 1] = o end
    end
    table.sort(primary, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        if a.x ~= b.x then return a.x < b.x end
        return a.start_time < b.start_time
    end)

    local clusters = {}
    for _, o in ipairs(primary) do
        checkCancelled()
        local best, best_d
        for _, c in ipairs(clusters) do
            local dx, dy = o.x - c.x, o.y - c.y
            if abs(dx) <= opts.position_tolerance and abs(dy) <= opts.position_tolerance then
                local d = dx * dx + dy * dy
                if not best_d or d < best_d then best, best_d = c, d end
            end
        end
        if not best then
            best = { points = {}, sum_x = 0, sum_y = 0, x = o.x, y = o.y }
            clusters[#clusters + 1] = best
        end
        best.points[#best.points + 1] = o
        best.sum_x = best.sum_x + o.x
        best.sum_y = best.sum_y + o.y
        best.x = best.sum_x / #best.points
        best.y = best.sum_y / #best.points
    end

    local maxSupport = 0
    for _, c in ipairs(clusters) do maxSupport = max(maxSupport, #c.points) end
    local threshold = max(1, floor(maxSupport * opts.anchor_support_ratio + 0.5))
    local kept = {}
    for _, c in ipairs(clusters) do
        if #c.points >= threshold then kept[#kept + 1] = c end
    end
    if #kept == 0 and #clusters > 0 then
        table.sort(clusters, function(a, b) return #a.points > #b.points end)
        kept[1] = clusters[1]
    end
    return kept
end

local function nearestUnit(units, observation, direction)
    if #units == 1 then return units[1] end
    local best, best_d
    for _, unit in ipairs(units) do
        local dx, dy = observation.x - unit.x, observation.y - unit.y
        local allowed = true
        if observation.h_align == 3 then
            if direction == "rtl" then allowed = unit.x >= observation.x
            else allowed = unit.x <= observation.x end
        end
        if allowed then
            local d = dx * dx + dy * dy
            if not best_d or d < best_d then best, best_d = unit, d end
        end
    end
    if best then return best end
    for _, unit in ipairs(units) do
        local dx, dy = observation.x - unit.x, observation.y - unit.y
        local d = dx * dx + dy * dy
        if not best_d or d < best_d then best, best_d = unit, d end
    end
    return best
end

local function finalizeUnit(unit)
    local rightPositions = {}
    local minStart, maxStart
    local intervals = {}
    for _, o in ipairs(unit.observations) do
        checkCancelled()
        minStart = minStart and min(minStart, o.start_time) or o.start_time
        maxStart = maxStart and max(maxStart, o.start_time) or o.start_time
        if o.h_align == 3 then rightPositions[#rightPositions + 1] = o.x end
        if not unit.anchor_h or o.h_align == unit.anchor_h then
            local key = tostring(round(o.start_time)) .. ":" .. tostring(round(o.end_time))
            local candidate = intervals[key]
            if not candidate then
                candidate = {
                    start_time = round(o.start_time),
                    end_time = round(o.end_time),
                    support = 0,
                    layers = {},
                }
                intervals[key] = candidate
            end
            candidate.support = candidate.support + 1
            candidate.layers[o.layer] = true
        end
    end
    unit.phase_span = max(0, (maxStart or 0) - (minStart or 0))
    unit.right = median(rightPositions)
    unit.candidates = {}
    for _, candidate in pairs(intervals) do
        if candidate.end_time > candidate.start_time then
            candidate.unit = unit
            unit.candidates[#unit.candidates + 1] = candidate
        end
    end
    table.sort(unit.candidates, function(a, b)
        if a.start_time ~= b.start_time then return a.start_time < b.start_time end
        return a.end_time < b.end_time
    end)
end

local function buildUnits(observations, opts)
    local buckets = {}
    for _, o in ipairs(observations) do
        checkCancelled()
        local key = groupKey(o.style, o.text)
        local bucket = buckets[key]
        if not bucket then
            bucket = { style = o.style, text = o.text, observations = {} }
            buckets[key] = bucket
        end
        bucket.observations[#bucket.observations + 1] = o
    end

    local units, nextId = {}, 1
    for _, bucket in pairs(buckets) do
        local hAlign = dominantHorizontalAlignment(bucket.observations)
        local clusters = clusterPrimary(bucket.observations, hAlign, opts)
        local localUnits = {}
        for _, c in ipairs(clusters) do
            local xs, ys = {}, {}
            for _, o in ipairs(c.points) do
                checkCancelled()
                xs[#xs + 1], ys[#ys + 1] = o.x, o.y
            end
            local unit = {
                id = nextId,
                style = bucket.style,
                text = bucket.text,
                x = median(xs),
                y = median(ys),
                anchor_h = hAlign,
                observations = {},
            }
            nextId = nextId + 1
            units[#units + 1] = unit
            localUnits[#localUnits + 1] = unit
        end
        for _, o in ipairs(bucket.observations) do
            checkCancelled()
            local unit = nearestUnit(localUnits, o, opts.direction or "ltr")
            if unit then unit.observations[#unit.observations + 1] = o end
        end
    end
    for _, unit in ipairs(units) do finalizeUnit(unit) end
    return units
end

local function buildRows(units, opts)
    table.sort(units, function(a, b)
        if a.style ~= b.style then return a.style < b.style end
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    local rows = {}
    for _, unit in ipairs(units) do
        local best, bestDistance
        for _, row in ipairs(rows) do
            checkCancelled()
            if row.style == unit.style then
                local d = abs(row.y - unit.y)
                if d <= opts.row_tolerance and (not bestDistance or d < bestDistance) then
                    best, bestDistance = row, d
                end
            end
        end
        if not best then
            best = { style = unit.style, y = unit.y, units = {}, sum_y = 0 }
            rows[#rows + 1] = best
        end
        best.units[#best.units + 1] = unit
        best.sum_y = best.sum_y + unit.y
        best.y = best.sum_y / #best.units
    end
    for _, row in ipairs(rows) do
        checkCancelled()
        table.sort(row.units, function(a, b) return a.x < b.x end)
    end
    return rows
end

local function betterPath(aLen, aDuration, bLen, bDuration)
    if aLen ~= bLen then return aLen > bLen end
    return aDuration > bDuration
end

local function bestChain(row, blocked, opts)
    local nodes = {}
    for _, unit in ipairs(row.units) do
        if not blocked.units[unit.id] then
            for _, candidate in ipairs(unit.candidates) do
                local key = unit.id .. ":" .. candidate.start_time .. ":" .. candidate.end_time
                if not blocked.nodes[key] then
                    nodes[#nodes + 1] = {
                        key = key,
                        unit = unit,
                        start_time = candidate.start_time,
                        end_time = candidate.end_time,
                        duration = candidate.end_time - candidate.start_time,
                        support = candidate.support,
                    }
                end
            end
        end
    end
    table.sort(nodes, function(a, b)
        if a.unit.x ~= b.unit.x then return a.unit.x < b.unit.x end
        if a.start_time ~= b.start_time then return a.start_time < b.start_time end
        return a.end_time < b.end_time
    end)

    local bestIndex
    for i, node in ipairs(nodes) do
        checkCancelled()
        node.path_len = 1
        node.path_duration = node.duration
        for j = 1, i - 1 do
            local prev = nodes[j]
            if prev.unit.id ~= node.unit.id
                and prev.unit.x + opts.position_tolerance < node.unit.x
                and abs(prev.end_time - node.start_time) <= opts.time_tolerance_ms then
                local pathLen = prev.path_len + 1
                local pathDuration = prev.path_duration + node.duration
                if betterPath(pathLen, pathDuration, node.path_len, node.path_duration) then
                    node.path_len = pathLen
                    node.path_duration = pathDuration
                    node.previous = j
                end
            end
        end
        if not bestIndex or betterPath(node.path_len, node.path_duration,
            nodes[bestIndex].path_len, nodes[bestIndex].path_duration) then
            bestIndex = i
        end
    end
    if not bestIndex then return nil end
    local path, at = {}, bestIndex
    while at do
        path[#path + 1] = nodes[at]
        at = nodes[at].previous
    end
    for index = 1, floor(#path / 2) do
        path[index], path[#path - index + 1] = path[#path - index + 1], path[index]
    end
    return path
end

local function styleAlignment(opts, styleName)
    local style = opts.styles and opts.styles[styleName]
    return tonumber(style and (style.align or style.alignment)) or opts.default_alignment
end

local function measureText(opts, styleName, text)
    if type(opts.measure_text) == "function" then
        local ok, width = pcall(opts.measure_text, styleName, text)
        if ok then return finiteNumber(width) end
    end
    local style = opts.styles and opts.styles[styleName]
    if style and aegisub and type(aegisub.text_extents) == "function" then
        local ok, width = pcall(aegisub.text_extents, style, text)
        if ok then return finiteNumber(width) end
    end
    return nil
end

local function unitBounds(unit, opts)
    local width = measureText(opts, unit.style, unit.text)
    if not width then return unit.x, unit.right or unit.x end
    local h = unit.anchor_h or horizontalAlignment(styleAlignment(opts, unit.style)) or 1
    if h == 2 then return unit.x - width / 2, unit.x + width / 2 end
    if h == 3 then return unit.x - width, unit.x end
    return unit.x, unit.x + width
end

local function inferredAlignment(path, row, opts)
    local left, right
    for _, node in ipairs(path) do
        local unit = node.unit
        local l, r = unitBounds(unit, opts)
        left = left and min(left, l) or l
        right = right and max(right, r) or r
    end
    local center = ((left or 0) + (right or left or 0)) / 2
    local h
    if center < opts.res_x / 3 then h = 1
    elseif center > opts.res_x * 2 / 3 then h = 3
    else h = 2 end
    local v
    if row.y < opts.res_y / 3 then v = 3
    elseif row.y > opts.res_y * 2 / 3 then v = 1
    else v = 2 end
    return (v - 1) * 3 + h
end

local function appendInferredSpace(text, unit, nextUnit, opts)
    if not opts.infer_spaces or not nextUnit then return text end
    if text:match("[%s]$") or text:match("\\[Nnh]$") then return text end
    if unit.space_after ~= nil then return unit.space_after and text .. " " or text end
    local space = measureText(opts, unit.style, " ")
    if not space or space <= 0 then return text end
    local _, right = unitBounds(unit, opts)
    local nextLeft = unitBounds(nextUnit, opts)
    local gap = nextLeft - right
    if gap >= max(1, space * 0.45) then return text .. " " end
    return text
end

local function commonField(path, name, fallback)
    local counts, best, bestCount = {}, fallback, 0
    for _, node in ipairs(path) do
        for _, o in ipairs(node.unit.observations) do
            checkCancelled()
            local value = o.source[name]
            if value ~= nil then
                local key = tostring(value)
                counts[key] = (counts[key] or 0) + 1
                if counts[key] > bestCount then best, bestCount = value, counts[key] end
            end
        end
    end
    return best
end

local function minimumNumericField(path, name, fallback)
    local best
    for _, node in ipairs(path) do
        for _, o in ipairs(node.unit.observations) do
            checkCancelled()
            local value = tonumber(o.source[name])
            if value ~= nil then best = best and min(best, value) or value end
        end
    end
    return best == nil and fallback or best
end

local function recoveredLine(path, row, opts, endTime, recovery)
    local parts = {}
    local alignment = inferredAlignment(path, row, opts)
    if opts.emit_alignment and alignment ~= styleAlignment(opts, row.style) then
        parts[#parts + 1] = "{\\an" .. alignment .. "}"
    end
    local first, elapsed = path[1].start_time, 0
    for index, node in ipairs(path) do
        checkCancelled()
        local nextNode = path[index + 1]
        local boundary = max(elapsed, round(((nextNode and nextNode.start_time or node.end_time) - first) / 10))
        parts[#parts + 1] = "{\\k" .. (boundary - elapsed) .. "}"
        parts[#parts + 1] = appendInferredSpace(node.unit.text, node.unit, nextNode and nextNode.unit, opts)
        elapsed = boundary
    end
    recovery.units, recovery.alignment = #path, alignment
    return {
        class = "dialogue", comment = true,
        layer = minimumNumericField(path, "layer", 0),
        start_time = first, end_time = endTime, style = row.style,
        actor = tostring(commonField(path, "actor", "") or ""),
        margin_l = finiteNumber(commonField(path, "margin_l", 0)) or 0,
        margin_r = finiteNumber(commonField(path, "margin_r", 0)) or 0,
        margin_t = finiteNumber(commonField(path, "margin_t", 0)) or 0,
        effect = "karaoke", text = table.concat(parts), recovery = recovery,
    }
end

local function lineFromChain(path, row, opts)
    local spans = {}
    for _, node in ipairs(path) do
        if node.unit.phase_span > 0 then spans[#spans + 1] = node.unit.phase_span end
    end
    local phaseDuration = median(spans) or 0
    phaseDuration = round(phaseDuration / 10) * 10
    local chainDuration = 0
    for _, node in ipairs(path) do chainDuration = chainDuration + node.duration end
    local coverage = phaseDuration > 0 and chainDuration / phaseDuration or 0
    if #path < opts.minimum_chain_units
        or phaseDuration <= 0
        or coverage < opts.minimum_timing_coverage
        or coverage > opts.maximum_timing_coverage then
        return nil, {
            units = #path,
            chain_duration = chainDuration,
            phase_duration = phaseDuration,
            coverage = coverage,
        }
    end

    return recoveredLine(path, row, opts, path[1].start_time + phaseDuration, {
        timing = "contiguous-event-chain", chain_duration = chainDuration,
        phase_duration = phaseDuration, coverage = coverage,
    })
end

local function recoverRow(row, opts, report)
    local recovered = {}
    local blocked = { units = {}, nodes = {} }
    while true do
        checkCancelled()
        local path = bestChain(row, blocked, opts)
        if not path or #path < opts.minimum_chain_units then break end
        local line, rejected = lineFromChain(path, row, opts)
        if line then
            recovered[#recovered + 1] = line
            for _, node in ipairs(path) do blocked.units[node.unit.id] = true end
        else
            for _, node in ipairs(path) do blocked.nodes[node.key] = true end
            report.rejected_chains[#report.rejected_chains + 1] = {
                style = row.style,
                y = row.y,
                units = rejected.units,
                coverage = rejected.coverage,
            }
        end
    end
    if #recovered == 0 then
        report.skipped_rows[#report.skipped_rows + 1] = {
            style = row.style,
            y = row.y,
            reason = "no contiguous temporal chain with sufficient length",
        }
    end
    return recovered
end

local function buildPhaseUnits(observations, opts)
    local units, byKey = {}, {}
    local buckets = observationsByText(observations)
    for _, active in ipairs(observations) do
        checkCancelled()
        local duration = active.transform_duration
        if duration and duration <= active.end_time - active.start_time + opts.time_tolerance_ms then
            local predecessor, best_score
            for _, candidate in ipairs(buckets[groupKey(active.style, active.text)]) do
                if candidate ~= active
                    and not candidate.transform_duration
                    and candidate.h_align == active.h_align
                    and abs(candidate.x - active.x) <= opts.position_tolerance
                    and abs(candidate.y - active.y) <= opts.position_tolerance
                    and abs(candidate.end_time - active.start_time) <= opts.time_tolerance_ms then
                    local score = abs(candidate.end_time - active.start_time)
                        + abs(candidate.x - active.x) + abs(candidate.y - active.y)
                    if not best_score or score < best_score then
                        predecessor, best_score = candidate, score
                    end
                end
            end
            if predecessor then
                local unit = {
                    id = #units + 1,
                    style = active.style,
                    text = active.text,
                    x = active.x,
                    y = active.y,
                    anchor_h = active.h_align or predecessor.h_align,
                    observations = { predecessor, active },
                    candidates = {},
                }
                unit.candidates[1] = {
                    unit = unit,
                    start_time = round(active.start_time),
                    end_time = round(active.start_time + duration),
                    support = 2,
                }
                local key = table.concat({unit.style, unit.text, unit.x, unit.y,
                    unit.candidates[1].start_time, unit.candidates[1].end_time}, "\0")
                local existing = byKey[key]
                if existing then
                    existing.observations[#existing.observations + 1] = predecessor
                    existing.observations[#existing.observations + 1] = active
                else
                    units[#units + 1], byKey[key] = unit, unit
                end
            end
        end
    end
    return units
end

local function lineFromPhaseChain(path, row, opts)
    local chainDuration = 0
    for _, node in ipairs(path) do chainDuration = chainDuration + node.end_time - node.start_time end
    return recoveredLine(path, row, opts, path[#path].end_time, {
        timing = "paired-transform-chain", chain_duration = chainDuration,
    })
end

local function recoverPhaseRows(units, opts)
    local recovered, consumed, recoveredRows = {}, {}, 0
    for _, row in ipairs(buildRows(units, opts)) do
        checkCancelled()
        local blocked = { units = {}, nodes = {} }
        local rowRecovered = false
        while true do
            checkCancelled()
            local path = bestChain(row, blocked, opts)
            if not path or #path < opts.minimum_chain_units then break end
            recovered[#recovered + 1] = lineFromPhaseChain(path, row, opts)
            rowRecovered = true
            for _, node in ipairs(path) do
                blocked.units[node.unit.id] = true
                for _, observation in ipairs(node.unit.observations) do consumed[observation] = true end
                    checkCancelled()
            end
        end
        if rowRecovered then recoveredRows = recoveredRows + 1 end
    end
    return recovered, consumed, recoveredRows
end

local function activeClusterKey(observation)
    return table.concat({
        observation.style,
        observation.text,
        round(observation.start_time),
        round(observation.end_time),
        round(observation.x * 10),
        round(observation.y * 10),
    }, "\0")
end

local function buildRepeatedActiveUnits(observations, opts)
    local buckets = {}
    local byText = observationsByText(observations)
    for _, observation in ipairs(observations) do
        checkCancelled()
        if observation.has_move and not observation.has_pos then
            local key = activeClusterKey(observation)
            local bucket = buckets[key]
            if not bucket then
                bucket = { observations = {} }
                buckets[key] = bucket
            end
            bucket.observations[#bucket.observations + 1] = observation
        end
    end

    local units = {}
    for _, bucket in pairs(buckets) do
        if #bucket.observations >= minimumActiveCopies then
            local active = bucket.observations[1]
            local body, best_score
            for _, candidate in ipairs(byText[groupKey(active.style, active.text)]) do
                if candidate.has_pos and not candidate.has_move
                    and candidate.h_align == active.h_align
                    and abs(candidate.x - active.x) <= opts.position_tolerance
                    and abs(candidate.y - active.y) <= opts.position_tolerance
                    and candidate.start_time > active.start_time
                    and candidate.start_time <= active.end_time + opts.time_tolerance_ms
                    and candidate.end_time > candidate.start_time then
                    local score = candidate.start_time - active.start_time
                        + abs(candidate.x - active.x) + abs(candidate.y - active.y)
                    if not best_score or score < best_score then body, best_score = candidate, score end
                end
            end
            if body then
                local observationsForUnit = {}
                for _, observation in ipairs(bucket.observations) do
                    checkCancelled()
                    observationsForUnit[#observationsForUnit + 1] = observation
                end
                observationsForUnit[#observationsForUnit + 1] = body
                units[#units + 1] = {
                    id = #units + 1,
                    style = active.style,
                    text = active.text,
                    x = active.x,
                    y = active.y,
                    anchor_h = active.h_align or body.h_align,
                    observations = observationsForUnit,
                    start_time = round(active.start_time),
                    active_end_time = round(active.end_time),
                    line_end_time = round(body.end_time),
                    active_copies = #bucket.observations,
                }
            end
        end
    end
    return units
end

local function buildRepeatedActiveGroups(units, opts)
    table.sort(units, function(a, b)
        if a.style ~= b.style then return a.style < b.style end
        if a.line_end_time ~= b.line_end_time then return a.line_end_time < b.line_end_time end
        if a.y ~= b.y then return a.y < b.y end
        return a.start_time < b.start_time
    end)
    local groups = {}
    for _, unit in ipairs(units) do
        local best, bestDistance
        for _, group in ipairs(groups) do
            checkCancelled()
            if group.style == unit.style
                and abs(group.line_end_time - unit.line_end_time) <= opts.time_tolerance_ms
                and abs(group.y - unit.y) <= opts.row_tolerance then
                local distance = abs(group.line_end_time - unit.line_end_time) + abs(group.y - unit.y)
                if not bestDistance or distance < bestDistance then best, bestDistance = group, distance end
            end
        end
        if not best then
            best = {
                style = unit.style,
                y = unit.y,
                line_end_time = unit.line_end_time,
                units = {},
                sum_y = 0,
            }
            groups[#groups + 1] = best
        end
        best.units[#best.units + 1] = unit
        best.sum_y = best.sum_y + unit.y
        best.y = best.sum_y / #best.units
    end
    return groups
end

local function annotateRepeatedActiveSpacing(groups, observations, opts)
    local equationsByStyle, pairDistances = {}, {}
    for _, group in ipairs(groups) do
        checkCancelled()
        for _, unit in ipairs(group.units) do
            local glyphs = {}
            for _, observation in ipairs(observations) do
                checkCancelled()
                if observation.has_pos and observation.has_move
                    and observation.style == unit.style
                    and abs(observation.y - unit.y) <= opts.position_tolerance
                    and abs(observation.end_time - unit.start_time) <= opts.time_tolerance_ms then
                    glyphs[#glyphs + 1] = observation
                end
            end
            table.sort(glyphs, function(a, b) return a.x < b.x end)
            if #glyphs > 0 then
                unit.first_glyph, unit.last_glyph = glyphs[1].text, glyphs[#glyphs].text
                unit.first_glyph_x, unit.last_glyph_x = glyphs[1].x, glyphs[#glyphs].x
            end
            if #glyphs >= 2 then
                local equations = equationsByStyle[unit.style]
                if not equations then equations = {}; equationsByStyle[unit.style] = equations end
                local pairs = pairDistances[unit.style]
                if not pairs then pairs = {}; pairDistances[unit.style] = pairs end
                for i = 1, #glyphs - 1 do
                    local distance = glyphs[i + 1].x - glyphs[i].x
                    if distance > 0 and unit.text:find(glyphs[i].text .. glyphs[i + 1].text, 1, true) then
                        local left, right = glyphs[i].text, glyphs[i + 1].text
                        equations[#equations + 1] = { left = left, right = right, distance = distance }
                        local key = left .. "\0" .. right
                        if not pairs[key] then pairs[key] = {} end
                        pairs[key][#pairs[key] + 1] = distance
                    end
                end
            end
        end
    end

    local widthsByStyle, defaultWidthByStyle = {}, {}
    for style, equations in pairs(equationsByStyle) do
        local distances, widths = {}, {}
        for _, equation in ipairs(equations) do
            distances[#distances + 1] = equation.distance
            widths[equation.left], widths[equation.right] = true, true
        end
        local initial = median(distances) or 1
        for glyph in pairs(widths) do widths[glyph] = initial end
        for _ = 1, spacingWidthIterations do
            local sums, counts = {}, {}
            for _, equation in ipairs(equations) do
                local leftTarget = max(1, equation.distance * 2 - widths[equation.right])
                local rightTarget = max(1, equation.distance * 2 - widths[equation.left])
                sums[equation.left] = (sums[equation.left] or 0) + leftTarget
                counts[equation.left] = (counts[equation.left] or 0) + 1
                sums[equation.right] = (sums[equation.right] or 0) + rightTarget
                counts[equation.right] = (counts[equation.right] or 0) + 1
            end
            for glyph in pairs(widths) do
                if counts[glyph] then widths[glyph] = (widths[glyph] + sums[glyph] / counts[glyph]) / 2 end
            end
        end
        widthsByStyle[style] = widths
        local learnedWidths = {}
        for _, width in pairs(widths) do learnedWidths[#learnedWidths + 1] = width end
        defaultWidthByStyle[style] = median(learnedWidths) or initial
        for key, distancesForPair in pairs(pairDistances[style] or {}) do
            pairDistances[style][key] = median(distancesForPair)
        end
    end

    local gapsByStyle = {}
    for _, group in ipairs(groups) do
        checkCancelled()
        table.sort(group.units, function(a, b)
            if a.start_time ~= b.start_time then return a.start_time < b.start_time end
            return a.x < b.x
        end)
        for i = 1, #group.units - 1 do
            local unit, nextUnit = group.units[i], group.units[i + 1]
            if unit.last_glyph_x and nextUnit.first_glyph_x then
                local widths = widthsByStyle[unit.style] or {}
                local pairKey = unit.last_glyph .. "\0" .. nextUnit.first_glyph
                local expected = pairDistances[unit.style] and pairDistances[unit.style][pairKey]
                if not expected then
                    local fallback = defaultWidthByStyle[unit.style]
                    local leftWidth = widths[unit.last_glyph]
                        or widths[unit.last_glyph:lower()] or widths[unit.last_glyph:upper()] or fallback
                    local rightWidth = widths[nextUnit.first_glyph]
                        or widths[nextUnit.first_glyph:lower()] or widths[nextUnit.first_glyph:upper()] or fallback
                    if leftWidth and rightWidth then expected = (leftWidth + rightWidth) / 2 end
                end
                if expected then
                    local item = {
                        unit = unit,
                        residual = nextUnit.first_glyph_x - unit.last_glyph_x - expected,
                    }
                    if not gapsByStyle[unit.style] then gapsByStyle[unit.style] = {} end
                    gapsByStyle[unit.style][#gapsByStyle[unit.style] + 1] = item
                end
            end
        end
    end

    for _, gaps in pairs(gapsByStyle) do
        if #gaps >= 2 then
            local low, high = gaps[1].residual, gaps[1].residual
            for _, item in ipairs(gaps) do
                low, high = min(low, item.residual), max(high, item.residual)
            end
            for _ = 1, spacingClusterIterations do
                local lowSum, lowCount, highSum, highCount = 0, 0, 0, 0
                for _, item in ipairs(gaps) do
                    if abs(item.residual - low) <= abs(item.residual - high) then
                        lowSum, lowCount = lowSum + item.residual, lowCount + 1
                    else
                        highSum, highCount = highSum + item.residual, highCount + 1
                    end
                end
                if lowCount > 0 then low = lowSum / lowCount end
                if highCount > 0 then high = highSum / highCount end
            end
            if high - low >= minimumSpaceSeparation then
                local threshold = (low + high) / 2
                for _, item in ipairs(gaps) do item.unit.space_after = item.residual > threshold end
            end
        end
    end
end

local function lineFromRepeatedActiveGroup(group, opts)
    table.sort(group.units, function(a, b)
        if a.start_time ~= b.start_time then return a.start_time < b.start_time end
        return a.x < b.x
    end)
    if #group.units < opts.minimum_chain_units then return nil end

    local path, tails = {}, {}
    for i, unit in ipairs(group.units) do
        local end_time = i < #group.units and group.units[i + 1].start_time or group.line_end_time
        if end_time <= unit.start_time then return nil end
        path[#path + 1] = {
            unit = unit,
            start_time = unit.start_time,
            end_time = end_time,
        }
        tails[#tails + 1] = unit.active_end_time - end_time
    end
    local commonTail = median(tails)

    return recoveredLine(path, group, opts, group.line_end_time, {
        timing = "repeated-active-body-chain", active_tail = commonTail,
    })
end

local function recoverRepeatedActiveRows(units, observations, opts)
    local recovered, coveredRows = {}, {}
    local groups = buildRepeatedActiveGroups(units, opts)
    annotateRepeatedActiveSpacing(groups, observations, opts)
    for _, group in ipairs(groups) do
        checkCancelled()
        local line = lineFromRepeatedActiveGroup(group, opts)
        if line then
            recovered[#recovered + 1] = line
            local first, last = line.start_time, line.end_time
            for _, unit in ipairs(group.units) do
                for _, observation in ipairs(unit.observations) do
                    checkCancelled()
                    first, last = min(first, observation.start_time), max(last, observation.end_time)
                end
            end
            coveredRows[#coveredRows + 1] = {style=group.style, y=group.y, start_time=first, end_time=last}
        end
    end
    return recovered, coveredRows
end

local function isCoveredRow(observation, coveredRows, opts)
    for _, row in ipairs(coveredRows) do
        checkCancelled()
        if row.style == observation.style and abs(row.y - observation.y) <= opts.row_tolerance
            and observation.start_time < row.end_time and observation.end_time > row.start_time then return true end
    end
    return false
end

function Reconstructor.recover(values, opts)
    opts = mergedOptions(opts)
    local report = {
        input_events = 0,
        observations = 0,
        skipped_events = {},
        skipped_rows = {},
        rejected_chains = {},
        warnings = {},
    }
    local observations = {}
    for i, value in ipairs(values or {}) do
        checkCancelled()
        report.input_events = report.input_events + 1
        local observation, err = normalizeEvent(value, opts)
        if observation then
            if not opts.effects or opts.effects[observation.effect] then
                observations[#observations + 1] = observation
            end
        else
            report.skipped_events[#report.skipped_events + 1] = { index = i, reason = err }
        end
    end
    report.observations = #observations
    local phaseUnits = buildPhaseUnits(observations, opts)
    local recovered, phaseConsumed, phaseRows = recoverPhaseRows(phaseUnits, opts)
    local afterPhase = {}
    for _, observation in ipairs(observations) do
        checkCancelled()
        if not phaseConsumed[observation] then afterPhase[#afterPhase + 1] = observation end
    end
    local activeUnits = buildRepeatedActiveUnits(afterPhase, opts)
    local activeLines, coveredRows = recoverRepeatedActiveRows(activeUnits, afterPhase, opts)
    for _, line in ipairs(activeLines) do recovered[#recovered + 1] = line end
    local remaining = {}
    for _, observation in ipairs(afterPhase) do
        checkCancelled()
        if not isCoveredRow(observation, coveredRows, opts) then remaining[#remaining + 1] = observation end
    end
    local units = buildUnits(remaining, opts)
    local rows = buildRows(units, opts)
    report.units = #units + #phaseUnits + #activeUnits
    report.rows = #rows + phaseRows + #coveredRows

    for _, row in ipairs(rows) do
        checkCancelled()
        local lines = recoverRow(row, opts, report)
        for _, line in ipairs(lines) do recovered[#recovered + 1] = line end
    end
    table.sort(recovered, function(a, b)
        if a.start_time ~= b.start_time then return a.start_time < b.start_time end
        if a.style ~= b.style then return a.style < b.style end
        return a.text < b.text
    end)
    report.recovered = #recovered
    return recovered, report
end

local function parseStyle(line)
    local body = line:match("^Style:%s*(.*)$")
    if not body then return nil end
    local f = splitCsv(body)
    if #f < 19 then return nil end
    return f[1], { name = f[1], align = tonumber(f[19]) }
end

function Reconstructor.recoverAssText(text, opts)
    opts = shallowCopy(opts or {})
    opts.styles = shallowCopy(opts.styles or {})
    local events = {}
    text = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local key, value = line:match("^(PlayRes[XY]):%s*(%d+)")
        if key == "PlayResX" and opts.res_x == nil then opts.res_x = tonumber(value) end
        if key == "PlayResY" and opts.res_y == nil then opts.res_y = tonumber(value) end
        local styleName, style = parseStyle(line)
        if styleName and not opts.styles[styleName] then opts.styles[styleName] = style end
        local event = Reconstructor.parseAssEvent(line)
        if event then events[#events + 1] = event end
    end
    return Reconstructor.recover(events, opts)
end

function Reconstructor.recoverSubs(subs, indices, opts)
    opts = shallowCopy(opts or {})
    opts.styles = shallowCopy(opts.styles or {})
    local selected = {}
    local wanted = nil
    if indices then
        wanted = {}
        for _, index in ipairs(LineOps.normalizeIndices(subs, indices, function(line)
            return type(line) == "table" and line.class == "dialogue"
        end)) do
            wanted[index] = true
        end
    end
    for i = 1, #subs do
        checkCancelled()
        local line = subs[i]
        if line.class == "style" then
            local name = line.name or line.style
            if name and not opts.styles[name] then opts.styles[name] = line end
        elseif line.class == "info" then
            if line.key == "PlayResX" and opts.res_x == nil then opts.res_x = tonumber(line.value) end
            if line.key == "PlayResY" and opts.res_y == nil then opts.res_y = tonumber(line.value) end
        elseif line.class == "dialogue" and (not wanted or wanted[i]) then
            selected[#selected + 1] = line
        end
    end
    return Reconstructor.recover(selected, opts)
end

Reconstructor.visibleText = visibleText
Reconstructor.parseTime = parseTime
Reconstructor.formatTime = formatTime
Reconstructor.Defaults = shallowCopy(defaults)

Reconstructor.parse_ass_event = Reconstructor.parseAssEvent
Reconstructor.format_event = Reconstructor.formatEvent
Reconstructor.recover_ass_text = Reconstructor.recoverAssText
Reconstructor.recover_subs = Reconstructor.recoverSubs
Reconstructor.visible_text = visibleText
Reconstructor.parse_time = parseTime
Reconstructor.format_time = formatTime
Reconstructor.DEFAULTS = shallowCopy(defaults)

local function showMessage(message)
    return require("kite.UI").message(message,{title="Macaria Revert",button="OK"})
end
local function subtitleLine(line)
    return {
        class = "dialogue",
        comment = true,
        layer = tonumber(line.layer) or 0,
        start_time = tonumber(line.start_time) or 0,
        end_time = tonumber(line.end_time) or 0,
        style = tostring(line.style or "Default"),
        actor = tostring(line.actor or ""),
        margin_l = tonumber(line.margin_l) or 0,
        margin_r = tonumber(line.margin_r) or 0,
        margin_t = tonumber(line.margin_t or line.margin_v) or 0,
        effect = tostring(line.effect or "karaoke"),
        text = tostring(line.text or ""),
    }
end

local function countReason(report, needle)
    local count = 0
    for _, item in ipairs(report and report.skipped_events or {}) do
        if tostring(item.reason or ""):find(needle, 1, true) then count = count + 1 end
    end
    return count
end

local function reportSummary(report, recovered)
    return string.format(
        "Recovered lines: %d\nSelected events: %d\nAnalyzable events: %d\nSkipped drawings: %d\nRows without a valid chain: %d",
        recovered,
        tonumber(report and report.input_events) or 0,
        tonumber(report and report.observations) or 0,
        countReason(report, "ASS drawing"),
        #(report and report.skipped_rows or {}))
end

local function insertRecovered(subs, sel, lines, report)
    local selected = LineOps.normalizeIndices(subs, sel, function(line) return line.class == "dialogue" end)
    local insertAt = selected[#selected] + 1

    local prepared = {}
    for _, line in ipairs(lines) do prepared[#prepared + 1] = subtitleLine(line) end
    local newSelection
    LineOps.transaction(subs, "Macaria Revert", function()
        checkCancelled()
        newSelection = LineOps.insertLines(subs, {
            { index = insertAt, lines = prepared },
        })
    end)
    if type(aegisub.log) == "function" then
        aegisub.log(0, "%s\n", reportSummary(report, #prepared))
    end
    return newSelection, newSelection[1]
end

local function reconstructSelected(subs, sel, options)
    if type(sel) ~= "table" or #sel == 0 then
        showMessage("Select the generated lines to reconstruct.")
        return sel
    end

    local ok, lines, report = pcall(Reconstructor.recoverSubs, subs, sel, options)
    checkCancelled()
    if not ok then
        showMessage("Reconstruction failed without changing the subtitle:\n" .. tostring(lines))
        return sel
    end
    if #lines == 0 then
        showMessage("No recoverable lines were found.\n\n" .. reportSummary(report, 0))
        return sel
    end

    return insertRecovered(subs, sel, lines, report)
end

local function canRun(subs, sel)
    return #LineOps.normalizeIndices(subs, sel, function(line)
        return type(line) == "table" and line.class == "dialogue"
    end) > 0
end

function Reconstructor.run(subs, selection)
    local UI = require("kite.UI")
    local store = require("kite.UI").Settings.open("kite.MacariaRevert", "1.0.0", {main=defaults})
    local state = mergedOptions(store:values("main"))
    state.res_x, state.res_y = nil, nil
    local report = "Select generated events. Preview lists the proposed bases. Reconstruct inserts them as comments after the selection."
    while true do
        local controls = {
            {class="label",label="Position tolerance (ASS units)",x=0,y=0,width=24,height=1},
            {class="floatedit",name="position_tolerance",value=state.position_tolerance,min=0,x=24,y=0,width=16,height=1},
            {class="label",label="Row tolerance (ASS units)",x=0,y=1,width=24,height=1},
            {class="floatedit",name="row_tolerance",value=state.row_tolerance,min=0,x=24,y=1,width=16,height=1},
            {class="label",label="Time tolerance (ms)",x=0,y=2,width=24,height=1},
            {class="floatedit",name="time_tolerance_ms",value=state.time_tolerance_ms,min=0,x=24,y=2,width=16,height=1},
            {class="checkbox",name="infer_spaces",label="Infer word spacing",value=state.infer_spaces,x=0,y=4,width=20,height=1},
            {class="checkbox",name="emit_alignment",label="Include alignment tags",value=state.emit_alignment,x=20,y=4,width=20,height=1},
            {class="textbox",name="report",text=report,x=0,y=6,width=40,height=10},
        }
        local button, result = UI.workflow("Macaria Revert", "Recover base karaoke lines", controls,
            {"Reconstruct", "Preview", "Cancel"}, {ok="Reconstruct", close="Cancel"})
        if button ~= "Preview" and button ~= "Reconstruct" then return selection end
        local invalid
        for _, key in ipairs({"position_tolerance", "row_tolerance", "time_tolerance_ms"}) do
            local value = finiteNumber(result[key])
            if not value or value < 0 then invalid = "Tolerances must be finite, non-negative numbers."
            else state[key] = value end
        end
        for _, key in ipairs({"infer_spaces", "emit_alignment"}) do
            if type(result[key]) == "boolean" then state[key] = result[key] end
        end
        if invalid then report = invalid
        else
            local ok, lines, details = pcall(Reconstructor.recoverSubs, subs, selection, state)
            checkCancelled()
            if not ok then report = "Reconstruction failed without changing the subtitle:\n" .. tostring(lines)
            else
                local parts = {reportSummary(details, #lines)}
                for _, line in ipairs(lines) do
                    checkCancelled()
                    parts[#parts + 1] = Reconstructor.formatEvent(line)
                end
                report = table.concat(parts, "\n\n")
                if #lines == 0 then report = "No recoverable lines were found.\n\n" .. report
                elseif button == "Reconstruct" then
                    local saved, written, err = pcall(function()
                        store:update("main", state)
                        return store:write()
                    end)
                    if saved and written then return insertRecovered(subs, selection, lines, details) end
                    report = "Preferences could not be saved. No lines were inserted.\n" .. tostring(saved and err or written)
                end
            end
        end
    end
end
Reconstructor.runDirect = reconstructSelected
Reconstructor.canRun = canRun
Reconstructor.reportSummary = reportSummary

return Reconstructor
end)()

Timing.Locale = (function()
local M = {}
function M.new(getLanguage)
local LANG = {
    en = {
        title_suite      = "═══ CHRONO SUITE ═══════════════════",
        title_markers    = "═══ AUDIT MARKERS ════════════════════",
        title_utilities  = "═══ UTILITY TOOLS ════════════════",
        title_data_import  = "─── DATA IMPORT ─────────",
        title_tools      = "─── Extra Tools ─",
        lbl_apply_to     = "Apply to:",            lbl_filter      = "Filter:",
        lbl_preset       = "Preset:",              lbl_kf_mode     = "KF Mode:", lbl_kf_dir = "KF Dir:",
        lbl_short_ms     = "Short (ms):",          lbl_long_ms     = "Long (ms):",
        lbl_twin_ms      = "Twin KF (ms):",        lbl_miss_ms     = "Miss KF (ms):",
        lbl_overtime     = "Overtime (ms):",       lbl_min_cps     = "Min CPS:",
        lbl_max_cps      = "Max CPS:",             lbl_gap_ms      = "Short gap (ms):",
        lbl_max_width    = "Max Width (px):",      lbl_marker_dd   = "Single Marker:",
        lbl_section_case  = "CASE:",
        lbl_section_punct = "PUNCT/TEXT:",
        lbl_section_tags  = "TAGS/COMM:",
        lbl_section_smart = "SMART:",
        lbl_section_split = "SPLIT/JOIN:",
        lbl_section_time  = "TIME/SORT:",
        lbl_section_kara  = "KARAOKE:",
        lbl_data_import_mode = "Import Mode:",
        lbl_suite_tool    = "Extra Tool:",
        lbl_selection     = "Selection: %d lines",
        chk_clear_old     = "Clear previous markers",
        chk_gap_continuous= "Mark continuous (0ms)",
        chk_gap_ignore_kf = "Ignore gap on KF",
        chk_kf_seal       = "Keyframe seal",
        chk_data_import_cmt = "Text as {...}",
        chk_data_import_same_layers = "Same Layers",
        chk_data_import_skip= "(empty box → skip Data Import)",
        btn_execute       = "EXECUTE",
        btn_autotiming    = "Auto Timing",
        btn_browse        = "Browse...",
        btn_extract_kf    = "Extract KF",
        btn_cancel        = "Cancel",
        btn_ok            = "OK",
        btn_save          = "Save",
        btn_process       = "Execute",
        err_no_selection  = "No selection.",
        err_filter_zero   = "Filter resulted in 0 lines.",
        err_no_video      = "No video loaded.",
        err_invalid_twin  = "Twin KF must be a number ≥ 0",
        err_invalid_miss  = "Miss KF must be a number ≥ 0",
        err_invalid_ov    = "Overtime must be a number ≥ 0",
        msg_audit_done    = "Audit completed.\n\nLines audited: %d\nLines flagged: %d\n\nIssues:\n%s",
        msg_avg_cps       = "Average CPS (%d lines): %.2f",
        lbl_section_cps_gap          = "── CPS / Gap ──",
        lbl_section_filters_header   = "──── AUDIT TAG & STRUCTURE FILTERS ──────────────────────────",
        lbl_section_text_markers_hdr = "──── AUDIT TEXT MARKERS ─────────────────────────────────────",
        lbl_dropdown_skip_hint       = "(empty dropdown = skip section)",
        chk_has_n        = "\\N break [LINE-BREAK]",
        chk_has_pos      = "\\pos/\\move [POSITION-TAG]",
        chk_has_clip     = "\\clip [CLIP-TAG]",
        chk_has_fad      = "\\fad [FADE-TAG]",
        chk_has_t        = "\\t transform [TRANSFORM-TAG]",
        chk_has_k        = "\\k karaoke [KARAOKE-TAG]",
        chk_has_comment  = "Comment {} [COMMENT-BLOCK]",
        chk_has_num      = "Digits [HAS-DIGITS]",
        chk_full_italic  = "Italic line [FULL-ITALIC]",
        chk_has_cjk      = "CJK / kana [HAS-CJK]",
        chk_dbl_space    = "Double space [DOUBLE-SPACE]",
        chk_edge_space   = "Edge space [EDGE-SPACE]",
        chk_uppercase      = "Uppercase [UPPERCASE]",
        chk_3liner         = "3-Liner [THREE-LINES]",
        chk_missing_punct  = "No end punctuation [NO-END-PUNCT]",
        chk_punct_balance  = "Unpaired punctuation [UNPAIRED-PUNCT]",
        chk_orphan_word    = "Short last line [SHORT-LAST-LINE]",
        chk_orphan_tag     = "Broken tag [BROKEN-TAG]",
        chk_overlap        = "Overlap [OVERLAP]",
        chk_unstyled       = "Unstyled [DEFAULT-STYLE]",
        chk_double_italics = "Dbl Italics [ITALIC-ERROR]",
        chk_parentheses    = "Parentheses [PARENTHESES]",
        chk_name_prefix    = "Name Prefix [NAME-PREFIX]",
        chk_sentences      = "Sentences [MULTI-SENTENCE]",

        lazyt_lbl_mode     = "Mode:",
        lazyt_lbl_json     = "Waveform JSON:",
        lazyt_chk_reload   = "Reload waveform cache",
        lazyt_lbl_outer    = "Search ± (ms):",
        lazyt_sec_detect   = "── Voice detection (waveform peaks) ──",
        lazyt_lbl_smooth   = "Smoothing (ms):",
        lazyt_chk_otsu     = "Auto threshold (Otsu)",
        lazyt_lbl_bridge   = "Bridge gaps ≤ (ms):",
        lazyt_lbl_island   = "Drop islands < (ms):",
        lazyt_chk_spill    = "Trim small edge spill",
        lazyt_sec_margins  = "── Margins · post-timing ──",
        lazyt_lbl_leads    = "Lead-in / out (ms):",
        lazyt_lbl_kfrange  = "KF snap end / start (ms):",
        lazyt_lbl_chain    = "Chain max out / in (ms):",
        lazyt_lbl_cut      = "Voice-cut limit (ms):",
        lazyt_lbl_cps      = "CPS flag above:",
        lazyt_lbl_floor    = "Duration floor (ms):",
        lazyt_chk_signs    = "Skip sign/karaoke/fx styles",
        lazyt_chk_stats    = "Show statistics",
        lazyt_lbl_style    = "Style filter:",
        lazyt_sum          = "Timed: %d/%d spoken | KF snaps: %d | Joins: %d | Flagged: %d",
        lazyt_no_voice     = "No voice found in the waveform.",
        lazyt_hint         = "Full/Post need keyframes. Raw only follows detected voice. Markers land in Effect as [TM-...].",
        lazyt_open_title   = "Select the waveform JSON (peaks)",
        lazyt_json_filter  = "JSON (*.json)|*.json|All files (*.*)|*.*",
        lazyt_err_parse    = "Could not read the waveform JSON:\n%s",
        lazyt_err_no_wave  = "This mode needs a waveform JSON (peaks). Pick one to continue.",
        at_title           = "Auto Timing — %s",
        at_lbl_detector    = "Method:",
        at_msg_done        = "Auto Timing · %s\n%s",
        at_hint            = "Lazy = JSON. Busy = Kite Timing files (+ JSON).",
        at_hint_mode       = "Full=method+KFs. Raw=method only. Post=current+KFs. Legacy=no KFs.",
        at_lbl_data        = "Busy files:",
        at_busy_hint       = "Busy uses signal files from Kite Timing. Waveform JSON can be added in the main window.",
        at_chk_discover    = "Find signal files next to the subtitle",
        at_chk_discover_legacy = "Find silence files next to the subtitle",
        at_lbl_sil         = "Silences 30/40/50:",
        at_lbl_vad         = "VAD intervals:",
        at_lbl_flux        = "Flux events:",
        at_lbl_env         = "RMS/dB envelope:",
        at_sec_legacy      = "── Legacy ──",
        at_legacy_hint     = "Legacy uses silence files and does not use video keyframes.",
        at_lbl_method      = "Method:",
        at_lbl_limit       = "Limit (ms):",
        at_chk_silonly     = "Silences only (ignore method)",
        at_data_title      = "Pick Busy files (matched by name)",
        at_legacy_data_title = "Pick Legacy silence files",
        at_err_module      = "Busy and Legacy need the Kite Timing module. Install or update it with DependencyControl.",
        at_err_busy_input  = "Busy needs a waveform JSON or at least one Busy file.",
        at_err_sil         = "Legacy needs at least one silence file.",
        at_legacy_done     = "Legacy: %d lines modified.",
        btn_data           = "Busy Files...",
        btn_legacy         = "Legacy...",
        btn_run_legacy     = "Execute",
        msg_config_saved   = "Config saved.",

        data_import_paste_hint = "Paste 'Dialogue:' lines (or use one of the modes).",
    },
    es = {
        title_suite      = "═══ CHRONO SUITE ═══════════════════",
        title_markers    = "═══ MARCADORES AUDITORIA ═════════════════",
        title_utilities  = "═══ UTILIDADES ═══════════════",
        title_data_import  = "─── IMPORTAR DATOS ──────",
        title_tools      = "─── Herramientas Extra ",
        lbl_apply_to     = "Aplicar a:",           lbl_filter      = "Filtro:",
        lbl_preset       = "Preset:",              lbl_kf_mode     = "Modo KF:", lbl_kf_dir = "Dir KF:",
        lbl_short_ms     = "Corto (ms):",          lbl_long_ms     = "Largo (ms):",
        lbl_twin_ms      = "Twin KF (ms):",        lbl_miss_ms     = "Miss KF (ms):",
        lbl_overtime     = "Sobretiempo (ms):",    lbl_min_cps     = "Min CPS:",
        lbl_max_cps      = "Max CPS:",             lbl_gap_ms      = "Gap corto (ms):",
        lbl_max_width    = "Ancho máx (px):",      lbl_marker_dd   = "Marcador único:",
        lbl_section_case  = "CAJA:",
        lbl_section_punct = "PUNT/TEXTO:",
        lbl_section_tags  = "TAGS/COMENT:",
        lbl_section_smart = "INTELIG:",
        lbl_section_split = "DIVIDIR/UNIR:",
        lbl_section_time  = "TIEMPO/ORDEN:",
        lbl_section_kara  = "KARAOKE:",
        lbl_data_import_mode = "Modo Importación:",
        lbl_suite_tool    = "Herramienta:",
        lbl_selection     = "Selección: %d líneas",
        chk_clear_old     = "Limpiar marcadores previos",
        chk_gap_continuous= "Marcar continuas (0ms)",
        chk_gap_ignore_kf = "Ignorar gap en KF",
        chk_kf_seal       = "Sello de keyframe",
        chk_data_import_cmt = "Texto en {...}",
        chk_data_import_same_layers = "Same Layers",
        chk_data_import_skip= "(caja vacía → omitir Importar Datos)",
        btn_execute       = "EJECUTAR",
        btn_autotiming    = "Auto Timing",
        btn_browse        = "Buscar...",
        btn_extract_kf    = "Extraer KF",
        btn_cancel        = "Cancel",
        btn_ok            = "OK",
        btn_save          = "Guardar",
        btn_process       = "Execute",
        err_no_selection  = "Sin selección.",
        err_filter_zero   = "El filtro resultó en 0 líneas.",
        err_no_video      = "No hay vídeo cargado.",
        err_invalid_twin  = "Twin KF debe ser un número ≥ 0",
        err_invalid_miss  = "Miss KF debe ser un número ≥ 0",
        err_invalid_ov    = "Sobretiempo debe ser un número ≥ 0",
        msg_audit_done    = "Auditoría completada.\n\nLíneas auditadas: %d\nLíneas marcadas: %d\n\nProblemas:\n%s",
        msg_avg_cps       = "CPS promedio (%d líneas): %.2f",
        lbl_section_cps_gap          = "── CPS / Gap ──",
        lbl_section_filters_header   = "──── FILTROS DE TAGS Y ESTRUCTURA (AUDIT) ────────────────────",
        lbl_section_text_markers_hdr = "──── MARCADORES DE TEXTO (AUDIT) ────────────────────────────",
        lbl_dropdown_skip_hint       = "(dropdown vacío = saltar sección)",
        chk_has_n        = "Salto \\N [LINE-BREAK]",
        chk_has_pos      = "\\pos/\\move [POSITION-TAG]",
        chk_has_clip     = "\\clip [CLIP-TAG]",
        chk_has_fad      = "\\fad [FADE-TAG]",
        chk_has_t        = "\\t transform [TRANSFORM-TAG]",
        chk_has_k        = "\\k karaoke [KARAOKE-TAG]",
        chk_has_comment  = "Comentario {} [COMMENT-BLOCK]",
        chk_has_num      = "Dígitos [HAS-DIGITS]",
        chk_full_italic  = "Línea cursiva [FULL-ITALIC]",
        chk_has_cjk      = "CJK / kana [HAS-CJK]",
        chk_dbl_space    = "Espacio doble [DOUBLE-SPACE]",
        chk_edge_space   = "Espacio bordes [EDGE-SPACE]",
        chk_uppercase      = "Mayúsculas [UPPERCASE]",
        chk_3liner         = "3 Líneas [THREE-LINES]",
        chk_missing_punct  = "Sin puntuación final [NO-END-PUNCT]",
        chk_punct_balance  = "Puntuación sin pareja [UNPAIRED-PUNCT]",
        chk_orphan_word    = "Última línea corta [SHORT-LAST-LINE]",
        chk_orphan_tag     = "Tag roto [BROKEN-TAG]",
        chk_overlap        = "Solapamiento [OVERLAP]",
        chk_unstyled       = "Sin estilo [DEFAULT-STYLE]",
        chk_double_italics = "Dbl Cursiva [ITALIC-ERROR]",
        chk_parentheses    = "Paréntesis [PARENTHESES]",
        chk_name_prefix    = "Nombre [NAME-PREFIX]",
        chk_sentences      = "Oraciones [MULTI-SENTENCE]",
        lazyt_lbl_mode     = "Modo:",
        lazyt_lbl_json     = "JSON de onda:",
        lazyt_chk_reload   = "Recargar caché de onda",
        lazyt_lbl_outer    = "Buscar ± (ms):",
        lazyt_sec_detect   = "── Detección de voz (picos de onda) ──",
        lazyt_lbl_smooth   = "Suavizado (ms):",
        lazyt_chk_otsu     = "Umbral automático (Otsu)",
        lazyt_lbl_bridge   = "Unir huecos ≤ (ms):",
        lazyt_lbl_island   = "Quitar islas < (ms):",
        lazyt_chk_spill    = "Recortar derrames de borde",
        lazyt_sec_margins  = "── Márgenes · post-timing ──",
        lazyt_lbl_leads    = "Lead-in / out (ms):",
        lazyt_lbl_kfrange  = "Snap KF fin / inicio (ms):",
        lazyt_lbl_chain    = "Cadena máx out / in (ms):",
        lazyt_lbl_cut      = "Corte de voz máx (ms):",
        lazyt_lbl_cps      = "Marcar CPS sobre:",
        lazyt_lbl_floor    = "Duración mínima (ms):",
        lazyt_chk_signs    = "Omitir estilos sign/karaoke/fx",
        lazyt_chk_stats    = "Mostrar estadísticas",
        lazyt_lbl_style    = "Filtro de estilo:",
        lazyt_sum          = "Cronometradas: %d/%d habladas | Snaps KF: %d | Uniones: %d | Marcadas: %d",
        lazyt_no_voice     = "No se encontró voz en la onda.",
        lazyt_hint         = "Completo/Post necesitan keyframes. Bruto solo sigue la voz detectada. Las marcas van al Effect como [TM-...].",
        lazyt_open_title   = "Elige el JSON de onda (picos)",
        lazyt_json_filter  = "JSON (*.json)|*.json|Todos los archivos (*.*)|*.*",
        lazyt_err_parse    = "No pude leer el JSON de onda:\n%s",
        lazyt_err_no_wave  = "Este modo necesita un JSON de onda (picos). Elige uno para continuar.",
        at_title           = "Auto Timing — %s",
        at_lbl_detector    = "Método:",
        at_msg_done        = "Auto Timing · %s\n%s",
        at_hint            = "Lazy = JSON. Busy = archivos Kite Timing (+ JSON).",
        at_hint_mode       = "Completo=método+KFs. Bruto=solo método. Post=actual+KFs. Legacy=sin KFs.",
        at_lbl_data        = "Archivos Busy:",
        at_busy_hint       = "Busy usa archivos de señales de Kite Timing. El JSON de onda se suma desde la ventana principal.",
        at_chk_discover    = "Buscar archivos Busy junto al subtítulo",
        at_chk_discover_legacy = "Buscar silencios junto al subtítulo",
        at_lbl_sil         = "Silencios 30/40/50:",
        at_lbl_vad         = "Intervalos VAD:",
        at_lbl_flux        = "Eventos flux:",
        at_lbl_env         = "Envelope RMS/dB:",
        at_sec_legacy      = "── Legacy ──",
        at_legacy_hint     = "Legacy usa archivos de silencios y no usa keyframes del video.",
        at_lbl_method      = "Método:",
        at_lbl_limit       = "Límite (ms):",
        at_chk_silonly     = "Solo silencios (ignora el método)",
        at_data_title      = "Elige archivos Busy (por nombre)",
        at_legacy_data_title = "Elige silencios para Legacy",
        at_err_module      = "Busy y Legacy necesitan el módulo Kite Timing. Instálalo o actualízalo con DependencyControl.",
        at_err_busy_input  = "Busy necesita un JSON de onda o al menos un archivo Busy.",
        at_err_sil         = "Legacy necesita al menos un archivo de silencios.",
        at_legacy_done     = "Legacy: %d líneas modificadas.",
        btn_data           = "Archivos Busy...",
        btn_legacy         = "Legacy...",
        btn_run_legacy     = "Execute",
        msg_config_saved   = "Configuración guardada.",
        data_import_paste_hint = "Pega líneas 'Dialogue:' (o usa uno de los modos).",
    },
    pt = {
        title_suite      = "═══ CHRONO SUITE ═══════════════════",
        title_markers    = "═══ MARCADORES AUDITORIA ═════════════════",
        title_utilities  = "═══ UTILIDADES ═══════════════",
        title_data_import  = "─── IMPORTAR DADOS ──────",
        title_tools      = "─── Ferramentas Extra",
        lbl_apply_to     = "Aplicar em:",          lbl_filter      = "Filtro:",
        lbl_preset       = "Preset:",              lbl_kf_mode     = "Modo KF:", lbl_kf_dir = "Dir KF:",
        lbl_short_ms     = "Curto (ms):",          lbl_long_ms     = "Longo (ms):",
        lbl_twin_ms      = "Twin KF (ms):",        lbl_miss_ms     = "Miss KF (ms):",
        lbl_overtime     = "Sobretempo (ms):",     lbl_min_cps     = "Min CPS:",
        lbl_max_cps      = "Max CPS:",             lbl_gap_ms      = "Gap curto (ms):",
        lbl_max_width    = "Largura máx (px):",    lbl_marker_dd   = "Marcador único:",
        lbl_section_case  = "CAIXA:",
        lbl_section_punct = "PONT/TEXTO:",
        lbl_section_tags  = "TAGS/COMENT:",
        lbl_section_smart = "INTELIG:",
        lbl_section_split = "DIVIDIR/UNIR:",
        lbl_section_time  = "TEMPO/ORDEM:",
        lbl_section_kara  = "KARAOKE:",
        lbl_data_import_mode = "Modo Importação:",
        lbl_suite_tool    = "Ferramenta:",
        lbl_selection     = "Seleção: %d linhas",
        chk_clear_old     = "Limpar marcadores prévios",
        chk_gap_continuous= "Marcar contínuas (0ms)",
        chk_gap_ignore_kf = "Ignorar gap em KF",
        chk_kf_seal       = "Selo de keyframe",
        chk_data_import_cmt = "Texto em {...}",
        chk_data_import_same_layers = "Same Layers",
        chk_data_import_skip= "(caixa vazia → ignorar Importar Dados)",
        btn_execute       = "EXECUTAR",
        btn_autotiming    = "Auto Timing",
        btn_browse        = "Procurar...",
        btn_extract_kf    = "Extrair KF",
        btn_cancel        = "Cancel",
        btn_ok            = "OK",
        btn_save          = "Salvar",
        btn_process       = "Execute",
        err_no_selection  = "Sem seleção.",
        err_filter_zero   = "O filtro resultou em 0 linhas.",
        err_no_video      = "Nenhum vídeo carregado.",
        err_invalid_twin  = "Twin KF deve ser um número ≥ 0",
        err_invalid_miss  = "Miss KF deve ser um número ≥ 0",
        err_invalid_ov    = "Sobretempo deve ser um número ≥ 0",
        msg_audit_done    = "Auditoria concluída.\n\nLinhas auditadas: %d\nLinhas marcadas: %d\n\nProblemas:\n%s",
        msg_avg_cps       = "CPS médio (%d linhas): %.2f",
        lbl_section_cps_gap          = "── CPS / Gap ──",
        lbl_section_filters_header   = "──── FILTROS DE TAGS E ESTRUTURA (AUDIT) ─────────────────────",
        lbl_section_text_markers_hdr = "──── MARCADORES DE TEXTO (AUDIT) ─────────────────────────────",
        lbl_dropdown_skip_hint       = "(dropdown vazio = saltar seção)",
        chk_has_n        = "Quebra \\N [LINE-BREAK]",
        chk_has_pos      = "\\pos/\\move [POSITION-TAG]",
        chk_has_clip     = "\\clip [CLIP-TAG]",
        chk_has_fad      = "\\fad [FADE-TAG]",
        chk_has_t        = "\\t transform [TRANSFORM-TAG]",
        chk_has_k        = "\\k karaoke [KARAOKE-TAG]",
        chk_has_comment  = "Comentário {} [COMMENT-BLOCK]",
        chk_has_num      = "Dígitos [HAS-DIGITS]",
        chk_full_italic  = "Linha itálica [FULL-ITALIC]",
        chk_has_cjk      = "CJK / kana [HAS-CJK]",
        chk_dbl_space    = "Espaço duplo [DOUBLE-SPACE]",
        chk_edge_space   = "Espaço bordas [EDGE-SPACE]",
        chk_uppercase      = "Maiúsculas [UPPERCASE]",
        chk_3liner         = "3 Linhas [THREE-LINES]",
        chk_missing_punct  = "Sem pontuação final [NO-END-PUNCT]",
        chk_punct_balance  = "Pontuação sem par [UNPAIRED-PUNCT]",
        chk_orphan_word    = "Última linha curta [SHORT-LAST-LINE]",
        chk_orphan_tag     = "Tag quebrada [BROKEN-TAG]",
        chk_overlap        = "Sobreposição [OVERLAP]",
        chk_unstyled       = "Sem estilo [DEFAULT-STYLE]",
        chk_double_italics = "Dbl Itálico [ITALIC-ERROR]",
        chk_parentheses    = "Parênteses [PARENTHESES]",
        chk_name_prefix    = "Nome [NAME-PREFIX]",
        chk_sentences      = "Frases [MULTI-SENTENCE]",
        lazyt_lbl_mode     = "Modo:",
        lazyt_lbl_json     = "JSON da onda:",
        lazyt_chk_reload   = "Recarregar cache da onda",
        lazyt_lbl_outer    = "Buscar ± (ms):",
        lazyt_sec_detect   = "── Detecção de voz (picos da onda) ──",
        lazyt_lbl_smooth   = "Suavização (ms):",
        lazyt_chk_otsu     = "Limiar automático (Otsu)",
        lazyt_lbl_bridge   = "Unir lacunas ≤ (ms):",
        lazyt_lbl_island   = "Remover ilhas < (ms):",
        lazyt_chk_spill    = "Aparar derrames de borda",
        lazyt_sec_margins  = "── Margens · pós-timing ──",
        lazyt_lbl_leads    = "Lead-in / out (ms):",
        lazyt_lbl_kfrange  = "Snap KF fim / início (ms):",
        lazyt_lbl_chain    = "Cadeia máx out / in (ms):",
        lazyt_lbl_cut      = "Corte de voz máx (ms):",
        lazyt_lbl_cps      = "Marcar CPS acima de:",
        lazyt_lbl_floor    = "Duração mínima (ms):",
        lazyt_chk_signs    = "Pular estilos sign/karaokê/fx",
        lazyt_chk_stats    = "Mostrar estatísticas",
        lazyt_lbl_style    = "Filtro de estilo:",
        lazyt_sum          = "Cronometradas: %d/%d faladas | Snaps KF: %d | Uniões: %d | Marcadas: %d",
        lazyt_no_voice     = "Nenhuma voz encontrada na onda.",
        lazyt_hint         = "Completo/Pós precisam de keyframes. Bruto só segue a voz detectada. As marcas vão ao Effect como [TM-...].",
        lazyt_open_title   = "Escolha o JSON da onda (picos)",
        lazyt_json_filter  = "JSON (*.json)|*.json|Todos os arquivos (*.*)|*.*",
        lazyt_err_parse    = "Não consegui ler o JSON da onda:\n%s",
        lazyt_err_no_wave  = "Este modo precisa de um JSON da onda (picos). Escolha um para continuar.",
        at_title           = "Auto Timing — %s",
        at_lbl_detector    = "Método:",
        at_msg_done        = "Auto Timing · %s\n%s",
        at_hint            = "Lazy = JSON. Busy = arquivos Kite Timing (+ JSON).",
        at_hint_mode       = "Completo=método+KFs. Bruto=só método. Pós=atual+KFs. Legacy=sem KFs.",
        at_lbl_data        = "Arquivos Busy:",
        at_busy_hint       = "Busy usa arquivos de sinais do Kite Timing. O JSON da onda pode ser somado na janela principal.",
        at_chk_discover    = "Buscar arquivos Busy junto da legenda",
        at_chk_discover_legacy = "Buscar silêncios junto da legenda",
        at_lbl_sil         = "Silêncios 30/40/50:",
        at_lbl_vad         = "Intervalos VAD:",
        at_lbl_flux        = "Eventos flux:",
        at_lbl_env         = "Envelope RMS/dB:",
        at_sec_legacy      = "── Legacy ──",
        at_legacy_hint     = "Legacy usa arquivos de silêncios e não usa keyframes do vídeo.",
        at_lbl_method      = "Método:",
        at_lbl_limit       = "Limite (ms):",
        at_chk_silonly     = "Só silêncios (ignora o método)",
        at_data_title      = "Escolha arquivos Busy (por nome)",
        at_legacy_data_title = "Escolha silêncios para Legacy",
        at_err_module      = "Busy e Legacy precisam do módulo Kite Timing. Instale ou atualize com DependencyControl.",
        at_err_busy_input  = "Busy precisa de um JSON da onda ou ao menos um arquivo Busy.",
        at_err_sil         = "Legacy precisa de ao menos um arquivo de silêncios.",
        at_legacy_done     = "Legacy: %d linhas modificadas.",
        btn_data           = "Arquivos Busy...",
        btn_legacy         = "Legacy...",
        btn_run_legacy     = "Execute",
        msg_config_saved   = "Configuração salva.",
        data_import_paste_hint = "Cole linhas 'Dialogue:' (ou use um dos modos).",
    },
}

local extraLang = {
    en = {
        btn_config="Config", btn_help="Help", help_btn_close="Cancel",
        cfg_title="Chrono Suite Config", cfg_lbl_language="Language:",
        cfg_lbl_scxvid="SCXvid", cfg_lbl_scxvid_path="SCXvid path:", cfg_lbl_ffmpeg_path="FFmpeg path:", cfg_lbl_log_suffix="Log suffix:",
        cfg_lbl_leadutil="Lead-In / Lead-Out / Chain", cfg_lbl_lead_step="Step (ms):", cfg_lbl_chain_cap="Chain max (ms):",
        cfg_lbl_kite="Kite Timing", cfg_lbl_lead_in_base="Lead-in base:", cfg_lbl_lead_in_max="Lead-in max:", cfg_lbl_lead_out_base="Lead-out base:", cfg_lbl_lead_out_max="Lead-out max:", cfg_lbl_lead_out_chain="Chain out:", cfg_lbl_chain_gap_max="Chain gap:",
        cfg_lbl_bidir="Bidirectional Snapping", cfg_lbl_bidir_snap="Snap range (frames):", cfg_lbl_snap_protect="Directional range (ms):",
        cfg_lbl_presets="Audit Presets", cfg_lbl_preset_start="Start T/M:", cfg_lbl_preset_end="End T/M:", cfg_lbl_preset_full_kf="Full T/M:", cfg_lbl_preset_full_time="Full S/L:", cfg_lbl_preset_full_read="Full CPS/W:", cfg_lbl_preset_full_gap="Full Gap S/L:", cfg_lbl_preset_duration="Duration S/L:", cfg_lbl_preset_cps="CPS Max:", cfg_lbl_preset_gaps="Gaps S/L:", cfg_lbl_preset_overtime="Overtime:",
        cfg_msg_saved="Config saved.", cfg_msg_lang_changed="Language changed. Reopen the dialog.",
        msg_bidir_done="Bidirectional snapping done.\n\nLines modified: %d\nStarts snapped: %d\nEnds snapped: %d\nRange: ±%d frames",
        err_no_keyframes="No keyframes loaded.",
        title_markers="=== AUDIT MARKERS ===", title_utilities="=== UTILITY TOOLS ===", title_data_import="--- DATA IMPORT ---", title_tools="--- EXTRA TOOLS ---",
        lbl_section_case="CASE:", lbl_section_punct="PUNCT/TEXT:", lbl_section_tags="TAGS/COMMENTS:", lbl_section_smart="SMART:", lbl_section_split="SPLIT/JOIN:", lbl_section_time="TIME/SORT:", lbl_suite_tool="Extra Tool:", lbl_large_gap="Large gap (ms):",
        chk_kf_seal="Keyframe seal", chk_data_import_skip="(empty box = skip Data Import)",
        chk_has_n="Line break [LINE-BREAK]", chk_has_pos="Position tag [POSITION-TAG]", chk_has_clip="Clip tag [CLIP-TAG]", chk_has_fad="Fade tag [FADE-TAG]", chk_has_t="Transform tag [TRANSFORM-TAG]", chk_has_k="Karaoke tag [KARAOKE-TAG]", chk_has_comment="Comment block [COMMENT-BLOCK]", chk_has_num="Digits [HAS-DIGITS]", chk_full_italic="Full italic [FULL-ITALIC]", chk_dbl_space="Double space [DOUBLE-SPACE]", chk_edge_space="Edge space [EDGE-SPACE]",
        chk_3liner="Three lines [THREE-LINES]", chk_missing_punct="No end punctuation [NO-END-PUNCT]", chk_punct_balance="Unpaired punctuation [UNPAIRED-PUNCT]", chk_orphan_word="Short last line [SHORT-LAST-LINE]", chk_orphan_tag="Broken tag [BROKEN-TAG]", chk_unstyled="Default style [DEFAULT-STYLE]", chk_double_italics="Italic error [ITALIC-ERROR]", chk_parentheses="Parentheses [PARENTHESES]", chk_name_prefix="Name prefix [NAME-PREFIX]", chk_sentences="Multiple sentences [MULTI-SENTENCE]",
    },
    es = {
        btn_config="Config", btn_help="Ayuda", help_btn_close="Cancel",
        cfg_title="Config de Chrono Suite", cfg_lbl_language="Idioma:",
        cfg_lbl_scxvid="SCXvid", cfg_lbl_scxvid_path="Ruta de SCXvid:", cfg_lbl_ffmpeg_path="Ruta de FFmpeg:", cfg_lbl_log_suffix="Sufijo del log:",
        cfg_lbl_leadutil="Lead-In / Lead-Out / Cadena", cfg_lbl_lead_step="Paso (ms):", cfg_lbl_chain_cap="Cadena máx (ms):",
        cfg_lbl_kite="Kite Timing", cfg_lbl_lead_in_base="Lead-in base:", cfg_lbl_lead_in_max="Lead-in máximo:", cfg_lbl_lead_out_base="Lead-out base:", cfg_lbl_lead_out_max="Lead-out máximo:", cfg_lbl_lead_out_chain="Salida en cadena:", cfg_lbl_chain_gap_max="Gap de cadena:",
        cfg_lbl_bidir="Bidirectional Snapping", cfg_lbl_bidir_snap="Rango de snap (frames):", cfg_lbl_snap_protect="Rango direccional (ms):",
        cfg_lbl_presets="Presets de auditoría", cfg_lbl_preset_start="Inicio T/M:", cfg_lbl_preset_end="Final T/M:", cfg_lbl_preset_full_kf="Completa T/M:", cfg_lbl_preset_full_time="Completa C/L:", cfg_lbl_preset_full_read="Completa CPS/An:", cfg_lbl_preset_full_gap="Completa Gap C/L:", cfg_lbl_preset_duration="Duración C/L:", cfg_lbl_preset_cps="CPS máx:", cfg_lbl_preset_gaps="Gaps C/L:", cfg_lbl_preset_overtime="Sobretiempo:",
        cfg_msg_saved="Configuración guardada.", cfg_msg_lang_changed="Idioma cambiado. Reabre el diálogo.",
        msg_bidir_done="Bidirectional Snapping finalizado.\n\nLíneas modificadas: %d\nInicios ajustados: %d\nFinales ajustados: %d\nRango: ±%d frames",
        err_no_keyframes="No hay keyframes cargados.",
        title_markers="=== MARCADORES DE AUDITORÍA ===", title_utilities="=== UTILIDADES ===", title_data_import="--- IMPORTAR DATOS ---", title_tools="--- HERRAMIENTAS EXTRA ---",
        lbl_apply_to="Aplicar a:", lbl_filter="Filtro:", lbl_marker_dd="Marcador único:", lbl_large_gap="Gap largo (ms):", lbl_section_case="CAJA:", lbl_section_punct="PUNT/TEXTO:", lbl_section_tags="TAGS/COMENTARIOS:", lbl_section_smart="SMART:", lbl_section_split="DIVIDIR/UNIR:", lbl_section_time="TIEMPO/ORDEN:", lbl_suite_tool="Herramienta:", lbl_selection="Selección: %d líneas",
        chk_clear_old="Limpiar marcadores previos", chk_gap_continuous="Marcar continuas (0 ms)", chk_gap_ignore_kf="Ignorar gap si cae en KF", chk_kf_seal="Sello de keyframe", chk_data_import_skip="(caja vacía = saltar Importar Datos)",
        chk_has_n="Salto de línea [LINE-BREAK]", chk_has_pos="Tag de posición [POSITION-TAG]", chk_has_clip="Tag de clip [CLIP-TAG]", chk_has_fad="Tag de fade [FADE-TAG]", chk_has_t="Tag de transformación [TRANSFORM-TAG]", chk_has_k="Tag de karaoke [KARAOKE-TAG]", chk_has_comment="Bloque de comentario [COMMENT-BLOCK]", chk_has_num="Dígitos [HAS-DIGITS]", chk_full_italic="Toda en cursiva [FULL-ITALIC]", chk_dbl_space="Doble espacio [DOUBLE-SPACE]", chk_edge_space="Espacio al borde [EDGE-SPACE]",
        chk_uppercase="Mayúsculas [UPPERCASE]", chk_3liner="Tres líneas [THREE-LINES]", chk_missing_punct="Sin puntuación final [NO-END-PUNCT]", chk_punct_balance="Puntuación sin pareja [UNPAIRED-PUNCT]", chk_orphan_word="Última línea corta [SHORT-LAST-LINE]", chk_orphan_tag="Tag roto [BROKEN-TAG]", chk_overlap="Solapamiento [OVERLAP]", chk_unstyled="Estilo Default [DEFAULT-STYLE]", chk_double_italics="Error de cursiva [ITALIC-ERROR]", chk_parentheses="Paréntesis [PARENTHESES]", chk_name_prefix="Prefijo de nombre [NAME-PREFIX]", chk_sentences="Varias oraciones [MULTI-SENTENCE]",
        msg_config_saved="Configuración guardada.", data_import_paste_hint="Pega líneas 'Dialogue:' o elige un modo de importación.",
    },
    pt = {
        btn_config="Config", btn_help="Ajuda", help_btn_close="Cancel",
        cfg_title="Config do Chrono Suite", cfg_lbl_language="Idioma:",
        cfg_lbl_scxvid="SCXvid", cfg_lbl_scxvid_path="Caminho do SCXvid:", cfg_lbl_ffmpeg_path="Caminho do FFmpeg:", cfg_lbl_log_suffix="Sufixo do log:",
        cfg_lbl_leadutil="Lead-In / Lead-Out / Cadeia", cfg_lbl_lead_step="Passo (ms):", cfg_lbl_chain_cap="Cadeia máx (ms):",
        cfg_lbl_kite="Kite Timing", cfg_lbl_lead_in_base="Lead-in base:", cfg_lbl_lead_in_max="Lead-in máximo:", cfg_lbl_lead_out_base="Lead-out base:", cfg_lbl_lead_out_max="Lead-out máximo:", cfg_lbl_lead_out_chain="Saída em cadeia:", cfg_lbl_chain_gap_max="Gap da cadeia:",
        cfg_lbl_bidir="Bidirectional Snapping", cfg_lbl_bidir_snap="Alcance de snap (frames):", cfg_lbl_snap_protect="Alcance direcional (ms):",
        cfg_lbl_presets="Presets de auditoria", cfg_lbl_preset_start="Início T/M:", cfg_lbl_preset_end="Fim T/M:", cfg_lbl_preset_full_kf="Completa T/M:", cfg_lbl_preset_full_time="Completa C/L:", cfg_lbl_preset_full_read="Completa CPS/Lg:", cfg_lbl_preset_full_gap="Completa Gap C/L:", cfg_lbl_preset_duration="Duração C/L:", cfg_lbl_preset_cps="CPS máx:", cfg_lbl_preset_gaps="Gaps C/L:", cfg_lbl_preset_overtime="Sobretempo:",
        cfg_msg_saved="Configuração salva.", cfg_msg_lang_changed="Idioma alterado. Reabra o diálogo.",
        msg_bidir_done="Bidirectional Snapping concluído.\n\nLinhas modificadas: %d\nInícios ajustados: %d\nFinais ajustados: %d\nAlcance: ±%d frames",
        err_no_keyframes="Nenhum keyframe carregado.",
        title_markers="=== MARCADORES DE AUDITORIA ===", title_utilities="=== UTILIDADES ===", title_data_import="--- IMPORTAR DADOS ---", title_tools="--- FERRAMENTAS EXTRA ---",
        lbl_apply_to="Aplicar em:", lbl_filter="Filtro:", lbl_marker_dd="Marcador único:", lbl_large_gap="Gap longo (ms):", lbl_section_case="CAIXA:", lbl_section_punct="PONT/TEXTO:", lbl_section_tags="TAGS/COMENTÁRIOS:", lbl_section_smart="SMART:", lbl_section_split="DIVIDIR/UNIR:", lbl_section_time="TEMPO/ORDEM:", lbl_suite_tool="Ferramenta:", lbl_selection="Seleção: %d linhas",
        chk_clear_old="Limpar marcadores anteriores", chk_gap_continuous="Marcar contínuas (0 ms)", chk_gap_ignore_kf="Ignorar gap se cair em KF", chk_kf_seal="Selo de keyframe", chk_data_import_skip="(caixa vazia = pular Importar Dados)",
        chk_has_n="Quebra de linha [LINE-BREAK]", chk_has_pos="Tag de posição [POSITION-TAG]", chk_has_clip="Tag de clip [CLIP-TAG]", chk_has_fad="Tag de fade [FADE-TAG]", chk_has_t="Tag de transformação [TRANSFORM-TAG]", chk_has_k="Tag de karaokê [KARAOKE-TAG]", chk_has_comment="Bloco de comentário [COMMENT-BLOCK]", chk_has_num="Dígitos [HAS-DIGITS]", chk_full_italic="Toda em itálico [FULL-ITALIC]", chk_dbl_space="Espaço duplo [DOUBLE-SPACE]", chk_edge_space="Espaço nas bordas [EDGE-SPACE]",
        chk_uppercase="Maiúsculas [UPPERCASE]", chk_3liner="Três linhas [THREE-LINES]", chk_missing_punct="Sem pontuação final [NO-END-PUNCT]", chk_punct_balance="Pontuação sem par [UNPAIRED-PUNCT]", chk_orphan_word="Última linha curta [SHORT-LAST-LINE]", chk_orphan_tag="Tag quebrada [BROKEN-TAG]", chk_overlap="Sobreposição [OVERLAP]", chk_unstyled="Estilo Default [DEFAULT-STYLE]", chk_double_italics="Erro de itálico [ITALIC-ERROR]", chk_parentheses="Parênteses [PARENTHESES]", chk_name_prefix="Prefixo de nome [NAME-PREFIX]", chk_sentences="Várias frases [MULTI-SENTENCE]",
        msg_config_saved="Configuração salva.", data_import_paste_hint="Cole linhas 'Dialogue:' ou escolha um modo de importação.",
    },
}

local localePatch = {
    en = {
        err_no_active_dialogue   = "No valid active dialogue lines found.",
        err_no_sync_point        = "Data Import — Songs: no sync point found.\nNeed Comment line with layer 50.",
        err_scxvid_not_found     = "SCXvid not found:\n%s",
        err_ffmpeg_not_found     = "FFmpeg not found:\n%s",
        err_cannot_create_batch  = "Error: cannot create temp batch file",
        err_cannot_create_directory = "Error: cannot create the working directory",
        err_cannot_create_shell  = "Error: cannot create temp shell script",
        err_no_lines_selected    = "No lines selected.",
        err_not_inside_fold      = "Active line is not inside a fold.\nMove to a line within a fold group.",
        err_no_fold_group        = "Could not find complete fold group.",
        err_cannot_write_file    = "Could not write to:\n%s",
        err_shift_min_two        = "Align to First Start requires at least 2 lines.",
        err_shift_first_two      = "Align to First Start requires the first two selected lines to be dialogue lines.",
        err_tolerance_positive   = "Tolerance must be a positive number.",
        err_paste_mpvqc          = "Paste mpvQC text first.",
        err_no_mpvqc_comments    = "No mpvQC comments found.",
        msg_process_done         = "Process completed.\nLog: %s",
        err_process_failed       = "Process failed.\n\n%s",
        msg_ae_saved             = "AE keyframe data saved to:\n%s",
        msg_kite_done            = "Kite Timing: %d changes from %d selected lines.",
        msg_replacer_done        = "Text Replacer: %d lines modified.",
        msg_mpvqc_done           = "mpv QC done.\nLines modified: %d",
        msg_remover_done         = "Text and Tag Cleanup done.\nLines modified: %d\nLines deleted: %d",
        err_remover_none         = "Select at least one remover option.",
        lbl_include_partial      = "Include partially overlapping lines",
        lbl_paste_dialogue       = "Paste text or Dialogue/Comment lines:",
        lbl_import_as_comments   = "Import plain text as {…} comments",
        lbl_original_text        = "ORIGINAL TEXT",
        lbl_replacement_text     = "REPLACEMENT TEXT",
        lbl_replacer_help        = "Each line in Original matches the corresponding line in Replacement. Tags preserved.",
        lbl_mpvqc_title          = "mpv QC",
        lbl_mpvqc_tolerance      = "Tolerance (ms):",
        lbl_mpvqc_paste          = "Paste mpvQC text:",
        lbl_remover_title        = "Text and Tag Cleanup",
        lbl_remover_text         = "Visible text",
        lbl_remover_tags         = "Override tags",
        lbl_remover_comments     = "Comments",
        chk_rem_n                = "Remove \\N",
        chk_rem_h                = "Remove \\h",
        chk_rem_double_space     = "Double spaces",
        chk_rem_edge_space       = "Edge spaces",
        chk_rem_excl             = "Exclamation signs",
        chk_rem_quest            = "Question signs",
        chk_rem_combo            = "Mixed ¡¿?! signs",
        chk_rem_final_commas     = "Final commas",
        chk_rem_all_commas       = "All commas",
        chk_rem_quotes           = "Quotes",
        chk_rem_apostrophes      = "Apostrophes",
        chk_rem_stutter          = "Stutter X-X",
        chk_rem_dup_letters      = "Duplicate letters",
        chk_rem_leading_ellipsis = "Leading ellipsis",
        chk_rem_ellipsis         = "All ellipsis",
        chk_rem_italic_tags      = "\\i tags",
        chk_rem_q_tags           = "\\q tags",
        chk_rem_an8              = "\\an8",
        chk_rem_comment_lines    = "Comment lines",
        chk_rem_inline_comments  = "Inline comments {...}",
        btn_import               = "Import",
        btn_replace_all          = "Replace All",
        btn_apply                = "Execute",
    },
    es = {
        err_no_active_dialogue   = "No se encontraron líneas de diálogo activas válidas.",
        err_no_sync_point        = "Importar datos — Songs: no se encontró punto de sincronización.\nSe requiere línea Comment con layer 50.",
        err_scxvid_not_found     = "SCXvid no encontrado:\n%s",
        err_ffmpeg_not_found     = "FFmpeg no encontrado:\n%s",
        err_cannot_create_batch  = "Error: no se pudo crear el archivo batch temporal",
        err_cannot_create_directory = "Error: no se pudo crear el directorio de trabajo",
        err_cannot_create_shell  = "Error: no se pudo crear el script shell temporal",
        err_no_lines_selected    = "Sin líneas seleccionadas.",
        err_not_inside_fold      = "La línea activa no está dentro de un fold.\nMuévete a una línea dentro de un grupo fold.",
        err_no_fold_group        = "No se encontró un grupo fold completo.",
        err_cannot_write_file    = "No se pudo escribir en:\n%s",
        err_shift_min_two        = "Align to First Start requiere al menos 2 líneas.",
        err_shift_first_two      = "Align to First Start requiere que las dos primeras líneas seleccionadas sean diálogo.",
        err_tolerance_positive   = "La tolerancia debe ser un número positivo.",
        err_paste_mpvqc          = "Pega primero el texto de mpvQC.",
        err_no_mpvqc_comments    = "No se encontraron comentarios de mpvQC.",
        msg_process_done         = "Proceso finalizado.\nLog: %s",
        err_process_failed       = "El proceso falló.\n\n%s",
        msg_ae_saved             = "Datos AE guardados en:\n%s",
        msg_kite_done            = "Kite Timing: %d cambios en %d líneas seleccionadas.",
        msg_replacer_done        = "Text Replacer: %d líneas modificadas.",
        msg_mpvqc_done           = "mpv QC finalizado.\nLíneas modificadas: %d",
        msg_remover_done         = "Text and Tag Cleanup finalizado.\nLíneas modificadas: %d\nLíneas eliminadas: %d",
        err_remover_none         = "Selecciona al menos una opcion de limpieza.",
        lbl_include_partial      = "Incluir líneas con superposición parcial",
        lbl_paste_dialogue       = "Pega texto o líneas Dialogue/Comment:",
        lbl_import_as_comments   = "Importar texto plano como comentarios {…}",
        lbl_original_text        = "TEXTO ORIGINAL",
        lbl_replacement_text     = "TEXTO DE REEMPLAZO",
        lbl_replacer_help        = "Cada línea de Original corresponde a la misma línea en Reemplazo. Los tags se conservan.",
        lbl_mpvqc_title          = "mpv QC",
        lbl_mpvqc_tolerance      = "Tolerancia (ms):",
        lbl_mpvqc_paste          = "Pega el texto de mpvQC:",
        lbl_remover_title        = "Text and Tag Cleanup",
        lbl_remover_text         = "Texto visible",
        lbl_remover_tags         = "Override tags",
        lbl_remover_comments     = "Comentarios",
        chk_rem_n                = "Quitar \\N",
        chk_rem_h                = "Quitar \\h",
        chk_rem_double_space     = "Espacios dobles",
        chk_rem_edge_space       = "Espacios al borde",
        chk_rem_excl             = "Signos de exclamacion",
        chk_rem_quest            = "Signos de interrogacion",
        chk_rem_combo            = "Signos mixtos ¡¿?!",
        chk_rem_final_commas     = "Comas finales",
        chk_rem_all_commas       = "Todas las comas",
        chk_rem_quotes           = "Comillas",
        chk_rem_apostrophes      = "Apostrofos",
        chk_rem_stutter          = "Tartamudeo X-X",
        chk_rem_dup_letters      = "Letras duplicadas",
        chk_rem_leading_ellipsis = "Puntos suspensivos iniciales",
        chk_rem_ellipsis         = "Todos los puntos suspensivos",
        chk_rem_italic_tags      = "Tags \\i",
        chk_rem_q_tags           = "Tags \\q",
        chk_rem_an8              = "\\an8",
        chk_rem_comment_lines    = "Lineas comentadas",
        chk_rem_inline_comments  = "Comentarios inline {...}",
        btn_import               = "Importar",
        btn_replace_all          = "Reemplazar todo",
        btn_apply                = "Execute",
    },
    pt = {
        err_no_active_dialogue   = "Nenhuma linha de diálogo ativa válida encontrada.",
        err_no_sync_point        = "Importar dados — Songs: ponto de sincronia não encontrado.\nNecessário linha Comment com layer 50.",
        err_scxvid_not_found     = "SCXvid não encontrado:\n%s",
        err_ffmpeg_not_found     = "FFmpeg não encontrado:\n%s",
        err_cannot_create_batch  = "Erro: não foi possível criar o arquivo batch temporário",
        err_cannot_create_directory = "Erro: não foi possível criar o diretório de trabalho",
        err_cannot_create_shell  = "Erro: não foi possível criar o script shell temporário",
        err_no_lines_selected    = "Nenhuma linha selecionada.",
        err_not_inside_fold      = "A linha ativa não está dentro de um fold.\nVá para uma linha dentro de um grupo fold.",
        err_no_fold_group        = "Grupo fold completo não encontrado.",
        err_cannot_write_file    = "Não foi possível gravar em:\n%s",
        err_shift_min_two        = "Align to First Start requer pelo menos 2 linhas.",
        err_shift_first_two      = "Align to First Start requer que as duas primeiras linhas selecionadas sejam diálogo.",
        err_tolerance_positive   = "A tolerância deve ser um número positivo.",
        err_paste_mpvqc          = "Cole primeiro o texto do mpvQC.",
        err_no_mpvqc_comments    = "Nenhum comentário do mpvQC encontrado.",
        msg_process_done         = "Processo concluído.\nLog: %s",
        err_process_failed       = "O processo falhou.\n\n%s",
        msg_ae_saved             = "Dados AE salvos em:\n%s",
        msg_kite_done            = "Kite Timing: %d alterações em %d linhas selecionadas.",
        msg_replacer_done        = "Text Replacer: %d linhas modificadas.",
        msg_mpvqc_done           = "mpv QC concluído.\nLinhas modificadas: %d",
        msg_remover_done         = "Text and Tag Cleanup concluido.\nLinhas modificadas: %d\nLinhas apagadas: %d",
        err_remover_none         = "Selecione pelo menos uma opcao de limpeza.",
        lbl_include_partial      = "Incluir linhas com sobreposição parcial",
        lbl_paste_dialogue       = "Cole texto ou linhas Dialogue/Comment:",
        lbl_import_as_comments   = "Importar texto puro como comentários {…}",
        lbl_original_text        = "TEXTO ORIGINAL",
        lbl_replacement_text     = "TEXTO DE SUBSTITUIÇÃO",
        lbl_replacer_help        = "Cada linha em Original corresponde à mesma linha em Substituição. Tags são preservados.",
        lbl_mpvqc_title          = "mpv QC",
        lbl_mpvqc_tolerance      = "Tolerância (ms):",
        lbl_mpvqc_paste          = "Cole o texto do mpvQC:",
        lbl_remover_title        = "Text and Tag Cleanup",
        lbl_remover_text         = "Texto visivel",
        lbl_remover_tags         = "Override tags",
        lbl_remover_comments     = "Comentarios",
        chk_rem_n                = "Remover \\N",
        chk_rem_h                = "Remover \\h",
        chk_rem_double_space     = "Espacos duplos",
        chk_rem_edge_space       = "Espacos nas bordas",
        chk_rem_excl             = "Sinais de exclamacao",
        chk_rem_quest            = "Sinais de interrogacao",
        chk_rem_combo            = "Sinais mistos ¡¿?!",
        chk_rem_final_commas     = "Virgulas finais",
        chk_rem_all_commas       = "Todas as virgulas",
        chk_rem_quotes           = "Aspas",
        chk_rem_apostrophes      = "Apostrofos",
        chk_rem_stutter          = "Gagueira X-X",
        chk_rem_dup_letters      = "Letras duplicadas",
        chk_rem_leading_ellipsis = "Reticencias iniciais",
        chk_rem_ellipsis         = "Todas as reticencias",
        chk_rem_italic_tags      = "Tags \\i",
        chk_rem_q_tags           = "Tags \\q",
        chk_rem_an8              = "\\an8",
        chk_rem_comment_lines    = "Linhas comentadas",
        chk_rem_inline_comments  = "Comentarios inline {...}",
        btn_import               = "Importar",
        btn_replace_all          = "Substituir tudo",
        btn_apply                = "Execute",
    },
}

for code, tbl in pairs(extraLang) do
    LANG[code] = LANG[code] or {}
    for k, v in pairs(tbl) do LANG[code][k] = v end
end

for code, tbl in pairs(localePatch) do
    LANG[code] = LANG[code] or {}
    for k, v in pairs(tbl) do LANG[code][k] = v end
end

local emphasisLang = {
    en = {
        chk_strong_excl     = "Strong exclamation [STRONG-EXCL]",
        chk_strong_quest    = "Strong question [STRONG-QUEST]",
        chk_mixed_emphasis  = "Mixed emphasis [MIXED-EMPHASIS]",
        chk_semicolon       = "Semicolon [SEMICOLON]",
        chk_stutter         = "Stutter [STUTTER]",
        btn_scream          = "Scream",
        scream_title        = "Scream Detector",
        scream_lbl_avg      = "Average line dB:",
        scream_lbl_sample   = "Strong sample dB:",
        scream_lbl_ratio    = "Strong sample ratio (%):",
        scream_lbl_min      = "Minimum samples:",
        scream_lbl_z        = "Robust z-score:",
        scream_chk_clean    = "Clear previous SCREAM marks",
        scream_chk_reuse    = "Reuse existing analysis log",
        scream_btn_analyze  = "Analyze",
        scream_msg_no_media = "Scream Detector: no audio or video file is loaded.",
        scream_msg_no_folder= "Scream Detector: could not find a folder for the analysis files.",
        scream_msg_no_batch = "Scream Detector: could not create the analysis workspace.",
        scream_msg_running  = "Scream Detector: running FFmpeg analysis.\nThis can take a while.",
        scream_msg_no_log   = "Scream Detector: no audio samples found in the analysis log.\nLog: %s",
        scream_msg_done     = "Scream Detector: marked %d of %d lines.\nSamples: %d\nMedian avg: %.2f dB | MAD: %.2f dB",
        scream_help         = "Scream Detector marks lines whose interval is statistically loud.\n\n"
                              .. "Average line dB: mean power inside each subtitle interval (closer to 0 is stricter).\n"
                              .. "Strong sample dB: samples above this value count as strong evidence.\n"
                              .. "Strong sample ratio: minimum percent of strong samples per interval.\n"
                              .. "Minimum samples: ignore lines with too little audio evidence.\n"
                              .. "Robust z-score: compares each line against median/MAD of the current set.\n"
                              .. "Reuse log skips FFmpeg if the analysis log already exists.",
    },
    es = {
        chk_strong_excl     = "Exclamación fuerte [STRONG-EXCL]",
        chk_strong_quest    = "Interrogación fuerte [STRONG-QUEST]",
        chk_mixed_emphasis  = "Énfasis mixto [MIXED-EMPHASIS]",
        chk_semicolon       = "Punto y coma [SEMICOLON]",
        chk_stutter         = "Tartamudeo [STUTTER]",
        btn_scream          = "Grito",
        scream_title        = "Detector de Gritos",
        scream_lbl_avg      = "Promedio dB:",
        scream_lbl_sample   = "Muestra fuerte dB:",
        scream_lbl_ratio    = "Ratio muestra fuerte (%):",
        scream_lbl_min      = "Muestras mínimas:",
        scream_lbl_z        = "z-score robusto:",
        scream_chk_clean    = "Limpiar marcas SCREAM previas",
        scream_chk_reuse    = "Reutilizar log de análisis existente",
        scream_btn_analyze  = "Analizar",
        scream_msg_no_media = "Scream Detector: no hay audio o vídeo cargado.",
        scream_msg_no_folder= "Scream Detector: no se encontró carpeta para los archivos de análisis.",
        scream_msg_no_batch = "Scream Detector: no se pudo crear el espacio de análisis.",
        scream_msg_running  = "Scream Detector: ejecutando análisis de FFmpeg.\nPuede tardar un rato.",
        scream_msg_no_log   = "Scream Detector: no se encontraron muestras en el registro de análisis.\nRegistro: %s",
        scream_msg_done     = "Scream Detector: marcadas %d de %d líneas.\nMuestras: %d\nMediana promedio: %.2f dB | MAD: %.2f dB",
        scream_help         = "Scream Detector marca líneas cuyo intervalo es estadísticamente fuerte.\n\n"
                              .. "Promedio dB: potencia media en el intervalo de cada subtítulo (más cerca de 0 es más estricto).\n"
                              .. "Muestra fuerte dB: muestras por encima de este valor cuentan como evidencia fuerte.\n"
                              .. "Ratio muestra fuerte: porcentaje mínimo de muestras fuertes por intervalo.\n"
                              .. "Muestras mínimas: ignora líneas con muy poca evidencia.\n"
                              .. "z-score robusto: compara cada línea contra mediana/MAD del conjunto actual.\n"
                              .. "Reutilizar log evita correr FFmpeg si ya existe el log de análisis.",
    },
    pt = {
        chk_strong_excl     = "Exclamação forte [STRONG-EXCL]",
        chk_strong_quest    = "Interrogação forte [STRONG-QUEST]",
        chk_mixed_emphasis  = "Ênfase mista [MIXED-EMPHASIS]",
        chk_semicolon       = "Ponto e vírgula [SEMICOLON]",
        chk_stutter         = "Gagueira [STUTTER]",
        btn_scream          = "Grito",
        scream_title        = "Detector de Gritos",
        scream_lbl_avg      = "Média dB:",
        scream_lbl_sample   = "Amostra forte dB:",
        scream_lbl_ratio    = "Razão amostra forte (%):",
        scream_lbl_min      = "Amostras mínimas:",
        scream_lbl_z        = "z-score robusto:",
        scream_chk_clean    = "Limpar marcas SCREAM anteriores",
        scream_chk_reuse    = "Reutilizar log de análise existente",
        scream_btn_analyze  = "Analisar",
        scream_msg_no_media = "Scream Detector: nenhum áudio ou vídeo carregado.",
        scream_msg_no_folder= "Scream Detector: não foi encontrada pasta para os arquivos de análise.",
        scream_msg_no_batch = "Scream Detector: não foi possível criar o espaço de análise.",
        scream_msg_running  = "Scream Detector: executando análise do FFmpeg.\nPode demorar.",
        scream_msg_no_log   = "Scream Detector: nenhuma amostra encontrada no registro de análise.\nRegistro: %s",
        scream_msg_done     = "Scream Detector: marcadas %d de %d linhas.\nAmostras: %d\nMediana média: %.2f dB | MAD: %.2f dB",
        scream_help         = "Scream Detector marca linhas cujo intervalo é estatisticamente forte.\n\n"
                              .. "Média dB: potência média no intervalo de cada legenda (mais perto de 0 é mais estrito).\n"
                              .. "Amostra forte dB: amostras acima deste valor contam como evidência forte.\n"
                              .. "Razão amostra forte: porcentagem mínima de amostras fortes por intervalo.\n"
                              .. "Amostras mínimas: ignora linhas com pouca evidência.\n"
                              .. "z-score robusto: compara cada linha contra mediana/MAD do conjunto atual.\n"
                              .. "Reutilizar log evita rodar FFmpeg se o log de análise já existir.",
    },
}

for code, tbl in pairs(emphasisLang) do
    LANG[code] = LANG[code] or {}
    for k, v in pairs(tbl) do LANG[code][k] = v end
end

local function L(key)
    return (LANG[getLanguage()] and LANG[getLanguage()][key]) or LANG.en[key] or key
end

local UI = {
    labels = {
        en = {
            ["en"]="English", ["es"]="Spanish", ["pt"]="Portuguese",
            ["All Selected"]="All selected", ["By Style"]="By style", ["By Actor"]="By actor", ["By Effect"]="By effect", ["By Layer"]="By layer",
            ["Ends Only"]="Ends only", ["Start Only"]="Start only", ["Full Audit"]="Full audit", ["Duration"]="Duration", ["CPS"]="CPS", ["Short Gaps"]="Short gaps", ["Large Gaps"]="Large gaps", ["Both Gaps"]="Both gaps", ["Overtime"]="Overtime",
            ["End Only"]="End only", ["Both"]="Both", ["End only"]="End only", ["Start only"]="Start only",
            ["KF Back"]="Back", ["KF Forward"]="Forward", ["KF Both"]="Both",
            ["Import Effects"]="Import effects", ["Import Actor"]="Import actor", ["Import Tags"]="Import tags", ["Song Sync"]="Song sync",
            ["Full Timing"]="Full + polish", ["Post-Timing"]="Post current", ["Raw Timing"]="Raw voice",
            ["Lazy"]="Lazy", ["Busy"]="Busy", ["LazyFusion"]="LazyFusion", ["Cluster (±ms)"]="Cluster (±ms)", ["Table (±ms)"]="Table (±ms)",
            ["Only changes"]="Only changes", ["Only 0ms"]="Only 0 ms", ["None"]="None",
            ["All"]="All", ["All Default"]="All Default", ["Default+Alt"]="Default + Alt",
            ["Number Effects"]="Number effects", ["Add Identifier"]="Add identifier",
            ["UPPERCASE"]="Uppercase", ["THREE-LINES"]="Three lines", ["NO-END-PUNCT"]="No end punctuation", ["UNPAIRED-PUNCT"]="Unpaired punctuation",
            ["SHORT-LAST-LINE"]="Short last line", ["BROKEN-TAG"]="Broken tag", ["OVERLAP"]="Overlap", ["DEFAULT-STYLE"]="Default style",
            ["ITALIC-ERROR"]="Italic error", ["PARENTHESES"]="Parentheses", ["NAME-PREFIX"]="Name prefix", ["MULTI-SENTENCE"]="Multiple sentences",
            ["TOO-WIDE"]="Too wide", ["TOO-SHORT"]="Too short", ["TOO-LONG"]="Too long", ["TOO-LONG-TIME"]="Too long duration",
            ["FAST-CPS"]="Fast CPS", ["SLOW-CPS"]="Slow CPS", ["SHORT-GAP"]="Short gap", ["LARGE-GAP"]="Large gap", ["END-ON-KF/START-ON-KF"]="On keyframe",
            ["NEAR-END-KF/NEAR-START-KF"]="Near keyframe", ["MISSED-END-KF/MISSED-START-KF"]="Missed keyframe",
            ["LINE-BREAK"]="Line break", ["POSITION-TAG"]="Position tag", ["CLIP-TAG"]="Clip tag", ["DRAWING-CLIP"]="Drawing + clip", ["FADE-TAG"]="Fade tag",
            ["TRANSFORM-TAG"]="Transform tag", ["KARAOKE-TAG"]="Karaoke tag", ["COMMENT-BLOCK"]="Comment block", ["HAS-DIGITS"]="Digits",
            ["HAS-CJK"]="CJK / kana", ["FULL-ITALIC"]="Full italic", ["DOUBLE-SPACE"]="Double space", ["EDGE-SPACE"]="Edge space",
            ["Toggle \\an8"]="Toggle \\an8", ["Toggle Italics"]="Toggle italics", ["Uppercase"]="Uppercase", ["Lowercase"]="Lowercase",
            ["Title Case"]="Title case", ["Sentence Case"]="Sentence case", ["Capitalize First"]="Capitalize first", ["Lowercase First"]="Lowercase first",
            ["Normalize Ellipsis"]="Normalize ellipsis", ["Add Ellipsis"]="Add ellipsis", ["Erase Leading Ellipsis"]="Erase leading ellipsis", ["Erase Inner Ellipsis"]="Erase inner ellipsis",
            ["Ellipsis to Comma"]="Ellipsis to comma", ["Ellipsis to Period"]="Ellipsis to period",
            ["Unify Quotes"]="Unify quotes", ["Normalize Dashes"]="Normalize dashes", ["Trim Trailing Spaces"]="Trim trailing spaces",
            ["Remove Duplicate Letters"]="Remove duplicate letters", ["Normalize Stutter"]="Normalize stutter", ["Extract Tags"]="Extract tags",
            ["Reinsert Tags"]="Reinsert tags", ["Remove Tags"]="Remove tags", ["Merge Tags"]="Merge tags", ["Remove Inline Comments"]="Remove inline comments", ["Extract Actors and Split"]="Extract actors and split",
            ["Swap Text and Comments"]="Swap text and comments", ["Delete Comment Lines"]="Delete comment lines", ["Comments to Top"]="Comments to top",
            ["Comments to Bottom"]="Comments to bottom", ["Effects to Top"]="Effects to top", ["Fold by Identifier"]="Fold by identifier", ["Add Stutter"]="Add stutter",
            ["Add Ah Prefix"]="Add Ah prefix", ["Bidirectional Snapping"]="Bidirectional snapping", ["Start Snap Back"]="Start snap back", ["Start Snap Forward"]="Start snap forward", ["End Snap Back"]="End snap back", ["End Snap Forward"]="End snap forward", ["Remove Honorifics"]="Remove honorifics",
            ["Caption Clarifier"]="Caption clarifier", ["Complete Sentences"]="Complete sentences", ["Erase Blank Lines"]="Erase blank lines", ["Remove \\N"]="Remove \\N",
            ["Current Frame to Effect"]="Current frame to Effect", ["Copy Fold"]="Copy fold", ["Smart Break"]="Smart break", ["Split by Sentence"]="Split by sentence",
            ["Split by Comma"]="Split by comma", ["Line Merge and Cleanup"]="Line merge and cleanup", ["Join Same Text"]="Join same text", ["Join Overlaps"]="Join overlaps", ["Join Overlap Sentences"]="Join overlap sentences", ["Divide by \\N"]="Divide by \\N",
            ["Copy Times"]="Copy times", ["Select Time Range"]="Select time range", ["Sort by Text Length"]="Sort by text length", ["Sort by CPS"]="Sort by CPS",
            ["Sort Odd Even"]="Sort odd/even", ["Count CPS"]="Count CPS", ["Import Text"]="Import text", ["Kite Timing"]="Kite timing",
            ["Add Lead-In Left"]="Add lead-in left", ["Add Lead-In Right"]="Add lead-in right", ["Add Lead-Out Left"]="Add lead-out left", ["Add Lead-Out Right"]="Add lead-out right", ["Chain Left"]="Chain left", ["Chain Right"]="Chain right",
            ["Align to First Start"]="Align to first start", ["Romaji Karaoker (Word → \\k)"]="Romaji karaoker (word → \\k)",
            ["Text and Tag Cleanup"]="Text and tag cleanup", ["Properties and Cleanup"]="Properties and cleanup", ["After Effects Keyframes"]="After Effects keyframes", ["Text Replacer"]="Text replacer", ["mpv QC"]="mpv QC",
        },
        es = {
            ["en"]="Inglés", ["es"]="Español", ["pt"]="Portugués",
            ["All Selected"]="Toda la selección", ["By Style"]="Por estilo", ["By Actor"]="Por actor", ["By Effect"]="Por Effect", ["By Layer"]="Por capa",
            ["Ends Only"]="Solo finales", ["Start Only"]="Solo inicios", ["Full Audit"]="Auditoría completa", ["Duration"]="Duración", ["CPS"]="CPS", ["Short Gaps"]="Gaps cortos", ["Large Gaps"]="Gaps largos", ["Both Gaps"]="Ambos gaps", ["Overtime"]="Sobretiempo",
            ["End Only"]="Solo final", ["Both"]="Ambos", ["End only"]="Solo final", ["Start only"]="Solo inicio",
            ["KF Back"]="Atrás", ["KF Forward"]="Adelante", ["KF Both"]="Ambos",
            ["Import Effects"]="Importar Effects", ["Import Actor"]="Importar actor", ["Import Tags"]="Importar tags", ["Song Sync"]="Sincronía de canción",
            ["Full Timing"]="Completo + ajuste", ["Post-Timing"]="Post actual", ["Raw Timing"]="Voz bruta",
            ["Lazy"]="Lazy", ["Busy"]="Busy", ["LazyFusion"]="LazyFusion", ["Cluster (±ms)"]="Clúster (±ms)", ["Table (±ms)"]="Tabla (±ms)",
            ["Only changes"]="Solo cambios", ["Only 0ms"]="Solo 0 ms", ["None"]="Ninguno",
            ["All"]="Todo", ["All Default"]="Todo Default", ["Default+Alt"]="Default + Alt",
            ["Number Effects"]="Numerar Effects", ["Add Identifier"]="Añadir identificador",
            ["UPPERCASE"]="Mayúsculas", ["THREE-LINES"]="Tres líneas", ["NO-END-PUNCT"]="Sin puntuación final", ["UNPAIRED-PUNCT"]="Puntuación sin pareja",
            ["SHORT-LAST-LINE"]="Última línea corta", ["BROKEN-TAG"]="Tag roto", ["OVERLAP"]="Solapamiento", ["DEFAULT-STYLE"]="Estilo Default",
            ["ITALIC-ERROR"]="Error de cursiva", ["PARENTHESES"]="Paréntesis", ["NAME-PREFIX"]="Prefijo de nombre", ["MULTI-SENTENCE"]="Varias oraciones",
            ["TOO-WIDE"]="Demasiado ancho", ["TOO-SHORT"]="Muy corta", ["TOO-LONG"]="Muy larga", ["TOO-LONG-TIME"]="Duración excesiva",
            ["FAST-CPS"]="CPS alto", ["SLOW-CPS"]="CPS bajo", ["SHORT-GAP"]="Gap corto", ["LARGE-GAP"]="Gap largo", ["END-ON-KF/START-ON-KF"]="En keyframe",
            ["NEAR-END-KF/NEAR-START-KF"]="Cerca de keyframe", ["MISSED-END-KF/MISSED-START-KF"]="Keyframe omitido",
            ["LINE-BREAK"]="Salto de línea", ["POSITION-TAG"]="Tag de posición", ["CLIP-TAG"]="Tag de clip", ["DRAWING-CLIP"]="Dibujo + clip", ["FADE-TAG"]="Tag de fade",
            ["TRANSFORM-TAG"]="Tag de transformación", ["KARAOKE-TAG"]="Tag de karaoke", ["COMMENT-BLOCK"]="Bloque de comentario", ["HAS-DIGITS"]="Dígitos",
            ["HAS-CJK"]="CJK / kana", ["FULL-ITALIC"]="Toda en cursiva", ["DOUBLE-SPACE"]="Doble espacio", ["EDGE-SPACE"]="Espacio al borde",
            ["Toggle \\an8"]="Alternar \\an8", ["Toggle Italics"]="Alternar cursiva", ["Uppercase"]="Mayúsculas", ["Lowercase"]="Minúsculas",
            ["Title Case"]="Tipo título", ["Sentence Case"]="Tipo oración", ["Capitalize First"]="Primera mayúscula", ["Lowercase First"]="Primera minúscula",
            ["Normalize Ellipsis"]="Normalizar elipsis", ["Add Ellipsis"]="Añadir elipsis", ["Erase Leading Ellipsis"]="Borrar elipsis inicial", ["Erase Inner Ellipsis"]="Borrar elipsis interna",
            ["Ellipsis to Comma"]="Elipsis a coma", ["Ellipsis to Period"]="Elipsis a punto",
            ["Unify Quotes"]="Unificar comillas", ["Normalize Dashes"]="Normalizar guiones", ["Trim Trailing Spaces"]="Quitar espacios finales",
            ["Remove Duplicate Letters"]="Quitar letras repetidas", ["Normalize Stutter"]="Normalizar tartamudeo", ["Extract Tags"]="Extraer tags",
            ["Reinsert Tags"]="Reinsertar tags", ["Remove Tags"]="Quitar tags", ["Merge Tags"]="Unir tags", ["Remove Inline Comments"]="Quitar comentarios internos", ["Extract Actors and Split"]="Extraer actores y dividir",
            ["Swap Text and Comments"]="Intercambiar texto y comentarios", ["Delete Comment Lines"]="Borrar líneas comentadas", ["Comments to Top"]="Comentarios arriba",
            ["Comments to Bottom"]="Comentarios abajo", ["Effects to Top"]="Con Effect arriba", ["Fold by Identifier"]="Fold por identificador", ["Add Stutter"]="Añadir tartamudeo",
            ["Add Ah Prefix"]="Añadir Ah inicial", ["Bidirectional Snapping"]="Snap bidireccional", ["Start Snap Back"]="Inicio a KF previo", ["Start Snap Forward"]="Inicio a KF siguiente", ["End Snap Back"]="Final a KF previo", ["End Snap Forward"]="Final a KF siguiente", ["Remove Honorifics"]="Comentar honoríficos",
            ["Caption Clarifier"]="Limpiar acotaciones", ["Complete Sentences"]="Completar oraciones", ["Erase Blank Lines"]="Borrar líneas vacías", ["Remove \\N"]="Quitar \\N",
            ["Current Frame to Effect"]="Fotograma actual a Effect", ["Copy Fold"]="Copiar fold", ["Smart Break"]="Salto inteligente", ["Split by Sentence"]="Dividir por oración",
            ["Split by Comma"]="Dividir por coma", ["Line Merge and Cleanup"]="Combinar y limpiar líneas", ["Join Same Text"]="Unir texto igual", ["Join Overlaps"]="Unir solapes", ["Join Overlap Sentences"]="Unir solapes en frase", ["Divide by \\N"]="Dividir por \\N",
            ["Copy Times"]="Copiar tiempos", ["Select Time Range"]="Seleccionar por intervalo", ["Sort by Text Length"]="Ordenar por longitud del texto", ["Sort by CPS"]="Ordenar por CPS",
            ["Sort Odd Even"]="Ordenar impar/par", ["Count CPS"]="Contar CPS", ["Import Text"]="Importar texto", ["Kite Timing"]="Kite timing",
            ["Add Lead-In Left"]="Lead-in izquierda", ["Add Lead-In Right"]="Lead-in derecha", ["Add Lead-Out Left"]="Lead-out izquierda", ["Add Lead-Out Right"]="Lead-out derecha", ["Chain Left"]="Encadenar izquierda", ["Chain Right"]="Encadenar derecha",
            ["Align to First Start"]="Alinear al inicio de la primera", ["Romaji Karaoker (Word → \\k)"]="Karaoke romaji (palabra → \\k)",
            ["Text and Tag Cleanup"]="Limpiar texto y tags", ["Properties and Cleanup"]="Propiedades y limpieza", ["After Effects Keyframes"]="Fotogramas para After Effects", ["Text Replacer"]="Reemplazar texto", ["mpv QC"]="mpv QC",
        },
        pt = {
            ["en"]="Inglês", ["es"]="Espanhol", ["pt"]="Português",
            ["All Selected"]="Toda a seleção", ["By Style"]="Por estilo", ["By Actor"]="Por ator", ["By Effect"]="Por Effect", ["By Layer"]="Por camada",
            ["Ends Only"]="Só finais", ["Start Only"]="Só inícios", ["Full Audit"]="Auditoria completa", ["Duration"]="Duração", ["CPS"]="CPS", ["Short Gaps"]="Gaps curtos", ["Large Gaps"]="Gaps longos", ["Both Gaps"]="Ambos gaps", ["Overtime"]="Sobretempo",
            ["End Only"]="Só final", ["Both"]="Ambos", ["End only"]="Só final", ["Start only"]="Só início",
            ["KF Back"]="Para trás", ["KF Forward"]="Para frente", ["KF Both"]="Ambos",
            ["Import Effects"]="Importar Effects", ["Import Actor"]="Importar ator", ["Import Tags"]="Importar tags", ["Song Sync"]="Sincronia da música",
            ["Full Timing"]="Completo + ajuste", ["Post-Timing"]="Pós atual", ["Raw Timing"]="Voz bruta",
            ["Lazy"]="Lazy", ["Busy"]="Busy", ["LazyFusion"]="LazyFusion", ["Cluster (±ms)"]="Cluster (±ms)", ["Table (±ms)"]="Tabela (±ms)",
            ["Only changes"]="Só mudanças", ["Only 0ms"]="Só 0 ms", ["None"]="Nenhum",
            ["All"]="Tudo", ["All Default"]="Tudo Default", ["Default+Alt"]="Default + Alt",
            ["Number Effects"]="Numerar Effects", ["Add Identifier"]="Adicionar identificador",
            ["UPPERCASE"]="Maiúsculas", ["THREE-LINES"]="Três linhas", ["NO-END-PUNCT"]="Sem pontuação final", ["UNPAIRED-PUNCT"]="Pontuação sem par",
            ["SHORT-LAST-LINE"]="Última linha curta", ["BROKEN-TAG"]="Tag quebrada", ["OVERLAP"]="Sobreposição", ["DEFAULT-STYLE"]="Estilo Default",
            ["ITALIC-ERROR"]="Erro de itálico", ["PARENTHESES"]="Parênteses", ["NAME-PREFIX"]="Prefixo de nome", ["MULTI-SENTENCE"]="Várias frases",
            ["TOO-WIDE"]="Larga demais", ["TOO-SHORT"]="Curta demais", ["TOO-LONG"]="Longa demais", ["TOO-LONG-TIME"]="Duração excessiva",
            ["FAST-CPS"]="CPS alto", ["SLOW-CPS"]="CPS baixo", ["SHORT-GAP"]="Gap curto", ["LARGE-GAP"]="Gap longo", ["END-ON-KF/START-ON-KF"]="Em keyframe",
            ["NEAR-END-KF/NEAR-START-KF"]="Perto de keyframe", ["MISSED-END-KF/MISSED-START-KF"]="Keyframe perdido",
            ["LINE-BREAK"]="Quebra de linha", ["POSITION-TAG"]="Tag de posição", ["CLIP-TAG"]="Tag de clip", ["DRAWING-CLIP"]="Desenho + clip", ["FADE-TAG"]="Tag de fade",
            ["TRANSFORM-TAG"]="Tag de transformação", ["KARAOKE-TAG"]="Tag de karaokê", ["COMMENT-BLOCK"]="Bloco de comentário", ["HAS-DIGITS"]="Dígitos",
            ["HAS-CJK"]="CJK / kana", ["FULL-ITALIC"]="Toda em itálico", ["DOUBLE-SPACE"]="Espaço duplo", ["EDGE-SPACE"]="Espaço nas bordas",
            ["Toggle \\an8"]="Alternar \\an8", ["Toggle Italics"]="Alternar itálico", ["Uppercase"]="Maiúsculas", ["Lowercase"]="Minúsculas",
            ["Title Case"]="Tipo título", ["Sentence Case"]="Tipo frase", ["Capitalize First"]="Primeira maiúscula", ["Lowercase First"]="Primeira minúscula",
            ["Normalize Ellipsis"]="Normalizar reticências", ["Add Ellipsis"]="Adicionar reticências", ["Erase Leading Ellipsis"]="Apagar reticências iniciais", ["Erase Inner Ellipsis"]="Apagar reticências internas",
            ["Ellipsis to Comma"]="Reticências para vírgula", ["Ellipsis to Period"]="Reticências para ponto",
            ["Unify Quotes"]="Unificar aspas", ["Normalize Dashes"]="Normalizar travessões", ["Trim Trailing Spaces"]="Remover espaços finais",
            ["Remove Duplicate Letters"]="Remover letras repetidas", ["Normalize Stutter"]="Normalizar gaguejo", ["Extract Tags"]="Extrair tags",
            ["Reinsert Tags"]="Reinserir tags", ["Remove Tags"]="Remover tags", ["Merge Tags"]="Unir tags", ["Remove Inline Comments"]="Remover comentários internos", ["Extract Actors and Split"]="Extrair atores e dividir",
            ["Swap Text and Comments"]="Trocar texto e comentários", ["Delete Comment Lines"]="Apagar linhas comentadas", ["Comments to Top"]="Comentários acima",
            ["Comments to Bottom"]="Comentários abaixo", ["Effects to Top"]="Com Effect acima", ["Fold by Identifier"]="Fold por identificador", ["Add Stutter"]="Adicionar gaguejo",
            ["Add Ah Prefix"]="Adicionar Ah inicial", ["Bidirectional Snapping"]="Snap bidirecional", ["Start Snap Back"]="Inicio ao KF anterior", ["Start Snap Forward"]="Inicio ao KF seguinte", ["End Snap Back"]="Fim ao KF anterior", ["End Snap Forward"]="Fim ao KF seguinte", ["Remove Honorifics"]="Comentar honoríficos",
            ["Caption Clarifier"]="Limpar indicações", ["Complete Sentences"]="Completar frases", ["Erase Blank Lines"]="Apagar linhas vazias", ["Remove \\N"]="Remover \\N",
            ["Current Frame to Effect"]="Quadro atual para Effect", ["Copy Fold"]="Copiar fold", ["Smart Break"]="Quebra inteligente", ["Split by Sentence"]="Dividir por frase",
            ["Split by Comma"]="Dividir por vírgula", ["Line Merge and Cleanup"]="Combinar e limpar linhas", ["Join Same Text"]="Unir texto igual", ["Join Overlaps"]="Unir sobreposições", ["Join Overlap Sentences"]="Unir sobreposições em frase", ["Divide by \\N"]="Dividir por \\N",
            ["Copy Times"]="Copiar tempos", ["Select Time Range"]="Selecionar por intervalo", ["Sort by Text Length"]="Ordenar por tamanho do texto", ["Sort by CPS"]="Ordenar por CPS",
            ["Sort Odd Even"]="Ordenar ímpar/par", ["Count CPS"]="Contar CPS", ["Import Text"]="Importar texto", ["Kite Timing"]="Kite timing",
            ["Add Lead-In Left"]="Lead-in esquerda", ["Add Lead-In Right"]="Lead-in direita", ["Add Lead-Out Left"]="Lead-out esquerda", ["Add Lead-Out Right"]="Lead-out direita", ["Chain Left"]="Encadear esquerda", ["Chain Right"]="Encadear direita",
            ["Align to First Start"]="Alinhar ao início da primeira", ["Romaji Karaoker (Word → \\k)"]="Karaokê romaji (palavra → \\k)",
            ["Text and Tag Cleanup"]="Limpar texto e tags", ["Properties and Cleanup"]="Propriedades e limpeza", ["After Effects Keyframes"]="Quadros para After Effects", ["Text Replacer"]="Substituir texto", ["mpv QC"]="mpv QC",
        },
    },
}
UI.labels.en["FINAL-COMMA"] = "Final comma"
UI.labels.es["FINAL-COMMA"] = "Final con coma"
UI.labels.pt["FINAL-COMMA"] = "Final com virgula"
UI.labels.en["Pivot \\N"] = "Pivot \\N"
UI.labels.es["Pivot \\N"] = "Pivotear \\N"
UI.labels.pt["Pivot \\N"] = "Pivotar \\N"
UI.labels.en["STRONG-EXCL"]     = "Strong exclamation"
UI.labels.es["STRONG-EXCL"]     = "Exclamación fuerte"
UI.labels.pt["STRONG-EXCL"]     = "Exclamação forte"
UI.labels.en["STRONG-QUEST"]    = "Strong question"
UI.labels.es["STRONG-QUEST"]    = "Interrogación fuerte"
UI.labels.pt["STRONG-QUEST"]    = "Interrogação forte"
UI.labels.en["MIXED-EMPHASIS"]  = "Mixed emphasis"
UI.labels.es["MIXED-EMPHASIS"]  = "Énfasis mixto"
UI.labels.pt["MIXED-EMPHASIS"]  = "Ênfase mista"
UI.labels.en["SEMICOLON"]       = "Semicolon"
UI.labels.es["SEMICOLON"]       = "Punto y coma"
UI.labels.pt["SEMICOLON"]       = "Ponto e vírgula"
UI.labels.en["Smart Split"] = "Smart Split"
UI.labels.en["Shift Following Lines"] = "Shift Following Lines"
UI.labels.en["STUTTER"]         = "Stutter"
UI.labels.es["Smart Split"] = "División inteligente"
UI.labels.es["Shift Following Lines"] = "Desplazar posteriores"
UI.labels.es["STUTTER"]         = "Tartamudeo"
UI.labels.pt["Smart Split"] = "Divisão inteligente"
UI.labels.pt["Shift Following Lines"] = "Deslocar seguintes"
UI.labels.pt["STUTTER"]         = "Gagueira"
UI.labels.en["SCREAM"]          = "Scream"
UI.labels.es["SCREAM"]          = "Grito"
UI.labels.pt["SCREAM"]          = "Grito"
UI.labels.en["All dialogue"]    = "All dialogue"
UI.labels.es["All dialogue"]    = "Todo el diálogo"
UI.labels.pt["All dialogue"]    = "Todo o diálogo"
UI.labels.en["Selected lines"]  = "Selected lines"
UI.labels.es["Selected lines"]  = "Líneas seleccionadas"
UI.labels.pt["Selected lines"]  = "Linhas selecionadas"
function UI.text(key)
    return (UI.labels[getLanguage()] and UI.labels[getLanguage()][key]) or (UI.labels.en and UI.labels.en[key]) or key
end
function UI.options(values, current)
    local data = { items = {}, map = {}, value = "" }
    local n = 0
    for _, key in ipairs(values) do
        local shown = ""
        if key ~= "" then n = n + 1; shown = tostring(n) .. ". " .. UI.text(key) end
        data.items[#data.items+1] = shown
        data.map[shown] = key
        if key == current then data.value = shown end
    end
    return data
end
function UI.utilityOptions(section, current)
    local values = {}
    for _, it in ipairs(section.items) do values[#values+1] = it.name or "" end
    return UI.options(values, current)
end
function UI.from(data, shown)
    if not data then return shown end
    return data.map[shown] ~= nil and data.map[shown] or shown
end

return L, UI
end
return M

end)()

Timing.Waveform = (function()
local M = {}
local Core = require("kite.Core")
local floor, max, abs = math.floor, math.max, math.abs
local trim = Core.trim
local integerArray
do
    local lpeg = require("lpeg")
    local P, S, R = lpeg.P, lpeg.S, lpeg.R
    local space = S(" \t\r\n")^0
    local integer = P("-")^-1 * (P("0") + R("19") * R("09")^0)
    integerArray = P("[") * space * (integer * space * (P(",") * space * integer * space)^0)^-1 * P("]") * -P(1)
end
function M.read(path, progress, checkCancelled)
    progress = progress or function() end
    checkCancelled = checkCancelled or function() end
    progress("Smart Split: leyendo onda...", 0)
    local file, message = io.open(path, "rb")
    if not file then error(message, 0) end
    local content = file:read("*a")
    file:close()
    if not content then error("No se pudo leer el JSON de onda.", 0) end
    local arrays = {}
    local skeleton = content:gsub('("peaks"%s*:%s*)(%b[])', function(key, array)
        checkCancelled()
        if not integerArray:match(array) then error("Lista de picos inválida en un nivel de la onda.", 0) end
        arrays[#arrays+1] = array
        return key .. '"Smart SplitPeaks' .. #arrays .. '"'
    end)
    content = nil
    checkCancelled()
    local json = require("json")
    local ok, meta = pcall(json.decode, skeleton, json.decode.strict)
    skeleton = nil
    if not ok or type(meta) ~= "table" or meta.type ~= "waveform" or meta.version ~= 1 then
        error("JSON inválido: se necesita una onda Wave2json versión 1.", 0)
    end
    if meta.pointLayout ~= "interleavedMinMax" or type(meta.levels) ~= "table" then
        error("La onda debe contener niveles con pares mínimo/máximo.", 0)
    end
    local best
    for _, level in ipairs(meta.levels) do
        local pm, count = Core.finiteNumber(level.pointMs), Core.finiteNumber(level.points)
        local index = type(level.peaks) == "string" and tonumber(level.peaks:match("^Smart SplitPeaks(%d+)$"))
        if not pm or pm <= 0 or not count or count < 1 or count ~= floor(count) or not index or not arrays[index] then
            error("Un nivel contiene resolución, puntos o picos inválidos.", 0)
        end
        if not best or pm < best.pm then best = {pm=pm, count=count, index=index} end
    end
    if not best then error("La onda no contiene niveles.", 0) end
    local duration = Core.finiteNumber(meta.durationMs)
    local origin = meta.sourceStartMs == nil and 0 or Core.finiteNumber(meta.sourceStartMs)
    if not origin or origin < 0 or not duration or duration <= 0 or
        abs(best.count * best.pm - duration) > best.pm + 0.001 then
        error("La duración o el desplazamiento temporal de la onda es inválido.", 0)
    end
    if meta.sourceEndMs ~= nil then
        local finish = Core.finiteNumber(meta.sourceEndMs)
        if not finish or finish <= origin or abs((finish-origin)-duration) > best.pm + 1 then
            error("El rango de origen no corresponde a la duración de la onda.", 0)
        end
    end
    local array = arrays[best.index]:sub(2, -2)
    arrays, meta = nil, nil
    collectgarbage("collect")
    if array:match("^%s*,") or array:match(",%s*$") or array:match(",%s*,") then
        error("Lista de picos inválida.", 0)
    end
    local prefix, count, pending, sum = {[0]=0}, 0, nil, 0
    for token in array:gmatch("[^,]+") do
        token = trim(token)
        local value = token:match("^%-?%d+$") and Core.finiteNumber(token)
        if not value or value < -32768 or value > 32767 then error("Pico inválido: se requieren enteros s16.", 0) end
        if pending == nil then pending = value else
            if pending > value then error("Un par de picos tiene el mínimo mayor que el máximo.", 0) end
            count = count+1
            sum = sum + max(abs(pending), abs(value))
            prefix[count] = sum
            pending = nil
            if count % 100000 == 0 then progress("Smart Split: leyendo picos...", 15*count/best.count) end
        end
    end
    if pending ~= nil or count ~= best.count then error("La cantidad de pares no coincide con points.", 0) end
    return {prefix=prefix, n=count, point_ms=best.pm, origin=origin, duration=duration}
end


return M

end)()

if depctrl then
    Timing.version = depctrl
    return depctrl:register(Timing)
end
return Timing
