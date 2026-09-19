# Alecto KFX 3.4.3

English | [Español](es/AlectoKFX.md) | [Index](../README.md#documentation)

Alecto KFX compiles karaoke and plain-text targets from editable `intro`, `active`, and `outro` guide lines. It reprojects guide timing, position, movement, clips, transforms, colors, and fades onto syllables, graphemes, words, or whole lines.

Menu root: `Alecto KFX`

## Commands

- **Aplicar** compiles the selected targets and replaces only their associated output.
- **Generar líneas base** creates editable guide blocks from selected targets.
- **Validar selección** reports guide syntax, geometry, gaps, target issues, and the estimated event count without changing the file.
- **Limpiar FX seleccionados** removes only the output associated with the selected source or generated event and restores the source's original Comment state.
- **Configurar** changes timing defaults and the event limit persistently in the shared settings store.

Every command in the Alecto KFX submenu can be assigned directly as a hotkey in Aegisub.

## Workflow

1. Select one or more target lines.
2. Run **Generar líneas base**, or prepare your own guide lines with `Effect` set to `intro`, `active`, or `outro`.
3. Edit the guide styling, motion, clips, timing, and Actor options.
4. Select the guides and targets.
5. Run **Validar selección**, then **Aplicar**.

If no guide is selected, Alecto looks for a contiguous guide block immediately above the first target. A missing phase uses a neutral guide on the target's original layer.

## Actor options

Units:

- `char` or `grapheme`
- `syl` or `syllable`
- `word`
- `line`

Flags and values:

- `nobase`, `nofade`, `nostagger`
- `lead=`, `tail=`, `fade=`, `stagger=`, `gap=`
- `order=ltr|rtl|center|edges`
- `group=`, `channel=`
- `inherit=static|none`

Guide values override target values, which override the saved defaults.

## Reapplication and cleanup

Each source receives a private persistent UID and each generated event carries that UID in its `Effect`. This keeps byte-identical sources independent and allows moved FX to resolve back to the correct source.

Version 3.1 markers without a UID remain supported when they are contiguous with their source or their fingerprint is unique. If a moved legacy marker is ambiguous between identical sources, Alecto aborts without changing the subtitle file.

Generation, cancellation, event-budget checks, and base-line planning finish before any subtitle mutation. The configured event limit is enforced before rendering the event that would exceed it.

Apply, cleanup, and base insertion are transactional. Gap detection excludes only the actual source row, so byte-identical targets still block one another correctly. Base guide timestamps follow the targets' timeline order even though rows are inserted from bottom to top.

## Requirements

Follow the [installation steps](../README.md#installation) and keep Aegisub’s bundled `karaskel.lua`.

Alecto prefers Aegisub's `include("karaskel.lua")` loader and falls back to `require("karaskel")` when needed.

## Deliberate limits

- Vector drawing targets (`\p`) are rejected as text targets.
- Multiline unit geometry is approximate; use `line` or separate ASS events for precise multiline layouts.
- Grapheme grouping is portable and approximate rather than a complete Unicode UAX #29 implementation.

## Choosing the operation and unit

The launcher presents the same operations as the direct menu commands. Use **Generar líneas base** when you need editable examples, **Validar selección** for diagnosis, and **Aplicar** when the guides are ready. Apply selects the new FX, base generation selects the new guides, and cleanup selects the restored sources. Indices remain correct across multiple sources and deletions.

`char` works on shared grapheme boundaries, including combining marks, emoji joined with ZWJ, paired regional flags and decomposed Hangul. ASS escapes `\N`, `\n` and `\h` remain distinct spacing/control tokens rather than animation samples. `syl` follows karaoke syllable timing; `word` groups visible words; `line` keeps the whole target together. Use `line` for a sign whose motion must stay coherent across the text.

## Timing, geometry and inheritance

Guide timing is relative to its duration. Alecto maps position, move endpoints, origin and clips into each target unit and maps transform/fade timing into the generated phase. For example, a 1000 ms guide transform spanning 200–800 ms becomes 60–240 ms in a 300 ms phase. Nested tag arguments are read by the shared balanced parser; font names and named resets retain their complete values.

Intro starts before the unit, active follows its karaoke interval, and outro follows the end. Lead, tail, fade and stagger values are milliseconds. `gap`/`respiro` reserve space between neighboring targets; `channel` limits which neighbors share that space. `group` chooses matching guides. `inherit=none` avoids importing the target's initial static tags; it does not delete the guide's own tags. Geometry uses karaskel measurements, so font availability matters.

Example Actor: `char lead=300 fade=200 stagger=40 order=edges group=outline`. Set the same `group=outline` on the intended guides and targets. Select both and validate before applying.

## Budgets and cancellation

The default event budget is 20000 and can be changed without an upper UI cap. Set it to **0** to disable the event-count limit. This is a saved preference. Validation estimates output; generation checks the budget before producing the next event. Cancellation is checked during generation and insertion/deletion, with transactional rollback for changes already started. Very large output still consumes memory and Aegisub processing time.

Keep source provenance metadata and the generated `alecto-fx` Effect value intact to preserve reapplication and cleanup. These are technical identifiers, not labels to rename manually.
