local moduleVersion = "1.2.2"
local Color = {VERSION=moduleVersion, version=moduleVersion}
local Core = require("kite.Core")
local finiteNumber, trim = Core.finiteNumber, Core.trim
local colorWhite = "&HFFFFFF&"
local assColorModulo, assAlphaModulo = 0x1000000, 4294967296
local assSignedColorMin, assUnsignedColorMax = -2147483648, 4294967295
local rgbChannelMax = 255
local okDep, DependencyControl = pcall(require, "l0.DependencyControl")
local depctrl
if okDep then
    depctrl = DependencyControl{
        name="kite.Color", moduleName="kite.Color", version=moduleVersion,
        description="ASS and RGB color conversion and contrast primitives", author="Kiterow",
        url="https://github.com/Kiterowx/Kite-Aegisub-Scripts",
        feed="https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
        {{"kite.Core", version="1.1.0"},{"kite.LineOps",version="1.7.4"},{"kite.UI",version="1.5.0"}},
    }
end

local function colorNumber(c)
    if c == nil or c == "" then return nil end
    if type(c) == "number" then
        if not finiteNumber(c) then return nil end
        if c ~= math.floor(c) then return nil end
        if c < assSignedColorMin or c > assUnsignedColorMax then return nil end
        if c < 0 then c = c + assAlphaModulo end
        return c % assColorModulo
    end
    c = trim(c)
    local hex = c:match("^&[Hh](%x+)&?$")
    if hex and (#hex == 6 or #hex == 8) then
        if #hex == 8 then hex = hex:sub(-6) end
        return tonumber(hex, 16)
    end
    local r, g, b = c:match("^#?(%x%x)(%x%x)(%x%x)$")
    if not r then r, g, b = c:match("^#(%x%x)(%x%x)(%x%x)%x%x$") end
    if r then
        return tonumber(r, 16) + tonumber(g, 16) * 0x100 + tonumber(b, 16) * 0x10000
    end
    return nil
end

function Color.normalizeStrict(c)
    local number = colorNumber(c)
    return number and string.format("&H%06X&", number) or nil
end

function Color.normalize(c)
    local n = Color.normalizeStrict(c)
    if n then return n end
    return colorWhite
end

function Color.fromStyle(n)
    if type(n) == "string" then return Color.normalize(n) end
    if type(n) ~= "number" or not finiteNumber(n) then return colorWhite end
    n = math.floor(n)
    if n < assSignedColorMin or n > assUnsignedColorMax then return colorWhite end
    if n < 0 then n = n + assAlphaModulo end
    return string.format("&H%06X&", n % assColorModulo)
end

function Color.toNumber(c)
    return colorNumber(c) or 0xFFFFFF
end

function Color.toHex(c)
    local r, g, b = Color.toRGB(c)
    return string.format("#%02X%02X%02X", r, g, b)
end

function Color.srgb8ToLinear(v)
    v = (finiteNumber(v) or 0) / rgbChannelMax
    if v <= 0 then return 0 end
    if v >= 1 then return 1 end
    if v <= 0.04045 then return v / 12.92 end
    return ((v + 0.055) / 1.055) ^ 2.4
end

function Color.linearToSrgb8(v)
    v = finiteNumber(v) or 0
    if v <= 0 then return 0 end
    if v >= 1 then return rgbChannelMax end
    local s
    if v <= 0.0031308 then s = v * 12.92
    else s = 1.055 * (v ^ (1.0 / 2.4)) - 0.055 end
    s = math.floor(s * rgbChannelMax + 0.5)
    if s < 0 then return 0 end
    if s > rgbChannelMax then return rgbChannelMax end
    return s
end

local function cubeRoot(x)
    if x >= 0 then return x ^ (1.0 / 3.0) end
    return -((-x) ^ (1.0 / 3.0))
end

function Color.rgbToOklab(r, g, b)
    local lr = Color.srgb8ToLinear(r)
    local lg = Color.srgb8ToLinear(g)
    local lb = Color.srgb8ToLinear(b)
    local lp = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
    local mp = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
    local sp = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb
    local lc, mc, sc = cubeRoot(lp), cubeRoot(mp), cubeRoot(sp)
    local L = 0.2104542553 * lc + 0.7936177850 * mc - 0.0040720468 * sc
    local A = 1.9779984951 * lc - 2.4285922050 * mc + 0.4505937099 * sc
    local B = 0.0259040371 * lc + 0.7827717662 * mc - 0.8086757660 * sc
    return L, A, B
end

function Color.luminance(c)
    local r, g, b = Color.toRGB(c)
    return 0.2126 * Color.srgb8ToLinear(r) + 0.7152 * Color.srgb8ToLinear(g) + 0.0722 * Color.srgb8ToLinear(b)
end

function Color.contrastRatio(c1, c2)
    local l1 = Color.luminance(c1) + 0.05
    local l2 = Color.luminance(c2) + 0.05
    return (l1 > l2) and l1 / l2 or l2 / l1
end

function Color.toRGB(c)
    local n = Color.toNumber(c)
    local b = math.floor(n / 0x10000) % (rgbChannelMax + 1)
    local g = math.floor(n / 0x100) % (rgbChannelMax + 1)
    local r = n % (rgbChannelMax + 1)
    return r, g, b
end

function Color.fromRGB(r, g, b)
    local function clamp(v)
        v = tonumber(v) or 0
        if v ~= v then v = 0 end
        v = math.floor(v + 0.5)
        if v < 0 then return 0 end
        if v > rgbChannelMax then return rgbChannelMax end
        return v
    end
    return string.format("&H%02X%02X%02X&", clamp(b), clamp(g), clamp(r))
end

function Color.interpolate(c1, c2, factor)
    factor = finiteNumber(factor) or 0
    if factor <= 0 then return Color.normalize(c1) end
    if factor >= 1 then return Color.normalize(c2) end
    local r1, g1, b1 = Color.toRGB(c1)
    local r2, g2, b2 = Color.toRGB(c2)
    return Color.fromRGB(
        r1 + (r2 - r1) * factor,
        g1 + (g2 - g1) * factor,
        b1 + (b2 - b1) * factor)
end

function Color.interpolateAss(first, second, factor)
    local r1, g1, b1 = Color.toRGB(first)
    local r2, g2, b2 = Color.toRGB(second)
    factor = Core.clamp(finiteNumber(factor) or 0, 0, 1)
    return Color.fromRGB(math.floor(r1 + (r2-r1)*factor),
        math.floor(g1 + (g2-g1)*factor), math.floor(b1 + (b2-b1)*factor))
end

function Color.parseAss(value)
    if type(value) ~= "string" then return Color.normalizeStrict(value) end
    local hex = trim(value):match("^&[Hh](%x+)&?$")
    if not hex or #hex > 8 then return nil end
    return string.format("&H%06X&", tonumber(hex, 16) % assColorModulo)
end

function Color.parseTag(value)
    if type(value)~="string" then return nil end
    local hex=trim(value):match("^&[Hh](%x+)&?$")
    if not hex then return nil end
    local number=tonumber(hex,16)
    if not number then return nil end
    return string.format("&H%06X&",math.min(number,0x7FFFFFFF)%assColorModulo)
end

Color.segments = (function()
local channels={
    {key="fill",label="Relleno",tag="\\c",styleField="color1",fallback="&HFFFFFF&"},
    {key="secondary",label="Secundario",tag="\\2c",styleField="color2",fallback="&H0000FF&"},
    {key="border",label="Borde",tag="\\3c",styleField="color3",fallback="&H000000&"},
    {key="shadow",label="Sombra",tag="\\4c",styleField="color4",fallback="&H000000&"},
}
local rowsPerPage=8
local function normalizeColor(value)
    return Color.parseAss(value) or Color.normalizeStrict(value)
end
local function slot(name)
    if name=="c" or name=="1c" then return 1 end
    return tonumber(name:match("^([234])c$"))
end
local function collectVisibleGlyphs(text)
    local LineOps = require("kite.LineOps")
    local glyphs={}
    for _,section in ipairs(LineOps.scanSections(text)) do
        if section.type=="drawing" then return nil,"El editor de tramos requiere texto, no dibujos vectoriales." end
        if section.type=="text" then
            local position=section.start
            for _,value in ipairs(LineOps.graphemes(section.text)) do
                glyphs[#glyphs+1]={raw=value,display=value,raw_pos=position}
                position=position+#value
            end
        end
    end
    return glyphs
end
local function anchor(glyphs,position)
    local first,last=1,#glyphs+1
    while first<last do
        local middle=math.floor((first+last)/2)
        if glyphs[middle] and glyphs[middle].raw_pos<=position then first=middle+1 else last=middle end
    end
    return first
end
local function glyphText(glyphs,first,last)
    local values={}
    for index=first,last do values[#values+1]=glyphs[index].raw end
    return table.concat(values)
end
local function analyze(text,styleColors,styles,baseStyle)
    local LineOps = require("kite.LineOps")
    text=tostring(text or "")
    local glyphs,message=collectVisibleGlyphs(text)
    if not glyphs then return nil,message end
    if #glyphs==0 then return nil,"La línea no contiene texto para dividir en tramos." end
    local result={text=text,glyphs=glyphs,compact=glyphText(glyphs,1,#glyphs),channels={},animated={},resets={}}
    for _,channel in ipairs(channels) do
        local value=type(styleColors)=="table" and (styleColors[channel.key] or styleColors[channel.styleField]) or channel.key=="fill" and styleColors
        local color=normalizeColor(value) or channel.fallback
        result.channels[channel.key]={occurrences={{tag=channel.tag,color=color,anchor=1}},rows={}}
    end
    local function add(channel,color,position)
        local entries=result.channels[channel.key].occurrences
        local index=anchor(glyphs,position)
        if entries[#entries].anchor==index then entries[#entries].color=color
        else entries[#entries+1]={tag=channel.tag,color=color,anchor=index} end
    end
    local currentStyle=baseStyle or styleColors
    for _,call in ipairs(LineOps.tagCalls(text)) do
        local channelIndex=slot(call.name)
        if channelIndex then
            local channel=channels[channelIndex]
            if not call.top_level then result.animated[channel.key]=true
            else
                local color=Color.parseTag(call.value)
                if not color and Core.trim(call.value)=="" and type(currentStyle)=="table" then
                    color=normalizeColor(currentStyle[channel.styleField] or currentStyle[channel.key]) or channel.fallback
                end
                if color then add(channel,color,call.finish) end
            end
        elseif call.name=="r" and call.top_level then
            local resetName=Core.trim(call.value)
            local style=resetName=="" and (baseStyle or styleColors) or styles and styles[resetName]
            if type(style)~="table" then return nil,"No se pudo resolver el estilo del reset: "..resetName end
            currentStyle=style
            result.resets[anchor(glyphs,call.finish)]=true
            for _,channel in ipairs(channels) do add(channel,normalizeColor(style[channel.styleField] or style[channel.key]) or channel.fallback,call.finish) end
        end
    end
    for _,channel in ipairs(channels) do
        local data=result.channels[channel.key]
        for index,entry in ipairs(data.occurrences) do
            local finish=data.occurrences[index+1] and data.occurrences[index+1].anchor-1 or #glyphs
            data.rows[index]=glyphText(glyphs,entry.anchor,finish)
        end
    end
    return result
end
local function initialStates(analysis)
    local states={}
    for _,channel in ipairs(channels) do
        local source=analysis.channels[channel.key]
        local state={occurrences=Core.deepCopy(source.occurrences),rows=Core.copy(source.rows),colors={},units=analysis.glyphs,emit=false}
        for index,entry in ipairs(state.occurrences) do state.colors[index]=Color.toHex(entry.color) end
        states[channel.key]=state
    end
    return states
end
local function lengths(state)
    local values,cursor={},1
    for index,row in ipairs(state.rows) do
        local bytes,count=0,0
        while bytes<#row and state.units[cursor] do
            bytes=bytes+#state.units[cursor].raw
            cursor,count=cursor+1,count+1
        end
        values[index]=count
    end
    return values
end
local function rebuild(analysis,states)
    local LineOps = require("kite.LineOps")
    local changed,paint={},{}
    for channelIndex,channel in ipairs(channels) do
        local state=states[channel.key]
        if state and state.emit then
            if analysis.animated[channel.key] then return nil,channel.label..": este canal está animado. Puedes editar los otros canales conservando su animación." end
            if #state.rows~=#state.colors or table.concat(state.rows)~=analysis.compact then return nil,"Los tramos deben cubrir el texto completo, sin cambiarlo." end
            changed[channelIndex]=true
            local cursor=1
            for index,count in ipairs(lengths(state)) do
                local color=normalizeColor(state.colors[index])
                if not color then return nil,"Color inválido en el tramo "..index end
                for position=cursor,cursor+count-1 do
                    paint[position]=paint[position] or {}
                    paint[position][channelIndex]=color
                end
                cursor=cursor+count
            end
        end
    end
    if not next(changed) then return analysis.text end
    local replacements={}
    for _,call in ipairs(LineOps.tagCalls(analysis.text)) do
        if call.top_level and changed[slot(call.name)] then replacements[#replacements+1]={first=call.start,last=call.finish,text=""} end
    end
    local previous={}
    for position,glyph in ipairs(analysis.glyphs) do
        local tags={}
        for index,channel in ipairs(channels) do
            local color=paint[position] and paint[position][index]
            if color and (previous[index]~=color or analysis.resets[position]) then tags[#tags+1]=channel.tag..color;previous[index]=color end
        end
        if #tags>0 then replacements[#replacements+1]={first=glyph.raw_pos,last=glyph.raw_pos-1,text="{"..table.concat(tags).."}"} end
    end
    table.sort(replacements,function(a,b) return a.first<b.first end)
    local chunks,cursor={},1
    for _,change in ipairs(replacements) do
        chunks[#chunks+1]=analysis.text:sub(cursor,change.first-1)
        chunks[#chunks+1]=change.text
        cursor=change.last+1
    end
    chunks[#chunks+1]=analysis.text:sub(cursor)
    return (table.concat(chunks):gsub("{%s*}",""))
end
local function splitRow(state,channel,index)
    index=index or #state.rows
    local sizes=lengths(state)
    local start=1
    for row=1,index-1 do start=start+sizes[row] end
    local units={}
    for position=start,start+sizes[index]-1 do units[#units+1]=state.units[position].raw end
    local split=math.floor(#units/2)
    state.rows[index]=table.concat(units,"",1,split)
    table.insert(state.rows,index+1,table.concat(units,"",split+1,#units))
    table.insert(state.colors,index+1,state.colors[index] or Color.toHex(channel.fallback))
    table.insert(state.occurrences,index+1,{tag=channel.tag})
    state.emit=true
end
local function mergeRow(state,index)
    if #state.rows<=1 then return end
    index=math.min(index or #state.rows,#state.rows-1)
    state.rows[index]=state.rows[index]..state.rows[index+1]
    table.remove(state.rows,index+1);table.remove(state.colors,index+1);table.remove(state.occurrences,index+1)
    state.emit=true
end
local function canRun(subs,selection)
    return type(selection)=="table" and #selection==1 and subs[selection[1]]~=nil and subs[selection[1]].class=="dialogue"
end
local function run(subs,selection)
    local LineOps = require("kite.LineOps")
    local UI=require("kite.UI")
    if not canRun(subs,selection) then UI.message("Selecciona una línea de diálogo.",{button="Aceptar"});return selection end
    local index=selection[1]
    local line=subs[index]
    local styles={}
    for position=1,#subs do local item=subs[position];if item.class=="style" then styles[item.name]=item end end
    local style=styles[line.style] or styles.Default or {}
    local analysis,message=analyze(line.text,style,styles,style)
    if not analysis then UI.message(message,{button="Aceptar"});return selection end
    local states=initialStates(analysis)
    local active,page,selectedRow=1,1,1
    local draft
    local channelLabels={}
    for _,channel in ipairs(channels) do channelLabels[#channelLabels+1]=channel.label end
    while true do
        local channel=channels[active]
        local state=states[channel.key]
        local sizes=lengths(state)
        local pages=math.max(1,math.ceil(#state.rows/rowsPerPage))
        page=math.max(1,math.min(pages,page))
        local first,last=(page-1)*rowsPerPage+1,math.min(page*rowsPerPage,#state.rows)
        local dialog={
            {class="label",label="Zheus · Editor de tramos",x=0,y=0,width=48,height=1},
            {class="textbox",name="original",text=analysis.compact,x=0,y=1,width=48,height=3},
            {class="label",label="Canal",x=0,y=4,width=6,height=1},
            {class="dropdown",name="channel",items=channelLabels,value=channel.label,x=6,y=4,width=14,height=1},
            {class="label",label="Página "..page.." / "..pages.." · "..#state.rows.." tramos",x=22,y=4,width=26,height=1},
            {class="label",label="Tramo",x=0,y=6,width=4,height=1},
            {class="label",label="Color",x=4,y=6,width=6,height=1},
            {class="label",label="Termina en",x=10,y=6,width=8,height=1},
            {class="label",label="Texto",x=18,y=6,width=30,height=1},
        }
        local ending=0
        for row,count in ipairs(sizes) do
            ending=ending+count
            if row>=first and row<=last then
                local y=7+row-first
                dialog[#dialog+1]={class="label",label=tostring(row),x=0,y=y,width=4,height=1}
                dialog[#dialog+1]={class="color",name="color"..row,value=state.colors[row],x=4,y=y,width=6,height=1}
                dialog[#dialog+1]={class="intedit",name="end"..row,value=ending,min=0,max=#analysis.glyphs,x=10,y=y,width=8,height=1}
                dialog[#dialog+1]={class="label",label=state.rows[row],x=18,y=y,width=30,height=1}
            end
        end
        local bottom=8+rowsPerPage
        dialog[#dialog+1]={class="label",label="Tramo para dividir o unir",x=0,y=bottom,width=18,height=1}
        dialog[#dialog+1]={class="intedit",name="row",value=math.min(selectedRow,#state.rows),min=1,max=#state.rows,x=18,y=bottom,width=6,height=1}
        dialog[#dialog+1]={class="label",label=analysis.animated[channel.key] and "Este canal está animado; cambia de canal para conservar esa animación." or "Ajusta el final de cada tramo. Espacios y saltos cuentan como unidades; el texto original se conserva.",x=0,y=bottom+2,width=48,height=2}
        if draft then
            for _,item in ipairs(dialog) do
                if item.name and draft[item.name]~=nil and (item.class=="intedit" or item.class=="color" or item.class=="dropdown") then item.value=draft[item.name] end
            end
        end
        local button,result=aegisub.dialog.display(dialog,{"Aplicar","Actualizar","Dividir","Unir","Anterior","Siguiente","Restablecer canal","Cancelar"},{ok="Aplicar",close="Cancelar"})
        if not button or button=="Cancelar" then return selection end
        if button=="Restablecer canal" then
            states[channel.key]=initialStates(analysis)[channel.key]
            draft,page,selectedRow=nil,1,1
        else
            local ends,total={},0
            for row,count in ipairs(sizes) do total=total+count;ends[row]=result["end"..row] or total end
            local valid=ends[#ends]==#analysis.glyphs
            for row,value in ipairs(ends) do if value<(ends[row-1] or 0) then valid=false end end
            if not valid then draft=result;UI.message("Los finales deben estar ordenados y el último debe cubrir todo el texto.",{button="Aceptar"})
            else
                draft=nil
                local cursor=1
                for row,finish in ipairs(ends) do
                    local value=glyphText(analysis.glyphs,cursor,finish)
                    local color=result["color"..row] or state.colors[row]
                    if value~=state.rows[row] or color~=state.colors[row] then state.emit=true end
                    state.rows[row],state.colors[row],cursor=value,color,finish+1
                end
                selectedRow=result.row or selectedRow
                if button=="Dividir" then splitRow(state,channel,selectedRow)
                elseif button=="Unir" then mergeRow(state,selectedRow)
                elseif button=="Anterior" then page=math.max(1,page-1);selectedRow=(page-1)*rowsPerPage+1
                elseif button=="Siguiente" then page=math.min(pages,page+1);selectedRow=(page-1)*rowsPerPage+1
                elseif button=="Aplicar" then
                    local updated,errorMessage=rebuild(analysis,states)
                    if not updated then UI.message(errorMessage,{button="Aceptar"})
                    else
                        if updated~=line.text then
                            local replacement=Core.copy(line);replacement.text=updated
                            LineOps.transaction(subs,"Zheus · Editor de tramos",function() subs[index]=replacement end)
                        end
                        return selection
                    end
                end
                for number,label in ipairs(channelLabels) do if result.channel==label and active~=number then active,page,selectedRow=number,1,1 end end
            end
        end
    end
end
return {analyze=analyze,rebuild=rebuild,initialStates=initialStates,collectVisibleGlyphs=collectVisibleGlyphs,normalizeColor=normalizeColor,assToHtml=Color.toHex,channels=channels,splitRow=splitRow,mergeRow=mergeRow,run=run,canRun=canRun,rowsPerPage=rowsPerPage}
end)()

if depctrl then Color.version=depctrl; return depctrl:register(Color) end
return Color
