export script_name = "Moka Motion"
export script_description = "Unified Mocha motion, shape, clip, perspective and FBF track tools"
export script_author = "Kiterow"
export script_version = "3.7.6"
export script_namespace = "kite.MokaMotion"

local depctrl, LineCollection, ASS, AMath, APersp, ArchUtil, Tags, ZF, KiteUI, PyBridge, Media, LineOps, KiteCore, FBFOptimizer, clipboard
local Point, Matrix, Quad, an_xshift, an_yshift, relevantTags, usedTags
local transformPoints, tagsFromQuad, prepareForPerspective
local ShiftFrameKaraoke

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
    {"kite.UI", version: "1.5.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.PyBridge", version: "1.7.2", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.Media", version: "1.4.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.LineOps", version: "1.7.2", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.Core", version: "1.1.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    "aegisub.clipboard"
    {"kite.AssContext", version: "1.1.1"}
    {"kite.AssDrawing", version: "1.0.3"}
  }
}
LineCollection, Tags, ASS, AMath, APersp, ArchUtil, ZF, KiteUI, PyBridge, Media, LineOps, KiteCore, clipboard = depctrl\requireModules!
AssContext = require "kite.AssContext"
FBFOptimizer = {}
{:Point, :Matrix} = AMath
{:Quad, :an_xshift, :an_yshift, :relevantTags, :usedTags, :transformPoints, :tagsFromQuad, :prepareForPerspective} = APersp

Core = {}
Core.api_version = 1
Core.ApiVersion = Core.api_version
Core.VERSION = script_version
Core.version = script_version

numericEpsilon = 0.0000001
geometryEpsilon = 0.000001
scaleEpsilon = 0.000000001
singularEpsilon = 0.000000000001

DEFAULTS = {
  sample_start: 1
  reference_frame: 1
  strict_sync: false
  optimize_linear: true
  optimize_fbf: false
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

trim = KiteCore.trim

finite = (value) -> KiteCore.finiteNumber(value) != nil

clamp = KiteCore.clamp

FormatNumber = (value, decimals = 2) -> KiteCore.formatNumber value, decimals

CopyTable = (source) ->
  out = {}
  out[k] = v for k, v in pairs source or {}
  out

CopyLine = (line) ->
  out = CopyTable line
  out.extra = CopyTable(line.extra) if type(line.extra) == "table"
  out

AcceptDialogueLine = (line) -> not line.comment
AcceptAllLines = -> true

ParseNumbers = (text) ->
  out = {}
  for value in tostring(text or "")\gmatch NUM_PATTERN
    number = tonumber value
    out[#out + 1] = number if number
  out

SplitLines = (text) ->
  out = {}
  text = tostring(text or "")\gsub "^\239\187\191", ""
  text = text\gsub "\r\n", "\n"
  text = text\gsub "\r", "\n"
  for line in (text .. "\n")\gmatch "([^\n]*)\n"
    out[#out + 1] = line
  out

ParseMeta = (input) ->
  text, result = tostring(input or ""), {}
  fields = {fps: "Units Per Second", source_width: "Source Width", source_height: "Source Height", source_par: "Source Pixel Aspect Ratio", comp_par: "Comp Pixel Aspect Ratio"}
  for key, label in pairs fields
    value = KiteCore.finiteNumber text\match(label .. "%s+(%S+)")
    result[key] = value if value and value > 0
  result

sectionNames = {
  ["position"]: "position"
  ["scale"]: "scale"
  ["rotation"]: "rotation"
  ["anchor point"]: "anchor"
  ["opacity"]: "opacity"
}

PinKey = (line) ->
  line = line\gsub "^Effects%s+ADBE%s+", "Effects "
  line = line\gsub "(#1)%s+ADBE%s+", "%1 "
  marker = line\match "^Effects%s+CC Power Pin #1%s+CC Power Pin%-([%d]+)%s*$"
  return "pin_#{marker}" if marker
  marker = line\match "^Effects%s+Corner Pin #1%s+Corner Pin%-([%d]+)%s*$"
  marker and "corner_#{marker}" or nil

AddRow = (section, frame, values, line_number) ->
  return nil, "Non-finite or non-integer frame on line #{line_number}: #{frame}" unless finite(frame) and frame == math.floor(frame) and frame + 1 > frame and frame - 1 < frame
  if section.by_frame[frame]
    return nil, "Duplicate frame #{frame} in #{section.name} (line #{line_number})."
  row = {frame: frame, values: values, line_number: line_number}
  section.by_frame[frame] = row
  section.rows[#section.rows + 1] = row
  true

ParseKeyframeSections = (input) ->
  sections = {}
  diagnostics = {}
  unknown = {}
  NoteUnknown = (label) ->
    return if unknown[label]
    unknown[label] = true
    diagnostics[#diagnostics + 1] = "Unrecognized AE channel/section: #{label}."
  current = nil
  for line_number, raw in ipairs SplitLines input
    stripped = trim raw
    lower = stripped\lower!
    name = sectionNames[lower] or PinKey stripped
    if name
      sections[name] or= {name: name, rows: {}, by_frame: {}}
      current = sections[name]
      continue
    if current and raw\match "^%s+"
      if stripped\match "^[%+%-]?[%d%.]"
        values = {}
        for token in stripped\gmatch "%S+"
          number = KiteCore.finiteNumber token
          return nil, "Invalid numeric value on line #{line_number}: #{token}" unless number
          values[#values + 1] = number
        return nil, "Missing channel values on line #{line_number}." if #values < 2
        frame = values[1]
        rowValues = [values[i] for i = 2, #values]
        ok, err = AddRow current, frame, rowValues, line_number
        return nil, err unless ok
      continue
    if stripped != "" and not raw\match("^%s+")
      allowedHeader = lower == "end of keyframe data" or lower\match("^adobe after effects") or lower\match("^units per second") or lower\match("^source width") or lower\match("^source height") or lower\match("^source pixel aspect ratio") or lower\match("^comp pixel aspect ratio")
      if not allowedHeader and (stripped\match("^Effects%s+") or stripped\match("^[%a][%a%s]+$"))
        NoteUnknown stripped
    current = nil if stripped != ""
  for _, section in pairs sections
    table.sort section.rows, (a, b) -> a.frame < b.frame
  sections, nil, diagnostics

RequireSectionArity = (section, count, label) ->
  return true unless section
  for row in *section.rows
    return nil, "#{label}, frame #{row.frame}: expected #{count} values, received #{#row.values}." if #row.values < count
    for i = 1, count
      return nil, "#{label}, frame #{row.frame}: value #{i} is not finite." unless finite row.values[i]
  true

AllFrames = (sections, names) ->
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

InterpolatedValues = (section, frame, defaults) ->
  return CopyTable defaults, false unless section and #section.rows > 0
  exact = section.by_frame[frame]
  return exact.values, false if exact
  low, high = 1, #section.rows + 1
  while low < high
    middle = math.floor((low + high) / 2)
    if section.rows[middle].frame < frame then low = middle + 1 else high = middle
  before, after = section.rows[low - 1], section.rows[low]
  return (before or after).values, true unless before and after
  k = (frame - before.frame) / (after.frame - before.frame)
  count = math.max #before.values, #after.values, #defaults
  values = {}
  for i = 1, count
    a = before.values[i] or defaults[i] or 0
    b = after.values[i] or defaults[i] or a
    values[i] = a + (b - a) * k
  values, true

UnwrapAngles = (values) ->
  out = {}
  return out if #values == 0
  out[1] = values[1]
  for i = 2, #values
    LineOps.checkCancelled!
    value, previous = values[i], out[i - 1]
    delta = value - previous
    if delta > 180 then value -= math.ceil((delta - 180) / 360) * 360
    elseif delta < -180 then value += math.ceil((-180 - delta) / 360) * 360
    out[i] = value
  out

UnwrapRotationSection = (section) ->
  return nil unless section
  out = {name: section.name, rows: {}, by_frame: {}}
  diagnostics = {}
  cumulative = false
  for row in *section.rows
    value = row.values[1] or 0
    if value < -180 or value > 360
      cumulative = true
      break
  offset, previousRaw = 0, nil
  for i, row in ipairs section.rows
    rawAngle = row.values[1] or 0
    angle = rawAngle
    if not cumulative and previousRaw != nil
      delta = rawAngle - previousRaw
      turns = math.floor(math.abs(delta) / 360 + 0.5)
      explicitTurn = turns >= 1 and math.abs(math.abs(delta) - turns * 360) <= geometryEpsilon
      if previousRaw >= 135 and rawAngle <= -135
        offset += 360
      elseif previousRaw <= -135 and rawAngle >= 135
        offset -= 360
      elseif previousRaw >= 315 and rawAngle <= 45
        offset += 360
      elseif not explicitTurn and math.abs(delta) > 180
        diagnostics[#diagnostics + 1] = "Rotation #{row.frame}: ambiguous #{FormatNumber(delta, 3)} degree jump preserved without shortest-path wrapping."
        out.ambiguous or= {}
        out.ambiguous[row.frame] = delta
      angle = rawAngle + offset
    values = [value for value in *row.values]
    values[1] = angle
    copy = {frame: row.frame, :values, line_number: row.line_number}
    out.rows[i] = copy
    out.by_frame[copy.frame] = copy
    previousRaw = rawAngle
  diagnostics[#diagnostics + 1] = "Cumulative rotation detected; complete revolutions are preserved." if cumulative
  out, diagnostics

ParseTransformData = (input) ->
  sections, err, parseDiagnostics = ParseKeyframeSections input
  return nil, err unless sections
  return nil, "No Position, Scale, or Rotation section was found." unless sections.position or sections.scale or sections.rotation
  for check in *{
    {sections.position, 2, "Position"}
    {sections.scale, 1, "Scale"}
    {sections.rotation, 1, "Rotation"}
    {sections.anchor, 2, "Anchor Point"}
    {sections.opacity, 1, "Opacity"}
  }
    ok, err = RequireSectionArity check[1], check[2], check[3]
    return nil, err unless ok
  uniform_scale_rows = 0
  if sections.scale
    for row in *sections.scale.rows
      if row.values[2] == nil
        row.values[2] = row.values[1]
        uniform_scale_rows += 1
  meta = ParseMeta input
  frames = AllFrames sections, {"position", "scale", "rotation", "anchor", "opacity"}
  return nil, "The tracking sections contain no numeric samples." if #frames == 0
  first_frame, last_frame = frames[1], frames[#frames]
  diagnostics, samples, had_gap = {}, {}, false
  diagnostics[#diagnostics + 1] = item for item in *parseDiagnostics or {}
  diagnostics[#diagnostics + 1] = "#{uniform_scale_rows} uniform Scale rows were expanded to X/Y." if uniform_scale_rows > 0
  rotation_section, rotationDiagnostics = UnwrapRotationSection sections.rotation
  diagnostics[#diagnostics + 1] = item for item in *rotationDiagnostics or {}
  defaultX = (meta.source_width or 0) / 2
  defaultY = (meta.source_height or 0) / 2
  diagnostics[#diagnostics + 1] = "Position is missing; the source center is used as the pivot." unless sections.position
  for frame = first_frame, last_frame
    LineOps.checkCancelled!
    position, posGap = InterpolatedValues sections.position, frame, {defaultX, defaultY, 0}
    scale, scaleGap = InterpolatedValues sections.scale, frame, {100, 100, 100}
    rotation, rotGap = InterpolatedValues rotation_section, frame, {0}
    anchor, anchorGap = InterpolatedValues sections.anchor, frame, {0, 0, 0}
    opacity, opacityGap = InterpolatedValues sections.opacity, frame, {100}
    gaps = {}
    gaps[#gaps + 1] = "Position" if sections.position and posGap
    gaps[#gaps + 1] = "Scale" if sections.scale and scaleGap
    gaps[#gaps + 1] = "Rotation" if sections.rotation and rotGap
    gaps[#gaps + 1] = "Anchor Point" if sections.anchor and anchorGap
    gaps[#gaps + 1] = "Opacity" if sections.opacity and opacityGap
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

ParsePowerPinData = (input) ->
  sections, err, parseDiagnostics = ParseKeyframeSections input
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
    ok, err = RequireSectionArity sections[name], 2, name
    return nil, err unless ok
  frames = AllFrames sections, order
  return nil, "Power Pin data contains no numeric samples." if #frames == 0
  first_frame, last_frame = frames[1], frames[#frames]
  samples, diagnostics = {}, {}
  diagnostics[#diagnostics + 1] = item for item in *parseDiagnostics or {}
  used = {name, true for name in *order}
  for name in pairs sections
    if (name\match("^pin_") or name\match("^corner_")) and not used[name]
      diagnostics[#diagnostics + 1] = "Additional parameter #{name} was detected; it is reported but not applied to ASS."
  for frame = first_frame, last_frame
    LineOps.checkCancelled!
    quad = {}
    missing = {}
    for name in *order
      values, gap = InterpolatedValues sections[name], frame, {0, 0}
      missing[#missing + 1] = name if gap
      quad[#quad + 1] = {x: values[1], y: values[2]}
    diagnostics[#diagnostics + 1] = "Frame #{frame} was interpolated in #{table.concat missing, ', '}." if #missing > 0
    samples[#samples + 1] = {source_frame: frame, quad: quad, interpolated: #missing > 0}
  {
    kind: "perspective"
    :format
    meta: ParseMeta(input)
    :samples
    :diagnostics
    first_frame: first_frame
    last_frame: last_frame
    has_interpolation: #diagnostics > 0
  }

FindBalanced = (text, startPos, openChar, closeChar) ->
  depth = 0
  for i = startPos, #text
    ch = text\sub i, i
    if ch == openChar
      depth += 1
    elseif ch == closeChar
      depth -= 1
      return text\sub(startPos, i), i if depth == 0
  nil, nil

ExtractLabeledArray = (block, label) ->
  labelPos = block\find label, 1, true
  return nil unless labelPos
  startPos = block\find "[", labelPos, true
  return nil unless startPos
  array = FindBalanced block, startPos, "[", "]"
  array

ParsePairArray = (arrayText) ->
  points = {}
  return points unless arrayText
  pattern = "%[%s*(#{NUM_PATTERN})%s*,%s*(#{NUM_PATTERN})%s*%]"
  for x, y in arrayText\gmatch pattern
    points[#points + 1] = {x: tonumber(x), y: tonumber(y)}
  points

FrameFromPrefix = (prefix) ->
  frame = nil
  for line in tostring(prefix or "")\gmatch "[^\r\n]+"
    value = line\match "^%s*([%-]?%d+)%s"
    frame = tonumber value if value
  frame

ParseShapeBlock = (block, frame, source_index) ->
  verticesRaw = ExtractLabeledArray block, "vertices"
  inRaw = ExtractLabeledArray block, "inTangents"
  outRaw = ExtractLabeledArray block, "outTangents"
  vertices = ParsePairArray verticesRaw
  inTangents = ParsePairArray inRaw
  outTangents = ParsePairArray outRaw
  return nil, "Shape #{source_index} contains no vertices." if #vertices < 2
  return nil, "Shape #{source_index}: incomplete inTangents." if inRaw and #inTangents != #vertices
  return nil, "Shape #{source_index}: incomplete outTangents." if outRaw and #outTangents != #vertices
  closedRaw = block\match "[\"']?closed[\"']?%s*[:=]%s*(%a+)"
  closed = not (closedRaw and closedRaw\lower! == "false")
  points = {}
  for i, vertex in ipairs vertices
    in_t = inTangents[i] or {x: 0, y: 0}
    out_t = outTangents[i] or {x: 0, y: 0}
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

ParseBezierPointBlock = (body, frame, source_index, closed) ->
  points = {}
  for raw in tostring(body or "")\gmatch "Point%(([^%)]*)%)"
    values = ParseNumbers raw
    if #values >= 2
      return nil, "Bezier #{source_index}: non-finite value." unless finite(values[1]) and finite(values[2])
      points[#points + 1] = {
        x: values[1], y: values[2]
        inx: 0, iny: 0, outx: 0, outy: 0
        normalized: true, y_up: true
      }
  return nil, "Bezier #{source_index} contains no points." if #points < 2
  {id: "bezier_#{source_index}", frame: frame, :closed, :points, source_index: source_index, legacy_bezier: true}

ParseLegacyBezierData = (input) ->
  text, masks, pos, source_index = tostring(input or ""), {}, 1, 0
  while true
    bezierPos = text\find "Bezier", pos, true
    break unless bezierPos
    openPos = text\find "(", bezierPos, true
    break unless openPos
    block, blockEnd = FindBalanced text, openPos, "(", ")"
    break unless block and blockEnd
    source_index += 1
    prefix = text\sub pos, bezierPos - 1
    nextBezier = text\find "Bezier", blockEnd + 1, true
    suffix = text\sub blockEnd + 1, nextBezier and nextBezier - 1 or #text
    frame = FrameFromPrefix(prefix) or source_index - 1
    closed = tostring(suffix\match("<Open>%s*(%d+)%s*</Open>") or "0") != "1"
    shape, err = ParseBezierPointBlock block\sub(2, -2), frame, source_index, closed
    return nil, err unless shape
    masks[#masks + 1] = shape
    pos = blockEnd + 1
  return nil if #masks == 0
  masks

ExpandSparseShapeSamples = (samples, diagnostics) ->
  return samples if #samples < 2
  first_frame, last_frame = samples[1].source_frame, samples[#samples].source_frame
  return samples if last_frame - first_frame + 1 == #samples
  by_frame = {sample.source_frame, sample for sample in *samples}
  out, held, held_count = {}, nil, 0
  for frame = first_frame, last_frame
    LineOps.checkCancelled!
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

ParseShapeData = (input) ->
  text, masks, pos, source_index = tostring(input or ""), {}, 1, 0
  while true
    shapePos = text\find "Shape", pos, true
    break unless shapePos
    bracePos = text\find "{", shapePos, true
    break unless bracePos
    block, blockEnd = FindBalanced text, bracePos, "{", "}"
    break unless block and blockEnd
    if block\find "vertices", 1, true
      source_index += 1
      prefix = text\sub pos, bracePos - 1
      frame = FrameFromPrefix(prefix) or 0
      shape, err = ParseShapeBlock block, frame, source_index
      return nil, err unless shape
      masks[#masks + 1] = shape
    pos = blockEnd + 1
  if #masks == 0 and text\find("vertices", 1, true)
    shape, err = ParseShapeBlock text, 0, 1
    return nil, err unless shape
    masks[1] = shape
  if #masks == 0
    masks, err = ParseLegacyBezierData text
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
  lowerText = text\lower!
  for label in *{"featherseg", "featherradii", "featherinterps", "feathertensions", "feathertypes", "mask feather", "mask opacity", "mask expansion", "mask mode", "inverted"}
    unsupported_shape_fields[#unsupported_shape_fields + 1] = label if lowerText\find(label, 1, true)
  if #unsupported_shape_fields > 0
    diagnostics[#diagnostics + 1] = "AE Mask fields not representable by one ASS clip: #{table.concat unsupported_shape_fields, ', '}."
  samples = [{source_frame: frame, masks: by_frame[frame]} for frame in *frames]
  samples = ExpandSparseShapeSamples samples, diagnostics
  {
    kind: "shape"
    format: "Adobe After Effects Mask Data"
    meta: ParseMeta(input)
    :samples
    :diagnostics
    first_frame: samples[1].source_frame
    last_frame: samples[#samples].source_frame
    sparse: frames[#frames] - frames[1] + 1 != #frames
  }

StripQuotes = (value) ->
  value = trim value
  quoted = value\match '^"(.*)"$' or value\match "^'(.*)'$"
  quoted or value

ShakePointsFromValues = (values, expected_vertices = nil) ->
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
      if math.abs(value) > numericEpsilon
        has_edge = true
        break
  points, edge_points, has_edge

ShakeMaskFromKey = (shape, key, points = key.points, edge_points = key.edge_points) ->
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

InterpolateShakeMask = (shape, before, after, frame) ->
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
  ShakeMaskFromKey shape, before, points, before.edge_points

BuildShakeTrack = (shapes, meta, diagnostics) ->
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
    LineOps.checkCancelled!
    masks, sample_approx = {}, false
    for shape in *shapes
      continue if shape.visible == false
      key = shape.keys[frame]
      mask = ShakeMaskFromKey(shape, key) if key
      unless mask
        before, after = nil, nil
        for keyFrame in *shape.key_order
          candidate = shape.keys[keyFrame]
          if keyFrame < frame
            before = candidate
          elseif keyFrame > frame
            after = candidate
            break
        mask = InterpolateShakeMask shape, before, after, frame
        unless mask
          held = before or after
          mask = ShakeMaskFromKey(shape, held) if held
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

ParseLegacyShakeLayout = (input, num_shapes, meta, diagnostics) ->
  rows = {}
  for raw in *SplitLines input
    if raw\find "vertex_data", 1, true
      values = ParseNumbers raw\match("vertex_data%s+(.*)") or ""
      points, edge_points, has_edge, err = ShakePointsFromValues values
      return nil, err unless points
      rows[#rows + 1] = {:points, :edge_points, :has_edge}
  return nil, "Shake SSF contains no vertex_data." if #rows == 0
  return nil, "#{#rows} vertex_data blocks cannot be divided evenly among #{num_shapes} shapes." if #rows % num_shapes != 0
  length = #rows / num_shapes
  samples, edgeSeen = {}, false
  for frame_index = 1, length
    masks = {}
    for shape_index = 1, num_shapes
      row = rows[(shape_index - 1) * length + frame_index]
      edgeSeen or= row.has_edge
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
  diagnostics[#diagnostics + 1] = "Auxiliary edge/feather data was read; one ASS clip cannot represent it faithfully." if edgeSeen
  {
    kind: "shape"
    format: "Shake RotoShape SSF 4.0 (legacy layout)"
    :meta, :samples, :diagnostics
    first_frame: 0
    last_frame: length - 1
  }

ParseShakeShapeData = (input) ->
  text = tostring(input or "")
  num_shapes = tonumber text\match "num_shapes%s+([%d]+)"
  return nil, "Shake SSF: num_shapes is missing or invalid." unless num_shapes and num_shapes >= 1
  meta = ParseMeta text
  meta.motion_blur = tonumber text\match "motion_blur%s+([%+%-%.%deE]+)"
  meta.shutter_timing = tonumber text\match "shutter_timing%s+([%+%-%.%deE]+)"
  meta.shutter_offset = tonumber text\match "shutter_offset%s+([%+%-%.%deE]+)"
  diagnostics = {"Y-up SSF coordinates detected; vertical flipping is deferred until the actual source height is known."}
  if meta.motion_blur or meta.shutter_timing or meta.shutter_offset
    diagnostics[#diagnostics + 1] = "SSF motion blur/shutter values are retained as metadata, but ASS cannot reproduce Mocha subframe sampling; this is not geometric jitter."
  return ParseLegacyShakeLayout(text, num_shapes, meta, diagnostics) unless text\find("shape_name", 1, true) or text\find("key_time", 1, true)

  known = {shape_name: true, parent_name: true, closed: true, visible: true, locked: true, tangents: true, edge_shape: true, num_vertices: true, num_key_times: true, key_time: true, center_x: true, center_y: true, color_r: true, color_g: true, color_b: true, color_a: true, vertex_data: true, shake_shape_data: true, num_shapes: true, motion_blur: true, shutter_timing: true, shutter_offset: true, Units: true, Source: true, Comp: true}
  unknownTokens = {}
  shapes, current_shape, currentKey = {}, nil, nil
  lines = SplitLines text
  i = 1
  while i <= #lines
    stripped = trim lines[i]
    token, rest = stripped\match "^(%S+)%s*(.-)%s*$"
    switch token
      when "shape_name"
        current_shape = {
          id: "shake_#{#shapes + 1}:#{StripQuotes rest}"
          name: StripQuotes(rest), parent: "", closed: true, visible: true, locked: false
          keys: {}, key_order: {}
        }
        shapes[#shapes + 1] = current_shape
        currentKey = nil
      when "parent_name"
        current_shape.parent = StripQuotes(rest) if current_shape
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
        currentKey = {frame: frame, color: {}}
        current_shape.keys[frame] = currentKey
        current_shape.key_order[#current_shape.key_order + 1] = frame
      when "center_x"
        currentKey.center or= {} if currentKey
        currentKey.center.x = tonumber(rest) if currentKey
      when "center_y"
        currentKey.center or= {} if currentKey
        currentKey.center.y = tonumber(rest) if currentKey
      when "color_r", "color_g", "color_b", "color_a"
        currentKey.color[token\sub(-1)] = tonumber(rest) if currentKey
      when "vertex_data"
        return nil, "Shake SSF: vertex_data appears without key_time." unless current_shape and currentKey
        expected = current_shape.num_vertices and current_shape.num_vertices * 12 or nil
        values = ParseNumbers rest
        while expected and #values < expected and i < #lines
          nextLine = trim lines[i + 1]
          nextToken = nextLine\match "^(%S+)"
          break if known[nextToken]
          i += 1
          more = ParseNumbers nextLine
          values[#values + 1] = value for value in *more
        return nil, "Shake SSF: vertex_data has #{#values} values; expected #{expected}." if expected and #values != expected
        points, edge_points, has_edge, err = ShakePointsFromValues values, current_shape.num_vertices
        return nil, err unless points
        currentKey.points, currentKey.edge_points, currentKey.has_edge = points, edge_points, has_edge
      else
        unknownTokens[token] = true if token and token != "" and not known[token] and not tonumber(token)
    i += 1

  return nil, "Shake SSF declares #{num_shapes} shapes and contains #{#shapes}." if #shapes != num_shapes
  edgeSeen = false
  for shape in *shapes
    table.sort shape.key_order
    return nil, "Shake SSF: #{shape.name} declares #{shape.num_key_times} keys and contains #{#shape.key_order}." if shape.num_key_times and shape.num_key_times != #shape.key_order
    for frame in *shape.key_order
      key = shape.keys[frame]
      return nil, "Shake SSF: #{shape.name}, frame #{frame}, contains no vertex_data." unless key.points
      edgeSeen or= key.has_edge
  diagnostics[#diagnostics + 1] = "Auxiliary edge/feather data was read and retained; one ASS clip cannot represent it faithfully." if edgeSeen
  unknown_list = [token for token in pairs unknownTokens]
  table.sort unknown_list
  diagnostics[#diagnostics + 1] = "Unknown or unapplied SSF fields: #{table.concat unknown_list, ', '}." if #unknown_list > 0
  BuildShakeTrack shapes, meta, diagnostics

ReadInputOrPath = (input) ->
  raw = tostring(input or "")
  candidate = trim(raw)\gsub '^"(.*)"$', '%1'
  if not raw\find("\n", 1, true) and candidate != ""
    file = io.open candidate, "rb"
    if file
      content = file\read "*a"
      file\close!
      return content, candidate
  raw, nil

ParseInput = (input) ->
  text, sourcePath = ReadInputOrPath input
  text = tostring(text or "")\gsub "^\239\187\191", ""
  local track, err
  if text\find "shake_shape_data 4.0", 1, true
    track, err = ParseShakeShapeData text
  elseif text\find("CC Power Pin #1", 1, true) or text\find("Corner Pin #1", 1, true)
    track, err = ParsePowerPinData text
  elseif text\find("vertices", 1, true) or text\find("Bezier(", 1, true)
    track, err = ParseShapeData text
  elseif text\find "Adobe After Effects", 1, true
    track, err = ParseTransformData text
  else
    return nil, "Unrecognized format. Supported formats are AE Transform, Power Pin/Corner Pin, AE Mask Shape, legacy Bezier, and Shake SSF 4.0."
  track.source_path = sourcePath if track
  track, err

LinearFit = (times, values) ->
  n = math.min #times, #values
  return nil, "At least two samples are required." if n < 2
  sumT, sumV, sumTt, sumTv = 0, 0, 0, 0
  for i = 1, n
    t, v = tonumber(times[i]), tonumber(values[i])
    return nil, "Non-numeric sample at #{i}." unless finite(t) and finite(v)
    sumT += t
    sumV += v
    sumTt += t * t
    sumTv += t * v
  denom = n * sumTt - sumT * sumT
  return nil, "All timestamps are equal." if math.abs(denom) < singularEpsilon
  slope = (n * sumTv - sumT * sumV) / denom
  intercept = (sumV - slope * sumT) / n
  residuals, sse, max_abs = {}, 0, 0
  for i = 1, n
    residual = values[i] - (intercept + slope * times[i])
    residuals[i] = residual
    sse += residual * residual
    max_abs = math.max max_abs, math.abs residual
  {slope: slope, intercept: intercept, residuals: residuals, rms: math.sqrt(sse / n), max: max_abs}

VectorLinearity = (times, xs, ys) ->
  fit_x, err = LinearFit times, xs
  return nil, err unless fit_x
  fit_y, err = LinearFit times, ys
  return nil, err unless fit_y
  sum, max_vector = 0, 0
  residuals = {}
  for i = 1, #times
    value = math.sqrt(fit_x.residuals[i]^2 + fit_y.residuals[i]^2)
    residuals[i] = value
    sum += value * value
    max_vector = math.max max_vector, value
  {x: fit_x, y: fit_y, residuals: residuals, rms: math.sqrt(sum / #times), max: max_vector}

SignedQuadArea = (quad) ->
  area = 0
  for i = 1, 4
    a, b = quad[i], quad[i % 4 + 1]
    area += a.x * b.y - b.x * a.y
  area / 2

ValidateQuad = (quad, minArea = geometryEpsilon) ->
  return false, "A quad must contain four corners." unless quad and #quad == 4
  min_x, min_y, max_x, max_y = nil, nil, nil, nil
  for i, point in ipairs quad
    return false, "Corner #{i} is not numeric." unless finite(point.x) and finite(point.y)
    min_x, max_x = math.min(min_x or point.x, point.x), math.max(max_x or point.x, point.x)
    min_y, max_y = math.min(min_y or point.y, point.y), math.max(max_y or point.y, point.y)
  area = SignedQuadArea quad
  return false, "Degenerate quad: area #{FormatNumber area, 4}." if math.abs(area) < minArea
  bboxArea = (max_x - min_x) * (max_y - min_y)
  return false, "Degenerate quad: bounding box has no area." if bboxArea < minArea
  fill_ratio = math.abs(area) / bboxArea
  return false, "Numerically unstable quad: it occupies only #{FormatNumber(fill_ratio * 100, 4)}% of its bounding box." if fill_ratio < 0.001
  sign = nil
  for i = 1, 4
    a, b, c = quad[i], quad[i % 4 + 1], quad[(i + 1) % 4 + 1]
    edge = math.sqrt((b.x - a.x)^2 + (b.y - a.y)^2)
    return false, "Degenerate quad: edge #{i} is nearly zero." if edge < 0.001
    cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
    return false, "Quad is nearly collinear at corner #{i}." if math.abs(cross) < geometryEpsilon
    current = cross > 0 and 1 or -1
    sign or= current
    return false, "Concave quad or crossed corners." if current != sign
  true, nil, area

SeriesFromTrack = (track, fps = nil, shapeSpace = nil) ->
  fps = tonumber(fps or (track.meta and track.meta.fps)) or 24
  fps = 24 if fps <= 0
  shapeSpace or= {}
  shapeW = tonumber(shapeSpace.source_width or (track.meta and track.meta.source_width)) or 1
  shapeH = tonumber(shapeSpace.source_height or (track.meta and track.meta.source_height)) or 1
  ShapePoint = (point) ->
    x, y = point.x, point.y
    if point.normalized
      x *= shapeW
      y = 1 - y if point.y_up
      y *= shapeH
    elseif point.absolute_y_up
      y = shapeH - y
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
      series.area[i] = math.abs SignedQuadArea sample.quad
    elseif track.kind == "shape"
      sx, sy, count, area = 0, 0, 0, 0
      for mask in *sample.masks
        maskArea = 0
        for point in *mask.points
          x, y = ShapePoint point
          sx += x
          sy += y
          count += 1
        if #mask.points >= 3
          for j = 1, #mask.points
            a, b = mask.points[j], mask.points[j % #mask.points + 1]
            ax, ay = ShapePoint a
            bx, by = ShapePoint b
            maskArea += (ax * by - bx * ay) / 2
        area += math.abs maskArea
      series.x[i], series.y[i] = sx / math.max(1, count), sy / math.max(1, count)
      series.area[i] = area
  series

Core.trim = trim
Core.finite = finite
Core.FormatNumber = FormatNumber
Core.ParseNumbers = ParseNumbers
Core.ParseMeta = ParseMeta
Core.ParseKeyframeSections = ParseKeyframeSections
Core.ParseTransformData = ParseTransformData
Core.ParsePowerPinData = ParsePowerPinData
Core.ParseShapeData = ParseShapeData
Core.ParseShakeShapeData = ParseShakeShapeData
Core.ParseInput = ParseInput
Core.UnwrapAngles = UnwrapAngles
Core.UnwrapRotationSection = UnwrapRotationSection
Core.LinearFit = LinearFit
Core.VectorLinearity = VectorLinearity
Core.SignedQuadArea = SignedQuadArea
Core.ValidateQuad = ValidateQuad
Core.SeriesFromTrack = SeriesFromTrack

PointAt = (point, x, y, ctx) ->
  if point and point.normalized
    x *= ctx.source_w
    y = 1 - y if point.y_up
    y *= ctx.source_h
  elseif point and point.absolute_y_up
    y = ctx.source_h - y
  {x: x * ctx.sx + ctx.dx, y: y * ctx.sy + ctx.dy}

SegmentIsLine = (pointA, pointB, ctx) ->
  eps = ctx.epsilon
  math.abs((pointA.outx or 0) * ctx.sx) <= eps and
    math.abs((pointA.outy or 0) * ctx.sy) <= eps and
    math.abs((pointB.inx or 0) * ctx.sx) <= eps and
    math.abs((pointB.iny or 0) * ctx.sy) <= eps

AppendSegment = (parts, pointA, pointB, ctx) ->
  endpoint = PointAt pointB, pointB.x, pointB.y, ctx
  if SegmentIsLine pointA, pointB, ctx
    parts[#parts + 1] = "l"
    parts[#parts + 1] = FormatNumber endpoint.x, ctx.decimals
    parts[#parts + 1] = FormatNumber endpoint.y, ctx.decimals
  else
    c1 = PointAt pointA, pointA.x + pointA.outx, pointA.y + pointA.outy, ctx
    c2 = PointAt pointB, pointB.x + pointB.inx, pointB.y + pointB.iny, ctx
    parts[#parts + 1] = "b"
    for value in *{c1.x, c1.y, c2.x, c2.y, endpoint.x, endpoint.y}
      parts[#parts + 1] = FormatNumber value, ctx.decimals

RenderShapePath = (shape, ctx) ->
  points = shape.points
  return nil, "Shape has fewer than two points." unless points and #points >= 2
  first = PointAt points[1], points[1].x, points[1].y, ctx
  parts = {"m", FormatNumber(first.x, ctx.decimals), FormatNumber(first.y, ctx.decimals)}
  AppendSegment parts, points[i], points[i + 1], ctx for i = 1, #points - 1
  AppendSegment parts, points[#points], points[1], ctx if shape.closed
  table.concat parts, " "

NormalizePath = (path) ->
  path = trim path
  return nil, "Empty ASS path." if path == ""
  if ZF
    ok, shape = pcall -> ZF.shape path
    return nil, "ZF.shape rejected the path: #{shape}" unless ok and shape
    okBuild, built = pcall -> trim shape\build!
    return built if okBuild and built and built != ""
  path

ManualBounds = (path) ->
  min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
  isX, found = true, false
  for token in tostring(path or "")\gmatch "%S+"
    if token == "m" or token == "l" or token == "b"
      isX = true
    else
      number = tonumber token
      if number
        if isX
          min_x, max_x = math.min(min_x, number), math.max(max_x, number)
        else
          min_y, max_y = math.min(min_y, number), math.max(max_y, number)
          found = true
        isX = not isX
  return nil unless found
  {l: min_x, t: min_y, r: max_x, b: max_y, w: max_x - min_x, h: max_y - min_y}

PathBounds = (path) ->
  if ZF
    ok, shape = pcall -> ZF.shape path
    if ok and shape and shape.l and shape.t and shape.w and shape.h
      return {l: shape.l, t: shape.t, r: shape.l + shape.w, b: shape.t + shape.h, w: shape.w, h: shape.h}
  ManualBounds path

ManualShiftPath = (path, dx, dy, decimals) ->
  out, isX = {}, true
  for token in tostring(path or "")\gmatch "%S+"
    if token == "m" or token == "l" or token == "b"
      out[#out + 1], isX = token, true
    else
      number = tonumber token
      if number
        out[#out + 1] = FormatNumber(number + (isX and dx or dy), decimals)
        isX = not isX
      else
        out[#out + 1] = token
  table.concat out, " "

ShiftPath = (path, dx, dy, decimals) ->
  if ZF
    ok, moved = pcall -> trim ZF.shape(path)\move(dx, dy)\build!
    return moved if ok and moved and moved != ""
  ManualShiftPath path, dx, dy, decimals

BuildShapeContext = (opts, meta, script_res) ->
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

PrepareShapeSamples = (track, opts, script_res) ->
  ctx = BuildShapeContext opts, track.meta or {}, script_res
  out = {}
  for sample in *track.samples
    LineOps.checkCancelled!
    paths = {}
    for mask in *sample.masks
      path, err = RenderShapePath mask, ctx
      return nil, err unless path
      path, err = NormalizePath path
      return nil, err unless path
      paths[#paths + 1] = path
    out[#out + 1] = {source_frame: sample.source_frame, path: trim(table.concat(paths, " ")), masks: sample.masks}
  {kind: "shape", format: track.format, meta: track.meta, samples: out, diagnostics: track.diagnostics, ctx: ctx}

StripTopLevelClips = (text) -> LineOps.removeTagCalls text, {"clip", "iclip"}, true

ApplyClipText = (text, mode, path) -> LineOps.prependTag StripTopLevelClips(text), "\\#{mode}(#{path})"

ApplyClipWithAss = (line, mode, path) ->
  return nil unless ASS and ASS.parse and ASS.Draw and ASS.Draw.DrawingBase
  working = CopyLine line
  ok, result = pcall ->
    data = ASS\parse working
    data\removeTags {"clip_vect", "iclip_vect", "clip_rect", "iclip_rect"}
    drawing = ASS.Draw.DrawingBase{str: path}
    data\replaceTags {ASS\createTag(mode == "iclip" and "iclip_vect" or "clip_vect", drawing)}
    data\commit!
    working.text
  if ok and result and result != "" then result else nil

ShapeText = (path, opts) ->
  decimals = clamp opts.decimals, 0, 6
  bounds = PathBounds(path) or {l: 0, t: 0, w: 0, h: 0}
  local_path = ShiftPath path, -bounds.l, -bounds.t, decimals
  tags = opts.shape_tags or DEFAULTS.shape_tags
  "{\\an7\\pos(#{FormatNumber bounds.l, decimals},#{FormatNumber bounds.t, decimals})\\fscx100\\fscy100#{tags}\\p1}#{local_path}{\\p0}"

RenderShapeLineText = (line, mode, path, opts) ->
  return ShapeText(path, opts) if mode == "shape"
  ApplyClipWithAss(line, mode, path) or ApplyClipText(line.text or "", mode, path)

GetScriptResolution = (subs) ->
  x, y = LineOps.scriptResolution subs, DEFAULTS.target_width, DEFAULTS.target_height
  {x: x, y: y}

ExclusiveEndFrame = (startTime, endTime) ->
  start_frame = aegisub.frame_from_ms startTime
  end_frame = aegisub.frame_from_ms endTime
  return nil unless start_frame and end_frame
  math.max start_frame + 1, end_frame

SelectionWindow = (subs, sel) ->
  window, err = Media.selectionWindow subs, sel, {includeComments: false, positiveDuration: true, requireFrames: true}
  return nil, err or "Select at least one non-comment dialogue line with a positive duration." unless window
  end_frame = ExclusiveEndFrame window.min_start, window.max_end
  return nil, "The selection covers no loaded video frames." unless end_frame and end_frame > window.start_frame
  window.end_frame = end_frame
  window.frame_count = end_frame - window.start_frame
  window

SliceTrack = (track, sample_start, count, strict = true) ->
  sample_start = KiteCore.finiteNumber(sample_start) or 1
  return nil, "The first sample must be an integer." unless sample_start == math.floor sample_start
  return nil, "The sample count must be a positive integer." unless finite(count) and count > 0 and count == math.floor(count)
  return nil, "The first sample must be 1 or greater." if sample_start < 1
  if track.kind == "shape" and #track.samples == 1 and count > 1
    out = CopyTable track
    out.samples = {}
    first = track.samples[1]
    for i = 1, count
      sample = CopyTable first
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
      return nil, "Ambiguous Rotation at source frame #{sample.source_frame} (#{FormatNumber sample.ambiguous_rotation, 3)} degree jump); normalize the export or deliberately disable strict synchronization." if sample.ambiguous_rotation
  out = CopyTable track
  out.samples = samples
  out.first_frame, out.last_frame = samples[1].source_frame, samples[#samples].source_frame
  out.sample_start = sample_start
  out

CanonicalFPS = (fps) ->
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

TimingDiagnostics = (track, window) ->
  diagnostics = {}
  startMs = aegisub.ms_from_frame window.start_frame
  endMs = aegisub.ms_from_frame window.end_frame
  return diagnostics unless startMs and endMs
  duration = endMs - startMs
  if duration > 0
    localFps = window.frame_count * 1000 / duration
    diagnostics.local_fps = localFps
    diagnostics.actual_duration_ms = duration
    if track.meta and track.meta.fps
      effectiveFps = CanonicalFPS track.meta.fps
      if effectiveFps
        diagnostics.effective_export_fps = effectiveFps
        diagnostics.fps_delta = math.abs(effectiveFps - localFps)
        diagnostics.expected_duration_ms = window.frame_count * 1000 / effectiveFps
        diagnostics.duration_delta_ms = math.abs(duration - diagnostics.expected_duration_ms)
    maxPhase = 0
    for i = 0, window.frame_count
      actual = aegisub.ms_from_frame(window.start_frame + i)
      return diagnostics unless actual
      predicted = startMs + duration * i / window.frame_count
      maxPhase = math.max maxPhase, math.abs(actual - predicted)
    diagnostics.max_timeline_phase_ms = maxPhase
  diagnostics

ValidateSync = (track, window, strict, ordinalExact = false) ->
  info = TimingDiagnostics track, window
  if strict and not ordinalExact and not track.static and info.duration_delta_ms and info.duration_delta_ms > 2.5
    return nil, "Duration mismatch: export #{FormatNumber info.expected_duration_ms, 3} ms, timeline #{FormatNumber info.actual_duration_ms, 3} ms (delta #{FormatNumber info.duration_delta_ms, 3} ms)."
  if strict and not ordinalExact and not track.static and (info.max_timeline_phase_ms or 0) > 2.5
    return nil, "Variable or irregular timeline: phase differs by #{FormatNumber info.max_timeline_phase_ms, 3} ms from CFR sampling."
  if strict and track.meta and track.meta.source_par and track.meta.comp_par and math.abs(track.meta.source_par - track.meta.comp_par) > 0.0001
    return nil, "Pixel-aspect mismatch (source #{track.meta.source_par}, comp #{track.meta.comp_par}); it will not be approximated silently."
  info

SameOutputState = (a, b) ->
  return false unless a and b and a.end_time == b.start_time
  return false if FBFOptimizer.hasDurationTags a.text
  return false unless LineOps.shallowEqual a.extra, b.extra
  for key in *{"text", "layer", "style", "actor", "effect", "margin_l", "margin_r", "margin_t", "comment"}
    return false if a[key] != b[key]
  true

CompressOutputLines = (lines) ->
  out = {}
  for line in *lines
    if #out > 0 and SameOutputState(out[#out], line)
      out[#out].end_time = line.end_time
    else
      out[#out + 1] = line
  out

FBFOptimizer.DEFAULT_TOLERANCE = 0.05
FBFOptimizer.MODES = {
  {label: "Conservative (0.05 px)", tolerance: 0.05}
  {label: "Exact (0 px)", tolerance: 0}
  {label: "Subpixel (0.10 px)", tolerance: 0.10}
}

FBFOptimizer.sameFields = (left, right) ->
  return false unless left and right
  return false unless LineOps.shallowEqual left.extra, right.extra
  for key in *{"class", "layer", "style", "actor", "effect", "margin_l", "margin_r", "margin_t", "margin_b", "margin_v", "comment"}
    return false if left[key] != right[key]
  true

FBFOptimizer.metadataKey = (line) ->
  table.concat [tostring(line[key] or "") for key in *{"class", "layer", "style", "actor", "effect", "margin_l", "margin_r", "margin_t", "margin_b", "margin_v", "comment"}], "\31"

FBFOptimizer.hasDurationTags = (text) ->
  for name in *{"move", "t", "fad", "fade", "k", "kf", "ko", "kt"}
    return true if LineOps.hasTag text, name, false
  false

FBFOptimizer.drawingTemplate = (text, analysis) ->
  parts = {}
  geometryTags = {"p", "pos", "fscx", "fscy", "frz", "fr"}
  for section in *analysis.sections
    if section.type == "override"
      parts[#parts + 1] = LineOps.removeTagCalls "{" .. section.text .. "}", geometryTags
    elseif section.type == "drawing"
      topology = section.text\gsub NUM_PATTERN, "#"
      topology = topology\gsub "%s+", " "
      parts[#parts + 1] = "<drawing:#{trim topology}>"
    elseif section.type == "comment"
      parts[#parts + 1] = "{" .. section.text .. "}"
    else
      parts[#parts + 1] = section.text
  table.concat parts

FBFOptimizer.state = (line) ->
  text = tostring(line and line.text or "")
  duration_unsafe = FBFOptimizer.hasDurationTags text
  analysis = LineOps.analyzeText text
  unless analysis.has_drawing
    position = LineOps.position text
    template = if position then LineOps.removeTagCalls(text, "pos") else text
    return {
      kind: "text"
      :text, :template, :position, :duration_unsafe
      lane_key: template
    }

  drawing_unsafe = false
  for name in *{"org", "frx", "fry", "fax", "fay", "clip", "iclip", "r"}
    if LineOps.hasTag text, name, false
      drawing_unsafe = true
      break
  scales, drawing_scale = {}, nil
  drawing = {}
  for section in *analysis.sections
    if section.type == "drawing" and trim(section.text) != ""
      scale = tonumber section.drawing
      scales[scale] = true if scale and scale > 0
      drawing_scale or= scale
      drawing[#drawing + 1] = section.text
  scaleCount = 0
  scaleCount += 1 for _ in pairs scales
  drawing_unsafe = true if scaleCount != 1
  path = table.concat drawing, " "
  coordinates = [tonumber(value) for value in path\gmatch NUM_PATTERN]
  drawing_unsafe = true if #coordinates == 0 or #coordinates % 2 != 0
  position = LineOps.position text
  scale_x = LineOps.tagNumber text, "fscx", 100, true
  scale_y = LineOps.tagNumber text, "fscy", 100, true
  rotation, rotationCall = LineOps.tagNumber text, "frz", nil, true
  rotation = LineOps.tagNumber(text, "fr", 0, true) unless rotationCall
  align = LineOps.tagNumber text, "an", 7, true
  template = FBFOptimizer.drawingTemplate text, analysis
  {
    kind: "drawing"
    :text, :template, :position, :duration_unsafe, :drawing_unsafe
    p: drawing_scale
    :scale_x, :scale_y, :rotation, :align, :coordinates, :path
    lane_key: template
  }

FBFOptimizer.geometryPoints = (state) ->
  return nil unless state and state.position and state.p and state.p > 0
  return nil unless finite(state.scale_x) and finite(state.scale_y) and finite(state.rotation)
  denominator = 2 ^ (state.p - 1)
  angle = math.rad state.rotation
  cosine, sine = math.cos(angle), math.sin(angle)
  points = {}
  for index = 1, #state.coordinates, 2
    x = state.coordinates[index] * state.scale_x / 100 / denominator
    y = state.coordinates[index + 1] * state.scale_y / 100 / denominator
    points[#points + 1] = {
      x: x * cosine - y * sine + state.position.x
      y: x * sine + y * cosine + state.position.y
    }
  points

FBFOptimizer.distance = (left, right) ->
  math.sqrt((left.x - right.x)^2 + (left.y - right.y)^2)

FBFOptimizer.compatible = (left, right, tolerance = FBFOptimizer.DEFAULT_TOLERANCE) ->
  return false unless left and right
  return false if left.duration_unsafe or right.duration_unsafe
  return true if left.text == right.text
  return false unless left.kind == right.kind and left.template == right.template
  tolerance = math.max 0, tonumber(tolerance) or FBFOptimizer.DEFAULT_TOLERANCE
  if left.kind == "text"
    return false unless left.position and right.position
    return FBFOptimizer.distance(left.position, right.position) <= tolerance + numericEpsilon
  return false if left.drawing_unsafe or right.drawing_unsafe
  return false unless left.p == right.p and #left.coordinates == #right.coordinates
  if left.align != 7 or right.align != 7
    return false unless left.path == right.path
    return false unless math.abs(left.scale_x - right.scale_x) <= numericEpsilon
    return false unless math.abs(left.scale_y - right.scale_y) <= numericEpsilon
    return false unless math.abs(left.rotation - right.rotation) <= numericEpsilon
    return left.position and right.position and FBFOptimizer.distance(left.position, right.position) <= tolerance + numericEpsilon
  leftPoints, rightPoints = FBFOptimizer.geometryPoints(left), FBFOptimizer.geometryPoints(right)
  return false unless leftPoints and rightPoints and #leftPoints == #rightPoints
  for index = 1, #leftPoints
    return false if FBFOptimizer.distance(leftPoints[index], rightPoints[index]) > tolerance + numericEpsilon
  true

FBFOptimizer.selectionItems = (subs, selection) ->
  records = LineOps.selectedLines subs, selection, (line) ->
    line and line.class == "dialogue" and not line.comment and tonumber(line.end_time) and tonumber(line.start_time) and line.end_time > line.start_time
  items = {}
  for record in *records or {}
    items[#items + 1] = {
      index: record.index
      line: record.line
      state: FBFOptimizer.state record.line
    }
  items

FBFOptimizer.buildPlan = (items, tolerance = FBFOptimizer.DEFAULT_TOLERANCE) ->
  ordered = [item for item in *items or {}]
  table.sort ordered, (left, right) ->
    if left.line.start_time == right.line.start_time
      if left.line.end_time == right.line.end_time then left.index < right.index else left.line.end_time < right.line.end_time
    else
      left.line.start_time < right.line.start_time
  lanes = {}
  for item in *ordered
    item.state or= FBFOptimizer.state item.line
    item.lane_key = FBFOptimizer.metadataKey(item.line) .. "\31" .. tostring(item.state.lane_key or item.line.text or "")
    lane = nil
    for candidate in *lanes
      if candidate.last.line.end_time == item.line.start_time and candidate.key == item.lane_key and FBFOptimizer.sameFields(candidate.last.line, item.line)
        lane = candidate
        break
    unless lane
      lane = {key: item.lane_key, items: {}}
      lanes[#lanes + 1] = lane
    lane.items[#lane.items + 1] = item
    lane.last = item

  plan = {
    before: #ordered
    after: #ordered
    merged: 0
    longest_run: 0
    unsafe_count: 0
    :lanes
    updates: {}
    deletes: {}
    retained: {}
  }
  for item in *ordered
    plan.unsafe_count += 1 if item.state.duration_unsafe
  for lane in *lanes
    anchor, previous, run = nil, nil, 0
    for item in *lane.items
      if anchor and previous.line.end_time == item.line.start_time and FBFOptimizer.sameFields(anchor.line, item.line) and FBFOptimizer.compatible(anchor.state, item.state, tolerance)
        plan.updates[anchor.index] = item.line.end_time
        plan.deletes[#plan.deletes + 1] = item.index
        plan.retained[item.index] = nil
        plan.merged += 1
        run += 1
      else
        anchor = item
        plan.retained[item.index] = true
        run = 1
      previous = item
      plan.longest_run = math.max plan.longest_run, run
  plan.after = plan.before - plan.merged
  plan

FBFOptimizer.applyPlan = (subs, plan) ->
  for index, endTime in pairs plan.updates or {}
    LineOps.checkCancelled!
    line = CopyLine subs[index]
    line.end_time = endTime
    subs[index] = line
  deleted = [index for index in *plan.deletes or {}]
  table.sort deleted
  LineOps.deleteIndices subs, deleted
  selection = {}
  retained = [index for index, keep in pairs(plan.retained or {}) when keep]
  table.sort retained
  shift = 0
  for original in *retained
    while deleted[shift + 1] and deleted[shift + 1] < original
      shift += 1
    selection[#selection + 1] = original - shift
  selection

FBFOptimizer.optimize = (subs, selection, tolerance = FBFOptimizer.DEFAULT_TOLERANCE) ->
  items = FBFOptimizer.selectionItems subs, selection
  plan = FBFOptimizer.buildPlan items, tolerance
  return selection, plan if plan.merged == 0
  FBFOptimizer.applyPlan(subs, plan), plan

FBFOptimizer.toleranceForMode = (label) ->
  for mode in *FBFOptimizer.MODES
    return mode.tolerance if mode.label == label
  nil

FBFOptimizer.canRun = (subs, selection) ->
  #FBFOptimizer.selectionItems(subs, selection) > 1

FrameInterval = (line, frame) ->
  startTime = math.max line.start_time, aegisub.ms_from_frame(frame)
  last_frame = ExclusiveEndFrame(line.start_time, line.end_time) - 1
  endTime = if frame == last_frame then line.end_time else math.min(line.end_time, aegisub.ms_from_frame(frame + 1))
  return nil unless endTime > startTime
  startTime, endTime

ReplaceOrInsertOutputs = (subs, index, outputs, replace) ->
  return if #outputs == 0
  if replace
    subs[index] = outputs[1]
    for i = #outputs, 2, -1
      LineOps.checkCancelled!
      subs.insert index + 1, outputs[i]
  else
    for i = #outputs, 1, -1
      LineOps.checkCancelled!
      subs.insert index + 1, outputs[i]

SelectionFromGroups = (groups) ->
  ordered = [group for group in *groups or {}]
  table.sort ordered, (a, b) -> a.index < b.index
  selected, shift = {}, 0
  for group in *ordered
    count = math.max 0, tonumber(group.count) or 0
    startIndex = group.index + shift + (group.replace and 0 or 1)
    selected[#selected + 1] = startIndex + offset for offset = 0, count - 1
    shift += count - (group.replace and 1 or 0)
  selected

ApplyShapeTrack = (subs, window, track, opts) ->
  script_res = GetScriptResolution subs
  prepared, err = PrepareShapeSamples track, opts, script_res
  return nil, err unless prepared
  mode = opts.output_mode or DEFAULTS.output_mode
  replace = opts.placement != "Insert new lines"
  wrappedByIndex, groups = {}, {}
  if mode != "shape"
    collection = LineCollection subs, window.indices, AcceptDialogueLine, false
    wrappedByIndex[line.number] = line for line in *collection.lines
  for position = #window.indices, 1, -1
    LineOps.checkCancelled!
    index = window.indices[position]
    base = subs[index]
    outputs = {}
    first_frame = aegisub.frame_from_ms base.start_time
    last_frame = ExclusiveEndFrame base.start_time, base.end_time
    fbfByFrame = {}
    if mode != "shape"
      source = wrappedByIndex[index]
      return nil, "Line #{index}: temporal tags could not be baked." unless source
      source.startFrame, source.endFrame = first_frame, last_frame
      sourceData = ASS\parse source
      for frameLine in *AssContext.line2fbf(sourceData, ArchUtil, ASS)
        frame = frameLine.startFrame or aegisub.frame_from_ms frameLine.start_time
        fbfByFrame[frame] = frameLine
    for frame = first_frame, last_frame - 1
      LineOps.checkCancelled!
      sampleIndex = if opts.mapping_mode == "Restart on each line" then frame - first_frame + 1 else frame - window.start_frame + 1
      sample = prepared.samples[sampleIndex]
      continue unless sample
      startTime, endTime = FrameInterval base, frame
      continue unless startTime
      line = if mode == "shape" then CopyLine(base) else fbfByFrame[frame]
      return nil, "Line #{index}, frame #{frame}: ASS state could not be baked." unless line
      line.start_time, line.end_time = startTime, endTime
      ShiftFrameKaraoke line, base.start_time, startTime if mode != "shape"
      line.comment = false
      line.layer = (tonumber(base.layer) or 0) + (replace and 0 or tonumber(opts.layer_offset) or 1)
      line.text = RenderShapeLineText line, mode, sample.path, opts
      outputs[#outputs + 1] = CopyLine line
    outputs = CompressOutputLines outputs
    return nil, "Line #{index}: no Shape output was generated." if #outputs == 0
    ReplaceOrInsertOutputs subs, index, outputs, replace
    groups[#groups + 1] = {index: index, count: #outputs, replace: replace}
  true, {selection: SelectionFromGroups(groups), groups: groups}

Core.BuildShapeContext = BuildShapeContext
Core.RenderShapePath = RenderShapePath
Core.PrepareShapeSamples = PrepareShapeSamples
Core.ShapeText = ShapeText
Core.RenderShapeLineText = RenderShapeLineText
Core.StripTopLevelClips = StripTopLevelClips
Core.ApplyClipText = ApplyClipText
Core.SelectionWindow = SelectionWindow
Core.ExclusiveEndFrame = ExclusiveEndFrame
Core.SliceTrack = SliceTrack
Core.CanonicalFPS = CanonicalFPS
Core.TimingDiagnostics = TimingDiagnostics
Core.ValidateSync = ValidateSync
Core.CompressOutputLines = CompressOutputLines
Core.SelectionFromGroups = SelectionFromGroups
Core.ApplyShapeTrack = ApplyShapeTrack

ScaleTrackCoordinates = (track, script_res, opts) ->
  out = CopyTable track
  out.meta = CopyTable track.meta
  out.samples = {}
  source_w = if opts.use_source_meta and track.meta and track.meta.source_width then track.meta.source_width else tonumber(opts.source_width)
  source_h = if opts.use_source_meta and track.meta and track.meta.source_height then track.meta.source_height else tonumber(opts.source_height)
  source_w = script_res.x unless source_w and source_w > 0
  source_h = script_res.y unless source_h and source_h > 0
  sx = opts.scale_to_script and script_res.x / source_w or 1
  sy = opts.scale_to_script and script_res.y / source_h or 1
  dx, dy = tonumber(opts.offset_x) or 0, tonumber(opts.offset_y) or 0
  for sample in *track.samples
    LineOps.checkCancelled!
    copy = CopyTable sample
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

RotateVector = (x, y, radians) ->
  c, s = math.cos(radians), math.sin(radians)
  x * c - y * s, x * s + y * c

TransformPoint = (x, y, sample, reference) ->
  refSx = (reference.scale and reference.scale.x or 100) / 100
  refSy = (reference.scale and reference.scale.y or 100) / 100
  curSx = (sample.scale and sample.scale.x or 100) / 100
  curSy = (sample.scale and sample.scale.y or 100) / 100
  return nil, nil, "Zero scale at the reference frame." if math.abs(refSx) < scaleEpsilon or math.abs(refSy) < scaleEpsilon
  coord = reference.coordinate_scale or sample.coordinate_scale or {x: 1, y: 1}
  coordX, coordY = tonumber(coord.x) or 1, tonumber(coord.y) or 1
  return nil, nil, "Invalid coordinate scale." if math.abs(coordX) < scaleEpsilon or math.abs(coordY) < scaleEpsilon
  dx, dy = (x - reference.position.x) / coordX, (y - reference.position.y) / coordY
  dx, dy = RotateVector dx, dy, math.rad(reference.rotation or 0)
  dx, dy = dx / refSx, dy / refSy
  dx, dy = dx * curSx, dy * curSy
  dx, dy = RotateVector dx, dy, -math.rad(sample.rotation or 0)
  sample.position.x + dx * coordX, sample.position.y + dy * coordY

InverseTransformPoint = (x, y, sample, reference) ->
  refSx = (reference.scale and reference.scale.x or 100) / 100
  refSy = (reference.scale and reference.scale.y or 100) / 100
  curSx = (sample.scale and sample.scale.x or 100) / 100
  curSy = (sample.scale and sample.scale.y or 100) / 100
  return nil, nil, "Current scale is zero; the transform cannot be inverted." if math.abs(curSx) < scaleEpsilon or math.abs(curSy) < scaleEpsilon
  coord = reference.coordinate_scale or sample.coordinate_scale or {x: 1, y: 1}
  coordX, coordY = tonumber(coord.x) or 1, tonumber(coord.y) or 1
  return nil, nil, "Invalid coordinate scale." if math.abs(coordX) < scaleEpsilon or math.abs(coordY) < scaleEpsilon
  dx, dy = (x - sample.position.x) / coordX, (y - sample.position.y) / coordY
  dx, dy = RotateVector dx, dy, math.rad(sample.rotation or 0)
  dx, dy = dx / curSx, dy / curSy
  dx, dy = dx * refSx, dy * refSy
  dx, dy = RotateVector dx, dy, -math.rad(reference.rotation or 0)
  reference.position.x + dx * coordX, reference.position.y + dy * coordY

MotionPoint = (x, y, sample, reference, options) ->
  if options and options.inverse
    InverseTransformPoint x, y, sample, reference
  else
    TransformPoint x, y, sample, reference

EffectiveTransformSample = (sample, reference, options, prefix = "") ->
  enabled = (name, fallback = true) ->
    value = options[prefix .. name]
    if value == nil then fallback else value
  copy = CopyTable sample
  position_x, position_y = reference.position.x, reference.position.y
  position_x = sample.position.x if enabled "x_position"
  position_y = sample.position.y if enabled "y_position"
  copy.position = {x: position_x, y: position_y}
  copy.scale = if enabled("scale") then {x: sample.scale.x, y: sample.scale.y} else {x: reference.scale.x, y: reference.scale.y}
  copy.rotation = if enabled("rotation") then sample.rotation else reference.rotation
  copy

mapPathCoordinates = require("kite.AssDrawing").mapCoordinates

RectClipToPath = (content) ->
  args = LineOps.splitArguments content
  return nil unless #args == 4
  values = [KiteCore.finiteNumber(value) for value in *args]
  return nil unless #values == 4
  l, t, r, b = unpack values
  "m #{l} #{t} l #{r} #{t} #{r} #{b} #{l} #{b}"

ClipToFloatPath = (content) ->
  AssDrawing = require "kite.AssDrawing"
  content = trim content
  rectangle = RectClipToPath content
  return rectangle, true if rectangle
  scale, path = content\match "^(%d+)%s*,%s*(.*)$"
  unless scale
    return nil, false unless AssDrawing.validatePath content
    return content, false
  scale = KiteCore.finiteNumber scale
  return nil, false unless scale and scale >= 1 and scale == math.floor(scale)
  factor = 2 ^ (scale - 1)
  return nil, false unless finite(factor) and AssDrawing.validatePath(path)
  mapPathCoordinates(path, ((x, y) -> x / factor, y / factor), 6), false

TransformClipPath = (path, sample, reference, decimals = 2, options = nil) ->
  mapPathCoordinates path, ((x, y) -> MotionPoint x, y, sample, reference, options), decimals

TranslateClipPath = (path, dx, dy, decimals = 2) ->
  return path if math.abs(dx) < numericEpsilon and math.abs(dy) < numericEpsilon
  mapPathCoordinates path, ((x, y) -> x + dx, y + dy), decimals

importantTags = {
  xscale: {opt: "scale", skip: 0}
  yscale: {opt: "scale", skip: 0}
  border: {opt: "border", skip: 0}
  shadow: {opt: "shadow", skip: 0}
  zrot: {opt: "rotation"}
}

GetMissingTags = (block, options, properties) ->
  result = {}
  for key, spec in pairs importantTags
    tag = Tags.allTags[key]
    if options[spec.opt] and not block\match(tag.pattern) and properties[tag] != spec.skip
      result[#result + 1] = tag\format properties[tag]
  table.concat result

PrepareStaticLine = (line, options) ->
  line.hasOrg, line.hasClip = false, false
  line\getPropertiesFromStyle!
  unless line\extraMetrics line.styleRef
    line\ensureLeadingOverrideBlockExists!
    line\runCallbackOnFirstOverride (tagBlock) =>
      tagBlock\gsub "{", ("{\\pos(%g,%g)")\format @xPosition, @yPosition
  line\runCallbackOnFirstOverride (tagBlock) =>
    tags = GetMissingTags tagBlock, options, line.properties
    "{" .. tags .. tagBlock\sub 2
  styles = line.parentCollection and line.parentCollection.styles or {}
  line\runCallbackOnOverrides (tagBlock) =>
    tagBlock\gsub "\\org%([%.%d%-]+,[%.%d%-]+%)", ->
      line.hasOrg = true
      nil
    savedStyle, reset = line.styleRef, false
    tagBlock = tagBlock\gsub "\\r([^\\}]*)([^}]*)", (resetStyle, remainder) ->
      if styles[resetStyle]
        line.styleRef = styles[resetStyle]
        line\getPropertiesFromStyle!
        reset = true
      tags = GetMissingTags remainder, options, line.properties
      "\\r" .. resetStyle .. tags .. remainder
    if reset
      line.styleRef = savedStyle
      line\getPropertiesFromStyle!
    for pattern in *{"(\\clip%b())", "(\\iclip%b())"}
      tagBlock = tagBlock\gsub pattern, (clip) ->
        line.hasClip = true
        clip
    tagBlock
  line

ApplyTransformText = (line, sample, reference, options) ->
  text = line.text
  effectiveSample = EffectiveTransformSample sample, reference, options
  snapX, snapY = 0, 0
  if options.absolute and not options.only_clip and not options.inverse
    posX, posY = AssContext.explicitPosition text, (line.end_time or 0) - (line.start_time or 0), 0
    if posX and posY
      relativeX, relativeY, snapErr = MotionPoint posX, posY, effectiveSample, reference, options
      unless snapErr
        snapX = effectiveSample.position.x - relativeX if options.x_position
        snapY = effectiveSample.position.y - relativeY if options.y_position
  unless options.only_clip
    text = LineOps.mapTagCalls text, {"pos", "org"}, (call) ->
      return nil if call.name == "org" and not options.origin
      args = LineOps.splitArguments call.value
      x, y = KiteCore.finiteNumber(args[1]), KiteCore.finiteNumber(args[2])
      return nil unless #args == 2 and x and y
      tx, ty, err = MotionPoint x, y, effectiveSample, reference, options
      assert not err, err
      "\\#{call.raw_name}(#{FormatNumber(tx + snapX, 2)},#{FormatNumber(ty + snapY, 2)})"
    rx = (effectiveSample.scale.x or 100) / (reference.scale.x or 100)
    ry = (effectiveSample.scale.y or 100) / (reference.scale.y or 100)
    if options.inverse
      assert math.abs(rx) > scaleEpsilon and math.abs(ry) > scaleEpsilon, "A zero scale cannot be inverted."
      rx, ry = 1 / rx, 1 / ry
    scalar = math.sqrt math.abs(rx * ry)
    factors = {}
    if options.scale then factors.fscx, factors.fscy = rx, ry
    if options.border then factors.xbord, factors.ybord, factors.bord = math.abs(rx), math.abs(ry), scalar
    if options.shadow then factors.xshad, factors.yshad, factors.shad = rx, ry, scalar
    if options.blur then factors.blur = 1 - (1 - scalar) * (KiteCore.finiteNumber(options.blur_scale) or 1)
    rotationDelta = (effectiveSample.rotation - reference.rotation) * (options.inverse and -1 or 1)
    selected = {name, true for name in pairs factors}
    selected.fr, selected.frz = true, true if options.rotation
    text = LineOps.mapTagCalls text, selected, ((call) ->
      value = KiteCore.finiteNumber call.value
      return nil unless value
      value = if factors[call.name] then value * factors[call.name] else value + rotationDelta
      assert finite(value), "Non-finite transformed tag."
      "\\#{call.raw_name}#{FormatNumber value, 2}"
    ), {top_level_only: false}
  if options.track_clip
    cs, cr = effectiveSample, reference
    ApplyClip = (tag_name, wrapped) ->
      content = wrapped\sub 2, -2
      path, wasRect = ClipToFloatPath content
      return "\\#{tag_name}#{wrapped}" unless path
      return "\\#{tag_name}#{wrapped}" if wasRect and options.rect_clip == false
      return "\\#{tag_name}#{wrapped}" if not wasRect and options.vector_clip == false
      moved = TransformClipPath path, cs, cr, options.decimals or 2, options
      moved = TranslateClipPath moved, snapX, snapY, options.decimals or 2
      if wasRect and not options.rect_to_vector
        points = ParseNumbers moved
        if #points >= 8
          axisError = math.max math.abs(points[2] - points[4]), math.abs(points[3] - points[5]), math.abs(points[6] - points[8]), math.abs(points[7] - points[1])
          if axisError <= 0.01
            l = math.min points[1], points[3], points[5], points[7]
            r = math.max points[1], points[3], points[5], points[7]
            t = math.min points[2], points[4], points[6], points[8]
            b = math.max points[2], points[4], points[6], points[8]
            return "\\#{tag_name}(#{FormatNumber l, options.decimals or 2},#{FormatNumber t, options.decimals or 2},#{FormatNumber r, options.decimals or 2},#{FormatNumber b, options.decimals or 2})"
      "\\#{tag_name}(#{moved})"
    text = LineOps.mapTagCalls text, {"clip", "iclip"}, ((call) -> ApplyClip call.raw_name, call.value), {top_level_only: false}
  text

HasUnsafeLinearTags = (text, options) ->
  return true if FBFOptimizer.hasDurationTags text
  LineOps.hasTag text, {"org", "clip", "iclip"}, false

ShiftFrameKaraoke = (frameLine, sourceStart, frameStart) ->
  AssContext.shiftFrameKaraoke frameLine, sourceStart, frameStart

TrackChannelsConstant = (samples, tolerance = geometryEpsilon, options = nil) ->
  first = samples[1]
  for sample in *samples
    if not options or options.scale
      return false if math.abs(sample.scale.x - first.scale.x) > tolerance
      return false if math.abs(sample.scale.y - first.scale.y) > tolerance
    if not options or options.rotation
      return false if math.abs(sample.rotation - first.rotation) > tolerance
  true

AxisAlignedRotation = (degrees, tolerance = geometryEpsilon) ->
  value = math.abs(tonumber(degrees) or 0) % 180
  value <= tolerance or math.abs(value - 180) <= tolerance

TransformShearRisk = (track, referenceIndex = 1, tolerance = geometryEpsilon, firstSample = 1, lastSample = nil) ->
  return nil unless track and track.samples and #track.samples > 0
  reference = track.samples[math.floor(clamp(referenceIndex, 1, #track.samples))]
  return "zero reference scale", "zero_scale" if math.abs(reference.scale.x or 0) < tolerance or math.abs(reference.scale.y or 0) < tolerance
  coord = track.coordinate_scale or reference.coordinate_scale or {x: 1, y: 1}
  nonuniformCoordinates = math.abs((coord.x or 1) - (coord.y or 1)) > tolerance
  firstSample = math.floor clamp(firstSample, 1, #track.samples)
  lastSample = math.floor clamp(lastSample or #track.samples, firstSample, #track.samples)
  for i = firstSample, lastSample
    sample = track.samples[i]
    rotationDelta = (sample.rotation or 0) - (reference.rotation or 0)
    if nonuniformCoordinates and not AxisAlignedRotation(rotationDelta, tolerance)
      return "source frame #{sample.source_frame}: aspect change plus rotation requires shear (use Power Pin/Perspective)", "aspect_rotation"
  nil

TrackDeformationFlags = (track, referenceIndex = 1, tolerance = geometryEpsilon, firstSample = 1, lastSample = nil) ->
  reference = track.samples[math.floor(clamp(referenceIndex, 1, #track.samples))]
  anisotropic, rotationChanges = false, false
  firstSample = math.floor clamp(firstSample, 1, #track.samples)
  lastSample = math.floor clamp(lastSample or #track.samples, firstSample, #track.samples)
  for i = firstSample, lastSample
    sample = track.samples[i]
    rx = (sample.scale.x or 100) / (reference.scale.x or 100)
    ry = (sample.scale.y or 100) / (reference.scale.y or 100)
    anisotropic = true if math.abs(rx - ry) > tolerance
    rotationChanges = true if math.abs((sample.rotation or 0) - (reference.rotation or 0)) > tolerance
  anisotropic, rotationChanges, reference

LineTransformShearRisk = (line, track, referenceIndex = 1, options = {}, firstSample = 1, lastSample = nil) ->
  anisotropic, rotationChanges, reference = TrackDeformationFlags track, referenceIndex, geometryEpsilon, firstSample, lastSample
  return nil unless anisotropic or rotationChanges
  fields = {"text", "properties", "align", "xPosition", "yPosition", "move", "hasOrg", "hasClip", "styleRef"}
  saved, present = {}, {}
  for field in *fields
    present[field] = line[field] != nil
    saved[field] = line[field]
  probeOptions = CopyTable options
  probeOptions.scale, probeOptions.rotation = true, true
  probeOptions.border, probeOptions.shadow, probeOptions.blur = false, false, false
  ok, prepare_error = pcall PrepareStaticLine, line, probeOptions
  probeText = line.text
  for field in *fields
    if present[field]
      line[field] = saved[field]
    else
      line[field] = nil
  return "could not read the initial geometry: #{prepare_error}" unless ok
  if anisotropic
    rotations = {}
    for pattern in *{"\\frz([%+%-]?[%d%.]+)", "\\fr([%+%-]?[%d%.]+)"}
      for value in probeText\gmatch pattern
        number = tonumber value
        rotations[#rotations + 1] = number if number
    rotations = {0} if #rotations == 0
    for rotation in *rotations
      relative = rotation - (reference.rotation or 0)
      unless AxisAlignedRotation relative
        return "anisotropic scaling over \\frz#{FormatNumber(rotation, 3)} requires shear; use Power Pin/Perspective"
  for tag in *{"fax", "fay", "frx", "fry"}
    pattern = "\\#{tag}([%+%-]?[%d%.]+)"
    for value in probeText\gmatch pattern
      if math.abs(tonumber(value) or 0) > geometryEpsilon
        return "\\#{tag}#{value} cannot be composed faithfully with this deformation; use Power Pin/Perspective"
  nil

EffectiveTransformTrack = (track, referenceIndex, options) ->
  out = CopyTable track
  out.coordinate_scale = track.coordinate_scale
  out.samples = {}
  reference = track.samples[math.floor(clamp(referenceIndex, 1, #track.samples))]
  out.samples[i] = EffectiveTransformSample(sample, reference, options) for i, sample in ipairs track.samples
  out

SampleIndexFor = (frame, source, window, options) ->
  if options.mapping_mode == "Restart on each line"
    frame - source.startFrame + 1
  else
    frame - window.start_frame + 1

InsertFirstOverride = LineOps.prependTag

TryLinearLine = (line, track, window, options) ->
  return nil unless options.optimize_linear and #track.samples >= 2
  return nil if HasUnsafeLinearTags line.text, options
  first_frame = aegisub.frame_from_ms line.start_time
  last_frame = ExclusiveEndFrame line.start_time, line.end_time
  return nil if last_frame - first_frame < 2
  return nil unless TrackChannelsConstant track.samples, geometryEpsilon, options
  PrepareStaticLine line, options
  positions = [call for call in *LineOps.tagCalls(line.text, "pos") when call.top_level]
  return nil unless #positions == 1
  args = LineOps.splitArguments positions[1].value
  posX, posY = tonumber(args[1]), tonumber(args[2])
  return nil unless posX and posY
  referenceIndex = clamp options.reference_frame, 1, #track.samples
  reference = track.samples[referenceIndex]
  times, xs, ys = {}, {}, {}
  for frame = first_frame, last_frame - 1
    LineOps.checkCancelled!
    sampleIndex = SampleIndexFor frame, line, window, options
    sample = track.samples[sampleIndex]
    return nil unless sample
    effectiveSample = EffectiveTransformSample sample, reference, options
    tx, ty, err = MotionPoint posX, posY, effectiveSample, reference, options
    return nil if err
    if options.absolute
      tx = effectiveSample.position.x if options.x_position
      ty = effectiveSample.position.y if options.y_position
    times[#times + 1] = 0.5 * (aegisub.ms_from_frame(frame) + aegisub.ms_from_frame(frame + 1))
    xs[#xs + 1], ys[#ys + 1] = tx, ty
  fit = VectorLinearity times, xs, ys
  return nil unless fit and fit.max <= (tonumber(options.linear_tolerance) or DEFAULTS.linear_tolerance)
  start_x = fit.x.intercept + fit.x.slope * line.start_time
  start_y = fit.y.intercept + fit.y.slope * line.start_time
  end_x = fit.x.intercept + fit.x.slope * line.end_time
  end_y = fit.y.intercept + fit.y.slope * line.end_time
  text = LineOps.removeTagCalls line.text, "pos"
  distance = math.sqrt((end_x - start_x)^2 + (end_y - start_y)^2)
  tag = if distance <= 0.0001
    "\\pos(#{FormatNumber start_x, 2},#{FormatNumber start_y, 2})"
  else
    "\\move(#{FormatNumber start_x, 2},#{FormatNumber start_y, 2},#{FormatNumber end_x, 2},#{FormatNumber end_y, 2})"
  line.text = InsertFirstOverride text, tag
  line.linear_report = fit
  line

ApplyTransformTrack = (subs, window, rawTrack, options) ->
  script_res = GetScriptResolution subs
  track = ScaleTrackCoordinates rawTrack, script_res, options
  referenceIndex = math.floor clamp(options.reference_frame, 1, #track.samples)
  reference = track.samples[referenceIndex]
  return nil, "X or Y scale is zero at the reference frame." if math.abs(reference.scale.x or 0) < scaleEpsilon or math.abs(reference.scale.y or 0) < scaleEpsilon
  effectiveTrack = EffectiveTransformTrack track, referenceIndex, options
  shearRisk = TransformShearRisk effectiveTrack, referenceIndex
  shearApplies = not options.only_clip and shearRisk != nil
  collection = LineCollection subs, window.indices, AcceptDialogueLine, true
  ordered = [line for line in *collection.lines]
  table.sort ordered, (a, b) -> a.number > b.number
  if options.strict_geometry and not options.only_clip
    for source in *ordered
      LineOps.checkCancelled!
      source.startFrame = aegisub.frame_from_ms source.start_time
      source.endFrame = ExclusiveEndFrame source.start_time, source.end_time
      firstSample = math.max 1, source.startFrame - window.start_frame + 1
      lastSample = math.min #effectiveTrack.samples, source.endFrame - window.start_frame
      matrix_risk = TransformShearRisk effectiveTrack, referenceIndex, geometryEpsilon, firstSample, lastSample
      return nil, "Line #{source.humanizedNumber or source.number or '?'}: #{matrix_risk}." if matrix_risk
      line_risk = LineTransformShearRisk source, effectiveTrack, referenceIndex, options, firstSample, lastSample
      return nil, "Line #{source.humanizedNumber or source.number or '?'}: #{line_risk}." if line_risk
  report = {linear: 0, fbf: 0, compressed: 0, groups: {}}
  report.warning = shearRisk if shearApplies
  for source in *ordered
    LineOps.checkCancelled!
    source.startFrame = aegisub.frame_from_ms source.start_time
    source.endFrame = ExclusiveEndFrame source.start_time, source.end_time
    originalText = source.text
    optimized = if options.only_clip then nil else TryLinearLine source, track, window, options
    if optimized
      output = CopyLine optimized
      output.start_time, output.end_time = source.start_time, source.end_time
      subs[source.number] = output
      report.linear += 1
      report.groups[#report.groups + 1] = {index: source.number, count: 1, replace: true}
      continue
    source.text = originalText
    sourceData = ASS\parse source
    fbf = AssContext.line2fbf sourceData, ArchUtil, ASS
    outputs = {}
    for frameLine in *fbf
      LineOps.checkCancelled!
      frame = frameLine.startFrame or aegisub.frame_from_ms frameLine.start_time
      sampleIndex = SampleIndexFor frame, source, window, options
      sample = track.samples[sampleIndex]
      continue unless sample
      startTime, endTime = FrameInterval source, frame
      continue unless startTime
      frameLine.start_time, frameLine.end_time = startTime, endTime
      ShiftFrameKaraoke frameLine, source.start_time, startTime
      PrepareStaticLine frameLine, options unless options.only_clip
      frameLine.text = ApplyTransformText frameLine, sample, reference, options
      outputs[#outputs + 1] = CopyLine frameLine
    before = #outputs
    outputs = CompressOutputLines outputs
    return nil, "Line #{source.humanizedNumber or source.number or '?'}: no Transform output was generated." if #outputs == 0
    report.compressed += before - #outputs
    report.fbf += #outputs
    ReplaceOrInsertOutputs subs, source.number, outputs, true
    report.groups[#report.groups + 1] = {index: source.number, count: #outputs, replace: true}
  report.selection = SelectionFromGroups report.groups
  true, report

Core.ScaleTrackCoordinates = ScaleTrackCoordinates
Core.TransformPoint = TransformPoint
Core.InverseTransformPoint = InverseTransformPoint
Core.MotionPoint = MotionPoint
Core.EffectiveTransformSample = EffectiveTransformSample
Core.TransformClipPath = TransformClipPath
Core.TranslateClipPath = TranslateClipPath
Core.ApplyTransformText = ApplyTransformText
Core.ShiftFrameKaraoke = ShiftFrameKaraoke
Core.TrackChannelsConstant = TrackChannelsConstant
Core.TransformShearRisk = TransformShearRisk
Core.TrackDeformationFlags = TrackDeformationFlags
Core.LineTransformShearRisk = LineTransformShearRisk
Core.EffectiveTransformTrack = EffectiveTransformTrack
Core.TryLinearLine = TryLinearLine
Core.ApplyTransformTrack = ApplyTransformTrack

perspectiveWarningLabels = {
  zero_size: "zero-size text or drawing"
  text_and_drawings: "mixed text and drawing"
  move: "unbaked \\move"
  multiple_tags: "repeated geometric tags"
  transform: "\\t that changes geometry"
}

PerspectiveWarningText = (warnings) ->
  out = {}
  for warning in *warnings or {}
    name, detail = warning[1], warning[2]
    label = perspectiveWarningLabels[name] or tostring(name)
    label ..= " (#{detail})" if detail
    out[#out + 1] = label
  table.concat out, ", "

ValidateQuadTrack = (track) ->
  winding = nil
  for i, sample in ipairs track.samples
    ok, err, area = ValidateQuad sample.quad, 0.5
    return nil, "Source frame #{sample.source_frame}: #{err}" unless ok
    current = area > 0 and 1 or -1
    winding or= current
    return nil, "Quad winding changes at source frame #{sample.source_frame}." if current != winding
  true

PerspectiveTrack = (subs, window, rawTrack, options) ->
  script_res = GetScriptResolution subs
  track = ScaleTrackCoordinates rawTrack, script_res, options
  ok, err = ValidateQuadTrack track
  return nil, err unless ok
  quads = {}
  for sample in *track.samples
    LineOps.checkCancelled!
    quadPoints = {}
    quadPoints[#quadPoints + 1] = {point.x, point.y} for point in *sample.quad
    quads[#quads + 1] = Quad quadPoints
  referenceIndex = math.floor clamp(options.reference_frame, 1, #quads)
  lines = LineCollection subs, window.indices, AcceptAllLines
  okVideo, videoW, videoH = pcall aegisub.video_size
  videoW, videoH = tonumber(videoW), tonumber(videoH)
  return nil, "Could not obtain the video dimensions." unless okVideo and videoW and videoH and videoW > 0 and videoH > 0
  playY = tonumber(lines.meta and (lines.meta.PlayResY or lines.meta.playresy or lines.meta.res_y))
  layoutY = tonumber(lines.meta and (lines.meta.LayoutResY or lines.meta.layoutresy)) or videoH
  return nil, "The script has no valid PlayResY/LayoutResY for perspective tracking." unless playY and playY > 0 and layoutY > 0
  layoutScale = playY / layoutY
  absReferenceFrame = window.start_frame + referenceIndex - 1
  lines\runCallback (collection, line) ->
    line.startFrame = aegisub.frame_from_ms line.start_time
    line.endFrame = ExclusiveEndFrame line.start_time, line.end_time
  relativeLines, toDelete, setupError = {}, {}, nil
  lines\runCallback ((collection, line) ->
    data = ASS\parse line
    toDelete[#toDelete + 1] = line
    line.willdelete = true
    fbf = AssContext.line2fbf data, ArchUtil, ASS
    localReferenceFrame = math.floor clamp(absReferenceFrame, line.startFrame, line.endFrame - 1)
    relative_line = fbf[localReferenceFrame - line.startFrame + 1]
    relativeQuad = quads[localReferenceFrame - window.start_frame + 1]
    unless relative_line and relativeQuad
      setupError = "Line #{line.humanizedNumber or line.number or '?'}: its local reference could not be built."
      return
    relativeLines[relative_line] = relativeQuad
    for fbfLine in *fbf
      LineOps.checkCancelled!
      frame = fbfLine.startFrame or aegisub.frame_from_ms fbfLine.start_time
      startTime, endTime = FrameInterval line, frame
      continue unless startTime
      fbfLine.start_time, fbfLine.end_time = startTime, endTime
      ShiftFrameKaraoke fbfLine, line.start_time, startTime
      fbfLine.rel_line = relative_line
      fbfLine.reference_quad = relativeQuad
      collection\addLine fbfLine
  ), true
  return nil, setupError if setupError
  org_mode = ({
    ["Keep \\org"]: 1
    ["Force stable center"]: 2
    ["Try \\fax0"]: 3
  })[options.org_mode] or 2
  if options.apply_perspective
    for relative_line, relativeQuad in pairs relativeLines
      data = ASS\parse relative_line
      tagvals, width, height, warnings = prepareForPerspective ASS, data
      warning_text = PerspectiveWarningText warnings
      return nil, "Line #{relative_line.number or '?'}: #{warning_text}." if warning_text != ""
      sourceQuad = transformPoints tagvals, width, height, nil, layoutScale
      position = Point tagvals.position.x, tagvals.position.y
      oldScale = {x: tagvals.scale_x.value, y: tagvals.scale_y.value}
      data\removeTags relevantTags
      insertedTags = {}
      insertedTags[#insertedTags + 1] = tagvals[name] for name in *usedTags
      data\insertTags insertedTags
      AlignedRect = (w, h) ->
        result = Quad.rect 1, 1
        result -= Point an_xshift[tagvals.align.value], an_yshift[tagvals.align.value]
        result *= Matrix.diag w, h
        result
      RectAtPosition = (w, h) ->
        result = AlignedRect w, h
        result += relativeQuad\xy_to_uv position
        mapped = {}
        mapped[#mapped + 1] = relativeQuad\uv_to_xy(point) for point in *result
        Quad mapped
      tagsFromQuad tagvals, RectAtPosition(1, 1), width, height, org_mode, layoutScale
      targetQuad = RectAtPosition oldScale.x / tagvals.scale_x.value, oldScale.y / tagvals.scale_y.value
      untransformed = position + AlignedRect width, height
      transformedPoints = {}
      transformedPoints[#transformedPoints + 1] = targetQuad\uv_to_xy(untransformed\xy_to_uv(point)) for point in *sourceQuad
      transformed = Quad transformedPoints
      tagsFromQuad tagvals, transformed, width, height, org_mode, layoutScale
      data\cleanTags 4
      data\commit!
  for relative_line in pairs relativeLines
    data = ASS\parse relative_line
    tags, width, height, warnings = prepareForPerspective ASS, data
    warning_text = PerspectiveWarningText warnings
    return nil, "Reference line: #{warning_text}." if warning_text != ""
    relative_line.tags = tags
    relative_line.quad = transformPoints tags, width, height, nil, layoutScale
  lines\runCallback (collection, line) ->
    return if line.willdelete
    return unless line.rel_line
    relativeQuad = line.reference_quad or relativeLines[line.rel_line]
    return unless relativeQuad
    data = ASS\parse line
    sampleIndex = line.startFrame - window.start_frame + 1
    frameQuad = quads[sampleIndex]
    return unless frameQuad
    tagvals, width, height, warnings = prepareForPerspective ASS, data
    warning_text = PerspectiveWarningText warnings
    error "Moka Perspective: #{warning_text}" if warning_text != ""
    oldScale = {x: tagvals.scale_x.value, y: tagvals.scale_y.value}
    uvPoints = {}
    uvPoints[#uvPoints + 1] = relativeQuad\xy_to_uv(point) for point in *line.rel_line.quad
    uvQuad = Quad uvPoints
    unless options.track_position
      uvQuad += frameQuad\xy_to_uv(Point(tagvals.position.x, tagvals.position.y)) - relativeQuad\xy_to_uv(Point(line.rel_line.tags.position.x, line.rel_line.tags.position.y))
    targetPoints = {}
    targetPoints[#targetPoints + 1] = frameQuad\uv_to_xy(point) for point in *uvQuad
    targetQuad = Quad targetPoints
    data\removeTags relevantTags
    insertedTags = {}
    insertedTags[#insertedTags + 1] = tagvals[name] for name in *usedTags
    data\insertTags insertedTags
    tagsFromQuad tagvals, targetQuad, width, height, org_mode, layoutScale
    if options.track_border_shadow
      for name in *{"outline", "shadow"}
        for coord in *{"x", "y"}
          tagvals["#{name}_#{coord}"].value *= tagvals["scale_#{coord}"].value / oldScale[coord]
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
              projected = frameQuad\uv_to_xy relativeQuad\xy_to_uv(Point(point.x, point.y))
              point.x, point.y = projected\x!, projected\y!
    data\cleanTags 4
    data\commit!
  lines\insertLines!
  lines\deleteLines toDelete
  selection, active = lines\getSelection!
  true, {selection: selection, active: active}

Core.PerspectiveWarningText = PerspectiveWarningText
Core.ValidateQuadTrack = ValidateQuadTrack
Core.PerspectiveTrack = PerspectiveTrack

median = KiteCore.median

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

SolveSystem = (matrix, vector) ->
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
    return nil if best < singularEpsilon
    work[column], work[pivot] = work[pivot], work[column] if pivot != column
    divisor = work[column][column]
    work[column][index] /= divisor for index = column, count + 1
    for row = 1, count
      if row != column
        factor = work[row][column]
        work[row][index] -= factor * work[column][index] for index = column, count + 1
  [work[index][count + 1] for index = 1, count]

PolyPredict = (xs, ys, degree, target) ->
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
    LineOps.checkCancelled!
    value = (xs[index] - center) / scale
    powers = {1}
    powers[power + 1] = powers[power] * value for power = 1, degree
    for row = 1, size
      vector[row] += powers[row] * ys[index]
      matrix[row][column] += powers[row] * powers[column] for column = 1, size
  matrix[index][index] += scaleEpsilon for index = 1, size
  coefficients = SolveSystem matrix, vector
  return median ys unless coefficients
  value, power = (target - center) / scale, 1
  result = 0
  for index = 1, size
    result += coefficients[index] * power
    power *= value
  result

LocalRegression = (values, frames, window = 7, degree = 2) ->
  count = #values
  radius = math.max 1, math.floor((tonumber(window) or 7) / 2)
  out = {}
  for index = 1, count
    LineOps.checkCancelled!
    xs, ys = {}, {}
    for neighbor = math.max(1, index - radius), math.min(count, index + radius)
      if finite values[neighbor]
        xs[#xs + 1] = frames[neighbor] or neighbor
        ys[#ys + 1] = values[neighbor]
    out[index] = PolyPredict(xs, ys, degree, frames[index] or index) or values[index]
  out

CloneTransformTrack = (track) ->
  out = CopyTable track
  out.meta = CopyTable track.meta
  out.diagnostics = [item for item in *track.diagnostics or {}]
  out.samples = {}
  for index, sample in ipairs track.samples or {}
    copy = CopyTable sample
    copy.position = CopyTable sample.position
    copy.scale = CopyTable sample.scale
    copy.anchor = CopyTable sample.anchor if sample.anchor
    copy.coordinate_scale = CopyTable sample.coordinate_scale if sample.coordinate_scale
    out.samples[index] = copy
  out

transformChannels = {
  {"position", "x", 0.25}
  {"position", "y", 0.25}
  {"scale", "x", 0.15}
  {"scale", "y", 0.15}
  {"rotation", nil, 0.08}
  {"opacity", nil, 0.25}
}

ChannelValue = (sample, descriptor) ->
  parent, child = descriptor[1], descriptor[2]
  value = sample[parent]
  if child then value and value[child] else value

SetChannelValue = (sample, descriptor, value) ->
  parent, child = descriptor[1], descriptor[2]
  if child
    sample[parent] or= {}
    sample[parent][child] = value
  else
    sample[parent] = value

PhaseSlipCandidate = (track) ->
  samples = track and track.samples or {}
  return nil if #samples < 4
  steps, scaleSteps, rotationSteps = {}, {}, {}
  for index = 2, #samples
    previous, current = samples[index - 1], samples[index]
    dx = current.position.x - previous.position.x
    dy = current.position.y - previous.position.y
    steps[index] = math.sqrt(dx * dx + dy * dy)
    dsx = (current.scale.x or 100) - (previous.scale.x or 100)
    dsy = (current.scale.y or 100) - (previous.scale.y or 100)
    scaleSteps[index] = math.sqrt(dsx * dsx + dsy * dsy)
    rotationSteps[index] = math.abs((current.rotation or 0) - (previous.rotation or 0))
  movingSteps, sampledScales, sampledRotations = {}, {}, {}
  for index = 2, #samples
    movingSteps[#movingSteps + 1] = steps[index] if steps[index] > geometryEpsilon
    sampledScales[#sampledScales + 1] = scaleSteps[index]
    sampledRotations[#sampledRotations + 1] = rotationSteps[index]
  typical = median movingSteps
  return nil unless typical and typical > 0.0001
  typicalScale = median(sampledScales) or 0
  typicalRotation = median(sampledRotations) or 0
  best = nil
  for index = 2, #samples - 1
    stalled = steps[index] <= math.max(0.02, typical * 0.08)
    resumes = steps[index + 1] >= typical * 0.35
    scaleDuplicate = scaleSteps[index] <= math.max(0.005, typicalScale * 0.25)
    rotationDuplicate = rotationSteps[index] <= math.max(0.01, typicalRotation * 0.75)
    if stalled and resumes and scaleDuplicate and rotationDuplicate
      score = (1 - math.min(1, steps[index] / math.max(typical, geometryEpsilon))) * math.min(1, steps[index + 1] / typical)
      candidate = {
        :index, :score, typical_step: typical, stalled_step: steps[index], resumed_step: steps[index + 1]
        source_frame: samples[index].source_frame
      }
      best = candidate if not best or candidate.score > best.score
  best

RepairTransformPhase = (track, candidate, window = 11, degree = 2) ->
  return CloneTransformTrack(track), nil unless candidate and candidate.index
  out = CloneTransformTrack track
  count, index = #out.samples, candidate.index
  return out, nil if index < 2 or index >= count
  for sampleIndex = index, count - 1
    source_frame = out.samples[sampleIndex].source_frame
    nextSample = out.samples[sampleIndex + 1]
    copy = CopyTable nextSample
    copy.position = CopyTable nextSample.position
    copy.scale = CopyTable nextSample.scale
    copy.anchor = CopyTable(nextSample.anchor) if nextSample.anchor
    copy.coordinate_scale = CopyTable(nextSample.coordinate_scale) if nextSample.coordinate_scale
    copy.source_frame = source_frame
    copy.phase_repaired = true
    out.samples[sampleIndex] = copy
  last = CopyTable out.samples[count]
  last.position = CopyTable out.samples[count].position
  last.scale = CopyTable out.samples[count].scale
  last.anchor = CopyTable(out.samples[count].anchor) if out.samples[count].anchor
  firstFit = math.max 1, count - math.max(3, tonumber(window) or 11)
  for descriptor in *transformChannels
    xs, ys = {}, {}
    for sampleIndex = firstFit, count - 1
      value = ChannelValue out.samples[sampleIndex], descriptor
      if finite value
        xs[#xs + 1] = sampleIndex
        ys[#ys + 1] = value
    prediction = PolyPredict xs, ys, degree, count
    SetChannelValue last, descriptor, prediction if prediction
  last.source_frame = track.samples[count].source_frame
  last.phase_repaired = true
  out.samples[count] = last
  message = "Removed duplicate sample at row #{index} (source frame #{candidate.source_frame or '?'}); only the new tail sample was extrapolated."
  out.diagnostics[#out.diagnostics + 1] = message
  out, message

CleanupTransformTrack = (track, options) ->
  mode = options.cleanup_mode or "Off"
  return CloneTransformTrack(track), {mode: mode, changed: 0} if mode == "Off"
  out = CloneTransformTrack track
  count = #out.samples
  referenceIndex = math.floor clamp(options.reference_frame or 1, 1, count)
  frames = [index for index = 1, count]
  changed = 0
  for descriptor in *transformChannels
    values = [ChannelValue(sample, descriptor) for sample in *out.samples]
    continue unless #values == count and finite(values[1])
    threshold = descriptor[3]
    cleaned = [value for value in *values]
    if mode == "Protective"
      low, high = percentile(values, 0.05), percentile(values, 0.95)
      if low and high and high - low <= threshold
        cleaned[index] = values[referenceIndex] for index = 1, count
      else
        fit = LinearFit frames, values
        absoluteResiduals = {}
        if fit
          absoluteResiduals[#absoluteResiduals + 1] = math.abs(value) for value in *fit.residuals
        residualP95 = math.huge
        residualP95 = percentile(absoluteResiduals, 0.95) or math.huge if fit
        if fit and residualP95 <= threshold
          cleaned[index] = fit.intercept + fit.slope * frames[index] for index = 1, count
        else
          for index = 2, count - 1
            neighborhood = {values[index - 1], values[index + 1]}
            localCenter = median neighborhood
            localScale = mad neighborhood, localCenter
            if localCenter and math.abs(values[index] - localCenter) > math.max(threshold * 2, localScale * 4)
              cleaned[index] = localCenter
    else
      smooth = LocalRegression values, frames, options.cleanup_window, options.cleanup_degree
      strength = clamp((tonumber(options.cleanup_strength) or 100) / 100, 0, 1)
      cleaned[index] = values[index] + (smooth[index] - values[index]) * strength for index = 1, count
    anchorDelta = values[referenceIndex] - cleaned[referenceIndex]
    for index = 1, count
      LineOps.checkCancelled!
      cleaned[index] += anchorDelta
      if math.abs(cleaned[index] - values[index]) > numericEpsilon
        SetChannelValue out.samples[index], descriptor, cleaned[index]
        changed += 1
  report = {mode: mode, :changed}
  out, report

PrepareTransformTrack = (track, options) ->
  working = CloneTransformTrack track
  report = {phase: nil, repaired: false, cleanup: nil}
  candidate = PhaseSlipCandidate working
  report.phase = candidate
  if candidate and options.phase_mode == "Repair duplicate sample"
    working, report.phase_message = RepairTransformPhase working, candidate, options.cleanup_window, options.cleanup_degree
    report.repaired = true
  working, report.cleanup = CleanupTransformTrack working, options
  working.preprocess_report = report
  working, report

Core.PhaseSlipCandidate = PhaseSlipCandidate
Core.RepairTransformPhase = RepairTransformPhase
Core.CleanupTransformTrack = CleanupTransformTrack
Core.PrepareTransformTrack = PrepareTransformTrack

ReadClipboard = ->
  ok, value = pcall -> clipboard.get!
  if ok and value then tostring value else ""

ShowMessage = (title, message, height = 16) ->
  KiteUI.message message, {title: title or script_name, :height}

SampleCountForSelection = (subs, window, mapping_mode) ->
  return window.frame_count unless mapping_mode == "Restart on each line"
  largest = 1
  for index in *window.indices
    line = subs[index]
    first = aegisub.frame_from_ms line.start_time
    last = ExclusiveEndFrame line.start_time, line.end_time
    largest = math.max largest, last - first
  largest

Core.CurrentVideoFrame = ->
  properties = LineOps.projectProperties!
  frame = tonumber(properties and properties.video_position)
  return nil unless finite(frame) and frame >= 0
  math.floor frame

Core.ReferenceRowForWindow = (window, fallback = DEFAULTS.reference_frame) ->
  fallback = math.max 1, math.floor(tonumber(fallback) or DEFAULTS.reference_frame)
  return fallback unless window
  currentFrame = Core.CurrentVideoFrame!
  start_frame = tonumber window.start_frame
  frame_count = tonumber window.frame_count
  if not frame_count and start_frame and tonumber(window.end_frame)
    frame_count = tonumber(window.end_frame) - start_frame
  return fallback unless currentFrame and start_frame and frame_count and frame_count > 0
  reference_row = currentFrame - start_frame + 1
  if reference_row >= 1 and reference_row <= frame_count then reference_row else fallback

MotionDialog = (inverse = false, window = nil, draft = nil) ->
  action = if inverse then "Revert" else "Apply"
  reference_row = Core.ReferenceRowForWindow window
  controls = {
    {class: "label", label: "Mocha / After Effects Transform data or a text-file path:", x: 0, y: 0, width: 12, height: 1}
    {class: "textbox", name: "input", text: ReadClipboard!, x: 0, y: 1, width: 12, height: 11}
    {class: "label", label: "First data row", x: 0, y: 12, width: 2, height: 1}
    {class: "intedit", name: "sample_start", value: 1, min: 1, x: 2, y: 12, width: 1, height: 1}
    {class: "label", label: "Reference row", x: 3, y: 12, width: 2, height: 1}
    {class: "intedit", name: "reference_frame", value: reference_row, min: 1, x: 5, y: 12, width: 1, height: 1}
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
    {class: "intedit", name: "cleanup_window", value: 9, min: 3, x: 9, y: 15, width: 1, height: 1}
    {class: "label", label: "Degree", x: 10, y: 15, width: 1, height: 1}
    {class: "intedit", name: "cleanup_degree", value: 2, min: 1, max: 3, x: 11, y: 15, width: 1, height: 1}
    {class: "checkbox", name: "strict_sync", label: "Strict frame/FPS/PAR synchronization", value: DEFAULTS.strict_sync, x: 0, y: 16, width: 5, height: 1}
  }
  table.insert controls, {class: "checkbox", name: "optimize_fbf", label: "Optimize FBF states (0.05 px)", value: DEFAULTS.optimize_fbf, x: 5, y: 16, width: 7, height: 1} unless inverse
  if draft
    for control in *controls
      continue unless control.name and draft[control.name] != nil
      if control.class == "textbox" then control.text = draft[control.name]
      else control.value = draft[control.name]
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
  values.optimize_fbf = false if inverse
  values

ShapeDialog = (mode, script_res, draft = nil) ->
  labels = {clip: "Create Clip", iclip: "Create Inverse Clip", shape: "Create Vector Drawing"}
  action = labels[mode]
  controls = {
    {class: "label", label: "Mocha AE Mask Data, Shake SSF 4.0, legacy Bezier data, or a text-file path:", x: 0, y: 0, width: 12, height: 1}
    {class: "textbox", name: "input", text: ReadClipboard!, x: 0, y: 1, width: 12, height: 12}
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
    {class: "intedit", name: "layer_offset", value: 1, x: 9, y: 14, width: 1, height: 1}
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
  if draft
    for control in *controls
      continue unless control.name and draft[control.name] != nil
      if control.class == "textbox" then control.text = draft[control.name]
      else control.value = draft[control.name]
  pressed, values = aegisub.dialog.display controls, {action, "Cancel"}, {ok: action, close: "Cancel"}
  return nil unless pressed == action
  values.output_mode = mode
  values

PowerPinDialog = (window = nil, draft = nil) ->
  reference_row = Core.ReferenceRowForWindow window
  controls = {
    {class: "label", label: "Mocha CC Power Pin / Corner Pin data or a text-file path:", x: 0, y: 0, width: 12, height: 1}
    {class: "textbox", name: "input", text: ReadClipboard!, x: 0, y: 1, width: 12, height: 12}
    {class: "label", label: "First data row", x: 0, y: 13, width: 2, height: 1}
    {class: "intedit", name: "sample_start", value: 1, min: 1, x: 2, y: 13, width: 1, height: 1}
    {class: "label", label: "Reference row", x: 3, y: 13, width: 2, height: 1}
    {class: "intedit", name: "reference_frame", value: reference_row, min: 1, x: 5, y: 13, width: 1, height: 1}
    {class: "checkbox", name: "apply_perspective", label: "Perspective", value: true, x: 0, y: 14, width: 2, height: 1}
    {class: "checkbox", name: "track_position", label: "Position", value: true, x: 2, y: 14, width: 2, height: 1}
    {class: "checkbox", name: "track_border_shadow", label: "Border / shadow", value: true, x: 4, y: 14, width: 3, height: 1}
    {class: "checkbox", name: "track_clip", label: "Clips", value: true, x: 7, y: 14, width: 2, height: 1}
    {class: "label", label: "Origin mode", x: 0, y: 15, width: 2, height: 1}
    {class: "dropdown", name: "org_mode", items: {"Keep \\org", "Force stable center", "Try \\fax0"}, value: "Force stable center", x: 2, y: 15, width: 4, height: 1}
    {class: "checkbox", name: "strict_sync", label: "Strict frame/FPS/PAR synchronization", value: DEFAULTS.strict_sync, x: 0, y: 16, width: 5, height: 1}
  }
  if draft
    for control in *controls
      continue unless control.name and draft[control.name] != nil
      if control.class == "textbox" then control.text = draft[control.name]
      else control.value = draft[control.name]
  pressed, values = aegisub.dialog.display controls, {"Apply Power Pin", "Cancel"}, {ok: "Apply Power Pin", close: "Cancel"}
  return nil unless pressed == "Apply Power Pin"
  values.use_source_meta = true
  values.scale_to_script = true
  values

ApplyAtomically = (subs, callback) ->
  state = LineOps.snapshot subs
  ok, result, details = pcall ->
    callbackResult, callbackDetails = callback!
    LineOps.checkCancelled!
    callbackResult, callbackDetails
  return ok, result, details if ok and result
  restored, restore_error = pcall LineOps.restore, subs, state
  unless restored
    rollback_message = "Rollback failed: #{tostring(restore_error or 'unknown error')}"
    if ok
      details = "#{tostring(details or 'No output was generated.')}\n#{rollback_message}"
    else
      result = "#{tostring(result or 'Operation failed.')}\n#{rollback_message}"
  LineOps.checkCancelled!
  ok, result, details

FBFOptimizer.optionsDialog = ->
  labels = [mode.label for mode in *FBFOptimizer.MODES]
  controls = {
    {class: "label", label: "Merge consecutive compatible FBF states without accumulating positional drift.", x: 0, y: 0, width: 8, height: 1}
    {class: "label", label: "Comparison", x: 0, y: 1, width: 1, height: 1}
    {class: "dropdown", name: "mode", items: labels, value: labels[1], x: 1, y: 1, width: 3, height: 1}
    {class: "label", label: "Duration-dependent \\move, \\t, fades, and karaoke are protected.", x: 0, y: 2, width: 8, height: 1}
  }
  button, values = aegisub.dialog.display controls, {"Optimize", "Cancel"}, {ok: "Optimize", close: "Cancel"}
  return nil unless button == "Optimize"
  tolerance = FBFOptimizer.toleranceForMode values.mode
  return nil unless tolerance != nil
  {mode: values.mode, :tolerance}

FBFOptimizer.main = (subs, selection) ->
  items = FBFOptimizer.selectionItems subs, selection
  if #items < 2
    ShowMessage "Moka Motion / Optimizer", "Select at least two uncommented FBF dialogue lines.", 6
    return selection
  options = FBFOptimizer.optionsDialog!
  return selection unless options
  plan = FBFOptimizer.buildPlan items, options.tolerance
  if plan.merged == 0
    ShowMessage "Moka Motion / Optimizer", "No consecutive temporal states are compatible with #{options.mode}.", 6
    return selection
  ok, result, details = ApplyAtomically subs, ->
    optimized = FBFOptimizer.applyPlan subs, plan
    true, {selection: optimized}
  unless ok and result
    ShowMessage "Moka Motion / Optimizer", ok and "No output was generated." or result, 10
    return selection
  aegisub.set_undo_point "Moka Motion: Optimizer"
  ShowMessage "Moka Motion / Optimizer", "Optimization complete.\nLines: #{plan.before} -> #{plan.after}\nMerged: #{plan.merged}\nLongest run: #{plan.longest_run} states\nTemporal tracks: #{#plan.lanes}\nProtected by duration-dependent tags: #{plan.unsafe_count}", 9
  details.selection

Core.OptimizeTransformReport = (subs, report, enabled) ->
  if enabled and report and report.selection and #report.selection > 1
    report.selection, report.optimizer = FBFOptimizer.optimize subs, report.selection, FBFOptimizer.DEFAULT_TOLERANCE
  report

MotionMain = (inverse = false) ->
  (subs, sel, active) ->
    window, err = SelectionWindow subs, sel
    unless window
      ShowMessage script_name, err
      return sel
    draft = nil
    while true
      options = MotionDialog inverse, window, draft
      return sel unless options
      draft = options
      track, parseError = ParseInput options.input
      unless track and track.kind == "transform"
        ShowMessage "Moka Motion / #{inverse and 'Revert Motion' or 'Apply Motion'}", parseError or "The pasted data is not a Transform export."
        continue
      required = SampleCountForSelection subs, window, options.mapping_mode
      sliced, sliceError = SliceTrack track, options.sample_start, required, options.strict_sync == true
      unless sliced
        ShowMessage script_name, sliceError
        continue
      syncInfo, syncError = ValidateSync sliced, window, options.strict_sync == true, options.mapping_mode == "Restart on each line"
      unless syncInfo
        ShowMessage script_name, syncError
        continue
      options.reference_frame = math.floor clamp(options.reference_frame, 1, #sliced.samples)
      prepared, prep = PrepareTransformTrack sliced, options
      ok, result, details = ApplyAtomically subs, ->
        applied, report = ApplyTransformTrack subs, window, prepared, options
        return applied, report unless applied
        Core.OptimizeTransformReport subs, report, options.optimize_fbf
        applied, report
      unless ok and result
        ShowMessage script_name, ok and (details or "No output was generated.") or result
        continue
      aegisub.set_undo_point "#{script_name}: #{inverse and 'Revert Motion' or 'Apply Motion'}"
      notes = {}
      notes[#notes + 1] = "Geometry: #{details.warning}" if details and details.warning
      if prep.phase
        notes[#notes + 1] = "Duplicate-sample candidate: row #{prep.phase.index}, source frame #{prep.phase.source_frame or '?'}, score #{FormatNumber(prep.phase.score * 100, 1)}%."
      notes[#notes + 1] = prep.phase_message if prep.phase_message
      notes[#notes + 1] = "Cleanup changed #{prep.cleanup.changed} channel values." if prep.cleanup and prep.cleanup.changed > 0
      if details and details.optimizer
        optimizer = details.optimizer
        notes[#notes + 1] = "FBF Optimizer: #{optimizer.before} -> #{optimizer.after} lines (#{optimizer.merged} merged)."
      ShowMessage script_name, table.concat(notes, "\n"), 6 if #notes > 0
      if details and details.selection and #details.selection > 0
        return details.selection, details.selection[1]
      else
        return sel

ShapeMain = (mode) ->
  (subs, sel, active) ->
    window, err = SelectionWindow subs, sel
    unless window
      ShowMessage script_name, err
      return sel
    scriptResolution = GetScriptResolution subs
    draft = nil
    while true
      options = ShapeDialog mode, scriptResolution, draft
      return sel unless options
      draft = options
      track, parseError = ParseInput options.input
      unless track and track.kind == "shape"
        ShowMessage script_name, parseError or "The pasted data is not shape or mask data."
        continue
      required = SampleCountForSelection subs, window, options.mapping_mode
      sliced, sliceError = SliceTrack track, options.sample_start, required, options.strict_sync == true
      unless sliced
        ShowMessage script_name, sliceError
        continue
      syncInfo, syncError = ValidateSync sliced, window, options.strict_sync == true, options.mapping_mode == "Restart on each line"
      unless syncInfo
        ShowMessage script_name, syncError
        continue
      ok, result, details = ApplyAtomically subs, -> ApplyShapeTrack subs, window, sliced, options
      unless ok and result
        ShowMessage script_name, ok and (details or "No shape output was generated.") or result
        continue
      aegisub.set_undo_point "#{script_name}: #{mode}"
      if details and details.selection and #details.selection > 0
        return details.selection, details.selection[1]
      else
        return sel

PowerPinMain = (subs, sel, active) ->
  window, err = SelectionWindow subs, sel
  unless window
    ShowMessage script_name, err
    return sel
  draft = nil
  while true
    options = PowerPinDialog window, draft
    return sel unless options
    draft = options
    track, parseError = ParseInput options.input
    unless track and track.kind == "perspective"
      ShowMessage script_name, parseError or "The pasted data is not CC Power Pin or Corner Pin data."
      continue
    sliced, sliceError = SliceTrack track, options.sample_start, window.frame_count, options.strict_sync == true
    unless sliced
      ShowMessage script_name, sliceError
      continue
    syncInfo, syncError = ValidateSync sliced, window, options.strict_sync == true
    unless syncInfo
      ShowMessage script_name, syncError
      continue
    options.reference_frame = math.floor clamp(options.reference_frame, 1, #sliced.samples)
    valid, validationError = ValidateQuadTrack sliced
    unless valid
      ShowMessage script_name, validationError
      continue
    ok, result, details = ApplyAtomically subs, -> PerspectiveTrack subs, window, sliced, options
    unless ok and result
      ShowMessage script_name, ok and (details or "No perspective output was generated.") or result
      continue
    aegisub.set_undo_point "#{script_name}: Apply Power Pin"
    if details and details.selection and #details.selection > 0
      return details.selection, details.active or details.selection[1]
    else
      return sel

InspectMain = (subs, sel, active) ->
  controls = {
    {class: "label", label: "Paste Mocha data or a text-file path:", x: 0, y: 0, width: 12, height: 1}
    {class: "textbox", name: "input", text: ReadClipboard!, x: 0, y: 1, width: 12, height: 14}
  }
  pressed, values = aegisub.dialog.display controls, {"Inspect", "Cancel"}, {ok: "Inspect", close: "Cancel"}
  return sel unless pressed == "Inspect"
  track, err = ParseInput values.input
  unless track
    ShowMessage "Moka Motion / Inspect", err
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
    candidate = PhaseSlipCandidate track
    if candidate
      lines[#lines + 1] = "Duplicate-sample candidate: row #{candidate.index}, source frame #{candidate.source_frame or '?'}, score #{FormatNumber(candidate.score * 100, 1)}%."
    else
      lines[#lines + 1] = "Duplicate-sample candidate: none."
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Diagnostics:"
  if track.diagnostics and #track.diagnostics > 0
    lines[#lines + 1] = "- #{item}" for item in *track.diagnostics
  else
    lines[#lines + 1] = "- None"
  ShowMessage "Moka Motion / Inspect", table.concat(lines, "\n"), 18
  sel

SetPositionText = (text, x, y) ->
  tag = "\\pos(#{FormatNumber x, 3},#{FormatNumber y, 3})"
  replaced, changed = LineOps.replaceTagCall text, "pos", tag, true
  return replaced if changed
  replaced, changed = LineOps.replaceTagCall replaced, "move", tag, true
  return replaced if changed
  InsertFirstOverride replaced, tag

ShiftLinkedGeometry = (text, dx, dy) ->
  return text if math.abs(dx) < numericEpsilon and math.abs(dy) < numericEpsilon
  LineOps.mapTagCalls text, {"org", "clip", "iclip"}, ((call) ->
    content = call.value\sub 2, -2
    if call.name == "org"
      args = LineOps.splitArguments call.value
      x, y = KiteCore.finiteNumber(args[1]), KiteCore.finiteNumber(args[2])
      return nil unless call.top_level and #args == 2 and x and y
      return "\\org(#{FormatNumber(x + dx, 3)},#{FormatNumber(y + dy, 3)})"
    path, rectangle = ClipToFloatPath content
    return nil unless path
    if rectangle
      values = LineOps.splitArguments content
      return "\\#{call.raw_name}(#{FormatNumber(tonumber(values[1]) + dx, 3)},#{FormatNumber(tonumber(values[2]) + dy, 3)},#{FormatNumber(tonumber(values[3]) + dx, 3)},#{FormatNumber(tonumber(values[4]) + dy, 3)})"
    "\\#{call.raw_name}(#{TranslateClipPath(path, dx, dy, 3)})"
  ), {top_level_only: false}

AuthoredSignature = (text) ->
  clean = LineOps.removeTagCalls text, {"pos", "move", "org", "clip", "iclip", "fscx", "fscy", "frz", "fr", "bord", "xbord", "ybord", "shad", "xshad", "yshad", "blur"}
  clean\gsub "%s+", ""

BuildRefineryTracks = (subs, sel) ->
  buckets, order = {}, {}
  sorted = LineOps.normalizeIndices subs, sel
  for index in *sorted
    line = subs[index]
    if line and line.class == "dialogue" and not line.comment
      position = LineOps.position line.text
      if position and finite(position.x) and finite(position.y)
        startFrame = aegisub.frame_from_ms line.start_time
        endFrame = ExclusiveEndFrame line.start_time, line.end_time
        continue unless startFrame and endFrame and line.end_time > line.start_time
        key = table.concat {tostring(line.layer or 0), tostring(line.style or ""), tostring(line.actor or ""), LineOps.visibleText(line.text)}, "\31"
        unless buckets[key]
          buckets[key] = {}
          order[#order + 1] = key
        buckets[key][#buckets[key] + 1] = {
          :index, :line, :position
          start_frame: startFrame
          end_frame: endFrame
          signature: AuthoredSignature line.text
        }
  tracks = {}
  for key in *order
    items = buckets[key]
    table.sort items, (a, b) -> if a.start_frame == b.start_frame then a.index < b.index else a.start_frame < b.start_frame
    current, previousEnd = {}, nil
    for item in *items
      if #current > 0 and previousEnd and item.start_frame > previousEnd + 1
        tracks[#tracks + 1] = {key: key, items: current}
        current = {}
      current[#current + 1] = item
      previousEnd = item.end_frame
    tracks[#tracks + 1] = {key: key, items: current} if #current > 0
  tracks

DetectAuthoredPeriod = (track) ->
  count = #track.items
  return nil if count < 4
  signatures = [item.signature for item in *track.items]
  prefix = {0}
  for index = 2, count
    LineOps.checkCancelled!
    matched = prefix[index - 1]
    while matched > 0 and signatures[index] != signatures[matched + 1]
      matched = prefix[matched]
    matched += 1 if signatures[index] == signatures[matched + 1]
    prefix[index] = matched
  signaturePeriod = count - prefix[count]
  return signaturePeriod if signaturePeriod >= 2 and signaturePeriod <= math.floor(count / 2)
  frames = [item.start_frame for item in *track.items]
  xs = [item.position.x for item in *track.items]
  ys = [item.position.y for item in *track.items]
  fit_x, fit_y = LinearFit(frames, xs), LinearFit(frames, ys)
  return nil unless fit_x and fit_y
  residuals, magnitudes = {}, {}
  for index = 1, count
    LineOps.checkCancelled!
    point = {x: fit_x.residuals[index], y: fit_y.residuals[index]}
    residuals[index] = point
    magnitudes[index] = math.sqrt(point.x^2 + point.y^2)
  amplitude = percentile(magnitudes, 0.90) or 0
  return nil if amplitude < 0.35
  for period = 2, math.floor(count / 2)
    LineOps.checkCancelled!
    errors = {}
    for index = period + 1, count
      dx = residuals[index].x - residuals[index - period].x
      dy = residuals[index].y - residuals[index - period].y
      errors[#errors + 1] = math.sqrt(dx * dx + dy * dy)
    return period if (percentile(errors, 0.90) or math.huge) <= math.max(0.15, amplitude * 0.08)
  nil

PhaseAdjustSeries = (values, frames, period) ->
  count = #values
  offsets = [0 for index = 1, math.max(1, period or 1)]
  unless period and period > 1
    copied = {}
    copied[index] = value for index, value in ipairs values
    return copied, offsets
  fit = LinearFit frames, values
  unless fit
    copied = {}
    copied[index] = value for index, value in ipairs values
    return copied, offsets
  groups = [{} for index = 1, period]
  for index = 1, count
    LineOps.checkCancelled!
    phase = (index - 1) % period + 1
    groups[phase][#groups[phase] + 1] = fit.residuals[index]
  offsets[phase] = median(groups[phase]) or 0 for phase = 1, period
  base = [values[index] - offsets[(index - 1) % period + 1] for index = 1, count]
  base, offsets

ReadScalar = (text, name) ->
  call = LineOps.lastTagCall text, (name == "frz" and {"fr", "frz"} or name), true
  call and KiteCore.finiteNumber(call.value) or nil

SetScalarText = (text, name, value) ->
  LineOps.replaceTagCall text, (name == "frz" and {"fr", "frz"} or name), ((call) -> "\\#{call.raw_name}#{FormatNumber(value, 3)}"), true

RefineSeries = (values, frames, period, options) ->
  base, offsets = PhaseAdjustSeries values, frames, period
  smooth = LocalRegression base, frames, options.window, options.degree
  residuals = [math.abs(base[index] - smooth[index]) for index = 1, #base]
  center = median(residuals) or 0
  threshold = math.max(tonumber(options.threshold) or 0.35, center + 3 * mad(residuals, center))
  strength = clamp((tonumber(options.strength) or 100) / 100, 0, 1)
  out = {}
  for index = 1, #base
    use = options.scope == "Whole track" or residuals[index] > threshold
    value = if use then base[index] + (smooth[index] - base[index]) * strength else base[index]
    phase = if period and period > 1 then (index - 1) % period + 1 else 1
    out[index] = value + (offsets[phase] or 0)
  out, threshold

RefineryReport = (tracks) ->
  lines = {"Tracks: #{#tracks}", ""}
  for track_index, track in ipairs tracks
    period = DetectAuthoredPeriod track
    steps = {}
    for index = 2, #track.items
      dx = track.items[index].position.x - track.items[index - 1].position.x
      dy = track.items[index].position.y - track.items[index - 1].position.y
      steps[#steps + 1] = math.sqrt(dx * dx + dy * dy)
    frames = [item.start_frame for item in *track.items]
    xs = [item.position.x for item in *track.items]
    ys = [item.position.y for item in *track.items]
    base_x = PhaseAdjustSeries xs, frames, period
    base_y = PhaseAdjustSeries ys, frames, period
    pseudo_samples = {}
    pseudo_samples[index] = {source_frame: frames[index], position: {x: base_x[index], y: base_y[index]}, scale: {x: 100, y: 100}, rotation: 0} for index = 1, #frames
    pseudo = {samples: pseudo_samples}
    candidate = PhaseSlipCandidate pseudo
    lines[#lines + 1] = "#{track_index}. #{#track.items} samples, frames #{frames[1]}..#{frames[#frames]}, median step #{FormatNumber(median(steps) or 0, 3)}, authored period #{period or 'none'}."
    lines[#lines + 1] = "   Duplicate-frame candidate at sample #{candidate.index}." if candidate
  table.concat lines, "\n"

ApplyRefinery = (subs, tracks, options) ->
  changedIndices, changed, candidates = {}, 0, 0
  for track in *tracks
    LineOps.checkCancelled!
    count = #track.items
    retarget = options.action == "Retarget Start" or options.action == "Retarget End"
    continue if count < (retarget and 1 or 3)
    frames = [item.start_frame for item in *track.items]
    xs = [item.position.x for item in *track.items]
    ys = [item.position.y for item in *track.items]
    period = options.protect_authored and DetectAuthoredPeriod(track) or nil
    nextX, nextY = {}, {}
    nextX[index] = value for index, value in ipairs xs
    nextY[index] = value for index, value in ipairs ys
    if options.action == "Smooth / Denoise"
      nextX = RefineSeries xs, frames, period, options
      nextY = RefineSeries ys, frames, period, options
    elseif options.action == "Repair Duplicate Frame"
      base_x, offsetsX = PhaseAdjustSeries xs, frames, period
      base_y, offsetsY = PhaseAdjustSeries ys, frames, period
      pseudo_samples = {}
      pseudo_samples[index] = {source_frame: frames[index], position: {x: base_x[index], y: base_y[index]}, scale: {x: 100, y: 100}, rotation: 0} for index = 1, count
      pseudo = {samples: pseudo_samples}
      candidate = PhaseSlipCandidate pseudo
      if candidate
        candidates += 1
        repaired = RepairTransformPhase pseudo, candidate, options.window, options.degree
        for index = 1, count
          LineOps.checkCancelled!
          phase = if period then (index - 1) % period + 1 else 1
          nextX[index] = repaired.samples[index].position.x + (offsetsX[phase] or 0)
          nextY[index] = repaired.samples[index].position.y + (offsetsY[phase] or 0)
    elseif options.action == "Retarget Start" or options.action == "Retarget End"
      sideStart = options.action == "Retarget Start"
      anchorIndex = sideStart and 1 or count
      dx = (tonumber(options.target_x) or xs[anchorIndex]) - xs[anchorIndex]
      dy = (tonumber(options.target_y) or ys[anchorIndex]) - ys[anchorIndex]
      for index = 1, count
        LineOps.checkCancelled!
        t = (index - 1) / math.max(1, count - 1)
        weight = if count == 1 then 1 else (if sideStart then 1 - (t * t * (3 - 2 * t)) else t * t * (3 - 2 * t))
        nextX[index] = xs[index] + dx * weight
        nextY[index] = ys[index] + dy * weight
    for index, item in ipairs track.items
      LineOps.checkCancelled!
      dx, dy = nextX[index] - xs[index], nextY[index] - ys[index]
      if math.abs(dx) > numericEpsilon or math.abs(dy) > numericEpsilon
        line = CopyLine subs[item.index]
        text = SetPositionText line.text, nextX[index], nextY[index]
        text = ShiftLinkedGeometry text, dx, dy if options.linked_geometry
        line.text = text
        subs[item.index] = line
        changedIndices[item.index] = true
    if options.include_transforms and options.action == "Smooth / Denoise"
      for name in *{"fscx", "fscy", "frz", "bord", "xbord", "ybord", "shad", "xshad", "yshad", "blur"}
        values = [ReadScalar(item.line.text, name) for item in *track.items]
        complete = #values == count
        complete = false for value in *values when not finite value
        continue unless complete
        refined = RefineSeries values, frames, period, options
        for index, item in ipairs track.items
          LineOps.checkCancelled!
          continue if math.abs(refined[index] - values[index]) <= numericEpsilon
          line = CopyLine subs[item.index]
          line.text = SetScalarText line.text, name, refined[index]
          subs[item.index] = line
          changedIndices[item.index] = true
  changed += 1 for _ in pairs changedIndices
  changed, candidates

RefineryDialog = ->
  controls = {
    {class: "label", label: "Operation", x: 0, y: 0, width: 2, height: 1}
    {class: "dropdown", name: "action", items: {"Analyze", "Smooth / Denoise", "Repair Duplicate Frame", "Retarget Start", "Retarget End"}, value: "Analyze", x: 2, y: 0, width: 4, height: 1}
    {class: "label", label: "Scope", x: 6, y: 0, width: 1, height: 1}
    {class: "dropdown", name: "scope", items: {"Outliers only", "Whole track"}, value: "Outliers only", x: 7, y: 0, width: 3, height: 1}
    {class: "label", label: "Window", x: 0, y: 1, width: 1, height: 1}
    {class: "intedit", name: "window", value: 9, min: 3, x: 1, y: 1, width: 1, height: 1}
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

RefineryMain = (subs, sel, active) ->
  tracks = BuildRefineryTracks subs, sel
  if #tracks == 0
    ShowMessage "Moka Motion / Track Refinery", "Select contiguous FBF dialogue lines containing \\pos."
    return sel
  options = RefineryDialog!
  return sel unless options
  if options.action == "Analyze"
    ShowMessage "Moka Motion / Track Refinery", RefineryReport(tracks), 20
    return sel
  ok, result, details = ApplyAtomically subs, ->
    changed, candidates = ApplyRefinery subs, tracks, options
    true, {changed: changed, candidates: candidates}
  unless ok and result
    ShowMessage script_name, ok and details or result
    return sel
  changed, candidates = details.changed, details.candidates
  if changed > 0
    aegisub.set_undo_point "#{script_name}: Track Refinery / #{options.action}"
  message = "#{options.action}: #{changed} lines changed."
  message ..= " Duplicate-frame candidates repaired: #{candidates}." if options.action == "Repair Duplicate Frame"
  ShowMessage "Moka Motion / Track Refinery", message, 6
  sel

Core.BuildRefineryTracks = BuildRefineryTracks
Core.DetectAuthoredPeriod = DetectAuthoredPeriod
Core.ApplyRefinery = ApplyRefinery

PathParts = (path) ->
  directory, name = tostring(path or "")\match "^(.*)[\\/]([^\\/]+)$"
  directory or= "."
  name or= tostring(path or "")
  stem = name\gsub "%.[^%.]+$", ""
  directory, stem

trimSettingsDefaults = {
  encoders: {
    x264: ""
    ffmpeg: ""
  }
}

trimSettingsStore = nil

EncoderSettings = ->
  trimSettingsStore or= KiteUI.settings script_namespace, script_version, trimSettingsDefaults
  trimSettingsStore\values "encoders"

EncoderCommand = (value, fallback) ->
  value = trim value
  if value == "" then fallback else value

TrimSettingsMain = ->
  settings = EncoderSettings!
  controls = {
    {class: "label", label: "FFmpeg handles exact seeking; x264 is the automatic fallback. Blank fields use PATH.", x: 0, y: 0, width: 10, height: 1}
    {class: "label", label: "x264 fallback", x: 0, y: 1, width: 2, height: 1}
    {class: "edit", name: "x264", value: settings.x264, x: 2, y: 1, width: 8, height: 1}
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
    return unless button == "Save"
    trimSettingsStore\update "encoders", values
    ok, err = trimSettingsStore\write!
    ShowMessage script_name, ok and "Encoder settings saved." or "Could not save encoder settings:\n#{err}", 5
    return if ok

PowerShellLiteral = (value) ->
  "'" .. tostring(value or "")\gsub("'", "''") .. "'"

RunHiddenCommand = PyBridge.runProcess

TrimPaths = (source, window, tempRoot) ->
  directory, stem = PathParts source
  end_frame = window.end_frame - 1
  suffix = "[#{window.start_frame}-#{end_frame}]"
  tempRoot = trim(tempRoot) != "" and tempRoot or PyBridge.tempRoot!
  return nil, "The temporary directory is unavailable." if trim(tempRoot) == ""
  token = "#{stem\gsub '[^%w_.-]', '_'}_#{window.start_frame}_#{end_frame}_#{PyBridge.uniqueSuffix!}"
  base = stem .. suffix
  output = PyBridge.joinPath directory, base .. ".mp4"
  collision = 2
  while PyBridge.fileExists output
    output = PyBridge.joinPath directory, "#{base} (#{collision}).mp4"
    collision += 1
  {
    :output
    partial_output: PyBridge.joinPath directory, ".#{token}.partial.mp4"
    source_mkv: PyBridge.joinPath tempRoot, token .. ".source.mkv"
    source_y4m: PyBridge.joinPath tempRoot, token .. ".source.y4m"
    temp_mkv: PyBridge.joinPath tempRoot, token .. ".mkv"
    log: PyBridge.joinPath tempRoot, token .. ".log"
  }

BuildTrimCommands = (source, window, paths, settings) ->
  return nil, "The selected frame range is invalid." unless window and tonumber(window.frame_count) and window.frame_count > 0
  settings = {} unless type(settings) == "table"
  startMs = Media.msFromFrame window.start_frame
  return nil, "The start time for frame #{window.start_frame} is unavailable." unless finite startMs
  return nil, "The selection begins before the first decodable video frame." if startMs < 0
  fps, measured_fps = Media.frameRateArgument window.start_frame, window.end_frame
  constant_fps = fps != nil
  unless fps
    fps, measured_fps = Media.frameRateArgument window.start_frame, window.end_frame, {requireConstant: false}
  return nil, "The selected frames do not provide a usable frame rate." unless fps
  start_seconds = string.format("%.6f", startMs / 1000)\gsub("0+$", "")\gsub("%.$", "")
  count = tostring window.frame_count
  timingFilter = "setpts=N/((#{fps})*TB)"
  ffmpeg = EncoderCommand settings.ffmpeg, "ffmpeg"
  x264 = EncoderCommand settings.x264, "x264"
  inputArgs = {
    "-hide_banner", "-nostdin", "-loglevel", "warning", "-y"
    "-ss", start_seconds, "-i", source, "-map", "0:V:0", "-an", "-frames:v", count
  }
  direct_args = [value for value in *inputArgs]
  for value in *{
    "-vf", timingFilter, "-r", fps, "-fps_mode", "cfr"
    "-c:v", "libx264", "-crf", "16", "-tune", "fastdecode"
    "-f", "matroska", paths.temp_mkv
  }
    table.insert direct_args, value
  lossless_args = [value for value in *inputArgs]
  for value in *{
    "-vf", timingFilter, "-r", fps, "-fps_mode", "cfr"
    "-c:v", "ffv1", "-level", "3", "-g", "1", "-f", "matroska", paths.source_mkv
  }
    table.insert lossless_args, value
  y4m_args = [value for value in *inputArgs]
  for value in *{
    "-vf", timingFilter .. ",format=yuv420p", "-r", fps, "-fps_mode", "cfr"
    "-f", "yuv4mpegpipe", paths.source_y4m
  }
    table.insert y4m_args, value
  {
    :ffmpeg
    :x264
    ffmpeg_probe: {executable: ffmpeg, args: {"-hide_banner", "-encoders"}}
    x264_probe: {executable: x264, args: {"--fullhelp"}}
    direct: {executable: ffmpeg, args: direct_args}
    lossless: {executable: ffmpeg, args: lossless_args}
    y4m: {executable: ffmpeg, args: y4m_args}
    x264_lossless: {executable: x264, args: {"--crf", "16", "--tune", "fastdecode", "--fps", fps, "--frames", count, "--muxer", "mkv", "-o", paths.temp_mkv, paths.source_mkv}}
    x264_y4m: {executable: x264, args: {"--demuxer", "y4m", "--crf", "16", "--tune", "fastdecode", "--fps", fps, "--frames", count, "--muxer", "mkv", "-o", paths.temp_mkv, paths.source_y4m}}
    remux: {executable: ffmpeg, args: {"-hide_banner", "-nostdin", "-loglevel", "warning", "-y", "-i", paths.temp_mkv, "-map", "0:V:0", "-c", "copy", "-movflags", "+faststart", "-f", "mp4", paths.partial_output}}
    :fps
    :measured_fps
    :constant_fps
    :start_seconds
  }

PowerShellArguments = (arguments) ->
  table.concat [PowerShellLiteral(value) for value in *arguments], " "

BuildTrimPowerShell = (source, window, paths, settings) ->
  commands, err = BuildTrimCommands source, window, paths, settings
  return nil, err unless commands
  "try { & #{PowerShellLiteral commands.direct.executable} #{PowerShellArguments commands.direct.args}; exit $LASTEXITCODE } catch { exit 1 }"

VideoTrimMain = (subs, sel, active) ->
  window, err = SelectionWindow subs, sel
  unless window
    ShowMessage script_name, err
    return sel
  source = Media.projectPath "video"
  unless source
    ShowMessage script_name, "Aegisub has no readable local video path."
    return sel
  paths, pathsError = TrimPaths source, window, PyBridge.tempRoot!
  unless paths and paths.temp_mkv and paths.source_mkv and paths.partial_output and paths.log
    ShowMessage script_name, pathsError or "The temporary directory is unavailable."
    return sel
  settings = EncoderSettings!
  commands, commandError = BuildTrimCommands source, window, paths, settings
  unless commands
    ShowMessage script_name, commandError
    return sel
  PyBridge.cleanup {paths.temp_mkv, paths.source_mkv, paths.source_y4m, paths.partial_output, paths.log}
  RunCommand = (command) -> RunHiddenCommand command
  cancelled = (exit_code, output) ->
    code = tonumber exit_code
    code == -1073741510 or code == 3221225786 or code == 130 or tostring(output or "")\find("^C", 1, true) != nil
  tail = (value, limit = 5000) ->
    value = tostring value or ""
    return value if #value <= limit
    "... full output is in the diagnostic log ...\n" .. value\sub(-limit)
  VerifyFrames = (path) ->
    command = {
      executable: commands.ffmpeg
      args: {"-hide_banner", "-nostdin", "-loglevel", "error", "-nostats", "-progress", "pipe:1", "-i", path, "-map", "0:V:0", "-an", "-f", "null", "-"}
    }
    ok, output, exit_code = RunCommand command
    count = nil
    for value in tostring(output or "")\gmatch "frame=(%d+)"
      count = tonumber value
    ok and count == window.frame_count, count, output, exit_code
  logParts = {
    "Source: #{source}"
    "Frames: #{window.start_frame}..#{window.end_frame - 1} (#{window.frame_count})"
    "Seek: #{commands.start_seconds} s"
    "Output FPS: #{commands.fps} (#{commands.constant_fps and 'source timecodes are CFR' or 'irregular timecodes normalized to CFR'})"
  }
  AddLog = (label, output, exit_code = nil) ->
    status = exit_code != nil and " [exit #{exit_code}]" or ""
    logParts[#logParts + 1] = "#{label}#{status}:\n#{output or ''}"
  fail = (message, output = "", keepMkv = false) ->
    PyBridge.removeFile paths.source_mkv
    PyBridge.removeFile paths.source_y4m
    PyBridge.removeFile paths.partial_output
    PyBridge.removeFile paths.temp_mkv unless keepMkv
    PyBridge.writeFile paths.log, table.concat(logParts, "\n\n")
    kept = keepMkv and (Media.fileSize(paths.temp_mkv) or 0) > 0 and "\nIntermediate MKV: #{paths.temp_mkv}" or ""
    ShowMessage script_name, "#{message}\n\n#{tail output}\nDiagnostic log: #{paths.log}#{kept}", 14
    sel

  aegisub.progress.task "Checking the configured FFmpeg..."
  ffmpegOk, ffmpegInfo, ffmpegExit = RunCommand commands.ffmpeg_probe
  AddLog "FFmpeg capability check", ffmpegInfo, ffmpegExit
  return fail("FFmpeg is unavailable or could not be started. Check Utilities/Trim Settings.", ffmpegInfo) unless ffmpegOk

  hasLibx264 = tostring(ffmpegInfo or "")\find(" libx264 ", 1, true) != nil
  encoded = false
  used_mode = nil
  lastOutput = ""
  local lastExit
  if hasLibx264
    aegisub.progress.task "Seeking to frame #{window.start_frame} and encoding #{window.frame_count} frames with FFmpeg/libx264..."
    encoded, lastOutput, lastExit = RunCommand commands.direct
    encoded = encoded and (Media.fileSize(paths.temp_mkv) or 0) > 0
    used_mode = "FFmpeg/libx264" if encoded
    AddLog "FFmpeg/libx264", lastOutput, lastExit
    return fail("Video clip creation was cancelled.", lastOutput) if cancelled lastExit, lastOutput
    PyBridge.removeFile paths.temp_mkv unless encoded
  else
    AddLog "FFmpeg/libx264", "libx264 is not present; using the configured external x264 fallback."

  unless encoded
    aegisub.progress.task "Checking the configured x264 fallback..."
    x264Ok, x264Info, x264Exit = RunCommand commands.x264_probe
    AddLog "x264 capability check", x264Info, x264Exit
    return fail("Neither FFmpeg/libx264 nor the configured x264 fallback is usable. Check Utilities/Trim Settings.", x264Info) unless x264Ok
    useLossless = tostring(x264Info or "")\find("lavf support (yes)", 1, true) != nil
    extraction = useLossless and commands.lossless or commands.y4m
    intermediate = useLossless and paths.source_mkv or paths.source_y4m
    encoder = useLossless and commands.x264_lossless or commands.x264_y4m
    aegisub.progress.task "Extracting #{window.frame_count} source frames from #{commands.start_seconds} s..."
    extracted, extractOutput, extractExit = RunCommand extraction
    AddLog useLossless and "FFmpeg lossless extraction" or "FFmpeg Y4M extraction", extractOutput, extractExit
    return fail("Video clip creation was cancelled.", extractOutput) if cancelled extractExit, extractOutput
    return fail("FFmpeg could not extract the selected frame range. The selection may extend beyond the video or the source may be undecodable.", extractOutput) unless extracted and (Media.fileSize(intermediate) or 0) > 0
    aegisub.progress.task "Encoding the extracted frames with x264..."
    encoded, lastOutput, lastExit = RunCommand encoder
    AddLog "External x264", lastOutput, lastExit
    PyBridge.removeFile paths.source_mkv
    PyBridge.removeFile paths.source_y4m
    return fail("Video clip creation was cancelled.", lastOutput) if cancelled lastExit, lastOutput
    encoded = encoded and (Media.fileSize(paths.temp_mkv) or 0) > 0
    used_mode = "external x264 fallback" if encoded
  return fail("Both H.264 encoding routes failed.", lastOutput) unless encoded

  aegisub.progress.task "Verifying the encoded frame count..."
  exactMkv, mkvCount, verifyOutput, verifyExit = VerifyFrames paths.temp_mkv
  AddLog "Intermediate frame verification", verifyOutput, verifyExit
  unless exactMkv
    received = mkvCount and tostring(mkvCount) or "unknown"
    return fail("The encoder produced #{received} frames instead of #{window.frame_count}; the incomplete clip was not published.", verifyOutput, true)
  aegisub.progress.task "Remuxing the frame-exact clip..."
  remuxed, remuxOutput, remuxExit = RunCommand commands.remux
  AddLog "MP4 remux", remuxOutput, remuxExit
  return fail("Video clip creation was cancelled.", remuxOutput, true) if cancelled remuxExit, remuxOutput
  return fail("FFmpeg could not create the final MP4.", remuxOutput, true) unless remuxed and (Media.fileSize(paths.partial_output) or 0) > 0
  aegisub.progress.task "Verifying the final MP4..."
  exactMp4, mp4Count, mp4VerifyOutput, mp4VerifyExit = VerifyFrames paths.partial_output
  AddLog "Final frame verification", mp4VerifyOutput, mp4VerifyExit
  unless exactMp4
    received = mp4Count and tostring(mp4Count) or "unknown"
    return fail("The final MP4 contains #{received} frames instead of #{window.frame_count}; it was not published.", mp4VerifyOutput, true)
  published, publishError = PyBridge.replaceFile paths.partial_output, paths.output
  unless published
    AddLog "Publish output", publishError
    return fail("The verified MP4 could not be moved into the source directory.", publishError, true)
  PyBridge.removeFile paths.temp_mkv
  PyBridge.removeFile paths.log
  timing_note = commands.constant_fps and "" or " Irregular source timecodes were normalized to CFR #{commands.fps}."
  ShowMessage script_name, "Created and verified #{window.frame_count}-frame MP4 for source frames #{window.start_frame}..#{window.end_frame - 1} with #{used_mode}.#{timing_note}\n#{paths.output}", 8
  sel

ExactPNGMain = (subs, sel, active) ->
  window, err = SelectionWindow subs, sel
  unless window
    ShowMessage script_name, err
    return sel
  source = Media.projectPath "video"
  unless source
    ShowMessage script_name, "Aegisub has no readable local video path."
    return sel
  startMs = Media.msFromFrame window.start_frame
  unless finite(startMs) and startMs >= 0
    ShowMessage script_name, "The start time for frame #{window.start_frame} is unavailable."
    return sel
  start_seconds = string.format("%.6f", startMs / 1000)\gsub("0+$", "")\gsub("%.$", "")
  destination = aegisub.dialog.save "Choose a name for the PNG sequence", "", "moka_sequence.png", "PNG (*.png)|*.png", false
  return sel unless destination and destination != ""
  directory, stem = PathParts destination
  baseFolder = PyBridge.joinPath directory, stem .. "_frames"
  folder, suffix = baseFolder, 2
  while PyBridge.directoryExists(folder) or PyBridge.fileExists(folder)
    folder = "#{baseFolder} (#{suffix})"
    suffix += 1
  made, mkdir_error = PyBridge.ensureDir folder
  unless made
    ShowMessage script_name, "Could not create #{folder}: #{mkdir_error}"
    return sel
  output = PyBridge.joinPath folder, "frame_%08d.png"
  ffmpeg_args = {
    "-hide_banner", "-nostdin", "-loglevel", "warning", "-y", "-ss", start_seconds, "-i", source, "-map", "0:v:0", "-an"
    "-frames:v", tostring(window.frame_count), "-fps_mode", "passthrough", "-start_number", tostring(window.start_frame), "-compression_level", "3", output
  }
  aegisub.progress.task "Decoding #{window.frame_count} exact frames..."
  ok, diagnostic, exit_code = RunHiddenCommand {executable: EncoderCommand(EncoderSettings!.ffmpeg, "ffmpeg"), args: ffmpeg_args}
  unless ok
    aegisub.cancel! if exit_code == 130 and aegisub and aegisub.cancel
    ShowMessage script_name, "FFmpeg failed. The partial folder was kept for inspection.\n\n#{diagnostic or ''}\n#{folder}", 12
    return sel
  count, missing, invalid = 0, {}, {}
  for frame = window.start_frame, window.end_frame - 1
    LineOps.checkCancelled!
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
    ShowMessage script_name, message, 10
    return sel
  ShowMessage script_name, "Created and verified #{count} PNG files for source frames #{window.start_frame}..#{window.end_frame - 1}.\n#{folder}", 7
  sel

ValidateSelection = (subs, sel) -> sel and #sel > 0
MenuPath = (suffix) -> "#{script_name}/#{suffix}"

macros = {
  {MenuPath("Motion/Apply Motion"), "Apply one Mocha Transform track to selected lines, including FBF authored motion.", MotionMain(false), ValidateSelection}
  {MenuPath("Motion/Revert Motion"), "Mathematically invert one application using the same Transform data; no stored snapshots are required.", MotionMain(true), ValidateSelection}
  {MenuPath("Shapes/Create Clip"), "Convert Mocha mask or shape data to animated ASS \\clip.", ShapeMain("clip"), ValidateSelection}
  {MenuPath("Shapes/Create Inverse Clip"), "Convert Mocha mask or shape data to animated ASS \\iclip.", ShapeMain("iclip"), ValidateSelection}
  {MenuPath("Shapes/Create Vector Drawing"), "Convert Mocha mask or shape data to animated ASS vector drawings.", ShapeMain("shape"), ValidateSelection}
  {MenuPath("Perspective/Apply Power Pin"), "Apply Mocha CC Power Pin or Corner Pin data to selected lines and clips.", PowerPinMain, ValidateSelection}
  {MenuPath("Track Refinery"), "Analyze, denoise, repair duplicate frames, or retarget selected FBF tracks.", RefineryMain, ValidateSelection}
  {MenuPath("Utilities/Optimizer"), "Merge consecutive compatible FBF states without accumulating positional drift.", FBFOptimizer.main, FBFOptimizer.canRun}
  {MenuPath("Utilities/Inspect Mocha Data"), "Identify supported Mocha export data and inspect continuity problems.", InspectMain}
  {MenuPath("Utilities/Create Video Clip"), "Create and verify a frame-exact H.264 MP4 with adaptive FFmpeg/libx264 and external x264 fallback.", VideoTrimMain, ValidateSelection}
  {MenuPath("Utilities/Create Exact PNG Sequence"), "Create a frame-indexed PNG sequence for Mocha without an H.264 trim.", ExactPNGMain, ValidateSelection}
  {MenuPath("Utilities/Trim Settings"), "Configure FFmpeg and the optional external x264 fallback; blank fields use PATH.", TrimSettingsMain}
}
for macro in *macros
  depctrl\registerMacro macro[1], macro[2], macro[3], macro[4], nil, false

Core.DEFAULTS = DEFAULTS
Core.MotionDialog = MotionDialog
Core.ParseInput = ParseInput
Core.MotionMain = MotionMain
Core.ShapeMain = ShapeMain
Core.PowerPinMain = PowerPinMain
Core.RefineryMain = RefineryMain
Core.InspectMain = InspectMain
Core.EncoderCommand = EncoderCommand
Core.TrimPaths = TrimPaths
Core.BuildTrimCommands = BuildTrimCommands
Core.BuildTrimPowerShell = BuildTrimPowerShell
Core.FBFOptimizer = FBFOptimizer
Core.OptimizerMain = FBFOptimizer.main
Core.WindowsQuoteArgument = PyBridge.quoteProcessArgument
Core.ManagedProcessScript = PyBridge.buildProcessScript
Core.RunHiddenCommand = RunHiddenCommand

Core.Trim = trim
Core.Finite = finite
Core.trim = Core.Trim
Core.finite = Core.Finite
Core.format_number = Core.FormatNumber
Core.parse_numbers = Core.ParseNumbers
Core.parse_meta = Core.ParseMeta
Core.parse_keyframe_sections = Core.ParseKeyframeSections
Core.parse_transform_data = Core.ParseTransformData
Core.parse_powerpin_data = Core.ParsePowerPinData
Core.parse_shape_data = Core.ParseShapeData
Core.parse_shake_shape_data = Core.ParseShakeShapeData
Core.parse_input = Core.ParseInput
Core.unwrap_angles = Core.UnwrapAngles
Core.unwrap_rotation_section = Core.UnwrapRotationSection
Core.linear_fit = Core.LinearFit
Core.vector_linearity = Core.VectorLinearity
Core.signed_quad_area = Core.SignedQuadArea
Core.validate_quad = Core.ValidateQuad
Core.series_from_track = Core.SeriesFromTrack
Core.build_shape_context = Core.BuildShapeContext
Core.render_shape_path = Core.RenderShapePath
Core.prepare_shape_samples = Core.PrepareShapeSamples
Core.shape_text = Core.ShapeText
Core.render_shape_line_text = Core.RenderShapeLineText
Core.strip_top_level_clips = Core.StripTopLevelClips
Core.apply_clip_text = Core.ApplyClipText
Core.selection_window = Core.SelectionWindow
Core.exclusive_end_frame = Core.ExclusiveEndFrame
Core.slice_track = Core.SliceTrack
Core.canonical_fps = Core.CanonicalFPS
Core.timing_diagnostics = Core.TimingDiagnostics
Core.validate_sync = Core.ValidateSync
Core.compress_output_lines = Core.CompressOutputLines
Core.selection_from_groups = Core.SelectionFromGroups
Core.apply_shape_track = Core.ApplyShapeTrack
Core.scale_track_coordinates = Core.ScaleTrackCoordinates
Core.transform_point = Core.TransformPoint
Core.inverse_transform_point = Core.InverseTransformPoint
Core.motion_point = Core.MotionPoint
Core.effective_transform_sample = Core.EffectiveTransformSample
Core.transform_clip_path = Core.TransformClipPath
Core.translate_clip_path = Core.TranslateClipPath
Core.apply_transform_text = Core.ApplyTransformText
Core.shift_frame_karaoke = Core.ShiftFrameKaraoke
Core.track_channels_constant = Core.TrackChannelsConstant
Core.transform_shear_risk = Core.TransformShearRisk
Core.track_deformation_flags = Core.TrackDeformationFlags
Core.line_transform_shear_risk = Core.LineTransformShearRisk
Core.effective_transform_track = Core.EffectiveTransformTrack
Core.try_linear_line = Core.TryLinearLine
Core.apply_transform_track = Core.ApplyTransformTrack
Core.perspective_warning_text = Core.PerspectiveWarningText
Core.validate_quad_track = Core.ValidateQuadTrack
Core.perspective_track = Core.PerspectiveTrack
Core.phase_slip_candidate = Core.PhaseSlipCandidate
Core.repair_transform_phase = Core.RepairTransformPhase
Core.cleanup_transform_track = Core.CleanupTransformTrack
Core.prepare_transform_track = Core.PrepareTransformTrack
Core.current_video_frame = Core.CurrentVideoFrame
Core.reference_row_for_window = Core.ReferenceRowForWindow
Core.optimize_transform_report = Core.OptimizeTransformReport
Core.build_refinery_tracks = Core.BuildRefineryTracks
Core.detect_authored_period = Core.DetectAuthoredPeriod
Core.apply_refinery = Core.ApplyRefinery
Core.motion_dialog = Core.MotionDialog
Core.motion_main = Core.MotionMain
Core.shape_main = Core.ShapeMain
Core.powerpin_main = Core.PowerPinMain
Core.refinery_main = Core.RefineryMain
Core.inspect_main = Core.InspectMain
Core.encoder_command = Core.EncoderCommand
Core.trim_paths = Core.TrimPaths
Core.build_trim_commands = Core.BuildTrimCommands
Core.build_trim_powershell = Core.BuildTrimPowerShell
Core.optimizer_main = Core.OptimizerMain
Core.windows_quote_argument = Core.WindowsQuoteArgument
Core.managed_process_script = Core.ManagedProcessScript
Core.run_hidden_command = Core.RunHiddenCommand

require("kite.UI").publishActions()

return Core
