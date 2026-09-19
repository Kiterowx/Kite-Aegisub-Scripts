# Snapshoter 1.6.8

English | [Español](es/Snapshoter.md) | [Index](../README.md#documentation)

Snapshoter exports PNG captures from the loaded video, using selected subtitle events, explicit frame numbers, clips or drawing geometry. It can also export an entire frame interval with or without the current subtitle file. It never changes subtitle events.

Menu and assignable action: **Snapshoter**.

## Basic workflow

1. Load a real video file in Aegisub. FFmpeg must be able to decode the same file.
2. Select timed Dialogue events for line-based modes. Comment events and zero/negative-duration lines are excluded. Frame list can work without a subtitle selection.
3. Choose Capture and, where applicable, Timing and Clip output.
4. Use **Config...** to select FFmpeg or leave `ffmpeg` to resolve it through PATH. Returning from that window preserves the main draft, including the frame list.
5. Press **Execute**. The result reports the output location, errors or skipped lines.

On Windows, FFmpeg runs through the shared hidden-process supervisor in PyBridge. Cancellation is monitored while the process runs. The macro checks both the process result and the generated PNGs.

## Capture modes

| Capture | Source and result |
| --- | --- |
| Selected lines | Captures the source video at the chosen points of each selected timed Dialogue event. These individual captures do not burn subtitles. |
| Frame list | Captures explicitly listed video frames in ascending order; duplicates are removed. Timing and subtitle selection do not restrict the explicit list. |
| Frame sequence | Exports every frame from the earliest selected event's first active frame through the latest selected event's last active frame. Gaps between events remain in the sequence. Uses the three sequence-output checkboxes. |
| Clip crop | Uses the selected events' clips or drawing sections, according to Clip output. |
| Manual rectangle | Applies the X/Y/W/H rectangle and padding to captures at the selected events' timing points. Coordinates are video pixels. |
| Densest subtitle frame | Finds the earliest frame with the greatest number of overlapping selected timed Dialogue events and captures it once. Counts are based on event intervals, including events whose text may be transparent. |

## Timing

| Timing | Captures |
| --- | --- |
| Midpoint | The frame containing the midpoint of each event. |
| Start and end | The start frame and final active frame. The event's exclusive end is not captured as a new frame. |
| Start, middle, end | Start, midpoint and final active frame. Short events can produce more than one named capture of the same frame. |
| Current video frame | Captures only selected events containing the playhead frame. Reports when none contains it. |

Frame list, Frame sequence and Densest subtitle frame determine their own frames. Input seeking uses the loaded video's frame timestamps with a small allowance for Aegisub's millisecond rounding. It does not decode the entire video from frame zero for each capture. FFmpeg must use the same video stream and timecodes as Aegisub; custom external timecodes that disagree with the media timestamps can change correspondence.

## Frame list syntax

Examples: `120`, `120f`, `F120`, `120f, 130f`, or one entry per line. Spaces, commas and semicolons separate entries. Existing annotation lines such as `120f > P1 fade 6f` are accepted: the suffix after `>` is ignored, as are recognized `fade` annotations. A leading `--` is removed for compatibility with such lists.

Ranges such as `120-130` are not expanded. Negative, malformed, overflowing and out-of-range frame tokens are reported before processing. Frame indices are zero-based and constrained by Aegisub's signed integer frame API, not by a capture-count ceiling.

The initial list first uses frame markers from selected events' Effect fields when those markers fall inside the selected time intervals. Otherwise it uses the current frame if it belongs to an interval, then the beginning of each merged interval. Without timed selected events it uses the current video frame.

## Clips and drawing alpha

| Clip output | Behavior |
| --- | --- |
| Rectangle crop | Crops the bounding rectangle of a static regular clip. Rectangular clips are direct; vector clips use their coordinate/control-point bounds, which can include extra space around curves. Inverse and animated clips require an alpha output. |
| Clip alpha crop | Uses the actual clip shape as alpha and crops to its nontransparent bounds. Handles inverse clips and rectangular clip animation through libass. |
| Clip alpha full frame | Applies clip alpha while retaining the full video dimensions. |
| Drawing alpha crop | Renders the selected event's drawing sections as an alpha mask, then crops to the nontransparent area. |
| Drawing alpha full frame | Uses drawing alpha while retaining the full video dimensions. |

Clip coordinates use the subtitle resolution and are scaled to video pixels. Vector paths accept scaled clips, multiple contours, `m`/`n`, curves and complete finite numeric coordinates. Invalid paths or overflowing drawing scales are rejected. A clip introduced only inside a transform starts from the full subtitle frame for its rectangular interpolation. Vector clip transforms remain subject to libass's ASS support.

Drawing masks retain the source style, margins, alignment, scaling, rotations, motion, resets and transparency. The mask uses the original event clock, so clipping, fades and transforms are evaluated at the captured video's timestamp. Actual rendered alpha is extracted; RGB luminance is not substituted for transparency. This preserves partial alpha and antialiased edges regardless of drawing color.

Only drawing sections contribute to a drawing mask. Ordinary text is omitted. Mixed text/drawing events can therefore have different layout after text is removed; drawing-only events are the intended input. ASS comments and tags inside transforms do not accidentally activate drawing mode. Named style resets use the current subtitle file's styles.

The alpha crop includes every pixel with nonzero alpha, including faint one-pixel edges and odd-sized shapes. A completely transparent mask reports that no alpha area was found. Lines without a usable clip or drawing are skipped and reported.

## Rectangles and padding

X and Y may be negative; W and H must be positive. Padding must be nonnegative. The expanded rectangle is intersected with the video dimensions. A rectangle entirely outside the video reports an error instead of producing an unrelated edge pixel.

Finite values and the actual frame dimensions determine the valid output. Padding applies to manual rectangles and Rectangle crop. Alpha outputs use their rendered alpha bounds; their crop is not enlarged by the rectangle-padding control.

## Frame sequence outputs

At least one output must be checked:

| Checkbox | PNG content |
| --- | --- |
| No subtitles | Original video pixels. |
| With subtitles | Video plus all non-comment events overlapping the sequence interval from the current subtitle file. The selected events define the interval, not the complete set of events burned into it. |
| Subtitles only | The current subtitle rendering on a transparent background. |

Sequence rendering preserves native style properties, including `scale_x`/`scale_y`, and keeps original event times. A line beginning before the exported interval retains its animation progress. Script Info settings and styles are written to a temporary ASS file; missing resolution information falls back to the video dimensions. Embedded fonts/graphics are not exported; FFmpeg/libass uses fonts available to its renderer.

Every requested PNG is checked for a valid PNG structure, including frames in the middle of the interval. Successful extraction is not inferred solely from the first and last file or FFmpeg's exit code. The output range includes the first active frame and excludes the frame following the final active frame.

## Output folders and names

The output root is `Snapshots` beside the saved subtitle project, with the script/video directory as fallback. There is no separate output-directory chooser.

Single captures are written directly in Snapshots. Larger batches normally receive a uniquely named subfolder. **All images in Snapshots** writes directly in the root instead and prefixes names to avoid collisions. A sequence with one output normally uses its sequence folder; multiple outputs use `clean`, `with_subtitles` and `subtitles_only` subfolders unless flattened.

Names include a sequence counter, line or frame information and timestamp. **Add subtitle text to filenames** adds a sanitized visible-text suffix. Invalid Windows filename characters and reserved device names are handled, and the bounded filename suffix is cut only between complete graphemes. The suffix limit protects path length; it does not truncate subtitle text or output data.

## Preferences and failures

Capture options and FFmpeg settings use the shared configuration service, with migration from `kite-snapshoter.json`. The frame-list draft is not saved between invocations. Failed preference writes are reported. Cancelling Config returns to the preserved main draft; closing the main window performs no capture.

Temporary mask files and intermediate alpha PNGs are cleaned up after each capture, including processing errors. A failed capture removes its partial PNG. Already completed captures remain available if a later capture fails. Interrupted sequences can retain their completed or partial output set; they are not reported as a successful complete sequence. Temporary subtitle files are removed on the handled failure and cancellation paths.

The Windows supervisor preserves Unicode paths and literal `%06d` filename patterns and monitors cancellation. The non-Windows fallback uses the existing command runner and may only respond to cancellation between process calls.

## Requirements

Install Aegisub-Motion, `myaa.ASSParser` and FFmpeg. Use FFmpeg with libass and PNG support for subtitle and transparency captures.
