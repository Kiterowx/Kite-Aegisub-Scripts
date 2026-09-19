# Pointiac 1.1.7

English | [Español](es/Pointiac.md) | [Index](../README.md#documentation)

Pointiac adds two small circular markers to each selected dialogue: one at its first visible frame and one at its last. The source remains unchanged. Open **Pointiac** from the Automation menu. DependencyControl may add a saved custom menu prefix.

## Use

1. Select the source dialogue lines. Commented dialogues are also accepted; their generated markers are ordinary visible dialogues.
2. Run **Pointiac** and choose the marker color, position, horizontal offset and layer offset.
3. Choose **Execute** to insert the two markers after each source. **Cancel** closes the form without insertion or configuration writes.

The inserted marker rows become the selection, with the first marker active. Duplicate/unsorted selected indices are normalized, and non-dialogue rows are excluded. Source text, timing, comment state and other source data remain intact.

## Controls

| Control | Behavior |
| --- | --- |
| Color | Primary color for both markers; accepts HTML RGB and ASS colors |
| FPS* | Positive fallback rate, used only when usable video timecodes are unavailable |
| X/Y | Top-left drawing position of the first circle, in ASS script coordinates |
| Offset X | Second marker's horizontal displacement relative to the first; positive, negative and zero are supported |
| Layer + | Integer offset from each source layer; the resulting layer is at least zero |

The circle's nominal diameter is 9.314 script units. The initial position centers the entire pair, including that diameter and the saved signed displacement. X/Y are recalculated from the current script resolution each time; color, FPS, displacement and layer offset are saved. Changing Offset X within the open form does not automatically rewrite a manually entered X value.

For example, X=100, Y=200 and Offset X=-20 place the first marker at (100,200) and the last at (80,200). Offset zero deliberately puts both at the same position. A one-frame source may display both markers simultaneously.

There is no hidden minimum separation and no ±100 layer-offset ceiling. Non-finite numerical inputs fall back to the corresponding default. A zero/negative fallback FPS uses 24. Fallback frame duration is rounded to whole milliseconds with a minimum of one millisecond.

## Timing

With loaded video timecodes, Pointiac finds the frame containing the source start and the frame containing the final millisecond before its end. The first marker stops at the next frame boundary or the source end, whichever comes first. The last marker starts at its frame boundary or the source start, whichever comes later. Partial first/last frames retain the source's exact boundaries, and variable frame durations are respected.

If either required frame conversion fails, the complete timing calculation falls back to FPS. It does not stretch a marker across the source merely because one boundary is missing. Without video data, a 25 FPS fallback gives a nominal 40 ms first/last interval. Short events are confined to their available interval. A source with nonpositive duration gets a fallback-length marker interval beginning at its nonnegative start.

## Marker appearance and data

Markers replace the copied text with a fixed ASS vector circle. They explicitly set alignment, position, zero border/shadow, neutral scale/rotation, visible alpha and the selected primary color. Consequently, a rotated, stretched or transparent source style does not distort or hide the markers. The original style reference and other line fields remain copied, but the relevant drawing properties are explicitly controlled.

Cancel stops generation. A failed or canceled insertion restores the subtitle file.

## Dependencies

Install the modules included with the scripts, following [Installation](../README.md#installation).
