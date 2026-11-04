initializeScript = ->
  package.preload["Yutils"] = -> require "tstools.Yutils"

  export script_name = "Moka Motion"
  export script_description = "Unified Mocha motion, shape, clip, perspective and FBF track tools"
  export script_author = "Kiterow"
  export script_version = "3.8.2"
  export script_namespace = "kite.MokaMotion"

  DependencyControl = require "l0.DependencyControl"
  depctrl = DependencyControl{
    feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
    {
      {"kite.MotionEngine", version: "3.8.2", feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
      {"kite.UI", version: "2.0.1", feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    }
  }
  depctrl\requireModules!
  Core, KiteUI = depctrl\requireModules!
  for macro in *Core.macros
    depctrl\registerMacro macro[1], macro[2], macro[3], macro[4], nil, false
  KiteUI.publishActions!
  return Core

registrations = {}
registerMacro = aegisub.register_macro
loadScript = ->
  registrations = {}
  aegisub.register_macro = (name, description, callback, validate, active) ->
    registrations[#registrations + 1] = {name, description, callback, validate, active}
  ok, message = pcall initializeScript
  aegisub.register_macro = registerMacro
  available, control = pcall require, "l0.DependencyControl"
  control.updater\releaseLock! if available and control.updater
  ok, message
loaded, failure = loadScript!
if loaded
  registerMacro unpack action for action in *registrations
else
  registerMacro script_name, script_description, (subs, selection, active) ->
    unless loaded
      available, control = pcall require, "l0.DependencyControl"
      error control, 0 unless available
      loader = require "l0.DependencyControl.ModuleLoader"
      for _, task in pairs control.updater.tasks[control.Domain.ScriptType.Module]
        loader.removeDummyRef task.record unless task.updated or task.running
      loaded, failure = loadScript!
      error failure, 0 unless loaded
    choices, actions = {}, {}
    for action in *registrations
      if not action[4] or action[4] subs, selection, active
        choices[#choices + 1] = action[1]
        actions[action[1]] = action[3]
    return selection, active if #choices == 0
    return actions[choices[1]] subs, selection, active if #choices == 1
    button, values = aegisub.dialog.display {
      {class: "dropdown", name: "action", items: choices, value: choices[1], x: 0, y: 0, width: 1, height: 1}
    }, {"Run", "Cancel"}, {ok: "Run", close: "Cancel"}
    return actions[values.action] subs, selection, active if button == "Run"
    selection, active
