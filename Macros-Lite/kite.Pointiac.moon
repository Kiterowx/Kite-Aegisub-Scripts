export script_name        = "Pointiac"
export script_description = "Create first and last frame point markers from selected lines"
export script_author      = "Kiterow"
export script_version     = "1.1.0"
export script_namespace   = "kite.Pointiac"

POINT_PATH = "m 0 4.657 b 0 2.085 2.085 0 4.657 0 7.229 0 9.314 2.085 9.314 4.657 9.314 7.229 7.229 9.314 4.657 9.314 2.085 9.314 0 7.229 0 4.657"
POINT_SIZE = 9.314
DEFAULTS = {
  color: "#FFFFFF"
  fps: 24
  separation: 16
  layer_offset: 1
  target_width: 1920
  target_height: 1080
}

ok_depctrl, DependencyControl = pcall require, "l0.DependencyControl"
depctrl = nil
if ok_depctrl and DependencyControl
  ok_record, record = pcall ->
    DependencyControl{
      name: script_name
      description: script_description
      author: script_author
      version: script_version
      namespace: script_namespace
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
      {
        {"kite.UI", version: "1.1.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
        {"kite.LineOps", version: "1.5.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
      }
    }
  depctrl = record if ok_record

KiteUI, LineOps = nil, nil
if depctrl
  ok_ui, ui, line_ops = pcall -> depctrl\requireModules!
  if ok_ui
    KiteUI = ui
    LineOps = line_ops
KiteUI or= require "kite.UI"
LineOps or= require "kite.LineOps"
POINT_SETTINGS = KiteUI.settings script_namespace, script_version, {
  main: {
    color: DEFAULTS.color
    fps: DEFAULTS.fps
    separation: DEFAULTS.separation
    layer_offset: DEFAULTS.layer_offset
  }
}, {}
POINT_SETTINGS\load!

copy_line = (line) ->
  out = {}
  return out unless type(line) == "table"
  out[k] = v for k, v in pairs line
  out

round_int = (value) ->
  value = tonumber(value) or 0
  if value >= 0
    math.floor(value + 0.5)
  else
    math.ceil(value - 0.5)

format_number = (value) ->
  n = tonumber(value) or 0
  n = 0 if math.abs(n) < 0.000001
  nearest = round_int n
  return tostring nearest if math.abs(n - nearest) < 0.000001
  out = string.format "%.3f", n
  out = out\gsub "0+$", ""
  out\gsub "%.$", ""

normalize_color = (value) ->
  text = if value == nil then "" else tostring value
  text = text\gsub "^%s+", ""
  text = text\gsub "%s+$", ""
  r, g, b = text\match "^#?(%x%x)(%x%x)(%x%x)$"
  return "&H#{b\upper!}#{g\upper!}#{r\upper!}&" if r
  hex = text\match "&[Hh](%x+)&?"
  if hex
    hex = hex\sub -6 if #hex > 6
    hex = string.rep("0", 6 - #hex) .. hex if #hex < 6
    return "&H#{hex\upper!}&"
  "&HFFFFFF&"

safe_fps = (value) ->
  fps = tonumber(value) or DEFAULTS.fps
  if fps > 0 then fps else DEFAULTS.fps

frame_ms = (fps) ->
  math.max 1, math.floor(1000 / safe_fps(fps) + 0.5)

safe_separation = (value) ->
  raw = tonumber(value) or DEFAULTS.separation
  sign = if raw < 0 then -1 else 1
  min_sep = POINT_SIZE + 1
  sign * math.max(math.abs(raw), min_sep)

get_script_resolution = (subs) ->
  res = {x: DEFAULTS.target_width, y: DEFAULTS.target_height}
  if subs
    for i = 1, #subs
      line = subs[i]
      if line and line.class == "info"
        key = tostring(line.key or "")\lower!
        if key == "playresx"
          res.x = tonumber(line.value) or res.x
        elseif key == "playresy"
          res.y = tonumber(line.value) or res.y
  res

default_position = (script_res) ->
  sep = DEFAULTS.separation
  {
    x: round_int((script_res.x - sep) / 2)
    y: round_int((script_res.y - POINT_SIZE) / 2)
  }

show_message = (message) ->
  aegisub.dialog.display {
    {class: "label", label: tostring(message or ""), x: 0, y: 0, width: 34, height: 2}
  }, {"OK"}

show_dialog = (script_res) ->
  saved = POINT_SETTINGS\values "main"
  pos = default_position script_res
  ui = {
    {class: "label", label: "Pointiac", x: 0, y: 0, width: 8, height: 1}
    {class: "label", label: "Color", x: 0, y: 1, width: 2, height: 1}
    {class: "color", name: "color", value: saved.color, x: 2, y: 1, width: 2, height: 2}
    {class: "label", label: "FPS", x: 5, y: 1, width: 1, height: 1}
    {class: "floatedit", name: "fps", value: saved.fps, min: 1, x: 6, y: 1, width: 2, height: 1}
    {class: "label", label: "X/Y", x: 0, y: 3, width: 2, height: 1}
    {class: "floatedit", name: "x", value: pos.x, x: 2, y: 3, width: 2, height: 1}
    {class: "floatedit", name: "y", value: pos.y, x: 4, y: 3, width: 2, height: 1}
    {class: "label", label: "Sep X", x: 0, y: 4, width: 2, height: 1}
    {class: "floatedit", name: "separation", value: saved.separation, min: POINT_SIZE + 1, x: 2, y: 4, width: 2, height: 1}
    {class: "label", label: "Capa+", x: 4, y: 4, width: 2, height: 1}
    {class: "intedit", name: "layer_offset", value: saved.layer_offset, min: -100, max: 100, x: 6, y: 4, width: 2, height: 1}
  }
  button, res = aegisub.dialog.display ui, {"Execute", "Cancel"}, {ok: "Execute", close: "Cancel"}
  return nil if button != "Execute"
  stable = {
    color: res.color
    fps: safe_fps res.fps
    separation: safe_separation res.separation
    layer_offset: tonumber(res.layer_offset) or DEFAULTS.layer_offset
  }
  POINT_SETTINGS\update "main", stable
  POINT_SETTINGS\write!
  {
    color: normalize_color res.color
    fps: stable.fps
    x: tonumber(res.x) or pos.x
    y: tonumber(res.y) or pos.y
    separation: stable.separation
    layer_offset: stable.layer_offset
  }

point_text = (x, y, color) ->
  string.format "{\\an7\\pos(%s,%s)\\bord0\\shad0\\1c%s\\p1}%s",
    format_number(x),
    format_number(y),
    color,
    POINT_PATH

timings = (base, fps) ->
  start_time = tonumber(base.start_time) or 0
  end_time = tonumber(base.end_time) or start_time
  frame_len = frame_ms fps
  end_time = start_time + frame_len if end_time <= start_time
  if aegisub and aegisub.frame_from_ms and aegisub.ms_from_frame
    start_frame = tonumber aegisub.frame_from_ms start_time
    last_frame = tonumber aegisub.frame_from_ms math.max(start_time, end_time - 1)
    if start_frame and last_frame
      first_end = math.min end_time, tonumber(aegisub.ms_from_frame(start_frame + 1)) or end_time
      last_start = math.max start_time, tonumber(aegisub.ms_from_frame(last_frame)) or start_time
      first_end = math.min end_time, start_time + 1 if first_end <= start_time
      last_start = start_time if last_start >= end_time
      return {
        first_start: start_time
        first_end: first_end
        last_start: last_start
        last_end: end_time
      }
  first_end = math.min end_time, start_time + frame_len
  first_end = start_time + 1 if first_end <= start_time
  last_start = math.max start_time, end_time - frame_len
  last_end = end_time
  if last_start >= last_end
    last_start = start_time
    last_end = first_end
  {
    first_start: start_time
    first_end: first_end
    last_start: last_start
    last_end: last_end
  }

point_lines = (base, opts) ->
  times = timings base, opts.fps
  base_layer = tonumber(base.layer) or 0
  layer = base_layer + opts.layer_offset
  first = copy_line base
  last = copy_line base

  first.comment = false
  first.layer = layer
  first.start_time = times.first_start
  first.end_time = times.first_end
  first.text = point_text opts.x, opts.y, opts.color

  last.comment = false
  last.layer = layer
  last.start_time = times.last_start
  last.end_time = times.last_end
  last.text = point_text opts.x + opts.separation, opts.y, opts.color

  first, last

selected_dialogue_indices = (subs, sel) ->
  LineOps.normalizeIndices subs, sel, (line) -> line and line.class == "dialogue"

main = (subs, sel, active) ->
  targets = selected_dialogue_indices subs, sel
  if #targets == 0
    show_message "Select at least one dialogue line."
    aegisub.cancel!

  opts = show_dialog get_script_resolution(subs)
  return nil unless opts
  operations = {}
  for idx in *targets
    first, last = point_lines subs[idx], opts
    operations[#operations + 1] = {index: idx + 1, lines: {first, last}}
  LineOps.transaction subs, script_name, -> LineOps.insertLines subs, operations

validate = (subs, sel) -> sel and #sel > 0
if aegisub and aegisub.register_macro
  if depctrl and depctrl.registerMacro
    depctrl\registerMacro script_name, script_description, main, validate, nil, false
  else
    aegisub.register_macro script_name, script_description, main, validate
