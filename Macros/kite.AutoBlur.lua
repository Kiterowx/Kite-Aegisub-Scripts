script_name = "AutoBlur"
script_description = "Match a sign's \\blur to frame sharpness with fixed or tracked sample points and time-varying blur curves."
script_author = "Kiterow"
script_version = "2.1.4"
script_namespace = "kite.AutoBlur"

local function safeRequire(m)
    local ok, mod = pcall(require, m)
    if ok then return mod end
    return nil
end

local function safeInclude(path)
    if type(include) == "function" then pcall(include, path) end
end

local DependencyControl = safeRequire("l0.DependencyControl")
local depctrl
if DependencyControl then
    local okRecord, record = pcall(DependencyControl, {
        name = script_name,
        description = script_description,
        author = script_author,
        version = script_version,
        namespace = script_namespace,
        feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
        {
            { "kite.Core", version = "1.1.0", url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
              feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
            { "kite.LineOps", version = "1.7.0", url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
              feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
            { "kite.Media", version = "1.4.0", url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
              feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
            { "kite.AssContext", version = "1.1.1" },
            { "kite.UI", version = "1.5.0", url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
              feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
        },
    })
    if okRecord then depctrl = record end
end

local KiteCore, LineOps, Media, AssContext, KiteUI
if depctrl and depctrl.requireModules then
    local ok, coreModule, lineOpsModule, mediaModule, contextModule, uiModule = pcall(function()
        return depctrl:requireModules()
    end)
    if ok then
        KiteCore, LineOps, Media, AssContext, KiteUI = coreModule, lineOpsModule, mediaModule, contextModule, uiModule
    end
end
KiteCore = KiteCore or safeRequire("kite.Core")
LineOps = LineOps or safeRequire("kite.LineOps")
Media = Media or safeRequire("kite.Media")
AssContext = AssContext or safeRequire("kite.AssContext")
KiteUI = KiteUI or safeRequire("kite.UI")

local DataWrapper = safeRequire("a-mo.DataWrapper")
local clipboard = safeRequire("aegisub.clipboard")
safeInclude("karaskel.lua")

local autoSettings = KiteUI.settings(script_namespace, script_version, {
    main = {
        radius = 8,
        max_blur = 5.0,
        curve = 0.5,
        quant_step = 0.25,
        smooth = 5,
        min_run = 3,
        trans_ms = 0,
        mode = "Discrete (RLE transitions)",
        use_tracking = false,
        remove_existing = true,
    },
}, {})

local clamp = KiteCore.clamp

local function extractRGB(color)
    if type(color) ~= "string" then return nil, nil, nil end
    color = color:gsub("%s+", "")
    local b, g, r = color:match("&[Hh](%x%x)(%x%x)(%x%x)&?")
    if b then return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) end
    r, g, b = color:match("#?(%x%x)(%x%x)(%x%x)")
    if r then return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) end
    r, g, b = color:match("(%d+),(%d+),(%d+)")
    if r then
        return clamp(tonumber(r) or 0, 0, 255),
               clamp(tonumber(g) or 0, 0, 255),
               clamp(tonumber(b) or 0, 0, 255)
    end
    return nil, nil, nil
end

local function lum(r, g, b)
    return 0.299 * r + 0.587 * g + 0.114 * b
end

local function formatBlurValue(v)
    local rounded = KiteCore.round(v)
    if math.abs(v - rounded) < 1e-6 then
        return string.format("%d", rounded)
    end
    local s = string.format("%.2f", v)
    s = s:gsub("0+$", "")
    s = s:gsub("%.$", "")
    return s
end

local function pixelLuminance(frame, x, y, vw, vh, cache)
    x = clamp(x, 0, vw - 1)
    y = clamp(y, 0, vh - 1)
    local key = y * vw + x
    local cached = cache[key]
    if cached ~= nil then return cached end
    local color = frame:getPixelFormatted(x, y)
    local r, g, b = extractRGB(color)
    if not r then
        error(string.format("unsupported pixel value at %d,%d: %s", x, y, tostring(color)), 0)
    end
    local value = lum(r, g, b)
    cache[key] = value
    return value
end

local function samplePatchLuminance(frame, cx, cy, radius, vw, vh, cache)
    local luminanceMatrix = {}
    cx = math.floor(cx + 0.5)
    cy = math.floor(cy + 0.5)
    for dy = -radius, radius do
        LineOps.checkCancelled()
        local row = {}
        for dx = -radius, radius do
            row[#row + 1] = pixelLuminance(frame, cx + dx, cy + dy, vw, vh, cache)
        end
        luminanceMatrix[#luminanceMatrix + 1] = row
    end
    return luminanceMatrix
end

local function laplacianVariance(luminanceMatrix)
    local rows = #luminanceMatrix
    if rows < 3 then return 0 end
    local cols = #luminanceMatrix[1]
    if cols < 3 then return 0 end
    local count, mean, deviation = 0, 0, 0
    for y = 2, rows - 1 do
        for x = 2, cols - 1 do
            local value = 4 * luminanceMatrix[y][x] - luminanceMatrix[y - 1][x]
                - luminanceMatrix[y + 1][x] - luminanceMatrix[y][x - 1] - luminanceMatrix[y][x + 1]
            count = count + 1
            local delta = value - mean
            mean = mean + delta / count
            deviation = deviation + delta * (value - mean)
        end
    end
    return count > 0 and deviation / count or 0
end

local function robustMean(values)
    local n = #values
    if n == 0 then return 0 end
    local sorted = {}
    for i, v in ipairs(values) do sorted[i] = v end
    table.sort(sorted)
    local first, last = 1, n
    if n >= 5 then
        first = 2
        last = n - 1
    end
    local sum, count = 0, 0
    for i = first, last do
        sum = sum + sorted[i]
        count = count + 1
    end
    return sum / math.max(1, count)
end

local sampleOffsets = {
    {0, 0},
    {1, 0},
    {-1, 0},
    {0, 1},
    {0, -1},
}

local function sampleSharpness(frame, cx, cy, radius, vw, vh)
    local scores = {}
    local pixelCache = {}
    local spread = math.max(1, radius * 0.75)
    for _, offset in ipairs(sampleOffsets) do
        local luminanceMatrix = samplePatchLuminance(
            frame, cx + offset[1] * spread, cy + offset[2] * spread, radius, vw, vh, pixelCache)
        scores[#scores + 1] = laplacianVariance(luminanceMatrix)
    end
    return robustMean(scores)
end

local function percentile(arr, p)
    local values = {}
    for _, v in ipairs(arr) do
        if type(v) == "number" and v == v then
            values[#values + 1] = v
        end
    end
    local n = #values
    if n == 0 then return 0 end
    table.sort(values)
    if n == 1 then return values[1] end
    local pos = 1 + (n - 1) * clamp(p, 0, 1)
    local lo = math.floor(pos)
    local hi = math.ceil(pos)
    if lo == hi then return values[lo] end
    local t = pos - lo
    return values[lo] * (1 - t) + values[hi] * t
end

local function robustReference(arr)
    local ref = percentile(arr, 0.95)
    if ref > 0 then return ref end
    for _, v in ipairs(arr) do
        if v > ref then ref = v end
    end
    return ref
end

local function blurFromVarianceRelative(v, ref, maxBlur, curve)
    if ref <= 0 then return 0 end
    local ratio = clamp(v / ref, 0, 1)
    return maxBlur * (1 - math.pow(ratio, curve))
end

local function smoothMovingAverage(arr, window)
    if window <= 1 then return arr end
    local n = #arr
    local out = {}
    window = math.max(1, math.floor(tonumber(window) or 1))
    local left = math.floor((window - 1) / 2)
    local right = window - left - 1
    local prefix = {[0] = 0}
    for i = 1, n do prefix[i] = prefix[i - 1] + arr[i] end
    for i = 1, n do
        local first = math.max(1, i - left)
        local last = math.min(n, i + right)
        out[i] = (prefix[last] - prefix[first - 1]) / (last - first + 1)
    end
    return out
end

local function quantize(arr, ref, maxBlur, curve, quantStep)
    local out = {}
    for i, v in ipairs(arr) do
        local raw = blurFromVarianceRelative(v, ref, maxBlur, curve)
        if quantStep and quantStep > 0 then
            raw = math.floor(raw / quantStep + 0.5) * quantStep
        end
        out[i] = clamp(raw, 0, maxBlur)
    end
    return out
end

local function suppressShortRuns(arr, minRunLen)
    if minRunLen <= 1 then return arr end
    local out = {}
    for i = 1, #arr do out[i] = arr[i] end
    local i = 1
    while i <= #out do
        local v = out[i]
        local j = i
        while j <= #out and out[j] == v do j = j + 1 end
        local runLen = j - i
        if runLen < minRunLen then
            local replacement = nil
            if i > 1 then
                replacement = out[i - 1]
            elseif j <= #out then
                replacement = out[j]
            end
            if replacement ~= nil then
                for k = i, j - 1 do out[k] = replacement end
            end
        end
        i = j
    end
    return out
end

local function findRuns(arr)
    local runs = {}
    if #arr == 0 then return runs end
    local cur = arr[1]
    local startIdx = 1
    for i = 2, #arr do
        if arr[i] ~= cur then
            runs[#runs + 1] = {startIdx = startIdx, endIdx = i - 1, value = cur}
            cur = arr[i]
            startIdx = i
        end
    end
    runs[#runs + 1] = {startIdx = startIdx, endIdx = #arr, value = cur}
    return runs
end

local function buildDiscreteTransform(runs, lineStartFrame, lineStartMs, transitionMs)
    if #runs == 0 then return "" end
    local out = {"\\blur" .. formatBlurValue(runs[1].value)}
    for k = 2, #runs do
        local r = runs[k]
        local frameMs = Media.msFromFrame(lineStartFrame + r.startIdx - 1) - lineStartMs
        local half = math.floor(transitionMs / 2)
        local t1 = math.max(0, frameMs - half)
        local t2 = t1 + math.max(1, transitionMs)
        out[#out + 1] = string.format("\\t(%d,%d,\\blur%s)", t1, t2, formatBlurValue(r.value))
    end
    return table.concat(out)
end

local function firstOverrideBlock(text)
    for _, section in ipairs(LineOps.scanSections(text)) do
        if section.type == "override" then return section.start, section.finish end
        if section.type == "text" or section.type == "drawing" then return nil end
    end
end

local function stripBlurFromFirstBlock(text)
    local first, last = firstOverrideBlock(text)
    if not first then return text end
    local block = LineOps.removeTagCalls(text:sub(first, last), {blur = true, be = true})
    local removed
    repeat
        block, removed = LineOps.mapTagCalls(block, {t = true}, function(call)
            if not call.value:find("\\", 1, true) then return false end
        end, {top_level_only = false})
    until removed == 0
    if block:match("^%{%s*%}$") then block = "" end
    return text:sub(1, first - 1) .. block .. text:sub(last + 1)
end

local function injectTransform(text, transform)
    if transform == "" then return text end
    local _, last = firstOverrideBlock(text)
    if last then return text:sub(1, last - 1) .. transform .. text:sub(last) end
    return LineOps.prependTag(text, transform)
end

local function getPlayRes(subs)
    if karaskel and type(karaskel.collect_head) == "function" then
        local ok, meta = pcall(karaskel.collect_head, subs, false)
        if ok and meta and meta.res_x and meta.res_y then
            return tonumber(meta.res_x), tonumber(meta.res_y)
        end
    end
    return nil, nil
end

local function getVideoSize()
    if aegisub.video_size then
        local ok, w, h = pcall(aegisub.video_size)
        w, h = tonumber(w), tonumber(h)
        if ok and w and h and w > 0 and h > 0 then return w, h end
    end
    local props = aegisub.project_properties() or {}
    local vw = tonumber(props.video_width)
    local vh = tonumber(props.video_height)
    if vw and vh and vw > 0 and vh > 0 then return vw, vh end
    return nil, nil
end
local function firstVectorClipPoint(text)
    for _, call in ipairs(LineOps.tagCalls(text, {clip = true, iclip = true})) do
        if call.top_level then
            local inner = call.value:sub(2, -2)
            local scale, path = inner:match("^%s*(%d+)%s*,%s*(.*)$")
            if not path then path, scale = inner, "1" end
            local x, y = path:match("^%s*[mM]%s+([%+%-]?%d*%.?%d+)%s+([%+%-]?%d*%.?%d+)")
            scale = tonumber(scale)
            x, y = KiteCore.finiteNumber(x), KiteCore.finiteNumber(y)
            if x and y and scale and scale >= 1 and scale == math.floor(scale) then
                local divisor = 2 ^ (scale - 1)
                if KiteCore.finiteNumber(divisor) then return x / divisor, y / divisor end
            end
        end
    end
end

local function autoDetectCoord(subs, line, currentMs)
    local x, y = firstVectorClipPoint(line.text)
    if x then return x, y end
    x, y = AssContext.explicitPosition(line.text, line.end_time - line.start_time, currentMs - line.start_time)
    if x then return x, y end
    if clipboard and clipboard.get then
        local ok, data = pcall(clipboard.get)
        if ok and type(data) == "string" then
            x, y = data:match("([%-%d%.]+),([%-%d%.]+)")
            if x then return x, y end
        end
    end
    return AssContext.defaultPosition(line, {sub = subs})
end

local function readClipboardData()
    if not (clipboard and clipboard.get) then return "" end
    local ok, data = pcall(clipboard.get)
    if ok and type(data) == "string" then return data end
    return ""
end

local function showDialog(initialCoord, initialData, defaults)
    defaults = defaults or {}
    local dlg = {
        {class = "label", x = 0, y = 0, width = 9, height = 1,
         label = "AutoBlur"},

        {class = "label", x = 0, y = 1, width = 9,
         label = "BG sample point  x,y  (auto-filled from \\clip pin, \\pos, \\move, clipboard, or style):"},
        {class = "edit", name = "coord", x = 0, y = 2, width = 9, value = initialCoord or ""},

        {class = "label", x = 0, y = 3, width = 9,
         label = "Tracking data  (paste AE Position export - optional):"},
        {class = "textbox", name = "data", x = 0, y = 4, width = 9, height = 4,
         text = initialData or ""},

        {class = "label", x = 0, y = 8, width = 3, label = "Patch radius (px):"},
        {class = "intedit", name = "radius", x = 3, y = 8, width = 2,
         value = defaults.radius or 8, min = 2},
        {class = "label", x = 5, y = 8, width = 2, label = "Max blur:"},
        {class = "floatedit", name = "max_blur", x = 7, y = 8, width = 2,
         value = defaults.max_blur or 5.0, min = 0},

        {class = "label", x = 0, y = 9, width = 3, label = "Curve exponent:"},
        {class = "floatedit", name = "curve", x = 3, y = 9, width = 2,
         value = defaults.curve or 0.5, min = 0},
        {class = "label", x = 5, y = 9, width = 2, label = "Quant step:"},
        {class = "floatedit", name = "quant_step", x = 7, y = 9, width = 2,
         value = defaults.quant_step or 0.25, min = 0},

        {class = "label", x = 0, y = 10, width = 3, label = "Smooth window (frames):"},
        {class = "intedit", name = "smooth", x = 3, y = 10, width = 2,
         value = defaults.smooth or 5, min = 1},
        {class = "label", x = 5, y = 10, width = 2, label = "Min run (frames):"},
        {class = "intedit", name = "min_run", x = 7, y = 10, width = 2,
         value = defaults.min_run or 3, min = 1},

        {class = "label", x = 0, y = 11, width = 3, label = "Transition (ms):"},
        {class = "intedit", name = "trans_ms", x = 3, y = 11, width = 2,
         value = defaults.trans_ms or 0, min = 0},
        {class = "label", x = 5, y = 11, width = 4,
         label = "0 = step / e.g. 80 = soft fade between levels"},

        {class = "label", x = 0, y = 12, width = 2, label = "Mode:"},
        {class = "dropdown", name = "mode", x = 2, y = 12, width = 7,
         items = {"Discrete (RLE transitions)", "Continuous (per-frame \\t)"},
         value = defaults.mode or "Discrete (RLE transitions)"},

        {class = "checkbox", name = "use_tracking", x = 0, y = 13, width = 9,
         label = "Use tracking data (off = sample stays at the fixed coord above)",
         value = defaults.use_tracking or false},
        {class = "checkbox", name = "remove_existing", x = 0, y = 14, width = 9,
         label = "Strip existing \\blur / \\be / \\t(blur) from first tag block before applying",
         value = defaults.remove_existing ~= false},
    }
    return aegisub.dialog.display(dlg, {"Execute", "Cancel"}, {ok = "Execute", close = "Cancel"})
end

local function showError(msg)
    return KiteUI.message(msg)
end
local function main(subs, sel)
    if not KiteCore or not LineOps or not Media or not AssContext
        or type(LineOps.selectedLines) ~= "function" or type(LineOps.transaction) ~= "function"
        or type(Media.frameFromMs) ~= "function" or type(Media.msFromFrame) ~= "function"
        or type(Media.exclusiveEndFrame) ~= "function" then
        showError("Missing compatible kite.Core, kite.LineOps, or kite.Media modules.")
        return
    end
    if not aegisub.get_frame or not aegisub.frame_from_ms or not aegisub.ms_from_frame then
        showError("Need an Aegisub fork with frame access and loaded timecodes.")
        return
    end
    local props = aegisub.project_properties() or {}
    if not props.video_file or props.video_file == "" then
        showError("No video open.")
        return
    end
    if #sel ~= 1 then
        showError("Select exactly one line.")
        return
    end

    local records = LineOps.selectedLines(subs, sel, function(candidate)
        return type(candidate) == "table" and candidate.class == "dialogue"
    end, true)
    if not records or #records ~= 1 then
        showError("Select exactly one dialogue line.")
        return
    end
    local selectedIndex = records[1].index
    local line = records[1].line
    local startMs = tonumber(line.start_time)
    local endMs = tonumber(line.end_time)
    if not startMs or not endMs or endMs <= startMs then
        showError("Line has zero or negative duration.")
        return
    end
    local startFrame = Media.frameFromMs(startMs)
    local endFrame = Media.exclusiveEndFrame(startMs, endMs)
    if not startFrame or not endFrame then
        showError("Could not map the selected line to loaded video frames.")
        return
    end
    local currentFrame = tonumber(props.video_position) or startFrame
    if currentFrame < startFrame or currentFrame >= endFrame then
        showError("Move the video playhead inside the line first.\n(The current frame is the reference for tracking offsets and the BG color.)")
        return
    end

    local currentMs = Media.msFromFrame(currentFrame)
    if not currentMs then
        showError("Could not map the current video frame to milliseconds.")
        return
    end
    local autoX, autoY = autoDetectCoord(subs, line, currentMs)
    local initialCoord = (autoX and (autoX .. "," .. autoY)) or ""
    local clipboardData = readClipboardData()
    if not clipboardData:find("\n") then clipboardData = "" end

    local res, cx, cy
    local defaults = autoSettings:values("main")
    while true do
        local button
        button, res = showDialog(initialCoord, clipboardData, defaults)
        if button ~= "Execute" then return sel end
        cx, cy = tostring(res.coord or ""):match(
            "^%s*([%+%-]?%d*%.?%d+)%s*,%s*([%+%-]?%d*%.?%d+)%s*$")
        cx, cy = KiteCore.finiteNumber(cx), KiteCore.finiteNumber(cy)
        local problem
        if not cx or not cy then problem = "Invalid coordinate. Format: x,y (e.g. 960,540)." end
        local minimums = {radius = 2, max_blur = 0, curve = 0, quant_step = 0, smooth = 1, min_run = 1, trans_ms = 0}
        for name, minimum in pairs(minimums) do
            local value = KiteCore.finiteNumber(res[name])
            if not value or value < minimum or (name == "curve" and value == 0) then
                problem = "Invalid value: " .. name .. ". Use a finite number within the field's range."
            end
        end
        if res.use_tracking and tostring(res.data or ""):match("^%s*$") then
            problem = "Paste tracking data or disable Use tracking data."
        elseif res.use_tracking and not DataWrapper then
            problem = "Install a-mo.DataWrapper to read tracking data, or disable Use tracking data."
        end
        if not problem then break end
        showError(problem)
        initialCoord, clipboardData, defaults = res.coord, res.data, res
    end

    local numFrames = endFrame - startFrame
    if numFrames < 1 then
        showError("Not enough frames.")
        return
    end

    local vw, vh = getVideoSize()
    if not vw or not vh then
        showError("Could not obtain the loaded video's dimensions.")
        return
    end
    local prx, pry = getPlayRes(subs)
    local positions = {x = {}, y = {}}
    if res.use_tracking and res.data and res.data ~= "" then
        if not DataWrapper then
            showError("a-mo.DataWrapper not installed; cannot parse tracking data.\nInstall Aegisub-Motion or disable 'Use tracking data'.")
            return
        end
        local tdata = DataWrapper()
        local parseW = prx and prx > 0 and prx or vw
        local parseH = pry and pry > 0 and pry or vh
        local parseOk, parsed = pcall(tdata.bestEffortParsingAttempt, tdata, res.data, parseW, parseH)
        if not parseOk or not parsed or type(tdata.dataObject) ~= "table" then
            showError("Could not parse tracking data. Expected After Effects Position export.")
            return
        end
        local lengthOk, lengthMatches = pcall(tdata.dataObject.checkLength, tdata.dataObject, numFrames)
        if not lengthOk or not lengthMatches then
            showError(string.format(
                "Tracking data length (%d frames) doesn't match line length (%d frames).",
                tonumber(tdata.dataObject.length) or 0, numFrames))
            return
        end
        local referenceOk = pcall(tdata.dataObject.addReferenceFrame, tdata.dataObject, currentFrame - startFrame + 1)
        if not referenceOk then
            showError("Tracking data could not set the selected reference frame.")
            return
        end
        local d = tdata.dataObject
        if type(d.xPosition) ~= "table" or type(d.yPosition) ~= "table"
            or not KiteCore.finiteNumber(d.xStartPosition) or not KiteCore.finiteNumber(d.yStartPosition) then
            showError("Tracking data has no usable position channels.")
            return
        end
        local xStart, yStart = tonumber(d.xStartPosition), tonumber(d.yStartPosition)
        for i = 1, numFrames do
            local trackedX, trackedY = KiteCore.finiteNumber(d.xPosition[i]), KiteCore.finiteNumber(d.yPosition[i])
            if not trackedX or not trackedY then
                showError(string.format("Tracking data is missing a position at frame %d.", i))
                return
            end
            positions.x[i] = cx + (trackedX - xStart)
            positions.y[i] = cy + (trackedY - yStart)
        end
    else
        for i = 1, numFrames do
            positions.x[i] = cx
            positions.y[i] = cy
        end
    end

    local sx = (prx and prx > 0) and (vw / prx) or 1
    local sy = (pry and pry > 0) and (vh / pry) or 1

    local radius = math.max(2, math.floor(tonumber(res.radius) or 8))
    local variances = {}
    aegisub.progress.task("AutoBlur: sampling frames")
    for i = 1, numFrames do
        if aegisub.progress.is_cancelled and aegisub.progress.is_cancelled() then
            return
        end
        local f = startFrame + i - 1
        local ok, frame = pcall(aegisub.get_frame, f, false)
        if not ok or not frame then
            showError(string.format("Could not read video frame %d; no subtitle changes were made.", f))
            return
        end
        local px = positions.x[i] * sx
        local py = positions.y[i] * sy
        local sampleOk, score = pcall(sampleSharpness, frame, px, py, radius, vw, vh)
        if not sampleOk or type(score) ~= "number" or score ~= score then
            showError(string.format(
                "Could not sample video frame %d: %s\nNo subtitle changes were made.",
                f, tostring(score or "invalid sharpness result")))
            return
        end
        variances[i] = score
        aegisub.progress.set((i / numFrames) * 100)
    end
    aegisub.progress.task("AutoBlur: building transforms")

    local smoothWindow = math.max(1, math.floor(tonumber(res.smooth) or 5))
    local smoothed = smoothMovingAverage(variances, smoothWindow)
    local ref = robustReference(smoothed)
    if ref <= 0 then
        showError("All sampled frames returned zero variance.\nCheck the sample coordinate / patch radius.")
        return
    end
    aegisub.log("AutoBlur: reference variance = %.2f\n", ref)

    local maxBlur = math.max(0, tonumber(res.max_blur) or 5.0)
    local curve = tonumber(res.curve)
    local quantStep = math.max(0, tonumber(res.quant_step) or 0.25)
    local transitionMs = math.max(0, math.floor(tonumber(res.trans_ms) or 0))
    local quantized = quantize(smoothed, ref, maxBlur, curve, quantStep)

    local transform
    if res.mode and res.mode:find("Continuous") then
        transform = buildDiscreteTransform(findRuns(quantized), startFrame, line.start_time, transitionMs)
    else
        local minRun = math.max(1, math.floor(tonumber(res.min_run) or 3))
        local cleaned = suppressShortRuns(quantized, minRun)
        local runs = findRuns(cleaned)
        transform = buildDiscreteTransform(runs, startFrame, line.start_time, transitionMs)
    end

    local newText = res.remove_existing and stripBlurFromFirstBlock(line.text) or line.text
    line = KiteCore.copy(line)
    line.text = injectTransform(newText, transform)
    LineOps.transaction(subs, script_name, function()
        LineOps.checkCancelled()
        subs[selectedIndex] = line
    end)
    local settingsOk, saved, settingsError = pcall(function()
        autoSettings:update("main", res)
        return autoSettings:write()
    end)
    if (not settingsOk or not saved) and aegisub.log then
        aegisub.log("AutoBlur: could not persist settings: %s\n", tostring(settingsOk and settingsError or saved))
    end
    return {selectedIndex}, selectedIndex
end

local function canRun(subs, sel)
    return sel and #sel == 1
end

if aegisub and aegisub.register_macro then
    if depctrl and depctrl.registerMacro then
        depctrl:registerMacro(script_name, script_description, main, canRun, nil, false)
    else
        aegisub.register_macro(script_name, script_description, main, canRun)
    end
end

require("kite.UI").publishActions()
