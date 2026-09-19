# Gradient Row 1.8.9

English | [Español](es/GradientRow.md) | [Index](../README.md#documentation)

Open **Gradient Row** with one or more uncommented dialogue events selected. It creates gradients either by splitting the visible area into clipped duplicate lines or by inserting colors between visible graphemes.

## Choose a mode

| Mode | Result |
| --- | --- |
| Horizontal | Spatial strips advance across the horizontal extent. |
| Vertical | Spatial strips advance across the vertical extent. |
| Rotated | Spatial strips follow the configured angle and the line's orientation. |
| Char Line | A complete character gradient restarts on each selected line. |
| Char Selection | One character gradient spans the selected lines in their input order. |

Spatial modes comment each source and insert colored clipped copies, selecting the generated rows. Character modes edit the selected lines in place and keep their selection. Character modes skip vector drawing lines. Spaces count as gradient positions; ASS `\N`, `\n` and `\h` remain intact but do not consume a color position. Graphemes keep combining marks, joined emoji and flag pairs together.

## Palette and controls

The dialog groups the controls in a centered column: gradient type, strip thickness, acceleration, angle, color slots and vertically stacked colors. The column remains centered when navigation buttons appear. The palette shows up to eight colors per page. **Previous** and **Next** appear only when there is more than one page and navigate without losing edits on other pages. The Colors label then shows the visible range and total; hovering a swatch identifies its position. **Add+** duplicates the final color and opens its page; **Rem-** removes the final color, retaining at least two. **Reset** restores defaults in the draft; **Cancel** discards it. **Execute** saves preferences and processes the selection. Failed preference writes are logged separately.

**Pixels per strip** sets integer spatial thickness, minimum one pixel. Larger values create fewer rows and a more visibly stepped gradient. **Acceleration** is a positive interpolation exponent; 1 is linear, larger values hold the earlier colors longer. Nonpositive stored input falls back to 1. Small positive values below 0.01 are accepted. **Angle** applies to Rotated mode. Choose one or more ASS color channels: primary, secondary, outline and shadow. These controls change colors, not their alpha.

For a three-position black-to-white gradient with acceleration 1, the center is approximately RGB 128/128/128. Raising acceleration changes the center while retaining the endpoints. The ratio is calculated before exponentiation so large exponents do not overflow into an undefined result.

## Inline color stops

**Inline color stops** applies to Char Line and Char Selection. It derives anchors from static explicit color tags before and between letters. Channels with at least two distinct anchor positions are interpolated; channels without enough anchors stay unchanged. If several color tags occupy one anchor, the last one in source order wins. This mode uses the qualifying inline channels, independently of the palette channel checkboxes.

For example, `{\c&H000000&}AB{\c&HFFFFFF&}CD` supplies primary-color anchors at A and C. Char Line restarts that interpretation per line; Char Selection uses offsets across the selection. Existing transforms remain transforms; their colors are not used as static stops. Colors written inside ASS comments are ignored. Style resets are preserved, but this mode's anchors come from explicit color tags rather than inferred style colors. Add explicit stops where a reset should define a gradient boundary.

## Geometry and perspective

Spatial modes accept no source clip, one rectangular clip, or one four-corner vector clip before visible content. Multiple clips, inline clip changes, inverse clips and animated clips are rejected because replacing them with ordinary strips would change their semantics. Curved or multi-contour clips must first be converted to supported geometry; this is a supported-input condition, not an output-count budget.

Without an explicit clip, the script uses ASSFoundation, optional SubInspector and font measurement to obtain bounds, with a rough measurement fallback. Positions can come from the style, alignment and margins through AssContext. Rotation and perspective use projected geometry where available. Quad subdivision uses arch.Perspective when possible and a geometric fallback otherwise. Small padding and neighboring-strip overlap reduce visible seams.

A moving or transformed sign can change its geometry over time. Perspective preparation reports those cases because the spatial strips use prepared geometry; inspect the whole event or bake the changing geometry first using [Cliptomaniac](Cliptomaniac.md). A rough font bound is an estimate, not an exact outline. Font availability and renderer settings still affect appearance.

Leading comments stay comments when new clip and color tags are inserted. Static color replacement uses the shared tag parser and preserves nested color transforms. Other source metadata and timing are copied into generated rows.

## Output size, cancellation and settings

There is no fixed limit on the number of generated strips or lines. Generation checks cancellation while building strips and inserting events. A transaction restores the subtitle file if a failure or cancellation interrupts the operation. Large output still requires proportional memory and Aegisub processing time; increase strip thickness when the visual result permits it.

Install ASSFoundation, Aegisub-Motion and `arch.Perspective`. SubInspector is optional and provides rendered text measurements.
