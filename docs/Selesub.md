# Selesub 2.1.1

Selesub filters, selects, comments, deletes, imports, and exports subtitle events from one interface.

Menu root: `Selesub`

Namespace: `kite.Selesub`

## Main filters

The exact-value row filters by Effect, Actor, Layer, and Style. Active fields are combined, and the scope can be the whole subtitle file or the current selection.

Advanced search covers:

- Text, visible text, ASS comments, Style, Actor, Effect, and event type.
- Layer, duration, word count, character count, CPS, blur, margins, start, end, and event number.
- Contains, exact, regular-expression, all-words, prefix, comparison, range, parity, exclusion, case, inversion, and first-match controls.

The result can be selected, commented, or deleted. Destructive actions require confirmation and remain undoable through Aegisub.

## Values manager

**Values** groups Style, Actor, Effect, or Layer values, displays their event counts, and lets you keep or remove groups from the editable list. The selected action is then applied to the omitted groups within the chosen scope.

## Import and export

- **Export** writes the selected events to an ASS file together with the current script information, project data, and styles.
- **Import** adds ASS events and any missing styles, preserving existing style names case-insensitively.

## Hotkey actions

Assignable entries are registered under `: Kite Hotkeys :/Selesub` for Style, Actor, and Effect navigation:

- Select all lines with the active value.
- Jump to the previous or next matching line.
- Jump to the start or end of a contiguous matching block.
- Select the matching block.
- Select from the start to the active line, or from the active line to the end.

## Requirements

- `kite.UI` 1.1.0
- `aegisub.re`
- `aegisub.unicode`
- `myaa.ASSParser` 0.0.4
