export script_name        = "Snapshoter"
export script_description = "Capture subtitle frames, frame lists, frame sequences, and clip crops from the loaded video"
export script_author      = "Kiterow"
export script_version     = "1.6.8"
export script_namespace   = "kite.Snapshoter"

DependencyControl = require "l0.DependencyControl"
depctrl = DependencyControl{
  feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
  {
    {"a-mo.LineCollection", version: "1.3.0", url: "https://github.com/TypesettingTools/Aegisub-Motion",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"}
    {"kite.UI", version: "1.5.1", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"a-mo.Log", version: "1.0.0", url: "https://github.com/TypesettingTools/Aegisub-Motion",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"}
    {"myaa.ASSParser", version: "0.0.4", url: "https://github.com/TypesettingTools/Myaamori-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Myaamori-Aegisub-Scripts/master/DependencyControl.json"}
    {"kite.PyBridge", version: "1.7.2", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.LineOps", version: "1.7.2", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.Core", version: "1.1.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.Media", version: "1.4.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.AssDrawing", version: "1.0.3", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
  }
}
LineCollection, KiteUI, log, ASSParser, PyBridge, LineOps, Core, Media, AssDrawing = depctrl\requireModules!
finiteNumber = Core.finiteNumber

configHandler = (interface, fileName, _hasSections, version) ->
  KiteUI.dialogHandler interface, script_namespace, version, {
    {path: "?user/" .. fileName, format: "json_sections"}
  }

ConfigFile = "kite-snapshoter.json"
AssCentisecondMs = 10
FrameTimeToleranceMs = 1
MaxFfmpegErrorBytes = 12000
MaxVideoFrame = 2147483647
FilenameTextBytes = 96

CaptureModes = {
  "Selected lines"
  "Frame list"
  "Frame sequence"
  "Clip crop"
  "Manual rectangle"
  "Densest subtitle frame"
}

TimingModes = {
  "Midpoint"
  "Start and end"
  "Start, middle, end"
  "Current video frame"
}

ClipOutputs = {
  "Rectangle crop"
  "Clip alpha crop"
  "Clip alpha full frame"
  "Drawing alpha crop"
  "Drawing alpha full frame"
}

choiceOrDefault = (value, items, defaultValue) ->
  for item in *items
    return item if value == item
  defaultValue

normalizeMode = (value) ->
  if value == "Rectangular clip" then "Clip crop" else value

normalizeClipOutput = (value) ->
  switch value
    when "Vector alpha crop" then "Clip alpha crop"
    when "Vector alpha full frame" then "Clip alpha full frame"
    else value

baseName = (path) ->
  name = tostring(path or "")\match("([^\\/]+)$") or tostring(path or "")
  name\gsub "%.[^%.]*$", ""

safeName = (text, defaultValue = "snapshoter") ->
  value = LineOps.trim(text)\gsub('[\z\1-\31\\/:*?"<>|]+', "_")\gsub("%s+", "_")
  value = value\gsub "_+", "_"
  value = value\gsub "^_+", ""
  value = value\gsub "_+$", ""
  value = value\gsub "[%.%s]+$", ""
  lower = value\lower!\match "^[^%.]+" or ""
  reserved = lower == "con" or lower == "prn" or lower == "aux" or lower == "nul" or lower\match("^com[1-9]$") or lower\match("^lpt[1-9]$")
  return defaultValue if value == "." or value == ".." or value\match("^%.+$") or reserved
  if value == "" then defaultValue else value

readFile = (path, maxBytes) ->
  content = PyBridge.readFile path, maxBytes
  content or ""

decodedPath = (spec) ->
  LineOps.decodedPath(spec) or ""

filterPathQuote = (value) ->
  value = tostring(value or "")\gsub "\\", "/"
  value = Media.filterPath value
  Media.filterPath value

ffmpegExecutable = (value) ->
  exe = LineOps.trim value
  if exe == "" then "ffmpeg" else exe

showMessage = (text) ->
  KiteUI.message text

videoPath = ->
  path = decodedPath "?video"
  return path if path != "" and PyBridge.fileExists path
  props = aegisub.project_properties and aegisub.project_properties! or {}
  path = props.video_file or ""
  return path if path != "" and PyBridge.fileExists path
  nil

projectFolder = (video) ->
  folder = LineOps.subtitleFolder! or ""
  return folder if folder != ""
  scriptDir = decodedPath "?script"
  return scriptDir if scriptDir != ""
  PyBridge.parentPath(video) or ""

snapshotsFolder = (video) ->
  PyBridge.joinPath projectFolder(video), "Snapshots"

fileTime = (ms) ->
  ms = math.max 0, LineOps.round(ms)
  h = math.floor(ms / 3600000)
  m = math.floor((ms % 3600000) / 60000)
  s = math.floor((ms % 60000) / 1000)
  mm = ms % 1000
  string.format "%02d-%02d-%02d-%03d", h, m, s, mm

frameSeekTime = (frame) ->
  milliseconds = Media.msFromFrame frame
  assert milliseconds, "Could not obtain the video frame timestamp."
  Core.formatNumber(math.max(0, milliseconds - FrameTimeToleranceMs) / 1000, 6)

cleanText = (text) ->
  LineOps.trim LineOps.visibleText text

lastActiveFrame = (startMs, endMs) ->
  frame = Media.exclusiveEndFrame startMs, endMs
  if frame then frame - 1 else nil

currentVideoFrame = ->
  return nil unless aegisub.project_properties
  ok, props = pcall aegisub.project_properties
  return nil unless ok and props
  return nil if props.video_position == nil
  frame = finiteNumber props.video_position
  if frame and frame >= 0 and frame <= MaxVideoFrame then math.floor(frame) else nil

lineIntervals = (lines) ->
  raw = {}
  for line in *lines
    startFrame = Media.frameFromMs line.start_time
    endFrame = lastActiveFrame line.start_time, line.end_time
    if startFrame and endFrame
      endFrame = startFrame if endFrame < startFrame
      table.insert raw, { first: startFrame, last: endFrame }
  table.sort raw, (a, b) ->
    if a.first == b.first then a.last < b.last else a.first < b.first
  merged = {}
  for item in *raw
    last = merged[#merged]
    if last and item.first <= last.last + 1
      last.last = item.last if item.last > last.last
    else
      table.insert merged, { first: item.first, last: item.last }
  merged

frameInIntervals = (frame, intervals) ->
  for item in *(intervals or {})
    return true if frame >= item.first and frame <= item.last
  false

collectEffectFrames = (lines, intervals) ->
  seen, out = {}, {}
  for line in *lines
    effect = tostring(line.effect or "")
    for token in effect\gmatch "[^;,%s]+"
      raw = token\match "^[Ff]?(%d+)$"
      raw = token\match("^[Ff]?(%d+)[Ff]?$") unless raw
      if raw
        frame = tonumber raw
        if frame and frameInIntervals(frame, intervals) and not seen[frame]
          seen[frame] = true
          table.insert out, frame
  table.sort out
  out

defaultFrameList = (lines) ->
  unless lines and #lines > 0
    frame = currentVideoFrame!
    return if frame then { frame } else {}
  intervals = lineIntervals lines
  effectFrames = collectEffectFrames lines, intervals
  return effectFrames if #effectFrames > 0
  frame = currentVideoFrame!
  return { frame } if frame and frameInIntervals frame, intervals
  out = {}
  for item in *intervals
    table.insert out, item.first
  out

parseFrameToken = (token) ->
  token = LineOps.trim token
  return nil if token == ""
  raw = token\match "^[Ff]?(%d+)[Ff]?$"
  frame = raw and finiteNumber raw
  if frame and frame <= MaxVideoFrame then frame else nil

parseFrameList = (text) ->
  frames, seen, errors = {}, {}, {}
  for rawLine in tostring(text or "")\gmatch "[^\n]+"
    line = LineOps.trim rawLine\gsub("^%-%-%s*", "")
    if line != ""
      line = line\gsub "%f[%a][Ff][Aa][Dd][Ee]%f[%A]%s+[^,%s;]+", ""
      line = line\match("^(.-)>") or line
      for token in line\gmatch "[^,%s;]+"
        frame = parseFrameToken token
        if frame
          unless seen[frame]
            seen[frame] = true
            table.insert frames, frame
        else
          table.insert errors, "Invalid frame token: #{token}"
  table.sort frames
  frames, errors

buildFrameDefaults = (frames) ->
  items = {}
  for frame in *(frames or {})
    table.insert items, "#{frame}f"
  table.concat items, " "

lineContainsFrame = (line, frame) ->
  return false unless line and frame
  startMs = tonumber(line.start_time) or 0
  endMs = tonumber(line.end_time) or startMs
  startFrame = Media.frameFromMs startMs
  endFrame = lastActiveFrame startMs, endMs
  startFrame and endFrame and frame >= startFrame and frame <= endFrame

linePoints = (line, timingMode, currentFrame = nil) ->
  startMs = tonumber(line.start_time) or 0
  endMs = tonumber(line.end_time) or startMs
  midMs = startMs + (endMs - startMs) / 2
  if timingMode == "Current video frame"
    frame = currentFrame or currentVideoFrame!
    return {} unless frame
    frame = math.floor((tonumber(frame) or 0) + 0.5)
    return {} unless lineContainsFrame line, frame
    time = Media.msFromFrame frame
    return {} unless time
    {
      { key: "current", label: "current frame", time: time, frame: frame }
    }
  elseif timingMode == "Start and end"
    lastFrame = lastActiveFrame startMs, endMs
    lastMs = lastFrame and Media.msFromFrame(lastFrame) or startMs
    {
      { key: "start", label: "start", time: startMs }
      { key: "end", label: "end", time: lastMs }
    }
  elseif timingMode == "Start, middle, end"
    lastFrame = lastActiveFrame startMs, endMs
    lastMs = lastFrame and Media.msFromFrame(lastFrame) or startMs
    {
      { key: "start", label: "start", time: startMs }
      { key: "mid", label: "midpoint", time: midMs }
      { key: "end", label: "end", time: lastMs }
    }
  else
    {
      { key: "mid", label: "midpoint", time: midMs }
    }

selectedLines = (subs, sel) ->
  collection = LineCollection subs, sel, ((line) -> line.class == "dialogue" and not line.comment and line.end_time and line.end_time > line.start_time), true
  lines = {}
  for line in *collection.lines
    table.insert lines, line if line.end_time > line.start_time
  table.sort lines, (a, b) -> (a.number or 0) < (b.number or 0)
  collection, lines

videoSize = ->
  return 0, 0 unless aegisub and aegisub.video_size
  ok, width, height = pcall aegisub.video_size
  return 0, 0 unless ok
  tonumber(width) or 0, tonumber(height) or 0

normalizeCrop = (x, y, w, h, padding, videoW, videoH) ->
  x, y, w, h = finiteNumber(x), finiteNumber(y), finiteNumber(w), finiteNumber(h)
  padding, videoW, videoH = finiteNumber(padding), finiteNumber(videoW), finiteNumber(videoH)
  return nil unless x and y and w and h and padding and videoW and videoH
  return nil if w <= 0 or h <= 0 or videoW <= 0 or videoH <= 0 or padding < 0
  x1, y1 = math.max(0, math.floor(x - padding)), math.max(0, math.floor(y - padding))
  x2, y2 = math.min(videoW, math.ceil(x + w + padding)), math.min(videoH, math.ceil(y + h + padding))
  return nil unless x2 > x1 and y2 > y1
  {x: x1, y: y1, w: x2 - x1, h: y2 - y1}

scaleClipRect = (rect, collection, cfg) ->
  videoW, videoH = cfg.videoW, cfg.videoH
  playX = tonumber(collection.meta and collection.meta.PlayResX) or videoW
  playY = tonumber(collection.meta and collection.meta.PlayResY) or videoH
  sx = if playX > 0 then videoW / playX else 1
  sy = if playY > 0 then videoH / playY else 1
  x1 = math.min(rect.x1, rect.x2) * sx
  y1 = math.min(rect.y1, rect.y2) * sy
  x2 = math.max(rect.x1, rect.x2) * sx
  y2 = math.max(rect.y1, rect.y2) * sy
  normalizeCrop x1, y1, x2 - x1, y2 - y1, cfg.cropPadding, videoW, videoH

manualCrop = (cfg) ->
  normalizeCrop cfg.manualX, cfg.manualY, cfg.manualW, cfg.manualH, cfg.cropPadding, cfg.videoW, cfg.videoH

extendBounds = (bounds, x, y) ->
  x, y = finiteNumber(x), finiteNumber(y)
  return false unless x and y
  if bounds.x1 == nil
    bounds.x1, bounds.x2 = x, x
    bounds.y1, bounds.y2 = y, y
  else
    bounds.x1 = math.min bounds.x1, x
    bounds.y1 = math.min bounds.y1, y
    bounds.x2 = math.max bounds.x2, x
    bounds.y2 = math.max bounds.y2, y
  true

boundsRect = (bounds) ->
  return nil unless bounds and bounds.x1 != nil and bounds.y1 != nil and bounds.x2 != nil and bounds.y2 != nil
  { x1: bounds.x1, y1: bounds.y1, x2: bounds.x2, y2: bounds.y2 }

rectFromPayload = (payload) ->
  values = LineOps.splitArguments payload
  return nil unless #values == 4
  numbers = {}
  for value in *values
    number = finiteNumber value
    return nil unless number
    numbers[#numbers + 1] = number
  {x1: numbers[1], y1: numbers[2], x2: numbers[3], y2: numbers[4]}

clipInfoFromPayload = (name, payload) ->
  payload = LineOps.trim payload
  body, scale = payload, 1
  rawScale, drawing = payload\match "^([^,]+),%s*([mMnN].*)$"
  if rawScale
    scale, body = finiteNumber(rawScale), drawing
    return nil unless scale and scale >= 1 and scale == math.floor(scale)
  vector = body\match("^[mMnN]%s") != nil
  local rect
  if vector
    body = body\lower!
    return nil unless AssDrawing.validatePath body
    divisor = finiteNumber 2 ^ (scale - 1)
    return nil unless divisor and divisor > 0
    bounds, x = {}, nil
    for token in body\gmatch "%S+"
      number = finiteNumber token
      if number
        if x == nil
          x = number
        else
          LineOps.checkCancelled!
          extendBounds bounds, x / divisor, number / divisor
          x = nil
    rect = boundsRect bounds
    payload = if scale == 1 then body else "#{Core.formatNumber(scale, 0)},#{body}"
  else
    rect = rectFromPayload payload
  return nil unless rect
  {rect: rect, tag: "\\#{name}(#{payload})", isVector: vector, inverse: name == "iclip"}

relevantClipEntries = (text) ->
  entries = {}
  for call in *LineOps.tagCalls(text, {clip: true, iclip: true})
    if call.top_level
      table.insert entries, {start: call.start, raw: call.raw, static: true}
  for transform in *LineOps.tagCalls(text, "t")
    continue unless transform.top_level
    clips = LineOps.tagCalls("{#{transform.raw}}", {clip: true, iclip: true})
    continue if #clips == 0
    value = tostring(transform.value or "")
    value = value\sub(2, -2) if value\sub(1, 1) == "(" and value\sub(-1) == ")"
    firstTag = value\find "\\", 1, true
    continue unless firstTag
    prefix = value\sub 1, firstTag - 1
    clipTags = [call.raw for call in *clips]
    table.insert entries, {
      start: transform.start
      raw: "\\t(#{prefix}#{table.concat(clipTags, '')})"
      animated: true
    }
  table.sort entries, (a, b) -> a.start < b.start
  entries

clipInfoFromTags = (text) ->
  entries = relevantClipEntries text
  info = nil
  for entry in *entries
    if entry.static
      name, raw = entry.raw\match "^\\(i?clip)%s*(%b())$"
      parsed = clipInfoFromPayload(name, raw\sub(2, -2)) if name and raw
      info = parsed if parsed
  if info
    info.entries = entries
    for item in *entries
      info.animated = true if item.animated
  info

lineClipInfo = (line, playX, playY) ->
  info = clipInfoFromTags line.text
  return info if info
  entries = relevantClipEntries line.text
  return nil if #entries == 0 or not playX or not playY
  info = clipInfoFromPayload "clip", "0,0,#{playX},#{playY}"
  info.entries, info.animated = entries, true
  info

drawingMaskText = (line) ->
  parts, hasDrawing = {}, false
  for section in *LineOps.scanSections(line and line.text or "")
    if section.type == "drawing"
      parts[#parts + 1] = section.text
      hasDrawing = true if LineOps.trim(section.text) != ""
    elseif section.type == "override" or section.type == "comment"
      parts[#parts + 1] = "{#{section.text}}"
  if hasDrawing then table.concat(parts) else nil

lineDrawingInfo = (line) ->
  text = drawingMaskText line
  return nil unless text
  { text: text }

densestFrame = (lines) ->
  events = {}
  for line in *lines
    log.checkCancellation!
    startFrame = Media.frameFromMs line.start_time
    endFrame = lastActiveFrame line.start_time, line.end_time
    continue unless startFrame and endFrame
    endFrame = math.max startFrame, endFrame
    table.insert events, { frame: startFrame, delta: 1 }
    table.insert events, { frame: endFrame + 1, delta: -1 }
  table.sort events, (a, b) ->
    if a.frame == b.frame then a.delta > b.delta else a.frame < b.frame
  active, bestCount, bestFrame = 0, 0, nil
  i = 1
  while i <= #events
    frame = events[i].frame
    while i <= #events and events[i].frame == frame
      active += events[i].delta
      i += 1
    if active > bestCount
      bestCount = active
      bestFrame = frame
  bestFrame, bestCount

shotName = (seq, line, point, _mode, includeText, extra = nil) ->
  parts = {
    string.format "%04d", seq
    line and string.format("L%04d", line.number or 0) or "dense"
    point.key
    fileTime(point.time)
  }
  table.insert parts, extra if extra
  if includeText and line
    units, bytes = {}, 0
    for unit in *LineOps.graphemes(safeName(cleanText(line.text), ""))
      break if bytes + #unit > FilenameTextBytes
      units[#units + 1], bytes = unit, bytes + #unit
    label = table.concat units
    table.insert parts, label if label != ""
  table.concat(parts, "_") .. ".png"

frameShotName = (seq, frame, time) ->
  string.format "%04d_F%06d_%s.png", seq, frame, fileTime(time)

clipOutputExtra = (clipOutput) ->
  switch clipOutput
    when "Clip alpha crop" then "clip_alpha_crop"
    when "Clip alpha full frame" then "clip_alpha_full"
    when "Drawing alpha crop" then "drawing_alpha_crop"
    when "Drawing alpha full frame" then "drawing_alpha_full"
    else "crop"

drawRectShape = (w, h) ->
  w = math.floor((tonumber(w) or 1) + 0.5)
  h = math.floor((tonumber(h) or 1) + 0.5)
  "m 0 0 l #{w} 0 #{w} #{h} 0 #{h}"

clipMaskText = (clipInfo, playX, playY) ->
  entries = clipInfo.entries or {}
  tags = table.concat([entry.raw for entry in *entries], "")
  hasStatic = false
  for entry in *entries
    hasStatic = true if entry.static
  tags = clipInfo.tag .. tags unless hasStatic
  "{\\an7\\pos(0,0)\\p1\\bord0\\shad0\\blur0\\1c&HFFFFFF&\\alpha&H00&#{tags}}#{drawRectShape playX, playY}"

makeJobs = (collection, lines, cfg) ->
  jobs, skipped, errors, seq = {}, {}, {}, 0
  mode = normalizeMode cfg.mode
  if mode == "Frame list"
    frames, parseErrors = parseFrameList cfg.frameText
    return jobs, skipped, parseErrors if #parseErrors > 0
    return jobs, skipped, { "No valid frames were listed." } if #frames == 0
    for frame in *frames
      time = Media.msFromFrame frame
      if time
        seq += 1
        table.insert jobs, {
          time: time
          frame: frame
          name: frameShotName seq, frame, time
          subtitle: ""
          label: "frame #{frame}"
          mode: mode
        }
      else
        table.insert errors, "Could not convert frame to milliseconds: #{frame}"
    return jobs, skipped, errors

  return jobs, skipped, { "Select at least one timed dialogue line." } unless lines and #lines > 0

  manualRect = manualCrop(cfg) if mode == "Manual rectangle"
  return jobs, skipped, {"The manual rectangle does not intersect the video."} if mode == "Manual rectangle" and not manualRect
  currentFrame = nil
  if cfg.timing == "Current video frame"
    currentFrame = currentVideoFrame!
    return jobs, skipped, { "Current video frame is unavailable. Open a video and place the playhead on the frame you want." } unless currentFrame

  if mode == "Densest subtitle frame"
    frame, count = densestFrame lines
    return jobs, skipped, errors unless frame
    time = Media.msFromFrame(frame)
    seq += 1
    table.insert jobs, {
      time: time
      frame: frame
      name: shotName seq, nil, { key: "dense", time: time }, mode, false, "#{count}lines"
      subtitle: ""
      label: "densest frame"
      mode: mode
      overlap: count
    }
    return jobs, skipped, errors

  currentFrameTouchesLine = false
  for line in *lines
    log.checkCancellation!
    rect = nil
    alphaMaskText, alphaDetectCrop = nil, false
    currentFrameTouchesLine = true if currentFrame and lineContainsFrame line, currentFrame
    if mode == "Clip crop"
      if cfg.clipOutput == "Drawing alpha crop" or cfg.clipOutput == "Drawing alpha full frame"
        drawingInfo = lineDrawingInfo line
        if drawingInfo
          alphaMaskText = drawingInfo.text
          alphaDetectCrop = cfg.clipOutput == "Drawing alpha crop"
        else
          table.insert skipped, line.number
          continue
      else
        clipInfo = lineClipInfo line, cfg.playX, cfg.playY
        if clipInfo and clipInfo.rect
          if cfg.clipOutput == "Clip alpha crop"
            alphaMaskText = clipMaskText clipInfo, cfg.playX, cfg.playY
            alphaDetectCrop = true
          elseif cfg.clipOutput == "Clip alpha full frame"
            alphaMaskText = clipMaskText clipInfo, cfg.playX, cfg.playY
          else
            if clipInfo.inverse
              table.insert errors, "Line #{line.number}: Rectangle crop cannot represent \\iclip. Choose Clip alpha crop/full frame."
              continue
            if clipInfo.animated
              table.insert errors, "Line #{line.number}: Rectangle crop cannot follow an animated clip. Choose Clip alpha crop/full frame."
              continue
            rect = scaleClipRect clipInfo.rect, collection, cfg
            unless rect
              table.insert errors, "Line #{line.number}: the clip does not intersect the video."
              continue
        else
          table.insert skipped, line.number
          continue
    elseif mode == "Manual rectangle"
      rect = manualRect

    points = linePoints line, cfg.timing, currentFrame
    continue if #points == 0
    for point in *points
      seq += 1
      extra = if rect or alphaMaskText then clipOutputExtra(cfg.clipOutput) else nil
      maskDurationMs = math.max 1, (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0)
      maskStartMs = tonumber(line.start_time) or 0
      table.insert jobs, {
        time: point.time
        frame: point.frame or Media.frameFromMs(point.time)
        name: shotName seq, line, point, mode, cfg.includeText, extra
        subtitle: line.number
        label: point.label
        mode: mode
        crop: rect
        alphaMaskText: alphaMaskText
        maskSource: if cfg.clipOutput == "Drawing alpha crop" or cfg.clipOutput == "Drawing alpha full frame" then line else nil
        alphaDetectCrop: alphaDetectCrop
        :maskDurationMs
        :maskStartMs
      }
  if cfg.timing == "Current video frame" and #jobs == 0 and not currentFrameTouchesLine
    table.insert errors, "The current video frame is not inside any selected line."
  jobs, skipped, errors

cropFilter = (crop) ->
  string.format "crop=%d:%d:%d:%d", crop.w, crop.h, crop.x, crop.y

runCommand = (command, errPath = nil) ->
  ok, output, exitCode = PyBridge.runProcess command
  PyBridge.writeFile errPath, output or "" if errPath and errPath != ""
  ok, output, exitCode

ffmpegErrorPath = (outDir, job, suffix = "error") ->
  PyBridge.joinPath outDir, "_snapshoter_ffmpeg_#{safeName(baseName(job.name), "capture")}_#{suffix}.txt"

ffmpegErrorMessage = (label, path, errPath) ->
  details = LineOps.trim(readFile(errPath, 6000))
  message = "FFmpeg returned an error while #{label}:\n#{path}"
  if details != ""
    message ..= "\n\nFFmpeg:\n#{details}"
  else
    message ..= "\n\nFFmpeg did not return diagnostic output."
  message

runFfmpeg = (command, outDir, job, label, path) ->
  errPath = ffmpegErrorPath outDir, job, safeName(label, "error")
  ok, _, exitCode = runCommand command, errPath
  if ok and Media.verifyPng(path)
    PyBridge.removeFile errPath
    return true, nil
  if ok
    PyBridge.writeFile errPath, "FFmpeg exited successfully but did not create a non-empty output file."
  message = ffmpegErrorMessage label, path, errPath
  PyBridge.removeFile errPath
  PyBridge.removeFile path
  false, if exitCode == 130 then "Capture cancelled." else message

maskAssPath = (outDir, job) ->
  PyBridge.joinPath outDir, "_snapshoter_mask_#{safeName(baseName(job.name), "mask")}.ass"

alphaTempPath = (outDir, job) ->
  PyBridge.joinPath outDir, "_snapshoter_alpha_#{safeName(baseName(job.name), "alpha")}.png"

maskAssText = (text) ->
  text = tostring(text or "")\gsub "\r\n", "\\N"
  text\gsub "[\r\n]", "\\N"

writeMaskAss = (path, maskText, playX, playY, durationMs, sourceLine = nil, styles = nil, scriptInfo = nil, startMs = 0) ->
  return false unless finiteNumber(playX) and finiteNumber(playY) and playX > 0 and playY > 0
  durationMs = math.max AssCentisecondMs, finiteNumber(durationMs) or 1000
  info = scriptInfo or {
    {class: "info", key: "ScriptType", value: "v4.00+"}
    {class: "info", key: "PlayResX", value: tostring(playX)}
    {class: "info", key: "PlayResY", value: tostring(playY)}
  }
  local line
  if sourceLine
    line = ASSParser.create_dialogue_line {
      style: sourceLine.style, margin_l: sourceLine.margin_l, margin_r: sourceLine.margin_r,
      margin_t: sourceLine.margin_t, text: maskAssText(maskText), end_time: durationMs
    }
  else
    line = ASSParser.create_dialogue_line {text: maskAssText(maskText), end_time: durationMs, style: "Mask"}
  line.start_time = startMs
  line.end_time = startMs + durationMs
  outputStyles = [style for style in *(styles or {})]
  outputStyles[#outputStyles + 1] = ASSParser.create_style_line {name: "Mask", align: 7, outline: 0, shadow: 0, margin_l: 0, margin_r: 0, margin_t: 0} unless sourceLine
  chunks = {}
  ASSParser.generate_file info, nil, outputStyles, {line}, {}, (chunk) -> chunks[#chunks + 1] = chunk
  PyBridge.writeFile path, table.concat chunks

jobFrame = (job) ->
  frame = finiteNumber(job.frame) or Media.frameFromMs(job.time)
  assert frame and frame >= 0 and frame <= MaxVideoFrame and frame == math.floor(frame), "Invalid video frame."
  frame

captureCommand = (video, ffmpeg, job, outPath) ->
  arguments = {
    "-hide_banner", "-nostdin", "-loglevel", "error", "-y", "-ss", frameSeekTime(jobFrame(job)), "-i", video,
    "-map", "0:V:0", "-an", "-frames:v", "1", "-fps_mode", "passthrough"
  }
  if job.crop
    arguments[#arguments + 1] = "-vf"
    arguments[#arguments + 1] = cropFilter job.crop
  arguments[#arguments + 1] = outPath
  {executable: ffmpegExecutable(ffmpeg), args: arguments}

alphaCaptureCommand = (video, ffmpeg, job, outPath, maskPath, _videoW, _videoH) ->
  assFilter = filterPathQuote maskPath
  filter = "[0:V:0]split[base][maskSource];[maskSource]format=rgba,colorchannelmixer=rr=0:gg=0:bb=0:aa=0,subtitles=#{assFilter}:alpha=1,alphaextract[mask];[base]format=rgba[baseRgba];[baseRgba][mask]alphamerge[out]"
  {executable: ffmpegExecutable(ffmpeg), args: {
    "-hide_banner", "-nostdin", "-loglevel", "error", "-y", "-copyts", "-ss", frameSeekTime(jobFrame(job)), "-i", video,
    "-filter_complex", filter, "-map", "[out]", "-frames:v", "1", outPath
  }}

alphaBoundsCommand = (ffmpeg, imagePath) ->
  {executable: ffmpegExecutable(ffmpeg), args: {
    "-hide_banner", "-loglevel", "info", "-y", "-i", imagePath,
    "-vf", "alphaextract,bbox=min_val=0",
    "-frames:v", "1", "-f", "null", "-"
  }}

parseAlphaBounds = (text) ->
  crop = nil
  for w, h, x, y in tostring(text or "")\gmatch "crop=(%d+):(%d+):(%d+):(%d+)"
    crop = { w: tonumber(w), h: tonumber(h), x: tonumber(x), y: tonumber(y) }
  crop

detectAlphaCrop = (ffmpeg, imagePath, outDir, job) ->
  errPath = ffmpegErrorPath outDir, job, "alpha_bounds"
  ok = runCommand alphaBoundsCommand(ffmpeg, imagePath), errPath
  details = readFile errPath, MaxFfmpegErrorBytes
  PyBridge.removeFile errPath
  detailsText = LineOps.trim details
  return nil, "FFmpeg returned an error while detecting alpha bounds:\n#{imagePath}\n\nFFmpeg:\n#{detailsText}" unless ok
  crop = parseAlphaBounds details
  return nil, "FFmpeg could not detect a non-transparent alpha area in:\n#{imagePath}" unless crop
  crop, nil

cropPngCommand = (ffmpeg, imagePath, crop, outPath) ->
  {executable: ffmpegExecutable(ffmpeg), args: {
    "-hide_banner", "-loglevel", "error", "-y", "-i", imagePath,
    "-vf", cropFilter(crop), "-frames:v", "1", outPath
  }}

runCaptureJobs = (video, outDir, cfg, jobs) ->
  made, makeError = PyBridge.ensureDir outDir
  return false, "Could not create output folder: #{makeError or outDir}" unless made
  total = #jobs
  for index, job in ipairs jobs
    LineOps.progress "Capturing #{index}/#{total}", 100 * (index - 1) / math.max(1, total)
    outPath = PyBridge.joinPath outDir, job.name
    maskPath = maskAssPath(outDir, job) if job.alphaMaskText
    tempPath = alphaTempPath(outDir, job) if job.alphaDetectCrop
    protected, ok, message = pcall ->
      unless job.alphaMaskText
        return runFfmpeg captureCommand(video, cfg.ffmpeg, job, outPath), outDir, job, "writing PNG", outPath
      written = writeMaskAss maskPath, job.alphaMaskText, cfg.playX, cfg.playY, job.maskDurationMs, job.maskSource, cfg.styles, cfg.scriptInfo, job.maskStartMs or 0
      return false, "Snapshoter could not write the temporary vector mask." unless written
      alphaPath = tempPath or outPath
      captured, failure = runFfmpeg alphaCaptureCommand(video, cfg.ffmpeg, job, alphaPath, maskPath, cfg.videoW, cfg.videoH), outDir, job, "writing alpha PNG", alphaPath
      return false, failure unless captured
      if tempPath
        crop, failure = detectAlphaCrop cfg.ffmpeg, tempPath, outDir, job
        return false, failure unless crop
        return runFfmpeg cropPngCommand(cfg.ffmpeg, tempPath, crop, outPath), outDir, job, "writing cropped PNG", outPath
      true
    PyBridge.removeFile maskPath if maskPath
    PyBridge.removeFile tempPath if tempPath
    PyBridge.removeFile outPath unless protected and ok
    error ok, 0 unless protected
    return false, message unless ok
  LineOps.progress "Capture complete", 100
  true, nil

dialogueAssLine = (line, range) ->
  return nil unless line and line.class == "dialogue" and not line.comment
  startMs, endMs = finiteNumber(line.start_time), finiteNumber(line.end_time)
  return nil unless startMs and endMs and endMs > startMs and endMs > range.startMs and startMs < range.endMs
  ASSParser.line_to_raw line

sequenceRange = (lines) ->
  intervals = lineIntervals lines
  return nil unless #intervals > 0
  startFrame = intervals[1].first
  endFrame = intervals[1].last
  for item in *intervals
    startFrame = math.min startFrame, item.first
    endFrame = math.max endFrame, item.last
  startMs = Media.msFromFrame startFrame
  endMs = Media.msFromFrame(endFrame + 1)
  return nil unless startMs and endMs and endMs > startMs
  {
    :startFrame
    :endFrame
    frameCount: endFrame - startFrame + 1
    :startMs
    :endMs
    durationMs: endMs - startMs
  }

writeSequenceAss = (subs, assPath, range, videoW, videoH) ->
  rows = { "[Script Info]" }
  hasScriptType, hasPlayResX, hasPlayResY = false, false, false
  for i = 1, #subs
    LineOps.checkCancelled!
    line = subs[i]
    if line and line.class == "info" and line.key and (not line.section or line.section == "[Script Info]")
      key = LineOps.trim line.key
      value = tostring(line.value or "")
      if key != ""
        lower = key\lower!
        hasScriptType = true if lower == "scripttype"
        hasPlayResX = true if lower == "playresx"
        hasPlayResY = true if lower == "playresy"
        table.insert rows, "#{key}: #{value}"
  table.insert rows, "ScriptType: v4.00+" unless hasScriptType
  table.insert rows, "PlayResX: #{Core.formatNumber(videoW, 0)}" unless hasPlayResX or videoW <= 0
  table.insert rows, "PlayResY: #{Core.formatNumber(videoH, 0)}" unless hasPlayResY or videoH <= 0
  table.insert rows, ""
  table.insert rows, "[V4+ Styles]"
  table.insert rows, "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding"
  styleCount = 0
  for i = 1, #subs
    LineOps.checkCancelled!
    line = subs[i]
    if line and line.class == "style"
      table.insert rows, ASSParser.line_to_raw line
      styleCount += 1
  table.insert rows, ASSParser.line_to_raw(ASSParser.create_style_line!) if styleCount == 0
  table.insert rows, ""
  table.insert rows, "[Events]"
  table.insert rows, "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text"
  rendered = 0
  for i = 1, #subs
    LineOps.checkCancelled!
    line = subs[i]
    row = dialogueAssLine line, range
    if row
      table.insert rows, row
      rendered += 1
  ok = PyBridge.writeFile assPath, table.concat(rows, "\n")
  ok, rendered

sequenceOutputs = (cfg) ->
  {
    clean: if cfg.captureClean == nil then true else cfg.captureClean == true
    withSubtitles: cfg.captureWithSubtitles == true
    subtitlesOnly: cfg.captureSubtitlesOnly == true
  }

sequenceOutputCount = (outputs) ->
  count = 0
  count += 1 if outputs.clean
  count += 1 if outputs.withSubtitles
  count += 1 if outputs.subtitlesOnly
  count

runId = (prefix) ->
  suffix = if PyBridge.uniqueSuffix then PyBridge.uniqueSuffix! else tostring(os.time!)
  safeName("#{prefix}_#{os.date("%Y%m%d_%H%M%S")}_#{suffix}", "snapshoter")

prefixJobNames = (jobs, prefix) ->
  return unless jobs and prefix and prefix != ""
  for job in *jobs
    job.name = "#{prefix}_#{job.name}" if job and job.name

captureBatchFolder = (jobs) ->
  first = jobs and jobs[1]
  prefix = if first and first.mode then first.mode else "captures"
  runId prefix

sequenceFolderName = (range) ->
  runId string.format("sequence_%06d-%06d", range.startFrame, range.endFrame)

sequenceOutputItems = (outputs, assPath) ->
  items = {}
  table.insert items, { key: "clean", label: "No subtitles", filter: "" } if outputs.clean
  if outputs.withSubtitles or outputs.subtitlesOnly
    assFilter = filterPathQuote assPath
    table.insert items, { key: "with_subtitles", label: "With subtitles", filter: "subtitles=#{assFilter}" } if outputs.withSubtitles
    table.insert items, { key: "subtitles_only", label: "Subtitles only", filter: "format=rgba,colorchannelmixer=aa=0,subtitles=#{assFilter}:alpha=1,format=rgba" } if outputs.subtitlesOnly
  items

sequenceCommand = (video, ffmpeg, range, filter, pattern) ->
  filters = {}
  filters[#filters + 1] = filter if filter and filter != ""
  filters[#filters + 1] = "setpts=PTS-STARTPTS"
  {executable: ffmpegExecutable(ffmpeg), args: {
    "-hide_banner", "-nostdin", "-loglevel", "error", "-y", "-copyts", "-ss", frameSeekTime(range.startFrame), "-i", video, "-map", "0:V:0", "-an",
    "-vf", table.concat(filters, ","), "-frames:v", tostring(range.frameCount),
    "-start_number", tostring(range.startFrame), "-fps_mode", "passthrough", pattern
  }}

sequenceOutputDir = (snapshotsDir, sequenceDir, itemCount, item, flatten) ->
  return snapshotsDir if flatten
  return sequenceDir if itemCount == 1
  PyBridge.joinPath sequenceDir, item.key

sequenceOutputPattern = (dir, item, _range, flatten, sequenceName) ->
  if flatten
    PyBridge.joinPath dir, "#{sequenceName}_#{item.key}_%06d.png"
  else
    PyBridge.joinPath dir, "frame_%06d.png"

sequenceFramePath = (pattern, frame) ->
  path, count = tostring(pattern or "")\gsub "%%06d", string.format("%06d", frame), 1
  if count == 1 then path else nil

sequenceOutputComplete = (pattern, range) ->
  for frame = range.startFrame, range.endFrame
    LineOps.checkCancelled!
    path = sequenceFramePath pattern, frame
    return false unless path and Media.verifyPng path
  true

runFrameSequence = (subs, lines, video, outDir, cfg) ->
  return false, "Select at least one timed dialogue line for Frame sequence." unless lines and #lines > 0
  range = sequenceRange lines
  return false, "Could not build a frame range from the selected lines." unless range
  made, makeError = PyBridge.ensureDir outDir
  return false, "Could not create output folder: #{makeError or outDir}" unless made

  outputs = sequenceOutputs cfg
  return false, "Select at least one Frame sequence output." if sequenceOutputCount(outputs) == 0

  sequenceName = sequenceFolderName range
  assPath, rendered = "", 0
  if outputs.withSubtitles or outputs.subtitlesOnly
    assPath = PyBridge.joinPath outDir, "_snapshoter_#{sequenceName}.ass"
    ok, count = writeSequenceAss subs, assPath, range, cfg.videoW, cfg.videoH
    unless ok
      PyBridge.removeFile assPath
      return false, "Snapshoter could not write the temporary ASS file."
    rendered = count

  aegisub.progress.title "Snapshoter"
  aegisub.progress.task "Extracting frame sequence with FFmpeg"
  sequenceDir = if cfg.flatSnapshots then outDir else PyBridge.joinPath outDir, sequenceName
  unless cfg.flatSnapshots
    made, makeError = PyBridge.ensureDir sequenceDir
    unless made
      PyBridge.removeFile assPath if assPath != ""
      return false, "Could not create sequence folder: #{makeError or sequenceDir}"
  items = sequenceOutputItems outputs, assPath
  outputDirs = {}
  for item in *items
    dir = sequenceOutputDir outDir, sequenceDir, #items, item, cfg.flatSnapshots
    made, makeError = PyBridge.ensureDir dir
    unless made
      PyBridge.removeFile assPath if assPath != ""
      return false, "Could not create sequence output folder: #{makeError or dir}"
    outputDirs[item.key] = dir
    pattern = sequenceOutputPattern dir, item, range, cfg.flatSnapshots, sequenceName
    ok, details = PyBridge.runProcess sequenceCommand(video, cfg.ffmpeg, range, item.filter, pattern)
    unless ok
      PyBridge.removeFile assPath if assPath != ""
      return false, "FFmpeg returned an error while writing sequence frames to:\n#{dir}\n\n#{details or ''}"
    checked, complete = pcall sequenceOutputComplete, pattern, range
    unless checked or assPath == ""
      PyBridge.removeFile assPath
    error complete, 0 unless checked
    unless complete
      PyBridge.removeFile assPath if assPath != ""
      return false, "FFmpeg did not create the complete requested frame range in:\n#{dir}"
  PyBridge.removeFile assPath if assPath != ""

  message = "Frame sequence written to:\n#{outDir}"
  message ..= "\nFrames: #{range.startFrame}-#{range.endFrame} (#{range.frameCount})"
  message ..= "\nSubtitle lines rendered: #{rendered or 0}"
  unless cfg.flatSnapshots
    folders = {}
    if #items == 1
      table.insert folders, sequenceDir
    else
      for item in *items
        table.insert folders, outputDirs[item.key]
    message ..= "\nFolders:\n" .. table.concat folders, "\n"
  else
    message ..= "\nImages were written directly in Snapshots."
  true, message

buildInterface = (_video, lineCount, frameDefaults) ->
  {
    main: {
      title: { class: "label", label: "Snapshoter", x: 0, y: 0, width: 4, height: 1 }
      count: { class: "label", label: "Selected dialogue lines: #{lineCount}", x: 4, y: 0, width: 8, height: 1 }
      modeLabel: { class: "label", label: "Capture", x: 0, y: 1, width: 2, height: 1 }
      mode: { class: "dropdown", value: "Selected lines", items: CaptureModes, config: true, x: 2, y: 1, width: 5, height: 1 }
      timingLabel: { class: "label", label: "Timing", x: 7, y: 1, width: 2, height: 1 }
      timing: { class: "dropdown", value: "Midpoint", items: TimingModes, config: true, x: 9, y: 1, width: 5, height: 1 }
      clipOutputLabel: { class: "label", label: "Clip output", x: 0, y: 2, width: 2, height: 1 }
      clipOutput: { class: "dropdown", value: "Rectangle crop", items: ClipOutputs, config: true, x: 2, y: 2, width: 6, height: 1 }
      outputInfo: { class: "label", label: "Output: project folder / Snapshots", x: 0, y: 3, width: 14, height: 1 }
      includeText: { class: "checkbox", label: "Add subtitle text to filenames", value: true, config: true, x: 2, y: 4, width: 6, height: 1 }
      flatSnapshots: { class: "checkbox", label: "All images in Snapshots", value: false, config: true, x: 12, y: 4, width: 5, height: 1 }
      sequenceInfo: { class: "label", label: "Frame sequence outputs", x: 0, y: 5, width: 4, height: 1 }
      captureClean: { class: "checkbox", label: "No subtitles", value: true, config: true, x: 4, y: 5, width: 4, height: 1 }
      captureWithSubtitles: { class: "checkbox", label: "With subtitles", value: false, config: true, x: 8, y: 5, width: 4, height: 1 }
      captureSubtitlesOnly: { class: "checkbox", label: "Subtitles only", value: false, config: true, x: 12, y: 5, width: 4, height: 1 }
      frameInfo: { class: "label", label: "Frame list mode accepts: 120f, 130f or 120f > P1 fade 6f.", x: 0, y: 6, width: 14, height: 1 }
      frameText: { class: "textbox", value: frameDefaults or "", config: false, x: 2, y: 7, width: 12, height: 4 }
      rectInfo: { class: "label", label: "Rectangle crops need a static clip. Alpha outputs follow clips or drawing geometry.", x: 0, y: 11, width: 14, height: 1 }
      paddingLabel: { class: "label", label: "Padding", x: 0, y: 12, width: 2, height: 1 }
      cropPadding: { class: "intedit", value: 0, min: 0, config: true, x: 2, y: 12, width: 3, height: 1 }
      xLabel: { class: "label", label: "X", x: 5, y: 12, width: 1, height: 1 }
      manualX: { class: "intedit", value: 0, config: true, x: 6, y: 12, width: 3, height: 1 }
      yLabel: { class: "label", label: "Y", x: 9, y: 12, width: 1, height: 1 }
      manualY: { class: "intedit", value: 0, config: true, x: 10, y: 12, width: 3, height: 1 }
      wLabel: { class: "label", label: "W", x: 0, y: 13, width: 1, height: 1 }
      manualW: { class: "intedit", value: 320, min: 1, config: true, x: 1, y: 13, width: 3, height: 1 }
      hLabel: { class: "label", label: "H", x: 4, y: 13, width: 1, height: 1 }
      manualH: { class: "intedit", value: 180, min: 1, config: true, x: 5, y: 13, width: 3, height: 1 }
    }
    config: {
      title: { class: "label", label: "Snapshoter Config", x: 0, y: 0, width: 6, height: 1 }
      ffmpegLabel: { class: "label", label: "FFmpeg", x: 0, y: 1, width: 2, height: 1 }
      ffmpeg: { class: "edit", value: "ffmpeg", config: true, x: 2, y: 1, width: 12, height: 1 }
    }
  }

readConfig = (video, lineCount, frameDefaults) ->
  interface = buildInterface video, lineCount, frameDefaults
  options = configHandler interface, ConfigFile, true, script_version
  options\read!
  options\updateInterface "main"
  options\updateInterface "config"
  interface.main.clipOutput.value = normalizeClipOutput(interface.main.clipOutput.value)
  save = ->
    ok, written, failure = pcall -> options\write!
    showMessage "Could not save preferences: #{if ok then failure or "write failed" else written}" if not ok or written == false
  while true
    button, result = aegisub.dialog.display interface.main, { "Execute", "Config...", "Cancel" }, { ok: "Execute", close: "Cancel" }
    return nil unless button == "Execute" or button == "Config..."
    for name, value in pairs result
      control = interface.main[name]
      control.value = value if control

    if button == "Config..."
      cfgButton, cfgResult = aegisub.dialog.display interface.config, { "Execute", "Cancel" }, { ok: "Execute", close: "Cancel" }
      if cfgButton == "Execute"
        options\updateConfiguration cfgResult, "config"
        save!
        options\updateInterface "config"
      continue
    if button == "Execute"
      invalid = nil
      for name in *{"cropPadding", "manualX", "manualY", "manualW", "manualH"}
        number = finiteNumber(result[name] or interface.main[name].value)
        if not number or (name == "cropPadding" and number < 0) or ((name == "manualW" or name == "manualH") and number <= 0)
          invalid = "Enter finite rectangle values, positive width/height and nonnegative padding."
          break
        result[name] = number
      if result.mode == "Frame list" and not invalid
        frames, errors = parseFrameList result.frameText
        invalid = table.concat(errors, "\n") if #errors > 0
        invalid = "Enter at least one frame." if #frames == 0 and not invalid
      if invalid
        showMessage invalid
        continue
      options\updateConfiguration result, "main"
      save!
      return {
        mode: choiceOrDefault(normalizeMode(result.mode), CaptureModes, "Selected lines")
        timing: choiceOrDefault(result.timing, TimingModes, "Midpoint")
        clipOutput: choiceOrDefault(normalizeClipOutput(result.clipOutput), ClipOutputs, "Rectangle crop")
        ffmpeg: LineOps.trim(interface.config.ffmpeg.value)
        includeText: result.includeText == true
        flatSnapshots: result.flatSnapshots == true
        captureClean: result.captureClean == true
        captureWithSubtitles: result.captureWithSubtitles == true
        captureSubtitlesOnly: result.captureSubtitlesOnly == true
        frameText: tostring(result.frameText or "")
        cropPadding: tonumber(result.cropPadding) or 0
        manualX: tonumber(result.manualX) or 0
        manualY: tonumber(result.manualY) or 0
        manualW: tonumber(result.manualW) or 1
        manualH: tonumber(result.manualH) or 1
      }

canRun = ->
  if not Media.frameFromMs or not aegisub.ms_from_frame
    return false, "Load a video before running Snapshoter."
  if not videoPath!
    return false, "Load a video before running Snapshoter."
  true

snapshoter = (subs, sel) ->
  video = videoPath!
  unless video
    showMessage "Load a video before running Snapshoter."
    return

  collection, lines = selectedLines subs, sel or {}

  frameDefaults = buildFrameDefaults defaultFrameList(lines)
  configOk, cfg = pcall readConfig, video, #lines, frameDefaults
  unless configOk
    showMessage "Could not read Snapshoter settings: #{tostring(cfg)}"
    return
  return unless cfg
  cfg.ffmpeg = "ffmpeg" if cfg.ffmpeg == ""
  cfg.videoW, cfg.videoH = videoSize!
  if cfg.videoW <= 0 or cfg.videoH <= 0
    showMessage "Could not obtain the loaded video's dimensions."
    return
  cfg.playX = tonumber(collection.meta and collection.meta.PlayResX)
  cfg.playY = tonumber(collection.meta and collection.meta.PlayResY)
  cfg.playX = cfg.videoW unless cfg.playX and cfg.playX > 0
  cfg.playY = cfg.videoH unless cfg.playY and cfg.playY > 0

  cfg.styles, cfg.scriptInfo = {}, {}
  for index = 1, #subs
    line = subs[index]
    if line.class == "style"
      cfg.styles[#cfg.styles + 1] = line
    elseif line.class == "info" and (not line.section or line.section == "[Script Info]")
      cfg.scriptInfo[#cfg.scriptInfo + 1] = line
  cfg.scriptInfo[#cfg.scriptInfo + 1] = {class: "info", key: "PlayResX", value: tostring(cfg.playX)}
  cfg.scriptInfo[#cfg.scriptInfo + 1] = {class: "info", key: "PlayResY", value: tostring(cfg.playY)}
  outDir = snapshotsFolder video
  made, makeError = PyBridge.ensureDir outDir
  unless made
    showMessage "Could not create Snapshots folder: #{makeError or outDir}"
    return

  if cfg.mode == "Frame sequence"
    _, message = runFrameSequence subs, lines, video, outDir, cfg
    showMessage message
    return

  jobs, skipped, errors = makeJobs collection, lines, cfg
  if #errors > 0
    showMessage table.concat errors, "\n"
    return
  if #jobs == 0
    showMessage "No captures were queued. Clip modes need \\clip/\\iclip; drawing modes need a selected \\p vector line."
    return
  captureDir = if cfg.flatSnapshots or #jobs == 1 then outDir else PyBridge.joinPath outDir, captureBatchFolder jobs
  prefixJobNames jobs, runId("capture") if captureDir == outDir
  log.debug "Snapshoter queued %d capture job(s) in %s", #jobs, captureDir

  aegisub.progress.title "Snapshoter"
  aegisub.progress.task "Capturing PNG frames with FFmpeg"
  ok, errorMessage = runCaptureJobs video, captureDir, cfg, jobs

  if ok
    message = "#{#jobs} PNG capture"
    message ..= "s" if #jobs != 1
    message ..= " written to:\n#{captureDir}"
    if captureDir != outDir
      message ..= "\nSnapshots root:\n#{outDir}"
    if #skipped > 0
      message ..= "\nSkipped #{#skipped} line(s) without usable \\clip/\\iclip."
    showMessage message
  else
    showMessage errorMessage

if depctrl and depctrl.registerMacro
  depctrl\registerMacro script_name, script_description, snapshoter, canRun, nil, false
else
  aegisub.register_macro script_name, script_description, snapshoter, canRun

require("kite.UI").publishActions()
