export script_name = "Selesub"
export script_description = "Filters, imports, exports, and manages subtitle events"
export script_author = "Kiterow"
export script_version = "2.1.1"
export script_namespace = "kite.Selesub"

HOTKEY_MENU_ROOT = ": Kite Hotkeys :"
EMPTY_VALUE = "<empty>"

DependencyControl = require "l0.DependencyControl"
depctrl = DependencyControl{
  feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
  {
    {"kite.UI", version: "1.1.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"aegisub.re"}
    {"aegisub.unicode"}
    {"myaa.ASSParser", version: "0.0.4", url: "https://github.com/TypesettingTools/Myaamori-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Myaamori-Aegisub-Scripts/master/DependencyControl.json"}
  }
}
KiteUI, re, unicode, ASSParser = depctrl\requireModules!
unicode_lower = unicode.to_lower_case

visible_text = (value) ->
  text = tostring(value or "")
  text = text\gsub("{\\alpha&HFF&}[^{}]-{[^{}]-}", "")
  text = text\gsub("{\\alpha&HFF&}[^{}]*$", "")
  text = text\gsub("{[^}]*}", "")\gsub("\\[Nn]", " ")
  text = text\gsub "^%s+", ""
  return (text\gsub "%s+$", "")

ass_comments = (value) ->
  comments = {}
  for block in tostring(value or "")\gmatch "{([^}]*)}"
    comments[#comments + 1] = block unless block\match "^\\"
  table.concat comments, "\n"

word_count = (value) ->
  count = 0
  count += 1 for _ in visible_text(value)\gmatch "%S+"
  count

character_count = (value) ->
  text = visible_text(value)\gsub "[%s%.,%?!'\"—]", ""
  unicode.len text

blur_value = (value) ->
  tonumber(tostring(value or "")\match("\\blur([%d%.]+)")) or 0

DIRECT_FIELDS = {
  {label: "Effect", key: "effect", kind: "string"}
  {label: "Actor", key: "actor", kind: "string"}
  {label: "Layer", key: "layer", kind: "number"}
  {label: "Style", key: "style", kind: "string"}
}

MANAGER_FIELDS = {
  {label: "Style", key: "style", kind: "string"}
  {label: "Actor", key: "actor", kind: "string"}
  {label: "Effect", key: "effect", kind: "string"}
  {label: "Layer", key: "layer", kind: "number"}
}

MANAGER_BY_LABEL = {}
MANAGER_LABELS = {}
for field in *MANAGER_FIELDS
  MANAGER_BY_LABEL[field.label] = field
  MANAGER_LABELS[#MANAGER_LABELS + 1] = field.label

SEARCH_FIELDS = {
  {label: "None", kind: "none"}
  {label: "Text", kind: "text", value: (line) -> tostring(line.text or "")}
  {label: "Visible Text", kind: "text", value: (line) -> visible_text line.text}
  {label: "ASS Comments", kind: "text", value: (line) -> ass_comments line.text}
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
  {label: "Word Count", kind: "number", value: (line) -> word_count line.text}
  {label: "Character Count", kind: "number", value: (line) -> character_count line.text}
  {label: "CPS", kind: "number", value: (line) ->
    duration = (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0)
    if duration <= 0 then 0 else math.ceil(character_count(line.text) * 1000 / duration)}
  {label: "Blur", kind: "number", value: (line) -> blur_value line.text}
  {label: "Margin L", kind: "number", value: (line) -> tonumber(line.margin_l) or 0}
  {label: "Margin R", kind: "number", value: (line) -> tonumber(line.margin_r) or 0}
  {label: "Margin V", kind: "number", value: (line) -> tonumber(line.margin_t or line.margin_v) or 0}
  {label: "Start", kind: "time", value: (line) -> tonumber(line.start_time) or 0}
  {label: "End", kind: "time", value: (line) -> tonumber(line.end_time) or 0}
  {label: "Event Number", kind: "number", value: (_line, context) -> context.event_no}
}

SEARCH_BY_LABEL = {}
SEARCH_LABELS = {}
for field in *SEARCH_FIELDS
  SEARCH_BY_LABEL[field.label] = field
  SEARCH_LABELS[#SEARCH_LABELS + 1] = field.label

TEXT_OPERATORS = {"Contains", "Exact", "Regex", "All Words", "Starts With"}
NUMBER_OPERATORS = {"=", ">=", "<=", "Range", "Nonzero <=", "Even", "Odd"}
ALL_OPERATORS = {}
ALL_OPERATORS[#ALL_OPERATORS + 1] = item for item in *TEXT_OPERATORS
ALL_OPERATORS[#ALL_OPERATORS + 1] = item for item in *NUMBER_OPERATORS
SCOPES = {"All", "Selection"}
ACTIONS = {"Select", "Comment", "Delete"}
MANAGER_SCOPES = {"Selection", "All"}

is_event = (line) ->
  type(line) == "table" and (line.class == nil or line.class == "dialogue")

raw_field_value = (line, field) ->
  return field.value line if field.value
  value = line[field.key]
  value = line[field.alt_key] if value == nil and field.alt_key
  value

canonical_key = (line, field) ->
  value = raw_field_value line, field
  switch field.kind
    when "number"
      "n:" .. tostring(tonumber(value) or 0)
    else
      "s:" .. tostring(value or "")

display_value = (line, field) ->
  value = raw_field_value line, field
  switch field.kind
    when "number"
      tostring(tonumber(value) or 0)
    else
      text = tostring(value or "")
      if text == "" then EMPTY_VALUE else text

field_entry_sorter = (field) ->
  (a, b) ->
    if field.kind == "number"
      return a.sort_value < b.sort_value if a.sort_value != b.sort_value
    else
      a_lower = unicode_lower a.label
      b_lower = unicode_lower b.label
      return a_lower < b_lower if a_lower != b_lower
    return a.label < b.label if a.label != b.label
    a.key < b.key

collect_field_options = (subs, field) ->
  entries = {}
  seen = {}
  for index = 1, #subs
    line = subs[index]
    if is_event line
      key = canonical_key line, field
      unless seen[key]
        seen[key] = true
        value = raw_field_value line, field
        entries[#entries + 1] = {
          :key
          label: display_value line, field
          sort_value: if field.kind == "number" then tonumber(value) or 0 else 0
        }
  table.sort entries, field_entry_sorter field

  items = {""}
  key_by_label = {}
  label_by_key = {}
  used_labels = {[""]: true}
  for entry in *entries
    base = entry.label
    label = base
    suffix = 2
    while used_labels[label]
      label = "#{base} [#{suffix}]"
      suffix += 1
    used_labels[label] = true
    key_by_label[label] = entry.key
    label_by_key[entry.key] = label
    items[#items + 1] = label
  {:items, :key_by_label, :label_by_key}

collect_options = (subs) ->
  options = {}
  options[field.key] = collect_field_options(subs, field) for field in *DIRECT_FIELDS
  options

contains = (items, value) ->
  return true for item in *items when item == value
  false

trim = (value) ->
  text = tostring(value or "")
  text = text\gsub "^%s+", ""
  return (text\gsub "%s+$", "")

blank_values = ->
  values = {}
  values[field.key] = "" for field in *DIRECT_FIELDS
  values

default_state = ->
  {
    values: blank_values!
    scope: "All"
    action: "Select"
    search_field: SEARCH_FIELDS[1].label
    operator: TEXT_OPERATORS[1]
    query: ""
    exclude: ""
    negate: false
    case_sensitive: false
    include_comments: true
    only_first: false
  }

SELECTOR_SETTINGS = KiteUI.settings script_namespace, script_version, {
  main: {
    scope: "All"
    action: "Select"
    search_field: SEARCH_FIELDS[1].label
    operator: TEXT_OPERATORS[1]
    negate: false
    case_sensitive: false
    include_comments: true
    only_first: false
  }
  manager: {
    nature: MANAGER_FIELDS[1].label
    scope: MANAGER_SCOPES[1]
    action: ACTIONS[1]
  }
}, {}
SELECTOR_SETTINGS\load!

normalize_operator = (field, operator) ->
  if field.kind == "text"
    if contains(TEXT_OPERATORS, operator) then operator else TEXT_OPERATORS[1]
  elseif field.kind == "number" or field.kind == "time"
    if contains(NUMBER_OPERATORS, operator) then operator else NUMBER_OPERATORS[1]
  else
    TEXT_OPERATORS[1]

normalize_state = (incoming) ->
  source = incoming or {}
  state = default_state!
  state.values = blank_values!
  for field in *DIRECT_FIELDS
    saved_value = source.values and source.values[field.key] or ""
    saved_value = saved_value[1] if type(saved_value) == "table"
    state.values[field.key] = tostring(saved_value or "")
  scope = source.scope
  action = source.action
  search_label = source.search_field
  state.scope = scope if contains SCOPES, scope
  state.action = action if contains ACTIONS, action
  state.search_field = search_label if SEARCH_BY_LABEL[search_label]
  search_field = SEARCH_BY_LABEL[state.search_field]
  state.operator = normalize_operator search_field, source.operator
  state.query = tostring(source.query or "")
  state.exclude = tostring(source.exclude or "")
  state.negate = source.negate == true
  state.case_sensitive = source.case_sensitive == true
  state.include_comments = source.include_comments != false
  state.only_first = source.only_first == true
  state

initial_state = ->
  state = default_state!
  saved = SELECTOR_SETTINGS\values "main"
  state.scope = saved.scope
  state.action = saved.action
  state.search_field = saved.search_field
  state.operator = saved.operator
  state.negate = saved.negate
  state.case_sensitive = saved.case_sensitive
  state.include_comments = saved.include_comments
  state.only_first = saved.only_first
  normalize_state state

persist_main = (state) ->
  SELECTOR_SETTINGS\update "main", state, {
    "scope", "action", "search_field", "operator", "negate",
    "case_sensitive", "include_comments", "only_first"
  }
  SELECTOR_SETTINGS\write!

manager_state = ->
  saved = SELECTOR_SETTINGS\values "manager"
  nature = saved.nature
  scope = saved.scope
  action = saved.action
  {
    nature: if MANAGER_BY_LABEL[nature] then nature else MANAGER_FIELDS[1].label
    scope: if contains(MANAGER_SCOPES, scope) then scope else MANAGER_SCOPES[1]
    action: if contains(ACTIONS, action) then action else ACTIONS[1]
  }

persist_manager = (state) ->
  SELECTOR_SETTINGS\update "manager", state, {"nature", "scope", "action"}
  SELECTOR_SETTINGS\write!

show_message = (message) ->
  text = tostring message
  width = math.max 20, math.min 48, #text + 2
  aegisub.dialog.display {
    {class: "label", label: text, x: 0, y: 0, width: width, height: 2}
  }, {"OK"}, close: "OK"

build_dialog = (state, options) ->
  gui = {}
  gui[#gui + 1] = {class: "label", label: "Scope", x: 0, y: 0, width: 5, height: 1}
  gui[#gui + 1] = {class: "label", label: "Action", x: 5, y: 0, width: 5, height: 1}
  gui[#gui + 1] = {class: "dropdown", name: "scope", items: SCOPES, value: state.scope, x: 0, y: 1, width: 5}
  gui[#gui + 1] = {class: "dropdown", name: "action", items: ACTIONS, value: state.action, x: 5, y: 1, width: 5}

  gui[#gui + 1] = {class: "label", label: "Exact", x: 0, y: 2, width: 20, height: 1}
  columns = {0, 5, 10, 15}
  for position, field in ipairs DIRECT_FIELDS
    x = columns[position]
    gui[#gui + 1] = {class: "label", label: field.label, :x, y: 3, width: 5, height: 1}
    selected_key = state.values[field.key]
    value = options[field.key].label_by_key[selected_key] or ""
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
  advanced_labels = {
    {"Field", 0, 5}
    {"Match", 5, 5}
    {"Find", 10, 5}
    {"Exclude", 15, 5}
  }
  for entry in *advanced_labels
    label, x, width = entry[1], entry[2], entry[3]
    gui[#gui + 1] = {class: "label", :label, :x, y: 6, :width, height: 1}
  gui[#gui + 1] = {class: "dropdown", name: "search_field", items: SEARCH_LABELS, value: state.search_field, x: 0, y: 7, width: 5}
  gui[#gui + 1] = {class: "dropdown", name: "operator", items: ALL_OPERATORS, value: state.operator, x: 5, y: 7, width: 5}
  gui[#gui + 1] = {class: "edit", name: "query", value: state.query, x: 10, y: 7, width: 5}
  gui[#gui + 1] = {class: "edit", name: "exclude", value: state.exclude, x: 15, y: 7, width: 5}
  gui[#gui + 1] = {class: "checkbox", name: "negate", label: "Invert", value: state.negate, x: 0, y: 8, width: 5}
  gui[#gui + 1] = {class: "checkbox", name: "case_sensitive", label: "Case", value: state.case_sensitive, x: 5, y: 8, width: 5}
  gui[#gui + 1] = {class: "checkbox", name: "include_comments", label: "Comments", value: state.include_comments, x: 10, y: 8, width: 5}
  gui[#gui + 1] = {class: "checkbox", name: "only_first", label: "First", value: state.only_first, x: 15, y: 8, width: 5}
  gui

read_state = (result, previous, options) ->
  state = normalize_state previous
  for field in *DIRECT_FIELDS
    label = result[field.key] or ""
    state.values[field.key] = options[field.key].key_by_label[label] or ""
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
  normalize_state state

selected_criteria = (state) ->
  criteria = {}
  active_fields = 0
  for field in *DIRECT_FIELDS
    key = state.values[field.key]
    if key and key != ""
      criteria[field.key] = {[key]: true}
      active_fields += 1
  criteria, active_fields

parse_time = (value) ->
  text = trim value
  return tonumber(text) if text\match "^%d+$"

  hours, minutes, seconds, fraction = text\match "^(%d+):(%d%d):(%d%d)%.(%d+)$"
  unless hours
    minutes, seconds, fraction = text\match "^(%d+):(%d%d)%.(%d+)$"
    hours = "0" if minutes
  if hours
    return nil if tonumber(minutes) >= 60 or tonumber(seconds) >= 60
    milliseconds = tonumber(("0." .. fraction)) * 1000
    return ((tonumber(hours) * 60 + tonumber(minutes)) * 60 + tonumber(seconds)) * 1000 + milliseconds

  hours, minutes, seconds = text\match "^(%d+)h(%d+)m([%d%.]+)s$"
  if hours
    return (tonumber(hours) * 3600 + tonumber(minutes) * 60 + tonumber(seconds)) * 1000
  minutes, seconds = text\match "^(%d+)m([%d%.]+)s$"
  return (tonumber(minutes) * 60 + tonumber(seconds)) * 1000 if minutes
  seconds = text\match "^([%d%.]+)s$"
  return tonumber(seconds) * 1000 if seconds
  nil

parse_number = (value, kind) ->
  if kind == "time" then parse_time(value) else tonumber(trim(value))

compile_number_matcher = (field, state) ->
  operator = normalize_operator field, state.operator
  if operator == "Even"
    return ((value) -> value % 2 == 0), nil
  if operator == "Odd"
    return ((value) -> value % 2 != 0), nil

  if trim(state.query) == ""
    return nil, "Enter an advanced value."
  if operator == "Range"
    first, last = state.query\match "^%s*(.-)%s+%-%s+(.-)%s*$"
    first, last = state.query\match("^%s*([^%-]+)%-([^%-]+)%s*$") unless first
    low = first and parse_number(first, field.kind) or nil
    high = last and parse_number(last, field.kind) or nil
    return nil, "Use a valid range, such as 3-8." unless low and high
    low, high = high, low if low > high
    return ((value) -> value >= low and value <= high), nil

  target = parse_number state.query, field.kind
  return nil, "Invalid number or time." unless target
  matcher = switch operator
    when ">=" then (value) -> value >= target
    when "<=" then (value) -> value <= target
    when "Nonzero <=" then (value) -> value != 0 and value <= target
    else (value) -> value == target
  matcher, nil

plain_contains = (haystack, needle, case_sensitive) ->
  unless case_sensitive
    haystack = unicode_lower haystack
    needle = unicode_lower needle
  haystack\find(needle, 1, true) != nil

compile_text_matcher = (operator, query, case_sensitive) ->
  if operator == "Regex"
    flags = if case_sensitive then nil else re.ICASE
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
        return false unless plain_contains value, word, case_sensitive
      true), nil

  if operator == "Exact"
    return ((value) ->
      if case_sensitive then value == query else unicode_lower(value) == unicode_lower(query)), nil

  if operator == "Starts With"
    return ((value) ->
      if case_sensitive
        value\sub(1, #query) == query
      else
        unicode_lower(value)\sub(1, #unicode_lower(query)) == unicode_lower(query)), nil

  ((value) -> plain_contains value, query, case_sensitive), nil

compile_search = (state) ->
  field = SEARCH_BY_LABEL[state.search_field]
  return nil, nil if not field or field.kind == "none"
  operator = normalize_operator field, state.operator

  if field.kind == "text"
    return nil, "Enter advanced text." if trim(state.query) == ""
    include_matcher, err = compile_text_matcher operator, state.query, state.case_sensitive
    return nil, err if err
    exclude_matcher = nil
    if state.exclude != ""
      if operator == "Regex"
        exclude_matcher, err = compile_text_matcher operator, state.exclude, state.case_sensitive
      else
        exclude_matcher = (value) -> plain_contains value, state.exclude, state.case_sensitive
      return nil, err if err
    matcher = (line, context) ->
      value = tostring(field.value(line, context) or "")
      matched = include_matcher(value) and (not exclude_matcher or not exclude_matcher(value))
      if state.negate then not matched else matched
    return matcher, nil

  number_matcher, err = compile_number_matcher field, state
  return nil, err if err
  matcher = (line, context) ->
    matched = number_matcher(tonumber(field.value(line, context)) or 0)
    if state.negate then not matched else matched
  matcher, nil

line_matches = (line, criteria, state, search_matcher, context) ->
  return false if not state.include_comments and line.comment
  for field in *DIRECT_FIELDS
    selected = criteria[field.key]
    return false if selected and not selected[canonical_key(line, field)]
  return false if search_matcher and not search_matcher(line, context)
  true

matching_indexes = (subs, state, criteria, search_matcher, selection) ->
  allowed = nil
  if state.scope == "Selection"
    allowed = {}
    allowed[index] = true for index in *(selection or {})

  indexes = {}
  event_no = 0
  for index = 1, #subs
    line = subs[index]
    if is_event line
      event_no += 1
      if (not allowed or allowed[index]) and line_matches(line, criteria, state, search_matcher, {:index, :event_no})
        indexes[#indexes + 1] = index
        break if state.only_first
  indexes

apply_comment = (subs, indexes) ->
  changed = 0
  for index in *indexes
    line = subs[index]
    unless line.comment
      line.comment = true
      subs[index] = line
      changed += 1
  changed

apply_delete = (subs, indexes) ->
  for position = #indexes, 1, -1
    subs.delete indexes[position]

manager_indexes = (subs, selection, scope) ->
  allowed = nil
  if scope == "Selection"
    allowed = {}
    allowed[index] = true for index in *(selection or {})
  [index for index = 1, #subs when is_event(subs[index]) and (not allowed or allowed[index])]

collect_manager_data = (subs, selection, state) ->
  field = MANAGER_BY_LABEL[state.nature] or MANAGER_FIELDS[1]
  groups_by_key = {}
  source_indexes = manager_indexes subs, selection, state.scope
  for index in *source_indexes
    line = subs[index]
    key = canonical_key line, field
    group = groups_by_key[key]
    unless group
      value = raw_field_value line, field
      group = {
        :key
        label: display_value line, field
        sort_value: if field.kind == "number" then tonumber(value) or 0 else 0
        indexes: {}
        count: 0
      }
      groups_by_key[key] = group
    group.indexes[#group.indexes + 1] = index
    group.count += 1

  groups = [group for _, group in pairs groups_by_key]
  table.sort groups, field_entry_sorter field
  key_by_label = {}
  used_labels = {}
  keep_lines = {}
  count_lines = {}
  for group in *groups
    base = group.label
    label = base
    suffix = 2
    while used_labels[label]
      label = "#{base} [#{suffix}]"
      suffix += 1
    used_labels[label] = true
    group.list_label = label
    key_by_label[label] = group.key
    keep_lines[#keep_lines + 1] = label
    count_lines[#count_lines + 1] = tostring group.count
  {
    :field
    :groups
    :key_by_label
    :source_indexes
    keep_text: table.concat keep_lines, "\n"
    count_text: table.concat count_lines, "\n"
  }

build_manager_dialog = (state, data, keep_text) ->
  {
    {class: "label", label: "Nature", x: 0, y: 0, width: 12, height: 1}
    {class: "label", label: "Scope", x: 12, y: 0, width: 12, height: 1}
    {class: "label", label: "Action", x: 24, y: 0, width: 12, height: 1}
    {class: "dropdown", name: "nature", items: MANAGER_LABELS, value: state.nature, x: 0, y: 1, width: 12, height: 1}
    {class: "dropdown", name: "scope", items: MANAGER_SCOPES, value: state.scope, x: 12, y: 1, width: 12, height: 1}
    {class: "dropdown", name: "action", items: ACTIONS, value: state.action, x: 24, y: 1, width: 12, height: 1}
    {class: "label", label: "Targets", x: 0, y: 2, width: 36, height: 1}
    {class: "label", label: "Values", x: 0, y: 3, width: 30, height: 1}
    {class: "label", label: "Lines", x: 30, y: 3, width: 6, height: 1}
    {class: "textbox", name: "keep", text: keep_text, x: 0, y: 4, width: 30, height: 12}
    {class: "textbox", name: "counts", text: data.count_text, x: 30, y: 4, width: 6, height: 12}
    {class: "label", label: "Values #{#data.groups}", x: 0, y: 16, width: 15, height: 1}
    {class: "label", label: "Lines #{#data.source_indexes}", x: 15, y: 16, width: 15, height: 1}
  }

parse_manager_keep = (text, data) ->
  kept = {}
  unknown = {}
  seen_unknown = {}
  for line in tostring(text or "")\gmatch "[^\r\n]+"
    label = trim line
    if label != ""
      key = data.key_by_label[label]
      if key
        kept[key] = true
      elseif not seen_unknown[label]
        seen_unknown[label] = true
        unknown[#unknown + 1] = label
  kept, unknown

manager_targets = (data, kept) ->
  targets = {}
  kept_count = 0
  for group in *data.groups
    if kept[group.key]
      kept_count += group.count
    else
      targets[#targets + 1] = index for index in *group.indexes
  table.sort targets
  targets, kept_count

confirm_manager_action = (action, kept_count, target_count) ->
  warning = if kept_count == 0
    "The list is empty: all #{target_count} scoped lines will be affected."
  else
    "#{kept_count} lines will remain and #{target_count} will be affected."
  pressed = aegisub.dialog.display {
    {
      class: "label"
      label: "#{warning}\nUse Ctrl+Z to undo."
      x: 0, y: 0, width: 36, height: 3
    }
  }, {action, "Cancel"}, close: "Cancel"
  pressed == action

confirm_selection_delete = (target_count) ->
  pressed = aegisub.dialog.display {
    {
      class: "label"
      label: "#{target_count} selected lines will be deleted.\nUse Ctrl+Z to undo."
      x: 0, y: 0, width: 36, height: 3
    }
  }, {"Delete", "Cancel"}, close: "Cancel"
  pressed == "Delete"

selection_events = (subs, selection) ->
  indexes = [index for index in *(selection or {}) when is_event subs[index]]
  table.sort indexes
  indexes

manage_values = (subs, selection, initial_action = nil) ->
  state = manager_state!
  state.action = initial_action if contains ACTIONS, initial_action
  keep_text = nil
  buttons = {"Apply", "Current", "Refresh", "Close"}

  while true
    data = collect_manager_data subs, selection, state
    shown_keep = if keep_text == nil then data.keep_text else keep_text
    button, result = aegisub.dialog.display build_manager_dialog(state, data, shown_keep), buttons, {
      close: "Close"
    }
    return selection, false unless button and button != "Close"

    next_state = {
      nature: if MANAGER_BY_LABEL[result.nature] then result.nature else state.nature
      scope: if contains(MANAGER_SCOPES, result.scope) then result.scope else state.scope
      action: if contains(ACTIONS, result.action) then result.action else state.action
    }
    changed_source = next_state.nature != state.nature or next_state.scope != state.scope
    state = next_state
    persist_manager state

    if button == "Current"
      targets = selection_events subs, selection
      if #targets == 0
        show_message "The selection has no subtitle lines."
      elseif state.action == "Select"
        return targets, true
      elseif state.action == "Comment"
        changed = apply_comment subs, targets
        aegisub.set_undo_point "#{script_name}: comment selection" if changed > 0
        return targets, true
      elseif confirm_selection_delete #targets
        apply_delete subs, targets
        aegisub.set_undo_point "#{script_name}: delete selection"
        return {}, true
      continue

    if button == "Refresh" or changed_source
      keep_text = nil
      continue

    keep_text = result.keep or ""
    kept, unknown = parse_manager_keep keep_text, data
    if #unknown > 0
      show_message "Unknown values found. Refresh or restore their names."
      continue

    targets, kept_count = manager_targets data, kept
    if #targets == 0
      show_message "No values were removed."
      continue

    switch button
      when "Apply"
        if state.action == "Select"
          return targets, true
        if state.action == "Comment" and confirm_manager_action "Comment", kept_count, #targets
          changed = apply_comment subs, targets
          aegisub.set_undo_point "#{script_name}: comment values" if changed > 0
          return targets, true
        if state.action == "Delete" and confirm_manager_action "Delete", kept_count, #targets
          apply_delete subs, targets
          aegisub.set_undo_point "#{script_name}: delete values"
          return {}, true

execute_state = (subs, selection, state) ->
  criteria, active_fields = selected_criteria state
  search_matcher, err = compile_search state
  return nil, err if err
  if active_fields == 0 and not search_matcher
    return nil, "Choose a filter or advanced search."

  matches = matching_indexes subs, state, criteria, search_matcher, selection
  return nil, "No events matched." if #matches == 0

  if state.action == "Comment"
    changed = apply_comment subs, matches
    aegisub.set_undo_point "#{script_name}: comment" if changed > 0
    return matches, nil

  if state.action == "Delete"
    confirm = aegisub.dialog.display {
      {class: "label", label: "#{#matches} lines will be deleted. Use Ctrl+Z to undo.", x: 0, y: 0, width: 36, height: 2}
    }, {"Delete", "Cancel"}, close: "Cancel"
    return selection, nil unless confirm == "Delete"
    apply_delete subs, matches
    aegisub.set_undo_point "#{script_name}: delete"
    return {}, nil

  matches, nil

collect_ass_sections = (subs) ->
  script_info = {}
  garbage = {}
  styles = {}
  for index = 1, #subs
    line = subs[index]
    if type(line) == "table"
      if line.class == "style"
        styles[#styles + 1] = KiteUI.copy line
      elseif line.class == "info"
        target = if line.section == "[Aegisub Project Garbage]" then garbage else script_info
        target[#target + 1] = KiteUI.copy line
  script_info, garbage, styles

export_ass = (subs, selection) ->
  indexes = selection_events subs, selection
  if #indexes == 0
    show_message "Select subtitle lines first."
    return selection, false

  path = aegisub.dialog.save "Export ASS", "", "selection.ass", "ASS (*.ass)|*.ass", false
  return selection, false unless path and path != ""
  path ..= ".ass" unless unicode_lower(path)\match "%.ass$"

  file, open_error = io.open path, "wb"
  unless file
    show_message "Export failed: #{open_error or "unknown error"}"
    return selection, false

  script_info, garbage, styles = collect_ass_sections subs
  events = [KiteUI.copy(subs[index]) for index in *indexes]
  ok, failure = pcall ->
    ASSParser.generate_file script_info, garbage, styles, events, {}, (chunk) -> file\write chunk
  file\close!
  unless ok
    show_message "Export failed: #{failure}"
    return selection, false
  show_message "Exported #{#events} lines."
  selection, true

import_ass = (subs, selection) ->
  path = aegisub.dialog.open "Import ASS", "", "", "ASS (*.ass)|*.ass", false, true
  return selection, false unless path and path != ""

  file, open_error = io.open path, "rb"
  unless file
    show_message "Import failed: #{open_error or "unknown error"}"
    return selection, false
  ok, parsed = pcall -> ASSParser.parse_file file
  file\close!
  unless ok and parsed
    show_message "Import failed: #{parsed or "invalid ASS"}"
    return selection, false
  if #parsed.events == 0
    show_message "No events found."
    return selection, false

  styles_by_key = {}
  first_event = #subs + 1
  for index = 1, #subs
    line = subs[index]
    if line.class == "style"
      styles_by_key[unicode_lower(tostring(line.name or ""))] = tostring(line.name or "")
    elseif is_event(line) and first_event == #subs + 1
      first_event = index

  added_styles = 0
  for source_style in *parsed.styles
    name = tostring(source_style.name or "")
    key = unicode_lower name
    unless styles_by_key[key]
      subs.insert first_event, KiteUI.copy(source_style)
      first_event += 1
      added_styles += 1
      styles_by_key[key] = name

  insert_at = #subs + 1
  imported = {}
  for source_line in *parsed.events
    line = KiteUI.copy source_line
    mapped_style = styles_by_key[unicode_lower(tostring(line.style or ""))]
    line.style = mapped_style if mapped_style
    subs.insert insert_at, line
    imported[#imported + 1] = insert_at
    insert_at += 1

  aegisub.set_undo_point "#{script_name}: import"
  show_message "Imported #{#imported} lines and #{added_styles} styles."
  imported, true

subtitle_selector = (subs, selection) ->
  options = collect_options subs
  state = initial_state!
  buttons = {"Run", "Values", "Import", "Export", "Cancel"}

  while true
    button, result = aegisub.dialog.display build_dialog(state, options), buttons, {
      ok: "Run"
      close: "Cancel"
    }
    return selection unless button and button != "Cancel"
    state = read_state result, state, options

    switch button
      when "Values"
        output, changed = manage_values subs, selection, state.action
        return output if changed
      when "Import"
        output, changed = import_ass subs, selection
        return output if changed
      when "Export"
        output, changed = export_ass subs, selection
        return output if changed
      when "Run"
        output, err = execute_state subs, selection, state
        if err
          show_message err
        else
          persist_main state
          return output

can_run = -> true

HOTKEY_FIELDS = {
  {label: "Style", key: "style"}
  {label: "Actor", key: "actor"}
  {label: "Effect", key: "effect"}
}

active_value = (subs, active, field) ->
  line = active and subs[active] or nil
  return nil unless is_event line
  tostring(line[field.key] or "")

select_current_value = (field) ->
  (subs, selection, active) ->
    value = active_value subs, active, field
    return selection, active unless value != nil
    matches = [index for index = 1, #subs when is_event(subs[index]) and tostring(subs[index][field.key] or "") == value]
    matches, active

jump_current_value = (field, direction) ->
  (subs, selection, active) ->
    value = active_value subs, active, field
    return selection, active unless value != nil
    index = active + direction
    while index >= 1 and index <= #subs
      line = subs[index]
      if is_event(line) and tostring(line[field.key] or "") == value
        return {index}, index
      index += direction
    selection, active

block_bounds = (subs, active, field) ->
  value = active_value subs, active, field
  return nil unless value != nil
  first, last = active, active
  index = active - 1
  while index >= 1
    line = subs[index]
    break unless is_event(line) and tostring(line[field.key] or "") == value
    first = index
    index -= 1
  index = active + 1
  while index <= #subs
    line = subs[index]
    break unless is_event(line) and tostring(line[field.key] or "") == value
    last = index
    index += 1
  first, last

block_action = (field, action) ->
  (subs, selection, active) ->
    first, last = block_bounds subs, active, field
    return selection, active unless first
    switch action
      when "first"
        {first}, first
      when "last"
        {last}, last
      else
        [index for index = first, last], active

until_action = (direction) ->
  (subs, selection, active) ->
    return selection, active unless active and is_event subs[active]
    if direction < 0
      [index for index = 1, active when is_event subs[index]], active
    else
      [index for index = active, #subs when is_event subs[index]], active

hotkey_path = (section, action) ->
  "#{HOTKEY_MENU_ROOT}/#{script_name}/#{section}/#{action}"

register_macro = (name, description, process, validate = can_run) ->
  depctrl\registerMacro name, description, process, validate, nil, false

register_macro script_name, script_description, subtitle_selector
for field in *HOTKEY_FIELDS
  section = field.label
  description = field.label\lower!
  register_macro hotkey_path(section, "Select All"), "Selects every line with the current #{description}.", select_current_value(field)
  register_macro hotkey_path(section, "Previous"), "Jumps to the previous line with the same #{description}.", jump_current_value(field, -1)
  register_macro hotkey_path(section, "Next"), "Jumps to the next line with the same #{description}.", jump_current_value(field, 1)
  register_macro hotkey_path(section, "Block Start"), "Jumps to the start of the matching block.", block_action(field, "first")
  register_macro hotkey_path(section, "Block End"), "Jumps to the end of the matching block.", block_action(field, "last")
  register_macro hotkey_path(section, "Select Block"), "Selects the contiguous matching block.", block_action(field, "select")

register_macro hotkey_path("Range", "To Start"), "Selects from the start through the active line.", until_action(-1)
register_macro hotkey_path("Range", "To End"), "Selects from the active line through the end.", until_action(1)
