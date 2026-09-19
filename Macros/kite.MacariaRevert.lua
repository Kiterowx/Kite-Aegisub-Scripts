script_name = "Macaria Revert"
script_description = "Recover base karaoke lines from selected generated events"
script_author = "Kiterow"
script_version = "1.0.2"
script_namespace = "kite.MacariaRevert"
local DependencyControl = require("l0.DependencyControl")
local depctrl = DependencyControl{
    name=script_name,version=script_version,description=script_description,author=script_author,namespace=script_namespace,
    url="https://github.com/Kiterowx/Kite-Aegisub-Scripts",
    feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    {{"kite.Timing",version="1.4.3"},{"kite.UI",version="1.5.0"}},
}
local Timing, UI = depctrl:requireModules()
depctrl:registerMacros({
    {script_name,script_description,Timing.reconstructor.run,Timing.reconstructor.canRun},
    {": Kite Hotkeys :/Macaria Revert/Reconstruct","Reconstruct with default options",Timing.reconstructor.runDirect,Timing.reconstructor.canRun},
},false)
UI.publishActions()
