local moduleVersion = "1.0.3"
local defaultMaxChars = 8000000
local maxDrawingScale = 9
local maxAlignment = 9
local maxWrapStyle = 3

local AssDrawing = {
    VERSION = moduleVersion,
    version = moduleVersion,
    DEFAULT_MAX_CHARS = defaultMaxChars,
}

local function safeRequire(name)
    local ok, value = pcall(require, name)
    if ok then return value end
    return nil
end

local DependencyControl = safeRequire("l0.DependencyControl")
local LineOps = assert(safeRequire("kite.LineOps"), "kite.LineOps is required")
local depctrl
if DependencyControl then
    depctrl = DependencyControl({
        name = "kite.AssDrawing",
        version = moduleVersion,
        description = "Pure ASS drawing validation profiles for Kite macros",
        author = "Kiterow",
        url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
        moduleName = "kite.AssDrawing",
        feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
        {
            { "kite.LineOps", version = "1.7.0" },
            { "kite.Core", version = "1.1.0" },
        },
    })
end

local Core = require("kite.Core")
local trim = Core.trim
local safeFillScalarTags = {
    pbo = true,
    bord = true,
    xbord = true,
    ybord = true,
    shad = true,
    xshad = true,
    yshad = true,
    blur = true,
    be = true,
    fscx = true,
    fscy = true,
    frx = true,
    fry = true,
    frz = true,
    fax = true,
    fay = true,
}

local function finiteNumber(value, fallback)
    return Core.finiteNumber(value) or fallback
end

local function containsControlBytes(text)
    return text:find("[%z\1-\8\11\12\14-\31]") ~= nil
end

local function validatePath(path, options)
    options = type(options) == "table" and options or {}
    local text = tostring(path or "")
    if options.trimOuter then text = trim(text) end
    if text == "" then return false end
    if options.maxChars and #text > options.maxChars then return false end
    if options.rejectControls and containsControlBytes(text) then return false end

    local firstCommand
    local command
    local coordinateCount = 0
    local splineOpen = false

    local function finishCommand()
        if not command then return false end
        if command == "c" then
            if coordinateCount ~= 0 or not splineOpen then return false end
            splineOpen = false
            return true
        elseif command == "s" then
            if coordinateCount < 6 or coordinateCount % 2 ~= 0 then return false end
            splineOpen = true
            return true
        elseif command == "p" then
            return splineOpen and coordinateCount == 2
        elseif command == "b" then
            splineOpen = false
            return coordinateCount >= 6 and coordinateCount % 6 == 0
        elseif command == "l" then
            splineOpen = false
            return coordinateCount >= 2 and coordinateCount % 2 == 0
        end
        splineOpen = false
        return coordinateCount == 2
    end

    for token in text:gmatch("%S+") do
        local candidate = token:lower()
        if candidate:match("^[mnlbspc]$") then
            if token ~= candidate then return false end
            if command and not finishCommand() then return false end
            command = candidate
            firstCommand = firstCommand or command
            coordinateCount = 0
        else
            if not command or command == "c" or finiteNumber(token) == nil then return false end
            coordinateCount = coordinateCount + 1
        end
    end

    return (firstCommand == "m" or firstCommand == "n") and finishCommand()
end

local function validateSafeFillOverride(block)
    local rawBlock = tostring(block or "")
    if rawBlock:sub(1, 1) ~= "{" or rawBlock:sub(-1) ~= "}" then return false end
    local inner = trim(rawBlock:sub(2, -2))
    if inner == "" or inner:sub(1, 1) ~= "\\" then return false end

    local cursor = 1
    while cursor <= #inner do
        if inner:sub(cursor, cursor) ~= "\\" then return false end
        local nextSlash = inner:find("\\", cursor + 1, true)
        local stop = nextSlash and nextSlash - 1 or #inner
        local fragment = trim(inner:sub(cursor + 1, stop))
        if fragment == "" then return false end
        local name = fragment:match("^([1-4]?%a+)")
        if not name then return false end
        local rest = trim(fragment:sub(#name + 1))

        if name == "p" then
            local level = finiteNumber(rest)
            if not level or level ~= math.floor(level) or level < 0 or level > maxDrawingScale then return false end
        elseif name == "an" then
            local alignment = finiteNumber(rest)
            if not alignment or alignment ~= math.floor(alignment) or alignment < 1 or alignment > maxAlignment then return false end
        elseif name == "q" then
            local wrap = finiteNumber(rest)
            if not wrap or wrap ~= math.floor(wrap) or wrap < 0 or wrap > maxWrapStyle then return false end
        elseif name == "pos" or name == "org" then
            local x, y = rest:match("^%(%s*([%+%-]?[%d%.]+)%s*,%s*([%+%-]?[%d%.]+)%s*%)$")
            if finiteNumber(x) == nil or finiteNumber(y) == nil then return false end
        elseif name == "move" then
            local body = rest:match("^%((.*)%)$")
            if not body then return false end
            local values = {}
            for rawValue in (body .. ","):gmatch("(.-),") do
                local value = trim(rawValue)
                if value == "" then return false end
                local parsedValue = finiteNumber(value)
                if parsedValue == nil then return false end
                values[#values + 1] = parsedValue
            end
            if #values ~= 4 and #values ~= 6 then return false end
        elseif name == "c" or name:match("^[1-4]c$") then
            local hex = rest:match("^&[Hh](%x+)&$")
            if not hex or (#hex ~= 6 and #hex ~= 8) then return false end
        elseif name == "alpha" or name:match("^[1-4]a$") then
            if not rest:match("^&[Hh]%x%x&$") then return false end
        elseif safeFillScalarTags[name] then
            if finiteNumber(rest) == nil then return false end
        else
            return false
        end

        cursor = nextSlash or #inner + 1
    end
    return true
end

local function validateDrawingLine(text, options)
    options = type(options) == "table" and options or {}
    if type(text) ~= "string" or text == "" then return false end
    if options.requireVisibleContent and trim(text) == "" then return false end
    if options.maxChars and #text > options.maxChars then return false end
    if options.rejectControls and containsControlBytes(text) then return false end
    if options.rejectNewlines and text:find("[\r\n]") then return false end

    local drawings = {}
    for _, section in ipairs(LineOps.scanSections(text)) do
        if section.type == "override" then
            if options.validateOverride and not options.validateOverride("{" .. section.text .. "}") then return false end
        elseif section.type == "drawing" then
            if trim(section.text) ~= "" then drawings[#drawings + 1] = section.text end
        elseif trim(section.text) ~= "" then
            return false
        end
    end
    if #drawings == 0 then return false end

    local pathValidator = options.validatePath or validatePath
    return pathValidator(table.concat(drawings, " "))
end

local function validateAutoMaskPath(path, maxChars)
    return validatePath(path, {
        trimOuter = true,
        maxChars = maxChars or defaultMaxChars,
        rejectControls = true,
    })
end

local function validatePng2AssPath(path)
    return validatePath(path)
end

local function validateAutoMaskLine(text, maxChars)
    local limit = maxChars or defaultMaxChars
    return validateDrawingLine(text, {
        requireVisibleContent = true,
        maxChars = limit,
        rejectControls = true,
        rejectNewlines = true,
        validateOverride = validateSafeFillOverride,
        validatePath = function(path) return validateAutoMaskPath(path, limit) end,
    })
end

local function validatePng2AssLine(text, maxChars)
    return validateDrawingLine(text, {
        maxChars = maxChars or defaultMaxChars,
        rejectControls = true,
        rejectNewlines = true,
        validatePath = validatePng2AssPath,
    })
end

function AssDrawing.mapCoordinates(path, callback, decimals)
    assert(validatePath(path), "Invalid ASS drawing path.")
    local output, pending = {}, nil
    for token in path:gmatch("%S+") do
        local number = finiteNumber(token)
        if number == nil then
            output[#output + 1] = token
        elseif pending == nil then
            pending = number
        else
            LineOps.checkCancelled()
            local x, y, err = callback(pending, number)
            assert(not err and finiteNumber(x) and finiteNumber(y), err or "Non-finite drawing coordinates.")
            output[#output + 1] = Core.formatNumber(x, decimals)
            output[#output + 1] = Core.formatNumber(y, decimals)
            pending = nil
        end
    end
    return table.concat(output, " ")
end

AssDrawing.finiteNumber = finiteNumber
AssDrawing.validatePath = validatePath
AssDrawing.validateSafeFillOverride = validateSafeFillOverride
AssDrawing.validateDrawingLine = validateDrawingLine
AssDrawing.validateAutoMaskPath = validateAutoMaskPath
AssDrawing.validateAutoMaskLine = validateAutoMaskLine
AssDrawing.validatePng2AssPath = validatePng2AssPath
AssDrawing.validatePng2AssLine = validatePng2AssLine

if depctrl and depctrl.register then return depctrl:register(AssDrawing) end
return AssDrawing
