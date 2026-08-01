local Media = { version = "1.2.0" }

local function safeRequire(name)
    local ok, value = pcall(require, name)
    if ok then return value end
    return nil
end

local DependencyControl = safeRequire("l0.DependencyControl")
local LineOps = safeRequire("kite.LineOps")
local PyBridge = safeRequire("kite.PyBridge")
local depctrl
if DependencyControl then
    depctrl = DependencyControl({
        name = "kite.Media",
        version = Media.version,
        description = "Shared project-media, frame-window and media-output utilities for Kite macros",
        author = "Kiterow",
        url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
        moduleName = "kite.Media",
        feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
        {
            { "kite.LineOps", version = "1.5.0" },
            { "kite.PyBridge", version = "1.4.0" },
        },
    })
end

local function trim(value)
    if LineOps and LineOps.trim then return LineOps.trim(value) end
    return (tostring(value == nil and "" or value):match("^%s*(.-)%s*$")) or ""
end

local function fileExists(path)
    if PyBridge and PyBridge.fileExists then return PyBridge.fileExists(path) end
    local handle = trim(path) ~= "" and io.open(path, "rb") or nil
    if not handle then return false end
    handle:close()
    return true
end

local function decodedPath(specification)
    if PyBridge and PyBridge.decodedPath then return PyBridge.decodedPath(specification) end
    if not aegisub or type(aegisub.decode_path) ~= "function" then return nil end
    local ok, value = pcall(aegisub.decode_path, specification)
    if ok and type(value) == "string" and value ~= "" and value ~= specification then return value end
    return nil
end

local function projectProperties()
    if LineOps and LineOps.projectProperties then return LineOps.projectProperties() end
    if not aegisub or type(aegisub.project_properties) ~= "function" then return {} end
    local ok, value = pcall(aegisub.project_properties)
    if ok and type(value) == "table" then return value end
    return {}
end

local function isDummy(path)
    local value = trim(path):lower()
    return value == "" or value:match("^%?dummy") ~= nil or value:match("^dummy:") ~= nil
end

local function projectPath(kind, options)
    options = options or {}
    kind = kind == "audio" and "audio" or "video"
    local properties = projectProperties()
    local candidates = {}
    local function append(value)
        value = trim(value)
        if value ~= "" and not isDummy(value) then
            for _, existing in ipairs(candidates) do if existing == value then return end end
            candidates[#candidates + 1] = value
        end
    end
    append(properties[kind .. "_file"])
    append(decodedPath("?" .. kind))
    if kind == "audio" and options.fallbackVideo ~= false then
        append(properties.video_file)
        append(decodedPath("?video"))
    end
    if options.requireExisting == false then return candidates[1], candidates end
    for _, path in ipairs(candidates) do if fileExists(path) then return path, candidates end end
    return nil, candidates
end

local function frameFromMs(milliseconds)
    if not aegisub or type(aegisub.frame_from_ms) ~= "function" then return nil end
    local ok, value = pcall(aegisub.frame_from_ms, tonumber(milliseconds) or 0)
    if ok and type(value) == "number" then return value end
    return nil
end

local function msFromFrame(frame)
    if not aegisub or type(aegisub.ms_from_frame) ~= "function" then return nil end
    local ok, value = pcall(aegisub.ms_from_frame, tonumber(frame) or 0)
    if ok and type(value) == "number" then return value end
    return nil
end

local function exclusiveEndFrame(startTime, endTime)
    local first = frameFromMs(startTime)
    local last = frameFromMs(endTime)
    if not first or not last then return nil end
    return math.max(first + 1, last)
end

local function selectionWindow(subtitles, selection, options)
    options = options or {}
    local predicate = function(line)
        if not line or line.class ~= "dialogue" then return false end
        if options.includeComments ~= true and line.comment then return false end
        if options.positiveDuration ~= false and (tonumber(line.end_time) or 0) <= (tonumber(line.start_time) or 0) then return false end
        return true
    end
    local records, rejected
    if LineOps and LineOps.selectedLines then
        records, rejected = LineOps.selectedLines(subtitles, selection, predicate, options.requireAll == true)
    else
        records, rejected = {}, {}
        for _, index in ipairs(selection or {}) do
            local line = subtitles[index]
            if predicate(line) then records[#records + 1] = { index = index, line = line }
            else rejected[#rejected + 1] = index end
        end
        if options.requireAll == true and #rejected > 0 then records = nil end
    end
    if not records then return nil, "selection contains unsupported lines", rejected end
    if #records == 0 then return nil, "select at least one valid dialogue line", rejected end
    local indices, minimumStart, maximumEnd = {}, nil, nil
    for _, record in ipairs(records) do
        local line = record.line
        indices[#indices + 1] = record.index
        minimumStart = math.min(minimumStart or line.start_time, line.start_time)
        maximumEnd = math.max(maximumEnd or line.end_time, line.end_time)
    end
    table.sort(indices)
    local startFrame = frameFromMs(minimumStart)
    local endFrame = exclusiveEndFrame(minimumStart, maximumEnd)
    if options.requireFrames ~= false and (not startFrame or not endFrame or endFrame <= startFrame) then
        return nil, "the selection covers no loaded video frames", rejected
    end
    return {
        records = records,
        rejected = rejected,
        indices = indices,
        min_start = minimumStart,
        max_end = maximumEnd,
        start_frame = startFrame,
        end_frame = endFrame,
        frame_count = startFrame and endFrame and (endFrame - startFrame) or nil,
    }
end

local commonRates = {
    { value = 24000 / 1001, text = "24000/1001" },
    { value = 24, text = "24" },
    { value = 25, text = "25" },
    { value = 30000 / 1001, text = "30000/1001" },
    { value = 30, text = "30" },
    { value = 50, text = "50" },
    { value = 60000 / 1001, text = "60000/1001" },
    { value = 60, text = "60" },
}

local function frameRate(startFrame, endFrame)
    startFrame = tonumber(startFrame)
    endFrame = tonumber(endFrame)
    if not startFrame or not endFrame or endFrame <= startFrame then return nil end
    local startTime = msFromFrame(startFrame)
    local endTime = msFromFrame(endFrame)
    if not startTime or not endTime or endTime <= startTime then return nil end
    return (endFrame - startFrame) * 1000 / (endTime - startTime)
end

local function constantFrameRate(startFrame, endFrame, options)
    options = options or {}
    startFrame = tonumber(startFrame)
    endFrame = tonumber(endFrame)
    if not startFrame or not endFrame or endFrame <= startFrame then return false, nil, { reason = "invalid range" } end
    local startTime = msFromFrame(startFrame)
    local endTime = msFromFrame(endFrame)
    if not startTime or not endTime or endTime <= startTime then return false, nil, { reason = "timecodes unavailable" } end
    local count = endFrame - startFrame
    local maximumSamples = math.max(16, math.floor(tonumber(options.maximumSamples) or 4096))
    local step = math.max(1, math.ceil(count / maximumSamples))
    local minimumDuration, maximumDuration, maximumPhase = nil, nil, 0
    local sampled = 0
    local function inspect(frame)
        if frame < startFrame or frame >= endFrame then return true end
        local current = msFromFrame(frame)
        local following = msFromFrame(frame + 1)
        if not current or not following or following <= current then return false end
        local duration = following - current
        minimumDuration = math.min(minimumDuration or duration, duration)
        maximumDuration = math.max(maximumDuration or duration, duration)
        local expected = startTime + (endTime - startTime) * (frame - startFrame) / count
        maximumPhase = math.max(maximumPhase, math.abs(current - expected))
        sampled = sampled + 1
        return true
    end
    local frame = startFrame
    while frame < endFrame do
        if not inspect(frame) then return false, nil, { reason = "invalid timecode", frame = frame } end
        frame = frame + step
    end
    if endFrame - 1 >= startFrame and ((endFrame - 1 - startFrame) % step ~= 0) then
        if not inspect(endFrame - 1) then return false, nil, { reason = "invalid timecode", frame = endFrame - 1 } end
    end
    local durationTolerance = tonumber(options.durationTolerance) or 1.1
    local phaseTolerance = tonumber(options.phaseTolerance) or 1.1
    local rate = count * 1000 / (endTime - startTime)
    local constant = minimumDuration ~= nil
        and maximumDuration - minimumDuration <= durationTolerance
        and maximumPhase <= phaseTolerance
    return constant, rate, {
        sampled = sampled,
        minimum_duration = minimumDuration,
        maximum_duration = maximumDuration,
        maximum_phase = maximumPhase,
        start_time = startTime,
        end_time = endTime,
    }
end

local function frameRateArgument(startFrame, endFrame, options)
    options = options or {}
    local rate
    if options.requireConstant == false then
        rate = frameRate(startFrame, endFrame)
    else
        local constant
        constant, rate = constantFrameRate(startFrame, endFrame, options)
        if not constant then return nil, rate end
    end
    if not rate then return nil end
    for _, candidate in ipairs(commonRates) do
        if math.abs(rate - candidate.value) <= 0.02 then return candidate.text, rate end
    end
    return string.format("%.6f", rate):gsub("0+$", ""):gsub("%.$", ""), rate
end

local function fileSize(path)
    if PyBridge and PyBridge.fileSize then return PyBridge.fileSize(path) end
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local size = handle:seek("end")
    handle:close()
    return tonumber(size)
end

local function verifyPng(path)
    local handle = io.open(path, "rb")
    if not handle then return false, "missing" end
    local signature = handle:read(8)
    handle:close()
    if signature ~= "\137PNG\r\n\26\n" then return false, "invalid" end
    local size = fileSize(path)
    if not size or size <= 8 then return false, "empty" end
    return true, size
end

local function filterPath(path)
    local value = tostring(path or "")
    value = value:gsub("\\", "\\\\")
    value = value:gsub(":", "\\:")
    value = value:gsub("'", "\\'")
    value = value:gsub(",", "\\,")
    value = value:gsub(";", "\\;")
    value = value:gsub("%[", "\\[")
    value = value:gsub("%]", "\\]")
    return value
end

Media.trim = trim
Media.fileExists = fileExists
Media.decodedPath = decodedPath
Media.projectProperties = projectProperties
Media.isDummy = isDummy
Media.projectPath = projectPath
Media.frameFromMs = frameFromMs
Media.msFromFrame = msFromFrame
Media.exclusiveEndFrame = exclusiveEndFrame
Media.selectionWindow = selectionWindow
Media.frameRate = frameRate
Media.constantFrameRate = constantFrameRate
Media.frameRateArgument = frameRateArgument
Media.fileSize = fileSize
Media.verifyPng = verifyPng
Media.filterPath = filterPath

if depctrl then return depctrl:register(Media) end
return Media
