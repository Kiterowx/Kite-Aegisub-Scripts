local moduleVersion = "1.0.1"
local Settings = {VERSION=moduleVersion, version=moduleVersion}
local Core = require("kite.Core")
local PyBridge = require("kite.PyBridge")
local function safeRequire(name)
    local ok, value = pcall(require, name)
    if ok then return value end
end
local json = safeRequire("json") or safeRequire("l0.dkjson")
local DependencyControl = safeRequire("l0.DependencyControl")
local ConfigHandler = DependencyControl and DependencyControl.ConfigHandler
local copy, finiteNumber = Core.deepCopy, Core.finiteNumber
local depctrl
if DependencyControl then
    depctrl = DependencyControl{
        name="kite.Settings", moduleName="kite.Settings", version=moduleVersion,
        description="Shared settings sections, migration and validated persistence", author="Kiterow",
        url="https://github.com/Kiterowx/Kite-Aegisub-Scripts",
        feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
        {{"kite.Core", version="1.1.0"},{"kite.PyBridge",version="1.7.1"}},
    }
end

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
if depctrl then Settings.version=depctrl; return depctrl:register(Settings) end
return Settings
