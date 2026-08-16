export script_name        = "AddTexture"
export script_description = "Apply pasted ASS drawing textures clipped to selected text outlines"
export script_author      = "Kiterow"
export script_version     = "2.0.13"
export script_namespace   = "kite.AddTexture"

CONFIG_FILE = "kite-addtexture.json"
NUMBER_EPSILON = 0.000001
NUMBER_DECIMALS = 3
DEFAULT_TOLERANCE = 1
MIN_TOLERANCE = 1
MAX_TOLERANCE = 50
MIN_LAYER_OFFSET = 0
MAX_LAYER_OFFSET = 100
LARGE_OUTPUT_WARNING_LINES = 20000
DIALOG_INPUT_PREVIEW_CHARS = 12000

local ZF, ASS, KiteUI, LineOps, depctrl
DependencyControl = require "l0.DependencyControl"
depctrl = DependencyControl{
  feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
  {
    {"ZF.main", version: "2.3.0", url: "https://github.com/TypesettingTools/zeref-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/TypesettingTools/zeref-Aegisub-Scripts/main/DependencyControl.json"}
    {"l0.ASSFoundation", version: "0.5.0", url: "https://github.com/TypesettingTools/ASSFoundation",
      feed: "https://raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json"}
    {"kite.UI", version: "1.1.3", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.LineOps", version: "1.5.2", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
  }
}
ZF, ASS, KiteUI, LineOps = depctrl\requireModules!

ConfigHandler = (interface, file_name, _has_sections, version) ->
  KiteUI.dialogHandler interface, script_namespace, version, {
    {path: "?user/" .. file_name, format: "json_sections"}
  }

safe_require = (name) ->
  ok, mod = pcall require, name
  if ok then mod else nil

clipboard = safe_require "aegisub.clipboard"

DEFAULTS = {
  clip_tolerance: 1.0
  shape_tolerance: 1.0
  layer_offset: 1
  preserve_colors: false
  cut_to_text_shape: false
  copy_visibility_tags: false
  user_tags: "\\bord0\\shad0"
}

trim = (value) ->
  text = tostring(value or "")
  text = text\gsub "^%s+", ""
  text = text\gsub "%s+$", ""
  text

normalize_color = (color) ->
  return nil unless type(color) == "string"
  hex = trim(color)\match "^&[Hh](%x+)&?$"
  return nil unless hex and (#hex == 6 or #hex == 8)
  hex = hex\sub(-6) if #hex > 6
  "&H" .. hex\upper! .. "&"

finite_number = (value, fallback = 0) ->
  number = tonumber value
  return fallback unless number and number == number and number != math.huge and number != -math.huge
  number

normalize_tolerance = (tolerance) ->
  value = finite_number tolerance, DEFAULT_TOLERANCE
  math.max MIN_TOLERANCE, math.min MAX_TOLERANCE, value

normalize_layer_offset = (value) ->
  value = math.floor(finite_number(value, DEFAULTS.layer_offset) + 0.5)
  math.max MIN_LAYER_OFFSET, math.min MAX_LAYER_OFFSET, value

format_number = (n) ->
  n = finite_number n, 0
  n = 0 if math.abs(n) < NUMBER_EPSILON
  if math.abs(n - math.floor(n + 0.5)) < NUMBER_EPSILON
    return tostring(math.floor(n + 0.5))
  s = string.format "%.#{NUMBER_DECIMALS}f", n
  s = s\gsub "0+$", ""
  s\gsub "%.$", ""

normalize_draw_scale = (drawing, p_scale) ->
  scale = finite_number p_scale, 1
  return drawing if scale <= 1
  factor = math.pow 2, scale - 1
  tokens = {}
  for token in tostring(drawing or "")\gmatch "%S+"
    number = tonumber token
    if number and number == number and number != math.huge and number != -math.huge
      tokens[#tokens + 1] = format_number(number / factor)
    else
      tokens[#tokens + 1] = token
  table.concat tokens, " "

read_clipboard = ->
  return "" unless clipboard and clipboard.get
  ok, data = pcall clipboard.get
  if ok and type(data) == "string" then data else ""

clean_shape = (raw) ->
  s = tostring(raw or "")
  s = s\gsub "\r", " "
  s = s\gsub "\n", " "
  s = s\gsub "\\N", " "
  s = s\gsub "%b{}", " "
  s = s\gsub "\\p%d+", " "
  s = s\gsub ",", " "
  s = s\gsub "([mMnNlLbBsSpPcC])", (c) -> " " .. c\lower! .. " "
  s = s\gsub "%s+", " "
  s = trim s
  trim(s\match("([mn]%s+%-?[%d%.]+%s+%-?[%d%.]+.*)") or s)

parse_dialogue_line = (line) ->
  s = trim line
  prefix = s\match("^(Dialogue:)") or s\match "^(Comment:)"
  return nil unless prefix
  rest = trim s\sub #prefix + 1
  fields = {}
  pos = 1
  for _ = 1, 9
    comma = rest\find ",", pos, true
    return nil unless comma
    fields[#fields + 1] = rest\sub pos, comma - 1
    pos = comma + 1
  fields[#fields + 1] = rest\sub pos
  { text: fields[10] or "" }

split_payloads = (input) ->
  normalized = tostring(input or "")\gsub "\r\n", "\n"
  normalized = normalized\gsub "\r", "\n"
  return {} if trim(normalized) == ""

  lines, parsed_count = {}, 0
  for line in (normalized .. "\n")\gmatch "([^\n]*)\n"
    if trim(line) != ""
      parsed = parse_dialogue_line line
      parsed_count += 1 if parsed
      lines[#lines + 1] = { text: parsed and parsed.text or line, line: parsed }

  -- Physical newlines are valid separators inside a raw ASS drawing. Splitting
  -- those lines would discard every continuation that does not start with m/n.
  return { { text: normalized } } if parsed_count == 0

  payloads = {}
  for item in *lines
    payloads[#payloads + 1] = item
  payloads

copy_state = (state = {}) ->
  {
    p: state.p
    color: state.color
    align: state.align
    pos: state.pos and { state.pos[1], state.pos[2] } or nil
    scale_x: state.scale_x
    scale_y: state.scale_y
  }

update_tag_state = (tags, state) ->
  tags = tostring(tags or "")
  -- A target inside \t() is not the current static state of the drawing.
  tags = tags\gsub "\\t%s*%b()", ""
  for color in tags\gmatch "\\1?c%s*(&[Hh]%x+&?)"
    state.color = normalize_color(color) or state.color
  for p in tags\gmatch "\\p(%d+)"
    state.p = tonumber(p) or state.p
  for an in tags\gmatch "\\an([1-9])"
    state.align = tonumber(an) or state.align

  x, y = tags\match "\\pos%(%s*([%-%.%d]+)%s*,%s*([%-%.%d]+)%s*%)"
  if x and y
    state.pos = { tonumber(x), tonumber(y) }
  else
    x, y = tags\match "\\move%(%s*([%-%.%d]+)%s*,%s*([%-%.%d]+)%s*,%s*[%-%.%d]+%s*,%s*[%-%.%d]+"
    state.pos = { tonumber(x), tonumber(y) } if x and y

  fscx = tags\match "\\fscx([%-%.%d]+)"
  fscy = tags\match "\\fscy([%-%.%d]+)"
  state.scale_x = tonumber(fscx) or state.scale_x if fscx
  state.scale_y = tonumber(fscy) or state.scale_y if fscy

collect_tag_state = (input) ->
  state = { p: 0, color: nil, align: 7, pos: nil, scale_x: 100, scale_y: 100 }
  for tags in tostring(input or "")\gmatch "{([^}]*)}"
    update_tag_state tags, state
  state

append_record = (records, raw, state = {}, source_index = 1, kind = "drawing", apply_position = false) ->
  drawing = clean_shape raw
  return false if drawing == "" or not drawing\match "^[mn]%s+"
  drawing = normalize_draw_scale drawing, state.p or 1
  records[#records + 1] = {
    drawing: drawing
    color: normalize_color state.color
    source_index: source_index
    kind: kind
    apply_position: apply_position and state.pos != nil
    align: state.align or 7
    pos: state.pos and { state.pos[1], state.pos[2] } or nil
    scale_x: tonumber(state.scale_x) or 100
    scale_y: tonumber(state.scale_y) or 100
  }
  true

append_clip_args = (records, args, state = {}, source_index = 1) ->
  local_state = copy_state state
  p_scale, drawing = tostring(args or "")\match "^%s*(%d+)%s*,%s*([mMnN]%s+.+)$"
  if drawing
    local_state.p = tonumber(p_scale) or 1
  else
    drawing = tostring(args or "")\match "^%s*([mMnN]%s+.+)$"
    local_state.p = 1
  if drawing
    return append_record records, drawing, local_state, source_index, "clip", false
  false

extract_clip_shapes = (text, records, source_index) ->
  state = { p: 0, color: nil, align: 7, pos: nil, scale_x: 100, scale_y: 100 }
  before = #records
  for tags in tostring(text or "")\gmatch "{([^}]*)}"
    update_tag_state tags, state
    for args in tags\gmatch "\\i?clip%(([^%)]*)%)"
      append_clip_args records, args, state, source_index
  return true if #records > before
  for args in tostring(text or "")\gmatch "\\i?clip%(([^%)]*)%)"
    append_clip_args records, args, state, source_index
  #records > before

extract_p_drawings = (text, records, source_index) ->
  text = tostring(text or "")
  seed = collect_tag_state text
  state = { p: 0, color: nil, align: seed.align, pos: seed.pos, scale_x: 100, scale_y: 100 }
  pos = 1
  before = #records
  while true
    open, close, tags = text\find "{([^}]*)}", pos
    chunk = if open then text\sub(pos, open - 1) else text\sub(pos)
    append_record records, chunk, state, source_index, "drawing", true if state.p and state.p > 0
    break unless open
    update_tag_state tags, state
    pos = close + 1
  #records > before

extract_raw_shape = (text, records, source_index) ->
  state = collect_tag_state text
  stripped = tostring(text or "")\gsub "%b{}", " "
  stripped = stripped\gsub "\r", " "
  stripped = stripped\gsub "\n", " "
  drawing = stripped\match "%f[%a]([mMnN]%s*%-?[%d%.]+%s+%-?[%d%.]+.*)"
  if drawing
    return append_record records, drawing, state, source_index, "drawing", state.pos != nil
  false

section_string = (section) ->
  ok, value = pcall ->
    if section.toString
      section\toString!
    elseif section.getString
      section\getString!
    elseif section.getTagParams
      section\getTagParams!
  if ok and value then tostring(value) else ""

assf_tag_name = (tag) ->
  if tag and tag.__tag then tag.__tag.name else nil

assf_tag_values = (tag) ->
  ok, a, b, c, d, e, f = pcall -> tag\getTagParams!
  return nil unless ok
  { a, b, c, d, e, f }

format_assf_color = (values) ->
  return nil unless values and values[1] and values[2] and values[3]
  string.format "&H%02X%02X%02X&", values[1], values[2], values[3]

update_assf_tag_state = (tag, state) ->
  name = assf_tag_name tag
  return false unless name
  values = assf_tag_values tag
  return false unless values

  switch name
    when "color1"
      state.color = format_assf_color(values) or state.color
    when "align"
      state.align = tonumber(values[1]) or state.align
    when "position"
      state.pos = { tonumber(values[1]), tonumber(values[2]) } if values[1] and values[2]
    when "move"
      state.pos = { tonumber(values[1]), tonumber(values[2]) } if values[1] and values[2]
    when "scale_x"
      state.scale_x = tonumber(values[1]) or state.scale_x
    when "scale_y"
      state.scale_y = tonumber(values[1]) or state.scale_y
    else
      return false
  true

append_assf_clip = (records, tag, state, source_index) ->
  name = assf_tag_name tag
  return false unless name == "clip_vect" or name == "iclip_vect" or name == "clip_rect" or name == "iclip_rect"

  local_state = copy_state state
  local_state.p = 1

  values = assf_tag_values tag
  drawing = nil
  if values
    if type(values[2]) == "string"
      drawing = values[2]
      local_state.p = tonumber(values[1]) or 1
    else
      drawing = values[1]
  if drawing and type(drawing) == "string" and drawing\match "^%s*[mMnN]%s+"
    return append_record records, drawing, local_state, source_index, "clip", false

  if tag.getDrawing
    ok, drawing_section, pos = pcall -> tag\getDrawing true
    if ok and drawing_section
      if pos and pos.getTagParams
        px, py = pos\getTagParams!
        local_state.pos = { px, py }
        return append_record records, section_string(drawing_section), local_state, source_index, "clip", true
      return append_record records, section_string(drawing_section), local_state, source_index, "clip", false
  false

extract_assf_sections = (payload, records, source_index) ->
  return false unless ASS and ASS.Parser and ASS.Parser.LineText
  line = payload.line or { text: payload.text or "" }
  ok, sections = pcall -> ASS.Parser.LineText\getSections line
  return false unless ok and type(sections) == "table"

  before = #records
  seed = collect_tag_state payload.text
  state = { p: 0, color: nil, align: seed.align, pos: seed.pos, scale_x: 100, scale_y: 100 }
  for section in *sections
    if ASS\instanceOf(section, ASS.Section.Tag)
      if section.tags
        for tag in *section.tags
          append_assf_clip records, tag, state, source_index
          update_assf_tag_state tag, state
      else
        update_tag_state section_string(section), state
    elseif ASS\instanceOf(section, ASS.Section.Drawing)
      draw_state = copy_state state
      ok_scale, p_scale = pcall -> section.scale\get!
      draw_state.p = ok_scale and tonumber(p_scale) or 1
      append_record records, section_string(section), draw_state, source_index, "drawing", true
  #records > before

extract_from_text = (text, records, source_index) ->
  before = #records
  return #records - before if extract_p_drawings text, records, source_index
  return #records - before if extract_clip_shapes text, records, source_index
  extract_raw_shape text, records, source_index
  #records - before

extract_ass_drawings = (input) ->
  records = {}
  payloads = split_payloads input
  for i, payload in ipairs payloads
    extracted = extract_assf_sections payload, records, i
    extract_from_text payload.text, records, i unless extracted
  extract_from_text input, records, 1 if #records == 0
  records

normalize_input_newlines = (value) ->
  normalized = tostring(value or "")\gsub "\r\n", "\n"
  normalized = normalized\gsub "\r", "\n"
  normalized

resolve_dialog_input = (dialog_input, presented_input, clipboard_inputs = {}) ->
  dialog_input = tostring dialog_input or ""
  dialog_normalized = normalize_input_newlines dialog_input
  presented_normalized = normalize_input_newlines presented_input
  valid_clipboards = {}

  for candidate in *clipboard_inputs
    candidate = tostring candidate or ""
    if trim(candidate) != "" and #extract_ass_drawings(candidate) > 0
      valid_clipboards[#valid_clipboards + 1] = {
        text: candidate
        normalized: normalize_input_newlines candidate
      }

  ui_returned_presented = dialog_normalized == presented_normalized or dialog_normalized == ""
  if not ui_returned_presented and #dialog_normalized < #presented_normalized
    ui_returned_presented = presented_normalized\sub(1, #dialog_normalized) == dialog_normalized

  for candidate in *valid_clipboards
    is_candidate_prefix = #dialog_normalized < #candidate.normalized and candidate.normalized\sub(1, #dialog_normalized) == dialog_normalized
    return candidate.text, true if ui_returned_presented or is_candidate_prefix

  return dialog_input, false if #extract_ass_drawings(dialog_input) > 0
  return valid_clipboards[1].text, true if valid_clipboards[1]
  dialog_input, false

shape_info = (drawing) ->
  ok, shape = pcall -> ZF.shape drawing
  return nil, "Invalid ASS shape." unless ok and shape
  shape_l = finite_number shape.l, nil
  shape_t = finite_number shape.t, nil
  shape_w = finite_number shape.w, nil
  shape_h = finite_number shape.h, nil
  return nil, "ASS shape has invalid bounds." unless shape_l and shape_t and shape_w and shape_h
  return nil, "ASS shape has empty bounds." unless shape_w > 0 and shape_h > 0
  shape

build_shape = (shape) ->
  trim shape\build!

transform_record = (record) ->
  shape, err = shape_info record.drawing
  return nil, err unless shape
  if (record.scale_x and record.scale_x != 100) or (record.scale_y and record.scale_y != 100)
    shape\scale record.scale_x or 100, record.scale_y or 100
    shape\setBoudingBox!
  if record.apply_position and record.pos
    shape\setPosition record.align or 7, "tcp", record.pos[1] or 0, record.pos[2] or 0
  drawing = build_shape shape
  shape, err = shape_info drawing
  return nil, err unless shape
  {
    drawing: drawing
    color: record.color
    source_index: record.source_index
  }

join_drawings = (items) ->
  out = {}
  for item in *items
    drawing = if type(item) == "table" then item.drawing else item
    out[#out + 1] = trim drawing if drawing and trim(drawing) != ""
  trim table.concat out, " "

move_drawing = (drawing, dx = 0, dy = 0) ->
  shape, err = shape_info drawing
  return nil, err unless shape
  build_shape shape\move dx, dy

scale_drawing = (drawing, scale = 1) ->
  shape, err = shape_info drawing
  return nil, err unless shape
  build_shape shape\scale scale * 100, scale * 100

simplify_drawing = (drawing, tolerance) ->
  tol = normalize_tolerance tolerance
  ok, simplified = pcall ->
    ZF.clipper(drawing)\simplify!\build "line", tol
  return nil, "Could not simplify ASS shape: #{simplified}" unless ok
  simplified = trim simplified
  simplified = drawing if simplified == ""
  shape, err = shape_info simplified
  return nil, err unless shape
  simplified

prepare_texture_groups = (input, tolerance, preserve_colors) ->
  extracted = extract_ass_drawings input
  if #extracted == 0
    return nil, "Paste raw ASS drawing data, a {\\p1} drawing, a vector \\clip(), or Dialogue/Comment lines containing drawings."

  transformed = {}
  for i, record in ipairs extracted
    item, err = transform_record record
    unless item
      return nil, ("Texture shape %d failed: %s")\format i, err or "invalid shape"
    transformed[#transformed + 1] = item

  combined = join_drawings transformed
  global_shape, err = shape_info combined
  return nil, err unless global_shape

  global = {
    l: global_shape.l
    t: global_shape.t
    w: global_shape.w
    h: global_shape.h
  }
  return nil, "ASS texture composition has empty bounds." if global.w <= 0 or global.h <= 0

  normalize_to_global = (drawing) ->
    move_drawing drawing, -global.l, -global.t

  unless preserve_colors
    moved, move_err = normalize_to_global combined
    return nil, move_err unless moved
    simplified, simplify_err = simplify_drawing moved, tolerance
    return nil, simplify_err unless simplified
    return {
      {
        drawing: simplified
        color: nil
        w: global.w
        h: global.h
      }
    }, global

  buckets, order = {}, {}
  for item in *transformed
    key = item.color or "__fallback__"
    unless buckets[key]
      buckets[key] = { color: item.color, drawings: {} }
      order[#order + 1] = key
    buckets[key].drawings[#buckets[key].drawings + 1] = item

  groups = {}
  for key in *order
    bucket = buckets[key]
    drawing = join_drawings bucket.drawings
    moved, move_err = normalize_to_global drawing
    return nil, move_err unless moved
    simplified, simplify_err = simplify_drawing moved, tolerance
    return nil, simplify_err unless simplified
    groups[#groups + 1] = {
      drawing: simplified
      color: bucket.color
      w: global.w
      h: global.h
    }

  groups, global

fit_texture_to_box = (group, target_l, target_t, target_w, target_h) ->
  target_l = finite_number target_l, 0
  target_t = finite_number target_t, 0
  target_w = finite_number target_w, 0
  target_h = finite_number target_h, 0
  return nil, "Text outline has empty bounds." if target_w <= 0 or target_h <= 0
  return nil, "Texture shape has empty bounds." unless group and group.w and group.h and group.w > 0 and group.h > 0

  scale = math.max target_w / group.w, target_h / group.h
  drawing, err = scale_drawing group.drawing, scale
  return nil, err unless drawing
  scaled_w = group.w * scale
  scaled_h = group.h * scale
  {
    drawing: drawing
    scale: scale
    x: target_l + (target_w - scaled_w) / 2
    y: target_t + (target_h - scaled_h) / 2
  }

cut_fitted_texture_to_clip = (fitted, clip_drawing, tolerance) ->
  absolute, move_err = move_drawing fitted.drawing, fitted.x, fitted.y
  return nil, move_err unless absolute
  tol = normalize_tolerance tolerance
  ok, clipped = pcall ->
    ZF.clipper(absolute, clip_drawing, true)\clip(false)\build "line", tol
  return nil, "Could not cut texture shape to text outline: #{clipped}" unless ok
  clipped = trim clipped
  return "" if clipped == ""
  local_drawing, local_err = move_drawing clipped, -fitted.x, -fitted.y
  return nil, local_err unless local_drawing
  local_drawing

build_text_clip = (dlg, line, tolerance) ->
  call = ZF.line(line)\prepoc dlg
  pers = dlg\getPerspectiveTags line
  pers.p = "text" if pers.p == 0
  px, py = pers.pos[1], pers.pos[2]
  shape = ZF.util\isShape line.text
  unless shape
    shape = call\toShape dlg, nil, px, py
  style_ref = line.styleref
  old_scale_x, old_scale_y = nil, nil
  changed_style_scale = false
  if not ZF.util\isShape(line.text) and style_ref
    old_scale_x, old_scale_y = style_ref.scale_x, style_ref.scale_y
    style_ref.scale_x, style_ref.scale_y = 100, 100
    changed_style_scale = true
  ok, clip_abs = pcall ->
    align = style_ref and style_ref.align or 7
    ZF.shape(shape, true)\setPosition(align)\expand(line, pers)\move(px, py)\build!
  if style_ref and changed_style_scale
    style_ref.scale_x, style_ref.scale_y = old_scale_x, old_scale_y
  error clip_abs unless ok
  tol = normalize_tolerance tolerance
  simplified = trim ZF.clipper(clip_abs)\simplify!\build "line", tol
  sh = ZF.shape simplified
  error "Text outline has invalid bounds." unless finite_number(sh.l, nil) and finite_number(sh.t, nil) and finite_number(sh.w, nil) and finite_number(sh.h, nil)
  error "Text outline has empty bounds." unless sh.w > 0 and sh.h > 0
  {
    clip: simplified
    l: sh.l
    t: sh.t
    w: sh.w
    h: sh.h
    cx: sh.l + sh.w / 2
    cy: sh.t + sh.h / 2
  }

text_primary_color = (l, line) ->
  static_text = tostring(l.text or "")\gsub "\\t%s*%b()", ""
  c1 = static_text\match "\\1?c%s*(&[Hh]%x+&?)"
  return normalize_color c1 if c1
  if line.styleref and line.styleref.color1
    return normalize_color(line.styleref.color1) or line.styleref.color1
  "&HFFFFFF&"

balanced_paren_end = (text, open_pos) ->
  depth = 0
  for i = open_pos, #text
    c = text\sub(i, i)
    if c == "("
      depth += 1
    elseif c == ")"
      depth -= 1
      return i if depth == 0
  nil

match_visibility_tag = (text, pos) ->
  chunk = text\sub pos
  tag = chunk\match "^\\alpha%s*&[Hh]%x+&?"
  return tag if tag
  tag = chunk\match "^\\[1234]a%s*&[Hh]%x+&?"
  return tag if tag
  tag = chunk\match "^\\fade%s*%([^%)]*%)"
  return tag if tag
  tag = chunk\match "^\\fad%s*%([^%)]*%)"
  return tag if tag
  nil

scan_visibility_tags = (tags) ->
  frames = {{text: tostring(tags or ""), pos: 1, out: {}}}
  while #frames > 0
    frame = frames[#frames]
    if frame.pos > #frame.text
      result = table.concat frame.out, ""
      table.remove frames
      return result if #frames == 0
      parent = frames[#frames]
      parent.out[#parent.out + 1] = "\\t(" .. frame.prefix .. result .. ")" if result != ""
    elseif frame.text\sub(frame.pos, frame.pos) == "\\"
      chunk = frame.text\sub(frame.pos)
      transform_start = chunk\match "^\\t%s*%("
      if transform_start
        open_pos = frame.pos + #transform_start - 1
        close_pos = balanced_paren_end frame.text, open_pos
        unless close_pos
          frame.pos = #frame.text + 1
          continue
        body = frame.text\sub(open_pos + 1, close_pos - 1)
        tag_start = body\find "\\", 1, true
        frame.pos = close_pos + 1
        if tag_start
          frames[#frames + 1] = {
            text: body\sub tag_start
            pos: 1
            out: {}
            prefix: body\sub(1, tag_start - 1)
          }
      else
        tag = match_visibility_tag frame.text, frame.pos
        if tag
          frame.out[#frame.out + 1] = tag
          frame.pos += #tag
        else
          frame.pos += 1
    else
      frame.pos += 1
  ""

collect_visibility_tags = (text) ->
  out = {}
  for tags in tostring(text or "")\gmatch "{([^}]*)}"
    copied = scan_visibility_tags tags
    out[#out + 1] = copied if copied != ""
  table.concat out, ""

show_message = (title, msg) ->
  aegisub.dialog.display {
    { class: "label", label: title, x: 0, y: 0, width: 42 }
    { class: "textbox", value: msg, x: 0, y: 1, width: 42, height: 8 }
  }, { "OK" }

confirm_large_output = (estimated_lines) ->
  return true if estimated_lines <= LARGE_OUTPUT_WARNING_LINES
  btn = aegisub.dialog.display {
    { class: "label", label: "AddTexture - large output warning", x: 0, y: 0, width: 42 }
    { class: "textbox", value: "This operation can generate up to #{estimated_lines} lines. The warning threshold is #{LARGE_OUTPUT_WARNING_LINES}; processing may take longer and use more memory, but AddTexture can continue.", x: 0, y: 1, width: 42, height: 8 }
  }, { "Continue", "Cancel" }, { ok: "Continue", close: "Cancel" }
  btn == "Continue"

cancel_requested = ->
  return false unless aegisub.progress and aegisub.progress.is_cancelled
  aegisub.progress.is_cancelled!

build_interface = ->
  {
    main: {
      title: { class: "label", label: "AddTexture", x: 0, y: 0, width: 7 }
      hint: {
        class: "label"
        label: "Paste ASS drawings, vector clips, or Dialogue/Comment lines."
        x: 0
        y: 1
        width: 7
      }
      shape_label: { class: "label", label: "ASS drawings / Dialogue lines:", x: 0, y: 2, width: 7 }
      shape_input: { class: "textbox", name: "shape_input", text: "", config: false, x: 0, y: 3, width: 7, height: 9 }
      preserve_colors: {
        class: "checkbox"
        name: "preserve_colors"
        label: "Preserve colors"
        value: DEFAULTS.preserve_colors
        config: true
        x: 0
        y: 12
        width: 3
      }
      cut_to_text_shape: {
        class: "checkbox"
        name: "cut_to_text_shape"
        label: "Clip to text"
        value: DEFAULTS.cut_to_text_shape
        config: true
        x: 3
        y: 12
        width: 4
      }
      copy_visibility_tags: {
        class: "checkbox"
        name: "copy_visibility_tags"
        label: "Copy alpha/fad"
        value: DEFAULTS.copy_visibility_tags
        config: true
        x: 0
        y: 13
        width: 7
      }
      user_tags_label: { class: "label", label: "Extra tags:", x: 0, y: 14, width: 2 }
      user_tags: {
        class: "edit"
        name: "user_tags"
        value: DEFAULTS.user_tags
        config: true
        x: 2
        y: 14
        width: 5
      }
      clip_tolerance_label: { class: "label", label: "Text simplify:", x: 0, y: 15, width: 4 }
      clip_tolerance: {
        class: "floatedit"
        name: "clip_tolerance"
        value: DEFAULTS.clip_tolerance
        config: true
        min: 1
        max: MAX_TOLERANCE
        x: 4
        y: 15
        width: 3
      }
      shape_tolerance_label: { class: "label", label: "Shape simplify:", x: 0, y: 16, width: 4 }
      shape_tolerance: {
        class: "floatedit"
        name: "shape_tolerance"
        value: DEFAULTS.shape_tolerance
        config: true
        min: 1
        max: MAX_TOLERANCE
        x: 4
        y: 16
        width: 3
      }
      layer_offset_label: { class: "label", label: "Layer offset:", x: 0, y: 17, width: 4 }
      layer_offset: {
        class: "intedit"
        name: "layer_offset"
        value: DEFAULTS.layer_offset
        config: true
        min: MIN_LAYER_OFFSET
        max: MAX_LAYER_OFFSET
        x: 4
        y: 17
        width: 3
      }
    }
  }

show_dialog = ->
  interface = build_interface!
  options = nil
  if ConfigHandler
    options = ConfigHandler interface, CONFIG_FILE, true, script_version
    options\read!
    options\updateInterface "main"

  clipboard_before = read_clipboard!
  presented_input = clipboard_before
  if #presented_input > DIALOG_INPUT_PREVIEW_CHARS
    presented_input = presented_input\sub 1, DIALOG_INPUT_PREVIEW_CHARS
    interface.main.shape_label.label = "ASS drawings / Dialogue lines (#{#clipboard_before} clipboard chars loaded; preview shown):"
  interface.main.shape_input.text = presented_input
  btn, res = aegisub.dialog.display interface.main, { "Execute", "Cancel" }, { ok: "Execute", close: "Cancel" }
  aegisub.cancel! if btn != "Execute"
  clipboard_after = read_clipboard!
  res.shape_input = resolve_dialog_input res.shape_input, presented_input, { clipboard_after, clipboard_before }
  if options
    options\updateConfiguration res, "main"
    options\write!
  res

valid_selection = (subs, sel) ->
  return false unless sel and #sel > 0
  for index in *sel
    line = subs[index]
    return false unless line and line.class == "dialogue" and not line.comment
  true

main = (subs, sel, active) ->
  unless valid_selection subs, sel
    aegisub.dialog.display { { class: "label", label: "Select at least one uncommented dialogue line." } }, { "OK" }
    aegisub.cancel!

  opts = show_dialog!
  opts.clip_tolerance = normalize_tolerance opts.clip_tolerance
  opts.shape_tolerance = normalize_tolerance opts.shape_tolerance
  opts.layer_offset = normalize_layer_offset opts.layer_offset
  texture_groups, err = prepare_texture_groups opts.shape_input or "", opts.shape_tolerance, opts.preserve_colors and true or false
  unless texture_groups
    show_message "AddTexture - invalid drawing input", err
    aegisub.cancel!
  estimated_lines = #sel * #texture_groups
  aegisub.cancel! unless confirm_large_output estimated_lines

  aegisub.progress.title "AddTexture"
  dlg = ZF.dialog subs, sel, active, false
  processed = 0
  plans = {}
  skipped_empty_groups = 0
  skipped_empty_lines = 0

  for l, line, sel_idx, _, n in dlg\iterSelected!
    aegisub.cancel! if cancel_requested!
    processed += 1
    aegisub.progress.set processed * 100 / n
    aegisub.progress.task ("Texturing line %d / %d")\format processed, n

    unless l.comment
      empty_groups_before_line = skipped_empty_groups
      text_box = build_text_clip dlg, line, opts.clip_tolerance
      clip_inner = trim text_box.clip
      fallback_color = text_primary_color l, line
      visibility_tags = if opts.copy_visibility_tags then collect_visibility_tags l.text else ""

      for group in *texture_groups
        aegisub.cancel! if cancel_requested!
        fitted, fit_err = fit_texture_to_box group, text_box.l, text_box.t, text_box.w, text_box.h
        unless fitted
          show_message "AddTexture - fit failed", fit_err
          aegisub.cancel!

        drawing = fitted.drawing
        clip_tag = "\\clip(#{clip_inner})"
        if opts.cut_to_text_shape
          cut, cut_err = cut_fitted_texture_to_clip fitted, clip_inner, opts.shape_tolerance
          if cut == nil
            show_message "AddTexture - shape cut failed", cut_err
            aegisub.cancel!
          if cut == ""
            skipped_empty_groups += 1
            continue
          drawing = cut
          clip_tag = ""

        new_line = ZF.table(l)\copy!
        new_line.comment = false
        new_line.layer = (l.layer or 0) + (tonumber(opts.layer_offset) or 1)
        new_line.text = string.format "{\\an7\\pos(%s,%s)%s%s\\1c%s%s\\p1}%s",
          format_number(fitted.x),
          format_number(fitted.y),
          opts.user_tags or "",
          visibility_tags,
          group.color or fallback_color,
          clip_tag,
          drawing
        plans[#plans + 1] = {line: new_line, selection_index: sel_idx}
      skipped_empty_lines += 1 if skipped_empty_groups > empty_groups_before_line

  aegisub.progress.set 100
  if #plans == 0
    show_message "AddTexture - no intersections", "No texture group intersected the selected text outlines. Nothing was inserted; empty intersections are valid and were skipped."
    return sel

  new_selection = LineOps.transaction subs, script_name, ->
    for plan in *plans
      dlg\insertLine plan.line, plan.selection_index
    dlg\getSelection!

  if skipped_empty_groups > 0
    show_message "AddTexture - completed with warnings", "Inserted #{#plans} texture lines. Skipped #{skipped_empty_groups} empty texture/text intersections across #{skipped_empty_lines} selected lines."
  new_selection

validate = valid_selection
if depctrl and depctrl.registerMacro
  depctrl\registerMacro script_name, script_description, main, validate, nil, false
else
  aegisub.register_macro script_name, script_description, main, validate
