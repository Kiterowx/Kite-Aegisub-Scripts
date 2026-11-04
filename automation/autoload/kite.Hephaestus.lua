local function initializeScript()
package.preload["Yutils"] = function() return require("tstools.Yutils") end

script_name = "Hephaestus Fansubber"
script_description = "Auto Blur, Motion, Mask, Drawing and Timing, with shared installation and diagnostics."
script_author = "Kiterow"
script_version = "1.2.1"
script_namespace = "kite.Hephaestus"

local DependencyControl = require("l0.DependencyControl")
local dependencies = DependencyControl({
    feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    {
        {"tstools.Yutils", version="1.0.0", feed="https://raw.githubusercontent.com/TypesettingTools/Yutils/master/DependencyControl.json"},
        {"ZF.main", version="2.3.0", feed="https://raw.githubusercontent.com/TypesettingTools/zeref-Aegisub-Scripts/main/DependencyControl.json"},
        {"aka.command", version="1.0.2", feed="https://raw.githubusercontent.com/Akatmks/Akatsumekusa-Aegisub-Scripts/master/DependencyControl.json"},
        {"kite.AssContext", version="2.0.1", feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.Automatons", version="1.2.1", feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.Core", version="2.0.0", feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.MotionEngine", version="3.8.2", feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.PyBridge", version="2.0.1", feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.ShapeOptimizer", version="2.0.1", feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.Timing", version="1.5.0", feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.UI", version="2.0.2", feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
    }
})
dependencies:requireModules()

local Automatons = require("kite.Automatons")

local function registerAutoBlur(record)
    local script_name = "Auto Blur"
    local script_description = "Match a sign's \\blur to frame sharpness with fixed or tracked sample points and time-varying blur curves."
    local script_version = "2.2.0"
    local script_namespace = "kite.AutoBlur"

    local function safeRequire(m)
        local ok, mod = pcall(require, m)
        if ok then return mod end
        return nil
    end

    local function safeInclude(path)
        if type(include) == "function" then pcall(include, path) end
    end

    local depctrl = record
    local KiteCore = require("kite.Core")
    local LineOps = KiteCore.LineOps
    local Media = require("kite.PyBridge").Media
    local AssContext = require("kite.AssContext")
    local KiteUI = require("kite.UI")

    local DataWrapper
    local function loadTracking()
        if not DataWrapper then
            DataWrapper = depctrl:requireModules({
                {moduleName = "a-mo.DataWrapper", version = "1.0.2", feed = "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"}
            })
        end
        return DataWrapper
    end
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
            showError("Missing compatible kite.Core, kite.Core.LineOps, or kite.PyBridge.Media modules.")
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
            elseif res.use_tracking and not DataWrapper and not problem then
                local loaded, message = pcall(loadTracking)
                if not loaded then problem = tostring(message) end
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
        require("kite.Automatons").register("autoblur", {{"",script_description,main,canRun,backend=false,oldPaths={"AutoBlur"}}},script_namespace,depctrl)
    end
end

local function registerAutoMotion(record)
    local script_description = "Seguimiento de Ã¡rea con CPU/CUDA, aplicaciÃ³n AE y biblioteca JSON junto al proyecto."
    local script_namespace = "kite.AutoMotion"

    local dependencies = record
    local Bridge = require("kite.PyBridge")
    local Lines = require("kite.Core").LineOps
    local Media = require("kite.PyBridge").Media
    local Json = require("l0.dkjson")
    local Copy = Lines.deepCopy
    local DATA_KEY, LINK_KEY = "_kite_automotion_v1", "_kite_automotion_source"
    local Olympus = require("kite.Automatons")
    local Engine
    local AutoMotion = {}

    local function Check(value, message)
        if not value then error(message, 0) end
        return value
    end

    local function Notice(message)
        aegisub.dialog.display({{class="textbox", text=tostring(message), x=0, y=0, width=64, height=9}}, {"Cerrar"})
    end

    local function LoadEngine()
        if not Engine then Engine = require("kite.MotionEngine") end
        Check(type(Engine) == "table" and Engine.api_version == 1 and type(Engine.ApplyTransformTrack) == "function",
            "La versiÃ³n del motor de motion no es compatible con AutoMotion.")
        return Engine
    end

    local function Decode(text)
        local value, _, message = Json.decode(text, 1, nil)
        Check(type(value) == "table", "Datos de AutoMotion daÃ±ados: " .. tostring(message or "JSON invÃ¡lido"))
        return value
    end

    local function LegacyRecords(subs)
        local records = {}
        for i = 1, #subs do
            local line = subs[i]
            local value = line.class == "dialogue" and line.comment and line.extra and line.extra[DATA_KEY]
            if value then
                local record = Decode(value)
                Check(record.version == 1 and type(record.id) == "string" and type(record.ae) == "string"
                    and type(record.sources) == "table", "Registro de AutoMotion no compatible en la lÃ­nea " .. i)
                record.index = i
                records[#records + 1] = record
            end
        end
        return records
    end

    local function LibraryPaths()
        local folder = Check(Lines.subtitleFolder(true), "Guarda primero el archivo ASS para crear su biblioteca de AutoMotion.")
        return {data=Bridge.joinPath(folder, "AutoMotion Library"),
            index=Bridge.joinPath(folder, "AutoMotion Library.index.json")}
    end

    local function RecordPath(paths, id)
        Check(type(id) == "string" and #id <= 96 and id:match("^[%w][%w_.-]*$")
            and not id:find("..", 1, true), "Identificador de motion no vÃ¡lido.")
        return Bridge.joinPath(paths.data, id .. ".json")
    end

    local function LoadIndex(paths)
        if not Bridge.fileExists(paths.index) then
            return {format="kite.automotion.index", version=1, entries=setmetatable({}, {__jsontype="array"})}
        end
        local index = Decode(Check(Bridge.readFile(paths.index), "No se pudo leer el Ã­ndice de AutoMotion."))
        Check(index.format == "kite.automotion.index" and index.version == 1 and type(index.entries) == "table",
            "El Ã­ndice de AutoMotion no es compatible.")
        local seen = {}
        for _, entry in ipairs(index.entries) do
            RecordPath(paths, entry.id)
            Check(not seen[entry.id], "El Ã­ndice contiene un motion duplicado.")
            seen[entry.id] = true
        end
        return index
    end

    local function Records()
        local paths, records = LibraryPaths(), {}
        for _, entry in ipairs(LoadIndex(paths).entries) do
            local path = RecordPath(paths, entry.id)
            local record = Decode(Check(Bridge.readFile(path), "No se pudo leer el motion: " .. path))
            Check(record.format == "kite.automotion.motion" and record.version == 1 and record.id == entry.id
                and type(record.ae) == "string" and type(record.sources) == "table", "JSON de motion no vÃ¡lido: " .. path)
            records[#records + 1] = record
        end
        return records
    end

    local function SaveRecord(record, remove)
        local paths = LibraryPaths()
        local index = LoadIndex(paths)
        local path = RecordPath(paths, record.id)
        local oldIndex = Bridge.fileExists(paths.index) and Check(Bridge.readFile(paths.index), "No se pudo leer el Ã­ndice.") or nil
        local oldRecord = Bridge.fileExists(path) and Check(Bridge.readFile(path), "No se pudo leer el motion anterior.") or nil
        local position
        for i, entry in ipairs(index.entries) do if entry.id == record.id then position = i; break end end
        if remove then
            Check(position, "El motion ya no estÃ¡ en la biblioteca.")
            table.remove(index.entries, position)
        else
            local made, message = Bridge.ensureDir(paths.data)
            Check(made, "No se pudo crear la biblioteca: " .. tostring(message))
            local entry = {id=record.id, name=record.name}
            if position then index.entries[position] = entry else index.entries[#index.entries + 1] = entry end
        end
        setmetatable(index.entries, {__jsontype="array"})
        local saved = Copy(record)
        saved.index, saved.format = nil, "kite.automotion.motion"
        local indexText, recordText = Json.encode(index), not remove and Json.encode(saved) or nil
        local ok, message = pcall(function()
            if not remove then
                local wrote, why = Bridge.writeFile(path, recordText)
                Check(wrote, "No se pudo guardar el motion: " .. tostring(why))
            end
            local wrote, why = Bridge.writeFile(paths.index, indexText)
            Check(wrote, "No se pudo guardar el Ã­ndice: " .. tostring(why))
            if remove then
                local deleted, reason = Bridge.removeFile(path)
                Check(deleted, "No se pudo borrar el JSON: " .. tostring(reason))
            end
        end)
        if not ok then
            local failures = {}
            for _, file in ipairs({{path, oldRecord}, {paths.index, oldIndex}}) do
                local restored, why
                if file[2] then restored, why = Bridge.writeFile(file[1], file[2])
                else restored, why = Bridge.removeFile(file[1]) end
                if not restored then failures[#failures + 1] = file[1] .. ": " .. tostring(why) end
            end
            error(tostring(message) .. (#failures > 0 and ("\nNo se pudo restaurar: " .. table.concat(failures, "\n")) or ""), 0)
        end
    end

    local function MigrateLegacy(subs, selection)
        local legacy = LegacyRecords(subs)
        if #legacy == 0 then return selection end
        local existing = {}
        for _, record in ipairs(Records()) do existing[record.id] = true end
        for _, record in ipairs(legacy) do if not existing[record.id] then SaveRecord(record) end end
        return Lines.transaction(subs, "AutoMotion: migrar biblioteca a JSON", function()
            local selected = Copy(selection)
            for i = #legacy, 1, -1 do
                local deleted = legacy[i].index
                subs.delete(deleted)
                for j = #selected, 1, -1 do
                    if selected[j] == deleted then table.remove(selected, j)
                    elseif selected[j] > deleted then selected[j] = selected[j] - 1 end
                end
            end
            return selected
        end)
    end

    local function Selection(subs, selection)
        local engine = LoadEngine()
        local window, message = engine.SelectionWindow(subs, selection)
        Check(window, message)
        for _, i in ipairs(window.indices) do
            Check(not (subs[i].extra and subs[i].extra[LINK_KEY]),
                "La selecciÃ³n ya contiene AutoMotion. Usa Â«Quitar motion de la selecciÃ³nÂ» antes de volver a aplicarlo.")
        end
        return window
    end

    local function BuildRequest(subs, selection)
        LibraryPaths()
        local window = Selection(subs, selection)
        Check(window.frame_count >= 2, "Selecciona al menos dos fotogramas.")
        Check(window.frame_count <= 5000, "La selecciÃ³n supera 5000 fotogramas. Divide el seguimiento por escenas.")
        local video = Check(Media.projectPath("video"), "Carga un vÃ­deo real en Aegisub.")
        local centers = {}
        for frame = window.start_frame, window.end_frame - 1 do
            local a, b = aegisub.ms_from_frame(frame), aegisub.ms_from_frame(frame + 1)
            Check(a and b and b > a, "Los timecodes del vÃ­deo no son vÃ¡lidos.")
            centers[#centers + 1] = (a + b) / 2
        end
        local fps = window.frame_count * 1000 / (aegisub.ms_from_frame(window.end_frame) - aegisub.ms_from_frame(window.start_frame))
        return {version=1, video=video, start_frame=window.start_frame,
            reference=LoadEngine().ReferenceRowForWindow(window) - 1, centers_ms=centers, fps=fps,
            name="Motion " .. ( #Records(subs) + 1 ) .. " Â· f" .. window.start_frame}, window
    end

    local function RunBackend(request)
        Check(Bridge.available, "AutoMotion necesita aka.command y kite.PyBridge.")
        local Python = Olympus.python()
        Check(Python ~= "" and Bridge.fileExists(Python), Olympus.missing("automotion"))
        local paths, pathError = Bridge.tempPaths("automotion", {request=".request.json", result=".result.json"})
        Check(paths, pathError)
        local ok, result = pcall(function()
            Check(Bridge.writeFile(paths.request, Json.encode(request)), "No se pudo escribir la solicitud temporal.")
            aegisub.progress.title("AutoMotion")
            aegisub.progress.task("Selecciona el Ã¡rea en la ventana de AutoMotion. DespuÃ©s se calcularÃ¡ el motion con CPU o CUDA segÃºn la configuraciÃ³n de Hephaestus.")
            local success, diagnostic, code = Bridge.runProcess({executable=Python,
                args=Olympus.arguments("automotion", {"--request", paths.request, "--result", paths.result})})
            if code == 130 then return {status="cancelled"} end
            local text = Bridge.readFile(paths.result)
            Check(text, "No se recibiÃ³ respuesta de AutoMotion.\n" .. tostring(diagnostic))
            local response = Decode(text)
            if response.status == "cancelled" then return response end
            Check(success and response.status == "ok", response.message or diagnostic or "El seguimiento fallÃ³.")
            return response
        end)
        Bridge.cleanup(paths)
        Bridge.removeFile(paths.result .. ".partial")
        Bridge.removeFile(paths.request .. ".partial")
        if not ok then error(result, 0) end
        return result
    end

    local function ValidateRecord(record)
        Check(record.version == 1 and record.count and record.count >= 2 and record.count <= 5000
            and record.count == math.floor(record.count), "NÃºmero de muestras no vÃ¡lido.")
        Check(record.reference and record.reference >= 0 and record.reference < record.count
            and record.reference == math.floor(record.reference), "Referencia fuera del motion.")
        local track, message = LoadEngine().ParseInput(record.ae)
        Check(track and track.kind == "transform", message or "El backend no devolviÃ³ motion AE.")
        Check(#track.samples == record.count and not track.has_interpolation and not track.has_ambiguous_rotation,
            "El motion AE no contiene una muestra continua por fotograma.")
        return track
    end

    local function Apply(subs, selection, record, origin, reference)
        local engine = LoadEngine()
        local window = Selection(subs, selection)
        local track = ValidateRecord(record)
        Check(window.start_frame >= origin and window.end_frame <= origin + record.count,
            "La selecciÃ³n sale del intervalo del motion. Alinea al inicio de la selecciÃ³n o selecciona su intervalo original.")
        window.start_frame = origin
        window.end_frame = origin + record.count
        window.frame_count = record.count
        local options = Copy(engine.DEFAULTS)
        options.reference_frame = reference + 1
        options.optimize_linear, options.optimize_fbf = false, false
        options.cleanup_mode, options.phase_mode = "Off", "Off"
        options.strict_geometry, options.scale_to_script, options.use_source_meta = true, true, true
        options.preserve_perspective = true
        options.mapping_mode = "Selection timeline"
        record = Copy(record)
        local preservedPerspective
        local selected = Lines.transaction(subs, "AutoMotion: " .. record.name, function()
            local firstSource = #record.sources + 1
            for offset, index in ipairs(window.indices) do
                local sourceId = firstSource + offset - 1
                local line = Copy(subs[index])
                record.sources[sourceId] = Copy(line)
                line.extra = Copy(line.extra or {})
                line.extra[LINK_KEY] = record.id .. ":" .. sourceId
                subs[index] = line
            end
            local applied, report = engine.ApplyTransformTrack(subs, window, track, options)
            Check(applied, report or "No se generaron lÃ­neas.")
            Lines.checkCancelled()
            SaveRecord(record)
            preservedPerspective = report.preserved_perspective
            return report.selection
        end)
        if preservedPerspective and #preservedPerspective > 0 then
            Notice("AutoMotion Â· Aviso\n\nMovimiento aplicado. Se conservaron los valores de \\fax, \\fay, \\frx y \\fry "
                .. "sin recalcular la perspectiva; \\pos y \\org siguen el movimiento.\n\nLÃ­neas: "
                .. table.concat(preservedPerspective, ", ") .. ".")
        end
        return selected
    end

    local function Generate(subs, selection)
        local request = BuildRequest(subs, selection)
        local response = RunBackend(request)
        if response.status == "cancelled" then return selection end
        Check(response.start_frame == request.start_frame and response.count == #request.centers_ms
            and response.reference == request.reference, "La respuesta no coincide con la selecciÃ³n enviada.")
        Check(response.gpu and (response.gpu.device == "cuda" or response.gpu.device == "cpu") and response.gpu.refinement_frames == response.count - 1,
            "El backend no confirmÃ³ el refinamiento de todos los fotogramas.")
        response.id, response.sources, response.created = Bridge.uniqueSuffix(), {}, os.date("%Y-%m-%d %H:%M")
        response.status = nil
        return Apply(subs, selection, response, response.start_frame, response.reference)
    end

    local function Restore(subs, selection, record, removeRecord)
        local selected, groups = {}, {}
        if selection then for _, index in ipairs(selection) do selected[index] = true end end
        for i = 1, #subs do
            local line = subs[i]
            local link = line.class == "dialogue" and line.extra and line.extra[LINK_KEY]
            if link then
                local id, sourceId = link:match("^(.*):(%d+)$")
                if id == record.id then
                    sourceId = tonumber(sourceId)
                    Check(record.sources[sourceId], "Falta la lÃ­nea original de este motion.")
                    local group = groups[sourceId] or {indices={}, selected=false}
                    group.indices[#group.indices + 1] = i
                    group.selected = group.selected or not selection or selected[i]
                    groups[sourceId] = group
                end
            end
        end
        local actions = {}
        for sourceId, group in pairs(groups) do
            if group.selected then
                for _, index in ipairs(group.indices) do
                    Check(not selection or selected[index], "Selecciona todos los fragmentos de cada lÃ­nea que quieras restaurar.")
                    actions[#actions + 1] = {index=index, original=index == group.indices[1] and record.sources[sourceId] or nil}
                end
            end
        end
        table.sort(actions, function(a, b) return a.index > b.index end)
        return Lines.transaction(subs, "AutoMotion: restaurar originales", function()
            local restored = {}
            for _, action in ipairs(actions) do
                if action.original then
                    subs[action.index] = Copy(action.original)
                    restored[#restored + 1] = action.index
                else
                    subs.delete(action.index)
                    for j, index in ipairs(restored) do if index > action.index then restored[j] = index - 1 end end
                end
            end
            table.sort(restored)
            Lines.checkCancelled()
            if removeRecord then SaveRecord(record, true) end
            if #restored == 0 then
                for i = 1, #subs do if subs[i].class == "dialogue" then return {i} end end
            end
            return restored
        end)
    end

    local function History(subs, selection)
        local records = Records(subs)
        if #records == 0 then Notice("Este proyecto no tiene motions guardados."); return selection end
        local labels, byLabel = {}, {}
        for _, record in ipairs(records) do
            local label = string.format("%d. %s Â· f%dâ€“%d Â· %s", #labels + 1, record.name, record.start_frame,
                record.start_frame + record.count - 1, record.created or "")
            labels[#labels + 1], byLabel[label] = label, record
        end
        local button, values = aegisub.dialog.display({
            {class="label", label="Biblioteca JSON junto al ASS. Reaplicar utiliza sus valores AE sin recalcular.", x=0,y=0,width=9,height=1},
            {class="dropdown", name="motion", items=labels, value=labels[1], x=0,y=1,width=9,height=1},
            {class="label", label="SincronizaciÃ³n", x=0,y=2,width=2,height=1},
            {class="dropdown", name="mapping", items={"Fotogramas originales", "Alinear al inicio de la selecciÃ³n"},
                value="Fotogramas originales", x=2,y=2,width=7,height=1},
            {class="label", label="Borrar restaura las lÃ­neas de este proyecto y elimina el JSON de la biblioteca.\nTambiÃ©n reemplaza sus ediciones posteriores. Ctrl+Z deshace las lÃ­neas, pero no el borrado del JSON.", x=0,y=3,width=9,height=2},
        }, {"Reaplicar", "Borrar y restaurar", "Cerrar"}, {ok="Reaplicar", close="Cerrar"})
        if button == "Cerrar" or not values then return selection end
        local record = Check(byLabel[values.motion], "Selecciona un motion.")
        if button == "Borrar y restaurar" then return Restore(subs, nil, record, true) end
        if button ~= "Reaplicar" then return selection end
        local window = Selection(subs, selection)
        local origin = record.start_frame
        if values.mapping == "Alinear al inicio de la selecciÃ³n" then
            origin = window.start_frame
        else
            local video = Media.projectPath("video")
            if video and record.source then
                local name = video:match("[^/\\]+$")
                Check(name == record.source.name and Bridge.fileSize(video) == record.source.size,
                    "El vÃ­deo es distinto al del motion. Elige Â«Alinear al inicio de la selecciÃ³nÂ» para reutilizarlo expresamente.")
            end
        end
        return Apply(subs, selection, record, origin, record.reference)
    end

    local function RemoveSelected(subs, selection)
        local ids = {}
        for _, index in ipairs(selection) do
            local line = subs[index]
            local link = line.extra and line.extra[LINK_KEY]
            if link then ids[link:match("^(.*):%d+$")] = true end
        end
        local id = next(ids)
        Check(id and not next(ids, id), "Selecciona fragmentos de un solo motion para restaurar sus originales.")
        for _, record in ipairs(Records(subs)) do
            if record.id == id then return Restore(subs, selection, record, false) end
        end
        error("No se encontrÃ³ el JSON de este motion en la biblioteca junto al ASS.", 0)
    end

    local function Guard(callback)
        return function(subs, selection, active)
            local ok, result = pcall(function()
                selection = MigrateLegacy(subs, selection)
                return callback(subs, selection, active)
            end)
            if ok then return result end
            if aegisub.progress.is_cancelled() then aegisub.cancel() end
            Notice("AutoMotion\n\n" .. tostring(result))
            return selection
        end
    end

    Olympus.register("automotion", {
        {"Generar y aplicar",script_description,Guard(Generate),oldPaths={"AutoMotion/Generar y aplicar"}},
        {"Historial del proyecto","Reaplicar o borrar motions de la biblioteca.",Guard(History),backend=false,oldPaths={"AutoMotion/Historial del proyecto"}},
        {"Quitar motion de la selecciÃ³n","Restaurar las lÃ­neas originales.",Guard(RemoveSelected),backend=false,oldPaths={"AutoMotion/Quitar motion de la selecciÃ³n"}},
    },script_namespace,dependencies)

    AutoMotion.LoadEngine, AutoMotion.BuildRequest, AutoMotion.RunBackend = LoadEngine, BuildRequest, RunBackend
    AutoMotion.Records, AutoMotion.Apply, AutoMotion.Restore = Records, Apply, Restore
    AutoMotion.Generate, AutoMotion.History, AutoMotion.RemoveSelected = Generate, History, RemoveSelected
    AutoMotion.DataKey, AutoMotion.LinkKey = DATA_KEY, LINK_KEY
    AutoMotion.LibraryPaths, AutoMotion.SaveRecord, AutoMotion.MigrateLegacy = LibraryPaths, SaveRecord, MigrateLegacy
    return AutoMotion
end

local function registerAutoMask(record)
    local Olympus = nil
    local script_name = "Auto Mask"
    local script_description = "Detect, clean and reconstruct guided surfaces through the kite-automask backend."
    local script_version = "2.7.0"
    local script_namespace = "kite.AutoMask"
    local menuPath = script_name
    local BACKEND_RESPONSE_VERSION = 1
    local snapshotConfigReadLimit = 16000
    local maxBackendResponseChars = 100000000
    local maxTimelineFrame = 2147483647
    local guideModes = {
      whole = true,
      inside = true
    }
    local depctrl = record
    Olympus = require("kite.Automatons")
    local KiteUI = require("kite.UI")
    local PyBridge = require("kite.PyBridge")
    local LineOps = require("kite.Core").LineOps
    local Media = PyBridge.Media
    local AssDrawing = require("kite.ShapeOptimizer").AssDrawing
    local haveJson, json = pcall(require, "json")
    if not (haveJson and json and json.encode) then
      haveJson, json = pcall(require, "l0.dkjson")
    end
    local trim = LineOps.trim
    local joinPath = PyBridge.joinPath
    local fileExists = PyBridge.fileExists
    local readFile = PyBridge.readFile
    local writeFile = PyBridge.writeFile
    local shellQuote = PyBridge.quote
    local decodedPath = PyBridge.decodedPath
    local roundInt = LineOps.round
    local copyLine = LineOps.copy
    local commandProgram = PyBridge.program
    local finiteNumber = AssDrawing.finiteNumber
    local validShapePath = AssDrawing.validateAutoMaskPath
    local validDrawingLine = AssDrawing.validateAutoMaskLine
    local showError = KiteUI.message
    local showMessage = showError
    local logMessage
    logMessage = function(message)
      if aegisub and aegisub.debug and aegisub.debug.out then
        return aegisub.debug.out("[AutoMask] " .. tostring(message) .. "\n")
      end
    end
    local progressTitle
    progressTitle = function(text)
      if aegisub and aegisub.progress and aegisub.progress.title then
        return pcall(aegisub.progress.title, text)
      end
    end
    local progressTask
    progressTask = function(text)
      return LineOps.progress(text, nil)
    end
    local progressSet
    progressSet = function(value)
      return LineOps.progress(nil, value)
    end
    local SETTINGS = KiteUI.settings(script_namespace, script_version, {
      main = {
        guide_mode = "whole"
      }
    }, { }, {
      "kite.Automask"
    })
    local readConfig
    readConfig = function()
      return {
        python = Olympus.python()
      }
    end
    local configuredPython
    configuredPython = function()
      return readConfig().python
    end
    local pythonPathError
    pythonPathError = function(python)
      local value = trim(python)
      if not (value:find("[/\\]")) then
        return nil
      end
      if fileExists(value) then
        return nil
      end
      return "The configured Python interpreter was not found.\nPath: " .. tostring(value) .. "\nOpen Hephaestus Fansubber/Install/Auto Mask."
    end
    local configuredFfmpeg
    configuredFfmpeg = function()
      local executable, message = Olympus.tool("ffmpeg")
      if not (executable) then
        error(message)
      end
      return executable
    end
    local ffmpegExecutable
    ffmpegExecutable = function(value)
      local exe = trim(value)
      if exe == "" then
        exe = "ffmpeg"
      end
      local lower = exe:lower()
      if PyBridge.isWindows and (lower == "ffmpeg" or lower == "ffmpeg.exe") then
        local _list_0 = {
          {
            "SystemRoot",
            "ffmpeg.exe"
          },
          {
            "ProgramFiles",
            "ffmpeg/bin/ffmpeg.exe"
          }
        }
        for _index_0 = 1, #_list_0 do
          local location = _list_0[_index_0]
          local base = os.getenv(location[1])
          if base and base ~= "" then
            local candidate = joinPath(base, location[2])
            if fileExists(candidate) then
              return candidate
            end
          end
        end
      end
      return exe
    end
    local ffmpegTime
    ffmpegTime = function(ms)
      return string.format("%.3f", math.max(0, finiteNumber(ms, 0)) / 1000)
    end
    local projectProperties = LineOps.projectProperties
    local videoPath
    videoPath = function()
      return Media.projectPath("video")
    end
    local currentVideoFrame
    currentVideoFrame = function()
      local props = projectProperties()
      if props.video_position == nil then
        return nil
      end
      local frame = tonumber(props.video_position)
      if not (frame and frame == frame and frame ~= math.huge and frame ~= -math.huge and frame >= 0 and frame <= maxTimelineFrame) then
        return nil
      end
      return math.floor(frame)
    end
    local frameCenterMs
    frameCenterMs = function(frame)
      frame = finiteNumber(frame)
      if not (frame and frame >= 0 and frame <= maxTimelineFrame) then
        return nil
      end
      frame = math.floor(frame)
      local startMs = Media.msFromFrame(frame)
      if not (finiteNumber(startMs)) then
        return nil
      end
      local nextMs = Media.msFromFrame(frame + 1)
      if finiteNumber(nextMs) and nextMs > startMs then
        return (startMs + nextMs) / 2
      else
        return startMs
      end
    end
    local videoSize
    videoSize = function()
      if not (aegisub and aegisub.video_size) then
        return nil, nil
      end
      local ok, width, height = pcall(aegisub.video_size)
      if not (ok) then
        return nil, nil
      end
      width, height = finiteNumber(width), finiteNumber(height)
      if not (width and height and width > 0 and height > 0) then
        return nil, nil
      end
      width, height = roundInt(width), roundInt(height)
      if not (width and height and width >= 1 and height >= 1) then
        return nil, nil
      end
      return width, height
    end
    local scriptResolution
    scriptResolution = function(subs, fallbackX, fallbackY)
      local x, y = LineOps.scriptResolution(subs, fallbackX, fallbackY)
      if not (finiteNumber(x) and finiteNumber(y) and x > 0 and y > 0) then
        return nil, nil
      end
      x, y = roundInt(x), roundInt(y)
      if not (x and y and x >= 1 and y >= 1) then
        return nil, nil
      end
      return x, y
    end
    local captureCommand
    captureCommand = function(video, ffmpeg, timeMs, outputPath, playX, playY)
      local filter = "scale=" .. tostring(playX) .. ":" .. tostring(playY) .. ":flags=bicubic,format=rgb24"
      return commandProgram(ffmpegExecutable(ffmpeg), "ffmpeg") .. " -hide_banner -nostdin -loglevel error -y -ss " .. ffmpegTime(timeMs) .. " -i " .. shellQuote(video) .. " -vf " .. shellQuote(filter) .. " -frames:v 1 " .. shellQuote(outputPath)
    end
    local backendCommand
    backendCommand = function(python, requestPath, resultPath, noGui)
      if noGui == nil then
        noGui = false
      end
      local arguments = {
        "--request",
        requestPath,
        "--output",
        resultPath
      }
      if noGui then
        arguments[#arguments + 1] = "--no-gui"
      end
      return Olympus.command("automask", arguments)
    end
    local runHidden
    runHidden = function(command)
      return PyBridge.run(command)
    end
    local uniqueTempPaths
    uniqueTempPaths = function()
      return PyBridge.tempPaths("automask", {
        frame = "_frame.png",
        request = "_request.json",
        result = "_result.json"
      })
    end
    local collectItems
    collectItems = function(subs, sel)
      if not (sel and #sel > 0) then
        return nil, "Select at least one line."
      end
      local records, rejected = LineOps.selectedLines(subs, sel, (function(line)
        return line and line.class == "dialogue" and not line.comment
      end), true)
      if not records then
        return nil, "Every selected row must be an uncommented dialogue line. Invalid rows: " .. tostring(table.concat(rejected, ', ')) .. "."
      end
      local items = { }
      for order, record in ipairs(records) do
        items[#items + 1] = {
          order = order,
          index = record.index,
          line = record.line
        }
      end
      return items
    end
    local encodeJson
    encodeJson = function(value)
      if not (haveJson and json and json.encode) then
        return nil, "The Aegisub JSON module is missing."
      end
      local ok, encoded = pcall(json.encode, value)
      if not (ok) then
        return nil, tostring(encoded)
      end
      return encoded
    end
    local decodeJson
    decodeJson = function(value)
      if not (haveJson and json and json.decode) then
        return nil, "The Aegisub JSON module is missing."
      end
      local ok, decoded = pcall(json.decode, tostring(value or ""))
      if not (ok) then
        return nil, tostring(decoded)
      end
      if not (type(decoded) == "table") then
        return nil, "The JSON response is not an object."
      end
      return decoded
    end
    local validateResult
    validateResult = function(items, result)
      if not (type(result.version) == "number" and result.version == BACKEND_RESPONSE_VERSION) then
        return nil, "Unsupported backend response."
      end
      if result.status == "cancelled" then
        return "cancelled"
      end
      if not (result.status == "ok") then
        return nil, "The backend did not return a valid result."
      end
      local mode = tostring(result.output_mode or "")
      if not (mode == "fill" or mode == "shape" or mode == "clip" or mode == "iclip") then
        return nil, "Unknown output mode: " .. tostring(mode)
      end
      if result.limits ~= nil and type(result.limits) ~= "table" then
        return nil, "The backend limits field is invalid."
      end
      local limits = result.limits or { }
      if limits.max_lines ~= nil then
        local maxLines = finiteNumber(limits.max_lines)
        if not (maxLines and maxLines >= 1 and maxLines == math.floor(maxLines)) then
          return nil, "The backend returned an invalid line limit."
        end
      end
      if not (type(result.regions) == "table") then
        return nil, "The backend regions field is invalid."
      end
      local region_slots = 0
      for key in pairs(result.regions) do
        if not (type(key) == "number" and key == math.floor(key) and key >= 1 and key <= #items) then
          return nil, "The backend returned a sparse region list."
        end
        region_slots = region_slots + 1
      end
      if not (region_slots == #items) then
        return nil, "The backend returned " .. tostring(region_slots) .. " region slots for " .. tostring(#items) .. " inputs."
      end
      local groups = { }
      local group_count = 0
      for regionIndex = 1, #items do
        local group = result.regions[regionIndex]
        if not (type(group) == "table") then
          return nil, "The backend returned a malformed region."
        end
        local order = tonumber(group.order)
        if not (order and order == math.floor(order) and order >= 1 and order <= #items) then
          return nil, "Group without a valid order."
        end
        if groups[order] then
          return nil, "Duplicate result for region " .. tostring(order) .. "."
        end
        if group.stats ~= nil and type(group.stats) ~= "table" then
          return nil, "Region " .. tostring(order) .. " has invalid stats."
        end
        groups[order] = group
        group_count = group_count + 1
      end
      if not (group_count == #items) then
        return nil, "The backend returned " .. tostring(group_count) .. " regions for " .. tostring(#items) .. " inputs."
      end
      for _index_0 = 1, #items do
        local item = items[_index_0]
        local group = groups[item.order]
        if not (group) then
          return nil, "Missing result for region " .. tostring(item.order) .. "."
        end
        if mode == "fill" then
          if not (type(group.lines) == "table" and #group.lines > 0) then
            return nil, "Region " .. tostring(item.order) .. " produced no drawings."
          end
          for key in pairs(group.lines) do
            if not (type(key) == "number" and key == math.floor(key) and key >= 1 and key <= #group.lines) then
              return nil, "Region " .. tostring(item.order) .. " contains a sparse drawing list."
            end
          end
          for line_number = 1, #group.lines do
            local text = group.lines[line_number]
            if not (validDrawingLine(text)) then
              return nil, "Region " .. tostring(item.order) .. " contains an invalid drawing at line " .. tostring(line_number) .. "."
            end
          end
        else
          if not (validShapePath(group.path)) then
            return nil, "Region " .. tostring(item.order) .. " produced no valid contour."
          end
        end
      end
      return {
        mode = mode,
        groups = groups,
        limits = limits
      }
    end
    local stripClips = LineOps.stripClips
    local injectFirstTag = LineOps.prependTag
    local shapeText
    shapeText = function(path)
      return "{\\an7\\pos(0,0)\\fscx100\\fscy100\\bord0\\shad0\\p1}" .. tostring(path) .. "{\\p0}"
    end
    local replacementSelection
    replacementSelection = function(items, groups)
      local selection, delta = { }, 0
      for _index_0 = 1, #items do
        local item = items[_index_0]
        local group = groups[item.order]
        local startIndex = item.index + delta
        for offset = 0, #group.lines - 1 do
          selection[#selection + 1] = startIndex + offset
        end
        delta = delta + #group.lines - 1
      end
      return selection
    end
    local applyFill
    applyFill = function(subs, items, groups)
      local selection = replacementSelection(items, groups)
      for position = #items, 1, -1 do
        LineOps.progress("Applying fill vectors", (#items - position + 1) / math.max(#items, 1) * 100)
        local item = items[position]
        local group = groups[item.order]
        subs.delete(item.index)
        for lineIndex = #group.lines, 1, -1 do
          local line = copyLine(item.line)
          line.text = group.lines[lineIndex]
          line.comment = false
          subs.insert(item.index, line)
        end
      end
      return selection
    end
    local applyShape
    applyShape = function(subs, items, groups)
      local selection, offset = { }, 0
      for _index_0 = 1, #items do
        local item = items[_index_0]
        selection[#selection + 1] = item.index + offset + 1
        offset = offset + 1
      end
      for position = #items, 1, -1 do
        LineOps.progress("Inserting contour shapes", (#items - position + 1) / math.max(#items, 1) * 100)
        local item = items[position]
        local line = copyLine(item.line)
        line.layer = math.max(0, math.floor(finiteNumber(line.layer, 0))) + 1
        line.text = shapeText(groups[item.order].path)
        line.comment = false
        subs.insert(item.index + 1, line)
      end
      return selection
    end
    local applyClip
    applyClip = function(subs, items, groups, inverse)
      local selection = { }
      for position, item in ipairs(items) do
        LineOps.progress("Applying clips", position / math.max(#items, 1) * 100)
        local line = copyLine(item.line)
        local tag
        if inverse then
          tag = "\\iclip(" .. tostring(groups[item.order].path) .. ")"
        else
          tag = "\\clip(" .. tostring(groups[item.order].path) .. ")"
        end
        line.text = injectFirstTag(stripClips(line.text), tag)
        subs[item.index] = line
        selection[#selection + 1] = item.index
      end
      return selection
    end
    local applyResult
    applyResult = function(subs, items, parsed)
      local _exp_0 = parsed.mode
      if "fill" == _exp_0 then
        return applyFill(subs, items, parsed.groups)
      elseif "shape" == _exp_0 then
        return applyShape(subs, items, parsed.groups)
      elseif "clip" == _exp_0 then
        return applyClip(subs, items, parsed.groups, false)
      elseif "iclip" == _exp_0 then
        return applyClip(subs, items, parsed.groups, true)
      end
    end
    local topLevelClipCounts
    topLevelClipCounts = function(text)
      local clipCount, iclipCount = 0, 0
      local _list_0 = LineOps.tagCalls(text, {
        clip = true,
        iclip = true
      })
      for _index_0 = 1, #_list_0 do
        local call = _list_0[_index_0]
        if call.top_level then
          if call.name == "clip" then
            clipCount = clipCount + 1
          else
            iclipCount = iclipCount + 1
          end
        end
      end
      return clipCount, iclipCount
    end
    local execute
    execute = function(subs, sel, profile, editor, guideMode)
      if profile == nil then
        profile = "auto"
      end
      if editor == nil then
        editor = true
      end
      if guideMode == nil then
        guideMode = nil
      end
      if not (PyBridge.available) then
        return false, "AutoMask requires the aka.command module."
      end
      if not (haveJson) then
        return false, "AutoMask requires an Aegisub JSON module."
      end
      guideMode = guideMode or (SETTINGS:values("main").guide_mode or "whole")
      if not (guideModes[guideMode]) then
        return false, "Unknown guide mode: " .. tostring(guideMode)
      end
      local items, itemError = collectItems(subs, sel)
      if not (items) then
        return false, itemError
      end
      if profile == "autogrask-classic" then
        for _index_0 = 1, #items do
          local item = items[_index_0]
          local text = tostring(item.line.text or "")
          local clipCount, iclipCount = topLevelClipCounts(text)
          if not (clipCount == 1 and iclipCount == 0) then
            return false, "Classic AutoGrask requires exactly one plain \\clip on line " .. tostring(item.index) .. "."
          end
        end
      end
      local video = videoPath()
      if not (video) then
        return false, "Open a video before running AutoMask."
      end
      local frame = currentVideoFrame()
      if not (frame) then
        return false, "Could not read the current video frame."
      end
      local time_ms = frameCenterMs(frame)
      if not (time_ms) then
        return false, "Could not convert the frame to a timestamp."
      end
      local videoX, videoY = videoSize()
      if not (videoX and videoY) then
        return false, "Could not read the video resolution."
      end
      local play_x, play_y = scriptResolution(subs, videoX, videoY)
      local python = configuredPython()
      local missingPython = pythonPathError(python)
      if missingPython then
        return false, missingPython
      end
      local tempPaths, temp_error = uniqueTempPaths()
      if not (tempPaths) then
        return false, "Could not resolve the temporary folder.\n" .. tostring(temp_error or '')
      end
      local completed, success, result = pcall(function()
        local frame_path = tempPaths.frame
        local request_path = tempPaths.request
        local result_path = tempPaths.result
        local regions = { }
        for _index_0 = 1, #items do
          local item = items[_index_0]
          regions[#regions + 1] = {
            order = item.order,
            source_index = item.index,
            text = tostring(item.line.text or "")
          }
        end
        local request = {
          version = BACKEND_RESPONSE_VERSION,
          frame_path = frame_path,
          video_size = {
            videoX,
            videoY
          },
          playres = {
            play_x,
            play_y
          },
          profile = profile,
          guide_mode = guideMode,
          regions = regions
        }
        local encoded, encode_error = encodeJson(request)
        if not (encoded) then
          return false, "Could not encode the JSON request.\n" .. tostring(encode_error or '')
        end
        local wrote, write_error = writeFile(request_path, encoded)
        if not (wrote) then
          return false, "Could not write the JSON request.\nPath: " .. tostring(request_path) .. "\n" .. tostring(write_error or '')
        end
        progressTitle("AutoMask")
        progressTask((function()
          if editor then
            return "Capturing the frame and opening the editor"
          else
            return "Capturing the frame and running " .. tostring(profile)
          end
        end)())
        progressSet(20)
        local backend, backend_error = backendCommand(python, request_path, result_path, not editor)
        if not (backend) then
          return false, "Could not build the backend command.\n" .. tostring(backend_error or '')
        end
        local command = PyBridge.chain(captureCommand(video, configuredFfmpeg(), time_ms, frame_path, play_x, play_y), backend)
        local ok, detail = runHidden(command)
        if not (ok and fileExists(result_path)) then
          local stage
          if fileExists(frame_path) then
            stage = "The AutoMask backend failed."
          else
            stage = "FFmpeg could not capture the frame."
          end
          return false, tostring(stage) .. "\n\n" .. tostring(detail)
        end
        local resultContent, result_read_error = readFile(result_path, maxBackendResponseChars + 1)
        if not (resultContent) then
          return false, "Could not read the backend response.\n" .. tostring(result_read_error or '')
        end
        if #resultContent > maxBackendResponseChars then
          return false, "The backend response exceeds the size limit."
        end
        local decodedResult, decodeError = decodeJson(resultContent)
        if not (decodedResult) then
          return false, decodeError
        end
        local parsed, validationError = validateResult(items, decodedResult)
        if parsed == "cancelled" then
          return false, "cancelled"
        end
        if not (parsed) then
          return false, validationError
        end
        progressTask("Applying ASS vectors")
        progressSet(90)
        local selection = nil
        local applied, apply_error = pcall(function()
          selection = LineOps.transaction(subs, script_name, function()
            return applyResult(subs, items, parsed)
          end)
        end)
        if not (applied) then
          return false, "Could not apply the result. The subtitles were restored.\n" .. tostring(apply_error)
        end
        progressSet(100)
        local total = 0
        local summaries = { }
        if parsed.mode == "fill" then
          for _index_0 = 1, #items do
            local item = items[_index_0]
            local group = parsed.groups[item.order]
            total = total + #group.lines
            local stats
            if type(group.stats) == "table" then
              stats = group.stats
            else
              stats = { }
            end
            summaries[#summaries + 1] = tostring(item.order) .. "=" .. tostring(stats.engine or 'fill') .. "/" .. tostring(#group.lines)
          end
        else
          total = #items
        end
        logMessage(tostring(#items) .. " regions -> " .. tostring(total) .. " lines (" .. tostring(parsed.mode) .. "); " .. tostring(table.concat(summaries, ', ')))
        return true, selection
      end)
      PyBridge.cleanup(tempPaths)
      if not (completed) then
        error(success, 0)
      end
      return success, result
    end
    local runProfile
    runProfile = function(subs, sel, profile, editor, guideMode)
      local ok, success, result = pcall(execute, subs, sel, profile, editor, guideMode)
      if not (ok) then
        showError(tostring(success))
        return sel, sel and sel[1]
      end
      if not (success) then
        if result == "cancelled" then
          return sel, sel and sel[1]
        end
        showError(result)
        return sel, sel and sel[1]
      end
      return result, result and result[1]
    end
    local main
    main = function(subs, sel)
      return runProfile(subs, sel, "auto", true, nil)
    end
    local mainInside
    mainInside = function(subs, sel)
      return runProfile(subs, sel, "auto", true, "inside")
    end
    local mainClassic
    mainClassic = function(subs, sel)
      return runProfile(subs, sel, "autogrask-classic", false, "whole")
    end
    local validate
    validate = function(subs, sel)
      if not (sel and #sel > 0) then
        return false
      end
      for _index_0 = 1, #sel do
        local index = sel[_index_0]
        local line = subs and subs[index]
        if not (line and line.class == "dialogue" and not line.comment) then
          return false
        end
      end
      return true
    end
    local validateClip
    validateClip = function(subs, sel)
      if not (validate(subs, sel)) then
        return false
      end
      for _index_0 = 1, #sel do
        local index = sel[_index_0]
        local text = tostring(subs[index].text or "")
        local clipCount, iclipCount = topLevelClipCounts(text)
        if clipCount == 0 or iclipCount > 0 then
          return false
        end
      end
      return true
    end
    if aegisub and aegisub.register_macro then
      local entries = {
        {
          "Open",
          script_description,
          main,
          validate,
          oldPaths = {
            "AutoMask/AutoMask"
          }
        },
        {
          "Find surface inside clip",
          "Detect the surface contained inside each clip.",
          mainInside,
          validateClip,
          oldPaths = {
            "AutoMask/Find surface inside clip"
          }
        },
        {
          "Classic AutoGrask",
          "Run the original clip-guided AutoGrask profile.",
          mainClassic,
          validateClip,
          oldPaths = {
            "AutoMask/Classic AutoGrask"
          }
        }
      }
      Olympus.register("automask", entries, script_namespace, depctrl)
    end
    return
end

local function registerAutoDrawing(record)
    local Olympus
    local script_name        = "Auto Drawing"
    local script_description = "Convert images and SVG files into ASS drawing lines"
    local script_version     = "1.9.0"
    local script_namespace   = "kite.AutoDrawing"

    local PNG2ASS = {}

    local moduleName = "fansub_automatons.drawing"
    local imageFilter = "Images (.png .jpg .jpeg .webp .bmp .tif .tiff .gif .tga .svg)|"
        .. "*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.tif;*.tiff;*.gif;*.tga;*.svg"
    local supportedExtensions = {
        png = true, jpg = true, jpeg = true, webp = true, bmp = true,
        tif = true, tiff = true, gif = true, tga = true, svg = true,
    }
    local maxSequenceLines = 500000
    local maxSequenceChars = 100000000
    local maxLogChars = 1000000
    local processPollMs = 100
    local processExitGracePolls = 30
    local insertChunkSize = 128
    local CANCELLED = "PNG2ASS_CANCELLED"

    local depctrl = record
    local KiteUI = require("kite.UI")
    local PyBridge = require("kite.PyBridge")
    local LineOps = require("kite.Core").LineOps
    local Media = PyBridge.Media
    local AssDrawing = require("kite.ShapeOptimizer").AssDrawing
    local json
    Olympus = require("kite.Automatons")

    do
        local ok, value = pcall(require, "json")
        if not ok or not value or type(value.decode) ~= "function" then
            ok, value = pcall(require, "l0.dkjson")
        end
        if ok and value and type(value.decode) == "function" then json = value end
    end

    local DEFAULTS = {
        python = "python",
        engine = "auto",
        mode = "auto",
        trace_profile = "balanced",
        threshold = 50,
        p_scale = 4,
        simplify = 1.0,
        min_area = 2,
        max_chars = 1000000,
        max_pixels = 40000000,
        denoise = 0,
        position = "0,0",
        x = 0,
        y = 0,
        blur = 0,
        color = "style",
        line_warning = 256,
        svg_precision = 3,
        svg_arc_degrees = 30,
    }

    local MODES = { "auto", "alpha", "white-matte", "dark-matte", "luma", "color" }
    local traceProfiles = { "balanced", "quality" }
    local POSITIONS = { "0,0", "Active pos", "Manual" }
    local COLORS = { "style", "source" }
    local optionLimits = {
        svg_precision = { min = 0, max = 5, integer = true },
        svg_arc_degrees = { min = 1, max = 90 },
        threshold = { min = 0, max = 100, integer = true },
        p_scale = { min = 1, max = 6, integer = true },
        line_warning = { min = 1, max = maxSequenceLines, integer = true },
        simplify = { min = 0, max = 1000 },
        min_area = { min = 0, max = 1000000000 },
        x = { min = -10000000, max = 10000000 },
        y = { min = -10000000, max = 10000000 },
        blur = { min = 0, max = 100 },
        denoise = { min = 0, max = 50, integer = true },
        max_chars = { min = 1, max = maxSequenceChars, integer = true },
        max_pixels = { min = 1, max = 250000000, integer = true },
    }

    local function listContains(values, wanted)
        for _, value in ipairs(values) do if value == wanted then return true end end
        return false
    end

    local trim = LineOps.trim
    local joinPath = PyBridge.joinPath
    local fileExists = PyBridge.fileExists
    local writeFile = PyBridge.writeFile
    local copyLine = LineOps.copy
    local readFile = PyBridge.readFile
    local decodedPath = LineOps.decodedPath

    local finiteNumber = AssDrawing.finiteNumber

    local function normalizeMainOptions(values)
        values = type(values) == "table" and values or {}
        local normalized = {}
        normalized.engine = "auto"
        normalized.mode = listContains(MODES, values.mode) and values.mode or DEFAULTS.mode
        normalized.trace_profile = listContains(traceProfiles, values.trace_profile) and values.trace_profile or DEFAULTS.trace_profile
        normalized.position = listContains(POSITIONS, values.position) and values.position or DEFAULTS.position
        normalized.color = listContains(COLORS, values.color) and values.color or DEFAULTS.color
        for name, limits in pairs(optionLimits) do
            local value = finiteNumber(values[name]) or DEFAULTS[name]
            value = math.max(limits.min, math.min(limits.max, value))
            if limits.integer then value = LineOps.round(value) end
            normalized[name] = value
        end
        normalized.python = type(values.python) == "string" and trim(values.python) or ""
        return normalized
    end

    local validAssShapeLine = AssDrawing.validatePng2AssLine

    local function readLog(path)
        local content = readFile(path, maxLogChars + 1)
        if content and #content > maxLogChars then return content:sub(1, maxLogChars) .. "\n[output truncated]" end
        return content
    end

    local cancellationRequested
    local setProgress

    local function readLines(path)
        local content, message = readFile(path, maxSequenceChars + 1)
        if not content then
            return nil, message
        end
        if #content > maxSequenceChars then return nil, "Backend output exceeds the character limit." end
        local lines = {}
        for line in (content .. "\n"):gmatch("([^\r\n]*)\r?\n") do
            line = trim(line)
            if line ~= "" then
                if not validAssShapeLine(line) then
                    return nil, "Backend output contains an invalid ASS drawing at line " .. tostring(#lines + 1) .. "."
                end
                lines[#lines + 1] = line
                if #lines > maxSequenceLines then return nil, "Backend output exceeds the ASS line limit." end
                if #lines % insertChunkSize == 0 then
                    setProgress("Validating ASS output", math.min(99, #lines / math.max(1, maxSequenceLines) * 100))
                    if cancellationRequested() then return nil, CANCELLED end
                end
            end
        end
        return lines
    end

    local function showMessage(message)
        return KiteUI.message(message)
    end
    local function cancelWith(message)
        showMessage(message)
        aegisub.cancel()
    end

    local allocateTempPaths

    cancellationRequested = function()
        if not aegisub or not aegisub.progress or type(aegisub.progress.is_cancelled) ~= "function" then return false end
        local ok, cancelled = pcall(aegisub.progress.is_cancelled)
        return ok and cancelled == true
    end

    setProgress = function(task, percent)
        if not aegisub or not aegisub.progress then return end
        if task and type(aegisub.progress.task) == "function" then pcall(aegisub.progress.task, tostring(task)) end
        if percent and type(aegisub.progress.set) == "function" then pcall(aegisub.progress.set, math.max(0, math.min(100, percent))) end
    end

    local function decodeJsonFile(path)
        if not json then return nil, "JSON support is unavailable." end
        local content, message = readFile(path, maxLogChars + 1)
        if not content then return nil, message end
        if #content > maxLogChars then return nil, "JSON output is too large." end
        local ok, value = pcall(json.decode, content)
        if not ok or type(value) ~= "table" then return nil, ok and "JSON output is invalid." or tostring(value) end
        return value
    end

    local function powershellLiteral(value)
        return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
    end

    local function windowsQuoteArgument(value)
        value = tostring(value or "")
        local parts = { '"' }
        local slashes = 0
        for index = 1, #value do
            local character = value:sub(index, index)
            if character == "\\" then
                slashes = slashes + 1
            elseif character == '"' then
                parts[#parts + 1] = string.rep("\\", slashes * 2 + 1)
                parts[#parts + 1] = '"'
                slashes = 0
            else
                if slashes > 0 then parts[#parts + 1] = string.rep("\\", slashes); slashes = 0 end
                parts[#parts + 1] = character
            end
        end
        if slashes > 0 then parts[#parts + 1] = string.rep("\\", slashes * 2) end
        parts[#parts + 1] = '"'
        return table.concat(parts)
    end

    local function managedRunnerScript(python, arguments, paths)
        local native = { "-B", "-X", "utf8", "-m", moduleName }
        for _, value in ipairs(arguments or {}) do native[#native + 1] = tostring(value) end
        local quoted = {}
        for _, value in ipairs(native) do quoted[#quoted + 1] = windowsQuoteArgument(value) end
        local argumentLine = table.concat(quoted, " ")
        local cancel = powershellLiteral(paths.cancel)
        local stdout = powershellLiteral(paths.stdout)
        local stderr = powershellLiteral(paths.stderr)
        local cmdlog = powershellLiteral(paths.cmdlog)
        local exitPath = powershellLiteral(paths.exit)
        return "\239\187\191" .. table.concat({
            "$ErrorActionPreference = 'Stop'",
            "$utf8 = New-Object System.Text.UTF8Encoding($false)",
            "$exitCode = 1",
            "$cancelled = $false",
            "$process = $null",
            "$jobRoot = [IO.Path]::Combine([IO.Path]::GetTempPath(), 'kite-olympus-' + [Guid]::NewGuid().ToString('N'))",
            "$stdoutText = ''",
            "$stderrText = ''",
            "try {",
            "    [IO.Directory]::CreateDirectory($jobRoot) | Out-Null",
            "    $argumentLine = " .. powershellLiteral(argumentLine),
            "    $startInfo = New-Object System.Diagnostics.ProcessStartInfo",
            "    $startInfo.FileName = " .. powershellLiteral(python),
            "    $startInfo.Arguments = $argumentLine",
            "    $startInfo.UseShellExecute = $false",
            "    $startInfo.EnvironmentVariables['TEMP'] = $jobRoot",
            "    $startInfo.EnvironmentVariables['TMP'] = $jobRoot",
            "    $startInfo.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'",
            "    $startInfo.EnvironmentVariables['CUDA_CACHE_DISABLE'] = '1'",
            "    $startInfo.CreateNoWindow = $true",
            "    $startInfo.RedirectStandardOutput = $true",
            "    $startInfo.RedirectStandardError = $true",
            "    $process = New-Object System.Diagnostics.Process",
            "    $process.StartInfo = $startInfo",
            "    if (-not $process.Start()) { throw 'Could not start the Auto Drawing backend.' }",
            "    $stdoutTask = $process.StandardOutput.ReadToEndAsync()",
            "    $stderrTask = $process.StandardError.ReadToEndAsync()",
            "    while (-not $process.HasExited) {",
            "        if (Test-Path -LiteralPath " .. cancel .. ") {",
            "            $cancelled = $true",
            "            try { if (-not $process.HasExited) { $process.Kill() }; $process.WaitForExit() } catch {}",
            "            $exitCode = 130",
            "            break",
            "        }",
            "        Start-Sleep -Milliseconds " .. tostring(processPollMs),
            "    }",
            "    if (-not $cancelled) { $process.WaitForExit(); $exitCode = $process.ExitCode }",
            "    $stdoutText = $stdoutTask.Result",
            "    $stderrText = $stderrTask.Result",
            "} catch {",
            "    try { if ($process -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() } } catch {}",
            "    $stderrText = $stderrText + ($_ | Out-String)",
            "    $exitCode = 1",
            "} finally {",
            "    if ([IO.Directory]::Exists($jobRoot)) { try { [IO.Directory]::Delete($jobRoot, $true) } catch { $stderrText += (' Temporary cleanup failed: ' + $_.Exception.Message); $exitCode = 1 } }",
            "}",
            "[IO.File]::WriteAllText(" .. stdout .. ", $stdoutText, $utf8)",
            "[IO.File]::WriteAllText(" .. stderr .. ", $stderrText, $utf8)",
            "[IO.File]::WriteAllText(" .. cmdlog .. ", ($stdoutText + $stderrText), $utf8)",
            "[IO.File]::WriteAllText(" .. exitPath .. ", [string]$exitCode, $utf8)",
            "exit $exitCode",
        }, "\r\n")
    end

    local function updateBackendProgress(paths)
        if not fileExists(paths.progress) then return end
        local progress = decodeJsonFile(paths.progress)
        if not progress then return end
        setProgress(progress.stage or "Converting image", finiteNumber(progress.percent))
    end

    local function waitForProcessExit(pid, exitPath)
        for poll = 1, processExitGracePolls do
            if (not exitPath or fileExists(exitPath)) and not PyBridge.processExists(pid) then return true end
            PyBridge.sleep(processPollMs)
        end
        return not PyBridge.processExists(pid)
    end

    local function runManagedBackend(python, arguments, paths)
        if not PyBridge.isWindows then return false, "Cancelable Auto Drawing conversion currently requires Windows." end
        if type(PyBridge.startDetachedScript) ~= "function" or type(PyBridge.processExists) ~= "function" or type(PyBridge.sleep) ~= "function" then
            return false, "kite.PyBridge 1.5.0 or newer is required for cancelable conversion."
        end
        local wrote, writeError = writeFile(paths.runner, managedRunnerScript(python, arguments, paths))
        if not wrote then return false, writeError or "Could not create the managed backend runner." end
        local started, pid = PyBridge.startDetachedScript(paths.runner)
        if not started then return false, pid or "Could not start the managed backend runner." end

        setProgress("Starting Auto Drawing backend", 0)
        local poll = 0
        while not fileExists(paths.exit) do
            poll = poll + 1
            if cancellationRequested() then
                local signalled, signalError = writeFile(paths.cancel, "cancel")
                if not signalled then return false, signalError or "Could not signal backend cancellation." end
                setProgress("Cancelling Auto Drawing backend", nil)
                if not waitForProcessExit(pid, paths.exit) then
                    return false, "The managed Auto Drawing process did not stop after cancellation."
                end
                return false, CANCELLED, true
            end
            updateBackendProgress(paths)
            if poll % 10 == 0 and not PyBridge.processExists(pid) then
                for _ = 1, 5 do
                    if fileExists(paths.exit) then break end
                    PyBridge.sleep(processPollMs)
                end
                if not fileExists(paths.exit) then return false, "The Auto Drawing supervisor exited without reporting a result." end
                break
            end
            PyBridge.sleep(processPollMs)
        end

        if not waitForProcessExit(pid, paths.exit) then return false, "The Auto Drawing supervisor did not exit cleanly." end
        local exitText, exitError = readFile(paths.exit, 32)
        local exitCode = exitText and tonumber(trim(exitText)) or nil
        if exitCode == nil then return false, exitError or "The Auto Drawing exit code is invalid." end
        local log = readLog(paths.log)
        if not log or trim(log) == "" then log = readLog(paths.cmdlog) end
        return exitCode == 0, log, exitCode == 130
    end

    local function runCommand(command, logPath)
        if not command or trim(command) == "" then
            writeFile(logPath, "Command could not be built.")
            return false
        end
        local ok, log = PyBridge.run(command)
        writeFile(logPath, log or "")
        return ok
    end

    local function runCommandDialog(title, command, okMessage)
        local current = command
        local log = nil
        while true do
            local interface = {
                { class = "label", label = title, x = 0, y = 0, width = 8, height = 1 },
                { class = "label", label = "Execute this command.", x = 0, y = 1, width = 8, height = 1 },
                { class = "textbox", name = "command", value = current, x = 0, y = 2, width = 56, height = 6 },
            }
            if log and trim(log) ~= "" then
                table.insert(interface, { class = "label", label = "Output", x = 0, y = 8, width = 8, height = 1 })
                table.insert(interface, { class = "textbox", name = "log", value = log, x = 0, y = 9, width = 56, height = 6 })
            end

            local runLabel = "Execute"
            local button, result = aegisub.dialog.display(interface, { runLabel, "Cancel" }, { ok = runLabel, close = "Cancel" })
            if button ~= runLabel then
                aegisub.cancel()
            end

            current = trim(result.command)
            if current == "" then
                log = "Command is empty."
            else
                local paths, pathError = allocateTempPaths()
                if not paths then
                    log = pathError or "Could not allocate temporary files."
                else
                    local ok = runCommand(current, paths.cmdlog)
                    log = readLog(paths.cmdlog) or "Command failed."
                    PyBridge.cleanup(paths)
                    if ok then showMessage(okMessage); return true end
                end
            end
        end
    end

    local function sourceDir()
        if not debug or not debug.getinfo then
            return nil
        end
        local info = debug.getinfo(1, "S")
        local source = info and info.source or ""
        if source:sub(1, 1) ~= "@" then
            return nil
        end
        local path = source:sub(2)
        local dir = path:match("^(.*)[\\/]")
        if dir and dir ~= "" then
            return dir
        end
        return nil
    end

    local function scriptDir()
        local dir = sourceDir()
        if dir then
            return dir
        end
        local userPath = decodedPath("?user")
        if userPath then
            return joinPath(joinPath(userPath, "automation"), "autoload")
        end
        return decodedPath("?script") or "."
    end

    local pngSettings = KiteUI.settings(script_namespace, script_version, {
        main = {
            mode = DEFAULTS.mode,
            trace_profile = DEFAULTS.trace_profile,
            color = DEFAULTS.color,
            threshold = DEFAULTS.threshold,
            p_scale = DEFAULTS.p_scale,
            line_warning = DEFAULTS.line_warning,
            simplify = DEFAULTS.simplify,
            min_area = DEFAULTS.min_area,
            position = DEFAULTS.position,
            x = DEFAULTS.x,
            y = DEFAULTS.y,
            blur = DEFAULTS.blur,
            max_chars = DEFAULTS.max_chars,
            max_pixels = DEFAULTS.max_pixels,
            denoise = DEFAULTS.denoise,
            svg_precision = DEFAULTS.svg_precision,
            svg_arc_degrees = DEFAULTS.svg_arc_degrees,
        },
    }, {}, {"kite.PNG2ASS"})

    local function readConfig()
        return {python=Olympus.python()}
    end

    local function pythonPathError(value)
        if value and value ~= "" and fileExists(value) then return nil end
        return Olympus.missing("png2ass")
    end

    function allocateTempPaths()
        return PyBridge.tempPaths("png2ass", {
            out = ".txt",
            list = ".list",
            sequence = ".seq",
            log = ".log",
            cmdlog = ".cmd.log",
            result = ".result.json",
            progress = ".progress.json",
            cancel = ".cancel",
            runner = ".runner.ps1",
            stdout = ".stdout.log",
            stderr = ".stderr.log",
            exit = ".exit",
        })
    end

    local function activePos(text)
        local position = LineOps.position(text)
        local x = position and finiteNumber(position.x) or nil
        local y = position and finiteNumber(position.y) or nil
        if x and y then return x, y end
        return nil, nil
    end

    local function naturalKey(path)
        local name = tostring(path or ""):match("([^\\/]+)$") or tostring(path or "")
        name = name:lower()
        return name:gsub("(%d+)", function(number)
            local significant = number:gsub("^0+", "")
            if significant == "" then significant = "0" end
            return string.format("%08d:%s", #significant, significant)
        end)
    end

    local function normalizePaths(value)
        local paths = {}
        local rejected = {}
        local seen = {}
        local values = type(value) == "table" and value or { value }
        for _, path in ipairs(values) do
            path = type(path) == "string" and trim(path) or ""
            local key = PyBridge.isWindows and path:lower() or path
            local extension = path:lower():match("%.([^.\\/]+)$")
            local unsafeListPath = path:find("[\r\n]") or path:find("%z")
            if path ~= "" and not unsafeListPath and supportedExtensions[extension] and fileExists(path) and not seen[key] then
                seen[key] = true
                paths[#paths + 1] = path
            elseif path ~= "" and (unsafeListPath or not supportedExtensions[extension] or not fileExists(path)) then
                rejected[#rejected + 1] = path
            end
        end
        table.sort(paths, function(left, right)
            local leftKey = naturalKey(left)
            local rightKey = naturalKey(right)
            if leftKey == rightKey then return left:lower() < right:lower() end
            return leftKey < rightKey
        end)
        return paths, rejected
    end

    local function selectPngs()
        local result = aegisub.dialog.open(
            "Select Images",
            "",
            scriptDir(),
            imageFilter,
            true,
            true
        )
        local paths, rejected = normalizePaths(result)
        if #rejected > 0 then
            cancelWith("Some selected images are missing or unsupported:\n" .. table.concat(rejected, "\n"))
        end
        if #paths == 0 then
            aegisub.cancel()
        end
        return paths
    end




    local function createDialog(line, cfg, imageCount, frameCount, isSvg)
        local px, py = activePos(line.text)
        local saved = normalizeMainOptions(pngSettings:values("main"))
        local defaultPosition = (px and py) and "Active pos" or saved.position
        if isSvg then
            defaultPosition = "0,0"
            saved.color = "source"
        end
        local countLabel = "Images: " .. tostring(imageCount or 1)
        if frameCount then
            countLabel = countLabel .. " / Frames: " .. tostring(frameCount)
        end
        local interface = {
            title = { class = "label", label = "Auto Drawing", x = 0, y = 0, width = 6, height = 1 },
            mode_label = { class = "label", label = "Mode", x = 0, y = 1, width = 2, height = 1 },
            mode = { class = "dropdown", name = "mode", items = MODES, value = saved.mode, x = 2, y = 1, width = 3, height = 1 },
            color_label = { class = "label", label = "Color", x = 5, y = 1, width = 2, height = 1 },
            color = { class = "dropdown", name = "color", items = COLORS, value = saved.color, x = 7, y = 1, width = 3, height = 1 },
            profile_label = { class = "label", label = "VTracer", x = 10, y = 1, width = 2, height = 1 },
            trace_profile = { class = "dropdown", name = "trace_profile", items = traceProfiles, value = saved.trace_profile, x = 12, y = 1, width = 3, height = 1 },
            threshold_label = { class = "label", label = "Threshold", x = 0, y = 2, width = 3, height = 1 },
            threshold = { class = "intedit", name = "threshold", value = saved.threshold, min = optionLimits.threshold.min, max = optionLimits.threshold.max, x = 3, y = 2, width = 3, height = 1 },
            scale_label = { class = "label", label = "Scale", x = 6, y = 2, width = 2, height = 1 },
            p_scale = { class = "intedit", name = "p_scale", value = saved.p_scale, min = optionLimits.p_scale.min, max = optionLimits.p_scale.max, x = 8, y = 2, width = 2, height = 1 },
            simplify_label = { class = "label", label = "Simplify", x = 0, y = 3, width = 3, height = 1 },
            simplify = { class = "floatedit", name = "simplify", value = saved.simplify, min = optionLimits.simplify.min, max = optionLimits.simplify.max, step = 0.25, x = 3, y = 3, width = 3, height = 1 },
            min_area_label = { class = "label", label = "Min area", x = 6, y = 3, width = 3, height = 1 },
            min_area = { class = "floatedit", name = "min_area", value = saved.min_area, min = optionLimits.min_area.min, max = optionLimits.min_area.max, step = 1, x = 9, y = 3, width = 3, height = 1 },
            position_label = { class = "label", label = "Position", x = 0, y = 4, width = 3, height = 1 },
            position = { class = "dropdown", name = "position", items = POSITIONS, value = defaultPosition, x = 3, y = 4, width = 4, height = 1 },
            x_label = { class = "label", label = "X", x = 7, y = 4, width = 1, height = 1 },
            x = { class = "floatedit", name = "x", value = px or saved.x, min = optionLimits.x.min, max = optionLimits.x.max, x = 8, y = 4, width = 3, height = 1 },
            y_label = { class = "label", label = "Y", x = 11, y = 4, width = 1, height = 1 },
            y = { class = "floatedit", name = "y", value = py or saved.y, min = optionLimits.y.min, max = optionLimits.y.max, x = 12, y = 4, width = 3, height = 1 },
            blur_label = { class = "label", label = "Blur", x = 0, y = 5, width = 2, height = 1 },
            blur = { class = "floatedit", name = "blur", value = saved.blur, min = optionLimits.blur.min, max = optionLimits.blur.max, step = 0.1, x = 2, y = 5, width = 3, height = 1 },
            denoise_label = { class = "label", label = "Denoise", x = 5, y = 5, width = 2, height = 1 },
            denoise = { class = "intedit", name = "denoise", value = saved.denoise, min = optionLimits.denoise.min, max = optionLimits.denoise.max, x = 7, y = 5, width = 2, height = 1 },
            max_label = { class = "label", label = "Warn chars", x = 9, y = 5, width = 3, height = 1 },
            max_chars = { class = "intedit", name = "max_chars", value = saved.max_chars, min = optionLimits.max_chars.min, max = optionLimits.max_chars.max, x = 12, y = 5, width = 3, height = 1 },
            pixels_label = { class = "label", label = "Max pixels", x = 0, y = 6, width = 3, height = 1 },
            max_pixels = { class = "intedit", name = "max_pixels", value = saved.max_pixels, min = optionLimits.max_pixels.min, max = optionLimits.max_pixels.max, x = 3, y = 6, width = 5, height = 1 },
            lines_label = { class = "label", label = "Warn lines", x = 8, y = 6, width = 3, height = 1 },
            line_warning = { class = "intedit", name = "line_warning", value = saved.line_warning, min = optionLimits.line_warning.min, max = optionLimits.line_warning.max, x = 11, y = 6, width = 4, height = 1 },
            python_label = { class = "label", label = "Python", x = 0, y = 7, width = 2, height = 1 },
            python = { class = "label", label = cfg.python, x = 2, y = 7, width = 11, height = 1 },
            count_label = { class = "label", label = countLabel, x = 0, y = 8, width = 15, height = 1 },
        }
        if isSvg then
            interface.svg_precision_label = { class = "label", label = "SVG decimals", x = 0, y = 9, width = 3, height = 1 }
            interface.svg_precision = { class = "intedit", name = "svg_precision", value = saved.svg_precision, min = 0, max = 5, x = 3, y = 9, width = 2, height = 1 }
            interface.svg_arc_label = { class = "label", label = "Arc degrees", x = 5, y = 9, width = 3, height = 1 }
            interface.svg_arc_degrees = { class = "floatedit", name = "svg_arc_degrees", value = saved.svg_arc_degrees, min = 1, max = 90, x = 8, y = 9, width = 2, height = 1 }
            interface.svg_note = { class = "label", label = "SVG keeps its canvas coordinates. Use matching PlayRes. Raster tracing controls do not apply.", x = 0, y = 10, width = 15, height = 2 }
        end
        local button, result = aegisub.dialog.display(interface, { "Execute", "Cancel" }, { ok = "Execute", close = "Cancel" })
        if button ~= "Execute" then
            aegisub.cancel()
        end
        result.svg_precision = result.svg_precision or saved.svg_precision
        result.svg_arc_degrees = result.svg_arc_degrees or saved.svg_arc_degrees
        result = normalizeMainOptions(result)
        if result.color == "source" and result.mode == "auto" then result.mode = "color" end
        result.python = cfg.python
        return result
    end

    local function persistOptions(options, cfg)
        local saved = {}
        for key, value in pairs(options) do
            if key ~= "python" then saved[key] = value end
        end
        pngSettings:update("main", saved)
        return pngSettings:write()
    end

    local function conversionArguments(paths, options, posX, posY)
        local arguments = {
            "--mode", options.mode,
            "--engine", "auto",
            "--trace-profile", options.trace_profile,
            "--threshold", tostring(options.threshold),
            "--p-scale", tostring(options.p_scale),
            "--simplify", tostring(options.simplify),
            "--min-area", tostring(options.min_area),
            "--max-lines", tostring(options.line_warning),
            "--max-chars", tostring(options.max_chars),
            "--max-pixels", tostring(options.max_pixels),
            "--denoise", tostring(options.denoise),
            "--pos-x", tostring(posX),
            "--pos-y", tostring(posY),
            "--blur", tostring(options.blur),
            "--svg-precision", tostring(options.svg_precision),
            "--svg-arc-degrees", tostring(options.svg_arc_degrees),
            "--log", paths.log,
            "--result-file", paths.result,
            "--progress-file", paths.progress,
            "--cancel-file", paths.cancel,
            "--quiet",
        }
        if options.color == "source" or options.mode == "color" then arguments[#arguments + 1] = "--keep-color" end
        return arguments
    end

    local function buildCommand(paths, imagePath, options, posX, posY)
        local arguments = { "--input", imagePath }
        local common = conversionArguments(paths, options, posX, posY)
        for _, value in ipairs(common) do arguments[#arguments + 1] = value end
        arguments[#arguments + 1] = "--out"
        arguments[#arguments + 1] = paths.out
        local command, message = Olympus.command("png2ass", arguments)
        return command, message, arguments
    end

    local function buildSequenceCommand(paths, options, posX, posY)
        local arguments = { "--input-list", paths.list }
        local common = conversionArguments(paths, options, posX, posY)
        for _, value in ipairs(common) do arguments[#arguments + 1] = value end
        arguments[#arguments + 1] = "--sequence-out"
        arguments[#arguments + 1] = paths.sequence
        local command, message = Olympus.command("png2ass", arguments)
        return command, message, arguments
    end

    local function resolvePosition(options, line)
        if options.position == "Active pos" then
            local px, py = activePos(line.text)
            if not px or not py then return nil, nil, "The active line does not contain a valid \\pos tag." end
            return px, py
        end
        if options.position == "Manual" then
            local x, y = finiteNumber(options.x), finiteNumber(options.y)
            if not x or not y then return nil, nil, "The manual position is invalid." end
            return x, y
        end
        return 0, 0
    end

    local function conversionSummary(result, fallbackLines, fallbackChars)
        result = type(result) == "table" and result or {}
        local lines = finiteNumber(result.lines) or fallbackLines or 0
        local chars = finiteNumber(result.chars) or fallbackChars or 0
        local values = {
            "Conversion completed.",
            "Engine: " .. tostring(result.engine or "automatic per input mode"),
            "VTracer profile: " .. tostring(result.trace_profile or "not used"),
            "ASS lines: " .. tostring(math.floor(lines)),
            "Characters: " .. tostring(math.floor(chars)),
        }
        local elapsed = finiteNumber(result.elapsed_seconds)
        if result.mode == "svg" and result.width and result.height then
            values[#values + 1] = "SVG canvas: " .. tostring(result.width) .. " x " .. tostring(result.height) .. " (match the subtitle PlayRes)."
        end
        if elapsed then values[#values + 1] = string.format("Backend time: %.2f s", elapsed) end
        local frames = finiteNumber(result.frames)
        if frames then values[#values + 1] = "Frames: " .. tostring(math.floor(frames)) end
        local peak = finiteNumber(result.peak_lines)
        if peak then values[#values + 1] = "Peak lines in one frame: " .. tostring(math.floor(peak)) end
        local warnings = type(result.warnings) == "table" and result.warnings or {}
        if #warnings > 0 then
            values[#values + 1] = ""
            values[#values + 1] = "Warnings:"
            for index = 1, math.min(#warnings, 12) do values[#values + 1] = "- " .. tostring(warnings[index]) end
            if #warnings > 12 then values[#values + 1] = "- ... and " .. tostring(#warnings - 12) .. " more warnings." end
        end
        values[#values + 1] = ""
        values[#values + 1] = "Insert the converted ASS lines?"
        return table.concat(values, "\n")
    end

    local function confirmInsertion(result, fallbackLines, fallbackChars)
        local button = aegisub.dialog.display({
            { class = "textbox", value = conversionSummary(result, fallbackLines, fallbackChars), x = 0, y = 0, width = 62, height = 14 },
        }, { "Insert", "Cancel" }, { ok = "Insert", close = "Cancel" })
        return button == "Insert"
    end

    local ShapeClipper

    local function bakeDrawingClip(tags, drawing)
        local clip = tags:match("\\clip%(([^)]*)%)")
        if not clip then return tags, drawing, false end
        local p = assert(tonumber(tags:match("\\p(%d+)")), "Drawing scale is missing.")
        local x, y = tags:match("\\pos%(([^,]+),([^)]*)%)")
        x, y = assert(finiteNumber(x)), assert(finiteNumber(y))
        local clipScale, clipPath = clip:match("^%s*(%d+)%s*,%s*(m%s.+)$")
        if not clipPath then clipScale, clipPath = 1, clip:match("^%s*(m%s.+)$") end
        if not clipPath then
            local coords = {}
            for value in clip:gmatch("[^,]+") do coords[#coords + 1] = assert(finiteNumber(trim(value)), "Invalid rectangle clip.") end
            assert(#coords == 4, "Unsupported SVG clip.")
            clipPath = string.format("m %.6f %.6f l %.6f %.6f %.6f %.6f %.6f %.6f", coords[1], coords[2], coords[3], coords[2], coords[3], coords[4], coords[1], coords[4])
        end


        local drawScale = 2 ^ (p - 1)
        local screenScale = 2 ^ (tonumber(clipScale) - 1)
        local subject = AssDrawing.mapCoordinates(drawing, function(a, b) return a * 32 / drawScale, b * 32 / drawScale end, 6)
        local cutter = AssDrawing.mapCoordinates(clipPath, function(a, b) return (a / screenScale - x) * 32, (b / screenScale - y) * 32 end, 6)
        ShapeClipper = ShapeClipper or require("ZF.main.2D.clipper").CLIPPER

        local outside = ShapeClipper(subject, cutter, true):clipper("difference", "non_zero"):build()
        if trim(outside) ~= "" then
            local clipped = ShapeClipper(subject, cutter, true):clipper("intersection", "non_zero"):build(nil, 1, 6)
            if trim(clipped) == "" then return tags, nil, true end
            drawing = AssDrawing.mapCoordinates(clipped, function(a, b) return a * drawScale / 32, b * drawScale / 32 end, 6)
        end
        return tags:gsub("\\clip%b()", ""), drawing, true
    end

    local function removeStyleDefaults(tags, style)
        if not style then return tags end


        if tags:find("\\t%(") or tags:find("\\r") then return tags end
        local defaults = {
            an = style.align, bord = style.outline, shad = style.shadow,
            fscx = style.scale_x, fscy = style.scale_y, frz = style.angle,
            frx = 0, fry = 0, fax = 0, fay = 0, pbo = 0, blur = 0, be = 0,
        }
        local function hex(value)
            local digits = type(value) == "string" and value:match("&?[Hh]([%x]+)&?")
            return digits and tonumber(digits, 16) or nil
        end
        for channel = 1, 4 do
            local color = hex(style["color" .. channel])
            if color then
                defaults[channel .. "c"] = color % 16777216
                defaults[channel .. "a"] = math.floor(color / 16777216) % 256
            end
        end
        local entries, last = {}, {}
        for name, value in tags:gmatch("\\([1-4]?[a-z]+)([^\\]*)") do
            if name == "c" then name = "1c" end
            entries[#entries + 1] = { name = name, value = value }
            if defaults[name] ~= nil then last[name] = #entries end
        end
        local border = last.bord and finiteNumber(trim(entries[last.bord].value)) or style.outline
        local shadow = last.shad and finiteNumber(trim(entries[last.shad].value)) or style.shadow
        local noBorder = tonumber(style.borderstyle) == 1 and border == 0 and not tags:find("\\[xy]bord")
        local noShadow = shadow == 0 and not tags:find("\\[xy]shad")
        local output = {}
        for index, entry in ipairs(entries) do
            local name, value = entry.name, entry.value
            local isHex = name:match("^[1-4][ac]$")
            local numeric = isHex and hex(value) or finiteNumber(trim(value))
            if name == "alpha" then
                local alpha = hex(value)
                for channel = 1, 4 do defaults[channel .. "a"] = alpha end
            end
            local redundant = defaults[name] ~= nil and numeric ~= nil and math.abs(numeric - defaults[name]) < 0.0000001


            local repeated = last[name] and last[name] ~= index and not name:match("^[1-4]a$")
            local invisible = noBorder and (name == "3a" or name == "3c") or noShadow and (name == "4a" or name == "4c")
            if not redundant and not repeated and not invisible then output[#output + 1] = "\\" .. name .. value end
            if not repeated and defaults[name] ~= nil and numeric ~= nil then defaults[name] = numeric end
        end
        return table.concat(output)
    end

    local function prepareDrawings(subs, groups, source, jobs)
        local styles, clipped, softClips = {}, 0, false
        for i = 1, #subs do
            local line = subs[i]
            if line.class == "style" then styles[line.name] = line end
        end
        for groupIndex, group in ipairs(groups) do
            local target = jobs and jobs[groupIndex].line or source
            local prepared = {}
            for _, text in ipairs(group) do
                if cancellationRequested() then error(CANCELLED, 0) end
                local tags, drawing = text:match("^%{([^}]*)%}%s*(.-)%s*%{\\p0%}%s*$")
                assert(tags and drawing, "Expected a generated ASS drawing.")
                local oldTags, hadClip = tags
                tags, drawing, hadClip = bakeDrawingClip(tags, drawing)
                if hadClip then
                    clipped = clipped + 1
                    for name, value in oldTags:gmatch("\\([a-z]+)([%d%.]+)") do
                        if (name == "blur" or name == "bord") and tonumber(value) > 0 then softClips = true end
                    end
                end
                if drawing then
                    tags = removeStyleDefaults(tags, styles[target.style])
                    local line = "{" .. tags .. "}" .. drawing .. "{\\p0}"
                    assert(validAssShapeLine(line), "Postprocessed ASS drawing is invalid.")
                    prepared[#prepared + 1] = line
                end
            end
            groups[groupIndex] = prepared
        end
        return clipped, softClips
    end

    local function makeShapeLine(source, assText, startTime, endTime)
        local line = copyLine(source)
        line.comment = false
        line.layer = (tonumber(source.layer) or 0) + 1
        line.text = assText
        if startTime ~= nil then line.start_time = startTime end
        if endTime ~= nil then line.end_time = endTime end
        return line
    end

    local function selectedDialogueRecords(subs, sel)
        local records, rejected = LineOps.selectedLines(subs, sel, function(line)
            return line and line.class == "dialogue" and not line.comment
        end, true)
        if not records or #records == 0 then
            local suffix = rejected and #rejected > 0 and (" Invalid rows: " .. table.concat(rejected, ", ")) or ""
            return nil, "Select only uncommented dialogue lines." .. suffix
        end
        return records
    end

    local frameFromMs = Media.frameFromMs
    local msFromFrame = Media.msFromFrame

    local function buildFrameJobs(subs, sel)
        if not aegisub or not aegisub.frame_from_ms or not aegisub.ms_from_frame then return nil, "A loaded video is required to map images to frames." end
        local records, message = selectedDialogueRecords(subs, sel)
        if not records then return nil, message end
        local jobs = {}
        for _, record in ipairs(records) do
            if cancellationRequested() then return nil, CANCELLED end
            local lineStart = finiteNumber(record.line.start_time)
            local lineEnd = finiteNumber(record.line.end_time)
            if not lineStart or not lineEnd or lineEnd <= lineStart then
                return nil, "Selected row " .. tostring(record.index) .. " has invalid timing."
            end
            local startFrame = frameFromMs(lineStart)
            local endFrame = frameFromMs(lineEnd)
            if not startFrame or not endFrame then return nil, "Could not read frame timing from selected row " .. tostring(record.index) .. "." end
            startFrame = math.floor(startFrame)
            endFrame = math.floor(endFrame)
            if endFrame <= startFrame then return nil, "Selected row " .. tostring(record.index) .. " does not cover a video frame." end
            for frame = startFrame, endFrame - 1 do
                if #jobs % insertChunkSize == 0 and cancellationRequested() then return nil, CANCELLED end
                local startMs = msFromFrame(frame)
                local endMs = msFromFrame(frame + 1)
                if not startMs or not endMs or endMs <= startMs then return nil, "Invalid frame timing at frame " .. tostring(frame) .. "." end
                startMs = math.max(startMs, lineStart)
                endMs = math.min(endMs, lineEnd)
                if endMs <= startMs then return nil, "Selected row " .. tostring(record.index) .. " has an empty frame intersection." end
                jobs[#jobs + 1] = {
                    index = record.index,
                    line = record.line,
                    frame = frame,
                    start_time = startMs,
                    end_time = endMs,
                    sequence_index = #jobs + 1,
                }
            end
        end
        if #jobs == 0 then return nil, "The selected lines do not cover any frames." end
        return jobs
    end

    local function readSequence(path, expectedFrames)
        local content, message = readFile(path, maxSequenceChars + 1)
        if not content then return nil, message or "Sequence output was not created." end
        if #content > maxSequenceChars then return nil, "Sequence output exceeds the character limit." end
        local rows = {}
        for line in (content .. "\n"):gmatch("([^\r\n]*)\r?\n") do rows[#rows + 1] = line end
        if trim(rows[1]) ~= "PNG2ASS_SEQUENCE 1" then return nil, "Sequence output has an unsupported format." end
        local frames = {}
        local expectedIndex = 1
        local totalLines = 0
        local cursor = 2
        while cursor <= #rows do
            if cursor % insertChunkSize == 0 then
                setProgress("Validating ASS sequence", cursor / math.max(1, #rows) * 100)
                if cancellationRequested() then return nil, CANCELLED end
            end
            local row = trim(rows[cursor])
            if row == "" then
                cursor = cursor + 1
            else
                local frameIndex = finiteNumber(row:match("^FRAME%s+(%d+)$"))
                if not frameIndex or frameIndex ~= expectedIndex then return nil, "Sequence frame order is invalid near line " .. tostring(cursor) .. "." end
                cursor = cursor + 1
                local count = finiteNumber(trim(rows[cursor] or ""):match("^LINES%s+(%d+)$"))
                if not count or count < 0 or count ~= math.floor(count) then return nil, "Sequence output has an invalid line count for frame " .. tostring(frameIndex) .. "." end
                totalLines = totalLines + count
                if totalLines > maxSequenceLines then return nil, "Sequence output exceeds the ASS line limit." end
                cursor = cursor + 1
                local assLines = {}
                for _ = 1, count do
                    if cursor > #rows then return nil, "Sequence output ended before frame " .. tostring(frameIndex) .. " was complete." end
                    if trim(rows[cursor]) == "" then return nil, "Sequence output contains an empty ASS line for frame " .. tostring(frameIndex) .. "." end
                    if not validAssShapeLine(rows[cursor]) then return nil, "Sequence output contains an invalid ASS drawing for frame " .. tostring(frameIndex) .. "." end
                    assLines[#assLines + 1] = rows[cursor]
                    cursor = cursor + 1
                end
                frames[frameIndex] = assLines
                expectedIndex = expectedIndex + 1
            end
        end
        local frameCount = expectedIndex - 1
        if expectedFrames and frameCount ~= expectedFrames then return nil, "Sequence output contains " .. tostring(frameCount) .. " frames; expected " .. tostring(expectedFrames) .. "." end
        return frames
    end

    local function insertOperationsCancellable(subs, operations)
        local total = 0
        for _, operation in ipairs(operations) do total = total + #(operation.lines or {}) end
        local completed = 0
        local descending = {}
        for _, operation in ipairs(operations) do descending[#descending + 1] = operation end
        table.sort(descending, function(left, right) return left.index > right.index end)
        for _, operation in ipairs(descending) do
            local offset = 0
            while offset < #operation.lines do
                if cancellationRequested() then error(CANCELLED, 0) end
                local chunk = {}
                local last = math.min(#operation.lines, offset + insertChunkSize)
                for position = offset + 1, last do chunk[#chunk + 1] = operation.lines[position] end
                subs.insert(operation.index + offset, unpack(chunk))
                offset = last
                completed = completed + #chunk
                setProgress("Inserting ASS lines", completed / math.max(1, total) * 100)
            end
        end
        local ascending = {}
        for _, operation in ipairs(operations) do ascending[#ascending + 1] = operation end
        table.sort(ascending, function(left, right) return left.index < right.index end)
        local inserted = {}
        local shift = 0
        for _, operation in ipairs(ascending) do
            local first = operation.index + shift
            for offset = 0, #operation.lines - 1 do inserted[#inserted + 1] = first + offset end
            shift = shift + #operation.lines
        end
        return inserted
    end

    local function insertShapes(subs, index, assLines)
        local source = copyLine(subs[index])
        local lines = {}
        for position, assText in ipairs(assLines) do
            if position % insertChunkSize == 0 and cancellationRequested() then error(CANCELLED, 0) end
            lines[#lines + 1] = makeShapeLine(source, assText)
        end
        return LineOps.transaction(subs, script_name, function()
            return insertOperationsCancellable(subs, { { index = index + 1, lines = lines } })
        end)
    end

    local function insertSequenceShapes(subs, jobs, frames)
        local grouped = {}
        local order = {}
        for jobIndex, job in ipairs(jobs) do
            if jobIndex % insertChunkSize == 0 and cancellationRequested() then error(CANCELLED, 0) end
            local assLines = frames[job.sequence_index]
            if not assLines then return nil, "Missing converted shape for frame " .. tostring(job.sequence_index) .. "." end
            if not grouped[job.index] then grouped[job.index] = {}; order[#order + 1] = job.index end
            for _, assText in ipairs(assLines) do
                grouped[job.index][#grouped[job.index] + 1] = makeShapeLine(job.line, assText, job.start_time, job.end_time)
            end
        end
        table.sort(order)
        local operations = {}
        for _, index in ipairs(order) do
            if #grouped[index] > 0 then operations[#operations + 1] = { index = index + 1, lines = grouped[index] } end
        end
        if #operations == 0 then return {} end
        return LineOps.transaction(subs, script_name, function() return insertOperationsCancellable(subs, operations) end)
    end

    function PNG2ASS.Main(subs, sel, activeLine)
        local records, selectionError = selectedDialogueRecords(subs, sel)
        if not records then cancelWith(selectionError) end
        local index = records[1].index
        for _, record in ipairs(records) do
            if record.index == activeLine then index = record.index; break end
        end
        local line = subs[index]
        local cfg = readConfig()
        local imagePaths = selectPngs()
        local frameJobs
        if #imagePaths > 1 then
            local message
            frameJobs, message = buildFrameJobs(subs, sel)
            if not frameJobs then cancelWith(message) end
            if #imagePaths ~= #frameJobs then
                cancelWith("Image count does not match selected frame count.\n\nImages: " .. tostring(#imagePaths) .. "\nFrames: " .. tostring(#frameJobs))
            end
        end
        local isSvg = imagePaths[1]:lower():match("%.svg$") ~= nil
        local options = createDialog(line, cfg, #imagePaths, frameJobs and #frameJobs or nil, isSvg)
        local posX, posY, positionError = resolvePosition(options, line)
        if not posX then cancelWith(positionError) end
        local paths, pathError = allocateTempPaths()
        if not paths then cancelWith(pathError or "Could not allocate temporary files.") end
        local completed, selection, active = pcall(function()
            local sequence = #imagePaths > 1
            local command, commandError, arguments
            if sequence then
                local wrote, message = writeFile(paths.list, table.concat(imagePaths, "\n"))
                if not wrote then cancelWith(message or "Could not create the image list.") end
                command, commandError, arguments = buildSequenceCommand(paths, options, posX, posY)
            else
                command, commandError, arguments = buildCommand(paths, imagePaths[1], options, posX, posY)
            end
            if not command then cancelWith(commandError or "Could not build the conversion command.") end
            local ok, log, wasCancelled = runManagedBackend(options.python, arguments, paths)
            if wasCancelled then aegisub.cancel() end
            if not ok then cancelWith(log and trim(log) ~= "" and log or "Image conversion failed. Open Hephaestus Fansubber/Check/Auto Drawing.") end
            local data, message
            if sequence then data, message = readSequence(paths.sequence, #frameJobs)
            else data, message = readLines(paths.out) end
            if message == CANCELLED then aegisub.cancel() end
            if not data or not sequence and #data == 0 then cancelWith(message or "Conversion produced no ASS drawings.") end
            local groups = sequence and data or {data}
            local _, softClips = prepareDrawings(subs, groups, line, frameJobs)
            data = sequence and groups or groups[1]
            local totalLines, totalChars = 0, 0
            for _, lines in ipairs(groups) do
                totalLines = totalLines + #lines
                for _, text in ipairs(lines) do totalChars = totalChars + #text end
            end
            assert(totalChars <= maxSequenceChars, "Clipped drawings exceed the character limit.")
            if totalLines == 0 then
                showMessage("The clip removed every drawing. No lines were inserted.")
                return sel, activeLine
            end
            local result = decodeJsonFile(paths.result) or {}
            result.lines, result.chars = totalLines, totalChars
            if softClips then
                result.warnings = result.warnings or {}
                result.warnings[#result.warnings + 1] = "Clip tags were baked into geometry with Everything Shape. Blur and borders can extend past the cut edge."
            end
            if not confirmInsertion(result, totalLines, totalChars) then aegisub.cancel() end
            local inserted, newSel, insertError
            if sequence then inserted, newSel, insertError = pcall(insertSequenceShapes, subs, frameJobs, data)
            else inserted, newSel, insertError = pcall(insertShapes, subs, index, data) end
            if not inserted and tostring(newSel) == CANCELLED then aegisub.cancel() end
            if not inserted or not newSel then cancelWith(insertError or ("Could not insert converted shapes atomically: " .. tostring(newSel or "unknown error"))) end
            local saved, saveError = persistOptions(options, cfg)
            if not saved then showMessage("Conversion completed, but settings could not be saved:\n" .. tostring(saveError or "unknown error")) end
            if #newSel == 0 then return sel, activeLine end
            return newSel, newSel[1]
        end)
        PyBridge.cleanup(paths)
        if not completed then error(selection, 0) end
        return selection, active
    end

    function PNG2ASS.CanRun(subs, sel)
        local records = selectedDialogueRecords(subs, sel)
        return records ~= nil
    end

    PNG2ASS.main = PNG2ASS.Main
    PNG2ASS.can_run = PNG2ASS.CanRun

    if aegisub and aegisub.register_macro then
        Olympus.register("png2ass", {{"Convert",script_description,PNG2ASS.Main,PNG2ASS.CanRun,oldPaths={"PNG2ASS/PNG2ASS","PNG2ASS/Convert"}}},script_namespace,depctrl)
    end



    return PNG2ASS
end

local function registerAutoTiming(record)
local function createAudio()
local Olympus, Bridge, UI = Automatons, require("kite.PyBridge"), require("kite.UI")
local mediaFilter = "Audio and video|*.wav;*.flac;*.opus;*.ogg;*.mp3;*.aac;*.m4a;*.mkv;*.mp4;*.avi;*.mov;*.ts;*.m4v;*.webm|All files|*.*"
local videoFilter = "Video|*.mkv;*.mp4;*.avi;*.mov;*.ts;*.m4v;*.webm|All files|*.*"

local function directory(path)
    local parent = Bridge.parentPath(path) or ""
    return parent:match("^%a:$") and parent .. "\\" or parent
end

local function chooseFile(title, current, filter)
    local selected = aegisub.dialog.open(title, "", directory(current), filter, false, true)
    if type(selected) == "table" then selected = selected[1] end
    return type(selected) == "string" and selected ~= "" and selected or current
end

local function readOptions(mode)
    local separation = mode == "isolate" or mode == "all"
    local input = Bridge.Media.projectPath(mode == "keyframes" and "video" or "audio", {fallbackVideo=true}) or ""
    local values = {input=input, output=directory(input), video="", profile="quality", format="opus", overwrite=false}
    if mode == "all" then values.video = Bridge.Media.projectPath("video") or "" end
    while true do
        local controls = {
            {class="label", label=separation and "quality: current BS-RoFormer model. fast: MDX-Net." or mode == "signals" and "Use isolated vocals with the original full timeline." or "The complete input timeline is preserved.", x=0,y=0,width=14,height=1},
            {class="label", label="Input file", x=0,y=1,width=3,height=1},
            {class="edit", name="input", value=values.input, x=3,y=1,width=11,height=1},
            {class="label", label="Output folder", x=0,y=2,width=3,height=1},
            {class="edit", name="output", value=values.output, x=3,y=2,width=11,height=1},
        }
        local row = 3
        if separation then
            controls[#controls + 1] = {class="label", label="Separation profile", x=0,y=row,width=3,height=1}
            controls[#controls + 1] = {class="dropdown", name="profile", items={"quality","fast"}, value=values.profile, x=3,y=row,width=4,height=1}
            controls[#controls + 1] = {class="label", label="Vocals format", x=7,y=row,width=3,height=1}
            controls[#controls + 1] = {class="dropdown", name="format", items={"opus","wav"}, value=values.format, x=10,y=row,width=4,height=1}
            row = row + 1
        end
        if mode == "all" then
            controls[#controls + 1] = {class="label", label="Video for keyframes (optional)", x=0,y=row,width=5,height=1}
            controls[#controls + 1] = {class="edit", name="video", value=values.video, x=5,y=row,width=9,height=1}
            row = row + 1
        end
        controls[#controls + 1] = {class="checkbox", name="overwrite", label="Replace existing generated files", value=values.overwrite, x=0,y=row,width=14,height=1}
        local buttons = mode == "all" and {"Run","Choose input","Choose video","Cancel"} or {"Run","Choose input","Cancel"}
        local button, edited = aegisub.dialog.display(controls, buttons, {ok="Run",close="Cancel"})
        if button == "Cancel" or not button then return end
        for key, value in pairs(edited) do values[key] = value end
        if button == "Choose input" then
            local previous = values.input
            values.input = chooseFile("Auto Timing input", previous, mode == "keyframes" and videoFilter or mediaFilter)
            if values.output == "" or values.output == directory(previous) then values.output = directory(values.input) end
        elseif button == "Choose video" then
            values.video = chooseFile("Video for keyframes", values.video, videoFilter)
        elseif button == "Run" then
            values.input, values.output, values.video = Bridge.trim(values.input), Bridge.trim(values.output), Bridge.trim(values.video)
            if not Bridge.fileExists(values.input) then
                UI.message("Select an existing audio or video file.")
            elseif values.output == "" then
                UI.message("Enter an output folder.")
            elseif mode == "all" and values.video ~= "" and not Bridge.fileExists(values.video) then
                UI.message("Select an existing video or clear the optional video field.")
            else
                return values
            end
        end
    end
end

local function process(mode, selection, keyframeSuffix)
    local options = readOptions(mode)
    if not options then return selection end
    local arguments = {mode, options.input, "--output-dir", options.output}
    if mode == "isolate" or mode == "all" then
        arguments[#arguments + 1] = "--profile"
        arguments[#arguments + 1] = options.profile
        arguments[#arguments + 1] = "--format"
        arguments[#arguments + 1] = options.format
    end
    if mode == "all" and options.video ~= "" then
        arguments[#arguments + 1] = "--video"
        arguments[#arguments + 1] = options.video
    end
    if mode == "keyframes" or mode == "all" then
        arguments[#arguments+1] = "--keyframe-suffix"
        arguments[#arguments+1] = keyframeSuffix or "_keyframes.log"
    end
    if options.overwrite then arguments[#arguments + 1] = "--overwrite" end
    local paths, pathError = Bridge.tempPaths("chrono_audio", {work=".work"})
    if not paths then UI.message(pathError); return selection end
    arguments[#arguments + 1] = "--work-dir"
    arguments[#arguments + 1] = paths.work
    local command, message = Olympus.command("chrono_audio", arguments)
    if not command then UI.message(message); return selection end
    aegisub.progress.title("Auto Timing")
    aegisub.progress.task("Processing the complete input; this may take several minutes.")
    local called, ok, detail = pcall(Bridge.runProcess, {executable=Olympus.python(), args=Olympus.arguments("chrono_audio", arguments)})
    if not called then detail, ok = ok, false end
    local cleanupCommand, cleanupError = Olympus.command("chrono_audio", {"cleanup-work", paths.work})
    local cleaned, cleanupDetail = false, cleanupError
    if cleanupCommand then cleaned, cleanupDetail = Bridge.run(cleanupCommand) end
    if not cleaned then detail = tostring(detail or "") .. "\nTemporary files could not be removed: " .. tostring(cleanupDetail or paths.work) end
    UI.message((ok and "Auto Timing completed.\n" or "Auto Timing did not complete.\n") .. tostring(detail or ""))
    return selection
end


return {run=process}

end
local function createWaveform()
local script_name = "Auto Timing Waveform"
local script_description = "Export the active audio waveform to JSON."
local script_author = "Kiterow"
local script_version = "1.3.7"
local script_namespace = "kite.TimingWaveform"
local sampleRate = 48000
local channels = 1
local bits = 16
local bytesPerSample = bits / 8
local basePointMs = 1
local samplesPerPoint = sampleRate * basePointMs / 1000
local readBytes = 262144
local sampleModulus = 2 ^ bits
local sampleMidpoint = sampleModulus / 2
local amplitudeMin = -sampleMidpoint
local amplitudeMax = sampleMidpoint - 1
local byteBase = 256
local PyBridge, Core = require("kite.PyBridge"), require("kite.Core")
local LineOps, Media = Core.LineOps, PyBridge.Media
local sharedUI = require("kite.UI")
local trim = LineOps.trim
local roundInt = LineOps.round
local fileExists = PyBridge.fileExists
local joinPath = PyBridge.joinPath
local removeFile = PyBridge.removeFile
local writeChecked
writeChecked = function(file, ...)
  local written, message = file:write(...)
  if not (written) then
    error(message or "Could not write output.")
  end
  return written
end
local ffmpegTime
ffmpegTime = function(ms)
  return string.format("%.3f", math.max(0, Core.finiteNumber(ms) or 0) / 1000)
end
local dirName
dirName = function(path)
  return tostring(path or ""):match("^(.*)[\\/]") or ""
end
local baseName
baseName = function(path)
  local name = tostring(path or ""):match("([^\\/]+)$") or tostring(path or "")
  name = name:gsub("%.[^%.\\/]*$", "")
  if name == "" then
    return "waveform"
  else
    return name
  end
end
local safeName
safeName = function(value, fallback)
  if fallback == nil then
    fallback = "wave2json"
  end
  local out = trim(value):gsub("[%z\1-\31\\/:*?\"<>|]+", "_"):gsub("%s+", "_")
  out = out:gsub("_+", "_")
  out = out:gsub("^_+", "")
  out = out:gsub("_+$", "")
  out = out:gsub("[%.%s]+$", "")
  local lower = out:lower():match("^[^%.]+") or ""
  local reserved = lower == "con" or lower == "prn" or lower == "aux" or lower == "nul" or lower:match("^com[1-9]$") or lower:match("^lpt[1-9]$")
  if out == "" or out == "." or out == ".." or out:match("^%.+$") or reserved then
    return fallback
  end
  return out
end
local selectedLineRanges
selectedLineRanges = function(subs, sel)
  local records, rejected = LineOps.selectedLines(subs, sel, (function(line)
    if not (line and line.class == "dialogue" and not line.comment) then
      return false
    end
    local startTime, endTime = Core.finiteNumber(line.start_time), Core.finiteNumber(line.end_time)
    return startTime and endTime and endTime > startTime
  end), true)
  if not (records and #records > 0) then
    local suffix
    if rejected and #rejected > 0 then
      suffix = " Invalid rows: " .. table.concat(rejected, ", ")
    else
      suffix = ""
    end
    return nil, "Select only uncommented dialogue lines with valid timing." .. suffix
  end
  local ranges = { }
  for _index_0 = 1, #records do
    local record = records[_index_0]
    local startMs = math.max(0, roundInt(record.line.start_time))
    local endMs = roundInt(record.line.end_time)
    if endMs <= startMs then
      return nil, "Line " .. tostring(record.index) .. " has no positive duration after clipping to the media start."
    end
    ranges[#ranges + 1] = {
      startMs = startMs,
      endMs = endMs,
      durationMs = endMs - startMs,
      lineCount = 1,
      lineIndex = record.index
    }
  end
  return ranges
end
local selectionRange
selectionRange = function(subs, sel)
  local ranges, message = selectedLineRanges(subs, sel)
  if not (ranges) then
    return nil, message
  end
  local startMs, endMs = ranges[1].startMs, ranges[1].endMs
  for _index_0 = 1, #ranges do
    local range = ranges[_index_0]
    if range.startMs < startMs then
      startMs = range.startMs
    end
    if range.endMs > endMs then
      endMs = range.endMs
    end
  end
  return {
    startMs = startMs,
    endMs = endMs,
    durationMs = endMs - startMs,
    lineCount = #ranges
  }
end
local mediaCandidate
mediaCandidate = function()
  local path = Media.projectPath("audio", {
    fallbackVideo = true
  })
  if path then
    return path, "audio"
  end
  return "", "manual"
end
local rangeSuffix
rangeSuffix = function(range)
  if not (range) then
    return ""
  end
  return "_" .. tostring(roundInt(range.startMs)) .. "-" .. tostring(roundInt(range.endMs)) .. "ms"
end
local defaultOutputPath
defaultOutputPath = function(media, range)
  if range == nil then
    range = nil
  end
  local ass = LineOps.subtitlePath() or ""
  local root
  if ass ~= "" then
    root = dirName(ass)
  else
    root = dirName(media)
  end
  local source
  if ass ~= "" then
    source = ass
  else
    source = media
  end
  return joinPath(root, tostring(safeName(baseName(source), "waveform")) .. tostring(rangeSuffix(range)) .. ".waveform.json")
end
local outputStem
outputStem = function(path)
  local name = tostring(path or ""):match("([^\\/]+)$") or ""
  name = name:gsub("%.waveform%.json$", "")
  name = name:gsub("%.[^%.\\/]*$", "")
  return safeName(name, "waveform")
end
local outputRoot
outputRoot = function(outputPath, media)
  local folder = dirName(outputPath)
  if folder ~= "" then
    return folder
  end
  folder = dirName(media)
  if folder ~= "" then
    return folder
  else
    return (LineOps.decodedPath("?temp") or "")
  end
end
local lineOutputPath
lineOutputPath = function(baseOutput, media, range, order)
  local folder = dirName(baseOutput)
  if folder == "" then
    folder = outputRoot(baseOutput, media)
  end
  local stem = outputStem(baseOutput)
  local lineNumber = string.format("%03d", math.max(1, tonumber(order) or 1))
  return joinPath(folder, tostring(stem) .. "_line" .. tostring(lineNumber) .. tostring(rangeSuffix(range)) .. ".waveform.json")
end
local progressTitle
progressTitle = function(text)
  if aegisub and aegisub.progress and aegisub.progress.title then
    pcall(aegisub.progress.title, tostring(text or ""))
  end
  return LineOps.checkCancelled()
end
local progressTask
progressTask = function(text)
  return LineOps.progress(text)
end
local progressSet
progressSet = function(value)
  return LineOps.progress(nil, value)
end
local progressCancelled
progressCancelled = function()
  if not (aegisub and aegisub.progress and aegisub.progress.is_cancelled) then
    return false
  end
  local ok, cancelled = pcall(aegisub.progress.is_cancelled)
  return ok and cancelled == true
end
local showMessage
showMessage = function(text)
  return sharedUI.message(text)
end
local runFfmpeg
runFfmpeg = function(cfg, pcmPath)
  local stream = Core.finiteNumber(cfg.stream or 0)
  if not (stream and stream >= 0 and stream == math.floor(stream)) then
    return false, "The audio stream must be a non-negative integer."
  end
  local executable, toolError = (require("kite.Automatons")).tool("ffmpeg")
  if not (executable) then
    return false, toolError
  end
  if executable == "" then
    executable = "ffmpeg"
  end
  if executable:match('^".*"$') or executable:match("^'.*'$") then
    executable = executable:sub(2, -2)
  end
  local arguments = {
    "-hide_banner",
    "-nostdin",
    "-loglevel",
    "error",
    "-y"
  }
  table.insert(arguments, "-i")
  table.insert(arguments, cfg.media)
  if cfg.range then
    local startMs, durationMs = Core.finiteNumber(cfg.range.startMs), Core.finiteNumber(cfg.range.durationMs)
    if not (startMs and startMs >= 0 and durationMs and durationMs > 0) then
      return false, "The audio range must have a finite start and positive duration."
    end
    table.insert(arguments, "-ss")
    table.insert(arguments, ffmpegTime(startMs))
    table.insert(arguments, "-t")
    table.insert(arguments, ffmpegTime(cfg.range.durationMs))
  end
  local _list_0 = {
    "-map",
    "0:a:" .. tostring(stream),
    "-vn",
    "-ac",
    tostring(channels),
    "-ar",
    tostring(sampleRate),
    "-f",
    "s16le",
    pcmPath
  }
  for _index_0 = 1, #_list_0 do
    local value = _list_0[_index_0]
    table.insert(arguments, value)
  end
  return PyBridge.runProcess({
    executable = executable,
    args = arguments
  })
end
local readConfig
readConfig = function()
  local media = mediaCandidate()
  if trim(media) == "" then
    return nil, "No active audio file is loaded."
  end
  return {
    media = media,
    output = defaultOutputPath(media),
    ffmpeg = "ffmpeg",
    stream = 0,
    range = nil
  }
end
local newPyramid
newPyramid = function(tempPrefix)
  local pyramid = {
    levels = { },
    tempPrefix = tempPrefix
  }
  pyramid.ensureLevel = function(self, index)
    local state = self.levels[index]
    if not (state) then
      local scale = 2 ^ (index - 1)
      local path = tostring(self.tempPrefix) .. "_level_" .. tostring(index) .. ".tmp"
      local file = io.open(path, "wb")
      if not (file) then
        error("Could not create temporary level file: " .. tostring(path))
      end
      state = {
        index = index,
        scale = scale,
        pointMs = basePointMs * scale,
        samplesPerPoint = samplesPerPoint * scale,
        points = 0,
        path = path,
        file = file,
        pendingCount = 0
      }
      self.levels[index] = state
    end
    return state
  end
  pyramid.emitPair = function(self, index, minValue, maxValue)
    local state = self:ensureLevel(index)
    writeChecked(state.file, tostring(roundInt(minValue)), ",", tostring(roundInt(maxValue)), "\n")
    state.points = state.points + 1
    if state.pendingCount == 0 then
      state.pendingMin = minValue
      state.pendingMax = maxValue
      state.pendingCount = 1
    else
      local cmin = math.min(state.pendingMin, minValue)
      local cmax = math.max(state.pendingMax, maxValue)
      state.pendingCount = 0
      return self:emitPair(index + 1, cmin, cmax)
    end
  end
  pyramid.flush = function(self)
    local index = 1
    while index <= #self.levels do
      local state = self.levels[index]
      if state and state.pendingCount == 1 and index < #self.levels then
        local minValue, maxValue = state.pendingMin, state.pendingMax
        state.pendingCount = 0
        self:emitPair(index + 1, minValue, maxValue)
      end
      index = index + 1
    end
    local _list_0 = self.levels
    for _index_0 = 1, #_list_0 do
      local state = _list_0[_index_0]
      if state.file then
        local closed, message = state.file:close()
        if not (closed) then
          error(message or "Could not finish temporary waveform level.")
        end
      end
      state.file = nil
    end
  end
  pyramid.cleanup = function(self)
    local _list_0 = (self.levels or { })
    for _index_0 = 1, #_list_0 do
      local state = _list_0[_index_0]
      pcall(function()
        if state.file then
          return state.file:close()
        end
      end)
      removeFile(state.path)
    end
  end
  return pyramid
end
local processPcm
processPcm = function(pcmPath, tempPrefix, totalBytes)
  if totalBytes == nil then
    totalBytes = nil
  end
  local input = io.open(pcmPath, "rb")
  if not (input) then
    return nil, "Could not open decoded PCM."
  end
  local pyramid = newPyramid(tempPrefix)
  local currentMin, currentMax = amplitudeMax, amplitudeMin
  local samplesInPoint = 0
  local totalSamples = 0
  local bytesRead = 0
  local leftover = ""
  local ok, result, failure = pcall(function()
    progressTask("Reading PCM and building waveform")
    while true do
      if progressCancelled() then
        return nil, "Cancelled."
      end
      local data, readError = input:read(readBytes)
      if readError then
        error(readError)
      end
      if not (data and #data > 0) then
        break
      end
      if leftover ~= "" then
        data = leftover .. data
        leftover = ""
      end
      if (#data % bytesPerSample) == 1 then
        leftover = data:sub(#data)
        data = data:sub(1, #data - 1)
      end
      bytesRead = bytesRead + #data
      if totalBytes and totalBytes > 0 then
        progressSet(20 + 70 * math.min(1, bytesRead / totalBytes))
      end
      local pos = 1
      local limit = #data
      while pos < limit do
        local lo = data:byte(pos)
        local hi = data:byte(pos + 1)
        local sample = lo + hi * byteBase
        if sample >= sampleMidpoint then
          sample = sample - sampleModulus
        end
        if sample < currentMin then
          currentMin = sample
        end
        if sample > currentMax then
          currentMax = sample
        end
        samplesInPoint = samplesInPoint + 1
        totalSamples = totalSamples + 1
        if samplesInPoint >= samplesPerPoint then
          pyramid:emitPair(1, currentMin, currentMax)
          currentMin, currentMax = amplitudeMax, amplitudeMin
          samplesInPoint = 0
        end
        pos = pos + bytesPerSample
      end
    end
    if leftover ~= "" then
      error("Decoded PCM ended with an incomplete sample.")
    end
    if totalBytes and bytesRead ~= totalBytes then
      error("Decoded PCM size changed while reading.")
    end
    if totalSamples == 0 then
      error("Decoded PCM contains no samples.")
    end
    if samplesInPoint > 0 then
      pyramid:emitPair(1, currentMin, currentMax)
    end
    pyramid:flush()
    local durationMs = totalSamples * 1000 / sampleRate
    return {
      pyramid = pyramid,
      durationMs = durationMs,
      totalSamples = totalSamples
    }, nil
  end)
  pcall(function()
    return input:close()
  end)
  if not (ok) then
    pyramid:cleanup()
    return nil, tostring(result)
  end
  if not (result) then
    pyramid:cleanup()
    return nil, failure
  end
  return result, nil
end
local copyLevelPeaks
copyLevelPeaks = function(out, level)
  local file = io.open(level.path, "rb")
  if not (file) then
    return false, "Could not read temporary level file."
  end
  local ok, failure = pcall(function()
    local first, count = true, 0
    local buffer, bytes = { }, 0
    local flush
    flush = function()
      if #buffer == 0 then
        return
      end
      LineOps.checkCancelled()
      writeChecked(out, ((function()
        if first then
          return ""
        else
          return ","
        end
      end)()), table.concat(buffer, ","))
      first, buffer, bytes = false, { }, 0
    end
    while true do
      local line, readError = file:read("*l")
      if readError then
        error(readError)
      end
      if not (line) then
        break
      end
      buffer[#buffer + 1] = line
      bytes = bytes + #line + 1
      count = count + 1
      if bytes >= readBytes then
        flush()
      end
    end
    if not (count == level.points) then
      error("Temporary waveform level is incomplete.")
    end
    return flush()
  end)
  file:close()
  if not (ok) then
    return false, tostring(failure)
  end
  return true
end
local writeJson
writeJson = function(outputPath, result)
  return PyBridge.withAtomicFile(outputPath, function(out)
    local pyramid = result.pyramid
    writeChecked(out, "{\n")
    writeChecked(out, '  "type": "waveform",\n')
    writeChecked(out, '  "version": 1,\n')
    writeChecked(out, '  "sampleRate": ', tostring(sampleRate), ",\n")
    writeChecked(out, '  "channels": ', tostring(channels), ",\n")
    writeChecked(out, '  "bits": ', tostring(bits), ",\n")
    writeChecked(out, '  "amplitudeFormat": "s16",\n')
    writeChecked(out, '  "amplitudeMin": ', tostring(amplitudeMin), ',\n')
    writeChecked(out, '  "amplitudeMax": ', tostring(amplitudeMax), ',\n')
    writeChecked(out, '  "pointLayout": "interleavedMinMax",\n')
    if result.range then
      writeChecked(out, '  "sourceStartMs": ', tostring(result.range.startMs), ",\n")
      writeChecked(out, '  "sourceEndMs": ', tostring(result.range.endMs), ",\n")
      writeChecked(out, '  "sourceDurationMs": ', tostring(result.range.durationMs), ",\n")
      writeChecked(out, '  "sourceLineCount": ', tostring(result.range.lineCount), ",\n")
    end
    writeChecked(out, '  "durationMs": ', Core.formatNumber(result.durationMs, 6), ",\n")
    writeChecked(out, '  "totalSamples": ', tostring(result.totalSamples), ",\n")
    writeChecked(out, '  "levels": [\n')
    for i, level in ipairs(pyramid.levels) do
      if i > 1 then
        writeChecked(out, ",\n")
      end
      writeChecked(out, "    {\n")
      writeChecked(out, '      "scale": ', tostring(level.scale), ",\n")
      writeChecked(out, '      "pointMs": ', tostring(level.pointMs), ",\n")
      writeChecked(out, '      "samplesPerPoint": ', tostring(level.samplesPerPoint), ",\n")
      writeChecked(out, '      "points": ', tostring(level.points), ",\n")
      writeChecked(out, '      "peaks": [')
      local copied, copyError = copyLevelPeaks(out, level)
      if not (copied) then
        error(copyError)
      end
      writeChecked(out, "]\n")
      writeChecked(out, "    }")
    end
    writeChecked(out, "\n  ]\n")
    return writeChecked(out, "}\n")
  end)
end
local exportWaveform
exportWaveform = function(cfg)
  if trim(cfg.media) == "" then
    return false, "Choose an audio or video file."
  end
  if not (fileExists(cfg.media)) then
    return false, "Media file does not exist:\n" .. tostring(cfg.media)
  end
  if trim(cfg.output) == "" then
    return false, "Choose a JSON output path."
  end
  local root = outputRoot(cfg.output, cfg.media)
  if trim(root) == "" then
    return false, "Could not resolve an output folder."
  end
  if dirName(cfg.output) == "" then
    cfg.output = joinPath(root, cfg.output)
  end
  local made, makeError = PyBridge.ensureDir(root)
  if not (made) then
    return false, "Could not create output folder: " .. tostring(makeError or root)
  end
  local paths, pathError = PyBridge.tempPaths("wave2json", {
    pcm = ".s16le",
    prefix = ""
  })
  if not (paths) then
    return false, pathError or "Could not create temporary paths."
  end
  local pyramid = nil
  local pcallOk, success, message = pcall(function()
    progressTitle(script_name)
    progressTask("Decoding audio with FFmpeg")
    progressSet(5)
    local okFfmpeg, detail, code = runFfmpeg(cfg, paths.pcm)
    if code == 130 then
      return false, "Cancelled."
    end
    if not (okFfmpeg) then
      return false, "FFmpeg could not decode the selected audio stream.\n" .. tostring(detail or "")
    end
    local size = Media.fileSize(paths.pcm) or 0
    if size <= 0 then
      return false, "FFmpeg produced an empty PCM file."
    end
    progressSet(20)
    local result, err = processPcm(paths.pcm, paths.prefix, size)
    if err then
      return false, err
    end
    pyramid = result.pyramid
    result.range = cfg.range
    progressTask("Writing JSON")
    progressSet(95)
    local okJson, jsonErr = writeJson(cfg.output, result)
    if not (okJson) then
      return false, jsonErr
    end
    progressSet(100)
    local rangeText
    if cfg.range then
      rangeText = "\nRange: " .. tostring(cfg.range.startMs) .. " ms - " .. tostring(cfg.range.endMs) .. " ms"
    else
      rangeText = ""
    end
    return true, "Waveform JSON written:\n" .. tostring(cfg.output) .. tostring(rangeText) .. "\n\nDuration: " .. tostring(result.durationMs) .. " ms\nLevels: " .. tostring(#result.pyramid.levels)
  end)
  PyBridge.cleanup(paths)
  if pyramid then
    pyramid:cleanup()
  end
  if pcallOk then
    return success, message
  else
    return false, tostring(success)
  end
end
local exportLineRanges
exportLineRanges = function(cfg, ranges)
  if not (ranges and #ranges > 0) then
    return false, "Select at least one subtitle line with valid timing."
  end
  local firstOutput, lastOutput = nil, nil
  for i, range in ipairs(ranges) do
    local output = lineOutputPath(cfg.output, cfg.media, range, i)
    local lineCfg = {
      media = cfg.media,
      output = output,
      ffmpeg = cfg.ffmpeg,
      stream = cfg.stream,
      range = range
    }
    local ok, message = exportWaveform(lineCfg)
    if not (ok) then
      return false, "Line " .. tostring(range.lineIndex or i) .. " failed:\n" .. tostring(message)
    end
    if not (firstOutput) then
      firstOutput = output
    end
    lastOutput = output
  end
  local folder = dirName(firstOutput or cfg.output)
  return true, "Waveform JSON files written: " .. tostring(#ranges) .. "\nFolder: " .. tostring(folder) .. "\nFirst: " .. tostring(firstOutput) .. "\nLast: " .. tostring(lastOutput)
end
local readBaseConfig
readBaseConfig = function()
  local cfg, message = readConfig()
  if not (cfg) then
    showMessage(message)
    return nil
  end
  return cfg
end
local mainFull
mainFull = function()
  local cfg = readBaseConfig()
  if not (cfg) then
    return
  end
  local _, message = exportWaveform(cfg)
  return showMessage(message)
end
local mainSelection
mainSelection = function(subs, sel)
  local cfg = readBaseConfig()
  if not (cfg) then
    return
  end
  local range, rangeError = selectionRange(subs, sel)
  if not (range) then
    showMessage(rangeError)
    return
  end
  cfg.range = range
  cfg.output = defaultOutputPath(cfg.media, range)
  local _, message = exportWaveform(cfg)
  return showMessage(message)
end
local mainEach
mainEach = function(subs, sel)
  local cfg = readBaseConfig()
  if not (cfg) then
    return
  end
  local ranges, rangeError = selectedLineRanges(subs, sel)
  if not (ranges) then
    showMessage(rangeError)
    return
  end
  local first = ranges[1]
  cfg.output = defaultOutputPath(cfg.media, first)
  local _, message = exportLineRanges(cfg, ranges)
  return showMessage(message)
end
local canRunFull
canRunFull = function()
  local media = mediaCandidate()
  return trim(media) ~= ""
end
local canRunSelection
canRunSelection = function(subs, sel)
  local ranges = selectedLineRanges(subs, sel)
  return ranges ~= nil and canRunFull()
end
local result = {
  full = mainFull,
  selected = mainSelection,
  each = mainEach,
  canFull = canRunFull,
  canSelection = canRunSelection,
  version = script_version
}
return result
end
    local function createTiming()
    local M = {}
    local KiteUI = require("kite.UI")
    local Timing = require("kite.Timing")
    local Kite = {Core=require("kite.Core"), PyBridge=require("kite.PyBridge")}
    Kite.LineOps, Kite.Media = Kite.Core.LineOps, Kite.PyBridge.Media
    local defaultConfig = {
        language          = "en",

        scxvid_suffix     = "_keyframes.log",

        lazyt_mode            = "Full Timing",
        lazyt_lead_in_ms      = 120,
        lazyt_lead_out_ms     = 420,
        lazyt_max_lead_out_ms = 800,
        lazyt_max_lead_in_ms  = 400,
        lazyt_kf_end_range_ms = 800,
        lazyt_kf_start_range_ms = 400,
        lazyt_kf_back_ms      = 100,
        lazyt_duration_floor_ms = 500,
        lazyt_cps_flag        = 28,
        lazyt_skip_signs      = true,
        lazyt_show_stats      = true,
        lazyt_style_filter    = "All",
        lazyt_extra_style     = "",
        lazyt_smooth_ms       = 10,
        lazyt_auto_otsu       = true,
        lazyt_fill_gap_ms     = 60,
        lazyt_min_island_ms   = 60,
        lazyt_outer_search_ms = 0,
        lazyt_edge_spill      = true,
        at_detector           = "Lazy",
        lzt_method            = "Cluster (Â±ms)",
        lzt_limit             = 800,
        lzt_silences_only     = false,



        scream_avg_db        = -13,
        scream_sample_db     = -17,
        scream_loud_ratio    = 35,
        scream_min_samples   = 3,
        scream_robust_z      = 0.50,
        scream_clean_previous = true,
        scream_reuse_log     = true,
        scream_scope         = "All dialogue",
    }

    local currentConfig, currentLang = {}, "en"
    local settings = KiteUI.settings("kite.AutoTiming", "1.0.0", {main=defaultConfig}, {
        {path="?user/config/kite.settings.json", format="json", section="kite.ChronoSuite"},
        {path="?user/chrono_suite_config.lua", format="lua_table", target="main"},
    })

    do
        local previous = KiteUI.Settings and KiteUI.Settings.readJson("?user/config/kite.settings.json")
        local chrono = previous and previous["kite.ChronoSuite"]
        if previous and not previous["kite.AutoTiming"] and type(chrono)=="table" and type(chrono.main)=="table" then
            settings:update("main", chrono.main)
            settings:write()
        end
    end
    local function resolveConfig()
        currentConfig = settings:values("main")
        currentLang = currentConfig.language or "en"
    end
    local function saveConfig()
        settings:update("main", currentConfig)
        return settings:write()
    end
    local L, UI = require("kite.Timing").Locale.new(function() return currentLang end)
    local showMsg = KiteUI.message
    resolveConfig()
    local function normalizeString(v) if type(v)=="string" then return v end if v==nil then return "" end return tostring(v) end
    local function normalizeNumber(v, fallback)
        local number = tonumber(v)
        if not number or number ~= number or math.abs(number) == math.huge then return fallback end
        return number
    end
    local trimText, roundNumber = Kite.Core.trim, Kite.Core.roundTo
    local function isDialogue(line) return type(line)=="table" and line.class=="dialogue" end
    local function getKeyframes()
        if aegisub and type(aegisub.keyframes) == "function" then
            local ok, k = pcall(aegisub.keyframes)
            if ok and type(k) == "table" then table.sort(k); return k end
        end
        return nil
    end

    local function msToFrame(ms)
        if aegisub and type(aegisub.frame_from_ms) == "function" then
            local ok, f = pcall(aegisub.frame_from_ms, ms); if ok and f then return f end
        end
        return nil
    end

    local function frameToMs(frame)
        if aegisub and type(aegisub.ms_from_frame) == "function" then
            local ok, ms = pcall(aegisub.ms_from_frame, frame); if ok and ms then return ms end
        end
        return nil
    end

    local function collectStyles(subs, sel)
        local st, seen = { "All", "All Default", "Default+Alt" }, {}
        for _, i in ipairs(sel) do
            if subs[i].class == "dialogue" and not seen[subs[i].style] then
                seen[subs[i].style] = true; st[#st+1] = subs[i].style
            end
        end
        return st
    end

    do

    local VTMOD

    local function getVT()
    if VTMOD then return VTMOD end

    local DEFAULTS = {
        lead_in_ms        = defaultConfig.lazyt_lead_in_ms,
        lead_out_ms       = defaultConfig.lazyt_lead_out_ms,
        max_lead_out_ms   = defaultConfig.lazyt_max_lead_out_ms,
        max_lead_in_ms    = defaultConfig.lazyt_max_lead_in_ms,
        kf_end_range_ms   = defaultConfig.lazyt_kf_end_range_ms,
        kf_start_range_ms = defaultConfig.lazyt_kf_start_range_ms,
        kf_back_ms        = defaultConfig.lazyt_kf_back_ms,
        duration_floor_ms = defaultConfig.lazyt_duration_floor_ms,
        cps_flag          = defaultConfig.lazyt_cps_flag,
        skip_signs        = defaultConfig.lazyt_skip_signs,
        show_stats        = defaultConfig.lazyt_show_stats,
        style_filter      = defaultConfig.lazyt_style_filter,
        extra_style       = defaultConfig.lazyt_extra_style,

        smooth_ms          = defaultConfig.lazyt_smooth_ms,
        auto_otsu          = defaultConfig.lazyt_auto_otsu,
        fill_gap_ms        = defaultConfig.lazyt_fill_gap_ms,
        min_island_ms      = defaultConfig.lazyt_min_island_ms,
        outer_search_ms    = defaultConfig.lazyt_outer_search_ms,
        edge_spill_cleanup = defaultConfig.lazyt_edge_spill,

        hist_bins                  = 96,
        floor_percentile           = 5,
        peak_percentile            = 95,
        sensitivity_per_mille      = 120,
        edge_near_ms               = 20,
        spill_mass_per_mille       = 300,
        spill_gap_factor_per_mille = 1000,
        min_voice_ms               = 50,
    }

    local configKeys = {
        lead_in_ms        = "lazyt_lead_in_ms",
        lead_out_ms       = "lazyt_lead_out_ms",
        max_lead_out_ms   = "lazyt_max_lead_out_ms",
        max_lead_in_ms    = "lazyt_max_lead_in_ms",
        kf_end_range_ms   = "lazyt_kf_end_range_ms",
        kf_start_range_ms = "lazyt_kf_start_range_ms",
        kf_back_ms        = "lazyt_kf_back_ms",
        duration_floor_ms = "lazyt_duration_floor_ms",
        cps_flag          = "lazyt_cps_flag",
        skip_signs        = "lazyt_skip_signs",
        show_stats        = "lazyt_show_stats",
        style_filter      = "lazyt_style_filter",
        extra_style       = "lazyt_extra_style",
        smooth_ms          = "lazyt_smooth_ms",
        auto_otsu          = "lazyt_auto_otsu",
        fill_gap_ms        = "lazyt_fill_gap_ms",
        min_island_ms      = "lazyt_min_island_ms",
        outer_search_ms    = "lazyt_outer_search_ms",
        edge_spill_cleanup = "lazyt_edge_spill",
    }

    local TUNE = {
        stack_eps_ms    = 40,
        keep_min_out_ms = 200,
        flash_gap_ms    = 250,
        cap_grace_ms    = 120,
        frame_grace_ms  = 45,
        min_event_ms    = 10,
    }

    local guiBounds = {
        lead_in_ms        = { min = 0 },
        lead_out_ms       = { min = 0 },
        max_lead_out_ms   = { min = 0 },
        max_lead_in_ms    = { min = 0 },
        kf_end_range_ms   = { min = 0 },
        kf_start_range_ms = { min = 0 },
        kf_back_ms        = { min = 0 },
        cps_flag          = { min = 1 },
        duration_floor_ms = { min = 0 },
        smooth_ms         = { min = 1 },
        fill_gap_ms       = { min = 0 },
        min_island_ms     = { min = 1 },
        outer_search_ms   = { min = 0 },
    }

    local function trim(s)
        return trimText(s or "")
    end

    local function round(x)
        return roundNumber(tonumber(x) or 0)
    end

    local function clamp(x, lo, hi)
        if x < lo then return lo end
        if x > hi then return hi end
        return x
    end

    local function lowerBound(list, value)
        local lo, hi = 1, #list + 1
        while lo < hi do
            local mid = math.floor((lo + hi) / 2)
            if list[mid] < value then lo = mid + 1 else hi = mid end
        end
        return lo
    end

    local function overlapLength(a0, a1, b0, b1)
        return math.min(a1, b1) - math.max(a0, b0)
    end

    local function progress(task, pct)
        if aegisub and aegisub.progress then
            if task and aegisub.progress.task then pcall(aegisub.progress.task, task) end
            if pct and aegisub.progress.set then pcall(aegisub.progress.set, pct) end
        end
    end

    local function saveAutoTimingConfig(c)
        for key, configKey in pairs(configKeys) do currentConfig[configKey] = c[key] end
        return saveConfig()
    end

    local function normalizeAutoTimingConfig(c)
        for k, v in pairs(DEFAULTS) do
            if c[k] == nil or type(c[k]) ~= type(v) then c[k] = v end
        end
        for k, b in pairs(guiBounds) do
            c[k] = math.max(b.min, round(normalizeNumber(c[k]) or DEFAULTS[k]))
        end
        if c.max_lead_out_ms < c.lead_out_ms then c.max_lead_out_ms = c.lead_out_ms end
        if c.max_lead_in_ms < c.lead_in_ms then c.max_lead_in_ms = c.lead_in_ms end
        return c
    end

    local function getAutoTimingConfig()
        local c = {}
        for k, v in pairs(DEFAULTS) do c[k] = v end
        for key, configKey in pairs(configKeys) do
            if currentConfig[configKey] ~= nil then c[key] = currentConfig[configKey] end
        end
        return normalizeAutoTimingConfig(c)
    end

    local function visibleAutoTimingText(text)
        if Kite.LineOps then return trim(Kite.LineOps.visibleText(text)) end
        local s = tostring(text or "")
        s = s:gsub("{[^}]*}", "")
        s = s:gsub("\\[Nn]", " ")
        s = s:gsub("\\h", " ")
        return trim(s)
    end

    local function utf8Length(s)
        s = tostring(s or "")
        local _, continuation = s:gsub("[\128-\191]", "")
        return #s - continuation
    end

    local function readableCharacters(text)
        local clean = visibleAutoTimingText(text)
        clean = clean:gsub("[%s%p]", "")
        clean = clean:gsub("\194\191", ""):gsub("\194\161", ""):gsub("\226\128\166", "")
        return utf8Length(clean)
    end

    local function styleMatches(style, flt, extra)
        flt = tostring(flt or "All")
        if flt == "" or flt == "All" then return true end
        style = tostring(style or "")
        local extraHit = extra ~= nil and extra ~= "" and style == extra
        local lowerStyle = style:lower()
        if flt == "All Default" then return lowerStyle:find("defa", 1, true) ~= nil or extraHit end
        if flt == "Default+Alt" then
            return lowerStyle:find("defa", 1, true) ~= nil or lowerStyle:find("alt", 1, true) ~= nil or extraHit
        end
        return style == flt or extraHit
    end

    local function isSpoken(line, cfg)
        if not line or line.comment then return false end
        local raw = tostring(line.text or "")
        if Kite.LineOps and Kite.LineOps.hasDrawing(raw) then return false end
        if visibleAutoTimingText(raw) == "" then return false end
        local effect = tostring(line.effect or ""):lower()
        if effect:find("template", 1, true) or effect:find("karaoke", 1, true) or effect:find("code", 1, true) then return false end
        if cfg.skip_signs then
            local style = tostring(line.style or ""):lower()
            if style:find("sign", 1, true) or style:find("kara", 1, true) or style:find("fx", 1, true) then return false end
        end
        if not styleMatches(line.style, cfg.style_filter, cfg.extra_style) then return false end
        return true
    end

    local parseWaveformJson = require("kite.Timing").Waveform.read

    local function smoothAt(wave, pointIndex, leftWindow, rightWindow)
        local n = wave.n
        if pointIndex < 1 then pointIndex = 1 end
        if pointIndex > n then pointIndex = n end
        local l = pointIndex - leftWindow
        local r = pointIndex + rightWindow
        if l < 1 then l = 1 end
        if r > n then r = n end
        return (wave.prefix[r] - wave.prefix[l - 1]) / (r - l + 1)
    end

    local function percentile(values, p)
        local n = #values
        if n == 0 then return 0 end
        local tmp = {}
        for i = 1, n do tmp[i] = values[i] end
        table.sort(tmp)
        if n == 1 then return tmp[1] end
        local pos = 1 + (n - 1) * p / 100
        local lo = math.floor(pos)
        local hi = math.ceil(pos)
        if lo < 1 then lo = 1 end
        if hi > n then hi = n end
        if lo == hi then return tmp[lo] end
        local frac = pos - lo
        return tmp[lo] * (1 - frac) + tmp[hi] * frac
    end

    local function otsuThreshold(values, bins)
        local n = #values
        if n == 0 then return 0 end
        bins = math.max(16, bins or 96)
        local lo = percentile(values, 1)
        local hi = percentile(values, 99)
        if hi <= lo then
            local sum = 0
            for i = 1, n do sum = sum + values[i] end
            return sum / n
        end
        local hist = {}
        for i = 1, bins do hist[i] = 0 end
        local span = hi - lo
        for i = 1, n do
            local v = values[i]
            if v < lo then v = lo end
            if v > hi then v = hi end
            local idx = math.floor(((v - lo) / span) * (bins - 1)) + 1
            if idx < 1 then idx = 1 end
            if idx > bins then idx = bins end
            hist[idx] = hist[idx] + 1
        end
        local centers = {}
        local total = 0
        local sumTotal = 0
        for i = 1, bins do
            centers[i] = lo + (i - 0.5) * span / bins
            total = total + hist[i]
            sumTotal = sumTotal + hist[i] * centers[i]
        end
        if total == 0 then return (lo + hi) / 2 end
        local wB = 0
        local sumB = 0
        local bestVar = -1
        local bestThr = centers[1]
        for i = 1, bins do
            wB = wB + hist[i]
            sumB = sumB + hist[i] * centers[i]
            local wF = total - wB
            if wB > 0 and wF > 0 then
                local meanB = sumB / wB
                local meanF = (sumTotal - sumB) / wF
                local diff = meanB - meanF
                local between = wB * wF * diff * diff
                if between > bestVar then
                    bestVar = between
                    bestThr = centers[i]
                end
            end
        end
        return bestThr
    end

    local function buildRuns(mask)
        local runs = {}
        local n = #mask
        local i = 1
        while i <= n do
            local v = mask[i]
            local j = i + 1
            while j <= n and mask[j] == v do j = j + 1 end
            runs[#runs + 1] = { v = v, a = i, b = j - 1 }
            i = j
        end
        return runs
    end

    local function morphMask(mask, fillGap, minIsland)
        local runs = buildRuns(mask)
        for r = 2, #runs - 1 do
            local run = runs[r]
            if (not run.v) and (run.b - run.a + 1) <= fillGap and runs[r - 1].v and runs[r + 1].v then
                for i = run.a, run.b do mask[i] = true end
            end
        end
        runs = buildRuns(mask)
        for r = 1, #runs do
            local run = runs[r]
            if run.v and (run.b - run.a + 1) < minIsland then
                for i = run.a, run.b do mask[i] = false end
            end
        end
    end

    local function buildComponents(mask, values, threshold, L0, pointMs)
        local comps = {}
        local runs = buildRuns(mask)
        for r = 1, #runs do
            local run = runs[r]
            if run.v then
                local mass = 0
                local maxv = -1e100
                for i = run.a, run.b do
                    local v = values[i]
                    local excess = v - threshold
                    if excess > 0 then mass = mass + excess end
                    if v > maxv then maxv = v end
                end
                local aMs = (L0 + run.a - 1) * pointMs
                local bMs = (L0 + run.b) * pointMs
                comps[#comps + 1] = {
                    a = aMs,
                    b = bMs,
                    duration = bMs - aMs,
                    mass = mass,
                    maxv = maxv
                }
            end
        end
        return comps
    end

    local function removeEdgeSpill(comps, startMs, endMs, cfg)
        if #comps <= 1 or not cfg.edge_spill_cleanup then return comps end
        local maxMass = 0
        for i = 1, #comps do
            if comps[i].mass > maxMass then maxMass = comps[i].mass end
        end
        if maxMass <= 0 then return comps end
        local massRatio = (cfg.spill_mass_per_mille or 300) / 1000.0
        local gapFactor = (cfg.spill_gap_factor_per_mille or 1000) / 1000.0
        local edgeNear = cfg.edge_near_ms or 20
        while #comps > 1 do
            local first = comps[1]
            local second = comps[2]
            local gap = second.a - first.b
            local nearEdge = first.a <= startMs + edgeNear
            local separated = gap > gapFactor * math.max(1, first.duration)
            local small = first.mass < massRatio * maxMass
            if nearEdge and separated and small then
                table.remove(comps, 1)
            else
                break
            end
        end
        while #comps > 1 do
            local last = comps[#comps]
            local prev = comps[#comps - 1]
            local gap = last.a - prev.b
            local nearEdge = last.b >= endMs - edgeNear
            local separated = gap > gapFactor * math.max(1, last.duration)
            local small = last.mass < massRatio * maxMass
            if nearEdge and separated and small then
                table.remove(comps, #comps)
            else
                break
            end
        end
        return comps
    end

    local function thresholdValues(values, cfg)
        if cfg.auto_otsu then
            return otsuThreshold(values, cfg.hist_bins)
        end
        local floor = percentile(values, cfg.floor_percentile or 5)
        local peak = percentile(values, cfg.peak_percentile or 95)
        local range = peak - floor
        if range <= 0 then return floor end
        return floor + (cfg.sensitivity_per_mille / 1000.0) * range
    end

    local function detectVoiceWaveform(it, wave, cfg)
        local pointMs = wave.point_ms
        local startMs = it.os
        local endMs = it.oe
        if endMs <= startMs then return nil end

        local outer = cfg.outer_search_ms or 0
        local origin = wave.origin or 0
        local searchStart = math.max(origin, startMs - outer)
        local searchEnd = math.min(origin + wave.n * pointMs, endMs + outer)
        if searchEnd <= searchStart + 10 then return nil end

        local L0 = math.floor((searchStart - origin) / pointMs)
        local R0 = math.floor((searchEnd - origin) / pointMs)
        if R0 > wave.n then R0 = wave.n end
        if L0 < 0 then L0 = 0 end
        local len = R0 - L0
        if len <= 10 then return nil end

        local smoothPoints = math.max(1, math.floor(cfg.smooth_ms / pointMs + 0.5))
        local leftWindow = math.floor((smoothPoints - 1) / 2)
        local rightWindow = (smoothPoints - 1) - leftWindow

        local values = {}
        local maxValue = 0
        for j = 1, len do
            local env = smoothAt(wave, L0 + j, leftWindow, rightWindow)
            if cfg.auto_otsu then
                values[j] = math.log(1 + env)
            else
                values[j] = env
            end
            if values[j] > maxValue then maxValue = values[j] end
        end

        if maxValue <= 0 then return nil end

        local threshold = thresholdValues(values, cfg)
        local mask = {}
        for i = 1, len do mask[i] = values[i] >= threshold end

        local fillGap = math.max(0, math.floor((cfg.fill_gap_ms or 60) / pointMs + 0.5))
        local minIsland = math.max(1, math.floor((cfg.min_island_ms or 60) / pointMs + 0.5))
        morphMask(mask, fillGap, minIsland)

        local comps = buildComponents(mask, values, threshold, L0, pointMs)
        for _, component in ipairs(comps) do component.a, component.b = component.a + origin, component.b + origin end
        if #comps == 0 then return nil end
        comps = removeEdgeSpill(comps, startMs, endMs, cfg)
        if #comps == 0 then return nil end

        local vs = clamp(comps[1].a, searchStart, searchEnd)
        local ve = clamp(comps[#comps].b, searchStart, searchEnd)
        if ve - vs < (cfg.min_voice_ms or 50) then return nil end
        local weak = (vs <= searchStart + 1) or (ve >= searchEnd - 1)
        return { vs = round(vs), ve = round(ve), weak = weak }
    end

    local function keyframeInRange(kfs, lo, hi, target)
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

    local function addFlag(it, flag)
        it.flags = it.flags or {}
        for _, f in ipairs(it.flags) do if f == flag then return end end
        it.flags[#it.flags + 1] = flag
    end

    local function stacked(a, b)
        return overlapLength(a.os, a.oe, b.os, b.oe) > TUNE.stack_eps_ms
    end

    local function planPadding(items, kfs, kfset, cfg, stats)
        stats = stats or {}
        local vis, processed = {}, {}
        for _, it in ipairs(items) do
            if it.spoken then
                vis[#vis + 1] = it
                it.vpos = #vis
                if it.use then processed[#processed + 1] = it end
            end
        end

        local grace = TUNE.frame_grace_ms

        for _, it in ipairs(processed) do
            it.ideal_s = it.vs - cfg.lead_in_ms
            it.ideal_e = it.ve + cfg.lead_out_ms
            it.s, it.e = it.ideal_s, it.ideal_e
            it.s_kf, it.e_kf = false, false
            it.joined_l, it.joined_r = false, false
            local origStartKf = keyframeInRange(kfs, it.os - grace, it.os + grace, it.os)
            local origEndKf = keyframeInRange(kfs, it.oe - grace, it.oe + grace, it.oe)
            local ks = keyframeInRange(kfs, it.vs - cfg.kf_start_range_ms, it.vs, it.vs)
                or keyframeInRange(kfs, it.vs + 1, math.min(it.vs + cfg.kf_back_ms, it.ve - 1), it.vs + 1)
            if not ks and origStartKf
                and origStartKf >= it.vs - cfg.kf_start_range_ms - 2 * grace
                and origStartKf <= it.vs + cfg.kf_back_ms then
                ks = origStartKf
            end
            if ks then it.s, it.s_kf = ks, true end
            local elo = math.max(it.ve - cfg.kf_back_ms, it.vs + 1)
            local ke = keyframeInRange(kfs, it.ve, it.ve + cfg.kf_end_range_ms, it.ve)
            if not ke and elo <= it.ve - 1 then
                ke = keyframeInRange(kfs, elo, it.ve - 1, it.ve)
            end
            if not ke and origEndKf
                and origEndKf > it.vs
                and origEndKf <= it.ve + cfg.max_lead_out_ms + 2 * grace then
                ke = origEndKf
            end
            if ke then it.e, it.e_kf = ke, true end
            if it.s < 0 then it.s = 0 end
        end

        local function setBoundary(a, b, t)
            t = round(t)
            a.e, b.s = t, t
            local on = kfset and kfset[t] or false
            a.e_kf, b.s_kf = on, on
            a.joined_r, b.joined_l = true, true
            stats.joins = (stats.joins or 0) + 1
        end

        local function resolvePair(a, b, blocked, origChained)
            if stacked(a, b) then return end
            if b.vs < a.ve then
                if a.e > b.s then addFlag(a, "OVERLAP"); addFlag(b, "OVERLAP") end
                return
            end
            if blocked then
                if a.e > b.s then
                    a.e = clamp(b.s, a.ve, a.e)
                    a.e_kf = kfset and kfset[a.e] or false
                end
                if a.e > b.s then addFlag(a, "OVERLAP"); addFlag(b, "OVERLAP") end
                return
            end
            local vaE, vbS = a.ve, b.vs
            local gap = b.s - a.e
            if gap == 0 then
                a.joined_r, b.joined_l = true, true
                return
            end

            if gap < 0 then
                local boundary
                if a.e_kf and a.e <= vbS + cfg.kf_back_ms then boundary = a.e
                elseif b.s_kf and b.s >= vaE - cfg.kf_back_ms then boundary = b.s
                else
                    local r0 = math.max(vaE - cfg.kf_back_ms, math.min(a.e, b.s))
                    local r1 = math.min(vbS + cfg.kf_back_ms, math.max(a.e, b.s))
                    boundary = keyframeInRange(kfs, r0, r1, clamp(vbS - cfg.lead_in_ms, r0, r1))
                    if not boundary then
                        local cand = vbS - cfg.lead_in_ms
                        if cand - vaE >= TUNE.keep_min_out_ms then
                            boundary = cand
                        else
                            local padding = cfg.lead_out_ms + cfg.lead_in_ms
                            if padding > 0 then
                                boundary = vaE + (vbS - vaE) * cfg.lead_out_ms / padding
                            else
                                boundary = vaE + (vbS - vaE) / 2
                            end
                        end
                        boundary = clamp(boundary, vaE, vbS)
                    end
                end
                setBoundary(a, b, boundary)
                return
            end

            local outRoom = math.max(0, cfg.max_lead_out_ms - (a.e - vaE))
            local inRoom = math.max(0, cfg.max_lead_in_ms - (vbS - b.s))
            local joinable = gap <= outRoom + inRoom
            local flashy = gap <= TUNE.flash_gap_ms
            local wanted = joinable or flashy or origChained
            local graceMs = (flashy or origChained) and TUNE.cap_grace_ms or 0

            local zoneKf
            if b.s - a.e > 2 then
                zoneKf = keyframeInRange(kfs, a.e + 1, b.s - 1, clamp(vbS - cfg.lead_in_ms, a.e + 1, b.s - 1))
            end

            if a.e_kf and b.s_kf then
                if flashy then
                    if b.s - vaE <= cfg.max_lead_out_ms + TUNE.cap_grace_ms then
                        setBoundary(a, b, b.s)
                    elseif vbS - a.e <= cfg.max_lead_in_ms + TUNE.cap_grace_ms then
                        setBoundary(a, b, a.e)
                    end
                end
                return
            end
            if a.e_kf then
                if wanted and not zoneKf and vbS - a.e <= cfg.max_lead_in_ms + graceMs then
                    setBoundary(a, b, a.e)
                end
                return
            end
            if b.s_kf then
                if zoneKf and zoneKf - vaE <= cfg.max_lead_out_ms then
                    a.e = zoneKf
                    a.e_kf = true
                elseif wanted and b.s - vaE <= cfg.max_lead_out_ms + graceMs then
                    setBoundary(a, b, b.s)
                end
                return
            end
            if zoneKf then
                if wanted and zoneKf - vaE <= cfg.max_lead_out_ms + graceMs
                    and vbS - zoneKf <= cfg.max_lead_in_ms + graceMs then
                    setBoundary(a, b, zoneKf)
                end
                return
            end
            if not wanted then return end
            if b.s - vaE <= cfg.max_lead_out_ms + graceMs then
                setBoundary(a, b, b.s)
            elseif joinable then
                setBoundary(a, b, vaE + cfg.max_lead_out_ms)
            elseif flashy then
                setBoundary(a, b, clamp(b.s, vaE, vbS))
            end
        end

        for i = 1, #processed - 1 do
            local a, b = processed[i], processed[i + 1]
            local blocked = false
            for k = a.vpos + 1, b.vpos - 1 do
                local m = vis[k]
                if not m.use and m.oe > a.ve and m.os < b.vs then blocked = true; break end
            end
            local origGap = b.os - a.oe
            local origChained = origGap <= grace and origGap >= -TUNE.stack_eps_ms
            resolvePair(a, b, blocked, origChained)
        end

        for _, it in ipairs(processed) do
            local p = vis[it.vpos - 1]
            if p and not p.use and not stacked(p, it) and it.s < p.oe then
                it.s = math.min(math.max(it.s, p.oe), it.vs)
                it.s_kf = kfset and kfset[it.s] or false
            end
            local nx = vis[it.vpos + 1]
            if nx and not nx.use and not stacked(it, nx) and it.e > nx.os then
                it.e = math.max(math.min(it.e, nx.os), it.ve)
                it.e_kf = kfset and kfset[it.e] or false
            end
        end

        local futureStarts = {}
        for i = #processed, 1, -1 do
            futureStarts[i] = math.min(processed[i].s, futureStarts[i + 1] or math.huge)
        end
        for i = 1, #processed do
            if Kite.LineOps then Kite.LineOps.checkCancelled() end
            local a = processed[i]
            for j = i + 1, #processed do
                if a.e <= futureStarts[j] then break end
                local b = processed[j]
                if not stacked(a, b) and a.e > b.s then
                    a.e = math.max(b.s, a.ve)
                    a.e_kf = kfset and kfset[a.e] or false
                    if a.e > b.s then addFlag(a, "OVERLAP"); addFlag(b, "OVERLAP") end
                end
            end
        end

        for _, it in ipairs(processed) do
            if not it.e_kf and not it.joined_r then
                local z = keyframeInRange(kfs, it.ve, it.ve + cfg.kf_end_range_ms, it.ve)
                if z and z ~= it.e then
                    local nx = vis[it.vpos + 1]
                    local lim
                    if nx and not stacked(it, nx) then lim = (nx.use and nx.s) or nx.os end
                    local ok = true
                    if lim then
                        if z > lim then ok = false
                        elseif z < lim and lim - z < TUNE.flash_gap_ms then ok = false end
                    end
                    if ok then it.e = z; it.e_kf = true end
                end
            end
        end

        for _, it in ipairs(processed) do
            if it.chars and it.chars > 0 then
                local short = cfg.duration_floor_ms - (it.e - it.s)
                if short > 0 then
                    local pall = vis[it.vpos - 1]
                    local leftLim = 0
                    if pall and not stacked(pall, it) then leftLim = (pall.use and pall.e) or pall.oe end
                    local nall = vis[it.vpos + 1]
                    local rightLim = math.huge
                    if nall and not stacked(it, nall) then rightLim = (nall.use and nall.s) or nall.os end
                    if not it.e_kf then
                        local give = math.min(short, math.max(0, rightLim - it.e))
                        it.e = it.e + give; short = short - give
                    end
                    if short > 0 and not it.s_kf then
                        local give = math.min(short, math.max(0, it.s - leftLim))
                        it.s = it.s - give; short = short - give
                    end
                    if short > 0 then addFlag(it, "SHORT") end
                end
            end
        end

        for i = 1, #vis - 1 do
            local a, b = vis[i], vis[i + 1]
            if (a.use or b.use) and b.os >= a.oe - TUNE.stack_eps_ms then
                local ae = a.use and a.e or a.oe
                local bs = b.use and b.s or b.os
                if ae > bs then
                    if a.use then
                        a.e = math.max(bs, a.ve)
                        a.e_kf = kfset and kfset[a.e] or false
                        ae = a.e
                    end
                    if ae > bs and b.use then
                        b.s = math.min(ae, b.vs)
                        b.s_kf = kfset and kfset[b.s] or false
                        bs = b.s
                    end
                    if ae > bs then addFlag(a, "OVERLAP"); addFlag(b, "OVERLAP") end
                end
            end
        end

        for _, it in ipairs(processed) do
            if it.s_kf then stats.snaps = (stats.snaps or 0) + 1 end
            if it.e_kf then stats.snaps = (stats.snaps or 0) + 1 end
        end
        return processed
    end

    local function addCpsFlags(items, cfg)
        for _, it in ipairs(items) do
            if it.use and it.chars > 0 and it.e and it.s and it.e > it.s then
                local cps = it.chars * 1000 / (it.e - it.s)
                if cps > cfg.cps_flag then
                    addFlag(it, string.format("CPS %d", round(cps)))
                end
            end
        end
    end

    local function cleanMarks(effect)
        local s = trim(effect)
        s = s:gsub("%s*%[TM%-[^%]]*%]", "")
        return trim(s)
    end

    local function collectAutoTimingItems(subs, sel, cfg)
        local items = {}
        for _, idx in ipairs(sel or {}) do
            local line = subs[idx]
            if line and line.class == "dialogue" and not line.comment then
                local osMs = tonumber(line.start_time) or 0
                local oeMs = tonumber(line.end_time) or 0
                local oldMarks = {}
                for m in tostring(line.effect or ""):gmatch("%[TM%-([^%]%s]+)") do
                    oldMarks[m] = true
                end
                items[#items + 1] = {
                    idx = idx, line = line, os = osMs, oe = oeMs,
                    spoken = oeMs > osMs and isSpoken(line, cfg),
                    chars = readableCharacters(line.text),
                    old_marks = oldMarks,
                    flags = {},
                }
            end
        end
        table.sort(items, function(a, b)
            if a.os == b.os then return a.idx < b.idx end
            return a.os < b.os
        end)
        return items
    end

    local function dialogueOrdinals(subs)
        local ord, n = {}, 0
        for i = 1, #subs do
            if subs[i].class == "dialogue" then
                n = n + 1
                ord[i] = n
            end
        end
        return ord
    end

    local function applyAutoTimingItems(subs, items)
        local flagged = {}
        for _, it in ipairs(items) do
            if it.spoken then
                local line = it.line
                if it.use and it.s and it.e then
                    local ns = round(it.s)
                    local ne = math.max(round(it.e), ns + TUNE.min_event_ms)
                    line.start_time = ns
                    line.end_time = ne
                end
                local eff = cleanMarks(line.effect)
                if #it.flags > 0 then
                    local tags = {}
                    for _, fl in ipairs(it.flags) do tags[#tags + 1] = "[TM-" .. fl .. "]" end
                    eff = (eff == "" and "" or eff .. " ") .. table.concat(tags, " ")
                    flagged[#flagged + 1] = it
                end
                line.effect = eff
                subs[it.idx] = line
            end
        end
        return flagged
    end

    local function runAutoTimingPipeline(subs, sel, cfg, mode, detect, kfs, kfset)
        local items = collectAutoTimingItems(subs, sel, cfg)
        if #items == 0 then return nil, "no_lines" end

        local stats = { matched = 0, spoken = 0, used = 0 }
        progress("Detecting voice...", 5)
        for k, it in ipairs(items) do
            if it.spoken then
                stats.spoken = stats.spoken + 1
                if mode == 2 then
                    if it.old_marks["NOVOICE"] then
                        addFlag(it, "NOVOICE")
                    else
                        it.vs, it.ve = it.os, it.oe
                        it.use = true
                        if it.old_marks["WEAK"] then addFlag(it, "WEAK") end
                    end
                else
                    local v = detect(it)
                    if v then
                        it.vs, it.ve = v.vs, v.ve
                        it.use = true
                        if v.weak then addFlag(it, "WEAK") end
                        stats.matched = stats.matched + 1
                    else
                        addFlag(it, "NOVOICE")
                    end
                end
                if it.use then stats.used = stats.used + 1 end
            end
            progress(nil, 5 + math.floor(45 * k / #items))
        end

        if mode ~= 2 and stats.matched == 0 then return nil, "no_voice" end

        progress("Planning timing...", 55)
        if mode == 1 then
            local prev
            for _, it in ipairs(items) do
                if it.use then
                    it.s, it.e = it.vs, it.ve
                    if prev and not stacked(prev, it) and it.s < prev.e then
                        addFlag(prev, "OVERLAP"); addFlag(it, "OVERLAP")
                    end
                    prev = it
                end
            end
        else
            planPadding(items, kfs, kfset, cfg, stats)
        end
        addCpsFlags(items, cfg)

        progress("Applying...", 85)
        local ordinals = dialogueOrdinals(subs)
        local flagged
        if Kite.LineOps and Kite.LineOps.transaction then
            Kite.LineOps.transaction(subs, function() flagged = applyAutoTimingItems(subs, items) end)
        else
            flagged = applyAutoTimingItems(subs, items)
        end
        progress(nil, 100)
        return { items = items, flagged = flagged, stats = stats, ordinals = ordinals }
    end

    local VT = {
        GUI_BOUNDS = guiBounds,
        normalize_cfg = normalizeAutoTimingConfig,
        style_ok = styleMatches,
        get_cfg = getAutoTimingConfig,
        save_cfg = saveAutoTimingConfig,
        parse_waveform_json = parseWaveformJson,
        detect_voice_waveform = detectVoiceWaveform,
        run_pipeline = runAutoTimingPipeline,
    }

    VTMOD = VT
    M.engine = VT

    return VTMOD
    end

    local atDetectors = { "Lazy", "Busy" }
    local atModes = { "Full Timing", "Raw Timing", "Post-Timing" }
    local atModeSet = {}
    for _, m in ipairs(atModes) do atModeSet[m] = true end
    local lztMethods = { "LazyFusion", "Cluster (Â±ms)", "Table (Â±ms)" }
    local lazyNumeric = {
        "lead_in_ms", "lead_out_ms", "max_lead_out_ms", "max_lead_in_ms",
        "kf_end_range_ms", "kf_start_range_ms", "kf_back_ms", "duration_floor_ms", "cps_flag",
        "smooth_ms", "fill_gap_ms", "min_island_ms", "outer_search_ms",
    }
    local dataKeys = { "sil30", "sil40", "sil50", "vad", "flux", "env" }
    local legacyKeys = { "sil30", "sil40", "sil50" }
    local atWave = { path = nil, data = nil }
    local busyPaths = { sil30 = "", sil40 = "", sil50 = "", vad = "", flux = "", env = "" }
    local busyDiscovered = false

    local function atKeyframesMs()
        local kf = getKeyframes()
        if not kf or #kf == 0 then return nil end
        local ms, seen = {}, {}
        for _, fr in ipairs(kf) do
            local t = frameToMs(fr)
            if t and not seen[t] then seen[t] = true; ms[#ms + 1] = t end
        end
        table.sort(ms)
        if #ms == 0 then return nil end
        local set = {}
        for _, t in ipairs(ms) do set[t] = true end
        return ms, set
    end

    local function atGetWave(VT, jsonField, forceReload)
        local path = (jsonField ~= "" and jsonField) or atWave.path or ""
        if forceReload or path == "" then
            local picked = aegisub.dialog.open(L("lazyt_open_title"), "", path, L("lazyt_json_filter"), false, true)
            if not picked or picked == "" then return nil, "cancel" end
            path = picked
        end
        if forceReload or atWave.data == nil or atWave.path ~= path then
            local ok, waveOrErr = pcall(VT.parse_waveform_json, path)
            if not ok or type(waveOrErr) ~= "table" then
                showMsg(string.format(L("lazyt_err_parse"), tostring(waveOrErr)))
                return nil, "parse"
            end
            atWave.path, atWave.data = path, waveOrErr
        end
        return atWave.data
    end

    local function atWaveEnvelope(wave)
        local pm = wave.point_ms
        local step = math.max(1, math.floor(10 / pm + 0.5))
        local ts, vs = {}, {}
        local i = 1
        while i <= wave.n do
            local lo = math.max(1, i - step)
            local hi = math.min(wave.n, i + step)
            ts[#ts + 1] = (wave.origin or 0) + (i - 1) * pm
            vs[#vs + 1] = (wave.prefix[hi] - wave.prefix[lo - 1]) / (hi - lo + 1)
            i = i + step
        end
        return { t = ts, v = vs }
    end

    local function atDiscoverBusyPaths()
        if not Timing or busyDiscovered then return end
        busyDiscovered = true
        local p = {}
        for _, k in ipairs(Timing.pathKeys or dataKeys) do p[k] = "" end
        local ok = pcall(Timing.discoverPaths, p)
        if ok then
            for _, k in ipairs(dataKeys) do
                if (busyPaths[k] or "") == "" and p[k] and p[k] ~= "" then busyPaths[k] = p[k] end
            end
        end
    end

    local function atBusyHasInput(wave)
        if wave then return true end
        for _, k in ipairs(dataKeys) do if (busyPaths[k] or "") ~= "" then return true end end
        return false
    end

    local function atMakeBusyDetect(cfg, wave, kfs)
        local paths = {}
        for _, k in ipairs(dataKeys) do paths[k] = busyPaths[k] or "" end
        if wave then paths.waveEnv = atWaveEnvelope(wave) end
        local sig = Timing.buildSignals(paths)
        if #sig.sources == 0 and not sig.env then return nil end
        return function(it)
            local v = Timing.detectVoice({ os = it.os, oe = it.oe }, sig, cfg, kfs, false)
            if not v then v = Timing.detectVoice({ os = it.os, oe = it.oe }, sig, cfg, kfs, true) end
            return v
        end
    end

    local function atLegacySelection(VT, subs, sel, cfg)
        local out = {}
        for _, i in ipairs(sel) do
            local l = subs[i]
            if l and l.class == "dialogue" and not l.comment
                and VT.style_ok(l.style, cfg.style_filter, cfg.extra_style) then
                local skip = false
                if cfg.skip_signs then
                    local st = tostring(l.style or ""):lower()
                    skip = st:find("sign", 1, true) ~= nil or st:find("kara", 1, true) ~= nil or st:find("fx", 1, true) ~= nil
                end
                if not skip then out[#out + 1] = i end
            end
        end
        return out
    end

    local function atRunLegacy(VT, subs, sel, cfg)
        if not Timing then showMsg(L("at_err_module")); return end
        local silencesOnly = currentConfig.lzt_silences_only and true or false
        local opts = {
            method = currentConfig.lzt_method,
            limit = tonumber(currentConfig.lzt_limit) or 800,
            silences_only = silencesOnly,
            apply_start = true, apply_end = true,
            enable_tagging = true, tag_mode = "Both", tag_scope = "Both",
        }
        local tsel = atLegacySelection(VT, subs, sel, cfg)
        local modified = Timing.lzt.run(subs, tsel, busyPaths, opts)
        if modified == nil then showMsg(L("at_err_sil")); return end
        aegisub.set_undo_point("Auto Timing (Legacy)")
        showMsg(string.format(L("at_legacy_done"), modified))
        return true
    end

    local function atBusyDialog()
        if not Timing then showMsg(L("at_err_module")); return end
        atDiscoverBusyPaths()
        while true do
            local d = {
                { class="label", label=L("at_lbl_data"), x=0, y=0, width=8, height=1 },
                { class="checkbox", name="discover", label=L("at_chk_discover"), value=false, x=0, y=1, width=8, height=1 },
                { class="label", label=L("at_lbl_sil"), x=0, y=2, width=2, height=1 },
                { class="edit", name="sil30", value=busyPaths.sil30, x=2, y=2, width=6, height=1 },
                { class="edit", name="sil40", value=busyPaths.sil40, x=0, y=3, width=4, height=1 },
                { class="edit", name="sil50", value=busyPaths.sil50, x=4, y=3, width=4, height=1 },
                { class="label", label=L("at_lbl_vad"), x=0, y=4, width=2, height=1 },
                { class="edit", name="vad", value=busyPaths.vad, x=2, y=4, width=6, height=1 },
                { class="label", label=L("at_lbl_flux"), x=0, y=5, width=2, height=1 },
                { class="edit", name="flux", value=busyPaths.flux, x=2, y=5, width=6, height=1 },
                { class="label", label=L("at_lbl_env"), x=0, y=6, width=2, height=1 },
                { class="edit", name="env", value=busyPaths.env, x=2, y=6, width=6, height=1 },
                { class="label", label=L("at_busy_hint"), x=0, y=7, width=8, height=1 },
            }
            local pressed, r = aegisub.dialog.display(d, { L("btn_ok"), L("btn_browse"), L("btn_cancel") }, { close = L("btn_cancel") })
            if not pressed or pressed == L("btn_cancel") then return end
            for _, k in ipairs(dataKeys) do busyPaths[k] = normalizeString(r[k]) end
            if r.discover then busyDiscovered = false; atDiscoverBusyPaths() end
            if pressed == L("btn_browse") then
                local dir = Timing and select(1, Timing.scriptDirAndBase()) or ""
                local ok, got = pcall(aegisub.dialog.open, L("at_data_title"), "", dir or "", "*.txt;*.log;*.tsv;*.csv", true, true)
                if ok and got then
                    local picks = type(got) == "table" and got or { got }
                    for _, p in ipairs(picks) do
                        local slot = Timing and Timing.classifyDataFile((tostring(p):match("[^/\\]+$")) or p)
                        if slot and busyPaths[slot] ~= nil then busyPaths[slot] = p end
                    end
                end
            else
                saveConfig()
                return "ok"
            end
        end
    end

    local function atLegacyDialog()
        if not Timing then showMsg(L("at_err_module")); return end
        atDiscoverBusyPaths()
        local methodUi = UI.options(lztMethods, currentConfig.lzt_method)
        while true do
            local d = {
                { class="label", label=L("at_sec_legacy"), x=0, y=0, width=8, height=1 },
                { class="label", label=L("at_legacy_hint"), x=0, y=1, width=8, height=1 },
                { class="checkbox", name="discover", label=L("at_chk_discover_legacy"), value=false, x=0, y=2, width=8, height=1 },
                { class="label", label=L("at_lbl_sil"), x=0, y=3, width=2, height=1 },
                { class="edit", name="sil30", value=busyPaths.sil30, x=2, y=3, width=6, height=1 },
                { class="edit", name="sil40", value=busyPaths.sil40, x=0, y=4, width=4, height=1 },
                { class="edit", name="sil50", value=busyPaths.sil50, x=4, y=4, width=4, height=1 },
                { class="label", label=L("at_lbl_method"), x=0, y=5, width=2, height=1 },
                { class="dropdown", name="method", items=methodUi.items, value=methodUi.value, x=2, y=5, width=4, height=1 },
                { class="label", label=L("at_lbl_limit"), x=6, y=5, width=1, height=1 },
                { class="intedit", name="limit", value=tonumber(currentConfig.lzt_limit) or 800, min=0, x=7, y=5, width=1, height=1 },
                { class="checkbox", name="silonly", label=L("at_chk_silonly"), value=currentConfig.lzt_silences_only and true or false, x=0, y=6, width=8, height=1 },
            }
            local pressed, r = aegisub.dialog.display(d, { L("btn_run_legacy"), L("btn_browse"), L("btn_cancel") }, { close = L("btn_cancel") })
            if not pressed or pressed == L("btn_cancel") then return end
            for _, k in ipairs(legacyKeys) do busyPaths[k] = normalizeString(r[k]) end
            currentConfig.lzt_method = UI.from(methodUi, r.method)
            currentConfig.lzt_limit = tonumber(r.limit) or currentConfig.lzt_limit
            currentConfig.lzt_silences_only = r.silonly and true or false
            if r.discover then busyDiscovered = false; atDiscoverBusyPaths() end
            if pressed == L("btn_browse") then
                local dir = Timing and select(1, Timing.scriptDirAndBase()) or ""
                local ok, got = pcall(aegisub.dialog.open, L("at_legacy_data_title"), "", dir or "", "*.txt;*.log;*.tsv;*.csv", true, true)
                if ok and got then
                    local picks = type(got) == "table" and got or { got }
                    for _, p in ipairs(picks) do
                        local slot = Timing and Timing.classifyDataFile((tostring(p):match("[^/\\]+$")) or p)
                        if slot and (slot == "sil30" or slot == "sil40" or slot == "sil50") then busyPaths[slot] = p end
                    end
                end
            else
                saveConfig()
                return "legacy"
            end
        end
    end

    local function atRunPipeline(VT, subs, tsel, cfg, modeNum, detect, kfs, kfset)
        local res, why = VT.run_pipeline(subs, tsel, cfg, modeNum, detect, kfs, kfset)
        if not res then return nil, why end
        local s = res.stats
        local txt = string.format(L("lazyt_sum"), s.used or 0, s.spoken or 0, s.snaps or 0, s.joins or 0, #res.flagged)
        local rows = {}
        for i, it in ipairs(res.flagged) do
            if i > 15 then rows[#rows + 1] = string.format("(+%d)", #res.flagged - 15); break end
            rows[#rows + 1] = string.format("#%d %s", res.ordinals[it.idx] or it.idx, table.concat(it.flags, ","))
        end
        if #rows > 0 then txt = txt .. "\n" .. table.concat(rows, "\n") end
        return txt, nil, #res.flagged
    end

    M.run = function(subs, sel)
        resolveConfig()
        if not sel or #sel == 0 then showMsg(L("err_no_selection")); return end
        local VT = getVT()
        if not atModeSet[currentConfig.lazyt_mode] then currentConfig.lazyt_mode = "Full Timing" end
        if currentConfig.at_detector ~= "Busy" then currentConfig.at_detector = "Lazy" end
        local cfg = VT.get_cfg()

        local subsName
        if aegisub.file_name then
            local ok, n = pcall(aegisub.file_name)
            if ok and n and n ~= "" then
                subsName = n:match("[^/\\]+$") or n
                if #subsName > 38 then subsName = "..." .. subsName:sub(-35) end
            end
        end

        local styles = collectStyles(subs, sel)
        do
            local present = {}
            for _, s in ipairs(styles) do present[s] = true end
            if cfg.style_filter ~= "" and not present[cfg.style_filter] then styles[#styles + 1] = cfg.style_filter end
        end
        local B = VT.GUI_BOUNDS

        while true do
            local modeUi = UI.options(atModes, currentConfig.lazyt_mode)
            local detUi = UI.options(atDetectors, currentConfig.at_detector)
            local styleUi = UI.options(styles, cfg.style_filter)
            local d = {
                { class="label", label=string.format(L("at_title"), subsName or "?"), x=0, y=0, width=4, height=1 },
                { class="label", label=L("lazyt_lbl_mode"), x=4, y=0, width=1, height=1 },
                { class="dropdown", name="mode", items=modeUi.items, value=modeUi.value, x=5, y=0, width=2, height=1 },
                { class="label", label=L("at_lbl_detector"), x=7, y=0, width=2, height=1 },
                { class="dropdown", name="detector", items=detUi.items, value=detUi.value, x=9, y=0, width=3, height=1 },

                { class="label", label=L("lazyt_lbl_json"), x=0, y=1, width=3, height=1 },
                { class="edit", name="json", value=(atWave.path or ""), x=3, y=1, width=9, height=1 },
                { class="checkbox", name="reload_json", label=L("lazyt_chk_reload"), value=false, x=0, y=2, width=4, height=1 },
                { class="label", label=L("lazyt_lbl_outer"), x=4, y=2, width=2, height=1 },
                { class="intedit", name="outer_search_ms", value=cfg.outer_search_ms, min=B.outer_search_ms.min, max=B.outer_search_ms.max, x=6, y=2, width=2, height=1 },

                { class="label", label=L("lazyt_sec_detect"), x=0, y=3, width=12, height=1 },
                { class="label", label=L("lazyt_lbl_smooth"), x=0, y=4, width=2, height=1 },
                { class="intedit", name="smooth_ms", value=cfg.smooth_ms, min=B.smooth_ms.min, max=B.smooth_ms.max, x=2, y=4, width=1, height=1 },
                { class="checkbox", name="auto_otsu", label=L("lazyt_chk_otsu"), value=cfg.auto_otsu, x=3, y=4, width=3, height=1 },
                { class="label", label=L("lazyt_lbl_bridge"), x=6, y=4, width=2, height=1 },
                { class="intedit", name="fill_gap_ms", value=cfg.fill_gap_ms, min=B.fill_gap_ms.min, max=B.fill_gap_ms.max, x=8, y=4, width=1, height=1 },
                { class="label", label=L("lazyt_lbl_island"), x=9, y=4, width=2, height=1 },
                { class="intedit", name="min_island_ms", value=cfg.min_island_ms, min=B.min_island_ms.min, max=B.min_island_ms.max, x=11, y=4, width=1, height=1 },
                { class="checkbox", name="edge_spill_cleanup", label=L("lazyt_chk_spill"), value=cfg.edge_spill_cleanup, x=0, y=5, width=6, height=1 },

                { class="label", label=L("lazyt_sec_margins"), x=0, y=6, width=12, height=1 },
                { class="label", label=L("lazyt_lbl_leads"), x=0, y=7, width=3, height=1 },
                { class="intedit", name="lead_in_ms", value=cfg.lead_in_ms, min=B.lead_in_ms.min, max=B.lead_in_ms.max, x=3, y=7, width=2, height=1 },
                { class="intedit", name="lead_out_ms", value=cfg.lead_out_ms, min=B.lead_out_ms.min, max=B.lead_out_ms.max, x=5, y=7, width=2, height=1 },
                { class="label", label=L("lazyt_lbl_chain"), x=7, y=7, width=3, height=1 },
                { class="intedit", name="max_lead_out_ms", value=cfg.max_lead_out_ms, min=B.max_lead_out_ms.min, max=B.max_lead_out_ms.max, x=10, y=7, width=1, height=1 },
                { class="intedit", name="max_lead_in_ms", value=cfg.max_lead_in_ms, min=B.max_lead_in_ms.min, max=B.max_lead_in_ms.max, x=11, y=7, width=1, height=1 },
                { class="label", label=L("lazyt_lbl_kfrange"), x=0, y=8, width=3, height=1 },
                { class="intedit", name="kf_end_range_ms", value=cfg.kf_end_range_ms, min=B.kf_end_range_ms.min, max=B.kf_end_range_ms.max, x=3, y=8, width=2, height=1 },
                { class="intedit", name="kf_start_range_ms", value=cfg.kf_start_range_ms, min=B.kf_start_range_ms.min, max=B.kf_start_range_ms.max, x=5, y=8, width=2, height=1 },
                { class="label", label=L("lazyt_lbl_cut"), x=7, y=8, width=3, height=1 },
                { class="intedit", name="kf_back_ms", value=cfg.kf_back_ms, min=B.kf_back_ms.min, max=B.kf_back_ms.max, x=10, y=8, width=2, height=1 },
                { class="label", label=L("lazyt_lbl_floor"), x=0, y=9, width=3, height=1 },
                { class="intedit", name="duration_floor_ms", value=cfg.duration_floor_ms, min=B.duration_floor_ms.min, max=B.duration_floor_ms.max, x=3, y=9, width=2, height=1 },
                { class="label", label=L("lazyt_lbl_cps"), x=7, y=9, width=3, height=1 },
                { class="intedit", name="cps_flag", value=cfg.cps_flag, min=B.cps_flag.min, max=B.cps_flag.max, x=10, y=9, width=2, height=1 },

                { class="checkbox", name="skip_signs", label=L("lazyt_chk_signs"), value=cfg.skip_signs, x=0, y=10, width=5, height=1 },
                { class="checkbox", name="show_stats", label=L("lazyt_chk_stats"), value=cfg.show_stats, x=5, y=10, width=4, height=1 },
                { class="label", label=L("lazyt_lbl_style"), x=0, y=11, width=3, height=1 },
                { class="dropdown", name="style_filter", items=styleUi.items, value=styleUi.value, x=3, y=11, width=4, height=1 },
                { class="edit", name="extra_style", value=cfg.extra_style, x=7, y=11, width=5, height=1 },
                { class="label", label=L("at_hint"), x=0, y=12, width=12, height=1 },
                { class="label", label=L("at_hint_mode"), x=0, y=13, width=12, height=1 },
            }
            local pressed, r = aegisub.dialog.display(d, { L("btn_process"), L("btn_browse"), L("btn_data"), L("btn_legacy"), L("btn_save"), L("btn_cancel") }, { close = L("btn_cancel") })
            if not pressed or pressed == L("btn_cancel") then return end

            currentConfig.lazyt_mode = UI.from(modeUi, r.mode)
            currentConfig.at_detector = UI.from(detUi, r.detector)
            cfg.style_filter = UI.from(styleUi, r.style_filter)
            cfg.extra_style = normalizeString(r.extra_style)
            for _, k in ipairs(lazyNumeric) do cfg[k] = r[k] end
            cfg.auto_otsu = r.auto_otsu and true or false
            cfg.edge_spill_cleanup = r.edge_spill_cleanup and true or false
            cfg.skip_signs = r.skip_signs and true or false
            cfg.show_stats = r.show_stats and true or false
            VT.normalize_cfg(cfg)
            local jsonField = normalizeString(r.json)
            local enteredPath = jsonField ~= "" and jsonField or nil
            if atWave.path ~= enteredPath then atWave.path, atWave.data = enteredPath, nil end

            if pressed == L("btn_save") then
                local saved, message = VT.save_cfg(cfg)
                showMsg(saved and L("msg_config_saved") or tostring(message or "Could not save configuration."))
            elseif pressed == L("btn_browse") then
                local picked = aegisub.dialog.open(L("lazyt_open_title"), "", jsonField ~= "" and jsonField or (atWave.path or ""), L("lazyt_json_filter"), false, true)
                if picked and picked ~= "" then atWave.path = picked; atWave.data = nil end
            elseif pressed == L("btn_data") then
                atBusyDialog()
            elseif pressed == L("btn_legacy") then
                local action = atLegacyDialog()
                if action == "legacy" then
                    if atRunLegacy(VT, subs, sel, cfg) then return sel end
                end
            else
                VT.save_cfg(cfg)
                local modeKey = currentConfig.lazyt_mode
                local modeNum = (modeKey == "Full Timing") and 3 or (modeKey == "Post-Timing") and 2 or 1
                local busy = (currentConfig.at_detector == "Busy")
                local kfs, kfset = {}, {}
                local ready = true
                if modeNum ~= 1 then
                    kfs, kfset = atKeyframesMs()
                    if not kfs then showMsg(L("err_no_keyframes")); ready = false; kfs, kfset = {}, {} end
                end
                local detect
                if ready and modeNum ~= 2 then
                    local wave
                    if busy then
                        if jsonField ~= "" or atWave.path then
                            wave = atGetWave(VT, jsonField, r.reload_json and true or false)
                        end
                        if not Timing then showMsg(L("at_err_module")); ready = false
                        elseif not atBusyHasInput(wave) then
                            local action = atBusyDialog()
                            if action ~= "ok" or not atBusyHasInput(wave) then showMsg(L("at_err_busy_input")); ready = false end
                        else
                            detect = atMakeBusyDetect(cfg, wave, kfs)
                            if not detect then showMsg(L("at_err_busy_input")); ready = false end
                        end
                        if ready and not detect then
                            detect = atMakeBusyDetect(cfg, wave, kfs)
                            if not detect then showMsg(L("at_err_busy_input")); ready = false end
                        end
                    else
                        wave = atGetWave(VT, jsonField, r.reload_json and true or false)
                        if not wave then ready = false
                        else detect = function(it) return VT.detect_voice_waveform(it, wave, cfg) end end
                    end
                end
                if ready then
                    local txt, why, nflag = atRunPipeline(VT, subs, sel, cfg, modeNum, detect, kfs, kfset)
                    if txt then
                        aegisub.set_undo_point("Auto Timing")
                        if cfg.show_stats or (nflag or 0) > 0 then
                            showMsg(string.format(L("at_msg_done"), UI.text(currentConfig.at_detector) .. " / " .. UI.text(currentConfig.lazyt_mode), txt))
                        end
                        return sel
                    else
                        showMsg(why == "no_lines" and L("err_no_selection") or L("lazyt_no_voice"))
                    end
                end
            end
        end
    end
    end

    local Scream = { MARKER = "[SCREAM]" }

    function Scream.analysisFolder(media)
        local folder = Kite.LineOps and Kite.LineOps.subtitleFolder and Kite.LineOps.subtitleFolder() or nil
        folder = folder or (Kite.PyBridge and Kite.PyBridge.parentPath(media)) or (Kite.PyBridge and Kite.PyBridge.tempRoot())
        if not folder then return nil end
        local ok = Kite.PyBridge.ensureDir(folder)
        if not ok then return nil end
        return folder
    end

    function Scream.analysisLog(media)
        local folder = Scream.analysisFolder(media)
        if not folder then return nil end
        return Kite.PyBridge.joinPath(folder, "chrono_suite_scream.log")
    end

    function Scream.median(values) return require("kite.Core").median(values, true) or 0 end

    function Scream.dbToPower(db) return 10 ^ (db / 10) end
    function Scream.powerToDb(power)
        if not power or power <= 0 then return -120 end
        return 10 * math.log(power) / math.log(10)
    end

    function Scream.annotateSpans(samples)
        local gaps = {}
        for i = 2, #samples do
            local gap = samples[i].time - samples[i - 1].time
            if gap > 0 then gaps[#gaps+1] = gap end
        end
        local medianGap = Scream.median(gaps)
        if medianGap <= 0 then medianGap = 40 end
        for i, sample in ipairs(samples) do
            local left  = i > 1 and (sample.time - samples[i - 1].time) or medianGap
            local right = i < #samples and (samples[i + 1].time - sample.time) or medianGap
            if left  <= 0 then left  = medianGap end
            if right <= 0 then right = medianGap end
            if left  > medianGap * 3 then left  = medianGap end
            if right > medianGap * 3 then right = medianGap end
            sample.start  = sample.time - left  / 2
            sample["end"] = sample.time + right / 2
        end
    end

    function Scream.parseLog(path)
        local f = io.open(path, "r"); if not f then return {} end
        local samples, timeMs = {}, nil
        for line in f:lines() do
            local t = line:match("pts_time:([%-%d%.]+)")
            if t then timeMs = tonumber(t) and tonumber(t) * 1000 or nil end
            local peak = line:match("lavfi%.astats%.Overall%.Peak_level=([%-%d%.]+)")
            if peak and timeMs then
                local db = tonumber(peak)
                if db then samples[#samples+1] = { time = timeMs, db = db, power = Scream.dbToPower(db) } end
            end
        end
        f:close()
        table.sort(samples, function(a, b) return a.time < b.time end)
        Scream.annotateSpans(samples)
        return samples
    end

    function Scream.firstSampleIndex(samples, t)
        local lo, hi = 1, #samples + 1
        while lo < hi do
            local mid = math.floor((lo + hi) / 2)
            if samples[mid].time < t then lo = mid + 1 else hi = mid end
        end
        return lo
    end

    function Scream.scoreLine(line, samples, cfg)
        local startT, endT = line.start_time or 0, line.end_time or 0
        local count, loud, powerSum, peakDb = 0, 0, 0, -120
        for k = Scream.firstSampleIndex(samples, startT), #samples do
            local sample = samples[k]
            if sample.start > endT then break end
            if sample.start >= startT and sample["end"] <= endT then
                count = count + 1
                powerSum = powerSum + sample.power
                if sample.db >= cfg.scream_sample_db then loud = loud + 1 end
                if sample.db > peakDb then peakDb = sample.db end
            end
        end
        if count == 0 then
            return { samples = 0, avg_db = -120, peak_db = -120, loud_ratio = 0, robust_z = 0 }
        end
        return {
            samples    = count,
            avg_db     = Scream.powerToDb(powerSum / count),
            peak_db    = peakDb,
            loud_ratio = loud / count,
            robust_z   = 0,
        }
    end

    function Scream.robustStats(scores)
        local values = {}
        for _, s in ipairs(scores) do if s.samples > 0 then values[#values+1] = s.avg_db end end
        local med = Scream.median(values)
        if #values < 5 then return med, 0, 0 end
        local deviations = {}
        for _, v in ipairs(values) do deviations[#deviations+1] = math.abs(v - med) end
        local mad = Scream.median(deviations)
        local sigma = mad * 1.4826
        if sigma < 0.25 then sigma = 0 end
        return med, mad, sigma
    end

    function Scream.passes(score, cfg, sigma)
        if score.samples < cfg.scream_min_samples then return false end
        if score.avg_db < cfg.scream_avg_db then return false end
        if score.loud_ratio < (cfg.scream_loud_ratio / 100) then return false end
        if cfg.scream_robust_z > 0 and sigma > 0 and score.robust_z < cfg.scream_robust_z then return false end
        return true
    end

    function Scream.stripMarker(effect)
        return trimText(normalizeString(effect):gsub("%s*%[SCREAM%]", ""))
    end

    function Scream.runAnalysis(media, logPath)
        local ffmpeg, message = require("kite.Automatons").tool("ffmpeg")
        if not ffmpeg then return false, message end
        Kite.PyBridge.removeFile(logPath)
        local filter = "astats=metadata=1:reset=1,ametadata=print:key=lavfi.astats.Overall.Peak_level:file='" .. Kite.Media.filterPath(logPath) .. "'"
        local nullOutput = Kite.PyBridge.isWindows and "NUL" or "/dev/null"
        local args = {
            "-hide_banner", "-nostdin", "-loglevel", "warning", "-y", "-i", media,
            "-map", "0:a:0", "-vn", "-af", filter, "-f", "null", nullOutput
        }
        return Kite.PyBridge.run(Kite.PyBridge.commandLine(ffmpeg, args))
    end

    function Scream.configDialog()
        resolveConfig()
        local scopeUi = UI.options({ "All dialogue", "Selected lines" }, currentConfig.scream_scope)
        local dlg = {
            { class = "label", label = L("scream_title"),     x = 0, y = 0, width = 10, height = 1 },
            { class = "label", label = L("scream_lbl_avg"),    x = 0, y = 1, width = 6, height = 1 },
            { class = "edit",  name  = "scream_avg_db",        value = tostring(currentConfig.scream_avg_db),    x = 6, y = 1, width = 4, height = 1 },
            { class = "label", label = L("scream_lbl_sample"), x = 0, y = 2, width = 6, height = 1 },
            { class = "edit",  name  = "scream_sample_db",     value = tostring(currentConfig.scream_sample_db), x = 6, y = 2, width = 4, height = 1 },
            { class = "label", label = L("scream_lbl_ratio"),  x = 0, y = 3, width = 6, height = 1 },
            { class = "intedit", name = "scream_loud_ratio",   value = currentConfig.scream_loud_ratio, min = 0, max = 100, x = 6, y = 3, width = 4, height = 1 },
            { class = "label", label = L("scream_lbl_min"),    x = 0, y = 4, width = 6, height = 1 },
            { class = "intedit", name = "scream_min_samples", value = currentConfig.scream_min_samples, min = 1, x = 6, y = 4, width = 4, height = 1 },
            { class = "label", label = L("scream_lbl_z"),      x = 0, y = 5, width = 6, height = 1 },
            { class = "edit",  name  = "scream_robust_z",      value = tostring(currentConfig.scream_robust_z),  x = 6, y = 5, width = 4, height = 1 },
            { class = "label", label = L("lbl_apply_to"),      x = 0, y = 6, width = 6, height = 1 },
            { class = "dropdown", name = "scream_scope", items = scopeUi.items, value = scopeUi.value, x = 6, y = 6, width = 4, height = 1 },
            { class = "checkbox", name = "scream_clean_previous", label = L("scream_chk_clean"), value = currentConfig.scream_clean_previous, x = 0, y = 7, width = 10, height = 1 },
            { class = "checkbox", name = "scream_reuse_log",      label = L("scream_chk_reuse"), value = currentConfig.scream_reuse_log,      x = 0, y = 8, width = 10, height = 1 },
        }
        local btn, res = aegisub.dialog.display(dlg, { L("scream_btn_analyze"), L("btn_cancel") }, { close = L("btn_cancel") })
        if not btn or btn == L("btn_cancel") then return nil end
        local scope = UI.from(scopeUi, res.scream_scope)
        if scope ~= "Selected lines" then scope = "All dialogue" end
        local cfg = {
            scream_avg_db        = tonumber(res.scream_avg_db)        or currentConfig.scream_avg_db,
            scream_sample_db     = tonumber(res.scream_sample_db)     or currentConfig.scream_sample_db,
            scream_loud_ratio    = math.max(0, math.min(100, tonumber(res.scream_loud_ratio) or currentConfig.scream_loud_ratio)),
            scream_min_samples   = math.max(1, tonumber(res.scream_min_samples) or currentConfig.scream_min_samples),
            scream_robust_z      = math.max(0, tonumber(res.scream_robust_z) or currentConfig.scream_robust_z),
            scream_clean_previous = res.scream_clean_previous == true,
            scream_reuse_log     = res.scream_reuse_log == true,
            scream_scope         = scope,
        }
        for k, v in pairs(cfg) do currentConfig[k] = v end
        saveConfig()
        return cfg
    end

    function M.scream(subs, sel)
        resolveConfig()
        if not Kite.PyBridge or not Kite.Media or not Kite.LineOps then showMsg("Auto Timing requires kite.PyBridge, kite.PyBridge.Media and kite.Core.LineOps."); return end
        local media = Kite.Media.projectPath("audio", { fallbackVideo = true })
        if not media then showMsg(L("scream_msg_no_media")); return end
        local cfg = Scream.configDialog()
        if not cfg then return end
        local logPath = Scream.analysisLog(media)
        if not logPath then showMsg(L("scream_msg_no_folder")); return end
        local sourcePath = logPath .. ".source"
        local cachedSource = Kite.PyBridge.readFile(sourcePath)
        if not cfg.scream_reuse_log or cachedSource ~= media or not Kite.PyBridge.fileExists(logPath) then
            showMsg(L("scream_msg_running"))
            Kite.PyBridge.removeFile(sourcePath)
            local ok, diagnostic = Scream.runAnalysis(media, logPath)
            if not ok then showMsg(string.format(L("err_process_failed"), tostring(diagnostic or ""))); return end
            Kite.PyBridge.writeFile(sourcePath, media)
        end
        local samples = Scream.parseLog(logPath)
        if #samples == 0 then showMsg(string.format(L("scream_msg_no_log"), logPath)); return end
        local lookup, restrictToSel = {}, cfg.scream_scope == "Selected lines"
        if restrictToSel and sel then for _, idx in ipairs(sel) do lookup[idx] = true end end
        if restrictToSel and (not sel or #sel == 0) then showMsg(L("err_no_selection")); return end
        local candidates, scores, scanned = {}, {}, 0
        for i = 1, #subs do
            local line = subs[i]
            if isDialogue(line) and not line.comment and (not restrictToSel or lookup[i]) then
                scanned = scanned + 1
                local score = Scream.scoreLine(line, samples, cfg)
                candidates[#candidates + 1] = { index = i, score = score }
                scores[#scores + 1] = score
            end
        end
        if scanned == 0 then showMsg(L("err_no_selection")); return end
        local medianDb, madDb, sigmaDb = Scream.robustStats(scores)
        for _, candidate in ipairs(candidates) do
            if sigmaDb > 0 then candidate.score.robust_z = (candidate.score.avg_db - medianDb) / sigmaDb end
        end
        local changes, marked = {}, 0
        for _, candidate in ipairs(candidates) do
            local line = subs[candidate.index]
            local before = normalizeString(line.effect)
            local after = before
            if cfg.scream_clean_previous then after = Scream.stripMarker(after) end
            if Scream.passes(candidate.score, cfg, sigmaDb) then
                after = Scream.stripMarker(after)
                after = trimText(after == "" and Scream.MARKER or (after .. " " .. Scream.MARKER))
                marked = marked + 1
            end
            if after ~= before then changes[#changes + 1] = { index = candidate.index, effect = after } end
        end
        if #changes > 0 then
            Kite.LineOps.transaction(subs, "Auto Timing - Scream Detector", function()
                for _, change in ipairs(changes) do
                    local line = subs[change.index]
                    line.effect = change.effect
                    subs[change.index] = line
                end
            end)
        end
        showMsg(string.format(L("scream_msg_done"), marked, scanned, #samples, medianDb, madDb))
        return true
    end

    function M.configure()
        resolveConfig()
        local button, values = aegisub.dialog.display({
            {class="label",label="Language",x=0,y=0,width=3,height=1},
            {class="dropdown",name="language",items={"en","es","pt"},value=currentConfig.language,x=3,y=0,width=5,height=1},
            {class="label",label="Keyframe log suffix",x=0,y=1,width=3,height=1},
            {class="edit",name="scxvid_suffix",value=currentConfig.scxvid_suffix,x=3,y=1,width=5,height=1},
        }, {"Save","Cancel"}, {ok="Save",close="Cancel"})
        if button ~= "Save" then return end
        if values.scxvid_suffix:find('[\\/:*?"<>|]') or values.scxvid_suffix == "" then
            showMsg("Enter a filename suffix without directory characters."); return
        end
        currentConfig.language, currentConfig.scxvid_suffix = values.language, values.scxvid_suffix
        local ok, message = saveConfig()
        if not ok then showMsg(message) end
    end
    function M.keyframeSuffix() resolveConfig(); return currentConfig.scxvid_suffix end
    M.screamEngine = Scream
    return M
    end

    local script_name = "Auto Timing"
    local script_namespace = "kite.AutoTiming"
    local depctrl = record
    local Manager = Automatons
    local Timing = createTiming()
    local Audio = createAudio()
    local Waveform = createWaveform()
    local function audio(mode) return function(_,selection) return Audio.run(mode,selection,Timing.keyframeSuffix()) end end
    Manager.register("chrono_audio", {
        {"Timing","Auto-time dialogue with Lazy, Busy or Legacy.",Timing.run,backend=false},
        {"Scream Detector","Mark loud dialogue intervals.",Timing.scream,capability="ffmpeg"},
        {"Audio/Isolator","Separate full-timeline vocals.",audio("isolate"),capability="isolate"},
        {"Audio/Signals","Generate timing signals from isolated vocals.",audio("signals"),capability="signals"},
        {"Audio/Complete","Separate vocals and generate signals and keyframes.",audio("all"),capability="all"},
        {"Keyframes","Extract SCXvid keyframes.",audio("keyframes"),capability="keyframes"},
        {"Waveform/Full audio","Export the entire active audio waveform.",Waveform.full,Waveform.canFull,capability="ffmpeg"},
        {"Waveform/Selected span","Export a waveform covering the selection.",Waveform.selected,Waveform.canSelection,capability="ffmpeg"},
        {"Waveform/Each selected line","Export one waveform per selected line.",Waveform.each,Waveform.canSelection,capability="ffmpeg"},
        {"Settings","Language and keyframe output naming.",Timing.configure,backend=false},
    }, script_namespace,depctrl)
end

registerAutoBlur(dependencies)
registerAutoMotion(dependencies)
registerAutoMask(dependencies)
registerAutoDrawing(dependencies)
registerAutoTiming(dependencies)

local function register(path, description, process)
    aegisub.register_macro(script_name .. "/" .. path,description,function(subs,selection,active)
        process()
        return selection,active
    end)
end

register("Check/All automatons","Check all scripts, backends and media tools.",function() Automatons.check() end)
register("Install/All automatons","Install or repair the complete collection.",function() Automatons.install() end)
for _, item in ipairs(Automatons.catalog) do
    local id = item.id
    register("Install/" .. item.name,"Install or repair " .. item.name .. ".",function() Automatons.install(id) end)
    register("Check/" .. item.name,"Diagnose " .. item.name .. ".",function() Automatons.check(id) end)
end
register("Install/Media tools","Install FFmpeg, FFprobe and SCXvid.",function() Automatons.install("tools") end)
register("Install/Auto Mask models","Download and verify the Auto Mask models.",Automatons.installModels)
register("Configure","Configure the shared runtime and compute device.",Automatons.configure)

require("kite.UI").publishActions()

end
local registrations = {}
local registerMacro = aegisub.register_macro
local function loadScript()
    registrations = {}
    aegisub.register_macro = function(name, description, callback, validate, active)
        registrations[#registrations+1] = {name, description, callback, validate, active}
    end
    local ok, message = pcall(initializeScript)
    aegisub.register_macro = registerMacro
    local available, control = pcall(require, "l0.DependencyControl")
    if available and control.updater then control.updater:releaseLock() end
    return ok, message
end
local loaded, failure = loadScript()
if loaded then
    for _, action in ipairs(registrations) do registerMacro(unpack(action)) end
else
    registerMacro(script_name, script_description, function(subs, selection, active)
        if not loaded then
            local available, control = pcall(require, "l0.DependencyControl")
            if not available then error(control, 0) end
            local loader = require("l0.DependencyControl.ModuleLoader")
            for _, task in pairs(control.updater.tasks[control.Domain.ScriptType.Module]) do
                if not task.updated and not task.running then loader.removeDummyRef(task.record) end
            end
            loaded, failure = loadScript()
            if not loaded then error(failure, 0) end
        end
        local choices, actions = {}, {}
        for _, action in ipairs(registrations) do
            if not action[4] or action[4](subs, selection, active) then
                choices[#choices+1] = action[1]
                actions[action[1]] = action[3]
            end
        end
        if #choices == 0 then return selection, active end
        if #choices == 1 then return actions[choices[1]](subs, selection, active) end
        local button, values = aegisub.dialog.display({
            {class="dropdown", name="action", items=choices, value=choices[1], x=0,y=0,width=1,height=1}
        }, {"Run","Cancel"}, {ok="Run",close="Cancel"})
        if button == "Run" then return actions[values.action](subs, selection, active) end
        return selection, active
    end)
end
