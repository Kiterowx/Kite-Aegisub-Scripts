export script_name        = "Field Group Manager"
export script_description = "Group unique dialogue field values and write mapped values into another field"
export script_author      = "Kiterow"
export script_version     = "1.1.8"
export script_namespace   = "kite.FieldGroupManager"

DependencyControl = require "l0.DependencyControl"
depctrl = DependencyControl{
  feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
  {
    {"kite.UI", version: "1.5.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.LineOps", version: "1.7.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.Core", version: "1.1.0"}
  }
}
KiteUI, LineOps = depctrl\requireModules!
finiteNumber = require("kite.Core").finiteNumber

mixedMark = "<mixed>"
escapedMixedMark = "\\<mixed>"
emptyMark = "<empty>"
noGroupsMark = "<no groups>"

fields = {
  { label: "Effect",   key: "effect",     kind: "string" }
  { label: "Layer",    key: "layer",      kind: "number", min: 0 }
  { label: "Actor",    key: "actor",      kind: "string" }
  { label: "Style",    key: "style",      kind: "string" }
  { label: "Text",     key: "text",       kind: "string" }
  { label: "Start",    key: "start_time", kind: "time" }
  { label: "End",      key: "end_time",   kind: "time" }
  { label: "Margin L", key: "margin_l",   kind: "number", min: 0 }
  { label: "Margin R", key: "margin_r",   kind: "number", min: 0 }
  { label: "Margin V", key: "margin_t",   kind: "number", min: 0, altKey: "margin_v" }
  { label: "Comment",  key: "comment",    kind: "bool" }
}

fieldLabels = {}
for field in *fields
  table.insert fieldLabels, field.label

scopes = { "Selection", "Whole script" }
modes = { "Parallel list", "Single value" }
fieldSettings = KiteUI.settings script_namespace, script_version, {
  main: {
    source: "Effect"
    target: "Layer"
    scope: "Selection"
    mode: "Parallel list"
    include_comments: true
    include_empty_source: false
  }
}, {}
fieldSettings\load!

stringValue = (value) ->
  if value == nil then "" else tostring value

boolKey = (value) ->
  if value then "1" else "0"

choiceOrDefault = (value, items, defaultValue) ->
  for item in *items
    return item if value == item
  defaultValue

findField = (label) ->
  for field in *fields
    return field if field.label == label
  fields[1]

isDialogue = (line) ->
  type(line) == "table" and line.class == "dialogue"

assTime = (ms) ->
  totalCentiseconds = math.max 0, math.floor(((tonumber(ms) or 0) / 10) + 0.5)
  cs = totalCentiseconds % 100
  totalSeconds = math.floor totalCentiseconds / 100
  s = totalSeconds % 60
  totalMinutes = math.floor totalSeconds / 60
  m = totalMinutes % 60
  h = math.floor totalMinutes / 60
  string.format "%d:%02d:%02d.%02d", h, m, s, cs

parseTime = (value) ->
  text = LineOps.trim value
  return 0 if text == ""
  local parsed
  if text\match "^%d+$"
    parsed = tonumber text
  else
    h, m, seconds, cs = text\match "^(%d+):(%d%d):(%d%d)%.(%d%d)$"
    if h
      return nil, "use minutes and seconds below 60" if tonumber(m) >= 60 or tonumber(seconds) >= 60
      parsed = (((tonumber(h) * 60 + tonumber(m)) * 60 + tonumber(seconds)) * 1000) + tonumber(cs) * 10
    else
      m, seconds, cs = text\match "^(%d+):(%d%d)%.(%d%d)$"
      return nil, "use h:mm:ss.cc, mm:ss.cc, or milliseconds" unless m
      return nil, "use seconds below 60" if tonumber(seconds) >= 60
      parsed = ((tonumber(m) * 60 + tonumber(seconds)) * 1000) + tonumber(cs) * 10
  return nil, "use a finite time value" unless finiteNumber parsed
  parsed

parseBool = (value) ->
  text = LineOps.trim(value)\lower!
  return true if text == "1" or text == "true" or text == "yes" or text == "y" or text == "si" or text == "comment" or text == "commented"
  return false if text == "0" or text == "false" or text == "no" or text == "n" or text == "dialogue" or text == "dialog"
  nil, "use Comment/Dialogue, yes/no, true/false, or 1/0"

readRawField = (line, field) ->
  value = line[field.key]
  if value == nil and field.altKey
    value = line[field.altKey]
  value

fieldText = (line, field) ->
  value = readRawField line, field
  if field.kind == "time"
    assTime value
  elseif field.kind == "number"
    tostring(tonumber(value) or 0)
  elseif field.kind == "bool"
    if value then "Comment" else "Dialogue"
  else
    stringValue value

displayGroupValue = (value) ->
  if value == "" then emptyMark else value

parseTargetValue = (field, value) ->
  if field.kind == "time"
    parsed, err = parseTime value
    return nil, err unless parsed != nil
    parsed, nil
  elseif field.kind == "number"
    text = LineOps.trim value
    text = "0" if text == ""
    return nil, "use a numeric value" unless text\match "^%-?%d+$"
    number = finiteNumber text
    return nil, "use a finite numeric value" unless number
    if field.min != nil and number < field.min
      return nil, "use a value of #{field.min} or higher"
    number, nil
  elseif field.kind == "bool"
    parsed, err = parseBool value
    return nil, err unless parsed != nil
    parsed, nil
  else
    stringValue(value), nil

writeField = (line, field, value) ->
  line[field.key] = value
  if field.key == "margin_t"
    line.margin_v = value
  line

parseLines = (value) ->
  text = tostring(value or "")
  text = text\gsub "\r\n", "\n"
  text = text\gsub "\r", "\n"
  rows = {}
  pos = 1
  while true
    nextPos = text\find "\n", pos, true
    unless nextPos
      table.insert rows, text\sub(pos)
      break
    table.insert rows, text\sub(pos, nextPos - 1)
    pos = nextPos + 1
  rows

collectIndexes = (subs, sel, state) ->
  indexes = {}
  addIndex = (idx) ->
    line = subs[idx]
    if isDialogue(line) and (state.include_comments or not line.comment)
      table.insert indexes, idx

  if state.scope == "Whole script"
    for idx = 1, #subs
      addIndex idx
  else
    for idx in *LineOps.normalizeIndices(subs, sel)
      addIndex idx
  indexes

groupCompare = (field) ->
  (a, b) ->
    if field.kind == "number" or field.kind == "time"
      return (tonumber(a.sortValue) or 0) < (tonumber(b.sortValue) or 0)
    a.value < b.value

collectGroups = (subs, indexes, sourceField, state) ->
  groups = {}
  seen = {}
  for idx in *indexes
    line = subs[idx]
    source = fieldText line, sourceField
    if source != "" or state.include_empty_source
      group = seen[source]
      unless group
        group = { value: source, sortValue: readRawField(line, sourceField), indexes: {} }
        seen[source] = group
        table.insert groups, group
      table.insert group.indexes, idx
  table.sort groups, groupCompare sourceField
  groups

targetSummary = (subs, group, targetField) ->
  values = {}
  seen = {}
  for idx in *group.indexes
    value = fieldText subs[idx], targetField
    unless seen[value]
      seen[value] = true
      table.insert values, value
  if #values == 0
    "", false
  elseif #values == 1
    values[1], false
  else
    mixedMark, true

buildListTexts = (subs, groups, targetField) ->
  sourceRows = {}
  targetRows = {}
  if #groups == 0
    return noGroupsMark, ""
  for group in *groups
    table.insert sourceRows, displayGroupValue group.value
    summary = targetSummary subs, group, targetField
    table.insert targetRows, summary
  table.concat(sourceRows, "\n"), table.concat(targetRows, "\n")

stateSignature = (state) ->
  table.concat {
    state.source
    state.target
    state.scope
    boolKey state.include_comments
    boolKey state.include_empty_source
  }, "\t"

readState = (res, previous) ->
  {
    source: choiceOrDefault(res.source, fieldLabels, previous.source)
    target: choiceOrDefault(res.target, fieldLabels, previous.target)
    scope: choiceOrDefault(res.scope, scopes, previous.scope)
    mode: choiceOrDefault(res.mode, modes, previous.mode)
    include_comments: res.include_comments == true
    include_empty_source: res.include_empty_source == true
    singleValue: stringValue res.single_value
  }

showMessage = (message) ->
  KiteUI.message message

buildDialog = (state, sourceText, targetText, groupCount, lineCount) ->
  listHeight = math.max 8, math.min 20, math.max(groupCount, 1)
  listsY = 4
  singleY = listsY + listHeight + 1
  {
    { class: "label",    label: "Group by",       x: 0,  y: 0, width: 3, height: 1 }
    { class: "dropdown", name: "source",          x: 3,  y: 0, width: 5, height: 1, items: fieldLabels, value: state.source }
    { class: "label",    label: "Write field",    x: 8,  y: 0, width: 4, height: 1 }
    { class: "dropdown", name: "target",          x: 12, y: 0, width: 5, height: 1, items: fieldLabels, value: state.target }
    { class: "label",    label: "Mode",           x: 17, y: 0, width: 2, height: 1 }
    { class: "dropdown", name: "mode",            x: 19, y: 0, width: 6, height: 1, items: modes, value: state.mode }

    { class: "label",    label: "Scope",          x: 0,  y: 1, width: 3, height: 1 }
    { class: "dropdown", name: "scope",           x: 3,  y: 1, width: 5, height: 1, items: scopes, value: state.scope }
    { class: "checkbox", name: "include_comments", label: "Include comments", x: 8,  y: 1, width: 7, height: 1, value: state.include_comments }
    { class: "checkbox", name: "include_empty_source", label: "Include empty source", x: 15, y: 1, width: 8, height: 1, value: state.include_empty_source }

    { class: "label", label: "Groups: #{groupCount} / Lines: #{lineCount}", x: 0, y: 2, width: 25, height: 1 }

    { class: "label",   label: "Grouped values",       x: 0,  y: 3, width: 15, height: 1 }
    { class: "label",   label: "New values",           x: 15, y: 3, width: 15, height: 1 }
    { class: "textbox", name: "source_list", text: sourceText, x: 0,  y: listsY, width: 15, height: listHeight }
    { class: "textbox", name: "dest",        text: targetText, x: 15, y: listsY, width: 15, height: listHeight }

    { class: "label", label: "Single value", x: 0, y: singleY, width: 4, height: 1 }
    { class: "edit",  name: "single_value", value: state.singleValue, x: 4, y: singleY, width: 26, height: 1 }
    { class: "label", label: "#{mixedMark} skips mixed groups; #{escapedMixedMark} writes the literal text.", x: 0, y: singleY + 1, width: 30, height: 1 }
  }

prepareParallelTasks = (subs, groups, targetField, destText) ->
  rows = parseLines destText
  if #rows < #groups
    return nil, "The right list has fewer rows than the grouped list."
  for idx = #groups + 1, #rows
    if LineOps.trim(rows[idx]) != ""
      return nil, "The right list has extra non-empty rows."

  tasks = {}
  skipped = 0
  for idx, group in ipairs groups
    row = rows[idx]
    literalMixed = targetField.kind == "string" and row == escapedMixedMark
    row = mixedMark if literalMixed
    if row == nil
      skipped += 1
    elseif row == mixedMark and not literalMixed
      _, isMixed = targetSummary subs, group, targetField
      if isMixed
        skipped += 1
      else
        value, err = parseTargetValue targetField, row
        return nil, "Row #{idx} (#{displayGroupValue group.value}): #{err}" if err
        table.insert tasks, { group: group, value: value }
    else
      value, err = parseTargetValue targetField, row
      return nil, "Row #{idx} (#{displayGroupValue group.value}): #{err}" if err
      table.insert tasks, { group: group, value: value }
  tasks, nil, skipped

prepareSingleTasks = (groups, targetField, singleValue) ->
  value, err = parseTargetValue targetField, singleValue
  return nil, err if err
  tasks = {}
  for group in *groups
    table.insert tasks, { group: group, value: value }
  tasks, nil, 0

validateTasks = (subs, tasks, targetField) ->
  return nil unless targetField.key == "start_time" or targetField.key == "end_time"
  for task in *tasks
    for idx in *task.group.indexes
      LineOps.checkCancelled!
      line = subs[idx]
      startTime = if targetField.key == "start_time" then task.value else tonumber(line.start_time) or 0
      endTime = if targetField.key == "end_time" then task.value else tonumber(line.end_time) or 0
      if startTime > endTime
        return "Line #{idx}: start time would be after end time."
  nil

applyTasks = (subs, tasks, targetField) ->
  changes = {}
  changedLines = 0
  changedGroups = 0
  for task in *tasks
    groupChanged = false
    for idx in *task.group.indexes
      LineOps.checkCancelled!
      line = subs[idx]
      before = readRawField line, targetField
      candidate = LineOps.copy line
      writeField candidate, targetField, task.value
      after = readRawField candidate, targetField
      if after != before
        changedLines += 1
        groupChanged = true
        table.insert changes, {index: idx, line: candidate}
    changedGroups += 1 if groupChanged

  if #changes > 0
    LineOps.transaction subs, script_name, ->
      for change in *changes
        LineOps.checkCancelled!
        subs[change.index] = change.line
  changedIndices = [change.index for change in *changes]
  table.sort changedIndices
  changedGroups, changedLines, changedIndices

fieldGroupManager = (subs, sel) ->
  saved = fieldSettings\values("main") or {}
  savedScope = choiceOrDefault saved.scope, scopes, "Selection"
  state = {
    source: choiceOrDefault saved.source, fieldLabels, "Effect"
    target: choiceOrDefault saved.target, fieldLabels, "Layer"
    scope: if savedScope == "Selection" and (not sel or #sel == 0) then "Whole script" else savedScope
    mode: choiceOrDefault saved.mode, modes, "Parallel list"
    include_comments: if type(saved.include_comments) == "boolean" then saved.include_comments else true
    include_empty_source: if type(saved.include_empty_source) == "boolean" then saved.include_empty_source else false
    singleValue: ""
  }

  while true
    sourceField = findField state.source
    targetField = findField state.target
    indexes = collectIndexes subs, sel, state
    groups = collectGroups subs, indexes, sourceField, state
    sourceText, targetText = buildListTexts subs, groups, targetField
    signature = stateSignature state
    if state.dest != nil
      targetText = state.dest
    dialog = buildDialog state, sourceText, targetText, #groups, #indexes
    button, res = aegisub.dialog.display dialog, { "Execute", "Refresh list", "Cancel" }, { ok: "Execute", close: "Cancel" }
    return sel unless button == "Execute" or button == "Refresh list"

    newState = readState res, state
    if button == "Refresh list" or stateSignature(newState) != signature
      newState.dest = nil
      state = newState
      continue

    if #groups == 0
      showMessage "No grouped values were found with the current options."
      newState.dest = nil
      state = newState
      continue

    local tasks, err, skipped
    if newState.mode == "Single value"
      tasks, err, skipped = prepareSingleTasks groups, targetField, newState.singleValue
    else
      tasks, err, skipped = prepareParallelTasks subs, groups, targetField, res.dest

    if err
      showMessage err
      newState.dest = res.dest unless newState.mode == "Single value"
      state = newState
      continue

    err = validateTasks subs, tasks, targetField
    if err
      showMessage err
      newState.dest = res.dest unless newState.mode == "Single value"
      state = newState
      continue

    changedGroups, changedLines, changedIndices = applyTasks subs, tasks, targetField
    fieldSettings\update "main", newState, {"source", "target", "scope", "mode", "include_comments", "include_empty_source"}
    saved, saveError = fieldSettings\write!
    message = "Updated #{changedGroups} group(s) and #{changedLines} line(s).\nSkipped #{skipped} group(s)."
    message ..= "\nPreferences could not be saved: #{tostring saveError}" unless saved
    showMessage message
    return #changedIndices > 0 and changedIndices or sel

canRun = (subs, sel) ->
  true

if depctrl and depctrl.registerMacro
  depctrl\registerMacro script_name, script_description, fieldGroupManager, canRun, nil, false
else
  aegisub.register_macro script_name, script_description, fieldGroupManager, canRun

KiteUI.publishActions()
