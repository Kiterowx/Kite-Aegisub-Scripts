local DependencyControl = require("l0.DependencyControl")
local depctrl = DependencyControl({name="kite.Automatons", moduleName="kite.Automatons", version="1.2.0",
    author="Kiterow", description="Fansub Automatons runtime and Hephaestus services",
    feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    {{"kite.UI",version="2.0.2",feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}, {"kite.PyBridge",version="2.0.1",feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}, {"l0.dkjson",version="0.7.0",feed="https://raw.githubusercontent.com/TypesettingTools/DependencyControl/publish/DependencyControl.json"}}})
local UI, Bridge, Json = depctrl:requireModules()
local M = {root="Hephaestus Fansubber", catalog={
    {id="autoblur",name="Auto Blur",lua={"Core","UI","AssContext"}},
    {id="automotion",name="Auto Motion",module="fansub_automatons.motion",lua={"MotionEngine","UI","AssContext","ShapeOptimizer"}},
    {id="automask",name="Auto Mask",module="fansub_automatons.mask",tools={"ffmpeg"},lua={"UI","Core","ShapeOptimizer"}},
    {id="png2ass",name="Auto Drawing",module="fansub_automatons.drawing",lua={"UI","Core","ShapeOptimizer"}},
    {id="chrono_audio",name="Auto Timing",module="fansub_automatons.audio",tools={"ffmpeg","ffprobe","scxvid"},lua={"Timing"}},
}}

local function entry(id)
    for _, item in ipairs(M.catalog) do if item.id == id then return item end end
    error("Unknown automaton: " .. tostring(id), 0)
end

local function configPath()
    return Bridge.joinPath(assert(Bridge.decodedPath("?user")), "config/kite.Automatons.json")
end

local function readJson(path)
    local value = Bridge.readFile(path)
    if not value then return nil end
    local ok, data = pcall(Json.decode, value, 1, nil)
    return ok and type(data)=="table" and data or nil
end

function M.config()
    local config = readJson(configPath()) or readJson(Bridge.joinPath(Bridge.decodedPath("?user"), "config/kite.Olympus.json"))
    if config and config.version == 1 then
        local installed = readJson(Bridge.joinPath(config.home or "", "olympus.json"))
        if installed and installed.python and Bridge.fileExists(installed.python) then
            config.python = installed.python
            config.source = installed.source or config.source
            return config
        end
        if config.python and Bridge.fileExists(config.python) then return config end
    end
    local root = os.getenv("FANSUB_AUTOMATONS_HOME") or os.getenv("KITE_OLYMPUS_HOME")
    root = root or Bridge.joinPath(os.getenv("LOCALAPPDATA") or Bridge.decodedPath("?user"), "Kiterow/Fansub Automatons")
    local installed = readJson(Bridge.joinPath(root, "olympus.json")) or {}
    return {version=1,home=root,python=installed.python or Bridge.joinPath(root,"runtime/Scripts/python.exe"),source=installed.source or "",device=installed.device or "auto"}
end

function M.python() return M.config().python or "" end

function M.scriptPresent()
    return Bridge.fileExists(Bridge.joinPath(Bridge.decodedPath("?user"),"automation/autoload/kite.Hephaestus.lua"))
end

function M.notice(message)
    aegisub.dialog.display({{class="textbox",text=tostring(message or ""),x=0,y=0,width=70,height=18}}, {"Close"})
end

function M.missing(id, detail)
    return entry(id).name .. " is not ready.\n" .. tostring(detail or "The backend is not installed.")
        .. "\n\nOpen " .. M.root .. "/Install/" .. entry(id).name .. "."
end

function M.tool(name)
    local allowed = {ffmpeg=true,ffprobe=true,scxvid=true}
    name = tostring(name):lower()
    if not allowed[name] then return nil,"Unknown media tool." end
    local config = M.config()
    local manifest = readJson(Bridge.joinPath(config.home, "olympus.json")) or {}
    local candidate = (manifest.tools or {})[name] or Bridge.joinPath(config.home,"tools/bin/" .. name .. ".exe")
    if Bridge.fileExists(candidate) then return candidate end
    return nil, name .. " is missing. Open " .. M.root .. "/Install/Media tools."
end

function M.arguments(id, arguments)
    local item = entry(id)
    assert(item.module, "This automaton has no Python backend.")
    local values = {"-B","-X","utf8","-m",item.module}
    for _, value in ipairs(arguments or {}) do values[#values+1] = value end
    return values
end

function M.command(id, arguments)
    local python = M.python()
    if python=="" or not Bridge.fileExists(python) then return nil,M.missing(id) end
    return Bridge.commandLine(python,M.arguments(id,arguments))
end

function M.ready(id, capability)
    local item, config = entry(id), M.config()
    if not item.module then return true end
    if capability=="ffmpeg" then
        local path, message = M.tool("ffmpeg")
        return path~=nil,message
    end
    if not Bridge.fileExists(config.python or "") then return false,M.missing(id) end
    local ok, output = Bridge.runProcess({executable=config.python,args={"-B","-X","utf8","-m","fansub_automatons","preflight",id,capability or "default"}})
    local decoded, state = pcall(Json.decode, output or "", 1, nil)
    if not ok or not decoded or type(state)~="table" or not state.ready then
        return false,M.missing(id,type(state)=="table" and state.error or output)
    end
    return true
end

function M.guard(id, process, capability)
    return function(subs, selection, active)
        local ready, message = M.ready(id,capability)
        if not ready then M.notice(message); return selection,active end
        return process(subs,selection,active)
    end
end

function M.register(id, entries, owner, record)
    local item, aliases = entry(id), {}
    for _, action in ipairs(entries) do
        local suffix = action[1]
        if suffix==item.name or suffix=="AutoMask" or suffix=="PNG2ASS" then suffix="Open" end
        local path = M.root .. "/Automatons/" .. item.name .. (suffix~="" and "/" .. suffix or "")
        local process = action.backend == false and action[3] or M.guard(id,action[3],action.capability)
        aegisub.register_macro(path,action[2],process,action[4])
        aliases[path] = path
        for _, old in ipairs(action.oldPaths or {}) do aliases[old]=path end
    end
    if next(aliases) then UI.actions.rename(owner,aliases,"kite.Hephaestus") end
end

function M.check(id)
    local config, lines, details = M.config(), {"Fansub Automatons — Hephaestus Fansubber"}, {}
    details[#details+1] = "Python: " .. tostring(config.python)
    lines[#lines+1] = "Environment: " .. tostring(config.home)
    local targets = id and {entry(id)} or M.catalog
    for _, item in ipairs(targets) do
        lines[#lines+1] = "\n" .. item.name .. ": Lua/MoonScript " .. (M.scriptPresent(item) and "present" or "missing")
        local include = Bridge.joinPath(Bridge.decodedPath("?user"),"automation/include")
        local required = {"kite/Automatons.lua","kite/PyBridge.lua"}
        for _, name in ipairs(item.lua or {}) do required[#required+1]="kite/" .. name .. ".lua" end
        local vendor = readJson(Bridge.joinPath(config.source or "","vendor/lua.json"))
        if vendor then
            for _, name in ipairs((vendor.groups or {})[item.id] or {}) do required[#required+1]=name end
        end
        local missing = 0
        for _, name in ipairs(required) do
            local path = Bridge.joinPath(include,name)
            local alternate = path:gsub("%.moon$",".lua")
            if not Bridge.fileExists(path) and not Bridge.fileExists(alternate) then
                missing=missing+1; lines[#lines+1]="Missing Lua dependency: " .. name
            end
        end
        if missing>0 then lines[#lines+1]="Open " .. M.root .. "/Install/" .. item.name .. " to restore missing modules."
        else lines[#lines+1]="Lua dependency files: present." end
        if item.module then
            if Bridge.fileExists(config.python or "") then
                local ok, detail = Bridge.runProcess({executable=config.python,args=M.arguments(item.id,{"--status"})})
                local decoded, status = pcall(Json.decode,detail or "",1,nil)
                if ok and decoded and type(status)=="table" then
                    lines[#lines+1] = "Backend: " .. (status.ready and "ready" or "needs repair")
                        .. " | Version: " .. tostring(status.installed_version or "unknown")
                        .. " | Device: " .. tostring(status.active_device or status.device or "auto")
                    if not status.ready then lines[#lines+1]="Open Details for the backend diagnostic." end
                    if status.models_ready==false then lines[#lines+1]="Missing or invalid models: open Hephaestus Fansubber/Install/Auto Mask models." end
                    details[#details+1] = "\n" .. item.name .. "\n" .. Json.encode(status,{indent=true})
                else lines[#lines+1] = "Backend check failed: " .. tostring(detail) end
            else lines[#lines+1] = M.missing(item.id) end
        else lines[#lines+1] = "No Python backend required." end
        for _, tool in ipairs(item.tools or {}) do
            local path, message = M.tool(tool)
            lines[#lines+1] = tool .. ": " .. (path and "present" or message)
            if path then details[#details+1] = tool .. ": " .. path end
        end
    end
    lines[#lines+1] = "\nLua file checks do not confirm script loading. Reload Automation after installation."
    local button = aegisub.dialog.display({{class="textbox",text=table.concat(lines,"\n"),x=0,y=0,width=70,height=22}}, {"Details","Close"}, {close="Close"})
    if button=="Details" then M.notice(table.concat(details,"\n")) end
end

function M.configure()
    local config = M.config()
    local settings = readJson(Bridge.joinPath(config.home,"olympus.json")) or {}
    local button, values = aegisub.dialog.display({
        {class="label",label="Fansub Automatons release folder",x=0,y=0,width=5,height=1},
        {class="edit",name="source",value=config.source or "",x=5,y=0,width=10,height=1},
        {class="label",label="Installation folder",x=0,y=1,width=5,height=1},
        {class="edit",name="home",value=config.home or "",x=5,y=1,width=10,height=1},
        {class="label",label="Compute device",x=0,y=2,width=5,height=1},
        {class="dropdown",name="device",items={"auto","cpu","cuda"},value=settings.device or "auto",x=5,y=2,width=4,height=1},
    }, {"Save","Cancel"}, {ok="Save",close="Cancel"})
    if button~="Save" then return end
    if values.source ~= "" and not Bridge.fileExists(Bridge.joinPath(values.source,"install.py")) then M.notice("Select the extracted release folder containing install.py."); return end
    config.source, config.home, config.device = values.source,values.home,values.device
    local manifest = readJson(Bridge.joinPath(config.home,"olympus.json")) or {}
    config.python = manifest.python or Bridge.joinPath(config.home,"runtime/Scripts/python.exe")
    if Bridge.fileExists(config.python) then
        local ok, message = Bridge.runProcess({executable=config.python,args={"-B","-m","fansub_automatons","configure","--device",values.device}})
        if not ok then M.notice(message); return end
    end
    local ok, message = Bridge.writeFile(configPath(),Json.encode(config,{indent=true}))
    M.notice(ok and "Shared configuration saved." or message)
end

local function acquireRelease(config)
    local paths, message = Bridge.tempPaths("hephaestus_download", {script=".ps1"})
    if not paths then return nil, message end
    local script = [====[
param([Parameter(Mandatory=$true)][string]$InstallRoot)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$tag = 'fansub-automatons-v1.2.0'
$headers = @{'User-Agent'='Hephaestus-Fansubber';'Accept'='application/vnd.github+json'}
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/Kiterowx/Kite-Aegisub-Scripts/releases/tags/$tag" -Headers $headers
$asset = @($release.assets | Where-Object name -eq 'Fansub-Automatons-1.2.0.zip')
$checksum = @($release.assets | Where-Object name -eq 'Fansub-Automatons-1.2.0.zip.sha256')
if ($asset.Count -ne 1 -or $checksum.Count -ne 1 -or $asset[0].size -le 0 -or $asset[0].size -gt 512MB) { throw 'The published backend package is missing or invalid.' }
$root = [IO.Path]::GetFullPath($InstallRoot)
$destination = [IO.Path]::GetFullPath((Join-Path $root ('releases\'+$tag)))
if (-not $destination.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid installation path.' }
[IO.Directory]::CreateDirectory($root) | Out-Null
$drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($root))
if ($drive.AvailableFreeSpace -lt (2GB + 3*$asset[0].size)) { throw 'Not enough free space for the backend and the 2 GiB reserve.' }
$checksumContent = (Invoke-WebRequest -UseBasicParsing -Uri $checksum[0].browser_download_url -Headers $headers).Content
if ($checksumContent -is [byte[]]) { $checksumContent = [Text.Encoding]::UTF8.GetString($checksumContent) }
$expected = ($checksumContent.Trim() -split '\s+')[0]
if ($expected -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid backend checksum.' }
$marker = Join-Path $destination 'release.sha256'
if ((Test-Path -LiteralPath $marker) -and ((Get-Content -LiteralPath $marker -Raw).Trim() -eq $expected) -and (Test-Path -LiteralPath (Join-Path $destination 'Install.cmd'))) { Write-Output $destination; exit 0 }
if (Test-Path -LiteralPath $destination) { throw 'An incomplete backend folder already exists. Review it in Hephaestus configuration before retrying.' }
$archive = Join-Path $root ('download-'+[guid]::NewGuid().ToString('N')+'.zip')
$pending = $destination+'.'+[guid]::NewGuid().ToString('N')+'.pending'
try {
    Invoke-WebRequest -UseBasicParsing -Uri $asset[0].browser_download_url -Headers $headers -OutFile $archive
    if ((Get-Item -LiteralPath $archive).Length -ne $asset[0].size) { throw 'Incomplete backend download.' }
    $hasher = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($archive)
    try { $actual = ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-','') } finally { $stream.Dispose(); $hasher.Dispose() }
    if ($actual -ne $expected) { throw 'Backend checksum mismatch.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        $total = 0L
        foreach ($entry in $zip.Entries) {
            $target = [IO.Path]::GetFullPath((Join-Path $pending $entry.FullName))
            if (-not $target.StartsWith($pending+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe backend archive path.' }
            $total += $entry.Length
        }
        if ($total -gt 768MB -or $drive.AvailableFreeSpace -lt (2GB+$total)) { throw 'Not enough free space to extract the backend.' }
        [IO.Directory]::CreateDirectory($pending) | Out-Null
        foreach ($entry in $zip.Entries) {
            if (-not $entry.Name) { continue }
            $target = [IO.Path]::GetFullPath((Join-Path $pending $entry.FullName))
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$false)
        }
    } finally { $zip.Dispose() }
    if (-not (Test-Path -LiteralPath (Join-Path $pending 'Install.cmd')) -or -not (Test-Path -LiteralPath (Join-Path $pending 'install.py'))) { throw 'The backend archive has no installer.' }
    [IO.File]::WriteAllText((Join-Path $pending 'release.sha256'),$expected)
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
    [IO.Directory]::Move($pending,$destination)
    Write-Output $destination
} finally {
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
    if (Test-Path -LiteralPath $pending) {
        $resolved = (Resolve-Path -LiteralPath $pending).Path
        if (-not $resolved.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase) -or -not $resolved.EndsWith('.pending')) { throw 'Unsafe cleanup path.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

]====]
    local written, detail = Bridge.writeFile(paths.script, script)
    if not written then return nil, detail end
    local called, ok, output = pcall(Bridge.runProcess, {executable="powershell.exe", args={"-NoProfile","-NonInteractive","-File",paths.script,"-InstallRoot",config.home}})
    Bridge.cleanup(paths)
    if not called then return nil, ok end
    if not ok then return nil, output end
    local source = tostring(output or ""):match("([^\r\n]+)%s*$")
    if not source or not Bridge.fileExists(Bridge.joinPath(source,"Install.cmd")) then return nil, "The backend download did not return a valid installer." end
    config.source = source
    local saved, failure = Bridge.writeFile(configPath(),Json.encode(config,{indent=true}))
    if not saved then return nil, failure end
    return source
end

function M.install(id)
    local config = M.config()
    if not Bridge.fileExists(Bridge.joinPath(config.source or "","Install.cmd")) then
        local source, message = acquireRelease(config)
        if not source then M.notice("The shared backend could not be downloaded.\n" .. tostring(message)); return end
    end
    local args = {"--modules",id or "all","--home",config.home,"--aegisub",Bridge.decodedPath("?user"),"--compute",config.device or "auto"}
    if id=="tools" then args[2]="all"; args[#args+1]="--tools-only" end
    local bootstrapped, diagnostic = Bridge.run(Bridge.commandLine(Bridge.joinPath(config.source,"Install.cmd"),{"--bootstrap-only"}))
    if not bootstrapped then M.notice(diagnostic); return end
    local python = Bridge.joinPath(os.getenv("LOCALAPPDATA"),"Kiterow/Fansub Automatons/python-3.13.7/tools/python.exe")
    local arguments = {"-B","-X","utf8",Bridge.joinPath(config.source,"install.py")}
    for _, value in ipairs(args) do arguments[#arguments+1]=value end
    local ok, detail = Bridge.runProcess({executable=python,args=arguments})
    M.notice((ok and "Installation completed. Reload Automation scripts to refresh menus.\n" or "Installation did not complete.\n") .. tostring(detail or ""))
end

function M.installModels()
    local ok, message = M.ready("automask")
    if not ok then M.notice(message); return end
    local success, detail = Bridge.runProcess({executable=M.python(),args=M.arguments("automask",{"--install-models"})})
    M.notice((success and "Auto Mask models installed.\n" or "Model installation failed.\n") .. tostring(detail or ""))
end

M.version = depctrl
return depctrl:register(M)
