# PNG2ASS 1.6.4

English | [Español](es/PNG2ASS.md) | [Index](../README.md#documentation)

PNG2ASS converts raster images and SVG files into ASS drawings through `kite-png2ass` 1.4.2. A still image inherits the active selected line's timing. Multiple images form a sequence mapped to the selected lines' video frames. Originals remain in the subtitle file.

## Convert a still image

1. Select an uncommented dialogue line. Its style, timing and other event properties become the base for the inserted drawings.
2. Run PNG2ASS and choose an image or SVG. Supported raster extensions are PNG, JPEG, WebP, BMP, TIFF, GIF and TGA. Animated or multipage images must first be exported as separate still files.
3. Choose the mode, color policy and position. Execute starts conversion in a hidden supervised Python process.
4. Review the engine, generated line count, character count, elapsed time and warnings. Insert adds the drawings after the source, one layer above it. Cancel leaves subtitles untouched.

The active line is used when it belongs to the selection; otherwise the first selected dialogue is used. The inserted rows become the selection. A successful insertion creates one undo operation. Cancellation during insertion restores the subtitle state.

## Choose a mode

| Mode | Input interpretation | Engine |
| --- | --- | --- |
| auto | Transparency becomes an alpha mask; mostly black/white images become mattes; other opaque images become color. | Chosen from the detected mode. |
| alpha | Pixels whose alpha exceeds the threshold. | OpenCV |
| white-matte | Bright foreground over black, compositing transparent pixels over black. | OpenCV |
| dark-matte / luma | Dark foreground over white, compositing transparency over white. | OpenCV |
| color | Visible image content as colored layers. | VTracer + svg2ssa |

Choose **source** color with **auto** to request color conversion instead of reducing the input to a mask. Explicit mask modes use the subtitle style's color. Color mode retains source colors. SVG goes directly through svg2ssa; **style** removes source color tags while retaining the SVG's opacity.

OpenCV preserves holes by retaining the contour orientation returned by the contour finder. VTracer output is sanitized only for empty path elements; valid path data is retained.

## Options

| Option | Meaning |
| --- | --- |
| Threshold | Percentage used to form a binary mask, from 0 to 100. It does not quantize a color image. |
| Scale | ASS drawing precision through `\p1`–`\p6`, not a change to the image's displayed size. |
| Simplify | OpenCV contour tolerance; smaller values preserve more vertices. |
| Min area | Discards contours below the chosen area. Set zero when inspecting small details. Degenerate contours still cannot form filled polygons. |
| VTracer balanced / quality | Color tracing presets. Quality keeps smaller details and can produce more layers. |
| Position | Origin at 0,0; the active line's explicit top-level `\pos`; or manual coordinates. |
| X / Y | Manual coordinates, including fractions. The backend retains six decimal places instead of rounding to whole pixels. |
| Blur | Blur applied to generated drawings. |
| Denoise | Median filter radius for image color before tracing. |
| Warn chars / Warn lines | Warning thresholds for output size; crossing them does not cancel a valid conversion. |
| Max pixels | Image decoding budget checked against the image header. |
| Python | Interpreter for this conversion and subsequent saved runs. |

The window's ranges match the backend: Simplify up to 1000, Min area up to one billion, coordinates within ±10 million, Blur up to 100 and Denoise up to 50. Large values can deliberately remove detail or require substantial processing. Settings are saved after a successful insertion. A settings-write failure is reported without discarding inserted drawings.

**Active pos** reads an explicit static position. It does not infer an anchor from the style or sample `\move`; use Manual when you need a different anchor. Position refers to the original image canvas. Cropping transparent margins retains the corresponding offset.

## Image sequences

Select all source dialogue lines, then select multiple image files. PNG2ASS removes duplicate paths and sorts naturally: frame2 precedes frame10. Every selected file must exist and have a supported extension. Paths containing line breaks cannot be represented by the sequence list and are rejected.

For each selected line, frame jobs use `frame_from_ms(start_time)` up to, but excluding, `frame_from_ms(end_time)`. Each job intersects that frame's interval with the source timing. This preserves the suite's existing exclusive-end mapping; it does not force an extra final frame into the range. The image count must equal the displayed frame count. Overlapping selected lines contribute their own jobs.

Each image corresponds to one job. A fully empty mask is written as `LINES 0`, preserving that job's position in the sequence. It creates a gap rather than shifting following images or aborting the whole sequence. A single empty still image reports that it has no usable drawing. A sequence containing only empty masks leaves the subtitles and selection unchanged.

Example: with three jobs and a visible/transparent/visible sequence, drawings are inserted for jobs one and three using their own timestamps; job two produces no drawing. Cancelling the final insertion review applies none of them.

There is no fixed 10,000-image or 10,000-frame cutoff. Sequence lists retain a 16 MiB input budget and a maximum path-line length. Output retains emergency budgets of 500,000 ASS lines or 100,000,000 characters, checked as the sequence accumulates. Individual drawing validation also protects the subtitle parser from oversized or malformed payloads.

## Backend and cancellation

| Command | Purpose |
| --- | --- |
| Backend/Check | Inspect the package, dependencies and available source version. |
| Backend/Configure | Save Python and the installation source. Closing the window acts as Cancel. |
| Backend/Install or Update | Inspect and run the installation command, then review its result. |

The Windows supervisor starts the exact Python child without a console window and captures stdout/stderr. Paths containing accented characters and apostrophes are supported. Cancel signals the supervisor, which can terminate a native tracing call. Conversion output, progress, result and supervisor files are temporary and cleaned up after the operation; installation logs are also removed after being read.

The Lua adapter validates all frame indices, counts and drawing payloads before editing. Both still and sequence conversion share the same completion, review, insertion and cleanup flow. Backend output files are replaced atomically; a failed write retains an existing destination and removes its temporary file.
