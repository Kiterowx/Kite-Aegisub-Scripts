local moduleVersion = "1.1.0"
local Core = { VERSION = moduleVersion, version = moduleVersion }
local maximumRoundDecimals = 12

local function safeRequire(name)
    local ok, value = pcall(require, name)
    if ok then return value end
    return nil
end

local aegisubUtil = safeRequire("aegisub.util")
local DependencyControl = safeRequire("l0.DependencyControl")
local depctrl
if DependencyControl then
    depctrl = DependencyControl({
        name = "kite.Core",
        version = moduleVersion,
        description = "Shared pure primitives for Kite modules and macros",
        author = "Kiterow",
        url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
        moduleName = "kite.Core",
        feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
    })
end

local function trim(value)
    return (tostring(value == nil and "" or value):match("^%s*(.-)%s*$")) or ""
end

local function copy(value)
    if type(value) ~= "table" then return value end
    if aegisubUtil and type(aegisubUtil.copy) == "function" then
        local ok, result = pcall(aegisubUtil.copy, value)
        if ok then return result end
    end
    local result = {}
    for key, item in pairs(value) do result[key] = item end
    return setmetatable(result, getmetatable(value))
end

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    if aegisubUtil and type(aegisubUtil.deep_copy) == "function" then
        local ok, result = pcall(aegisubUtil.deep_copy, value)
        if ok then return result end
    end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do
        result[deepCopy(key, seen)] = deepCopy(item, seen)
    end
    return setmetatable(result, getmetatable(value))
end

local function finiteNumber(value)
    local number = tonumber(value)
    if not number or number ~= number or math.abs(number) == math.huge then return nil end
    return number
end

local function round(value)
    value = finiteNumber(value) or 0
    if value >= 0 then return math.floor(value + 0.5) end
    return math.ceil(value - 0.5)
end

local function roundTo(value, decimals)
    value = finiteNumber(value) or 0
    decimals = math.max(0, math.min(maximumRoundDecimals, round(finiteNumber(decimals) or 0)))
    local factor = 10 ^ decimals
    if value >= 0 then return math.floor(value * factor + 0.5) / factor end
    return math.ceil(value * factor - 0.5) / factor
end

local function shallowEqual(left, right)
    left = type(left) == "table" and left or {}
    right = type(right) == "table" and right or {}
    for key, value in pairs(left) do if right[key] ~= value then return false end end
    for key, value in pairs(right) do if left[key] ~= value then return false end end
    return true
end

local function clamp(value, minimum, maximum)
    value = finiteNumber(value) or 0
    if minimum ~= nil and value < minimum then return minimum end
    if maximum ~= nil and value > maximum then return maximum end
    return value
end

Core.trim = trim
Core.finiteNumber = finiteNumber
Core.copy = copy
Core.deepCopy = deepCopy
Core.round = round
Core.roundTo = roundTo
Core.shallowEqual = shallowEqual
Core.clamp = clamp

function Core.formatNumber(value, decimals, fallback)
    local defaultDecimals = 3
    value = finiteNumber(value) or finiteNumber(fallback) or 0
    decimals = math.max(0,math.floor(finiteNumber(decimals) or defaultDecimals))
    local text = string.format("%."..decimals.."f",value):gsub(",",".")
    if decimals>0 then text=text:gsub("0+$",""):gsub("%.$","") end
    return text=="-0" and "0" or text
end

function Core.median(values, inPlace)
    local sorted=inPlace and values or {}
    if not inPlace then
        for _,value in ipairs(values or {}) do
            local number=finiteNumber(value)
            if number then sorted[#sorted+1]=number end
        end
    end
    if #sorted==0 then return nil end
    table.sort(sorted)
    local middle=math.floor((#sorted+1)/2)
    if #sorted%2==1 then return sorted[middle] end
    return sorted[middle]/2+sorted[middle+1]/2
end

if depctrl then
    Core.version = depctrl
    return depctrl:register(Core)
end
return Core
