export script_name        = "Zagreo Glyphs"
export script_description = "Generate vector-path glyph animation moments from ASS text or drawings"
export script_author      = "Kiterow"
export script_version     = "1.2.4"
export script_namespace   = "kite.ZagreoGlyphs"

ConfigFile = "kite-zagreo-glyphs.json"

local LineCollection, Line, ASS, Core, configHandler, KiteUI, LineOps, Yutils, AssContext, AssDrawing, depctrl
DependencyControl = require "l0.DependencyControl"
depctrl = DependencyControl{
  feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"
  {
    {"a-mo.LineCollection", version: "1.3.0", url: "https://github.com/TypesettingTools/Aegisub-Motion",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"}
    {"a-mo.Line", version: "1.5.3", url: "https://github.com/TypesettingTools/Aegisub-Motion",
      feed: "https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json"}
    {"l0.ASSFoundation", version: "0.5.0", url: "https://github.com/TypesettingTools/ASSFoundation",
      feed: "https://raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json"}
    {"kite.Core", version: "1.1.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.UI", version: "1.5.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.LineOps", version: "1.7.0", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    "Yutils"
    {"kite.AssContext", version: "1.1.3"}
    {"kite.AssDrawing", version: "1.0.3"}
  }
}
LineCollection, Line, ASS, Core, KiteUI, LineOps, Yutils, AssContext, AssDrawing = depctrl\requireModules!
configHandler = (interface, fileName, _, version) ->
  KiteUI.dialogHandler interface, script_namespace, version, {
    {path: "?user/" .. fileName, format: "json_sections"}
  }

EffectMeta = {}
addEffect = (name, category, help, spec) ->
  EffectMeta[#EffectMeta + 1] = {name, category, help, spec}

addEffect "Font Morph", "Morph", "Text becomes the same text in another font through vector in-betweens.", {kind: "morph"}
addEffect "Font Morph Elastic", "Morph", "Font morph with overshoot and recoil.", {kind: "morph", elastic: true}
addEffect "Font Morph Overshoot", "Morph", "Pushes the shape past the target font before settling.", {kind: "morph", curve: "overshoot"}
addEffect "Font Morph Anticipation", "Morph", "Backs away briefly before morphing into the target font.", {kind: "morph", curve: "anticipation"}
addEffect "Font Morph Bounce", "Morph", "Morphs with a bouncing final approach.", {kind: "morph", curve: "bounce"}
addEffect "Font Morph Steps", "Morph", "Stepped vector states between fonts.", {kind: "morph", curve: "steps"}
addEffect "Font Morph Glitch", "Morph", "Morphs while corrupting intermediate coordinates.", {kind: "morph", curve: "glitch"}
addEffect "Font Morph Rubber", "Morph", "Stretches the in-between shape like elastic material.", {kind: "morph", curve: "rubber"}
addEffect "Pair Morph", "Morph", "Morphs the first selected line into the second selected line.", {kind: "pair_morph"}
addEffect "Pair Morph Elastic", "Morph", "Selected-line morph with overshoot and recoil.", {kind: "pair_morph", elastic: true}
addEffect "Pair Morph Overshoot", "Morph", "Selected-line morph passing the target before settling.", {kind: "pair_morph", curve: "overshoot"}
addEffect "Pair Morph Bounce", "Morph", "Selected-line morph with a bouncing approach.", {kind: "pair_morph", curve: "bounce"}
addEffect "Blob Morph In", "Morph", "Each contour enters as a round blob and resolves into the drawing.", {kind: "shape_morph", mode: "blob", phase: "in"}
addEffect "Blob Morph Out", "Morph", "Contours relax into round blobs and leave.", {kind: "shape_morph", mode: "blob", phase: "out"}
addEffect "Blob Pulse", "Morph", "Contours cyclically soften toward blobs and back, lava-lamp style.", {kind: "shape_morph", mode: "blob", d: {period: 1400}}
addEffect "Line Sweep In", "Morph", "Contours unfold from flat horizontal strokes into the drawing.", {kind: "shape_morph", mode: "line", phase: "in"}
addEffect "Line Sweep Out", "Morph", "Contours collapse into flat horizontal strokes.", {kind: "shape_morph", mode: "line", phase: "out"}
addEffect "Spike Morph In", "Morph", "Contours enter as star bursts and settle into the drawing.", {kind: "shape_morph", mode: "star", phase: "in", d: {frequency: 5}}
addEffect "Spike Morph Out", "Morph", "Contours sharpen into star bursts and leave.", {kind: "shape_morph", mode: "star", phase: "out", d: {frequency: 5}}
addEffect "Scribble Morph In", "Morph", "Contours enter as loose scribbles that tighten into the drawing.", {kind: "shape_morph", mode: "scribble", phase: "in", d: {seed: 77}}
addEffect "Scribble Morph Out", "Morph", "Contours unravel into loose scribbles.", {kind: "shape_morph", mode: "scribble", phase: "out", d: {seed: 77}}

addEffect "Boiling Line", "Surface", "Constant organic boil over every path point, period-locked.", {kind: "field", mode: "boil", d: {strength: 5, period: 280, noise_scale: 55}}
addEffect "Electric Jitter", "Surface", "Hard unsmoothed per-frame jitter, like electric interference.", {kind: "field", mode: "electric", d: {strength: 4, period: 120}}
addEffect "Handwriting Noise", "Surface", "Slow hand-drawn wobble of the whole outline.", {kind: "field", mode: "handwriting", d: {strength: 6, period: 900, noise_scale: 140}}
addEffect "Ink Wobble", "Surface", "Loose sine sway over the vector outline.", {kind: "field", mode: "wobble", d: {strength: 5, period: 1100}}
addEffect "Fine Contour Jitter", "Surface", "Small fast per-point contour jitter.", {kind: "field", mode: "fine_jitter", d: {strength: 3, period: 200}}
addEffect "Coarse Zone Jitter", "Surface", "Chunky zone-based jitter; whole regions jump together.", {kind: "field", mode: "coarse_jitter", d: {strength: 8, period: 260, noise_scale: 90}}
addEffect "Organic Drift", "Surface", "Slow wandering deformation that never repeats.", {kind: "field", mode: "drift", d: {strength: 10, period: 2400, noise_scale: 160}}
addEffect "Heat Haze", "Surface", "Upward-drifting shimmer bands, like air over fire.", {kind: "field", mode: "heat", d: {strength: 7, period: 700, frequency: 4}}
addEffect "Water Flow", "Surface", "Sideways-advecting refraction wobble.", {kind: "field", mode: "water", d: {strength: 8, period: 1600, frequency: 3}}
addEffect "Gelatin Wobble", "Surface", "Springy low-frequency jiggle with damped recoil.", {kind: "field", mode: "gelatin", d: {strength: 10, period: 1000, frequency: 2}}
addEffect "Underwater Sway", "Surface", "Big slow current sway plus fine refraction.", {kind: "field", mode: "underwater", d: {strength: 12, period: 2200, frequency: 1.5}}
addEffect "Windblown Turbulence", "Surface", "Directional gusts ripping at the outline in bursts.", {kind: "field", mode: "windblown", dir: true, d: {strength: 10, period: 800, noise_scale: 110}}
addEffect "Static Buzz", "Surface", "One-frame alternating offsets, like TV static tremble.", {kind: "field", mode: "buzz", d: {strength: 2.5, period: 80}}

addEffect "Wave Horizontal", "Wave", "Traveling horizontal wave running through the drawing.", {kind: "field", mode: "wave_h", d: {strength: 10, frequency: 2, period: 900}}
addEffect "Wave Vertical", "Wave", "Traveling vertical wave running through the drawing.", {kind: "field", mode: "wave_v", d: {strength: 10, frequency: 2, period: 900}}
addEffect "Wave Diagonal", "Wave", "Traveling diagonal wave running through the drawing.", {kind: "field", mode: "wave_d", d: {strength: 10, frequency: 2, period: 900}}
addEffect "Standing Wave", "Wave", "Standing wave with fixed nodes and swinging antinodes.", {kind: "field", mode: "wave_standing", d: {strength: 10, frequency: 3, period: 900}}
addEffect "Flag Wave", "Wave", "Wave whose amplitude grows away from the anchored edge, like a flag.", {kind: "field", mode: "flag", dir: true, d: {strength: 14, frequency: 2, period: 800}}
addEffect "Skip Rope", "Wave", "Whole shape swings like a rope anchored at both ends.", {kind: "field", mode: "skiprope", d: {strength: 18, period: 1000}}
addEffect "Seaweed Sway", "Wave", "Anchored at the bottom, sways more toward the top.", {kind: "field", mode: "seaweed", d: {strength: 12, period: 1600}}
addEffect "Twist Wave", "Wave", "Local rotation angle waves along the axis, like a twisting ribbon.", {kind: "field", mode: "twist_wave", dir: true, d: {strength: 30, frequency: 1.5, period: 1400}}
addEffect "Whip Crack", "Wave", "A single amplitude spike whips through the shape once per period.", {kind: "field", mode: "whip", dir: true, d: {strength: 16, period: 1200}}
addEffect "Ripple Center", "Wave", "Circular ripple radiating from the drawing center.", {kind: "field", mode: "ripple", d: {strength: 8, frequency: 3, period: 900}}
addEffect "Ripple Point", "Wave", "Circular ripple from an adjustable off-center origin.", {kind: "field", mode: "ripple_point", off: true, d: {strength: 8, frequency: 3, period: 900, x_offset: -30, y_offset: -20}}
addEffect "Ripple Rain", "Wave", "New ripple origins keep appearing at random spots.", {kind: "field", mode: "ripple_rain", d: {strength: 7, frequency: 4, period: 700}}
addEffect "Cross Ripple", "Wave", "Two ripple origins interfering across the shape.", {kind: "field", mode: "ripple_cross", off: true, d: {strength: 7, frequency: 3, period: 900, x_offset: -35, y_offset: 35}}
addEffect "Bounce Wave", "Wave", "Rectified wave; crests bounce instead of swinging through.", {kind: "field", mode: "wave_bounce", d: {strength: 12, frequency: 2, period: 800}}
addEffect "Wave Settle In", "Wave", "Enters waving hard, then the wave dies down to the clean shape.", {kind: "field", mode: "wave_h", phase: "in", d: {strength: 16, frequency: 2, period: 700}}
addEffect "Wave Break Out", "Wave", "The wave grows until it breaks the shape apart on exit.", {kind: "field", mode: "wave_h", phase: "out", d: {strength: 22, frequency: 2, period: 700}}

addEffect "Twist Sway", "Radial", "The shape twists back and forth around its center.", {kind: "field", mode: "twist_sway", d: {strength: 20, period: 1300}}
addEffect "Vortex Swirl", "Radial", "Continuous circulation around the center with radial falloff.", {kind: "field", mode: "vortex_swirl", d: {strength: 14, period: 1600}}
addEffect "Magnet Pulse", "Radial", "An off-center attractor pulls the outline in pulses.", {kind: "field", mode: "magnet", off: true, d: {strength: 14, period: 1100, x_offset: -25, y_offset: -10}}
addEffect "Pinch Pulse", "Radial", "The shape rhythmically pinches toward its center.", {kind: "field", mode: "pinch_pulse", d: {strength: 25, period: 1000}}
addEffect "Bulge Pulse", "Radial", "The shape rhythmically bulges outward from its center.", {kind: "field", mode: "bulge_pulse", d: {strength: 25, period: 1000}}
addEffect "Heartbeat", "Radial", "Double-thump radial pulse per period, like a heartbeat.", {kind: "field", mode: "heartbeat_r", d: {strength: 18, period: 1200}}
addEffect "Spring Boing", "Radial", "Squash-and-stretch spring bounce with damped recoil.", {kind: "field", mode: "spring", d: {strength: 20, period: 900}}
addEffect "Lens Sweep", "Radial", "A magnifying bulge sweeps across the shape each period.", {kind: "field", mode: "lens", off: true, d: {strength: 30, period: 1500}}
addEffect "Shockwave", "Radial", "A displacement ring travels outward once per period.", {kind: "field", mode: "shock", d: {strength: 14, period: 1300}}
addEffect "Pulse Rings", "Radial", "Concentric rings breathe in alternating directions.", {kind: "field", mode: "rings", d: {strength: 6, frequency: 4, period: 900}}
addEffect "Lag Orbit", "Radial", "The shape orbits a small circle; inner points lag behind, jelly-like.", {kind: "field", mode: "lag_orbit", d: {strength: 10, period: 1000}}

addEffect "Rough Edge", "Edge", "Multi-octave roughening along the outline normal.", {kind: "field", mode: "rough", d: {strength: 5, noise_scale: 30, period: 600}}
addEffect "Rough Edge Progressive", "Edge", "Rough edge grows from clean to fully rough over the line.", {kind: "field", mode: "rough", env: "grow", d: {strength: 7, noise_scale: 30, period: 600}}
addEffect "Rough Edge Calming", "Edge", "Rough edge settles down to clean over the line.", {kind: "field", mode: "rough", env: "fade", d: {strength: 7, noise_scale: 30, period: 600}}
addEffect "Serrated Edge", "Edge", "Regular symmetric saw teeth along the outline.", {kind: "field", mode: "serrate", d: {strength: 5, frequency: 26, period: 1200}}
addEffect "Sawtooth Edge", "Edge", "Asymmetric leaning teeth along the outline.", {kind: "field", mode: "sawtooth", d: {strength: 6, frequency: 22, period: 1200}}
addEffect "Bitten Edge", "Edge", "A few deep smooth bites dent the outline.", {kind: "field", mode: "bitten", d: {strength: 9, frequency: 7, period: 1600}}
addEffect "Corroded Edge", "Edge", "High-frequency inward pitting, like rust eating the edge.", {kind: "field", mode: "corrode", d: {strength: 6, noise_scale: 14, period: 900}}
addEffect "Charcoal Edge", "Edge", "Grainy layered noise with per-frame flicker, like charcoal strokes.", {kind: "field", mode: "charcoal", d: {strength: 5, noise_scale: 20, period: 180}}
addEffect "Chalk Edge", "Edge", "Broken chalky edge; short runs shift sideways off the line.", {kind: "field", mode: "chalk", d: {strength: 5, frequency: 30, period: 700}}
addEffect "Crayon Edge", "Edge", "Waxy low-frequency lateral wobble, like crayon pressure.", {kind: "field", mode: "crayon", d: {strength: 4, frequency: 8, period: 1000}}
addEffect "Dry Brush Edge", "Edge", "Streaks dragged along the outline tangent, like a dry brush.", {kind: "field", mode: "drybrush", d: {strength: 7, noise_scale: 24, period: 800}}
addEffect "Spray Edge", "Edge", "Outward-only fuzz spikes, like spray paint bleed.", {kind: "field", mode: "spray", d: {strength: 8, noise_scale: 10, period: 300}}
addEffect "Living Edge", "Edge", "Edge noise crawls along the outline instead of boiling in place.", {kind: "field", mode: "living", d: {strength: 6, frequency: 8, period: 800}}
addEffect "Electric Edge", "Edge", "Sharp lightning zigzags flickering along the outline.", {kind: "field", mode: "electric_edge", d: {strength: 8, frequency: 18, period: 140}}
addEffect "Fur Edge", "Edge", "Dense swaying hair spikes along the outline.", {kind: "field", mode: "fur", d: {strength: 9, frequency: 40, period: 900}}
addEffect "Frost Edge", "Edge", "Angular crystalline jitter with sparkle flicker.", {kind: "field", mode: "frost", d: {strength: 6, frequency: 24, period: 400}}
addEffect "Torn Edge", "Edge", "Sparse deep tears rip the outline, like torn paper.", {kind: "field", mode: "torn", d: {strength: 14, frequency: 5, period: 1400}}
addEffect "Postage Stamp", "Edge", "Regular semicircular perforations along the outline.", {kind: "field", mode: "stamp", d: {strength: 6, frequency: 18, period: 2000}}
addEffect "Cloud Edge", "Edge", "Bulbous rounded lobes swell outward along the outline.", {kind: "field", mode: "cloud", d: {strength: 10, frequency: 8, period: 1800}}
addEffect "Thorn Edge", "Edge", "Sparse long thorn spikes grow outward.", {kind: "field", mode: "thorn", d: {strength: 16, frequency: 9, period: 1600}}
addEffect "Scallop Edge", "Edge", "Regular scalloped arcs along the outline.", {kind: "field", mode: "scallop", d: {strength: 7, frequency: 14, period: 2000}}
addEffect "Bubble Edge", "Edge", "Foamy bubbles keep swelling and popping along the edge.", {kind: "field", mode: "bubble", d: {strength: 8, frequency: 12, period: 600}}

addEffect "Ink Spread In", "Ink", "Ink soaks outward along the outline normals until it lands.", {kind: "field", mode: "spread", phase: "in", d: {strength: 10}}
addEffect "Ink Dry Out", "Ink", "The outline dries and crumbles inward as it leaves.", {kind: "field", mode: "dry", phase: "out", d: {strength: 10}}
addEffect "Wet Ink", "Ink", "Wet ink swells and settles cyclically while wobbling.", {kind: "field", mode: "wet", d: {strength: 7, period: 1200}}
addEffect "Watercolor Bloom In", "Ink", "Blotchy lobed blooming into place, like watercolor on paper.", {kind: "field", mode: "bloom", phase: "in", d: {strength: 14, frequency: 5}}
addEffect "Ink Absorb Out", "Ink", "The shape sinks and shrinks as paper absorbs it.", {kind: "field", mode: "absorb", phase: "out", d: {strength: 12}}
addEffect "Smoke Away Out", "Ink", "The outline drifts upward and swirls apart like smoke.", {kind: "field", mode: "smoke", phase: "out", d: {strength: 26, noise_scale: 70}}
addEffect "Steam Rise", "Ink", "Gentle rising shimmer lobes, like steam off the shape.", {kind: "field", mode: "steam", d: {strength: 8, period: 1500}}
addEffect "Burn Away Out", "Ink", "A burn front eats the shape from one side with ember flicker.", {kind: "field", mode: "burn", phase: "out", dir: true, d: {strength: 12}}
addEffect "Boil Away Out", "Ink", "Boils harder and harder until it evaporates upward.", {kind: "field", mode: "boiloff", phase: "out", d: {strength: 14, period: 300}}
addEffect "Bleed Through In", "Ink", "Ink bleeds in from scattered seed patches along the outline.", {kind: "field", mode: "bleed", phase: "in", d: {strength: 12, frequency: 6}}
addEffect "Frost Creep In", "Ink", "Crystalline frost creeps over the outline into place.", {kind: "field", mode: "frost_creep", phase: "in", d: {strength: 8, frequency: 20}}

addEffect "Ink Drip", "Drip", "Discrete drip fingers grow from the lower outline.", {kind: "field", mode: "drip", env: "grow", d: {strength: 26, frequency: 7}}
addEffect "Bottom Drips", "Drip", "Heavier drips pull from the bottom edge.", {kind: "field", mode: "bottom", env: "grow", d: {strength: 34, frequency: 6}}
addEffect "Side Drips", "Drip", "Drips run sideways off the outer edges.", {kind: "field", mode: "side", env: "grow", d: {strength: 26, frequency: 7}}
addEffect "Falling Stain", "Drip", "The whole outline smears downward into a falling stain.", {kind: "field", mode: "stain", env: "grow", d: {strength: 40}}
addEffect "Melt Down", "Drip", "Melts downward and pools on an invisible floor.", {kind: "field", mode: "melt", env: "grow", d: {strength: 50}}
addEffect "Diagonal Melt", "Drip", "Melts diagonally, dragging sideways while it sags.", {kind: "field", mode: "melt_diag", env: "grow", d: {strength: 45}}
addEffect "Rain Wash", "Drip", "Vertical streak columns wash the shape downward.", {kind: "field", mode: "rainwash", env: "grow", d: {strength: 36, frequency: 9}}
addEffect "Slime Stretch", "Drip", "Lower outline stretches like slime and recoils, cyclically.", {kind: "field", mode: "slime", d: {strength: 30, period: 1400}}
addEffect "Slime Snap In", "Drip", "Enters overstretched like slime and snaps into shape.", {kind: "field", mode: "slime_snap", phase: "in", d: {strength: 36}}
addEffect "Puddle Expansion", "Drip", "The lower part spreads out into a widening puddle.", {kind: "field", mode: "puddle", env: "grow", d: {strength: 30}}
addEffect "Icicle Growth", "Drip", "Icicle spikes grow downward from the lower outline.", {kind: "field", mode: "icicle", env: "grow", d: {strength: 24, frequency: 8}}
addEffect "Candle Melt", "Drip", "Slow cyclic sag and recovery, like softening candle wax.", {kind: "field", mode: "candle", d: {strength: 18, period: 2600}}
addEffect "Drip Loop", "Drip", "Drip fingers form, fall and reset every period.", {kind: "field", mode: "drip_loop", d: {strength: 28, frequency: 6, period: 1600}}

addEffect "Wave Along Path", "Path", "A wave travels along the outline arc length itself.", {kind: "field", mode: "path_wave", d: {strength: 6, frequency: 6, period: 900}}
addEffect "Traveling Bulge", "Path", "A single lump laps the outline each period, like a swallowed pulse.", {kind: "field", mode: "path_bulge", d: {strength: 10, period: 1400}}
addEffect "Peristalsis", "Path", "Several lumps crawl along the outline in sequence.", {kind: "field", mode: "path_peristalsis", d: {strength: 8, frequency: 4, period: 1200}}
addEffect "Path Flow", "Path", "Points advect along the outline tangent; the contour crawls over itself.", {kind: "field", mode: "path_flow", d: {strength: 8, period: 1000}}
addEffect "Snake Run", "Path", "One visible segment laps the outline like a snake.", {kind: "subpath", mode: "snake", d: {strength: 30, period: 1600}}
addEffect "Snake Chase", "Path", "Two segments chase each other around the outline in opposite phase.", {kind: "subpath", mode: "snake_chase", d: {strength: 24, period: 1600}}
addEffect "Dash March", "Path", "The outline becomes marching dashes, ant-trail style.", {kind: "subpath", mode: "dash_march", d: {frequency: 9, period: 1000}}
addEffect "Dotted March", "Path", "The outline becomes marching dots.", {kind: "subpath", mode: "dot_march", d: {frequency: 22, period: 1000, strength: 4}}
addEffect "Morse Flicker", "Path", "Random dash-dot patterns retile the outline every beat.", {kind: "subpath", mode: "morse", d: {frequency: 10, period: 400}}
addEffect "Segment Flicker", "Path", "Random outline segments cut out per frame, like a failing neon sign.", {kind: "subpath", mode: "seg_flicker", d: {period: 160}}
addEffect "Path Retract", "Path", "A running segment grows and shrinks while lapping the outline.", {kind: "subpath", mode: "path_retract", d: {period: 1800}}
addEffect "Crawl Bugs", "Path", "Many short wiggling dashes crawl along the outline.", {kind: "subpath", mode: "crawl", d: {frequency: 14, period: 900, strength: 3}}

addEffect "Stroke Reveal In", "Reveal", "Every contour draws itself on in parallel.", {kind: "subpath", mode: "prefix_parallel", phase: "in"}
addEffect "Stroke Reveal Out", "Reveal", "Every contour erases itself in parallel.", {kind: "subpath", mode: "prefix_parallel", phase: "out"}
addEffect "Handwriting Reveal In", "Reveal", "Contours draw on one after another by arc length, like real writing.", {kind: "subpath", mode: "prefix_sequential", phase: "in"}
addEffect "Handwriting Reveal Out", "Reveal", "Contours erase sequentially, unwriting the drawing.", {kind: "subpath", mode: "prefix_sequential", phase: "out"}
addEffect "Segment Pop In", "Reveal", "Path chunks pop on in drawing order, stepped.", {kind: "subpath", mode: "prefix_chunk", phase: "in", d: {frequency: 8}}
addEffect "Segment Pop Out", "Reveal", "Path chunks pop off in drawing order, stepped.", {kind: "subpath", mode: "prefix_chunk", phase: "out", d: {frequency: 8}}
addEffect "Random Segment In", "Reveal", "Randomized outline segments accumulate until the drawing completes.", {kind: "subpath", mode: "prefix_random", phase: "in"}
addEffect "Random Segment Out", "Reveal", "Randomized outline segments drop until nothing remains.", {kind: "subpath", mode: "prefix_random", phase: "out"}
addEffect "Dash Reveal In", "Reveal", "A dash pattern whose gaps close until the outline is solid.", {kind: "subpath", mode: "prefix_dash", phase: "in", d: {frequency: 12}}
addEffect "Dash Reveal Out", "Reveal", "Gaps open across the outline until it dissolves into dashes.", {kind: "subpath", mode: "prefix_dash", phase: "out", d: {frequency: 12}}
addEffect "Organic Wipe In", "Reveal", "Directional wipe with an irregular organic frontier.", {kind: "field", mode: "wipe_organic", phase: "in", dir: true, d: {strength: 60}}
addEffect "Organic Wipe Out", "Reveal", "Directional wipe-out with an irregular organic frontier.", {kind: "field", mode: "wipe_organic", phase: "out", dir: true, d: {strength: 60}}
addEffect "Wavy Wipe In", "Reveal", "Directional wipe with a sine-wave frontier.", {kind: "field", mode: "wipe_wavy", phase: "in", dir: true, d: {strength: 50, frequency: 3}}
addEffect "Wavy Wipe Out", "Reveal", "Directional wipe-out with a sine-wave frontier.", {kind: "field", mode: "wipe_wavy", phase: "out", dir: true, d: {strength: 50, frequency: 3}}
addEffect "Shaky Wipe In", "Reveal", "Wipe whose frontier trembles every frame.", {kind: "field", mode: "wipe_shaky", phase: "in", dir: true, d: {strength: 60, period: 120}}
addEffect "Shaky Wipe Out", "Reveal", "Wipe-out whose frontier trembles every frame.", {kind: "field", mode: "wipe_shaky", phase: "out", dir: true, d: {strength: 60, period: 120}}
addEffect "Ink Wipe In", "Reveal", "Wipe with long ink fingers reaching ahead of the frontier.", {kind: "field", mode: "wipe_ink", phase: "in", dir: true, d: {strength: 80, frequency: 5}}
addEffect "Ink Wipe Out", "Reveal", "Wipe-out with trailing ink fingers.", {kind: "field", mode: "wipe_ink", phase: "out", dir: true, d: {strength: 80, frequency: 5}}
addEffect "Iris Reveal In", "Reveal", "Radial reveal expanding from an adjustable center.", {kind: "field", mode: "wipe_iris", phase: "in", off: true, d: {strength: 50}}
addEffect "Iris Reveal Out", "Reveal", "Radial collapse toward an adjustable center.", {kind: "field", mode: "wipe_iris", phase: "out", off: true, d: {strength: 50}}
addEffect "Swirl Wipe In", "Reveal", "Angular sweep reveal with points swirling onto the frontier.", {kind: "field", mode: "wipe_swirl", phase: "in", d: {strength: 60}}
addEffect "Swirl Wipe Out", "Reveal", "Angular sweep erase with points swirling off the frontier.", {kind: "field", mode: "wipe_swirl", phase: "out", d: {strength: 60}}
addEffect "Diagonal Wipe In", "Reveal", "Wipe along the diagonal with a soft collapsing frontier.", {kind: "field", mode: "wipe_diag", phase: "in", d: {strength: 50}}
addEffect "Diagonal Wipe Out", "Reveal", "Wipe-out along the diagonal with a soft collapsing frontier.", {kind: "field", mode: "wipe_diag", phase: "out", d: {strength: 50}}

addEffect "Noise Dissolve In", "Dissolve", "Points condense from noise-scattered clusters into the drawing.", {kind: "field", mode: "ds_noise", phase: "in", d: {strength: 60}}
addEffect "Noise Dissolve Out", "Dissolve", "Points scatter into noise clusters until the drawing dissolves.", {kind: "field", mode: "ds_noise", phase: "out", d: {strength: 60}}
addEffect "Erode In", "Dissolve", "The shape rebuilds from an eroded crumble.", {kind: "field", mode: "ds_erode", phase: "in", d: {strength: 30}}
addEffect "Erode Out", "Dissolve", "Noise erodes the shape inward until it crumbles away.", {kind: "field", mode: "ds_erode", phase: "out", d: {strength: 30}}
addEffect "Split Wipe In", "Dissolve", "Opens from the center line outward to both sides.", {kind: "field", mode: "ds_split", phase: "in", dir: true, d: {strength: 50}}
addEffect "Split Wipe Out", "Dissolve", "Closes from both sides into the center line.", {kind: "field", mode: "ds_split", phase: "out", dir: true, d: {strength: 50}}
addEffect "Band Dissolve In", "Dissolve", "Alternating bands slide into place from opposite sides.", {kind: "field", mode: "ds_band", phase: "in", dir: true, d: {strength: 60, frequency: 6}}
addEffect "Band Dissolve Out", "Dissolve", "Alternating bands slide apart to opposite sides.", {kind: "field", mode: "ds_band", phase: "out", dir: true, d: {strength: 60, frequency: 6}}
addEffect "Checker Dissolve In", "Dissolve", "Grid cells assemble in a staggered checkerboard order.", {kind: "field", mode: "ds_checker", phase: "in", d: {strength: 50, frequency: 5}}
addEffect "Checker Dissolve Out", "Dissolve", "Grid cells collapse in a staggered checkerboard order.", {kind: "field", mode: "ds_checker", phase: "out", d: {strength: 50, frequency: 5}}
addEffect "Crystallize In", "Dissolve", "Enters as coarse crystal facets that refine into the drawing.", {kind: "field", mode: "ds_crystal", phase: "in", d: {strength: 14}}
addEffect "Crystallize Out", "Dissolve", "Coordinates snap to coarser and coarser crystal facets.", {kind: "field", mode: "ds_crystal", phase: "out", d: {strength: 14}}

addEffect "Accordion Fold In", "Fold", "Unfolds from compressed zigzag pleats.", {kind: "field", mode: "accordion", phase: "in", dir: true, d: {frequency: 5, strength: 20}}
addEffect "Accordion Fold Out", "Fold", "Compresses into zigzag pleats toward one edge.", {kind: "field", mode: "accordion", phase: "out", dir: true, d: {frequency: 5, strength: 20}}
addEffect "Roll In", "Fold", "Unrolls from a cylinder rolled at one edge.", {kind: "field", mode: "roll", phase: "in", dir: true, d: {strength: 30}}
addEffect "Roll Out", "Fold", "Rolls up into a cylinder toward one edge.", {kind: "field", mode: "roll", phase: "out", dir: true, d: {strength: 30}}
addEffect "Twist Collapse In", "Fold", "Untwists from a corkscrew along the axis into place.", {kind: "field", mode: "twistc", phase: "in", dir: true, d: {frequency: 1.5}}
addEffect "Twist Collapse Out", "Fold", "Twists into a corkscrew along the axis and collapses.", {kind: "field", mode: "twistc", phase: "out", dir: true, d: {frequency: 1.5}}
addEffect "Fan Unfold In", "Fold", "Opens like fan blades rotating from a corner pivot.", {kind: "field", mode: "fan", phase: "in", dir: true, d: {strength: 90}}
addEffect "Fan Fold Out", "Fold", "Folds shut like fan blades into a corner pivot.", {kind: "field", mode: "fan", phase: "out", dir: true, d: {strength: 90}}
addEffect "Blinds In", "Fold", "Venetian slats rotate open into the drawing.", {kind: "field", mode: "blinds", phase: "in", dir: true, d: {frequency: 6}}
addEffect "Blinds Out", "Fold", "Venetian slats rotate shut and flatten the drawing.", {kind: "field", mode: "blinds", phase: "out", dir: true, d: {frequency: 6}}
addEffect "Crumple In", "Fold", "Uncrumples from a balled-up wad into the drawing.", {kind: "field", mode: "crumple", phase: "in", d: {frequency: 6, strength: 60}}
addEffect "Crumple Out", "Fold", "Crumples into a balled-up wad along random creases.", {kind: "field", mode: "crumple", phase: "out", d: {frequency: 6, strength: 60}}

addEffect "Jelly Impact In", "Impact", "Drops in and rings out with damped jelly wobbles.", {kind: "field", mode: "jelly", phase: "in", d: {strength: 22, frequency: 3}}
addEffect "Jelly Release Out", "Impact", "Starts ringing and springs away like released jelly.", {kind: "field", mode: "jelly", phase: "out", d: {strength: 22, frequency: 3}}
addEffect "Radial Burst Out", "Impact", "Every point flies straight out from the center.", {kind: "field", mode: "burst", phase: "out", d: {strength: 80}}
addEffect "Radial Gather In", "Impact", "Points fly in from far outside and lock into the drawing.", {kind: "field", mode: "burst", phase: "in", d: {strength: 80}}
addEffect "Vortex In", "Impact", "Points spiral inward from a wide orbit into place.", {kind: "field", mode: "vortexp", phase: "in", d: {strength: 70}}
addEffect "Vortex Out", "Impact", "Points spiral outward into a widening orbit.", {kind: "field", mode: "vortexp", phase: "out", d: {strength: 70}}
addEffect "Gravity Sag Out", "Impact", "The shape progressively sags and slumps downward.", {kind: "field", mode: "sag", phase: "out", d: {strength: 30}}
addEffect "Gravity Recover In", "Impact", "Starts slumped and straightens up into the drawing.", {kind: "field", mode: "sag", phase: "in", d: {strength: 30}}
addEffect "Wind Sweep Out", "Impact", "Wind shears the shape apart toward the chosen direction.", {kind: "field", mode: "wind", phase: "out", dir: true, d: {strength: 60}}
addEffect "Wind Settle In", "Impact", "Blown-away tatters settle back against the wind.", {kind: "field", mode: "wind", phase: "in", dir: true, d: {strength: 60}}
addEffect "Shiver In", "Impact", "Arrives trembling; the shiver dies down as it settles.", {kind: "field", mode: "shiver", phase: "in", d: {strength: 8, period: 100}}
addEffect "Shiver Out", "Impact", "A growing shiver shakes the shape apart.", {kind: "field", mode: "shiver", phase: "out", d: {strength: 8, period: 100}}
addEffect "Slam Shock In", "Impact", "Slams into place and fires one shock ring outward.", {kind: "field", mode: "slam", phase: "in", d: {strength: 26}}
addEffect "Kickback Out", "Impact", "Recoils opposite the direction, then snaps away along it.", {kind: "field", mode: "kickback", phase: "out", dir: true, d: {strength: 50}}

addEffect "Contour Bob", "Contour", "Each contour bobs up and down with its own phase.", {kind: "contour", mode: "c_bob", d: {strength: 6, period: 1000}}
addEffect "Contour Sway", "Contour", "Each contour rocks around its own centroid.", {kind: "contour", mode: "c_sway", d: {strength: 10, period: 1200}}
addEffect "Contour Orbit", "Contour", "Each contour circles a tiny orbit, phase-staggered.", {kind: "contour", mode: "c_orbit", d: {strength: 5, period: 1300}}
addEffect "Contour Breathe", "Contour", "Each contour pulses around its own centroid, staggered.", {kind: "contour", mode: "c_breathe", d: {strength: 8, period: 1400}}
addEffect "Contour Wave", "Contour", "A lift wave travels across the contours, stadium-wave style.", {kind: "contour", mode: "c_wave", dir: true, d: {strength: 12, period: 1100}}
addEffect "Contour Heartbeat", "Contour", "Contours thump with a double-beat pulse in sequence.", {kind: "contour", mode: "c_heart", d: {strength: 10, period: 1200}}
addEffect "Contour Jolt", "Contour", "Random contours jump to offset positions each beat.", {kind: "contour", mode: "c_jolt", d: {strength: 10, period: 200}}
addEffect "Contour Blink", "Contour", "Random contours cut out per beat, like broken sign letters.", {kind: "contour", mode: "c_blink", d: {period: 220}}
addEffect "Contour Carousel", "Contour", "Contours ride a slow circular conga around their positions.", {kind: "contour", mode: "c_carousel", d: {strength: 16, period: 2000}}
addEffect "Contour Pop In", "Contour", "Contours pop in from zero scale with overshoot, staggered.", {kind: "contour", mode: "c_pop", phase: "in", curve: "overshoot"}
addEffect "Contour Pop Out", "Contour", "Contours shrink away to zero scale, staggered.", {kind: "contour", mode: "c_pop", phase: "out", curve: "anticipation"}
addEffect "Contour Drop In", "Contour", "Contours fall in from above and bounce into place.", {kind: "contour", mode: "c_drop", phase: "in", curve: "bounce", d: {strength: 120}}
addEffect "Contour Drop Out", "Contour", "Contours drop off the layout downward, staggered.", {kind: "contour", mode: "c_drop", phase: "out", d: {strength: 120}}
addEffect "Contour Slide In", "Contour", "Contours slide in from the chosen direction, staggered.", {kind: "contour", mode: "c_slide", phase: "in", dir: true, d: {strength: 120}}
addEffect "Contour Slide Out", "Contour", "Contours slide out toward the chosen direction, staggered.", {kind: "contour", mode: "c_slide", phase: "out", dir: true, d: {strength: 120}}
addEffect "Contour Spin In", "Contour", "Contours spin in from a full rotation, staggered.", {kind: "contour", mode: "c_spin", phase: "in"}
addEffect "Contour Spin Out", "Contour", "Contours spin away, alternating turn directions.", {kind: "contour", mode: "c_spin", phase: "out"}
addEffect "Contour Scatter In", "Contour", "Contours fly in from random directions and rotations.", {kind: "contour", mode: "c_scatter", phase: "in", d: {strength: 140}}
addEffect "Contour Scatter Out", "Contour", "Contours scatter to random directions and rotations.", {kind: "contour", mode: "c_scatter", phase: "out", d: {strength: 140}}
addEffect "Contour Flip In", "Contour", "Contours flip in edge-on like turning cards, staggered.", {kind: "contour", mode: "c_flip", phase: "in"}
addEffect "Contour Flip Out", "Contour", "Contours flip away edge-on like turning cards.", {kind: "contour", mode: "c_flip", phase: "out"}
addEffect "Contour Zoom In", "Contour", "Contours zoom down from oversized into place, staggered.", {kind: "contour", mode: "c_zoom", phase: "in", d: {strength: 250}}
addEffect "Contour Zoom Out", "Contour", "Contours blow up past the camera, staggered.", {kind: "contour", mode: "c_zoom", phase: "out", d: {strength: 250}}
addEffect "Contour Typewriter In", "Contour", "Contours appear one by one in order, typewriter style.", {kind: "contour", mode: "c_type", phase: "in"}
addEffect "Contour Typewriter Out", "Contour", "Contours vanish one by one in order.", {kind: "contour", mode: "c_type", phase: "out"}
addEffect "Contour Domino In", "Contour", "Contours tip upright in sequence like falling dominoes reversed.", {kind: "contour", mode: "c_domino", phase: "in", dir: true}
addEffect "Contour Domino Out", "Contour", "Contours tip over in sequence like falling dominoes.", {kind: "contour", mode: "c_domino", phase: "out", dir: true}

addEffect "Shatter Out", "Shatter", "The filled shape breaks into spinning shards that burst outward.", {kind: "confetti", mode: "sh_burst", phase: "out", d: {strength: 60, layers: 6, alpha: 0}}
addEffect "Shatter In", "Shatter", "Spinning shards fly in and assemble the filled shape.", {kind: "confetti", mode: "sh_burst", phase: "in", d: {strength: 60, layers: 6, alpha: 0}}
addEffect "Crumble Down", "Shatter", "Shards break loose and pile up on an invisible floor.", {kind: "confetti", mode: "sh_crumble", phase: "out", d: {strength: 50, layers: 6, alpha: 0}}
addEffect "Sand Blow Out", "Shatter", "Grains blow away along the direction, front edge first.", {kind: "confetti", mode: "sh_sand", phase: "out", dir: true, d: {strength: 90, layers: 6, alpha: 0}}
addEffect "Sand Assemble In", "Shatter", "Grains blow in along the direction and settle into the shape.", {kind: "confetti", mode: "sh_sand", phase: "in", dir: true, d: {strength: 90, layers: 6, alpha: 0}}
addEffect "Dust Float Out", "Shatter", "Particles float up and drift apart like dust.", {kind: "confetti", mode: "sh_dust", phase: "out", d: {strength: 60, layers: 6, alpha: 0}}
addEffect "Dust Settle In", "Shatter", "Floating dust sinks and settles into the shape.", {kind: "confetti", mode: "sh_dust", phase: "in", d: {strength: 60, layers: 6, alpha: 0}}
addEffect "Swarm Out", "Shatter", "Particles spiral away like a startled swarm.", {kind: "confetti", mode: "sh_swarm", phase: "out", d: {strength: 90, layers: 6, alpha: 0}}
addEffect "Swarm In", "Shatter", "A swarm spirals in and condenses into the shape.", {kind: "confetti", mode: "sh_swarm", phase: "in", d: {strength: 90, layers: 6, alpha: 0}}
addEffect "Splash Out", "Shatter", "Droplets launch on ballistic arcs and fall away.", {kind: "confetti", mode: "sh_splash", phase: "out", d: {strength: 50, layers: 6, alpha: 0}}
addEffect "Confetti Rain In", "Shatter", "Pieces rain down from above and land into the shape.", {kind: "confetti", mode: "sh_rain", phase: "in", d: {strength: 120, layers: 6, alpha: 0}}
addEffect "Ember Drift", "Shatter", "Particles keep lifting off and rising like embers, cyclically.", {kind: "confetti", mode: "sh_ember", d: {strength: 60, layers: 6, alpha: 0, period: 1600}}
addEffect "Ash Fall Out", "Shatter", "The top edge flakes off first; ash flakes tumble down.", {kind: "confetti", mode: "sh_ash", phase: "out", d: {strength: 70, layers: 6, alpha: 0}}

addEffect "Corrupt Contour", "Glitch", "Short random coordinate bursts corrupt the outline per beat.", {kind: "field", mode: "g_corrupt", d: {strength: 14, period: 180}}
addEffect "Torn Static", "Glitch", "Ragged shear bursts with jagged torn edges, analog-static style.", {kind: "field", mode: "g_static", d: {strength: 12, period: 140}}
addEffect "Interlace Weave", "Glitch", "Odd and even scan rows shear in opposite directions.", {kind: "field", mode: "g_weave", d: {strength: 6, period: 400, frequency: 10}}
addEffect "Spike Burst", "Glitch", "Random single vertices spike out hard for a frame.", {kind: "field", mode: "g_spikes", d: {strength: 22, period: 200}}
addEffect "Dropout Holes", "Glitch", "Random point clusters collapse per beat, punching holes.", {kind: "field", mode: "g_dropout", d: {strength: 20, period: 240}}
addEffect "Quantize Pulse", "Glitch", "Coordinates snap to an oscillating grid, crystal-glitch style.", {kind: "field", mode: "g_quant", d: {strength: 10, period: 800}}
addEffect "Vertex Storm", "Glitch", "Vertices locally swap and churn positions every frame.", {kind: "field", mode: "g_storm", d: {strength: 12, period: 120}}

addEffect "Sketch Passes", "Sketch", "Stacked jittered pencil passes with blur and alpha.", {kind: "layer_deform", mode: "pencil", d: {layers: 3}}
addEffect "Scribble Passes", "Sketch", "Rougher stacked scribble passes with stronger offsets.", {kind: "layer_deform", mode: "scribble", d: {layers: 4, strength: 7}}

Effects = [item[1] for item in *EffectMeta]
EffectSpecs = {}
EffectCategory = {}
EffectHelp = {}
Categories = {}
CategoryEffects = {}
for item in *EffectMeta
  EffectSpecs[item[1]] = item[4]
  EffectCategory[item[1]] = item[2]
  EffectHelp[item[1]] = item[3]
  unless CategoryEffects[item[2]]
    CategoryEffects[item[2]] = {}
    Categories[#Categories + 1] = item[2]
  list = CategoryEffects[item[2]]
  list[#list + 1] = item[1]

Directions = {"Left to Right", "Right to Left", "Top to Bottom", "Bottom to Top"}
TimingModes = {"Auto frame ranges", "Moments only"}
MotionModes = {"Preserve source motion", "Bake AE position data"}

Defaults = {
  effect: "Font Morph"
  operation: "Font Morph"
  category: "Morph"
  target_font: "Times New Roman"
  moments: 3
  ratios: ""
  split_len: 4
  strength: 8
  frequency: 3
  noise_scale: 120
  period: 800
  seed: 1985
  layers: 4
  blur: 1.2
  alpha: 96
  x_offset: 0
  y_offset: 0
  direction: "Left to Right"
  timing_mode: "Auto frame ranges"
  motion_mode: "Preserve source motion"
  tracking_data: ""
  tracking_ref_frame: 1
}

MinMorphPoints = 8
GeometryEpsilon = 0.000001
MorphStepCount = 4
HotkeyMenuRoot = ": Kite Hotkeys :"
HotkeyMenuScript = script_name
WindowW = 8
PickerHelpH = 6
OptionHelpH = 6

finiteNumber = Core.finiteNumber
trim = LineOps.trim

clamp = (value, minValue, maxValue) ->
  LineOps.clamp (Core.finiteNumber(value) or minValue), minValue, maxValue

round = (value) ->
  value = Core.finiteNumber(value) or 0
  math.floor(value + 0.5)

fmtNum = (value) ->
  value = assert finiteNumber(value), "A generated coordinate is not finite."
  s = "%.1f"\format value
  s = s\gsub("%.0$", "")
  s

export utf8_len = (text) ->
  count = 0
  for _ in tostring(text or "")\gmatch "[^\128-\191]"
    count += 1
  count

choiceOrDefault = (value, choices, defaultValue) ->
  value = tostring(value or "")
  for choice in *choices
    return choice if value == choice
  defaultValue

showMessage = (message) ->
  rows = 0
  for line in (tostring(message or "") .. "\n")\gmatch "(.-)\n"
    rows += math.max 1, math.ceil(#line / 90)
  KiteUI.message message, {width: 36, height: math.max(3, math.min(14, rows))}

export window_error = (message) ->
  showMessage message
  aegisub.cancel!

export confirm_large_output = (lineCount, context = "one run") ->
  count = finiteNumber lineCount
  return true if count and count >= 0
  windowError "Invalid output count for #{context}."

export progress_is_cancelled = ->
  aegisub.progress and aegisub.progress.is_cancelled and aegisub.progress.is_cancelled!

export progress_task = (text) ->
  aegisub.progress.task text if aegisub.progress and aegisub.progress.task

export progress_set = (value) ->
  aegisub.progress.set value if aegisub.progress and aegisub.progress.set

sortedSelection = (sel) ->
  return nil, "Select at least one dialogue line." unless sel and #sel >= 1
  sorted, seen = {}, {}
  for rawIndex in *sel
    index = finiteNumber rawIndex
    return nil, "Selection contains an invalid line index." unless index and index >= 1 and index == math.floor(index)
    continue if seen[index]
    seen[index] = true
    sorted[#sorted + 1] = index
  table.sort sorted
  sorted

safeCollection = (sub, sel) ->
  ok, collection = pcall -> LineCollection sub, sel
  return nil, "LineCollection failed: #{collection}" unless ok and collection
  collection

safeLine = (source, collection, label = "Line") ->
  return nil, "#{label} is missing." unless source
  ok, line = pcall -> Line source, collection
  return nil, "#{label} could not be read: #{line}" unless ok and line
  line

effectSpec = (effect) ->
  EffectSpecs[effect] or EffectSpecs[Defaults.effect] or {kind: "field", mode: "boil"}

specDefault = (effect, name) ->
  spec = EffectSpecs[effect]
  if spec and spec.d and spec.d[name] != nil
    return spec.d[name]
  Defaults[name]

effectHelpText = (effect) ->
  category = EffectCategory[effect] or "Effect"
  spec = effectSpec effect
  timing = if spec.phase == "in" then "Entrance"
  elseif spec.phase == "out" then "Exit"
  elseif spec.kind == "morph" or spec.kind == "pair_morph" then "Timed morph"
  else "Loop (Period ms per cycle)"
  help = EffectHelp[effect] or ""
  "[#{category} - #{timing}] #{help}"

normalizeOptions = (result = {}) ->
  effect = choiceOrDefault result.effect or result.operation, Effects, Defaults.effect
  value = (name, minimum = nil, integer = false, positive = false) ->
    raw = result[name]
    raw = specDefault(effect, name) if raw == nil
    number = finiteNumber raw
    error "#{name} must be a finite number.", 0 unless number
    error "#{name} must be greater than zero.", 0 if positive and number <= 0
    error "#{name} must be at least #{minimum}.", 0 if minimum and number < minimum
    error "#{name} must be a representable integer.", 0 if integer and (number != math.floor(number) or number + 1 == number)
    number
  alpha = value "alpha", 0, true
  error "Alpha must be between 0 and 255.", 0 if alpha > 255
  {
    effect: effect
    operation: effect
    category: choiceOrDefault result.category, Categories, EffectCategory[effect] or Defaults.category
    target_font: trim(result.target_font or Defaults.target_font)
    moments: value "moments", 1, true
    ratios: trim(result.ratios or Defaults.ratios)
    split_len: value "split_len", nil, false, true
    strength: value "strength", 0
    frequency: value "frequency", 0
    noise_scale: value "noise_scale", nil, false, true
    period: value "period", 0, true
    seed: value "seed", nil, true
    layers: value "layers", 1, true
    blur: value "blur", 0
    alpha: alpha
    x_offset: value "x_offset"
    y_offset: value "y_offset"
    direction: choiceOrDefault result.direction, Directions, Defaults.direction
    timing_mode: choiceOrDefault result.timing_mode, TimingModes, Defaults.timing_mode
    motion_mode: choiceOrDefault result.motion_mode, MotionModes, Defaults.motion_mode
    tracking_data: tostring(result.tracking_data or Defaults.tracking_data)
    tracking_ref_frame: value "tracking_ref_frame", 1, true
  }

configSection = (effect) ->
  return "main" unless effect
  key = tostring(effect)\lower!\gsub "[^%w]+", "_"
  "effect_" .. key

export config_entries_for_gui = (gui) ->
  entries = {}
  for item in *(gui or {})
    if item.name
      item.config = true
      entries[item.name] = item
  entries

export control_value = (gui, name, fallback = nil) ->
  for item in *(gui or {})
    return item.value if item.name == name and item.value != nil
  fallback

export picker_gui = (category = Defaults.category, effect = Defaults.effect) ->
  category = choiceOrDefault category, Categories, Defaults.category
  pool = CategoryEffects[category] or Effects
  effect = choiceOrDefault effect, pool, pool[1]
  {
    {class: "label", label: "Category", x: 0, y: 0, width: 2}
    {class: "dropdown", name: "category", items: Categories, value: category, x: 2, y: 0, width: WindowW - 2}
    {class: "label", label: "Effect", x: 0, y: 1, width: 2}
    {class: "dropdown", name: "operation", items: pool, value: effect, x: 2, y: 1, width: WindowW - 2}
    {class: "textbox", readonly: true, value: effectHelpText(effect), x: 0, y: 2, width: WindowW, height: PickerHelpH}
    {class: "label", label: "Filter re-lists effects for the chosen category.", x: 0, y: 2 + PickerHelpH, width: WindowW}
  }

export add_moment_controls = (gui, y, effect) ->
  gui[#gui + 1] = {class: "label", label: "Moments", x: 0, y: y, width: 2}
  gui[#gui + 1] = {class: "intedit", name: "moments", value: specDefault(effect, "moments"), min: 1, x: 2, y: y, width: 2}
  gui[#gui + 1] = {class: "label", label: "Ratios", x: 4, y: y, width: 2}
  gui[#gui + 1] = {class: "edit", name: "ratios", value: specDefault(effect, "ratios"), x: 6, y: y, width: 2}

export add_shape_controls = (gui, y, effect) ->
  gui[#gui + 1] = {class: "label", label: "Split len", x: 0, y: y, width: 2}
  gui[#gui + 1] = {class: "floatedit", name: "split_len", value: specDefault(effect, "split_len"), x: 2, y: y, width: 2}
  gui[#gui + 1] = {class: "label", label: "Strength", x: 4, y: y, width: 2}
  gui[#gui + 1] = {class: "floatedit", name: "strength", value: specDefault(effect, "strength"), x: 6, y: y, width: 2}
  gui[#gui + 1] = {class: "label", label: "Frequency", x: 0, y: y + 1, width: 2}
  gui[#gui + 1] = {class: "floatedit", name: "frequency", value: specDefault(effect, "frequency"), x: 2, y: y + 1, width: 2}
  gui[#gui + 1] = {class: "label", label: "Scale", x: 4, y: y + 1, width: 2}
  gui[#gui + 1] = {class: "floatedit", name: "noise_scale", value: specDefault(effect, "noise_scale"), x: 6, y: y + 1, width: 2}

export add_seed_direction_controls = (gui, y, effect, spec) ->
  gui[#gui + 1] = {class: "label", label: "Seed", x: 0, y: y, width: 2}
  gui[#gui + 1] = {class: "intedit", name: "seed", value: specDefault(effect, "seed"), x: 2, y: y, width: 2}
  gui[#gui + 1] = {class: "label", label: "Period ms", x: 4, y: y, width: 2}
  gui[#gui + 1] = {class: "intedit", name: "period", value: specDefault(effect, "period"), min: 0, x: 6, y: y, width: 2}
  if spec and spec.dir
    gui[#gui + 1] = {class: "label", label: "Direction", x: 0, y: y + 1, width: 2}
    gui[#gui + 1] = {class: "dropdown", name: "direction", items: Directions, value: specDefault(effect, "direction"), x: 2, y: y + 1, width: 6}

export add_layer_controls = (gui, y, effect, label = "Pieces") ->
  gui[#gui + 1] = {class: "label", label: label, x: 0, y: y, width: 2}
  gui[#gui + 1] = {class: "intedit", name: "layers", value: specDefault(effect, "layers"), min: 1, x: 2, y: y, width: 2}
  gui[#gui + 1] = {class: "label", label: "Blur", x: 4, y: y, width: 1}
  gui[#gui + 1] = {class: "floatedit", name: "blur", value: specDefault(effect, "blur"), x: 5, y: y, width: 1}
  gui[#gui + 1] = {class: "label", label: "Alpha", x: 6, y: y, width: 1}
  gui[#gui + 1] = {class: "intedit", name: "alpha", value: specDefault(effect, "alpha"), min: 0, max: 255, x: 7, y: y, width: 1}

export add_offset_controls = (gui, y, effect) ->
  gui[#gui + 1] = {class: "label", label: "Center X%", x: 0, y: y, width: 2}
  gui[#gui + 1] = {class: "floatedit", name: "x_offset", value: specDefault(effect, "x_offset"), x: 2, y: y, width: 2}
  gui[#gui + 1] = {class: "label", label: "Y%", x: 4, y: y, width: 2}
  gui[#gui + 1] = {class: "floatedit", name: "y_offset", value: specDefault(effect, "y_offset"), x: 6, y: y, width: 2}

export add_timing_controls = (gui, y, effect) ->
  gui[#gui + 1] = {class: "label", label: "Timing", x: 0, y: y, width: 2}
  gui[#gui + 1] = {class: "dropdown", name: "timing_mode", items: TimingModes, value: specDefault(effect, "timing_mode"), x: 2, y: y, width: 6, hint: "Moments only overrides frame ranges"}

export add_motion_controls = (gui, y, effect) ->
  gui[#gui + 1] = {class: "label", label: "Motion", x: 0, y: y, width: 2}
  gui[#gui + 1] = {class: "dropdown", name: "motion_mode", items: MotionModes, value: specDefault(effect, "motion_mode"), x: 2, y: y, width: 6}
  gui[#gui + 1] = {class: "label", label: "Tracking data (optional)", x: 0, y: y + 1, width: 4}
  gui[#gui + 1] = {class: "label", label: "Ref frame", x: 4, y: y + 1, width: 2}
  gui[#gui + 1] = {class: "intedit", name: "tracking_ref_frame", value: specDefault(effect, "tracking_ref_frame"), min: 1, x: 6, y: y + 1, width: 2}
  gui[#gui + 1] = {class: "textbox", name: "tracking_data", value: specDefault(effect, "tracking_data"), x: 0, y: y + 2, width: WindowW, height: 2, hint: "Paste tracking data here when using a tracking motion mode."}

export options_gui = (effect) ->
  effect = choiceOrDefault effect, Effects, Defaults.effect
  spec = effectSpec effect
  gui = {
    {class: "label", label: "#{script_name} - #{effect}", x: 0, y: 0, width: WindowW}
    {class: "textbox", readonly: true, value: effectHelpText(effect), x: 0, y: 1, width: WindowW, height: OptionHelpH}
  }
  y = OptionHelpH + 1
  if spec.kind == "morph"
    gui[#gui + 1] = {class: "label", label: "Target font", x: 0, y: y, width: 2}
    gui[#gui + 1] = {class: "edit", name: "target_font", value: specDefault(effect, "target_font"), x: 2, y: y, width: 6}
    y += 1
  if spec.kind == "confetti"
    addLayerControls gui, y, effect, "Pieces"
    y += 1
  elseif spec.kind == "layer_deform"
    addLayerControls gui, y, effect, "Passes"
    y += 1
  addMomentControls gui, y, effect
  y += 1
  addShapeControls gui, y, effect
  y += 2
  unless spec.kind == "morph" or spec.kind == "pair_morph"
    addSeedDirectionControls gui, y, effect, spec
    y += spec.dir and 2 or 1
  if spec.off or spec.kind == "confetti"
    addOffsetControls gui, y, effect
    y += 1
  addTimingControls gui, y, effect
  y += 1
  addMotionControls gui, y, effect
  gui

export config_interface = (section = nil, gui = nil) ->
  interface = {main: configEntriesForGui pickerGui(Defaults.category, Defaults.effect)}
  if section and gui
    interface[section] = configEntriesForGui gui
  else
    for effect in *Effects
      interface[configSection effect] = configEntriesForGui optionsGui(effect)
  interface

export read_configured_gui = (section, gui) ->
  return nil unless configHandler
  ok, options = pcall -> configHandler configInterface(section, gui), ConfigFile, true, script_version
  return nil unless ok and options
  pcall -> options\read!
  pcall -> options\updateInterface section
  options

export save_configured_gui = (options, result, section) ->
  return true unless options and result
  ok, saved, err = pcall ->
    options\updateConfiguration result, section
    options\write!
  unless ok and saved != false
    showMessage "Could not save #{section} settings: #{ok and err or saved}"
    return false
  true

export effect_picker = ->
  category = Defaults.category
  current = Defaults.effect
  savedGui = pickerGui category, current
  options = readConfiguredGui "main", savedGui
  category = choiceOrDefault controlValue(savedGui, "category", category), Categories, category
  pool = CategoryEffects[category] or Effects
  current = choiceOrDefault controlValue(savedGui, "operation", current), pool, pool[1]
  while true
    gui = pickerGui category, current
    pool = CategoryEffects[category] or Effects
    gui[2].value = category
    gui[4].items = pool
    gui[4].value = current
    gui[5].value = effectHelpText current
    button, result = aegisub.dialog.display gui, {"Run", "Filter", "Cancel"}, {ok: "Run", close: "Cancel"}
    chosenCategory = choiceOrDefault result and result.category or category, Categories, category
    pool = CategoryEffects[chosenCategory] or Effects
    chosen = choiceOrDefault result and result.operation or current, pool, pool[1]
    if button == "Filter"
      saveConfiguredGui options, {category: chosenCategory, operation: chosen}, "main"
      category = chosenCategory
      current = chosen
    elseif button == "Run"
      saveConfiguredGui options, {category: chosenCategory, operation: chosen}, "main"
      return chosen
    else
      aegisub.cancel!

export show_effect_options = (effect) ->
  section = configSection effect
  gui = optionsGui effect
  options = readConfiguredGui section, gui
  while true
    button, result = aegisub.dialog.display gui, {"Apply", "Back", "Cancel"}, {ok: "Apply", close: "Cancel"}
    if button == "Apply"
      result or= {}
      result.effect = effect
      ok, opts = pcall -> normalizeOptions result
      if ok
        ratios, err = parseRatios opts.ratios, opts.moments
        if ratios
          saveConfiguredGui options, result, section
          return opts
        showMessage err
      else
        showMessage opts
      for item in *gui
        item.value = result[item.name] if item.name and result[item.name] != nil
    elseif button == "Back"
      return "__back"
    else
      aegisub.cancel!

export read_options = ->
  while true
    effect = effectPicker!
    opts = showEffectOptions effect
    return opts if opts != "__back"

export auto_ratios = (count) ->
  count = math.max 1, round count
  return {1} if count <= 1
  ratios = {}
  for i = 1, count
    LineOps.checkCancelled!
    ratios[#ratios + 1] = (i - 1) / (count - 1)
  ratios

export same_ratio = (a, b) ->
  math.abs((finiteNumber(a) or 0) - (finiteNumber(b) or 0)) < GeometryEpsilon

export legacy_default_ratios = (ratios) ->
  #ratios == 3 and sameRatio(ratios[1], 0) and sameRatio(ratios[2], 0.5) and sameRatio(ratios[3], 1)

export parse_ratio_tokens = (text) ->
  ratios, invalid = {}, {}
  for token in tostring(text or "")\gmatch "[^,%s]+"
    value = finiteNumber token
    if not value
      invalid[#invalid + 1] = token

    else
      ratios[#ratios + 1] = value
  if #invalid > 0
    return nil, "Ratios contains invalid value(s): #{table.concat invalid, ", "}. Use finite numbers, or leave Ratios blank for automatic spacing."
  ratios

export parse_ratios = (text, count) ->
  count = math.max 1, round count
  raw = trim text
  ratios, err = parseRatioTokens raw
  return nil, err unless ratios
  if raw == "" or legacyDefaultRatios(ratios) and count != 3
    return autoRatios count
  return ratios if #ratios == count
  return nil, "Ratios has #{#ratios} value(s), but Moments is #{count}. Leave Ratios blank for automatic spacing or provide exactly #{count} ratio values."

export elastic_ratios = (count) ->
  return {0} if count <= 1
  return {0, 1.12, 1} if count == 3
  ratios = {}
  for i = 1, count
    LineOps.checkCancelled!
    t = (i - 1) / (count - 1)
    if t < 0.7
      ratios[i] = (t / 0.7) * 0.75
    elseif t < 0.85
      ratios[i] = 0.75 + ((t - 0.7) / 0.15) * 0.37
    else
      ratios[i] = 1.12 + ((t - 0.85) / 0.15) * -0.12
  ratios

momentRatios = (opts) ->
  spec = EffectSpecs[opts.effect]
  if spec and spec.elastic
    elasticRatios opts.moments
  else
    parseRatios opts.ratios, opts.moments

collectNumbers = (shape) ->
  nums = {}
  for token in tostring(shape or "")\gmatch "%S+"
    value = finiteNumber token
    nums[#nums + 1] = value if value
  nums



cleanShape = (shape) ->
  shape = tostring(shape or "")
  shape = shape\gsub "^%s+", ""
  shape = shape\gsub "%s+$", ""
  tokens = {}
  for token in shape\gmatch "%S+"
    lower = token\lower!
    tokens[#tokens + 1] = if lower\match("^[mnlbspc]$") then lower else token
  table.concat tokens, " "

validateShapeStructure = (shape, allowEmpty = false) ->
  return true if allowEmpty and trim(shape) == ""
  valid = AssDrawing.validatePath shape
  return nil, "expected complete finite ASS drawing commands" unless valid
  true

export shape_limit_error = (label, numberCount) ->
  "#{label} could not be processed (#{numberCount} coordinates). Increase Split len if memory is insufficient."

guardShape = (shape, label = "Shape", allowEmpty = false) ->
  shape = cleanShape shape
  valid, err = validateShapeStructure shape, allowEmpty
  return nil, "#{label} has invalid drawing structure: #{err}." unless valid
  shape, nil

shapeBbox = (shape) ->
  nums = collectNumbers shape
  return nil if #nums < 2
  minX, maxX = nums[1], nums[1]
  minY, maxY = nums[2], nums[2]
  for i = 1, #nums - 1, 2
    LineOps.checkCancelled!
    x, y = nums[i], nums[i + 1]
    if x and y
      minX = math.min minX, x
      maxX = math.max maxX, x
      minY = math.min minY, y
      maxY = math.max maxY, y
  {min_x: minX, max_x: maxX, min_y: minY, max_y: maxY, width: maxX - minX, height: maxY - minY}

parseContours = (shape) ->
  contours, current, pending = {}, nil, nil
  for token in tostring(shape or "")\gmatch "%S+"
    value = finiteNumber token
    if value
      if pending != nil
        if current
          current[#current + 1] = {x: pending, y: value}
        pending = nil
      else
        pending = value
    else
      pending = nil
      if token\lower! == "m" or token\lower! == "n"
        current = {}
        contours[#contours + 1] = current
  result = {}
  for contour in *contours
    result[#result + 1] = contour if #contour > 0
  result

contourMetrics = (points) ->
  n = #points
  segs, total = {}, 0
  for i = 1, n
    LineOps.checkCancelled!
    a = points[i]
    b = points[i == n and 1 or i + 1]
    dx, dy = b.x - a.x, b.y - a.y
    d = math.sqrt dx * dx + dy * dy
    segs[i] = d
    total += d
  assert finiteNumber(total), "Contour length cannot be represented."
  segs, total

contourCentroid = (points) ->
  n = #points
  return {x: 0, y: 0} if n == 0
  sx, sy = 0, 0
  for p in *points
    sx += p.x
    sy += p.y
  {x: sx / n, y: sy / n}

signedArea = (points) ->
  area, n = 0, #points
  for i = 1, n
    LineOps.checkCancelled!
    a = points[i]
    b = points[i == n and 1 or i + 1]
    area += a.x * b.y - b.x * a.y
  area / 2

reverseContour = (points) ->
  out = {}
  for i = #points, 1, -1
    LineOps.checkCancelled!
    out[#out + 1] = points[i]
  out

contourBbox = (points) ->
  return nil if #points == 0
  minX, maxX = points[1].x, points[1].x
  minY, maxY = points[1].y, points[1].y
  for p in *points
    minX = math.min minX, p.x
    maxX = math.max maxX, p.x
    minY = math.min minY, p.y
    maxY = math.max maxY, p.y
  {min_x: minX, max_x: maxX, min_y: minY, max_y: maxY, width: maxX - minX, height: maxY - minY}

resampleContour = (points, count) ->
  n = #points
  count = math.max 3, round count
  return nil if n == 0
  out = {}
  if n == 1
    for i = 1, count
      LineOps.checkCancelled!
      out[i] = {x: points[1].x, y: points[1].y}
    return out
  segs, total = contourMetrics points
  if total <= 0
    for i = 1, count
      LineOps.checkCancelled!
      out[i] = {x: points[1].x, y: points[1].y}
    return out
  cum = {0}
  for i = 1, n
    LineOps.checkCancelled!
    cum[i + 1] = cum[i] + segs[i]
  step = total / count
  si = 1
  for k = 0, count - 1
    LineOps.checkCancelled!
    d = k * step
    while si < n and cum[si + 1] < d
      si += 1
    a = points[si]
    b = points[si == n and 1 or si + 1]
    segD = segs[si]
    t = if segD > 0 then (d - cum[si]) / segD else 0
    out[k + 1] = {x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t}
  out

alignContour = (reference, candidate) ->
  n = #reference
  return candidate if n != #candidate or n == 0
  refArea, candArea = signedArea(reference), signedArea(candidate)
  candidate = reverseContour candidate if refArea * candArea < 0
  bestOffset, bestCost = 0, math.huge
  for offset = 0, n - 1
    LineOps.checkCancelled!
    cost = 0
    for i = 1, n
      LineOps.checkCancelled!
      j = ((i - 1 + offset) % n) + 1
      dx = reference[i].x - candidate[j].x
      dy = reference[i].y - candidate[j].y
      cost += dx * dx + dy * dy
      break if cost >= bestCost
    if cost < bestCost
      bestCost, bestOffset = cost, offset
  aligned = {}
  for i = 1, n
    LineOps.checkCancelled!
    j = ((i - 1 + bestOffset) % n) + 1
    aligned[i] = candidate[j]
  aligned

contoursToShape = (contours) ->
  parts = {}
  for contour in *contours
    continue if #contour == 0
    first = contour[1]
    parts[#parts + 1] = "m #{fmtNum first.x} #{fmtNum first.y} l"
    for i = 2, #contour
      LineOps.checkCancelled!
      p = contour[i]
      parts[#parts + 1] = "#{fmtNum p.x} #{fmtNum p.y}"
    if #contour == 1
      parts[#parts + 1] = "#{fmtNum first.x} #{fmtNum first.y}"
  table.concat parts, " "

flattenShape = (shape, label = "Shape") ->
  shape, err = guardShape shape, label
  return nil, err unless shape
  return shape unless shape\match "%f[%a][bspc]%f[%A]"
  return nil, "Yutils.shape.flatten is required for curves." unless Yutils and Yutils.shape and Yutils.shape.flatten
  ok, result = pcall Yutils.shape.flatten, shape
  return nil, "Yutils.shape.flatten failed for #{label}: #{result}" unless ok
  result, err = guardShape result, "#{label} after flatten"
  return nil, err unless result
  return nil, "Yutils.shape.flatten returned unflattened curves." if result\match "%f[%a][bspc]%f[%A]"
  result

normalizePair = (shapeA, shapeB, opts) ->
  flatA, err = flattenShape shapeA, "Source shape"
  return nil, nil, err unless flatA
  flatB, err = flattenShape shapeB, "Target shape"
  return nil, nil, err unless flatB
  contoursA = parseContours flatA
  contoursB = parseContours flatB
  return nil, nil, "source shape has no drawable contours" if #contoursA == 0
  return nil, nil, "target shape has no drawable contours" if #contoursB == 0
  pairCount = math.max #contoursA, #contoursB
  for i = #contoursA + 1, pairCount
    LineOps.checkCancelled!
    contoursA[i] = {contourCentroid contoursB[i]}
  for i = #contoursB + 1, pairCount
    LineOps.checkCancelled!
    contoursB[i] = {contourCentroid contoursA[i]}
  segLen = opts.split_len
  desired = {}
  for i = 1, pairCount
    LineOps.checkCancelled!
    _, lenA = contourMetrics contoursA[i]
    _, lenB = contourMetrics contoursB[i]
    count = math.max MinMorphPoints, math.ceil(math.max(lenA, lenB) / segLen)
    desired[i] = count
  outA, outB = {}, {}
  for i = 1, pairCount
    LineOps.checkCancelled!
    sampledA = resampleContour contoursA[i], desired[i]
    sampledB = resampleContour contoursB[i], desired[i]
    return nil, nil, "shape morph resampling failed for contour #{i}" unless sampledA and sampledB
    outA[i] = sampledA
    outB[i] = alignContour sampledA, sampledB
  resultA, err = guardShape contoursToShape(outA), "Source shape after resample"
  return nil, nil, err unless resultA
  resultB, err = guardShape contoursToShape(outB), "Target shape after resample"
  return nil, nil, err unless resultB
  resultA, resultB

lerpShape = (shapeA, shapeB, ratio, numsB = nil) ->
  ratio = assert finiteNumber(ratio), "Morph ratio must be finite."
  numsB = numsB or collectNumbers shapeB
  result, ni = {}, 1
  for token in tostring(shapeA or "")\gmatch "%S+"
    value = finiteNumber token
    if value
      other = numsB[ni]
      return nil, "missing target coordinate #{ni}" unless other
      result[#result + 1] = fmtNum value + (other - value) * ratio
      ni += 1
    else
      result[#result + 1] = token
  return nil, "source shape has fewer coordinates than target shape" if ni <= #numsB
  guardShape table.concat(result, " "), "Lerped shape"

noiseHash = (ix, iy, seed) ->
  raw = math.sin(ix * 127.1 + iy * 311.7 + seed * 74.7) * 43758.5453123
  raw - math.floor raw

smoothNoise = (x, y, seed) ->
  ix, iy = math.floor(x), math.floor(y)
  fx, fy = x - ix, y - iy
  sx = fx * fx * (3 - 2 * fx)
  sy = fy * fy * (3 - 2 * fy)
  n00, n10 = noiseHash(ix, iy, seed), noiseHash(ix + 1, iy, seed)
  n01, n11 = noiseHash(ix, iy + 1, seed), noiseHash(ix + 1, iy + 1, seed)
  nx0 = n00 + (n10 - n00) * sx
  nx1 = n01 + (n11 - n01) * sx
  nx0 + (nx1 - nx0) * sy

octaveNoise = (x, y, seed, octaves = 3) ->
  total, amp, freq, norm = 0, 1, 1, 0
  for _ = 1, octaves
    total += (smoothNoise(x * freq, y * freq, seed) - 0.5) * amp
    norm += amp
    amp *= 0.5
    freq *= 2.1
  total / norm

normSpan = (value, minValue, maxValue) ->
  span = maxValue - minValue
  return 0 if math.abs(span) < GeometryEpsilon
  clamp (value - minValue) / span, 0, 1

shapeCenter = (bbox) ->
  {x: (bbox.min_x + bbox.max_x) / 2, y: (bbox.min_y + bbox.max_y) / 2}

unitFromCenter = (x, y, center) ->
  dx, dy = x - center.x, y - center.y
  len = math.sqrt(dx * dx + dy * dy)
  return 0, -1, 0 if len <= GeometryEpsilon
  dx / len, dy / len, len

curveRatio = (ratio, mode) ->
  ratio = assert finiteNumber(ratio), "Curve ratio must be finite."
  return ratio if mode == "linear" or mode == "glitch"
  ratio = clamp ratio, 0, 1
  switch mode
    when "overshoot" then ratio + math.sin(ratio * math.pi) * 0.22
    when "anticipation" then ratio * ratio * 1.18 - math.sin((1 - ratio) * math.pi) * 0.12
    when "bounce" then ratio + math.sin(ratio * math.pi * 3) * (1 - ratio) * 0.16
    when "steps" then math.floor(ratio * MorphStepCount + GeometryEpsilon) / MorphStepCount
    when "rubber" then ratio + math.sin(ratio * math.pi * 2) * 0.10
    else ratio * ratio * (3 - 2 * ratio)

triWave = (t) ->
  t = t - math.floor t
  if t < 0.5 then t * 4 - 1 else 3 - t * 4

staggerAmount = (arrival, rank, spread = 0.6) ->
  clamp (arrival * (1 + spread) - rank * spread), 0, 1

prepGeo = (shape, opts, label = "Shape") ->
  flat, err = flattenShape shape, label
  return nil, err unless flat
  return nil, "Yutils.shape.split is required for outline effects." unless Yutils and Yutils.shape and Yutils.shape.split
  ok, result = pcall Yutils.shape.split, flat, opts.split_len
  return nil, "Yutils.shape.split failed for #{label}: #{result}" unless ok
  base, err = guardShape result, "#{label} after split"
  return nil, err unless base

  raw = parseContours base
  return nil, "#{label} has no drawable contours." if #raw == 0
  bbox = shapeBbox base
  return nil, "#{label} has no coordinate bounds." unless bbox
  contours, totalLen = {}, 0
  for pts in *raw
    LineOps.checkCancelled!
    n = #pts
    if n > 2 and math.abs(pts[n].x - pts[1].x) < 0.001 and math.abs(pts[n].y - pts[1].y) < 0.001
      pts[n] = nil
      n -= 1
    continue if n == 0
    segs, len = contourMetrics pts
    cum = {0}
    for i = 1, n
      LineOps.checkCancelled!
      cum[i + 1] = cum[i] + segs[i]
    area = signedArea pts
    sign = area >= 0 and 1 or -1
    normals = {}
    for i = 1, n
      LineOps.checkCancelled!
      prev = pts[i == 1 and n or i - 1]
      nxt = pts[i == n and 1 or i + 1]
      tx, ty = nxt.x - prev.x, nxt.y - prev.y
      tl = math.sqrt tx * tx + ty * ty
      if tl < GeometryEpsilon
        normals[i] = {x: 0, y: -1, tx: 1, ty: 0}
      else
        normals[i] = {x: ty * sign / tl, y: -tx * sign / tl, tx: tx / tl, ty: ty / tl}
    contours[#contours + 1] = {
      pts: pts
      n: n
      segs: segs
      len: len
      cum: cum
      area: area
      centroid: contourCentroid pts
      cbox: contourBbox pts
      normals: normals
      offset: totalLen
    }
    totalLen += len
  return nil, "#{label} has no usable contours." if #contours == 0
  {
    sourceShape: shape
    contours: contours
    cn: #contours
    bbox: bbox
    center: shapeCenter bbox
    width: math.max 1, bbox.width
    height: math.max 1, bbox.height
    total_len: math.max 1, totalLen
  }

dirAxis = (direction, px, py) ->
  switch direction
    when "Right to Left" then 1 - px
    when "Top to Bottom" then py
    when "Bottom to Top" then 1 - py
    else px

dirVector = (direction) ->
  switch direction
    when "Right to Left" then -1, 0
    when "Top to Bottom" then 0, 1
    when "Bottom to Top" then 0, -1
    else 1, 0

buildCtx = (geo, opts, slice, spec) ->
  prog = clamp slice.progress, 0, 1
  eased = curveRatio prog, spec.curve
  m = 1
  if spec.phase == "in"
    m = 1 - eased
  elseif spec.phase == "out"
    m = eased
  elseif spec.env == "grow"
    m = eased
  elseif spec.env == "fade"
    m = 1 - eased
  period = opts.period
  tMs = finiteNumber(slice.time_ms) or 0
  phi = if period and period > 0
    (tMs / period) * math.pi * 2
  else
    slice.ratio * math.pi * 2
  beat = math.floor phi / (math.pi * 2) * 4
  cx = geo.center.x + (opts.x_offset / 100) * geo.width * 0.5
  cy = geo.center.y + (opts.y_offset / 100) * geo.height * 0.5
  {
    geo: geo
    opts: opts
    spec: spec
    slice: slice
    prog: prog
    eased: eased
    m: m
    phi: phi
    t: tMs
    beat: beat
    frame_key: math.floor(period and period > 0 and (tMs / math.max(1, period)) * 8 or slice.index)
    strength: opts.strength
    freq: math.max 0.01, opts.frequency
    scale: opts.noise_scale
    seed: opts.seed
    fx_center: {x: cx, y: cy}
    maxd: math.max(geo.width, geo.height) * 0.5
  }

timingForMoment = (source, index, total) ->
  startTime = finiteNumber(source.start_time) or 0
  endTime = finiteNumber(source.end_time) or startTime + 1
  endTime = startTime + 1 if endTime <= startTime
  duration = math.max 1, endTime - startTime
  s = round startTime + duration * (index - 1) / total
  e = if index == total then endTime else round startTime + duration * index / total
  s, math.max(s + 1, e)

frameTimingEnabled = (opts) ->
  not opts or opts.timing_mode != "Moments only"

frameApiAvailable = ->
  aegisub and aegisub.frame_from_ms and aegisub.ms_from_frame

lineFrameBounds = (source) ->
  return nil unless frameApiAvailable!
  startTime = finiteNumber(source.start_time) or 0
  endTime = finiteNumber(source.end_time) or startTime + 1
  endTime = startTime + 1 if endTime <= startTime
  okStart, startFrame = pcall aegisub.frame_from_ms, startTime
  okEnd, lastFrame = pcall aegisub.frame_from_ms, math.max(startTime, endTime - 1)
  startFrame = okStart and finiteNumber(startFrame) or nil
  lastFrame = okEnd and finiteNumber(lastFrame) or nil
  return nil unless startFrame and lastFrame
  startFrame = round startFrame
  endFrame = round(lastFrame) + 1
  endFrame = startFrame + 1 if endFrame <= startFrame
  startFrame, endFrame

lineFrameCount = (source) ->
  startFrame, endFrame = lineFrameBounds source
  return 1 unless startFrame and endFrame
  math.max 1, endFrame - startFrame

lineDurationMs = (source) ->
  startTime = finiteNumber(source.start_time) or 0
  endTime = finiteNumber(source.end_time) or startTime + 1
  math.max 1, endTime - startTime

timeRangeForFrame = (source, frame) ->
  return nil unless frameApiAvailable!
  sourceStart = finiteNumber(source.start_time) or 0
  sourceEnd = finiteNumber(source.end_time) or sourceStart + 1
  sourceEnd = sourceStart + 1 if sourceEnd <= sourceStart
  okStart, startTime = pcall aegisub.ms_from_frame, frame
  okEnd, endTime = pcall aegisub.ms_from_frame, frame + 1
  return nil unless okStart and okEnd and startTime != nil and endTime != nil
  startTime = math.max sourceStart, round startTime
  endTime = math.min sourceEnd, round endTime
  endTime = startTime + 1 if endTime <= startTime
  startTime, endTime

progressForMoment = (index, total) ->
  total = round(finiteNumber(total) or 1)
  index = round(finiteNumber(index) or 1)
  return 1 if total <= 1
  clamp (index - 1) / (total - 1), 0, 1

momentSlices = (source, opts) ->
  return nil, "Moments exceeds the available whole milliseconds in this line." if opts.moments > source.end_time - source.start_time
  ratios, err = momentRatios opts
  return nil, err unless ratios
  sourceStart = finiteNumber(source.start_time) or 0
  slices = {}
  for i, ratio in ipairs ratios
    startTime, endTime = timingForMoment source, i, #ratios
    slices[#slices + 1] = {
      index: i
      total: #ratios
      local_index: i
      local_total: #ratios
      ratio: ratio
      progress: progressForMoment i, #ratios
      start_time: startTime
      end_time: endTime
      time_ms: startTime - sourceStart
      frame: nil
      mode: "moment"
    }
  slices

temporalSlices = (source, opts) ->
  return nil, "Line duration must be positive and finite." unless finiteNumber(source.start_time) and finiteNumber(source.end_time) and source.end_time > source.start_time
  return momentSlices source, opts unless frameTimingEnabled opts
  startFrame, endFrame = lineFrameBounds source
  return momentSlices source, opts unless startFrame and endFrame
  localTotal = math.max 1, endFrame - startFrame
  context = opts and opts._frame_context or nil
  total = context and context.total_frames or localTotal
  offset = context and context.frame_offset or 0
  timeOffset = context and context.time_offset or 0
  sourceStart = finiteNumber(source.start_time) or 0
  slices = {}
  for i = 1, localTotal
    LineOps.checkCancelled!
    frame = startFrame + i - 1
    startTime, endTime = timeRangeForFrame source, frame
    return momentSlices source, opts unless startTime and endTime
    globalIndex = offset + i
    progress = if total <= 1 then 1 else clamp((globalIndex - 1) / (total - 1), 0, 1)
    slices[#slices + 1] = {
      index: globalIndex
      total: total
      local_index: i
      local_total: localTotal
      ratio: progress
      progress: progress
      start_time: startTime
      end_time: endTime
      time_ms: timeOffset + (startTime - sourceStart)
      frame: frame
      mode: "frame"
    }
  slices

FieldFx = {}

applyField = (geo, ctx, mode, label = "Field shape") ->
  fx = FieldFx[mode]
  return nil, "Unknown field mode '#{mode}'." unless fx
  ctx.ca = math.cos(ctx.phi) * 1.3
  ctx.sa = math.sin(ctx.phi) * 1.3
  bbox = geo.bbox
  out = {}
  q = {}
  changed = false
  for ci, co in ipairs geo.contours
    LineOps.checkCancelled!
    pts, n = co.pts, co.n
    rank = ctx.ranks and ctx.ranks[ci] or 0
    newPts = {}
    for i = 1, n
      LineOps.checkCancelled!
      p = pts[i]
      nor = co.normals[i]
      q.px = normSpan p.x, bbox.min_x, bbox.max_x
      q.py = normSpan p.y, bbox.min_y, bbox.max_y
      q.s = co.cum[i] / math.max(0.001, co.len)
      q.sg = (co.offset + co.cum[i]) / geo.total_len
      q.nx, q.ny = nor.x, nor.y
      q.tx, q.ty = nor.tx, nor.ty
      q.ci, q.i, q.n = ci, i, n
      q.co = co
      q.rank = rank
      q.ux, q.uy, q.dist = unitFromCenter p.x, p.y, geo.center
      x, y = fx ctx, p.x, p.y, q
      changed = true if x != p.x or y != p.y
      newPts[i] = {x: x, y: y}
    out[#out + 1] = newPts
  return geo.sourceShape unless changed
  guardShape contoursToShape(out), label

fieldNoise = (ctx, x, y, ox = 0, oy = 0) ->
  smoothNoise(x / ctx.scale + ctx.ca + ox, y / ctx.scale + ctx.sa + oy, ctx.seed) - 0.5

FieldFx.boil = (ctx, x, y, q) ->
  dx = fieldNoise(ctx, x, y) * ctx.strength * 2
  dy = fieldNoise(ctx, x, y, 37, 17) * ctx.strength * 2
  x + dx * ctx.m, y + dy * ctx.m

FieldFx.electric = (ctx, x, y, q) ->
  dx = (noiseHash(q.i * 7 + q.ci * 131, ctx.frame_key, ctx.seed) - 0.5) * 2
  dy = (noiseHash(q.i * 13 + q.ci * 57, ctx.frame_key + 41, ctx.seed) - 0.5) * 2
  x + dx * ctx.strength * ctx.m, y + dy * ctx.strength * ctx.m

FieldFx.handwriting = (ctx, x, y, q) ->
  dx = fieldNoise(ctx, x, y) * ctx.strength * 2
  dy = fieldNoise(ctx, x, y, 91, 43) * ctx.strength * 2
  wob = math.sin(q.s * math.pi * 4 + ctx.phi) * ctx.strength * 0.3
  x + (dx + q.nx * wob) * ctx.m, y + (dy + q.ny * wob) * ctx.m

FieldFx.wobble = (ctx, x, y, q) ->
  dx = math.sin(y * 0.02 * ctx.freq + ctx.phi) * ctx.strength
  dy = math.sin(x * 0.02 * ctx.freq + ctx.phi * 1.3) * ctx.strength
  x + dx * ctx.m, y + dy * ctx.m

FieldFx.fineJitter = (ctx, x, y, q) ->
  dx = (noiseHash(q.i + q.ci * 89, ctx.frame_key, ctx.seed) - 0.5) * 1.4
  dy = (noiseHash(q.i + q.ci * 89, ctx.frame_key + 7, ctx.seed + 3) - 0.5) * 1.4
  sm = fieldNoise(ctx, x, y) * 0.8
  x + (dx + sm) * ctx.strength * ctx.m, y + (dy - sm) * ctx.strength * ctx.m

FieldFx.coarseJitter = (ctx, x, y, q) ->
  cell = math.max 6, ctx.scale / 8
  jx = smoothNoise(math.floor(x / cell), math.floor(y / cell) + ctx.frame_key * 0.618, ctx.seed) - 0.5
  jy = smoothNoise(math.floor(x / cell) + 40, math.floor(y / cell) - 13 + ctx.frame_key * 0.618, ctx.seed + 7) - 0.5
  x + jx * ctx.strength * 2 * ctx.m, y + jy * ctx.strength * 2 * ctx.m

FieldFx.drift = (ctx, x, y, q) ->
  t = ctx.phi / (math.pi * 2)
  dx = (smoothNoise(x / ctx.scale + t * 0.7, y / ctx.scale, ctx.seed) - 0.5) * ctx.strength * 2
  dy = (smoothNoise(x / ctx.scale + t * 0.7 + 60, y / ctx.scale + 25, ctx.seed + 5) - 0.5) * ctx.strength * 2
  x + dx * ctx.m, y + dy * ctx.m

FieldFx.heat = (ctx, x, y, q) ->
  t = ctx.phi / math.pi
  dx = (smoothNoise(x / ctx.scale * ctx.freq, y / ctx.scale * ctx.freq + t, ctx.seed) - 0.5) * ctx.strength * 2
  dy = (smoothNoise(x / ctx.scale * ctx.freq + 33, y / ctx.scale * ctx.freq + t * 1.4, ctx.seed + 9) - 0.5) * ctx.strength * 0.6
  x + dx * ctx.m, y + (dy - ctx.strength * 0.15) * ctx.m

FieldFx.water = (ctx, x, y, q) ->
  t = ctx.phi / math.pi
  dx = (smoothNoise(x / ctx.scale + t, y / ctx.scale, ctx.seed) - 0.5) * ctx.strength * 1.2
  dy = math.sin(q.px * math.pi * 2 * ctx.freq + ctx.phi + fieldNoise(ctx, x, y) * 4) * ctx.strength * 0.8
  x + dx * ctx.m, y + dy * ctx.m

FieldFx.gelatin = (ctx, x, y, q) ->
  tp = ctx.phi / (math.pi * 2)
  tp = tp - math.floor tp
  damp = math.exp(-tp * 3) * math.sin(tp * math.pi * 2 * ctx.freq)
  dx = damp * (q.px - 0.5) * ctx.strength * 1.6
  dy = -damp * (q.py - 0.5) * ctx.strength * 1.2
  x + dx * ctx.m, y + dy * ctx.m

FieldFx.underwater = (ctx, x, y, q) ->
  sway = math.sin(q.py * math.pi * ctx.freq + ctx.phi) * ctx.strength
  fine = fieldNoise(ctx, x, y) * ctx.strength * 0.5
  lift = math.sin(q.px * math.pi * 2 + ctx.phi * 0.5) * ctx.strength * 0.3
  x + (sway + fine) * ctx.m, y + (lift - fine) * ctx.m

FieldFx.windblown = (ctx, x, y, q) ->
  dvx, dvy = dirVector ctx.opts.direction
  ax = dirAxis ctx.opts.direction, q.px, q.py
  t = ctx.phi / (math.pi * 2)
  gust = math.max 0, octaveNoise(t * 1.4 - ax * 0.8, q.ci * 0.31, ctx.seed, 2) * 2.4
  flut = fieldNoise(ctx, x, y) * 0.8
  amp = ctx.strength * (gust + 0.15) * ctx.m
  x + (dvx * amp) + flut * amp * 0.4, y + (dvy * amp) + flut * amp * 0.4

FieldFx.buzz = (ctx, x, y, q) ->
  step = ctx.frame_key % 4
  sign = step % 2 == 0 and 1 or -1
  dx = sign * ctx.strength * (0.5 + noiseHash(q.i, q.ci + step, ctx.seed))
  dy = -sign * ctx.strength * 0.4 * (0.5 + noiseHash(q.i + 9, q.ci + step, ctx.seed))
  x + dx * ctx.m, y + dy * ctx.m

FieldFx.waveH = (ctx, x, y, q) ->
  x + math.sin(q.py * math.pi * 2 * ctx.freq - ctx.phi) * ctx.strength * ctx.m, y

FieldFx.waveV = (ctx, x, y, q) ->
  x, y + math.sin(q.px * math.pi * 2 * ctx.freq - ctx.phi) * ctx.strength * ctx.m

FieldFx.waveD = (ctx, x, y, q) ->
  w = math.sin((q.px + q.py) * math.pi * ctx.freq * 2 - ctx.phi) * ctx.strength * ctx.m
  x + w, y + w * 0.55

FieldFx.waveStanding = (ctx, x, y, q) ->
  x + math.sin(q.py * math.pi * 2 * ctx.freq) * math.cos(ctx.phi) * ctx.strength * ctx.m, y

FieldFx.flag = (ctx, x, y, q) ->
  ax = dirAxis ctx.opts.direction, q.px, q.py
  dvx, dvy = dirVector ctx.opts.direction
  w = math.sin(ax * math.pi * 2 * ctx.freq - ctx.phi) * ctx.strength * ax * ax * ctx.m
  x + (-dvy) * w, y + dvx * w

FieldFx.skiprope = (ctx, x, y, q) ->
  swing = math.sin(ctx.phi) * math.sin(q.px * math.pi) * ctx.strength * ctx.m
  lean = math.cos(ctx.phi) * math.sin(q.px * math.pi) * ctx.strength * 0.25 * ctx.m
  x + lean, y + swing

FieldFx.seaweed = (ctx, x, y, q) ->
  h = 1 - q.py
  sway = math.sin(ctx.phi + q.px * 2 + h * 2.4) * ctx.strength * h * h * ctx.m
  x + sway, y + math.abs(sway) * 0.15

FieldFx.twistWave = (ctx, x, y, q) ->
  ax = dirAxis ctx.opts.direction, q.px, q.py
  theta = math.sin(ax * math.pi * 2 * ctx.freq - ctx.phi) * (ctx.strength * math.pi / 180) * ctx.m
  horizontal = ctx.opts.direction == "Left to Right" or ctx.opts.direction == "Right to Left"
  if horizontal
    ry = y - ctx.geo.center.y
    x + ry * math.sin(theta) * 0.6, ctx.geo.center.y + ry * math.cos(theta)
  else
    rx = x - ctx.geo.center.x
    ctx.geo.center.x + rx * math.cos(theta), y + rx * math.sin(theta) * 0.6

FieldFx.whip = (ctx, x, y, q) ->
  ax = dirAxis ctx.opts.direction, q.px, q.py
  pos = ctx.phi / (math.pi * 2)
  pos = pos - math.floor pos
  d = ax - pos
  g = math.exp(-d * d * 60)
  w = g * ctx.strength * math.sin(ctx.phi * 3) * ctx.m
  dvx, dvy = dirVector ctx.opts.direction
  x + (-dvy) * w, y + dvx * w

rippleDisp = (ctx, x, y, ox, oy, phaseShift = 0) ->
  vx, vy, d = unitFromCenter x, y, {x: ox, y: oy}
  lam = math.max 8, ctx.maxd * 2 / math.max(0.5, ctx.freq)
  w = math.sin(d / lam * math.pi * 2 - ctx.phi + phaseShift) * ctx.strength
  atten = 1 / (1 + d / (ctx.maxd * 1.2))
  vx * w * atten, vy * w * atten

FieldFx.ripple = (ctx, x, y, q) ->
  dx, dy = rippleDisp ctx, x, y, ctx.geo.center.x, ctx.geo.center.y
  x + dx * ctx.m, y + dy * ctx.m

FieldFx.ripplePoint = (ctx, x, y, q) ->
  dx, dy = rippleDisp ctx, x, y, ctx.fx_center.x, ctx.fx_center.y
  x + dx * ctx.m, y + dy * ctx.m

FieldFx.rippleRain = (ctx, x, y, q) ->
  cycle = math.floor ctx.phi / (math.pi * 2)
  dx, dy = 0, 0
  for k = 0, 2
    LineOps.checkCancelled!
    ck = cycle - k
    hx = ctx.geo.bbox.min_x + noiseHash(ck, 11 + k, ctx.seed) * ctx.geo.width
    hy = ctx.geo.bbox.min_y + noiseHash(ck, 29 + k, ctx.seed + 3) * ctx.geo.height
    rx, ry = rippleDisp ctx, x, y, hx, hy, -k * 2.1
    fade = 1 - k / 3
    dx += rx * fade
    dy += ry * fade
  x + dx * 0.6 * ctx.m, y + dy * 0.6 * ctx.m

FieldFx.rippleCross = (ctx, x, y, q) ->
  ax, ay = rippleDisp ctx, x, y, ctx.fx_center.x, ctx.fx_center.y
  mirrorX = ctx.geo.center.x * 2 - ctx.fx_center.x
  mirrorY = ctx.geo.center.y * 2 - ctx.fx_center.y
  bx, by = rippleDisp ctx, x, y, mirrorX, mirrorY, math.pi
  x + (ax + bx) * 0.7 * ctx.m, y + (ay + by) * 0.7 * ctx.m

FieldFx.waveBounce = (ctx, x, y, q) ->
  w = math.abs(math.sin(q.px * math.pi * ctx.freq - ctx.phi)) * ctx.strength * ctx.m
  x, y - w

FieldFx.twistSway = (ctx, x, y, q) ->
  falloff = 1 - clamp(q.dist / (ctx.maxd * 1.4), 0, 1)
  theta = math.sin(ctx.phi) * (ctx.strength * math.pi / 180) * falloff * ctx.m
  rx, ry = x - ctx.geo.center.x, y - ctx.geo.center.y
  ca, sa = math.cos(theta), math.sin(theta)
  ctx.geo.center.x + rx * ca - ry * sa, ctx.geo.center.y + rx * sa + ry * ca

FieldFx.vortexSwirl = (ctx, x, y, q) ->
  falloff = 1 - clamp(q.dist / (ctx.maxd * 1.5), 0, 0.85)
  theta = ctx.phi * (ctx.strength / 60) * falloff * ctx.m
  rx, ry = x - ctx.geo.center.x, y - ctx.geo.center.y
  ca, sa = math.cos(theta), math.sin(theta)
  ctx.geo.center.x + rx * ca - ry * sa, ctx.geo.center.y + rx * sa + ry * ca

FieldFx.magnet = (ctx, x, y, q) ->
  vx, vy, d = unitFromCenter ctx.fx_center.x, ctx.fx_center.y, {x: x, y: y}
  pulse = 0.5 + 0.5 * math.sin(ctx.phi)
  force = ctx.strength * pulse * (1 - clamp(d / (ctx.maxd * 2.4), 0, 1)) * ctx.m
  x + vx * force, y + vy * force

FieldFx.pinchPulse = (ctx, x, y, q) ->
  force = (ctx.strength / 100) * (0.5 + 0.5 * math.sin(ctx.phi)) * ctx.m
  x - q.ux * q.dist * force, y - q.uy * q.dist * force

FieldFx.bulgePulse = (ctx, x, y, q) ->
  force = (ctx.strength / 100) * (0.5 + 0.5 * math.sin(ctx.phi)) * ctx.m
  x + q.ux * q.dist * force, y + q.uy * q.dist * force

FieldFx.heartbeatR = (ctx, x, y, q) ->
  tp = ctx.phi / (math.pi * 2)
  tp = tp - math.floor tp
  thump = math.exp(-((tp - 0.12) / 0.06) ^ 2) + 0.65 * math.exp(-((tp - 0.34) / 0.07) ^ 2)
  force = (ctx.strength / 100) * thump * ctx.m
  x + q.ux * q.dist * force, y + q.uy * q.dist * force

FieldFx.spring = (ctx, x, y, q) ->
  tp = ctx.phi / (math.pi * 2)
  tp = tp - math.floor tp
  osc = math.sin(tp * math.pi * 2 * 2) * math.exp(-tp * 3)
  sy = 1 + osc * (ctx.strength / 100) * ctx.m
  sx = 1 - osc * (ctx.strength / 140) * ctx.m
  floorY = ctx.geo.bbox.max_y
  cx = ctx.geo.center.x
  cx + (x - cx) * sx, floorY + (y - floorY) * sy

FieldFx.lens = (ctx, x, y, q) ->
  tp = ctx.phi / (math.pi * 2)
  tp = tp - math.floor tp
  lx = ctx.geo.bbox.min_x + tp * ctx.geo.width
  ly = ctx.fx_center.y
  vx, vy, d = unitFromCenter x, y, {x: lx, y: ly}
  radius = math.max 8, ctx.geo.width * 0.18
  g = math.exp(-(d / radius) ^ 2)
  x + vx * ctx.strength * g * 0.5 * ctx.m, y + vy * ctx.strength * g * 0.5 * ctx.m

FieldFx.shock = (ctx, x, y, q) ->
  tp = ctx.phi / (math.pi * 2)
  tp = tp - math.floor tp
  ring = tp * ctx.maxd * 1.3
  band = math.max 4, ctx.maxd * 0.1
  g = math.exp(-((q.dist - ring) / band) ^ 2) * (1 - tp)
  x + q.ux * ctx.strength * g * ctx.m, y + q.uy * ctx.strength * g * ctx.m

FieldFx.rings = (ctx, x, y, q) ->
  w = math.sin(q.dist / ctx.maxd * math.pi * ctx.freq - ctx.phi) * ctx.strength * ctx.m
  x + q.ux * w, y + q.uy * w

FieldFx.lagOrbit = (ctx, x, y, q) ->
  delay = q.dist / math.max(1, ctx.maxd) * 1.3
  x + math.cos(ctx.phi - delay) * ctx.strength * ctx.m, y + math.sin(ctx.phi - delay) * ctx.strength * 0.8 * ctx.m

edgeOut = (ctx, x, y, q, amount) ->
  x + q.nx * amount, y + q.ny * amount

FieldFx.rough = (ctx, x, y, q) ->
  amount = octaveNoise(x / ctx.scale + ctx.ca, y / ctx.scale + ctx.sa, ctx.seed, 3) * ctx.strength * 2.4 * ctx.m
  edgeOut ctx, x, y, q, amount

FieldFx.serrate = (ctx, x, y, q) ->
  amount = triWave(q.s * ctx.freq) * ctx.strength * 0.5 * ctx.m
  edgeOut ctx, x, y, q, amount

FieldFx.sawtooth = (ctx, x, y, q) ->
  ph = q.s * ctx.freq
  ph = ph - math.floor ph
  amount = (ph * 2 - 1) * ctx.strength * 0.6 * ctx.m
  x + q.nx * amount + q.tx * amount * 0.5, y + q.ny * amount + q.ty * amount * 0.5

FieldFx.bitten = (ctx, x, y, q) ->
  b = math.max(0, smoothNoise(q.s * ctx.freq, q.ci * 5.3, ctx.seed) - 0.6) / 0.4
  edgeOut ctx, x, y, q, -b * b * ctx.strength * 2 * ctx.m

FieldFx.corrode = (ctx, x, y, q) ->
  pit = math.abs(octaveNoise(x / ctx.scale + ctx.ca * 0.4, y / ctx.scale + ctx.sa * 0.4, ctx.seed, 3))
  edgeOut ctx, x, y, q, -pit * ctx.strength * 2.2 * ctx.m

FieldFx.charcoal = (ctx, x, y, q) ->
  grain = octaveNoise(x / ctx.scale, y / ctx.scale, ctx.seed, 4) * 1.6
  flick = (noiseHash(q.i * 3 + q.ci * 71, ctx.frame_key, ctx.seed) - 0.5) * 0.9
  edgeOut ctx, x, y, q, (grain + flick) * ctx.strength * ctx.m

FieldFx.chalk = (ctx, x, y, q) ->
  run = noiseHash(math.floor(q.s * ctx.freq), q.ci * 13, ctx.seed) - 0.5
  x + q.tx * run * ctx.strength * 2 * ctx.m + q.nx * run * ctx.strength * 0.6 * ctx.m, y + q.ty * run * ctx.strength * 2 * ctx.m + q.ny * run * ctx.strength * 0.6 * ctx.m

FieldFx.crayon = (ctx, x, y, q) ->
  w = (smoothNoise(q.s * ctx.freq + ctx.ca * 0.3, q.ci * 3.7, ctx.seed) - 0.5) * 2
  x + q.tx * w * ctx.strength * ctx.m + q.nx * w * ctx.strength * 0.8 * ctx.m, y + q.ty * w * ctx.strength * ctx.m + q.ny * w * ctx.strength * 0.8 * ctx.m

FieldFx.drybrush = (ctx, x, y, q) ->
  streak = (smoothNoise(q.s * 40, q.ci * 2.9 + ctx.ca * 0.2, ctx.seed) - 0.5) * 3
  x + q.tx * streak * ctx.strength * ctx.m + q.nx * streak * ctx.strength * 0.25 * ctx.m, y + q.ty * streak * ctx.strength * ctx.m + q.ny * streak * ctx.strength * 0.25 * ctx.m

FieldFx.spray = (ctx, x, y, q) ->
  amount = math.max(0, noiseHash(q.i * 11 + q.ci * 43, ctx.frame_key, ctx.seed) - 0.35) * ctx.strength * 1.8 * ctx.m
  edgeOut ctx, x, y, q, amount

FieldFx.living = (ctx, x, y, q) ->
  amount = (smoothNoise(q.s * ctx.freq - ctx.phi / math.pi, q.ci * 4.7, ctx.seed) - 0.5) * ctx.strength * 2.2 * ctx.m
  edgeOut ctx, x, y, q, amount

FieldFx.electricEdge = (ctx, x, y, q) ->
  cellk = math.floor(q.s * ctx.freq * 2) + ctx.frame_key * 13
  zig = (noiseHash(cellk, q.ci * 3, ctx.seed) - 0.5) * 2
  gate = noiseHash(cellk, ctx.frame_key + q.ci, ctx.seed + 9) > 0.45 and 1 or 0.15
  edgeOut ctx, x, y, q, zig * gate * ctx.strength * ctx.m

FieldFx.fur = (ctx, x, y, q) ->
  spike = math.abs(math.sin(q.s * math.pi * ctx.freq)) ^ 3
  sway = math.sin(ctx.phi + q.s * 20 + q.ci) * 0.35
  amount = spike * ctx.strength * (1 + sway) * ctx.m
  x + (q.nx + q.tx * sway) * amount, y + (q.ny + q.ty * sway) * amount

FieldFx.frost = (ctx, x, y, q) ->
  facet = math.floor(noiseHash(math.floor(q.s * ctx.freq), q.ci * 7, ctx.seed) * 3) - 1
  sparkle = noiseHash(math.floor(q.s * ctx.freq), ctx.frame_key, ctx.seed + 4) > 0.85 and 1.8 or 1
  edgeOut ctx, x, y, q, facet * ctx.strength * 0.6 * sparkle * ctx.m

FieldFx.torn = (ctx, x, y, q) ->
  g = math.max(0, smoothNoise(q.s * ctx.freq * 0.7, q.ci * 7.7, ctx.seed) - 0.55) * 2.2
  jag = (noiseHash(q.i, q.ci * 19, ctx.seed) - 0.5) * 0.7
  edgeOut ctx, x, y, q, -(g * (1 + jag)) * ctx.strength * 1.6 * ctx.m

FieldFx.stamp = (ctx, x, y, q) ->
  ph = q.s * ctx.freq
  ph = ph - math.floor ph
  notch = math.sqrt(math.max(0, 0.25 - (ph - 0.5) ^ 2)) * 2
  edgeOut ctx, x, y, q, -notch * ctx.strength * ctx.m

FieldFx.cloud = (ctx, x, y, q) ->
  lobe = math.abs(math.sin(q.s * math.pi * ctx.freq + q.ci)) ^ 1.4
  edgeOut ctx, x, y, q, lobe * ctx.strength * ctx.m

FieldFx.thorn = (ctx, x, y, q) ->
  ph = q.s * ctx.freq
  ph = ph - math.floor ph
  spike = math.max(0, 1 - math.abs(ph - 0.5) * 8)
  len = 0.5 + noiseHash(math.floor(q.s * ctx.freq), q.ci * 3, ctx.seed)
  edgeOut ctx, x, y, q, spike * len * ctx.strength * ctx.m

FieldFx.scallop = (ctx, x, y, q) ->
  arc = math.abs(math.sin(q.s * math.pi * ctx.freq)) - 0.5
  edgeOut ctx, x, y, q, arc * ctx.strength * ctx.m

FieldFx.bubble = (ctx, x, y, q) ->
  k = math.floor q.s * ctx.freq
  ph = ctx.phi / (math.pi * 2) + noiseHash(k, q.ci * 11, ctx.seed)
  ph = ph - math.floor ph
  grow = ph < 0.8 and ph / 0.8 or (1 - ph) / 0.2
  lobe = math.abs(math.sin(q.s * math.pi * ctx.freq))
  edgeOut ctx, x, y, q, lobe * grow * ctx.strength * ctx.m

FieldFx.spread = (ctx, x, y, q) ->
  amount = ctx.strength * (0.6 + smoothNoise(q.s * 9, q.ci * 3, ctx.seed)) * ctx.m
  edgeOut ctx, x, y, q, amount

FieldFx.dry = (ctx, x, y, q) ->
  pit = math.abs(octaveNoise(x / ctx.scale, y / ctx.scale, ctx.seed, 3)) * 1.4
  amount = -(0.5 + pit) * ctx.strength * ctx.m
  edgeOut ctx, x, y, q, amount

FieldFx.wet = (ctx, x, y, q) ->
  swell = (0.3 + 0.7 * (0.5 + 0.5 * math.sin(ctx.phi))) * ctx.strength * (0.5 + fieldNoise(ctx, x, y) * 0.9)
  wob = math.sin(q.s * math.pi * 6 + ctx.phi) * ctx.strength * 0.25
  x + q.nx * (swell + wob) * ctx.m, y + q.ny * (swell + wob) * ctx.m + swell * 0.12 * ctx.m

FieldFx.bloom = (ctx, x, y, q) ->
  ang = math.atan2 y - q.co.centroid.y, x - q.co.centroid.x
  lobes = 0.5 + 0.5 * math.sin(ang * ctx.freq + q.ci * 2.1)
  amount = ctx.strength * (0.3 + lobes) * (0.5 + smoothNoise(q.s * 5, q.ci, ctx.seed) * 0.8) * ctx.m
  edgeOut ctx, x, y, q, amount

FieldFx.absorb = (ctx, x, y, q) ->
  pull = ctx.strength * ctx.m
  x - q.nx * pull * 0.8, y - q.ny * pull * 0.8 + pull * 0.5

FieldFx.smoke = (ctx, x, y, q) ->
  swirl = octaveNoise(x / ctx.scale, y / ctx.scale - ctx.m * 2, ctx.seed, 3) * ctx.strength * 1.6
  x + swirl * ctx.m, y - ctx.strength * ctx.m * (1 + q.py) - math.abs(swirl) * ctx.m * 0.4

FieldFx.steam = (ctx, x, y, q) ->
  t = ctx.phi / math.pi
  lift = (0.5 + 0.5 * math.sin(ctx.phi + q.py * 4)) * ctx.strength
  wob = (smoothNoise(x / ctx.scale, y / ctx.scale + t, ctx.seed) - 0.5) * ctx.strength * 1.4
  x + wob * ctx.m, y - lift * (1 - q.py) * 0.6 * ctx.m

FieldFx.burn = (ctx, x, y, q) ->
  ax = dirAxis ctx.opts.direction, q.px, q.py
  finger = (smoothNoise(q.px * 6, q.py * 6, ctx.seed) - 0.5) * 0.25
  e = 1 - ctx.m + finger
  k = clamp((ax - e) / 0.22, 0, 1)
  return x, y if k <= 0
  ember = (noiseHash(q.i, ctx.frame_key, ctx.seed) - 0.5) * ctx.strength * k
  x - q.nx * k * ctx.strength * 1.6 + ember, y - q.ny * k * ctx.strength * 1.6 - k * ctx.strength * 0.8 + ember * 0.5

FieldFx.boiloff = (ctx, x, y, q) ->
  boil = fieldNoise(ctx, x, y) * ctx.strength * 2 * (0.4 + ctx.m * 1.6)
  x + boil, y + fieldNoise(ctx, x, y, 37, 17) * ctx.strength * 2 * (0.4 + ctx.m * 1.6) - ctx.m * ctx.m * ctx.strength * 3

FieldFx.bleed = (ctx, x, y, q) ->
  seedv = smoothNoise(q.s * ctx.freq, q.ci * 3.3, ctx.seed)
  k = clamp((seedv + 0.35 - ctx.m * 1.4) * 3, 0, 1)
  amount = (1 - k) * ctx.strength * (0.5 + seedv)
  edgeOut ctx, x, y, q, amount

FieldFx.frostCreep = (ctx, x, y, q) ->
  reach = (1 - ctx.m) * 1.25
  g = clamp((reach - q.sg) * 6, 0, 1)
  facet = math.floor(noiseHash(math.floor(q.s * ctx.freq), q.ci * 7, ctx.seed) * 3) - 1
  loose = (1 - g) * ctx.strength
  x + q.nx * facet * loose + (noiseHash(q.i, q.ci, ctx.seed) - 0.5) * loose, y + q.ny * facet * loose + (noiseHash(q.i + 5, q.ci, ctx.seed + 2) - 0.5) * loose

dripFinger = (ctx, q, cols) ->
  math.max(0, smoothNoise(q.px * cols, q.ci * 5.1, ctx.seed) - 0.55) / 0.45

FieldFx.drip = (ctx, x, y, q) ->
  lower = q.py * q.py
  f = dripFinger ctx, q, ctx.freq
  x, y + ctx.strength * ctx.m * lower * (0.25 + f * 2.2)

FieldFx.bottom = (ctx, x, y, q) ->
  lower = q.py ^ 3
  f = dripFinger ctx, q, ctx.freq
  x, y + ctx.strength * ctx.m * lower * (0.5 + f * 1.8) * 1.4

FieldFx.side = (ctx, x, y, q) ->
  edgeW = math.abs(q.px - 0.5) * 2
  f = math.max(0, smoothNoise(q.py * ctx.freq, q.ci * 4.3, ctx.seed) - 0.5) * 2.2
  run = ctx.strength * ctx.m * edgeW * (0.3 + f) * q.py
  x + (q.px < 0.5 and -run or run), y + run * 0.5

FieldFx.stain = (ctx, x, y, q) ->
  lower = q.py * q.py
  n = smoothNoise(q.px * 8, q.py * 8, ctx.seed)
  x + (n - 0.5) * ctx.strength * ctx.m, y + ctx.strength * ctx.m * lower * 2.2 * (0.5 + n)

meltFloor = (ctx, x, y, dx, dy) ->
  floorY = ctx.geo.bbox.max_y + ctx.strength * 0.25
  ny = y + dy
  if ny > floorY
    over = ny - floorY
    dx += (x >= ctx.geo.center.x and 1 or -1) * over * 0.55
    ny = floorY + math.min(over * 0.08, ctx.strength * 0.1)
  x + dx, ny

FieldFx.melt = (ctx, x, y, q) ->
  lower = q.py * q.py
  n = 0.6 + smoothNoise(q.px * 5, q.ci * 3, ctx.seed) * 0.8
  meltFloor ctx, x, y, 0, ctx.strength * ctx.m * (0.35 + lower * 1.3) * n

FieldFx.meltDiag = (ctx, x, y, q) ->
  lower = q.py * q.py
  n = 0.6 + smoothNoise(q.px * 5, q.ci * 3, ctx.seed) * 0.8
  drop = ctx.strength * ctx.m * (0.35 + lower * 1.3) * n
  meltFloor ctx, x, y, drop * 0.5, drop

FieldFx.rainwash = (ctx, x, y, q) ->
  col = math.floor q.px * ctx.freq
  g = noiseHash col, 3, ctx.seed
  x, y + ctx.strength * ctx.m * (0.25 + g * 1.5) * (0.4 + q.py)

FieldFx.slime = (ctx, x, y, q) ->
  stretch = 0.5 - 0.5 * math.cos(ctx.phi)
  lower = q.py ^ 3
  x + (x - ctx.geo.center.x) * lower * stretch * 0.22 * ctx.m, y + ctx.strength * stretch * lower * 2 * ctx.m

FieldFx.slimeSnap = (ctx, x, y, q) ->
  lower = q.py ^ 3
  x + (x - ctx.geo.center.x) * lower * ctx.m * 0.3, y + ctx.strength * ctx.m * lower * 2.4

FieldFx.puddle = (ctx, x, y, q) ->
  lower = q.py * q.py
  spread = (x - ctx.geo.center.x) * lower * ctx.m * 0.9
  squash = (ctx.geo.bbox.max_y - y) * ctx.m * lower * 0.45
  x + spread, y + squash + ctx.strength * ctx.m * lower * 0.3

FieldFx.icicle = (ctx, x, y, q) ->
  ph = q.px * ctx.freq
  ph = ph - math.floor ph
  spike = math.max(0, 1 - math.abs(ph - 0.5) * 5) ^ 1.5
  len = 0.4 + noiseHash(math.floor(q.px * ctx.freq), 7, ctx.seed)
  x, y + ctx.strength * ctx.m * spike * len * q.py * 2

FieldFx.candle = (ctx, x, y, q) ->
  sag = 0.5 - 0.5 * math.cos(ctx.phi)
  lower = q.py * q.py
  n = 0.5 + smoothNoise(q.px * 4, q.ci * 2, ctx.seed)
  meltFloor ctx, x, y, 0, ctx.strength * sag * lower * n * ctx.m

FieldFx.dripLoop = (ctx, x, y, q) ->
  tp = ctx.phi / (math.pi * 2)
  tp = tp - math.floor tp
  fall = tp < 0.7 and tp / 0.7 or 1 + ((tp - 0.7) / 0.3) ^ 2 * 2
  lower = q.py * q.py
  f = dripFinger ctx, q, ctx.freq
  x, y + ctx.strength * fall * lower * f * 2 * ctx.m

FieldFx.pathWave = (ctx, x, y, q) ->
  w = math.sin(q.s * math.pi * 2 * ctx.freq - ctx.phi) * ctx.strength * ctx.m
  x + q.nx * w, y + q.ny * w

FieldFx.pathBulge = (ctx, x, y, q) ->
  head = ctx.phi / (math.pi * 2)
  head = head - math.floor head
  d = math.abs q.s - head
  d = math.min d, 1 - d
  g = math.exp(-(d * 9) ^ 2)
  x + q.nx * g * ctx.strength * ctx.m, y + q.ny * g * ctx.strength * ctx.m

FieldFx.pathPeristalsis = (ctx, x, y, q) ->
  w = math.max(0, math.sin(q.s * math.pi * 2 * ctx.freq - ctx.phi)) ^ 3 * ctx.strength * ctx.m
  x + q.nx * w, y + q.ny * w

FieldFx.pathFlow = (ctx, x, y, q) ->
  flow = ctx.strength * (0.6 + 0.4 * math.sin(q.s * math.pi * 4 - ctx.phi)) * ctx.m
  x + q.tx * flow, y + q.ty * flow

wipeJitter = (ctx, q, k) ->
  jx = (smoothNoise(q.px * 9, q.py * 9, ctx.seed + 9) - 0.5) * ctx.strength * 0.18 * k
  jy = (smoothNoise(q.px * 9 + 3, q.py * 9 - 4, ctx.seed + 13) - 0.5) * ctx.strength * 0.18 * k
  jx, jy

dirProject = (ctx, e, x, y) ->
  bbox = ctx.geo.bbox
  switch ctx.opts.direction
    when "Right to Left" then bbox.max_x - ctx.geo.width * e, y
    when "Top to Bottom" then x, bbox.min_y + ctx.geo.height * e
    when "Bottom to Top" then x, bbox.max_y - ctx.geo.height * e
    else bbox.min_x + ctx.geo.width * e, y

dirWipe = (ctx, x, y, q, fnoise) ->
  e = clamp 1 - ctx.m, 0, 1
  ax = dirAxis(ctx.opts.direction, q.px, q.py) + fnoise
  return x, y if ax <= e
  k = clamp (ax - e) / math.max(0.05, 1 - e), 0, 1
  tx, ty = dirProject ctx, clamp(e + fnoise, 0, 1), x, y
  jx, jy = wipeJitter ctx, q, k
  x + (tx - x) * k + jx, y + (ty - y) * k + jy

FieldFx.wipeOrganic = (ctx, x, y, q) ->
  fnoise = (smoothNoise(q.px * 5 + 3, q.py * 5, ctx.seed) - 0.5) * 0.3
  dirWipe ctx, x, y, q, fnoise

FieldFx.wipeWavy = (ctx, x, y, q) ->
  perp = (ctx.opts.direction == "Left to Right" or ctx.opts.direction == "Right to Left") and q.py or q.px
  fnoise = math.sin(perp * math.pi * 2 * ctx.freq + ctx.prog * math.pi) * 0.16
  dirWipe ctx, x, y, q, fnoise

FieldFx.wipeShaky = (ctx, x, y, q) ->
  fnoise = (smoothNoise(q.px * 6, q.py * 6 + ctx.frame_key * 0.618, ctx.seed) - 0.5) * 0.34
  dirWipe ctx, x, y, q, fnoise

FieldFx.wipeInk = (ctx, x, y, q) ->
  perp = (ctx.opts.direction == "Left to Right" or ctx.opts.direction == "Right to Left") and q.py or q.px
  finger = math.max(0, smoothNoise(perp * ctx.freq, q.ci * 2.3, ctx.seed) - 0.42) * 1.9
  dirWipe ctx, x, y, q, -finger * 0.45

FieldFx.wipeDiag = (ctx, x, y, q) ->
  e = clamp 1 - ctx.m, 0, 1
  fnoise = (smoothNoise(q.px * 5, q.py * 5, ctx.seed) - 0.5) * 0.22
  ax = (q.px + q.py) / 2 + fnoise
  return x, y if ax <= e
  k = clamp (ax - e) / math.max(0.05, 1 - e), 0, 1
  span = (ctx.geo.width + ctx.geo.height) * 0.5
  shift = (ax - e) * span * 0.707 * k
  jx, jy = wipeJitter ctx, q, k
  x - shift + jx, y - shift + jy

FieldFx.wipeIris = (ctx, x, y, q) ->
  e = clamp 1 - ctx.m, 0, 1
  vx, vy, d = unitFromCenter x, y, ctx.fx_center
  reach = ctx.maxd * 1.35
  fnoise = (smoothNoise(q.px * 6, q.py * 6, ctx.seed) - 0.5) * 0.2
  ax = d / math.max(1, reach) + fnoise
  return x, y if ax <= e
  k = clamp (ax - e) / math.max(0.05, 1 - e), 0, 1
  targetD = clamp(e + fnoise, 0, 1) * reach
  jx, jy = wipeJitter ctx, q, k
  x + (ctx.fx_center.x + vx * targetD - x) * k + jx, y + (ctx.fx_center.y + vy * targetD - y) * k + jy

FieldFx.wipeSwirl = (ctx, x, y, q) ->
  e = clamp 1 - ctx.m, 0, 1
  ang = math.atan2 y - ctx.geo.center.y, x - ctx.geo.center.x
  a0 = (ang + math.pi) / (math.pi * 2)
  fnoise = (smoothNoise(q.px * 4, q.py * 4, ctx.seed) - 0.5) * 0.12
  ax = clamp a0 + fnoise, 0, 1
  return x, y if ax <= e
  k = clamp (ax - e) / math.max(0.05, 1 - e), 0, 1
  thetaF = e * math.pi * 2 - math.pi
  theta = ang + (thetaF - ang) * k + k * 0.9
  d = q.dist * (1 - k * 0.3)
  jx, jy = wipeJitter ctx, q, k
  ctx.geo.center.x + math.cos(theta) * d + jx, ctx.geo.center.y + math.sin(theta) * d + jy

FieldFx.dsNoise = (ctx, x, y, q) ->
  r = 1 - ctx.m
  h1 = noiseHash(q.i * 3 + q.ci * 101, 7, ctx.seed) - 0.5
  h2 = noiseHash(q.i * 3 + q.ci * 101, 19, ctx.seed + 5) - 0.5
  stagger = noiseHash(q.i + q.ci * 47, 3, ctx.seed + 11)
  k = staggerAmount r, stagger, 0.85
  sx = x + h1 * ctx.strength * 3
  sy = y + h2 * ctx.strength * 3
  sx + (x - sx) * k, sy + (y - sy) * k

FieldFx.dsErode = (ctx, x, y, q) ->
  r = 1 - ctx.m
  g = smoothNoise(x / math.max(8, ctx.scale * 0.3), y / math.max(8, ctx.scale * 0.3), ctx.seed)
  eat = clamp((g + 0.2 - r * 1.4) * 2.4, 0, 1) * ctx.m
  crumb = (noiseHash(q.i, q.ci * 7, ctx.seed) - 0.5) * eat * ctx.strength * 0.5
  x - q.nx * eat * ctx.strength + crumb, y - q.ny * eat * ctx.strength + crumb * 0.7

FieldFx.dsSplit = (ctx, x, y, q) ->
  e = clamp 1 - ctx.m, 0, 1
  ax0 = dirAxis ctx.opts.direction, q.px, q.py
  side = ax0 >= 0.5 and 1 or -1
  ax = math.abs(ax0 - 0.5) * 2
  fnoise = (smoothNoise(q.px * 5, q.py * 5, ctx.seed) - 0.5) * 0.18
  ax += fnoise
  return x, y if ax <= e
  k = clamp (ax - e) / math.max(0.05, 1 - e), 0, 1
  targetAx0 = 0.5 + side * clamp(e + fnoise, 0, 1) * 0.5
  tx, ty = dirProject ctx, targetAx0, x, y
  jx, jy = wipeJitter ctx, q, k
  x + (tx - x) * k + jx, y + (ty - y) * k + jy

FieldFx.dsBand = (ctx, x, y, q) ->
  ax = dirAxis ctx.opts.direction, q.px, q.py
  band = math.floor ax * ctx.freq
  sign = band % 2 == 0 and 1 or -1
  stagger = noiseHash(band, 5, ctx.seed) * 0.3
  k = clamp ctx.m * (1 + stagger) - stagger, 0, 1
  horizontal = ctx.opts.direction == "Left to Right" or ctx.opts.direction == "Right to Left"
  if horizontal
    x, y + sign * k * ctx.geo.height * 1.4
  else
    x + sign * k * ctx.geo.width * 1.4, y

FieldFx.dsChecker = (ctx, x, y, q) ->
  cells = math.max 2, ctx.freq
  cw = ctx.geo.width / cells
  ch = ctx.geo.height / math.max(1, round(cells * ctx.geo.height / math.max(1, ctx.geo.width)))
  ch = cw if ch <= 0
  cxi = math.floor (x - ctx.geo.bbox.min_x) / math.max(1, cw)
  cyi = math.floor (y - ctx.geo.bbox.min_y) / math.max(1, ch)
  ccX = ctx.geo.bbox.min_x + (cxi + 0.5) * cw
  ccY = ctx.geo.bbox.min_y + (cyi + 0.5) * ch
  stagger = noiseHash(cxi * 7 + cyi * 13, (cxi + cyi) % 2, ctx.seed)
  r = 1 - ctx.m
  k = staggerAmount r, stagger, 0.8
  ccX + (x - ccX) * k, ccY + (y - ccY) * k

FieldFx.dsCrystal = (ctx, x, y, q) ->
  qsize = 1 + ctx.m * ctx.strength
  sx = math.floor(x / qsize + 0.5) * qsize
  sy = math.floor(y / qsize + 0.5) * qsize
  k = clamp ctx.m * 1.4, 0, 1
  x + (sx - x) * k, y + (sy - y) * k

axisIsHorizontal = (direction) ->
  direction == "Left to Right" or direction == "Right to Left"

FieldFx.accordion = (ctx, x, y, q) ->
  ax = dirAxis ctx.opts.direction, q.px, q.py
  pleat = triWave(ax * ctx.freq) * ctx.strength * ctx.m
  ax2 = ax * (1 - 0.85 * ctx.m)
  tx, ty = dirProject ctx, ax2, x, y
  if axisIsHorizontal ctx.opts.direction
    tx, y + pleat
  else
    x + pleat, ty

FieldFx.roll = (ctx, x, y, q) ->
  ax = dirAxis ctx.opts.direction, q.px, q.py
  front = 1 - ctx.m
  return x, y if ax <= front
  horizontal = axisIsHorizontal ctx.opts.direction
  axisLen = horizontal and ctx.geo.width or ctx.geo.height
  r = math.max 6, ctx.strength
  dBeyond = (ax - front) * axisLen
  theta = dBeyond / r
  newAx = front + (r * math.sin(theta)) / math.max(1, axisLen)
  lift = r * (1 - math.cos(theta)) * 0.35
  tx, ty = dirProject ctx, newAx, x, y
  if horizontal
    tx, y - lift
  else
    x - lift, ty

FieldFx.twistc = (ctx, x, y, q) ->
  ax = dirAxis ctx.opts.direction, q.px, q.py
  theta = (ax - 0.5) * ctx.freq * math.pi * 2 * ctx.m
  shrink = 1 - 0.3 * ctx.m
  if axisIsHorizontal ctx.opts.direction
    ry = (y - ctx.geo.center.y) * shrink
    x + ry * math.sin(theta) * 0.7, ctx.geo.center.y + ry * math.cos(theta)
  else
    rx = (x - ctx.geo.center.x) * shrink
    ctx.geo.center.x + rx * math.cos(theta), y + rx * math.sin(theta) * 0.7

FieldFx.fan = (ctx, x, y, q) ->
  ax = dirAxis ctx.opts.direction, q.px, q.py
  bbox = ctx.geo.bbox
  local pivotX, pivotY, sign
  switch ctx.opts.direction
    when "Right to Left"
      pivotX, pivotY, sign = bbox.max_x, bbox.max_y, 1
    when "Top to Bottom"
      pivotX, pivotY, sign = bbox.min_x, bbox.min_y, -1
    when "Bottom to Top"
      pivotX, pivotY, sign = bbox.min_x, bbox.max_y, 1
    else
      pivotX, pivotY, sign = bbox.min_x, bbox.max_y, -1
  alpha = (ctx.strength * math.pi / 180) * ctx.m * (0.15 + 0.85 * (1 - ax)) * sign
  rx, ry = x - pivotX, y - pivotY
  ca, sa = math.cos(alpha), math.sin(alpha)
  pivotX + rx * ca - ry * sa, pivotY + rx * sa + ry * ca

FieldFx.blinds = (ctx, x, y, q) ->
  ax = dirAxis ctx.opts.direction, q.px, q.py
  slats = math.max 2, ctx.freq
  slat = math.floor ax * slats
  wS = ax * slats - slat
  w2 = 0.5 + (wS - 0.5) * (1 - ctx.m)
  ax2 = (slat + w2) / slats
  tx, ty = dirProject ctx, ax2, x, y
  if axisIsHorizontal ctx.opts.direction
    tx, y
  else
    x, ty

FieldFx.crumple = (ctx, x, y, q) ->
  px, py = x, y
  folds = math.max 2, round ctx.freq
  for k = 1, folds
    LineOps.checkCancelled!
    ang = noiseHash(k, 3, ctx.seed) * math.pi * 2
    nkx, nky = math.cos(ang), math.sin(ang)
    ckx = ctx.geo.center.x + (noiseHash(k, 7, ctx.seed) - 0.5) * ctx.geo.width * 0.6
    cky = ctx.geo.center.y + (noiseHash(k, 11, ctx.seed) - 0.5) * ctx.geo.height * 0.6
    d = (px - ckx) * nkx + (py - cky) * nky
    if d > 0
      w = (0.4 + 0.6 * noiseHash(k, 17, ctx.seed)) * ctx.m
      px -= nkx * d * 1.6 * w
      py -= nky * d * 1.6 * w
  shrink = 1 - 0.3 * ctx.m
  ctx.geo.center.x + (px - ctx.geo.center.x) * shrink, ctx.geo.center.y + (py - ctx.geo.center.y) * shrink

FieldFx.jelly = (ctx, x, y, q) ->
  t = ctx.spec.phase == "out" and 1 - ctx.prog or ctx.prog
  ring = math.sin(t * math.pi * 2 * (ctx.freq + 1.5)) * math.exp(-t * 5)
  dy = ring * (1 - q.py) * ctx.strength * 0.7
  dx = -ring * (q.px - 0.5) * ctx.strength * 1.1
  drop = math.max(0, 1 - t * 4)
  x + dx, y + dy - drop * drop * ctx.geo.height * 1.2

FieldFx.burst = (ctx, x, y, q) ->
  h = noiseHash(q.i * 3 + q.ci * 91, 5, ctx.seed)
  dExtra = ctx.m * ctx.m * ctx.strength * (0.6 + h * 0.9)
  theta = ctx.m * (h - 0.5) * 1.4
  rx, ry = x - ctx.geo.center.x, y - ctx.geo.center.y
  ca, sa = math.cos(theta), math.sin(theta)
  nx0 = ctx.geo.center.x + rx * ca - ry * sa
  ny0 = ctx.geo.center.y + rx * sa + ry * ca
  nx0 + q.ux * dExtra, ny0 + q.uy * dExtra

FieldFx.vortexp = (ctx, x, y, q) ->
  h = noiseHash(q.ci * 31, 3, ctx.seed)
  r = q.dist * (1 + ctx.m * (ctx.strength / 30))
  ang = math.atan2(y - ctx.geo.center.y, x - ctx.geo.center.x) + ctx.m * (2.2 + h)
  ctx.geo.center.x + math.cos(ang) * r, ctx.geo.center.y + math.sin(ang) * r

FieldFx.sag = (ctx, x, y, q) ->
  n = 0.6 + smoothNoise(q.px * 4, q.ci * 2, ctx.seed) * 0.8
  x + (q.px - 0.5) * ctx.strength * ctx.m * 0.3, y + ctx.strength * ctx.m * q.py * q.py * n

FieldFx.wind = (ctx, x, y, q) ->
  dvx, dvy = dirVector ctx.opts.direction
  h = noiseHash(q.i + q.ci * 61, 9, ctx.seed)
  tat = math.max(0, octaveNoise(q.px * 3, q.py * 3, ctx.seed, 2) * 2 + 0.3)
  amp = ctx.m * ctx.m * ctx.strength * (0.5 + q.py * 0.5) * (0.6 + h) * tat
  x + dvx * amp + (h - 0.5) * ctx.m * ctx.strength * 0.2, y + dvy * amp + (noiseHash(q.i, 3, ctx.seed) - 0.5) * ctx.m * ctx.strength * 0.35

FieldFx.shiver = (ctx, x, y, q) ->
  dx = (noiseHash(q.i * 5 + q.ci * 113, ctx.frame_key, ctx.seed) - 0.5) * 2
  dy = (noiseHash(q.i * 5 + q.ci * 113, ctx.frame_key + 3, ctx.seed + 7) - 0.5) * 2
  x + dx * ctx.strength * ctx.m, y + dy * ctx.strength * ctx.m

FieldFx.slam = (ctx, x, y, q) ->
  s = 1 + ctx.m * 2
  g = math.exp(-((ctx.prog - 0.3) * 6) ^ 2)
  ring = g * math.sin(math.min(1.2, q.dist / math.max(1, ctx.maxd)) * math.pi * 2 - ctx.prog * 6) * ctx.strength * 0.4
  nx0 = ctx.geo.center.x + (x - ctx.geo.center.x) * s
  ny0 = ctx.geo.center.y + (y - ctx.geo.center.y) * s
  nx0 + q.ux * ring, ny0 + q.uy * ring

FieldFx.kickback = (ctx, x, y, q) ->
  dvx, dvy = dirVector ctx.opts.direction
  recoil = math.sin(math.min(1, ctx.prog / 0.3) * math.pi) * ctx.strength * 0.25
  shoot = math.max(0, (ctx.prog - 0.3) / 0.7) ^ 2 * ctx.strength * 3
  x - dvx * recoil + dvx * shoot, y - dvy * recoil + dvy * shoot

FieldFx.gCorrupt = (ctx, x, y, q) ->
  gate = noiseHash(ctx.frame_key, q.ci * 3, ctx.seed) < 0.4
  return x, y unless gate
  dx = (smoothNoise(math.floor(y / 8), ctx.frame_key * 3, ctx.seed) - 0.5) * ctx.strength * 3 * ctx.m
  dy = (noiseHash(q.i, ctx.frame_key, ctx.seed + 3) - 0.5) * ctx.strength * 0.5 * ctx.m
  x + dx, y + dy

FieldFx.gStatic = (ctx, x, y, q) ->
  band = math.floor q.py * (6 + ctx.freq)
  g = noiseHash(band, ctx.frame_key, ctx.seed)
  return x, y if g <= 0.7
  rag = (noiseHash(q.i, ctx.frame_key, ctx.seed + 5) - 0.5) * ctx.strength * 0.9
  x + (g - 0.85) * ctx.strength * 6 * ctx.m + rag, y + rag * 0.4

FieldFx.gWeave = (ctx, x, y, q) ->
  row = math.floor q.py * ctx.freq * 2
  sign = row % 2 == 0 and 1 or -1
  x + sign * ctx.strength * (0.5 + 0.5 * math.sin(ctx.phi)) * ctx.m, y

FieldFx.gSpikes = (ctx, x, y, q) ->
  sp = noiseHash(q.i * 7 + q.ci * 113, ctx.frame_key, ctx.seed)
  return x, y if sp <= 0.985
  amp = ctx.strength * (1 + noiseHash(q.i, ctx.frame_key + 1, ctx.seed) * 2) * ctx.m
  x + q.nx * amp, y + q.ny * amp

FieldFx.gDropout = (ctx, x, y, q) ->
  cluster = math.floor q.s * 12
  gate = noiseHash(cluster + q.ci * 7, ctx.frame_key, ctx.seed) < 0.15
  return x, y unless gate
  cc = q.co.centroid
  x + (cc.x - x) * 0.8 * ctx.m, y + (cc.y - y) * 0.8 * ctx.m

FieldFx.gQuant = (ctx, x, y, q) ->
  qsize = 2 + (0.5 + 0.5 * math.sin(ctx.phi)) * ctx.strength * ctx.m
  math.floor(x / qsize + 0.5) * qsize, math.floor(y / qsize + 0.5) * qsize

FieldFx.gStorm = (ctx, x, y, q) ->
  dx = (noiseHash(q.i, ctx.frame_key, ctx.seed) - 0.5) * ctx.strength * 2 * ctx.m
  dy = (noiseHash(q.i * 3, ctx.frame_key, ctx.seed + 9) - 0.5) * ctx.strength * 2 * ctx.m
  qs = 2
  math.floor((x + dx) / qs + 0.5) * qs, math.floor((y + dy) / qs + 0.5) * qs

SubpathFx = {}

SubpathFx.prefixParallel = (ctx, q) -> q.s <= ctx.reveal
SubpathFx.prefixSequential = (ctx, q) -> q.sg <= ctx.reveal
SubpathFx.prefixChunk = (ctx, q) ->
  chunks = math.max 2, round ctx.freq * ctx.geo.cn
  math.floor(q.sg * chunks) / chunks < ctx.reveal
SubpathFx.prefixRandom = (ctx, q) ->
  smoothNoise(q.i * 0.35, q.ci * 3.1, ctx.seed) <= ctx.reveal * 1.02
SubpathFx.prefixDash = (ctx, q) ->
  ph = q.s * ctx.freq
  ph - math.floor(ph) < ctx.reveal * 1.01
SubpathFx.snake = (ctx, q) ->
  head = ctx.phi / (math.pi * 2)
  d = (q.sg - head) % 1
  d < clamp(ctx.strength / 100, 0.05, 0.9)
SubpathFx.snakeChase = (ctx, q) ->
  head = ctx.phi / (math.pi * 2)
  lf = clamp(ctx.strength / 100, 0.05, 0.45)
  d1 = (q.sg - head) % 1
  d2 = (q.sg + head) % 1
  d1 < lf or d2 < lf
SubpathFx.dashMarch = (ctx, q) ->
  ph = q.s * ctx.freq - ctx.phi / (math.pi * 2)
  ph - math.floor(ph) < 0.55
SubpathFx.morse = (ctx, q) ->
  cell = math.floor q.s * ctx.freq * 2
  noiseHash(cell, q.ci * 5 + math.floor(ctx.phi / math.pi), ctx.seed) < 0.62
SubpathFx.segFlicker = (ctx, q) ->
  cell = math.floor(q.s * 10) + q.ci * 31
  noiseHash(cell, ctx.frame_key, ctx.seed) < 0.82
SubpathFx.pathRetract = (ctx, q) ->
  tp = ctx.phi / (math.pi * 2)
  tp = tp - math.floor tp
  duty = 0.12 + 0.76 * (0.5 - 0.5 * math.cos(tp * math.pi * 2))
  d = (q.sg - tp * 2) % 1
  d < duty
SubpathFx.crawl = (ctx, q) ->
  ph = q.sg * ctx.freq - ctx.phi / (math.pi * 2)
  keep = ph - math.floor(ph) < 0.35
  return false unless keep
  w = math.sin(ctx.phi * 2 + q.sg * 40) * ctx.strength
  true, q.nx * w, q.ny * w

applyDots = (geo, ctx, label) ->
  offset = ctx.phi / (math.pi * 2)
  offset = offset - math.floor offset
  out = {}
  r = math.max 1.2, ctx.strength
  for co in *geo.contours
    dots = math.max 2, round ctx.freq * (co.len / geo.total_len) * math.max(1, geo.cn * 0.8)
    si = 1
    for j = 0, dots - 1
      d = ((j + offset) / dots) * co.len
      while si < co.n and co.cum[si + 1] < d
        si += 1
      si = 1 if d < co.cum[si]
      a = co.pts[si]
      b = co.pts[si == co.n and 1 or si + 1]
      segD = co.segs[si]
      t = segD > 0 and (d - co.cum[si]) / segD or 0
      x = a.x + (b.x - a.x) * t
      y = a.y + (b.y - a.y) * t
      out[#out + 1] = {
        {x: x - r, y: y}
        {x: x, y: y - r}
        {x: x + r, y: y}
        {x: x, y: y + r}
      }
  if #out == 0
    p = geo.contours[1].pts[1]
    out[1] = {{x: p.x, y: p.y}, {x: p.x, y: p.y}}
  guardShape contoursToShape(out), label

applySubpath = (geo, ctx, mode, label = "Subpath shape") ->
  return applyDots geo, ctx, label if mode == "dot_march"
  fx = SubpathFx[mode]
  return nil, "Unknown subpath mode '#{mode}'." unless fx
  ctx.reveal = 1
  if ctx.spec.phase == "in"
    ctx.reveal = ctx.eased
  elseif ctx.spec.phase == "out"
    ctx.reveal = 1 - ctx.eased
  bbox = geo.bbox
  out = {}
  q = {}
  for ci, co in ipairs geo.contours
    LineOps.checkCancelled!
    run = nil
    for i = 1, co.n
      LineOps.checkCancelled!
      p = co.pts[i]
      q.px = normSpan p.x, bbox.min_x, bbox.max_x
      q.py = normSpan p.y, bbox.min_y, bbox.max_y
      q.s = co.cum[i] / math.max(0.001, co.len)
      q.sg = (co.offset + co.cum[i]) / geo.total_len
      nor = co.normals[i]
      q.nx, q.ny = nor.x, nor.y
      q.ci, q.i, q.n = ci, i, co.n
      keep, dx, dy = fx ctx, q
      if keep
        unless run
          run = {}
          out[#out + 1] = run
        run[#run + 1] = {x: p.x + (dx or 0), y: p.y + (dy or 0)}
      else
        run = nil
  cleaned = {}
  for run in *out
    cleaned[#cleaned + 1] = run if #run >= 2
  if #cleaned == 0
    p = geo.contours[1].pts[1]
    cleaned[1] = {{x: p.x, y: p.y}, {x: p.x, y: p.y}}
  guardShape contoursToShape(cleaned), label

ContourFx = {}

contourLocal = (ctx, rank) ->
  la = staggerAmount ctx.prog, rank, 0.6
  el = curveRatio la, ctx.spec.curve
  if ctx.spec.phase == "in" then 1 - el, el else el, el

ContourFx.cBob = (ctx, co, ci, rank) ->
  {dy: math.sin(ctx.phi + ci * 0.9) * ctx.strength * 0.6}
ContourFx.cSway = (ctx, co, ci, rank) ->
  {rot: math.sin(ctx.phi + ci * 0.9) * ctx.strength * math.pi / 180}
ContourFx.cOrbit = (ctx, co, ci, rank) ->
  ang = ctx.phi + ci * math.pi * 2 / math.max(1, ctx.geo.cn)
  {dx: math.cos(ang) * ctx.strength * 0.5, dy: math.sin(ang) * ctx.strength * 0.5}
ContourFx.cBreathe = (ctx, co, ci, rank) ->
  s = 1 + math.sin(ctx.phi + ci * 0.8) * ctx.strength / 100
  {sx: s, sy: s}
ContourFx.cWave = (ctx, co, ci, rank) ->
  pos = ctx.phi / (math.pi * 2)
  pos = (pos - math.floor(pos)) * 1.4 - 0.2
  d = rank - pos
  {dy: -math.exp(-(d * 3.5) ^ 2) * ctx.strength}
ContourFx.cHeart = (ctx, co, ci, rank) ->
  tp = ctx.phi / (math.pi * 2) - rank * 0.12
  tp = tp - math.floor tp
  thump = math.exp(-((tp - 0.12) / 0.06) ^ 2) + 0.65 * math.exp(-((tp - 0.34) / 0.07) ^ 2)
  s = 1 + thump * ctx.strength / 100
  {sx: s, sy: s}
ContourFx.cJolt = (ctx, co, ci, rank) ->
  h = noiseHash(ci * 7, ctx.frame_key, ctx.seed)
  return {} if h >= 0.3
  qs = 2
  dx = math.floor(((noiseHash(ci, ctx.frame_key, ctx.seed + 3) - 0.5) * ctx.strength * 2) / qs + 0.5) * qs
  dy = math.floor(((noiseHash(ci, ctx.frame_key, ctx.seed + 9) - 0.5) * ctx.strength) / qs + 0.5) * qs
  {dx: dx, dy: dy}
ContourFx.cBlink = (ctx, co, ci, rank) ->
  {vis: noiseHash(ci * 13, ctx.frame_key, ctx.seed) > 0.25}
ContourFx.cCarousel = (ctx, co, ci, rank) ->
  ang0 = math.pi * 2 * rank
  ang = ang0 + ctx.phi
  {dx: (math.cos(ang) - math.cos(ang0)) * ctx.strength, dy: (math.sin(ang) - math.sin(ang0)) * ctx.strength * 0.6}
ContourFx.cPop = (ctx, co, ci, rank) ->
  _, el = contourLocal ctx, rank
  s = math.max 0.001, ctx.spec.phase == "in" and el or 1 - el
  {sx: s, sy: s}
ContourFx.cDrop = (ctx, co, ci, rank) ->
  am = contourLocal ctx, rank
  h = noiseHash(ci * 3, 7, ctx.seed)
  sign = ctx.spec.phase == "in" and -1 or 1
  {dy: sign * am * ctx.strength * (1 + h * 0.4), rot: sign * am * 0.25 * (h - 0.5)}
ContourFx.cSlide = (ctx, co, ci, rank) ->
  am = contourLocal ctx, rank
  dvx, dvy = dirVector ctx.opts.direction
  sign = ctx.spec.phase == "in" and -1 or 1
  {dx: sign * dvx * am * ctx.strength, dy: sign * dvy * am * ctx.strength}
ContourFx.cSpin = (ctx, co, ci, rank) ->
  am = contourLocal ctx, rank
  sign = noiseHash(ci * 11, 3, ctx.seed) > 0.5 and 1 or -1
  {rot: am * math.pi * 2 * sign, sx: math.max(0.05, 1 - am * 0.4), sy: math.max(0.05, 1 - am * 0.4)}
ContourFx.cScatter = (ctx, co, ci, rank) ->
  am = contourLocal ctx, rank
  h = noiseHash(ci * 17, 5, ctx.seed)
  ang = h * math.pi * 2
  {dx: math.cos(ang) * am * ctx.strength, dy: math.sin(ang) * am * ctx.strength, rot: am * 6 * (h - 0.5)}
ContourFx.cFlip = (ctx, co, ci, rank) ->
  am, el = contourLocal ctx, rank
  sx = if ctx.spec.phase == "in" then math.sin(el * math.pi / 2) else math.cos(el * math.pi / 2)
  {sx: math.max(0.02, sx), rot: am * 0.2}
ContourFx.cZoom = (ctx, co, ci, rank) ->
  am = contourLocal ctx, rank
  s = 1 + am * ctx.strength / 60
  {sx: s, sy: s}
ContourFx.cType = (ctx, co, ci, rank) ->
  order = (ci - 1) / math.max(1, ctx.geo.cn)
  visible = if ctx.spec.phase == "in" then order < ctx.prog + GeometryEpsilon else order < 1 - ctx.prog - GeometryEpsilon
  {vis: visible}
ContourFx.cDomino = (ctx, co, ci, rank) ->
  am = contourLocal ctx, rank
  dvx, dvy = dirVector ctx.opts.direction
  sign = (dvx + dvy) >= 0 and 1 or -1
  {rot: am * math.pi / 2 * sign, px: (co.cbox.min_x + co.cbox.max_x) / 2, py: co.cbox.max_y}

applyContour = (geo, ctx, mode, label = "Contour shape") ->
  fx = ContourFx[mode]
  return nil, "Unknown contour mode '#{mode}'." unless fx
  out = {}
  for ci, co in ipairs geo.contours
    LineOps.checkCancelled!
    rank = ctx.ranks[ci] or 0
    t = fx(ctx, co, ci, rank) or {}
    continue if t.vis == false
    px = t.px or co.centroid.x
    py = t.py or co.centroid.y
    rot = t.rot or 0
    sx = t.sx or 1
    sy = t.sy or 1
    dx = t.dx or 0
    dy = t.dy or 0
    ca, sa = math.cos(rot), math.sin(rot)
    newPts = {}
    for i = 1, co.n
      LineOps.checkCancelled!
      p = co.pts[i]
      rx = (p.x - px) * sx
      ry = (p.y - py) * sy
      newPts[i] = {
        x: px + rx * ca - ry * sa + dx
        y: py + rx * sa + ry * ca + dy
      }
    out[#out + 1] = newPts
  if #out == 0
    p = geo.contours[1].pts[1]
    out[1] = {{x: p.x, y: p.y}, {x: p.x, y: p.y}}
  guardShape contoursToShape(out), label

confettiSites = (shape, geo, spacing = Defaults.split_len) ->
  return nil, "Yutils.shape.to_pixels is not available" unless Yutils and Yutils.shape and Yutils.shape.to_pixels
  ok, pixels = pcall Yutils.shape.to_pixels, shape
  return nil, "Yutils.shape.to_pixels failed: #{pixels}" unless ok and pixels
  solid = {}
  for px in *pixels
    LineOps.checkCancelled!
    solid[#solid + 1] = px if (px.alpha or 0) >= 96
  solid = pixels if #solid == 0
  return nil, "Confetti effects found no filled pixels in the shape." if #solid == 0
  stride = math.max 1, round(spacing * spacing)
  jitterPick = stride > 1
  sites = {}
  bbox = geo.bbox
  idx = 1
  while idx <= #solid
    px = solid[idx]
    h1 = noiseHash idx, 3, 51
    sites[#sites + 1] = {
      x: px.x
      y: px.y
      px: normSpan px.x, bbox.min_x, bbox.max_x
      py: normSpan px.y, bbox.min_y, bbox.max_y
      h1: h1
      h2: noiseHash idx, 17, 52
      h3: noiseHash idx, 29, 53
    }
    idx += stride + (jitterPick and math.floor(h1 * stride * 0.5) or 0)
  sites

ConfettiFx = {}

confettiK = (ctx, rank) ->
  la = staggerAmount ctx.prog, rank, 0.55
  el = curveRatio la, ctx.spec.curve
  if ctx.spec.phase == "in" then 1 - el else el

ConfettiFx.shBurst = (ctx, s) ->
  k = confettiK ctx, s.h1 * 0.7
  ux, uy = unitFromCenter s.x, s.y, ctx.geo.center
  d = k * k * ctx.strength * (0.6 + s.h2)
  s.x + ux * d, s.y + uy * d, k * math.pi * 2 * (s.h3 - 0.5) * 2, 1, true

ConfettiFx.shCrumble = (ctx, s) ->
  k = confettiK ctx, (1 - s.py) * 0.6 + s.h1 * 0.4
  floorY = ctx.geo.bbox.max_y + 4
  ny = math.min s.y + k * k * (floorY - s.y + 30 + s.h2 * 50), floorY + (s.h3 - 0.5) * 6
  s.x + (s.h2 - 0.5) * k * 20, ny, k * (s.h1 - 0.5) * 6, 1, true

ConfettiFx.shSand = (ctx, s) ->
  ax = dirAxis ctx.opts.direction, s.px, s.py
  k = confettiK ctx, (1 - ax) * 0.7 + s.h1 * 0.3
  dvx, dvy = dirVector ctx.opts.direction
  d = k * ctx.strength * (1 + s.h2 * 1.2)
  wob = math.sin(k * 6 + s.h3 * 9) * 8 * k
  s.x + dvx * d - dvy * wob, s.y + dvy * d + dvx * wob, k * (s.h1 - 0.5) * 3, 1 - k * 0.3, k < 0.98

ConfettiFx.shDust = (ctx, s) ->
  k = confettiK ctx, s.h1
  s.x + math.sin(k * 5 + s.h2 * 7) * ctx.strength * 0.25, s.y - k * ctx.strength * (0.6 + s.h2), k * 4 * (s.h1 - 0.5), 1 - k * 0.4, k < 0.97

ConfettiFx.shSwarm = (ctx, s) ->
  k = confettiK ctx, s.h1 * 0.5
  ang = s.h2 * math.pi * 2 + k * (3 + s.h3 * 2)
  r = k * ctx.strength * (0.5 + s.h2)
  s.x + math.cos(ang) * r, s.y + math.sin(ang) * r, ang * 0.5, 1, true

ConfettiFx.shSplash = (ctx, s) ->
  k = confettiK ctx, s.h1 * 0.4
  vx = (s.h2 - 0.5) * 2 * ctx.strength * 1.2
  vy0 = -ctx.strength * (0.8 + s.h3 * 0.8)
  s.x + vx * k, s.y + vy0 * k + ctx.strength * 2.4 * k * k, k * (s.h1 - 0.5) * 5, 1, true

ConfettiFx.shRain = (ctx, s) ->
  k = confettiK ctx, s.h1 * 0.6 + s.px * 0.2
  s.x + math.sin(k * 4 + s.h2 * 8) * 10 * k, s.y - k * ctx.strength * (1 + s.h3 * 0.8), k * (s.h2 - 0.5) * 4, 1, true

ConfettiFx.shEmber = (ctx, s) ->
  c = ctx.phi / (math.pi * 2) * (0.5 + s.h1 * 0.8) + s.h2
  c = c - math.floor c
  s.x + math.sin(c * 7 + s.h3 * 9) * ctx.strength * 0.2, s.y - c * ctx.strength, c * 3, 1 - c * 0.5, c < 0.85

ConfettiFx.shAsh = (ctx, s) ->
  k = confettiK ctx, s.py * 0.7 + s.h1 * 0.3
  sway = octaveNoise(k * 2 + s.h2 * 4, s.h3 * 5, 7, 2) * ctx.strength * 0.8
  s.x + sway * k, s.y + k * k * ctx.strength * (0.8 + s.h1), k * (s.h2 - 0.5) * 4, 1 - k * 0.3, k < 0.98

FieldFx.fine_jitter = FieldFx.fineJitter
FieldFx.coarse_jitter = FieldFx.coarseJitter
FieldFx.wave_h = FieldFx.waveH
FieldFx.wave_v = FieldFx.waveV
FieldFx.wave_d = FieldFx.waveD
FieldFx.wave_standing = FieldFx.waveStanding
FieldFx.twist_wave = FieldFx.twistWave
FieldFx.ripple_point = FieldFx.ripplePoint
FieldFx.ripple_rain = FieldFx.rippleRain
FieldFx.ripple_cross = FieldFx.rippleCross
FieldFx.wave_bounce = FieldFx.waveBounce
FieldFx.twist_sway = FieldFx.twistSway
FieldFx.vortex_swirl = FieldFx.vortexSwirl
FieldFx.pinch_pulse = FieldFx.pinchPulse
FieldFx.bulge_pulse = FieldFx.bulgePulse
FieldFx.heartbeat_r = FieldFx.heartbeatR
FieldFx.lag_orbit = FieldFx.lagOrbit
FieldFx.electric_edge = FieldFx.electricEdge
FieldFx.frost_creep = FieldFx.frostCreep
FieldFx.melt_diag = FieldFx.meltDiag
FieldFx.slime_snap = FieldFx.slimeSnap
FieldFx.drip_loop = FieldFx.dripLoop
FieldFx.path_wave = FieldFx.pathWave
FieldFx.path_bulge = FieldFx.pathBulge
FieldFx.path_peristalsis = FieldFx.pathPeristalsis
FieldFx.path_flow = FieldFx.pathFlow
FieldFx.wipe_organic = FieldFx.wipeOrganic
FieldFx.wipe_wavy = FieldFx.wipeWavy
FieldFx.wipe_shaky = FieldFx.wipeShaky
FieldFx.wipe_ink = FieldFx.wipeInk
FieldFx.wipe_diag = FieldFx.wipeDiag
FieldFx.wipe_iris = FieldFx.wipeIris
FieldFx.wipe_swirl = FieldFx.wipeSwirl
FieldFx.ds_noise = FieldFx.dsNoise
FieldFx.ds_erode = FieldFx.dsErode
FieldFx.ds_split = FieldFx.dsSplit
FieldFx.ds_band = FieldFx.dsBand
FieldFx.ds_checker = FieldFx.dsChecker
FieldFx.ds_crystal = FieldFx.dsCrystal
FieldFx.g_corrupt = FieldFx.gCorrupt
FieldFx.g_static = FieldFx.gStatic
FieldFx.g_weave = FieldFx.gWeave
FieldFx.g_spikes = FieldFx.gSpikes
FieldFx.g_dropout = FieldFx.gDropout
FieldFx.g_quant = FieldFx.gQuant
FieldFx.g_storm = FieldFx.gStorm
SubpathFx.prefix_parallel = SubpathFx.prefixParallel
SubpathFx.prefix_sequential = SubpathFx.prefixSequential
SubpathFx.prefix_chunk = SubpathFx.prefixChunk
SubpathFx.prefix_random = SubpathFx.prefixRandom
SubpathFx.prefix_dash = SubpathFx.prefixDash
SubpathFx.snake_chase = SubpathFx.snakeChase
SubpathFx.dash_march = SubpathFx.dashMarch
SubpathFx.seg_flicker = SubpathFx.segFlicker
SubpathFx.path_retract = SubpathFx.pathRetract
ContourFx.c_bob = ContourFx.cBob
ContourFx.c_sway = ContourFx.cSway
ContourFx.c_orbit = ContourFx.cOrbit
ContourFx.c_breathe = ContourFx.cBreathe
ContourFx.c_wave = ContourFx.cWave
ContourFx.c_heart = ContourFx.cHeart
ContourFx.c_jolt = ContourFx.cJolt
ContourFx.c_blink = ContourFx.cBlink
ContourFx.c_carousel = ContourFx.cCarousel
ContourFx.c_pop = ContourFx.cPop
ContourFx.c_drop = ContourFx.cDrop
ContourFx.c_slide = ContourFx.cSlide
ContourFx.c_spin = ContourFx.cSpin
ContourFx.c_scatter = ContourFx.cScatter
ContourFx.c_flip = ContourFx.cFlip
ContourFx.c_zoom = ContourFx.cZoom
ContourFx.c_type = ContourFx.cType
ContourFx.c_domino = ContourFx.cDomino
ConfettiFx.sh_burst = ConfettiFx.shBurst
ConfettiFx.sh_crumble = ConfettiFx.shCrumble
ConfettiFx.sh_sand = ConfettiFx.shSand
ConfettiFx.sh_dust = ConfettiFx.shDust
ConfettiFx.sh_swarm = ConfettiFx.shSwarm
ConfettiFx.sh_splash = ConfettiFx.shSplash
ConfettiFx.sh_rain = ConfettiFx.shRain
ConfettiFx.sh_ember = ConfettiFx.shEmber
ConfettiFx.sh_ash = ConfettiFx.shAsh

confettiPieceShape = (ctx, sites, piece, pieces, mode, sizeBase) ->
  fx = ConfettiFx[mode]
  return nil, "Unknown confetti mode '#{mode}'." unless fx
  out = {}
  for idx = piece, #sites, pieces
    LineOps.checkCancelled!
    s = sites[idx]
    x, y, rot, scale, vis = fx ctx, s
    continue if vis == false
    r = sizeBase * (0.7 + s.h3 * 0.6) * math.max(0.05, scale or 1)
    ca, sa = math.cos(rot or 0), math.sin(rot or 0)
    quad = {}
    corners = {{-r, 0}, {0, -r}, {r, 0}, {0, r}}
    for c in *corners
      quad[#quad + 1] = {x: x + c[1] * ca - c[2] * sa, y: y + c[1] * sa + c[2] * ca}
    out[#out + 1] = quad
  if #out == 0
    s = sites[1]
    out[1] = {{x: s.x, y: s.y}, {x: s.x, y: s.y}}
  guardShape contoursToShape(out), "#{mode} confetti"

ShapeTargetBuilders = {}

ShapeTargetBuilders.blob = (src, coMeta, ci, opts) ->
  n = #src
  centroid = contourCentroid src
  _, len = contourMetrics src
  r = math.max 2, len / (math.pi * 2)
  sign = signedArea(src) >= 0 and 1 or -1
  ang0 = math.atan2 src[1].y - centroid.y, src[1].x - centroid.x
  out = {}
  for k = 0, n - 1
    LineOps.checkCancelled!
    ang = ang0 + sign * math.pi * 2 * k / n
    out[k + 1] = {x: centroid.x + math.cos(ang) * r, y: centroid.y + math.sin(ang) * r}
  out

ShapeTargetBuilders.line = (src, coMeta, ci, opts) ->
  n = #src
  centroid = contourCentroid src
  _, len = contourMetrics src
  half = math.max 2, len * 0.25
  out = {}
  for k = 0, n - 1
    LineOps.checkCancelled!
    t = k / n
    u = t < 0.5 and t * 2 or 2 - t * 2
    side = t < 0.5 and -0.6 or 0.6
    out[k + 1] = {x: centroid.x + (u - 0.5) * half * 2, y: centroid.y + side}
  out

ShapeTargetBuilders.star = (src, coMeta, ci, opts) ->
  n = #src
  centroid = contourCentroid src
  _, len = contourMetrics src
  rb = math.max 2, len / (math.pi * 2)
  spikes = math.max 3, round opts.frequency
  sign = signedArea(src) >= 0 and 1 or -1
  ang0 = math.atan2 src[1].y - centroid.y, src[1].x - centroid.x
  out = {}
  for k = 0, n - 1
    LineOps.checkCancelled!
    ang = ang0 + sign * math.pi * 2 * k / n
    r = rb * (0.45 + 1.15 * math.max(0, math.cos(spikes * (ang - ang0))) ^ 1.6)
    out[k + 1] = {x: centroid.x + math.cos(ang) * r, y: centroid.y + math.sin(ang) * r}
  out

ShapeTargetBuilders.scribble = (src, coMeta, ci, opts) ->
  n = #src
  centroid = contourCentroid src
  cbox = contourBbox src
  w = math.max 6, cbox.width
  h = math.max 6, cbox.height
  out = {}
  for k = 0, n - 1
    LineOps.checkCancelled!
    out[k + 1] = {
      x: centroid.x + (smoothNoise(k * 0.11, ci * 3.3, opts.seed) - 0.5) * w * 2.2
      y: centroid.y + (smoothNoise(k * 0.11 + 50, ci * 3.3 + 9, opts.seed) - 0.5) * h * 2.2
    }
  out

shapeMorphPair = (shape, opts, mode) ->
  builder = ShapeTargetBuilders[mode]
  return nil, nil, "Unknown shape morph mode '#{mode}'." unless builder
  flat, err = flattenShape shape, "Shape morph source"
  return nil, nil, err unless flat
  contours = parseContours flat
  return nil, nil, "Shape morph source has no contours." if #contours == 0
  segLen = opts.split_len
  desired = {}
  for ci, contour in ipairs contours
    LineOps.checkCancelled!
    _, len = contourMetrics contour
    desired[ci] = math.max MinMorphPoints, math.ceil(len / segLen)
  outSrc, outTgt = {}, {}
  for ci, contour in ipairs contours
    LineOps.checkCancelled!
    count = desired[ci]
    sampled = resampleContour contour, count
    return nil, nil, "Shape morph resampling failed for contour #{ci}." unless sampled
    outSrc[ci] = sampled
    outTgt[ci] = builder sampled, nil, ci, opts
  srcShape, err = guardShape contoursToShape(outSrc), "Shape morph source after resample"
  return nil, nil, err unless srcShape
  tgtShape, err = guardShape contoursToShape(outTgt), "Shape morph target"
  return nil, nil, err unless tgtShape
  srcShape, tgtShape

export collect_initial_tag_blocks = (text) ->
  text = tostring(text or "")
  blocks, pos = {}, 1
  while text\sub(pos, pos) == "{"
    closePos = text\find("}", pos, true)
    break unless closePos
    block = text\sub(pos + 1, closePos - 1)
    blocks[#blocks + 1] = block if block\match "^%s*\\"
    pos = closePos + 1
  table.concat blocks, ""

stripInitialTags = (text, dropPlacement = false) ->
  body = collectInitialTagBlocks text
  leadingEnd = 0
  for section in *LineOps.scanSections text
    break unless section.type == "override" or section.type == "comment"
    leadingEnd = section.finish
  for call in *LineOps.tagCalls text, {"clip", "iclip", "org"}
    body ..= call.raw if call.top_level and call.start > leadingEnd
  wrapped = "{" .. body .. "}"
  wrapped = LineOps.removeTagCalls wrapped, {"fn", "fsp", "fscx", "fscy", "fs", "b", "i", "u", "s", "p", "k", "K", "kf", "ko"}
  wrapped = LineOps.removeTagCalls(wrapped, {"an", "a", "pos", "move"}) if dropPlacement
  wrapped\match("^%{(.*)%}$") or ""

export alpha_tag = (alpha) ->
  "\\alpha&H%02X&"\format round clamp(alpha, 0, 255)

drawingText = (sourceText, shape, extraTags = "", placementTags = "") ->
  placementTags = placementTags or ""
  tags = stripInitialTags sourceText, placementTags != ""
  "{#{tags}#{placementTags}#{extraTags}\\fscx100\\fscy100\\p1}#{cleanShape shape}{\\p0}"

visibleText = (text) -> LineOps.visibleText text

export tag_bool = (value) ->
  return false if value == nil or value == false
  return value != 0 if type(value) == "number"
  tostring(value) != "0"

export raw_num_tag = (tagBlock, name, defaultValue) ->
  value = LineOps.tagNumber tagBlock, name, defaultValue, true
  finiteNumber(value) or defaultValue

export raw_bool_tag = (tagBlock, name, defaultValue) ->
  value, call = LineOps.tagNumber tagBlock, name, nil, true
  return defaultValue unless call and finiteNumber(value) != nil
  tagBool finiteNumber(value)

export raw_font_tag = (tagBlock, defaultValue) ->
  call = LineOps.lastTagCall tagBlock, "fn", true
  value = trim(call and call.value or "")
  if value == "" then defaultValue else value

export style_number = (style, field, defaultValue) ->
  finiteNumber(style and style[field]) or defaultValue

export style_bool = (style, field, defaultValue) ->
  value = style and style[field]
  return defaultValue if value == nil
  tagBool value

styleFromLine = (source) ->
  ctx = AssContext.resolve source
  return nil, "The source style could not be resolved." unless ctx.style
  style = LineOps.copy ctx.style
  AssContext.applyInlineStyleTags style, "{" .. collectInitialTagBlocks(source.text) .. "}", ctx.styles, ctx.style, ctx.style

TextStyleTags = {"fn", "fs", "fscx", "fscy", "fsp", "b", "i", "u", "s"}

uniformTextStyleError = (text) ->
  visibleStarted = false
  for section in *LineOps.scanSections text
    if section.type == "override"
      wrapped = "{#{section.text}}"
      return "Inline style resets require separate uniform lines." if visibleStarted and LineOps.hasTag wrapped, "r", true
      if visibleStarted
        for call in *LineOps.tagCalls wrapped
          unless call.name == "an" or call.name == "a" or call.name == "pos" or call.name == "move" or call.name == "org" or call.name == "clip" or call.name == "iclip" or call.name == "p"
            return "Inline appearance changes require separate uniform glyph lines."
      for call in *LineOps.tagCalls wrapped, TextStyleTags
        return "Animated typography is not supported while converting text to one shape; remove typography changes inside \\t first." unless call.top_level
        return "Inline typography changes are not supported while converting text to one shape; split the line into uniform runs first." if visibleStarted
    elseif section.type == "text"
      plain = tostring(section.text or "")\gsub "\\[Nnh]", ""
      visibleStarted = true if plain != ""
  nil

textToShape = (text, style, fontname = nil) ->
  text = tostring(text or "")
  style = style or {}
  return nil, "Yutils.decode.create_font is not available" unless Yutils and Yutils.decode and Yutils.decode.create_font
  ok, font = pcall Yutils.decode.create_font,
    fontname or style.fontname or "Arial",
    style.bold or false,
    style.italic or false,
    style.underline or false,
    style.strikeout or false,
    style.fontsize or 40,
    (style.scale_x or 100) / 100,
    (style.scale_y or 100) / 100,
    style.spacing or 0
  return nil, "Yutils.decode.create_font failed: #{font}" unless ok
  return nil, "Yutils font.text_to_shape is not available" unless font and font.text_to_shape
  ok, shape = pcall font.text_to_shape, text
  return nil, "Yutils font.text_to_shape failed: #{shape}" unless ok
  guardShape shape, "Text shape"

drawingScaleValue = (section) ->
  ok, result = pcall ->
    scaleTag = section.scale
    return 1 unless scaleTag
    if type(scaleTag) == "table"
      if scaleTag.get
        scaleTag\get!
      else
        scaleTag.value
    else
      scaleTag
  value = ok and finiteNumber(result) or nil
  return 1 unless value and value >= 1
  math.floor value

scaleShape = (shape, factorX, factorY) ->
  return nil, "Drawing scale is not finite." unless finiteNumber(factorX) and finiteNumber(factorY)
  return shape if factorX == 1 and factorY == 1
  AssDrawing.mapCoordinates shape, ((x, y) -> x * factorX, y * factorY), 4

sourceInfo = (source, opts) ->
  okParse, data = pcall -> ASS\parse source
  return nil, "ASS parse failed: #{data}" unless okParse and data
  return nil, "ASS parser did not return section accessors." unless data.getSectionCount and data.callback
  info = {kind: nil, shape: nil, text: "", style: nil, data: data}
  okCount, drawingCount = pcall -> data\getSectionCount ASS.Section.Drawing
  return nil, "ASS drawing section detection failed: #{drawingCount}" unless okCount
  drawingCount = tonumber(drawingCount) or 0
  okTextCount, textCount = pcall -> data\getSectionCount ASS.Section.Text
  return nil, "ASS text section detection failed: #{textCount}" unless okTextCount
  textCount = tonumber(textCount) or 0
  visibleSource = visibleText source.text
  styleErr = uniformTextStyleError source.text
  return nil, styleErr if styleErr
  return nil, "Split explicit line breaks into separate lines before converting text to a glyph shape." if visibleSource != "" and tostring(source.text)\match "\\[Nn]"
  if drawingCount > 0 and textCount > 0 and visibleSource != ""
    return nil, "Mixed drawing and visible text runs are not supported; split them into separate lines first."
  if drawingCount > 0
    sections = {}
    okCallback, callbackErr = pcall ->
      data\callback ((section) ->
        sections[#sections + 1] = section
        true), ASS.Section.Drawing
    return nil, "ASS drawing extraction failed: #{callbackErr}" unless okCallback
    return nil, "ASS drawing extraction failed: no drawing section captured." if #sections == 0
    return nil, "Line has #{#sections} drawing sections; #{script_name} supports exactly one drawing per line." if #sections > 1
    rawShape = nil
    okString, stringErr = pcall -> rawShape = cleanShape sections[1]\toString!
    return nil, "ASS drawing extraction failed: #{stringErr}" unless okString
    pScale = drawingScaleValue sections[1]
    info.style, styleErr = styleFromLine source
    return nil, styleErr unless info.style
    factor = 2 ^ (pScale - 1)
    return nil, "Drawing scale cannot be represented." unless finiteNumber(factor) and factor > 0
    shape, scaleErr = scaleShape rawShape, (info.style.scale_x / 100) / factor, (info.style.scale_y / 100) / factor
    return nil, scaleErr unless shape
    info.shape, err = guardShape shape, "Drawing shape"
    return nil, err unless info.shape
    info.kind = "drawing"
    return info
  if textCount > 0
    info.text = visibleSource
    return nil, "Text line has no visible text." if info.text == ""
    info.style, styleErr = styleFromLine source
    return nil, styleErr unless info.style
    shape, err = textToShape info.text, info.style
    return nil, err unless shape and shape != ""
    info.shape = shape
    info.kind = "text"
    return info
  nil, "Line has neither text nor drawing."

targetShapeFor = (info, opts) ->
  return nil, "Font morph requires text input." unless info.kind == "text"
  return nil, "Target font is empty." if trim(opts.target_font) == ""
  textToShape info.text, info.style, opts.target_font



export has_move = (text) -> LineOps.hasTag text, "move", true

extractMove = (text) ->
  args, call = LineOps.tagArguments text, "move", true
  return nil unless call
  values = {}
  for token in *args
    value = finiteNumber token
    return nil, "Move tag has invalid numeric value '#{token}'." unless value
    values[#values + 1] = value
  return nil, "Move tag must have 4 or 6 numeric values." unless #values == 4 or #values == 6
  {
    x1: values[1]
    y1: values[2]
    x2: values[3]
    y2: values[4]
    t1: values[5]
    t2: values[6]
  }

export same_point = (x1, y1, x2, y2) ->
  math.abs((x1 or 0) - (x2 or 0)) < 0.01 and math.abs((y1 or 0) - (y2 or 0)) < 0.01

movePositionAt = (move, relTime, sourceDuration) ->
  return nil unless move
  relTime = finiteNumber(relTime) or 0
  sourceDuration = math.max 1, finiteNumber(sourceDuration) or 1
  t1 = finiteNumber(move.t1) or 0
  t2 = finiteNumber(move.t2) or 0
  t1, t2 = t2, t1 if t1 > t2
  t1, t2 = 0, sourceDuration if t1 <= 0 and t2 <= 0
  if t2 <= t1
    return move.x1, move.y1 if relTime < t1
    return move.x2, move.y2
  return move.x1, move.y1 if relTime <= t1
  return move.x2, move.y2 if relTime >= t2
  ratio = (relTime - t1) / (t2 - t1)
  move.x1 + (move.x2 - move.x1) * ratio, move.y1 + (move.y2 - move.y1) * ratio

export format_pos_tag = (x, y) ->
  "\\pos(#{fmtNum x},#{fmtNum y})"

export format_move_tag = (x1, y1, x2, y2, t1 = nil, t2 = nil) ->
  if t1 != nil and t2 != nil
    return "\\move(#{fmtNum x1},#{fmtNum y1},#{fmtNum x2},#{fmtNum y2},#{round t1},#{round t2})"
  "\\move(#{fmtNum x1},#{fmtNum y1},#{fmtNum x2},#{fmtNum y2})"

trackingActive = (opts) ->
  opts and opts.motion_mode == "Bake AE position data" and trim(opts.tracking_data) != ""

parseTrackingPoints = (text) ->
  rows = {}
  for raw in tostring(text or "")\gmatch "[^\r\n]+"
    rows[#rows + 1] = trim raw
  wanted = nil
  for row in *rows
    wanted = "Position" if row == "Position"
  unless wanted
    for row in *rows
      wanted = "Anchor Point" if row == "Anchor Point"
  collecting = not wanted
  points = {}
  for row in *rows
    if wanted and row == wanted
      collecting = true
      continue
    continue unless collecting
    break if row == "End of Keyframe Data"
    if row != "" and not row\match "^[%+%-%d%.]"
      break if #points > 0
      continue
    nums = {}
    valid = true
    for token in row\gmatch "[^,%s]+"
      number = finiteNumber token
      unless number
        valid = false
        break
      nums[#nums + 1] = number
    return nil, "Tracking row contains an invalid number: #{row}" unless valid
    continue if #nums == 0
    if #nums == 2
      points[#points + 1] = {x: nums[1], y: nums[2]}
    elseif #nums == 3 or #nums == 4
      return nil, "Tracking frame numbers must be integers." unless nums[1] == math.floor(nums[1])
      points[#points + 1] = {frame: nums[1], x: nums[2], y: nums[3]}
    else
      return nil, "Tracking rows must contain X Y, Frame X Y, or Frame X Y Z."
  return nil, "Tracking data has no usable Position/Anchor Point rows." if #points == 0
  framed = points[1].frame != nil
  for i, point in ipairs points
    return nil, "Tracking data mixes rows with and without frame numbers." if (point.frame != nil) != framed
    return nil, "Tracking frame numbers must be strictly increasing." if framed and i > 1 and point.frame <= points[i - 1].frame
    point.frame = i - 1 unless framed
  points

trackingPointsFor = (opts) ->
  return nil unless trackingActive opts
  return opts._tracking_points if opts._tracking_points
  points, err = parseTrackingPoints opts.tracking_data
  return nil, err unless points
  opts._tracking_points = points
  points

trackingSampleIndex = (source, absTime, points) ->
  absTime = finiteNumber(absTime) or finiteNumber(source.start_time) or 0
  if aegisub and aegisub.frame_from_ms
    ok1, frame = pcall aegisub.frame_from_ms, absTime
    ok2, startFrame = pcall aegisub.frame_from_ms, finiteNumber(source.start_time) or 0
    if ok1 and ok2 and frame and startFrame
      return round(frame - startFrame + 1)
  duration = math.max 1, (finiteNumber(source.end_time) or absTime + 1) - (finiteNumber(source.start_time) or 0)
  progress = clamp (absTime - (finiteNumber(source.start_time) or 0)) / duration, 0, 1
  progress * math.max(0, points[#points].frame - points[1].frame) + 1

trackingPointAt = (points, offset) ->
  frame = points[1].frame + offset
  return points[1] if frame <= points[1].frame
  return points[#points] if frame >= points[#points].frame
  lo, hi = 1, #points
  while lo + 1 < hi
    mid = math.floor((lo + hi) / 2)
    if points[mid].frame <= frame then lo = mid else hi = mid
  a, b = points[lo], points[hi]
  ratio = (frame - a.frame) / (b.frame - a.frame)
  {x: a.x + (b.x - a.x) * ratio, y: a.y + (b.y - a.y) * ratio}

trackingOffsetAt = (source, absTime, opts) ->
  points, err = trackingPointsFor opts
  return nil, nil, err unless points
  ref = trackingPointAt points, opts.tracking_ref_frame - 1
  point = trackingPointAt points, trackingSampleIndex(source, absTime, points) - 1
  point.x - ref.x, point.y - ref.y

motionPoint = (source, anchor, relTime, absTime, dx, dy, opts) ->
  sourceStart = finiteNumber(source.start_time) or 0
  sourceDuration = math.max 1, (finiteNumber(source.end_time) or sourceStart + 1) - sourceStart
  local x, y
  if anchor.kind == "move"
    x, y = movePositionAt anchor.move, relTime, sourceDuration
  else
    x, y = anchor.x, anchor.y
  x += dx or 0
  y += dy or 0
  if trackingActive opts
    ox, oy, err = trackingOffsetAt source, absTime, opts
    return nil, nil, err unless ox
    x += ox
    y += oy
  x, y

motionTagFor = (source, anchor, dx, dy, lineStart, lineEnd, opts) ->
  sourceStart = finiteNumber(source.start_time) or 0
  lineStart = finiteNumber(lineStart) or sourceStart
  lineEnd = finiteNumber(lineEnd) or finiteNumber(source.end_time) or lineStart + 1
  lineEnd = lineStart + 1 if lineEnd <= lineStart
  relStart = lineStart - sourceStart
  relEnd = lineEnd - sourceStart
  if anchor.kind == "move" and not trackingActive(opts)
    move = anchor.move
    text = "{" .. formatMoveTag(move.x1 + dx, move.y1 + dy, move.x2 + dx, move.y2 + dy, move.t1, move.t2) .. "}"
    timed = AssContext.retimeText text, source.end_time - source.start_time, relStart
    return timed\sub(2, -2), hasMove(timed)
  sampleEnd = math.max lineStart, lineEnd - 1
  x1, y1, err = motionPoint source, anchor, relStart, lineStart, dx, dy, opts
  return nil, nil, err unless x1
  x2, y2, err = motionPoint source, anchor, relEnd, sampleEnd, dx, dy, opts
  return nil, nil, err unless x2
  moving = not samePoint x1, y1, x2, y2
  return formatPosTag(x1, y1), false if not moving
  formatMoveTag(x1, y1, x2, y2), true

effectiveAlign = (source) ->
  AssContext.alignment source.text, AssContext.resolve(source).style

alignToTopLeftOffset = (align, bbox) ->
  align = round clamp align, 1, 9
  col = ((align - 1) % 3) + 1
  row = math.floor((align - 1) / 3) + 1
  dx = if col == 1 then 0 elseif col == 2 then -bbox.width / 2 else -bbox.width
  dy = if row == 1 then -bbox.height elseif row == 2 then -bbox.height / 2 else 0
  dx, dy

lineDefaultPosition = (source) ->
  AssContext.defaultPosition source

export has_org = (text) ->
  LineOps.hasTag text, "org", true

export has_origin_sensitive_tags = (text) ->
  LineOps.hasTag text, {"fr", "frx", "fry", "frz", "fax", "fay"}, false

originTagFor = (source, anchorX, anchorY, moving = false) ->
  return "" if hasOrg source.text
  style = AssContext.resolve(source).style
  return "" unless hasOriginSensitiveTags(source.text) or (finiteNumber(style and style.angle) or 0) != 0
  if moving
    return nil, "Text line uses \\move with rotation/shear and no explicit \\org; add \\org before running #{script_name} so the transform origin can be preserved."
  "\\org(#{fmtNum anchorX},#{fmtNum anchorY})"

anchorPosition = (source) ->
  x, y, call = AssContext.explicitPosition source.text, source.end_time - source.start_time, 0
  if call
    if call.name == "move"
      move, err = extractMove "{#{call.raw}}"
      return nil, err unless move
      return {kind: "move", move: move}
    return {kind: "pos", x: x, y: y}
  x, y, err = lineDefaultPosition source
  return {kind: "pos", x: x, y: y, default_position: true} if x and y
  nil, err or "Could not resolve original line position."

placementTagsFor = (source, shape, lineStart = nil, lineEnd = nil, opts = nil) ->
  align = effectiveAlign source
  bbox = shapeBbox shape
  return nil, "Could not read generated shape bounds for alignment compensation." if align != 7 and not bbox
  dx, dy = 0, 0
  dx, dy = alignToTopLeftOffset align, bbox if align != 7
  anchor, err = anchorPosition source
  return nil, err unless anchor
  if anchor.kind == "move" or trackingActive(opts)
    tag, moving, tagErr = motionTagFor source, anchor, dx, dy, lineStart, lineEnd, opts
    return nil, tagErr unless tag
    org, orgErr = originTagFor source, anchor.kind == "move" and anchor.move.x1 or anchor.x, anchor.kind == "move" and anchor.move.y1 or anchor.y, moving
    return nil, orgErr unless org
    return "\\an7#{tag}#{org}" if align != 7
    return "#{tag}#{org}"
  org, orgErr = originTagFor source, anchor.x, anchor.y, false
  return nil, orgErr unless org
  "\\an7\\pos(#{fmtNum(anchor.x + dx)},#{fmtNum(anchor.y + dy)})#{org}"

clearAMoExtra = (line) ->
  if line and line.extra
    line.extra = LineOps.copy line.extra
    line.extra["a-mo"] = nil
  line

export same_merge_value = (a, b) ->
  tostring(a or "") == tostring(b or "")

mergeFields = {"text", "style", "layer", "actor", "margin_l", "margin_r", "margin_t", "margin_b", "comment"}

sameExtra = (a, b) ->
  return true if a == b
  a, b = a or {}, b or {}
  return false unless type(a) == "table" and type(b) == "table"
  for key, value in pairs a
    return false unless value == b[key]
  for key, value in pairs b
    return false unless value == a[key]
  true

export can_merge_generated_lines = (last, line) ->
  return false unless last and line
  for field in *mergeFields
    return false unless last[field] == line[field]
  return false unless sameExtra last.extra, line.extra
  return false if LineOps.hasTag line.text, {"t", "move", "fad", "fade", "k", "kf", "ko", "kt"}, true
  return false unless finiteNumber(last.end_time) and finiteNumber(line.start_time)
  finiteNumber(last.end_time) == finiteNumber(line.start_time)

compressContiguousLines = (lines) ->
  result, buckets = {}, {}
  for line in *(lines or {})
    LineOps.checkCancelled!
    fields = {}
    for field in *mergeFields
      value = tostring line[field]
      fields[#fields + 1] = "#{#value}:#{value}"
    key = table.concat fields
    bucket = buckets[key] or {}
    buckets[key] = bucket
    previous = bucket[line.start_time]
    if previous and canMergeGeneratedLines(previous, line)
      bucket[previous.end_time] = nil
      previous.end_time = line.end_time
      previous.duration = line.end_time - previous.start_time
      bucket[previous.end_time] = previous
    else
      result[#result + 1] = line
      bucket[line.end_time] = line
  result

export line_extra_value = (line, key) ->
  return nil unless line
  if line.extra and line.extra[key] != nil
    return line.extra[key]
  if line.getExtraData
    ok, value = pcall -> line\getExtraData key
    return value if ok and value != nil
  nil

aMoUuid = (line) ->
  extra = lineExtraValue line, "a-mo"
  return nil unless extra
  if type(extra) == "table"
    return tostring(extra.uuid) if extra.uuid
  text = tostring(extra)
  uuid = text\match '"uuid"%s*:%s*"([^"]+)"'
  uuid or= text\match "'uuid'%s*:%s*'([^']+)'"
  uuid or "__a-mo:" .. text

frameContextsForSelection = (sub, sortedSel, collection) ->
  groups, order = {}, {}
  for index in *sortedSel
    line = safeLine sub[index], collection, "Selected line #{index}"
    continue unless line
    uuid = aMoUuid line
    continue unless uuid
    group = groups[uuid]
    unless group
      group = {uuid: uuid, items: {}, total_frames: 0}
      groups[uuid] = group
      order[#order + 1] = group
    count = lineFrameCount line
    group.items[#group.items + 1] = {index: index, count: count, duration: lineDurationMs(line), start: line.start_time}
    group.total_frames += count
  contexts = {}
  for group in *order
    continue unless group.total_frames > 1
    table.sort group.items, (a, b) -> if a.start == b.start then a.index < b.index else a.start < b.start
    offset = 0
    timeOffset = 0
    for item in *group.items
      contexts[item.index] = {frame_offset: offset, total_frames: group.total_frames, time_offset: timeOffset, a_mo_uuid: group.uuid}
      offset += item.count
      timeOffset += item.duration
  contexts

contourRanks = (geo, direction) ->
  cn = geo.cn
  ranks = {}
  return ranks if cn == 0
  if cn == 1
    ranks[1] = 0
    return ranks
  order = {}
  for ci, co in ipairs geo.contours
    LineOps.checkCancelled!
    px = normSpan co.centroid.x, geo.bbox.min_x, geo.bbox.max_x
    py = normSpan co.centroid.y, geo.bbox.min_y, geo.bbox.max_y
    order[#order + 1] = {ci: ci, axis: dirAxis direction, px, py}
  table.sort order, (a, b) -> a.axis < b.axis
  for pos, entry in ipairs order
    ranks[entry.ci] = (pos - 1) / (cn - 1)
  ranks

makeCtx = (geo, opts, slice, spec) ->
  ctx = buildCtx geo, opts, slice, spec
  geo.ranks or= {}
  geo.ranks[opts.direction] or= contourRanks geo, opts.direction
  ctx.ranks = geo.ranks[opts.direction]
  ctx

newLine = (source, collection, shape, opts, marker, startTime = nil, endTime = nil, extraTags = "", layerDelta = 0, info = nil, placementShape = nil) ->
  line, err = safeLine source, collection, "Generated line base"
  return nil, err unless line
  clearAMoExtra line
  placementTags = ""
  if info
    placementTags, err = placementTagsFor source, placementShape or shape, startTime, endTime, opts
    return nil, err unless placementTags != nil
  line.start_time = startTime if startTime
  line.end_time = endTime if endTime
  line.layer = (finiteNumber(source.layer) or 0) + layerDelta
  line.comment = false
  line.effect = "[#{script_name} - #{opts.effect}]#{marker}"
  timedText = AssContext.retimeText source.text, source.end_time - source.start_time, line.start_time - source.start_time
  line.text = drawingText timedText, shape, extraTags, placementTags
  line

sliceMarker = (slice, prefix = "") ->
  if slice.mode == "frame" then "[#{prefix}f#{slice.index}/#{slice.total}]" else "[#{prefix}m#{slice.index}/#{slice.total}]"

momentOutputs = (source, collection, info, opts) ->
  spec = effectSpec opts.effect
  slices, err = temporalSlices source, opts
  return nil, err unless slices
  local baseShape, targetShape, targetNums, geo
  if spec.kind == "morph"
    targetShape, err = targetShapeFor info, opts
    return nil, err unless targetShape
    baseShape, targetShape, err = normalizePair info.shape, targetShape, opts
    return nil, err unless baseShape and targetShape
    targetNums = collectNumbers targetShape
  elseif spec.kind == "shape_morph"
    baseShape, targetShape, err = shapeMorphPair info.shape, opts, spec.mode
    return nil, err unless baseShape and targetShape
    targetNums = collectNumbers targetShape
    geo, err = prepGeo info.shape, opts, "Shape morph base"
    return nil, err unless geo
  else
    geo, err = prepGeo info.shape, opts, "Moment base shape"
    return nil, err unless geo
    baseShape = info.shape
  lines = {}
  for slice in *slices
    LineOps.checkCancelled!
    local shape
    if spec.kind == "morph"
      morphRatio = if spec.elastic then curveRatio(slice.progress, "overshoot") else curveRatio(slice.ratio, spec.curve or "linear")
      shape, err = lerpShape baseShape, targetShape, morphRatio, targetNums
      return nil, err unless shape
      if spec.curve == "glitch" or spec.curve == "rubber"
        postGeo, postErr = prepGeo shape, opts, "Morph post shape"
        return nil, postErr unless postGeo
        postMode = spec.curve == "glitch" and "g_corrupt" or "gelatin"
        postCtx = makeCtx postGeo, opts, slice, {curve: "linear"}
        shape, err = applyField postGeo, postCtx, postMode, "Morph post shape"
        return nil, err unless shape
    elseif spec.kind == "shape_morph"
      ctx = makeCtx geo, opts, slice, spec
      r = if spec.phase then ctx.m else 0.55 * (0.5 - 0.5 * math.cos(ctx.phi))
      shape, err = lerpShape baseShape, targetShape, r, targetNums
      return nil, err unless shape
    elseif spec.kind == "subpath"
      ctx = makeCtx geo, opts, slice, spec
      shape, err = applySubpath geo, ctx, spec.mode, "#{spec.mode} shape"
      return nil, err unless shape
    elseif spec.kind == "contour"
      ctx = makeCtx geo, opts, slice, spec
      shape, err = applyContour geo, ctx, spec.mode, "#{spec.mode} shape"
      return nil, err unless shape
    else
      ctx = makeCtx geo, opts, slice, spec
      shape, err = applyField geo, ctx, spec.mode, "#{spec.mode} shape"
      return nil, err unless shape
    line, err = newLine source, collection, shape, opts, sliceMarker(slice), slice.start_time, slice.end_time, "", 0, info, baseShape
    return nil, err unless line
    lines[#lines + 1] = line
  compressContiguousLines lines

SketchFieldModes = {pencil: "handwriting", scribble: "boil"}

layerDeformOutputs = (source, collection, info, opts) ->
  spec = effectSpec opts.effect
  slices, err = temporalSlices source, opts
  return nil, err unless slices
  geo, err = prepGeo info.shape, opts, "Sketch base shape"
  return nil, err unless geo
  fieldMode = SketchFieldModes[spec.mode] or "handwriting"
  lines = {}
  for slice in *slices
    LineOps.checkCancelled!
    for i = 1, opts.layers
      LineOps.checkCancelled!
      ctx = makeCtx geo, opts, slice, spec
      ctx.seed = opts.seed + i * 101
      ctx.m = 1
      shape, err = applyField geo, ctx, fieldMode, "Sketch pass shape"
      return nil, err unless shape
      extra = "\\blur#{fmtNum(opts.blur)}#{alphaTag math.floor(opts.alpha * 0.75)}"
      line, err = newLine source, collection, shape, opts, sliceMarker(slice, "pass#{i} "), slice.start_time, slice.end_time, extra, i - 1, info, info.shape
      return nil, err unless line
      lines[#lines + 1] = line
  compressContiguousLines lines

confettiOutputs = (source, collection, info, opts) ->
  spec = effectSpec opts.effect
  slices, err = temporalSlices source, opts
  return nil, err unless slices
  geo, err = prepGeo info.shape, opts, "Confetti base shape"
  return nil, err unless geo
  sites, err = confettiSites info.shape, geo, opts.split_len
  return nil, err unless sites
  pieces = opts.layers
  sizeBase = math.max 1.5, opts.split_len * 0.9
  extra = opts.alpha > 0 and alphaTag(opts.alpha) or ""
  lines = {}
  for slice in *slices
    LineOps.checkCancelled!
    ctx = makeCtx geo, opts, slice, spec
    for piece = 1, pieces
      LineOps.checkCancelled!
      shape, err = confettiPieceShape ctx, sites, piece, pieces, spec.mode, sizeBase
      return nil, err unless shape
      line, err = newLine source, collection, shape, opts, sliceMarker(slice, "piece#{piece} "), slice.start_time, slice.end_time, extra, piece - 1, info, info.shape
      return nil, err unless line
      lines[#lines + 1] = line
  compressContiguousLines lines

pairMorphOutputs = (source, target, collection, opts) ->
  srcInfo, err = sourceInfo source, opts
  return nil, err unless srcInfo
  tgtInfo, err = sourceInfo target, opts
  return nil, err unless tgtInfo
  baseShape, targetShape, err = normalizePair srcInfo.shape, tgtInfo.shape, opts
  return nil, err unless baseShape and targetShape
  targetNums = collectNumbers targetShape
  spec = effectSpec opts.effect
  sourceCopy = LineOps.copy source
  timedSource, err = safeLine sourceCopy, collection, "Pair morph timing source"
  return nil, err unless timedSource
  sourceStart = finiteNumber(source.start_time) or 0
  targetStart = finiteNumber(target.start_time) or sourceStart
  sourceEnd = finiteNumber(source.end_time) or sourceStart + 1
  targetEnd = finiteNumber(target.end_time) or sourceEnd
  timedSource.start_time = math.min sourceStart, targetStart
  timedSource.end_time = math.max sourceEnd, targetEnd
  slices, err = temporalSlices timedSource, opts
  return nil, err unless slices
  lines = {}
  for slice in *slices
    LineOps.checkCancelled!
    morphRatio = if spec.elastic then curveRatio(slice.progress, "overshoot") else curveRatio(slice.ratio, spec.curve or "linear")
    shape, err = lerpShape baseShape, targetShape, morphRatio, targetNums
    return nil, err unless shape
    line, err = newLine timedSource, collection, shape, opts, sliceMarker(slice, "pair "), slice.start_time, slice.end_time, "", 0, srcInfo, baseShape
    return nil, err unless line
    lines[#lines + 1] = line
  compressContiguousLines lines

outputsFor = (source, collection, opts) ->
  info, err = sourceInfo source, opts
  return nil, err unless info
  spec = effectSpec opts.effect
  local lines
  if spec.kind == "layer_deform"
    lines, err = layerDeformOutputs source, collection, info, opts
  elseif spec.kind == "confetti"
    lines, err = confettiOutputs source, collection, info, opts
  else
    lines, err = momentOutputs source, collection, info, opts
  return nil, err unless lines
  lines

safeOutputsFor = (source, collection, opts) ->
  ok, lines, err = pcall -> outputsFor source, collection, opts
  return nil, "#{script_name} failed while generating output: #{lines}" unless ok
  lines, err

safePairMorphOutputs = (source, target, collection, opts) ->
  ok, lines, err = pcall -> pairMorphOutputs source, target, collection, opts
  return nil, "#{script_name} failed while generating pair morph output: #{lines}" unless ok
  lines, err

estimatedOutputCount = (opts) ->
  spec = effectSpec opts.effect
  if spec.kind == "confetti" or spec.kind == "layer_deform"
    opts.moments * opts.layers
  else
    opts.moments

export utf8Len = utf8_len
export windowError = window_error
export confirmLargeOutput = confirm_large_output
export progressIsCancelled = progress_is_cancelled
export progressTask = progress_task
export progressSet = progress_set
export configEntriesForGui = config_entries_for_gui
export controlValue = control_value
export pickerGui = picker_gui
export addMomentControls = add_moment_controls
export addShapeControls = add_shape_controls
export addSeedDirectionControls = add_seed_direction_controls
export addLayerControls = add_layer_controls
export addOffsetControls = add_offset_controls
export addTimingControls = add_timing_controls
export addMotionControls = add_motion_controls
export optionsGui = options_gui
export configInterface = config_interface
export readConfiguredGui = read_configured_gui
export saveConfiguredGui = save_configured_gui
export effectPicker = effect_picker
export showEffectOptions = show_effect_options
export readOptions = read_options
export autoRatios = auto_ratios
export sameRatio = same_ratio
export legacyDefaultRatios = legacy_default_ratios
export parseRatioTokens = parse_ratio_tokens
export parseRatios = parse_ratios
export elasticRatios = elastic_ratios
export shapeLimitError = shape_limit_error
export collectInitialTagBlocks = collect_initial_tag_blocks
export alphaTag = alpha_tag
export tagBool = tag_bool
export rawNumTag = raw_num_tag
export rawBoolTag = raw_bool_tag
export rawFontTag = raw_font_tag
export styleNumber = style_number
export styleBool = style_bool
export hasMove = has_move
export samePoint = same_point
export formatPosTag = format_pos_tag
export formatMoveTag = format_move_tag
export hasOrg = has_org
export hasOriginSensitiveTags = has_origin_sensitive_tags
export sameMergeValue = same_merge_value
export canMergeGeneratedLines = can_merge_generated_lines
export lineExtraValue = line_extra_value

validate = (sub, sel) ->
  return false unless sub and sel and #sel >= 1
  for index in *sel
    line = sub[index]
    return false unless line and line.class == "dialogue" and not line.comment
  true

runWithOptions = (sub, sel, opts) ->
  return unless opts
  sortedSel, err = sortedSelection sel
  return windowError err unless sortedSel
  spec = effectSpec opts.effect
  estimatedTotal = if spec.kind == "pair_morph" then estimatedOutputCount(opts) else #sortedSel * estimatedOutputCount(opts)
  return unless confirmLargeOutput estimatedTotal, "the estimated run"
  return windowError "Subtitle object has no insert method." unless sub and sub.insert
  collection, err = safeCollection sub, sortedSel
  return windowError err unless collection
  frameContexts = frameContextsForSelection sub, sortedSel, collection
  if spec.kind == "pair_morph"
    return windowError "#{opts.effect} needs exactly two selected dialogue lines: source first, target second." unless #sortedSel == 2
    source, err = safeLine sub[sortedSel[1]], collection, "Source line #{sortedSel[1]}"
    return windowError err unless source
    target, err = safeLine sub[sortedSel[2]], collection, "Target line #{sortedSel[2]}"
    return windowError err unless target
    return windowError "#{opts.effect} needs two uncommented dialogue lines." unless source.class == "dialogue" and target.class == "dialogue" and not source.comment and not target.comment
    if collection.styles
      source.styleRef = collection.styles[source.style] if not source.styleRef
      target.styleRef = collection.styles[target.style] if not target.styleRef
    lines, err = safePairMorphOutputs source, target, collection, opts
    return windowError err unless lines and #lines > 0
    return unless confirmLargeOutput #lines, "this pair"
    commentedSource, err = safeLine source, collection, "Commented source line"
    return windowError err unless commentedSource
    commentedTarget, err = safeLine target, collection, "Commented target line"
    return windowError err unless commentedTarget
    commentedSource.comment = true
    commentedTarget.comment = true
    okApply, generatedOrError = pcall ->
      LineOps.transaction sub, script_name, ->
        sub[sortedSel[1]] = commentedSource
        sub[sortedSel[2]] = commentedTarget
        generatedSelection = {}
        insertAt = sortedSel[2] + 1
        for line in *lines
          LineOps.checkCancelled!
          sub.insert insertAt, line
          generatedSelection[#generatedSelection + 1] = insertAt
          insertAt += 1
        generatedSelection
    return windowError "Could not apply pair morph atomically: #{generatedOrError}" unless okApply
    return generatedOrError
  plans = {}
  for i, index in ipairs sortedSel
    aegisub.cancel! if progressIsCancelled!
    progressTask "Preparing line #{i} of #{#sortedSel}"
    progressSet math.floor(50 * i / #sortedSel)
    source, err = safeLine sub[index], collection, "Selected line #{index}"
    return windowError err unless source
    unless source and source.class == "dialogue" and not source.comment
      return windowError "Selection contains a non-dialogue or commented line."
    if collection.styles and not source.styleRef
      source.styleRef = collection.styles[source.style]
    sourceOpts = opts
    if frameContexts[index]
      sourceOpts = LineOps.copy opts
      sourceOpts._frame_context = frameContexts[index]
    lines, err = safeOutputsFor source, collection, sourceOpts
    return windowError err unless lines and #lines > 0
    plans[#plans + 1] = {index: index, source: source, lines: lines}
  actualTotal = 0
  for plan in *plans
    actualTotal += #plan.lines
  return unless confirmLargeOutput actualTotal, "the actual output"
  okApply, generatedOrError = pcall ->
    LineOps.transaction sub, script_name, ->
      inserted = 0
      generatedSelection = {}
      for i, plan in ipairs plans
        sourceIndex = plan.index + inserted
        commented, commentErr = safeLine plan.source, collection, "Commented source line"
        error commentErr unless commented
        commented.comment = true
        sub[sourceIndex] = commented
        insertAt = sourceIndex + 1
        for line in *plan.lines
          LineOps.checkCancelled!
          sub.insert insertAt, line
          generatedSelection[#generatedSelection + 1] = insertAt
          insertAt += 1
        inserted += #plan.lines
        progressSet 50 + math.floor(50 * i / #plans)
      generatedSelection
  return windowError "Could not apply generated lines atomically: #{generatedOrError}" unless okApply
  generatedOrError

main = (sub, sel) ->
  opts = readOptions!
  runWithOptions sub, sel, opts

validateAny = -> true

validateEffect = (effect) ->
  spec = effectSpec effect
  if spec.kind == "pair_morph"
    (sub, sel) -> validate(sub, sel) and #sel == 2
  else
    validate

hotkeyMenuPath = (effect) ->
  HotkeyMenuRoot .. "/" .. HotkeyMenuScript .. "/" .. (EffectCategory[effect] or "Other") .. "/" .. effect

actionMacro = (effect) ->
  (sub, sel) ->
    opts = showEffectOptions effect
    return if opts == "__back"
    runWithOptions sub, sel, opts

helpMacro = ->
  category = Defaults.category
  current = Defaults.effect
  while true
    gui = pickerGui category, current
    button, result = aegisub.dialog.display gui, {"Refresh", "Close"}, {ok: "Refresh", close: "Close"}
    return unless button == "Refresh"
    category = choiceOrDefault result and result.category or category, Categories, category
    pool = CategoryEffects[category] or Effects
    current = choiceOrDefault result and result.operation or current, pool, pool[1]

registerMacro = (name, description, process, validateFn) ->
  if depctrl and depctrl.registerMacro
    depctrl\registerMacro name, description, process, validateFn, nil, false
  else
    aegisub.register_macro name, description, process, validateFn

registerMacro script_name, script_description, main, validate
registerMacro "#{script_name}/Help", "Show #{script_name} effect help.", helpMacro, validateAny
for effect in *Effects
  registerMacro hotkeyMenuPath(effect), EffectHelp[effect] or script_description, actionMacro(effect), validateEffect(effect)

require("kite.UI").publishActions()
