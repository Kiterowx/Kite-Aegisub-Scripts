local moduleVersion = "1.5.1"
local UI = { VERSION = moduleVersion, version = moduleVersion }

local function safeRequire(name)
    local ok, value = pcall(require, name)
    if ok then return value end
    return nil
end

local Core = assert(safeRequire("kite.Core"), "kite.Core is required")
local DependencyControl = safeRequire("l0.DependencyControl")
local depctrl
if DependencyControl then
    depctrl = DependencyControl({
        name = "kite.UI",
        version = moduleVersion,
        description = "Shared Kite dialog and settings utilities",
        author = "Kiterow",
        url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
        moduleName = "kite.UI",
        feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
        {
            { "kite.Core", version = "1.1.0" },
            { "kite.Settings", version = "1.0.0" },
        },
    })
end

local copy = Core.deepCopy

local Settings = require("kite.Settings")
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

if depctrl then
    UI.version = depctrl
    return depctrl:register(UI)
end
return UI
