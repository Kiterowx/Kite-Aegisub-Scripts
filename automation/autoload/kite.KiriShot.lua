local function initializeScript()
script_name = "Kiri-Shot"
script_description = "Capturas PNG, secuencias, máscaras ASS y vídeo social en un mismo flujo"
script_author = "Kiterow"
script_version = "1.0.0"
script_namespace = "kite.KiriShot"

package.preload["Yutils"] = function() return require("tstools.Yutils") end
local DependencyControl = require("l0.DependencyControl")
local feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
local depctrl = DependencyControl {
    feed = feed,
    {
        {"tstools.Yutils", version="1.0.0", feed="https://raw.githubusercontent.com/TypesettingTools/Yutils/master/DependencyControl.json"},
        {"a-mo.LineCollection", version="1.3.0", feed="https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"},
        {"kite.UI", version="2.0.3", feed=feed},
        {"l0.ASSFoundation", version="0.5.0", feed="https://raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json"},
        {"kite.Core", version="2.0.0", feed=feed},
        {"kite.PyBridge", version="2.0.1", feed=feed},
        {"kite.ShapeOptimizer", version="2.0.1", feed=feed},
        {"kite.AssContext", version="2.0.1", feed=feed},
        {"myaa.ASSParser", version="0.0.4", feed="https://raw.githubusercontent.com/TypesettingTools/Myaamori-Aegisub-Scripts/master/DependencyControl.json"},
    }
}
local _, LineCollection, KiteUI, ASS, Core, PyBridge, ShapeOptimizer, AssContext, ASSParser = depctrl:requireModules()
local LineOps, Media, AssDrawing = Core.LineOps, PyBridge.Media, ShapeOptimizer.AssDrawing
local trim, finiteNumber = Core.trim, Core.finiteNumber

local function choiceOrDefault(value, items, fallback)
    for _, item in ipairs(items) do if value == item then return item end end
    return fallback
end

local function baseName(path)
    local name = tostring(path or ""):match("([^\\/]+)$") or tostring(path or "")
    return (name:gsub("%.[^%.]*$", ""))
end

local function safeName(value, fallback)
    local name = trim(value):gsub('[%z\1-\31\\/:*?"<>|]+', '_'):gsub('%s+', '_')
    name = name:gsub('_+', '_'):gsub('^_+', ''):gsub('_+$', ''):gsub('[%.%s]+$', '')
    local lower = name:lower():match('^[^%.]+') or ''
    if name == '' or name:match('^%.+$') or lower == 'con' or lower == 'prn' or lower == 'aux'
        or lower == 'nul' or lower:match('^com[1-9]$') or lower:match('^lpt[1-9]$') then
        return fallback or 'kiri-shot'
    end
    return name
end

local function decodedPath(spec) return Media.decodedPath(spec) or '' end
local function videoPath()
    local path = decodedPath('?video')
    if path ~= '' and PyBridge.fileExists(path) then return path end
    path = Media.projectProperties().video_file or ''
    if path ~= '' and PyBridge.fileExists(path) then return path end
end
local function projectFolder(video)
    local folder = LineOps.subtitleFolder() or ''
    if folder ~= '' then return folder end
    folder = decodedPath('?script')
    if folder ~= '' then return folder end
    return PyBridge.parentPath(video) or ''
end
local function videoSize()
    if not aegisub.video_size then return 0, 0 end
    local ok, w, h = pcall(aegisub.video_size)
    if not ok then return 0, 0 end
    return tonumber(w) or 0, tonumber(h) or 0
end
local function filterPathQuote(value)
    return Media.filterPath(Media.filterPath(tostring(value or ''):gsub('\\', '/')))
end
local function ffmpegExecutable(value)
    local executable = trim(value)
    if executable:match('^".*"$') or executable:match("^'.*'$") then executable = executable:sub(2, -2) end
    return executable ~= '' and executable or 'ffmpeg'
end
local function showMessage(message, title)
    return KiteUI.message(message, {title=title or script_name})
end

local Social = (function()
local maskEffect = "Kite Social Mask"
local previewEffect = "Kite Social Y Preview"
local centerExtra = "_kite_socialclip_centered"
local isWindows = PyBridge.isWindows
local coordinateTolerance = 0.001
local trajectoryErrorTolerance = 0.25

local presets = {
    ["TikTok / Reels - 1080x1920 (9:16)"] = {w = 1080, h = 1920, suffix = "9x16"},
    ["Vertical HD - 720x1280 (9:16)"] = {w = 720, h = 1280, suffix = "9x16_720p"},
    ["Instagram Feed - 1080x1350 (4:5)"] = {w = 1080, h = 1350, suffix = "4x5"}
}

local presetItems = {
    "TikTok / Reels - 1080x1920 (9:16)",
    "Vertical HD - 720x1280 (9:16)",
    "Instagram Feed - 1080x1350 (4:5)",
    "Personalizado"
}

local fpsItems = {"Origen", "30", "60"}
local aspectItems = {"Expandir al formato", "Exigir la misma relación"}
local x264Presets = {"veryfast", "faster", "fast", "medium", "slow"}
local audioBitrates = {"128k", "192k", "256k"}
local outputProfileItems = {
    "MP4 · pegados y adaptados",
    "MP4 · pegados exactos",
    "MKV · diálogo ASS flotante"
}
local outputProfiles = {
    [outputProfileItems[1]] = {extension = ".mp4", burnDialogue = true, softDialogue = false},
    [outputProfileItems[2]] = {extension = ".mp4", burnDialogue = false, softDialogue = false, exactAll = true},
    [outputProfileItems[3]] = {extension = ".mkv", burnDialogue = false, softDialogue = true}
}

local clamp = Core.clamp
local round = Core.roundTo
local fileExists = PyBridge.fileExists
local writeFile = PyBridge.writeFile
local joinPath = PyBridge.joinPath
local frameFromMs = Media.frameFromMs
local msFromFrame = Media.msFromFrame

local function shallowCopy(source)
    return Core.copy(type(source) == "table" and source or {})
end

local function finitePositive(value)
    value = Core.finiteNumber(value)
    if value and value > 0 then return value end
    return nil
end

local formatNumber = Core.formatNumber

local function evenFloor(value)
    return math.max(2, math.floor((tonumber(value) or 0) / 2) * 2)
end

local function evenCeil(value)
    return math.max(2, math.ceil((tonumber(value) or 0) / 2) * 2)
end

local function evenNearest(value, limit)
    local result = math.max(2, math.floor((tonumber(value) or 0) / 2 + 0.5) * 2)
    if limit and result > limit then result = evenFloor(limit) end
    return result
end

local function resolveOutputProfile(cfg)
    local name = choiceOrDefault(cfg and cfg.outputProfile, outputProfileItems, outputProfileItems[1])
    return outputProfiles[name], name
end

local function dirName(path)
    return PyBridge.parentPath(path) or ""
end

local function replaceExtension(path, extension)
    local stem = tostring(path or ""):gsub("%.[^%.\\/]+$", "")
    return stem .. extension
end

local function comparablePath(path)
    path = trim(path)
    if not isWindows then return path:gsub("/+$", "") end
    path = path:gsub("/", "\\"):gsub("^\\\\%?\\", "")
    local prefix, rest = "", path
    if path:match("^%a:\\") then
        prefix, rest = path:sub(1, 3), path:sub(4)
    elseif path:sub(1, 2) == "\\\\" then
        prefix, rest = "\\\\", path:sub(3)
    end
    local parts = {}
    for part in rest:gmatch("[^\\]+") do
        if part == ".." and #parts > 0 and parts[#parts] ~= ".." then
            table.remove(parts)
        elseif part ~= "." and part ~= "" then
            parts[#parts + 1] = part
        end
    end
    return (prefix .. table.concat(parts, "\\")):gsub("\\+$", ""):lower()
end

local function samePath(left, right)
    return comparablePath(left) == comparablePath(right)
end

local projectProperties = Media.projectProperties

local function activeScriptPath()
    local props = projectProperties()
    for _, key in ipairs({"filename", "script_file"}) do
        local path = tostring(props[key] or "")
        if path ~= "" then return path end
    end
    if aegisub and aegisub.file_name then
        local ok, name = pcall(aegisub.file_name)
        local folder = decodedPath("?script")
        if ok and name and folder ~= "" then return joinPath(folder, name) end
    end
    return ""
end

local function confirmOverwrite(path)
    if not fileExists(path) then return true end
    local button = aegisub.dialog.display({
        {class = "label", label = "El archivo ya existe:", x = 0, y = 0, width = 48, height = 1},
        {class = "label", label = tostring(path), x = 0, y = 1, width = 48, height = 3},
        {class = "label", label = "¿Quieres sobrescribirlo?", x = 0, y = 4, width = 48, height = 1}
    }, {"Sobrescribir", "Cancelar"}, {ok = "Sobrescribir", close = "Cancelar"})
    return button == "Sobrescribir"
end

local function processCommand(executable, arguments, fallback)
    executable = trim(executable)
    if executable == "" then executable = fallback end
    if executable:match('^".*"$') or executable:match("^'.*'$" ) then executable = executable:sub(2, -2) end
    return {executable = executable, args = arguments}
end

local function nextTempBase(folder, label)
    return joinPath(folder, "_socialclip_" .. safeName(label, "run") .. "_" .. PyBridge.uniqueSuffix())
end

local function normalizeOutputDimensions(cfg)
    local preset = presets[cfg.preset]
    local width = preset and preset.w or finitePositive(cfg.customW)
    local height = preset and preset.h or finitePositive(cfg.customH)
    if not width or not height then return nil, nil, "La resolución de salida debe contener valores positivos y finitos." end
    width, height = evenNearest(width), evenNearest(height)
    if width < 2 or height < 2 then return nil, nil, "La resolución de salida debe ser mayor que cero." end
    return width, height, preset and preset.suffix or (tostring(width) .. "x" .. tostring(height))
end

local function overlapMidpointFrame(previous, current, frameToMs, msToFrame)
    local low, high = previous.startFrame + 1, current.endFrame - 1
    if frameToMs and msToFrame then
        local startMs = frameToMs(current.startFrame)
        local endMs = frameToMs(previous.endFrame)
        if startMs and endMs and endMs > startMs then
            local target = (startMs + endMs) / 2
            local raw = msToFrame(target)
            local best, bestDistance
            for _, candidate in ipairs({raw, raw and raw + 1 or nil}) do
                if candidate and candidate >= low and candidate <= high then
                    local boundaryMs = frameToMs(candidate)
                    if boundaryMs then
                        local distance = math.abs(boundaryMs - target)
                        if not bestDistance or distance < bestDistance then
                            best, bestDistance = candidate, distance
                        end
                    end
                end
            end
            if best then return best end
        end
    end
    return clamp(math.floor((current.startFrame + previous.endFrame) / 2), low, high)
end

local function normalizeScenes(rawScenes, frameToMs, msToFrame)
    local scenes = {}
    for _, source in ipairs(rawScenes or {}) do
        local scene = shallowCopy(source)
        scene.originalStartFrame = source.startFrame
        scene.originalEndFrame = source.endFrame
        if not Core.finiteNumber(scene.startFrame) or not Core.finiteNumber(scene.endFrame)
            or scene.startFrame ~= math.floor(scene.startFrame) or scene.endFrame ~= math.floor(scene.endFrame)
            or scene.endFrame <= scene.startFrame then
            return nil, "Hay una máscara sin duración útil."
        end
        scenes[#scenes + 1] = scene
    end
    table.sort(scenes, function(a, b)
        if a.startFrame == b.startFrame then
            if a.endFrame == b.endFrame then return (a.index or 0) < (b.index or 0) end
            return a.endFrame < b.endFrame
        end
        return a.startFrame < b.startFrame
    end)

    local active = {}
    for _, scene in ipairs(scenes) do
        LineOps.checkCancelled()
        for i = #active, 1, -1 do
            if active[i].originalEndFrame <= scene.originalStartFrame then table.remove(active, i) end
        end
        if #active >= 2 then
            return nil, "Hay un solape triple entre máscaras; no existe una mitad única para repartirlo."
        end
        if #active == 1 and scene.originalEndFrame <= active[1].originalEndFrame then
            return nil, "Hay una máscara anidada dentro de otra; divide esas escenas antes de exportar."
        end
        active[#active + 1] = scene
    end

    local overlaps = 0
    for i = 2, #scenes do
        local previous, current = scenes[i - 1], scenes[i]
        if current.startFrame < previous.endFrame then
            local boundary = overlapMidpointFrame(previous, current, frameToMs, msToFrame)
            if boundary <= previous.startFrame or boundary >= current.endFrame then
                return nil, "Un solape deja una escena sin cuadros útiles."
            end
            previous.endFrame = boundary
            current.startFrame = boundary
            overlaps = overlaps + 1
        end
    end

    for _, scene in ipairs(scenes) do
        if scene.endFrame <= scene.startFrame then return nil, "Una escena quedó vacía al repartir los solapes." end
    end
    return scenes, nil, overlaps
end

local function materializeTimeline(scenes, frameToMs)
    local outputCursor = 0
    local gaps = 0
    for i, scene in ipairs(scenes) do
        LineOps.checkCancelled()
        scene.startMs = Core.finiteNumber(frameToMs(scene.startFrame))
        scene.endMs = Core.finiteNumber(frameToMs(scene.endFrame))
        if not scene.startMs or not scene.endMs then return nil, "No se pudo convertir el tiempo de escena." end
        scene.durationMs = scene.endMs - scene.startMs
        if scene.durationMs <= 0 then return nil, "Una escena no tiene duración temporal útil." end
        scene.outputStartMs = outputCursor
        scene.outputEndMs = outputCursor + scene.durationMs
        outputCursor = scene.outputEndMs
        if i > 1 and scene.startFrame > scenes[i - 1].endFrame then gaps = gaps + 1 end
    end
    return {durationMs = outputCursor, gaps = gaps}
end

local function resolveCropSize(maskW, maskH, targetRatio, aspectMode, videoW, videoH)
    maskW, maskH = finitePositive(maskW), finitePositive(maskH)
    if not maskW or not maskH then
        return nil, nil, "La máscara no tiene una caja visible válida."
    end
    local ratioError = math.abs(maskW / maskH - targetRatio) / targetRatio
    local cropW, cropH
    if ratioError <= 0.01 then
        cropW, cropH = evenNearest(maskW), evenNearest(maskH)
    elseif aspectMode == "Exigir la misma relación" then
        return nil, nil, string.format("La máscara tiene relación %.4f y la salida requiere %.4f.", maskW / maskH, targetRatio)
    elseif maskW / maskH > targetRatio then
        cropW, cropH = evenCeil(maskW), evenCeil(maskW / targetRatio)
    else
        cropH, cropW = evenCeil(maskH), evenCeil(maskH * targetRatio)
    end
    if cropW > videoW or cropH > videoH then
        return nil, nil, string.format("El recorte calculado (%dx%d) no cabe en el vídeo (%dx%d).", cropW, cropH, videoW, videoH)
    end
    return cropW, cropH
end

local function compressTrajectory(points)
    local compressed, previous = {}, nil
    for _, point in ipairs(points or {}) do
        if not previous or math.abs(point.x - previous.x) >= coordinateTolerance or math.abs(point.y - previous.y) >= coordinateTolerance then
            compressed[#compressed + 1] = point
            previous = point
        end
    end
    return compressed
end

local function trajectoryCommands(scene, filterId, frameToMs)
    local points = scene.trajectory or {}
    if #points <= 1 then return "" end
    local rows = {}
    local previous = points[1]
    for i = 2, #points do
        local point = points[i]
        local seconds = math.max(0, (frameToMs(point.frame) - scene.startMs) / 1000)
        local commands = {}
        if math.abs(point.x - previous.x) >= coordinateTolerance then
            commands[#commands + 1] = string.format("[enter] crop@crop%d x %s", filterId, formatNumber(point.x, 3))
        end
        if math.abs(point.y - previous.y) >= coordinateTolerance then
            commands[#commands + 1] = string.format("[enter] crop@crop%d y %s", filterId, formatNumber(point.y, 3))
        end
        if #commands > 0 then rows[#rows + 1] = string.format("%.6f %s;", seconds, table.concat(commands, ",")) end
        previous = point
    end
    return table.concat(rows, "\n")
end

local scriptResolution = LineOps.scriptResolution

local function drawingContentState(text)
    local hasDrawing, hasOutside = false, false
    for _, section in ipairs(LineOps.scanSections(text)) do
        if trim(section.text) ~= "" then
            if section.type == "drawing" then hasDrawing = true
            elseif section.type == "text" then hasOutside = true end
        end
    end
    return hasDrawing, hasOutside
end

local function hasVectorDrawing(text)
    return (drawingContentState(text))
end

local function forceMaskBlock(block)
    if not tostring(block):match("^%{%s*\\") then return block end
    local body = LineOps.mapTagCalls(block, {"fad", "fade", "alpha", "1a", "2a", "3a", "4a",
        "c", "1c", "2c", "3c", "4c", "bord", "xbord", "ybord", "shad", "xshad", "yshad", "blur", "be"},
        function() return false end, {top_level_only = false})
    body = LineOps.mapTagCalls(body, "t", function(call)
        if not call.value:find("\\", 1, true) then return false end
    end)
    return body:sub(1, -2) .. "\\1c&HFFFFFF&\\2c&HFFFFFF&\\3c&HFFFFFF&\\4c&HFFFFFF&\\alpha&H00&\\bord0\\shad0\\blur0\\be0}"
end

local function opaqueMaskText(text)
    local chunks = {}
    for _, section in ipairs(LineOps.scanSections(text)) do
        if section.type == "override" then chunks[#chunks + 1] = forceMaskBlock("{" .. section.text .. "}")
        elseif section.type == "comment" then chunks[#chunks + 1] = "{" .. section.text .. "}"
        else chunks[#chunks + 1] = section.text end
    end
    return table.concat(chunks)
end

local function collectMaskLines(subs, selection)
    local indices, impure = {}, 0
    for _, index in ipairs(LineOps.normalizeIndices(subs, selection)) do
        local line = subs[index]
        if line and line.class == "dialogue" and not line.comment and line.end_time > line.start_time then
            local drawing, outside = drawingContentState(line.text)
            if drawing and not outside then indices[#indices + 1] = index
            elseif drawing and outside then impure = impure + 1 end
        end
    end
    if #indices == 0 and impure > 0 then
        return nil, "Una máscara seleccionada mezcla dibujo \\p con texto visible. Deja únicamente el dibujo vectorial."
    end
    local source = "selección"
    if #indices == 0 then
        source = "efecto"
        for i = 1, #subs do
        LineOps.checkCancelled()
            local line = subs[i]
            if line and line.class == "dialogue" and not line.comment and line.end_time > line.start_time and tostring(line.effect or "") == maskEffect then
                local drawing, outside = drawingContentState(line.text)
                if drawing and not outside then indices[#indices + 1] = i
                elseif drawing and outside then impure = impure + 1 end
            end
        end
        if #indices == 0 then
            source = "vista Y"
            for i = 1, #subs do
        LineOps.checkCancelled()
                local line = subs[i]
                if line and line.class == "dialogue" and not line.comment and line.end_time > line.start_time
                    and tostring(line.effect or "") == previewEffect then
                    local drawing, outside = drawingContentState(line.text)
                    if drawing and not outside then indices[#indices + 1] = i
                    elseif drawing and outside then impure = impure + 1 end
                end
            end
        end
    end
    if #indices == 0 and impure > 0 then
        return nil, "Una línea de máscara o vista Y mezcla dibujo con texto visible."
    end
    if #indices == 0 then return nil, "Selecciona una o más líneas de máscara con dibujo \\p, o crea máscaras primero." end
    local collection = LineCollection(subs, indices, function(line)
        return line.class == "dialogue" and not line.comment and line.end_time > line.start_time
    end, true)
    local lines = {}
    for _, line in ipairs(collection.lines or {}) do
        if hasVectorDrawing(line.text) then lines[#lines + 1] = line end
    end
    table.sort(lines, function(a, b) return (a.number or 0) < (b.number or 0) end)
    if #lines == 0 then return nil, "No se pudo preparar ninguna máscara vectorial." end
    return {indices = indices, lines = lines, collection = collection, source = source}
end

local function createMasks(subs, selection, cfg, videoW, videoH, playX, playY)
    local sourceIndices = {}
    for _, index in ipairs(LineOps.normalizeIndices(subs, selection)) do
        local line = subs[index]
        if line and line.class == "dialogue" and not line.comment and line.end_time > line.start_time then
            sourceIndices[#sourceIndices + 1] = index
        end
    end
    if #sourceIndices == 0 then
        return nil, "Selecciona las líneas cuyos tiempos definirán las escenas."
    end

    local outW, outH, resolutionError = normalizeOutputDimensions(cfg)
    if not outW then return nil, resolutionError end
    local ratio = outW / outH
    local cropW, cropH, cropY
    if videoW / videoH >= ratio then
        cropH = evenFloor(videoH)
        cropW = evenNearest(cropH * ratio, videoW)
        cropY = (videoH - cropH) / 2
    else
        cropW = evenFloor(videoW)
        cropH = evenNearest(cropW / ratio, videoH)
        cropY = (videoH - cropH) / 2
    end
    local shapeW = cropW * playX / videoW
    local shapeH = cropH * playY / videoH
    local centerY = (cropY + cropH / 2) * playY / videoH
    local minCenterX, maxCenterX = shapeW / 2, playX - shapeW / 2
    if cfg.maskX1 < minCenterX - coordinateTolerance or cfg.maskX1 > maxCenterX + coordinateTolerance
        or cfg.maskX2 < minCenterX - coordinateTolerance or cfg.maskX2 > maxCenterX + coordinateTolerance then
        return nil, string.format("La X central válida para este formato va de %.2f a %.2f en PlayRes.", shapeW / 2, playX - shapeW / 2)
    end

    local positionTag
    if math.abs(cfg.maskX1 - cfg.maskX2) < coordinateTolerance then
        positionTag = string.format("\\pos(%s,%s)", formatNumber(cfg.maskX1, 3), formatNumber(centerY, 3))
    else
        positionTag = string.format("\\move(%s,%s,%s,%s)", formatNumber(cfg.maskX1, 3), formatNumber(centerY, 3),
            formatNumber(cfg.maskX2, 3), formatNumber(centerY, 3))
    end
    local alpha = string.format("%02X", cfg.maskAlpha)
    local drawing = string.format("m 0 0 l %s 0 %s %s 0 %s", formatNumber(shapeW, 3), formatNumber(shapeW, 3),
        formatNumber(shapeH, 3), formatNumber(shapeH, 3))
    local text = "{\\an5" .. positionTag .. "\\p1\\pbo0\\fscx100\\fscy100\\frz0\\frx0\\fry0\\fax0\\fay0\\bord2\\shad0\\blur0"
        .. "\\1c&H00D7FF&\\3c&HFFFFFF&\\1a&H" .. alpha .. "&\\3a&H20&}" .. drawing .. "{\\p0}"

    local maskLayer = 0
    for i = 1, #subs do
        if subs[i].class == "dialogue" then maskLayer = math.max(maskLayer, Core.finiteNumber(subs[i].layer) or 0) end
    end
    maskLayer = maskLayer + 1
    local newSelection = {}
    for _, index in ipairs(sourceIndices) do
        LineOps.checkCancelled()
        local source = subs[index]
        local line = shallowCopy(source)
        line.raw = nil
        line.comment = false
        line.layer = maskLayer
        line.actor = "SocialClip"
        line.effect = maskEffect
        line.text = text
        if subs.append then
            subs.append(line)
        else
            subs.insert(#subs + 1, line)
        end
        newSelection[#newSelection + 1] = #subs
    end
    aegisub.set_undo_point("Kiri-Shot - Crear máscaras")
    return newSelection, string.format("Se crearon %d máscara(s) de %.0fx%.0f PlayRes para una salida %dx%d.",
        #newSelection, shapeW, shapeH, outW, outH)
end

local function lastNumericTag(text, name)
    local call = LineOps.lastTagCall(text, name)
    return call and Core.finiteNumber(call.value)
end

local function parsePositionSpec(text)
    local spec
    for _, call in ipairs(LineOps.tagCalls(text, {"pos", "move"})) do
        if call.top_level then
            if spec then return nil, "contiene más de un \\pos/\\move" end
            local values, numbers = LineOps.splitArguments(call.value), {}
            local valid = call.value:match("^%b()$") and
                ((call.name == "pos" and #values == 2) or (call.name == "move" and (#values == 4 or #values == 6)))
            for i, raw in ipairs(values) do
                numbers[i] = Core.finiteNumber(raw)
                valid = valid and numbers[i] ~= nil
            end
            if not valid then return nil, "contiene un \\" .. call.name .. " inválido" end
            spec = {kind = call.name, values = values, numbers = numbers}
        end
    end
    return spec
end

local function simpleMaskPosition(text)
    local spec = parsePositionSpec(text)
    return spec and {kind = spec.kind, values = spec.numbers}
end

local function simpleDrawingBounds(text)
    local path
    for _, section in ipairs(LineOps.scanSections(text)) do
        if section.type == "drawing" and trim(section.text) ~= "" then
            if path then return nil end
            path = section.text
        elseif section.type == "text" and trim(section.text) ~= "" then return nil end
    end
    if not path or not AssDrawing.validatePath(path) then return nil end
    for token in path:gmatch("%S+") do
        if not Core.finiteNumber(token) and token ~= "m" and token ~= "n" and token ~= "l" then return nil end
    end
    local minX, minY, maxX, maxY
    AssDrawing.mapCoordinates(path, function(x, y)
        minX, minY = math.min(minX or x, x), math.min(minY or y, y)
        maxX, maxY = math.max(maxX or x, x), math.max(maxY or y, y)
        return x, y
    end)
    if not minX or maxX <= minX or maxY <= minY then return nil end
    return minX, minY, maxX, maxY
end

local function simpleMaskBounds(line, playX, playY, videoW, videoH)
    local text = tostring(line.text or "")
    if LineOps.hasTag(text, {"t", "r", "clip", "iclip", "org", "fr"}) then return nil end
    local drawingScale, drawingAt
    for _, section in ipairs(LineOps.scanSections(text)) do
        if section.type == "drawing" and trim(section.text) ~= "" then
            if drawingAt then return nil end
            drawingScale, drawingAt = section.drawing, section.start
        elseif drawingAt and section.type == "override" then
            for _, call in ipairs(LineOps.tagCalls("{" .. section.text .. "}")) do
                if call.name ~= "p" or Core.finiteNumber(call.value) ~= 0 then return nil end
            end
        end
    end
    local style = AssContext.resolve(line).style or {}
    local align = AssContext.alignment(text, style)
    local scaleX = lastNumericTag(text, "fscx") or Core.finiteNumber(style.scale_x) or 100
    local scaleY = lastNumericTag(text, "fscy") or Core.finiteNumber(style.scale_y) or 100
    local pbo = lastNumericTag(text, "pbo") or 0
    if not align or align < 1 or align > 9 or align ~= math.floor(align) or not drawingScale or not scaleX or not scaleY or scaleX <= 0 or scaleY <= 0
        or not pbo or math.abs(pbo) > coordinateTolerance then return nil end
    for _, name in ipairs({"frz", "frx", "fry", "fax", "fay"}) do
        local value = lastNumericTag(text, name) or (name == "frz" and Core.finiteNumber(style.angle)) or 0
        if value == nil or math.abs(value) > coordinateTolerance then return nil end
    end
    local position = simpleMaskPosition(text)
    if not position and #LineOps.tagCalls(text, {"pos", "move"}) == 0 then
        local x, y = AssContext.defaultPosition(line, {style = style, meta = {PlayResX = playX, PlayResY = playY}})
        if x and y then position = {kind = "pos", values = {x, y}} end
    end
    local minX, minY, maxX, maxY = simpleDrawingBounds(text)
    if not position or not minX then return nil end
    local drawingFactor = 1 / (2 ^ (drawingScale - 1))
    local width = (maxX - minX) * drawingFactor * scaleX / 100
    local height = (maxY - minY) * drawingFactor * scaleY / 100
    if not finitePositive(width) or not finitePositive(height) then return nil end
    local startFrame = frameFromMs(line.start_time)
    local endFrame = frameFromMs(line.end_time)
    if endFrame <= startFrame then endFrame = startFrame + 1 end
    local fbf = {off = startFrame, n = endFrame - startFrame}
    local horizontal = ((align - 1) % 3) + 1
    local vertical = math.floor((align - 1) / 3)
    local duration = math.max(1, (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0))
    for frame = startFrame, endFrame - 1 do
        LineOps.checkCancelled()
        local posX, posY
        if position.kind == "pos" then
            posX, posY = position.values[1], position.values[2]
        else
            local atMs = (msFromFrame(frame) or line.start_time) - line.start_time
            posX, posY = AssContext.explicitPosition(text, duration, atMs)
        end
        local left = horizontal == 1 and posX or (horizontal == 2 and posX - width / 2 or posX - width)
        local top = vertical == 2 and posY or (vertical == 1 and posY - height / 2 or posY - height)
        left, top = left * videoW / playX, top * videoH / playY
        local renderedW, renderedH = width * videoW / playX, height * videoH / playY
        fbf[frame] = {
            {x = left, y = top},
            {x = left + renderedW, y = top + renderedH},
            w = renderedW,
            h = renderedH
        }
    end
    return {
        animated = position.kind == "move",
        fbf = fbf,
        w = width * videoW / playX,
        h = height * videoH / playY,
        exactSocialMask = true
    }
end

local function collectRenderedBounds(maskLines, playX, playY, videoW, videoH)
    local result = {}
    for _, line in ipairs(maskLines) do
        LineOps.checkCancelled()
        local bounds = simpleMaskBounds(line, playX, playY, videoW, videoH)
        if not bounds then
            local probe = shallowCopy(line)
            probe.text, probe.raw, probe.ASS = opaqueMaskText(line.text), nil, nil
            local ok
            ok, bounds = pcall(function() return ASS:parse(probe):getLineBounds(true, false) end)
            if not ok then
                return nil, "SubInspector no pudo medir la máscara de la línea " .. tostring(line.number) .. ": " .. tostring(bounds)
            end
            if not bounds or not bounds.fbf then
                return nil, "SubInspector no devolvió geometría para la máscara de la línea " .. tostring(line.number) .. "."
            end
        end
        result[line.number] = bounds
    end
    return result
end

local function unpackFrameBound(entry)
    if not entry or not entry[1] or not entry[2] then return nil end
    local x = Core.finiteNumber(entry[1].x)
    local y = Core.finiteNumber(entry[1].y)
    local w = Core.finiteNumber(entry.w)
    local h = Core.finiteNumber(entry.h)
    if not x or not y or not w or not h or w <= 0 or h <= 0 then return nil end
    return {x = x, y = y, w = w, h = h}
end

local function attachSceneGeometry(scene, lineBounds, cfg, videoW, videoH, outW, outH)
    if not lineBounds or not lineBounds.fbf then
        return nil, "No se obtuvo geometría renderizada para la máscara de la línea " .. tostring(scene.index) .. "."
    end
    local frames, maxW, maxH = {}, 0, 0
    local staticEntry = not lineBounds.animated and lineBounds.fbf[lineBounds.fbf.off] or nil
    for frame = scene.startFrame, scene.endFrame - 1 do
        LineOps.checkCancelled()
        local bound = unpackFrameBound(lineBounds.fbf[frame] or staticEntry)
        if not bound then
            return nil, string.format("La máscara de la línea %d no es visible en el cuadro %d.", scene.index, frame)
        end
        frames[#frames + 1] = {frame = frame, bound = bound}
        maxW = math.max(maxW, bound.w)
        maxH = math.max(maxH, bound.h)
    end
    local widthTolerance, heightTolerance = math.max(3, maxW * 0.01), math.max(3, maxH * 0.01)
    for _, item in ipairs(frames) do
        local bound = item.bound
        local widthClipped = bound.x <= 1 or bound.x + bound.w >= videoW - 1
        local heightClipped = bound.y <= 1 or bound.y + bound.h >= videoH - 1
        if maxW - bound.w > widthTolerance and not widthClipped then
            return nil, string.format("La máscara de la línea %d cambia de ancho dentro del cuadro. Usa movimiento sin escala/rotación animada.", scene.index)
        end
        if maxH - bound.h > heightTolerance and not heightClipped then
            return nil, string.format("La máscara de la línea %d cambia de alto dentro del cuadro. Usa movimiento sin escala/rotación animada.", scene.index)
        end
    end

    local cropW, cropH, cropError = resolveCropSize(maxW, maxH, outW / outH, cfg.aspectMode, videoW, videoH)
    if not cropW then return nil, "Línea " .. tostring(scene.index) .. ": " .. cropError end
    local trajectory, yCorrections = {}, 0
    local maxX, maxY = videoW - cropW, videoH - cropH
    for _, item in ipairs(frames) do
        local bound = item.bound
        local x = bound.x + bound.w / 2 - cropW / 2
        local requestedY = bound.y + bound.h / 2 - cropH / 2
        if x < -1 or x > maxX + 1 then
            return nil, string.format("La X de la máscara de la línea %d sale del vídeo en el cuadro %d (X %.2f; rango 0..%.2f).",
                scene.index, item.frame, x, maxX)
        end
        x = clamp(x, 0, maxX)
        local y = clamp(requestedY, 0, maxY)
        if math.abs(y - requestedY) >= coordinateTolerance then yCorrections = yCorrections + 1 end
        trajectory[#trajectory + 1] = {
            frame = item.frame,
            x = round(x, 3),
            y = round(y, 3),
            requestedY = round(requestedY, 3),
            yCorrected = math.abs(y - requestedY) >= coordinateTolerance
        }
    end
    scene.cropW, scene.cropH = cropW, cropH
    scene.frameTrajectory = trajectory
    scene.trajectory = compressTrajectory(trajectory)
    scene.yCorrections = yCorrections
    return true
end

local function prepareScenePlan(subs, selection, cfg, videoW, videoH, outW, outH)
    local masks, maskError = collectMaskLines(subs, selection)
    if not masks then return nil, maskError end
    local rawScenes = {}
    for _, line in ipairs(masks.lines) do
        local startFrame = frameFromMs(line.start_time)
        local endFrame = frameFromMs(line.end_time)
        if endFrame <= startFrame then
            endFrame = frameFromMs(math.max(line.start_time, line.end_time - 1)) + 1
        end
        rawScenes[#rawScenes + 1] = {
            index = line.number,
            line = line,
            startFrame = startFrame,
            endFrame = endFrame
        }
    end
    local scenes, sceneError, overlaps = normalizeScenes(rawScenes, msFromFrame, frameFromMs)
    if not scenes then return nil, sceneError end
    local timeline, timelineError = materializeTimeline(scenes, msFromFrame)
    if not timeline then return nil, timelineError end

    aegisub.progress.title(script_name)
    aegisub.progress.task("Midiendo máscaras animadas por cuadro")
    local playX, playY = scriptResolution(subs, videoW, videoH)
    local bounds, boundsError = collectRenderedBounds(masks.lines, playX, playY, videoW, videoH)
    if not bounds then return nil, boundsError end
    local yCorrections = 0
    for i, scene in ipairs(scenes) do
        if aegisub.progress.is_cancelled() then aegisub.cancel() end
        aegisub.progress.set(math.floor((i - 1) * 100 / #scenes))
        local ok, geometryError = attachSceneGeometry(scene, bounds[scene.index], cfg, videoW, videoH, outW, outH)
        if not ok then return nil, geometryError end
        yCorrections = yCorrections + scene.yCorrections
    end
    aegisub.progress.set(100)

    local indexSet = {}
    for _, index in ipairs(masks.indices) do indexSet[index] = true end
    return {
        scenes = scenes,
        durationMs = timeline.durationMs,
        gaps = timeline.gaps,
        overlaps = overlaps or 0,
        yCorrections = yCorrections,
        maskSource = masks.source,
        maskIndexSet = indexSet,
        maskCount = #scenes
    }
end

local function assField(value, fallback)
    value = tostring(value or fallback or ""):gsub("[\r\n]", " ")
    return (value:gsub(",", " "))
end

local function assNumber(value, fallback)
    return Core.finiteNumber(value) or fallback or 0
end

local function assInteger(value, fallback)
    return math.floor(assNumber(value, fallback) + 0.5)
end

local function assEventText(value)
    value = tostring(value or ""):gsub("\r\n", "\\N")
    return (value:gsub("[\r\n]", "\\N"))
end

local function defaultStyle()
    return {
        class = "style", name = "Default", fontname = "Arial", fontsize = 60,
        color1 = "&H00FFFFFF&", color2 = "&H000000FF&", color3 = "&H00000000&", color4 = "&H80000000&",
        bold = false, italic = false, underline = false, strikeout = false,
        scale_x = 100, scale_y = 100, spacing = 0, angle = 0,
        borderstyle = 1, outline = 3, shadow = 0, align = 2,
        margin_l = 40, margin_r = 40, margin_t = 40, encoding = 1
    }
end

local function collectStyles(subs)
    local list, map = {}, {}
    for i = 1, #subs do
        LineOps.checkCancelled()
        local line = subs[i]
        if line and line.class == "style" then
            list[#list + 1] = line
            map[tostring(line.name or "Default")] = line
        end
    end
    if #list == 0 then
        local style = defaultStyle()
        list[1], map.Default = style, style
    elseif not map.Default then
        local style = shallowCopy(list[1])
        style.name = "Default"
        list[#list + 1] = style
        map.Default = style
    end
    return list, map
end

local function sourceStyleLine(style)
    local copy = ASSParser.create_style_line(style)
    copy.name, copy.fontname = assField(copy.name, "Default"), assField(copy.fontname, "Arial")
    copy.margin_t = style.margin_t or style.margin_v or copy.margin_t
    for _, key in ipairs({"bold", "italic", "underline", "strikeout"}) do
        if type(copy[key]) == "number" then copy[key] = copy[key] ~= 0 end
    end
    return ASSParser.line_to_raw(copy)
end

local function scaledStyleLine(style, scale, outW, outH, cfg)
    local copy = ASSParser.create_style_line(style)
    copy.fontsize = math.min(assNumber(style.fontsize, 60) * scale, outH * cfg.maxFont / 100)
    for _, key in ipairs({"spacing", "outline", "shadow"}) do copy[key] = assNumber(copy[key], 0) * scale end
    copy.angle, copy.align = 0, 2
    copy.margin_l = math.floor(outW * cfg.safeX / 100 + 0.5)
    copy.margin_r = copy.margin_l
    copy.margin_t = math.floor(outH * cfg.safeBottom / 100 + 0.5)
    return sourceStyleLine(copy)
end

local function visibleText(text)
    text = tostring(text or ""):gsub("%b{}", "")
    text = text:gsub("\\[Nnh]", " "):gsub("%s+", " ")
    return trim(text)
end

local function isTraditionalLine(line, style)
    local text = tostring(line and line.text or "")
    if hasVectorDrawing(text) then return false, "drawing" end
    local centered = type(line and line.extra) == "table" and line.extra[centerExtra] ~= nil
    style = style or (line and line.styleRef)
    if not centered and style and assInteger(style.align, 2) ~= 2 then return false, "alignment" end
    if style and math.abs(assNumber(style.angle, 0)) >= coordinateTolerance then return false, "rotation" end
    local complex = {org=true, clip=true, iclip=true, fr=true, frx=true, fry=true, frz=true, fax=true, fay=true,
        fn=true, r=true, pbo=true, _persp=true, t=true, k=true, kf=true, ko=true, kt=true}
    local positioned = {pos=true, move=true, fs=true, fsp=true, fscx=true, fscy=true}
    for _, call in ipairs(LineOps.tagCalls(text)) do
        if call.top_level then
            if not centered and (call.name == "an" or call.name == "a") and Core.finiteNumber(call.value) ~= 2 then
                return false, "alignment"
            end
            if complex[call.name] or (not centered and positioned[call.name]) then return false, "positioned" end
        end
    end
    if visibleText(text) == "" then return false, "empty" end
    return true
end

local insertLeadingTags = LineOps.prependTag

local function adaptOverrideBlock(block, scale, maxFont)
    local body = LineOps.removeTagCalls(block, {"an", "a", "q", "pos", "move", "org", "clip", "iclip"})
    return (LineOps.mapTagCalls(body, {"fs", "fsp", "bord", "xbord", "ybord", "shad", "xshad", "yshad", "blur", "be"}, function(call)
        local value = Core.finiteNumber(call.value)
        if not value then return end
        if call.name == "fs" and trim(call.value):match("^[%+%-]") then return end
        value = value * scale
        if call.name == "fs" and value > 0 then value = math.min(value, maxFont) end
        return "\\" .. call.raw_name .. formatNumber(value, 3)
    end))
end

local function measureText(style, text)
    if not aegisub or not aegisub.text_extents or not style then return nil, nil end
    local ok, width, height = pcall(aegisub.text_extents, style, text)
    if not ok then return nil, nil end
    return tonumber(width), tonumber(height)
end

local function plainMeasurementLines(text)
    text = tostring(text or ""):gsub("%b{}", "")
    text = text:gsub("\\h", "\1"):gsub("\\n", " "):gsub("\\N", "\n")
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    return lines
end

local function wrappedLineCount(line, style, projectedScale, safeWidth, fit)
    local lineCount, longestWord = 0, 0
    local spaceWidth = select(1, measureText(style, " ")) or (assNumber(style.fontsize, 40) * 0.35)
    spaceWidth = spaceWidth * projectedScale * fit
    for _, explicitLine in ipairs(plainMeasurementLines(line.text)) do
        local current, words = 0, 0
        for word in explicitLine:gmatch("%S+") do
            word = word:gsub("\1", " ")
            local width = select(1, measureText(style, word)) or (#LineOps.graphemes(word) * assNumber(style.fontsize, 40) * 0.55)
            width = width * projectedScale * fit
            longestWord = math.max(longestWord, width)
            if words > 0 and current + spaceWidth + width > safeWidth then
                lineCount, current, words = lineCount + 1, width, 1
            else
                current = words > 0 and (current + spaceWidth + width) or width
                words = words + 1
            end
        end
        lineCount = lineCount + 1
    end
    return math.max(1, lineCount), longestWord
end

local function traditionalTextFit(line, style, scale, outW, outH, cfg)
    if not style then return 1 end
    local safeWidth = outW * (1 - 2 * cfg.safeX / 100)
    local safeHeight = outH * (1 - cfg.safeBottom / 100)
    local fontSize = math.max(1, assNumber(style.fontsize, 40))
    local projectedScale = math.min(scale, (outH * cfg.maxFont / 100) / fontSize)
    local _, measuredHeight = measureText(style, "Ag")
    local lineHeight = (measuredHeight or fontSize) * projectedScale
    lineHeight = lineHeight + 2 * assNumber(style.outline, 0) * scale + math.abs(assNumber(style.shadow, 0) * scale)
    local fit = 1
    while true do
        LineOps.checkCancelled()
        local lineCount, longestWord = wrappedLineCount(line, style, projectedScale, safeWidth, fit)
        local widthFactor = longestWord > safeWidth and safeWidth / longestWord or 1
        local totalHeight = lineCount * lineHeight * 1.12 * fit
        local heightFactor = totalHeight > safeHeight and safeHeight / totalHeight or 1
        local adjustment = math.min(widthFactor, heightFactor)
        if adjustment >= 0.999 then break end
        local nextFit = fit * adjustment * 0.98
        if nextFit <= 0 or nextFit >= fit then break end
        fit = nextFit
    end
    return fit
end

local function adaptLineText(line, style, scale, outW, outH, cfg)
    local maxFont = outH * cfg.maxFont / 100
    local text = tostring(line.text or "")
    text = text:gsub("{[^}]*}", function(block) return adaptOverrideBlock(block, scale, maxFont) end)
    local fit = traditionalTextFit(line, style, scale, outW, outH, cfg)
    local tags = "\\an2\\q0"
    if fit < 0.999 then
        text = LineOps.mapTagCalls(text, {"fscx", "fscy"}, function(call)
            local value = Core.finiteNumber(call.value)
            if value then return "\\" .. call.raw_name .. formatNumber(value * fit, 3) end
        end)
        tags = tags .. "\\fscx" .. formatNumber(assNumber(style and style.scale_x, 100) * fit, 3)
            .. "\\fscy" .. formatNumber(assNumber(style and style.scale_y, 100) * fit, 3)
    end
    return insertLeadingTags(text, tags), fit
end

local function lineIntersectsPlan(line, scenes)
    local startMs, endMs = tonumber(line.start_time) or 0, tonumber(line.end_time) or 0
    for _, scene in ipairs(scenes) do
        if endMs > scene.startMs and startMs < scene.endMs then return true end
    end
    return false
end

local function exportLineKind(line, index, plan, styleMap)
    if not line or line.class ~= "dialogue" or line.comment then return "ignore" end
    local startMs, endMs = tonumber(line.start_time) or 0, tonumber(line.end_time) or 0
    if endMs <= startMs then return "ignore" end
    local effect = tostring(line.effect or "")
    if (plan.maskIndexSet and plan.maskIndexSet[index]) or effect == maskEffect or effect == previewEffect then return "ignore" end
    if not lineIntersectsPlan(line, plan.scenes) then return "ignore" end
    local text = tostring(line.text or "")
    if not hasVectorDrawing(text) and visibleText(text) == "" then return "ignore" end
    local style = styleMap and (styleMap[tostring(line.style or "Default")] or styleMap.Default) or nil
    return isTraditionalLine(line, style) and "traditional" or "visual"
end

local function buildSourceVisualEvents(subs, plan, includeTraditional)
    local events, drawings, traditional = {}, 0, 0
    local _, styleMap = collectStyles(subs)
    for i = 1, #subs do
        LineOps.checkCancelled()
        local line = subs[i]
        local kind = exportLineKind(line, i, plan, styleMap)
        if kind == "visual" or (includeTraditional and kind == "traditional") then
            events[#events + 1] = line
            if hasVectorDrawing(line.text) then drawings = drawings + 1 end
            if kind == "traditional" then traditional = traditional + 1 end
        end
    end
    return events, {eventCount = #events, drawingCount = drawings, traditionalCount = traditional}
end

local offsetFades = AssContext.offsetFades

local function buildAdaptedEvents(subs, plan, cfg, outW, outH, playY, styleMap)
    local events, skippedComplex, splitEvents, shortFragments = {}, 0, 0, 0
    local styleScale = outH / playY
    local safeX = math.floor(outW * cfg.safeX / 100 + 0.5)
    local safeBottom = math.floor(outH * cfg.safeBottom / 100 + 0.5)
    for i = 1, #subs do
        LineOps.checkCancelled()
        local line = subs[i]
        local kind = exportLineKind(line, i, plan, styleMap)
        if kind ~= "ignore" then
            if kind == "traditional" then
                local style = styleMap[tostring(line.style or "Default")] or styleMap.Default
                local pieces = 0
                for _, scene in ipairs(plan.scenes) do
        LineOps.checkCancelled()
                    local overlapStart = math.max(line.start_time, scene.startMs)
                    local overlapEnd = math.min(line.end_time, scene.endMs)
                    if overlapEnd - overlapStart >= 10 then
                        local event = shallowCopy(line)
                        event.start_time = scene.outputStartMs + overlapStart - scene.startMs
                        event.end_time = scene.outputStartMs + overlapEnd - scene.startMs
                        event.margin_l, event.margin_r, event.margin_t = safeX, safeX, safeBottom
                        event.margin_v = safeBottom
                        event.text = adaptLineText(line, style, styleScale, outW, outH, cfg)
                        if overlapStart > line.start_time or overlapEnd < line.end_time then
                            event.text = offsetFades(event.text, line.end_time - line.start_time, overlapStart - line.start_time)
                        end
                        event.sourceIndex = i
                        events[#events + 1] = event
                        pieces = pieces + 1
                    elseif overlapEnd > overlapStart then
                        shortFragments = shortFragments + 1
                    end
                end
                if pieces > 1 then splitEvents = splitEvents + pieces - 1 end
            else
                skippedComplex = skippedComplex + 1
            end
        end
    end
    table.sort(events, function(a, b)
        if a.start_time == b.start_time then
            if (a.layer or 0) == (b.layer or 0) then return (a.sourceIndex or 0) < (b.sourceIndex or 0) end
            return (a.layer or 0) < (b.layer or 0)
        end
        return a.start_time < b.start_time
    end)
    return events, {skippedComplex = skippedComplex, splitEvents = splitEvents, shortFragments = shortFragments, styleScale = styleScale}
end

local function trajectoryPointAtFrame(scene, frame)
    frame = clamp(math.floor(tonumber(frame) or scene.startFrame), scene.startFrame, scene.endFrame - 1)
    local full = scene.frameTrajectory or {}
    local direct = full[frame - scene.startFrame + 1]
    if direct and direct.frame == frame then return direct end
    local previous
    for _, point in ipairs(full) do
        if point.frame == frame then return point end
        if point.frame > frame then break end
        previous = point
    end
    if previous then return previous end
    for _, point in ipairs(scene.trajectory or {}) do
        if point.frame > frame then break end
        previous = point
    end
    return previous or (scene.trajectory and scene.trajectory[1])
end

local function sceneForSubtitle(line, scenes)
    local found, count
    local startMs, endMs = tonumber(line.start_time) or 0, tonumber(line.end_time) or 0
    local startFrame = frameFromMs(startMs)
    local endFrame = frameFromMs(endMs)
    if endFrame <= startFrame then endFrame = startFrame + 1 end
    for _, scene in ipairs(scenes or {}) do
        if endFrame > scene.startFrame and startFrame < scene.endFrame then
            found, count = scene, (count or 0) + 1
        end
    end
    if not found then return nil, "no coincide con ninguna máscara" end
    if count ~= 1 then return nil, "atraviesa más de una máscara; divídelo antes" end
    if startFrame < found.startFrame or endFrame > found.endFrame then
        return nil, "incluye un hueco fuera de su máscara"
    end
    return found
end

local function linearSceneX(line, scene, playX, videoW)
    local lineStartMs = tonumber(line.start_time) or 0
    local lineEndMs = tonumber(line.end_time) or lineStartMs
    local startMs = math.max(lineStartMs, scene.startMs)
    local endMs = math.min(lineEndMs, scene.endMs)
    local sampleEnd = math.max(startMs, endMs - 1)
    local firstFrame = clamp(frameFromMs(startMs), scene.startFrame, scene.endFrame - 1)
    local lastFrame = clamp(frameFromMs(sampleEnd), scene.startFrame, scene.endFrame - 1)
    local samples = {}
    for frame = firstFrame, lastFrame do
        LineOps.checkCancelled()
        local point = trajectoryPointAtFrame(scene, frame)
        local atMs = msFromFrame(frame)
        if point and atMs then
            samples[#samples + 1] = {ms = atMs, x = (point.x + scene.cropW / 2) * playX / videoW}
        end
    end
    if #samples == 0 then return nil, nil, "no se pudo medir la X de la máscara" end
    local first, last = samples[1], samples[#samples]
    local slope = last.ms > first.ms and (last.x - first.x) / (last.ms - first.ms) or 0
    for _, sample in ipairs(samples) do
        local expected = first.x + slope * (sample.ms - first.ms)
        if math.abs(sample.x - expected) > 0.75 then
            return nil, nil, "la X de la máscara no es lineal y no cabe en un solo \\move"
        end
    end
    local motion = {originMs = first.ms, originX = first.x, slope = slope}
    local x1 = motion.originX + motion.slope * (lineStartMs - motion.originMs)
    local x2 = motion.originX + motion.slope * (lineEndMs - motion.originMs)
    return x1, x2, nil, motion
end

local function centeredAlignment(value)
    value = clamp(math.floor((tonumber(value) or 2) + 0.5), 1, 9)
    if value <= 3 then return 2 end
    if value <= 6 then return 5 end
    return 8
end

local function stripPositionAndAlignment(text)
    return (LineOps.removeTagCalls(text, {"pos", "move", "an", "a"}))
end

local function rewriteCenteredText(line, style, playY, scene, playX, videoW)
    local text = tostring(line.text or "")
    if hasVectorDrawing(text) then return nil, "es un dibujo, no un subtítulo" end
    if LineOps.hasTag(text, {"org", "clip", "iclip"}) then
        return nil, "usa \\org/\\clip y no se puede mover solo en X con seguridad"
    end
    local position, positionError = parsePositionSpec(text)
    if positionError then return nil, positionError end
    local x1, x2, motionError, motion = linearSceneX(line, scene, playX, videoW)
    if not x1 then return nil, motionError end
    local sourceAlign = AssContext.alignment(text, style)
    local targetAlign = centeredAlignment(sourceAlign)
    local positionTag
    if position and position.kind == "move" then
        local values, numbers = position.values, position.numbers
        local moveX1, moveX2 = x1, x2
        if #values == 6 then
            local duration = math.max(1, (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0))
            local maskMoves = math.abs(x2 - x1) >= 0.01
            local yMoves = math.abs(numbers[4] - numbers[2]) >= coordinateTolerance
            local fullDuration = math.abs(numbers[5]) <= 1 and math.abs(numbers[6] - duration) <= 1
            if maskMoves and yMoves and not fullDuration then
                return nil, "el \\move temporal de Y no es compatible con una máscara que se mueve en X"
            end
            if maskMoves and not yMoves then
                values = {values[1], values[2], values[3], values[4]}
            else
                local absoluteT1 = (tonumber(line.start_time) or 0) + numbers[5]
                local absoluteT2 = (tonumber(line.start_time) or 0) + numbers[6]
                moveX1 = motion.originX + motion.slope * (absoluteT1 - motion.originMs)
                moveX2 = motion.originX + motion.slope * (absoluteT2 - motion.originMs)
            end
        end
        positionTag = "\\move(" .. formatNumber(moveX1, 3) .. "," .. values[2] .. ","
            .. formatNumber(moveX2, 3) .. "," .. values[4]
        if #values == 6 then positionTag = positionTag .. "," .. values[5] .. "," .. values[6] end
        positionTag = positionTag .. ")"
    else
        local _, defaultY = AssContext.defaultPosition(line, {style = style, meta = {PlayResX = playX, PlayResY = playY}})
        local y = position and position.numbers[2] or defaultY
        if not y then return nil, "no se pudo resolver la posición del estilo" end
        if math.abs(x2 - x1) < 0.01 then
            positionTag = "\\pos(" .. formatNumber((x1 + x2) / 2, 3) .. "," .. formatNumber(y, 3) .. ")"
        else
            positionTag = "\\move(" .. formatNumber(x1, 3) .. "," .. formatNumber(y, 3) .. ","
                .. formatNumber(x2, 3) .. "," .. formatNumber(y, 3) .. ")"
        end
    end
    local cleaned = stripPositionAndAlignment(text)
    return "{\\an" .. tostring(targetAlign) .. positionTag .. "}" .. cleaned,
        positionTag:sub(1, 5) == "\\move" and "move" or "pos"
end

local function centerSelectedSubtitlesX(subs, selection, plan, playX, playY, videoW)
    local _, styleMap = collectStyles(subs)
    local updates, skipped, candidates, moving = {}, {}, 0, 0
    for _, index in ipairs(LineOps.normalizeIndices(subs, selection)) do
        LineOps.checkCancelled()
        local line = subs[index]
            if line and line.class == "dialogue" and not line.comment and line.end_time > line.start_time
                and tostring(line.effect or "") ~= maskEffect and tostring(line.effect or "") ~= previewEffect then
                candidates = candidates + 1
                local scene, sceneError = sceneForSubtitle(line, plan.scenes)
                if not scene then
                    skipped[#skipped + 1] = string.format("Línea %d: %s.", index, sceneError)
                else
                    local style = styleMap[tostring(line.style or "Default")] or styleMap.Default
                    local text, modeOrError = rewriteCenteredText(line, style, playY, scene, playX, videoW)
                    if not text then
                        skipped[#skipped + 1] = string.format("Línea %d: %s.", index, modeOrError)
                    else
                        local updated = shallowCopy(line)
                        updated.text = text
                        updated.raw = nil
                        updated.extra = shallowCopy(line.extra)
                        updated.extra[centerExtra] = "1"
                        updates[#updates + 1] = {index = index, line = updated}
                        if modeOrError == "move" then moving = moving + 1 end
                    end
                end
            end
    end
    if candidates == 0 then return nil, "Selecciona uno o más subtítulos; las máscaras se reconocen por Effect." end
    if #updates == 0 then
        return nil, "No se centró ninguna línea.\n\n" .. table.concat(skipped, "\n")
    end
    for _, update in ipairs(updates) do LineOps.checkCancelled(); subs[update.index] = update.line end
    aegisub.set_undo_point("Kiri-Shot - Centrar subtítulos en X")
    local message = string.format("Centradas: %d | siguiendo movimiento X: %d | omitidas: %d", #updates, moving, #skipped)
    if #skipped > 0 then
        local details = {}
        for i = 1, math.min(5, #skipped) do details[#details + 1] = skipped[i] end
        message = message .. "\n\n" .. table.concat(details, "\n")
        if #skipped > 5 then message = message .. string.format("\n... y %d más.", #skipped - 5) end
    end
    return selection, message
end

local function correctedTrajectorySegments(scene, playX, playY, videoW, videoH)
    local points = {}
    for _, point in ipairs(scene.frameTrajectory or {}) do
        points[#points + 1] = {
            frame = point.frame,
            ms = msFromFrame(point.frame),
            x = (point.x + scene.cropW / 2) * playX / videoW,
            y = (point.y + scene.cropH / 2) * playY / videoH,
            corrected = point.yCorrected == true
        }
    end
    if #points == 0 then return nil, "La máscara no tiene trayectoria para corregir." end
    local groups = {}
    if #points == 1 then
        groups[1] = {first = 1, last = 1, final = true}
    else
        local pending = {{first = 1, last = #points}}
        while #pending > 0 do
            LineOps.checkCancelled()
            local candidate = table.remove(pending)
            local first, last = points[candidate.first], points[candidate.last]
            local span = math.max(1, last.ms - first.ms)
            local splitIndex, maxError
            for i = candidate.first + 1, candidate.last - 1 do
                local factor = clamp((points[i].ms - first.ms) / span, 0, 1)
                local expectedX = first.x + (last.x - first.x) * factor
                local expectedY = first.y + (last.y - first.y) * factor
                local error = math.max(math.abs(points[i].x - expectedX), math.abs(points[i].y - expectedY))
                if not maxError or error > maxError then splitIndex, maxError = i, error end
            end
            if splitIndex and maxError > trajectoryErrorTolerance then
                pending[#pending + 1] = {first = splitIndex, last = candidate.last}
                pending[#pending + 1] = {first = candidate.first, last = splitIndex}
            else
                groups[#groups + 1] = {first = candidate.first, last = candidate.last, final = false}
            end
        end
        table.sort(groups, function(a, b) return a.first < b.first end)
        groups[#groups].final = true
    end
    local segments = {}
    for _, group in ipairs(groups) do
        local first, last = points[group.first], points[group.last]
        local endFrame = group.final and scene.endFrame or last.frame
        local corrected = false
        for i = group.first, group.last do corrected = corrected or points[i].corrected end
        local positionTag
        if math.abs(last.x - first.x) < coordinateTolerance and math.abs(last.y - first.y) < coordinateTolerance then
            positionTag = "\\pos(" .. formatNumber(first.x, 3) .. "," .. formatNumber(first.y, 3) .. ")"
        elseif group.final then
            local moveEnd = math.max(1, last.ms - first.ms)
            positionTag = "\\move(" .. formatNumber(first.x, 3) .. "," .. formatNumber(first.y, 3) .. ","
                .. formatNumber(last.x, 3) .. "," .. formatNumber(last.y, 3) .. ",0," .. formatNumber(moveEnd, 3) .. ")"
        else
            positionTag = "\\move(" .. formatNumber(first.x, 3) .. "," .. formatNumber(first.y, 3) .. ","
                .. formatNumber(last.x, 3) .. "," .. formatNumber(last.y, 3) .. ")"
        end
        segments[#segments + 1] = {
            startFrame = first.frame,
            endFrame = endFrame,
            corrected = corrected,
            positionTag = positionTag
        }
    end
    return segments
end

local function removeYPreviews(subs, selection)
    local selected, indices, remapped = {}, {}, {}
    for _, index in ipairs(LineOps.normalizeIndices(subs, selection)) do selected[index] = true end
    for index = 1, #subs do
        LineOps.checkCancelled()
        local line = subs[index]
        if line and line.class == "dialogue" and tostring(line.effect or "") == previewEffect then
            indices[#indices + 1] = index
        elseif selected[index] then remapped[#remapped + 1] = index - #indices end
    end
    for i = #indices, 1, -1 do subs.delete(indices[i]) end
    return remapped, #indices
end

local function correctedMaskText(text, positionTag)
    return "{\\an5" .. positionTag .. "}" .. stripPositionAndAlignment(text)
end

local function correctSelectedMasksY(subs, selection, cfg, playX, playY, videoW, videoH, outW, outH)
    local maskSelection = {}
    for _, index in ipairs(LineOps.normalizeIndices(subs, selection)) do
        local line = subs[index]
        local effect = line and tostring(line.effect or "") or ""
        if effect == maskEffect or effect == previewEffect then maskSelection[#maskSelection + 1] = index end
    end
    if #maskSelection == 0 then
        return nil, "Selecciona una o más líneas con Effect " .. maskEffect .. " o " .. previewEffect .. "."
    end
    local masks, maskError = collectMaskLines(subs, maskSelection)
    if not masks then return nil, maskError end
    if masks.source ~= "selección" then
        return nil, "Selecciona las máscaras que quieres corregir; esta acción no modifica líneas por búsqueda automática."
    end
    local bounds, boundsError = collectRenderedBounds(masks.lines, playX, playY, videoW, videoH)
    if not bounds then return nil, boundsError end
    local jobs, totalSegments, correctedFrames = {}, 0, 0
    for _, mask in ipairs(masks.lines) do
        LineOps.checkCancelled()
        if not bounds[mask.number].exactSocialMask then
            return nil, "La máscara de la línea " .. mask.number .. " necesita su geometría original para renderizarse. "
                .. "La exportación ajusta su recorte en Y; para modificar la línea, crea una máscara poligonal sin transformaciones, rotación ni clips."
        end
        local startFrame = frameFromMs(mask.start_time)
        local endFrame = frameFromMs(mask.end_time)
        if endFrame <= startFrame then endFrame = startFrame + 1 end
        local scene = {index = mask.number, startFrame = startFrame, endFrame = endFrame}
        local attached, geometryError = attachSceneGeometry(scene, bounds[mask.number], cfg, videoW, videoH, outW, outH)
        if not attached then return nil, geometryError end
        local segments, segmentError = correctedTrajectorySegments(scene, playX, playY, videoW, videoH)
        if not segments then return nil, segmentError end
        local source = shallowCopy(subs[mask.number])
        local outputs = {}
        for segmentIndex, segment in ipairs(segments) do
            local output = shallowCopy(source)
            output.raw = nil
            output.comment = false
            output.start_time = segmentIndex == 1 and source.start_time or msFromFrame(segment.startFrame)
            output.end_time = segmentIndex == #segments and source.end_time or msFromFrame(segment.endFrame)
            output.effect = maskEffect
            if tostring(source.effect or "") == previewEffect then output.actor = "SocialClip" end
            output.text = correctedMaskText(source.text, segment.positionTag)
            if output.start_time ~= source.start_time or output.end_time ~= source.end_time then
                output.text = offsetFades(output.text, source.end_time - source.start_time, output.start_time - source.start_time)
            end
            outputs[#outputs + 1] = output
        end
        jobs[#jobs + 1] = {index = mask.number, outputs = outputs}
        totalSegments = totalSegments + #outputs
        correctedFrames = correctedFrames + (scene.yCorrections or 0)
    end
    table.sort(jobs, function(a, b) return a.index < b.index end)
    local offset, newSelection = 0, {}
    for _, job in ipairs(jobs) do
        LineOps.checkCancelled()
        local index = job.index + offset
        subs[index] = job.outputs[1]
        newSelection[#newSelection + 1] = index
        for outputIndex = 2, #job.outputs do
            local insertAt = index + outputIndex - 1
            subs.insert(insertAt, job.outputs[outputIndex])
            newSelection[#newSelection + 1] = insertAt
        end
        offset = offset + #job.outputs - 1
    end
    newSelection = removeYPreviews(subs, newSelection)
    aegisub.set_undo_point("Kiri-Shot - Corregir Y")
    return newSelection, string.format("Máscaras corregidas: %d | tramos resultantes: %d | cuadros con Y ajustada: %d. X se conservó y el origen quedó en \\an5.",
        #jobs, totalSegments, correctedFrames)
end

local function eventAssLine(line)
    local copy = ASSParser.create_dialogue_line(line)
    copy.comment = false
    copy.style, copy.actor, copy.effect = assField(copy.style, "Default"), assField(copy.actor), assField(copy.effect)
    copy.text = assEventText(copy.text)
    copy.margin_t = line.margin_t or line.margin_v or copy.margin_t
    return ASSParser.line_to_raw(copy)
end

local function writeSourceVisualAss(subs, plan, playX, playY, path, includeTraditional)
    local events, stats = buildSourceVisualEvents(subs, plan, includeTraditional)
    if #events == 0 then
        stats.noEvents = true
        return false, "No hay carteles, dibujos ni efectos complejos dentro de las escenas exportables.", stats
    end

    local rows, seenInfo = {"[Script Info]"}, {}
    for i = 1, #subs do
        LineOps.checkCancelled()
        local line = subs[i]
        if line and line.class == "info" and line.key then
            local key = trim(line.key)
            if key ~= "" then
                rows[#rows + 1] = key .. ": " .. tostring(line.value or ""):gsub("[\r\n]", " ")
                seenInfo[key:lower()] = true
            end
        end
    end
    if not seenInfo.scripttype then rows[#rows + 1] = "ScriptType: v4.00+" end
    if not seenInfo.playresx then rows[#rows + 1] = "PlayResX: " .. formatNumber(playX, 3) end
    if not seenInfo.playresy then rows[#rows + 1] = "PlayResY: " .. formatNumber(playY, 3) end

    local styles = collectStyles(subs)
    rows[#rows + 1] = ""
    rows[#rows + 1] = "[V4+ Styles]"
    rows[#rows + 1] = "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding"
    for _, style in ipairs(styles) do rows[#rows + 1] = sourceStyleLine(style) end
    rows[#rows + 1] = ""
    rows[#rows + 1] = "[Events]"
    rows[#rows + 1] = "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text"
    for _, event in ipairs(events) do rows[#rows + 1] = eventAssLine(event) end

    if not writeFile(path, table.concat(rows, "\n")) then
        return false, "No se pudo escribir el ASS visual temporal:\n" .. tostring(path), stats
    end
    return true, nil, stats
end

local function writeAdaptedAss(subs, plan, cfg, outW, outH, playY, path)
    local styles, styleMap = collectStyles(subs)
    local events, stats = buildAdaptedEvents(subs, plan, cfg, outW, outH, playY, styleMap)
    if #events == 0 then
        stats.noEvents = true
        return false, "No hay subtítulos tradicionales dentro de las escenas exportables.", stats
    end
    local rows = {
        "[Script Info]",
        "ScriptType: v4.00+",
        "Title: Social Clip - subtítulos adaptados",
        "PlayResX: " .. tostring(outW),
        "PlayResY: " .. tostring(outH),
        "WrapStyle: 0",
        "ScaledBorderAndShadow: yes",
        "YCbCr Matrix: TV.709",
        "",
        "[V4+ Styles]",
        "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding"
    }
    for _, style in ipairs(styles) do
        rows[#rows + 1] = scaledStyleLine(style, stats.styleScale, outW, outH, cfg)
    end
    rows[#rows + 1] = ""
    rows[#rows + 1] = "[Events]"
    rows[#rows + 1] = "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text"
    for _, event in ipairs(events) do rows[#rows + 1] = eventAssLine(event) end
    if not writeFile(path, table.concat(rows, "\n")) then
        return false, "No se pudo escribir el ASS adaptado:\n" .. tostring(path), stats
    end
    stats.eventCount = #events
    return true, nil, stats
end

local function sourceAudioPath(video)
    local audio = tostring(projectProperties().audio_file or "")
    if audio ~= "" and fileExists(audio) then return audio end
    return video
end

local function fileSize(path)
    return Media.fileSize(path) or 0
end

local function buildSubtitleBundleCommand(video, tracks, bundlePath, cfg)
    local args = {"-hide_banner", "-loglevel", "error", "-y"}
    for _, track in ipairs(tracks) do args[#args + 1] = "-i"; args[#args + 1] = track.path end
    args[#args + 1] = "-i"; args[#args + 1] = video
    for input = 0, #tracks - 1 do args[#args + 1] = "-map"; args[#args + 1] = input .. ":s:0" end
    for _, value in ipairs({"-map", #tracks .. ":t?", "-map_chapters", "-1", "-c", "copy", "-f", "matroska", bundlePath}) do
        args[#args + 1] = value
    end
    return processCommand(cfg.ffmpeg, args, "ffmpeg")
end

local function createSubtitleBundle(video, visualPath, adaptedPath, cfg, tempBase)
    local tracks, bundle = {}, {visualStream = nil, adaptedStream = nil}
    if visualPath then
        bundle.visualStream = #tracks
        tracks[#tracks + 1] = {path = visualPath}
    end
    if adaptedPath then
        bundle.adaptedStream = #tracks
        tracks[#tracks + 1] = {path = adaptedPath}
    end
    if #tracks == 0 then return nil end

    bundle.path = tempBase .. "_subtitles.mkv"
    local command = buildSubtitleBundleCommand(video, tracks, bundle.path, cfg)
    local status, details, code = PyBridge.runProcess(command)
    details = trim(details)
    if not status or fileSize(bundle.path) <= 0 then
        os.remove(bundle.path)
        local message = code == 130 and "Exportación cancelada." or "FFmpeg no pudo preparar los subtítulos y las fuentes adjuntas."
        if details ~= "" then message = message .. "\n\nFFmpeg:\n" .. details end
        return nil, message
    end
    return bundle
end

local function probeAudioStream(path, cfg)
    local audioStream = math.max(0, math.floor(assNumber(cfg.audioTrack, 1) + 0.5) - 1)
    local status, output, code = PyBridge.runProcess(processCommand(cfg.ffprobe,
        {"-v", "error", "-select_streams", "a:" .. audioStream, "-show_entries", "stream=index", "-of", "csv=p=0", path}, "ffprobe"))
    if code == 130 then return nil, "Exportación cancelada." end
    if status then return trim(output) ~= "" end
    status, output, code = PyBridge.runProcess(processCommand(cfg.ffmpeg,
        {"-hide_banner", "-loglevel", "error", "-i", path, "-map", "0:a:" .. audioStream,
            "-frames:a", "1", "-c:a", "copy", "-f", "null", "-"}, "ffmpeg"))
    if code == 130 then return nil, "Exportación cancelada." end
    if status then return true end
    if tostring(output):find("matches no streams", 1, true) then return false end
    return nil, "No se pudo inspeccionar el audio. Revisa Config...\\n" .. trim(output)
end

local function writeTrajectoryFiles(plan, tempBase, cleanupList)
    local paths = {}
    for i, scene in ipairs(plan.scenes) do
        local commands = trajectoryCommands(scene, i, msFromFrame)
        scene.commandPath = nil
        if commands ~= "" then
            local path = tempBase .. string.format("_scene_%03d.cmd", i)
            if cleanupList then cleanupList[#cleanupList + 1] = path end
            if not writeFile(path, commands) then
                for _, oldPath in ipairs(paths) do os.remove(oldPath) end
                return nil, "No se pudo escribir la trayectoria temporal:\n" .. path
            end
            scene.commandPath = path
            paths[#paths + 1] = path
        end
    end
    return paths
end

local function subtitleFilter(spec)
    if not spec then return nil end
    if type(spec) == "string" then return "subtitles=" .. filterPathQuote(spec) end
    local filter = "subtitles=" .. filterPathQuote(spec.path)
    if spec.stream ~= nil then filter = filter .. ":si=" .. tostring(assInteger(spec.stream, 0)) end
    return filter
end

local function buildFiltergraph(plan, cfg, outW, outH, audioInput, visualSubtitle, burnedSubtitle)
    local scenes, rows = plan.scenes, {}
    local count = #scenes
    local audioStream = math.max(0, math.floor((tonumber(cfg.audioTrack) or 1) + 0.5) - 1)
    local outputFps = choiceOrDefault(cfg.fps, fpsItems, "30")
    if count == 0 then return nil, "No hay escenas para el filtro." end

    local videoRoot = "[0:v:0]"
    local visualFilter = subtitleFilter(visualSubtitle)
    if visualFilter then
        rows[#rows + 1] = videoRoot .. visualFilter .. "[vdecorated]"
        videoRoot = "[vdecorated]"
    end

    if count > 1 then
        local labels = {}
        for i = 1, count do labels[#labels + 1] = "[vsrc" .. tostring(i) .. "]" end
        rows[#rows + 1] = videoRoot .. "split=" .. tostring(count) .. table.concat(labels, "")
        if audioInput ~= nil then
            labels = {}
            for i = 1, count do labels[#labels + 1] = "[asrc" .. tostring(i) .. "]" end
            rows[#rows + 1] = string.format("[%d:a:%d]asplit=%d%s", audioInput, audioStream, count, table.concat(labels, ""))
        end
    end

    for i, scene in ipairs(scenes) do
        local videoSource = count > 1 and ("[vsrc" .. tostring(i) .. "]") or videoRoot
        local first = assert(scene.trajectory and scene.trajectory[1], "Escena sin trayectoria")
        local chain = videoSource
            .. "trim=start=" .. string.format("%.6f", scene.startMs / 1000)
            .. ":end=" .. string.format("%.6f", scene.endMs / 1000)
            .. ",setpts=PTS-STARTPTS"
        if scene.commandPath then chain = chain .. ",sendcmd=f=" .. filterPathQuote(scene.commandPath) end
        chain = chain
            .. string.format(",crop@crop%d=w=%d:h=%d:x=%s:y=%s:exact=1", i, scene.cropW, scene.cropH,
                formatNumber(first.x, 3), formatNumber(first.y, 3))
            .. string.format(",scale=w=%d:h=%d:flags=lanczos+accurate_rnd:force_original_aspect_ratio=decrease", outW, outH)
            .. string.format(",pad=%d:%d:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1[v%d]", outW, outH, i)
        rows[#rows + 1] = chain

        if audioInput ~= nil then
            local audioSource = count > 1 and ("[asrc" .. tostring(i) .. "]") or string.format("[%d:a:%d]", audioInput, audioStream)
            rows[#rows + 1] = audioSource
                .. "atrim=start=" .. string.format("%.6f", scene.startMs / 1000)
                .. ":end=" .. string.format("%.6f", scene.endMs / 1000)
                .. ",asetpts=PTS-STARTPTS,aresample=async=1:first_pts=0[a" .. tostring(i) .. "]"
        end
    end

    local videoLabel, audioLabel
    if count == 1 then
        videoLabel = "v1"
        if audioInput ~= nil then audioLabel = "a1" end
    else
        local inputs = {}
        for i = 1, count do
            inputs[#inputs + 1] = "[v" .. tostring(i) .. "]"
            if audioInput ~= nil then inputs[#inputs + 1] = "[a" .. tostring(i) .. "]" end
        end
        if audioInput ~= nil then
            rows[#rows + 1] = table.concat(inputs, "") .. string.format("concat=n=%d:v=1:a=1[vcat][acat]", count)
            videoLabel, audioLabel = "vcat", "acat"
        else
            rows[#rows + 1] = table.concat(inputs, "") .. string.format("concat=n=%d:v=1:a=0[vcat]", count)
            videoLabel = "vcat"
        end
    end

    local post = {}
    if outputFps ~= "Origen" then post[#post + 1] = "fps=" .. tostring(tonumber(outputFps) or 30) end
    local burnedFilter = subtitleFilter(burnedSubtitle)
    if burnedFilter then post[#post + 1] = burnedFilter end
    post[#post + 1] = "format=yuv420p"
    rows[#rows + 1] = "[" .. videoLabel .. "]" .. table.concat(post, ",") .. "[vout]"
    if audioLabel then rows[#rows + 1] = "[" .. audioLabel .. "]anull[aout]" end
    return table.concat(rows, ";\n")
end

local function buildExportCommand(video, audio, audioInput, filterPath, outputPath, cfg, softSubtitle)
    local profile = resolveOutputProfile(cfg)
    local args = {"-hide_banner", "-loglevel", "error", "-y", "-i", video}
    local function add(...)
        for i = 1, select("#", ...) do args[#args + 1] = tostring(select(i, ...)) end
    end
    if audioInput == 1 then add("-i", audio) end
    local softInput = audioInput == 1 and 2 or 1
    if softSubtitle then add("-i", softSubtitle.path) end
    add("-filter_complex_script", filterPath, "-map", "[vout]")
    if audioInput ~= nil then add("-map", "[aout]") end
    if softSubtitle then add("-map", softInput .. ":s:" .. softSubtitle.stream, "-map", softInput .. ":t?") end
    add("-c:v", "libx264", "-preset", choiceOrDefault(cfg.x264Preset, x264Presets, "fast"),
        "-crf", clamp(math.floor(assNumber(cfg.crf, 20) + 0.5), 0, maximumCrf), "-pix_fmt", "yuv420p",
        "-map_metadata:g", "-1", "-map_chapters", "-1", "-dn",
        "-fps_mode", choiceOrDefault(cfg.fps, fpsItems, "30") == "Origen" and "vfr" or "cfr", "-disposition:v:0", "default")
    if audioInput ~= nil then
        add("-c:a", "aac", "-b:a", choiceOrDefault(cfg.audioBitrate, audioBitrates, "192k"), "-ar", "48000", "-ac", "2", "-disposition:a:0", "default")
    end
    if profile.softDialogue and softSubtitle then
        add("-c:s", "copy", "-c:t", "copy", "-metadata:s:s:0", "language=spa", "-metadata:s:s:0", "title=Español adaptado", "-disposition:s:0", "default")
    else add("-sn") end
    if profile.extension == ".mp4" then add("-movflags", "+faststart", "-f", "mp4") else add("-f", "matroska") end
    add(outputPath)
    return processCommand(cfg.ffmpeg, args, "ffmpeg")
end

local function runExportCommand(command, _error_path, outputPath)
    local status, details, code = PyBridge.runProcess(command)
    details = trim(details)
    if not status or fileSize(outputPath) <= 0 then
        os.remove(outputPath)
        local message = code == 130 and "Exportación cancelada." or "FFmpeg no pudo crear el vídeo:\n" .. outputPath
        if details ~= "" then message = message .. "\n\nFFmpeg:\n" .. details end
        return false, message
    end
    return true
end

local function defaultProjectName(video)
    local name
    if aegisub.file_name then
        local ok, value = pcall(aegisub.file_name)
        if ok then name = value end
    end
    return safeName(baseName(name or video), "social")
end

local function selectOutputPath(video, outW, outH, extension)
    local folder = projectFolder(video)
    local suffix = extension == ".ass" and "_social_subtitles.ass" or string.format("_social_%dx%d%s", outW, outH, extension)
    local defaultName = defaultProjectName(video) .. suffix
    local wildcard
    if extension == ".ass" then
        wildcard = "ASS (*.ass)|*.ass"
    elseif extension == ".mkv" then
        wildcard = "Matroska (*.mkv)|*.mkv"
    else
        wildcard = "MP4 (*.mp4)|*.mp4"
    end
    local title = extension == ".ass" and "Guardar subtítulos sociales" or "Guardar vídeo social"
    local path = aegisub.dialog.save(title, folder, defaultName, wildcard, false)
    if not path or trim(path) == "" then return nil end
    if not tostring(path):lower():match(extension:gsub("%.", "%%.") .. "$") then path = path .. extension end
    if extension == ".ass" then
        local active = activeScriptPath()
        if active ~= "" and samePath(path, active) then
            showMessage("El ASS adaptado no puede sobrescribir el guion activo.", "Kiri-Shot - Seguridad")
            return nil
        end
    end
    if not confirmOverwrite(path) then return nil end
    return path
end

local function cleanupPaths(paths)
    for _, path in ipairs(paths or {}) do
        if path and path ~= "" then os.remove(path) end
    end
end

local function exportAssOnly(subs, plan, cfg, outW, outH, playY, video)
    local path = selectOutputPath(video, outW, outH, ".ass")
    if not path then return end
    local ok, message, stats = writeAdaptedAss(subs, plan, cfg, outW, outH, playY, path)
    if not ok then showMessage(message, "Kiri-Shot - ASS") return end
    showMessage(string.format("ASS adaptado escrito en:\n%s\n\n%d evento(s); %d línea(s) compleja(s) omitida(s); %d división(es) por escenas.",
        path, stats.eventCount or 0, stats.skippedComplex or 0, stats.splitEvents or 0), "Kiri-Shot - ASS")
end

local function exportVideo(subs, plan, cfg, outW, outH, playX, playY, video, temporary)
    local profile, profileName = resolveOutputProfile(cfg)
    local outputPath = selectOutputPath(video, outW, outH, profile.extension)
    if not outputPath then return end
    if samePath(outputPath, video) then
        showMessage("La salida no puede sobrescribir el vídeo de origen.", "Kiri-Shot")
        return
    end

    local folder = dirName(outputPath)
    local tempBase = nextTempBase(folder, baseName(outputPath))

    local audio = sourceAudioPath(video)
    local audioInput
    local hasAudio, probeError = probeAudioStream(audio, cfg, tempBase)
    if hasAudio == nil then
        cleanupPaths(temporary)
        showMessage(probeError, "Kiri-Shot - Audio")
        return
    elseif hasAudio then
        audioInput = samePath(audio, video) and 0 or 1
    elseif cfg.audioTrack > 1 then
        cleanupPaths(temporary)
        showMessage(string.format("No existe la pista de audio %d en el origen. Elige otra pista.", cfg.audioTrack), "Kiri-Shot - Audio")
        return
    end

    local needsAdapted = profile.burnDialogue or profile.softDialogue or cfg.saveASS
    local adaptedPath, adaptedStats
    if needsAdapted then
        adaptedPath = cfg.saveASS and replaceExtension(outputPath, "_subtitles.ass") or (tempBase .. "_adapted.ass")
        if cfg.saveASS then
            local active = activeScriptPath()
            if active ~= "" and samePath(adaptedPath, active) then
                showMessage("El ASS adaptado no puede sobrescribir el guion activo.", "Kiri-Shot - Seguridad")
                return
            end
            if not confirmOverwrite(adaptedPath) then return end
        end
        local adaptedOk, adaptedError
        adaptedOk, adaptedError, adaptedStats = writeAdaptedAss(subs, plan, cfg, outW, outH, playY, adaptedPath)
        if not adaptedOk and adaptedStats and adaptedStats.noEvents then
            adaptedPath = nil
        elseif not adaptedOk then
            showMessage(adaptedError, "Kiri-Shot - Subtítulos")
            return
        elseif not cfg.saveASS then
            temporary[#temporary + 1] = adaptedPath
        end
    end

    local visualPath = tempBase .. "_visual.ass"
    local visualOk, visualError, visualStats = writeSourceVisualAss(subs, plan, playX, playY, visualPath, profile.exactAll)
    if not visualOk and visualStats and visualStats.noEvents then
        visualPath = nil
    elseif not visualOk then
        cleanupPaths(temporary)
        showMessage(visualError, "Kiri-Shot - Carteles y FX")
        return
    else
        temporary[#temporary + 1] = visualPath
    end

    aegisub.progress.title(script_name)
    aegisub.progress.task("Preparando subtítulos y fuentes adjuntas")
    local bundledAdaptedPath = (profile.burnDialogue or profile.softDialogue) and adaptedPath or nil
    temporary[#temporary + 1] = tempBase .. "_subtitles.mkv"
    local bundle, bundleError = createSubtitleBundle(video, visualPath, bundledAdaptedPath, cfg, tempBase)
    if bundleError then
        cleanupPaths(temporary)
        showMessage(bundleError, "Kiri-Shot - Subtítulos")
        return
    end

    local commandPaths, commandError = writeTrajectoryFiles(plan, tempBase, temporary)
    if not commandPaths then
        cleanupPaths(temporary)
        showMessage(commandError, "Kiri-Shot - Trayectoria")
        return
    end

    local visualSubtitle = bundle and bundle.visualStream ~= nil and {path = bundle.path, stream = bundle.visualStream} or nil
    local adaptedSubtitle = bundle and bundle.adaptedStream ~= nil and {path = bundle.path, stream = bundle.adaptedStream} or nil
    local graph, graphError = buildFiltergraph(plan, cfg, outW, outH, audioInput,
        visualSubtitle, profile.burnDialogue and adaptedSubtitle or nil)
    if not graph then
        cleanupPaths(temporary)
        showMessage(graphError, "Kiri-Shot - Filtro")
        return
    end
    local filterPath = tempBase .. "_filter.txt"
    if not writeFile(filterPath, graph) then
        cleanupPaths(temporary)
        showMessage("No se pudo escribir el filtro temporal:\n" .. filterPath, "Kiri-Shot")
        return
    end
    temporary[#temporary + 1] = filterPath
    local renderPath = tempBase .. profile.extension
    temporary[#temporary + 1] = renderPath
    local command = buildExportCommand(video, audio, audioInput, filterPath, renderPath, cfg,
        profile.softDialogue and adaptedSubtitle or nil)
    aegisub.progress.title(script_name)
    aegisub.progress.task("Codificando un único vídeo vertical con FFmpeg")
    local ok, errorMessage = runExportCommand(command, nil, renderPath)
    if ok then
        ok, errorMessage = PyBridge.replaceFile(renderPath, outputPath)
        if not ok then errorMessage = "No se pudo guardar el vídeo terminado:\n" .. tostring(errorMessage) end
    end
    cleanupPaths(temporary)
    if not ok then showMessage(errorMessage, "Kiri-Shot - FFmpeg") return end

    local lines = {
        string.format("Vídeo %dx%d creado en:", outW, outH),
        outputPath,
        "",
        "Perfil: " .. profileName,
        string.format("Escenas: %d | duración final: %.3f s", plan.maskCount, plan.durationMs / 1000),
        string.format("Solapes partidos: %d | huecos omitidos: %d | correcciones Y por cuadro: %d", plan.overlaps, plan.gaps, plan.yCorrections)
    }
    if adaptedStats and (profile.burnDialogue or profile.softDialogue) then
        lines[#lines + 1] = string.format("Diálogo adaptado: %d evento(s), %d división(es).",
            adaptedStats.eventCount or 0, adaptedStats.splitEvents or 0)
    end
    if visualStats and profile.exactAll then
        lines[#lines + 1] = string.format("Composición exacta pegada: %d evento(s), incluidos %d diálogo(s) tradicional(es).",
            visualStats.eventCount or 0, visualStats.traditionalCount or 0)
    elseif visualStats then
        lines[#lines + 1] = string.format("Carteles/FX pegados: %d evento(s), %d dibujo(s) vectorial(es).",
            visualStats.eventCount or 0, visualStats.drawingCount or 0)
    end
    if not hasAudio then lines[#lines + 1] = "El origen no contiene audio; se exportó solo el vídeo." end
    if cfg.saveASS and adaptedPath then lines[#lines + 1] = "ASS adaptado: " .. adaptedPath end
    if needsAdapted and not adaptedPath then lines[#lines + 1] = "No había diálogo tradicional adaptable dentro de las escenas." end
    showMessage(table.concat(lines, "\n"), "Kiri-Shot - Listo")
end

local function editSubtitles(subs, callback, ...)
    local args = {...}
    return LineOps.transaction(subs, nil, function() return callback(subs, unpack(args)) end)
end

local function socialClip(subs, selection, action, cfg)
    if action == "Limpiar vistas Y" then
        local newSelection, removed = editSubtitles(subs, removeYPreviews, selection)
        if removed > 0 then aegisub.set_undo_point(script_name .. " - Limpiar vistas Y") end
        showMessage(string.format("Vistas Y retiradas: %d", removed))
        return newSelection, newSelection[1]
    end
    local video = videoPath()
    if not video then
        showMessage("Carga un vídeo real antes de ejecutar esta tarea.")
        return selection
    end
    local ok, videoW, videoH = pcall(aegisub.video_size)
    videoW, videoH = tonumber(videoW) or 0, tonumber(videoH) or 0
    if not ok or videoW <= 0 or videoH <= 0 then
        showMessage("Aegisub no devolvió una resolución de vídeo válida.")
        return
    end
    local playX, playY = scriptResolution(subs, videoW, videoH)

    local outW, outH, resolutionError = normalizeOutputDimensions(cfg)
    if not outW then showMessage(resolutionError) return end

    if action == "Crear máscaras" then
        local newSelection, message = editSubtitles(subs, createMasks, selection, cfg, videoW, videoH, playX, playY)
        if not newSelection then showMessage(message, "Kiri-Shot - Máscaras") return end
        showMessage(message, "Kiri-Shot - Máscaras")
        return newSelection, newSelection[1]
    end

    if action == "Corregir Y" then
        local correctedSelection, message = editSubtitles(subs, correctSelectedMasksY, selection, cfg, playX, playY, videoW, videoH, outW, outH)
        if not correctedSelection then showMessage(message, "Kiri-Shot - Corregir Y") return end
        showMessage(message, "Kiri-Shot - Corregir Y")
        return correctedSelection, correctedSelection[1]
    end

    local plan, planError = prepareScenePlan(subs, {}, cfg, videoW, videoH, outW, outH)
    if not plan then showMessage(planError, "Kiri-Shot - Escenas") return end
    if action == "Centrar subs X" then
        local centeredSelection, message = editSubtitles(subs, centerSelectedSubtitlesX, selection, plan, playX, playY, videoW)
        if not centeredSelection then showMessage(message, "Kiri-Shot - Centrar X") return end
        showMessage(message, "Kiri-Shot - Centrar X")
        return centeredSelection, centeredSelection[1]
    elseif action == "Solo ASS" then
        exportAssOnly(subs, plan, cfg, outW, outH, playY, video)
    else
        local temporary = {}
        local success, err = pcall(exportVideo, subs, plan, cfg, outW, outH, playX, playY, video, temporary)
        cleanupPaths(temporary)
        if not success then error(err, 0) end
    end
end

return {run=socialClip, presets=presetItems, profiles=outputProfileItems, fps=fpsItems,
    aspects=aspectItems, encoders=x264Presets, bitrates=audioBitrates}
end)()

local Snapshot = (function()
local AssCentisecondMs = 10
local FrameTimeToleranceMs = 1
local MaxFfmpegErrorBytes = 12000
local MaxVideoFrame = 2147483647
local FilenameTextBytes = 96
local CaptureModes = {
  "Selected lines",
  "Frame list",
  "Frame sequence",
  "Clip crop",
  "Manual rectangle",
  "Densest subtitle frame"
}
local TimingModes = {
  "Midpoint",
  "Start and end",
  "Start, middle, end",
  "Current video frame"
}
local ClipOutputs = {
  "Rectangle crop",
  "Clip alpha crop",
  "Clip alpha full frame",
  "Drawing alpha crop",
  "Drawing alpha full frame"
}
local normalizeMode
normalizeMode = function(value)
  if value == "Rectangular clip" then
    return "Clip crop"
  else
    return value
  end
end
local normalizeClipOutput
normalizeClipOutput = function(value)
  local _exp_0 = value
  if "Vector alpha crop" == _exp_0 then
    return "Clip alpha crop"
  elseif "Vector alpha full frame" == _exp_0 then
    return "Clip alpha full frame"
  else
    return value
  end
end
local readFile
readFile = function(path, maxBytes)
  local content = PyBridge.readFile(path, maxBytes)
  return content or ""
end
local snapshotsFolder
snapshotsFolder = function(video)
  return PyBridge.joinPath(projectFolder(video), "Snapshots")
end
local fileTime
fileTime = function(ms)
  ms = math.max(0, LineOps.round(ms))
  local h = math.floor(ms / 3600000)
  local m = math.floor((ms % 3600000) / 60000)
  local s = math.floor((ms % 60000) / 1000)
  local mm = ms % 1000
  return string.format("%02d-%02d-%02d-%03d", h, m, s, mm)
end
local frameSeekTime
frameSeekTime = function(frame)
  local milliseconds = Media.msFromFrame(frame)
  assert(milliseconds, "Could not obtain the video frame timestamp.")
  return Core.formatNumber(math.max(0, milliseconds - FrameTimeToleranceMs) / 1000, 6)
end
local cleanText
cleanText = function(text)
  return LineOps.trim(LineOps.visibleText(text))
end
local lastActiveFrame
lastActiveFrame = function(startMs, endMs)
  local frame = Media.exclusiveEndFrame(startMs, endMs)
  if frame then
    return frame - 1
  else
    return nil
  end
end
local currentVideoFrame
currentVideoFrame = function()
  if not (aegisub.project_properties) then
    return nil
  end
  local ok, props = pcall(aegisub.project_properties)
  if not (ok and props) then
    return nil
  end
  if props.video_position == nil then
    return nil
  end
  local frame = finiteNumber(props.video_position)
  if frame and frame >= 0 and frame <= MaxVideoFrame then
    return math.floor(frame)
  else
    return nil
  end
end
local lineIntervals
lineIntervals = function(lines)
  local raw = { }
  for _index_0 = 1, #lines do
    local line = lines[_index_0]
    local startFrame = Media.frameFromMs(line.start_time)
    local endFrame = lastActiveFrame(line.start_time, line.end_time)
    if startFrame and endFrame then
      if endFrame < startFrame then
        endFrame = startFrame
      end
      table.insert(raw, {
        first = startFrame,
        last = endFrame
      })
    end
  end
  table.sort(raw, function(a, b)
    if a.first == b.first then
      return a.last < b.last
    else
      return a.first < b.first
    end
  end)
  local merged = { }
  for _index_0 = 1, #raw do
    local item = raw[_index_0]
    local last = merged[#merged]
    if last and item.first <= last.last + 1 then
      if item.last > last.last then
        last.last = item.last
      end
    else
      table.insert(merged, {
        first = item.first,
        last = item.last
      })
    end
  end
  return merged
end
local frameInIntervals
frameInIntervals = function(frame, intervals)
  local _list_0 = (intervals or { })
  for _index_0 = 1, #_list_0 do
    local item = _list_0[_index_0]
    if frame >= item.first and frame <= item.last then
      return true
    end
  end
  return false
end
local collectEffectFrames
collectEffectFrames = function(lines, intervals)
  local seen, out = { }, { }
  for _index_0 = 1, #lines do
    local line = lines[_index_0]
    local effect = tostring(line.effect or "")
    for token in effect:gmatch("[^;,%s]+") do
      local raw = token:match("^[Ff]?(%d+)$")
      if not (raw) then
        raw = token:match("^[Ff]?(%d+)[Ff]?$")
      end
      if raw then
        local frame = tonumber(raw)
        if frame and frameInIntervals(frame, intervals) and not seen[frame] then
          seen[frame] = true
          table.insert(out, frame)
        end
      end
    end
  end
  table.sort(out)
  return out
end
local defaultFrameList
defaultFrameList = function(lines)
  if not (lines and #lines > 0) then
    local frame = currentVideoFrame()
    if frame then
      return {
        frame
      }
    else
      return { }
    end
  end
  local intervals = lineIntervals(lines)
  local effectFrames = collectEffectFrames(lines, intervals)
  if #effectFrames > 0 then
    return effectFrames
  end
  local frame = currentVideoFrame()
  if frame and frameInIntervals(frame, intervals) then
    return {
      frame
    }
  end
  local out = { }
  for _index_0 = 1, #intervals do
    local item = intervals[_index_0]
    table.insert(out, item.first)
  end
  return out
end
local parseFrameToken
parseFrameToken = function(token)
  token = LineOps.trim(token)
  if token == "" then
    return nil
  end
  local raw = token:match("^[Ff]?(%d+)[Ff]?$")
  local frame = raw and finiteNumber(raw)
  if frame and frame <= MaxVideoFrame then
    return frame
  else
    return nil
  end
end
local parseFrameList
parseFrameList = function(text)
  local frames, seen, errors = { }, { }, { }
  for rawLine in tostring(text or ""):gmatch("[^\n]+") do
    local line = LineOps.trim(rawLine:gsub("^%-%-%s*", ""))
    if line ~= "" then
      line = line:gsub("%f[%a][Ff][Aa][Dd][Ee]%f[%A]%s+[^,%s;]+", "")
      line = line:match("^(.-)>") or line
      for token in line:gmatch("[^,%s;]+") do
        local frame = parseFrameToken(token)
        if frame then
          if not (seen[frame]) then
            seen[frame] = true
            table.insert(frames, frame)
          end
        else
          table.insert(errors, "Invalid frame token: " .. tostring(token))
        end
      end
    end
  end
  table.sort(frames)
  return frames, errors
end
local buildFrameDefaults
buildFrameDefaults = function(frames)
  local items = { }
  local _list_0 = (frames or { })
  for _index_0 = 1, #_list_0 do
    local frame = _list_0[_index_0]
    table.insert(items, tostring(frame) .. "f")
  end
  return table.concat(items, " ")
end
local lineContainsFrame
lineContainsFrame = function(line, frame)
  if not (line and frame) then
    return false
  end
  local startMs = tonumber(line.start_time) or 0
  local endMs = tonumber(line.end_time) or startMs
  local startFrame = Media.frameFromMs(startMs)
  local endFrame = lastActiveFrame(startMs, endMs)
  return startFrame and endFrame and frame >= startFrame and frame <= endFrame
end
local linePoints
linePoints = function(line, timingMode, currentFrame)
  if currentFrame == nil then
    currentFrame = nil
  end
  local startMs = tonumber(line.start_time) or 0
  local endMs = tonumber(line.end_time) or startMs
  local midMs = startMs + (endMs - startMs) / 2
  if timingMode == "Current video frame" then
    local frame = currentFrame or currentVideoFrame()
    if not (frame) then
      return { }
    end
    frame = math.floor((tonumber(frame) or 0) + 0.5)
    if not (lineContainsFrame(line, frame)) then
      return { }
    end
    local time = Media.msFromFrame(frame)
    if not (time) then
      return { }
    end
    return {
      {
        key = "current",
        label = "current frame",
        time = time,
        frame = frame
      }
    }
  elseif timingMode == "Start and end" then
    local lastFrame = lastActiveFrame(startMs, endMs)
    local lastMs = lastFrame and Media.msFromFrame(lastFrame) or startMs
    return {
      {
        key = "start",
        label = "start",
        time = startMs
      },
      {
        key = "end",
        label = "end",
        time = lastMs
      }
    }
  elseif timingMode == "Start, middle, end" then
    local lastFrame = lastActiveFrame(startMs, endMs)
    local lastMs = lastFrame and Media.msFromFrame(lastFrame) or startMs
    return {
      {
        key = "start",
        label = "start",
        time = startMs
      },
      {
        key = "mid",
        label = "midpoint",
        time = midMs
      },
      {
        key = "end",
        label = "end",
        time = lastMs
      }
    }
  else
    return {
      {
        key = "mid",
        label = "midpoint",
        time = midMs
      }
    }
  end
end
local selectedLines
selectedLines = function(subs, sel)
  local collection = LineCollection(subs, sel, (function(line)
    return line.class == "dialogue" and not line.comment and line.end_time and line.end_time > line.start_time
  end), true)
  local lines = { }
  local _list_0 = collection.lines
  for _index_0 = 1, #_list_0 do
    local line = _list_0[_index_0]
    if line.end_time > line.start_time then
      table.insert(lines, line)
    end
  end
  table.sort(lines, function(a, b)
    return (a.number or 0) < (b.number or 0)
  end)
  return collection, lines
end
local normalizeCrop
normalizeCrop = function(x, y, w, h, padding, videoW, videoH)
  x, y, w, h = finiteNumber(x), finiteNumber(y), finiteNumber(w), finiteNumber(h)
  padding, videoW, videoH = finiteNumber(padding), finiteNumber(videoW), finiteNumber(videoH)
  if not (x and y and w and h and padding and videoW and videoH) then
    return nil
  end
  if w <= 0 or h <= 0 or videoW <= 0 or videoH <= 0 or padding < 0 then
    return nil
  end
  local x1, y1 = math.max(0, math.floor(x - padding)), math.max(0, math.floor(y - padding))
  local x2, y2 = math.min(videoW, math.ceil(x + w + padding)), math.min(videoH, math.ceil(y + h + padding))
  if not (x2 > x1 and y2 > y1) then
    return nil
  end
  return {
    x = x1,
    y = y1,
    w = x2 - x1,
    h = y2 - y1
  }
end
local scaleClipRect
scaleClipRect = function(rect, collection, cfg)
  local videoW, videoH = cfg.videoW, cfg.videoH
  local playX = tonumber(collection.meta and collection.meta.PlayResX) or videoW
  local playY = tonumber(collection.meta and collection.meta.PlayResY) or videoH
  local sx
  if playX > 0 then
    sx = videoW / playX
  else
    sx = 1
  end
  local sy
  if playY > 0 then
    sy = videoH / playY
  else
    sy = 1
  end
  local x1 = math.min(rect.x1, rect.x2) * sx
  local y1 = math.min(rect.y1, rect.y2) * sy
  local x2 = math.max(rect.x1, rect.x2) * sx
  local y2 = math.max(rect.y1, rect.y2) * sy
  return normalizeCrop(x1, y1, x2 - x1, y2 - y1, cfg.cropPadding, videoW, videoH)
end
local manualCrop
manualCrop = function(cfg)
  return normalizeCrop(cfg.manualX, cfg.manualY, cfg.manualW, cfg.manualH, cfg.cropPadding, cfg.videoW, cfg.videoH)
end
local extendBounds
extendBounds = function(bounds, x, y)
  x, y = finiteNumber(x), finiteNumber(y)
  if not (x and y) then
    return false
  end
  if bounds.x1 == nil then
    bounds.x1, bounds.x2 = x, x
    bounds.y1, bounds.y2 = y, y
  else
    bounds.x1 = math.min(bounds.x1, x)
    bounds.y1 = math.min(bounds.y1, y)
    bounds.x2 = math.max(bounds.x2, x)
    bounds.y2 = math.max(bounds.y2, y)
  end
  return true
end
local boundsRect
boundsRect = function(bounds)
  if not (bounds and bounds.x1 ~= nil and bounds.y1 ~= nil and bounds.x2 ~= nil and bounds.y2 ~= nil) then
    return nil
  end
  return {
    x1 = bounds.x1,
    y1 = bounds.y1,
    x2 = bounds.x2,
    y2 = bounds.y2
  }
end
local rectFromPayload
rectFromPayload = function(payload)
  local values = LineOps.splitArguments(payload)
  if not (#values == 4) then
    return nil
  end
  local numbers = { }
  for _index_0 = 1, #values do
    local value = values[_index_0]
    local number = finiteNumber(value)
    if not (number) then
      return nil
    end
    numbers[#numbers + 1] = number
  end
  return {
    x1 = numbers[1],
    y1 = numbers[2],
    x2 = numbers[3],
    y2 = numbers[4]
  }
end
local clipInfoFromPayload
clipInfoFromPayload = function(name, payload)
  payload = LineOps.trim(payload)
  local body, scale = payload, 1
  local rawScale, drawing = payload:match("^([^,]+),%s*([mMnN].*)$")
  if rawScale then
    scale, body = finiteNumber(rawScale), drawing
    if not (scale and scale >= 1 and scale == math.floor(scale)) then
      return nil
    end
  end
  local vector = body:match("^[mMnN]%s") ~= nil
  local rect
  if vector then
    body = body:lower()
    if not (AssDrawing.validatePath(body)) then
      return nil
    end
    local divisor = finiteNumber(2 ^ (scale - 1))
    if not (divisor and divisor > 0) then
      return nil
    end
    local bounds, x = { }, nil
    for token in body:gmatch("%S+") do
      local number = finiteNumber(token)
      if number then
        if x == nil then
          x = number
        else
          LineOps.checkCancelled()
          extendBounds(bounds, x / divisor, number / divisor)
          x = nil
        end
      end
    end
    rect = boundsRect(bounds)
    if scale == 1 then
      payload = body
    else
      payload = tostring(Core.formatNumber(scale, 0)) .. "," .. tostring(body)
    end
  else
    rect = rectFromPayload(payload)
  end
  if not (rect) then
    return nil
  end
  return {
    rect = rect,
    tag = "\\" .. tostring(name) .. "(" .. tostring(payload) .. ")",
    isVector = vector,
    inverse = name == "iclip"
  }
end
local relevantClipEntries
relevantClipEntries = function(text)
  local entries = { }
  local _list_0 = LineOps.tagCalls(text, {
    clip = true,
    iclip = true
  })
  for _index_0 = 1, #_list_0 do
    local call = _list_0[_index_0]
    if call.top_level then
      table.insert(entries, {
        start = call.start,
        raw = call.raw,
        static = true
      })
    end
  end
  local _list_1 = LineOps.tagCalls(text, "t")
  for _index_0 = 1, #_list_1 do
    local _continue_0 = false
    repeat
      local transform = _list_1[_index_0]
      if not (transform.top_level) then
        _continue_0 = true
        break
      end
      local clips = LineOps.tagCalls("{" .. tostring(transform.raw) .. "}", {
        clip = true,
        iclip = true
      })
      if #clips == 0 then
        _continue_0 = true
        break
      end
      local value = tostring(transform.value or "")
      if value:sub(1, 1) == "(" and value:sub(-1) == ")" then
        value = value:sub(2, -2)
      end
      local firstTag = value:find("\\", 1, true)
      if not (firstTag) then
        _continue_0 = true
        break
      end
      local prefix = value:sub(1, firstTag - 1)
      local clipTags
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_1 = 1, #clips do
          local call = clips[_index_1]
          _accum_0[_len_0] = call.raw
          _len_0 = _len_0 + 1
        end
        clipTags = _accum_0
      end
      table.insert(entries, {
        start = transform.start,
        raw = "\\t(" .. tostring(prefix) .. tostring(table.concat(clipTags, '')) .. ")",
        animated = true
      })
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  table.sort(entries, function(a, b)
    return a.start < b.start
  end)
  return entries
end
local clipInfoFromTags
clipInfoFromTags = function(text)
  local entries = relevantClipEntries(text)
  local info = nil
  for _index_0 = 1, #entries do
    local entry = entries[_index_0]
    if entry.static then
      local name, raw = entry.raw:match("^\\(i?clip)%s*(%b())$")
      local parsed
      if name and raw then
        parsed = clipInfoFromPayload(name, raw:sub(2, -2))
      end
      if parsed then
        info = parsed
      end
    end
  end
  if info then
    info.entries = entries
    for _index_0 = 1, #entries do
      local item = entries[_index_0]
      if item.animated then
        info.animated = true
      end
    end
  end
  return info
end
local lineClipInfo
lineClipInfo = function(line, playX, playY)
  local info = clipInfoFromTags(line.text)
  if info then
    return info
  end
  local entries = relevantClipEntries(line.text)
  if #entries == 0 or not playX or not playY then
    return nil
  end
  info = clipInfoFromPayload("clip", "0,0," .. tostring(playX) .. "," .. tostring(playY))
  info.entries, info.animated = entries, true
  return info
end
local drawingMaskText
drawingMaskText = function(line)
  local parts, hasDrawing = { }, false
  local _list_0 = LineOps.scanSections(line and line.text or "")
  for _index_0 = 1, #_list_0 do
    local section = _list_0[_index_0]
    if section.type == "drawing" then
      parts[#parts + 1] = section.text
      if LineOps.trim(section.text) ~= "" then
        hasDrawing = true
      end
    elseif section.type == "override" or section.type == "comment" then
      parts[#parts + 1] = "{" .. tostring(section.text) .. "}"
    end
  end
  if hasDrawing then
    return table.concat(parts)
  else
    return nil
  end
end
local lineDrawingInfo
lineDrawingInfo = function(line)
  local text = drawingMaskText(line)
  if not (text) then
    return nil
  end
  return {
    text = text
  }
end
local densestFrame
densestFrame = function(lines)
  local events = { }
  for _index_0 = 1, #lines do
    local _continue_0 = false
    repeat
      local line = lines[_index_0]
      LineOps.checkCancelled()
      local startFrame = Media.frameFromMs(line.start_time)
      local endFrame = lastActiveFrame(line.start_time, line.end_time)
      if not (startFrame and endFrame) then
        _continue_0 = true
        break
      end
      endFrame = math.max(startFrame, endFrame)
      table.insert(events, {
        frame = startFrame,
        delta = 1
      })
      table.insert(events, {
        frame = endFrame + 1,
        delta = -1
      })
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  table.sort(events, function(a, b)
    if a.frame == b.frame then
      return a.delta > b.delta
    else
      return a.frame < b.frame
    end
  end)
  local active, bestCount, bestFrame = 0, 0, nil
  local i = 1
  while i <= #events do
    local frame = events[i].frame
    while i <= #events and events[i].frame == frame do
      active = active + events[i].delta
      i = i + 1
    end
    if active > bestCount then
      bestCount = active
      bestFrame = frame
    end
  end
  return bestFrame, bestCount
end
local shotName
shotName = function(seq, line, point, _mode, includeText, extra)
  if extra == nil then
    extra = nil
  end
  local parts = {
    string.format("%04d", seq),
    line and string.format("L%04d", line.number or 0) or "dense",
    point.key,
    fileTime(point.time)
  }
  if extra then
    table.insert(parts, extra)
  end
  if includeText and line then
    local units, bytes = { }, 0
    local _list_0 = LineOps.graphemes(safeName(cleanText(line.text), ""))
    for _index_0 = 1, #_list_0 do
      local unit = _list_0[_index_0]
      if bytes + #unit > FilenameTextBytes then
        break
      end
      units[#units + 1], bytes = unit, bytes + #unit
    end
    local label = table.concat(units)
    if label ~= "" then
      table.insert(parts, label)
    end
  end
  return table.concat(parts, "_") .. ".png"
end
local frameShotName
frameShotName = function(seq, frame, time)
  return string.format("%04d_F%06d_%s.png", seq, frame, fileTime(time))
end
local clipOutputExtra
clipOutputExtra = function(clipOutput)
  local _exp_0 = clipOutput
  if "Clip alpha crop" == _exp_0 then
    return "clip_alpha_crop"
  elseif "Clip alpha full frame" == _exp_0 then
    return "clip_alpha_full"
  elseif "Drawing alpha crop" == _exp_0 then
    return "drawing_alpha_crop"
  elseif "Drawing alpha full frame" == _exp_0 then
    return "drawing_alpha_full"
  else
    return "crop"
  end
end
local drawRectShape
drawRectShape = function(w, h)
  w = math.floor((tonumber(w) or 1) + 0.5)
  h = math.floor((tonumber(h) or 1) + 0.5)
  return "m 0 0 l " .. tostring(w) .. " 0 " .. tostring(w) .. " " .. tostring(h) .. " 0 " .. tostring(h)
end
local clipMaskText
clipMaskText = function(clipInfo, playX, playY)
  local entries = clipInfo.entries or { }
  local tags = table.concat((function()
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #entries do
      local entry = entries[_index_0]
      _accum_0[_len_0] = entry.raw
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)(), "")
  local hasStatic = false
  for _index_0 = 1, #entries do
    local entry = entries[_index_0]
    if entry.static then
      hasStatic = true
    end
  end
  if not (hasStatic) then
    tags = clipInfo.tag .. tags
  end
  return "{\\an7\\pos(0,0)\\p1\\bord0\\shad0\\blur0\\1c&HFFFFFF&\\alpha&H00&" .. tostring(tags) .. "}" .. tostring(drawRectShape(playX, playY))
end
local makeJobs
makeJobs = function(collection, lines, cfg)
  local jobs, skipped, errors, seq = { }, { }, { }, 0
  local mode = normalizeMode(cfg.mode)
  if mode == "Frame list" then
    local frames, parseErrors = parseFrameList(cfg.frameText)
    if #parseErrors > 0 then
      return jobs, skipped, parseErrors
    end
    if #frames == 0 then
      return jobs, skipped, {
        "No valid frames were listed."
      }
    end
    for _index_0 = 1, #frames do
      local frame = frames[_index_0]
      local time = Media.msFromFrame(frame)
      if time then
        seq = seq + 1
        table.insert(jobs, {
          time = time,
          frame = frame,
          name = frameShotName(seq, frame, time),
          subtitle = "",
          label = "frame " .. tostring(frame),
          mode = mode
        })
      else
        table.insert(errors, "Could not convert frame to milliseconds: " .. tostring(frame))
      end
    end
    return jobs, skipped, errors
  end
  if not (lines and #lines > 0) then
    return jobs, skipped, {
      "Select at least one timed dialogue line."
    }
  end
  local manualRect
  if mode == "Manual rectangle" then
    manualRect = manualCrop(cfg)
  end
  if mode == "Manual rectangle" and not manualRect then
    return jobs, skipped, {
      "The manual rectangle does not intersect the video."
    }
  end
  local currentFrame = nil
  if cfg.timing == "Current video frame" then
    currentFrame = currentVideoFrame()
    if not (currentFrame) then
      return jobs, skipped, {
        "Current video frame is unavailable. Open a video and place the playhead on the frame you want."
      }
    end
  end
  if mode == "Densest subtitle frame" then
    local frame, count = densestFrame(lines)
    if not (frame) then
      return jobs, skipped, errors
    end
    local time = Media.msFromFrame(frame)
    seq = seq + 1
    table.insert(jobs, {
      time = time,
      frame = frame,
      name = shotName(seq, nil, {
        key = "dense",
        time = time
      }, mode, false, tostring(count) .. "lines"),
      subtitle = "",
      label = "densest frame",
      mode = mode,
      overlap = count
    })
    return jobs, skipped, errors
  end
  local currentFrameTouchesLine = false
  for _index_0 = 1, #lines do
    local _continue_0 = false
    repeat
      local line = lines[_index_0]
      LineOps.checkCancelled()
      local rect = nil
      local alphaMaskText, alphaDetectCrop = nil, false
      if currentFrame and lineContainsFrame(line, currentFrame) then
        currentFrameTouchesLine = true
      end
      if mode == "Clip crop" then
        if cfg.clipOutput == "Drawing alpha crop" or cfg.clipOutput == "Drawing alpha full frame" then
          local drawingInfo = lineDrawingInfo(line)
          if drawingInfo then
            alphaMaskText = drawingInfo.text
            alphaDetectCrop = cfg.clipOutput == "Drawing alpha crop"
          else
            table.insert(skipped, line.number)
            _continue_0 = true
            break
          end
        else
          local clipInfo = lineClipInfo(line, cfg.playX, cfg.playY)
          if clipInfo and clipInfo.rect then
            if cfg.clipOutput == "Clip alpha crop" then
              alphaMaskText = clipMaskText(clipInfo, cfg.playX, cfg.playY)
              alphaDetectCrop = true
            elseif cfg.clipOutput == "Clip alpha full frame" then
              alphaMaskText = clipMaskText(clipInfo, cfg.playX, cfg.playY)
            else
              if clipInfo.inverse then
                table.insert(errors, "Line " .. tostring(line.number) .. ": Rectangle crop cannot represent \\iclip. Choose Clip alpha crop/full frame.")
                _continue_0 = true
                break
              end
              if clipInfo.animated then
                table.insert(errors, "Line " .. tostring(line.number) .. ": Rectangle crop cannot follow an animated clip. Choose Clip alpha crop/full frame.")
                _continue_0 = true
                break
              end
              rect = scaleClipRect(clipInfo.rect, collection, cfg)
              if not (rect) then
                table.insert(errors, "Line " .. tostring(line.number) .. ": the clip does not intersect the video.")
                _continue_0 = true
                break
              end
            end
          else
            table.insert(skipped, line.number)
            _continue_0 = true
            break
          end
        end
      elseif mode == "Manual rectangle" then
        rect = manualRect
      end
      local points = linePoints(line, cfg.timing, currentFrame)
      if #points == 0 then
        _continue_0 = true
        break
      end
      for _index_1 = 1, #points do
        local point = points[_index_1]
        seq = seq + 1
        local extra
        if rect or alphaMaskText then
          extra = clipOutputExtra(cfg.clipOutput)
        else
          extra = nil
        end
        local maskDurationMs = math.max(1, (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0))
        local maskStartMs = tonumber(line.start_time) or 0
        table.insert(jobs, {
          time = point.time,
          frame = point.frame or Media.frameFromMs(point.time),
          name = shotName(seq, line, point, mode, cfg.includeText, extra),
          subtitle = line.number,
          label = point.label,
          mode = mode,
          crop = rect,
          alphaMaskText = alphaMaskText,
          maskSource = (function()
            if cfg.clipOutput == "Drawing alpha crop" or cfg.clipOutput == "Drawing alpha full frame" then
              return line
            else
              return nil
            end
          end)(),
          alphaDetectCrop = alphaDetectCrop,
          maskDurationMs = maskDurationMs,
          maskStartMs = maskStartMs
        })
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  if cfg.timing == "Current video frame" and #jobs == 0 and not currentFrameTouchesLine then
    table.insert(errors, "The current video frame is not inside any selected line.")
  end
  return jobs, skipped, errors
end
local cropFilter
cropFilter = function(crop)
  return string.format("crop=%d:%d:%d:%d", crop.w, crop.h, crop.x, crop.y)
end
local runCommand
runCommand = function(command, errPath)
  if errPath == nil then
    errPath = nil
  end
  local ok, output, exitCode = PyBridge.runProcess(command)
  if errPath and errPath ~= "" then
    PyBridge.writeFile(errPath, output or "")
  end
  return ok, output, exitCode
end
local ffmpegErrorPath
ffmpegErrorPath = function(outDir, job, suffix)
  if suffix == nil then
    suffix = "error"
  end
  return PyBridge.joinPath(outDir, "_snapshoter_ffmpeg_" .. tostring(safeName(baseName(job.name), "capture")) .. "_" .. tostring(suffix) .. ".txt")
end
local ffmpegErrorMessage
ffmpegErrorMessage = function(label, path, errPath)
  local details = LineOps.trim(readFile(errPath, 6000))
  local message = "FFmpeg returned an error while " .. tostring(label) .. ":\n" .. tostring(path)
  if details ~= "" then
    message = message .. "\n\nFFmpeg:\n" .. tostring(details)
  else
    message = message .. "\n\nFFmpeg did not return diagnostic output."
  end
  return message
end
local runFfmpeg
runFfmpeg = function(command, outDir, job, label, path)
  local errPath = ffmpegErrorPath(outDir, job, safeName(label, "error"))
  local ok, _, exitCode = runCommand(command, errPath)
  if ok and Media.verifyPng(path) then
    PyBridge.removeFile(errPath)
    return true, nil
  end
  if ok then
    PyBridge.writeFile(errPath, "FFmpeg exited successfully but did not create a non-empty output file.")
  end
  local message = ffmpegErrorMessage(label, path, errPath)
  PyBridge.removeFile(errPath)
  PyBridge.removeFile(path)
  return false, (function()
    if exitCode == 130 then
      return "Capture cancelled."
    else
      return message
    end
  end)()
end
local maskAssPath
maskAssPath = function(outDir, job)
  return PyBridge.joinPath(outDir, "_snapshoter_mask_" .. tostring(safeName(baseName(job.name), "mask")) .. ".ass")
end
local alphaTempPath
alphaTempPath = function(outDir, job)
  return PyBridge.joinPath(outDir, "_snapshoter_alpha_" .. tostring(safeName(baseName(job.name), "alpha")) .. ".png")
end
local maskAssText
maskAssText = function(text)
  text = tostring(text or ""):gsub("\r\n", "\\N")
  return text:gsub("[\r\n]", "\\N")
end
local writeMaskAss
writeMaskAss = function(path, maskText, playX, playY, durationMs, sourceLine, styles, scriptInfo, startMs)
  if sourceLine == nil then
    sourceLine = nil
  end
  if styles == nil then
    styles = nil
  end
  if scriptInfo == nil then
    scriptInfo = nil
  end
  if startMs == nil then
    startMs = 0
  end
  if not (finiteNumber(playX) and finiteNumber(playY) and playX > 0 and playY > 0) then
    return false
  end
  durationMs = math.max(AssCentisecondMs, finiteNumber(durationMs) or 1000)
  local info = scriptInfo or {
    {
      class = "info",
      key = "ScriptType",
      value = "v4.00+"
    },
    {
      class = "info",
      key = "PlayResX",
      value = tostring(playX)
    },
    {
      class = "info",
      key = "PlayResY",
      value = tostring(playY)
    }
  }
  local line
  if sourceLine then
    line = ASSParser.create_dialogue_line({
      style = sourceLine.style,
      margin_l = sourceLine.margin_l,
      margin_r = sourceLine.margin_r,
      margin_t = sourceLine.margin_t,
      text = maskAssText(maskText),
      end_time = durationMs
    })
  else
    line = ASSParser.create_dialogue_line({
      text = maskAssText(maskText),
      end_time = durationMs,
      style = "Mask"
    })
  end
  line.start_time = startMs
  line.end_time = startMs + durationMs
  local outputStyles
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = (styles or { })
    for _index_0 = 1, #_list_0 do
      local style = _list_0[_index_0]
      _accum_0[_len_0] = style
      _len_0 = _len_0 + 1
    end
    outputStyles = _accum_0
  end
  if not (sourceLine) then
    outputStyles[#outputStyles + 1] = ASSParser.create_style_line({
      name = "Mask",
      align = 7,
      outline = 0,
      shadow = 0,
      margin_l = 0,
      margin_r = 0,
      margin_t = 0
    })
  end
  local chunks = { }
  ASSParser.generate_file(info, nil, outputStyles, {
    line
  }, { }, function(chunk)
    chunks[#chunks + 1] = chunk
  end)
  return PyBridge.writeFile(path, table.concat(chunks))
end
local jobFrame
jobFrame = function(job)
  local frame = finiteNumber(job.frame) or Media.frameFromMs(job.time)
  assert(frame and frame >= 0 and frame <= MaxVideoFrame and frame == math.floor(frame), "Invalid video frame.")
  return frame
end
local captureCommand
captureCommand = function(video, ffmpeg, job, outPath)
  local arguments = {
    "-hide_banner",
    "-nostdin",
    "-loglevel",
    "error",
    "-y",
    "-ss",
    frameSeekTime(jobFrame(job)),
    "-i",
    video,
    "-map",
    "0:V:0",
    "-an",
    "-frames:v",
    "1",
    "-fps_mode",
    "passthrough"
  }
  if job.crop then
    arguments[#arguments + 1] = "-vf"
    arguments[#arguments + 1] = cropFilter(job.crop)
  end
  arguments[#arguments + 1] = outPath
  return {
    executable = ffmpegExecutable(ffmpeg),
    args = arguments
  }
end
local alphaCaptureCommand
alphaCaptureCommand = function(video, ffmpeg, job, outPath, maskPath, _videoW, _videoH)
  local assFilter = filterPathQuote(maskPath)
  local filter = "[0:V:0]split[base][maskSource];[maskSource]format=rgba,colorchannelmixer=rr=0:gg=0:bb=0:aa=0,subtitles=" .. tostring(assFilter) .. ":alpha=1,alphaextract[mask];[base]format=rgba[baseRgba];[baseRgba][mask]alphamerge[out]"
  return {
    executable = ffmpegExecutable(ffmpeg),
    args = {
      "-hide_banner",
      "-nostdin",
      "-loglevel",
      "error",
      "-y",
      "-copyts",
      "-ss",
      frameSeekTime(jobFrame(job)),
      "-i",
      video,
      "-filter_complex",
      filter,
      "-map",
      "[out]",
      "-frames:v",
      "1",
      outPath
    }
  }
end
local alphaBoundsCommand
alphaBoundsCommand = function(ffmpeg, imagePath)
  return {
    executable = ffmpegExecutable(ffmpeg),
    args = {
      "-hide_banner",
      "-loglevel",
      "info",
      "-y",
      "-i",
      imagePath,
      "-vf",
      "alphaextract,bbox=min_val=0",
      "-frames:v",
      "1",
      "-f",
      "null",
      "-"
    }
  }
end
local parseAlphaBounds
parseAlphaBounds = function(text)
  local crop = nil
  for w, h, x, y in tostring(text or ""):gmatch("crop=(%d+):(%d+):(%d+):(%d+)") do
    crop = {
      w = tonumber(w),
      h = tonumber(h),
      x = tonumber(x),
      y = tonumber(y)
    }
  end
  return crop
end
local detectAlphaCrop
detectAlphaCrop = function(ffmpeg, imagePath, outDir, job)
  local errPath = ffmpegErrorPath(outDir, job, "alpha_bounds")
  local ok = runCommand(alphaBoundsCommand(ffmpeg, imagePath), errPath)
  local details = readFile(errPath, MaxFfmpegErrorBytes)
  PyBridge.removeFile(errPath)
  local detailsText = LineOps.trim(details)
  if not (ok) then
    return nil, "FFmpeg returned an error while detecting alpha bounds:\n" .. tostring(imagePath) .. "\n\nFFmpeg:\n" .. tostring(detailsText)
  end
  local crop = parseAlphaBounds(details)
  if not (crop) then
    return nil, "FFmpeg could not detect a non-transparent alpha area in:\n" .. tostring(imagePath)
  end
  return crop, nil
end
local cropPngCommand
cropPngCommand = function(ffmpeg, imagePath, crop, outPath)
  return {
    executable = ffmpegExecutable(ffmpeg),
    args = {
      "-hide_banner",
      "-loglevel",
      "error",
      "-y",
      "-i",
      imagePath,
      "-vf",
      cropFilter(crop),
      "-frames:v",
      "1",
      outPath
    }
  }
end
local runCaptureJobs
runCaptureJobs = function(video, outDir, cfg, jobs)
  local made, makeError = PyBridge.ensureDir(outDir)
  if not (made) then
    return false, "Could not create output folder: " .. tostring(makeError or outDir)
  end
  local total = #jobs
  for index, job in ipairs(jobs) do
    LineOps.progress("Capturing " .. tostring(index) .. "/" .. tostring(total), 100 * (index - 1) / math.max(1, total))
    local outPath = PyBridge.joinPath(outDir, job.name)
    local maskPath
    if job.alphaMaskText then
      maskPath = maskAssPath(outDir, job)
    end
    local tempPath
    if job.alphaDetectCrop then
      tempPath = alphaTempPath(outDir, job)
    end
    local protected, ok, message = pcall(function()
      if not (job.alphaMaskText) then
        return runFfmpeg(captureCommand(video, cfg.ffmpeg, job, outPath), outDir, job, "writing PNG", outPath)
      end
      local written = writeMaskAss(maskPath, job.alphaMaskText, cfg.playX, cfg.playY, job.maskDurationMs, job.maskSource, cfg.styles, cfg.scriptInfo, job.maskStartMs or 0)
      if not (written) then
        return false, "Kiri-Shot could not write the temporary vector mask."
      end
      local alphaPath = tempPath or outPath
      local captured, failure = runFfmpeg(alphaCaptureCommand(video, cfg.ffmpeg, job, alphaPath, maskPath, cfg.videoW, cfg.videoH), outDir, job, "writing alpha PNG", alphaPath)
      if not (captured) then
        return false, failure
      end
      if tempPath then
        local crop
        crop, failure = detectAlphaCrop(cfg.ffmpeg, tempPath, outDir, job)
        if not (crop) then
          return false, failure
        end
        return runFfmpeg(cropPngCommand(cfg.ffmpeg, tempPath, crop, outPath), outDir, job, "writing cropped PNG", outPath)
      end
      return true
    end)
    if maskPath then
      PyBridge.removeFile(maskPath)
    end
    if tempPath then
      PyBridge.removeFile(tempPath)
    end
    if not (protected and ok) then
      PyBridge.removeFile(outPath)
    end
    if not (protected) then
      error(ok, 0)
    end
    if not (ok) then
      return false, message
    end
  end
  LineOps.progress("Capture complete", 100)
  return true, nil
end
local dialogueAssLine
dialogueAssLine = function(line, range)
  if not (line and line.class == "dialogue" and not line.comment) then
    return nil
  end
  local startMs, endMs = finiteNumber(line.start_time), finiteNumber(line.end_time)
  if not (startMs and endMs and endMs > startMs and endMs > range.startMs and startMs < range.endMs) then
    return nil
  end
  return ASSParser.line_to_raw(line)
end
local sequenceRange
sequenceRange = function(lines)
  local intervals = lineIntervals(lines)
  if not (#intervals > 0) then
    return nil
  end
  local startFrame = intervals[1].first
  local endFrame = intervals[1].last
  for _index_0 = 1, #intervals do
    local item = intervals[_index_0]
    startFrame = math.min(startFrame, item.first)
    endFrame = math.max(endFrame, item.last)
  end
  local startMs = Media.msFromFrame(startFrame)
  local endMs = Media.msFromFrame(endFrame + 1)
  if not (startMs and endMs and endMs > startMs) then
    return nil
  end
  return {
    startFrame = startFrame,
    endFrame = endFrame,
    frameCount = endFrame - startFrame + 1,
    startMs = startMs,
    endMs = endMs,
    durationMs = endMs - startMs
  }
end
local writeSequenceAss
writeSequenceAss = function(subs, assPath, range, videoW, videoH)
  local rows = {
    "[Script Info]"
  }
  local hasScriptType, hasPlayResX, hasPlayResY = false, false, false
  for i = 1, #subs do
    LineOps.checkCancelled()
    local line = subs[i]
    if line and line.class == "info" and line.key and (not line.section or line.section == "[Script Info]") then
      local key = LineOps.trim(line.key)
      local value = tostring(line.value or "")
      if key ~= "" then
        local lower = key:lower()
        if lower == "scripttype" then
          hasScriptType = true
        end
        if lower == "playresx" then
          hasPlayResX = true
        end
        if lower == "playresy" then
          hasPlayResY = true
        end
        table.insert(rows, tostring(key) .. ": " .. tostring(value))
      end
    end
  end
  if not (hasScriptType) then
    table.insert(rows, "ScriptType: v4.00+")
  end
  if not (hasPlayResX or videoW <= 0) then
    table.insert(rows, "PlayResX: " .. tostring(Core.formatNumber(videoW, 0)))
  end
  if not (hasPlayResY or videoH <= 0) then
    table.insert(rows, "PlayResY: " .. tostring(Core.formatNumber(videoH, 0)))
  end
  table.insert(rows, "")
  table.insert(rows, "[V4+ Styles]")
  table.insert(rows, "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding")
  local styleCount = 0
  for i = 1, #subs do
    LineOps.checkCancelled()
    local line = subs[i]
    if line and line.class == "style" then
      table.insert(rows, ASSParser.line_to_raw(line))
      styleCount = styleCount + 1
    end
  end
  if styleCount == 0 then
    table.insert(rows, ASSParser.line_to_raw(ASSParser.create_style_line()))
  end
  table.insert(rows, "")
  table.insert(rows, "[Events]")
  table.insert(rows, "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text")
  local rendered = 0
  for i = 1, #subs do
    LineOps.checkCancelled()
    local line = subs[i]
    local row = dialogueAssLine(line, range)
    if row then
      table.insert(rows, row)
      rendered = rendered + 1
    end
  end
  local ok = PyBridge.writeFile(assPath, table.concat(rows, "\n"))
  return ok, rendered
end
local sequenceOutputs
sequenceOutputs = function(cfg)
  return {
    clean = (function()
      if cfg.captureClean == nil then
        return true
      else
        return cfg.captureClean == true
      end
    end)(),
    withSubtitles = cfg.captureWithSubtitles == true,
    subtitlesOnly = cfg.captureSubtitlesOnly == true
  }
end
local sequenceOutputCount
sequenceOutputCount = function(outputs)
  local count = 0
  if outputs.clean then
    count = count + 1
  end
  if outputs.withSubtitles then
    count = count + 1
  end
  if outputs.subtitlesOnly then
    count = count + 1
  end
  return count
end
local runId
runId = function(prefix)
  local suffix
  if PyBridge.uniqueSuffix then
    suffix = PyBridge.uniqueSuffix()
  else
    suffix = tostring(os.time())
  end
  return safeName(tostring(prefix) .. "_" .. tostring(os.date("%Y%m%d_%H%M%S")) .. "_" .. tostring(suffix), "snapshoter")
end
local prefixJobNames
prefixJobNames = function(jobs, prefix)
  if not (jobs and prefix and prefix ~= "") then
    return
  end
  for _index_0 = 1, #jobs do
    local job = jobs[_index_0]
    if job and job.name then
      job.name = tostring(prefix) .. "_" .. tostring(job.name)
    end
  end
end
local captureBatchFolder
captureBatchFolder = function(jobs)
  local first = jobs and jobs[1]
  local prefix
  if first and first.mode then
    prefix = first.mode
  else
    prefix = "captures"
  end
  return runId(prefix)
end
local sequenceFolderName
sequenceFolderName = function(range)
  return runId(string.format("sequence_%06d-%06d", range.startFrame, range.endFrame))
end
local sequenceOutputItems
sequenceOutputItems = function(outputs, assPath)
  local items = { }
  if outputs.clean then
    table.insert(items, {
      key = "clean",
      label = "No subtitles",
      filter = ""
    })
  end
  if outputs.withSubtitles or outputs.subtitlesOnly then
    local assFilter = filterPathQuote(assPath)
    if outputs.withSubtitles then
      table.insert(items, {
        key = "with_subtitles",
        label = "With subtitles",
        filter = "subtitles=" .. tostring(assFilter)
      })
    end
    if outputs.subtitlesOnly then
      table.insert(items, {
        key = "subtitles_only",
        label = "Subtitles only",
        filter = "format=rgba,colorchannelmixer=aa=0,subtitles=" .. tostring(assFilter) .. ":alpha=1,format=rgba"
      })
    end
  end
  return items
end
local sequenceCommand
sequenceCommand = function(video, ffmpeg, range, filter, pattern)
  local filters = { }
  if filter and filter ~= "" then
    filters[#filters + 1] = filter
  end
  filters[#filters + 1] = "setpts=PTS-STARTPTS"
  return {
    executable = ffmpegExecutable(ffmpeg),
    args = {
      "-hide_banner",
      "-nostdin",
      "-loglevel",
      "error",
      "-y",
      "-copyts",
      "-ss",
      frameSeekTime(range.startFrame),
      "-i",
      video,
      "-map",
      "0:V:0",
      "-an",
      "-vf",
      table.concat(filters, ","),
      "-frames:v",
      tostring(range.frameCount),
      "-start_number",
      tostring(range.startFrame),
      "-fps_mode",
      "passthrough",
      pattern
    }
  }
end
local sequenceOutputDir
sequenceOutputDir = function(snapshotsDir, sequenceDir, itemCount, item, flatten)
  if flatten then
    return snapshotsDir
  end
  if itemCount == 1 then
    return sequenceDir
  end
  return PyBridge.joinPath(sequenceDir, item.key)
end
local sequenceOutputPattern
sequenceOutputPattern = function(dir, item, _range, flatten, sequenceName)
  if flatten then
    return PyBridge.joinPath(dir, tostring(sequenceName) .. "_" .. tostring(item.key) .. "_%06d.png")
  else
    return PyBridge.joinPath(dir, "frame_%06d.png")
  end
end
local sequenceFramePath
sequenceFramePath = function(pattern, frame)
  local path, count = tostring(pattern or ""):gsub("%%06d", string.format("%06d", frame), 1)
  if count == 1 then
    return path
  else
    return nil
  end
end
local sequenceOutputComplete
sequenceOutputComplete = function(pattern, range)
  for frame = range.startFrame, range.endFrame do
    LineOps.checkCancelled()
    local path = sequenceFramePath(pattern, frame)
    if not (path and Media.verifyPng(path)) then
      return false
    end
  end
  return true
end
local runFrameSequence
runFrameSequence = function(subs, lines, video, outDir, cfg)
  if not (lines and #lines > 0) then
    return false, "Select at least one timed dialogue line for Frame sequence."
  end
  local range = sequenceRange(lines)
  if not (range) then
    return false, "Could not build a frame range from the selected lines."
  end
  local made, makeError = PyBridge.ensureDir(outDir)
  if not (made) then
    return false, "Could not create output folder: " .. tostring(makeError or outDir)
  end
  local outputs = sequenceOutputs(cfg)
  if sequenceOutputCount(outputs) == 0 then
    return false, "Select at least one Frame sequence output."
  end
  local sequenceName = sequenceFolderName(range)
  local assPath, rendered = "", 0
  if outputs.withSubtitles or outputs.subtitlesOnly then
    assPath = PyBridge.joinPath(outDir, "_snapshoter_" .. tostring(sequenceName) .. ".ass")
    local ok, count = writeSequenceAss(subs, assPath, range, cfg.videoW, cfg.videoH)
    if not (ok) then
      PyBridge.removeFile(assPath)
      return false, "Kiri-Shot could not write the temporary ASS file."
    end
    rendered = count
  end
  aegisub.progress.title(script_name)
  aegisub.progress.task("Extracting frame sequence with FFmpeg")
  local sequenceDir
  if cfg.flatSnapshots then
    sequenceDir = outDir
  else
    sequenceDir = PyBridge.joinPath(outDir, sequenceName)
  end
  if not (cfg.flatSnapshots) then
    made, makeError = PyBridge.ensureDir(sequenceDir)
    if not (made) then
      if assPath ~= "" then
        PyBridge.removeFile(assPath)
      end
      return false, "Could not create sequence folder: " .. tostring(makeError or sequenceDir)
    end
  end
  local items = sequenceOutputItems(outputs, assPath)
  local outputDirs = { }
  for _index_0 = 1, #items do
    local item = items[_index_0]
    local dir = sequenceOutputDir(outDir, sequenceDir, #items, item, cfg.flatSnapshots)
    made, makeError = PyBridge.ensureDir(dir)
    if not (made) then
      if assPath ~= "" then
        PyBridge.removeFile(assPath)
      end
      return false, "Could not create sequence output folder: " .. tostring(makeError or dir)
    end
    outputDirs[item.key] = dir
    local pattern = sequenceOutputPattern(dir, item, range, cfg.flatSnapshots, sequenceName)
    local ok, details = PyBridge.runProcess(sequenceCommand(video, cfg.ffmpeg, range, item.filter, pattern))
    if not (ok) then
      if assPath ~= "" then
        PyBridge.removeFile(assPath)
      end
      return false, "FFmpeg returned an error while writing sequence frames to:\n" .. tostring(dir) .. "\n\n" .. tostring(details or '')
    end
    local checked, complete = pcall(sequenceOutputComplete, pattern, range)
    if not (checked or assPath == "") then
      PyBridge.removeFile(assPath)
    end
    if not (checked) then
      error(complete, 0)
    end
    if not (complete) then
      if assPath ~= "" then
        PyBridge.removeFile(assPath)
      end
      return false, "FFmpeg did not create the complete requested frame range in:\n" .. tostring(dir)
    end
  end
  if assPath ~= "" then
    PyBridge.removeFile(assPath)
  end
  local message = "Frame sequence written to:\n" .. tostring(outDir)
  message = message .. "\nFrames: " .. tostring(range.startFrame) .. "-" .. tostring(range.endFrame) .. " (" .. tostring(range.frameCount) .. ")"
  message = message .. "\nSubtitle lines rendered: " .. tostring(rendered or 0)
  if not (cfg.flatSnapshots) then
    local folders = { }
    if #items == 1 then
      table.insert(folders, sequenceDir)
    else
      for _index_0 = 1, #items do
        local item = items[_index_0]
        table.insert(folders, outputDirs[item.key])
      end
    end
    message = message .. ("\nFolders:\n" .. table.concat(folders, "\n"))
  else
    message = message .. "\nImages were written directly in Snapshots."
  end
  return true, message
end
local snapshoter
snapshoter = function(subs, sel, cfg)
  local video = videoPath()
  if not (video) then
    showMessage("Load a video before running Kiri-Shot.")
    return
  end
  local collection, lines = selectedLines(subs, sel or { })
  if cfg.ffmpeg == "" then
    cfg.ffmpeg = "ffmpeg"
  end
  cfg.videoW, cfg.videoH = videoSize()
  if cfg.videoW <= 0 or cfg.videoH <= 0 then
    showMessage("Could not obtain the loaded video's dimensions.")
    return
  end
  cfg.playX = tonumber(collection.meta and collection.meta.PlayResX)
  cfg.playY = tonumber(collection.meta and collection.meta.PlayResY)
  if not (cfg.playX and cfg.playX > 0) then
    cfg.playX = cfg.videoW
  end
  if not (cfg.playY and cfg.playY > 0) then
    cfg.playY = cfg.videoH
  end
  cfg.styles, cfg.scriptInfo = { }, { }
  for index = 1, #subs do
    local line = subs[index]
    if line.class == "style" then
      cfg.styles[#cfg.styles + 1] = line
    elseif line.class == "info" and (not line.section or line.section == "[Script Info]") then
      cfg.scriptInfo[#cfg.scriptInfo + 1] = line
    end
  end
  cfg.scriptInfo[#cfg.scriptInfo + 1] = {
    class = "info",
    key = "PlayResX",
    value = tostring(cfg.playX)
  }
  cfg.scriptInfo[#cfg.scriptInfo + 1] = {
    class = "info",
    key = "PlayResY",
    value = tostring(cfg.playY)
  }
  local outDir = snapshotsFolder(video)
  local made, makeError = PyBridge.ensureDir(outDir)
  if not (made) then
    showMessage("Could not create Snapshots folder: " .. tostring(makeError or outDir))
    return
  end
  if cfg.mode == "Frame sequence" then
    local _, message = runFrameSequence(subs, lines, video, outDir, cfg)
    showMessage(message)
    return
  end
  local jobs, skipped, errors = makeJobs(collection, lines, cfg)
  if #errors > 0 then
    showMessage(table.concat(errors, "\n"))
    return
  end
  if #jobs == 0 then
    showMessage("No captures were queued. Clip modes need \\clip/\\iclip; drawing modes need a selected \\p vector line.")
    return
  end
  local captureDir
  if cfg.flatSnapshots or #jobs == 1 then
    captureDir = outDir
  else
    captureDir = PyBridge.joinPath(outDir, captureBatchFolder(jobs))
  end
  if captureDir == outDir then
    prefixJobNames(jobs, runId("capture"))
  end
  aegisub.progress.title(script_name)
  aegisub.progress.task("Capturing PNG frames with FFmpeg")
  local ok, errorMessage = runCaptureJobs(video, captureDir, cfg, jobs)
  if ok then
    local message = tostring(#jobs) .. " PNG capture"
    if #jobs ~= 1 then
      message = message .. "s"
    end
    message = message .. " written to:\n" .. tostring(captureDir)
    if captureDir ~= outDir then
      message = message .. "\nSnapshots root:\n" .. tostring(outDir)
    end
    if #skipped > 0 then
      message = message .. "\nSkipped " .. tostring(#skipped) .. " line(s) without usable \\clip/\\iclip."
    end
    return showMessage(message)
  else
    return showMessage(errorMessage)
  end
end
return {
  run = snapshoter,
  selectedLines = selectedLines,
  frameDefaults = function(lines)
    return buildFrameDefaults(defaultFrameList(lines))
  end,
  parseFrameList = parseFrameList,
  normalizeMode = normalizeMode,
  normalizeClipOutput = normalizeClipOutput,
  modes = CaptureModes,
  timings = TimingModes,
  clipOutputs = ClipOutputs
}
end)()

local tasks = {
    "Capturas · líneas seleccionadas", "Capturas · lista de fotogramas", "Capturas · secuencia PNG",
    "Recorte · clip o dibujo", "Recorte · rectángulo manual", "Captura · mayor superposición",
    "Vídeo social", "Preparar máscaras",
}
local modeByTask, taskByMode = {}, {}
for i, mode in ipairs(Snapshot.modes) do modeByTask[tasks[i]], taskByMode[mode] = mode, tasks[i] end
local timingNames = {"Punto medio", "Inicio y final", "Inicio, medio y final", "Fotograma actual"}
local clipNames = {"Rectángulo del clip", "Alfa del clip · recortado", "Alfa del clip · cuadro completo",
    "Alfa del dibujo · recortado", "Alfa del dibujo · cuadro completo"}
local maskActions = {"Crear máscaras", "Corregir Y", "Centrar subs X", "Limpiar vistas Y"}

local function translated(value, source, target)
    for i, item in ipairs(source) do if value == item then return target[i] end end
    return target[1]
end

local function defaults(centerX)
    return {
        main={task=tasks[1], maskAction=maskActions[1], migrated=false},
        common={ffmpeg="ffmpeg", ffprobe="ffprobe", x264Preset="fast", audioBitrate="192k"},
        capture={mode="Selected lines", timing="Midpoint", clipOutput="Rectangle crop", includeText=true,
            flatSnapshots=false, captureClean=true, captureWithSubtitles=false, captureSubtitlesOnly=false,
            cropPadding=0, manualX=0, manualY=0, manualW=320, manualH=180},
        social={preset=Social.presets[1], customW=1080, customH=1920, audioTrack=1,
            outputProfile=Social.profiles[1], fps="30", crf=20, aspectMode=Social.aspects[1],
            safeX=7.5, safeBottom=12, maxFont=8, saveASS=false, maskX1=centerX, maskX2=centerX, maskAlpha=144},
    }
end

local function readStore(namespace, version, values, legacy)
    local store = KiteUI.settings(namespace, version, values, legacy or {})
    local _, loaded, message = store:load()
    if loaded == false then error(message or "No se pudieron leer las preferencias.", 0) end
    return store
end

local function loadState(centerX)
    local initial = defaults(centerX)
    local store = readStore(script_namespace, script_version, initial)
    local state = {}
    for section in pairs(initial) do state[section] = store:values(section) end
    if not state.main.migrated then
        local previousCapture = readStore("kite.Snapshoter", "1.6.11", {main=initial.capture, config={ffmpeg="ffmpeg"}},
            {{path="?user/kite-snapshoter.json", format="json_sections"}})
        local previousSocial = readStore("kite.SocialClip", "1.0.6", {main=initial.social, config=initial.common},
            {{path="?user/kite-social-clip.json", format="json_sections"}})
        state.capture, state.social = previousCapture:values("main"), previousSocial:values("main")
        state.common = previousSocial:values("config")
        local otherFfmpeg = trim(previousCapture:values("config").ffmpeg)
        if trim(state.common.ffmpeg) == "" or state.common.ffmpeg == "ffmpeg" then
            state.common.ffmpeg = otherFfmpeg ~= "" and otherFfmpeg or "ffmpeg"
        elseif otherFfmpeg ~= "" and otherFfmpeg ~= "ffmpeg" and otherFfmpeg ~= state.common.ffmpeg then
            state.notice = "Había dos rutas de FFmpeg. Se conserva la de Social Clip; puedes cambiarla en Ajustes."
        end
        state.main.task = taskByMode[Snapshot.normalizeMode(state.capture.mode)] or tasks[1]
        state.main.migrated = true
    end
    state.capture.mode = choiceOrDefault(Snapshot.normalizeMode(state.capture.mode), Snapshot.modes, Snapshot.modes[1])
    state.capture.clipOutput = choiceOrDefault(Snapshot.normalizeClipOutput(state.capture.clipOutput), Snapshot.clipOutputs, Snapshot.clipOutputs[1])
    state.main.task = choiceOrDefault(state.main.task, tasks, tasks[1])
    state.main.maskAction = choiceOrDefault(state.main.maskAction, maskActions, maskActions[1])
    state.capture.timing = choiceOrDefault(state.capture.timing, Snapshot.timings, Snapshot.timings[1])
    for key, choices in pairs({preset=Social.presets, outputProfile=Social.profiles, fps=Social.fps, aspectMode=Social.aspects}) do
        state.social[key] = choiceOrDefault(state.social[key], choices, initial.social[key])
    end
    state.common.x264Preset = choiceOrDefault(state.common.x264Preset, Social.encoders, "fast")
    state.common.audioBitrate = choiceOrDefault(state.common.audioBitrate, Social.bitrates, "192k")
    return state, store, initial
end

local function saveState(state, store, initial)
    for section, values in pairs(initial) do
        local keys = {}; for key in pairs(values) do keys[#keys+1] = key end
        store:update(section, state[section], keys)
    end
    local ok, written, message = pcall(store.write, store)
    if not ok or written == false then
        showMessage("No se pudieron guardar las preferencias:\n" .. tostring(ok and message or written))
    end
end

local function label(dialog, text, x, y, width, height)
    dialog[#dialog+1] = {class="label", label=text, x=x, y=y, width=width, height=height or 1}
end
local function field(dialog, kind, name, title, value, x, y, width, items, min, max)
    label(dialog, title, x, y, width)
    dialog[#dialog+1] = {class=kind, name=name, value=value, x=x, y=y+1, width=width, height=1, items=items, min=min, max=max}
end
local function check(dialog, name, title, value, x, y, width)
    dialog[#dialog+1] = {class="checkbox", name=name, label=title, value=value, x=x, y=y, width=width, height=1}
end
local function header(context, title)
    local dialog = {}
    label(dialog, "KIRI-SHOT  /  " .. title, 0, 0, 24)
    local video = context.video and baseName(context.video) or "Sin vídeo cargado"
    local glyphs = LineOps.graphemes(video)
    if #glyphs > 48 then video = table.concat(glyphs, "", 1, 45) .. "..." end
    label(dialog, string.format("%s  ·  %d × %d  ·  %d diálogos seleccionados", video, context.width, context.height, context.count), 0, 1, 24)
    return dialog
end

local function formatFields(dialog, cfg, y)
    field(dialog, "dropdown", "preset", "Formato de salida", cfg.preset, 0, y, 12, Social.presets)
    field(dialog, "intedit", "customW", "Ancho personalizado", cfg.customW, 12, y, 6, nil, 2)
    field(dialog, "intedit", "customH", "Alto personalizado", cfg.customH, 18, y, 6, nil, 2)
    field(dialog, "dropdown", "aspectMode", "Relación entre máscara y salida", cfg.aspectMode, 0, y+2, 24, Social.aspects)
end

local function homeDialog(context, state)
    local dialog = header(context, "Elige una tarea")
    field(dialog, "dropdown", "task", "Qué quieres preparar", state.main.task, 0, 3, 24, tasks)
    label(dialog, "CAPTURAS  ·  PNG por líneas, fotogramas, secuencias, clips o dibujos.\nVÍDEO SOCIAL  ·  Une escenas y adapta el encuadre y los subtítulos.\nMÁSCARAS  ·  Prepara y corrige las regiones del recorte.", 0, 6, 24, 3)
    label(dialog, "PNG: carpeta del proyecto / Snapshots.\nVídeo y ASS: eliges el archivo al exportar.", 0, 10, 24, 2)
    if state.notice then label(dialog, state.notice, 0, 13, 24, 2) end
    return dialog
end

local function captureDialog(context, state)
    local cfg, mode = state.capture, modeByTask[state.main.task]
    local dialog = header(context, state.main.task)
    local y = 3
    if mode == "Frame list" then
        label(dialog, "Fotogramas desde cero: 120f, 130f o una entrada por línea.", 0, y, 24)
        dialog[#dialog+1] = {class="textbox", name="frameText", text=cfg.frameText, x=0, y=y+1, width=24, height=5}
        y = y + 7
    elseif mode == "Frame sequence" then
        label(dialog, "Salidas de la secuencia  ·  activa al menos una", 0, y, 24)
        check(dialog, "captureClean", "Vídeo sin subtítulos", cfg.captureClean, 0, y+1, 8)
        check(dialog, "captureWithSubtitles", "Vídeo con subtítulos", cfg.captureWithSubtitles, 8, y+1, 8)
        check(dialog, "captureSubtitlesOnly", "Subtítulos transparentes", cfg.captureSubtitlesOnly, 16, y+1, 8)
        label(dialog, "La selección define el intervalo completo, incluidos los huecos.\nSe renderizan los eventos del guion que coinciden con ese intervalo.", 0, y+3, 24, 2)
        y = y + 6
    elseif mode ~= "Densest subtitle frame" then
        field(dialog, "dropdown", "timingChoice", "Instantes que se capturan", translated(cfg.timing, Snapshot.timings, timingNames), 0, y, 24, timingNames)
        y = y + 3
    else
        label(dialog, "Se captura el primer fotograma con más diálogos seleccionados superpuestos.", 0, y, 24, 2)
        y = y + 3
    end
    if mode == "Clip crop" then
        field(dialog, "dropdown", "clipChoice", "Forma y transparencia del recorte", translated(cfg.clipOutput, Snapshot.clipOutputs, clipNames), 0, y, 18, clipNames)
        field(dialog, "intedit", "cropPadding", "Margen del rectángulo", cfg.cropPadding, 18, y, 6, nil, 0)
        label(dialog, "Las salidas alfa siguen el clip o dibujo renderizado. El margen solo afecta al rectángulo.", 0, y+2, 24, 2)
        y = y + 5
    elseif mode == "Manual rectangle" then
        for i, item in ipairs({{"manualX", "X"}, {"manualY", "Y"}, {"manualW", "Ancho"}, {"manualH", "Alto"}}) do
            field(dialog, "intedit", item[1], item[2] .. " · píxeles", cfg[item[1]], (i-1)*6, y, 6, nil, i>2 and 1 or nil)
        end
        field(dialog, "intedit", "cropPadding", "Margen adicional · píxeles", cfg.cropPadding, 0, y+2, 12, nil, 0)
        y = y + 5
    end
    label(dialog, "Archivos PNG  ·  carpeta del proyecto / Snapshots", 0, y, 24)
    if mode ~= "Frame sequence" then check(dialog, "includeText", "Añadir texto del subtítulo al nombre", cfg.includeText, 0, y+1, 14) end
    check(dialog, "flatSnapshots", "Todo en la carpeta raíz", cfg.flatSnapshots, 14, y+1, 10)
    return dialog
end

local function socialDialog(context, state, masks)
    local cfg = state.social
    local dialog = header(context, masks and "Preparar máscaras" or "Vídeo social")
    local y = 3
    if masks then
        field(dialog, "dropdown", "maskAction", "Operación sobre el guion", state.main.maskAction, 0, y, 24, maskActions)
        y = y + 3
    end
    formatFields(dialog, cfg, y)
    y = y + 5
    if masks then
        field(dialog, "floatedit", "maskX1", "Centro X inicial · PlayRes", cfg.maskX1, 0, y, 8)
        field(dialog, "floatedit", "maskX2", "Centro X final · PlayRes", cfg.maskX2, 8, y, 8)
        field(dialog, "intedit", "maskAlpha", "Transparencia · 0–255", cfg.maskAlpha, 16, y, 8, nil, 0, 255)
        label(dialog, "Crear: usa los tiempos seleccionados y conserva las líneas originales.\nCorregir Y y centrar X: modifican solo la selección. Se pueden deshacer.\nLimpiar vistas Y: retira únicamente los antiguos eventos auxiliares.", 0, y+3, 24, 3)
    else
        field(dialog, "dropdown", "outputProfile", "Subtítulos en la salida", cfg.outputProfile, 0, y, 24, Social.profiles)
        field(dialog, "dropdown", "fps", "Fotogramas por segundo", cfg.fps, 0, y+2, 8, Social.fps)
        field(dialog, "intedit", "crf", "Calidad CRF · menor = mejor", cfg.crf, 8, y+2, 8, nil, 0, 51)
        field(dialog, "intedit", "audioTrack", "Pista de audio · desde 1", cfg.audioTrack, 16, y+2, 8, nil, 1)
        field(dialog, "floatedit", "safeX", "Margen lateral · %", cfg.safeX, 0, y+4, 8)
        field(dialog, "floatedit", "safeBottom", "Margen inferior · %", cfg.safeBottom, 8, y+4, 8)
        field(dialog, "floatedit", "maxFont", "Fuente máxima · % alto", cfg.maxFont, 16, y+4, 8)
        check(dialog, "saveASS", "Guardar además el ASS adaptado", cfg.saveASS, 0, y+6, 24)
        label(dialog, "Se exportan las escenas de las máscaras del guion y se omiten los huecos.\n«Solo ASS» guarda el diálogo adaptado sin codificar vídeo.", 0, y+8, 24, 2)
    end
    return dialog
end

local function settingsDialog(context, state)
    local cfg = state.common
    local dialog = header(context, "Ajustes compartidos")
    field(dialog, "edit", "ffmpeg", "FFmpeg · ejecutable o nombre en PATH", cfg.ffmpeg, 0, 3, 24)
    field(dialog, "edit", "ffprobe", "FFprobe · inspección del audio", cfg.ffprobe, 0, 5, 24)
    field(dialog, "dropdown", "x264Preset", "Velocidad de codificación de vídeo", cfg.x264Preset, 0, 7, 12, Social.encoders)
    field(dialog, "dropdown", "audioBitrate", "Tasa de audio AAC", cfg.audioBitrate, 12, 7, 12, Social.bitrates)
    label(dialog, "La ruta de FFmpeg se usa para capturas y vídeo.\nGuardar vuelve a la tarea. Cancelar conserva los ajustes anteriores.", 0, 10, 24, 2)
    return dialog
end

local function retain(values, target)
    for key, value in pairs(values or {}) do if target[key] ~= nil then target[key] = value end end
end
local function validate(state, action)
    local mode, cfg = modeByTask[state.main.task], state.capture
    if mode then
        if mode == "Frame list" then
            local frames, errors = Snapshot.parseFrameList(cfg.frameText)
            if #errors > 0 then return table.concat(errors, "\n") end
            if #frames == 0 then return "Introduce al menos un fotograma." end
        elseif mode == "Frame sequence" then
            if not (cfg.captureClean or cfg.captureWithSubtitles or cfg.captureSubtitlesOnly) then return "Activa al menos una salida de secuencia." end
        end
        if mode == "Manual rectangle" or (mode == "Clip crop" and cfg.clipOutput == "Rectangle crop") then
            local padding = finiteNumber(cfg.cropPadding)
            if not padding or padding < 0 then return "El margen debe ser un número finito no negativo." end
            if mode == "Manual rectangle" then
                for _, key in ipairs({"manualX", "manualY", "manualW", "manualH"}) do
                    local value = finiteNumber(cfg[key])
                    if not value or ((key == "manualW" or key == "manualH") and value <= 0) then return "Introduce coordenadas finitas y un ancho y alto positivos." end
                end
            end
        end
    else
        cfg = state.social
        if action == "Limpiar vistas Y" then return end
        if cfg.preset == "Personalizado" then
            if not finiteNumber(cfg.customW) or not finiteNumber(cfg.customH) or cfg.customW < 2 or cfg.customH < 2 then return "La resolución personalizada debe ser de al menos 2 × 2." end
        end
        if action == "Crear máscaras" then
            if not finiteNumber(cfg.maskX1) or not finiteNumber(cfg.maskX2) or not finiteNumber(cfg.maskAlpha) or cfg.maskAlpha < 0 or cfg.maskAlpha > 255 then return "Introduce centros X finitos y una transparencia de 0 a 255." end
            cfg.maskAlpha = math.floor(cfg.maskAlpha + 0.5)
        elseif state.main.task == "Vídeo social" then
            if not finiteNumber(cfg.audioTrack) or cfg.audioTrack < 1 or cfg.audioTrack ~= math.floor(cfg.audioTrack) then return "La pista de audio debe ser un entero positivo." end
            if not finiteNumber(cfg.crf) or cfg.crf < 0 or cfg.crf > 51 then return "La calidad CRF debe estar entre 0 y 51." end
            for _, key in ipairs({"safeX", "safeBottom", "maxFont"}) do if not finiteNumber(cfg[key]) then return "Introduce porcentajes finitos para el diálogo adaptado." end end
            if cfg.safeX < 0 or cfg.safeX >= 50 or cfg.safeBottom < 0 or cfg.safeBottom >= 100 or cfg.maxFont <= 0 then return "Márgenes: lateral de 0 a menos de 50 %, inferior de 0 a menos de 100 %; fuente máxima positiva." end
            cfg.crf = math.floor(cfg.crf + 0.5)
        end
    end
end

local function main(subs, selection, active, entry)
    local video = videoPath()
    local width, height = videoSize()
    local _, lines = Snapshot.selectedLines(subs, selection or {})
    local playX = LineOps.scriptResolution(subs, width > 0 and width or 1920, height > 0 and height or 1080)
    local ok, state, store, initial = pcall(loadState, math.floor(playX/2+0.5))
    if not ok then showMessage(tostring(state)); return selection, active end
    state.capture.frameText = video and Snapshot.frameDefaults(lines) or ""
    local context = {video=video, width=width, height=height, count=#lines}
    local page = "home"
    if entry then
        state.main.task = entry == "social" and "Vídeo social" or taskByMode[state.capture.mode] or tasks[1]
        page = entry == "social" and "social" or "capture"
    end
    while true do
        local dialog, buttons, primary
        if page == "home" then
            dialog, buttons, primary = homeDialog(context, state), {"Abrir tarea", "Ajustes", "Cerrar"}, "Abrir tarea"
        elseif page == "capture" then
            dialog, buttons, primary = captureDialog(context, state), {"Capturar PNG", "Cambiar tarea", "Ajustes", "Cerrar"}, "Capturar PNG"
        elseif page == "masks" then
            dialog, buttons, primary = socialDialog(context, state, true), {"Aplicar", "Cambiar tarea", "Ajustes", "Cerrar"}, "Aplicar"
        else
            dialog, buttons, primary = socialDialog(context, state, false), {"Exportar vídeo", "Solo ASS", "Cambiar tarea", "Ajustes", "Cerrar"}, "Exportar vídeo"
        end
        local button, values = aegisub.dialog.display(dialog, buttons, {ok=primary, close="Cerrar"})
        if not button or button == "Cerrar" then return selection, active end
        if page == "home" then
            state.main.task = choiceOrDefault(values.task, tasks, state.main.task)
        elseif page == "capture" then
            retain(values, state.capture)
            if values.timingChoice then state.capture.timing = translated(values.timingChoice, timingNames, Snapshot.timings) end
            if values.clipChoice then state.capture.clipOutput = translated(values.clipChoice, clipNames, Snapshot.clipOutputs) end
        else
            retain(values, state.social)
            if values.maskAction then state.main.maskAction = choiceOrDefault(values.maskAction, maskActions, state.main.maskAction) end
        end
        if button == "Cambiar tarea" then page = "home"
        elseif button == "Ajustes" then
            local pressed, config = aegisub.dialog.display(settingsDialog(context, state), {"Guardar", "Cancelar"}, {ok="Guardar", close="Cancelar"})
            if pressed == "Guardar" then
                retain(config, state.common)
                state.common.ffmpeg = ffmpegExecutable(state.common.ffmpeg)
                if trim(state.common.ffprobe) == "" then state.common.ffprobe = "ffprobe" end
                saveState(state, store, initial)
            end
        elseif button == "Abrir tarea" and page == "home" then
            if modeByTask[state.main.task] then state.capture.mode = modeByTask[state.main.task] end
            page = modeByTask[state.main.task] and "capture" or state.main.task == "Vídeo social" and "social" or "masks"
        elseif button == primary or (page == "social" and button == "Solo ASS") then
            local action = page == "masks" and state.main.maskAction or button
            local problem = validate(state, action)
            if action ~= "Limpiar vistas Y" and (not video or width <= 0 or height <= 0) then problem = "Carga un vídeo real en Aegisub antes de ejecutar esta tarea." end
            if problem then showMessage(problem)
            else
                saveState(state, store, initial)
                local cfg = Core.copy(page == "capture" and state.capture or state.social)
                for key, value in pairs(state.common) do cfg[key] = value end
                cfg.ffmpeg = ffmpegExecutable(cfg.ffmpeg)
                if page == "capture" then
                    cfg.mode = modeByTask[state.main.task]
                    Snapshot.run(subs, selection, cfg)
                    return selection, active
                end
                local output, current = Social.run(subs, selection, action, cfg)
                return output or selection, current or active
            end
        else return selection, active end
    end
end

local hotkeyRoot = ": Kite Hotkeys :/Kiri-Shot/"
local function captureEntry(subs, selection, active) return main(subs, selection, active, "capture") end
local function socialEntry(subs, selection, active) return main(subs, selection, active, "social") end
depctrl:registerMacro(script_name, script_description, main, nil, nil, false)
depctrl:registerMacro(hotkeyRoot .. "Capturas", "Abrir directamente las capturas de Kiri-Shot", captureEntry, nil, nil, false)
depctrl:registerMacro(hotkeyRoot .. "Vídeo social", "Abrir directamente el vídeo social de Kiri-Shot", socialEntry, nil, nil, false)
KiteUI.actions.rename("kite.Snapshoter", {Snapshoter=hotkeyRoot .. "Capturas"}, script_namespace)
KiteUI.actions.rename("kite.SocialClip", {
    ["Social Clip"]=hotkeyRoot .. "Vídeo social", [": Kite Hotkeys :/Social Clip/Execute"]=hotkeyRoot .. "Vídeo social",
}, script_namespace)
for _, owner in ipairs({"kite.Snapshoter", "kite.SocialClip"}) do
    local retired = KiteUI.settings("kite.Actions." .. owner, "1.0.0", {main={commands={}}})
    local _, loaded = retired:load()
    if loaded ~= false and next(retired:values("main").commands) then
        retired:update("main", {commands={}}, {"commands"})
        local ok, written, message = pcall(retired.write, retired)
        if not ok or written == false then KiteUI.log(tostring(ok and message or written), "Kiri-Shot: catálogo de acciones") end
    end
end
KiteUI.publishActions()

end
local registrations = {}
local registerMacro = aegisub.register_macro
local function loadScript()
    registrations = {}
    aegisub.register_macro = function(name, description, callback, validate, active)
        registrations[#registrations+1] = {name, description, callback, validate, active}
    end
    local ok, message = pcall(initializeScript)
    aegisub.register_macro = registerMacro
    local available, control = pcall(require, "l0.DependencyControl")
    if available and control.updater then control.updater:releaseLock() end
    return ok, message
end
local loaded, failure = loadScript()
if loaded then
    for _, action in ipairs(registrations) do registerMacro(unpack(action)) end
else
    registerMacro(script_name, script_description, function(subs, selection, active)
        if not loaded then
            local available, control = pcall(require, "l0.DependencyControl")
            if not available then error(control, 0) end
            local loader = require("l0.DependencyControl.ModuleLoader")
            for _, task in pairs(control.updater.tasks[control.Domain.ScriptType.Module]) do
                if not task.updated and not task.running then loader.removeDummyRef(task.record) end
            end
            loaded, failure = loadScript()
            if not loaded then error(failure, 0) end
        end
        local choices, actions = {}, {}
        for _, action in ipairs(registrations) do
            if not action[4] or action[4](subs, selection, active) then
                choices[#choices+1] = action[1]
                actions[action[1]] = action[3]
            end
        end
        if #choices == 0 then return selection, active end
        if #choices == 1 then return actions[choices[1]](subs, selection, active) end
        local button, values = aegisub.dialog.display({
            {class="dropdown", name="action", items=choices, value=choices[1], x=0,y=0,width=1,height=1}
        }, {"Run","Cancel"}, {ok="Run",close="Cancel"})
        if button == "Run" then return actions[values.action](subs, selection, active) end
        return selection, active
    end)
end
