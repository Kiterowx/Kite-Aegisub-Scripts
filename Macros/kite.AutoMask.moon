export script_name        = "AutoMask"
export script_description = "Detect, clean and reconstruct guided surfaces through the kite-automask backend."
export script_author      = "Kiterow"
export script_version     = "2.4.3"
export script_namespace   = "kite.AutoMask"

MENU_PATH = script_name
MODULE_NAME = "kite_automask"
DEFAULT_INSTALL_SOURCE = "git+https://github.com/Kiterowx/kite-automask.git"
LEGACY_CONFIG = "kite.automask.conf"
DEFAULT_MAX_LINES = 48

have_depctrl, DependencyControl = pcall require, "l0.DependencyControl"
depctrl = nil
if have_depctrl and DependencyControl
  depctrl = DependencyControl{
    name: script_name
    description: script_description
    author: script_author
    version: script_version
    namespace: script_namespace
    feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
    {
      {
        "aka.command"
        version: "1.0.2"
        url: "https://github.com/Akatmks/Akatsumekusa-Aegisub-Scripts"
        feed: "https://raw.githubusercontent.com/Akatmks/Akatsumekusa-Aegisub-Scripts/master/DependencyControl.json"
      }
      {
        "kite.UI"
        version: "1.1.1"
        url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts"
        feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
      }
      {
        "kite.PyBridge"
        version: "1.4.2"
        url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts"
        feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
      }
      {
        "kite.LineOps"
        version: "1.5.0"
        url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts"
        feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
      }
    }
  }

KiteUI = nil
PyBridge = nil
LineOps = nil
if depctrl and depctrl.requireModules
  ok, _command, ui, bridge, line_ops = pcall -> depctrl\requireModules!
  if ok
    KiteUI = ui
    PyBridge = bridge
    LineOps = line_ops
KiteUI = KiteUI or require "kite.UI"
PyBridge = PyBridge or require "kite.PyBridge"
LineOps = LineOps or require "kite.LineOps"

have_json, json = pcall require, "json"
unless have_json and json and json.encode
  have_json, json = pcall require, "l0.dkjson"

trim = LineOps.trim
join_path = PyBridge.joinPath
file_exists = PyBridge.fileExists
read_file = PyBridge.readFile
write_file = PyBridge.writeFile
shell_quote = PyBridge.quote
decoded_path = PyBridge.decodedPath
round_int = LineOps.round
copy_line = LineOps.copy
command_program = PyBridge.program

show_error = (message) ->
  if aegisub and aegisub.dialog and aegisub.dialog.display
    aegisub.dialog.display {
      {class: "textbox", value: tostring(message or ""), x: 0, y: 0, width: 70, height: 12}
    }, {"OK"}
  elseif aegisub and aegisub.debug and aegisub.debug.out
    aegisub.debug.out "[AutoMask] #{message}\n"

show_message = (message) ->
  if aegisub and aegisub.dialog and aegisub.dialog.display
    aegisub.dialog.display {
      {class: "textbox", value: tostring(message or ""), x: 0, y: 0, width: 70, height: 12}
    }, {"OK"}

log_message = (message) ->
  if aegisub and aegisub.debug and aegisub.debug.out
    aegisub.debug.out "[AutoMask] #{message}\n"

progress_title = (text) ->
  if aegisub and aegisub.progress and aegisub.progress.title
    pcall aegisub.progress.title, text

progress_task = (text) ->
  LineOps.progress text, nil

progress_set = (value) ->
  LineOps.progress nil, value

legacy_config_path = ->
  user = decoded_path "?user"
  return "" if user == ""
  join_path user, LEGACY_CONFIG

SETTINGS = KiteUI.settings script_namespace, script_version, {
  package: {
    python: ""
    install_source: DEFAULT_INSTALL_SOURCE
  }
  main: {
    guide_mode: "whole"
  }
}, {
  {path: legacy_config_path!, format: "key_value", target: "package"}
}, {"kite.Automask"}

read_config = ->
  values = SETTINGS\values "package"
  values.python = PyBridge.resolvePython values.python
  values.install_source = DEFAULT_INSTALL_SOURCE if trim(values.install_source) == ""
  values

write_config = (values) ->
  SETTINGS\update "package", values
  SETTINGS\write!

configured_python = ->
  read_config!.python

python_path_error = (python) ->
  value = trim python
  return nil unless value\find "[/\\]"
  return nil if file_exists value
  "The configured Python interpreter was not found.\nPath: #{value}\nOpen AutoMask/Backend/Configure and set Python to python or select an existing interpreter."

configured_ffmpeg = ->
  user = decoded_path "?user"
  if user != ""
    content = read_file join_path(user, "kite-snapshoter.json"), 16000
    if content
      escaped = content\match '"ffmpeg"%s*:%s*"(.-)"'
      if escaped
        value = escaped\gsub "\\\\", "\\"
        value = value\gsub '\\"', '"'
        return value if trim(value) != ""
  "ffmpeg"

ffmpeg_executable = (value) ->
  exe = trim value
  exe = "ffmpeg" if exe == ""
  lower = exe\lower!
  if PyBridge.isWindows and (lower == "ffmpeg" or lower == "ffmpeg.exe")
    for candidate in *{
      "C:\\Windows\\ffmpeg.exe"
      "C:\\Program Files\\ffmpeg\\bin\\ffmpeg.exe"
    }
      return candidate if file_exists candidate
  exe

ffmpeg_time = (ms) ->
  string.format "%.3f", math.max(0, tonumber(ms) or 0) / 1000

project_props = LineOps.projectProperties

video_path = ->
  path = decoded_path "?video"
  return path if path != "" and file_exists path
  props = project_props!
  path = trim props.video_file
  return path if path != "" and file_exists path
  nil

current_video_frame = ->
  props = project_props!
  return nil if props.video_position == nil
  tonumber props.video_position

frame_center_ms = (frame) ->
  return nil unless aegisub and aegisub.ms_from_frame
  start_ms = aegisub.ms_from_frame frame
  return nil unless start_ms
  next_ms = aegisub.ms_from_frame frame + 1
  if next_ms and next_ms > start_ms
    (start_ms + next_ms) / 2
  else
    start_ms

video_size = ->
  return nil, nil unless aegisub and aegisub.video_size
  ok, width, height = pcall aegisub.video_size
  return nil, nil unless ok
  width, height = tonumber(width), tonumber(height)
  return nil, nil unless width and height and width > 0 and height > 0
  round_int(width), round_int(height)

script_resolution = (subs, fallback_x, fallback_y) ->
  play_x, play_y = nil, nil
  for index = 1, #subs
    line = subs[index]
    if line and line.class == "info"
      key = tostring line.key or ""
      value = tonumber line.value
      play_x = value if key == "PlayResX" and value and value > 0
      play_y = value if key == "PlayResY" and value and value > 0
    break if play_x and play_y
  round_int(play_x or fallback_x), round_int(play_y or fallback_y)

capture_command = (video, ffmpeg, time_ms, output_path, play_x, play_y) ->
  filter = "scale=#{play_x}:#{play_y}:flags=bicubic,format=rgb24"
  command_program(ffmpeg_executable(ffmpeg), "ffmpeg") ..
    " -hide_banner -nostdin -loglevel error -y -ss " .. ffmpeg_time(time_ms) ..
    " -i " .. shell_quote(video) ..
    " -vf " .. shell_quote(filter) ..
    " -frames:v 1 " .. shell_quote(output_path)

backend_command = (python, request_path, result_path, no_gui = false) ->
  arguments = {"--request", request_path, "--output", result_path}
  arguments[#arguments + 1] = "--no-gui" if no_gui
  PyBridge.moduleCommand python, MODULE_NAME, arguments

run_hidden = (command) ->
  PyBridge.run command

unique_temp_paths = ->
  PyBridge.tempPaths "automask", {
    frame: "_frame.png"
    request: "_request.json"
    result: "_result.json"
  }

collect_items = (subs, sel) ->
  return nil, "Select at least one line." unless sel and #sel > 0
  records, rejected = LineOps.selectedLines subs, sel, ((line) -> line and line.class == "dialogue" and not line.comment), true
  if not records
    return nil, "Every selected row must be an uncommented dialogue line. Invalid rows: #{table.concat rejected, ', '}."
  items = {}
  for order, record in ipairs records
    items[#items + 1] = {
      :order
      index: record.index
      line: record.line
    }
  items

encode_json = (value) ->
  return nil, "The Aegisub JSON module is missing." unless have_json and json and json.encode
  ok, encoded = pcall json.encode, value
  return nil, tostring(encoded) unless ok
  encoded

decode_json = (value) ->
  return nil, "The Aegisub JSON module is missing." unless have_json and json and json.decode
  ok, decoded = pcall json.decode, tostring(value or "")
  return nil, tostring(decoded) unless ok
  return nil, "The JSON response is not an object." unless type(decoded) == "table"
  decoded

validate_result = (items, result) ->
  return nil, "Unsupported backend response." unless tonumber(result.version) == 1
  return "cancelled" if result.status == "cancelled"
  return nil, "The backend did not return a valid result." unless result.status == "ok"
  mode = tostring(result.output_mode or "")
  return nil, "Unknown output mode: #{mode}" unless mode == "fill" or mode == "shape" or mode == "clip" or mode == "iclip"
  limits = result.limits or {}
  max_lines = math.max 1, math.min DEFAULT_MAX_LINES, tonumber(limits.max_lines) or DEFAULT_MAX_LINES
  groups = {}
  for group in *(result.regions or {})
    order = tonumber group.order
    return nil, "Group without a valid order." unless order
    return nil, "Duplicate result for region #{order}." if groups[order]
    return nil, "Region #{order} has invalid stats." if group.stats != nil and type(group.stats) != "table"
    groups[order] = group
  for item in *items
    group = groups[item.order]
    return nil, "Missing result for region #{item.order}." unless group
    if mode == "fill"
      return nil, "Region #{item.order} produced no drawings." unless type(group.lines) == "table" and #group.lines > 0
      return nil, "Region #{item.order} exceeds #{max_lines} lines." if #group.lines > max_lines
      for text in *group.lines
        return nil, "Region #{item.order} contains an invalid drawing." unless type(text) == "string" and text != ""
    else
      return nil, "Region #{item.order} produced no contour." unless type(group.path) == "string" and group.path != ""
  { :mode, :groups, :limits }

strip_clips = LineOps.stripClips
inject_first_tag = LineOps.prependTag

shape_text = (path) ->
  "{\\an7\\pos(0,0)\\bord0\\shad0\\p1}#{path}{\\p0}"

replacement_selection = (items, groups) ->
  selection, delta = {}, 0
  for item in *items
    group = groups[item.order]
    start_index = item.index + delta
    for offset = 0, #group.lines - 1
      selection[#selection + 1] = start_index + offset
    delta += #group.lines - 1
  selection

apply_fill = (subs, items, groups) ->
  selection = replacement_selection items, groups
  for position = #items, 1, -1
    LineOps.progress "Applying fill vectors", (#items - position + 1) / math.max(#items, 1) * 100
    item = items[position]
    group = groups[item.order]
    subs.delete item.index
    for line_index = #group.lines, 1, -1
      line = copy_line item.line
      line.text = group.lines[line_index]
      line.comment = false
      subs.insert item.index, line
  selection

apply_shape = (subs, items, groups) ->
  selection, offset = {}, 0
  for item in *items
    selection[#selection + 1] = item.index + offset + 1
    offset += 1
  for position = #items, 1, -1
    LineOps.progress "Inserting contour shapes", (#items - position + 1) / math.max(#items, 1) * 100
    item = items[position]
    line = copy_line item.line
    line.layer = (tonumber(line.layer) or 0) + 1
    line.text = shape_text groups[item.order].path
    line.comment = false
    subs.insert item.index + 1, line
  selection

apply_clip = (subs, items, groups, inverse) ->
  selection = {}
  for position, item in ipairs items
    LineOps.progress "Applying clips", position / math.max(#items, 1) * 100
    line = copy_line item.line
    tag = if inverse then "\\iclip(#{groups[item.order].path})" else "\\clip(#{groups[item.order].path})"
    line.text = inject_first_tag strip_clips(line.text), tag
    subs[item.index] = line
    selection[#selection + 1] = item.index
  selection

apply_result = (subs, items, parsed) ->
  switch parsed.mode
    when "fill"
      apply_fill subs, items, parsed.groups
    when "shape"
      apply_shape subs, items, parsed.groups
    when "clip"
      apply_clip subs, items, parsed.groups, false
    when "iclip"
      apply_clip subs, items, parsed.groups, true

execute = (subs, sel, profile = "auto", editor = true, guide_mode = nil) ->
  return false, "AutoMask requires the aka.command module." unless PyBridge.available
  return false, "AutoMask requires an Aegisub JSON module." unless have_json

  guide_mode = guide_mode or (SETTINGS\values("main").guide_mode or "whole")

  items, item_error = collect_items subs, sel
  return false, item_error unless items
  if profile == "autogrask-classic"
    for item in *items
      text = tostring item.line.text or ""
      return false, "Classic AutoGrask requires a plain \\clip on line #{item.index}." unless text\find "\\clip%s*%("
  video = video_path!
  return false, "Open a video before running AutoMask." unless video
  frame = current_video_frame!
  return false, "Could not read the current video frame." unless frame
  time_ms = frame_center_ms frame
  return false, "Could not convert the frame to a timestamp." unless time_ms
  video_x, video_y = video_size!
  return false, "Could not read the video resolution." unless video_x and video_y
  play_x, play_y = script_resolution subs, video_x, video_y
  python = configured_python!
  missing_python = python_path_error python
  return false, missing_python if missing_python

  temp_paths, temp_error = unique_temp_paths!
  return false, "Could not resolve the temporary folder.\n#{temp_error or ''}" unless temp_paths
  frame_path = temp_paths.frame
  request_path = temp_paths.request
  result_path = temp_paths.result

  regions = {}
  for item in *items
    regions[#regions + 1] = {
      order: item.order
      source_index: item.index
      text: tostring(item.line.text or "")
    }
  request = {
    version: 1
    frame_path: frame_path
    video_size: {video_x, video_y}
    playres: {play_x, play_y}
    profile: profile
    guide_mode: guide_mode
    regions: regions
  }
  encoded, encode_error = encode_json request
  unless encoded
    PyBridge.cleanup temp_paths
    return false, "Could not encode the JSON request.\n#{encode_error or ''}"
  wrote, write_error = write_file request_path, encoded
  unless wrote
    PyBridge.cleanup temp_paths
    return false, "Could not write the JSON request.\nPath: #{request_path}\n#{write_error or ''}"

  progress_title "AutoMask"
  progress_task if editor then "Capturing the frame and opening the editor" else "Capturing the frame and running #{profile}"
  progress_set 20
  command = PyBridge.chain(
    capture_command(video, configured_ffmpeg!, time_ms, frame_path, play_x, play_y)
    backend_command python, request_path, result_path, not editor
  )
  ok, detail = run_hidden command
  unless ok and file_exists result_path
    stage = if file_exists frame_path then "The AutoMask backend failed." else "FFmpeg could not capture the frame."
    PyBridge.cleanup temp_paths
    return false, "#{stage}\n\n#{detail}"

  result, decode_error = decode_json read_file(result_path)
  unless result
    PyBridge.cleanup temp_paths
    return false, decode_error
  parsed, validation_error = validate_result items, result
  if parsed == "cancelled"
    PyBridge.cleanup temp_paths
    return false, "cancelled"
  unless parsed
    PyBridge.cleanup temp_paths
    return false, validation_error

  progress_task "Applying ASS vectors"
  progress_set 90
  selection = nil
  applied, apply_error = pcall ->
    selection = LineOps.transaction subs, script_name, -> apply_result subs, items, parsed
  unless applied
    PyBridge.cleanup temp_paths
    return false, "Could not apply the result. The subtitles were restored.\n#{apply_error}"
  PyBridge.cleanup temp_paths
  progress_set 100

  total = 0
  summaries = {}
  if parsed.mode == "fill"
    for item in *items
      group = parsed.groups[item.order]
      total += #group.lines
      stats = if type(group.stats) == "table" then group.stats else {}
      summaries[#summaries + 1] = "#{item.order}=#{stats.engine or 'fill'}/#{#group.lines}"
  else
    total = #items
  log_message "#{#items} regions -> #{total} lines (#{parsed.mode}); #{table.concat summaries, ', '}"
  true, selection

run_profile = (subs, sel, profile, editor, guide_mode) ->
  ok, success, result = pcall execute, subs, sel, profile, editor, guide_mode
  unless ok
    show_error tostring success
    return sel
  unless success
    return sel if result == "cancelled"
    show_error result
    return sel
  result

main = (subs, sel) ->
  run_profile subs, sel, "auto", true, nil

main_inside = (subs, sel) ->
  run_profile subs, sel, "auto", true, "inside"

main_classic = (subs, sel) ->
  run_profile subs, sel, "autogrask-classic", false, "whole"

backend_maintenance_command = (arguments) ->
  values = {}
  if type(arguments) == "table"
    values = arguments
  else
    for value in tostring(arguments or "")\gmatch "%S+"
      values[#values + 1] = value
  PyBridge.moduleCommand configured_python!, MODULE_NAME, values

package_dialog = (title) ->
  cfg = read_config!
  interface = {
    {class: "label", label: title, x: 0, y: 0, width: 8, height: 1}
    {class: "label", label: "Python", x: 0, y: 1, width: 2, height: 1}
    {class: "edit", name: "python", value: cfg.python, x: 2, y: 1, width: 14, height: 1}
    {class: "label", label: "Install source", x: 0, y: 2, width: 3, height: 1}
    {class: "edit", name: "install_source", value: cfg.install_source, x: 3, y: 2, width: 13, height: 1}
  }
  button, result = aegisub.dialog.display interface, {"Save", "Cancel"}, {ok: "Save", close: "Cancel"}
  return nil if button != "Save"
  {
    python: trim result.python
    install_source: if trim(result.install_source) == "" then DEFAULT_INSTALL_SOURCE else trim result.install_source
  }

configure_backend = (subs, sel) ->
  values = package_dialog "AutoMask Backend"
  return sel unless values
  write_config values
  show_message "Configuration saved."
  sel

backend_summary = (status) ->
  lines = {
    "Package: kite-automask"
    "Installed: #{status.installed_version or 'unknown'}"
    "Source version: #{status.latest_version or 'unavailable'}"
    "Runtime: #{if status.ready == false then 'needs repair' else 'ready'}"
  }
  if status.update_available == true
    lines[#lines + 1] = "Update: available"
  elseif status.latest_version
    lines[#lines + 1] = "Update: not required"
  else
    lines[#lines + 1] = "Update check: #{status.update_error or 'unavailable'}"
  table.concat lines, "\n"

backend_action = (message, buttons) ->
  button = aegisub.dialog.display {
    {class: "textbox", value: tostring(message or ""), x: 0, y: 0, width: 70, height: 12}
  }, buttons, {ok: buttons[1], close: buttons[#buttons]}
  button

install_backend = nil

check_backend = (subs, sel) ->
  cfg = read_config!
  python = cfg.python
  missing_python = python_path_error python
  if missing_python
    action = backend_action missing_python, {"Configure", "Close"}
    return configure_backend(subs, sel) if action == "Configure"
    return sel

  command, command_error = backend_maintenance_command {"--status", "--source", cfg.install_source}
  ok, detail = false, command_error
  ok, detail = run_hidden command if command
  unless ok
    action = backend_action "The kite-automask package was not found or could not start.\n\n#{detail or ''}", {"Install", "Configure", "Close"}
    return install_backend(subs, sel) if action == "Install"
    return configure_backend(subs, sel) if action == "Configure"
    return sel

  status, status_error = decode_json detail
  unless status
    show_error "The backend returned an invalid status.\n\n#{status_error or detail or ''}"
    return sel

  summary = backend_summary status
  if status.ready == false
    action = backend_action summary, {"Repair", "Configure", "Close"}
    return install_backend(subs, sel) if action == "Repair"
    return configure_backend(subs, sel) if action == "Configure"
  elseif status.update_available == true
    action = backend_action summary, {"Update", "Close"}
    return install_backend(subs, sel) if action == "Update"
  else
    show_message summary
  sel

install_backend = (subs, sel) ->
  cfg = read_config!
  missing_python = python_path_error cfg.python
  if missing_python
    show_error missing_python
    return sel
  install_command, install_error = PyBridge.installCommand cfg.python, cfg.install_source
  unless install_command
    show_error install_error
    return sel
  command = PyBridge.chain(
    install_command
    backend_maintenance_command {"--status", "--source", cfg.install_source}
  )
  ok, detail = run_hidden command
  if ok
    show_message "The kite-automask backend was installed or updated.\n\n#{detail}"
  else
    show_error "Could not install kite-automask.\n\n#{detail}"
  sel

install_models_main = (subs, sel) ->
  cfg = read_config!
  missing_python = python_path_error cfg.python
  if missing_python
    show_error missing_python
    return sel
  ok, detail = run_hidden backend_maintenance_command "--install-models"
  if ok
    show_message "The official models were installed and verified.\n\n#{detail}"
  else
    show_error "Could not install the models.\n\n#{detail}"
  sel

validate = (subs, sel) ->
  return false unless sel and #sel > 0
  for index in *sel
    line = subs and subs[index]
    return false unless line and line.class == "dialogue" and not line.comment
  true

validate_clip = (subs, sel) ->
  return false unless validate subs, sel
  for index in *sel
    text = tostring subs[index].text or ""
    return false if #LineOps.tagCalls(text, "clip") == 0 or #LineOps.tagCalls(text, "iclip") > 0
  true

always_available = -> true

if aegisub and aegisub.register_macro
  entries = {
    {MENU_PATH, script_description, main, validate}
    {"Find surface inside clip", "Detect the surface contained inside each clip instead of using the whole clip.", main_inside, validate_clip}
    {"Classic AutoGrask", "Run the original clip-guided AutoGrask profile without the editor.", main_classic, validate_clip}
    {"Backend/Check", "Check installation, dependencies and available updates.", check_backend, always_available}
    {"Backend/Install or Update", "Install or update kite-automask from the configured repository.", install_backend, always_available}
    {"Backend/Configure", "Set the Python interpreter and the install source.", configure_backend, always_available}
    {"Backend/Install Models", "Download and verify the official EfficientSAM and LaMa models.", install_models_main, always_available}
  }
  if depctrl and depctrl.registerMacros
    depctrl\registerMacros entries
  else
    for entry in *entries
      aegisub.register_macro MENU_PATH .. "/" .. entry[1], entry[2], entry[3], entry[4]
