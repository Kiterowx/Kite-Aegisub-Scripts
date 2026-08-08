# Alecto KFX 3.2.3

Alecto KFX compiles karaoke and plain-text targets from editable `intro`, `active`, and `outro` guide lines. It reprojects guide timing, position, movement, clips, transforms, colors, and fades onto syllables, graphemes, words, or whole lines.

Namespace: `kite.AlectoKFX`

Menu root: `Alecto KFX`

## Commands

- **Aplicar** compiles the selected targets and replaces only their associated output.
- **Generar líneas base** creates editable guide blocks from selected targets.
- **Validar selección** reports guide syntax, geometry, gaps, target issues, and the estimated event count without changing the file.
- **Limpiar FX seleccionados** removes only the output associated with the selected source or generated event and restores the source's original Comment state.
- **Configurar** changes timing defaults and the event limit for the current Aegisub session.

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

Guide values override target values, which override the session defaults.

## Reapplication and cleanup

Each source receives a private persistent UID and each generated event carries that UID in its `Effect`. This keeps byte-identical sources independent and allows moved FX to resolve back to the correct source.

Version 3.1 markers without a UID remain supported when they are contiguous with their source or their fingerprint is unique. If a moved legacy marker is ambiguous between identical sources, Alecto aborts without changing the subtitle file.

Generation, cancellation, event-budget checks, and base-line planning finish before any subtitle mutation. The configured event limit is enforced before rendering the event that would exceed it.

Apply, cleanup, and base insertion are transactional. Gap detection excludes only the actual source row, so byte-identical targets still block one another correctly. Base guide timestamps follow the targets' timeline order even though rows are inserted from bottom to top.

## Requirements

- Aegisub Automation 4 with its bundled `karaskel.lua`
- Lua 5.1 compatibility
- `kite.LineOps` 1.5.2
- `l0.DependencyControl` is optional when the required modules are already installed

Alecto prefers Aegisub's `include("karaskel.lua")` loader and falls back to `require("karaskel")` in external harnesses.

## Deliberate limits

- Vector drawing targets (`\p`) are rejected as text targets.
- Multiline unit geometry is approximate; use `line` or separate ASS events for precise multiline layouts.
- Grapheme grouping is portable and approximate rather than a complete Unicode UAX #29 implementation.
- Configuration changes last for the current Aegisub session.
