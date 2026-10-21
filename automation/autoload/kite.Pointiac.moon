export script_name        = "Pointiac"
export script_description = "Create first and last frame point markers from selected lines"
export script_author      = "Kiterow"
export script_version     = "1.1.7"
export script_namespace   = "kite.Pointiac"

PointPath = "m 0 4.657 b 0 2.085 2.085 0 4.657 0 7.229 0 9.314 2.085 9.314 4.657 9.314 7.229 7.229 9.314 4.657 9.314 2.085 9.314 0 7.229 0 4.657"
PointSize = 9.314
Defaults = {
  color: "#FFFFFF"
  fps: 24
  separation: 16
  layerOffset: 1
  targetWidth: 1920
  targetHeight: 1080
}

okDepctrl, DependencyControl = pcall require, "l0.DependencyControl"
depctrl = nil
if okDepctrl and DependencyControl
  okRecord, record = pcall ->
    DependencyControl{
      name: script_name
      description: script_description
      author: script_author
      version: script_version
      namespace: script_namespace
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
      {
        {"kite.UI", version: "1.5.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
        {"kite.LineOps", version: "1.7.2", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
          feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
        {"kite.Core", version: "1.1.0"}
        {"kite.Color", version: "1.2.1"}
      }
    }
  depctrl = record if okRecord

KiteUI, LineOps = nil, nil
if depctrl
  okUi, ui, lineOps = pcall -> depctrl\requireModules!
  if okUi
    KiteUI = ui
    LineOps = lineOps
KiteUI or= require "kite.UI"
LineOps or= require "kite.LineOps"
PointSettings = KiteUI.settings script_namespace, script_version, {
  main: {
    color: Defaults.color
    fps: Defaults.fps
    separation: Defaults.separation
    layer_offset: Defaults.layerOffset
  }
}, {}
PointSettings\load!

finiteNumber = require("kite.Core").finiteNumber
formatNumber = LineOps.formatNumber
normalizeColor = require("kite.Color").normalize

safeFps = (value) ->
  fps = finiteNumber(value) or Defaults.fps
  if fps > 0 then fps else Defaults.fps

frameMs = (fps) ->
  math.max 1, math.floor(1000 / safeFps(fps) + 0.5)

safeSeparation = (value) -> finiteNumber(value) or Defaults.separation

defaultPosition = (scriptResolution, separation = Defaults.separation) ->
  {
    x: (scriptResolution.x - separation - PointSize) / 2
    y: (scriptResolution.y - PointSize) / 2
  }

showMessage = (message) ->
  KiteUI.message message

showDialog = (scriptResolution) ->
  saved = PointSettings\values "main"
  pos = defaultPosition scriptResolution, safeSeparation(saved.separation)
  ui = {
    {class: "label", label: "Pointiac", x: 0, y: 0, width: 8, height: 1}
    {class: "label", label: "Color", x: 0, y: 1, width: 2, height: 1}
    {class: "color", name: "color", value: saved.color, x: 2, y: 1, width: 2, height: 2}
    {class: "label", label: "FPS*", x: 5, y: 1, width: 1, height: 1}
    {class: "floatedit", name: "fps", value: saved.fps, min: 0, x: 6, y: 1, width: 2, height: 1}
    {class: "label", label: "X/Y", x: 0, y: 3, width: 2, height: 1}
    {class: "floatedit", name: "x", value: pos.x, x: 2, y: 3, width: 2, height: 1}
    {class: "floatedit", name: "y", value: pos.y, x: 4, y: 3, width: 2, height: 1}
    {class: "label", label: "Offset X", x: 0, y: 4, width: 2, height: 1}
    {class: "floatedit", name: "separation", value: saved.separation, x: 2, y: 4, width: 2, height: 1}
    {class: "label", label: "Layer +", x: 4, y: 4, width: 2, height: 1}
    {class: "intedit", name: "layer_offset", value: saved.layer_offset, x: 6, y: 4, width: 2, height: 1}
    {class: "label", label: "* FPS is used only when video timecodes are unavailable.", x: 0, y: 5, width: 8}
    {class: "label", label: "Offset X may be positive, negative or zero.", x: 0, y: 6, width: 8}
  }
  button, res = aegisub.dialog.display ui, {"Execute", "Cancel"}, {ok: "Execute", close: "Cancel"}
  return nil if button != "Execute"
  stable = {
    color: res.color
    fps: safeFps res.fps
    separation: safeSeparation res.separation
    layer_offset: LineOps.round(finiteNumber(res.layer_offset) or Defaults.layerOffset)
  }
  PointSettings\update "main", stable
  ok, saved, err = pcall -> PointSettings\write!
  unless ok and saved
    showMessage "Could not save settings. The current values will still be used.\n" .. tostring(err or saved or "")
  {
    color: normalizeColor res.color
    fps: stable.fps
    x: finiteNumber(res.x) or pos.x
    y: finiteNumber(res.y) or pos.y
    separation: stable.separation
    layerOffset: stable.layer_offset
  }

pointText = (x, y, color) ->
  string.format "{\\an7\\pos(%s,%s)\\bord0\\shad0\\fscx100\\fscy100\\frz0\\alpha&H00&\\1c%s\\p1}%s",
    formatNumber(x),
    formatNumber(y),
    color,
    PointPath

markerTimings = (base, fps) ->
  startTime = math.max 0, finiteNumber(base.start_time) or 0
  endTime = finiteNumber(base.end_time) or startTime
  frameLength = frameMs fps
  endTime = startTime + frameLength if endTime <= startTime
  if aegisub and aegisub.frame_from_ms and aegisub.ms_from_frame
    okStart, startValue = pcall aegisub.frame_from_ms, startTime
    okLast, lastValue = pcall aegisub.frame_from_ms, math.max(startTime, endTime - 1)
    startFrame = finiteNumber startValue if okStart
    lastFrame = finiteNumber lastValue if okLast
    if startFrame and lastFrame and startFrame >= 0 and lastFrame >= startFrame
      okFirstEnd, firstEndValue = pcall aegisub.ms_from_frame, startFrame + 1
      okLastStart, lastStartValue = pcall aegisub.ms_from_frame, lastFrame
      firstBoundary = finiteNumber firstEndValue if okFirstEnd
      lastBoundary = finiteNumber lastStartValue if okLastStart
      if firstBoundary and lastBoundary and firstBoundary > startTime and lastBoundary < endTime
        return {
          firstStart: startTime
          firstEnd: math.min(endTime, firstBoundary)
          lastStart: math.max(startTime, lastBoundary)
          lastEnd: endTime
        }
  firstEnd = math.min endTime, startTime + frameLength
  firstEnd = startTime + 1 if firstEnd <= startTime
  lastStart = math.max startTime, endTime - frameLength
  lastEnd = endTime
  if lastStart >= lastEnd
    lastStart = startTime
    lastEnd = firstEnd
  {
    firstStart: startTime
    firstEnd: firstEnd
    lastStart: lastStart
    lastEnd: lastEnd
  }

pointLines = (base, opts) ->
  times = markerTimings base, opts.fps
  baseLayer = finiteNumber(base.layer) or 0
  layer = math.max 0, LineOps.round(baseLayer + opts.layerOffset)
  first = LineOps.copy base
  last = LineOps.copy base

  first.comment = false
  first.layer = layer
  first.start_time = times.firstStart
  first.end_time = times.firstEnd
  first.text = pointText opts.x, opts.y, opts.color

  last.comment = false
  last.layer = layer
  last.start_time = times.lastStart
  last.end_time = times.lastEnd
  last.text = pointText opts.x + opts.separation, opts.y, opts.color

  first, last

selectedDialogueIndices = (subs, sel) ->
  LineOps.normalizeIndices subs, sel, (line) -> line and line.class == "dialogue"

main = (subs, sel, active) ->
  targets = selectedDialogueIndices subs, sel
  if #targets == 0
    showMessage "Select at least one dialogue line."
    aegisub.cancel!
    return nil

  scriptWidth, scriptHeight = LineOps.scriptResolution subs, Defaults.targetWidth, Defaults.targetHeight
  opts = showDialog {x: scriptWidth, y: scriptHeight}
  return nil unless opts
  operations = {}
  for idx in *targets
    LineOps.checkCancelled!
    first, last = pointLines subs[idx], opts
    operations[#operations + 1] = {index: idx + 1, lines: {first, last}}
  inserted = LineOps.transaction subs, script_name, -> LineOps.insertLines subs, operations
  inserted, inserted[1] or active

validate = (subs, sel) -> #selectedDialogueIndices(subs, sel) > 0
if aegisub and aegisub.register_macro
  if depctrl and depctrl.registerMacro
    depctrl\registerMacro script_name, script_description, main, validate, nil, false
  else
    aegisub.register_macro script_name, script_description, main, validate

KiteUI.publishActions()
