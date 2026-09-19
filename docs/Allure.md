# Allure 1.2.4

English | [Español](es/Allure.md) | [Index](../README.md#documentation)

Allure saves reusable sign styles and transforms selected layers around a shared pivot. The interface is available in English and Spanish.

Menu root: `Allure`

## Makeup

Makeup stores two kinds of reusable records:

- `[TAG] Name` is an adaptive preset. It preserves styles, tags, drawings, geometry, clips, and structural anchors while adapting the saved treatment to new text.
- `[GROUP] Name` is an exact sign group. It preserves complete ASS events, including text, drawings, inline tags, perspective data, actor/effect fields, comments, timing relationships, and layer order.

The active source line is the capture anchor. On insertion, positions, moves, origins, perspective coordinates, and clips are translated to the destination anchor. Layer offsets are preserved for the complete stack.

The subtitle folder contains a small `Makeup Library.index.json` index and a `Makeup Library` directory with one JSON file per preset. Records are loaded only when needed.

## Posing

Posing transforms the complete selected sign stack around one shared pivot. It can:

- move the stack horizontally or vertically;
- resize the stack by a relative percentage around the selected pivot;
- rotate it around the stack center, the first selected line anchor, or a custom pivot;
- rotate the group as one rigid composition or rotate individual lines around their own centers;
- expose direct hotkey actions for positive and negative X, Y, and Z steps.

Relative resize updates positions, movement endpoints, origins, rectangular or vector clips, drawings, and existing `\fscx`/`\fscy` values as one atomic transformation. Invalid geometry cancels the operation without applying a partial result.

The main dialog also provides configuration and help without opening a separate macro.

## Dependencies

Follow [Installation](../README.md#installation) and install `l0.dkjson` through DependencyControl.

## Capture and insertion workflow

1. Save the ASS file so the script can locate its preset library.
2. Select the source layers and make the intended reference line active.
3. Enter a name and choose **Save style**, **Save group**, or **Save both**, then press **Makeup**.
4. The window stays open and reloads the library. Close it, select your destination text, reopen Allure and select the saved record.
5. Choose **Insert preset** and the insertion mode, then press **Makeup**. The new output is selected.

Adaptive capture groups identical visible source texts into reusable slots. **Create from targets** accepts one target per slot and expands each group into the saved layer stack. When there are multiple slots, each target group must be contiguous and contain the required number of lines. **Replace selected layers** expects complete contiguous layer stacks with the same number of rows as the preset and changes those rows in place. These requirements prevent mixing unrelated stacks; there is no arbitrary cap on the number of complete groups.

Use **Save group** for drawing-only signs or when the original text and exact event fields are part of the design. Exact groups expand once per selected target. Their layer offsets and start/end offsets are relative to the captured active source. For example, a secondary layer beginning 200 ms later and ending 100 ms earlier retains those offsets at the destination. A destination interval too short for those offsets is rejected and the operation is rolled back.

## How adaptive styling follows text

Allure keeps grapheme boundaries and compares tokens, punctuation, words and phrases to place inline tags on equivalent parts of the new text. If structure differs, it maps relative positions within the available spans. The target's protected geometry takes precedence where appropriate; other layers retain their displacement from the source reference. Named style resets are remapped when an imported style must be renamed to avoid a collision.

Rectangular clip bands can be recognized as a common horizontal or vertical family; clips that overlap the source text box can follow the new box. This detection is heuristic. Font measurements, multiline layouts, perspective and unusually large or detached clips can require manual inspection. **Save group** preserves a deliberately fixed composition instead of adapting its text structure.

## Posing: position, pivot and motion

For a line without `\pos` or `\move`, Posing resolves position from PlayRes, style alignment, legacy `\a` or modern `\an`, and line/style margins. A line containing only a clip therefore still has a text anchor. Explicit `\move` endpoints move together; its time arguments remain unchanged.

The group center is the center of the bounds of the selected anchors and move endpoints, not a measured visual center of every glyph. **First line** uses the first selected row, whereas the active source line is the reference for preset capture. A custom pivot uses script coordinates. Positive relative resize enlarges the stack; `-50` halves it. A resize must leave a positive size.

Rotation and resize update existing appearance tags, nested transform values and named resets. A rotated static rectangle becomes a vector clip. A rectangular clip animated inside `\t` cannot be converted to an equivalent animated vector clip by this operation, so rotation is rejected; bake it frame by frame first. Individual rotation of a moving clipped line requires a fixed `\org` for the same reason. Lines containing both `\pos` and `\move` are rejected as ambiguous.

Vector clip scale is accepted when it is a positive integer and its coordinate factor is finite. Extremely large values remain constrained by Lua numeric precision and the subtitle renderer.

## Windows, preferences and failure recovery

Configuration controls the language, hotkey steps, rotation mode and pivot. Invalid step values keep the dialog open and preserve the other edited values. Help and configuration return to the main draft. Saving or deleting library records also returns to that draft. Closing a window cancels its current operation. Hotkey steps accept any positive finite value.

Preset files and the index use atomic file writes. Replacing a preset creates the new record before committing the index, so an index-write failure keeps the old record readable. The old file is removed after a successful commit. **Save both** stores two independent records; it is not a single transaction across the pair. Keep the index and record directory together when transferring a library.

Subtitle insertion and Posing changes use rollback on failures or cancellation. Posing checks cancellation during preflight and commit. Comments are excluded from Posing. Preset application reports an insertion failure to the window after restoring the subtitle state.
