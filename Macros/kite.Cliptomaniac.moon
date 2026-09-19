export script_name = "Cliptomaniac"
export script_description = "Clip toolbox for measuring, transforming, reshaping, fitting, and projecting ASS clips."
export script_author = "Kiterow"
export script_namespace = "kite.Cliptomaniac"
export script_version = "0.4.4"

local ZF, ASS, ArchPerspective, KiteCore, Functional, Util, AMLine, LineOps, depctrl, logger
Core = {}
PerspectiveTools = {}

DependencyControl = require "l0.DependencyControl"
depctrl = DependencyControl{
  feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    {
      {"ZF.main", version: "2.3.0", url: "https://github.com/TypesettingTools/zeref-Aegisub-Scripts",
        feed: "https://raw.githubusercontent.com/TypesettingTools/zeref-Aegisub-Scripts/main/DependencyControl.json"}
      {"l0.ASSFoundation", version: "0.5.0", url: "https://github.com/TypesettingTools/ASSFoundation",
        feed: "https://raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json"}
      {"arch.Perspective", version: "1.2.1", url: "https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts",
        feed: "https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json"}
      {"kite.Core", version: "1.1.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
        feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
      {"kite.UI", version: "1.5.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
        feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
      {"l0.Functional", version: "0.6.0", url: "https://github.com/TypesettingTools/Functional",
        feed: "https://raw.githubusercontent.com/TypesettingTools/Functional/master/DependencyControl.json"}
      {"arch.Util", version: "0.1.0", url: "https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts",
        feed: "https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json"}
      {"a-mo.Line", version: "1.5.3", url: "https://github.com/TypesettingTools/Aegisub-Motion",
        feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"}
      {"kite.LineOps", version: "1.7.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
        feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
      {"kite.AssContext", version: "1.1.1"}
    }
}
ZF, ASS, ArchPerspective, KiteCore, Core.UI, Functional, Util, AMLine, LineOps = depctrl\requireModules!
AssContext = require "kite.AssContext"
logger = depctrl\getLogger!

ConfigHandler = (interface, fileName, _has_sections, version) ->
  Core.UI.dialogHandler interface, script_namespace, version, {
    {path: "?user/" .. fileName, format: "json_sections"}
  }

Core.safeRequire = (name) ->
  ok, mod = pcall require, name
  if ok then mod else nil

unicode = Core.safeRequire "aegisub.unicode"
FunctionalMath = Functional and Functional.math or nil

configFile = "kite-cliptomaniac.json"
hotkeyMenuRoot = ": Kite Hotkeys :"
hotkeyMenuScript = "Cliptomaniac"
defaultLanguage = "en"
current_language = defaultLanguage
languageConfigHandler = nil
averageGlyphWidthEm = 0.4042
bezierArclengthSegments = 80
sameLineCurveCompensation = 0.62
geometryEpsilon = 0.0005
numericEpsilon = 0.0000005
parametricEpsilon = 0.000001
minFbfFrameBudget = 0
defaultFbfFrameBudget = 400
trackingFallbackFps = 24000 / 1001

OPERATIONS = {
  "Autofit clip to text"
  "Fit text to clip guide"
  "Create clip around text"
  "Text to clip"
  "Expand clip margin"
  "Copy clip/iclip"
  "Shape to clip"
  "Clip to shape"
  "Toggle clip/iclip"
  "Rect clip to vector"
  "Vector clip to rect"
  "Clip boolean with text/shape"
  "Extract clip as mask line"
  "Position at clip midpoint"
  "Align to clip"
  "Clip to reposition"
  "Clip to move"
  "Clip to FRZ"
  "Clip to FAX"
  "Clip to FAY"
  "Measure clip"
  "Measure & transform clip"
  "Adjust by clip scale"
  "Rescale by rectangle clip"
  "Clip to perspective"
  "Perspective to clip"
  "Complete quadrilateral"
  "Create strip clips"
  "Animated clip to FBF"
  "Export clip track to AE"
  "Calibrate clip X"
  "Calibrate clip Y"
  "Rectangle from diagonal"
  "Circle from 2 points"
  "New clip shape"
  "Add clip points"
  "Remove clip points"
  "Bezier clip to curved text"
  "Clip diagnostics"
}

operationLabels = {
  en: {
    ["Autofit clip to text"]: "autofit clip to text"
    ["Fit text to clip guide"]: "fit text to clip guide"
    ["Create clip around text"]: "create clip around text"
    ["Text to clip"]: "text to clip"
    ["Expand clip margin"]: "expand/shrink clip margin"
    ["Copy clip/iclip"]: "copy clip/iclip"
    ["Shape to clip"]: "shape to clip"
    ["Clip to shape"]: "clip to shape"
    ["Toggle clip/iclip"]: "toggle clip/iclip"
    ["Rect clip to vector"]: "rect clip to vector"
    ["Vector clip to rect"]: "vector clip to rect"
    ["Clip boolean with text/shape"]: "clip boolean with text/shape"
    ["Extract clip as mask line"]: "extract clip as mask line"
    ["Position at clip midpoint"]: "pos to clip center"
    ["Align to clip"]: "align pos to clip path"
    ["Clip to reposition"]: "reposition selection from clip"
    ["Clip to move"]: "clip to move"
    ["Clip to FRZ"]: "clip to frz"
    ["Clip to FAX"]: "clip to fax"
    ["Clip to FAY"]: "clip to fay"
    ["Measure clip"]: "measure clip guide"
    ["Measure & transform clip"]: "animate scale from clip guide"
    ["Adjust by clip scale"]: "adjust tags by clip scale"
    ["Rescale by rectangle clip"]: "rescale tags by rectangular clip"
    ["Clip to perspective"]: "clip to perspective"
    ["Perspective to clip"]: "perspective to clip"
    ["Complete quadrilateral"]: "complete quadrilateral"
    ["Create strip clips"]: "create strip clips"
    ["Animated clip to FBF"]: "animated clip to FBF"
    ["Export clip track to AE"]: "export clip track to AE"
    ["Calibrate clip X"]: "calibrate clip X"
    ["Calibrate clip Y"]: "calibrate clip Y"
    ["Rectangle from diagonal"]: "rectangle from diagonal"
    ["Circle from 2 points"]: "circle from diameter"
    ["New clip shape"]: "new clip shape"
    ["Add clip points"]: "add clip points"
    ["Remove clip points"]: "remove clip points"
    ["Bezier clip to curved text"]: "curve text from Bézier clip"
    ["Clip diagnostics"]: "clip diagnostics"
  }
  es: {
    ["Autofit clip to text"]: "ajustar clip al texto"
    ["Fit text to clip guide"]: "ajustar texto a guia de clip"
    ["Create clip around text"]: "crear clip alrededor del texto"
    ["Text to clip"]: "texto a clip"
    ["Expand clip margin"]: "expandir/reducir margen de clip"
    ["Copy clip/iclip"]: "copiar clip/iclip"
    ["Shape to clip"]: "dibujo a clip"
    ["Clip to shape"]: "clip a dibujo"
    ["Toggle clip/iclip"]: "toggle clip/iclip"
    ["Rect clip to vector"]: "clip rectangular a vector"
    ["Vector clip to rect"]: "clip vectorial a rectangular"
    ["Clip boolean with text/shape"]: "booleano de clip con texto/dibujo"
    ["Extract clip as mask line"]: "extraer clip como máscara"
    ["Position at clip midpoint"]: "pos al centro del clip"
    ["Align to clip"]: "alinear pos a la ruta del clip"
    ["Clip to reposition"]: "mover selección desde clip"
    ["Clip to move"]: "clip a move"
    ["Clip to FRZ"]: "clip a frz"
    ["Clip to FAX"]: "clip a fax"
    ["Clip to FAY"]: "clip a fay"
    ["Measure clip"]: "medir guía de clip"
    ["Measure & transform clip"]: "animar escala desde guía de clip"
    ["Adjust by clip scale"]: "escalar tags desde guía de clip"
    ["Rescale by rectangle clip"]: "ajustar tags a clip rectangular"
    ["Clip to perspective"]: "clip a perspectiva"
    ["Perspective to clip"]: "perspectiva a clip"
    ["Complete quadrilateral"]: "completar cuadrilátero"
    ["Create strip clips"]: "crear franjas de clip"
    ["Animated clip to FBF"]: "clip animado a FBF"
    ["Export clip track to AE"]: "exportar tracking de clips a AE"
    ["Calibrate clip X"]: "enderezar guía clip en X"
    ["Calibrate clip Y"]: "enderezar guía clip en Y"
    ["Rectangle from diagonal"]: "crear rectángulo desde diagonal"
    ["Circle from 2 points"]: "crear círculo desde diámetro"
    ["New clip shape"]: "continuar forma de clip"
    ["Add clip points"]: "anadir puntos de clip"
    ["Remove clip points"]: "quitar puntos de clip"
    ["Bezier clip to curved text"]: "curvar texto desde clip Bézier"
    ["Clip diagnostics"]: "diagnóstico de clip"
  }
}

AXES = {"x", "y", "both"}
angleModes = {"none", "first angle", "transform angle"}
autofitModes = {
  "Whole text"
  "Auto by position"
  "Left/top half"
  "Right/bottom half"
  "Left/top third"
  "Center third"
  "Right/bottom third"
  "Custom section"
}
rescaleRectModes = {"Fit (uniform)", "Fill (uniform)", "Stretch (per-axis)"}
stripModes = {"Horizontal", "Vertical"}
clipTypes = {"Auto", "clip", "iclip"}
fbfSources = {"Clip only", "Full line"}
booleanModes = {"Keep overlap", "Cut text from clip"}
pointInsertModes = {"By distance", "By count"}
perspectiveData = {
  maps: {
    {"ABCD (exact copy)", {1, 2, 3, 4}}
    {"BADC (h-mirror)", {2, 1, 4, 3}}
    {"DCBA (v-mirror)", {4, 3, 2, 1}}
    {"CDAB (rot 180)", {3, 4, 1, 2}}
    {"BCDA (rot 90 CW)", {2, 3, 4, 1}}
    {"DABC (rot 90 CCW)", {4, 1, 2, 3}}
    {"ABDC (swap CD)", {1, 2, 4, 3}}
    {"BACD (swap AB)", {2, 1, 3, 4}}
  }
  org_modes: {"1 keep dst org", "2 quad center", "3 minimize fax"}
}

perspectiveMapAliases = {
  ["ABCD (as drawn)"]: "ABCD (exact copy)"
  ["BADC (flip left/right)"]: "BADC (h-mirror)"
  ["DCBA (flip top/bottom)"]: "DCBA (v-mirror)"
  ["CDAB (rotate 180)"]: "CDAB (rot 180)"
  ["BCDA (rotate 90 clockwise)"]: "BCDA (rot 90 CW)"
  ["DABC (rotate 90 counter-clockwise)"]: "DABC (rot 90 CCW)"
  ["ABDC (swap bottom corners)"]: "ABDC (swap CD)"
  ["BACD (swap top corners)"]: "BACD (swap AB)"
  ["AB source + CD target"]: "ABCD (exact copy)"
  ["CD source + AB target"]: "ABCD (exact copy)"
  ["AC source + BD target"]: "ABCD (exact copy)"
  ["BD source + AC target"]: "ABCD (exact copy)"
  ["AB src + CD dst"]: "ABCD (exact copy)"
  ["CD src + AB dst"]: "ABCD (exact copy)"
  ["AC src + BD dst"]: "ABCD (exact copy)"
  ["BD src + AC dst"]: "ABCD (exact copy)"
}

perspectiveOrgAliases = {
  ["1 keep current origin"]: "1 keep dst org"
  ["1 keep target org"]: "1 keep dst org"
  ["Keep target org"]: "1 keep dst org"
  ["Keep dst org"]: "1 keep dst org"
  ["Mantener org destino"]: "1 keep dst org"
  ["2 use clip center"]: "2 quad center"
  ["Quad center"]: "2 quad center"
  ["Centro del quad"]: "2 quad center"
  ["3 reduce slant"]: "3 minimize fax"
  ["Minimize fax"]: "3 minimize fax"
  ["Minimizar fax"]: "3 minimize fax"
}

uiLang = {
  en: {
    run: "Execute"
    help: "Help"
    cancel: "Cancel"
    close: "Cancel"
    apply: "Execute"
    language: "Español"
    action: "Action:"
    runs_now: "Runs now"
    opens_settings: "Opens settings"
    what_it_does: "What it does:"
    controls: "Controls:"
    no_extra_controls: "No extra controls. This action runs with the current selection."
    picker_refresh: "Change the dropdown and press Help to refresh this text."
    picker_run: "Execute starts the selected action."
    axis: "Axis:"
    angle_mode: "Angle mode:"
    show_report: "Show report"
    resize: "Resize:"
    width: "width"
    height: "height"
    font: "font"
    spacing: "spacing"
    outline: "outline"
    shadow: "shadow"
    blur: "blur"
    mode: "Mode:"
    scale: "Scale:"
    center: "Center"
    remove_guide_clip: "Remove guide clip"
    curve_depth: "Curve depth (%):"
    curve_spacing: "Extra \\fsp (px):"
    corner_order: "Corner order:"
    origin: "Origin:"
    section_axis: "Section axis:"
    margin: "Margin:"
    tolerance: "Tolerance:"
    sections: "Sections:"
    index: "Index:"
    bleed: "Bleed:"
    no_shrink: "No shrink"
    style_pad: "Style pad"
    transform_max_bounds: "Include \\t maxima"
    replace_existing_clip: "Replace existing clip"
    clip_type: "Clip type:"
    close_paths: "Close paths"
    comment_source: "Comment source"
    point_mode: "Add by:"
    point_distance: "Distance:"
    point_count: "Points:"
    strip_mode: "Strip mode:"
    strip_size: "Strip size:"
    create_new_lines: "Create new lines"
    bake_source: "Bake source:"
    max_frames: "Max frames:"
    merge_identical: "Merge identical"
    boolean_mode: "Boolean mode:"
    select_one: "Select at least one dialogue line."
    line: "Line"
    track_failed: "Clip tracking export failed:"
    track_no_clip: "has no primary clip"
    track_transform: "uses a clip inside \\t(...); bake it to FBF first"
    track_segment: "must use exactly one m-l or m-b vector segment"
    track_zero: "has a zero-length clip segment"
    track_duration: "has an empty or invalid duration"
    track_sample: "Selected sample"
  }
  es: {
    run: "Execute"
    help: "Ayuda"
    cancel: "Cancel"
    close: "Cancel"
    apply: "Execute"
    language: "English"
    action: "Acción:"
    runs_now: "Directa"
    opens_settings: "Con opciones"
    what_it_does: "Qué hace:"
    controls: "Controles:"
    no_extra_controls: "Sin controles extra. Esta acción se ejecuta con la selección actual."
    picker_refresh: "Cambia el dropdown y pulsa Ayuda para refrescar este texto."
    picker_run: "Execute inicia la acción seleccionada."
    axis: "Eje:"
    angle_mode: "Ángulo:"
    show_report: "Mostrar reporte"
    resize: "Escalar:"
    width: "ancho"
    height: "alto"
    font: "fuente"
    spacing: "espacio"
    outline: "borde"
    shadow: "sombra"
    blur: "blur"
    mode: "Modo:"
    scale: "Escala:"
    center: "Centrar"
    remove_guide_clip: "Quitar clip guía"
    curve_depth: "Profundidad (%):"
    curve_spacing: "\\fsp adicional (px):"
    corner_order: "Esquinas:"
    origin: "Origen:"
    section_axis: "Eje:"
    margin: "Margen:"
    tolerance: "Tolerancia:"
    sections: "Partes:"
    index: "Índice:"
    bleed: "Solape:"
    no_shrink: "No reducir"
    style_pad: "Incluir estilo"
    transform_max_bounds: "Incluir máximos de \\t"
    replace_existing_clip: "Reemplazar clip"
    clip_type: "Tipo:"
    close_paths: "Cerrar rutas"
    comment_source: "Comentar original"
    point_mode: "Anadir por:"
    point_distance: "Distancia:"
    point_count: "Puntos:"
    strip_mode: "Franjas:"
    strip_size: "Tamaño:"
    create_new_lines: "Crear líneas"
    bake_source: "Hornear:"
    max_frames: "Frames max:"
    merge_identical: "Unir iguales"
    boolean_mode: "Booleano:"
    select_one: "Selecciona al menos una línea de diálogo."
    line: "Línea"
    track_failed: "Falló la exportación del tracking de clips:"
    track_no_clip: "no contiene un clip primario"
    track_transform: "usa un clip dentro de \\t(...); hornéalo primero a FBF"
    track_segment: "debe usar exactamente un segmento vectorial m-l o m-b"
    track_zero: "tiene un segmento de clip de longitud cero"
    track_duration: "tiene una duración vacía o inválida"
    track_sample: "Muestra seleccionada"
    ["both"]: "ambos"
    ["none"]: "ninguno"
    ["first angle"]: "primer ángulo"
    ["transform angle"]: "ángulo en transform"
    ["Auto"]: "Auto"
    ["Two guide strokes"]: "dos trazos guía"
    ["Path tangents"]: "Tangentes de ruta"
    ["Whole text"]: "Texto completo"
    ["Auto by position"]: "auto por posición"
    ["Left/top half"]: "Mitad izquierda/arriba"
    ["Right/bottom half"]: "Mitad derecha/abajo"
    ["Left/top third"]: "Tercio izquierdo/arriba"
    ["Center third"]: "Tercio central"
    ["Right/bottom third"]: "Tercio derecho/abajo"
    ["Custom section"]: "Parte personalizada"
    ["Fit (uniform)"]: "Encajar uniforme"
    ["Fill (uniform)"]: "Rellenar uniforme"
    ["Stretch (per-axis)"]: "Estirar por eje"
    ["Horizontal"]: "Horizontal"
    ["Vertical"]: "Vertical"
    ["Clip only"]: "solo clip"
    ["Full line"]: "línea completa"
    ["Keep overlap"]: "conservar intersección"
    ["Cut text from clip"]: "Recortar texto del clip"
    ["By distance"]: "por distancia"
    ["By count"]: "por cantidad"
    ["1 keep dst org"]: "1 conservar org destino"
    ["2 quad center"]: "2 centro del quad"
    ["3 minimize fax"]: "3 minimizar fax"
  }
}

DEFAULTS = {
  operation: OPERATIONS[1]
  axis: "x"
  angle_mode: "none"
  curve_depth: 100
  curve_spacing: 0
  margin: 8
  tolerance: 1
  strip: 24
  strip_mode: "Horizontal"
  rescale_rect_mode: "Fit (uniform)"
  recenter: true
  sections: 2
  section_index: 1
  bleed: 1
  no_shrink: true
  style_pad: true
  transform_max_bounds: true
  replace_clip: true
  remove_clip: true
  create_new_lines: true
  comment_source: false
  point_mode: "By distance"
  point_distance: 5
  point_count: 1
  clip_type: "Auto"
  close_paths: true
  merge_identical: true
  max_frames: defaultFbfFrameBudget
  fbf_source: "Clip only"
  boolean_mode: "Keep overlap"
  perspective_map: "ABCD (exact copy)"
  perspective_org_mode: "2 quad center"
  info: true
  adj_fscx: true
  adj_fscy: true
  adj_fs: false
  adj_fsp: false
  adj_bord: true
  adj_shad: true
  adj_blur: true
}

clipTagNames = {"clip_rect", "iclip_rect", "clip_vect", "iclip_vect"}

numPattern = "[%+%-]?%.?%d+%.?%d*[eE]?[%+%-]?%d*"

Core.checkCancelled = LineOps.checkCancelled
Core.trim = KiteCore.trim

Core.copyLine = (line) ->
  pairs line if type(line) != "table"
  out = KiteCore.copy line
  setmetatable out, nil if type(out) == "table" and getmetatable(out) != nil
  out

Core.copyStyle = (style) ->
  return nil unless type(style) == "table"
  out = KiteCore.copy style
  setmetatable out, nil if getmetatable(out) != nil
  out

Core.assLine = (line) ->
  AssContext.toLine line, AMLine, Core.lineContext

Core.parseAssLine = (line) ->
  return line if ASS and type(line) == "table" and line.class == ASS.LineContents
  ASS\parse Core.assLine(line)

Core.clamp = KiteCore.clamp

Core.enumOption = (value, items, fallback) ->
  value = Core.choiceRaw value
  for item in *(items or {})
    return item if value == item
  fallback

Core.L = (key) ->
  lang = uiLang[current_language] or uiLang.en
  lang[key] or uiLang.en[key] or tostring(key or "")

Core.choiceLabel = (value) ->
  raw = tostring(value or "")
  return raw if raw == ""
  lang = uiLang[current_language] or uiLang.en
  lang[raw] or raw

Core.choiceRaw = (value) ->
  shown = tostring(value or "")
  return shown if current_language == defaultLanguage
  for raw, label in pairs uiLang[current_language] or {}
    return raw if label == shown
  shown

Core.localizedItems = (items) ->
  [Core.choiceLabel item for item in *(items or {})]

Core.validLanguage = (value) ->
  if value == "es" then "es" else "en"

Core.normalizePerspectiveMap = (value) ->
  raw = tostring(Core.choiceRaw(value) or "")
  aliased = perspectiveMapAliases[raw] or raw
  for entry in *perspectiveData.maps
    return entry[1] if aliased == entry[1]
  prefix = aliased\match "^([A-Z][A-Z][A-Z][A-Z])"
  if prefix
    for entry in *perspectiveData.maps
      return entry[1] if entry[1]\match("^" .. prefix)
  DEFAULTS.perspective_map

Core.normalizePerspectiveOrg = (value) ->
  raw = tostring(Core.choiceRaw(value) or "")
  aliased = perspectiveOrgAliases[raw] or raw
  for item in *perspectiveData.org_modes
    return item if aliased == item
  n = tonumber aliased\match "^(%d)"
  return perspectiveData.org_modes[n] if n and perspectiveData.org_modes[n]
  DEFAULTS.perspective_org_mode

Core.normalizeOperation = (operation) ->
  return "Bezier clip to curved text" if operation == "FRZ stops for LerpByChar"
  return "Clip to perspective" if operation == "Clip to Persp"
  Core.enumOption operation, OPERATIONS, DEFAULTS.operation

Core.operationLabel = (operation) ->
  labels = operationLabels[current_language] or operationLabels.en
  labels[operation] or operationLabels.en[operation] or tostring(operation or "")

Core.dropdownData = (items, labeler) ->
  out, to_raw, toShown = {""}, {[""]: ""}, {[""]: ""}
  n = 1
  for raw in *(items or {})
    if raw != nil and raw != ""
      shown = "#{n}. #{if labeler then labeler(raw) else Core.choiceLabel(raw)}"
      out[#out + 1] = shown
      to_raw[shown] = raw
      to_raw[raw] = raw
      toShown[raw] = shown
      n += 1
  out, to_raw, toShown

Core.shownChoice = (toShown, raw) ->
  (toShown and toShown[raw]) or raw or ""

Core.rawChoice = (to_raw, shown) ->
  (to_raw and to_raw[shown]) or Core.choiceRaw(shown) or ""

Core.rawOperationChoice = (to_raw, shown) ->
  Core.normalizeOperation Core.rawChoice(to_raw, shown)

Core.formatNum = (value, decimals = 3) ->
  n = tonumber value
  return "0" unless n and n == n and n != math.huge and n != -math.huge
  n = 0 if math.abs(n) < numericEpsilon
  if math.abs(n - math.floor(n + 0.5)) < numericEpsilon
    return tostring math.floor(n + 0.5)
  s = string.format "%." .. tostring(decimals) .. "f", n
  s = s\gsub "0+$", ""
  s = s\gsub "%.$", ""
  if s == "-0" or s == "" then "0" else s

Core.finiteNumber = KiteCore.finiteNumber

Core.round = (n, decimals = 0) ->
  n = tonumber(n) or 0
  if FunctionalMath and FunctionalMath.round
    ok, out = pcall FunctionalMath.round, n, decimals
    return out if ok and tonumber(out)
  p = 10 ^ (tonumber(decimals) or 0)
  math.floor(n * p + 0.5) / p

Core.warn = (message) ->
  if logger and logger.warn
    logger\warn message
  elseif aegisub and aegisub.debug and aegisub.debug.out
    aegisub.debug.out "[Cliptomaniac] #{message}\n"

messageEs = {
  ["No text could be fitted to a clip guide."]: "No se pudo ajustar ningun texto a una guia de clip."
  ["No perspective plane could be converted to clip."]: "No se pudo convertir ningun plano de perspectiva a clip."
  ["No 3-point vector clip could be completed."]: "No se pudo completar ningun clip vectorial de 3 puntos."
  ["No clip points changed."]: "No cambiaron puntos de clip."
  ["No vector clip with two usable segments was found."]: "No se encontró un clip vectorial con dos segmentos usables."
  ["No line was transformed."]: "No se transformó ninguna línea."
  ["Select two clipped lines, or one vector clip with two m-l strokes."]: "Selecciona dos líneas con clip, o un clip vectorial con dos trazos m-l."
  ["First clip segment has zero length."]: "El primer segmento del clip mide cero."
  ["No numeric tags changed."]: "No cambió ningún tag numérico."
  ["Shape tools are not available."]: "Las herramientas de formas no están disponibles."
  ["Could not prepare text bounds."]: "No se pudo preparar el área del texto."
  ["Text bounds could not be measured."]: "No se pudo medir el área del texto."
  ["No rectangular clip was found."]: "No se encontró un clip rectangular."
  ["Curved text must stay on one visual line."]: "El texto curvo debe permanecer en una sola línea visual."
  ["Curved text only accepts text, not \\p drawings."]: "El texto curvo solo acepta texto, no dibujos \\p."
  ["Remove animated \\fr/\\frz/\\fsp transforms before curving the text."]: "Quita las transformaciones animadas de \\fr/\\frz/\\fsp antes de curvar el texto."
  ["No visible text was found to curve."]: "No se encontró texto visible para curvar."
  ["Use exactly one cubic Bezier clip: \\clip(m x y b x1 y1 x2 y2 x3 y3)."]: "Usa exactamente un clip Bézier cúbico: \\clip(m x y b x1 y1 x2 y2 x3 y3)."
  ["No usable clip midpoint found."]: "No se encontró un centro de clip usable."
  ["No line position changed."]: "No cambió ninguna posición."
  ["No usable vector clip found."]: "No se encontró un clip vectorial usable."
  ["No position or clip geometry changed."]: "No cambió ninguna posición ni geometría del clip."
  ["No selected line had both \\pos and a usable clip segment."]: "Ninguna línea seleccionada tenía \\pos y un segmento de clip usable."
  ["No vector clip found for alignment."]: "No se encontró un clip vectorial para alinear."
  ["No selected line with \\pos could be aligned."]: "No se pudo alinear ninguna línea seleccionada con \\pos."
  ["No editable clip found."]: "No se encontró un clip editable."
  ["No source/target clip group found."]: "No se encontró grupo de clip fuente/destino."
  ["No clip was expanded."]: "No se expandió ningún clip."
  ["Text outline tools are not available."]: "Las herramientas de contorno de texto no están disponibles."
  ["No clip could be autofit."]: "No se pudo autoajustar ningún clip."
  ["Load a video to include transform maxima over the full line duration."]: "Carga un vídeo para incluir los máximos de las transformaciones durante toda la duración de la línea."
  ["This action needs the text measuring tools."]: "Esta acción necesita las herramientas de medición de texto."
  ["No text area could be clipped."]: "No se pudo crear clip de ningún área de texto."
  ["No text or drawing outline could be converted to a clip."]: "No se pudo convertir ningún texto o dibujo a clip."
  ["No drawing shape was converted to clip."]: "No se convirtió ningún dibujo a clip."
  ["No clip was converted to shape."]: "No se convirtió ningún clip a dibujo."
  ["No clip could be extracted as a mask line."]: "No se pudo extraer ningún clip como línea de máscara."
  ["Shape combining tools are not available."]: "Las herramientas para combinar formas no están disponibles."
  ["No clip could be combined with the text or drawing shape."]: "No se pudo combinar ningún clip con texto o dibujo."
  ["No dialogue lines selected."]: "No hay líneas de diálogo seleccionadas."
  ["No strip clips were generated."]: "No se generaron franjas de clip."
  ["No animated clip or movable clipped line could be baked."]: "No se pudo hornear ningún clip animado o línea con clip movible."
  ["Perspective tools are not available."]: "Las herramientas de perspectiva no están disponibles."
  ["No 4-point clip could be applied as perspective."]: "No se pudo aplicar ningún clip de 4 puntos como perspectiva."
}

Core.messageText = (message) ->
  text = tostring(message or "")
  return text unless current_language == "es"
  messageEs[text] or text

Core.messageTitle = (title) ->
  raw = tostring(title or "Cliptomaniac")
  if operationLabels.en[raw] then Core.operationLabel(raw) else raw

Core.showMessage = (message, title = "Cliptomaniac") ->
  Core.UI.message Core.messageText(message), {title: Core.messageTitle(title)}

Core.isDialogue = (line) ->
  line and line.class == "dialogue" and not line.comment

Core.dialogueIndices = (subs, sel, includeComments = false) ->
  LineOps.normalizeIndices subs, sel, (line) ->
    Core.isDialogue(line) or (includeComments and line and line.class == "dialogue")

Core.enrichSelectedLines = (subs, _sel) ->
  Core.lineContext = AssContext.fromSubtitles subs
  true

Core.ensureTagBlock = (text) ->
  text = tostring(text or "")
  return text if text\find "^{"
  "{}" .. text

Core.overrideBlockSpans = (text) ->
  text = tostring(text or "")
  spans, pos = {}, 1
  while true
    s = text\find "{", pos, true
    break unless s
    e = text\find "}", s + 1, true
    break unless e
    spans[#spans + 1] = {
      start: s
      stop: e
      inner: text\sub s + 1, e - 1
    }
    pos = e + 1
  spans

Core.looksLikeOverride = (inner) ->
  tostring(inner or "")\match("^%s*\\[%a%d]") != nil

Core.hasTransformTag = (text) ->
  for block in *Core.overrideBlockSpans text
    continue unless Core.looksLikeOverride block.inner
    return true if block.inner\find "\\t%("
  false

Core.videoResolution = ->
  return nil unless aegisub and type(aegisub.video_size) == "function"
  ok, x, y = pcall aegisub.video_size
  x, y = tonumber(x), tonumber(y)
  return nil unless ok and x and y and x > 0 and y > 0
  x, y

Core.videoLoaded = ->
  x, y = Core.videoResolution!
  x != nil and y != nil

Core.scriptResolution = (line, data = nil) ->
  positive = (value) ->
    n = Core.finiteNumber value
    if n and n > 0 then n else nil
  sub = data and data.sub or line and line.parentCollection and line.parentCollection.sub
  if sub
    ok, subX, subY = pcall -> sub\script_resolution!
    subX, subY = positive(subX), positive(subY)
    return subX, subY if ok and subX and subY
  readInfo = (info) ->
    info or= {}
    positive(info.PlayResX or info.playresx or info.res_x), positive(info.PlayResY or info.playresy or info.res_y)
  x, y = readInfo(data and data.scriptInfo)
  metaX, metaY = readInfo(line and line.parentCollection and line.parentCollection.meta)
  x or= metaX
  y or= metaY
  if (not x or not y) and sub and ASS and ASS.getScriptInfo
    ok, info = pcall -> ASS\getScriptInfo sub
    if ok and info
      infoX, infoY = readInfo info
      x or= infoX
      y or= infoY
  x, y

Core.trackingResolution = (subs) ->
  script_info = {}
  for i = 1, #subs
    line = subs[i]
    if line and line.class == "info"
      key = tostring(line.key or "")
      script_info[key] = line.value
      script_info[key\lower!] = line.value
  x, y = Core.scriptResolution nil, {scriptInfo: script_info}
  return x, y if x and y
  x, y = Core.videoResolution!
  if x and y then x, y else 1920, 1080

Core.spanIsInOverride = (text, absolutePos) ->
  for block in *Core.overrideBlockSpans text
    if absolutePos > block.start and absolutePos < block.stop and Core.looksLikeOverride block.inner
      return true
  false

Core.mapOverrideBlocks = (text, mapper) ->
  text = tostring(text or "")
  out, pos, changed = {}, 1, 0
  for block in *Core.overrideBlockSpans text
    out[#out + 1] = text\sub pos, block.start - 1
    if Core.looksLikeOverride block.inner
      nextInner = mapper block.inner, block
      if nextInner != nil and nextInner != block.inner
        out[#out + 1] = "{" .. tostring(nextInner) .. "}"
        changed += 1
      else
        out[#out + 1] = text\sub block.start, block.stop
    else
      out[#out + 1] = text\sub block.start, block.stop
    pos = block.stop + 1
  out[#out + 1] = text\sub pos
  table.concat(out), changed

Core.cleanEmptyOverrides = (text) ->
  tostring(text or "")\gsub "{%s*}", ""

Core.insertLeadingTags = (text, payload) ->
  text = tostring(text or "")
  return text if not payload or payload == ""
  first = Core.overrideBlockSpans(text)[1]
  if first and first.start == 1 and Core.looksLikeOverride first.inner
    "{" .. payload .. first.inner .. "}" .. text\sub(first.stop + 1)
  else
    "{" .. payload .. "}" .. text

Core.stripTags = (text) -> LineOps.analyzeText(text).plain

Core.visibleText = (text) -> LineOps.visibleText text

Core.overrideTagsOnly = (text) ->
  out = {}
  for block in *Core.overrideBlockSpans text
    if Core.looksLikeOverride block.inner
      out[#out + 1] = "{" .. block.inner .. "}"
  Core.cleanEmptyOverrides table.concat(out)

Core.nextChar = (text, pos) ->
  if unicode and unicode.chars
    rest = text\sub pos
    for ch in unicode.chars rest
      return ch, #ch
  first = text\byte pos
  len = if not first or first < 0x80
    1
  elseif first < 0xE0
    2
  elseif first < 0xF0
    3
  elseif first < 0xF8
    4
  else
    1
  text\sub(pos, math.min(#text, pos + len - 1)), len

Core.balancedParenEnd = (text, openPos) ->
  depth = 0
  for i = openPos, #text
    c = text\sub i, i
    if c == "("
      depth += 1
    elseif c == ")"
      depth -= 1
      return i if depth == 0
  nil

Core.ass_override_names = {
  "iclip", "clip", "xbord", "ybord", "xshad", "yshad", "fscx", "fscy"
  "alpha", "blur", "bord", "shad", "move", "fade", "frx", "fry", "frz", "fax", "fay"
  "pos", "org", "fad", "fsp", "fn", "fs", "be", "an", "fr", "ko", "kf", "kt"
  "1a", "2a", "3a", "4a", "1c", "2c", "3c", "4c", "c", "p", "b", "i", "u", "s", "r", "t", "q", "k", "K", "a"
}

Core.tagNameAt = (inner, slashPos) ->
  rest = tostring(inner or "")\sub (tonumber(slashPos) or 0) + 1
  for name in *Core.ass_override_names
    return name if rest\sub(1, #name) == name
  rest\match "^[1-4]?%a+"

Core.clipSpanInInner = (text, inner, base_offset, init = 1) ->
  frames = {{inner: inner or "", base_offset: base_offset, pos: 1, in_transform: false}}
  while #frames > 0
    frame = frames[#frames]
    if frame.pos > #frame.inner
      table.remove frames
    elseif frame.inner\sub(frame.pos, frame.pos) == "\\"
      name = Core.tagNameAt frame.inner, frame.pos
      if name
        valuePos = frame.pos + 1 + #name
        if frame.inner\sub(valuePos, valuePos) == "("
          close = Core.balancedParenEnd frame.inner, valuePos
          return nil unless close
          absolute_start = frame.base_offset + frame.pos
          if (name == "clip" or name == "iclip") and absolute_start >= init
            absolute_open = frame.base_offset + valuePos
            absolute_stop = frame.base_offset + close
            return {
              start: absolute_start
              stop: absolute_stop
              open_pos: absolute_open
              name: name
              raw: text\sub absolute_start, absolute_stop
              inner: frame.inner\sub valuePos + 1, close - 1
              in_transform: frame.in_transform and true or false
            }
          frame.pos = close + 1
          frames[#frames + 1] = {
            inner: frame.inner\sub(valuePos + 1, close - 1)
            base_offset: frame.base_offset + valuePos
            pos: 1
            in_transform: frame.in_transform or name == "t"
          }
          continue
        frame.pos = valuePos
        continue
      frame.pos += 1
    else
      frame.pos += 1
  nil

Core.clipSpanInBlock = (text, block, init = 1) ->
  Core.clipSpanInInner text, block.inner or "", block.start, init

Core.firstClipSpan = (text, init = 1) ->
  text = tostring(text or "")
  for block in *Core.overrideBlockSpans text
    continue unless block.stop >= init and Core.looksLikeOverride block.inner
    span = Core.clipSpanInBlock text, block, init
    return span if span
  nil

Core.allClipSpans = (text) ->
  spans, pos = {}, 1
  while true
    span = Core.firstClipSpan text, pos
    break unless span
    spans[#spans + 1] = span
    pos = span.stop + 1
  spans

Core.mapClipTags = (text, mapper) ->
  text = tostring(text or "")
  out, pos, changed = {}, 1, 0
  while true
    span = Core.firstClipSpan text, pos
    break unless span
    out[#out + 1] = text\sub pos, span.start - 1
    replacement = mapper span
    if replacement and replacement != span.raw
      out[#out + 1] = replacement
      changed += 1
    else
      out[#out + 1] = span.raw
    pos = span.stop + 1
  out[#out + 1] = text\sub pos
  table.concat(out), changed

Core.stripClipTags = (text) ->
  mapped = Core.mapClipTags text, -> ""
  mapped

Core.stripAllClipsClean = (text) ->
  stripped = Core.stripClipTags text
  stripped = Core.mapOverrideBlocks stripped, (inner) ->
    inner\gsub "\\t%(%s*[%d%+%-%.eE,%s]*%)", ""
  Core.cleanEmptyOverrides stripped

Core.clipTagText = (name, inner) ->
  "\\" .. (name or "clip") .. "(" .. tostring(inner or "") .. ")"

Core.clipKindFromSpan = (span) ->
  span and span.name or "clip"

Core.normalizeBounds = (bounds) ->
  left, top, right, bottom = unpack bounds
  left, right = right, left if left > right
  top, bottom = bottom, top if top > bottom
  {left, top, right, bottom}

Core.padBounds = (bounds, margin) ->
  left, top, right, bottom = unpack Core.normalizeBounds bounds
  margin = tonumber(margin) or 0
  {left - margin, top - margin, right + margin, bottom + margin}

Core.unionBounds = (a, b) ->
  a, b = Core.normalizeBounds(a), Core.normalizeBounds(b)
  {math.min(a[1], b[1]), math.min(a[2], b[2]), math.max(a[3], b[3]), math.max(a[4], b[4])}

Core.rectClipInner = (bounds) ->
  left, top, right, bottom = unpack Core.normalizeBounds bounds
  "#{math.floor(left)},#{math.floor(top)},#{math.ceil(right)},#{math.ceil(bottom)}"

Core.rectClipTag = (bounds, name = "clip") ->
  Core.clipTagText name, Core.rectClipInner bounds

Core.rectPoints = (bounds) ->
  left, top, right, bottom = unpack Core.normalizeBounds bounds
  {
    {x: left, y: top}
    {x: right, y: top}
    {x: right, y: bottom}
    {x: left, y: bottom}
  }

Core.vectorClipInner = (points) ->
  "m #{Core.formatNum points[1].x} #{Core.formatNum points[1].y} l #{Core.formatNum points[2].x} #{Core.formatNum points[2].y} #{Core.formatNum points[3].x} #{Core.formatNum points[3].y} #{Core.formatNum points[4].x} #{Core.formatNum points[4].y}"

Core.vectorClipTag = (points, name = "clip") ->
  Core.clipTagText name, Core.vectorClipInner points

Core.scaleClipPath = (path, scale) ->
  factor = 2 ^ ((tonumber(scale) or 1) - 1)
  return path if math.abs(factor - 1) < numericEpsilon
  tostring(path or "")\gsub "(" .. numPattern .. ")", (n) ->
    v = tonumber n
    if v then Core.formatNum(v / factor) else n

Core.clipScaleFactor = (scale) ->
  2 ^ ((tonumber(scale) or 1) - 1)

Core.scalePathNumbers = (path, factor) ->
  tostring(path or "")\gsub "(" .. numPattern .. ")", (n) ->
    v = tonumber n
    if v then Core.formatNum(v * factor) else n

Core.vectorInnerWithScale = (path, scale) ->
  return path unless scale
  "#{scale},#{Core.scalePathNumbers path, Core.clipScaleFactor scale}"

Core.clipInnerParts = (inner) ->
  inner = Core.trim inner
  scale, path = inner\match "^%s*(%d+)%s*,%s*([mMnN]%s+.*)$"
  if path
    numericScale = tonumber scale
    return nil, nil, nil unless numericScale and numericScale >= 1
    return "vector", scale, Core.scaleClipPath(path, numericScale)
  path = inner\match "^%s*([mMnN]%s+.*)$"
  if path
    return "vector", nil, path
  number = "(" .. numPattern .. ")"
  x1, y1, x2, y2 = inner\match "^%s*" .. number .. "%s*,%s*" .. number .. "%s*,%s*" .. number .. "%s*,%s*" .. number .. "%s*$"
  x1, y1, x2, y2 = tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2)
  if x1 and y1 and x2 and y2
    return "rect", nil, {x1, y1, x2, y2}
  nil, nil, nil

Core.clipBoundsFromSpan = (span) ->
  kind, _, payload = Core.clipInnerParts span.inner
  if kind == "rect"
    return Core.normalizeBounds payload
  if kind == "vector"
    cmds = Core.parseDrawCommands payload
    sampled = nil
    sampled = Core.samplePath cmds, 30 if cmds
    points = if sampled and #sampled > 0 then [item.p for item in *sampled when item and item.p] else Core.anchorPointsFromCommands cmds
    if points and #points > 0
      minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
      for p in *points
        minx = math.min minx, p.x
        miny = math.min miny, p.y
        maxx = math.max maxx, p.x
        maxy = math.max maxy, p.y
      return {minx, miny, maxx, maxy}
  nil

Core.firstClipBounds = (text) ->
  span = Core.firstClipSpan text
  return nil unless span
  Core.clipBoundsFromSpan span

Core.tokensForPath = (path) ->
  s = tostring(path or "")\gsub ",", " "
  s = s\gsub "([mMlLbBsSpPcCnN])", " %1 "
  tokens = {}
  for token in s\gmatch "%S+"
    tokens[#tokens + 1] = token
  tokens

Core.parseDrawCommands = (path) ->
  tokens = Core.tokensForPath path
  cmds, i, cmd = {}, 1, nil
  while i <= #tokens
    token = tokens[i]
    if token\match "^[mMlLbBsSpPcCnN]$"
      cmd = token\lower!
      cmd = "m" if cmd == "n"
      if cmd == "c"
        cmds[#cmds + 1] = {type: "c", pts: {}}
        cmd = nil
      i += 1
      continue
    return nil unless cmd
    return nil if cmd == "s" or cmd == "p"
    if cmd == "m" or cmd == "l"
      x, y = tonumber(tokens[i]), tonumber(tokens[i + 1])
      return nil unless x and y
      draw_type = if cmd == "m" then "m" else "l"
      cmds[#cmds + 1] = {type: draw_type, pts: {x, y}}
      i += 2
    elseif cmd == "b"
      pts = {}
      for j = 0, 5
        pts[#pts + 1] = tonumber tokens[i + j]
      return nil unless pts[1] and pts[2] and pts[3] and pts[4] and pts[5] and pts[6]
      cmds[#cmds + 1] = {type: "b", pts: pts}
      i += 6
    else
        return nil
  cmds

Core.pointXy = (x, y) ->
  {x: tonumber(x) or 0, y: tonumber(y) or 0}

Core.pointText = (prefix, point) ->
  "#{prefix} #{Core.formatNum point.x} #{Core.formatNum point.y}"

Core.lerpPoint = (a, b, t) ->
  {
    x: a.x + (b.x - a.x) * t
    y: a.y + (b.y - a.y) * t
  }

Core.pointInsertDistances = (length, opts = {}) ->
  length = tonumber(length) or 0
  out = {}
  return out unless length > 0
  if opts.point_mode == "By count"
    count = math.max 0, math.floor(tonumber(opts.point_count) or 0)
    for i = 1, count
      out[#out + 1] = length * i / (count + 1)
  else
    spacing = tonumber(opts.point_distance) or 0
    return out unless spacing > 0
    d = spacing
    while d < length - geometryEpsilon
      out[#out + 1] = d
      d += spacing
  out

Core.addLineInsertPoints = (parts, p1, p2, opts = {}, includeEnd = true) ->
  dx, dy = p2.x - p1.x, p2.y - p1.y
  length = math.sqrt dx * dx + dy * dy
  added = 0
  if length > 0
    for d in *Core.pointInsertDistances(length, opts)
      t = d / length
      parts[#parts + 1] = Core.pointText "l", {x: p1.x + dx * t, y: p1.y + dy * t}
      added += 1
  parts[#parts + 1] = Core.pointText "l", p2 if includeEnd
  added

Core.bezierArclengthSamples = (p0, p1, p2, p3, segments = bezierArclengthSegments) ->
  segments = math.max 1, math.floor(tonumber(segments) or bezierArclengthSegments)
  samples = {{t: 0, p: p0, acc: 0}}
  prev, total = p0, 0
  for i = 1, segments
    t = i / segments
    pt = Core.bezierPoint t, p0, p1, p2, p3
    dist = math.sqrt((pt.x - prev.x) ^ 2 + (pt.y - prev.y) ^ 2)
    total += dist
    samples[#samples + 1] = {t: t, p: pt, acc: total}
    prev = pt
  samples, total

Core.bezierTAtDistance = (samples, target) ->
  return 0 unless samples and #samples > 0
  target = tonumber(target) or 0
  return 0 if target <= 0
  last = samples[#samples]
  return 1 if target >= (last.acc or 0)
  for i = 2, #samples
    if (samples[i].acc or 0) >= target
      a, b = samples[i - 1], samples[i]
      span = (b.acc or 0) - (a.acc or 0)
      k = if span == 0 then 0 else (target - (a.acc or 0)) / span
      return (a.t or 0) + ((b.t or 0) - (a.t or 0)) * k
  1

Core.bezierSplit = (p0, p1, p2, p3, t) ->
  t = Core.clamp tonumber(t) or 0, 0, 1
  p01 = Core.lerpPoint p0, p1, t
  p12 = Core.lerpPoint p1, p2, t
  p23 = Core.lerpPoint p2, p3, t
  p012 = Core.lerpPoint p01, p12, t
  p123 = Core.lerpPoint p12, p23, t
  p0123 = Core.lerpPoint p012, p123, t
  {p0, p01, p012, p0123}, {p0123, p123, p23, p3}

Core.addBezierPart = (parts, curve) ->
  parts[#parts + 1] = "b #{Core.formatNum curve[2].x} #{Core.formatNum curve[2].y} #{Core.formatNum curve[3].x} #{Core.formatNum curve[3].y} #{Core.formatNum curve[4].x} #{Core.formatNum curve[4].y}"

Core.addBezierInsertPoints = (parts, p0, p1, p2, p3, opts = {}) ->
  samples, total = Core.bezierArclengthSamples p0, p1, p2, p3
  targets = [Core.bezierTAtDistance(samples, d) for d in *Core.pointInsertDistances(total, opts)]
  current = {p0, p1, p2, p3}
  prevT, added = 0, 0
  for tAbs in *targets
    continue unless tAbs > prevT + parametricEpsilon and tAbs < 1 - parametricEpsilon
    localT = (tAbs - prevT) / (1 - prevT)
    left, right = Core.bezierSplit current[1], current[2], current[3], current[4], localT
    Core.addBezierPart parts, left
    current = right
    prevT = tAbs
    added += 1
  Core.addBezierPart parts, current
  added

Core.addCloseInsertPoints = (parts, startPoint, currentPoint, anchorCount, opts = {}) ->
  return 0 unless anchorCount >= 3 and startPoint and currentPoint
  return 0 if Core.samePoint startPoint, currentPoint
  Core.addLineInsertPoints parts, currentPoint, startPoint, opts, false

Core.densifyClipPath = (path, opts = {}) ->
  cmds = Core.parseDrawCommands path
  return nil, 0 unless cmds
  parts, startPoint, currentPoint, anchorCount, added = {}, nil, nil, 0, 0
  for cmd in *cmds
    if cmd.type == "m" and #cmd.pts >= 2
      added += Core.addCloseInsertPoints parts, startPoint, currentPoint, anchorCount, opts
      startPoint = Core.pointXy(cmd.pts[1], cmd.pts[2])
      currentPoint = startPoint
      anchorCount = 1
      parts[#parts + 1] = Core.pointText "m", startPoint
    elseif cmd.type == "l" and currentPoint and #cmd.pts >= 2
      nextPoint = Core.pointXy(cmd.pts[1], cmd.pts[2])
      unless Core.samePoint currentPoint, nextPoint
        added += Core.addLineInsertPoints parts, currentPoint, nextPoint, opts, true
        anchorCount += 1
      currentPoint = nextPoint
    elseif cmd.type == "b" and currentPoint and #cmd.pts >= 6
      c1 = Core.pointXy(cmd.pts[1], cmd.pts[2])
      c2 = Core.pointXy(cmd.pts[3], cmd.pts[4])
      nextPoint = Core.pointXy(cmd.pts[5], cmd.pts[6])
      added += Core.addBezierInsertPoints parts, currentPoint, c1, c2, nextPoint, opts
      currentPoint = nextPoint
      anchorCount += 1
    elseif cmd.type == "c"
      added += Core.addCloseInsertPoints parts, startPoint, currentPoint, anchorCount, opts
      currentPoint = startPoint if startPoint
  added += Core.addCloseInsertPoints parts, startPoint, currentPoint, anchorCount, opts
  return nil, 0 if #parts == 0
  Core.trim(table.concat(parts, " ")), added

Core.pathSubpaths = (cmds) ->
  subpaths, current = {}, nil
  for cmd in *(cmds or {})
    if cmd.type == "m" and #cmd.pts >= 2
      current = {points: {Core.pointXy(cmd.pts[1], cmd.pts[2])}}
      subpaths[#subpaths + 1] = current
    elseif current and cmd.type == "l" and #cmd.pts >= 2
      current.points[#current.points + 1] = Core.pointXy(cmd.pts[1], cmd.pts[2])
    elseif current and cmd.type == "b" and #cmd.pts >= 6
      current.points[#current.points + 1] = Core.pointXy(cmd.pts[5], cmd.pts[6])
  for sub in *subpaths
    sub.points = Core.cleanAnchorPoints sub.points
  subpaths

Core.pathFromSubpaths = (subpaths) ->
  parts = {}
  for sub in *(subpaths or {})
    pts = sub.points or {}
    continue unless #pts > 0
    parts[#parts + 1] = Core.pointText "m", pts[1]
    for i = 2, #pts
      parts[#parts + 1] = Core.pointText "l", pts[i]
  return nil if #parts == 0
  Core.trim table.concat parts, " "

Core.removeAlternateClipPointsPath = (path) ->
  cmds = Core.parseDrawCommands path
  return nil, false unless cmds
  subpaths = Core.pathSubpaths cmds
  changed = false
  for sub in *subpaths
    pts = sub.points or {}
    if #pts > 3
      reduced = {}
      for i, point in ipairs pts
        reduced[#reduced + 1] = point if i % 2 == 1
      if #reduced >= 3 and #reduced < #pts
        sub.points = reduced
        changed = true
  return nil, false unless changed
  Core.pathFromSubpaths(subpaths), true

Core.newShapeSplitPath = (path) ->
  cmds = Core.parseDrawCommands path
  return nil unless cmds
  subpaths = Core.pathSubpaths cmds
  return nil unless #subpaths > 0
  lastSub = subpaths[#subpaths]
  return nil unless lastSub and lastSub.points and #lastSub.points >= 3
  lastPoint = lastSub.points[#lastSub.points]
  output, removed = {}, false
  for i = 1, #cmds
    cmd = cmds[i]
    if i == #cmds and (cmd.type == "l" or cmd.type == "b")
      removed = true
      continue
    if cmd.type == "m" and #cmd.pts >= 2
      output[#output + 1] = Core.pointText "m", Core.pointXy(cmd.pts[1], cmd.pts[2])
    elseif cmd.type == "l" and #cmd.pts >= 2
      output[#output + 1] = Core.pointText "l", Core.pointXy(cmd.pts[1], cmd.pts[2])
    elseif cmd.type == "b" and #cmd.pts >= 6
      output[#output + 1] = "b #{Core.formatNum cmd.pts[1]} #{Core.formatNum cmd.pts[2]} #{Core.formatNum cmd.pts[3]} #{Core.formatNum cmd.pts[4]} #{Core.formatNum cmd.pts[5]} #{Core.formatNum cmd.pts[6]}"
  return nil unless removed and #output > 0
  output[#output + 1] = Core.pointText "m", lastPoint
  Core.trim table.concat output, " "

Core.clipCommandsFromSpan = (span) ->
  kind, _, payload = Core.clipInnerParts span.inner
  if kind == "rect"
    left, top, right, bottom = unpack Core.normalizeBounds payload
    return {
      {type: "m", pts: {left, top}}
      {type: "l", pts: {right, top}}
      {type: "l", pts: {right, bottom}}
      {type: "l", pts: {left, bottom}}
      {type: "l", pts: {left, top}}
    }
  if kind == "vector"
    return Core.parseDrawCommands payload
  nil

Core.samePoint = (a, b, epsilon = geometryEpsilon) ->
  a and b and math.abs((a.x or 0) - (b.x or 0)) <= epsilon and math.abs((a.y or 0) - (b.y or 0)) <= epsilon

Core.cleanAnchorPoints = (points) ->
  out = {}
  for p in *(points or {})
    if p and p.x and p.y and (not out[#out] or not Core.samePoint out[#out], p)
      out[#out + 1] = {x: p.x, y: p.y}
  if #out > 1 and Core.samePoint out[1], out[#out]
    table.remove out
  out

Core.anchorPointsFromCommands = (cmds) ->
  points = {}
  for cmd in *(cmds or {})
    if (cmd.type == "m" or cmd.type == "l") and #cmd.pts >= 2
      points[#points + 1] = {x: cmd.pts[1], y: cmd.pts[2]}
    elseif cmd.type == "b" and #cmd.pts >= 6
      points[#points + 1] = {x: cmd.pts[5], y: cmd.pts[6]}
  Core.cleanAnchorPoints points

Core.centerFromPoints = (points) ->
  return nil unless points and #points > 0
  minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
  for p in *points
    minx = math.min minx, p.x
    miny = math.min miny, p.y
    maxx = math.max maxx, p.x
    maxy = math.max maxy, p.y
  {x: (minx + maxx) / 2, y: (miny + maxy) / 2}

Core.quadPointsFromSpan = (span) ->
  kind, _, payload = Core.clipInnerParts span.inner
  if kind == "rect"
    return Core.rectPoints payload
  return nil unless kind == "vector"
  cmds = Core.parseDrawCommands payload
  points = Core.anchorPointsFromCommands cmds
  return nil unless #points == 4
  points

Core.firstClipCommands = (text) ->
  span = Core.firstClipSpan text
  return nil, nil unless span
  Core.clipCommandsFromSpan(span), span

Core.trackingSegmentForLine = (line) ->
  effective = nil
  for span in *Core.allClipSpans(line and line.text or "")
    return nil, "transform" if span.in_transform
    effective = span
  return nil, "no_clip" unless effective
  kind, _, payload = Core.clipInnerParts effective.inner
  return nil, "segment" unless kind == "vector"
  cmds = Core.parseDrawCommands payload
  return nil, "segment" unless cmds and #cmds == 2 and cmds[1].type == "m" and (cmds[2].type == "l" or cmds[2].type == "b")
  return nil, "segment" unless (cmds[2].type == "l" and #cmds[2].pts == 2) or (cmds[2].type == "b" and #cmds[2].pts == 6)
  x1, y1 = cmds[1].pts[1], cmds[1].pts[2]
  local x2, y2
  if cmds[2].type == "l"
    x2, y2 = cmds[2].pts[1], cmds[2].pts[2]
  else
    x2, y2 = cmds[2].pts[5], cmds[2].pts[6]
  segment = {:x1, :y1, :x2, :y2}
  length = Core.segmentLength segment
  return nil, "zero" unless length > geometryEpsilon
  {
    :x1, :y1, :x2, :y2
    kind: cmds[2].type
    span: effective
    x: (x1 + x2) / 2
    y: (y1 + y2) / 2
    :length
    angle: Core.segmentAngleMath segment
  }

Core.atan2 = (dy, dx) ->
  dy, dx = tonumber(dy) or 0, tonumber(dx) or 0
  if math.atan2
    return math.atan2 dy, dx
  if dx > 0 then return math.atan(dy / dx)
  if dx < 0 and dy >= 0 then return math.atan(dy / dx) + math.pi
  if dx < 0 then return math.atan(dy / dx) - math.pi
  if dy > 0 then return math.pi / 2
  if dy < 0 then return -math.pi / 2
  0

Core.segmentLength = (segment) ->
  return 0 unless segment
  dx, dy = segment.x2 - segment.x1, segment.y2 - segment.y1
  math.sqrt dx * dx + dy * dy

Core.segmentAngleMath = (segment) ->
  return 0 unless segment
  math.deg Core.atan2 segment.y2 - segment.y1, segment.x2 - segment.x1

Core.segmentFrz = (segment) ->
  -Core.segmentAngleMath segment

Core.lerpAngle = (a, b, t) ->
  a, b = tonumber(a) or 0, tonumber(b) or 0
  delta = (b - a) % (math.pi * 2)
  delta -= math.pi * 2 if delta > math.pi
  a + delta * (tonumber(t) or 0)

Core.firstRealAngle = (sampled, fallback = 0) ->
  return fallback unless sampled
  for item in *sampled
    return item.angle if item and (item.dist or 0) > 0 and item.angle != nil
  fallback

Core.bezierPoint = (t, p0, p1, p2, p3) ->
  u = 1 - t
  tt, uu = t * t, u * u
  uuu, ttt = uu * u, tt * t
  {
    x: uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x
    y: uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y
  }

Core.bezierDerivative = (t, p0, p1, p2, p3) ->
  u = 1 - t
  uu, tt = u * u, t * t
  {
    x: 3 * uu * (p1.x - p0.x) + 6 * u * t * (p2.x - p1.x) + 3 * tt * (p3.x - p2.x)
    y: 3 * uu * (p1.y - p0.y) + 6 * u * t * (p2.y - p1.y) + 3 * tt * (p3.y - p2.y)
  }

Core.firstPathSegments = (cmds, count = 2, bezierSteps = 8) ->
  out, cur = {}, nil
  for cmd in *(cmds or {})
    if cmd.type == "m" and #cmd.pts >= 2
      cur = {x: cmd.pts[1], y: cmd.pts[2]}
    elseif cmd.type == "l" and cur and #cmd.pts >= 2
      nx, ny = cmd.pts[1], cmd.pts[2]
      if nx != cur.x or ny != cur.y
        out[#out + 1] = {x1: cur.x, y1: cur.y, x2: nx, y2: ny}
        return out if #out >= count
      cur = {x: nx, y: ny}
    elseif cmd.type == "b" and cur and #cmd.pts >= 6
      p1 = {x: cmd.pts[1], y: cmd.pts[2]}
      p2 = {x: cmd.pts[3], y: cmd.pts[4]}
      p3 = {x: cmd.pts[5], y: cmd.pts[6]}
      prev = cur
      for step = 1, math.max(1, bezierSteps)
        pt = Core.bezierPoint step / bezierSteps, cur, p1, p2, p3
        if pt.x != prev.x or pt.y != prev.y
          out[#out + 1] = {x1: prev.x, y1: prev.y, x2: pt.x, y2: pt.y}
          return out if #out >= count
        prev = pt
      cur = p3
  out

Core.samplePath = (cmds, segments = 30) ->
  pts, cur = {}, {x: 0, y: 0}
  segments = math.max 1, tonumber(segments) or 30
  for cmd in *(cmds or {})
    if cmd.type == "m" and #cmd.pts >= 2
      cur = {x: cmd.pts[1], y: cmd.pts[2]}
      pts[#pts + 1] = {p: cur, dist: 0, angle: 0}
    elseif cmd.type == "l" and #cmd.pts >= 2
      pts[#pts + 1] = {p: cur, dist: 0, angle: 0} if #pts == 0
      nx, ny = cmd.pts[1], cmd.pts[2]
      dx, dy = nx - cur.x, ny - cur.y
      dist = math.sqrt dx * dx + dy * dy
      if dist > 0
        ang = Core.atan2 dy, dx
        for j = 1, segments
          t = j / segments
          pts[#pts + 1] = {p: {x: cur.x + dx * t, y: cur.y + dy * t}, dist: dist / segments, angle: ang}
      cur = {x: nx, y: ny}
    elseif cmd.type == "b" and #cmd.pts >= 6
      pts[#pts + 1] = {p: cur, dist: 0, angle: 0} if #pts == 0
      p1 = {x: cmd.pts[1], y: cmd.pts[2]}
      p2 = {x: cmd.pts[3], y: cmd.pts[4]}
      p3 = {x: cmd.pts[5], y: cmd.pts[6]}
      for j = 1, segments
        t = j / segments
        pt = Core.bezierPoint t, cur, p1, p2, p3
        dp = Core.bezierDerivative t, cur, p1, p2, p3
        prev = pts[#pts] and pts[#pts].p or cur
        pts[#pts + 1] = {
          p: pt
          dist: math.sqrt((pt.x - prev.x) ^ 2 + (pt.y - prev.y) ^ 2)
          angle: Core.atan2 dp.y, dp.x
        }
      cur = p3
  total = 0
  for i = 2, #pts
    total += pts[i].dist or 0
    pts[i].accDist = total
  pts[1].accDist = 0 if pts[1]
  pts, total

Core.pointOnPath = (sampled, target) ->
  return nil unless sampled and #sampled > 0
  if target <= 0
    first = sampled[1]
    return {p: first.p, angle: Core.firstRealAngle sampled, first.angle or 0}
  return sampled[#sampled] if target >= sampled[#sampled].accDist
  for i = 2, #sampled
    if sampled[i].accDist >= target
      p1, p2 = sampled[i - 1], sampled[i]
      d = p2.accDist - p1.accDist
      t = if d == 0 then 0 else (target - p1.accDist) / d
      a1, a2 = p1.angle or 0, p2.angle or 0
      a1 = a2 if (p1.dist or 0) == 0
      return {
        p: {
          x: p1.p.x + (p2.p.x - p1.p.x) * t
          y: p1.p.y + (p2.p.y - p1.p.y) * t
        }
        angle: Core.lerpAngle a1, a2, t
      }
  sampled[#sampled]

Core.firstClipPathReference = (subs, sel) ->
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    cmds, span = Core.firstClipCommands subs[i].text
    return cmds, span, i if cmds and span
  nil, nil, nil

Core.pathMidpoint = (cmds) ->
  sampled, total = Core.samplePath cmds, 40
  return nil unless sampled and total and total > 0
  item = Core.pointOnPath sampled, total / 2
  item and item.p

Core.clipMidpointFromSpan = (span) ->
  return nil unless span
  kind, _, payload = Core.clipInnerParts span.inner
  if kind == "rect"
    b = Core.normalizeBounds payload
    return {x: (b[1] + b[3]) / 2, y: (b[2] + b[4]) / 2}
  return nil unless kind == "vector"
  cmds = Core.clipCommandsFromSpan span
  anchors = Core.anchorPointsFromCommands cmds
  return Core.centerFromPoints anchors if #anchors >= 4
  Core.pathMidpoint cmds

Core.clipMidpointForLine = (line, fallback = nil) ->
  span = Core.firstClipSpan line.text
  if span
    point = Core.clipMidpointFromSpan span
    return point if point
  fallback

Core.pathSegments = (cmds, steps = 30) ->
  sampled, total = Core.samplePath cmds, steps
  out = {}
  return out unless total and total > 0
  for i = 2, #sampled
    a, b = sampled[i - 1], sampled[i]
    if a and b and a.p and b.p and (b.dist or 0) > 0
      out[#out + 1] = {x1: a.p.x, y1: a.p.y, x2: b.p.x, y2: b.p.y}
  out

Core.distanceToSegment = (px, py, x1, y1, x2, y2) ->
  dx, dy = x2 - x1, y2 - y1
  len2 = dx * dx + dy * dy
  if len2 == 0
    ddx, ddy = px - x1, py - y1
    return math.sqrt(ddx * ddx + ddy * ddy), x1, y1
  t = ((px - x1) * dx + (py - y1) * dy) / len2
  t = Core.clamp t, 0, 1
  bx, by = x1 + t * dx, y1 + t * dy
  ddx, ddy = px - bx, py - by
  math.sqrt(ddx * ddx + ddy * ddy), bx, by

Core.clipScaleReference = (subs, sel) ->
  clipped, single = {}, nil
  for i in *(sel or {})
    line = subs[i]
    if Core.isDialogue line
      cmds, span = Core.firstClipCommands line.text
      if cmds
        segs = Core.firstPathSegments cmds, 2, 8
        if #segs > 0
          clipped[#clipped + 1] = {index: i, seg: segs[1], span: span}
          single = {index: i, seg1: segs[1], seg2: segs[2], span: span} if not single and #segs >= 2
  if #clipped >= 2
    return clipped[1].seg, clipped[2].seg, {mode: "lines", source: clipped[1].index, target: clipped[2].index}
  if single
    return single.seg1, single.seg2, {mode: "single", source: single.index}
  nil, nil, nil, "no_clip"

Core.curveCharUnits = (text) ->
  text = tostring(text or "")
  units, pos = {}, 1
  while pos <= #text
    c = text\sub pos, pos
    if c == "{"
      close = text\find "}", pos + 1, true
      break unless close
      pos = close + 1
    elseif c == "\\" and pos < #text
      escaped = text\sub pos + 1, pos + 1
      return nil, "multiline" if escaped == "N" or escaped == "n"
      if escaped == "h"
        units[#units + 1] = {start: pos, stop: pos + 1, insert: false}
        pos += 2
      elseif escaped == "\\"
        units[#units + 1] = {start: pos, stop: pos + 1, insert: true}
        pos += 2
      else
        units[#units + 1] = {start: pos, stop: pos, insert: true}
        pos += 1
    else
      ch, len = Core.nextChar text, pos
      len = math.max 1, tonumber(len) or 1
      units[#units + 1] = {start: pos, stop: pos + len - 1, insert: not ch\match("^%s$")}
      pos += len
  units

Core.insertTagsAtSpans = (text, inserts) ->
  text = tostring(text or "")
  return text unless inserts and #inserts > 0
  table.sort inserts, (a, b) -> a.pos < b.pos
  out, cursor = {}, 1
  for item in *inserts
    pos = Core.clamp tonumber(item.pos) or 1, 1, #text + 1
    if pos >= cursor
      out[#out + 1] = text\sub cursor, pos - 1
      out[#out + 1] = item.tag
      cursor = pos
  out[#out + 1] = text\sub cursor
  table.concat out

Core.numericTagValue = (text, tag, fallback = nil) ->
  value = nil
  for block in *Core.overrideBlockSpans text
    continue unless Core.looksLikeOverride block.inner
    i = 1
    while i <= #block.inner
      if block.inner\sub(i, i) == "\\"
        name = Core.tagNameAt block.inner, i
        if name
          valuePos = i + 1 + #name
          if block.inner\sub(valuePos, valuePos) == "("
            close = Core.balancedParenEnd block.inner, valuePos
            i = (close or valuePos) + 1
            continue
          if name == tag
            raw = block.inner\sub(valuePos)\match "^" .. numPattern
            value = tonumber(raw) or value if raw and raw != ""
          i = valuePos
          continue
      i += 1
  value or fallback

Core.ass_tag_names = {
  an: "align"
  fscx: "scale_x"
  fscy: "scale_y"
  fr: "angle"
  frz: "angle"
  frx: "angle_x"
  fry: "angle_y"
  fax: "shear_x"
  fay: "shear_y"
  fs: "fontsize"
  fsp: "spacing"
  b: "bold"
  i: "italic"
  u: "underline"
  s: "strikeout"
  bord: "outline"
  xbord: "outline_x"
  ybord: "outline_y"
  shad: "shadow"
  xshad: "shadow_x"
  yshad: "shadow_y"
  blur: "blur"
  be: "be"
}

Core.tagNumber = (value, fallback = nil) ->
  kind = type value
  return value and 1 or 0 if kind == "boolean"
  if kind == "number" or kind == "string"
    n = tonumber value
    return n if n != nil
  return fallback unless kind == "table"
  n = tonumber value.value
  return n if n != nil
  if value.getTagParams
    ok, raw = pcall -> value\getTagParams!
    n = tonumber raw if ok
    return n if n != nil
  if value.get
    ok, raw = pcall -> value\get!
    n = tonumber raw if ok
    return n if n != nil
  fallback

Core.effectiveLineState = (line, index = -1) ->
  state = {line: line, tags: {}}
  if ASS and line
    okData, data = pcall -> Core.parseAssLine line
    if okData and data
      state.data = data
      if data.getEffectiveTags
        okTags, tagList = pcall -> data\getEffectiveTags index, true, true, true
        if okTags and tagList
          state.tag_list = tagList
          state.tags = tagList.tags or {}
          styleRef = data.line and (data.line.styleRef or data.line.styleref) or line.styleRef or line.styleref
          if tagList.getStyleTable and type(styleRef) == "table"
            okStyle, style = pcall -> tagList\getStyleTable styleRef, line.style or styleRef.name, true
            state.style = style if okStyle and type(style) == "table"
  state.style or= Core.copyStyle(line and (line.styleRef or line.styleref)) or {}
  state

Core.styleValue = (line, key, fallback, state = nil) ->
  state or= Core.effectiveLineState line
  style = state and state.style or line and (line.styleref or line.styleRef) or {}
  tonumber(style[key]) or fallback

Core.lineTagValue = (line, tag, styleKey = nil, fallback = nil, state = nil) ->
  state or= Core.effectiveLineState line
  assName = Core.ass_tag_names[tag] or tag
  value = Core.tagNumber state and state.tags and state.tags[assName]
  return value if value != nil
  value = Core.numericTagValue line and line.text or "", tag
  return value if value != nil
  return Core.styleValue(line, styleKey, fallback, state) if styleKey
  fallback

Core.removeTagNames = (text, names) ->
  set = {}
  set[name] = true for name in *names
  mapped = Core.mapOverrideBlocks text, (inner) ->
    out, i = {}, 1
    while i <= #inner
      if inner\sub(i, i) == "\\"
        name = Core.tagNameAt inner, i
        if name
          valuePos = i + 1 + #name
          if inner\sub(valuePos, valuePos) == "("
            close = Core.balancedParenEnd inner, valuePos
            close = valuePos unless close
            unless set[name]
              out[#out + 1] = inner\sub i, close
            i = close + 1
            continue
          raw = inner\sub(valuePos)\match "^" .. numPattern
          if set[name] and raw and raw != ""
            i = valuePos + #raw
            continue
      out[#out + 1] = inner\sub i, i
      i += 1
    table.concat out
  Core.cleanEmptyOverrides mapped

Core.replaceOrInsertNumericTag = (text, tag, value) ->
  text = tostring(text or "")
  payload = "\\" .. tag .. Core.formatNum(value, 4)
  replaced = false
  newText = Core.mapOverrideBlocks text, (inner) ->
    return inner if replaced
    i = 1
    while i <= #inner
      if inner\sub(i, i) == "\\"
        name = Core.tagNameAt inner, i
        if name
          valuePos = i + 1 + #name
          if inner\sub(valuePos, valuePos) == "("
            close = Core.balancedParenEnd inner, valuePos
            i = (close or valuePos) + 1
            continue
          if name == tag
            raw = inner\sub(valuePos)\match "^" .. numPattern
            if raw and raw != ""
              replaced = true
              return inner\sub(1, i - 1) .. payload .. inner\sub(valuePos + #raw)
          i = valuePos
          continue
      i += 1
    inner
  return newText if replaced
  Core.insertLeadingTags text, payload

Core.scaleExistingNumericTag = (text, tag, factor, fallback = nil) ->
  found = false
  text = Core.mapOverrideBlocks text, (inner) ->
    out, i = {}, 1
    while i <= #inner
      if inner\sub(i, i) == "\\"
        name = Core.tagNameAt inner, i
        if name
          valuePos = i + 1 + #name
          if inner\sub(valuePos, valuePos) == "("
            close = Core.balancedParenEnd inner, valuePos
            close = valuePos unless close
            out[#out + 1] = inner\sub i, close
            i = close + 1
            continue
          if name == tag
            raw = inner\sub(valuePos)\match "^" .. numPattern
            if raw and raw != ""
              found = true
              out[#out + 1] = "\\" .. tag .. Core.formatNum((tonumber(raw) or 0) * factor, 4)
              i = valuePos + #raw
              continue
      out[#out + 1] = inner\sub i, i
      i += 1
    table.concat out
  if not found and fallback and math.abs(factor - 1) > 0.0001
    text = Core.insertLeadingTags text, "\\" .. tag .. Core.formatNum(fallback * factor, 4)
  text

Core.adjustTextByRatio = (line, ratio, opts) ->
  text = line.text or ""
  state = Core.effectiveLineState line
  axis = opts.axis
  if axis == "x" or axis == "both"
    base = Core.lineTagValue line, "fscx", "scale_x", 100, state
    text = Core.scaleExistingNumericTag text, "fscx", ratio, base if opts.adj_fscx
  if axis == "y" or axis == "both"
    base = Core.lineTagValue line, "fscy", "scale_y", 100, state
    text = Core.scaleExistingNumericTag text, "fscy", ratio, base if opts.adj_fscy
  text = Core.scaleExistingNumericTag text, "fs", ratio, Core.styleValue(line, "fontsize", 20, state) if opts.adj_fs
  text = Core.scaleExistingNumericTag text, "fsp", ratio, Core.styleValue(line, "spacing", 0, state) if opts.adj_fsp
  if opts.adj_bord
    text = Core.scaleExistingNumericTag text, "bord", ratio, Core.styleValue(line, "outline", 0, state)
    text = Core.scaleExistingNumericTag text, "xbord", ratio
    text = Core.scaleExistingNumericTag text, "ybord", ratio
  if opts.adj_shad
    text = Core.scaleExistingNumericTag text, "shad", ratio, Core.styleValue(line, "shadow", 0, state)
    text = Core.scaleExistingNumericTag text, "xshad", ratio
    text = Core.scaleExistingNumericTag text, "yshad", ratio
  if opts.adj_blur
    text = Core.scaleExistingNumericTag text, "blur", ratio
    text = Core.scaleExistingNumericTag text, "be", ratio
  text

Core.rectangleClipBoundsFromLine = (line) ->
  span = Core.firstClipSpan line and line.text
  return nil, "no_clip" unless span
  kind, _, payload = Core.clipInnerParts span.inner
  return Core.normalizeBounds(payload), nil if kind == "rect"
  return nil, "vector_clip" if kind == "vector"
  nil, "bad_clip"

Core.alignForLine = (line) ->
  n = math.floor(tonumber(Core.lineTagValue(line, "an", "align", 5)) or 5)
  if n >= 1 and n <= 9 then n else 5

Core.zfAlignForLine = (line) ->
  for block in *Core.overrideBlockSpans(line and line.text or "")
    if block.inner\find("\\an[1-9]") or block.inner\find("\\r", 1, true)
      return Core.alignForLine line
  n = math.floor(tonumber(line and line.styleref and line.styleref.align) or 0)
  return n if n >= 1 and n <= 9
  Core.alignForLine line

Core.leadingOverrideTags = (text) ->
  payload, cursor = {}, 1
  for block in *Core.overrideBlockSpans text
    break unless block.start == cursor
    payload[#payload + 1] = block.inner if Core.looksLikeOverride block.inner
    cursor = block.stop + 1
  table.concat payload

Core.prepareZfTextLine = (dlg, sourceLine, dropClip = true) ->
  work = Core.copyLine sourceLine
  work.styleref = Core.copyStyle work.styleref if work.styleref
  work.styleRef = Core.copyStyle work.styleRef if work.styleRef
  work.text = Core.stripClipTags work.text if dropClip
  leading = Core.leadingOverrideTags work.text
  work.text = "{" .. leading .. "}" .. work.text if leading != ""
  call = ZF.line(work)\prepoc dlg
  pers = dlg\getPerspectiveTags work
  source_align = Core.zfAlignForLine work
  align = source_align
  shape = ZF.util\isShape work.text
  multiline = work.text\find("\\N", 1, true) or work.text\find("\\n", 1, true)
  if not shape and not Core.lineNeedsProjectedQuad(work) and pers and pers.pos and not multiline
    width, height = tonumber(work.width), tonumber(work.height)
    if width and height and width > 0 and height > 0
      column = (source_align - 1) % 3
      row = math.floor (source_align - 1) / 3
      x = pers.pos[1] - (column == 1 and width / 2 or column == 2 and width or 0)
      y = pers.pos[2] - (row == 0 and height or row == 1 and height / 2 or 0)
      work.text = Core.removeTagNames work.text, {"an", "pos", "move"}
      work.text = Core.insertLeadingTags work.text, "\\an7\\pos(#{Core.formatNum x, 4},#{Core.formatNum y, 4})"
      call = ZF.line(work)\prepoc dlg
      pers = dlg\getPerspectiveTags work
      align = 7
  {:work, :call, :pers, :align, :source_align}

Core.anchorPointFromAlign = (align, bounds) ->
  left, top, right, bottom = unpack Core.normalizeBounds bounds
  an = math.floor(tonumber(align) or 5)
  an = 5 unless an >= 1 and an <= 9
  h = (an - 1) % 3
  v = math.floor (an - 1) / 3
  x = if h == 0 then left elseif h == 1 then (left + right) / 2 else right
  y = if v == 0 then bottom elseif v == 1 then (top + bottom) / 2 else top
  {:x, :y}

Core.rescaleTextDimensions = (line, fx, fy, opts) ->
  text = line.text or ""
  state = Core.effectiveLineState line
  fu = math.sqrt math.max(fx * fy, 0)
  fu = (fx + fy) / 2 if fu == 0
  if opts.adj_fscx
    base = Core.lineTagValue line, "fscx", "scale_x", 100, state
    text = Core.scaleExistingNumericTag text, "fscx", fx, base
  if opts.adj_fscy
    base = Core.lineTagValue line, "fscy", "scale_y", 100, state
    text = Core.scaleExistingNumericTag text, "fscy", fy, base
  text = Core.scaleExistingNumericTag text, "fsp", fx, Core.styleValue(line, "spacing", 0, state) if opts.adj_fsp
  if opts.adj_bord
    text = Core.scaleExistingNumericTag text, "bord", fu, Core.styleValue(line, "outline", 0, state)
    text = Core.scaleExistingNumericTag text, "xbord", fx
    text = Core.scaleExistingNumericTag text, "ybord", fy
  if opts.adj_shad
    text = Core.scaleExistingNumericTag text, "shad", fu, Core.styleValue(line, "shadow", 0, state)
    text = Core.scaleExistingNumericTag text, "xshad", fx
    text = Core.scaleExistingNumericTag text, "yshad", fy
  if opts.adj_blur
    text = Core.scaleExistingNumericTag text, "blur", fu
    text = Core.scaleExistingNumericTag text, "be", fu
  text

Core.rescaleLineByRectangleClip = (dlg, line, opts) ->
  rect, err = Core.rectangleClipBoundsFromLine line
  return nil, err unless rect
  left, top, right, bottom = unpack rect
  clipW, clipH = right - left, bottom - top
  return nil, "bad_clip" unless clipW > 0 and clipH > 0
  shape = Core.buildTextBounds dlg, line, opts
  return nil, "no_text" unless shape and shape.w and shape.h and shape.w > 0 and shape.h > 0
  fx, fy = clipW / shape.w, clipH / shape.h
  if opts.rescale_rect_mode == "Fit (uniform)"
    f = math.min fx, fy
    fx, fy = f, f
  elseif opts.rescale_rect_mode == "Fill (uniform)"
    f = math.max fx, fy
    fx, fy = f, f
  text = Core.rescaleTextDimensions line, fx, fy, opts
  if opts.recenter and not text\find "\\move%("
    align = shape.align or Core.alignForLine line
    anchor = Core.anchorPointFromAlign align, rect
    text = Core.replacePosOrInsert text, anchor.x, anchor.y
  text = Core.stripClipTags text if opts.remove_clip
  text, nil, {fx: fx, fy: fy, rect: rect, text_w: shape.w, text_h: shape.h}

Core.transformClipRulerText = (line, seg1, seg2, opts) ->
  d1, d2 = Core.segmentLength(seg1), Core.segmentLength(seg2)
  return nil, nil, "zero" if d1 == 0
  ratio = d2 / d1
  axis = opts.axis == "y" and "y" or "x"
  scaleTag = axis == "y" and "fscy" or "fscx"
  styleKey = axis == "y" and "scale_y" or "scale_x"
  base = Core.lineTagValue line, scaleTag, styleKey, 100
  startTags = "\\" .. scaleTag .. Core.formatNum(base, 4)
  finalTags = "\\" .. scaleTag .. Core.formatNum(base * ratio, 4)
  if opts.angle_mode == "first angle" or opts.angle_mode == "transform angle"
    startTags ..= "\\frz" .. Core.formatNum(Core.segmentFrz(seg1), 2)
  if opts.angle_mode == "transform angle"
    finalTags ..= "\\frz" .. Core.formatNum(Core.segmentFrz(seg2), 2)
  dur = math.max 0, (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0)
  payload = startTags .. "\\t(0," .. tostring(dur) .. "," .. finalTags .. ")"
  Core.insertLeadingTags(line.text or "", payload), {d1: d1, d2: d2, ratio: ratio, a1: Core.segmentFrz(seg1), a2: Core.segmentFrz(seg2)}

Core.singleCubicBezier = (cmds) ->
  return nil unless cmds and #cmds == 2
  move, bezier = cmds[1], cmds[2]
  return nil unless move.type == "m" and #move.pts >= 2
  return nil unless bezier.type == "b" and #bezier.pts == 6
  curve = {
    Core.pointXy move.pts[1], move.pts[2]
    Core.pointXy bezier.pts[1], bezier.pts[2]
    Core.pointXy bezier.pts[3], bezier.pts[4]
    Core.pointXy bezier.pts[5], bezier.pts[6]
  }
  return nil if Core.samePoint curve[1], curve[4]
  curve

Core.cleanCurveModel = (curve) ->
  return nil unless curve and #curve == 4
  p0, p1, p2, p3 = curve[1], curve[2], curve[3], curve[4]
  dx, dy = p3.x - p0.x, p3.y - p0.y
  chord = math.sqrt dx * dx + dy * dy
  return nil unless chord > geometryEpsilon
  nx, ny = -dy / chord, dx / chord
  samples, total = Core.bezierArclengthSamples p0, p1, p2, p3, bezierArclengthSegments
  return nil unless samples and total and total > geometryEpsilon

  depths = {}
  for s in *{0.35, 0.425, 0.5, 0.575, 0.65}
    t = Core.bezierTAtDistance samples, total * s
    point = Core.bezierPoint t, p0, p1, p2, p3
    arch = 4 * s * (1 - s)
    continue unless arch > numericEpsilon
    baseX, baseY = p0.x + dx * s, p0.y + dy * s
    offset = (point.x - baseX) * nx + (point.y - baseY) * ny
    depths[#depths + 1] = offset / arch
  return nil if #depths == 0
  table.sort depths
  middle = math.floor((#depths + 1) / 2)
  sagitta = depths[middle]
  sagitta = 0 if math.abs(sagitta) < 0.5
  {
    chord: chord
    chord_angle: Core.atan2 dy, dx
    sagitta: sagitta
  }

Core.cleanCurveFrz = (model, s, depthPercent = 100) ->
  s = Core.clamp tonumber(s) or 0, 0, 1
  scale = (tonumber(depthPercent) or 100) / 100
  depth = model.sagitta * scale
  halfSweep = 2 * Core.atan2(2 * depth, model.chord)
  halfSweep *= sameLineCurveCompensation
  tangent = model.chord_angle + halfSweep * (1 - 2 * s)
  -math.deg tangent

Core.hasCurveTransform = (text) ->
  for block in *Core.overrideBlockSpans text
    continue unless Core.looksLikeOverride block.inner
    for payload in block.inner\gmatch "\\t(%b())"
      return true if payload\find("\\frz", 1, true) or payload\find("\\fsp", 1, true)
      pos = 1
      while true
        pos = payload\find "\\fr", pos, true
        break unless pos
        nextChar = payload\sub pos + 3, pos + 3
        return true if nextChar\match "[%+%-%.%d]"
        pos += 3
  false

Core.hasDrawingMode = (text) ->
  for block in *Core.overrideBlockSpans text
    continue unless Core.looksLikeOverride block.inner
    for value in block.inner\gmatch "\\p(%d+)"
      return true if (tonumber(value) or 0) > 0
  false

Core.curvedTextFromBezier = (line, opts = {}) ->
  source = line and line.text or ""
  return nil, "drawing" if Core.hasDrawingMode source
  return nil, "transform" if Core.hasCurveTransform source
  cmds = Core.firstClipCommands source
  curve = Core.singleCubicBezier cmds
  return nil, "bezier" unless curve
  model = Core.cleanCurveModel curve
  return nil, "bezier" unless model

  state = Core.effectiveLineState line
  baseSpacing = Core.lineTagValue(line, "fsp", "spacing", 0, state) or 0
  spacing = baseSpacing + (tonumber(opts.curve_spacing) or 0)
  text = Core.removeTagNames source, {"fr", "frz", "fsp"}
  text = Core.stripClipTags text if opts.remove_clip
  units, unitError = Core.curveCharUnits text
  return nil, unitError unless units
  visible = 0
  visible += 1 for unit in *units when unit.insert
  return nil, "text" if visible == 0

  inserts = {}
  for index, unit in ipairs units
    continue unless unit.insert
    ratio = if #units == 1 then 0.5 else (index - 1) / (#units - 1)
    frz = Core.cleanCurveFrz model, ratio, opts.curve_depth
    tag = "{\\frz" .. Core.formatNum(frz, 2) .. "\\fsp" .. Core.formatNum(spacing, 2) .. "}"
    inserts[#inserts + 1] = {pos: unit.start, tag: tag}
  Core.insertTagsAtSpans(text, inserts), nil, {characters: visible, spacing: spacing, depth: model.sagitta}

Core.measureReport = (label, seg1, seg2) ->
  d1, d2 = Core.segmentLength(seg1), Core.segmentLength(seg2)
  ratio = if d1 == 0 then 0 else d2 / d1
  if current_language == "es"
    table.concat {
      label
      "Primero: #{Core.formatNum d1, 2} px @ #{Core.formatNum Core.segmentFrz(seg1), 2} deg"
      "Segundo: #{Core.formatNum d2, 2} px @ #{Core.formatNum Core.segmentFrz(seg2), 2} deg"
      "Cambio: #{Core.formatNum (ratio - 1) * 100, 2}%"
    }, "\n"
  else
    table.concat {
      label
      "First: #{Core.formatNum d1, 2} px @ #{Core.formatNum Core.segmentFrz(seg1), 2} deg"
      "Second: #{Core.formatNum d2, 2} px @ #{Core.formatNum Core.segmentFrz(seg2), 2} deg"
      "Change: #{Core.formatNum (ratio - 1) * 100, 2}%"
    }, "\n"

Core.opMeasure = (subs, sel, opts) ->
  reports = {}
  for n, i in ipairs Core.dialogueIndices(subs, sel)
    cmds = Core.firstClipCommands subs[i].text
    if cmds
      segs = Core.firstPathSegments cmds, 2, 8
      if #segs >= 2
        reports[#reports + 1] = Core.measureReport "#{Core.L('line')} #{i}", segs[1], segs[2]
  if #reports == 0
    Core.showMessage "No vector clip with two usable segments was found."
    return false
  Core.showMessage table.concat(reports, "\n\n"), "Measure clip"
  true

Core.opMeasureTransform = (subs, sel, opts) ->
  changed, reports = 0, {}
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    cmds = Core.firstClipCommands line.text
    continue unless cmds
    segs = Core.firstPathSegments cmds, 2, 8
    continue unless #segs >= 2
    next_text = Core.transformClipRulerText line, segs[1], segs[2], opts
    if next_text and next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
      reports[#reports + 1] = Core.measureReport "#{Core.L('line')} #{i}", segs[1], segs[2]
  if changed == 0
    Core.showMessage "No line was transformed."
    return false
  aegisub.set_undo_point "Cliptomaniac - Measure transform"
  Core.showMessage table.concat(reports, "\n\n"), "Measure & transform clip" if opts.info
  true

Core.opAdjustByClipScale = (subs, sel, opts) ->
  seg1, seg2 = Core.clipScaleReference subs, sel
  unless seg1 and seg2
    Core.showMessage "Select two clipped lines, or one vector clip with two m-l strokes."
    return false
  d1, d2 = Core.segmentLength(seg1), Core.segmentLength(seg2)
  if d1 == 0
    Core.showMessage "First clip segment has zero length."
    return false
  ratio = d2 / d1
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    next_text = Core.adjustTextByRatio line, ratio, opts
    if next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No numeric tags changed."
    return false
  aegisub.set_undo_point "Cliptomaniac - Adjust by clip scale"
  if opts.info
    message = if current_language == "es" then "Proporción #{Core.formatNum ratio * 100, 2}% aplicada a #{changed} línea(s)." else "Ratio #{Core.formatNum ratio * 100, 2}% applied to #{changed} line(s)."
    Core.showMessage message, "Adjust by clip scale"
  true

Core.opRescaleByRectangleClip = (subs, sel, opts) ->
  unless ZF
    Core.showMessage "Shape tools are not available."
    return false
  dlg = nil
  okDlg, value = pcall -> ZF.dialog subs, sel, nil, false
  dlg = value if okDlg
  unless dlg
    Core.showMessage "Could not prepare text bounds."
    return false
  changed, skipped = 0, 0
  reasons, reports = {}, {}
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    next_text, err, meta = Core.rescaleLineByRectangleClip dlg, line, opts
    if next_text and next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
      reports[#reports + 1] = "#{Core.L('line')} #{i}: x #{Core.formatNum(meta.fx * 100, 2)}%, y #{Core.formatNum(meta.fy * 100, 2)}%"
    else
      skipped += 1
      reasons[err or "unchanged"] = (reasons[err or "unchanged"] or 0) + 1
  if changed == 0
    details = {}
    if current_language == "es"
      details[#details + 1] = "Esta operacion solo acepta \\clip(x1,y1,x2,y2) o \\iclip(x1,y1,x2,y2) rectangular."
      details[#details + 1] = "Los clips vectoriales se rechazan intencionalmente." if reasons.vector_clip
    else
      details[#details + 1] = "This operation only accepts rectangular \\clip(x1,y1,x2,y2) or \\iclip(x1,y1,x2,y2)."
      details[#details + 1] = "Vector clips are intentionally rejected." if reasons.vector_clip
    details[#details + 1] = Core.messageText("No rectangular clip was found.") if reasons.no_clip
    details[#details + 1] = Core.messageText("Text bounds could not be measured.") if reasons.no_text
    Core.showMessage table.concat(details, "\n"), "Rescale by rectangle clip"
    return false
  aegisub.set_undo_point "Cliptomaniac - Rescale by rectangle clip"
  if opts.info
    summary = if current_language == "es" then "Cambiadas #{changed} línea(s), omitidas #{skipped}." else "Changed #{changed} line(s), skipped #{skipped}."
    summary ..= "\n\n" .. table.concat(reports, "\n") if #reports > 0
    Core.showMessage summary, "Rescale by rectangle clip"
  true

Core.curveErrorMessage = (reason) ->
  switch reason
    when "multiline" then "Curved text must stay on one visual line."
    when "drawing" then "Curved text only accepts text, not \\p drawings."
    when "transform" then "Remove animated \\fr/\\frz/\\fsp transforms before curving the text."
    when "text" then "No visible text was found to curve."
    else "Use exactly one cubic Bezier clip: \\clip(m x y b x1 y1 x2 y2 x3 y3)."

Core.opBezierClipToCurvedText = (subs, sel, opts) ->
  changed, reasons = 0, {}
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    next_text, reason = Core.curvedTextFromBezier line, opts
    unless next_text
      reasons[reason or "bezier"] = (reasons[reason or "bezier"] or 0) + 1
      continue
    if next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    reason = nil
    for candidate in *{"multiline", "drawing", "transform", "text", "bezier"}
      if reasons[candidate]
        reason = candidate
        break
    Core.showMessage Core.curveErrorMessage(reason)
    return false
  aegisub.set_undo_point "Cliptomaniac - Bezier clip to curved text"
  true

Core.positionTextAt = (text, x, y) ->
  text = Core.removeTagNames text, {"move"}
  Core.replacePosOrInsert text, x, y

Core.opPositionAtClipMidpoint = (subs, sel, opts) ->
  _, guideSpan = Core.firstClipPathReference subs, sel
  fallback = Core.clipMidpointFromSpan guideSpan
  unless fallback
    Core.showMessage "No usable clip midpoint found."
    return false
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    point = Core.clipMidpointForLine line, fallback
    continue unless point
    next_text = Core.positionTextAt line.text or "", point.x, point.y
    if next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No line position changed."
    return false
  aegisub.set_undo_point "Cliptomaniac - Position at clip midpoint"
  true

Core.firstSegmentForLine = (line) ->
  cmds = Core.firstClipCommands line.text
  return nil unless cmds
  segs = Core.firstPathSegments cmds, 1, 8
  segs[1]

Core.replaceOrInsertParenthesizedTag = (text, name, payload) ->
  replaced = false
  newText = Core.mapOverrideBlocks text, (inner) ->
    return inner if replaced
    i = 1
    while i <= #inner
      if inner\sub(i, i) == "\\"
        tagName = Core.tagNameAt inner, i
        if tagName
          valuePos = i + 1 + #tagName
          if inner\sub(valuePos, valuePos) == "("
            close = Core.balancedParenEnd inner, valuePos
            if tagName == name and close
              replaced = true
              return inner\sub(1, i - 1) .. payload .. inner\sub(close + 1)
            i = (close or valuePos) + 1
            continue
      i += 1
    inner
  return newText if replaced
  Core.insertLeadingTags text, payload

Core.replacePosOrInsert = (text, x, y) ->
  tag = "\\pos(" .. Core.formatNum(x, 2) .. "," .. Core.formatNum(y, 2) .. ")"
  Core.replaceOrInsertParenthesizedTag text, "pos", tag

Core.firstPosXy = (text) ->
  for block in *Core.overrideBlockSpans text
    continue unless Core.looksLikeOverride block.inner
    x, y = block.inner\match "\\pos%(%s*(" .. numPattern .. ")%s*,%s*(" .. numPattern .. ")%s*%)"
    return tonumber(x), tonumber(y) if x and y
  nil, nil

Core.replaceFirstPosWithMove = (text, moveTag) ->
  replaced = false
  out = Core.mapOverrideBlocks text, (inner) ->
    return inner if replaced
    nextInner, count = inner\gsub "\\pos%b()", moveTag, 1
    if count > 0
      replaced = true
      nextInner
    else
      inner
  out, replaced

Core.shiftPair = (x, y, dx, dy) ->
  Core.formatNum((tonumber(x) or 0) + dx, 2), Core.formatNum((tonumber(y) or 0) + dy, 2)

Core.shiftPath = (path, dx, dy) ->
  tostring(path or "")\gsub "(" .. numPattern .. ")%s+(" .. numPattern .. ")", (x, y) ->
    nx, ny = Core.shiftPair x, y, dx, dy
    nx .. " " .. ny

Core.shiftGeometryText = (text, dx, dy, line = nil) ->
  text = tostring(text or "")
  shiftedAnchor = false
  text = Core.mapOverrideBlocks text, (inner) ->
    inner = inner\gsub "\\pos%(%s*(" .. numPattern .. ")%s*,%s*(" .. numPattern .. ")%s*%)", (x, y) ->
      shiftedAnchor = true
      nx, ny = Core.shiftPair x, y, dx, dy
      "\\pos(#{nx},#{ny})"
    inner = inner\gsub "\\move%(%s*(" .. numPattern .. ")%s*,%s*(" .. numPattern .. ")%s*,%s*(" .. numPattern .. ")%s*,%s*(" .. numPattern .. ")(.-)%)", (x1, y1, x2, y2, rest) ->
      shiftedAnchor = true
      nx1, ny1 = Core.shiftPair x1, y1, dx, dy
      nx2, ny2 = Core.shiftPair x2, y2, dx, dy
      "\\move(#{nx1},#{ny1},#{nx2},#{ny2}#{rest})"
    inner\gsub "\\org%(%s*(" .. numPattern .. ")%s*,%s*(" .. numPattern .. ")%s*%)", (x, y) ->
      nx, ny = Core.shiftPair x, y, dx, dy
      "\\org(#{nx},#{ny})"
  text = Core.mapClipTags text, (span) ->
    kind, scale, payload = Core.clipInnerParts span.inner
    if kind == "rect"
      b = Core.padBounds(payload, 0)
      "\\#{span.name}(#{Core.formatNum b[1] + dx, 2},#{Core.formatNum b[2] + dy, 2},#{Core.formatNum b[3] + dx, 2},#{Core.formatNum b[4] + dy, 2})"
    elseif kind == "vector"
      "\\#{span.name}(#{Core.vectorInnerWithScale(Core.shiftPath(payload, dx, dy), scale)})"
    else
      span.raw
  unless shiftedAnchor or not line
    point = PerspectiveTools.defaultPosition line
    text = Core.replacePosOrInsert text, point.x + dx, point.y + dy if point
  text

Core.opClipToFrz = (subs, sel, opts) ->
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    seg = Core.firstSegmentForLine line
    continue unless seg
    text = Core.replaceOrInsertNumericTag line.text, "frz", Core.segmentFrz(seg)
    text = Core.stripClipTags text if opts.remove_clip
    if text != line.text
      line.text = text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No usable vector clip found."
    return false
  aegisub.set_undo_point "Cliptomaniac - Clip to FRZ"
  true

Core.opClipToFax = (subs, sel, opts) ->
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    seg = Core.firstSegmentForLine line
    continue unless seg
    state = Core.effectiveLineState line
    frz = Core.lineTagValue(line, "frz", "angle", 0, state) or 0
    scx = Core.lineTagValue(line, "fscx", "scale_x", 100, state) or 100
    scy = Core.lineTagValue(line, "fscy", "scale_y", 100, state) or 100
    ratio = if scy == 0 then 1 else scx / scy
    line_angle = Core.segmentFrz seg
    fax = math.tan(math.rad(line_angle - frz)) / ratio
    unless Core.finiteNumber(fax) and math.abs(math.cos(math.rad(line_angle - frz))) > numericEpsilon
      Core.warn "Line #{i}: skipped unstable FAX value from angle #{Core.formatNum(line_angle - frz, 2)}."
      continue
    text = Core.replaceOrInsertNumericTag line.text, "fax", fax
    text = Core.stripClipTags text if opts.remove_clip
    if text != line.text
      line.text = text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No usable vector clip found."
    return false
  aegisub.set_undo_point "Cliptomaniac - Clip to FAX"
  true

Core.opClipToFay = (subs, sel, opts) ->
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    seg = Core.firstSegmentForLine line
    continue unless seg
    state = Core.effectiveLineState line
    frz = Core.lineTagValue(line, "frz", "angle", 0, state) or 0
    scx = Core.lineTagValue(line, "fscx", "scale_x", 100, state) or 100
    scy = Core.lineTagValue(line, "fscy", "scale_y", 100, state) or 100
    ratio = if scy == 0 then 1 else scx / scy
    line_angle = Core.segmentFrz seg
    fay = math.tan(math.rad(line_angle + 90 - frz)) * ratio
    unless Core.finiteNumber(fay) and math.abs(math.cos(math.rad(line_angle + 90 - frz))) > numericEpsilon
      Core.warn "Line #{i}: skipped unstable FAY value from angle #{Core.formatNum(line_angle + 90 - frz, 2)}."
      continue
    text = Core.replaceOrInsertNumericTag line.text, "fay", fay
    text = Core.stripClipTags text if opts.remove_clip
    if text != line.text
      line.text = text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No usable vector clip found."
    return false
  aegisub.set_undo_point "Cliptomaniac - Clip to FAY"
  true

Core.opClipToReposition = (subs, sel, opts) ->
  indices = Core.dialogueIndices subs, sel
  guide, guideIndex = nil, nil
  for i in *indices
    candidate = Core.trackingSegmentForLine subs[i]
    if candidate and candidate.kind == "l"
      guide, guideIndex = candidate, i
      break
  unless guide
    Core.showMessage "No usable vector clip found."
    return false
  dx, dy = guide.x2 - guide.x1, guide.y2 - guide.y1
  changed = 0
  for i in *indices
    line = subs[i]
    sourceText = line.text or ""
    if i == guideIndex and opts.remove_clip
      sourceText = sourceText\sub(1, guide.span.start - 1) .. sourceText\sub(guide.span.stop + 1)
    text = Core.shiftGeometryText sourceText, dx, dy, line
    if text != line.text
      line.text = text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No position or clip geometry changed."
    return false
  aegisub.set_undo_point "Cliptomaniac - Clip to reposition"
  true

Core.opClipToMove = (subs, sel, opts) ->
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    seg = Core.firstSegmentForLine line
    continue unless seg
    x, y = Core.firstPosXy line.text
    continue unless x and y
    dx, dy = seg.x2 - seg.x1, seg.y2 - seg.y1
    move = "\\move(#{Core.formatNum x, 2},#{Core.formatNum y, 2},#{Core.formatNum x + dx, 2},#{Core.formatNum y + dy, 2})"
    text = Core.removeTagNames line.text, {"move"}
    text = Core.replaceFirstPosWithMove text, move
    text = Core.stripClipTags text if opts.remove_clip
    if text != line.text
      line.text = text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No selected line had both \\pos and a usable clip segment."
    return false
  aegisub.set_undo_point "Cliptomaniac - Clip to move"
  true

Core.opAlignToClip = (subs, sel, opts) ->
  globalCmds = nil
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    globalCmds = Core.firstClipCommands subs[i].text
    break if globalCmds
  unless globalCmds
    Core.showMessage "No vector clip found for alignment."
    return false
  globalSegments = Core.pathSegments globalCmds, 40
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    px, py = Core.firstPosXy line.text
    continue unless px and py
    localCmds = Core.firstClipCommands line.text
    segments = if localCmds then Core.pathSegments(localCmds, 40) else globalSegments
    segments = globalSegments if #segments == 0
    bestDist, bestX, bestY = math.huge, px, py
    for seg in *segments
      d, bx, by = Core.distanceToSegment px, py, seg.x1, seg.y1, seg.x2, seg.y2
      if d < bestDist
        bestDist, bestX, bestY = d, bx, by
    if bestDist < math.huge
      line.text = Core.positionTextAt line.text, bestX, bestY
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No selected line with \\pos could be aligned."
    return false
  aegisub.set_undo_point "Cliptomaniac - Align to clip"
  true

Core.clipVectorPartsForOutput = (span) ->
  kind, scale, payload = Core.clipInnerParts span.inner
  return kind, payload, scale

Core.hotkeyText = (text, op, opts = {}) ->
  Core.mapClipTags text, (span) ->
    kind, payload, scale = Core.clipVectorPartsForOutput span
    switch op
      when "Toggle clip/iclip"
        Core.clipTagText span.name == "clip" and "iclip" or "clip", span.inner
      when "Calibrate clip X"
        return span.raw unless kind == "vector"
        path = tostring(payload or "")\gsub "([mM])%s+(" .. numPattern .. ")%s+(" .. numPattern .. ")%s+([lL])%s+(" .. numPattern .. ")%s+(" .. numPattern .. ")", (m, x1, y1, l, x2, y2) ->
          "#{m} #{Core.formatNum x1} #{Core.formatNum y1} #{l} #{Core.formatNum x2} #{Core.formatNum y1}"
        Core.clipTagText span.name, Core.vectorInnerWithScale(path, scale)
      when "Calibrate clip Y"
        return span.raw unless kind == "vector"
        path = tostring(payload or "")\gsub "([mM])%s+(" .. numPattern .. ")%s+(" .. numPattern .. ")%s+([lL])%s+(" .. numPattern .. ")%s+(" .. numPattern .. ")", (m, x1, y1, l, x2, y2) ->
          "#{m} #{Core.formatNum x1} #{Core.formatNum y1} #{l} #{Core.formatNum x1} #{Core.formatNum y2}"
        Core.clipTagText span.name, Core.vectorInnerWithScale(path, scale)
      when "Rectangle from diagonal"
        return span.raw unless kind == "vector"
        segs = Core.firstPathSegments(Core.parseDrawCommands(payload), 1, 1)
        return span.raw unless segs[1]
        s = segs[1]
        path = "m #{Core.formatNum s.x1} #{Core.formatNum s.y1} l #{Core.formatNum s.x2} #{Core.formatNum s.y1} #{Core.formatNum s.x2} #{Core.formatNum s.y2} #{Core.formatNum s.x1} #{Core.formatNum s.y2}"
        Core.clipTagText span.name, Core.vectorInnerWithScale(path, scale)
      when "Circle from 2 points"
        return span.raw unless kind == "vector"
        segs = Core.firstPathSegments(Core.parseDrawCommands(payload), 1, 1)
        return span.raw unless segs[1]
        s = segs[1]
        cx, cy = (s.x1 + s.x2) / 2, (s.y1 + s.y2) / 2
        r = Core.segmentLength(s) / 2
        return span.raw if r <= 0
        k = 0.5522847498307936
        path = table.concat {
          "m #{Core.formatNum cx - r} #{Core.formatNum cy}"
          "b #{Core.formatNum cx - r} #{Core.formatNum cy - k * r} #{Core.formatNum cx - k * r} #{Core.formatNum cy - r} #{Core.formatNum cx} #{Core.formatNum cy - r}"
          "b #{Core.formatNum cx + k * r} #{Core.formatNum cy - r} #{Core.formatNum cx + r} #{Core.formatNum cy - k * r} #{Core.formatNum cx + r} #{Core.formatNum cy}"
          "b #{Core.formatNum cx + r} #{Core.formatNum cy + k * r} #{Core.formatNum cx + k * r} #{Core.formatNum cy + r} #{Core.formatNum cx} #{Core.formatNum cy + r}"
          "b #{Core.formatNum cx - k * r} #{Core.formatNum cy + r} #{Core.formatNum cx - r} #{Core.formatNum cy + k * r} #{Core.formatNum cx - r} #{Core.formatNum cy}"
        }, " "
        Core.clipTagText span.name, Core.vectorInnerWithScale(path, scale)
      when "New clip shape"
        return span.raw unless kind == "vector"
        path = Core.newShapeSplitPath payload
        return span.raw unless path
        Core.clipTagText span.name, Core.vectorInnerWithScale(path, scale)
      when "Add clip points"
        path = if kind == "rect" then Core.vectorClipInner(Core.rectPoints(payload)) else payload
        return span.raw unless path
        path, added = Core.densifyClipPath path, opts
        return span.raw unless path and added > 0
        Core.clipTagText span.name, Core.vectorInnerWithScale(path, scale)
      when "Remove clip points"
        path = if kind == "rect" then Core.vectorClipInner(Core.rectPoints(payload)) else payload
        return span.raw unless path
        path, changed = Core.removeAlternateClipPointsPath path
        return span.raw unless path and changed
        Core.clipTagText span.name, Core.vectorInnerWithScale(path, scale)
      when "Rect clip to vector"
        return span.raw unless kind == "rect"
        b = Core.normalizeBounds payload
        Core.clipTagText span.name, Core.vectorClipInner Core.rectPoints b
      when "Vector clip to rect"
        bounds = Core.clipBoundsFromSpan span
        return span.raw unless bounds
        Core.rectClipTag bounds, span.name
      else
        span.raw

Core.opHotkey = (subs, sel, op, opts = {}) ->
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    next_text, c = Core.hotkeyText line.text, op, opts
    if c > 0 and next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    if op == "Add clip points" or op == "Remove clip points"
      Core.showMessage "No clip points changed."
      return false
    Core.showMessage "No editable clip found."
    return false
  aegisub.set_undo_point "Cliptomaniac - #{op}"
  true

Core.selectionCopyGroups = (subs, sel) ->
  groups, order = {}, {}
  for i in *(sel or {})
    line = subs[i]
    if Core.isDialogue line
      key = "effect:" .. Core.trim(line.effect or "")
      group = groups[key]
      unless group
        group = {source: i, targets: {}, indices: {i}}
        groups[key] = group
        order[#order + 1] = group
      else
        group.targets[#group.targets + 1] = i
        group.indices[#group.indices + 1] = i
  usable = {}
  for group in *order
    usable[#usable + 1] = group if #group.targets > 0
  if #usable == 0
    indices = Core.dialogueIndices subs, sel
    if #indices >= 2
      targets = {}
      for n = 2, #indices
        targets[#targets + 1] = indices[n]
      usable[1] = {source: indices[1], targets: targets, indices: indices}
  usable

Core.replaceFirstClip = (text, replacement) ->
  span = Core.firstClipSpan text
  if span
    return text\sub(1, span.start - 1) .. replacement .. text\sub(span.stop + 1)
  Core.insertLeadingTags text, replacement

Core.opCopyClip = (subs, sel, opts) ->
  changed = 0
  for group in *Core.selectionCopyGroups(subs, sel)
    src = subs[group.source]
    span = src and Core.firstClipSpan(src.text)
    continue unless span
    for i in *group.targets
      line = subs[i]
      next_text = Core.replaceFirstClip line.text or "", span.raw
      if next_text != line.text
        line.text = next_text
        subs[i] = line
        changed += 1
  if changed == 0
    Core.showMessage "No source/target clip group found."
    return false
  aegisub.set_undo_point "Cliptomaniac - Copy clip"
  true

Core.shapeInfo = (drawing) ->
  return nil, "Shape tools are not available." unless ZF and ZF.shape
  ok, shape = pcall -> ZF.shape drawing
  return nil, tostring(shape) unless ok and shape
  return nil, "Empty shape." unless shape.w and shape.h and shape.w > 0 and shape.h > 0
  shape

Core.boundsFromPath = (drawing) ->
  Core.clipBoundsFromSpan {inner: drawing, name: "clip"}

Core.shapeBounds = (shape, drawing = nil) ->
  return nil unless shape
  l, t = tonumber(shape.l), tonumber(shape.t)
  r, b = tonumber(shape.r), tonumber(shape.b)
  w, h = tonumber(shape.w), tonumber(shape.h)
  if l and t and r and b
    return Core.normalizeBounds {l, t, r, b}
  if l and t and w and h
    return Core.normalizeBounds {l, t, l + w, t + h}
  if drawing
    return Core.boundsFromPath drawing
  nil

Core.buildShapeText = (shape) ->
  Core.trim shape\build!

Core.moveDrawing = (drawing, dx, dy) ->
  shape, err = Core.shapeInfo drawing
  return nil, err unless shape
  Core.buildShapeText shape\move(dx or 0, dy or 0)

Core.scalePathFromCenter = (path, margin) ->
  bounds = Core.clipBoundsFromSpan {inner: path, name: "clip"}
  return path unless bounds
  left, top, right, bottom = unpack bounds
  cx, cy = (left + right) / 2, (top + bottom) / 2
  halfW, halfH = math.max((right - left) / 2, 0.001), math.max((bottom - top) / 2, 0.001)
  fx, fy = (halfW + margin) / halfW, (halfH + margin) / halfH
  tostring(path or "")\gsub "(" .. numPattern .. ")%s+(" .. numPattern .. ")", (x, y) ->
    x, y = tonumber(x), tonumber(y)
    "#{Core.formatNum cx + (x - cx) * fx} #{Core.formatNum cy + (y - cy) * fy}"

Core.expandVectorPath = (path, margin, tolerance) ->
  if ZF and ZF.clipper
    ok, expanded = pcall ->
      ZF.clipper(path, nil, true)\offset(margin, "Miter", nil, 2, 0.25)\build "line", math.max(1, tonumber(tolerance) or 1)
    return Core.trim expanded if ok and expanded and Core.trim(expanded) != ""
  Core.scalePathFromCenter path, margin

Core.simplifyVectorPath = (path, tolerance, close_paths = true) ->
  tolerance = math.max 1, tonumber(tolerance) or 1
  return Core.trim path if tolerance <= 1 or not (ZF and ZF.clipper)
  ok, simplified = pcall -> ZF.clipper(path, nil, close_paths)\simplify!\build "line", tolerance
  if ok and simplified and Core.trim(simplified) != "" then Core.trim simplified else Core.trim path

Core.opExpandClipMargin = (subs, sel, opts) ->
  margin = tonumber(opts.margin) or 0
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    next_text, c = Core.mapClipTags line.text, (span) ->
      kind, scale, payload = Core.clipInnerParts span.inner
      if kind == "rect"
        Core.rectClipTag Core.padBounds(payload, margin), span.name
      elseif kind == "vector"
        Core.clipTagText span.name, Core.vectorInnerWithScale(Core.expandVectorPath(payload, margin, opts.tolerance), scale)
      else
        span.raw
    if c > 0 and next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No clip was expanded."
    return false
  aegisub.set_undo_point "Cliptomaniac - Expand clip margin"
  true

Core.transformBoundsRequested = (line, opts = {}) ->
  opts.transform_max_bounds and Core.hasTransformTag(line and line.text or "")

Core.removeMeasurementClips = (data) ->
  data\removeTags clipTagNames
  for transform in *(data\getTags("transform") or {})
    if transform.tags and transform.tags.removeTags
      transform.tags\removeTags clipTagNames
  data

Core.renderedTransformBounds = (sourceLine, opts = {}) ->
  return nil unless ASS and Core.transformBoundsRequested sourceLine, opts
  return nil unless Core.videoLoaded!
  ok, result = pcall ->
    data = Core.parseAssLine sourceLine
    Core.removeMeasurementClips data
    data.isAnimated = -> true
    bounds = data\getLineBounds false, true
    first, last = Core.matrixPoint(bounds and bounds[1]), Core.matrixPoint(bounds and bounds[2])
    return nil unless first and last
    video_x, video_y = Core.videoResolution!
    playX, playY = Core.scriptResolution sourceLine, data
    scale_x = (playX or video_x) / video_x
    scale_y = (playY or video_y) / video_y
    rect = Core.normalizeBounds {first.x * scale_x, first.y * scale_y, last.x * scale_x, last.y * scale_y}
    return nil unless rect[3] > rect[1] and rect[4] > rect[2]
    {
      l: rect[1]
      t: rect[2]
      r: rect[3]
      b: rect[4]
      w: rect[3] - rect[1]
      h: rect[4] - rect[2]
      align: Core.alignForLine sourceLine
      rendered: true
      line_bounds: bounds
    }
  unless ok
    Core.warn "Could not inspect transformed text bounds: #{result}"
    return nil
  result

Core.buildTextBounds = (dlg, sourceLine, opts = {}) ->
  if Core.transformBoundsRequested sourceLine, opts
    return Core.renderedTransformBounds sourceLine, opts
  return nil unless ZF
  prepared = Core.prepareZfTextLine dlg, sourceLine
  line, call, pers, align = prepared.work, prepared.call, prepared.pers, prepared.align
  return nil unless pers and pers.pos
  px, py = pers.pos[1], pers.pos[2]
  shape = ZF.util\isShape line.text
  unless shape
    shape = call\toShape dlg, align, px, py
    if line.styleref
      line.styleref.scale_x = 100
      line.styleref.scale_y = 100
  return nil unless shape
  expanded = ZF.shape(shape, true)\setPosition(align)\expand(line, pers)\move(px, py)\build!
  simplified = Core.trim ZF.clipper(expanded)\simplify!\build "line", math.max(1, tonumber(opts.tolerance) or 1)
  shape_info = Core.shapeInfo simplified
  return nil unless shape_info
  bounds = Core.shapeBounds shape_info, simplified
  return nil unless bounds
  {
    l: bounds[1]
    t: bounds[2]
    r: bounds[3]
    b: bounds[4]
    w: bounds[3] - bounds[1]
    h: bounds[4] - bounds[2]
    align: prepared.source_align
    shape: shape_info
    path: simplified
  }

Core.shapeOutlinePath = (dlg, sourceLine, opts = {}) ->
  return nil unless ZF
  prepared = Core.prepareZfTextLine dlg, sourceLine, opts.drop_clip != false
  work, call, pers, align = prepared.work, prepared.call, prepared.pers, prepared.align
  return nil unless pers and pers.pos
  px, py = pers.pos[1], pers.pos[2]
  shape = ZF.util\isShape work.text
  unless shape
    shape = call\toShape dlg, align, px, py
    if work.styleref
      work.styleref.scale_x = 100
      work.styleref.scale_y = 100
  return nil unless shape
  close_paths = opts.close_paths != false
  path = Core.trim ZF.shape(shape, close_paths)\setPosition(align)\expand(work, pers)\move(px, py)\build!
  margin = tonumber(opts.margin) or 0
  path = Core.expandVectorPath path, margin, opts.tolerance if math.abs(margin) > geometryEpsilon
  Core.simplifyVectorPath path, opts.tolerance, close_paths

Core.styleSafePad = (line) ->
  state = Core.effectiveLineState line
  bord = Core.lineTagValue(line, "bord", "outline", 0, state) or 0
  xbord = Core.lineTagValue(line, "xbord", nil, bord, state) or bord
  ybord = Core.lineTagValue(line, "ybord", nil, bord, state) or bord
  shad = Core.lineTagValue(line, "shad", "shadow", 0, state) or 0
  xshad = Core.lineTagValue(line, "xshad", nil, shad, state) or shad
  yshad = Core.lineTagValue(line, "yshad", nil, shad, state) or shad
  blur = Core.lineTagValue(line, "blur", nil, 0, state) or 0
  math.max(bord, xbord, ybord) + math.max(math.abs(shad), math.abs(xshad), math.abs(yshad)) + math.abs(blur) * 2

Core.sectionFromMode = (mode, opts, oldBounds, textBounds) ->
  switch mode
    when "Left/top half" then return 2, 1
    when "Right/bottom half" then return 2, 2
    when "Left/top third" then return 3, 1
    when "Center third" then return 3, 2
    when "Right/bottom third" then return 3, 3
    when "Custom section"
      sections = math.max 1, opts.sections
      return sections, Core.clamp opts.section_index, 1, sections
    when "Auto by position"
      sections = math.max 1, opts.sections
      tb = Core.normalizeBounds textBounds
      ob = Core.normalizeBounds oldBounds
      if opts.strip_mode == "Vertical"
        span = tb[4] - tb[2]
        return sections, 1 if span <= 0
        center = (ob[2] + ob[4]) / 2
        return sections, Core.clamp(math.floor(Core.clamp((center - tb[2]) / span, 0, 1 - parametricEpsilon) * sections) + 1, 1, sections)
      span = tb[3] - tb[1]
      return sections, 1 if span <= 0
      center = (ob[1] + ob[3]) / 2
      return sections, Core.clamp(math.floor(Core.clamp((center - tb[1]) / span, 0, 1 - parametricEpsilon) * sections) + 1, 1, sections)
  1, 1

Core.sectionBounds = (bounds, sections, index, opts, margin) ->
  bounds = Core.normalizeBounds bounds
  return Core.padBounds bounds, margin if sections <= 1
  left, top, right, bottom = unpack bounds
  index = Core.clamp index, 1, sections
  bleed = math.max 0, tonumber(opts.bleed) or 0
  if opts.strip_mode == "Vertical"
    height = bottom - top
    y1 = top + height * (index - 1) / sections
    y2 = top + height * index / sections
    y1 -= if index == 1 then margin else bleed
    y2 += if index == sections then margin else bleed
    return {left - margin, y1, right + margin, y2}
  width = right - left
  x1 = left + width * (index - 1) / sections
  x2 = left + width * index / sections
  x1 -= if index == 1 then margin else bleed
  x2 += if index == sections then margin else bleed
  {x1, top - margin, x2, bottom + margin}

Core.safeStripSize = (strip) ->
  Core.clamp Core.finiteNumber(strip) or DEFAULTS.strip, 1

Core.layoutScaleForLine = (line) ->
  collection = line and line.parentCollection
  meta = collection and collection.meta or {}
  playY = tonumber(meta.PlayResY or meta.playresy or meta.res_y)
  layoutY = tonumber(meta.LayoutResY or meta.layoutresy)
  unless layoutY
    if aegisub and type(aegisub.video_size) == "function"
      ok, _, video_y = pcall aegisub.video_size
      layoutY = tonumber(video_y) if ok
  return playY / layoutY if playY and layoutY and layoutY != 0
  1

Core.matrixPoint = (point) ->
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
  return nil unless x and y and Core.finiteNumber(x) and Core.finiteNumber(y)
  {:x, :y}

Core.projectLocalPoints = (tags, width, height, points, layoutScale) ->
  return nil unless ArchPerspective and ArchPerspective.transformPoints
  source = [{point.x, point.y} for point in *points]
  ok, projected = pcall -> ArchPerspective.transformPoints tags, width, height, source, layoutScale
  return nil unless ok and projected
  out = {}
  for i = 1, #points
    point = Core.matrixPoint projected[i]
    return nil unless point
    out[#out + 1] = point
  out

Core.normalizeVector = (x, y) ->
  length = math.sqrt x * x + y * y
  return {x: 0, y: 0} if length < geometryEpsilon
  {x: x / length, y: y / length}

Core.outwardEdgeNormal = (a, b) ->
  Core.normalizeVector b.y - a.y, -(b.x - a.x)

Core.offsetEdge = (a, b, amount) ->
  normal = Core.outwardEdgeNormal a, b
  {
    {x: a.x + normal.x * amount, y: a.y + normal.y * amount}
    {x: b.x + normal.x * amount, y: b.y + normal.y * amount}
  }

Core.lineIntersection = (a1, a2, b1, b2) ->
  dax, day = a2.x - a1.x, a2.y - a1.y
  dbx, dby = b2.x - b1.x, b2.y - b1.y
  denominator = dax * dby - day * dbx
  return nil if math.abs(denominator) < geometryEpsilon
  t = ((b1.x - a1.x) * dby - (b1.y - a1.y) * dbx) / denominator
  {x: a1.x + dax * t, y: a1.y + day * t}

Core.expandQuadScreen = (quad, margin) ->
  return quad unless quad and #quad >= 4
  margin = tonumber(margin) or 0
  return quad if math.abs(margin) < geometryEpsilon
  edges = {}
  for i = 1, 4
    nextI = i == 4 and 1 or i + 1
    edges[i] = Core.offsetEdge quad[i], quad[nextI], margin
  expanded = {}
  for i = 1, 4
    prevI = i == 1 and 4 or i - 1
    point = Core.lineIntersection edges[prevI][1], edges[prevI][2], edges[i][1], edges[i][2]
    unless point
      prevNormal = Core.outwardEdgeNormal quad[prevI], quad[i]
      nextI = i == 4 and 1 or i + 1
      nextNormal = Core.outwardEdgeNormal quad[i], quad[nextI]
      point = {
        x: quad[i].x + prevNormal.x * margin + nextNormal.x * margin
        y: quad[i].y + prevNormal.y * margin + nextNormal.y * margin
      }
    expanded[i] = point
  expanded

Core.lineNeedsProjectedQuad = (line) ->
  text = if line then tostring(line.text or "") else ""
  return true if text\find "\\p[1-9]"
  state = Core.effectiveLineState line
  angle = Core.lineTagValue line, "frz", nil, nil, state
  angle = Core.lineTagValue(line, "fr", "angle", 0, state) if angle == nil
  return true if math.abs(tonumber(angle) or 0) > parametricEpsilon
  for tag in *{"frx", "fry", "fax", "fay"}
    value = Core.lineTagValue line, tag, nil, 0, state
    return true if math.abs(tonumber(value) or 0) > parametricEpsilon
  false

Core.bakedGeometryTags = ->
  {"p", "an", "fscx", "fscy", "pos", "move", "org", "frx", "fry", "frz", "fr", "fax", "fay", "t"}

Core.drawingLocalBounds = (data) ->
  return nil unless data and data.callback and ASS and ASS.Section and ASS.Section.Drawing
  left, top, right, bottom = nil, nil, nil, nil
  ok = pcall ->
    data\callback (section) ->
      isDrawing = section and ((section.instanceOf and section.instanceOf[ASS.Section.Drawing]) or section.class == ASS.Section.Drawing)
      return unless isDrawing and section.getExtremePoints
      okExt, ext = pcall -> section\getExtremePoints true
      return unless okExt and ext
      if ext.left and ext.top and ext.right and ext.bottom
        l, t = tonumber(ext.left.x), tonumber(ext.top.y)
        r, b = tonumber(ext.right.x), tonumber(ext.bottom.y)
        if l and t and r and b
          left = l if not left or l < left
          top = t if not top or t < top
          right = r if not right or r > right
          bottom = b if not bottom or b > bottom
      elseif ext.x and ext.y and ext.w and ext.h
        l, t, r, b = tonumber(ext.x), tonumber(ext.y), tonumber(ext.x + ext.w), tonumber(ext.y + ext.h)
        if l and t and r and b
          left = l if not left or l < left
          top = t if not top or t < top
          right = r if not right or r > right
          bottom = b if not bottom or b > bottom
  return nil unless ok and left and top and right and bottom
  Core.normalizeBounds {left, top, right, bottom}

Core.projectedTextQuad = (line, opts = {}) ->
  if Core.transformBoundsRequested line, opts
    shape = Core.renderedTransformBounds line, opts
    return nil unless shape
    bounds = Core.padBounds {shape.l, shape.t, shape.r, shape.b}, tonumber(opts.margin) or 0
    return Core.rectPoints bounds
  return nil unless ArchPerspective and ArchPerspective.transformPoints
  return nil unless Core.lineNeedsProjectedQuad line
  data, tags, width, height = nil, nil, nil, nil
  okParse, parsed = pcall -> Core.parseAssLine line
  data = parsed if okParse
  if data and ArchPerspective.prepareForPerspective
    okPrep, ptags, pwidth, pheight = pcall -> ArchPerspective.prepareForPerspective ASS, data
    pwidth, pheight = tonumber(pwidth), tonumber(pheight)
    if okPrep and ptags and PerspectiveTools and PerspectiveTools.validDim(pwidth) and PerspectiveTools.validDim(pheight)
      tags, width, height = ptags, pwidth, pheight
      if PerspectiveTools and PerspectiveTools.needsExtentOverride(line, width, height)
        mw, mh = PerspectiveTools.textExtents line, tags
        if PerspectiveTools.validDim(mw) and PerspectiveTools.validDim(mh)
          width, height = mw, mh
  unless tags and PerspectiveTools and PerspectiveTools.validDim(width) and PerspectiveTools.validDim(height)
    if PerspectiveTools and PerspectiveTools.prepare
      tags, width, height = PerspectiveTools.prepare line
  return nil unless tags and PerspectiveTools and PerspectiveTools.validDim(width) and PerspectiveTools.validDim(height)
  bounds = (data and Core.drawingLocalBounds(data)) or {0, 0, width, height}
  quad = Core.projectLocalPoints tags, width, height, Core.rectPoints(bounds), Core.layoutScaleForLine(line)
  return nil unless quad and #quad == 4
  margin = tonumber(opts.margin) or 0
  margin += Core.styleSafePad line if opts.style_pad
  Core.expandQuadScreen quad, margin

Core.textAreaClipTag = (dlg, line, opts = {}) ->
  name = "clip"
  if opts.replace_clip
    span = Core.firstClipSpan line.text
    name = span.name if span
  if Core.transformBoundsRequested line, opts
    shape = Core.renderedTransformBounds line, opts
    return nil unless shape
    margin = tonumber(opts.margin) or 0
    return Core.rectClipTag Core.padBounds({shape.l, shape.t, shape.r, shape.b}, margin), name
  if quad = Core.projectedTextQuad line, opts
    return Core.vectorClipTag quad, name
  return nil unless dlg
  ok, shape = pcall -> Core.buildTextBounds dlg, line, opts
  return nil unless ok and shape
  margin = tonumber(opts.margin) or 0
  margin += Core.styleSafePad line if opts.style_pad
  Core.rectClipTag Core.padBounds({shape.l, shape.t, shape.l + shape.w, shape.t + shape.h}, margin), name

Core.replaceOrInsertClip = (text, clipTag, replaceExisting = true) ->
  span = Core.firstClipSpan text
  if span and replaceExisting
    text\sub(1, span.start - 1) .. clipTag .. text\sub(span.stop + 1)
  else
    Core.insertLeadingTags text, clipTag

Core.opAutofitClip = (subs, sel, active, opts) ->
  unless ZF
    Core.showMessage "Text outline tools are not available."
    return false
  dlg = ZF.dialog subs, sel, active, false
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    span = Core.firstClipSpan line.text
    continue unless span
    oldBounds = Core.clipBoundsFromSpan span
    continue unless oldBounds
    ok, shapeOrErr = pcall -> Core.buildTextBounds dlg, line, opts
    continue unless ok and shapeOrErr
    sh = shapeOrErr
    textBounds = {sh.l, sh.t, sh.l + sh.w, sh.t + sh.h}
    margin = tonumber(opts.margin) or 0
    margin += Core.styleSafePad line if opts.style_pad and not sh.rendered
    sections, index = Core.sectionFromMode opts.autofit_mode or "Whole text", opts, oldBounds, textBounds
    target = Core.sectionBounds textBounds, sections, index, opts, margin
    target = Core.unionBounds target, oldBounds if opts.no_shrink
    repl = Core.rectClipTag target, span.name
    next_text = if sh.rendered
      Core.insertLeadingTags Core.stripAllClipsClean(line.text), repl
    else
      line.text\sub(1, span.start - 1) .. repl .. line.text\sub(span.stop + 1)
    if next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No clip could be autofit."
    return false
  aegisub.set_undo_point "Cliptomaniac - Autofit clip"
  true

Core.opCreateTextClip = (subs, sel, active, opts) ->
  unless ZF or (ASS and ArchPerspective)
    Core.showMessage "This action needs the text measuring tools."
    return false
  dlg = nil
  if ZF
    ok, value = pcall -> ZF.dialog subs, sel, active, false
    dlg = value if ok
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    clipTag = Core.textAreaClipTag dlg, line, opts
    continue unless clipTag
    next_text = if opts.replace_clip and Core.transformBoundsRequested(line, opts)
      Core.insertLeadingTags Core.stripAllClipsClean(line.text or ""), clipTag
    else
      Core.replaceOrInsertClip line.text or "", clipTag, opts.replace_clip
    if next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No text area could be clipped."
    return false
  aegisub.set_undo_point "Cliptomaniac - Create clip around text"
  true

Core.clipTypeForLine = (line, opts = {}) ->
  requested = opts.clip_type or "Auto"
  return requested if requested == "clip" or requested == "iclip"
  span = Core.firstClipSpan line.text
  if span and span.name == "iclip" then "iclip" else "clip"

Core.textToClipText = (dlg, line, opts = {}) ->
  path = Core.shapeOutlinePath dlg, line, opts
  return nil unless path and path != ""
  clipTag = Core.clipTagText Core.clipTypeForLine(line, opts), path
  Core.replaceOrInsertClip line.text or "", clipTag, opts.replace_clip

Core.opTextToClip = (subs, sel, active, opts) ->
  unless ZF
    Core.showMessage "Text outline tools are not available."
    return false
  dlg = ZF.dialog subs, sel, active, false
  changed, insertedOffset = 0, 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    idx = i + insertedOffset
    source = subs[idx]
    ok, next_text = pcall -> Core.textToClipText dlg, source, opts
    Core.warn "Line #{idx}: text to clip failed: #{next_text}" unless ok
    continue unless ok and next_text and next_text != source.text
    if opts.comment_source
      output = Core.copyLine source
      output.comment = false
      output.text = next_text
      source.comment = true
      subs[idx] = source
      subs.insert idx + 1, output
      insertedOffset += 1
    else
      source.text = next_text
      subs[idx] = source
    changed += 1
  if changed == 0
    Core.showMessage "No text or drawing outline could be converted to a clip."
    return false
  aegisub.set_undo_point "Cliptomaniac - Text to clip"
  true

Core.shapeToClipLine = (dlg, line) ->
  return nil unless ZF
  work = Core.copyLine line
  ZF.line(work)\prepoc dlg
  shape = ZF.util\isShape work.text
  return nil unless shape
  pers = dlg\getPerspectiveTags work
  return nil unless pers and pers.pos
  px, py = pers.pos[1], pers.pos[2]
  align = Core.zfAlignForLine work
  clip = ZF.shape(shape, true)\setPosition(align)\expand(work, pers)\move(px, py)\build!
  clipTag = "\\clip(#{clip})"
  text = Core.stripClipTags work.text
  text = Core.removeTagNames text, Core.bakedGeometryTags!
  text = Core.overrideTagsOnly text
  Core.replaceOrInsertClip text, clipTag, true

Core.clipToShapeText = (text) ->
  span = Core.firstClipSpan text
  return nil unless span
  kind, _, payload = Core.clipInnerParts span.inner
  drawing = if kind == "rect"
    Core.vectorClipInner Core.rectPoints payload
  elseif kind == "vector"
    payload
  else
    nil
  return nil unless drawing
  bounds = Core.clipBoundsFromSpan span
  return nil unless bounds
  left, top = bounds[1], bounds[2]
  localDrawing = Core.moveDrawing(drawing, -left, -top) or Core.shiftPath(drawing, -left, -top)
  text = Core.stripClipTags text
  text = Core.removeTagNames text, Core.bakedGeometryTags!
  text = Core.overrideTagsOnly text
  Core.insertLeadingTags(text, "\\an7\\pos(#{Core.formatNum left},#{Core.formatNum top})\\fscx100\\fscy100\\p1") .. localDrawing

Core.opShapeToClip = (subs, sel, active, opts) ->
  unless ZF
    Core.showMessage "Shape tools are not available."
    return false
  dlg = ZF.dialog subs, sel, active, false
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    ok, next_text = pcall -> Core.shapeToClipLine dlg, line
    Core.warn "Line #{i}: shape to clip failed: #{next_text}" unless ok
    if next_text and next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No drawing shape was converted to clip."
    return false
  aegisub.set_undo_point "Cliptomaniac - Shape to clip"
  true

Core.opClipToShape = (subs, sel, opts) ->
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    next_text = Core.clipToShapeText line.text
    if next_text and next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No clip was converted to shape."
    return false
  aegisub.set_undo_point "Cliptomaniac - Clip to shape"
  true

Core.opExtractClipAsMask = (subs, sel, opts) ->
  changed, insertedOffset = 0, 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    idx = i + insertedOffset
    source = subs[idx]
    next_text = Core.clipToShapeText source.text
    continue unless next_text
    output = Core.copyLine source
    output.comment = false
    output.text = next_text
    subs.insert idx + 1, output
    insertedOffset += 1
    changed += 1
  if changed == 0
    Core.showMessage "No clip could be extracted as a mask line."
    return false
  aegisub.set_undo_point "Cliptomaniac - Extract clip as mask line"
  true

Core.clipBooleanText = (dlg, line, opts = {}) ->
  return nil unless ZF and ZF.clipper
  span = Core.firstClipSpan line.text
  return nil unless span
  kind, _, payload = Core.clipInnerParts span.inner
  clipPath = if kind == "rect"
    Core.vectorClipInner Core.rectPoints payload
  elseif kind == "vector"
    payload
  else
    nil
  return nil unless clipPath
  shapePath = Core.shapeOutlinePath dlg, line, {
    margin: 0
    tolerance: opts.tolerance
    close_paths: opts.close_paths
    drop_clip: true
  }
  return nil unless shapePath and shapePath != ""
  inverse = opts.boolean_mode == "Cut text from clip"
  ok, result = pcall -> ZF.clipper(clipPath, shapePath, opts.close_paths != false)\clip(inverse)\build "line", math.max(1, tonumber(opts.tolerance) or 1)
  return nil unless ok and result and Core.trim(result) != ""
  Core.replaceOrInsertClip line.text, Core.clipTagText(span.name, Core.trim(result)), true

Core.opClipBoolean = (subs, sel, active, opts) ->
  unless ZF and ZF.clipper
    Core.showMessage "Shape combining tools are not available."
    return false
  dlg = ZF.dialog subs, sel, active, false
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    ok, next_text = pcall -> Core.clipBooleanText dlg, line, opts
    Core.warn "Line #{i}: clip boolean failed: #{next_text}" unless ok
    if ok and next_text and next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No clip could be combined with the text or drawing shape."
    return false
  aegisub.set_undo_point "Cliptomaniac - Clip boolean"
  true

Core.clipPointCount = (span) ->
  return 0 unless span
  kind, _, payload = Core.clipInnerParts span.inner
  return 4 if kind == "rect"
  return 0 unless kind == "vector"
  points = Core.anchorPointsFromCommands Core.parseDrawCommands payload
  points and #points or 0

Core.clipDiagnosticsLine = (line, index) ->
  spans = Core.allClipSpans line.text
  return "Line #{index}: no clip" if #spans == 0
  parts = {}
  for n, span in ipairs spans
    kind, scale = Core.clipInnerParts span.inner
    bounds = Core.clipBoundsFromSpan span
    bounds_text = if bounds
      "#{Core.formatNum bounds[1], 2},#{Core.formatNum bounds[2], 2} - #{Core.formatNum bounds[3], 2},#{Core.formatNum bounds[4], 2}"
    else
      "unknown bounds"
    kind_text = kind or "unknown"
    scale_text = scale or 1
    parts[#parts + 1] = "#{span.name} ##{n}: #{kind_text}, #{Core.clipPointCount span} points, scale #{scale_text}, #{bounds_text}"
  plane = line.extra and line.extra["_aegi_perspective_ambient_plane"]
  suffix = if plane then " | perspective plane saved" else ""
  "Line #{index}: " .. table.concat(parts, " / ") .. suffix

Core.opClipDiagnostics = (subs, sel, opts) ->
  reports = {}
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    reports[#reports + 1] = Core.clipDiagnosticsLine subs[i], i
  if #reports == 0
    Core.showMessage "No dialogue lines selected."
    return false
  Core.showMessage table.concat(reports, "\n"), "Clip diagnostics"
  true

Core.pointDistance = (a, b) ->
  dx, dy = b.x - a.x, b.y - a.y
  math.sqrt dx * dx + dy * dy

Core.shiftBoundaryT = (boundaryAt, t, direction, maxStep, amount = 1) ->
  return t if amount <= 0 or maxStep <= 0
  base = boundaryAt t
  return t unless base and base[1] and base[2]
  low, high = 0, maxStep
  for _ = 1, 10
    mid = (low + high) / 2
    candidateT = Core.clamp t + direction * mid, 0, 1
    candidate = boundaryAt candidateT
    if candidate and candidate[1] and candidate[2]
      delta = math.max Core.pointDistance(base[1], candidate[1]), Core.pointDistance(base[2], candidate[2])
      if delta <= amount then low = mid else high = mid
    else
      high = mid
  Core.clamp t + direction * low, 0, 1

Core.createRectStripClips = (bounds, mode, strip, name = "clip") ->
  strip = Core.safeStripSize strip
  bounds = Core.normalizeBounds bounds
  left, top, right, bottom = unpack bounds
  span = mode == "Vertical" and bottom - top or right - left
  sections = math.max 1, math.ceil(span / strip)
  clips = {}
  for i = 1, sections
    Core.checkCancelled!
    a = (i - 1) * strip
    b = i == sections and span or i * strip
    if mode == "Vertical"
      y1, y2 = top + a, top + b
      y1 -= 0.5 if i > 1
      y2 += 0.5 if i < sections
      clips[#clips + 1] = Core.rectClipTag {left, y1, right, y2}, name
    else
      x1, x2 = left + a, left + b
      x1 -= 0.5 if i > 1
      x2 += 0.5 if i < sections
      clips[#clips + 1] = Core.rectClipTag {x1, top, x2, bottom}, name
  clips

Core.createQuadStripClips = (points, mode, strip, name = "clip") ->
  strip = Core.safeStripSize strip
  return nil unless points and #points >= 4
  quad = {points[1], points[2], points[3], points[4]}
  span = if mode == "Vertical"
    (Core.pointDistance(quad[1], quad[4]) + Core.pointDistance(quad[2], quad[3])) / 2
  else
    (Core.pointDistance(quad[1], quad[2]) + Core.pointDistance(quad[4], quad[3])) / 2
  return nil if span <= 0
  sections = math.max 1, math.ceil(span / strip)
  boundaryAt = (t) ->
    if mode == "Vertical"
      {Core.lerpPoint(quad[1], quad[4], t), Core.lerpPoint(quad[2], quad[3], t)}
    else
      {Core.lerpPoint(quad[1], quad[2], t), Core.lerpPoint(quad[4], quad[3], t)}
  clips = {}
  stepT = 1 / sections
  for i = 1, sections
    Core.checkCancelled!
    t1, t2 = (i - 1) / sections, i / sections
    t2 = Core.shiftBoundaryT boundaryAt, t2, 1, stepT / 2, 1 if i < sections
    if mode == "Vertical"
      top = boundaryAt t1
      bottom = boundaryAt t2
      clips[#clips + 1] = Core.vectorClipTag {top[1], top[2], bottom[2], bottom[1]}, name
    else
      left = boundaryAt t1
      right = boundaryAt t2
      clips[#clips + 1] = Core.vectorClipTag {left[1], right[1], right[2], left[2]}, name
  clips

Core.quadUvPoint = (quad, u, v) ->
  ok, point = pcall -> quad\uv_to_xy {u, v}
  return nil unless ok and point
  Core.matrixPoint point

Core.createQuadMeshClips = (points, mode, strip, name = "clip") ->
  strip = Core.safeStripSize strip
  return nil unless points and #points >= 4
  return nil unless ArchPerspective and ArchPerspective.Quad
  ok, quad = pcall -> ArchPerspective.Quad {
    {points[1].x, points[1].y}
    {points[2].x, points[2].y}
    {points[3].x, points[3].y}
    {points[4].x, points[4].y}
  }
  return {} unless ok and quad
  span = if mode == "Vertical"
    (Core.pointDistance(points[1], points[4]) + Core.pointDistance(points[2], points[3])) / 2
  else
    (Core.pointDistance(points[1], points[2]) + Core.pointDistance(points[4], points[3])) / 2
  return {} if span <= geometryEpsilon
  sections = math.max 1, math.ceil(span / strip)
  stepT = 1 / sections
  boundaryAt = (t) ->
    if mode == "Vertical"
      {Core.quadUvPoint(quad, 0, t), Core.quadUvPoint(quad, 1, t)}
    else
      {Core.quadUvPoint(quad, t, 0), Core.quadUvPoint(quad, t, 1)}
  clips = {}
  for i = 1, sections
    Core.checkCancelled!
    t1, t2 = (i - 1) / sections, i / sections
    t2 = Core.shiftBoundaryT boundaryAt, t2, 1, stepT / 2, 1 if i < sections
    if mode == "Vertical"
      top = boundaryAt t1
      bottom = boundaryAt t2
      if top[1] and top[2] and bottom[1] and bottom[2]
        clips[#clips + 1] = Core.vectorClipTag {top[1], top[2], bottom[2], bottom[1]}, name
    else
      left = boundaryAt t1
      right = boundaryAt t2
      if left[1] and left[2] and right[1] and right[2]
        clips[#clips + 1] = Core.vectorClipTag {left[1], right[1], right[2], left[2]}, name
  if #clips == sections then clips else {}

Core.stripClipsFromQuad = (points, mode, strip, name = "clip") ->
  quadMode = if mode == "Vertical" then "Vertical" else "Horizontal"
  Core.createQuadMeshClips(points, quadMode, strip, name) or Core.createQuadStripClips(points, quadMode, strip, name)

Core.pointsFromClipSpan = (span) ->
  kind, _, payload = Core.clipInnerParts span.inner
  if kind == "rect"
    return Core.rectPoints payload
  if kind == "vector"
    return Core.anchorPointsFromCommands Core.parseDrawCommands payload
  nil

Core.insertClippedDuplicate = (subs, index, source, clipTag, offset) ->
  line = Core.copyLine source
  line.comment = false
  line.text = Core.stripClipTags line.text
  line.text = Core.insertLeadingTags line.text, clipTag
  subs.insert index + offset, line

Core.opCreateStripClips = (subs, sel, active, opts) ->
  dlg = nil
  if ZF
    ok, value = pcall -> ZF.dialog subs, sel, active, false
    dlg = value if ok
  pending = {}
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    source = subs[i]
    span = Core.firstClipSpan source.text
    clips = nil
    if span
      kind = Core.clipInnerParts span.inner
      points = Core.pointsFromClipSpan span
      if kind == "vector" and points and #points >= 4
        clips = Core.stripClipsFromQuad points, opts.strip_mode, opts.strip, span.name
      else
        bounds = Core.clipBoundsFromSpan span
        clips = Core.createRectStripClips bounds, opts.strip_mode, opts.strip, span.name if bounds
    else
      if quad = Core.projectedTextQuad source, opts
        clips = Core.stripClipsFromQuad quad, opts.strip_mode, opts.strip
      unless clips
        bounds = nil
        if dlg
          ok, shape = pcall -> Core.buildTextBounds dlg, source, opts
          bounds = {shape.l, shape.t, shape.l + shape.w, shape.t + shape.h} if ok and shape
        clips = Core.createRectStripClips bounds, opts.strip_mode, opts.strip if bounds
    continue unless clips and #clips > 0
    pending[#pending + 1] = {index: i, source: source, clips: clips}
  if #pending == 0
    Core.showMessage "No strip clips were generated."
    return false
  changed, insertedOffset = 0, 0
  for job in *pending
    Core.checkCancelled!
    idx = job.index + insertedOffset
    source = subs[idx]
    clips = job.clips
    if opts.create_new_lines
      source.comment = true if opts.comment_source
      subs[idx] = source
      for n, clipTag in ipairs clips
        Core.checkCancelled!
        Core.insertClippedDuplicate subs, idx, source, clipTag, n
      insertedOffset += #clips
      changed += #clips
    else
      source.text = Core.stripClipTags source.text
      source.text = Core.insertLeadingTags source.text, clips[1]
      subs[idx] = source
      changed += 1
  aegisub.set_undo_point "Cliptomaniac - Create strip clips"
  true

Core.parseMoveTag = (text) ->
  call = AssContext.firstTag text, {"move"}
  return nil unless call
  args = LineOps.splitArguments call.value
  return nil unless #args == 4 or #args == 6
  nums = {}
  for index, value in ipairs args
    nums[index] = Core.finiteNumber value
    return nil unless nums[index]
  {
    x1: nums[1], y1: nums[2], x2: nums[3], y2: nums[4]
    t1: nums[5], t2: nums[6]
  }

Core.shiftClipText = (text, dx, dy) ->
  Core.mapClipTags text, (span) ->
    kind, scale, payload = Core.clipInnerParts span.inner
    if kind == "rect"
      b = Core.padBounds payload, 0
      Core.rectClipTag {b[1] + dx, b[2] + dy, b[3] + dx, b[4] + dy}, span.name
    elseif kind == "vector"
      Core.clipTagText span.name, Core.vectorInnerWithScale(Core.shiftPath(payload, dx, dy), scale)
    else
      span.raw

Core.movePositionAt = (move, line, ms) ->
  duration = math.max 1, (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0)
  localMs = (tonumber(ms) or 0) - (tonumber(line.start_time) or 0)
  t1, t2 = Core.finiteNumber(move.t1) or 0, Core.finiteNumber(move.t2) or 0
  t1, t2 = t2, t1 if t1 > t2
  t1, t2 = 0, duration if t1 <= 0 and t2 <= 0
  ratio = if localMs <= t1 then 0 elseif localMs >= t2 then 1 else (localMs - t1) / (t2 - t1)
  {
    x: move.x1 + (move.x2 - move.x1) * ratio
    y: move.y1 + (move.y2 - move.y1) * ratio
  }

Core.frameRangeForLine = (line) ->
  AssContext.frameRange line

Core.trackingFps = ->
  if aegisub and aegisub.ms_from_frame
    okFirst, firstMs = pcall aegisub.ms_from_frame, 0
    okLast, lastMs = pcall aegisub.ms_from_frame, 1000
    firstMs, lastMs = Core.finiteNumber(firstMs), Core.finiteNumber(lastMs)
    elapsed = lastMs - firstMs if okFirst and okLast and firstMs and lastMs
    return 1000000 / elapsed if elapsed and elapsed > 0
  trackingFallbackFps

Core.trackingFrameCount = (line, fps) ->
  startMs = Core.finiteNumber(line and line.start_time)
  endMs = Core.finiteNumber(line and line.end_time)
  return nil, "duration" unless startMs and endMs and endMs > startMs
  if aegisub and aegisub.frame_from_ms
    okStart, startFrame = pcall aegisub.frame_from_ms, startMs
    okEnd, endFrame = pcall aegisub.frame_from_ms, endMs
    startFrame, endFrame = tonumber(startFrame), tonumber(endFrame)
    return math.max(1, endFrame - startFrame) if okStart and okEnd and startFrame and endFrame
  fps = Core.finiteNumber(fps) or trackingFallbackFps
  math.max 1, math.floor((endMs - startMs) * fps / 1000 + 0.5)

Core.manualMoveFbfLines = (line) ->
  return nil unless Core.parseMoveTag(line.text) and Core.firstClipSpan(line.text)
  Core.utilFbfLines line

Core.copyPlainFbfLine = (item, fallback) ->
  return nil unless type(item) == "table"
  source = if item.text then item elseif item.line and item.line.text then item.line else nil
  return nil unless source
  out = Core.copyLine fallback
  out[k] = v for k, v in pairs source
  out.class = out.class or "dialogue"
  out.comment = false
  out

Core.utilFbfLines = (line) ->
  return nil unless Util and Util.exact_ms_from_frame and ASS and ASS.parse
  okParse, data = pcall -> Core.parseAssLine line
  return nil unless okParse and data
  okFbf, fbf = pcall -> AssContext.line2fbf data, Util, ASS
  Core.checkCancelled!
  return nil unless okFbf and type(fbf) == "table"
  out = {}
  for item in *fbf
    plain = Core.copyPlainFbfLine item, line
    AssContext.shiftFrameKaraoke plain, line.start_time, plain.start_time if plain
    out[#out + 1] = plain if plain and plain.text
  if #out > 0 then out else nil

Core.clipOnlyFromBaked = (source, baked) ->
  return baked if AssContext.needsFullBake source.text
  span = Core.firstClipSpan baked.text
  return baked unless span
  out = Core.copyLine source
  out.start_time = baked.start_time
  out.end_time = baked.end_time
  base = Core.stripClipTags source.text
  base = Core.removeTagNames base, {"t"}
  out.text = Core.insertLeadingTags base, span.raw
  out

Core.fbfLinesForLine = (line, opts = {}) ->
  lines = Core.utilFbfLines line, opts
  return nil unless lines and #lines > 0
  if opts.fbf_source == "Clip only"
    lines = [Core.clipOnlyFromBaked(line, baked) for baked in *lines]
  lines

Core.sameFbfBody = (a, b) ->
  return false unless a and b
  for key in *{"text", "style", "actor", "effect", "layer"}
    return false unless tostring(a[key] or "") == tostring(b[key] or "")
  true

Core.mergeFbfLines = (lines) ->
  out = {}
  for line in *(lines or {})
    if #out > 0 and Core.sameFbfBody(out[#out], line) and out[#out].end_time == line.start_time
      out[#out].end_time = line.end_time
    else
      out[#out + 1] = line
  out

Core.opAnimatedClipToFbf = (subs, sel, active, opts) ->
  changed, insertedOffset, total_frames = 0, 0, 0
  pending = {}
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    lines = Core.fbfLinesForLine line, opts
    continue unless lines and #lines > 0
    lines = Core.mergeFbfLines lines if opts.merge_identical
    total_frames += #lines
    pending[#pending + 1] = {index: i, lines: lines}
  if #pending == 0
    Core.showMessage "No animated clip or movable clipped line could be baked."
    return false
  if opts.max_frames > 0 and total_frames > opts.max_frames
    message = if current_language == "es" then "Esto crearía #{total_frames} línea(s). Sube Frames max si quieres ejecutarlo." else "This would create #{total_frames} line(s). Raise Max frames if you want to run it."
    Core.showMessage message, "Animated clip to FBF"
    return false
  for job in *pending
    Core.checkCancelled!
    idx = job.index + insertedOffset
    source = subs[idx]
    lines = job.lines
    if opts.comment_source
      source.comment = true
      subs[idx] = source
      for n, outLine in ipairs lines
        Core.checkCancelled!
        subs.insert idx + n, outLine
      insertedOffset += #lines
    else
      subs[idx] = lines[1]
      for n = 2, #lines
        Core.checkCancelled!
        subs.insert idx + n - 1, lines[n]
      insertedOffset += #lines - 1
    changed += #lines
  aegisub.set_undo_point "Cliptomaniac - Animated clip to FBF"
  true

Core.collectAeClipTrack = (subs, sel) ->
  fps = Core.trackingFps!
  indices = Core.dialogueIndices subs, sel, true
  return nil, nil, Core.L("select_one") if #indices == 0
  table.sort indices, (a, b) ->
    lineA, lineB = subs[a], subs[b]
    startA, startB = tonumber(lineA and lineA.start_time) or 0, tonumber(lineB and lineB.start_time) or 0
    if startA == startB then a < b else startA < startB
  jobs, problems = {}, {}
  for n, i in ipairs indices
    segment, reason = Core.trackingSegmentForLine subs[i]
    frame_count, timeReason = Core.trackingFrameCount subs[i], fps
    reason or= timeReason
    if reason
      problems[#problems + 1] = "#{Core.L 'track_sample'} #{n}: #{Core.L('track_' .. reason)}."
    else
      jobs[#jobs + 1] = {:segment, :frame_count}
  if #problems > 0
    return nil, nil, Core.L("track_failed") .. "\n\n" .. table.concat(problems, "\n")
  samples, frame = {}, 0
  for job in *jobs
    for _ = 1, job.frame_count
      samples[#samples + 1] = {
        :frame
        x: job.segment.x
        y: job.segment.y
        length: job.segment.length
        angle: job.segment.angle
      }
      frame += 1
  samples, fps

Core.buildAeClipTrackData = (samples, fps, width, height) ->
  position = {
    "Adobe After Effects 6.0 Keyframe Data\n\n"
    "\tUnits Per Second\t#{Core.formatNum fps, 6}\n"
    "\tSource Width\t#{Core.formatNum width, 0}\n"
    "\tSource Height\t#{Core.formatNum height, 0}\n"
    "\tSource Pixel Aspect Ratio\t1\n"
    "\tComp Pixel Aspect Ratio\t1\n\n"
    "Position\n\tFrame\tX pixels\tY pixels\tZ pixels\n"
  }
  scale = {"\nScale\n\tFrame\tX percent\tY percent\tZ percent\n"}
  rotation = {"\nRotation\n\tFrame\tDegrees\n"}
  referenceLength = samples[1].length
  previousAngle = samples[1].angle
  unwrappedRotation = 0
  for n, sample in ipairs samples
    if n > 1
      delta = (sample.angle - previousAngle) % 360
      delta -= 360 if delta > 180
      unwrappedRotation += delta
      previousAngle = sample.angle
    scalePercent = sample.length / referenceLength * 100
    position[#position + 1] = string.format "\t%d\t%s\t%s\t0\n", sample.frame, Core.formatNum(sample.x, 4), Core.formatNum(sample.y, 4)
    value = Core.formatNum scalePercent, 4
    scale[#scale + 1] = string.format "\t%d\t%s\t%s\t%s\n", sample.frame, value, value, value
    rotation[#rotation + 1] = string.format "\t%d\t%s\n", sample.frame, Core.formatNum(unwrappedRotation, 4)
  rotation[#rotation + 1] = "\nEnd of Keyframe Data"
  table.concat(position) .. table.concat(scale) .. table.concat(rotation)

Core.opExportClipTrackAe = (subs, sel) ->
  samples, fps, problem = Core.collectAeClipTrack subs, sel
  unless samples
    Core.showMessage problem, "Export clip track to AE"
    return false
  width, height = Core.trackingResolution subs
  aegisub.log Core.buildAeClipTrackData samples, fps, width, height
  true

Core.quadFromClip = (text) ->
  span = Core.firstClipSpan text
  return nil unless span
  pts = Core.quadPointsFromSpan span
  return nil unless pts and #pts == 4
  {
    {pts[1].x, pts[1].y}
    {pts[2].x, pts[2].y}
    {pts[3].x, pts[3].y}
    {pts[4].x, pts[4].y}
  }

Core.planeExtraString = (quad) ->
  return nil unless quad and #quad >= 4
  string.format "%.3f;%.3f|%.3f;%.3f|%.3f;%.3f|%.3f;%.3f",
    quad[1][1], quad[1][2], quad[2][1], quad[2][2], quad[3][1], quad[3][2], quad[4][1], quad[4][2]

Core.planePointsFromNumbers = (nums) ->
  return nil unless nums and #nums >= 8
  points = {}
  for i = 1, 4
    x, y = Core.finiteNumber(nums[i * 2 - 1]), Core.finiteNumber(nums[i * 2])
    return nil unless x and y
    points[#points + 1] = {:x, :y}
  points

Core.planePointsFromString = (value) ->
  nums = {}
  for n in tostring(value or "")\gmatch numPattern
    nums[#nums + 1] = tonumber n
    break if #nums >= 8
  Core.planePointsFromNumbers nums

Core.perspectiveMarkerInner = (text) ->
  tostring(text or "")\match "\\_persp%(([^%)]*)%)"

Core.stripPerspectiveMarker = (text) ->
  clean = tostring(text or "")\gsub "\\_persp%([^%)]+%)", ""
  Core.cleanEmptyOverrides clean

Core.planePointsToQuad = (points) ->
  return nil unless points and #points >= 4
  {{points[1].x, points[1].y}, {points[2].x, points[2].y}, {points[3].x, points[3].y}, {points[4].x, points[4].y}}

Core.perspectivePlanePointsForLine = (line) ->
  if line and type(line.extra) == "table"
    points = Core.planePointsFromString line.extra["_aegi_perspective_ambient_plane"]
    return points, "extra" if points
  marker = Core.perspectiveMarkerInner(line and line.text)
  if marker
    points = Core.planePointsFromString marker
    return points, "marker" if points
  quad = Core.projectedTextQuad line, {margin: 0, style_pad: false}
  return quad, "projected" if quad and #quad >= 4
  nil, nil

Core.planeExtraStringFromPoints = (points) ->
  quad = Core.planePointsToQuad points
  Core.planeExtraString quad

PerspectiveTools = PerspectiveTools or {}

PerspectiveTools.finiteValue = (n) ->
  type(n) == "number" and Core.finiteNumber(n) != nil

PerspectiveTools.validDim = (n) ->
  PerspectiveTools.finiteValue(n) and n > 0.0001

PerspectiveTools.validQuad = (quad) ->
  return false unless type(quad) == "table" and #quad >= 4
  area = 0
  for i = 1, 4
    p = quad[i]
    return false unless type(p) == "table" and PerspectiveTools.finiteValue(p[1]) and PerspectiveTools.finiteValue(p[2])
    j = i == 4 and 1 or i + 1
    area += p[1] * quad[j][2] - quad[j][1] * p[2]
  math.abs(area) > 0.01

Core.trianglePointsFromSpan = (span) ->
  kind, payload, scale = Core.clipVectorPartsForOutput span
  return nil unless kind == "vector"
  cmds = Core.parseDrawCommands payload
  return nil unless cmds and #cmds >= 3 and #cmds <= 4
  moves, lines = 0, 0
  for i, cmd in ipairs cmds
    if cmd.type == "m"
      return nil unless i == 1
      moves += 1
    elseif cmd.type == "l"
      lines += 1
    elseif cmd.type == "c"
      return nil unless i == #cmds
    else
      return nil
  return nil unless moves == 1 and lines == 2
  points = Core.anchorPointsFromCommands cmds
  return nil unless #points == 3
  points, scale

Core.projectiveFourthPoint = (points, planePoints) ->
  return nil unless ArchPerspective and ArchPerspective.Quad and planePoints and #planePoints >= 4
  plane = {}
  for i = 1, 4
    point = Core.matrixPoint planePoints[i]
    return nil unless point
    plane[i] = {point.x, point.y}
  okQuad, quad = pcall -> ArchPerspective.Quad plane
  return nil unless okQuad and quad
  pointClass = quad[1] and quad[1].__class
  return nil unless pointClass
  uv = {}
  for i = 1, 3
    okXy, xy = pcall -> pointClass points[i].x, points[i].y
    return nil unless okXy and xy
    okUv, mapped = pcall -> quad\xy_to_uv xy
    return nil unless okUv and mapped
    uv[i] = Core.matrixPoint mapped
    return nil unless uv[i]
  target = {
    uv[1].x + uv[3].x - uv[2].x
    uv[1].y + uv[3].y - uv[2].y
  }
  okPoint, mapped = pcall -> quad\uv_to_xy target
  return nil unless okPoint and mapped
  Core.matrixPoint mapped

Core.completeQuadrilateralPoints = (points, planePoints = nil) ->
  return nil unless points and #points == 3
  clean = {}
  for i = 1, 3
    clean[i] = Core.matrixPoint points[i]
    return nil unless clean[i]
  a, b, c = clean[1], clean[2], clean[3]
  local d
  if planePoints
    d = Core.projectiveFourthPoint clean, planePoints
    return nil unless d
  else
    d = {x: a.x + c.x - b.x, y: a.y + c.y - b.y}
  completed = {a, b, c, d}
  quad = [{point.x, point.y} for point in *completed]
  return nil unless PerspectiveTools.validQuad quad
  completed

Core.completeQuadrilateralText = (line) ->
  span = Core.firstClipSpan line and line.text
  return nil unless span
  points, scale = Core.trianglePointsFromSpan span
  return nil unless points
  planePoints, source = Core.perspectivePlanePointsForLine line
  completed = Core.completeQuadrilateralPoints points, planePoints
  return nil unless completed
  replacement = Core.clipTagText span.name, Core.vectorInnerWithScale(Core.vectorClipInner(completed), scale)
  Core.replaceFirstClip(line.text or "", replacement), completed, source or "affine"

PerspectiveTools.edgeLen = (a, b) ->
  dx, dy = (b[1] or 0) - (a[1] or 0), (b[2] or 0) - (a[2] or 0)
  math.sqrt dx * dx + dy * dy

PerspectiveTools.area = (quad) ->
  area = 0
  for i = 1, 4
    j = i == 4 and 1 or i + 1
    area += quad[i][1] * quad[j][2] - quad[j][1] * quad[i][2]
  area / 2

PerspectiveTools.rotate = (quad, startIndex, reversed) ->
  out = {}
  for i = 1, 4
    idx = if reversed then ((startIndex - i) % 4) + 1 else ((startIndex + i - 2) % 4) + 1
    out[i] = {quad[idx][1], quad[idx][2]}
  out

PerspectiveTools.orient = (quad, width, height) ->
  return quad unless PerspectiveTools.validQuad quad
  targetAspect = if PerspectiveTools.validDim(width) and PerspectiveTools.validDim(height) then width / height else 1
  best, bestScore = nil, nil
  for reversed in *{false, true}
    for startIndex = 1, 4
      candidate = PerspectiveTools.rotate quad, startIndex, reversed
      widthLen = (PerspectiveTools.edgeLen(candidate[1], candidate[2]) + PerspectiveTools.edgeLen(candidate[4], candidate[3])) / 2
      heightLen = (PerspectiveTools.edgeLen(candidate[2], candidate[3]) + PerspectiveTools.edgeLen(candidate[1], candidate[4])) / 2
      if widthLen > 0 and heightLen > 0
        score = math.abs math.log((widthLen / heightLen) / targetAspect)
        topY = (candidate[1][2] + candidate[2][2]) / 2
        bottomY = (candidate[3][2] + candidate[4][2]) / 2
        score += 2 if topY > bottomY
        score += 0.5 if candidate[1][1] > candidate[2][1]
        score += 0.25 if PerspectiveTools.area(candidate) < 0
        if not bestScore or score < bestScore
          best, bestScore = candidate, score
  best or quad

PerspectiveTools.mapQuad = (quad, name) ->
  name = Core.normalizePerspectiveMap name
  for entry in *perspectiveData.maps
    if entry[1] == name
      mapping = entry[2]
      return {quad[mapping[1]], quad[mapping[2]], quad[mapping[3]], quad[mapping[4]]} if type(mapping) == "table"
  quad

PerspectiveTools.mapItems = ->
  [entry[1] for entry in *perspectiveData.maps]

PerspectiveTools.orgMode = (name) ->
  tonumber(tostring(Core.normalizePerspectiveOrg(name))\match "^(%d)") or 2

PerspectiveTools.tagValue = (tag, fallback = 0) ->
  return tonumber(tag) or fallback unless type(tag) == "table"
  return tonumber(tag.value) or fallback if tag.value != nil
  return tonumber(tag.dim_value) or fallback if tag.dim_value != nil
  fallback

PerspectiveTools.dimTag = (value) ->
  n = tonumber(value) or 0
  {value: n, dim_value: n}

PerspectiveTools.alignValue = (value, fallback = 5) ->
  n = math.floor(tonumber(value) or tonumber(fallback) or 5)
  if n >= 1 and n <= 9 then n else 5

PerspectiveTools.ensureDimTag = (tags, name, fallback = 0) ->
  tag = tags[name]
  n = PerspectiveTools.tagValue tag, fallback
  if type(tag) == "table"
    tag.value = n
    tag.dim_value = n
  else
    tags[name] = PerspectiveTools.dimTag(n)
  tags[name]

PerspectiveTools.ensureAlignTag = (tags, fallback = 5) ->
  n = PerspectiveTools.alignValue(PerspectiveTools.tagValue(tags.align, fallback), fallback)
  tags.align = PerspectiveTools.dimTag(n)

PerspectiveTools.defaultPosition = (line, style = nil) ->
  options = KiteCore.copy(Core.lineContext or {})
  options.style = style if style
  x, y, err = AssContext.defaultPosition line, options
  error err, 0 unless x and y
  {:x, :y}

PerspectiveTools.ensurePointTag = (tags, name, fallback) ->
  tag = tags[name]
  x, y = nil, nil
  if type(tag) == "table"
    x = tonumber(tag.x)
    y = tonumber(tag.y)
  x = tonumber(fallback and fallback.x) or 0 unless x
  y = tonumber(fallback and fallback.y) or 0 unless y
  tags[name] = {x: x, y: y}
  tags[name]

PerspectiveTools.syncDimTags = (tags) ->
  return tags unless type(tags) == "table"
  for _name, tag in pairs tags
    if type(tag) == "table"
      n = tonumber(tag.value) or tonumber(tag.dim_value)
      if n != nil
        tag.value = n
        tag.dim_value = n
  tags

PerspectiveTools.style = (style, name = "Default") ->
  out = {}
  if type(style) == "table"
    out[k] = v for k, v in pairs style
  out.class = out.class or "style"
  out.name = out.name or name or "Default"
  out.fontname = out.fontname or "Arial"
  out.fontsize = tonumber(out.fontsize) or 20
  out.scale_x = tonumber(out.scale_x) or 100
  out.scale_y = tonumber(out.scale_y) or 100
  out.angle = tonumber(out.angle) or 0
  out.spacing = tonumber(out.spacing) or 0
  out.outline = tonumber(out.outline) or 0
  out.shadow = tonumber(out.shadow) or 0
  out.margin_l = tonumber(out.margin_l) or 0
  out.margin_r = tonumber(out.margin_r) or 0
  out.margin_t = tonumber(out.margin_t or out.margin_v) or 0
  out.align = tonumber(out.align) or 5
  out.bold = out.bold or false
  out.italic = out.italic or false
  out.underline = out.underline or false
  out.strikeout = out.strikeout or false
  out.color1 = out.color1 or "&H00FFFFFF"
  out.color2 = out.color2 or "&H00FFFFFF"
  out.color3 = out.color3 or "&H00000000"
  out.color4 = out.color4 or "&H00000000"
  out

PerspectiveTools.effectiveTags = (data) ->
  return nil unless data and data.line
  ok, eff = pcall -> AssContext.effectiveTags data.line, ASS, AMLine, Core.lineContext
  return nil unless ok and eff
  eff

PerspectiveTools.shapeExtents = (text) ->
  raw = tostring(text or "")
  return nil unless raw\find "\\p[1-9]"
  body = LineOps.analyzeText(raw).drawing
  minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
  found = false
  for sx, sy in body\gmatch "(" .. numPattern .. ")%s+(" .. numPattern .. ")"
    x, y = tonumber(sx), tonumber(sy)
    if x and y
      found = true
      minx = math.min minx, x
      miny = math.min miny, y
      maxx = math.max maxx, x
      maxy = math.max maxy, y
  return nil unless found
  math.max(maxx - minx, 0.01), math.max(maxy - miny, 0.01)

PerspectiveTools.measureStyle = (line, style) ->
  state = Core.effectiveLineState line
  baseStyle = if state and state.style and next(state.style) then state.style else style
  out = PerspectiveTools.style baseStyle, line and line.style or "Default"
  out.fontsize = Core.lineTagValue(line, "fs", "fontsize", out.fontsize, state) or out.fontsize
  out.scale_x = Core.lineTagValue(line, "fscx", "scale_x", out.scale_x, state) or out.scale_x
  out.scale_y = Core.lineTagValue(line, "fscy", "scale_y", out.scale_y, state) or out.scale_y
  out.spacing = Core.lineTagValue(line, "fsp", "spacing", out.spacing, state) or out.spacing
  unless state.tag_list and state.style
    for block in *Core.overrideBlockSpans(line and line.text or "")
      continue unless Core.looksLikeOverride block.inner
      for name in block.inner\gmatch "\\fn([^\\}]*)"
        out.fontname = name if name and name != ""
  for item in *{{"b", "bold"}, {"i", "italic"}, {"u", "underline"}, {"s", "strikeout"}}
    value = Core.lineTagValue line, item[1], nil, nil, state
    out[item[2]] = value != 0 if value != nil
  out

PerspectiveTools.pointValue = (value) ->
  seen = {}
  while type(value) == "table" and value.startPos
    return nil if seen[value]
    seen[value] = true
    value = value.startPos
  return nil unless type(value) == "table"
  x = tonumber(value.x or value[1])
  y = tonumber(value.y or value[2])
  return {x: x, y: y} if x and y
  if value.getTagParams
    ok, px, py = pcall -> value\getTagParams!
    x, y = tonumber(px), tonumber(py) if ok
    return {x: x, y: y} if x and y
  nil

PerspectiveTools.pointFromTag = (text, name) ->
  call = AssContext.firstTag text, name
  return nil unless call
  args = LineOps.splitArguments call.value
  x, y = Core.finiteNumber(args[1]), Core.finiteNumber(args[2])
  if x and y then {:x, :y} else nil

PerspectiveTools.moveStart = (text) ->
  x, y = AssContext.explicitPosition text
  if x and y then {:x, :y} else nil

PerspectiveTools.rawTags = (line) ->
  state = Core.effectiveLineState line
  style = PerspectiveTools.measureStyle line, PerspectiveTools.style(state.style, line and line.style or "Default")
  bord = Core.lineTagValue(line, "bord", "outline", style.outline or 0, state)
  shad = Core.lineTagValue(line, "shad", "shadow", style.shadow or 0, state)
  tags = {
    align: PerspectiveTools.dimTag Core.lineTagValue(line, "an", "align", style.align or 5, state)
    scale_x: PerspectiveTools.dimTag Core.lineTagValue(line, "fscx", "scale_x", style.scale_x or 100, state)
    scale_y: PerspectiveTools.dimTag Core.lineTagValue(line, "fscy", "scale_y", style.scale_y or 100, state)
    angle: PerspectiveTools.dimTag Core.lineTagValue(line, "frz", "angle", style.angle or 0, state)
    angle_x: PerspectiveTools.dimTag Core.lineTagValue(line, "frx", nil, 0, state)
    angle_y: PerspectiveTools.dimTag Core.lineTagValue(line, "fry", nil, 0, state)
    shear_x: PerspectiveTools.dimTag Core.lineTagValue(line, "fax", nil, 0, state)
    shear_y: PerspectiveTools.dimTag Core.lineTagValue(line, "fay", nil, 0, state)
    fontsize: PerspectiveTools.dimTag Core.lineTagValue(line, "fs", "fontsize", style.fontsize or 20, state)
    outline_x: PerspectiveTools.dimTag Core.lineTagValue(line, "xbord", nil, bord, state)
    outline_y: PerspectiveTools.dimTag Core.lineTagValue(line, "ybord", nil, bord, state)
    shadow_x: PerspectiveTools.dimTag Core.lineTagValue(line, "xshad", nil, shad, state)
    shadow_y: PerspectiveTools.dimTag Core.lineTagValue(line, "yshad", nil, shad, state)
  }
  x, y, err = AssContext.position line, Core.lineContext
  error err, 0 unless x and y
  ox, oy = AssContext.origin line, Core.lineContext
  pos, org = {x: x, y: y}, {x: ox, y: oy}
  tags.position = {x: pos.x, y: pos.y}
  tags.origin = {x: org.x, y: org.y}
  tags

PerspectiveTools.hasVisibleSource = (line) ->
  clean = Core.visibleText(Core.stripClipTags(line and line.text or ""))\gsub("\\[Nn]", " ")
  Core.trim(clean) != ""

PerspectiveTools.needsExtentOverride = (line, width, height) ->
  return true if tostring(line and line.text or "")\find "\\N", 1, true
  return true if tostring(line and line.text or "")\find "\\n", 1, true
  PerspectiveTools.hasVisibleSource(line) and ((tonumber(width) or 0) < 1 or (tonumber(height) or 0) < 1)

PerspectiveTools.visibleLines = (text) ->
  clean = Core.visibleText(Core.stripClipTags(text or ""))\gsub("\\[Nn]", "\n")\gsub("\\h", " ")
  out = {}
  for line in (clean .. "\n")\gmatch "([^\n]*)\n"
    out[#out + 1] = if line == "" then " " else line
  if #out > 0 then out else {" "}

PerspectiveTools.textLen = (text) ->
  text = tostring(text or "")
  count = 0
  if unicode and unicode.chars
    for _ch in unicode.chars text
      count += 1
  else
    count = #text
  count

PerspectiveTools.roughTextExtents = (line, style, state = nil) ->
  state or= Core.effectiveLineState line
  fs = Core.lineTagValue(line, "fs", "fontsize", tonumber(style and style.fontsize) or 20, state) or 20
  sx = Core.lineTagValue(line, "fscx", "scale_x", tonumber(style and style.scale_x) or 100, state) or 100
  sy = Core.lineTagValue(line, "fscy", "scale_y", tonumber(style and style.scale_y) or 100, state) or 100
  spacing = Core.lineTagValue(line, "fsp", "spacing", tonumber(style and style.spacing) or 0, state) or 0
  maxW, totalH = 0, 0
  for piece in *PerspectiveTools.visibleLines(line and line.text or "")
    count = PerspectiveTools.textLen piece
    rawWidth = count * fs * averageGlyphWidthEm + math.max(count - 1, 0) * spacing
    maxW = math.max maxW, rawWidth * sx / 100
    totalH += fs * sy / 100
  math.max(maxW, 0.01), math.max(totalH, 0.01)

PerspectiveTools.textExtents = (line, tags = nil) ->
  state = Core.effectiveLineState line
  style = PerspectiveTools.measureStyle line, PerspectiveTools.style(state.style, line and line.style or "Default")
  w, h = PerspectiveTools.shapeExtents line and line.text
  unless PerspectiveTools.validDim(w) and PerspectiveTools.validDim(h)
    clean = Core.visibleText(Core.stripClipTags(line and line.text or ""))\gsub("\\[Nn]", "\n")
    return 100, 100 if Core.trim(clean) == ""
    hasLinebreak = tostring(line and line.text or "")\find("\\N", 1, true) or tostring(line and line.text or "")\find("\\n", 1, true)
    if not hasLinebreak and state.data and state.data.getTextExtents
      ok, ew, eh = pcall -> state.data\getTextExtents!
      if ok and PerspectiveTools.validDim(ew) and PerspectiveTools.validDim(eh)
        w, h = ew, eh
    if aegisub and type(aegisub.text_extents) == "function"
      unless PerspectiveTools.validDim(w) and PerspectiveTools.validDim(h)
        maxW, totalH, measured = 0, 0, false
        for piece in *PerspectiveTools.visibleLines(line and line.text or "")
          sample = if piece == "" then " " else piece
          ok, ew, eh = pcall aegisub.text_extents, style, sample
          if ok and PerspectiveTools.validDim(ew) and PerspectiveTools.validDim(eh)
            measured = true
            maxW = math.max maxW, ew
            totalH += eh
        if measured
          w, h = maxW, math.max(totalH, 0.01)
  unless PerspectiveTools.validDim(w) and PerspectiveTools.validDim(h)
    w, h = PerspectiveTools.roughTextExtents line, style, state
  sx = PerspectiveTools.tagValue(tags and tags.scale_x, Core.lineTagValue(line, "fscx", "scale_x", style.scale_x or 100, state))
  sy = PerspectiveTools.tagValue(tags and tags.scale_y, Core.lineTagValue(line, "fscy", "scale_y", style.scale_y or 100, state))
  w /= sx / 100 if PerspectiveTools.validDim sx
  h /= sy / 100 if PerspectiveTools.validDim sy
  unless PerspectiveTools.validDim(w) and PerspectiveTools.validDim(h)
    w, h = PerspectiveTools.roughTextExtents line, style, state
  math.max(w, 0.01), math.max(h, 0.01)

Core.leadingBlocksAndBody = (text) ->
  text = tostring(text or "")
  cursor = 1
  for block in *Core.overrideBlockSpans text
    break unless block.start == cursor
    cursor = block.stop + 1
  text\sub(1, cursor - 1), text\sub(cursor)

Core.clipGuideAxisLength = (line, axis) ->
  span = Core.firstClipSpan(line and line.text or "")
  return nil, nil unless span
  kind, _, payload = Core.clipInnerParts span.inner
  if kind == "rect"
    left, top, right, bottom = unpack Core.normalizeBounds payload
    length = if axis == "y" then bottom - top else right - left
    return length, span
  return nil, span unless kind == "vector"
  segments = Core.firstPathSegments Core.parseDrawCommands(payload), 1, 8
  segment = segments and segments[1]
  return nil, span unless segment
  length = if axis == "y" then math.abs(segment.y2 - segment.y1) else math.abs(segment.x2 - segment.x1)
  length, span

Core.fitGuideMeasure = (line) ->
  state = Core.effectiveLineState line
  style = PerspectiveTools.measureStyle line, PerspectiveTools.style(state.style, line and line.style or "Default")
  style.align = Core.alignForLine line
  measure = (value) ->
    sample = tostring(value or "")\gsub "\\h", " "
    sample = " " if sample == ""
    if aegisub and type(aegisub.text_extents) == "function"
      ok, width, height = pcall aegisub.text_extents, style, sample
      if ok and PerspectiveTools.validDim(width) and PerspectiveTools.validDim(height)
        return width, height
    count = PerspectiveTools.textLen sample
    fs = tonumber(style.fontsize) or 20
    sx = tonumber(style.scale_x) or 100
    sy = tonumber(style.scale_y) or 100
    spacing = tonumber(style.spacing) or 0
    width = (count * fs * averageGlyphWidthEm + math.max(count - 1, 0) * spacing) * sx / 100
    height = fs * sy / 100
    math.max(width, 0.01), math.max(height, 0.01)
  _, lineHeight = measure "Ag"
  measure, math.max(lineHeight, 0.01)

Core.wrapWordsToWidth = (words, maxWidth, measure) ->
  rows, current = {}, {}
  for word in *words
    candidate = if #current == 0 then word else table.concat(current, " ") .. " " .. word
    width = measure candidate
    if #current > 0 and width > maxWidth
      rows[#rows + 1] = table.concat current, " "
      current = {word}
    else
      current[#current + 1] = word
  rows[#rows + 1] = table.concat(current, " ") if #current > 0
  rows

Core.balanceWordsToRows = (words, rowCount, measure) ->
  rowCount = Core.clamp math.floor(tonumber(rowCount) or 1), 1, #words
  widths = {}
  for first = 1, #words
    widths[first] = {}
    text = ""
    for last = first, #words
      text = if text == "" then words[last] else text .. " " .. words[last]
      widths[first][last] = measure text
  costs = {[0]: {[0]: 0}}
  cuts = {}
  for rows = 1, rowCount
    costs[rows], cuts[rows] = {}, {}
    for last = rows, #words
      best, bestFirst = nil, nil
      for first = rows, last
        previous = costs[rows - 1] and costs[rows - 1][first - 1]
        continue if previous == nil
        score = math.max previous, widths[first][last]
        if best == nil or score < best
          best, bestFirst = score, first
      if bestFirst
        costs[rows][last] = best
        cuts[rows][last] = bestFirst
  rows, last = {}, #words
  for row = rowCount, 1, -1
    first = cuts[row] and cuts[row][last]
    return nil unless first
    table.insert rows, 1, table.concat(words, " ", first, last)
    last = first - 1
  rows

Core.fitTextToClipGuideText = (line, opts = {}) ->
  return nil, "drawing" if (Core.lineTagValue(line, "p", nil, 0) or 0) > 0
  axis = if opts.axis == "y" then "y" else "x"
  length, span = Core.clipGuideAxisLength line, axis
  return nil, "no_clip" unless span
  return nil, "zero_axis" unless length and length > 0.001
  prefix, body = Core.leadingBlocksAndBody(line and line.text or "")
  return nil, "inline_tags" if body\find("{", 1, true) or body\find("}", 1, true)
  normalized = tostring(body or "")\gsub("\\[Nn]", " ")\gsub("[\r\n\t]+", " ")\gsub(" +", " ")
  normalized = Core.trim normalized
  return nil, "no_text" if normalized == ""
  words = [word for word in normalized\gmatch "%S+"]
  return nil, "no_text" if #words == 0
  measure, lineHeight = Core.fitGuideMeasure line
  rows = if axis == "y"
    wanted = Core.clamp math.floor(length / lineHeight), 1, #words
    Core.balanceWordsToRows words, wanted, measure
  else
    Core.wrapWordsToWidth words, length, measure
  return nil, "no_text" unless rows and #rows > 0
  prefix .. table.concat(rows, "\\N"), nil, {
    :axis
    :length
    rows: #rows
    align: Core.alignForLine line
    clip_kind: span.name
  }

Core.opFitTextToClipGuide = (subs, sel, opts) ->
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    next_text = Core.fitTextToClipGuideText line, opts
    if next_text and next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No text could be fitted to a clip guide."
    return false
  aegisub.set_undo_point "Cliptomaniac - Fit text to clip guide"
  true

PerspectiveTools.normalizePerspectiveTags = (tags, line) ->
  return nil unless type(tags) == "table"
  styleRef = if line then (line.styleRef or line.styleref) else nil
  styleName = if line then line.style or "Default" else "Default"
  style = PerspectiveTools.measureStyle line, PerspectiveTools.style(styleRef, styleName)
  PerspectiveTools.ensureAlignTag(tags, style.align or 5)
  for item in *{
    {"scale_x", style.scale_x or 100}
    {"scale_y", style.scale_y or 100}
    {"angle", style.angle or 0}
    {"angle_x", 0}
    {"angle_y", 0}
    {"shear_x", 0}
    {"shear_y", 0}
    {"fontsize", style.fontsize or 20}
  }
    PerspectiveTools.ensureDimTag(tags, item[1], item[2])
  outline = PerspectiveTools.tagValue(tags.outline, style.outline or 0)
  shadow = PerspectiveTools.tagValue(tags.shadow, style.shadow or 0)
  PerspectiveTools.ensureDimTag(tags, "outline_x", outline)
  PerspectiveTools.ensureDimTag(tags, "outline_y", outline)
  PerspectiveTools.ensureDimTag(tags, "shadow_x", shadow)
  PerspectiveTools.ensureDimTag(tags, "shadow_y", shadow)
  pos = PerspectiveTools.ensurePointTag(tags, "position", PerspectiveTools.defaultPosition(line, style))
  PerspectiveTools.ensurePointTag(tags, "origin", pos)
  PerspectiveTools.syncDimTags(tags)

PerspectiveTools.line = (line) ->
  copy = Core.copyLine line
  copy.text = tostring(copy.text or "")
  styleName = copy.style or "Default"
  context = AssContext.resolve line, Core.lineContext
  style = PerspectiveTools.style(context.style, styleName)
  copy.styleRef = style
  copy.styleref = style
  copy.parentCollection = Core.lineContext if Core.lineContext
  unless copy.parentCollection
    video_x, video_y = 0, 0
    if aegisub and aegisub.video_size
      okVideo, rawX, rawY = pcall aegisub.video_size
      if okVideo
        video_x, video_y = tonumber(rawX) or 0, tonumber(rawY) or 0
    styles = {Default: style}
    styles[styleName] = style
    copy.parentCollection = {
      meta: {PlayResX: video_x, PlayResY: video_y}
      styles: styles
    }
  copy

PerspectiveTools.prepare = (line) ->
  pline = PerspectiveTools.line(line)
  data = nil
  okData, parsed = pcall -> Core.parseAssLine pline
  data = parsed if okData
  okPrep, tags, width, height = false, nil, nil, nil
  if data
    okPrep, tags, width, height = pcall -> ArchPerspective.prepareForPerspective ASS, data
    if okPrep and tags and PerspectiveTools.validDim(width) and PerspectiveTools.validDim(height) and PerspectiveTools.needsExtentOverride(pline, width, height)
      mw, mh = PerspectiveTools.textExtents pline, tags
      if PerspectiveTools.validDim(mw) and PerspectiveTools.validDim(mh)
        width, height = mw, mh
  unless okPrep and tags and PerspectiveTools.validDim(width) and PerspectiveTools.validDim(height)
    tags = PerspectiveTools.effectiveTags(data) or PerspectiveTools.rawTags(pline)
    width, height = PerspectiveTools.textExtents pline, tags
  return nil unless tags and PerspectiveTools.validDim(width) and PerspectiveTools.validDim(height)
  x, y, err = AssContext.position pline
  error err, 0 unless x and y
  ox, oy = AssContext.origin pline
  tags.position = {x: x, y: y}
  tags.origin = {x: ox, y: oy}
  PerspectiveTools.normalizePerspectiveTags(tags, pline)
  tags, width, height

PerspectiveTools.fail = (reason) ->
  PerspectiveTools.last_apply_error = reason or "apply failed"
  false

PerspectiveTools.tagsAreFinite = (tags) ->
  for name in *{"align", "scale_x", "scale_y", "angle", "angle_x", "angle_y", "shear_x", "shear_y"}
    return false, "non-finite tag #{name}" unless tags[name] and PerspectiveTools.finiteValue(PerspectiveTools.tagValue(tags[name], 0))
  return false, "missing position/origin" unless tags.position and tags.origin
  return false, "non-finite position/origin" unless PerspectiveTools.finiteValue(tags.position.x) and PerspectiveTools.finiteValue(tags.position.y) and PerspectiveTools.finiteValue(tags.origin.x) and PerspectiveTools.finiteValue(tags.origin.y)
  true

PerspectiveTools.applyTagsFromQuad = (tags, quad, width, height, line, orgMode) ->
  return PerspectiveTools.fail "bad quad" unless PerspectiveTools.validQuad(quad)
  return PerspectiveTools.fail "bad dimensions #{tostring(width)}x#{tostring(height)}" unless PerspectiveTools.validDim(width) and PerspectiveTools.validDim(height)
  PerspectiveTools.normalizePerspectiveTags(tags, line)
  ok, err = pcall ->
    q = ArchPerspective.Quad {quad[1], quad[2], quad[3], quad[4]}
    ArchPerspective.tagsFromQuad tags, q, width, height, orgMode or 3, Core.layoutScaleForLine(line)
  return PerspectiveTools.fail "tagsFromQuad failed: #{tostring(err)}" unless ok
  PerspectiveTools.syncDimTags tags
  finite, reason = PerspectiveTools.tagsAreFinite tags
  return PerspectiveTools.fail reason unless finite
  true

PerspectiveTools.rectAtQuad = (archQuad, tags, sx = 1, sy = 1) ->
  return nil unless archQuad and tags and ArchPerspective
  an = PerspectiveTools.alignValue PerspectiveTools.tagValue(tags.align, 5), 5
  xshift = (ArchPerspective.an_xshift and ArchPerspective.an_xshift[an]) or ({0, 0.5, 1, 0, 0.5, 1, 0, 0.5, 1})[an]
  yshift = (ArchPerspective.an_yshift and ArchPerspective.an_yshift[an]) or ({1, 1, 1, 0.5, 0.5, 0.5, 0, 0, 0})[an]
  return nil unless xshift and yshift
  base = {{0, 0}, {1, 0}, {1, 1}, {0, 1}}
  out = {}
  for i, p in ipairs base
    u = (p[1] - xshift) * sx + 0.5
    v = (p[2] - yshift) * sy + 0.5
    ok, mapped = pcall -> archQuad\uv_to_xy {u, v}
    return nil unless ok and mapped
    point = Core.matrixPoint mapped
    return nil unless point
    out[i] = {point.x, point.y}
  if PerspectiveTools.validQuad(out) then out else nil

PerspectiveTools.applyTagsFromPlane = (tags, quad, width, height, line, orgMode) ->
  return false unless PerspectiveTools.validQuad(quad) and PerspectiveTools.validDim(width) and PerspectiveTools.validDim(height)
  PerspectiveTools.normalizePerspectiveTags(tags, line)
  oldX = PerspectiveTools.tagValue tags.scale_x, 100
  oldY = PerspectiveTools.tagValue tags.scale_y, 100
  okQuad, archQuad = pcall -> ArchPerspective.Quad {quad[1], quad[2], quad[3], quad[4]}
  return false unless okQuad and archQuad
  rect = PerspectiveTools.rectAtQuad archQuad, tags, 1, 1
  return false unless rect and PerspectiveTools.applyTagsFromQuad(tags, rect, width, height, line, orgMode)
  curX = PerspectiveTools.tagValue tags.scale_x, oldX
  curY = PerspectiveTools.tagValue tags.scale_y, oldY
  return false unless PerspectiveTools.validDim(curX) and PerspectiveTools.validDim(curY)
  rect = PerspectiveTools.rectAtQuad archQuad, tags, oldX / curX, oldY / curY
  rect and PerspectiveTools.applyTagsFromQuad(tags, rect, width, height, line, orgMode)

PerspectiveTools.serialize = (line, tags) ->
  text = Core.removeTagNames line.text, {"frx", "fry", "frz", "fr", "fax", "fay", "fscx", "fscy", "org", "pos", "move", "t"}
  payload = string.format "\\frx%.4f\\fry%.4f\\frz%.4f\\fax%.6f\\fay%.6f\\fscx%.4f\\fscy%.4f\\org(%.3f,%.3f)\\pos(%.3f,%.3f)",
    PerspectiveTools.tagValue(tags.angle_x, 0), PerspectiveTools.tagValue(tags.angle_y, 0), PerspectiveTools.tagValue(tags.angle, 0),
    PerspectiveTools.tagValue(tags.shear_x, 0), PerspectiveTools.tagValue(tags.shear_y, 0),
    PerspectiveTools.tagValue(tags.scale_x, 100), PerspectiveTools.tagValue(tags.scale_y, 100),
    tags.origin.x, tags.origin.y,
    tags.position.x, tags.position.y
  line.text = Core.insertLeadingTags text, payload
  line.text = Core.cleanEmptyOverrides line.text

PerspectiveTools.applyQuad = (line, quad, opts) ->
  opts = {} unless type(opts) == "table"
  opts.perspective_map = opts.perspective_map or DEFAULTS.perspective_map
  opts.perspective_org_mode = opts.perspective_org_mode or DEFAULTS.perspective_org_mode
  opts.remove_clip = DEFAULTS.remove_clip if opts.remove_clip == nil
  PerspectiveTools.last_apply_error = nil
  tags, width, height = PerspectiveTools.prepare line
  return PerspectiveTools.fail "prepare failed" unless tags
  oriented = PerspectiveTools.orient quad, width, height
  mapped = PerspectiveTools.mapQuad oriented, opts.perspective_map
  return false unless PerspectiveTools.applyTagsFromQuad tags, mapped, width, height, line, PerspectiveTools.orgMode(opts.perspective_org_mode)
  PerspectiveTools.serialize line, tags
  line.extra = {} unless type(line.extra) == "table"
  plane = Core.planeExtraString mapped
  line.extra["_aegi_perspective_ambient_plane"] = plane if plane
  line.text = Core.stripClipTags line.text if opts.remove_clip
  true

Core.opClipToPerspective = (subs, sel, opts) ->
  unless ASS and ArchPerspective and ArchPerspective.prepareForPerspective and ArchPerspective.tagsFromQuad
    Core.showMessage "Perspective tools are not available."
    return false
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    quad = Core.quadFromClip line.text
    continue unless quad
    ok, appliedOrErr = pcall -> PerspectiveTools.applyQuad line, quad, opts
    if ok and appliedOrErr
      subs[i] = line
      changed += 1
    else
      detail = if appliedOrErr == false then (PerspectiveTools.last_apply_error or "apply failed") else tostring appliedOrErr
      Core.warn "Line #{i}: clip to perspective failed: #{detail}"
  if changed == 0
    Core.showMessage "No 4-point clip could be applied as perspective."
    return false
  aegisub.set_undo_point "Cliptomaniac - Clip to perspective"
  true

Core.perspectiveToClipText = (line, opts = {}) ->
  points, source = Core.perspectivePlanePointsForLine line, opts
  return nil unless points and #points >= 4
  clipTag = Core.vectorClipTag points, Core.clipTypeForLine(line, opts)
  text = Core.stripPerspectiveMarker line.text or ""
  text = Core.replaceOrInsertClip text, clipTag, true
  Core.cleanEmptyOverrides(text), points, source

Core.opPerspectiveToClip = (subs, sel, opts) ->
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    next_text, points = Core.perspectiveToClipText line, opts
    continue unless next_text
    if next_text != line.text
      line.text = next_text
      plane = Core.planeExtraStringFromPoints points
      if plane
        line.extra = {} unless type(line.extra) == "table"
        line.extra["_aegi_perspective_ambient_plane"] = plane
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No perspective plane could be converted to clip."
    return false
  aegisub.set_undo_point "Cliptomaniac - Perspective to clip"
  true

Core.opCompleteQuadrilateral = (subs, sel, opts) ->
  changed = 0
  for i in *Core.dialogueIndices(subs, sel)
    Core.checkCancelled!
    line = subs[i]
    next_text = Core.completeQuadrilateralText line
    if next_text and next_text != line.text
      line.text = next_text
      subs[i] = line
      changed += 1
  if changed == 0
    Core.showMessage "No 3-point vector clip could be completed."
    return false
  aegisub.set_undo_point "Cliptomaniac - Complete quadrilateral"
  true

actionMeta = {
  {"Measure clip", "direct", "Shows the length and angle of the first two guide strokes inside a clip."}
  {"Measure & transform clip", "options", "Uses two guide strokes as a before and after ruler, then adds a size animation."}
  {"Adjust by clip scale", "options", "Uses two guide strokes as rulers and resizes the selected text values."}
  {"Rescale by rectangle clip", "options", "Resizes text tags to fit a rectangular clip. Vector clips are intentionally rejected."}
  {"Bezier clip to curved text", "options", "Converts one cubic Bezier clip directly into clean per-character rotation and spacing tags."}
  {"Clip to FRZ", "options", "Turns the first guide stroke into the line rotation."}
  {"Clip to FAX", "options", "Turns the first guide stroke into the line slant."}
  {"Clip to FAY", "options", "Turns the first vertical guide stroke into the line Y slant."}
  {"Clip to reposition", "options", "Uses the first selected two-point clip as a shared source-to-target vector and translates every selected line without changing their relative layout."}
  {"Clip to move", "options", "Changes a fixed position into movement using the first guide stroke."}
  {"Position at clip midpoint", "direct", "Moves selected lines to the middle of their clip path, or to the first selected clip."}
  {"Align to clip", "direct", "Moves the line position onto the nearest point of the clip path."}
  {"Autofit clip to text", "options", "Makes the clip fit around the visible text, with padding, section choices, and optional full-duration transform bounds."}
  {"Fit text to clip guide", "options", "Uses the first clip or inverse-clip guide to wrap text on X or balance rows on Y without changing alignment."}
  {"Create clip around text", "options", "Creates a new clip around the visible text, including tilted, perspective, or transformed text."}
  {"Text to clip", "options", "Uses the actual text or drawing outline as the clip shape."}
  {"Expand clip margin", "options", "Grows or shrinks the selected clip by a pixel margin."}
  {"Shape to clip", "direct", "Uses the selected drawing as a clipping area."}
  {"Clip to shape", "direct", "Turns the first clip into an editable drawing."}
  {"Toggle clip/iclip", "direct", "Switches between showing inside the clip and hiding inside the clip."}
  {"Calibrate clip X", "direct", "Makes the first guide stroke perfectly horizontal."}
  {"Calibrate clip Y", "direct", "Makes the first guide stroke perfectly vertical."}
  {"Rectangle from diagonal", "direct", "Makes a rectangle from the first diagonal guide stroke."}
  {"Circle from 2 points", "direct", "Makes a circle using the first guide stroke as its diameter."}
  {"New clip shape", "direct", "Starts a new clip shape from the last point of the current clip path."}
  {"Copy clip/iclip", "direct", "Copies the first clip to matching selected lines, or from the first line to the rest."}
  {"Rect clip to vector", "direct", "Turns a simple rectangle clip into an editable path."}
  {"Vector clip to rect", "direct", "Turns an editable path clip into the smallest rectangle around it."}
  {"Add clip points", "options", "Adds points between existing clip points while preserving the current shape."}
  {"Remove clip points", "direct", "Removes alternating clip points while keeping each shape valid."}
  {"Clip to perspective", "options", "Uses a four-corner clip as the perspective plane for the line."}
  {"Perspective to clip", "direct", "Recreates a four-point clip from the stored perspective plane or current projected geometry."}
  {"Complete quadrilateral", "direct", "Adds D to a three-point A-B-C clip by closing opposite directions in the line's perspective plane."}
  {"Create strip clips", "options", "Splits a clip or text area, optionally including full-duration transform bounds, into thin clipped copies."}
  {"Animated clip to FBF", "options", "Bakes a moving or transformed clipped line into frame-by-frame clipped lines."}
  {"Export clip track to AE", "direct", "Concatenates the selected clip durations as After Effects Position, Scale, and Rotation keyframe data in the console."}
  {"Extract clip as mask line", "direct", "Creates a new drawing line from the first clip."}
  {"Clip boolean with text/shape", "options", "Combines the current clip with the selected text or drawing outline."}
  {"Clip diagnostics", "direct", "Shows clip type, size, points, and perspective-plane status."}
}

actionHelp = {}
actionDirect = {}
for item in *actionMeta
  actionHelp[item[1]] = item[3]
  actionDirect[item[1]] = item[2] == "direct"

actionHelpEs = {
  ["Clip to FAY"]: "Convierte el primer trazo vertical guia en inclinacion Y de la linea."
  ["Add clip points"]: "Anade puntos entre los puntos del clip conservando la forma actual."
  ["Remove clip points"]: "Quita puntos alternos del clip conservando cada forma valida."
  ["Perspective to clip"]: "Recrea un clip de cuatro puntos desde el plano de perspectiva guardado o desde la geometria proyectada actual."
  ["Complete quadrilateral"]: "Anade D a un clip A-B-C de tres puntos cerrando las direcciones opuestas en el plano de perspectiva de la linea."
  ["Autofit clip to text"]: "Ajusta el clip alrededor del texto visible, con margen, opciones por secciones y límites de transformación opcionales para toda la duración."
  ["Fit text to clip guide"]: "Usa la primera guia clip o iclip para insertar saltos en X o equilibrar filas en Y sin cambiar la alineacion."
  ["Create clip around text"]: "Crea un clip nuevo alrededor del texto visible, incluyendo texto inclinado, en perspectiva o transformado."
  ["Text to clip"]: "Usa el texto real o el contorno del dibujo como forma del clip."
  ["Expand clip margin"]: "Crece o reduce el clip seleccionado por un margen en píxeles."
  ["Copy clip/iclip"]: "Copia el primer clip a líneas compatibles, o desde la primera línea al resto."
  ["Shape to clip"]: "Usa el dibujo seleccionado como área de clip."
  ["Clip to shape"]: "Convierte el primer clip en un dibujo editable."
  ["Toggle clip/iclip"]: "Alterna entre mostrar dentro del clip y ocultar dentro del clip."
  ["Rect clip to vector"]: "Convierte un clip rectangular simple en una ruta editable."
  ["Vector clip to rect"]: "Convierte una ruta editable en el rectángulo mínimo que la contiene."
  ["Clip boolean with text/shape"]: "Combina el clip actual con el texto o el contorno del dibujo seleccionado."
  ["Extract clip as mask line"]: "Crea una nueva línea de dibujo a partir del primer clip."
  ["Position at clip midpoint"]: "Mueve las líneas seleccionadas al centro de su clip, o al primer clip seleccionado."
  ["Align to clip"]: "Mueve la posición de la línea al punto más cercano de la ruta del clip."
  ["Clip to reposition"]: "Usa el primer clip de dos puntos como vector origen-destino y traslada juntas todas las líneas seleccionadas."
  ["Clip to move"]: "Convierte una posición fija en movimiento usando el primer trazo guía."
  ["Clip to FRZ"]: "Convierte el primer trazo guía en rotación de la línea."
  ["Clip to FAX"]: "Convierte el primer trazo guía en inclinación de la línea."
  ["Measure clip"]: "Muestra longitud y ángulo de los dos primeros trazos guía dentro de un clip."
  ["Measure & transform clip"]: "Usa dos trazos guía como regla de antes y después, y añade una animación de tamaño."
  ["Adjust by clip scale"]: "Usa dos trazos guía como regla y escala los valores de texto seleccionados."
  ["Rescale by rectangle clip"]: "Escala tags de texto para ajustarlos a un clip rectangular. Los clips vectoriales se rechazan."
  ["Clip to perspective"]: "Usa un clip de cuatro esquinas como plano de perspectiva para la línea."
  ["Create strip clips"]: "Divide un clip o área de texto, con límites transformados opcionales para toda la duración, en copias con franjas finas."
  ["Animated clip to FBF"]: "Hornea una línea con clip movido o transformado en líneas frame a frame."
  ["Export clip track to AE"]: "Concatena la duración de los clips seleccionados como datos de Position, Scale y Rotation para After Effects en la consola."
  ["Calibrate clip X"]: "Endereza horizontalmente el primer trazo guía."
  ["Calibrate clip Y"]: "Endereza verticalmente el primer trazo guía."
  ["Rectangle from diagonal"]: "Crea un rectángulo desde el primer trazo diagonal."
  ["Circle from 2 points"]: "Crea un círculo usando el primer trazo como diámetro."
  ["New clip shape"]: "Empieza una forma de clip nueva desde el último punto de la ruta actual."
  ["Bezier clip to curved text"]: "Convierte un único clip Bézier cúbico directamente en rotación y espaciado limpios por carácter."
  ["Clip diagnostics"]: "Muestra tipo, tamaño, puntos y estado de perspectiva del clip."
}

readOnlyActions = {
  ["Measure clip"]: true
  ["Export clip track to AE"]: true
  ["Clip diagnostics"]: true
}

transformBoundsActions = {
  ["Autofit clip to text"]: true
  ["Create clip around text"]: true
  ["Create strip clips"]: true
}

sectionAxes = {"Horizontal", "Vertical"}

Core.boolOption = (res, key) ->
  if res[key] == nil
    DEFAULTS[key] and true or false
  else
    res[key] and true or false

Core.normalizeOptions = (res = {}) ->
  opts = {}
  opts.operation = Core.normalizeOperation res.operation
  stripDefaults = opts.operation == "Create strip clips"
  defaultMargin = if stripDefaults then 0 else DEFAULTS.margin
  defaultStylePad = if stripDefaults then false else DEFAULTS.style_pad
  opts.axis = Core.enumOption res.axis, AXES, DEFAULTS.axis
  opts.angle_mode = Core.enumOption res.angle_mode, angleModes, DEFAULTS.angle_mode
  opts.curve_depth = Core.clamp Core.finiteNumber(res.curve_depth) or DEFAULTS.curve_depth, 0
  opts.curve_spacing = Core.finiteNumber(res.curve_spacing) or DEFAULTS.curve_spacing
  opts.autofit_mode = Core.enumOption res.autofit_mode, autofitModes, autofitModes[1]
  opts.rescale_rect_mode = Core.enumOption res.rescale_rect_mode, rescaleRectModes, DEFAULTS.rescale_rect_mode
  opts.strip_mode = if Core.choiceRaw(res.strip_mode) == "Vertical" then "Vertical" else "Horizontal"
  opts.margin = Core.finiteNumber(res.margin) or defaultMargin
  opts.tolerance = Core.clamp Core.finiteNumber(res.tolerance) or DEFAULTS.tolerance, 1
  opts.strip = Core.clamp Core.finiteNumber(res.strip) or DEFAULTS.strip, 1
  opts.sections = Core.clamp math.floor(Core.finiteNumber(res.sections) or DEFAULTS.sections), 1
  opts.section_index = Core.clamp math.floor(Core.finiteNumber(res.section_index) or DEFAULTS.section_index), 1
  opts.bleed = Core.clamp Core.finiteNumber(res.bleed) or DEFAULTS.bleed, 0
  opts.no_shrink = Core.boolOption res, "no_shrink"
  opts.recenter = Core.boolOption res, "recenter"
  opts.style_pad = if res.style_pad == nil then defaultStylePad else Core.boolOption res, "style_pad"
  opts.transform_max_bounds = if transformBoundsActions[opts.operation] then Core.boolOption(res, "transform_max_bounds") else false
  opts.replace_clip = Core.boolOption res, "replace_clip"
  opts.remove_clip = Core.boolOption res, "remove_clip"
  opts.create_new_lines = Core.boolOption res, "create_new_lines"
  opts.comment_source = Core.boolOption res, "comment_source"
  opts.point_mode = Core.enumOption res.point_mode, pointInsertModes, DEFAULTS.point_mode
  opts.point_distance = Core.clamp Core.finiteNumber(res.point_distance) or DEFAULTS.point_distance, 0.1
  opts.point_count = Core.clamp math.floor(Core.finiteNumber(res.point_count) or DEFAULTS.point_count), 1
  opts.clip_type = Core.enumOption res.clip_type, clipTypes, DEFAULTS.clip_type
  opts.close_paths = Core.boolOption res, "close_paths"
  opts.merge_identical = Core.boolOption res, "merge_identical"
  opts.max_frames = Core.clamp math.floor(Core.finiteNumber(res.max_frames) or DEFAULTS.max_frames), minFbfFrameBudget
  opts.fbf_source = Core.enumOption res.fbf_source, fbfSources, DEFAULTS.fbf_source
  opts.boolean_mode = Core.enumOption res.boolean_mode, booleanModes, DEFAULTS.boolean_mode
  opts.perspective_map = Core.normalizePerspectiveMap res.perspective_map
  opts.perspective_org_mode = Core.normalizePerspectiveOrg res.perspective_org_mode
  opts.info = Core.boolOption res, "info"
  for key in *{"adj_fscx", "adj_fscy", "adj_fs", "adj_fsp", "adj_bord", "adj_shad", "adj_blur"}
    opts[key] = Core.boolOption res, key
  opts

Core.actionModeLabel = (operation) ->
  if actionDirect[operation] then Core.L("runs_now") else Core.L("opens_settings")

Core.actionHelp = (operation) ->
  if current_language == "es"
    actionHelpEs[operation] or actionHelp[operation] or ""
  else
    actionHelp[operation] or ""

Core.actionHelpLine = (operation) ->
  "[#{Core.actionModeLabel operation}] #{Core.operationLabel operation}: #{Core.actionHelp(operation)}"

controlHelpEs = {
  ["Add clip points"]: {
    "Anadir por: elige distancia fija en pixeles o cantidad fija por tramo original."
    "Distancia: inserta puntos a este intervalo y deja el resto final antes del siguiente punto original."
    "Puntos: inserta esta cantidad de puntos equidistantes entre cada par de puntos originales."
  }
  ["Measure & transform clip"]: {
    "Eje: elige si la guía cambia ancho o alto."
    "Ángulo: decide si la guía también aplica rotación."
    "Mostrar reporte: muestra medidas después de aplicar."
  }
  ["Adjust by clip scale"]: {
    "Eje: elige ancho, alto o ambos."
    "fscx: escala el ancho del texto."
    "fscy: escala el alto del texto."
    "fs: escala el tamaño de fuente."
    "fsp: escala el espaciado."
    "bord: escala el borde."
    "shad: escala la sombra."
    "blur: escala blur y edge blur."
    "Mostrar reporte: muestra el porcentaje aplicado."
  }
  ["Rescale by rectangle clip"]: {
    "Modo: Encajar conserva todo dentro; Rellenar cubre el rectángulo; Estirar usa ancho y alto separados."
    "Centrar: mueve \\pos al ancla del rectángulo según la alineación."
    "Quitar clip guía: borra el clip rectangular después de usarlo."
    "ancho/alto: escala \\fscx y \\fscy."
    "espacio/borde/sombra/blur: escala esas dimensiones."
    "Los clips vectoriales se rechazan; usa primero un clip rectangular."
  }
  ["Bezier clip to curved text"]: {
    "Profundidad: 100% crea un arco circular compensado desde el clip; 0% lo endereza y valores mayores lo hunden más."
    "fsp adicional: suma separación uniforme al espaciado efectivo de la línea."
    "Quitar clip guía: borra el clip después de convertir la curvatura."
  }
  ["Clip to FRZ"]: {"Quitar clip guía: borra el clip después de usarlo como guía."}
  ["Clip to FAX"]: {"Quitar clip guía: borra el clip después de usarlo como guía."}
  ["Clip to reposition"]: {
    "El primer clip recto de dos puntos seleccionado define el desplazamiento para toda la selección."
    "Quitar clip guía: borra solo ese clip de referencia; los demás clips se trasladan con sus líneas."
  }
  ["Clip to move"]: {"Quitar clip guía: borra el clip después de usarlo como guía."}
  ["Clip to perspective"]: {
    "Esquinas: elige como se leen las cuatro esquinas del clip."
    "Origen: elige el ancla de la línea después de aplicar perspectiva."
    "Quitar clip guía: borra el clip después de usarlo como guía."
  }
  ["Autofit clip to text"]: {
    "Modo: elige que parte del texto debe cubrir el clip."
    "Eje: divide el texto de izquierda a derecha o de arriba a abajo."
    "Margen: suma o resta píxeles alrededor del clip."
    "Tolerancia: valores altos simplifican el resultado; valores bajos conservan más detalle."
    "Partes: cantidad de partes iguales."
    "Índice: parte que se usa en modo personalizado."
    "Solape: solapa partes vecinas para evitar huecos pequeños."
    "No reducir: nunca hace el clip nuevo menor que el anterior."
    "Incluir estilo: incluye borde, sombra y blur en el área."
    "Máximos de \\t: une los límites renderizados de todos los frames, respeta \\an e ignora clip/iclip solo durante la medición."
    "Con máximos de \\t se necesita un vídeo cargado; el render ya incluye el estilo visible y no se suma dos veces."
    "El resultado temporal consolida todos los clip/iclip en un único clip estático y conserva su tipo."
  }
  ["Fit text to clip guide"]: {
    "Eje X: usa la distancia horizontal de la guia como ancho maximo."
    "Eje Y: usa la distancia vertical para calcular y equilibrar la cantidad de filas."
    "Conserva an y conserva clip o iclip sin convertirlo ni borrarlo."
  }
  ["Create clip around text"]: {
    "Margen: suma o resta píxeles alrededor del texto."
    "Tolerancia: valores altos simplifican clips de texto."
    "Incluir estilo: incluye borde, sombra y blur en el área."
    "Reemplazar clip: sobrescribe el primero; con máximos de \\t consolida todos en un único clip estático."
    "Máximos de \\t: une los límites renderizados de todos los frames, respeta \\an e ignora clip/iclip solo durante la medición."
    "Con máximos de \\t se necesita un vídeo cargado; el render ya incluye el estilo visible y conserva clip o iclip al reemplazar."
  }
  ["Text to clip"]: {
    "Tipo: elige clip normal, inverse clip o conservar el actual."
    "Margen: suma o resta píxeles alrededor del contorno del texto."
    "Tolerancia: valores altos simplifican el contorno."
    "Cerrar rutas: conecta huecos del contorno al construir el clip."
    "Reemplazar clip: sobrescribe el primer clip existente."
    "Comentar original: deja apagada la línea original y crea una copia con clip."
  }
  ["Expand clip margin"]: {
    "Margen: valores positivos crecen el clip; negativos lo reducen."
    "Tolerancia: valores altos simplifican rutas editadas."
  }
  ["Create strip clips"]: {
    "Franjas: elige si las franjas cruzan horizontal o verticalmente. Detecta inclinación y perspectiva."
    "Tamaño: tamaño aproximado de cada franja en píxeles."
    "Crear líneas: crea una línea duplicada por franja."
    "Comentar original: conserva la original apagada al crear duplicados."
    "Máximos de \\t: si no hay clip guía, une los límites renderizados de todos los frames; requiere vídeo cargado."
  }
  ["Animated clip to FBF"]: {
    "Hornear: elige si conserva toda la línea o solo copia el clip."
    "Frames max: presupuesto opcional de líneas de salida; 0 lo desactiva."
    "Unir iguales: une frames vecinos cuando el clip final es idéntico."
    "Comentar original: conserva la línea original apagada."
  }
  ["Clip boolean with text/shape"]: {
    "Booleano: conserva solo la intersección o recorta la forma del texto del clip."
    "Tolerancia: valores altos simplifican el resultado."
    "Cerrar rutas: conecta contornos abiertos antes de combinar."
  }
}

Core.operationControlHelp = (operation) ->
  return controlHelpEs[operation] if current_language == "es" and controlHelpEs[operation]
  switch operation
    when "Measure & transform clip"
      {
        "Axis: choose whether the ruler changes width or height."
        "Angle mode: choose if the guide also sets rotation."
        "Show report: show the measured sizes after applying."
      }
    when "Adjust by clip scale"
      {
        "Axis: choose width, height, or both."
        "fscx: resize the text width."
        "fscy: resize the text height."
        "fs: resize the font size."
        "fsp: resize letter spacing."
        "bord: resize the outline."
        "shad: resize the shadow."
        "blur: resize blur and edge blur."
        "Show report: show the percentage that was applied."
      }
    when "Rescale by rectangle clip"
      {
        "Mode: Fit keeps the whole text inside; Fill covers the rectangle; Stretch uses separate width and height factors."
        "Center: move \\pos to the rectangle anchor for the line alignment."
        "Remove guide clip: delete the rectangle clip after it has been used."
        "width/height: scale \\fscx and \\fscy."
        "spacing/outline/shadow/blur: scale those dimensions like Rhea's Rescale to Clip."
        "Vector clips are rejected. Use Rect clip to vector only after this operation, not before it."
      }
    when "Bezier clip to curved text"
      {
        "Curve depth: 100% builds a compensated circular arc from the clip; 0% straightens it and larger values deepen it."
        "Extra fsp: add uniform spacing to the line's effective letter spacing."
        "Remove guide clip: delete the clip after converting the curve."
      }
    when "Clip to reposition"
      {
        "The first selected straight two-point clip defines the displacement for the whole selection."
        "Remove guide clip: delete only that reference clip; other clips move with their lines."
      }
    when "Clip to FRZ", "Clip to FAX", "Clip to FAY", "Clip to move"
      {
        "Remove guide clip: delete the clip after it has been used as a guide."
      }
    when "Clip to perspective"
      {
        "Corner order: choose how the four clip corners are read."
        "Origin: choose how the line anchor is chosen after the perspective is applied."
        "Remove guide clip: delete the clip after it has been used as a guide."
      }
    when "Autofit clip to text"
      {
        "Mode: choose which part of the text the new clip should cover."
        "Section axis: split the text from left to right or from top to bottom."
        "Margin: add or remove extra pixels around the fitted clip."
        "Tolerance: higher values make the result simpler; lower values keep more detail."
        "Sections: how many equal parts to split the text into."
        "Index: which part to use when Mode is Custom section."
        "Bleed: overlap between neighboring sections so tiny gaps do not appear."
        "No shrink: never make the new clip smaller than the old one."
        "Style pad: include outline, shadow, and blur in the fitted area."
        "Transform maxima: union rendered bounds from every frame, honor \\an, and ignore clip/iclip only while measuring."
        "Transform maxima requires a loaded video; rendered bounds already include visible style and are not padded twice."
        "The temporal result consolidates every clip/iclip into one static clip and preserves its kind."
      }
    when "Fit text to clip guide"
      {
        "X axis: use the guide's horizontal distance as the maximum line width."
        "Y axis: use the guide's vertical distance to choose and balance the row count."
        "Keep the effective alignment and preserve clip or iclip without converting or removing it."
      }
    when "Create clip around text"
      {
        "Margin: add or remove extra pixels around the text."
        "Tolerance: higher values make regular text clips simpler."
        "Style pad: include outline, shadow, and blur in the clipped area."
        "Replace existing clip: overwrite the first clip; with transform maxima, consolidate all clips into one static clip."
        "Transform maxima: union rendered bounds from every frame, honor \\an, and ignore clip/iclip only while measuring."
        "Transform maxima requires a loaded video; rendered bounds include visible style and preserve clip or iclip when replacing."
      }
    when "Text to clip"
      {
        "Clip type: choose normal clip, inverse clip, or keep the current kind."
        "Margin: add or remove extra pixels around the text outline."
        "Tolerance: higher values make the outline simpler."
        "Close paths: connect outline gaps when building the clip."
        "Replace existing clip: overwrite the first clip already on the line."
        "Comment source: keep the original line off and create a clipped copy."
      }
    when "Expand clip margin"
      {
        "Margin: positive values grow the clip; negative values shrink it."
        "Tolerance: higher values make edited paths simpler."
      }
    when "Add clip points"
      {
        "Add by: choose fixed pixel spacing or a fixed number of inserted points per original segment."
        "Distance: when adding by distance, insert points at this pixel interval and leave any final remainder before the next original point."
        "Points: when adding by count, insert this many evenly spaced points between each pair of original points."
      }
    when "Create strip clips"
      {
        "Strip mode: choose whether strips go across or down. Tilt and perspective are detected from the line."
        "Strip size: approximate pixel size of each strip."
        "Create new lines: make one duplicate line per strip."
        "Comment source: when creating duplicates, keep the original line but turn it off."
        "Transform maxima: when there is no guide clip, union rendered bounds from every frame; a loaded video is required."
      }
    when "Animated clip to FBF"
      {
        "Bake source: choose whether to keep the whole baked line or only copy its clip."
        "Max frames: optional output-line budget; 0 disables it."
        "Merge identical: join neighboring frames when their final clip is the same."
        "Comment source: keep the original line but turn it off."
      }
    when "Clip boolean with text/shape"
      {
        "Boolean mode: keep only the overlap, or cut the text shape out of the clip."
        "Tolerance: higher values make the result simpler."
        "Close paths: connect open outlines before combining."
      }
    else
      {}

Core.operationHelpText = (operation) ->
  lines = {
    "[#{Core.actionModeLabel operation}] #{Core.operationLabel operation}"
    ""
    Core.L("what_it_does")
    Core.actionHelp(operation)
  }
  controls = Core.operationControlHelp operation
  lines[#lines + 1] = ""
  if #controls > 0
    lines[#lines + 1] = Core.L("controls")
    for line in *controls
      lines[#lines + 1] = line
  else
    lines[#lines + 1] = Core.L("controls")
    lines[#lines + 1] = Core.L("no_extra_controls")
  table.concat lines, "\n"

Core.pickerHelpText = (operation) ->
  table.concat {
    Core.operationHelpText operation
    ""
    Core.L("picker_refresh")
    Core.L("picker_run")
  }, "\n"

Core.configSection = (operation) ->
  return "main" unless operation
  key = tostring(operation)\lower!
  key = key\gsub "[^%w]+", "_"
  "action_" .. key

Core.configEntriesForGui = (gui) ->
  entries = {}
  for item in *(gui or {})
    if item.name
      item.config = true
      entries[item.name] = item
  entries

Core.languageEntry = ->
  {class: "edit", name: "language", value: current_language, config: true}

Core.addLanguageEntry = (entries) ->
  entries.language = Core.languageEntry!
  entries

Core.languageConfig = ->
  return nil unless ConfigHandler
  languageConfigHandler or= ConfigHandler Core.configInterface!, configFile, true, script_version
  languageConfigHandler

Core.loadLanguage = ->
  options = Core.languageConfig!
  return current_language unless options
  pcall -> options\read!
  lang = options.configuration and options.configuration.main and options.configuration.main.language
  current_language = Core.validLanguage lang
  current_language

Core.saveLanguage = ->
  options = Core.languageConfig!
  return false unless options
  pcall -> options\read!
  options.configuration or= {}
  options.configuration.main or= {}
  options.configuration.main.language = Core.validLanguage current_language
  pcall -> options\write!

Core.toggleLanguage = ->
  current_language = if current_language == "es" then "en" else "es"
  Core.saveLanguage!
  current_language

Core.configInterface = (section, gui) ->
  interface = {}
  interface.main = Core.addLanguageEntry Core.configEntriesForGui(Core.actionPickerGui(DEFAULTS.operation))
  for operation in *OPERATIONS
    continue if actionDirect[operation]
    opSection = Core.configSection operation
    interface[opSection] = Core.configEntriesForGui Core.optionsGui(operation)
  if section and gui
    entries = Core.configEntriesForGui gui
    entries = Core.addLanguageEntry entries if section == "main"
    interface[section] = entries
  interface

Core.readConfiguredGui = (section, gui) ->
  Core.loadLanguage!
  return nil unless ConfigHandler
  interface = Core.configInterface section, gui
  ok, options = pcall -> ConfigHandler interface, configFile, true, script_version
  unless ok and options
    Core.warn "ConfigHandler failed for #{section}: #{options}"
    return nil
  okRead, err_read = pcall -> options\read!
  Core.warn "Could not read config for #{section}: #{err_read}" unless okRead
  lang = options.configuration and options.configuration.main and options.configuration.main.language
  current_language = Core.validLanguage lang
  okUpdate, err_update = pcall -> options\updateInterface section
  Core.warn "Could not apply config for #{section}: #{err_update}" unless okUpdate
  Core.localizeDropdownValues gui
  options

Core.saveConfiguredGui = (options, result, section) ->
  return true unless options and result
  ok, saved, err = pcall ->
    options.configuration.main.language = current_language if options.configuration and options.configuration.main
    result.language = current_language if section == "main"
    options\updateConfiguration result, section
    options\write!
  Core.warn "Could not save config for #{section}: #{tostring(if ok then err else saved)}" unless ok and saved != false
  ok and saved != false

Core.controlValue = (gui, name, fallback = nil) ->
  for item in *(gui or {})
    return item.value if item.name == name and item.value != nil
  fallback

Core.localizeDropdownValues = (gui) ->
  for item in *(gui or {})
    if item.class == "dropdown" and item.value != nil and item.items
      raw = Core.choiceRaw item.value
      shown = Core.choiceLabel raw
      if shown != item.value
        for candidate in *item.items
          if candidate == shown
            item.value = shown
            break
  gui

WINDOW_W = 24
PICKER_HELP_H = 16
OPTION_HELP_H = 16
optionYShift = 17

Core.actionPickerGui = (operation) ->
  items, to_raw, toShown = Core.dropdownData OPERATIONS, Core.operationLabel
  gui = {
    {class: "label", label: Core.L("action"), x: 0, y: 0, width: 3}
    {class: "dropdown", name: "operation", items: items, value: Core.shownChoice(toShown, operation or DEFAULTS.operation), x: 3, y: 0, width: WINDOW_W - 3}
    {class: "textbox", value: Core.pickerHelpText(operation or DEFAULTS.operation), x: 0, y: 1, width: WINDOW_W, height: PICKER_HELP_H}
  }
  gui, to_raw, toShown

Core.actionPicker = ->
  onHelp = (chosen, _result, context) ->
    Core.saveConfiguredGui context.options, {operation: chosen}, "main"
  onLanguage = -> Core.toggleLanguage!
  onRun = (_chosen, result, context) ->
    Core.saveConfiguredGui context.options, result, "main"
  Core.UI.chooseAction {
    current: DEFAULTS.operation
    build: (current) ->
      Core.loadLanguage!
      gui, to_raw, toShown = Core.actionPickerGui current
      options = Core.readConfiguredGui "main", gui
      selected = Core.rawOperationChoice to_raw, Core.controlValue(gui, "operation", Core.shownChoice(toShown, current))
      gui[2].value = Core.shownChoice toShown, selected
      gui[3].value = Core.pickerHelpText selected
      gui, {to_raw: to_raw, options: options}
    buttons: ->
      run, help, language, cancel = Core.L("run"), Core.L("help"), Core.L("language"), Core.L("cancel")
      {run: run, help: help, language: language, cancel: cancel, order: {run, help, language, cancel}}
    read: (result, current, context) ->
      Core.rawOperationChoice context.to_raw, result and result.operation or current
    on_help: onHelp
    on_language: onLanguage
    on_run: onRun
  }

Core.actionHelpPicker = ->
  current = DEFAULTS.operation
  while true
    Core.loadLanguage!
    gui, to_raw, toShown = Core.actionPickerGui current
    options = Core.readConfiguredGui "main", gui
    current = Core.rawOperationChoice to_raw, Core.controlValue(gui, "operation", Core.shownChoice(toShown, current))
    gui[2].value = Core.shownChoice toShown, current
    gui[3].value = Core.pickerHelpText current
    btn_help, btnLanguage, btn_close = Core.L("help"), Core.L("language"), Core.L("close")
    button, res = aegisub.dialog.display gui, {btn_help, btnLanguage, btn_close}, {ok: btn_help, close: btn_close}
    if button == btn_help
      chosen = Core.rawOperationChoice to_raw, res and res.operation or current
      Core.saveConfiguredGui options, {operation: chosen}, "main"
      current = chosen
    elseif button == btnLanguage
      current = Core.rawOperationChoice to_raw, res and res.operation or current
      Core.toggleLanguage!
    else
      return

Core.baseOptionGui = (operation) ->
  help_value = Core.operationHelpText operation
  {
    {class: "label", label: Core.operationLabel(operation), x: 0, y: 0, width: WINDOW_W}
    {class: "textbox", value: help_value, x: 0, y: 1, width: WINDOW_W, height: OPTION_HELP_H}
  }

Core.addRemoveClip = (gui, y) ->
  gui[#gui + 1] = {class: "checkbox", name: "remove_clip", label: Core.L("remove_guide_clip"), value: DEFAULTS.remove_clip, x: 0, y: y, width: 6}

Core.shiftOptionControls = (gui, firstIndex, amount) ->
  for idx = firstIndex, #gui
    gui[idx].y += amount if gui[idx] and gui[idx].y
  gui

Core.optionsGui = (operation) ->
  gui = Core.baseOptionGui operation
  controlStart = #gui + 1
  switch operation
    when "Measure & transform clip"
      gui[#gui + 1] = {class: "label", label: Core.L("axis"), x: 0, y: 4, width: 3}
      gui[#gui + 1] = {class: "dropdown", name: "axis", items: Core.localizedItems({"x", "y"}), value: Core.choiceLabel("x"), x: 3, y: 4, width: 5}
      gui[#gui + 1] = {class: "label", label: Core.L("angle_mode"), x: 0, y: 5, width: 3}
      gui[#gui + 1] = {class: "dropdown", name: "angle_mode", items: Core.localizedItems(angleModes), value: Core.choiceLabel(DEFAULTS.angle_mode), x: 3, y: 5, width: 8}
      gui[#gui + 1] = {class: "checkbox", name: "info", label: Core.L("show_report"), value: DEFAULTS.info, x: 0, y: 6, width: 5}
    when "Adjust by clip scale"
      gui[#gui + 1] = {class: "label", label: Core.L("axis"), x: 0, y: 4, width: 3}
      gui[#gui + 1] = {class: "dropdown", name: "axis", items: Core.localizedItems(AXES), value: Core.choiceLabel(DEFAULTS.axis), x: 3, y: 4, width: 5}
      gui[#gui + 1] = {class: "label", label: Core.L("resize"), x: 0, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "adj_fscx", label: Core.L("width"), value: DEFAULTS.adj_fscx, x: 3, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "adj_fscy", label: Core.L("height"), value: DEFAULTS.adj_fscy, x: 6, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "adj_fs", label: Core.L("font"), value: DEFAULTS.adj_fs, x: 9, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "adj_fsp", label: Core.L("spacing"), value: DEFAULTS.adj_fsp, x: 12, y: 5, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "adj_bord", label: Core.L("outline"), value: DEFAULTS.adj_bord, x: 3, y: 6, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "adj_shad", label: Core.L("shadow"), value: DEFAULTS.adj_shad, x: 7, y: 6, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "adj_blur", label: Core.L("blur"), value: DEFAULTS.adj_blur, x: 11, y: 6, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "info", label: Core.L("show_report"), value: DEFAULTS.info, x: 0, y: 7, width: 5}
    when "Rescale by rectangle clip"
      gui[#gui + 1] = {class: "label", label: Core.L("mode"), x: 0, y: 4, width: 3}
      gui[#gui + 1] = {class: "dropdown", name: "rescale_rect_mode", items: Core.localizedItems(rescaleRectModes), value: Core.choiceLabel(DEFAULTS.rescale_rect_mode), x: 3, y: 4, width: 9}
      gui[#gui + 1] = {class: "label", label: Core.L("scale"), x: 0, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "adj_fscx", label: Core.L("width"), value: DEFAULTS.adj_fscx, x: 3, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "adj_fscy", label: Core.L("height"), value: DEFAULTS.adj_fscy, x: 6, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "adj_fsp", label: Core.L("spacing"), value: DEFAULTS.adj_fsp, x: 9, y: 5, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "adj_bord", label: Core.L("outline"), value: DEFAULTS.adj_bord, x: 3, y: 6, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "adj_shad", label: Core.L("shadow"), value: DEFAULTS.adj_shad, x: 7, y: 6, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "adj_blur", label: Core.L("blur"), value: DEFAULTS.adj_blur, x: 11, y: 6, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "recenter", label: Core.L("center"), value: DEFAULTS.recenter, x: 0, y: 7, width: 4}
      Core.addRemoveClip gui, 8
      gui[#gui + 1] = {class: "checkbox", name: "info", label: Core.L("show_report"), value: DEFAULTS.info, x: 6, y: 8, width: 5}
    when "Bezier clip to curved text"
      gui[#gui + 1] = {class: "label", label: Core.L("curve_depth"), x: 0, y: 4, width: 5}
      gui[#gui + 1] = {class: "intedit", name: "curve_depth", value: DEFAULTS.curve_depth, min: 0, x: 5, y: 4, width: 3}
      gui[#gui + 1] = {class: "label", label: Core.L("curve_spacing"), x: 0, y: 5, width: 5}
      gui[#gui + 1] = {class: "floatedit", name: "curve_spacing", value: DEFAULTS.curve_spacing, x: 5, y: 5, width: 3}
      Core.addRemoveClip gui, 6
    when "Clip to FRZ", "Clip to FAX", "Clip to FAY", "Clip to reposition", "Clip to move"
      Core.addRemoveClip gui, 4
    when "Clip to perspective"
      gui[#gui + 1] = {class: "label", label: Core.L("corner_order"), x: 0, y: 4, width: 4}
      gui[#gui + 1] = {class: "dropdown", name: "perspective_map", items: Core.localizedItems(PerspectiveTools.mapItems!), value: Core.choiceLabel(DEFAULTS.perspective_map), x: 4, y: 4, width: 9}
      gui[#gui + 1] = {class: "label", label: Core.L("origin"), x: 0, y: 5, width: 4}
      gui[#gui + 1] = {class: "dropdown", name: "perspective_org_mode", items: Core.localizedItems(perspectiveData.org_modes), value: Core.choiceLabel(DEFAULTS.perspective_org_mode), x: 4, y: 5, width: 9}
      Core.addRemoveClip gui, 6
    when "Fit text to clip guide"
      gui[#gui + 1] = {class: "label", label: Core.L("axis"), x: 0, y: 4, width: 3}
      gui[#gui + 1] = {class: "dropdown", name: "axis", items: Core.localizedItems({"x", "y"}), value: Core.choiceLabel(DEFAULTS.axis), x: 3, y: 4, width: 5}
    when "Autofit clip to text"
      gui[#gui + 1] = {class: "label", label: Core.L("mode"), x: 0, y: 4, width: 3}
      gui[#gui + 1] = {class: "dropdown", name: "autofit_mode", items: Core.localizedItems(autofitModes), value: Core.choiceLabel(autofitModes[1]), x: 3, y: 4, width: 10}
      gui[#gui + 1] = {class: "label", label: Core.L("section_axis"), x: 0, y: 5, width: 3}
      gui[#gui + 1] = {class: "dropdown", name: "strip_mode", items: Core.localizedItems(sectionAxes), value: Core.choiceLabel("Horizontal"), x: 3, y: 5, width: 6}
      gui[#gui + 1] = {class: "label", label: Core.L("margin"), x: 0, y: 6, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "margin", value: DEFAULTS.margin, x: 3, y: 6, width: 3}
      gui[#gui + 1] = {class: "label", label: Core.L("tolerance"), x: 7, y: 6, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "tolerance", value: DEFAULTS.tolerance, min: 1, x: 10, y: 6, width: 3}
      gui[#gui + 1] = {class: "label", label: Core.L("sections"), x: 0, y: 7, width: 3}
      gui[#gui + 1] = {class: "intedit", name: "sections", value: DEFAULTS.sections, min: 1, x: 3, y: 7, width: 3}
      gui[#gui + 1] = {class: "label", label: Core.L("index"), x: 7, y: 7, width: 2}
      gui[#gui + 1] = {class: "intedit", name: "section_index", value: DEFAULTS.section_index, min: 1, x: 9, y: 7, width: 3}
      gui[#gui + 1] = {class: "label", label: Core.L("bleed"), x: 13, y: 7, width: 2}
      gui[#gui + 1] = {class: "floatedit", name: "bleed", value: DEFAULTS.bleed, min: 0, x: 15, y: 7, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "no_shrink", label: Core.L("no_shrink"), value: DEFAULTS.no_shrink, x: 0, y: 8, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "style_pad", label: Core.L("style_pad"), value: DEFAULTS.style_pad, x: 4, y: 8, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "transform_max_bounds", label: Core.L("transform_max_bounds"), value: DEFAULTS.transform_max_bounds, x: 8, y: 8, width: 10}
    when "Create clip around text"
      gui[#gui + 1] = {class: "label", label: Core.L("margin"), x: 0, y: 4, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "margin", value: DEFAULTS.margin, x: 3, y: 4, width: 3}
      gui[#gui + 1] = {class: "label", label: Core.L("tolerance"), x: 7, y: 4, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "tolerance", value: DEFAULTS.tolerance, min: 1, x: 10, y: 4, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "style_pad", label: Core.L("style_pad"), value: DEFAULTS.style_pad, x: 0, y: 5, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "replace_clip", label: Core.L("replace_existing_clip"), value: DEFAULTS.replace_clip, x: 4, y: 5, width: 7}
      gui[#gui + 1] = {class: "checkbox", name: "transform_max_bounds", label: Core.L("transform_max_bounds"), value: DEFAULTS.transform_max_bounds, x: 0, y: 6, width: 10}
    when "Text to clip"
      gui[#gui + 1] = {class: "label", label: Core.L("clip_type"), x: 0, y: 4, width: 3}
      gui[#gui + 1] = {class: "dropdown", name: "clip_type", items: Core.localizedItems(clipTypes), value: Core.choiceLabel(DEFAULTS.clip_type), x: 3, y: 4, width: 5}
      gui[#gui + 1] = {class: "label", label: Core.L("margin"), x: 9, y: 4, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "margin", value: DEFAULTS.margin, x: 12, y: 4, width: 3}
      gui[#gui + 1] = {class: "label", label: Core.L("tolerance"), x: 0, y: 5, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "tolerance", value: DEFAULTS.tolerance, min: 1, x: 3, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "close_paths", label: Core.L("close_paths"), value: DEFAULTS.close_paths, x: 0, y: 6, width: 5}
      gui[#gui + 1] = {class: "checkbox", name: "replace_clip", label: Core.L("replace_existing_clip"), value: DEFAULTS.replace_clip, x: 5, y: 6, width: 7}
      gui[#gui + 1] = {class: "checkbox", name: "comment_source", label: Core.L("comment_source"), value: DEFAULTS.comment_source, x: 0, y: 7, width: 6}
    when "Expand clip margin"
      gui[#gui + 1] = {class: "label", label: Core.L("margin"), x: 0, y: 4, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "margin", value: DEFAULTS.margin, x: 3, y: 4, width: 3}
      gui[#gui + 1] = {class: "label", label: Core.L("tolerance"), x: 0, y: 5, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "tolerance", value: DEFAULTS.tolerance, min: 1, x: 3, y: 5, width: 3}
    when "Add clip points"
      gui[#gui + 1] = {class: "label", label: Core.L("point_mode"), x: 0, y: 4, width: 4}
      gui[#gui + 1] = {class: "dropdown", name: "point_mode", items: Core.localizedItems(pointInsertModes), value: Core.choiceLabel(DEFAULTS.point_mode), x: 4, y: 4, width: 7}
      gui[#gui + 1] = {class: "label", label: Core.L("point_distance"), x: 0, y: 5, width: 4}
      gui[#gui + 1] = {class: "floatedit", name: "point_distance", value: DEFAULTS.point_distance, min: 0.1, x: 4, y: 5, width: 4}
      gui[#gui + 1] = {class: "label", label: Core.L("point_count"), x: 0, y: 6, width: 4}
      gui[#gui + 1] = {class: "intedit", name: "point_count", value: DEFAULTS.point_count, min: 1, x: 4, y: 6, width: 4}
    when "Create strip clips"
      gui[#gui + 1] = {class: "label", label: Core.L("strip_mode"), x: 0, y: 4, width: 4}
      gui[#gui + 1] = {class: "dropdown", name: "strip_mode", items: Core.localizedItems(stripModes), value: Core.choiceLabel(DEFAULTS.strip_mode), x: 4, y: 4, width: 6}
      gui[#gui + 1] = {class: "label", label: Core.L("strip_size"), x: 0, y: 5, width: 4}
      gui[#gui + 1] = {class: "floatedit", name: "strip", value: DEFAULTS.strip, min: 1, x: 4, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "create_new_lines", label: Core.L("create_new_lines"), value: DEFAULTS.create_new_lines, x: 0, y: 6, width: 6}
      gui[#gui + 1] = {class: "checkbox", name: "comment_source", label: Core.L("comment_source"), value: DEFAULTS.comment_source, x: 6, y: 6, width: 6}
      gui[#gui + 1] = {class: "checkbox", name: "transform_max_bounds", label: Core.L("transform_max_bounds"), value: DEFAULTS.transform_max_bounds, x: 0, y: 7, width: 10}
    when "Animated clip to FBF"
      gui[#gui + 1] = {class: "label", label: Core.L("bake_source"), x: 0, y: 4, width: 4}
      gui[#gui + 1] = {class: "dropdown", name: "fbf_source", items: Core.localizedItems(fbfSources), value: Core.choiceLabel(DEFAULTS.fbf_source), x: 4, y: 4, width: 6}
      gui[#gui + 1] = {class: "label", label: Core.L("max_frames"), x: 0, y: 5, width: 4}
      gui[#gui + 1] = {class: "intedit", name: "max_frames", value: DEFAULTS.max_frames, min: minFbfFrameBudget, x: 4, y: 5, width: 4}
      gui[#gui + 1] = {class: "checkbox", name: "merge_identical", label: Core.L("merge_identical"), value: DEFAULTS.merge_identical, x: 0, y: 6, width: 6}
      gui[#gui + 1] = {class: "checkbox", name: "comment_source", label: Core.L("comment_source"), value: DEFAULTS.comment_source, x: 6, y: 6, width: 6}
    when "Clip boolean with text/shape"
      gui[#gui + 1] = {class: "label", label: Core.L("boolean_mode"), x: 0, y: 4, width: 4}
      gui[#gui + 1] = {class: "dropdown", name: "boolean_mode", items: Core.localizedItems(booleanModes), value: Core.choiceLabel(DEFAULTS.boolean_mode), x: 4, y: 4, width: 8}
      gui[#gui + 1] = {class: "label", label: Core.L("tolerance"), x: 0, y: 5, width: 3}
      gui[#gui + 1] = {class: "floatedit", name: "tolerance", value: DEFAULTS.tolerance, min: 1, x: 3, y: 5, width: 3}
      gui[#gui + 1] = {class: "checkbox", name: "close_paths", label: Core.L("close_paths"), value: DEFAULTS.close_paths, x: 0, y: 6, width: 5}
  Core.shiftOptionControls gui, controlStart, optionYShift

Core.showActionOptions = (operation) ->
  return Core.normalizeOptions {operation: operation} if actionDirect[operation]
  section = Core.configSection operation
  gui = Core.optionsGui operation
  options = Core.readConfiguredGui section, gui
  button, res = aegisub.dialog.display gui, {Core.L("apply"), Core.L("cancel")}, {ok: Core.L("apply"), close: Core.L("cancel")}
  if button == Core.L("apply")
    Core.saveConfiguredGui options, res, section
    res.operation = operation
    return Core.normalizeOptions res
  else
    return nil


Core.lineNeedsTransformBounds = (line, operation) ->
  return false unless Core.hasTransformTag(line and line.text or "")
  switch operation
    when "Create clip around text"
      true
    when "Autofit clip to text"
      span = Core.firstClipSpan line.text
      span and Core.clipBoundsFromSpan(span) != nil
    when "Create strip clips"
      Core.firstClipSpan(line.text) == nil
    else
      false

Core.validateTransformBoundsContext = (subs, sel, opts = {}) ->
  return true unless opts.transform_max_bounds and transformBoundsActions[opts.operation]
  for i in *Core.dialogueIndices subs, sel
    Core.checkCancelled!
    if Core.lineNeedsTransformBounds subs[i], opts.operation
      unless Core.videoLoaded!
        Core.showMessage "Load a video to include transform maxima over the full line duration.", opts.operation
        return false
      break
  true

Core.dispatch = (subs, sel, active, opts) ->
  return false unless Core.validateTransformBoundsContext subs, sel, opts
  switch opts.operation
    when "Measure clip" then Core.opMeasure subs, sel, opts
    when "Measure & transform clip" then Core.opMeasureTransform subs, sel, opts
    when "Adjust by clip scale" then Core.opAdjustByClipScale subs, sel, opts
    when "Rescale by rectangle clip" then Core.opRescaleByRectangleClip subs, sel, opts
    when "Bezier clip to curved text" then Core.opBezierClipToCurvedText subs, sel, opts
    when "Clip to FRZ" then Core.opClipToFrz subs, sel, opts
    when "Clip to FAX" then Core.opClipToFax subs, sel, opts
    when "Clip to FAY" then Core.opClipToFay subs, sel, opts
    when "Clip to reposition" then Core.opClipToReposition subs, sel, opts
    when "Clip to move" then Core.opClipToMove subs, sel, opts
    when "Position at clip midpoint" then Core.opPositionAtClipMidpoint subs, sel, opts
    when "Align to clip" then Core.opAlignToClip subs, sel, opts
    when "Autofit clip to text" then Core.opAutofitClip subs, sel, active, opts
    when "Fit text to clip guide" then Core.opFitTextToClipGuide subs, sel, opts
    when "Create clip around text" then Core.opCreateTextClip subs, sel, active, opts
    when "Text to clip" then Core.opTextToClip subs, sel, active, opts
    when "Expand clip margin" then Core.opExpandClipMargin subs, sel, opts
    when "Shape to clip" then Core.opShapeToClip subs, sel, active, opts
    when "Clip to shape" then Core.opClipToShape subs, sel, opts
    when "Toggle clip/iclip" then Core.opHotkey subs, sel, "Toggle clip/iclip", opts
    when "Calibrate clip X" then Core.opHotkey subs, sel, "Calibrate clip X", opts
    when "Calibrate clip Y" then Core.opHotkey subs, sel, "Calibrate clip Y", opts
    when "Rectangle from diagonal" then Core.opHotkey subs, sel, "Rectangle from diagonal", opts
    when "Circle from 2 points" then Core.opHotkey subs, sel, "Circle from 2 points", opts
    when "New clip shape" then Core.opHotkey subs, sel, "New clip shape", opts
    when "Copy clip/iclip" then Core.opCopyClip subs, sel, opts
    when "Rect clip to vector" then Core.opHotkey subs, sel, "Rect clip to vector", opts
    when "Vector clip to rect" then Core.opHotkey subs, sel, "Vector clip to rect", opts
    when "Add clip points" then Core.opHotkey subs, sel, "Add clip points", opts
    when "Remove clip points" then Core.opHotkey subs, sel, "Remove clip points", opts
    when "Clip to perspective" then Core.opClipToPerspective subs, sel, opts
    when "Perspective to clip" then Core.opPerspectiveToClip subs, sel, opts
    when "Complete quadrilateral" then Core.opCompleteQuadrilateral subs, sel, opts
    when "Create strip clips" then Core.opCreateStripClips subs, sel, active, opts
    when "Animated clip to FBF" then Core.opAnimatedClipToFbf subs, sel, active, opts
    when "Export clip track to AE" then Core.opExportClipTrackAe subs, sel
    when "Extract clip as mask line" then Core.opExtractClipAsMask subs, sel, opts
    when "Clip boolean with text/shape" then Core.opClipBoolean subs, sel, active, opts
    when "Clip diagnostics" then Core.opClipDiagnostics subs, sel, opts
    else false

Core.runOperation = (subs, sel, active, operation) ->
  unless sel and #sel > 0
    Core.showMessage Core.L("select_one")
    aegisub.cancel!
  opts = Core.showActionOptions operation
  return nil unless opts
  return Core.dispatch(subs, sel, active, opts) if readOnlyActions[operation]

  state = LineOps.snapshot subs
  succeeded, result = pcall ->
    error "Cliptomaniac could not prepare the selected dialogue lines.", 0 unless Core.enrichSelectedLines(subs, sel)
    value = Core.dispatch subs, sel, active, opts
    Core.checkCancelled!
    value
  unless succeeded and result
    restored, restore_error = pcall LineOps.restore, subs, state
    error "Cliptomaniac could not roll back a failed operation: #{tostring(restore_error or 'unknown error')}", 0 unless restored
    error result, 0 unless succeeded
    aegisub.cancel!
  result

Core.main = (subs, sel, active) ->
  while true
    operation = Core.actionPicker!
    return unless operation
    result = Core.runOperation subs, sel, active, operation
    return result if result != nil

Core.validate = (subs, sel) -> sel and #sel > 0

Core.validateAny = -> true

Core.actionMacro = (operation) ->
  (subs, sel, active) ->
    Core.runOperation subs, sel, active, operation

Core.hotkeyMenuPath = (operation) ->
  hotkeyMenuRoot .. "/" .. hotkeyMenuScript .. "/" .. operation\gsub("/", "／")

Core.helpMacro = ->
  Core.actionHelpPicker!

installCompatibilityAliases = (namespace) ->
  pending = {}
  for canonical, value in pairs namespace
    if type(canonical) == "string" and type(value) == "function" and canonical\match("^[a-z]") and canonical\match("%u")
      legacy = canonical\gsub("(%u)", "_%1")\lower!
      pending[#pending + 1] = {legacy, value} if namespace[legacy] == nil
  namespace[item[1]] = item[2] for item in *pending

installCompatibilityAliases Core
installCompatibilityAliases PerspectiveTools

Core.loadLanguage!

registerMacro = (name, description, process, validate) ->
  if depctrl and depctrl.registerMacro
    depctrl\registerMacro name, description, process, validate, nil, false
  else
    aegisub.register_macro name, description, process, validate

registerMacro "Cliptomaniac", script_description, Core.main, Core.validate
registerMacro "Cliptomaniac/Help", "Show the Cliptomaniac action help.", Core.helpMacro, Core.validateAny
for operation in *OPERATIONS
  registerMacro Core.hotkeyMenuPath(operation), Core.actionHelp(operation), Core.actionMacro(operation), Core.validate

require("kite.UI").publishActions()
