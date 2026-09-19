# Moka Motion 3.7.6

English | [Español](es/MokaMotion.md) | [Index](../README.md#documentation)

Moka Motion applies and reverses Mocha motion, converts masks to clips/drawings, applies corner-pin perspective, refines existing frame-by-frame tracks and exports media for tracking.

Default menu root: **Moka Motion**; DependencyControl can add a saved custom menu prefix.

## Commands

| Menu command | Input | Result |
| --- | --- | --- |
| Motion/Apply Motion | AE Transform data and selected subtitle lines | Tracked ASS lines |
| Motion/Revert Motion | The same Transform data and corresponding tracked lines | One inverse application |
| Shapes/Create Clip | Supported mask/shape export | Animated `\clip` |
| Shapes/Create Inverse Clip | Supported mask/shape export | Animated `\iclip` |
| Shapes/Create Vector Drawing | Supported mask/shape export | Positioned ASS drawings |
| Perspective/Apply Power Pin | CC Power Pin or Corner Pin data | Tracked perspective and optional clips |
| Track Refinery | Existing FBF lines with explicit positions | Analysis, smoothing, duplicate repair or endpoint retargeting |
| Utilities/Optimizer | Consecutive compatible FBF states | Fewer subtitle events |
| Utilities/Inspect Mocha Data | Any supported export | Format, sample, timing and channel diagnostics |
| Utilities/Create Video Clip | Selected time range and loaded local video | Verified H.264 MP4 |
| Utilities/Create Exact PNG Sequence | Selected time range and loaded local video | Verified PNG sequence indexed by source frame |
| Utilities/Trim Settings | Encoder executable paths | Saved FFmpeg/x264 settings |

## Select the range and align the data

The tracking and media commands use non-comment dialogue lines with positive duration and require loaded video timecodes. The selection is normalized. Its timeline begins at the earliest selected start and ends at the latest selected end, including gaps between selected lines. Frame ends are exclusive: a selection covering frames 103 through 160 contains 58 frames and has an end frame of 161.

Paste export text into the input box, or enter the path of a text file. The initial text comes from the clipboard. Files with a UTF-8 BOM and CRLF/CR/LF line endings are accepted. **First data row** is one-based and refers to an entry in the parsed sample array, not the number in the export's Frame column.

**Reference row** selects the neutral tracking sample after slicing from First data row. Its initial value follows Aegisub's current video position when that position belongs to the selection, otherwise it uses row 1. The value is confined to the available sliced data; the command cannot use a nonexistent reference.

Motion and Shapes offer two mapping modes:

| Mapping | Interpretation |
| --- | --- |
| Selection timeline | A single track follows the entire selected timeline, including gaps |
| Restart on each line | Each selected line starts from the first sliced sample; enough samples for the longest selected line are required |

Power Pin uses the selection timeline. An export that is too short is rejected with the available and required sample counts. A single static mask can be held across the selected range without inventing intermediate motion.

Strict synchronization is optional. It rejects missing/interpolated source frames, ambiguous rotation jumps, incompatible FPS/timecode phase and differing source/composition pixel aspect ratios. Rounded common rates such as 23.976 are recognized as 24000/1001. Per-line mapping and static shapes apply their own timing context. Disabling strict mode permits the reported interpolation or approximation; it does not supply information absent from the export.

An input, slicing, synchronization or application error returns to the Motion/Shapes/Power Pin form with its text and values intact. Cancel closes that draft. Successful subtitle application uses one undo point; failure or cancellation during application restores the original subtitle. The recovered output selection and first active row follow the inserted/replaced results.

## Apply and revert Transform motion

AE Transform input can contain Position, Scale, Rotation, Anchor Point and Opacity. At least Position, Scale or Rotation must be present. A one-value Scale expands to X/Y. Missing Position uses the exported source center as the pivot. Missing samples interpolate between known values and are reported. Source frame numbers must be finite, representable integers; malformed numeric cells and duplicate frames are rejected.

Rotation wrapping distinguishes conventional angle-boundary crossings from explicitly cumulative revolutions. Ambiguous jumps are preserved and diagnosed instead of automatically choosing a shorter turn. Anchor Point is retained for diagnostics and is not applied twice. Opacity is read but does not change ASS geometry.

| Control | Effect |
| --- | --- |
| X / Y | Apply the corresponding position component |
| Scale / Rotation | Apply scale ratios and rotation relative to the reference |
| Move `\org` | Move the explicit transform origin with the track |
| Transform clips | Track rectangular/vector clips |
| Clips only | Apply the track to clips while leaving the text geometry alone |
| Borders / Shadows / Blur | Scale the selected styling geometry with the track |
| Absolute position | Place the tracked position at the sample's exported position instead of preserving its relative offset |
| Compact linear motion | Use a compact linear result when the channel/tag checks prove it suitable |
| Optimize FBF states | Run the conservative 0.05-unit state optimizer after application |

The source size is read from the export and coordinates are scaled to the current ASS resolution. Style properties and existing static tags supply the starting geometry; frame-dependent tags are evaluated before each generated state. Original first/last time boundaries are retained, and karaoke offsets are shifted for the generated frame interval.

Position, origin, scaling and clips use shared balanced ASS tag readers. Comments do not become geometry. Numeric tags accept complete finite values, including signs, decimals and exponents. Vector clips are validated and mapped as coordinate pairs, so tabs or multiple spaces do not leave points untransformed. Scaling a clip with an explicit drawing scale first converts its coordinates to the scale-1 system. Animated scalar/clip targets are handled without treating comments as tags.

Revert applies the mathematical inverse using the supplied data, mapping and reference. It has no hidden snapshot dependency. To undo one application, use matching data and options. A zero scale has no inverse and is rejected. Geometry that needs shear under anisotropic scale/rotation cannot always be represented by ordinary Transform tags; the application report identifies that approximation and points to the Power Pin/Perspective route. Revert cannot restore detail lost through earlier rounding or an approximation.

## Repair and clean incoming tracking samples

**Duplicate sample** can be Off, Detect only or Repair duplicate sample. Detection looks for a stalled position sample whose movement resumes, with corresponding scale/rotation evidence. Detect only reports the candidate. Repair removes the duplicate from the progression and extrapolates only the new tail sample, preserving the overall sample count. Review a deliberate hold before applying this repair.

**Cleanup** can be Off, Protective or Local regression. Protective cleanup uses channel-specific residual evidence to flatten near-constant channels, fit sufficiently linear data or correct an isolated outlier. Local regression uses the selected Window and Degree. The cleanup stays anchored at the reference sample. The report states how many channel values changed.

Window defines a neighborhood bounded by the available samples. Degree remains 1–3 because these modes use local linear, quadratic or cubic fitting. The dialog applies full cleanup strength; Track Refinery offers a separate strength control. Cleanup is optional and defaults to Off.

## Create clips and drawings

Supported inputs include AE Mask `Shape` blocks with vertices and optional tangents, legacy `Bezier(Point(...))` data and Shake RotoShape SSF 4.0. Tangent counts and finite coordinates are validated. Shape metadata is read from the complete relevant entry.

Sparse AE/legacy shape data holds the previous shape at missing frames rather than compressing the timeline. Shake data interpolates compatible point layouts and otherwise holds available geometry. Interpolated/held samples are marked; strict synchronization can reject them because the original temporal easing is unavailable. Invisible or unsupported shape states can require editing the source export.

| Control | Effect |
| --- | --- |
| Placement: Replace selection | Replace selected sources with the generated output |
| Placement: Insert new lines | Keep sources and insert output after them |
| Offset X / Y | Add a translation after coordinate scaling |
| Tangent epsilon | Decide when a nearly straight Bézier segment can be emitted as a line |
| Inserted layer + | Layer offset for newly inserted output |
| Drawing tags | Additional tags for vector drawing output; defaults to zero border/shadow |
| Use exported source size | Prefer exported dimensions over the source W/H fields |
| Scale to target | Scale source coordinates into target W/H |
| Source W/H / Target W/H | Source and output coordinate systems |
| Decimals | Output coordinate precision, from 0 to 6 |

Clip output follows the selected text's temporal state. Drawing output creates its own `\an7`, position, unit scale and drawing-mode tags, and moves the path into local coordinates. Adjacent identical static output states can merge, while remaining duration-dependent tags prevent a merge that would change timing.

## Apply Power Pin

Moka recognizes the four CC Power Pin or Corner Pin channels and orders their corners for the perspective solver. All required channels must be present. It interpolates missing samples only when strict synchronization allows it, checks each quad and rejects invalid, crossed, concave or numerically degenerate geometry. Small valid subpixel quads are no longer rejected solely for having an area below one ASS square unit.

**Perspective** controls the perspective composition. **Position**, **Border / shadow** and **Clips** control the linked components. **Origin mode** offers Keep `\org`, Force stable center and Try `\fax0`. The solver uses the document's PlayRes/LayoutRes relationship and loaded video dimensions. Each source uses a reference frame within its own time span. Unsupported reference states are reported before the final insertion.

The geometry comes from the shared ASS context and the installed perspective library. This path can represent deformation that ordinary X/Y scale plus rotation cannot. It needs a usable reference quad and compatible ASS geometry. Review the result against the source effects.

## Track Refinery

Select existing FBF dialogues with explicit `\pos`. Tracks group compatible layer/style/actor/text and adjacent frame spans. Duplicate selection indices do not create duplicate samples. Lines without usable positions, positive duration or loaded frame times are excluded.

| Operation | Behavior |
| --- | --- |
| Analyze | Report track sizes, motion steps, authored cycles and duplicate candidates |
| Smooth / Denoise | Fit local motion; affect outliers only or the whole track |
| Repair Duplicate Frame | Repair a detected duplicated progression sample |
| Retarget Start | Move the start toward Target X/Y, tapering smoothly to the original end |
| Retarget End | Move the end toward Target X/Y, tapering from the original start |

Window chooses the local neighborhood; Degree selects linear/quadratic/cubic fitting. Strength is a percentage from 0 to 100. Min residual sets the baseline outlier threshold. **Preserve authored zig-zag / cycles** detects recurring authored signatures and geometric phases; cycles longer than eight frames are supported. This detection is heuristic; review intentional movement before applying the result.

**Shift linked `\org` and clips** follows a positional correction with the linked geometry. **Smooth scale / rotation / styling geometry** also considers complete static channels such as scale, rotation, border, shadow and blur. Missing channels are skipped instead of sent to a fit with no samples. Comment tags do not become channel values.

The changed count is the number of distinct lines changed, including scalar-only edits. A line changed in several channels counts once. Those edits receive undo and rollback just like position changes. Retargeting works on one- and two-frame tracks; smoothing/duplicate repair still needs at least three samples.

## Optimizer

Choose Exact (0), Conservative (0.05) or Subpixel (0.10) comparison. The optimizer merges consecutive compatible states against the retained anchor, preventing small per-frame differences from accumulating positional drift. It preserves differing metadata and extra fields, and protects movement, transformations, fades and karaoke whose meaning depends on event duration. Some drawing/perspective states are intentionally ineligible.

Its report lists before/after counts, merged states, longest run, temporal tracks and protected states. No compatible run means no edit or undo point. The tolerance is a comparison in script coordinates; a compacted result may still warrant visual checking for the intended subtitle resolution.

## Inspect exported data

Inspect reports detected type/format, parsed sample count, first/last source frame, exported FPS and source size. Transform input also gets duplicate-sample analysis. The diagnostics list unknown channels, interpolation, uniform-scale expansion, ambiguous rotations and other unsupported information. Inspect does not alter subtitle lines.

## Export a video clip or exact PNG sequence

Create Video Clip reads the selected frame range and loaded local video path. It prefers FFmpeg with libx264, then uses external x264 if needed. The fallback extracts lossless MKV when x264 has the required decoder, otherwise Y4M. Audio is omitted. Irregular timecodes are normalized to a stated CFR for the MP4.

The encoded intermediate and final MP4 are decoded to verify the requested frame count. Only a verified MP4 is moved into the source directory. Its name includes the first and last included source frame; a numeric suffix avoids existing output filenames. An error leaves a diagnostic log. When useful, a valid intermediate MKV is retained; temporary source extractions and incomplete MP4s are cleaned. A failed export does not replace a previous published clip.

Create Exact PNG Sequence asks for a base filename and creates a corresponding `_frames` directory. If it already exists, the command chooses a new numbered directory. Previous sequences are preserved. Filenames use `frame_%08d.png`, starting with the original source frame number. Export uses passthrough frame timing and checks every expected file as a valid PNG. Incomplete/failed output remains available for inspection and is reported.

Trim Settings saves FFmpeg and optional x264 executable paths in the shared `kite.MokaMotion` settings. Blank fields use PATH. File-picker cancellation preserves typed values; a save error keeps the form available. Motion/shape/reference forms are per-run drafts rather than persistent encoder settings.

Windows tools run through a hidden native process supervisor with structured executable arguments, Unicode-safe PowerShell text, separate diagnostics and cancellation. Paths with spaces or apostrophes are quoted without invoking a command shell to interpret the encoder arguments. Cancellation can wait for the native process to stop; it is reported with exit code 130.

## Drawing coordinates and external processes

Coordinate remapping uses `AssDrawing.mapCoordinates` for complete ASS paths, including spline commands. External commands use `kite.PyBridge` for argument quoting, Unicode support, completion and cancellation.
