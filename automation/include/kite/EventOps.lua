local moduleVersion = "1.3.1"
local EventOps = { VERSION = moduleVersion, version = moduleVersion }

local function safeRequire(name)
    local ok, value = pcall(require, name)
    if ok then return value end
    return nil
end

local DependencyControl = safeRequire("l0.DependencyControl")
local Core = assert(safeRequire("kite.Core"), "kite.Core is required")
local LineOps = assert(safeRequire("kite.LineOps"), "kite.LineOps is required")
local depctrl
if DependencyControl then
    depctrl = DependencyControl({
        name = "kite.EventOps",
        version = moduleVersion,
        description = "Shared dialogue-event transformations for Kite macros",
        author = "Kiterow",
        url = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
        moduleName = "kite.EventOps",
        feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
        {
            { "kite.Core", version = "1.1.0" },
            { "kite.LineOps", version = "1.7.0" },
            {"kite.UI",version="1.5.0"},
        },
    })
end

local trim = Core.trim
local copy = Core.deepCopy

local function dialogueIndices(subtitles, selection)
    return LineOps.normalizeIndices(subtitles, selection, function(line)
        return line and line.class == "dialogue"
    end)
end

local function leadingPrefix(text)
    text = tostring(text or "")
    local parts = {}
    for _, section in ipairs(LineOps.scanSections(text)) do
        if section.type == "text" or section.type == "drawing" then break end
        local raw = text:sub(section.start, section.finish)
        if section.type == "override" then
            raw = LineOps.removeTagCalls(raw, { p = true, pbo = true })
            if raw ~= "" then parts[#parts + 1] = raw end
        elseif section.type == "comment" then
            parts[#parts + 1] = raw
        end
    end
    return table.concat(parts)
end

local function cloneWithVisibleText(subtitles, selection, replacement)
    local indices = dialogueIndices(subtitles, selection)
    local operations = {}
    for _, index in ipairs(indices) do
        local clone = copy(subtitles[index])
        clone.text = leadingPrefix(clone.text) .. tostring(replacement or "")
        operations[#operations + 1] = { index = index + 1, lines = { clone } }
    end
    if #operations == 0 then return {}, 0 end
    local inserted = LineOps.insertLines(subtitles, operations)
    return inserted, #inserted
end

local lowerMap = {
    ["Á"] = "á", ["É"] = "é", ["Í"] = "í", ["Ó"] = "ó", ["Ú"] = "ú", ["Ü"] = "ü", ["Ñ"] = "ñ",
    ["À"] = "à", ["È"] = "è", ["Ì"] = "ì", ["Ò"] = "ò", ["Ù"] = "ù", ["Ç"] = "ç",
}

local letterSet = {
    ["á"] = true, ["é"] = true, ["í"] = true, ["ó"] = true, ["ú"] = true, ["ü"] = true, ["ñ"] = true,
    ["à"] = true, ["è"] = true, ["ì"] = true, ["ò"] = true, ["ù"] = true, ["ç"] = true,
}

local function utf8Characters(text)
    local out = {}
    for char in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = char end
    return out
end

local function lowerCharacter(char)
    return lowerMap[char] or tostring(char or ""):lower()
end

local function isLetter(char)
    if tostring(char or ""):match("^%a$") then return true end
    return letterSet[lowerCharacter(char)] == true
end

local hyphens = { ["-"] = true, ["‐"] = true, ["‑"] = true }

local function hasStutter(text)
    local visible = LineOps.visibleText(text)
    local chars = utf8Characters(visible)
    for index = 1, #chars - 2 do
        local left, separator, right = chars[index], chars[index + 1], chars[index + 2]
        if hyphens[separator] and isLetter(left) and isLetter(right) and lowerCharacter(left) == lowerCharacter(right) then
            return true, index
        end
    end
    return false
end

local function addEffectMarker(effect, marker)
    effect = trim(effect)
    marker = trim(marker)
    if marker == "" then return effect, false end
    for token in effect:gmatch("%S+") do
        if token:lower() == marker:lower() then return effect, false end
    end
    if effect == "" then return marker, true end
    return effect .. " " .. marker, true
end

local function markStutter(subtitles, selection, marker)
    local changed = 0
    for _, index in ipairs(dialogueIndices(subtitles, selection)) do
        local line = subtitles[index]
        if hasStutter(line.text) then
            local effect, modified = addEffectMarker(line.effect, marker or "Komari")
            if modified then
                line.effect = effect
                subtitles[index] = line
                changed = changed + 1
            end
        end
    end
    return selection, changed
end

local function zero(value)
    local number = tonumber(trim(value))
    return number ~= nil and number == 0
end

local function adjustFade(text, removeIn, removeOut)
    local result, changed = LineOps.mapTagCalls(text, "fad", function(call)
        local args = LineOps.splitArguments(call.value)
        if #args ~= 2 then return nil end
        local first, second = trim(args[1]), trim(args[2])
        local modified = false
        if removeIn and not zero(first) then first, modified = "0", true end
        if removeOut and not zero(second) then second, modified = "0", true end
        if not modified then return nil end
        if zero(first) and zero(second) then return false end
        return "\\fad(" .. first .. "," .. second .. ")"
    end, { top_level_only = true })
    if changed > 0 then result = result:gsub("{%s*}", "") end
    return result, changed
end

local function setFadeComponent(text, component, duration)
    component = tostring(component or ""):lower()
    if component == "intro" then component = "in" end
    if component == "outro" then component = "out" end
    if component ~= "in" and component ~= "out" then return nil, "invalid_component" end
    duration = tonumber(duration)
    if not duration or duration ~= duration or math.abs(duration) == math.huge or duration < 0 then
        return nil, "invalid_duration"
    end
    local durationText
    if duration == math.floor(duration) then
        durationText = tostring(math.floor(duration))
    else
        durationText = tostring(duration):gsub("0+$", ""):gsub("%.$", "")
    end
    local invalid, found = false, false
    local result, changed = LineOps.mapTagCalls(text, "fad", function(call)
        found = true
        local value = trim(call.value)
        local args = LineOps.splitArguments(value)
        local first, second = trim(args[1]), trim(args[2])
        local firstNumber, secondNumber = tonumber(first), tonumber(second)
        if value:sub(1, 1) ~= "(" or value:sub(-1) ~= ")" or #args ~= 2
            or not firstNumber or not secondNumber
            or firstNumber ~= firstNumber or secondNumber ~= secondNumber
            or math.abs(firstNumber) == math.huge or math.abs(secondNumber) == math.huge
            or firstNumber < 0 or secondNumber < 0 then
            invalid = true
            return nil
        end
        if component == "in" then first = durationText else second = durationText end
        return "\\fad(" .. first .. "," .. second .. ")"
    end, { top_level_only = true })
    if invalid then return nil, "invalid_fad" end
    if not found then
        local first = component == "in" and durationText or "0"
        local second = component == "out" and durationText or "0"
        result = LineOps.prependTag(text, "\\fad(" .. first .. "," .. second .. ")")
        changed = 1
    end
    return result, nil, changed
end

local function continuousFadeCleanup(subtitles, selection)
    local groups, byTime = {}, {}
    for _, index in ipairs(dialogueIndices(subtitles, selection)) do
        local line = subtitles[index]
        local startTime, endTime = tonumber(line.start_time), tonumber(line.end_time)
        if startTime and endTime and startTime == startTime and endTime == endTime
            and math.abs(startTime) < math.huge and math.abs(endTime) < math.huge and endTime > startTime then
            local key = tostring(startTime) .. "\31" .. tostring(endTime)
            local group = byTime[key]
            if not group then
                group = { start_time = startTime, end_time = endTime, first_index = index, indices = {} }
                byTime[key] = group
                groups[#groups + 1] = group
            end
            if index < group.first_index then group.first_index = index end
            group.indices[#group.indices + 1] = index
        end
    end
    if #groups < 2 then return selection, 0 end
    table.sort(groups, function(left, right)
        if left.start_time ~= right.start_time then return left.start_time < right.start_time end
        if left.end_time ~= right.end_time then return left.end_time < right.end_time end
        return left.first_index < right.first_index
    end)
    local startsAt, endsAt = {}, {}
    for index, group in ipairs(groups) do
        startsAt[group.start_time] = startsAt[group.start_time] or {}
        endsAt[group.end_time] = endsAt[group.end_time] or {}
        startsAt[group.start_time][#startsAt[group.start_time] + 1] = index
        endsAt[group.end_time][#endsAt[group.end_time] + 1] = index
    end
    local function hasOther(indices, current)
        for _, index in ipairs(indices or {}) do
            if index ~= current then return true end
        end
        return false
    end
    local removeIn, removeOut = {}, {}
    for index, group in ipairs(groups) do
        removeIn[index] = hasOther(endsAt[group.start_time], index)
        removeOut[index] = hasOther(startsAt[group.end_time], index)
    end
    local modified = 0
    for groupIndex, group in ipairs(groups) do
        if removeIn[groupIndex] or removeOut[groupIndex] then
            for _, lineIndex in ipairs(group.indices) do
                local line = subtitles[lineIndex]
                local text, count = adjustFade(line.text, removeIn[groupIndex], removeOut[groupIndex])
                if count > 0 then
                    line.text = text
                    subtitles[lineIndex] = line
                    modified = modified + 1
                end
            end
        end
    end
    return selection, modified
end

local randomModulus = 2147483647
local randomMultiplier = 48271
local defaultSeedStride = 7919

local function randomIndex(state, maximum)
    state = (randomMultiplier * state) % randomModulus
    return state, math.floor(state % maximum) + 1
end

local function shuffleLineText(subtitles, selection, seed)
    local indices = dialogueIndices(subtitles, selection)
    if #indices < 2 then return selection, 0 end
    local original, shuffled = {}, {}
    for position, index in ipairs(indices) do
        original[position] = tostring(subtitles[index].text or "")
        shuffled[position] = original[position]
    end
    local numericSeed = tonumber(seed)
    if not numericSeed or numericSeed ~= numericSeed or math.abs(numericSeed) == math.huge then
        numericSeed = os.time() + #indices * defaultSeedStride
    end
    local state = math.floor(numericSeed % randomModulus)
    if state <= 0 then state = state + randomModulus - 1 end
    for index = #shuffled, 2, -1 do
        local swap
        state, swap = randomIndex(state, index)
        shuffled[index], shuffled[swap] = shuffled[swap], shuffled[index]
    end
    local same = true
    for index = 1, #shuffled do if shuffled[index] ~= original[index] then same = false; break end end
    if same then
        local first = table.remove(shuffled, 1)
        shuffled[#shuffled + 1] = first
    end
    local modified = 0
    for position, index in ipairs(indices) do
        if shuffled[position] ~= original[position] then
            local line = subtitles[index]
            line.text = shuffled[position]
            subtitles[index] = line
            modified = modified + 1
        end
    end
    return selection, modified
end

EventOps.dialogueIndices = dialogueIndices
EventOps.leadingPrefix = leadingPrefix
EventOps.cloneWithVisibleText = cloneWithVisibleText
EventOps.hasStutter = hasStutter
EventOps.addEffectMarker = addEffectMarker
EventOps.markStutter = markStutter
EventOps.adjustFade = adjustFade
EventOps.setFadeComponent = setFadeComponent
EventOps.continuousFadeCleanup = continuousFadeCleanup
EventOps.shuffleLineText = shuffleLineText

EventOps.properties = (function()
local fields={"Title","Original Script","Original Translation","Original Editing","Original Timing","Synch Point","Script Updated By","Update Details"}
local projectKeys={}
for _,key in ipairs({"Last Style Storage","Audio File","Video File","Video AR Mode","Video AR Value","Video Zoom Percent","Video Position","Scroll Position","Active Line","Automation Scripts","Keyframes File","Timecodes File","Audio URI","Video URI"}) do projectKeys[key]=true end
local labels={
    en={title="Properties and Cleanup",save="Save",cancel="Cancel",episode="Add episode from filename",clean="Clean the whole subtitle file",hint="Cleanup removes project paths, extradata, comments, Actor, Effect and empty dialogue lines.",missing="Save the subtitle with an episode number in its filename first.",empty="Enter a title before adding an episode.",fields={"Title","Original script","Translation","Editing","Timing","Sync point","Updated by","Update details"}},
    es={title="Propiedades y limpieza",save="Guardar",cancel="Cancelar",episode="Añadir episodio desde el nombre del archivo",clean="Limpiar todo el archivo de subtítulos",hint="La limpieza quita rutas del proyecto, extradata, comentarios, Actor, Effect y líneas de diálogo vacías.",missing="Guarda el subtítulo con un número de episodio en su nombre.",empty="Escribe un título antes de añadir el episodio.",fields={"Título","Guion original","Traducción","Edición","Tiempos","Punto de sincronía","Actualizado por","Detalles de actualización"}},
    pt={title="Propriedades e limpeza",save="Salvar",cancel="Cancelar",episode="Adicionar episódio pelo nome do arquivo",clean="Limpar todo o arquivo de legendas",hint="A limpeza remove caminhos do projeto, extradata, comentários, Actor, Effect e linhas de diálogo vazias.",missing="Salve a legenda com um número de episódio no nome.",empty="Preencha o título antes de adicionar o episódio.",fields={"Título","Roteiro original","Tradução","Edição","Tempos","Ponto de sincronia","Atualizado por","Detalhes da atualização"}},
}
local function section(line)
    return (trim(line.section):lower():gsub("^%[", ""):gsub("%]$", ""))
end
local function scriptInfo(line)
    local name=section(line)
    return line.class=="info" and (name=="" or name=="script info")
end
local function read(subs)
    local values={}
    for _,field in ipairs(fields) do values[field]="" end
    local seen={}
    for index=1,#subs do
        local line=subs[index]
        if scriptInfo(line) and values[line.key]~=nil and not seen[line.key] then values[line.key]=tostring(line.value or "");seen[line.key]=true end
    end
    return values
end
local function cleanText(text)
    local output={}
    text=tostring(text or "")
    for _,part in ipairs(LineOps.scanSections(text)) do
        if part.type~="comment" then output[#output+1]=text:sub(part.start,part.finish) end
    end
    return table.concat(output)
end
local function apply(subs,selection,values,clean)
    local wanted,indices={},{}
    for _,index in ipairs(selection or {}) do wanted[index]=true end
    for index=1,#subs do indices[index]=index end
    return LineOps.transaction(subs,nil,function()
        local changes=0
        local function remove(index)
            subs.delete(index);table.remove(indices,index);changes=changes+1
        end
        if clean then
            for index=#subs,1,-1 do
                LineOps.checkCancelled()
                local line=subs[index]
                local name=section(line)
                if name=="aegisub project garbage" or name=="aegisub extradata" or line.class=="extradata" or (line.class=="info" and projectKeys[line.key]) then remove(index)
                elseif line.class=="dialogue" then
                    if line.comment then remove(index)
                    else
                        local nextLine=Core.copy(line)
                        nextLine.text=cleanText(line.text)
                        nextLine.actor,nextLine.effect,nextLine.extra="","",nil
                        local analysis=LineOps.analyzeText(nextLine.text)
                        if analysis.visible:gsub("%s+","")=="" and not analysis.has_drawing then remove(index)
                        elseif nextLine.text~=line.text or line.actor~="" or line.effect~="" or line.extra~=nil then subs[index]=nextLine;changes=changes+1 end
                    end
                end
            end
        end
        local first={}
        local duplicates={}
        for index=1,#subs do
            LineOps.checkCancelled()
            local line=subs[index]
            if scriptInfo(line) and values[line.key]~=nil then
                if first[line.key] then duplicates[#duplicates+1]=index
                else first[line.key]=true
                    if tostring(line.value or "")~=values[line.key] then line.value=values[line.key];subs[index]=line;changes=changes+1 end
                end
            end
        end
        for index=#duplicates,1,-1 do remove(duplicates[index]) end
        local insertAt=1
        for index=1,#subs do if scriptInfo(subs[index]) then insertAt=index+1 elseif insertAt>1 then break end end
        for _,field in ipairs(fields) do
            LineOps.checkCancelled()
            if not first[field] then
                subs.insert(insertAt,{class="info",section="[Script Info]",key=field,value=values[field] or ""})
                table.insert(indices,insertAt,false);insertAt=insertAt+1;changes=changes+1
            end
        end
        local result={}
        for index,original in ipairs(indices) do if wanted[original] and subs[index].class=="dialogue" then result[#result+1]=index end end
        return result,changes
    end)
end
local function run(subs,selection,context)
    context=context or {}
    local text=labels[context.language] or labels.en
    local values=read(subs)
    local addEpisode,clean=false,false
    while true do
        local width,labelWidth=40,12
        local dialog={{class="label",label=text.title,x=0,y=0,width=width,height=1}}
        for index,key in ipairs(fields) do
            dialog[#dialog+1]={class="label",label=text.fields[index],x=0,y=index+1,width=labelWidth,height=1}
            dialog[#dialog+1]={class="edit",name="property"..index,value=values[key],x=labelWidth,y=index+1,width=width-labelWidth,height=1}
        end
        local row=#fields+3
        dialog[#dialog+1]={class="checkbox",name="add_ep",label=text.episode,value=addEpisode,x=0,y=row,width=width,height=1}
        dialog[#dialog+1]={class="checkbox",name="clean_all",label=text.clean,value=clean,x=0,y=row+1,width=width,height=1}
        dialog[#dialog+1]={class="label",label=text.hint,x=0,y=row+3,width=width,height=2}
        local button,result=aegisub.dialog.display(dialog,{text.save,text.cancel},{ok=text.save,close=text.cancel})
        if button~=text.save then return selection end
        addEpisode,clean=result.add_ep==true,result.clean_all==true
        for index,key in ipairs(fields) do values[key]=tostring(result["property"..index] or values[key]) end
        local message
        if result.values then
            local rows={}
            for value in (result.values:gsub("\r\n","\n"):gsub("\r","\n").."\n"):gmatch("(.-)\n") do rows[#rows+1]=value end
            for index,key in ipairs(fields) do values[key]=rows[index] or "" end
            for index=#fields+1,#rows do if trim(rows[index])~="" then message=text.fields[#fields]..": "..rows[index] end end
        end
        if addEpisode and not message then
            local ok,name=pcall(aegisub.file_name or function() end)
            local stem=ok and tostring(name or ""):match("([^/\\]+)$")
            stem=stem and stem:gsub("%.[^.]+$","")
            local episode
            if stem then
                local plain=trim(stem:gsub("%b[]",""):gsub("%b()", ""))
                episode=plain:match("[sS]%d+[eE](%d+)") or plain:match("%s%-%s*(%d+)")
                    or plain:gsub("[vV]%d+$", ""):match("(%d+)%s*$")
            end
            if not episode then message=text.missing
            elseif trim(values.Title)=="" then message=text.empty
            else
                episode=episode:gsub("^0+", "")
                if #episode<2 then episode=string.rep("0",2-#episode)..episode end
                values.Title=trim(values.Title:gsub("%s+%-%s+%d+$","")).." - "..episode
            end
        end
        if message then require("kite.UI").message(message,{button=text.save})
        else
            local selected,changes=apply(subs,selection,values,clean)
            if changes>0 and aegisub.set_undo_point then aegisub.set_undo_point(text.title) end
            return selected
        end
    end
end
return {run=run,read=read,apply=apply,fields=fields}
end)()

if depctrl then
    EventOps.version = depctrl
    return depctrl:register(EventOps)
end
return EventOps
