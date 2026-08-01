local PyBridge = { version = "1.4.2" }

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
        version = PyBridge.version,
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
    if trim(path) == "" then return false end
    local handle = io.open(path, "rb")
    if not handle then return false end
    handle:close()
    return true
end

local function directoryExists(path)
    if trim(path) == "" then return false end
    if lfs then
        local attributes = lfs.attributes(path)
        return attributes and attributes.mode == "directory" or false
    end
    local ok, _, code = os.rename(path, path)
    if ok or code == 13 then
        local probe = io.open(path, "rb")
        if probe then probe:close(); return true end
        return true
    end
    return false
end
local function readFile(path, limit)
    local handle, message = io.open(path, "rb")
    if not handle then return nil, message end
    local data, readMessage = handle:read(limit or "*a")
    handle:close()
    if data == nil then return nil, readMessage end
    return data
end

local function fileSize(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local size = handle:seek("end")
    handle:close()
    return size
end

local function uniqueSuffix()
    counter = counter + 1
    return string.format("%d.%d.%d", os.time(), counter, math.floor(os.clock() * 1000000) % 1000000)
end

local function removeFile(path)
    if trim(path) == "" then return true end
    if not fileExists(path) then return true end
    local ok, message = os.remove(path)
    return ok and true or false, message
end

local function ensureDir(path)
    path = trim(path)
    if path == "" then return false, "directory path is empty" end
    if directoryExists(path) then return true end
    if not lfs then return false, "lfs is required to create directories" end
    local normalized = path:gsub("[/\\]+", PyBridge.separator):gsub("[/\\]+$", "")
    local root = ""
    local remainder = normalized
    if PyBridge.isWindows then
        local drive = normalized:match("^([A-Za-z]:)[/\\]?")
        local uncServer, uncShare = normalized:match("^\\\\([^\\]+)\\([^\\]+)")
        if drive then
            root = drive .. PyBridge.separator
            remainder = normalized:sub(#drive + 1):gsub("^[/\\]+", "")
        elseif uncServer and uncShare then
            root = "\\\\" .. uncServer .. "\\" .. uncShare
            remainder = normalized:sub(#root + 1):gsub("^[/\\]+", "")
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
    return directoryExists(path) or directoryExists(normalized), directoryExists(path) and nil or "directory was not created"
end

local function replaceFile(source, target)
    if trim(source) == "" or trim(target) == "" then return false, "source and target are required" end
    local backup = target .. ".backup." .. uniqueSuffix()
    local hadTarget = fileExists(target)
    if hadTarget then
        local ok, message = os.rename(target, backup)
        if not ok then return false, message end
    end
    local ok, message = os.rename(source, target)
    if not ok then
        if hadTarget then pcall(os.rename, backup, target) end
        return false, message
    end
    if hadTarget then removeFile(backup) end
    return true
end

local writableDirectory

local function withAtomicFile(path, callback)
    if trim(path) == "" then return false, "target path is empty" end
    if type(callback) ~= "function" then return false, "writer callback is required" end
    local parent = parentPath(path)
    if parent and parent ~= "" then
        local ok, message = writableDirectory(parent)
        if not ok then return false, message end
    end
    local temporary = path .. ".temporary." .. uniqueSuffix()
    local handle, message = io.open(temporary, "wb")
    if not handle then return false, message end
    local packed = { pcall(callback, handle, temporary) }
    local flushOk, flushMessage = pcall(handle.flush, handle)
    local closeOk, closeMessage = pcall(handle.close, handle)
    if not packed[1] then
        removeFile(temporary)
        return false, packed[2]
    end
    if packed[2] == false then
        removeFile(temporary)
        return false, packed[3]
    end
    if not flushOk or not closeOk then
        removeFile(temporary)
        return false, flushMessage or closeMessage
    end
    local replaced, replaceMessage = replaceFile(temporary, path)
    if not replaced then removeFile(temporary) end
    if not replaced then return false, replaceMessage end
    return true, packed[2], packed[3], packed[4]
end

local function writeFile(path, data)
    local parent = parentPath(path)
    if parent and parent ~= "" then
        local ok, message = writableDirectory(parent)
        if not ok then return false, message end
    end
    local temporary = path .. ".temporary." .. uniqueSuffix()
    local handle, message = io.open(temporary, "wb")
    if not handle then return false, message end
    local ok, writeMessage = handle:write(data or "")
    if ok then handle:flush() end
    local closeOk, closeMessage = handle:close()
    if not ok or closeOk == false then
        removeFile(temporary)
        return false, writeMessage or closeMessage
    end
    local replaced, replaceMessage = replaceFile(temporary, path)
    if not replaced then removeFile(temporary) end
    return replaced, replaceMessage
end

local function quote(value)
    value = tostring(value or "")
    if PyBridge.isWindows then return "'" .. value:gsub("'", "''") .. "'" end
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function program(value, fallback)
    value = trim(value)
    if value == "" then value = tostring(fallback or "python") end
    if value:find("[/\\]") or value:find("%s") then return quote(value) end
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
    else
        for _, value in ipairs(arguments or {}) do parts[#parts + 1] = argument(value) end
    end
    return table.concat(parts, " ")
end

local function run(commandText, quiet)
    if not PyBridge.available then return false, "aka.command is required to run commands", nil end
    local ok, output, status, reason, exitCode = pcall(command.run_cmd_c, tostring(commandText or ""), quiet ~= false)
    if not ok then return false, tostring(output), nil end
    if status == true then return true, tostring(output or ""), tonumber(exitCode) or 0 end
    local ending = reason == "exit" and ("exit code " .. tostring(exitCode)) or (tostring(reason or "failure") .. " " .. tostring(exitCode or ""))
    return false, ending .. (output and output ~= "" and ("\n" .. tostring(output)) or ""), tonumber(exitCode)
end

local function chain(...)
    local parts = {}
    for _, value in ipairs({...}) do
        if trim(value) ~= "" then parts[#parts + 1] = tostring(value) end
    end
    return table.concat(parts, "\n")
end

writableDirectory = function(path)
    path = trim(path)
    if path == "" then return nil, "directory path is empty" end

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
    addCandidate(os.getenv("TEMP"))
    addCandidate(os.getenv("TMP"))
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
    for key, suffix in pairs(names or {}) do paths[key] = joinPath(root, stem .. tostring(suffix or "")) end
    return paths
end

local function cleanup(paths)
    local failures = {}
    for _, path in pairs(paths or {}) do
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

if depctrl then return depctrl:register(PyBridge) end
return PyBridge
