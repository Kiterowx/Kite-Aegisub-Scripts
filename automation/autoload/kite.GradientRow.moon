export script_name = "Gradient Row"
export script_description = "Create adaptive color gradients across selected lines and visible text from palettes or inline color states."
export script_author = "Kiterow"
export script_namespace = "kite.GradientRow"
export script_version = "1.8.9"

DependencyControl = require "l0.DependencyControl"
depctrl = DependencyControl{
  feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
  {
    {"a-mo.LineCollection", version: "1.3.0", url: "https://github.com/TypesettingTools/Aegisub-Motion",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"},
    {"a-mo.Line", version: "1.5.3", url: "https://github.com/TypesettingTools/Aegisub-Motion",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"},
    {"l0.ASSFoundation", version: "0.5.0", url: "https://github.com/TypesettingTools/ASSFoundation",
      feed: "https://raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json"},
    {"arch.Perspective", version: "1.2.1", url: "https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json"},
    {"kite.Core", version: "1.1.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
    {"kite.UI", version: "1.5.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
    {"kite.LineOps", version: "1.7.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
    {"SubInspector.Inspector", version: "0.6.0", url: "https://github.com/TypesettingTools/SubInspector",
      feed: "https://raw.githubusercontent.com/TypesettingTools/SubInspector/master/DependencyControl.json",
      optional: true},
      {"kite.AssContext", version: "1.1.1"}
      {"kite.Color", version: "1.2.0"}
  }
}

LineCollection, Line, ASS, ArchPerspective, Core, KiteUI, LineOps, SubInspector = depctrl\requireModules!
Color = require "kite.Color"
AssContext = require "kite.AssContext"
logger = depctrl\getLogger!
haveSubInspector = depctrl\checkOptionalModules "SubInspector.Inspector"

colorSlots = {"c", "2c", "3c", "4c"}
gradientModes = {"Horizontal", "Vertical", "Rotated", "Char Line", "Char Selection"}
geometryEpsilon = 0.0005
boundarySearchIterations = 12
clipBleed = 0.5
clipCoverBleed = clipBleed * 2
minStripSize = 1
palettePageSize = 8
minimumPerspectiveExtent = 0.01
perspectivePadding = 4
rotatedMinPadding = 1
rotatedMaxPadding = 4
rotatedPaddingRatio = 0.25

colorTagName = (slot) ->
  return "color1" if slot == "c"
  return "color2" if slot == "2c"
  return "color3" if slot == "3c"
  return "color4" if slot == "4c"
  nil

makeDefaultSlots = ->
  slots = {}
  for slot in *colorSlots
    slots[slot] = slot == "c"
  slots

readSlots = (res) ->
  slots = makeDefaultSlots!
  if res
    for slot in *colorSlots
      slots[slot] = res[slot] and true or false
  slots

finiteNumber = (value, fallback = nil) ->
  Core.finiteNumber(value) or fallback

normalizeGuiColor = (value) ->
  normalized = Color.normalizeStrict value
  Color.toHex normalized if normalized

normalizeState = (state) ->
  state or= {}
  state.mode or= "Horizontal"
  knownMode = false
  for mode in *gradientModes
    if state.mode == mode
      knownMode = true
      break
  state.mode = "Horizontal" unless knownMode
  state.use_between = state.use_between and true or false
  state.strip = math.max(minStripSize, math.floor(finiteNumber(state.strip, 2)))
  state.accel = finiteNumber state.accel, 1
  state.accel = 1 if state.accel <= 0
  state.angle = finiteNumber state.angle, 0
  defaults = makeDefaultSlots!
  state.slots or= {}
  for slot in *colorSlots
    if state.slots[slot] == nil
      state.slots[slot] = defaults[slot]
    else
      state.slots[slot] = state.slots[slot] and true or false
  colors = {}
  for color in *(state.colors or {})
    normalized = normalizeGuiColor color
    colors[#colors + 1] = normalized if normalized
  state.colors = colors
  if #state.colors < 2
    state.colors = {"#FFFFFF", "#FF0000"}
  state

defaultState = ->
  normalizeState {
    mode: "Horizontal"
    use_between: false
    strip: 2
    accel: 1
    angle: 0
    slots: makeDefaultSlots!
    colors: {"#FFFFFF", "#FF0000"}
  }

legacyGradient = (loaded) ->
  state = {
    mode: loaded.mode
    use_between: loaded.use_between
    strip: loaded.strip
    accel: loaded.accel
    angle: loaded.angle
    slots: {}
    colors: {}
  }
  for slot in *colorSlots
    state.slots[slot] = loaded["slot_#{slot}"]
  for color in tostring(loaded.colors or "")\gmatch "[^,]+"
    normalized = normalizeGuiColor color
    state.colors[#state.colors + 1] = normalized if normalized
  normalizeState state

gradientSettings = KiteUI.settings script_namespace, script_version, {main: defaultState!}, {
  {path: "?user/kite.GradientRow.conf", format: "key_value", target: "main", transform: legacyGradient}
}

saveState = (state) ->
  gradientSettings\update "main", normalizeState(state)
  gradientSettings\write!

loadState = ->
  normalizeState gradientSettings\values "main"

windowError = (message) ->
  KiteUI.message message
  aegisub.cancel!

formatNum = (value) ->
  value = finiteNumber value
  error "Gradient Row could not format a vector clip coordinate." unless value
  value = 0 if math.abs(value) < geometryEpsilon
  ("%.2f")\format value

assColor = (color) ->
  Color.fromRGB color.r, color.g, color.b

tagValue = (tag, fallback = 0) ->
  return finiteNumber(tag, fallback) unless type(tag) == "table"
  return finiteNumber(tag.value, fallback) if tag.value != nil
  fallback

layoutScaleForLine = (line) ->
  AssContext.layoutScale line

positionFromText = (text) ->
  AssContext.explicitPosition text

implicitPositionTag = (line) ->
  x, y = positionFromText line.text
  return nil if x != nil and y != nil
  x, y, err = AssContext.position line
  error err, 0 unless x and y
  "\\pos(#{formatNum x},#{formatNum y})"

originFromText = (line) ->
  x, y = AssContext.origin line
  if x and y then {:x, :y} else nil

rotationFromText = (line) ->
  rotation, call = LineOps.tagNumber line.text, "frz", nil, true
  rotation = LineOps.tagNumber(line.text, "fr", nil, true) unless call
  style = line.styleRef or line.styleref or {}
  finiteNumber(rotation) or finiteNumber(style.angle, 0)

rotatePoint = (point, origin, angle) ->
  radians = math.rad angle
  cosA, sinA = math.cos(radians), math.sin(radians)
  dx, dy = point.x - origin.x, point.y - origin.y
  {
    x: origin.x + dx * cosA - dy * sinA
    y: origin.y + dx * sinA + dy * cosA
  }

numberTag = (text, tag, fallback) ->
  value = LineOps.tagNumber text, tag, finiteNumber(fallback, 0), true
  finiteNumber value, finiteNumber(fallback, 0)

textPad = (line) ->
  style = line.styleRef or line.styleref or {}
  outline = numberTag(line.text, "bord", style.outline or 0)
  shadow = numberTag(line.text, "shad", style.shadow or 0)
  math.abs(outline) + math.abs(shadow) + 2

anchoredTextBounds = (line, width, height, pad) ->
  x, y = AssContext.position line
  return nil unless x and y and width and height

  style = line.styleRef or line.styleref or {}
  align = AssContext.alignment line.text, style
  pad or= textPad line

  hAnchor = align % 3
  left = switch hAnchor
    when 1 then x
    when 2 then x - width / 2
    else x - width
  right = left + width

  vAnchor = math.ceil(align / 3)
  top = switch vAnchor
    when 3 then y
    when 2 then y - height / 2
    else y - height
  bottom = top + height

  {left - pad, top - pad, right + pad, bottom + pad}

measuredTextBounds = (line) ->
  okParse, data = pcall -> ASS\parse line
  return nil unless okParse and data
  ok, width, height = pcall -> data\getTextExtents true
  width, height = finiteNumber(width), finiteNumber(height)
  return nil unless ok and width and height and width > 0 and height > 0
  anchoredTextBounds line, width, height, textPad line

removeColorTagText = (text, slot) ->
  names = if slot == "c" then {"c", "1c"} else {slot}
  LineOps.mapTagCalls text, names, (call) ->
    return "" if call.top_level and Color.parseAss(call.value)
    call.raw

applyColorTagsText = (text, slots, color) ->
  prefix = ""
  for slot in *colorSlots
    if slots[slot]
      text = removeColorTagText text, slot
      tagText = if slot == "c" then "\\c#{assColor color}" else "\\#{slot}#{assColor color}"
      prefix ..= tagText
  LineOps.prependTag text, prefix

roughTextBounds = (line) ->
  style = line.styleRef or line.styleref or {}
  visible = LineOps.visibleText line.text
  charCount = 0
  charCount += 1 for _ in visible\gmatch "[%z\1-\127\194-\244][\128-\191]*"
  charCount = math.max 1, charCount
  fs = math.max(geometryEpsilon, math.abs(numberTag(line.text, "fs", style.fontsize or 40)))
  fscx = math.abs(numberTag(line.text, "fscx", style.scale_x or 100)) / 100
  fscy = math.abs(numberTag(line.text, "fscy", style.scale_y or 100)) / 100

  width = math.max(fs * 0.75, charCount * fs * 0.58 * fscx)
  height = fs * 1.15 * fscy
  anchoredTextBounds line, width, height, textPad line

normalizeBounds = (bounds) ->
  return nil unless type(bounds) == "table"
  left, top, right, bottom = unpack bounds
  left, top = finiteNumber(left), finiteNumber(top)
  right, bottom = finiteNumber(right), finiteNumber(bottom)
  return nil unless left and top and right and bottom
  left, right = right, left if left > right
  top, bottom = bottom, top if top > bottom
  {left, top, right, bottom}

validBounds = (bounds) ->
  normalized = normalizeBounds bounds
  return nil unless normalized
  return nil unless normalized[3] - normalized[1] > geometryEpsilon and normalized[4] - normalized[2] > geometryEpsilon
  normalized

boundsToRect = (bounds) ->
  return nil unless type(bounds) == "table"
  x, y = finiteNumber(bounds.x), finiteNumber(bounds.y)
  width, height = finiteNumber(bounds.w), finiteNumber(bounds.h)
  if x and y and width and height and width > 0 and height > 0
    return normalizeBounds {x, y, x + width, y + height}
  if bounds[1] and bounds[2]
    x1, y1 = finiteNumber(bounds[1].x), finiteNumber(bounds[1].y)
    x2, y2 = finiteNumber(bounds[2].x), finiteNumber(bounds[2].y)
    return normalizeBounds {x1, y1, x2, y2} if x1 and y1 and x2 and y2
  left = bounds.left or bounds.l
  top = bounds.top or bounds.t
  right = bounds.right or bounds.r
  bottom = bounds.bottom or bounds.b
  if left and top and right and bottom
    return normalizeBounds {left, top, right, bottom}
  nil

drawingLocalBounds = (data) ->
  left, top, right, bottom = nil, nil, nil, nil
  data\callback (section) ->
    if section.instanceOf and section.instanceOf[ASS.Section.Drawing]
      ok, ext = pcall -> section\getExtremePoints true
      if ok and ext and ext.left and ext.top and ext.right and ext.bottom
        left = ext.left.x if not left or ext.left.x < left
        top = ext.top.y if not top or ext.top.y < top
        right = ext.right.x if not right or ext.right.x > right
        bottom = ext.bottom.y if not bottom or ext.bottom.y > bottom
  return nil unless left and top and right and bottom
  normalizeBounds {left, top, right, bottom}

rectClipFromText = (text) ->
  args, call = LineOps.tagArguments text, "clip", true
  return nil unless call and #args == 4
  validBounds {args[1], args[2], args[3], args[4]}

rectClipTag = (bounds) ->
  left, top, right, bottom = unpack(validBounds(bounds) or error("Gradient Row received empty clip bounds."))
  "\\clip(#{math.floor(left)},#{math.floor(top)},#{math.ceil(right)},#{math.ceil(bottom)})"

rectPoints = (bounds) ->
  left, top, right, bottom = unpack(validBounds(bounds) or error("Gradient Row received empty geometry bounds."))
  {
    {x: left, y: top}
    {x: right, y: top}
    {x: right, y: bottom}
    {x: left, y: bottom}
  }

vectorClipTag = (points) ->
  "\\clip(m #{formatNum points[1].x} #{formatNum points[1].y} l #{formatNum points[2].x} #{formatNum points[2].y} l #{formatNum points[3].x} #{formatNum points[3].y} l #{formatNum points[4].x} #{formatNum points[4].y})"

lerpPoint = (a, b, factor) ->
  {
    x: a.x + (b.x - a.x) * factor
    y: a.y + (b.y - a.y) * factor
  }

pointDistance = (a, b) ->
  dx, dy = b.x - a.x, b.y - a.y
  math.sqrt dx * dx + dy * dy

normalizeVector = (x, y) ->
  length = math.sqrt x * x + y * y
  return {x: 0, y: 0} if length < geometryEpsilon
  {x: x / length, y: y / length}

outwardEdgeNormal = (a, b) ->
  normalizeVector b.y - a.y, -(b.x - a.x)

offsetEdge = (a, b, amount) ->
  normal = outwardEdgeNormal a, b
  {
    {x: a.x + normal.x * amount, y: a.y + normal.y * amount}
    {x: b.x + normal.x * amount, y: b.y + normal.y * amount}
  }

lineIntersection = (a1, a2, b1, b2) ->
  dax, day = a2.x - a1.x, a2.y - a1.y
  dbx, dby = b2.x - b1.x, b2.y - b1.y
  denominator = dax * dby - day * dbx
  return nil if math.abs(denominator) < geometryEpsilon
  t = ((b1.x - a1.x) * dby - (b1.y - a1.y) * dbx) / denominator
  {x: a1.x + dax * t, y: a1.y + day * t}

expandQuadScreen = (quad, padX, padY) ->
  return quad unless quad and #quad >= 4
  pads = {padY, padX, padY, padX}
  edges = {}
  for i = 1, 4
    nextI = i == 4 and 1 or i + 1
    edges[i] = offsetEdge quad[i], quad[nextI], pads[i]
  expanded = {}
  for i = 1, 4
    prevI = i == 1 and 4 or i - 1
    point = lineIntersection edges[prevI][1], edges[prevI][2], edges[i][1], edges[i][2]
    unless point
      prevNormal = outwardEdgeNormal quad[prevI], quad[i]
      nextI = i == 4 and 1 or i + 1
      nextNormal = outwardEdgeNormal quad[i], quad[nextI]
      point = {
        x: quad[i].x + prevNormal.x * pads[prevI] + nextNormal.x * pads[i]
        y: quad[i].y + prevNormal.y * pads[prevI] + nextNormal.y * pads[i]
      }
    expanded[i] = point
  expanded

extractVectorPoints = (data) ->
  clipTable = data\getTags "clip_vect"
  return {} if #clipTable == 0
  points = {}
  for contour in *clipTable[1].contours
    for command in *contour.commands
      gotPoints = false
      if command.getPoints
        ok, commandPoints = pcall -> command\getPoints true
        if ok and commandPoints
          for point in *commandPoints
            x, y = finiteNumber(point.x), finiteNumber(point.y)
            if x and y
              points[#points + 1] = {:x, :y}
              gotPoints = true
      unless gotPoints
        x, y = command\get!
        x, y = finiteNumber(x), finiteNumber(y)
        if x and y
          points[#points + 1] = {:x, :y}
  points

boundsFromPoints = (points) ->
  return nil unless type(points) == "table" and #points > 0
  for point in *points
    return nil unless point and finiteNumber(point.x) != nil and finiteNumber(point.y) != nil
  left, top, right, bottom = points[1].x, points[1].y, points[1].x, points[1].y
  for point in *points
    left = math.min(left, point.x)
    top = math.min(top, point.y)
    right = math.max(right, point.x)
    bottom = math.max(bottom, point.y)
  {left, top, right, bottom}

tryParseLine = (line) ->
  ok, data = pcall -> ASS\parse line
  return data if ok
  nil, data

projectLocalPoints = nil

warnPerspective = (line, warnings) ->
  return unless warnings
  for warning in *warnings
    name, detail = warning[1], warning[2]
    switch name
      when "zero_size"
        logger\warn "Gradient Row: text has zero size; perspective clips may be inaccurate."
      when "text_and_drawings"
        logger\warn "Gradient Row: line mixes text and drawings; perspective clips may be inaccurate."
      when "move"
        logger\warn "Gradient Row: line uses \\move; perspective clips use the prepared position only."
      when "multiple_tags"
        logger\warn "Gradient Row: tag \\#{detail} appears multiple times; perspective clips may be inaccurate."
      when "transform"
        logger\warn "Gradient Row: tag \\#{detail} is used inside \\t; perspective clips may be inaccurate."

preparePerspectiveLine = (line) ->
  data = tryParseLine line
  return nil unless data
  ok, tags, width, height, warnings = pcall -> ArchPerspective.prepareForPerspective ASS, data
  return nil unless ok and tags and width and height
  warnPerspective line, warnings
  data, tags, width, height

screenPaddingForLine = (line, tags) ->
  blur = numberTag line.text, "blur", 0
  blurPad = math.abs(finiteNumber(blur, 0)) * 2
  padX = math.max(math.abs(tagValue(tags.outline_x)), math.abs(tagValue(tags.shadow_x)), 0) + blurPad + perspectivePadding
  padY = math.max(math.abs(tagValue(tags.outline_y)), math.abs(tagValue(tags.shadow_y)), 0) + blurPad + perspectivePadding
  padX, padY

baseLocalRectForPerspective = (data, width, height) ->
  bounds = drawingLocalBounds data
  width, height = finiteNumber(width, minimumPerspectiveExtent), finiteNumber(height, minimumPerspectiveExtent)
  bounds or {0, 0, math.max(width, minimumPerspectiveExtent), math.max(height, minimumPerspectiveExtent)}

projectedQuadForLine = (line, data, tags, width, height, layoutScale) ->
  bounds = baseLocalRectForPerspective data, width, height
  quad = projectLocalPoints tags, width, height, rectPoints(bounds), layoutScale
  return nil unless quad and #quad == 4
  padX, padY = screenPaddingForLine line, tags
  expandQuadScreen quad, padX, padY

subinspectorBounds = (sub, line) ->
  return nil unless haveSubInspector and SubInspector
  assi = SubInspector sub
  return nil unless assi
  probe = LineOps.copy line
  probe.assi_exhaustive = true
  bounds = assi\getBounds {probe}
  return nil unless bounds and bounds[1]
  b = bounds[1]
  boundsToRect b

lineBounds = (sub, line) ->
  if bounds = rectClipFromText line.text
    return bounds

  data, parseErr = tryParseLine line
  if data
    if points = extractVectorPoints data
      if #points > 0
        return boundsFromPoints points

    data\removeTags {"clip_rect", "iclip_rect", "clip_vect", "iclip_vect"}
    bounds = data\getLineBounds false, true
    if rect = boundsToRect bounds
      return rect

  if bounds = subinspectorBounds sub, line
    return bounds

  if bounds = measuredTextBounds line
    return bounds

  if bounds = roughTextBounds line
    return bounds

  if parseErr
    logger\warn "ASSFoundation could not parse line for bounds: #{parseErr}"
  windowError "Could not determine a clip or rendered text area for the selected line."

parseColor = (value) ->
  r, g, b = Color.toRGB value
  {:r, :g, :b}

interpolateColor = (a, b, factor) ->
  factor = LineOps.clamp factor, 0, 1
  {
    r: LineOps.round(a.r + (b.r - a.r) * factor)
    g: LineOps.round(a.g + (b.g - a.g) * factor)
    b: LineOps.round(a.b + (b.b - a.b) * factor)
  }

paletteColor = (colors, factor) ->
  factor = LineOps.clamp factor, 0, 1
  return colors[1] if #colors == 1
  scaled = factor * (#colors - 1)
  index = math.floor(scaled) + 1
  return colors[#colors] if index >= #colors
  interpolateColor colors[index], colors[index + 1], scaled - math.floor(scaled)

interpolationFactor = (index, total, accel) ->
  return 1 if total < 2
  ((index - 1) / (total - 1)) ^ accel

boundaryDelta = (a, b) ->
  return nil unless a and b and a[1] and a[2] and b[1] and b[2]
  math.max pointDistance(a[1], b[1]), pointDistance(a[2], b[2])

shiftBoundaryT = (boundaryAt, t, direction, maxStep, amount = clipBleed) ->
  return t if amount <= 0 or maxStep <= 0
  base = boundaryAt t
  return t unless base and base[1] and base[2]
  low, high = 0, maxStep
  for _ = 1, boundarySearchIterations
    mid = (low + high) / 2
    candidateT = LineOps.clamp t + direction * mid, 0, 1
    candidate = boundaryAt candidateT
    delta = boundaryDelta base, candidate
    if delta and delta <= amount
      low = mid
    else
      high = mid
  LineOps.clamp t + direction * low, 0, 1

gradientSegmentCount = (span, strip) ->
  span, strip = finiteNumber(span), finiteNumber(strip)
  windowError "Gradient Row received an invalid span or strip size." unless span and strip and span > geometryEpsilon and strip > 0
  sections = math.max 1, math.ceil(span / strip)
  sections

createRectClips = (bounds, mode, strip) ->
  bounds = validBounds bounds
  windowError "The selected line has empty gradient bounds." unless bounds
  left, top, right, bottom = unpack bounds
  span = mode == "Vertical" and bottom - top or right - left
  sections = gradientSegmentCount span, strip
  clips = {}
  for i = 1, sections
    LineOps.checkCancelled!
    startOff = (i - 1) * strip
    endOff = i == sections and span or i * strip
    if mode == "Vertical"
      y1 = top + startOff
      y2 = top + endOff
      y1 -= clipBleed if i > 1
      y2 += clipBleed if i < sections
      clips[#clips + 1] = rectClipTag {left, y1, right, y2}
    else
      x1 = left + startOff
      x2 = left + endOff
      x1 -= clipBleed if i > 1
      x2 += clipBleed if i < sections
      clips[#clips + 1] = rectClipTag {x1, top, x2, bottom}
  clips

createQuadClips = (points, mode, strip) ->
  return nil unless points and #points >= 4
  quad = {points[1], points[2], points[3], points[4]}
  span = if mode == "Vertical"
    (pointDistance(quad[1], quad[4]) + pointDistance(quad[2], quad[3])) / 2
  else
    (pointDistance(quad[1], quad[2]) + pointDistance(quad[4], quad[3])) / 2
  return nil if span <= geometryEpsilon
  sections = gradientSegmentCount span, math.max(minStripSize, strip)
  stepT = 1 / sections
  boundaryAt = (t) ->
    if mode == "Vertical"
      {lerpPoint(quad[1], quad[4], t), lerpPoint(quad[2], quad[3], t)}
    else
      {lerpPoint(quad[1], quad[2], t), lerpPoint(quad[4], quad[3], t)}
  clips = {}
  for i = 1, sections
    LineOps.checkCancelled!
    t1 = (i - 1) / sections
    t2 = i / sections
    t2 = shiftBoundaryT boundaryAt, t2, 1, stepT / 2, clipCoverBleed if i < sections
    if mode == "Vertical"
      top = boundaryAt t1
      bottom = boundaryAt t2
      clips[#clips + 1] = vectorClipTag {top[1], top[2], bottom[2], bottom[1]}
    else
      left = boundaryAt t1
      right = boundaryAt t2
      clips[#clips + 1] = vectorClipTag {left[1], right[1], right[2], left[2]}
  clips

projectPoint = (point, axis) ->
  point.x * axis.x + point.y * axis.y

pointOnStrip = (axis, perp, along, across) ->
  {
    x: axis.x * along + perp.x * across
    y: axis.y * along + perp.y * across
  }

matrixPoint = (point) ->
  return nil unless point
  x, y = tonumber(point.x), tonumber(point.y)
  if x == nil and type(point) == "table"
    x = tonumber point[1]
  if y == nil and type(point) == "table"
    y = tonumber point[2]
  if (x == nil or y == nil) and type(point) == "table"
    unless x
      okX, valueX = pcall -> point\x!
      x = tonumber valueX if okX
    unless y
      okY, valueY = pcall -> point\y!
      y = tonumber valueY if okY
  return nil unless x and y
  {:x, :y}

projectLocalPoints = (tags, width, height, points, layoutScale) ->
  source = [{point.x, point.y} for point in *points]
  ok, projected = pcall -> ArchPerspective.transformPoints tags, width, height, source, layoutScale
  return nil unless ok and projected
  out = {}
  for i = 1, #points
    point = matrixPoint projected[i]
    return nil unless point
    out[#out + 1] = point
  out

quadUvPoint = (quad, u, v) ->
  ok, point = pcall -> quad\uv_to_xy {u, v}
  return nil unless ok and point
  matrixPoint point

createQuadMeshClips = (points, mode, strip) ->
  return nil unless points and #points >= 4 and ArchPerspective and ArchPerspective.Quad
  ok, quad = pcall -> ArchPerspective.Quad {
    {points[1].x, points[1].y}
    {points[2].x, points[2].y}
    {points[3].x, points[3].y}
    {points[4].x, points[4].y}
  }
  return nil unless ok and quad
  span = if mode == "Vertical"
    (pointDistance(points[1], points[4]) + pointDistance(points[2], points[3])) / 2
  else
    (pointDistance(points[1], points[2]) + pointDistance(points[4], points[3])) / 2
  return nil if span <= geometryEpsilon
  sections = gradientSegmentCount span, math.max(minStripSize, strip)
  stepT = 1 / sections
  boundaryAt = (t) ->
    if mode == "Vertical"
      {quadUvPoint(quad, 0, t), quadUvPoint(quad, 1, t)}
    else
      {quadUvPoint(quad, t, 0), quadUvPoint(quad, t, 1)}
  clips = {}
  for i = 1, sections
    LineOps.checkCancelled!
    t1 = (i - 1) / sections
    t2 = i / sections
    t2 = shiftBoundaryT boundaryAt, t2, 1, stepT / 2, clipCoverBleed if i < sections
    if mode == "Vertical"
      top = boundaryAt t1
      bottom = boundaryAt t2
      if top[1] and top[2] and bottom[1] and bottom[2]
        clips[#clips + 1] = vectorClipTag {top[1], top[2], bottom[2], bottom[1]}
    else
      left = boundaryAt t1
      right = boundaryAt t2
      if left[1] and left[2] and right[1] and right[2]
        clips[#clips + 1] = vectorClipTag {left[1], right[1], right[2], left[2]}
  clips

validPoint = (point) ->
  point and finiteNumber(point.x) != nil and finiteNumber(point.y) != nil

createRotatedClips = (points, strip, angle) ->
  angle = finiteNumber angle, 0
  windowError "Could not create rotated clips from the selected line." unless points and #points >= 3
  for point in *points
    windowError "Could not create rotated clips from the selected line." unless validPoint point

  radians = math.rad angle
  axis = {x: math.cos(radians), y: math.sin(radians)}
  perp = {x: -math.sin(radians), y: math.cos(radians)}

  minProj, maxProj = projectPoint(points[1], axis), projectPoint(points[1], axis)
  minAcross, maxAcross = projectPoint(points[1], perp), projectPoint(points[1], perp)
  for point in *points
    projection = projectPoint point, axis
    minProj = math.min(minProj, projection)
    maxProj = math.max(maxProj, projection)
    across = projectPoint point, perp
    minAcross = math.min(minAcross, across)
    maxAcross = math.max(maxAcross, across)

  span = maxProj - minProj
  windowError "The selected line has an empty gradient span." unless span > geometryEpsilon
  sections = gradientSegmentCount span, strip
  acrossPad = math.min(rotatedMaxPadding, math.max(rotatedMinPadding, strip * rotatedPaddingRatio))
  minAcross -= acrossPad
  maxAcross += acrossPad
  clips = {}
  for i = 1, sections
    LineOps.checkCancelled!
    startProj = minProj + (i - 1) * strip
    endProj = i == sections and maxProj or minProj + i * strip
    endProj += clipCoverBleed if i < sections
    clips[#clips + 1] = vectorClipTag {
      pointOnStrip axis, perp, startProj, minAcross
      pointOnStrip axis, perp, endProj, minAcross
      pointOnStrip axis, perp, endProj, maxAcross
      pointOnStrip axis, perp, startProj, maxAcross
    }
  clips

intersectPerpendicular = (points) ->
  x1, y1 = points[1].x, points[1].y
  x2, y2 = points[2].x, points[2].y
  x3, y3 = points[3].x, points[3].y
  denominator = (x2 - x1) ^ 2 + (y2 - y1) ^ 2
  return nil if math.abs(denominator) <= geometryEpsilon
  k = ((x3 - x1) * (x2 - x1) + (y3 - y1) * (y2 - y1)) / denominator
  {
    x: x1 + k * (x2 - x1)
    y: y1 + k * (y2 - y1)
  }

angleFromVectorClip = (line) ->
  data = tryParseLine line
  return nil unless data
  points = extractVectorPoints data
  return nil if #points < 3
  foot = intersectPerpendicular points
  return nil unless foot
  math.deg math.atan2(points[3].y - foot.y, points[3].x - foot.x)

gradientAxisAngle = (state, lineRotation) ->
  base = switch state.mode
    when "Vertical" then 90
    when "Rotated" then state.angle
    else 0
  base - lineRotation

lineNeedsProjectedClips = (line) ->
  text = tostring(line.text or "")
  return true if LineOps.hasDrawing text
  return true if math.abs(rotationFromText line) >= geometryEpsilon
  for pattern in *{"\\frx", "\\fry", "\\frz", "\\fr", "\\fax", "\\fay", "\\fscx", "\\fscy", "\\xbord", "\\ybord", "\\xshad", "\\yshad", "\\org"}
    return true if text\find pattern, 1, true
  false

projectedClipTagsForLine = (line, state) ->
  return nil unless lineNeedsProjectedClips line
  data, tags, width, height = preparePerspectiveLine line
  return nil unless data and tags and width and height
  layoutScale = layoutScaleForLine line
  quad = projectedQuadForLine line, data, tags, width, height, layoutScale
  return nil unless quad and #quad == 4
  clips = if state.mode == "Rotated"
    createRotatedClips quad, math.max(1, state.strip), tonumber(state.angle) or 0
  else
    createQuadMeshClips(quad, state.mode, math.max(1, state.strip)) or createQuadClips quad, state.mode, math.max(1, state.strip)
  return clips if clips and #clips > 0
  nil

explicitClipInfo = (line) ->
  if bounds = rectClipFromText line.text
    points = rectPoints bounds
    return {:bounds, :points, is_vector_clip: false}

  data = tryParseLine line
  if data
    points = extractVectorPoints data
    if points and #points > 0
      if #points == 5
        first, last = points[1], points[#points]
        if math.abs(first.x - last.x) <= geometryEpsilon and math.abs(first.y - last.y) <= geometryEpsilon
          table.remove points, #points
      windowError "Gradient Row supports rectangular or four-corner vector clips. Simplify this clip to four corners before applying a spatial gradient." unless #points == 4
      bounds = boundsFromPoints points
      return {:bounds, :points, is_vector_clip: true}
  nil

gradientPointsForLine = (line, bounds) ->
  data = tryParseLine line
  if data
    points = extractVectorPoints data
    return points if #points >= 4

  rotation = rotationFromText line
  if math.abs(rotation) >= geometryEpsilon
    textBounds = measuredTextBounds(line) or roughTextBounds(line)
    if textBounds
      origin = originFromText line
      if origin
        return [rotatePoint point, origin, -rotation for point in *rectPoints textBounds]

  rectPoints bounds

clipTagsForLine = (sub, line, state) ->
  if info = explicitClipInfo line
    strip = math.max(1, state.strip)
    lineRotation = rotationFromText line
    if info.is_vector_clip and #info.points >= 4 and state.mode != "Rotated"
      if clips = createQuadMeshClips(info.points, state.mode, strip) or createQuadClips info.points, state.mode, strip
        return clips
    if state.mode == "Rotated" or math.abs(lineRotation) >= geometryEpsilon
      angle = if state.mode == "Rotated" then gradientAxisAngle(state, lineRotation) else angleFromVectorClip(line) or gradientAxisAngle(state, lineRotation)
      return createRotatedClips info.points, strip, angle
    return createRectClips info.bounds, state.mode, strip

  if clips = projectedClipTagsForLine line, state
    return clips

  bounds = lineBounds sub, line
  strip = math.max(1, state.strip)
  lineRotation = rotationFromText line
  if state.mode == "Rotated" or math.abs(lineRotation) >= geometryEpsilon
    points = gradientPointsForLine line, bounds
    angle = if state.mode == "Rotated" then gradientAxisAngle(state, lineRotation) else angleFromVectorClip(line) or gradientAxisAngle(state, lineRotation)
    return createRotatedClips points, strip, angle
  createRectClips bounds, state.mode, strip

applyGradientLine = (source, clipTag, slots, color, collection) ->
  line = Line source, collection
  line.comment = false
  positionTag = implicitPositionTag line
  data, parseErr = tryParseLine line
  if data
    data\removeTags {"clip_rect", "iclip_rect", "clip_vect", "iclip_vect"}
    ok, colorErr = pcall ->
      tags = {}
      for slot in *colorSlots
        if slots[slot]
          tagName = colorTagName slot
          error "Unknown color slot: #{slot}" unless tagName
          tags[#tags + 1] = ASS\createTag tagName, color.b, color.g, color.r
      data\replaceTags tags if #tags > 0
      data\commit!
    unless ok
      logger\warn "ASSFoundation could not replace color tags; using text fallback: #{colorErr}"
      line.text = LineOps.stripClips line.text
      line.text = applyColorTagsText line.text, slots, color
  else
    logger\warn "ASSFoundation could not parse line for color replacement; using text fallback: #{parseErr}"
    line.text = LineOps.stripClips line.text
    line.text = applyColorTagsText line.text, slots, color
  line.text = LineOps.prependTag line.text, clipTag .. (positionTag or "")
  line

firstTagBlock = (text) ->
  tostring(text or "")\match("^({[^}]*})") or ""

removeSelectedColorTags = (text, activeSlots) ->
  for slot in *activeSlots
    text = removeColorTagText text, slot
  text

removeSelectedColorTagsClean = (text, activeSlots) ->
  (removeSelectedColorTags text, activeSlots)\gsub "{}", ""

colorTagsForSlots = (activeSlots, color) ->
  tags = {}
  for slot in *activeSlots
    tagText = if slot == "c" then "\\c#{assColor color}" else "\\#{slot}#{assColor color}"
    tags[#tags + 1] = tagText
  table.concat tags

colorTagForSlot = (slot, color) ->
  if slot == "c" then "\\c#{assColor color}" else "\\#{slot}#{assColor color}"

tokenizeVisible = (text) ->
  tokens = {}
  text = tostring(text or "")
  for section in *LineOps.scanSections text
    if section.type == "override" or section.type == "comment"
      tokens[#tokens + 1] = {type: "tag", content: text\sub(section.start, section.finish)}
    else
      for content in *LineOps.graphemes section.text
        kind = if content == "\\N" or content == "\\n" or content == "\\h" then "break" else "char"
        tokens[#tokens + 1] = {type: kind, :content}
  tokens

countCharTokens = (tokens) ->
  total = 0
  for token in *tokens
    total += 1 if token.type == "char"
  total

charEntryForLine = (line, offset = 0) ->
  return false if LineOps.hasDrawing line.text
  head = firstTagBlock line.text
  body = tostring(line.text or "")\sub #head + 1
  tokens = tokenizeVisible body
  charCount = countCharTokens tokens
  return nil if charCount == 0
  {:line, :head, :tokens, char_count: charCount, :offset}

applyPaletteToCharEntry = (entry, activeSlots, palette, accel, total) ->
  total or= entry.char_count
  result, charIndex = {}, 0
  for token in *entry.tokens
    switch token.type
      when "tag"
        result[#result + 1] = removeSelectedColorTagsClean token.content, activeSlots
      when "break"
        result[#result + 1] = token.content
      else
        charIndex += 1
        colorIndex = (entry.offset or 0) + charIndex
        color = paletteColor palette, interpolationFactor colorIndex, total, accel
        result[#result + 1] = "{#{colorTagsForSlots activeSlots, color}}#{token.content}"
  entry.line.text = removeSelectedColorTagsClean(entry.head, activeSlots) .. table.concat result
  true

blockColorTags = (content) ->
  colors = {}
  for call in *LineOps.tagCalls content, {"c", "1c", "2c", "3c", "4c"}
    if call.top_level
      normalized = Color.parseAss call.value
      if normalized
        r, g, b = Color.toRGB normalized
        slot = if call.name == "1c" then "c" else call.name
        colors[slot] = {:r, :g, :b}
  colors

collectBetweenAnchors = (entries) ->
  anchors = {slot, {} for slot in *colorSlots}
  for entry in *entries
    nextChar = 1
    addAnchors = (content) ->
      colors = blockColorTags content
      return unless next colors
      anchorIndex = entry.offset + math.max(1, math.min(nextChar, entry.char_count))
      for slot, color in pairs colors
        anchors[slot][#anchors[slot] + 1] = {index: anchorIndex, :color}
    addAnchors entry.head
    for token in *entry.tokens
      switch token.type
        when "tag"
          addAnchors token.content
        when "char"
          nextChar += 1
  anchors

usableSlotsFromAnchors = (anchors) ->
  usable = {}
  for slot in *colorSlots
    list = anchors[slot] or {}
    compact, byIndex = {}, {}
    for anchor in *list
      byIndex[anchor.index] = anchor
    for _, anchor in pairs byIndex
      compact[#compact + 1] = anchor
    table.sort compact, (a, b) -> a.index < b.index
    anchors[slot] = compact
    usable[#usable + 1] = slot if #compact >= 2
  usable

betweenColorAt = (anchors, index) ->
  return nil unless anchors and #anchors > 0
  return anchors[1].color if index <= anchors[1].index
  for i = 1, #anchors - 1
    startAnchor, endAnchor = anchors[i], anchors[i + 1]
    if index <= endAnchor.index
      span = endAnchor.index - startAnchor.index
      factor = if span <= 0 then 1 else (index - startAnchor.index) / span
      return interpolateColor startAnchor.color, endAnchor.color, factor
  anchors[#anchors].color

betweenColorTags = (usableSlots, anchors, index) ->
  tags = {}
  for slot in *usableSlots
    if color = betweenColorAt anchors[slot], index
      tags[#tags + 1] = colorTagForSlot slot, color
  table.concat tags

applyBetweenToCharEntry = (entry, usableSlots, anchors) ->
  result, charIndex = {}, 0
  for token in *entry.tokens
    switch token.type
      when "tag"
        result[#result + 1] = removeSelectedColorTagsClean token.content, usableSlots
      when "break"
        result[#result + 1] = token.content
      else
        charIndex += 1
        globalIndex = (entry.offset or 0) + charIndex
        result[#result + 1] = "{#{betweenColorTags usableSlots, anchors, globalIndex}}#{token.content}"
  entry.line.text = removeSelectedColorTagsClean(entry.head, usableSlots) .. table.concat result
  true

collectCharEntries = (sub, sel, globalOffsets = false) ->
  entries, total = {}, 0
  for index in *sel
    line = LineOps.copy sub[index]
    if line and (line.class == nil or line.class == "dialogue")
      offset = if globalOffsets then total else 0
      if entry = charEntryForLine line, offset
        entry.index = index
        entries[#entries + 1] = entry
        total += entry.char_count
  entries, total

applyPaletteCharLine = (sub, sel, activeSlots, palette, state) ->
  entries = collectCharEntries sub, sel, false
  changed = false
  for entry in *entries
    aegisub.cancel! if aegisub.progress.is_cancelled!
    if applyPaletteToCharEntry entry, activeSlots, palette, state.accel, entry.char_count
      sub[entry.index] = entry.line
      changed = true
  logger\warn "Gradient Row: no visible text characters found for Char Line." unless changed
  sel

applyPaletteCharSelection = (sub, sel, activeSlots, palette, state) ->
  entries, total = collectCharEntries sub, sel, true
  changed = false
  for entry in *entries
    aegisub.cancel! if aegisub.progress.is_cancelled!
    if applyPaletteToCharEntry entry, activeSlots, palette, state.accel, total
      sub[entry.index] = entry.line
      changed = true
  logger\warn "Gradient Row: no visible text characters found for Char Selection." unless changed
  sel

applyBetweenCharLine = (sub, sel) ->
  changed = false
  for index in *sel
    aegisub.cancel! if aegisub.progress.is_cancelled!
    line = LineOps.copy sub[index]
    if line and (line.class == nil or line.class == "dialogue")
      if entry = charEntryForLine line, 0
        anchors = collectBetweenAnchors {entry}
        usableSlots = usableSlotsFromAnchors anchors
        if #usableSlots > 0 and applyBetweenToCharEntry entry, usableSlots, anchors
          sub[index] = entry.line
          changed = true
  logger\warn "Gradient Row: Use colors between letters found no channel with at least two color states." unless changed
  sel

applyBetweenCharSelection = (sub, sel) ->
  entries = collectCharEntries sub, sel, true
  anchors = collectBetweenAnchors entries
  usableSlots = usableSlotsFromAnchors anchors
  unless #usableSlots > 0
    logger\warn "Gradient Row: Use colors between letters found no channel with at least two color states."
    return sel
  for entry in *entries
    aegisub.cancel! if aegisub.progress.is_cancelled!
    if applyBetweenToCharEntry entry, usableSlots, anchors
      sub[entry.index] = entry.line
  sel

applyCharGradient = (sub, sel, activeSlots, palette, state) ->
  if state.use_between
    return if state.mode == "Char Selection" then applyBetweenCharSelection sub, sel else applyBetweenCharLine sub, sel
  if state.mode == "Char Selection"
    applyPaletteCharSelection sub, sel, activeSlots, palette, state
  else
    applyPaletteCharLine sub, sel, activeSlots, palette, state

collectSources = (sub, sel) ->
  collection = LineCollection sub, sel, ((line) -> line.class == "dialogue"), false
  byIndex = {line.number, line for line in *collection.lines}
  sources = {}
  for selectedIndex in *sel
    source = byIndex[selectedIndex]
    windowError "Gradient Row could not resolve selected dialogue line #{selectedIndex}." unless source
    sources[#sources + 1] = {index: selectedIndex, line: source}
  sources, collection

collectActiveSlots = (slots) ->
  active = [slot for slot in *colorSlots when slots[slot]]
  windowError "Select at least one color slot." if #active == 0
  active

buildGui = (state, x = nil, page = 1) ->
  state = normalizeState state
  pages = math.max 1, math.ceil(#state.colors / palettePageSize)
  page = LineOps.clamp page, 1, pages
  buttons = {"Execute", "Add+", "Rem-"}
  if pages > 1
    buttons[#buttons + 1] = "Previous"
    buttons[#buttons + 1] = "Next"
  buttons[#buttons + 1] = "Reset"
  buttons[#buttons + 1] = "Cancel"
  x or= if pages > 1 then 13 else 8
  first = (page - 1) * palettePageSize + 1
  last = math.min(first + palettePageSize - 1, #state.colors)
  gui = {
    {class: "label", label: "Gradient Type:", :x, y: 0, width: 3}
    {class: "dropdown", name: "mode", items: gradientModes, value: state.mode, :x, y: 1, width: 3}
    {class: "checkbox", name: "use_between", label: "Inline color stops", hint: "Use inline colors in Char modes. Spatial modes use the palette.", value: state.use_between, :x, y: 2, width: 3}
    {class: "label", label: "Pixels per strip:", :x, y: 4, width: 3}
    {class: "intedit", name: "strip", min: 1, value: state.strip, :x, y: 5, width: 3}
    {class: "label", label: "Acceleration:", :x, y: 6, width: 3}
    {class: "floatedit", name: "accel", min: 0, hint: "Positive values only; 1 is linear.", value: state.accel, :x, y: 7, width: 3}
    {class: "label", label: "Angle:", :x, y: 8, width: 3}
    {class: "floatedit", name: "angle", value: state.angle, :x, y: 9, width: 3}
    {class: "label", label: "Color slots:", :x, y: 11, width: 3}
  }
  for i, slot in ipairs colorSlots
    gui[#gui + 1] = {class: "checkbox", name: slot, label: "\\#{slot}", value: state.slots[slot], :x, y: 11 + i, width: 3}
  colorsY = 13 + #colorSlots
  paletteLabel = if pages > 1 then "Colors: #{first}–#{last} / #{#state.colors}" else "Colors:"
  gui[#gui + 1] = {class: "label", label: paletteLabel, :x, y: colorsY, width: 3}
  for i = first, last
    gui[#gui + 1] = {class: "color", name: "color#{i}", hint: "Color #{i} / #{#state.colors}", value: state.colors[i], :x, y: colorsY + (i - first) * 2 + 1, width: 3, height: 2}
  gui, buttons

readState = (res, colorCount, previous = {}) ->
  state = {}
  state.mode = res.mode
  state.use_between = res.use_between and true or false
  state.strip = res.strip
  state.accel = res.accel
  state.angle = res.angle
  state.slots = readSlots res
  state.colors = {}
  for i = 1, colorCount
    state.colors[i] = res["color#{i}"] or previous[i] or "#FFFFFF"
  normalizeState state

createDialog = ->
  state = loadState!
  page = 1
  while true
    gui, buttons = buildGui state, nil, page
    button, res = aegisub.dialog.display gui, buttons, {ok: "Execute", close: "Cancel"}
    return nil if button == "Cancel" or not button
    if button == "Reset"
      state, page = defaultState!, 1
      continue
    state = readState res, #state.colors, state.colors
    switch button
      when "Add+"
        state.colors[#state.colors + 1] = state.colors[#state.colors]
        page = math.ceil(#state.colors / palettePageSize)
      when "Rem-"
        table.remove state.colors if #state.colors > 2
        page = math.min page, math.ceil(#state.colors / palettePageSize)
      when "Previous"
        page = math.max 1, page - 1
      when "Next"
        page = math.min math.ceil(#state.colors / palettePageSize), page + 1
      when "Execute"
        saved, saveError = saveState state
        logger\warn "Preferences could not be saved: #{tostring saveError}" unless saved
        return state

isCharMode = (mode) ->
  mode == "Char Line" or mode == "Char Selection"

validate = (sub, sel) ->
  records = LineOps.selectedLines sub, sel, ((line) -> line and line.class == "dialogue" and not line.comment), true
  return false unless records
  #records >= 1

main = (sub, sel) ->
  windowError "Select only uncommented dialogue lines." unless validate sub, sel
  state = createDialog!
  return unless state
  state = normalizeState state
  unless isCharMode state.mode
    for index in *sel
      text = tostring(sub[index].text or "")
      visibleStarted = false
      for section in *LineOps.scanSections text
        if section.type == "override"
          for call in *LineOps.tagCalls "{#{section.text}}", {"clip", "iclip"}
            windowError "Animated clips inside \\t are not supported because generating strips would discard their animation." unless call.top_level
            windowError "Spatial gradients require the source clip before visible content; split lines that change clip between runs." if visibleStarted
        elseif section.type == "text" or section.type == "drawing"
          visiblePart = tostring(section.text or "")\gsub("\\[Nnh]", "")
          visibleStarted = true if visiblePart\match "%S"
      windowError "Inverse clips are not supported because replacing an \\iclip would invert the gradient area." if #LineOps.tagCalls(text, "iclip") > 0
      clipCount = #LineOps.tagCalls(text, "clip")
      windowError "Use at most one clip per line before applying Gradient Row." if clipCount > 1
  LineOps.transaction sub, script_name, ->
    if isCharMode state.mode
      activeSlots = if state.use_between then {} else collectActiveSlots state.slots
      palette = [parseColor color for color in *state.colors]
      return applyCharGradient sub, sel, activeSlots, palette, state
    palette = [parseColor color for color in *state.colors]
    sources, collection = collectSources sub, sel
    plans = {}
    for lineNo, sourceInfo in ipairs sources
      aegisub.cancel! if aegisub.progress.is_cancelled!
      clips = clipTagsForLine sub, sourceInfo.line, state
      windowError "No gradient clips were generated." unless clips and #clips > 0
      plans[#plans + 1] = {source_info: sourceInfo, clips: clips}
      aegisub.progress.set math.floor(40 * lineNo / math.max(#sources, 1))

    generatedSelection = {}
    insertedBefore = 0

    for lineNo, plan in ipairs plans
      aegisub.cancel! if aegisub.progress.is_cancelled!
      sourceInfo = plan.source_info
      sourceIndex = sourceInfo.index + insertedBefore
      source = sourceInfo.line
      clips = plan.clips

      commented = Line source, collection
      commented.comment = true
      sub[sourceIndex] = commented
      insertAt = sourceIndex + 1

      for i, clipTag in ipairs clips
        aegisub.cancel! if aegisub.progress.is_cancelled!
        factor = interpolationFactor i, #clips, state.accel
        color = paletteColor palette, factor
        line = applyGradientLine source, clipTag, state.slots, color, collection
        sub.insert insertAt, line
        generatedSelection[#generatedSelection + 1] = insertAt
        insertAt += 1

      insertedBefore += #clips
      aegisub.progress.set 40 + math.floor(60 * lineNo / math.max(#plans, 1))

    generatedSelection
depctrl\registerMacro main, validate

KiteUI.publishActions()
