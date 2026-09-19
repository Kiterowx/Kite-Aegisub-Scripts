export script_name        = "AutoMask"
export script_description = "Detect, clean and reconstruct guided surfaces through the kite-automask backend."
export script_author      = "Kiterow"
export script_version     = "2.5.5"
export script_namespace   = "kite.AutoMask"

menuPath = script_name
moduleName = "kite_automask"
DEFAULT_INSTALL_SOURCE = "git+https://github.com/Kiterowx/kite-automask.git"
legacyConfig = "kite.automask.conf"
BACKEND_RESPONSE_VERSION = 1
snapshotConfigReadLimit = 16000
maxBackendResponseChars = 100000000
maxTimelineFrame = 2147483647
guideModes = {whole: true, inside: true}

haveDepctrl, DependencyControl = pcall require, "l0.DependencyControl"
depctrl = nil
if haveDepctrl and DependencyControl
  depctrl = DependencyControl{
    name: script_name
    description: script_description
    author: script_author
    version: script_version
    namespace: script_namespace
    feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
    {
      {
        "kite.UI"
        version: "1.5.0"
        url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts"
        feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
      }
      {
        "kite.PyBridge"
        version: "1.7.1"
        url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts"
        feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
      }
      {
        "kite.LineOps"
        version: "1.7.0"
        url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts"
        feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
      }
      {
        "kite.Media"
        version: "1.4.0"
        url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts"
        feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
      }
      {
        "kite.AssDrawing"
        version: "1.0.2"
        url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts"
        feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
      }
    }
  }

KiteUI = nil
PyBridge = nil
LineOps = nil
Media = nil
AssDrawing = nil
if depctrl and depctrl.requireModules
  ok, ui, bridge, lineOps, media, assDrawing = pcall -> depctrl\requireModules!
  if ok
    KiteUI = ui
    PyBridge = bridge
    LineOps = lineOps
    Media = media
    AssDrawing = assDrawing
KiteUI = KiteUI or require "kite.UI"
PyBridge = PyBridge or require "kite.PyBridge"
LineOps = LineOps or require "kite.LineOps"
Media = Media or require "kite.Media"
AssDrawing = AssDrawing or require "kite.AssDrawing"

haveJson, json = pcall require, "json"
unless haveJson and json and json.encode
  haveJson, json = pcall require, "l0.dkjson"

trim = LineOps.trim
joinPath = PyBridge.joinPath
fileExists = PyBridge.fileExists
readFile = PyBridge.readFile
writeFile = PyBridge.writeFile
shellQuote = PyBridge.quote
decodedPath = PyBridge.decodedPath
roundInt = LineOps.round
copyLine = LineOps.copy
commandProgram = PyBridge.program

finiteNumber = AssDrawing.finiteNumber
validShapePath = AssDrawing.validateAutoMaskPath
validDrawingLine = AssDrawing.validateAutoMaskLine

showError = KiteUI.message
showMessage = showError

logMessage = (message) ->
  if aegisub and aegisub.debug and aegisub.debug.out
    aegisub.debug.out "[AutoMask] #{message}\n"

progressTitle = (text) ->
  if aegisub and aegisub.progress and aegisub.progress.title
    pcall aegisub.progress.title, text

progressTask = (text) ->
  LineOps.progress text, nil

progressSet = (value) ->
  LineOps.progress nil, value

legacyConfigPath = ->
  user = decodedPath "?user"
  return "" if user == ""
  joinPath user, legacyConfig

SETTINGS = KiteUI.settings script_namespace, script_version, {
  package: {
    python: ""
    install_source: DEFAULT_INSTALL_SOURCE
  }
  main: {
    guide_mode: "whole"
  }
}, {
  {path: legacyConfigPath!, format: "key_value", target: "package"}
}, {"kite.Automask"}

readConfig = ->
  values = SETTINGS\values "package"
  values.python = PyBridge.resolvePython values.python
  values.install_source = DEFAULT_INSTALL_SOURCE if trim(values.install_source) == ""
  values

writeConfig = (values) ->
  SETTINGS\update "package", values
  SETTINGS\write!

configuredPython = ->
  readConfig!.python

pythonPathError = (python) ->
  value = trim python
  return nil unless value\find "[/\\]"
  return nil if fileExists value
  "The configured Python interpreter was not found.\nPath: #{value}\nOpen AutoMask/Backend/Configure and set Python to python or select an existing interpreter."

configuredFfmpeg = ->
  user = decodedPath "?user"
  if user != ""
    content = readFile joinPath(user, "kite-snapshoter.json"), snapshotConfigReadLimit
    if content
      if haveJson and json and json.decode
        ok, decoded = pcall json.decode, content
        if ok and type(decoded) == "table" and type(decoded.ffmpeg) == "string"
          return decoded.ffmpeg if trim(decoded.ffmpeg) != ""
  "ffmpeg"

ffmpegExecutable = (value) ->
  exe = trim value
  exe = "ffmpeg" if exe == ""
  lower = exe\lower!
  if PyBridge.isWindows and (lower == "ffmpeg" or lower == "ffmpeg.exe")
    for location in *{{"SystemRoot", "ffmpeg.exe"}, {"ProgramFiles", "ffmpeg/bin/ffmpeg.exe"}}
      base = os.getenv location[1]
      if base and base != ""
        candidate = joinPath base, location[2]
        return candidate if fileExists candidate
  exe

ffmpegTime = (ms) ->
  string.format "%.3f", math.max(0, finiteNumber(ms, 0)) / 1000

projectProperties = LineOps.projectProperties

videoPath = ->
  Media.projectPath "video"

currentVideoFrame = ->
  props = projectProperties!
  return nil if props.video_position == nil
  frame = tonumber props.video_position
  return nil unless frame and frame == frame and frame != math.huge and frame != -math.huge and frame >= 0 and frame <= maxTimelineFrame
  math.floor frame

frameCenterMs = (frame) ->
  frame = finiteNumber frame
  return nil unless frame and frame >= 0 and frame <= maxTimelineFrame
  frame = math.floor frame
  startMs = Media.msFromFrame frame
  return nil unless finiteNumber startMs
  nextMs = Media.msFromFrame frame + 1
  if finiteNumber(nextMs) and nextMs > startMs
    (startMs + nextMs) / 2
  else
    startMs

videoSize = ->
  return nil, nil unless aegisub and aegisub.video_size
  ok, width, height = pcall aegisub.video_size
  return nil, nil unless ok
  width, height = finiteNumber(width), finiteNumber(height)
  return nil, nil unless width and height and width > 0 and height > 0
  width, height = roundInt(width), roundInt(height)
  return nil, nil unless width and height and width >= 1 and height >= 1
  width, height

scriptResolution = (subs, fallbackX, fallbackY) ->
  x, y = LineOps.scriptResolution subs, fallbackX, fallbackY
  return nil, nil unless finiteNumber(x) and finiteNumber(y) and x > 0 and y > 0
  x, y = roundInt(x), roundInt(y)
  return nil, nil unless x and y and x >= 1 and y >= 1
  x, y

captureCommand = (video, ffmpeg, timeMs, outputPath, playX, playY) ->
  filter = "scale=#{playX}:#{playY}:flags=bicubic,format=rgb24"
  commandProgram(ffmpegExecutable(ffmpeg), "ffmpeg") ..
    " -hide_banner -nostdin -loglevel error -y -ss " .. ffmpegTime(timeMs) ..
    " -i " .. shellQuote(video) ..
    " -vf " .. shellQuote(filter) ..
    " -frames:v 1 " .. shellQuote(outputPath)

backendCommand = (python, requestPath, resultPath, noGui = false) ->
  arguments = {"--request", requestPath, "--output", resultPath}
  arguments[#arguments + 1] = "--no-gui" if noGui
  PyBridge.moduleCommand python, moduleName, arguments

runHidden = (command) ->
  PyBridge.run command

uniqueTempPaths = ->
  PyBridge.tempPaths "automask", {
    frame: "_frame.png"
    request: "_request.json"
    result: "_result.json"
  }

collectItems = (subs, sel) ->
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

encodeJson = (value) ->
  return nil, "The Aegisub JSON module is missing." unless haveJson and json and json.encode
  ok, encoded = pcall json.encode, value
  return nil, tostring(encoded) unless ok
  encoded

decodeJson = (value) ->
  return nil, "The Aegisub JSON module is missing." unless haveJson and json and json.decode
  ok, decoded = pcall json.decode, tostring(value or "")
  return nil, tostring(decoded) unless ok
  return nil, "The JSON response is not an object." unless type(decoded) == "table"
  decoded

validateResult = (items, result) ->
  return nil, "Unsupported backend response." unless type(result.version) == "number" and result.version == BACKEND_RESPONSE_VERSION
  return "cancelled" if result.status == "cancelled"
  return nil, "The backend did not return a valid result." unless result.status == "ok"
  mode = tostring(result.output_mode or "")
  return nil, "Unknown output mode: #{mode}" unless mode == "fill" or mode == "shape" or mode == "clip" or mode == "iclip"
  return nil, "The backend limits field is invalid." if result.limits != nil and type(result.limits) != "table"
  limits = result.limits or {}
  if limits.max_lines != nil
    maxLines = finiteNumber limits.max_lines
    return nil, "The backend returned an invalid line limit." unless maxLines and maxLines >= 1 and maxLines == math.floor(maxLines)
  return nil, "The backend regions field is invalid." unless type(result.regions) == "table"
  region_slots = 0
  for key in pairs result.regions
    return nil, "The backend returned a sparse region list." unless type(key) == "number" and key == math.floor(key) and key >= 1 and key <= #items
    region_slots += 1
  return nil, "The backend returned #{region_slots} region slots for #{#items} inputs." unless region_slots == #items
  groups = {}
  group_count = 0
  for regionIndex = 1, #items
    group = result.regions[regionIndex]
    return nil, "The backend returned a malformed region." unless type(group) == "table"
    order = tonumber group.order
    return nil, "Group without a valid order." unless order and order == math.floor(order) and order >= 1 and order <= #items
    return nil, "Duplicate result for region #{order}." if groups[order]
    return nil, "Region #{order} has invalid stats." if group.stats != nil and type(group.stats) != "table"
    groups[order] = group
    group_count += 1
  return nil, "The backend returned #{group_count} regions for #{#items} inputs." unless group_count == #items
  for item in *items
    group = groups[item.order]
    return nil, "Missing result for region #{item.order}." unless group
    if mode == "fill"
      return nil, "Region #{item.order} produced no drawings." unless type(group.lines) == "table" and #group.lines > 0
      for key in pairs group.lines
        return nil, "Region #{item.order} contains a sparse drawing list." unless type(key) == "number" and key == math.floor(key) and key >= 1 and key <= #group.lines
      for line_number = 1, #group.lines
        text = group.lines[line_number]
        return nil, "Region #{item.order} contains an invalid drawing at line #{line_number}." unless validDrawingLine text
    else
      return nil, "Region #{item.order} produced no valid contour." unless validShapePath group.path
  { :mode, :groups, :limits }

stripClips = LineOps.stripClips
injectFirstTag = LineOps.prependTag

shapeText = (path) ->
  "{\\an7\\pos(0,0)\\bord0\\shad0\\p1}#{path}{\\p0}"

replacementSelection = (items, groups) ->
  selection, delta = {}, 0
  for item in *items
    group = groups[item.order]
    startIndex = item.index + delta
    for offset = 0, #group.lines - 1
      selection[#selection + 1] = startIndex + offset
    delta += #group.lines - 1
  selection

applyFill = (subs, items, groups) ->
  selection = replacementSelection items, groups
  for position = #items, 1, -1
    LineOps.progress "Applying fill vectors", (#items - position + 1) / math.max(#items, 1) * 100
    item = items[position]
    group = groups[item.order]
    subs.delete item.index
    for lineIndex = #group.lines, 1, -1
      line = copyLine item.line
      line.text = group.lines[lineIndex]
      line.comment = false
      subs.insert item.index, line
  selection

applyShape = (subs, items, groups) ->
  selection, offset = {}, 0
  for item in *items
    selection[#selection + 1] = item.index + offset + 1
    offset += 1
  for position = #items, 1, -1
    LineOps.progress "Inserting contour shapes", (#items - position + 1) / math.max(#items, 1) * 100
    item = items[position]
    line = copyLine item.line
    line.layer = math.max(0, math.floor(finiteNumber(line.layer, 0))) + 1
    line.text = shapeText groups[item.order].path
    line.comment = false
    subs.insert item.index + 1, line
  selection

applyClip = (subs, items, groups, inverse) ->
  selection = {}
  for position, item in ipairs items
    LineOps.progress "Applying clips", position / math.max(#items, 1) * 100
    line = copyLine item.line
    tag = if inverse then "\\iclip(#{groups[item.order].path})" else "\\clip(#{groups[item.order].path})"
    line.text = injectFirstTag stripClips(line.text), tag
    subs[item.index] = line
    selection[#selection + 1] = item.index
  selection

applyResult = (subs, items, parsed) ->
  switch parsed.mode
    when "fill"
      applyFill subs, items, parsed.groups
    when "shape"
      applyShape subs, items, parsed.groups
    when "clip"
      applyClip subs, items, parsed.groups, false
    when "iclip"
      applyClip subs, items, parsed.groups, true

topLevelClipCounts = (text) ->
  clipCount, iclipCount = 0, 0
  for call in *LineOps.tagCalls(text, {clip: true, iclip: true})
    if call.top_level
      if call.name == "clip" then clipCount += 1 else iclipCount += 1
  clipCount, iclipCount

execute = (subs, sel, profile = "auto", editor = true, guideMode = nil) ->
  return false, "AutoMask requires the aka.command module." unless PyBridge.available
  return false, "AutoMask requires an Aegisub JSON module." unless haveJson

  guideMode = guideMode or (SETTINGS\values("main").guide_mode or "whole")
  return false, "Unknown guide mode: #{guideMode}" unless guideModes[guideMode]

  items, itemError = collectItems subs, sel
  return false, itemError unless items
  if profile == "autogrask-classic"
    for item in *items
      text = tostring(item.line.text or "")
      clipCount, iclipCount = topLevelClipCounts text
      return false, "Classic AutoGrask requires exactly one plain \\clip on line #{item.index}." unless clipCount == 1 and iclipCount == 0
  video = videoPath!
  return false, "Open a video before running AutoMask." unless video
  frame = currentVideoFrame!
  return false, "Could not read the current video frame." unless frame
  time_ms = frameCenterMs frame
  return false, "Could not convert the frame to a timestamp." unless time_ms
  videoX, videoY = videoSize!
  return false, "Could not read the video resolution." unless videoX and videoY
  play_x, play_y = scriptResolution subs, videoX, videoY
  python = configuredPython!
  missingPython = pythonPathError python
  return false, missingPython if missingPython

  tempPaths, temp_error = uniqueTempPaths!
  return false, "Could not resolve the temporary folder.\n#{temp_error or ''}" unless tempPaths
  completed, success, result = pcall ->
    frame_path = tempPaths.frame
    request_path = tempPaths.request
    result_path = tempPaths.result

    regions = {}
    for item in *items
      regions[#regions + 1] = {
        order: item.order
        source_index: item.index
        text: tostring(item.line.text or "")
      }
    request = {
      version: BACKEND_RESPONSE_VERSION
      frame_path: frame_path
      video_size: {videoX, videoY}
      playres: {play_x, play_y}
      profile: profile
      guide_mode: guideMode
      regions: regions
    }
    encoded, encode_error = encodeJson request
    unless encoded
      return false, "Could not encode the JSON request.\n#{encode_error or ''}"
    wrote, write_error = writeFile request_path, encoded
    unless wrote
      return false, "Could not write the JSON request.\nPath: #{request_path}\n#{write_error or ''}"

    progressTitle "AutoMask"
    progressTask if editor then "Capturing the frame and opening the editor" else "Capturing the frame and running #{profile}"
    progressSet 20
    backend, backend_error = backendCommand python, request_path, result_path, not editor
    unless backend
      return false, "Could not build the backend command.\n#{backend_error or ''}"
    command = PyBridge.chain captureCommand(video, configuredFfmpeg!, time_ms, frame_path, play_x, play_y), backend
    ok, detail = runHidden command
    unless ok and fileExists result_path
      stage = if fileExists frame_path then "The AutoMask backend failed." else "FFmpeg could not capture the frame."
      return false, "#{stage}\n\n#{detail}"

    resultContent, result_read_error = readFile result_path, maxBackendResponseChars + 1
    unless resultContent
      return false, "Could not read the backend response.\n#{result_read_error or ''}"
    if #resultContent > maxBackendResponseChars
      return false, "The backend response exceeds the size limit."
    decodedResult, decodeError = decodeJson resultContent
    unless decodedResult
      return false, decodeError
    parsed, validationError = validateResult items, decodedResult
    if parsed == "cancelled"
      return false, "cancelled"
    unless parsed
      return false, validationError

    progressTask "Applying ASS vectors"
    progressSet 90
    selection = nil
    applied, apply_error = pcall ->
      selection = LineOps.transaction subs, script_name, -> applyResult subs, items, parsed
    unless applied
      return false, "Could not apply the result. The subtitles were restored.\n#{apply_error}"
    progressSet 100

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
    logMessage "#{#items} regions -> #{total} lines (#{parsed.mode}); #{table.concat summaries, ', '}"
    true, selection
  PyBridge.cleanup tempPaths
  error success, 0 unless completed
  success, result

runProfile = (subs, sel, profile, editor, guideMode) ->
  ok, success, result = pcall execute, subs, sel, profile, editor, guideMode
  unless ok
    showError tostring(success)
    return sel, sel and sel[1]
  unless success
    return sel, sel and sel[1] if result == "cancelled"
    showError result
    return sel, sel and sel[1]
  result, result and result[1]

main = (subs, sel) ->
  runProfile subs, sel, "auto", true, nil

mainInside = (subs, sel) ->
  runProfile subs, sel, "auto", true, "inside"

mainClassic = (subs, sel) ->
  runProfile subs, sel, "autogrask-classic", false, "whole"

backendMaintenanceCommand = (arguments) ->
  values = {}
  if type(arguments) == "table"
    values = arguments
  else
    for value in tostring(arguments or "")\gmatch "%S+"
      values[#values + 1] = value
  PyBridge.moduleCommand configuredPython!, moduleName, values

packageDialog = (title) ->
  cfg = readConfig!
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

configureBackend = (subs, sel) ->
  values = packageDialog "AutoMask Backend"
  return sel unless values
  saved, save_error = writeConfig values
  if saved
    showMessage "Configuration saved."
  else
    showError "Could not save the configuration.\n#{save_error or ''}"
  sel

backendSummary = (status) ->
  lines = {
    "Package: kite-automask"
    "Installed: #{status.installed_version or 'unknown'}"
    "Source version: #{status.latest_version or 'unavailable'}"
    "Runtime: #{if status.ready then 'ready' else 'needs repair'}"
  }
  if status.update_available == true
    lines[#lines + 1] = "Update: available"
  elseif status.latest_version
    lines[#lines + 1] = "Update: not required"
  else
    lines[#lines + 1] = "Update check: #{status.update_error or 'unavailable'}"
  table.concat lines, "\n"

backendAction = (message, buttons) ->
  button = aegisub.dialog.display {
    {class: "textbox", value: tostring(message or ""), x: 0, y: 0, width: 70, height: 12}
  }, buttons, {ok: buttons[1], close: buttons[#buttons]}
  button

installBackend = nil

checkBackend = (subs, sel) ->
  cfg = readConfig!
  python = cfg.python
  missingPython = pythonPathError python
  if missingPython
    action = backendAction missingPython, {"Configure", "Close"}
    return configureBackend(subs, sel) if action == "Configure"
    return sel

  command, commandError = backendMaintenanceCommand {"--status", "--source", cfg.install_source}
  ok, detail = false, commandError
  ok, detail = runHidden command if command
  unless ok
    action = backendAction "The kite-automask package was not found or could not start.\n\n#{detail or ''}", {"Install", "Configure", "Close"}
    return installBackend(subs, sel) if action == "Install"
    return configureBackend(subs, sel) if action == "Configure"
    return sel

  status, status_error = decodeJson detail
  unless status
    showError "The backend returned an invalid status.\n\n#{status_error or detail or ''}"
    return sel
  unless type(status.ready) == "boolean"
    showError "The backend status is missing the required ready flag."
    return sel
  if status.update_available != nil and type(status.update_available) != "boolean"
    showError "The backend status contains an invalid update flag."
    return sel

  summary = backendSummary status
  if status.ready == false
    action = backendAction summary, {"Repair", "Configure", "Close"}
    return installBackend(subs, sel) if action == "Repair"
    return configureBackend(subs, sel) if action == "Configure"
  elseif status.update_available == true
    action = backendAction summary, {"Update", "Close"}
    return installBackend(subs, sel) if action == "Update"
  else
    showMessage summary
  sel

installBackend = (subs, sel) ->
  cfg = readConfig!
  missingPython = pythonPathError cfg.python
  if missingPython
    showError missingPython
    return sel
  installCommand, installError = PyBridge.installCommand cfg.python, cfg.install_source
  unless installCommand
    showError installError
    return sel
  checkCommand, checkError = backendMaintenanceCommand {"--status", "--source", cfg.install_source}
  unless checkCommand
    showError checkError
    return sel
  command = PyBridge.chain installCommand, checkCommand
  ok, detail = runHidden command
  if ok
    showMessage "The kite-automask backend was installed or updated.\n\n#{detail}"
  else
    showError "Could not install kite-automask.\n\n#{detail}"
  sel

installModelsMain = (subs, sel) ->
  cfg = readConfig!
  missingPython = pythonPathError cfg.python
  if missingPython
    showError missingPython
    return sel
  command, commandError = backendMaintenanceCommand {"--install-models"}
  unless command
    showError commandError
    return sel
  ok, detail = runHidden command
  if ok
    showMessage "The official models were installed and verified.\n\n#{detail}"
  else
    showError "Could not install the models.\n\n#{detail}"
  sel

validate = (subs, sel) ->
  return false unless sel and #sel > 0
  for index in *sel
    line = subs and subs[index]
    return false unless line and line.class == "dialogue" and not line.comment
  true

validateClip = (subs, sel) ->
  return false unless validate subs, sel
  for index in *sel
    text = tostring(subs[index].text or "")
    clipCount, iclipCount = topLevelClipCounts text
    return false if clipCount == 0 or iclipCount > 0
  true

alwaysAvailable = -> true

if aegisub and aegisub.register_macro
  entries = {
    {menuPath, script_description, main, validate}
    {"Find surface inside clip", "Detect the surface contained inside each clip instead of using the whole clip.", mainInside, validateClip}
    {"Classic AutoGrask", "Run the original clip-guided AutoGrask profile without the editor.", mainClassic, validateClip}
    {"Backend/Check", "Check installation, dependencies and available updates.", checkBackend, alwaysAvailable}
    {"Backend/Install or Update", "Install or update kite-automask from the configured repository.", installBackend, alwaysAvailable}
    {"Backend/Configure", "Set the Python interpreter and the install source.", configureBackend, alwaysAvailable}
    {"Backend/Install Models", "Download and verify the official EfficientSAM and LaMa models.", installModelsMain, alwaysAvailable}
  }
  if depctrl and depctrl.registerMacros
    depctrl\registerMacros entries
  else
    for entry in *entries
      aegisub.register_macro menuPath .. "/" .. entry[1], entry[2], entry[3], entry[4]

require("kite.UI").publishActions()
