local moduleVersion = "1.3.2"
local ShapeOptimizer = { VERSION = moduleVersion, version = moduleVersion }

local function safeRequire(name)
  local ok, value = pcall(require, name)
  if ok then return value end
  return nil
end

local DependencyControl = safeRequire("l0.DependencyControl")
local Core = assert(safeRequire("kite.Core"), "kite.Core is required")
local Color = assert(safeRequire("kite.Color"), "kite.Color is required")
local LineOps = safeRequire("kite.LineOps")
local depctrl
if DependencyControl then
  depctrl = DependencyControl({
    name = "kite.ShapeOptimizer",
    version = moduleVersion,
    description = "Shared ASS vector-shape color and gradient optimizer for Kite macros",
    author = "Kiterow",
    url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
    moduleName = "kite.ShapeOptimizer",
    feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    {
      { "kite.Core", version = "1.1.0" },
      { "kite.LineOps", version = "1.7.0" },
      { "kite.Settings", version = "1.0.0" },
      { "kite.Color", version = "1.2.2" },
    },
  })
end

if not LineOps then error("kite.LineOps is required", 0) end

local languages = {
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
    err_mixed = "The selection mixes timing, style, layer, margins, or metadata.",
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
    err_mixed = "La selección mezcla tiempos, estilos, capas, márgenes o metadatos.",
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
    err_mixed = "A seleção combina tempos, estilos, camadas, margens ou metadados.",
    err_no_output = "O otimizador de formas não produziu nenhum resultado.",
    no_reduction = "Nenhuma redução segura foi encontrada com estes parâmetros.",
    confirm_apply = "Aplicar a substituição direta?"
  }
}
local currentLang = "en"
local currentTitle
local translate
translate = function(key, ...)
  local text = (languages[currentLang] and languages[currentLang][key]) or languages.en[key] or key
  if select("#", ...) == 0 then
    return text
  end
  return string.format(text, ...)
end
local modes = {
  "Auto",
  "Similar colors",
  "Full gradient"
}
local intensities = {
  "Balanced",
  "Fidelity",
  "Aggressive"
}
local modeKeys = {
  Auto = "mode_auto",
  ["Similar colors"] = "mode_similar",
  ["Full gradient"] = "mode_gradient"
}
local intensityKeys = {
  Balanced = "intensity_balanced",
  Fidelity = "intensity_fidelity",
  Aggressive = "intensity_aggressive"
}
local epsilon = 0.000001
local formatDecimals = 3
local formatRoundEpsilon = 0.5 * 10 ^ -formatDecimals
local minThreshold, maxThreshold = 0.005, 0.25
local minBands = 2
local defaultMaxBands = 8
local minGradientItems = 4
local minGradientEndpointDelta = 0.03
local minGradientAverageLimit, minGradientMaxLimit = 0.075, 0.180
local gradientAverageFactor, gradientMaxFactor = 1.6, 3.0
local profileThresholds = { Fidelity = 0.035, Balanced = 0.065, Aggressive = 0.100 }
local settingsCache = {}
local settingsDefaults = {
  main = {
    mode = "Auto",
    intensity = "Balanced",
    threshold = 0,
    max_bands = defaultMaxBands,
    show_summary = false
  }
}

local function settingsFor(context)
  context = context or {}
  local namespace = context.settings_namespace or "kite.ShapeOptimizer"
  local version = context.settings_version or ShapeOptimizer.VERSION
  local key = namespace .. "\31" .. version
  if not settingsCache[key] then
    settingsCache[key] = require("kite.Settings").open(namespace, version, settingsDefaults, {})
  end
  return settingsCache[key]
end

local copyLine = Core.deepCopy
local clamp = Core.clamp
local finiteNumber = Core.finiteNumber
local formatNumber
formatNumber = function(value)
  value = tonumber(value) or 0
  if math.abs(value) < formatRoundEpsilon then
    value = 0
  end
  local nearest = math.floor(value + 0.5)
  if math.abs(value - nearest) < formatRoundEpsilon then
    return tostring(nearest)
  end
  local text = ("%." .. tostring(formatDecimals) .. "f"):format(value)
  text = text:gsub("0+$", "")
  text = text:gsub("%.$", "")
  return text
end
local Geometry = {
  numberPattern = "[%+%-]?%d*%.?%d+",
  epsilon = 0.0000001
}
Geometry.translate = function(context, key, fallback, ...)
  local value = fallback
  if context and type(context.translate) == "function" then
    local translated = context.translate(key)
    if translated and translated ~= key then value = translated end
  end
  if select("#", ...) == 0 then return value end
  return string.format(value, ...)
end
Geometry.finite = finiteNumber
Geometry.cloneLine = copyLine
Geometry.formatNumber = function(value, precision)
  value = finiteNumber(value) or 0
  precision = tonumber(precision) or 6
  if math.abs(value) < Geometry.epsilon then value = 0 end
  local text = string.format("%." .. tostring(precision) .. "f", value)
  text = text:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
  if text == "-0" then text = "0" end
  return text
end
Geometry.splitText = function(text, translateMessage, requiredTags)
  translateMessage = translateMessage or function(_, fallback) return fallback end
  text = tostring(text or "")
  local cursor, prefixEnd = 1, 0
  while text:sub(cursor, cursor) == "{" do
    local close = text:find("}", cursor, true)
    if not close then return nil, translateMessage("sh_err_open_block", "The leading override block is not closed.") end
    local inner = text:sub(cursor + 1, close - 1)
    if not inner:match("^%s*\\") then break end
    prefixEnd = close
    cursor = close + 1
  end
  if prefixEnd == 0 then
    return nil, translateMessage("sh_err_initial_tags", requiredTags or "The drawing needs leading tags with \\pos and \\pN.")
  end
  local prefix = text:sub(1, prefixEnd)
  local body = text:sub(prefixEnd + 1)
  local drawing, suffix = body:match("^(.-)(%s*{\\p0}%s*)$")
  if not drawing then
    if body:find("{", 1, true) then
      return nil, translateMessage("sh_err_static_drawing", "Only one static drawing and an optional final {\\p0} are supported.")
    end
    drawing, suffix = body, ""
  end
  if drawing:match("^%s*$") then
    return nil, translateMessage("sh_err_empty_drawing", "The line contains no drawing data.")
  end
  return {prefix = prefix, drawing = drawing, suffix = suffix}
end
Geometry.hasPlainTag = function(text, tag)
  return tostring(text or ""):find("\\" .. tostring(tag), 1, true) ~= nil
end
Geometry.lastNumericTag = function(text, name)
  local value
  local pattern = "\\" .. tostring(name) .. "%s*(" .. Geometry.numberPattern .. ")"
  for number in tostring(text or ""):gmatch(pattern) do value = tonumber(number) end
  return value
end
Geometry.parsePosition = function(prefix, translateMessage, qualifier)
  translateMessage = translateMessage or function(_, fallback) return fallback end
  local pattern = "\\pos%s*%(%s*(" .. Geometry.numberPattern .. ")%s*,%s*(" .. Geometry.numberPattern .. ")%s*%)"
  local count, x, y = 0
  tostring(prefix or ""):gsub(pattern, function(px, py)
    count, x, y = count + 1, tonumber(px), tonumber(py)
    return ""
  end)
  if count ~= 1 or not finiteNumber(x) or not finiteNumber(y) then
    return nil, translateMessage("sh_err_exact_pos", qualifier or "Each line must have exactly one \\pos(x,y).")
  end
  return {x = x, y = y, pattern = pattern}
end
Geometry.tokenizePath = function(path, translateMessage)
  translateMessage = translateMessage or function(_, fallback) return fallback end
  local tokens, index = {}, 1
  local commands = {m=true, n=true, l=true, b=true, s=true, p=true, c=true}
  path = tostring(path or "")
  while index <= #path do
    local char = path:sub(index, index)
    if char:match("[%s,]") then
      index = index + 1
    elseif char:match("%a") then
      local command = char:lower()
      if not commands[command] then
        return nil, translateMessage("sh_err_path_command", "The drawing contains the unsupported command '%s'.", char)
      end
      tokens[#tokens + 1] = {kind = "command", value = command}
      index = index + 1
    else
      local number = path:sub(index):match("^(" .. Geometry.numberPattern .. ")")
      if not number then
        return nil, translateMessage("sh_err_path_data", "The drawing contains data that could not be parsed.")
      end
      tokens[#tokens + 1] = {kind = "number", value = tonumber(number)}
      index = index + #number
    end
  end
  return tokens
end
Geometry.styleMaps = function(subs)
  local exact, folded = {}, {}
  for index = 1, #subs do
    local item = subs[index]
    if type(item) == "table" and item.class == "style" then
      local name = tostring(item.name or item.style or "")
      if name ~= "" then
        exact[name] = item
        folded[name:lower()] = item
      end
    end
  end
  return exact, folded
end
Geometry.styleFor = function(exact, folded, name)
  name = tostring(name or "")
  return exact[name] or folded[name:lower()]
end
Geometry.selectionIndices = function(subs, sel)
  return LineOps.normalizeIndices(subs, sel, function(line)
    return line and line.class == "dialogue" and not line.comment
  end)
end
local showMessage
showMessage = function(message)
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
    translate("ok")
  })
end
local cancelWith
cancelWith = function(message)
  showMessage(message)
  return aegisub.cancel()
end
local profileThreshold
profileThreshold = function(intensity)
  return profileThresholds[intensity] or profileThresholds.Balanced
end
local normalizeOptions
normalizeOptions = function(opts)
  opts = type(opts) == "table" and opts or { }
  local mode = opts.mode or "Auto"
  local knownMode = false
  for index0 = 1, #modes do
    local value = modes[index0]
    if mode == value then
      knownMode = true
      break
    end
  end
  if not (knownMode) then
    mode = "Auto"
  end
  local intensity = opts.intensity or "Balanced"
  local knownIntensity = false
  for index0 = 1, #intensities do
    local value = intensities[index0]
    if intensity == value then
      knownIntensity = true
      break
    end
  end
  if not (knownIntensity) then
    intensity = "Balanced"
  end
  local threshold = finiteNumber(opts.threshold) or 0
  if threshold <= 0 then
    threshold = profileThreshold(intensity)
  end
  threshold = clamp(threshold, minThreshold, maxThreshold)
  return {
    mode = mode,
    intensity = intensity,
    threshold = threshold,
    max_bands = math.max(minBands, math.floor((finiteNumber(opts.max_bands) or defaultMaxBands) + 0.5)),
    show_summary = opts.show_summary and true or false
  }
end
local normalizeAssColor
normalizeAssColor = function(value)
  local hex = tostring(value or ""):match("&[Hh](%x+)&?")
  if not (hex) then
    return nil
  end
  hex = hex:upper()
  if #hex > 8 then return nil end
  hex = #hex > 6 and hex:sub(-6) or ("000000" .. hex):sub(-6)
  return "&H" .. tostring(hex) .. "&"
end
local rgbToAss
rgbToAss = function(r, g, b)
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
local assToRgb
assToRgb = function(color)
  color = normalizeAssColor(color)
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
local rgbToOklab = function(r, g, b)
  local l, a, blue = Color.rgbToOklab(r, g, b)
  return {l=l, a=a, b=blue}
end
local colorToOklab
colorToOklab = function(color)
  local rgb = assToRgb(color)
  if not (rgb) then
    return nil
  end
  return rgbToOklab(rgb.r, rgb.g, rgb.b)
end
local deltaLab
deltaLab = function(left, right)
  if not (left and right) then
    return 999
  end
  local dl = left.l - right.l
  local da = left.a - right.a
  local db = left.b - right.b
  return math.sqrt(dl * dl + da * da + db * db)
end
local lastMatch
lastMatch = function(text, pattern)
  local found = nil
  for value in tostring(text or ""):gmatch(pattern) do
    found = value
  end
  return found
end
local extractTag
extractTag = function(tags, name)
  return lastMatch(tags, "\\" .. tostring(name) .. "([%-%d%.]+)")
end
local extractAlphaTags
extractAlphaTags = function(tags)
  local values, explicit = { }, { }
  for name, hex in tostring(tags or ""):gmatch("\\([%a%d]+)&[Hh](%x+)&?") do
    local alpha = ("00" .. tostring(hex):upper()):sub(-2)
    if name == "alpha" then
      for channel = 1, 4 do
        values[channel], explicit[channel] = alpha, true
      end
    else
      local channel = tonumber(name:match("^([1234])a$"))
      if channel then
        values[channel], explicit[channel] = alpha, true
      end
    end
  end
  local out = { }
  for channel = 1, 4 do
    if explicit[channel] then
      out[#out + 1] = "\\" .. tostring(channel) .. "a&H" .. tostring(values[channel]) .. "&"
    end
  end
  return table.concat(out)
end
local parseDrawingBounds
parseDrawingBounds = function(drawing, posX, posY, scale, alignment, scaleX, scaleY)
  local nums = { }
  for token in tostring(drawing or ""):gmatch("%S+") do
    local n = tonumber(token)
    if n then
      nums[#nums + 1] = n
    end
  end
  if #nums < 4 then
    return nil, translate("err_no_coordinates")
  end
  if #nums % 2 ~= 0 then
    return nil, translate("err_odd_coordinates")
  end
  local left, top, right, bottom = nil, nil, nil, nil
  local i = 1
  while i <= #nums do
    local x = nums[i] / scale * scaleX / 100
    local y = nums[i + 1] / scale * scaleY / 100
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
  local width, height = right - left, bottom - top
  local anchorX = column == 1 and 0 or (column == 2 and width / 2 or width)
  local anchorY = row == 1 and height or (row == 2 and height / 2 or 0)
  local originX, originY = posX - anchorX, posY - anchorY
  return {
    left = originX + left,
    top = originY + top,
    right = originX + right,
    bottom = originY + bottom,
    width = math.max(0, right - left),
    height = math.max(0, bottom - top),
    center_x = originX + (left + right) / 2,
    center_y = originY + (top + bottom) / 2,
    area = math.max(1, (right - left) * (bottom - top)),
    origin_x = originX,
    origin_y = originY
  }
end
local parseShapeLine
parseShapeLine = function(text, style)
  text = tostring(text or "")
  if not (text:match("^%s*{")) then
    return nil, translate("err_simple_shape")
  end
  if text:find("\\t%(") then
    return nil, translate("err_transform")
  end
  if text:find("\\move%(") then
    return nil, translate("err_move")
  end
  if text:find("\\i?clip%(") then
    return nil, translate("err_clip")
  end
  local tags, drawing = text:match("^%s*{([^}]*)}(.-){\\p0}%s*$")
  if not tags then
    tags, drawing = text:match("^%s*{([^}]*)}([^{}]-)%s*$")
  end
  if not (tags and drawing) then
    return nil, translate("err_simple_shape")
  end
  if drawing:find("[{}]") then
    return nil, translate("err_extra_tags")
  end
  if drawing:match("^%s*$") then
    return nil, translate("err_empty_path")
  end
  local visualTags = tags
  visualTags = visualTags:gsub("\\an%d+", "")
  visualTags = visualTags:gsub("\\pos%([^)]*%)", "")
  visualTags = visualTags:gsub("\\p%d+", "")
  visualTags = visualTags:gsub("\\1?c&[Hh]%x+&?", "")
  visualTags = visualTags:match("^%s*(.-)%s*$")
  local residue = tags
  residue = residue:gsub("\\an%d+", "")
  residue = residue:gsub("\\pos%([^)]*%)", "")
  residue = residue:gsub("\\bord[%-%d%.]+", "")
  residue = residue:gsub("\\[xy]bord[%-%d%.]+", "")
  residue = residue:gsub("\\shad[%-%d%.]+", "")
  residue = residue:gsub("\\[xy]shad[%-%d%.]+", "")
  residue = residue:gsub("\\blur[%-%d%.]+", "")
  residue = residue:gsub("\\be[%-%d%.]+", "")
  residue = residue:gsub("\\fsc[xy][%-%d%.]+", "")
  residue = residue:gsub("\\p%d+", "")
  residue = residue:gsub("\\1?c&[Hh]%x+&?", "")
  residue = residue:gsub("\\[234]c&[Hh]%x+&?", "")
  residue = residue:gsub("\\alpha&[Hh]%x+&?", "")
  residue = residue:gsub("\\[1234]a&[Hh]%x+&?", "")
  residue = residue:gsub("\\fad%b()", "")
  residue = residue:gsub("\\fade%b()", "")
  residue = residue:gsub("%s+", "")
  if residue ~= "" then
    return nil, translate("err_unsupported_tags", residue)
  end
  local pScale = tonumber(lastMatch(tags, "\\p(%d+)"))
  if not (pScale and pScale >= 1) then
    return nil, translate("err_missing_p")
  end
  if not finiteNumber(2 ^ (pScale - 1)) then
    return nil, translate("err_unsupported_p")
  end
  local posValue = lastMatch(tags, "\\pos(%b())")
  local posX, posY
  if posValue then
    posX, posY = posValue:match("^%(%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*%)")
  end
  if not (posX and posY) then
    return nil, translate("err_missing_pos")
  end
  posX, posY = finiteNumber(posX), finiteNumber(posY)
  if not (posX and posY) then
    return nil, translate("err_invalid_pos")
  end
  style = type(style) == "table" and style or {}
  local colorHex = lastMatch(tags, "\\1?c&[Hh](%x+)&?")
  local colorSource = colorHex and ("&H" .. tostring(colorHex) .. "&")
    or style.color1 or style.primary_color or style.primaryColor
  if not colorSource then
    return nil, translate("err_missing_color")
  end
  local color = normalizeAssColor(colorSource)
  local rgb = assToRgb(color)
  local lab = colorToOklab(color)
  if not (rgb and lab) then
    return nil, translate("err_invalid_color")
  end
  local an = finiteNumber(lastMatch(tags, "\\an(%d+)")) or finiteNumber(style.align) or finiteNumber(style.alignment) or 2
  an = math.floor(an + 0.5)
  if an < 1 or an > 9 then an = 2 end
  local scaleXRaw = extractTag(tags, "fscx")
  local scaleYRaw = extractTag(tags, "fscy")
  if (scaleXRaw ~= nil and not finiteNumber(scaleXRaw))
    or (scaleYRaw ~= nil and not finiteNumber(scaleYRaw)) then
    return nil, translate("err_unsupported_tags", "invalid scale")
  end
  local scaleX = scaleXRaw ~= nil and finiteNumber(scaleXRaw)
    or finiteNumber(style.scale_x) or finiteNumber(style.scalex) or 100
  local scaleY = scaleYRaw ~= nil and finiteNumber(scaleYRaw)
    or finiteNumber(style.scale_y) or finiteNumber(style.scaley) or 100
  if scaleX <= 0 or scaleY <= 0 then
    return nil, translate("err_unsupported_tags", "invalid scale")
  end
  local scale = 2 ^ (pScale - 1)
  local bounds, boundsErr = parseDrawingBounds(drawing, posX, posY, scale, an, scaleX, scaleY)
  if not (bounds) then
    return nil, boundsErr
  end
  local bordRaw = extractTag(tags, "bord")
  local shadRaw = extractTag(tags, "shad")
  local blurRaw = extractTag(tags, "blur")
  local bord = bordRaw ~= nil and finiteNumber(bordRaw) or (finiteNumber(style.outline) or 0)
  local shad = shadRaw ~= nil and finiteNumber(shadRaw) or (finiteNumber(style.shadow) or 0)
  local blur = blurRaw ~= nil and finiteNumber(blurRaw) or nil
  if (bordRaw ~= nil and not bord) or (shadRaw ~= nil and not shad) or (blurRaw ~= nil and not blur) then
    return nil, translate("err_unsupported_tags", "invalid numeric tag")
  end
  bord = formatNumber(bord)
  shad = formatNumber(shad)
  if blur ~= nil then blur = formatNumber(blur) end
  local scaleXTag = scaleXRaw ~= nil and formatNumber(scaleX) or nil
  local scaleYTag = scaleYRaw ~= nil and formatNumber(scaleY) or nil
  local alphaTags = extractAlphaTags(tags)
  return {
    tags = tags,
    drawing = drawing:match("^%s*(.-)%s*$"),
    p_scale = pScale,
    coord_scale = scale,
    coord_scale_x = scale * 100 / scaleX,
    coord_scale_y = scale * 100 / scaleY,
    pos_x = posX,
    pos_y = posY,
    color = color,
    rgb = rgb,
    lab = lab,
    an = tostring(an),
    bord = bord,
    shad = shad,
    blur = blur,
    scale_x_tag = scaleXTag,
    scale_y_tag = scaleYTag,
    alpha_tags = alphaTags,
    visual_tags = visualTags,
    bounds = bounds,
    visual_key = table.concat({
      tostring(pScale),
      an,
      bord,
      shad,
      blur or "",
      formatNumber(scaleX),
      formatNumber(scaleY),
      alphaTags,
      visualTags
    }, "|")
  }
end
local lineKey
lineKey = function(line)
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
    line.comment and "1" or "0"
  }
  for index = 1, #fields do fields[index] = tostring(fields[index]) end
  return table.concat(fields, "\31")
end
local collectItems
collectItems = function(subs, sel)
  if type(sel) ~= "table" then
    return nil, translate("err_two_shapes")
  end
  local sorted = LineOps.normalizeIndices(subs, sel)
  if #sorted < 2 then return nil, translate("err_two_shapes") end
  for i = 2, #sorted do
    if sorted[i] ~= sorted[i - 1] + 1 then
      return nil, translate("err_contiguous")
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
  local commonKey = nil
  for _, index in ipairs(sorted) do
    local line = subs[index]
    if not (line and line.class == "dialogue") then
      return nil, translate("err_not_dialogue", index)
    end
    local style = line.styleref or line.styleRef or line.style_ref or styles[line.style]
    local parsed, err = parseShapeLine(line.text, style)
    if not (parsed) then
      return nil, translate("err_line", index, err)
    end
    local key = lineKey(line)
    if not (commonKey) then
      commonKey = key
    end
    if key ~= commonKey then
      return nil, translate("err_mixed")
    end
    parsed.index = index
    parsed.line = line
    parsed.weight = math.max(1, parsed.bounds.area)
    items[#items + 1] = parsed
  end
  return items
end
local uniqueColorCount
uniqueColorCount = function(items)
  local seen, count = { }, 0
  for index0 = 1, #items do
    local item = items[index0]
    local key = tostring(item.color) .. "\31" .. tostring(item.visual_key)
    if not (seen[key]) then
      seen[key] = true
      count = count + 1
    end
  end
  return count
end
local averageColor
averageColor = function(items)
  local total, r, g, b = 0, 0, 0, 0
  for index0 = 1, #items do
    local item = items[index0]
    local w = item.weight or 1
    total = total + w
    r = r + (item.rgb.r * w)
    g = g + (item.rgb.g * w)
    b = b + (item.rgb.b * w)
  end
  if total <= 0 then
    total = 1
  end
  return rgbToAss(r / total, g / total, b / total)
end
local offsetDrawing
offsetDrawing = function(drawing, dx, dy)
  local out, isX = { }, true
  for token in tostring(drawing or ""):gmatch("%S+") do
    local n = tonumber(token)
    if n then
      local value = n + (isX and dx or dy)
      out[#out + 1] = formatNumber(value)
      isX = not isX
    else
      out[#out + 1] = token
    end
  end
  return table.concat(out, " ")
end
local mergedText
mergedText = function(items, color)
  local first = items[1]
  local baseX, baseY = first.bounds.left, first.bounds.top
  for index0 = 1, #items do
    local item = items[index0]
    if item.bounds.left < baseX then
      baseX = item.bounds.left
    end
    if item.bounds.top < baseY then
      baseY = item.bounds.top
    end
  end
  local drawings = { }
  for index0 = 1, #items do
    local item = items[index0]
    local dx = (item.bounds.origin_x - baseX) * item.coord_scale_x
    local dy = (item.bounds.origin_y - baseY) * item.coord_scale_y
    drawings[#drawings + 1] = offsetDrawing(item.drawing, dx, dy)
  end
  return "{\\an7\\pos(" .. tostring(formatNumber(baseX)) .. "," .. tostring(formatNumber(baseY)) .. ")\\p" .. tostring(first.p_scale) .. "\\1c" .. tostring(color) .. tostring(first.visual_tags or "") .. "}" .. tostring(table.concat(drawings, " ")) .. "{\\p0}"
end
local newCluster
newCluster = function(item)
  local cluster = {
    items = { },
    total = 0,
    r = 0,
    g = 0,
    b = 0,
    first_index = item.index or 0,
    visual_key = item.visual_key,
    color = item.color,
    lab = item.lab
  }
  return cluster
end
local addToCluster
addToCluster = function(cluster, item)
  cluster.items[#cluster.items + 1] = item
  local w = item.weight or 1
  cluster.total = cluster.total + w
  cluster.r = cluster.r + (item.rgb.r * w)
  cluster.g = cluster.g + (item.rgb.g * w)
  cluster.b = cluster.b + (item.rgb.b * w)
  if item.index and item.index < cluster.first_index then
    cluster.first_index = item.index
  end
  cluster.color = rgbToAss(cluster.r / cluster.total, cluster.g / cluster.total, cluster.b / cluster.total)
  cluster.lab = colorToOklab(cluster.color)
end
local clusterAccepts
clusterAccepts = function(cluster, item, threshold)
  if cluster.visual_key ~= item.visual_key then return false end
  local weight = item.weight or 1
  local total = cluster.total + weight
  if total <= 0 then return false end
  local color = rgbToAss(
    (cluster.r + item.rgb.r * weight) / total,
    (cluster.g + item.rgb.g * weight) / total,
    (cluster.b + item.rgb.b * weight) / total
  )
  local lab = colorToOklab(color)
  if deltaLab(item.lab, lab) > threshold + epsilon then return false end
  for _, existing in ipairs(cluster.items) do
    if deltaLab(existing.lab, lab) > threshold + epsilon then return false end
  end
  return true
end
local similarOptimize
similarOptimize = function(items, opts)
  local clusters = { }
  for index0 = 1, #items do
    local item = items[index0]
    local best, bestDelta = nil, 999
    for index1 = 1, #clusters do
      local cluster = clusters[index1]
      local delta = deltaLab(item.lab, cluster.lab)
      if cluster.visual_key == item.visual_key and delta < bestDelta and delta <= opts.threshold and clusterAccepts(cluster, item, opts.threshold) then
        best, bestDelta = cluster, delta
      end
    end
    if best then
      addToCluster(best, item)
    else
      local cluster = newCluster(item)
      addToCluster(cluster, item)
      clusters[#clusters + 1] = cluster
    end
  end
  table.sort(clusters, function(a, b)
    return a.first_index < b.first_index
  end)
  local texts = { }
  for index0 = 1, #clusters do
    local cluster = clusters[index0]
    table.sort(cluster.items, function(a, b)
      return a.index < b.index
    end)
    texts[#texts + 1] = mergedText(cluster.items, cluster.color)
  end
  return {
    mode = "Similar colors",
    texts = texts,
    colors_after = #clusters,
    details = translate("detail_threshold", opts.threshold)
  }
end
local projectionValue
projectionValue = function(item, axis)
  if axis == "Vertical" then
    return item.bounds.center_y
  else
    return item.bounds.center_x
  end
end
local gradientScore
gradientScore = function(items, axis)
  local minP, maxP = nil, nil
  local sorted
  do
    local accumulator0 = { }
    local length0 = 1
    for index0 = 1, #items do
      local item = items[index0]
      accumulator0[length0] = item
      length0 = length0 + 1
    end
    sorted = accumulator0
  end
  table.sort(sorted, function(a, b)
    return projectionValue(a, axis) < projectionValue(b, axis)
  end)
  for index0 = 1, #sorted do
    local item = sorted[index0]
    local p = projectionValue(item, axis)
    if not minP or p < minP then
      minP = p
    end
    if not maxP or p > maxP then
      maxP = p
    end
  end
  local span = (maxP or 0) - (minP or 0)
  if span < epsilon then
    return nil
  end
  local first, last = sorted[1], sorted[#sorted]
  local endpointDelta = deltaLab(first.lab, last.lab)
  if endpointDelta < minGradientEndpointDelta then
    return nil
  end
  local totalW, totalErr, maxErr = 0, 0, 0
  for index0 = 1, #sorted do
    local item = sorted[index0]
    local t = (projectionValue(item, axis) - minP) / span
    local predicted = {
      l = first.lab.l + (last.lab.l - first.lab.l) * t,
      a = first.lab.a + (last.lab.a - first.lab.a) * t,
      b = first.lab.b + (last.lab.b - first.lab.b) * t
    }
    local err = deltaLab(item.lab, predicted)
    local w = item.weight or 1
    totalW = totalW + w
    totalErr = totalErr + (err * w)
    if err > maxErr then
      maxErr = err
    end
  end
  return {
    axis = axis,
    sorted = sorted,
    avg_err = totalErr / math.max(1, totalW),
    max_err = maxErr,
    endpoint_delta = endpointDelta,
    span = span
  }
end
local detectGradient
detectGradient = function(items, opts)
  if #items < minGradientItems then
    return nil
  end
  local horizontal = gradientScore(items, "Horizontal")
  local vertical = gradientScore(items, "Vertical")
  local best = horizontal
  if vertical and (not best or vertical.avg_err < best.avg_err) then
    best = vertical
  end
  if not (best) then
    return nil
  end
  local avgLimit = math.max(minGradientAverageLimit, opts.threshold * gradientAverageFactor)
  local maxLimit = math.max(minGradientMaxLimit, opts.threshold * gradientMaxFactor)
  if best.avg_err > avgLimit or best.max_err > maxLimit then
    return nil
  end
  return best
end
local gradientOptimize
gradientOptimize = function(items, opts)
  local visualKey = items[1] and items[1].visual_key
  for index = 2, #items do
    if items[index].visual_key ~= visualKey then
      return nil, translate("no_gradient")
    end
  end
  local score = detectGradient(items, opts)
  if not (score) then
    return nil, translate("no_gradient")
  end
  local targetBands = math.min(opts.max_bands, #items)
  if targetBands >= #items then
    return nil, translate("gradient_within_target")
  end
  local bands
  do
    local accumulator0 = { }
    local length0 = 1
    for _ = 1, targetBands do
      accumulator0[length0] = { }
      length0 = length0 + 1
    end
    bands = accumulator0
  end
  for rank, item in ipairs(score.sorted) do
    local band = math.floor((rank - 1) * targetBands / #score.sorted) + 1
    bands[band][#bands[band] + 1] = item
  end
  local texts, usedBands = { }, 0
  for index0 = 1, #bands do
    local bandItems = bands[index0]
    if #bandItems > 0 then
      usedBands = usedBands + 1
      texts[#texts + 1] = mergedText(bandItems, averageColor(bandItems))
    end
  end
  return {
    mode = "Full gradient",
    texts = texts,
    colors_after = usedBands,
    details = translate("detail_gradient", translate(score.axis == "Vertical" and "axis_vertical" or "axis_horizontal"), score.avg_err)
  }
end
local optimizeItems
optimizeItems = function(items, opts)
  if opts == nil then
    opts = { }
  end
  opts = normalizeOptions(opts)
  local result, err
  if opts.mode == "Auto" then
    result = gradientOptimize(items, opts)
    if not result or #result.texts >= #items then
      result = similarOptimize(items, opts)
      result.mode = "Auto -> " .. result.mode
    end
  elseif opts.mode == "Full gradient" then
    result, err = gradientOptimize(items, opts)
    if not (result) then
      result = similarOptimize(items, opts)
      result.mode = "Full gradient -> Similar colors"
      if err then
        result.details = result.details .. translate("detail_fallback", err)
      end
    end
  else
    result = similarOptimize(items, opts)
  end
  if not (result and result.texts and #result.texts > 0) then
    return nil, translate("err_no_output")
  end
  return result
end
local analyzeSelection
analyzeSelection = function(subs, sel, opts)
  if opts == nil then
    opts = { }
  end
  opts = normalizeOptions(opts)
  local items, err = collectItems(subs, sel)
  if not (items) then
    return nil, err
  end
  local result, optErr = optimizeItems(items, opts)
  if not (result) then
    return nil, optErr
  end
  local charsBefore = 0
  for index0 = 1, #items do
    local item = items[index0]
    charsBefore = charsBefore + #(item.line.text or "")
  end
  local charsAfter = 0
  local list0 = result.texts
  for index0 = 1, #list0 do
    local text = list0[index0]
    charsAfter = charsAfter + #text
  end
  local beforeLines = #items
  local afterLines = #result.texts
  local beforeColors = uniqueColorCount(items)
  local afterColors = result.colors_after or beforeColors
  local changed = afterLines ~= beforeLines
  if not changed then
    for index = 1, beforeLines do
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
    before_lines = beforeLines,
    after_lines = afterLines,
    before_colors = beforeColors,
    after_colors = afterColors,
    chars_before = charsBefore,
    chars_after = charsAfter,
    changed = changed
  }
end
local summaryText
summaryText = function(report)
  local mode = report.mode
  if mode == "Auto -> Similar colors" then
    mode = tostring(translate(modeKeys.Auto)) .. " -> " .. tostring(translate(modeKeys["Similar colors"]))
  elseif mode == "Full gradient -> Similar colors" then
    mode = tostring(translate(modeKeys["Full gradient"])) .. " -> " .. tostring(translate(modeKeys["Similar colors"]))
  elseif modeKeys[mode] then
    mode = translate(modeKeys[mode])
  end
  local lines = {
    currentTitle or translate("title"),
    "",
    translate("summary_mode", mode),
    translate("summary_detail", report.details or ""),
    "",
    translate("summary_lines", report.before_lines, report.after_lines),
    translate("summary_colors", report.before_colors, report.after_colors),
    translate("summary_characters", report.chars_before, report.chars_after)
  }
  return table.concat(lines, "\n")
end
local applyReport
applyReport = function(subs, selectionOrReport, report)
  report = report or selectionOrReport
  local sorted = { }
  for _, item in ipairs(report.items or {}) do sorted[#sorted + 1] = item.index end
  table.sort(sorted)
  local firstIndex = sorted[1]
  local template = report.items[1].line
  for i = #sorted, 1, -1 do
    subs.delete(sorted[i])
  end
  local lines = { }
  for i, text in ipairs(report.texts) do
    local newLine = copyLine(template)
    newLine.text = text
    lines[i] = newLine
  end
  return LineOps.insertLines(subs, { { index = firstIndex, lines = lines } })
end
local localizedValues
localizedValues = function(values, keys)
  local items, fromLabel, toLabel = { }, { }, { }
  for index0 = 1, #values do
    local value = values[index0]
    local label = translate(keys[value])
    items[#items + 1] = label
    fromLabel[label] = value
    toLabel[value] = label
  end
  return items, fromLabel, toLabel
end
local buildDialog
buildDialog = function(saved)
  local modeItems, modeFromLabel, modeToLabel = localizedValues(modes, modeKeys)
  local intensityItems, intensityFromLabel, intensityToLabel = localizedValues(intensities, intensityKeys)
  local dialog = {
    {
      class = "label",
      label = translate("mode"),
      x = 0,
      y = 0,
      width = 3,
      height = 1
    },
    {
      class = "dropdown",
      name = "mode",
      items = modeItems,
      value = modeToLabel[saved.mode] or modeItems[1],
      x = 3,
      y = 0,
      width = 6,
      height = 1
    },
    {
      class = "label",
      label = translate("intensity"),
      x = 0,
      y = 1,
      width = 3,
      height = 1
    },
    {
      class = "dropdown",
      name = "intensity",
      items = intensityItems,
      value = intensityToLabel[saved.intensity] or intensityItems[1],
      x = 3,
      y = 1,
      width = 6,
      height = 1
    },
    {
      class = "label",
      label = translate("threshold"),
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
      max = maxThreshold,
      step = minThreshold,
      x = 4,
      y = 2,
      width = 3,
      height = 1
    },
    {
      class = "label",
      label = translate("max_bands"),
      x = 0,
      y = 3,
      width = 3,
      height = 1
    },
    {
      class = "intedit",
      name = "max_bands",
      value = saved.max_bands,
      min = minBands,
      x = 3,
      y = 3,
      width = 3,
      height = 1
    },
    {
      class = "checkbox",
      name = "show_summary",
      label = translate("show_summary"),
      value = saved.show_summary,
      x = 0,
      y = 4,
      width = 9,
      height = 1
    }
  }
  return dialog, {
    mode = modeFromLabel,
    intensity = intensityFromLabel
  }
end
local function setLanguage(language)
  if languages[language] then currentLang = language else currentLang = "en" end
  return currentLang
end

local function commitUndo(context)
  local name = context.undo_name or currentTitle or translate("title")
  if type(context.undo) == "function" then
    context.undo(context.undo_key or "tool_undo_shape_optimizer", name)
  elseif aegisub and type(aegisub.set_undo_point) == "function" then
    aegisub.set_undo_point(name)
  end
end

local function main(subs, sel, _, context)
  context = context or {}
  setLanguage(context.language)
  currentTitle = context.title or translate("title")
  if not (sel and #sel >= 2) then cancelWith(translate("err_two_shapes")) end
  local settings = settingsFor(context)
  local dialogSpec, maps = buildDialog(settings:values("main"))
  local execute, cancel = translate("execute"), translate("cancel")
  local button, result = aegisub.dialog.display(dialogSpec, {execute, cancel}, {ok = execute, close = cancel})
  if button ~= execute then return sel end
  result.mode = maps.mode[result.mode] or "Auto"
  result.intensity = maps.intensity[result.intensity] or "Balanced"
  settings:update("main", result)
  settings:write()
  local options = normalizeOptions(result)
  local report, err = analyzeSelection(subs, sel, options)
  if not report then cancelWith(err) end
  if not report.changed then
    showMessage(tostring(translate("no_reduction")) .. "\n\n" .. tostring(summaryText(report)))
    return sel
  end
  if options.show_summary then
    local confirm = aegisub.dialog.display({
      {class = "textbox", value = summaryText(report) .. "\n\n" .. translate("confirm_apply"), x = 0, y = 0, width = 56, height = 10}
    }, {execute, cancel}, {ok = execute, close = cancel})
    if confirm ~= execute then return sel end
  end
  local newSelection = LineOps.transaction(subs, "", function()
    return applyReport(subs, report)
  end)
  commitUndo(context)
  if not context.silent then showMessage(summaryText(report)) end
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

ShapeOptimizer.languages = languages
ShapeOptimizer.modes = modes
ShapeOptimizer.intensities = intensities
ShapeOptimizer.setLanguage = setLanguage
ShapeOptimizer.normalizeOptions = normalizeOptions
ShapeOptimizer.parseLine = parseShapeLine
ShapeOptimizer.collectItems = collectItems
ShapeOptimizer.optimizeItems = optimizeItems
ShapeOptimizer.analyzeSelection = analyzeSelection
ShapeOptimizer.applyReport = applyReport
ShapeOptimizer.summaryText = summaryText
ShapeOptimizer.main = main
ShapeOptimizer.validate = validate
ShapeOptimizer.geometry = Geometry

if depctrl then
  ShapeOptimizer.version = depctrl
  return depctrl:register(ShapeOptimizer)
end
return ShapeOptimizer
