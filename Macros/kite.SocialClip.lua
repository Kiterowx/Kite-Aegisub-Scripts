script_name = "Social Clip"
script_description = "Crear máscaras de recorte animadas y exportar vídeo vertical continuo"
script_author = "Kiterow"
script_version = "1.0.3"
script_namespace = "kite.SocialClip"

local LineCollection, KiteUI, ASS, Core, LineOps, Media, PyBridge, AssDrawing, ASSParser, AssContext, depctrl

local DependencyControl = require "l0.DependencyControl"
depctrl = DependencyControl {
    feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    {
        {"a-mo.LineCollection", version = "1.3.0", url = "https://github.com/TypesettingTools/Aegisub-Motion",
            feed = "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"},
        {"kite.UI", version = "1.5.1", url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
            feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"l0.ASSFoundation", version = "0.5.0", url = "https://github.com/TypesettingTools/ASSFoundation",
            feed = "https://raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json"},
        {"kite.Core", version = "1.1.0", url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
            feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.LineOps", version = "1.7.3", url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
            feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.Media", version = "1.4.0", url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
            feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.PyBridge", version = "1.7.2", url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
            feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.AssDrawing", version = "1.0.3", url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
            feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.AssContext", version = "1.1.3", url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
            feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"myaa.ASSParser", version = "0.0.4", url = "https://github.com/TypesettingTools/Myaamori-Aegisub-Scripts",
            feed = "https://raw.githubusercontent.com/TypesettingTools/Myaamori-Aegisub-Scripts/master/DependencyControl.json"}
    }
}
LineCollection, KiteUI, ASS, Core, LineOps, Media, PyBridge, AssDrawing, AssContext, ASSParser = depctrl:requireModules()

local configFile = "kite-social-clip.json"
local maskEffect = "Kite Social Mask"
local previewEffect = "Kite Social Y Preview"
local centerExtra = "_kite_socialclip_centered"
local hotkeyPath = ": Kite Hotkeys :/Social Clip/Execute"
local isWindows = PyBridge.isWindows
local coordinateTolerance = 0.001
local maximumCrf = 51
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

local trim = Core.trim
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

local function choiceOrDefault(value, items, fallback)
    for _, item in ipairs(items) do
        if value == item then return item end
    end
    return fallback
end

local function resolveOutputProfile(cfg)
    local name = choiceOrDefault(cfg and cfg.outputProfile, outputProfileItems, outputProfileItems[1])
    return outputProfiles[name], name
end

local function dirName(path)
    return PyBridge.parentPath(path) or ""
end

local function baseName(path)
    local name = tostring(path or ""):match("([^\\/]+)$") or tostring(path or "")
    return (name:gsub("%.[^%.]*$", ""))
end

local function safeName(value, fallback)
    local text = trim(value):gsub("[%z\1-\31\\/:*?\"<>|]+", "_"):gsub("%s+", "_")
    text = text:gsub("_+", "_"):gsub("^_+", ""):gsub("_+$", ""):gsub("[%.%s]+$", "")
    local lower = text:lower():match("^[^%.]+") or ""
    local reserved = lower == "con" or lower == "prn" or lower == "aux" or lower == "nul"
        or lower:match("^com[1-9]$") or lower:match("^lpt[1-9]$")
    if text == "" or text == "." or text == ".." or reserved then return fallback or "social" end
    return text
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

local function decodedPath(spec)
    return Media.decodedPath(spec) or ""
end

local projectProperties = Media.projectProperties

local function videoPath()
    local path = decodedPath("?video")
    if path ~= "" and fileExists(path) then return path end
    path = projectProperties().video_file or ""
    if path ~= "" and fileExists(path) then return path end
    return nil
end

local function projectFolder(video)
    local props = projectProperties()
    for _, key in ipairs({"filename", "script_file"}) do
        local folder = dirName(props[key])
        if folder ~= "" then return folder end
    end
    local scriptFolder = decodedPath("?script")
    if scriptFolder ~= "" then return scriptFolder end
    return dirName(video)
end

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

local function filterPathQuote(value)
    value = Media.filterPath(tostring(value or ""):gsub("\\", "/"))
    return Media.filterPath(value)
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

local function showMessage(text, title)
    return KiteUI.message(text, {title=title or script_name})
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

local function configHandler(interface)
    return KiteUI.dialogHandler(interface, script_namespace, script_version, {
        {path = "?user/" .. configFile, format = "json_sections"}
    })
end

local function buildInterface(playX, videoW, videoH)
    local defaultX = math.floor((tonumber(playX) or videoW) / 2 + 0.5)
    return {
        main = {
            title = {class = "label", label = "Social Clip", x = 0, y = 0, width = 3, height = 1},
            videoInfo = {class = "label", label = string.format("Vídeo: %dx%d", videoW, videoH), x = 3, y = 0, width = 5, height = 1},
            presetLabel = {class = "label", label = "Formato", x = 0, y = 1, width = 2, height = 1},
            preset = {class = "dropdown", value = presetItems[1], items = presetItems, config = true, x = 2, y = 1, width = 8, height = 1},
            customLabel = {class = "label", label = "Personalizado", x = 10, y = 1, width = 2, height = 1},
            customW = {class = "intedit", value = 1080, min = 2, config = true, x = 12, y = 1, width = 2, height = 1},
            customX = {class = "label", label = "x", x = 14, y = 1, width = 1, height = 1},
            customH = {class = "intedit", value = 1920, min = 2, config = true, x = 15, y = 1, width = 2, height = 1},
            audioInfo = {class = "label", label = "Audio del origen", x = 0, y = 2, width = 2, height = 1},
            audioTrackLabel = {class = "label", label = "Pista", x = 2, y = 2, width = 2, height = 1},
            audioTrack = {class = "intedit", value = 1, min = 1, config = true, x = 4, y = 2, width = 2, height = 1},
            outputLabel = {class = "label", label = "Salida", x = 6, y = 2, width = 2, height = 1},
            outputProfile = {class = "dropdown", value = outputProfileItems[1], items = outputProfileItems, config = true, x = 8, y = 2, width = 9, height = 1},
            fpsLabel = {class = "label", label = "FPS", x = 0, y = 3, width = 2, height = 1},
            fps = {class = "dropdown", value = "30", items = fpsItems, config = true, x = 2, y = 3, width = 3, height = 1},
            crfLabel = {class = "label", label = "CRF", x = 5, y = 3, width = 2, height = 1},
            crf = {class = "intedit", value = 20, min = 0, max = maximumCrf, config = true, x = 7, y = 3, width = 2, height = 1},
            aspectLabel = {class = "label", label = "Relación", x = 9, y = 3, width = 2, height = 1},
            aspectMode = {class = "dropdown", value = aspectItems[1], items = aspectItems, config = true, x = 11, y = 3, width = 6, height = 1},
            safeLabel = {class = "label", label = "Subtítulos: margen lateral %", x = 0, y = 4, width = 5, height = 1},
            safeX = {class = "floatedit", value = 7.5, config = true, x = 5, y = 4, width = 2, height = 1},
            bottomLabel = {class = "label", label = "inferior %", x = 7, y = 4, width = 2, height = 1},
            safeBottom = {class = "floatedit", value = 12, config = true, x = 9, y = 4, width = 2, height = 1},
            fontLabel = {class = "label", label = "fuente máx. % alto", x = 11, y = 4, width = 3, height = 1},
            maxFont = {class = "floatedit", value = 8, config = true, x = 14, y = 4, width = 3, height = 1},
            saveASS = {class = "checkbox", label = "Guardar ASS adaptado", value = false, config = true, x = 0, y = 5, width = 4, height = 1},
            outputInfo = {class = "label", label = "Exacto conserva capas; Adaptado recoloca diálogo; MKV deja el diálogo activable.", x = 4, y = 5, width = 13, height = 1},
            maskTitle = {class = "label", label = "Crear máscaras desde los tiempos seleccionados", x = 0, y = 6, width = 8, height = 1},
            x1Label = {class = "label", label = "Centro X inicial", x = 0, y = 7, width = 3, height = 1},
            maskX1 = {class = "floatedit", value = defaultX, config = true, x = 3, y = 7, width = 3, height = 1},
            x2Label = {class = "label", label = "Centro X final", x = 6, y = 7, width = 3, height = 1},
            maskX2 = {class = "floatedit", value = defaultX, config = true, x = 9, y = 7, width = 3, height = 1},
            alphaLabel = {class = "label", label = "Alpha 0-255", x = 12, y = 7, width = 2, height = 1},
            maskAlpha = {class = "intedit", value = 144, min = 0, max = 255, config = true, x = 14, y = 7, width = 3, height = 1},
            maskInfo = {class = "label", label = "X se respeta. Y se corrige para aprovechar el cuadro. Las máscaras nuevas usan \\an5 y el \\pos marca su centro.", x = 0, y = 8, width = 17, height = 2},
            sceneInfo = {class = "label", label = "Corregir Y modifica las máscaras seleccionadas: conserva X, ajusta Y y normaliza el origen a \\an5.", x = 0, y = 10, width = 17, height = 2}
        },
        config = {
            title = {class = "label", label = "Social Clip - Configuración", x = 0, y = 0, width = 7, height = 1},
            ffmpegLabel = {class = "label", label = "FFmpeg", x = 0, y = 1, width = 2, height = 1},
            ffmpeg = {class = "edit", value = "ffmpeg", config = true, x = 2, y = 1, width = 13, height = 1},
            ffprobeLabel = {class = "label", label = "FFprobe", x = 0, y = 2, width = 2, height = 1},
            ffprobe = {class = "edit", value = "ffprobe", config = true, x = 2, y = 2, width = 13, height = 1},
            presetLabel = {class = "label", label = "Preset x264", x = 0, y = 3, width = 2, height = 1},
            x264Preset = {class = "dropdown", value = "fast", items = x264Presets, config = true, x = 2, y = 3, width = 4, height = 1},
            bitrateLabel = {class = "label", label = "AAC", x = 7, y = 3, width = 2, height = 1},
            audioBitrate = {class = "dropdown", value = "192k", items = audioBitrates, config = true, x = 9, y = 3, width = 3, height = 1}
        }
    }
end

local function showOptions(playX, videoW, videoH)
    local interface = buildInterface(playX, videoW, videoH)
    local options = configHandler(interface)
    options:read()
    options:updateInterface("main")
    options:updateInterface("config")
    local actions = {"Exportar vídeo", "Solo ASS", "Crear máscaras", "Corregir Y", "Centrar subs X"}
    local function save(values, section)
        options:updateConfiguration(values, section)
        local ok, written, err = pcall(options.write, options)
        if not ok or written == false then
            showMessage("No se pudo guardar la configuración.\n" .. tostring(ok and err or written), "Social Clip - Configuración")
        end
    end
    local function retain(values, section)
        for name, value in pairs(values or {}) do
            if interface[section][name] then interface[section][name].value = value end
        end
    end
    while true do
        local button, result = aegisub.dialog.display(interface.main,
            {"Exportar vídeo", "Solo ASS", "Crear máscaras", "Corregir Y", "Centrar subs X", "Config...", "Cancelar"},
            {ok = "Exportar vídeo", close = "Cancelar"})
        if not button or button == "Cancelar" then return nil end
        retain(result, "main")
        if button == "Config..." then
            local configButton, configResult = aegisub.dialog.display(interface.config, {"Guardar", "Cancelar"}, {ok = "Guardar", close = "Cancelar"})
            if configButton == "Guardar" then
                retain(configResult, "config")
                save(configResult, "config")
            end
        elseif choiceOrDefault(button, actions) then
            local cfg = {}
            for _, section in ipairs({"main", "config"}) do
                for name, control in pairs(interface[section]) do
                    if control.config then cfg[name] = control.value end
                end
            end
            local message
            for _, name in ipairs({"customW", "customH", "audioTrack", "crf", "safeX", "safeBottom", "maxFont", "maskX1", "maskX2", "maskAlpha"}) do
                cfg[name] = Core.finiteNumber(cfg[name])
                if not cfg[name] then message = "Introduce un número finito en " .. name .. "." break end
            end
            if not message then
                if cfg.customW < 2 or cfg.customH < 2 then message = "La resolución personalizada debe ser de al menos 2 × 2."
                elseif cfg.audioTrack < 1 or cfg.audioTrack ~= math.floor(cfg.audioTrack) then message = "La pista de audio debe ser un entero positivo."
                elseif cfg.safeX < 0 or cfg.safeX >= 50 then message = "El margen lateral debe estar entre 0 y menos de 50 %."
                elseif cfg.safeBottom < 0 or cfg.safeBottom >= 100 then message = "El margen inferior debe estar entre 0 y menos de 100 %."
                elseif cfg.maxFont <= 0 then message = "El tamaño máximo de fuente debe ser positivo."
                elseif cfg.crf < 0 or cfg.crf > maximumCrf then message = "CRF debe estar entre 0 y " .. maximumCrf .. "."
                elseif cfg.maskAlpha < 0 or cfg.maskAlpha > 255 then message = "Alpha debe estar entre 0 y 255." end
            end
            if message then showMessage(message)
            else
                cfg.preset = choiceOrDefault(cfg.preset, presetItems, presetItems[1])
                cfg.outputProfile = choiceOrDefault(cfg.outputProfile, outputProfileItems, outputProfileItems[1])
                cfg.fps = choiceOrDefault(cfg.fps, fpsItems, "30")
                cfg.aspectMode = choiceOrDefault(cfg.aspectMode, aspectItems, aspectItems[1])
                cfg.x264Preset = choiceOrDefault(cfg.x264Preset, x264Presets, "fast")
                cfg.audioBitrate = choiceOrDefault(cfg.audioBitrate, audioBitrates, "192k")
                cfg.maskAlpha, cfg.crf = math.floor(cfg.maskAlpha + 0.5), math.floor(cfg.crf + 0.5)
                cfg.saveASS = cfg.saveASS == true
                save(cfg, "main")
                return button, cfg
            end
        else return nil end
    end
end

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
    aegisub.set_undo_point("Social Clip - Crear máscaras")
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
    aegisub.set_undo_point("Social Clip - Centrar subtítulos en X")
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
    aegisub.set_undo_point("Social Clip - Corregir Y")
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
            showMessage("El ASS adaptado no puede sobrescribir el guion activo.", "Social Clip - Seguridad")
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
    if not ok then showMessage(message, "Social Clip - ASS") return end
    showMessage(string.format("ASS adaptado escrito en:\n%s\n\n%d evento(s); %d línea(s) compleja(s) omitida(s); %d división(es) por escenas.",
        path, stats.eventCount or 0, stats.skippedComplex or 0, stats.splitEvents or 0), "Social Clip - ASS")
end

local function exportVideo(subs, plan, cfg, outW, outH, playX, playY, video, temporary)
    local profile, profileName = resolveOutputProfile(cfg)
    local outputPath = selectOutputPath(video, outW, outH, profile.extension)
    if not outputPath then return end
    if samePath(outputPath, video) then
        showMessage("La salida no puede sobrescribir el vídeo de origen.", "Social Clip")
        return
    end

    local folder = dirName(outputPath)
    local tempBase = nextTempBase(folder, baseName(outputPath))

    local audio = sourceAudioPath(video)
    local audioInput
    local hasAudio, probeError = probeAudioStream(audio, cfg, tempBase)
    if hasAudio == nil then
        cleanupPaths(temporary)
        showMessage(probeError, "Social Clip - Audio")
        return
    elseif hasAudio then
        audioInput = samePath(audio, video) and 0 or 1
    elseif cfg.audioTrack > 1 then
        cleanupPaths(temporary)
        showMessage(string.format("No existe la pista de audio %d en el origen. Elige otra pista.", cfg.audioTrack), "Social Clip - Audio")
        return
    end

    local needsAdapted = profile.burnDialogue or profile.softDialogue or cfg.saveASS
    local adaptedPath, adaptedStats
    if needsAdapted then
        adaptedPath = cfg.saveASS and replaceExtension(outputPath, "_subtitles.ass") or (tempBase .. "_adapted.ass")
        if cfg.saveASS then
            local active = activeScriptPath()
            if active ~= "" and samePath(adaptedPath, active) then
                showMessage("El ASS adaptado no puede sobrescribir el guion activo.", "Social Clip - Seguridad")
                return
            end
            if not confirmOverwrite(adaptedPath) then return end
        end
        local adaptedOk, adaptedError
        adaptedOk, adaptedError, adaptedStats = writeAdaptedAss(subs, plan, cfg, outW, outH, playY, adaptedPath)
        if not adaptedOk and adaptedStats and adaptedStats.noEvents then
            adaptedPath = nil
        elseif not adaptedOk then
            showMessage(adaptedError, "Social Clip - Subtítulos")
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
        showMessage(visualError, "Social Clip - Carteles y FX")
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
        showMessage(bundleError, "Social Clip - Subtítulos")
        return
    end

    local commandPaths, commandError = writeTrajectoryFiles(plan, tempBase, temporary)
    if not commandPaths then
        cleanupPaths(temporary)
        showMessage(commandError, "Social Clip - Trayectoria")
        return
    end

    local visualSubtitle = bundle and bundle.visualStream ~= nil and {path = bundle.path, stream = bundle.visualStream} or nil
    local adaptedSubtitle = bundle and bundle.adaptedStream ~= nil and {path = bundle.path, stream = bundle.adaptedStream} or nil
    local graph, graphError = buildFiltergraph(plan, cfg, outW, outH, audioInput,
        visualSubtitle, profile.burnDialogue and adaptedSubtitle or nil)
    if not graph then
        cleanupPaths(temporary)
        showMessage(graphError, "Social Clip - Filtro")
        return
    end
    local filterPath = tempBase .. "_filter.txt"
    if not writeFile(filterPath, graph) then
        cleanupPaths(temporary)
        showMessage("No se pudo escribir el filtro temporal:\n" .. filterPath, "Social Clip")
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
    if not ok then showMessage(errorMessage, "Social Clip - FFmpeg") return end

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
    showMessage(table.concat(lines, "\n"), "Social Clip - Listo")
end

local function editSubtitles(subs, callback, ...)
    local args = {...}
    return LineOps.transaction(subs, nil, function() return callback(subs, unpack(args)) end)
end

local function canRun(subs)
    for i = 1, #(subs or {}) do
        local line = subs[i]
        if line and line.class == "dialogue" and tostring(line.effect or "") == previewEffect then return true end
    end
    if not aegisub.frame_from_ms or not aegisub.ms_from_frame or not aegisub.video_size then
        return false, "Carga un vídeo antes de ejecutar Social Clip."
    end
    if not videoPath() then return false, "Carga un vídeo real antes de ejecutar Social Clip." end
    return true
end

local function socialClip(subs, selection)
    local video = videoPath()
    if not video then
        local newSelection, removed = editSubtitles(subs, removeYPreviews, selection)
        if removed > 0 then
            aegisub.set_undo_point("Social Clip - Limpiar vista Y")
            return newSelection, newSelection[1]
        end
        showMessage("Carga un vídeo real antes de ejecutar Social Clip.")
        return
    end
    local ok, videoW, videoH = pcall(aegisub.video_size)
    videoW, videoH = tonumber(videoW) or 0, tonumber(videoH) or 0
    if not ok or videoW <= 0 or videoH <= 0 then
        showMessage("Aegisub no devolvió una resolución de vídeo válida.")
        return
    end
    local playX, playY = scriptResolution(subs, videoW, videoH)
    local action, cfg = showOptions(playX, videoW, videoH)
    if not action then return end

    local outW, outH, resolutionError = normalizeOutputDimensions(cfg)
    if not outW then showMessage(resolutionError) return end

    if action == "Crear máscaras" then
        local newSelection, message = editSubtitles(subs, createMasks, selection, cfg, videoW, videoH, playX, playY)
        if not newSelection then showMessage(message, "Social Clip - Máscaras") return end
        showMessage(message, "Social Clip - Máscaras")
        return newSelection, newSelection[1]
    end

    if action == "Corregir Y" then
        local correctedSelection, message = editSubtitles(subs, correctSelectedMasksY, selection, cfg, playX, playY, videoW, videoH, outW, outH)
        if not correctedSelection then showMessage(message, "Social Clip - Corregir Y") return end
        showMessage(message, "Social Clip - Corregir Y")
        return correctedSelection, correctedSelection[1]
    end

    local plan, planError = prepareScenePlan(subs, {}, cfg, videoW, videoH, outW, outH)
    if not plan then showMessage(planError, "Social Clip - Escenas") return end
    if action == "Centrar subs X" then
        local centeredSelection, message = editSubtitles(subs, centerSelectedSubtitlesX, selection, plan, playX, playY, videoW)
        if not centeredSelection then showMessage(message, "Social Clip - Centrar X") return end
        showMessage(message, "Social Clip - Centrar X")
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

if depctrl and depctrl.registerMacro then
    depctrl:registerMacro(script_name, script_description, socialClip, canRun, nil, false)
    depctrl:registerMacro(hotkeyPath, "Acción rápida. " .. script_description, socialClip, canRun, nil, false)
else
    aegisub.register_macro(script_name, script_description, socialClip, canRun)
    aegisub.register_macro(hotkeyPath, "Acción rápida. " .. script_description, socialClip, canRun)
end

require("kite.UI").publishActions()
