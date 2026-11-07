package.preload["Yutils"] = function() return require("tstools.Yutils") end

local DependencyControl = require("l0.DependencyControl")
local depctrl = DependencyControl({
    name="kite.MotionEngine", moduleName="kite.MotionEngine", version="3.9.0", author="Kiterow",
    description="Shared motion engine for Moka Motion and AutoMotion", url="https://github.com/Kiterowx/Kite-Aegisub-Scripts", feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    {
        {"tstools.Yutils", version = "1.0.0", feed = "https://raw.githubusercontent.com/TypesettingTools/Yutils/master/DependencyControl.json"},
        {"a-mo.LineCollection",version="1.3.0",feed="https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"},
        {"a-mo.Tags",version="1.3.4",feed="https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"},
        {"l0.ASSFoundation",version="0.5.0",feed="https://raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json"},
        {"arch.Math",version="0.1.10",feed="https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json"},
        {"arch.Perspective",version="1.2.1",feed="https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json"},
        {"arch.Util",version="0.1.0",feed="https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json"},
        {"ZF.main",version="2.3.0",feed="https://raw.githubusercontent.com/TypesettingTools/zeref-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.Core",version="2.0.0",feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.UI",version="2.0.1",feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.PyBridge",version="2.0.1",feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.AssContext",version="2.0.1",feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"},
        {"kite.ShapeOptimizer",version="2.0.1",feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    }
})
depctrl:requireModules()
local script_name = "Moka Motion"
local script_description = "Motion engine for Moka Motion and AutoMotion"
local script_version = "3.9.0"
local script_namespace = "kite.MokaMotion"
local LineCollection = require("a-mo.LineCollection")
local Tags = require("a-mo.Tags")
local ASS = require("l0.ASSFoundation")
local AMath = require("arch.Math")
local APersp = require("arch.Perspective")
local ArchUtil = require("arch.Util")
local ZF = require("ZF.main")
local KiteUI = require("kite.UI")
local PyBridge = require("kite.PyBridge")
local Media = require("kite.PyBridge").Media
local LineOps = require("kite.Core").LineOps
local KiteCore = require("kite.Core")
local AssContext = require("kite.AssContext")
local clipboard = require("aegisub.clipboard")
local ShiftFrameKaraoke
local FBFOptimizer = { }
local Point, Matrix
Point, Matrix = AMath.Point, AMath.Matrix
local Quad, an_xshift, an_yshift, relevantTags, usedTags, transformPoints, tagsFromQuad, prepareForPerspective
Quad, an_xshift, an_yshift, relevantTags, usedTags, transformPoints, tagsFromQuad, prepareForPerspective = APersp.Quad, APersp.an_xshift, APersp.an_yshift, APersp.relevantTags, APersp.usedTags, APersp.transformPoints, APersp.tagsFromQuad, APersp.prepareForPerspective
local Core = { }
Core.api_version = 1
Core.ApiVersion = Core.api_version
Core.VERSION = script_version
Core.version = script_version
local numericEpsilon = 0.0000001
local geometryEpsilon = 0.000001
local scaleEpsilon = 0.000000001
local singularEpsilon = 0.000000000001
local DEFAULTS = {
  sample_start = 1,
  reference_frame = 1,
  strict_sync = false,
  optimize_linear = true,
  optimize_fbf = false,
  linear_tolerance = 0.20,
  x_position = true,
  y_position = true,
  scale = true,
  rotation = true,
  origin = true,
  track_clip = true,
  border = true,
  shadow = true,
  blur = true,
  blur_scale = 1,
  absolute = false,
  rect_to_vector = true,
  rect_clip = true,
  vector_clip = true,
  output_mode = "clip",
  placement = "Replace selection",
  use_source_meta = true,
  scale_to_script = true,
  source_width = 1920,
  source_height = 1080,
  target_width = 1920,
  target_height = 1080,
  fps = 24,
  offset_x = 0,
  offset_y = 0,
  decimals = 2,
  tangent_epsilon = 0.25,
  layer_offset = 1,
  shape_tags = "\\bord0\\shad0",
  org_mode = "Force stable center",
  apply_perspective = true,
  inverse = false,
  mapping_mode = "Selection timeline",
  phase_mode = "Detect only",
  cleanup_mode = "Off",
  cleanup_window = 9,
  cleanup_degree = 2,
  cleanup_strength = 100,
  strict_geometry = false,
  refine_action = "Analyze",
  refine_method = "Local regression",
  refine_scope = "Outliers only",
  refine_threshold = 0.35,
  protect_authored = true,
  refine_frames = 4,
  target_x = 0,
  target_y = 0
}
local NUM_PATTERN = "[%+%-]?%d*%.?%d+[eE]?[%+%-]?%d*"
local trim = KiteCore.trim
local finite
finite = function(value)
  return KiteCore.finiteNumber(value) ~= nil
end
local clamp = KiteCore.clamp
local FormatNumber
FormatNumber = function(value, decimals)
  if decimals == nil then
    decimals = 2
  end
  return KiteCore.formatNumber(value, decimals)
end
local CopyTable
CopyTable = function(source)
  local out = { }
  for k, v in pairs(source or { }) do
    out[k] = v
  end
  return out
end
local CopyLine
CopyLine = function(line)
  local out = CopyTable(line)
  if type(line.extra) == "table" then
    out.extra = CopyTable(line.extra)
  end
  return out
end
local AcceptDialogueLine
AcceptDialogueLine = function(line)
  return not line.comment
end
local AcceptAllLines
AcceptAllLines = function()
  return true
end
local ParseNumbers
ParseNumbers = function(text)
  local out = { }
  for value in tostring(text or ""):gmatch(NUM_PATTERN) do
    local number = tonumber(value)
    if number then
      out[#out + 1] = number
    end
  end
  return out
end
local SplitLines
SplitLines = function(text)
  local out = { }
  text = tostring(text or ""):gsub("^\239\187\191", "")
  text = text:gsub("\r\n", "\n")
  text = text:gsub("\r", "\n")
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    out[#out + 1] = line
  end
  return out
end
local ParseMeta
ParseMeta = function(input)
  local text, result = tostring(input or ""), { }
  local fields = {
    fps = "Units Per Second",
    source_width = "Source Width",
    source_height = "Source Height",
    source_par = "Source Pixel Aspect Ratio",
    comp_par = "Comp Pixel Aspect Ratio"
  }
  for key, label in pairs(fields) do
    local value = KiteCore.finiteNumber(text:match(label .. "%s+(%S+)"))
    if value and value > 0 then
      result[key] = value
    end
  end
  return result
end
local sectionNames = {
  ["position"] = "position",
  ["scale"] = "scale",
  ["rotation"] = "rotation",
  ["z rotation"] = "rotation",
  ["anchor point"] = "anchor",
  ["opacity"] = "opacity"
}
local AE = {}
local function ChannelHeader(line)
  local label = line:lower():gsub("%s+", " "):gsub("^transform ", "")
  if sectionNames[label] then
    return sectionNames[label]
  end
  local rest = label:match("^effects (.+)$")
  if not rest then return end
  rest = rest:gsub("^adbe ", "")
  local family, property = rest:match("^(cc power pin) (.+)$")
  if not family then family, property = rest:match("^(corner pin) (.+)$") end
  if not family then return end
  local instance, field = property:match("^#(%d+) (.+)$")
  property = (field or property):gsub("^adbe ", ""):gsub(" #%d+$", "")
  local group = family .. " #" .. (instance or "1")
  local prefix = family == "corner pin" and "corner_" or "pin_"
  local id = property:match("^" .. family .. "%-(%d+)$")
  if id then return prefix .. id, group end
  local vertical, horizontal = property:match("^(%a+) (%a+)$")
  local row = ({upper = 0, top = 0, lower = 2, bottom = 2})[vertical]
  local col = ({left = 0, right = 1})[horizontal]
  if row and col then
    local first = family == "corner pin" and 1 or 2
    return prefix .. string.format("%04d", first + row + col), group
  end
  return nil, group
end
function AE.is3DHeader(line)
  local label = line:lower():gsub("%s+", " "):gsub("^transform ", "")
  return label == "x rotation" or label == "y rotation" or label == "orientation"
end
function AE.inventory(text)
  local groups, seen = {}, {}
  local hasTransform, exports, hasLayerGeometry = false, 0, false
  for _, line in ipairs(SplitLines(text)) do
    local stripped = trim(line)
    if stripped:match("^Adobe After Effects") then exports = exports + 1 end
    local name, group = ChannelHeader(stripped)
    if group and not seen[group] then
      groups[#groups + 1], seen[group] = group, true
    elseif name == "position" or name == "scale" or name == "rotation" then
      hasTransform = true
    elseif name == "anchor" or AE.is3DHeader(stripped) then
      hasLayerGeometry = true
    end
  end
  return groups, hasTransform, exports, hasLayerGeometry
end
local AddRow
AddRow = function(section, frame, values, line_number)
  if not (finite(frame) and frame == math.floor(frame) and frame + 1 > frame and frame - 1 < frame) then
    return nil, "Non-finite or non-integer frame on line " .. tostring(line_number) .. ": " .. tostring(frame)
  end
  if section.by_frame[frame] then
    return nil, "Duplicate frame " .. tostring(frame) .. " in " .. tostring(section.name) .. " (line " .. tostring(line_number) .. "). Keep one value for this frame or export a single layer."
  end
  local row = {
    frame = frame,
    values = values,
    line_number = line_number
  }
  section.by_frame[frame] = row
  section.rows[#section.rows + 1] = row
  return true
end
local function ReadChannelRow(section, text, line, recover)
  local frameText, rest = text:match("^(%S+)%s*(.*)$")
  local frame = KiteCore.finiteNumber(frameText)
  if not (frame and frame == math.floor(frame) and frame + 1 > frame and frame - 1 < frame) then
    return nil, "Invalid source frame on line " .. line .. ". Correct the frame number or copy the channel again."
  end
  local values, problem = {}, nil
  for token in rest:gmatch("%S+") do
    local number = KiteCore.finiteNumber(token)
    if not number then
      problem = "Invalid numeric value on line " .. line .. ": " .. token
      break
    end
    values[#values + 1] = number
  end
  local pinNumber = tonumber(section.name:match("^pin_(%d+)$"))
  local cornerNumber = tonumber(section.name:match("^corner_(%d+)$"))
  local pair = section.name == "position" or section.name == "anchor" or
    (pinNumber and pinNumber >= 2 and pinNumber <= 5) or (cornerNumber and cornerNumber >= 1 and cornerNumber <= 4)
  if text:find("\t *\t") or #values < (pair and 2 or 1) then
    problem = problem or ("Missing channel values on line " .. line .. ".")
  end
  if problem then
    if not recover then return nil, problem end
    section.damaged = section.damaged or {}
    section.damaged[frame] = true
    return true
  end
  local previous = section.by_frame[frame]
  if recover and previous and #previous.values == #values then
    local identical = true
    for i, value in ipairs(values) do
      if previous.values[i] ~= value then identical = false end
    end
    if identical then return true end
  end
  return AddRow(section, frame, values, line)
end
local ParseKeyframeSections
ParseKeyframeSections = function(input, scope, selectedGroup, recover)
  local sections, diagnostics, unknown = {}, {}, {}
  local current
  for line, raw in ipairs(SplitLines(input)) do
    local stripped = trim(raw)
    local name, group = ChannelHeader(stripped)
    if name or group then
      current = nil
      local selected = scope == nil or (scope == "pin" and group == selectedGroup) or
        ((scope == "transform" or scope == "geometry") and not group and not (scope == "geometry" and name == "opacity"))
      if name and selected then
        sections[name] = sections[name] or {name = name, rows = {}, by_frame = {}}
        current = sections[name]
      elseif not name and selected and not unknown[stripped] then
        unknown[stripped] = true
        diagnostics[#diagnostics + 1] = "Unrecognized AE channel/section: " .. stripped .. "."
      end
    elseif current and stripped:match("^[%+%-]?[%d%.]") then
      local ok, err = ReadChannelRow(current, stripped, line, recover)
      if not ok then return nil, err end
    elseif current and raw:match("^%s+") and stripped:match("^%S+%s+[%+%-]?[%d%.]") then
      return nil, "Invalid source frame on line " .. line .. ". Correct the frame number or copy the channel again."
    elseif stripped ~= "" and not raw:match("^%s+") then
      local lower = stripped:lower()
      if not (lower == "end of keyframe data" or lower:match("^adobe after effects") or lower:match("^units per second")
          or lower:match("^source ") or lower:match("^comp pixel aspect ratio") or lower:match("^frame%s"))
          and not unknown[stripped] and (lower:match("^effects%s+") or lower:match("^[%a][%a%s]+$")) then
        unknown[stripped] = true
        diagnostics[#diagnostics + 1] = "Unrecognized AE channel/section: " .. stripped .. "."
      end
      if not lower:match("^frame%s") then current = nil end
    end
  end
  for _, section in pairs(sections) do
    if section.damaged then
      local count = 0
      for _ in pairs(section.damaged) do count = count + 1 end
      diagnostics[#diagnostics + 1] = section.name .. " has " .. count .. " frame(s) with unreadable values."
    end
    table.sort(section.rows, function(a, b)
      return a.frame < b.frame
    end)
  end
  return sections, nil, diagnostics
end
local RequireSectionArity
RequireSectionArity = function(section, count, label)
  if not (section) then
    return true
  end
  if #section.rows == 0 then
    return nil, label .. " has a header but no samples. Restore its values or remove the empty channel."
  end
  local _list_0 = section.rows
  for _index_0 = 1, #_list_0 do
    local row = _list_0[_index_0]
    if #row.values < count then
      return nil, tostring(label) .. ", frame " .. tostring(row.frame) .. ": expected " .. tostring(count) .. " values, received " .. tostring(#row.values) .. "."
    end
    for i = 1, count do
      if not (finite(row.values[i])) then
        return nil, tostring(label) .. ", frame " .. tostring(row.frame) .. ": value " .. tostring(i) .. " is not finite."
      end
    end
  end
  return true
end
local AllFrames
AllFrames = function(sections, names)
  local seen, out = { }, { }
  for _index_0 = 1, #names do
    local name = names[_index_0]
    local section = sections[name]
    if section then
      for frame in pairs(section.damaged or {}) do
        if not seen[frame] then seen[frame], out[#out + 1] = true, frame end
      end
      local _list_0 = section.rows
      for _index_1 = 1, #_list_0 do
        local row = _list_0[_index_1]
        if not (seen[row.frame]) then
          seen[row.frame] = true
          out[#out + 1] = row.frame
        end
      end
    end
  end
  table.sort(out)
  return out
end
function AE.checkSpan(first, last, observations)
  local count = last - first + 1
  if count - observations > math.max(65536, observations * 16) then
    return nil, "Source frames " .. first .. ".." .. last .. " would expand to " .. count .. " samples. Check for a mistyped frame number or export a shorter range."
  end
  return true
end
local InterpolatedValues
InterpolatedValues = function(section, frame, defaults)
  if not (section and #section.rows > 0) then
    return CopyTable(defaults), false
  end
  local exact = section.by_frame[frame]
  if exact then
    return exact.values, false
  end
  local low, high = 1, #section.rows + 1
  while low < high do
    local middle = math.floor((low + high) / 2)
    if section.rows[middle].frame < frame then
      low = middle + 1
    else
      high = middle
    end
  end
  local before, after = section.rows[low - 1], section.rows[low]
  if not (before and after) then
    return (before or after).values, true
  end
  local k = (frame - before.frame) / (after.frame - before.frame)
  local count = math.max(#before.values, #after.values, #defaults)
  local values = { }
  for i = 1, count do
    local a = before.values[i] or defaults[i] or 0
    local b = after.values[i] or defaults[i] or a
    values[i] = a + (b - a) * k
  end
  return values, true
end
local UnwrapAngles
UnwrapAngles = function(values)
  local out = { }
  if #values == 0 then
    return out
  end
  out[1] = values[1]
  for i = 2, #values do
    LineOps.checkCancelled()
    local value, previous = values[i], out[i - 1]
    local delta = value - previous
    if delta > 180 then
      value = value - (math.ceil((delta - 180) / 360) * 360)
    elseif delta < -180 then
      value = value + (math.ceil((-180 - delta) / 360) * 360)
    end
    out[i] = value
  end
  return out
end
local UnwrapRotationSection
UnwrapRotationSection = function(section)
  if not (section) then
    return nil
  end
  local out = {
    name = section.name,
    rows = { },
    by_frame = { }
  }
  local diagnostics = { }
  local cumulative = false
  local _list_0 = section.rows
  for _index_0 = 1, #_list_0 do
    local row = _list_0[_index_0]
    local value = row.values[1] or 0
    if value < -180 or value > 360 then
      cumulative = true
      break
    end
  end
  local offset, previousRaw = 0, nil
  for i, row in ipairs(section.rows) do
    local rawAngle = row.values[1] or 0
    local angle = rawAngle
    if not cumulative and previousRaw ~= nil then
      local delta = rawAngle - previousRaw
      local turns = math.floor(math.abs(delta) / 360 + 0.5)
      local explicitTurn = turns >= 1 and math.abs(math.abs(delta) - turns * 360) <= geometryEpsilon
      if previousRaw >= 135 and rawAngle <= -135 then
        offset = offset + 360
      elseif previousRaw <= -135 and rawAngle >= 135 then
        offset = offset - 360
      elseif previousRaw >= 315 and rawAngle <= 45 then
        offset = offset + 360
      elseif not explicitTurn and math.abs(delta) > 180 then
        diagnostics[#diagnostics + 1] = "Rotation " .. tostring(row.frame) .. ": ambiguous " .. tostring(FormatNumber(delta, 3)) .. " degree jump preserved without shortest-path wrapping."
        out.ambiguous = out.ambiguous or { }
        out.ambiguous[row.frame] = delta
      end
      angle = rawAngle + offset
    end
    local values
    do
      local _accum_0 = { }
      local _len_0 = 1
      local _list_1 = row.values
      for _index_0 = 1, #_list_1 do
        local value = _list_1[_index_0]
        _accum_0[_len_0] = value
        _len_0 = _len_0 + 1
      end
      values = _accum_0
    end
    values[1] = angle
    local copy = {
      frame = row.frame,
      values = values,
      line_number = row.line_number
    }
    out.rows[i] = copy
    out.by_frame[copy.frame] = copy
    previousRaw = rawAngle
  end
  if cumulative then
    diagnostics[#diagnostics + 1] = "Cumulative rotation detected; complete revolutions are preserved."
  end
  return out, diagnostics
end
local ParseTransformData
ParseTransformData = function(input, geometry, recover)
  local sections, err, parseDiagnostics = ParseKeyframeSections(input, geometry and "geometry" or "transform", nil, recover)
  if not (sections) then
    return nil, err
  end
  if geometry then
    for _, line in ipairs(SplitLines(input)) do
      if AE.is3DHeader(trim(line)) then
        return nil, "3D orientation requires a projected four-corner export. Export After Effects Corner Pin from Mocha."
      end
    end
  end
  local defaultsUsed = {}
  if recover then
    local defaults = {position = "source center for Position", scale = "100% Scale", rotation = "zero Rotation"}
    if geometry then defaults.anchor = "layer center for Anchor Point" end
    for _, name in ipairs({"position", "scale", "rotation", "anchor", "opacity"}) do
      if sections[name] and #sections[name].rows == 0 then
        if defaults[name] then defaultsUsed[#defaultsUsed + 1] = defaults[name] end
        sections[name] = nil
      end
    end
  end
  local recovery
  if #defaultsUsed > 0 then
    recovery = "Empty tracking channels. Use " .. table.concat(defaultsUsed, ", ") .. "."
  end
  if not (sections.position or sections.scale or sections.rotation or (geometry and sections.anchor)) then
    return nil, "Include at least one Position, Scale or Rotation channel with samples. Export After Effects Transform Data from Mocha."
  end
  local _list_0 = {
    {
      sections.position,
      2,
      "Position"
    },
    {
      sections.scale,
      1,
      "Scale"
    },
    {
      sections.rotation,
      1,
      "Rotation"
    },
    {
      sections.anchor,
      2,
      "Anchor Point"
    },
    {
      sections.opacity,
      1,
      "Opacity"
    }
  }
  for _index_0 = 1, #_list_0 do
    local check = _list_0[_index_0]
    local ok
    ok, err = RequireSectionArity(check[1], check[2], check[3])
    if not (ok) then
      return nil, err
    end
  end
  if geometry then
    for _, name in ipairs({"position", "anchor"}) do
      for _, row in ipairs(sections[name] and sections[name].rows or {}) do
        if (row.values[3] or 0) ~= 0 then
          return nil, "3D layer coordinates require a projected four-corner export. Export After Effects Corner Pin from Mocha."
        end
      end
    end
  end
  local uniform_scale_rows = 0
  if sections.scale then
    local _list_1 = sections.scale.rows
    for _index_0 = 1, #_list_1 do
      local row = _list_1[_index_0]
      if row.values[2] == nil then
        row.values[2] = row.values[1]
        uniform_scale_rows = uniform_scale_rows + 1
      end
    end
  end
  local meta = ParseMeta(input)
  local frames = AllFrames(sections, {
    "position",
    "scale",
    "rotation",
    "anchor",
    "opacity"
  })
  if #frames == 0 then
    return nil, "The tracking sections contain no numeric samples."
  end
  local first_frame, last_frame = frames[1], frames[#frames]
  local withinSpan, spanError = AE.checkSpan(first_frame, last_frame, #frames)
  if not withinSpan then return nil, spanError end
  local diagnostics, samples, had_gap = { }, { }, recovery ~= nil
  if recovery then diagnostics[#diagnostics + 1] = recovery end
  local _list_1 = parseDiagnostics or { }
  for _index_0 = 1, #_list_1 do
    local item = _list_1[_index_0]
    diagnostics[#diagnostics + 1] = item
  end
  if uniform_scale_rows > 0 then
    diagnostics[#diagnostics + 1] = tostring(uniform_scale_rows) .. " uniform Scale rows were expanded to X/Y."
  end
  local rotation_section, rotationDiagnostics = UnwrapRotationSection(sections.rotation)
  local _list_2 = rotationDiagnostics or { }
  for _index_0 = 1, #_list_2 do
    local item = _list_2[_index_0]
    diagnostics[#diagnostics + 1] = item
  end
  local defaultX = (meta.source_width or 0) / 2
  local defaultY = (meta.source_height or 0) / 2
  if not (sections.position) then
    diagnostics[#diagnostics + 1] = "Position is missing; the source center is used as the pivot."
  end
  for frame = first_frame, last_frame do
    LineOps.checkCancelled()
    local position, posGap = InterpolatedValues(sections.position, frame, {
      defaultX,
      defaultY,
      0
    })
    local scale, scaleGap = InterpolatedValues(sections.scale, frame, {
      100,
      100,
      100
    })
    local rotation, rotGap = InterpolatedValues(rotation_section, frame, {
      0
    })
    local anchor, anchorGap = InterpolatedValues(sections.anchor, frame, {
      0,
      0,
      0
    })
    local opacity, opacityGap = InterpolatedValues(sections.opacity, frame, {
      100
    })
    local gaps = { }
    if sections.position and posGap then
      gaps[#gaps + 1] = "Position"
    end
    if sections.scale and scaleGap then
      gaps[#gaps + 1] = "Scale"
    end
    if sections.rotation and rotGap then
      gaps[#gaps + 1] = "Rotation"
    end
    if sections.anchor and anchorGap then
      gaps[#gaps + 1] = "Anchor Point"
    end
    if sections.opacity and opacityGap then
      gaps[#gaps + 1] = "Opacity"
    end
    if #gaps > 0 then
      diagnostics[#diagnostics + 1] = "Frame " .. tostring(frame) .. " was interpolated in " .. tostring(table.concat(gaps, ', ')) .. "."
    end
    if #gaps > 0 then
      had_gap = true
    end
    samples[#samples + 1] = {
      source_frame = frame,
      position = {
        x = position[1] or 0,
        y = position[2] or 0
      },
      scale = {
        x = scale[1] or 100,
        y = scale[2] or scale[1] or 100
      },
      rotation = -(rotation[1] or 0),
      ambiguous_rotation = rotation_section and rotation_section.ambiguous and rotation_section.ambiguous[frame] or nil,
      anchor = {
        x = anchor[1] or 0,
        y = anchor[2] or 0
      },
      opacity = opacity[1] or 100,
      interpolated = recovery ~= nil or #gaps > 0
    }
  end
  local ambiguous_rotation = rotation_section and rotation_section.ambiguous and next(rotation_section.ambiguous) ~= nil
  if ambiguous_rotation then
    diagnostics[#diagnostics + 1] = "Ambiguous Rotation jumps were detected; strict synchronization can reject them to avoid unintended revolutions."
  end
  if sections.anchor then
    diagnostics[#diagnostics + 1] = "Anchor Point was detected; it is retained for diagnostics and is not applied twice."
  end
  if sections.opacity then
    diagnostics[#diagnostics + 1] = "Opacity was detected; it does not change ASS geometry."
  end
  return {
    kind = "transform",
    format = "Adobe After Effects Transform Data",
    meta = meta,
    samples = samples,
    diagnostics = diagnostics,
    first_frame = first_frame,
    last_frame = last_frame,
    has_interpolation = had_gap,
    recovery = recovery,
    has_ambiguous_rotation = ambiguous_rotation,
    channels = {
      position = sections.position ~= nil,
      scale = sections.scale ~= nil,
      rotation = sections.rotation ~= nil,
      anchor = sections.anchor ~= nil,
      opacity = sections.opacity ~= nil
    }
  }
end
function AE.project(quad, sample, channels, meta)
  local anchorX = channels.anchor and sample.anchor.x or meta.source_width / 2
  local anchorY = channels.anchor and sample.anchor.y or meta.source_height / 2
  local angle = math.rad(-sample.rotation)
  local cos, sin = math.cos(angle), math.sin(angle)
  local sourcePAR, compPAR = meta.source_par or 1, meta.comp_par or 1
  for _, point in ipairs(quad) do
    local x = (point.x - anchorX) * sample.scale.x / 100 * sourcePAR
    local y = (point.y - anchorY) * sample.scale.y / 100
    point.x = sample.position.x + (x * cos - y * sin) / compPAR
    point.y = sample.position.y + x * sin + y * cos
  end
end
function AE.similarityQuad(first, second, par)
  local dx, dy = 1, 0
  if second then dx, dy = second.x - first.x, second.y - first.y end
  local right = {x = first.x + dx, y = first.y + dy}
  local lower = {x = first.x - dy / par, y = first.y + dx * par}
  return {first, right, {x = lower.x + dx, y = lower.y + dy}, lower}
end
local ParsePowerPinData
ParsePowerPinData = function(input, recover, selectedGroup, groups, hasTransform)
  if not groups then
    local found, motion, _, geometry = AE.inventory(input)
    groups, hasTransform = found, motion or geometry
  end
  if #groups > 1 and not selectedGroup then
    return nil, "Multiple Corner Pin effects were found. Choose one effect or export a single tracked layer."
  end
  selectedGroup = selectedGroup or groups[1]
  local sections, err, parseDiagnostics = ParseKeyframeSections(input, "pin", selectedGroup, recover)
  if not sections then return nil, err end
  local order, format
  if selectedGroup and selectedGroup:match("^cc power pin") then
    order = {"pin_0002", "pin_0003", "pin_0005", "pin_0004"}
    format = "After Effects CC Power Pin"
  else
    order = {"corner_0001", "corner_0002", "corner_0004", "corner_0003"}
    format = "After Effects Corner Pin"
  end
  local missing, known = {}, {}
  for i, name in ipairs(order) do
    if not sections[name] or #sections[name].rows == 0 then
      missing[#missing + 1] = i
    else
      local ok, message = RequireSectionArity(sections[name], 2, name)
      if not ok then return nil, message end
      known[#known + 1] = i
    end
  end
  local estimated = missing[1]
  local recovery
  if estimated then
    local labels = {"upper left", "upper right", "lower right", "lower left"}
    if #known == 0 or not recover then
      return nil, "Incomplete Power Pin data: " .. order[estimated] .. " is missing. " ..
        (#missing == 1 and "Apply Power Pin can estimate the " .. labels[estimated] .. " corner from the other three." or
        "Only " .. (4 - #missing) .. " corners have samples. Export all four corners from Mocha." ..
        (hasTransform and " Apply Motion can use the Transform channels in this export." or ""))
    end
    if #known == 3 then
      recovery = "Estimate the " .. labels[estimated] .. " corner from the other three as a parallelogram. Perspective convergence on that corner is unknown."
    elseif #known == 2 then
      recovery = "Two corners have samples. Use their translation, rotation and uniform scale. Perspective convergence is unknown."
    else
      recovery = "One corner has samples. Follow its translation. Rotation, scale and perspective from the corners are unknown."
    end
  end
  local frames = AllFrames(sections, order)
  local first_frame, last_frame = frames[1], frames[#frames]
  local meta = ParseMeta(input)
  local transform
  if hasTransform then
    transform, err = ParseTransformData(input, true, recover)
    if not transform then return nil, err end
    if not (transform.channels.anchor and transform.channels.position) and not (meta.source_width and meta.source_height) then
      return nil, "Mixed Corner Pin needs source width and height for the default layer center. Include the AE header or export standard Corner Pin from Mocha."
    end
    if transform.recovery then recovery = recovery and (recovery .. "\n" .. transform.recovery) or transform.recovery end
    format = format .. " + Transform"
    first_frame = math.min(first_frame, transform.first_frame)
    last_frame = math.max(last_frame, transform.last_frame)
  end
  local withinSpan, spanError = AE.checkSpan(first_frame, last_frame, #frames + (transform and #transform.samples or 0))
  if not withinSpan then return nil, spanError end
  local samples, diagnostics = { }, { }
  local _list_0 = parseDiagnostics or { }
  for _index_0 = 1, #_list_0 do
    local item = _list_0[_index_0]
    diagnostics[#diagnostics + 1] = item
  end
  local used
  do
    local _tbl_0 = { }
    for _index_0 = 1, #order do
      local name = order[_index_0]
      _tbl_0[name] = true
    end
    used = _tbl_0
  end
  for name in pairs(sections) do
    if (name:match("^pin_") or name:match("^corner_")) and not used[name] then
      diagnostics[#diagnostics + 1] = "Additional parameter " .. tostring(name) .. " was detected; it is reported but not applied to ASS."
    end
  end
  local hadGap = false
  if recovery then diagnostics[#diagnostics + 1] = recovery end
  for frame = first_frame, last_frame do
    LineOps.checkCancelled()
    local quad, gaps = {}, {}
    for _, i in ipairs(known) do
      local name = order[i]
      local values, gap = InterpolatedValues(sections[name], frame, {})
      quad[i] = {x = values[1], y = values[2]}
      if gap then gaps[#gaps + 1] = name end
    end
    if #known < 3 then
      quad = AE.similarityQuad(quad[known[1]], quad[known[2]], meta.source_par or 1)
    elseif estimated then
      local nextPoint, opposite, previous = quad[estimated % 4 + 1], quad[(estimated + 1) % 4 + 1], quad[(estimated + 2) % 4 + 1]
      quad[estimated] = {x = nextPoint.x + previous.x - opposite.x, y = nextPoint.y + previous.y - opposite.y}
    end
    local ambiguous
    if transform then
      local row = clamp(frame, transform.first_frame, transform.last_frame) - transform.first_frame + 1
      local motion = transform.samples[row]
      if motion.interpolated or motion.source_frame ~= frame then gaps[#gaps + 1] = "Transform" end
      ambiguous = motion.ambiguous_rotation
      AE.project(quad, motion, transform.channels, meta)
    end
    if #gaps > 0 then
      diagnostics[#diagnostics + 1] = "Source frame " .. frame .. " uses interpolated or held values in " .. table.concat(gaps, ", ") .. "."
    end
    local interpolated = recovery ~= nil or #gaps > 0
    hadGap = hadGap or interpolated
    samples[#samples + 1] = {source_frame = frame, quad = quad, interpolated = interpolated, ambiguous_rotation = ambiguous}
  end
  return {
    kind = "perspective", format = format, meta = meta, samples = samples,
    diagnostics = diagnostics, first_frame = first_frame, last_frame = last_frame,
    has_interpolation = hadGap, recovery = recovery, partial_pin = #known < 3 or nil
  }
end
local FindBalanced
FindBalanced = function(text, startPos, openChar, closeChar)
  local depth = 0
  for i = startPos, #text do
    local ch = text:sub(i, i)
    if ch == openChar then
      depth = depth + 1
    elseif ch == closeChar then
      depth = depth - 1
      if depth == 0 then
        return text:sub(startPos, i), i
      end
    end
  end
  return nil, nil
end
local ExtractLabeledArray
ExtractLabeledArray = function(block, label)
  local labelPos = block:find(label, 1, true)
  if not (labelPos) then
    return nil
  end
  local startPos = block:find("[", labelPos, true)
  if not (startPos) then
    return nil
  end
  local array = FindBalanced(block, startPos, "[", "]")
  return array
end
local ParsePairArray
ParsePairArray = function(arrayText)
  local points = { }
  if not (arrayText) then
    return points
  end
  local pattern = "%[%s*(" .. tostring(NUM_PATTERN) .. ")%s*,%s*(" .. tostring(NUM_PATTERN) .. ")%s*%]"
  for x, y in arrayText:gmatch(pattern) do
    points[#points + 1] = {
      x = tonumber(x),
      y = tonumber(y)
    }
  end
  return points
end
local FrameFromPrefix
FrameFromPrefix = function(prefix)
  local frame = nil
  for line in tostring(prefix or ""):gmatch("[^\r\n]+") do
    local value = line:match("^%s*([%-]?%d+)%s")
    if value then
      frame = tonumber(value)
    end
  end
  return frame
end
local ParseShapeBlock
ParseShapeBlock = function(block, frame, source_index)
  local verticesRaw = ExtractLabeledArray(block, "vertices")
  local inRaw = ExtractLabeledArray(block, "inTangents")
  local outRaw = ExtractLabeledArray(block, "outTangents")
  local vertices = ParsePairArray(verticesRaw)
  local inTangents = ParsePairArray(inRaw)
  local outTangents = ParsePairArray(outRaw)
  if #vertices < 2 then
    return nil, "Shape " .. tostring(source_index) .. " contains no vertices."
  end
  if inRaw and #inTangents ~= #vertices then
    return nil, "Shape " .. tostring(source_index) .. ": incomplete inTangents."
  end
  if outRaw and #outTangents ~= #vertices then
    return nil, "Shape " .. tostring(source_index) .. ": incomplete outTangents."
  end
  local closedRaw = block:match("[\"']?closed[\"']?%s*[:=]%s*(%a+)")
  local closed = not (closedRaw and closedRaw:lower() == "false")
  local points = { }
  for i, vertex in ipairs(vertices) do
    local in_t = inTangents[i] or {
      x = 0,
      y = 0
    }
    local out_t = outTangents[i] or {
      x = 0,
      y = 0
    }
    local _list_0 = {
      vertex.x,
      vertex.y,
      in_t.x,
      in_t.y,
      out_t.x,
      out_t.y
    }
    for _index_0 = 1, #_list_0 do
      local value = _list_0[_index_0]
      if not (finite(value)) then
        return nil, "Shape " .. tostring(source_index) .. ", vertex " .. tostring(i) .. ": non-finite value."
      end
    end
    points[#points + 1] = {
      x = vertex.x or 0,
      y = vertex.y or 0,
      inx = in_t.x or 0,
      iny = in_t.y or 0,
      outx = out_t.x or 0,
      outy = out_t.y or 0
    }
  end
  return {
    id = "shape_" .. tostring(source_index),
    frame = frame,
    closed = closed,
    points = points,
    source_index = source_index
  }
end
local ParseBezierPointBlock
ParseBezierPointBlock = function(body, frame, source_index, closed)
  local points = { }
  for raw in tostring(body or ""):gmatch("Point%(([^%)]*)%)") do
    local values = ParseNumbers(raw)
    if #values >= 2 then
      if not (finite(values[1]) and finite(values[2])) then
        return nil, "Bezier " .. tostring(source_index) .. ": non-finite value."
      end
      points[#points + 1] = {
        x = values[1],
        y = values[2],
        inx = 0,
        iny = 0,
        outx = 0,
        outy = 0,
        normalized = true,
        y_up = true
      }
    end
  end
  if #points < 2 then
    return nil, "Bezier " .. tostring(source_index) .. " contains no points."
  end
  return {
    id = "bezier_" .. tostring(source_index),
    frame = frame,
    closed = closed,
    points = points,
    source_index = source_index,
    legacy_bezier = true
  }
end
local ParseLegacyBezierData
ParseLegacyBezierData = function(input)
  local text, masks, pos, source_index = tostring(input or ""), { }, 1, 0
  while true do
    local bezierPos = text:find("Bezier", pos, true)
    if not (bezierPos) then
      break
    end
    local openPos = text:find("(", bezierPos, true)
    if not (openPos) then
      break
    end
    local block, blockEnd = FindBalanced(text, openPos, "(", ")")
    if not (block and blockEnd) then
      break
    end
    source_index = source_index + 1
    local prefix = text:sub(pos, bezierPos - 1)
    local nextBezier = text:find("Bezier", blockEnd + 1, true)
    local suffix = text:sub(blockEnd + 1, nextBezier and nextBezier - 1 or #text)
    local frame = FrameFromPrefix(prefix) or source_index - 1
    local closed = tostring(suffix:match("<Open>%s*(%d+)%s*</Open>") or "0") ~= "1"
    local shape, err = ParseBezierPointBlock(block:sub(2, -2), frame, source_index, closed)
    if not (shape) then
      return nil, err
    end
    masks[#masks + 1] = shape
    pos = blockEnd + 1
  end
  if #masks == 0 then
    return nil
  end
  return masks
end
local ExpandSparseShapeSamples
ExpandSparseShapeSamples = function(samples, diagnostics)
  if #samples < 2 then
    return samples
  end
  local first_frame, last_frame = samples[1].source_frame, samples[#samples].source_frame
  if last_frame - first_frame + 1 == #samples then
    return samples
  end
  local by_frame
  do
    local _tbl_0 = { }
    for _index_0 = 1, #samples do
      local sample = samples[_index_0]
      _tbl_0[sample.source_frame] = sample
    end
    by_frame = _tbl_0
  end
  local out, held, held_count = { }, nil, 0
  for frame = first_frame, last_frame do
    LineOps.checkCancelled()
    local sample = by_frame[frame]
    if sample then
      held = sample
      out[#out + 1] = sample
    else
      local fallback = held
      if not (fallback) then
        fallback = samples[1]
      end
      out[#out + 1] = {
        source_frame = frame,
        masks = fallback.masks,
        interpolated = true,
        held = true
      }
      held_count = held_count + 1
    end
  end
  diagnostics[#diagnostics + 1] = tostring(held_count) .. " missing Shape frames were held without compressing time; strict synchronization may reject them."
  return out
end
local ParseShapeData
ParseShapeData = function(input)
  local text, masks, pos, source_index = tostring(input or ""), { }, 1, 0
  while true do
    local shapePos = text:find("Shape", pos, true)
    if not (shapePos) then
      break
    end
    local bracePos = text:find("{", shapePos, true)
    if not (bracePos) then
      break
    end
    local block, blockEnd = FindBalanced(text, bracePos, "{", "}")
    if not (block and blockEnd) then
      break
    end
    if block:find("vertices", 1, true) then
      source_index = source_index + 1
      local prefix = text:sub(pos, bracePos - 1)
      local frame = FrameFromPrefix(prefix) or 0
      local shape, err = ParseShapeBlock(block, frame, source_index)
      if not (shape) then
        return nil, err
      end
      masks[#masks + 1] = shape
    end
    pos = blockEnd + 1
  end
  if #masks == 0 and text:find("vertices", 1, true) then
    local shape, err = ParseShapeBlock(text, 0, 1)
    if not (shape) then
      return nil, err
    end
    masks[1] = shape
  end
  if #masks == 0 then
    local err
    masks, err = ParseLegacyBezierData(text)
    if err then
      return nil, err
    end
  end
  if not (masks and #masks > 0) then
    return nil, "No Shape{...} or Bezier(Point(...)) data was found."
  end
  table.sort(masks, function(a, b)
    if a.frame == b.frame then
      return a.source_index < b.source_index
    else
      return a.frame < b.frame
    end
  end)
  local by_frame, frames = { }, { }
  for _index_0 = 1, #masks do
    local mask = masks[_index_0]
    if not (by_frame[mask.frame]) then
      by_frame[mask.frame] = { }
      frames[#frames + 1] = mask.frame
    end
    by_frame[mask.frame][#by_frame[mask.frame] + 1] = mask
  end
  table.sort(frames)
  local diagnostics = {
    "Multiple-mask identity is preserved by block order; pasted data does not always include layer names."
  }
  local unsupported_shape_fields = { }
  local lowerText = text:lower()
  local _list_0 = {
    "featherseg",
    "featherradii",
    "featherinterps",
    "feathertensions",
    "feathertypes",
    "mask feather",
    "mask opacity",
    "mask expansion",
    "mask mode",
    "inverted"
  }
  for _index_0 = 1, #_list_0 do
    local label = _list_0[_index_0]
    if lowerText:find(label, 1, true) then
      unsupported_shape_fields[#unsupported_shape_fields + 1] = label
    end
  end
  if #unsupported_shape_fields > 0 then
    diagnostics[#diagnostics + 1] = "AE Mask fields not representable by one ASS clip: " .. tostring(table.concat(unsupported_shape_fields, ', ')) .. "."
  end
  local samples
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #frames do
      local frame = frames[_index_0]
      _accum_0[_len_0] = {
        source_frame = frame,
        masks = by_frame[frame]
      }
      _len_0 = _len_0 + 1
    end
    samples = _accum_0
  end
  samples = ExpandSparseShapeSamples(samples, diagnostics)
  return {
    kind = "shape",
    format = "Adobe After Effects Mask Data",
    meta = ParseMeta(input),
    samples = samples,
    diagnostics = diagnostics,
    first_frame = samples[1].source_frame,
    last_frame = samples[#samples].source_frame,
    sparse = frames[#frames] - frames[1] + 1 ~= #frames
  }
end
local StripQuotes
StripQuotes = function(value)
  value = trim(value)
  local quoted = value:match('^"(.*)"$' or value:match("^'(.*)'$"))
  return quoted or value
end
local ShakePointsFromValues
ShakePointsFromValues = function(values, expected_vertices)
  if expected_vertices == nil then
    expected_vertices = nil
  end
  if #values == 0 or #values % 12 ~= 0 then
    return nil, nil, nil, "vertex_data must contain blocks of 12 values."
  end
  local vertices = #values / 12
  if expected_vertices and vertices ~= expected_vertices then
    return nil, nil, nil, "vertex_data expected " .. tostring(expected_vertices) .. " vertices and contains " .. tostring(vertices) .. "."
  end
  local points, edge_points, has_edge = { }, { }, false
  for vertex = 1, vertices do
    local base = (vertex - 1) * 12
    local vx, vy = values[base + 1], values[base + 2]
    local lx, ly = values[base + 3], values[base + 4]
    local rx, ry = values[base + 5], values[base + 6]
    for index = 1, 12 do
      if not (finite(values[base + index])) then
        return nil, nil, nil, "Vertex " .. tostring(vertex) .. ": value " .. tostring(index) .. " is not finite."
      end
    end
    points[vertex] = {
      x = vx,
      y = vy,
      inx = lx - vx,
      iny = ly - vy,
      outx = rx - vx,
      outy = ry - vy,
      absolute_y_up = true
    }
    local edge
    do
      local _accum_0 = { }
      local _len_0 = 1
      for index = 7, 12 do
        _accum_0[_len_0] = values[base + index]
        _len_0 = _len_0 + 1
      end
      edge = _accum_0
    end
    edge_points[vertex] = edge
    for _index_0 = 1, #edge do
      local value = edge[_index_0]
      if math.abs(value) > numericEpsilon then
        has_edge = true
        break
      end
    end
  end
  return points, edge_points, has_edge
end
local ShakeMaskFromKey
ShakeMaskFromKey = function(shape, key, points, edge_points)
  if points == nil then
    points = key.points
  end
  if edge_points == nil then
    edge_points = key.edge_points
  end
  return {
    id = shape.id,
    name = shape.name,
    parent = shape.parent,
    closed = shape.closed,
    visible = shape.visible,
    locked = shape.locked,
    points = points,
    edge_points = edge_points,
    color = key.color or shape.color,
    center = key.center,
    shake = true
  }
end
local InterpolateShakeMask
InterpolateShakeMask = function(shape, before, after, frame)
  if not (before and after and #before.points == #after.points) then
    return nil
  end
  local span = after.frame - before.frame
  if span <= 0 then
    return nil
  end
  local k = (frame - before.frame) / span
  local points = { }
  for i = 1, #before.points do
    local a, b = before.points[i], after.points[i]
    local point = {
      absolute_y_up = true
    }
    local _list_0 = {
      "x",
      "y",
      "inx",
      "iny",
      "outx",
      "outy"
    }
    for _index_0 = 1, #_list_0 do
      local field = _list_0[_index_0]
      point[field] = a[field] + (b[field] - a[field]) * k
    end
    points[i] = point
  end
  return ShakeMaskFromKey(shape, before, points, before.edge_points)
end
local BuildShakeTrack
BuildShakeTrack = function(shapes, meta, diagnostics)
  local frames, seen = { }, { }
  for _index_0 = 1, #shapes do
    local _continue_0 = false
    repeat
      local shape = shapes[_index_0]
      if shape.visible == false then
        _continue_0 = true
        break
      end
      local _list_0 = shape.key_order
      for _index_1 = 1, #_list_0 do
        local frame = _list_0[_index_1]
        if not (seen[frame]) then
          seen[frame] = true
          frames[#frames + 1] = frame
        end
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  table.sort(frames)
  if #frames == 0 then
    return nil, "Shake SSF contains no key_time/vertex_data."
  end
  local first_frame, last_frame = frames[1], frames[#frames]
  local samples, approximated = { }, 0
  for frame = first_frame, last_frame do
    LineOps.checkCancelled()
    local masks, sample_approx = { }, false
    for _index_0 = 1, #shapes do
      local _continue_0 = false
      repeat
        local shape = shapes[_index_0]
        if shape.visible == false then
          _continue_0 = true
          break
        end
        local key = shape.keys[frame]
        local mask
        if key then
          mask = ShakeMaskFromKey(shape, key)
        end
        if not (mask) then
          local before, after = nil, nil
          local _list_0 = shape.key_order
          for _index_1 = 1, #_list_0 do
            local keyFrame = _list_0[_index_1]
            local candidate = shape.keys[keyFrame]
            if keyFrame < frame then
              before = candidate
            elseif keyFrame > frame then
              after = candidate
              break
            end
          end
          mask = InterpolateShakeMask(shape, before, after, frame)
          if not (mask) then
            local held = before or after
            if held then
              mask = ShakeMaskFromKey(shape, held)
            end
          end
          if mask then
            sample_approx = true
          end
        end
        if mask then
          masks[#masks + 1] = mask
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    if #masks == 0 then
      return nil, "Shake frame " .. tostring(frame) .. " contains no visible shape."
    end
    if sample_approx then
      approximated = approximated + 1
    end
    samples[#samples + 1] = {
      source_frame = frame,
      masks = masks,
      interpolated = sample_approx
    }
  end
  if approximated > 0 then
    diagnostics[#diagnostics + 1] = tostring(approximated) .. " SSF frames require interpolation/holding; strict mode rejects them because SSF does not preserve temporal easing."
  end
  return {
    kind = "shape",
    format = "Shake RotoShape SSF 4.0",
    meta = meta,
    samples = samples,
    diagnostics = diagnostics,
    shapes = shapes,
    first_frame = first_frame,
    last_frame = last_frame,
    has_interpolation = approximated > 0
  }
end
local ParseLegacyShakeLayout
ParseLegacyShakeLayout = function(input, num_shapes, meta, diagnostics)
  local rows = { }
  local _list_0 = SplitLines(input)
  for _index_0 = 1, #_list_0 do
    local raw = _list_0[_index_0]
    if raw:find("vertex_data", 1, true) then
      local values = ParseNumbers(raw:match("vertex_data%s+(.*)") or "")
      local points, edge_points, has_edge, err = ShakePointsFromValues(values)
      if not (points) then
        return nil, err
      end
      rows[#rows + 1] = {
        points = points,
        edge_points = edge_points,
        has_edge = has_edge
      }
    end
  end
  if #rows == 0 then
    return nil, "Shake SSF contains no vertex_data."
  end
  if #rows % num_shapes ~= 0 then
    return nil, tostring(#rows) .. " vertex_data blocks cannot be divided evenly among " .. tostring(num_shapes) .. " shapes."
  end
  local length = #rows / num_shapes
  local samples, edgeSeen = { }, false
  for frame_index = 1, length do
    local masks = { }
    for shape_index = 1, num_shapes do
      local row = rows[(shape_index - 1) * length + frame_index]
      edgeSeen = edgeSeen or row.has_edge
      masks[#masks + 1] = {
        id = "shake_" .. tostring(shape_index),
        name = "Shape " .. tostring(shape_index),
        closed = true,
        visible = true,
        points = row.points,
        edge_points = row.edge_points,
        shake = true
      }
    end
    samples[#samples + 1] = {
      source_frame = frame_index - 1,
      masks = masks
    }
  end
  diagnostics[#diagnostics + 1] = "Legacy SSF without key_time: shape-major order is preserved and aligned ordinally."
  if edgeSeen then
    diagnostics[#diagnostics + 1] = "Auxiliary edge/feather data was read; one ASS clip cannot represent it faithfully."
  end
  return {
    kind = "shape",
    format = "Shake RotoShape SSF 4.0 (legacy layout)",
    meta = meta,
    samples = samples,
    diagnostics = diagnostics,
    first_frame = 0,
    last_frame = length - 1
  }
end
local ParseShakeShapeData
ParseShakeShapeData = function(input)
  local text = tostring(input or "")
  local num_shapes = tonumber(text:match("num_shapes%s+([%d]+)"))
  if not (num_shapes and num_shapes >= 1) then
    return nil, "Shake SSF: num_shapes is missing or invalid."
  end
  local meta = ParseMeta(text)
  meta.motion_blur = tonumber(text:match("motion_blur%s+([%+%-%.%deE]+)"))
  meta.shutter_timing = tonumber(text:match("shutter_timing%s+([%+%-%.%deE]+)"))
  meta.shutter_offset = tonumber(text:match("shutter_offset%s+([%+%-%.%deE]+)"))
  local diagnostics = {
    "Y-up SSF coordinates detected; vertical flipping is deferred until the actual source height is known."
  }
  if meta.motion_blur or meta.shutter_timing or meta.shutter_offset then
    diagnostics[#diagnostics + 1] = "SSF motion blur/shutter values are retained as metadata, but ASS cannot reproduce Mocha subframe sampling; this is not geometric jitter."
  end
  if not (text:find("shape_name", 1, true) or text:find("key_time", 1, true)) then
    return ParseLegacyShakeLayout(text, num_shapes, meta, diagnostics)
  end
  local known = {
    shape_name = true,
    parent_name = true,
    closed = true,
    visible = true,
    locked = true,
    tangents = true,
    edge_shape = true,
    num_vertices = true,
    num_key_times = true,
    key_time = true,
    center_x = true,
    center_y = true,
    color_r = true,
    color_g = true,
    color_b = true,
    color_a = true,
    vertex_data = true,
    shake_shape_data = true,
    num_shapes = true,
    motion_blur = true,
    shutter_timing = true,
    shutter_offset = true,
    Units = true,
    Source = true,
    Comp = true
  }
  local unknownTokens = { }
  local shapes, current_shape, currentKey = { }, nil, nil
  local lines = SplitLines(text)
  local i = 1
  while i <= #lines do
    local stripped = trim(lines[i])
    local token, rest = stripped:match("^(%S+)%s*(.-)%s*$")
    local _exp_0 = token
    if "shape_name" == _exp_0 then
      current_shape = {
        id = "shake_" .. tostring(#shapes + 1) .. ":" .. tostring(StripQuotes(rest)),
        name = StripQuotes(rest),
        parent = "",
        closed = true,
        visible = true,
        locked = false,
        keys = { },
        key_order = { }
      }
      shapes[#shapes + 1] = current_shape
      currentKey = nil
    elseif "parent_name" == _exp_0 then
      if current_shape then
        current_shape.parent = StripQuotes(rest)
      end
    elseif "closed" == _exp_0 then
      if current_shape then
        current_shape.closed = tonumber(rest) ~= 0
      end
    elseif "visible" == _exp_0 then
      if current_shape then
        current_shape.visible = tonumber(rest) ~= 0
      end
    elseif "locked" == _exp_0 then
      if current_shape then
        current_shape.locked = tonumber(rest) ~= 0
      end
    elseif "tangents" == _exp_0 then
      if current_shape then
        current_shape.tangents = tonumber(rest) ~= 0
      end
    elseif "edge_shape" == _exp_0 then
      if current_shape then
        current_shape.edge_shape = tonumber(rest) ~= 0
      end
    elseif "num_vertices" == _exp_0 then
      if current_shape then
        current_shape.num_vertices = tonumber(rest)
      end
    elseif "num_key_times" == _exp_0 then
      if current_shape then
        current_shape.num_key_times = tonumber(rest)
      end
    elseif "key_time" == _exp_0 then
      if not (current_shape) then
        return nil, "Shake SSF: key_time appears outside a shape."
      end
      local frame = tonumber(rest)
      if not (finite(frame) and frame == math.floor(frame)) then
        return nil, "Shake SSF: key_time must be finite and integral."
      end
      if current_shape.keys[frame] then
        return nil, "Shake SSF: duplicate key_time " .. tostring(frame) .. " in " .. tostring(current_shape.name) .. "."
      end
      currentKey = {
        frame = frame,
        color = { }
      }
      current_shape.keys[frame] = currentKey
      current_shape.key_order[#current_shape.key_order + 1] = frame
    elseif "center_x" == _exp_0 then
      if currentKey then
        currentKey.center = currentKey.center or { }
      end
      if currentKey then
        currentKey.center.x = tonumber(rest)
      end
    elseif "center_y" == _exp_0 then
      if currentKey then
        currentKey.center = currentKey.center or { }
      end
      if currentKey then
        currentKey.center.y = tonumber(rest)
      end
    elseif "color_r" == _exp_0 or "color_g" == _exp_0 or "color_b" == _exp_0 or "color_a" == _exp_0 then
      if currentKey then
        currentKey.color[token:sub(-1)] = tonumber(rest)
      end
    elseif "vertex_data" == _exp_0 then
      if not (current_shape and currentKey) then
        return nil, "Shake SSF: vertex_data appears without key_time."
      end
      local expected = current_shape.num_vertices and current_shape.num_vertices * 12 or nil
      local values = ParseNumbers(rest)
      while expected and #values < expected and i < #lines do
        local nextLine = trim(lines[i + 1])
        local nextToken = nextLine:match("^(%S+)")
        if known[nextToken] then
          break
        end
        i = i + 1
        local more = ParseNumbers(nextLine)
        for _index_0 = 1, #more do
          local value = more[_index_0]
          values[#values + 1] = value
        end
      end
      if expected and #values ~= expected then
        return nil, "Shake SSF: vertex_data has " .. tostring(#values) .. " values; expected " .. tostring(expected) .. "."
      end
      local points, edge_points, has_edge, err = ShakePointsFromValues(values, current_shape.num_vertices)
      if not (points) then
        return nil, err
      end
      currentKey.points, currentKey.edge_points, currentKey.has_edge = points, edge_points, has_edge
    else
      if token and token ~= "" and not known[token] and not tonumber(token) then
        unknownTokens[token] = true
      end
    end
    i = i + 1
  end
  if #shapes ~= num_shapes then
    return nil, "Shake SSF declares " .. tostring(num_shapes) .. " shapes and contains " .. tostring(#shapes) .. "."
  end
  local edgeSeen = false
  for _index_0 = 1, #shapes do
    local shape = shapes[_index_0]
    table.sort(shape.key_order)
    if shape.num_key_times and shape.num_key_times ~= #shape.key_order then
      return nil, "Shake SSF: " .. tostring(shape.name) .. " declares " .. tostring(shape.num_key_times) .. " keys and contains " .. tostring(#shape.key_order) .. "."
    end
    local _list_0 = shape.key_order
    for _index_1 = 1, #_list_0 do
      local frame = _list_0[_index_1]
      local key = shape.keys[frame]
      if not (key.points) then
        return nil, "Shake SSF: " .. tostring(shape.name) .. ", frame " .. tostring(frame) .. ", contains no vertex_data."
      end
      edgeSeen = edgeSeen or key.has_edge
    end
  end
  if edgeSeen then
    diagnostics[#diagnostics + 1] = "Auxiliary edge/feather data was read and retained; one ASS clip cannot represent it faithfully."
  end
  local unknown_list
  do
    local _accum_0 = { }
    local _len_0 = 1
    for token in pairs(unknownTokens) do
      _accum_0[_len_0] = token
      _len_0 = _len_0 + 1
    end
    unknown_list = _accum_0
  end
  table.sort(unknown_list)
  if #unknown_list > 0 then
    diagnostics[#diagnostics + 1] = "Unknown or unapplied SSF fields: " .. tostring(table.concat(unknown_list, ', ')) .. "."
  end
  return BuildShakeTrack(shapes, meta, diagnostics)
end
local ReadInputOrPath
ReadInputOrPath = function(input)
  local raw = tostring(input or "")
  local candidate = trim(raw):gsub('^"(.*)"$', '%1')
  if not raw:find("\n", 1, true) and candidate ~= "" then
    local file = io.open(candidate, "rb")
    if file then
      local content = file:read("*a")
      file:close()
      return content, candidate
    end
  end
  return raw, nil
end
local ParseInput
ParseInput = function(input, expectedKind, choose)
  local text, sourcePath = ReadInputOrPath(input)
  text = tostring(text or ""):gsub("^\239\187\191", "")
  local track, err
  local shape = text:find("vertices", 1, true) or text:find("Bezier(", 1, true)
  if text:find("shake_shape_data 4.0", 1, true) then
    track, err = ParseShakeShapeData(text)
  elseif expectedKind == "shape" and shape then
    track, err = ParseShapeData(text)
  else
    local groups, hasTransform, exports, hasLayerGeometry = AE.inventory(text)
    if exports > 1 then
      return nil, "Multiple AE exports were pasted together. Paste one tracked layer at a time."
    elseif expectedKind == "transform" and hasTransform then
      track, err = ParseTransformData(text, false, choose ~= nil)
    elseif #groups > 0 then
      if expectedKind == "transform" then
        return nil, "Use Perspective/Apply Power Pin for CC Power Pin or Corner Pin data."
      end
      local group = groups[1]
      if #groups > 1 then
        if type(choose) ~= "function" then
          return nil, "Multiple Corner Pin effects were found. Choose one in Apply Power Pin or export a single effect."
        end
        group = choose("Choose the Corner Pin effect to apply.", groups)
        if not group then return nil end
      end
      track, err = ParsePowerPinData(text, choose ~= nil, group, groups, hasTransform or hasLayerGeometry)
      if track then track.layer_motion = hasTransform or nil end
      if track and track.partial_pin and hasTransform and type(choose) == "function" then
        local action = choose(track.recovery .. "\nThis export also contains layer motion.", {"Use tracked corners", "Open Apply Motion"})
        if not action then return nil end
        if action == "Open Apply Motion" then track, err = ParseTransformData(text, false, true) end
      end
      if not track and (hasTransform or hasLayerGeometry) and type(choose) == "function" then
        local pins = ParsePowerPinData(text, true, group, groups, false)
        local motion = ParseTransformData(text, false, true)
        local alternatives = {}
        if motion then alternatives[#alternatives + 1] = "Open Apply Motion" end
        if pins then alternatives[#alternatives + 1] = "Use corners only" end
        if #alternatives > 0 then
          local action = choose(err .. "\nChoose which component to use on its own.", alternatives)
          if not action then return nil end
          track = action == "Use corners only" and pins or motion
          err = nil
        end
      end
    elseif shape then
      track, err = ParseShapeData(text)
    elseif hasTransform or exports > 0 then
      track, err = ParseTransformData(text, false, choose ~= nil)
      if track and expectedKind == "perspective" and type(choose) == "function" then
        if not choose("This export contains Transform data. Use it for position, scale and rotation.", {"Open Apply Motion"}) then return nil end
      end
    else
      return nil, "Unrecognized tracking format. In Mocha, export After Effects Transform Data, Corner Pin, CC Power Pin, AE Mask Shape or Shake SSF 4.0."
    end
  end
  if track then
    track.source_path = sourcePath
  end
  return track, err
end
local LinearFit
LinearFit = function(times, values)
  local n = math.min(#times, #values)
  if n < 2 then
    return nil, "At least two samples are required."
  end
  local sumT, sumV, sumTt, sumTv = 0, 0, 0, 0
  for i = 1, n do
    local t, v = tonumber(times[i]), tonumber(values[i])
    if not (finite(t) and finite(v)) then
      return nil, "Non-numeric sample at " .. tostring(i) .. "."
    end
    sumT = sumT + t
    sumV = sumV + v
    sumTt = sumTt + (t * t)
    sumTv = sumTv + (t * v)
  end
  local denom = n * sumTt - sumT * sumT
  if math.abs(denom) < singularEpsilon then
    return nil, "All timestamps are equal."
  end
  local slope = (n * sumTv - sumT * sumV) / denom
  local intercept = (sumV - slope * sumT) / n
  local residuals, sse, max_abs = { }, 0, 0
  for i = 1, n do
    local residual = values[i] - (intercept + slope * times[i])
    residuals[i] = residual
    sse = sse + (residual * residual)
    max_abs = math.max(max_abs, math.abs(residual))
  end
  return {
    slope = slope,
    intercept = intercept,
    residuals = residuals,
    rms = math.sqrt(sse / n),
    max = max_abs
  }
end
local VectorLinearity
VectorLinearity = function(times, xs, ys)
  local fit_x, err = LinearFit(times, xs)
  if not (fit_x) then
    return nil, err
  end
  local fit_y
  fit_y, err = LinearFit(times, ys)
  if not (fit_y) then
    return nil, err
  end
  local sum, max_vector = 0, 0
  local residuals = { }
  for i = 1, #times do
    local value = math.sqrt(fit_x.residuals[i] ^ 2 + fit_y.residuals[i] ^ 2)
    residuals[i] = value
    sum = sum + (value * value)
    max_vector = math.max(max_vector, value)
  end
  return {
    x = fit_x,
    y = fit_y,
    residuals = residuals,
    rms = math.sqrt(sum / #times),
    max = max_vector
  }
end
local SignedQuadArea
SignedQuadArea = function(quad)
  local area = 0
  for i = 1, 4 do
    local a, b = quad[i], quad[i % 4 + 1]
    area = area + (a.x * b.y - b.x * a.y)
  end
  return area / 2
end
local ValidateQuad
ValidateQuad = function(quad, minArea)
  if minArea == nil then
    minArea = geometryEpsilon
  end
  if not (quad and #quad == 4) then
    return false, "A quad must contain four corners."
  end
  local min_x, min_y, max_x, max_y = nil, nil, nil, nil
  for i, point in ipairs(quad) do
    if not (finite(point.x) and finite(point.y)) then
      return false, "Corner " .. tostring(i) .. " is not numeric."
    end
    min_x, max_x = math.min(min_x or point.x, point.x), math.max(max_x or point.x, point.x)
    min_y, max_y = math.min(min_y or point.y, point.y), math.max(max_y or point.y, point.y)
  end
  local area = SignedQuadArea(quad)
  if math.abs(area) < minArea then
    return false, "Degenerate quad: area " .. tostring(FormatNumber(area, 4)) .. "."
  end
  local bboxArea = (max_x - min_x) * (max_y - min_y)
  if bboxArea < minArea then
    return false, "Degenerate quad: bounding box has no area."
  end
  local fill_ratio = math.abs(area) / bboxArea
  if fill_ratio < 0.001 then
    return false, "Numerically unstable quad: it occupies only " .. tostring(FormatNumber(fill_ratio * 100, 4)) .. "% of its bounding box."
  end
  local sign = nil
  for i = 1, 4 do
    local a, b, c = quad[i], quad[i % 4 + 1], quad[(i + 1) % 4 + 1]
    local edge = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
    if edge < 0.001 then
      return false, "Degenerate quad: edge " .. tostring(i) .. " is nearly zero."
    end
    local cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
    if math.abs(cross) < geometryEpsilon then
      return false, "Quad is nearly collinear at corner " .. tostring(i) .. "."
    end
    local current = cross > 0 and 1 or -1
    sign = sign or current
    if current ~= sign then
      return false, "Concave quad or crossed corners."
    end
  end
  return true, nil, area
end
local SeriesFromTrack
SeriesFromTrack = function(track, fps, shapeSpace)
  if fps == nil then
    fps = nil
  end
  if shapeSpace == nil then
    shapeSpace = nil
  end
  fps = tonumber(fps or (track.meta and track.meta.fps)) or 24
  if fps <= 0 then
    fps = 24
  end
  shapeSpace = shapeSpace or { }
  local shapeW = tonumber(shapeSpace.source_width or (track.meta and track.meta.source_width)) or 1
  local shapeH = tonumber(shapeSpace.source_height or (track.meta and track.meta.source_height)) or 1
  local ShapePoint
  ShapePoint = function(point)
    local x, y = point.x, point.y
    if point.normalized then
      x = x * shapeW
      if point.y_up then
        y = 1 - y
      end
      y = y * shapeH
    elseif point.absolute_y_up then
      y = shapeH - y
    end
    return x, y
  end
  local series = {
    frame = { },
    time = { },
    x = { },
    y = { },
    scale_x = { },
    scale_y = { },
    rotation = { },
    area = { }
  }
  for i, sample in ipairs(track.samples or { }) do
    series.frame[i] = sample.source_frame
    series.time[i] = (sample.source_frame - track.samples[1].source_frame) * 1000 / fps
    if track.kind == "transform" then
      series.x[i], series.y[i] = sample.position.x, sample.position.y
      series.scale_x[i], series.scale_y[i] = sample.scale.x, sample.scale.y
      series.rotation[i] = sample.rotation
    elseif track.kind == "perspective" then
      local cx, cy = 0, 0
      local _list_0 = sample.quad
      for _index_0 = 1, #_list_0 do
        local point = _list_0[_index_0]
        cx = cx + (point.x / 4)
        cy = cy + (point.y / 4)
      end
      series.x[i], series.y[i] = cx, cy
      series.area[i] = math.abs(SignedQuadArea(sample.quad))
    elseif track.kind == "shape" then
      local sx, sy, count, area = 0, 0, 0, 0
      local _list_0 = sample.masks
      for _index_0 = 1, #_list_0 do
        local mask = _list_0[_index_0]
        local maskArea = 0
        local _list_1 = mask.points
        for _index_1 = 1, #_list_1 do
          local point = _list_1[_index_1]
          local x, y = ShapePoint(point)
          sx = sx + x
          sy = sy + y
          count = count + 1
        end
        if #mask.points >= 3 then
          for j = 1, #mask.points do
            local a, b = mask.points[j], mask.points[j % #mask.points + 1]
            local ax, ay = ShapePoint(a)
            local bx, by = ShapePoint(b)
            maskArea = maskArea + ((ax * by - bx * ay) / 2)
          end
        end
        area = area + math.abs(maskArea)
      end
      series.x[i], series.y[i] = sx / math.max(1, count), sy / math.max(1, count)
      series.area[i] = area
    end
  end
  return series
end
Core.trim = trim
Core.finite = finite
Core.FormatNumber = FormatNumber
Core.ParseNumbers = ParseNumbers
Core.ParseMeta = ParseMeta
Core.ParseKeyframeSections = ParseKeyframeSections
Core.ParseTransformData = ParseTransformData
Core.ParsePowerPinData = ParsePowerPinData
Core.ParseShapeData = ParseShapeData
Core.ParseShakeShapeData = ParseShakeShapeData
Core.ParseInput = ParseInput
Core.UnwrapAngles = UnwrapAngles
Core.UnwrapRotationSection = UnwrapRotationSection
Core.LinearFit = LinearFit
Core.VectorLinearity = VectorLinearity
Core.SignedQuadArea = SignedQuadArea
Core.ValidateQuad = ValidateQuad
Core.SeriesFromTrack = SeriesFromTrack
local PointAt
PointAt = function(point, x, y, ctx)
  if point and point.normalized then
    x = x * ctx.source_w
    if point.y_up then
      y = 1 - y
    end
    y = y * ctx.source_h
  elseif point and point.absolute_y_up then
    y = ctx.source_h - y
  end
  return {
    x = x * ctx.sx + ctx.dx,
    y = y * ctx.sy + ctx.dy
  }
end
local SegmentIsLine
SegmentIsLine = function(pointA, pointB, ctx)
  local eps = ctx.epsilon
  return math.abs((pointA.outx or 0) * ctx.sx) <= eps and math.abs((pointA.outy or 0) * ctx.sy) <= eps and math.abs((pointB.inx or 0) * ctx.sx) <= eps and math.abs((pointB.iny or 0) * ctx.sy) <= eps
end
local AppendSegment
AppendSegment = function(parts, pointA, pointB, ctx)
  local endpoint = PointAt(pointB, pointB.x, pointB.y, ctx)
  if SegmentIsLine(pointA, pointB, ctx) then
    parts[#parts + 1] = "l"
    parts[#parts + 1] = FormatNumber(endpoint.x, ctx.decimals)
    parts[#parts + 1] = FormatNumber(endpoint.y, ctx.decimals)
  else
    local c1 = PointAt(pointA, pointA.x + pointA.outx, pointA.y + pointA.outy, ctx)
    local c2 = PointAt(pointB, pointB.x + pointB.inx, pointB.y + pointB.iny, ctx)
    parts[#parts + 1] = "b"
    local _list_0 = {
      c1.x,
      c1.y,
      c2.x,
      c2.y,
      endpoint.x,
      endpoint.y
    }
    for _index_0 = 1, #_list_0 do
      local value = _list_0[_index_0]
      parts[#parts + 1] = FormatNumber(value, ctx.decimals)
    end
  end
end
local RenderShapePath
RenderShapePath = function(shape, ctx)
  local points = shape.points
  if not (points and #points >= 2) then
    return nil, "Shape has fewer than two points."
  end
  local first = PointAt(points[1], points[1].x, points[1].y, ctx)
  local parts = {
    "m",
    FormatNumber(first.x, ctx.decimals),
    FormatNumber(first.y, ctx.decimals)
  }
  for i = 1, #points - 1 do
    AppendSegment(parts, points[i], points[i + 1], ctx)
  end
  if shape.closed then
    AppendSegment(parts, points[#points], points[1], ctx)
  end
  return table.concat(parts, " ")
end
local NormalizePath
NormalizePath = function(path)
  path = trim(path)
  if path == "" then
    return nil, "Empty ASS path."
  end
  if ZF then
    local ok, shape = pcall(function()
      return ZF.shape(path)
    end)
    if not (ok and shape) then
      return nil, "ZF.shape rejected the path: " .. tostring(shape)
    end
    local okBuild, built = pcall(function()
      return trim(shape:build())
    end)
    if okBuild and built and built ~= "" then
      return built
    end
  end
  return path
end
local ManualBounds
ManualBounds = function(path)
  local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
  local isX, found = true, false
  for token in tostring(path or ""):gmatch("%S+") do
    if token == "m" or token == "l" or token == "b" then
      isX = true
    else
      local number = tonumber(token)
      if number then
        if isX then
          min_x, max_x = math.min(min_x, number), math.max(max_x, number)
        else
          min_y, max_y = math.min(min_y, number), math.max(max_y, number)
          found = true
        end
        isX = not isX
      end
    end
  end
  if not (found) then
    return nil
  end
  return {
    l = min_x,
    t = min_y,
    r = max_x,
    b = max_y,
    w = max_x - min_x,
    h = max_y - min_y
  }
end
local PathBounds
PathBounds = function(path)
  if ZF then
    local ok, shape = pcall(function()
      return ZF.shape(path)
    end)
    if ok and shape and shape.l and shape.t and shape.w and shape.h then
      return {
        l = shape.l,
        t = shape.t,
        r = shape.l + shape.w,
        b = shape.t + shape.h,
        w = shape.w,
        h = shape.h
      }
    end
  end
  return ManualBounds(path)
end
local ManualShiftPath
ManualShiftPath = function(path, dx, dy, decimals)
  local out, isX = { }, true
  for token in tostring(path or ""):gmatch("%S+") do
    if token == "m" or token == "l" or token == "b" then
      out[#out + 1], isX = token, true
    else
      local number = tonumber(token)
      if number then
        out[#out + 1] = FormatNumber(number + (isX and dx or dy), decimals)
        isX = not isX
      else
        out[#out + 1] = token
      end
    end
  end
  return table.concat(out, " ")
end
local ShiftPath
ShiftPath = function(path, dx, dy, decimals)
  if ZF then
    local ok, moved = pcall(function()
      return trim(ZF.shape(path):move(dx, dy):build())
    end)
    if ok and moved and moved ~= "" then
      return moved
    end
  end
  return ManualShiftPath(path, dx, dy, decimals)
end
local BuildShapeContext
BuildShapeContext = function(opts, meta, script_res)
  local target_w = tonumber(opts.target_width) or script_res.x or DEFAULTS.target_width
  local target_h = tonumber(opts.target_height) or script_res.y or DEFAULTS.target_height
  local source_w
  if opts.use_source_meta and meta.source_width then
    source_w = meta.source_width
  else
    source_w = tonumber(opts.source_width)
  end
  local source_h
  if opts.use_source_meta and meta.source_height then
    source_h = meta.source_height
  else
    source_h = tonumber(opts.source_height)
  end
  if not (source_w and source_w > 0) then
    source_w = target_w
  end
  if not (source_h and source_h > 0) then
    source_h = target_h
  end
  return {
    sx = opts.scale_to_script and target_w / source_w or 1,
    sy = opts.scale_to_script and target_h / source_h or 1,
    dx = tonumber(opts.offset_x) or 0,
    dy = tonumber(opts.offset_y) or 0,
    decimals = clamp(opts.decimals, 0, 6),
    epsilon = tonumber(opts.tangent_epsilon) or DEFAULTS.tangent_epsilon,
    target_w = target_w,
    target_h = target_h,
    source_w = source_w,
    source_h = source_h
  }
end
local PrepareShapeSamples
PrepareShapeSamples = function(track, opts, script_res)
  local ctx = BuildShapeContext(opts, track.meta or { }, script_res)
  local out = { }
  local _list_0 = track.samples
  for _index_0 = 1, #_list_0 do
    local sample = _list_0[_index_0]
    LineOps.checkCancelled()
    local paths = { }
    local _list_1 = sample.masks
    for _index_1 = 1, #_list_1 do
      local mask = _list_1[_index_1]
      local path, err = RenderShapePath(mask, ctx)
      if not (path) then
        return nil, err
      end
      path, err = NormalizePath(path)
      if not (path) then
        return nil, err
      end
      paths[#paths + 1] = path
    end
    out[#out + 1] = {
      source_frame = sample.source_frame,
      path = trim(table.concat(paths, " ")),
      masks = sample.masks
    }
  end
  return {
    kind = "shape",
    format = track.format,
    meta = track.meta,
    samples = out,
    diagnostics = track.diagnostics,
    ctx = ctx
  }
end
local StripTopLevelClips
StripTopLevelClips = function(text)
  return LineOps.removeTagCalls(text, {
    "clip",
    "iclip"
  }, true)
end
local ApplyClipText
ApplyClipText = function(text, mode, path)
  return LineOps.prependTag(StripTopLevelClips(text), "\\" .. tostring(mode) .. "(" .. tostring(path) .. ")")
end
local ApplyClipWithAss
ApplyClipWithAss = function(line, mode, path)
  if not (ASS and ASS.parse and ASS.Draw and ASS.Draw.DrawingBase) then
    return nil
  end
  local working = CopyLine(line)
  local ok, result = pcall(function()
    local data = ASS:parse(working)
    data:removeTags({
      "clip_vect",
      "iclip_vect",
      "clip_rect",
      "iclip_rect"
    })
    local drawing = ASS.Draw.DrawingBase({
      str = path
    })
    data:replaceTags({
      ASS:createTag(mode == "iclip" and "iclip_vect" or "clip_vect", drawing)
    })
    data:commit()
    return working.text
  end)
  if ok and result and result ~= "" then
    return result
  else
    return nil
  end
end
local ShapeText
ShapeText = function(path, opts)
  local decimals = clamp(opts.decimals, 0, 6)
  local bounds = PathBounds(path) or {
    l = 0,
    t = 0,
    w = 0,
    h = 0
  }
  local local_path = ShiftPath(path, -bounds.l, -bounds.t, decimals)
  local tags = opts.shape_tags or DEFAULTS.shape_tags
  return "{\\an7\\pos(" .. tostring(FormatNumber(bounds.l, decimals)) .. "," .. tostring(FormatNumber(bounds.t, decimals)) .. ")\\fscx100\\fscy100" .. tostring(tags) .. "\\p1}" .. tostring(local_path) .. "{\\p0}"
end
local RenderShapeLineText
RenderShapeLineText = function(line, mode, path, opts)
  if mode == "shape" then
    return ShapeText(path, opts)
  end
  return ApplyClipWithAss(line, mode, path) or ApplyClipText(line.text or "", mode, path)
end
local GetScriptResolution
GetScriptResolution = function(subs)
  local x, y = LineOps.scriptResolution(subs, DEFAULTS.target_width, DEFAULTS.target_height)
  return {
    x = x,
    y = y
  }
end
local ExclusiveEndFrame
ExclusiveEndFrame = function(startTime, endTime)
  local start_frame = aegisub.frame_from_ms(startTime)
  local end_frame = aegisub.frame_from_ms(endTime)
  if not (start_frame and end_frame) then
    return nil
  end
  return math.max(start_frame + 1, end_frame)
end
local SelectionWindow
SelectionWindow = function(subs, sel)
  local window, err = Media.selectionWindow(subs, sel, {
    includeComments = false,
    positiveDuration = true,
    requireFrames = true
  })
  if not (window) then
    return nil, err or "Select at least one non-comment dialogue line with a positive duration."
  end
  local end_frame = ExclusiveEndFrame(window.min_start, window.max_end)
  if not (end_frame and end_frame > window.start_frame) then
    return nil, "The selection covers no loaded video frames."
  end
  window.end_frame = end_frame
  window.frame_count = end_frame - window.start_frame
  return window
end
local SliceTrack
SliceTrack = function(track, sample_start, count, strict, acceptInterpolation)
  if strict == nil then
    strict = true
  end
  sample_start = KiteCore.finiteNumber(sample_start) or 1
  if not (sample_start == math.floor(sample_start)) then
    return nil, "The first sample must be an integer."
  end
  if not (finite(count) and count > 0 and count == math.floor(count)) then
    return nil, "The sample count must be a positive integer."
  end
  if sample_start < 1 then
    return nil, "The first sample must be 1 or greater."
  end
  if track.kind == "shape" and #track.samples == 1 and count > 1 then
    local out = CopyTable(track)
    out.samples = { }
    local first = track.samples[1]
    for i = 1, count do
      local sample = CopyTable(first)
      sample.source_frame = first.source_frame + i - 1
      sample.held = true
      out.samples[i] = sample
    end
    out.first_frame, out.last_frame = out.samples[1].source_frame, out.samples[#out.samples].source_frame
    out.sample_start = 1
    out.static = true
    do
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = track.diagnostics or { }
      for _index_0 = 1, #_list_0 do
        local item = _list_0[_index_0]
        _accum_0[_len_0] = item
        _len_0 = _len_0 + 1
      end
      out.diagnostics = _accum_0
    end
    out.diagnostics[#out.diagnostics + 1] = "Static Shape repeated exactly for " .. tostring(count) .. " frames."
    return out
  end
  if sample_start + count - 1 > #track.samples then
    local first_source = track.samples[1] and track.samples[1].source_frame or "?"
    local last_source = track.samples[#track.samples] and track.samples[#track.samples].source_frame or "?"
    return nil, "The data has " .. tostring(#track.samples) .. " samples (source frames " .. tostring(first_source) .. ".." .. tostring(last_source) .. "); the selection covers " .. tostring(count) .. " frames and requires " .. tostring(count) .. " samples starting at row " .. tostring(sample_start) .. ". 'Row' is 1-based and is not the value in the Frame column."
  end
  local samples
  do
    local _accum_0 = { }
    local _len_0 = 1
    for i = sample_start, sample_start + count - 1 do
      _accum_0[_len_0] = track.samples[i]
      _len_0 = _len_0 + 1
    end
    samples = _accum_0
  end
  if strict then
    local expected = samples[1].source_frame
    for i, sample in ipairs(samples) do
      if sample.source_frame ~= expected + i - 1 then
        return nil, "Temporal gap: expected source frame " .. tostring(expected + i - 1) .. ", received " .. tostring(sample.source_frame) .. "."
      end
      if sample.interpolated and not acceptInterpolation then
        return nil, "Source frame " .. tostring(sample.source_frame) .. " was interpolated; disable strict synchronization to accept it."
      end
      if sample.ambiguous_rotation then
        return nil, "Ambiguous Rotation at source frame " .. tostring(sample.source_frame) .. " (" .. FormatNumber(sample.ambiguous_rotation, 3) .. " degree jump). Normalize the export or disable strict synchronization."
      end
    end
  end
  local out = CopyTable(track)
  out.samples = samples
  out.first_frame, out.last_frame = samples[1].source_frame, samples[#samples].source_frame
  out.sample_start = sample_start
  return out
end
local CanonicalFPS
CanonicalFPS = function(fps)
  fps = tonumber(fps)
  if not (fps and fps > 0) then
    return nil
  end
  local _list_0 = {
    {
      23.976,
      24000 / 1001
    },
    {
      29.97,
      30000 / 1001
    },
    {
      47.952,
      48000 / 1001
    },
    {
      59.94,
      60000 / 1001
    },
    {
      119.88,
      120000 / 1001
    }
  }
  for _index_0 = 1, #_list_0 do
    local pair = _list_0[_index_0]
    local nominal, exact = pair[1], pair[2]
    if math.abs(fps - nominal) <= 0.0005 or math.abs(fps - exact) <= 0.0005 then
      return exact
    end
  end
  return fps
end
local TimingDiagnostics
TimingDiagnostics = function(track, window)
  local diagnostics = { }
  local startMs = aegisub.ms_from_frame(window.start_frame)
  local endMs = aegisub.ms_from_frame(window.end_frame)
  if not (startMs and endMs) then
    return diagnostics
  end
  local duration = endMs - startMs
  if duration > 0 then
    local localFps = window.frame_count * 1000 / duration
    diagnostics.local_fps = localFps
    diagnostics.actual_duration_ms = duration
    if track.meta and track.meta.fps then
      local effectiveFps = CanonicalFPS(track.meta.fps)
      if effectiveFps then
        diagnostics.effective_export_fps = effectiveFps
        diagnostics.fps_delta = math.abs(effectiveFps - localFps)
        diagnostics.expected_duration_ms = window.frame_count * 1000 / effectiveFps
        diagnostics.duration_delta_ms = math.abs(duration - diagnostics.expected_duration_ms)
      end
    end
    local maxPhase = 0
    for i = 0, window.frame_count do
      local actual = aegisub.ms_from_frame(window.start_frame + i)
      if not (actual) then
        return diagnostics
      end
      local predicted = startMs + duration * i / window.frame_count
      maxPhase = math.max(maxPhase, math.abs(actual - predicted))
    end
    diagnostics.max_timeline_phase_ms = maxPhase
  end
  return diagnostics
end
local ValidateSync
ValidateSync = function(track, window, strict, ordinalExact)
  if ordinalExact == nil then
    ordinalExact = false
  end
  local info = TimingDiagnostics(track, window)
  if strict and not ordinalExact and not track.static and info.duration_delta_ms and info.duration_delta_ms > 2.5 then
    return nil, "Duration mismatch: export " .. tostring(FormatNumber(info.expected_duration_ms, 3)) .. " ms, timeline " .. tostring(FormatNumber(info.actual_duration_ms, 3)) .. " ms (delta " .. tostring(FormatNumber(info.duration_delta_ms, 3)) .. " ms)."
  end
  if strict and not ordinalExact and not track.static and (info.max_timeline_phase_ms or 0) > 2.5 then
    return nil, "Variable or irregular timeline: phase differs by " .. tostring(FormatNumber(info.max_timeline_phase_ms, 3)) .. " ms from CFR sampling."
  end
  if strict and track.meta and track.meta.source_par and track.meta.comp_par and math.abs(track.meta.source_par - track.meta.comp_par) > 0.0001 then
    return nil, "Pixel-aspect mismatch (source " .. tostring(track.meta.source_par) .. ", comp " .. tostring(track.meta.comp_par) .. "); it will not be approximated silently."
  end
  return info
end
local SameOutputState
SameOutputState = function(a, b)
  if not (a and b and a.end_time == b.start_time) then
    return false
  end
  if FBFOptimizer.hasDurationTags(a.text) then
    return false
  end
  if not (LineOps.shallowEqual(a.extra, b.extra)) then
    return false
  end
  local _list_0 = {
    "text",
    "layer",
    "style",
    "actor",
    "effect",
    "margin_l",
    "margin_r",
    "margin_t",
    "comment"
  }
  for _index_0 = 1, #_list_0 do
    local key = _list_0[_index_0]
    if a[key] ~= b[key] then
      return false
    end
  end
  return true
end
local CompressOutputLines
CompressOutputLines = function(lines)
  local out = { }
  for _index_0 = 1, #lines do
    local line = lines[_index_0]
    if #out > 0 and SameOutputState(out[#out], line) then
      out[#out].end_time = line.end_time
    else
      out[#out + 1] = line
    end
  end
  return out
end
FBFOptimizer.DEFAULT_TOLERANCE = 0.05
FBFOptimizer.MODES = {
  {
    label = "Conservative (0.05 px)",
    tolerance = 0.05
  },
  {
    label = "Exact (0 px)",
    tolerance = 0
  },
  {
    label = "Subpixel (0.10 px)",
    tolerance = 0.10
  }
}
FBFOptimizer.sameFields = function(left, right)
  if not (left and right) then
    return false
  end
  if not (LineOps.shallowEqual(left.extra, right.extra)) then
    return false
  end
  local _list_0 = {
    "class",
    "layer",
    "style",
    "actor",
    "effect",
    "margin_l",
    "margin_r",
    "margin_t",
    "margin_b",
    "margin_v",
    "comment"
  }
  for _index_0 = 1, #_list_0 do
    local key = _list_0[_index_0]
    if left[key] ~= right[key] then
      return false
    end
  end
  return true
end
FBFOptimizer.metadataKey = function(line)
  return table.concat((function()
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = {
      "class",
      "layer",
      "style",
      "actor",
      "effect",
      "margin_l",
      "margin_r",
      "margin_t",
      "margin_b",
      "margin_v",
      "comment"
    }
    for _index_0 = 1, #_list_0 do
      local key = _list_0[_index_0]
      _accum_0[_len_0] = tostring(line[key] or "")
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)(), "\31")
end
FBFOptimizer.hasDurationTags = function(text)
  local _list_0 = {
    "move",
    "t",
    "fad",
    "fade",
    "k",
    "kf",
    "ko",
    "kt"
  }
  for _index_0 = 1, #_list_0 do
    local name = _list_0[_index_0]
    if LineOps.hasTag(text, name, false) then
      return true
    end
  end
  return false
end
FBFOptimizer.drawingTemplate = function(text, analysis)
  local parts = { }
  local geometryTags = {
    "p",
    "pos",
    "fscx",
    "fscy",
    "frz",
    "fr"
  }
  local _list_0 = analysis.sections
  for _index_0 = 1, #_list_0 do
    local section = _list_0[_index_0]
    if section.type == "override" then
      parts[#parts + 1] = LineOps.removeTagCalls("{" .. section.text .. "}", geometryTags)
    elseif section.type == "drawing" then
      local topology = section.text:gsub(NUM_PATTERN, "#")
      topology = topology:gsub("%s+", " ")
      parts[#parts + 1] = "<drawing:" .. tostring(trim(topology)) .. ">"
    elseif section.type == "comment" then
      parts[#parts + 1] = "{" .. section.text .. "}"
    else
      parts[#parts + 1] = section.text
    end
  end
  return table.concat(parts)
end
FBFOptimizer.state = function(line)
  local text = tostring(line and line.text or "")
  local duration_unsafe = FBFOptimizer.hasDurationTags(text)
  local analysis = LineOps.analyzeText(text)
  if not (analysis.has_drawing) then
    local position = LineOps.position(text)
    local template
    if position then
      template = LineOps.removeTagCalls(text, "pos")
    else
      template = text
    end
    return {
      kind = "text",
      text = text,
      template = template,
      position = position,
      duration_unsafe = duration_unsafe,
      lane_key = template
    }
  end
  local drawing_unsafe = false
  local _list_0 = {
    "org",
    "frx",
    "fry",
    "fax",
    "fay",
    "clip",
    "iclip",
    "r"
  }
  for _index_0 = 1, #_list_0 do
    local name = _list_0[_index_0]
    if LineOps.hasTag(text, name, false) then
      drawing_unsafe = true
      break
    end
  end
  local scales, drawing_scale = { }, nil
  local drawing = { }
  local _list_1 = analysis.sections
  for _index_0 = 1, #_list_1 do
    local section = _list_1[_index_0]
    if section.type == "drawing" and trim(section.text) ~= "" then
      local scale = tonumber(section.drawing)
      if scale and scale > 0 then
        scales[scale] = true
      end
      drawing_scale = drawing_scale or scale
      drawing[#drawing + 1] = section.text
    end
  end
  local scaleCount = 0
  for _ in pairs(scales) do
    scaleCount = scaleCount + 1
  end
  if scaleCount ~= 1 then
    drawing_unsafe = true
  end
  local path = table.concat(drawing, " ")
  local coordinates
  do
    local _accum_0 = { }
    local _len_0 = 1
    for value in path:gmatch(NUM_PATTERN) do
      _accum_0[_len_0] = tonumber(value)
      _len_0 = _len_0 + 1
    end
    coordinates = _accum_0
  end
  if #coordinates == 0 or #coordinates % 2 ~= 0 then
    drawing_unsafe = true
  end
  local position = LineOps.position(text)
  local scale_x = LineOps.tagNumber(text, "fscx", 100, true)
  local scale_y = LineOps.tagNumber(text, "fscy", 100, true)
  local rotation, rotationCall = LineOps.tagNumber(text, "frz", nil, true)
  if not (rotationCall) then
    rotation = LineOps.tagNumber(text, "fr", 0, true)
  end
  local align = LineOps.tagNumber(text, "an", 7, true)
  local template = FBFOptimizer.drawingTemplate(text, analysis)
  return {
    kind = "drawing",
    text = text,
    template = template,
    position = position,
    duration_unsafe = duration_unsafe,
    drawing_unsafe = drawing_unsafe,
    p = drawing_scale,
    scale_x = scale_x,
    scale_y = scale_y,
    rotation = rotation,
    align = align,
    coordinates = coordinates,
    path = path,
    lane_key = template
  }
end
FBFOptimizer.geometryPoints = function(state)
  if not (state and state.position and state.p and state.p > 0) then
    return nil
  end
  if not (finite(state.scale_x) and finite(state.scale_y) and finite(state.rotation)) then
    return nil
  end
  local denominator = 2 ^ (state.p - 1)
  local angle = math.rad(state.rotation)
  local cosine, sine = math.cos(angle), math.sin(angle)
  local points = { }
  for index = 1, #state.coordinates, 2 do
    local x = state.coordinates[index] * state.scale_x / 100 / denominator
    local y = state.coordinates[index + 1] * state.scale_y / 100 / denominator
    points[#points + 1] = {
      x = x * cosine - y * sine + state.position.x,
      y = x * sine + y * cosine + state.position.y
    }
  end
  return points
end
FBFOptimizer.distance = function(left, right)
  return math.sqrt((left.x - right.x) ^ 2 + (left.y - right.y) ^ 2)
end
FBFOptimizer.compatible = function(left, right, tolerance)
  if tolerance == nil then
    tolerance = FBFOptimizer.DEFAULT_TOLERANCE
  end
  if not (left and right) then
    return false
  end
  if left.duration_unsafe or right.duration_unsafe then
    return false
  end
  if left.text == right.text then
    return true
  end
  if not (left.kind == right.kind and left.template == right.template) then
    return false
  end
  tolerance = math.max(0, tonumber(tolerance) or FBFOptimizer.DEFAULT_TOLERANCE)
  if left.kind == "text" then
    if not (left.position and right.position) then
      return false
    end
    return FBFOptimizer.distance(left.position, right.position) <= tolerance + numericEpsilon
  end
  if left.drawing_unsafe or right.drawing_unsafe then
    return false
  end
  if not (left.p == right.p and #left.coordinates == #right.coordinates) then
    return false
  end
  if left.align ~= 7 or right.align ~= 7 then
    if not (left.path == right.path) then
      return false
    end
    if not (math.abs(left.scale_x - right.scale_x) <= numericEpsilon) then
      return false
    end
    if not (math.abs(left.scale_y - right.scale_y) <= numericEpsilon) then
      return false
    end
    if not (math.abs(left.rotation - right.rotation) <= numericEpsilon) then
      return false
    end
    return left.position and right.position and FBFOptimizer.distance(left.position, right.position) <= tolerance + numericEpsilon
  end
  local leftPoints, rightPoints = FBFOptimizer.geometryPoints(left), FBFOptimizer.geometryPoints(right)
  if not (leftPoints and rightPoints and #leftPoints == #rightPoints) then
    return false
  end
  for index = 1, #leftPoints do
    if FBFOptimizer.distance(leftPoints[index], rightPoints[index]) > tolerance + numericEpsilon then
      return false
    end
  end
  return true
end
FBFOptimizer.selectionItems = function(subs, selection)
  local records = LineOps.selectedLines(subs, selection, function(line)
    return line and line.class == "dialogue" and not line.comment and tonumber(line.end_time) and tonumber(line.start_time) and line.end_time > line.start_time
  end)
  local items = { }
  local _list_0 = records or { }
  for _index_0 = 1, #_list_0 do
    local record = _list_0[_index_0]
    items[#items + 1] = {
      index = record.index,
      line = record.line,
      state = FBFOptimizer.state(record.line)
    }
  end
  return items
end
FBFOptimizer.buildPlan = function(items, tolerance)
  if tolerance == nil then
    tolerance = FBFOptimizer.DEFAULT_TOLERANCE
  end
  local ordered
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = items or { }
    for _index_0 = 1, #_list_0 do
      local item = _list_0[_index_0]
      _accum_0[_len_0] = item
      _len_0 = _len_0 + 1
    end
    ordered = _accum_0
  end
  table.sort(ordered, function(left, right)
    if left.line.start_time == right.line.start_time then
      if left.line.end_time == right.line.end_time then
        return left.index < right.index
      else
        return left.line.end_time < right.line.end_time
      end
    else
      return left.line.start_time < right.line.start_time
    end
  end)
  local lanes = { }
  for _index_0 = 1, #ordered do
    local item = ordered[_index_0]
    item.state = item.state or FBFOptimizer.state(item.line)
    item.lane_key = FBFOptimizer.metadataKey(item.line) .. "\31" .. tostring(item.state.lane_key or item.line.text or "")
    local lane = nil
    for _index_1 = 1, #lanes do
      local candidate = lanes[_index_1]
      if candidate.last.line.end_time == item.line.start_time and candidate.key == item.lane_key and FBFOptimizer.sameFields(candidate.last.line, item.line) then
        lane = candidate
        break
      end
    end
    if not (lane) then
      lane = {
        key = item.lane_key,
        items = { }
      }
      lanes[#lanes + 1] = lane
    end
    lane.items[#lane.items + 1] = item
    lane.last = item
  end
  local plan = {
    before = #ordered,
    after = #ordered,
    merged = 0,
    longest_run = 0,
    unsafe_count = 0,
    lanes = lanes,
    updates = { },
    deletes = { },
    retained = { }
  }
  for _index_0 = 1, #ordered do
    local item = ordered[_index_0]
    if item.state.duration_unsafe then
      plan.unsafe_count = plan.unsafe_count + 1
    end
  end
  for _index_0 = 1, #lanes do
    local lane = lanes[_index_0]
    local anchor, previous, run = nil, nil, 0
    local _list_0 = lane.items
    for _index_1 = 1, #_list_0 do
      local item = _list_0[_index_1]
      if anchor and previous.line.end_time == item.line.start_time and FBFOptimizer.sameFields(anchor.line, item.line) and FBFOptimizer.compatible(anchor.state, item.state, tolerance) then
        plan.updates[anchor.index] = item.line.end_time
        plan.deletes[#plan.deletes + 1] = item.index
        plan.retained[item.index] = nil
        plan.merged = plan.merged + 1
        run = run + 1
      else
        anchor = item
        plan.retained[item.index] = true
        run = 1
      end
      previous = item
      plan.longest_run = math.max(plan.longest_run, run)
    end
  end
  plan.after = plan.before - plan.merged
  return plan
end
FBFOptimizer.applyPlan = function(subs, plan)
  for index, endTime in pairs(plan.updates or { }) do
    LineOps.checkCancelled()
    local line = CopyLine(subs[index])
    line.end_time = endTime
    subs[index] = line
  end
  local deleted
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = plan.deletes or { }
    for _index_0 = 1, #_list_0 do
      local index = _list_0[_index_0]
      _accum_0[_len_0] = index
      _len_0 = _len_0 + 1
    end
    deleted = _accum_0
  end
  table.sort(deleted)
  LineOps.deleteIndices(subs, deleted)
  local selection = { }
  local retained
  do
    local _accum_0 = { }
    local _len_0 = 1
    for index, keep in pairs(plan.retained or { }) do
      if keep then
        _accum_0[_len_0] = index
        _len_0 = _len_0 + 1
      end
    end
    retained = _accum_0
  end
  table.sort(retained)
  local shift = 0
  for _index_0 = 1, #retained do
    local original = retained[_index_0]
    while deleted[shift + 1] and deleted[shift + 1] < original do
      shift = shift + 1
    end
    selection[#selection + 1] = original - shift
  end
  return selection
end
FBFOptimizer.optimize = function(subs, selection, tolerance)
  if tolerance == nil then
    tolerance = FBFOptimizer.DEFAULT_TOLERANCE
  end
  local items = FBFOptimizer.selectionItems(subs, selection)
  local plan = FBFOptimizer.buildPlan(items, tolerance)
  if plan.merged == 0 then
    return selection, plan
  end
  return FBFOptimizer.applyPlan(subs, plan), plan
end
FBFOptimizer.toleranceForMode = function(label)
  local _list_0 = FBFOptimizer.MODES
  for _index_0 = 1, #_list_0 do
    local mode = _list_0[_index_0]
    if mode.label == label then
      return mode.tolerance
    end
  end
  return nil
end
FBFOptimizer.canRun = function(subs, selection)
  return #FBFOptimizer.selectionItems(subs, selection) > 1
end
local FrameInterval
FrameInterval = function(line, frame)
  local startTime = math.max(line.start_time, aegisub.ms_from_frame(frame))
  local last_frame = ExclusiveEndFrame(line.start_time, line.end_time) - 1
  local endTime
  if frame == last_frame then
    endTime = line.end_time
  else
    endTime = math.min(line.end_time, aegisub.ms_from_frame(frame + 1))
  end
  if not (endTime > startTime) then
    return nil
  end
  return startTime, endTime
end
local ReplaceOrInsertOutputs
ReplaceOrInsertOutputs = function(subs, index, outputs, replace)
  if #outputs == 0 then
    return
  end
  if replace then
    subs[index] = outputs[1]
    for i = #outputs, 2, -1 do
      LineOps.checkCancelled()
      subs.insert(index + 1, outputs[i])
    end
  else
    for i = #outputs, 1, -1 do
      LineOps.checkCancelled()
      subs.insert(index + 1, outputs[i])
    end
  end
end
local SelectionFromGroups
SelectionFromGroups = function(groups)
  local ordered
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = groups or { }
    for _index_0 = 1, #_list_0 do
      local group = _list_0[_index_0]
      _accum_0[_len_0] = group
      _len_0 = _len_0 + 1
    end
    ordered = _accum_0
  end
  table.sort(ordered, function(a, b)
    return a.index < b.index
  end)
  local selected, shift = { }, 0
  for _index_0 = 1, #ordered do
    local group = ordered[_index_0]
    local count = math.max(0, tonumber(group.count) or 0)
    local startIndex = group.index + shift + (group.replace and 0 or 1)
    for offset = 0, count - 1 do
      selected[#selected + 1] = startIndex + offset
    end
    shift = shift + (count - (group.replace and 1 or 0))
  end
  return selected
end
local ApplyShapeTrack
ApplyShapeTrack = function(subs, window, track, opts)
  local script_res = GetScriptResolution(subs)
  local prepared, err = PrepareShapeSamples(track, opts, script_res)
  if not (prepared) then
    return nil, err
  end
  local mode = opts.output_mode or DEFAULTS.output_mode
  local replace = opts.placement ~= "Insert new lines"
  local wrappedByIndex, groups = { }, { }
  if mode ~= "shape" then
    local collection = LineCollection(subs, window.indices, AcceptDialogueLine, false)
    local _list_0 = collection.lines
    for _index_0 = 1, #_list_0 do
      local line = _list_0[_index_0]
      wrappedByIndex[line.number] = line
    end
  end
  for position = #window.indices, 1, -1 do
    LineOps.checkCancelled()
    local index = window.indices[position]
    local base = subs[index]
    local outputs = { }
    local first_frame = aegisub.frame_from_ms(base.start_time)
    local last_frame = ExclusiveEndFrame(base.start_time, base.end_time)
    local fbfByFrame = { }
    if mode ~= "shape" then
      local source = wrappedByIndex[index]
      if not (source) then
        return nil, "Line " .. tostring(index) .. ": temporal tags could not be baked."
      end
      source.startFrame, source.endFrame = first_frame, last_frame
      local sourceData = ASS:parse(source)
      local _list_0 = AssContext.line2fbf(sourceData, ArchUtil, ASS)
      for _index_0 = 1, #_list_0 do
        local frameLine = _list_0[_index_0]
        local frame = frameLine.startFrame or aegisub.frame_from_ms(frameLine.start_time)
        fbfByFrame[frame] = frameLine
      end
    end
    for frame = first_frame, last_frame - 1 do
      local _continue_0 = false
      repeat
        LineOps.checkCancelled()
        local sampleIndex
        if opts.mapping_mode == "Restart on each line" then
          sampleIndex = frame - first_frame + 1
        else
          sampleIndex = frame - window.start_frame + 1
        end
        local sample = prepared.samples[sampleIndex]
        if not (sample) then
          _continue_0 = true
          break
        end
        local startTime, endTime = FrameInterval(base, frame)
        if not (startTime) then
          _continue_0 = true
          break
        end
        local line
        if mode == "shape" then
          line = CopyLine(base)
        else
          line = fbfByFrame[frame]
        end
        if not (line) then
          return nil, "Line " .. tostring(index) .. ", frame " .. tostring(frame) .. ": ASS state could not be baked."
        end
        line.start_time, line.end_time = startTime, endTime
        if mode ~= "shape" then
          ShiftFrameKaraoke(line, base.start_time, startTime)
        end
        line.comment = false
        line.layer = (tonumber(base.layer) or 0) + (replace and 0 or tonumber(opts.layer_offset) or 1)
        line.text = RenderShapeLineText(line, mode, sample.path, opts)
        outputs[#outputs + 1] = CopyLine(line)
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    outputs = CompressOutputLines(outputs)
    if #outputs == 0 then
      return nil, "Line " .. tostring(index) .. ": no Shape output was generated."
    end
    ReplaceOrInsertOutputs(subs, index, outputs, replace)
    groups[#groups + 1] = {
      index = index,
      count = #outputs,
      replace = replace
    }
  end
  return true, {
    selection = SelectionFromGroups(groups),
    groups = groups
  }
end
Core.BuildShapeContext = BuildShapeContext
Core.RenderShapePath = RenderShapePath
Core.PrepareShapeSamples = PrepareShapeSamples
Core.ShapeText = ShapeText
Core.RenderShapeLineText = RenderShapeLineText
Core.StripTopLevelClips = StripTopLevelClips
Core.ApplyClipText = ApplyClipText
Core.SelectionWindow = SelectionWindow
Core.ExclusiveEndFrame = ExclusiveEndFrame
Core.SliceTrack = SliceTrack
Core.CanonicalFPS = CanonicalFPS
Core.TimingDiagnostics = TimingDiagnostics
Core.ValidateSync = ValidateSync
Core.CompressOutputLines = CompressOutputLines
Core.SelectionFromGroups = SelectionFromGroups
Core.ApplyShapeTrack = ApplyShapeTrack
local ScaleTrackCoordinates
ScaleTrackCoordinates = function(track, script_res, opts)
  local out = CopyTable(track)
  out.meta = CopyTable(track.meta)
  out.samples = { }
  local source_w
  if opts.use_source_meta and track.meta and track.meta.source_width then
    source_w = track.meta.source_width
  else
    source_w = tonumber(opts.source_width)
  end
  local source_h
  if opts.use_source_meta and track.meta and track.meta.source_height then
    source_h = track.meta.source_height
  else
    source_h = tonumber(opts.source_height)
  end
  if not (source_w and source_w > 0) then
    source_w = script_res.x
  end
  if not (source_h and source_h > 0) then
    source_h = script_res.y
  end
  local sx = opts.scale_to_script and script_res.x / source_w or 1
  local sy = opts.scale_to_script and script_res.y / source_h or 1
  local dx, dy = tonumber(opts.offset_x) or 0, tonumber(opts.offset_y) or 0
  local _list_0 = track.samples
  for _index_0 = 1, #_list_0 do
    local sample = _list_0[_index_0]
    LineOps.checkCancelled()
    local copy = CopyTable(sample)
    if sample.position then
      copy.position = {
        x = sample.position.x * sx + dx,
        y = sample.position.y * sy + dy
      }
    end
    if sample.anchor then
      copy.anchor = {
        x = sample.anchor.x * sx + dx,
        y = sample.anchor.y * sy + dy
      }
    end
    if sample.scale then
      copy.scale = {
        x = sample.scale.x,
        y = sample.scale.y
      }
    end
    if sample.quad then
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_1 = sample.quad
        for _index_1 = 1, #_list_1 do
          local point = _list_1[_index_1]
          _accum_0[_len_0] = {
            x = point.x * sx + dx,
            y = point.y * sy + dy
          }
          _len_0 = _len_0 + 1
        end
        copy.quad = _accum_0
      end
    end
    copy.coordinate_scale = {
      x = sx,
      y = sy
    }
    out.samples[#out.samples + 1] = copy
  end
  out.coordinate_scale = {
    x = sx,
    y = sy,
    dx = dx,
    dy = dy,
    source_w = source_w,
    source_h = source_h
  }
  return out
end
local RotateVector
RotateVector = function(x, y, radians)
  local c, s = math.cos(radians), math.sin(radians)
  return x * c - y * s, x * s + y * c
end
local TransformPoint
TransformPoint = function(x, y, sample, reference)
  local refSx = (reference.scale and reference.scale.x or 100) / 100
  local refSy = (reference.scale and reference.scale.y or 100) / 100
  local curSx = (sample.scale and sample.scale.x or 100) / 100
  local curSy = (sample.scale and sample.scale.y or 100) / 100
  if math.abs(refSx) < scaleEpsilon or math.abs(refSy) < scaleEpsilon then
    return nil, nil, "Zero scale at the reference frame."
  end
  local coord = reference.coordinate_scale or sample.coordinate_scale or {
    x = 1,
    y = 1
  }
  local coordX, coordY = tonumber(coord.x) or 1, tonumber(coord.y) or 1
  if math.abs(coordX) < scaleEpsilon or math.abs(coordY) < scaleEpsilon then
    return nil, nil, "Invalid coordinate scale."
  end
  local dx, dy = (x - reference.position.x) / coordX, (y - reference.position.y) / coordY
  dx, dy = RotateVector(dx, dy, math.rad(reference.rotation or 0))
  dx, dy = dx / refSx, dy / refSy
  dx, dy = dx * curSx, dy * curSy
  dx, dy = RotateVector(dx, dy, -math.rad(sample.rotation or 0))
  return sample.position.x + dx * coordX, sample.position.y + dy * coordY
end
local InverseTransformPoint
InverseTransformPoint = function(x, y, sample, reference)
  local refSx = (reference.scale and reference.scale.x or 100) / 100
  local refSy = (reference.scale and reference.scale.y or 100) / 100
  local curSx = (sample.scale and sample.scale.x or 100) / 100
  local curSy = (sample.scale and sample.scale.y or 100) / 100
  if math.abs(curSx) < scaleEpsilon or math.abs(curSy) < scaleEpsilon then
    return nil, nil, "Current scale is zero; the transform cannot be inverted."
  end
  local coord = reference.coordinate_scale or sample.coordinate_scale or {
    x = 1,
    y = 1
  }
  local coordX, coordY = tonumber(coord.x) or 1, tonumber(coord.y) or 1
  if math.abs(coordX) < scaleEpsilon or math.abs(coordY) < scaleEpsilon then
    return nil, nil, "Invalid coordinate scale."
  end
  local dx, dy = (x - sample.position.x) / coordX, (y - sample.position.y) / coordY
  dx, dy = RotateVector(dx, dy, math.rad(sample.rotation or 0))
  dx, dy = dx / curSx, dy / curSy
  dx, dy = dx * refSx, dy * refSy
  dx, dy = RotateVector(dx, dy, -math.rad(reference.rotation or 0))
  return reference.position.x + dx * coordX, reference.position.y + dy * coordY
end
local MotionPoint
MotionPoint = function(x, y, sample, reference, options)
  if options and options.inverse then
    return InverseTransformPoint(x, y, sample, reference)
  else
    return TransformPoint(x, y, sample, reference)
  end
end
local EffectiveTransformSample
EffectiveTransformSample = function(sample, reference, options, prefix)
  if prefix == nil then
    prefix = ""
  end
  local enabled
  enabled = function(name, fallback)
    if fallback == nil then
      fallback = true
    end
    local value = options[prefix .. name]
    if value == nil then
      return fallback
    else
      return value
    end
  end
  local copy = CopyTable(sample)
  local position_x, position_y = reference.position.x, reference.position.y
  if enabled("x_position") then
    position_x = sample.position.x
  end
  if enabled("y_position") then
    position_y = sample.position.y
  end
  copy.position = {
    x = position_x,
    y = position_y
  }
  if enabled("scale") then
    copy.scale = {
      x = sample.scale.x,
      y = sample.scale.y
    }
  else
    copy.scale = {
      x = reference.scale.x,
      y = reference.scale.y
    }
  end
  if enabled("rotation") then
    copy.rotation = sample.rotation
  else
    copy.rotation = reference.rotation
  end
  return copy
end
local mapPathCoordinates = require("kite.ShapeOptimizer").AssDrawing.mapCoordinates
local RectClipToPath
RectClipToPath = function(content)
  local args = LineOps.splitArguments(content)
  if not (#args == 4) then
    return nil
  end
  local values
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #args do
      local value = args[_index_0]
      _accum_0[_len_0] = KiteCore.finiteNumber(value)
      _len_0 = _len_0 + 1
    end
    values = _accum_0
  end
  if not (#values == 4) then
    return nil
  end
  local l, t, r, b = unpack(values)
  return "m " .. tostring(l) .. " " .. tostring(t) .. " l " .. tostring(r) .. " " .. tostring(t) .. " " .. tostring(r) .. " " .. tostring(b) .. " " .. tostring(l) .. " " .. tostring(b)
end
local ClipToFloatPath
ClipToFloatPath = function(content)
  local AssDrawing = require("kite.ShapeOptimizer").AssDrawing
  content = trim(content)
  local rectangle = RectClipToPath(content)
  if rectangle then
    return rectangle, true
  end
  local scale, path = content:match("^(%d+)%s*,%s*(.*)$")
  if not (scale) then
    if not (AssDrawing.validatePath(content)) then
      return nil, false
    end
    return content, false
  end
  scale = KiteCore.finiteNumber(scale)
  if not (scale and scale >= 1 and scale == math.floor(scale)) then
    return nil, false
  end
  local factor = 2 ^ (scale - 1)
  if not (finite(factor) and AssDrawing.validatePath(path)) then
    return nil, false
  end
  return mapPathCoordinates(path, (function(x, y)
    return x / factor, y / factor
  end), 6), false
end
local TransformClipPath
TransformClipPath = function(path, sample, reference, decimals, options)
  if decimals == nil then
    decimals = 2
  end
  if options == nil then
    options = nil
  end
  return mapPathCoordinates(path, (function(x, y)
    return MotionPoint(x, y, sample, reference, options)
  end), decimals)
end
local TranslateClipPath
TranslateClipPath = function(path, dx, dy, decimals)
  if decimals == nil then
    decimals = 2
  end
  if math.abs(dx) < numericEpsilon and math.abs(dy) < numericEpsilon then
    return path
  end
  return mapPathCoordinates(path, (function(x, y)
    return x + dx, y + dy
  end), decimals)
end
local importantTags = {
  xscale = {
    opt = "scale",
    skip = 0
  },
  yscale = {
    opt = "scale",
    skip = 0
  },
  border = {
    opt = "border",
    skip = 0
  },
  shadow = {
    opt = "shadow",
    skip = 0
  },
  zrot = {
    opt = "rotation"
  }
}
local GetMissingTags
GetMissingTags = function(block, options, properties)
  local result = { }
  for key, spec in pairs(importantTags) do
    local tag = Tags.allTags[key]
    if options[spec.opt] and not block:match(tag.pattern) and properties[tag] ~= spec.skip then
      result[#result + 1] = tag:format(properties[tag])
    end
  end
  return table.concat(result)
end
local PrepareStaticLine
PrepareStaticLine = function(line, options)
  line.hasOrg, line.hasClip = false, false
  line:getPropertiesFromStyle()
  if not (line:extraMetrics(line.styleRef)) then
    line:ensureLeadingOverrideBlockExists()
    line:runCallbackOnFirstOverride(function(self, tagBlock)
      return tagBlock:gsub("{", ("{\\pos(%g,%g)"):format(self.xPosition, self.yPosition))
    end)
  end
  line:runCallbackOnFirstOverride(function(self, tagBlock)
    local tags = GetMissingTags(tagBlock, options, line.properties)
    return "{" .. tags .. tagBlock:sub(2)
  end)
  local styles = line.parentCollection and line.parentCollection.styles or { }
  line:runCallbackOnOverrides(function(self, tagBlock)
    tagBlock:gsub("\\org%([%.%d%-]+,[%.%d%-]+%)", function()
      line.hasOrg = true
      return nil
    end)
    local savedStyle, reset = line.styleRef, false
    tagBlock = tagBlock:gsub("\\r([^\\}]*)([^}]*)", function(resetStyle, remainder)
      if styles[resetStyle] then
        line.styleRef = styles[resetStyle]
        line:getPropertiesFromStyle()
        reset = true
      end
      local tags = GetMissingTags(remainder, options, line.properties)
      return "\\r" .. resetStyle .. tags .. remainder
    end)
    if reset then
      line.styleRef = savedStyle
      line:getPropertiesFromStyle()
    end
    local _list_0 = {
      "(\\clip%b())",
      "(\\iclip%b())"
    }
    for _index_0 = 1, #_list_0 do
      local pattern = _list_0[_index_0]
      tagBlock = tagBlock:gsub(pattern, function(clip)
        line.hasClip = true
        return clip
      end)
    end
    return tagBlock
  end)
  return line
end
local ApplyTransformText
ApplyTransformText = function(line, sample, reference, options)
  local text = line.text
  local effectiveSample = EffectiveTransformSample(sample, reference, options)
  local snapX, snapY = 0, 0
  if options.absolute and not options.only_clip and not options.inverse then
    local posX, posY = AssContext.explicitPosition(text, (line.end_time or 0) - (line.start_time or 0), 0)
    if posX and posY then
      local relativeX, relativeY, snapErr = MotionPoint(posX, posY, effectiveSample, reference, options)
      if not (snapErr) then
        if options.x_position then
          snapX = effectiveSample.position.x - relativeX
        end
        if options.y_position then
          snapY = effectiveSample.position.y - relativeY
        end
      end
    end
  end
  if not (options.only_clip) then
    text = LineOps.mapTagCalls(text, {
      "pos",
      "org"
    }, function(call)
      if call.name == "org" and not options.origin then
        return nil
      end
      local args = LineOps.splitArguments(call.value)
      local x, y = KiteCore.finiteNumber(args[1]), KiteCore.finiteNumber(args[2])
      if not (#args == 2 and x and y) then
        return nil
      end
      local tx, ty, err = MotionPoint(x, y, effectiveSample, reference, options)
      assert(not err, err)
      return "\\" .. tostring(call.raw_name) .. "(" .. tostring(FormatNumber(tx + snapX, 2)) .. "," .. tostring(FormatNumber(ty + snapY, 2)) .. ")"
    end)
    local rx = (effectiveSample.scale.x or 100) / (reference.scale.x or 100)
    local ry = (effectiveSample.scale.y or 100) / (reference.scale.y or 100)
    if options.inverse then
      assert(math.abs(rx) > scaleEpsilon and math.abs(ry) > scaleEpsilon, "A zero scale cannot be inverted.")
      rx, ry = 1 / rx, 1 / ry
    end
    local scalar = math.sqrt(math.abs(rx * ry))
    local factors = { }
    if options.scale then
      factors.fscx, factors.fscy = rx, ry
    end
    if options.border then
      factors.xbord, factors.ybord, factors.bord = math.abs(rx), math.abs(ry), scalar
    end
    if options.shadow then
      factors.xshad, factors.yshad, factors.shad = rx, ry, scalar
    end
    if options.blur then
      factors.blur = 1 - (1 - scalar) * (KiteCore.finiteNumber(options.blur_scale) or 1)
    end
    local rotationDelta = (effectiveSample.rotation - reference.rotation) * (options.inverse and -1 or 1)
    local selected
    do
      local _tbl_0 = { }
      for name in pairs(factors) do
        _tbl_0[name] = true
      end
      selected = _tbl_0
    end
    if options.rotation then
      selected.fr, selected.frz = true, true
    end
    text = LineOps.mapTagCalls(text, selected, (function(call)
      local value = KiteCore.finiteNumber(call.value)
      if not (value) then
        return nil
      end
      if factors[call.name] then
        value = value * factors[call.name]
      else
        value = value + rotationDelta
      end
      assert(finite(value), "Non-finite transformed tag.")
      return "\\" .. tostring(call.raw_name) .. tostring(FormatNumber(value, 2))
    end), {
      top_level_only = false
    })
  end
  if options.track_clip then
    local cs, cr = effectiveSample, reference
    local ApplyClip
    ApplyClip = function(tag_name, wrapped)
      local content = wrapped:sub(2, -2)
      local path, wasRect = ClipToFloatPath(content)
      if not (path) then
        return "\\" .. tostring(tag_name) .. tostring(wrapped)
      end
      if wasRect and options.rect_clip == false then
        return "\\" .. tostring(tag_name) .. tostring(wrapped)
      end
      if not wasRect and options.vector_clip == false then
        return "\\" .. tostring(tag_name) .. tostring(wrapped)
      end
      local moved = TransformClipPath(path, cs, cr, options.decimals or 2, options)
      moved = TranslateClipPath(moved, snapX, snapY, options.decimals or 2)
      if wasRect and not options.rect_to_vector then
        local points = ParseNumbers(moved)
        if #points >= 8 then
          local axisError = math.max(math.abs(points[2] - points[4]), math.abs(points[3] - points[5]), math.abs(points[6] - points[8]), math.abs(points[7] - points[1]))
          if axisError <= 0.01 then
            local l = math.min(points[1], points[3], points[5], points[7])
            local r = math.max(points[1], points[3], points[5], points[7])
            local t = math.min(points[2], points[4], points[6], points[8])
            local b = math.max(points[2], points[4], points[6], points[8])
            return "\\" .. tostring(tag_name) .. "(" .. tostring(FormatNumber(l, options.decimals or 2)) .. "," .. tostring(FormatNumber(t, options.decimals or 2)) .. "," .. tostring(FormatNumber(r, options.decimals or 2)) .. "," .. tostring(FormatNumber(b, options.decimals or 2)) .. ")"
          end
        end
      end
      return "\\" .. tostring(tag_name) .. "(" .. tostring(moved) .. ")"
    end
    text = LineOps.mapTagCalls(text, {
      "clip",
      "iclip"
    }, (function(call)
      return ApplyClip(call.raw_name, call.value)
    end), {
      top_level_only = false
    })
  end
  return text
end
local HasUnsafeLinearTags
HasUnsafeLinearTags = function(text, options)
  if FBFOptimizer.hasDurationTags(text) then
    return true
  end
  return LineOps.hasTag(text, {
    "org",
    "clip",
    "iclip"
  }, false)
end
ShiftFrameKaraoke = function(frameLine, sourceStart, frameStart)
  return AssContext.shiftFrameKaraoke(frameLine, sourceStart, frameStart)
end
local TrackChannelsConstant
TrackChannelsConstant = function(samples, tolerance, options)
  if tolerance == nil then
    tolerance = geometryEpsilon
  end
  if options == nil then
    options = nil
  end
  local first = samples[1]
  for _index_0 = 1, #samples do
    local sample = samples[_index_0]
    if not options or options.scale then
      if math.abs(sample.scale.x - first.scale.x) > tolerance then
        return false
      end
      if math.abs(sample.scale.y - first.scale.y) > tolerance then
        return false
      end
    end
    if not options or options.rotation then
      if math.abs(sample.rotation - first.rotation) > tolerance then
        return false
      end
    end
  end
  return true
end
local AxisAlignedRotation
AxisAlignedRotation = function(degrees, tolerance)
  if tolerance == nil then
    tolerance = geometryEpsilon
  end
  local value = math.abs(tonumber(degrees) or 0) % 180
  return value <= tolerance or math.abs(value - 180) <= tolerance
end
local TransformShearRisk
TransformShearRisk = function(track, referenceIndex, tolerance, firstSample, lastSample)
  if referenceIndex == nil then
    referenceIndex = 1
  end
  if tolerance == nil then
    tolerance = geometryEpsilon
  end
  if firstSample == nil then
    firstSample = 1
  end
  if lastSample == nil then
    lastSample = nil
  end
  if not (track and track.samples and #track.samples > 0) then
    return nil
  end
  local reference = track.samples[math.floor(clamp(referenceIndex, 1, #track.samples))]
  if math.abs(reference.scale.x or 0) < tolerance or math.abs(reference.scale.y or 0) < tolerance then
    return "zero reference scale", "zero_scale"
  end
  local coord = track.coordinate_scale or reference.coordinate_scale or {
    x = 1,
    y = 1
  }
  local nonuniformCoordinates = math.abs((coord.x or 1) - (coord.y or 1)) > tolerance
  firstSample = math.floor(clamp(firstSample, 1, #track.samples))
  lastSample = math.floor(clamp(lastSample or #track.samples, firstSample, #track.samples))
  for i = firstSample, lastSample do
    local sample = track.samples[i]
    local rotationDelta = (sample.rotation or 0) - (reference.rotation or 0)
    if nonuniformCoordinates and not AxisAlignedRotation(rotationDelta, tolerance) then
      return "source frame " .. tostring(sample.source_frame) .. ": aspect change plus rotation requires shear (use Power Pin/Perspective)", "aspect_rotation"
    end
  end
  return nil
end
local TrackDeformationFlags
TrackDeformationFlags = function(track, referenceIndex, tolerance, firstSample, lastSample)
  if referenceIndex == nil then
    referenceIndex = 1
  end
  if tolerance == nil then
    tolerance = geometryEpsilon
  end
  if firstSample == nil then
    firstSample = 1
  end
  if lastSample == nil then
    lastSample = nil
  end
  local reference = track.samples[math.floor(clamp(referenceIndex, 1, #track.samples))]
  local anisotropic, rotationChanges = false, false
  firstSample = math.floor(clamp(firstSample, 1, #track.samples))
  lastSample = math.floor(clamp(lastSample or #track.samples, firstSample, #track.samples))
  for i = firstSample, lastSample do
    local sample = track.samples[i]
    local rx = (sample.scale.x or 100) / (reference.scale.x or 100)
    local ry = (sample.scale.y or 100) / (reference.scale.y or 100)
    if math.abs(rx - ry) > tolerance then
      anisotropic = true
    end
    if math.abs((sample.rotation or 0) - (reference.rotation or 0)) > tolerance then
      rotationChanges = true
    end
  end
  return anisotropic, rotationChanges, reference
end
local LineTransformShearRisk
LineTransformShearRisk = function(line, track, referenceIndex, options, firstSample, lastSample)
  if referenceIndex == nil then
    referenceIndex = 1
  end
  if options == nil then
    options = { }
  end
  if firstSample == nil then
    firstSample = 1
  end
  if lastSample == nil then
    lastSample = nil
  end
  local anisotropic, rotationChanges, reference = TrackDeformationFlags(track, referenceIndex, geometryEpsilon, firstSample, lastSample)
  if not (anisotropic or rotationChanges) then
    return nil
  end
  local fields = {
    "text",
    "properties",
    "align",
    "xPosition",
    "yPosition",
    "move",
    "hasOrg",
    "hasClip",
    "styleRef"
  }
  local saved, present = { }, { }
  for _index_0 = 1, #fields do
    local field = fields[_index_0]
    present[field] = line[field] ~= nil
    saved[field] = line[field]
  end
  local probeOptions = CopyTable(options)
  probeOptions.scale, probeOptions.rotation = true, true
  probeOptions.border, probeOptions.shadow, probeOptions.blur = false, false, false
  local ok, prepare_error = pcall(PrepareStaticLine, line, probeOptions)
  local probeText = line.text
  for _index_0 = 1, #fields do
    local field = fields[_index_0]
    if present[field] then
      line[field] = saved[field]
    else
      line[field] = nil
    end
  end
  if not (ok) then
    return "could not read the initial geometry: " .. tostring(prepare_error)
  end
  if anisotropic then
    local rotations = { }
    local _list_0 = {
      "\\frz([%+%-]?[%d%.]+)",
      "\\fr([%+%-]?[%d%.]+)"
    }
    for _index_0 = 1, #_list_0 do
      local pattern = _list_0[_index_0]
      for value in probeText:gmatch(pattern) do
        local number = tonumber(value)
        if number then
          rotations[#rotations + 1] = number
        end
      end
    end
    if #rotations == 0 then
      rotations = {
        0
      }
    end
    for _index_0 = 1, #rotations do
      local rotation = rotations[_index_0]
      local relative = rotation - (reference.rotation or 0)
      if not (AxisAlignedRotation(relative)) then
        return "anisotropic scaling over \\frz" .. tostring(FormatNumber(rotation, 3)) .. " requires shear; use Power Pin/Perspective"
      end
    end
  end
  local _list_0 = {
    "fax",
    "fay",
    "frx",
    "fry"
  }
  for _index_0 = 1, #_list_0 do
    local tag = _list_0[_index_0]
    local pattern = "\\" .. tostring(tag) .. "([%+%-]?[%d%.]+)"
    for value in probeText:gmatch(pattern) do
      if math.abs(tonumber(value) or 0) > geometryEpsilon then
        return "\\" .. tostring(tag) .. tostring(value) .. " cannot be composed faithfully with this deformation; use Power Pin/Perspective", "perspective"
      end
    end
  end
  return nil
end
local EffectiveTransformTrack
EffectiveTransformTrack = function(track, referenceIndex, options)
  local out = CopyTable(track)
  out.coordinate_scale = track.coordinate_scale
  out.samples = { }
  local reference = track.samples[math.floor(clamp(referenceIndex, 1, #track.samples))]
  for i, sample in ipairs(track.samples) do
    out.samples[i] = EffectiveTransformSample(sample, reference, options)
  end
  return out
end
local SampleIndexFor
SampleIndexFor = function(frame, source, window, options)
  if options.mapping_mode == "Restart on each line" then
    return frame - source.startFrame + 1
  else
    return frame - window.start_frame + 1
  end
end
local InsertFirstOverride = LineOps.prependTag
local TryLinearLine
TryLinearLine = function(line, track, window, options)
  if not (options.optimize_linear and #track.samples >= 2) then
    return nil
  end
  if HasUnsafeLinearTags(line.text, options) then
    return nil
  end
  local first_frame = aegisub.frame_from_ms(line.start_time)
  local last_frame = ExclusiveEndFrame(line.start_time, line.end_time)
  if last_frame - first_frame < 2 then
    return nil
  end
  if not (TrackChannelsConstant(track.samples, geometryEpsilon, options)) then
    return nil
  end
  PrepareStaticLine(line, options)
  local positions
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = LineOps.tagCalls(line.text, "pos")
    for _index_0 = 1, #_list_0 do
      local call = _list_0[_index_0]
      if call.top_level then
        _accum_0[_len_0] = call
        _len_0 = _len_0 + 1
      end
    end
    positions = _accum_0
  end
  if not (#positions == 1) then
    return nil
  end
  local args = LineOps.splitArguments(positions[1].value)
  local posX, posY = tonumber(args[1]), tonumber(args[2])
  if not (posX and posY) then
    return nil
  end
  local referenceIndex = clamp(options.reference_frame, 1, #track.samples)
  local reference = track.samples[referenceIndex]
  local times, xs, ys = { }, { }, { }
  for frame = first_frame, last_frame - 1 do
    LineOps.checkCancelled()
    local sampleIndex = SampleIndexFor(frame, line, window, options)
    local sample = track.samples[sampleIndex]
    if not (sample) then
      return nil
    end
    local effectiveSample = EffectiveTransformSample(sample, reference, options)
    local tx, ty, err = MotionPoint(posX, posY, effectiveSample, reference, options)
    if err then
      return nil
    end
    if options.absolute then
      if options.x_position then
        tx = effectiveSample.position.x
      end
      if options.y_position then
        ty = effectiveSample.position.y
      end
    end
    times[#times + 1] = 0.5 * (aegisub.ms_from_frame(frame) + aegisub.ms_from_frame(frame + 1))
    xs[#xs + 1], ys[#ys + 1] = tx, ty
  end
  local fit = VectorLinearity(times, xs, ys)
  if not (fit and fit.max <= (tonumber(options.linear_tolerance) or DEFAULTS.linear_tolerance)) then
    return nil
  end
  local start_x = fit.x.intercept + fit.x.slope * line.start_time
  local start_y = fit.y.intercept + fit.y.slope * line.start_time
  local end_x = fit.x.intercept + fit.x.slope * line.end_time
  local end_y = fit.y.intercept + fit.y.slope * line.end_time
  local text = LineOps.removeTagCalls(line.text, "pos")
  local distance = math.sqrt((end_x - start_x) ^ 2 + (end_y - start_y) ^ 2)
  local tag
  if distance <= 0.0001 then
    tag = "\\pos(" .. tostring(FormatNumber(start_x, 2)) .. "," .. tostring(FormatNumber(start_y, 2)) .. ")"
  else
    tag = "\\move(" .. tostring(FormatNumber(start_x, 2)) .. "," .. tostring(FormatNumber(start_y, 2)) .. "," .. tostring(FormatNumber(end_x, 2)) .. "," .. tostring(FormatNumber(end_y, 2)) .. ")"
  end
  line.text = InsertFirstOverride(text, tag)
  line.linear_report = fit
  return line
end
local ApplyTransformTrack
ApplyTransformTrack = function(subs, window, rawTrack, options)
  local script_res = GetScriptResolution(subs)
  local track = ScaleTrackCoordinates(rawTrack, script_res, options)
  local referenceIndex = math.floor(clamp(options.reference_frame, 1, #track.samples))
  local reference = track.samples[referenceIndex]
  if math.abs(reference.scale.x or 0) < scaleEpsilon or math.abs(reference.scale.y or 0) < scaleEpsilon then
    return nil, "X or Y scale is zero at the reference frame."
  end
  local effectiveTrack = EffectiveTransformTrack(track, referenceIndex, options)
  local shearRisk = TransformShearRisk(effectiveTrack, referenceIndex)
  local shearApplies = not options.only_clip and shearRisk ~= nil
  local collection = LineCollection(subs, window.indices, AcceptDialogueLine, true)
  local ordered
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = collection.lines
    for _index_0 = 1, #_list_0 do
      local line = _list_0[_index_0]
      _accum_0[_len_0] = line
      _len_0 = _len_0 + 1
    end
    ordered = _accum_0
  end
  table.sort(ordered, function(a, b)
    return a.number > b.number
  end)
  local preservedPerspective = { }
  if options.strict_geometry and not options.only_clip then
    for _index_0 = 1, #ordered do
      local source = ordered[_index_0]
      LineOps.checkCancelled()
      source.startFrame = aegisub.frame_from_ms(source.start_time)
      source.endFrame = ExclusiveEndFrame(source.start_time, source.end_time)
      local firstSample = math.max(1, source.startFrame - window.start_frame + 1)
      local lastSample = math.min(#effectiveTrack.samples, source.endFrame - window.start_frame)
      local matrix_risk = TransformShearRisk(effectiveTrack, referenceIndex, geometryEpsilon, firstSample, lastSample)
      if matrix_risk then
        return nil, "Line " .. tostring(source.humanizedNumber or source.number or '?') .. ": " .. tostring(matrix_risk) .. "."
      end
      local line_risk, risk_kind = LineTransformShearRisk(source, effectiveTrack, referenceIndex, options, firstSample, lastSample)
      if line_risk then
        if options.preserve_perspective and risk_kind == "perspective" then
          preservedPerspective[#preservedPerspective + 1] = source.humanizedNumber or source.number or '?'
        else
          return nil, "Line " .. tostring(source.humanizedNumber or source.number or '?') .. ": " .. tostring(line_risk) .. "."
        end
      end
    end
  end
  local report = {
    linear = 0,
    fbf = 0,
    compressed = 0,
    groups = { },
    preserved_perspective = preservedPerspective
  }
  if shearApplies then
    report.warning = shearRisk
  end
  for _index_0 = 1, #ordered do
    local _continue_0 = false
    repeat
      local source = ordered[_index_0]
      LineOps.checkCancelled()
      source.startFrame = aegisub.frame_from_ms(source.start_time)
      source.endFrame = ExclusiveEndFrame(source.start_time, source.end_time)
      local originalText = source.text
      local optimized
      if options.only_clip then
        optimized = nil
      else
        optimized = TryLinearLine(source, track, window, options)
      end
      if optimized then
        local output = CopyLine(optimized)
        output.start_time, output.end_time = source.start_time, source.end_time
        subs[source.number] = output
        report.linear = report.linear + 1
        report.groups[#report.groups + 1] = {
          index = source.number,
          count = 1,
          replace = true
        }
        _continue_0 = true
        break
      end
      source.text = originalText
      local sourceData = ASS:parse(source)
      local fbf = AssContext.line2fbf(sourceData, ArchUtil, ASS)
      local outputs = { }
      for _index_1 = 1, #fbf do
        local _continue_1 = false
        repeat
          local frameLine = fbf[_index_1]
          LineOps.checkCancelled()
          local frame = frameLine.startFrame or aegisub.frame_from_ms(frameLine.start_time)
          local sampleIndex = SampleIndexFor(frame, source, window, options)
          local sample = track.samples[sampleIndex]
          if not (sample) then
            _continue_1 = true
            break
          end
          local startTime, endTime = FrameInterval(source, frame)
          if not (startTime) then
            _continue_1 = true
            break
          end
          frameLine.start_time, frameLine.end_time = startTime, endTime
          ShiftFrameKaraoke(frameLine, source.start_time, startTime)
          if not (options.only_clip) then
            PrepareStaticLine(frameLine, options)
          end
          frameLine.text = ApplyTransformText(frameLine, sample, reference, options)
          outputs[#outputs + 1] = CopyLine(frameLine)
          _continue_1 = true
        until true
        if not _continue_1 then
          break
        end
      end
      local before = #outputs
      outputs = CompressOutputLines(outputs)
      if #outputs == 0 then
        return nil, "Line " .. tostring(source.humanizedNumber or source.number or '?') .. ": no Transform output was generated."
      end
      report.compressed = report.compressed + (before - #outputs)
      report.fbf = report.fbf + #outputs
      ReplaceOrInsertOutputs(subs, source.number, outputs, true)
      report.groups[#report.groups + 1] = {
        index = source.number,
        count = #outputs,
        replace = true
      }
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  report.selection = SelectionFromGroups(report.groups)
  return true, report
end
Core.ScaleTrackCoordinates = ScaleTrackCoordinates
Core.TransformPoint = TransformPoint
Core.InverseTransformPoint = InverseTransformPoint
Core.MotionPoint = MotionPoint
Core.EffectiveTransformSample = EffectiveTransformSample
Core.TransformClipPath = TransformClipPath
Core.TranslateClipPath = TranslateClipPath
Core.ApplyTransformText = ApplyTransformText
Core.ShiftFrameKaraoke = ShiftFrameKaraoke
Core.TrackChannelsConstant = TrackChannelsConstant
Core.TransformShearRisk = TransformShearRisk
Core.TrackDeformationFlags = TrackDeformationFlags
Core.LineTransformShearRisk = LineTransformShearRisk
Core.EffectiveTransformTrack = EffectiveTransformTrack
Core.TryLinearLine = TryLinearLine
Core.ApplyTransformTrack = ApplyTransformTrack
local perspectiveWarningLabels = {
  zero_size = "zero-size text or drawing",
  text_and_drawings = "mixed text and drawing",
  move = "unbaked \\move",
  multiple_tags = "repeated geometric tags",
  transform = "\\t that changes geometry"
}
local PerspectiveWarningText
PerspectiveWarningText = function(warnings)
  local out = { }
  local _list_0 = warnings or { }
  for _index_0 = 1, #_list_0 do
    local warning = _list_0[_index_0]
    local name, detail = warning[1], warning[2]
    local label = perspectiveWarningLabels[name] or tostring(name)
    if detail then
      label = label .. " (" .. tostring(detail) .. ")"
    end
    out[#out + 1] = label
  end
  return table.concat(out, ", ")
end
local ValidateQuadTrack
ValidateQuadTrack = function(track)
  local winding = nil
  for i, sample in ipairs(track.samples) do
    local ok, err, area = ValidateQuad(sample.quad, 0.5)
    if not (ok) then
      return nil, "Source frame " .. tostring(sample.source_frame) .. ": " .. tostring(err)
    end
    local current = area > 0 and 1 or -1
    winding = winding or current
    if current ~= winding then
      return nil, "Quad winding changes at source frame " .. tostring(sample.source_frame) .. "."
    end
  end
  return true
end
local PerspectiveTrack
PerspectiveTrack = function(subs, window, rawTrack, options)
  local script_res = GetScriptResolution(subs)
  local track = ScaleTrackCoordinates(rawTrack, script_res, options)
  local ok, err = ValidateQuadTrack(track)
  if not (ok) then
    return nil, err
  end
  local quads = { }
  local _list_0 = track.samples
  for _index_0 = 1, #_list_0 do
    local sample = _list_0[_index_0]
    LineOps.checkCancelled()
    local quadPoints = { }
    local _list_1 = sample.quad
    for _index_1 = 1, #_list_1 do
      local point = _list_1[_index_1]
      quadPoints[#quadPoints + 1] = {
        point.x,
        point.y
      }
    end
    quads[#quads + 1] = Quad(quadPoints)
  end
  local referenceIndex = math.floor(clamp(options.reference_frame, 1, #quads))
  local lines = LineCollection(subs, window.indices, AcceptAllLines)
  local okVideo, videoW, videoH = pcall(aegisub.video_size)
  videoW, videoH = tonumber(videoW), tonumber(videoH)
  if not (okVideo and videoW and videoH and videoW > 0 and videoH > 0) then
    return nil, "Could not obtain the video dimensions."
  end
  local playY = tonumber(lines.meta and (lines.meta.PlayResY or lines.meta.playresy or lines.meta.res_y))
  local layoutY = tonumber(lines.meta and (lines.meta.LayoutResY or lines.meta.layoutresy)) or videoH
  if not (playY and playY > 0 and layoutY > 0) then
    return nil, "The script has no valid PlayResY/LayoutResY for perspective tracking."
  end
  local layoutScale = playY / layoutY
  local absReferenceFrame = window.start_frame + referenceIndex - 1
  lines:runCallback(function(collection, line)
    line.startFrame = aegisub.frame_from_ms(line.start_time)
    line.endFrame = ExclusiveEndFrame(line.start_time, line.end_time)
  end)
  local relativeLines, toDelete, setupError = { }, { }, nil
  lines:runCallback((function(collection, line)
    local data = ASS:parse(line)
    toDelete[#toDelete + 1] = line
    line.willdelete = true
    local fbf = AssContext.line2fbf(data, ArchUtil, ASS)
    local localReferenceFrame = math.floor(clamp(absReferenceFrame, line.startFrame, line.endFrame - 1))
    local relative_line = fbf[localReferenceFrame - line.startFrame + 1]
    local relativeQuad = quads[localReferenceFrame - window.start_frame + 1]
    if not (relative_line and relativeQuad) then
      setupError = "Line " .. tostring(line.humanizedNumber or line.number or '?') .. ": its local reference could not be built."
      return
    end
    relativeLines[relative_line] = relativeQuad
    for _index_0 = 1, #fbf do
      local _continue_0 = false
      repeat
        local fbfLine = fbf[_index_0]
        LineOps.checkCancelled()
        local frame = fbfLine.startFrame or aegisub.frame_from_ms(fbfLine.start_time)
        local startTime, endTime = FrameInterval(line, frame)
        if not (startTime) then
          _continue_0 = true
          break
        end
        fbfLine.start_time, fbfLine.end_time = startTime, endTime
        ShiftFrameKaraoke(fbfLine, line.start_time, startTime)
        fbfLine.rel_line = relative_line
        fbfLine.reference_quad = relativeQuad
        collection:addLine(fbfLine)
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
  end), true)
  if setupError then
    return nil, setupError
  end
  local org_mode = ({
    ["Keep \\org"] = 1,
    ["Force stable center"] = 2,
    ["Try \\fax0"] = 3
  })[options.org_mode] or 2
  if options.apply_perspective then
    for relative_line, relativeQuad in pairs(relativeLines) do
      local data = ASS:parse(relative_line)
      local tagvals, width, height, warnings = prepareForPerspective(ASS, data)
      local warning_text = PerspectiveWarningText(warnings)
      if warning_text ~= "" then
        return nil, "Line " .. tostring(relative_line.number or '?') .. ": " .. tostring(warning_text) .. "."
      end
      local sourceQuad = transformPoints(tagvals, width, height, nil, layoutScale)
      local position = Point(tagvals.position.x, tagvals.position.y)
      local oldScale = {
        x = tagvals.scale_x.value,
        y = tagvals.scale_y.value
      }
      data:removeTags(relevantTags)
      local insertedTags = { }
      for _index_0 = 1, #usedTags do
        local name = usedTags[_index_0]
        insertedTags[#insertedTags + 1] = tagvals[name]
      end
      data:insertTags(insertedTags)
      local AlignedRect
      AlignedRect = function(w, h)
        local result = Quad.rect(1, 1)
        result = result - Point(an_xshift[tagvals.align.value], an_yshift[tagvals.align.value])
        result = result * Matrix.diag(w, h)
        return result
      end
      local RectAtPosition
      RectAtPosition = function(w, h)
        local result = AlignedRect(w, h)
        result = result + relativeQuad:xy_to_uv(position)
        local mapped = { }
        for _index_0 = 1, #result do
          local point = result[_index_0]
          mapped[#mapped + 1] = relativeQuad:uv_to_xy(point)
        end
        return Quad(mapped)
      end
      tagsFromQuad(tagvals, RectAtPosition(1, 1), width, height, org_mode, layoutScale)
      local targetQuad = RectAtPosition(oldScale.x / tagvals.scale_x.value, oldScale.y / tagvals.scale_y.value)
      local untransformed = position + AlignedRect(width, height)
      local transformedPoints = { }
      for _index_0 = 1, #sourceQuad do
        local point = sourceQuad[_index_0]
        transformedPoints[#transformedPoints + 1] = targetQuad:uv_to_xy(untransformed:xy_to_uv(point))
      end
      local transformed = Quad(transformedPoints)
      tagsFromQuad(tagvals, transformed, width, height, org_mode, layoutScale)
      data:cleanTags(4)
      data:commit()
    end
  end
  for relative_line in pairs(relativeLines) do
    local data = ASS:parse(relative_line)
    local tags, width, height, warnings = prepareForPerspective(ASS, data)
    local warning_text = PerspectiveWarningText(warnings)
    if warning_text ~= "" then
      return nil, "Reference line: " .. tostring(warning_text) .. "."
    end
    relative_line.tags = tags
    relative_line.quad = transformPoints(tags, width, height, nil, layoutScale)
  end
  lines:runCallback(function(collection, line)
    if line.willdelete then
      return
    end
    if not (line.rel_line) then
      return
    end
    local relativeQuad = line.reference_quad or relativeLines[line.rel_line]
    if not (relativeQuad) then
      return
    end
    local data = ASS:parse(line)
    local sampleIndex = line.startFrame - window.start_frame + 1
    local frameQuad = quads[sampleIndex]
    if not (frameQuad) then
      return
    end
    local tagvals, width, height, warnings = prepareForPerspective(ASS, data)
    local warning_text = PerspectiveWarningText(warnings)
    if warning_text ~= "" then
      error("Moka Perspective: " .. tostring(warning_text))
    end
    local oldScale = {
      x = tagvals.scale_x.value,
      y = tagvals.scale_y.value
    }
    local uvPoints = { }
    local _list_1 = line.rel_line.quad
    for _index_0 = 1, #_list_1 do
      local point = _list_1[_index_0]
      uvPoints[#uvPoints + 1] = relativeQuad:xy_to_uv(point)
    end
    local uvQuad = Quad(uvPoints)
    if not (options.track_position) then
      uvQuad = uvQuad + (frameQuad:xy_to_uv(Point(tagvals.position.x, tagvals.position.y)) - relativeQuad:xy_to_uv(Point(line.rel_line.tags.position.x, line.rel_line.tags.position.y)))
    end
    local targetPoints = { }
    for _index_0 = 1, #uvQuad do
      local point = uvQuad[_index_0]
      targetPoints[#targetPoints + 1] = frameQuad:uv_to_xy(point)
    end
    local targetQuad = Quad(targetPoints)
    data:removeTags(relevantTags)
    local insertedTags = { }
    for _index_0 = 1, #usedTags do
      local name = usedTags[_index_0]
      insertedTags[#insertedTags + 1] = tagvals[name]
    end
    data:insertTags(insertedTags)
    tagsFromQuad(tagvals, targetQuad, width, height, org_mode, layoutScale)
    if options.track_border_shadow then
      local _list_2 = {
        "outline",
        "shadow"
      }
      for _index_0 = 1, #_list_2 do
        local name = _list_2[_index_0]
        local _list_3 = {
          "x",
          "y"
        }
        for _index_1 = 1, #_list_3 do
          local coord = _list_3[_index_1]
          local _update_0 = tostring(name) .. "_" .. tostring(coord)
          tagvals[_update_0].value = tagvals[_update_0].value * (tagvals["scale_" .. tostring(coord)].value / oldScale[coord])
        end
      end
    end
    if options.track_clip then
      local clip = (data:getTags({
        "clip_vect",
        "iclip_vect"
      }))[1]
      if not (clip) then
        local rect = (data:removeTags({
          "clip_rect",
          "iclip_rect"
        }))[1]
        if rect then
          clip = rect:getVect()
          clip:setInverse(rect.__tag.inverse)
          data:insertTags(clip)
        end
      end
      if clip then
        local _list_2 = clip.contours
        for _index_0 = 1, #_list_2 do
          local contour = _list_2[_index_0]
          local _list_3 = contour.commands
          for _index_1 = 1, #_list_3 do
            local command = _list_3[_index_1]
            local _list_4 = command:getPoints(true)
            for _index_2 = 1, #_list_4 do
              local point = _list_4[_index_2]
              local projected = frameQuad:uv_to_xy(relativeQuad:xy_to_uv(Point(point.x, point.y)))
              point.x, point.y = projected:x(), projected:y()
            end
          end
        end
      end
    end
    data:cleanTags(4)
    return data:commit()
  end)
  lines:insertLines()
  lines:deleteLines(toDelete)
  local selection, active = lines:getSelection()
  return true, {
    selection = selection,
    active = active
  }
end
Core.PerspectiveWarningText = PerspectiveWarningText
Core.ValidateQuadTrack = ValidateQuadTrack
Core.PerspectiveTrack = PerspectiveTrack
local median = KiteCore.median
local percentile
percentile = function(values, ratio)
  local sorted
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = values or { }
    for _index_0 = 1, #_list_0 do
      local value = _list_0[_index_0]
      if finite(value) then
        _accum_0[_len_0] = tonumber(value)
        _len_0 = _len_0 + 1
      end
    end
    sorted = _accum_0
  end
  table.sort(sorted)
  local count = #sorted
  if count == 0 then
    return nil
  end
  if count == 1 then
    return sorted[1]
  end
  local position = clamp(ratio or 0.5, 0, 1) * (count - 1) + 1
  local lower = math.floor(position)
  local upper = math.ceil(position)
  if lower == upper then
    return sorted[lower]
  end
  return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower)
end
local mad
mad = function(values, center)
  if center == nil then
    center = nil
  end
  center = center or median(values)
  if not (center) then
    return 0
  end
  local deviations = { }
  for _index_0 = 1, #values do
    local value = values[_index_0]
    if finite(value) then
      deviations[#deviations + 1] = math.abs(value - center)
    end
  end
  return median(deviations) or 0
end
local SolveSystem
SolveSystem = function(matrix, vector)
  local count = #vector
  local work = { }
  for row = 1, count do
    do
      local _accum_0 = { }
      local _len_0 = 1
      for column = 1, count do
        _accum_0[_len_0] = matrix[row][column]
        _len_0 = _len_0 + 1
      end
      work[row] = _accum_0
    end
    work[row][count + 1] = vector[row]
  end
  for column = 1, count do
    local pivot, best = column, math.abs(work[column][column] or 0)
    for row = column + 1, count do
      local value = math.abs(work[row][column] or 0)
      if value > best then
        pivot, best = row, value
      end
    end
    if best < singularEpsilon then
      return nil
    end
    if pivot ~= column then
      work[column], work[pivot] = work[pivot], work[column]
    end
    local divisor = work[column][column]
    for index = column, count + 1 do
      local _update_0, _update_1 = column, index
      work[_update_0][_update_1] = work[_update_0][_update_1] / divisor
    end
    for row = 1, count do
      if row ~= column then
        local factor = work[row][column]
        for index = column, count + 1 do
          local _update_0, _update_1 = row, index
          work[_update_0][_update_1] = work[_update_0][_update_1] - (factor * work[column][index])
        end
      end
    end
  end
  local _accum_0 = { }
  local _len_0 = 1
  for index = 1, count do
    _accum_0[_len_0] = work[index][count + 1]
    _len_0 = _len_0 + 1
  end
  return _accum_0
end
local PolyPredict
PolyPredict = function(xs, ys, degree, target)
  local count = math.min(#xs, #ys)
  if count == 0 then
    return nil
  end
  degree = math.floor(clamp(degree or 1, 0, math.min(3, count - 1)))
  local size = degree + 1
  local center = xs[math.floor((count + 1) / 2)] or 0
  local scale = math.max(1, math.abs((xs[count] or center) - (xs[1] or center)))
  local matrix, vector = { }, { }
  for row = 1, size do
    do
      local _accum_0 = { }
      local _len_0 = 1
      for column = 1, size do
        _accum_0[_len_0] = 0
        _len_0 = _len_0 + 1
      end
      matrix[row] = _accum_0
    end
    vector[row] = 0
  end
  for index = 1, count do
    LineOps.checkCancelled()
    local value = (xs[index] - center) / scale
    local powers = {
      1
    }
    for power = 1, degree do
      powers[power + 1] = powers[power] * value
    end
    for row = 1, size do
      local _update_0 = row
      vector[_update_0] = vector[_update_0] + (powers[row] * ys[index])
      for column = 1, size do
        local _update_1, _update_2 = row, column
        matrix[_update_1][_update_2] = matrix[_update_1][_update_2] + (powers[row] * powers[column])
      end
    end
  end
  for index = 1, size do
    local _update_0, _update_1 = index, index
    matrix[_update_0][_update_1] = matrix[_update_0][_update_1] + scaleEpsilon
  end
  local coefficients = SolveSystem(matrix, vector)
  if not (coefficients) then
    return median(ys)
  end
  local value, power = (target - center) / scale, 1
  local result = 0
  for index = 1, size do
    result = result + (coefficients[index] * power)
    power = power * value
  end
  return result
end
local LocalRegression
LocalRegression = function(values, frames, window, degree)
  if window == nil then
    window = 7
  end
  if degree == nil then
    degree = 2
  end
  local count = #values
  local radius = math.max(1, math.floor((tonumber(window) or 7) / 2))
  local out = { }
  for index = 1, count do
    LineOps.checkCancelled()
    local xs, ys = { }, { }
    for neighbor = math.max(1, index - radius), math.min(count, index + radius) do
      if finite(values[neighbor]) then
        xs[#xs + 1] = frames[neighbor] or neighbor
        ys[#ys + 1] = values[neighbor]
      end
    end
    out[index] = PolyPredict(xs, ys, degree, frames[index] or index) or values[index]
  end
  return out
end
local CloneTransformTrack
CloneTransformTrack = function(track)
  local out = CopyTable(track)
  out.meta = CopyTable(track.meta)
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = track.diagnostics or { }
    for _index_0 = 1, #_list_0 do
      local item = _list_0[_index_0]
      _accum_0[_len_0] = item
      _len_0 = _len_0 + 1
    end
    out.diagnostics = _accum_0
  end
  out.samples = { }
  for index, sample in ipairs(track.samples or { }) do
    local copy = CopyTable(sample)
    copy.position = CopyTable(sample.position)
    copy.scale = CopyTable(sample.scale)
    if sample.anchor then
      copy.anchor = CopyTable(sample.anchor)
    end
    if sample.coordinate_scale then
      copy.coordinate_scale = CopyTable(sample.coordinate_scale)
    end
    out.samples[index] = copy
  end
  return out
end
local transformChannels = {
  {
    "position",
    "x",
    0.25
  },
  {
    "position",
    "y",
    0.25
  },
  {
    "scale",
    "x",
    0.15
  },
  {
    "scale",
    "y",
    0.15
  },
  {
    "rotation",
    nil,
    0.08
  },
  {
    "opacity",
    nil,
    0.25
  }
}
local ChannelValue
ChannelValue = function(sample, descriptor)
  local parent, child = descriptor[1], descriptor[2]
  local value = sample[parent]
  if child then
    return value and value[child]
  else
    return value
  end
end
local SetChannelValue
SetChannelValue = function(sample, descriptor, value)
  local parent, child = descriptor[1], descriptor[2]
  if child then
    local _update_0 = parent
    sample[_update_0] = sample[_update_0] or { }
    sample[parent][child] = value
  else
    sample[parent] = value
  end
end
local PhaseSlipCandidate
PhaseSlipCandidate = function(track)
  local samples = track and track.samples or { }
  if #samples < 4 then
    return nil
  end
  local steps, scaleSteps, rotationSteps = { }, { }, { }
  for index = 2, #samples do
    local previous, current = samples[index - 1], samples[index]
    local dx = current.position.x - previous.position.x
    local dy = current.position.y - previous.position.y
    steps[index] = math.sqrt(dx * dx + dy * dy)
    local dsx = (current.scale.x or 100) - (previous.scale.x or 100)
    local dsy = (current.scale.y or 100) - (previous.scale.y or 100)
    scaleSteps[index] = math.sqrt(dsx * dsx + dsy * dsy)
    rotationSteps[index] = math.abs((current.rotation or 0) - (previous.rotation or 0))
  end
  local movingSteps, sampledScales, sampledRotations = { }, { }, { }
  for index = 2, #samples do
    if steps[index] > geometryEpsilon then
      movingSteps[#movingSteps + 1] = steps[index]
    end
    sampledScales[#sampledScales + 1] = scaleSteps[index]
    sampledRotations[#sampledRotations + 1] = rotationSteps[index]
  end
  local typical = median(movingSteps)
  if not (typical and typical > 0.0001) then
    return nil
  end
  local typicalScale = median(sampledScales) or 0
  local typicalRotation = median(sampledRotations) or 0
  local best = nil
  for index = 2, #samples - 1 do
    local stalled = steps[index] <= math.max(0.02, typical * 0.08)
    local resumes = steps[index + 1] >= typical * 0.35
    local scaleDuplicate = scaleSteps[index] <= math.max(0.005, typicalScale * 0.25)
    local rotationDuplicate = rotationSteps[index] <= math.max(0.01, typicalRotation * 0.75)
    if stalled and resumes and scaleDuplicate and rotationDuplicate then
      local score = (1 - math.min(1, steps[index] / math.max(typical, geometryEpsilon))) * math.min(1, steps[index + 1] / typical)
      local candidate = {
        index = index,
        score = score,
        typical_step = typical,
        stalled_step = steps[index],
        resumed_step = steps[index + 1],
        source_frame = samples[index].source_frame
      }
      if not best or candidate.score > best.score then
        best = candidate
      end
    end
  end
  return best
end
local RepairTransformPhase
RepairTransformPhase = function(track, candidate, window, degree)
  if window == nil then
    window = 11
  end
  if degree == nil then
    degree = 2
  end
  if not (candidate and candidate.index) then
    return CloneTransformTrack(track), nil
  end
  local out = CloneTransformTrack(track)
  local count, index = #out.samples, candidate.index
  if index < 2 or index >= count then
    return out, nil
  end
  for sampleIndex = index, count - 1 do
    local source_frame = out.samples[sampleIndex].source_frame
    local nextSample = out.samples[sampleIndex + 1]
    local copy = CopyTable(nextSample)
    copy.position = CopyTable(nextSample.position)
    copy.scale = CopyTable(nextSample.scale)
    if nextSample.anchor then
      copy.anchor = CopyTable(nextSample.anchor)
    end
    if nextSample.coordinate_scale then
      copy.coordinate_scale = CopyTable(nextSample.coordinate_scale)
    end
    copy.source_frame = source_frame
    copy.phase_repaired = true
    out.samples[sampleIndex] = copy
  end
  local last = CopyTable(out.samples[count])
  last.position = CopyTable(out.samples[count].position)
  last.scale = CopyTable(out.samples[count].scale)
  if out.samples[count].anchor then
    last.anchor = CopyTable(out.samples[count].anchor)
  end
  local firstFit = math.max(1, count - math.max(3, tonumber(window) or 11))
  for _index_0 = 1, #transformChannels do
    local descriptor = transformChannels[_index_0]
    local xs, ys = { }, { }
    for sampleIndex = firstFit, count - 1 do
      local value = ChannelValue(out.samples[sampleIndex], descriptor)
      if finite(value) then
        xs[#xs + 1] = sampleIndex
        ys[#ys + 1] = value
      end
    end
    local prediction = PolyPredict(xs, ys, degree, count)
    if prediction then
      SetChannelValue(last, descriptor, prediction)
    end
  end
  last.source_frame = track.samples[count].source_frame
  last.phase_repaired = true
  out.samples[count] = last
  local message = "Removed duplicate sample at row " .. tostring(index) .. " (source frame " .. tostring(candidate.source_frame or '?') .. "); only the new tail sample was extrapolated."
  out.diagnostics[#out.diagnostics + 1] = message
  return out, message
end
local CleanupTransformTrack
CleanupTransformTrack = function(track, options)
  local mode = options.cleanup_mode or "Off"
  if mode == "Off" then
    return CloneTransformTrack(track), {
      mode = mode,
      changed = 0
    }
  end
  local out = CloneTransformTrack(track)
  local count = #out.samples
  local referenceIndex = math.floor(clamp(options.reference_frame or 1, 1, count))
  local frames
  do
    local _accum_0 = { }
    local _len_0 = 1
    for index = 1, count do
      _accum_0[_len_0] = index
      _len_0 = _len_0 + 1
    end
    frames = _accum_0
  end
  local changed = 0
  for _index_0 = 1, #transformChannels do
    local _continue_0 = false
    repeat
      local descriptor = transformChannels[_index_0]
      local values
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = out.samples
        for _index_1 = 1, #_list_0 do
          local sample = _list_0[_index_1]
          _accum_0[_len_0] = ChannelValue(sample, descriptor)
          _len_0 = _len_0 + 1
        end
        values = _accum_0
      end
      if not (#values == count and finite(values[1])) then
        _continue_0 = true
        break
      end
      local threshold = descriptor[3]
      local cleaned
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_1 = 1, #values do
          local value = values[_index_1]
          _accum_0[_len_0] = value
          _len_0 = _len_0 + 1
        end
        cleaned = _accum_0
      end
      if mode == "Protective" then
        local low, high = percentile(values, 0.05), percentile(values, 0.95)
        if low and high and high - low <= threshold then
          for index = 1, count do
            cleaned[index] = values[referenceIndex]
          end
        else
          local fit = LinearFit(frames, values)
          local absoluteResiduals = { }
          if fit then
            local _list_0 = fit.residuals
            for _index_1 = 1, #_list_0 do
              local value = _list_0[_index_1]
              absoluteResiduals[#absoluteResiduals + 1] = math.abs(value)
            end
          end
          local residualP95 = math.huge
          if fit then
            residualP95 = percentile(absoluteResiduals, 0.95) or math.huge
          end
          if fit and residualP95 <= threshold then
            for index = 1, count do
              cleaned[index] = fit.intercept + fit.slope * frames[index]
            end
          else
            for index = 2, count - 1 do
              local neighborhood = {
                values[index - 1],
                values[index + 1]
              }
              local localCenter = median(neighborhood)
              local localScale = mad(neighborhood, localCenter)
              if localCenter and math.abs(values[index] - localCenter) > math.max(threshold * 2, localScale * 4) then
                cleaned[index] = localCenter
              end
            end
          end
        end
      else
        local smooth = LocalRegression(values, frames, options.cleanup_window, options.cleanup_degree)
        local strength = clamp((tonumber(options.cleanup_strength) or 100) / 100, 0, 1)
        for index = 1, count do
          cleaned[index] = values[index] + (smooth[index] - values[index]) * strength
        end
      end
      local anchorDelta = values[referenceIndex] - cleaned[referenceIndex]
      for index = 1, count do
        LineOps.checkCancelled()
        local _update_0 = index
        cleaned[_update_0] = cleaned[_update_0] + anchorDelta
        if math.abs(cleaned[index] - values[index]) > numericEpsilon then
          SetChannelValue(out.samples[index], descriptor, cleaned[index])
          changed = changed + 1
        end
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  local report = {
    mode = mode,
    changed = changed
  }
  return out, report
end
local PrepareTransformTrack
PrepareTransformTrack = function(track, options)
  local working = CloneTransformTrack(track)
  local report = {
    phase = nil,
    repaired = false,
    cleanup = nil
  }
  local candidate = PhaseSlipCandidate(working)
  report.phase = candidate
  if candidate and options.phase_mode == "Repair duplicate sample" then
    working, report.phase_message = RepairTransformPhase(working, candidate, options.cleanup_window, options.cleanup_degree)
    report.repaired = true
  end
  working, report.cleanup = CleanupTransformTrack(working, options)
  working.preprocess_report = report
  return working, report
end
Core.PhaseSlipCandidate = PhaseSlipCandidate
Core.RepairTransformPhase = RepairTransformPhase
Core.CleanupTransformTrack = CleanupTransformTrack
Core.PrepareTransformTrack = PrepareTransformTrack
local ReadClipboard
ReadClipboard = function()
  local ok, value = pcall(function()
    return clipboard.get()
  end)
  if ok and value then
    return tostring(value)
  else
    return ""
  end
end
local ShowMessage
ShowMessage = function(title, message, height)
  if height == nil then
    height = 16
  end
  return KiteUI.message(message, {
    title = title or script_name,
    height = height
  })
end
local SampleCountForSelection
SampleCountForSelection = function(subs, window, mapping_mode)
  if not (mapping_mode == "Restart on each line") then
    return window.frame_count
  end
  local largest = 1
  local _list_0 = window.indices
  for _index_0 = 1, #_list_0 do
    local index = _list_0[_index_0]
    local line = subs[index]
    local first = aegisub.frame_from_ms(line.start_time)
    local last = ExclusiveEndFrame(line.start_time, line.end_time)
    largest = math.max(largest, last - first)
  end
  return largest
end
Core.CurrentVideoFrame = function()
  local properties = LineOps.projectProperties()
  local frame = tonumber(properties and properties.video_position)
  if not (finite(frame) and frame >= 0) then
    return nil
  end
  return math.floor(frame)
end
Core.ReferenceRowForWindow = function(window, fallback)
  if fallback == nil then
    fallback = DEFAULTS.reference_frame
  end
  fallback = math.max(1, math.floor(tonumber(fallback) or DEFAULTS.reference_frame))
  if not (window) then
    return fallback
  end
  local currentFrame = Core.CurrentVideoFrame()
  local start_frame = tonumber(window.start_frame)
  local frame_count = tonumber(window.frame_count)
  if not frame_count and start_frame and tonumber(window.end_frame) then
    frame_count = tonumber(window.end_frame) - start_frame
  end
  if not (currentFrame and start_frame and frame_count and frame_count > 0) then
    return fallback
  end
  local reference_row = currentFrame - start_frame + 1
  if reference_row >= 1 and reference_row <= frame_count then
    return reference_row
  else
    return fallback
  end
end
local MotionDialog
MotionDialog = function(inverse, window, draft)
  if inverse == nil then
    inverse = false
  end
  if window == nil then
    window = nil
  end
  if draft == nil then
    draft = nil
  end
  local action
  if inverse then
    action = "Revert"
  else
    action = "Apply"
  end
  local reference_row = Core.ReferenceRowForWindow(window)
  local controls = {
    {
      class = "label",
      label = "Mocha / After Effects Transform data or a text-file path:",
      x = 0,
      y = 0,
      width = 12,
      height = 1
    },
    {
      class = "textbox",
      name = "input",
      text = ReadClipboard(),
      x = 0,
      y = 1,
      width = 12,
      height = 11
    },
    {
      class = "label",
      label = "First data row",
      x = 0,
      y = 12,
      width = 2,
      height = 1
    },
    {
      class = "intedit",
      name = "sample_start",
      value = 1,
      min = 1,
      x = 2,
      y = 12,
      width = 1,
      height = 1
    },
    {
      class = "label",
      label = "Reference row",
      x = 3,
      y = 12,
      width = 2,
      height = 1
    },
    {
      class = "intedit",
      name = "reference_frame",
      value = reference_row,
      min = 1,
      x = 5,
      y = 12,
      width = 1,
      height = 1
    },
    {
      class = "label",
      label = "Mapping",
      x = 6,
      y = 12,
      width = 1,
      height = 1
    },
    {
      class = "dropdown",
      name = "mapping_mode",
      items = {
        "Selection timeline",
        "Restart on each line"
      },
      value = "Selection timeline",
      x = 7,
      y = 12,
      width = 3,
      height = 1
    },
    {
      class = "checkbox",
      name = "x_position",
      label = "X",
      value = true,
      x = 0,
      y = 13,
      width = 1,
      height = 1
    },
    {
      class = "checkbox",
      name = "y_position",
      label = "Y",
      value = true,
      x = 1,
      y = 13,
      width = 1,
      height = 1
    },
    {
      class = "checkbox",
      name = "scale",
      label = "Scale",
      value = true,
      x = 2,
      y = 13,
      width = 2,
      height = 1
    },
    {
      class = "checkbox",
      name = "rotation",
      label = "Rotation",
      value = true,
      x = 4,
      y = 13,
      width = 2,
      height = 1
    },
    {
      class = "checkbox",
      name = "origin",
      label = "Move \\org",
      value = true,
      x = 6,
      y = 13,
      width = 2,
      height = 1
    },
    {
      class = "checkbox",
      name = "track_clip",
      label = "Transform clips",
      value = true,
      x = 8,
      y = 13,
      width = 2,
      height = 1
    },
    {
      class = "checkbox",
      name = "only_clip",
      label = "Clips only",
      value = false,
      x = 10,
      y = 13,
      width = 2,
      height = 1
    },
    {
      class = "checkbox",
      name = "border",
      label = "Borders",
      value = true,
      x = 0,
      y = 14,
      width = 2,
      height = 1
    },
    {
      class = "checkbox",
      name = "shadow",
      label = "Shadows",
      value = true,
      x = 2,
      y = 14,
      width = 2,
      height = 1
    },
    {
      class = "checkbox",
      name = "blur",
      label = "Blur",
      value = true,
      x = 4,
      y = 14,
      width = 2,
      height = 1
    },
    {
      class = "checkbox",
      name = "absolute",
      label = "Absolute position",
      value = false,
      x = 6,
      y = 14,
      width = 3,
      height = 1
    },
    {
      class = "checkbox",
      name = "optimize_linear",
      label = "Compact linear motion",
      value = not inverse,
      x = 9,
      y = 14,
      width = 3,
      height = 1
    },
    {
      class = "label",
      label = "Duplicate sample",
      x = 0,
      y = 15,
      width = 2,
      height = 1
    },
    {
      class = "dropdown",
      name = "phase_mode",
      items = {
        "Off",
        "Detect only",
        "Repair duplicate sample"
      },
      value = "Detect only",
      x = 2,
      y = 15,
      width = 3,
      height = 1
    },
    {
      class = "label",
      label = "Cleanup",
      x = 5,
      y = 15,
      width = 1,
      height = 1
    },
    {
      class = "dropdown",
      name = "cleanup_mode",
      items = {
        "Off",
        "Protective",
        "Local regression"
      },
      value = "Off",
      x = 6,
      y = 15,
      width = 2,
      height = 1
    },
    {
      class = "label",
      label = "Window",
      x = 8,
      y = 15,
      width = 1,
      height = 1
    },
    {
      class = "intedit",
      name = "cleanup_window",
      value = 9,
      min = 3,
      x = 9,
      y = 15,
      width = 1,
      height = 1
    },
    {
      class = "label",
      label = "Degree",
      x = 10,
      y = 15,
      width = 1,
      height = 1
    },
    {
      class = "intedit",
      name = "cleanup_degree",
      value = 2,
      min = 1,
      max = 3,
      x = 11,
      y = 15,
      width = 1,
      height = 1
    },
    {
      class = "checkbox",
      name = "strict_sync",
      label = "Strict frame/FPS/PAR synchronization",
      value = DEFAULTS.strict_sync,
      x = 0,
      y = 16,
      width = 5,
      height = 1
    }
  }
  if not (inverse) then
    table.insert(controls, {
      class = "checkbox",
      name = "optimize_fbf",
      label = "Optimize FBF states (0.05 px)",
      value = DEFAULTS.optimize_fbf,
      x = 5,
      y = 16,
      width = 7,
      height = 1
    })
  end
  if draft then
    for _index_0 = 1, #controls do
      local _continue_0 = false
      repeat
        local control = controls[_index_0]
        if not (control.name and draft[control.name] ~= nil) then
          _continue_0 = true
          break
        end
        if control.class == "textbox" then
          control.text = draft[control.name]
        else
          control.value = draft[control.name]
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
  end
  local pressed, values = aegisub.dialog.display(controls, {
    action,
    "Cancel"
  }, {
    ok = action,
    close = "Cancel"
  })
  if not (pressed == action) then
    return nil
  end
  values.inverse = inverse
  values.use_source_meta = true
  values.scale_to_script = true
  values.rect_to_vector = true
  values.rect_clip = true
  values.vector_clip = true
  values.strict_geometry = false
  values.linear_tolerance = 0.20
  values.blur_scale = 1
  values.decimals = 2
  values.cleanup_strength = 100
  if inverse then
    values.optimize_fbf = false
  end
  return values
end
local ShapeDialog
ShapeDialog = function(mode, script_res, draft)
  if draft == nil then
    draft = nil
  end
  local labels = {
    clip = "Create Clip",
    iclip = "Create Inverse Clip",
    shape = "Create Vector Drawing"
  }
  local action = labels[mode]
  local controls = {
    {
      class = "label",
      label = "Mocha AE Mask Data, Shake SSF 4.0, legacy Bezier data, or a text-file path:",
      x = 0,
      y = 0,
      width = 12,
      height = 1
    },
    {
      class = "textbox",
      name = "input",
      text = ReadClipboard(),
      x = 0,
      y = 1,
      width = 12,
      height = 12
    },
    {
      class = "label",
      label = "First data row",
      x = 0,
      y = 13,
      width = 2,
      height = 1
    },
    {
      class = "intedit",
      name = "sample_start",
      value = 1,
      min = 1,
      x = 2,
      y = 13,
      width = 1,
      height = 1
    },
    {
      class = "label",
      label = "Mapping",
      x = 3,
      y = 13,
      width = 1,
      height = 1
    },
    {
      class = "dropdown",
      name = "mapping_mode",
      items = {
        "Selection timeline",
        "Restart on each line"
      },
      value = "Selection timeline",
      x = 4,
      y = 13,
      width = 3,
      height = 1
    },
    {
      class = "label",
      label = "Placement",
      x = 7,
      y = 13,
      width = 1,
      height = 1
    },
    {
      class = "dropdown",
      name = "placement",
      items = {
        "Replace selection",
        "Insert new lines"
      },
      value = "Replace selection",
      x = 8,
      y = 13,
      width = 3,
      height = 1
    },
    {
      class = "label",
      label = "Offset X",
      x = 0,
      y = 14,
      width = 1,
      height = 1
    },
    {
      class = "floatedit",
      name = "offset_x",
      value = 0,
      x = 1,
      y = 14,
      width = 1,
      height = 1
    },
    {
      class = "label",
      label = "Offset Y",
      x = 2,
      y = 14,
      width = 1,
      height = 1
    },
    {
      class = "floatedit",
      name = "offset_y",
      value = 0,
      x = 3,
      y = 14,
      width = 1,
      height = 1
    },
    {
      class = "label",
      label = "Tangent epsilon",
      x = 4,
      y = 14,
      width = 2,
      height = 1
    },
    {
      class = "floatedit",
      name = "tangent_epsilon",
      value = 0.25,
      min = 0,
      x = 6,
      y = 14,
      width = 1,
      height = 1
    },
    {
      class = "label",
      label = "Inserted layer +",
      x = 7,
      y = 14,
      width = 2,
      height = 1
    },
    {
      class = "intedit",
      name = "layer_offset",
      value = 1,
      x = 9,
      y = 14,
      width = 1,
      height = 1
    },
    {
      class = "label",
      label = "Drawing tags",
      x = 0,
      y = 15,
      width = 2,
      height = 1
    },
    {
      class = "edit",
      name = "shape_tags",
      value = "\\bord0\\shad0",
      x = 2,
      y = 15,
      width = 9,
      height = 1
    },
    {
      class = "checkbox",
      name = "use_source_meta",
      label = "Use exported source size",
      value = true,
      x = 0,
      y = 16,
      width = 3,
      height = 1
    },
    {
      class = "checkbox",
      name = "scale_to_script",
      label = "Scale to target",
      value = true,
      x = 3,
      y = 16,
      width = 2,
      height = 1
    },
    {
      class = "label",
      label = "Source W/H",
      x = 5,
      y = 16,
      width = 2,
      height = 1
    },
    {
      class = "intedit",
      name = "source_width",
      value = DEFAULTS.source_width,
      min = 1,
      x = 7,
      y = 16,
      width = 1,
      height = 1
    },
    {
      class = "intedit",
      name = "source_height",
      value = DEFAULTS.source_height,
      min = 1,
      x = 8,
      y = 16,
      width = 1,
      height = 1
    },
    {
      class = "label",
      label = "Target W/H",
      x = 0,
      y = 17,
      width = 2,
      height = 1
    },
    {
      class = "intedit",
      name = "target_width",
      value = script_res.x,
      min = 1,
      x = 2,
      y = 17,
      width = 1,
      height = 1
    },
    {
      class = "intedit",
      name = "target_height",
      value = script_res.y,
      min = 1,
      x = 3,
      y = 17,
      width = 1,
      height = 1
    },
    {
      class = "label",
      label = "Decimals",
      x = 4,
      y = 17,
      width = 1,
      height = 1
    },
    {
      class = "intedit",
      name = "decimals",
      value = DEFAULTS.decimals,
      min = 0,
      max = 6,
      x = 5,
      y = 17,
      width = 1,
      height = 1
    },
    {
      class = "checkbox",
      name = "strict_sync",
      label = "Strict frame/FPS/PAR synchronization",
      value = DEFAULTS.strict_sync,
      x = 6,
      y = 17,
      width = 5,
      height = 1
    }
  }
  if draft then
    for _index_0 = 1, #controls do
      local _continue_0 = false
      repeat
        local control = controls[_index_0]
        if not (control.name and draft[control.name] ~= nil) then
          _continue_0 = true
          break
        end
        if control.class == "textbox" then
          control.text = draft[control.name]
        else
          control.value = draft[control.name]
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
  end
  local pressed, values = aegisub.dialog.display(controls, {
    action,
    "Cancel"
  }, {
    ok = action,
    close = "Cancel"
  })
  if not (pressed == action) then
    return nil
  end
  values.output_mode = mode
  return values
end
local PowerPinDialog
PowerPinDialog = function(window, draft)
  if window == nil then
    window = nil
  end
  if draft == nil then
    draft = nil
  end
  local reference_row = Core.ReferenceRowForWindow(window)
  local controls = {
    {
      class = "label",
      label = "Mocha CC Power Pin / Corner Pin data or a text-file path:",
      x = 0,
      y = 0,
      width = 12,
      height = 1
    },
    {
      class = "textbox",
      name = "input",
      text = ReadClipboard(),
      x = 0,
      y = 1,
      width = 12,
      height = 12
    },
    {
      class = "label",
      label = "First data row",
      x = 0,
      y = 13,
      width = 2,
      height = 1
    },
    {
      class = "intedit",
      name = "sample_start",
      value = 1,
      min = 1,
      x = 2,
      y = 13,
      width = 1,
      height = 1
    },
    {
      class = "label",
      label = "Reference row",
      x = 3,
      y = 13,
      width = 2,
      height = 1
    },
    {
      class = "intedit",
      name = "reference_frame",
      value = reference_row,
      min = 1,
      x = 5,
      y = 13,
      width = 1,
      height = 1
    },
    {
      class = "checkbox",
      name = "apply_perspective",
      label = "Perspective",
      value = true,
      x = 0,
      y = 14,
      width = 2,
      height = 1
    },
    {
      class = "checkbox",
      name = "track_position",
      label = "Position",
      value = true,
      x = 2,
      y = 14,
      width = 2,
      height = 1
    },
    {
      class = "checkbox",
      name = "track_border_shadow",
      label = "Border / shadow",
      value = true,
      x = 4,
      y = 14,
      width = 3,
      height = 1
    },
    {
      class = "checkbox",
      name = "track_clip",
      label = "Clips",
      value = true,
      x = 7,
      y = 14,
      width = 2,
      height = 1
    },
    {
      class = "label",
      label = "Origin mode",
      x = 0,
      y = 15,
      width = 2,
      height = 1
    },
    {
      class = "dropdown",
      name = "org_mode",
      items = {
        "Keep \\org",
        "Force stable center",
        "Try \\fax0"
      },
      value = "Force stable center",
      x = 2,
      y = 15,
      width = 4,
      height = 1
    },
    {
      class = "checkbox",
      name = "strict_sync",
      label = "Strict frame/FPS/PAR synchronization",
      value = DEFAULTS.strict_sync,
      x = 0,
      y = 16,
      width = 5,
      height = 1
    }
  }
  if draft then
    for _index_0 = 1, #controls do
      local _continue_0 = false
      repeat
        local control = controls[_index_0]
        if not (control.name and draft[control.name] ~= nil) then
          _continue_0 = true
          break
        end
        if control.class == "textbox" then
          control.text = draft[control.name]
        else
          control.value = draft[control.name]
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
  end
  local pressed, values = aegisub.dialog.display(controls, {
    "Apply Power Pin",
    "Cancel"
  }, {
    ok = "Apply Power Pin",
    close = "Cancel"
  })
  if not (pressed == "Apply Power Pin") then
    return nil
  end
  values.use_source_meta = true
  values.scale_to_script = true
  return values
end
local ApplyAtomically
ApplyAtomically = function(subs, callback)
  local state = LineOps.snapshot(subs)
  local ok, result, details = pcall(function()
    local callbackResult, callbackDetails = callback()
    LineOps.checkCancelled()
    return callbackResult, callbackDetails
  end)
  if ok and result then
    return ok, result, details
  end
  local restored, restore_error = pcall(LineOps.restore, subs, state)
  if not (restored) then
    local rollback_message = "Rollback failed: " .. tostring(tostring(restore_error or 'unknown error'))
    if ok then
      details = tostring(tostring(details or 'No output was generated.')) .. "\n" .. tostring(rollback_message)
    else
      result = tostring(tostring(result or 'Operation failed.')) .. "\n" .. tostring(rollback_message)
    end
  end
  LineOps.checkCancelled()
  return ok, result, details
end
FBFOptimizer.optionsDialog = function()
  local labels
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = FBFOptimizer.MODES
    for _index_0 = 1, #_list_0 do
      local mode = _list_0[_index_0]
      _accum_0[_len_0] = mode.label
      _len_0 = _len_0 + 1
    end
    labels = _accum_0
  end
  local controls = {
    {
      class = "label",
      label = "Merge consecutive compatible FBF states without accumulating positional drift.",
      x = 0,
      y = 0,
      width = 8,
      height = 1
    },
    {
      class = "label",
      label = "Comparison",
      x = 0,
      y = 1,
      width = 1,
      height = 1
    },
    {
      class = "dropdown",
      name = "mode",
      items = labels,
      value = labels[1],
      x = 1,
      y = 1,
      width = 3,
      height = 1
    },
    {
      class = "label",
      label = "Duration-dependent \\move, \\t, fades, and karaoke are protected.",
      x = 0,
      y = 2,
      width = 8,
      height = 1
    }
  }
  local button, values = aegisub.dialog.display(controls, {
    "Optimize",
    "Cancel"
  }, {
    ok = "Optimize",
    close = "Cancel"
  })
  if not (button == "Optimize") then
    return nil
  end
  local tolerance = FBFOptimizer.toleranceForMode(values.mode)
  if not (tolerance ~= nil) then
    return nil
  end
  return {
    mode = values.mode,
    tolerance = tolerance
  }
end
FBFOptimizer.main = function(subs, selection)
  local items = FBFOptimizer.selectionItems(subs, selection)
  if #items < 2 then
    ShowMessage("Moka Motion / Optimizer", "Select at least two uncommented FBF dialogue lines.", 6)
    return selection
  end
  local options = FBFOptimizer.optionsDialog()
  if not (options) then
    return selection
  end
  local plan = FBFOptimizer.buildPlan(items, options.tolerance)
  if plan.merged == 0 then
    ShowMessage("Moka Motion / Optimizer", "No consecutive temporal states are compatible with " .. tostring(options.mode) .. ".", 6)
    return selection
  end
  local ok, result, details = ApplyAtomically(subs, function()
    local optimized = FBFOptimizer.applyPlan(subs, plan)
    return true, {
      selection = optimized
    }
  end)
  if not (ok and result) then
    ShowMessage("Moka Motion / Optimizer", ok and "No output was generated." or result, 10)
    return selection
  end
  aegisub.set_undo_point("Moka Motion: Optimizer")
  ShowMessage("Moka Motion / Optimizer", "Optimization complete.\nLines: " .. tostring(plan.before) .. " -> " .. tostring(plan.after) .. "\nMerged: " .. tostring(plan.merged) .. "\nLongest run: " .. tostring(plan.longest_run) .. " states\nTemporal tracks: " .. tostring(#plan.lanes) .. "\nProtected by duration-dependent tags: " .. tostring(plan.unsafe_count), 9)
  return details.selection
end
Core.OptimizeTransformReport = function(subs, report, enabled)
  if enabled and report and report.selection and #report.selection > 1 then
    report.selection, report.optimizer = FBFOptimizer.optimize(subs, report.selection, FBFOptimizer.DEFAULT_TOLERANCE)
  end
  return report
end
function AE.choose(message, choices)
  local controls = {{class = "label", label = message, x = 0, y = 0}}
  local buttons = {}
  if #choices > 2 then
    controls[2] = {class = "dropdown", name = "choice", items = choices, value = choices[1], x = 0, y = 1}
    buttons[1] = "Use selection"
  else
    for i, item in ipairs(choices) do buttons[i] = item end
  end
  buttons[#buttons + 1] = "Back"
  local button, values = aegisub.dialog.display(controls, buttons, {close = "Back"})
  if button == "Use selection" then return values.choice end
  for _, item in ipairs(choices) do
    if item == button then return item end
  end
end
function AE.recoverQuads(track)
  local valid, err = ValidateQuadTrack(track)
  if valid then return track end
  local firstValid, winding, damaged = nil, nil, 0
  local usable = {}
  for i, sample in ipairs(track.samples) do
    local ok, _, area = ValidateQuad(sample.quad, 0.5)
    if ok then
      local sign = area > 0
      if winding ~= nil and winding ~= sign then
        return nil, err .. " Check the corner order or export this layer in separate ranges."
      end
      winding, firstValid, usable[i] = sign, firstValid or i, true
    else
      damaged = damaged + 1
    end
  end
  if not firstValid then return nil, err .. " Export four distinct corners or use the Transform channels in Apply Motion if available." end
  local message = err .. "\n" .. damaged .. " frame(s) have invalid corners. Hold the preceding valid quad, or the first valid quad for leading frames?"
  if not AE.choose(message, {"Hold valid corners"}) then return nil end
  local out, previous = CopyTable(track), track.samples[firstValid]
  out.samples, out.has_interpolation = {}, true
  for i, sample in ipairs(track.samples) do
    if usable[i] then
      previous = sample
      out.samples[i] = sample
    else
      local held = CopyTable(sample)
      held.quad, held.interpolated, held.held = previous.quad, true, true
      out.samples[i] = held
    end
  end
  return out
end
function AE.sliceForApply(track, start, count, strict)
  local sliced, err = SliceTrack(track, start, count, false)
  local first = tonumber(start) or 1
  if not sliced then
    if not (first >= 1 and first <= #track.samples and first == math.floor(first) and count > 0 and count == math.floor(count)) then
      return nil, err
    end
    local shortage = first + count - 1 - #track.samples
    if shortage <= 0 then return nil, err end
    local choices = {"Hold last frame"}
    if first == 1 then choices[#choices + 1] = "Hold first frame" end
    local answer = AE.choose("The selection needs " .. shortage .. " more frame(s). Repeat the nearest sample at the missing end, or adjust the selection.", choices)
    if not answer then return nil end
    local prefix = answer == "Hold first frame" and shortage or 0
    local padded = CopyTable(track)
    padded.samples = {}
    for i = 1, count do
      LineOps.checkCancelled()
      local row = first + i - 1 - prefix
      local source = track.samples[clamp(row, 1, #track.samples)]
      local sample = source
      if row < 1 or row > #track.samples then
        sample = CopyTable(source)
        sample.source_frame = track.first_frame + row - 1
        sample.interpolated, sample.held = true, true
      end
      padded.samples[i] = sample
    end
    track, first = padded, 1
    sliced = padded
  end
  local recovered, firstEstimate, lastEstimate = 0, nil, nil
  for _, sample in ipairs(sliced.samples) do
    if sample.interpolated and not sample.held then
      recovered = recovered + 1
      firstEstimate, lastEstimate = firstEstimate or sample.source_frame, sample.source_frame
    end
  end
  if recovered > 0 then
    local message = recovered .. " frame(s) between source frames " .. firstEstimate .. " and " .. lastEstimate .. " need estimated values. Gaps between samples use linear interpolation. At the ends, the nearest value is held."
    if track.recovery then message = track.recovery .. "\n" .. message end
    if not AE.choose(message, {"Use estimates"}) then return nil end
  end
  return SliceTrack(track, first, count, strict, true)
end
local MotionMain
MotionMain = function(inverse, initialDraft)
  if inverse == nil then
    inverse = false
  end
  return function(subs, sel, active)
    local window, err = SelectionWindow(subs, sel)
    if not (window) then
      ShowMessage(script_name, err)
      return sel
    end
    local draft = initialDraft
    while true do
      local _continue_0 = false
      repeat
        local options = MotionDialog(inverse, window, draft)
        if not (options) then
          return sel
        end
        draft = options
        local track, parseError = ParseInput(options.input, "transform", AE.choose)
        if not (track and track.kind == "transform") then
          ShowMessage("Moka Motion / " .. tostring(inverse and 'Revert Motion' or 'Apply Motion'), parseError or "The pasted data is not a Transform export.")
          _continue_0 = true
          break
        end
        local required = SampleCountForSelection(subs, window, options.mapping_mode)
        local sliced, sliceError = AE.sliceForApply(track, options.sample_start, required, options.strict_sync == true)
        if not (sliced) then
          if sliceError then ShowMessage(script_name, sliceError) end
          _continue_0 = true
          break
        end
        local syncInfo, syncError = ValidateSync(sliced, window, options.strict_sync == true, options.mapping_mode == "Restart on each line")
        if not (syncInfo) then
          ShowMessage(script_name, syncError)
          _continue_0 = true
          break
        end
        options.reference_frame = math.floor(clamp(options.reference_frame, 1, #sliced.samples))
        local prepared, prep = PrepareTransformTrack(sliced, options)
        local ok, result, details = ApplyAtomically(subs, function()
          local applied, report = ApplyTransformTrack(subs, window, prepared, options)
          if not (applied) then
            return applied, report
          end
          Core.OptimizeTransformReport(subs, report, options.optimize_fbf)
          return applied, report
        end)
        if not (ok and result) then
          ShowMessage(script_name, ok and (details or "No output was generated.") or result)
          _continue_0 = true
          break
        end
        aegisub.set_undo_point(tostring(script_name) .. ": " .. tostring(inverse and 'Revert Motion' or 'Apply Motion'))
        local notes = { }
        if details and details.warning then
          notes[#notes + 1] = "Geometry: " .. tostring(details.warning)
        end
        if prep.phase then
          notes[#notes + 1] = "Duplicate-sample candidate: row " .. tostring(prep.phase.index) .. ", source frame " .. tostring(prep.phase.source_frame or '?') .. ", score " .. tostring(FormatNumber(prep.phase.score * 100, 1)) .. "%."
        end
        if prep.phase_message then
          notes[#notes + 1] = prep.phase_message
        end
        if prep.cleanup and prep.cleanup.changed > 0 then
          notes[#notes + 1] = "Cleanup changed " .. tostring(prep.cleanup.changed) .. " channel values."
        end
        if details and details.optimizer then
          local optimizer = details.optimizer
          notes[#notes + 1] = "FBF Optimizer: " .. tostring(optimizer.before) .. " -> " .. tostring(optimizer.after) .. " lines (" .. tostring(optimizer.merged) .. " merged)."
        end
        if #notes > 0 then
          ShowMessage(script_name, table.concat(notes, "\n"), 6)
        end
        if details and details.selection and #details.selection > 0 then
          return details.selection, details.selection[1]
        else
          return sel
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
  end
end
local ShapeMain
ShapeMain = function(mode)
  return function(subs, sel, active)
    local window, err = SelectionWindow(subs, sel)
    if not (window) then
      ShowMessage(script_name, err)
      return sel
    end
    local scriptResolution = GetScriptResolution(subs)
    local draft = nil
    while true do
      local _continue_0 = false
      repeat
        local options = ShapeDialog(mode, scriptResolution, draft)
        if not (options) then
          return sel
        end
        draft = options
        local track, parseError = ParseInput(options.input, "shape")
        if not (track and track.kind == "shape") then
          ShowMessage(script_name, parseError or "The pasted data is not shape or mask data.")
          _continue_0 = true
          break
        end
        local required = SampleCountForSelection(subs, window, options.mapping_mode)
        local sliced, sliceError = SliceTrack(track, options.sample_start, required, options.strict_sync == true)
        if not (sliced) then
          ShowMessage(script_name, sliceError)
          _continue_0 = true
          break
        end
        local syncInfo, syncError = ValidateSync(sliced, window, options.strict_sync == true, options.mapping_mode == "Restart on each line")
        if not (syncInfo) then
          ShowMessage(script_name, syncError)
          _continue_0 = true
          break
        end
        local ok, result, details = ApplyAtomically(subs, function()
          return ApplyShapeTrack(subs, window, sliced, options)
        end)
        if not (ok and result) then
          ShowMessage(script_name, ok and (details or "No shape output was generated.") or result)
          _continue_0 = true
          break
        end
        aegisub.set_undo_point(tostring(script_name) .. ": " .. tostring(mode))
        if details and details.selection and #details.selection > 0 then
          return details.selection, details.selection[1]
        else
          return sel
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
  end
end
local PowerPinMain
PowerPinMain = function(subs, sel, active)
  local window, err = SelectionWindow(subs, sel)
  if not (window) then
    ShowMessage(script_name, err)
    return sel
  end
  local draft = nil
  while true do
    local _continue_0 = false
    repeat
      local options = PowerPinDialog(window, draft)
      if not (options) then
        return sel
      end
      draft = options
      local track, parseError = ParseInput(options.input, "perspective", AE.choose)
      if track and track.kind == "transform" then
        return MotionMain(false, options)(subs, sel, active)
      end
      if not (track and track.kind == "perspective") then
        if parseError or track then ShowMessage(script_name, parseError or "Export After Effects Corner Pin or CC Power Pin from Mocha.") end
        _continue_0 = true
        break
      end
      local sliced, sliceError = AE.sliceForApply(track, options.sample_start, window.frame_count, options.strict_sync == true)
      if not (sliced) then
        if sliceError then ShowMessage(script_name, sliceError) end
        _continue_0 = true
        break
      end
      local syncInfo, syncError = ValidateSync(sliced, window, options.strict_sync == true)
      if not (syncInfo) then
        ShowMessage(script_name, syncError)
        _continue_0 = true
        break
      end
      options.reference_frame = math.floor(clamp(options.reference_frame, 1, #sliced.samples))
      local validationError
      sliced, validationError = AE.recoverQuads(sliced)
      if not sliced then
        if validationError and track.layer_motion then
          if AE.choose(validationError .. "\nUse this export's Transform channels instead?", {"Open Apply Motion"}) then
            return MotionMain(false, options)(subs, sel, active)
          end
        elseif validationError then
          ShowMessage(script_name, validationError)
        end
        _continue_0 = true
        break
      end
      local ok, result, details = ApplyAtomically(subs, function()
        return PerspectiveTrack(subs, window, sliced, options)
      end)
      if not (ok and result) then
        ShowMessage(script_name, ok and (details or "No perspective output was generated.") or result)
        _continue_0 = true
        break
      end
      aegisub.set_undo_point(tostring(script_name) .. ": Apply Power Pin")
      if details and details.selection and #details.selection > 0 then
        return details.selection, details.active or details.selection[1]
      else
        return sel
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
end
local InspectMain
InspectMain = function(subs, sel, active)
  local controls = {
    {
      class = "label",
      label = "Paste Mocha data or a text-file path:",
      x = 0,
      y = 0,
      width = 12,
      height = 1
    },
    {
      class = "textbox",
      name = "input",
      text = ReadClipboard(),
      x = 0,
      y = 1,
      width = 12,
      height = 14
    }
  }
  local pressed, values = aegisub.dialog.display(controls, {
    "Inspect",
    "Cancel"
  }, {
    ok = "Inspect",
    close = "Cancel"
  })
  if not (pressed == "Inspect") then
    return sel
  end
  local track, err = ParseInput(values.input, nil, "inspect")
  if not (track) then
    ShowMessage("Moka Motion / Inspect", err)
    return sel
  end
  local lines = {
    "Type: " .. tostring(track.kind),
    "Format: " .. tostring(track.format or 'unknown'),
    "Samples: " .. tostring(#track.samples),
    "Source frames: " .. tostring(track.first_frame or '?') .. ".." .. tostring(track.last_frame or '?'),
    "Export FPS: " .. tostring(track.meta and track.meta.fps or 'not supplied'),
    "Source size: " .. tostring(track.meta and track.meta.source_width or '?') .. " x " .. tostring(track.meta and track.meta.source_height or '?')
  }
  if track.kind == "transform" then
    local candidate = PhaseSlipCandidate(track)
    if candidate then
      lines[#lines + 1] = "Duplicate-sample candidate: row " .. tostring(candidate.index) .. ", source frame " .. tostring(candidate.source_frame or '?') .. ", score " .. tostring(FormatNumber(candidate.score * 100, 1)) .. "%."
    else
      lines[#lines + 1] = "Duplicate-sample candidate: none."
    end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Diagnostics:"
  if track.diagnostics and #track.diagnostics > 0 then
    local _list_0 = track.diagnostics
    for _index_0 = 1, #_list_0 do
      local item = _list_0[_index_0]
      lines[#lines + 1] = "- " .. tostring(item)
    end
  else
    lines[#lines + 1] = "- None"
  end
  ShowMessage("Moka Motion / Inspect", table.concat(lines, "\n"), 18)
  return sel
end
local SetPositionText
SetPositionText = function(text, x, y)
  local tag = "\\pos(" .. tostring(FormatNumber(x, 3)) .. "," .. tostring(FormatNumber(y, 3)) .. ")"
  local replaced, changed = LineOps.replaceTagCall(text, "pos", tag, true)
  if changed then
    return replaced
  end
  replaced, changed = LineOps.replaceTagCall(replaced, "move", tag, true)
  if changed then
    return replaced
  end
  return InsertFirstOverride(replaced, tag)
end
local ShiftLinkedGeometry
ShiftLinkedGeometry = function(text, dx, dy)
  if math.abs(dx) < numericEpsilon and math.abs(dy) < numericEpsilon then
    return text
  end
  return LineOps.mapTagCalls(text, {
    "org",
    "clip",
    "iclip"
  }, (function(call)
    local content = call.value:sub(2, -2)
    if call.name == "org" then
      local args = LineOps.splitArguments(call.value)
      local x, y = KiteCore.finiteNumber(args[1]), KiteCore.finiteNumber(args[2])
      if not (call.top_level and #args == 2 and x and y) then
        return nil
      end
      return "\\org(" .. tostring(FormatNumber(x + dx, 3)) .. "," .. tostring(FormatNumber(y + dy, 3)) .. ")"
    end
    local path, rectangle = ClipToFloatPath(content)
    if not (path) then
      return nil
    end
    if rectangle then
      local values = LineOps.splitArguments(content)
      return "\\" .. tostring(call.raw_name) .. "(" .. tostring(FormatNumber(tonumber(values[1]) + dx, 3)) .. "," .. tostring(FormatNumber(tonumber(values[2]) + dy, 3)) .. "," .. tostring(FormatNumber(tonumber(values[3]) + dx, 3)) .. "," .. tostring(FormatNumber(tonumber(values[4]) + dy, 3)) .. ")"
    end
    return "\\" .. tostring(call.raw_name) .. "(" .. tostring(TranslateClipPath(path, dx, dy, 3)) .. ")"
  end), {
    top_level_only = false
  })
end
local AuthoredSignature
AuthoredSignature = function(text)
  local clean = LineOps.removeTagCalls(text, {
    "pos",
    "move",
    "org",
    "clip",
    "iclip",
    "fscx",
    "fscy",
    "frz",
    "fr",
    "bord",
    "xbord",
    "ybord",
    "shad",
    "xshad",
    "yshad",
    "blur"
  })
  return clean:gsub("%s+", "")
end
local BuildRefineryTracks
BuildRefineryTracks = function(subs, sel)
  local buckets, order = { }, { }
  local sorted = LineOps.normalizeIndices(subs, sel)
  for _index_0 = 1, #sorted do
    local _continue_0 = false
    repeat
      local index = sorted[_index_0]
      local line = subs[index]
      if line and line.class == "dialogue" and not line.comment then
        local position = LineOps.position(line.text)
        if position and finite(position.x) and finite(position.y) then
          local startFrame = aegisub.frame_from_ms(line.start_time)
          local endFrame = ExclusiveEndFrame(line.start_time, line.end_time)
          if not (startFrame and endFrame and line.end_time > line.start_time) then
            _continue_0 = true
            break
          end
          local key = table.concat({
            tostring(line.layer or 0),
            tostring(line.style or ""),
            tostring(line.actor or ""),
            LineOps.visibleText(line.text)
          }, "\31")
          if not (buckets[key]) then
            buckets[key] = { }
            order[#order + 1] = key
          end
          buckets[key][#buckets[key] + 1] = {
            index = index,
            line = line,
            position = position,
            start_frame = startFrame,
            end_frame = endFrame,
            signature = AuthoredSignature(line.text)
          }
        end
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  local tracks = { }
  for _index_0 = 1, #order do
    local key = order[_index_0]
    local items = buckets[key]
    table.sort(items, function(a, b)
      if a.start_frame == b.start_frame then
        return a.index < b.index
      else
        return a.start_frame < b.start_frame
      end
    end)
    local current, previousEnd = { }, nil
    for _index_1 = 1, #items do
      local item = items[_index_1]
      if #current > 0 and previousEnd and item.start_frame > previousEnd + 1 then
        tracks[#tracks + 1] = {
          key = key,
          items = current
        }
        current = { }
      end
      current[#current + 1] = item
      previousEnd = item.end_frame
    end
    if #current > 0 then
      tracks[#tracks + 1] = {
        key = key,
        items = current
      }
    end
  end
  return tracks
end
local DetectAuthoredPeriod
DetectAuthoredPeriod = function(track)
  local count = #track.items
  if count < 4 then
    return nil
  end
  local signatures
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = track.items
    for _index_0 = 1, #_list_0 do
      local item = _list_0[_index_0]
      _accum_0[_len_0] = item.signature
      _len_0 = _len_0 + 1
    end
    signatures = _accum_0
  end
  local prefix = {
    0
  }
  for index = 2, count do
    LineOps.checkCancelled()
    local matched = prefix[index - 1]
    while matched > 0 and signatures[index] ~= signatures[matched + 1] do
      matched = prefix[matched]
    end
    if signatures[index] == signatures[matched + 1] then
      matched = matched + 1
    end
    prefix[index] = matched
  end
  local signaturePeriod = count - prefix[count]
  if signaturePeriod >= 2 and signaturePeriod <= math.floor(count / 2) then
    return signaturePeriod
  end
  local frames
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = track.items
    for _index_0 = 1, #_list_0 do
      local item = _list_0[_index_0]
      _accum_0[_len_0] = item.start_frame
      _len_0 = _len_0 + 1
    end
    frames = _accum_0
  end
  local xs
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = track.items
    for _index_0 = 1, #_list_0 do
      local item = _list_0[_index_0]
      _accum_0[_len_0] = item.position.x
      _len_0 = _len_0 + 1
    end
    xs = _accum_0
  end
  local ys
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = track.items
    for _index_0 = 1, #_list_0 do
      local item = _list_0[_index_0]
      _accum_0[_len_0] = item.position.y
      _len_0 = _len_0 + 1
    end
    ys = _accum_0
  end
  local fit_x, fit_y = LinearFit(frames, xs), LinearFit(frames, ys)
  if not (fit_x and fit_y) then
    return nil
  end
  local residuals, magnitudes = { }, { }
  for index = 1, count do
    LineOps.checkCancelled()
    local point = {
      x = fit_x.residuals[index],
      y = fit_y.residuals[index]
    }
    residuals[index] = point
    magnitudes[index] = math.sqrt(point.x ^ 2 + point.y ^ 2)
  end
  local amplitude = percentile(magnitudes, 0.90) or 0
  if amplitude < 0.35 then
    return nil
  end
  for period = 2, math.floor(count / 2) do
    LineOps.checkCancelled()
    local errors = { }
    for index = period + 1, count do
      local dx = residuals[index].x - residuals[index - period].x
      local dy = residuals[index].y - residuals[index - period].y
      errors[#errors + 1] = math.sqrt(dx * dx + dy * dy)
    end
    if (percentile(errors, 0.90) or math.huge) <= math.max(0.15, amplitude * 0.08) then
      return period
    end
  end
  return nil
end
local PhaseAdjustSeries
PhaseAdjustSeries = function(values, frames, period)
  local count = #values
  local offsets
  do
    local _accum_0 = { }
    local _len_0 = 1
    for index = 1, math.max(1, period or 1) do
      _accum_0[_len_0] = 0
      _len_0 = _len_0 + 1
    end
    offsets = _accum_0
  end
  if not (period and period > 1) then
    local copied = { }
    for index, value in ipairs(values) do
      copied[index] = value
    end
    return copied, offsets
  end
  local fit = LinearFit(frames, values)
  if not (fit) then
    local copied = { }
    for index, value in ipairs(values) do
      copied[index] = value
    end
    return copied, offsets
  end
  local groups
  do
    local _accum_0 = { }
    local _len_0 = 1
    for index = 1, period do
      _accum_0[_len_0] = { }
      _len_0 = _len_0 + 1
    end
    groups = _accum_0
  end
  for index = 1, count do
    LineOps.checkCancelled()
    local phase = (index - 1) % period + 1
    groups[phase][#groups[phase] + 1] = fit.residuals[index]
  end
  for phase = 1, period do
    offsets[phase] = median(groups[phase]) or 0
  end
  local base
  do
    local _accum_0 = { }
    local _len_0 = 1
    for index = 1, count do
      _accum_0[_len_0] = values[index] - offsets[(index - 1) % period + 1]
      _len_0 = _len_0 + 1
    end
    base = _accum_0
  end
  return base, offsets
end
local ReadScalar
ReadScalar = function(text, name)
  local call = LineOps.lastTagCall(text, (name == "frz" and {
    "fr",
    "frz"
  } or name), true)
  return call and KiteCore.finiteNumber(call.value) or nil
end
local SetScalarText
SetScalarText = function(text, name, value)
  return LineOps.replaceTagCall(text, (name == "frz" and {
    "fr",
    "frz"
  } or name), (function(call)
    return "\\" .. tostring(call.raw_name) .. tostring(FormatNumber(value, 3))
  end), true)
end
local RefineSeries
RefineSeries = function(values, frames, period, options)
  local base, offsets = PhaseAdjustSeries(values, frames, period)
  local smooth = LocalRegression(base, frames, options.window, options.degree)
  local residuals
  do
    local _accum_0 = { }
    local _len_0 = 1
    for index = 1, #base do
      _accum_0[_len_0] = math.abs(base[index] - smooth[index])
      _len_0 = _len_0 + 1
    end
    residuals = _accum_0
  end
  local center = median(residuals) or 0
  local threshold = math.max(tonumber(options.threshold) or 0.35, center + 3 * mad(residuals, center))
  local strength = clamp((tonumber(options.strength) or 100) / 100, 0, 1)
  local out = { }
  for index = 1, #base do
    local use = options.scope == "Whole track" or residuals[index] > threshold
    local value
    if use then
      value = base[index] + (smooth[index] - base[index]) * strength
    else
      value = base[index]
    end
    local phase
    if period and period > 1 then
      phase = (index - 1) % period + 1
    else
      phase = 1
    end
    out[index] = value + (offsets[phase] or 0)
  end
  return out, threshold
end
local RefineryReport
RefineryReport = function(tracks)
  local lines = {
    "Tracks: " .. tostring(#tracks),
    ""
  }
  for track_index, track in ipairs(tracks) do
    local period = DetectAuthoredPeriod(track)
    local steps = { }
    for index = 2, #track.items do
      local dx = track.items[index].position.x - track.items[index - 1].position.x
      local dy = track.items[index].position.y - track.items[index - 1].position.y
      steps[#steps + 1] = math.sqrt(dx * dx + dy * dy)
    end
    local frames
    do
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = track.items
      for _index_0 = 1, #_list_0 do
        local item = _list_0[_index_0]
        _accum_0[_len_0] = item.start_frame
        _len_0 = _len_0 + 1
      end
      frames = _accum_0
    end
    local xs
    do
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = track.items
      for _index_0 = 1, #_list_0 do
        local item = _list_0[_index_0]
        _accum_0[_len_0] = item.position.x
        _len_0 = _len_0 + 1
      end
      xs = _accum_0
    end
    local ys
    do
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = track.items
      for _index_0 = 1, #_list_0 do
        local item = _list_0[_index_0]
        _accum_0[_len_0] = item.position.y
        _len_0 = _len_0 + 1
      end
      ys = _accum_0
    end
    local base_x = PhaseAdjustSeries(xs, frames, period)
    local base_y = PhaseAdjustSeries(ys, frames, period)
    local pseudo_samples = { }
    for index = 1, #frames do
      pseudo_samples[index] = {
        source_frame = frames[index],
        position = {
          x = base_x[index],
          y = base_y[index]
        },
        scale = {
          x = 100,
          y = 100
        },
        rotation = 0
      }
    end
    local pseudo = {
      samples = pseudo_samples
    }
    local candidate = PhaseSlipCandidate(pseudo)
    lines[#lines + 1] = tostring(track_index) .. ". " .. tostring(#track.items) .. " samples, frames " .. tostring(frames[1]) .. ".." .. tostring(frames[#frames]) .. ", median step " .. tostring(FormatNumber(median(steps) or 0, 3)) .. ", authored period " .. tostring(period or 'none') .. "."
    if candidate then
      lines[#lines + 1] = "   Duplicate-frame candidate at sample " .. tostring(candidate.index) .. "."
    end
  end
  return table.concat(lines, "\n")
end
local ApplyRefinery
ApplyRefinery = function(subs, tracks, options)
  local changedIndices, changed, candidates = { }, 0, 0
  for _index_0 = 1, #tracks do
    local _continue_0 = false
    repeat
      local track = tracks[_index_0]
      LineOps.checkCancelled()
      local count = #track.items
      local retarget = options.action == "Retarget Start" or options.action == "Retarget End"
      if count < (retarget and 1 or 3) then
        _continue_0 = true
        break
      end
      local frames
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = track.items
        for _index_1 = 1, #_list_0 do
          local item = _list_0[_index_1]
          _accum_0[_len_0] = item.start_frame
          _len_0 = _len_0 + 1
        end
        frames = _accum_0
      end
      local xs
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = track.items
        for _index_1 = 1, #_list_0 do
          local item = _list_0[_index_1]
          _accum_0[_len_0] = item.position.x
          _len_0 = _len_0 + 1
        end
        xs = _accum_0
      end
      local ys
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = track.items
        for _index_1 = 1, #_list_0 do
          local item = _list_0[_index_1]
          _accum_0[_len_0] = item.position.y
          _len_0 = _len_0 + 1
        end
        ys = _accum_0
      end
      local period = options.protect_authored and DetectAuthoredPeriod(track) or nil
      local nextX, nextY = { }, { }
      for index, value in ipairs(xs) do
        nextX[index] = value
      end
      for index, value in ipairs(ys) do
        nextY[index] = value
      end
      if options.action == "Smooth / Denoise" then
        nextX = RefineSeries(xs, frames, period, options)
        nextY = RefineSeries(ys, frames, period, options)
      elseif options.action == "Repair Duplicate Frame" then
        local base_x, offsetsX = PhaseAdjustSeries(xs, frames, period)
        local base_y, offsetsY = PhaseAdjustSeries(ys, frames, period)
        local pseudo_samples = { }
        for index = 1, count do
          pseudo_samples[index] = {
            source_frame = frames[index],
            position = {
              x = base_x[index],
              y = base_y[index]
            },
            scale = {
              x = 100,
              y = 100
            },
            rotation = 0
          }
        end
        local pseudo = {
          samples = pseudo_samples
        }
        local candidate = PhaseSlipCandidate(pseudo)
        if candidate then
          candidates = candidates + 1
          local repaired = RepairTransformPhase(pseudo, candidate, options.window, options.degree)
          for index = 1, count do
            LineOps.checkCancelled()
            local phase
            if period then
              phase = (index - 1) % period + 1
            else
              phase = 1
            end
            nextX[index] = repaired.samples[index].position.x + (offsetsX[phase] or 0)
            nextY[index] = repaired.samples[index].position.y + (offsetsY[phase] or 0)
          end
        end
      elseif options.action == "Retarget Start" or options.action == "Retarget End" then
        local sideStart = options.action == "Retarget Start"
        local anchorIndex = sideStart and 1 or count
        local dx = (tonumber(options.target_x) or xs[anchorIndex]) - xs[anchorIndex]
        local dy = (tonumber(options.target_y) or ys[anchorIndex]) - ys[anchorIndex]
        for index = 1, count do
          LineOps.checkCancelled()
          local t = (index - 1) / math.max(1, count - 1)
          local weight
          if count == 1 then
            weight = 1
          else
            weight = ((function()
              if sideStart then
                return 1 - (t * t * (3 - 2 * t))
              else
                return t * t * (3 - 2 * t)
              end
            end)())
          end
          nextX[index] = xs[index] + dx * weight
          nextY[index] = ys[index] + dy * weight
        end
      end
      for index, item in ipairs(track.items) do
        LineOps.checkCancelled()
        local dx, dy = nextX[index] - xs[index], nextY[index] - ys[index]
        if math.abs(dx) > numericEpsilon or math.abs(dy) > numericEpsilon then
          local line = CopyLine(subs[item.index])
          local text = SetPositionText(line.text, nextX[index], nextY[index])
          if options.linked_geometry then
            text = ShiftLinkedGeometry(text, dx, dy)
          end
          line.text = text
          subs[item.index] = line
          changedIndices[item.index] = true
        end
      end
      if options.include_transforms and options.action == "Smooth / Denoise" then
        local _list_0 = {
          "fscx",
          "fscy",
          "frz",
          "bord",
          "xbord",
          "ybord",
          "shad",
          "xshad",
          "yshad",
          "blur"
        }
        for _index_1 = 1, #_list_0 do
          local _continue_1 = false
          repeat
            local name = _list_0[_index_1]
            local values
            do
              local _accum_0 = { }
              local _len_0 = 1
              local _list_1 = track.items
              for _index_2 = 1, #_list_1 do
                local item = _list_1[_index_2]
                _accum_0[_len_0] = ReadScalar(item.line.text, name)
                _len_0 = _len_0 + 1
              end
              values = _accum_0
            end
            local complete = #values == count
            for _index_2 = 1, #values do
              local value = values[_index_2]
              if not finite(value) then
                complete = false
              end
            end
            if not (complete) then
              _continue_1 = true
              break
            end
            local refined = RefineSeries(values, frames, period, options)
            for index, item in ipairs(track.items) do
              local _continue_2 = false
              repeat
                LineOps.checkCancelled()
                if math.abs(refined[index] - values[index]) <= numericEpsilon then
                  _continue_2 = true
                  break
                end
                local line = CopyLine(subs[item.index])
                line.text = SetScalarText(line.text, name, refined[index])
                subs[item.index] = line
                changedIndices[item.index] = true
                _continue_2 = true
              until true
              if not _continue_2 then
                break
              end
            end
            _continue_1 = true
          until true
          if not _continue_1 then
            break
          end
        end
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  for _ in pairs(changedIndices) do
    changed = changed + 1
  end
  return changed, candidates
end
local RefineryDialog
RefineryDialog = function()
  local controls = {
    {
      class = "label",
      label = "Operation",
      x = 0,
      y = 0,
      width = 2,
      height = 1
    },
    {
      class = "dropdown",
      name = "action",
      items = {
        "Analyze",
        "Smooth / Denoise",
        "Repair Duplicate Frame",
        "Retarget Start",
        "Retarget End"
      },
      value = "Analyze",
      x = 2,
      y = 0,
      width = 4,
      height = 1
    },
    {
      class = "label",
      label = "Scope",
      x = 6,
      y = 0,
      width = 1,
      height = 1
    },
    {
      class = "dropdown",
      name = "scope",
      items = {
        "Outliers only",
        "Whole track"
      },
      value = "Outliers only",
      x = 7,
      y = 0,
      width = 3,
      height = 1
    },
    {
      class = "label",
      label = "Window",
      x = 0,
      y = 1,
      width = 1,
      height = 1
    },
    {
      class = "intedit",
      name = "window",
      value = 9,
      min = 3,
      x = 1,
      y = 1,
      width = 1,
      height = 1
    },
    {
      class = "label",
      label = "Degree",
      x = 2,
      y = 1,
      width = 1,
      height = 1
    },
    {
      class = "intedit",
      name = "degree",
      value = 2,
      min = 1,
      max = 3,
      x = 3,
      y = 1,
      width = 1,
      height = 1
    },
    {
      class = "label",
      label = "Strength %",
      x = 4,
      y = 1,
      width = 2,
      height = 1
    },
    {
      class = "floatedit",
      name = "strength",
      value = 100,
      min = 0,
      max = 100,
      x = 6,
      y = 1,
      width = 1,
      height = 1
    },
    {
      class = "label",
      label = "Min residual",
      x = 7,
      y = 1,
      width = 2,
      height = 1
    },
    {
      class = "floatedit",
      name = "threshold",
      value = 0.35,
      min = 0,
      x = 9,
      y = 1,
      width = 1,
      height = 1
    },
    {
      class = "checkbox",
      name = "protect_authored",
      label = "Preserve authored zig-zag / cycles",
      value = true,
      x = 0,
      y = 2,
      width = 4,
      height = 1
    },
    {
      class = "checkbox",
      name = "linked_geometry",
      label = "Shift linked \\org and clips",
      value = true,
      x = 4,
      y = 2,
      width = 3,
      height = 1
    },
    {
      class = "checkbox",
      name = "include_transforms",
      label = "Smooth scale / rotation / styling geometry",
      value = false,
      x = 7,
      y = 2,
      width = 5,
      height = 1
    },
    {
      class = "label",
      label = "Target X",
      x = 0,
      y = 3,
      width = 1,
      height = 1
    },
    {
      class = "floatedit",
      name = "target_x",
      value = 0,
      x = 1,
      y = 3,
      width = 2,
      height = 1
    },
    {
      class = "label",
      label = "Target Y",
      x = 3,
      y = 3,
      width = 1,
      height = 1
    },
    {
      class = "floatedit",
      name = "target_y",
      value = 0,
      x = 4,
      y = 3,
      width = 2,
      height = 1
    }
  }
  local pressed, values = aegisub.dialog.display(controls, {
    "Execute",
    "Cancel"
  }, {
    ok = "Execute",
    close = "Cancel"
  })
  if pressed == "Execute" then
    return values
  else
    return nil
  end
end
local RefineryMain
RefineryMain = function(subs, sel, active)
  local tracks = BuildRefineryTracks(subs, sel)
  if #tracks == 0 then
    ShowMessage("Moka Motion / Track Refinery", "Select contiguous FBF dialogue lines containing \\pos.")
    return sel
  end
  local options = RefineryDialog()
  if not (options) then
    return sel
  end
  if options.action == "Analyze" then
    ShowMessage("Moka Motion / Track Refinery", RefineryReport(tracks), 20)
    return sel
  end
  local ok, result, details = ApplyAtomically(subs, function()
    local changed, candidates = ApplyRefinery(subs, tracks, options)
    return true, {
      changed = changed,
      candidates = candidates
    }
  end)
  if not (ok and result) then
    ShowMessage(script_name, ok and details or result)
    return sel
  end
  local changed, candidates = details.changed, details.candidates
  if changed > 0 then
    aegisub.set_undo_point(tostring(script_name) .. ": Track Refinery / " .. tostring(options.action))
  end
  local message = tostring(options.action) .. ": " .. tostring(changed) .. " lines changed."
  if options.action == "Repair Duplicate Frame" then
    message = message .. " Duplicate-frame candidates repaired: " .. tostring(candidates) .. "."
  end
  ShowMessage("Moka Motion / Track Refinery", message, 6)
  return sel
end
Core.BuildRefineryTracks = BuildRefineryTracks
Core.DetectAuthoredPeriod = DetectAuthoredPeriod
Core.ApplyRefinery = ApplyRefinery
local PathParts
PathParts = function(path)
  local directory, name = tostring(path or ""):match("^(.*)[\\/]([^\\/]+)$")
  directory = directory or "."
  name = name or tostring(path or "")
  local stem = name:gsub("%.[^%.]+$", "")
  return directory, stem
end
local trimSettingsDefaults = {
  encoders = {
    x264 = "",
    ffmpeg = ""
  }
}
local trimSettingsStore = nil
local EncoderSettings
EncoderSettings = function()
  trimSettingsStore = trimSettingsStore or KiteUI.settings(script_namespace, script_version, trimSettingsDefaults)
  return trimSettingsStore:values("encoders")
end
local EncoderCommand
EncoderCommand = function(value, fallback)
  value = trim(value)
  if value == "" then
    return fallback
  else
    return value
  end
end
local TrimSettingsMain
TrimSettingsMain = function()
  local settings = EncoderSettings()
  local controls = {
    {
      class = "label",
      label = "FFmpeg handles exact seeking; x264 is the automatic fallback. Blank fields use PATH.",
      x = 0,
      y = 0,
      width = 10,
      height = 1
    },
    {
      class = "label",
      label = "x264 fallback",
      x = 0,
      y = 1,
      width = 2,
      height = 1
    },
    {
      class = "edit",
      name = "x264",
      value = settings.x264,
      x = 2,
      y = 1,
      width = 8,
      height = 1
    },
    {
      class = "label",
      label = "FFmpeg",
      x = 0,
      y = 2,
      width = 1,
      height = 1
    },
    {
      class = "edit",
      name = "ffmpeg",
      value = settings.ffmpeg,
      x = 1,
      y = 2,
      width = 9,
      height = 1
    }
  }
  while true do
    local _continue_0 = false
    repeat
      local button, values = aegisub.dialog.display(controls, {
        "Save",
        "x264...",
        "FFmpeg...",
        "Cancel"
      }, {
        ok = "Save",
        close = "Cancel"
      })
      if not (button and button ~= "Cancel") then
        return
      end
      controls[3].value = values.x264
      controls[5].value = values.ffmpeg
      if button == "x264..." or button == "FFmpeg..." then
        local chosen = aegisub.dialog.open("Choose " .. tostring(button == 'x264...' and 'x264' or 'FFmpeg'), "", "", "Executable (*.exe)|*.exe|All files (*.*)|*.*", false, true)
        if chosen then
          if button == "x264..." then
            controls[3].value = chosen
          else
            controls[5].value = chosen
          end
        end
        _continue_0 = true
        break
      end
      if not (button == "Save") then
        return
      end
      trimSettingsStore:update("encoders", values)
      local ok, err = trimSettingsStore:write()
      ShowMessage(script_name, ok and "Encoder settings saved." or "Could not save encoder settings:\n" .. tostring(err), 5)
      if ok then
        return
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
end
local PowerShellLiteral
PowerShellLiteral = function(value)
  return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end
local RunHiddenCommand = PyBridge.runProcess
local TrimPaths
TrimPaths = function(source, window, tempRoot)
  local directory, stem = PathParts(source)
  local end_frame = window.end_frame - 1
  local suffix = "[" .. tostring(window.start_frame) .. "-" .. tostring(end_frame) .. "]"
  tempRoot = trim(tempRoot) ~= "" and tempRoot or PyBridge.tempRoot()
  if trim(tempRoot) == "" then
    return nil, "The temporary directory is unavailable."
  end
  local token = tostring(stem:gsub('[^%w_.-]', '_')) .. "_" .. tostring(window.start_frame) .. "_" .. tostring(end_frame) .. "_" .. tostring(PyBridge.uniqueSuffix())
  local base = stem .. suffix
  local output = PyBridge.joinPath(directory, base .. ".mp4")
  local collision = 2
  while PyBridge.fileExists(output) do
    output = PyBridge.joinPath(directory, tostring(base) .. " (" .. tostring(collision) .. ").mp4")
    collision = collision + 1
  end
  return {
    output = output,
    partial_output = PyBridge.joinPath(directory, "." .. tostring(token) .. ".partial.mp4"),
    source_mkv = PyBridge.joinPath(tempRoot, token .. ".source.mkv"),
    source_y4m = PyBridge.joinPath(tempRoot, token .. ".source.y4m"),
    temp_mkv = PyBridge.joinPath(tempRoot, token .. ".mkv"),
    log = PyBridge.joinPath(tempRoot, token .. ".log")
  }
end
local BuildTrimCommands
BuildTrimCommands = function(source, window, paths, settings)
  if not (window and tonumber(window.frame_count) and window.frame_count > 0) then
    return nil, "The selected frame range is invalid."
  end
  if not (type(settings) == "table") then
    settings = { }
  end
  local startMs = Media.msFromFrame(window.start_frame)
  if not (finite(startMs)) then
    return nil, "The start time for frame " .. tostring(window.start_frame) .. " is unavailable."
  end
  if startMs < 0 then
    return nil, "The selection begins before the first decodable video frame."
  end
  local fps, measured_fps = Media.frameRateArgument(window.start_frame, window.end_frame)
  local constant_fps = fps ~= nil
  if not (fps) then
    fps, measured_fps = Media.frameRateArgument(window.start_frame, window.end_frame, {
      requireConstant = false
    })
  end
  if not (fps) then
    return nil, "The selected frames do not provide a usable frame rate."
  end
  local start_seconds = string.format("%.6f", startMs / 1000):gsub("0+$", ""):gsub("%.$", "")
  local count = tostring(window.frame_count)
  local timingFilter = "setpts=N/((" .. tostring(fps) .. ")*TB)"
  local ffmpeg = EncoderCommand(settings.ffmpeg, "ffmpeg")
  local x264 = EncoderCommand(settings.x264, "x264")
  local inputArgs = {
    "-hide_banner",
    "-nostdin",
    "-loglevel",
    "warning",
    "-y",
    "-ss",
    start_seconds,
    "-i",
    source,
    "-map",
    "0:V:0",
    "-an",
    "-frames:v",
    count
  }
  local direct_args
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #inputArgs do
      local value = inputArgs[_index_0]
      _accum_0[_len_0] = value
      _len_0 = _len_0 + 1
    end
    direct_args = _accum_0
  end
  local _list_0 = {
    "-vf",
    timingFilter,
    "-r",
    fps,
    "-fps_mode",
    "cfr",
    "-c:v",
    "libx264",
    "-crf",
    "16",
    "-tune",
    "fastdecode",
    "-f",
    "matroska",
    paths.temp_mkv
  }
  for _index_0 = 1, #_list_0 do
    local value = _list_0[_index_0]
    table.insert(direct_args, value)
  end
  local lossless_args
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #inputArgs do
      local value = inputArgs[_index_0]
      _accum_0[_len_0] = value
      _len_0 = _len_0 + 1
    end
    lossless_args = _accum_0
  end
  local _list_1 = {
    "-vf",
    timingFilter,
    "-r",
    fps,
    "-fps_mode",
    "cfr",
    "-c:v",
    "ffv1",
    "-level",
    "3",
    "-g",
    "1",
    "-f",
    "matroska",
    paths.source_mkv
  }
  for _index_0 = 1, #_list_1 do
    local value = _list_1[_index_0]
    table.insert(lossless_args, value)
  end
  local y4m_args
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #inputArgs do
      local value = inputArgs[_index_0]
      _accum_0[_len_0] = value
      _len_0 = _len_0 + 1
    end
    y4m_args = _accum_0
  end
  local _list_2 = {
    "-vf",
    timingFilter .. ",format=yuv420p",
    "-r",
    fps,
    "-fps_mode",
    "cfr",
    "-f",
    "yuv4mpegpipe",
    paths.source_y4m
  }
  for _index_0 = 1, #_list_2 do
    local value = _list_2[_index_0]
    table.insert(y4m_args, value)
  end
  return {
    ffmpeg = ffmpeg,
    x264 = x264,
    ffmpeg_probe = {
      executable = ffmpeg,
      args = {
        "-hide_banner",
        "-encoders"
      }
    },
    x264_probe = {
      executable = x264,
      args = {
        "--fullhelp"
      }
    },
    direct = {
      executable = ffmpeg,
      args = direct_args
    },
    lossless = {
      executable = ffmpeg,
      args = lossless_args
    },
    y4m = {
      executable = ffmpeg,
      args = y4m_args
    },
    x264_lossless = {
      executable = x264,
      args = {
        "--crf",
        "16",
        "--tune",
        "fastdecode",
        "--fps",
        fps,
        "--frames",
        count,
        "--muxer",
        "mkv",
        "-o",
        paths.temp_mkv,
        paths.source_mkv
      }
    },
    x264_y4m = {
      executable = x264,
      args = {
        "--demuxer",
        "y4m",
        "--crf",
        "16",
        "--tune",
        "fastdecode",
        "--fps",
        fps,
        "--frames",
        count,
        "--muxer",
        "mkv",
        "-o",
        paths.temp_mkv,
        paths.source_y4m
      }
    },
    remux = {
      executable = ffmpeg,
      args = {
        "-hide_banner",
        "-nostdin",
        "-loglevel",
        "warning",
        "-y",
        "-i",
        paths.temp_mkv,
        "-map",
        "0:V:0",
        "-c",
        "copy",
        "-movflags",
        "+faststart",
        "-f",
        "mp4",
        paths.partial_output
      }
    },
    fps = fps,
    measured_fps = measured_fps,
    constant_fps = constant_fps,
    start_seconds = start_seconds
  }
end
local PowerShellArguments
PowerShellArguments = function(arguments)
  return table.concat((function()
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #arguments do
      local value = arguments[_index_0]
      _accum_0[_len_0] = PowerShellLiteral(value)
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)(), " ")
end
local BuildTrimPowerShell
BuildTrimPowerShell = function(source, window, paths, settings)
  local commands, err = BuildTrimCommands(source, window, paths, settings)
  if not (commands) then
    return nil, err
  end
  return "try { & " .. tostring(PowerShellLiteral(commands.direct.executable)) .. " " .. tostring(PowerShellArguments(commands.direct.args)) .. "; exit $LASTEXITCODE } catch { exit 1 }"
end
local VideoTrimMain
VideoTrimMain = function(subs, sel, active)
  local window, err = SelectionWindow(subs, sel)
  if not (window) then
    ShowMessage(script_name, err)
    return sel
  end
  local source = Media.projectPath("video")
  if not (source) then
    ShowMessage(script_name, "Aegisub has no readable local video path.")
    return sel
  end
  local paths, pathsError = TrimPaths(source, window, PyBridge.tempRoot())
  if not (paths and paths.temp_mkv and paths.source_mkv and paths.partial_output and paths.log) then
    ShowMessage(script_name, pathsError or "The temporary directory is unavailable.")
    return sel
  end
  local settings = EncoderSettings()
  local commands, commandError = BuildTrimCommands(source, window, paths, settings)
  if not (commands) then
    ShowMessage(script_name, commandError)
    return sel
  end
  PyBridge.cleanup({
    paths.temp_mkv,
    paths.source_mkv,
    paths.source_y4m,
    paths.partial_output,
    paths.log
  })
  local RunCommand
  RunCommand = function(command)
    return RunHiddenCommand(command)
  end
  local cancelled
  cancelled = function(exit_code, output)
    local code = tonumber(exit_code)
    return code == -1073741510 or code == 3221225786 or code == 130 or tostring(output or ""):find("^C", 1, true) ~= nil
  end
  local tail
  tail = function(value, limit)
    if limit == nil then
      limit = 5000
    end
    value = tostring(value or "")
    if #value <= limit then
      return value
    end
    return "... full output is in the diagnostic log ...\n" .. value:sub(-limit)
  end
  local VerifyFrames
  VerifyFrames = function(path)
    local command = {
      executable = commands.ffmpeg,
      args = {
        "-hide_banner",
        "-nostdin",
        "-loglevel",
        "error",
        "-nostats",
        "-progress",
        "pipe:1",
        "-i",
        path,
        "-map",
        "0:V:0",
        "-an",
        "-f",
        "null",
        "-"
      }
    }
    local ok, output, exit_code = RunCommand(command)
    local count = nil
    for value in tostring(output or ""):gmatch("frame=(%d+)") do
      count = tonumber(value)
    end
    return ok and count == window.frame_count, count, output, exit_code
  end
  local logParts = {
    "Source: " .. tostring(source),
    "Frames: " .. tostring(window.start_frame) .. ".." .. tostring(window.end_frame - 1) .. " (" .. tostring(window.frame_count) .. ")",
    "Seek: " .. tostring(commands.start_seconds) .. " s",
    "Output FPS: " .. tostring(commands.fps) .. " (" .. tostring(commands.constant_fps and 'source timecodes are CFR' or 'irregular timecodes normalized to CFR') .. ")"
  }
  local AddLog
  AddLog = function(label, output, exit_code)
    if exit_code == nil then
      exit_code = nil
    end
    local status = exit_code ~= nil and " [exit " .. tostring(exit_code) .. "]" or ""
    logParts[#logParts + 1] = tostring(label) .. tostring(status) .. ":\n" .. tostring(output or '')
  end
  local fail
  fail = function(message, output, keepMkv)
    if output == nil then
      output = ""
    end
    if keepMkv == nil then
      keepMkv = false
    end
    PyBridge.removeFile(paths.source_mkv)
    PyBridge.removeFile(paths.source_y4m)
    PyBridge.removeFile(paths.partial_output)
    if not (keepMkv) then
      PyBridge.removeFile(paths.temp_mkv)
    end
    PyBridge.writeFile(paths.log, table.concat(logParts, "\n\n"))
    local kept = keepMkv and (Media.fileSize(paths.temp_mkv) or 0) > 0 and "\nIntermediate MKV: " .. tostring(paths.temp_mkv) or ""
    ShowMessage(script_name, tostring(message) .. "\n\n" .. tostring(tail(output)) .. "\nDiagnostic log: " .. tostring(paths.log) .. tostring(kept), 14)
    return sel
  end
  aegisub.progress.task("Checking the configured FFmpeg...")
  local ffmpegOk, ffmpegInfo, ffmpegExit = RunCommand(commands.ffmpeg_probe)
  AddLog("FFmpeg capability check", ffmpegInfo, ffmpegExit)
  if not (ffmpegOk) then
    return fail("FFmpeg is unavailable or could not be started. Check Utilities/Trim Settings.", ffmpegInfo)
  end
  local hasLibx264 = tostring(ffmpegInfo or ""):find(" libx264 ", 1, true) ~= nil
  local encoded = false
  local used_mode = nil
  local lastOutput = ""
  local lastExit
  if hasLibx264 then
    aegisub.progress.task("Seeking to frame " .. tostring(window.start_frame) .. " and encoding " .. tostring(window.frame_count) .. " frames with FFmpeg/libx264...")
    encoded, lastOutput, lastExit = RunCommand(commands.direct)
    encoded = encoded and (Media.fileSize(paths.temp_mkv) or 0) > 0
    if encoded then
      used_mode = "FFmpeg/libx264"
    end
    AddLog("FFmpeg/libx264", lastOutput, lastExit)
    if cancelled(lastExit, lastOutput) then
      return fail("Video clip creation was cancelled.", lastOutput)
    end
    if not (encoded) then
      PyBridge.removeFile(paths.temp_mkv)
    end
  else
    AddLog("FFmpeg/libx264", "libx264 is not present; using the configured external x264 fallback.")
  end
  if not (encoded) then
    aegisub.progress.task("Checking the configured x264 fallback...")
    local x264Ok, x264Info, x264Exit = RunCommand(commands.x264_probe)
    AddLog("x264 capability check", x264Info, x264Exit)
    if not (x264Ok) then
      return fail("Neither FFmpeg/libx264 nor the configured x264 fallback is usable. Check Utilities/Trim Settings.", x264Info)
    end
    local useLossless = tostring(x264Info or ""):find("lavf support (yes)", 1, true) ~= nil
    local extraction = useLossless and commands.lossless or commands.y4m
    local intermediate = useLossless and paths.source_mkv or paths.source_y4m
    local encoder = useLossless and commands.x264_lossless or commands.x264_y4m
    aegisub.progress.task("Extracting " .. tostring(window.frame_count) .. " source frames from " .. tostring(commands.start_seconds) .. " s...")
    local extracted, extractOutput, extractExit = RunCommand(extraction)
    AddLog(useLossless and "FFmpeg lossless extraction" or "FFmpeg Y4M extraction", extractOutput, extractExit)
    if cancelled(extractExit, extractOutput) then
      return fail("Video clip creation was cancelled.", extractOutput)
    end
    if not (extracted and (Media.fileSize(intermediate) or 0) > 0) then
      return fail("FFmpeg could not extract the selected frame range. The selection may extend beyond the video or the source may be undecodable.", extractOutput)
    end
    aegisub.progress.task("Encoding the extracted frames with x264...")
    encoded, lastOutput, lastExit = RunCommand(encoder)
    AddLog("External x264", lastOutput, lastExit)
    PyBridge.removeFile(paths.source_mkv)
    PyBridge.removeFile(paths.source_y4m)
    if cancelled(lastExit, lastOutput) then
      return fail("Video clip creation was cancelled.", lastOutput)
    end
    encoded = encoded and (Media.fileSize(paths.temp_mkv) or 0) > 0
    if encoded then
      used_mode = "external x264 fallback"
    end
  end
  if not (encoded) then
    return fail("Both H.264 encoding routes failed.", lastOutput)
  end
  aegisub.progress.task("Verifying the encoded frame count...")
  local exactMkv, mkvCount, verifyOutput, verifyExit = VerifyFrames(paths.temp_mkv)
  AddLog("Intermediate frame verification", verifyOutput, verifyExit)
  if not (exactMkv) then
    local received = mkvCount and tostring(mkvCount) or "unknown"
    return fail("The encoder produced " .. tostring(received) .. " frames instead of " .. tostring(window.frame_count) .. "; the incomplete clip was not published.", verifyOutput, true)
  end
  aegisub.progress.task("Remuxing the frame-exact clip...")
  local remuxed, remuxOutput, remuxExit = RunCommand(commands.remux)
  AddLog("MP4 remux", remuxOutput, remuxExit)
  if cancelled(remuxExit, remuxOutput) then
    return fail("Video clip creation was cancelled.", remuxOutput, true)
  end
  if not (remuxed and (Media.fileSize(paths.partial_output) or 0) > 0) then
    return fail("FFmpeg could not create the final MP4.", remuxOutput, true)
  end
  aegisub.progress.task("Verifying the final MP4...")
  local exactMp4, mp4Count, mp4VerifyOutput, mp4VerifyExit = VerifyFrames(paths.partial_output)
  AddLog("Final frame verification", mp4VerifyOutput, mp4VerifyExit)
  if not (exactMp4) then
    local received = mp4Count and tostring(mp4Count) or "unknown"
    return fail("The final MP4 contains " .. tostring(received) .. " frames instead of " .. tostring(window.frame_count) .. "; it was not published.", mp4VerifyOutput, true)
  end
  local published, publishError = PyBridge.replaceFile(paths.partial_output, paths.output)
  if not (published) then
    AddLog("Publish output", publishError)
    return fail("The verified MP4 could not be moved into the source directory.", publishError, true)
  end
  PyBridge.removeFile(paths.temp_mkv)
  PyBridge.removeFile(paths.log)
  local timing_note = commands.constant_fps and "" or " Irregular source timecodes were normalized to CFR " .. tostring(commands.fps) .. "."
  ShowMessage(script_name, "Created and verified " .. tostring(window.frame_count) .. "-frame MP4 for source frames " .. tostring(window.start_frame) .. ".." .. tostring(window.end_frame - 1) .. " with " .. tostring(used_mode) .. "." .. tostring(timing_note) .. "\n" .. tostring(paths.output), 8)
  return sel
end
local ExactPNGMain
ExactPNGMain = function(subs, sel, active)
  local window, err = SelectionWindow(subs, sel)
  if not (window) then
    ShowMessage(script_name, err)
    return sel
  end
  local source = Media.projectPath("video")
  if not (source) then
    ShowMessage(script_name, "Aegisub has no readable local video path.")
    return sel
  end
  local startMs = Media.msFromFrame(window.start_frame)
  if not (finite(startMs) and startMs >= 0) then
    ShowMessage(script_name, "The start time for frame " .. tostring(window.start_frame) .. " is unavailable.")
    return sel
  end
  local start_seconds = string.format("%.6f", startMs / 1000):gsub("0+$", ""):gsub("%.$", "")
  local destination = aegisub.dialog.save("Choose a name for the PNG sequence", "", "moka_sequence.png", "PNG (*.png)|*.png", false)
  if not (destination and destination ~= "") then
    return sel
  end
  local directory, stem = PathParts(destination)
  local baseFolder = PyBridge.joinPath(directory, stem .. "_frames")
  local folder, suffix = baseFolder, 2
  while PyBridge.directoryExists(folder) or PyBridge.fileExists(folder) do
    folder = tostring(baseFolder) .. " (" .. tostring(suffix) .. ")"
    suffix = suffix + 1
  end
  local made, mkdir_error = PyBridge.ensureDir(folder)
  if not (made) then
    ShowMessage(script_name, "Could not create " .. tostring(folder) .. ": " .. tostring(mkdir_error))
    return sel
  end
  local output = PyBridge.joinPath(folder, "frame_%08d.png")
  local ffmpeg_args = {
    "-hide_banner",
    "-nostdin",
    "-loglevel",
    "warning",
    "-y",
    "-ss",
    start_seconds,
    "-i",
    source,
    "-map",
    "0:v:0",
    "-an",
    "-frames:v",
    tostring(window.frame_count),
    "-fps_mode",
    "passthrough",
    "-start_number",
    tostring(window.start_frame),
    "-compression_level",
    "3",
    output
  }
  aegisub.progress.task("Decoding " .. tostring(window.frame_count) .. " exact frames...")
  local ok, diagnostic, exit_code = RunHiddenCommand({
    executable = EncoderCommand(EncoderSettings().ffmpeg, "ffmpeg"),
    args = ffmpeg_args
  })
  if not (ok) then
    if exit_code == 130 and aegisub and aegisub.cancel then
      aegisub.cancel()
    end
    ShowMessage(script_name, "FFmpeg failed. The partial folder was kept for inspection.\n\n" .. tostring(diagnostic or '') .. "\n" .. tostring(folder), 12)
    return sel
  end
  local count, missing, invalid = 0, { }, { }
  for frame = window.start_frame, window.end_frame - 1 do
    LineOps.checkCancelled()
    local name = string.format("frame_%08d.png", frame)
    local path = PyBridge.joinPath(folder, name)
    local valid, reason = Media.verifyPng(path)
    if valid then
      count = count + 1
    elseif reason == "missing" then
      missing[#missing + 1] = name
    else
      invalid[#invalid + 1] = name
    end
    if aegisub.progress and aegisub.progress.set then
      aegisub.progress.set(100 * (frame - window.start_frame + 1) / window.frame_count)
    end
  end
  if #missing > 0 or #invalid > 0 then
    local message = "The sequence is incomplete: " .. tostring(count) .. "/" .. tostring(window.frame_count) .. " valid PNG files."
    if #missing > 0 then
      message = message .. "\nMissing: " .. tostring(table.concat(missing, ', ')) .. "."
    end
    if #invalid > 0 then
      message = message .. "\nInvalid PNG: " .. tostring(table.concat(invalid, ', ')) .. "."
    end
    message = message .. "\n" .. tostring(folder)
    ShowMessage(script_name, message, 10)
    return sel
  end
  ShowMessage(script_name, "Created and verified " .. tostring(count) .. " PNG files for source frames " .. tostring(window.start_frame) .. ".." .. tostring(window.end_frame - 1) .. ".\n" .. tostring(folder), 7)
  return sel
end
local ValidateSelection
ValidateSelection = function(subs, sel)
  return sel and #sel > 0
end
local MenuPath
MenuPath = function(suffix)
  return tostring(script_name) .. "/" .. tostring(suffix)
end
local macros = {
  {
    MenuPath("Motion/Apply Motion"),
    "Apply one Mocha Transform track to selected lines, including FBF authored motion.",
    MotionMain(false),
    ValidateSelection
  },
  {
    MenuPath("Motion/Revert Motion"),
    "Mathematically invert one application using the same Transform data; no stored snapshots are required.",
    MotionMain(true),
    ValidateSelection
  },
  {
    MenuPath("Shapes/Create Clip"),
    "Convert Mocha mask or shape data to animated ASS \\clip.",
    ShapeMain("clip"),
    ValidateSelection
  },
  {
    MenuPath("Shapes/Create Inverse Clip"),
    "Convert Mocha mask or shape data to animated ASS \\iclip.",
    ShapeMain("iclip"),
    ValidateSelection
  },
  {
    MenuPath("Shapes/Create Vector Drawing"),
    "Convert Mocha mask or shape data to animated ASS vector drawings.",
    ShapeMain("shape"),
    ValidateSelection
  },
  {
    MenuPath("Perspective/Apply Power Pin"),
    "Apply Mocha CC Power Pin or Corner Pin data to selected lines and clips.",
    PowerPinMain,
    ValidateSelection
  },
  {
    MenuPath("Track Refinery"),
    "Analyze, denoise, repair duplicate frames, or retarget selected FBF tracks.",
    RefineryMain,
    ValidateSelection
  },
  {
    MenuPath("Utilities/Optimizer"),
    "Merge consecutive compatible FBF states without accumulating positional drift.",
    FBFOptimizer.main,
    FBFOptimizer.canRun
  },
  {
    MenuPath("Utilities/Inspect Mocha Data"),
    "Identify supported Mocha export data and inspect continuity problems.",
    InspectMain
  },
  {
    MenuPath("Utilities/Create Video Clip"),
    "Create and verify a frame-exact H.264 MP4 with adaptive FFmpeg/libx264 and external x264 fallback.",
    VideoTrimMain,
    ValidateSelection
  },
  {
    MenuPath("Utilities/Create Exact PNG Sequence"),
    "Create a frame-indexed PNG sequence for Mocha without an H.264 trim.",
    ExactPNGMain,
    ValidateSelection
  },
  {
    MenuPath("Utilities/Trim Settings"),
    "Configure FFmpeg and the optional external x264 fallback; blank fields use PATH.",
    TrimSettingsMain
  }
}
Core.macros = macros
Core.DEFAULTS = DEFAULTS
Core.MotionDialog = MotionDialog
Core.ParseInput = ParseInput
Core.MotionMain = MotionMain
Core.ShapeMain = ShapeMain
Core.PowerPinMain = PowerPinMain
Core.RefineryMain = RefineryMain
Core.InspectMain = InspectMain
Core.EncoderCommand = EncoderCommand
Core.TrimPaths = TrimPaths
Core.BuildTrimCommands = BuildTrimCommands
Core.BuildTrimPowerShell = BuildTrimPowerShell
Core.FBFOptimizer = FBFOptimizer
Core.OptimizerMain = FBFOptimizer.main
Core.WindowsQuoteArgument = PyBridge.quoteProcessArgument
Core.ManagedProcessScript = PyBridge.buildProcessScript
Core.RunHiddenCommand = RunHiddenCommand
Core.Trim = trim
Core.Finite = finite
Core.trim = Core.Trim
Core.finite = Core.Finite
Core.format_number = Core.FormatNumber
Core.parse_numbers = Core.ParseNumbers
Core.parse_meta = Core.ParseMeta
Core.parse_keyframe_sections = Core.ParseKeyframeSections
Core.parse_transform_data = Core.ParseTransformData
Core.parse_powerpin_data = Core.ParsePowerPinData
Core.parse_shape_data = Core.ParseShapeData
Core.parse_shake_shape_data = Core.ParseShakeShapeData
Core.parse_input = Core.ParseInput
Core.unwrap_angles = Core.UnwrapAngles
Core.unwrap_rotation_section = Core.UnwrapRotationSection
Core.linear_fit = Core.LinearFit
Core.vector_linearity = Core.VectorLinearity
Core.signed_quad_area = Core.SignedQuadArea
Core.validate_quad = Core.ValidateQuad
Core.series_from_track = Core.SeriesFromTrack
Core.build_shape_context = Core.BuildShapeContext
Core.render_shape_path = Core.RenderShapePath
Core.prepare_shape_samples = Core.PrepareShapeSamples
Core.shape_text = Core.ShapeText
Core.render_shape_line_text = Core.RenderShapeLineText
Core.strip_top_level_clips = Core.StripTopLevelClips
Core.apply_clip_text = Core.ApplyClipText
Core.selection_window = Core.SelectionWindow
Core.exclusive_end_frame = Core.ExclusiveEndFrame
Core.slice_track = Core.SliceTrack
Core.canonical_fps = Core.CanonicalFPS
Core.timing_diagnostics = Core.TimingDiagnostics
Core.validate_sync = Core.ValidateSync
Core.compress_output_lines = Core.CompressOutputLines
Core.selection_from_groups = Core.SelectionFromGroups
Core.apply_shape_track = Core.ApplyShapeTrack
Core.scale_track_coordinates = Core.ScaleTrackCoordinates
Core.transform_point = Core.TransformPoint
Core.inverse_transform_point = Core.InverseTransformPoint
Core.motion_point = Core.MotionPoint
Core.effective_transform_sample = Core.EffectiveTransformSample
Core.transform_clip_path = Core.TransformClipPath
Core.translate_clip_path = Core.TranslateClipPath
Core.apply_transform_text = Core.ApplyTransformText
Core.shift_frame_karaoke = Core.ShiftFrameKaraoke
Core.track_channels_constant = Core.TrackChannelsConstant
Core.transform_shear_risk = Core.TransformShearRisk
Core.track_deformation_flags = Core.TrackDeformationFlags
Core.line_transform_shear_risk = Core.LineTransformShearRisk
Core.effective_transform_track = Core.EffectiveTransformTrack
Core.try_linear_line = Core.TryLinearLine
Core.apply_transform_track = Core.ApplyTransformTrack
Core.perspective_warning_text = Core.PerspectiveWarningText
Core.validate_quad_track = Core.ValidateQuadTrack
Core.perspective_track = Core.PerspectiveTrack
Core.phase_slip_candidate = Core.PhaseSlipCandidate
Core.repair_transform_phase = Core.RepairTransformPhase
Core.cleanup_transform_track = Core.CleanupTransformTrack
Core.prepare_transform_track = Core.PrepareTransformTrack
Core.current_video_frame = Core.CurrentVideoFrame
Core.reference_row_for_window = Core.ReferenceRowForWindow
Core.optimize_transform_report = Core.OptimizeTransformReport
Core.build_refinery_tracks = Core.BuildRefineryTracks
Core.detect_authored_period = Core.DetectAuthoredPeriod
Core.apply_refinery = Core.ApplyRefinery
Core.motion_dialog = Core.MotionDialog
Core.motion_main = Core.MotionMain
Core.shape_main = Core.ShapeMain
Core.powerpin_main = Core.PowerPinMain
Core.refinery_main = Core.RefineryMain
Core.inspect_main = Core.InspectMain
Core.encoder_command = Core.EncoderCommand
Core.trim_paths = Core.TrimPaths
Core.build_trim_commands = Core.BuildTrimCommands
Core.build_trim_powershell = Core.BuildTrimPowerShell
Core.optimizer_main = Core.OptimizerMain
Core.windows_quote_argument = Core.WindowsQuoteArgument
Core.managed_process_script = Core.ManagedProcessScript
Core.run_hidden_command = Core.RunHiddenCommand
Core.version = depctrl
return depctrl:register(Core)
