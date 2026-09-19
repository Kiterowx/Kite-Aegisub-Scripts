# Cliptomaniac 0.4.4

English | [Español](es/Cliptomaniac.md) | [Index](../README.md#documentation)

Cliptomaniac edits ASS clip geometry, uses drawn guides to position or reshape text, and converts animated clipped lines to frame-by-frame output. Open **Cliptomaniac** to select an action. **Cliptomaniac/Help** opens the action reference. The 39 individual actions remain under **: Kite Hotkeys :/Cliptomaniac/**; slashes within action names use the full-width slash to keep a single menu leaf.

## Choose the source geometry first

| Intended result | Useful input and action |
| --- | --- |
| Fit a crop to text | Autofit clip to text adjusts an existing clip; Create clip around text can start without one. |
| Use the glyph outline | Text to clip uses font contours; Shape to clip uses ASS drawing geometry. |
| Reposition several lines together | Draw a straight two-point guide from origin to destination, then Clip to reposition. |
| Change rotation or shear | A straight guide gives direction to FRZ, FAX or FAY. A zero-length or singular guide cannot establish the requested geometry. |
| Fit a planar sign | Clip to perspective requires four corners; Complete quadrilateral starts from three. |
| Follow a changing clip | Animated clip to FBF samples the event at video frames; use Export clip track to AE for tracking data. |
| Inspect an unexpected result | Clip diagnostics reports geometry; Measure clip reports guide lengths and angles. |

The first usable clip/guide is significant in most actions. Rectangles, vector paths and inverse clips are distinct inputs. A line containing only a clip can obtain its implicit position from the referenced style, alignment, margins and script resolution; it does not require an explicit pos tag. Event margins override style margins. Clips are in script coordinates; vector drawing scale must be accounted for before treating stored numbers as pixels. Named style resets and temporal operations use the shared ASS context and specialized ASSFoundation/perspective tools.

Select the intended dialogue events, open an action and read its contextual panel. Direct actions execute immediately; configurable actions show only their relevant controls. Canceling the options returns to the picker when opened through the main macro. The language button switches English/Spanish. Preferences persist by action in the shared settings store, migrating the old `kite-cliptomaniac.json`; the Hotkeys editor macro is optional. Failed preference writes are logged and returned as failures.

## Frame generation and strips

FBF uses the loaded video's frame mapping and an interval that includes the start frame and excludes the end frame. Clip only retains source text when only clip animation is involved; other temporal tags that need baking use the complete baked line to preserve time-dependent behavior. Karaoke timing is rebased to each generated frame. Merge identical combines adjacent events only when their generated body and relevant event fields match. Max frames is an optional output-event budget after merging: the default is 400, any nonnegative integer can be entered, and 0 disables it.

Strip generation has no fixed output-row limit. With Create lines enabled, it inserts a duplicate per strip and retains the source; enable Comment source to turn that original off. Without Create lines, it applies the first generated strip to the source. Horizontal mode advances along X and Vertical mode along Y; this describes the subdivision direction. Neighboring rectangular strips overlap by half a pixel to hide seams. Larger subdivisions take more time and memory; generation and insertion check cancellation and the outer operation restores the subtitle snapshot on cancellation or failure.

## Action reference

### Add clip points

Opens options. Adds points between existing clip points while preserving the current shape.

- Add by: choose fixed pixel spacing or a fixed number of inserted points per original segment.
- Distance: when adding by distance, insert points at this pixel interval and leave any final remainder before the next original point.
- Points: when adding by count, insert this many evenly spaced points between each pair of original points.

### Adjust by clip scale

Opens options. Uses two guide strokes as rulers and resizes the selected text values.

- Axis: choose width, height, or both.
- fscx: resize the text width.
- fscy: resize the text height.
- fs: resize the font size.
- fsp: resize letter spacing.
- bord: resize the outline.
- shad: resize the shadow.
- blur: resize blur and edge blur.
- Show report: show the percentage that was applied.

### Align to clip

Runs immediately. Moves the line position onto the nearest point of the clip path.

### Animated clip to FBF

Opens options. Bakes a moving or transformed clipped line into frame-by-frame clipped lines.

- Bake source: choose whether to keep the whole baked line or only copy its clip.
- Max frames: optional output-line budget; 0 disables it.
- Merge identical: join neighboring frames when their final clip is the same.
- Comment source: keep the original line but turn it off.

### Autofit clip to text

Opens options. Makes the clip fit around the visible text, with padding, section choices, and optional full-duration transform bounds.

- Mode: choose which part of the text the new clip should cover.
- Section axis: split the text from left to right or from top to bottom.
- Margin: add or remove extra pixels around the fitted clip.
- Tolerance: higher values make the result simpler; lower values keep more detail.
- Sections: how many equal parts to split the text into.
- Index: which part to use when Mode is Custom section.
- Bleed: overlap between neighboring sections so tiny gaps do not appear.
- No shrink: never make the new clip smaller than the old one.
- Style pad: include outline, shadow, and blur in the fitted area.
- Transform maxima: union rendered bounds from every frame, honor \an, and ignore clip/iclip only while measuring.
- Transform maxima requires a loaded video; rendered bounds already include visible style and are not padded twice.
- The temporal result consolidates every clip/iclip into one static clip and preserves its kind.

### Bezier clip to curved text

Opens options. Converts one cubic Bezier clip directly into clean per-character rotation and spacing tags.

- Curve depth: 100% builds a compensated circular arc from the clip; 0% straightens it and larger values deepen it.
- Extra fsp: add uniform spacing to the line's effective letter spacing.
- Remove guide clip: delete the clip after converting the curve.

### Calibrate clip X

Runs immediately. Makes the first guide stroke perfectly horizontal.

### Calibrate clip Y

Runs immediately. Makes the first guide stroke perfectly vertical.

### Circle from 2 points

Runs immediately. Makes a circle using the first guide stroke as its diameter.

### Clip boolean with text/shape

Opens options. Combines the current clip with the selected text or drawing outline.

- Boolean mode: keep only the overlap, or cut the text shape out of the clip.
- Tolerance: higher values make the result simpler.
- Close paths: connect open outlines before combining.

### Clip diagnostics

Runs immediately. Shows clip type, size, points, and perspective-plane status.

### Clip to FAX

Opens options. Turns the first guide stroke into the line slant.

- Remove guide clip: delete the clip after it has been used as a guide.

### Clip to FAY

Opens options. Turns the first vertical guide stroke into the line Y slant.

- Remove guide clip: delete the clip after it has been used as a guide.

### Clip to FRZ

Opens options. Turns the first guide stroke into the line rotation.

- Remove guide clip: delete the clip after it has been used as a guide.

### Clip to move

Opens options. Changes a fixed position into movement using the first guide stroke.

- Remove guide clip: delete the clip after it has been used as a guide.

### Clip to perspective

Opens options. Uses a four-corner clip as the perspective plane for the line.

- Corner order: choose how the four clip corners are read.
- Origin: choose how the line anchor is chosen after the perspective is applied.
- Remove guide clip: delete the clip after it has been used as a guide.

### Clip to reposition

Opens options. Uses the first selected two-point clip as a shared source-to-target vector and translates every selected line without changing their relative layout.

- The first selected straight two-point clip defines the displacement for the whole selection.
- Remove guide clip: delete only that reference clip; other clips move with their lines.

### Clip to shape

Runs immediately. Turns the first clip into an editable drawing.

### Complete quadrilateral

Runs immediately. Adds D to a three-point A-B-C clip by closing opposite directions in the line's perspective plane.

### Copy clip/iclip

Runs immediately. Copies the first clip to matching selected lines, or from the first line to the rest.

### Create clip around text

Opens options. Creates a new clip around the visible text, including tilted, perspective, or transformed text.

- Margin: add or remove extra pixels around the text.
- Tolerance: higher values make regular text clips simpler.
- Style pad: include outline, shadow, and blur in the clipped area.
- Replace existing clip: overwrite the first clip; with transform maxima, consolidate all clips into one static clip.
- Transform maxima: union rendered bounds from every frame, honor \an, and ignore clip/iclip only while measuring.
- Transform maxima requires a loaded video; rendered bounds include visible style and preserve clip or iclip when replacing.

### Create strip clips

Opens options. Splits a clip or text area, optionally including full-duration transform bounds, into thin clipped copies.

- Strip mode: choose whether strips go across or down. Tilt and perspective are detected from the line.
- Strip size: approximate pixel size of each strip.
- Create new lines: make one duplicate line per strip.
- Comment source: when creating duplicates, keep the original line but turn it off.
- Transform maxima: when there is no guide clip, union rendered bounds from every frame; a loaded video is required.

### Expand clip margin

Opens options. Grows or shrinks the selected clip by a pixel margin.

- Margin: positive values grow the clip; negative values shrink it.
- Tolerance: higher values make edited paths simpler.

### Export clip track to AE

Runs immediately. Concatenates the selected clip durations as After Effects Position, Scale, and Rotation keyframe data in the console.

### Extract clip as mask line

Runs immediately. Creates a new drawing line from the first clip.

### Fit text to clip guide

Opens options. Uses the first clip or inverse-clip guide to wrap text on X or balance rows on Y without changing alignment.

- X axis: use the guide's horizontal distance as the maximum line width.
- Y axis: use the guide's vertical distance to choose and balance the row count.
- Keep the effective alignment and preserve clip or iclip without converting or removing it.

### Measure & transform clip

Opens options. Uses two guide strokes as a before and after ruler, then adds a size animation.

- Axis: choose whether the ruler changes width or height.
- Angle mode: choose if the guide also sets rotation.
- Show report: show the measured sizes after applying.

### Measure clip

Runs immediately. Shows the length and angle of the first two guide strokes inside a clip.

### New clip shape

Runs immediately. Starts a new clip shape from the last point of the current clip path.

### Perspective to clip

Runs immediately. Recreates a four-point clip from the stored perspective plane or current projected geometry.

### Position at clip midpoint

Runs immediately. Moves selected lines to the middle of their clip path, or to the first selected clip.

### Rect clip to vector

Runs immediately. Turns a simple rectangle clip into an editable path.

### Rectangle from diagonal

Runs immediately. Makes a rectangle from the first diagonal guide stroke.

### Remove clip points

Runs immediately. Removes alternating clip points while keeping each shape valid.

### Rescale by rectangle clip

Opens options. Resizes text tags to fit a rectangular clip. Vector clips are intentionally rejected.

- Mode: Fit keeps the whole text inside; Fill covers the rectangle; Stretch uses separate width and height factors.
- Center: move \pos to the rectangle anchor for the line alignment.
- Remove guide clip: delete the rectangle clip after it has been used.
- width/height: scale \fscx and \fscy.
- spacing/outline/shadow/blur: scale those dimensions like Rhea's Rescale to Clip.
- Vector clips are rejected. Use Rect clip to vector only after this operation, not before it.

### Shape to clip

Runs immediately. Uses the selected drawing as a clipping area.

### Text to clip

Opens options. Uses the actual text or drawing outline as the clip shape.

- Clip type: choose normal clip, inverse clip, or keep the current kind.
- Margin: add or remove extra pixels around the text outline.
- Tolerance: higher values make the outline simpler.
- Close paths: connect outline gaps when building the clip.
- Replace existing clip: overwrite the first clip already on the line.
- Comment source: keep the original line off and create a clipped copy.

### Toggle clip/iclip

Runs immediately. Switches between showing inside the clip and hiding inside the clip.

### Vector clip to rect

Runs immediately. Turns an editable path clip into the smallest rectangle around it.

## Examples and interpretation

- A clip guide from (100,200) to (140,220) describes a displacement of (+40,+20) for Clip to reposition. Its absolute endpoints do not automatically become every selected line's final position.
- Two guide strokes with lengths 100 and 150 give a 1.5 size ratio. Adjust by clip scale applies the selected dimensions; Measure & transform clip creates the size animation instead.
- For a 120 ms event at 25 fps, unmerged FBF covers three exclusive frame intervals. A configured budget of 2 rejects that output without editing the original; a budget of 0 allows it.
- Text fitting requires usable font measurement. Rough fallback extents are estimates; inspect wrapping and perspective on the target font. Transform maxima measures every frame with clips temporarily ignored and can be expensive on long events.
- Shear values above magnitude 100 are accepted when the guide defines a finite, nonsingular angle. Near-singular trigonometric denominators remain rejected. Degenerate quadrilaterals and unusable dimensions also remain invalid geometry.

## Requirements

Install ZF, ASSFoundation, arch.Perspective, arch.Util, Functional and Aegisub-Motion. Follow the [installation steps](../README.md#installation) for the included modules.

Font outlines and perspective appearance depend on the installed font, renderer and input sign.
