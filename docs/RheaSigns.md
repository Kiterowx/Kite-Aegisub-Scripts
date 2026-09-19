# Rhea Signs 2.1.4

English | [Español](es/RheaSigns.md) | [Index](../README.md#documentation)

Rhea Signs edits sign text, copies and adjusts tags, constructs masks, distributes text, manages perspective and edits fonts/styles. Interface languages: English, Spanish and Portuguese.

Main menu: **Rhea Signs**. The dedicated commands are registered under `: Kite Hotkeys :/Rhea Signs`; DependencyControl may prepend the user's custom menu. Hotkeys is optional.

## Commands

| Command | Purpose |
| --- | --- |
| Rhea Signs | Open the main panel and combine operations |
| TagOps | Copy, retain, resize, transform or align tags |
| Fast Signs | Build a background, glow and text stack |
| Signs Editor | Replace repeated text and regenerate marked gradients |
| Shapes/Unify Positions | Share a drawing pivot while preserving placement |
| Shapes/Place on Perimeter | Repeat drawing units around closed contours |
| Shapes/Shape Color Optimizer | Merge compatible colors or reduce a gradient |
| Tools/Style to Tags | Bake selected style properties into override tags |
| Font and Style Manager | Inspect fonts, replace fonts, edit or clone styles |
| Fast Fades | Choose a frame fade or continuous cleanup |
| Fast Fades/In | Set fade-in duration using the active video frame |
| Fast Fades/Out | Set fade-out duration using the active video frame |
| Fast Fades/Clean | Remove internal fades between continuous groups |
| Shuffle Line Text | Shuffle text while retaining event properties |

## Main panel

The panel has **Masks**, **Perspective**, **Shapes**, **Sign** and **Toolbox** sections. An empty action means that section is skipped. **Execute** processes the chosen sections in this order:

1. Perspective.
2. Masks.
3. Shapes.
4. Sign layout.
5. Toolbox.

Generated selections feed the next operation. A perspective operation that cannot complete stops the chain. Each modifying operation has its own cancellation/rollback boundary; an error in a later operation does not intentionally undo a previously completed operation.

The panel also opens Signs Editor, Fast Signs, TagOps, configuration and help. Closing a child dialog returns to the main panel where that workflow supports it. Settings and the current dialog draft survive those transitions. A direct command opens its own workflow without requiring the main panel.

## Signs Editor

Select the events containing the sign. The first dialog controls grouping:

| Option | Behavior |
| --- | --- |
| Skip vector drawings | Exclude events containing active drawing sections |
| Detect/regenerate GBC | Enable interpolation for lines carrying a `{*...}` marker |
| Character limit | Optional filter, disabled by default |
| Limit value | Default 150; counts graphemes and ASS text escapes, not UTF-8 bytes |

The editor groups events with identical visible text. Groups appear in subtitle order; repeated occurrences share one editable row. `\N`, `\n` and `\h` remain literal ASS escapes within a row. The left panel is a reference; only the right panel determines the replacement.

Keep one row per group. An incorrect row count displays the expected/received totals and reopens the editor with the draft intact. Trailing extra empty rows are ignored. A required row can be empty to remove its text.

Text is distributed across existing ASS text sections using cumulative proportional boundaries. Tags, comments and drawing sections keep their place. Shorter replacements may leave an empty text section; characters are not duplicated merely to keep every section nonempty.

When regeneration is enabled, marked groups can be regenerated even if their visible text was not changed. The marker identifies the interpolated tag; the fallback is primary color. Interpolation follows effective tag anchors, inserts intermediate values per grapheme and removes the automatic markers. Combining marks and joined emoji stay together. ASS breaks and literal private-use characters are preserved without temporary substitutions.

Example: replacing three styled text sections `A{\b1}B{\i1}C` with `XY` assigns `X`, an empty middle section and `Y`. It preserves the formatting boundaries instead of moving both characters into the final sections.

## TagOps

### Copy tags

Choose tag checkboxes and **Copy tags**. Events with the same Effect value form source/target groups. The first selected event in each usable group supplies tags. If no Effect group has a target, the first selected event supplies the remaining selection.

- **Read all blocks** reads all override blocks; otherwise only the first override block is used.
- **Replace** removes corresponding destination tags before insertion. Related alternatives such as `pos`/`move` and `clip`/`iclip` are treated together.
- **Append** appends the copied payload to the leading override block; otherwise it is prepended.
- **Show result** reports copied categories and modified targets.

Comments and nested parentheses are recognized structurally. Copying `t` retains its payload as a transform. The operation reports a missing source category instead of writing an empty replacement.

### Keep only

Choose categories and **Keep only**. Matching tags survive; unrelated override tags are removed. Text and comment blocks are preserved. A transform survives with the selected contents supported by the filter. This is an explicit destructive filter, so choose the retained categories before applying it.

### Resize / transform

The numeric tool detects common size, spacing, scale, border, shadow, blur, rotation and shear parameters. Its checkboxes **toggle categories relative to that detected set**; they are not a simple whitelist. This distinction matters when excluding `fs` while adding `pos` to an operation.

| Mode | Calculation |
| --- | --- |
| Add | `value + amount` |
| Percent | `value × (1 + amount / 100)` |
| Transform | Append a whole-event `\t(...)` toward adjusted animatable scalar values |

Missing size, spacing, scale, border and shadow values can come from the event's style. Perspective-sensitive adjustments capture and reproject the existing plane when possible.

Numeric parameters are changed independently of tag names and hexadecimal colors. Exponent notation is treated as one number. For example, adding 1 to `\t(0,100,\1c&H123456&\fs1e2)` produces `\t(1,101,\1c&H123456&\fs101)` when the transform itself is selected. A selected transform adjusts numeric parameters within its payload as well; colors and font names remain intact. Vector clip coordinates are mapped without changing the clip's drawing scale.

Nonfinite amounts and arithmetic overflow are rejected. Choosing discrete tags such as alignment still requires a meaningful resulting ASS value; the tool does not invent a replacement alignment for an intentional numeric edit.

### Pos Align

At least two events are required. The first is the source and the second the reference. Rhea calculates `source position − reference position` and applies that displacement to every selected target after the source.

Positions come from a real `pos`, the initial point of `move`, or style alignment/margins and script resolution. Implicit target positions become explicit when moved.

- **Keep org** moves `pos`/`move` and retains origin/clip geometry.
- **Move org** also moves origins and rectangular/vector clips, including clips in transforms.
- If both positions coincide, Move org can derive the displacement from differing explicit origins.

Drawing coordinates remain local to the moved position. They are not shifted a second time. Scaled clips convert screen displacement into the corresponding drawing units.

## Masks

Sources are **from clip** and the saved library. Built-ins: `square`, `rounded`, `circle`, `triangle`.

| Action/control | Result |
| --- | --- |
| Apply Mask | Apply the selected source using the current create/replace options |
| Create Layer | Create a mask one layer below the source |
| Replace Mask | Replace the first active drawing section of an existing drawing event |
| Alignment | Choose `an1`–`an9` for the generated mask |
| Color | Override RGB when enabled |
| Alpha | Override transparency with the selected ASS alpha when enabled |
| q2 | Toggle ASS wrapping mode 2; this is not a resampling filter |
| Save Shape | Save the first selected event's drawing geometry under the entered name |
| Delete Shape | Remove the saved definition of that name |

With **from clip**, Rhea converts the clip geometry to a local drawing. Rectangles, Bézier paths, separate contours and clip drawing scales are handled through the ASS geometry helpers. An inverse clip supplies the same outline; it does not generate the full complementary screen region.

Create Layer removes the source clip after constructing the mask. If the source is at layer zero, it moves to layer one so the new mask can remain below it at zero. A library mask preserves the source clip. Generated clip masks neutralize inherited rotation, shear and drawing scale so screen coordinates remain meaningful.

Library placement resolves the source event's position from tags or style/margins. It retains supported explicit origin/rotation tags. Replacement accepts active `p` drawing sections beyond `p1`, resets the replaced section to `p1` and 100% scale, and preserves following text sections.

Saved masks live in `dramaturgy_masks.txt` in Aegisub's user directory. Saving normalizes drawing coordinates to `p1`, validates the complete path and updates an existing name. It does not keep appending duplicate entries. LF and CRLF records are accepted. Names cannot contain colons or line breaks; `from clip` is reserved.

Built-in names can have a saved override. Deleting that override reveals the built-in again. The four built-ins are part of the script and are not removed from its source by Delete Shape. The library stores drawing geometry, not the source event's timing or full tag stack.

## Sign layout

These operations lay out text from its initial state. Inline font, size, scale, spacing and style resets inform measurement. Static measurements do not reproduce a continuously changing font or perspective over time; split/bake such animation first when each frame needs a separate layout.

### Typewriter

Writes alpha transforms that reveal successive graphemes. Existing alpha overrides are cleared for the reveal. Combining characters and joined emoji count as one item. ASS breaks do not consume an extra reveal slot; drawing data is not counted as text characters.

- **Frame** uses the loaded video frame mapping, including variable frame rate. Reveal positions are constrained to the event's last usable millisecond.
- **Duration** spreads reveals across the event duration. It is also the fallback when frame conversion is unavailable.

The first character begins at the event start. Non-comment events with positive duration are eligible. Timing, style name and non-alpha content are retained.

### Vertical Drop

Creates one event per grapheme on a vertical axis. The initial position resolves explicit tags/movement or the style. Each next glyph advances by its measured height plus **Vertical gap**. Negative gap is allowed. Scale is applied once through Aegisub's text measurement.

The source is replaced. Result selections follow the layout helper's existing convention, selecting the last generated glyph per source. Spaces can produce a glyph event; line-break tokens do not create their own event.

### Circle Text

Requires explicit `pos` and `org`. Their distance defines the radius, adjusted by the radius offset. A positive radius is required; subpixel radii are accepted.

Tracking adds space between characters. Rotation choices are normal, inverted and vertical. The invert option reverses the direction around the circle. Delete original controls whether the source is replaced or retained with generated events after it. Whitespace consumes layout width but does not create its own visible glyph event.

The baseline/angle model includes the existing font-size compensation, so it remains an artistic circle-layout tool rather than a font-shaping engine for connected scripts.

### Curve Text

Uses the event's vector clip, or the first usable clip in the selection as a shared path. Text is centered along the sampled path, with each visible glyph rotated to the path tangent. The source is replaced and generated glyphs use the next layer.

Straight segments need only their endpoints. Cubic curves retain 40 subdivisions for distance/tangent sampling. Position lookup is binary; angle interpolation follows the shorter angular arc. Unsupported or unusable paths are rejected instead of inventing geometry.

## Perspective

The tools resolve style properties, script resolution and the existing plane. Degenerate or nonfinite geometry is not a usable perspective plane. Positive scale and finite screen coordinates are required.

| Mode | Operation |
| --- | --- |
| Copy Exact (same plane) | Copy the source perspective state, position and origin |
| Copy Static Plane (keep `pos`) | Copy the plane state while keeping the destination position |
| Copy Move Plane (whole plane) | Translate the copied plane/origin to the destination position |
| Copy w/ corner swap | Remap source corners according to the selected permutation |
| Mass FSC (lock quad) | Set selected X/Y scales while reprojecting to retain the quad |
| Scale Quad (3D Box) | Scale the quad about its center |
| Bake Extradata | Put the stored ambient plane into a portable text marker |
| Restore Extradata | Restore that marker to event extradata |
| Identity reproject | Recalculate tags for the current plane |

Copy modes use the source/target grouping rules described above. Corner maps include exact, horizontal/vertical mirror, rotations and explicit corner swaps. Invalid resulting quads are skipped.

Origin modes are **keep destination origin**, **quad center** and **minimize fax**. The layout scale compares PlayResY with LayoutResY, or video height if LayoutResY is absent. Rhea asks about a relevant mismatch and remembers that warning for the session.

Plane metadata accepts signed decimal/exponent numbers and requires exactly four coordinate pairs. Baking uses the existing `_persp` marker format; serialization precision remains compatible with existing files.

## Shapes

### Unify Positions

Select at least two static drawings. The active selected event supplies the pivot; otherwise the helper chooses its reference from the selection. It rewrites positions and compensates local drawing coordinates to preserve placement.

The accepted profile requires an unambiguous static `pos` and drawing section. Movement, origin-dependent animation, unsupported transforms or inherited rotation are rejected when one static pivot cannot preserve the result. Existing 1/64-pixel compensation is a renderer precision convention, not a line-count cap.

### Place on Perimeter

The first selected drawing is the base contour. Remaining drawings form template units; layers sharing a position belong to a unit. Unit order follows their first position in the selection. The base is retained and template rows are replaced by the generated layout.

Choose exterior contours only, or exteriors and holes. Winding and containment determine contour roles. Each selected contour closes its period independently.

Choose one of the suggested repeating patterns or **Custom**. The custom editor accepts unit numbers separated by spaces/commas, for example `1, 2, 2, 3`. The sequence can have more than sixteen steps. Invalid unit numbers reopen the editor with its contents retained.

Repetition count and gaps are calculated from contour length and template widths. There is no 4,000-output ceiling. Generation checks cancellation; a nonpositive advance, invalid tangent or failed closure is rejected because it cannot define a valid arrangement.

### Shape Color Optimizer

Uses `kite.ShapeOptimizer` for compatible static drawings. Modes: Auto, Similar colors and Full gradient. Intensities: Balanced, Fidelity and Aggressive. The OKLab threshold uses the chosen intensity when zero; the bounded tolerance limits color error.

**Max. bands** is a requested gradient target, with minimum two. There is no 64-band ceiling, and the actual target cannot exceed the input item count. Valid higher drawing scales, including `p7`, are accepted while their coordinate factor remains finite.

The summary reports the proposed reduction. When enabled, confirmation occurs before applying it. If the shapes are incompatible or no acceptable reduction exists, the original events remain unchanged.

## Fast Signs

Groups overlapping non-comment events, lays their boxes side by side near the configured top offset and generates three layers per source:

1. Background drawing at the original layer.
2. Border/glow at the next layer.
3. Text at the following layer.

The original event becomes a comment. Source timing is preserved. Fade duration is limited to half the event duration so fade-in and fade-out do not overlap unexpectedly.

Configuration controls RGB colors, independent box/glow alpha, text color/alpha, fade duration, horizontal/vertical padding, top offset, gap, maximum box width as a percentage of the frame, and blur/border values. Generated boxes and text neutralize inherited rotation. Text alpha comes from its configured color picker.

The width setting caps the box; it does not automatically shrink a long caption to fit. Existing inline styling is removed from the source text for this standardized stack. Generated events are returned as the selection.

## Font and Style Manager

The manager scans file styles and real top-level `fn` overrides. Font-like text in comment blocks or transforms is not counted as an inline font replacement.

| Action | Behavior |
| --- | --- |
| Swap font | Replace the chosen font in styles; optionally replace matching inline overrides |
| Refresh | Refresh the font/style summary after changing the chosen font |
| Edit properties | Choose styles, mark fields to apply and edit those fields together |
| Edit colors | Choose the channels to apply to the selected styles |
| Clone style | Create a new style with original or edited colors |

Style selection accepts one style name per row and reports unknown names. Mixed values are marked; an unselected Apply checkbox leaves that property unchanged. Boolean fields have unchanged/on/off choices.

Properties include font, size, X/Y scale, spacing, angle, outline, shadow, margins, encoding, bold, italic, underline, strikeout, border style and alignment. Numeric values must be finite. ASS value ranges still apply, including positive font size, nonnegative margins and byte encoding.

An invalid or incomplete form reopens with its draft intact. Color and clone forms retain their edits too. Clone names must be nonempty, unique and free of commas/newlines. Inserting a style updates both the subtitle selection and active row. The manager stays open after an accepted operation; closing it retains completed operations.

## Toolbox

**Style to Tags** converts chosen style properties through `AssContext.styleBake`. The dialog supports property selection, protection of existing families, zero omission and reset expansion. Explicit alignment retains its first-tag priority; resets do not introduce a new line alignment. Active resets resolve their actual styles, while comments and nested resets remain intact. The legacy Taggerize entry calls this integrated tool.

**Fast Fades/In** sets the incoming duration to `current frame time − start`. **Out** sets the outgoing duration to `end − current frame time`. The frame must be inside every selected non-comment event. The other component is preserved. Invalid fade data aborts before applying the batch.

**Continuous Fade Cleanup** groups matching event intervals and cleans internal boundaries of continuous groups, retaining external fades. It requires more than one timing group. **Shuffle Line Text** shuffles only text among selected dialogue events; timing and other event fields remain attached to their rows.

## Configuration and compatibility

Your settings are saved between sessions. Previous settings are imported automatically.

Public menu paths, action names and existing helper aliases remain available. Shared dependencies handle ASS context, line transactions, drawing validation/mapping, colors, shape optimization and event operations. Rhea does not require the Hotkeys macro to run.
