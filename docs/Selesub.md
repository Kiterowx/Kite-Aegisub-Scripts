# Selesub 2.1.8

English | [Español](es/Selesub.md) | [Index](../README.md#documentation)

Selesub finds subtitle events, selects or comments matches, deletes confirmed matches, manages groups of field values, and transfers selected events through ASS files. It also registers twenty navigation actions for hotkeys.

Menu: `Selesub`.

## Find and act on lines

1. Choose **All** or **Selection** as the scope. Only Dialogue and Comment events participate; headers and styles do not.
2. Choose **Select**, **Comment**, or **Delete**.
3. Choose one or more exact values or an advanced search. An empty dropdown means no restriction; `<empty>` represents an actual empty field.
4. Press **Run**. Invalid queries and empty results return to the same window with the entered values intact.

All active exact fields must match: Effect, Actor, Layer and Style. Exact dropdowns compare their underlying values, including case and whitespace. They list values from the whole subtitle file even when the scope is Selection. Colliding display labels receive a numeric suffix without changing the original values.

The advanced condition is combined with the exact fields. **Invert advanced** negates only that condition, including its exclusion; it does not invert the exact dropdowns or the comment filter. **Include comments** determines whether Comment events participate. **First match** stops at the first matching event in subtitle order, including within a selection.

**Select** returns all matching indices. **Comment** changes only matches that are not already comments and leaves them selected. **Delete** presents the match count for confirmation and returns an empty selection after deletion. Closing the confirmation preserves the incoming selection. Changes are undoable through Aegisub.

## Advanced fields

| Field | Value searched |
| --- | --- |
| Text | Complete event text, including ASS tags and comment blocks. |
| Visible Text | Text obtained from the shared ASS section parser; override blocks, comment blocks and drawing payloads are omitted. ASS line breaks and hard spaces become whitespace. This is a text extraction, not an evaluation of transparency at a video frame. |
| ASS Comments | Contents of ordinary `{comment}` blocks, joined with newlines. Override blocks are excluded. |
| Style, Actor, Effect | The corresponding event property. |
| Type | `Dialogue` or `Comment`. |
| Text+Actor+Effect | Those three fields joined with newlines. |
| Text+Actor+Effect+Style | Those four fields joined with newlines. |
| Layer | Event layer. |
| Duration | End minus start, in milliseconds. |
| Word Count | Whitespace-separated units in visible text. It does not perform language-specific word segmentation. |
| Character Count | Visible graphemes, excluding whitespace and `. , ? ! ' " —`. Combining marks and joined emoji stay with their character. Other punctuation counts. |
| CPS | Character Count divided by duration in seconds, rounded upward. Zero or negative duration produces zero. |
| Blur | Last explicit top-level `\blur`, or zero if absent. Transforms and style border are not evaluated as blur. |
| Margin L, Margin R, Margin V | Event margin values; zero remains zero and does not resolve the style margin. |
| Start, End | Absolute event time. |
| Event Number | One-based event number in the complete subtitle file, excluding headers and styles. A selection does not restart numbering. |

Numeric comparisons reject non-finite computed values. There is no match-count ceiling.

## Operators and examples

Text fields support **Contains**, **Exact**, **Regex**, **All Words** and **Starts With**. **Match case** affects advanced text matching. All Words requires every whitespace-separated query fragment to occur somewhere in the searched value; it does not require whole-word boundaries or their original order.

**Exclude** rejects values containing the exclusion text. When the operator is Regex, Exclude is also a regular expression. Regex uses Aegisub's regex engine and is compiled before scanning; invalid expressions return an error without changing lines. Numeric searches ignore Exclude and Match case.

Numeric and time fields support `=`, `>=`, `<=`, **Range**, **Nonzero <=**, **Even** and **Odd**. Ranges include both endpoints and accept reversed endpoints. Even and Odd test integer parity; fractional values match neither. A query is required except for parity. If a stored operator is incompatible with the chosen field, the default becomes Contains for text or `=` for numbers and times.

| Task | Controls |
| --- | --- |
| Select all signs by an actor | Exact Actor = that actor; Action = Select. |
| Find long visible lines in the selection | Scope = Selection; Field = Character Count; Match = `>=`; Find = `45`. |
| Find rapid lines | Field = CPS; Match = `>=`; Find = `20`. |
| Find tags without searching displayed text only | Field = Text; Match = Contains; Find = `\clip(`. |
| Find events starting in an interval | Field = Start; Match = Range; Find = `1:02:00.00-1:03:00.00`. This tests the start time, not interval overlap with the whole event. |
| Compare signed or fractional properties | Numeric ranges accept `-3--1` and `1e-3-2e-3`. |

Start and End accept integer milliseconds, `h:mm:ss.fraction`, `m:ss.fraction`, `1h2m3.5s`, `2m3.5s` or `3.5s`. Duration uses numeric milliseconds. In colon notation, seconds must be below sixty and the minutes component of a three-part time must be below sixty; the leading minutes in a two-part time may exceed fifty-nine. Invalid and overflowing inputs are rejected.

## Values manager

**Values** opens the group manager. Choose **Nature** (Style, Actor, Effect or Layer), **Scope** (Selection or All), and an action. The window shows one value per line and its event count.

The editable list contains values to **keep**. Delete a value from this list to target its events. The count column is informational; editing it has no effect. Preserve the exact displayed labels, including whitespace and any collision suffix. Duplicate kept labels do not multiply events. Unknown labels return an error and preserve the draft.

| Button | Result |
| --- | --- |
| Apply | Applies the action to groups omitted from the keep list. Select returns those events. Comment and Delete request confirmation with kept and affected counts. An empty list can target the entire scope and is identified in the confirmation. |
| Current | Uses the incoming subtitle selection directly, independently of the keep list and chosen Nature. Select returns it, Comment comments it, and Delete requests confirmation. |
| Refresh | Rebuilds the groups and restores all current values to the keep list. |
| Close | Returns to the main window without applying the draft. |

Changing Nature or Scope rebuilds the list before applying anything; edit the refreshed list and press Apply again. This prevents an old list from targeting a new group source. The manager includes Comment events. Its scope and action preferences are separate from the main window, although opening it initially uses the main window's action.

## Export and import

**Export** writes the incoming subtitle selection, not the unexecuted filter results. Select subtitle events first. Choose a path; `.ass` is appended if needed. The file includes the current script information, Aegisub project data, all styles and selected events in subtitle order. Event extra data is regenerated with its references. Source event text is not modified. Output is written through the shared atomic-file helper; failures are reported.

**Import** reads an ASS file using `myaa.ASSParser`. It appends its events to the current file and adds missing styles before the first event. Existing style names are matched case-insensitively and reused without replacing their properties. Therefore an imported line can use the current file's appearance when a same-named source style differs. Source script resolution and project metadata are not imported; the current file's resolution remains in effect. Inline named style resets are preserved as written.

Imported Dialogue/Comment status, text, fields and extra data come from the parser. The returned selection includes all imported events and accounts for newly inserted styles. Parse failures and empty imports leave the subtitle file unchanged; the commit is transactional. The third-party parser supports ASS sections and may skip malformed individual records; this is not a general converter for subtitle formats or embedded fonts/graphics.

Successful import or export closes the main window. Cancelling the file dialog or a failed operation returns to it with its search draft intact.

## Hotkeys

The public action root remains `: Kite Hotkeys :/Selesub`. For each of **Style**, **Actor** and **Effect**, six actions use the active event's exact, case-sensitive value:

| Action | Behavior |
| --- | --- |
| Select All | Selects every event with that value; retains the active row. |
| Previous / Next | Jumps to the nearest previous or next matching event. Does not wrap at file boundaries. |
| Block Start / Block End | Selects the first or last event in the contiguous block containing the active event. |
| Select Block | Selects that entire contiguous block and retains the active row. |

`Range/To Start` selects all events from the first event through the active row. `Range/To End` selects from the active row through the final event. Both include the active row. Comment events participate in all navigation actions. Invalid active rows leave the selection unchanged.

These actions work without installing the Hotkeys macro. Their registered paths remain compatible with existing bindings.

## Preferences, cancellation and dependencies

Selesub remembers scope, action, advanced field/operator and option checkboxes after a successful Run. It deliberately does not persist exact filter values or search/exclusion text. Manager Nature, Scope and Action are also remembered. Write failures are reported; an in-memory choice is not presented as successfully saved.

Scanning and mutation loops check cancellation. Comment/delete/import commits use shared transactions; file output uses the atomic writer. No arbitrary event-count or import-size ceiling is imposed.

Install `myaa.ASSParser` and follow the [installation steps](../README.md#installation).
