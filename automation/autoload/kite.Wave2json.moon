export script_name        = "Wave2json"
export script_description = "Export the active audio waveform to JSON."
export script_author      = "Kiterow"
export script_version     = "1.3.6"
export script_namespace   = "kite.Wave2json"

sampleRate = 48000
channels = 1
bits = 16
bytesPerSample = bits / 8
basePointMs = 1
samplesPerPoint = sampleRate * basePointMs / 1000
readBytes = 262144
sampleModulus = 2 ^ bits
sampleMidpoint = sampleModulus / 2
amplitudeMin = -sampleMidpoint
amplitudeMax = sampleMidpoint - 1
byteBase = 256

haveDepCtrl, DependencyControl = pcall require, "l0.DependencyControl"
depctrl = nil
local PyBridge, LineOps, Media, Core
if haveDepCtrl and DependencyControl
  depctrl = DependencyControl{
    name: script_name
    description: script_description
    author: script_author
    version: script_version
    namespace: script_namespace
    feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
    {
      {"kite.PyBridge", version: "1.7.2", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts", feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
      {"kite.LineOps", version: "1.7.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts", feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
      {"kite.Media", version: "1.4.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts", feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
      {"kite.Core", version: "1.1.0"}
      {"kite.UI", version: "1.5.1"}
    }
  }

if depctrl
  PyBridge, LineOps, Media, Core = depctrl\requireModules!
else
  PyBridge = require "kite.PyBridge"
  LineOps = require "kite.LineOps"
  Media = require "kite.Media"
  Core = require "kite.Core"

sharedUI = require "kite.UI"

trim = LineOps.trim
roundInt = LineOps.round
fileExists = PyBridge.fileExists
joinPath = PyBridge.joinPath
removeFile = PyBridge.removeFile

writeChecked = (file, ...) ->
  written, message = file\write ...
  error message or "Could not write output." unless written
  written

ffmpegTime = (ms) ->
  string.format "%.3f", math.max(0, Core.finiteNumber(ms) or 0) / 1000

dirName = (path) ->
  tostring(path or "")\match("^(.*)[\\/]") or ""

baseName = (path) ->
  name = tostring(path or "")\match("([^\\/]+)$") or tostring(path or "")
  name = name\gsub "%.[^%.\\/]*$", ""
  if name == "" then "waveform" else name

safeName = (value, fallback = "wave2json") ->
  out = trim(value)\gsub("[%z\1-\31\\/:*?\"<>|]+", "_")\gsub("%s+", "_")
  out = out\gsub "_+", "_"
  out = out\gsub "^_+", ""
  out = out\gsub "_+$", ""
  out = out\gsub "[%.%s]+$", ""
  lower = out\lower!\match("^[^%.]+") or ""
  reserved = lower == "con" or lower == "prn" or lower == "aux" or lower == "nul" or lower\match("^com[1-9]$") or lower\match("^lpt[1-9]$")
  return fallback if out == "" or out == "." or out == ".." or out\match("^%.+$") or reserved
  out

selectedLineRanges = (subs, sel) ->
  records, rejected = LineOps.selectedLines subs, sel, ((line) ->
    return false unless line and line.class == "dialogue" and not line.comment
    startTime, endTime = Core.finiteNumber(line.start_time), Core.finiteNumber(line.end_time)
    startTime and endTime and endTime > startTime
  ), true
  unless records and #records > 0
    suffix = if rejected and #rejected > 0 then " Invalid rows: " .. table.concat(rejected, ", ") else ""
    return nil, "Select only uncommented dialogue lines with valid timing." .. suffix
  ranges = {}
  for record in *records
    startMs = math.max 0, roundInt record.line.start_time
    endMs = roundInt record.line.end_time
    return nil, "Line #{record.index} has no positive duration after clipping to the media start." if endMs <= startMs
    ranges[#ranges + 1] = {
      :startMs
      :endMs
      durationMs: endMs - startMs
      lineCount: 1
      lineIndex: record.index
    }
  ranges

selectionRange = (subs, sel) ->
  ranges, message = selectedLineRanges subs, sel
  return nil, message unless ranges
  startMs, endMs = ranges[1].startMs, ranges[1].endMs
  for range in *ranges
    startMs = range.startMs if range.startMs < startMs
    endMs = range.endMs if range.endMs > endMs
  {
    :startMs
    :endMs
    durationMs: endMs - startMs
    lineCount: #ranges
  }

mediaCandidate = ->
  path = Media.projectPath "audio", {fallbackVideo: true}
  return path, "audio" if path
  "", "manual"

rangeSuffix = (range) ->
  return "" unless range
  "_#{roundInt range.startMs}-#{roundInt range.endMs}ms"

defaultOutputPath = (media, range = nil) ->
  ass = LineOps.subtitlePath! or ""
  root = if ass != "" then dirName ass else dirName media
  source = if ass != "" then ass else media
  joinPath root, "#{safeName baseName(source), "waveform"}#{rangeSuffix range}.waveform.json"

outputStem = (path) ->
  name = tostring(path or "")\match("([^\\/]+)$") or ""
  name = name\gsub "%.waveform%.json$", ""
  name = name\gsub "%.[^%.\\/]*$", ""
  safeName name, "waveform"

outputRoot = (outputPath, media) ->
  folder = dirName outputPath
  return folder if folder != ""
  folder = dirName media
  if folder != "" then folder else (LineOps.decodedPath("?temp") or "")

lineOutputPath = (baseOutput, media, range, order) ->
  folder = dirName baseOutput
  folder = outputRoot baseOutput, media if folder == ""
  stem = outputStem baseOutput
  lineNumber = string.format "%03d", math.max(1, tonumber(order) or 1)
  joinPath folder, "#{stem}_line#{lineNumber}#{rangeSuffix range}.waveform.json"

progressTitle = (text) ->
  if aegisub and aegisub.progress and aegisub.progress.title
    pcall aegisub.progress.title, tostring(text or "")
  LineOps.checkCancelled!

progressTask = (text) ->
  LineOps.progress text

progressSet = (value) ->
  LineOps.progress nil, value

progressCancelled = ->
  return false unless aegisub and aegisub.progress and aegisub.progress.is_cancelled
  ok, cancelled = pcall aegisub.progress.is_cancelled
  ok and cancelled == true

showMessage = (text) ->
  sharedUI.message text

runFfmpeg = (cfg, pcmPath) ->
  stream = Core.finiteNumber cfg.stream or 0
  return false, "The audio stream must be a non-negative integer." unless stream and stream >= 0 and stream == math.floor(stream)
  executable = trim cfg.ffmpeg
  executable = "ffmpeg" if executable == ""
  executable = executable\sub(2, -2) if executable\match('^".*"$') or executable\match("^'.*'$")
  arguments = {"-hide_banner", "-nostdin", "-loglevel", "error", "-y"}
  table.insert arguments, "-i"
  table.insert arguments, cfg.media
  if cfg.range
    startMs, durationMs = Core.finiteNumber(cfg.range.startMs), Core.finiteNumber(cfg.range.durationMs)
    return false, "The audio range must have a finite start and positive duration." unless startMs and startMs >= 0 and durationMs and durationMs > 0
    table.insert arguments, "-ss"
    table.insert arguments, ffmpegTime startMs
    table.insert arguments, "-t"
    table.insert arguments, ffmpegTime cfg.range.durationMs
  for value in *{
    "-map", "0:a:#{stream}", "-vn", "-ac", tostring(channels), "-ar", tostring(sampleRate), "-f", "s16le", pcmPath
  }
    table.insert arguments, value
  PyBridge.runProcess {executable: executable, args: arguments}

readConfig = ->
  media = mediaCandidate!
  return nil, "No active audio file is loaded." if trim(media) == ""
  {
    media: media
    output: defaultOutputPath media
    ffmpeg: "ffmpeg"
    stream: 0
    range: nil
  }

newPyramid = (tempPrefix) ->
  pyramid = {
    levels: {}
    tempPrefix: tempPrefix
  }

  pyramid.ensureLevel = (self, index) ->
    state = self.levels[index]
    unless state
      scale = 2 ^ (index - 1)
      path = "#{self.tempPrefix}_level_#{index}.tmp"
      file = io.open path, "wb"
      error "Could not create temporary level file: #{path}" unless file
      state = {
        index: index
        scale: scale
        pointMs: basePointMs * scale
        samplesPerPoint: samplesPerPoint * scale
        points: 0
        path: path
        file: file
        pendingCount: 0
      }
      self.levels[index] = state
    state

  pyramid.emitPair = (self, index, minValue, maxValue) ->
    state = self\ensureLevel index
    writeChecked state.file, tostring(roundInt(minValue)), ",", tostring(roundInt(maxValue)), "\n"
    state.points += 1
    if state.pendingCount == 0
      state.pendingMin = minValue
      state.pendingMax = maxValue
      state.pendingCount = 1
    else
      cmin = math.min state.pendingMin, minValue
      cmax = math.max state.pendingMax, maxValue
      state.pendingCount = 0
      self\emitPair index + 1, cmin, cmax

  pyramid.flush = (self) ->
    index = 1
    while index <= #self.levels
      state = self.levels[index]
      if state and state.pendingCount == 1 and index < #self.levels
        minValue, maxValue = state.pendingMin, state.pendingMax
        state.pendingCount = 0
        self\emitPair index + 1, minValue, maxValue
      index += 1
    for state in *self.levels
      if state.file
        closed, message = state.file\close!
        error message or "Could not finish temporary waveform level." unless closed
      state.file = nil

  pyramid.cleanup = (self) ->
    for state in *(self.levels or {})
      pcall -> state.file\close! if state.file
      removeFile state.path

  pyramid

processPcm = (pcmPath, tempPrefix, totalBytes = nil) ->
  input = io.open pcmPath, "rb"
  return nil, "Could not open decoded PCM." unless input

  pyramid = newPyramid tempPrefix
  currentMin, currentMax = amplitudeMax, amplitudeMin
  samplesInPoint = 0
  totalSamples = 0
  bytesRead = 0
  leftover = ""

  ok, result, failure = pcall ->
    progressTask "Reading PCM and building waveform"
    while true
      return nil, "Cancelled." if progressCancelled!
      data, readError = input\read readBytes
      error readError if readError
      break unless data and #data > 0
      if leftover != ""
        data = leftover .. data
        leftover = ""
      if (#data % bytesPerSample) == 1
        leftover = data\sub #data
        data = data\sub 1, #data - 1
      bytesRead += #data
      if totalBytes and totalBytes > 0
        progressSet 20 + 70 * math.min(1, bytesRead / totalBytes)

      pos = 1
      limit = #data
      while pos < limit
        lo = data\byte(pos)
        hi = data\byte(pos + 1)
        sample = lo + hi * byteBase
        sample -= sampleModulus if sample >= sampleMidpoint
        currentMin = sample if sample < currentMin
        currentMax = sample if sample > currentMax
        samplesInPoint += 1
        totalSamples += 1
        if samplesInPoint >= samplesPerPoint
          pyramid\emitPair 1, currentMin, currentMax
          currentMin, currentMax = amplitudeMax, amplitudeMin
          samplesInPoint = 0
        pos += bytesPerSample

    error "Decoded PCM ended with an incomplete sample." if leftover != ""
    error "Decoded PCM size changed while reading." if totalBytes and bytesRead != totalBytes
    error "Decoded PCM contains no samples." if totalSamples == 0
    if samplesInPoint > 0
      pyramid\emitPair 1, currentMin, currentMax
    pyramid\flush!

    durationMs = totalSamples * 1000 / sampleRate
    { :pyramid, :durationMs, :totalSamples }, nil

  pcall -> input\close!
  unless ok
    pyramid\cleanup!
    return nil, tostring result
  unless result
    pyramid\cleanup!
    return nil, failure
  result, nil

copyLevelPeaks = (out, level) ->
  file = io.open level.path, "rb"
  return false, "Could not read temporary level file." unless file
  ok, failure = pcall ->
    first, count = true, 0
    buffer, bytes = {}, 0
    flush = ->
      return if #buffer == 0
      LineOps.checkCancelled!
      writeChecked out, (if first then "" else ","), table.concat(buffer, ",")
      first, buffer, bytes = false, {}, 0
    while true
      line, readError = file\read "*l"
      error readError if readError
      break unless line
      buffer[#buffer + 1] = line
      bytes += #line + 1
      count += 1
      flush! if bytes >= readBytes
    error "Temporary waveform level is incomplete." unless count == level.points
    flush!
  file\close!
  return false, tostring(failure) unless ok
  true

writeJson = (outputPath, result) ->
  PyBridge.withAtomicFile outputPath, (out) ->
    pyramid = result.pyramid
    writeChecked out, "{\n"
    writeChecked out, '  "type": "waveform",\n'
    writeChecked out, '  "version": 1,\n'
    writeChecked out, '  "sampleRate": ', tostring(sampleRate), ",\n"
    writeChecked out, '  "channels": ', tostring(channels), ",\n"
    writeChecked out, '  "bits": ', tostring(bits), ",\n"
    writeChecked out, '  "amplitudeFormat": "s16",\n'
    writeChecked out, '  "amplitudeMin": ', tostring(amplitudeMin), ',\n'
    writeChecked out, '  "amplitudeMax": ', tostring(amplitudeMax), ',\n'
    writeChecked out, '  "pointLayout": "interleavedMinMax",\n'
    if result.range
      writeChecked out, '  "sourceStartMs": ', tostring(result.range.startMs), ",\n"
      writeChecked out, '  "sourceEndMs": ', tostring(result.range.endMs), ",\n"
      writeChecked out, '  "sourceDurationMs": ', tostring(result.range.durationMs), ",\n"
      writeChecked out, '  "sourceLineCount": ', tostring(result.range.lineCount), ",\n"
    writeChecked out, '  "durationMs": ', Core.formatNumber(result.durationMs, 6), ",\n"
    writeChecked out, '  "totalSamples": ', tostring(result.totalSamples), ",\n"
    writeChecked out, '  "levels": [\n'
    for i, level in ipairs pyramid.levels
      writeChecked out, ",\n" if i > 1
      writeChecked out, "    {\n"
      writeChecked out, '      "scale": ', tostring(level.scale), ",\n"
      writeChecked out, '      "pointMs": ', tostring(level.pointMs), ",\n"
      writeChecked out, '      "samplesPerPoint": ', tostring(level.samplesPerPoint), ",\n"
      writeChecked out, '      "points": ', tostring(level.points), ",\n"
      writeChecked out, '      "peaks": ['
      copied, copyError = copyLevelPeaks out, level
      error copyError unless copied
      writeChecked out, "]\n"
      writeChecked out, "    }"
    writeChecked out, "\n  ]\n"
    writeChecked out, "}\n"

exportWaveform = (cfg) ->
  return false, "Choose an audio or video file." if trim(cfg.media) == ""
  return false, "Media file does not exist:\n#{cfg.media}" unless fileExists cfg.media
  return false, "Choose a JSON output path." if trim(cfg.output) == ""
  root = outputRoot cfg.output, cfg.media
  return false, "Could not resolve an output folder." if trim(root) == ""
  cfg.output = joinPath root, cfg.output if dirName(cfg.output) == ""
  made, makeError = PyBridge.ensureDir root
  return false, "Could not create output folder: #{makeError or root}" unless made
  paths, pathError = PyBridge.tempPaths "wave2json", {pcm: ".s16le", prefix: ""}
  return false, pathError or "Could not create temporary paths." unless paths
  pyramid = nil
  pcallOk, success, message = pcall ->
    progressTitle script_name
    progressTask "Decoding audio with FFmpeg"
    progressSet 5
    okFfmpeg, detail, code = runFfmpeg cfg, paths.pcm
    return false, "Cancelled." if code == 130
    unless okFfmpeg
      return false, "FFmpeg could not decode the selected audio stream.\n#{detail or ""}"
    size = Media.fileSize(paths.pcm) or 0
    return false, "FFmpeg produced an empty PCM file." if size <= 0
    progressSet 20
    result, err = processPcm paths.pcm, paths.prefix, size
    return false, err if err
    pyramid = result.pyramid
    result.range = cfg.range
    progressTask "Writing JSON"
    progressSet 95
    okJson, jsonErr = writeJson cfg.output, result
    return false, jsonErr unless okJson
    progressSet 100
    rangeText = if cfg.range then "\nRange: #{cfg.range.startMs} ms - #{cfg.range.endMs} ms" else ""
    true, "Waveform JSON written:\n#{cfg.output}#{rangeText}\n\nDuration: #{result.durationMs} ms\nLevels: #{#result.pyramid.levels}"
  PyBridge.cleanup paths
  pyramid\cleanup! if pyramid
  if pcallOk then success, message else false, tostring success

exportLineRanges = (cfg, ranges) ->
  return false, "Select at least one subtitle line with valid timing." unless ranges and #ranges > 0
  firstOutput, lastOutput = nil, nil
  for i, range in ipairs ranges
    output = lineOutputPath cfg.output, cfg.media, range, i
    lineCfg = {
      media: cfg.media
      output: output
      ffmpeg: cfg.ffmpeg
      stream: cfg.stream
      range: range
    }
    ok, message = exportWaveform lineCfg
    unless ok
      return false, "Line #{range.lineIndex or i} failed:\n#{message}"
    firstOutput = output unless firstOutput
    lastOutput = output
  folder = dirName(firstOutput or cfg.output)
  true, "Waveform JSON files written: #{#ranges}\nFolder: #{folder}\nFirst: #{firstOutput}\nLast: #{lastOutput}"

readBaseConfig = ->
  cfg, message = readConfig!
  unless cfg
    showMessage message
    return nil
  cfg

mainFull = ->
  cfg = readBaseConfig!
  return unless cfg
  _, message = exportWaveform cfg
  showMessage message

mainSelection = (subs, sel) ->
  cfg = readBaseConfig!
  return unless cfg
  range, rangeError = selectionRange subs, sel
  unless range
    showMessage rangeError
    return
  cfg.range = range
  cfg.output = defaultOutputPath cfg.media, range
  _, message = exportWaveform cfg
  showMessage message

mainEach = (subs, sel) ->
  cfg = readBaseConfig!
  return unless cfg
  ranges, rangeError = selectedLineRanges subs, sel
  unless ranges
    showMessage rangeError
    return
  first = ranges[1]
  cfg.output = defaultOutputPath cfg.media, first
  _, message = exportLineRanges cfg, ranges
  showMessage message

canRunFull = ->
  media = mediaCandidate!
  trim(media) != ""

canRunSelection = (subs, sel) ->
  ranges = selectedLineRanges subs, sel
  ranges != nil and canRunFull!

macros = {
  {"Full audio", "Export the complete active audio waveform to JSON.", mainFull, canRunFull}
  {"Selected span", "Export one waveform covering the selected subtitle span.", mainSelection, canRunSelection}
  {"Each selected line", "Export one waveform JSON per selected subtitle line.", mainEach, canRunSelection}
}

if aegisub and aegisub.register_macro
  if depctrl and depctrl.registerMacros
    depctrl\registerMacros macros
  else
    for macro in *macros
      aegisub.register_macro "#{script_name}/#{macro[1]}", macro[2], macro[3], macro[4]

sharedUI.publishActions!
