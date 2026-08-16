script_name        = "PNG2ASS"
script_description = "Convert images and SVG files into ASS drawing lines"
script_author      = "Kiterow"
script_version     = "1.5.0"
script_namespace   = "kite.PNG2ASS"

local PNG2ASS = {}

local module_name = "ass_png2ass"
local config_file_name = "kite.PNG2ASS.conf"
local default_install_source = "git+https://github.com/Kiterowx/kite-png2ass.git"
local IMAGE_FILTER = "Images (.png .jpg .jpeg .webp .bmp .tif .tiff .gif .tga .svg)|"
    .. "*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.tif;*.tiff;*.gif;*.tga;*.svg"
local SUPPORTED_EXTENSIONS = {
    png = true, jpg = true, jpeg = true, webp = true, bmp = true,
    tif = true, tiff = true, gif = true, tga = true, svg = true,
}
local MAX_SEQUENCE_FRAMES = 10000
local MAX_SEQUENCE_LINES = 500000
local MAX_SEQUENCE_CHARS = 100000000
local MAX_BACKEND_LINE_CHARS = 8000000
local MAX_LOG_CHARS = 1000000
local PROCESS_POLL_MS = 100
local PROCESS_EXIT_GRACE_POLLS = 30
local INSERT_CHUNK_SIZE = 128
local CANCELLED = "PNG2ASS_CANCELLED"
local TEMP_STAMP_FORMAT = "%Y%m%d%H%M%S"
local STATUS_TEXT_LIMIT = 200

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
                    version = "1.1.3",
                    url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
                    feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
                },
                {
                    "kite.PyBridge",
                    version = "1.5.0",
                    url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
                    feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
                },
                {
                    "kite.LineOps",
                    version = "1.5.2",
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
local json
do
    if depctrl and depctrl.requireModules then
        local ok, _, ui, bridge, lineops = pcall(function()
            return depctrl:requireModules()
        end)
        if ok then
            KiteUI = ui
            PyBridge = bridge
            LineOps = lineops
        end
    end
end
KiteUI = KiteUI or require("kite.UI")
PyBridge = PyBridge or require("kite.PyBridge")
LineOps = LineOps or require("kite.LineOps")

do
    local ok, value = pcall(require, "json")
    if not ok or not value or type(value.decode) ~= "function" then
        ok, value = pcall(require, "l0.dkjson")
    end
    if ok and value and type(value.decode) == "function" then json = value end
end

local DEFAULTS = {
    python = "python",
    install_source = default_install_source,
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
local TRACE_PROFILES = { "balanced", "quality" }
local POSITIONS = { "0,0", "Active pos", "Manual" }
local COLORS = { "style", "source" }
local OPTION_LIMITS = {
    threshold = { min = 1, max = 99, integer = true },
    p_scale = { min = 1, max = 6, integer = true },
    line_warning = { min = 1, max = MAX_SEQUENCE_LINES, integer = true },
    simplify = { min = 0, max = 20 },
    min_area = { min = 0, max = 10000 },
    x = { min = -20000, max = 20000, integer = true },
    y = { min = -20000, max = 20000, integer = true },
    blur = { min = 0, max = 20 },
    denoise = { min = 0, max = 5, integer = true },
    max_chars = { min = 1000, max = MAX_BACKEND_LINE_CHARS, integer = true },
    max_pixels = { min = 250000, max = 200000000, integer = true },
}

local function list_contains(values, wanted)
    for _, value in ipairs(values) do if value == wanted then return true end end
    return false
end

local trim = LineOps.trim
local join_path = PyBridge.joinPath
local file_exists = PyBridge.fileExists
local write_file = PyBridge.writeFile
local copy_line = LineOps.copy

local function finite_number(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then return nil end
    return number
end

local function normalize_main_options(values)
    values = type(values) == "table" and values or {}
    local normalized = {}
    normalized.engine = "auto"
    normalized.mode = list_contains(MODES, values.mode) and values.mode or DEFAULTS.mode
    normalized.trace_profile = list_contains(TRACE_PROFILES, values.trace_profile) and values.trace_profile or DEFAULTS.trace_profile
    normalized.position = list_contains(POSITIONS, values.position) and values.position or DEFAULTS.position
    normalized.color = list_contains(COLORS, values.color) and values.color or DEFAULTS.color
    for name, limits in pairs(OPTION_LIMITS) do
        local value = finite_number(values[name]) or DEFAULTS[name]
        value = math.max(limits.min, math.min(limits.max, value))
        if limits.integer then value = LineOps.round(value) end
        normalized[name] = value
    end
    normalized.python = type(values.python) == "string" and trim(values.python) or ""
    return normalized
end

local function valid_ass_shape(shape)
    local current, count, first, spline_open
    count, spline_open = 0, false
    local function finish_command()
        if not current then return false end
        if current == "c" then
            if count ~= 0 or not spline_open then return false end
            spline_open = false
            return true
        elseif current == "s" then
            if count < 6 or count % 2 ~= 0 then return false end
            spline_open = true
            return true
        elseif current == "p" then
            return spline_open and count == 2
        elseif current == "b" then
            spline_open = false
            return count >= 6 and count % 6 == 0
        elseif current == "l" then
            spline_open = false
            return count >= 2 and count % 2 == 0
        end
        spline_open = false
        return count == 2
    end
    for token in tostring(shape or ""):gmatch("%S+") do
        local candidate = token:lower()
        if candidate:match("^[mnlbspc]$") then
            if token ~= candidate then return false end
            if current and not finish_command() then return false end
            current = candidate
            first = first or current
            count = 0
        else
            if not current or current == "c" or finite_number(token) == nil then return false end
            count = count + 1
        end
    end
    return (first == "m" or first == "n") and finish_command()
end

local function valid_ass_shape_line(line)
    if type(line) ~= "string" or line == "" or #line > MAX_BACKEND_LINE_CHARS then return false end
    if line:find("[%z\1-\8\11\12\14-\31]") or line:find("[\r\n]") then return false end
    local drawings = {}
    for _, section in ipairs(LineOps.scanSections(line)) do
        if section.type == "drawing" then
            if trim(section.text) ~= "" then drawings[#drawings + 1] = section.text end
        elseif section.type ~= "override" and trim(section.text) ~= "" then
            return false
        end
    end
    if #drawings == 0 then return false end
    return valid_ass_shape(table.concat(drawings, " "))
end

local function read_file(path, limit)
    return PyBridge.readFile(path, limit)
end

local function read_log(path)
    local content = read_file(path, MAX_LOG_CHARS + 1)
    if content and #content > MAX_LOG_CHARS then return content:sub(1, MAX_LOG_CHARS) .. "\n[output truncated]" end
    return content
end

local cancellation_requested
local set_progress

local function read_lines(path)
    local content, message = read_file(path, MAX_SEQUENCE_CHARS + 1)
    if not content then
        return nil, message
    end
    if #content > MAX_SEQUENCE_CHARS then return nil, "Backend output exceeds the character limit." end
    local lines = {}
    for line in (content .. "\n"):gmatch("([^\r\n]*)\r?\n") do
        line = trim(line)
        if line ~= "" then
            if not valid_ass_shape_line(line) then
                return nil, "Backend output contains an invalid ASS drawing at line " .. tostring(#lines + 1) .. "."
            end
            lines[#lines + 1] = line
            if #lines > MAX_SEQUENCE_LINES then return nil, "Backend output exceeds the ASS line limit." end
            if #lines % INSERT_CHUNK_SIZE == 0 then
                set_progress("Validating ASS output", math.min(99, #lines / math.max(1, MAX_SEQUENCE_LINES) * 100))
                if cancellation_requested() then return nil, CANCELLED end
            end
        end
    end
    return lines
end

local ensure_dir = PyBridge.ensureDir

local function show_message(message)
    aegisub.dialog.display({
        { class = "textbox", value = tostring(message or ""), x = 0, y = 0, width = 56, height = 10 },
    }, { "OK" })
end

local function cancel_with(message)
    show_message(message)
    aegisub.cancel()
end

local temp_paths

cancellation_requested = function()
    if not aegisub or not aegisub.progress or type(aegisub.progress.is_cancelled) ~= "function" then return false end
    local ok, cancelled = pcall(aegisub.progress.is_cancelled)
    return ok and cancelled == true
end

set_progress = function(task, percent)
    if not aegisub or not aegisub.progress then return end
    if task and type(aegisub.progress.task) == "function" then pcall(aegisub.progress.task, tostring(task)) end
    if percent and type(aegisub.progress.set) == "function" then pcall(aegisub.progress.set, math.max(0, math.min(100, percent))) end
end

local function decode_json_file(path)
    if not json then return nil, "JSON support is unavailable." end
    local content, message = read_file(path, MAX_LOG_CHARS + 1)
    if not content then return nil, message end
    if #content > MAX_LOG_CHARS then return nil, "JSON output is too large." end
    local ok, value = pcall(json.decode, content)
    if not ok or type(value) ~= "table" then return nil, ok and "JSON output is invalid." or tostring(value) end
    return value
end

local function powershell_literal(value)
    return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end

local function windows_quote_argument(value)
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

local function managed_runner_script(python, arguments, paths)
    local native = { "-m", module_name }
    for _, value in ipairs(arguments or {}) do native[#native + 1] = tostring(value) end
    local quoted = {}
    for _, value in ipairs(native) do quoted[#quoted + 1] = windows_quote_argument(value) end
    local argument_line = table.concat(quoted, " ")
    local cancel = powershell_literal(paths.cancel)
    local stdout = powershell_literal(paths.stdout)
    local stderr = powershell_literal(paths.stderr)
    local cmdlog = powershell_literal(paths.cmdlog)
    local exit_path = powershell_literal(paths.exit)
    return table.concat({
        "$ErrorActionPreference = 'Stop'",
        "$utf8 = New-Object System.Text.UTF8Encoding($false)",
        "$exitCode = 1",
        "$cancelled = $false",
        "$process = $null",
        "$stdoutText = ''",
        "$stderrText = ''",
        "try {",
        "    $argumentLine = " .. powershell_literal(argument_line),
        "    $startInfo = New-Object System.Diagnostics.ProcessStartInfo",
        "    $startInfo.FileName = " .. powershell_literal(python),
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
        "        Start-Sleep -Milliseconds " .. tostring(PROCESS_POLL_MS),
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
        "[IO.File]::WriteAllText(" .. exit_path .. ", [string]$exitCode, $utf8)",
        "exit $exitCode",
    }, "\r\n")
end

local function update_backend_progress(paths)
    if not file_exists(paths.progress) then return end
    local progress = decode_json_file(paths.progress)
    if not progress then return end
    set_progress(progress.stage or "Converting image", finite_number(progress.percent))
end

local function wait_for_process_exit(pid, exit_path)
    for poll = 1, PROCESS_EXIT_GRACE_POLLS do
        if (not exit_path or file_exists(exit_path)) and not PyBridge.processExists(pid) then return true end
        PyBridge.sleep(PROCESS_POLL_MS)
    end
    return not PyBridge.processExists(pid)
end

local function run_managed_backend(python, arguments, paths)
    if not PyBridge.isWindows then return false, "Cancelable PNG2ASS conversion currently requires Windows." end
    if type(PyBridge.startDetachedScript) ~= "function" or type(PyBridge.processExists) ~= "function" or type(PyBridge.sleep) ~= "function" then
        return false, "kite.PyBridge 1.5.0 or newer is required for cancelable conversion."
    end
    local wrote, write_error = write_file(paths.runner, managed_runner_script(python, arguments, paths))
    if not wrote then return false, write_error or "Could not create the managed backend runner." end
    local started, pid = PyBridge.startDetachedScript(paths.runner)
    if not started then return false, pid or "Could not start the managed backend runner." end

    set_progress("Starting PNG2ASS backend", 0)
    local poll = 0
    while not file_exists(paths.exit) do
        poll = poll + 1
        if cancellation_requested() then
            local signalled, signal_error = write_file(paths.cancel, "cancel")
            if not signalled then return false, signal_error or "Could not signal backend cancellation." end
            set_progress("Cancelling PNG2ASS backend", nil)
            if not wait_for_process_exit(pid, paths.exit) then
                return false, "The managed PNG2ASS process did not stop after cancellation."
            end
            return false, CANCELLED, true
        end
        update_backend_progress(paths)
        if poll % 10 == 0 and not PyBridge.processExists(pid) then
            for _ = 1, 5 do
                if file_exists(paths.exit) then break end
                PyBridge.sleep(PROCESS_POLL_MS)
            end
            if not file_exists(paths.exit) then return false, "The PNG2ASS supervisor exited without reporting a result." end
            break
        end
        PyBridge.sleep(PROCESS_POLL_MS)
    end

    if not wait_for_process_exit(pid, paths.exit) then return false, "The PNG2ASS supervisor did not exit cleanly." end
    local exit_text, exit_error = read_file(paths.exit, 32)
    local exit_code = exit_text and tonumber(trim(exit_text)) or nil
    if exit_code == nil then return false, exit_error or "The PNG2ASS exit code is invalid." end
    local log = read_log(paths.log)
    if not log or trim(log) == "" then log = read_log(paths.cmdlog) end
    return exit_code == 0, log, exit_code == 130
end

local function run_command(command, log_path)
    if not command or trim(command) == "" then
        write_file(log_path, "Command could not be built.")
        return false
    end
    local ok, log = PyBridge.run(command)
    write_file(log_path, log or "")
    return ok
end

local function run_command_dialog(title, command, ok_message)
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

        local run_label = "Execute"
        local button, result = aegisub.dialog.display(interface, { run_label, "Cancel" }, { ok = run_label, close = "Cancel" })
        if button ~= run_label then
            aegisub.cancel()
        end

        current = trim(result.command)
        if current == "" then
            log = "Command is empty."
        else
            local paths, path_error = temp_paths()
            if not paths then
                log = path_error or "Could not allocate temporary files."
            elseif run_command(current, paths.cmdlog) then
                show_message(ok_message)
                return true
            else
                log = read_log(paths.cmdlog) or "Command failed."
            end
        end
    end
end

local function source_dir()
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

local function decoded_path(spec)
    if aegisub and aegisub.decode_path then
        local ok, path = pcall(aegisub.decode_path, spec)
        if ok and type(path) == "string" and path ~= "" and path ~= spec then
            return path
        end
    end
    return nil
end

local function script_dir()
    local dir = source_dir()
    if dir then
        return dir
    end
    local user_path = decoded_path("?user")
    if user_path then
        return join_path(join_path(user_path, "automation"), "autoload")
    end
    return decoded_path("?script") or "."
end

local function local_package_source()
    local source = join_path(script_dir(), "ass_png2ass")
    if file_exists(join_path(source, "pyproject.toml")) then
        return source
    end
    return default_install_source
end

local function default_python()
    return PyBridge.resolvePython(
        "",
        join_path(join_path(script_dir(), "ass_png2ass"), ".venv")
    )
end

local function default_config()
    return {
        python = default_python(),
        install_source = local_package_source(),
    }
end

local function config_path(create)
    local user_path = decoded_path("?user")
    if user_path then
        local dir = join_path(user_path, "config")
        if create then
            ensure_dir(dir)
        end
        return join_path(dir, config_file_name)
    end
    return join_path(script_dir(), config_file_name)
end

local PNG_SETTINGS = KiteUI.settings(script_namespace, script_version, {
    package = default_config(),
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
    { path = config_path(false), format = "key_value", target = "package" },
})

local function read_config()
    local cfg = PNG_SETTINGS:values("package")
    if trim(cfg.python) == "" then
        cfg.python = default_python()
    end
    if trim(cfg.install_source) == "" then
        cfg.install_source = local_package_source()
    elseif cfg.install_source:find("png2ass_" .. "back" .. "end", 1, true) or cfg.install_source:find("png2ass-" .. "back" .. "end", 1, true) then
        cfg.install_source = local_package_source()
    end
    return cfg
end

local function write_config(cfg)
    PNG_SETTINGS:update("package", cfg)
    return PNG_SETTINGS:write()
end

local function python_path_error(value)
    local python = trim(value)
    if not python:find("[/\\]") or file_exists(python) then return nil end
    return "The configured Python interpreter was not found.\nPath: " .. python
        .. "\nOpen PNG2ASS/Backend/Configure and set Python to python or select an existing interpreter."
end

function temp_paths()
    local paths = PyBridge.tempPaths("png2ass", {
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
    if paths then
        return paths
    end
    local temp = join_path(script_dir(), "temp")
    local created, message = ensure_dir(temp)
    if not created then return nil, message or "Could not create a temporary directory." end
    local stamp = os.date(TEMP_STAMP_FORMAT) .. "." .. PyBridge.uniqueSuffix()
    return {
        out = join_path(temp, "png2ass_" .. stamp .. ".txt"),
        list = join_path(temp, "png2ass_" .. stamp .. ".list"),
        sequence = join_path(temp, "png2ass_" .. stamp .. ".seq"),
        log = join_path(temp, "png2ass_" .. stamp .. ".log"),
        cmdlog = join_path(temp, "png2ass_" .. stamp .. ".cmd.log"),
        result = join_path(temp, "png2ass_" .. stamp .. ".result.json"),
        progress = join_path(temp, "png2ass_" .. stamp .. ".progress.json"),
        cancel = join_path(temp, "png2ass_" .. stamp .. ".cancel"),
        runner = join_path(temp, "png2ass_" .. stamp .. ".runner.ps1"),
        stdout = join_path(temp, "png2ass_" .. stamp .. ".stdout.log"),
        stderr = join_path(temp, "png2ass_" .. stamp .. ".stderr.log"),
        exit = join_path(temp, "png2ass_" .. stamp .. ".exit"),
    }
end

local function active_pos(text)
    local calls = LineOps.tagCalls(text, { pos = true })
    for index = #calls, 1, -1 do
        local x, y = calls[index].value:match("^%(%s*([%+%-]?[%d%.]+)%s*,%s*([%+%-]?[%d%.]+)%s*%)$")
        x, y = finite_number(x), finite_number(y)
        if x and y then return x, y end
    end
    return nil, nil
end

local function natural_key(path)
    local name = tostring(path or ""):match("([^\\/]+)$") or tostring(path or "")
    name = name:lower()
    return name:gsub("(%d+)", function(number)
        local significant = number:gsub("^0+", "")
        if significant == "" then significant = "0" end
        return string.format("%08d:%s", #significant, significant)
    end)
end

local function normalize_paths(value)
    local paths = {}
    local rejected = {}
    local seen = {}
    local values = type(value) == "table" and value or { value }
    for _, path in ipairs(values) do
        path = type(path) == "string" and trim(path) or ""
        local key = PyBridge.isWindows and path:lower() or path
        local extension = path:lower():match("%.([^.\\/]+)$")
        local unsafe_list_path = path:find("[\r\n]") or path:find("%z")
        if path ~= "" and not unsafe_list_path and SUPPORTED_EXTENSIONS[extension] and file_exists(path) and not seen[key] then
            seen[key] = true
            paths[#paths + 1] = path
        elseif path ~= "" and (unsafe_list_path or not SUPPORTED_EXTENSIONS[extension] or not file_exists(path)) then
            rejected[#rejected + 1] = path
        end
    end
    table.sort(paths, function(left, right)
        local left_key = natural_key(left)
        local right_key = natural_key(right)
        if left_key == right_key then return left:lower() < right:lower() end
        return left_key < right_key
    end)
    return paths, rejected
end

local function select_pngs()
    local result = aegisub.dialog.open(
        "Select Images",
        "",
        script_dir(),
        IMAGE_FILTER,
        true,
        true
    )
    local paths, rejected = normalize_paths(result)
    if #rejected > 0 then
        cancel_with("Some selected images are missing or unsupported:\n" .. table.concat(rejected, "\n"))
    end
    if #paths == 0 then
        aegisub.cancel()
    end
    return paths
end

local function package_config_dialog(title, buttons)
    local cfg = read_config()
    local interface = {
        title = { class = "label", label = title, x = 0, y = 0, width = 8, height = 1 },
        python_label = { class = "label", label = "Python", x = 0, y = 1, width = 2, height = 1 },
        python = { class = "edit", name = "python", value = cfg.python, x = 2, y = 1, width = 14, height = 1 },
        source_label = { class = "label", label = "Install source", x = 0, y = 2, width = 3, height = 1 },
        install_source = { class = "edit", name = "install_source", value = cfg.install_source, x = 3, y = 2, width = 13, height = 1 },
    }
    local button, result = aegisub.dialog.display(interface, buttons or { "Execute", "Cancel" }, { ok = buttons and buttons[1] or "Execute", close = "Cancel" })
    if button == "Cancel" then
        aegisub.cancel()
    end
    result.python = trim(result.python)
    result.install_source = trim(result.install_source)
    if result.python == "" then
        result.python = default_python()
    end
    if result.install_source == "" then
        result.install_source = local_package_source()
    end
    return button, result
end

local function package_status(cfg)
    local command, message = PyBridge.moduleCommand(cfg.python, module_name, { "--status", "--source", cfg.install_source })
    if not command then return false, message end
    return PyBridge.run(command)
end

local function status_summary(detail)
    if not json then return "The backend status cannot be decoded because no JSON module is available.", false, nil, false end
    local ok, status = pcall(json.decode, tostring(detail or ""))
    if not ok or type(status) ~= "table" or type(status.ready) ~= "boolean" or
        (status.update_available ~= nil and type(status.update_available) ~= "boolean") then
        return "The backend returned an invalid status response.", false, nil, false
    end
    local function status_text(value, fallback)
        if type(value) ~= "string" or trim(value) == "" then return fallback end
        return trim(value):gsub("[\r\n]+", " "):sub(1, STATUS_TEXT_LIMIT)
    end
    local installed = status_text(status.installed_version, "unknown")
    local latest = status_text(status.latest_version, "unavailable")
    local ready = status.ready
    local update_available = status.update_available
    local update_error = status_text(status.update_error, "unavailable")
    local lines = {
        "Package: kite-png2ass",
        "Installed: " .. installed,
        "Source version: " .. latest,
        "Runtime: " .. (ready == false and "needs repair" or "ready"),
    }
    if update_available == true then
        lines[#lines + 1] = "Update: available"
    elseif latest ~= "unavailable" then
        lines[#lines + 1] = "Update: not required"
    else
        lines[#lines + 1] = "Update check: " .. (update_error or "unavailable")
    end
    return table.concat(lines, "\n"), ready, update_available, true
end

local function backend_action(message, buttons)
    local button = aegisub.dialog.display({
        { class = "textbox", value = tostring(message or ""), x = 0, y = 0, width = 70, height = 12 },
    }, buttons, { ok = buttons[1], close = buttons[#buttons] })
    return button
end

local function install_package_main()
    local cfg = read_config()
    local missing_python = python_path_error(cfg.python)
    if missing_python then cancel_with(missing_python) end
    local install, install_error = PyBridge.installCommand(cfg.python, cfg.install_source)
    local check, check_error = PyBridge.moduleCommand(cfg.python, module_name, { "--status", "--source", cfg.install_source })
    if not install or not check then cancel_with(install_error or check_error or "Package command could not be built.") end
    run_command_dialog("PNG2ASS Package", PyBridge.chain(install, check), "Package is installed and ready.")
end

local function configure_package_main()
    local _, cfg = package_config_dialog("PNG2ASS Package", { "Execute", "Cancel" })
    local ok, message = write_config(cfg)
    if not ok then return show_message("Could not save package configuration:\n" .. tostring(message or "unknown error")) end
    show_message("Package configuration saved.")
end

local function check_package_main()
    local cfg = read_config()
    local missing_python = python_path_error(cfg.python)
    if missing_python then
        local action = backend_action(missing_python, { "Configure", "Close" })
        if action == "Configure" then return configure_package_main() end
        return
    end
    local ok, detail = package_status(cfg)
    if not ok then
        local action = backend_action(
            "The kite-png2ass package was not found or could not start.\n\n" .. tostring(detail or ""),
            { "Install", "Configure", "Close" }
        )
        if action == "Install" then return install_package_main() end
        if action == "Configure" then return configure_package_main() end
        return
    end

    local summary, ready, update_available, valid_status = status_summary(detail)
    if not valid_status then
        local action = backend_action(summary, { "Repair", "Configure", "Close" })
        if action == "Repair" then return install_package_main() end
        if action == "Configure" then return configure_package_main() end
    elseif ready == false then
        local action = backend_action(summary, { "Repair", "Configure", "Close" })
        if action == "Repair" then return install_package_main() end
        if action == "Configure" then return configure_package_main() end
    elseif update_available == true then
        local action = backend_action(summary, { "Update", "Close" })
        if action == "Update" then return install_package_main() end
    else
        show_message(summary)
    end
end

local function create_dialog(line, cfg, image_count, frame_count)
    local px, py = active_pos(line.text)
    local saved = normalize_main_options(PNG_SETTINGS:values("main"))
    local default_position = (px and py) and "Active pos" or saved.position
    local count_label = "Images: " .. tostring(image_count or 1)
    if frame_count then
        count_label = count_label .. " / Frames: " .. tostring(frame_count)
    end
    local interface = {
        title = { class = "label", label = "PNG2ASS", x = 0, y = 0, width = 6, height = 1 },
        mode_label = { class = "label", label = "Mode", x = 0, y = 1, width = 2, height = 1 },
        mode = { class = "dropdown", name = "mode", items = MODES, value = saved.mode, x = 2, y = 1, width = 3, height = 1 },
        color_label = { class = "label", label = "Color", x = 5, y = 1, width = 2, height = 1 },
        color = { class = "dropdown", name = "color", items = COLORS, value = saved.color, x = 7, y = 1, width = 3, height = 1 },
        profile_label = { class = "label", label = "VTracer", x = 10, y = 1, width = 2, height = 1 },
        trace_profile = { class = "dropdown", name = "trace_profile", items = TRACE_PROFILES, value = saved.trace_profile, x = 12, y = 1, width = 3, height = 1 },
        threshold_label = { class = "label", label = "Threshold", x = 0, y = 2, width = 3, height = 1 },
        threshold = { class = "intedit", name = "threshold", value = saved.threshold, min = OPTION_LIMITS.threshold.min, max = OPTION_LIMITS.threshold.max, x = 3, y = 2, width = 3, height = 1 },
        scale_label = { class = "label", label = "Scale", x = 6, y = 2, width = 2, height = 1 },
        p_scale = { class = "intedit", name = "p_scale", value = saved.p_scale, min = OPTION_LIMITS.p_scale.min, max = OPTION_LIMITS.p_scale.max, x = 8, y = 2, width = 2, height = 1 },
        simplify_label = { class = "label", label = "Simplify", x = 0, y = 3, width = 3, height = 1 },
        simplify = { class = "floatedit", name = "simplify", value = saved.simplify, min = OPTION_LIMITS.simplify.min, max = OPTION_LIMITS.simplify.max, step = 0.25, x = 3, y = 3, width = 3, height = 1 },
        min_area_label = { class = "label", label = "Min area", x = 6, y = 3, width = 3, height = 1 },
        min_area = { class = "floatedit", name = "min_area", value = saved.min_area, min = OPTION_LIMITS.min_area.min, max = OPTION_LIMITS.min_area.max, step = 1, x = 9, y = 3, width = 3, height = 1 },
        position_label = { class = "label", label = "Position", x = 0, y = 4, width = 3, height = 1 },
        position = { class = "dropdown", name = "position", items = POSITIONS, value = default_position, x = 3, y = 4, width = 4, height = 1 },
        x_label = { class = "label", label = "X", x = 7, y = 4, width = 1, height = 1 },
        x = { class = "intedit", name = "x", value = px or saved.x, min = OPTION_LIMITS.x.min, max = OPTION_LIMITS.x.max, x = 8, y = 4, width = 3, height = 1 },
        y_label = { class = "label", label = "Y", x = 11, y = 4, width = 1, height = 1 },
        y = { class = "intedit", name = "y", value = py or saved.y, min = OPTION_LIMITS.y.min, max = OPTION_LIMITS.y.max, x = 12, y = 4, width = 3, height = 1 },
        blur_label = { class = "label", label = "Blur", x = 0, y = 5, width = 2, height = 1 },
        blur = { class = "floatedit", name = "blur", value = saved.blur, min = OPTION_LIMITS.blur.min, max = OPTION_LIMITS.blur.max, step = 0.1, x = 2, y = 5, width = 3, height = 1 },
        denoise_label = { class = "label", label = "Denoise", x = 5, y = 5, width = 2, height = 1 },
        denoise = { class = "intedit", name = "denoise", value = saved.denoise, min = OPTION_LIMITS.denoise.min, max = OPTION_LIMITS.denoise.max, x = 7, y = 5, width = 2, height = 1 },
        max_label = { class = "label", label = "Max chars", x = 9, y = 5, width = 3, height = 1 },
        max_chars = { class = "intedit", name = "max_chars", value = saved.max_chars, min = OPTION_LIMITS.max_chars.min, max = OPTION_LIMITS.max_chars.max, x = 12, y = 5, width = 3, height = 1 },
        pixels_label = { class = "label", label = "Max pixels", x = 0, y = 6, width = 3, height = 1 },
        max_pixels = { class = "intedit", name = "max_pixels", value = saved.max_pixels, min = OPTION_LIMITS.max_pixels.min, max = OPTION_LIMITS.max_pixels.max, x = 3, y = 6, width = 5, height = 1 },
        lines_label = { class = "label", label = "Warn lines", x = 8, y = 6, width = 3, height = 1 },
        line_warning = { class = "intedit", name = "line_warning", value = saved.line_warning, min = OPTION_LIMITS.line_warning.min, max = OPTION_LIMITS.line_warning.max, x = 11, y = 6, width = 4, height = 1 },
        python_label = { class = "label", label = "Python", x = 0, y = 7, width = 2, height = 1 },
        python = { class = "edit", name = "python", value = cfg.python, x = 2, y = 7, width = 11, height = 1 },
        count_label = { class = "label", label = count_label, x = 0, y = 8, width = 15, height = 1 },
    }
    local button, result = aegisub.dialog.display(interface, { "Execute", "Cancel" }, { ok = "Execute", close = "Cancel" })
    if button ~= "Execute" then
        aegisub.cancel()
    end
    result = normalize_main_options(result)
    if result.color == "source" and result.mode == "auto" then result.mode = "color" end
    result.python = trim(result.python)
    if result.python == "" then
        result.python = cfg.python
    end
    return result
end

local function persist_options(options, cfg)
    PNG_SETTINGS:update("main", options)
    cfg.python = options.python
    return write_config(cfg)
end

local function conversion_arguments(paths, options, pos_x, pos_y)
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
        "--pos-x", tostring(pos_x),
        "--pos-y", tostring(pos_y),
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

local function build_command(paths, image_path, options, pos_x, pos_y)
    local arguments = { "--input", image_path }
    local common = conversion_arguments(paths, options, pos_x, pos_y)
    for _, value in ipairs(common) do arguments[#arguments + 1] = value end
    arguments[#arguments + 1] = "--out"
    arguments[#arguments + 1] = paths.out
    local command, message = PyBridge.moduleCommand(options.python, module_name, arguments)
    return command, message, arguments
end

local function build_sequence_command(paths, options, pos_x, pos_y)
    local arguments = { "--input-list", paths.list }
    local common = conversion_arguments(paths, options, pos_x, pos_y)
    for _, value in ipairs(common) do arguments[#arguments + 1] = value end
    arguments[#arguments + 1] = "--sequence-out"
    arguments[#arguments + 1] = paths.sequence
    local command, message = PyBridge.moduleCommand(options.python, module_name, arguments)
    return command, message, arguments
end

local function resolve_position(options, line)
    if options.position == "Active pos" then
        local px, py = active_pos(line.text)
        if not px or not py then return nil, nil, "The active line does not contain a valid \\pos tag." end
        return px, py
    end
    if options.position == "Manual" then
        local x, y = finite_number(options.x), finite_number(options.y)
        if not x or not y then return nil, nil, "The manual position is invalid." end
        return x, y
    end
    return 0, 0
end

local function conversion_summary(result, fallback_lines, fallback_chars)
    result = type(result) == "table" and result or {}
    local lines = finite_number(result.lines) or fallback_lines or 0
    local chars = finite_number(result.chars) or fallback_chars or 0
    local values = {
        "Conversion completed.",
        "Engine: " .. tostring(result.engine or "automatic per input mode"),
        "VTracer profile: " .. tostring(result.trace_profile or "not used"),
        "ASS lines: " .. tostring(math.floor(lines)),
        "Characters: " .. tostring(math.floor(chars)),
    }
    local elapsed = finite_number(result.elapsed_seconds)
    if elapsed then values[#values + 1] = string.format("Backend time: %.2f s", elapsed) end
    local frames = finite_number(result.frames)
    if frames then values[#values + 1] = "Frames: " .. tostring(math.floor(frames)) end
    local peak = finite_number(result.peak_lines)
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

local function confirm_insertion(result, fallback_lines, fallback_chars)
    local button = aegisub.dialog.display({
        { class = "textbox", value = conversion_summary(result, fallback_lines, fallback_chars), x = 0, y = 0, width = 62, height = 14 },
    }, { "Insert", "Cancel" }, { ok = "Insert", close = "Cancel" })
    return button == "Insert"
end

local function make_shape_line(source, ass_text, start_time, end_time)
    local line = copy_line(source)
    line.comment = false
    line.layer = (tonumber(source.layer) or 0) + 1
    line.text = ass_text
    if start_time ~= nil then line.start_time = start_time end
    if end_time ~= nil then line.end_time = end_time end
    return line
end

local function selected_dialogue_records(subs, sel)
    local records, rejected = LineOps.selectedLines(subs, sel, function(line)
        return line and line.class == "dialogue" and not line.comment
    end, true)
    if not records or #records == 0 then
        local suffix = rejected and #rejected > 0 and (" Invalid rows: " .. table.concat(rejected, ", ")) or ""
        return nil, "Select only uncommented dialogue lines." .. suffix
    end
    return records
end

local function frame_from_ms(ms)
    ms = finite_number(ms)
    if not ms then return nil end
    local ok, frame = pcall(aegisub.frame_from_ms, ms)
    frame = ok and finite_number(frame) or nil
    return frame and math.floor(frame) or nil
end

local function ms_from_frame(frame)
    frame = finite_number(frame)
    if not frame then return nil end
    local ok, ms = pcall(aegisub.ms_from_frame, math.floor(frame))
    ms = ok and finite_number(ms) or nil
    return ms
end

local function build_frame_jobs(subs, sel)
    if not aegisub.frame_from_ms or not aegisub.ms_from_frame then return nil, "A loaded video is required to map images to frames." end
    local records, message = selected_dialogue_records(subs, sel)
    if not records then return nil, message end
    local jobs = {}
    for _, record in ipairs(records) do
        if cancellation_requested() then return nil, CANCELLED end
        local line_start = finite_number(record.line.start_time)
        local line_end = finite_number(record.line.end_time)
        if not line_start or not line_end or line_end <= line_start then
            return nil, "Selected row " .. tostring(record.index) .. " has invalid timing."
        end
        local start_frame = frame_from_ms(line_start)
        local end_frame = frame_from_ms(line_end)
        if not start_frame or not end_frame then return nil, "Could not read frame timing from selected row " .. tostring(record.index) .. "." end
        if end_frame <= start_frame then return nil, "Selected row " .. tostring(record.index) .. " does not cover a video frame." end
        for frame = start_frame, end_frame - 1 do
            if #jobs >= MAX_SEQUENCE_FRAMES then return nil, "Selected ranges exceed the " .. tostring(MAX_SEQUENCE_FRAMES) .. " frame limit." end
            local start_ms = ms_from_frame(frame)
            local end_ms = ms_from_frame(frame + 1)
            if not start_ms or not end_ms or end_ms <= start_ms then return nil, "Invalid frame timing at frame " .. tostring(frame) .. "." end
            start_ms = math.max(start_ms, line_start)
            end_ms = math.min(end_ms, line_end)
            if end_ms <= start_ms then return nil, "Selected row " .. tostring(record.index) .. " has an empty frame intersection." end
            jobs[#jobs + 1] = {
                index = record.index,
                line = copy_line(record.line),
                frame = frame,
                start_time = start_ms,
                end_time = end_ms,
                sequence_index = #jobs + 1,
            }
        end
    end
    if #jobs == 0 then return nil, "The selected lines do not cover any frames." end
    return jobs
end

local function read_sequence(path, expected_frames)
    local content, message = read_file(path, MAX_SEQUENCE_CHARS + 1)
    if not content then return nil, message or "Sequence output was not created." end
    if #content > MAX_SEQUENCE_CHARS then return nil, "Sequence output exceeds the character limit." end
    local rows = {}
    for line in (content .. "\n"):gmatch("([^\r\n]*)\r?\n") do rows[#rows + 1] = line end
    if trim(rows[1]) ~= "PNG2ASS_SEQUENCE 1" then return nil, "Sequence output has an unsupported format." end
    local frames = {}
    local expected_index = 1
    local total_lines = 0
    local cursor = 2
    while cursor <= #rows do
        if cursor % INSERT_CHUNK_SIZE == 0 then
            set_progress("Validating ASS sequence", cursor / math.max(1, #rows) * 100)
            if cancellation_requested() then return nil, CANCELLED end
        end
        local row = trim(rows[cursor])
        if row == "" then
            cursor = cursor + 1
        else
            local frame_index = finite_number(row:match("^FRAME%s+(%d+)$"))
            if not frame_index or frame_index ~= expected_index then return nil, "Sequence frame order is invalid near line " .. tostring(cursor) .. "." end
            cursor = cursor + 1
            local count = finite_number(trim(rows[cursor] or ""):match("^LINES%s+(%d+)$"))
            if not count or count < 1 or count ~= math.floor(count) then return nil, "Sequence output has an invalid line count for frame " .. tostring(frame_index) .. "." end
            total_lines = total_lines + count
            if total_lines > MAX_SEQUENCE_LINES then return nil, "Sequence output exceeds the ASS line limit." end
            cursor = cursor + 1
            local ass_lines = {}
            for _ = 1, count do
                if cursor > #rows then return nil, "Sequence output ended before frame " .. tostring(frame_index) .. " was complete." end
                if trim(rows[cursor]) == "" then return nil, "Sequence output contains an empty ASS line for frame " .. tostring(frame_index) .. "." end
                if not valid_ass_shape_line(rows[cursor]) then return nil, "Sequence output contains an invalid ASS drawing for frame " .. tostring(frame_index) .. "." end
                ass_lines[#ass_lines + 1] = rows[cursor]
                cursor = cursor + 1
            end
            frames[frame_index] = ass_lines
            expected_index = expected_index + 1
        end
    end
    local frame_count = expected_index - 1
    if expected_frames and frame_count ~= expected_frames then return nil, "Sequence output contains " .. tostring(frame_count) .. " frames; expected " .. tostring(expected_frames) .. "." end
    return frames
end

local function insert_operations_cancellable(subs, operations)
    local total = 0
    for _, operation in ipairs(operations) do total = total + #(operation.lines or {}) end
    local completed = 0
    local descending = {}
    for _, operation in ipairs(operations) do descending[#descending + 1] = operation end
    table.sort(descending, function(left, right) return left.index > right.index end)
    for _, operation in ipairs(descending) do
        local offset = 0
        while offset < #operation.lines do
            if cancellation_requested() then error(CANCELLED, 0) end
            local chunk = {}
            local last = math.min(#operation.lines, offset + INSERT_CHUNK_SIZE)
            for position = offset + 1, last do chunk[#chunk + 1] = operation.lines[position] end
            subs.insert(operation.index + offset, unpack(chunk))
            offset = last
            completed = completed + #chunk
            set_progress("Inserting ASS lines", completed / math.max(1, total) * 100)
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

local function insert_shapes(subs, index, ass_lines)
    local source = copy_line(subs[index])
    local lines = {}
    for position, ass_text in ipairs(ass_lines) do
        if position % INSERT_CHUNK_SIZE == 0 and cancellation_requested() then error(CANCELLED, 0) end
        lines[#lines + 1] = make_shape_line(source, ass_text)
    end
    return LineOps.transaction(subs, script_name, function()
        return insert_operations_cancellable(subs, { { index = index + 1, lines = lines } })
    end)
end

local function insert_sequence_shapes(subs, jobs, frames)
    local grouped = {}
    local order = {}
    for job_index, job in ipairs(jobs) do
        if job_index % INSERT_CHUNK_SIZE == 0 and cancellation_requested() then error(CANCELLED, 0) end
        local ass_lines = frames[job.sequence_index]
        if not ass_lines or #ass_lines == 0 then return nil, "Missing converted shape for frame " .. tostring(job.sequence_index) .. "." end
        if not grouped[job.index] then grouped[job.index] = {}; order[#order + 1] = job.index end
        for _, ass_text in ipairs(ass_lines) do
            grouped[job.index][#grouped[job.index] + 1] = make_shape_line(job.line, ass_text, job.start_time, job.end_time)
        end
    end
    table.sort(order)
    local operations = {}
    for _, index in ipairs(order) do operations[#operations + 1] = { index = index + 1, lines = grouped[index] } end
    return LineOps.transaction(subs, script_name, function() return insert_operations_cancellable(subs, operations) end)
end

function PNG2ASS.main(subs, sel, active_line)
    local records, selection_error = selected_dialogue_records(subs, sel)
    if not records then cancel_with(selection_error) end
    local index = records[1].index
    for _, record in ipairs(records) do
        if record.index == active_line then index = record.index; break end
    end
    local line = subs[index]
    local cfg = read_config()
    local image_paths = select_pngs()
    local frame_jobs
    if #image_paths > 1 then
        local message
        frame_jobs, message = build_frame_jobs(subs, sel)
        if not frame_jobs then cancel_with(message) end
        if #image_paths ~= #frame_jobs then
            cancel_with("Image count does not match selected frame count.\n\nImages: " .. tostring(#image_paths) .. "\nFrames: " .. tostring(#frame_jobs))
        end
    end
    local options = create_dialog(line, cfg, #image_paths, frame_jobs and #frame_jobs or nil)
    local paths, path_error = temp_paths()
    if not paths then cancel_with(path_error or "Could not allocate temporary files.") end
    local pos_x, pos_y, position_error = resolve_position(options, line)
    if not pos_x then PyBridge.cleanup(paths); cancel_with(position_error) end
    if #image_paths == 1 then
        local command, command_error, arguments = build_command(paths, image_paths[1], options, pos_x, pos_y)
        if not command then PyBridge.cleanup(paths); cancel_with(command_error or "Could not build the conversion command.") end
        local ok, log, was_cancelled = run_managed_backend(options.python, arguments, paths)
        if was_cancelled then PyBridge.cleanup(paths); aegisub.cancel() end
        if not ok then
            PyBridge.cleanup(paths)
            cancel_with(log and trim(log) ~= "" and log or "PNG conversion failed. Use Backend/Check or Backend/Install or Update.")
        end
        local ass_lines, output_error = read_lines(paths.out)
        if output_error == CANCELLED then PyBridge.cleanup(paths); aegisub.cancel() end
        if not ass_lines or #ass_lines == 0 then
            PyBridge.cleanup(paths)
            cancel_with(output_error or "PNG conversion produced no ASS drawings.")
        end
        local result = decode_json_file(paths.result)
        local chars = 0
        for _, value in ipairs(ass_lines) do chars = chars + #value end
        if not confirm_insertion(result, #ass_lines, chars) then
            PyBridge.cleanup(paths)
            aegisub.cancel()
        end
        local inserted, new_sel = pcall(insert_shapes, subs, index, ass_lines)
        if not inserted and tostring(new_sel) == CANCELLED then PyBridge.cleanup(paths); aegisub.cancel() end
        if not inserted or not new_sel then
            PyBridge.cleanup(paths)
            cancel_with("Could not insert converted shapes atomically: " .. tostring(new_sel or "unknown error"))
        end
        local settings_ok, settings_error = persist_options(options, cfg)
        PyBridge.cleanup(paths)
        if not settings_ok then show_message("Conversion completed, but settings could not be saved:\n" .. tostring(settings_error or "unknown error")) end
        return new_sel
    end
    local wrote, write_error = write_file(paths.list, table.concat(image_paths, "\n"))
    if not wrote then PyBridge.cleanup(paths); cancel_with(write_error or "Could not create the image list.") end
    local command, command_error, arguments = build_sequence_command(paths, options, pos_x, pos_y)
    if not command then PyBridge.cleanup(paths); cancel_with(command_error or "Could not build the sequence command.") end
    local ok, log, was_cancelled = run_managed_backend(options.python, arguments, paths)
    if was_cancelled then PyBridge.cleanup(paths); aegisub.cancel() end
    if not ok then
        PyBridge.cleanup(paths)
        cancel_with(log and trim(log) ~= "" and log or "PNG sequence conversion failed. Use Backend/Check or Backend/Install or Update.")
    end
    local frames, parse_error = read_sequence(paths.sequence, #frame_jobs)
    if parse_error == CANCELLED then PyBridge.cleanup(paths); aegisub.cancel() end
    if not frames then
        PyBridge.cleanup(paths)
        cancel_with(parse_error or "PNG sequence conversion produced no ASS drawings.")
    end
    local result = decode_json_file(paths.result)
    local total_lines, total_chars = 0, 0
    for _, ass_lines in pairs(frames) do
        total_lines = total_lines + #ass_lines
        for _, value in ipairs(ass_lines) do total_chars = total_chars + #value end
    end
    if not confirm_insertion(result, total_lines, total_chars) then
        PyBridge.cleanup(paths)
        aegisub.cancel()
    end
    local inserted, new_sel, insert_error = pcall(insert_sequence_shapes, subs, frame_jobs, frames)
    if not inserted and tostring(new_sel) == CANCELLED then PyBridge.cleanup(paths); aegisub.cancel() end
    if not inserted or not new_sel then
        PyBridge.cleanup(paths)
        cancel_with(insert_error or ("Could not insert converted sequence atomically: " .. tostring(new_sel or "unknown error")))
    end
    local settings_ok, settings_error = persist_options(options, cfg)
    PyBridge.cleanup(paths)
    if not settings_ok then show_message("Conversion completed, but settings could not be saved:\n" .. tostring(settings_error or "unknown error")) end
    return new_sel
end

function PNG2ASS.can_run(subs, sel)
    local records = selected_dialogue_records(subs, sel)
    return records ~= nil
end

if aegisub and aegisub.register_macro then
    local entries = {
        { script_name, script_description, PNG2ASS.main, PNG2ASS.can_run },
        { "Backend/Check", "Check installation, dependencies and available updates", check_package_main },
        { "Backend/Install or Update", "Install or update kite-png2ass from the configured repository", install_package_main },
        { "Backend/Configure", "Configure Python and package source", configure_package_main },
    }
    if depctrl and depctrl.registerMacro and depctrl.registerMacros then
        depctrl:registerMacros(entries)
    else
        for _, entry in ipairs(entries) do
            aegisub.register_macro(script_name .. "/" .. entry[1], entry[2], entry[3], entry[4])
        end
    end
end

return PNG2ASS
