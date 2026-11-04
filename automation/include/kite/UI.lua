local DependencyControl = require("l0.DependencyControl")
local depctrl = DependencyControl({
    name = "kite.UI",
    version = "2.0.3",
    description = "Shared Kite dialogs, settings persistence and action utilities",
    author = "Kiterow",
    url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
    moduleName = "kite.UI",
    feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    {
        {"kite.Core", version = "2.0.0", feed= "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.PyBridge", version = "2.0.1", feed= "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
    },
})
depctrl:requireModules()

local Settings = (function()
local moduleVersion = "1.0.1"
local Settings = {VERSION=moduleVersion, version=moduleVersion}
local Core = require("kite.Core")
local PyBridge = require("kite.PyBridge")
local function safeRequire(name)
    local ok, value = pcall(require, name)
    if ok then return value end
end
local json = safeRequire("json") or safeRequire("l0.dkjson")
local ConfigHandler = DependencyControl and DependencyControl.ConfigHandler
local copy, finiteNumber = Core.deepCopy, Core.finiteNumber

local function path(value)
    if type(value) ~= "string" then return value end
    if aegisub and aegisub.decode_path then
        local ok, decoded = pcall(aegisub.decode_path, value)
        if ok and type(decoded) == "string" and decoded ~= "" then return decoded end
    end
    return value
end

local function readFile(fileName) return PyBridge.readFile(path(fileName)) end
local function writeFile(fileName, data) return PyBridge.writeFile(path(fileName), data) end

local function decodeJson(text)
    if not json then return nil, "JSON support is unavailable." end
    local ok, value, position, message = pcall(json.decode, text)
    if not ok or type(value)~="table" then return nil, message or tostring(value) end
    if type(position)=="number" and Core.trim(text:sub(position))~="" then return nil,"Unexpected data after the JSON document." end
    return value
end

local function validJson(data)
    return type(data)=="string" and decodeJson(data)~=nil
end

local function decodeLuaString(value)
    local quote = value:sub(1, 1)
    if (quote ~= '"' and quote ~= "'") or value:sub(-1) ~= quote then return nil end
    local body = value:sub(2, -2)
    body = body:gsub("\\(%d%d?%d?)", function(number)
        if number == "" then return "\\" end
        local code = tonumber(number)
        if code and code <= 255 then return string.char(code) end
        return "\\" .. number
    end)
    local escapes = {
        a = "\a", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", v = "\v",
        ["\\"] = "\\", ['"'] = '"', ["'"] = "'",
    }
    body = body:gsub("\\(.)", function(char) return escapes[char] or char end)
    return body
end

local function scalar(value)
    value = tostring(value or ""):match("^%s*(.-)%s*$") or ""
    value = value:gsub(",$", ""):match("^%s*(.-)%s*$") or ""
    if value == "true" then return true end
    if value == "false" then return false end
    if value == "nil" then return nil end
    local number = tonumber(value)
    if number ~= nil then return number end
    return decodeLuaString(value) or value
end

local function parseLiteralTable(source)
    if type(source) ~= "string" then return nil end
    local position, token, value = 1
    local function nextToken()
        while true do
            local _,last=source:find("^%s*",position)
            position=(last or position-1)+1
            if source:sub(position,position+1)~="--" then break end
            local lineEnd=source:find("\n",position+2,true)
            position=lineEnd and lineEnd+1 or #source+1
        end
        local char=source:sub(position,position)
        if char=="" then token,value="eof",nil;return end
        if char=='"' or char=="'" then
            local parts={}
            position=position+1
            while position<=#source do
                local current=source:sub(position,position)
                position=position+1
                if current==char then token,value="scalar",table.concat(parts);return end
                if current=="\n" or current=="\r" then error("Unescaped newline in string",0) end
                if current=="\\" then
                    local escape=source:sub(position,position)
                    position=position+1
                    local escapes={a="\a",b="\b",f="\f",n="\n",r="\r",t="\t",v="\v",["\\"]="\\",['"']='"',["'"]="'"}
                    if escape:match("%d") then
                        local first,last=source:find("^%d%d?%d?",position-1)
                        local number=tonumber(source:sub(first,last))
                        if number>255 then error("Invalid byte escape",0) end
                        current,position=string.char(number),last+1
                    elseif escape=="\n" then current="\n"
                    elseif escape=="\r" then
                        current="\n"
                        if source:sub(position,position)=="\n" then position=position+1 end
                    elseif escapes[escape] then current=escapes[escape]
                    else error("Invalid string escape",0) end
                end
                parts[#parts+1]=current
            end
            error("Unterminated string",0)
        end
        if char:match("[{}%[%]=,;]") then token,value=char,nil;position=position+1;return end
        local first,last=source:find("^[%+%-]?0[xX]%x+",position)
        if not first then first,last=source:find("^[%+%-]?%d*%.?%d+[eE][%+%-]?%d+",position) end
        if not first then first,last=source:find("^[%+%-]?%d*%.?%d+",position) end
        if first then
            token,value="scalar",finiteNumber(source:sub(first,last))
            if not value then error("Invalid number",0) end
            position=last+1;return
        end
        first,last=source:find("^[%a_][%w_]*",position)
        if first then
            local word=source:sub(first,last)
            position=last+1
            if word=="true" or word=="false" or word=="nil" then
                token,value="scalar",word=="true" and true or word=="false" and false or nil
                if word=="false" then value=false end
            else token,value="word",word end
            return
        end
        error("Expected a table literal",0)
    end
    local function parse()
        nextToken()
        if token=="word" and value=="return" then nextToken() end
        if token~="{" then return nil end
        local result={}
        local stack={{target=result,nextIndex=1,state="field"}}
        nextToken()
        while #stack>0 do
            local frame=stack[#stack]
            if frame.state=="field" then
                if token=="}" then table.remove(stack);nextToken()
                else
                    if token=="[" then
                        nextToken()
                        if token~="scalar" or (type(value)~="number" and type(value)~="string") then return nil end
                        frame.key=value;nextToken()
                        if token~="]" then return nil end
                        nextToken();if token~="=" then return nil end;nextToken()
                    elseif token=="word" then
                        frame.key=value;nextToken()
                        if token~="=" then return nil end;nextToken()
                    else frame.key=frame.nextIndex;frame.nextIndex=frame.nextIndex+1 end
                    frame.state="separator"
                    if token=="{" then
                        local child={};frame.target[frame.key]=child
                        stack[#stack+1]={target=child,nextIndex=1,state="field"}
                        nextToken()
                    elseif token=="scalar" then frame.target[frame.key]=value;nextToken()
                    else return nil end
                end
            elseif token=="," or token==";" then frame.state="field";nextToken()
            elseif token=="}" then table.remove(stack);nextToken()
            else return nil end
        end
        if token~="eof" then return nil end
        return result
    end
    local ok,result=pcall(parse)
    if ok then return result end
    return nil
end

local function parseLuaTable(data)
    local out = {}
    for line in tostring(data or ""):gmatch("[^\r\n]+") do
        local key, value = line:match("^%s*([%a_][%w_]*)%s*=%s*(.-)%s*$")
        if key then out[key] = scalar(value) end
    end
    return out
end

local function parseKeyValue(data)
    local out = {}
    for line in tostring(data or ""):gmatch("[^\r\n]+") do
        local key, value = line:match("^%s*([%w_.%-]+)%s*=%s*(.-)%s*$")
        if key then out[key] = scalar(value) end
    end
    return out
end

local function compatible(value, default)
    if default == nil then return false end
    if type(default) == "number" then return finiteNumber(value) ~= nil end
    return type(value) == type(default)
end

local function sanitize(defaults, incoming)
    defaults = type(defaults) == "table" and defaults or {}
    local out = copy(defaults)
    if type(incoming) ~= "table" then return out end
    for key, default in pairs(defaults) do
        local value = incoming[key]
        if value ~= nil then
            if type(default) == "table" and type(value) == "table" then
                local open = next(default) == nil
                local numeric = #default > 0
                if numeric then
                    local sample = default[1]
                    local sequence = {}
                    for index = 1, #value do
                        local item = value[index]
                        if type(sample) == "table" and type(item) == "table" then
                            sequence[#sequence + 1] = sanitize(sample, item)
                        elseif compatible(item, sample) then
                            sequence[#sequence + 1] = type(sample) == "number" and finiteNumber(item) or copy(item)
                        end
                    end
                    if next(value) == nil then out[key] = {}
                    else out[key] = #sequence > 0 and sequence or copy(default) end
                elseif open then
                    out[key] = copy(value)
                else
                    out[key] = sanitize(default, value)
                end
            elseif compatible(value, default) then
                out[key] = type(default) == "number" and finiteNumber(value) or value
            end
        end
    end
    return out
end

local function readLegacy(source)
    if type(source) ~= "table" then return nil end
    local data = readFile(source.path)
    if not data or data == "" then return nil end
    local format = source.format or "json"
    local decoded
    if format == "json" or format == "json_sections" then
        if not json then return nil end
        local ok, value = pcall(json.decode, data)
        if not ok or type(value) ~= "table" then return nil end
        decoded = value
    elseif format == "lua_literal" then
        decoded = parseLiteralTable(data)
        if not decoded then return nil end
    elseif format == "lua_table" then
        decoded = parseLuaTable(data)
    elseif format == "key_value" then
        decoded = parseKeyValue(data)
    else
        return nil
    end
    if source.section and type(decoded[source.section]) == "table" then decoded = decoded[source.section] end
    if source.transform then
        local ok, value = pcall(source.transform, decoded)
        if not ok or type(value) ~= "table" then return nil end
        decoded = value
    end
    return decoded
end

local Store = {}
Store.__index = Store

function Store:migrateNamespace()
    if not self.handler or type(self.legacyNamespaces) ~= "table" then return false end
    if type(self.handler.userConfig) ~= "table" or next(self.handler.userConfig) ~= nil then return false end
    if type(self.handler.getSectionHandler) ~= "function" or type(self.handler.import) ~= "function" then return false end
    for _, namespace in ipairs(self.legacyNamespaces) do
        if type(namespace) == "string" and namespace ~= "" and namespace ~= self.namespace then
            local ok, source = pcall(self.handler.getSectionHandler, self.handler, {namespace}, {}, true)
            if ok and source and type(source.userConfig) == "table" and next(source.userConfig) ~= nil then
                local imported, changed = pcall(self.handler.import, self.handler, source)
                if imported and changed then
                    local written = self:write()
                    if written and type(source.delete) == "function" then pcall(source.delete, source) end
                    return written and true or false
                end
            end
        end
    end
    return false
end

function Store:load()
    if self.loaded then return self, true end
    if self.loadError then return self, false, self.loadError end
    if not self.handler then self.loaded = true; return self, true end
    local current = readFile(self.fileName)
    if current and not validJson(current) then
        local previous = readFile(self.fileName .. ".last-good")
        if validJson(previous) then writeFile(self.fileName, previous) end
    end
    local ok, found, message = pcall(function() return self.handler:load() end)
    if not ok then self.loadError = tostring(found); return self, false, self.loadError end
    if not found and message then self.loadError=tostring(message);return self,false,self.loadError end
    if type(self.handler.c) ~= "table" then self.handler.c = {} end
    self:migrateNamespace()
    local migrated = false
    if not found then
        for _, source in ipairs(self.legacySources) do
            local decoded = readLegacy(source)
            if decoded then
                for section, defaults in pairs(self.defaults) do
                    local incoming = decoded[section]
                    if incoming == nil and source.target == section then incoming = decoded end
                    if incoming ~= nil then
                        self.handler.c[section] = sanitize(defaults, incoming)
                        migrated = true
                    end
                end
            end
        end
    end
    self.loaded = true
    if migrated then self:write() end
    return self, true
end

function Store:values(section)
    local _, loaded = self:load()
    local values
    if loaded and self.handler and type(self.handler.c) == "table" then values = self.handler.c[section]
    else values = self.memory[section] end
    return sanitize(self.defaults[section] or {}, values or {})
end

function Store:apply(section, controls)
    local values = self:values(section)
    for key, control in pairs(controls or {}) do
        if type(control) == "table" then
            local name = control.name or key
            if values[name] ~= nil then
                if control.text ~= nil and control.value == nil then control.text = values[name]
                else control.value = values[name] end
            end
        end
    end
    return controls
end

function Store:update(section, result, allowlist)
    self:load()
    local values = self:values(section)
    local allowed = {}
    if type(allowlist) == "table" then
        for key, value in pairs(allowlist) do
            if type(key) == "number" then allowed[value] = true else allowed[key] = value and true or false end
        end
    else
        for key in pairs(self.defaults[section] or {}) do allowed[key] = true end
    end
    for key, default in pairs(self.defaults[section] or {}) do
        local value = result and result[key]
        if allowed[key] and value ~= nil and compatible(value, default) then
            if type(default) == "table" then
                values[key] = sanitize({value = default}, {value = value}).value
            else
                values[key] = type(default) == "number" and finiteNumber(value) or copy(value)
            end
        end
    end
    if not self.loadError and self.handler and type(self.handler.c) == "table" then self.handler.c[section] = values
    else self.memory[section] = copy(values) end
    return copy(values)
end

function Store:reset(section)
    self:load()
    if section ~= nil then
        local values = copy(self.defaults[section] or {})
        if not self.loadError and self.handler and type(self.handler.c) == "table" then self.handler.c[section] = values
        else self.memory[section] = values end
        return values
    end
    for name, defaults in pairs(self.defaults) do
        local values = copy(defaults)
        if not self.loadError and self.handler and type(self.handler.c) == "table" then self.handler.c[name] = values
        else self.memory[name] = values end
    end
    return copy(self.defaults)
end

function Store:write()
    if self.handlerError then return false, self.handlerError end
    if self.loadError then return false, self.loadError end
    if not self.handler then return true end
    if type(self.handler.c) ~= "table" then return false, "configuration handler is not loaded" end
    self.handler.c.__version = self.version
    local previous = readFile(self.fileName)
    if validJson(previous) then writeFile(self.fileName .. ".last-good", previous) end
    local ok, result, err = pcall(function() return self.handler:write() end)
    if not ok then return false, result end
    if result == false or (result==nil and err~=nil) then return false, err end
    local written = readFile(self.fileName)
    if not validJson(written) then
        if validJson(previous) then writeFile(self.fileName, previous) end
        return false, "invalid shared configuration"
    end
    return true
end

function Settings.open(namespace, version, defaults, legacySources, legacyNamespaces)
    assert(type(namespace) == "string" and namespace ~= "", "namespace required")
    defaults = type(defaults) == "table" and copy(defaults) or {}
    local handler
    local handlerError
    local fileName = path("?user/config/kite.settings.json")
    if ConfigHandler then
        local payload = copy(defaults)
        payload.__version = version
        local ok, result = pcall(function()
            if type(ConfigHandler.getView) == "function" then
                return assert(ConfigHandler:getView(fileName, {namespace}, payload))
            end
            return ConfigHandler(fileName, payload, {namespace}, true)
        end)
        if ok then handler = result else handlerError = tostring(result) end
    end
    return setmetatable({
        namespace = namespace,
        version = tostring(version or "0.0.0"),
        defaults = defaults,
        legacySources = type(legacySources) == "table" and legacySources or {},
        legacyNamespaces = type(legacyNamespaces) == "table" and legacyNamespaces or {},
        handler = handler,
        handlerError = handlerError,
        fileName = fileName,
        loaded = false,
        memory = copy(defaults),
    }, Store)
end

function Settings.readJson(fileName)
    local text = readFile(fileName)
    if not text then return nil, "Configuration file could not be read." end
    return decodeJson(text)
end

function Settings.encode(value)
    if not json then return nil, "JSON support is unavailable." end
    local ok, text = pcall(json.encode, value, {indent=true})
    if not ok or type(text) ~= "string" then return nil, tostring(text) end
    return text
end

Settings.decode = decodeJson

function Settings.sections()
    local data, message = Settings.readJson("?user/config/kite.settings.json")
    if not data then return nil, message end
    local sections = {}
    for namespace, values in pairs(data) do
        if type(namespace)=="string" and not namespace:match("^kite%.Actions%.") and type(values)=="table" then
            for name, value in pairs(values) do
                if type(name)=="string" and name:sub(1,2)~="__" and type(value)=="table" then
                    sections[#sections+1]={namespace=namespace,name=name,value=copy(value),version=values.__version}
                end
            end
        end
    end
    table.sort(sections,function(a,b) return a.namespace.."/"..a.name < b.namespace.."/"..b.name end)
    return sections
end

function Settings.saveSection(section, values)
    local function matches(original, edited)
        if type(original)~=type(edited) then return false end
        if type(original)=="number" then return finiteNumber(edited)~=nil end
        if type(original)~="table" then return true end
        for key,value in pairs(original) do if not matches(value,edited[key]) then return false end end
        for key in pairs(edited) do if original[key]==nil then return false end end
        return true
    end
    if not matches(section.value,values) then return false,"Keep the existing keys and value types." end
    local store=Settings.open(section.namespace,section.version,{[section.name]=section.value})
    store:update(section.name,values)
    return store:write()
end

function Settings.writeJson(fileName, value)
    local text, message = Settings.encode(value)
    if not text then return false, message end
    return writeFile(fileName, text)
end

Settings.path = path
Settings.readText = readFile
Settings.writeText = writeFile
Settings.sanitize = sanitize
Settings.parseLiteralTable = parseLiteralTable
Settings.parseLuaTable = parseLuaTable
Settings.parseKeyValue = parseKeyValue
return Settings
end)()

local UI = (function(Settings)
local moduleVersion = "2.0.3"
local UI = { VERSION = moduleVersion, version = moduleVersion }

local function safeRequire(name)
    local ok, value = pcall(require, name)
    if ok then return value end
    return nil
end

local Core = assert(safeRequire("kite.Core"), "kite.Core is required")


local copy = Core.deepCopy

UI.actions = (function()
local actionsVersion = "1.0.0"
local Actions = {VERSION=actionsVersion, version=actionsVersion}
local commandPrefix = "automation/lua/"
local settingsPath = "?user/config/kite.settings.json"
local defaultMenuRoot = ": Kite Hotkeys :"
local defaultFavoritesRoot = "Favorites"
local registry, order, favoritePaths = {}, {}, {}
local namespace, rawRegister, configuration
function Actions.normalizePath(value)
    return (Core.trim(value):gsub("/+", "/"):gsub("^/", ""):gsub("/$", ""))
end

function Actions.command(owner, menu)
    return commandPrefix .. owner .. "/" .. Actions.normalizePath(menu)
end

function Actions.remember(name, description, process, validate, isActive, owner)
    owner=owner or namespace
    if not owner then return end
    local command=Actions.command(owner,name)
    if not registry[command] then order[#order+1]=command end
    registry[command]={menu=name,description=description,process=process,validate=validate,isActive=isActive}
    return command
end

function Actions.registerFavorite(config, favorite)
    local entry=type(favorite)=="table" and Actions.resolve(favorite.source)
    if not entry or type(entry.process)~="function" then return false,"The source action must register the favorite in its own script." end
    local menu=Actions.normalizePath(config.menu_root.."/"..config.favorites_root.."/"..favorite.path)
    if favoritePaths[menu] or menu==entry.menu then return true end
    local register=rawRegister or aegisub and aegisub.register_macro
    if not register then return false,"Automation registration is unavailable." end
    register(menu,entry.description,entry.process,entry.validate,entry.isActive)
    favoritePaths[menu]=true
    return true
end

function Actions.configuration()
    local data = Settings.readJson(settingsPath) or {}
    local saved = data["kite.Hotkeys"]
    saved = type(saved)=="table" and saved.main or {}
    saved = type(saved)=="table" and Core.copy(saved) or {}
    saved.menu_root = Core.trim(saved.menu_root)~="" and saved.menu_root or defaultMenuRoot
    saved.favorites_root = Core.trim(saved.favorites_root)~="" and saved.favorites_root or defaultFavoritesRoot
    saved.favorites = type(saved.favorites)=="table" and saved.favorites or {}
    return saved
end

function Actions.rename(owner, aliases, targetOwner)
    local commands = {}
    local dependencyConfig = Settings.readJson("?user/config/l0.DependencyControl.json") or {}
    local macros = dependencyConfig.macros or {}
    local oldRoot = Core.trim((macros[owner] or {}).customMenu)
    local newRoot = Core.trim((macros[targetOwner or owner] or {}).customMenu)
    for old, new in pairs(aliases) do
        commands[Actions.command(owner, old)] = Actions.command(targetOwner or owner, new)
        if oldRoot ~= "" or newRoot ~= "" then
            commands[Actions.command(owner, oldRoot ~= "" and oldRoot .. "/" .. old or old)] =
                Actions.command(targetOwner or owner, newRoot ~= "" and newRoot .. "/" .. new or new)
        end
    end
    local function replace(entries, field)
        local changed = false
        for _, entry in pairs(type(entries) == "table" and entries or {}) do
            if type(entry) == "table" and commands[entry[field]] then
                entry[field], changed = commands[entry[field]], true
            end
        end
        return changed
    end
    for _, file in ipairs({"?user/hotkey.json", "?user/hotkeys.json"}) do
        local data, changed = Settings.readJson(file), false
        for _, bindings in pairs(type(data) == "table" and data or {}) do
            if replace(bindings, "command") then changed = true end
            if type(bindings) == "table" then
                for old, new in pairs(commands) do
                    if old ~= new and type(bindings[old]) == "table" then
                        local keys = bindings[new] or {}
                        for _, key in ipairs(bindings[old]) do
                            local exists = false
                            for _, current in ipairs(keys) do if current == key then exists = true; break end end
                            if not exists then keys[#keys + 1] = key end
                        end
                        bindings[new], bindings[old], changed = keys, nil, true
                    end
                end
            end
        end
        if changed then
            local ok, message = Settings.writeJson(file, data)
            if not ok then UI.log(message, "Hotkey migration") end
        end
    end
    local data = Settings.readJson(settingsPath)
    local saved = type(data) == "table" and data["kite.Hotkeys"]
    saved = type(saved) == "table" and saved.main
    if type(saved) == "table" and replace(saved.favorites, "source") then
        local ok, message = Settings.writeJson(settingsPath, data)
        if not ok then UI.log(message, "Favorite migration") end
    end
    if configuration and replace(configuration.favorites, "source") then
        for _, favorite in ipairs(configuration.favorites) do Actions.registerFavorite(configuration, favorite) end
    end
end

function Actions.attach(owner)
    if rawRegister or type(owner)~="string" or not owner:match("^kite%.") then return end
    if not (aegisub and type(aegisub.register_macro)=="function") then return end
    namespace, rawRegister, configuration = owner, aegisub.register_macro, Actions.configuration()
    aegisub.register_macro = function(name, description, process, validate, isActive)
        local result = rawRegister(name, description, process, validate, isActive)
        local command = Actions.remember(name, description, process, validate, isActive)
        for _, favorite in ipairs(configuration.favorites) do
            if type(favorite)=="table" and favorite.source==command and Core.trim(favorite.path)~="" then
                Actions.registerFavorite(configuration,favorite)
            end
        end
        return result
    end
end

function Actions.publish()
    if not namespace then return true end
    local entries = {}
    for _, command in ipairs(order) do
        local entry=registry[command]
        entries[command]={menu=entry.menu,description=entry.description}
    end
    local store=Settings.open("kite.Actions."..namespace,actionsVersion,{main={commands={}}})
    local _, loaded, message = store:load()
    if not loaded then return false, message end
    local current = store:values("main").commands
    local unchanged = true
    for command, entry in pairs(entries) do
        if not Core.shallowEqual(entry, current[command]) then unchanged = false; break end
    end
    if unchanged then
        for command in pairs(current) do if not entries[command] then unchanged = false; break end end
    end
    if unchanged then return true end
    store:update("main",{commands=entries})
    return store:write()
end

function Actions.catalog()
    local data = Settings.readJson(settingsPath) or {}
    local entries = {}
    for name, section in pairs(data) do
        if type(name)=="string" and name:match("^kite%.Actions%.") and type(section)=="table" then
            local commands=type(section.main)=="table" and section.main.commands
            for command, entry in pairs(type(commands)=="table" and commands or {}) do
                if type(command)=="string" and type(entry)=="table" then entries[command]=entry end
            end
        end
    end
    for command,entry in pairs(registry) do entries[command]={menu=entry.menu,description=entry.description} end
    return entries
end

function Actions.resolve(command)
    return registry[command]
end

Actions.manager = (function()
local Hotkeys = {}
local configFile = "kite.Hotkeys.json"
local stableAnchors = {
    "Kite-Macros",
    ": HELP :",
    ": Non-GUI macros :",
    ": Shapery macros :",
}
local namespaceRenames = {
    ["kite.Automask"] = "kite.AutoMask",
}
local menuRenames = {
    ["kite.AutoBlur"] = {
        ["Auto Blur"] = "AutoBlur",
        ["Autoblur"] = "AutoBlur",
    },
    ["kite.RheaSigns"] = {
        ["Font & Style Manager"] = "Font and Style Manager",
    },
}

local function haveAegisub()
    return aegisub and aegisub.decode_path
end

local function userPath(path)
    if haveAegisub() then
        return aegisub.decode_path(path)
    end
    local appdata = os.getenv("APPDATA") or ""
    local rel = path:gsub("^%?user/?", ""):gsub("/", "\\")
    return appdata .. "\\Aegisub\\" .. rel
end

local function configPath()
    return userPath(settingsPath)
end

local function legacyConfigPath()
    return userPath("?user/config/" .. configFile)
end

local normalizeMenu = Actions.normalizePath
local normalizeCommand = normalizeMenu

local function splitPath(path)
    local parts = {}
    path = normalizeMenu(path)
    for part in path:gmatch("[^/]+") do
        parts[#parts + 1] = part
    end
    return parts
end

local function joinPath(parts, first, last)
    local out = {}
    first = first or 1
    last = last or #parts
    for i = first, last do
        if parts[i] and parts[i] ~= "" then
            out[#out + 1] = parts[i]
        end
    end
    return table.concat(out, "/")
end

local function renamedMenu(namespace, menu)
    local replacements = menuRenames[namespace]
    if not replacements then
        return normalizeMenu(menu), false
    end
    local parts = splitPath(menu)
    local changed = false
    for i = 1, #parts do
        local replacement = replacements[parts[i]]
        if replacement then
            parts[i] = replacement
            changed = true
        end
    end
    return joinPath(parts), changed
end

local function startsWithParts(parts, prefix)
    if #prefix == 0 or #prefix > #parts then
        return false
    end
    for i = 1, #prefix do
        if parts[i] ~= prefix[i] then
            return false
        end
    end
    return true
end

local readFile, writeFile = Settings.readText, Settings.writeText

local encodeJson = Settings.encode

local function decodeJsonFile(path)
    local value,message=Settings.readJson(path)
    if not value then error(message..": "..tostring(path)) end
    return value
end

local function findHotkeyPath()
    local candidates = {
        userPath("?user/hotkey.json"),
        userPath("?user/hotkeys.json"),
    }
    for _, path in ipairs(candidates) do
        local file = io.open(path, "rb")
        if file then
            file:close()
            return path
        end
    end
    return candidates[1]
end

local function defaultConfig()
    return {
        hotkey_path = findHotkeyPath(),
        dep_path = userPath("?user/config/l0.DependencyControl.json"),
        menu_root = defaultMenuRoot,
        favorites_root = defaultFavoritesRoot,
        favorites = {},
    }
end

local hotkeySettings

local function settings()
    if not hotkeySettings then
        hotkeySettings = Settings.open("kite.Hotkeys", "2.0.0", { main = defaultConfig() }, {
            { path = legacyConfigPath(), format = "json", target = "main" },
        })
    end
    return hotkeySettings
end

local function repairConfig(cfg)
    local defaults = defaultConfig()
    cfg = type(cfg) == "table" and cfg or {}
    cfg.hotkey_path = Core.trim(cfg.hotkey_path) ~= "" and Core.trim(cfg.hotkey_path) or defaults.hotkey_path
    cfg.dep_path = Core.trim(cfg.dep_path) ~= "" and Core.trim(cfg.dep_path) or defaults.dep_path
    cfg.menu_root = normalizeMenu(cfg.menu_root) ~= "" and normalizeMenu(cfg.menu_root) or defaults.menu_root
    cfg.favorites_root = normalizeMenu(cfg.favorites_root) ~= "" and normalizeMenu(cfg.favorites_root) or defaults.favorites_root
    cfg.favorites = type(cfg.favorites) == "table" and cfg.favorites or {}
    return cfg
end

function Hotkeys.loadConfig()
    return repairConfig(settings():values("main"))
end

function Hotkeys.saveConfig(cfg)
    cfg = repairConfig(cfg)
    local store = settings()
    store:update("main", cfg)
    local ok, err = store:write()
    if not ok then
        error("Could not write " .. configPath() .. ": " .. tostring(err))
    end
    return configPath()
end

local function parseAutomationCommand(command)
    command = normalizeCommand(command)
    if command:sub(1, #commandPrefix) ~= commandPrefix then
        return nil, normalizeMenu(command)
    end
    local rest = command:sub(#commandPrefix + 1)
    local namespace, menu = rest:match("^([^/]+)/(.+)$")
    if not namespace or not menu then
        return nil, nil
    end
    return namespace, normalizeMenu(menu)
end

local function findSubsequence(parts, needle)
    if #needle == 0 or #needle > #parts then
        return nil
    end
    for i = 1, #parts - #needle + 1 do
        local ok = true
        for j = 1, #needle do
            if parts[i + j - 1] ~= needle[j] then
                ok = false
                break
            end
        end
        if ok then
            return i
        end
    end
    return nil
end

local function appendParts(dst, src)
    for i = 1, #src do
        dst[#dst + 1] = src[i]
    end
end

local function currentMenuParts(record)
    if type(record) ~= "table" or type(record.customMenu) ~= "string" then
        return {}
    end
    return splitPath(record.customMenu)
end

local function findDependencyRecord(depConfig, namespace)
    if type(depConfig) ~= "table" then
        return nil
    end
    if type(depConfig.modules) == "table" and type(depConfig.modules[namespace]) == "table" then
        return depConfig.modules[namespace]
    end
    if type(depConfig.macros) == "table" and type(depConfig.macros[namespace]) == "table" then
        return depConfig.macros[namespace]
    end
    return nil
end

local function stableSuffixStart(parts, record)
    local best
    for _, anchor in ipairs(stableAnchors) do
        local idx = findSubsequence(parts, splitPath(anchor))
        if idx and (not best or idx < best) then
            best = idx
        end
    end

    if type(record) == "table" and type(record.name) == "string" and record.name ~= "" then
        local idx = findSubsequence(parts, splitPath(record.name))
        if idx and (not best or idx < best) then
            best = idx
        end
    end

    return best
end

function Hotkeys.targetMenu(menu, record)
    local parts = splitPath(menu)
    if #parts == 0 or type(record) ~= "table" then
        return nil
    end

    local custom = currentMenuParts(record)
    if #custom > 0 and not startsWithParts(parts, custom) and findSubsequence(parts, splitPath(defaultMenuRoot)) then
        local targetParts = {}
        appendParts(targetParts, custom)
        appendParts(targetParts, parts)
        return joinPath(targetParts), "DependencyControl customMenu + explicit menu"
    end

    local localStart, reason

    if startsWithParts(parts, custom) then
        localStart = #custom + 1
        reason = "already current"
    else
        local anchorStart = stableSuffixStart(parts, record)
        if anchorStart then
            localStart = anchorStart
            reason = "DependencyControl customMenu"
        elseif #custom > 0 and #parts > 1 then
            localStart = 2
            reason = "DependencyControl customMenu fallback"
        elseif #custom > 0 then
            localStart = 1
            reason = "DependencyControl customMenu missing"
        else
            return nil
        end
    end

    local localParts = {}
    for i = localStart, #parts do
        localParts[#localParts + 1] = parts[i]
    end
    if #localParts == 0 then
        return nil
    end

    local targetParts = {}
    appendParts(targetParts, custom)
    appendParts(targetParts, localParts)

    local target = joinPath(targetParts)
    if target == normalizeMenu(menu) then
        return nil
    end
    return target, reason
end

function Hotkeys.analyze(hotkeys, depConfig)
    local changes = {}
    if type(hotkeys) ~= "table" then
        return changes
    end

    for context, bindings in pairs(hotkeys) do
        if type(bindings) == "table" then
            for command, keys in pairs(bindings) do
                local namespace, menu = parseAutomationCommand(command)
                local oldNamespace = namespace
                namespace = namespace and (namespaceRenames[namespace] or namespace)
                local namespaceRenamed = namespace ~= oldNamespace
                local record = namespace and findDependencyRecord(depConfig, namespace)
                if record then
                    local updatedMenu, renamed = renamedMenu(namespace, menu)
                    local targetMenu, reason = Hotkeys.targetMenu(updatedMenu, record)
                    local renameReason
                    if namespaceRenamed then renameReason = "renamed namespace" end
                    if renamed then
                        renameReason = renameReason and (renameReason .. " + renamed command") or "renamed command"
                    end
                    if renameReason and not targetMenu then
                        targetMenu = updatedMenu
                        reason = renameReason
                    elseif renameReason then
                        reason = renameReason .. " + " .. tostring(reason)
                    end
                    if targetMenu then
                        changes[#changes + 1] = {
                            context = context,
                            old_command = command,
                            new_command = commandPrefix .. namespace .. "/" .. targetMenu,
                            keys = keys,
                            reason = reason,
                        }
                    end
                end
            end
        end
    end

    table.sort(changes, function(a, b)
        if a.context ~= b.context then
            return a.context < b.context
        end
        return a.old_command < b.old_command
    end)

    return changes
end

local function mergeKeys(existing, incoming)
    local result, seen = {}, {}
    local function addAll(list)
        if type(list) ~= "table" then
            return
        end
        for i = 1, #list do
            local key = list[i]
            if type(key) == "string" and not seen[key] then
                result[#result + 1] = key
                seen[key] = true
            end
        end
    end
    addAll(existing)
    addAll(incoming)
    return result
end

function Hotkeys.applyChanges(hotkeys, changes)
    local moves = {}
    for _, change in ipairs(changes or {}) do
        local bindings = hotkeys[change.context]
        if change.old_command ~= change.new_command and type(bindings) == "table" and bindings[change.old_command] then
            moves[#moves+1] = {bindings=bindings, source=change.old_command, target=change.new_command, keys=bindings[change.old_command]}
        end
    end
    for _, move in ipairs(moves) do move.bindings[move.source] = nil end
    for _, move in ipairs(moves) do
        move.bindings[move.target] = mergeKeys(move.bindings[move.target], move.keys)
    end
    return #moves
end

function Hotkeys.writePlan(plan)
    local original, readError = readFile(plan.hotkey_path)
    if not original then error("Could not read " .. plan.hotkey_path .. ": " .. tostring(readError)) end
    if plan.original_text and original ~= plan.original_text then
        error("The hotkey file changed during review. Run Sync again to include those changes.")
    end
    local encoded, encodeError = encodeJson(plan.hotkeys)
    if not encoded then error(tostring(encodeError)) end
    local backupBase = plan.hotkey_path .. ".bak-" .. os.date("%Y%m%d-%H%M%S")
    local backupPath, suffix = backupBase, 1
    while readFile(backupPath) do suffix=suffix+1;backupPath=backupBase.."-"..suffix end
    local ok, err = writeFile(backupPath, original)
    if not ok then error("Could not create backup " .. backupPath .. ": " .. tostring(err)) end
    ok, err = writeFile(plan.hotkey_path, encoded .. "\n")
    if not ok then error("Could not write " .. plan.hotkey_path .. ": " .. tostring(err)) end
    return backupPath
end

Hotkeys.rememberMacro = Actions.remember
Hotkeys.installCaptureHook = Actions.attach
Hotkeys.resolveSource = Actions.resolve
Hotkeys.registerFavorite = Actions.registerFavorite

function Hotkeys.planFromConfig(cfg)
    cfg = repairConfig(cfg)
    local original, readError = readFile(cfg.hotkey_path)
    if not original then error(tostring(readError)) end
    local hotkeys, decodeError = Settings.decode(original)
    if type(hotkeys)~="table" then error(tostring(decodeError or "The hotkey file must contain a JSON object.")) end
    local depConfig = decodeJsonFile(cfg.dep_path)
    local changes = Hotkeys.analyze(hotkeys, depConfig)
    return {
        hotkey_path = cfg.hotkey_path,
        original_text = original,
        dep_path = cfg.dep_path,
        hotkeys = hotkeys,
        changes = changes,
    }
end

local function keyList(keys)
    if type(keys) ~= "table" then
        return ""
    end
    return table.concat(keys, ", ")
end

local function formatChanges(plan)
    local lines = {
        "hotkey file: " .. tostring(plan.hotkey_path),
        "DependencyControl: " .. tostring(plan.dep_path),
        "Changes: " .. tostring(#plan.changes),
        "",
    }
    for _, change in ipairs(plan.changes) do
        lines[#lines + 1] = "[" .. tostring(change.context) .. "] " .. keyList(change.keys)
        lines[#lines + 1] = "  " .. tostring(change.old_command)
        lines[#lines + 1] = "  -> " .. tostring(change.new_command)
    end
    return table.concat(lines, "\n")
end

local function showDialog(textOrDialog, buttons)
    if aegisub and aegisub.dialog and aegisub.dialog.display then
        buttons = buttons or { "OK" }
        if type(textOrDialog) == "table" then
            return aegisub.dialog.display(textOrDialog, buttons, {close=buttons[#buttons]})
        end
        local dialog = {
            { class = "textbox", name = "report", x = 0, y = 0, width = 70, height = 20, text = tostring(textOrDialog or "") },
        }
        return aegisub.dialog.display(dialog, buttons, {close=buttons[#buttons]})
    end
    error(tostring(textOrDialog))
end

local function syncMain()
    local okCfg, cfgOrErr = pcall(Hotkeys.loadConfig)
    if not okCfg then
        showDialog("Hotkeys config error:\n\n" .. tostring(cfgOrErr))
        return
    end

    local okPlan, planOrErr = pcall(Hotkeys.planFromConfig, cfgOrErr)
    if not okPlan then
        showDialog("Hotkeys sync error:\n\n" .. tostring(planOrErr))
        return
    end

    local plan = planOrErr
    if #plan.changes == 0 then
        showDialog("No hotkeys need DependencyControl menu sync.\n\n" .. formatChanges(plan))
        return
    end

    local button = showDialog(formatChanges(plan), { "Apply", "Close" })
    if button ~= "Apply" then
        return
    end

    local applied = Hotkeys.applyChanges(plan.hotkeys, plan.changes)
    local okWrite, backupOrErr = pcall(Hotkeys.writePlan, plan)
    if not okWrite then
        showDialog("Hotkeys sync write error:\n\n" .. tostring(backupOrErr))
        return
    end

    showDialog(
        "Applied changes: " .. tostring(applied) ..
        "\nBackup: " .. tostring(backupOrErr) ..
        "\n\nReload Aegisub if the new shortcuts are not active immediately."
    )
end

local function collectHotkeyCommands(path)
    local out, seen = {}, {}
    local ok, hotkeys = pcall(decodeJsonFile, path)
    if not ok or type(hotkeys) ~= "table" then
        return out, ok and nil or tostring(hotkeys)
    end

    for _, bindings in pairs(hotkeys) do
        if type(bindings) == "table" then
            for command, _ in pairs(bindings) do
                if type(command) == "string" and command:sub(1, #commandPrefix) == commandPrefix and not seen[command] then
                    seen[command] = true
                    out[#out + 1] = command
                end
            end
        end
    end
    table.sort(out)
    return out
end

local function addUnique(out, seen, command)
    command = normalizeCommand(command)
    if command ~= "" and command:sub(1, #commandPrefix) == commandPrefix and not seen[command] then
        seen[command] = true
        out[#out + 1] = command
    end
end

function Hotkeys.knownCommands(cfg)
    cfg = repairConfig(cfg)
    local out, seen = {}, {}

    for command in pairs(Actions.catalog()) do
        addUnique(out, seen, command)
    end

    local hotkeyCommands = collectHotkeyCommands(cfg.hotkey_path)
    for _, command in ipairs(hotkeyCommands) do
        addUnique(out, seen, command)
    end

    for _, fav in ipairs(cfg.favorites or {}) do
        if type(fav) == "table" then
            addUnique(out, seen, fav.source)
        end
    end

    table.sort(out)
    return out
end

local function lastMenuPart(command)
    local _, menu = parseAutomationCommand(command)
    local parts = splitPath(menu or command)
    return parts[#parts] or command
end

local function favoritePathFromSource(source)
    return normalizeMenu(lastMenuPart(source))
end

local function displayCommand(command)
    local namespace, menu = parseAutomationCommand(command)
    if namespace and menu then
        return lastMenuPart(command) .. " [" .. namespace .. "] - " .. menu
    end
    return command
end

local function commandDropdownData(cfg)
    local commands = Hotkeys.knownCommands(cfg)
    local items, map, used = {}, {}, {}
    for _, command in ipairs(commands) do
        local label = displayCommand(command)
        if used[label] then
            label = label .. " - " .. command
        end
        used[label] = true
        items[#items + 1] = label
        map[label] = command
    end
    if #items == 0 then
        items[1] = ""
        map[""] = ""
    end
    return items, map
end

local function normalizeFavoritePath(path, cfg)
    path = normalizeMenu(path)
    if path == "" then
        return ""
    end

    local parts = splitPath(path)
    local root = splitPath(cfg.menu_root or defaultMenuRoot)
    if startsWithParts(parts, root) then
        parts = { unpack(parts, #root + 1) }
    end

    local favorites = splitPath(cfg.favorites_root or defaultFavoritesRoot)
    local first = parts[1] and parts[1]:lower() or ""
    if #favorites>0 and startsWithParts(parts, favorites) then
        parts = { unpack(parts, #favorites + 1) }
    elseif first == "favorites" or first == "favourite" then
        parts = { unpack(parts, 2) }
    end

    return joinPath(parts)
end

local function addFavorite(cfg, path, source)
    path = normalizeFavoritePath(path, cfg)
    source = normalizeCommand(source)
    if path == "" then
        path = favoritePathFromSource(source)
    end
    if path == "" or source == "" then
        error("Favorite path and source command are required")
    end

    for _, fav in ipairs(cfg.favorites) do
        if type(fav) == "table" and normalizeMenu(fav.path) == path then
            fav.path = path
            fav.source = source
            return fav, "updated"
        end
    end

    local fav = { path = path, source = source }
    cfg.favorites[#cfg.favorites + 1] = fav
    return fav, "added"
end

local function removeFavorite(cfg, path)
    path = normalizeFavoritePath(path, cfg)
    if path == "" then
        return false
    end
    for i = #cfg.favorites, 1, -1 do
        local fav = cfg.favorites[i]
        if type(fav) == "table" and normalizeMenu(fav.path) == path then
            table.remove(cfg.favorites, i)
            return true
        end
    end
    return false
end

local function favoriteItems(cfg)
    local items = {}
    for _, fav in ipairs(cfg.favorites or {}) do
        if type(fav) == "table" and Core.trim(fav.path) ~= "" then
            items[#items + 1] = normalizeMenu(fav.path)
        end
    end
    table.sort(items)
    if #items == 0 then
        items[1] = ""
    end
    return items
end

local function favoritesReport(cfg)
    local lines = {
        "Config: " .. configPath(),
        "Menu: " .. normalizeMenu(cfg.menu_root) .. "/" .. normalizeMenu(cfg.favorites_root),
        "",
        "Favorites:",
    }
    if #(cfg.favorites or {}) == 0 then
        lines[#lines + 1] = "  (none)"
    else
        for _, fav in ipairs(cfg.favorites) do
            if type(fav) == "table" then
                lines[#lines + 1] = "  " .. tostring(fav.path)
                lines[#lines + 1] = "    -> " .. tostring(fav.source)
            end
        end
    end
    return table.concat(lines, "\n")
end

local function registeredReport(cfg)
    local commands = Hotkeys.knownCommands(cfg)
    local catalog = Actions.catalog()
    local lines = {
        "Known automation commands: " .. tostring(#commands),
        "",
    }
    for _, command in ipairs(commands) do
        local captured = catalog[command] and "registered" or "known"
        lines[#lines + 1] = "[" .. captured .. "] " .. command
    end
    return table.concat(lines, "\n")
end

local function applyDialogConfig(cfg, res)
    cfg.hotkey_path = Core.trim(res.hotkey_path)
    cfg.dep_path = Core.trim(res.dep_path)
    cfg.menu_root = normalizeMenu(res.menu_root)
    cfg.favorites_root = normalizeMenu(res.favorites_root)
    return repairConfig(cfg)
end

local function configStep(editSettings, cfg, draft)
    local sourceItems, sourceMap = commandDropdownData(cfg)
    local removeItems = favoriteItems(cfg)
    local defaultSource = draft.source_choice and sourceMap[draft.source_choice] and draft.source_choice or sourceItems[1] or ""
    local defaultFavorite = draft.favorite_path or favoritePathFromSource(sourceMap[defaultSource] or defaultSource)

    local dialog = {
        { class = "label", label = "Hotkey file", x = 0, y = 0, width = 4, height = 1 },
        { class = "edit", name = "hotkey_path", value = cfg.hotkey_path, x = 4, y = 0, width = 28, height = 1 },
        { class = "label", label = "DependencyControl", x = 0, y = 1, width = 4, height = 1 },
        { class = "edit", name = "dep_path", value = cfg.dep_path, x = 4, y = 1, width = 28, height = 1 },
        { class = "label", label = "Menu root", x = 0, y = 2, width = 4, height = 1 },
        { class = "edit", name = "menu_root", value = cfg.menu_root, x = 4, y = 2, width = 12, height = 1 },
        { class = "label", label = "Favorites root", x = 16, y = 2, width = 4, height = 1 },
        { class = "edit", name = "favorites_root", value = cfg.favorites_root, x = 20, y = 2, width = 12, height = 1 },
        { class = "label", label = "Source", x = 0, y = 3, width = 4, height = 1 },
        { class = "dropdown", name = "source_choice", items = sourceItems, value = defaultSource, x = 4, y = 3, width = 28, height = 1 },
        { class = "label", label = "Favorite path", x = 0, y = 4, width = 4, height = 1 },
        { class = "edit", name = "favorite_path", value = defaultFavorite, x = 4, y = 4, width = 12, height = 1 },
        { class = "label", label = "Remove", x = 16, y = 4, width = 4, height = 1 },
        { class = "dropdown", name = "remove_path", items = removeItems, value = draft.remove_path or removeItems[1] or "", x = 20, y = 4, width = 12, height = 1 },
        { class = "textbox", name = "favorites", text = favoritesReport(cfg), x = 0, y = 5, width = 32, height = 14 },
    }

    local buttons={ "Save", "Add Favorite", "Remove Favorite", "Registered", "Close" }
    if editSettings then table.insert(buttons,#buttons,"Settings") end
    local button, res = showDialog(dialog, buttons)
    if not button or button == "Close" then
        return
    end

    cfg = applyDialogConfig(cfg, res)
    draft.source_choice,draft.favorite_path,draft.remove_path=res.source_choice,res.favorite_path,res.remove_path

    if button == "Settings" then
        editSettings()
        return true
    end

    if button == "Registered" then
        showDialog(registeredReport(cfg))
        return true
    end

    if button == "Add Favorite" then
        local source = sourceMap[res.source_choice] or normalizeCommand(res.source_choice)
        local fav, action = addFavorite(cfg, res.favorite_path, source)
        Hotkeys.saveConfig(cfg)
        Hotkeys.registerFavorite(cfg, fav)
        showDialog(
            "Favorite " .. action .. ":\n\n" ..
            normalizeMenu(cfg.menu_root) .. "/" .. normalizeMenu(cfg.favorites_root) .. "/" .. fav.path ..
            "\n\nSource:\n" .. fav.source ..
            "\n\nReload Automation so the source script registers this favorite."
        )
        return true
    end

    if button == "Remove Favorite" then
        local removed = removeFavorite(cfg, res.remove_path)
        Hotkeys.saveConfig(cfg)
        showDialog((removed and "Favorite removed." or "Favorite not found.") .. "\n\nReload Aegisub to clear already registered menu entries.")
        return true
    end

    Hotkeys.saveConfig(cfg)
    showDialog("Hotkeys config saved:\n\n" .. configPath() .. "\n\nReload Aegisub if you changed menu roots.")
end

function Hotkeys.registerConfiguredFavorites(cfg)
    for _,favorite in ipairs(cfg.favorites or {}) do Actions.registerFavorite(cfg,favorite) end
end

Hotkeys.load_config = Hotkeys.loadConfig
Hotkeys.save_config = Hotkeys.saveConfig
Hotkeys.target_menu = Hotkeys.targetMenu
Hotkeys.apply_changes = Hotkeys.applyChanges
Hotkeys.write_plan = Hotkeys.writePlan
Hotkeys.remember_macro = Hotkeys.rememberMacro
Hotkeys.install_capture_hook = Hotkeys.installCaptureHook
Hotkeys.plan_from_config = Hotkeys.planFromConfig
Hotkeys.known_commands = Hotkeys.knownCommands
Hotkeys.resolve_source = Hotkeys.resolveSource
Hotkeys.register_favorite = Hotkeys.registerFavorite
Hotkeys.register_configured_favorites = Hotkeys.registerConfiguredFavorites

function Hotkeys.configure(editSettings)
    local loaded,cfg=pcall(Hotkeys.loadConfig)
    if not loaded then showDialog("Hotkeys config error:\n\n"..tostring(cfg));return end
    local draft={}
    while true do
        local ok,again=pcall(configStep,editSettings,cfg,draft)
        if not ok then showDialog("Hotkeys config error:\n\n"..tostring(again))
        elseif not again then return end
    end
end
Hotkeys.sync = syncMain
return Hotkeys
end)()

return Actions
end)()
local Actions = UI.actions
local path = Settings.path
UI.settings = Settings.open
UI.captureActions = Actions.attach
UI.publishActions = Actions.publish
Actions.attach(script_namespace)

local DialogHandler = {}
DialogHandler.__index = DialogHandler

local function dialogDefaults(interface, aliases)
    local defaults = {}
    for section, controls in pairs(interface or {}) do
        local storage = aliases and aliases[section] or section
        defaults[storage] = defaults[storage] or {}
        for key, control in pairs(controls or {}) do
            if type(control) == "table" and control.config then
                local name = control.name or key
                local value = control.value
                if value == nil then value = control.text end
                if value ~= nil then defaults[storage][name] = copy(value) end
            end
        end
    end
    return defaults
end

function DialogHandler:read()
    self.store:load()
    for section in pairs(self.interface) do
        local storage = self.aliases[section] or section
        self.configuration[section] = self.store:values(storage)
    end
    self.readCalled = true
    return true
end

function DialogHandler:updateInterface(sectionNames)
    local names = sectionNames
    if names == nil then
        names = {}
        for section in pairs(self.interface) do names[#names + 1] = section end
    elseif type(names) ~= "table" then
        names = {names}
    end
    for _, section in ipairs(names) do
        local storage = self.aliases[section] or section
        self.store:apply(storage, self.interface[section])
        self.configuration[section] = self.store:values(storage)
    end
    self.readCalled = true
end

function DialogHandler:updateConfiguration(result, sectionNames)
    local names = sectionNames
    if names == nil then
        names = {}
        for section in pairs(self.interface) do names[#names + 1] = section end
    elseif type(names) ~= "table" then
        names = {names}
    end
    for _, section in ipairs(names) do
        local storage = self.aliases[section] or section
        local source = result
        if result and result[section] and type(sectionNames) == "table" then source = result[section] end
        self.configuration[section] = self.store:update(storage, source or {})
    end
    self.readCalled = true
end

function DialogHandler:write()
    if not self.readCalled then self:read() end
    for section in pairs(self.interface) do
        local storage = self.aliases[section] or section
        if self.configuration[section] then self.store:update(storage, self.configuration[section]) end
    end
    return self.store:write()
end

function DialogHandler:delete()
    for section in pairs(self.interface) do
        local storage = self.aliases[section] or section
        self.store:reset(storage)
        self.configuration[section] = copy(self.defaults[storage] or {})
    end
    self.readCalled = true
    return self.store:write()
end

function UI.dialogHandler(interface, namespace, version, legacySources, aliases)
    aliases = aliases or {}
    local defaults = dialogDefaults(interface, aliases)
    local store = UI.settings(namespace, version, defaults, legacySources)
    local configuration = {}
    for section in pairs(interface or {}) do configuration[section] = copy(defaults[aliases[section] or section] or {}) end
    return setmetatable({
        interface = interface,
        defaults = defaults,
        store = store,
        aliases = aliases,
        configuration = configuration,
        fileName = path("?user/config/kite.settings.json"),
        readCalled = false,
    }, DialogHandler)
end

function UI.workflow(title, subtitle, controls, buttons, roles)
    local width, headerRows = 40, 3
    for _, control in ipairs(controls) do width=math.max(width,(control.x or 0)+(control.width or 1)) end
    local dialog={
        {class="label",label=title,x=0,y=0,width=width,height=1},
        {class="label",label=subtitle or "",x=0,y=1,width=width,height=1},
    }
    for _,control in ipairs(controls) do
        local item=Core.copy(control)
        item.y=(item.y or 0)+headerRows
        dialog[#dialog+1]=item
    end
    return aegisub.dialog.display(dialog,buttons,roles)
end

function UI.chooseAction(spec)
    local current = spec.current
    while true do
        local dialog, context = spec.build(current)
        local roles = spec.buttons(current)
        local button, result = aegisub.dialog.display(dialog, roles.order, {ok = roles.run, close = roles.cancel})
        if not button or button == roles.cancel then return nil end
        local chosen = spec.read(result, current, context)
        if button == roles.run then
            if spec.on_run then spec.on_run(chosen, result, context) end
            return chosen
        elseif button == roles.help then
            current = chosen
            if spec.on_help then spec.on_help(chosen, result, context) end
        elseif button == roles.language then
            current = chosen
            if spec.on_language then spec.on_language(chosen, result, context) end
        else
            return nil
        end
    end
end

function UI.editSettings()
    local sections, message=Settings.sections()
    if not sections then return UI.message(message) end
    if #sections==0 then return UI.message("No saved settings yet.") end
    local names={}
    for i,section in ipairs(sections) do names[i]=section.namespace.." / "..section.name end
    local chosen=names[1]
    while true do
        local button,result=UI.workflow("Suite settings","Choose a saved section to edit its values.",{
            {class="dropdown",name="section",items=names,value=chosen,x=0,y=0,width=40,height=1},
        },{"Edit","Close"},{ok="Edit",close="Close"})
        if button~="Edit" then return end
        chosen=result.section
        local section
        for i,name in ipairs(names) do if name==chosen then section=sections[i];break end end
        if section then
            local encoded=assert(Settings.encode(section.value))
            while true do
                local action,values=UI.workflow(chosen,"Keep the existing keys and value types. Changes apply when the script reads its settings again.",{
                    {class="textbox",name="values",text=encoded,x=0,y=0,width=70,height=20},
                },{"Save","Back"},{ok="Save",close="Back"})
                if action~="Save" then break end
                encoded=values.values
                local decoded,problem=Settings.decode(encoded)
                local saved
                if decoded then saved,problem=Settings.saveSection(section,decoded) end
                if saved then section.value=decoded;UI.message("Settings saved.");break end
                UI.message(problem)
            end
        end
    end
end

function UI.log(message, title)
    local text = (title and (tostring(title) .. ": ") or "") .. tostring(message or "") .. "\n"
    if aegisub and aegisub.log then return pcall(aegisub.log, "%s", text) end
    if aegisub and aegisub.debug and aegisub.debug.out then return pcall(aegisub.debug.out, "%s", text) end
end

function UI.message(message, options)
    options = options or {}
    local text = tostring(message or "")
    if not (aegisub and aegisub.dialog and aegisub.dialog.display) then
        return UI.log(text, options.title)
    end
    local _, breaks = text:gsub("\n", "")
    local width = options.width or 56
    local height = options.height or math.max(6, math.min(20, breaks + 3))
    local controls, row = {}, 0
    if options.title then
        controls[#controls + 1] = {class="label", label=tostring(options.title), x=0, y=row, width=width, height=1}
        row = row + 1
    end
    controls[#controls + 1] = {class="textbox", name="message", text=text, x=0, y=row, width=width, height=height}
    local buttons = options.buttons or {options.button or "OK"}
    return aegisub.dialog.display(controls, buttons, {close=options.close or buttons[#buttons]})
end

UI.copy = copy
UI.sanitize = Settings.sanitize
UI.parseLuaTable = Settings.parseLuaTable
UI.parseKeyValue = Settings.parseKeyValue

return UI
end)(Settings)

UI.Settings = Settings

if depctrl then
    UI.version = depctrl
    return depctrl:register(UI)
end
return UI
