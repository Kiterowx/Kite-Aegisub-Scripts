# Zagreo Glyphs 1.2.3

English | [Español](es/ZagreoGlyphs.md) | [Index](../README.md#documentation)

Generate vector drawings from a uniform text line or an ASS drawing, then deform them over time. The original selected lines become comments; generated events are inserted after their source and selected. Pair Morph comments both inputs and inserts the result after the second selection.

## Workflow and menus

1. Select uncommented dialogue lines. For Pair Morph, select exactly two: the lower subtitle index is the source, the other is the target.
2. Open **Zagreo Glyphs**, choose a category and effect, and use **Filter** to refresh the effect list for that category.
3. **Run** opens the parameters. **Apply** validates them and generates output; **Back** returns to the picker; **Cancel** leaves subtitles unchanged.

Every effect also has a direct command under `: Kite Hotkeys :/Zagreo Glyphs/<Category>/<Effect>`. **Zagreo Glyphs/Help** browses the same catalog without generating lines. There are 230 effects and 232 registrations. Existing command names and compatibility aliases remain available.

The effect picker and each effect’s settings are saved separately. Invalid values keep the form open so you can correct them.

## Source interpretation

The source style comes from the subtitle collection. Initial font/style overrides and initial `\r`/`\rStyle` resets are interpreted in order through `AssContext.applyInlineStyleTags`; relative `\fs+N` and `\fs-N` follow ASS relative-size semantics. Position and alignment use `AssContext`, including the first effective `\pos`/`\move`, legacy `\a`, style margins, and script resolution. The horizontal center without explicit position is the center of the area between the left and right margins.

Drawings are read through ASSFoundation, converted from their `\p` scale and font scale to `\p1`, and checked with `AssDrawing.validatePath`. All contours are preserved, including small ones. Curves are flattened and edges split with Yutils for operations that deform individual vertices. An unchanged field result reuses its original path, avoiding needless resampling differences in rasterization.

Font conversion uses `Yutils.decode.create_font` and `font.text_to_shape`. Font availability and shaping depend on that backend. On Windows, its underlying text conversion has an 8,192 UTF-16 code-unit backend limit.

One output path has one appearance. Mixed text/drawing input, multiple drawing sections, inline typography or appearance changes, animated typography, and explicit line breaks are reported before editing instead of being silently flattened into an incorrect uniform path. Convert these inputs into separate uniform lines first. Check font conversion and automatic text wrapping against the actual Aegisub renderer and installed fonts.

## Parameters

| Control | Meaning |
| --- | --- |
| Target font | Destination family for Font Morph. Required for those effects. |
| Moments | Number of equal time intervals in Moments only mode, or without usable frame timing. Positive integer. |
| Ratios | Blank for evenly spaced 0…1 values; a single moment uses 1. Otherwise provide exactly one finite ratio per moment, separated by spaces or commas. The legacy `0, 0.5, 1` default expands automatically when the moment count changes. Linear font/pair morphs allow extrapolation outside 0…1. Elastic and named easing effects use their own curves. |
| Split len | Positive edge-sampling distance in script coordinates. Smaller values produce more detailed and more expensive geometry. Morph contours retain at least eight samples. |
| Strength | Nonnegative deformation amount. Depending on the effect it represents displacement, scale percentage, rotation or another effect-specific amplitude. Zero is not an identity operation for every algorithm; it is for Boiling Line. |
| Frequency | Nonnegative spatial frequency or element count. The effect defines its interpretation; integer-count kernels round it. |
| Scale | Positive noise sampling scale. Larger values generally produce broader coherent deformation. |
| Seed | Integer controlling deterministic noise. The same source and settings produce the same output. |
| Period ms | Nonnegative cycle duration. At zero, phase follows the slice ratio. |
| Pieces / Passes | Positive number of output layers per temporal slice for Shatter / Sketch. |
| Blur | Nonnegative ASS blur for Sketch passes. |
| Alpha | Integer 0…255, where 0 is opaque and 255 transparent. Sketch applies its existing 75% alpha rule; Shatter adds the requested alpha when nonzero. |
| Center X% / Y% | Offset of the effect center, measured against half the shape width/height. Values may exceed ±100. |
| Direction | Left to Right, Right to Left, Top to Bottom or Bottom to Top for directional effects. |
| Timing | Auto frame ranges or Moments only. |
| Motion | Preserve source motion or Bake AE position data. |
| Ref frame | One-based reference frame within the imported tracking interval, relative to its first frame. |

There are no fixed script ceilings on moments, layers, shape size, period, seed, strength, frequency, blur or offsets. Values must be finite, counts must be representable integers, and a moment interval must contain at least one whole millisecond. Memory and the renderer's numeric limits still apply. Long Lua loops check cancellation; a single native Yutils call must return before Lua can observe cancellation.

## Timing and motion

**Auto frame ranges** generates one shape state per available video frame, clipped to the source event's interval. If frame timing is unavailable it falls back to Moments. **Moments only** partitions the event duration equally. It does not extend the event when there are more requested moments than whole milliseconds: that input is rejected.

The geometry changes between slices. Existing color, border, clip and other supported `\t` animations keep their original clock through `AssContext.retimeText`, as do `\fad`, `\fade` and `\move`. Motion keeps the original endpoints and timing instead of repeatedly rounding short segment endpoints. The first position tag keeps priority. Explicit origins are preserved; a moving line with rotation/shear and no explicit `\org` still requires an origin before converting to a different alignment.

Selected Aegisub-Motion events with the same `a-mo` UUID share effect progress in chronological order. Their selected durations are concatenated; gaps between selected events are not added to the phase. Generated copies drop their `a-mo` tracking marker while preserving unrelated extradata; originals retain their data.

**Bake AE position data** adds imported displacement to the source motion. It accepts `X Y`, `Frame X Y`, or `Frame X Y Z` rows, including exponents. In an AE block, Position takes priority over Anchor Point and parsing ends before the next property. Z is ignored. Numbered rows must increase strictly; missing frames are linearly interpolated. Samples outside the imported range hold the nearest endpoint. Values are used in script coordinates; the importer does not infer AE composition scaling, rotation or perspective. Use Moka Motion for that wider workflow.

## Effect families

| Family | Operation |
| --- | --- |
| Morph | Font Morph converts the same text in a target font. Pair Morph interpolates selected source/target outlines over their combined time span. Shape Morph builds blob, line, spike or scribble targets per contour. Contours are paired by index, resampled by arc length, winding-adjusted and cyclically aligned; this is geometric correspondence, not semantic letter matching. |
| Surface, Waves, Radial, Edge, Ink, Drip | Field functions displace sampled vertices using phase, normalized bounds, normals, tangents, noise and effect settings. |
| Path, Reveal | Subpath modes keep selected runs, create dots or displace a reveal frontier. ASS closes filled subpaths; these are filled path fragments, not automatically stroked centerlines. |
| Dissolve, Fold, Impact, Glitch | Geometric transitions, folds, impacts and coordinate disturbances. Effect coefficients define their visual character and are not output budgets. |
| Contour | Each drawing contour transforms around its own center or pivot. A contour is not necessarily a glyph: a letter's outer outline and holes can be separate contours. |
| Shatter | Samples filled pixels and creates diamond-shaped particles. Split len controls sample spacing and particle size. These are particle approximations, not an exact tessellation of the original fill. Pieces distributes those sites across output layers. |
| Sketch | Layers multiple seeded handwriting or boiling passes with blur and alpha. |

Generated events merge only when adjacent, visually static and equal in text, style, layer, actor, margins, comment state and extradata. Temporal tags prevent merging so a longer event cannot change their meaning. The generated Effect marker describes provenance and the first retained slice when a static run merges. All output is prepared before subtitle edits, and insertion failures roll the subtitle table back.

## Examples

- **Animated sign outline:** select a uniform drawing, choose Boiling Line, use Strength 3–6 and Split len 4, and keep Auto frame ranges. Increase Split len for fewer sampled vertices.
- **Three font states:** select uniform text, choose Font Morph, set Target font, Moments only, Moments 3, and leave Ratios blank. The three states are source, midpoint and target across equal intervals.
- **Sparse position tracking:** paste `10 100 200` followed by `14 140 240`, select Bake AE position data and Ref 1. Relative frame 3 samples `(120,220)` and adds `(20,20)` to the source position.
- **Retain complex source detail:** large drawings retain all contours. The operation may generate additional vertices and require more memory.

## Complete effect catalog

Each entry below is a registered operation. Its description explains the intended visual operation; the family notes above explain representation limits.

| Category | Effect | Operation |
| --- | --- | --- |
| Morph | Font Morph | Text becomes the same text in another font through vector in-betweens. |
| Morph | Font Morph Elastic | Font morph with overshoot and recoil. |
| Morph | Font Morph Overshoot | Pushes the shape past the target font before settling. |
| Morph | Font Morph Anticipation | Backs away briefly before morphing into the target font. |
| Morph | Font Morph Bounce | Morphs with a bouncing final approach. |
| Morph | Font Morph Steps | Stepped vector states between fonts. |
| Morph | Font Morph Glitch | Morphs while corrupting intermediate coordinates. |
| Morph | Font Morph Rubber | Stretches the in-between shape like elastic material. |
| Morph | Pair Morph | Morphs the first selected line into the second selected line. |
| Morph | Pair Morph Elastic | Selected-line morph with overshoot and recoil. |
| Morph | Pair Morph Overshoot | Selected-line morph passing the target before settling. |
| Morph | Pair Morph Bounce | Selected-line morph with a bouncing approach. |
| Morph | Blob Morph In | Each contour enters as a round blob and resolves into the drawing. |
| Morph | Blob Morph Out | Contours relax into round blobs and leave. |
| Morph | Blob Pulse | Contours cyclically soften toward blobs and back, lava-lamp style. |
| Morph | Line Sweep In | Contours unfold from flat horizontal strokes into the drawing. |
| Morph | Line Sweep Out | Contours collapse into flat horizontal strokes. |
| Morph | Spike Morph In | Contours enter as star bursts and settle into the drawing. |
| Morph | Spike Morph Out | Contours sharpen into star bursts and leave. |
| Morph | Scribble Morph In | Contours enter as loose scribbles that tighten into the drawing. |
| Morph | Scribble Morph Out | Contours unravel into loose scribbles. |
| Surface | Boiling Line | Constant organic boil over every path point, period-locked. |
| Surface | Electric Jitter | Hard unsmoothed per-frame jitter, like electric interference. |
| Surface | Handwriting Noise | Slow hand-drawn wobble of the whole outline. |
| Surface | Ink Wobble | Loose sine sway over the vector outline. |
| Surface | Fine Contour Jitter | Small fast per-point contour jitter. |
| Surface | Coarse Zone Jitter | Chunky zone-based jitter; whole regions jump together. |
| Surface | Organic Drift | Slow wandering deformation that never repeats. |
| Surface | Heat Haze | Upward-drifting shimmer bands, like air over fire. |
| Surface | Water Flow | Sideways-advecting refraction wobble. |
| Surface | Gelatin Wobble | Springy low-frequency jiggle with damped recoil. |
| Surface | Underwater Sway | Big slow current sway plus fine refraction. |
| Surface | Windblown Turbulence | Directional gusts ripping at the outline in bursts. |
| Surface | Static Buzz | One-frame alternating offsets, like TV static tremble. |
| Wave | Wave Horizontal | Traveling horizontal wave running through the drawing. |
| Wave | Wave Vertical | Traveling vertical wave running through the drawing. |
| Wave | Wave Diagonal | Traveling diagonal wave running through the drawing. |
| Wave | Standing Wave | Standing wave with fixed nodes and swinging antinodes. |
| Wave | Flag Wave | Wave whose amplitude grows away from the anchored edge, like a flag. |
| Wave | Skip Rope | Whole shape swings like a rope anchored at both ends. |
| Wave | Seaweed Sway | Anchored at the bottom, sways more toward the top. |
| Wave | Twist Wave | Local rotation angle waves along the axis, like a twisting ribbon. |
| Wave | Whip Crack | A single amplitude spike whips through the shape once per period. |
| Wave | Ripple Center | Circular ripple radiating from the drawing center. |
| Wave | Ripple Point | Circular ripple from an adjustable off-center origin. |
| Wave | Ripple Rain | New ripple origins keep appearing at random spots. |
| Wave | Cross Ripple | Two ripple origins interfering across the shape. |
| Wave | Bounce Wave | Rectified wave; crests bounce instead of swinging through. |
| Wave | Wave Settle In | Enters waving hard, then the wave dies down to the clean shape. |
| Wave | Wave Break Out | The wave grows until it breaks the shape apart on exit. |
| Radial | Twist Sway | The shape twists back and forth around its center. |
| Radial | Vortex Swirl | Continuous circulation around the center with radial falloff. |
| Radial | Magnet Pulse | An off-center attractor pulls the outline in pulses. |
| Radial | Pinch Pulse | The shape rhythmically pinches toward its center. |
| Radial | Bulge Pulse | The shape rhythmically bulges outward from its center. |
| Radial | Heartbeat | Double-thump radial pulse per period, like a heartbeat. |
| Radial | Spring Boing | Squash-and-stretch spring bounce with damped recoil. |
| Radial | Lens Sweep | A magnifying bulge sweeps across the shape each period. |
| Radial | Shockwave | A displacement ring travels outward once per period. |
| Radial | Pulse Rings | Concentric rings breathe in alternating directions. |
| Radial | Lag Orbit | The shape orbits a small circle; inner points lag behind, jelly-like. |
| Edge | Rough Edge | Multi-octave roughening along the outline normal. |
| Edge | Rough Edge Progressive | Rough edge grows from clean to fully rough over the line. |
| Edge | Rough Edge Calming | Rough edge settles down to clean over the line. |
| Edge | Serrated Edge | Regular symmetric saw teeth along the outline. |
| Edge | Sawtooth Edge | Asymmetric leaning teeth along the outline. |
| Edge | Bitten Edge | A few deep smooth bites dent the outline. |
| Edge | Corroded Edge | High-frequency inward pitting, like rust eating the edge. |
| Edge | Charcoal Edge | Grainy layered noise with per-frame flicker, like charcoal strokes. |
| Edge | Chalk Edge | Broken chalky edge; short runs shift sideways off the line. |
| Edge | Crayon Edge | Waxy low-frequency lateral wobble, like crayon pressure. |
| Edge | Dry Brush Edge | Streaks dragged along the outline tangent, like a dry brush. |
| Edge | Spray Edge | Outward-only fuzz spikes, like spray paint bleed. |
| Edge | Living Edge | Edge noise crawls along the outline instead of boiling in place. |
| Edge | Electric Edge | Sharp lightning zigzags flickering along the outline. |
| Edge | Fur Edge | Dense swaying hair spikes along the outline. |
| Edge | Frost Edge | Angular crystalline jitter with sparkle flicker. |
| Edge | Torn Edge | Sparse deep tears rip the outline, like torn paper. |
| Edge | Postage Stamp | Regular semicircular perforations along the outline. |
| Edge | Cloud Edge | Bulbous rounded lobes swell outward along the outline. |
| Edge | Thorn Edge | Sparse long thorn spikes grow outward. |
| Edge | Scallop Edge | Regular scalloped arcs along the outline. |
| Edge | Bubble Edge | Foamy bubbles keep swelling and popping along the edge. |
| Ink | Ink Spread In | Ink soaks outward along the outline normals until it lands. |
| Ink | Ink Dry Out | The outline dries and crumbles inward as it leaves. |
| Ink | Wet Ink | Wet ink swells and settles cyclically while wobbling. |
| Ink | Watercolor Bloom In | Blotchy lobed blooming into place, like watercolor on paper. |
| Ink | Ink Absorb Out | The shape sinks and shrinks as paper absorbs it. |
| Ink | Smoke Away Out | The outline drifts upward and swirls apart like smoke. |
| Ink | Steam Rise | Gentle rising shimmer lobes, like steam off the shape. |
| Ink | Burn Away Out | A burn front eats the shape from one side with ember flicker. |
| Ink | Boil Away Out | Boils harder and harder until it evaporates upward. |
| Ink | Bleed Through In | Ink bleeds in from scattered seed patches along the outline. |
| Ink | Frost Creep In | Crystalline frost creeps over the outline into place. |
| Drip | Ink Drip | Discrete drip fingers grow from the lower outline. |
| Drip | Bottom Drips | Heavier drips pull from the bottom edge. |
| Drip | Side Drips | Drips run sideways off the outer edges. |
| Drip | Falling Stain | The whole outline smears downward into a falling stain. |
| Drip | Melt Down | Melts downward and pools on an invisible floor. |
| Drip | Diagonal Melt | Melts diagonally, dragging sideways while it sags. |
| Drip | Rain Wash | Vertical streak columns wash the shape downward. |
| Drip | Slime Stretch | Lower outline stretches like slime and recoils, cyclically. |
| Drip | Slime Snap In | Enters overstretched like slime and snaps into shape. |
| Drip | Puddle Expansion | The lower part spreads out into a widening puddle. |
| Drip | Icicle Growth | Icicle spikes grow downward from the lower outline. |
| Drip | Candle Melt | Slow cyclic sag and recovery, like softening candle wax. |
| Drip | Drip Loop | Drip fingers form, fall and reset every period. |
| Path | Wave Along Path | A wave travels along the outline arc length itself. |
| Path | Traveling Bulge | A single lump laps the outline each period, like a swallowed pulse. |
| Path | Peristalsis | Several lumps crawl along the outline in sequence. |
| Path | Path Flow | Points advect along the outline tangent; the contour crawls over itself. |
| Path | Snake Run | One visible segment laps the outline like a snake. |
| Path | Snake Chase | Two segments chase each other around the outline in opposite phase. |
| Path | Dash March | The outline becomes marching dashes, ant-trail style. |
| Path | Dotted March | The outline becomes marching dots. |
| Path | Morse Flicker | Random dash-dot patterns retile the outline every beat. |
| Path | Segment Flicker | Random outline segments cut out per frame, like a failing neon sign. |
| Path | Path Retract | A running segment grows and shrinks while lapping the outline. |
| Path | Crawl Bugs | Many short wiggling dashes crawl along the outline. |
| Reveal | Stroke Reveal In | Every contour draws itself on in parallel. |
| Reveal | Stroke Reveal Out | Every contour erases itself in parallel. |
| Reveal | Handwriting Reveal In | Contours draw on one after another by arc length, like real writing. |
| Reveal | Handwriting Reveal Out | Contours erase sequentially, unwriting the drawing. |
| Reveal | Segment Pop In | Path chunks pop on in drawing order, stepped. |
| Reveal | Segment Pop Out | Path chunks pop off in drawing order, stepped. |
| Reveal | Random Segment In | Randomized outline segments accumulate until the drawing completes. |
| Reveal | Random Segment Out | Randomized outline segments drop until nothing remains. |
| Reveal | Dash Reveal In | A dash pattern whose gaps close until the outline is solid. |
| Reveal | Dash Reveal Out | Gaps open across the outline until it dissolves into dashes. |
| Reveal | Organic Wipe In | Directional wipe with an irregular organic frontier. |
| Reveal | Organic Wipe Out | Directional wipe-out with an irregular organic frontier. |
| Reveal | Wavy Wipe In | Directional wipe with a sine-wave frontier. |
| Reveal | Wavy Wipe Out | Directional wipe-out with a sine-wave frontier. |
| Reveal | Shaky Wipe In | Wipe whose frontier trembles every frame. |
| Reveal | Shaky Wipe Out | Wipe-out whose frontier trembles every frame. |
| Reveal | Ink Wipe In | Wipe with long ink fingers reaching ahead of the frontier. |
| Reveal | Ink Wipe Out | Wipe-out with trailing ink fingers. |
| Reveal | Iris Reveal In | Radial reveal expanding from an adjustable center. |
| Reveal | Iris Reveal Out | Radial collapse toward an adjustable center. |
| Reveal | Swirl Wipe In | Angular sweep reveal with points swirling onto the frontier. |
| Reveal | Swirl Wipe Out | Angular sweep erase with points swirling off the frontier. |
| Reveal | Diagonal Wipe In | Wipe along the diagonal with a soft collapsing frontier. |
| Reveal | Diagonal Wipe Out | Wipe-out along the diagonal with a soft collapsing frontier. |
| Dissolve | Noise Dissolve In | Points condense from noise-scattered clusters into the drawing. |
| Dissolve | Noise Dissolve Out | Points scatter into noise clusters until the drawing dissolves. |
| Dissolve | Erode In | The shape rebuilds from an eroded crumble. |
| Dissolve | Erode Out | Noise erodes the shape inward until it crumbles away. |
| Dissolve | Split Wipe In | Opens from the center line outward to both sides. |
| Dissolve | Split Wipe Out | Closes from both sides into the center line. |
| Dissolve | Band Dissolve In | Alternating bands slide into place from opposite sides. |
| Dissolve | Band Dissolve Out | Alternating bands slide apart to opposite sides. |
| Dissolve | Checker Dissolve In | Grid cells assemble in a staggered checkerboard order. |
| Dissolve | Checker Dissolve Out | Grid cells collapse in a staggered checkerboard order. |
| Dissolve | Crystallize In | Enters as coarse crystal facets that refine into the drawing. |
| Dissolve | Crystallize Out | Coordinates snap to coarser and coarser crystal facets. |
| Fold | Accordion Fold In | Unfolds from compressed zigzag pleats. |
| Fold | Accordion Fold Out | Compresses into zigzag pleats toward one edge. |
| Fold | Roll In | Unrolls from a cylinder rolled at one edge. |
| Fold | Roll Out | Rolls up into a cylinder toward one edge. |
| Fold | Twist Collapse In | Untwists from a corkscrew along the axis into place. |
| Fold | Twist Collapse Out | Twists into a corkscrew along the axis and collapses. |
| Fold | Fan Unfold In | Opens like fan blades rotating from a corner pivot. |
| Fold | Fan Fold Out | Folds shut like fan blades into a corner pivot. |
| Fold | Blinds In | Venetian slats rotate open into the drawing. |
| Fold | Blinds Out | Venetian slats rotate shut and flatten the drawing. |
| Fold | Crumple In | Uncrumples from a balled-up wad into the drawing. |
| Fold | Crumple Out | Crumples into a balled-up wad along random creases. |
| Impact | Jelly Impact In | Drops in and rings out with damped jelly wobbles. |
| Impact | Jelly Release Out | Starts ringing and springs away like released jelly. |
| Impact | Radial Burst Out | Every point flies straight out from the center. |
| Impact | Radial Gather In | Points fly in from far outside and lock into the drawing. |
| Impact | Vortex In | Points spiral inward from a wide orbit into place. |
| Impact | Vortex Out | Points spiral outward into a widening orbit. |
| Impact | Gravity Sag Out | The shape progressively sags and slumps downward. |
| Impact | Gravity Recover In | Starts slumped and straightens up into the drawing. |
| Impact | Wind Sweep Out | Wind shears the shape apart toward the chosen direction. |
| Impact | Wind Settle In | Blown-away tatters settle back against the wind. |
| Impact | Shiver In | Arrives trembling; the shiver dies down as it settles. |
| Impact | Shiver Out | A growing shiver shakes the shape apart. |
| Impact | Slam Shock In | Slams into place and fires one shock ring outward. |
| Impact | Kickback Out | Recoils opposite the direction, then snaps away along it. |
| Contour | Contour Bob | Each contour bobs up and down with its own phase. |
| Contour | Contour Sway | Each contour rocks around its own centroid. |
| Contour | Contour Orbit | Each contour circles a tiny orbit, phase-staggered. |
| Contour | Contour Breathe | Each contour pulses around its own centroid, staggered. |
| Contour | Contour Wave | A lift wave travels across the contours, stadium-wave style. |
| Contour | Contour Heartbeat | Contours thump with a double-beat pulse in sequence. |
| Contour | Contour Jolt | Random contours jump to offset positions each beat. |
| Contour | Contour Blink | Random contours cut out per beat, like broken sign letters. |
| Contour | Contour Carousel | Contours ride a slow circular conga around their positions. |
| Contour | Contour Pop In | Contours pop in from zero scale with overshoot, staggered. |
| Contour | Contour Pop Out | Contours shrink away to zero scale, staggered. |
| Contour | Contour Drop In | Contours fall in from above and bounce into place. |
| Contour | Contour Drop Out | Contours drop off the layout downward, staggered. |
| Contour | Contour Slide In | Contours slide in from the chosen direction, staggered. |
| Contour | Contour Slide Out | Contours slide out toward the chosen direction, staggered. |
| Contour | Contour Spin In | Contours spin in from a full rotation, staggered. |
| Contour | Contour Spin Out | Contours spin away, alternating turn directions. |
| Contour | Contour Scatter In | Contours fly in from random directions and rotations. |
| Contour | Contour Scatter Out | Contours scatter to random directions and rotations. |
| Contour | Contour Flip In | Contours flip in edge-on like turning cards, staggered. |
| Contour | Contour Flip Out | Contours flip away edge-on like turning cards. |
| Contour | Contour Zoom In | Contours zoom down from oversized into place, staggered. |
| Contour | Contour Zoom Out | Contours blow up past the camera, staggered. |
| Contour | Contour Typewriter In | Contours appear one by one in order, typewriter style. |
| Contour | Contour Typewriter Out | Contours vanish one by one in order. |
| Contour | Contour Domino In | Contours tip upright in sequence like falling dominoes reversed. |
| Contour | Contour Domino Out | Contours tip over in sequence like falling dominoes. |
| Shatter | Shatter Out | The filled shape breaks into spinning shards that burst outward. |
| Shatter | Shatter In | Spinning shards fly in and assemble the filled shape. |
| Shatter | Crumble Down | Shards break loose and pile up on an invisible floor. |
| Shatter | Sand Blow Out | Grains blow away along the direction, front edge first. |
| Shatter | Sand Assemble In | Grains blow in along the direction and settle into the shape. |
| Shatter | Dust Float Out | Particles float up and drift apart like dust. |
| Shatter | Dust Settle In | Floating dust sinks and settles into the shape. |
| Shatter | Swarm Out | Particles spiral away like a startled swarm. |
| Shatter | Swarm In | A swarm spirals in and condenses into the shape. |
| Shatter | Splash Out | Droplets launch on ballistic arcs and fall away. |
| Shatter | Confetti Rain In | Pieces rain down from above and land into the shape. |
| Shatter | Ember Drift | Particles keep lifting off and rising like embers, cyclically. |
| Shatter | Ash Fall Out | The top edge flakes off first; ash flakes tumble down. |
| Glitch | Corrupt Contour | Short random coordinate bursts corrupt the outline per beat. |
| Glitch | Torn Static | Ragged shear bursts with jagged torn edges, analog-static style. |
| Glitch | Interlace Weave | Odd and even scan rows shear in opposite directions. |
| Glitch | Spike Burst | Random single vertices spike out hard for a frame. |
| Glitch | Dropout Holes | Random point clusters collapse per beat, punching holes. |
| Glitch | Quantize Pulse | Coordinates snap to an oscillating grid, crystal-glitch style. |
| Glitch | Vertex Storm | Vertices locally swap and churn positions every frame. |
| Sketch | Sketch Passes | Stacked jittered pencil passes with blur and alpha. |
| Sketch | Scribble Passes | Rougher stacked scribble passes with stronger offsets. |
