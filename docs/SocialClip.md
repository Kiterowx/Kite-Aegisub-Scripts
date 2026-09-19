# Social Clip 1.0.3

English | [Español](es/SocialClip.md) | [Index](../README.md#documentation)

Social Clip builds a continuous video from intervals defined by ASS masks. Each mask identifies the source region to include. Scenes are sorted, two-scene overlaps are divided, and gaps are removed. Crop movement follows the frame timestamps of the video loaded in Aegisub.

Open **Social Clip** or use **: Kite Hotkeys :/Social Clip/Execute**. The Hotkeys editor macro is optional. The interface uses Spanish labels, retained below.

## Preparation

1. Load a real video file and check the subtitle's PlayRes.
2. Select the lines whose times will define the scenes.
3. Run **Crear máscaras**. Choose the output format and each mask's initial and final center X.
4. Review the masks over the video and adjust their timing and movement.
5. Run **Exportar vídeo** or **Solo ASS**.

FFmpeg needs the `subtitles`, `sendcmd`, `crop`, `scale` and `concat` filters, libass and libx264. FFprobe identifies the audio stream, with FFmpeg as a fallback. Complex mask measurement uses ASSFoundation and SubInspector in Aegisub.

## Main window

| Control | Function |
| --- | --- |
| Formato | 1080×1920, 720×1280, 1080×1350 or custom resolution. |
| Personalizado | Positive width and height, rounded to the nearest even integer for YUV 4:2:0 encoding. |
| Pista | Audio stream number, starting at 1. |
| Salida | One of the three profiles below. |
| FPS | `Origen`, 30 or 60. Origen preserves variable timing; the others produce a constant frame rate. |
| CRF | libx264 quality from 0 to 51. Lower values produce higher quality and usually larger files; 0 requests lossless encoding. |
| Relación | Expand the box to match the output ratio, or require matching mask and output ratios. |
| Margen lateral | Percentage of each side reserved for adapted dialogue, from 0 to less than 50. |
| Margen inferior | Percentage of height reserved below adapted dialogue, from 0 to less than 100. |
| Fuente máxima | Maximum adapted font size as a positive percentage of output height. |
| Guardar ASS adaptado | Save an additional adapted-dialogue ASS beside the video. |
| Centro X inicial/final | Center coordinates for new masks, in PlayRes. Geometry must fit the video. |
| Alpha | New mask fill transparency: 0 is opaque and 255 transparent. It does not change the crop box. |

Nonfinite values and percentages that leave no usable area are reported before execution.

## Creating masks

Creates one mask per selected uncommented dialogue with positive duration. Selection indices are normalized and sorted. Masks are appended and selected.

The box uses the largest crop of the chosen ratio that fits the video. Its initial vertical position uses the available frame; center X values come from the form. Equal values produce `\pos`; different values produce a full-duration `\move`. Drawings use PlayRes and account for the video dimensions.

New masks use Actor `SocialClip`, Effect `Kite Social Mask`, `\an5`, explicit scale and neutral rotation. Their layer is above the highest existing layer. Color and border make them visible in the editor; mask lines are excluded from the export.

## Finding and measuring masks

Export and subtitle centering find lines with Effect `Kite Social Mask`, falling back to legacy `Kite Social Y Preview` lines if none exist. Helpers given an explicit selection prefer its valid drawings.

A mask contains active `\p` drawing sections and no visible text. Comments and tags nested in `\t` do not activate drawing mode; `\r` ends it. Uppercase `\P` and `\R` do not replace the lowercase ASS tags. Mixed text and drawing lines are rejected when they cannot form a valid mask.

Simple polygon masks are measured with AssDrawing and AssContext. This supports exponent-form numbers, drawing and style scale, alignment, margins and implicit style positions. Special `\move` times, including `(0,0)`, use the shared motion evaluator.

Curves, clips, transforms and other geometry that needs rendering use ASSFoundation/SubInspector. Measurement uses an opaque copy without border or blur while retaining geometry and comments. The source remains unchanged even if measurement fails.

Each scene uses a constant-size rectangular crop. Export follows its position and can correct Y when it crosses the top or bottom. A box that cannot fit is rejected. Changes in scale or rotation that change its dimensions are reported, as is horizontal movement outside the video.

## Intervals and movement

Scenes are sorted by start and end. A two-scene overlap is divided at the frame boundary nearest its temporal midpoint. Fully nested masks and triple overlaps require manual timing adjustment.

Gaps are removed from video, audio and adapted dialogue. Scenes at 0–400 ms and 600–1000 ms therefore produce a continuous 800 ms output. Paths use each frame's actual timestamp; repeated positions are compressed. There is no fixed scene or frame limit.

## Corregir Y

Edits only selected masks with a recognized Effect. It preserves X, confines Y to the available area and normalizes the origin to `\an5`. Paths are split when the vertical correction stops being linear, with a tolerance of 0.25 PlayRes units. Fades are rebased to each fragment's clock.

Direct editing requires polygon geometry that can be reconstructed through position and alignment. Export can still measure and correct complex masks, but the editing action reports curves, clips, transforms and rotation instead of replacing their geometry tags. Legacy Y previews are removed and selection indices are updated.

## Centrar subs X

Centers selected subtitles on their mask's X while preserving their vertical alignment row and position. Implicit positions use style and margins. Comments and unrelated tags remain intact.

Each subtitle must belong to one scene and its X path must fit one `\pos` or `\move`. Lines crossing masks or gaps are reported. Compatible Y animation is retained. Lines with `\org` or clips are reported before editing because they require additional geometry handling.

Centered lines retain existing extra data and receive `_kite_socialclip_centered`, which identifies them as adaptable dialogue later.

## Export profiles

| Profile | Result |
| --- | --- |
| MP4 · pegados y adaptados | Burns signs and effects into the source before cropping, then burns repositioned dialogue into the joined output. |
| MP4 · pegados exactos | Burns the exportable ASS composition into the source with its layers, styles and original clock, then crops and joins scenes. |
| MKV · diálogo ASS flotante | Burns signs and effects before cropping and includes adapted dialogue as a switchable ASS track with available font attachments. |

The exact profile preserves ASS composition inside the crops; video is re-encoded. Appearance depends on fonts and libass.

Ordinary dialogue is text without drawings, transforms, karaoke, clips, rotation or complex positioning, usually bottom-centered. Lines marked by Centrar subs X may have their own position and scale. Other signs and effects remain in the visual composition. **Solo ASS** omits them and reports the count.

Adaptation scales font size, spacing, border, shadow and blur while retaining colors, alpha and comments. Exponent-form numbers are read completely; relative `\fs+…` changes stay relative. Font measurements can reduce oversized dialogue as needed. Without measurements, fitting estimates grapheme widths rather than UTF-8 byte counts.

Lines crossing scenes are split and remapped into the continuous timeline. `\fad` and `\fade` keep their original progress, including when a fragment starts during a fade. Fragments shorter than 10 ms are omitted because ASS timestamps use centiseconds.

## Audio and fonts

A real audio file loaded in Aegisub takes priority; otherwise the video supplies audio. The selected stream is cut to the same scene intervals and encoded as stereo AAC at 48 kHz, using the bitrate from Configuración. A video without audio can use the default stream setting and reports the absence of audio. A requested higher stream that does not exist is reported before export.

Temporary subtitle containers include source-video attachments. The MKV profile keeps the adapted Spanish subtitle track and available fonts. External fonts must be installed or otherwise accessible to the renderer.

## Files, cancellation and settings

**Solo ASS** saves adapted dialogue without encoding video. **Guardar ASS adaptado** also saves it during video export, so it may remain if later encoding fails. Output cannot overwrite the corresponding active subtitle or source video. Other existing destinations require confirmation.

Video is encoded to a temporary file and replaces the destination only after success. ASS writes are atomic. Temporary filters, paths, subtitle containers and videos are cleaned up after completion or failure. PyBridge supervises cancellation, hides the Windows console and captures diagnostics.

**Configuración** saves the FFmpeg and FFprobe paths, libx264 preset and AAC bitrate. Cancel returns to the main window without saving changes.

Subtitle edits are transactional: failures or cancellation restore the document, and insertions or deletions update the selection.
