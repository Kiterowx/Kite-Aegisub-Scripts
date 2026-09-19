export script_name = "Selesub"
export script_description = "Filters, imports, exports, and manages subtitle events"
export script_author = "Kiterow"
export script_version = "2.1.8"
export script_namespace = "kite.Selesub"

HotkeyMenuRoot = ": Kite Hotkeys :"
EmptyValue = "<empty>"

DependencyControl = require "l0.DependencyControl"
depctrl = DependencyControl{
  feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
  {
    {"kite.UI", version: "1.5.1", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"aegisub.re"}
    {"aegisub.unicode"}
    {"myaa.ASSParser", version: "0.0.4", url: "https://github.com/TypesettingTools/Myaamori-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Myaamori-Aegisub-Scripts/master/DependencyControl.json"}
    {"kite.LineOps", version: "1.7.2", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.PyBridge", version: "1.7.1", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.Core", version: "1.1.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
  }
}
KiteUI, re, unicode, ASSParser, LineOps, PyBridge, Core = depctrl\requireModules!
unicodeLower = unicode.to_lower_case

assComments = (value) ->
  comments = {}
  for section in *LineOps.scanSections(value)
    comments[#comments + 1] = section.text if section.type == "comment"
  table.concat comments, "\n"

wordCount = (value) ->
  count = 0
  count += 1 for _ in LineOps.visibleText(value)\gmatch "%S+"
  count

characterCount = (value) ->
  count = 0
  for unit in *LineOps.graphemes(LineOps.visibleText(value), re)
    count += 1 unless unit == "—" or unit\match "^[%s%.,%?!'\"]+$"
  count

blurValue = (value) ->
  number = LineOps.tagNumber value, "blur", 0, true
  number

DirectFields = {
  {label: "Effect", key: "effect", kind: "string"}
  {label: "Actor", key: "actor", kind: "string"}
  {label: "Layer", key: "layer", kind: "number"}
  {label: "Style", key: "style", kind: "string"}
}

ManagerFields = {
  {label: "Style", key: "style", kind: "string"}
  {label: "Actor", key: "actor", kind: "string"}
  {label: "Effect", key: "effect", kind: "string"}
  {label: "Layer", key: "layer", kind: "number"}
}

ManagerByLabel = {}
ManagerLabels = {}
for field in *ManagerFields
  ManagerByLabel[field.label] = field
  ManagerLabels[#ManagerLabels + 1] = field.label

SearchFields = {
  {label: "None", kind: "none"}
  {label: "Text", kind: "text", value: (line) -> tostring(line.text or "")}
  {label: "Visible Text", kind: "text", value: (line) -> LineOps.visibleText line.text}
  {label: "ASS Comments", kind: "text", value: (line) -> assComments line.text}
  {label: "Style", kind: "text", value: (line) -> tostring(line.style or "")}
  {label: "Actor", kind: "text", value: (line) -> tostring(line.actor or "")}
  {label: "Effect", kind: "text", value: (line) -> tostring(line.effect or "")}
  {label: "Type", kind: "text", value: (line) -> if line.comment then "Comment" else "Dialogue"}
  {label: "Text+Actor+Effect", kind: "text", value: (line) ->
    table.concat {tostring(line.text or ""), tostring(line.actor or ""), tostring(line.effect or "")}, "\n"}
  {label: "Text+Actor+Effect+Style", kind: "text", value: (line) ->
    table.concat {tostring(line.text or ""), tostring(line.actor or ""), tostring(line.effect or ""), tostring(line.style or "")}, "\n"}
  {label: "Layer", kind: "number", value: (line) -> tonumber(line.layer) or 0}
  {label: "Duration", kind: "number", value: (line) ->
    (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0)}
  {label: "Word Count", kind: "number", value: (line) -> wordCount line.text}
  {label: "Character Count", kind: "number", value: (line) -> characterCount line.text}
  {label: "CPS", kind: "number", value: (line) ->
    duration = (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0)
    if duration <= 0 then 0 else math.ceil(characterCount(line.text) * 1000 / duration)}
  {label: "Blur", kind: "number", value: (line) -> blurValue line.text}
  {label: "Margin L", kind: "number", value: (line) -> tonumber(line.margin_l) or 0}
  {label: "Margin R", kind: "number", value: (line) -> tonumber(line.margin_r) or 0}
  {label: "Margin V", kind: "number", value: (line) -> tonumber(line.margin_t or line.margin_v) or 0}
  {label: "Start", kind: "time", value: (line) -> tonumber(line.start_time) or 0}
  {label: "End", kind: "time", value: (line) -> tonumber(line.end_time) or 0}
  {label: "Event Number", kind: "number", value: (_line, context) -> context.eventNo}
}

SearchByLabel = {}
SearchLabels = {}
for field in *SearchFields
  SearchByLabel[field.label] = field
  SearchLabels[#SearchLabels + 1] = field.label

TextOperators = {"Contains", "Exact", "Regex", "All Words", "Starts With"}
NumberOperators = {"=", ">=", "<=", "Range", "Nonzero <=", "Even", "Odd"}
AllOperators = {}
AllOperators[#AllOperators + 1] = item for item in *TextOperators
AllOperators[#AllOperators + 1] = item for item in *NumberOperators
Scopes = {"All", "Selection"}
Actions = {"Select", "Comment", "Delete"}
ManagerScopes = {"Selection", "All"}

isEvent = (line) ->
  type(line) == "table" and line.class == "dialogue"

rawFieldValue = (line, field) ->
  return field.value line if field.value
  value = line[field.key]
  value = line[field.altKey] if value == nil and field.altKey
  value

canonicalKey = (line, field) ->
  value = rawFieldValue line, field
  switch field.kind
    when "number"
      "n:" .. tostring(tonumber(value) or 0)
    else
      "s:" .. tostring(value or "")

displayValue = (line, field) ->
  value = rawFieldValue line, field
  switch field.kind
    when "number"
      tostring(tonumber(value) or 0)
    else
      text = tostring(value or "")
      if text == "" then EmptyValue else text

fieldEntrySorter = (field) ->
  (a, b) ->
    if field.kind == "number"
      return a.sortValue < b.sortValue if a.sortValue != b.sortValue
    else
      aLower = unicodeLower a.label
      bLower = unicodeLower b.label
      return aLower < bLower if aLower != bLower
    return a.label < b.label if a.label != b.label
    a.key < b.key

collectFieldOptions = (subs, field) ->
  entries = {}
  seen = {}
  for index = 1, #subs
    LineOps.checkCancelled!
    line = subs[index]
    if isEvent line
      key = canonicalKey line, field
      unless seen[key]
        seen[key] = true
        value = rawFieldValue line, field
        entries[#entries + 1] = {
          :key
          label: displayValue line, field
          sortValue: if field.kind == "number" then tonumber(value) or 0 else 0
        }
  table.sort entries, fieldEntrySorter field

  items = {""}
  keyByLabel = {}
  labelByKey = {}
  usedLabels = {[""]: true}
  for entry in *entries
    base = entry.label
    label = base
    suffix = 2
    while usedLabels[label]
      label = "#{base} [#{suffix}]"
      suffix += 1
    usedLabels[label] = true
    keyByLabel[label] = entry.key
    labelByKey[entry.key] = label
    items[#items + 1] = label
  {:items, :keyByLabel, :labelByKey}

collectOptions = (subs) ->
  options = {}
  options[field.key] = collectFieldOptions(subs, field) for field in *DirectFields
  options

contains = (items, value) ->
  return true for item in *items when item == value
  false

blankValues = ->
  values = {}
  values[field.key] = "" for field in *DirectFields
  values

defaultState = ->
  {
    values: blankValues!
    scope: "All"
    action: "Select"
    search_field: SearchFields[1].label
    operator: TextOperators[1]
    query: ""
    exclude: ""
    negate: false
    case_sensitive: false
    include_comments: true
    only_first: false
  }

SelectorSettings = KiteUI.settings script_namespace, script_version, {
  main: {
    scope: "All"
    action: "Select"
    search_field: SearchFields[1].label
    operator: TextOperators[1]
    negate: false
    case_sensitive: false
    include_comments: true
    only_first: false
  }
  manager: {
    nature: ManagerFields[1].label
    scope: ManagerScopes[1]
    action: Actions[1]
  }
}, {}
SelectorSettings\load!

normalizeOperator = (field, operator) ->
  if field.kind == "text"
    if contains(TextOperators, operator) then operator else TextOperators[1]
  elseif field.kind == "number" or field.kind == "time"
    if contains(NumberOperators, operator) then operator else NumberOperators[1]
  else
    TextOperators[1]

normalizeState = (incoming) ->
  source = incoming or {}
  state = defaultState!
  state.values = blankValues!
  for field in *DirectFields
    savedValue = source.values and source.values[field.key] or ""
    savedValue = savedValue[1] if type(savedValue) == "table"
    state.values[field.key] = tostring(savedValue or "")
  scope = source.scope
  action = source.action
  searchLabel = source.search_field
  state.scope = scope if contains Scopes, scope
  state.action = action if contains Actions, action
  state.search_field = searchLabel if SearchByLabel[searchLabel]
  searchField = SearchByLabel[state.search_field]
  state.operator = normalizeOperator searchField, source.operator
  state.query = tostring(source.query or "")
  state.exclude = tostring(source.exclude or "")
  state.negate = source.negate == true
  state.case_sensitive = source.case_sensitive == true
  state.include_comments = source.include_comments != false
  state.only_first = source.only_first == true
  state

initialState = ->
  state = defaultState!
  saved = SelectorSettings\values "main"
  state.scope = saved.scope
  state.action = saved.action
  state.search_field = saved.search_field
  state.operator = saved.operator
  state.negate = saved.negate
  state.case_sensitive = saved.case_sensitive
  state.include_comments = saved.include_comments
  state.only_first = saved.only_first
  normalizeState state

saveSettings = ->
  ok, written, failure = pcall -> SelectorSettings\write!
  KiteUI.message "Could not save preferences: #{if ok then failure or "write failed" else written}" if not ok or written == false

persistMain = (state) ->
  SelectorSettings\update "main", state, {
    "scope", "action", "search_field", "operator", "negate",
    "case_sensitive", "include_comments", "only_first"
  }
  saveSettings!

managerState = ->
  saved = SelectorSettings\values "manager"
  nature = saved.nature
  scope = saved.scope
  action = saved.action
  {
    nature: if ManagerByLabel[nature] then nature else ManagerFields[1].label
    scope: if contains(ManagerScopes, scope) then scope else ManagerScopes[1]
    action: if contains(Actions, action) then action else Actions[1]
  }

persistManager = (state) ->
  SelectorSettings\update "manager", state, {"nature", "scope", "action"}
  saveSettings!

showMessage = (message) ->
  KiteUI.message message

buildDialog = (state, options) ->
  gui = {}
  gui[#gui + 1] = {class: "label", label: "Scope", x: 0, y: 0, width: 5, height: 1}
  gui[#gui + 1] = {class: "label", label: "Action", x: 5, y: 0, width: 5, height: 1}
  gui[#gui + 1] = {class: "dropdown", name: "scope", items: Scopes, value: state.scope, x: 0, y: 1, width: 5}
  gui[#gui + 1] = {class: "dropdown", name: "action", items: Actions, value: state.action, x: 5, y: 1, width: 5}

  gui[#gui + 1] = {class: "label", label: "Exact", x: 0, y: 2, width: 20, height: 1}
  columns = {0, 5, 10, 15}
  for position, field in ipairs DirectFields
    x = columns[position]
    gui[#gui + 1] = {class: "label", label: field.label, :x, y: 3, width: 5, height: 1}
    selectedKey = state.values[field.key]
    value = options[field.key].labelByKey[selectedKey] or ""
    gui[#gui + 1] = {
      class: "dropdown"
      name: field.key
      items: options[field.key].items
      :value
      :x
      y: 4
      width: 5
      height: 1
    }

  gui[#gui + 1] = {class: "label", label: "Advanced", x: 0, y: 5, width: 20, height: 1}
  advancedLabels = {
    {"Field", 0, 5}
    {"Match", 5, 5}
    {"Find", 10, 5}
    {"Exclude", 15, 5}
  }
  for entry in *advancedLabels
    label, x, width = entry[1], entry[2], entry[3]
    gui[#gui + 1] = {class: "label", :label, :x, y: 6, :width, height: 1}
  gui[#gui + 1] = {class: "dropdown", name: "search_field", items: SearchLabels, value: state.search_field, x: 0, y: 7, width: 5}
  gui[#gui + 1] = {class: "dropdown", name: "operator", items: AllOperators, value: state.operator, x: 5, y: 7, width: 5}
  gui[#gui + 1] = {class: "edit", name: "query", value: state.query, x: 10, y: 7, width: 5}
  gui[#gui + 1] = {class: "edit", name: "exclude", value: state.exclude, x: 15, y: 7, width: 5}
  gui[#gui + 1] = {class: "checkbox", name: "negate", label: "Invert advanced", value: state.negate, x: 0, y: 8, width: 5}
  gui[#gui + 1] = {class: "checkbox", name: "case_sensitive", label: "Match case", value: state.case_sensitive, x: 5, y: 8, width: 5}
  gui[#gui + 1] = {class: "checkbox", name: "include_comments", label: "Include comments", value: state.include_comments, x: 10, y: 8, width: 5}
  gui[#gui + 1] = {class: "checkbox", name: "only_first", label: "First match", value: state.only_first, x: 15, y: 8, width: 5}
  gui

readState = (result, previous, options) ->
  state = normalizeState previous
  for field in *DirectFields
    label = result[field.key] or ""
    state.values[field.key] = options[field.key].keyByLabel[label] or ""
  state.scope = result.scope
  state.action = result.action
  state.search_field = result.search_field
  state.operator = result.operator
  state.query = result.query
  state.exclude = result.exclude
  state.negate = result.negate == true
  state.case_sensitive = result.case_sensitive == true
  state.include_comments = result.include_comments == true
  state.only_first = result.only_first == true
  normalizeState state

selectedCriteria = (state) ->
  criteria = {}
  activeFields = 0
  for field in *DirectFields
    key = state.values[field.key]
    if key and key != ""
      criteria[field.key] = {[key]: true}
      activeFields += 1
  criteria, activeFields

parseTime = (value) ->
  text = LineOps.trim value
  return tonumber(text) if text\match "^%d+$"

  hours, minutes, seconds, fraction = text\match "^(%d+):(%d%d):(%d%d)%.(%d+)$"
  hasHours = hours != nil
  unless hours
    minutes, seconds, fraction = text\match "^(%d+):(%d%d)%.(%d+)$"
    hours = "0" if minutes
  if hours
    return nil if (hasHours and tonumber(minutes) >= 60) or tonumber(seconds) >= 60
    milliseconds = tonumber(("0." .. fraction)) * 1000
    return ((tonumber(hours) * 60 + tonumber(minutes)) * 60 + tonumber(seconds)) * 1000 + milliseconds

  hours, minutes, seconds = text\match "^(%d+)h(%d+)m(%d+%.?%d*)s$"
  if hours
    return nil if tonumber(minutes) >= 60 or tonumber(seconds) >= 60
    return (tonumber(hours) * 3600 + tonumber(minutes) * 60 + tonumber(seconds)) * 1000
  minutes, seconds = text\match "^(%d+)m(%d+%.?%d*)s$"
  if minutes
    return nil if tonumber(seconds) >= 60
    return (tonumber(minutes) * 60 + tonumber(seconds)) * 1000
  seconds = text\match "^(%d+%.?%d*)s$"
  return tonumber(seconds) * 1000 if seconds
  nil

finiteNumber = Core.finiteNumber

parseNumber = (value, kind) ->
  raw = if kind == "time" then parseTime(value) else LineOps.trim(value)
  finiteNumber raw

parseRange = (value, kind) ->
  text = tostring(value or "")
  for position = 1, #text
    if text\sub(position, position) == "-"
      low = parseNumber text\sub(1, position - 1), kind
      high = parseNumber text\sub(position + 1), kind
      return low, high if low != nil and high != nil
  nil, nil

compileNumberMatcher = (field, state) ->
  operator = normalizeOperator field, state.operator
  if operator == "Even"
    return ((value) -> value % 2 == 0), nil
  if operator == "Odd"
    return ((value) -> value % 2 == 1), nil

  if LineOps.trim(state.query) == ""
    return nil, "Enter an advanced value."
  if operator == "Range"
    low, high = parseRange state.query, field.kind
    return nil, "Use a valid range, such as 3-8." unless low != nil and high != nil
    low, high = high, low if low > high
    return ((value) -> value >= low and value <= high), nil

  target = parseNumber state.query, field.kind
  return nil, "Invalid number or time." unless target
  matcher = switch operator
    when ">=" then (value) -> value >= target
    when "<=" then (value) -> value <= target
    when "Nonzero <=" then (value) -> value != 0 and value <= target
    else (value) -> value == target
  matcher, nil

plainContains = (haystack, needle, caseSensitive) ->
  unless caseSensitive
    haystack = unicodeLower haystack
    needle = unicodeLower needle
  haystack\find(needle, 1, true) != nil

compileTextMatcher = (operator, query, caseSensitive) ->
  if operator == "Regex"
    flags = if caseSensitive then nil else re.ICASE
    ok, regex = if flags
      pcall -> re.compile query, flags
    else
      pcall -> re.compile query
    return nil, "Invalid regular expression." unless ok and regex
    return ((value) -> regex\match(value) != nil), nil

  if operator == "All Words"
    words = [word for word in query\gmatch "%S+"]
    return ((value) ->
      for word in *words
        return false unless plainContains value, word, caseSensitive
      true), nil

  if operator == "Exact"
    return ((value) ->
      if caseSensitive then value == query else unicodeLower(value) == unicodeLower(query)), nil

  if operator == "Starts With"
    return ((value) ->
      if caseSensitive
        value\sub(1, #query) == query
      else
        unicodeLower(value)\sub(1, #unicodeLower(query)) == unicodeLower(query)), nil

  ((value) -> plainContains value, query, caseSensitive), nil

compileSearch = (state) ->
  field = SearchByLabel[state.search_field]
  return nil, nil if not field or field.kind == "none"
  operator = normalizeOperator field, state.operator

  if field.kind == "text"
    return nil, "Enter advanced text." if LineOps.trim(state.query) == ""
    includeMatcher, err = compileTextMatcher operator, state.query, state.case_sensitive
    return nil, err if err
    excludeMatcher = nil
    if state.exclude != ""
      if operator == "Regex"
        excludeMatcher, err = compileTextMatcher operator, state.exclude, state.case_sensitive
      else
        excludeMatcher = (value) -> plainContains value, state.exclude, state.case_sensitive
      return nil, err if err
    matcher = (line, context) ->
      value = tostring(field.value(line, context) or "")
      matched = includeMatcher(value) and (not excludeMatcher or not excludeMatcher(value))
      if state.negate then not matched else matched
    return matcher, nil

  numberMatcher, err = compileNumberMatcher field, state
  return nil, err if err
  matcher = (line, context) ->
    value = finiteNumber field.value(line, context)
    return false unless value
    matched = numberMatcher value
    if state.negate then not matched else matched
  matcher, nil

lineMatches = (line, criteria, state, searchMatcher, context) ->
  return false if not state.include_comments and line.comment
  for field in *DirectFields
    selected = criteria[field.key]
    return false if selected and not selected[canonicalKey(line, field)]
  return false if searchMatcher and not searchMatcher(line, context)
  true

matchingIndexes = (subs, state, criteria, searchMatcher, selection) ->
  allowed = nil
  if state.scope == "Selection"
    allowed = {}
    allowed[index] = true for index in *LineOps.normalizeIndices(subs, selection, isEvent)

  indexes = {}
  eventNo = 0
  for index = 1, #subs
    LineOps.checkCancelled!
    line = subs[index]
    if isEvent line
      eventNo += 1
      if (not allowed or allowed[index]) and lineMatches(line, criteria, state, searchMatcher, {:index, :eventNo})
        indexes[#indexes + 1] = index
        break if state.only_first
  indexes

applyComment = (subs, indexes, undoName) ->
  changes = {}
  changed = 0
  for index in *indexes
    LineOps.checkCancelled!
    line = subs[index]
    unless line.comment
      candidate = LineOps.copy line
      candidate.comment = true
      changes[#changes + 1] = {index: index, line: candidate}
      changed += 1
  if changed > 0
    LineOps.transaction subs, undoName, ->
      for change in *changes
        LineOps.checkCancelled!
        subs[change.index] = change.line
  changed

applyDelete = (subs, indexes, undoName) ->
  normalized = LineOps.normalizeIndices subs, indexes
  return 0 if #normalized == 0
  LineOps.transaction subs, undoName, ->
    LineOps.deleteIndices subs, normalized
  #normalized

managerIndexes = (subs, selection, scope) ->
  allowed = nil
  if scope == "Selection"
    allowed = {}
    allowed[index] = true for index in *LineOps.normalizeIndices(subs, selection, isEvent)
  [index for index = 1, #subs when isEvent(subs[index]) and (not allowed or allowed[index])]

collectManagerData = (subs, selection, state) ->
  field = ManagerByLabel[state.nature] or ManagerFields[1]
  groupsByKey = {}
  sourceIndexes = managerIndexes subs, selection, state.scope
  for index in *sourceIndexes
    LineOps.checkCancelled!
    line = subs[index]
    key = canonicalKey line, field
    group = groupsByKey[key]
    unless group
      value = rawFieldValue line, field
      group = {
        :key
        label: displayValue line, field
        sortValue: if field.kind == "number" then tonumber(value) or 0 else 0
        indexes: {}
        count: 0
      }
      groupsByKey[key] = group
    group.indexes[#group.indexes + 1] = index
    group.count += 1

  groups = [group for _, group in pairs groupsByKey]
  table.sort groups, fieldEntrySorter field
  keyByLabel = {}
  usedLabels = {}
  keepLines = {}
  countLines = {}
  for group in *groups
    base = group.label
    label = base
    suffix = 2
    while usedLabels[label]
      label = "#{base} [#{suffix}]"
      suffix += 1
    usedLabels[label] = true
    group.listLabel = label
    keyByLabel[label] = group.key
    keepLines[#keepLines + 1] = label
    countLines[#countLines + 1] = tostring group.count
  {
    :field
    :groups
    :keyByLabel
    :sourceIndexes
    keepText: table.concat keepLines, "\n"
    countText: table.concat countLines, "\n"
  }

buildManagerDialog = (state, data, keepText) ->
  {
    {class: "label", label: "Nature", x: 0, y: 0, width: 12, height: 1}
    {class: "label", label: "Scope", x: 12, y: 0, width: 12, height: 1}
    {class: "label", label: "Action", x: 24, y: 0, width: 12, height: 1}
    {class: "dropdown", name: "nature", items: ManagerLabels, value: state.nature, x: 0, y: 1, width: 12, height: 1}
    {class: "dropdown", name: "scope", items: ManagerScopes, value: state.scope, x: 12, y: 1, width: 12, height: 1}
    {class: "dropdown", name: "action", items: Actions, value: state.action, x: 24, y: 1, width: 12, height: 1}
    {class: "label", label: "Keep these values; the action affects omitted values. Refresh after changing Nature or Scope.", x: 0, y: 2, width: 36, height: 1}
    {class: "label", label: "Values to keep", x: 0, y: 3, width: 30, height: 1}
    {class: "label", label: "Lines", x: 30, y: 3, width: 6, height: 1}
    {class: "textbox", name: "keep", text: keepText, x: 0, y: 4, width: 30, height: 12}
    {class: "textbox", name: "counts", text: data.countText, x: 30, y: 4, width: 6, height: 12}
    {class: "label", label: "Values #{#data.groups}", x: 0, y: 16, width: 15, height: 1}
    {class: "label", label: "Lines #{#data.sourceIndexes}", x: 15, y: 16, width: 15, height: 1}
  }

parseManagerKeep = (text, data) ->
  kept = {}
  unknown = {}
  seenUnknown = {}
  for line in tostring(text or "")\gmatch "[^\r\n]+"
    label = if data.keyByLabel[line] then line else LineOps.trim line
    if label != ""
      key = data.keyByLabel[label]
      if key
        kept[key] = true
      elseif not seenUnknown[label]
        seenUnknown[label] = true
        unknown[#unknown + 1] = label
  kept, unknown

managerTargets = (data, kept) ->
  targets = {}
  keptCount = 0
  for group in *data.groups
    if kept[group.key]
      keptCount += group.count
    else
      targets[#targets + 1] = index for index in *group.indexes
  table.sort targets
  targets, keptCount

confirmManagerAction = (action, keptCount, targetCount) ->
  warning = if keptCount == 0
    "The list is empty: all #{targetCount} scoped lines will be affected."
  else
    "#{keptCount} lines will remain and #{targetCount} will be affected."
  pressed = aegisub.dialog.display {
    {
      class: "label"
      label: "#{warning}\nUse Ctrl+Z to undo."
      x: 0, y: 0, width: 36, height: 3
    }
  }, {action, "Cancel"}, close: "Cancel"
  pressed == action

confirmSelectionDelete = (targetCount) ->
  pressed = aegisub.dialog.display {
    {
      class: "label"
      label: "#{targetCount} selected lines will be deleted.\nUse Ctrl+Z to undo."
      x: 0, y: 0, width: 36, height: 3
    }
  }, {"Delete", "Cancel"}, close: "Cancel"
  pressed == "Delete"

selectionEvents = (subs, selection) ->
  LineOps.normalizeIndices subs, selection, isEvent

manageValues = (subs, selection, initialAction = nil) ->
  state = managerState!
  state.action = initialAction if contains Actions, initialAction
  keepText = nil
  buttons = {"Apply", "Current", "Refresh", "Close"}

  while true
    data = collectManagerData subs, selection, state
    shownKeep = if keepText == nil then data.keepText else keepText
    button, result = aegisub.dialog.display buildManagerDialog(state, data, shownKeep), buttons, {
      close: "Close"
    }
    return selection, false unless button == "Apply" or button == "Current" or button == "Refresh"

    nextState = {
      nature: if ManagerByLabel[result.nature] then result.nature else state.nature
      scope: if contains(ManagerScopes, result.scope) then result.scope else state.scope
      action: if contains(Actions, result.action) then result.action else state.action
    }
    changedSource = nextState.nature != state.nature or nextState.scope != state.scope
    state = nextState
    persistManager state

    if button == "Current"
      targets = selectionEvents subs, selection
      if #targets == 0
        showMessage "The selection has no subtitle lines."
      elseif state.action == "Select"
        return targets, true
      elseif state.action == "Comment"
        applyComment subs, targets, "#{script_name}: comment selection"
        return targets, true
      elseif confirmSelectionDelete #targets
        applyDelete subs, targets, "#{script_name}: delete selection"
        return {}, true
      continue

    if button == "Refresh" or changedSource
      keepText = nil
      continue

    keepText = result.keep or ""
    kept, unknown = parseManagerKeep keepText, data
    if #unknown > 0
      showMessage "Unknown values found. Refresh or restore their names."
      continue

    targets, keptCount = managerTargets data, kept
    if #targets == 0
      showMessage "No values were removed."
      continue

    switch button
      when "Apply"
        if state.action == "Select"
          return targets, true
        if state.action == "Comment" and confirmManagerAction "Comment", keptCount, #targets
          applyComment subs, targets, "#{script_name}: comment values"
          return targets, true
        if state.action == "Delete" and confirmManagerAction "Delete", keptCount, #targets
          applyDelete subs, targets, "#{script_name}: delete values"
          return {}, true

executeState = (subs, selection, state) ->
  criteria, activeFields = selectedCriteria state
  searchMatcher, err = compileSearch state
  return nil, err if err
  if activeFields == 0 and not searchMatcher
    return nil, "Choose a filter or advanced search."

  matches = matchingIndexes subs, state, criteria, searchMatcher, selection
  return nil, "No events matched." if #matches == 0

  if state.action == "Comment"
    applyComment subs, matches, "#{script_name}: comment"
    return matches, nil

  if state.action == "Delete"
    confirm = aegisub.dialog.display {
      {class: "label", label: "#{#matches} lines will be deleted. Use Ctrl+Z to undo.", x: 0, y: 0, width: 36, height: 2}
    }, {"Delete", "Cancel"}, close: "Cancel"
    return selection, nil unless confirm == "Delete"
    applyDelete subs, matches, "#{script_name}: delete"
    return {}, nil

  matches, nil

collectAssSections = (subs) ->
  scriptInfo = {}
  garbage = {}
  styles = {}
  for index = 1, #subs
    LineOps.checkCancelled!
    line = subs[index]
    if type(line) == "table"
      if line.class == "style"
        styles[#styles + 1] = LineOps.copy line
      elseif line.class == "info"
        target = if line.section == "[Aegisub Project Garbage]" then garbage else scriptInfo
        target[#target + 1] = LineOps.copy line
  scriptInfo, garbage, styles

exportAss = (subs, selection) ->
  indexes = selectionEvents subs, selection
  if #indexes == 0
    showMessage "Select subtitle lines first."
    return selection, false

  path = aegisub.dialog.save "Export ASS", "", "selection.ass", "ASS (*.ass)|*.ass", false
  return selection, false unless path and path != ""
  path ..= ".ass" unless unicodeLower(path)\match "%.ass$"

  scriptInfo, garbage, styles = collectAssSections subs
  events = [LineOps.copy(subs[index]) for index in *indexes]
  ok, failure = PyBridge.withAtomicFile path, (file) ->
    ASSParser.generate_file scriptInfo, garbage, styles, events, {}, (chunk) ->
      LineOps.checkCancelled!
      written, writeError = file\write chunk
      error writeError or "Could not write ASS output." unless written
  unless ok
    showMessage "Export failed: #{failure}"
    return selection, false
  showMessage "Exported #{#events} lines."
  selection, true

importAss = (subs, selection) ->
  path = aegisub.dialog.open "Import ASS", "", "", "ASS (*.ass)|*.ass", false, true
  return selection, false unless path and path != ""

  file, openError = io.open path, "rb"
  unless file
    showMessage "Import failed: #{openError or "unknown error"}"
    return selection, false
  ok, parsed = pcall -> ASSParser.parse_file file
  file\close!
  unless ok and type(parsed) == "table" and type(parsed.events) == "table" and type(parsed.styles) == "table"
    showMessage "Import failed: #{parsed or "invalid ASS"}"
    return selection, false
  if #parsed.events == 0
    showMessage "No events found."
    return selection, false

  stylesByKey = {}
  firstEvent = #subs + 1
  for index = 1, #subs
    LineOps.checkCancelled!
    line = subs[index]
    if line.class == "style"
      stylesByKey[unicodeLower(tostring(line.name or ""))] = tostring(line.name or "")
    elseif isEvent(line) and firstEvent == #subs + 1
      firstEvent = index

  local imported, addedStyles
  imported, addedStyles = LineOps.transaction subs, "#{script_name}: import", ->
    addedStyles = 0
    for sourceStyle in *parsed.styles
      LineOps.checkCancelled!
      name = tostring(sourceStyle.name or "")
      key = unicodeLower name
      unless stylesByKey[key]
        subs.insert firstEvent, LineOps.copy(sourceStyle)
        firstEvent += 1
        addedStyles += 1
        stylesByKey[key] = name

    insertAt = #subs + 1
    imported = {}
    for sourceLine in *parsed.events
      LineOps.checkCancelled!
      line = LineOps.copy sourceLine
      mappedStyle = stylesByKey[unicodeLower(tostring(line.style or ""))]
      line.style = mappedStyle if mappedStyle
      subs.insert insertAt, line
      imported[#imported + 1] = insertAt
      insertAt += 1
    imported, addedStyles
  showMessage "Imported #{#imported} lines and #{addedStyles} styles."
  imported, true

subtitleSelector = (subs, selection) ->
  options = collectOptions subs
  state = initialState!
  buttons = {"Run", "Values", "Import", "Export", "Cancel"}

  while true
    button, result = aegisub.dialog.display buildDialog(state, options), buttons, {
      ok: "Run"
      close: "Cancel"
    }
    return selection unless button == "Run" or button == "Values" or button == "Import" or button == "Export"
    state = readState result, state, options

    switch button
      when "Values"
        output, changed = manageValues subs, selection, state.action
        return output if changed
      when "Import"
        output, changed = importAss subs, selection
        return output if changed
      when "Export"
        output, changed = exportAss subs, selection
        return output if changed
      when "Run"
        output, err = executeState subs, selection, state
        if err
          showMessage err
        else
          persistMain state
          return output

canRun = -> true

HotkeyFields = {
  {label: "Style", key: "style"}
  {label: "Actor", key: "actor"}
  {label: "Effect", key: "effect"}
}

activeValue = (subs, active, field) ->
  line = active and subs[active] or nil
  return nil unless isEvent line
  tostring(line[field.key] or "")

selectCurrentValue = (field) ->
  (subs, selection, active) ->
    value = activeValue subs, active, field
    return selection, active unless value != nil
    matches = [index for index = 1, #subs when isEvent(subs[index]) and tostring(subs[index][field.key] or "") == value]
    matches, active

jumpCurrentValue = (field, direction) ->
  (subs, selection, active) ->
    value = activeValue subs, active, field
    return selection, active unless value != nil
    index = active + direction
    while index >= 1 and index <= #subs
      line = subs[index]
      if isEvent(line) and tostring(line[field.key] or "") == value
        return {index}, index
      index += direction
    selection, active

blockBounds = (subs, active, field) ->
  value = activeValue subs, active, field
  return nil unless value != nil
  first, last = active, active
  index = active - 1
  while index >= 1
    line = subs[index]
    break unless isEvent(line) and tostring(line[field.key] or "") == value
    first = index
    index -= 1
  index = active + 1
  while index <= #subs
    line = subs[index]
    break unless isEvent(line) and tostring(line[field.key] or "") == value
    last = index
    index += 1
  first, last

blockAction = (field, action) ->
  (subs, selection, active) ->
    first, last = blockBounds subs, active, field
    return selection, active unless first
    switch action
      when "first"
        {first}, first
      when "last"
        {last}, last
      else
        [index for index = first, last], active

untilAction = (direction) ->
  (subs, selection, active) ->
    return selection, active unless active and isEvent subs[active]
    if direction < 0
      [index for index = 1, active when isEvent subs[index]], active
    else
      [index for index = active, #subs when isEvent subs[index]], active

hotkeyPath = (section, action) ->
  "#{HotkeyMenuRoot}/#{script_name}/#{section}/#{action}"

registerMacro = (name, description, process, validate = canRun) ->
  depctrl\registerMacro name, description, process, validate, nil, false

registerMacro script_name, script_description, subtitleSelector
for field in *HotkeyFields
  section = field.label
  description = field.label\lower!
  registerMacro hotkeyPath(section, "Select All"), "Selects every line with the current #{description}.", selectCurrentValue(field)
  registerMacro hotkeyPath(section, "Previous"), "Jumps to the previous line with the same #{description}.", jumpCurrentValue(field, -1)
  registerMacro hotkeyPath(section, "Next"), "Jumps to the next line with the same #{description}.", jumpCurrentValue(field, 1)
  registerMacro hotkeyPath(section, "Block Start"), "Jumps to the start of the matching block.", blockAction(field, "first")
  registerMacro hotkeyPath(section, "Block End"), "Jumps to the end of the matching block.", blockAction(field, "last")
  registerMacro hotkeyPath(section, "Select Block"), "Selects the contiguous matching block.", blockAction(field, "select")

registerMacro hotkeyPath("Range", "To Start"), "Selects from the start through the active line.", untilAction(-1)
registerMacro hotkeyPath("Range", "To End"), "Selects from the active line through the end.", untilAction(1)

require("kite.UI").publishActions()
