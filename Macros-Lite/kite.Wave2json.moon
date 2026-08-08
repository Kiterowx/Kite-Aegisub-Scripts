export script_name        = "Wave2json"
export script_description = "Export the active audio waveform to JSON."
export script_author      = "Kiterow"
export script_version     = "1.3.2"
export script_namespace   = "kite.Wave2json"

SAMPLE_RATE       = 48000
CHANNELS          = 1
BITS              = 16
BYTES_PER_SAMPLE  = 2
BASE_POINT_MS     = 1
SAMPLES_PER_POINT = SAMPLE_RATE / 1000
READ_BYTES        = 262144
MAX_STREAM_INDEX  = 63

haveDepCtrl, DependencyControl = pcall require, "l0.DependencyControl"
depctrl = nil
local PyBridge, LineOps
if haveDepCtrl and DependencyControl
  depctrl = DependencyControl{
    name: script_name
    description: script_description
    author: script_author
    version: script_version
    namespace: script_namespace
    feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
    {
      {"kite.PyBridge", version: "1.4.4", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts", feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
      {"kite.LineOps", version: "1.5.2", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts", feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    }
  }

if depctrl
  PyBridge, LineOps = depctrl\requireModules!
else
  PyBridge = require "kite.PyBridge"
  LineOps = require "kite.LineOps"

trim = LineOps.trim
round_int = LineOps.round
file_exists = PyBridge.fileExists
join_path = PyBridge.joinPath
write_file = PyBridge.writeFile
remove_file = PyBridge.removeFile

write_checked = (file, ...) ->
  written, message = file\write ...
  error message or "Could not write output." unless written
  written

ffmpeg_time = (ms) ->
  string.format "%.3f", math.max(0, tonumber(ms) or 0) / 1000

dir_name = (path) ->
  tostring(path or "")\match("^(.*)[\\/]") or ""

base_name = (path) ->
  name = tostring(path or "")\match("([^\\/]+)$") or tostring(path or "")
  name = name\gsub "%.[^%.\\/]*$", ""
  if name == "" then "waveform" else name

safe_name = (value, fallback = "wave2json") ->
  out = trim(value)\gsub("[\\/:*?\"<>|]+", "_")\gsub("%s+", "_")
  out = out\gsub "_+", "_"
  out = out\gsub "^_+", ""
  out = out\gsub "_+$", ""
  out = out\gsub "[%.%s]+$", ""
  lower = out\lower!
  reserved = lower == "con" or lower == "prn" or lower == "aux" or lower == "nul" or lower\match("^com[1-9]$") or lower\match("^lpt[1-9]$")
  return fallback if out == "" or out == "." or out == ".." or out\match("^%.+$") or reserved
  out

decoded_path = (spec) ->
  LineOps.decodedPath(spec) or ""

project_props = ->
  LineOps.projectProperties!

script_file_path = ->
  LineOps.subtitlePath! or ""

selected_line_ranges = (subs, sel) ->
  records, rejected = LineOps.selectedLines subs, sel, ((line) ->
    line and line.class == "dialogue" and not line.comment and tonumber(line.end_time) and tonumber(line.start_time) and tonumber(line.end_time) > tonumber(line.start_time)
  ), true
  unless records and #records > 0
    suffix = if rejected and #rejected > 0 then " Invalid rows: " .. table.concat(rejected, ", ") else ""
    return nil, "Select only uncommented dialogue lines with valid timing." .. suffix
  ranges = {}
  for record in *records
    start_ms = math.max 0, round_int record.line.start_time
    end_ms = math.max start_ms, round_int record.line.end_time
    ranges[#ranges + 1] = {
      :start_ms
      :end_ms
      duration_ms: end_ms - start_ms
      line_count: 1
      line_index: record.index
    }
  ranges

selection_range = (subs, sel) ->
  ranges, message = selected_line_ranges subs, sel
  return nil, message unless ranges
  start_ms, end_ms = ranges[1].start_ms, ranges[1].end_ms
  for range in *ranges
    start_ms = range.start_ms if range.start_ms < start_ms
    end_ms = range.end_ms if range.end_ms > end_ms
  {
    :start_ms
    :end_ms
    duration_ms: end_ms - start_ms
    line_count: #ranges
  }

media_candidate = ->
  props = project_props!
  audio = trim props.audio_file
  return audio, "audio" if audio != "" and file_exists audio
  path = decoded_path "?audio"
  return path, "audio" if path != "" and file_exists path
  "", "manual"

range_suffix = (range) ->
  return "" unless range
  "_#{round_int range.start_ms}-#{round_int range.end_ms}ms"

default_output_path = (media, range = nil) ->
  ass = script_file_path!
  root = if ass != "" then dir_name ass else dir_name media
  source = if ass != "" then ass else media
  join_path root, "#{safe_name base_name(source), "waveform"}#{range_suffix range}.waveform.json"

output_stem = (path) ->
  name = tostring(path or "")\match("([^\\/]+)$") or ""
  name = name\gsub "%.waveform%.json$", ""
  name = name\gsub "%.[^%.\\/]*$", ""
  safe_name name, "waveform"

output_root = (output_path, media) ->
  folder = dir_name output_path
  return folder if folder != ""
  folder = dir_name media
  if folder != "" then folder else decoded_path("?temp")

line_output_path = (base_output, media, range, order) ->
  folder = dir_name base_output
  folder = output_root base_output, media if folder == ""
  stem = output_stem base_output
  line_no = string.format "%03d", math.max(1, tonumber(order) or 1)
  join_path folder, "#{stem}_line#{line_no}#{range_suffix range}.waveform.json"

progress_title = (text) ->
  if aegisub and aegisub.progress and aegisub.progress.title
    pcall aegisub.progress.title, tostring(text or "")
  LineOps.checkCancelled!

progress_task = (text) ->
  LineOps.progress text

progress_set = (value) ->
  LineOps.progress nil, value

progress_cancelled = ->
  return false unless aegisub and aegisub.progress and aegisub.progress.is_cancelled
  ok, cancelled = pcall aegisub.progress.is_cancelled
  ok and cancelled == true

show_message = (text) ->
  if aegisub and aegisub.dialog and aegisub.dialog.display
    aegisub.dialog.display {
      {class: "textbox", value: tostring(text or ""), x: 0, y: 0, width: 60, height: 12}
    }, {"OK"}
  elseif aegisub and aegisub.log
    pcall aegisub.log, tostring(text or "") .. "\n"

run_ffmpeg = (cfg, pcm_path, log_path) ->
  stream = math.max 0, math.min MAX_STREAM_INDEX, math.floor(tonumber(cfg.stream) or 0)
  arguments = {
    "-hide_banner", "-nostdin", "-loglevel", "error", "-y", "-i", cfg.media
  }
  if cfg.range and (tonumber(cfg.range.duration_ms) or 0) > 0
    table.insert arguments, "-ss"
    table.insert arguments, ffmpeg_time cfg.range.start_ms
    table.insert arguments, "-t"
    table.insert arguments, ffmpeg_time cfg.range.duration_ms
  for value in *{
    "-map", "0:a:#{stream}", "-vn", "-ac", tostring(CHANNELS), "-ar", tostring(SAMPLE_RATE), "-f", "s16le", pcm_path
  }
    table.insert arguments, value
  command = PyBridge.commandLine cfg.ffmpeg, arguments
  ok, output = PyBridge.run command
  write_file log_path, output or ""
  ok, output

read_config = ->
  media = media_candidate!
  return nil, "No active audio file is loaded." if trim(media) == ""
  {
    media: media
    output: default_output_path media
    ffmpeg: "ffmpeg"
    stream: 0
    range: nil
  }

new_pyramid = (temp_prefix) ->
  pyramid = {
    levels: {}
    temp_prefix: temp_prefix
  }

  pyramid.ensure_level = (self, index) ->
    state = self.levels[index]
    unless state
      scale = 2 ^ (index - 1)
      path = "#{self.temp_prefix}_level_#{index}.tmp"
      file = io.open path, "wb"
      error "Could not create temporary level file: #{path}" unless file
      state = {
        index: index
        scale: scale
        point_ms: BASE_POINT_MS * scale
        samples_per_point: SAMPLES_PER_POINT * scale
        points: 0
        path: path
        file: file
        pending_count: 0
        pending_min: 0
        pending_max: 0
      }
      self.levels[index] = state
    state

  pyramid.emit_pair = (self, index, min_value, max_value) ->
    state = self\ensure_level index
    write_checked state.file, tostring(round_int(min_value)), ",", tostring(round_int(max_value)), "\n"
    state.points += 1
    if state.pending_count == 0
      state.pending_min = min_value
      state.pending_max = max_value
      state.pending_count = 1
    else
      cmin = math.min state.pending_min, min_value
      cmax = math.max state.pending_max, max_value
      state.pending_count = 0
      state.pending_min = 0
      state.pending_max = 0
      self\emit_pair index + 1, cmin, cmax

  pyramid.flush = (self) ->
    index = 1
    while index <= #self.levels
      state = self.levels[index]
      if state and state.pending_count == 1 and index < #self.levels
        min_value, max_value = state.pending_min, state.pending_max
        state.pending_count = 0
        state.pending_min = 0
        state.pending_max = 0
        self\emit_pair index + 1, min_value, max_value
      index += 1
    for state in *self.levels
      if state.file
        closed, message = state.file\close!
        error message or "Could not finish temporary waveform level." unless closed
      state.file = nil

  pyramid.cleanup = (self) ->
    for state in *(self.levels or {})
      pcall -> state.file\close! if state.file
      remove_file state.path

  pyramid

process_pcm = (pcm_path, temp_prefix, total_bytes = nil) ->
  input = io.open pcm_path, "rb"
  return nil, "Could not open decoded PCM." unless input

  pyramid = new_pyramid temp_prefix
  current_min, current_max = 32767, -32768
  samples_in_point = 0
  total_samples = 0
  bytes_read = 0
  leftover = ""

  ok, result, failure = pcall ->
    progress_task "Reading PCM and building waveform"
    while true
      return nil, "Cancelled." if progress_cancelled!
      data = input\read READ_BYTES
      break unless data and #data > 0
      if leftover != ""
        data = leftover .. data
        leftover = ""
      if (#data % BYTES_PER_SAMPLE) == 1
        leftover = data\sub #data
        data = data\sub 1, #data - 1
      bytes_read += #data
      if total_bytes and total_bytes > 0
        progress_set 20 + 70 * math.min(1, bytes_read / total_bytes)

      pos = 1
      limit = #data
      while pos < limit
        lo = data\byte(pos)
        hi = data\byte(pos + 1)
        sample = lo + hi * 256
        sample -= 65536 if sample >= 32768
        current_min = sample if sample < current_min
        current_max = sample if sample > current_max
        samples_in_point += 1
        total_samples += 1
        if samples_in_point >= SAMPLES_PER_POINT
          pyramid\emit_pair 1, current_min, current_max
          current_min, current_max = 32767, -32768
          samples_in_point = 0
        pos += 2

    error "Decoded PCM ended with an incomplete sample." if leftover != ""
    if samples_in_point > 0
      pyramid\emit_pair 1, current_min, current_max
    pyramid\flush!

    duration_ms = round_int(total_samples * 1000 / SAMPLE_RATE)
    { :pyramid, :duration_ms, :total_samples }, nil

  pcall -> input\close!
  unless ok
    pyramid\cleanup!
    return nil, tostring result
  unless result
    pyramid\cleanup!
    return nil, failure
  result, nil

copy_level_peaks = (out, level) ->
  file = io.open level.path, "rb"
  return false, "Could not read temporary level file." unless file
  first = true
  failure = nil
  while true
    line = file\read "*l"
    break unless line
    unless first
      written, failure = out\write ","
      break unless written
    first = false
    written, failure = out\write line
    break unless written
  file\close!
  return false, failure or "Could not write waveform peaks." if failure
  true, nil

write_json = (output_path, result) ->
  PyBridge.withAtomicFile output_path, (out) ->
    pyramid = result.pyramid
    write_checked out, "{\n"
    write_checked out, '  "type": "waveform",\n'
    write_checked out, '  "version": 1,\n'
    write_checked out, '  "sampleRate": ', tostring(SAMPLE_RATE), ",\n"
    write_checked out, '  "channels": ', tostring(CHANNELS), ",\n"
    write_checked out, '  "bits": ', tostring(BITS), ",\n"
    write_checked out, '  "amplitudeFormat": "s16",\n'
    write_checked out, '  "amplitudeMin": -32768,\n'
    write_checked out, '  "amplitudeMax": 32767,\n'
    write_checked out, '  "pointLayout": "interleavedMinMax",\n'
    if result.range
      write_checked out, '  "sourceStartMs": ', tostring(result.range.start_ms), ",\n"
      write_checked out, '  "sourceEndMs": ', tostring(result.range.end_ms), ",\n"
      write_checked out, '  "sourceDurationMs": ', tostring(result.range.duration_ms), ",\n"
      write_checked out, '  "sourceLineCount": ', tostring(result.range.line_count), ",\n"
    write_checked out, '  "durationMs": ', tostring(result.duration_ms), ",\n"
    write_checked out, '  "totalSamples": ', tostring(result.total_samples), ",\n"
    write_checked out, '  "levels": [\n'
    for i, level in ipairs pyramid.levels
      write_checked out, ",\n" if i > 1
      write_checked out, "    {\n"
      write_checked out, '      "scale": ', tostring(level.scale), ",\n"
      write_checked out, '      "pointMs": ', tostring(level.point_ms), ",\n"
      write_checked out, '      "samplesPerPoint": ', tostring(level.samples_per_point), ",\n"
      write_checked out, '      "points": ', tostring(level.points), ",\n"
      write_checked out, '      "peaks": ['
      copied, copy_error = copy_level_peaks out, level
      error copy_error unless copied
      write_checked out, "]\n"
      write_checked out, "    }"
    write_checked out, "\n  ]\n"
    write_checked out, "}\n"

file_size = (path) ->
  file = io.open path, "rb"
  return 0 unless file
  size = file\seek "end"
  file\close!
  tonumber(size) or 0

export_waveform = (cfg) ->
  return false, "Choose an audio or video file." if trim(cfg.media) == ""
  return false, "Media file does not exist:\n#{cfg.media}" unless file_exists cfg.media
  return false, "Choose a JSON output path." if trim(cfg.output) == ""
  root = output_root cfg.output, cfg.media
  return false, "Could not resolve an output folder." if trim(root) == ""
  cfg.output = join_path root, cfg.output if dir_name(cfg.output) == ""
  made, make_error = PyBridge.ensureDir root
  return false, "Could not create output folder: #{make_error or root}" unless made
  paths, path_error = PyBridge.tempPaths "wave2json", {pcm: ".s16le", log: ".ffmpeg.log", prefix: ""}
  return false, path_error or "Could not create temporary paths." unless paths
  pyramid = nil
  pcall_ok, success, message = pcall ->
    progress_title script_name
    progress_task "Decoding audio with FFmpeg"
    progress_set 5
    ok_ffmpeg = run_ffmpeg cfg, paths.pcm, paths.log
    unless ok_ffmpeg
      detail = PyBridge.readFile(paths.log, 65536) or ""
      return false, "FFmpeg could not decode the selected audio stream.\n#{detail}"
    size = file_size paths.pcm
    return false, "FFmpeg produced an empty PCM file." if size <= 0
    progress_set 20
    result, err = process_pcm paths.pcm, paths.prefix, size
    return false, err if err
    pyramid = result.pyramid
    result.range = cfg.range
    progress_task "Writing JSON"
    progress_set 95
    ok_json, json_err = write_json cfg.output, result
    return false, json_err unless ok_json
    progress_set 100
    range_text = if cfg.range then "\nRange: #{cfg.range.start_ms} ms - #{cfg.range.end_ms} ms" else ""
    true, "Waveform JSON written:\n#{cfg.output}#{range_text}\n\nDuration: #{result.duration_ms} ms\nLevels: #{#result.pyramid.levels}"
  PyBridge.cleanup paths
  pyramid\cleanup! if pyramid
  if pcall_ok then success, message else false, tostring success

export_line_ranges = (cfg, ranges) ->
  return false, "Select at least one subtitle line with valid timing." unless ranges and #ranges > 0
  first_output, last_output = nil, nil
  for i, range in ipairs ranges
    output = line_output_path cfg.output, cfg.media, range, i
    line_cfg = {
      media: cfg.media
      output: output
      ffmpeg: cfg.ffmpeg
      stream: cfg.stream
      range: range
    }
    ok, message = export_waveform line_cfg
    unless ok
      return false, "Line #{range.line_index or i} failed:\n#{message}"
    first_output = output unless first_output
    last_output = output
  folder = dir_name(first_output or cfg.output)
  true, "Waveform JSON files written: #{#ranges}\nFolder: #{folder}\nFirst: #{first_output}\nLast: #{last_output}"

read_base_config = ->
  cfg, message = read_config!
  unless cfg
    show_message message
    return nil
  cfg

main_full = (subs, sel) ->
  cfg = read_base_config!
  return unless cfg
  ok, message = export_waveform cfg
  show_message message

main_selection = (subs, sel) ->
  cfg = read_base_config!
  return unless cfg
  range, range_error = selection_range subs, sel
  unless range
    show_message range_error
    return
  cfg.range = range
  cfg.output = default_output_path cfg.media, range
  ok, message = export_waveform cfg
  show_message message

main_each = (subs, sel) ->
  cfg = read_base_config!
  return unless cfg
  ranges, range_error = selected_line_ranges subs, sel
  unless ranges
    show_message range_error
    return
  first = ranges[1]
  cfg.output = default_output_path cfg.media, first
  ok, message = export_line_ranges cfg, ranges
  show_message message

can_run_full = ->
  media = media_candidate!
  trim(media) != ""

can_run_selection = (subs, sel) ->
  ranges = selected_line_ranges subs, sel
  ranges != nil and can_run_full!

macros = {
  {"Full audio", "Export the complete active audio waveform to JSON.", main_full, can_run_full}
  {"Selected span", "Export one waveform covering the selected subtitle span.", main_selection, can_run_selection}
  {"Each selected line", "Export one waveform JSON per selected subtitle line.", main_each, can_run_selection}
}

if aegisub and aegisub.register_macro
  if depctrl and depctrl.registerMacros
    depctrl\registerMacros macros
  else
    for macro in *macros
      aegisub.register_macro "#{script_name}/#{macro[1]}", macro[2], macro[3], macro[4]
