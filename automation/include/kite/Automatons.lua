local DependencyControl = require("l0.DependencyControl")
local depctrl = DependencyControl({name="kite.Automatons", moduleName="kite.Automatons", version="1.2.1",
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
        {class="label",label="Installation folder",x=0,y=0,width=5,height=1},
        {class="edit",name="home",value=config.home or "",x=5,y=0,width=10,height=1},
        {class="label",label="Compute device",x=0,y=1,width=5,height=1},
        {class="dropdown",name="device",items={"auto","cpu","cuda"},value=settings.device or config.device or "auto",x=5,y=1,width=4,height=1},
    }, {"Save","Cancel"}, {ok="Save",close="Cancel"})
    if button~="Save" then return end
    if not values.home or not values.home:match("%S") then M.notice("Choose an installation folder."); return end
    config.home, config.device = values.home,values.device
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
    local paths, message = Bridge.tempPaths("hephaestus_download", {script=".ps1",result=".path"})
    if not paths then return nil, message end
    local script = [====[
param([Parameter(Mandatory=$true)][string]$InstallRoot, [Parameter(Mandatory=$true)][string]$ResultFile)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Get-Hash($Stream) {
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hash.ComputeHash($Stream)).Replace('-', '').ToLowerInvariant() }
    finally { $hash.Dispose(); $Stream.Dispose() }
}

function Test-Package($Zip, $Folder, $Expected) {
    $marker = Join-Path $Folder 'release.sha256'
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { return $false }
    if ((Get-Content -LiteralPath $marker -Raw).Trim() -ne $Expected) { return $false }
    $entries = @($Zip.Entries | Where-Object Name)
    $files = @(Get-ChildItem -LiteralPath $Folder -Recurse -Force -File)
    if ($files.Count -ne $entries.Count + 1) { return $false }
    foreach ($entry in $entries) {
        $path = Join-Path $Folder $entry.FullName
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
        $file = Get-Item -LiteralPath $path
        if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $file.Length -ne $entry.Length) { return $false }
        if ((Get-Hash ([IO.File]::OpenRead($path))) -ne (Get-Hash ($entry.Open()))) { return $false }
    }
    return $true
}

$lock = $zip = $partial = $pending = $null
try {
    $root = [IO.Path]::GetFullPath($InstallRoot)
    if ($root.TrimEnd('\') -eq [IO.Path]::GetPathRoot($root).TrimEnd('\')) { throw 'Choose a dedicated installation folder.' }
    $root = $root.TrimEnd('\')
    [IO.Directory]::CreateDirectory($root) | Out-Null
    $lock = [IO.File]::Open((Join-Path $root 'release.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $headers = @{'User-Agent'='Hephaestus-Fansubber'; 'Accept'='application/vnd.github+json'}
    $repository = 'https://api.github.com/repos/Kiterowx/Fansub-Automatons'
    $release = Invoke-RestMethod -Uri ($repository + '/releases/latest') -Headers $headers -TimeoutSec 30
    if ($release.draft -or $release.prerelease -or $release.tag_name -notmatch '^v(\d+\.\d+\.[0-9])$') { throw 'No compatible stable backend release is available.' }
    $version = $Matches[1]
    if ([version]$version -lt [version]'1.2.1') { throw 'The backend release is too old.' }
    $installed = Join-Path $root 'olympus.json'
    if (Test-Path -LiteralPath $installed -PathType Leaf) {
        $current = Get-Content -LiteralPath $installed -Raw | ConvertFrom-Json
        if ($current.release -match '^\d+\.\d+\.\d+$' -and [version]$current.release -gt [version]$version) { throw 'A newer backend is already installed.' }
    }
    $name = 'Fansub-Automatons-' + $version + '.zip'
    $asset = @($release.assets | Where-Object name -eq $name)
    $checksum = @($release.assets | Where-Object name -eq ($name + '.sha256'))
    if ($asset.Count -ne 1 -or $checksum.Count -ne 1 -or $asset[0].size -le 0 -or $asset[0].size -gt 512MB -or $checksum[0].size -gt 4096) { throw 'The backend package or checksum is missing or invalid.' }
    $download = 'https://github.com/Kiterowx/Fansub-Automatons/releases/download/' + $release.tag_name + '/'
    if ($asset[0].browser_download_url -ne ($download + $name) -or $checksum[0].browser_download_url -ne ($download + $name + '.sha256')) { throw 'Invalid backend download URL.' }
    $content = (Invoke-WebRequest -UseBasicParsing -Uri $checksum[0].browser_download_url -Headers $headers -TimeoutSec 30).Content
    if ($content -is [byte[]]) { $content = [Text.Encoding]::UTF8.GetString($content) }
    if ($content -notmatch ('^\s*([a-fA-F0-9]{64})(?:[ \t]+\*?' + [regex]::Escape($name) + ')?\s*$')) { throw 'Invalid backend checksum.' }
    $expected = $Matches[1].ToLowerInvariant()
    $drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($root))
    if ($drive.AvailableFreeSpace -lt (2GB + 3*$asset[0].size)) { throw 'Not enough free space for the backend and the 2 GiB reserve.' }
    $cache = Join-Path $root 'downloads'
    [IO.Directory]::CreateDirectory($cache) | Out-Null
    $archive = Join-Path $cache ($expected.Substring(0,12) + '-' + $name)
    if ((Test-Path -LiteralPath $archive -PathType Leaf) -and (Get-Hash ([IO.File]::OpenRead($archive))) -ne $expected) { Remove-Item -LiteralPath $archive -Force }
    if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
        $partial = $archive + '.' + [guid]::NewGuid().ToString('N') + '.part'
        Invoke-WebRequest -UseBasicParsing -Uri $asset[0].browser_download_url -Headers $headers -TimeoutSec 120 -OutFile $partial
        if ((Get-Item -LiteralPath $partial).Length -ne $asset[0].size -or (Get-Hash ([IO.File]::OpenRead($partial))) -ne $expected) { throw 'The backend download failed integrity verification.' }
        Move-Item -LiteralPath $partial -Destination $archive
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    $destination = Join-Path (Join-Path $root 'releases') ($release.tag_name + '-' + $expected.Substring(0,12))
    $total = 0L
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $zip.Entries) {
        $target = [IO.Path]::GetFullPath((Join-Path $destination $entry.FullName))
        if ($entry.FullName -match '(^[\\/]|:|(^|[\\/])\.\.([\\/]|$))' -or -not $target.StartsWith($destination+'\',[StringComparison]::OrdinalIgnoreCase) -or (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw 'Unsafe backend archive path.' }
        if (-not $names.Add($target) -or $entry.FullName -eq 'release.sha256') { throw 'Duplicate or reserved backend archive path.' }
        $total += $entry.Length
    }
    foreach ($required in @('Install.cmd','install.py','bootstrap.ps1','assets.json','pyproject.toml','installer_tools.py','installer_deploy.py','installer_reuse.py','src/fansub_automatons/__init__.py')) {
        if (-not $names.Contains([IO.Path]::GetFullPath((Join-Path $destination $required)))) { throw 'The backend archive is incomplete.' }
    }
    if ($total -gt 768MB -or $drive.AvailableFreeSpace -lt (2GB+$total)) { throw 'Not enough free space to extract the backend.' }
    if (Test-Path -LiteralPath $destination) {
        if (Test-Package $zip $destination $expected) { [IO.File]::WriteAllText($ResultFile,$destination); exit 0 }
        $destination += '-' + [guid]::NewGuid().ToString('N').Substring(0,8)
    }
    $pending = $destination + '.' + [guid]::NewGuid().ToString('N').Substring(0,8) + '.pending'
    [IO.Directory]::CreateDirectory($pending) | Out-Null
    foreach ($entry in $zip.Entries) {
        if (-not $entry.Name) { continue }
        $target = [IO.Path]::GetFullPath((Join-Path $pending $entry.FullName))
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$false)
    }
    [IO.File]::WriteAllText((Join-Path $pending 'release.sha256'),$expected)
    [IO.Directory]::Move($pending,$destination)
    [IO.File]::WriteAllText($ResultFile,$destination)
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
} finally {
    if ($zip) { $zip.Dispose() }
    if ($partial -and (Test-Path -LiteralPath $partial)) { Remove-Item -LiteralPath $partial -Force }
    if ($pending -and (Test-Path -LiteralPath $pending)) {
        $resolved = (Resolve-Path -LiteralPath $pending).Path
        if (-not $resolved.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase) -or -not $resolved.EndsWith('.pending')) { throw 'Unsafe cleanup path.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    if ($lock) { $lock.Dispose() }
}
]====]
    local written, detail = Bridge.writeFile(paths.script, script)
    if not written then Bridge.cleanup(paths); return nil, detail end
    local called, ok, output = pcall(Bridge.runProcess, {executable="powershell.exe", args={"-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-File",paths.script,"-InstallRoot",config.home,"-ResultFile",paths.result}})
    local source = called and ok and Bridge.readFile(paths.result) or nil
    Bridge.cleanup(paths)
    if not called then return nil, ok end
    if not ok then return nil, output end
    if not source or not Bridge.fileExists(Bridge.joinPath(source,"install.py")) then return nil, "The backend download did not return a valid installer." end
    return source
end

function M.install(id)
    if id and id~="tools" then entry(id) end
    local config = M.config()
    local source, message = acquireRelease(config)
    if not source then M.notice("The shared backend could not be downloaded.\n" .. tostring(message)); return end
    local paths, failure = Bridge.tempPaths("hephaestus_bootstrap", {result=".path"})
    if not paths then M.notice(failure); return end
    local called, bootstrapped, diagnostic = pcall(Bridge.runProcess, {executable="powershell.exe",args={"-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-File",Bridge.joinPath(source,"bootstrap.ps1"),"-ResultFile",paths.result}})
    local python = called and bootstrapped and Bridge.readFile(paths.result) or nil
    Bridge.cleanup(paths)
    if not called then M.notice(bootstrapped); return end
    if not bootstrapped then M.notice(diagnostic); return end
    if not python or not Bridge.fileExists(python) then M.notice("The Python bootstrap did not return a valid interpreter."); return end
    local arguments = {"-B","-X","utf8",Bridge.joinPath(source,"install.py"),"--modules",id=="tools" and "all" or id or "all","--home",config.home,"--aegisub",Bridge.decodedPath("?user"),"--compute",config.device or "auto"}
    if id=="tools" then arguments[#arguments+1]="--tools-only" end
    local called, ok, detail = pcall(Bridge.runProcess, {executable=python,args=arguments})
    if not called then M.notice(ok); return end
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
