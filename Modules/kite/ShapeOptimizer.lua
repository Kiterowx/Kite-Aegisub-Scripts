local MODULE_VERSION = "1.0.2"
local ShapeOptimizer = { VERSION = MODULE_VERSION, version = MODULE_VERSION }

local function safeRequire(name)
  local ok, value = pcall(require, name)
  if ok then return value end
  return nil
end

local DependencyControl = safeRequire("l0.DependencyControl")
local KiteUI = safeRequire("kite.UI")
local LineOps = safeRequire("kite.LineOps")
local depctrl
if DependencyControl then
  depctrl = DependencyControl({
    name = "kite.ShapeOptimizer",
    version = MODULE_VERSION,
    description = "Shared ASS vector-shape color and gradient optimizer for Kite macros",
    author = "Kiterow",
    url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
    moduleName = "kite.ShapeOptimizer",
    feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    {
      { "kite.LineOps", version = "1.5.2" },
      { "kite.UI", version = "1.1.3" },
    },
  })
end

if not KiteUI then error("kite.UI is required", 0) end
if not LineOps then error("kite.LineOps is required", 0) end

local LANG = {
  en = {
    title = "Shape Color Optimizer",
    mode = "Mode",
    intensity = "Intensity",
    threshold = "OKLab threshold (0 = intensity)",
    max_bands = "Max. bands",
    show_summary = "Show summary before applying",
    mode_auto = "Auto",
    mode_similar = "Similar colors",
    mode_gradient = "Full gradient",
    intensity_balanced = "Balanced",
    intensity_fidelity = "Fidelity",
    intensity_aggressive = "Aggressive",
    execute = "Execute",
    cancel = "Cancel",
    ok = "OK",
    summary_mode = "Mode: %s",
    summary_detail = "Detail: %s",
    summary_lines = "Lines: %d -> %d",
    summary_colors = "Colors: %d -> %d",
    summary_characters = "Characters: %d -> %d",
    detail_threshold = "OKLab threshold %.3f",
    detail_gradient = "%s, average error %.3f",
    detail_fallback = " (fallback: %s)",
    axis_horizontal = "horizontal",
    axis_vertical = "vertical",
    no_gradient = "No reliable gradient was detected.",
    gradient_within_target = "The gradient already has no more bands than the target.",
    err_two_shapes = "Select at least two ASS vector shape lines.",
    err_no_coordinates = "The drawing has no coordinates.",
    err_odd_coordinates = "The drawing has an odd coordinate count.",
    err_simple_shape = "The line must contain one simple ASS vector shape and one leading tag block.",
    err_transform = "Animated transforms are not supported.",
    err_move = "\\move is not supported.",
    err_clip = "Clips are not supported.",
    err_alpha_tags = "Per-channel alpha tags are not supported.",
    err_alpha = "\\alpha is not supported.",
    err_extra_tags = "Extra override blocks inside the drawing are not supported.",
    err_empty_path = "The drawing path is empty.",
    err_unsupported_tags = "Unsupported tag block content: %s",
    err_missing_p = "The \\p scale is missing.",
    err_unsupported_p = "That \\p scale is not supported.",
    err_missing_pos = "The \\pos tag is missing.",
    err_invalid_pos = "The \\pos tag is invalid.",
    err_missing_color = "The \\c or \\1c color is missing.",
    err_invalid_color = "The color is invalid.",
    err_contiguous = "The selection must be contiguous for direct replacement.",
    err_not_dialogue = "Selected row %d is not a dialogue line.",
    err_line = "Line %d: %s",
    err_mixed = "The selection mixes timing, style, layer, margins, or visual tags.",
    err_no_output = "The shape optimizer produced no output.",
    no_reduction = "No safe reduction was found with these parameters.",
    confirm_apply = "Apply direct replacement?"
  },
  es = {
    title = "Optimizador de color en shapes",
    mode = "Modo",
    intensity = "Intensidad",
    threshold = "Umbral OKLab (0 = intensidad)",
    max_bands = "Bandas máximas",
    show_summary = "Mostrar resumen antes de aplicar",
    mode_auto = "Auto",
    mode_similar = "Colores similares",
    mode_gradient = "Gradiente completo",
    intensity_balanced = "Equilibrado",
    intensity_fidelity = "Fidelidad",
    intensity_aggressive = "Agresivo",
    execute = "Ejecutar",
    cancel = "Cancelar",
    ok = "Aceptar",
    summary_mode = "Modo: %s",
    summary_detail = "Detalle: %s",
    summary_lines = "Líneas: %d -> %d",
    summary_colors = "Colores: %d -> %d",
    summary_characters = "Caracteres: %d -> %d",
    detail_threshold = "umbral OKLab %.3f",
    detail_gradient = "%s, error medio %.3f",
    detail_fallback = " (alternativa: %s)",
    axis_horizontal = "horizontal",
    axis_vertical = "vertical",
    no_gradient = "No se detectó un gradiente fiable.",
    gradient_within_target = "El gradiente ya tiene como máximo la cantidad de bandas indicada.",
    err_two_shapes = "Selecciona al menos dos líneas de shapes vectoriales ASS.",
    err_no_coordinates = "El dibujo no contiene coordenadas.",
    err_odd_coordinates = "El dibujo contiene una cantidad impar de coordenadas.",
    err_simple_shape = "La línea debe contener un shape vectorial ASS simple y un único bloque inicial de tags.",
    err_transform = "No se admiten transformaciones animadas.",
    err_move = "No se admite \\move.",
    err_clip = "No se admiten clips.",
    err_alpha_tags = "No se admiten tags de alfa por canal.",
    err_alpha = "No se admite \\alpha.",
    err_extra_tags = "No se admiten bloques de tags adicionales dentro del dibujo.",
    err_empty_path = "El trazado del dibujo está vacío.",
    err_unsupported_tags = "Contenido no admitido en el bloque de tags: %s",
    err_missing_p = "Falta la escala \\p.",
    err_unsupported_p = "Esa escala \\p no está admitida.",
    err_missing_pos = "Falta el tag \\pos.",
    err_invalid_pos = "El tag \\pos no es válido.",
    err_missing_color = "Falta el color \\c o \\1c.",
    err_invalid_color = "El color no es válido.",
    err_contiguous = "La selección debe ser contigua para el reemplazo directo.",
    err_not_dialogue = "La fila seleccionada %d no es una línea de diálogo.",
    err_line = "Línea %d: %s",
    err_mixed = "La selección mezcla tiempos, estilos, capas, márgenes o tags visuales.",
    err_no_output = "El optimizador de shapes no produjo ningún resultado.",
    no_reduction = "No se encontró una reducción segura con estos parámetros.",
    confirm_apply = "¿Aplicar el reemplazo directo?"
  },
  pt = {
    title = "Otimizador de cor em formas",
    mode = "Modo",
    intensity = "Intensidade",
    threshold = "Limiar OKLab (0 = intensidade)",
    max_bands = "Máx. de faixas",
    show_summary = "Mostrar resumo antes de aplicar",
    mode_auto = "Auto",
    mode_similar = "Cores semelhantes",
    mode_gradient = "Gradiente completo",
    intensity_balanced = "Equilibrado",
    intensity_fidelity = "Fidelidade",
    intensity_aggressive = "Agressivo",
    execute = "Executar",
    cancel = "Cancelar",
    ok = "OK",
    summary_mode = "Modo: %s",
    summary_detail = "Detalhe: %s",
    summary_lines = "Linhas: %d -> %d",
    summary_colors = "Cores: %d -> %d",
    summary_characters = "Caracteres: %d -> %d",
    detail_threshold = "limiar OKLab %.3f",
    detail_gradient = "%s, erro médio %.3f",
    detail_fallback = " (alternativa: %s)",
    axis_horizontal = "horizontal",
    axis_vertical = "vertical",
    no_gradient = "Nenhum gradiente confiável foi detectado.",
    gradient_within_target = "O gradiente já não ultrapassa a quantidade de faixas definida.",
    err_two_shapes = "Selecione ao menos duas linhas de formas vetoriais ASS.",
    err_no_coordinates = "O desenho não contém coordenadas.",
    err_odd_coordinates = "O desenho contém uma quantidade ímpar de coordenadas.",
    err_simple_shape = "A linha deve conter uma forma vetorial ASS simples e um único bloco inicial de etiquetas.",
    err_transform = "Transformações animadas não são compatíveis.",
    err_move = "\\move não é compatível.",
    err_clip = "Clipes não são compatíveis.",
    err_alpha_tags = "Etiquetas de alfa por canal não são compatíveis.",
    err_alpha = "\\alpha não é compatível.",
    err_extra_tags = "Blocos de etiquetas adicionais dentro do desenho não são compatíveis.",
    err_empty_path = "O traçado do desenho está vazio.",
    err_unsupported_tags = "Conteúdo incompatível no bloco de etiquetas: %s",
    err_missing_p = "A escala \\p está ausente.",
    err_unsupported_p = "Essa escala \\p não é compatível.",
    err_missing_pos = "A etiqueta \\pos está ausente.",
    err_invalid_pos = "A etiqueta \\pos é inválida.",
    err_missing_color = "A cor \\c ou \\1c está ausente.",
    err_invalid_color = "A cor é inválida.",
    err_contiguous = "A seleção deve ser contígua para a substituição direta.",
    err_not_dialogue = "A linha selecionada %d não é uma fala.",
    err_line = "Linha %d: %s",
    err_mixed = "A seleção combina tempos, estilos, camadas, margens ou etiquetas visuais diferentes.",
    err_no_output = "O otimizador de formas não produziu nenhum resultado.",
    no_reduction = "Nenhuma redução segura foi encontrada com estes parâmetros.",
    confirm_apply = "Aplicar a substituição direta?"
  }
}
local current_lang = "en"
local current_title
local L
L = function(key, ...)
  local text = (LANG[current_lang] and LANG[current_lang][key]) or LANG.en[key] or key
  if select("#", ...) == 0 then
    return text
  end
  return string.format(text, ...)
end
local MODES = {
  "Auto",
  "Similar colors",
  "Full gradient"
}
local INTENSITIES = {
  "Balanced",
  "Fidelity",
  "Aggressive"
}
local MODE_KEYS = {
  Auto = "mode_auto",
  ["Similar colors"] = "mode_similar",
  ["Full gradient"] = "mode_gradient"
}
local INTENSITY_KEYS = {
  Balanced = "intensity_balanced",
  Fidelity = "intensity_fidelity",
  Aggressive = "intensity_aggressive"
}
local EPSILON = 0.000001
local FORMAT_DECIMALS = 3
local FORMAT_ROUND_EPSILON = 0.5 * 10 ^ -FORMAT_DECIMALS
local MAX_DRAWING_SCALE = 6
local MIN_THRESHOLD, MAX_THRESHOLD = 0.005, 0.25
local MIN_BANDS, MAX_BANDS = 2, 64
local DEFAULT_MAX_BANDS = 8
local MIN_GRADIENT_ITEMS = 4
local MIN_GRADIENT_ENDPOINT_DELTA = 0.03
local MIN_GRADIENT_AVERAGE_LIMIT, MIN_GRADIENT_MAX_LIMIT = 0.075, 0.180
local GRADIENT_AVERAGE_FACTOR, GRADIENT_MAX_FACTOR = 1.6, 3.0
local PROFILE_THRESHOLDS = { Fidelity = 0.035, Balanced = 0.065, Aggressive = 0.100 }
local settingsCache = {}
local settingsDefaults = {
  main = {
    mode = "Auto",
    intensity = "Balanced",
    threshold = 0,
    max_bands = DEFAULT_MAX_BANDS,
    show_summary = false
  }
}

local function settingsFor(context)
  context = context or {}
  local namespace = context.settings_namespace or "kite.ShapeOptimizer"
  local version = context.settings_version or ShapeOptimizer.VERSION
  local key = namespace .. "\31" .. version
  if not settingsCache[key] then
    settingsCache[key] = KiteUI.settings(namespace, version, settingsDefaults, {})
  end
  return settingsCache[key]
end

local copy_line
copy_line = function(line)
  if LineOps and LineOps.deepCopy then
    return LineOps.deepCopy(line)
  end
  local out = { }
  for k, v in pairs(line) do
    out[k] = v
  end
  return out
end
local clamp
clamp = function(value, low, high)
  value = tonumber(value) or 0
  return math.max(low, math.min(high, value))
end
local finite_number
finite_number = function(value)
  local number = tonumber(value)
  if not number or number ~= number or math.abs(number) == math.huge then return nil end
  return number
end
local format_number
format_number = function(value)
  value = tonumber(value) or 0
  if math.abs(value) < FORMAT_ROUND_EPSILON then
    value = 0
  end
  local nearest = math.floor(value + 0.5)
  if math.abs(value - nearest) < FORMAT_ROUND_EPSILON then
    return tostring(nearest)
  end
  local text = ("%." .. tostring(FORMAT_DECIMALS) .. "f"):format(value)
  text = text:gsub("0+$", "")
  text = text:gsub("%.$", "")
  return text
end
local show_message
show_message = function(message)
  return aegisub.dialog.display({
    {
      class = "textbox",
      value = tostring(message or ""),
      x = 0,
      y = 0,
      width = 56,
      height = 10
    }
  }, {
    L("ok")
  })
end
local cancel_with
cancel_with = function(message)
  show_message(message)
  return aegisub.cancel()
end
local profile_threshold
profile_threshold = function(intensity)
  return PROFILE_THRESHOLDS[intensity] or PROFILE_THRESHOLDS.Balanced
end
local normalize_options
normalize_options = function(opts)
  opts = type(opts) == "table" and opts or { }
  local mode = opts.mode or "Auto"
  local known_mode = false
  for _index_0 = 1, #MODES do
    local value = MODES[_index_0]
    if mode == value then
      known_mode = true
      break
    end
  end
  if not (known_mode) then
    mode = "Auto"
  end
  local intensity = opts.intensity or "Balanced"
  local known_intensity = false
  for _index_0 = 1, #INTENSITIES do
    local value = INTENSITIES[_index_0]
    if intensity == value then
      known_intensity = true
      break
    end
  end
  if not (known_intensity) then
    intensity = "Balanced"
  end
  local threshold = finite_number(opts.threshold) or 0
  if threshold <= 0 then
    threshold = profile_threshold(intensity)
  end
  threshold = clamp(threshold, MIN_THRESHOLD, MAX_THRESHOLD)
  return {
    mode = mode,
    intensity = intensity,
    threshold = threshold,
    max_bands = math.max(MIN_BANDS, math.min(MAX_BANDS, math.floor((finite_number(opts.max_bands) or DEFAULT_MAX_BANDS) + 0.5))),
    show_summary = opts.show_summary and true or false
  }
end
local normalize_ass_color
normalize_ass_color = function(value)
  local hex = tostring(value or ""):match("&[Hh](%x+)&?")
  if not (hex) then
    return nil
  end
  hex = hex:upper()
  if #hex > 8 then return nil end
  hex = #hex > 6 and hex:sub(-6) or ("000000" .. hex):sub(-6)
  return "&H" .. tostring(hex) .. "&"
end
local rgb_to_ass
rgb_to_ass = function(r, g, b)
  local clamp8
  clamp8 = function(v)
    v = math.floor((tonumber(v) or 0) + 0.5)
    if v < 0 then
      return 0
    end
    if v > 255 then
      return 255
    end
    return v
  end
  return ("&H%02X%02X%02X&"):format(clamp8(b), clamp8(g), clamp8(r))
end
local ass_to_rgb
ass_to_rgb = function(color)
  color = normalize_ass_color(color)
  if not (color) then
    return nil
  end
  local b, g, r = color:match("&H(%x%x)(%x%x)(%x%x)&")
  if not b then return nil end
  return {
    r = tonumber(r, 16),
    g = tonumber(g, 16),
    b = tonumber(b, 16)
  }
end
local srgb8_to_linear
srgb8_to_linear = function(v)
  v = (tonumber(v) or 0) / 255
  if v <= 0 then
    return 0
  end
  if v >= 1 then
    return 1
  end
  if v <= 0.04045 then
    return v / 12.92
  end
  return ((v + 0.055) / 1.055) ^ 2.4
end
local cbrt
cbrt = function(value)
  if value >= 0 then
    return value ^ (1 / 3)
  end
  return -((-value) ^ (1 / 3))
end
local rgb_to_oklab
rgb_to_oklab = function(r, g, b)
  local lr = srgb8_to_linear(r)
  local lg = srgb8_to_linear(g)
  local lb = srgb8_to_linear(b)
  local lp = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
  local mp = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
  local sp = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb
  local lc, mc, sc = cbrt(lp), cbrt(mp), cbrt(sp)
  return {
    l = 0.2104542553 * lc + 0.7936177850 * mc - 0.0040720468 * sc,
    a = 1.9779984951 * lc - 2.4285922050 * mc + 0.4505937099 * sc,
    b = 0.0259040371 * lc + 0.7827717662 * mc - 0.8086757660 * sc
  }
end
local color_to_oklab
color_to_oklab = function(color)
  local rgb = ass_to_rgb(color)
  if not (rgb) then
    return nil
  end
  return rgb_to_oklab(rgb.r, rgb.g, rgb.b)
end
local delta_lab
delta_lab = function(left, right)
  if not (left and right) then
    return 999
  end
  local dl = left.l - right.l
  local da = left.a - right.a
  local db = left.b - right.b
  return math.sqrt(dl * dl + da * da + db * db)
end
local last_match
last_match = function(text, pattern)
  local found = nil
  for value in tostring(text or ""):gmatch(pattern) do
    found = value
  end
  return found
end
local extract_tag
extract_tag = function(tags, name)
  return last_match(tags, "\\" .. tostring(name) .. "([%-%d%.]+)")
end
local parse_drawing_bounds
parse_drawing_bounds = function(drawing, pos_x, pos_y, scale, alignment, scale_x, scale_y)
  local nums = { }
  for token in tostring(drawing or ""):gmatch("%S+") do
    local n = tonumber(token)
    if n then
      nums[#nums + 1] = n
    end
  end
  if #nums < 4 then
    return nil, L("err_no_coordinates")
  end
  if #nums % 2 ~= 0 then
    return nil, L("err_odd_coordinates")
  end
  local left, top, right, bottom = nil, nil, nil, nil
  local i = 1
  while i <= #nums do
    local x = nums[i] / scale * scale_x / 100
    local y = nums[i + 1] / scale * scale_y / 100
    if not left or x < left then
      left = x
    end
    if not right or x > right then
      right = x
    end
    if not top or y < top then
      top = y
    end
    if not bottom or y > bottom then
      bottom = y
    end
    i = i + 2
  end
  alignment = math.max(1, math.min(9, math.floor((tonumber(alignment) or 2) + 0.5)))
  local column = ((alignment - 1) % 3) + 1
  local row = math.floor((alignment - 1) / 3) + 1
  local anchor_x = column == 1 and left or (column == 2 and (left + right) / 2 or right)
  local anchor_y = row == 1 and bottom or (row == 2 and (top + bottom) / 2 or top)
  local origin_x, origin_y = pos_x - anchor_x, pos_y - anchor_y
  return {
    left = origin_x + left,
    top = origin_y + top,
    right = origin_x + right,
    bottom = origin_y + bottom,
    width = math.max(0, right - left),
    height = math.max(0, bottom - top),
    center_x = origin_x + (left + right) / 2,
    center_y = origin_y + (top + bottom) / 2,
    area = math.max(1, (right - left) * (bottom - top)),
    origin_x = origin_x,
    origin_y = origin_y
  }
end
local parse_shape_line
parse_shape_line = function(text, style)
  text = tostring(text or "")
  if not (text:match("^%s*{")) then
    return nil, L("err_simple_shape")
  end
  if text:find("\\t%(") then
    return nil, L("err_transform")
  end
  if text:find("\\move%(") then
    return nil, L("err_move")
  end
  if text:find("\\i?clip%(") then
    return nil, L("err_clip")
  end
  if text:find("\\[1234]?a&[Hh]") then
    return nil, L("err_alpha_tags")
  end
  if text:find("\\alpha&[Hh]") then
    return nil, L("err_alpha")
  end
  local tags, drawing = text:match("^%s*{([^}]*)}(.-){\\p0}%s*$")
  if not (tags and drawing) then
    return nil, L("err_simple_shape")
  end
  if drawing:find("[{}]") then
    return nil, L("err_extra_tags")
  end
  if drawing:match("^%s*$") then
    return nil, L("err_empty_path")
  end
  local residue = tags
  residue = residue:gsub("\\an%d+", "")
  residue = residue:gsub("\\pos%([^)]*%)", "")
  residue = residue:gsub("\\bord[%-%d%.]+", "")
  residue = residue:gsub("\\shad[%-%d%.]+", "")
  residue = residue:gsub("\\blur[%-%d%.]+", "")
  residue = residue:gsub("\\p%d+", "")
  residue = residue:gsub("\\1?c&[Hh]%x+&?", "")
  residue = residue:gsub("%s+", "")
  if residue ~= "" then
    return nil, L("err_unsupported_tags", residue)
  end
  local p_scale = tonumber(last_match(tags, "\\p(%d+)"))
  if not (p_scale and p_scale >= 1) then
    return nil, L("err_missing_p")
  end
  if p_scale > MAX_DRAWING_SCALE then
    return nil, L("err_unsupported_p")
  end
  local pos_value = last_match(tags, "\\pos(%b())")
  local pos_x, pos_y
  if pos_value then
    pos_x, pos_y = pos_value:match("^%(%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*%)")
  end
  if not (pos_x and pos_y) then
    return nil, L("err_missing_pos")
  end
  pos_x, pos_y = finite_number(pos_x), finite_number(pos_y)
  if not (pos_x and pos_y) then
    return nil, L("err_invalid_pos")
  end
  style = type(style) == "table" and style or {}
  local color_hex = last_match(tags, "\\1?c&[Hh](%x+)&?")
  local color_source = color_hex and ("&H" .. tostring(color_hex) .. "&")
    or style.color1 or style.primary_color or style.primaryColor
  if not color_source then
    return nil, L("err_missing_color")
  end
  local color = normalize_ass_color(color_source)
  local rgb = ass_to_rgb(color)
  local lab = color_to_oklab(color)
  if not (rgb and lab) then
    return nil, L("err_invalid_color")
  end
  local an = finite_number(last_match(tags, "\\an(%d+)")) or finite_number(style.align) or finite_number(style.alignment) or 2
  an = math.floor(an + 0.5)
  if an < 1 or an > 9 then an = 2 end
  local scale_x = finite_number(style.scale_x) or finite_number(style.scalex) or 100
  local scale_y = finite_number(style.scale_y) or finite_number(style.scaley) or 100
  if scale_x <= 0 or scale_y <= 0 then
    return nil, L("err_unsupported_tags", "invalid style scale")
  end
  local scale = 2 ^ (p_scale - 1)
  local bounds, bounds_err = parse_drawing_bounds(drawing, pos_x, pos_y, scale, an, scale_x, scale_y)
  if not (bounds) then
    return nil, bounds_err
  end
  local bord_raw = extract_tag(tags, "bord")
  local shad_raw = extract_tag(tags, "shad")
  local blur_raw = extract_tag(tags, "blur")
  local bord = bord_raw ~= nil and finite_number(bord_raw) or (finite_number(style.outline) or 0)
  local shad = shad_raw ~= nil and finite_number(shad_raw) or (finite_number(style.shadow) or 0)
  local blur = blur_raw ~= nil and finite_number(blur_raw) or nil
  if (bord_raw ~= nil and not bord) or (shad_raw ~= nil and not shad) or (blur_raw ~= nil and not blur) then
    return nil, L("err_unsupported_tags", "invalid numeric tag")
  end
  bord = format_number(bord)
  shad = format_number(shad)
  if blur ~= nil then blur = format_number(blur) end
  return {
    tags = tags,
    drawing = drawing:match("^%s*(.-)%s*$"),
    p_scale = p_scale,
    coord_scale = scale,
    coord_scale_x = scale * 100 / scale_x,
    coord_scale_y = scale * 100 / scale_y,
    pos_x = pos_x,
    pos_y = pos_y,
    color = color,
    rgb = rgb,
    lab = lab,
    an = tostring(an),
    bord = bord,
    shad = shad,
    blur = blur,
    bounds = bounds,
    visual_key = table.concat({
      tostring(p_scale),
      an,
      bord,
      shad,
      blur or "",
      format_number(scale_x),
      format_number(scale_y)
    }, "|")
  }
end
local line_key
line_key = function(line, parsed)
  local fields = {
    line.start_time or "",
    line.end_time or "",
    line.style or "",
    line.actor or "",
    line.effect or "",
    line.layer or 0,
    line.margin_l or "",
    line.margin_r or "",
    line.margin_t or line.margin_v or "",
    line.comment and "1" or "0",
    parsed.visual_key
  }
  for index = 1, #fields do fields[index] = tostring(fields[index]) end
  return table.concat(fields, "\31")
end
local collect_items
collect_items = function(subs, sel)
  if type(sel) ~= "table" then
    return nil, L("err_two_shapes")
  end
  local sorted = LineOps.normalizeIndices(subs, sel)
  if #sorted < 2 then return nil, L("err_two_shapes") end
  for i = 2, #sorted do
    if sorted[i] ~= sorted[i - 1] + 1 then
      return nil, L("err_contiguous")
    end
  end
  local styles = { }
  for index = 1, #subs do
    local candidate = subs[index]
    if candidate and candidate.class == "style" and candidate.name then
      styles[candidate.name] = candidate
    end
  end
  local items = { }
  local common_key = nil
  for _, index in ipairs(sorted) do
    local line = subs[index]
    if not (line and line.class == "dialogue") then
      return nil, L("err_not_dialogue", index)
    end
    local style = line.styleref or line.styleRef or line.style_ref or styles[line.style]
    local parsed, err = parse_shape_line(line.text, style)
    if not (parsed) then
      return nil, L("err_line", index, err)
    end
    local key = line_key(line, parsed)
    if not (common_key) then
      common_key = key
    end
    if key ~= common_key then
      return nil, L("err_mixed")
    end
    parsed.index = index
    parsed.line = line
    parsed.weight = math.max(1, parsed.bounds.area)
    items[#items + 1] = parsed
  end
  return items
end
local unique_color_count
unique_color_count = function(items)
  local seen, count = { }, 0
  for _index_0 = 1, #items do
    local item = items[_index_0]
    if not (seen[item.color]) then
      seen[item.color] = true
      count = count + 1
    end
  end
  return count
end
local average_color
average_color = function(items)
  local total, r, g, b = 0, 0, 0, 0
  for _index_0 = 1, #items do
    local item = items[_index_0]
    local w = item.weight or 1
    total = total + w
    r = r + (item.rgb.r * w)
    g = g + (item.rgb.g * w)
    b = b + (item.rgb.b * w)
  end
  if total <= 0 then
    total = 1
  end
  return rgb_to_ass(r / total, g / total, b / total)
end
local offset_drawing
offset_drawing = function(drawing, dx, dy)
  local out, is_x = { }, true
  for token in tostring(drawing or ""):gmatch("%S+") do
    local n = tonumber(token)
    if n then
      local value = n + (is_x and dx or dy)
      out[#out + 1] = format_number(value)
      is_x = not is_x
    else
      out[#out + 1] = token
    end
  end
  return table.concat(out, " ")
end
local merged_text
merged_text = function(items, color)
  local first = items[1]
  local base_x, base_y = first.bounds.left, first.bounds.top
  for _index_0 = 1, #items do
    local item = items[_index_0]
    if item.bounds.left < base_x then
      base_x = item.bounds.left
    end
    if item.bounds.top < base_y then
      base_y = item.bounds.top
    end
  end
  local drawings = { }
  for _index_0 = 1, #items do
    local item = items[_index_0]
    local dx = (item.bounds.origin_x - base_x) * item.coord_scale_x
    local dy = (item.bounds.origin_y - base_y) * item.coord_scale_y
    drawings[#drawings + 1] = offset_drawing(item.drawing, dx, dy)
  end
  local blur_tag = ""
  if first.blur and math.abs(tonumber(first.blur) or 0) > EPSILON then
    blur_tag = "\\blur" .. tostring(first.blur)
  end
  return "{\\an7\\pos(" .. tostring(format_number(base_x)) .. "," .. tostring(format_number(base_y)) .. ")\\bord" .. tostring(first.bord) .. "\\shad" .. tostring(first.shad) .. tostring(blur_tag) .. "\\p" .. tostring(first.p_scale) .. "\\1c" .. tostring(color) .. "}" .. tostring(table.concat(drawings, " ")) .. "{\\p0}"
end
local new_cluster
new_cluster = function(item)
  local cluster = {
    items = { },
    total = 0,
    r = 0,
    g = 0,
    b = 0,
    first_index = item.index or 0,
    color = item.color,
    lab = item.lab
  }
  return cluster
end
local add_to_cluster
add_to_cluster = function(cluster, item)
  cluster.items[#cluster.items + 1] = item
  local w = item.weight or 1
  cluster.total = cluster.total + w
  cluster.r = cluster.r + (item.rgb.r * w)
  cluster.g = cluster.g + (item.rgb.g * w)
  cluster.b = cluster.b + (item.rgb.b * w)
  if item.index and item.index < cluster.first_index then
    cluster.first_index = item.index
  end
  cluster.color = rgb_to_ass(cluster.r / cluster.total, cluster.g / cluster.total, cluster.b / cluster.total)
  cluster.lab = color_to_oklab(cluster.color)
end
local cluster_accepts
cluster_accepts = function(cluster, item, threshold)
  local weight = item.weight or 1
  local total = cluster.total + weight
  if total <= 0 then return false end
  local color = rgb_to_ass(
    (cluster.r + item.rgb.r * weight) / total,
    (cluster.g + item.rgb.g * weight) / total,
    (cluster.b + item.rgb.b * weight) / total
  )
  local lab = color_to_oklab(color)
  if delta_lab(item.lab, lab) > threshold + EPSILON then return false end
  for _, existing in ipairs(cluster.items) do
    if delta_lab(existing.lab, lab) > threshold + EPSILON then return false end
  end
  return true
end
local similar_optimize
similar_optimize = function(items, opts)
  local clusters = { }
  for _index_0 = 1, #items do
    local item = items[_index_0]
    local best, best_delta = nil, 999
    for _index_1 = 1, #clusters do
      local cluster = clusters[_index_1]
      local delta = delta_lab(item.lab, cluster.lab)
      if delta < best_delta and delta <= opts.threshold and cluster_accepts(cluster, item, opts.threshold) then
        best, best_delta = cluster, delta
      end
    end
    if best then
      add_to_cluster(best, item)
    else
      local cluster = new_cluster(item)
      add_to_cluster(cluster, item)
      clusters[#clusters + 1] = cluster
    end
  end
  table.sort(clusters, function(a, b)
    return a.first_index < b.first_index
  end)
  local texts = { }
  for _index_0 = 1, #clusters do
    local cluster = clusters[_index_0]
    table.sort(cluster.items, function(a, b)
      return a.index < b.index
    end)
    texts[#texts + 1] = merged_text(cluster.items, cluster.color)
  end
  return {
    mode = "Similar colors",
    texts = texts,
    colors_after = #clusters,
    details = L("detail_threshold", opts.threshold)
  }
end
local projection_value
projection_value = function(item, axis)
  if axis == "Vertical" then
    return item.bounds.center_y
  else
    return item.bounds.center_x
  end
end
local gradient_score
gradient_score = function(items, axis)
  local min_p, max_p = nil, nil
  local sorted
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #items do
      local item = items[_index_0]
      _accum_0[_len_0] = item
      _len_0 = _len_0 + 1
    end
    sorted = _accum_0
  end
  table.sort(sorted, function(a, b)
    return projection_value(a, axis) < projection_value(b, axis)
  end)
  for _index_0 = 1, #sorted do
    local item = sorted[_index_0]
    local p = projection_value(item, axis)
    if not min_p or p < min_p then
      min_p = p
    end
    if not max_p or p > max_p then
      max_p = p
    end
  end
  local span = (max_p or 0) - (min_p or 0)
  if span < EPSILON then
    return nil
  end
  local first, last = sorted[1], sorted[#sorted]
  local endpoint_delta = delta_lab(first.lab, last.lab)
  if endpoint_delta < MIN_GRADIENT_ENDPOINT_DELTA then
    return nil
  end
  local total_w, total_err, max_err = 0, 0, 0
  for _index_0 = 1, #sorted do
    local item = sorted[_index_0]
    local t = (projection_value(item, axis) - min_p) / span
    local predicted = {
      l = first.lab.l + (last.lab.l - first.lab.l) * t,
      a = first.lab.a + (last.lab.a - first.lab.a) * t,
      b = first.lab.b + (last.lab.b - first.lab.b) * t
    }
    local err = delta_lab(item.lab, predicted)
    local w = item.weight or 1
    total_w = total_w + w
    total_err = total_err + (err * w)
    if err > max_err then
      max_err = err
    end
  end
  return {
    axis = axis,
    sorted = sorted,
    avg_err = total_err / math.max(1, total_w),
    max_err = max_err,
    endpoint_delta = endpoint_delta,
    span = span
  }
end
local detect_gradient
detect_gradient = function(items, opts)
  if not (#items >= MIN_GRADIENT_ITEMS) then
    return nil
  end
  local horizontal = gradient_score(items, "Horizontal")
  local vertical = gradient_score(items, "Vertical")
  local best = horizontal
  if vertical and (not best or vertical.avg_err < best.avg_err) then
    best = vertical
  end
  if not (best) then
    return nil
  end
  local avg_limit = math.max(MIN_GRADIENT_AVERAGE_LIMIT, opts.threshold * GRADIENT_AVERAGE_FACTOR)
  local max_limit = math.max(MIN_GRADIENT_MAX_LIMIT, opts.threshold * GRADIENT_MAX_FACTOR)
  if best.avg_err > avg_limit or best.max_err > max_limit then
    return nil
  end
  return best
end
local gradient_optimize
gradient_optimize = function(items, opts)
  local score = detect_gradient(items, opts)
  if not (score) then
    return nil, L("no_gradient")
  end
  local target_bands = math.min(opts.max_bands, #items)
  if target_bands >= #items then
    return nil, L("gradient_within_target")
  end
  local bands
  do
    local _accum_0 = { }
    local _len_0 = 1
    for i = 1, target_bands do
      _accum_0[_len_0] = { }
      _len_0 = _len_0 + 1
    end
    bands = _accum_0
  end
  for rank, item in ipairs(score.sorted) do
    local band = math.floor((rank - 1) * target_bands / #score.sorted) + 1
    bands[band][#bands[band] + 1] = item
  end
  local texts, used_bands = { }, 0
  for _index_0 = 1, #bands do
    local band_items = bands[_index_0]
    if #band_items > 0 then
      used_bands = used_bands + 1
      texts[#texts + 1] = merged_text(band_items, average_color(band_items))
    end
  end
  return {
    mode = "Full gradient",
    texts = texts,
    colors_after = used_bands,
    details = L("detail_gradient", L(score.axis == "Vertical" and "axis_vertical" or "axis_horizontal"), score.avg_err)
  }
end
local optimize_items
optimize_items = function(items, opts)
  if opts == nil then
    opts = { }
  end
  opts = normalize_options(opts)
  local result, err = nil, nil
  if opts.mode == "Auto" then
    result, err = gradient_optimize(items, opts)
    if not result or #result.texts >= #items then
      result = similar_optimize(items, opts)
      result.mode = "Auto -> " .. result.mode
    end
  elseif opts.mode == "Full gradient" then
    result, err = gradient_optimize(items, opts)
    if not (result) then
      result = similar_optimize(items, opts)
      result.mode = "Full gradient -> Similar colors"
      if err then
        result.details = result.details .. L("detail_fallback", err)
      end
    end
  else
    result = similar_optimize(items, opts)
  end
  if not (result and result.texts and #result.texts > 0) then
    return nil, L("err_no_output")
  end
  return result
end
local analyze_selection
analyze_selection = function(subs, sel, opts)
  if opts == nil then
    opts = { }
  end
  opts = normalize_options(opts)
  local items, err = collect_items(subs, sel)
  if not (items) then
    return nil, err
  end
  local result, opt_err = optimize_items(items, opts)
  if not (result) then
    return nil, opt_err
  end
  local chars_before = 0
  for _index_0 = 1, #items do
    local item = items[_index_0]
    chars_before = chars_before + #(item.line.text or "")
  end
  local chars_after = 0
  local _list_0 = result.texts
  for _index_0 = 1, #_list_0 do
    local text = _list_0[_index_0]
    chars_after = chars_after + #text
  end
  local before_lines = #items
  local after_lines = #result.texts
  local before_colors = unique_color_count(items)
  local after_colors = result.colors_after or before_colors
  local changed = after_lines ~= before_lines
  if not changed then
    for index = 1, before_lines do
      if result.texts[index] ~= tostring(items[index].line.text or "") then
        changed = true
        break
      end
    end
  end
  return {
    items = items,
    texts = result.texts,
    mode = result.mode,
    details = result.details,
    before_lines = before_lines,
    after_lines = after_lines,
    before_colors = before_colors,
    after_colors = after_colors,
    chars_before = chars_before,
    chars_after = chars_after,
    changed = changed
  }
end
local summary_text
summary_text = function(report)
  local mode = report.mode
  if mode == "Auto -> Similar colors" then
    mode = tostring(L(MODE_KEYS.Auto)) .. " -> " .. tostring(L(MODE_KEYS["Similar colors"]))
  elseif mode == "Full gradient -> Similar colors" then
    mode = tostring(L(MODE_KEYS["Full gradient"])) .. " -> " .. tostring(L(MODE_KEYS["Similar colors"]))
  elseif MODE_KEYS[mode] then
    mode = L(MODE_KEYS[mode])
  end
  local lines = {
    current_title or L("title"),
    "",
    L("summary_mode", mode),
    L("summary_detail", report.details or ""),
    "",
    L("summary_lines", report.before_lines, report.after_lines),
    L("summary_colors", report.before_colors, report.after_colors),
    L("summary_characters", report.chars_before, report.chars_after)
  }
  return table.concat(lines, "\n")
end
local apply_report
apply_report = function(subs, selection_or_report, report)
  report = report or selection_or_report
  local sorted = { }
  for _, item in ipairs(report.items or {}) do sorted[#sorted + 1] = item.index end
  table.sort(sorted)
  local first_index = sorted[1]
  local template = report.items[1].line
  for i = #sorted, 1, -1 do
    subs.delete(sorted[i])
  end
  local lines = { }
  for i, text in ipairs(report.texts) do
    local new_line = copy_line(template)
    new_line.text = text
    lines[i] = new_line
  end
  return LineOps.insertLines(subs, { { index = first_index, lines = lines } })
end
local localized_values
localized_values = function(values, keys)
  local items, from_label, to_label = { }, { }, { }
  for _index_0 = 1, #values do
    local value = values[_index_0]
    local label = L(keys[value])
    items[#items + 1] = label
    from_label[label] = value
    to_label[value] = label
  end
  return items, from_label, to_label
end
local build_dialog
build_dialog = function(saved)
  local mode_items, mode_from_label, mode_to_label = localized_values(MODES, MODE_KEYS)
  local intensity_items, intensity_from_label, intensity_to_label = localized_values(INTENSITIES, INTENSITY_KEYS)
  local dialog = {
    {
      class = "label",
      label = L("mode"),
      x = 0,
      y = 0,
      width = 3,
      height = 1
    },
    {
      class = "dropdown",
      name = "mode",
      items = mode_items,
      value = mode_to_label[saved.mode] or mode_items[1],
      x = 3,
      y = 0,
      width = 6,
      height = 1
    },
    {
      class = "label",
      label = L("intensity"),
      x = 0,
      y = 1,
      width = 3,
      height = 1
    },
    {
      class = "dropdown",
      name = "intensity",
      items = intensity_items,
      value = intensity_to_label[saved.intensity] or intensity_items[1],
      x = 3,
      y = 1,
      width = 6,
      height = 1
    },
    {
      class = "label",
      label = L("threshold"),
      x = 0,
      y = 2,
      width = 4,
      height = 1
    },
    {
      class = "floatedit",
      name = "threshold",
      value = saved.threshold,
      min = 0,
      max = MAX_THRESHOLD,
      step = MIN_THRESHOLD,
      x = 4,
      y = 2,
      width = 3,
      height = 1
    },
    {
      class = "label",
      label = L("max_bands"),
      x = 0,
      y = 3,
      width = 3,
      height = 1
    },
    {
      class = "intedit",
      name = "max_bands",
      value = saved.max_bands,
      min = MIN_BANDS,
      max = MAX_BANDS,
      x = 3,
      y = 3,
      width = 3,
      height = 1
    },
    {
      class = "checkbox",
      name = "show_summary",
      label = L("show_summary"),
      value = saved.show_summary,
      x = 0,
      y = 4,
      width = 9,
      height = 1
    }
  }
  return dialog, {
    mode = mode_from_label,
    intensity = intensity_from_label
  }
end
local function setLanguage(language)
  if LANG[language] then current_lang = language else current_lang = "en" end
  return current_lang
end

local function commitUndo(context)
  local name = context.undo_name or current_title or L("title")
  if type(context.undo) == "function" then
    context.undo(context.undo_key or "tool_undo_shape_optimizer", name)
  elseif aegisub and type(aegisub.set_undo_point) == "function" then
    aegisub.set_undo_point(name)
  end
end

local function main(subs, sel, _, context)
  context = context or {}
  setLanguage(context.language)
  current_title = context.title or L("title")
  if not (sel and #sel >= 2) then cancel_with(L("err_two_shapes")) end
  local settings = settingsFor(context)
  local dialogSpec, maps = build_dialog(settings:values("main"))
  local execute, cancel = L("execute"), L("cancel")
  local button, result = aegisub.dialog.display(dialogSpec, {execute, cancel}, {ok = execute, close = cancel})
  if button ~= execute then return sel end
  result.mode = maps.mode[result.mode] or "Auto"
  result.intensity = maps.intensity[result.intensity] or "Balanced"
  settings:update("main", result)
  settings:write()
  local options = normalize_options(result)
  local report, err = analyze_selection(subs, sel, options)
  if not report then cancel_with(err) end
  if not report.changed then
    show_message(tostring(L("no_reduction")) .. "\n\n" .. tostring(summary_text(report)))
    return sel
  end
  if options.show_summary then
    local confirm = aegisub.dialog.display({
      {class = "textbox", value = summary_text(report) .. "\n\n" .. L("confirm_apply"), x = 0, y = 0, width = 56, height = 10}
    }, {execute, cancel}, {ok = execute, close = cancel})
    if confirm ~= execute then return sel end
  end
  local newSelection = LineOps.transaction(subs, "", function()
    return apply_report(subs, report)
  end)
  commitUndo(context)
  if not context.silent then show_message(summary_text(report)) end
  return newSelection
end

local function validate(subs, sel)
  if not (sel and #sel >= 2) then return false end
  local indices = LineOps.normalizeIndices(subs, sel, function(line)
    return line and line.class == "dialogue"
  end)
  if #indices < 2 then return false end
  for _, index in ipairs(indices) do
    if LineOps.hasDrawing(subs[index].text) then return true end
  end
  return false
end

ShapeOptimizer.languages = LANG
ShapeOptimizer.modes = MODES
ShapeOptimizer.intensities = INTENSITIES
ShapeOptimizer.setLanguage = setLanguage
ShapeOptimizer.normalizeOptions = normalize_options
ShapeOptimizer.parseLine = parse_shape_line
ShapeOptimizer.collectItems = collect_items
ShapeOptimizer.optimizeItems = optimize_items
ShapeOptimizer.analyzeSelection = analyze_selection
ShapeOptimizer.applyReport = apply_report
ShapeOptimizer.summaryText = summary_text
ShapeOptimizer.main = main
ShapeOptimizer.validate = validate

if depctrl then
  ShapeOptimizer.version = depctrl
  return depctrl:register(ShapeOptimizer)
end
return ShapeOptimizer
