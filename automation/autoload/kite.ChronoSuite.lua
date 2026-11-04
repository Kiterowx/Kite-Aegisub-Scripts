local function initializeScript()
script_name        = "Chrono Suite"
script_description = "Suite for subtitle timing, QC, cleanup, and workflow toolkit"
script_author      = "Kiterow"
script_version     = "1.8.0"
script_namespace   = "kite.ChronoSuite"

include("karaskel.lua")

local utf8CharPattern          = "[%z\1-\127\194-\244][\128-\191]*"
local NBSP                       = string.char(0xC2, 0xA0)
local invQuestion               = string.char(0xC2, 0xBF)
local invExclamation            = string.char(0xC2, 0xA1)
local cjkPeriod                 = string.char(0xE3, 0x80, 0x82)
local cjkComma                  = string.char(0xE3, 0x80, 0x81)
local fullwidthQuestion         = string.char(0xEF, 0xBC, 0x9F)
local fullwidthExclamation      = string.char(0xEF, 0xBC, 0x81)
local fullwidthComma            = string.char(0xEF, 0xBC, 0x8C)
local fullwidthSemicolon        = string.char(0xEF, 0xBC, 0x9B)
local fullwidthPeriod           = string.char(0xEF, 0xBC, 0x8E)
local fullwidthColon            = string.char(0xEF, 0xBC, 0x9A)
local horizontalEllipsis        = string.char(0xE2, 0x80, 0xA6)
local twoDotLeader             = string.char(0xE2, 0x80, 0xA5)
local leftDoubleQuote          = string.char(0xE2, 0x80, 0x9C)
local rightDoubleQuote         = string.char(0xE2, 0x80, 0x9D)
local doubleLowQuote           = string.char(0xE2, 0x80, 0x9E)
local doubleHighReversedQuote = string.char(0xE2, 0x80, 0x9F)
local leftSingleQuote          = string.char(0xE2, 0x80, 0x98)
local rightSingleQuote         = string.char(0xE2, 0x80, 0x99)
local singleLowQuote           = string.char(0xE2, 0x80, 0x9A)
local singleHighReversedQuote = string.char(0xE2, 0x80, 0x9B)
local leftGuillemet             = string.char(0xC2, 0xAB)
local rightGuillemet            = string.char(0xC2, 0xBB)
local leftSingleGuillemet      = string.char(0xE2, 0x80, 0xB9)
local rightSingleGuillemet     = string.char(0xE2, 0x80, 0xBA)
local enDash                    = string.char(0xE2, 0x80, 0x93)
local emDash                    = string.char(0xE2, 0x80, 0x94)
local horizontalBar             = string.char(0xE2, 0x80, 0x95)
local minusSign                 = string.char(0xE2, 0x88, 0x92)

local sentenceSplitChars = {
    ["."] = true, ["?"] = true, ["!"] = true,
    [cjkPeriod] = true, [fullwidthQuestion] = true, [fullwidthExclamation] = true,
    [fullwidthPeriod] = true, [horizontalEllipsis] = true, [twoDotLeader] = true,
}
local commaSplitChars = {
    [","] = true, [":"] = true, [";"] = true,
    [cjkComma] = true, [fullwidthComma] = true, [fullwidthColon] = true, [fullwidthSemicolon] = true,
}
local utf8PunctuationChars = {
    [invQuestion] = true, [invExclamation] = true,
    [cjkPeriod] = true, [cjkComma] = true,
    [fullwidthQuestion] = true, [fullwidthExclamation] = true,
    [fullwidthComma] = true, [fullwidthSemicolon] = true,
    [fullwidthPeriod] = true, [fullwidthColon] = true,
    [horizontalEllipsis] = true, [twoDotLeader] = true,
    [leftDoubleQuote] = true, [rightDoubleQuote] = true,
    [leftSingleQuote] = true, [rightSingleQuote] = true,
    [leftGuillemet] = true, [rightGuillemet] = true,
    [string.char(0xE3,0x80,0x8C)] = true, [string.char(0xE3,0x80,0x8D)] = true,
    [string.char(0xE3,0x80,0x8E)] = true, [string.char(0xE3,0x80,0x8F)] = true,
    [string.char(0xE3,0x80,0x90)] = true, [string.char(0xE3,0x80,0x91)] = true,
    [string.char(0xEF,0xBC,0x88)] = true, [string.char(0xEF,0xBC,0x89)] = true,
    [string.char(0xEF,0xBC,0xBB)] = true, [string.char(0xEF,0xBC,0xBD)] = true,
}
local terminalPunctuation = {
    ["."] = true, ["?"] = true, ["!"] = true, [","] = true,
    [cjkPeriod] = true, [cjkComma] = true,
    [fullwidthPeriod] = true, [fullwidthQuestion] = true, [fullwidthExclamation] = true, [fullwidthComma] = true,
    [horizontalEllipsis] = true,
}
local closingPunctuation  = {
    [")"] = true, ["]"] = true, ["}"] = true, ["\""] = true, ["'"] = true,
    [rightDoubleQuote] = true, [rightSingleQuote] = true, [rightGuillemet] = true,
}

local latinUpperToLower = {
    [string.char(0xC3,0x81)] = string.char(0xC3,0xA1), [string.char(0xC3,0x89)] = string.char(0xC3,0xA9),
    [string.char(0xC3,0x8D)] = string.char(0xC3,0xAD), [string.char(0xC3,0x93)] = string.char(0xC3,0xB3),
    [string.char(0xC3,0x9A)] = string.char(0xC3,0xBA), [string.char(0xC3,0x9C)] = string.char(0xC3,0xBC),
    [string.char(0xC3,0x91)] = string.char(0xC3,0xB1),
}
for upper, lower in pairs({["À"]="à",["È"]="è",["Ì"]="ì",["Ò"]="ò",["Ù"]="ù",["Â"]="â",["Ê"]="ê",["Î"]="î",["Ô"]="ô",["Û"]="û",["Ä"]="ä",["Ë"]="ë",["Ï"]="ï",["Ö"]="ö",["Ç"]="ç"}) do latinUpperToLower[upper] = lower end
local latinLowerToUpper = {}
for u, l in pairs(latinUpperToLower) do latinLowerToUpper[l] = u end

local function safeRequire(mod) local ok,m = pcall(require, mod); if ok then return m end end

local DependencyControl = safeRequire("l0.DependencyControl")
local depRec, KiteUI, Timing
local Kite = {}

if DependencyControl then
    local ok, rec = pcall(DependencyControl, {
        feed        = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json",
        {
            { "kite.UI", version = "2.0.3",
              url  = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
              feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
            { "kite.Timing", version = "1.5.0",
              url  = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
              feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
            { "kite.PyBridge", version = "2.0.1",
              url  = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
              feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
            { "kite.PyBridge", version = "2.0.1",
              url  = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
              feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
            { "kite.Core", version = "2.0.0",
              url  = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
              feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
            { "kite.Core", version = "2.0.0",
              url  = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
              feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
            { "kite.EventOps", version = "1.4.0",
              url  = "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
              feed = "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json" },
        },
    })
    if not ok then error(rec, 0) end
    if rec then
        depRec = rec
        depRec:requireModules()
        local okMods, mKiteUI, mTiming, mPyBridge, mMedia, mCore, mLineOps, mEventOps = pcall(function() return depRec:requireModules() end)
        if not okMods then error(mKiteUI, 0) end
        if okMods then
            KiteUI, Timing = mKiteUI, mTiming
            Kite.PyBridge, Kite.Media, Kite.Core, Kite.LineOps, Kite.EventOps = mPyBridge, mMedia.Media, mCore, mLineOps.LineOps, mEventOps
        end
    end
end
KiteUI     = KiteUI     or safeRequire("kite.UI")
Timing     = Timing     or safeRequire("kite.Timing")
Kite.PyBridge = Kite.PyBridge or safeRequire("kite.PyBridge")
Kite.Media = Kite.Media or (safeRequire("kite.PyBridge") or {}).Media
Kite.Core = Kite.Core or safeRequire("kite.Core")
Kite.LineOps = Kite.LineOps or (safeRequire("kite.Core") or {}).LineOps
Kite.EventOps = Kite.EventOps or safeRequire("kite.EventOps")

local unicode = safeRequire("aegisub.unicode") or {}
if type(unicode.to_upper) ~= "function" then unicode.to_upper = string.upper end
if type(unicode.to_lower) ~= "function" then unicode.to_lower = string.lower end
if type(unicode.len)      ~= "function" then
    unicode.len = function(t)
        local n = 0; for _ in tostring(t or ""):gmatch(utf8CharPattern) do n = n + 1 end; return n
    end
end

local defaultConfig = {
    language          = "en",
    lead_step_ms      = 100,
    chain_max_ms      = 2000,

    kt_lead_in_base   = 150,
    kt_lead_in_max    = 300,
    kt_lead_out_base  = 350,
    kt_lead_out_max   = 600,
    kt_lead_out_chain = 500,
    kt_chain_gap_max  = 800,
    bidir_snap_f      = 2,
    edge_snap_protect_ms = 250,

    preset_start_twin_ms = 300,
    preset_start_miss_ms = 300,
    preset_end_twin_ms = 1000,
    preset_end_miss_ms = 1000,
    preset_full_twin_ms = 1000,
    preset_full_miss_ms = 1000,
    preset_full_short_ms = 500,
    preset_full_long_ms = 7000,
    preset_full_max_cps = 20,
    preset_full_short_gap_ms = 300,
    preset_full_large_gap_ms = 800,
    preset_full_max_width = 1200,
    preset_duration_short_ms = 500,
    preset_duration_long_ms = 7000,
    preset_cps_max = 20,
    preset_gap_short_ms = 300,
    preset_gap_large_ms = 800,
    preset_overtime_ms = 5500,
}

local currentConfig = {}
local currentLang = "en"
local chronoSettings = KiteUI and KiteUI.settings(script_namespace, script_version, { main = defaultConfig }, {
    { path = "?user/chrono_suite_config.lua", format = "lua_table", target = "main" },
}) or nil

local function loadConfig()
    currentConfig = {}
    local loaded = chronoSettings and chronoSettings:values("main") or defaultConfig
    for k, v in pairs(defaultConfig) do currentConfig[k] = loaded[k] == nil and v or loaded[k] end
    currentLang = currentConfig.language or "en"
    return chronoSettings ~= nil
end

local function saveConfig()
    if not chronoSettings then return false end
    chronoSettings:update("main", currentConfig)
    return chronoSettings:write()
end

loadConfig()

local L, UI = require("kite.Timing").Locale.new(function() return currentLang end)
UI.labels.en["Import Lines"] = "Import lines"
UI.labels.es["Import Lines"] = "Importar líneas"
UI.labels.pt["Import Lines"] = "Importar linhas"

local function resolveConfig()
    currentLang = currentConfig.language or currentLang or "en"
end

local function showMsg(msg)
    msg = tostring(msg)
    local lines, maxLen = 0, 0
    for line in (msg .. "\n"):gmatch("(.-)\n") do
        lines = lines + 1
        if #line > maxLen then maxLen = #line end
    end
    if lines > 4 or maxLen > 70 or #msg > 180 then
        local width = math.max(45, math.min(90, math.floor(maxLen / 2) + 8))
        local height = math.max(8, math.min(26, lines + 4))
        aegisub.dialog.display({{class="textbox", text=msg, x=0, y=0, width=width, height=height}}, {L("btn_ok")})
    else
        local width = math.max(30, math.min(70, maxLen + 4))
        local height = math.max(3, math.min(8, lines + 2))
        aegisub.dialog.display({{class="label", label=msg, x=0, y=0, width=width, height=height}}, {L("btn_ok")})
    end
end
local suiteHelp = {
    en = [[
CHRONO SUITE · USER GUIDE
__________________________

A suite of timing, audit, cleanup, import, and editing utilities for
Aegisub. The interface consists of a main panel and auxiliary dialogs
(Cleanup, Joinator, Final Data, Config, and Help). The main
panel operates on the current selection and is split into two columns:
Audit Markers (left) and Utility Tools (right), with Data Import and
Extra Tools at the bottom. Most audit results are written to the Effect
field.


1. MAIN PANEL
_____________

The panel is organized around the current selection. Actions are
triggered by pressing EXECUTE. Cleanup, Joinator and Final Data
open directly and respect Apply to / Filter. Auto Timing and Extract KF
are available in Hephaestus Fansubber / Automatons.

   1.1. Apply to: defines the subset on which the panel sections act.
   1.2. Filter: text or numeric value paired with Apply to.
   1.3. Audit Markers: presets, thresholds, keyframe mode, and Single
        Marker.
   1.4. Utility Tools: seven independent sections (Case, Punct/Text,
        Tags/Comments, Smart, Split/Join, Time/Sort, and Karaoke).
   1.5. Data Import: import data from text pasted into the box.
   1.6. Tools: Text Replacer and mpv QC. The other editors have direct buttons.

An empty dropdown skips its section during execution.


2. APPLY TO / FILTER
____________________

   2.1. All Selected: uses the selection as it is.
   2.2. By Style: keeps lines whose style matches Filter.
   2.3. By Actor: keeps lines whose actor matches Filter.
   2.4. By Effect: keeps lines whose Effect contains the filter text
        (partial match).
   2.5. By Layer: keeps lines whose Layer equals the number written in
        Filter.


3. AUDIT PRESETS
________________

Each preset applies the thresholds defined in Config → Audit Presets
and writes its markers to the Effect field.

   3.1. Ends Only: checks line end times against nearby keyframes.
        Writes only Miss KF and Twin KF markers.
   3.2. Start Only: equivalent check applied to line start times.
   3.3. Full Audit: general check covering text, layout, timing, CPS,
        gaps, and structure.
   3.4. Duration: checks each line against the Short and Long
        thresholds.
   3.5. CPS: checks reading speed against the configured maximum.
   3.6. Short Gaps: checks line-to-line gaps against the Short gap
        threshold.
   3.7. Large Gaps: checks line-to-line gaps against the Large gap
        threshold.
   3.8. Both Gaps: runs both gap checks. Markers are written on both
        adjacent lines and include the detected millisecond value.
   3.9. Overtime: marks lines that exceed the configured maximum
        duration.


4. AUDIT NUMERIC FIELDS
_______________________

   4.1. Short (ms) / Long (ms): minimum and maximum duration
        thresholds.
   4.2. Twin KF (ms): distance for identifying two lines touching the
        same keyframe.
   4.3. Miss KF (ms): distance for identifying a missed keyframe.
   4.4. Overtime (ms): threshold exclusive to the Overtime preset.
   4.5. Min CPS / Max CPS: reading speed range.
   4.6. Short gap (ms) / Large gap (ms): line-to-line gap thresholds.
   4.7. Max Width (px): visual line width used as a review criterion.


5. KEYFRAME MODE AND DIRECTION
______________________________

   5.1. KF Mode: selects which edge is checked against keyframes:
        Start Only, End Only, or Both.
   5.2. KF Dir: search direction for Near/Missed keyframes: Back,
        Forward, or Both. An empty value defaults to Back.
   5.3. Keyframe Seal: independent option that writes START-ON-KF or
        END-ON-KF when an edge lands on a keyframe.
   5.4. Mark continuous (0 ms): includes zero-millisecond gaps in the
        check.
   5.5. Ignore gap on KF: skips gaps whose edge lands on a keyframe.
   5.6. Clear previous markers: removes existing markers before
        writing new ones.


6. SINGLE MARKER
________________

Overrides the chosen preset and runs a single check. The matching tag
is written to the Effect field.

   6.1. Numbering and identification
        - Number Effects: sequential numbering (1, 2, 3...).
        - Add Identifier: 14-digit unique identifier per line.

   6.2. Text and punctuation
        - UPPERCASE: entire line in uppercase.
        - THREE-LINES: line displayed across three rows.
        - NO-END-PUNCT: line without ending punctuation.
        - FINAL-COMMA: line ending with a comma.
        - UNPAIRED-PUNCT: punctuation marks without a counterpart.
        - STRONG-EXCL: visible exclamation sign ("¡", "!" or fullwidth
          variant).
        - STRONG-QUEST: word containing both opening "¿" and closing
          "?".
        - MIXED-EMPHASIS: word combining two openings (¡¿) or two
          closings (?!).
        - SEMICOLON: line containing ";".
        - STUTTER: word containing the X-X pattern (same letter
          repeated with a hyphen).

   6.3. Layout and structure
        - SHORT-LAST-LINE: visually short last line.
        - BROKEN-TAG: empty or malformed override block.
        - OVERLAP: overlap with another line.
        - DEFAULT-STYLE: line using the Default style.
        - ITALIC-ERROR: inconsistency in italics usage.
        - PARENTHESES: parentheses without a counterpart.
        - NAME-PREFIX: detected speaker-name prefix.
        - MULTI-SENTENCE: more than one sentence in a single line.

   6.4. Override tag presence
        - LINE-BREAK, POSITION-TAG, CLIP-TAG, FADE-TAG, TRANSFORM-TAG,
          KARAOKE-TAG.
        - DRAWING-CLIP: vector drawing that also carries \clip or
          \iclip. Available as a Single Marker.

   6.5. Cleanup and content
        - COMMENT-BLOCK: comment block embedded in the text.
        - HAS-DIGITS: digits present.
        - HAS-CJK: CJK characters or kana.
        - FULL-ITALIC: entire line in italics.
        - DOUBLE-SPACE: double spaces in the text.
        - EDGE-SPACE: spaces at the start or end of the line.


7. UTILITY TOOLS
________________

Each section offers an independent dropdown. An empty value skips that
section during execution.

7.1. CASE
    - Toggle \an8: toggles the top alignment \an8.
    - Toggle Italics: toggles italics.
    - Uppercase: converts the entire text to uppercase.
    - Lowercase: converts the entire text to lowercase.
    - Title Case: capitalizes each word.
    - Sentence Case: capitalizes the first word of each sentence.
    - Capitalize First: capitalizes the first visible character.
    - Lowercase First: converts the first visible character to
      lowercase.

7.2. PUNCT / TEXT
    - Toggle ¡!: toggles the opening exclamation mark.
    - Toggle ¿?: toggles the opening question mark.
    - Toggle ¡¿?!: toggles both opening signs.
    - Normalize Ellipsis: standardizes ellipsis characters.
    - Add Ellipsis: appends an ellipsis at the end of the line.
    - Erase Leading Ellipsis: removes an ellipsis at the start of the
      line.
    - Erase Inner Ellipsis: removes ellipsis inside the sentence while
      preserving a final ellipsis.
    - Ellipsis to Comma: replaces final ellipsis with a comma.
    - Ellipsis to Period: replaces final ellipsis with a period.
    - Unify Quotes: standardizes quotation marks.
    - Latin Quotes («»): converts quotes to Latin guillemets.
    - Normalize Dashes: standardizes hyphens, en-dashes, and em-dashes.
    - Trim Trailing Spaces: removes trailing spaces.
    - Remove Duplicate Letters: removes consecutive duplicate letters.
    - Add Stutter: inserts stutter formatting in the text.
    - Add Ah Prefix: inserts an "ah" prefix at the start of the
      dialogue.
    - Normalize Stutter: normalizes repeated initials and applies stutter to [TT] lines.

7.3. TAGS / COMMENTS
    - Fold by Identifier: groups lines sharing the same identifier into
      folds. A fold is created only when the group contains two or more
      lines.
    - Extract Tags: moves override tags from the text into the Effect
      field.
    - Reinsert Tags: returns override tags from Effect to the text and
      converts semicolons to commas inside override blocks.
    - Remove Tags: deletes override blocks from the visible dialogue.
    - Merge Tags: merges adjacent override tag blocks, deleting the
      }{ between them ({\an5}{\blur2} becomes {\an5\blur2}). Comment
      blocks and non-adjacent blocks are left untouched.
    - Remove Inline Comments: deletes comment blocks within the text.
    - Extract Actors and Split: extracts actor information from the text.
    - Swap Text and Comments: exchanges visible text with inline comments; override tags remain in place.
    - Delete Comment Lines: deletes lines flagged as comments.
    - Comments to Top: reorders comments to the top of the selection.
    - Comments to Bottom: reorders comments to the bottom of the
      selection.
    - Effects to Top: moves lines with a non-empty Effect to the top of
      the selection while preserving their relative order.

7.4. SMART
    - Bidirectional Snapping: snaps both start and end to the nearest
      keyframe within the configured frame range.
    - Remove Honorifics: wraps Japanese honorifics in {…} comment
      blocks so they stay in the source but disappear from the visual
      render.
    - Caption Clarifier: standardizes caption brackets and indications.
    - Complete Sentences: joins an incomplete line with the next line
      when the next text starts lowercase. Overlaps or non-lowercase
      continuations are marked as [POSSIBLE-JOIN] instead.
    - Erase Blank Lines: deletes blank lines.
    - Current Frame to Effect: appends the current video-frame number to Effect.
    - Copy Fold: displays ASS event rows from the fold containing the
      first selected line for copying, then selects that fold.

7.5. SPLIT / JOIN
    - Split by Sentence: splits the line by sentence.
    - Split by Comma: splits the line by comma.
    - Pivot \N: shifts the \N break within the line.
    - Remove \N: removes every \N from the line, collapsing whitespace.
    - Join Same Text: joins adjacent lines with identical text.
    - Join Overlaps: joins selected groups whose times overlap,
      expands the kept line to the group bounds, and preserves each
      source text separated by \N.
    - Join Overlap Sentences: joins selected overlapping groups in grid
      order as one sentence, keeps the first grid line as base, and
      extends the end time to the group end.
    - Divide by \N: splits the line on every existing \N break.

7.6. TIME / SORT
    - Copy Times: copies timing from one line to others.
    - Select Time Range: selects lines within a time range.
    - Sort by Text Length: sorts the lines by visible length.
    - Sort by CPS: sorts the lines by reading speed.
    - Sort Odd Even: sorts by the numeric value of the Effect field
      (odd and even).
    - Count CPS: shows the average CPS across the selection.
    - Import Text: imports text from an external source for controlled
      replacement.
    - Kite Timing: applies the Kite Timing algorithm (adaptive lead-in
      and lead-out, chaining, and edge protection) using the values
      from Config.
    - Align to First Start: shifts rows after the first so the second starts
      at the first row start; preserves their relative spacing.
    - Start Snap Back: snaps the start to the previous keyframe.
    - Start Snap Forward: snaps the start to the next keyframe.
    - End Snap Back: snaps the end to the previous keyframe.
    - End Snap Forward: snaps the end to the next keyframe.
    - Add Lead-In Left: moves the start back by the configured step
      (Config → Lead-In / Lead-Out). A neighbour chained at gap 0
      moves its end along to keep the chain; with a positive gap the
      start only advances until it touches the neighbour, never
      overlapping it.
    - Add Lead-In Right: moves the start forward by the configured
      step. A neighbour chained at gap 0 moves its end along to keep
      the chain.
    - Add Lead-Out Left: moves the end back by the configured step.
      A chained next line moves its start along to keep the chain.
    - Add Lead-Out Right: moves the end forward by the configured
      step, pushing the start of a chained next line.
    - Chain Left: extends the start back to the previous line's end
      (creates gap 0), within the configured max distance.
    - Chain Right: extends the end to the next line's start (creates
      gap 0), within the configured max distance.

7.7. KARAOKE
    - Romaji Karaoker (Word → \k): generates word-level romaji karaoke
      with {\k} tags.


8. DATA IMPORT
______________

The import source is the text pasted into the Data Import box. An
empty box skips this section.

   8.1. Import Effects: copies the source Effect by time overlap.
   8.2. Import Text: copies visible text by time overlap.
   8.3. Import Actor: copies actor by best time overlap.
   8.4. Import Tags: merges initial tags from the source with greatest positive
        overlap. Ties keep pasted order. Only matching initial tags are replaced;
        clip/iclip are alternatives. Other formatting, text, drawings, comments
        and inline tags are retained. No tags or no overlap leaves the target unchanged.
   Import Lines: replaces each selected dialogue with the pasted ASS group, keeping
        the destination start and end. Import options do not alter this exact copy.
   8.5. Song Sync: duplicates or synchronizes groups using a Comment
        line on layer 50 as the sync anchor. The selected line's Effect
        is copied into each imported line's Effect; source Effects are
        retained.
   8.6. Same Layers: when checked, Import Effects, Import Text,
        Import Actor, and Import Tags only match source lines whose
        layer equals the target line layer.
   8.7. Import as comments: wraps the imported text inside {…} comment
        blocks.


9. EXTRA TOOLS
______________

   After Effects Keyframes is available in Rhea Signs / Tools.
   9.2. Text Replacer: replaces visible text while preserving override
        tags.
   9.3. mpv QC: reads notes exported from mpvQC in the format
        [hh:mm:ss.ms] [Type] Observation {suggested text}. The
        observation is written as [QC: …] in Effect and the suggestion
        is inserted as a comment block in the dialogue. Tolerance is
        defined in milliseconds.
   9.4. Text and Tag Cleanup: removes selected visible signs, spacing
        tokens, comments, and known override tags without toggling them
        back on when absent.
   9.5. Final Data: paste eight lines in the displayed field order. Empty lines
        keep empty fields in place. The
        optional cleanup affects the whole file, removing project paths,
        extradata, comments, Actor, Effect and empty dialogue lines.

10. AUTO TIMING
_______________

Auto Timing has two main methods, plus a separate Legacy path. Every
control lives in this window and persists in the Chrono Suite
configuration.

   10.1. Method:
         - Lazy: reads spoken activity from a peaks JSON. It is the
           simple method and needs no extra module.
         - Busy: combines silence, VAD, flux, RMS envelope, and optional
           waveform data. It needs the Kite Timing module from
           DependencyControl.
   10.2. Mode for Lazy and Busy:
         - Full + polish: detect the voice, then pad, chain, and snap to
           video keyframes.
         - Raw voice: move each line onto the detected voice start/end
           with no padding. It does not use keyframes.
         - Post current: keep the current in/out and only run the final
           padding, chaining, and video-keyframe pass.
   10.3. Waveform JSON: a peaks file (min/max samples). Type a path or
         pick one with Browse...; it is cached for the session, and
         Reload waveform cache forces a fresh read.
   10.4. Keyframes come from the loaded video, the same way the audit
         markers read them. Full + polish and Post current need them;
         Raw voice does not.
   10.5. Busy Files... opens only the file inputs used by Busy. If Busy
         is processed without a JSON or Busy files, this window opens
         first.
   10.6. Legacy... opens the Legacy method selector and silence files.
         Legacy aligns line edges to silence clusters, does not use video
         keyframes, and writes [LZ ...] tags.
   10.7. Style filter: All, All Default, Default+Alt, or an exact
         style, plus a second exact style in the extra box.
   10.8. Problem lines are marked in Effect with [TM-...] markers (no
         voice, weak match, overlap, short, fast CPS), cleaned on the
         next run.


11. AUTO TIMING: DETECTION & MARGINS
____________________________________

Lazy smooths the peak envelope, thresholds it, cleans the mask, and
keeps the speech span each line is then padded around. Busy reuses the
same final margins on its combined match.

   11.1. Search ± (ms): how far beyond the line's own in/out to look
         for the voice (0 = stay inside the line).
   11.2. Smoothing (ms): width of the envelope smoothing window.
   11.3. Auto threshold (Otsu): choose the speech/silence cut
         automatically; off falls back to a percentile sensitivity.
   11.4. Bridge gaps / Drop islands (ms): close micro-silences and
         discard micro-blips before the span is measured.
   11.5. Trim small edge spill: drop a faint, well-separated blip stuck
         to a line edge so it does not stretch the timing.
   11.6. Margins · post-timing: lead-in / lead-out, chain max out / in,
         KF snap end / start, voice-cut limit, duration floor, and the
         CPS flag — the default criteria that shape how the raw span
         becomes the final in/out.


12. EXTRACT KF
______________

Generates a keyframe log through SCXvid, with FFmpeg used for
decoding. The SCXvid path, FFmpeg path, and log suffix are configured
in Config → SCXvid.


13. SCREAM DETECTOR
___________________

Audio-driven QA tool. Runs FFmpeg astats on the loaded audio/video and
writes the [SCREAM] marker to lines whose interval is statistically
loud relative to the rest of the analysed set.

   13.1. Average line dB: mean power inside each subtitle interval.
         Closer to 0 is stricter.
   13.2. Strong sample dB: samples above this value count as strong
         evidence.
   13.3. Strong sample ratio (%): minimum percent of strong samples
         per interval.
   13.4. Minimum samples: ignores lines with too little audio
         evidence.
   13.5. Robust z-score: compares each line against the median/MAD of
         the analysed set.
   13.6. Apply to: All dialogue or Selected lines only.
   13.7. Clear previous SCREAM marks: removes earlier [SCREAM] in
         scope before writing new ones.
   13.8. Reuse existing analysis log: skips FFmpeg if a previous log
         exists. Useful for recalibration.


14. CONFIG
__________

Global configuration persisted between sessions.

   14.1. Language: en, es, pt.
   14.2. Auto Timing keeps its own source, mode, detection, margin, and
         silence controls in the Auto Timing window, not here.
   14.3. SCXvid: SCXvid path, FFmpeg path, and log suffix.
   14.4. Lead-In / Lead-Out / Chain: step in milliseconds for the
         lead utilities and max distance for Chain Left/Right.
   14.5. Kite Timing: base and maximum lead-in, base and maximum
         lead-out, chain out, and maximum chain gap.
   14.6. Bidirectional Snapping: frame range for the bidirectional
         snap, and directional range in milliseconds for the
         Start/End Snap tools.
   14.7. Audit Presets: Twin/Miss pairs for Start, End, and Full;
         Short/Long thresholds; maximum CPS; Short, Large, and Both
         gap presets; overtime; maximum width.


15. SUPPORT
___________

Discord: https://discord.gg/Egq8us4xZC

Integrated tools (1.6):
Joinator uses direct buttons: Join, Keep Second (two rows),
Keep Last, No Inner ... and One Phrase. Keep modes copy the chosen text exactly.
The first row supplies other fields; times span every selected dialogue row.
One Phrase also accepts one row: Hola. ¿Cómo estás? becomes Hola, ¿cómo estás?
Abbreviations, decimals, ellipses and acronyms are protected; review proper names.
Smart / Smart Split uses Wave2json and the shared Auto Timing waveform reader.
Continuo preserves outer times; Raw trims to voice activity. [CS-*] in Effect
marks estimated or uncertain boundaries. Drawings and animated text are skipped.
Smart Break is in Smart. It balances visual width and natural pauses.
Karaoke / Shift Following Lines shifts all dialogue rows BELOW the active row
as one block, including comments, leaving 100 ms after the active row's end.
It follows row order, preserves durations, and refuses negative times.
]],
    es = [[
CHRONO SUITE · GUÍA DE USO
___________________________

Suite de timing, auditoría, limpieza, importación y utilidades de
edición para Aegisub. La interfaz se compone de un panel principal y
diálogos auxiliares (Cleanup, Joinator, Final Data, Config
y Ayuda). El panel principal opera sobre la selección actual y se
divide en dos columnas: Marcadores de Auditoría (izquierda) y
Utilidades (derecha), con Importar Datos y Herramientas Extra en la
parte inferior. La mayoría de los resultados de auditoría se inscribe
en el campo Effect.


1. PANEL PRINCIPAL
__________________

El panel se organiza en torno a la selección actual. Las acciones se
ejecutan al pulsar EJECUTAR. Cleanup, Joinator y Final Data
se abren directamente y respetan Aplicar a / Filtro. Auto Timing y
Extraer KF están en Hephaestus Fansubber / Automatons.

   1.1. Aplicar a: define el subconjunto sobre el que actúan las
        secciones del panel.
   1.2. Filtro: campo de texto o número asociado al criterio de
        Aplicar a.
   1.3. Marcadores de Auditoría: presets, tolerancias, modo de
        keyframe y Marcador único.
   1.4. Utilidades: siete secciones independientes (Caja, Puntuación,
        Tags/Comentarios, Smart, Dividir/Unir, Tiempo/Orden y Karaoke).
   1.5. Importar Datos: importación desde texto pegado en la caja
        correspondiente.
   1.6. Tools: Reemplazar texto y mpv QC. Los demás editores tienen botones.

Un desplegable vacío omite la sección durante la ejecución.


2. APLICAR A / FILTRO
_____________________

   2.1. Toda la selección: utiliza la selección sin filtrar.
   2.2. Por estilo: conserva las líneas cuyo estilo coincide con
        Filtro.
   2.3. Por actor: conserva las líneas cuyo actor coincide con Filtro.
   2.4. Por Effect: conserva las líneas cuyo Effect contiene el texto
        del filtro (coincidencia parcial).
   2.5. Por capa: conserva las líneas cuyo Layer es igual al número
        escrito en Filtro.


3. PRESETS DE AUDITORÍA
_______________________

Cada preset configura las tolerancias indicadas en Config → Presets de
auditoría e inscribe sus marcadores en el campo Effect.

   3.1. Solo finales: contrasta el final de las líneas con keyframes
        cercanos. Inscribe únicamente Miss KF y Twin KF.
   3.2. Solo inicios: equivalente al anterior aplicado al inicio de las
        líneas.
   3.3. Auditoría completa: revisión general de texto, composición,
        timing, CPS, gaps y estructura.
   3.4. Duración: contrasta cada línea con los umbrales Corto y Largo.
   3.5. CPS: revisa velocidad de lectura contra el umbral configurado.
   3.6. Gaps cortos: revisa los espacios entre líneas contra el umbral
        de Gap corto.
   3.7. Gaps largos: revisa los espacios entre líneas contra el umbral
        de Gap largo.
   3.8. Ambos gaps: ejecuta ambas revisiones de gaps. Los marcadores
        se inscriben en ambas líneas adyacentes con los milisegundos
        detectados.
   3.9. Sobretiempo: marca las líneas que superan la duración máxima
        configurada.


4. CAMPOS NUMÉRICOS DE AUDITORÍA
________________________________

   4.1. Corto (ms) / Largo (ms): umbrales mínimo y máximo de duración.
   4.2. Twin KF (ms): distancia para identificar dos líneas que tocan
        el mismo keyframe.
   4.3. Miss KF (ms): distancia para identificar omisión de keyframe.
   4.4. Sobretiempo (ms): umbral exclusivo del preset Sobretiempo.
   4.5. CPS mín / CPS máx: rangos de velocidad de lectura.
   4.6. Gap corto (ms) / Gap largo (ms): umbrales de separación entre
        líneas.
   4.7. Ancho máximo (px): ancho visual de la línea utilizado como
        criterio de revisión.


5. MODO Y DIRECCIÓN DE KEYFRAME
_______________________________

   5.1. Modo KF: define el borde contrastado contra los keyframes:
        Solo inicio, Solo final o Ambos.
   5.2. Dir KF: dirección de búsqueda para Near/Missed KF: Atrás,
        Adelante o Ambos. El valor vacío equivale a Atrás.
   5.3. Sello Keyframe: opción independiente que inscribe START-ON-KF
        o END-ON-KF cuando el borde coincide con un keyframe.
   5.4. Marcar continuas (0 ms): incluye los gaps de cero milisegundos
        en la revisión.
   5.5. Ignorar gap en KF: omite los gaps cuyo borde coincide con un
        keyframe.
   5.6. Limpiar marcadores previos: elimina los marcadores existentes
        antes de inscribir los nuevos.


6. MARCADOR ÚNICO
_________________

Anula el preset elegido y ejecuta una sola comprobación. Su etiqueta se
inscribe en Effect.

   6.1. Numeración e identificación
        - Number Effects: numeración correlativa (1, 2, 3...).
        - Add Identifier: identificador único de 14 dígitos por línea.

   6.2. Texto y puntuación
        - UPPERCASE: línea íntegramente en mayúsculas.
        - THREE-LINES: línea con tres renglones visibles.
        - NO-END-PUNCT: línea sin puntuación final.
        - FINAL-COMMA: línea terminada en coma.
        - UNPAIRED-PUNCT: signos de puntuación sin contraparte.
        - STRONG-EXCL: signo de exclamacion visible ("¡", "!" o
          variante fullwidth).
        - STRONG-QUEST: palabra con "¿" de apertura y "?" de cierre.
        - MIXED-EMPHASIS: palabra con dos aperturas (¡¿) o dos
          cierres (?!).
        - SEMICOLON: línea con ";".
        - STUTTER: palabra con el patrón X-X (misma letra repetida
          con guion).

   6.3. Composición y estructura
        - SHORT-LAST-LINE: última línea visualmente corta.
        - BROKEN-TAG: bloque de override vacío o malformado.
        - OVERLAP: solapamiento con otra línea.
        - DEFAULT-STYLE: línea con estilo Default.
        - ITALIC-ERROR: incoherencia en el uso de cursivas.
        - PARENTHESES: paréntesis sin contraparte.
        - NAME-PREFIX: prefijo de nombre detectado.
        - MULTI-SENTENCE: varias oraciones en una misma línea.

   6.4. Presencia de override tags
        - LINE-BREAK, POSITION-TAG, CLIP-TAG, FADE-TAG, TRANSFORM-TAG,
          KARAOKE-TAG.
        - DRAWING-CLIP: dibujo vectorial que además lleva \clip o
          \iclip. Disponible como Marcador único.

   6.5. Limpieza y contenido
        - COMMENT-BLOCK: bloque de comentario en el texto.
        - HAS-DIGITS: presencia de dígitos.
        - HAS-CJK: caracteres CJK o kana.
        - FULL-ITALIC: línea íntegramente en cursiva.
        - DOUBLE-SPACE: espacios dobles en el texto.
        - EDGE-SPACE: espacios al inicio o al final.


7. UTILIDADES
_____________

Cada sección ofrece un desplegable independiente. El valor vacío omite
la sección durante la ejecución.

7.1. CAJA
    - Toggle \an8: alterna la posición superior \an8.
    - Toggle Italics: alterna cursiva.
    - Uppercase: conversión total a mayúsculas.
    - Lowercase: conversión total a minúsculas.
    - Title Case: capitalización por palabra.
    - Sentence Case: capitalización por oración.
    - Capitalize First: capitaliza el primer carácter visible.
    - Lowercase First: convierte el primer carácter visible a
      minúscula.

7.2. PUNTUACIÓN / TEXTO
    - Toggle ¡!: alterna el signo de exclamación de apertura.
    - Toggle ¿?: alterna el signo de interrogación de apertura.
    - Toggle ¡¿?!: alterna ambos signos de apertura.
    - Normalize Ellipsis: unifica los puntos suspensivos.
    - Add Ellipsis: añade puntos suspensivos al final de la línea.
    - Erase Leading Ellipsis: elimina puntos suspensivos iniciales.
    - Erase Inner Ellipsis: elimina puntos suspensivos internos y
      conserva los finales.
    - Ellipsis to Comma: sustituye puntos suspensivos finales por coma.
    - Ellipsis to Period: sustituye puntos suspensivos finales por
      punto.
    - Unify Quotes: unifica comillas.
    - Latin Quotes («»): convierte las comillas a guillemets latinos.
    - Normalize Dashes: normaliza guiones y rayas.
    - Trim Trailing Spaces: elimina espacios finales.
    - Remove Duplicate Letters: elimina letras consecutivas repetidas.
    - Add Stutter: inserta tartamudeo.
    - Add Ah Prefix: añade el prefijo "ah" al inicio del diálogo.
    - Normalize Stutter: diálogo interactivo para la gestión de
      tartamudeos.

7.3. TAGS / COMENTARIOS
    - Fold by Identifier: agrupa en folds las líneas que comparten un
      identificador. El fold se crea cuando el grupo tiene dos o más
      líneas.
    - Extract Tags: traslada los override tags desde el texto al campo
      Effect.
    - Reinsert Tags: devuelve los tags desde Effect al texto y
      normaliza los signos de punto y coma como coma dentro de los
      bloques de override.
    - Remove Tags: elimina los bloques de override del diálogo
      visible.
    - Merge Tags: une bloques de override contiguos borrando el }{
      entre ellos ({\an5}{\blur2} pasa a {\an5\blur2}). Respeta los
      bloques de comentario y los no contiguos.
    - Remove Inline Comments: elimina los bloques de comentario dentro del
      texto.
    - Extract Actors and Split: procesa información de actor a partir del texto.
    - Swap Text and Comments: intercambia texto visible y comentarios internos; conserva los tags.
    - Delete Comment Lines: elimina las líneas marcadas como
      comentario.
    - Comments to Top: reordena los comentarios al inicio de la
      selección.
    - Comments to Bottom: reordena los comentarios al final de la
      selección.
    - Effects to Top: sube las líneas con Effect no vacío al inicio de
      la selección conservando el orden relativo.

7.4. SMART
    - Bidirectional Snapping: ajusta inicio y final al keyframe más
      próximo dentro del rango configurado en frames.
    - Remove Honorifics: envuelve los honoríficos japoneses en
      bloques de comentario {…} para que permanezcan en la fuente
      pero desaparezcan visualmente.
    - Caption Clarifier: normaliza acotaciones de subtitulado.
    - Complete Sentences: une una línea incompleta con la siguiente
      cuando el texto posterior empieza en minúscula. Los solapes o
      continuaciones sin minúscula se marcan como [POSSIBLE-JOIN].
    - Erase Blank Lines: elimina las líneas vacías.
    - Current Frame to Effect: inscribe en Effect el número de frame
      actual del vídeo, sin borrar el contenido previo.
    - Copy Fold: muestra las filas ASS del fold de la primera línea
      seleccionada para copiarlas y selecciona ese grupo.

7.5. DIVIDIR / UNIR
    - Split by Sentence: divide la línea por oraciones.
    - Split by Comma: divide la línea por comas.
    - Pivot \N: desplaza el salto \N dentro de la línea.
    - Remove \N: elimina todos los \N de la línea y compacta espacios.
    - Join Same Text: une las líneas adyacentes con texto idéntico.
    - Join Overlaps: une grupos seleccionados cuyos tiempos se solapan,
      expande la línea conservada a los límites del grupo y mantiene
      cada texto separado por \N.
    - Join Overlap Sentences: une grupos seleccionados solapados en
      orden del grid como una sola frase, conserva la primera línea del
      grid como base y extiende el final al cierre del grupo.
    - Divide by \N: divide la línea por cada \N existente.

7.6. TIEMPO / ORDEN
    - Copy Times: copia los tiempos de una línea a otras.
    - Select Time Range: selecciona líneas comprendidas en un rango.
    - Sort by Text Length: ordena las líneas por longitud.
    - Sort by CPS: ordena las líneas por velocidad de lectura.
    - Sort Odd Even: ordena por valor numérico del Effect (impares y
      pares).
    - Count CPS: muestra el promedio de CPS sobre la selección.
    - Import Text: importa texto desde una fuente externa para
      reemplazo controlado.
    - Kite Timing: aplica el algoritmo Kite Timing (lead-in y lead-out
      adaptativos, encadenado y protección de bordes) según los
      valores definidos en Config.
    - Align to First Start: desplaza desde la segunda fila para que empiece
      en el inicio de la primera; conserva las distancias relativas.
    - Start Snap Back: ajusta el inicio al keyframe anterior.
    - Start Snap Forward: ajusta el inicio al keyframe siguiente.
    - End Snap Back: ajusta el final al keyframe anterior.
    - End Snap Forward: ajusta el final al keyframe siguiente.
    - Add Lead-In Left: adelanta el inicio hacia la izquierda por el
      paso configurado (Config → Lead-In / Lead-Out). Si hay una
      vecina encadenada con gap 0, su final se mueve junto con el
      inicio para mantener la cadena; si el gap es positivo, el inicio
      solo avanza hasta tocar a la vecina (gap 0), nunca la solapa.
    - Add Lead-In Right: mueve el inicio hacia la derecha por el paso
      configurado. Si hay una vecina encadenada con gap 0, su final se
      mueve junto para mantener la cadena.
    - Add Lead-Out Left: mueve el final hacia la izquierda por el paso
      configurado. La siguiente línea encadenada mueve su inicio para
      mantener la cadena.
    - Add Lead-Out Right: mueve el final hacia la derecha por el paso
      configurado, empujando el inicio de la siguiente línea si está
      encadenada.
    - Chain Left: extiende el inicio hasta el final de la línea
      anterior (crea gap 0), dentro de la distancia máxima
      configurada.
    - Chain Right: extiende el final hasta el inicio de la línea
      siguiente (crea gap 0), dentro de la distancia máxima
      configurada.

7.7. KARAOKE
    - Romaji Karaoker (Word → \k): genera karaoke simple por palabra
      en romaji con etiquetas {\k}.


8. IMPORTAR DATOS
_________________

La importación toma como fuente el texto pegado en la caja. La caja
vacía omite esta sección.

   8.1. Import Effects: copia el Effect de origen por superposición
        temporal.
   8.2. Import Text: copia el texto visible por superposición temporal.
   8.3. Import Actor: copia el actor por la mejor superposición
        temporal.
   8.4. Import Tags: combina los tags iniciales de la fuente con mayor solapamiento
        positivo. Un empate conserva el orden pegado. Solo sustituye tags iniciales
        coincidentes; clip/iclip son alternativas. Conserva el resto del formato,
        texto, dibujos, comentarios y tags internos. Sin tags o solapamiento no cambia nada.
   Import Lines: sustituye cada diálogo seleccionado por el grupo ASS pegado,
        conservando los tiempos del destino. Las casillas de importación no alteran la copia.
   8.5. Song Sync: duplica o sincroniza grupos a partir de una línea
        Comment con layer 50 como punto de sincronización. El Effect de
        la línea seleccionada se copia al Effect de cada línea importada;
        se conservan los Effects de origen.
   8.6. Same Layers: al marcarlo, Import Effects, Import Text, Import
        Actor e Import Tags solo emparejan líneas de origen cuyo layer
        coincide con el layer de la línea destino.
   8.7. Importar como comentario: encapsula el texto importado dentro
        de bloques {…} de comentario.


9. HERRAMIENTAS EXTRA
_____________________

   After Effects Keyframes está en Rhea Signs / Tools.
   9.2. Text Replacer: reemplaza texto visible conservando los
        override tags.
   9.3. mpv QC: lee notas exportadas desde mpvQC con formato
        [hh:mm:ss.ms] [Tipo] Observación {sugerencia}. La observación
        se inscribe como [QC: …] en Effect y la sugerencia se inserta
        como bloque de comentario en el texto. La tolerancia se define
        en milisegundos.
   9.4. Text and Tag Cleanup: elimina signos visibles, espacios,
        comentarios y override tags conocidos sin alternarlos si no
        existen.
10. AUTO TIMING
_______________

Auto Timing tiene dos métodos principales y una ruta Legacy aparte.
Cada control vive en esta ventana y persiste en la configuración de
Chrono Suite.

   10.1. Método:
         - Lazy: lee la actividad de voz desde un JSON de picos. Es el
           método simple y no necesita módulo extra.
         - Busy: combina silencios, VAD, flux, envolvente RMS y una onda
           opcional. Necesita el módulo Kite Timing desde
           DependencyControl.
   10.2. Modo para Lazy y Busy:
         - Completo + ajuste: detecta la voz y luego aplica márgenes,
           encadenado y ajuste a keyframes del video.
         - Voz bruta: mueve cada línea al inicio/final de la voz
           detectada, sin márgenes. No usa keyframes.
         - Post actual: conserva el in/out actual y solo aplica la
           pasada final de márgenes, encadenado y keyframes del video.
   10.3. JSON de onda: un archivo de picos (muestras min/max). Escribe
         una ruta o elígela con Buscar...; se cachea en la sesión, y
         Recargar caché de onda fuerza una relectura.
   10.4. Los keyframes se leen del video cargado, igual que los
         marcadores de auditoría. Completo + ajuste y Post actual los
         necesitan; Voz bruta no.
   10.5. Archivos Busy... abre solo las entradas de archivos usadas por
         Busy. Si procesas Busy sin JSON ni archivos Busy, esta ventana
         se abre primero.
   10.6. Legacy... abre el selector de método Legacy y sus archivos de
         silencios. Legacy ajusta los bordes a clústeres de silencio, no
         usa keyframes del video e inscribe etiquetas [LZ ...].
   10.7. Filtro de estilo: All, All Default, Default+Alt o un estilo
         exacto, más un segundo estilo exacto en la caja extra.
   10.8. Las líneas con problemas se marcan en Effect con marcadores
         [TM-...] (sin voz, voz débil, solape, corta, CPS alto), que se
         limpian en la siguiente ejecución.


11. AUTO TIMING: DETECCIÓN Y MÁRGENES
_____________________________________

Lazy suaviza la envolvente de picos, la umbraliza, limpia la máscara y
conserva el tramo de voz que luego rellena cada línea. Busy reutiliza
los mismos márgenes sobre su coincidencia combinada.

   11.1. Buscar ± (ms): cuánto mirar más allá del in/out de la propia
         línea para hallar la voz (0 = quedarse dentro de la línea).
   11.2. Suavizado (ms): ancho de la ventana de suavizado.
   11.3. Umbral automático (Otsu): elige el corte voz/silencio solo;
         apagado recurre a una sensibilidad por percentil.
   11.4. Unir huecos / Quitar islas (ms): cierra microsilencios y
         descarta microdestellos antes de medir el tramo.
   11.5. Recortar derrames de borde: descarta un destello tenue y bien
         separado pegado al borde para que no estire el timing.
   11.6. Márgenes · post-timing: lead-in / lead-out, cadena máx out /
         in, snap KF fin / inicio, corte de voz, duración mínima y la
         marca de CPS — los criterios por defecto que moldean cómo el
         tramo bruto se vuelve el in/out final.


12. EXTRAER KF
______________

Genera un log de keyframes mediante SCXvid, con apoyo de FFmpeg para la
decodificación. Las rutas de SCXvid y FFmpeg y el sufijo del log se
configuran en Config → SCXvid.


13. SCREAM DETECTOR
___________________

Herramienta de QA basada en audio. Ejecuta FFmpeg astats sobre el
audio/vídeo cargado e inscribe el marcador [SCREAM] en las líneas
cuyo intervalo es estadísticamente fuerte respecto al resto.

   13.1. Promedio dB: potencia media en el intervalo de cada
         subtítulo. Más cerca de 0 es más estricto.
   13.2. Muestra fuerte dB: muestras por encima de este valor cuentan
         como evidencia fuerte.
   13.3. Ratio muestra fuerte (%): porcentaje mínimo de muestras
         fuertes por intervalo.
   13.4. Muestras mínimas: ignora líneas con poca evidencia.
   13.5. z-score robusto: compara cada línea contra mediana/MAD del
         conjunto analizado.
   13.6. Aplicar a: Todo el diálogo o solo Líneas seleccionadas.
   13.7. Limpiar marcas SCREAM previas: borra [SCREAM] anteriores en
         el ámbito antes de escribir nuevos.
   13.8. Reutilizar log existente: evita ejecutar FFmpeg si ya existe
         el log. Útil para recalibrar.


14. CONFIG
__________

Configuración global persistente entre sesiones.

   14.1. Idioma: en, es, pt.
   14.2. Auto Timing guarda sus propios controles de fuente, modo,
         detección, márgenes y silencios en su ventana, no aquí.
   14.3. SCXvid: ruta de SCXvid, ruta de FFmpeg y sufijo del log.
   14.4. Lead-In / Lead-Out / Cadena: paso en milisegundos de
         las utilidades de lead y distancia máxima de Chain
         Left/Right.
   14.5. Kite Timing: lead-in base y máximo, lead-out base y máximo,
         salida en cadena y gap máximo de cadena.
   14.6. Bidirectional Snapping: rango en frames para el snap
         bidireccional y rango direccional en milisegundos para los
         Start/End Snap.
   14.7. Presets de auditoría: pares Twin/Miss para Inicio, Final y
         Completa; umbrales Corto/Largo; CPS máxima; presets de gaps
         cortos, largos y ambos; sobretiempo; ancho máximo.


15. SOPORTE
___________

Discord: https://discord.gg/Egq8us4xZC

Herramientas integradas (1.6):
Joinator tiene botones directos: Unir, Conservar segunda (dos
filas), Conservar última, Sin ... internos y Una frase. Conservar copia el texto
elegido exacto. Los demás campos son de la primera fila; el tiempo abarca todas.
Una frase también acepta una sola fila: Hola. ¿Cómo estás? → Hola, ¿cómo estás?
Protege abreviaturas, decimales, puntos suspensivos y siglas; revisa nombres propios.
Smart / Smart Split usa Wave2json y comparte el lector de onda con Auto Timing.
Continuo conserva los extremos; Raw ajusta a la actividad. Los marcadores [CS-*]
en Effect señalan cortes estimados o dudosos. Omite dibujos y texto animado.
Smart Break está en Smart y equilibra ancho visual y pausas naturales.
Karaoke / Shift Following Lines desplaza en bloque todas las filas de diálogo
POSTERIORES a la activa, incluidos comentarios, hasta dejar 100 ms tras su final.
Sigue el orden de filas, conserva duraciones y rechaza tiempos negativos.
]],
    pt = [[
CHRONO SUITE · GUIA DE USO
___________________________

Conjunto de timing, auditoria, limpeza, importação e utilidades de
edição para o Aegisub. A interface é composta por um painel principal
e diálogos auxiliares (Cleanup, Joinator, Final Data,
Config e Ajuda). O painel principal opera sobre a seleção atual e se
divide em duas colunas: Marcadores de Auditoria (esquerda) e
Utilidades (direita), com Importar Dados e Ferramentas Extras na
parte inferior. A maior parte dos resultados de auditoria é escrita
no campo Effect.


1. PAINEL PRINCIPAL
___________________

O painel se organiza em torno da seleção atual. As ações são
executadas ao pressionar EXECUTAR. Cleanup, Joinator e Final Data
abrem diretamente e respeitam Aplicar em / Filtro. Auto Timing e Extrair KF
estão em Hephaestus Fansubber / Automatons.

   1.1. Aplicar em: define o subconjunto sobre o qual as seções do
        painel atuam.
   1.2. Filtro: campo de texto ou número associado ao critério de
        Aplicar em.
   1.3. Marcadores de Auditoria: presets, tolerâncias, modo de
        keyframe e Marcador único.
   1.4. Utilidades: sete seções independentes (Caixa, Pont/Texto,
        Tags/Comentários, Smart, Dividir/Unir, Tempo/Ordem e Karaokê).
   1.5. Importar Dados: importação a partir de texto colado na caixa
        correspondente.
   1.6. Tools: Substituir texto e mpv QC. Os outros editores têm botões.

Um dropdown vazio salta sua seção durante a execução.


2. APLICAR EM / FILTRO
______________________

   2.1. Toda a seleção: usa a seleção sem filtrar.
   2.2. Por estilo: mantém as linhas cujo estilo coincide com Filtro.
   2.3. Por ator: mantém as linhas cujo ator coincide com Filtro.
   2.4. Por Effect: mantém as linhas cujo Effect contém o texto do
        filtro (coincidência parcial).
   2.5. Por camada: mantém as linhas cujo Layer é igual ao número
        escrito em Filtro.


3. PRESETS DE AUDITORIA
_______________________

Cada preset aplica as tolerâncias definidas em Config → Presets de
auditoria e inscreve seus marcadores no campo Effect.

   3.1. Só finais: verifica o fim das linhas contra keyframes
        próximos. Inscreve apenas Miss KF e Twin KF.
   3.2. Só inícios: verificação equivalente aplicada ao início das
        linhas.
   3.3. Auditoria completa: revisão geral de texto, composição,
        timing, CPS, gaps e estrutura.
   3.4. Duração: verifica cada linha contra os limites Curto e Longo.
   3.5. CPS: verifica a velocidade de leitura contra o máximo
        configurado.
   3.6. Gaps curtos: verifica os espaços entre linhas contra o limite
        de Gap curto.
   3.7. Gaps longos: verifica os espaços entre linhas contra o limite
        de Gap longo.
   3.8. Ambos gaps: executa ambas as revisões de gaps. Os marcadores
        são inscritos em ambas as linhas adjacentes com os milissegundos
        detectados.
   3.9. Sobretempo: marca as linhas que ultrapassam a duração máxima
        configurada.


4. CAMPOS NUMÉRICOS DE AUDITORIA
________________________________

   4.1. Curto (ms) / Longo (ms): limites mínimo e máximo de duração.
   4.2. Twin KF (ms): distância para identificar duas linhas que
        tocam o mesmo keyframe.
   4.3. Miss KF (ms): distância para identificar omissão de keyframe.
   4.4. Sobretempo (ms): limite exclusivo do preset Sobretempo.
   4.5. Min CPS / Max CPS: faixa de velocidade de leitura.
   4.6. Gap curto (ms) / Gap longo (ms): limites de separação entre
        linhas.
   4.7. Largura máx (px): largura visual da linha usada como critério
        de revisão.


5. MODO E DIREÇÃO DE KEYFRAME
_____________________________

   5.1. Modo KF: define a borda verificada contra os keyframes: Só
        início, Só final ou Ambos.
   5.2. Dir KF: direção de busca para Near/Missed KF: Para trás,
        Para frente ou Ambos. O valor vazio equivale a Para trás.
   5.3. Selo de Keyframe: opção independente que inscreve START-ON-KF
        ou END-ON-KF quando a borda coincide com um keyframe.
   5.4. Marcar contínuas (0 ms): inclui os gaps de zero milissegundos
        na revisão.
   5.5. Ignorar gap em KF: descarta os gaps cuja borda coincide com
        um keyframe.
   5.6. Limpar marcadores prévios: remove os marcadores existentes
        antes de inscrever os novos.


6. MARCADOR ÚNICO
_________________

Anula o preset escolhido e executa uma única verificação. Sua
etiqueta é inscrita no campo Effect.

   6.1. Numeração e identificação
        - Number Effects: numeração sequencial (1, 2, 3...).
        - Add Identifier: identificador único de 14 dígitos por linha.

   6.2. Texto e pontuação
        - UPPERCASE: linha inteira em maiúsculas.
        - THREE-LINES: linha exibida em três fileiras.
        - NO-END-PUNCT: linha sem pontuação final.
        - FINAL-COMMA: linha terminada em vírgula.
        - UNPAIRED-PUNCT: sinais de pontuação sem contraparte.
        - STRONG-EXCL: sinal de exclamação visível ("¡", "!" ou
          variante fullwidth).
        - STRONG-QUEST: palavra com "¿" de abertura e "?" de
          fechamento.
        - MIXED-EMPHASIS: palavra com duas aberturas (¡¿) ou dois
          fechamentos (?!).
        - SEMICOLON: linha contém ";".
        - STUTTER: palavra com o padrão X-X (mesma letra repetida com
          hífen).

   6.3. Composição e estrutura
        - SHORT-LAST-LINE: última linha visualmente curta.
        - BROKEN-TAG: bloco de override vazio ou malformado.
        - OVERLAP: sobreposição com outra linha.
        - DEFAULT-STYLE: linha com estilo Default.
        - ITALIC-ERROR: inconsistência no uso de itálico.
        - PARENTHESES: parênteses sem contraparte.
        - NAME-PREFIX: prefixo de nome detectado.
        - MULTI-SENTENCE: mais de uma frase em uma mesma linha.

   6.4. Presença de override tags
        - LINE-BREAK, POSITION-TAG, CLIP-TAG, FADE-TAG, TRANSFORM-TAG,
          KARAOKE-TAG.
        - DRAWING-CLIP: desenho vetorial que também traz \clip ou
          \iclip. Disponível como Marcador único.

   6.5. Limpeza e conteúdo
        - COMMENT-BLOCK: bloco de comentário embutido no texto.
        - HAS-DIGITS: presença de dígitos.
        - HAS-CJK: caracteres CJK ou kana.
        - FULL-ITALIC: linha inteira em itálico.
        - DOUBLE-SPACE: espaços duplos no texto.
        - EDGE-SPACE: espaços no início ou no final.


7. UTILIDADES
_____________

Cada seção oferece um dropdown independente. O valor vazio salta a
seção durante a execução.

7.1. CAIXA
    - Toggle \an8: alterna o alinhamento superior \an8.
    - Toggle Italics: alterna itálico.
    - Uppercase: converte todo o texto para maiúsculas.
    - Lowercase: converte todo o texto para minúsculas.
    - Title Case: capitaliza cada palavra.
    - Sentence Case: capitaliza a primeira palavra de cada frase.
    - Capitalize First: capitaliza o primeiro caractere visível.
    - Lowercase First: converte o primeiro caractere visível para
      minúscula.

7.2. PONTUAÇÃO / TEXTO
    - Toggle ¡!: alterna o sinal de exclamação de abertura.
    - Toggle ¿?: alterna o sinal de interrogação de abertura.
    - Toggle ¡¿?!: alterna ambos os sinais de abertura.
    - Normalize Ellipsis: unifica as reticências.
    - Add Ellipsis: adiciona reticências no final da linha.
    - Erase Leading Ellipsis: remove reticências iniciais.
    - Erase Inner Ellipsis: remove reticências internas e conserva as
      finais.
    - Ellipsis to Comma: substitui reticências finais por vírgula.
    - Ellipsis to Period: substitui reticências finais por ponto.
    - Unify Quotes: unifica as aspas.
    - Latin Quotes («»): converte as aspas para guillemets latinos.
    - Normalize Dashes: padroniza hifens, travessões e meias-riscas.
    - Trim Trailing Spaces: remove espaços finais.
    - Remove Duplicate Letters: remove letras consecutivas repetidas.
    - Add Stutter: insere gagueira no texto.
    - Add Ah Prefix: insere o prefixo "ah" no início do diálogo.
    - Normalize Stutter: normaliza iniciais repetidas e aplica gagueira a linhas [TT].

7.3. TAGS / COMENTÁRIOS
    - Fold by Identifier: agrupa em folds as linhas que compartilham
      um identificador. O fold é criado quando o grupo contém duas
      ou mais linhas.
    - Extract Tags: move os override tags do texto para o campo
      Effect.
    - Reinsert Tags: devolve os tags do Effect ao texto e normaliza
      os pontos e vírgulas como vírgulas dentro dos blocos de
      override.
    - Remove Tags: apaga os blocos de override do diálogo visível.
    - Merge Tags: une blocos de override contíguos apagando o }{
      entre eles ({\an5}{\blur2} vira {\an5\blur2}). Preserva os
      blocos de comentário e os não contíguos.
    - Remove Inline Comments: apaga os blocos de comentário dentro do texto.
    - Extract Actors and Split: extrai informação de ator a partir do texto.
    - Swap Text and Comments: troca texto visível e comentários internos; preserva as tags.
    - Delete Comment Lines: apaga as linhas marcadas como comentário.
    - Comments to Top: reordena os comentários ao início da seleção.
    - Comments to Bottom: reordena os comentários ao final da
      seleção.
    - Effects to Top: sobe as linhas com Effect não vazio ao início
      da seleção, preservando a ordem relativa.

7.4. SMART
    - Bidirectional Snapping: ajusta início e fim ao keyframe mais
      próximo dentro do alcance configurado em frames.
    - Remove Honorifics: envolve os honoríficos japoneses em blocos
      de comentário {…} para que permaneçam na fonte mas desapareçam
      visualmente.
    - Caption Clarifier: padroniza indicações de legendagem.
    - Complete Sentences: une uma linha incompleta com a seguinte
      quando o texto posterior começa em minúscula. Sobreposições ou
      continuações sem minúscula são marcadas como [POSSIBLE-JOIN].
    - Erase Blank Lines: apaga linhas em branco.
    - Current Frame to Effect: inscreve em Effect o número de frame
      atual do vídeo, sem apagar o conteúdo anterior.
    - Copy Fold: mostra as linhas ASS do fold da primeira linha
      selecionada para copiar e seleciona esse grupo.

7.5. DIVIDIR / UNIR
    - Split by Sentence: divide a linha por frase.
    - Split by Comma: divide a linha por vírgula.
    - Pivot \N: desloca a quebra \N dentro da linha.
    - Remove \N: remove todos os \N da linha e compacta espaços.
    - Join Same Text: une as linhas adjacentes com texto idêntico.
    - Join Overlaps: une grupos selecionados cujos tempos se sobrepõem,
      expande a linha preservada aos limites do grupo e mantém cada
      texto separado por \N.
    - Join Overlap Sentences: une grupos selecionados sobrepostos em
      ordem da grade como uma só frase, preserva a primeira linha da
      grade como base e estende o fim ao encerramento do grupo.
    - Divide by \N: divide a linha em cada \N existente.

7.6. TEMPO / ORDEM
    - Copy Times: copia os tempos de uma linha para outras.
    - Select Time Range: seleciona linhas dentro de um intervalo.
    - Sort by Text Length: ordena as linhas por comprimento.
    - Sort by CPS: ordena as linhas por velocidade de leitura.
    - Sort Odd Even: ordena pelo valor numérico do Effect (ímpares e
      pares).
    - Count CPS: mostra o CPS médio da seleção.
    - Import Text: importa texto a partir de uma fonte externa para
      substituição controlada.
    - Kite Timing: aplica o algoritmo Kite Timing (lead-in e
      lead-out adaptativos, encadeamento e proteção de bordas) com
      os valores de Config.
    - Align to First Start: desloca desde a segunda linha para começar
      no início da primeira, mantendo as distâncias relativas.
    - Start Snap Back: ajusta o início ao keyframe anterior.
    - Start Snap Forward: ajusta o início ao keyframe seguinte.
    - End Snap Back: ajusta o fim ao keyframe anterior.
    - End Snap Forward: ajusta o fim ao keyframe seguinte.
    - Add Lead-In Left: antecipa o início para a esquerda pelo passo
      configurado (Config → Lead-In / Lead-Out). Se houver uma
      vizinha encadeada com gap 0, o fim dela se move junto para
      manter a cadeia; com gap positivo, o início só avança até tocar
      a vizinha (gap 0), nunca a sobrepõe.
    - Add Lead-In Right: move o início para a direita pelo passo
      configurado. Se houver uma vizinha encadeada com gap 0, o fim
      dela se move junto para manter a cadeia.
    - Add Lead-Out Left: move o fim para a esquerda pelo passo
      configurado. A próxima linha encadeada move o início para
      manter a cadeia.
    - Add Lead-Out Right: move o fim para a direita pelo passo
      configurado, empurrando o início da linha seguinte se estiver
      encadeada.
    - Chain Left: estende o início até o fim da linha anterior (cria
      gap 0), dentro da distância máxima configurada.
    - Chain Right: estende o fim até o início da linha seguinte (cria
      gap 0), dentro da distância máxima configurada.

7.7. KARAOKÊ
    - Romaji Karaoker (Word → \k): gera karaokê simples por palavra
      em romaji com tags {\k}.


8. IMPORTAR DADOS
_________________

A importação toma como fonte o texto colado na caixa de Importar
Dados. A caixa vazia salta esta seção.

   8.1. Import Effects: copia o Effect de origem por sobreposição
        temporal.
   8.2. Import Text: copia o texto visível por sobreposição temporal.
   8.3. Import Actor: copia o ator pela melhor sobreposição temporal.
   8.4. Import Tags: combina os tags iniciais da fonte com maior sobreposição
        positiva. Empates seguem a ordem colada. Só substitui tags iniciais
        correspondentes; clip/iclip são alternativas. Preserva a restante formatação,
        texto, desenhos, comentários e tags internos. Sem tags ou sobreposição não altera a linha.
   Import Lines: substitui cada diálogo selecionado pelo grupo ASS colado,
        mantendo os tempos do destino. As opções de importação não alteram a cópia.
   8.5. Song Sync: duplica ou sincroniza grupos a partir de uma linha
        Comment com layer 50 como ponto de sincronia. O Effect da linha
        selecionada é copiado ao Effect de cada linha importada; os
        Effects de origem são preservados.
   8.6. Same Layers: quando marcado, Import Effects, Import Text,
        Import Actor e Import Tags só combinam linhas de origem cujo
        layer coincide com o layer da linha destino.
   8.7. Importar como comentário: encapsula o texto importado dentro
        de blocos {…} de comentário.


9. FERRAMENTAS EXTRAS
_____________________

   After Effects Keyframes está em Rhea Signs / Tools.
   9.2. Text Replacer: substitui texto visível preservando os
        override tags.
   9.3. mpv QC: lê notas exportadas do mpvQC no formato
        [hh:mm:ss.ms] [Tipo] Observação {sugestão}. A observação é
        inscrita como [QC: …] em Effect e a sugestão é inserida como
        bloco de comentário no texto. A tolerância é definida em
        milissegundos.
   9.4. Text and Tag Cleanup: remove sinais visíveis, espaços,
        comentários e override tags conhecidos sem alterná-los quando
        ausentes.
10. AUTO TIMING
_______________

Auto Timing tem dois métodos principais e uma rota Legacy separada.
Cada controle vive nesta janela e persiste na configuração do Chrono
Suite.

   10.1. Método:
         - Lazy: lê a atividade de voz a partir de um JSON de picos. É
           o método simples e não precisa de módulo extra.
         - Busy: combina silêncios, VAD, flux, envelope RMS e uma onda
           opcional. Precisa do módulo Kite Timing pelo DependencyControl.
   10.2. Modo para Lazy e Busy:
         - Completo + ajuste: detecta a voz e depois aplica margens,
           encadeamento e ajuste a keyframes do vídeo.
         - Voz bruta: move cada linha para o início/fim da voz
           detectada, sem margens. Não usa keyframes.
         - Pós atual: mantém o in/out atual e só aplica a passagem final
           de margens, encadeamento e keyframes do vídeo.
   10.3. JSON da onda: um arquivo de picos (amostras min/max). Digite
         um caminho ou escolha com Procurar...; fica em cache na sessão,
         e Recarregar cache da onda força nova leitura.
   10.4. Os keyframes são lidos do vídeo carregado, do mesmo jeito que
         os marcadores de auditoria. Completo + ajuste e Pós atual
         precisam deles; Voz bruta não.
   10.5. Arquivos Busy... abre só as entradas de arquivos usadas pelo
         Busy. Se você processar Busy sem JSON nem arquivos Busy, esta
         janela abre primeiro.
   10.6. Legacy... abre o seletor do método Legacy e seus arquivos de
         silêncios. Legacy ajusta as bordas a clusters de silêncio, não
         usa keyframes do vídeo e inscreve tags [LZ ...].
   10.7. Filtro de estilo: All, All Default, Default+Alt ou um estilo
         exato, mais um segundo estilo exato na caixa extra.
   10.8. Linhas com problemas são marcadas em Effect com marcadores
         [TM-...] (sem voz, voz fraca, sobreposição, curta, CPS alto),
         limpas na próxima execução.


11. AUTO TIMING: DETECÇÃO E MARGENS
___________________________________

Lazy suaviza a envoltória de picos, aplica limiar, limpa a máscara e
mantém o trecho de voz que depois preenche cada linha. Busy reutiliza
as mesmas margens na sua correspondência combinada.

   11.1. Buscar ± (ms): quanto olhar além do in/out da própria linha
         para achar a voz (0 = ficar dentro da linha).
   11.2. Suavização (ms): largura da janela de suavização.
   11.3. Limiar automático (Otsu): escolhe o corte voz/silêncio
         sozinho; desligado recorre a uma sensibilidade por percentil.
   11.4. Unir lacunas / Remover ilhas (ms): fecha microssilêncios e
         descarta microlampejos antes de medir o trecho.
   11.5. Aparar derrames de borda: descarta um lampejo fraco e bem
         separado colado à borda para não esticar o timing.
   11.6. Margens · pós-timing: lead-in / lead-out, cadeia máx out / in,
         snap KF fim / início, corte de voz, duração mínima e a marca
         de CPS — os critérios padrão que moldam como o trecho bruto
         vira o in/out final.


12. EXTRAIR KF
______________

Gera um log de keyframes por meio do SCXvid, com apoio do FFmpeg para
a decodificação. O caminho do SCXvid, o caminho do FFmpeg e o sufixo
do log são configurados em Config → SCXvid.


13. SCREAM DETECTOR
___________________

Ferramenta de QA baseada em áudio. Executa FFmpeg astats no
áudio/vídeo carregado e escreve o marcador [SCREAM] nas linhas cujo
intervalo é estatisticamente forte em relação ao restante.

   13.1. Média dB: potência média no intervalo de cada legenda. Mais
         perto de 0 é mais estrito.
   13.2. Amostra forte dB: amostras acima deste valor contam como
         evidência forte.
   13.3. Razão amostra forte (%): porcentagem mínima de amostras
         fortes por intervalo.
   13.4. Amostras mínimas: ignora linhas com pouca evidência.
   13.5. z-score robusto: compara cada linha contra mediana/MAD do
         conjunto analisado.
   13.6. Aplicar em: Todo o diálogo ou somente Linhas selecionadas.
   13.7. Limpar marcas SCREAM anteriores: apaga [SCREAM] anteriores
         no escopo antes de escrever novos.
   13.8. Reutilizar log existente: evita executar FFmpeg se já existe
         o log. Útil para recalibrar.


14. CONFIG
__________

Configuração global persistente entre sessões.

   14.1. Idioma: en, es, pt.
   14.2. O Auto Timing guarda seus próprios controles de fonte, modo,
         detecção, margens e silêncios na sua janela, não aqui.
   14.3. SCXvid: caminho do SCXvid, caminho do FFmpeg e sufixo do
         log.
   14.4. Lead-In / Lead-Out / Cadeia: passo em
         milissegundos das utilidades de lead e distância máxima de
         Chain Left/Right.
   14.5. Kite Timing: lead-in base e máximo, lead-out base e máximo,
         saída em cadeia e gap máximo da cadeia.
   14.6. Bidirectional Snapping: alcance em frames para o snap
         bidirecional e alcance direcional em milissegundos para as
         ferramentas Start/End Snap.
   14.7. Presets de auditoria: pares Twin/Miss para Início, Fim e
         Completa; limites Curto/Longo; CPS máximo; presets de gaps
         curtos, longos e ambos; sobretempo; largura máxima.


15. SUPORTE
___________

Discord: https://discord.gg/Egq8us4xZC

Ferramentas integradas (1.6):
Joinator tem botões diretos: Unir, Manter segunda (duas linhas),
Manter última, Sem ... internos e Uma frase. Manter copia o texto escolhido exato.
Os demais campos vêm da primeira linha; os tempos abrangem toda a seleção.
Uma frase aceita uma linha: Hola. ¿Cómo estás? → Hola, ¿cómo estás?
Protege abreviações, decimais, reticências e siglas; revise nomes próprios.
Smart / Smart Split usa Wave2json e compartilha o leitor de onda do Auto Timing.
Continuo preserva os extremos; Raw ajusta à atividade. [CS-*] em Effect marca
cortes estimados ou incertos. Desenhos e texto animado são ignorados.
Smart Break fica em Smart e equilibra largura visual e pausas naturais.
Karaoke / Shift Following Lines desloca em bloco todas as linhas de diálogo
ABAIXO da ativa, incluindo comentários, deixando 100 ms após seu final.
Segue a ordem das linhas, preserva durações e rejeita tempos negativos.
]],
}
local function showHelp()
    aegisub.dialog.display({{class="textbox", text="Auto Timing, Scream Detector and SCXvid: Hephaestus Fansubber / Automatons / Auto Timing.\n\n" .. (suiteHelp[currentLang] or suiteHelp.en), x=0, y=0, width=45, height=25}}, {L("help_btn_close")})
end

local function showConfigDialog()
    resolveConfig()
    local cfgUi = {
        language = UI.options({"en","es","pt"}, currentConfig.language),
    }
    local dlg = {
        { class="label", label=L("cfg_lbl_language"), x=0, y=0, width=2, height=1 },
        { class="dropdown", name="language", items=cfgUi.language.items, value=cfgUi.language.value, x=2, y=0, width=2, height=1 },
        { class="label", label=L("cfg_lbl_leadutil"), x=0, y=1, width=4, height=1 },
        { class="label", label=L("cfg_lbl_lead_step"), x=0, y=2, width=1, height=1 },
        { class="intedit", name="lead_step_ms", value=currentConfig.lead_step_ms, x=1, y=2, width=1, min=1 },
        { class="label", label=L("cfg_lbl_chain_cap"), x=2, y=2, width=1, height=1 },
        { class="intedit", name="chain_max_ms", value=currentConfig.chain_max_ms, x=3, y=2, width=1, min=0 },
        { class="label", label=L("cfg_lbl_kite"), x=0, y=3, width=4, height=1 },
        { class="intedit", name="kt_lead_in_base", value=currentConfig.kt_lead_in_base, x=0, y=4, width=1, min=0 },
        { class="intedit", name="kt_lead_in_max", value=currentConfig.kt_lead_in_max, x=1, y=4, width=1, min=0 },
        { class="intedit", name="kt_lead_out_base", value=currentConfig.kt_lead_out_base, x=2, y=4, width=1, min=0 },
        { class="intedit", name="kt_lead_out_max", value=currentConfig.kt_lead_out_max, x=3, y=4, width=1, min=0 },
        { class="intedit", name="kt_lead_out_chain", value=currentConfig.kt_lead_out_chain, x=0, y=5, width=1, min=0 },
        { class="intedit", name="kt_chain_gap_max", value=currentConfig.kt_chain_gap_max, x=1, y=5, width=1, min=0 },
        { class="label", label=L("cfg_lbl_bidir"), x=0, y=6, width=4, height=1 },
        { class="label", label=L("cfg_lbl_bidir_snap"), x=0, y=7, width=2, height=1 },
        { class="intedit", name="bidir_snap_f", value=currentConfig.bidir_snap_f, x=2, y=7, width=1, min=0 },
        { class="label", label=L("cfg_lbl_snap_protect"), x=0, y=8, width=2, height=1 },
        { class="intedit", name="edge_snap_protect_ms", value=currentConfig.edge_snap_protect_ms, x=2, y=8, width=1, min=0 },
        { class="label", label=L("cfg_lbl_presets"), x=4, y=1, width=4, height=1 },
        { class="label", label=L("cfg_lbl_preset_start"), x=4, y=2, width=2, height=1 },
        { class="intedit", name="preset_start_twin_ms", value=currentConfig.preset_start_twin_ms, x=6, y=2, width=1, min=0 },
        { class="intedit", name="preset_start_miss_ms", value=currentConfig.preset_start_miss_ms, x=7, y=2, width=1, min=0 },
        { class="label", label=L("cfg_lbl_preset_end"), x=4, y=3, width=2, height=1 },
        { class="intedit", name="preset_end_twin_ms", value=currentConfig.preset_end_twin_ms, x=6, y=3, width=1, min=0 },
        { class="intedit", name="preset_end_miss_ms", value=currentConfig.preset_end_miss_ms, x=7, y=3, width=1, min=0 },
        { class="label", label=L("cfg_lbl_preset_full_kf"), x=4, y=4, width=2, height=1 },
        { class="intedit", name="preset_full_twin_ms", value=currentConfig.preset_full_twin_ms, x=6, y=4, width=1, min=0 },
        { class="intedit", name="preset_full_miss_ms", value=currentConfig.preset_full_miss_ms, x=7, y=4, width=1, min=0 },
        { class="label", label=L("cfg_lbl_preset_full_time"), x=4, y=5, width=2, height=1 },
        { class="intedit", name="preset_full_short_ms", value=currentConfig.preset_full_short_ms, x=6, y=5, width=1, min=0 },
        { class="intedit", name="preset_full_long_ms", value=currentConfig.preset_full_long_ms, x=7, y=5, width=1, min=0 },
        { class="label", label=L("cfg_lbl_preset_full_read"), x=4, y=6, width=2, height=1 },
        { class="intedit", name="preset_full_max_cps", value=currentConfig.preset_full_max_cps, x=6, y=6, width=1, min=0 },
        { class="intedit", name="preset_full_max_width", value=currentConfig.preset_full_max_width, x=7, y=6, width=1, min=0 },
        { class="label", label=L("cfg_lbl_preset_full_gap"), x=4, y=7, width=2, height=1 },
        { class="intedit", name="preset_full_short_gap_ms", value=currentConfig.preset_full_short_gap_ms, x=6, y=7, width=1, min=0 },
        { class="intedit", name="preset_full_large_gap_ms", value=currentConfig.preset_full_large_gap_ms, x=7, y=7, width=1, min=0 },
        { class="label", label=L("cfg_lbl_preset_duration"), x=4, y=8, width=2, height=1 },
        { class="intedit", name="preset_duration_short_ms", value=currentConfig.preset_duration_short_ms, x=6, y=8, width=1, min=0 },
        { class="intedit", name="preset_duration_long_ms", value=currentConfig.preset_duration_long_ms, x=7, y=8, width=1, min=0 },
        { class="label", label=L("cfg_lbl_preset_cps"), x=4, y=9, width=2, height=1 },
        { class="intedit", name="preset_cps_max", value=currentConfig.preset_cps_max, x=6, y=9, width=1, min=0 },
        { class="label", label=L("cfg_lbl_preset_overtime"), x=4, y=10, width=2, height=1 },
        { class="intedit", name="preset_overtime_ms", value=currentConfig.preset_overtime_ms, x=6, y=10, width=1, min=0 },
        { class="label", label=L("cfg_lbl_preset_gaps"), x=4, y=11, width=2, height=1 },
        { class="intedit", name="preset_gap_short_ms", value=currentConfig.preset_gap_short_ms, x=6, y=11, width=1, min=0 },
        { class="intedit", name="preset_gap_large_ms", value=currentConfig.preset_gap_large_ms, x=7, y=11, width=1, min=0 },
        { class="label", label=L("lbl_apply_to"), x=4, y=19, width=3, height=1 },
    }
    local pressed, result = aegisub.dialog.display(dlg, {L("btn_save"), L("btn_cancel")}, {ok=L("btn_save"), close=L("btn_cancel")})
    if pressed == L("btn_save") then
        local oldLang = currentConfig.language
        result.language = UI.from(cfgUi.language, result.language)
        for k, v in pairs(result) do currentConfig[k] = v end
        local saved, message = saveConfig()
        resolveConfig()
        showMsg(saved and L("cfg_msg_saved") or tostring(message or "Could not save configuration."))
        if oldLang ~= currentConfig.language then showMsg(L("cfg_msg_lang_changed")) end
    end
end


local function normalizeString(v) if type(v)=="string" then return v end if v==nil then return "" end return tostring(v) end
local function normalizeNumber(v, fallback)
    local number = tonumber(v)
    if not number or number ~= number or math.abs(number) == math.huge then return fallback end
    return number
end
local function escapeLuaPattern(t) return normalizeString(t):gsub("(%W)", "%%%1") end

local function splitUtf8Chars(text)
    local out = {}
    for c in normalizeString(text):gmatch(utf8CharPattern) do out[#out+1] = c end
    return out
end
local function joinRange(chars, a, b) if a > b then return "" end; return table.concat(chars, "", a, b) end
local function unicodeLenSafe(t)
    local ok, n = pcall(unicode.len, normalizeString(t))
    if ok and type(n) == "number" then return n end
    return #splitUtf8Chars(t)
end
local function mapLatinFallback(text, mapping)
    local chars = splitUtf8Chars(text)
    for i, c in ipairs(chars) do chars[i] = mapping[c] or c end
    return table.concat(chars)
end
local function unicodeUpper(t)
    t = normalizeString(t)
    local ok, v = pcall(unicode.to_upper, t)
    if ok and type(v) == "string" then return mapLatinFallback(v, latinLowerToUpper) end
    return mapLatinFallback(string.upper(t), latinLowerToUpper)
end
local function unicodeLower(t)
    t = normalizeString(t)
    local ok, v = pcall(unicode.to_lower, t)
    if ok and type(v) == "string" then return mapLatinFallback(v, latinUpperToLower) end
    return mapLatinFallback(string.lower(t), latinUpperToLower)
end
local function unicodeSub(text, fromIdx, toIdx)
    text = normalizeString(text)
    local chars = splitUtf8Chars(text)
    local a = fromIdx or 1; local b = toIdx or #chars
    if a < 0 then a = #chars + a + 1 end
    if b < 0 then b = #chars + b + 1 end
    return joinRange(chars, math.max(1, a), math.min(#chars, b))
end
local function trimText(t)
    t = normalizeString(t)
    if Kite.Core then return Kite.Core.trim(t) end
    return (t:gsub("^%s+", ""):gsub("%s+$", ""))
end
local function roundNumber(v, digits)
    if Kite.Core then return Kite.Core.roundTo(v, digits) end
    local m = 10 ^ (digits or 0)
    if v >= 0 then return math.floor(v*m + 0.5)/m end
    return math.ceil(v*m - 0.5)/m
end
local function isWhitespaceChar(c) return c ~= nil and (c == NBSP or (#c == 1 and c:match("^%s$") ~= nil)) end
local function isPunctuationChar(c) return utf8PunctuationChars[c] == true or (#c == 1 and c:match("^%p$") ~= nil) end
local function isLetter(c)
    c = normalizeString(c); if c == "" then return false end
    return unicodeLower(c) ~= unicodeUpper(c)
end
local function startsWith(t, p) t = normalizeString(t); p = normalizeString(p); return p == "" or t:sub(1, #p) == p end
local function endsWith(t, s)   t = normalizeString(t); s = normalizeString(s); return s == "" or t:sub(-#s) == s end
local function countChar(text, target)
    local n = 0; for _, c in ipairs(splitUtf8Chars(text)) do if c == target then n = n + 1 end end; return n
end
local function countLiteral(text, lit)
    local _, n = normalizeString(text):gsub(escapeLuaPattern(lit), ""); return n
end

local function cloneLine(l)
    if type(l.copy) == "function" then return l:copy() end
    if Kite.Core and Kite.Core.deepCopy then
        local d = Kite.Core.deepCopy(l)
        d.class = d.class or "dialogue"
        return d
    end
    local d = { class = l.class or "dialogue" }
    for k, v in pairs(l) do
        if type(v) == "table" then
            d[k] = {}; for ki, vi in pairs(v) do d[k][ki] = vi end
        else
            d[k] = v
        end
    end
    setmetatable(d, getmetatable(l))
    return d
end

local function clockToMs(h, m, s, frac)
    h, m, s = tonumber(h), tonumber(m), tonumber(s)
    if not h or not m or not s or h < 0 or m < 0 or m >= 60 or s < 0 or s >= 60 then return nil end
    local base = (h * 3600 + m * 60 + s) * 1000
    if frac and frac ~= "" then
        if not tostring(frac):match("^%d+$") then return nil end
        return base + tonumber((frac .. "000"):sub(1, 3))
    end
    return base
end

local function splitEventLine(line)
    local prefix = line:match("^(Dialogue):") or line:match("^(Comment):")
    if not prefix then return nil end
    local fields, startPos = {}, #prefix + 2
    for _ = 1, 9 do
        local comma = line:find(",", startPos, true); if not comma then return nil end
        fields[#fields+1] = line:sub(startPos, comma - 1); startPos = comma + 1
    end
    fields[10] = line:sub(startPos)
    return prefix, fields
end

local function msToAssTime(ms)
    local h = math.floor(ms / 3600000)
    local m = math.floor((ms % 3600000) / 60000)
    local s = math.floor((ms % 60000) / 1000)
    local cs = math.floor((ms % 1000) / 10)
    return string.format("%d:%02d:%02d.%02d", h, m, s, cs)
end
local function assTimeToMs(t)
    local h, m, s, cs = normalizeString(t):match("^%s*(%d+):(%d+):(%d+)%.(%d+)%s*$")
    if not h then return nil end
    return clockToMs(h, m, s, cs)
end

local function stripTags(text)
    text = normalizeString(text)
    return (text:gsub("(%b{})", function(b)
        return b:match("^%{%s*\\") and "" or b
    end))
end

local function stripComments(text)
    text = normalizeString(text)
    return text:gsub("{([^}]*)}", function(inner)
        if inner:match("^%s*\\") then return "{" .. inner .. "}" end
        return ""
    end)
end

local function visibleText(text)
    if Kite.LineOps then return Kite.LineOps.visibleText(text) end
    return stripComments(stripTags(text)):gsub("\\[Nnh]", " ")
end

local function countCharacters(text)
    local n = 0
    for _, c in ipairs(splitUtf8Chars(visibleText(text))) do
        if not isWhitespaceChar(c) and not isPunctuationChar(c) then n = n + 1 end
    end
    return n
end

local function countWords(text)
    local n, inWord = 0, false
    for _, c in ipairs(splitUtf8Chars(visibleText(text))) do
        if not isWhitespaceChar(c) and not isPunctuationChar(c) then
            if not inWord then n = n + 1; inWord = true end
        else
            inWord = false
        end
    end
    return n
end

local function validateDuration(l) return l.end_time and l.start_time and l.end_time > l.start_time end

local function addEffectMarker(line, marker)
    marker = normalizeString(marker); if marker == "" then return end
    local effect = normalizeString(line.effect)
    if not effect:find(escapeLuaPattern(marker), 1) then
        line.effect = (effect == "" and marker or effect .. " " .. marker)
    end
end

local function isOverrideBlock(block) return normalizeString(block):match("^%{%s*\\") ~= nil end

local function mutateOverrideBlocks(text, blockMutator)
    text = normalizeString(text)
    local out, cursor = {}, 1
    for startIdx, block, endIdx in text:gmatch("()(%b{})()") do
        if startIdx > cursor then out[#out+1] = text:sub(cursor, startIdx - 1) end
        if isOverrideBlock(block) then out[#out+1] = blockMutator(block) else out[#out+1] = block end
        cursor = endIdx
    end
    out[#out+1] = text:sub(cursor)
    return table.concat(out)
end

local function hasOverridePattern(text, pattern)
    text = normalizeString(text)
    for block in text:gmatch("(%b{})") do
        if isOverrideBlock(block) and block:match(pattern) then return true end
    end
    return false
end

local function removeOverridePattern(text, pattern)
    return mutateOverrideBlocks(text, function(block)
        local inner = block:sub(2, -2):gsub(pattern, "")
        if inner:match("^%s*$") then return "" end
        return "{" .. inner .. "}"
    end)
end

local function insertOverrideAfterLeadingComments(text, tagBlock)
    text = normalizeString(text); local cursor = 1
    while text:sub(cursor, cursor) == "{" do
        local s, e = text:find("%b{}", cursor)
        if not s or s ~= cursor then break end
        if isOverrideBlock(text:sub(s, e)) then break end
        cursor = e + 1
    end
    return text:sub(1, cursor - 1) .. tagBlock .. text:sub(cursor)
end

local function splitLeadingTagBlocks(text)
    text = normalizeString(text)
    local cursor, chunks = 1, {}
    while text:sub(cursor, cursor) == "{" do
        local s, e = text:find("%b{}", cursor); if not s or s ~= cursor then break end
        local block = text:sub(s, e)
        if block:match("^%{%s*\\") then chunks[#chunks+1] = block else break end
        cursor = e + 1
    end
    return table.concat(chunks, ""), text:sub(cursor)
end

local function splitLeadingBraceBlocks(text)
    text = normalizeString(text)
    local cursor = 1
    while text:sub(cursor, cursor) == "{" do
        local s, e = text:find("%b{}", cursor)
        if not s or s ~= cursor then break end
        cursor = e + 1
    end
    return text:sub(1, cursor - 1), text:sub(cursor)
end

local function extractLeadingTagBlocks(text)
    text = normalizeString(text)
    local cursor, chunks = 1, {}
    while text:sub(cursor, cursor) == "{" do
        local s, e = text:find("%b{}", cursor); if not s or s ~= cursor then break end
        local block = text:sub(s, e)
        if block:match("^%{%s*\\") then chunks[#chunks+1] = block end
        cursor = e + 1
    end
    return table.concat(chunks, "")
end

local function extractEffectTagBlocks(effect)
    local tags = {}
    local rest = normalizeString(effect):gsub("%b{}", function(b)
        if b:match("^%{%s*\\") then tags[#tags+1] = b; return " " end
        return b
    end)
    return table.concat(tags, ""), trimText(rest:gsub("%s+", " "))
end

local function splitTrailingTagBlocks(text)
    text = trimText(text); local tags = {}
    while true do
        local s, e = text:find("%{%s*\\[^}]*%}%s*$"); if not s then break end
        table.insert(tags, 1, trimText(text:sub(s, e)))
        text = trimText(text:sub(1, s - 1))
    end
    return text, table.concat(tags, "")
end

local function mutateTextOutsideBlocks(text, sectionMutator)
    text = normalizeString(text)
    if Kite.LineOps and Kite.LineOps.scanSections then
        local out = {}
        for _, section in ipairs(Kite.LineOps.scanSections(text)) do
            out[#out+1] = section.type == "text" and sectionMutator(section.text)
                or text:sub(section.start, section.finish)
        end
        return table.concat(out)
    end
    local out, cursor = {}, 1
    while cursor <= #text do
        local s, e = text:find("%b{}", cursor)
        if not s then out[#out+1] = sectionMutator(text:sub(cursor)); break end
        if s > cursor then out[#out+1] = sectionMutator(text:sub(cursor, s - 1)) end
        out[#out+1] = text:sub(s, e)
        cursor = e + 1
    end
    if #out == 0 then return sectionMutator("") end
    return table.concat(out)
end

local function mutateTextSections(line, sectionMutator)
    line.text = mutateTextOutsideBlocks(line.text, sectionMutator)
end

local function isDialogue(l) return type(l) == "table" and l.class == "dialogue" end
local function isEditableDialogue(l) return isDialogue(l) and not l.comment end
local function isVectorDrawing(line)
    local text = normalizeString(line and line.text or "")
    if hasOverridePattern(text, "\\p[1-9]") then return true end
    return false
end

local function collectSelection(subs, sel, predicate)
    if Kite.LineOps and Kite.LineOps.normalizeIndices then
        return Kite.LineOps.normalizeIndices(subs, sel, predicate)
    end
    local out, seen = {}, {}
    for _, i in ipairs(sel or {}) do
        i = tonumber(i)
        if i and i == math.floor(i) and i >= 1 and i <= #subs and not seen[i] and predicate(subs[i]) then
            seen[i] = true; out[#out+1] = i
        end
    end
    table.sort(out)
    return out
end
local function collectEditableSelection(subs, sel)
    return collectSelection(subs, sel, isEditableDialogue)
end
local function collectEditableTextSelection(subs, sel)
    return collectSelection(subs, sel, function(line)
        return isEditableDialogue(line) and not isVectorDrawing(line)
    end)
end
local function collectDialogueSelection(subs, sel)
    if Kite.EventOps and Kite.EventOps.dialogueIndices then return Kite.EventOps.dialogueIndices(subs, sel) end
    return collectSelection(subs, sel, isDialogue)
end

local function getTargetedSelection(subs, sel, c)
    local selected = collectDialogueSelection(subs, sel)
    if not c or c.mode == "All Selected" then return selected end
    local f = {}
    for _, i in ipairs(selected) do
        local l = subs[i]; local m = false
        if isDialogue(l) then
            if     c.mode == "By Style"  and normalizeString(l.style) == normalizeString(c.value) then m = true
            elseif c.mode == "By Actor"  and normalizeString(l.actor) == normalizeString(c.value) then m = true
            elseif c.mode == "By Layer"  and (tonumber(l.layer) or 0) == tonumber(c.value) then m = true
            elseif c.mode == "By Effect" and normalizeString(l.effect):find(normalizeString(c.value), 1, true) then m = true
            end
        end
        if m then table.insert(f, i) end
    end
    return f
end

local function remapSelectionAfterDeletion(subs, originalSel, deleteSet)
    local delSorted = {}
    for k in pairs(deleteSet or {}) do delSorted[#delSorted+1] = k end
    table.sort(delSorted)
    local sortedSel = {}
    for _, v in ipairs(originalSel or {}) do sortedSel[#sortedSel+1] = v end
    table.sort(sortedSel)
    local newSel = {}
    for _, i in ipairs(sortedSel) do
        if not (deleteSet and deleteSet[i]) then
            local shift = 0
            for _, d in ipairs(delSorted) do
                if d < i then shift = shift + 1 else break end
            end
            newSel[#newSel+1] = i - shift
        end
    end
    if #newSel == 0 and #sortedSel > 0 then
        local first = math.min(sortedSel[1], #subs)
        for i = first, #subs do
            if isDialogue(subs[i]) then return { i } end
        end
        for i = first - 1, 1, -1 do
            if isDialogue(subs[i]) then return { i } end
        end
    end
    return newSel
end

local function splitTextAtLinebreaks(text)
    local parts, current = {}, ""
    text = normalizeString(text)
    local cursor = 1
    while cursor <= #text do
        local bs, be = text:find("%b{}", cursor)
        local ns, ne = text:find("\\[Nn]", cursor)
        if bs and (not ns or bs < ns) then
            current = current .. text:sub(cursor, be)
            cursor = be + 1
        elseif ns then
            parts[#parts+1] = current .. text:sub(cursor, ns - 1)
            current, cursor = "", ne + 1
        else
            current = current .. text:sub(cursor)
            break
        end
    end
    parts[#parts+1] = current
    return parts
end

local function joinTextParts(parts)
    local clean = {}
    for _, p in ipairs(parts) do
        local v = trimText(normalizeString(p):gsub("%s+", " "))
        if v ~= "" then clean[#clean+1] = v end
    end
    local t = table.concat(clean, " ")
    t = t:gsub("%s+", " ")
    t = t:gsub("%s+([,;:%)%.%!%?])", "%1")
    t = t:gsub("([%(])%s+", "%1")
    t = t:gsub("(" .. invExclamation .. ")%s+", "%1")
    t = t:gsub("(" .. invQuestion .. ")%s+", "%1")
    return trimText(t)
end

local function normalizeRepeatedLetters(value)
    local chars = splitUtf8Chars(value); if #chars < 3 then return value end
    local out, i = {}, 1
    while i <= #chars do
        local cur = chars[i]
        if isLetter(cur) then
            local j = i + 1
            while j <= #chars and chars[j] == cur do j = j + 1 end
            local run = j - i
            if run >= 3 then out[#out+1] = cur
            else for k = i, j - 1 do out[#out+1] = chars[k] end end
            i = j
        else
            out[#out+1] = cur; i = i + 1
        end
    end
    return table.concat(out)
end
local function stripLeadingEllipsisText(value)
    value = normalizeString(value)
    local prefix, rest = "", trimText(value)
    while startsWith(rest, invQuestion) or startsWith(rest, invExclamation) do
        local c = unicodeSub(rest, 1, 1)
        prefix = prefix .. c
        rest = trimText(unicodeSub(rest, 2))
    end
    local stripping = true
    while stripping do
        stripping = false
        local r = rest:gsub("^%.%.%.+%s*", "")
        if r ~= rest then rest = r; stripping = true end
        if startsWith(rest, horizontalEllipsis) or startsWith(rest, twoDotLeader) then
            rest = trimText(unicodeSub(rest, 2)); stripping = true
        end
    end
    return prefix .. rest
end

local auditLines, applyPreset, singleMarkerItems
local TextOperations, TagOperations, SmartOperations, TimingOperations, MarkerOperations

local function getKeyframes()
    if aegisub and type(aegisub.keyframes) == "function" then
        local ok, k = pcall(aegisub.keyframes)
        if ok and type(k) == "table" then table.sort(k); return k end
    end
    return nil
end

local function msToFrame(ms)
    if aegisub and type(aegisub.frame_from_ms) == "function" then
        local ok, f = pcall(aegisub.frame_from_ms, ms); if ok and f then return f end
    end
    return nil
end

local function frameToMs(frame)
    if aegisub and type(aegisub.ms_from_frame) == "function" then
        local ok, ms = pcall(aegisub.ms_from_frame, frame); if ok and ms then return ms end
    end
    return nil
end

local function isOnKeyframe(ms, kfs)
    if not kfs then return false end
    local f = msToFrame(ms); if not f then return false end
    for _, k in ipairs(kfs) do if k == f then return true end; if k > f then break end end
    return false
end

local function hasKeyframeNearEdge(ms, kfs, rangeMs, direction, excludeEdgeFrame)
    if not kfs or rangeMs <= 0 then return false end
    local edgeFrame = msToFrame(ms)
    if not edgeFrame then return false end
    for _, k in ipairs(kfs) do
        if not (excludeEdgeFrame and k == edgeFrame) then
            local kMs = frameToMs(k)
            if kMs then
                local dist = math.abs(kMs - ms)
                if dist <= rangeMs then
                    if direction == "KF Both" or (direction == "KF Back" and k < edgeFrame) or (direction == "KF Forward" and k > edgeFrame) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

do
local auditMarkers = {
    ["TOO-SHORT"]=true,["TOO-LONG"]=true,["ZERO-LENGTH"]=true,
    ["FAST-CPS"]=true,["SLOW-CPS"]=true,["DEFAULT-STYLE"]=true,
    ["THREE-LINES"]=true,["SHORT-LAST-LINE"]=true,["TOO-WIDE"]=true,
    ["BROKEN-TAG"]=true,["PUNCT-ERROR"]=true,["UNPAIRED-PUNCT"]=true,
    ["NO-END-PUNCT"]=true,["FINAL-COMMA"]=true,["OVERLAP"]=true,["SHORT-GAP"]=true,["LARGE-GAP"]=true,
    ["UPPERCASE"]=true,["EMPTY"]=true,["DRAWING"]=true,["DRAWING-CLIP"]=true,
    ["COMMENT"]=true,["TOO-LONG-TIME"]=true,
    ["END-ON-KF"]=true,["START-ON-KF"]=true,["NEAR-END-KF"]=true,["NEAR-START-KF"]=true,
    ["MISSED-END-KF"]=true,["MISSED-START-KF"]=true,
    ["ITALIC-ERROR"]=true,["PARENTHESES"]=true,["NAME-PREFIX"]=true,
    ["LINE-BREAK"]=true,["POSITION-TAG"]=true,["CLIP-TAG"]=true,["FADE-TAG"]=true,
    ["TRANSFORM-TAG"]=true,["KARAOKE-TAG"]=true,["COMMENT-BLOCK"]=true,["HAS-DIGITS"]=true,["HAS-CJK"]=true,
    ["FULL-ITALIC"]=true,["DOUBLE-SPACE"]=true,["EDGE-SPACE"]=true,
    ["REPLACED"]=true,["COMPLETE-SENTENCE"]=true,["POSSIBLE-JOIN"]=true,
    ["STRONG-EXCL"]=true,["STRONG-QUEST"]=true,["MIXED-EMPHASIS"]=true,["SEMICOLON"]=true,
    ["STUTTER"]=true,["SCREAM"]=true,
}

local function hasTerminalPunctuation(text)
    local chars = splitUtf8Chars(trimText(visibleText(text)))
    for i = #chars, 1, -1 do
        local c = chars[i]
        if isWhitespaceChar(c) or closingPunctuation[c] then
        else
            return terminalPunctuation[c] == true
        end
    end
    return true
end

local function hasFinalComma(text)
    local chars = splitUtf8Chars(trimText(visibleText(text)))
    for i = #chars, 1, -1 do
        local c = chars[i]
        if isWhitespaceChar(c) or closingPunctuation[c] then
        else
            return c == ","
        end
    end
    return false
end

SmartOperations = {}
SmartOperations.completeSentences = function(subs, sel)
    local function incomplete(text)
        local clean = trimText(visibleText(text))
        return clean ~= "" and (hasFinalComma(clean) or not hasTerminalPunctuation(clean))
    end
    local function startsLower(text)
        local chars = splitUtf8Chars(trimText(visibleText(text)))
        for _, c in ipairs(chars) do
            if isLetter(c) then return c == unicodeLower(c) end
        end
        return false
    end
    local function itemSort(a, b)
        if a.line.start_time == b.line.start_time then return a.index < b.index end
        return (a.line.start_time or 0) < (b.line.start_time or 0)
    end
    local function collectItems()
        local selected = {}
        for _, i in ipairs(sel or {}) do selected[i] = true end
        local all, picked = {}, {}
        for i = 1, #subs do
            local l = subs[i]
            if isEditableDialogue(l) and not isVectorDrawing(l) and l.start_time and l.end_time then
                local item = { index = i, line = l, selected = selected[i] == true }
                all[#all+1] = item
                if item.selected then picked[#picked+1] = item end
            end
        end
        table.sort(all, itemSort); table.sort(picked, itemSort)
        return all, picked
    end
    local function blockers(all, first, second)
        local out, spanStart, spanEnd = {}, first.line.start_time, second.line.end_time
        if second.line.start_time < spanStart then spanStart = second.line.start_time end
        if first.line.end_time > spanEnd then spanEnd = first.line.end_time end
        for _, item in ipairs(all) do
            if item.index ~= first.index and item.index ~= second.index then
                local s, e = item.line.start_time or 0, item.line.end_time or 0
                if s < spanEnd and e > spanStart then out[#out+1] = item.index end
            end
        end
        return out
    end
    local function markSuspect(first, second, extra)
        local marked = {}
        local function mark(index)
            if marked[index] or not isDialogue(subs[index]) then return end
            marked[index] = true
            local line = cloneLine(subs[index])
            addEffectMarker(line, "[POSSIBLE-JOIN]")
            subs[index] = line
        end
        mark(first.index); mark(second.index)
        for _, idx in ipairs(extra or {}) do mark(idx) end
    end
    local function applyJoin(action)
        local first, second = subs[action.first], subs[action.second]
        local merged = cloneLine(first)
        local p1 = stripComments(stripTags(first.text))
        local p2 = stripComments(stripTags(second.text))
        merged.end_time = math.max(first.end_time or 0, second.end_time or 0)
        merged.text = extractLeadingTagBlocks(first.text) .. joinTextParts({ p1, p2 })
        addEffectMarker(merged, "[COMPLETE-SENTENCE]")
        subs[action.first] = merged
        subs.delete(action.second)
    end
    sel = collectEditableTextSelection(subs, sel)
    if #sel < 2 then return sel end
    local all, picked = collectItems()
    local actions, deleteSet, used = {}, {}, {}
    for pos = 1, #picked - 1 do
        local first, second = picked[pos], picked[pos + 1]
        if not used[first.index] and not used[second.index] and incomplete(first.line.text) then
            local extra = blockers(all, first, second)
            local overlaps = (second.line.start_time or 0) < (first.line.end_time or 0)
            local canJoin = #extra == 0 and not overlaps and first.index < second.index and startsLower(second.line.text)
            if canJoin then
                actions[#actions+1] = { first = first.index, second = second.index }
                used[first.index], used[second.index] = true, true
            else
                markSuspect(first, second, extra)
            end
        end
    end
    table.sort(actions, function(a, b) return a.second > b.second end)
    for _, action in ipairs(actions) do applyJoin(action); deleteSet[action.second] = true end
    return #actions > 0 and remapSelectionAfterDeletion(subs, sel, deleteSet) or sel
end

local function hasPunctuationBalanceIssue(text)
    local v = visibleText(text)
    if countChar(v, invQuestion)        ~= countChar(v, "?")             then return true end
    if countChar(v, invExclamation)     ~= countChar(v, "!")             then return true end
    if countChar(v, "(")                 ~= countChar(v, ")")             then return true end
    if countChar(v, "[")                 ~= countChar(v, "]")             then return true end
    if countChar(v, "\"") % 2 ~= 0 then return true end
    if countChar(v, leftDoubleQuote)   ~= countChar(v, rightDoubleQuote) then return true end
    if countChar(v, leftSingleQuote)   ~= countChar(v, rightSingleQuote) then return true end
    return countChar(v, leftGuillemet)  ~= countChar(v, rightGuillemet)
end

local function hasOrphanTag(text)
    text = normalizeString(text)
    if text:find("{}", 1, true) ~= nil or text:find("{\\}", 1, true) ~= nil or text:match("{%s*}") ~= nil then return true end
    local depth = 0
    for c in text:gmatch("[{}]") do
        if c == "{" then
            if depth > 0 then return true end
            depth = 1
        else
            if depth == 0 then return true end
            depth = 0
        end
    end
    return depth ~= 0
end

local function getLineWidth(text, style)
    local clean = visibleText(text)
    if aegisub and type(aegisub.text_extents) == "function" and type(style) == "table" then
        local ok, w = pcall(function() return aegisub.text_extents(style, clean) end)
        if ok and type(w) == "number" then return w end
    end
    return unicodeLenSafe(clean) * 15
end

local function hasDoubleItalics(text)
    text = normalizeString(text)
    local hasI1, hasI0 = false, false
    for block in text:gmatch("{([^}]*)}") do
        if block:sub(1, 1) == "\\" or block:find("^%s*\\") then
            if block:find("\\i1%f[%D]") then hasI1 = true end
            if block:find("\\i0%f[%D]") then hasI0 = true end
        end
    end
    return hasI1 and hasI0
end

local function hasParenthesesPair(text)
    local clean = visibleText(text)
    return clean:find("%(") ~= nil and clean:find("%)") ~= nil
end

local function hasNamePrefix(text)
    return visibleText(text):match("^%[.-%]:") ~= nil
end

local function hasLineBreakTag(text) return #splitTextAtLinebreaks(text) > 1 end
local function hasPosTag(text)        return hasOverridePattern(text, "\\pos%(") or hasOverridePattern(text, "\\move%(") end
local function hasClipTag(text)       return hasOverridePattern(text, "\\i?clip%(") end
local function hasFadeTag(text)       return hasOverridePattern(text, "\\fade?%(") end
local function hasTransformTag(text)  return hasOverridePattern(text, "\\t%(") end
local function hasKaraokeTag(text)    return hasOverridePattern(text, "\\[kK][fo]?%d") end
local function hasCommentBlock(text)
    text = normalizeString(text)
    for block in text:gmatch("{([^}]*)}") do
        local trimmed = block:gsub("^%s+", "")
        if trimmed ~= "" and trimmed:sub(1,1) ~= "\\" then return true end
    end
    return false
end
local function hasNumeric(text)         return visibleText(text):find("%d") ~= nil end
local function hasDoubleSpaceText(text) return stripComments(stripTags(text)):find("[ \t][ \t]") ~= nil end
local function hasEdgeSpace(text)
    local s = stripComments(stripTags(text)); if s == "" then return false end
    return s:match("^[ \t]") ~= nil or s:match("[ \t]$") ~= nil
end
local function hasCJKChars(text) return visibleText(text):find("[\227-\237]") ~= nil end

local function wordHasAny(word, needles)
    for _, n in ipairs(needles) do if word:find(n, 1, true) then return true end end
    return false
end

local function hasStrongExclamation(text)
    local clean = visibleText(text)
    for word in clean:gmatch("%S+") do
        if wordHasAny(word, { invExclamation }) and wordHasAny(word, { "!", fullwidthExclamation }) then
            return true
        end
    end
    return false
end

local function hasStrongQuestion(text)
    local clean = visibleText(text)
    for word in clean:gmatch("%S+") do
        if wordHasAny(word, { invQuestion }) and wordHasAny(word, { "?", fullwidthQuestion }) then
            return true
        end
    end
    return false
end

local function hasMixedEmphasis(text)
    local clean = visibleText(text)
    for word in clean:gmatch("%S+") do
        local hasOpenE = wordHasAny(word, { invExclamation })
        local hasOpenQ = wordHasAny(word, { invQuestion })
        local hasCloseE = wordHasAny(word, { "!", fullwidthExclamation })
        local hasCloseQ = wordHasAny(word, { "?", fullwidthQuestion })
        if (hasOpenE and hasOpenQ) or (hasCloseE and hasCloseQ) then return true end
    end
    return false
end

local function hasSemicolon(text)
    local clean = visibleText(text)
    return clean:find(";", 1, true) ~= nil or clean:find(fullwidthSemicolon, 1, true) ~= nil
end

local function hasStutter(text)
    local clean = visibleText(text)
    for word in clean:gmatch("%S+") do
        local chars = splitUtf8Chars(word)
        for i = 1, #chars - 2 do
            if chars[i+1] == "-" and isLetter(chars[i]) and isLetter(chars[i+2])
               and unicodeLower(chars[i]) == unicodeLower(chars[i+2]) then
                return true
            end
        end
    end
    return false
end

local function isFullItalic(text)
    text = normalizeString(text)
    local first = text:match("^{([^}]*)}")
    if not first or not first:find("\\i1") then return false end
    for block in text:gmatch("{([^}]*)}") do
        if block:find("\\i0") then return false end
    end
    return true
end

local function countSentences(text)
    local clean = visibleText(text)
    local chars = splitUtf8Chars(clean)
    local count, i = 0, 1
    while i <= #chars do
        local c = chars[i]
        local isEnd = (c == "." or c == "?" or c == "!" or c == horizontalEllipsis)
        if isEnd then
            count = count + 1
            while i + 1 <= #chars do
                local nx = chars[i + 1]
                if nx == "." or nx == "?" or nx == "!" or nx == horizontalEllipsis or closingPunctuation[nx] then
                    i = i + 1
                else break end
            end
        end
        i = i + 1
    end
    if count == 0 and #chars > 0 then count = 1 end
    return count
end

local function isUppercaseText(text)
    local letters = 0
    for _, c in ipairs(splitUtf8Chars(visibleText(text))) do
        if isLetter(c) then
            letters = letters + 1
            if c ~= unicodeUpper(c) then return false end
        end
    end
    return letters >= 2
end

local function cleanAuditMarkers(effect)
    effect = normalizeString(effect)
    effect = effect:gsub("%[([^%]]+)%]", function(key)
        local base = key:match("^(%S+)") or key
        if auditMarkers[base] or key:match("^%d+%-SENTENCES$") then return " " end
        return "[" .. key .. "]"
    end)
    return trimText(effect:gsub("%s+", " "))
end

local function auditMarkerKey(marker)
    marker = normalizeString(marker)
    local key = marker:match("^%[([^%]]+)%]$") or marker
    return key:match("^(%S+)") or key
end

local function gapMarker(kind, gap)
    return string.format("[%s %dms]", kind, math.floor((tonumber(gap) or 0) + 0.5))
end

local function applyIssues(line, issues, clearOld, allowDuplicate)
    local effect = clearOld and cleanAuditMarkers(line.effect) or normalizeString(line.effect)
    local seen, existingCounts = {}, {}
    effect:gsub("%[([^%]]+)%]", function(k)
        local key = auditMarkerKey(k)
        seen[key] = true
        existingCounts[key] = (existingCounts[key] or 0) + 1
    end)
    local issueCounts = {}
    for _, marker in ipairs(issues) do
        local key = auditMarkerKey(marker)
        if key ~= "" then issueCounts[key] = (issueCounts[key] or 0) + 1 end
    end
    local markers = {}
    for _, marker in ipairs(issues) do
        local key = auditMarkerKey(marker)
        if key ~= "" then
            if allowDuplicate and allowDuplicate[key] then
                local existing = existingCounts[key] or 0
                if issueCounts[key] > existing then
                    markers[#markers+1] = marker
                    existingCounts[key] = existing + 1
                end
            elseif not seen[key] then
                markers[#markers+1] = marker
                seen[key] = true
            end
        end
    end
    local prefix = table.concat(markers, " ")
    if prefix ~= "" and effect ~= "" then line.effect = prefix .. " " .. effect
    elseif prefix ~= "" then               line.effect = prefix
    else                                   line.effect = effect end
end

local function addIssue(issues, marker) issues[#issues+1] = marker end

local function collectHead(subs)
    if karaskel and type(karaskel.collect_head) == "function" then
        local ok, meta, styles = pcall(karaskel.collect_head, subs, false)
        if ok then return meta, styles or {} end
    end
    return nil, {}
end
local function preprocLine(subs, meta, styles, line)
    if karaskel and type(karaskel.preproc_line) == "function" then
        pcall(karaskel.preproc_line, subs, meta, styles, line)
    end
end

local function buildAdjacentSelection(subs, sel)
    local selected = {}
    for _, i in ipairs(sel) do selected[i] = true end
    local items = {}
    for i = 1, #subs do
        local l = subs[i]
        if isEditableDialogue(l) and l.start_time and l.end_time then
            items[#items+1] = { index = i, line = l, selected = selected[i] == true }
        end
    end
    table.sort(items, function(a, b)
        if a.line.start_time == b.line.start_time then return a.index < b.index end
        return (a.line.start_time or 0) < (b.line.start_time or 0)
    end)
    return items
end

singleMarkerItems = {
    "", "Number Effects","Add Identifier",
    "UPPERCASE","THREE-LINES","NO-END-PUNCT","FINAL-COMMA","UNPAIRED-PUNCT",
    "SHORT-LAST-LINE","TOO-WIDE","BROKEN-TAG","OVERLAP","DEFAULT-STYLE",
    "ITALIC-ERROR","PARENTHESES","NAME-PREFIX","MULTI-SENTENCE",
    "STRONG-EXCL","STRONG-QUEST","MIXED-EMPHASIS","SEMICOLON","STUTTER",
    "LINE-BREAK","POSITION-TAG","CLIP-TAG","DRAWING-CLIP","FADE-TAG","TRANSFORM-TAG","KARAOKE-TAG",
    "COMMENT-BLOCK","HAS-DIGITS","HAS-CJK","FULL-ITALIC","DOUBLE-SPACE","EDGE-SPACE",
}
local singleToChecks = {
    ["UPPERCASE"]={"check_uppercase"},     ["THREE-LINES"]={"check_3liner"},
    ["NO-END-PUNCT"]={"check_missing_punct"}, ["FINAL-COMMA"]={"check_final_comma"},
    ["UNPAIRED-PUNCT"]={"check_punct_balance"},
    ["SHORT-LAST-LINE"]={"check_orphan_word"}, ["BROKEN-TAG"]={"check_orphan_tag"},
    ["OVERLAP"]={"check_overlap"},         ["DEFAULT-STYLE"]={"check_unstyled"},
    ["ITALIC-ERROR"]={"check_double_italics"},     ["PARENTHESES"]={"check_parentheses"},
    ["NAME-PREFIX"]={"check_name_prefix"},        ["MULTI-SENTENCE"]={"check_sentences"},
    ["TOO-WIDE"]={"check_needs_split"},
    ["STRONG-EXCL"]={"check_strong_excl"}, ["STRONG-QUEST"]={"check_strong_quest"},
    ["MIXED-EMPHASIS"]={"check_mixed_emphasis"}, ["SEMICOLON"]={"check_semicolon"},
    ["STUTTER"]={"check_stutter"},
    ["LINE-BREAK"]={"check_has_n"},   ["POSITION-TAG"]={"check_has_pos"},
    ["CLIP-TAG"]={"check_has_clip"}, ["DRAWING-CLIP"]={"check_draw_clip"}, ["FADE-TAG"]={"check_has_fad"},
    ["TRANSFORM-TAG"]={"check_has_t"},   ["KARAOKE-TAG"]={"check_has_k"},
    ["COMMENT-BLOCK"]={"check_has_comment"}, ["HAS-DIGITS"]={"check_has_num"},
    ["HAS-CJK"]={"check_has_cjk"}, ["FULL-ITALIC"]={"check_full_italic"},
    ["DOUBLE-SPACE"]={"check_dbl_space"}, ["EDGE-SPACE"]={"check_edge_space"},
}
local function applySingleMarkerOverride(config)
    local sm = config.single_marker; if not sm or sm == "" then return end
    local allChecks = {
        "check_uppercase","check_3liner","check_missing_punct","check_final_comma","check_punct_balance",
        "check_orphan_word","check_orphan_tag","check_overlap","check_unstyled",
        "check_double_italics","check_parentheses","check_name_prefix","check_sentences",
        "check_needs_split","check_empty",
        "check_strong_excl","check_strong_quest","check_mixed_emphasis","check_semicolon","check_stutter",
        "check_has_n","check_has_pos","check_has_clip","check_has_fad",
        "check_has_t","check_has_k","check_has_comment","check_has_num",
        "check_has_cjk","check_full_italic","check_dbl_space","check_edge_space","check_draw_clip",
    }
    for _, k in ipairs(allChecks) do config[k] = false end
    config.short_ms = 0
    config.long_ms = 0
    config.overtime_ms = 0
    config.max_cps = 0
    config.min_cps = 0
    config.gap_ms = 0
    config.large_gap_ms = 0
    config.kf_seal = false
    config.twin_kf_ms = 0
    config.miss_kf_ms = 0
    config.kf_dir = ""
    local checks = singleToChecks[sm]
    if checks then for _, k in ipairs(checks) do config[k] = true end end
end

local function presetNumber(key)
    return tonumber(currentConfig and currentConfig[key]) or tonumber(defaultConfig[key]) or 0
end

function applyPreset(result, preset)
    result.short_ms = 0; result.long_ms = 0; result.overtime_ms = 0
    result.min_cps = 0; result.max_cps = 0; result.gap_ms = 0; result.large_gap_ms = 0
    result.max_width = 0
    result.kf_seal = false; result.twin_kf_ms = 0; result.miss_kf_ms = 0; result.kf_mode = ""; result.kf_dir = ""
    result.check_uppercase=false; result.check_3liner=false; result.check_missing_punct=false; result.check_final_comma=false
    result.check_punct_balance=false; result.check_orphan_word=false; result.check_orphan_tag=false
    result.check_overlap=false; result.check_unstyled=false; result.check_double_italics=false
    result.check_parentheses=false; result.check_name_prefix=false; result.check_sentences=false
    result.check_needs_split=false; result.check_empty=false; result.check_dbl_space=false; result.check_edge_space=false
    result.check_strong_excl=false; result.check_strong_quest=false; result.check_mixed_emphasis=false; result.check_semicolon=false
    result.check_stutter=false
    if preset == "Ends Only" then
        result.twin_kf_ms = presetNumber("preset_end_twin_ms"); result.miss_kf_ms = presetNumber("preset_end_miss_ms"); result.kf_mode = "End Only"; result.kf_dir = "KF Back"
    elseif preset == "Start Only" then
        result.twin_kf_ms = presetNumber("preset_start_twin_ms"); result.miss_kf_ms = presetNumber("preset_start_miss_ms"); result.kf_mode = "Start Only"; result.kf_dir = "KF Back"
    elseif preset == "Full Audit" then
        result.twin_kf_ms = presetNumber("preset_full_twin_ms"); result.miss_kf_ms = presetNumber("preset_full_miss_ms"); result.kf_mode = "Both"; result.kf_dir = "KF Back"
        result.short_ms = presetNumber("preset_full_short_ms"); result.long_ms = presetNumber("preset_full_long_ms"); result.max_cps = presetNumber("preset_full_max_cps"); result.gap_ms = presetNumber("preset_full_short_gap_ms"); result.large_gap_ms = presetNumber("preset_full_large_gap_ms"); result.max_width = presetNumber("preset_full_max_width")
        result.check_uppercase = true;     result.check_3liner = true
        result.check_missing_punct = true; result.check_punct_balance = true
        result.check_orphan_word = true;   result.check_orphan_tag = true
        result.check_overlap = true;       result.check_unstyled = true
        result.check_double_italics = true;result.check_parentheses = true
        result.check_name_prefix = true;   result.check_sentences = true
        result.check_needs_split = true;   result.check_empty = true
        result.check_dbl_space = true;     result.check_edge_space = true
    elseif preset == "Overtime" then
        result.overtime_ms = presetNumber("preset_overtime_ms")
    elseif preset == "Duration" then
        result.short_ms = presetNumber("preset_duration_short_ms"); result.long_ms = presetNumber("preset_duration_long_ms")
    elseif preset == "CPS" then
        result.max_cps = presetNumber("preset_cps_max")
    elseif preset == "Short Gaps" then
        result.gap_ms = presetNumber("preset_gap_short_ms")
    elseif preset == "Large Gaps" then
        result.large_gap_ms = presetNumber("preset_gap_large_ms")
    elseif preset == "Both Gaps" or preset == "Gaps" then
        result.gap_ms = presetNumber("preset_gap_short_ms"); result.large_gap_ms = presetNumber("preset_gap_large_ms")
    end
    return result
end

function auditLines(subs, sel, config)
    config = config or {}
    if config.single_marker == "Number Effects" then
        MarkerOperations.numberEffects(subs, sel)
        return
    elseif config.single_marker == "Add Identifier" then
        MarkerOperations.randomEffects(subs, sel)
        return
    end
    config.gap_ms      = math.max(normalizeNumber(config.gap_ms) or 0, 0)
    config.large_gap_ms= math.max(normalizeNumber(config.large_gap_ms) or 0, 0)
    config.short_ms    = tonumber(config.short_ms)    or 0
    config.long_ms     = tonumber(config.long_ms)     or 0
    config.max_cps     = tonumber(config.max_cps)     or 0
    config.min_cps     = tonumber(config.min_cps)     or 0
    config.max_width   = tonumber(config.max_width)   or 0
    config.clear_old   = config.clear_old ~= false
    config.overtime_ms = tonumber(config.overtime_ms) or 0
    config.twin_kf_ms  = tonumber(config.twin_kf_ms)  or 0
    config.miss_kf_ms  = tonumber(config.miss_kf_ms)  or 0
    config.kf_seal     = config.kf_seal or false
    config.kf_mode     = config.kf_mode or ""
    config.kf_dir      = config.kf_dir or ""
    config.gap_mark_continuous = config.gap_mark_continuous or false
    config.gap_ignore_kf       = config.gap_ignore_kf       or false

    applySingleMarkerOverride(config)

    local meta, styles = collectHead(subs)
    local kfs = getKeyframes()
    local activeKfMode = config.kf_mode ~= "" and config.kf_mode or ((config.kf_seal or config.twin_kf_ms > 0 or config.miss_kf_ms > 0) and "Both" or "")
    local activeKfDir = config.kf_dir ~= "" and config.kf_dir or "KF Back"
    local checkEnd   = (activeKfMode == "End Only"   or activeKfMode == "Both")
    local checkStart = (activeKfMode == "Start Only" or activeKfMode == "Both")
    local stats, linesWithIssues = {}, 0
    local selectedSet, issueMap = {}, {}
    for _, index in ipairs(sel) do selectedSet[index] = true; issueMap[index] = {} end
    local relationalMarkers = { ["OVERLAP"]=true, ["SHORT-GAP"]=true, ["LARGE-GAP"]=true }
    local function queueIssue(index, marker)
        if selectedSet[index] then
            issueMap[index] = issueMap[index] or {}
            issueMap[index][#issueMap[index]+1] = marker
        end
    end
    local function queueIssues(index, issues)
        for _, marker in ipairs(issues) do queueIssue(index, marker) end
    end

    for _, index in ipairs(sel) do
        local line = subs[index]
        if isDialogue(line) then
            preprocLine(subs, meta, styles, line)
            local issues = {}
            local duration = (tonumber(line.end_time) or 0) - (tonumber(line.start_time) or 0)

            if line.comment then
                addIssue(issues, "[COMMENT]")
                queueIssues(index, issues)
            else
                local drawing = isVectorDrawing(line)
                local clean = visibleText(line.text)

                if duration <= 0 then
                    addIssue(issues, "[ZERO-LENGTH]")
                elseif not drawing then
                    if config.short_ms > 0 and duration < config.short_ms then addIssue(issues, "[TOO-SHORT]") end
                    if config.long_ms > 0 and duration > config.long_ms  then addIssue(issues, "[TOO-LONG]")  end
                    if config.overtime_ms > 0 and duration > config.overtime_ms then
                        addIssue(issues, "[TOO-LONG-TIME]")
                    end
                    local cps = countCharacters(line.text) / (duration / 1000)
                    if config.max_cps > 0 and cps > config.max_cps then addIssue(issues, "[FAST-CPS]") end
                    if config.min_cps > 0 and cps < config.min_cps then addIssue(issues, "[SLOW-CPS]") end
                end

                if kfs then
                    if config.kf_seal then
                        if checkEnd   and isOnKeyframe(line.end_time,   kfs) then addIssue(issues, "[END-ON-KF]") end
                        if checkStart and isOnKeyframe(line.start_time, kfs) then addIssue(issues, "[START-ON-KF]") end
                    end
                    if config.twin_kf_ms > 0 then
                        if checkEnd and isOnKeyframe(line.end_time, kfs) then
                            if hasKeyframeNearEdge(line.end_time, kfs, config.twin_kf_ms, activeKfDir, true) then addIssue(issues, "[NEAR-END-KF]") end
                        end
                        if checkStart and isOnKeyframe(line.start_time, kfs) then
                            if hasKeyframeNearEdge(line.start_time, kfs, config.twin_kf_ms, activeKfDir, true) then addIssue(issues, "[NEAR-START-KF]") end
                        end
                    end
                    if config.miss_kf_ms > 0 then
                        if checkEnd and not isOnKeyframe(line.end_time, kfs) then
                            if hasKeyframeNearEdge(line.end_time, kfs, config.miss_kf_ms, activeKfDir, false) then addIssue(issues, "[MISSED-END-KF]") end
                        end
                        if checkStart and not isOnKeyframe(line.start_time, kfs) then
                            if hasKeyframeNearEdge(line.start_time, kfs, config.miss_kf_ms, activeKfDir, false) then addIssue(issues, "[MISSED-START-KF]") end
                        end
                    end
                end

                if not drawing and normalizeString(line.style) == "Default" then
                    if config.check_unstyled ~= false then addIssue(issues, "[DEFAULT-STYLE]") end
                end

                if drawing then
                    addIssue(issues, "[DRAWING]")
                    if config.check_draw_clip and hasClipTag(line.text) then addIssue(issues, "[DRAWING-CLIP]") end
                else
                    if trimText(clean) == "" then
                        if config.check_empty ~= false then addIssue(issues, "[EMPTY]") end
                    else
                        if config.check_uppercase ~= false and isUppercaseText(clean) then addIssue(issues, "[UPPERCASE]") end
                        if config.check_missing_punct ~= false and not hasTerminalPunctuation(clean) then addIssue(issues, "[NO-END-PUNCT]") end
                        if config.check_final_comma == true and hasFinalComma(clean) then addIssue(issues, "[FINAL-COMMA]") end
                    end

                    local parts = splitTextAtLinebreaks(line.text)
                    if #parts >= 3 then
                        if config.check_3liner ~= false then addIssue(issues, "[THREE-LINES]") end
                    elseif #parts == 2 then
                        local lastPart = parts[#parts]
                        if config.check_orphan_word ~= false and (countWords(lastPart) <= 1 or countCharacters(lastPart) < 4) then
                            addIssue(issues, "[SHORT-LAST-LINE]")
                        end
                    else
                        local style = line.styleref or styles[normalizeString(line.style)] or line.style
                        if config.max_width > 0 and getLineWidth(line.text, style) > config.max_width then
                            if config.check_needs_split ~= false then addIssue(issues, "[TOO-WIDE]") end
                        end
                    end

                    if config.check_orphan_tag    ~= false and hasOrphanTag(line.text)         then addIssue(issues, "[BROKEN-TAG]") end
                    if config.check_punct_balance ~= false and hasPunctuationBalanceIssue(line.text) then addIssue(issues, "[UNPAIRED-PUNCT]") end
                    if config.check_double_italics ~= false and hasDoubleItalics(line.text)    then addIssue(issues, "[ITALIC-ERROR]") end
                    if config.check_parentheses    ~= false and hasParenthesesPair(line.text)  then addIssue(issues, "[PARENTHESES]") end
                    if config.check_name_prefix    ~= false and hasNamePrefix(line.text)       then addIssue(issues, "[NAME-PREFIX]") end
                    if config.check_sentences      ~= false then
                        local sc = countSentences(clean)
                        if sc >= 2 then addIssue(issues, "[" .. sc .. "-SENTENCES]") end
                    end

                    if config.check_has_n     and hasLineBreakTag(line.text) then addIssue(issues, "[LINE-BREAK]") end
                    if config.check_has_pos   and hasPosTag(line.text)       then addIssue(issues, "[POSITION-TAG]") end
                    if config.check_has_clip  and hasClipTag(line.text)      then addIssue(issues, "[CLIP-TAG]") end
                    if config.check_has_fad   and hasFadeTag(line.text)      then addIssue(issues, "[FADE-TAG]") end
                    if config.check_has_t     and hasTransformTag(line.text) then addIssue(issues, "[TRANSFORM-TAG]") end
                    if config.check_has_k     and hasKaraokeTag(line.text)   then addIssue(issues, "[KARAOKE-TAG]") end
                    if config.check_has_comment and hasCommentBlock(line.text) then addIssue(issues, "[COMMENT-BLOCK]") end
                    if config.check_has_num   and hasNumeric(line.text)      then addIssue(issues, "[HAS-DIGITS]") end
                    if config.check_has_cjk   and hasCJKChars(line.text)     then addIssue(issues, "[HAS-CJK]") end
                    if config.check_full_italic and isFullItalic(line.text)  then addIssue(issues, "[FULL-ITALIC]") end

                    if config.check_dbl_space  ~= false and hasDoubleSpaceText(line.text) then addIssue(issues, "[DOUBLE-SPACE]") end
                    if config.check_edge_space ~= false and hasEdgeSpace(line.text)       then addIssue(issues, "[EDGE-SPACE]") end

                    if config.check_strong_excl     and hasStrongExclamation(clean) then addIssue(issues, "[STRONG-EXCL]") end
                    if config.check_strong_quest    and hasStrongQuestion(clean)    then addIssue(issues, "[STRONG-QUEST]") end
                    if config.check_mixed_emphasis  and hasMixedEmphasis(clean)     then addIssue(issues, "[MIXED-EMPHASIS]") end
                    if config.check_semicolon       and hasSemicolon(line.text)     then addIssue(issues, "[SEMICOLON]") end
                    if config.check_stutter         and hasStutter(clean)           then addIssue(issues, "[STUTTER]") end
                end

                queueIssues(index, issues)
            end
        end
    end

    local adjacent = buildAdjacentSelection(subs, sel)
    if config.check_overlap ~= false then
        local selectedTiming, overlapSet = {}, {}
        for _, item in ipairs(adjacent) do
            if item.selected and validateDuration(item.line) then selectedTiming[#selectedTiming+1] = item end
        end
        for i = 1, #selectedTiming - 1 do
            local prev = selectedTiming[i]
            local prevEnd = tonumber(prev.line.end_time) or 0
            for j = i + 1, #selectedTiming do
                local line = selectedTiming[j]
                if (tonumber(line.line.start_time) or 0) >= prevEnd then break end
                overlapSet[prev.index] = true
                overlapSet[line.index] = true
            end
        end
        for index in pairs(overlapSet) do queueIssue(index, "[OVERLAP]") end
    end
    for i = 1, #adjacent - 1 do
        local prev, line = adjacent[i], adjacent[i + 1]
        if prev.selected or line.selected then
            local gap = (tonumber(line.line.start_time) or 0) - (tonumber(prev.line.end_time) or 0)
            if gap == 0 and config.gap_mark_continuous then
                local marker = gapMarker("SHORT-GAP", gap)
                queueIssue(prev.index, marker)
                queueIssue(line.index, marker)
            elseif config.gap_ms > 0 and gap > 0 and gap <= config.gap_ms then
                if not (config.gap_ignore_kf and kfs and isOnKeyframe(prev.line.end_time, kfs)) then
                    local marker = gapMarker("SHORT-GAP", gap)
                    queueIssue(prev.index, marker)
                    queueIssue(line.index, marker)
                end
            elseif config.large_gap_ms > 0 and gap > config.large_gap_ms then
                local marker = gapMarker("LARGE-GAP", gap)
                queueIssue(prev.index, marker)
                queueIssue(line.index, marker)
            end
        end
    end

    for _, index in ipairs(sel) do
        local issues = issueMap[index] or {}
        if #issues > 0 and isDialogue(subs[index]) then
            linesWithIssues = linesWithIssues + 1
            for _, iss in ipairs(issues) do stats[iss] = (stats[iss] or 0) + 1 end
            local line = subs[index]
            applyIssues(line, issues, config.clear_old, relationalMarkers)
            subs[index] = line
        end
    end

    local statList = {}
    for marker, count in pairs(stats) do table.insert(statList, marker .. ": " .. count) end
    table.sort(statList)
    local msg = string.format(L("msg_audit_done"), #sel, linesWithIssues,
                              #statList > 0 and table.concat(statList, "\n") or "—")
    showMsg(msg)
end

end

do
TextOperations   = {}
TagOperations    = {}
TimingOperations = {}
MarkerOperations = {}

local function remapSelectionAfterInsertion(originalSel, insertedByIndex)
    local asc = {}
    for _, v in ipairs(originalSel or {}) do asc[#asc+1] = v end
    table.sort(asc)
    local newSel, shift = {}, 0
    for _, i in ipairs(asc) do
        local n = insertedByIndex[i] or 0
        for k = 0, n do newSel[#newSel+1] = i + shift + k end
        shift = shift + n
    end
    return newSel
end

function MarkerOperations.appendEffectText(line, value)
    value = trimText(value)
    if value == "" then return end
    local effect = trimText(line.effect)
    line.effect = effect == "" and value or effect .. " " .. value
end

function MarkerOperations.effectNumber(line)
    local effect = normalizeString(line and line.effect or "")
    for sign, num in effect:gmatch("(%-?)(%d+)") do
        if #num ~= 14 then return tonumber(sign .. num) end
    end
    return nil
end

function MarkerOperations.effectRandomNumber(line)
    return normalizeString(line and line.effect or ""):match("%f[%d](%d%d%d%d%d%d%d%d%d%d%d%d%d%d)%f[%D]")
end

function MarkerOperations.normalizeEffectTagSeparators(tags)
    return normalizeString(tags):gsub("%b{}", function(block)
        if block:match("^%{%s*\\") then return block:gsub(";", ",") end
        return block
    end)
end

local function hasVisibleSegmentText(text)
    local clean = stripComments(stripTags(text)):gsub("\\N", " ")
    for _, c in ipairs(splitUtf8Chars(clean)) do
        if not isWhitespaceChar(c) then return true end
    end
    return false
end

local function ensureInheritedTags(segment, tags)
    segment = trimText(segment); tags = normalizeString(tags)
    if segment == "" then return "" end
    if tags ~= "" and not startsWith(segment, tags) then return tags .. segment end
    return segment
end

local function caseTextForSelection(subs, sel, mode)
    for _, index in ipairs(sel) do
        local line = subs[index]
        local inWord, pending, done = false, true, false
        mutateTextSections(line, function(value)
            local chars, i = splitUtf8Chars(value), 1
            while i <= #chars do
                local c = chars[i]
                if c == "\\" and chars[i+1] and chars[i+1]:match("^[Nnh]$") then
                    inWord = false
                    i = i + 2
                else
                    if isLetter(c) then
                        if mode == "upper" then chars[i] = unicodeUpper(c)
                        elseif mode == "lower" then chars[i] = unicodeLower(c)
                        elseif mode == "title" then chars[i] = not inWord and unicodeUpper(c) or unicodeLower(c)
                        elseif mode == "sentence" then chars[i] = pending and unicodeUpper(c) or unicodeLower(c)
                        elseif not done then chars[i] = mode == "first_upper" and unicodeUpper(c) or unicodeLower(c) end
                        inWord, pending, done = true, false, true
                    else
                        if isWhitespaceChar(c) or isPunctuationChar(c) then inWord = false end
                        if sentenceSplitChars[c] then pending = true
                        elseif not isWhitespaceChar(c) and not isPunctuationChar(c) then pending = false end
                    end
                    i = i + 1
                end
            end
            return table.concat(chars)
        end)
        subs[index] = line
    end
end

local function changeFirstLetter(value, upper)
    local chars = splitUtf8Chars(value)
    for i, c in ipairs(chars) do
        if isLetter(c) then
            chars[i] = upper and unicodeUpper(c) or unicodeLower(c)
            return table.concat(chars), true
        end
    end
    return table.concat(chars), false
end

local function addEndingEllipsisText(value)
    local tags, body = splitLeadingTagBlocks(value)
    body = trimText(body)
    local trailingTags
    body, trailingTags = splitTrailingTagBlocks(body)
    if body == "" then return value end
    local suffix, changed = "", true
    while changed do
        changed = false
        if endsWith(body, "?") or endsWith(body, "!") then
            suffix = body:sub(-1) .. suffix
            body = trimText(body:sub(1, -2))
            changed = true
        end
    end
    local stripping = true
    while stripping do
        stripping = false
        local b = body:gsub("%s*%.+%s*$", "")
        if b ~= body then body = b; stripping = true end
        if endsWith(body, horizontalEllipsis) or endsWith(body, twoDotLeader) then
            body = trimText(unicodeSub(body, 1, -2)); stripping = true
        end
    end
    return tags .. trimText(body) .. "..." .. suffix .. trailingTags
end

local function normalizeQuotesText(v)
    return normalizeString(v)
        :gsub(leftDoubleQuote,"\""):gsub(rightDoubleQuote,"\"")
        :gsub(doubleLowQuote,"\""):gsub(doubleHighReversedQuote,"\"")
        :gsub(leftGuillemet,"\""):gsub(rightGuillemet,"\"")
        :gsub(leftSingleGuillemet,"\""):gsub(rightSingleGuillemet,"\"")
        :gsub(leftSingleQuote,"'"):gsub(rightSingleQuote,"'")
        :gsub(singleLowQuote,"'"):gsub(singleHighReversedQuote,"'")
end

local function toLatinQuotesText(value)
    local chars = splitUtf8Chars(normalizeString(value))
    local out = {}
    local doubleOpen, singleOpen = false, false
    for i, ch in ipairs(chars) do
        local prev, nxt = chars[i-1], chars[i+1]
        local letterContext = prev and nxt and isLetter(prev) and isLetter(nxt)
        if ch == leftDoubleQuote or ch == doubleLowQuote then
            out[#out+1] = leftGuillemet
        elseif ch == rightDoubleQuote or ch == doubleHighReversedQuote then
            out[#out+1] = rightGuillemet
        elseif ch == leftSingleGuillemet then
            out[#out+1] = leftGuillemet
        elseif ch == rightSingleGuillemet then
            out[#out+1] = rightGuillemet
        elseif ch == leftSingleQuote or ch == singleLowQuote then
            out[#out+1] = leftGuillemet
        elseif ch == rightSingleQuote or ch == singleHighReversedQuote then
            if letterContext then out[#out+1] = "'" else out[#out+1] = rightGuillemet end
        elseif ch == "\"" then
            if doubleOpen then out[#out+1] = rightGuillemet; doubleOpen = false
            else out[#out+1] = leftGuillemet; doubleOpen = true end
        elseif ch == "'" then
            if letterContext then out[#out+1] = "'"
            elseif singleOpen then out[#out+1] = rightGuillemet; singleOpen = false
            else out[#out+1] = leftGuillemet; singleOpen = true end
        else
            out[#out+1] = ch
        end
    end
    return table.concat(out)
end

local function normalizeDashesText(v)
    v = normalizeString(v):gsub(enDash,"-"):gsub(emDash,"-"):gsub(horizontalBar,"-"):gsub(minusSign,"-")
    v = v:gsub("%s+%-%s+", " - "):gsub("%s+%-%-", "--")
    return v
end

local function toggleWrappedPunctuation(text, opening, closing)
    local tags, body = splitLeadingTagBlocks(text)
    body = trimText(body)
    if body == "" then return text end
    local trailingTags
    body, trailingTags = splitTrailingTagBlocks(body)
    if startsWith(body, opening) and endsWith(body, closing) then
        body = body:sub(#opening + 1, #body - #closing); body = trimText(body)
        if body ~= "" and not (body:match("[%.%!%?]$") or endsWith(body, horizontalEllipsis)) then
            body = body .. "."
        end
        return tags .. body .. trailingTags
    end
    if startsWith(body, opening) and not endsWith(body, closing) then
        local clean = stripTags(body):sub(#opening + 1)
        if not clean:find(closing, 1, true) then return tags .. body .. closing .. trailingTags end
        return text
    end
    if not startsWith(body, opening) and endsWith(body, closing) then
        local clean = stripTags(body); clean = clean:sub(1, #clean - #closing)
        local paired = false
        if #opening > 1 then
            for c in opening:gmatch(utf8CharPattern) do
                if clean:find(c, 1, true) then paired = true; break end
            end
        else
            if clean:find(opening, 1, true) then paired = true end
        end
        if not paired then return tags .. opening .. trimText(body) .. trailingTags end
        return text
    end
    if not body:match("%.%.%s*$") and not endsWith(trimText(body), horizontalEllipsis) then
        body = body:gsub("%.%s*$", "")
    end
    return tags .. opening .. trimText(body) .. closing .. trailingTags
end

function TextOperations.toggleAlignment(subs, sel)
    for _, i in ipairs(sel) do
        local line = subs[i]; local text = normalizeString(line.text)
        if hasOverridePattern(text, "\\an8") then
            text = removeOverridePattern(text, "\\an8")
        else
            text = removeOverridePattern(text, "\\an%d")
            local applied = false
            text = mutateOverrideBlocks(text, function(block)
                if applied then return block end
                local inner = block:sub(2, -2); inner = "\\an8" .. inner
                applied = true; return "{" .. inner .. "}"
            end)
            if not applied then text = insertOverrideAfterLeadingComments(text, "{\\an8}") end
        end
        line.text = text; subs[i] = line
    end
end

function TextOperations.toggleItalics(subs, sel)
    for _, i in ipairs(sel) do
        local line = subs[i]; local text = normalizeString(line.text)
        if hasOverridePattern(text, "\\i1") then
            text = removeOverridePattern(text, "\\i[01]")
        else
            local applied = false
            text = mutateOverrideBlocks(text, function(block)
                if applied then return block end
                local inner = block:sub(2, -2)
                if inner:match("\\i%d") then inner = inner:gsub("\\i%d", "\\i1", 1)
                else inner = inner .. "\\i1" end
                applied = true; return "{" .. inner .. "}"
            end)
            if not applied then text = insertOverrideAfterLeadingComments(text, "{\\i1}") end
        end
        line.text = text; subs[i] = line
    end
end

function TextOperations.toUppercase(subs, sel) caseTextForSelection(subs, sel, "upper") end
function TextOperations.toLowercase(subs, sel) caseTextForSelection(subs, sel, "lower") end
function TextOperations.toTitleCase(subs, sel) caseTextForSelection(subs, sel, "title") end
function TextOperations.toSentenceCase(subs, sel) caseTextForSelection(subs, sel, "sentence") end
function TextOperations.capitalizeFirst(subs, sel) caseTextForSelection(subs, sel, "first_upper") end
function TextOperations.lowercaseFirst(subs, sel) caseTextForSelection(subs, sel, "first_lower") end

function TextOperations.formatEllipsis(subs, sel)
    for _, i in ipairs(sel) do
        local l = subs[i]
        mutateTextSections(l, function(t)
            t = t:gsub(horizontalEllipsis, "...")
            t = t:gsub(twoDotLeader, "...")
            t = t:gsub("%.%.+", "...")
            t = t:gsub("%s+%.%.%.", "...")
            return t
        end)
        subs[i] = l
    end
end
function TextOperations.eraseLeadingEllipsis(subs, sel)
    for _, i in ipairs(sel) do
        local l = subs[i]
        local tags, body = splitLeadingTagBlocks(l.text)
        l.text = tags .. stripLeadingEllipsisText(body)
        subs[i] = l
    end
end
local function splitTrailingTextSuffix(value)
    local text = normalizeString(value)
    local suffix = ""
    local peeling = true
    while peeling and text ~= "" do
        peeling = false
        local trailingSpace = text:match("(%s+)$")
        if trailingSpace then
            text = text:sub(1, #text - #trailingSpace)
            suffix = trailingSpace .. suffix
            peeling = true
        end
        local s = text:find("%b{}$")
        if s then
            suffix = text:sub(s) .. suffix
            text = text:sub(1, s - 1)
            peeling = true
        else
            local chars = splitUtf8Chars(text)
            local last = chars[#chars]
            if last and closingPunctuation[last] then
                suffix = last .. suffix
                text = joinRange(chars, 1, #chars - 1)
                peeling = true
            end
        end
    end
    return text, suffix
end
local function eraseInnerEllipsisText(value)
    local text, suffix = splitTrailingTextSuffix(value)
    local ending = ""
    local dots = text:match("(%.%.%.+)$")
    if dots then
        ending = dots
        text = text:sub(1, #text - #dots)
    elseif endsWith(text, horizontalEllipsis) or endsWith(text, twoDotLeader) then
        local chars = splitUtf8Chars(text)
        ending = chars[#chars]
        text = joinRange(chars, 1, #chars - 1)
    end
    text = mutateTextOutsideBlocks(text, function(part)
        part = part:gsub("%.%.%.+([,;:%.%!%?])", "%1")
        part = part:gsub(horizontalEllipsis .. "([,;:%.%!%?])", "%1")
        part = part:gsub(twoDotLeader .. "([,;:%.%!%?])", "%1")
        part = part:gsub("([^%s])%.%.%.+([^%s])", "%1 %2")
        part = part:gsub("([^%s])" .. horizontalEllipsis .. "([^%s])", "%1 %2")
        part = part:gsub("([^%s])" .. twoDotLeader .. "([^%s])", "%1 %2")
        return part:gsub(horizontalEllipsis, ""):gsub(twoDotLeader, ""):gsub("%.%.%.+", "")
    end)
    return text .. ending .. suffix
end
function TextOperations.eraseInnerEllipsis(subs, sel)
    for _, i in ipairs(sel) do
        local l = subs[i]
        l.text = eraseInnerEllipsisText(l.text)
        subs[i] = l
    end
end
function TextOperations.addEndingEllipsis(subs, sel)
    for _, i in ipairs(sel) do local l = subs[i]; l.text = addEndingEllipsisText(l.text); subs[i] = l end
end
local function replaceFinalEllipsisText(value, replacement)
    local text, suffix = splitTrailingTextSuffix(value)
    local changed
    text, changed = text:gsub("%.%.+$", replacement, 1)
    if changed == 0 then text, changed = text:gsub(horizontalEllipsis .. "$", replacement, 1) end
    if changed == 0 then text, changed = text:gsub(twoDotLeader .. "$", replacement, 1) end
    if changed == 0 then return value end
    return text .. suffix
end
local function replaceFinalEllipsisForSelection(subs, sel, replacement)
    for _, i in ipairs(sel) do
        local l = subs[i]
        l.text = replaceFinalEllipsisText(l.text, replacement)
        subs[i] = l
    end
end
function TextOperations.ellipsisToComma(subs, sel) replaceFinalEllipsisForSelection(subs, sel, ",") end
function TextOperations.ellipsisToPeriod(subs, sel) replaceFinalEllipsisForSelection(subs, sel, ".") end
function TextOperations.normalizeQuotes(subs, sel)
    for _, i in ipairs(sel) do local l = subs[i]; mutateTextSections(l, normalizeQuotesText); subs[i] = l end
end
function TextOperations.toLatinQuotes(subs, sel)
    for _, i in ipairs(sel) do local l = subs[i]; mutateTextSections(l, toLatinQuotesText); subs[i] = l end
end
function TextOperations.normalizeDashes(subs, sel)
    for _, i in ipairs(sel) do local l = subs[i]; mutateTextSections(l, normalizeDashesText); subs[i] = l end
end
function TextOperations.trimTrailingSpaces(subs, sel)
    for _, i in ipairs(sel) do
        local l = subs[i]
        l.text = normalizeString(l.text):gsub("[ \t]+\\N", "\\N"):gsub("\\N[ \t]+", "\\N"):gsub("[ \t]+$", "")
        subs[i] = l
    end
end

local function togglePunctuationForSelection(subs, sel, opening, closing)
    for _, i in ipairs(sel) do local l = subs[i]; l.text = toggleWrappedPunctuation(l.text, opening, closing); subs[i] = l end
end
function TextOperations.toggleExclamation(subs, sel) togglePunctuationForSelection(subs, sel, invExclamation, "!") end
function TextOperations.toggleQuestion(subs, sel)    togglePunctuationForSelection(subs, sel, invQuestion, "?") end
function TextOperations.toggleBothSigns(subs, sel)   togglePunctuationForSelection(subs, sel, invExclamation .. invQuestion, "?!") end

function TextOperations.removeDuplicateLetters(subs, sel)
    for _, i in ipairs(sel) do local l = subs[i]; mutateTextSections(l, normalizeRepeatedLetters); subs[i] = l end
end

function TagOperations.extractTags(subs, sel)
    for _, i in ipairs(sel) do
        local l = subs[i]
        local initialTags, rest = splitLeadingTagBlocks(l.text)
        if initialTags ~= "" then
            local cur = normalizeString(l.effect)
            l.effect = (cur ~= "" and (initialTags .. " " .. cur) or initialTags)
            l.text = trimText(rest)
            subs[i] = l
        end
    end
end

function TagOperations.reinsertTags(subs, sel)
    for _, i in ipairs(sel) do
        local l = subs[i]
        local saved, rest = extractEffectTagBlocks(l.effect)
        if saved ~= "" then
            l.text = MarkerOperations.normalizeEffectTagSeparators(saved) .. normalizeString(l.text)
            l.effect = rest
            subs[i] = l
        end
    end
end

function MarkerOperations.numberEffects(subs, sel)
    local sorted = {}
    for _, i in ipairs(sel) do sorted[#sorted+1] = i end
    table.sort(sorted)
    local n = 1
    for _, i in ipairs(sorted) do
        local l = subs[i]
        if isDialogue(l) then
            MarkerOperations.appendEffectText(l, tostring(n))
            subs[i] = l
            n = n + 1
        end
    end
end

function MarkerOperations.collectRandomNumbers(subs)
    local used = {}
    for i = 1, #subs do
        local effect = normalizeString(subs[i] and subs[i].effect or "")
        for n in effect:gmatch("%f[%d](%d%d%d%d%d%d%d%d%d%d%d%d%d%d)%f[%D]") do used[n] = true end
    end
    return used
end

function MarkerOperations.makeRandomNumber(used)
    local n
    repeat
        local out = {}
        for i = 1, 14 do out[i] = tostring(math.random(0, 9)) end
        n = table.concat(out)
    until not used[n]
    used[n] = true
    return n
end

function MarkerOperations.randomEffects(subs, sel)
    math.randomseed(os.time() + math.floor(os.clock() * 1000000) + (#sel * 7919))
    math.random(); math.random(); math.random()
    local used = MarkerOperations.collectRandomNumbers(subs)
    for _, i in ipairs(sel) do
        local l = subs[i]
        if isDialogue(l) then
            MarkerOperations.appendEffectText(l, MarkerOperations.makeRandomNumber(used))
            subs[i] = l
        end
    end
end

function MarkerOperations.collectFoldIds(subs)
    local used = {}
    for i = 1, #subs do
        local extra = subs[i] and subs[i].extra
        local data = type(extra) == "table" and extra["_aegi_folddata"] or nil
        local id = data and data:match("^%d+;%d+;(%d+)$")
        if id then used[tonumber(id)] = true end
    end
    return used
end

function MarkerOperations.nextFoldId(used)
    local id = math.floor(os.time() % 1000000000)
    if id < 1 then id = 1 end
    while used[id] do id = id + 1 end
    used[id] = true
    return id
end

function MarkerOperations.clearFoldData(line)
    if type(line.extra) == "table" then line.extra["_aegi_folddata"] = nil end
end

function MarkerOperations.setFoldData(line, side, id)
    if type(line.extra) ~= "table" then line.extra = {} end
    line.extra["_aegi_folddata"] = tostring(side) .. ";0;" .. tostring(id)
end

function MarkerOperations.randomFolds(subs, sel)
    local sorted = {}
    for _, i in ipairs(sel) do sorted[#sorted+1] = i end
    table.sort(sorted)
    local entries, groups, order = {}, {}, {}
    for _, i in ipairs(sorted) do
        local line = cloneLine(subs[i])
        MarkerOperations.clearFoldData(line)
        local id = MarkerOperations.effectRandomNumber(line)
        local entry = { line = line, random = id }
        entries[#entries+1] = entry
        if id then
            if not groups[id] then groups[id] = {}; order[#order+1] = id end
            groups[id][#groups[id]+1] = entry
        end
    end
    local groupedIds = {}
    for _, id in ipairs(order) do if #groups[id] > 1 then groupedIds[id] = true end end
    local out, emitted = {}, {}
    for _, entry in ipairs(entries) do
        local id = entry.random
        if id and groupedIds[id] then
            if not emitted[id] then
                for _, grouped in ipairs(groups[id]) do out[#out+1] = grouped end
                emitted[id] = true
            end
        else
            out[#out+1] = entry
        end
    end
    local usedFoldIds = MarkerOperations.collectFoldIds(subs)
    local firstById, lastById = {}, {}
    for pos, entry in ipairs(out) do
        local id = entry.random
        if id and groupedIds[id] then
            firstById[id] = firstById[id] or pos
            lastById[id] = pos
        end
    end
    for id, first in pairs(firstById) do
        local last = lastById[id]
        if first and last and first ~= last then
            local foldId = MarkerOperations.nextFoldId(usedFoldIds)
            MarkerOperations.setFoldData(out[first].line, 0, foldId)
            MarkerOperations.setFoldData(out[last].line, 1, foldId)
        end
    end
    for pos, i in ipairs(sorted) do subs[i] = out[pos].line end
    return sel
end

function TagOperations.removeAllTags(subs, sel)
    for _, i in ipairs(sel) do
        local line = subs[i]; line.text = stripTags(line.text); subs[i] = line
    end
end

function TagOperations.removeComments(subs, sel)
    for _, i in ipairs(sel) do
        local line = subs[i]; line.text = stripComments(line.text); subs[i] = line
    end
end

local function mergeAdjacentTagBlocks(text)
    text = normalizeString(text)
    local out, last = {}, 0
    local i, n = 1, #text
    while i <= n do
        if text:sub(i, i) == "{" then
            local close = text:find("}", i, true)
            if not close then out[#out+1] = text:sub(i); break end
            local block = text:sub(i, close)
            local isTag = isOverrideBlock(block)
            if isTag and last > 0 then
                out[last] = out[last]:sub(1, -2) .. block:sub(2)
            else
                out[#out+1] = block
                last = isTag and #out or 0
            end
            i = close + 1
        else
            local nextBrace = text:find("{", i, true)
            local stop = nextBrace and nextBrace - 1 or n
            out[#out+1] = text:sub(i, stop)
            last = 0
            i = stop + 1
        end
    end
    return table.concat(out)
end

function TagOperations.mergeTags(subs, sel)
    for _, i in ipairs(sel) do
        local l = subs[i]
        local merged = mergeAdjacentTagBlocks(l.text)
        if merged ~= normalizeString(l.text) then
            l.text = merged
            subs[i] = l
        end
    end
end

function TagOperations.parseActor(subs, sel)
    local function allocDur(seg, T)
        T = math.floor(tonumber(T) or 0)
        if #seg == 0 or T < #seg then return nil end
        local c = 0
        for _, s in ipairs(seg) do
            local txt = visibleText(s.text):gsub("%s+", "")
            c = c + unicodeLenSafe(txt)
        end
        local remaining = T - #seg
        local d, r = {}, remaining
        if c == 0 then
            local share = math.floor(remaining / #seg)
            for i = 1, #seg do d[i] = 1 + share end
            d[#seg] = d[#seg] + remaining - share * #seg
        else
            for i, s in ipairs(seg) do
                local txt = visibleText(s.text):gsub("%s+", "")
                local len = unicodeLenSafe(txt)
                if i == #seg then d[i] = 1 + r
                else local v = math.floor(remaining * len / c); d[i] = 1 + v; r = r - v end
            end
        end
        return d
    end
    local function parseActorsAndSplit(text)
        local segments = {}
        local currentText, currentActor = "", nil
        local i, len = 1, text:len()
        local patterns = {
            "^%s*（(.-)）", "^%s*%((.-)%)", "^%s*%[(.-)%]",
            "^%s*【(.-)】", "^%s*［(.-)］", "^%s*｛(.-)｝",
            "^%s*〈(.-)〉", "^%s*《(.-)》", "^%s*「(.-)」",
            "^%s*『(.-)』", "^%s*〔(.-)〕",
        }
        while i <= len do
            local blockEnd = text:sub(i, i) == "{" and select(2, text:find("^%b{}", i))
            if blockEnd then
                currentText = currentText .. text:sub(i, blockEnd)
                i = blockEnd + 1
            else
                local sub = text:sub(i)
                local actorMatch, matchLen = nil, 0
                for _, pat in ipairs(patterns) do
                    local s, e, cap = sub:find(pat)
                    if s then actorMatch = cap; matchLen = e - s + 1; break end
                end
                if actorMatch then
                    if hasVisibleSegmentText(currentText) then
                        table.insert(segments, { actor = currentActor, text = currentText })
                        currentText = ""
                    end
                    i = i + matchLen; currentActor = actorMatch
                else
                    local b = text:byte(i)
                    local cl = (b >= 240) and 4 or (b >= 224) and 3 or (b >= 192) and 2 or 1
                    currentText = currentText .. text:sub(i, i + cl - 1)
                    i = i + cl
                end
            end
        end
        if currentText ~= "" then table.insert(segments, { actor = currentActor, text = currentText }) end
        return segments
    end
    local lastActor = nil
    table.sort(sel)
    local shifts = 0
    local inserted = {}
    for _, ix in ipairs(sel) do
        local i = ix + shifts
        local l = subs[i]
        local text = normalizeString(l.text)
        text = mutateTextOutsideBlocks(text, function(value)
            return value:gsub("<([^>]+)>", "{\\i1}%1{\\i0}"):gsub("＜(.-)＞", "{\\i1}%1{\\i0}")
        end)
        local simpleActor, simpleRest = text:match("^%s*%[([^%]]+)%]%s*:%s*(.+)$")
        if not simpleActor then
            simpleActor, simpleRest = text:match("^%s*([^:%[%(]+):%s*(.+)$")
            if simpleActor and (text:match("^%s*[%a][%w+%.%-]*://") or simpleActor:find("\\") or #trimText(simpleActor) > 24) then
                simpleActor, simpleRest = nil, nil
            end
        end
        if simpleActor and simpleRest and not simpleRest:match("[%[%(（]") then
            l.actor = trimText(simpleActor)
            l.text = simpleRest
            lastActor = l.actor
            subs[i] = l
        else
            local parts = parseActorsAndSplit(text)
            local inherited = extractLeadingTagBlocks(text)
            for position, part in ipairs(parts) do
                local leading, body = splitLeadingBraceBlocks(trimText(part.text))
                part.text = leading .. trimText(body)
                if position > 1 then part.text = ensureInheritedTags(part.text, inherited) end
            end
            if #parts == 0 then
                if lastActor then l.actor = lastActor; subs[i] = l end
            elseif #parts == 1 then
                local p = parts[1]
                if p.actor then l.actor = p.actor; lastActor = p.actor
                elseif lastActor then l.actor = lastActor end
                l.text = p.text:gsub("^%s+", ""):gsub("%s+$", "")
                subs[i] = l
            else
                local dur = allocDur(parts, l.end_time - l.start_time)
                if dur then
                    local t = l.start_time
                    for j, p in ipairs(parts) do
                        local nl = cloneLine(l)
                        nl.start_time = t; nl.end_time = t + dur[j]; t = nl.end_time
                        if p.actor then nl.actor = p.actor; lastActor = p.actor
                        elseif lastActor then nl.actor = lastActor end
                        nl.text = p.text:gsub("^%s+", ""):gsub("%s+$", "")
                        if j == 1 then subs[i] = nl else subs.insert(i + j - 1, nl); shifts = shifts + 1 end
                    end
                    inserted[ix] = #parts - 1
                end
            end
        end
    end
    return remapSelectionAfterInsertion(sel, inserted)
end

function TagOperations.swapComment(subs, sel)
    for _, i in ipairs(sel) do
        local l = subs[i]; local text = normalizeString(l.text); local out = {}; local lastIdx = 1
        for s, block, e in text:gmatch("()(%b{})()") do
            local before = text:sub(lastIdx, s - 1)
            if before ~= "" then
                if before:match("^%s+$") then out[#out+1] = before
                else out[#out+1] = "{" .. before .. "}" end
            end
            if block:match("^%{%s*\\") then out[#out+1] = block else out[#out+1] = block:sub(2, -2) end
            lastIdx = e
        end
        local tail = text:sub(lastIdx)
        if tail ~= "" then
            if tail:match("^%s+$") then out[#out+1] = tail else out[#out+1] = "{" .. tail .. "}" end
        end
        l.text = table.concat(out); subs[i] = l
    end
end

local function addStutterToText(value)
    local chars = splitUtf8Chars(value)
    if #chars == 0 then return value, false end
    local target, depth = nil, 0
    for idx, ch in ipairs(chars) do
        if ch == "{" then depth = depth + 1
        elseif ch == "}" then depth = math.max(0, depth - 1)
        elseif depth == 0 and isLetter(ch) then target = idx; break end
    end
    if not target then return value, false end
    if chars[target+1] == "-" and chars[target+2] and unicodeLower(chars[target+2]) == unicodeLower(chars[target]) then
        table.remove(chars, target + 2)
        table.remove(chars, target + 1)
        return table.concat(chars), true
    end
    local out = {}
    for idx, ch in ipairs(chars) do
        if idx == target then out[#out+1] = ch; out[#out+1] = "-"; out[#out+1] = ch
        else out[#out+1] = ch end
    end
    return table.concat(out), true
end

local function addAhPrefixToText(value)
    local chars = splitUtf8Chars(value)
    if #chars == 0 then return value, false end
    local prefix, idx = {}, 1
    while idx <= #chars do
        local ch = chars[idx]
        if ch == invQuestion or ch == invExclamation then prefix[#prefix+1] = ch; idx = idx + 1
        elseif ch == "." then
            local dots, j = 0, idx
            while j <= #chars and chars[j] == "." do dots = dots + 1; j = j + 1 end
            if dots >= 2 then
                for _ = 1, dots do prefix[#prefix+1] = "." end
                idx = j
                while idx <= #chars and (chars[idx] == " " or chars[idx] == "\t") do idx = idx + 1 end
            else break end
        elseif ch == horizontalEllipsis or ch == twoDotLeader then
            prefix[#prefix+1] = ch; idx = idx + 1
            while idx <= #chars and (chars[idx] == " " or chars[idx] == "\t") do idx = idx + 1 end
        elseif ch == " " or ch == "\t" then idx = idx + 1
        else break end
    end
    if idx > #chars then return value, false end
    local firstLetter, depth = nil, 0
    for k = idx, #chars do
        if chars[k] == "{" then depth = depth + 1
        elseif chars[k] == "}" then depth = math.max(0, depth - 1)
        elseif depth == 0 and isLetter(chars[k]) then firstLetter = k; break end
    end
    if not firstLetter then return value, false end
    local matchA, matchB = true, true
    local lower = {"a","h",","}; local upper = {"A","h",","}
    for m = 1, 3 do
        local ci = firstLetter + m - 1
        if ci > #chars then matchA = false; matchB = false; break end
        if chars[ci] ~= lower[m] then matchA = false end
        if chars[ci] ~= upper[m] then matchB = false end
    end
    if matchA or matchB then
        for _ = 1, 3 do table.remove(chars, firstLetter) end
        while chars[firstLetter] == " " or chars[firstLetter] == "\t" do table.remove(chars, firstLetter) end
        if chars[firstLetter] then chars[firstLetter] = unicodeUpper(chars[firstLetter]) end
        return table.concat(chars), true
    end
    chars[firstLetter] = unicodeLower(chars[firstLetter])
    local out = {}
    for k = 1, #prefix do out[#out+1] = prefix[k] end
    out[#out+1] = "Ah, "
    for k = idx, #chars do out[#out+1] = chars[k] end
    return table.concat(out), true
end

local function mutateFirstText(subs, sel, transform)
    for _, i in ipairs(sel) do
        local line, done = subs[i], false
        mutateTextSections(line, function(value)
            if done then return value end
            local replaced, changed = transform(value)
            done = changed
            return replaced
        end)
        subs[i] = line
    end
end

function SmartOperations.injectStutter(subs, sel) mutateFirstText(subs, sel, addStutterToText) end
function SmartOperations.injectAhPrefix(subs, sel) mutateFirstText(subs, sel, addAhPrefixToText) end

function SmartOperations.removeHonorifics(subs, sel)
    local function removeFromText(text)
        return normalizeString(text)
            :gsub("%-san%f[%A]",      "{-san}")
            :gsub("%-tan%f[%A]",      "{-tan}")
            :gsub("%-chan%f[%A]",     "{-chan}")
            :gsub("%-kun%f[%A]",      "{-kun}")
            :gsub("%-sama%f[%A]",     "{-sama}")
            :gsub("%-niisan%f[%A]",   "{-niisan}")
            :gsub("%-oniisan%f[%A]",  "{-oniisan}")
            :gsub("%-oniichan%f[%A]", "{-oniichan}")
            :gsub("%-oneesan%f[%A]",  "{-oneesan}")
            :gsub("%-oneechan%f[%A]", "{-oneechan}")
            :gsub("%-neesama%f[%A]",  "{-neesama}")
            :gsub("%-sensei%f[%A]",   "{-sensei}")
            :gsub("%-se[mn]pai%f[%A]","{-senpai}")
            :gsub("%-dono%f[%A]",     "{-dono}")
            :gsub("{{", "{")
            :gsub("}}", "}")
            :gsub("({[^{}]-){(%-%a-)}([^{}]-})", "%1%2%3")
    end
    for _, i in ipairs(sel) do
        local l = subs[i]
        l.text = mutateTextOutsideBlocks(l.text, removeFromText)
        subs[i] = l
    end
end

function TimingOperations.removeLinebreaks(subs, sel)
    for _, i in ipairs(sel) do
        local line = subs[i]
        mutateTextSections(line, function(value) return value:gsub("\\[Nn]", " "):gsub("[ \t]+", " ") end)
        line.text = trimText(line.text)
        subs[i] = line
    end
end

function SmartOperations.clarifyCaption(subs, sel)
    for _, i in ipairs(sel) do
        local line, first = subs[i], true
        mutateTextSections(line, function(value)
            local clean = value:gsub("%b[]", ""):gsub("%s+", " ")
            if first then clean = clean:gsub("^%s+", ""); first = clean == "" end
            return clean
        end)
        line.text = trimText(line.text)
        subs[i] = line
    end
end

function SmartOperations.eraseBlankLines(subs, sel)
    local toDelete, deleteSet = {}, {}
    for _, i in ipairs(sel) do
        local l = subs[i]
        local clean = visibleText(l.text):gsub("%s+", ""):gsub(NBSP, "")
        if clean == "" then toDelete[#toDelete+1] = i; deleteSet[i] = true end
    end
    table.sort(toDelete, function(a, b) return a > b end)
    for _, i in ipairs(toDelete) do subs.delete(i) end
    return remapSelectionAfterDeletion(subs, sel, deleteSet)
end

function SmartOperations.deleteCommentLines(subs, sel)
    local deleteSet = {}
    table.sort(sel, function(a, b) return a > b end)
    for _, i in ipairs(sel) do
        local l = subs[i]
        if isDialogue(l) and l.comment then
            subs.delete(i); deleteSet[i] = true
        end
    end
    return remapSelectionAfterDeletion(subs, sel, deleteSet)
end

local function moveMatchingLines(subs, sel, predicate, toStart)
    local selected, matching, other = {}, {}, {}
    for _, i in ipairs(sel) do selected[#selected+1] = { index = i, line = cloneLine(subs[i]) } end
    table.sort(selected, function(a, b) return a.index < b.index end)
    for _, item in ipairs(selected) do
        local target = predicate(item.line) and matching or other
        target[#target+1] = item.line
    end
    local first, second = toStart and matching or other, toStart and other or matching
    for _, line in ipairs(second) do first[#first+1] = line end
    for position, item in ipairs(selected) do subs[item.index] = first[position] end
end
local function moveCommentLines(subs, sel, toStart)
    moveMatchingLines(subs, sel, function(line) return isDialogue(line) and line.comment end, toStart)
end
function SmartOperations.commentsToTop(subs, sel) moveCommentLines(subs, sel, true) end
function SmartOperations.commentsToBottom(subs, sel) moveCommentLines(subs, sel, false) end
function TagOperations.effectsToTop(subs, sel)
    moveMatchingLines(subs, sel, function(line) return isDialogue(line) and trimText(line.effect) ~= "" end, true)
end

local function nearestKeyframe(frame, kfs, range)
    local best, bestDist = nil, nil
    for _, kf in ipairs(kfs or {}) do
        local dist = math.abs(kf - frame)
        if dist <= range and (not bestDist or dist < bestDist) then
            best, bestDist = kf, dist
        end
        if kf > frame + range then break end
    end
    return best, bestDist
end

local function directionalKeyframeMs(targetMs, kfs, limitMs, direction)
    local frame = msToFrame(targetMs)
    if not frame then return nil end
    local bestMs, bestDist = nil, nil
    for _, kf in ipairs(kfs or {}) do
        local kfMs = frameToMs(kf)
        local ok = kfMs and ((direction == "back" and kf < frame) or (direction == "forward" and kf > frame))
        if ok then
            local dist = math.abs(kfMs - targetMs)
            if dist <= limitMs and (not bestDist or dist < bestDist) then
                bestMs, bestDist = kfMs, dist
            end
        end
    end
    return bestMs, bestDist
end

function SmartOperations.bidirectionalSnapping(subs, sel)
    local kfs = getKeyframes()
    if not kfs or #kfs == 0 then showMsg(L("err_no_keyframes")); return end
    local range = tonumber(currentConfig.bidir_snap_f) or 2
    if range < 0 then range = 0 end
    local modified, starts, ends = 0, 0, 0
    for _, i in ipairs(sel) do
        local line = subs[i]
        if isDialogue(line) and validateDuration(line) then
            local sf, ef = msToFrame(line.start_time), msToFrame(line.end_time)
            local skf, sdist, ekf, edist
            if sf then skf, sdist = nearestKeyframe(sf, kfs, range) end
            if ef then ekf, edist = nearestKeyframe(ef, kfs, range) end
            local oldStart, oldEnd = line.start_time, line.end_time
            local snapStart = skf and frameToMs(skf) or nil
            local snapEnd = ekf and frameToMs(ekf) or nil
            local newStart = snapStart or oldStart
            local newEnd = snapEnd or oldEnd
            if snapStart or snapEnd then
                if newEnd <= newStart then
                    if snapStart and (not snapEnd or sdist <= edist) and oldEnd > snapStart then
                        newStart, newEnd = snapStart, oldEnd
                    elseif snapEnd and snapEnd > oldStart then
                        newStart, newEnd = oldStart, snapEnd
                    else
                        newStart, newEnd = oldStart, oldEnd
                    end
                end
                if newStart ~= oldStart or newEnd ~= oldEnd then
                    if newStart ~= oldStart then starts = starts + 1 end
                    if newEnd ~= oldEnd then ends = ends + 1 end
                    line.start_time, line.end_time = newStart, newEnd
                    subs[i] = line
                    modified = modified + 1
                end
            end
        end
    end
    showMsg(string.format(L("msg_bidir_done"), modified, starts, ends, range))
end

local function directionalSnap(subs, sel, edge, direction)
    local kfs = getKeyframes()
    if not kfs or #kfs == 0 then showMsg(L("err_no_keyframes")); return end
    local limit = tonumber(currentConfig.edge_snap_protect_ms) or defaultConfig.edge_snap_protect_ms
    limit = math.max(0, limit)
    if limit == 0 then return end
    for _, i in ipairs(sel) do
        local line = subs[i]
        if isDialogue(line) and validateDuration(line) then
            local oldStart, oldEnd = line.start_time, line.end_time
            local target = edge == "start" and oldStart or oldEnd
            local snapped = directionalKeyframeMs(target, kfs, limit, direction)
            if snapped then
                if edge == "start" then
                    if snapped < oldEnd and snapped ~= oldStart then
                        line.start_time = snapped
                        subs[i] = line
                    end
                elseif snapped > oldStart and snapped ~= oldEnd then
                    line.end_time = snapped
                    subs[i] = line
                end
            end
        end
    end
end

function SmartOperations.startSnapBack(subs, sel) directionalSnap(subs, sel, "start", "back") end
function SmartOperations.startSnapForward(subs, sel) directionalSnap(subs, sel, "start", "forward") end
function SmartOperations.endSnapBack(subs, sel) directionalSnap(subs, sel, "end", "back") end
function SmartOperations.endSnapForward(subs, sel) directionalSnap(subs, sel, "end", "forward") end

local function timelineSnapshot(subs)
    local arr = {}
    for i = 1, #subs do
        local l = subs[i]
        if isEditableDialogue(l) and validateDuration(l) then
            arr[#arr+1] = { i = i, s = l.start_time, e = l.end_time }
        end
    end
    return arr
end

local function applySnapshotTime(subs, rec, s, e)
    local line = subs[rec.i]
    line.start_time, line.end_time = s, e
    subs[rec.i] = line
    rec.s, rec.e = s, e
end

local function selectionByStart(all, sel)
    local byIdx = {}
    for _, r in ipairs(all) do byIdx[r.i] = r end
    local order = {}
    for _, i in ipairs(sel) do if byIdx[i] then order[#order+1] = byIdx[i] end end
    table.sort(order, function(a, b)
        if a.s == b.s then return a.i < b.i end
        return a.s < b.s
    end)
    return order
end

local minNeighborDuration = 10

local function nudgeLead(subs, sel, edge)
    local step = normalizeNumber(currentConfig.lead_step_ms, defaultConfig.lead_step_ms)
    if step <= 0 then step = defaultConfig.lead_step_ms end
    local all = timelineSnapshot(subs)
    for _, rec in ipairs(selectionByStart(all, sel)) do
        local bound, chained = nil, {}
        if edge == "in" then
            for _, r in ipairs(all) do
                if r ~= rec then
                    if r.e == rec.s and r.s < rec.s then chained[#chained+1] = r
                    elseif r.e < rec.s and (not bound or r.e > bound) then bound = r.e end
                end
            end
            local move
            if #chained > 0 then
                move = step
                for _, r in ipairs(chained) do move = math.min(move, r.e - r.s - minNeighborDuration) end
                move = math.min(move, rec.s)
                if move > 0 then
                    for _, r in ipairs(chained) do applySnapshotTime(subs, r, r.s, r.e - move) end
                end
            else
                move = math.min(step, rec.s - (bound or 0))
            end
            if move > 0 then applySnapshotTime(subs, rec, rec.s - move, rec.e) end
        else
            for _, r in ipairs(all) do
                if r ~= rec then
                    if r.s == rec.e and r.e > rec.e then chained[#chained+1] = r
                    elseif r.s > rec.e and (not bound or r.s < bound) then bound = r.s end
                end
            end
            local move
            if #chained > 0 then
                move = step
                for _, r in ipairs(chained) do move = math.min(move, r.e - r.s - minNeighborDuration) end
                if move > 0 then
                    for _, r in ipairs(chained) do applySnapshotTime(subs, r, r.s + move, r.e) end
                end
            else
                move = bound and math.min(step, bound - rec.e) or step
            end
            if move > 0 then applySnapshotTime(subs, rec, rec.s, rec.e + move) end
        end
    end
end

local function nudgeLeadInward(subs, sel, edge)
    local step = normalizeNumber(currentConfig.lead_step_ms, defaultConfig.lead_step_ms)
    if step <= 0 then step = defaultConfig.lead_step_ms end
    local all = timelineSnapshot(subs)
    for _, rec in ipairs(selectionByStart(all, sel)) do
        local move = math.min(step, rec.e - rec.s - minNeighborDuration)
        if move > 0 then
            if edge == "in" then
                local oldStart = rec.s
                for _, r in ipairs(all) do
                    if r ~= rec and r.e == oldStart and r.s < oldStart then
                        applySnapshotTime(subs, r, r.s, r.e + move)
                    end
                end
                applySnapshotTime(subs, rec, rec.s + move, rec.e)
            else
                local oldEnd = rec.e
                for _, r in ipairs(all) do
                    if r ~= rec and r.s == oldEnd and r.e > oldEnd then
                        applySnapshotTime(subs, r, r.s - move, r.e)
                    end
                end
                applySnapshotTime(subs, rec, rec.s, rec.e - move)
            end
        end
    end
end

local function chainToNeighbor(subs, sel, side)
    local cap = normalizeNumber(currentConfig.chain_max_ms, defaultConfig.chain_max_ms)
    cap = math.max(0, cap)
    if cap == 0 then return end
    local all = timelineSnapshot(subs)
    for _, rec in ipairs(selectionByStart(all, sel)) do
        if side == "left" then
            local bound
            for _, r in ipairs(all) do
                if r ~= rec and r.e <= rec.s and (not bound or r.e > bound) then bound = r.e end
            end
            if bound and bound < rec.s and rec.s - bound <= cap then applySnapshotTime(subs, rec, bound, rec.e) end
        else
            local bound
            for _, r in ipairs(all) do
                if r ~= rec and r.s >= rec.e and (not bound or r.s < bound) then bound = r.s end
            end
            if bound and bound > rec.e and bound - rec.e <= cap then applySnapshotTime(subs, rec, rec.s, bound) end
        end
    end
end

function TimingOperations.addLeadIn(subs, sel)  nudgeLead(subs, sel, "in") end
function TimingOperations.addLeadInRight(subs, sel) nudgeLeadInward(subs, sel, "in") end
function TimingOperations.addLeadOutLeft(subs, sel) nudgeLeadInward(subs, sel, "out") end
function TimingOperations.addLeadOut(subs, sel) nudgeLead(subs, sel, "out") end
function TimingOperations.chainLeft(subs, sel)  chainToNeighbor(subs, sel, "left") end
function TimingOperations.chainRight(subs, sel) chainToNeighbor(subs, sel, "right") end

local function allocateDurationsByWeights(weights, totalDuration)
    local duration = math.floor(normalizeNumber(totalDuration, 0))
    local count = #weights
    if count == 0 or duration <= 0 or duration < count then return nil end
    local nw, sum = {}, 0
    for i = 1, count do
        local w = math.max(0, normalizeNumber(weights[i], 0)); nw[i] = w; sum = sum + w
    end
    local alloc = {}
    if sum == 0 then
        local base = math.floor(duration / count)
        local rem  = duration - (base * count)
        for i = 1, count do alloc[i] = base + (i <= rem and 1 or 0) end
        return alloc
    end
    local used = 0
    for i = 1, count - 1 do
        local raw = roundNumber(duration * nw[i] / sum, 0)
        local minRem = count - i
        local maxCur = duration - used - minRem
        if maxCur < 1 then return nil end
        if raw < 1 then raw = 1 elseif raw > maxCur then raw = maxCur end
        alloc[i] = raw; used = used + raw
    end
    alloc[count] = duration - used
    if alloc[count] < 1 then
        local needed = 1 - alloc[count]
        for i = count - 1, 1, -1 do
            if alloc[i] > 1 then
                local borrow = math.min(alloc[i] - 1, needed)
                alloc[i] = alloc[i] - borrow
                alloc[count] = alloc[count] + borrow
                needed = needed - borrow
                if needed <= 0 then break end
            end
        end
        if alloc[count] < 1 then return nil end
    end
    return alloc
end

local function allocateTimeDuration(segments, totalDuration)
    local w = {}; for i, s in ipairs(segments) do w[i] = countCharacters(s) end
    return allocateDurationsByWeights(w, totalDuration)
end

local function lineTextKey(line)
    return trimText(normalizeString(line.text):gsub("[ \t]+$", ""))
end

function TimingOperations.copyTimes(subs, sel)
    table.sort(sel); if #sel < 2 then return end
    local src = subs[sel[1]]
    for n = 2, #sel do
        local l = subs[sel[n]]
        l.start_time, l.end_time = src.start_time, src.end_time
        subs[sel[n]] = l
    end
end

function TimingOperations.joinSameText(subs, sel)
    local selected, deleteSet = {}, {}
    for _, i in ipairs(sel) do selected[i] = true end
    table.sort(sel, function(a, b) return a > b end)
    for _, i in ipairs(sel) do
        if i > 1 and selected[i-1] and isEditableDialogue(subs[i]) and isEditableDialogue(subs[i-1]) then
            local l = subs[i]; local prev = subs[i-1]
            if lineTextKey(l) ~= "" and lineTextKey(l) == lineTextKey(prev)
               and normalizeString(l.style) == normalizeString(prev.style) then
                prev.start_time = math.min(prev.start_time, l.start_time)
                prev.end_time   = math.max(prev.end_time,   l.end_time)
                subs[i-1] = prev; subs.delete(i); deleteSet[i] = true
            end
        end
    end
    return remapSelectionAfterDeletion(subs, sel, deleteSet)
end

local function joinOverlapSentenceParts(lines)
    local parts = {}
    for pos, entry in ipairs(lines) do
        local text = stripComments(stripTags(entry.line.text or ""))
        text = trimText(text:gsub("%s+", " "))
        if text ~= "" then
            if pos < #lines then text = replaceFinalEllipsisText(text, ",") end
            if pos > 1 then text = changeFirstLetter(text, false) end
            parts[#parts+1] = text
        end
    end
    return joinTextParts(parts)
end

local function joinOverlapGroups(subs, sel, sentences)
    if not sel or #sel < 2 then return sel end
    local entries = {}
    for _, index in ipairs(sel) do
        local line = subs[index]
        if isEditableDialogue(line) and validateDuration(line) and (not sentences or not isVectorDrawing(line)) then
            entries[#entries+1] = {
                index = index,
                line = line,
                start_time = line.start_time,
                end_time = line.end_time,
            }
        end
    end
    if #entries < 2 then return sel end
    table.sort(entries, function(a, b)
        if a.start_time ~= b.start_time then return a.start_time < b.start_time end
        if a.end_time ~= b.end_time then return a.end_time < b.end_time end
        return a.index < b.index
    end)

    local groups, current = {}, nil
    for _, entry in ipairs(entries) do
        if not current then
            current = { start_time = entry.start_time, end_time = entry.end_time, lines = { entry } }
        elseif entry.start_time < current.end_time then
            current.lines[#current.lines+1] = entry
            if entry.end_time > current.end_time then current.end_time = entry.end_time end
        else
            groups[#groups+1] = current
            current = { start_time = entry.start_time, end_time = entry.end_time, lines = { entry } }
        end
    end
    if current then groups[#groups+1] = current end

    local replacements, deleteSet, deleted = {}, {}, {}
    for _, group in ipairs(groups) do
        if #group.lines > 1 then
            local base = group.lines[1]
            local joined = cloneLine(base.line)
            local text
            if sentences then
                text = joinOverlapSentenceParts(group.lines)
                if text ~= "" then text = extractLeadingTagBlocks(base.line.text) .. text end
            else
                local parts = {}
                for _, entry in ipairs(group.lines) do parts[#parts+1] = entry.line.text or "" end
                text = table.concat(parts, "\\N")
            end
            if not sentences or text ~= "" then
                joined.start_time, joined.end_time = group.start_time, group.end_time
                joined.text = text
                replacements[#replacements+1] = { index = base.index, line = joined }
                for pos = 2, #group.lines do
                    local index = group.lines[pos].index
                    deleteSet[index] = true
                    deleted[#deleted+1] = index
                end
            end
        end
    end
    if #deleted == 0 then return sel end

    local function applyJoinPlan()
        for _, replacement in ipairs(replacements) do subs[replacement.index] = replacement.line end
        table.sort(deleted, function(a, b) return a > b end)
        for _, index in ipairs(deleted) do subs.delete(index) end
    end
    if Kite.LineOps and Kite.LineOps.transaction then Kite.LineOps.transaction(subs, applyJoinPlan)
    else applyJoinPlan() end
    return remapSelectionAfterDeletion(subs, sel, deleteSet)
end

function TimingOperations.joinOverlaps(subs, sel) return joinOverlapGroups(subs, sel, false) end
function TimingOperations.joinOverlapSentences(subs, sel) return joinOverlapGroups(subs, sel, true) end

function TimingOperations.sortByLength(subs, sel)
    table.sort(sel)
    local items = {}
    for _, i in ipairs(sel) do
        items[#items+1] = { line = cloneLine(subs[i]), count = countCharacters(subs[i].text) }
    end
    table.sort(items, function(a, b)
        if a.count == b.count then return normalizeString(a.line.text) < normalizeString(b.line.text) end
        return a.count > b.count
    end)
    for idx, i in ipairs(sel) do subs[i] = items[idx].line end
end

local function calcCPS(line)
    local d = (line.end_time - line.start_time) / 1000
    if d <= 0 then return 0 end
    return countCharacters(line.text) / d
end

function TimingOperations.sortByCPS(subs, sel)
    table.sort(sel)
    local items = {}
    for _, i in ipairs(sel) do
        items[#items+1] = { line = cloneLine(subs[i]), cps = calcCPS(subs[i]) }
    end
    table.sort(items, function(a, b)
        if a.cps == b.cps then return normalizeString(a.line.text) < normalizeString(b.line.text) end
        return a.cps > b.cps
    end)
    for idx, i in ipairs(sel) do subs[i] = items[idx].line end
end

function TimingOperations.sortByEvenOdd(subs, sel)
    local sorted = {}
    for _, i in ipairs(sel) do sorted[#sorted+1] = i end
    table.sort(sorted)
    local odds, evens, others = {}, {}, {}
    for _, i in ipairs(sorted) do
        local line = cloneLine(subs[i])
        local n = MarkerOperations.effectNumber(line)
        if n == nil then
            others[#others+1] = line
        elseif math.abs(n) % 2 == 1 then
            odds[#odds+1] = line
        else
            evens[#evens+1] = line
        end
    end
    local out = {}
    for _, line in ipairs(odds) do out[#out+1] = line end
    for _, line in ipairs(evens) do out[#out+1] = line end
    for _, line in ipairs(others) do out[#out+1] = line end
    for pos, i in ipairs(sorted) do subs[i] = out[pos] end
    return sel
end

function TimingOperations.showCPS(subs, sel)
    local totalChars, totalMs, maxCps, maxIdx = 0, 0, 0, nil
    for _, i in ipairs(sel) do
        local l = subs[i]
        if validateDuration(l) then
            local c = countCharacters(l.text)
            local cps = calcCPS(l)
            totalChars = totalChars + c
            totalMs    = totalMs    + (l.end_time - l.start_time)
            if cps > maxCps then maxCps = cps; maxIdx = i end
        end
    end
    local avg = totalMs > 0 and totalChars / (totalMs / 1000) or 0
    showMsg(string.format(L("msg_avg_cps"), #sel, avg) .. string.format("\nMax CPS: %.2f%s", maxCps,
        maxIdx and (" on line " .. tostring(maxIdx)) or ""))
end

function TimingOperations.timePicker(subs, sel)
    if #sel == 0 then showMsg(L("err_no_selection")); return sel end
    table.sort(sel)

    local btn, res = aegisub.dialog.display({
        { class="checkbox", name="include_partial", label=L("lbl_include_partial"), value=true, x=0, y=0, width=6, height=1 },
    }, { L("btn_ok"), L("btn_cancel") }, { close = L("btn_cancel") })
    if btn ~= L("btn_ok") then return sel end

    local minStart, maxEnd
    for _, i in ipairs(sel) do
        local l = subs[i]
        if isEditableDialogue(l) and validateDuration(l) then
            if not minStart or l.start_time < minStart then minStart = l.start_time end
            if not maxEnd or l.end_time > maxEnd then maxEnd = l.end_time end
        end
    end
    if not minStart or not maxEnd then showMsg(L("err_no_active_dialogue")); return sel end

    local includePartial = res.include_partial
    local newSel = {}
    for i = 1, #subs do
        local l = subs[i]
        if isEditableDialogue(l) and validateDuration(l) then
            local inRange
            if includePartial then
                inRange = l.start_time < maxEnd and l.end_time > minStart
            else
                inRange = l.start_time >= minStart and l.end_time <= maxEnd
            end
            if inRange then newSel[#newSel+1] = i end
        end
    end
    showMsg(string.format(
        "Time range: %s - %s\nMode: %s\nActive dialogue lines selected: %d",
        msToAssTime(minStart),
        msToAssTime(maxEnd),
        includePartial and "partial overlap" or "fully contained",
        #newSel
    ))
    return newSel
end

local function parseDialogueRaw(line)
    line = trimText(line)
    local prefix, fields = splitEventLine(line)
    if not prefix then return nil end
    local startTime = assTimeToMs(fields[2])
    local endTime = assTimeToMs(fields[3])
    if not startTime or not endTime or endTime <= startTime then return nil end
    return {
        comment    = prefix == "Comment",
        layer      = tonumber(fields[1]) or 0,
        start_time = startTime,
        end_time   = endTime,
        style      = trimText(fields[4]),
        actor      = trimText(fields[5]),
        margin_l   = tonumber(fields[6]) or 0,
        margin_r   = tonumber(fields[7]) or 0,
        margin_t   = tonumber(fields[8]) or 0,
        effect     = trimText(fields[9]),
        text       = fields[10],
    }
end

local function splitImportLines(content)
    local lines = {}
    content = normalizeString(content):gsub("\r\n", "\n"):gsub("\r", "\n")
    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        if trimText(line) ~= "" then
            local parsed = parseDialogueRaw(line)
            if parsed then lines[#lines+1] = parsed
            else lines[#lines+1] = { text = trimText(line) } end
        end
    end
    return lines
end

function TimingOperations.importText(subs, sel)
    table.sort(sel); if #sel == 0 then return end
    local btn, res = aegisub.dialog.display({
        { class="label",    label=L("lbl_paste_dialogue"), x=0, y=0, width=8, height=1 },
        { class="textbox",  name="content", text="", x=0, y=1, width=80, height=16 },
        { class="checkbox", name="as_comment", label=L("lbl_import_as_comments"), value=false, x=0, y=13, width=8, height=1 }
    }, { L("btn_import"), L("btn_cancel") })
    if btn ~= L("btn_import") then return end
    local entries = splitImportLines(res.content)
    if #entries == 0 then return end
    local insertAfter = sel[#sel]
    local function applyEntry(base, entry)
        local nl = cloneLine(base)
        if entry.style then
            nl.layer    = entry.layer
            nl.style    = entry.style
            nl.actor    = entry.actor
            nl.margin_l = entry.margin_l
            nl.margin_r = entry.margin_r
            nl.margin_t = entry.margin_t
            nl.effect   = entry.effect
            nl.comment  = entry.comment
        end
        nl.text = res.as_comment and not entry.style and ("{" .. entry.text .. "}") or entry.text
        return nl
    end
    if #sel == #entries then
        for idx, i in ipairs(sel) do
            local entry = entries[idx]
            local l = applyEntry(subs[i], entry)
            if entry.start_time and entry.end_time then
                l.start_time, l.end_time = entry.start_time, entry.end_time
            else
                l.start_time, l.end_time = subs[i].start_time, subs[i].end_time
            end
            subs[i] = l
        end
        return
    end
    local source = subs[sel[#sel]]
    for idx, entry in ipairs(entries) do
        local base = (idx <= #sel and subs[sel[idx]]) or source
        local l = applyEntry(base, entry)
        if entry.start_time and entry.end_time then
            l.start_time, l.end_time = entry.start_time, entry.end_time
        else
            l.start_time, l.end_time = base.start_time, base.end_time
        end
        if idx <= #sel then subs[sel[idx]] = l
        else subs.insert(insertAfter + idx - #sel, l) end
    end
    local newSel = {}
    for _, i in ipairs(sel) do newSel[#newSel+1] = i end
    for k = 1, #entries - #sel do newSel[#newSel+1] = insertAfter + k end
    return newSel
end

function TimingOperations.joinLines(subs, sel, mode)
    sel = collectEditableSelection(subs, sel)
    if #sel < (mode == "phrase" and 1 or 2) then return sel end
    table.sort(sel)
    local first = subs[sel[1]]
    local parts = {}
    for _, i in ipairs(sel) do parts[#parts+1] = subs[i].text end
    local merged = cloneLine(first)
    for _, index in ipairs(sel) do
        merged.start_time = math.min(merged.start_time, subs[index].start_time)
        merged.end_time = math.max(merged.end_time, subs[index].end_time)
    end
    local leadTags = extractLeadingTagBlocks(first.text)
    local mergedText = TimingOperations.Join.text(parts, mode)
    merged.text = leadTags .. mergedText
    if mode == "second" or mode == "last" then merged.text = subs[sel[mode == "second" and 2 or #sel]].text end
    subs[sel[1]] = merged
    for k = #sel, 2, -1 do subs.delete(sel[k]) end
    return { sel[1] }
end

SmartOperations.Split = (function()
local Core, LineOps, UI = Kite.Core, Kite.LineOps, KiteUI
local Split = {}
local floor, ceil, min, max, abs, log = math.floor, math.ceil, math.min, math.max, math.abs, math.log
local trim, clamp = trimText, Core.clamp
local settings = UI.settings(script_namespace .. ".SmartSplit", script_version, {main={mode="Continuo", wave_path=""}})
local cache = {}
local CANCEL = {}
local function checkCancelled()
    if aegisub.progress and aegisub.progress.is_cancelled and aegisub.progress.is_cancelled() then error(CANCEL, 0) end
end
local function progress(label, percent)
    checkCancelled()
    LineOps.progress(label, percent)
end
local function round10(value) return Core.round(value / 10) * 10 end
local function addFlag(flags, flag) flags[flag] = true end


local terminals, closers = sentenceSplitChars, closingPunctuation
local whitespace = isWhitespaceChar
local hasText = hasVisibleSegmentText

function Split.sentences(text, comma)
    local chars, output, part, history = splitUtf8Chars(text), {}, {}, {}
    local inherited, i = "", 1
    local function flush()
        local value = trim(table.concat(part))
        if hasText(value) then
            output[#output+1] = inherited .. value
        elseif value ~= "" and #output > 0 then
            output[#output] = output[#output] .. value
        end
        part = {}
        inherited = table.concat(history)
    end
    while i <= #chars do
        if chars[i] == "{" then
            local block = {}
            repeat
                local ch = chars[i]
                block[#block+1] = ch
                i = i + 1
                if ch == "}" then break end
            until i > #chars
            block = table.concat(block)
            part[#part+1] = block
            if block:match("^%{%s*\\") then history[#history+1] = block end
        else
            local ch = chars[i]
            part[#part+1] = ch
            local split = terminals[ch] or (comma and commaSplitChars[ch]) or (ch == "-" and chars[i-1] == " " and chars[i+1] == " ")
            i = i + 1
            if split then
                while terminals[chars[i]] or (comma and commaSplitChars[chars[i]]) do part[#part+1] = chars[i]; i = i+1 end
                while closers[chars[i]] do part[#part+1] = chars[i]; i = i+1 end
                flush()
                while whitespace(chars[i]) do i = i+1 end
            end
        end
    end
    flush()
    return output
end

local function textWeight(text)
    local n = 0
    for _, ch in ipairs(LineOps.graphemes(LineOps.visibleText(text))) do
        if not whitespace(ch) and not ch:match("^%p$") and not utf8PunctuationChars[ch] then n = n+1 end
    end
    return max(1, n)
end



function Split.readWave(path)
    return require("kite.Timing").Waveform.read(path, progress, checkCancelled)
end

local function runs(mask)
    local result, i = {}, 1
    while i <= #mask do
        local first, value = i, mask[i]
        repeat i=i+1 until i>#mask or mask[i] ~= value
        result[#result+1] = {a=first, b=i-1, active=value}
    end
    return result
end
local function percentile(sorted, fraction)
    return sorted[max(1, min(#sorted, floor((#sorted-1)*fraction+1.5)))]
end
local function threshold(values)
    local sorted = {}
    for i,v in ipairs(values) do sorted[i]=v end
    table.sort(sorted)
    local lo, hi = percentile(sorted, 0.01), percentile(sorted, 0.99)
    if hi-lo < 0.15 then return hi, lo, hi, false end
    local bins, total, weighted = {}, #values, 0
    for i=1,96 do bins[i]=0 end
    for _,v in ipairs(values) do
        local bin = clamp(floor((v-lo)/(hi-lo)*95)+1, 1, 96)
        bins[bin]=bins[bin]+1
        weighted=weighted+bin
    end
    local left, sum, best, cut = 0, 0, -1, 1
    for i=1,95 do
        left=left+bins[i]; sum=sum+i*bins[i]
        if left>0 and left<total then
            local difference=sum/left-(weighted-sum)/(total-left)
            local score=left*(total-left)*difference*difference
            if score>best then best,cut=score,i end
        end
    end
    return lo+(cut-0.5)*(hi-lo)/96, lo, hi, true
end

function Split.analyze(wave, startMs, endMs)
    if startMs < wave.origin or endMs > wave.origin+wave.duration+0.001 then return nil, "COVERAGE" end
    local step = max(10, wave.point_ms)
    local values, edges = {}, {startMs}
    local time = startMs
    while time < endMs do
        local finish = min(endMs, time+step)
        local a = clamp(floor((time-wave.origin)/wave.point_ms), 0, wave.n-1)
        local b = clamp(ceil((finish-wave.origin)/wave.point_ms), a+1, wave.n)
        values[#values+1] = log(1+(wave.prefix[b]-wave.prefix[a])/(b-a))
        edges[#edges+1] = finish
        time=finish
        if #values % 10000 == 0 then checkCancelled() end
    end
    local high, noise, peak, structured = threshold(values)
    local low = noise + (high-noise)*0.45
    local support, raw = {}, {}
    for i,v in ipairs(values) do support[i] = structured and v>low; raw[i]=false end

    for _,run in ipairs(runs(support)) do
        if run.active then
            local seeded=false
            for i=run.a,run.b do if values[i]>=high then seeded=true; break end end
            if seeded then for i=run.a,run.b do raw[i]=true end end
        end
    end
    local clean = {}
    for i,v in ipairs(raw) do clean[i]=v end
    local rawRuns=runs(raw)
    for index,run in ipairs(rawRuns) do
        if not run.active and index>1 and index<#rawRuns and edges[run.b+1]-edges[run.a]<=60 then
            for i=run.a,run.b do clean[i]=true end
        end
    end
    local cleaned=runs(clean)
    for index,run in ipairs(cleaned) do
        if run.active and index>2 and index<#cleaned-1 and edges[run.b+1]-edges[run.a]<60 then
            for i=run.a,run.b do clean[i]=false end
        end
    end
    local prefix, nextActive, prevActive = {[0]=0}, {}, {}
    local last
    for i,v in ipairs(raw) do
        prefix[i]=prefix[i-1]+(v and edges[i+1]-edges[i] or 0)
        if v then last=i end
        prevActive[i]=last
    end
    last=nil
    for i=#raw,1,-1 do
        if raw[i] then last=i end
        nextActive[i]=last
    end
    if prefix[#raw]<=0 then return nil, "NO-AUDIO" end
    return {values=values, edges=edges, raw=raw, clean=clean, runs=rawRuns,
        prefix=prefix, nextActive=nextActive, prevActive=prevActive,
        step=step, high=high, low=low, noise=noise, peak=peak, n=#raw,
        first=edges[nextActive[1]], last=edges[prevActive[#raw]+1]}
end

local function indexAt(analysis, time)
    return clamp(floor((time-analysis.edges[1])/analysis.step)+1, 1, analysis.n)
end
local function activityAt(analysis, time)
    if time<=analysis.edges[1] then return 0 end
    if time>=analysis.edges[analysis.n+1] then return analysis.prefix[analysis.n] end
    local i=indexAt(analysis,time)
    return analysis.prefix[i-1]+(analysis.raw[i] and time-analysis.edges[i] or 0)
end
local function activeSpan(analysis, a, b)
    local first=analysis.nextActive[indexAt(analysis,a)]
    local last=analysis.prevActive[indexAt(analysis,b-0.00001)]
    if not first or not last or first>last then return nil end
    local s,e=max(a,analysis.edges[first]),min(b,analysis.edges[last+1])
    if e<=s then return nil end
    return s,e
end

function Split.candidates(analysis, weights, startMs, endMs)
    local byTime={}
    local function add(time, cost, kind, gapA, gapB)
        time=round10(time)
        if time<=startMs or time>=endMs then return end
        if gapA and (time<gapA or time>gapB) then kind,cost="VALLEY",max(cost,2) end
        local old=byTime[time]
        if not old or cost<old.cost then byTime[time]={t=time,cost=cost,kind=kind,gap_a=gapA,gap_b=gapB} end
    end
    for index,run in ipairs(analysis.runs) do
        if not run.active and index>1 and index<#analysis.runs then
            local a,b=analysis.edges[run.a],analysis.edges[run.b+1]
            local sum=0
            for i=run.a,run.b do sum=sum+analysis.values[i] end
            local depth=clamp((analysis.high-sum/(run.b-run.a+1))/max(0.01,analysis.high-analysis.noise),0,1)
            local stable=false
            for i=run.a,run.b do if not analysis.clean[i] then stable=true; break end end
            local quality=0.65*min(1,(b-a)/250)+0.35*depth
            add((a+b)/2,1-quality+(stable and 0 or 0.25),stable and "GAP" or "MICRO",a,b)
        end
    end


    local stride=max(1,ceil(80/analysis.step))
    for first=2,analysis.n-1,stride do
        local best=first
        for i=first,min(analysis.n-1,first+stride-1) do
            if analysis.values[i]<analysis.values[best] then best=i end
        end
        if analysis.raw[best] then
            local energy=clamp((analysis.values[best]-analysis.noise)/max(0.01,analysis.peak-analysis.noise),0,1)
            add((analysis.edges[best]+analysis.edges[best+1])/2,2+energy,"VALLEY")
        end
    end
    local total, accumulated=0,0
    for _,w in ipairs(weights) do total=total+w end
    for i=1,#weights-1 do
        accumulated=accumulated+weights[i]
        local target=analysis.prefix[analysis.n]*accumulated/total
        local lo,hi=1,analysis.n
        while lo<hi do
            local mid=floor((lo+hi)/2)
            if analysis.prefix[mid]<target then lo=mid+1 else hi=mid end
        end
        add(analysis.edges[lo]+target-analysis.prefix[lo-1],2.75,"VALLEY")
        add(startMs+(endMs-startMs)*accumulated/total,3,"ESTIMATED")
    end
    local candidates={{t=startMs,cost=0,kind="EDGE"}}
    for _,candidate in pairs(byTime) do candidates[#candidates+1]=candidate end
    candidates[#candidates+1]={t=endMs,cost=0,kind="EDGE"}
    table.sort(candidates,function(a,b) return a.t<b.t end)
    for _,candidate in ipairs(candidates) do candidate.u=activityAt(analysis,candidate.t) end
    return candidates
end

local function ratePenalty(actual, expected)
    return min(2,abs(log(max(0.000001,actual)/max(0.000001,expected))))
end

function Split.align(analysis, weights, candidates)
    local count, size=#weights,#candidates
    local total, cumulative=0,{[0]=0}
    for i,w in ipairs(weights) do total=total+w; cumulative[i]=total end
    local voice=analysis.prefix[analysis.n]
    local extent=analysis.last-analysis.first
    local previous={[1]={{score=0}}}
    local layers={}
    local operations=0

    for phrase=1,count do
        local current={}
        local jFirst,jLast=2,size-1
        if phrase==count then jFirst,jLast=size,size end
        for j=jFirst,jLast do
            local right=candidates[j]
            local best,second
            for i=1,j-1 do
                local states=previous[i]
                local left=candidates[i]
                if states and right.t-left.t>=10 and right.u>left.u then
                    local a,b=activeSpan(analysis,left.t,right.t)
                    if a then
                        local expected=weights[phrase]/total
                        local penalty=0.55*ratePenalty((right.u-left.u)/voice,expected)
                            +0.20*ratePenalty((b-a)/extent,expected)
                        if phrase<count then
                            penalty=penalty+right.cost+0.15*abs(right.u/voice-cumulative[phrase]/total)
                        end
                        for rank,state in ipairs(states) do
                            local candidate={score=state.score+penalty, previous=i, rank=rank}
                            if not best or candidate.score<best.score then second,best=best,candidate
                            elseif not second or candidate.score<second.score then second=candidate end
                        end
                    end
                end
                operations=operations+1
                if operations%20000==0 then checkCancelled() end
            end
            if best then current[j]={best,second} end
        end
        layers[phrase]=current
        previous=current
    end
    local final=previous[size]
    if not final then return nil end
    local function recover(rank)
        local cuts,position={},size
        for phrase=count,1,-1 do
            local state=layers[phrase][position][rank]
            cuts[phrase]=position
            position,rank=state.previous,state.rank
        end
        cuts[0]=1
        return cuts
    end
    local cuts,uncertain=recover(1),{}
    if final[2] and final[2].score-final[1].score<=max(0.10,0.05*abs(final[1].score)) then
        local alternative=recover(2)
        for i=1,count-1 do
            if abs(candidates[cuts[i]].t-candidates[alternative[i]].t)>=80 then uncertain[i]=true end
        end
    end
    return {cuts=cuts, uncertain=uncertain, score=final[1].score,
        second_score=final[2] and final[2].score, candidates=candidates}
end

local function estimated(weights,startMs,endMs)
    local count,total=#weights,0
    for _,w in ipairs(weights) do total=total+w end
    local boundaries,accumulated={[0]=startMs},0
    for i=1,count-1 do
        accumulated=accumulated+weights[i]
        local lower=ceil((boundaries[i-1]+10)/10)*10
        local upper=floor((endMs-(count-i)*10)/10)*10
        if lower>upper then return nil end
        boundaries[i]=clamp(round10(startMs+(endMs-startMs)*accumulated/total),lower,upper)
    end
    boundaries[count]=endMs
    return boundaries
end

function Split.planLine(line,wave,mode)
    local phrases=Split.sentences(line.text)
    if #phrases<2 then return nil,"ONE-SENTENCE" end
    local startMs,endMs=Core.finiteNumber(line.start_time),Core.finiteNumber(line.end_time)
    if not startMs or not endMs or startMs<0 or endMs-startMs<#phrases*10 then return nil,"DURATION" end
    local weights={}
    for i,text in ipairs(phrases) do weights[i]=textWeight(text) end
    local fallback=estimated(weights,startMs,endMs)
    if not fallback then return nil,"DURATION" end
    local analysis,reason=Split.analyze(wave,startMs,endMs)
    local alignment
    if analysis then alignment=Split.align(analysis,weights,Split.candidates(analysis,weights,startMs,endMs)) end
    if not alignment and not reason then reason="NO-PATH" end
    local results={}
    for i,text in ipairs(phrases) do
        local flags={}
        local a,b=fallback[i-1],fallback[i]
        if alignment then
            local left,right=alignment.candidates[alignment.cuts[i-1]],alignment.candidates[alignment.cuts[i]]
            a,b=left.t,right.t
            if (i>1 and left.kind~="GAP") or (i<#phrases and right.kind~="GAP") then addFlag(flags,"CUT") end
            if alignment.uncertain[i-1] or alignment.uncertain[i] then addFlag(flags,"AMBIGUOUS") end
            if mode=="Raw" then
                local voiceA,voiceB=activeSpan(analysis,a,b)
                local trimmedA=max(a,floor(voiceA/10)*10)
                local trimmedB=min(b,ceil(voiceB/10)*10)

                if i~=1 or voiceA-startMs>=max(30,2*analysis.step) then a=trimmedA end
                if i~=#phrases or endMs-voiceB>=max(30,2*analysis.step) then b=trimmedB end
            end
            if analysis.step>20 then addFlag(flags,"RESOLUTION") end
        else
            addFlag(flags,"ESTIMATED"); addFlag(flags,reason)
        end
        local new=LineOps.copy(line)
        new.text,new.start_time,new.end_time=text,a,b
        local names={}
        for flag in pairs(flags) do names[#names+1]=flag end
        table.sort(names)
        local effect=tostring(new.effect or "")
        for _,flag in ipairs(names) do
            local marker="[CS-"..flag.."]"
            if not effect:find(marker,1,true) then effect=effect..(effect~="" and " " or "")..marker end
        end
        new.effect=effect
        results[i]={line=new,flags=names}
    end
    return {segments=results,analysis=analysis,alignment=alignment,estimated=not alignment}
end

local function skipReason(line)
    if line.class~="dialogue" or line.comment then return "COMMENT" end
    if LineOps.hasDrawing(line.text) then return "DRAWING" end
    local effect=tostring(line.effect or ""):lower()
    if effect:find("template",1,true) or effect:find("karaoke",1,true) or effect:match("^code") then return "FX" end
    for _,call in ipairs(LineOps.tagCalls(line.text)) do
        local name=call.name:lower()
        if name=="k" or name=="kf" or name=="ko" or name=="kt" or name=="t" or name=="move" or name=="fad" or name=="fade" then return "FX" end
    end
end

function Split.process(subs,selection,wave,mode)
    local indices=LineOps.normalizeIndices(subs,selection)
    local plans,summary={}, {split=0,created=0,flagged=0,estimated=0,skipped=0,reasons={}}
    for position,index in ipairs(indices) do
        progress("Smart Split: analizando línea "..position.."/"..#indices,15+70*(position-1)/max(1,#indices))
        local line=subs[index]
        local reason=skipReason(line)
        local plan
        if not reason then plan,reason=Split.planLine(line,wave,mode) end
        if plan then
            plans[index]=plan
            summary.split=summary.split+1
            summary.created=summary.created+#plan.segments
            if plan.estimated then summary.estimated=summary.estimated+1 end
            for _,segment in ipairs(plan.segments) do if #segment.flags>0 then summary.flagged=summary.flagged+1 end end

            plan.analysis,plan.alignment=nil,nil
        else
            summary.skipped=summary.skipped+1
            summary.reasons[reason]=(summary.reasons[reason] or 0)+1
        end
    end
    checkCancelled()
    if summary.split==0 then return indices,summary end
    local remapped={}
    local offset=0
    for _,index in ipairs(indices) do
        local count=plans[index] and #plans[index].segments or 1
        for i=0,count-1 do remapped[#remapped+1]=index+offset+i end
        offset=offset+count-1
    end
    LineOps.transaction(subs,"Smart Split - "..mode,function()
        for i=#indices,1,-1 do
            checkCancelled()
            local index=indices[i]
            local plan=plans[index]
            if plan then
                subs[index]=plan.segments[1].line
                for j=#plan.segments,2,-1 do subs.insert(index+1,plan.segments[j].line) end
            end
        end
    end)
    return remapped,summary
end

local reasonNames={COMMENT="Comentarios u otras filas",DRAWING="Dibujos",FX="Karaoke/efectos temporales",["ONE-SENTENCE"]="Una sola frase",DURATION="Duración insuficiente o inválida"}
function Split.main(subs,selection)
    local cfg=settings:values("main")
    local path=cfg.wave_path or ""
    local mode=cfg.mode=="Raw" and "Raw" or "Continuo"
    while true do
        local button,result=UI.workflow("Smart Split","Frases en orden · islas de voz · CPS como orientación",{
            {class="label",label="JSON de onda:",x=0,y=0,width=7,height=1},
            {class="edit",name="wave_path",text=path,x=7,y=0,width=33,height=1},
            {class="label",label="Modo:",x=0,y=1,width=7,height=1},
            {class="dropdown",name="mode",items={"Continuo","Raw"},value=mode,x=7,y=1,width=12,height=1},
            {class="checkbox",name="reload",label="Recargar onda",value=false,x=20,y=1,width=20,height=1},
            {class="label",label="Continuo conserva los extremos y corta en el centro de las pausas.",x=0,y=2,width=40,height=1},
            {class="label",label="Raw ajusta cada frase a su actividad. Las dudas se marcan en Effect.",x=0,y=3,width=40,height=1},
        },{"Dividir","Examinar...","Cancelar"},{ok="Dividir",close="Cancelar"})
        if not button or button=="Cancelar" then return selection end
        path,mode=trim(result.wave_path),result.mode=="Raw" and "Raw" or "Continuo"
        if button=="Examinar..." then
            local picked=aegisub.dialog.open("Elige el JSON de Wave2json","",path,"JSON (*.json)|*.json",false,true)
            if picked and picked~="" then path=picked end
        elseif button=="Dividir" then
            if path=="" then UI.message("Selecciona el JSON de onda.") else
                local ok,newSelection,summary=pcall(function()
                    if result.reload or cache.path~=path or not cache.wave then
                        local wave=Split.readWave(path)
                        cache={path=path,wave=wave}
                        collectgarbage("collect")
                    end
                    return Split.process(subs,selection,cache.wave,mode)
                end)
                if not ok then
                    if newSelection==CANCEL then return selection end
                    UI.message("Smart Split: "..tostring(newSelection))
                    return selection
                end
                settings:update("main",{mode=mode,wave_path=path})
                local saved,message=settings:write()
                local lines={string.format("Divididas: %d | Frases: %d | Frases marcadas: %d\nOriginales con reparto estimado: %d | Omitidas: %d",summary.split,summary.created,summary.flagged,summary.estimated,summary.skipped)}
                local reasons={}
                for reason,count in pairs(summary.reasons) do reasons[#reasons+1]=(reasonNames[reason] or reason)..": "..count end
                table.sort(reasons)
                for _,reason in ipairs(reasons) do lines[#lines+1]=reason end
                if not saved then lines[#lines+1]="No se guardaron las preferencias: "..tostring(message) end
                UI.message(table.concat(lines,"\n"))
                return newSelection,newSelection[1]
            end
        else return selection end
    end
end

return Split
end)()

TimingOperations.Join = {}
do
    local Join = TimingOperations.Join
    function Join.continues(text)
        local chars = splitUtf8Chars(trimText(text))
        while #chars > 0 and (closingPunctuation[chars[#chars]] or isWhitespaceChar(chars[#chars])) do table.remove(chars) end
        local last = chars[#chars]
        return last == "," or last == horizontalEllipsis or last == twoDotLeader
            or (#chars >= 3 and last == "." and chars[#chars-1] == "." and chars[#chars-2] == ".")
    end

    function Join.onePhrase(text)
        local chars, output = splitUtf8Chars(text), {}
        local lower, index = false, 1
        local abbreviations = {sr=true, sra=true, srta=true, dr=true, dra=true, prof=true, ud=true, uds=true, etc=true}
        while index <= #chars do
            local char = chars[index]
            if char == "." and chars[index-1] ~= "." and chars[index+1] ~= "." and isWhitespaceChar(chars[index+1]) then
                local word, cursor = {}, index - 1
                while cursor > 0 and isLetter(chars[cursor]) do table.insert(word, 1, chars[cursor]); cursor = cursor - 1 end
                local nextIndex = index + 1
                while isWhitespaceChar(chars[nextIndex]) do nextIndex = nextIndex + 1 end
                if chars[nextIndex] and #word > 1 and not abbreviations[unicodeLower(table.concat(word))] then
                    char, lower = ",", true
                end
            elseif lower and isLetter(char) then
                local word, cursor = {}, index
                while chars[cursor] and isLetter(chars[cursor]) do word[#word+1] = chars[cursor]; cursor = cursor + 1 end
                local value = table.concat(word)
                if #word == 1 or unicodeUpper(value) ~= value then char = unicodeLower(char) end
                lower = false
            end
            output[#output+1] = char
            index = index + 1
        end
        return table.concat(output)
    end

    function Join.text(parts, mode)
        local values, previous = {}, nil
        for _, part in ipairs(parts) do
            local value = trimText(Kite.LineOps.visibleText(part)):gsub("%s+", " ")
            if value ~= "" then
                if previous and Join.continues(previous) then value = changeFirstLetter(value, false) end
                values[#values+1], previous = value, value
            end
        end
        local text = joinTextParts(values)
        if mode == "clean" then
            local ending = text:match("(%.%.%.+)$") or (endsWith(text, horizontalEllipsis) and horizontalEllipsis)
                or (endsWith(text, twoDotLeader) and twoDotLeader) or ""
            if ending ~= "" then text = text:sub(1, #text - #ending) end
            text = trimText(text:gsub(horizontalEllipsis, " "):gsub(twoDotLeader, " "):gsub("%.%.%.+", " ")):gsub("%s+", " ") .. ending
        elseif mode == "phrase" then text = Join.onePhrase(text) end
        return text
    end
end

function TimingOperations.joinDialog(subs, sel)
    local labels = {
        en = {"Join", "Keep Second", "Keep Last", "No Inner ...", "One Phrase", "Cancel",
            "Join: combines text. Keep Second: exactly two rows; keeps the second text.\nKeep Last: keeps the last selected text. No Inner ...: removes inner ellipses.\nOne Phrase: joins sentences with commas and lowers the next initial.\nKeeps the first row's fields and expands its time range. Review names in One Phrase."},
        es = {"Unir", "Conservar segunda", "Conservar última", "Sin ... internos", "Una frase", "Cancelar",
            "Unir: combina textos. Segunda: exige dos filas y conserva el segundo texto.\nÚltima: conserva el último texto seleccionado. Sin ...: quita puntos suspensivos internos.\nUna frase: une oraciones con comas y baja la inicial siguiente.\nConserva los campos de la primera fila y amplía sus tiempos. Revisa nombres en Una frase."},
        pt = {"Unir", "Manter segunda", "Manter última", "Sem ... internos", "Uma frase", "Cancelar",
            "Unir: combina textos. Segunda: exige duas linhas e mantém o segundo texto.\nÚltima: mantém o último texto selecionado. Sem ...: remove reticências internas.\nUma frase: une orações com vírgulas e baixa a inicial seguinte.\nMantém os campos da primeira linha e amplia os tempos. Revise nomes em Uma frase."},
    }
    local text = labels[currentConfig.language] or labels.en
    local button = aegisub.dialog.display({{class="label", label=text[7], x=0, y=0, width=1, height=4}},
        {text[1],text[2],text[3],text[4],text[5],text[6]}, {close=text[6]})
    local modes = {[text[1]]="normal", [text[2]]="second", [text[3]]="last", [text[4]]="clean", [text[5]]="phrase"}
    local mode = modes[button]
    if not mode then return sel end
    local indices = Kite.LineOps.normalizeIndices(subs, sel, isEditableDialogue)
    if #indices < (mode == "phrase" and 1 or 2) or (mode == "second" and #indices ~= 2) then
        showMsg(mode == "second" and "Keep Second: select exactly two dialogue lines." or "Select at least two dialogue lines.")
        return sel
    end
    return Kite.LineOps.transaction(subs, "Chrono Suite - Joinator", function()
        Kite.LineOps.checkCancelled()
        return TimingOperations.joinLines(subs, indices, mode)
    end)
end

function TimingOperations.shiftFollowing(subs, sel, active)
    if not active or active < 1 or active >= #subs or not isDialogue(subs[active]) then return sel, active end
    local indices = {}
    for index = active + 1, #subs do
        if isDialogue(subs[index]) then indices[#indices+1] = index end
    end
    if #indices == 0 then return sel, active end
    local delta = subs[active].end_time + 100 - subs[indices[1]].start_time
    if delta == 0 then return sel, active end
    for _, index in ipairs(indices) do
        Kite.LineOps.checkCancelled()
        local line = subs[index]
        if line.start_time + delta < 0 or line.end_time + delta < 0 then
            showMsg("Shift Following Lines: a lower row would start or end before 0 ms.")
            return sel, active
        end
    end
    return Kite.LineOps.transaction(subs, "Chrono Suite - Shift Following Lines", function()
        for _, index in ipairs(indices) do
            Kite.LineOps.checkCancelled()
            local line = subs[index]
            line.start_time, line.end_time = line.start_time + delta, line.end_time + delta
            subs[index] = line
        end
        return sel, active
    end)
end

local function splitTextByPunctuation(text, comma)
    local segments = SmartOperations.Split.sentences(text, comma)
    if #segments >= 2 then return segments end
end

local function splitLineByPunctuationFallback(subs, i, comma)
    local l = subs[i]
    if not isEditableDialogue(l) or not validateDuration(l) then return 0 end
    local segments = splitTextByPunctuation(l.text, comma); if not segments then return 0 end
    local weights = {}; for k, s in ipairs(segments) do weights[k] = countCharacters(s) end
    local durations = allocateDurationsByWeights(weights, l.end_time - l.start_time); if not durations then return 0 end
    local cur = l.start_time
    for k, seg in ipairs(segments) do
        local nl = cloneLine(l); nl.text = seg
        nl.start_time = cur; nl.end_time = cur + durations[k]
        if k == 1 then subs[i] = nl else subs.insert(i + k - 1, nl) end
        cur = nl.end_time
    end
    return #segments - 1
end

local function splitLineByPunctuation(subs, sel, comma)
    table.sort(sel, function(a, b) return a > b end)
    local inserted = {}
    for _, i in ipairs(sel) do inserted[i] = splitLineByPunctuationFallback(subs, i, comma) end
    return remapSelectionAfterInsertion(sel, inserted)
end

function TimingOperations.splitBySentence(subs, sel) return splitLineByPunctuation(subs, sel, false) end
function TimingOperations.splitByComma(subs, sel)    return splitLineByPunctuation(subs, sel, true) end

local function countWordsBeforeLinebreak(text)
    local before = normalizeString(text)
    local nPos = before:find("\\[Nn]")
    if not nPos then return nil end
    before = before:sub(1, nPos - 1)
    local count, inWord, depth = 0, false, 0
    for _, ch in ipairs(splitUtf8Chars(before)) do
        if ch == "{" then depth = depth + 1; inWord = false
        elseif ch == "}" then depth = math.max(0, depth - 1); inWord = false
        elseif depth > 0 then
        elseif isWhitespaceChar(ch) then inWord = false
        elseif not inWord then count = count + 1; inWord = true end
    end
    return count
end

local function pivotLinebreakText(text)
    local beforeCount = countWordsBeforeLinebreak(text)
    if not beforeCount then return text, false end
    local clean = normalizeString(text):gsub("\\[Nn]", " ")
    clean = clean:gsub("[ \t]+", " ")
    clean = trimText(clean)
    local chars = splitUtf8Chars(clean)
    local words, inWord, depth = {}, false, 0
    for idx, ch in ipairs(chars) do
        if ch == "{" then
            if inWord then words[#words].finish = idx - 1; inWord = false end
            depth = depth + 1
        elseif ch == "}" then
            depth = math.max(0, depth - 1)
        elseif depth == 0 and isWhitespaceChar(ch) then
            if inWord then words[#words].finish = idx - 1; inWord = false end
        elseif depth == 0 and not inWord then
            words[#words+1] = { start = idx, finish = idx }
            inWord = true
        elseif depth == 0 and inWord then
            words[#words].finish = idx
        end
    end
    if #words < 2 then return text, false end
    local candidateCount = #words - 1
    local target = beforeCount + 1
    if target > candidateCount then target = 1 end
    if target < 1 then target = 1 end
    local splitAt = words[target].finish
    local left, right = {}, {}
    for idx = 1, splitAt do left[#left+1] = chars[idx] end
    for idx = splitAt + 1, #chars do right[#right+1] = chars[idx] end
    return trimText(table.concat(left)) .. " \\N" .. trimText(table.concat(right)), true
end

function TimingOperations.pivotLinebreak(subs, sel)
    for _, i in ipairs(sel) do
        local l = subs[i]
        if isEditableDialogue(l) and normalizeString(l.text):find("\\[Nn]") then
            local changed
            l.text, changed = pivotLinebreakText(l.text)
            if changed then subs[i] = l end
        end
    end
end

function TimingOperations.splitByLinebreak(subs, sel)
    table.sort(sel, function(a, b) return a > b end)
    local inserted = {}
    for _, i in ipairs(sel) do
        local l = subs[i]
        if isEditableDialogue(l) and normalizeString(l.text):find("\\[Nn]") and validateDuration(l) then
            local parts = splitTextAtLinebreaks(l.text)
            if #parts >= 2 then
                local inherited = extractLeadingTagBlocks(l.text)
                local final = {}
                for _, p in ipairs(parts) do
                    local seg = ensureInheritedTags(p, inherited)
                    if hasVisibleSegmentText(seg) then final[#final+1] = seg end
                end
                if #final >= 2 then
                    local alloc = allocateTimeDuration(final, l.end_time - l.start_time)
                    if alloc then
                        local first = cloneLine(l); first.text = final[1]; first.end_time = first.start_time + alloc[1]
                        subs[i] = first; local cur = first.end_time
                        for p = 2, #final do
                            local nl = cloneLine(l); nl.text = final[p]
                            nl.start_time = cur; nl.end_time = cur + alloc[p]
                            subs.insert(i + p - 1, nl); cur = nl.end_time
                        end
                        inserted[i] = #final - 1
                    end
                end
            end
        end
    end
    return remapSelectionAfterInsertion(sel, inserted)
end

function TimingOperations.smartLineBreak(subs, sel)
    local meta, styles
    if karaskel and type(karaskel.collect_head) == "function" then
        local ok, m, s = pcall(karaskel.collect_head, subs, false)
        if ok then meta, styles = m, s end
    end
    local scriptWidth = meta and normalizeNumber(meta.res_x, 0) or 0
    if scriptWidth <= 0 then
        local ok, w = pcall(function() return aegisub.video_size() end)
        scriptWidth = ok and normalizeNumber(type(w) == "table" and w.width or w, 0) or 0
        if scriptWidth <= 0 then scriptWidth = 1920 end
    end
    local function tagTokens(block)
        if Kite.LineOps and Kite.LineOps.overrideTokens then
            return Kite.LineOps.overrideTokens(block)
        end
        local tokens = {}

        block = block:gsub("%b()", "")
        for raw in block:gmatch("\\([^\\]+)") do
            for _, name in ipairs({"fscx", "fscy", "fsp", "fn", "fs", "r", "b", "i", "p"}) do
                if raw:sub(1, #name) == name then
                    local value = trimText(raw:sub(#name + 1))
                    if name == "fn" or name == "r" or value == "" or tonumber(value) then
                        tokens[#tokens+1] = {name=name, value=value}
                        break
                    end
                end
            end
        end
        return tokens
    end
    local function sections(text)
        if Kite.LineOps and Kite.LineOps.scanSections then return Kite.LineOps.scanSections(text) end
        local out, cursor, drawing = {}, 1, false
        while cursor <= #text do
            local a, b = text:find("%b{}", cursor)
            local finish = a and a - 1 or #text
            if finish >= cursor then
                out[#out+1] = {type=drawing and "drawing" or "text", start=cursor,
                    finish=finish, text=text:sub(cursor, finish)}
            end
            if not a then break end
            local block = text:sub(a+1, b-1)
            out[#out+1] = {type="override", start=a, finish=b, text=block}
            for _, token in ipairs(tagTokens(block)) do
                if token.name == "p" then drawing = (tonumber(token.value) or 0) > 0
                elseif token.name == "r" then drawing = false end
            end
            cursor = b + 1
        end
        return out
    end
    local function tokenize(text)
        local tokens, hasBreak, hasDrawing = {}, false, false
        for _, section in ipairs(sections(text)) do
            if section.type ~= "text" then
                tokens[#tokens+1] = {kind=section.type, raw=text:sub(section.start, section.finish),
                    tags=section.type == "override" and tagTokens(section.text) or {}}
                hasDrawing = hasDrawing or section.type == "drawing"
            else
                local cursor = 1
                while cursor <= #section.text do
                    local a, b = section.text:find("[ \t]+", cursor)
                    local e = section.text:find("\\[Nnh]", cursor)
                    if e and (not a or e < a) then a, b = e, e+1 end
                    if not a then a, b = #section.text+1, #section.text end
                    if a > cursor then
                        tokens[#tokens+1] = {kind="text", raw=section.text:sub(cursor, a-1)}
                    end
                    if a <= #section.text then
                        local raw = section.text:sub(a, b)
                        local kind = raw == "\\h" and "hardspace"
                            or (raw == "\\N" or raw == "\\n") and "break" or "space"
                        tokens[#tokens+1] = {kind=kind, raw=raw}
                        hasBreak = hasBreak or kind == "break"
                    end
                    cursor = b+1
                end
            end
        end
        return tokens, hasBreak, hasDrawing
    end
    local function join(tokens)
        local out = {}; for _, token in ipairs(tokens) do out[#out+1] = token.raw end
        return table.concat(out)
    end
    local function normalizeBreaks(tokens)
        for i, token in ipairs(tokens) do
            if token.kind == "break" and token.raw == "\\N" then
                local j = i-1
                while j > 0 do
                    local previous = tokens[j]
                    if previous.kind == "space" then previous.raw = ""
                    elseif previous.kind ~= "override" and previous.kind ~= "comment" then break end
                    j = j-1
                end
                local previous = tokens[j]
                if previous and previous.kind == "text" and not endsWith(previous.raw, NBSP) then
                    token.raw = " \\N"
                end
                j = i+1
                while tokens[j] do
                    local following = tokens[j]
                    if following.kind == "space" then following.raw = ""
                    elseif following.kind ~= "override" and following.kind ~= "comment" then break end
                    j = j+1
                end
            end
        end
    end
    local numericTags = {fs="fontsize", fscx="scale_x", fscy="scale_y", fsp="spacing"}
    local function measureRuns(tokens, baseStyle)
        local style, runs, plain = cloneLine(baseStyle), {}, {}
        local resetStyle = baseStyle
        for i, token in ipairs(tokens) do
            local previousStyle = style
            if token.tags and #token.tags > 0 then style = cloneLine(style) end
            local changed = false
            for _, tag in ipairs(token.tags or {}) do
                local value, field = trimText(tag.value), numericTags[tag.name]
                if tag.name == "r" then
                    resetStyle = (value ~= "" and styles and styles[value]) or baseStyle
                    style = cloneLine(resetStyle)
                    changed = true
                elseif tag.name == "fn" then
                    style.fontname = value ~= "" and value ~= "0" and value or resetStyle.fontname; changed = true
                elseif field then
                    local number = tonumber(value)
                    if tag.name == "fs" and value:match("^[+-]") then
                        number = (tonumber(style.fontsize) or 24) * (1 + (number or 0) / 10)
                    end
                    if tag.name == "fs" and number and number <= 0 then number = nil end
                    if (tag.name == "fscx" or tag.name == "fscy") and number then number = math.max(0, number) end
                    style[field] = number or resetStyle[field]; changed = true
                elseif tag.name == "b" or tag.name == "i" then
                    local key = tag.name == "b" and "bold" or "italic"
                    style[key] = value == "" and resetStyle[key] or (tonumber(value) or 0) ~= 0
                    changed = true
                end
            end
            if not changed then style = previousStyle end
            local visible = token.kind == "hardspace" and NBSP
                or (token.kind == "text" or token.kind == "space") and token.raw or ""
            token.visible = visible
            plain[#plain+1] = visible
            if visible ~= "" then
                local run = runs[#runs]
                if not run or run.style ~= style then
                    run = {first=i, last=i, style=style, cache={}}; runs[#runs+1] = run
                end
                run.last = i
            end
        end
        local function width(first, last)
            local total = 0
            for _, run in ipairs(runs) do
                local a, b = math.max(first, run.first), math.min(last, run.last)
                if a <= b then
                    local parts = {}
                    for i = a, b do parts[#parts+1] = tokens[i].visible end
                    local text = table.concat(parts)
                    local w = run.cache[text]
                    if not w then
                        local ok, measured = pcall(function() return aegisub.text_extents(run.style, text) end)
                        w = ok and normalizeNumber(measured, nil) or nil
                        if not w or w < 0 then
                            w = unicodeLenSafe(text) * (tonumber(run.style.fontsize) or 24) * 0.5
                                * (tonumber(run.style.scale_x) or 100) / 100
                        end
                        run.cache[text] = w
                    end
                    total = total + w
                end
            end
            return total
        end
        return width, table.concat(plain)
    end
    local function breakWords(text)
        local words = {}
        for word, finish in text:gmatch("(%S+)()") do
            local tail = word
            while closingPunctuation[unicodeSub(tail, -1)] do tail = unicodeSub(tail, 1, -2) end
            local punctuation = unicodeSub(tail, -1)
            local chars = splitUtf8Chars(word)
            while #chars > 0 and isPunctuationChar(chars[1]) do table.remove(chars, 1) end
            while #chars > 0 and isPunctuationChar(chars[#chars]) do table.remove(chars) end
            if #chars > 0 then
                words[#words+1] = {finish=finish-1,
                    pause=sentenceSplitChars[punctuation] and 2 or commaSplitChars[punctuation] and 1 or 0}
            end
        end
        return words
    end
    local function chooseBreak(candidates, byWord, words, total, available)

        local sizes, previous, gap = {}, 0, 0
        for j, word in ipairs(words) do
            local boundary = byWord[j]
            local prefix = boundary and boundary.upper or total
            word.width = math.max(0, prefix-previous-gap)
            sizes[#sizes+1] = word.width
            previous = prefix
            gap = boundary and math.max(0, total-boundary.upper-boundary.lower) or 0
        end
        if #sizes == 0 then return nil end
        table.sort(sizes)
        local median = math.max(1e-6, (sizes[math.ceil(#sizes/2)] + sizes[math.floor(#sizes/2)+1])/2)
        for _, word in ipairs(words) do word.compact = math.max(0, 1-word.width/median) end
        local function affordable(candidate, completed)
            return completed and completed.overflow <= candidate.overflow
                and completed.maximum <= candidate.maximum + available*0.10
        end
        for _, candidate in ipairs(candidates) do
            local j = candidate.words
            local left, right = words[j], words[j+1]
            local share = candidate.upper/math.max(1e-6, candidate.upper+candidate.lower)
            local cost = 4000*(share-0.51)^2
            if left.pause == 0 then
                cost = cost + 16*right.compact^3

                local valley = math.min(left.compact, right.compact)
                if words[j-1] and words[j+2] and words[j-1].pause == 0 and right.pause == 0 then
                    local scale = math.max(1e-6, math.min(words[j-1].width, words[j+2].width))
                    valley = math.max(valley, math.max(0, 1-2*math.max(left.width,right.width)/scale))
                end
                cost = cost + 24*valley
                if share < 0.5 then
                    local head = j+1
                    while words[head] and words[head].compact > 0.5 and words[head].pause == 0 do head = head+1 end
                    if affordable(candidate, byWord[head]) then
                        local scale = math.max(1e-6, words[head].width)
                        local cohesion, start = math.max(0, 1-2*left.width/scale), j
                        while cohesion > 0 and words[start-1] and words[start-1].width < scale/2 and words[start-1].pause == 0 do
                            start = start-1
                            cohesion = 1-(1-cohesion)*2*words[start].width/scale
                        end

                        cost = cost + 64*cohesion^2*math.min(1, (1-2*share)/0.04)
                    end
                end
            end
            if math.min(j,#words-j) < 2 then cost = cost+150
            elseif math.abs(2*share-1) <= 0.20 then
                if left.pause == 2 then cost = cost-40
                elseif left.pause == 1 then
                    cost = cost-40*math.min(1,available/math.max(1e-6,candidate.upper+candidate.lower))^2
                end
            end
            candidate.cost, candidate.groupPenalty = cost, 0
        end
        local function protect(first, last)
            for _, candidate in ipairs(candidates) do
                if candidate.words >= first and candidate.words < last and affordable(candidate,byWord[last]) then
                    candidate.groupPenalty = 40
                end
            end
        end
        local previousPause, span = nil, 0
        for j, word in ipairs(words) do
            span = span+word.width
            if word.pause > 0 then

                if previousPause and span <= total*0.20 then protect(previousPause+1,j) end
                if word.pause == 1 and words[j+3] and words[j+1].pause == 0 and words[j+2].pause == 0
                    and words[j+2].width < math.min(words[j+1].width,words[j+3].width)/2 then
                    protect(j+1,j+3)
                end
                previousPause, span = word.pause == 1 and j or nil, 0
            end
        end
        local best, bestCost, bestOverflow = nil, math.huge, math.huge
        for _, candidate in ipairs(candidates) do
            local cost = candidate.cost+candidate.groupPenalty
            if candidate.overflow < bestOverflow or (candidate.overflow == bestOverflow and cost < bestCost) then
                best, bestCost, bestOverflow = candidate.index, cost, candidate.overflow
            end
        end
        return best
    end
    for _, i in ipairs(sel) do
        local line = subs[i]
        if isEditableDialogue(line) then
            local tokens, hasBreak, hasDrawing = tokenize(normalizeString(line.text))

            if not hasDrawing then
                if hasBreak then
                    normalizeBreaks(tokens)
                    local text = join(tokens)
                    if text ~= line.text then line.text = text; subs[i] = line end
                else
                    local style = (styles and styles[line.style]) or line.styleref or {}
                    local mL, mR = normalizeNumber(line.margin_l, 0), normalizeNumber(line.margin_r, 0)
                    if mL <= 0 then mL = normalizeNumber(style.margin_l, 0) end
                    if mR <= 0 then mR = normalizeNumber(style.margin_r, 0) end
                    local available = scriptWidth - mL - mR
                    local width, plain = measureRuns(tokens, style)
                    local total = width(1, #tokens)
                    if available > 0 and total > available then
                        local words, candidates, byWord = breakWords(plain), {}, {}
                        local offset, n1 = 0, 0
                        for k, token in ipairs(tokens) do
                            if token.kind == "space" then
                                while words[n1+1] and words[n1+1].finish <= offset do n1 = n1+1 end
                                local n2 = #words-n1
                                if n1 > 0 and n2 > 0 then
                                    local w1, w2 = width(1, k-1), width(k+1, #tokens)
                                    local overflow = math.max(0, w1-available, w2-available)
                                    local candidate = {index=k, words=n1, upper=w1, lower=w2,
                                        maximum=math.max(w1,w2), overflow=overflow}
                                    candidates[#candidates+1], byWord[n1] = candidate, candidate
                                end
                            end
                            offset = offset + #token.visible
                        end
                        local best = chooseBreak(candidates, byWord, words, total, available)
                        if best then
                            tokens[best].kind, tokens[best].raw = "break", "\\N"
                            normalizeBreaks(tokens)
                            line.text = join(tokens); subs[i] = line
                        end
                    end
                end
            end
        end
    end
end

end

local trimWS = trimText

local function parseTime(t)
    t = trimWS(t)
    local h, m, s, frac = t:match("^(%d+):(%d+):(%d+)%.(%d+)$")
    if h then return clockToMs(h, m, s, frac) end
    local h2, m2, s2 = t:match("^(%d+):(%d+):(%d+)$")
    if h2 then return clockToMs(h2, m2, s2, nil) end
    return nil
end

local function timeInt(s1, e1, s2, e2)
    local s, e = math.max(s1, s2), math.min(e1, e2)
    return s < e and (e - s) or 0
end

local function parseDialogue(l)
    l = trimWS(l); if not l:match("^Dialogue:") then return nil end
    local _, fields = splitEventLine(l)
    if not fields then return nil end
    local f = {}
    for i = 1, 10 do f[i] = trimWS(fields[i]) end
    return f
end

local function sameLayerMatch(line, src, sameLayers)
    if not sameLayers then return true end
    return (tonumber(line.layer) or 0) == (tonumber(src.layer) or 0)
end

local function antEffects(subs, sel, raw, sameLayers)
    local src = {}
    for l in raw:gmatch("[^\r\n]+") do
        local f = parseDialogue(l)
        if f then
            local s, e, ef, ly = parseTime(f[2]), parseTime(f[3]), f[9], tonumber(f[1]) or 0
            if s and e and ef ~= "" then table.insert(src, { start = s, end_time = e, effect = ef, layer = ly }) end
        end
    end
    if #src == 0 then return 0 end
    local mod = 0
    for _, i in ipairs(sel) do
        local l = subs[i]; local add = {}
        for _, s in ipairs(src) do
            if sameLayerMatch(l, s, sameLayers) and timeInt(l.start_time, l.end_time, s.start, s.end_time) > 0 then table.insert(add, s.effect) end
        end
        if #add > 0 then
            if l.effect ~= "" then table.insert(add, 1, l.effect) end
            l.effect = table.concat(add, "; "); mod = mod + 1
        end
        subs[i] = l
    end
    return mod
end

local function antLines(subs, sel, raw, comm, sameLayers)
    local src = {}
    for l in raw:gmatch("[^\r\n]+") do
        local f = parseDialogue(l)
        if f then
            local s, e, tx, ly = parseTime(f[2]), parseTime(f[3]), f[10], tonumber(f[1]) or 0
            if s and e and tx ~= "" and not tx:match("^{=%d+}$") then
                table.insert(src, { start = s, end_time = e, text = tx, layer = ly })
            end
        end
    end
    if #src == 0 then return 0 end
    local mod = 0
    for _, i in ipairs(sel) do
        local l = subs[i]; local add = ""
        for _, s in ipairs(src) do
            if sameLayerMatch(l, s, sameLayers) and timeInt(l.start_time, l.end_time, s.start, s.end_time) > 0 then
                local t = comm and ("{" .. s.text .. "}") or s.text
                add = (add == "" and t or add .. " " .. t)
            end
        end
        if add ~= "" then l.text = l.text .. " " .. add; mod = mod + 1 end
        subs[i] = l
    end
    return mod
end

local function antActor(subs, sel, raw, sameLayers)
    local src = {}
    for l in raw:gmatch("[^\r\n]+") do
        local f = parseDialogue(l)
        if f then
            local s, e, ac, ly = parseTime(f[2]), parseTime(f[3]), f[5], tonumber(f[1]) or 0
            if s and e and ac ~= "" then table.insert(src, { start = s, end_time = e, actor = ac, layer = ly }) end
        end
    end
    if #src == 0 then return 0 end
    local mod = 0
    for _, i in ipairs(sel) do
        local l = subs[i]; local ba, bd = nil, 0
        for _, s in ipairs(src) do
            if sameLayerMatch(l, s, sameLayers) then
                local d = timeInt(l.start_time, l.end_time, s.start, s.end_time)
                if d > bd then bd, ba = d, s.actor end
            end
        end
        if ba then l.actor = ba; mod = mod + 1 end
        subs[i] = l
    end
    return mod
end

local DataImportOps = {}
function DataImportOps.importLines(subs, sel, raw)
    local source = {}
    for row in normalizeString(raw):gmatch("[^\r\n]+") do
        Kite.LineOps.checkCancelled()
        if trimWS(row) ~= "" then
            local kind, fields = splitEventLine(row:gsub("^%s+", ""))
            if not kind or not parseTime(fields[2]) or not parseTime(fields[3]) then
                error("Import Lines: invalid ASS row " .. (#source + 1) .. ". Copy complete subtitle rows.", 0)
            end
            source[#source+1] = {
                class="dialogue", comment=kind=="Comment", layer=tonumber(fields[1]) or 0,
                style=fields[4], actor=fields[5], margin_l=tonumber(fields[6]) or 0,
                margin_r=tonumber(fields[7]) or 0, margin_t=tonumber(fields[8]) or 0,
                effect=fields[9], text=fields[10],
            }
        end
    end
    if #source == 0 then return sel end
    local indices = Kite.LineOps.normalizeIndices(subs, sel, isEditableDialogue)
    if #indices == 0 then return sel end
    return Kite.LineOps.transaction(subs, function()
        for n=#indices,1,-1 do
            local index = indices[n]
            local target = subs[index]
            for k=#source,1,-1 do
                Kite.LineOps.checkCancelled()
                local line = Kite.Core.copy(source[k])
                line.start_time, line.end_time = target.start_time, target.end_time
                if k == 1 then subs[index] = line else subs.insert(index+1,line) end
            end
        end
        local selected = {}
        for n,index in ipairs(indices) do
            local first = index + (n-1)*(#source-1)
            for offset=0,#source-1 do selected[#selected+1]=first+offset end
        end
        return selected
    end)
end

function DataImportOps.splitInitial(text)
    local comments, tags, cursor = {}, {}, 1
    text = normalizeString(text)
    for _, section in ipairs(Kite.LineOps.scanSections(text)) do
        if section.type ~= "override" and section.type ~= "comment" then break end
        if section.type == "override" then tags[#tags + 1] = section.text
        else comments[#comments + 1] = text:sub(section.start, section.finish) end
        cursor = section.finish + 1
    end
    return table.concat(comments), table.concat(tags), text:sub(cursor)
end

local importTagPeers = {clip="iclip", iclip="clip", pos="move", move="pos", fad="fade", fade="fad", c="1c", ["1c"]="c", fr="frz", frz="fr", a="an", an="a"}
function DataImportOps.mergeInitialTags(text, importedInner)
    text = normalizeString(text)
    if importedInner == "" then return text, false end
    local names = {}
    for _, tag in ipairs(Kite.LineOps.overrideTokens(importedInner)) do
        if tag.name ~= "t" then
            names[tag.name] = true
            names[importTagPeers[tag.name] or tag.name] = true
        end
    end
    local comments, initial, rest = DataImportOps.splitInitial(text)
    initial = Kite.LineOps.mapTagCalls("{" .. initial .. "}", names, function() return "" end)
    local merged = comments .. initial:sub(1, -2) .. importedInner .. "}" .. rest
    return merged, merged ~= normalizeString(text)
end

function DataImportOps.importTags(subs, sel, raw, sameLayers)
    local sources = {}
    for row in normalizeString(raw):gmatch("[^\r\n]+") do
        local fields = parseDialogue(row)
        if fields then
            local first, last = parseTime(fields[2]), parseTime(fields[3])
            if first and last and last > first then
                local _, tags = DataImportOps.splitInitial(fields[10])
                sources[#sources + 1] = {start=first, end_time=last, layer=tonumber(fields[1]) or 0, tags=tags}
            end
        end
    end
    local changes = 0
    for _, index in ipairs(Kite.LineOps.normalizeIndices(subs, sel, isDialogue)) do
        Kite.LineOps.checkCancelled()
        local line, best, overlap = subs[index], nil, 0
        for _, source in ipairs(sources) do
            if sameLayerMatch(line, source, sameLayers) then
                local shared = timeInt(line.start_time, line.end_time, source.start, source.end_time)
                if shared > overlap then best, overlap = source, shared end
            end
        end
        if best then
            local text, changed = DataImportOps.mergeInitialTags(line.text, best.tags)
            if changed then
                line.text = text
                subs[index] = line
                changes = changes + 1
            end
        end
    end
    return changes
end

local function spParseDialogueLine(line)
    line = trimWS(line)
    local prefix, f = splitEventLine(line)
    if not prefix then return nil end
    return {
        line_type = prefix == "Comment" and "comment" or "dialogue", layer = tonumber(f[1]) or 0,
        start_time = f[2], end_time = f[3],
        style = f[4], actor = f[5],
        margin_l = tonumber(f[6]) or 0, margin_r = tonumber(f[7]) or 0, margin_t = tonumber(f[8]) or 0,
        effect = f[9], text = f[10],
    }
end

local function antSongs(subs, sel, raw)
    if not sel or #sel == 0 then return 0 end
    if not raw or raw:gsub("%s", "") == "" then return 0 end
    local group, syncPoint = {}, nil
    for rawLine in raw:gmatch("[^\r\n]+") do
        local line = trimWS(rawLine)
        if line ~= "" then
            local p = spParseDialogueLine(line)
            if p then
                if p.line_type == "comment" and p.layer == 50 then
                    local s = parseTime(p.start_time); if s then syncPoint = s end
                end
                table.insert(group, p)
            end
        end
    end
    if not syncPoint then
        showMsg(L("err_no_sync_point")); return 0
    end
    if #group == 0 then return 0 end
    local linesAdded = 0
    local insertPos = sel[#sel]
    for idx = #sel, 1, -1 do
        local target = subs[sel[idx]]
        if target and target.start_time then
            local shift = target.start_time - syncPoint
            local marker = target.effect or ""
            for i = #group, 1, -1 do
                local p = group[i]
                local s = parseTime(p.start_time); local e = parseTime(p.end_time)
                if s and e then
                    local ns, ne = s + shift, e + shift
                    if ns >= 0 and ne >= 0 then
                        local importedEffect = p.effect or ""
                        if marker ~= "" then
                            importedEffect = importedEffect ~= "" and (marker .. "; " .. importedEffect) or marker
                        end
                        local nl = {
                            class = "dialogue", comment = (p.line_type == "comment"),
                            layer = p.layer, start_time = ns, end_time = ne,
                            style = p.style, actor = p.actor,
                            margin_l = p.margin_l, margin_r = p.margin_r, margin_t = p.margin_t, margin_b = 0,
                            effect = importedEffect, text = p.text,
                        }
                        subs.insert(insertPos + 1, nl)
                        linesAdded = linesAdded + 1
                    end
                end
            end
        end
    end
    return linesAdded
end

local fallbackVideoFps = 24000 / 1001
local frTo, msFrom = aegisub.frame_from_ms, aegisub.ms_from_frame
local function getFps()
    local m1, m0
    if msFrom then
        local ok1, v1 = pcall(msFrom, 1)
        local ok0, v0 = pcall(msFrom, 0)
        if ok1 then m1 = v1 end
        if ok0 then m0 = v0 end
    end
    local delta = tonumber(m1) and tonumber(m0) and (tonumber(m1) - tonumber(m0)) or nil
    if delta and delta == delta and delta > 0 and delta < math.huge then return 1000 / delta end
    return fallbackVideoFps
end
local function toFrame(t)
    local f = msToFrame(t)
    if f then return f end
    return math.floor(t * getFps() / 1000 + 0.5)
end
local function toMs(f)
    local m = frameToMs(f)
    if m then return m end
    return math.floor(f * 1000 / getFps() + 0.5)
end
local function getKfSet()
    local kfs = getKeyframes()
    if not kfs or #kfs == 0 then return {}, {} end
    local set = {}; for _, k in ipairs(kfs) do set[k] = true end
    return kfs, set
end
local function ktSnap(t) return toMs(toFrame(t)) end
local function ktIsOnKf(tMs, kfs)
    local f = toFrame(tMs)
    for _, k in ipairs(kfs) do if k == f then return true end; if k > f then break end end
    return false
end
local function ktFindKfForward(orig, maxMs, kfs)
    local f0, fl = toFrame(orig), toFrame(orig + maxMs)
    for _, k in ipairs(kfs) do if k > f0 and k <= fl then return toMs(k) end; if k > fl then break end end
end
local function ktFindKfBackward(orig, maxMs, kfs)
    local f0, fl = toFrame(orig), toFrame(orig - maxMs)
    local best
    for _, k in ipairs(kfs) do if k >= fl and k < f0 then best = k end; if k >= f0 then break end end
    if best then return toMs(best) end
end

local function ktCalcLeadIn(origStart, boundary, kfs, cfg)
    local hard = boundary or 0
    local kf = ktFindKfBackward(origStart, cfg.kt_lead_in_max, kfs)
    if kf and kf >= hard then return kf end
    return ktSnap(math.max(origStart - cfg.kt_lead_in_base, hard))
end
local function ktCalcLeadOut(origEnd, boundary, kfs, cfg)
    local kf = ktFindKfForward(origEnd, cfg.kt_lead_out_max, kfs)
    if kf and (not boundary or kf <= boundary) then return kf end
    local base = origEnd + cfg.kt_lead_out_base
    if boundary then base = math.min(base, boundary) end
    return ktSnap(base)
end

local function kiteTimingOne(subs, si, kfs, cfg)
    local cur = subs[si]
    if not isEditableDialogue(cur) or not cur.start_time or not cur.end_time then return 0 end
    local before = {
        [si] = { start_time = cur.start_time, end_time = cur.end_time },
    }
    local prevIdx, nextIdx
    for j = si - 1, 1, -1 do if isEditableDialogue(subs[j]) then prevIdx = j; break end end
    for j = si + 1, #subs do if isEditableDialogue(subs[j]) then nextIdx = j; break end end
    local newS, newE = cur.start_time, cur.end_time
    local pendingNextStart
    if not prevIdx and not ktIsOnKf(cur.start_time, kfs) then
        newS = ktCalcLeadIn(cur.start_time, nil, kfs, cfg)
    end
    if nextIdx then
        local nxt = subs[nextIdx]
        if not nxt.start_time then return 0 end
        before[nextIdx] = { start_time = nxt.start_time, end_time = nxt.end_time }
        local origE1, origS2 = cur.end_time, nxt.start_time
        local e1Locked = ktIsOnKf(origE1, kfs)
        local s2Locked = ktIsOnKf(origS2, kfs)
        local gap = origS2 - origE1
        local newE1, newS2 = origE1, origS2
        if e1Locked and s2Locked then
        elseif e1Locked then
            if gap > 0 then
                if gap <= cfg.kt_lead_in_max and gap <= cfg.kt_chain_gap_max then newS2 = origE1
                else newS2 = ktCalcLeadIn(origS2, origE1, kfs, cfg) end
            elseif gap < 0 then
                newS2 = ktCalcLeadIn(origS2, nil, kfs, cfg)
                if newS2 < 0 then newS2 = 0 end
            end
        elseif s2Locked then
            if gap > 0 then
                local reach = origS2 - origE1
                if reach >= 0 and reach <= cfg.kt_lead_out_chain and gap <= cfg.kt_chain_gap_max then newE1 = origS2
                else newE1 = ktCalcLeadOut(origE1, origS2, kfs, cfg) end
            elseif gap < 0 then
                newE1 = ktCalcLeadOut(origE1, nil, kfs, cfg)
            end
        elseif gap > 0 then
            local kf1 = ktFindKfForward(origE1, cfg.kt_lead_out_max, kfs)
            if kf1 and kf1 > origS2 then kf1 = nil end
            local kf2 = ktFindKfBackward(origS2, cfg.kt_lead_in_max, kfs)
            if kf2 and kf2 < origE1 then kf2 = nil end
            local baseE1 = ktSnap(math.min(origE1 + cfg.kt_lead_out_base, origS2))
            local baseS2 = ktSnap(math.max(origS2 - cfg.kt_lead_in_base, origE1))
            if kf1 and kf2 then
                newE1 = kf1; newS2 = kf2
                if newE1 > newS2 then local mid = ktSnap((newE1 + newS2) / 2); newE1 = mid; newS2 = mid end
            elseif kf1 and not kf2 then
                newE1 = kf1
                local reach = origS2 - kf1
                if reach >= 0 and reach <= cfg.kt_lead_in_max and gap <= cfg.kt_chain_gap_max then newS2 = kf1 else newS2 = baseS2 end
            elseif not kf1 and kf2 then
                newS2 = kf2
                local reach = kf2 - origE1
                if reach >= 0 and reach <= cfg.kt_lead_out_chain and gap <= cfg.kt_chain_gap_max then newE1 = kf2 else newE1 = baseE1 end
            else
                if gap <= cfg.kt_chain_gap_max and gap <= (cfg.kt_lead_out_chain + cfg.kt_lead_in_max) then
                    newS2 = baseS2; newE1 = newS2
                else
                    newE1 = baseE1; newS2 = baseS2
                    if newE1 > newS2 then local mid = ktSnap((newE1 + newS2) / 2); newE1 = mid; newS2 = mid end
                end
            end
        elseif gap < 0 then
            newE1 = ktCalcLeadOut(origE1, nil, kfs, cfg)
            newS2 = ktCalcLeadIn(origS2, nil, kfs, cfg)
            if newS2 < 0 then newS2 = 0 end
        end
        newE = newE1
        pendingNextStart = newS2
    else
        if not ktIsOnKf(cur.end_time, kfs) then
            newE = ktCalcLeadOut(cur.end_time, nil, kfs, cfg)
        end
    end
    if newE <= newS then return 0 end
    if nextIdx and pendingNextStart then
        local nxt = subs[nextIdx]
        if not nxt or not nxt.end_time or pendingNextStart >= nxt.end_time then return 0 end
    end
    cur.start_time = newS; cur.end_time = newE; subs[si] = cur
    if nextIdx and pendingNextStart then
        local nxt = subs[nextIdx]
        nxt.start_time = pendingNextStart
        subs[nextIdx] = nxt
    end

    local changed = 0
    for idx, old in pairs(before) do
        local line = subs[idx]
        if line and (line.start_time ~= old.start_time or line.end_time ~= old.end_time) then changed = changed + 1 end
    end
    return changed
end

local function kiteTiming(subs, sel)
    resolveConfig()
    local okFrame = false
    if frTo and msFrom then
        local ok, f0, m0 = pcall(function() return frTo(0), msFrom(0) end)
        okFrame = ok and f0 ~= nil and m0 ~= nil
    end
    if not okFrame then showMsg(L("err_no_video")); return end
    sel = collectEditableSelection(subs, sel or {})
    if #sel == 0 then showMsg(L("err_no_selection")); return end
    table.sort(sel)
    local kfs = getKfSet()
    local cfg = currentConfig
    local changed = 0
    for _, si in ipairs(sel) do
        changed = changed + kiteTimingOne(subs, si, kfs, cfg)
    end
    showMsg(string.format(L("msg_kite_done"), changed, #sel))
end

local function frameToEffect(subs, sel)
    local props = aegisub.project_properties()
    if not props or not props.video_position then showMsg(L("err_no_video")); return end
    local frame = tostring(props.video_position)
    for _, i in ipairs(sel) do
        local l = subs[i]
        if l.class == "dialogue" then
            local effect = normalizeString(l.effect)
            l.effect = (effect == "" and frame or (effect .. " " .. frame))
            subs[i] = l
        end
    end
end

local function splitRomaji(w)
    local t, pos, len = {}, 1, #w
    local function peek(n) return pos + n - 1 <= len and w:sub(pos, pos + n - 1) or nil end
    local function consume(n) local s = w:sub(pos, pos + n - 1); pos = pos + n; return s end
    local function isVowel(c) return c and c:match("[aiueo]") end
    while pos <= len do
        local found = false
        local c1, c2, c3, c4 = peek(1), peek(2), peek(3), peek(4)
        if c4 then
            local p4 = { "kky[auo]","ssy[auo]","tty[auo]","ppy[auo]","ggy[auo]","zzy[auo]",
                         "ddy[auo]","bby[auo]","mmy[auo]","nny[auo]","rry[auo]","hhy[auo]" }
            for _, p in ipairs(p4) do if c4:match("^" .. p .. "$") then t[#t+1] = consume(4); found = true; break end end
        end
        if not found and c3 then
            local p3 = { "nn[aiueo]","mm[aiueo]","kk[aiueo]","ss[aiueo]","tt[aiueo]","pp[aiueo]",
                         "gg[aiueo]","zz[aiueo]","dd[aiueo]","bb[aiueo]","rr[aiueo]","hh[aiueo]","yy[aiueo]",
                         "kya","kyu","kyo","gya","gyu","gyo","sha","shu","sho","cha","chu","cho",
                         "nya","nyu","nyo","hya","hyu","hyo","bya","byu","byo","pya","pyu","pyo",
                         "mya","myu","myo","rya","ryu","ryo","tsu","shi","chi",
                         "tta","kka","ssa","ppa","gga","zza","dda","bba","mma","nna","rra","hha","yya" }
            for _, p in ipairs(p3) do if c3:match("^" .. p .. "$") then t[#t+1] = consume(3); found = true; break end end
        end
        if not found and c2 then
            local p2 = { "ka","ki","ku","ke","ko","ga","gi","gu","ge","go","sa","si","su","se","so",
                         "za","zi","zu","ze","zo","ta","ti","tu","te","to","da","di","du","de","do",
                         "na","ni","nu","ne","no","ha","hi","hu","he","ho","ba","bi","bu","be","bo",
                         "pa","pi","pu","pe","po","ma","mi","mu","me","mo","ya","yu","yo",
                         "ra","ri","ru","re","ro","wa","wi","wu","we","wo","nn","n'",
                         "aa","ii","uu","ee","oo","ou","oa","oe","oi","ue","ua","ui","ai","au","ei",
                         "ia","ie","iu","uo" }
            for _, p in ipairs(p2) do
                if c2:match("^" .. p .. "$") then
                    if p == "nn" and isVowel(peek(3)) then t[#t+1] = consume(1); found = true; break
                    else t[#t+1] = consume(2); found = true; break end
                end
            end
        end
        if not found and c1 then
            if c1:match("[aiueon]") then t[#t+1] = consume(1); found = true end
        end
        if not found then t[#t+1] = consume(1) end
    end
    if #t == 0 then t[1] = w end
    return t
end

local function romajiKara(subs, sel)
    aegisub.progress.task("Romaji Karaoker (Kana-Beat \\\\k)...")
    local function tokenize(text)
        local tokens, i, n = {}, 1, #text
        while i <= n do
            local first = text:sub(i, i)
            if first == "{" then
                local close = text:find("}", i + 1, true)
                if close then
                    tokens[#tokens+1] = { raw = text:sub(i, close) }
                    i = close + 1
                else
                    tokens[#tokens+1] = { raw = text:sub(i), syllables = splitRomaji(text:sub(i)) }
                    break
                end
            elseif first:match("%s") then
                local j = i + 1
                while j <= n and text:sub(j, j):match("%s") do j = j + 1 end
                tokens[#tokens+1] = { raw = text:sub(i, j - 1) }
                i = j
            elseif first == "\\" and text:sub(i + 1, i + 1):match("[Nnh]") then
                tokens[#tokens+1] = { raw = text:sub(i, i + 1) }
                i = i + 2
            else
                local j = i
                while j <= n do
                    local char = text:sub(j, j)
                    if char == "{" or char:match("%s") or (char == "\\" and text:sub(j + 1, j + 1):match("[Nnh]")) then break end
                    j = j + 1
                end
                local raw = text:sub(i, j - 1)
                tokens[#tokens+1] = { raw = raw, syllables = splitRomaji(raw) }
                i = j
            end
        end
        return tokens
    end

    local updates = {}
    for idx, i in ipairs(sel) do
        aegisub.progress.set(idx / #sel * 100)
        if Kite.LineOps and Kite.LineOps.checkCancelled then Kite.LineOps.checkCancelled() end
        local ln = subs[i]
        local tokens = tokenize(normalizeString(ln.text))
        local total = 0
        for _, token in ipairs(tokens) do total = total + (token.syllables and #token.syllables or 0) end
        if total > 0 then
            local cs = math.max(0, math.floor((ln.end_time - ln.start_time) / 10 + 0.5))
            local base, rem = math.floor(cs / total), cs % total
            local out, kix = {}, 1
            for _, token in ipairs(tokens) do
                if token.syllables then
                    for _, syllable in ipairs(token.syllables) do
                        local duration = base + (kix <= rem and 1 or 0)
                        out[#out+1] = "{\\k" .. duration .. "}" .. syllable
                        kix = kix + 1
                    end
                else
                    out[#out+1] = token.raw
                end
            end
            local updated = cloneLine(ln)
            updated.text = table.concat(out)
            updates[#updates+1] = { index = i, line = updated }
        end
    end
    local function applyUpdates()
        for _, update in ipairs(updates) do subs[update.index] = update.line end
    end
    if #updates > 0 and Kite.LineOps and Kite.LineOps.transaction then
        Kite.LineOps.transaction(subs, applyUpdates)
    else
        applyUpdates()
    end
end

local function foldCopy(subs, sel)
    if #sel == 0 then showMsg(L("err_no_lines_selected")); return end
    local act = sel[1]
    local function parseLineFold(line)
        if not line.extra then return nil end
        local info = line.extra["_aegi_folddata"]; if not info then return nil end
        local side, collapsed, id = info:match("^(%d+);(%d+);(%d+)$")
        if not side then return nil end
        return { side = tonumber(side), collapsed = tonumber(collapsed), id = tonumber(id) }
    end
    local foldStack, newSelection, foldAroundLine = {}, {}
    for i = 1, #subs do
        if subs[i].class == "dialogue" then
            local line = subs[i]
            local fd = parseLineFold(line)
            if fd and fd.side == 0 then table.insert(foldStack, { index = i, id = fd.id }) end
            if i == act then
                if #foldStack == 0 then
                    showMsg(L("err_not_inside_fold"))
                    return
                end
                foldAroundLine = foldStack[#foldStack]
                newSelection = {}
                for j = foldAroundLine.index, i do table.insert(newSelection, j) end
            elseif i > act and foldAroundLine then
                table.insert(newSelection, i)
            end
            if fd and fd.side == 1 then
                if #foldStack > 0 and foldStack[#foldStack].id == fd.id then
                    table.remove(foldStack)
                    if foldAroundLine and foldAroundLine.id == fd.id then break end
                end
            end
        end
    end
    if not foldAroundLine or #newSelection == 0 then
        showMsg(L("err_no_fold_group")); return
    end
    local clipboard = {}
    for _, idx in ipairs(newSelection) do
        local l = subs[idx]
        if l.class == "dialogue" then
            local s = string.format("%s: %d,%s,%s,%s,%s,%d,%d,%d,%s,%s",
                l.comment and "Comment" or "Dialogue",
                l.layer, msToAssTime(l.start_time), msToAssTime(l.end_time),
                l.style, l.actor, l.margin_l or 0, l.margin_r or 0, l.margin_t or l.margin_v or 0,
                l.effect, l.text)
            table.insert(clipboard, s)
        end
    end
    local txt = table.concat(clipboard, "\n")
    aegisub.dialog.display({
        { class = "label", label = string.format("Fold group found (%d lines).\nCopy text below:", #newSelection), x = 0, y = 0, width = 40, height = 1 },
        { class = "textbox", name = "clipboard", text = txt, x = 0, y = 1, width = 40, height = 20 },
    }, { L("btn_ok") })
    return newSelection
end


local function normalizeStutter(subs, sel)
    for _, i in ipairs(sel) do
        local l = subs[i]
        local hasTT = normalizeString(l.effect):find("%[TT%]") ~= nil
        local pre, text = splitLeadingBraceBlocks(l.text)
        local punct, rest = "", text
        local scanning = true
        while scanning do
            if startsWith(rest, invExclamation) then punct = punct .. invExclamation; rest = rest:sub(#invExclamation + 1)
            elseif startsWith(rest, invQuestion) then punct = punct .. invQuestion; rest = rest:sub(#invQuestion + 1)
            elseif rest:match("^%s") then punct = punct .. rest:sub(1, 1); rest = rest:sub(2)
            else scanning = false end
        end
        local chars = {}
        for c in rest:gmatch(utf8CharPattern) do table.insert(chars, c) end
        if #chars > 0 and chars[1]:match("[%a\128-\255]") then
            local first = chars[1]
            local base = unicodeUpper(first)
            local firstLower = unicodeLower(first)
            local isStutter = (#chars >= 3 and chars[2] == "-" and unicodeLower(chars[3]) == firstLower)
            if isStutter then
                local res, mode = {}, true
                for _, c in ipairs(chars) do
                    if mode then
                        if c == "-" then table.insert(res, "-")
                        elseif unicodeLower(c) == firstLower then table.insert(res, base)
                        else mode = false; table.insert(res, c) end
                    else
                        table.insert(res, c)
                    end
                end
                l.text = pre .. punct .. table.concat(res)
            elseif hasTT then
                local tail = table.concat(chars, "", 2)
                l.text = pre .. punct .. base .. "-" .. base .. tail
            end
        end
        subs[i] = l
    end
end

local function remplacer(subs, sel)
    if #sel < 1 then showMsg(L("err_no_selection")); return end
    local dlg = {
        { class="label",   x=0,  y=0,  width=40, height=1, label = L("lbl_original_text") },
        { class="textbox", x=0,  y=1,  width=40, height=10, name="original", text="" },
        { class="label",   x=41, y=0,  width=40, height=1, label = L("lbl_replacement_text") },
        { class="textbox", x=41, y=1,  width=40, height=10, name="replacement", text="" },
        { class="label",   x=0,  y=11, width=81, height=1, label = L("lbl_replacer_help") },
    }
    local ret, res = aegisub.dialog.display(dlg, { L("btn_replace_all"), L("btn_cancel") }, { ok = L("btn_replace_all"), close = L("btn_cancel") })
    if ret ~= L("btn_replace_all") or not ret then return end
    local origs = {}; for line in res.original:gmatch("[^\r\n]+") do table.insert(origs, line) end
    local reps  = {}; for line in res.replacement:gmatch("[^\r\n]+") do table.insert(reps, line) end
    if #origs ~= #reps or #origs == 0 then return end
    local map = {}; for i, o in ipairs(origs) do map[o] = reps[i] end
    local mod = 0
    for _, i in ipairs(sel) do
        local line = subs[i]
        if isDialogue(line) then
            local text = normalizeString(line.text)
            local vis = visibleText(text)
            local repl = map[vis]
            if repl then
                local tags = splitLeadingBraceBlocks(text)
                line.text = tags .. repl
                addEffectMarker(line, "[REPLACED]")
                subs[i] = line; mod = mod + 1
            end
        end
    end
    showMsg(string.format(L("msg_replacer_done"), mod))
end

local function shiftToFirst(subs, sel)
    if #sel < 2 then showMsg(L("err_shift_min_two")); return end
    local line1 = subs[sel[1]]
    local line2 = subs[sel[2]]
    if not isDialogue(line1) or not isDialogue(line2) then
        showMsg(L("err_shift_first_two"))
        return
    end
    local delta = line1.start_time - line2.start_time
    if delta == 0 then return end
    for k = 2, #sel do
        local idx = sel[k]
        local cur = subs[idx]
        if isDialogue(cur) then
            local new_start = cur.start_time + delta
            local new_end = cur.end_time + delta
            if new_start < 0 then
                local dur = cur.end_time - cur.start_time
                new_start = 0
                new_end = dur
                if new_end < 0 then new_end = 0 end
            end
            if new_end < new_start then new_end = new_start end
            cur.start_time = new_start
            cur.end_time = new_end
            subs[idx] = cur
        end
    end
end

local utilitySections = {
    {
        id    = "case",
        label_key = "lbl_section_case",
        items = {
            { name="",                                  func = nil },
            { name="Toggle \\an8",                      func = TextOperations.toggleAlignment,      includeVector = true },
            { name="Toggle Italics",                    func = TextOperations.toggleItalics },
            { name="Uppercase",                         func = TextOperations.toUppercase },
            { name="Lowercase",                         func = TextOperations.toLowercase },
            { name="Title Case",                        func = TextOperations.toTitleCase },
            { name="Sentence Case",                     func = TextOperations.toSentenceCase },
            { name="Capitalize First",                  func = TextOperations.capitalizeFirst },
            { name="Lowercase First",                   func = TextOperations.lowercaseFirst },
        },
    },
    {
        id    = "punct",
        label_key = "lbl_section_punct",
        items = {
            { name="" },
            { name="Toggle " .. invExclamation .. "!",                       func = TextOperations.toggleExclamation },
            { name="Toggle " .. invQuestion .. "?",                          func = TextOperations.toggleQuestion },
            { name="Toggle " .. invExclamation .. invQuestion .. "?!",      func = TextOperations.toggleBothSigns },
            { name="Normalize Ellipsis",                func = TextOperations.formatEllipsis },
            { name="Add Ellipsis",                      func = TextOperations.addEndingEllipsis },
            { name="Erase Leading Ellipsis",            func = TextOperations.eraseLeadingEllipsis },
            { name="Erase Inner Ellipsis",              func = TextOperations.eraseInnerEllipsis },
            { name="Ellipsis to Comma",                 func = TextOperations.ellipsisToComma },
            { name="Ellipsis to Period",                func = TextOperations.ellipsisToPeriod },
            { name="Unify Quotes",                      func = TextOperations.normalizeQuotes },
            { name="Latin Quotes (" .. leftGuillemet .. rightGuillemet .. ")", func = TextOperations.toLatinQuotes },
            { name="Normalize Dashes",                  func = TextOperations.normalizeDashes },
            { name="Trim Trailing Spaces",              func = TextOperations.trimTrailingSpaces },
            { name="Remove Duplicate Letters",          func = TextOperations.removeDuplicateLetters },
            { name="Add Stutter",                       func = SmartOperations.injectStutter },
            { name="Add Ah Prefix",                     func = SmartOperations.injectAhPrefix },
            { name="Normalize Stutter",                   func = normalizeStutter },
        },
    },
    {
        id    = "tags",
        label_key = "lbl_section_tags",
        items = {
            { name="" },
            { name="Fold by Identifier",               func = MarkerOperations.randomFolds,         includeComments = true, includeVector = true, returnsSelection = true },
            { name="Extract Tags",                      func = TagOperations.extractTags,           includeVector = true },
            { name="Reinsert Tags",                     func = TagOperations.reinsertTags,          includeVector = true },
            { name="Remove Tags",                       func = TagOperations.removeAllTags },
            { name="Merge Tags",                        func = TagOperations.mergeTags,             includeVector = true },
            { name="Remove Inline Comments",                   func = TagOperations.removeComments },
            { name="Extract Actors and Split",                      func = TagOperations.parseActor,            returnsSelection = true },
            { name="Swap Text and Comments",                      func = TagOperations.swapComment },
            { name="Delete Comment Lines",              func = SmartOperations.deleteCommentLines,  includeComments = true, includeVector = true, returnsSelection = true },
            { name="Comments to Top",                   func = SmartOperations.commentsToTop,       includeComments = true, includeVector = true },
            { name="Comments to Bottom",                func = SmartOperations.commentsToBottom,    includeComments = true, includeVector = true },
            { name="Effects to Top",                    func = TagOperations.effectsToTop,          includeComments = true, includeVector = true },
        },
    },
    {
        id    = "smart",
        label_key = "lbl_section_smart",
        items = {
            { name="" },
            { name="Smart Break", func = TimingOperations.smartLineBreak },
            { name="Smart Split", func = SmartOperations.Split.main, returnsSelection = true, mutates = false },
            { name="Bidirectional Snapping",            func = SmartOperations.bidirectionalSnapping, includeComments = true, includeVector = true },
            { name="Remove Honorifics",                 func = SmartOperations.removeHonorifics },
            { name="Caption Clarifier",                 func = SmartOperations.clarifyCaption },
            { name="Complete Sentences",                func = SmartOperations.completeSentences, returnsSelection = true },
            { name="Erase Blank Lines",                 func = SmartOperations.eraseBlankLines,     returnsSelection = true },
            { name="Current Frame to Effect",     func = frameToEffect,                     includeVector = true },
            { name="Copy Fold",    func = foldCopy,                           includeComments = true, includeVector = true, returnsSelection = true, mutates = false },
        },
    },
    {
        id    = "split",
        label_key = "lbl_section_split",
        items = {
            { name="" },
            { name="Split by Sentence",                 func = TimingOperations.splitBySentence,    returnsSelection = true },
            { name="Split by Comma",                    func = TimingOperations.splitByComma,       returnsSelection = true },
            { name="Pivot \\N",                         func = TimingOperations.pivotLinebreak },
            { name="Remove \\N",                        func = TimingOperations.removeLinebreaks },
            { name="Join Same Text",                    func = TimingOperations.joinSameText,       returnsSelection = true },
            { name="Join Overlaps",                     func = TimingOperations.joinOverlaps,       returnsSelection = true },
            { name="Join Overlap Sentences",            func = TimingOperations.joinOverlapSentences, returnsSelection = true },
            { name="Divide by \\N",                     func = TimingOperations.splitByLinebreak,   returnsSelection = true },
        },
    },
    {
        id    = "time",
        label_key = "lbl_section_time",
        items = {
            { name="" },
            { name="Copy Times",                        func = TimingOperations.copyTimes,          includeVector = true },
            { name="Select Time Range",                       func = TimingOperations.timePicker,         returnsSelection = true, includeVector = true, mutates = false },
            { name="Sort by Text Length",                    func = TimingOperations.sortByLength },
            { name="Sort by CPS",                       func = TimingOperations.sortByCPS },
            { name="Sort Odd Even",                     func = TimingOperations.sortByEvenOdd,      includeComments = true, includeVector = true },
            { name="Count CPS",                         func = TimingOperations.showCPS, mutates = false },
            { name="Import Text",               func = TimingOperations.importText,         returnsSelection = true },
            { name="Kite Timing", func = kiteTiming,                       includeVector = true },
            { name="Align to First Start",  func = shiftToFirst,                      includeComments = true },
            { name="Start Snap Back",                   func = SmartOperations.startSnapBack, includeComments = true, includeVector = true },
            { name="Start Snap Forward",                func = SmartOperations.startSnapForward, includeComments = true, includeVector = true },
            { name="End Snap Back",                     func = SmartOperations.endSnapBack, includeComments = true, includeVector = true },
            { name="End Snap Forward",                  func = SmartOperations.endSnapForward, includeComments = true, includeVector = true },
            { name="Add Lead-In Left",                  func = TimingOperations.addLeadIn, includeVector = true },
            { name="Add Lead-In Right",                 func = TimingOperations.addLeadInRight, includeVector = true },
            { name="Add Lead-Out Left",                 func = TimingOperations.addLeadOutLeft, includeVector = true },
            { name="Add Lead-Out Right",                func = TimingOperations.addLeadOut, includeVector = true },
            { name="Chain Left",                        func = TimingOperations.chainLeft, includeVector = true },
            { name="Chain Right",                       func = TimingOperations.chainRight, includeVector = true },
        },
    },
    {
        id    = "kara",
        label_key = "lbl_section_kara",
        items = {
            { name="" },
            { name="Shift Following Lines", func = TimingOperations.shiftFollowing, includeComments = true, includeVector = true, mutates = false, preserveActive = true },
            { name="Romaji Karaoker (Word → \\k)",      func = romajiKara },
        },
    },
}

local function findUtilityEntry(sectionId, name)
    for _, sec in ipairs(utilitySections) do
        if sec.id == sectionId then
            for _, it in ipairs(sec.items) do
                if it.name == name then return it end
            end
        end
    end
    return nil
end

local function runUtilityEntry(entry, subs, sel, active)
    if not entry or not entry.func then return sel end
    local target
    if entry.includeComments then target = collectDialogueSelection(subs, sel)
    elseif entry.includeVector   then target = collectEditableSelection(subs, sel)
    else                          target = collectEditableTextSelection(subs, sel) end
    local result = entry.func(subs, target, active)
    if entry.returnsSelection and type(result) == "table" then return result end
    return sel
end

function MarkerOperations.parseMpvQcTime(value)
    local h, m, s, ms = normalizeString(value):match("%[(%d+):(%d+):(%d+)%.(%d+)%]")
    if not h then h, m, s = normalizeString(value):match("%[(%d+):(%d+):(%d+)%]") end
    if not h then return nil end
    return clockToMs(h, m, s, ms)
end

function MarkerOperations.parseMpvQc(raw, tolerance)
    local out = {}
    tolerance = tolerance or 1000
    for rawLine in normalizeString(raw):gmatch("[^\r\n]+") do
        local line = trimText(rawLine)
        local timeStr, kind, comment = line:match("(%[%d+:%d+:%d+%.?%d*%])%s*%[([^%]]+)%]%s*(.*)")
        if timeStr and comment and comment ~= "" then
            local time = MarkerOperations.parseMpvQcTime(timeStr)
            if time then
                out[#out+1] = {
                    time = time,
                    kind = trimText(kind),
                    comment = trimText(comment),
                    start_time = time - tolerance,
                    end_time = time + tolerance,
                }
            end
        end
    end
    return out
end

function MarkerOperations.splitQcComment(comment)
    local suggestions = {}
    local observation = normalizeString(comment):gsub("%b{}", function(block)
        local inner = trimText(block:sub(2, -2))
        if inner ~= "" then suggestions[#suggestions+1] = "{" .. inner .. "}" end
        return " "
    end)
    observation = trimText(observation:gsub("%s+", " "))
    return observation, suggestions
end

function MarkerOperations.addQcSuggestion(line, suggestion)
    local text = normalizeString(line.text)
    if suggestion ~= "" and not text:find(escapeLuaPattern(suggestion), 1) then
        line.text = trimText(text .. " " .. suggestion)
    end
end

local function mpvQcTool(subs, sel)
    local state = { tolerance = "1000", raw = "" }
    while true do
        local dlg = {
            { class="label", label=L("lbl_mpvqc_title"), x=0, y=0, width=4, height=1 },
            { class="label", label=L("lbl_mpvqc_tolerance"), x=0, y=1, width=1, height=1 },
            { class="edit", name="tolerance", value=state.tolerance, x=1, y=1, width=1 },
            { class="label", label=L("lbl_mpvqc_paste"), x=0, y=2, width=4, height=1 },
            { class="textbox", name="raw", text=state.raw, x=0, y=3, width=65, height=14 },
        }
        local button, result = aegisub.dialog.display(dlg, { L("btn_apply"), L("btn_cancel") })
        if button ~= L("btn_apply") then return end
        state = result
        local tolerance = tonumber(result.tolerance)
        if not tolerance or tolerance < 0 then
            showMsg(L("err_tolerance_positive"))
        elseif trimText(result.raw) == "" then
            showMsg(L("err_paste_mpvqc"))
        else
            local comments = MarkerOperations.parseMpvQc(result.raw, tolerance)
            if #comments == 0 then
                showMsg(L("err_no_mpvqc_comments"))
            else
                local modified = 0
                for _, i in ipairs(sel) do
                    local line = subs[i]
                    if isDialogue(line) and validateDuration(line) then
                        local changed = false
                        for _, qc in ipairs(comments) do
                            if timeInt(line.start_time, line.end_time, qc.start_time, qc.end_time) > 0 then
                                local observation, suggestions = MarkerOperations.splitQcComment(qc.comment)
                                if observation == "" then observation = qc.kind ~= "" and qc.kind or "Observation" end
                                addEffectMarker(line, "[QC: " .. observation .. "]")
                                for _, suggestion in ipairs(suggestions) do MarkerOperations.addQcSuggestion(line, suggestion) end
                                changed = true
                            end
                        end
                        if changed then subs[i] = line; modified = modified + 1 end
                    end
                end
                showMsg(string.format(L("msg_mpvqc_done"), modified))
                return
            end
        end
    end
end

local RemoverOps = {}

function RemoverOps.anySelected(opts)
    for k, v in pairs(opts or {}) do
        if type(k) == "string" and k:match("^rem_") and v == true then return true end
    end
    return false
end

function RemoverOps.removeVisibleSet(value, set)
    local out, changed = {}, false
    for _, c in ipairs(splitUtf8Chars(normalizeString(value))) do
        if set[c] then changed = true else out[#out+1] = c end
    end
    return table.concat(out), changed
end

function RemoverOps.removeStutterText(value)
    local chars, out, i = splitUtf8Chars(normalizeString(value)), {}, 1
    while i <= #chars do
        if i + 2 <= #chars and isLetter(chars[i]) and chars[i + 1] == "-"
           and isLetter(chars[i + 2]) and unicodeLower(chars[i]) == unicodeLower(chars[i + 2]) then
            i = i + 2
        else
            out[#out+1] = chars[i]
            i = i + 1
        end
    end
    return table.concat(out)
end

RemoverOps.removeDuplicateLettersText = normalizeRepeatedLetters
RemoverOps.removeLeadingEllipsisText = stripLeadingEllipsisText

function RemoverOps.cleanTextSection(value, opts)
    local t = normalizeString(value)
    if opts.rem_n then t = t:gsub("\\[Nn]", " ") end
    if opts.rem_h then t = t:gsub("\\h", " "):gsub(NBSP, " ") end
    if opts.rem_combo then
        t = RemoverOps.removeVisibleSet(t, {
            [invExclamation]=true, ["!"]=true, [fullwidthExclamation]=true,
            [invQuestion]=true, ["?"]=true, [fullwidthQuestion]=true,
        })
    else
        if opts.rem_excl then
            t = RemoverOps.removeVisibleSet(t, {
                [invExclamation]=true, ["!"]=true, [fullwidthExclamation]=true,
            })
        end
        if opts.rem_quest then
            t = RemoverOps.removeVisibleSet(t, {
                [invQuestion]=true, ["?"]=true, [fullwidthQuestion]=true,
            })
        end
    end
    if opts.rem_all_commas then t = RemoverOps.removeVisibleSet(t, { [","]=true, [cjkComma]=true, [fullwidthComma]=true }) end
    if opts.rem_quotes then
        t = RemoverOps.removeVisibleSet(t, {
            ["\""]=true, [leftDoubleQuote]=true, [rightDoubleQuote]=true,
            [doubleLowQuote]=true, [doubleHighReversedQuote]=true,
            [string.char(0xEF,0xBC,0x82)]=true,
            [leftGuillemet]=true, [rightGuillemet]=true,
            [string.char(0xE3,0x80,0x8C)]=true, [string.char(0xE3,0x80,0x8D)]=true,
            [string.char(0xE3,0x80,0x8E)]=true, [string.char(0xE3,0x80,0x8F)]=true,
        })
    end
    if opts.rem_apostrophes then
        t = RemoverOps.removeVisibleSet(t, {
            ["'"]=true, [leftSingleQuote]=true, [rightSingleQuote]=true,
            [singleLowQuote]=true, [singleHighReversedQuote]=true,
            [string.char(0xEF,0xBC,0x87)]=true,
            [leftSingleGuillemet]=true, [rightSingleGuillemet]=true,
        })
    end
    if opts.rem_stutter then t = RemoverOps.removeStutterText(t) end
    if opts.rem_dup_letters then t = RemoverOps.removeDuplicateLettersText(t) end
    if opts.rem_leading_ellipsis then t = RemoverOps.removeLeadingEllipsisText(t) end
    if opts.rem_ellipsis then
        t = t:gsub(horizontalEllipsis, ""):gsub(twoDotLeader, ""):gsub("%.%.%.+", "")
    end
    if opts.rem_n or opts.rem_h or opts.rem_double_space then t = t:gsub("[ \t][ \t]+", " ") end
    return t
end

function RemoverOps.trimVisibleEdges(text)
    local leading, body = splitLeadingTagBlocks(text)
    local core, trailing = splitTrailingTagBlocks(body)
    core = core:gsub("^[ \t]+", ""):gsub("[ \t]+$", "")
    return leading .. core .. trailing
end

function RemoverOps.removeOneFinalComma(text)
    local tokens, cursor = {}, 1
    text = normalizeString(text)
    while cursor <= #text do
        local s, e = text:find("%b{}", cursor)
        if not s then
            for _, c in ipairs(splitUtf8Chars(text:sub(cursor))) do tokens[#tokens+1] = { c, true } end
            break
        end
        if s > cursor then
            for _, c in ipairs(splitUtf8Chars(text:sub(cursor, s - 1))) do tokens[#tokens+1] = { c, true } end
        end
        tokens[#tokens+1] = { text:sub(s, e), false }
        cursor = e + 1
    end
    for i = #tokens, 1, -1 do
        if tokens[i][2] then
            local c = tokens[i][1]
            if isWhitespaceChar(c) or closingPunctuation[c] then
            elseif c == "," or c == cjkComma or c == fullwidthComma then
                table.remove(tokens, i)
                local out = {}
                for _, token in ipairs(tokens) do out[#out+1] = token[1] end
                return table.concat(out), true
            else
                return text, false
            end
        end
    end
    return text, false
end

function RemoverOps.removeFinalComma(text)
    local current = normalizeString(text)
    while true do
        local nextText, removed = RemoverOps.removeOneFinalComma(current)
        if not removed then return current end
        current = nextText
    end
end

function RemoverOps.cleanLine(line, opts)
    local before = normalizeString(line.text)
    if opts.rem_inline_comments then line.text = stripComments(line.text) end
    if opts.rem_italic_tags then line.text = removeOverridePattern(line.text, "\\i[01]") end
    if opts.rem_q_tags then line.text = removeOverridePattern(line.text, "\\q%d") end
    if opts.rem_an8 then line.text = removeOverridePattern(line.text, "\\an8") end
    mutateTextSections(line, function(value) return RemoverOps.cleanTextSection(value, opts) end)
    if opts.rem_final_commas then line.text = RemoverOps.removeFinalComma(line.text) end
    if opts.rem_edge_space then line.text = RemoverOps.trimVisibleEdges(line.text) end
    return before ~= normalizeString(line.text)
end

function RemoverOps.gui(subs, sel)
    local dlg = {
        { class="label", label=L("lbl_remover_title"), x=0, y=0, width=6, height=1 },
        { class="label", label=L("lbl_remover_text"), x=0, y=1, width=3, height=1 },
        { class="checkbox", name="rem_n", label=L("chk_rem_n"), value=false, x=0, y=2, width=2, height=1 },
        { class="checkbox", name="rem_h", label=L("chk_rem_h"), value=false, x=2, y=2, width=2, height=1 },
        { class="checkbox", name="rem_double_space", label=L("chk_rem_double_space"), value=false, x=4, y=2, width=2, height=1 },
        { class="checkbox", name="rem_edge_space", label=L("chk_rem_edge_space"), value=false, x=0, y=3, width=2, height=1 },
        { class="checkbox", name="rem_excl", label=L("chk_rem_excl"), value=false, x=2, y=3, width=2, height=1 },
        { class="checkbox", name="rem_quest", label=L("chk_rem_quest"), value=false, x=4, y=3, width=2, height=1 },
        { class="checkbox", name="rem_combo", label=L("chk_rem_combo"), value=false, x=0, y=4, width=2, height=1 },
        { class="checkbox", name="rem_final_commas", label=L("chk_rem_final_commas"), value=false, x=2, y=4, width=2, height=1 },
        { class="checkbox", name="rem_all_commas", label=L("chk_rem_all_commas"), value=false, x=4, y=4, width=2, height=1 },
        { class="checkbox", name="rem_quotes", label=L("chk_rem_quotes"), value=false, x=0, y=5, width=2, height=1 },
        { class="checkbox", name="rem_apostrophes", label=L("chk_rem_apostrophes"), value=false, x=2, y=5, width=2, height=1 },
        { class="checkbox", name="rem_stutter", label=L("chk_rem_stutter"), value=false, x=4, y=5, width=2, height=1 },
        { class="checkbox", name="rem_dup_letters", label=L("chk_rem_dup_letters"), value=false, x=0, y=6, width=2, height=1 },
        { class="checkbox", name="rem_leading_ellipsis", label=L("chk_rem_leading_ellipsis"), value=false, x=2, y=6, width=2, height=1 },
        { class="checkbox", name="rem_ellipsis", label=L("chk_rem_ellipsis"), value=false, x=4, y=6, width=2, height=1 },
        { class="label", label=L("lbl_remover_tags"), x=0, y=7, width=3, height=1 },
        { class="checkbox", name="rem_italic_tags", label=L("chk_rem_italic_tags"), value=false, x=0, y=8, width=2, height=1 },
        { class="checkbox", name="rem_q_tags", label=L("chk_rem_q_tags"), value=false, x=2, y=8, width=2, height=1 },
        { class="checkbox", name="rem_an8", label=L("chk_rem_an8"), value=false, x=4, y=8, width=2, height=1 },
        { class="label", label=L("lbl_remover_comments"), x=0, y=9, width=3, height=1 },
        { class="checkbox", name="rem_comment_lines", label=L("chk_rem_comment_lines"), value=false, x=0, y=10, width=3, height=1 },
        { class="checkbox", name="rem_inline_comments", label=L("chk_rem_inline_comments"), value=false, x=3, y=10, width=3, height=1 },
    }
    local button, result = aegisub.dialog.display(dlg, { L("btn_apply"), L("btn_cancel") })
    if button ~= L("btn_apply") then return false end
    local state = result
    if not RemoverOps.anySelected(state) then showMsg(L("err_remover_none")); return false end
    local modified, deleted, deleteSet = 0, 0, {}
    for _, i in ipairs(sel) do
        local line = subs[i]
        if isDialogue(line) and not line.comment then
            if RemoverOps.cleanLine(line, state) then
                subs[i] = line
                modified = modified + 1
            end
        end
    end
    if state.rem_comment_lines then
        for _, i in ipairs(sel) do
            local line = subs[i]
            if isDialogue(line) and line.comment then deleteSet[i] = true end
        end
        local sorted = {}
        for i in pairs(deleteSet) do sorted[#sorted+1] = i end
        table.sort(sorted, function(a, b) return a > b end)
        for _, i in ipairs(sorted) do subs.delete(i); deleted = deleted + 1 end
    end
    showMsg(string.format(L("msg_remover_done"), modified, deleted))
    return remapSelectionAfterDeletion(subs, sel, deleteSet)
end

local primaryTools = {
    { name = "Joinator", func = TimingOperations.joinDialog, returnsSelection = true, mutates = false },
    { name = "Text and Tag Cleanup", button = "Cleanup", func = RemoverOps.gui, returnsSelection = true },
    { name = "Final Data", func = function(subs, sel) return Kite.EventOps.properties.run(subs, sel, {language=currentConfig.language}) end, mutates=false, returnsSelection=true },
}
local suiteTools = {
    { name = "" },
    { name = "Text Replacer", func = remplacer },
    { name = "mpv QC", func = mpvQcTool },
}
local suiteToolNames = {}
for _, t in ipairs(suiteTools) do suiteToolNames[#suiteToolNames+1] = t.name end

local function findSuiteTool(name)
    for _, t in ipairs(suiteTools) do if t.name == name then return t end end
end

local function rowMasterGui(subs, sel, active)
    if not sel or #sel == 0 then showMsg(L("err_no_selection")); return end

    resolveConfig()

    local state = {
        tm = "All Selected", tv = "",

        preset = "", kf_mode = "", kf_dir = "", single_marker = "",
        short_ms = 0, long_ms = 0, twin_kf_ms = 0, miss_kf_ms = 0,
        overtime_ms = 0, min_cps = 0, max_cps = 0,
        gap_ms = 0, large_gap_ms = 0, max_width = 0,
        kf_seal = false, gap_mark_continuous = false, gap_ignore_kf = false, clear_old = true,
        sec_case = "", sec_punct = "", sec_tags = "", sec_smart = "", sec_split = "", sec_time = "", sec_kara = "",

        mr = "", mm = "Import Effects", mc = false, same_layers = false,
        ct = "",
    }

    while true do
        local ui = {
            tm = UI.options({ "All Selected","By Style","By Actor","By Effect","By Layer" }, state.tm),
            preset = UI.options({ "","Ends Only","Start Only","Full Audit","Duration","CPS","Short Gaps","Large Gaps","Both Gaps","Overtime" }, state.preset),
            kf_mode = UI.options({ "","End Only","Start Only","Both" }, state.kf_mode),
            kf_dir = UI.options({ "","KF Back","KF Forward","KF Both" }, state.kf_dir),
            sec_case = UI.utilityOptions(utilitySections[1], state.sec_case),
            sec_punct = UI.utilityOptions(utilitySections[2], state.sec_punct),
            sec_tags = UI.utilityOptions(utilitySections[3], state.sec_tags),
            sec_smart = UI.utilityOptions(utilitySections[4], state.sec_smart),
            sec_split = UI.utilityOptions(utilitySections[5], state.sec_split),
            sec_time = UI.utilityOptions(utilitySections[6], state.sec_time),
            sec_kara = UI.utilityOptions(utilitySections[7], state.sec_kara),
            single_marker = UI.options(singleMarkerItems, state.single_marker),
            mm = UI.options({ "Import Effects","Import Text","Import Actor","Import Tags","Import Lines","Song Sync" }, state.mm),
            ct = UI.options(suiteToolNames, state.ct),
        }
        local d = {
            { class="label",    label=L("lbl_apply_to"),                                              x=0,  y=0, width=4, height=1 },
            { class="dropdown", name="tm", items=ui.tm.items, value=ui.tm.value, x=4, y=0, width=8, height=1 },
            { class="label",    label=L("lbl_filter"),                                                x=12, y=0, width=4, height=1 },
            { class="edit",     name="tv", value=state.tv,                                            x=16, y=0, width=8, height=1 },

            { class="label", label=L("title_markers"),   x=0,  y=1, width=11, height=1 },
            { class="label", label="│",                   x=11, y=1, width=1,  height=1 },
            { class="label", label=L("title_utilities"), x=12, y=1, width=12, height=1 },

            { class="label",    label=L("lbl_preset"),                                                x=0, y=2, width=3, height=1 },
            { class="dropdown", name="preset", items=ui.preset.items, value=ui.preset.value, x=3, y=2, width=8, height=1 },
            { class="label",    label="│",                                                            x=11, y=2, width=1, height=1 },

            { class="label",    label=L("lbl_short_ms"),                                              x=0, y=3, width=3, height=1 },
            { class="intedit",  name="short_ms", value=state.short_ms, min=0,                         x=3, y=3, width=3, height=1 },
            { class="label",    label=L("lbl_long_ms"),                                               x=6, y=3, width=3, height=1 },
            { class="intedit",  name="long_ms",  value=state.long_ms,  min=0,                         x=9, y=3, width=2, height=1 },
            { class="label",    label="│",                                                            x=11, y=3, width=1, height=1 },

            { class="label",    label=L("lbl_kf_mode"),                                               x=0, y=4, width=2, height=1 },
            { class="dropdown", name="kf_mode", items=ui.kf_mode.items, value=ui.kf_mode.value, x=2, y=4, width=4, height=1 },
            { class="label",    label=L("lbl_kf_dir"),                                                x=6, y=4, width=2, height=1 },
            { class="dropdown", name="kf_dir", items=ui.kf_dir.items, value=ui.kf_dir.value, x=8, y=4, width=3, height=1 },
            { class="label",    label="│",                                                            x=11, y=4, width=1, height=1 },

            { class="label",    label=L("lbl_twin_ms"),                                               x=0, y=5, width=3, height=1 },
            { class="intedit",  name="twin_kf_ms", value=state.twin_kf_ms, min=0,                     x=3, y=5, width=3, height=1 },
            { class="label",    label=L("lbl_miss_ms"),                                               x=6, y=5, width=3, height=1 },
            { class="intedit",  name="miss_kf_ms", value=state.miss_kf_ms, min=0,                     x=9, y=5, width=2, height=1 },
            { class="label",    label="│",                                                            x=11, y=5, width=1, height=1 },

            { class="checkbox", name="kf_seal", label=L("chk_kf_seal"), hint="[START-ON-KF/END-ON-KF]", value=state.kf_seal,          x=0, y=6, width=5, height=1 },
            { class="label",    label=L("lbl_overtime"),                                              x=5, y=6, width=3, height=1 },
            { class="intedit",  name="overtime_ms", value=state.overtime_ms, min=0,                   x=8, y=6, width=3, height=1 },
            { class="label",    label="│",                                                            x=11, y=6, width=1, height=1 },

            { class="label",    label=L("lbl_section_cps_gap"),                                       x=0, y=7, width=11, height=1 },
            { class="label",    label="│",                                                            x=11, y=7, width=1, height=1 },

            { class="label",    label=L("lbl_min_cps"),                                               x=0, y=8, width=3, height=1 },
            { class="intedit",  name="min_cps", value=state.min_cps, min=0,                           x=3, y=8, width=3, height=1 },
            { class="label",    label=L("lbl_max_cps"),                                               x=6, y=8, width=3, height=1 },
            { class="intedit",  name="max_cps", value=state.max_cps, min=0,                           x=9, y=8, width=2, height=1 },
            { class="label",    label="│",                                                            x=11, y=8, width=1, height=1 },

            { class="label",    label=L("lbl_gap_ms"),                                                x=0, y=9, width=3, height=1 },
            { class="intedit",  name="gap_ms", value=state.gap_ms, min=0,                             x=3, y=9, width=3, height=1 },
            { class="label",    label=L("lbl_max_width"),                                             x=6, y=9, width=3, height=1 },
            { class="intedit",  name="max_width", value=state.max_width, min=0,                       x=9, y=9, width=2, height=1 },
            { class="label",    label="│",                                                            x=11, y=9, width=1, height=1 },

            { class="label",    label=L("lbl_large_gap"),                                             x=0, y=10, width=3, height=1 },
            { class="intedit",  name="large_gap_ms", value=state.large_gap_ms, min=0,                 x=3, y=10, width=3, height=1 },
            { class="checkbox", name="gap_mark_continuous", label=L("chk_gap_continuous"),            value=state.gap_mark_continuous, x=6, y=10, width=5, height=1 },
            { class="label",    label="│",                                                            x=11, y=10, width=1, height=1 },

            { class="checkbox", name="gap_ignore_kf",       label=L("chk_gap_ignore_kf"),             value=state.gap_ignore_kf,       x=0, y=11, width=5, height=1 },
            { class="checkbox", name="clear_old", label=L("chk_clear_old"), value=state.clear_old,    x=5, y=11, width=6, height=1 },
            { class="label",    label="│",                                                            x=11, y=11, width=1, height=1 },

            { class="label",    label=L("lbl_section_case"),    x=12, y=2, width=4, height=1 },
            { class="dropdown", name="sec_case",  items=ui.sec_case.items, value=ui.sec_case.value,  x=16, y=2, width=8, height=1 },

            { class="label",    label=L("lbl_section_punct"),   x=12, y=3, width=4, height=1 },
            { class="dropdown", name="sec_punct", items=ui.sec_punct.items, value=ui.sec_punct.value, x=16, y=3, width=8, height=1 },

            { class="label",    label=L("lbl_section_tags"),    x=12, y=4, width=4, height=1 },
            { class="dropdown", name="sec_tags",  items=ui.sec_tags.items, value=ui.sec_tags.value,  x=16, y=4, width=8, height=1 },

            { class="label",    label=L("lbl_section_smart"),   x=12, y=5, width=4, height=1 },
            { class="dropdown", name="sec_smart", items=ui.sec_smart.items, value=ui.sec_smart.value, x=16, y=5, width=8, height=1 },

            { class="label",    label=L("lbl_section_split"),   x=12, y=6, width=4, height=1 },
            { class="dropdown", name="sec_split", items=ui.sec_split.items, value=ui.sec_split.value, x=16, y=6, width=8, height=1 },

            { class="label",    label=L("lbl_section_time"),    x=12, y=7, width=4, height=1 },
            { class="dropdown", name="sec_time",  items=ui.sec_time.items, value=ui.sec_time.value,  x=16, y=7, width=8, height=1 },

            { class="label",    label=L("lbl_section_kara"),    x=12, y=8, width=4, height=1 },
            { class="dropdown", name="sec_kara",  items=ui.sec_kara.items, value=ui.sec_kara.value,  x=16, y=8, width=8, height=1 },

            { class="label",    label=L("lbl_marker_dd"),       x=12, y=9, width=4, height=1 },
            { class="dropdown", name="single_marker", items=ui.single_marker.items, value=ui.single_marker.value, x=16, y=9, width=8, height=1 },

            { class="label",    label=string.format(L("lbl_selection"), #sel),        x=12, y=10, width=12, height=1 },
            { class="label",    label=L("lbl_dropdown_skip_hint"),                    x=12, y=11, width=12, height=1 },

            { class="label",    label=L("title_data_import"),                                       x=0, y=12, width=24, height=1 },
            { class="label",    label=L("lbl_data_import_mode"),                                    x=0, y=13, width=4, height=1 },
            { class="dropdown", name="mm", items=ui.mm.items, value=ui.mm.value, x=4, y=13, width=8, height=1 },
            { class="checkbox", name="mc", label=L("chk_data_import_cmt"), hint=L("lbl_import_as_comments"), value=state.mc,
                                                                                                  x=12, y=13, width=4, height=1 },
            { class="checkbox", name="same_layers", label=L("chk_data_import_same_layers"), value=state.same_layers,
                                                                                                  x=16, y=13, width=8, height=1 },
            { class="textbox",  name="mr", text=state.mr,                                         x=0, y=14, width=24, height=4 },
            { class="label",    label=L("chk_data_import_skip") .. "  ·  " .. L("data_import_paste_hint"),
                                                                                                  x=0, y=18, width=24, height=1 },

            { class="label",    label=L("title_tools"),                                           x=0, y=19, width=24, height=1 },
            { class="label",    label=L("lbl_suite_tool"),                                        x=0, y=20, width=4, height=1 },
            { class="dropdown", name="ct", items=ui.ct.items, value=ui.ct.value,              x=4, y=20, width=20, height=1 },
        }

        local buttons = { L("btn_execute"), "Cleanup", "Joinator", "Final Data", L("btn_config"), L("btn_help"), L("btn_cancel") }
        local b, r = aegisub.dialog.display(d, buttons, {close=L("btn_cancel")})
        if b == L("btn_cancel") or not b then return end

        r.tm = UI.from(ui.tm, r.tm)
        r.preset = UI.from(ui.preset, r.preset)
        r.kf_mode = UI.from(ui.kf_mode, r.kf_mode)
        r.kf_dir = UI.from(ui.kf_dir, r.kf_dir)
        r.sec_case = UI.from(ui.sec_case, r.sec_case)
        r.sec_punct = UI.from(ui.sec_punct, r.sec_punct)
        r.sec_tags = UI.from(ui.sec_tags, r.sec_tags)
        r.sec_smart = UI.from(ui.sec_smart, r.sec_smart)
        r.sec_split = UI.from(ui.sec_split, r.sec_split)
        r.sec_time = UI.from(ui.sec_time, r.sec_time)
        r.sec_kara = UI.from(ui.sec_kara, r.sec_kara)
        r.single_marker = UI.from(ui.single_marker, r.single_marker)
        r.mm = UI.from(ui.mm, r.mm)
        r.ct = UI.from(ui.ct, r.ct)

        for k, v in pairs(r) do state[k] = v end

        if b == L("btn_config") then
            showConfigDialog()
        elseif b == L("btn_help") then
            showHelp()
        elseif b == "Joinator" or b == "Cleanup" or b == "Final Data" then
            local targeted = getTargetedSelection(subs, sel, {mode=r.tm,value=r.tv})
            if #targeted == 0 then showMsg(L("err_filter_zero"))
            else
                for _, tool in ipairs(primaryTools) do
                    if b == (tool.button or UI.text(tool.name)) then
                        local result = tool.func(subs, targeted)
                        if tool.mutates ~= false then aegisub.set_undo_point("Chrono Suite - " .. tool.name) end
                        return result
                    end
                end
            end
        elseif b == L("btn_execute") then
            local twinVal = tonumber(r.twin_kf_ms)
            if not twinVal or twinVal < 0 then showMsg(L("err_invalid_twin")) else
                local missVal = tonumber(r.miss_kf_ms)
                if not missVal or missVal < 0 then showMsg(L("err_invalid_miss")) else
                    local ovVal = tonumber(r.overtime_ms)
                    if not ovVal or ovVal < 0 then showMsg(L("err_invalid_ov")) else
                        local toolActive = (r.ct and r.ct ~= "")
                        local sectionActive = (r.sec_case ~= "" or r.sec_punct ~= "" or r.sec_tags ~= ""
                            or r.sec_smart ~= "" or r.sec_split ~= "" or r.sec_time ~= "" or r.sec_kara ~= "")
                        local importActive = (r.mr and r.mr:gsub("%s", "") ~= "")
                        local auditActive = (r.preset ~= "" or r.single_marker ~= "" or r.kf_seal
                            or twinVal > 0 or missVal > 0 or ovVal > 0
                            or (tonumber(r.short_ms) or 0) > 0 or (tonumber(r.long_ms) or 0) > 0
                            or (tonumber(r.min_cps) or 0) > 0 or (tonumber(r.max_cps) or 0) > 0
                            or (tonumber(r.gap_ms) or 0) > 0 or (tonumber(r.large_gap_ms) or 0) > 0
                            or (tonumber(r.max_width) or 0) > 0)

                        if not (toolActive or sectionActive or importActive or auditActive) then return end

                        local tsel = getTargetedSelection(subs, sel, { mode = r.tm, value = r.tv })
                        if #tsel == 0 then
                            showMsg(L("err_filter_zero"))
                        else
                            aegisub.progress.task("Chrono Suite - Executing...")

                            if toolActive then
                                local tool = findSuiteTool(r.ct)
                                if tool and tool.func then
                                    local result = tool.func(subs, tsel)
                                    if tool.returnsSelection and type(result) == "table" then
                                        if tool.mutates ~= false then aegisub.set_undo_point("Chrono Suite - " .. r.ct) end
                                        return result
                                    end
                                end
                                if tool and tool.mutates ~= false then aegisub.set_undo_point("Chrono Suite - " .. r.ct) end
                                return
                            end

                            local currentSel = tsel
                            local returnsSelection = false
                            local mutated = importActive or auditActive
                            if sectionActive then
                                local sectionDd = {
                                    { id = "case",  pick = r.sec_case  },
                                    { id = "punct", pick = r.sec_punct },
                                    { id = "tags",  pick = r.sec_tags  },
                                    { id = "smart", pick = r.sec_smart },
                                    { id = "split", pick = r.sec_split },
                                    { id = "time",  pick = r.sec_time  },
                                    { id = "kara",  pick = r.sec_kara  },
                                }
                                for _, s in ipairs(sectionDd) do
                                    if s.pick and s.pick ~= "" then
                                        local entry = findUtilityEntry(s.id, s.pick)
                                        if entry and entry.returnsSelection then returnsSelection = true end
                                        if entry and entry.mutates ~= false then mutated = true end
                                        currentSel = runUtilityEntry(entry, subs, currentSel, active)
                                    end
                                end
                            end

                            if importActive then
                                if     r.mm == "Import Effects" then antEffects(subs, currentSel, r.mr, r.same_layers)
                                elseif r.mm == "Import Text"   then antLines(subs,   currentSel, r.mr, r.mc, r.same_layers)
                                elseif r.mm == "Import Actor"   then antActor(subs,   currentSel, r.mr, r.same_layers)
                                elseif r.mm == "Import Tags"    then DataImportOps.importTags(subs, currentSel, r.mr, r.same_layers)
                                elseif r.mm == "Import Lines" then currentSel = DataImportOps.importLines(subs, currentSel, r.mr); returnsSelection = true
                                elseif r.mm == "Song Sync"   then antSongs(subs,   currentSel, r.mr) end
                            end

                            if auditActive then
                                local auditCfg = {
                                    short_ms = tonumber(r.short_ms) or 0,
                                    long_ms = tonumber(r.long_ms) or 0,
                                    twin_kf_ms = twinVal, miss_kf_ms = missVal, overtime_ms = ovVal,
                                    min_cps = tonumber(r.min_cps) or 0,
                                    max_cps = tonumber(r.max_cps) or 0,
                                    gap_ms = tonumber(r.gap_ms) or 0,
                                    large_gap_ms = tonumber(r.large_gap_ms) or 0,
                                    max_width = tonumber(r.max_width) or 0,
                                    kf_seal = r.kf_seal, kf_mode = r.kf_mode, kf_dir = r.kf_dir,
                                    gap_mark_continuous = r.gap_mark_continuous,
                                    gap_ignore_kf = r.gap_ignore_kf,
                                    clear_old = r.clear_old,
                                    single_marker = r.single_marker,
                                    check_uppercase=false, check_3liner=false, check_missing_punct=false,
                                    check_punct_balance=false, check_orphan_word=false, check_orphan_tag=false,
                                    check_overlap=false, check_unstyled=false, check_double_italics=false,
                                    check_parentheses=false, check_name_prefix=false, check_sentences=false,
                                    check_needs_split=(tonumber(r.max_width) or 0) > 0, check_empty=false,
                                    check_has_n=false, check_has_pos=false, check_has_clip=false, check_has_fad=false,
                                    check_has_t=false, check_has_k=false, check_has_comment=false, check_has_num=false,
                                    check_has_cjk=false, check_full_italic=false,
                                    check_dbl_space=false, check_edge_space=false,
                                }
                                if r.preset and r.preset ~= "" then
                                    auditCfg = applyPreset(auditCfg, r.preset)
                                    if r.kf_dir and r.kf_dir ~= "" then auditCfg.kf_dir = r.kf_dir end
                                end
                                auditLines(subs, currentSel, auditCfg)
                            end

                            if mutated then aegisub.set_undo_point("Chrono Suite - Executed") end
                            if returnsSelection then return currentSel end
                            return
                        end
                    end
                end
            end
        end
    end
end

local function macroPath(name)
    if name == "" then return script_name end
    return script_name .. "/" .. name
end

local HotkeyMenu = { root = ": Kite Hotkeys :", script = script_name, migrations = {} }

function HotkeyMenu.path(name)
    return HotkeyMenu.root .. "/" .. HotkeyMenu.script .. "/" .. name
end

function HotkeyMenu.addMigration(oldMacroName, newMacroName)
    HotkeyMenu.migrations[oldMacroName] = newMacroName
end

function HotkeyMenu.migrate()
    require("kite.UI").actions.rename(script_namespace, HotkeyMenu.migrations)
end

local macros = {
    { macroPath(""),                   script_description,                  rowMasterGui },
    { macroPath("Config"),             "Chrono Suite settings",             showConfigDialog },
    { macroPath("Help"),               "Chrono Suite help",                 showHelp },

    { macroPath("Audit/Markers"),       "Run audit markers with current config", function(subs, sel)
            resolveConfig()
            auditLines(subs, sel, applyPreset({}, "Full Audit"))
            aegisub.set_undo_point("Chrono Suite - Audit/Markers")
        end, hotkeyName = "Audit Markers" },
}

local function registerMacro(name, description, process)
    if depRec then
        depRec:registerMacro(name, description, process, nil, nil, false)
    else
        aegisub.register_macro(name, description, process)
    end
end

for _, m in ipairs(macros) do
    if m.hotkeyName then
        local newPath = HotkeyMenu.path(m.hotkeyName)
        registerMacro(newPath, "Hotkey action. " .. m[2], m[3])
        HotkeyMenu.addMigration(m[1], newPath)
    else
        registerMacro(m[1], m[2], m[3])
    end
end

local utilityMacroGroups = {
    case  = "Case",
    punct = "Punctuation",
    tags  = "Tags",
    smart = "Smart",
    split = "Split Join",
    time  = "Timing",
    kara  = "Karaoke",
}

local function makeUtilityMacro(entry)
    return function(subs, sel, active)
        local result = runUtilityEntry(entry, subs, sel, active)
        if entry.mutates ~= false then aegisub.set_undo_point("Chrono Suite - " .. entry.name) end
        if entry.preserveActive then return result, active end
        return result
    end
end

for _, sec in ipairs(utilitySections) do
    local group = utilityMacroGroups[sec.id] or sec.id
    for _, entry in ipairs(sec.items) do
        if entry.name and entry.name ~= "" and entry.func then
            local root = sec.id == "kara" and "Karaoke" or ("Utility/" .. group)
            local process = makeUtilityMacro(entry)
            local newPath = HotkeyMenu.path(root .. "/" .. entry.name)
            registerMacro(newPath, "Hotkey action. " .. entry.name, process)
            HotkeyMenu.addMigration(macroPath(root .. "/" .. entry.name), newPath)
        end
    end
end

local function makeSuiteToolMacro(tool)
    return function(subs, sel)
        local result = tool.func(subs, sel)
        if tool.mutates ~= false then aegisub.set_undo_point("Chrono Suite - " .. tool.name) end
        if tool.returnsSelection and type(result) == "table" then return result end
    end
end

local shortcutTools = {}
for _, tool in ipairs(primaryTools) do shortcutTools[#shortcutTools+1] = tool end
for _, tool in ipairs(suiteTools) do shortcutTools[#shortcutTools+1] = tool end
for _, tool in ipairs(shortcutTools) do
    if tool.name and tool.name ~= "" and tool.func then
        local process = makeSuiteToolMacro(tool)
        local newPath = HotkeyMenu.path(tool.name)
        registerMacro(newPath, "Hotkey action. " .. tool.name, process)
        HotkeyMenu.addMigration(macroPath("Tools/" .. tool.name), newPath)
    end
end

for _, name in ipairs({"Line Merge and Cleanup", "Properties and Cleanup"}) do
    local target = name == "Line Merge and Cleanup" and "Joinator" or "Final Data"
    HotkeyMenu.addMigration(HotkeyMenu.path(name), HotkeyMenu.path(target))
    HotkeyMenu.addMigration(macroPath("Tools/" .. name), HotkeyMenu.path(target))
end

HotkeyMenu.addMigration(HotkeyMenu.path("Utility/Split Join/Smart Break"), HotkeyMenu.path("Utility/Smart/Smart Break"))
HotkeyMenu.addMigration(HotkeyMenu.path("Utility/Punctuation/Stutter Manager"), HotkeyMenu.path("Utility/Punctuation/Normalize Stutter"))

HotkeyMenu.addMigration(HotkeyMenu.path("Utility/Smart/Frame Effect"), HotkeyMenu.path("Utility/Smart/Current Frame to Effect"))
HotkeyMenu.addMigration(HotkeyMenu.path("Utility/Timing/Shift First"), HotkeyMenu.path("Utility/Timing/Align to First Start"))

HotkeyMenu.addMigration(": Kite Hotkeys :/Chrono Suite/Utility/Split Join/Join Lines", ": Kite Hotkeys :/Chrono Suite/Joinator")
HotkeyMenu.addMigration("Chrono Suite/Utility/Split Join/Join Lines", ": Kite Hotkeys :/Chrono Suite/Joinator")
HotkeyMenu.addMigration(": Kite Hotkeys :/Chrono Suite/Join Lines", ": Kite Hotkeys :/Chrono Suite/Joinator")
HotkeyMenu.addMigration("Chrono Suite/Tools/Join Lines", ": Kite Hotkeys :/Chrono Suite/Joinator")
HotkeyMenu.addMigration(": Kite Hotkeys :/Chrono Suite/Remover Assistant", ": Kite Hotkeys :/Chrono Suite/Text and Tag Cleanup")
HotkeyMenu.addMigration("Chrono Suite/Tools/Remover Assistant", ": Kite Hotkeys :/Chrono Suite/Text and Tag Cleanup")
HotkeyMenu.addMigration(": Kite Hotkeys :/Chrono Suite/Utility/Tags/Actor Parser", ": Kite Hotkeys :/Chrono Suite/Utility/Tags/Extract Actors and Split")
HotkeyMenu.addMigration("Chrono Suite/Utility/Tags/Actor Parser", ": Kite Hotkeys :/Chrono Suite/Utility/Tags/Extract Actors and Split")
HotkeyMenu.addMigration(": Kite Hotkeys :/Chrono Suite/Utility/Tags/Swap Comment", ": Kite Hotkeys :/Chrono Suite/Utility/Tags/Swap Text and Comments")
HotkeyMenu.addMigration("Chrono Suite/Utility/Tags/Swap Comment", ": Kite Hotkeys :/Chrono Suite/Utility/Tags/Swap Text and Comments")
HotkeyMenu.addMigration(": Kite Hotkeys :/Chrono Suite/Utility/Tags/Remove Comments", ": Kite Hotkeys :/Chrono Suite/Utility/Tags/Remove Inline Comments")
HotkeyMenu.addMigration("Chrono Suite/Utility/Tags/Remove Comments", ": Kite Hotkeys :/Chrono Suite/Utility/Tags/Remove Inline Comments")
HotkeyMenu.addMigration(": Kite Hotkeys :/Chrono Suite/Utility/Timing/Time Picker", ": Kite Hotkeys :/Chrono Suite/Utility/Timing/Select Time Range")
HotkeyMenu.addMigration("Chrono Suite/Utility/Timing/Time Picker", ": Kite Hotkeys :/Chrono Suite/Utility/Timing/Select Time Range")
HotkeyMenu.addMigration(": Kite Hotkeys :/Chrono Suite/Utility/Timing/Sort by Length", ": Kite Hotkeys :/Chrono Suite/Utility/Timing/Sort by Text Length")
HotkeyMenu.addMigration("Chrono Suite/Utility/Timing/Sort by Length", ": Kite Hotkeys :/Chrono Suite/Utility/Timing/Sort by Text Length")
HotkeyMenu.addMigration(": Kite Hotkeys :/Chrono Suite/Utility/Smart/Start Frame to Effect", ": Kite Hotkeys :/Chrono Suite/Utility/Smart/Current Frame to Effect")
HotkeyMenu.addMigration("Chrono Suite/Utility/Smart/Start Frame to Effect", ": Kite Hotkeys :/Chrono Suite/Utility/Smart/Current Frame to Effect")

HotkeyMenu.migrate()

require("kite.UI").publishActions()

end
local registrations = {}
local registerMacro = aegisub.register_macro
local function loadScript()
    registrations = {}
    aegisub.register_macro = function(name, description, callback, validate, active)
        registrations[#registrations+1] = {name, description, callback, validate, active}
    end
    local ok, message = pcall(initializeScript)
    aegisub.register_macro = registerMacro
    local available, control = pcall(require, "l0.DependencyControl")
    if available and control.updater then control.updater:releaseLock() end
    return ok, message
end
local loaded, failure = loadScript()
if loaded then
    for _, action in ipairs(registrations) do registerMacro(unpack(action)) end
else
    registerMacro(script_name, script_description, function(subs, selection, active)
        if not loaded then
            local available, control = pcall(require, "l0.DependencyControl")
            if not available then error(control, 0) end
            local loader = require("l0.DependencyControl.ModuleLoader")
            for _, task in pairs(control.updater.tasks[control.Domain.ScriptType.Module]) do
                if not task.updated and not task.running then loader.removeDummyRef(task.record) end
            end
            loaded, failure = loadScript()
            if not loaded then error(failure, 0) end
        end
        local choices, actions = {}, {}
        for _, action in ipairs(registrations) do
            if not action[4] or action[4](subs, selection, active) then
                choices[#choices+1] = action[1]
                actions[action[1]] = action[3]
            end
        end
        if #choices == 0 then return selection, active end
        if #choices == 1 then return actions[choices[1]](subs, selection, active) end
        local button, values = aegisub.dialog.display({
            {class="dropdown", name="action", items=choices, value=choices[1], x=0,y=0,width=1,height=1}
        }, {"Run","Cancel"}, {ok="Run",close="Cancel"})
        if button == "Run" then return actions[values.action](subs, selection, active) end
        return selection, active
    end)
end
