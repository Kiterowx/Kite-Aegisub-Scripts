# Macaria Revert 1.0.2

English | [Español](es/MacariaRevert.md) | [Index](../README.md#documentation)

Macaria Revert recovers editable base karaoke lines from selected generated events. It is the recovery sibling of [Alecto KFX](AlectoKFX.md) and [Zagreo Glyphs](ZagreoGlyphs.md). Recovery uses temporal and spatial evidence in the generated subtitle; it cannot reverse every possible effect or reconstruct information that was discarded during generation.

Default main command: **Macaria Revert**. Default direct command: **: Kite Hotkeys :/Macaria Revert/Reconstruct**. DependencyControl's saved custom menu can prefix these paths.

## Workflow

1. Select generated events belonging to the karaoke you want to recover. Include their layers and phases where possible.
2. Open Macaria Revert and choose the tolerances, spacing and alignment options.
3. Use **Preview** to inspect the count and complete ASS text of the proposed bases.
4. Adjust the options and preview again if necessary.
5. Use **Reconstruct** to save the options and insert the recovered bases.

The originals remain in place. New bases are comments with `Effect=karaoke`, inserted after the last selected dialogue. They become the new selection, with the first base active. The complete insertion has one undo point and rolls back on failure or cancellation. Duplicate, unsorted and out-of-range selection indices are normalized before processing.

Preview does not change subtitles or save preferences. Cancel closes without inserting or saving a draft. The report box is an output reference: editing its text does not change the proposed lines. Reconstruct analyzes the current input and current options again, so it never applies a stale preview after you change the form.

If no valid chain is found, the window stays open with the report. Analysis errors also preserve the current options. If saving preferences fails, the window shows the error and retains the draft without inserting lines; you can correct the storage problem and retry or cancel. Cancellation during analysis is propagated rather than presented as an ordinary reconstruction failure.

## Controls

| Control | Purpose | Default |
| --- | --- | --- |
| Position tolerance | Maximum difference per coordinate when matching anchor positions and phases | 4 ASS units |
| Row tolerance | Vertical distance allowed when grouping fragments into one row | 20 ASS units |
| Time tolerance | Difference allowed between adjacent temporal boundaries | 10 ms |
| Infer word spacing | Use available style measurements and glyph-layer spacing evidence | On |
| Include alignment tags | Emit inferred alignment when it differs from the base style | On |

Tolerances accept finite, non-negative values with no fixed upper ceiling. Zero requests exact matching. Large tolerances can combine unrelated fragments; increase them only to accommodate the observed tracking or rounding variation. Coordinates use the subtitle's ASS resolution. Alignment inference reads the current document resolution.

The scrollable report includes the full ASS text of every proposed event. Aegisub's own dialog layout and font determine the physical window size.

## Recognized patterns

| Pattern | Required evidence | Recovered timing |
| --- | --- | --- |
| Paired transformation phases | Matching prior and active events, with a usable active transformation | Contiguous active transformation spans |
| Repeated active layers followed by a body | At least three matching moving copies, followed by a fixed-position body with a common line end | Active start boundaries and the body end |
| Contiguous event chain | Spatially ordered fragments with adjacent times and repeated phases | Fragment timings and the inferred phase span |

These patterns run in that order. Equivalent phase layers merge into one candidate, preventing duplicate bases. Recovery of one interval does not suppress independent karaoke later on the same row. The search stops when no eligible candidates remain. The minimum chain length and coverage checks remain evidence requirements rather than output-count limits.

Comments inside event text do not supply tags. Only valid top-level `\pos` or `\move` supplies a fragment position. Movement is evaluated at the event start; `\an`, legacy `\a` and style alignment share the common ASS context reader. A style's implicit position alone does not reveal the original arrangement of separated fragments, so such events are skipped. Text outside drawing mode is retained, including invisible phases and ASS text escapes. Reset tags end drawing mode. Transformation arguments use the shared parser, including acceleration and implicit-duration forms.

The result uses `\k` timing in centiseconds. Quantizing accumulated boundaries preserves the total span: 33, 33 and 34 ms produce `\k3`, `\k4` and `\k3`. The style belongs to the recovered group; the layer is the lowest observed layer, and actor/margins use the most frequent values. The output intentionally describes a base karaoke rather than reproducing the generated appearance.

## Example

Suppose selected layers contain A at one position from 0–500 ms and B farther right from 500–1000 ms, with repeated phases beginning 1000 ms later. With a valid phase pattern and no inferred space, Macaria can propose a commented base from 0–1000 ms:

```ass
{\k50}A{\k50}B
```

Preview the proposed start/end and text before using the base in another effect. If a space is missing, check whether the selected layers or style metrics actually contain spacing evidence. If a row is skipped, inspect position tags, durations and the presence of matching phases before widening tolerances.

## Direct access and settings

The direct hotkey command runs immediately with engine defaults; it does not reuse the window's saved adjustments. It reports failure or an empty recovery without inserting lines. Use the main window when you want custom options or review before insertion.

Install the modules included in the repository. Your reconstruction preferences are saved between sessions.

## Practical limits

Recovery is heuristic, with horizontal chain ordering in the ordinary/paired patterns. Overlapping fragments, nonstandard motion, incomplete selections, missing font metrics and discarded source timing can require manual correction.
