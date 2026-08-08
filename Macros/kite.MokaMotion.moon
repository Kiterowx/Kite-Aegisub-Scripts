export script_name = "Moka Motion"
export script_description = "Unified Mocha motion, shape, clip, perspective and FBF track tools"
export script_author = "Kiterow"
export script_version = "3.4.2"
export script_namespace = "kite.MokaMotion"

local depctrl, LineCollection, ASS, AMath, APersp, ArchUtil, Tags, ZF, KiteUI, PyBridge, Media, LineOps, clipboard
local Point, Matrix, Quad, an_xshift, an_yshift, relevantTags, usedTags
local transformPoints, tagsFromQuad, prepareForPerspective
local shift_frame_karaoke

DependencyControl = require "l0.DependencyControl"
depctrl = DependencyControl{
  feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
  {
    {"a-mo.LineCollection", version: "1.3.0", url: "https://github.com/TypesettingTools/Aegisub-Motion",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"}
    {"a-mo.Tags", version: "1.3.4", url: "https://github.com/TypesettingTools/Aegisub-Motion",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"}
    {"l0.ASSFoundation", version: "0.5.0", url: "https://github.com/TypesettingTools/ASSFoundation",
      feed: "https://raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json"}
    {"arch.Math", version: "0.1.10", url: "https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json"}
    {"arch.Perspective", version: "1.2.1", url: "https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json"}
    {"arch.Util", version: "0.1.0", url: "https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json"}
    {"ZF.main", version: "2.3.0", url: "https://github.com/TypesettingTools/zeref-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/TypesettingTools/zeref-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.UI", version: "1.1.3", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.PyBridge", version: "1.4.4", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.Media", version: "1.2.2", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.LineOps", version: "1.5.2", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    "aegisub.clipboard"
  }
}
LineCollection, Tags, ASS, AMath, APersp, ArchUtil, ZF, KiteUI, PyBridge, Media, LineOps, clipboard = depctrl\requireModules!
{:Point, :Matrix} = AMath
{:Quad, :an_xshift, :an_yshift, :relevantTags, :usedTags, :transformPoints, :tagsFromQuad, :prepareForPerspective} = APersp

Core = {}
Core.api_version = 1

NUMERIC_EPSILON = 0.0000001
GEOMETRY_EPSILON = 0.000001
SCALE_EPSILON = 0.000000001
SINGULAR_EPSILON = 0.000000000001

DEFAULTS = {
  sample_start: 1
  reference_frame: 1
  strict_sync: false
  optimize_linear: true
  linear_tolerance: 0.20
  x_position: true
  y_position: true
  scale: true
  rotation: true
  origin: true
  track_clip: true
  border: true
  shadow: true
  blur: true
  blur_scale: 1
  absolute: false
  rect_to_vector: true
  rect_clip: true
  vector_clip: true
  output_mode: "clip"
  placement: "Replace selection"
  use_source_meta: true
  scale_to_script: true
  source_width: 1920
  source_height: 1080
  target_width: 1920
  target_height: 1080
  fps: 24
  offset_x: 0
  offset_y: 0
  decimals: 2
  tangent_epsilon: 0.25
  layer_offset: 1
  shape_tags: "\\bord0\\shad0"
  org_mode: "Force stable center"
  apply_perspective: true
  inverse: false
  mapping_mode: "Selection timeline"
  phase_mode: "Detect only"
  cleanup_mode: "Off"
  cleanup_window: 9
  cleanup_degree: 2
  cleanup_strength: 100
  strict_geometry: false
  refine_action: "Analyze"
  refine_method: "Local regression"
  refine_scope: "Outliers only"
  refine_threshold: 0.35
  protect_authored: true
  refine_frames: 4
  target_x: 0
  target_y: 0
}

NUM_PATTERN = "[%+%-]?%d*%.?%d+[eE]?[%+%-]?%d*"

trim = (value) ->
  text = if value == nil then "" else tostring value
  text = text\gsub "^%s+", ""
  text\gsub "%s+$", ""

finite = (value) ->
  value = tonumber value
  value != nil and value == value and value != math.huge and value != -math.huge

clamp = (value, low, high) ->
  value = tonumber(value) or low
  math.max low, math.min high, value

format_number = (value, decimals = 2) ->
  value = tonumber(value) or 0
  value = 0 if math.abs(value) < NUMERIC_EPSILON
  value = LineOps.roundTo value, decimals
  if math.abs(value - math.floor(value + 0.5)) < NUMERIC_EPSILON
    return tostring math.floor(value + 0.5)
  out = string.format "%.#{decimals}f", value
  out = out\gsub "0+$", ""
  out\gsub "%.$", ""

copy_table = (source) ->
  out = {}
  out[k] = v for k, v in pairs source or {}
  out

copy_line = (line) ->
  out = copy_table line
  out.extra = copy_table(line.extra) if type(line.extra) == "table"
  out

accept_dialogue_line = (line) -> not line.comment
accept_all_lines = -> true

parse_numbers = (text) ->
  out = {}
  for value in tostring(text or "")\gmatch NUM_PATTERN
    number = tonumber value
    out[#out + 1] = number if number
  out

split_lines = (text) ->
  out = {}
  text = tostring(text or "")\gsub "^\239\187\191", ""
  text = text\gsub "\r\n", "\n"
  text = text\gsub "\r", "\n"
  for line in (text .. "\n")\gmatch "([^\n]*)\n"
    out[#out + 1] = line
  out

parse_meta = (input) ->
  text = tostring(input or "")
  {
    fps: tonumber(text\match "Units Per Second%s+([%d%.]+)")
    source_width: tonumber(text\match "Source Width%s+([%d%.]+)")
    source_height: tonumber(text\match "Source Height%s+([%d%.]+)")
    source_par: tonumber(text\match "Source Pixel Aspect Ratio%s+([%d%.]+)")
    comp_par: tonumber(text\match "Comp Pixel Aspect Ratio%s+([%d%.]+)")
  }

SECTION_NAMES = {
  ["position"]: "position"
  ["scale"]: "scale"
  ["rotation"]: "rotation"
  ["anchor point"]: "anchor"
  ["opacity"]: "opacity"
}

pin_key = (line) ->
  line = line\gsub "^Effects%s+ADBE%s+", "Effects "
  line = line\gsub "(#1)%s+ADBE%s+", "%1 "
  marker = line\match "^Effects%s+CC Power Pin #1%s+CC Power Pin%-([%d]+)%s*$"
  return "pin_#{marker}" if marker
  marker = line\match "^Effects%s+Corner Pin #1%s+Corner Pin%-([%d]+)%s*$"
  marker and "corner_#{marker}" or nil

add_row = (section, frame, values, line_number) ->
  return nil, "Non-finite or non-integer frame on line #{line_number}: #{frame}" unless finite(frame) and frame == math.floor frame
  if section.by_frame[frame]
    return nil, "Duplicate frame #{frame} in #{section.name} (line #{line_number})."
  row = {frame: frame, values: values, line_number: line_number}
  section.by_frame[frame] = row
  section.rows[#section.rows + 1] = row
  true

parse_keyframe_sections = (input) ->
  sections = {}
  diagnostics = {}
  unknown = {}
  note_unknown = (label) ->
    return if unknown[label]
    unknown[label] = true
    diagnostics[#diagnostics + 1] = "Unrecognized AE channel/section: #{label}."
  current = nil
  for line_number, raw in ipairs split_lines input
    stripped = trim raw
    lower = stripped\lower!
    name = SECTION_NAMES[lower] or pin_key stripped
    if name
      sections[name] or= {name: name, rows: {}, by_frame: {}}
      current = sections[name]
      continue
    if current and raw\match "^%s+"
      values = parse_numbers stripped
      if #values >= 2
        frame = values[1]
        row_values = [values[i] for i = 2, #values]
        ok, err = add_row current, frame, row_values, line_number
        return nil, err unless ok
      continue
    if stripped != "" and not raw\match("^%s+")
      allowed_header = lower == "end of keyframe data" or lower\match("^adobe after effects") or lower\match("^units per second") or lower\match("^source width") or lower\match("^source height") or lower\match("^source pixel aspect ratio") or lower\match("^comp pixel aspect ratio")
      if not allowed_header and (stripped\match("^Effects%s+") or stripped\match("^[%a][%a%s]+$"))
        note_unknown stripped
    current = nil if stripped != ""
  for _, section in pairs sections
    table.sort section.rows, (a, b) -> a.frame < b.frame
  sections, nil, diagnostics

require_section_arity = (section, count, label) ->
  return true unless section
  for row in *section.rows
    return nil, "#{label}, frame #{row.frame}: expected #{count} values, received #{#row.values}." if #row.values < count
    for i = 1, count
      return nil, "#{label}, frame #{row.frame}: value #{i} is not finite." unless finite row.values[i]
  true

all_frames = (sections, names) ->
  seen, out = {}, {}
  for name in *names
    section = sections[name]
    if section
      for row in *section.rows
        unless seen[row.frame]
          seen[row.frame] = true
          out[#out + 1] = row.frame
  table.sort out
  out

interpolated_values = (section, frame, defaults) ->
  return copy_table defaults, false unless section and #section.rows > 0
  exact = section.by_frame[frame]
  return exact.values, false if exact
  before, after = nil, nil
  for row in *section.rows
    if row.frame < frame
      before = row
    elseif row.frame > frame
      after = row
      break
  return (before or after).values, true unless before and after
  k = (frame - before.frame) / (after.frame - before.frame)
  count = math.max #before.values, #after.values, #defaults
  values = {}
  for i = 1, count
    a = before.values[i] or defaults[i] or 0
    b = after.values[i] or defaults[i] or a
    values[i] = a + (b - a) * k
  values, true

unwrap_angles = (values) ->
  out = {}
  return out if #values == 0
  out[1] = values[1]
  for i = 2, #values
    value = values[i]
    previous = out[i - 1]
    while value - previous > 180
      value -= 360
    while value - previous < -180
      value += 360
    out[i] = value
  out

unwrap_rotation_section = (section) ->
  return nil unless section
  out = {name: section.name, rows: {}, by_frame: {}}
  diagnostics = {}
  cumulative = false
  for row in *section.rows
    value = row.values[1] or 0
    if value < -180 or value > 360
      cumulative = true
      break
  offset, previous_raw = 0, nil
  for i, row in ipairs section.rows
    raw_angle = row.values[1] or 0
    angle = raw_angle
    if not cumulative and previous_raw != nil
      delta = raw_angle - previous_raw
      turns = math.floor(math.abs(delta) / 360 + 0.5)
      explicit_turn = turns >= 1 and math.abs(math.abs(delta) - turns * 360) <= GEOMETRY_EPSILON
      if previous_raw >= 135 and raw_angle <= -135
        offset += 360
      elseif previous_raw <= -135 and raw_angle >= 135
        offset -= 360
      elseif previous_raw >= 315 and raw_angle <= 45
        offset += 360
      elseif not explicit_turn and math.abs(delta) > 180
        diagnostics[#diagnostics + 1] = "Rotation #{row.frame}: ambiguous #{format_number(delta, 3)} degree jump preserved without shortest-path wrapping."
        out.ambiguous or= {}
        out.ambiguous[row.frame] = delta
      angle = raw_angle + offset
    values = [value for value in *row.values]
    values[1] = angle
    copy = {frame: row.frame, :values, line_number: row.line_number}
    out.rows[i] = copy
    out.by_frame[copy.frame] = copy
    previous_raw = raw_angle
  diagnostics[#diagnostics + 1] = "Cumulative rotation detected; complete revolutions are preserved." if cumulative
  out, diagnostics

parse_transform_data = (input) ->
  sections, err, parse_diagnostics = parse_keyframe_sections input
  return nil, err unless sections
  return nil, "No Position, Scale, or Rotation section was found." unless sections.position or sections.scale or sections.rotation
  for check in *{
    {sections.position, 2, "Position"}
    {sections.scale, 1, "Scale"}
    {sections.rotation, 1, "Rotation"}
    {sections.anchor, 2, "Anchor Point"}
    {sections.opacity, 1, "Opacity"}
  }
    ok, err = require_section_arity check[1], check[2], check[3]
    return nil, err unless ok
  uniform_scale_rows = 0
  if sections.scale
    for row in *sections.scale.rows
      if row.values[2] == nil
        row.values[2] = row.values[1]
        uniform_scale_rows += 1
  meta = parse_meta input
  frames = all_frames sections, {"position", "scale", "rotation", "anchor", "opacity"}
  return nil, "The tracking sections contain no numeric samples." if #frames == 0
  first_frame, last_frame = frames[1], frames[#frames]
  diagnostics, samples, had_gap = {}, {}, false
  diagnostics[#diagnostics + 1] = item for item in *parse_diagnostics or {}
  diagnostics[#diagnostics + 1] = "#{uniform_scale_rows} uniform Scale rows were expanded to X/Y." if uniform_scale_rows > 0
  rotation_section, rotation_diagnostics = unwrap_rotation_section sections.rotation
  diagnostics[#diagnostics + 1] = item for item in *rotation_diagnostics or {}
  default_x = (meta.source_width or 0) / 2
  default_y = (meta.source_height or 0) / 2
  diagnostics[#diagnostics + 1] = "Position is missing; the source center is used as the pivot." unless sections.position
  for frame = first_frame, last_frame
    position, pos_gap = interpolated_values sections.position, frame, {default_x, default_y, 0}
    scale, scale_gap = interpolated_values sections.scale, frame, {100, 100, 100}
    rotation, rot_gap = interpolated_values rotation_section, frame, {0}
    anchor, anchor_gap = interpolated_values sections.anchor, frame, {0, 0, 0}
    opacity, opacity_gap = interpolated_values sections.opacity, frame, {100}
    gaps = {}
    gaps[#gaps + 1] = "Position" if sections.position and pos_gap
    gaps[#gaps + 1] = "Scale" if sections.scale and scale_gap
    gaps[#gaps + 1] = "Rotation" if sections.rotation and rot_gap
    gaps[#gaps + 1] = "Anchor Point" if sections.anchor and anchor_gap
    gaps[#gaps + 1] = "Opacity" if sections.opacity and opacity_gap
    diagnostics[#diagnostics + 1] = "Frame #{frame} was interpolated in #{table.concat gaps, ', '}." if #gaps > 0
    had_gap = true if #gaps > 0
    samples[#samples + 1] = {
      source_frame: frame
      position: {x: position[1] or 0, y: position[2] or 0}
      scale: {x: scale[1] or 100, y: scale[2] or scale[1] or 100}
      rotation: -(rotation[1] or 0)
      ambiguous_rotation: rotation_section and rotation_section.ambiguous and rotation_section.ambiguous[frame] or nil
      anchor: {x: anchor[1] or 0, y: anchor[2] or 0}
      opacity: opacity[1] or 100
      interpolated: #gaps > 0
    }
  ambiguous_rotation = rotation_section and rotation_section.ambiguous and next(rotation_section.ambiguous) != nil
  diagnostics[#diagnostics + 1] = "Ambiguous Rotation jumps were detected; strict synchronization can reject them to avoid unintended revolutions." if ambiguous_rotation
  diagnostics[#diagnostics + 1] = "Anchor Point was detected; it is retained for diagnostics and is not applied twice." if sections.anchor
  diagnostics[#diagnostics + 1] = "Opacity was detected; it does not change ASS geometry." if sections.opacity
  {
    kind: "transform"
    format: "Adobe After Effects Transform Data"
    :meta
    :samples
    :diagnostics
    first_frame: first_frame
    last_frame: last_frame
    has_interpolation: had_gap
    has_ambiguous_rotation: ambiguous_rotation
    channels: {
      position: sections.position != nil
      scale: sections.scale != nil
      rotation: sections.rotation != nil
      anchor: sections.anchor != nil
      opacity: sections.opacity != nil
    }
  }

parse_powerpin_data = (input) ->
  sections, err, parse_diagnostics = parse_keyframe_sections input
  return nil, err unless sections
  local order, format
  if sections.pin_0002
    order = {"pin_0002", "pin_0003", "pin_0005", "pin_0004"}
    format = "After Effects CC Power Pin"
  else
    order = {"corner_0001", "corner_0002", "corner_0004", "corner_0003"}
    format = "After Effects Corner Pin"
  return nil, "Incomplete Power Pin data: #{name} is missing." for name in *order when not sections[name]
  for name in *order
    ok, err = require_section_arity sections[name], 2, name
    return nil, err unless ok
  frames = all_frames sections, order
  return nil, "Power Pin data contains no numeric samples." if #frames == 0
  first_frame, last_frame = frames[1], frames[#frames]
  samples, diagnostics = {}, {}
  diagnostics[#diagnostics + 1] = item for item in *parse_diagnostics or {}
  used = {name, true for name in *order}
  for name in pairs sections
    if (name\match("^pin_") or name\match("^corner_")) and not used[name]
      diagnostics[#diagnostics + 1] = "Additional parameter #{name} was detected; it is reported but not applied to ASS."
  for frame = first_frame, last_frame
    quad = {}
    missing = {}
    for name in *order
      values, gap = interpolated_values sections[name], frame, {0, 0}
      missing[#missing + 1] = name if gap
      quad[#quad + 1] = {x: values[1], y: values[2]}
    diagnostics[#diagnostics + 1] = "Frame #{frame} was interpolated in #{table.concat missing, ', '}." if #missing > 0
    samples[#samples + 1] = {source_frame: frame, quad: quad, interpolated: #missing > 0}
  {
    kind: "perspective"
    :format
    meta: parse_meta(input)
    :samples
    :diagnostics
    first_frame: first_frame
    last_frame: last_frame
    has_interpolation: #diagnostics > 0
  }

find_balanced = (text, start_pos, open_char, close_char) ->
  depth = 0
  for i = start_pos, #text
    ch = text\sub i, i
    if ch == open_char
      depth += 1
    elseif ch == close_char
      depth -= 1
      return text\sub(start_pos, i), i if depth == 0
  nil, nil

extract_labeled_array = (block, label) ->
  label_pos = block\find label, 1, true
  return nil unless label_pos
  start_pos = block\find "[", label_pos, true
  return nil unless start_pos
  array = find_balanced block, start_pos, "[", "]"
  array

parse_pair_array = (array_text) ->
  points = {}
  return points unless array_text
  pattern = "%[%s*(#{NUM_PATTERN})%s*,%s*(#{NUM_PATTERN})%s*%]"
  for x, y in array_text\gmatch pattern
    points[#points + 1] = {x: tonumber(x), y: tonumber(y)}
  points

frame_from_prefix = (prefix) ->
  frame = nil
  for line in tostring(prefix or "")\gmatch "[^\r\n]+"
    value = line\match "^%s*([%-]?%d+)%s"
    frame = tonumber value if value
  frame

parse_shape_block = (block, frame, source_index) ->
  vertices_raw = extract_labeled_array block, "vertices"
  in_raw = extract_labeled_array block, "inTangents"
  out_raw = extract_labeled_array block, "outTangents"
  vertices = parse_pair_array vertices_raw
  in_tangents = parse_pair_array in_raw
  out_tangents = parse_pair_array out_raw
  return nil, "Shape #{source_index} contains no vertices." if #vertices < 2
  return nil, "Shape #{source_index}: incomplete inTangents." if in_raw and #in_tangents != #vertices
  return nil, "Shape #{source_index}: incomplete outTangents." if out_raw and #out_tangents != #vertices
  closed_raw = block\match "[\"']?closed[\"']?%s*[:=]%s*(%a+)"
  closed = not (closed_raw and closed_raw\lower! == "false")
  points = {}
  for i, vertex in ipairs vertices
    in_t = in_tangents[i] or {x: 0, y: 0}
    out_t = out_tangents[i] or {x: 0, y: 0}
    for value in *{vertex.x, vertex.y, in_t.x, in_t.y, out_t.x, out_t.y}
      return nil, "Shape #{source_index}, vertex #{i}: non-finite value." unless finite value
    points[#points + 1] = {
      x: vertex.x or 0
      y: vertex.y or 0
      inx: in_t.x or 0
      iny: in_t.y or 0
      outx: out_t.x or 0
      outy: out_t.y or 0
    }
  {id: "shape_#{source_index}", frame: frame, :closed, :points, source_index: source_index}

parse_bezier_point_block = (body, frame, source_index, closed) ->
  points = {}
  for raw in tostring(body or "")\gmatch "Point%(([^%)]*)%)"
    values = parse_numbers raw
    if #values >= 2
      return nil, "Bezier #{source_index}: non-finite value." unless finite(values[1]) and finite(values[2])
      points[#points + 1] = {
        x: values[1], y: values[2]
        inx: 0, iny: 0, outx: 0, outy: 0
        normalized: true, y_up: true
      }
  return nil, "Bezier #{source_index} contains no points." if #points < 2
  {id: "bezier_#{source_index}", frame: frame, :closed, :points, source_index: source_index, legacy_bezier: true}

parse_legacy_bezier_data = (input) ->
  text, masks, pos, source_index = tostring(input or ""), {}, 1, 0
  while true
    bezier_pos = text\find "Bezier", pos, true
    break unless bezier_pos
    open_pos = text\find "(", bezier_pos, true
    break unless open_pos
    block, block_end = find_balanced text, open_pos, "(", ")"
    break unless block and block_end
    source_index += 1
    prefix = text\sub math.max(1, bezier_pos - 2048), bezier_pos - 1
    suffix = text\sub block_end + 1, math.min(#text, block_end + 4096)
    frame = frame_from_prefix(prefix) or source_index - 1
    closed = tostring(suffix\match("<Open>%s*(%d+)%s*</Open>") or "0") != "1"
    shape, err = parse_bezier_point_block block\sub(2, -2), frame, source_index, closed
    return nil, err unless shape
    masks[#masks + 1] = shape
    pos = block_end + 1
  return nil if #masks == 0
  masks

expand_sparse_shape_samples = (samples, diagnostics) ->
  return samples if #samples < 2
  first_frame, last_frame = samples[1].source_frame, samples[#samples].source_frame
  return samples if last_frame - first_frame + 1 == #samples
  by_frame = {sample.source_frame, sample for sample in *samples}
  out, held, held_count = {}, nil, 0
  for frame = first_frame, last_frame
    sample = by_frame[frame]
    if sample
      held = sample
      out[#out + 1] = sample
    else
      fallback = held
      unless fallback
        fallback = samples[1]
      out[#out + 1] = {source_frame: frame, masks: fallback.masks, interpolated: true, held: true}
      held_count += 1
  diagnostics[#diagnostics + 1] = "#{held_count} missing Shape frames were held without compressing time; strict synchronization may reject them."
  out

parse_shape_data = (input) ->
  text, masks, pos, source_index = tostring(input or ""), {}, 1, 0
  while true
    shape_pos = text\find "Shape", pos, true
    break unless shape_pos
    brace_pos = text\find "{", shape_pos, true
    break unless brace_pos
    block, block_end = find_balanced text, brace_pos, "{", "}"
    break unless block and block_end
    if block\find "vertices", 1, true
      source_index += 1
      prefix = text\sub math.max(1, brace_pos - 2048), brace_pos - 1
      frame = frame_from_prefix(prefix) or 0
      shape, err = parse_shape_block block, frame, source_index
      return nil, err unless shape
      masks[#masks + 1] = shape
    pos = block_end + 1
  if #masks == 0 and text\find("vertices", 1, true)
    shape, err = parse_shape_block text, 0, 1
    return nil, err unless shape
    masks[1] = shape
  if #masks == 0
    masks, err = parse_legacy_bezier_data text
    return nil, err if err
  return nil, "No Shape{...} or Bezier(Point(...)) data was found." unless masks and #masks > 0
  table.sort masks, (a, b) ->
    if a.frame == b.frame then a.source_index < b.source_index else a.frame < b.frame
  by_frame, frames = {}, {}
  for mask in *masks
    unless by_frame[mask.frame]
      by_frame[mask.frame] = {}
      frames[#frames + 1] = mask.frame
    by_frame[mask.frame][#by_frame[mask.frame] + 1] = mask
  table.sort frames
  diagnostics = {"Multiple-mask identity is preserved by block order; pasted data does not always include layer names."}
  unsupported_shape_fields = {}
  lower_text = text\lower!
  for label in *{"featherseg", "featherradii", "featherinterps", "feathertensions", "feathertypes", "mask feather", "mask opacity", "mask expansion", "mask mode", "inverted"}
    unsupported_shape_fields[#unsupported_shape_fields + 1] = label if lower_text\find(label, 1, true)
  if #unsupported_shape_fields > 0
    diagnostics[#diagnostics + 1] = "AE Mask fields not representable by one ASS clip: #{table.concat unsupported_shape_fields, ', '}."
  samples = [{source_frame: frame, masks: by_frame[frame]} for frame in *frames]
  samples = expand_sparse_shape_samples samples, diagnostics
  {
    kind: "shape"
    format: "Adobe After Effects Mask Data"
    meta: parse_meta(input)
    :samples
    :diagnostics
    first_frame: samples[1].source_frame
    last_frame: samples[#samples].source_frame
    sparse: frames[#frames] - frames[1] + 1 != #frames
  }

strip_quotes = (value) ->
  value = trim value
  quoted = value\match '^"(.*)"$' or value\match "^'(.*)'$"
  quoted or value

shake_points_from_values = (values, expected_vertices = nil) ->
  return nil, nil, nil, "vertex_data must contain blocks of 12 values." if #values == 0 or #values % 12 != 0
  vertices = #values / 12
  return nil, nil, nil, "vertex_data expected #{expected_vertices} vertices and contains #{vertices}." if expected_vertices and vertices != expected_vertices
  points, edge_points, has_edge = {}, {}, false
  for vertex = 1, vertices
    base = (vertex - 1) * 12
    vx, vy = values[base + 1], values[base + 2]
    lx, ly = values[base + 3], values[base + 4]
    rx, ry = values[base + 5], values[base + 6]
    for index = 1, 12
      return nil, nil, nil, "Vertex #{vertex}: value #{index} is not finite." unless finite values[base + index]
    points[vertex] = {
      x: vx, y: vy
      inx: lx - vx, iny: ly - vy
      outx: rx - vx, outy: ry - vy
      absolute_y_up: true
    }
    edge = [values[base + index] for index = 7, 12]
    edge_points[vertex] = edge
    for value in *edge
      if math.abs(value) > NUMERIC_EPSILON
        has_edge = true
        break
  points, edge_points, has_edge

shake_mask_from_key = (shape, key, points = key.points, edge_points = key.edge_points) ->
  {
    id: shape.id
    name: shape.name
    parent: shape.parent
    closed: shape.closed
    visible: shape.visible
    locked: shape.locked
    :points, :edge_points
    color: key.color or shape.color
    center: key.center
    shake: true
  }

interpolate_shake_mask = (shape, before, after, frame) ->
  return nil unless before and after and #before.points == #after.points
  span = after.frame - before.frame
  return nil if span <= 0
  k = (frame - before.frame) / span
  points = {}
  for i = 1, #before.points
    a, b = before.points[i], after.points[i]
    point = {absolute_y_up: true}
    for field in *{"x", "y", "inx", "iny", "outx", "outy"}
      point[field] = a[field] + (b[field] - a[field]) * k
    points[i] = point
  shake_mask_from_key shape, before, points, before.edge_points

build_shake_track = (shapes, meta, diagnostics) ->
  frames, seen = {}, {}
  for shape in *shapes
    continue if shape.visible == false
    for frame in *shape.key_order
      unless seen[frame]
        seen[frame] = true
        frames[#frames + 1] = frame
  table.sort frames
  return nil, "Shake SSF contains no key_time/vertex_data." if #frames == 0
  first_frame, last_frame = frames[1], frames[#frames]
  samples, approximated = {}, 0
  for frame = first_frame, last_frame
    masks, sample_approx = {}, false
    for shape in *shapes
      continue if shape.visible == false
      key = shape.keys[frame]
      mask = shake_mask_from_key(shape, key) if key
      unless mask
        before, after = nil, nil
        for key_frame in *shape.key_order
          candidate = shape.keys[key_frame]
          if key_frame < frame
            before = candidate
          elseif key_frame > frame
            after = candidate
            break
        mask = interpolate_shake_mask shape, before, after, frame
        unless mask
          held = before or after
          mask = shake_mask_from_key(shape, held) if held
        sample_approx = true if mask
      masks[#masks + 1] = mask if mask
    return nil, "Shake frame #{frame} contains no visible shape." if #masks == 0
    approximated += 1 if sample_approx
    samples[#samples + 1] = {source_frame: frame, :masks, interpolated: sample_approx}
  if approximated > 0
    diagnostics[#diagnostics + 1] = "#{approximated} SSF frames require interpolation/holding; strict mode rejects them because SSF does not preserve temporal easing."
  {
    kind: "shape"
    format: "Shake RotoShape SSF 4.0"
    :meta, :samples, :diagnostics, :shapes
    first_frame: first_frame
    last_frame: last_frame
    has_interpolation: approximated > 0
  }

parse_legacy_shake_layout = (input, num_shapes, meta, diagnostics) ->
  rows = {}
  for raw in *split_lines input
    if raw\find "vertex_data", 1, true
      values = parse_numbers raw\match("vertex_data%s+(.*)") or ""
      points, edge_points, has_edge, err = shake_points_from_values values
      return nil, err unless points
      rows[#rows + 1] = {:points, :edge_points, :has_edge}
  return nil, "Shake SSF contains no vertex_data." if #rows == 0
  return nil, "#{#rows} vertex_data blocks cannot be divided evenly among #{num_shapes} shapes." if #rows % num_shapes != 0
  length = #rows / num_shapes
  samples, edge_seen = {}, false
  for frame_index = 1, length
    masks = {}
    for shape_index = 1, num_shapes
      row = rows[(shape_index - 1) * length + frame_index]
      edge_seen or= row.has_edge
      masks[#masks + 1] = {
        id: "shake_#{shape_index}"
        name: "Shape #{shape_index}"
        closed: true
        visible: true
        points: row.points
        edge_points: row.edge_points
        shake: true
      }
    samples[#samples + 1] = {source_frame: frame_index - 1, :masks}
  diagnostics[#diagnostics + 1] = "Legacy SSF without key_time: shape-major order is preserved and aligned ordinally."
  diagnostics[#diagnostics + 1] = "Auxiliary edge/feather data was read; one ASS clip cannot represent it faithfully." if edge_seen
  {
    kind: "shape"
    format: "Shake RotoShape SSF 4.0 (legacy layout)"
    :meta, :samples, :diagnostics
    first_frame: 0
    last_frame: length - 1
  }

parse_shake_shape_data = (input) ->
  text = tostring(input or "")
  num_shapes = tonumber text\match "num_shapes%s+([%d]+)"
  return nil, "Shake SSF: num_shapes is missing or invalid." unless num_shapes and num_shapes >= 1
  meta = parse_meta text
  meta.motion_blur = tonumber text\match "motion_blur%s+([%+%-%.%deE]+)"
  meta.shutter_timing = tonumber text\match "shutter_timing%s+([%+%-%.%deE]+)"
  meta.shutter_offset = tonumber text\match "shutter_offset%s+([%+%-%.%deE]+)"
  diagnostics = {"Y-up SSF coordinates detected; vertical flipping is deferred until the actual source height is known."}
  if meta.motion_blur or meta.shutter_timing or meta.shutter_offset
    diagnostics[#diagnostics + 1] = "SSF motion blur/shutter values are retained as metadata, but ASS cannot reproduce Mocha subframe sampling; this is not geometric jitter."
  return parse_legacy_shake_layout(text, num_shapes, meta, diagnostics) unless text\find("shape_name", 1, true) or text\find("key_time", 1, true)

  known = {shape_name: true, parent_name: true, closed: true, visible: true, locked: true, tangents: true, edge_shape: true, num_vertices: true, num_key_times: true, key_time: true, center_x: true, center_y: true, color_r: true, color_g: true, color_b: true, color_a: true, vertex_data: true, shake_shape_data: true, num_shapes: true, motion_blur: true, shutter_timing: true, shutter_offset: true, Units: true, Source: true, Comp: true}
  unknown_tokens = {}
  shapes, current_shape, current_key = {}, nil, nil
  lines = split_lines text
  i = 1
  while i <= #lines
    stripped = trim lines[i]
    token, rest = stripped\match "^(%S+)%s*(.-)%s*$"
    switch token
      when "shape_name"
        current_shape = {
          id: "shake_#{#shapes + 1}:#{strip_quotes rest}"
          name: strip_quotes(rest), parent: "", closed: true, visible: true, locked: false
          keys: {}, key_order: {}
        }
        shapes[#shapes + 1] = current_shape
        current_key = nil
      when "parent_name"
        current_shape.parent = strip_quotes(rest) if current_shape
      when "closed"
        current_shape.closed = tonumber(rest) != 0 if current_shape
      when "visible"
        current_shape.visible = tonumber(rest) != 0 if current_shape
      when "locked"
        current_shape.locked = tonumber(rest) != 0 if current_shape
      when "tangents"
        current_shape.tangents = tonumber(rest) != 0 if current_shape
      when "edge_shape"
        current_shape.edge_shape = tonumber(rest) != 0 if current_shape
      when "num_vertices"
        current_shape.num_vertices = tonumber(rest) if current_shape
      when "num_key_times"
        current_shape.num_key_times = tonumber(rest) if current_shape
      when "key_time"
        return nil, "Shake SSF: key_time appears outside a shape." unless current_shape
        frame = tonumber rest
        return nil, "Shake SSF: key_time must be finite and integral." unless finite(frame) and frame == math.floor(frame)
        return nil, "Shake SSF: duplicate key_time #{frame} in #{current_shape.name}." if current_shape.keys[frame]
        current_key = {frame: frame, color: {}}
        current_shape.keys[frame] = current_key
        current_shape.key_order[#current_shape.key_order + 1] = frame
      when "center_x"
        current_key.center or= {} if current_key
        current_key.center.x = tonumber(rest) if current_key
      when "center_y"
        current_key.center or= {} if current_key
        current_key.center.y = tonumber(rest) if current_key
      when "color_r", "color_g", "color_b", "color_a"
        current_key.color[token\sub(-1)] = tonumber(rest) if current_key
      when "vertex_data"
        return nil, "Shake SSF: vertex_data appears without key_time." unless current_shape and current_key
        expected = current_shape.num_vertices and current_shape.num_vertices * 12 or nil
        values = parse_numbers rest
        while expected and #values < expected and i < #lines
          next_line = trim lines[i + 1]
          next_token = next_line\match "^(%S+)"
          break if known[next_token]
          i += 1
          more = parse_numbers next_line
          values[#values + 1] = value for value in *more
        return nil, "Shake SSF: vertex_data has #{#values} values; expected #{expected}." if expected and #values != expected
        points, edge_points, has_edge, err = shake_points_from_values values, current_shape.num_vertices
        return nil, err unless points
        current_key.points, current_key.edge_points, current_key.has_edge = points, edge_points, has_edge
      else
        unknown_tokens[token] = true if token and token != "" and not known[token] and not tonumber(token)
    i += 1

  return nil, "Shake SSF declares #{num_shapes} shapes and contains #{#shapes}." if #shapes != num_shapes
  edge_seen = false
  for shape in *shapes
    table.sort shape.key_order
    return nil, "Shake SSF: #{shape.name} declares #{shape.num_key_times} keys and contains #{#shape.key_order}." if shape.num_key_times and shape.num_key_times != #shape.key_order
    for frame in *shape.key_order
      key = shape.keys[frame]
      return nil, "Shake SSF: #{shape.name}, frame #{frame}, contains no vertex_data." unless key.points
      edge_seen or= key.has_edge
  diagnostics[#diagnostics + 1] = "Auxiliary edge/feather data was read and retained; one ASS clip cannot represent it faithfully." if edge_seen
  unknown_list = [token for token in pairs unknown_tokens]
  table.sort unknown_list
  diagnostics[#diagnostics + 1] = "Unknown or unapplied SSF fields: #{table.concat unknown_list, ', '}." if #unknown_list > 0
  build_shake_track shapes, meta, diagnostics

read_input_or_path = (input) ->
  raw = tostring(input or "")
  candidate = trim(raw)\gsub '^"(.*)"$', '%1'
  if not raw\find("\n", 1, true) and candidate != ""
    file = io.open candidate, "rb"
    if file
      content = file\read "*a"
      file\close!
      return content, candidate
  raw, nil

parse_input = (input) ->
  text, source_path = read_input_or_path input
  text = tostring(text or "")\gsub "^\239\187\191", ""
  local track, err
  if text\find "shake_shape_data 4.0", 1, true
    track, err = parse_shake_shape_data text
  elseif text\find("CC Power Pin #1", 1, true) or text\find("Corner Pin #1", 1, true)
    track, err = parse_powerpin_data text
  elseif text\find("vertices", 1, true) or text\find("Bezier(", 1, true)
    track, err = parse_shape_data text
  elseif text\find "Adobe After Effects", 1, true
    track, err = parse_transform_data text
  else
    return nil, "Unrecognized format. Supported formats are AE Transform, Power Pin/Corner Pin, AE Mask Shape, legacy Bezier, and Shake SSF 4.0."
  track.source_path = source_path if track
  track, err

linear_fit = (times, values) ->
  n = math.min #times, #values
  return nil, "At least two samples are required." if n < 2
  sum_t, sum_v, sum_tt, sum_tv = 0, 0, 0, 0
  for i = 1, n
    t, v = tonumber(times[i]), tonumber(values[i])
    return nil, "Non-numeric sample at #{i}." unless finite(t) and finite(v)
    sum_t += t
    sum_v += v
    sum_tt += t * t
    sum_tv += t * v
  denom = n * sum_tt - sum_t * sum_t
  return nil, "All timestamps are equal." if math.abs(denom) < SINGULAR_EPSILON
  slope = (n * sum_tv - sum_t * sum_v) / denom
  intercept = (sum_v - slope * sum_t) / n
  residuals, sse, max_abs = {}, 0, 0
  for i = 1, n
    residual = values[i] - (intercept + slope * times[i])
    residuals[i] = residual
    sse += residual * residual
    max_abs = math.max max_abs, math.abs residual
  {slope: slope, intercept: intercept, residuals: residuals, rms: math.sqrt(sse / n), max: max_abs}

vector_linearity = (times, xs, ys) ->
  fit_x, err = linear_fit times, xs
  return nil, err unless fit_x
  fit_y, err = linear_fit times, ys
  return nil, err unless fit_y
  sum, max_vector = 0, 0
  residuals = {}
  for i = 1, #times
    value = math.sqrt(fit_x.residuals[i]^2 + fit_y.residuals[i]^2)
    residuals[i] = value
    sum += value * value
    max_vector = math.max max_vector, value
  {x: fit_x, y: fit_y, residuals: residuals, rms: math.sqrt(sum / #times), max: max_vector}

signed_quad_area = (quad) ->
  area = 0
  for i = 1, 4
    a, b = quad[i], quad[i % 4 + 1]
    area += a.x * b.y - b.x * a.y
  area / 2

validate_quad = (quad, min_area = 1) ->
  return false, "A quad must contain four corners." unless quad and #quad == 4
  min_x, min_y, max_x, max_y = nil, nil, nil, nil
  for i, point in ipairs quad
    return false, "Corner #{i} is not numeric." unless finite(point.x) and finite(point.y)
    min_x, max_x = math.min(min_x or point.x, point.x), math.max(max_x or point.x, point.x)
    min_y, max_y = math.min(min_y or point.y, point.y), math.max(max_y or point.y, point.y)
  area = signed_quad_area quad
  return false, "Degenerate quad: area #{format_number area, 4}." if math.abs(area) < min_area
  bbox_area = (max_x - min_x) * (max_y - min_y)
  return false, "Degenerate quad: bounding box has no area." if bbox_area < min_area
  fill_ratio = math.abs(area) / bbox_area
  return false, "Numerically unstable quad: it occupies only #{format_number(fill_ratio * 100, 4)}% of its bounding box." if fill_ratio < 0.001
  sign = nil
  for i = 1, 4
    a, b, c = quad[i], quad[i % 4 + 1], quad[(i + 1) % 4 + 1]
    edge = math.sqrt((b.x - a.x)^2 + (b.y - a.y)^2)
    return false, "Degenerate quad: edge #{i} is nearly zero." if edge < 0.001
    cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
    return false, "Quad is nearly collinear at corner #{i}." if math.abs(cross) < GEOMETRY_EPSILON
    current = cross > 0 and 1 or -1
    sign or= current
    return false, "Concave quad or crossed corners." if current != sign
  true, nil, area

series_from_track = (track, fps = nil, shape_space = nil) ->
  fps = tonumber(fps or (track.meta and track.meta.fps)) or 24
  fps = 24 if fps <= 0
  shape_space or= {}
  shape_w = tonumber(shape_space.source_width or (track.meta and track.meta.source_width)) or 1
  shape_h = tonumber(shape_space.source_height or (track.meta and track.meta.source_height)) or 1
  shape_point = (point) ->
    x, y = point.x, point.y
    if point.normalized
      x *= shape_w
      y = 1 - y if point.y_up
      y *= shape_h
    elseif point.absolute_y_up
      y = shape_h - y
    x, y
  series = {frame: {}, time: {}, x: {}, y: {}, scale_x: {}, scale_y: {}, rotation: {}, area: {}}
  for i, sample in ipairs track.samples or {}
    series.frame[i] = sample.source_frame
    series.time[i] = (sample.source_frame - track.samples[1].source_frame) * 1000 / fps
    if track.kind == "transform"
      series.x[i], series.y[i] = sample.position.x, sample.position.y
      series.scale_x[i], series.scale_y[i] = sample.scale.x, sample.scale.y
      series.rotation[i] = sample.rotation
    elseif track.kind == "perspective"
      cx, cy = 0, 0
      for point in *sample.quad
        cx += point.x / 4
        cy += point.y / 4
      series.x[i], series.y[i] = cx, cy
      series.area[i] = math.abs signed_quad_area sample.quad
    elseif track.kind == "shape"
      sx, sy, count, area = 0, 0, 0, 0
      for mask in *sample.masks
        mask_area = 0
        for point in *mask.points
          x, y = shape_point point
          sx += x
          sy += y
          count += 1
        if #mask.points >= 3
          for j = 1, #mask.points
            a, b = mask.points[j], mask.points[j % #mask.points + 1]
            ax, ay = shape_point a
            bx, by = shape_point b
            mask_area += (ax * by - bx * ay) / 2
        area += math.abs mask_area
      series.x[i], series.y[i] = sx / math.max(1, count), sy / math.max(1, count)
      series.area[i] = area
  series

Core.trim = trim
Core.finite = finite
Core.format_number = format_number
Core.parse_numbers = parse_numbers
Core.parse_meta = parse_meta
Core.parse_keyframe_sections = parse_keyframe_sections
Core.parse_transform_data = parse_transform_data
Core.parse_powerpin_data = parse_powerpin_data
Core.parse_shape_data = parse_shape_data
Core.parse_shake_shape_data = parse_shake_shape_data
Core.parse_input = parse_input
Core.parse_trim_manifest = parse_trim_manifest
Core.validate_trim_manifest = validate_trim_manifest
Core.validate_manifest_track = validate_manifest_track
Core.unwrap_angles = unwrap_angles
Core.unwrap_rotation_section = unwrap_rotation_section
Core.linear_fit = linear_fit
Core.vector_linearity = vector_linearity
Core.kalman_1d = kalman_1d
Core.signed_quad_area = signed_quad_area
Core.validate_quad = validate_quad
Core.quad_translation_model = quad_translation_model
Core.series_from_track = series_from_track

point_at = (point, x, y, ctx) ->
  if point and point.normalized
    x *= ctx.source_w
    y = 1 - y if point.y_up
    y *= ctx.source_h
  elseif point and point.absolute_y_up
    y = ctx.source_h - y
  {x: x * ctx.sx + ctx.dx, y: y * ctx.sy + ctx.dy}

segment_is_line = (point_a, point_b, ctx) ->
  eps = ctx.epsilon
  math.abs((point_a.outx or 0) * ctx.sx) <= eps and
    math.abs((point_a.outy or 0) * ctx.sy) <= eps and
    math.abs((point_b.inx or 0) * ctx.sx) <= eps and
    math.abs((point_b.iny or 0) * ctx.sy) <= eps

append_segment = (parts, point_a, point_b, ctx) ->
  endpoint = point_at point_b, point_b.x, point_b.y, ctx
  if segment_is_line point_a, point_b, ctx
    parts[#parts + 1] = "l"
    parts[#parts + 1] = format_number endpoint.x, ctx.decimals
    parts[#parts + 1] = format_number endpoint.y, ctx.decimals
  else
    c1 = point_at point_a, point_a.x + point_a.outx, point_a.y + point_a.outy, ctx
    c2 = point_at point_b, point_b.x + point_b.inx, point_b.y + point_b.iny, ctx
    parts[#parts + 1] = "b"
    for value in *{c1.x, c1.y, c2.x, c2.y, endpoint.x, endpoint.y}
      parts[#parts + 1] = format_number value, ctx.decimals

render_shape_path = (shape, ctx) ->
  points = shape.points
  return nil, "Shape has fewer than two points." unless points and #points >= 2
  first = point_at points[1], points[1].x, points[1].y, ctx
  parts = {"m", format_number(first.x, ctx.decimals), format_number(first.y, ctx.decimals)}
  append_segment parts, points[i], points[i + 1], ctx for i = 1, #points - 1
  append_segment parts, points[#points], points[1], ctx if shape.closed
  table.concat parts, " "

normalize_path = (path) ->
  path = trim path
  return nil, "Empty ASS path." if path == ""
  if ZF
    ok, shape = pcall -> ZF.shape path
    return nil, "ZF.shape rejected the path: #{shape}" unless ok and shape
    ok_build, built = pcall -> trim shape\build!
    return built if ok_build and built and built != ""
  path

manual_bounds = (path) ->
  min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
  is_x, found = true, false
  for token in tostring(path or "")\gmatch "%S+"
    if token == "m" or token == "l" or token == "b"
      is_x = true
    else
      number = tonumber token
      if number
        if is_x
          min_x, max_x = math.min(min_x, number), math.max(max_x, number)
        else
          min_y, max_y = math.min(min_y, number), math.max(max_y, number)
          found = true
        is_x = not is_x
  return nil unless found
  {l: min_x, t: min_y, r: max_x, b: max_y, w: max_x - min_x, h: max_y - min_y}

path_bounds = (path) ->
  if ZF
    ok, shape = pcall -> ZF.shape path
    if ok and shape and shape.l and shape.t and shape.w and shape.h
      return {l: shape.l, t: shape.t, r: shape.l + shape.w, b: shape.t + shape.h, w: shape.w, h: shape.h}
  manual_bounds path

manual_shift_path = (path, dx, dy, decimals) ->
  out, is_x = {}, true
  for token in tostring(path or "")\gmatch "%S+"
    if token == "m" or token == "l" or token == "b"
      out[#out + 1], is_x = token, true
    else
      number = tonumber token
      if number
        out[#out + 1] = format_number(number + (is_x and dx or dy), decimals)
        is_x = not is_x
      else
        out[#out + 1] = token
  table.concat out, " "

shift_path = (path, dx, dy, decimals) ->
  if ZF
    ok, moved = pcall -> trim ZF.shape(path)\move(dx, dy)\build!
    return moved if ok and moved and moved != ""
  manual_shift_path path, dx, dy, decimals

build_shape_context = (opts, meta, script_res) ->
  target_w = tonumber(opts.target_width) or script_res.x or DEFAULTS.target_width
  target_h = tonumber(opts.target_height) or script_res.y or DEFAULTS.target_height
  source_w = if opts.use_source_meta and meta.source_width then meta.source_width else tonumber(opts.source_width)
  source_h = if opts.use_source_meta and meta.source_height then meta.source_height else tonumber(opts.source_height)
  source_w = target_w unless source_w and source_w > 0
  source_h = target_h unless source_h and source_h > 0
  {
    sx: opts.scale_to_script and target_w / source_w or 1
    sy: opts.scale_to_script and target_h / source_h or 1
    dx: tonumber(opts.offset_x) or 0
    dy: tonumber(opts.offset_y) or 0
    decimals: clamp opts.decimals, 0, 6
    epsilon: tonumber(opts.tangent_epsilon) or DEFAULTS.tangent_epsilon
    target_w: target_w, target_h: target_h
    source_w: source_w, source_h: source_h
  }

prepare_shape_samples = (track, opts, script_res) ->
  ctx = build_shape_context opts, track.meta or {}, script_res
  out = {}
  for sample in *track.samples
    paths = {}
    for mask in *sample.masks
      path, err = render_shape_path mask, ctx
      return nil, err unless path
      path, err = normalize_path path
      return nil, err unless path
      paths[#paths + 1] = path
    out[#out + 1] = {source_frame: sample.source_frame, path: trim(table.concat(paths, " ")), masks: sample.masks}
  {kind: "shape", format: track.format, meta: track.meta, samples: out, diagnostics: track.diagnostics, ctx: ctx}

starts_at = (text, pos, needle) -> text\sub(pos, pos + #needle - 1) == needle

strip_top_level_clips = (text) ->
  text, out, i, depth = tostring(text or ""), {}, 1, 0
  while i <= #text
    if depth == 0 and (starts_at(text, i, "\\clip(") or starts_at(text, i, "\\iclip("))
      open_pos = text\find "(", i, true
      _, close_pos = find_balanced text, open_pos, "(", ")"
      if close_pos
        i = close_pos + 1
        continue
    ch = text\sub i, i
    out[#out + 1] = ch
    if ch == "("
      depth += 1
    elseif ch == ")" and depth > 0
      depth -= 1
    i += 1
  table.concat out

apply_clip_text = (text, mode, path) ->
  tag = "\\#{mode}(#{path})"
  clean = strip_top_level_clips text
  if clean\match "^%s*{"
    clean\gsub "^(%s*{)", "%1" .. tag, 1
  else
    "{#{tag}}" .. clean

apply_clip_with_ass = (line, mode, path) ->
  return nil unless ASS and ASS.parse and ASS.Draw and ASS.Draw.DrawingBase
  working = copy_line line
  ok, result = pcall ->
    data = ASS\parse working
    data\removeTags {"clip_vect", "iclip_vect", "clip_rect", "iclip_rect"}
    drawing = ASS.Draw.DrawingBase{str: path}
    data\replaceTags {ASS\createTag(mode == "iclip" and "iclip_vect" or "clip_vect", drawing)}
    data\commit!
    working.text
  if ok and result and result != "" then result else nil

shape_text = (path, opts) ->
  decimals = clamp opts.decimals, 0, 6
  bounds = path_bounds(path) or {l: 0, t: 0, w: 0, h: 0}
  local_path = shift_path path, -bounds.l, -bounds.t, decimals
  tags = opts.shape_tags or DEFAULTS.shape_tags
  "{\\an7\\pos(#{format_number bounds.l, decimals},#{format_number bounds.t, decimals})\\fscx100\\fscy100#{tags}\\p1}#{local_path}{\\p0}"

render_shape_line_text = (line, mode, path, opts) ->
  return shape_text(path, opts) if mode == "shape"
  apply_clip_with_ass(line, mode, path) or apply_clip_text(line.text or "", mode, path)

get_script_resolution = (subs) ->
  res = {x: nil, y: nil}
  if subs
    for i = 1, #subs
      line = subs[i]
      if line and line.class == "info"
        key = tostring(line.key or "")\lower!
        res.x = tonumber(line.value) if key == "playresx"
        res.y = tonumber(line.value) if key == "playresy"
      break if line and line.class == "dialogue"
  res.x or= DEFAULTS.target_width
  res.y or= DEFAULTS.target_height
  res

exclusive_end_frame = (start_time, end_time) -> Media.exclusiveEndFrame start_time, end_time

selection_window = (subs, sel) ->
  window, err = Media.selectionWindow subs, sel, {includeComments: false, positiveDuration: true, requireFrames: true}
  return nil, err or "Select at least one non-comment dialogue line with a positive duration." unless window
  window

slice_track = (track, sample_start, count, strict = true) ->
  sample_start = math.floor(tonumber(sample_start) or 1)
  return nil, "The first sample must be 1 or greater." if sample_start < 1
  if track.kind == "shape" and #track.samples == 1 and count > 1
    out = copy_table track
    out.samples = {}
    first = track.samples[1]
    for i = 1, count
      sample = copy_table first
      sample.source_frame = first.source_frame + i - 1
      sample.held = true
      out.samples[i] = sample
    out.first_frame, out.last_frame = out.samples[1].source_frame, out.samples[#out.samples].source_frame
    out.sample_start = 1
    out.static = true
    out.diagnostics = [item for item in *track.diagnostics or {}]
    out.diagnostics[#out.diagnostics + 1] = "Static Shape repeated exactly for #{count} frames."
    return out
  if sample_start + count - 1 > #track.samples
    first_source = track.samples[1] and track.samples[1].source_frame or "?"
    last_source = track.samples[#track.samples] and track.samples[#track.samples].source_frame or "?"
    return nil, "The data has #{#track.samples} samples (source frames #{first_source}..#{last_source}); the selection covers #{count} frames and requires #{count} samples starting at row #{sample_start}. 'Row' is 1-based and is not the value in the Frame column."
  samples = [track.samples[i] for i = sample_start, sample_start + count - 1]
  if strict
    expected = samples[1].source_frame
    for i, sample in ipairs samples
      return nil, "Temporal gap: expected source frame #{expected + i - 1}, received #{sample.source_frame}." if sample.source_frame != expected + i - 1
      return nil, "Source frame #{sample.source_frame} was interpolated; disable strict synchronization to accept it." if sample.interpolated
      return nil, "Ambiguous Rotation at source frame #{sample.source_frame} (#{format_number sample.ambiguous_rotation, 3)} degree jump); normalize the export or deliberately disable strict synchronization." if sample.ambiguous_rotation
  out = copy_table track
  out.samples = samples
  out.first_frame, out.last_frame = samples[1].source_frame, samples[#samples].source_frame
  out.sample_start = sample_start
  out

canonical_fps = (fps) ->
  fps = tonumber fps
  return nil unless fps and fps > 0
  for pair in *{
    {23.976, 24000 / 1001}
    {29.97, 30000 / 1001}
    {47.952, 48000 / 1001}
    {59.94, 60000 / 1001}
    {119.88, 120000 / 1001}
  }
    nominal, exact = pair[1], pair[2]
    return exact if math.abs(fps - nominal) <= 0.0005 or math.abs(fps - exact) <= 0.0005
  fps

timing_diagnostics = (track, window) ->
  diagnostics = {}
  start_ms = aegisub.ms_from_frame window.start_frame
  end_ms = aegisub.ms_from_frame window.end_frame
  return diagnostics unless start_ms and end_ms
  duration = end_ms - start_ms
  if duration > 0
    local_fps = window.frame_count * 1000 / duration
    diagnostics.local_fps = local_fps
    diagnostics.actual_duration_ms = duration
    if track.meta and track.meta.fps
      effective_fps = canonical_fps track.meta.fps
      if effective_fps
        diagnostics.effective_export_fps = effective_fps
        diagnostics.fps_delta = math.abs(effective_fps - local_fps)
        diagnostics.expected_duration_ms = window.frame_count * 1000 / effective_fps
        diagnostics.duration_delta_ms = math.abs(duration - diagnostics.expected_duration_ms)
    max_phase = 0
    for i = 0, window.frame_count
      actual = aegisub.ms_from_frame(window.start_frame + i)
      return diagnostics unless actual
      predicted = start_ms + duration * i / window.frame_count
      max_phase = math.max max_phase, math.abs(actual - predicted)
    diagnostics.max_timeline_phase_ms = max_phase
  diagnostics

validate_sync = (track, window, strict, ordinal_exact = false) ->
  info = timing_diagnostics track, window
  if strict and not ordinal_exact and not track.static and info.duration_delta_ms and info.duration_delta_ms > 2.5
    return nil, "Duration mismatch: export #{format_number info.expected_duration_ms, 3} ms, timeline #{format_number info.actual_duration_ms, 3} ms (delta #{format_number info.duration_delta_ms, 3} ms)."
  if strict and not ordinal_exact and not track.static and (info.max_timeline_phase_ms or 0) > 2.5
    return nil, "Variable or irregular timeline: phase differs by #{format_number info.max_timeline_phase_ms, 3} ms from CFR sampling."
  if strict and track.meta and track.meta.source_par and track.meta.comp_par and math.abs(track.meta.source_par - track.meta.comp_par) > 0.0001
    return nil, "Pixel-aspect mismatch (source #{track.meta.source_par}, comp #{track.meta.comp_par}); it will not be approximated silently."
  info

same_output_state = (a, b) ->
  return false unless a and b and a.end_time == b.start_time
  return false unless LineOps.shallowEqual a.extra, b.extra
  for key in *{"text", "layer", "style", "actor", "effect", "margin_l", "margin_r", "margin_t", "comment"}
    return false if a[key] != b[key]
  true

compress_output_lines = (lines) ->
  out = {}
  for line in *lines
    if #out > 0 and same_output_state(out[#out], line)
      out[#out].end_time = line.end_time
    else
      out[#out + 1] = line
  out

frame_interval = (line, frame) ->
  start_time = math.max line.start_time, aegisub.ms_from_frame(frame)
  last_frame = exclusive_end_frame(line.start_time, line.end_time) - 1
  end_time = if frame == last_frame then line.end_time else math.min(line.end_time, aegisub.ms_from_frame(frame + 1))
  return nil unless end_time > start_time
  start_time, end_time

replace_or_insert_outputs = (subs, index, outputs, replace) ->
  return if #outputs == 0
  if replace
    subs[index] = outputs[1]
    for i = #outputs, 2, -1
      subs.insert index + 1, outputs[i]
  else
    for i = #outputs, 1, -1
      subs.insert index + 1, outputs[i]

selection_from_groups = (groups) ->
  ordered = [group for group in *groups or {}]
  table.sort ordered, (a, b) -> a.index < b.index
  selected, shift = {}, 0
  for group in *ordered
    count = math.max 0, tonumber(group.count) or 0
    start_index = group.index + shift + (group.replace and 0 or 1)
    selected[#selected + 1] = start_index + offset for offset = 0, count - 1
    shift += count - (group.replace and 1 or 0)
  selected

apply_shape_track = (subs, window, track, opts) ->
  script_res = get_script_resolution subs
  prepared, err = prepare_shape_samples track, opts, script_res
  return nil, err unless prepared
  mode = opts.output_mode or DEFAULTS.output_mode
  replace = opts.placement != "Insert new lines"
  wrapped_by_index, groups = {}, {}
  if mode != "shape"
    collection = LineCollection subs, window.indices, accept_dialogue_line, false
    wrapped_by_index[line.number] = line for line in *collection.lines
  for position = #window.indices, 1, -1
    index = window.indices[position]
    base = subs[index]
    outputs = {}
    first_frame = aegisub.frame_from_ms base.start_time
    last_frame = exclusive_end_frame base.start_time, base.end_time
    fbf_by_frame = {}
    if mode != "shape"
      source = wrapped_by_index[index]
      return nil, "Line #{index}: temporal tags could not be baked." unless source
      source.startFrame, source.endFrame = first_frame, last_frame
      source_data = ASS\parse source
      for frame_line in *ArchUtil.line2fbf(source_data)
        frame = frame_line.startFrame or aegisub.frame_from_ms frame_line.start_time
        fbf_by_frame[frame] = frame_line
    for frame = first_frame, last_frame - 1
      sample_index = if opts.mapping_mode == "Restart on each line" then frame - first_frame + 1 else frame - window.start_frame + 1
      sample = prepared.samples[sample_index]
      continue unless sample
      start_time, end_time = frame_interval base, frame
      continue unless start_time
      line = if mode == "shape" then copy_line(base) else fbf_by_frame[frame]
      return nil, "Line #{index}, frame #{frame}: ASS state could not be baked." unless line
      line.start_time, line.end_time = start_time, end_time
      shift_frame_karaoke line, base.start_time, start_time if mode != "shape"
      line.comment = false
      line.layer = (tonumber(base.layer) or 0) + (replace and 0 or tonumber(opts.layer_offset) or 1)
      line.text = render_shape_line_text line, mode, sample.path, opts
      outputs[#outputs + 1] = copy_line line
    outputs = compress_output_lines outputs
    return nil, "Line #{index}: no Shape output was generated." if #outputs == 0
    replace_or_insert_outputs subs, index, outputs, replace
    groups[#groups + 1] = {index: index, count: #outputs, replace: replace}
  true, {selection: selection_from_groups(groups), groups: groups}

Core.build_shape_context = build_shape_context
Core.render_shape_path = render_shape_path
Core.prepare_shape_samples = prepare_shape_samples
Core.shape_text = shape_text
Core.render_shape_line_text = render_shape_line_text
Core.strip_top_level_clips = strip_top_level_clips
Core.apply_clip_text = apply_clip_text
Core.selection_window = selection_window
Core.exclusive_end_frame = exclusive_end_frame
Core.slice_track = slice_track
Core.canonical_fps = canonical_fps
Core.timing_diagnostics = timing_diagnostics
Core.validate_sync = validate_sync
Core.compress_output_lines = compress_output_lines
Core.selection_from_groups = selection_from_groups
Core.apply_shape_track = apply_shape_track

scale_track_coordinates = (track, script_res, opts) ->
  out = copy_table track
  out.meta = copy_table track.meta
  out.samples = {}
  source_w = if opts.use_source_meta and track.meta and track.meta.source_width then track.meta.source_width else tonumber(opts.source_width)
  source_h = if opts.use_source_meta and track.meta and track.meta.source_height then track.meta.source_height else tonumber(opts.source_height)
  source_w = script_res.x unless source_w and source_w > 0
  source_h = script_res.y unless source_h and source_h > 0
  sx = opts.scale_to_script and script_res.x / source_w or 1
  sy = opts.scale_to_script and script_res.y / source_h or 1
  dx, dy = tonumber(opts.offset_x) or 0, tonumber(opts.offset_y) or 0
  for sample in *track.samples
    copy = copy_table sample
    if sample.position
      copy.position = {x: sample.position.x * sx + dx, y: sample.position.y * sy + dy}
    if sample.anchor
      copy.anchor = {x: sample.anchor.x * sx + dx, y: sample.anchor.y * sy + dy}
    if sample.scale
      copy.scale = {x: sample.scale.x, y: sample.scale.y}
    if sample.quad
      copy.quad = [{x: point.x * sx + dx, y: point.y * sy + dy} for point in *sample.quad]
    copy.coordinate_scale = {x: sx, y: sy}
    out.samples[#out.samples + 1] = copy
  out.coordinate_scale = {x: sx, y: sy, dx: dx, dy: dy, source_w: source_w, source_h: source_h}
  out

rotate_vector = (x, y, radians) ->
  c, s = math.cos(radians), math.sin(radians)
  x * c - y * s, x * s + y * c

transform_point = (x, y, sample, reference) ->
  ref_sx = (reference.scale and reference.scale.x or 100) / 100
  ref_sy = (reference.scale and reference.scale.y or 100) / 100
  cur_sx = (sample.scale and sample.scale.x or 100) / 100
  cur_sy = (sample.scale and sample.scale.y or 100) / 100
  return nil, nil, "Zero scale at the reference frame." if math.abs(ref_sx) < SCALE_EPSILON or math.abs(ref_sy) < SCALE_EPSILON
  coord = reference.coordinate_scale or sample.coordinate_scale or {x: 1, y: 1}
  coord_x, coord_y = tonumber(coord.x) or 1, tonumber(coord.y) or 1
  return nil, nil, "Invalid coordinate scale." if math.abs(coord_x) < SCALE_EPSILON or math.abs(coord_y) < SCALE_EPSILON
  dx, dy = (x - reference.position.x) / coord_x, (y - reference.position.y) / coord_y
  dx, dy = rotate_vector dx, dy, math.rad(reference.rotation or 0)
  dx, dy = dx / ref_sx, dy / ref_sy
  dx, dy = dx * cur_sx, dy * cur_sy
  dx, dy = rotate_vector dx, dy, -math.rad(sample.rotation or 0)
  sample.position.x + dx * coord_x, sample.position.y + dy * coord_y


inverse_transform_point = (x, y, sample, reference) ->
  ref_sx = (reference.scale and reference.scale.x or 100) / 100
  ref_sy = (reference.scale and reference.scale.y or 100) / 100
  cur_sx = (sample.scale and sample.scale.x or 100) / 100
  cur_sy = (sample.scale and sample.scale.y or 100) / 100
  return nil, nil, "Current scale is zero; the transform cannot be inverted." if math.abs(cur_sx) < SCALE_EPSILON or math.abs(cur_sy) < SCALE_EPSILON
  coord = reference.coordinate_scale or sample.coordinate_scale or {x: 1, y: 1}
  coord_x, coord_y = tonumber(coord.x) or 1, tonumber(coord.y) or 1
  return nil, nil, "Invalid coordinate scale." if math.abs(coord_x) < SCALE_EPSILON or math.abs(coord_y) < SCALE_EPSILON
  dx, dy = (x - sample.position.x) / coord_x, (y - sample.position.y) / coord_y
  dx, dy = rotate_vector dx, dy, math.rad(sample.rotation or 0)
  dx, dy = dx / cur_sx, dy / cur_sy
  dx, dy = dx * ref_sx, dy * ref_sy
  dx, dy = rotate_vector dx, dy, -math.rad(reference.rotation or 0)
  reference.position.x + dx * coord_x, reference.position.y + dy * coord_y

motion_point = (x, y, sample, reference, options) ->
  if options and options.inverse
    inverse_transform_point x, y, sample, reference
  else
    transform_point x, y, sample, reference

effective_transform_sample = (sample, reference, options, prefix = "") ->
  enabled = (name, fallback = true) ->
    value = options[prefix .. name]
    if value == nil then fallback else value
  copy = copy_table sample
  position_x, position_y = reference.position.x, reference.position.y
  position_x = sample.position.x if enabled "x_position"
  position_y = sample.position.y if enabled "y_position"
  copy.position = {x: position_x, y: position_y}
  copy.scale = if enabled("scale") then {x: sample.scale.x, y: sample.scale.y} else {x: reference.scale.x, y: reference.scale.y}
  copy.rotation = if enabled("rotation") then sample.rotation else reference.rotation
  copy

rect_clip_to_path = (content) ->
  l, t, r, b = content\match "^%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*$"
  return nil unless l
  "m #{l} #{t} l #{r} #{t} #{r} #{b} #{l} #{b}"

clip_to_float_path = (content) ->
  content = trim content
  rectangle = rect_clip_to_path content
  return rectangle, true if rectangle
  scale, path = content\match "^(%d+)%s*,%s*(.*)$"
  return content, false unless scale
  scale = tonumber scale
  return nil, false unless scale and scale >= 1 and scale == math.floor(scale)
  factor = 2 ^ (scale - 1)
  path = path\gsub "([%.%d%-]+) ([%.%d%-]+)", (x, y) ->
    "#{format_number(tonumber(x) / factor, 4)} #{format_number(tonumber(y) / factor, 4)}"
  path, false

transform_clip_path = (path, sample, reference, decimals = 2, options = nil) ->
  path\gsub "([%.%d%-]+) ([%.%d%-]+)", (x, y) ->
    tx, ty, err = motion_point tonumber(x), tonumber(y), sample, reference, options
    return x .. " " .. y if err
    "#{format_number tx, decimals} #{format_number ty, decimals}"

translate_clip_path = (path, dx, dy, decimals = 2) ->
  return path if math.abs(dx) < NUMERIC_EPSILON and math.abs(dy) < NUMERIC_EPSILON
  path\gsub "([%.%d%-]+) ([%.%d%-]+)", (x, y) ->
    "#{format_number(tonumber(x) + dx, decimals)} #{format_number(tonumber(y) + dy, decimals)}"

IMPORTANT_TAGS = {
  xscale: {opt: "scale", skip: 0}
  yscale: {opt: "scale", skip: 0}
  border: {opt: "border", skip: 0}
  shadow: {opt: "shadow", skip: 0}
  zrot: {opt: "rotation"}
}

get_missing_tags = (block, options, properties) ->
  result = {}
  for key, spec in pairs IMPORTANT_TAGS
    tag = Tags.allTags[key]
    if options[spec.opt] and not block\match(tag.pattern) and properties[tag] != spec.skip
      result[#result + 1] = tag\format properties[tag]
  table.concat result

prepare_static_line = (line, options) ->
  line.hasOrg, line.hasClip = false, false
  line\getPropertiesFromStyle!
  unless line\extraMetrics line.styleRef
    line\ensureLeadingOverrideBlockExists!
    line\runCallbackOnFirstOverride (tag_block) =>
      tag_block\gsub "{", ("{\\pos(%g,%g)")\format @xPosition, @yPosition
  line\runCallbackOnFirstOverride (tag_block) =>
    tags = get_missing_tags tag_block, options, line.properties
    "{" .. tags .. tag_block\sub 2
  styles = line.parentCollection and line.parentCollection.styles or {}
  line\runCallbackOnOverrides (tag_block) =>
    tag_block\gsub "\\org%([%.%d%-]+,[%.%d%-]+%)", ->
      line.hasOrg = true
      nil
    saved_style, reset = line.styleRef, false
    tag_block = tag_block\gsub "\\r([^\\}]*)([^}]*)", (reset_style, remainder) ->
      if styles[reset_style]
        line.styleRef = styles[reset_style]
        line\getPropertiesFromStyle!
        reset = true
      tags = get_missing_tags remainder, options, line.properties
      "\\r" .. reset_style .. tags .. remainder
    if reset
      line.styleRef = saved_style
      line\getPropertiesFromStyle!
    for pattern in *{"(\\clip%b())", "(\\iclip%b())"}
      tag_block = tag_block\gsub pattern, (clip) ->
        line.hasClip = true
        clip
    tag_block
  line

apply_transform_text = (line, sample, reference, options) ->
  text = line.text
  effective_sample = effective_transform_sample sample, reference, options
  snap_x, snap_y = 0, 0
  if options.absolute and not options.only_clip and not options.inverse
    pos_x, pos_y = text\match "\\pos%(([%-%d%.]+),([%-%d%.]+)%)"
    if pos_x and pos_y
      relative_x, relative_y, snap_err = motion_point tonumber(pos_x), tonumber(pos_y), effective_sample, reference, options
      unless snap_err
        snap_x = effective_sample.position.x - relative_x if options.x_position
        snap_y = effective_sample.position.y - relative_y if options.y_position
  unless options.only_clip
    text = text\gsub "(\\pos)%(([%-%d%.]+),([%-%d%.]+)%)", (tag, x, y) ->
      x, y = tonumber(x), tonumber(y)
      tx, ty, err = motion_point x, y, effective_sample, reference, options
      return "#{tag}(#{x},#{y})" if err
      tx += snap_x
      ty += snap_y
      "#{tag}(#{format_number tx, 2},#{format_number ty, 2})"
    if options.origin
      text = text\gsub "(\\org)%(([%-%d%.]+),([%-%d%.]+)%)", (tag, x, y) ->
        tx, ty, err = motion_point tonumber(x), tonumber(y), effective_sample, reference, options
        return "#{tag}(#{x},#{y})" if err
        tx += snap_x
        ty += snap_y
        "#{tag}(#{format_number tx, 2},#{format_number ty, 2})"
    rx = (effective_sample.scale.x or 100) / (reference.scale.x or 100)
    ry = (effective_sample.scale.y or 100) / (reference.scale.y or 100)
    if options.inverse
      rx = 1 / rx if math.abs(rx) > SCALE_EPSILON
      ry = 1 / ry if math.abs(ry) > SCALE_EPSILON
    scalar = math.sqrt math.abs(rx * ry)
    if options.scale
      text = text\gsub "(\\fscx)([%-%d%.]+)", (tag, value) -> tag .. format_number(tonumber(value) * rx, 2)
      text = text\gsub "(\\fscy)([%-%d%.]+)", (tag, value) -> tag .. format_number(tonumber(value) * ry, 2)
    if options.border
      text = text\gsub "(\\xbord)([%-%d%.]+)", (tag, value) -> tag .. format_number(tonumber(value) * math.abs(rx), 2)
      text = text\gsub "(\\ybord)([%-%d%.]+)", (tag, value) -> tag .. format_number(tonumber(value) * math.abs(ry), 2)
      text = text\gsub "(\\bord)([%-%d%.]+)", (tag, value) -> tag .. format_number(tonumber(value) * scalar, 2)
    if options.shadow
      text = text\gsub "(\\xshad)([%-%d%.]+)", (tag, value) -> tag .. format_number(tonumber(value) * rx, 2)
      text = text\gsub "(\\yshad)([%-%d%.]+)", (tag, value) -> tag .. format_number(tonumber(value) * ry, 2)
      text = text\gsub "(\\shad)([%-%d%.]+)", (tag, value) -> tag .. format_number(tonumber(value) * scalar, 2)
    if options.blur
      blur_ratio = 1 - (1 - scalar) * (tonumber(options.blur_scale) or 1)
      text = text\gsub "(\\blur)([%-%d%.]+)", (tag, value) -> tag .. format_number(tonumber(value) * blur_ratio, 2)
    if options.rotation
      rotation_delta = effective_sample.rotation - reference.rotation
      rotation_delta = -rotation_delta if options.inverse
      for pattern in *{"(\\frz)([%-%d%.]+)", "(\\fr)([%-%d%.]+)"}
        text = text\gsub pattern, (tag, value) -> tag .. format_number(tonumber(value) + rotation_delta, 2)
  if options.track_clip
    cs, cr = effective_sample, reference
    apply_clip = (tag_name, wrapped) ->
      content = wrapped\sub 2, -2
      path, was_rect = clip_to_float_path content
      return "\\#{tag_name}#{wrapped}" unless path
      return "\\#{tag_name}#{wrapped}" if was_rect and options.rect_clip == false
      return "\\#{tag_name}#{wrapped}" if not was_rect and options.vector_clip == false
      moved = transform_clip_path path, cs, cr, options.decimals or 2, options
      moved = translate_clip_path moved, snap_x, snap_y, options.decimals or 2
      if was_rect and not options.rect_to_vector
        points = parse_numbers moved
        if #points >= 8
          axis_error = math.max math.abs(points[2] - points[4]), math.abs(points[3] - points[5]), math.abs(points[6] - points[8]), math.abs(points[7] - points[1])
          if axis_error <= 0.01
            l = math.min points[1], points[3], points[5], points[7]
            r = math.max points[1], points[3], points[5], points[7]
            t = math.min points[2], points[4], points[6], points[8]
            b = math.max points[2], points[4], points[6], points[8]
            return "\\#{tag_name}(#{format_number l, options.decimals or 2},#{format_number t, options.decimals or 2},#{format_number r, options.decimals or 2},#{format_number b, options.decimals or 2})"
      "\\#{tag_name}(#{moved})"
    text = text\gsub "\\clip(%b())", (wrapped) -> apply_clip "clip", wrapped
    text = text\gsub "\\iclip(%b())", (wrapped) -> apply_clip "iclip", wrapped
  text

has_unsafe_linear_tags = (text, options) ->
  return true if text\find "\\move%b()"
  return true if text\find "\\t%b()"
  return true if text\find "\\fad%b()" or text\find "\\fade%b()"
  return true if text\find "\\k[fo]?[%d]+" or text\find "\\K[%d]+"
  return true if text\find "\\org%b()"
  return true if text\find("\\clip%b()") or text\find("\\iclip%b()")
  false

shift_frame_karaoke = (frame_line, source_start, frame_start) ->
  return unless frame_line and frame_line.shiftKaraoke
  frame_line.karaokeShift = (frame_start - source_start) * 0.1
  frame_line\shiftKaraoke!

track_channels_constant = (samples, tolerance = GEOMETRY_EPSILON, options = nil) ->
  first = samples[1]
  for sample in *samples
    if not options or options.scale
      return false if math.abs(sample.scale.x - first.scale.x) > tolerance
      return false if math.abs(sample.scale.y - first.scale.y) > tolerance
    if not options or options.rotation
      return false if math.abs(sample.rotation - first.rotation) > tolerance
  true

axis_aligned_rotation = (degrees, tolerance = GEOMETRY_EPSILON) ->
  value = math.abs(tonumber(degrees) or 0) % 180
  value <= tolerance or math.abs(value - 180) <= tolerance

transform_shear_risk = (track, reference_index = 1, tolerance = GEOMETRY_EPSILON, first_sample = 1, last_sample = nil) ->
  return nil unless track and track.samples and #track.samples > 0
  reference = track.samples[math.floor(clamp(reference_index, 1, #track.samples))]
  return "zero reference scale", "zero_scale" if math.abs(reference.scale.x or 0) < tolerance or math.abs(reference.scale.y or 0) < tolerance
  coord = track.coordinate_scale or reference.coordinate_scale or {x: 1, y: 1}
  nonuniform_coordinates = math.abs((coord.x or 1) - (coord.y or 1)) > tolerance
  first_sample = math.floor clamp(first_sample, 1, #track.samples)
  last_sample = math.floor clamp(last_sample or #track.samples, first_sample, #track.samples)
  for i = first_sample, last_sample
    sample = track.samples[i]
    rx = (sample.scale.x or 100) / reference.scale.x
    ry = (sample.scale.y or 100) / reference.scale.y
    rotation_delta = (sample.rotation or 0) - (reference.rotation or 0)
    if nonuniform_coordinates and not axis_aligned_rotation(rotation_delta, tolerance)
      return "source frame #{sample.source_frame}: aspect change plus rotation requires shear (use Power Pin/Perspective)", "aspect_rotation"
  nil

track_deformation_flags = (track, reference_index = 1, tolerance = GEOMETRY_EPSILON, first_sample = 1, last_sample = nil) ->
  reference = track.samples[math.floor(clamp(reference_index, 1, #track.samples))]
  anisotropic, rotation_changes = false, false
  first_sample = math.floor clamp(first_sample, 1, #track.samples)
  last_sample = math.floor clamp(last_sample or #track.samples, first_sample, #track.samples)
  for i = first_sample, last_sample
    sample = track.samples[i]
    rx = (sample.scale.x or 100) / (reference.scale.x or 100)
    ry = (sample.scale.y or 100) / (reference.scale.y or 100)
    anisotropic = true if math.abs(rx - ry) > tolerance
    rotation_changes = true if math.abs((sample.rotation or 0) - (reference.rotation or 0)) > tolerance
  anisotropic, rotation_changes, reference

line_transform_shear_risk = (line, track, reference_index = 1, options = {}, first_sample = 1, last_sample = nil) ->
  anisotropic, rotation_changes, reference = track_deformation_flags track, reference_index, GEOMETRY_EPSILON, first_sample, last_sample
  return nil unless anisotropic or rotation_changes
  fields = {"text", "properties", "align", "xPosition", "yPosition", "move", "hasOrg", "hasClip", "styleRef"}
  saved, present = {}, {}
  for field in *fields
    present[field] = line[field] != nil
    saved[field] = line[field]
  probe_options = copy_table options
  probe_options.scale, probe_options.rotation = true, true
  probe_options.border, probe_options.shadow, probe_options.blur = false, false, false
  ok, prepare_error = pcall prepare_static_line, line, probe_options
  probe_text = line.text
  for field in *fields
    if present[field]
      line[field] = saved[field]
    else
      line[field] = nil
  return "could not read the initial geometry: #{prepare_error}" unless ok
  if anisotropic
    rotations = {}
    for pattern in *{"\\frz([%+%-]?[%d%.]+)", "\\fr([%+%-]?[%d%.]+)"}
      for value in probe_text\gmatch pattern
        number = tonumber value
        rotations[#rotations + 1] = number if number
    rotations = {0} if #rotations == 0
    for rotation in *rotations
      relative = rotation - (reference.rotation or 0)
      unless axis_aligned_rotation relative
        return "anisotropic scaling over \\frz#{format_number(rotation, 3)} requires shear; use Power Pin/Perspective"
  for tag in *{"fax", "fay", "frx", "fry"}
    pattern = "\\#{tag}([%+%-]?[%d%.]+)"
    for value in probe_text\gmatch pattern
      if math.abs(tonumber(value) or 0) > GEOMETRY_EPSILON
        return "\\#{tag}#{value} cannot be composed faithfully with this deformation; use Power Pin/Perspective"
  nil

effective_transform_track = (track, reference_index, options) ->
  out = copy_table track
  out.coordinate_scale = track.coordinate_scale
  out.samples = {}
  reference = track.samples[math.floor(clamp(reference_index, 1, #track.samples))]
  out.samples[i] = effective_transform_sample(sample, reference, options) for i, sample in ipairs track.samples
  out


sample_index_for = (frame, source, window, options) ->
  if options.mapping_mode == "Restart on each line"
    frame - source.startFrame + 1
  else
    frame - window.start_frame + 1

insert_first_override = (text, tags) ->
  if text\match "^%s*{"
    text\gsub "^(%s*{)", "%1" .. tags, 1
  else
    "{#{tags}}" .. text

try_linear_line = (line, track, window, options) ->
  return nil unless options.optimize_linear and #track.samples >= 2
  return nil if has_unsafe_linear_tags line.text, options
  first_frame = aegisub.frame_from_ms line.start_time
  last_frame = exclusive_end_frame line.start_time, line.end_time
  return nil if last_frame - first_frame < 2
  return nil unless track_channels_constant track.samples, GEOMETRY_EPSILON, options
  prepare_static_line line, options
  positions = [call for call in *LineOps.tagCalls(line.text, "pos") when call.top_level]
  return nil unless #positions == 1
  args = LineOps.splitArguments positions[1].value
  pos_x, pos_y = tonumber(args[1]), tonumber(args[2])
  return nil unless pos_x and pos_y
  reference_index = clamp options.reference_frame, 1, #track.samples
  reference = track.samples[reference_index]
  times, xs, ys = {}, {}, {}
  for frame = first_frame, last_frame - 1
    sample_index = sample_index_for frame, line, window, options
    sample = track.samples[sample_index]
    return nil unless sample
    effective_sample = effective_transform_sample sample, reference, options
    tx, ty, err = motion_point pos_x, pos_y, effective_sample, reference, options
    return nil if err
    if options.absolute
      tx = effective_sample.position.x if options.x_position
      ty = effective_sample.position.y if options.y_position
    times[#times + 1] = 0.5 * (aegisub.ms_from_frame(frame) + aegisub.ms_from_frame(frame + 1))
    xs[#xs + 1], ys[#ys + 1] = tx, ty
  fit = vector_linearity times, xs, ys
  return nil unless fit and fit.max <= (tonumber(options.linear_tolerance) or DEFAULTS.linear_tolerance)
  start_x = fit.x.intercept + fit.x.slope * line.start_time
  start_y = fit.y.intercept + fit.y.slope * line.start_time
  end_x = fit.x.intercept + fit.x.slope * line.end_time
  end_y = fit.y.intercept + fit.y.slope * line.end_time
  text = LineOps.removeTagCalls line.text, "pos"
  distance = math.sqrt((end_x - start_x)^2 + (end_y - start_y)^2)
  tag = if distance <= 0.0001
    "\\pos(#{format_number start_x, 2},#{format_number start_y, 2})"
  else
    "\\move(#{format_number start_x, 2},#{format_number start_y, 2},#{format_number end_x, 2},#{format_number end_y, 2})"
  line.text = insert_first_override text, tag
  line.linear_report = fit
  line

apply_transform_track = (subs, window, raw_track, options) ->
  script_res = get_script_resolution subs
  track = scale_track_coordinates raw_track, script_res, options
  reference_index = math.floor clamp(options.reference_frame, 1, #track.samples)
  reference = track.samples[reference_index]
  return nil, "X or Y scale is zero at the reference frame." if math.abs(reference.scale.x or 0) < SCALE_EPSILON or math.abs(reference.scale.y or 0) < SCALE_EPSILON
  effective_track = effective_transform_track track, reference_index, options
  shear_risk, shear_code = transform_shear_risk effective_track, reference_index
  shear_applies = not options.only_clip and shear_risk != nil
  collection = LineCollection subs, window.indices, accept_dialogue_line, true
  ordered = [line for line in *collection.lines]
  table.sort ordered, (a, b) -> a.number > b.number
  if options.strict_geometry and not options.only_clip
    for source in *ordered
      source.startFrame = aegisub.frame_from_ms source.start_time
      source.endFrame = exclusive_end_frame source.start_time, source.end_time
      first_sample = math.max 1, source.startFrame - window.start_frame + 1
      last_sample = math.min #effective_track.samples, source.endFrame - window.start_frame
      matrix_risk = transform_shear_risk effective_track, reference_index, GEOMETRY_EPSILON, first_sample, last_sample
      return nil, "Line #{source.humanizedNumber or source.number or '?'}: #{matrix_risk}." if matrix_risk
      line_risk = line_transform_shear_risk source, effective_track, reference_index, options, first_sample, last_sample
      return nil, "Line #{source.humanizedNumber or source.number or '?'}: #{line_risk}." if line_risk
  report = {linear: 0, fbf: 0, compressed: 0, groups: {}}
  report.warning = shear_risk if shear_applies
  for source in *ordered
    base = subs[source.number]
    source.startFrame = aegisub.frame_from_ms source.start_time
    source.endFrame = exclusive_end_frame source.start_time, source.end_time
    original_text = source.text
    optimized = if options.only_clip then nil else try_linear_line source, track, window, options
    if optimized
      output = copy_line optimized
      output.start_time, output.end_time = source.start_time, source.end_time
      subs[source.number] = output
      report.linear += 1
      report.groups[#report.groups + 1] = {index: source.number, count: 1, replace: true}
      continue
    source.text = original_text
    source_data = ASS\parse source
    fbf = ArchUtil.line2fbf source_data
    outputs = {}
    for frame_line in *fbf
      frame = frame_line.startFrame or aegisub.frame_from_ms frame_line.start_time
      sample_index = sample_index_for frame, source, window, options
      sample = track.samples[sample_index]
      continue unless sample
      start_time, end_time = frame_interval source, frame
      continue unless start_time
      frame_line.start_time, frame_line.end_time = start_time, end_time
      shift_frame_karaoke frame_line, source.start_time, start_time
      prepare_static_line frame_line, options unless options.only_clip
      frame_line.text = apply_transform_text frame_line, sample, reference, options
      outputs[#outputs + 1] = copy_line frame_line
    before = #outputs
    outputs = compress_output_lines outputs
    return nil, "Line #{source.humanizedNumber or source.number or '?'}: no Transform output was generated." if #outputs == 0
    report.compressed += before - #outputs
    report.fbf += #outputs
    replace_or_insert_outputs subs, source.number, outputs, true
    report.groups[#report.groups + 1] = {index: source.number, count: #outputs, replace: true}
  report.selection = selection_from_groups report.groups
  true, report

Core.scale_track_coordinates = scale_track_coordinates
Core.transform_point = transform_point
Core.inverse_transform_point = inverse_transform_point
Core.motion_point = motion_point
Core.effective_transform_sample = effective_transform_sample
Core.transform_clip_path = transform_clip_path
Core.translate_clip_path = translate_clip_path
Core.apply_transform_text = apply_transform_text
Core.shift_frame_karaoke = shift_frame_karaoke
Core.track_channels_constant = track_channels_constant
Core.transform_shear_risk = transform_shear_risk
Core.track_deformation_flags = track_deformation_flags
Core.line_transform_shear_risk = line_transform_shear_risk
Core.effective_transform_track = effective_transform_track
Core.try_linear_line = try_linear_line
Core.apply_transform_track = apply_transform_track

PERSPECTIVE_WARNING_LABELS = {
  zero_size: "zero-size text or drawing"
  text_and_drawings: "mixed text and drawing"
  move: "unbaked \\move"
  multiple_tags: "repeated geometric tags"
  transform: "\\t that changes geometry"
}

perspective_warning_text = (warnings) ->
  out = {}
  for warning in *warnings or {}
    name, detail = warning[1], warning[2]
    label = PERSPECTIVE_WARNING_LABELS[name] or tostring(name)
    label ..= " (#{detail})" if detail
    out[#out + 1] = label
  table.concat out, ", "

validate_quad_track = (track) ->
  winding = nil
  for i, sample in ipairs track.samples
    ok, err, area = validate_quad sample.quad, 0.5
    return nil, "Source frame #{sample.source_frame}: #{err}" unless ok
    current = area > 0 and 1 or -1
    winding or= current
    return nil, "Quad winding changes at source frame #{sample.source_frame}." if current != winding
  true

perspective_track = (subs, window, raw_track, options) ->
  script_res = get_script_resolution subs
  track = scale_track_coordinates raw_track, script_res, options
  ok, err = validate_quad_track track
  return nil, err unless ok
  quads = {}
  for sample in *track.samples
    quad_points = {}
    quad_points[#quad_points + 1] = {point.x, point.y} for point in *sample.quad
    quads[#quads + 1] = Quad quad_points
  reference_index = math.floor clamp(options.reference_frame, 1, #quads)
  lines = LineCollection subs, window.indices, accept_all_lines
  ok_video, video_w, video_h = pcall aegisub.video_size
  video_w, video_h = tonumber(video_w), tonumber(video_h)
  return nil, "Could not obtain the video dimensions." unless ok_video and video_w and video_h and video_w > 0 and video_h > 0
  play_y = tonumber(lines.meta and (lines.meta.PlayResY or lines.meta.playresy or lines.meta.res_y))
  layout_y = tonumber(lines.meta and (lines.meta.LayoutResY or lines.meta.layoutresy)) or video_h
  return nil, "The script has no valid PlayResY/LayoutResY for perspective tracking." unless play_y and play_y > 0 and layout_y > 0
  layout_scale = play_y / layout_y
  abs_reference_frame = window.start_frame + reference_index - 1
  lines\runCallback (collection, line) ->
    line.startFrame = aegisub.frame_from_ms line.start_time
    line.endFrame = exclusive_end_frame line.start_time, line.end_time
  relative_lines, to_delete, setup_error = {}, {}, nil
  lines\runCallback ((collection, line) ->
    data = ASS\parse line
    to_delete[#to_delete + 1] = line
    line.willdelete = true
    fbf = ArchUtil.line2fbf data
    local_reference_frame = math.floor clamp(abs_reference_frame, line.startFrame, line.endFrame - 1)
    relative_line = fbf[local_reference_frame - line.startFrame + 1]
    relative_quad = quads[local_reference_frame - window.start_frame + 1]
    unless relative_line and relative_quad
      setup_error = "Line #{line.humanizedNumber or line.number or '?'}: its local reference could not be built."
      return
    relative_lines[relative_line] = relative_quad
    for fbf_line in *fbf
      frame = fbf_line.startFrame or aegisub.frame_from_ms fbf_line.start_time
      start_time, end_time = frame_interval line, frame
      continue unless start_time
      fbf_line.start_time, fbf_line.end_time = start_time, end_time
      shift_frame_karaoke fbf_line, line.start_time, start_time
      fbf_line.rel_line = relative_line
      fbf_line.reference_quad = relative_quad
      collection\addLine fbf_line
  ), true
  return nil, setup_error if setup_error
  org_mode = ({
    ["Keep \\org"]: 1
    ["Force stable center"]: 2
    ["Try \\fax0"]: 3
  })[options.org_mode] or 2
  if options.apply_perspective
    for relative_line, relative_quad in pairs relative_lines
      data = ASS\parse relative_line
      tagvals, width, height, warnings = prepareForPerspective ASS, data
      warning_text = perspective_warning_text warnings
      return nil, "Line #{relative_line.number or '?'}: #{warning_text}." if warning_text != ""
      source_quad = transformPoints tagvals, width, height, nil, layout_scale
      position = Point tagvals.position.x, tagvals.position.y
      old_scale = {x: tagvals.scale_x.value, y: tagvals.scale_y.value}
      data\removeTags relevantTags
      inserted_tags = {}
      inserted_tags[#inserted_tags + 1] = tagvals[name] for name in *usedTags
      data\insertTags inserted_tags
      aligned_rect = (w, h) ->
        result = Quad.rect 1, 1
        result -= Point an_xshift[tagvals.align.value], an_yshift[tagvals.align.value]
        result *= Matrix.diag w, h
        result
      rect_at_position = (w, h) ->
        result = aligned_rect w, h
        result += relative_quad\xy_to_uv position
        mapped = {}
        mapped[#mapped + 1] = relative_quad\uv_to_xy(point) for point in *result
        Quad mapped
      tagsFromQuad tagvals, rect_at_position(1, 1), width, height, org_mode, layout_scale
      target_quad = rect_at_position old_scale.x / tagvals.scale_x.value, old_scale.y / tagvals.scale_y.value
      untransformed = position + aligned_rect width, height
      transformed_points = {}
      transformed_points[#transformed_points + 1] = target_quad\uv_to_xy(untransformed\xy_to_uv(point)) for point in *source_quad
      transformed = Quad transformed_points
      tagsFromQuad tagvals, transformed, width, height, org_mode, layout_scale
      data\cleanTags 4
      data\commit!
  for relative_line in pairs relative_lines
    data = ASS\parse relative_line
    tags, width, height, warnings = prepareForPerspective ASS, data
    warning_text = perspective_warning_text warnings
    return nil, "Reference line: #{warning_text}." if warning_text != ""
    relative_line.tags = tags
    relative_line.quad = transformPoints tags, width, height, nil, layout_scale
  lines\runCallback (collection, line) ->
    return if line.willdelete
    return unless line.rel_line
    relative_quad = line.reference_quad or relative_lines[line.rel_line]
    return unless relative_quad
    data = ASS\parse line
    sample_index = line.startFrame - window.start_frame + 1
    frame_quad = quads[sample_index]
    return unless frame_quad
    tagvals, width, height, warnings = prepareForPerspective ASS, data
    warning_text = perspective_warning_text warnings
    error "Moka Perspective: #{warning_text}" if warning_text != ""
    old_scale = {x: tagvals.scale_x.value, y: tagvals.scale_y.value}
    uv_points = {}
    uv_points[#uv_points + 1] = relative_quad\xy_to_uv(point) for point in *line.rel_line.quad
    uv_quad = Quad uv_points
    unless options.track_position
      uv_quad += frame_quad\xy_to_uv(Point(tagvals.position.x, tagvals.position.y)) - relative_quad\xy_to_uv(Point(line.rel_line.tags.position.x, line.rel_line.tags.position.y))
    target_points = {}
    target_points[#target_points + 1] = frame_quad\uv_to_xy(point) for point in *uv_quad
    target_quad = Quad target_points
    data\removeTags relevantTags
    inserted_tags = {}
    inserted_tags[#inserted_tags + 1] = tagvals[name] for name in *usedTags
    data\insertTags inserted_tags
    tagsFromQuad tagvals, target_quad, width, height, org_mode, layout_scale
    if options.track_border_shadow
      for name in *{"outline", "shadow"}
        for coord in *{"x", "y"}
          tagvals["#{name}_#{coord}"].value *= tagvals["scale_#{coord}"].value / old_scale[coord]
    if options.track_clip
      clip = (data\getTags {"clip_vect", "iclip_vect"})[1]
      unless clip
        rect = (data\removeTags {"clip_rect", "iclip_rect"})[1]
        if rect
          clip = rect\getVect!
          clip\setInverse rect.__tag.inverse
          data\insertTags clip
      if clip
        for contour in *clip.contours
          for command in *contour.commands
            for point in *command\getPoints true
              projected = frame_quad\uv_to_xy relative_quad\xy_to_uv(Point(point.x, point.y))
              point.x, point.y = projected\x!, projected\y!
    data\cleanTags 4
    data\commit!
  lines\insertLines!
  lines\deleteLines to_delete
  selection, active = lines\getSelection!
  true, {selection: selection, active: active}

Core.perspective_warning_text = perspective_warning_text
Core.validate_quad_track = validate_quad_track
Core.perspective_track = perspective_track



median = (values) ->
  sorted = [tonumber(value) for value in *values or {} when finite value]
  table.sort sorted
  count = #sorted
  return nil if count == 0
  middle = math.floor((count + 1) / 2)
  if count % 2 == 1 then sorted[middle] else (sorted[middle] + sorted[middle + 1]) / 2

percentile = (values, ratio) ->
  sorted = [tonumber(value) for value in *values or {} when finite value]
  table.sort sorted
  count = #sorted
  return nil if count == 0
  return sorted[1] if count == 1
  position = clamp(ratio or 0.5, 0, 1) * (count - 1) + 1
  lower = math.floor position
  upper = math.ceil position
  return sorted[lower] if lower == upper
  sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower)

mad = (values, center = nil) ->
  center or= median values
  return 0 unless center
  deviations = {}
  deviations[#deviations + 1] = math.abs(value - center) for value in *values when finite value
  median(deviations) or 0

solve_system = (matrix, vector) ->
  count = #vector
  work = {}
  for row = 1, count
    work[row] = [matrix[row][column] for column = 1, count]
    work[row][count + 1] = vector[row]
  for column = 1, count
    pivot, best = column, math.abs(work[column][column] or 0)
    for row = column + 1, count
      value = math.abs(work[row][column] or 0)
      if value > best
        pivot, best = row, value
    return nil if best < SINGULAR_EPSILON
    work[column], work[pivot] = work[pivot], work[column] if pivot != column
    divisor = work[column][column]
    work[column][index] /= divisor for index = column, count + 1
    for row = 1, count
      if row != column
        factor = work[row][column]
        work[row][index] -= factor * work[column][index] for index = column, count + 1
  [work[index][count + 1] for index = 1, count]

poly_predict = (xs, ys, degree, target) ->
  count = math.min #xs, #ys
  return nil if count == 0
  degree = math.floor clamp(degree or 1, 0, math.min(3, count - 1))
  size = degree + 1
  center = xs[math.floor((count + 1) / 2)] or 0
  scale = math.max 1, math.abs((xs[count] or center) - (xs[1] or center))
  matrix, vector = {}, {}
  for row = 1, size
    matrix[row] = [0 for column = 1, size]
    vector[row] = 0
  for index = 1, count
    value = (xs[index] - center) / scale
    powers = {1}
    powers[power + 1] = powers[power] * value for power = 1, degree
    for row = 1, size
      vector[row] += powers[row] * ys[index]
      matrix[row][column] += powers[row] * powers[column] for column = 1, size
  matrix[index][index] += SCALE_EPSILON for index = 1, size
  coefficients = solve_system matrix, vector
  return median ys unless coefficients
  value, power = (target - center) / scale, 1
  result = 0
  for index = 1, size
    result += coefficients[index] * power
    power *= value
  result

local_regression = (values, frames, window = 7, degree = 2) ->
  count = #values
  radius = math.max 1, math.floor((tonumber(window) or 7) / 2)
  out = {}
  for index = 1, count
    xs, ys = {}, {}
    for neighbor = math.max(1, index - radius), math.min(count, index + radius)
      if finite values[neighbor]
        xs[#xs + 1] = frames[neighbor] or neighbor
        ys[#ys + 1] = values[neighbor]
    out[index] = poly_predict(xs, ys, degree, frames[index] or index) or values[index]
  out

clone_transform_track = (track) ->
  out = copy_table track
  out.meta = copy_table track.meta
  out.diagnostics = [item for item in *track.diagnostics or {}]
  out.samples = {}
  for index, sample in ipairs track.samples or {}
    copy = copy_table sample
    copy.position = copy_table sample.position
    copy.scale = copy_table sample.scale
    copy.anchor = copy_table sample.anchor if sample.anchor
    copy.coordinate_scale = copy_table sample.coordinate_scale if sample.coordinate_scale
    out.samples[index] = copy
  out

TRANSFORM_CHANNELS = {
  {"position", "x", 0.25}
  {"position", "y", 0.25}
  {"scale", "x", 0.15}
  {"scale", "y", 0.15}
  {"rotation", nil, 0.08}
  {"opacity", nil, 0.25}
}

channel_value = (sample, descriptor) ->
  parent, child = descriptor[1], descriptor[2]
  value = sample[parent]
  if child then value and value[child] else value

set_channel_value = (sample, descriptor, value) ->
  parent, child = descriptor[1], descriptor[2]
  if child
    sample[parent] or= {}
    sample[parent][child] = value
  else
    sample[parent] = value

phase_slip_candidate = (track) ->
  samples = track and track.samples or {}
  return nil if #samples < 4
  steps, scale_steps, rotation_steps = {}, {}, {}
  for index = 2, #samples
    previous, current = samples[index - 1], samples[index]
    dx = current.position.x - previous.position.x
    dy = current.position.y - previous.position.y
    steps[index] = math.sqrt(dx * dx + dy * dy)
    dsx = (current.scale.x or 100) - (previous.scale.x or 100)
    dsy = (current.scale.y or 100) - (previous.scale.y or 100)
    scale_steps[index] = math.sqrt(dsx * dsx + dsy * dsy)
    rotation_steps[index] = math.abs((current.rotation or 0) - (previous.rotation or 0))
  moving_steps, sampled_scales, sampled_rotations = {}, {}, {}
  for index = 2, #samples
    moving_steps[#moving_steps + 1] = steps[index] if steps[index] > GEOMETRY_EPSILON
    sampled_scales[#sampled_scales + 1] = scale_steps[index]
    sampled_rotations[#sampled_rotations + 1] = rotation_steps[index]
  typical = median moving_steps
  return nil unless typical and typical > 0.0001
  typical_scale = median(sampled_scales) or 0
  typical_rotation = median(sampled_rotations) or 0
  best = nil
  for index = 2, #samples - 1
    stalled = steps[index] <= math.max(0.02, typical * 0.08)
    resumes = steps[index + 1] >= typical * 0.35
    scale_duplicate = scale_steps[index] <= math.max(0.005, typical_scale * 0.25)
    rotation_duplicate = rotation_steps[index] <= math.max(0.01, typical_rotation * 0.75)
    if stalled and resumes and scale_duplicate and rotation_duplicate
      score = (1 - math.min(1, steps[index] / math.max(typical, GEOMETRY_EPSILON))) * math.min(1, steps[index + 1] / typical)
      candidate = {
        :index, :score, typical_step: typical, stalled_step: steps[index], resumed_step: steps[index + 1]
        source_frame: samples[index].source_frame
      }
      best = candidate if not best or candidate.score > best.score
  best

repair_transform_phase = (track, candidate, window = 11, degree = 2) ->
  return clone_transform_track(track), nil unless candidate and candidate.index
  out = clone_transform_track track
  count, index = #out.samples, candidate.index
  return out, nil if index < 2 or index >= count
  for sample_index = index, count - 1
    source_frame = out.samples[sample_index].source_frame
    next_sample = out.samples[sample_index + 1]
    copy = copy_table next_sample
    copy.position = copy_table next_sample.position
    copy.scale = copy_table next_sample.scale
    copy.anchor = copy_table(next_sample.anchor) if next_sample.anchor
    copy.coordinate_scale = copy_table(next_sample.coordinate_scale) if next_sample.coordinate_scale
    copy.source_frame = source_frame
    copy.phase_repaired = true
    out.samples[sample_index] = copy
  last = copy_table out.samples[count]
  last.position = copy_table out.samples[count].position
  last.scale = copy_table out.samples[count].scale
  last.anchor = copy_table(out.samples[count].anchor) if out.samples[count].anchor
  first_fit = math.max 1, count - math.max(3, tonumber(window) or 11)
  for descriptor in *TRANSFORM_CHANNELS
    xs, ys = {}, {}
    for sample_index = first_fit, count - 1
      value = channel_value out.samples[sample_index], descriptor
      if finite value
        xs[#xs + 1] = sample_index
        ys[#ys + 1] = value
    prediction = poly_predict xs, ys, degree, count
    set_channel_value last, descriptor, prediction if prediction
  last.source_frame = track.samples[count].source_frame
  last.phase_repaired = true
  out.samples[count] = last
  message = "Removed duplicate sample at row #{index} (source frame #{candidate.source_frame or '?'}); only the new tail sample was extrapolated."
  out.diagnostics[#out.diagnostics + 1] = message
  out, message

cleanup_transform_track = (track, options) ->
  mode = options.cleanup_mode or "Off"
  return clone_transform_track(track), {mode: mode, changed: 0} if mode == "Off"
  out = clone_transform_track track
  count = #out.samples
  reference_index = math.floor clamp(options.reference_frame or 1, 1, count)
  frames = [index for index = 1, count]
  changed = 0
  for descriptor in *TRANSFORM_CHANNELS
    values = [channel_value(sample, descriptor) for sample in *out.samples]
    continue unless #values == count and finite(values[1])
    threshold = descriptor[3]
    cleaned = [value for value in *values]
    if mode == "Protective"
      low, high = percentile(values, 0.05), percentile(values, 0.95)
      if low and high and high - low <= threshold
        cleaned[index] = values[reference_index] for index = 1, count
      else
        fit = linear_fit frames, values
        absolute_residuals = {}
        if fit
          absolute_residuals[#absolute_residuals + 1] = math.abs(value) for value in *fit.residuals
        residual_p95 = math.huge
        residual_p95 = percentile(absolute_residuals, 0.95) or math.huge if fit
        if fit and residual_p95 <= threshold
          cleaned[index] = fit.intercept + fit.slope * frames[index] for index = 1, count
        else
          for index = 2, count - 1
            neighborhood = {values[index - 1], values[index + 1]}
            local_center = median neighborhood
            local_scale = mad neighborhood, local_center
            if local_center and math.abs(values[index] - local_center) > math.max(threshold * 2, local_scale * 4)
              cleaned[index] = local_center
    else
      smooth = local_regression values, frames, options.cleanup_window, options.cleanup_degree
      strength = clamp((tonumber(options.cleanup_strength) or 100) / 100, 0, 1)
      cleaned[index] = values[index] + (smooth[index] - values[index]) * strength for index = 1, count
    anchor_delta = values[reference_index] - cleaned[reference_index]
    for index = 1, count
      cleaned[index] += anchor_delta
      if math.abs(cleaned[index] - values[index]) > NUMERIC_EPSILON
        set_channel_value out.samples[index], descriptor, cleaned[index]
        changed += 1
  report = {mode: mode, :changed}
  out, report

prepare_transform_track = (track, options) ->
  working = clone_transform_track track
  report = {phase: nil, repaired: false, cleanup: nil}
  candidate = phase_slip_candidate working
  report.phase = candidate
  if candidate and options.phase_mode == "Repair duplicate sample"
    working, report.phase_message = repair_transform_phase working, candidate, options.cleanup_window, options.cleanup_degree
    report.repaired = true
  working, report.cleanup = cleanup_transform_track working, options
  working.preprocess_report = report
  working, report

Core.phase_slip_candidate = phase_slip_candidate
Core.repair_transform_phase = repair_transform_phase
Core.cleanup_transform_track = cleanup_transform_track
Core.prepare_transform_track = prepare_transform_track

read_clipboard = ->
  ok, value = pcall -> clipboard.get!
  if ok and value then tostring value else ""

show_message = (title, message, height = 16) ->
  aegisub.dialog.display {
    {class: "label", label: tostring(title or script_name), x: 0, y: 0, width: 72, height: 1}
    {class: "textbox", name: "message", text: tostring(message or ""), x: 0, y: 1, width: 72, height: height}
  }, {"OK"}

sample_count_for_selection = (subs, window, mapping_mode) ->
  return window.frame_count unless mapping_mode == "Restart on each line"
  largest = 1
  for index in *window.indices
    line = subs[index]
    first = aegisub.frame_from_ms line.start_time
    last = exclusive_end_frame line.start_time, line.end_time
    largest = math.max largest, last - first
  largest

motion_dialog = (inverse = false) ->
  action = if inverse then "Revert" else "Apply"
  controls = {
    {class: "label", label: "Mocha / After Effects Transform data or a text-file path:", x: 0, y: 0, width: 12, height: 1}
    {class: "textbox", name: "input", text: read_clipboard!, x: 0, y: 1, width: 12, height: 11}
    {class: "label", label: "First data row", x: 0, y: 12, width: 2, height: 1}
    {class: "intedit", name: "sample_start", value: 1, min: 1, x: 2, y: 12, width: 1, height: 1}
    {class: "label", label: "Reference row", x: 3, y: 12, width: 2, height: 1}
    {class: "intedit", name: "reference_frame", value: 1, min: 1, x: 5, y: 12, width: 1, height: 1}
    {class: "label", label: "Mapping", x: 6, y: 12, width: 1, height: 1}
    {class: "dropdown", name: "mapping_mode", items: {"Selection timeline", "Restart on each line"}, value: "Selection timeline", x: 7, y: 12, width: 3, height: 1}
    {class: "checkbox", name: "x_position", label: "X", value: true, x: 0, y: 13, width: 1, height: 1}
    {class: "checkbox", name: "y_position", label: "Y", value: true, x: 1, y: 13, width: 1, height: 1}
    {class: "checkbox", name: "scale", label: "Scale", value: true, x: 2, y: 13, width: 2, height: 1}
    {class: "checkbox", name: "rotation", label: "Rotation", value: true, x: 4, y: 13, width: 2, height: 1}
    {class: "checkbox", name: "origin", label: "Move \\org", value: true, x: 6, y: 13, width: 2, height: 1}
    {class: "checkbox", name: "track_clip", label: "Transform clips", value: true, x: 8, y: 13, width: 2, height: 1}
    {class: "checkbox", name: "only_clip", label: "Clips only", value: false, x: 10, y: 13, width: 2, height: 1}
    {class: "checkbox", name: "border", label: "Borders", value: true, x: 0, y: 14, width: 2, height: 1}
    {class: "checkbox", name: "shadow", label: "Shadows", value: true, x: 2, y: 14, width: 2, height: 1}
    {class: "checkbox", name: "blur", label: "Blur", value: true, x: 4, y: 14, width: 2, height: 1}
    {class: "checkbox", name: "absolute", label: "Absolute position", value: false, x: 6, y: 14, width: 3, height: 1}
    {class: "checkbox", name: "optimize_linear", label: "Compact linear motion", value: not inverse, x: 9, y: 14, width: 3, height: 1}
    {class: "label", label: "Duplicate sample", x: 0, y: 15, width: 2, height: 1}
    {class: "dropdown", name: "phase_mode", items: {"Off", "Detect only", "Repair duplicate sample"}, value: "Detect only", x: 2, y: 15, width: 3, height: 1}
    {class: "label", label: "Cleanup", x: 5, y: 15, width: 1, height: 1}
    {class: "dropdown", name: "cleanup_mode", items: {"Off", "Protective", "Local regression"}, value: "Off", x: 6, y: 15, width: 2, height: 1}
    {class: "label", label: "Window", x: 8, y: 15, width: 1, height: 1}
    {class: "intedit", name: "cleanup_window", value: 9, min: 3, max: 99, x: 9, y: 15, width: 1, height: 1}
    {class: "label", label: "Degree", x: 10, y: 15, width: 1, height: 1}
    {class: "intedit", name: "cleanup_degree", value: 2, min: 1, max: 3, x: 11, y: 15, width: 1, height: 1}
    {class: "checkbox", name: "strict_sync", label: "Strict frame/FPS/PAR synchronization", value: DEFAULTS.strict_sync, x: 0, y: 16, width: 5, height: 1}
  }
  pressed, values = aegisub.dialog.display controls, {action, "Cancel"}, {ok: action, close: "Cancel"}
  return nil unless pressed == action
  values.inverse = inverse
  values.use_source_meta = true
  values.scale_to_script = true
  values.rect_to_vector = true
  values.rect_clip = true
  values.vector_clip = true
  values.strict_geometry = false
  values.linear_tolerance = 0.20
  values.blur_scale = 1
  values.decimals = 2
  values.cleanup_strength = 100
  values

shape_dialog = (mode, script_res) ->
  labels = {clip: "Create Clip", iclip: "Create Inverse Clip", shape: "Create Vector Drawing"}
  action = labels[mode]
  controls = {
    {class: "label", label: "Mocha AE Mask Data, Shake SSF 4.0, legacy Bezier data, or a text-file path:", x: 0, y: 0, width: 12, height: 1}
    {class: "textbox", name: "input", text: read_clipboard!, x: 0, y: 1, width: 12, height: 12}
    {class: "label", label: "First data row", x: 0, y: 13, width: 2, height: 1}
    {class: "intedit", name: "sample_start", value: 1, min: 1, x: 2, y: 13, width: 1, height: 1}
    {class: "label", label: "Mapping", x: 3, y: 13, width: 1, height: 1}
    {class: "dropdown", name: "mapping_mode", items: {"Selection timeline", "Restart on each line"}, value: "Selection timeline", x: 4, y: 13, width: 3, height: 1}
    {class: "label", label: "Placement", x: 7, y: 13, width: 1, height: 1}
    {class: "dropdown", name: "placement", items: {"Replace selection", "Insert new lines"}, value: "Replace selection", x: 8, y: 13, width: 3, height: 1}
    {class: "label", label: "Offset X", x: 0, y: 14, width: 1, height: 1}
    {class: "floatedit", name: "offset_x", value: 0, x: 1, y: 14, width: 1, height: 1}
    {class: "label", label: "Offset Y", x: 2, y: 14, width: 1, height: 1}
    {class: "floatedit", name: "offset_y", value: 0, x: 3, y: 14, width: 1, height: 1}
    {class: "label", label: "Tangent epsilon", x: 4, y: 14, width: 2, height: 1}
    {class: "floatedit", name: "tangent_epsilon", value: 0.25, min: 0, x: 6, y: 14, width: 1, height: 1}
    {class: "label", label: "Inserted layer +", x: 7, y: 14, width: 2, height: 1}
    {class: "intedit", name: "layer_offset", value: 1, min: -100, max: 100, x: 9, y: 14, width: 1, height: 1}
    {class: "label", label: "Drawing tags", x: 0, y: 15, width: 2, height: 1}
    {class: "edit", name: "shape_tags", value: "\\bord0\\shad0", x: 2, y: 15, width: 9, height: 1}
    {class: "checkbox", name: "use_source_meta", label: "Use exported source size", value: true, x: 0, y: 16, width: 3, height: 1}
    {class: "checkbox", name: "scale_to_script", label: "Scale to target", value: true, x: 3, y: 16, width: 2, height: 1}
    {class: "label", label: "Source W/H", x: 5, y: 16, width: 2, height: 1}
    {class: "intedit", name: "source_width", value: DEFAULTS.source_width, min: 1, x: 7, y: 16, width: 1, height: 1}
    {class: "intedit", name: "source_height", value: DEFAULTS.source_height, min: 1, x: 8, y: 16, width: 1, height: 1}
    {class: "label", label: "Target W/H", x: 0, y: 17, width: 2, height: 1}
    {class: "intedit", name: "target_width", value: script_res.x, min: 1, x: 2, y: 17, width: 1, height: 1}
    {class: "intedit", name: "target_height", value: script_res.y, min: 1, x: 3, y: 17, width: 1, height: 1}
    {class: "label", label: "Decimals", x: 4, y: 17, width: 1, height: 1}
    {class: "intedit", name: "decimals", value: DEFAULTS.decimals, min: 0, max: 6, x: 5, y: 17, width: 1, height: 1}
    {class: "checkbox", name: "strict_sync", label: "Strict frame/FPS/PAR synchronization", value: DEFAULTS.strict_sync, x: 6, y: 17, width: 5, height: 1}
  }
  pressed, values = aegisub.dialog.display controls, {action, "Cancel"}, {ok: action, close: "Cancel"}
  return nil unless pressed == action
  values.output_mode = mode
  values

powerpin_dialog = ->
  controls = {
    {class: "label", label: "Mocha CC Power Pin / Corner Pin data or a text-file path:", x: 0, y: 0, width: 12, height: 1}
    {class: "textbox", name: "input", text: read_clipboard!, x: 0, y: 1, width: 12, height: 12}
    {class: "label", label: "First data row", x: 0, y: 13, width: 2, height: 1}
    {class: "intedit", name: "sample_start", value: 1, min: 1, x: 2, y: 13, width: 1, height: 1}
    {class: "label", label: "Reference row", x: 3, y: 13, width: 2, height: 1}
    {class: "intedit", name: "reference_frame", value: 1, min: 1, x: 5, y: 13, width: 1, height: 1}
    {class: "checkbox", name: "apply_perspective", label: "Perspective", value: true, x: 0, y: 14, width: 2, height: 1}
    {class: "checkbox", name: "track_position", label: "Position", value: true, x: 2, y: 14, width: 2, height: 1}
    {class: "checkbox", name: "track_border_shadow", label: "Border / shadow", value: true, x: 4, y: 14, width: 3, height: 1}
    {class: "checkbox", name: "track_clip", label: "Clips", value: true, x: 7, y: 14, width: 2, height: 1}
    {class: "label", label: "Origin mode", x: 0, y: 15, width: 2, height: 1}
    {class: "dropdown", name: "org_mode", items: {"Keep \\org", "Force stable center", "Try \\fax0"}, value: "Force stable center", x: 2, y: 15, width: 4, height: 1}
    {class: "checkbox", name: "strict_sync", label: "Strict frame/FPS/PAR synchronization", value: DEFAULTS.strict_sync, x: 0, y: 16, width: 5, height: 1}
  }
  pressed, values = aegisub.dialog.display controls, {"Apply Power Pin", "Cancel"}, {ok: "Apply Power Pin", close: "Cancel"}
  return nil unless pressed == "Apply Power Pin"
  values.use_source_meta = true
  values.scale_to_script = true
  values

apply_atomically = (subs, callback) ->
  state = LineOps.snapshot subs
  ok, result, details = pcall callback
  return ok, result, details if ok and result
  restored, restore_error = pcall LineOps.restore, subs, state
  unless restored
    rollback_message = "Rollback failed: #{tostring(restore_error or 'unknown error')}"
    if ok
      details = "#{tostring(details or 'No output was generated.')}\n#{rollback_message}"
    else
      result = "#{tostring(result or 'Operation failed.')}\n#{rollback_message}"
  ok, result, details

motion_main = (inverse = false) ->
  (subs, sel, active) ->
    window, err = selection_window subs, sel
    unless window
      show_message script_name, err
      return sel
    options = motion_dialog inverse
    return sel unless options
    track, parse_error = parse_input options.input
    unless track and track.kind == "transform"
      show_message "Moka Motion / #{inverse and 'Revert Motion' or 'Apply Motion'}", parse_error or "The pasted data is not a Transform export."
      return sel
    required = sample_count_for_selection subs, window, options.mapping_mode
    sliced, slice_error = slice_track track, options.sample_start, required, options.strict_sync == true
    unless sliced
      show_message script_name, slice_error
      return sel
    sync_info, sync_error = validate_sync sliced, window, options.strict_sync == true, options.mapping_mode == "Restart on each line"
    unless sync_info
      show_message script_name, sync_error
      return sel
    options.reference_frame = math.floor clamp(options.reference_frame, 1, #sliced.samples)
    prepared, prep = prepare_transform_track sliced, options
    ok, result, details = apply_atomically subs, -> apply_transform_track subs, window, prepared, options
    unless ok and result
      show_message script_name, ok and (details or "No output was generated.") or result
      return sel
    aegisub.set_undo_point "#{script_name}: #{inverse and 'Revert Motion' or 'Apply Motion'}"
    notes = {}
    if prep.phase
      notes[#notes + 1] = "Duplicate-sample candidate: row #{prep.phase.index}, source frame #{prep.phase.source_frame or '?'}, score #{format_number(prep.phase.score * 100, 1)}%."
    notes[#notes + 1] = prep.phase_message if prep.phase_message
    notes[#notes + 1] = "Cleanup changed #{prep.cleanup.changed} channel values." if prep.cleanup and prep.cleanup.changed > 0
    show_message script_name, table.concat(notes, "\n"), 6 if #notes > 0
    if details and details.selection and #details.selection > 0
      details.selection, details.selection[1]
    else
      sel

shape_main = (mode) ->
  (subs, sel, active) ->
    window, err = selection_window subs, sel
    unless window
      show_message script_name, err
      return sel
    script_resolution = get_script_resolution subs
    options = shape_dialog mode, script_resolution
    return sel unless options
    track, parse_error = parse_input options.input
    unless track and track.kind == "shape"
      show_message script_name, parse_error or "The pasted data is not shape or mask data."
      return sel
    required = sample_count_for_selection subs, window, options.mapping_mode
    sliced, slice_error = slice_track track, options.sample_start, required, options.strict_sync == true
    unless sliced
      show_message script_name, slice_error
      return sel
    sync_info, sync_error = validate_sync sliced, window, options.strict_sync == true, options.mapping_mode == "Restart on each line"
    unless sync_info
      show_message script_name, sync_error
      return sel
    ok, result, details = apply_atomically subs, -> apply_shape_track subs, window, sliced, options
    unless ok and result
      show_message script_name, ok and (details or "No shape output was generated.") or result
      return sel
    aegisub.set_undo_point "#{script_name}: #{mode}"
    if details and details.selection and #details.selection > 0
      details.selection, details.selection[1]
    else
      sel

powerpin_main = (subs, sel, active) ->
  window, err = selection_window subs, sel
  unless window
    show_message script_name, err
    return sel
  options = powerpin_dialog!
  return sel unless options
  track, parse_error = parse_input options.input
  unless track and track.kind == "perspective"
    show_message script_name, parse_error or "The pasted data is not CC Power Pin or Corner Pin data."
    return sel
  sliced, slice_error = slice_track track, options.sample_start, window.frame_count, options.strict_sync == true
  unless sliced
    show_message script_name, slice_error
    return sel
  sync_info, sync_error = validate_sync sliced, window, options.strict_sync == true
  unless sync_info
    show_message script_name, sync_error
    return sel
  options.reference_frame = math.floor clamp(options.reference_frame, 1, #sliced.samples)
  valid, validation_error = validate_quad_track sliced
  unless valid
    show_message script_name, validation_error
    return sel
  ok, result, details = apply_atomically subs, -> perspective_track subs, window, sliced, options
  unless ok and result
    show_message script_name, ok and (details or "No perspective output was generated.") or result
    return sel
  aegisub.set_undo_point "#{script_name}: Apply Power Pin"
  if details and details.selection and #details.selection > 0
    details.selection, details.active or details.selection[1]
  else
    sel

inspect_main = (subs, sel, active) ->
  controls = {
    {class: "label", label: "Paste Mocha data or a text-file path:", x: 0, y: 0, width: 12, height: 1}
    {class: "textbox", name: "input", text: read_clipboard!, x: 0, y: 1, width: 12, height: 14}
  }
  pressed, values = aegisub.dialog.display controls, {"Inspect", "Cancel"}, {ok: "Inspect", close: "Cancel"}
  return sel unless pressed == "Inspect"
  track, err = parse_input values.input
  unless track
    show_message "Moka Motion / Inspect", err
    return sel
  lines = {
    "Type: #{track.kind}"
    "Format: #{track.format or 'unknown'}"
    "Samples: #{#track.samples}"
    "Source frames: #{track.first_frame or '?'}..#{track.last_frame or '?'}"
    "Export FPS: #{track.meta and track.meta.fps or 'not supplied'}"
    "Source size: #{track.meta and track.meta.source_width or '?'} x #{track.meta and track.meta.source_height or '?'}"
  }
  if track.kind == "transform"
    candidate = phase_slip_candidate track
    if candidate
      lines[#lines + 1] = "Duplicate-sample candidate: row #{candidate.index}, source frame #{candidate.source_frame or '?'}, score #{format_number(candidate.score * 100, 1)}%."
    else
      lines[#lines + 1] = "Duplicate-sample candidate: none."
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Diagnostics:"
  if track.diagnostics and #track.diagnostics > 0
    lines[#lines + 1] = "- #{item}" for item in *track.diagnostics
  else
    lines[#lines + 1] = "- None"
  show_message "Moka Motion / Inspect", table.concat(lines, "\n"), 18
  sel

set_position_text = (text, x, y) ->
  tag = "\\pos(#{format_number x, 3},#{format_number y, 3})"
  replaced, changed = LineOps.replaceTagCall text, "pos", tag, true
  return replaced if changed
  replaced, changed = LineOps.replaceTagCall replaced, "move", tag, true
  return replaced if changed
  insert_first_override replaced, tag

shift_linked_geometry = (text, dx, dy) ->
  return text if math.abs(dx) < NUMERIC_EPSILON and math.abs(dy) < NUMERIC_EPSILON
  text = tostring(text or "")
  text = text\gsub "\\org%(([%+%-]?[%d%.]+),([%+%-]?[%d%.]+)%)", (x, y) ->
    "\\org(#{format_number(tonumber(x) + dx, 3)},#{format_number(tonumber(y) + dy, 3)})"
  for tag_name in *{"clip", "iclip"}
    text = text\gsub "\\#{tag_name}(%b())", (wrapped) ->
      content = wrapped\sub 2, -2
      rectangle = rect_clip_to_path content
      if rectangle
        values = parse_numbers content
        return "\\#{tag_name}(#{format_number(values[1] + dx, 3)},#{format_number(values[2] + dy, 3)},#{format_number(values[3] + dx, 3)},#{format_number(values[4] + dy, 3)})"
      path, was_rect = clip_to_float_path content
      return "\\#{tag_name}#{wrapped}" unless path
      "\\#{tag_name}(#{translate_clip_path(path, dx, dy, 3)})"
  text

authored_signature = (text) ->
  clean = LineOps.removeTagCalls text, {"pos", "move", "org", "clip", "iclip", "fscx", "fscy", "frz", "fr", "bord", "xbord", "ybord", "shad", "xshad", "yshad", "blur"}
  clean\gsub "%s+", ""

build_refinery_tracks = (subs, sel) ->
  buckets, order = {}, {}
  sorted = [index for index in *sel or {}]
  table.sort sorted
  for index in *sorted
    line = subs[index]
    if line and line.class == "dialogue" and not line.comment
      position = LineOps.position line.text
      if position
        key = table.concat {tostring(line.layer or 0), tostring(line.style or ""), tostring(line.actor or ""), LineOps.visibleText(line.text)}, "\31"
        unless buckets[key]
          buckets[key] = {}
          order[#order + 1] = key
        buckets[key][#buckets[key] + 1] = {
          :index, :line, :position
          start_frame: aegisub.frame_from_ms(line.start_time)
          end_frame: exclusive_end_frame(line.start_time, line.end_time)
          signature: authored_signature line.text
        }
  tracks = {}
  for key in *order
    items = buckets[key]
    table.sort items, (a, b) -> if a.start_frame == b.start_frame then a.index < b.index else a.start_frame < b.start_frame
    current, previous_end = {}, nil
    for item in *items
      if #current > 0 and previous_end and item.start_frame > previous_end + 1
        tracks[#tracks + 1] = {key: key, items: current}
        current = {}
      current[#current + 1] = item
      previous_end = item.end_frame
    tracks[#tracks + 1] = {key: key, items: current} if #current > 0
  tracks

detect_authored_period = (track) ->
  count = #track.items
  return nil if count < 4
  signatures = [item.signature for item in *track.items]
  for period = 2, math.min(8, math.floor(count / 2))
    matches = true
    for index = period + 1, count
      if signatures[index] != signatures[index - period]
        matches = false
        break
    return period if matches and signatures[1] != signatures[2]
  frames = [item.start_frame for item in *track.items]
  xs = [item.position.x for item in *track.items]
  ys = [item.position.y for item in *track.items]
  fit_x, fit_y = linear_fit(frames, xs), linear_fit(frames, ys)
  return nil unless fit_x and fit_y
  residuals, magnitudes = {}, {}
  for index = 1, count
    point = {x: fit_x.residuals[index], y: fit_y.residuals[index]}
    residuals[index] = point
    magnitudes[index] = math.sqrt(point.x^2 + point.y^2)
  amplitude = percentile(magnitudes, 0.90) or 0
  return nil if amplitude < 0.35
  for period = 2, math.min(8, math.floor(count / 2))
    errors = {}
    for index = period + 1, count
      dx = residuals[index].x - residuals[index - period].x
      dy = residuals[index].y - residuals[index - period].y
      errors[#errors + 1] = math.sqrt(dx * dx + dy * dy)
    return period if (percentile(errors, 0.90) or math.huge) <= math.max(0.15, amplitude * 0.08)
  nil

phase_adjust_series = (values, frames, period) ->
  count = #values
  offsets = [0 for index = 1, math.max(1, period or 1)]
  unless period and period > 1
    copied = {}
    copied[index] = value for index, value in ipairs values
    return copied, offsets
  fit = linear_fit frames, values
  unless fit
    copied = {}
    copied[index] = value for index, value in ipairs values
    return copied, offsets
  groups = [{} for index = 1, period]
  for index = 1, count
    phase = (index - 1) % period + 1
    groups[phase][#groups[phase] + 1] = fit.residuals[index]
  offsets[phase] = median(groups[phase]) or 0 for phase = 1, period
  base = [values[index] - offsets[(index - 1) % period + 1] for index = 1, count]
  base, offsets

read_scalar = (text, name) ->
  pattern = if name == "frz" then "\\frz?([%+%-]?[%d%.]+)" else "\\#{name}([%+%-]?[%d%.]+)"
  tonumber tostring(text or "")\match pattern

set_scalar_text = (text, name, value) ->
  pattern = if name == "frz" then "(\\frz?)([%+%-]?[%d%.]+)" else "(\\#{name})([%+%-]?[%d%.]+)"
  replaced, count = tostring(text or "")\gsub pattern, (tag) -> tag .. format_number(value, 3), 1
  if count > 0 then replaced else text

refine_series = (values, frames, period, options) ->
  base, offsets = phase_adjust_series values, frames, period
  smooth = local_regression base, frames, options.window, options.degree
  residuals = [math.abs(base[index] - smooth[index]) for index = 1, #base]
  center = median residuals or 0
  threshold = math.max(tonumber(options.threshold) or 0.35, center + 3 * mad(residuals, center))
  strength = clamp((tonumber(options.strength) or 100) / 100, 0, 1)
  out = {}
  for index = 1, #base
    use = options.scope == "Whole track" or residuals[index] > threshold
    value = if use then base[index] + (smooth[index] - base[index]) * strength else base[index]
    phase = if period and period > 1 then (index - 1) % period + 1 else 1
    out[index] = value + (offsets[phase] or 0)
  out, threshold

refinery_report = (tracks) ->
  lines = {"Tracks: #{#tracks}", ""}
  for track_index, track in ipairs tracks
    period = detect_authored_period track
    steps = {}
    for index = 2, #track.items
      dx = track.items[index].position.x - track.items[index - 1].position.x
      dy = track.items[index].position.y - track.items[index - 1].position.y
      steps[#steps + 1] = math.sqrt(dx * dx + dy * dy)
    frames = [item.start_frame for item in *track.items]
    xs = [item.position.x for item in *track.items]
    ys = [item.position.y for item in *track.items]
    base_x = phase_adjust_series xs, frames, period
    base_y = phase_adjust_series ys, frames, period
    pseudo_samples = {}
    pseudo_samples[index] = {source_frame: frames[index], position: {x: base_x[index], y: base_y[index]}, scale: {x: 100, y: 100}, rotation: 0} for index = 1, #frames
    pseudo = {samples: pseudo_samples}
    candidate = phase_slip_candidate pseudo
    lines[#lines + 1] = "#{track_index}. #{#track.items} samples, frames #{frames[1]}..#{frames[#frames]}, median step #{format_number(median(steps) or 0, 3)}, authored period #{period or 'none'}."
    lines[#lines + 1] = "   Duplicate-frame candidate at sample #{candidate.index}." if candidate
  table.concat lines, "\n"

apply_refinery = (subs, tracks, options) ->
  changed, candidates = 0, 0
  for track in *tracks
    count = #track.items
    continue if count < 3
    frames = [item.start_frame for item in *track.items]
    xs = [item.position.x for item in *track.items]
    ys = [item.position.y for item in *track.items]
    period = options.protect_authored and detect_authored_period(track) or nil
    next_x, next_y = {}, {}
    next_x[index] = value for index, value in ipairs xs
    next_y[index] = value for index, value in ipairs ys
    if options.action == "Smooth / Denoise"
      next_x = refine_series xs, frames, period, options
      next_y = refine_series ys, frames, period, options
    elseif options.action == "Repair Duplicate Frame"
      base_x, offsets_x = phase_adjust_series xs, frames, period
      base_y, offsets_y = phase_adjust_series ys, frames, period
      pseudo_samples = {}
      pseudo_samples[index] = {source_frame: frames[index], position: {x: base_x[index], y: base_y[index]}, scale: {x: 100, y: 100}, rotation: 0} for index = 1, count
      pseudo = {samples: pseudo_samples}
      candidate = phase_slip_candidate pseudo
      if candidate
        candidates += 1
        repaired = repair_transform_phase pseudo, candidate, options.window, options.degree
        for index = 1, count
          phase = if period then (index - 1) % period + 1 else 1
          next_x[index] = repaired.samples[index].position.x + (offsets_x[phase] or 0)
          next_y[index] = repaired.samples[index].position.y + (offsets_y[phase] or 0)
    elseif options.action == "Retarget Start" or options.action == "Retarget End"
      side_start = options.action == "Retarget Start"
      anchor_index = side_start and 1 or count
      dx = (tonumber(options.target_x) or xs[anchor_index]) - xs[anchor_index]
      dy = (tonumber(options.target_y) or ys[anchor_index]) - ys[anchor_index]
      for index = 1, count
        t = (index - 1) / math.max(1, count - 1)
        weight = if side_start then 1 - (t * t * (3 - 2 * t)) else t * t * (3 - 2 * t)
        next_x[index] = xs[index] + dx * weight
        next_y[index] = ys[index] + dy * weight
    for index, item in ipairs track.items
      dx, dy = next_x[index] - xs[index], next_y[index] - ys[index]
      if math.abs(dx) > NUMERIC_EPSILON or math.abs(dy) > NUMERIC_EPSILON
        line = subs[item.index]
        text = set_position_text line.text, next_x[index], next_y[index]
        text = shift_linked_geometry text, dx, dy if options.linked_geometry
        line.text = text
        subs[item.index] = line
        changed += 1
    if options.include_transforms and options.action == "Smooth / Denoise"
      for name in *{"fscx", "fscy", "frz", "bord", "xbord", "ybord", "shad", "xshad", "yshad", "blur"}
        values = [read_scalar(item.line.text, name) for item in *track.items]
        complete = true
        complete = false for value in *values when not finite value
        continue unless complete
        refined = refine_series values, frames, period, options
        for index, item in ipairs track.items
          continue if math.abs(refined[index] - values[index]) <= NUMERIC_EPSILON
          line = subs[item.index]
          line.text = set_scalar_text line.text, name, refined[index]
          subs[item.index] = line
  changed, candidates

refinery_dialog = ->
  controls = {
    {class: "label", label: "Operation", x: 0, y: 0, width: 2, height: 1}
    {class: "dropdown", name: "action", items: {"Analyze", "Smooth / Denoise", "Repair Duplicate Frame", "Retarget Start", "Retarget End"}, value: "Analyze", x: 2, y: 0, width: 4, height: 1}
    {class: "label", label: "Scope", x: 6, y: 0, width: 1, height: 1}
    {class: "dropdown", name: "scope", items: {"Outliers only", "Whole track"}, value: "Outliers only", x: 7, y: 0, width: 3, height: 1}
    {class: "label", label: "Window", x: 0, y: 1, width: 1, height: 1}
    {class: "intedit", name: "window", value: 9, min: 3, max: 99, x: 1, y: 1, width: 1, height: 1}
    {class: "label", label: "Degree", x: 2, y: 1, width: 1, height: 1}
    {class: "intedit", name: "degree", value: 2, min: 1, max: 3, x: 3, y: 1, width: 1, height: 1}
    {class: "label", label: "Strength %", x: 4, y: 1, width: 2, height: 1}
    {class: "floatedit", name: "strength", value: 100, min: 0, max: 100, x: 6, y: 1, width: 1, height: 1}
    {class: "label", label: "Min residual", x: 7, y: 1, width: 2, height: 1}
    {class: "floatedit", name: "threshold", value: 0.35, min: 0, x: 9, y: 1, width: 1, height: 1}
    {class: "checkbox", name: "protect_authored", label: "Preserve authored zig-zag / cycles", value: true, x: 0, y: 2, width: 4, height: 1}
    {class: "checkbox", name: "linked_geometry", label: "Shift linked \\org and clips", value: true, x: 4, y: 2, width: 3, height: 1}
    {class: "checkbox", name: "include_transforms", label: "Smooth scale / rotation / styling geometry", value: false, x: 7, y: 2, width: 5, height: 1}
    {class: "label", label: "Target X", x: 0, y: 3, width: 1, height: 1}
    {class: "floatedit", name: "target_x", value: 0, x: 1, y: 3, width: 2, height: 1}
    {class: "label", label: "Target Y", x: 3, y: 3, width: 1, height: 1}
    {class: "floatedit", name: "target_y", value: 0, x: 4, y: 3, width: 2, height: 1}
  }
  pressed, values = aegisub.dialog.display controls, {"Execute", "Cancel"}, {ok: "Execute", close: "Cancel"}
  if pressed == "Execute" then values else nil

refinery_main = (subs, sel, active) ->
  tracks = build_refinery_tracks subs, sel
  if #tracks == 0
    show_message "Moka Motion / Track Refinery", "Select contiguous FBF dialogue lines containing \\pos."
    return sel
  options = refinery_dialog!
  return sel unless options
  if options.action == "Analyze"
    show_message "Moka Motion / Track Refinery", refinery_report(tracks), 20
    return sel
  changed, candidates = apply_refinery subs, tracks, options
  if changed > 0
    aegisub.set_undo_point "#{script_name}: Track Refinery / #{options.action}"
  message = "#{options.action}: #{changed} lines changed."
  message ..= " Duplicate-frame candidates repaired: #{candidates}." if options.action == "Repair Duplicate Frame"
  show_message "Moka Motion / Track Refinery", message, 6
  sel

Core.build_refinery_tracks = build_refinery_tracks
Core.detect_authored_period = detect_authored_period
Core.apply_refinery = apply_refinery

path_parts = (path) ->
  directory, name = tostring(path or "")\match "^(.*)[\\/]([^\\/]+)$"
  directory or= "."
  name or= tostring(path or "")
  stem = name\gsub "%.[^%.]+$", ""
  directory, stem

TRIM_SETTINGS_DEFAULTS = {
  encoders: {
    x264: ""
    ffmpeg: ""
  }
}

trim_settings_store = nil

encoder_settings = ->
  trim_settings_store or= KiteUI.settings script_namespace, script_version, TRIM_SETTINGS_DEFAULTS
  trim_settings_store\values "encoders"

encoder_command = (value, fallback) ->
  value = trim value
  if value == "" then fallback else value

trim_settings_main = ->
  settings = encoder_settings!
  controls = {
    {class: "label", label: "Leave a field blank to resolve that encoder from PATH.", x: 0, y: 0, width: 10, height: 1}
    {class: "label", label: "x264", x: 0, y: 1, width: 1, height: 1}
    {class: "edit", name: "x264", value: settings.x264, x: 1, y: 1, width: 9, height: 1}
    {class: "label", label: "FFmpeg", x: 0, y: 2, width: 1, height: 1}
    {class: "edit", name: "ffmpeg", value: settings.ffmpeg, x: 1, y: 2, width: 9, height: 1}
  }
  while true
    button, values = aegisub.dialog.display controls, {"Save", "x264...", "FFmpeg...", "Cancel"}, {ok: "Save", close: "Cancel"}
    return unless button and button != "Cancel"
    controls[3].value = values.x264
    controls[5].value = values.ffmpeg
    if button == "x264..." or button == "FFmpeg..."
      chosen = aegisub.dialog.open "Choose #{button == 'x264...' and 'x264' or 'FFmpeg'}", "", "", "Executable (*.exe)|*.exe|All files (*.*)|*.*", false, true
      if chosen
        if button == "x264..."
          controls[3].value = chosen
        else
          controls[5].value = chosen
      continue
    trim_settings_store\update "encoders", values
    ok, err = trim_settings_store\write!
    show_message script_name, ok and "Encoder settings saved." or "Could not save encoder settings:\n#{err}", 5
    return

powershell_literal = (value) ->
  "'" .. tostring(value or "")\gsub("'", "''") .. "'"

trim_paths = (source, window, temp_root) ->
  directory, stem = path_parts source
  end_frame = window.end_frame - 1
  suffix = "[#{window.start_frame}-#{end_frame}]"
  temp_root = trim(temp_root) != "" and temp_root or PyBridge.tempRoot!
  token = "#{stem\gsub '[^%w_.-]', '_'}_#{window.start_frame}_#{end_frame}_#{PyBridge.uniqueSuffix!}"
  {
    output: PyBridge.joinPath directory, stem .. suffix .. ".mp4"
    index: PyBridge.joinPath temp_root, token .. ".lavf.index"
    temp_mkv: PyBridge.joinPath temp_root, token .. ".mkv"
    log: PyBridge.joinPath temp_root, token .. ".log"
  }

build_trim_commands = (source, window, paths, settings) ->
  fps = Media.frameRateArgument window.start_frame, window.end_frame
  x264_args = {"--crf", "16", "--tune", "fastdecode"}
  if fps
    table.insert x264_args, "--fps"
    table.insert x264_args, fps
  for value in *{
    "-i", "250", "--sar", "1:1", "--index", paths.index
    "--seek", tostring(window.start_frame), "--frames", tostring(window.frame_count)
    "--muxer", "mkv", "-o", paths.temp_mkv, source
  }
    table.insert x264_args, value
  {
    x264: {
      executable: encoder_command settings.x264, "x264"
      args: x264_args
    }
    ffmpeg: {
      executable: encoder_command settings.ffmpeg, "ffmpeg"
      args: {"-hide_banner", "-nostdin", "-loglevel", "warning", "-y", "-i", paths.temp_mkv, "-map", "0:v:0", "-c", "copy", "-movflags", "+faststart", paths.output}
    }
    fps: fps
  }

powershell_arguments = (arguments) ->
  table.concat [powershell_literal(value) for value in *arguments], " "

build_trim_powershell = (source, window, paths, settings) ->
  commands = build_trim_commands source, window, paths, settings
  parts = {
    "$x264 = #{powershell_literal commands.x264.executable}"
    "$ffmpeg = #{powershell_literal commands.ffmpeg.executable}"
    "$tempMkv = #{powershell_literal paths.temp_mkv}"
    "$log = #{powershell_literal paths.log}"
    "Remove-Item -LiteralPath $tempMkv -Force -ErrorAction SilentlyContinue"
    "Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue"
    "if (-not (Get-Command $x264 -ErrorAction SilentlyContinue)) { \"Encoder not found: $x264\" | Out-File -LiteralPath $log -Encoding UTF8; exit 1 }"
    "if (-not (Get-Command $ffmpeg -ErrorAction SilentlyContinue)) { \"Encoder not found: $ffmpeg\" | Out-File -LiteralPath $log -Encoding UTF8; exit 1 }"
    "& $x264 #{powershell_arguments commands.x264.args} 2>&1 | Out-File -LiteralPath $log -Encoding UTF8"
    "if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }"
    "& $ffmpeg #{powershell_arguments commands.ffmpeg.args} 2>&1 | Out-File -LiteralPath $log -Encoding UTF8 -Append"
    "if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }"
    "Remove-Item -LiteralPath $tempMkv -Force"
    "Remove-Item -LiteralPath #{powershell_literal paths.index} -Force -ErrorAction SilentlyContinue"
    "exit 0"
  }
  table.concat parts, "; "

video_trim_main = (subs, sel, active) ->
  window, err = selection_window subs, sel
  unless window
    show_message script_name, err
    return sel
  source = Media.projectPath "video"
  unless source
    show_message script_name, "Aegisub has no readable local video path."
    return sel
  paths = trim_paths source, window, PyBridge.tempRoot!
  unless paths.temp_mkv and paths.log
    show_message script_name, "The temporary directory is unavailable."
    return sel
  settings = encoder_settings!
  commands = build_trim_commands source, window, paths, settings
  PyBridge.cleanup {paths.temp_mkv, paths.index, paths.log}
  PyBridge.removeFile paths.output
  aegisub.progress.task "Encoding #{window.frame_count} frames with x264..."
  ok_x264, x264_output = PyBridge.run PyBridge.commandLine(commands.x264.executable, commands.x264.args)
  PyBridge.removeFile paths.index
  log_parts = {"x264:\n#{x264_output or ''}"}
  unless ok_x264 and (Media.fileSize(paths.temp_mkv) or 0) > 0
    PyBridge.removeFile paths.temp_mkv
    PyBridge.writeFile paths.log, table.concat(log_parts, "\n\n")
    show_message script_name, "x264 failed. The diagnostic log was kept for inspection.\n\n#{x264_output or ''}\n#{paths.log}", 14
    return sel
  aegisub.progress.task "Remuxing the frame-exact clip..."
  ok_ffmpeg, ffmpeg_output = PyBridge.run PyBridge.commandLine(commands.ffmpeg.executable, commands.ffmpeg.args)
  log_parts[#log_parts + 1] = "ffmpeg:\n#{ffmpeg_output or ''}"
  PyBridge.writeFile paths.log, table.concat(log_parts, "\n\n")
  if ok_ffmpeg and (Media.fileSize(paths.output) or 0) > 0
    PyBridge.removeFile paths.temp_mkv
    PyBridge.removeFile paths.log
    show_message script_name, "Created #{window.frame_count}-frame MP4 for source frames #{window.start_frame}..#{window.end_frame - 1}.\n#{paths.output}", 7
  else
    show_message script_name, "FFmpeg failed. The diagnostic log and intermediate MKV were kept for inspection.\n\n#{ffmpeg_output or ''}\n#{paths.log}", 14
  sel

exact_png_main = (subs, sel, active) ->
  window, err = selection_window subs, sel
  unless window
    show_message script_name, err
    return sel
  source = Media.projectPath "video"
  unless source
    show_message script_name, "Aegisub has no readable local video path."
    return sel
  destination = aegisub.dialog.save "Choose a name for the PNG sequence", "", "moka_sequence.png", "PNG (*.png)|*.png", false
  return sel unless destination and destination != ""
  directory, stem = path_parts destination
  folder = PyBridge.joinPath directory, stem .. "_frames"
  made, mkdir_error = PyBridge.ensureDir folder
  unless made
    show_message script_name, "Could not create #{folder}: #{mkdir_error}"
    return sel
  output = PyBridge.joinPath folder, "frame_%08d.png"
  for frame = window.start_frame, window.end_frame - 1
    PyBridge.removeFile PyBridge.joinPath(folder, string.format("frame_%08d.png", frame))
  filter = "trim=start_frame=#{window.start_frame}:end_frame=#{window.end_frame},setpts=PTS-STARTPTS"
  ffmpeg_args = {
    "-hide_banner", "-nostdin", "-loglevel", "warning", "-y", "-i", source, "-map", "0:v:0", "-an"
    "-vf", filter, "-fps_mode", "passthrough", "-start_number", tostring(window.start_frame), "-compression_level", "3", output
  }
  aegisub.progress.task "Decoding #{window.frame_count} exact frames..."
  ok, diagnostic = PyBridge.run PyBridge.commandLine(encoder_command(encoder_settings!.ffmpeg, "ffmpeg"), ffmpeg_args)
  unless ok
    show_message script_name, "FFmpeg failed. The partial folder was kept for inspection.\n\n#{diagnostic or ''}\n#{folder}", 12
    return sel
  count, missing, invalid = 0, {}, {}
  for frame = window.start_frame, window.end_frame - 1
    name = string.format "frame_%08d.png", frame
    path = PyBridge.joinPath folder, name
    valid, reason = Media.verifyPng path
    if valid
      count += 1
    elseif reason == "missing"
      missing[#missing + 1] = name
    else
      invalid[#invalid + 1] = name
    aegisub.progress.set 100 * (frame - window.start_frame + 1) / window.frame_count if aegisub.progress and aegisub.progress.set
  if #missing > 0 or #invalid > 0
    message = "The sequence is incomplete: #{count}/#{window.frame_count} valid PNG files."
    message ..= "\nMissing: #{table.concat missing, ', '}." if #missing > 0
    message ..= "\nInvalid PNG: #{table.concat invalid, ', '}." if #invalid > 0
    message ..= "\n#{folder}"
    show_message script_name, message, 10
    return sel
  show_message script_name, "Created and verified #{count} PNG files for source frames #{window.start_frame}..#{window.end_frame - 1}.\n#{folder}", 7
  sel

validate_selection = (subs, sel) -> sel and #sel > 0
menu_path = (suffix) -> "#{script_name}/#{suffix}"

macros = {
  {menu_path("Motion/Apply Motion"), "Apply one Mocha Transform track to selected lines, including FBF authored motion.", motion_main(false), validate_selection}
  {menu_path("Motion/Revert Motion"), "Mathematically invert one application using the same Transform data; no stored snapshots are required.", motion_main(true), validate_selection}
  {menu_path("Shapes/Create Clip"), "Convert Mocha mask or shape data to animated ASS \\clip.", shape_main("clip"), validate_selection}
  {menu_path("Shapes/Create Inverse Clip"), "Convert Mocha mask or shape data to animated ASS \\iclip.", shape_main("iclip"), validate_selection}
  {menu_path("Shapes/Create Vector Drawing"), "Convert Mocha mask or shape data to animated ASS vector drawings.", shape_main("shape"), validate_selection}
  {menu_path("Perspective/Apply Power Pin"), "Apply Mocha CC Power Pin or Corner Pin data to selected lines and clips.", powerpin_main, validate_selection}
  {menu_path("Track Refinery"), "Analyze, denoise, repair duplicate frames, or retarget selected FBF tracks.", refinery_main, validate_selection}
  {menu_path("Utilities/Inspect Mocha Data"), "Identify supported Mocha export data and inspect continuity problems.", inspect_main}
  {menu_path("Utilities/Create Video Clip"), "Create a frame-exact H.264 MP4 through x264 and FFmpeg.", video_trim_main, validate_selection}
  {menu_path("Utilities/Create Exact PNG Sequence"), "Create a frame-indexed PNG sequence for Mocha without an H.264 trim.", exact_png_main, validate_selection}
  {menu_path("Utilities/Trim Settings"), "Configure x264 and FFmpeg paths; blank fields use PATH.", trim_settings_main}
}
for macro in *macros
  depctrl\registerMacro macro[1], macro[2], macro[3], macro[4], nil, false

Core.DEFAULTS = DEFAULTS
Core.parse_input = parse_input
Core.motion_main = motion_main
Core.shape_main = shape_main
Core.powerpin_main = powerpin_main
Core.refinery_main = refinery_main
Core.inspect_main = inspect_main
Core.encoder_command = encoder_command
Core.trim_paths = trim_paths
Core.build_trim_commands = build_trim_commands
Core.build_trim_powershell = build_trim_powershell

return Core
