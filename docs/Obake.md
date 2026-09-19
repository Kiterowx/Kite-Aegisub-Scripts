# Obake 0.4.5

English | [Español](es/Obake.md) | [Index](../README.md#documentation)

Obake builds transform chains, applies animation and layer presets, connects pairs of visual states and generates random or alternating frame sequences.

## Commands and workflow

The main **Obake** entry opens an action picker. **Execute** opens that action's options, or runs a direct action. **Help** displays contextual information. **Language** switches English/Spanish while retaining the chosen action. Canceling an options window returns to the picker; canceling the picker exits. **Obake/Help** is available without a dialogue selection.

Eight additional commands are registered under `: Kite Hotkeys :/Obake/`, one per action below. They open the same options or direct operation as the picker. DependencyControl may add the user's saved custom menu prefix. The main and action commands require selected non-comment dialogue lines; ZigZag requires at least two, and In-Out requires valid pairs.

| Action | Input | Output |
| --- | --- | --- |
| Apply chain | Selected lines and keyframe/shape settings | Initial tags followed by timed transforms |
| Animation FX | Selected lines and a preset | Modified lines or preset-specific replacement layers |
| Color preset | Selected lines | Fill/border, glow, shadow or cleaned layers |
| Border layers | Selected lines and enabled borders | One fill plus the enabled cumulative borders |
| Retime transforms | Existing timed transforms | Transform times scaled to the line duration |
| In-Out tags | Two selected lines per Effect value | One transition line; both sources become comments |
| Gunfight of Tags | Explicit numeric/hex tags | Randomized selected states or generated frame slices |
| ZigZag lines | Two or more selected visual states | Alternating states across their combined time range |

Subtitle modifications use a transaction and one undo point. A write failure or cancellation during commit restores the document. Output selection follows generated replacements; In-Out selects the newly created lines.

Your preferences are saved between sessions. Cancel closes the form without applying it.

## Transform chains

The common-tag grid provides text to copy into keyframe rows. Each row contains a time and a tag payload, without braces. The editor displays eight rows per page with a visible row range. **Previous/Next** preserve edits. **Add+** duplicates the last row and opens the last page; **Rem-** removes the last row while retaining at least two. **Reset** restores the default chain. There is no total keyframe ceiling.

**Strip existing transforms** removes actual top-level `\t` calls before adding the chain. Comments containing example tags remain comments. The generated tags go in the leading override block, or in a new block before the text/comment. Optional acceleration accepts any finite positive value; nonpositive input uses the default acceleration. Small values are serialized without being rounded to zero.

| Shape | Interpretation of Value |
| --- | --- |
| Manual keyframes | Uses all rows; Value and Delay do not define the row timeline |
| Once (one-way) | First row to last row over the available interval |
| Out and back | First to last, then back to first, in two equal halves |
| Yoyo (N cycles) | Integer number of forward/back cycles, minimum one |
| Pulse (ms) | Duration of each alternating half-cycle, minimum one millisecond |
| Steps (N) | Number of interpolated target states, minimum two |

Manual times use **Percent** of the line duration or **Milliseconds**, and are confined to that line's interval. Rows are sorted by time; the last row wins when several share a time. The earliest payload is the initial state, followed by transforms between consecutive retained rows. A single retained nonempty payload acts as a static initial state.

The other shapes use the first and last payloads. Delay can be zero, milliseconds from the start, a percentage, or the current frame. It shifts the start of the animation, not the event's start time. A delay at the line's end leaves no animation interval.

Steps evaluate each target with ASSFoundation and the shared ASS context. Multiple scalar tags, colors, rectangular clips, style defaults and ordered resets use the same evaluation rules as frame sampling. For example, four steps from `\fscx100\fscy50` to `\fscx200\fscy150` target 125/75, 150/100, 175/125 and 200/150. These are successive transform targets, not instantaneous hold frames. ASS's restrictions on transformable properties still apply.

The entire selection is checked before a chain is committed. A zero-duration member is reported instead of silently applying only to the other members.

## Animation FX

The form provides Preset, Strip existing transforms, optional Acceleration, Step in milliseconds, Amount and two colors. Each preset uses the controls described below; unused controls do not affect that preset. Generated effects retain the original text unless the preset explicitly splits it.

When valid karaoke cues are present, the start of the second karaoke block supplies an internal cue. Its time must lie strictly inside the line. `\kt` establishes an absolute karaoke start, and repeated duration tags in one override block use the last duration. Comments and tags nested inside transforms do not become cues. Presets using that cue remove the karaoke tags while keeping other formatting. Otherwise, frame-dependent actions use the current video frame.

| Preset | Result and relevant controls |
| --- | --- |
| Blur In | Blur 8 → 0; optional acceleration |
| Blur Out | Blur 0 → 8; optional acceleration |
| Fade In | Global alpha FF → 00; optional acceleration |
| Fade Out | Global alpha 00 → FF; optional acceleration |
| Scale Up | X/Y scale 100 → 115; optional acceleration |
| Scale Down | X/Y scale 115 → 100; optional acceleration |
| Pop In | X/Y scale 40 → 100 and alpha FF → 00; optional acceleration |
| Pop Out | X/Y scale 100 → 40 and alpha 00 → FF; optional acceleration |
| Color Flash | Color 1 → Color 2 over the first 30% of the available interval, then back |
| Color Pulse | Alternates Color 1 and Color 2; Step is each half-cycle |
| To Color (frame) | Transforms primary, outline and shadow colors to Color 1 from the cue/current frame until the end |
| To Style (frame) | Starts those channels at Color 1 and reaches the line style's colors at the cue/current frame |
| Border Pulse | One transition of outline 2 → 6; optional acceleration |
| Glow Pulse | One transition of blur 1 → 8 and outline 2 → 4; optional acceleration |
| Shake V / H / XY | Alternating Z rotation around a displaced origin; Step controls each half-cycle and Amount the angle |
| Wobble (frz) | Alternating positive/negative Z rotation; Step and Amount |
| Glitch | Random shear and integer spacing targets; Step and Amount |
| Dramatic Pulse | Two layers: expanding fading glow and a smaller scale pulse that settles back; Color 1 and Step |
| Flashback (fad) | Adds a 200 ms entrance/exit fade |
| Split Line | Reveals the second text part at the cue/current frame using two consecutive events |
| Split Line Fad | Keeps the first part and introduces the second on a higher layer with a 250 ms fade |
| Split Title | Two simultaneous layers: hidden fill on the lower copy and zero outline on the upper copy |

Color Pulse, Shake, Wobble and Glitch accept steps down to one millisecond. Dramatic Pulse retains its designed minimum 120 ms expansion and 180 ms settling endpoint, with the second endpoint also derived from 1.8 times Step. These are preset timings, not a generation budget. Border Pulse and Glow Pulse retain their historical names and each makes one transition.

Shake resolves position through `AssContext`: it can inherit alignment, margins and resolution from the style/document when no explicit position is present. It creates a distant origin and rotates around it; its apparent movement depends on the selected axes and existing geometry. It is an artistic rotational effect rather than a translation track.

For Split Line and Split Line Fad, use karaoke text such as `{\k20}First{\k80}Second`, or insert `|` between the two parts and place the video cursor strictly inside the event. The pipe is removed. An invalid/outside cue does not create negative-duration events. Ordinary splitting translates the existing transform, movement, fade and karaoke time coordinates so that shortening an event does not restart its effects. Split Line Fad replaces the new layer's old fade with its own entrance fade. Inline styles and visibility tags can still deliberately override the preset's initial tags.

## Color and border layers

| Color preset | Layer behavior |
| --- | --- |
| Decompose (Fill + Border) | Lower copy hides fill while retaining border/shadow; upper copy keeps fill and removes outline/shadow |
| Blur + Glow | Lower copy uses blur 3 and global alpha 80; upper copy gains blur 0.6 only when no explicit top-level blur exists |
| Shadtrick (Shadow Layer) | Lower copy exposes shadow using the small X-shadow displacement required by the trick; upper copy removes shadow |
| Double Border Blur | Fill on top, normal border with blur 0.4 in the middle, doubled outline with blur 2 below |
| Clean Layers (Flatten) | Each selected line loses alpha tags and CAL markers and moves to layer 0 |

Double Border Blur uses the largest explicit nonnegative border component, falling back to the actual style outline and then the legacy value 2 when no style is available. Clean Layers works on each selected line; it does not infer the source of a group or merge text from several layers.

Border layers provide four individually enabled controls B1–B4 with nonnegative sizes and colors. Sizes are cumulative in enabled order. For B1=1 and B2=2, the inner outline is 1 and the outer outline is 3. The fill sits above all borders. No enabled border produces no replacement. Generated groups receive `[CAL-NNN]` markers while preserving unrelated Effect content.

Layer helpers remove conflicting selected properties, including their animated occurrences, and append the requested values after reset tags. This is deliberate when making an exact fill, outline or blur layer. Unrelated tags and comments remain available.

## Retime transforms

This direct action infers each line's source duration from the greatest explicit transform endpoint and scales explicit `\t(t1,t2,...)` times to that line's current duration. It does not change the event times. The public dispatch options also accept `retime_source`, `retime_target` and `retime_info`.

Untimed `\t(tags)` and `\t(accel,tags)` remain tied to the line's duration. Balanced nested arguments such as rectangular clips remain intact; comments containing transform examples are ignored. If no timed transform can be changed, the action reports that condition.

## In-Out tags

Select exactly two non-comment dialogues for each distinct Effect value. Empty Effect is a valid group, so four selected lines with empty Effect do not form two inferred pairs. The pair is ordered by time, with row order breaking ties.

The two endpoints must have compatible style, layer and margins. Their leading override blocks supply visual states. Differing animatable tags become transforms; differing positions become a move. Static properties that cannot animate must match. A differing rectangular clip can interpolate only when both endpoints use the same clip type. A differing vector clip is rejected because ASS cannot animate its path through `\t`.

Position coordinates and clip/fade arguments must be complete finite values; signs and scientific notation are accepted. A string such as `1x` is rejected instead of being partially interpreted as 1. Both endpoints require explicit placement, or both may inherit placement; a pair with only one explicit position is diagnosed.

Existing transforms, full fades and karaoke require baking/removal first because merging their time domains would change them. Leading `\fad` is supported: the first endpoint contributes the entrance and the second the exit. Differing inline overrides around identical visible text are diagnosed. When visible bodies differ, a dialog lets you choose either text or cancel.

Each successful pair produces one event spanning the earliest start to latest end, including any gap. The originals become comments. Their unrelated text and Effect data remain on those source rows. All pairs must succeed before the transaction is applied.

## Gunfight of Tags

The form lists numeric and hexadecimal tags actually found in the selection, with occurrence counts. Select the tags to change, or use **All/Clear**. It does not synthesize absent style tags merely because the style has corresponding values.

| Control | Meaning |
| --- | --- |
| Min / Max | Random additive change; reversed bounds are normalized |
| Step | Quantization of the random change; zero permits continuous values |
| Dec | Output decimal precision, 0–8 |
| Seed | A repeatable seed; zero chooses a fresh local seed |
| Link | Share the change per value, line, tag, line axis or tag axis |
| X / Y | Enable the corresponding coordinate components |
| Scalar/discrete | Enable scalar, discrete and color/alpha values |
| Times | Enable supported timing arguments |
| Inside `\t` | Change selected target tags within transforms |
| `\t args` | Change transform time/acceleration arguments according to enabled categories |
| `{*}` blocks | Include the explicitly requested special blocks in the numeric-tag pass |
| Clamp ≥0 | Prevent negative values for properties whose specifications require that |
| Discrete safe | Round discrete tag values appropriately |
| FBF period | Number of frames per generated slice, or selected rows per linked group |
| Count selection as FBF unit | Treat a multiple-line selection as an existing sequence instead of splitting each event |
| Report | Show changed values, source lines, seed and generated/recognized frame information |

With multiple selected lines and Count selection enabled, the sequence follows normalized subtitle row order. A period groups that many selected rows under the same random sequence/cache context. Existing event times remain unchanged; recognizing one-frame events is reported but does not impose that requirement.

With one source, or when Count selection is disabled, each source is split on loaded video timecodes. Original first/last event boundaries are preserved. The random change is applied to the source tags before evaluating the resulting temporal state at each slice's start. Ordered transforms, moves, fades, resets and karaoke use the shared context and the current document's styles. Thus a transform does not restart at each slice.

A period above one frame deliberately holds the sampled visual state for that slice. Use period 1 for full frame sampling. The period and output count have no fixed upper limits. Generation checks cancellation, and insertion is chunked to stay within Lua's argument limits. Memory and actual video frame availability remain practical constraints.

Random generation uses its own seeded generator and does not reseed Lua's global random state. Byte ranges for color/alpha, discrete ASS domains, seed domain and output precision remain meaningful constraints.

## ZigZag lines

Select two or more visual states. The output covers the minimum selected start through the maximum selected end, including gaps, and cycles through the states in normalized row order. The period sets each slice's frame length. Originals are replaced and the resulting sequence is selected.

For each slice, temporal tags are evaluated at the slice's absolute time relative to the chosen template's original start. A template's transform/fade can therefore already be complete when the combined range extends past its own end; it is not restarted each time that template reappears. Static templates remain static. Use coincident source ranges when all states should share a common animation timeline.

## Dependencies

Obake requires ASSFoundation, a-mo.Line, Core, UI, LineOps, AssContext and Color.

Slice timing uses `AssContext.retimeSlice`. Transform, move, fade and karaoke clocks are preserved; reversed move intervals are normalized before shifting.
