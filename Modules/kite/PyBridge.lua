local MODULE_VERSION = "1.4.4"
local PyBridge = { VERSION = MODULE_VERSION, version = MODULE_VERSION }
local unpack = table.unpack or unpack

local function safeRequire(name)
    local ok, value = pcall(require, name)
    if ok then return value end
    return nil
end

local DependencyControl = safeRequire("l0.DependencyControl")
local command = safeRequire("aka.command")
local lfs = safeRequire("lfs")
local depctrl
if DependencyControl then
    depctrl = DependencyControl({
        name = "kite.PyBridge",
        version = MODULE_VERSION,
        description = "Shared process and filesystem bridge for Kite backends",
        author = "Kiterow",
        url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
        moduleName = "kite.PyBridge",
        feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
        {
            {"aka.command", version = "1.0.2"},
        },
    })
end

PyBridge.isWindows = package.config:sub(1, 1) == "\\"
PyBridge.separator = PyBridge.isWindows and "\\" or "/"
PyBridge.available = command ~= nil and type(command.run_cmd_c) == "function"

local counter = 0
local CLOCK_SUBSECOND_SCALE = 1000000

local function pack(...)
    return { n = select("#", ...), ... }
end

local function trim(value)
    return (tostring(value == nil and "" or value):match("^%s*(.-)%s*$")) or ""
end

local function decodedPath(specification)
    if not aegisub or type(aegisub.decode_path) ~= "function" then return nil end
    local ok, value = pcall(aegisub.decode_path, specification)
    if not ok or type(value) ~= "string" or value == "" or value == specification then return nil end
    return value
end

local function joinPath(left, right)
    left = tostring(left or "")
    right = tostring(right or "")
    if left == "" then return right end
    if right == "" then return left end
    if left:sub(-1) == "/" or left:sub(-1) == "\\" then return left .. right end
    return left .. PyBridge.separator .. right
end

local function parentPath(path)
    path = tostring(path or ""):gsub("[/\\]+$", "")
    return path:match("^(.*)[/\\][^/\\]+$")
end

local function fileExists(path)
    if type(path) ~= "string" or trim(path) == "" then return false end
    if lfs then
        local attributes = lfs.attributes(path)
        if attributes then return attributes.mode == "file" end
    end
    local handle = io.open(path, "rb")
    if not handle then return false end
    local readOk, _, readMessage = pcall(handle.read, handle, 1)
    pcall(handle.close, handle)
    return readOk and readMessage == nil
end

local function directoryExists(path)
    if type(path) ~= "string" or trim(path) == "" then return false end
    if lfs then
        local attributes = lfs.attributes(path)
        return attributes and attributes.mode == "directory" or false
    end
    local ok, _, code = os.rename(path, path)
    if not ok and code ~= 13 then return false end
    local probe = io.open(path, "rb")
    if not probe then return true end
    local readable, _, readMessage = pcall(probe.read, probe, 1)
    pcall(probe.close, probe)
    return not readable or readMessage ~= nil
end
local function readFile(path, limit)
    if type(path) ~= "string" or trim(path) == "" then return nil, "file path is empty" end
    local handle, message = io.open(path, "rb")
    if not handle then return nil, message end
    local called, data, readMessage = pcall(handle.read, handle, limit or "*a")
    pcall(handle.close, handle)
    if not called then return nil, data end
    if data == nil then return nil, readMessage end
    return data
end

local function fileSize(path)
    if type(path) ~= "string" or trim(path) == "" then return nil end
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local called, size = pcall(handle.seek, handle, "end")
    pcall(handle.close, handle)
    return called and size or nil
end

local function uniqueSuffix()
    counter = counter + 1
    return string.format("%d.%d.%d", os.time(), counter,
        math.floor(os.clock() * CLOCK_SUBSECOND_SCALE) % CLOCK_SUBSECOND_SCALE)
end

local function removeFile(path)
    if path == nil or path == "" then return true end
    if type(path) ~= "string" then return false, "file path must be a string" end
    if not fileExists(path) then return true end
    local ok, message = os.remove(path)
    return ok and true or false, message
end

local function ensureDir(path)
    if type(path) ~= "string" then return false, "directory path must be a string" end
    if trim(path) == "" then return false, "directory path is empty" end
    if directoryExists(path) then return true end
    if not lfs then return false, "lfs is required to create directories" end
    local wasUnc = PyBridge.isWindows and path:match("^[/\\][/\\]") ~= nil
    local normalized = path:gsub("[/\\]+", PyBridge.separator)
    local isWindowsRoot = PyBridge.isWindows and normalized:match("^[A-Za-z]:\\$") ~= nil
    if normalized ~= "/" and normalized ~= "\\" and not isWindowsRoot then
        normalized = normalized:gsub("[/\\]+$", "")
    end
    if wasUnc and normalized:sub(1, 2) ~= "\\\\" then normalized = "\\" .. normalized end
    local root = ""
    local remainder = normalized
    if PyBridge.isWindows then
        local drive = normalized:match("^([A-Za-z]:)\\")
        if normalized:match("^[A-Za-z]:[^\\]") then
            return false, "drive-relative paths are not supported"
        elseif normalized:sub(1, 2) == "\\\\" then
            local tail = normalized:sub(3)
            local first = tail:find("\\", 1, true)
            local second = first and tail:find("\\", first + 1, true) or nil
            local server = first and tail:sub(1, first - 1) or nil
            local share = first and (second and tail:sub(first + 1, second - 1) or tail:sub(first + 1)) or nil
            if not server or server == "" or not share or share == "" then
                return false, "UNC paths require a server and share"
            end
            root = "\\\\" .. server .. "\\" .. share
            remainder = second and tail:sub(second + 1) or ""
        elseif drive then
            root = drive .. PyBridge.separator
            remainder = normalized:sub(#drive + 1):gsub("^[/\\]+", "")
        elseif normalized:sub(1, 1) == "\\" then
            root = "\\"
            remainder = normalized:sub(2)
        end
    elseif normalized:sub(1, 1) == "/" then
        root = "/"
        remainder = normalized:sub(2)
    end
    local current = root
    for part in remainder:gmatch("[^/\\]+") do
        if part ~= "." and part ~= "" then
            if part == ".." then return false, "parent traversal is not allowed" end
            current = current == "" and part or joinPath(current, part)
            if not directoryExists(current) then
                local ok, message = lfs.mkdir(current)
                if not ok and not directoryExists(current) then return false, message end
            end
        end
    end
    if directoryExists(path) or directoryExists(normalized) then return true end
    return false, "directory was not created"
end

local function replaceFile(source, target)
    if type(source) ~= "string" or type(target) ~= "string" or trim(source) == "" or trim(target) == "" then
        return false, "source and target are required"
    end
    local backup = target .. ".backup." .. uniqueSuffix()
    local hadTarget = fileExists(target)
    if hadTarget then
        local ok, message = os.rename(target, backup)
        if not ok then return false, message end
    end
    local ok, message = os.rename(source, target)
    if not ok then
        if hadTarget then
            local restored, restoreMessage = os.rename(backup, target)
            if not restored then
                return false, tostring(message or "replacement failed") .. "; backup retained at " .. backup
                    .. ": " .. tostring(restoreMessage or "restore failed")
            end
        end
        return false, message
    end
    if hadTarget then removeFile(backup) end
    return true
end

local writableDirectory

local function flushAndClose(handle, flush)
    local flushOk, flushResult, flushMessage = true, true, nil
    if flush then
        flushOk, flushResult, flushMessage = pcall(handle.flush, handle)
        flushOk = flushOk and flushResult ~= nil and flushResult ~= false
    end
    local closeOk, closeResult, closeMessage = pcall(handle.close, handle)
    closeOk = closeOk and closeResult ~= nil and closeResult ~= false
    if not flushOk or not closeOk then
        return false, flushMessage or closeMessage or flushResult or closeResult or "file finalization failed"
    end
    return true
end

local function withAtomicFile(path, callback)
    if type(path) ~= "string" or trim(path) == "" then return false, "target path is empty" end
    if type(callback) ~= "function" then return false, "writer callback is required" end
    local parent = parentPath(path)
    if parent and parent ~= "" then
        local ok, message = writableDirectory(parent)
        if not ok then return false, message end
    end
    local temporary = path .. ".temporary." .. uniqueSuffix()
    local handle, message = io.open(temporary, "wb")
    if not handle then return false, message end
    local packed = pack(pcall(callback, handle, temporary))
    local finalized, finalMessage = flushAndClose(handle, true)
    if not packed[1] then
        removeFile(temporary)
        return false, packed[2]
    end
    if packed[2] == false then
        removeFile(temporary)
        return false, packed[3]
    end
    if not finalized then
        removeFile(temporary)
        return false, finalMessage
    end
    local replaced, replaceMessage = replaceFile(temporary, path)
    if not replaced then removeFile(temporary) end
    if not replaced then return false, replaceMessage end
    return true, unpack(packed, 2, packed.n)
end

local function writeFile(path, data)
    if type(path) ~= "string" or trim(path) == "" then return false, "target path is empty" end
    local parent = parentPath(path)
    if parent and parent ~= "" then
        local ok, message = writableDirectory(parent)
        if not ok then return false, message end
    end
    local temporary = path .. ".temporary." .. uniqueSuffix()
    local handle, message = io.open(temporary, "wb")
    if not handle then return false, message end
    local called, ok, writeMessage = pcall(handle.write, handle, data or "")
    local finalized, finalMessage = flushAndClose(handle, called and ok ~= nil and ok ~= false)
    if not called or ok == nil or ok == false or not finalized then
        removeFile(temporary)
        return false, (not called and ok) or writeMessage or finalMessage
    end
    local replaced, replaceMessage = replaceFile(temporary, path)
    if not replaced then removeFile(temporary) end
    return replaced, replaceMessage
end

local function quote(value)
    value = tostring(value or "")
    if command and type(command.p) == "function" then
        local ok, quoted = pcall(command.p, value)
        if ok and type(quoted) == "string" and quoted ~= "" then return quoted end
    end
    if PyBridge.isWindows then
        return '"' .. value:gsub("%%", "%%%%"):gsub('"', '\\"') .. '"'
    end
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function program(value, fallback)
    value = trim(value)
    if value == "" then value = tostring(fallback or "python") end
    if not value:match("^[%w_.+%-]+$") then return quote(value) end
    return value
end

local function raw(value)
    return { __kite_raw = true, value = tostring(value or "") }
end

local function argument(value)
    if type(value) == "table" and value.__kite_raw then return tostring(value.value or "") end
    return quote(value)
end

local function commandLine(executable, arguments)
    local parts = {program(executable)}
    if type(arguments) == "string" then
        if trim(arguments) ~= "" then parts[#parts + 1] = arguments end
    elseif type(arguments) == "table" then
        for _, value in ipairs(arguments) do parts[#parts + 1] = argument(value) end
    elseif arguments ~= nil then
        parts[#parts + 1] = argument(arguments)
    end
    return table.concat(parts, " ")
end

local function run(commandText, quiet)
    if not PyBridge.available then return false, "aka.command is required to run commands", nil end
    commandText = tostring(commandText or "")
    if trim(commandText) == "" then return false, "command is empty", nil end
    local ok, output, status, reason, exitCode = pcall(command.run_cmd_c, commandText, quiet ~= false)
    if not ok then return false, tostring(output), nil end
    if status == true then return true, tostring(output or ""), tonumber(exitCode) or 0 end
    local ending = reason == "exit" and ("exit code " .. tostring(exitCode)) or (tostring(reason or "failure") .. " " .. tostring(exitCode or ""))
    return false, ending .. (output and output ~= "" and ("\n" .. tostring(output)) or ""), tonumber(exitCode)
end

local function chain(...)
    local parts = {}
    local values = pack(...)
    for index = 1, values.n do
        local value = values[index]
        if trim(value) ~= "" then parts[#parts + 1] = tostring(value) end
    end
    return table.concat(parts, "\n")
end

writableDirectory = function(path)
    if type(path) ~= "string" or trim(path) == "" then return nil, "directory path is empty" end

    local function probe()
        local probePath = joinPath(path, ".kite-temp-probe-" .. uniqueSuffix())
        local handle, openMessage = io.open(probePath, "wb")
        if not handle then return nil, openMessage end
        local wrote, writeMessage = handle:write("")
        local closed, closeMessage = handle:close()
        if not wrote or closed == false then
            removeFile(probePath)
            return nil, writeMessage or closeMessage
        end
        local removed, removeMessage = os.remove(probePath)
        if not removed then return nil, removeMessage end
        return path
    end

    local usable, message = probe()
    if usable then return usable end
    local created, createMessage = ensureDir(path)
    if not created then return nil, createMessage or message end
    usable, message = probe()
    if usable then return usable end
    return nil, message or "directory is not writable"
end

local function tempRoot()
    local candidates = {}
    local seen = {}
    local function addCandidate(path)
        path = trim(path)
        if path ~= "" and not seen[path] then
            seen[path] = true
            candidates[#candidates + 1] = path
        end
    end

    addCandidate(decodedPath("?temp"))
    if not PyBridge.isWindows then addCandidate(os.getenv("TMPDIR")) end
    addCandidate(os.getenv("TEMP"))
    addCandidate(os.getenv("TMP"))
    if not PyBridge.isWindows then addCandidate("/tmp") end
    local user = decodedPath("?user")
    if user then
        addCandidate(joinPath(user, "temp"))
        addCandidate(user)
    end

    local failures = {}
    for _, candidate in ipairs(candidates) do
        local root, message = writableDirectory(candidate)
        if root then return root end
        failures[#failures + 1] = candidate .. ": " .. tostring(message or "unavailable")
    end
    return nil, #failures > 0 and table.concat(failures, "\n") or "no temporary directory candidates were resolved"
end

local function tempPaths(prefix, names)
    local root, message = tempRoot()
    if not root then return nil, message or "temporary directory is unavailable" end
    local stem = string.format("%s_%s", tostring(prefix or "kite"):gsub("[^%w_.-]", "_"), uniqueSuffix())
    local paths = {}
    for key, suffix in pairs(type(names) == "table" and names or {}) do
        paths[key] = joinPath(root, stem .. tostring(suffix or ""))
    end
    return paths
end

local function cleanup(paths)
    local failures = {}
    for _, path in pairs(type(paths) == "table" and paths or {}) do
        local ok, message = removeFile(path)
        if not ok then failures[#failures + 1] = tostring(message or path) end
    end
    return #failures == 0, table.concat(failures, "\n")
end

local function resolvePython(configured, virtualEnvironment)
    configured = trim(configured)
    if configured ~= "" then return configured end
    if trim(virtualEnvironment) ~= "" then
        local candidate = joinPath(virtualEnvironment, PyBridge.isWindows and "Scripts\\python.exe" or "bin/python")
        if fileExists(candidate) then return candidate end
    end
    return PyBridge.isWindows and "python" or "python3"
end

local function installCommand(python, source)
    if trim(source) == "" then return nil, "package source is required" end
    local executable = program(python, PyBridge.isWindows and "python" or "python3")
    return chain(
        executable .. " -m ensurepip",
        executable .. " -m pip install --upgrade pip setuptools wheel",
        executable .. " -m pip install --upgrade " .. quote(source)
    )
end

local function validModuleName(name)
    name = tostring(name or "")
    return name:match("^[A-Za-z_][A-Za-z0-9_%.]*$") ~= nil and not name:find("..", 1, true) and name:sub(-1) ~= "."
end

local function moduleCommand(python, moduleName, arguments)
    if not validModuleName(moduleName) then return nil, "invalid Python module name" end
    local executable = program(python, PyBridge.isWindows and "python" or "python3")
    if type(arguments) == "table" then
        local parts = {executable, "-m", moduleName}
        for _, value in ipairs(arguments) do parts[#parts + 1] = argument(value) end
        return table.concat(parts, " ")
    end
    return executable .. " -m " .. moduleName .. (trim(arguments) ~= "" and (" " .. tostring(arguments)) or "")
end

local function runModule(python, moduleName, arguments, quiet)
    local text, message = moduleCommand(python, moduleName, arguments)
    if not text then return false, message end
    return run(text, quiet)
end

local function scriptCommand(path)
    path = tostring(path or "")
    if trim(path) == "" then return nil, "script path is required" end
    local suffix = path:lower():match("(%.[^./\\]+)$") or ""
    if PyBridge.isWindows then
        if suffix == ".ps1" then return "powershell -NoProfile -ExecutionPolicy Bypass -File " .. quote(path) end
        if suffix == ".bat" or suffix == ".cmd" then return "cmd.exe /d /s /c " .. quote('"' .. path .. '"') end
        return program(path)
    end
    return "sh " .. quote(path)
end

local function runScript(path, quiet)
    local text, message = scriptCommand(path)
    if not text then return false, message end
    return run(text, quiet)
end

local function runDetachedScript(path)
    local text, message = scriptCommand(path)
    if not text then return false, message end
    if PyBridge.isWindows then
        return run("Start-Process -WindowStyle Hidden -FilePath 'powershell' -ArgumentList " .. quote("-NoProfile -Command " .. text), true)
    end
    return run(text .. " >/dev/null 2>&1 &", true)
end

PyBridge.trim = trim
PyBridge.decodedPath = decodedPath
PyBridge.joinPath = joinPath
PyBridge.parentPath = parentPath
PyBridge.fileExists = fileExists
PyBridge.directoryExists = directoryExists
PyBridge.readFile = readFile
PyBridge.fileSize = fileSize
PyBridge.writeFile = writeFile
PyBridge.withAtomicFile = withAtomicFile
PyBridge.replaceFile = replaceFile
PyBridge.removeFile = removeFile
PyBridge.ensureDir = ensureDir
PyBridge.quote = quote
PyBridge.program = program
PyBridge.raw = raw
PyBridge.commandLine = commandLine
PyBridge.run = run
PyBridge.chain = chain
PyBridge.uniqueSuffix = uniqueSuffix
PyBridge.tempRoot = tempRoot
PyBridge.tempPaths = tempPaths
PyBridge.cleanup = cleanup
PyBridge.resolvePython = resolvePython
PyBridge.installCommand = installCommand
PyBridge.validModuleName = validModuleName
PyBridge.moduleCommand = moduleCommand
PyBridge.runModule = runModule
PyBridge.scriptCommand = scriptCommand
PyBridge.runScript = runScript
PyBridge.runDetachedScript = runDetachedScript

if depctrl then
    PyBridge.version = depctrl
    return depctrl:register(PyBridge)
end
return PyBridge
