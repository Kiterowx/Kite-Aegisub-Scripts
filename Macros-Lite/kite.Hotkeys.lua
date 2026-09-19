script_name = "Hotkeys"
script_description = "Shared action catalog, hotkey migration, favorites and settings"
script_author = "Kiterow"
script_version = "2.0.2"
script_namespace = "kite.Hotkeys"
local DependencyControl = require("l0.DependencyControl")
local depctrl = DependencyControl{
    name=script_name,version=script_version,description=script_description,author=script_author,namespace=script_namespace,
    url="https://github.com/Kiterowx/Kite-Aegisub-Scripts",
    feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    {{"kite.UI",version="1.5.1"}},
}
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
