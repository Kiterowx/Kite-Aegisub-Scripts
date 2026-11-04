local function initializeScript()
script_name = "Hotkeys"
script_description = "Shared action catalog, hotkey migration, favorites and settings"
script_author = "Kiterow"
script_version = "2.0.4"
script_namespace = "kite.Hotkeys"
local DependencyControl = require("l0.DependencyControl")
local depctrl = DependencyControl{
    name=script_name,version=script_version,description=script_description,author=script_author,namespace=script_namespace,
    url="https://github.com/Kiterowx/Kite-Aegisub-Scripts",
    feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    {{"kite.UI",version="2.0.1", feed= "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}},
}
depctrl:requireModules()
local UI = depctrl:requireModules()
local manager = UI.actions.manager
local config = manager.loadConfig()
local root = UI.actions.normalizePath(config.menu_root)
depctrl:registerMacros({
    {root.."/Sync","Review and apply hotkey migrations",manager.sync},
    {root.."/Config","Manage favorites and shared settings",function() return manager.configure(UI.editSettings) end},
},false)
UI.publishActions()
return manager

end
local registrations = {}
local registerMacro = aegisub.register_macro
local function loadScript()
    registrations = {}
    aegisub.register_macro = function(name, description, callback, validate, active)
        registrations[#registrations+1] = {name, description, callback, validate, active}
    end
    local ok, message = pcall(initializeScript)
    aegisub.register_macro = registerMacro
    local available, control = pcall(require, "l0.DependencyControl")
    if available and control.updater then control.updater:releaseLock() end
    return ok, message
end
local loaded, failure = loadScript()
if loaded then
    for _, action in ipairs(registrations) do registerMacro(unpack(action)) end
else
    registerMacro(script_name, script_description, function(subs, selection, active)
        if not loaded then
            local available, control = pcall(require, "l0.DependencyControl")
            if not available then error(control, 0) end
            local loader = require("l0.DependencyControl.ModuleLoader")
            for _, task in pairs(control.updater.tasks[control.Domain.ScriptType.Module]) do
                if not task.updated and not task.running then loader.removeDummyRef(task.record) end
            end
            loaded, failure = loadScript()
            if not loaded then error(failure, 0) end
        end
        local choices, actions = {}, {}
        for _, action in ipairs(registrations) do
            if not action[4] or action[4](subs, selection, active) then
                choices[#choices+1] = action[1]
                actions[action[1]] = action[3]
            end
        end
        if #choices == 0 then return selection, active end
        if #choices == 1 then return actions[choices[1]](subs, selection, active) end
        local button, values = aegisub.dialog.display({
            {class="dropdown", name="action", items=choices, value=choices[1], x=0,y=0,width=1,height=1}
        }, {"Run","Cancel"}, {ok="Run",close="Cancel"})
        if button == "Run" then return actions[values.action](subs, selection, active) end
        return selection, active
    end)
end
