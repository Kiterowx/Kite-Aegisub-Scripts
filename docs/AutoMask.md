# AutoMask 2.5.5

English | [Español](es/AutoMask.md) | [Index](../README.md#documentation)

AutoMask samples the current video frame, uses each selected dialogue line as a guide and sends one region per line to `kite-automask` 0.4.2. Use it to cover lettering or defects on a surface, or to obtain the surface outline as an ASS drawing or clip.

## Choose the operation

| Command | Use it when | Result |
| --- | --- | --- |
| AutoMask | You want to inspect or paint the masks before applying. | Opens the editor. |
| Find surface inside clip | A plain clip surrounds a surface and leaves a margin around it. | Opens the editor after detecting the surface within the guide. |
| Classic AutoGrask | A plain clip encloses bright paper with darker lettering. | Fits the classic surface without opening the editor. |
| Backend/Check | You need the package version and dependency status. | Displays runtime readiness and the source version, when available. |
| Backend/Configure | Python is elsewhere or you use another installation source. | Saves the interpreter and source. |
| Backend/Install or Update | The package is missing or outdated. | Runs the configured Python installer. |
| Backend/Install Models | You want SAM refinement or LaMa inpainting. | Downloads and verifies the supported weights. |

Open a video and select uncommented dialogue lines. Put the video cursor on the frame you want to reconstruct. The capture is scaled to the script resolution, so the editor and generated coordinates use PlayRes rather than the video's original dimensions. All selected regions use that same frame; this operation does not track a moving surface through time.

## Guides and geometry

A single rectangular or vector `\clip` defines a region in script coordinates. The main editor also accepts `\iclip`, using the area outside that contour. The dedicated Inside and Classic commands require a plain clip; Classic requires exactly one.

Position, movement, rotation, scale and color animation of the text do not move an absolute clip. They therefore do not prevent that clip from being used as a guide. An animated clip still needs to be baked at the intended frame first. Multiple clips are rejected because the backend cannot choose their rendering precedence safely. A clip entirely outside the image produces an error instead of triggering unrelated global detection.

Raw ASS drawings need explicit `\pos` and `\an7`. Drawing scale, `\pbo`, cubic curves and B-splines are read. Geometry-changing transforms, movement, rotation, shear and style resets on a raw drawing must be baked first. Unsupported tokens and incomplete curves are reported; they are not silently removed. Lines without a clip or drawing enter automatic area detection and can be completed manually with Box or Region +.

## Work in the editor

1. Select a region in **Regions**. `·` means pending, `✓` means reconstructed and `!` indicates a reported failure.
2. Choose **Clip usage**. **Whole clip** keeps the original guide; **Find surface inside** searches for a distinct surface with a margin around it. Changing this choice updates guided regions and is undoable.
3. Choose an engine. **Automatic** selects gradient reconstruction or inpainting from the fitted surface. **Full AutoMask** uses inpainting. **Improved AutoGrask** fits a color gradient. **Classic AutoGrask** uses the bright-paper fit.
4. Use **Region + / −** or **Box** to correct the area. Use **Ink + / −** for defects that should be removed. **Detect ink** replaces the ink mask from the current sensitivity. Manual ink edits invalidate the old preview and survive undo followed by rebuilding.
5. Add **Point + / −** or a box, then choose **Refine with SAM**. The shipped model has six prompt slots and a box consumes two. Excess prompts produce an actionable message rather than being discarded. Undo restores points and boxes as well as masks.
6. Compare **Original**, **Mask**, **Fill** and **Vector**. **Rebuild** refreshes the reconstruction. **Sensitivity** previews ink detection while dragging and rebuilds on release. **Simplify** is the contour simplification tolerance; lower values keep more detail.
7. Choose **Output**, then **Apply**. **Cancel** and closing the editor leave the subtitles untouched.

The side panel scrolls on smaller displays. Editing shortcuts are inactive during the initial background job; cancellation remains available. A native inference already running can finish before the backend process exits.

| Shortcut | Action |
| --- | --- |
| 1–7 | Select tool |
| Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z | Undo / redo |
| Space | Cycle preview |
| A / S / D / R | Find area / refine with SAM / detect ink / rebuild |
| Ctrl+Enter | Apply |
| Esc | Cancel |
| Mouse wheel / middle drag | Zoom / pan |

## Outputs and subtitle changes

| Output | Subtitle operation | Properties |
| --- | --- | --- |
| ASS fill | Replaces each selected line with its generated drawing lines. | Copies source timing, layer and event properties; selects all generated rows. |
| Shape | Inserts one contour immediately after each source. | Copies timing and uses the next layer; keeps the original. |
| `\clip` / `\iclip` | Replaces the clip on each selected line. | Preserves other tags, text and event properties. |

Shape and clip output only need a valid contour. They do not require surface fitting, palette quantization or LaMa, so a small usable contour is not rejected by the fill engine's minimum sample requirement.

The Lua adapter validates the whole response before editing and applies it in a transaction. Sparse groups, missing regions, duplicate orders and malformed drawings fail without partial edits. Temporary request, frame and response files are cleaned up on success, cancellation and exceptions. The operation creates one undo point when it changes subtitles.

## Quality, resources and models

There is no fixed rejection at 48 lines per region, 512 lines per job or 128 regions. Gradient bands follow the fitted color range with a 2.5-unit target step. Inpainting palette quantization retains its 48-color quality setting; that is an algorithm setting, not a response-size cap.

Resource checks remain explicit: request JSON up to 8 MiB, region text up to 262,144 characters, frame files up to 512 MiB and 67,108,864 pixels, and bounded geometry parsing. The Lua response reader allows up to 100,000,000 bytes. History stores packed masks with a 64 MiB mask budget per region instead of a fixed 24-step cutoff. Older history can be released when that memory budget is reached. Large jobs still cost more memory and rendering time.

Automatic area detection and gradient fitting work without model downloads. SAM refinement uses EfficientSAM; inpainting tries LaMa and falls back to OpenCV if LaMa is unavailable, recording the reason in diagnostics. Model files are checked against their expected SHA-256. Installation replaces a target only after the download is complete and verified.

Your settings are saved between sessions. The backend includes PNG2ASS for vector conversion.

## Example

For a paper notice, draw `\clip(100,80,420,240)` on a line timed to the visible shot. Open AutoMask, select Whole clip and Automatic, inspect the detected ink, paint any missed letters with Ink +, then rebuild. Choose ASS fill to cover the lettering. Choose Shape or `\clip` when you only need the contour. Review the result throughout the line's timing because this capture represents a single frame.
