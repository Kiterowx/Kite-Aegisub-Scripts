# Chrono Suite 1.5.3

English | [Español](es/ChronoSuite.md) | [Index](../README.md#documentation)

Open **Chrono Suite** for the combined panel. **Chrono Suite/Config** and **Chrono Suite/Help** are the other direct entries. The 83 individual actions are registered under **: Kite Hotkeys :/Chrono Suite/**, including Autotiming, Extract KF (SCXvid), Scream Detector, Audit Markers, the 74 utility actions and the five extra tools. Utility submenus are Case, Punctuation, Tags, Smart, Split Join and Timing; Karaoke has its own branch. Existing command IDs are preserved.

## Start with the intended operation

- To review existing timing: select dialogue, choose an Audit preset, inspect markers in Effect and correct flagged lines. Audit flags are review criteria, not automatic diagnoses.
- To align dialogue to sound: open Auto Timing, choose Lazy or Busy and a mode, supply its input data, and inspect the resulting timing against audio. Use Raw voice to characterize detection before applying padding and keyframe polish.
- To edit text: choose a utility and execute with the intended selection. Multiple nonempty sections execute in the panel's defined order; leave unrelated sections empty.
- To prepare delivery properties: open Properties and Cleanup. Editing credits is separate from its optional whole-file cleanup; this option deliberately exceeds the current selection.

Most text utilities exclude commented events and vector drawings. Timing and tag operations can explicitly include drawings; sorting, folds and comment management have their own event scope. Deleting and splitting operations return remapped selections. Count CPS, Time Picker, Copy Fold and AE Export do not edit event text. Properties and Cleanup manages its own transaction. Use Undo to review a mutating operation, especially when combining utilities.

The main panel places Audit Markers on the left and Utility Tools on the right, with Data Import and Extra Tools below. Most audit results appear in the Effect field.

## Main panel

**Text as {...}** wraps imported text in comment blocks. Its tooltip gives the full description; the Spanish and Portuguese labels are **Texto en {...}** and **Texto em {...}**. **Keyframe seal** retains its existing behavior and shows its marker codes in a tooltip. These compact labels keep the main window narrow.

The panel is organized around the current selection. Actions are triggered by pressing EXECUTE. The Auto Timing, Extract KF, Config, and Help buttons open their dialogs directly. Auto Timing respects the Apply to / Filter pair.

- **Apply to:** defines the subset on which the panel sections act.
- **Filter:** text or numeric value paired with Apply to.
- **Audit Markers:** presets, thresholds, keyframe mode, and Single Marker.
- **Utility Tools:** seven independent sections (Case, Punct/Text, Tags/Comments, Smart, Split/Join, Time/Sort, and Karaoke).
- **Data Import:** import data from text pasted into the box.
- **Extra Tools:** five independent tools.

An empty dropdown skips its section during execution.

## Apply to / Filter

- **All Selected:** uses the selection as it is.
- **By Style:** keeps lines whose style matches Filter.
- **By Actor:** keeps lines whose actor matches Filter.
- **By Effect:** keeps lines whose Effect contains the filter text (partial match).
- **By Layer:** keeps lines whose Layer equals the number written in Filter.

## Audit presets

Each preset applies the thresholds defined in Config → Audit Presets and writes its markers to the Effect field.

- **Ends Only:** checks line end times against nearby keyframes. Writes only Miss KF and Twin KF markers.
- **Start Only:** equivalent check applied to line start times.
- **Full Audit:** general check covering text, layout, timing, CPS, gaps, and structure.
- **Duration:** checks each line against the Short and Long thresholds.
- **CPS:** checks reading speed against the configured maximum.
- **Short Gaps:** checks line-to-line gaps against the Short gap threshold.
- **Large Gaps:** checks line-to-line gaps against the Large gap threshold.
- **Both Gaps:** runs both gap checks. Markers are written on both adjacent lines and include the detected millisecond value.
- **Overtime:** marks lines that exceed the configured maximum duration.

## Audit numeric fields

- **Short (ms) / Long (ms):** minimum and maximum duration thresholds.
- **Twin KF (ms):** distance for identifying two lines touching the same keyframe.
- **Miss KF (ms):** distance for identifying a missed keyframe.
- **Overtime (ms):** threshold exclusive to the Overtime preset.
- **Min CPS / Max CPS:** reading speed range.
- **Short gap (ms) / Large gap (ms):** line-to-line gap thresholds.
- **Max Width (px):** visual line width used as a review criterion.

## Keyframe mode and direction

- **KF Mode:** selects which edge is checked against keyframes: Start Only, End Only, or Both.
- **KF Dir:** search direction for Near/Missed keyframes: Back, Forward, or Both. An empty value defaults to Back.
- **Keyframe Seal:** independent option that writes START-ON-KF or END-ON-KF when an edge lands on a keyframe.
- **Mark continuous (0 ms):** includes zero-millisecond gaps in the check.
- **Ignore gap on KF:** skips gaps whose edge lands on a keyframe.
- **Clear previous markers:** removes existing markers before writing new ones.

## Single Marker

Overrides the chosen preset and runs a single check. The matching tag is written to the Effect field.

### Numbering and identification

- Number Effects: sequential numbering (1, 2, 3...).
- Add Identifier: 14-digit unique identifier per line.

### Text and punctuation

- UPPERCASE: entire line in uppercase.
- THREE-LINES: line displayed across three rows.
- NO-END-PUNCT: line without ending punctuation.
- FINAL-COMMA: line ending with a comma.
- UNPAIRED-PUNCT: punctuation marks without a counterpart.
- STRONG-EXCL: visible exclamation sign ("¡", "!" or fullwidth variant).
- STRONG-QUEST: word containing both opening "¿" and closing "?".
- MIXED-EMPHASIS: word combining two openings (¡¿) or two closings (?!).
- SEMICOLON: line containing ";".
- STUTTER: word containing the X-X pattern (same letter repeated with a hyphen).

### Layout and structure

- SHORT-LAST-LINE: visually short last line.
- BROKEN-TAG: empty or malformed override block.
- OVERLAP: overlap with another line.
- DEFAULT-STYLE: line using the Default style.
- ITALIC-ERROR: inconsistency in italics usage.
- PARENTHESES: parentheses without a counterpart.
- NAME-PREFIX: detected speaker-name prefix.
- MULTI-SENTENCE: more than one sentence in a single line.

### Override tag presence

- LINE-BREAK, POSITION-TAG, CLIP-TAG, FADE-TAG, TRANSFORM-TAG, KARAOKE-TAG.
- DRAWING-CLIP: vector drawing that also carries \clip or \iclip. Available as a Single Marker.

### Cleanup and content

- COMMENT-BLOCK: comment block embedded in the text.
- HAS-DIGITS: digits present.
- HAS-CJK: CJK characters or kana.
- FULL-ITALIC: entire line in italics.
- DOUBLE-SPACE: double spaces in the text.
- EDGE-SPACE: spaces at the start or end of the line.

## Utility Tools

Each section offers an independent dropdown. An empty value skips that section during execution.

### Case

- Toggle \an8: toggles the top alignment \an8.
- Toggle Italics: toggles italics.
- Uppercase: converts the entire text to uppercase.
- Lowercase: converts the entire text to lowercase.
- Title Case: capitalizes each word.
- Sentence Case: capitalizes the first word of each sentence.
- Capitalize First: capitalizes the first visible character.
- Lowercase First: converts the first visible character to lowercase.

### Punct / Text

- Toggle ¡!: toggles the opening exclamation mark.
- Toggle ¿?: toggles the opening question mark.
- Toggle ¡¿?!: toggles both opening signs.
- Normalize Ellipsis: standardizes ellipsis characters.
- Add Ellipsis: appends an ellipsis at the end of the line.
- Erase Leading Ellipsis: removes an ellipsis at the start of the line.
- Erase Inner Ellipsis: removes ellipsis inside the sentence while preserving a final ellipsis.
- Ellipsis to Comma: replaces final ellipsis with a comma.
- Ellipsis to Period: replaces final ellipsis with a period.
- Unify Quotes: standardizes quotation marks.
- Latin Quotes («»): converts quotes to Latin guillemets.
- Normalize Dashes: standardizes hyphens, en-dashes, and em-dashes.
- Trim Trailing Spaces: removes trailing spaces.
- Remove Duplicate Letters: removes consecutive duplicate letters.
- Add Stutter: inserts stutter formatting in the text.
- Add Ah Prefix: inserts an "ah" prefix at the start of the dialogue.
- Stutter Manager: interactive dialog for stutter management.

### Tags / Comments

- Fold by Identifier: groups lines sharing the same identifier into folds. A fold is created only when the group contains two or more lines.
- Extract Tags: moves override tags from the text into the Effect field.
- Reinsert Tags: returns override tags from Effect to the text and converts semicolons to commas inside override blocks.
- Remove Tags: deletes override blocks from the visible dialogue.
- Merge Tags: merges adjacent override tag blocks, deleting the }{ between them ({\an5}{\blur2} becomes {\an5\blur2}). Comment blocks and non-adjacent blocks are left untouched.
- Remove Comments: deletes comment blocks within the text.
- Actor Parser: extracts actor information from the text.
- Swap Comment: toggles the comment state of the line.
- Delete Comment Lines: deletes lines flagged as comments.
- Comments to Top: reorders comments to the top of the selection.
- Comments to Bottom: reorders comments to the bottom of the selection.
- Effects to Top: moves lines with a non-empty Effect to the top of the selection while preserving their relative order.

### Smart

- Bidirectional Snapping: snaps both start and end to the nearest keyframe within the configured frame range.
- Remove Honorifics: wraps Japanese honorifics in {…} comment blocks so they stay in the source but disappear from the visual render.
- Caption Clarifier: standardizes caption brackets and indications.
- Complete Sentences: joins an incomplete line with the next line when the next text starts lowercase. Overlaps or non-lowercase continuations are marked as [POSSIBLE-JOIN] instead.
- Erase Blank Lines: deletes blank lines.
- Frame Effect: writes the start-frame number into Effect.
- Copy Fold: displays ASS event rows from the fold containing the first selected line for copying, then selects that fold.

### Split / Join

- Smart Break: inserts a \N line break at the optimal position only when the rendered text exceeds the available width.
- Split by Sentence: splits the line by sentence.
- Split by Comma: splits the line by comma.
- Pivot \N: shifts the \N break within the line.
- Remove \N: removes every \N from the line, collapsing whitespace.
- Join Lines: joins selected lines in grid order and spans their earliest start and latest end, retaining the first row metadata.
- Join Same Text: joins adjacent lines with identical text.
- Join Overlaps: joins selected groups whose times overlap, expands the kept line to the group bounds, and preserves each source text separated by \N.
- Join Overlap Sentences: joins selected overlapping groups in grid order as one sentence, keeps the first grid line as base, and extends the end time to the group end.
- Divide by \N: splits the line on every existing \N break.

### Time / Sort

- Copy Times: copies timing from one line to others.
- Time Picker: selects lines within a time range.
- Sort by Length: sorts the lines by visible length.
- Sort by CPS: sorts the lines by reading speed.
- Sort Odd Even: sorts by the numeric value of the Effect field (odd and even).
- Count CPS: shows the average CPS across the selection.
- Import Text: imports text from an external source for controlled replacement.
- Kite Timing: applies the Kite Timing algorithm (adaptive lead-in and lead-out, chaining, and edge protection) using the values from Config.
- Shift First: shifts the selection so the first line aligns with the start of the second.
- Start Snap Back: snaps the start to the previous keyframe.
- Start Snap Forward: snaps the start to the next keyframe.
- End Snap Back: snaps the end to the previous keyframe.
- End Snap Forward: snaps the end to the next keyframe.
- Add Lead-In Left: moves the start back by the configured step (Config → Lead-In / Lead-Out). A neighbour chained at gap 0 moves its end along to keep the chain; with a positive gap the start only advances until it touches the neighbour, never overlapping it.
- Add Lead-In Right: moves the start forward by the configured step. A neighbour chained at gap 0 moves its end along to keep the chain.
- Add Lead-Out Left: moves the end back by the configured step. A chained next line moves its start along to keep the chain.
- Add Lead-Out Right: moves the end forward by the configured step, pushing the start of a chained next line.
- Chain Left: extends the start back to the previous line's end (creates gap 0), within the configured max distance.
- Chain Right: extends the end to the next line's start (creates gap 0), within the configured max distance.

### Karaoke

- Romaji Karaoker (Word → \k): generates word-level romaji karaoke with {\k} tags.

## Data Import

The import source is the text pasted into the Data Import box. An empty box skips this section.

- **Import Effects:** copies the source Effect by time overlap.
- **Import Text:** copies visible text by time overlap.
- **Import Actor:** copies actor by best time overlap.
- **Import Tags:** copies initial override tags from overlapping source lines. Imported tags override matching initial tags in the target line; inline tags after visible text are ignored.
- **Song Sync:** duplicates or synchronizes groups using a Comment line on layer 50 as the sync anchor. The selected line's Effect is copied into each imported line's Effect; source Effects are retained.
- **Same Layers:** when checked, Import Effects, Import Text, Import Actor, and Import Tags only match source lines whose layer equals the target line layer.
- **Import as comments:** wraps the imported text inside {…} comment blocks.

## Extra Tools

- **AE Export:** exports motion data compatible with After Effects.
- **Text Replacer:** replaces visible text while preserving override tags.
- **mpv QC:** reads notes exported from mpvQC in the format [hh:mm:ss.ms] [Type] Observation {suggested text}. The observation is written as [QC: …] in Effect and the suggestion is inserted as a comment block in the dialogue. Tolerance is defined in milliseconds.
- **Remover Assistant:** removes selected visible signs, spacing tokens, comments, and known override tags without toggling them back on when absent.
- **Properties and Cleanup:** edits script credits and title. The optional cleanup affects the whole file, removing project paths, extradata, comments, Actor, Effect and empty dialogue lines.

## Auto Timing

Auto Timing has two main methods, plus a separate Legacy path. Every control lives in this window and persists in the Chrono Suite configuration.

- **Method:**
- Lazy: reads spoken activity from a peaks JSON. It is the simple method and needs no extra module.
- Busy: combines silence, VAD, flux, RMS envelope, and optional waveform data. It requires the bundled `kite.Timing` module.
- **Mode for Lazy and Busy:**
- Full + polish: detect the voice, then pad, chain, and snap to video keyframes.
- Raw voice: move each line onto the detected voice start/end with no padding. It does not use keyframes.
- Post current: keep the current in/out and only run the final padding, chaining, and video-keyframe pass.
- **Waveform JSON:** a peaks file (min/max samples). Type a path or pick one with Browse...; it is cached for the session, and Reload waveform cache forces a fresh read.
- Keyframes come from the loaded video, the same way the audit markers read them. Full + polish and Post current need them; Raw voice does not.
- Busy Files... opens only the file inputs used by Busy. If Busy is processed without a JSON or Busy files, this window opens first.
- Legacy... opens the Legacy method selector and silence files. Legacy aligns line edges to silence clusters, does not use video keyframes, and writes [LZ ...] tags.
- **Style filter:** All, All Default, Default+Alt, or an exact style, plus a second exact style in the extra box.
- Problem lines are marked in Effect with [TM-...] markers (no voice, weak match, overlap, short, fast CPS), cleaned on the next run.

## Auto Timing: detection and margins

Lazy smooths the peak envelope, thresholds it, cleans the mask, and keeps the speech span each line is then padded around. Busy reuses the same final margins on its combined match.

- **Search ± (ms):** how far beyond the line's own in/out to look for the voice (0 = stay inside the line).
- **Smoothing (ms):** width of the envelope smoothing window.
- **Auto threshold (Otsu):** choose the speech/silence cut automatically; off falls back to a percentile sensitivity.
- **Bridge gaps / Drop islands (ms):** close micro-silences and discard micro-blips before the span is measured.
- **Trim small edge spill:** drop a faint, well-separated blip stuck to a line edge so it does not stretch the timing.
- **Margins · post-timing:** lead-in / lead-out, chain max out / in, KF snap end / start, voice-cut limit, duration floor, and the CPS flag — the default criteria that shape how the raw span becomes the final in/out.

## Extract KF

Generates a keyframe log through SCXvid, with FFmpeg used for decoding. The SCXvid path, FFmpeg path, and log suffix are configured in Config → SCXvid.

## Scream Detector

Audio-level review tool. Runs FFmpeg astats on the loaded audio/video and writes the [SCREAM] marker to lines whose interval is statistically loud relative to the rest of the analysed set.

- **Average line dB:** mean power inside each subtitle interval. Closer to 0 is stricter.
- **Strong sample dB:** samples above this value count as strong evidence.
- **Strong sample ratio (%):** minimum percent of strong samples per interval.
- **Minimum samples:** ignores lines with too little audio evidence.
- **Robust z-score:** compares each line against the median/MAD of the analysed set.
- **Apply to:** All dialogue or Selected lines only.
- **Clear previous SCREAM marks:** removes earlier [SCREAM] in scope before writing new ones.
- **Reuse existing analysis log:** skips FFmpeg if a previous log exists. Useful for recalibration.

## Config

Global configuration persisted between sessions.

- **Language:** en, es, pt.
- Auto Timing keeps its own source, mode, detection, margin, and silence controls in the Auto Timing window, not here.
- **SCXvid:** SCXvid path, FFmpeg path, and log suffix.
- **Lead-In / Lead-Out / Chain:** step in milliseconds for the lead utilities and max distance for Chain Left/Right.
- **Kite Timing:** base and maximum lead-in, base and maximum lead-out, chain out, and maximum chain gap.
- **Bidirectional Snapping:** frame range for the bidirectional snap, and directional range in milliseconds for the Start/End Snap tools.
- **Audit Presets:** Twin/Miss pairs for Start, End, and Full; Short/Long thresholds; maximum CPS; Short, Large, and Both gap presets; overtime; maximum width.

## Support

[Support Discord](https://discord.gg/Egq8us4xZC).

## Properties and Cleanup in detail

Edit Title, Original Script, Original Translation, Original Editing, Original Timing, Synch Point, Script Updated By and Update Details. Add episode from filename requires a saved subtitle filename with an episode number and a nonempty title. EventOps 1.3.1 ignores bracketed resolution/hash suffixes, recognizes SxxExx and preserves long episode numbers without numeric conversion. Cleanup checks cancellation during mutation and restores on failure. Invalid input returns to the edited form. Save updates the script info fields; Cancel leaves them unchanged.

With **Clean the whole subtitle file**, the shared EventOps operation also removes project path metadata, extradata, comment events and inline comments, clears Actor and Effect, and removes empty dialogue. This affects all events. Keep an editable working copy if those fields carry timing notes or workflow metadata.

## Worked examples and boundaries

- Join Lines with rows at 4–5 s and 1–2 s retains text in grid order but produces an event at 1–5 s. It preserves the first row's initial tags and metadata, not every row's inline formatting. Join Same Text additionally requires compatible style and adjacent selected rows.
- An Auto Timing overlap can involve more than three subsequent rows. The final pass checks all remaining candidates until their earliest possible start is beyond the current end; stacked original lines retain their existing handling.
- A waveform file provides positive finite `pointMs` and alternating integer min/max `peaks`. Decimal/garbage peaks and incomplete pairs are rejected instead of partially read. Scientific notation in pointMs is read as a complete number. Changing the typed path invalidates the session cache; returning from a secondary window retains the typed path.
- Durations stay nonnegative, smoothing and island controls enforce their minimum values, and percentages keep their 0–100 range. Increasing a search window can match unrelated speech, so select it according to the scene.
- FFmpeg analysis and SCXvid extraction require the configured executables and readable media. Scream Detector marks relative loudness; it does not identify an emotion or speaker.

## Persistence and requirements

Preferences are saved for each tool.

The interface supports English, Spanish and Portuguese. Stable English action IDs keep existing hotkeys usable while display labels are localized.
