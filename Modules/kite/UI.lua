local MODULE_VERSION = "1.1.3"
local UI = { VERSION = MODULE_VERSION, version = MODULE_VERSION }

local function safe_require(name)
    local ok, value = pcall(require, name)
    if ok then return value end
    return nil
end

local json = safe_require("json")
local aegisubUtil = safe_require("aegisub.util")
local DependencyControl = safe_require("l0.DependencyControl")
local ConfigHandler = DependencyControl and DependencyControl.ConfigHandler or nil
local depctrl
if DependencyControl then
    depctrl = DependencyControl({
        name = "kite.UI",
        version = MODULE_VERSION,
        description = "Shared Kite dialog and settings utilities",
        author = "Kiterow",
        url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
        moduleName = "kite.UI",
        feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    })
end

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    if aegisubUtil and type(aegisubUtil.deep_copy) == "function" then
        local ok, result = pcall(aegisubUtil.deep_copy, value)
        if ok then return result end
    end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, item in pairs(value) do out[copy(key, seen)] = copy(item, seen) end
    return out
end

local function path(value)
    if type(value) ~= "string" then return value end
    if aegisub and aegisub.decode_path then
        local ok, decoded = pcall(aegisub.decode_path, value)
        if ok and type(decoded) == "string" and decoded ~= "" then return decoded end
    end
    return value
end

local function read_file(file_name)
    file_name = path(file_name)
    if type(file_name) ~= "string" or file_name == "" then return nil end
    local file = io.open(file_name, "rb")
    if not file then return nil end
    local called, data = pcall(file.read, file, "*a")
    pcall(file.close, file)
    return called and data or nil
end

local write_counter = 0

local function flush_and_close(file, flush)
    local flush_ok, flush_result, flush_message = true, true, nil
    if flush then
        flush_ok, flush_result, flush_message = pcall(file.flush, file)
        flush_ok = flush_ok and flush_result ~= nil and flush_result ~= false
    end
    local close_ok, close_result, close_message = pcall(file.close, file)
    close_ok = close_ok and close_result ~= nil and close_result ~= false
    if not flush_ok or not close_ok then
        return false, flush_message or close_message or flush_result or close_result or "file finalization failed"
    end
    return true
end

local function write_file(file_name, data)
    file_name = path(file_name)
    if type(file_name) ~= "string" or file_name == "" then return false, "file path is empty" end
    write_counter = write_counter + 1
    local temporary = file_name .. ".temporary." .. tostring(os.time()) .. "." .. tostring(write_counter)
    local file, message = io.open(temporary, "wb")
    if not file then return false, message end
    local called, ok, write_message = pcall(file.write, file, data or "")
    local finalized, final_message = flush_and_close(file, called and ok ~= nil and ok ~= false)
    if not called or ok == nil or ok == false or not finalized then
        os.remove(temporary)
        return false, (not called and ok) or write_message or final_message
    end
    local backup = file_name .. ".replacement-backup." .. tostring(os.time()) .. "." .. tostring(write_counter)
    local existing = io.open(file_name, "rb")
    local had_existing = existing ~= nil
    if existing then
        existing:close()
        local moved, move_message = os.rename(file_name, backup)
        if not moved then os.remove(temporary); return false, move_message end
    end
    local moved, move_message = os.rename(temporary, file_name)
    if not moved then
        if had_existing then
            local restored, restore_message = os.rename(backup, file_name)
            if not restored then
                os.remove(temporary)
                return false, tostring(move_message or "replacement failed") .. "; backup retained at " .. backup
                    .. ": " .. tostring(restore_message or "restore failed")
            end
        end
        os.remove(temporary)
        return false, move_message
    end
    if had_existing then os.remove(backup) end
    return true
end

local function valid_json(data)
    if not json or type(data) ~= "string" or data == "" then return false end
    local ok, value = pcall(json.decode, data)
    return ok and type(value) == "table"
end

local function decode_lua_string(value)
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
    return decode_lua_string(value) or value
end

local function parse_lua_table(data)
    local out = {}
    for line in tostring(data or ""):gmatch("[^\r\n]+") do
        local key, value = line:match("^%s*([%a_][%w_]*)%s*=%s*(.-)%s*$")
        if key then out[key] = scalar(value) end
    end
    return out
end

local function parse_key_value(data)
    local out = {}
    for line in tostring(data or ""):gmatch("[^\r\n]+") do
        local key, value = line:match("^%s*([%w_.%-]+)%s*=%s*(.-)%s*$")
        if key then out[key] = scalar(value) end
    end
    return out
end

local function finite_number(value)
    local number = tonumber(value)
    if not number or number ~= number or math.abs(number) == math.huge then return nil end
    return number
end

local function compatible(value, default)
    if default == nil then return false end
    if type(default) == "number" then return finite_number(value) ~= nil end
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
                            sequence[#sequence + 1] = type(sample) == "number" and finite_number(item) or copy(item)
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
                out[key] = type(default) == "number" and finite_number(value) or value
            end
        end
    end
    return out
end

local function read_legacy(source)
    if type(source) ~= "table" then return nil end
    local data = read_file(source.path)
    if not data or data == "" then return nil end
    local format = source.format or "json"
    local decoded
    if format == "json" or format == "json_sections" then
        if not json then return nil end
        local ok, value = pcall(json.decode, data)
        if not ok or type(value) ~= "table" then return nil end
        decoded = value
    elseif format == "lua_table" then
        decoded = parse_lua_table(data)
    elseif format == "key_value" then
        decoded = parse_key_value(data)
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
    if not self.handler or type(self.legacy_namespaces) ~= "table" then return false end
    if type(self.handler.userConfig) ~= "table" or next(self.handler.userConfig) ~= nil then return false end
    if type(self.handler.getSectionHandler) ~= "function" or type(self.handler.import) ~= "function" then return false end
    for _, namespace in ipairs(self.legacy_namespaces) do
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
    if self.load_error then return self, false, self.load_error end
    if not self.handler then self.loaded = true; return self, true end
    local current = read_file(self.file_name)
    if current and not valid_json(current) then
        local previous = read_file(self.file_name .. ".last-good")
        if valid_json(previous) then write_file(self.file_name, previous) end
    end
    local ok, found = pcall(function() return self.handler:load() end)
    if not ok then self.load_error = tostring(found); return self, false, self.load_error end
    if type(self.handler.c) ~= "table" then self.handler.c = {} end
    self:migrateNamespace()
    local migrated = false
    if not found then
        for _, source in ipairs(self.legacy_sources) do
            local decoded = read_legacy(source)
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
                values[key] = type(default) == "number" and finite_number(value) or copy(value)
            end
        end
    end
    if not self.load_error and self.handler and type(self.handler.c) == "table" then self.handler.c[section] = values
    else self.memory[section] = copy(values) end
    return copy(values)
end

function Store:reset(section)
    self:load()
    if section ~= nil then
        local values = copy(self.defaults[section] or {})
        if not self.load_error and self.handler and type(self.handler.c) == "table" then self.handler.c[section] = values
        else self.memory[section] = values end
        return values
    end
    for name, defaults in pairs(self.defaults) do
        local values = copy(defaults)
        if not self.load_error and self.handler and type(self.handler.c) == "table" then self.handler.c[name] = values
        else self.memory[name] = values end
    end
    return copy(self.defaults)
end

function Store:write()
    if self.handler_error then return false, self.handler_error end
    if self.load_error then return false, self.load_error end
    if not self.handler then return true end
    if type(self.handler.c) ~= "table" then return false, "configuration handler is not loaded" end
    self.handler.c.__version = self.version
    local previous = read_file(self.file_name)
    if valid_json(previous) then write_file(self.file_name .. ".last-good", previous) end
    local ok, result, err = pcall(function() return self.handler:write() end)
    if not ok then return false, result end
    if result == false then return false, err end
    local written = read_file(self.file_name)
    if not valid_json(written) then
        if valid_json(previous) then write_file(self.file_name, previous) end
        return false, "invalid shared configuration"
    end
    return true
end

function UI.settings(namespace, version, defaults, legacy_sources, legacy_namespaces)
    assert(type(namespace) == "string" and namespace ~= "", "namespace required")
    defaults = type(defaults) == "table" and copy(defaults) or {}
    local handler
    local handler_error
    local file_name = path("?user/config/kite.settings.json")
    if ConfigHandler then
        local payload = copy(defaults)
        payload.__version = version
        local ok, result = pcall(function()
            if type(ConfigHandler.getView) == "function" then
                return assert(ConfigHandler:getView(file_name, {namespace}, payload))
            end
            return ConfigHandler(file_name, payload, {namespace}, true)
        end)
        if ok then handler = result else handler_error = tostring(result) end
    end
    return setmetatable({
        namespace = namespace,
        version = tostring(version or "0.0.0"),
        defaults = defaults,
        legacy_sources = type(legacy_sources) == "table" and legacy_sources or {},
        legacy_namespaces = type(legacy_namespaces) == "table" and legacy_namespaces or {},
        handler = handler,
        handler_error = handler_error,
        file_name = file_name,
        loaded = false,
        memory = copy(defaults),
    }, Store)
end

local DialogHandler = {}
DialogHandler.__index = DialogHandler

local function dialog_defaults(interface, aliases)
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
    self.read_called = true
    return true
end

function DialogHandler:updateInterface(section_names)
    local names = section_names
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
    self.read_called = true
end

function DialogHandler:updateConfiguration(result, section_names)
    local names = section_names
    if names == nil then
        names = {}
        for section in pairs(self.interface) do names[#names + 1] = section end
    elseif type(names) ~= "table" then
        names = {names}
    end
    for _, section in ipairs(names) do
        local storage = self.aliases[section] or section
        local source = result
        if result and result[section] and type(section_names) == "table" then source = result[section] end
        self.configuration[section] = self.store:update(storage, source or {})
    end
    self.read_called = true
end

function DialogHandler:write()
    if not self.read_called then self:read() end
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
    self.read_called = true
    return self.store:write()
end

function UI.dialogHandler(interface, namespace, version, legacy_sources, aliases)
    aliases = aliases or {}
    local defaults = dialog_defaults(interface, aliases)
    local store = UI.settings(namespace, version, defaults, legacy_sources)
    local configuration = {}
    for section in pairs(interface or {}) do configuration[section] = copy(defaults[aliases[section] or section] or {}) end
    return setmetatable({
        interface = interface,
        defaults = defaults,
        store = store,
        aliases = aliases,
        configuration = configuration,
        fileName = path("?user/config/kite.settings.json"),
        read_called = false,
    }, DialogHandler)
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

UI.copy = copy
UI.sanitize = sanitize
UI.parseLuaTable = parse_lua_table
UI.parseKeyValue = parse_key_value

if depctrl then
    UI.version = depctrl
    return depctrl:register(UI)
end
return UI
