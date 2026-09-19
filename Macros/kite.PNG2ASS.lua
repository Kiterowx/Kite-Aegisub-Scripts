script_name        = "PNG2ASS"
script_description = "Convert images and SVG files into ASS drawing lines"
script_author      = "Kiterow"
script_version     = "1.6.4"
script_namespace   = "kite.PNG2ASS"

local PNG2ASS = {}

local moduleName = "ass_png2ass"
local configFileName = "kite.PNG2ASS.conf"
local defaultInstallSource = "git+https://github.com/Kiterowx/kite-png2ass.git"
local imageFilter = "Images (.png .jpg .jpeg .webp .bmp .tif .tiff .gif .tga .svg)|"
    .. "*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.tif;*.tiff;*.gif;*.tga;*.svg"
local supportedExtensions = {
    png = true, jpg = true, jpeg = true, webp = true, bmp = true,
    tif = true, tiff = true, gif = true, tga = true, svg = true,
}
local maxSequenceLines = 500000
local maxSequenceChars = 100000000
local maxLogChars = 1000000
local processPollMs = 100
local processExitGracePolls = 30
local insertChunkSize = 128
local CANCELLED = "PNG2ASS_CANCELLED"
local statusTextLimit = 200

local depctrl
do
    local ok, DependencyControl = pcall(require, "l0.DependencyControl")
    if ok and DependencyControl then
        depctrl = DependencyControl({
            feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
            {
                {
                    "aka.command",
                    version = "1.0.2",
                    url = "https://github.com/Akatmks/Akatsumekusa-Aegisub-Scripts",
                    feed = "https://raw.githubusercontent.com/Akatmks/Akatsumekusa-Aegisub-Scripts/master/DependencyControl.json",
                },
                {
                    "kite.UI",
                    version = "1.5.0",
                    url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
                    feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
                },
                {
                    "kite.PyBridge",
                    version = "1.7.1",
                    url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
                    feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
                },
                {
                    "kite.LineOps",
                    version = "1.7.0",
                    url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
                    feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
                },
                {
                    "kite.Media",
                    version = "1.4.0",
                    url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
                    feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
                },
                {
                    "kite.AssDrawing",
                    version = "1.0.2",
                    url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
                    feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
                },
            }
        })
    end
end

local KiteUI
local PyBridge
local LineOps
local Media
local AssDrawing
local json
do
    if depctrl and depctrl.requireModules then
        local ok, _, ui, bridge, lineOps, media, assDrawing = pcall(function()
            return depctrl:requireModules()
        end)
        if ok then
            KiteUI = ui
            PyBridge = bridge
            LineOps = lineOps
            Media = media
            AssDrawing = assDrawing
        end
    end
end
KiteUI = KiteUI or require("kite.UI")
PyBridge = PyBridge or require("kite.PyBridge")
LineOps = LineOps or require("kite.LineOps")
Media = Media or require("kite.Media")
AssDrawing = AssDrawing or require("kite.AssDrawing")

do
    local ok, value = pcall(require, "json")
    if not ok or not value or type(value.decode) ~= "function" then
        ok, value = pcall(require, "l0.dkjson")
    end
    if ok and value and type(value.decode) == "function" then json = value end
end

local DEFAULTS = {
    python = "python",
    install_source = defaultInstallSource,
    engine = "auto",
    mode = "auto",
    trace_profile = "balanced",
    threshold = 50,
    p_scale = 4,
    simplify = 1.0,
    min_area = 2,
    max_chars = 1000000,
    max_pixels = 40000000,
    denoise = 0,
    position = "0,0",
    x = 0,
    y = 0,
    blur = 0,
    color = "style",
    line_warning = 256,
}

local MODES = { "auto", "alpha", "white-matte", "dark-matte", "luma", "color" }
local traceProfiles = { "balanced", "quality" }
local POSITIONS = { "0,0", "Active pos", "Manual" }
local COLORS = { "style", "source" }
local optionLimits = {
    threshold = { min = 0, max = 100, integer = true },
    p_scale = { min = 1, max = 6, integer = true },
    line_warning = { min = 1, max = maxSequenceLines, integer = true },
    simplify = { min = 0, max = 1000 },
    min_area = { min = 0, max = 1000000000 },
    x = { min = -10000000, max = 10000000 },
    y = { min = -10000000, max = 10000000 },
    blur = { min = 0, max = 100 },
    denoise = { min = 0, max = 50, integer = true },
    max_chars = { min = 1, max = maxSequenceChars, integer = true },
    max_pixels = { min = 1, max = 250000000, integer = true },
}

local function listContains(values, wanted)
    for _, value in ipairs(values) do if value == wanted then return true end end
    return false
end

local trim = LineOps.trim
local joinPath = PyBridge.joinPath
local fileExists = PyBridge.fileExists
local writeFile = PyBridge.writeFile
local copyLine = LineOps.copy
local readFile = PyBridge.readFile
local decodedPath = LineOps.decodedPath

local finiteNumber = AssDrawing.finiteNumber

local function normalizeMainOptions(values)
    values = type(values) == "table" and values or {}
    local normalized = {}
    normalized.engine = "auto"
    normalized.mode = listContains(MODES, values.mode) and values.mode or DEFAULTS.mode
    normalized.trace_profile = listContains(traceProfiles, values.trace_profile) and values.trace_profile or DEFAULTS.trace_profile
    normalized.position = listContains(POSITIONS, values.position) and values.position or DEFAULTS.position
    normalized.color = listContains(COLORS, values.color) and values.color or DEFAULTS.color
    for name, limits in pairs(optionLimits) do
        local value = finiteNumber(values[name]) or DEFAULTS[name]
        value = math.max(limits.min, math.min(limits.max, value))
        if limits.integer then value = LineOps.round(value) end
        normalized[name] = value
    end
    normalized.python = type(values.python) == "string" and trim(values.python) or ""
    return normalized
end

local validAssShapeLine = AssDrawing.validatePng2AssLine

local function readLog(path)
    local content = readFile(path, maxLogChars + 1)
    if content and #content > maxLogChars then return content:sub(1, maxLogChars) .. "\n[output truncated]" end
    return content
end

local cancellationRequested
local setProgress

local function readLines(path)
    local content, message = readFile(path, maxSequenceChars + 1)
    if not content then
        return nil, message
    end
    if #content > maxSequenceChars then return nil, "Backend output exceeds the character limit." end
    local lines = {}
    for line in (content .. "\n"):gmatch("([^\r\n]*)\r?\n") do
        line = trim(line)
        if line ~= "" then
            if not validAssShapeLine(line) then
                return nil, "Backend output contains an invalid ASS drawing at line " .. tostring(#lines + 1) .. "."
            end
            lines[#lines + 1] = line
            if #lines > maxSequenceLines then return nil, "Backend output exceeds the ASS line limit." end
            if #lines % insertChunkSize == 0 then
                setProgress("Validating ASS output", math.min(99, #lines / math.max(1, maxSequenceLines) * 100))
                if cancellationRequested() then return nil, CANCELLED end
            end
        end
    end
    return lines
end

local function showMessage(message)
    return KiteUI.message(message)
end
local function cancelWith(message)
    showMessage(message)
    aegisub.cancel()
end

local allocateTempPaths

cancellationRequested = function()
    if not aegisub or not aegisub.progress or type(aegisub.progress.is_cancelled) ~= "function" then return false end
    local ok, cancelled = pcall(aegisub.progress.is_cancelled)
    return ok and cancelled == true
end

setProgress = function(task, percent)
    if not aegisub or not aegisub.progress then return end
    if task and type(aegisub.progress.task) == "function" then pcall(aegisub.progress.task, tostring(task)) end
    if percent and type(aegisub.progress.set) == "function" then pcall(aegisub.progress.set, math.max(0, math.min(100, percent))) end
end

local function decodeJsonFile(path)
    if not json then return nil, "JSON support is unavailable." end
    local content, message = readFile(path, maxLogChars + 1)
    if not content then return nil, message end
    if #content > maxLogChars then return nil, "JSON output is too large." end
    local ok, value = pcall(json.decode, content)
    if not ok or type(value) ~= "table" then return nil, ok and "JSON output is invalid." or tostring(value) end
    return value
end

local function powershellLiteral(value)
    return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end

local function windowsQuoteArgument(value)
    value = tostring(value or "")
    local parts = { '"' }
    local slashes = 0
    for index = 1, #value do
        local character = value:sub(index, index)
        if character == "\\" then
            slashes = slashes + 1
        elseif character == '"' then
            parts[#parts + 1] = string.rep("\\", slashes * 2 + 1)
            parts[#parts + 1] = '"'
            slashes = 0
        else
            if slashes > 0 then parts[#parts + 1] = string.rep("\\", slashes); slashes = 0 end
            parts[#parts + 1] = character
        end
    end
    if slashes > 0 then parts[#parts + 1] = string.rep("\\", slashes * 2) end
    parts[#parts + 1] = '"'
    return table.concat(parts)
end

local function managedRunnerScript(python, arguments, paths)
    local native = { "-m", moduleName }
    for _, value in ipairs(arguments or {}) do native[#native + 1] = tostring(value) end
    local quoted = {}
    for _, value in ipairs(native) do quoted[#quoted + 1] = windowsQuoteArgument(value) end
    local argumentLine = table.concat(quoted, " ")
    local cancel = powershellLiteral(paths.cancel)
    local stdout = powershellLiteral(paths.stdout)
    local stderr = powershellLiteral(paths.stderr)
    local cmdlog = powershellLiteral(paths.cmdlog)
    local exitPath = powershellLiteral(paths.exit)
    return "\239\187\191" .. table.concat({
        "$ErrorActionPreference = 'Stop'",
        "$utf8 = New-Object System.Text.UTF8Encoding($false)",
        "$exitCode = 1",
        "$cancelled = $false",
        "$process = $null",
        "$stdoutText = ''",
        "$stderrText = ''",
        "try {",
        "    $argumentLine = " .. powershellLiteral(argumentLine),
        "    $startInfo = New-Object System.Diagnostics.ProcessStartInfo",
        "    $startInfo.FileName = " .. powershellLiteral(python),
        "    $startInfo.Arguments = $argumentLine",
        "    $startInfo.UseShellExecute = $false",
        "    $startInfo.CreateNoWindow = $true",
        "    $startInfo.RedirectStandardOutput = $true",
        "    $startInfo.RedirectStandardError = $true",
        "    $process = New-Object System.Diagnostics.Process",
        "    $process.StartInfo = $startInfo",
        "    if (-not $process.Start()) { throw 'Could not start the PNG2ASS backend.' }",
        "    $stdoutTask = $process.StandardOutput.ReadToEndAsync()",
        "    $stderrTask = $process.StandardError.ReadToEndAsync()",
        "    while (-not $process.HasExited) {",
        "        if (Test-Path -LiteralPath " .. cancel .. ") {",
        "            $cancelled = $true",
        "            try { if (-not $process.HasExited) { $process.Kill() }; $process.WaitForExit() } catch {}",
        "            $exitCode = 130",
        "            break",
        "        }",
        "        Start-Sleep -Milliseconds " .. tostring(processPollMs),
        "    }",
        "    if (-not $cancelled) { $process.WaitForExit(); $exitCode = $process.ExitCode }",
        "    $stdoutText = $stdoutTask.Result",
        "    $stderrText = $stderrTask.Result",
        "} catch {",
        "    try { if ($process -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() } } catch {}",
        "    $stderrText = $stderrText + ($_ | Out-String)",
        "    $exitCode = 1",
        "}",
        "[IO.File]::WriteAllText(" .. stdout .. ", $stdoutText, $utf8)",
        "[IO.File]::WriteAllText(" .. stderr .. ", $stderrText, $utf8)",
        "[IO.File]::WriteAllText(" .. cmdlog .. ", ($stdoutText + $stderrText), $utf8)",
        "[IO.File]::WriteAllText(" .. exitPath .. ", [string]$exitCode, $utf8)",
        "exit $exitCode",
    }, "\r\n")
end

local function updateBackendProgress(paths)
    if not fileExists(paths.progress) then return end
    local progress = decodeJsonFile(paths.progress)
    if not progress then return end
    setProgress(progress.stage or "Converting image", finiteNumber(progress.percent))
end

local function waitForProcessExit(pid, exitPath)
    for poll = 1, processExitGracePolls do
        if (not exitPath or fileExists(exitPath)) and not PyBridge.processExists(pid) then return true end
        PyBridge.sleep(processPollMs)
    end
    return not PyBridge.processExists(pid)
end

local function runManagedBackend(python, arguments, paths)
    if not PyBridge.isWindows then return false, "Cancelable PNG2ASS conversion currently requires Windows." end
    if type(PyBridge.startDetachedScript) ~= "function" or type(PyBridge.processExists) ~= "function" or type(PyBridge.sleep) ~= "function" then
        return false, "kite.PyBridge 1.5.0 or newer is required for cancelable conversion."
    end
    local wrote, writeError = writeFile(paths.runner, managedRunnerScript(python, arguments, paths))
    if not wrote then return false, writeError or "Could not create the managed backend runner." end
    local started, pid = PyBridge.startDetachedScript(paths.runner)
    if not started then return false, pid or "Could not start the managed backend runner." end

    setProgress("Starting PNG2ASS backend", 0)
    local poll = 0
    while not fileExists(paths.exit) do
        poll = poll + 1
        if cancellationRequested() then
            local signalled, signalError = writeFile(paths.cancel, "cancel")
            if not signalled then return false, signalError or "Could not signal backend cancellation." end
            setProgress("Cancelling PNG2ASS backend", nil)
            if not waitForProcessExit(pid, paths.exit) then
                return false, "The managed PNG2ASS process did not stop after cancellation."
            end
            return false, CANCELLED, true
        end
        updateBackendProgress(paths)
        if poll % 10 == 0 and not PyBridge.processExists(pid) then
            for _ = 1, 5 do
                if fileExists(paths.exit) then break end
                PyBridge.sleep(processPollMs)
            end
            if not fileExists(paths.exit) then return false, "The PNG2ASS supervisor exited without reporting a result." end
            break
        end
        PyBridge.sleep(processPollMs)
    end

    if not waitForProcessExit(pid, paths.exit) then return false, "The PNG2ASS supervisor did not exit cleanly." end
    local exitText, exitError = readFile(paths.exit, 32)
    local exitCode = exitText and tonumber(trim(exitText)) or nil
    if exitCode == nil then return false, exitError or "The PNG2ASS exit code is invalid." end
    local log = readLog(paths.log)
    if not log or trim(log) == "" then log = readLog(paths.cmdlog) end
    return exitCode == 0, log, exitCode == 130
end

local function runCommand(command, logPath)
    if not command or trim(command) == "" then
        writeFile(logPath, "Command could not be built.")
        return false
    end
    local ok, log = PyBridge.run(command)
    writeFile(logPath, log or "")
    return ok
end

local function runCommandDialog(title, command, okMessage)
    local current = command
    local log = nil
    while true do
        local interface = {
            { class = "label", label = title, x = 0, y = 0, width = 8, height = 1 },
            { class = "label", label = "Execute this command.", x = 0, y = 1, width = 8, height = 1 },
            { class = "textbox", name = "command", value = current, x = 0, y = 2, width = 56, height = 6 },
        }
        if log and trim(log) ~= "" then
            table.insert(interface, { class = "label", label = "Output", x = 0, y = 8, width = 8, height = 1 })
            table.insert(interface, { class = "textbox", name = "log", value = log, x = 0, y = 9, width = 56, height = 6 })
        end

        local runLabel = "Execute"
        local button, result = aegisub.dialog.display(interface, { runLabel, "Cancel" }, { ok = runLabel, close = "Cancel" })
        if button ~= runLabel then
            aegisub.cancel()
        end

        current = trim(result.command)
        if current == "" then
            log = "Command is empty."
        else
            local paths, pathError = allocateTempPaths()
            if not paths then
                log = pathError or "Could not allocate temporary files."
            else
                local ok = runCommand(current, paths.cmdlog)
                log = readLog(paths.cmdlog) or "Command failed."
                PyBridge.cleanup(paths)
                if ok then showMessage(okMessage); return true end
            end
        end
    end
end

local function sourceDir()
    if not debug or not debug.getinfo then
        return nil
    end
    local info = debug.getinfo(1, "S")
    local source = info and info.source or ""
    if source:sub(1, 1) ~= "@" then
        return nil
    end
    local path = source:sub(2)
    local dir = path:match("^(.*)[\\/]")
    if dir and dir ~= "" then
        return dir
    end
    return nil
end

local function scriptDir()
    local dir = sourceDir()
    if dir then
        return dir
    end
    local userPath = decodedPath("?user")
    if userPath then
        return joinPath(joinPath(userPath, "automation"), "autoload")
    end
    return decodedPath("?script") or "."
end

local function localPackageSource()
    local source = joinPath(scriptDir(), "ass_png2ass")
    if fileExists(joinPath(source, "pyproject.toml")) then
        return source
    end
    return defaultInstallSource
end

local function defaultPython()
    return PyBridge.resolvePython(
        "",
        joinPath(joinPath(scriptDir(), "ass_png2ass"), ".venv")
    )
end

local function defaultConfig()
    return {
        python = defaultPython(),
        install_source = localPackageSource(),
    }
end

local function configPath()
    local userPath = decodedPath("?user")
    if userPath then
        local dir = joinPath(userPath, "config")
        return joinPath(dir, configFileName)
    end
    return joinPath(scriptDir(), configFileName)
end

local pngSettings = KiteUI.settings(script_namespace, script_version, {
    package = defaultConfig(),
    main = {
        mode = DEFAULTS.mode,
        trace_profile = DEFAULTS.trace_profile,
        color = DEFAULTS.color,
        threshold = DEFAULTS.threshold,
        p_scale = DEFAULTS.p_scale,
        line_warning = DEFAULTS.line_warning,
        simplify = DEFAULTS.simplify,
        min_area = DEFAULTS.min_area,
        position = DEFAULTS.position,
        x = DEFAULTS.x,
        y = DEFAULTS.y,
        blur = DEFAULTS.blur,
        max_chars = DEFAULTS.max_chars,
        max_pixels = DEFAULTS.max_pixels,
        denoise = DEFAULTS.denoise,
    },
}, {
    { path = configPath(), format = "key_value", target = "package" },
})

local function readConfig()
    local cfg = pngSettings:values("package")
    if trim(cfg.python) == "" then
        cfg.python = defaultPython()
    end
    if trim(cfg.install_source) == "" then
        cfg.install_source = localPackageSource()
    elseif cfg.install_source:find("png2ass_" .. "back" .. "end", 1, true) or cfg.install_source:find("png2ass-" .. "back" .. "end", 1, true) then
        cfg.install_source = localPackageSource()
    end
    return cfg
end

local function writeConfig(cfg)
    pngSettings:update("package", cfg)
    return pngSettings:write()
end

local function pythonPathError(value)
    local python = trim(value)
    if not python:find("[/\\]") or fileExists(python) then return nil end
    return "The configured Python interpreter was not found.\nPath: " .. python
        .. "\nOpen PNG2ASS/Backend/Configure and set Python to python or select an existing interpreter."
end

function allocateTempPaths()
    return PyBridge.tempPaths("png2ass", {
        out = ".txt",
        list = ".list",
        sequence = ".seq",
        log = ".log",
        cmdlog = ".cmd.log",
        result = ".result.json",
        progress = ".progress.json",
        cancel = ".cancel",
        runner = ".runner.ps1",
        stdout = ".stdout.log",
        stderr = ".stderr.log",
        exit = ".exit",
    })
end

local function activePos(text)
    local position = LineOps.position(text)
    local x = position and finiteNumber(position.x) or nil
    local y = position and finiteNumber(position.y) or nil
    if x and y then return x, y end
    return nil, nil
end

local function naturalKey(path)
    local name = tostring(path or ""):match("([^\\/]+)$") or tostring(path or "")
    name = name:lower()
    return name:gsub("(%d+)", function(number)
        local significant = number:gsub("^0+", "")
        if significant == "" then significant = "0" end
        return string.format("%08d:%s", #significant, significant)
    end)
end

local function normalizePaths(value)
    local paths = {}
    local rejected = {}
    local seen = {}
    local values = type(value) == "table" and value or { value }
    for _, path in ipairs(values) do
        path = type(path) == "string" and trim(path) or ""
        local key = PyBridge.isWindows and path:lower() or path
        local extension = path:lower():match("%.([^.\\/]+)$")
        local unsafeListPath = path:find("[\r\n]") or path:find("%z")
        if path ~= "" and not unsafeListPath and supportedExtensions[extension] and fileExists(path) and not seen[key] then
            seen[key] = true
            paths[#paths + 1] = path
        elseif path ~= "" and (unsafeListPath or not supportedExtensions[extension] or not fileExists(path)) then
            rejected[#rejected + 1] = path
        end
    end
    table.sort(paths, function(left, right)
        local leftKey = naturalKey(left)
        local rightKey = naturalKey(right)
        if leftKey == rightKey then return left:lower() < right:lower() end
        return leftKey < rightKey
    end)
    return paths, rejected
end

local function selectPngs()
    local result = aegisub.dialog.open(
        "Select Images",
        "",
        scriptDir(),
        imageFilter,
        true,
        true
    )
    local paths, rejected = normalizePaths(result)
    if #rejected > 0 then
        cancelWith("Some selected images are missing or unsupported:\n" .. table.concat(rejected, "\n"))
    end
    if #paths == 0 then
        aegisub.cancel()
    end
    return paths
end

local function packageConfigDialog(title, buttons)
    local cfg = readConfig()
    local interface = {
        title = { class = "label", label = title, x = 0, y = 0, width = 8, height = 1 },
        python_label = { class = "label", label = "Python", x = 0, y = 1, width = 2, height = 1 },
        python = { class = "edit", name = "python", value = cfg.python, x = 2, y = 1, width = 14, height = 1 },
        source_label = { class = "label", label = "Install source", x = 0, y = 2, width = 3, height = 1 },
        install_source = { class = "edit", name = "install_source", value = cfg.install_source, x = 3, y = 2, width = 13, height = 1 },
    }
    local button, result = aegisub.dialog.display(interface, buttons or { "Execute", "Cancel" }, { ok = buttons and buttons[1] or "Execute", close = "Cancel" })
    if button ~= (buttons and buttons[1] or "Execute") then aegisub.cancel() end
    result.python = trim(result.python)
    result.install_source = trim(result.install_source)
    if result.python == "" then
        result.python = defaultPython()
    end
    if result.install_source == "" then
        result.install_source = localPackageSource()
    end
    return button, result
end

local function packageStatus(cfg)
    local command, message = PyBridge.moduleCommand(cfg.python, moduleName, { "--status", "--source", cfg.install_source })
    if not command then return false, message end
    return PyBridge.run(command)
end

local function statusSummary(detail)
    if not json then return "The backend status cannot be decoded because no JSON module is available.", false, nil, false end
    local ok, status = pcall(json.decode, tostring(detail or ""))
    if not ok or type(status) ~= "table" or type(status.ready) ~= "boolean" or
        (status.update_available ~= nil and type(status.update_available) ~= "boolean") then
        return "The backend returned an invalid status response.", false, nil, false
    end
    local function statusText(value, fallback)
        if type(value) ~= "string" or trim(value) == "" then return fallback end
        return trim(value):gsub("[\r\n]+", " "):sub(1, statusTextLimit)
    end
    local installed = statusText(status.installed_version, "unknown")
    local latest = statusText(status.latest_version, "unavailable")
    local ready = status.ready
    local updateAvailable = status.update_available
    local updateError = statusText(status.update_error, "unavailable")
    local lines = {
        "Package: kite-png2ass",
        "Installed: " .. installed,
        "Source version: " .. latest,
        "Runtime: " .. (ready == false and "needs repair" or "ready"),
    }
    if updateAvailable == true then
        lines[#lines + 1] = "Update: available"
    elseif latest ~= "unavailable" then
        lines[#lines + 1] = "Update: not required"
    else
        lines[#lines + 1] = "Update check: " .. (updateError or "unavailable")
    end
    return table.concat(lines, "\n"), ready, updateAvailable, true
end

local function backendAction(message, buttons)
    local button = aegisub.dialog.display({
        { class = "textbox", value = tostring(message or ""), x = 0, y = 0, width = 70, height = 12 },
    }, buttons, { ok = buttons[1], close = buttons[#buttons] })
    return button
end

local function installPackageMain()
    local cfg = readConfig()
    local missingPython = pythonPathError(cfg.python)
    if missingPython then cancelWith(missingPython) end
    local install, installError = PyBridge.installCommand(cfg.python, cfg.install_source)
    local check, checkError = PyBridge.moduleCommand(cfg.python, moduleName, { "--status", "--source", cfg.install_source })
    if not install or not check then cancelWith(installError or checkError or "Package command could not be built.") end
    runCommandDialog("PNG2ASS Package", PyBridge.chain(install, check), "Package is installed and ready.")
end

local function configurePackageMain()
    local _, cfg = packageConfigDialog("PNG2ASS Package", { "Save", "Cancel" })
    local ok, message = writeConfig(cfg)
    if not ok then return showMessage("Could not save package configuration:\n" .. tostring(message or "unknown error")) end
    showMessage("Package configuration saved.")
end

local function checkPackageMain()
    local cfg = readConfig()
    local missingPython = pythonPathError(cfg.python)
    if missingPython then
        local action = backendAction(missingPython, { "Configure", "Close" })
        if action == "Configure" then return configurePackageMain() end
        return
    end
    local ok, detail = packageStatus(cfg)
    if not ok then
        local action = backendAction(
            "The kite-png2ass package was not found or could not start.\n\n" .. tostring(detail or ""),
            { "Install", "Configure", "Close" }
        )
        if action == "Install" then return installPackageMain() end
        if action == "Configure" then return configurePackageMain() end
        return
    end

    local summary, ready, updateAvailable, validStatus = statusSummary(detail)
    if not validStatus or ready == false then
        local action = backendAction(summary, { "Repair", "Configure", "Close" })
        if action == "Repair" then return installPackageMain() end
        if action == "Configure" then return configurePackageMain() end
    elseif updateAvailable == true then
        local action = backendAction(summary, { "Update", "Close" })
        if action == "Update" then return installPackageMain() end
    else
        showMessage(summary)
    end
end

local function createDialog(line, cfg, imageCount, frameCount)
    local px, py = activePos(line.text)
    local saved = normalizeMainOptions(pngSettings:values("main"))
    local defaultPosition = (px and py) and "Active pos" or saved.position
    local countLabel = "Images: " .. tostring(imageCount or 1)
    if frameCount then
        countLabel = countLabel .. " / Frames: " .. tostring(frameCount)
    end
    local interface = {
        title = { class = "label", label = "PNG2ASS", x = 0, y = 0, width = 6, height = 1 },
        mode_label = { class = "label", label = "Mode", x = 0, y = 1, width = 2, height = 1 },
        mode = { class = "dropdown", name = "mode", items = MODES, value = saved.mode, x = 2, y = 1, width = 3, height = 1 },
        color_label = { class = "label", label = "Color", x = 5, y = 1, width = 2, height = 1 },
        color = { class = "dropdown", name = "color", items = COLORS, value = saved.color, x = 7, y = 1, width = 3, height = 1 },
        profile_label = { class = "label", label = "VTracer", x = 10, y = 1, width = 2, height = 1 },
        trace_profile = { class = "dropdown", name = "trace_profile", items = traceProfiles, value = saved.trace_profile, x = 12, y = 1, width = 3, height = 1 },
        threshold_label = { class = "label", label = "Threshold", x = 0, y = 2, width = 3, height = 1 },
        threshold = { class = "intedit", name = "threshold", value = saved.threshold, min = optionLimits.threshold.min, max = optionLimits.threshold.max, x = 3, y = 2, width = 3, height = 1 },
        scale_label = { class = "label", label = "Scale", x = 6, y = 2, width = 2, height = 1 },
        p_scale = { class = "intedit", name = "p_scale", value = saved.p_scale, min = optionLimits.p_scale.min, max = optionLimits.p_scale.max, x = 8, y = 2, width = 2, height = 1 },
        simplify_label = { class = "label", label = "Simplify", x = 0, y = 3, width = 3, height = 1 },
        simplify = { class = "floatedit", name = "simplify", value = saved.simplify, min = optionLimits.simplify.min, max = optionLimits.simplify.max, step = 0.25, x = 3, y = 3, width = 3, height = 1 },
        min_area_label = { class = "label", label = "Min area", x = 6, y = 3, width = 3, height = 1 },
        min_area = { class = "floatedit", name = "min_area", value = saved.min_area, min = optionLimits.min_area.min, max = optionLimits.min_area.max, step = 1, x = 9, y = 3, width = 3, height = 1 },
        position_label = { class = "label", label = "Position", x = 0, y = 4, width = 3, height = 1 },
        position = { class = "dropdown", name = "position", items = POSITIONS, value = defaultPosition, x = 3, y = 4, width = 4, height = 1 },
        x_label = { class = "label", label = "X", x = 7, y = 4, width = 1, height = 1 },
        x = { class = "floatedit", name = "x", value = px or saved.x, min = optionLimits.x.min, max = optionLimits.x.max, x = 8, y = 4, width = 3, height = 1 },
        y_label = { class = "label", label = "Y", x = 11, y = 4, width = 1, height = 1 },
        y = { class = "floatedit", name = "y", value = py or saved.y, min = optionLimits.y.min, max = optionLimits.y.max, x = 12, y = 4, width = 3, height = 1 },
        blur_label = { class = "label", label = "Blur", x = 0, y = 5, width = 2, height = 1 },
        blur = { class = "floatedit", name = "blur", value = saved.blur, min = optionLimits.blur.min, max = optionLimits.blur.max, step = 0.1, x = 2, y = 5, width = 3, height = 1 },
        denoise_label = { class = "label", label = "Denoise", x = 5, y = 5, width = 2, height = 1 },
        denoise = { class = "intedit", name = "denoise", value = saved.denoise, min = optionLimits.denoise.min, max = optionLimits.denoise.max, x = 7, y = 5, width = 2, height = 1 },
        max_label = { class = "label", label = "Warn chars", x = 9, y = 5, width = 3, height = 1 },
        max_chars = { class = "intedit", name = "max_chars", value = saved.max_chars, min = optionLimits.max_chars.min, max = optionLimits.max_chars.max, x = 12, y = 5, width = 3, height = 1 },
        pixels_label = { class = "label", label = "Max pixels", x = 0, y = 6, width = 3, height = 1 },
        max_pixels = { class = "intedit", name = "max_pixels", value = saved.max_pixels, min = optionLimits.max_pixels.min, max = optionLimits.max_pixels.max, x = 3, y = 6, width = 5, height = 1 },
        lines_label = { class = "label", label = "Warn lines", x = 8, y = 6, width = 3, height = 1 },
        line_warning = { class = "intedit", name = "line_warning", value = saved.line_warning, min = optionLimits.line_warning.min, max = optionLimits.line_warning.max, x = 11, y = 6, width = 4, height = 1 },
        python_label = { class = "label", label = "Python", x = 0, y = 7, width = 2, height = 1 },
        python = { class = "edit", name = "python", value = cfg.python, x = 2, y = 7, width = 11, height = 1 },
        count_label = { class = "label", label = countLabel, x = 0, y = 8, width = 15, height = 1 },
    }
    local button, result = aegisub.dialog.display(interface, { "Execute", "Cancel" }, { ok = "Execute", close = "Cancel" })
    if button ~= "Execute" then
        aegisub.cancel()
    end
    result = normalizeMainOptions(result)
    if result.color == "source" and result.mode == "auto" then result.mode = "color" end
    result.python = trim(result.python)
    if result.python == "" then
        result.python = cfg.python
    end
    return result
end

local function persistOptions(options, cfg)
    pngSettings:update("main", options)
    cfg.python = options.python
    return writeConfig(cfg)
end

local function conversionArguments(paths, options, posX, posY)
    local arguments = {
        "--mode", options.mode,
        "--engine", "auto",
        "--trace-profile", options.trace_profile,
        "--threshold", tostring(options.threshold),
        "--p-scale", tostring(options.p_scale),
        "--simplify", tostring(options.simplify),
        "--min-area", tostring(options.min_area),
        "--max-lines", tostring(options.line_warning),
        "--max-chars", tostring(options.max_chars),
        "--max-pixels", tostring(options.max_pixels),
        "--denoise", tostring(options.denoise),
        "--pos-x", tostring(posX),
        "--pos-y", tostring(posY),
        "--blur", tostring(options.blur),
        "--log", paths.log,
        "--result-file", paths.result,
        "--progress-file", paths.progress,
        "--cancel-file", paths.cancel,
        "--quiet",
    }
    if options.color == "source" or options.mode == "color" then arguments[#arguments + 1] = "--keep-color" end
    return arguments
end

local function buildCommand(paths, imagePath, options, posX, posY)
    local arguments = { "--input", imagePath }
    local common = conversionArguments(paths, options, posX, posY)
    for _, value in ipairs(common) do arguments[#arguments + 1] = value end
    arguments[#arguments + 1] = "--out"
    arguments[#arguments + 1] = paths.out
    local command, message = PyBridge.moduleCommand(options.python, moduleName, arguments)
    return command, message, arguments
end

local function buildSequenceCommand(paths, options, posX, posY)
    local arguments = { "--input-list", paths.list }
    local common = conversionArguments(paths, options, posX, posY)
    for _, value in ipairs(common) do arguments[#arguments + 1] = value end
    arguments[#arguments + 1] = "--sequence-out"
    arguments[#arguments + 1] = paths.sequence
    local command, message = PyBridge.moduleCommand(options.python, moduleName, arguments)
    return command, message, arguments
end

local function resolvePosition(options, line)
    if options.position == "Active pos" then
        local px, py = activePos(line.text)
        if not px or not py then return nil, nil, "The active line does not contain a valid \\pos tag." end
        return px, py
    end
    if options.position == "Manual" then
        local x, y = finiteNumber(options.x), finiteNumber(options.y)
        if not x or not y then return nil, nil, "The manual position is invalid." end
        return x, y
    end
    return 0, 0
end

local function conversionSummary(result, fallbackLines, fallbackChars)
    result = type(result) == "table" and result or {}
    local lines = finiteNumber(result.lines) or fallbackLines or 0
    local chars = finiteNumber(result.chars) or fallbackChars or 0
    local values = {
        "Conversion completed.",
        "Engine: " .. tostring(result.engine or "automatic per input mode"),
        "VTracer profile: " .. tostring(result.trace_profile or "not used"),
        "ASS lines: " .. tostring(math.floor(lines)),
        "Characters: " .. tostring(math.floor(chars)),
    }
    local elapsed = finiteNumber(result.elapsed_seconds)
    if elapsed then values[#values + 1] = string.format("Backend time: %.2f s", elapsed) end
    local frames = finiteNumber(result.frames)
    if frames then values[#values + 1] = "Frames: " .. tostring(math.floor(frames)) end
    local peak = finiteNumber(result.peak_lines)
    if peak then values[#values + 1] = "Peak lines in one frame: " .. tostring(math.floor(peak)) end
    local warnings = type(result.warnings) == "table" and result.warnings or {}
    if #warnings > 0 then
        values[#values + 1] = ""
        values[#values + 1] = "Warnings:"
        for index = 1, math.min(#warnings, 12) do values[#values + 1] = "- " .. tostring(warnings[index]) end
        if #warnings > 12 then values[#values + 1] = "- ... and " .. tostring(#warnings - 12) .. " more warnings." end
    end
    values[#values + 1] = ""
    values[#values + 1] = "Insert the converted ASS lines?"
    return table.concat(values, "\n")
end

local function confirmInsertion(result, fallbackLines, fallbackChars)
    local button = aegisub.dialog.display({
        { class = "textbox", value = conversionSummary(result, fallbackLines, fallbackChars), x = 0, y = 0, width = 62, height = 14 },
    }, { "Insert", "Cancel" }, { ok = "Insert", close = "Cancel" })
    return button == "Insert"
end

local function makeShapeLine(source, assText, startTime, endTime)
    local line = copyLine(source)
    line.comment = false
    line.layer = (tonumber(source.layer) or 0) + 1
    line.text = assText
    if startTime ~= nil then line.start_time = startTime end
    if endTime ~= nil then line.end_time = endTime end
    return line
end

local function selectedDialogueRecords(subs, sel)
    local records, rejected = LineOps.selectedLines(subs, sel, function(line)
        return line and line.class == "dialogue" and not line.comment
    end, true)
    if not records or #records == 0 then
        local suffix = rejected and #rejected > 0 and (" Invalid rows: " .. table.concat(rejected, ", ")) or ""
        return nil, "Select only uncommented dialogue lines." .. suffix
    end
    return records
end

local frameFromMs = Media.frameFromMs
local msFromFrame = Media.msFromFrame

local function buildFrameJobs(subs, sel)
    if not aegisub or not aegisub.frame_from_ms or not aegisub.ms_from_frame then return nil, "A loaded video is required to map images to frames." end
    local records, message = selectedDialogueRecords(subs, sel)
    if not records then return nil, message end
    local jobs = {}
    for _, record in ipairs(records) do
        if cancellationRequested() then return nil, CANCELLED end
        local lineStart = finiteNumber(record.line.start_time)
        local lineEnd = finiteNumber(record.line.end_time)
        if not lineStart or not lineEnd or lineEnd <= lineStart then
            return nil, "Selected row " .. tostring(record.index) .. " has invalid timing."
        end
        local startFrame = frameFromMs(lineStart)
        local endFrame = frameFromMs(lineEnd)
        if not startFrame or not endFrame then return nil, "Could not read frame timing from selected row " .. tostring(record.index) .. "." end
        startFrame = math.floor(startFrame)
        endFrame = math.floor(endFrame)
        if endFrame <= startFrame then return nil, "Selected row " .. tostring(record.index) .. " does not cover a video frame." end
        for frame = startFrame, endFrame - 1 do
            if #jobs % insertChunkSize == 0 and cancellationRequested() then return nil, CANCELLED end
            local startMs = msFromFrame(frame)
            local endMs = msFromFrame(frame + 1)
            if not startMs or not endMs or endMs <= startMs then return nil, "Invalid frame timing at frame " .. tostring(frame) .. "." end
            startMs = math.max(startMs, lineStart)
            endMs = math.min(endMs, lineEnd)
            if endMs <= startMs then return nil, "Selected row " .. tostring(record.index) .. " has an empty frame intersection." end
            jobs[#jobs + 1] = {
                index = record.index,
                line = record.line,
                frame = frame,
                start_time = startMs,
                end_time = endMs,
                sequence_index = #jobs + 1,
            }
        end
    end
    if #jobs == 0 then return nil, "The selected lines do not cover any frames." end
    return jobs
end

local function readSequence(path, expectedFrames)
    local content, message = readFile(path, maxSequenceChars + 1)
    if not content then return nil, message or "Sequence output was not created." end
    if #content > maxSequenceChars then return nil, "Sequence output exceeds the character limit." end
    local rows = {}
    for line in (content .. "\n"):gmatch("([^\r\n]*)\r?\n") do rows[#rows + 1] = line end
    if trim(rows[1]) ~= "PNG2ASS_SEQUENCE 1" then return nil, "Sequence output has an unsupported format." end
    local frames = {}
    local expectedIndex = 1
    local totalLines = 0
    local cursor = 2
    while cursor <= #rows do
        if cursor % insertChunkSize == 0 then
            setProgress("Validating ASS sequence", cursor / math.max(1, #rows) * 100)
            if cancellationRequested() then return nil, CANCELLED end
        end
        local row = trim(rows[cursor])
        if row == "" then
            cursor = cursor + 1
        else
            local frameIndex = finiteNumber(row:match("^FRAME%s+(%d+)$"))
            if not frameIndex or frameIndex ~= expectedIndex then return nil, "Sequence frame order is invalid near line " .. tostring(cursor) .. "." end
            cursor = cursor + 1
            local count = finiteNumber(trim(rows[cursor] or ""):match("^LINES%s+(%d+)$"))
            if not count or count < 0 or count ~= math.floor(count) then return nil, "Sequence output has an invalid line count for frame " .. tostring(frameIndex) .. "." end
            totalLines = totalLines + count
            if totalLines > maxSequenceLines then return nil, "Sequence output exceeds the ASS line limit." end
            cursor = cursor + 1
            local assLines = {}
            for _ = 1, count do
                if cursor > #rows then return nil, "Sequence output ended before frame " .. tostring(frameIndex) .. " was complete." end
                if trim(rows[cursor]) == "" then return nil, "Sequence output contains an empty ASS line for frame " .. tostring(frameIndex) .. "." end
                if not validAssShapeLine(rows[cursor]) then return nil, "Sequence output contains an invalid ASS drawing for frame " .. tostring(frameIndex) .. "." end
                assLines[#assLines + 1] = rows[cursor]
                cursor = cursor + 1
            end
            frames[frameIndex] = assLines
            expectedIndex = expectedIndex + 1
        end
    end
    local frameCount = expectedIndex - 1
    if expectedFrames and frameCount ~= expectedFrames then return nil, "Sequence output contains " .. tostring(frameCount) .. " frames; expected " .. tostring(expectedFrames) .. "." end
    return frames
end

local function insertOperationsCancellable(subs, operations)
    local total = 0
    for _, operation in ipairs(operations) do total = total + #(operation.lines or {}) end
    local completed = 0
    local descending = {}
    for _, operation in ipairs(operations) do descending[#descending + 1] = operation end
    table.sort(descending, function(left, right) return left.index > right.index end)
    for _, operation in ipairs(descending) do
        local offset = 0
        while offset < #operation.lines do
            if cancellationRequested() then error(CANCELLED, 0) end
            local chunk = {}
            local last = math.min(#operation.lines, offset + insertChunkSize)
            for position = offset + 1, last do chunk[#chunk + 1] = operation.lines[position] end
            subs.insert(operation.index + offset, unpack(chunk))
            offset = last
            completed = completed + #chunk
            setProgress("Inserting ASS lines", completed / math.max(1, total) * 100)
        end
    end
    local ascending = {}
    for _, operation in ipairs(operations) do ascending[#ascending + 1] = operation end
    table.sort(ascending, function(left, right) return left.index < right.index end)
    local inserted = {}
    local shift = 0
    for _, operation in ipairs(ascending) do
        local first = operation.index + shift
        for offset = 0, #operation.lines - 1 do inserted[#inserted + 1] = first + offset end
        shift = shift + #operation.lines
    end
    return inserted
end

local function insertShapes(subs, index, assLines)
    local source = copyLine(subs[index])
    local lines = {}
    for position, assText in ipairs(assLines) do
        if position % insertChunkSize == 0 and cancellationRequested() then error(CANCELLED, 0) end
        lines[#lines + 1] = makeShapeLine(source, assText)
    end
    return LineOps.transaction(subs, script_name, function()
        return insertOperationsCancellable(subs, { { index = index + 1, lines = lines } })
    end)
end

local function insertSequenceShapes(subs, jobs, frames)
    local grouped = {}
    local order = {}
    for jobIndex, job in ipairs(jobs) do
        if jobIndex % insertChunkSize == 0 and cancellationRequested() then error(CANCELLED, 0) end
        local assLines = frames[job.sequence_index]
        if not assLines then return nil, "Missing converted shape for frame " .. tostring(job.sequence_index) .. "." end
        if not grouped[job.index] then grouped[job.index] = {}; order[#order + 1] = job.index end
        for _, assText in ipairs(assLines) do
            grouped[job.index][#grouped[job.index] + 1] = makeShapeLine(job.line, assText, job.start_time, job.end_time)
        end
    end
    table.sort(order)
    local operations = {}
    for _, index in ipairs(order) do
        if #grouped[index] > 0 then operations[#operations + 1] = { index = index + 1, lines = grouped[index] } end
    end
    if #operations == 0 then return {} end
    return LineOps.transaction(subs, script_name, function() return insertOperationsCancellable(subs, operations) end)
end

function PNG2ASS.Main(subs, sel, activeLine)
    local records, selectionError = selectedDialogueRecords(subs, sel)
    if not records then cancelWith(selectionError) end
    local index = records[1].index
    for _, record in ipairs(records) do
        if record.index == activeLine then index = record.index; break end
    end
    local line = subs[index]
    local cfg = readConfig()
    local imagePaths = selectPngs()
    local frameJobs
    if #imagePaths > 1 then
        local message
        frameJobs, message = buildFrameJobs(subs, sel)
        if not frameJobs then cancelWith(message) end
        if #imagePaths ~= #frameJobs then
            cancelWith("Image count does not match selected frame count.\n\nImages: " .. tostring(#imagePaths) .. "\nFrames: " .. tostring(#frameJobs))
        end
    end
    local options = createDialog(line, cfg, #imagePaths, frameJobs and #frameJobs or nil)
    local posX, posY, positionError = resolvePosition(options, line)
    if not posX then cancelWith(positionError) end
    local paths, pathError = allocateTempPaths()
    if not paths then cancelWith(pathError or "Could not allocate temporary files.") end
    local completed, selection, active = pcall(function()
        local sequence = #imagePaths > 1
        local command, commandError, arguments
        if sequence then
            local wrote, message = writeFile(paths.list, table.concat(imagePaths, "\n"))
            if not wrote then cancelWith(message or "Could not create the image list.") end
            command, commandError, arguments = buildSequenceCommand(paths, options, posX, posY)
        else
            command, commandError, arguments = buildCommand(paths, imagePaths[1], options, posX, posY)
        end
        if not command then cancelWith(commandError or "Could not build the conversion command.") end
        local ok, log, wasCancelled = runManagedBackend(options.python, arguments, paths)
        if wasCancelled then aegisub.cancel() end
        if not ok then cancelWith(log and trim(log) ~= "" and log or "Image conversion failed. Use Backend/Check or Backend/Install or Update.") end
        local data, message
        if sequence then data, message = readSequence(paths.sequence, #frameJobs)
        else data, message = readLines(paths.out) end
        if message == CANCELLED then aegisub.cancel() end
        if not data or not sequence and #data == 0 then cancelWith(message or "Conversion produced no ASS drawings.") end
        local groups = sequence and data or {data}
        local totalLines, totalChars = 0, 0
        for _, lines in ipairs(groups) do
            totalLines = totalLines + #lines
            for _, text in ipairs(lines) do totalChars = totalChars + #text end
        end
        if not confirmInsertion(decodeJsonFile(paths.result), totalLines, totalChars) then aegisub.cancel() end
        local inserted, newSel, insertError
        if sequence then inserted, newSel, insertError = pcall(insertSequenceShapes, subs, frameJobs, data)
        else inserted, newSel, insertError = pcall(insertShapes, subs, index, data) end
        if not inserted and tostring(newSel) == CANCELLED then aegisub.cancel() end
        if not inserted or not newSel then cancelWith(insertError or ("Could not insert converted shapes atomically: " .. tostring(newSel or "unknown error"))) end
        local saved, saveError = persistOptions(options, cfg)
        if not saved then showMessage("Conversion completed, but settings could not be saved:\n" .. tostring(saveError or "unknown error")) end
        if #newSel == 0 then return sel, activeLine end
        return newSel, newSel[1]
    end)
    PyBridge.cleanup(paths)
    if not completed then error(selection, 0) end
    return selection, active
end

function PNG2ASS.CanRun(subs, sel)
    local records = selectedDialogueRecords(subs, sel)
    return records ~= nil
end

PNG2ASS.main = PNG2ASS.Main
PNG2ASS.can_run = PNG2ASS.CanRun

if aegisub and aegisub.register_macro then
    local entries = {
        { script_name, script_description, PNG2ASS.Main, PNG2ASS.CanRun },
        { "Backend/Check", "Check installation, dependencies and available updates", checkPackageMain },
        { "Backend/Install or Update", "Install or update kite-png2ass from the configured repository", installPackageMain },
        { "Backend/Configure", "Configure Python and package source", configurePackageMain },
    }
    if depctrl and depctrl.registerMacro and depctrl.registerMacros then
        depctrl:registerMacros(entries)
    else
        for _, entry in ipairs(entries) do
            aegisub.register_macro(script_name .. "/" .. entry[1], entry[2], entry[3], entry[4])
        end
    end
end

require("kite.UI").publishActions()

return PNG2ASS
