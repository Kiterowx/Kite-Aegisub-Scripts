export script_name = "Obake"
export script_description = "Build and maintain ASS transform/tag effects."
export script_author = "Kiterow"
export script_namespace = "kite.Obake"
export script_version = "0.4.5"

Obake = {
  Foundation: {}
  Tags: {}
  Selection: {}
  Lines: {}
  Operations: {}
  FX: {
    handlers: {}
    specs: {
      {name: "Blur In", label_es: "Blur de entrada", handler: "blur_in"}
      {name: "Blur Out", label_es: "Blur de salida", handler: "blur_out"}
      {name: "Fade In", label_es: "Fade de entrada", handler: "fade_in"}
      {name: "Fade Out", label_es: "Fade de salida", handler: "fade_out"}
      {name: "Scale Up", label_es: "Escalar arriba", handler: "scale_up"}
      {name: "Scale Down", label_es: "Escalar abajo", handler: "scale_down"}
      {name: "Pop In", label_es: "Pop de entrada", handler: "pop_in"}
      {name: "Pop Out", label_es: "Pop de salida", handler: "pop_out"}
      {name: "Color Flash", label_es: "Flash de color", handler: "color_flash"}
      {name: "Color Pulse", label_es: "Pulso de color", handler: "color_pulse"}
      {name: "To Color (frame)", label_es: "A color (frame)", handler: "to_color_frame"}
      {name: "To Style (frame)", label_es: "A estilo (frame)", handler: "to_style_frame", needs_styles: true}
      {name: "Border Pulse", label_es: "Pulso de borde", handler: "border_pulse"}
      {name: "Glow Pulse", label_es: "Pulso de brillo", handler: "glow_pulse"}
      {name: "Shake V", label_es: "Sacudida V", handler: "shake_v"}
      {name: "Shake H", label_es: "Sacudida H", handler: "shake_h"}
      {name: "Shake XY", label_es: "Sacudida XY", handler: "shake_xy"}
      {name: "Wobble (frz)", label_es: "Tambaleo (frz)", handler: "wobble"}
      {name: "Glitch", label_es: "Glitch", handler: "glitch", needs_random: true}
      {name: "Dramatic Pulse", label_es: "Pulso dramático", handler: "dramatic_pulse", output: "lines"}
      {name: "Flashback (fad)", label_es: "Flashback (fad)", handler: "flashback"}
      {name: "Split Line", label_es: "dividir línea", handler: "split_line", output: "lines"}
      {name: "Split Line Fad", label_es: "dividir línea con fad", handler: "split_line_fad", output: "lines"}
      {name: "Split Title", label_es: "dividir título", handler: "split_title", output: "lines"}
    }
    by_name: {}
    by_label_es: {}
  }
  StylePresets: {
    handlers: {}
    specs: {
      {name: "Decompose (Fill + Border)", label_es: "Separar relleno + borde", handler: "decompose"}
      {name: "Blur + Glow", label_es: "Blur + glow", handler: "blur_glow"}
      {name: "Shadtrick (Shadow Layer)", label_es: "Shadtrick", handler: "shadtrick"}
      {name: "Double Border Blur", label_es: "Doble borde con blur", handler: "double_border_blur"}
      {name: "Clean Layers (Flatten)", label_es: "Limpiar capas", handler: "clean_layers"}
    }
    by_name: {}
    by_label_es: {}
  }
}
local ASS, AMLine, KiteCore, LineOps

DependencyControl = require "l0.DependencyControl"
depctrl = DependencyControl{
  feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
  {
    {"l0.ASSFoundation", version: "0.5.0", url: "https://github.com/TypesettingTools/ASSFoundation",
      feed: "https://raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json"}
    {"a-mo.Line", version: "1.5.3", url: "https://github.com/TypesettingTools/Aegisub-Motion",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"}
    {"kite.Core", version: "1.1.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.UI", version: "1.5.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.LineOps", version: "1.7.2", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.AssContext", version: "1.1.3"}
    {"kite.Color", version: "1.2.0"}
  }
}
ASS, AMLine, KiteCore, Obake.UI, LineOps = depctrl\requireModules!
Color = require "kite.Color"
AssContext = require "kite.AssContext"

Obake.ConfigHandler = (interface, fileName, _has_sections, version) ->
  storage = switch fileName
    when "kite-gunfight.json" then "gunfight"
    when "kite-obake-zigzag.json" then "zigzag"
    else "language"
  Obake.UI.dialogHandler interface, script_namespace, version, {
    {path: "?user/" .. fileName, format: "json_sections", section: "main", target: storage}
  }, {main: storage}

CONSTANTS = {
  HOTKEY_MENU_ROOT: ": Kite Hotkeys :"
  HOTKEY_MENU_SCRIPT: "Obake"
  CONFIG_FILE: "kite-obake.json"
  DEFAULT_LANGUAGE: "en"
  MAX_FORMAT_DECIMALS: 8
  MAX_RANDOM_SEED: 999999999
  RNG_CLOCK_SCALE: 1000000
  CHAIN_PAGE_ROWS: 8
  SHAKE_ORIGIN_DISTANCE: 1500
  SPLIT_FADE_IN_MS: 250
  RNG_MODULUS: 2147483647
  RNG_MULTIPLIER: 48271
}
current_language = CONSTANTS.DEFAULT_LANGUAGE
languageConfigHandler = nil

OPERATIONS = {
  "Apply chain"
  "Retime transforms"
  "In-Out tags"
  "Gunfight of Tags"
  "ZigZag lines"
  "Animation FX"
  "Border layers"
  "Color preset"
}

operationLabels = {
  en: {
    ["Apply chain"]: "build t() chain"
    ["Retime transforms"]: "retime t() tags"
    ["In-Out tags"]: "create in/out t() tags"
    ["Gunfight of Tags"]: "randomize numeric tags / FBF"
    ["ZigZag lines"]: "alternate selected lines by frames"
    ["Animation FX"]: "apply animation presets"
    ["Border layers"]: "create border layers"
    ["Color preset"]: "apply color-layer preset"
  }
  es: {
    ["Apply chain"]: "crear cadena de t()"
    ["Retime transforms"]: "recalcular tiempos de t()"
    ["In-Out tags"]: "crear tags in/out con t()"
    ["Gunfight of Tags"]: "randomizar tags numericos / FBF"
    ["ZigZag lines"]: "alternar lineas por frames"
    ["Animation FX"]: "aplicar presets de animación"
    ["Border layers"]: "crear capas de borde"
    ["Color preset"]: "aplicar preset de color por capas"
  }
}

actionHelp = {
  en: {
    ["Apply chain"]: "Builds one or more transform segments and injects them in the first override block. Add+ and Rem- control the number of keyframes. In manual mode, the first row is the initial state and each later row becomes one timed \\t()."
    ["Retime transforms"]: "Directly scales every timed \\t(t1,t2,...) in each selected line. Source duration is inferred from the largest existing transform time; target duration is the current line duration."
    ["In-Out tags"]: "Groups selected dialogue lines by matching Effect in pairs of two. Each pair creates one line spanning both timings, comments the originals, and turns differing leading tags into \\t() transitions."
    ["Gunfight of Tags"]: "Randomizes selected numeric/hex ASS override tags. With one source line it splits the line into FBF chunks using the frame period. With multiple selected lines, Count selection as FBF unit treats the selection itself as the tag-change sequence; disabling it splits each line into its own FBF chunks."
    ["ZigZag lines"]: "Uses the selected lines as visual states and emits FBF chunks that alternate through them every N frames. If their times differ, the generated range covers the combined min start to max end."
    ["Animation FX"]: "Applies ready-made animation presets. Color and frame-driven presets use the selected lines, the active frame when needed, and the current line duration."
    ["Border layers"]: "Creates layered border copies from the selected lines. B1-B4 are cumulative outlines, with fill kept above the generated border layers."
    ["Color preset"]: "Creates color-layer presets: fill/border decomposition, glow, shadtrick, double border blur, or clean flatten."
  }
  es: {
    ["Apply chain"]: "Crea uno o varios tramos de transform y los inserta en el primer bloque de tags. Add+ y Rem- controlan la cantidad de keyframes. En modo manual, la primera fila es el estado inicial y las siguientes filas generan \\t() cronometrados."
    ["Retime transforms"]: "Escala directamente cada \\t(t1,t2,...) de las líneas seleccionadas. La duración origen sale del mayor tiempo existente y la duración destino sale de la línea actual."
    ["In-Out tags"]: "Agrupa las líneas de diálogo seleccionadas por Effect en pares de dos. Cada par crea una línea que cubre ambos tiempos, comenta los originales y convierte los tags iniciales distintos en transiciones \\t()."
    ["Gunfight of Tags"]: "Randomiza valores numéricos y hexadecimales en tags ASS. Puede usar la selección como secuencia FBF o dividir cada línea por fotogramas sin alterar el generador aleatorio global."
    ["ZigZag lines"]: "Usa las líneas seleccionadas como estados y crea segmentos FBF que alternan cada N fotogramas sobre el intervalo combinado."
    ["Animation FX"]: "Aplica presets de animación. Los presets de color y de frame usan las líneas seleccionadas, el frame activo cuando corresponde y la duración actual de cada línea."
    ["Border layers"]: "Crea copias en capas con borde a partir de las líneas seleccionadas. B1-B4 son bordes acumulados y el relleno queda encima."
    ["Color preset"]: "Crea presets por capas: relleno/borde, glow, shadtrick, doble borde con blur o limpieza por reemplazo de la línea."
  }
}

fxItems = {""}
for spec in *Obake.FX.specs
  Obake.FX.by_name[spec.name] = spec
  Obake.FX.by_label_es[spec.label_es] = spec if spec.label_es
  fxItems[#fxItems + 1] = spec.name

LANG = {
  en: {
    run: "Execute"
    help: "Help"
    cancel: "Cancel"
    close: "Cancel"
    apply: "Execute"
    reset: "Reset"
    language: "Español"
    action: "Action:"
    time_unit: "Time unit:"
    strip_existing_t: "Strip existing \\t"
    shape: "Shape:"
    value: "Value:"
    accel: "Accel"
    delay: "Delay:"
    time: "T"
    tags: "Tags"
    common_tags: "Common tags"
    color1: "Color 1:"
    color2: "Color 2:"
    step_ms: "Step ms:"
    amount: "Amount:"
    preset: "Preset:"
    select_action: "Select an action and press Execute."
    no_transform_chain: "No transform chain was applied."
    no_border_layers: "No border layers were created."
    no_color_preset: "No color preset was applied."
    no_fx_preset: "Select an FX preset."
    no_lines_changed: "No lines were changed."
    no_t_ret: "No timed \\t() tags were retimed."
    no_numeric_tags: "No numeric override tags were found."
    select_gun_tag: "Select at least one tag."
    gun_no_change: "No selected numeric tags were changed."
    fbf_period: "FBF period:"
    selection_as_fbf_unit: "Count selection as FBF unit"
    frame_api_missing: "Frame timing API is unavailable. Open a video or run this inside Aegisub with frame_from_ms/ms_from_frame."
    no_fbf_slices: "No FBF slices were produced."
    zigzag_period: "Frames:"
    zigzag_need_lines: "ZigZag lines needs at least two dialogue lines."
    zigzag_created: "ZigZag lines created"
    use_line1: "Use line 1"
    use_line2: "Use line 2"
    choose_text: "The two lines have different text. Which text should be kept?"
    in_out_need_pairs: "In-Out tags needs selected dialogue lines grouped into pairs with the same Effect."
    in_out_bad_pairs: "Each Effect must identify exactly two selected dialogue lines. Invalid groups: %s."
    in_out_created: "In-Out tags created %d output line(s)."
    line: "Line"
    zero_duration: "zero duration."
    transform_s: "transform(s)."
  }
  es: {
    ["Manual keyframes"]: "Keyframes manuales"
    ["Once (one-way)"]: "Una vez"
    ["Out and back"]: "Ida y vuelta"
    ["Yoyo (N cycles)"]: "Yoyo (N ciclos)"
    ["Pulse (ms)"]: "Pulso (ms)"
    ["Steps (N)"]: "Pasos (N)"
    ["No delay"]: "Sin retardo"
    ["ms from start"]: "ms desde inicio"
    ["Current frame"]: "Frame actual"
    ["Percent (%)"]: "Porcentaje (%)"
    ["Percent"]: "Porcentaje"
    run: "Execute"
    help: "Ayuda"
    cancel: "Cancel"
    close: "Cancel"
    apply: "Execute"
    reset: "Reset"
    language: "English"
    action: "Acción:"
    time_unit: "Unidad:"
    strip_existing_t: "Quitar \\t existentes"
    shape: "Forma:"
    value: "Valor:"
    accel: "Accel"
    delay: "Retardo:"
    time: "T"
    tags: "Tags"
    common_tags: "Tags comunes"
    color1: "Color 1:"
    color2: "Color 2:"
    step_ms: "Paso ms:"
    amount: "Cantidad:"
    preset: "Preset:"
    select_action: "Selecciona una accion y pulsa Execute."
    no_transform_chain: "No se aplicó ninguna cadena de transforms."
    no_border_layers: "No se crearon capas de borde."
    no_color_preset: "No se aplicó ningún preset de color."
    no_fx_preset: "Selecciona un preset de FX."
    no_lines_changed: "No cambió ninguna línea."
    no_t_ret: "No se recalculó ningún \\t() con tiempo."
    use_line1: "Usar línea 1"
    use_line2: "Usar línea 2"
    choose_text: "Las dos líneas tienen texto distinto. ¿Cuál texto quieres conservar?"
    in_out_need_pairs: "In-Out tags necesita líneas de diálogo seleccionadas agrupadas en pares con el mismo Effect."
    in_out_bad_pairs: "Cada Effect debe identificar exactamente dos líneas de diálogo seleccionadas. Grupos inválidos: %s."
    in_out_created: "In-Out tags creó %d línea(s) de salida."
    line: "Línea"
    zero_duration: "duración cero."
    transform_s: "transform(s)."
  }
}

chainShapes = {
  "Manual keyframes"
  "Once (one-way)"
  "Out and back"
  "Yoyo (N cycles)"
  "Pulse (ms)"
  "Steps (N)"
}

delayModes = {
  "No delay"
  "ms from start"
  "Current frame"
  "Percent (%)"
}

timeUnits = {"Percent", "ms from start"}

CAL_PRESETS = {}
for spec in *Obake.StylePresets.specs
  Obake.StylePresets.by_name[spec.name] = spec
  Obake.StylePresets.by_label_es[spec.label_es] = spec if spec.label_es
  CAL_PRESETS[#CAL_PRESETS + 1] = spec.name

commonTags = {
  "\\fscx100\\fscy100"
  "\\fs50"
  "\\fsp0"
  "\\bord1"
  "\\shad1"
  "\\blur1"
  "\\be1"
  "\\frz0"
  "\\frx0"
  "\\fry0"
  "\\fax0"
  "\\fay0"
  "\\alpha&H00&"
  "\\c&HFFFFFF&"
  "\\3c&H000000&"
  "\\4c&H000000&"
}

CHAIN_DIALOG_W = 24
commonTagColumns = 4
COMMON_TAG_W = CHAIN_DIALOG_W / commonTagColumns

DEFAULTS = {
  operation: "Apply chain"
  time_unit: "Percent"
  chain_shape: "Manual keyframes"
  strip_existing: true
  use_accel: false
  accel: 1.0
  shape_val: 3
  delay_mode: "No delay"
  delay_val: 0
  fx_preset: ""
  fx_step_ms: 50
  fx_amount: 0.12
  fx_color: "#FFCC00"
  fx_color2: "#00CCFF"
  cal_preset: CAL_PRESETS[1]
  bord1: 2
  bord2: 4
  bord3: 0
  bord4: 0
  use_bord1: true
  use_bord2: false
  use_bord3: false
  use_bord4: false
  color1: "#FFFFFF"
  color2: "#000000"
  color3: "#FF0000"
  color4: "#00FF00"
}

gunConfigFile = "kite-gunfight.json"
gunConfigVersion = "1.0.0"
zigzagConfigFile = "kite-obake-zigzag.json"

GUN_RANDOM_SCOPES = {
  "Each value"
  "Same per tag"
  "Same per line"
  "Axis per tag"
  "Axis per line"
}

gunTagDefs = {
  {key: "pos", label: "pos", names: {"pos"}}
  {key: "move", label: "move", names: {"move"}}
  {key: "org", label: "org", names: {"org"}}
  {key: "clip", label: "clip", names: {"clip"}}
  {key: "iclip", label: "iclip", names: {"iclip"}}
  {key: "fad", label: "fad", names: {"fad"}}
  {key: "fade", label: "fade", names: {"fade"}}
  {key: "t", label: "t args", names: {"t"}}
  {key: "an", label: "an", names: {"an"}}
  {key: "a", label: "a", names: {"a"}}
  {key: "q", label: "q", names: {"q"}}
  {key: "fs", label: "fs", names: {"fs"}}
  {key: "fsp", label: "fsp", names: {"fsp"}}
  {key: "fscx", label: "fscx", names: {"fscx"}}
  {key: "fscy", label: "fscy", names: {"fscy"}}
  {key: "frz", label: "frz/fr", names: {"frz", "fr"}}
  {key: "frx", label: "frx", names: {"frx"}}
  {key: "fry", label: "fry", names: {"fry"}}
  {key: "fax", label: "fax", names: {"fax"}}
  {key: "fay", label: "fay", names: {"fay"}}
  {key: "bord", label: "bord", names: {"bord"}}
  {key: "xbord", label: "xbord", names: {"xbord"}}
  {key: "ybord", label: "ybord", names: {"ybord"}}
  {key: "shad", label: "shad", names: {"shad"}}
  {key: "xshad", label: "xshad", names: {"xshad"}}
  {key: "yshad", label: "yshad", names: {"yshad"}}
  {key: "blur", label: "blur", names: {"blur"}}
  {key: "be", label: "be", names: {"be"}}
  {key: "b", label: "b", names: {"b"}}
  {key: "i", label: "i", names: {"i"}}
  {key: "u", label: "u", names: {"u"}}
  {key: "s", label: "s", names: {"s"}}
  {key: "c", label: "c/1c", names: {"c", "1c"}}
  {key: "2c", label: "2c", names: {"2c"}}
  {key: "3c", label: "3c", names: {"3c"}}
  {key: "4c", label: "4c", names: {"4c"}}
  {key: "alpha", label: "alpha", names: {"alpha"}}
  {key: "1a", label: "1a", names: {"1a"}}
  {key: "2a", label: "2a", names: {"2a"}}
  {key: "3a", label: "3a", names: {"3a"}}
  {key: "4a", label: "4a", names: {"4a"}}
  {key: "k", label: "k", names: {"k"}}
  {key: "kf", label: "kf/K", names: {"kf", "K"}}
  {key: "ko", label: "ko", names: {"ko"}}
  {key: "p", label: "p", names: {"p"}}
  {key: "pbo", label: "pbo", names: {"pbo"}}
  {key: "fe", label: "fe", names: {"fe"}}
}

gunKnownNames = {
  "alpha", "iclip", "clip", "move", "fade", "fad", "pos", "org"
  "xbord", "ybord", "xshad", "yshad"
  "fscx", "fscy", "fsp", "frz", "frx", "fry", "fax", "fay"
  "bord", "shad", "blur", "pbo"
  "be", "kf", "ko", "fn", "fe", "an", "fs", "fr"
  "1c", "2c", "3c", "4c", "1a", "2a", "3a", "4a"
  "q", "K", "k", "p", "a", "b", "i", "u", "s", "t", "r", "c"
}

gunNameToKey = {}
for def in *gunTagDefs
  for name in *def.names
    gunNameToKey[name] = def.key

gunColorKeys = {c: true, ["2c"]: true, ["3c"]: true, ["4c"]: true}
gunAlphaKeys = {alpha: true, ["1a"]: true, ["2a"]: true, ["3a"]: true, ["4a"]: true}

gunTagSpec = {
  an: {integer: true, min: 1, max: 9}
  a: {integer: true, min: 1, max: 11}
  q: {integer: true, min: 0, max: 3}
  fs: {nonnegative: true}
  fscx: {nonnegative: true}
  fscy: {nonnegative: true}
  bord: {nonnegative: true}
  xbord: {nonnegative: true}
  ybord: {nonnegative: true}
  shad: {nonnegative: true}
  blur: {nonnegative: true}
  be: {integer: true, nonnegative: true}
  i: {integer: true, min: 0, max: 1}
  u: {integer: true, min: 0, max: 1}
  s: {integer: true, min: 0, max: 1}
  b: {integer: true, min: 0, max: 900}
  k: {integer: true, nonnegative: true}
  kf: {integer: true, nonnegative: true}
  ko: {integer: true, nonnegative: true}
  p: {integer: true, nonnegative: true}
  fe: {integer: true, nonnegative: true}
  fade_alpha: {integer: true, min: 0, max: 255}
  color_channel: {integer: true, min: 0, max: 255}
  time: {integer: true, nonnegative: true}
  accel: {min: 0.001}
}

gunDefaults = {
  min_delta: -5
  max_delta: 10
  step: 0
  decimals: 3
  seed: 0
  random_scope: "Each value"
  use_x: true
  use_y: true
  use_scalar: true
  use_time: false
  include_transform_inner: true
  include_transform_args: false
  include_auto_blocks: false
  clamp_nonnegative: true
  protect_discrete: true
  show_report: true
  fbf_period: 1
  selection_as_fbf_unit: true
}

ZIGZAG_DEFAULTS = {
  period_frames: 3
}

Obake.settings = Obake.UI.settings script_namespace, script_version, {
  main: {
    operation: DEFAULTS.operation
  }
  chain: {
    time_unit: DEFAULTS.time_unit
    chain_shape: DEFAULTS.chain_shape
    strip_existing: DEFAULTS.strip_existing
    use_accel: DEFAULTS.use_accel
    accel: DEFAULTS.accel
    shape_val: DEFAULTS.shape_val
    delay_mode: DEFAULTS.delay_mode
    delay_val: DEFAULTS.delay_val
    rows: {
      {time: 0, tags: "\\fscx100\\fscy100"}
      {time: 100, tags: "\\fscx110\\fscy110"}
    }
  }
  fx: {
    fx_preset: DEFAULTS.fx_preset
    strip_existing: DEFAULTS.strip_existing
    use_accel: DEFAULTS.use_accel
    accel: DEFAULTS.accel
    fx_step_ms: DEFAULTS.fx_step_ms
    fx_amount: DEFAULTS.fx_amount
    fx_color: DEFAULTS.fx_color
    fx_color2: DEFAULTS.fx_color2
  }
  preset: {
    cal_preset: DEFAULTS.cal_preset
  }
  border: {
    use_bord1: DEFAULTS.use_bord1
    bord1: DEFAULTS.bord1
    color1: DEFAULTS.color1
    use_bord2: DEFAULTS.use_bord2
    bord2: DEFAULTS.bord2
    color2: DEFAULTS.color2
    use_bord3: DEFAULTS.use_bord3
    bord3: DEFAULTS.bord3
    color3: DEFAULTS.color3
    use_bord4: DEFAULTS.use_bord4
    bord4: DEFAULTS.bord4
    color4: DEFAULTS.color4
  }
}, {}
Obake.settings\load!

(->
  cloneLine = (line) ->
    return nil unless type(line) == "table"
    src = KiteCore.copy line
    src.class = src.class or "dialogue"
    src.comment = src.comment or false
    src.layer = tonumber(src.layer) or 0
    src.start_time = tonumber(src.start_time) or 0
    src.end_time = tonumber(src.end_time) or src.start_time
    src.style = src.style or "Default"
    src.actor = src.actor or ""
    src.margin_l = tonumber(src.margin_l) or 0
    src.margin_r = tonumber(src.margin_r) or 0
    src.margin_t = tonumber(src.margin_t or src.margin_v) or 0
    src.effect = src.effect or ""
    src.text = tostring(src.text or "")
    wrapped = AMLine src, line.parentCollection or src.parentCollection, {}
    for k, v in pairs src
      wrapped[k] = v if wrapped[k] == nil
    wrapped

  isDialogue = (line) ->
    type(line) == "table" and (line.class == nil or line.class == "dialogue") and not line.comment

  trim = KiteCore.trim
  finiteNumber = KiteCore.finiteNumber
  clamp = KiteCore.clamp

  formatNumber = KiteCore.formatNumber

  formatMilliseconds = (value) ->
    tostring(math.floor((finiteNumber(value) or 0) + 0.5))

  tagNameAliases = {
    t: "transform"
    bord: "outline"
    xbord: "outline_x"
    ybord: "outline_y"
    shad: "shadow"
    xshad: "shadow_x"
    yshad: "shadow_y"
    org: "origin"
    pos: "position"
    c: "color1"
    ["1c"]: "color1"
    ["2c"]: "color2"
    ["3c"]: "color3"
    ["4c"]: "color4"
    ["1a"]: "alpha1"
    ["2a"]: "alpha2"
    ["3a"]: "alpha3"
    ["4a"]: "alpha4"
  }

  assLineForText = (text) ->
    {
      class: "dialogue"
      comment: false
      layer: 0
      start_time: 0
      end_time: 0
      style: "Default"
      actor: ""
      margin_l: 0
      margin_r: 0
      margin_t: 0
      effect: ""
      text: tostring(text or "")
    }

  parseText = (text) ->
    ok, data = pcall -> ASS\parse assLineForText text
    if ok then data else nil

  normalizeTagNames = (names) ->
    names = {names} unless type(names) == "table"
    out = {}
    for name in *(names or {})
      raw = tostring(name or "")
      raw = raw\gsub "^\\", ""
      out[#out + 1] = tagNameAliases[raw] or raw
    out

  removeAssTags = (text, names) ->
    data = parseText text
    return tostring(text or "") unless data
    ok = pcall -> data\removeTags normalizeTagNames names
    return tostring(text or "") unless ok
    data\getString!

  tagText = (name, ...) ->
    tostring(ASS\createTag(name, ...))

  rgbFromColor = (value) ->
    Color.toRGB Color.parseAss(value) or Color.normalize(value)

  colorTagText = (name, value) ->
    r, g, b = rgbFromColor value
    tagText name, b, g, r

  assColorValue = (value) ->
    colorTagText("color1", value)\match("&H%x%x%x%x%x%x&") or "&HFFFFFF&"

  Obake.Foundation.cloneLine = cloneLine
  Obake.Foundation.isDialogue = isDialogue
  Obake.Foundation.finiteNumber = finiteNumber
  Obake.Foundation.formatNumber = formatNumber
  Obake.Foundation.formatMilliseconds = formatMilliseconds

  Obake.L = (key) ->
    lang = LANG[current_language] or LANG.en
    lang[key] or LANG.en[key] or tostring(key or "")

  Obake.presetSpec = (value) ->
    raw = tostring(value or "")
    Obake.FX.by_name[raw] or Obake.StylePresets.by_name[raw]

  Obake.choiceLabel = (value) ->
    raw = tostring(value or "")
    return raw if raw == ""
    preset = Obake.presetSpec raw
    return preset.label_es if preset and current_language == "es" and preset.label_es
    lang = LANG[current_language] or LANG.en
    lang[raw] or raw

  Obake.choiceRaw = (value) ->
    shown = tostring(value or "")
    return shown if current_language == CONSTANTS.DEFAULT_LANGUAGE
    preset = Obake.FX.by_label_es[shown] or Obake.StylePresets.by_label_es[shown]
    return preset.name if preset
    for raw, label in pairs LANG[current_language] or {}
      return raw if label == shown
    shown

  Obake.localizedItems = (items) ->
    [Obake.choiceLabel item for item in *(items or {})]

  Obake.validLanguage = (value) ->
    if value == "es" then "es" else "en"

  Obake.configInterface = ->
    {
      main: {
        language: {class: "edit", name: "language", value: current_language, config: true}
      }
    }

  Obake.languageConfig = ->
    return nil unless Obake.ConfigHandler
    languageConfigHandler or= Obake.ConfigHandler Obake.configInterface!, CONSTANTS.CONFIG_FILE, true, script_version
    languageConfigHandler

  Obake.loadLanguage = ->
    options = Obake.languageConfig!
    return current_language unless options
    pcall -> options\read!
    lang = options.configuration and options.configuration.main and options.configuration.main.language
    current_language = Obake.validLanguage lang
    current_language

  Obake.writeConfig = (options) ->
    ok, saved, err = pcall -> options\write!
    unless ok and saved
      message = if current_language == "es" then "No se pudo guardar la configuración. Los valores siguen disponibles en esta sesión." else "Could not save settings. The values remain available for this session."
      Obake.UI.message message .. "\n" .. tostring(err or saved or ""), {button: Obake.L("close")}
      return false
    true

  Obake.saveLanguage = ->
    options = Obake.languageConfig!
    return false unless options
    pcall -> options\read!
    options.configuration or= {}
    options.configuration.main or= {}
    options.configuration.main.language = Obake.validLanguage current_language
    Obake.writeConfig options

  Obake.toggleLanguage = ->
    current_language = if current_language == "es" then "en" else "es"
    Obake.saveLanguage!
    current_language

  Obake.loadLanguage!

  showMessage = (message) ->
    Obake.UI.message message, {button: Obake.L("close")}

  enumValue = (value, items, fallback) ->
    value = Obake.choiceRaw value
    for item in *(items or {})
      return item if value == item
    fallback or (items and items[1]) or value

  Obake.operationLabel = (operation) ->
    labels = operationLabels[current_language] or operationLabels.en
    labels[operation] or operationLabels.en[operation] or tostring(operation or "")

  Obake.actionHelp = (operation) ->
    help = actionHelp[current_language] or actionHelp.en
    help[operation] or actionHelp.en[operation] or ""

  Obake.normalizeOperation = (operation) ->
    enumValue operation, OPERATIONS, DEFAULTS.operation

  Obake.dropdownData = (items, labeler) ->
    out, to_raw, toShown = {""}, {[""]: ""}, {[""]: ""}
    n = 1
    for raw in *(items or {})
      if raw != nil and raw != ""
        shown = "#{n}. #{if labeler then labeler(raw) else Obake.choiceLabel(raw)}"
        out[#out + 1] = shown
        to_raw[shown] = raw
        to_raw[raw] = raw
        toShown[raw] = shown
        n += 1
    out, to_raw, toShown

  Obake.shownChoice = (toShown, raw) ->
    (toShown and toShown[raw]) or raw or ""

  Obake.rawChoice = (to_raw, shown) ->
    (to_raw and to_raw[shown]) or Obake.choiceRaw(shown) or ""

  Obake.rawOperationChoice = (to_raw, shown) ->
    Obake.normalizeOperation Obake.rawChoice(to_raw, shown)

  firstBlock = (text) ->
    tostring(text or "")\match("^({%s*\\[^}]*})") or ""

  injectFirst = LineOps.prependTag

  injectTransformFirst = (text, payload) ->
    return text unless payload and payload != ""
    text = tostring(text or "")
    fb = firstBlock text
    if fb != ""
      return fb\sub(1, -2) .. payload .. "}" .. text\sub(#fb + 1)
    "{" .. payload .. "}" .. text

  removeSimpleTag = (text, tag) ->
    removeAssTags text, tag

  removeAlphaTags = (text) ->
    removeAssTags text, {"alpha", "alpha1", "alpha2", "alpha3", "alpha4"}

  stripKaraokeTags = (text) ->
    LineOps.removeTagCalls text, {"k", "kf", "ko", "kt"}, {top_level_only: true}

  splitTopCommas = LineOps.splitArguments

  mapTransforms = (text, fn) ->
    text = tostring(text or "")
    out, changed, cursor = {}, 0, 1
    for call in *LineOps.tagCalls(text, "t")
      if call.top_level and call.value\sub(1, 1) == "(" and call.value\sub(-1) == ")"
        out[#out + 1] = text\sub cursor, call.start - 1
        replacement, didChange = fn call.value\sub(2, -2), call.raw
        out[#out + 1] = replacement or call.raw
        changed += 1 if didChange
        cursor = call.finish + 1
    out[#out + 1] = text\sub cursor
    table.concat(out), changed

  stripTransforms = (text) ->
    out = mapTransforms text, -> "", true
    out

  transformTag = (t1, t2, tags, accel = nil) ->
    tags = tostring(tags or "")
    return "" if tags == ""
    a = math.floor((tonumber(t1) or 0) + 0.5)
    b = math.floor((tonumber(t2) or 0) + 0.5)
    a, b = b, a if b < a
    prefix = "\\t(" .. a .. "," .. b .. ","
    accel = finiteNumber accel
    prefix ..= tostring(accel) .. "," if accel and accel > 0 and accel != 1
    prefix .. tags .. ")"

  maxTransformEnd = (text) ->
    maxEnd = 0
    mapTransforms text, (body) ->
      parts = splitTopCommas body
      if #parts >= 3
        t1 = finiteNumber parts[1]
        t2 = finiteNumber parts[2]
        if t1 and t2
          maxEnd = math.max maxEnd, t1, t2
      "\\t(" .. body .. ")", false
    maxEnd

  retimeTransformText = (text, sourceDuration, targetDuration) ->
    source = finiteNumber(sourceDuration) or 0
    target = finiteNumber(targetDuration) or 0
    return text, 0 unless source > 0 and target >= 0
    scale = target / source
    mapTransforms text, (body) ->
      parts = splitTopCommas body
      return "\\t(" .. body .. ")", false unless #parts >= 3
      t1 = finiteNumber parts[1]
      t2 = finiteNumber parts[2]
      return "\\t(" .. body .. ")", false unless t1 and t2
      parts[1] = formatMilliseconds t1 * scale
      parts[2] = formatMilliseconds t2 * scale
      "\\t(" .. table.concat(parts, ",") .. ")", true

  stripTags = (text) -> LineOps.analyzeText(text).plain

  splitLeadingTagBlocks = (text) ->
    text = tostring(text or "")
    blocks, i = {}, 1
    while i <= #text and text\sub(i, i) == "{"
      closePos = text\find "}", i + 1, true
      break unless closePos
      content = text\sub i + 1, closePos - 1
      break unless content\match "^%s*\\"
      blocks[#blocks + 1] = text\sub i, closePos
      i = closePos + 1
    table.concat(blocks), text\sub(i)

  parseTagBlock = (blocks) ->
    [call for call in *LineOps.tagCalls(blocks) when call.top_level]

  tagNumbers = (value) ->
    nums = {}
    for raw in *LineOps.splitArguments(value)
      number = finiteNumber raw
      return {} unless number
      nums[#nums + 1] = number
    nums

  roundInteger = KiteCore.round

  gunChoiceOrDefault = (value, items, defaultValue) ->
    for item in *(items or {})
      return item if value == item
    defaultValue

  gunBalancedParenEnd = (text, start_pos) ->
    depth = 0
    for i = start_pos, #text
      c = text\sub i, i
      if c == "("
        depth += 1
      elseif c == ")"
        depth -= 1
        return i if depth == 0
    nil

  gunIterTagBlocks = (text) ->
    blocks = {}
    text = tostring(text or "")
    i = 1
    while true
      s = text\find "{", i, true
      break unless s
      e = text\find "}", s + 1, true
      break unless e
      blocks[#blocks + 1] = {
        open_pos: s
        close_pos: e
        content: text\sub s + 1, e - 1
      }
      i = e + 1
    blocks

  gunParseTagBlock = (block) ->
    block = tostring(block or "")
    tags = {}
    i = 1
    while i <= #block
      if block\sub(i, i) == "\\"
        nameStart = i + 1
        name = nil
        for known in *gunKnownNames
          if block\sub(nameStart, nameStart + #known - 1) == known
            name = known
            break
        name or= block\sub(nameStart)\match "^[1-4]?[A-Za-z]+"
        if name and name != ""
          j = nameStart + #name
          local token_end
          if block\sub(j, j) == "("
            token_end = gunBalancedParenEnd block, j
            break unless token_end
          else
            token_end = j - 1
            while token_end + 1 <= #block and block\sub(token_end + 1, token_end + 1) != "\\"
              token_end += 1
          tags[#tags + 1] = {
            name: name
            raw: block\sub i, token_end
            value: block\sub j, token_end
            start_pos: i
            end_pos: token_end
          }
          i = token_end + 1
        else
          i += 1
      else
        i += 1
    tags

  gunIsDigit = (c) ->
    c and c\match("%d") != nil

  gunScanNumbers = (text) ->
    text = tostring(text or "")
    tokens = {}
    i = 1
    while i <= #text
      c = text\sub i, i
      nextC = text\sub i + 1, i + 1
      canStart = gunIsDigit(c) or ((c == "+" or c == "-") and (gunIsDigit(nextC) or nextC == ".")) or (c == "." and gunIsDigit(nextC))
      unless canStart
        i += 1
        continue
      start_pos = i
      i += 1 if c == "+" or c == "-"
      digits = 0
      while i <= #text and gunIsDigit text\sub(i, i)
        i += 1
        digits += 1
      if i <= #text and text\sub(i, i) == "."
        i += 1
        while i <= #text and gunIsDigit text\sub(i, i)
          i += 1
          digits += 1
      if digits == 0
        i = start_pos + 1
        continue
      expStart = i
      if i <= #text and (text\sub(i, i) == "e" or text\sub(i, i) == "E")
        j = i + 1
        j += 1 if text\sub(j, j) == "+" or text\sub(j, j) == "-"
        expDigits = 0
        while j <= #text and gunIsDigit text\sub(j, j)
          j += 1
          expDigits += 1
        if expDigits > 0
          i = j
        else
          i = expStart
      raw = text\sub start_pos, i - 1
      tokens[#tokens + 1] = {
        start_pos: start_pos
        end_pos: i - 1
        raw: raw
        value: tonumber raw
      }
    tokens

  gunIsSelected = (key, selected) ->
    selected and selected[key] == true

  gunCategoryEnabled = (category, cfg) ->
    switch category
      when "x" then cfg.use_x
      when "y" then cfg.use_y
      when "time" then cfg.use_time
      when "accel" then cfg.use_scalar and cfg.include_transform_args
      when "pathscale" then cfg.use_scalar
      when "discrete" then cfg.use_scalar
      else cfg.use_scalar

  gunClipHasVectorCommands = (value) ->
    stripped = tostring(value or "")\gsub "^%(", ""
    stripped = stripped\gsub "%)$", ""
    stripped\match("[mnlbspcMNLBSPC]") != nil

  gunClipHasScalePrefix = (value) ->
    return false unless gunClipHasVectorCommands value
    body = tostring(value or "")\gsub "^%(", ""
    body = body\gsub "%)$", ""
    body\match("^%s*[%+%-]?%d*%.?%d+%s*,%s*[mnlbspcMNLBSPC]") != nil

  gunClassifyNumber = (key, index, value) ->
    return "x" if key == "fscx" or key == "xbord" or key == "xshad" or key == "fax"
    return "y" if key == "fscy" or key == "ybord" or key == "yshad" or key == "fay"
    return "discrete" if key == "an" or key == "a" or key == "q" or key == "b" or key == "i" or key == "u" or key == "s" or key == "p" or key == "fe" or key == "be"
    return "time" if key == "fad" or key == "k" or key == "kf" or key == "ko"
    if key == "pos" or key == "org"
      return if index % 2 == 1 then "x" else "y"
    if key == "move"
      return "time" if index >= 5
      return if index % 2 == 1 then "x" else "y"
    if key == "clip" or key == "iclip"
      offset = if gunClipHasScalePrefix(value) then 1 else 0
      return "pathscale" if offset == 1 and index == 1
      coordIndex = index - offset
      return if coordIndex % 2 == 1 then "x" else "y"
    if key == "fade"
      return if index <= 3 then "scalar" else "time"
    "scalar"

  gunSpecFor = (key, category) ->
    return gunTagSpec.time if category == "time"
    return gunTagSpec.accel if category == "accel"
    return gunTagSpec.fade_alpha if key == "fade" and category == "scalar"
    gunTagSpec[key] or {}

  gunDeltaKey = (ctx, key, category, tokenIndex, cfg) ->
    scope = cfg.random_scope or "Each value"
    if scope == "Each value"
      ctx.value_counter = (ctx.value_counter or 0) + 1
      return "v:" .. tostring(ctx.line_index) .. ":" .. tostring(ctx.value_counter)
    if scope == "Same per line"
      return "line:" .. tostring(ctx.line_index)
    if scope == "Same per tag"
      return "tag:" .. tostring(ctx.line_index) .. ":" .. tostring(ctx.block_index) .. ":" .. tostring(ctx.tag_index)
    if scope == "Axis per line"
      if category == "x" or category == "y"
        return "line-axis:" .. tostring(ctx.line_index) .. ":" .. category
      return "line:" .. tostring(ctx.line_index)
    if scope == "Axis per tag"
      if category == "x" or category == "y"
        return "tag-axis:" .. tostring(ctx.line_index) .. ":" .. tostring(ctx.block_index) .. ":" .. tostring(ctx.tag_index) .. ":" .. category
      return "tag:" .. tostring(ctx.line_index) .. ":" .. tostring(ctx.block_index) .. ":" .. tostring(ctx.tag_index)
    "fallback:" .. tostring(ctx.line_index) .. ":" .. tostring(ctx.block_index) .. ":" .. tostring(ctx.tag_index) .. ":" .. tostring(tokenIndex)

  gunRandomDelta = (ctx, key, category, tokenIndex, cfg) ->
    cacheKey = gunDeltaKey ctx, key, category, tokenIndex, cfg
    return ctx.cache[cacheKey] if ctx.cache[cacheKey] != nil
    min_delta, max_delta = finiteNumber(cfg.min_delta) or 0, finiteNumber(cfg.max_delta) or 0
    if min_delta > max_delta
      min_delta, max_delta = max_delta, min_delta
    random = ctx.random
    sample = if random then random! else 0.5
    delta = min_delta + sample * (max_delta - min_delta)
    step = finiteNumber(cfg.step) or 0
    if step > 0
      delta = roundInteger(delta / step) * step
      delta = clamp delta, min_delta, max_delta
    ctx.cache[cacheKey] = delta
    delta

  gunApplyLimits = (value, spec, cfg) ->
    spec or= {}
    if cfg.protect_discrete and spec.integer
      value = roundInteger value
    if cfg.clamp_nonnegative and spec.nonnegative
      value = math.max 0, value
    value = math.max spec.min, value if spec.min != nil
    value = math.min spec.max, value if spec.max != nil
    value

  gunApplyNumber = (token, key, category, index, cfg, ctx) ->
    return token.raw unless gunCategoryEnabled category, cfg
    value = tonumber token.value
    return token.raw unless value
    delta = gunRandomDelta ctx, key, category, index, cfg
    spec = gunSpecFor key, category
    value = gunApplyLimits value + delta, spec, cfg
    decimals = clamp math.floor(finiteNumber(cfg.decimals) or 3), 0, CONSTANTS.MAX_FORMAT_DECIMALS
    decimals = 0 if cfg.protect_discrete and spec.integer
    formatNumber value, decimals

  gunNormalizeHex = (hex, width) ->
    hex = tostring(hex or "")\upper!
    hex = hex\gsub "[^0-9A-F]", ""
    hex = hex\sub -width if #hex > width
    while #hex < width
      hex = "0" .. hex
    hex

  gunHexByte = (hex, start_pos) ->
    tonumber(hex\sub(start_pos, start_pos + 1), 16) or 0

  gunApplyByte = (value, key, index, cfg, ctx) ->
    return value unless gunCategoryEnabled "scalar", cfg
    delta = gunRandomDelta ctx, key, "scalar", index, cfg
    roundInteger gunApplyLimits value + delta, gunTagSpec.color_channel, cfg

  gunProcessAlphaTag = (tag, key, cfg, ctx) ->
    hex = tag.raw\match "&[Hh]([%x]+)&?"
    return tag.raw, 0 unless hex
    hex = gunNormalizeHex hex, 2
    old = gunHexByte hex, 1
    newValue = gunApplyByte old, key, 1, cfg, ctx
    return tag.raw, 0 if newValue == old
    nextHex = ("&H%02X&")\format newValue
    (tag.raw\gsub "&[Hh][%x]+&?", nextHex, 1), 1

  gunProcessColorTag = (tag, key, cfg, ctx) ->
    hex = tag.raw\match "&[Hh]([%x]+)&?"
    return tag.raw, 0 unless hex
    hex = gunNormalizeHex hex, 6
    values = {gunHexByte(hex, 1), gunHexByte(hex, 3), gunHexByte(hex, 5)}
    changed = 0
    for i = 1, 3
      newValue = gunApplyByte values[i], key, i, cfg, ctx
      if newValue != values[i]
        values[i] = newValue
        changed += 1
    return tag.raw, 0 if changed == 0
    nextHex = ("&H%02X%02X%02X&")\format values[1], values[2], values[3]
    (tag.raw\gsub "&[Hh][%x]+&?", nextHex, 1), changed

  gunReplaceNumberTokens = (raw, numbers, key, cfg, ctx, value) ->
    return raw, 0 unless numbers and #numbers > 0
    out = {}
    pos = 1
    changed = 0
    for index, token in ipairs numbers
      out[#out + 1] = raw\sub pos, token.start_pos - 1
      category = gunClassifyNumber key, index, value
      nextRaw = gunApplyNumber token, key, category, index, cfg, ctx
      out[#out + 1] = nextRaw
      changed += 1 if nextRaw != token.raw
      pos = token.end_pos + 1
    out[#out + 1] = raw\sub pos
    table.concat(out), changed

  gunTransformParts = (raw) ->
    inner = tostring(raw or "")\match "^\\t%((.*)%)$"
    return nil unless inner
    tagStart = inner\find "\\", 1, true
    unless tagStart
      return inner, "", ""
    inner\sub(1, tagStart - 1), inner\sub(tagStart), inner

  gunClassifyTransformArg = (index, total) ->
    if total == 1
      "accel"
    elseif total == 2
      "time"
    elseif index <= 2
      "time"
    elseif index == 3
      "accel"
    else
      "scalar"

  gunReplaceTransformArgs = (prefix, cfg, ctx) ->
    numbers = gunScanNumbers prefix
    return prefix, 0 unless #numbers > 0
    out = {}
    pos = 1
    changed = 0
    for index, token in ipairs numbers
      out[#out + 1] = prefix\sub pos, token.start_pos - 1
      category = gunClassifyTransformArg index, #numbers
      nextRaw = if gunCategoryEnabled(category, cfg) then gunApplyNumber(token, "t", category, index, cfg, ctx) else token.raw
      out[#out + 1] = nextRaw
      changed += 1 if nextRaw != token.raw
      pos = token.end_pos + 1
    out[#out + 1] = prefix\sub pos
    table.concat(out), changed

  gunProcessBlockContent = nil

  gunProcessTransformTag = (tag, selected, cfg, ctx) ->
    prefix, mods = gunTransformParts tag.raw
    return tag.raw, 0 unless prefix != nil
    changed = 0
    nextPrefix = prefix
    if gunIsSelected("t", selected) and cfg.include_transform_args
      nextPrefix, c = gunReplaceTransformArgs prefix, cfg, ctx
      changed += c
    nextMods = mods
    if mods != "" and cfg.include_transform_inner
      nextMods, c = gunProcessBlockContent mods, selected, cfg, ctx, true
      changed += c
    "\\t(" .. nextPrefix .. nextMods .. ")", changed

  gunProcessTag = (tag, selected, cfg, ctx) ->
    key = gunNameToKey[tag.name]
    return gunProcessTransformTag tag, selected, cfg, ctx if tag.name == "t"
    return tag.raw, 0 unless key and gunIsSelected key, selected
    return gunProcessColorTag tag, key, cfg, ctx if gunColorKeys[key]
    return gunProcessAlphaTag tag, key, cfg, ctx if gunAlphaKeys[key]
    numbers = gunScanNumbers tag.raw
    gunReplaceNumberTokens tag.raw, numbers, key, cfg, ctx, tag.value

  gunProcessBlockContent = (content, selected, cfg, ctx) ->
    content = tostring(content or "")
    tags = gunParseTagBlock content
    return content, 0 if #tags == 0
    out = {}
    pos = 1
    changed = 0
    for tagIndex, tag in ipairs tags
      ctx.tag_index = tagIndex
      out[#out + 1] = content\sub pos, tag.start_pos - 1
      nextRaw, c = gunProcessTag tag, selected, cfg, ctx
      out[#out + 1] = nextRaw
      changed += c
      pos = tag.end_pos + 1
    out[#out + 1] = content\sub pos
    table.concat(out), changed

  gunProcessText = (text, selected, cfg, line_index = 1, shared_cache = nil, random = nil) ->
    text = tostring(text or "")
    out = {}
    pos = 1
    changed = 0
    ctx = {line_index: line_index, cache: shared_cache or {}, value_counter: 0, random: random}
    blocks = gunIterTagBlocks text
    for blockIndex, block in ipairs blocks
      ctx.block_index = blockIndex
      out[#out + 1] = text\sub pos, block.open_pos - 1
      first = block.content\sub 1, 1
      if (first == "*" or first == ">") and not cfg.include_auto_blocks
        out[#out + 1] = text\sub block.open_pos, block.close_pos
      else
        nextContent, c = gunProcessBlockContent block.content, selected, cfg, ctx
        out[#out + 1] = "{" .. nextContent .. "}"
        changed += c
      pos = block.close_pos + 1
    out[#out + 1] = text\sub pos
    table.concat(out), changed

  gunMarkKey = (found, key) ->
    return unless key
    found[key] or= {count: 0}
    found[key].count += 1

  gunCollectFromBlock = nil

  gunCollectFromTransform = (tag, found, includeAuto) ->
    prefix, mods = gunTransformParts tag.raw
    gunMarkKey found, "t" if prefix != nil and #gunScanNumbers(prefix) > 0
    gunCollectFromBlock mods, found, includeAuto if mods and mods != ""

  gunCollectFromBlock = (content, found, includeAuto) ->
    for tag in *gunParseTagBlock content
      if tag.name == "t"
        gunCollectFromTransform tag, found, includeAuto
      else
        key = gunNameToKey[tag.name]
        if key and (gunColorKeys[key] or gunAlphaKeys[key])
          gunMarkKey found, key if tag.raw\match "&[Hh][%x]+&?"
        elseif key and #gunScanNumbers(tag.raw) > 0
          gunMarkKey found, key

  gunCollectNumericTags = (subs, sel, includeAuto = false) ->
    found = {}
    for index in *Obake.Selection.dialogueIndices subs, sel
      line = subs[index]
      for block in *gunIterTagBlocks(line.text or "")
        first = block.content\sub 1, 1
        continue if (first == "*" or first == ">") and not includeAuto
        gunCollectFromBlock block.content, found, includeAuto
    found

  gunHasAnySelected = (selected) ->
    for _, value in pairs selected or {}
      return true if value
    false

  makeRandom = (seed) ->
    seed = finiteNumber(seed) or 0
    if seed <= 0
      clockPart = if os.clock then math.floor(os.clock! * CONSTANTS.RNG_CLOCK_SCALE) else 0
      seed = os.time! * CONSTANTS.RNG_CLOCK_SCALE + clockPart
    seed = (math.floor(math.abs(seed)) - 1) % CONSTANTS.MAX_RANDOM_SEED + 1
    state = seed
    random = ->
      state = (state * CONSTANTS.RNG_MULTIPLIER) % CONSTANTS.RNG_MODULUS
      state / CONSTANTS.RNG_MODULUS
    random, seed

  gunSeedRandom = (seed) ->
    makeRandom seed

  Obake.Tags.iterBlocks = gunIterTagBlocks
  Obake.Tags.parseBlock = gunParseTagBlock
  Obake.Tags.clipIsVector = gunClipHasVectorCommands

  transitionCanon = {fr: "frz", ["1c"]: "c"}

  transitionAnimatable = {
    clip: true, iclip: true
    fs: true, fsp: true, fscx: true, fscy: true
    frz: true, frx: true, fry: true, fax: true, fay: true
    bord: true, xbord: true, ybord: true
    shad: true, xshad: true, yshad: true
    blur: true, be: true
    c: true, ["2c"]: true, ["3c"]: true, ["4c"]: true
    alpha: true, ["1a"]: true, ["2a"]: true, ["3a"]: true, ["4a"]: true
  }

  transitionCanonical = (name) ->
    transitionCanon[name] or name

  parseTransitionTags = (blocks) ->
    tags, order = {}, {}
    for t in *parseTagBlock blocks
      key = transitionCanonical t.name
      order[#order + 1] = key unless tags[key]
      tags[key] = {name: t.name, key: key, value: t.value, raw: t.raw}
    tags, order

  transitionClipKind = (tag) ->
    return nil unless tag
    return "vector" if Obake.Tags.clipIsVector tag.value
    numbers = tagNumbers tag.value
    return "rectangle" if #numbers == 4 and numbers[1] and numbers[2] and numbers[3] and numbers[4]
    "invalid"

  transitionPosition = (tags, final) ->
    t = tags.pos
    if t
      nums = tagNumbers t.value
      return {x: nums[1], y: nums[2]} if #nums == 2
    t = tags.move
    if t
      nums = tagNumbers t.value
      if #nums == 4 or #nums == 6
        xIndex = if final then 3 else 1
        yIndex = if final then 4 else 2
        return {x: nums[xIndex], y: nums[yIndex]}
    nil

  transitionFadValue = (tag, slot) ->
    return 0 unless tag and tag.key == "fad"
    nums = tagNumbers tag.value
    math.max 0, math.floor((nums[slot] or 0) + 0.5)

  transitionTagText = (tag) ->
    "\\" .. tag.name .. tostring(tag.value or "")

  transitionSpecial = {pos: true, move: true, fad: true}

  transitionStaticMismatches = (tags1, tags2, order1, order2) ->
    mismatches, seen = {}, {}
    inspect = (key) ->
      return if seen[key]
      seen[key] = true
      return if transitionAnimatable[key] or transitionSpecial[key]
      first, second = tags1[key], tags2[key]
      mismatches[#mismatches + 1] = "\\#{key}" unless first and second and first.raw == second.raw
    inspect key for key in *order1
    inspect key for key in *order2
    mismatches

  transitionFadValid = (tag) ->
    return true unless tag
    numbers = tagNumbers tag.value
    #numbers == 2 and numbers[1] >= 0 and numbers[2] >= 0

  chooseTransitionBody = (body1, body2) ->
    return body1 if body1 == body2
    if stripTags(body1) == stripTags(body2)
      showMessage "In-Out found different inline override tags around the same visible text. Split the runs or make both bodies identical before combining them."
      return nil
    b1, b2, bc = Obake.L("use_line1"), Obake.L("use_line2"), Obake.L("cancel")
    button = aegisub.dialog.display {
      {class: "textbox", text: Obake.L("choose_text"), x: 0, y: 0, width: 34, height: 4}
    }, {b1, b2, bc}, {cancel: bc, close: bc}
    if button == b2 then body2 elseif button == b1 then body1 else nil

  Obake.collectInOutPairs = (subs, sel) ->
    return nil unless subs and sel and #sel >= 2
    selected = Obake.Selection.dialogueRecords subs, sel, true
    return nil unless selected and #selected >= 2
    groups, effectOrder = {}, {}
    for record in *selected
      index, line = record.index, record.line
      effect = tostring line.effect or ""
      unless groups[effect]
        groups[effect] = {}
        effectOrder[#effectOrder + 1] = effect
      groups[effect][#groups[effect] + 1] = {index: index, line: line}
    pairs, invalidEffects = {}, {}
    for effect in *effectOrder
      records = groups[effect]
      if #records != 2
        invalidEffects[#invalidEffects + 1] = effect
      else
        table.sort records, (a, b) ->
          at, bt = tonumber(a.line.start_time) or 0, tonumber(b.line.start_time) or 0
          if at == bt then a.index < b.index else at < bt
        pairs[#pairs + 1] = records
    return nil, invalidEffects if #invalidEffects > 0
    pairs

  Obake.buildInOutPair = (records) ->
    idx1, idx2 = records[1].index, records[2].index
    line1, line2 = cloneLine(records[1].line), cloneLine(records[2].line)
    unless isDialogue(line1) and isDialogue(line2)
      showMessage Obake.L("in_out_need_pairs")
      return nil
    visualFields = {"style", "effect", "layer", "margin_l", "margin_r", "margin_t", "margin_b", "margin_v"}
    exactVisualFields = {style: true, effect: true}
    differing_fields = {}
    for field in *visualFields
      first = line1[field]
      second = line2[field]
      same = if exactVisualFields[field] then tostring(first or "") == tostring(second or "") else (tonumber(first) or 0) == (tonumber(second) or 0)
      differing_fields[#differing_fields + 1] = field unless same
    if #differing_fields > 0
      showMessage "In-Out requires matching visual line fields because ASS cannot animate them: #{table.concat differing_fields, ", "}."
      return false
    tagsText1, body1 = splitLeadingTagBlocks line1.text
    tagsText2, body2 = splitLeadingTagBlocks line2.text
    finalText = chooseTransitionBody body1, body2
    return false unless finalText

    tags1, order1 = parseTransitionTags tagsText1
    tags2, order2 = parseTransitionTags tagsText2
    timed_tags = {}
    for key in *{"t", "fade", "k", "kf", "ko", "kt"}
      firstCalls = LineOps.tagCalls line1.text, key
      secondCalls = LineOps.tagCalls line2.text, key
      timed_tags[#timed_tags + 1] = "\\#{key}" if #firstCalls > 0 or #secondCalls > 0
    if #timed_tags > 0
      showMessage "In-Out does not combine existing time-sensitive tags (#{table.concat timed_tags, ", "}) because their timing would change. Bake or remove them first."
      return false
    if #LineOps.tagCalls(body1, "fad") > 0 or #LineOps.tagCalls(body2, "fad") > 0
      showMessage "In-Out only supports \\fad in the leading override blocks; inline fades would change timing in the combined line."
      return false
    mismatches = transitionStaticMismatches tags1, tags2, order1, order2
    if #mismatches > 0
      showMessage "In-Out found non-animatable tags that differ between endpoints: #{table.concat mismatches, ", "}. Make them identical or split the operation."
      return false
    unless transitionFadValid(tags1.fad) and transitionFadValid(tags2.fad)
      showMessage "In-Out found an invalid \\fad tag; use exactly two non-negative durations."
      return false
    if (tags1.pos and tags1.move) or (tags2.pos and tags2.move)
      showMessage "In-Out needs one placement tag per endpoint; do not combine \\pos and \\move on the same line."
      return false
    if (tags1.clip and tags1.iclip) or (tags2.clip and tags2.iclip)
      showMessage "In-Out found both \\clip and \\iclip on one endpoint; keep exactly one clip type before combining the lines."
      return false
    firstClipKey = if tags1.clip then "clip" elseif tags1.iclip then "iclip" else nil
    secondClipKey = if tags2.clip then "clip" elseif tags2.iclip then "iclip" else nil
    if firstClipKey != secondClipKey
      showMessage "In-Out can only interpolate clips when both endpoints use the same rectangular \\clip or \\iclip tag."
      return false
    for key in *{"clip", "iclip"}
      firstClip, secondClip = tags1[key], tags2[key]
      if firstClip or secondClip
        changedClip = not firstClip or not secondClip or firstClip.raw != secondClip.raw
        if changedClip
          firstKind = transitionClipKind firstClip
          secondKind = transitionClipKind secondClip
          if firstKind == "vector" or secondKind == "vector"
            showMessage "In-Out cannot animate vector \\#{key}; ASS only animates rectangular clips. Keep the vector clip identical or convert it to a rectangle first."
            return false
          if firstKind == "invalid" or secondKind == "invalid"
            showMessage "In-Out found an invalid \\#{key}; use exactly four numeric coordinates for an animated rectangular clip."
            return false
    parts, used = {}, {}
    pos1 = transitionPosition tags1, false
    pos2 = transitionPosition tags2, true
    hasPos1 = tags1.pos or tags1.move
    hasPos2 = tags2.pos or tags2.move
    if (hasPos1 and not pos1) or (hasPos2 and not pos2)
      showMessage "In-Out found an invalid \\pos or \\move tag."
      return false
    if (pos1 and not pos2) or (pos2 and not pos1)
      showMessage "In-Out needs explicit placement on both endpoints, or on neither endpoint."
      return false
    if pos1 and pos2 and (pos1.x != pos2.x or pos1.y != pos2.y)
      parts[#parts + 1] = "\\move(" .. formatNumber(pos1.x, 3) .. "," .. formatNumber(pos1.y, 3) .. "," .. formatNumber(pos2.x, 3) .. "," .. formatNumber(pos2.y, 3) .. ")"
    elseif pos1
      parts[#parts + 1] = "\\pos(" .. formatNumber(pos1.x, 3) .. "," .. formatNumber(pos1.y, 3) .. ")"

    for key in *order1
      t1, t2 = tags1[key], tags2[key]
      if transitionAnimatable[key]
        parts[#parts + 1] = transitionTagText t1
        parts[#parts + 1] = "\\t(" .. transitionTagText(t2) .. ")" if t2 and t1.raw != t2.raw
        used[key] = true
      elseif not transitionSpecial[key]
        parts[#parts + 1] = transitionTagText t1
        used[key] = true

    for key in *order2
      if transitionAnimatable[key] and not used[key]
        parts[#parts + 1] = "\\t(" .. transitionTagText(tags2[key]) .. ")"
        used[key] = true

    fadIn = transitionFadValue tags1.fad, 1
    fadOut = transitionFadValue tags2.fad, 2
    parts[#parts + 1] = "\\fad(" .. fadIn .. "," .. fadOut .. ")" if fadIn > 0 or fadOut > 0

    new_line = cloneLine line1
    new_line.start_time = math.min line1.start_time, line2.start_time
    new_line.end_time = math.max line1.end_time, line2.end_time
    new_line.comment = false
    new_line.text = (if #parts > 0 then "{" .. table.concat(parts) .. "}" else "") .. finalText
    line1.comment = true
    line2.comment = true
    {
      idx1: idx1
      idx2: idx2
      insert_after: math.max(idx1, idx2)
      line1: line1
      line2: line2
      new_line: new_line
    }

  applyInOutTags = (subs, sel, cfg = {}) ->
    pairs, invalidEffects = Obake.collectInOutPairs subs, sel
    unless pairs
      if invalidEffects and #invalidEffects > 0
        labels = [(if effect == "" then "<empty>" else effect) for effect in *invalidEffects]
        showMessage string.format Obake.L("in_out_bad_pairs"), table.concat(labels, ", ")
      else
        showMessage Obake.L("in_out_need_pairs")
      return false
    plans = {}
    for records in *pairs
      plan = Obake.buildInOutPair records
      return false unless plan
      plans[#plans + 1] = plan
    table.sort plans, (a, b) -> a.insert_after > b.insert_after
    okApply, apply_error = pcall ->
      LineOps.transaction subs, "Obake - In-Out tags", ->
        for plan in *plans
          LineOps.checkCancelled!
          subs[plan.idx1] = plan.line1
          subs[plan.idx2] = plan.line2
          subs.insert plan.insert_after + 1, plan.new_line
    unless okApply
      showMessage "In-Out could not apply output atomically: #{apply_error}"
      return false
    Obake.Lines.resultSelection = [plans[n].insert_after + #plans - n + 1 for n = #plans, 1, -1]
    showMessage string.format(Obake.L("in_out_created"), #plans) unless cfg.quiet
    true

  htmlToAss = (value) ->
    assColorValue value

  colorNorm = (value) ->
    assColorValue value

  colorFromStyle = (value) ->
    if type(value) == "string"
      return assColorValue value
    if type(value) == "number"
      n = value
      n += 4294967296 if n < 0
      return assColorValue string.format("&H%06X&", n % 16777216)
    "&HFFFFFF&"

  styleMap = (subs) ->
    styles = {}
    for i = 1, #subs
      line = subs[i]
      if line and line.class == "style" and line.name
        styles[line.name] = line
    styles

  lineDuration = (line) ->
    math.max 0, (tonumber(line and line.end_time) or 0) - (tonumber(line and line.start_time) or 0)

  Obake.Foundation.styleMap = styleMap
  Obake.Foundation.lineDuration = lineDuration

  currentFrameMs = ->
    return nil, "No video frame API." unless aegisub and aegisub.project_properties
    okProps, props = pcall aegisub.project_properties
    return nil, "Could not read project properties." unless okProps
    frame = props and props.video_position
    return nil, "No active video frame." unless frame
    if aegisub.ms_from_frame
      okMs, ms = pcall aegisub.ms_from_frame, frame
      ms = finiteNumber ms
      return ms, nil if okMs and ms
      return nil, "Could not convert the active frame to milliseconds."
    nil, "aegisub.ms_from_frame is unavailable."

  frameSlices = (startMs, endMs, period_frames = 1) ->
    unless aegisub and aegisub.frame_from_ms and aegisub.ms_from_frame
      return nil, Obake.L("frame_api_missing")
    startMs = math.floor((finiteNumber(startMs) or 0) + 0.5)
    endMs = math.floor((finiteNumber(endMs) or startMs) + 0.5)
    return {}, nil unless endMs > startMs
    period = math.max 1, math.floor((finiteNumber(period_frames) or 1) + 0.5)
    okStartFrame, startFrame = pcall aegisub.frame_from_ms, startMs
    okLastFrame, lastFrame = pcall aegisub.frame_from_ms, math.max(startMs, endMs - 1)
    startFrame, lastFrame = finiteNumber(startFrame), finiteNumber(lastFrame)
    startFrame = math.floor startFrame if okStartFrame and startFrame
    lastFrame = math.floor lastFrame if okLastFrame and lastFrame
    return nil, Obake.L("frame_api_missing") unless startFrame and lastFrame
    slices = {}
    frame = startFrame
    while frame <= lastFrame
      LineOps.checkCancelled!
      nextFrame = math.min frame + period, lastFrame + 1
      return nil, "Frame indices exceed numeric precision." unless nextFrame > frame
      okSliceStart, slice_start = pcall aegisub.ms_from_frame, frame
      okSliceEnd, slice_end = pcall aegisub.ms_from_frame, nextFrame
      slice_start, slice_end = finiteNumber(slice_start), finiteNumber(slice_end)
      return nil, Obake.L("frame_api_missing") unless okSliceStart and okSliceEnd and slice_start and slice_end
      slice_start = math.max startMs, math.floor(slice_start + 0.5)
      slice_end = math.min endMs, math.floor(slice_end + 0.5)
      slice_end = math.min endMs, slice_start + 1 if slice_end <= slice_start
      slices[#slices + 1] = {start_time: slice_start, end_time: slice_end} if slice_end > slice_start
      frame = nextFrame
    slices, nil

  Obake.Foundation.currentFrameMs = currentFrameMs
  Obake.Foundation.frameSlices = frameSlices

  lineIsSingleFrame = (line) ->
    return false unless line.end_time > line.start_time
    firstOk, first = pcall aegisub.frame_from_ms, line.start_time
    lastOk, last = pcall aegisub.frame_from_ms, math.max(line.start_time, line.end_time - 1)
    firstOk and lastOk and finiteNumber(first) != nil and first == last

  selectionIsSingleFrameFbf = (subs, indices) ->
    return false unless aegisub and aegisub.frame_from_ms and aegisub.ms_from_frame
    return false unless indices and #indices > 0
    for index in *indices
      return false unless lineIsSingleFrame subs[index]
    true

  resolveOffset = (line, dur, cfg) ->
    mode = cfg.delay_mode or "No delay"
    return 0 if mode == "No delay"
    if mode == "ms from start"
      return clamp cfg.delay_val, 0, dur
    if mode == "Percent (%)"
      return math.floor(dur * clamp((tonumber(cfg.delay_val) or 0) / 100, 0, 1) + 0.5)
    if mode == "Current frame"
      fms = currentFrameMs!
      return clamp((fms or line.start_time) - line.start_time, 0, dur) if fms
    0

  interpolateSimple = (ini, fin, factor, line) ->
    ini, fin = tostring(ini or ""), tostring(fin or "")
    return fin if fin == ""
    probe = cloneLine line
    prefix = "{" .. ini
    probe.text = prefix .. "\\t(0,1," .. fin .. ")}"
    probe.start_time, probe.end_time = 0, 1
    sampled = AssContext.sampleTransforms probe, factor, ASS, AMLine
    sampled\sub #prefix + 1, -2

  chainDefaultRows = ->
    {
      {time: 0, tags: "\\fscx100\\fscy100"}
      {time: 100, tags: "\\fscx110\\fscy110"}
    }

  normalizeChainState = (state) ->
    state or= {}
    state.time_unit = enumValue state.time_unit, timeUnits, DEFAULTS.time_unit
    state.chain_shape = enumValue state.chain_shape, chainShapes, DEFAULTS.chain_shape
    state.strip_existing = state.strip_existing != false
    state.use_accel = state.use_accel and true or false
    state.accel = finiteNumber(state.accel) or DEFAULTS.accel
    state.accel = DEFAULTS.accel unless state.accel > 0
    state.shape_val = finiteNumber(state.shape_val) or DEFAULTS.shape_val
    state.delay_mode = enumValue state.delay_mode, delayModes, DEFAULTS.delay_mode
    state.delay_val = finiteNumber(state.delay_val) or 0
    rows = {}
    for row in *(state.rows or chainDefaultRows!)
      tags = tostring(row.tags or "")
      time = finiteNumber(row.time)
      if time != nil or tags != ""
        rows[#rows + 1] = {time: time or 0, tags: tags}
    rows = chainDefaultRows! if #rows < 2
    state.rows = rows
    state

  buildShapeChain = (line, state) ->
    dur = lineDuration line
    return "" unless dur > 0
    rows = state.rows or chainDefaultRows!
    tagsIni = rows[1] and rows[1].tags or ""
    tagsFin = rows[#rows] and rows[#rows].tags or ""
    accel = if state.use_accel then state.accel else nil
    offset = resolveOffset line, dur, state
    effDur = dur - offset
    return "" unless effDur > 0
    tEnd = offset + effDur
    payload = {tagsIni}
    switch state.chain_shape
      when "Once (one-way)"
        payload[#payload + 1] = transformTag offset, tEnd, tagsFin, accel if tagsFin != ""
      when "Out and back"
        mid = offset + effDur / 2
        payload[#payload + 1] = transformTag offset, mid, tagsFin, accel if tagsFin != ""
        payload[#payload + 1] = transformTag mid, tEnd, tagsIni, accel if tagsIni != ""
      when "Yoyo (N cycles)"
        cycles = math.max 1, math.floor(tonumber(state.shape_val) or 1)
        seg = effDur / (cycles * 2)
        for i = 0, cycles * 2 - 1
          LineOps.checkCancelled!
          t1 = offset + seg * i
          t2 = offset + seg * (i + 1)
          payload[#payload + 1] = transformTag(t1, t2, if i % 2 == 0 then tagsFin else tagsIni, accel)
      when "Pulse (ms)"
        half = math.max 1, math.floor(finiteNumber(state.shape_val) or 200)
        t, forward = offset, true
        while t < tEnd
          LineOps.checkCancelled!
          t2 = math.min t + half, tEnd
          payload[#payload + 1] = transformTag(t, t2, if forward then tagsFin else tagsIni, accel)
          t = t2
          forward = not forward
      when "Steps (N)"
        steps = math.max 2, math.floor(finiteNumber(state.shape_val) or 4)
        for i = 1, steps
          LineOps.checkCancelled!
          factor = i / steps
          t1 = offset + (effDur / steps) * (i - 1)
          t2 = offset + (effDur / steps) * i
          payload[#payload + 1] = transformTag t1, t2, interpolateSimple(tagsIni, tagsFin, factor, line), accel
    table.concat payload

  buildManualChain = (line, state) ->
    dur = lineDuration line
    return "" unless dur > 0
    rows = {}
    for order, row in ipairs(state.rows or {})
      tags = tostring(row.tags or "")
      continue if tags == ""
      rawTime = finiteNumber(row.time) or 0
      t = if state.time_unit == "Percent" then dur * rawTime / 100 else rawTime
      t = clamp t, 0, dur
      rows[#rows + 1] = {time: t, tags: tags, order: order}
    table.sort rows, (a, b) -> if a.time == b.time then a.order < b.order else a.time < b.time
    compact = {}
    for row in *rows
      if #compact > 0 and compact[#compact].time == row.time
        compact[#compact] = row
      else
        compact[#compact + 1] = row
    rows = compact
    return "" if #rows == 0
    accel = if state.use_accel then state.accel else nil
    payload = {rows[1].tags}
    for i = 2, #rows
      prev = rows[i - 1]
      row = rows[i]
      payload[#payload + 1] = transformTag prev.time, row.time, row.tags, accel
    table.concat payload

  buildChain = (line, state) ->
    state = normalizeChainState state
    if state.chain_shape == "Manual keyframes"
      buildManualChain line, state
    else
      buildShapeChain line, state

  applyChain = (subs, sel, state) ->
    updates, errors = {}, {}
    state = normalizeChainState state
    collection = AssContext.fromSubtitles subs
    for i in *Obake.Selection.dialogueIndices subs, sel
      LineOps.checkCancelled!
      line = AssContext.toLine subs[i], AMLine, {collection: collection}
      dur = lineDuration line
      if dur <= 0
        errors[#errors + 1] = "#{Obake.L('line')} #{i}: #{Obake.L('zero_duration')}"
      else
        payload = buildChain line, state
        if payload != ""
          text = line.text or ""
          text = stripTransforms text if state.strip_existing
          line.text = injectTransformFirst text, payload
          updates[#updates + 1] = {index: i, line: line}
    if #errors > 0
      showMessage table.concat errors, "\n"
      return false
    if #updates > 0
      okApply, apply_error = Obake.Lines.commitUpdates subs, updates, "Obake - Apply chain"
      unless okApply
        showMessage "Apply chain could not apply changes atomically: #{apply_error}"
        return false
      return true
    showMessage if #errors > 0 then table.concat(errors, "\n") else Obake.L("no_transform_chain")
    false

  readChainState = (res, count, previous = {}) ->
    state = {
      time_unit: res.time_unit
      chain_shape: res.chain_shape
      strip_existing: res.strip_existing
      use_accel: res.use_accel
      accel: res.accel
      shape_val: res.shape_val
      delay_mode: res.delay_mode
      delay_val: res.delay_val
      rows: {}
    }
    for i = 1, count
      row = previous[i] or {}
      state.rows[#state.rows + 1] = {
        time: finiteNumber(res["time#{i}"]) or row.time or 0
        tags: tostring(res["tags#{i}"] or row.tags or "")
      }
    normalizeChainState state

  commonTagRows = ->
    math.ceil #commonTags / commonTagColumns

  addCommonTagGrid = (gui, y) ->
    gui[#gui + 1] = {class: "label", label: Obake.L("common_tags"), x: 0, y: y, width: CHAIN_DIALOG_W}
    for i, tag in ipairs commonTags
      index = i - 1
      col = index % commonTagColumns
      row = math.floor index / commonTagColumns
      gui[#gui + 1] = {
        class: "textbox"
        name: "common#{i}"
        text: tag
        x: col * COMMON_TAG_W
        y: y + 1 + row
        width: COMMON_TAG_W
        height: 1
      }
    y + 1 + commonTagRows!

  buildChainGui = (state, page = 1) ->
    state = normalizeChainState state
    shape_items, shapeMap, shapeShown = Obake.dropdownData chainShapes
    delay_items, delayMap, delayShown = Obake.dropdownData delayModes
    gui = {}
    controls_y = addCommonTagGrid(gui, 0) + 1
    gui[#gui + 1] = {class: "label", label: Obake.L("time_unit"), x: 0, y: controls_y, width: 3}
    gui[#gui + 1] = {class: "dropdown", name: "time_unit", items: Obake.localizedItems(timeUnits), value: Obake.choiceLabel(state.time_unit), x: 3, y: controls_y, width: 5}
    gui[#gui + 1] = {class: "checkbox", name: "strip_existing", label: Obake.L("strip_existing_t"), value: state.strip_existing, x: 9, y: controls_y, width: 8}
    gui[#gui + 1] = {class: "checkbox", name: "use_accel", label: Obake.L("accel"), value: state.use_accel, x: 18, y: controls_y, width: 2}
    gui[#gui + 1] = {class: "floatedit", name: "accel", value: state.accel, min: 0, x: 20, y: controls_y, width: 3}
    gui[#gui + 1] = {class: "label", label: Obake.L("shape"), x: 0, y: controls_y + 1, width: 3}
    gui[#gui + 1] = {class: "dropdown", name: "chain_shape", items: shape_items, value: Obake.shownChoice(shapeShown, state.chain_shape), x: 3, y: controls_y + 1, width: 7}
    gui[#gui + 1] = {class: "label", label: Obake.L("value"), x: 11, y: controls_y + 1, width: 3}
    gui[#gui + 1] = {class: "floatedit", name: "shape_val", value: state.shape_val, min: 0, x: 14, y: controls_y + 1, width: 3}
    gui[#gui + 1] = {class: "label", label: Obake.L("delay"), x: 0, y: controls_y + 2, width: 3}
    gui[#gui + 1] = {class: "dropdown", name: "delay_mode", items: delay_items, value: Obake.shownChoice(delayShown, state.delay_mode), x: 3, y: controls_y + 2, width: 7}
    gui[#gui + 1] = {class: "floatedit", name: "delay_val", value: state.delay_val, min: 0, x: 11, y: controls_y + 2, width: 3}
    header_y = controls_y + 4
    gui[#gui + 1] = {class: "label", label: Obake.L("time"), x: 0, y: header_y, width: 3}
    gui[#gui + 1] = {class: "label", label: Obake.L("tags"), x: 3, y: header_y, width: CHAIN_DIALOG_W - 3}
    y = header_y + 1
    first = (page - 1) * CONSTANTS.CHAIN_PAGE_ROWS + 1
    last = math.min #state.rows, first + CONSTANTS.CHAIN_PAGE_ROWS - 1
    gui[#gui + 1] = {class: "label", label: "#{first}-#{last} / #{#state.rows}", x: 0, y: y, width: CHAIN_DIALOG_W}
    y += 1
    for i = first, last
      row = state.rows[i]
      gui[#gui + 1] = {class: "edit", name: "time#{i}", value: formatNumber(row.time, 3), x: 0, y: y + i - first, width: 3}
      gui[#gui + 1] = {class: "textbox", name: "tags#{i}", text: row.tags, x: 3, y: y + i - first, width: CHAIN_DIALOG_W - 3, height: 1}
    gui, shapeMap, delayMap

  showChainOptions = ->
    state = normalizeChainState Obake.settings\values "chain"
    page = 1
    while true
      page = clamp page, 1, math.ceil(#state.rows / CONSTANTS.CHAIN_PAGE_ROWS)
      gui, shapeMap, delayMap = buildChainGui state, page
      previous = if current_language == "es" then "Anterior" else "Previous"
      following = if current_language == "es" then "Siguiente" else "Next"
      button, res = aegisub.dialog.display gui, {Obake.L("apply"), "Add+", "Rem-", previous, following, Obake.L("reset"), Obake.L("cancel")}, {ok: Obake.L("apply"), close: Obake.L("cancel")}
      return nil if button == Obake.L("cancel") or not button
      if button == Obake.L("reset")
        state = normalizeChainState {}
        continue
      res.time_unit = Obake.choiceRaw res.time_unit
      res.chain_shape = Obake.rawChoice shapeMap, res.chain_shape
      res.delay_mode = Obake.rawChoice delayMap, res.delay_mode
      state = readChainState res, #state.rows, state.rows
      switch button
        when "Add+"
          last = state.rows[#state.rows]
          state.rows[#state.rows + 1] = {time: last.time, tags: last.tags}
          page = math.ceil #state.rows / CONSTANTS.CHAIN_PAGE_ROWS
        when "Rem-"
          table.remove state.rows if #state.rows > 2
        when previous
          page -= 1
        when following
          page += 1
        when Obake.L("apply")
          Obake.settings\update "chain", state
          Obake.writeConfig Obake.settings
          return state

  htmlColorControls = (x, y, color1, color2 = nil) ->
    out = {
      {class: "label", label: Obake.L("color1"), x: x, y: y, width: 2}
      {class: "color", name: "fx_color", value: color1, x: x + 2, y: y, width: 2, height: 2}
    }
    if color2 != nil
      out[#out + 1] = {class: "label", label: Obake.L("color2"), x: x + 5, y: y, width: 2}
      out[#out + 1] = {class: "color", name: "fx_color2", value: color2, x: x + 7, y: y, width: 2, height: 2}
    out

  showFxOptions = ->
    saved = Obake.settings\values "fx"
    fx_items, fxMap, fxShown = Obake.dropdownData fxItems
    gui = {
      {class: "label", label: "FX:", x: 0, y: 0, width: 2}
      {class: "dropdown", name: "fx_preset", items: fx_items, value: Obake.shownChoice(fxShown, saved.fx_preset), x: 2, y: 0, width: 8}
      {class: "checkbox", name: "strip_existing", label: Obake.L("strip_existing_t"), value: saved.strip_existing, x: 0, y: 1, width: 6}
      {class: "checkbox", name: "use_accel", label: Obake.L("accel"), value: saved.use_accel, x: 6, y: 1, width: 2}
      {class: "floatedit", name: "accel", value: saved.accel, min: 0, x: 8, y: 1, width: 3}
      {class: "label", label: Obake.L("step_ms"), x: 0, y: 2, width: 2}
      {class: "intedit", name: "fx_step_ms", value: saved.fx_step_ms, min: 1, x: 2, y: 2, width: 3}
      {class: "label", label: Obake.L("amount"), x: 6, y: 2, width: 2}
      {class: "floatedit", name: "fx_amount", value: saved.fx_amount, x: 8, y: 2, width: 3}
    }
    for item in *htmlColorControls 0, 4, saved.fx_color, saved.fx_color2
      gui[#gui + 1] = item
    button, res = aegisub.dialog.display gui, {Obake.L("apply"), Obake.L("cancel")}, {ok: Obake.L("apply"), close: Obake.L("cancel")}
    return nil unless button == Obake.L("apply")
    res.fx_preset = Obake.rawChoice fxMap, res.fx_preset
    Obake.settings\update "fx", res
    Obake.writeConfig Obake.settings
    res.fx_color = htmlToAss res.fx_color
    res.fx_color2 = htmlToAss res.fx_color2
    res

  showPresetOptions = ->
    saved = Obake.settings\values "preset"
    preset_items, presetMap, presetShown = Obake.dropdownData CAL_PRESETS
    gui = {
      {class: "label", label: Obake.L("preset"), x: 0, y: 0, width: 2}
      {class: "dropdown", name: "cal_preset", items: preset_items, value: Obake.shownChoice(presetShown, saved.cal_preset), x: 2, y: 0, width: 9}
    }
    button, res = aegisub.dialog.display gui, {Obake.L("apply"), Obake.L("cancel")}, {ok: Obake.L("apply"), close: Obake.L("cancel")}
    return nil unless button == Obake.L("apply")
    res.cal_preset = Obake.rawChoice presetMap, res.cal_preset
    Obake.settings\update "preset", res
    Obake.writeConfig Obake.settings
    res

  showBorderOptions = ->
    saved = Obake.settings\values "border"
    gui = {
      {class: "checkbox", name: "use_bord1", label: "B1", value: saved.use_bord1, x: 0, y: 0, width: 2}
      {class: "floatedit", name: "bord1", value: saved.bord1, min: 0, x: 2, y: 0, width: 3}
      {class: "color", name: "color1", value: saved.color1, x: 5, y: 0, width: 2, height: 2}
      {class: "checkbox", name: "use_bord2", label: "B2", value: saved.use_bord2, x: 0, y: 2, width: 2}
      {class: "floatedit", name: "bord2", value: saved.bord2, min: 0, x: 2, y: 2, width: 3}
      {class: "color", name: "color2", value: saved.color2, x: 5, y: 2, width: 2, height: 2}
      {class: "checkbox", name: "use_bord3", label: "B3", value: saved.use_bord3, x: 0, y: 4, width: 2}
      {class: "floatedit", name: "bord3", value: saved.bord3, min: 0, x: 2, y: 4, width: 3}
      {class: "color", name: "color3", value: saved.color3, x: 5, y: 4, width: 2, height: 2}
      {class: "checkbox", name: "use_bord4", label: "B4", value: saved.use_bord4, x: 0, y: 6, width: 2}
      {class: "floatedit", name: "bord4", value: saved.bord4, min: 0, x: 2, y: 6, width: 3}
      {class: "color", name: "color4", value: saved.color4, x: 5, y: 6, width: 2, height: 2}
    }
    button, res = aegisub.dialog.display gui, {Obake.L("apply"), Obake.L("cancel")}, {ok: Obake.L("apply"), close: Obake.L("cancel")}
    return nil unless button == Obake.L("apply")
    Obake.settings\update "border", res
    Obake.writeConfig Obake.settings
    res.color1 = htmlToAss res.color1
    res.color2 = htmlToAss res.color2
    res.color3 = htmlToAss res.color3
    res.color4 = htmlToAss res.color4
    res

  gunConfigState = (interface) ->
    state = {}
    for _, item in pairs interface.main
      if item.config and item.name
        state[item.name] = item.value
    state

  gunBuildInterface = (found, state) ->
    state or= gunDefaults
    main = {
      title: {class: "label", label: "Gunfight of Tags - numeric override tags", x: 0, y: 0, width: 16, height: 1}
      min_label: {class: "label", label: "Min", x: 0, y: 1, width: 2, height: 1}
      min_delta: {class: "floatedit", name: "min_delta", value: state.min_delta, config: true, x: 2, y: 1, width: 3, height: 1}
      max_label: {class: "label", label: "Max", x: 5, y: 1, width: 2, height: 1}
      max_delta: {class: "floatedit", name: "max_delta", value: state.max_delta, config: true, x: 7, y: 1, width: 3, height: 1}
      step_label: {class: "label", label: "Step", x: 10, y: 1, width: 2, height: 1}
      step: {class: "floatedit", name: "step", value: state.step, min: 0, config: true, x: 12, y: 1, width: 3, height: 1}
      dec_label: {class: "label", label: "Dec", x: 0, y: 2, width: 2, height: 1}
      decimals: {class: "intedit", name: "decimals", value: state.decimals, min: 0, max: 8, config: true, x: 2, y: 2, width: 2, height: 1}
      seed_label: {class: "label", label: "Seed", x: 4, y: 2, width: 2, height: 1}
      seed: {class: "intedit", name: "seed", value: state.seed, min: 0, max: CONSTANTS.MAX_RANDOM_SEED, config: true, x: 6, y: 2, width: 4, height: 1}
      fbf_label: {class: "label", label: Obake.L("fbf_period"), x: 10, y: 2, width: 3, height: 1}
      fbf_period: {class: "intedit", name: "fbf_period", value: state.fbf_period, min: 1, config: true, x: 13, y: 2, width: 3, height: 1}
      scope_label: {class: "label", label: "Link", x: 0, y: 3, width: 2, height: 1}
      random_scope: {class: "dropdown", name: "random_scope", items: GUN_RANDOM_SCOPES, value: gunChoiceOrDefault(state.random_scope, GUN_RANDOM_SCOPES, gunDefaults.random_scope), config: true, x: 2, y: 3, width: 4, height: 1}
      show_report: {class: "checkbox", name: "show_report", label: "Report", value: state.show_report, config: true, x: 8, y: 3, width: 3, height: 1}
      selection_as_fbf_unit: {class: "checkbox", name: "selection_as_fbf_unit", label: Obake.L("selection_as_fbf_unit"), value: state.selection_as_fbf_unit != false, config: true, x: 0, y: 4, width: 10, height: 1}
      use_x: {class: "checkbox", name: "use_x", label: "X coords", value: state.use_x, config: true, x: 0, y: 5, width: 2, height: 1}
      use_y: {class: "checkbox", name: "use_y", label: "Y coords", value: state.use_y, config: true, x: 2, y: 5, width: 2, height: 1}
      use_scalar: {class: "checkbox", name: "use_scalar", label: "Scalar/discrete", value: state.use_scalar, config: true, x: 4, y: 5, width: 3, height: 1}
      use_time: {class: "checkbox", name: "use_time", label: "Times", value: state.use_time, config: true, x: 7, y: 5, width: 2, height: 1}
      include_transform_inner: {class: "checkbox", name: "include_transform_inner", label: "Inside \\t", value: state.include_transform_inner, config: true, x: 0, y: 6, width: 2, height: 1}
      include_transform_args: {class: "checkbox", name: "include_transform_args", label: "\\t args", value: state.include_transform_args, config: true, x: 2, y: 6, width: 2, height: 1}
      include_auto_blocks: {class: "checkbox", name: "include_auto_blocks", label: "{*} blocks", value: state.include_auto_blocks, config: true, x: 4, y: 6, width: 2, height: 1}
      clamp_nonnegative: {class: "checkbox", name: "clamp_nonnegative", label: "Clamp >=0", value: state.clamp_nonnegative, config: true, x: 6, y: 6, width: 2, height: 1}
      protect_discrete: {class: "checkbox", name: "protect_discrete", label: "Discrete safe", value: state.protect_discrete, config: true, x: 8, y: 6, width: 2, height: 1}
      note: {class: "label", label: "Tags shown are numeric/hex tags found in the current selection.", x: 0, y: 7, width: 16, height: 1}
    }
    row0 = 9
    shown = 0
    for def in *gunTagDefs
      meta = found[def.key]
      if meta
        col = shown % 6
        row = math.floor shown / 6
        main["tag_" .. def.key] = {
          class: "checkbox"
          name: "tag_" .. def.key
          label: def.label .. " (" .. tostring(meta.count) .. ")"
          value: state["tag_" .. def.key] == true
          config: true
          x: col * 2
          y: row0 + row
          width: 2
          height: 1
        }
        shown += 1
    main.no_tags = {class: "label", label: Obake.L("no_numeric_tags"), x: 0, y: row0, width: 8, height: 1} if shown == 0
    {main: main}

  gunReadStateFromResult = (result, found) ->
    state = {}
    for key, value in pairs gunDefaults
      state[key] = value
    state.min_delta = finiteNumber(result.min_delta) or gunDefaults.min_delta
    state.max_delta = finiteNumber(result.max_delta) or gunDefaults.max_delta
    state.step = math.max 0, finiteNumber(result.step) or gunDefaults.step
    state.decimals = clamp roundInteger(result.decimals), 0, 8
    state.seed = clamp roundInteger(result.seed), 0, CONSTANTS.MAX_RANDOM_SEED
    state.random_scope = gunChoiceOrDefault result.random_scope, GUN_RANDOM_SCOPES, gunDefaults.random_scope
    state.use_x = result.use_x == true
    state.use_y = result.use_y == true
    state.use_scalar = result.use_scalar == true
    state.use_time = result.use_time == true
    state.include_transform_inner = result.include_transform_inner == true
    state.include_transform_args = result.include_transform_args == true
    state.include_auto_blocks = result.include_auto_blocks == true
    state.clamp_nonnegative = result.clamp_nonnegative == true
    state.protect_discrete = result.protect_discrete == true
    state.show_report = result.show_report == true
    state.fbf_period = math.max 1, roundInteger(result.fbf_period)
    state.selection_as_fbf_unit = result.selection_as_fbf_unit == true
    for def in *gunTagDefs
      state["tag_" .. def.key] = result["tag_" .. def.key] == true if found[def.key]
    state

  showGunfightOptions = (subs, sel) ->
    includeAuto = gunDefaults.include_auto_blocks
    found = gunCollectNumericTags subs or {}, sel or {}, includeAuto
    cfg = nil
    while true
      interface = gunBuildInterface found, gunDefaults
      options = Obake.ConfigHandler interface, gunConfigFile, true, gunConfigVersion
      options\read!
      options\updateInterface "main"
      state = gunConfigState interface
      if cfg
        for key, value in pairs cfg
          state[key] = value
      while true
        interface = gunBuildInterface found, state
        button, result = aegisub.dialog.display interface.main, {Obake.L("apply"), "All", "Clear", Obake.L("cancel")}, {ok: Obake.L("apply"), close: Obake.L("cancel")}
        return nil unless button and button != Obake.L("cancel")
        state = gunReadStateFromResult result, found
        if button == "All"
          for def in *gunTagDefs
            state["tag_" .. def.key] = true if found[def.key]
          continue
        if button == "Clear"
          for def in *gunTagDefs
            state["tag_" .. def.key] = false if found[def.key]
          continue
        cfg = state
        break
      if cfg.include_auto_blocks == includeAuto
        options = Obake.ConfigHandler (gunBuildInterface found, cfg), gunConfigFile, true, gunConfigVersion
        options\updateConfiguration cfg, "main"
        Obake.writeConfig options
        cfg.operation = "Gunfight of Tags"
        return cfg
      includeAuto = cfg.include_auto_blocks
      found = gunCollectNumericTags subs or {}, sel or {}, includeAuto

  showZigzagOptions = ->
    gui = {
      period_label: {class: "label", label: Obake.L("zigzag_period"), x: 0, y: 0, width: 2}
      period_frames: {class: "intedit", name: "period_frames", value: ZIGZAG_DEFAULTS.period_frames, min: 1, x: 2, y: 0, width: 2, config: true}
    }
    options = Obake.ConfigHandler {main: gui}, zigzagConfigFile, true, script_version
    options\read!
    options\updateInterface "main"
    button, res = aegisub.dialog.display gui, {Obake.L("apply"), Obake.L("cancel")}, {ok: Obake.L("apply"), close: Obake.L("cancel")}
    return nil unless button == Obake.L("apply")
    res.period_frames = math.max 1, roundInteger(res.period_frames)
    options\updateConfiguration res, "main"
    Obake.writeConfig options
    res

  WINDOW_W = 24
  PICKER_HELP_H = 10

  Obake.pickerHelpText = (operation) ->
    Obake.actionHelp(operation) or Obake.L("select_action")

  Obake.actionPickerGui = (operation) ->
    items, to_raw, toShown = Obake.dropdownData OPERATIONS, Obake.operationLabel
    gui = {
      {class: "label", label: Obake.L("action"), x: 0, y: 0, width: 3}
      {class: "dropdown", name: "operation", items: items, value: Obake.shownChoice(toShown, operation or DEFAULTS.operation), x: 3, y: 0, width: WINDOW_W - 3}
      {class: "textbox", value: Obake.pickerHelpText(operation or DEFAULTS.operation), x: 0, y: 1, width: WINDOW_W, height: PICKER_HELP_H}
    }
    gui, to_raw, toShown

  Obake.actionPicker = ->
    saved = Obake.settings\values "main"
    saveOperation = (chosen) ->
      Obake.settings\update "main", {operation: chosen}
      Obake.writeConfig Obake.settings
    onHelp = (chosen) -> saveOperation chosen
    onLanguage = (chosen) ->
      saveOperation chosen
      Obake.toggleLanguage!
    onRun = (chosen) -> saveOperation chosen
    Obake.UI.chooseAction {
      current: saved.operation
      build: (current) ->
        gui, to_raw = Obake.actionPickerGui current
        gui, {to_raw: to_raw}
      buttons: ->
        run, help, language, cancel = Obake.L("run"), Obake.L("help"), Obake.L("language"), Obake.L("cancel")
        {run: run, help: help, language: language, cancel: cancel, order: {run, help, language, cancel}}
      read: (result, current, context) ->
        Obake.rawOperationChoice context.to_raw, result and result.operation or current
      on_help: onHelp
      on_language: onLanguage
      on_run: onRun
    }

  Obake.actionHelpPicker = ->
    current = DEFAULTS.operation
    while true
      gui, to_raw = Obake.actionPickerGui current
      btn_help, btnLanguage, btn_close = Obake.L("help"), Obake.L("language"), Obake.L("close")
      button, res = aegisub.dialog.display gui, {btn_help, btnLanguage, btn_close}, {ok: btn_help, close: btn_close}
      if button == btn_help
        current = Obake.rawOperationChoice to_raw, res and res.operation or current
      elseif button == btnLanguage
        current = Obake.rawOperationChoice to_raw, res and res.operation or current
        Obake.toggleLanguage!
      else
        return

  Obake.showActionOptions = (operation, subs, sel) ->
    spec = Obake.Operations[operation]
    return nil unless spec
    return {operation: operation} if spec.direct
    spec.options subs, sel if spec.options

  Obake.Selection.dialogueIndices = (subs, sel) ->
    LineOps.normalizeIndices subs, sel, (line) -> isDialogue line

  Obake.Selection.dialogueRecords = (subs, sel, requireAll = false) ->
    records = LineOps.selectedLines subs, sel, ((line) -> isDialogue line), requireAll
    records

  Obake.Selection.descending = (indices) ->
    out = [i for i in *(indices or {})]
    table.sort out, (a, b) -> a > b
    out

  Obake.Lines.replaceOneWithMany = (subs, index, lines) ->
    return false unless lines and #lines > 0
    subs.delete index
    LineOps.insertLines subs, {{index: index, lines: lines}}
    true

  Obake.Lines.commitUpdates = (subs, updates, undoName) ->
    return false, "No updates." unless updates and #updates > 0
    pcall ->
      LineOps.transaction subs, undoName, ->
        for update in *updates
          LineOps.checkCancelled!
          subs[update.index] = update.line
        LineOps.checkCancelled!

  Obake.Lines.commitReplacements = (subs, plans, undoName, onApplied = nil) ->
    return false, "No replacement plans." unless plans and #plans > 0
    ordered = [plan for plan in *plans]
    table.sort ordered, (a, b) -> a.index > b.index
    ok, err = pcall ->
      LineOps.transaction subs, undoName, ->
        for position, plan in ipairs ordered
          LineOps.checkCancelled!
          error "Invalid empty replacement plan for line #{plan.index}." unless plan.lines and Obake.Lines.replaceOneWithMany(subs, plan.index, plan.lines)
          onApplied plan, position, #ordered if onApplied
        LineOps.checkCancelled!
    if ok
      selected, offset = {}, 0
      for n = #ordered, 1, -1
        plan = ordered[n]
        for row = 1, #plan.lines
          selected[#selected + 1] = plan.index + offset + row - 1
        offset += #plan.lines - 1
      Obake.Lines.resultSelection = selected
    ok, err

  Obake.Lines.replacementPlans = (subs, sel, builder) ->
    plans, errors = {}, {}
    for index in *Obake.Selection.dialogueIndices(subs, sel)
      LineOps.checkCancelled!
      lines, err = builder subs[index], index
      if lines and #lines > 0
        plans[#plans + 1] = {index: index, lines: lines}
      elseif err
        errors[#errors + 1] = "#{Obake.L('line')} #{index}: #{err}"
    plans, errors

  gunSelectedTags = (cfg) ->
    selected = {}
    for def in *gunTagDefs
      selected[def.key] = true if cfg["tag_" .. def.key]
    selected

  gunProcessLine = (line, selected, cfg, sequenceIndex, cache = nil, random = nil) ->
    nextText, count = gunProcessText line.text or "", selected, cfg, sequenceIndex, cache, random
    out = cloneLine line
    out.text = nextText
    out, count, nextText != (line.text or "")

  sampleSlice = (source, slice, collection) ->
    line = AssContext.toLine source, AMLine, {collection: collection}
    offset = slice.start_time - source.start_time
    line.text = AssContext.sampleTransforms line, offset, ASS, AMLine
    line.text = AssContext.samplePosition line.text, lineDuration(source), offset
    line.text = AssContext.sampleFade line, line.text, offset
    AssContext.shiftFrameKaraoke line, source.start_time, slice.start_time
    line.start_time, line.end_time = slice.start_time, slice.end_time
    line

  gunFbfLinesForLine = (line, selected, cfg, sequenceStart = 1, random = nil, collection = nil) ->
    slices, err = frameSlices line.start_time, line.end_time, cfg.fbf_period
    return nil, err if err
    return nil, Obake.L("no_fbf_slices") unless slices and #slices > 0
    out = {}
    changed_tags = 0
    changedText = 0
    for n, slice in ipairs slices
      LineOps.checkCancelled!
      next_line, count, changed = gunProcessLine line, selected, cfg, sequenceStart + n - 1, nil, random
      next_line = sampleSlice next_line, slice, collection
      out[#out + 1] = next_line
      changed_tags += count
      changedText += 1 if changed
    out, nil, changed_tags, changedText

  applyGunfightOfTags = (subs, sel, cfg) ->
    cfg or= gunDefaults
    selected = gunSelectedTags cfg
    unless gunHasAnySelected selected
      showMessage Obake.L("select_gun_tag")
      return false
    indices = Obake.Selection.dialogueIndices subs, sel
    unless #indices > 0
      showMessage Obake.L("no_lines_changed")
      return false
    random, seed_used = gunSeedRandom cfg.seed
    changed_lines, changed_tags, produced_lines, skipped = 0, 0, 0, 0
    period = math.max 1, roundInteger(cfg.fbf_period)
    recognizedFbf = cfg.selection_as_fbf_unit and #indices > 1 and selectionIsSingleFrameFbf(subs, indices)
    if cfg.selection_as_fbf_unit and #indices > 1
      groupCaches, updates = {}, {}
      for n, index in ipairs indices
        LineOps.checkCancelled!
        line = subs[index]
        group = math.floor((n - 1) / period) + 1
        groupCaches[group] or= {}
        next_line, count, changed = gunProcessLine line, selected, cfg, group, groupCaches[group], random
        if changed
          updates[#updates + 1] = {index: index, line: next_line}
          changed_lines += 1
        changed_tags += count
        aegisub.progress.set math.floor 100 * n / math.max(1, #indices)
      if #updates > 0
        okApply, apply_error = Obake.Lines.commitUpdates subs, updates, "Obake - Gunfight of Tags"
        unless okApply
          showMessage "Gunfight of Tags could not apply changes atomically: #{apply_error}"
          return false
    else
      plans = {}
      collection = AssContext.fromSubtitles subs
      for index in *indices
        line = subs[index]
        unless isDialogue line
          skipped += 1
          continue
        lines, err, count, changedText = gunFbfLinesForLine line, selected, cfg, 1, random, collection
        if err
          showMessage "#{Obake.L('line')} #{index}: #{err}"
          return false
        if changedText and changedText > 0
          plans[#plans + 1] = {index: index, lines: lines, count: count or 0}
        else
          skipped += 1
      if #plans > 0
        okApply, apply_error = Obake.Lines.commitReplacements subs, plans, "Obake - Gunfight of Tags", (plan, completed, total) ->
          produced_lines += #plan.lines
          changed_lines += 1
          changed_tags += plan.count
          aegisub.progress.set math.floor 100 * completed / math.max(1, total)
        unless okApply
          showMessage "Gunfight of Tags could not apply FBF output atomically: #{apply_error}"
          return false
    if changed_lines == 0 and produced_lines == 0
      showMessage Obake.L("gun_no_change")
      return false
    if cfg.show_report
      detail = "Gunfight of Tags changed #{changed_tags} value(s) in #{changed_lines} source line(s).\nSeed: #{seed_used}"
      detail ..= "\nRecognized one-frame FBF selection." if recognizedFbf
      detail ..= "\nProduced FBF lines: #{produced_lines}" if produced_lines > 0
      detail ..= "\nSkipped non-dialogue lines: #{skipped}" if skipped > 0
      showMessage detail
    true

  applyZigzagLines = (subs, sel, cfg) ->
    cfg or= ZIGZAG_DEFAULTS
    indices = Obake.Selection.dialogueIndices subs, sel
    unless #indices >= 2
      showMessage Obake.L("zigzag_need_lines")
      return false
    templates = {}
    collection = AssContext.fromSubtitles subs
    startMs, endMs = nil, nil
    for index in *indices
      line = cloneLine subs[index]
      templates[#templates + 1] = line
      startMs = line.start_time if not startMs or line.start_time < startMs
      endMs = line.end_time if not endMs or line.end_time > endMs
    slices, err = frameSlices startMs, endMs, cfg.period_frames
    if err
      showMessage err
      return false
    unless slices and #slices > 0
      showMessage Obake.L("no_fbf_slices")
      return false
    out = {}
    for n, slice in ipairs slices
      LineOps.checkCancelled!
      source = templates[((n - 1) % #templates) + 1]
      line = sampleSlice source, slice, collection
      line.comment = false
      out[#out + 1] = line
    insertAt = indices[1]
    okApply, apply_error = pcall ->
      LineOps.transaction subs, "Obake - ZigZag lines", ->
        for index in *Obake.Selection.descending indices
          subs.delete index
        LineOps.insertLines subs, {{index: insertAt, lines: out}}
    unless okApply
      showMessage "ZigZag could not apply output atomically: #{apply_error}"
      return false
    Obake.Lines.resultSelection = [insertAt + n - 1 for n = 1, #out]
    showMessage "#{Obake.L('zigzag_created')} #{#out} line(s)."
    true

  stampMarker = (line, prefix, seq) ->
    line.effect = line.effect or ""
    cleaned = trim tostring(line.effect)\gsub("%[" .. prefix .. "%-%d+%]", "")\gsub("%s+", " ")
    marker = string.format "[%s-%03d]", prefix, tonumber(seq) or 1
    line.effect = if cleaned != "" then marker .. " " .. cleaned else marker

  markerCounter = 0
  nextMarker = ->
    markerCounter += 1
    markerCounter

  resetMarkers = ->
    markerCounter = 0

  lineLayer = (line) ->
    tonumber(line and line.layer) or 0

  Obake.OUTLINE_TAGS = {"outline", "outline_x", "outline_y"}
  Obake.SHADOW_TAGS = {"shadow", "shadow_x", "shadow_y"}

  Obake.layerOverrideBlock = (content) ->
    raw = trim tostring(content or "")
    first = raw\sub 1, 1
    first == "\\" or ((first == "*" or first == ">") and raw\sub(2, 2) == "\\")

  Obake.removeLayerTagsFromBlock = (block, removeSet) ->
    frameFor = (content, prefix = "", suffix = "", require_tag = false) ->
      {
        block: content
        tags: Obake.Tags.parseBlock content
        index: 1
        pos: 1
        out: {}
        prefix: prefix
        suffix: suffix
        require_tag: require_tag
      }

    stack = {frameFor block}
    while #stack > 0
      frame = stack[#stack]
      tag = frame.tags[frame.index]
      unless tag
        frame.out[#frame.out + 1] = frame.block\sub frame.pos
        cleaned = table.concat frame.out
        table.remove stack
        return cleaned if #stack == 0
        parent = stack[#stack]
        if not frame.require_tag or cleaned\find("\\", 1, true)
          parent.out[#parent.out + 1] = frame.prefix .. cleaned .. frame.suffix
        continue

      frame.out[#frame.out + 1] = frame.block\sub frame.pos, tag.start_pos - 1
      frame.pos = tag.end_pos + 1
      frame.index += 1
      canonical = tagNameAliases[tag.name] or tag.name
      continue if removeSet[canonical]

      raw = tag.raw
      if canonical == "transform"
        openPos = raw\find "(", 1, true
        if openPos and raw\sub(-1) == ")"
          inner = raw\sub openPos + 1, -2
          tagPos = inner\find "\\", 1, true
          if tagPos
            prefix = raw\sub(1, openPos) .. inner\sub(1, tagPos - 1)
            stack[#stack + 1] = frameFor inner\sub(tagPos), prefix, ")", true
            continue
      frame.out[#frame.out + 1] = raw
    ""

  Obake.removeLayerTags = (text, names) ->
    removeSet = {}
    removeSet[name] = true for name in *normalizeTagNames names
    text = tostring(text or "")
    out = {}
    pos = 1
    for block in *Obake.Tags.iterBlocks text
      out[#out + 1] = text\sub pos, block.open_pos - 1
      if Obake.layerOverrideBlock block.content
        cleaned = Obake.removeLayerTagsFromBlock block.content, removeSet
        out[#out + 1] = "{" .. cleaned .. "}" if trim(cleaned) != ""
      else
        out[#out + 1] = text\sub block.open_pos, block.close_pos
      pos = block.close_pos + 1
    out[#out + 1] = text\sub pos
    table.concat out

  Obake.appendLayerTags = (text, payload) ->
    return tostring(text or "") unless payload and payload != ""
    text = tostring(text or "")
    out = {}
    pos = 1
    hasInitialOverride = false
    for block in *Obake.Tags.iterBlocks text
      out[#out + 1] = text\sub pos, block.open_pos - 1
      if Obake.layerOverrideBlock block.content
        out[#out + 1] = "{" .. block.content .. payload .. "}"
        hasInitialOverride = true if block.open_pos == 1
      else
        out[#out + 1] = text\sub block.open_pos, block.close_pos
      pos = block.close_pos + 1
    out[#out + 1] = text\sub pos
    result = table.concat out
    result = "{" .. payload .. "}" .. result unless hasInitialOverride
    result

  Obake.rewriteLayerTags = (text, names, payload) ->
    Obake.appendLayerTags Obake.removeLayerTags(text, names), payload

  Obake.fillOnlyText = (text) ->
    names = {}
    names[#names + 1] = name for name in *Obake.OUTLINE_TAGS
    names[#names + 1] = name for name in *Obake.SHADOW_TAGS
    Obake.rewriteLayerTags text, names, tagText("outline", 0) .. tagText("shadow", 0)

  Obake.borderOnlyText = (text, outline = nil, color = nil, clearShadow = true) ->
    names = {"color1", "alpha1"}
    payload = tagText "alpha1", 255
    if outline != nil
      names[#names + 1] = name for name in *Obake.OUTLINE_TAGS
      payload ..= tagText "outline", outline
    if color != nil
      names[#names + 1] = "color3"
      payload ..= colorTagText "color3", color
    if clearShadow
      names[#names + 1] = name for name in *Obake.SHADOW_TAGS
      payload ..= tagText "shadow", 0
    Obake.rewriteLayerTags text, names, payload

  Obake.withoutShadowText = (text) ->
    Obake.rewriteLayerTags text, Obake.SHADOW_TAGS, tagText("shadow", 0)

  Obake.exactBlurText = (text, value) ->
    Obake.rewriteLayerTags text, "blur", tagText("blur", value)

  Obake.explicitOutlineSize = (text, fallback = 2) ->
    largest = nil
    for block in *Obake.Tags.iterBlocks text
      continue unless Obake.layerOverrideBlock block.content
      for tag in *Obake.Tags.parseBlock block.content
        if tag.name == "bord" or tag.name == "xbord" or tag.name == "ybord"
          value = tonumber trim tag.value
          if value and value >= 0
            largest = math.max largest or 0, value
    if largest != nil then largest else fallback

  makeBorderLayers = (line, cfg) ->
    baseLayer = lineLayer line
    layers = {
      {use: cfg.use_bord1, size: tonumber(cfg.bord1) or 0, color: cfg.color1}
      {use: cfg.use_bord2, size: tonumber(cfg.bord2) or 0, color: cfg.color2}
      {use: cfg.use_bord3, size: tonumber(cfg.bord3) or 0, color: cfg.color3}
      {use: cfg.use_bord4, size: tonumber(cfg.bord4) or 0, color: cfg.color4}
    }
    used = [layer for layer in *layers when layer.use]
    return nil if #used == 0
    mid = nextMarker!
    out = {}
    fill = cloneLine line
    fill.text = Obake.fillOnlyText fill.text
    fill.layer = baseLayer + #used
    stampMarker fill, "CAL", mid
    out[#out + 1] = fill
    accumulated = 0
    depth = #used - 1
    for layer in *used
      accumulated += tonumber(layer.size) or 0
      border = cloneLine line
      border.text = Obake.borderOnlyText border.text, accumulated, layer.color
      border.layer = baseLayer + depth
      depth -= 1
      stampMarker border, "CAL", mid
      out[#out + 1] = border
    table.sort out, (a, b) -> lineLayer(a) < lineLayer(b)
    out

  applyBorderLayers = (subs, sel, cfg) ->
    cfg or= DEFAULTS
    resetMarkers!
    plans = Obake.Lines.replacementPlans subs, sel, (line) -> makeBorderLayers line, cfg
    if #plans > 0
      okApply, apply_error = Obake.Lines.commitReplacements subs, plans, "Obake - Border layers"
      unless okApply
        showMessage "Border layers could not apply output atomically: #{apply_error}"
        return false
      return true
    showMessage Obake.L("no_border_layers")
    false

  Obake.StylePresets.handlers.decompose = (line, context) ->
    border = cloneLine line
    fill = cloneLine line
    border.text = Obake.borderOnlyText border.text, nil, nil, false
    border.layer = context.base
    stampMarker border, "CAL", context.marker
    fill.text = Obake.fillOnlyText fill.text
    fill.layer = context.base + 1
    stampMarker fill, "CAL", context.marker
    {border, fill}

  Obake.StylePresets.handlers.blurGlow = (line, context) ->
    glow = cloneLine line
    fill = cloneLine line
    glow.text = Obake.rewriteLayerTags glow.text, {"blur", "alpha"}, tagText("blur", 3) .. tagText("alpha", 128)
    glow.layer = context.base
    stampMarker glow, "CAL", context.marker
    fill.text = Obake.appendLayerTags fill.text, tagText("blur", 0.6) unless AssContext.firstTag fill.text, "blur"
    fill.layer = context.base + 1
    stampMarker fill, "CAL", context.marker
    {glow, fill}

  Obake.StylePresets.handlers.shadtrick = (line, context) ->
    shad = cloneLine line
    front = cloneLine line
    shad.text = Obake.rewriteLayerTags shad.text,
      {"color1", "color2", "color3", "alpha", "alpha1", "alpha2", "alpha3", "alpha4", "shadow", "shadow_x", "shadow_y"},
      tagText("alpha", 255) .. tagText("alpha4", 0) .. tagText("shadow_x", 0.001) .. tagText("shadow_y", 0)
    shad.layer = context.base
    stampMarker shad, "CAL", context.marker
    front.text = Obake.withoutShadowText front.text
    front.layer = context.base + 1
    stampMarker front, "CAL", context.marker
    {shad, front}

  Obake.StylePresets.handlers.doubleBorderBlur = (line, context) ->
    top = cloneLine line
    middle = cloneLine line
    bottom = cloneLine line
    bord = Obake.explicitOutlineSize line.text, context.outline
    top.text = Obake.fillOnlyText top.text
    top.layer = context.base + 2
    stampMarker top, "CAL", context.marker
    middle.text = Obake.exactBlurText Obake.borderOnlyText(middle.text), 0.4
    middle.layer = context.base + 1
    stampMarker middle, "CAL", context.marker
    bottom.text = Obake.exactBlurText Obake.borderOnlyText(bottom.text, bord * 2), 2
    bottom.layer = context.base
    stampMarker bottom, "CAL", context.marker
    {bottom, middle, top}

  Obake.StylePresets.handlers.cleanLayers = (line) ->
    clean = cloneLine line
    clean.text = removeAlphaTags clean.text
    clean.effect = trim tostring(clean.effect or "")\gsub("%[CAL%-%d+%]", "")\gsub("%s+", " ")
    clean.layer = 0
    {clean}

  presetLayers = (line, preset, styles) ->
    spec = Obake.StylePresets.by_name[preset]
    handler = spec and Obake.StylePresets.handlers[spec.handler]
    return nil unless handler
    style = styles and (styles[line.style] or styles.Default)
    handler line, {marker: nextMarker!, base: lineLayer(line), outline: finiteNumber(style and style.outline) or 2}

  applyColorPreset = (subs, sel, cfg) ->
    cfg or= DEFAULTS
    resetMarkers!
    styles = styleMap subs
    plans = Obake.Lines.replacementPlans subs, sel, (line) -> presetLayers line, cfg.cal_preset, styles
    if #plans > 0
      okApply, apply_error = Obake.Lines.commitReplacements subs, plans, "Obake - Color preset"
      unless okApply
        showMessage "Color preset could not apply output atomically: #{apply_error}"
        return false
      return true
    showMessage Obake.L("no_color_preset")
    false

  karaokeCue = (text) ->
    elapsed, seen = 0, 0
    text = tostring(text or "")
    for section in *LineOps.scanSections(text)
      if section.type == "override"
        duration = nil
        for call in *LineOps.tagCalls("{" .. section.text .. "}", {"k", "kf", "ko", "kt"})
          continue unless call.top_level
          value = finiteNumber call.value
          continue unless value and value >= 0
          if call.name == "kt"
            elapsed = value * 10
          else
            duration = math.floor(value * 10 + 0.5)
        if duration
          seen += 1
          if seen == 2
            return elapsed, stripKaraokeTags(text\sub(1, section.start - 1)), stripKaraokeTags(text\sub(section.start))
          elapsed += duration
    nil

  fxOffset = (line) ->
    offset = karaokeCue line.text
    dur = lineDuration line
    if offset and offset > 0 and offset < dur then offset, true else 0, false

  fxText = (line, usesKaraoke) ->
    if usesKaraoke then stripKaraokeTags(line.text) else line.text

  injectFx = (line, payload, strip) ->
    line.text = stripTransforms line.text if strip
    line.text = injectTransformFirst line.text, payload
    line

  fxFromIniFin = (ini, fin) ->
    (line, cfg) ->
      dur = lineDuration line
      return nil unless dur > 0
      offset, usesKaraoke = fxOffset line
      line.text = fxText line, usesKaraoke
      accel = if cfg.use_accel then cfg.accel else nil
      payload = ini .. transformTag(offset, dur, fin, accel)
      injectFx line, payload, cfg.strip_existing

  Obake.FX.handlers.blurIn = fxFromIniFin "\\blur8", "\\blur0"
  Obake.FX.handlers.blurOut = fxFromIniFin "\\blur0", "\\blur8"
  Obake.FX.handlers.fadeIn = fxFromIniFin "\\alpha&HFF&", "\\alpha&H00&"
  Obake.FX.handlers.fadeOut = fxFromIniFin "\\alpha&H00&", "\\alpha&HFF&"
  Obake.FX.handlers.scaleUp = fxFromIniFin "\\fscx100\\fscy100", "\\fscx115\\fscy115"
  Obake.FX.handlers.scaleDown = fxFromIniFin "\\fscx115\\fscy115", "\\fscx100\\fscy100"
  Obake.FX.handlers.popIn = fxFromIniFin "\\fscx40\\fscy40\\alpha&HFF&", "\\fscx100\\fscy100\\alpha&H00&"
  Obake.FX.handlers.popOut = fxFromIniFin "\\fscx100\\fscy100\\alpha&H00&", "\\fscx40\\fscy40\\alpha&HFF&"
  Obake.FX.handlers.borderPulse = fxFromIniFin "\\bord2", "\\bord6"
  Obake.FX.handlers.glowPulse = fxFromIniFin "\\blur1\\bord2", "\\blur8\\bord4"

  applyColorFlash = (line, cfg) ->
    dur = lineDuration line
    return nil unless dur > 0
    offset, usesKaraoke = fxOffset line
    line.text = fxText line, usesKaraoke
    c1 = colorNorm cfg.fx_color or "&HFFFFFF&"
    c2 = colorNorm cfg.fx_color2 or "&H0000FF&"
    mid = offset + math.floor((dur - offset) * 0.3)
    payload = "\\c" .. c1 .. transformTag(offset, mid, "\\c" .. c2) .. transformTag(mid, dur, "\\c" .. c1)
    injectFx line, payload, cfg.strip_existing

  applyColorPulseFx = (line, cfg) ->
    dur = lineDuration line
    return nil unless dur > 0
    offset, usesKaraoke = fxOffset line
    line.text = fxText line, usesKaraoke
    c1 = colorNorm cfg.fx_color or "&HFFFFFF&"
    c2 = colorNorm cfg.fx_color2 or "&H00CCFF&"
    step = math.max 1, math.floor(finiteNumber(cfg.fx_step_ms) or 250)
    payload = {"\\c" .. c1}
    t, toFin = offset, true
    while t < dur
      LineOps.checkCancelled!
      t2 = math.min t + step, dur
      payload[#payload + 1] = transformTag t, t2, "\\c" .. (if toFin then c2 else c1)
      t = t2
      toFin = not toFin
    injectFx line, table.concat(payload), cfg.strip_existing

  applyToColorFrame = (line, cfg) ->
    dur = lineDuration line
    return nil unless dur > 0
    offset, usesKaraoke = fxOffset line
    unless usesKaraoke
      fms, err = currentFrameMs!
      return nil, err unless fms
      return nil, "Frame is outside the line." if fms < line.start_time or fms >= line.end_time
      offset = fms - line.start_time
    line.text = fxText line, usesKaraoke
    color = colorNorm cfg.fx_color or "&HFFCC00&"
    injectFx line, transformTag(offset, dur, "\\c" .. color .. "\\3c" .. color .. "\\4c" .. color), cfg.strip_existing

  applyToStyleFrame = (line, cfg, styles) ->
    dur = lineDuration line
    return nil unless dur > 0
    offset, usesKaraoke = fxOffset line
    unless usesKaraoke
      fms, err = currentFrameMs!
      return nil, err unless fms
      return nil, "Frame is outside the line." if fms < line.start_time or fms >= line.end_time
      offset = fms - line.start_time
    style = styles[line.style] or styles.Default
    return nil, "Style not found." unless style
    line.text = fxText line, usesKaraoke
    color = colorNorm cfg.fx_color or "&HFFCC00&"
    sc1 = colorFromStyle style.color1
    sc3 = colorFromStyle style.color3
    sc4 = colorFromStyle style.color4
    init = "\\c" .. color .. "\\3c" .. color .. "\\4c" .. color
    injectFx line, init .. transformTag(0, offset, "\\c" .. sc1 .. "\\3c" .. sc3 .. "\\4c" .. sc4), cfg.strip_existing

  effectPosition = (line, subs) ->
    x, y, err = AssContext.position line, {sub: subs}
    error err, 0 unless x and y
    x, y

  applyShake = (line, cfg, axis, subs) ->
    dur = lineDuration line
    return nil unless dur > 0
    offset, usesKaraoke = fxOffset line
    line.text = fxText line, usesKaraoke
    px, py = effectPosition line, subs
    line.text = removeSimpleTag line.text, "org"
    distance = CONSTANTS.SHAKE_ORIGIN_DISTANCE
    orgX, orgY = math.floor(px), math.floor(py)
    orgX -= distance if axis == "V" or axis == "XY"
    orgY -= distance if axis == "H" or axis == "XY"
    step = math.max 1, math.floor(finiteNumber(cfg.fx_step_ms) or 50)
    amount = finiteNumber(cfg.fx_amount) or 0.12
    payload = {string.format "\\org(%d,%d)", orgX, orgY}
    t, dir = offset, 1
    while t < dur
      LineOps.checkCancelled!
      t2 = math.min t + step, dur
      payload[#payload + 1] = transformTag t, t2, string.format("\\frz%.3f", amount * dir)
      t = t2
      dir = -dir
    injectFx line, table.concat(payload), cfg.strip_existing

  applyWobble = (line, cfg) ->
    dur = lineDuration line
    return nil unless dur > 0
    offset, usesKaraoke = fxOffset line
    line.text = fxText line, usesKaraoke
    step = math.max 1, math.floor(finiteNumber(cfg.fx_step_ms) or 120)
    amount = finiteNumber(cfg.fx_amount) or 4.0
    payload, t, dir = {}, offset, 1
    while t < dur
      LineOps.checkCancelled!
      t2 = math.min t + step, dur
      payload[#payload + 1] = transformTag t, t2, string.format("\\frz%.2f", amount * dir)
      t = t2
      dir = -dir
    injectFx line, table.concat(payload), cfg.strip_existing

  applyGlitch = (line, cfg, random) ->
    dur = lineDuration line
    return nil unless dur > 0
    offset, usesKaraoke = fxOffset line
    line.text = fxText line, usesKaraoke
    step = math.max 1, math.floor(finiteNumber(cfg.fx_step_ms) or 60)
    amount = finiteNumber(cfg.fx_amount) or 6.0
    random or= makeRandom!
    payload, t = {}, offset
    while t < dur
      LineOps.checkCancelled!
      t2 = math.min t + step, dur
      fax = (random! - 0.5) * amount * 0.05
      fsp = math.floor((random! - 0.5) * amount)
      payload[#payload + 1] = transformTag t, t2, string.format("\\fax%.3f\\fsp%d", fax, fsp)
      t = t2
    injectFx line, table.concat(payload), cfg.strip_existing

  dramaticPulseLines = (line, cfg) ->
    dur = lineDuration line
    return nil unless dur > 0
    offset, usesKaraoke = fxOffset line
    base = fxText line, usesKaraoke
    pulseEnd = math.min dur, offset + math.max(120, math.floor(tonumber(cfg.fx_step_ms) or 220))
    settleEnd = math.min dur, offset + math.max(180, math.floor((tonumber(cfg.fx_step_ms) or 220) * 1.8))
    color = colorNorm cfg.fx_color or "&HFFFFFF&"
    glow = cloneLine line
    top = cloneLine line
    glow.layer = lineLayer line
    top.layer = lineLayer(line) + 1
    glow.text = base
    top.text = base
    glowTags = "\\c" .. color .. "\\3c" .. color .. "\\blur2\\bord3\\alpha&H20&" .. transformTag(offset, pulseEnd, "\\fscx170\\fscy170\\blur9\\bord8\\alpha&HFF&")
    topTags = "\\alpha&H00&" .. transformTag(offset, pulseEnd, "\\fscx122\\fscy122") .. transformTag(pulseEnd, settleEnd, "\\fscx100\\fscy100")
    {injectFx(glow, glowTags, cfg.strip_existing), injectFx(top, topTags, cfg.strip_existing)}

  retimeSlice = AssContext.retimeSlice

  splitLineLines = (line, mode) ->
    kOffset, kBefore, kAfter = karaokeCue line.text
    fms = nil
    unless kOffset
      fms = currentFrameMs!
      return nil unless fms and fms > line.start_time and fms < line.end_time
    splitTime = if kOffset then line.start_time + kOffset else fms
    return nil unless splitTime > line.start_time and splitTime < line.end_time
    head = firstBlock line.text
    body = line.text\sub(#head + 1)
    before, after = body\match "^(.-)%|(.*)$"
    if kOffset
      head, before, after = "", kBefore, kAfter
    return nil unless before and after
    l1 = cloneLine line
    l2 = cloneLine line
    if mode == "Split Line"
      l1.end_time = splitTime
      l1.text = head .. before .. "{\\alpha&HFF&}" .. after
      l2.start_time = splitTime
      l2.text = head .. before .. after
      retimeSlice l1, line
      retimeSlice l2, line
    else
      l1.text = head .. before .. "{\\alpha&HFF&}" .. after
      l2.layer = lineLayer(line) + 1
      l2.start_time = splitTime
      fad = "\\fad(#{CONSTANTS.SPLIT_FADE_IN_MS},0)\\alpha&HFF&"
      if head != ""
        l2.text = head\gsub("^{", "{" .. fad, 1) .. before .. "{\\alpha&H00&}" .. after
      else
        l2.text = "{" .. fad .. "}" .. before .. "{\\alpha&H00&}" .. after
      l2.text = LineOps.removeTagCalls l2.text, {"fad", "fade"}, {top_level_only: true}
      retimeSlice l2, line
      l2.text = injectFirst l2.text, "\\fad(#{CONSTANTS.SPLIT_FADE_IN_MS},0)"
    {l1, l2}

  splitTitleLines = (line) ->
    head = firstBlock line.text
    body = line.text\sub(#head + 1)
    l1 = cloneLine line
    l2 = cloneLine line
    l1.layer = lineLayer line
    l2.layer = lineLayer(line) + 1
    if head != ""
      l1.text = head\gsub("^{", "{\\1a&HFF&", 1) .. body
      l2.text = head\gsub("^{", "{\\bord0", 1) .. body
    else
      l1.text = "{\\1a&HFF&}" .. body
      l2.text = "{\\bord0}" .. body
    {l1, l2}

  Obake.FX.handlers.colorFlash = applyColorFlash
  Obake.FX.handlers.colorPulse = applyColorPulseFx
  Obake.FX.handlers.toColorFrame = applyToColorFrame
  Obake.FX.handlers.toStyleFrame = (line, cfg, context) -> applyToStyleFrame line, cfg, context.styles
  Obake.FX.handlers.shakeV = (line, cfg, context) -> applyShake line, cfg, "V", context.subs
  Obake.FX.handlers.shakeH = (line, cfg, context) -> applyShake line, cfg, "H", context.subs
  Obake.FX.handlers.shakeXy = (line, cfg, context) -> applyShake line, cfg, "XY", context.subs
  Obake.FX.handlers.wobble = applyWobble
  Obake.FX.handlers.glitch = (line, cfg, context) -> applyGlitch line, cfg, context.random
  Obake.FX.handlers.dramaticPulse = dramaticPulseLines
  Obake.FX.handlers.flashback = (line) ->
    line.text = injectFirst line.text, "\\fad(200,200)"
    line
  Obake.FX.handlers.splitLine = (line) -> splitLineLines line, "Split Line"
  Obake.FX.handlers.splitLineFad = (line) -> splitLineLines line, "Split Line Fad"
  Obake.FX.handlers.splitTitle = splitTitleLines

  applyFx = (subs, sel, cfg) ->
    cfg or= DEFAULTS
    presetName = cfg.fx_preset
    spec = Obake.FX.by_name[presetName]
    handler = spec and Obake.FX.handlers[spec.handler]
    unless spec and handler
      showMessage Obake.L("no_fx_preset")
      return false
    context = {subs: subs}
    context.styles = styleMap subs if spec.needs_styles
    context.random = makeRandom! if spec.needs_random
    undoName = "Obake - Animation FX " .. presetName
    if spec.output == "lines"
      plans, errors = Obake.Lines.replacementPlans subs, sel, (source) ->
        handler cloneLine(source), cfg, context
      if #errors > 0
        showMessage table.concat errors, "\n"
        return false
      if #plans > 0
        okApply, apply_error = Obake.Lines.commitReplacements subs, plans, undoName
        unless okApply
          showMessage "Animation FX could not apply output atomically: #{apply_error}"
          return false
        return true
      showMessage Obake.L("no_lines_changed")
      return false
    updates, errors = {}, {}
    for i in *Obake.Selection.dialogueIndices subs, sel
      LineOps.checkCancelled!
      out, err = handler cloneLine(subs[i]), cfg, context
      if out
        updates[#updates + 1] = {index: i, line: out}
      elseif err
        errors[#errors + 1] = "#{Obake.L('line')} #{i}: #{err}"
    if #errors > 0
      showMessage table.concat errors, "\n"
      return false
    if #updates > 0
      okApply, apply_error = Obake.Lines.commitUpdates subs, updates, undoName
      unless okApply
        showMessage "Animation FX could not apply changes atomically: #{apply_error}"
        return false
      return true
    showMessage Obake.L("no_lines_changed")
    false

  applyRetime = (subs, sel, cfg) ->
    cfg or= {}
    updates = {}
    report = {}
    for i in *Obake.Selection.dialogueIndices subs, sel
      LineOps.checkCancelled!
      line = cloneLine subs[i]
      target = tonumber(cfg.retime_target) or 0
      target = lineDuration line if target <= 0
      continue if target <= 0
      source = tonumber(cfg.retime_source) or 0
      source = maxTransformEnd(line.text) if source <= 0
      if source > 0 and target >= 0
        newText, tags_changed = retimeTransformText line.text, source, target
        if tags_changed > 0 and newText != line.text
          line.text = newText
          updates[#updates + 1] = {index: i, line: line}
          report[#report + 1] = "#{Obake.L('line')} #{i}: #{formatMilliseconds(source)} -> #{formatMilliseconds(target)} ms, #{tags_changed} #{Obake.L('transform_s')}"
    if #updates > 0
      okApply, apply_error = Obake.Lines.commitUpdates subs, updates, "Obake - Retime transforms"
      unless okApply
        showMessage "Retime transforms could not apply changes atomically: #{apply_error}"
        return false
      showMessage table.concat(report, "\n") if cfg.retime_info
      return true
    showMessage Obake.L("no_t_ret")
    false

  Obake.Operations["Apply chain"] = {run: applyChain, options: -> showChainOptions!}
  Obake.Operations["Animation FX"] = {run: applyFx, options: -> showFxOptions!}
  Obake.Operations["Color preset"] = {run: applyColorPreset, options: -> showPresetOptions!}
  Obake.Operations["Border layers"] = {run: applyBorderLayers, options: -> showBorderOptions!}
  Obake.Operations["Retime transforms"] = {run: applyRetime, direct: true}
  Obake.Operations["In-Out tags"] = {run: applyInOutTags, direct: true}
  Obake.Operations["Gunfight of Tags"] = {run: applyGunfightOfTags, options: (subs, sel) -> showGunfightOptions subs, sel}
  Obake.Operations["ZigZag lines"] = {run: applyZigzagLines, options: -> showZigzagOptions!}

  Obake.dispatch = (subs, sel, active, operation, opts) ->
    Obake.Lines.resultSelection = nil
    spec = Obake.Operations[operation]
    if spec and spec.run then spec.run subs, sel, opts else false

  Obake.runOperation = (subs, sel, active, operation) ->
    opts = Obake.showActionOptions operation, subs, sel, active
    return unless opts
    opts.operation = operation
    ok = Obake.dispatch subs, sel, active, operation, opts
    LineOps.checkCancelled!
    aegisub.cancel! unless ok
    result = Obake.Lines.resultSelection or Obake.Selection.dialogueIndices(subs, sel)
    result, result[1] or active

  Obake.main = (subs, sel, active) ->
    while true
      operation = Obake.actionPicker!
      return unless operation
      result, current = Obake.runOperation subs, sel, active, operation
      return result, current if result != nil

  Obake.validate = (subs, sel) ->
    return false unless sel and #sel > 0
    records = Obake.Selection.dialogueRecords subs, sel, true
    records != nil and #records == #sel

  Obake.validateAny = ->
    true

  Obake.validateInOut = (subs, sel) ->
    return false unless Obake.validate subs, sel
    pairs = Obake.collectInOutPairs subs, sel
    pairs != nil

  Obake.validateZigzag = (subs, sel) ->
    Obake.validate(subs, sel) and #sel >= 2

  Obake.validateAction = (operation) ->
    if operation == "In-Out tags"
      Obake.validateInOut
    elseif operation == "ZigZag lines"
      Obake.validateZigzag
    else
      Obake.validate

  Obake.actionMacro = (operation) ->
    (subs, sel, active) ->
      Obake.runOperation subs, sel, active, operation

  Obake.hotkeyMenuPath = (operation) ->
    CONSTANTS.HOTKEY_MENU_ROOT .. "/" .. CONSTANTS.HOTKEY_MENU_SCRIPT .. "/" .. (operationLabels.en[operation] or operation)

  Obake.helpMacro = ->
    Obake.actionHelpPicker!

  Obake.Foundation.clone_line = Obake.Foundation.cloneLine
  Obake.Foundation.is_dialogue = Obake.Foundation.isDialogue
  Obake.Foundation.finite = Obake.Foundation.finiteNumber
  Obake.Foundation.format_num = Obake.Foundation.formatNumber
  Obake.Foundation.format_ms = Obake.Foundation.formatMilliseconds
  Obake.Foundation.style_map = Obake.Foundation.styleMap
  Obake.Foundation.line_duration = Obake.Foundation.lineDuration
  Obake.Foundation.current_frame_ms = Obake.Foundation.currentFrameMs
  Obake.Foundation.frame_slices = Obake.Foundation.frameSlices

  Obake.Tags.iter_blocks = Obake.Tags.iterBlocks
  Obake.Tags.parse_block = Obake.Tags.parseBlock
  Obake.Tags.clip_is_vector = Obake.Tags.clipIsVector

  Obake.Selection.dialogue_indices = Obake.Selection.dialogueIndices
  Obake.Selection.dialogue_records = Obake.Selection.dialogueRecords

  Obake.Lines.replace_one_with_many = Obake.Lines.replaceOneWithMany
  Obake.Lines.commit_updates = Obake.Lines.commitUpdates
  Obake.Lines.commit_replacements = Obake.Lines.commitReplacements
  Obake.Lines.replacement_plans = Obake.Lines.replacementPlans

  Obake.preset_spec = Obake.presetSpec
  Obake.choice_label = Obake.choiceLabel
  Obake.choice_raw = Obake.choiceRaw
  Obake.localized_items = Obake.localizedItems
  Obake.valid_language = Obake.validLanguage
  Obake.config_interface = Obake.configInterface
  Obake.language_config = Obake.languageConfig
  Obake.load_language = Obake.loadLanguage
  Obake.save_language = Obake.saveLanguage
  Obake.toggle_language = Obake.toggleLanguage
  Obake.operation_label = Obake.operationLabel
  Obake.action_help = Obake.actionHelp
  Obake.normalize_operation = Obake.normalizeOperation
  Obake.dropdown_data = Obake.dropdownData
  Obake.shown_choice = Obake.shownChoice
  Obake.raw_choice = Obake.rawChoice
  Obake.raw_operation_choice = Obake.rawOperationChoice
  Obake.collect_in_out_pairs = Obake.collectInOutPairs
  Obake.build_in_out_pair = Obake.buildInOutPair
  Obake.picker_help_text = Obake.pickerHelpText
  Obake.action_picker_gui = Obake.actionPickerGui
  Obake.action_picker = Obake.actionPicker
  Obake.action_help_picker = Obake.actionHelpPicker
  Obake.show_action_options = Obake.showActionOptions
  Obake.layer_override_block = Obake.layerOverrideBlock
  Obake.remove_layer_tags_from_block = Obake.removeLayerTagsFromBlock
  Obake.remove_layer_tags = Obake.removeLayerTags
  Obake.append_layer_tags = Obake.appendLayerTags
  Obake.rewrite_layer_tags = Obake.rewriteLayerTags
  Obake.fill_only_text = Obake.fillOnlyText
  Obake.border_only_text = Obake.borderOnlyText
  Obake.without_shadow_text = Obake.withoutShadowText
  Obake.exact_blur_text = Obake.exactBlurText
  Obake.explicit_outline_size = Obake.explicitOutlineSize
  Obake.run_operation = Obake.runOperation
  Obake.validate_any = Obake.validateAny
  Obake.validate_in_out = Obake.validateInOut
  Obake.validate_zigzag = Obake.validateZigzag
  Obake.validate_action = Obake.validateAction
  Obake.action_macro = Obake.actionMacro
  Obake.hotkey_menu_path = Obake.hotkeyMenuPath
  Obake.help_macro = Obake.helpMacro

  Obake.StylePresets.handlers.blur_glow = Obake.StylePresets.handlers.blurGlow
  Obake.StylePresets.handlers.double_border_blur = Obake.StylePresets.handlers.doubleBorderBlur
  Obake.StylePresets.handlers.clean_layers = Obake.StylePresets.handlers.cleanLayers

  Obake.FX.handlers.blur_in = Obake.FX.handlers.blurIn
  Obake.FX.handlers.blur_out = Obake.FX.handlers.blurOut
  Obake.FX.handlers.fade_in = Obake.FX.handlers.fadeIn
  Obake.FX.handlers.fade_out = Obake.FX.handlers.fadeOut
  Obake.FX.handlers.scale_up = Obake.FX.handlers.scaleUp
  Obake.FX.handlers.scale_down = Obake.FX.handlers.scaleDown
  Obake.FX.handlers.pop_in = Obake.FX.handlers.popIn
  Obake.FX.handlers.pop_out = Obake.FX.handlers.popOut
  Obake.FX.handlers.color_flash = Obake.FX.handlers.colorFlash
  Obake.FX.handlers.color_pulse = Obake.FX.handlers.colorPulse
  Obake.FX.handlers.to_color_frame = Obake.FX.handlers.toColorFrame
  Obake.FX.handlers.to_style_frame = Obake.FX.handlers.toStyleFrame
  Obake.FX.handlers.border_pulse = Obake.FX.handlers.borderPulse
  Obake.FX.handlers.glow_pulse = Obake.FX.handlers.glowPulse
  Obake.FX.handlers.shake_v = Obake.FX.handlers.shakeV
  Obake.FX.handlers.shake_h = Obake.FX.handlers.shakeH
  Obake.FX.handlers.shake_xy = Obake.FX.handlers.shakeXy
  Obake.FX.handlers.dramatic_pulse = Obake.FX.handlers.dramaticPulse
  Obake.FX.handlers.split_line = Obake.FX.handlers.splitLine
  Obake.FX.handlers.split_line_fad = Obake.FX.handlers.splitLineFad
  Obake.FX.handlers.split_title = Obake.FX.handlers.splitTitle
)!

registerMacro = (name, description, process, validate) ->
  depctrl\registerMacro name, description, process, validate, nil, false

registerMacro "Obake", script_description, Obake.main, Obake.validate
registerMacro "Obake/Help", "Show the Obake action help.", Obake.helpMacro, Obake.validateAny
for operation in *OPERATIONS
  registerMacro Obake.hotkeyMenuPath(operation), Obake.actionHelp(operation), Obake.actionMacro(operation), Obake.validateAction(operation)

require("kite.UI").publishActions()
