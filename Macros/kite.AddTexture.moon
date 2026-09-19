export script_name        = "AddTexture"
export script_description = "Apply pasted ASS drawing textures clipped to selected text outlines"
export script_author      = "Kiterow"
export script_version     = "2.1.8"
export script_namespace   = "kite.AddTexture"

ConfigFile = "kite-addtexture.json"
DefaultTolerance = 1
MinTolerance = 0
MinLayerOffset = 0
LargeOutputWarningLines = 20000
DialogInputPreviewChars = 12000

local ZF, ASS, KiteUI, LineOps, depctrl
DependencyControl = require "l0.DependencyControl"
depctrl = DependencyControl{
  feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
  {
    {"ZF.main", version: "2.3.0", url: "https://github.com/TypesettingTools/zeref-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/TypesettingTools/zeref-Aegisub-Scripts/main/DependencyControl.json"}
    {"l0.ASSFoundation", version: "0.5.0", url: "https://github.com/TypesettingTools/ASSFoundation",
      feed: "https://raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json"}
    {"kite.UI", version: "1.5.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.LineOps", version: "1.7.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
  }
}
ZF, ASS, KiteUI, LineOps = depctrl\requireModules!

configHandler = (interface, fileName, _hasSections, version) ->
  KiteUI.dialogHandler interface, script_namespace, version, {
    {path: "?user/" .. fileName, format: "json_sections"}
  }

safeRequire = (name) ->
  ok, mod = pcall require, name
  if ok then mod else nil

clipboard = safeRequire "aegisub.clipboard"

Defaults = {
  clip_tolerance: 1.0
  shape_tolerance: 1.0
  layer_offset: 1
  preserve_colors: false
  cut_to_text_shape: false
  copy_visibility_tags: false
  user_tags: "\\bord0\\shad0"
}

normalizeColor = (color) ->
  return nil unless type(color) == "string"
  hex = LineOps.trim(color)\match "^&[Hh](%x+)&?$"
  return nil unless hex and (#hex == 6 or #hex == 8)
  hex = hex\sub(-6) if #hex > 6
  "&H" .. hex\upper! .. "&"

finiteNumber = (value, fallback = 0) ->
  number = tonumber value
  return fallback unless number and number == number and number != math.huge and number != -math.huge
  number

normalizeTolerance = (tolerance) ->
  value = finiteNumber tolerance, DefaultTolerance
  math.max value, MinTolerance

normalizeLayerOffset = (value) ->
  value = LineOps.round finiteNumber(value, Defaults.layer_offset)
  math.max value, MinLayerOffset

formatNumber = LineOps.formatNumber

normalizeDrawScale = (drawing, pScale) ->
  scale = finiteNumber pScale, 1
  return drawing if scale <= 1
  factor = math.pow 2, scale - 1
  tokens = {}
  for token in tostring(drawing or "")\gmatch "%S+"
    number = tonumber token
    if number and number == number and number != math.huge and number != -math.huge
      tokens[#tokens + 1] = formatNumber(number / factor)
    else
      tokens[#tokens + 1] = token
  table.concat tokens, " "

readClipboard = ->
  return "" unless clipboard and clipboard.get
  ok, data = pcall clipboard.get
  if ok and type(data) == "string" then data else ""

cleanShape = (raw) ->
  s = tostring(raw or "")
  s = s\gsub "\r", " "
  s = s\gsub "\n", " "
  s = s\gsub "\\N", " "
  s = s\gsub "%b{}", " "
  s = s\gsub "\\p%d+", " "
  s = s\gsub ",", " "
  s = s\gsub "([mMnNlLbBsSpPcC])", (c) -> " " .. c\lower! .. " "
  s = s\gsub "%s+", " "
  s = LineOps.trim s
  LineOps.trim(s\match("([mn]%s+%-?[%d%.]+%s+%-?[%d%.]+.*)") or s)

parseDialogueLine = (line) ->
  s = LineOps.trim line
  prefix = s\match("^(Dialogue:)") or s\match "^(Comment:)"
  return nil unless prefix
  rest = LineOps.trim s\sub #prefix + 1
  fields = {}
  pos = 1
  for _ = 1, 9
    comma = rest\find ",", pos, true
    return nil unless comma
    fields[#fields + 1] = rest\sub pos, comma - 1
    pos = comma + 1
  fields[#fields + 1] = rest\sub pos
  { text: fields[10] or "" }

splitPayloads = (input) ->
  normalized = tostring(input or "")\gsub "\r\n", "\n"
  normalized = normalized\gsub "\r", "\n"
  return {} if LineOps.trim(normalized) == ""

  lines, parsedCount = {}, 0
  for line in (normalized .. "\n")\gmatch "([^\n]*)\n"
    if LineOps.trim(line) != ""
      parsed = parseDialogueLine line
      parsedCount += 1 if parsed
      lines[#lines + 1] = { text: parsed and parsed.text or line, line: parsed }

  return { { text: normalized } } if parsedCount == 0

  payloads = {}
  for item in *lines
    payloads[#payloads + 1] = item
  payloads

copyState = (state = {}) ->
  {
    p: state.p
    color: state.color
    align: state.align
    pos: state.pos and { state.pos[1], state.pos[2] } or nil
    scaleX: state.scaleX
    scaleY: state.scaleY
  }

updateTagState = (tags, state) ->
  tags = tostring(tags or "")
  tags = tags\gsub "\\t%s*%b()", ""
  for color in tags\gmatch "\\1?c%s*(&[Hh]%x+&?)"
    state.color = normalizeColor(color) or state.color
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
  state.scaleX = tonumber(fscx) or state.scaleX if fscx
  state.scaleY = tonumber(fscy) or state.scaleY if fscy

collectTagState = (input) ->
  state = { p: 0, color: nil, align: 7, pos: nil, scaleX: 100, scaleY: 100 }
  for tags in tostring(input or "")\gmatch "{([^}]*)}"
    updateTagState tags, state
  state

appendRecord = (records, raw, state = {}, sourceIndex = 1, kind = "drawing", applyPosition = false) ->
  drawing = cleanShape raw
  return false if drawing == "" or not drawing\match "^[mn]%s+"
  drawing = normalizeDrawScale drawing, state.p or 1
  records[#records + 1] = {
    drawing: drawing
    color: normalizeColor state.color
    sourceIndex: sourceIndex
    kind: kind
    applyPosition: applyPosition and state.pos != nil
    align: state.align or 7
    pos: state.pos and { state.pos[1], state.pos[2] } or nil
    scaleX: tonumber(state.scaleX) or 100
    scaleY: tonumber(state.scaleY) or 100
  }
  true

appendClipArgs = (records, args, state = {}, sourceIndex = 1) ->
  localState = copyState state
  localState.scaleX, localState.scaleY, localState.align = 100, 100, 7
  pScale, drawing = tostring(args or "")\match "^%s*(%d+)%s*,%s*([mMnN]%s+.+)$"
  if drawing
    localState.p = tonumber(pScale) or 1
  else
    drawing = tostring(args or "")\match "^%s*([mMnN]%s+.+)$"
    localState.p = 1
  if drawing
    return appendRecord records, drawing, localState, sourceIndex, "clip", false
  false

extractClipShapes = (text, records, sourceIndex) ->
  state = collectTagState text
  before = #records
  wrapped = tostring(text or "")
  wrapped = "{" .. wrapped .. "}" unless wrapped\find "{", 1, true
  for call in *LineOps.tagCalls(wrapped, {clip: true, iclip: true})
    appendClipArgs records, call.value\sub(2, -2), state, sourceIndex if call.top_level
  #records > before

extractPDrawings = (text, records, sourceIndex) ->
  text = tostring(text or "")
  seed = collectTagState text
  state = { p: 0, color: nil, align: seed.align, pos: seed.pos, scaleX: 100, scaleY: 100 }
  pos = 1
  before = #records
  while true
    open, close, tags = text\find "{([^}]*)}", pos
    chunk = if open then text\sub(pos, open - 1) else text\sub(pos)
    appendRecord records, chunk, state, sourceIndex, "drawing", true if state.p and state.p > 0
    break unless open
    updateTagState tags, state
    pos = close + 1
  #records > before

extractRawShape = (text, records, sourceIndex) ->
  state = collectTagState text
  stripped = tostring(text or "")\gsub "%b{}", " "
  stripped = stripped\gsub "\r", " "
  stripped = stripped\gsub "\n", " "
  drawing = stripped\match "%f[%a]([mMnN]%s*%-?[%d%.]+%s+%-?[%d%.]+.*)"
  if drawing
    return appendRecord records, drawing, state, sourceIndex, "drawing", state.pos != nil
  false

sectionString = (section) ->
  ok, value = pcall ->
    if section.toString
      section\toString!
    elseif section.getString
      section\getString!
    elseif section.getTagParams
      section\getTagParams!
  if ok and value then tostring(value) else ""

assfTagName = (tag) ->
  if tag and tag.__tag then tag.__tag.name else nil

assfTagValues = (tag) ->
  ok, a, b, c, d, e, f = pcall -> tag\getTagParams!
  return nil unless ok
  { a, b, c, d, e, f }

formatAssfColor = (values) ->
  return nil unless values and values[1] and values[2] and values[3]
  string.format "&H%02X%02X%02X&", values[1], values[2], values[3]

updateAssfTagState = (tag, state) ->
  name = assfTagName tag
  return false unless name
  values = assfTagValues tag
  return false unless values

  switch name
    when "color1"
      state.color = formatAssfColor(values) or state.color
    when "align"
      state.align = tonumber(values[1]) or state.align
    when "position"
      state.pos = { tonumber(values[1]), tonumber(values[2]) } if values[1] and values[2]
    when "move"
      state.pos = { tonumber(values[1]), tonumber(values[2]) } if values[1] and values[2]
    when "scale_x"
      state.scaleX = tonumber(values[1]) or state.scaleX
    when "scale_y"
      state.scaleY = tonumber(values[1]) or state.scaleY
    else
      return false
  true

appendAssfClip = (records, tag, state, sourceIndex) ->
  name = assfTagName tag
  return false unless name == "clip_vect" or name == "iclip_vect" or name == "clip_rect" or name == "iclip_rect"

  localState = copyState state
  localState.p = 1
  localState.scaleX, localState.scaleY, localState.align = 100, 100, 7

  values = assfTagValues tag
  drawing = nil
  if values
    if type(values[2]) == "string"
      drawing = values[2]
      localState.p = tonumber(values[1]) or 1
    else
      drawing = values[1]
  if drawing and type(drawing) == "string" and drawing\match "^%s*[mMnN]%s+"
    return appendRecord records, drawing, localState, sourceIndex, "clip", false

  if tag.getDrawing
    ok, drawingSection, pos = pcall -> tag\getDrawing true
    if ok and drawingSection
      if pos and pos.getTagParams
        px, py = pos\getTagParams!
        localState.pos = { px, py }
        return appendRecord records, sectionString(drawingSection), localState, sourceIndex, "clip", true
      return appendRecord records, sectionString(drawingSection), localState, sourceIndex, "clip", false
  false

extractAssfSections = (payload, records, sourceIndex) ->
  return false unless ASS and ASS.Parser and ASS.Parser.LineText
  line = payload.line or { text: payload.text or "" }
  ok, sections = pcall -> ASS.Parser.LineText\getSections line
  return false unless ok and type(sections) == "table"

  before = #records
  seed = collectTagState payload.text
  state = { p: 0, color: nil, align: seed.align, pos: seed.pos, scaleX: 100, scaleY: 100 }
  for section in *sections
    if ASS\instanceOf(section, ASS.Section.Tag)
      if section.tags
        for tag in *section.tags
          appendAssfClip records, tag, state, sourceIndex
          updateAssfTagState tag, state
      else
        updateTagState sectionString(section), state
    elseif ASS\instanceOf(section, ASS.Section.Drawing)
      drawState = copyState state
      okScale, pScale = pcall -> section.scale\get!
      drawState.p = okScale and tonumber(pScale) or 1
      appendRecord records, sectionString(section), drawState, sourceIndex, "drawing", true
  #records > before

extractFromText = (text, records, sourceIndex) ->
  before = #records
  return #records - before if extractPDrawings text, records, sourceIndex
  return #records - before if extractClipShapes text, records, sourceIndex
  extractRawShape text, records, sourceIndex
  #records - before

extractAssDrawings = (input) ->
  records = {}
  payloads = splitPayloads input
  for i, payload in ipairs payloads
    extracted = extractAssfSections payload, records, i
    extractFromText payload.text, records, i unless extracted
  extractFromText input, records, 1 if #records == 0
  records

normalizeInputNewlines = (value) ->
  normalized = tostring(value or "")\gsub "\r\n", "\n"
  normalized = normalized\gsub "\r", "\n"
  normalized

resolveDialogInput = (dialogInput, presentedInput, clipboardInputs = {}) ->
  dialogInput = tostring dialogInput or ""
  if normalizeInputNewlines(dialogInput) == normalizeInputNewlines(presentedInput)
    for candidate in *clipboardInputs
      candidate = tostring candidate or ""
      return candidate, true if LineOps.trim(candidate) != "" and #extractAssDrawings(candidate) > 0
  dialogInput, false

shapeInfo = (drawing) ->
  ok, shape = pcall -> ZF.shape drawing
  return nil, "Invalid ASS shape." unless ok and shape
  shapeL = finiteNumber shape.l, nil
  shapeT = finiteNumber shape.t, nil
  shapeW = finiteNumber shape.w, nil
  shapeH = finiteNumber shape.h, nil
  return nil, "ASS shape has invalid bounds." unless shapeL and shapeT and shapeW and shapeH
  return nil, "ASS shape has empty bounds." unless shapeW > 0 and shapeH > 0
  shape

buildShape = (shape) ->
  LineOps.trim shape\build!

transformRecord = (record) ->
  shape, err = shapeInfo record.drawing
  return nil, err unless shape
  if (record.scaleX and record.scaleX != 100) or (record.scaleY and record.scaleY != 100)
    shape\scale record.scaleX or 100, record.scaleY or 100
    shape\setBoudingBox!
  if record.applyPosition and record.pos
    shape\setPosition record.align or 7, "tcp", record.pos[1] or 0, record.pos[2] or 0
  drawing = buildShape shape
  shape, err = shapeInfo drawing
  return nil, err unless shape
  {
    drawing: drawing
    color: record.color
    sourceIndex: record.sourceIndex
  }

joinDrawings = (items) ->
  out = {}
  for item in *items
    drawing = if type(item) == "table" then item.drawing else item
    out[#out + 1] = LineOps.trim drawing if drawing and LineOps.trim(drawing) != ""
  LineOps.trim table.concat out, " "

moveDrawing = (drawing, dx = 0, dy = 0) ->
  shape, err = shapeInfo drawing
  return nil, err unless shape
  buildShape shape\move dx, dy

scaleDrawing = (drawing, scale = 1) ->
  shape, err = shapeInfo drawing
  return nil, err unless shape
  buildShape shape\scale scale * 100, scale * 100

simplifyDrawing = (drawing, tolerance) ->
  tol = normalizeTolerance tolerance
  ok, simplified = pcall ->
    ZF.clipper(drawing)\simplify!\build "line", tol
  return nil, "Could not simplify ASS shape: #{simplified}" unless ok
  simplified = LineOps.trim simplified
  simplified = drawing if simplified == ""
  shape, err = shapeInfo simplified
  return nil, err unless shape
  simplified

prepareTextureGroups = (input, tolerance, preserveColors) ->
  extracted = extractAssDrawings input
  if #extracted == 0
    return nil, "Paste raw ASS drawing data, a {\\p1} drawing, a vector \\clip(), or Dialogue/Comment lines containing drawings."

  transformed = {}
  for i, record in ipairs extracted
    item, err = transformRecord record
    unless item
      return nil, ("Texture shape %d failed: %s")\format i, err or "invalid shape"
    transformed[#transformed + 1] = item

  combined = joinDrawings transformed
  globalShape, err = shapeInfo combined
  return nil, err unless globalShape

  global = {
    l: globalShape.l
    t: globalShape.t
    w: globalShape.w
    h: globalShape.h
  }
  return nil, "ASS texture composition has empty bounds." if global.w <= 0 or global.h <= 0

  normalizeToGlobal = (drawing) ->
    moveDrawing drawing, -global.l, -global.t

  unless preserveColors
    moved, moveErr = normalizeToGlobal combined
    return nil, moveErr unless moved
    simplified, simplifyErr = simplifyDrawing moved, tolerance
    return nil, simplifyErr unless simplified
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
    drawing = joinDrawings bucket.drawings
    moved, moveErr = normalizeToGlobal drawing
    return nil, moveErr unless moved
    simplified, simplifyErr = simplifyDrawing moved, tolerance
    return nil, simplifyErr unless simplified
    groups[#groups + 1] = {
      drawing: simplified
      color: bucket.color
      w: global.w
      h: global.h
    }

  groups, global

fitTextureToBox = (group, targetL, targetT, targetW, targetH) ->
  targetL = finiteNumber targetL, 0
  targetT = finiteNumber targetT, 0
  targetW = finiteNumber targetW, 0
  targetH = finiteNumber targetH, 0
  return nil, "Text outline has empty bounds." if targetW <= 0 or targetH <= 0
  return nil, "Texture shape has empty bounds." unless group and group.w and group.h and group.w > 0 and group.h > 0

  scale = math.max targetW / group.w, targetH / group.h
  drawing, err = scaleDrawing group.drawing, scale
  return nil, err unless drawing
  scaledW = group.w * scale
  scaledH = group.h * scale
  {
    drawing: drawing
    scale: scale
    x: targetL + (targetW - scaledW) / 2
    y: targetT + (targetH - scaledH) / 2
  }

cutFittedTextureToClip = (fitted, clipDrawing, tolerance) ->
  absolute, moveErr = moveDrawing fitted.drawing, fitted.x, fitted.y
  return nil, moveErr unless absolute
  tol = normalizeTolerance tolerance
  ok, clipped = pcall ->
    ZF.clipper(absolute, clipDrawing, true)\clip(false)\build "line", tol
  return nil, "Could not cut texture shape to text outline: #{clipped}" unless ok
  clipped = LineOps.trim clipped
  return "" if clipped == ""
  localDrawing, localErr = moveDrawing clipped, -fitted.x, -fitted.y
  return nil, localErr unless localDrawing
  localDrawing

buildTextClip = (dlg, line, tolerance) ->
  call = ZF.line(line)\prepoc dlg
  pers = dlg\getPerspectiveTags line
  pers.p = "text" if pers.p == 0
  px, py = pers.pos[1], pers.pos[2]
  shape = ZF.util\isShape line.text
  unless shape
    shape = call\toShape dlg, nil, px, py
  styleRef = line.styleref
  oldScaleX, oldScaleY = nil, nil
  changedStyleScale = false
  if not ZF.util\isShape(line.text) and styleRef
    oldScaleX, oldScaleY = styleRef.scaleX, styleRef.scaleY
    styleRef.scaleX, styleRef.scaleY = 100, 100
    changedStyleScale = true
  ok, clipAbs = pcall ->
    align = styleRef and styleRef.align or 7
    ZF.shape(shape, true)\setPosition(align)\expand(line, pers)\move(px, py)\build!
  if styleRef and changedStyleScale
    styleRef.scaleX, styleRef.scaleY = oldScaleX, oldScaleY
  error clipAbs unless ok
  tol = normalizeTolerance tolerance
  simplified = LineOps.trim ZF.clipper(clipAbs)\simplify!\build "line", tol
  sh = ZF.shape simplified
  error "Text outline has invalid bounds." unless finiteNumber(sh.l, nil) and finiteNumber(sh.t, nil) and finiteNumber(sh.w, nil) and finiteNumber(sh.h, nil)
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

textPrimaryColor = (l, line) ->
  staticText = tostring(l.text or "")\gsub "\\t%s*%b()", ""
  c1 = staticText\match "\\1?c%s*(&[Hh]%x+&?)"
  return normalizeColor c1 if c1
  if line.styleref and line.styleref.color1
    return normalizeColor(line.styleref.color1) or line.styleref.color1
  "&HFFFFFF&"

scanVisibilityTags = (tags) ->
  frames = {{tokens: LineOps.overrideTokens(tags), index: 1, out: {}}}
  while #frames > 0
    frame = frames[#frames]
    token = frame.tokens[frame.index]
    unless token
      result = table.concat frame.out
      table.remove frames
      return result if #frames == 0
      parent = frames[#frames]
      parent.out[#parent.out + 1] = "\\t(" .. frame.prefix .. result .. ")" if result != ""
      continue
    frame.index += 1
    if token.name == "t"
      body = token.value\sub 2, -2
      tagStart = body\find "\\", 1, true
      if tagStart
        frames[#frames + 1] = {
          tokens: LineOps.overrideTokens(body\sub(tagStart))
          index: 1
          out: {}
          prefix: body\sub(1, tagStart - 1)
        }
    elseif token.name == "alpha" or token.name\match("^[1234]a$") or token.name == "fad" or token.name == "fade"
      frame.out[#frame.out + 1] = token.raw
  ""

collectVisibilityTags = (text) ->
  out = {}
  for tags in tostring(text or "")\gmatch "{([^}]*)}"
    copied = scanVisibilityTags tags
    out[#out + 1] = copied if copied != ""
  table.concat out, ""

showMessage = (title, msg) ->
  KiteUI.message msg, {:title}

confirmLargeOutput = (estimatedLines) ->
  return true if estimatedLines <= LargeOutputWarningLines
  btn = aegisub.dialog.display {
    { class: "label", label: "AddTexture - large output warning", x: 0, y: 0, width: 42 }
    { class: "textbox", value: "This operation can generate up to #{estimatedLines} lines. The warning threshold is #{LargeOutputWarningLines}; processing may take longer and use more memory, but AddTexture can continue.", x: 0, y: 1, width: 42, height: 8 }
  }, { "Continue", "Cancel" }, { ok: "Continue", close: "Cancel" }
  btn == "Continue"

cancelRequested = ->
  return false unless aegisub.progress and aegisub.progress.is_cancelled
  aegisub.progress.is_cancelled!

buildInterface = ->
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
        value: Defaults.preserve_colors
        config: true
        x: 0
        y: 12
        width: 3
      }
      cut_to_text_shape: {
        class: "checkbox"
        name: "cut_to_text_shape"
        label: "Clip to text"
        value: Defaults.cut_to_text_shape
        config: true
        x: 3
        y: 12
        width: 4
      }
      copy_visibility_tags: {
        class: "checkbox"
        name: "copy_visibility_tags"
        label: "Copy alpha/fad"
        value: Defaults.copy_visibility_tags
        config: true
        x: 0
        y: 13
        width: 7
      }
      user_tags_label: { class: "label", label: "Extra tags:", x: 0, y: 14, width: 2 }
      user_tags: {
        class: "edit"
        name: "user_tags"
        value: Defaults.user_tags
        config: true
        x: 2
        y: 14
        width: 5
      }
      clip_tolerance_label: { class: "label", label: "Text simplify:", x: 0, y: 15, width: 4 }
      clip_tolerance: {
        class: "floatedit"
        name: "clip_tolerance"
        value: Defaults.clip_tolerance
        config: true
        min: MinTolerance
        x: 4
        y: 15
        width: 3
      }
      shape_tolerance_label: { class: "label", label: "Shape simplify:", x: 0, y: 16, width: 4 }
      shape_tolerance: {
        class: "floatedit"
        name: "shape_tolerance"
        value: Defaults.shape_tolerance
        config: true
        min: MinTolerance
        x: 4
        y: 16
        width: 3
      }
      layer_offset_label: { class: "label", label: "Layer offset:", x: 0, y: 17, width: 4 }
      layer_offset: {
        class: "intedit"
        name: "layer_offset"
        value: Defaults.layer_offset
        config: true
        min: MinLayerOffset
        x: 4
        y: 17
        width: 3
      }
    }
  }

showDialog = ->
  interface = buildInterface!
  options = nil
  if configHandler
    options = configHandler interface, ConfigFile, true, script_version
    options\read!
    options\updateInterface "main"

  clipboardInput = readClipboard!
  while true
    presentedInput = clipboardInput
    if #presentedInput > DialogInputPreviewChars
      presentedInput = presentedInput\sub 1, DialogInputPreviewChars
      interface.main.shape_label.label = "ASS drawings (#{#clipboardInput} clipboard chars; editing replaces this full input):"
    else
      interface.main.shape_label.label = "ASS drawings / Dialogue lines:"
    interface.main.shape_input.text = presentedInput
    btn, res = aegisub.dialog.display interface.main, { "Execute", "Paste clipboard", "Cancel" }, { ok: "Execute", close: "Cancel" }
    aegisub.cancel! if btn != "Execute" and btn != "Paste clipboard"
    if btn == "Paste clipboard"
      clipboardInput = readClipboard!
      for name, value in pairs res
        control = interface.main[name]
        control.value = value if control and name != "shape_input"
      continue
    res.shape_input = resolveDialogInput res.shape_input, presentedInput, {clipboardInput}
    if options
      options\updateConfiguration res, "main"
      options\write!
    return res

validSelection = (subs, sel) ->
  records = LineOps.selectedLines subs, sel, ((line) -> line and line.class == "dialogue" and not line.comment), true
  records != nil and #records > 0

main = (subs, sel, active) ->
  unless validSelection subs, sel
    aegisub.dialog.display { { class: "label", label: "Select at least one uncommented dialogue line." } }, { "OK" }
    aegisub.cancel!

  opts = showDialog!
  opts.clip_tolerance = normalizeTolerance opts.clip_tolerance
  opts.shape_tolerance = normalizeTolerance opts.shape_tolerance
  opts.layer_offset = normalizeLayerOffset opts.layer_offset
  textureGroups, err = prepareTextureGroups opts.shape_input or "", opts.shape_tolerance, opts.preserve_colors and true or false
  unless textureGroups
    showMessage "AddTexture - invalid drawing input", err
    aegisub.cancel!
  estimatedLines = #sel * #textureGroups
  aegisub.cancel! unless confirmLargeOutput estimatedLines

  aegisub.progress.title "AddTexture"
  dlg = ZF.dialog subs, sel, active, false
  processed = 0
  plans = {}
  skippedEmptyGroups = 0
  skippedEmptyLines = 0

  for l, line, selIdx, _, n in dlg\iterSelected!
    aegisub.cancel! if cancelRequested!
    processed += 1
    aegisub.progress.set processed * 100 / n
    aegisub.progress.task ("Texturing line %d / %d")\format processed, n

    unless l.comment
      emptyGroupsBeforeLine = skippedEmptyGroups
      textBox = buildTextClip dlg, line, opts.clip_tolerance
      clipInner = LineOps.trim textBox.clip
      fallbackColor = textPrimaryColor l, line
      visibilityTags = if opts.copy_visibility_tags then collectVisibilityTags l.text else ""

      for group in *textureGroups
        aegisub.cancel! if cancelRequested!
        fitted, fitErr = fitTextureToBox group, textBox.l, textBox.t, textBox.w, textBox.h
        unless fitted
          showMessage "AddTexture - fit failed", fitErr
          aegisub.cancel!

        drawing = fitted.drawing
        clipTag = "\\clip(#{clipInner})"
        if opts.cut_to_text_shape
          cut, cutErr = cutFittedTextureToClip fitted, clipInner, opts.shape_tolerance
          if cut == nil
            showMessage "AddTexture - shape cut failed", cutErr
            aegisub.cancel!
          if cut == ""
            skippedEmptyGroups += 1
            continue
          drawing = cut
          clipTag = ""

        newLine = ZF.table(l)\copy!
        newLine.comment = false
        newLine.layer = (l.layer or 0) + (tonumber(opts.layer_offset) or 1)
        newLine.text = string.format "{\\an7\\pos(%s,%s)%s%s\\1c%s%s\\p1}%s",
          formatNumber(fitted.x),
          formatNumber(fitted.y),
          opts.user_tags or "",
          visibilityTags,
          group.color or fallbackColor,
          clipTag,
          drawing
        plans[#plans + 1] = {line: newLine, selectionIndex: selIdx}
      skippedEmptyLines += 1 if skippedEmptyGroups > emptyGroupsBeforeLine

  aegisub.progress.set 100
  if #plans == 0
    showMessage "AddTexture - no intersections", "No texture group intersected the selected text outlines. Nothing was inserted; empty intersections are valid and were skipped."
    return sel

  newSelection = LineOps.transaction subs, script_name, ->
    for plan in *plans
      aegisub.cancel! if cancelRequested!
      dlg\insertLine plan.line, plan.selectionIndex
    dlg\getSelection!

  if skippedEmptyGroups > 0
    showMessage "AddTexture - completed with warnings", "Inserted #{#plans} texture lines. Skipped #{skippedEmptyGroups} empty texture/text intersections across #{skippedEmptyLines} selected lines."
  newSelection, newSelection and newSelection[1]

validate = validSelection
if depctrl and depctrl.registerMacro
  depctrl\registerMacro script_name, script_description, main, validate, nil, false
else
  aegisub.register_macro script_name, script_description, main, validate

require("kite.UI").publishActions()
