export script_name        = "Zagreo Glyphs"
export script_description = "Generate vector-path glyph animation moments from ASS text or drawings"
export script_author      = "Kiterow"
export script_version     = "1.1.2"
export script_namespace   = "kite.ZagreoGlyphs"

CONFIG_FILE = "kite-zagreo-glyphs.json"

local LineCollection, Line, ASS, ConfigHandler, KiteUI, LineOps, Yutils, depctrl
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
    {"kite.UI", version: "1.1.3", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    {"kite.LineOps", version: "1.5.2", url: "https://github.com/Kiterowx/Kite-Aegisub-Scripts",
      feed: "https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json"}
    "Yutils"
  }
}
LineCollection, Line, ASS, KiteUI, LineOps, Yutils = depctrl\requireModules!
ConfigHandler = (interface, file_name, _has_sections, version) ->
  KiteUI.dialogHandler interface, script_namespace, version, {
    {path: "?user/" .. file_name, format: "json_sections"}
  }

EFFECT_META = {}
_E = (name, category, help, spec) ->
  EFFECT_META[#EFFECT_META + 1] = {name, category, help, spec}

_E "Font Morph", "Morph", "Text becomes the same text in another font through vector in-betweens.", {kind: "morph"}
_E "Font Morph Elastic", "Morph", "Font morph with overshoot and recoil.", {kind: "morph", elastic: true}
_E "Font Morph Overshoot", "Morph", "Pushes the shape past the target font before settling.", {kind: "morph", curve: "overshoot"}
_E "Font Morph Anticipation", "Morph", "Backs away briefly before morphing into the target font.", {kind: "morph", curve: "anticipation"}
_E "Font Morph Bounce", "Morph", "Morphs with a bouncing final approach.", {kind: "morph", curve: "bounce"}
_E "Font Morph Steps", "Morph", "Stepped vector states between fonts.", {kind: "morph", curve: "steps"}
_E "Font Morph Glitch", "Morph", "Morphs while corrupting intermediate coordinates.", {kind: "morph", curve: "glitch"}
_E "Font Morph Rubber", "Morph", "Stretches the in-between shape like elastic material.", {kind: "morph", curve: "rubber"}
_E "Pair Morph", "Morph", "Morphs the first selected line into the second selected line.", {kind: "pair_morph"}
_E "Pair Morph Elastic", "Morph", "Selected-line morph with overshoot and recoil.", {kind: "pair_morph", elastic: true}
_E "Pair Morph Overshoot", "Morph", "Selected-line morph passing the target before settling.", {kind: "pair_morph", curve: "overshoot"}
_E "Pair Morph Bounce", "Morph", "Selected-line morph with a bouncing approach.", {kind: "pair_morph", curve: "bounce"}
_E "Blob Morph In", "Morph", "Each contour enters as a round blob and resolves into the drawing.", {kind: "shape_morph", mode: "blob", phase: "in"}
_E "Blob Morph Out", "Morph", "Contours relax into round blobs and leave.", {kind: "shape_morph", mode: "blob", phase: "out"}
_E "Blob Pulse", "Morph", "Contours cyclically soften toward blobs and back, lava-lamp style.", {kind: "shape_morph", mode: "blob", d: {period: 1400}}
_E "Line Sweep In", "Morph", "Contours unfold from flat horizontal strokes into the drawing.", {kind: "shape_morph", mode: "line", phase: "in"}
_E "Line Sweep Out", "Morph", "Contours collapse into flat horizontal strokes.", {kind: "shape_morph", mode: "line", phase: "out"}
_E "Spike Morph In", "Morph", "Contours enter as star bursts and settle into the drawing.", {kind: "shape_morph", mode: "star", phase: "in", d: {frequency: 5}}
_E "Spike Morph Out", "Morph", "Contours sharpen into star bursts and leave.", {kind: "shape_morph", mode: "star", phase: "out", d: {frequency: 5}}
_E "Scribble Morph In", "Morph", "Contours enter as loose scribbles that tighten into the drawing.", {kind: "shape_morph", mode: "scribble", phase: "in", d: {seed: 77}}
_E "Scribble Morph Out", "Morph", "Contours unravel into loose scribbles.", {kind: "shape_morph", mode: "scribble", phase: "out", d: {seed: 77}}

_E "Boiling Line", "Surface", "Constant organic boil over every path point, period-locked.", {kind: "field", mode: "boil", d: {strength: 5, period: 280, noise_scale: 55}}
_E "Electric Jitter", "Surface", "Hard unsmoothed per-frame jitter, like electric interference.", {kind: "field", mode: "electric", d: {strength: 4, period: 120}}
_E "Handwriting Noise", "Surface", "Slow hand-drawn wobble of the whole outline.", {kind: "field", mode: "handwriting", d: {strength: 6, period: 900, noise_scale: 140}}
_E "Ink Wobble", "Surface", "Loose sine sway over the vector outline.", {kind: "field", mode: "wobble", d: {strength: 5, period: 1100}}
_E "Fine Contour Jitter", "Surface", "Small fast per-point contour jitter.", {kind: "field", mode: "fine_jitter", d: {strength: 3, period: 200}}
_E "Coarse Zone Jitter", "Surface", "Chunky zone-based jitter; whole regions jump together.", {kind: "field", mode: "coarse_jitter", d: {strength: 8, period: 260, noise_scale: 90}}
_E "Organic Drift", "Surface", "Slow wandering deformation that never repeats.", {kind: "field", mode: "drift", d: {strength: 10, period: 2400, noise_scale: 160}}
_E "Heat Haze", "Surface", "Upward-drifting shimmer bands, like air over fire.", {kind: "field", mode: "heat", d: {strength: 7, period: 700, frequency: 4}}
_E "Water Flow", "Surface", "Sideways-advecting refraction wobble.", {kind: "field", mode: "water", d: {strength: 8, period: 1600, frequency: 3}}
_E "Gelatin Wobble", "Surface", "Springy low-frequency jiggle with damped recoil.", {kind: "field", mode: "gelatin", d: {strength: 10, period: 1000, frequency: 2}}
_E "Underwater Sway", "Surface", "Big slow current sway plus fine refraction.", {kind: "field", mode: "underwater", d: {strength: 12, period: 2200, frequency: 1.5}}
_E "Windblown Turbulence", "Surface", "Directional gusts ripping at the outline in bursts.", {kind: "field", mode: "windblown", dir: true, d: {strength: 10, period: 800, noise_scale: 110}}
_E "Static Buzz", "Surface", "One-frame alternating offsets, like TV static tremble.", {kind: "field", mode: "buzz", d: {strength: 2.5, period: 80}}

_E "Wave Horizontal", "Wave", "Traveling horizontal wave running through the drawing.", {kind: "field", mode: "wave_h", d: {strength: 10, frequency: 2, period: 900}}
_E "Wave Vertical", "Wave", "Traveling vertical wave running through the drawing.", {kind: "field", mode: "wave_v", d: {strength: 10, frequency: 2, period: 900}}
_E "Wave Diagonal", "Wave", "Traveling diagonal wave running through the drawing.", {kind: "field", mode: "wave_d", d: {strength: 10, frequency: 2, period: 900}}
_E "Standing Wave", "Wave", "Standing wave with fixed nodes and swinging antinodes.", {kind: "field", mode: "wave_standing", d: {strength: 10, frequency: 3, period: 900}}
_E "Flag Wave", "Wave", "Wave whose amplitude grows away from the anchored edge, like a flag.", {kind: "field", mode: "flag", dir: true, d: {strength: 14, frequency: 2, period: 800}}
_E "Skip Rope", "Wave", "Whole shape swings like a rope anchored at both ends.", {kind: "field", mode: "skiprope", d: {strength: 18, period: 1000}}
_E "Seaweed Sway", "Wave", "Anchored at the bottom, sways more toward the top.", {kind: "field", mode: "seaweed", d: {strength: 12, period: 1600}}
_E "Twist Wave", "Wave", "Local rotation angle waves along the axis, like a twisting ribbon.", {kind: "field", mode: "twist_wave", dir: true, d: {strength: 30, frequency: 1.5, period: 1400}}
_E "Whip Crack", "Wave", "A single amplitude spike whips through the shape once per period.", {kind: "field", mode: "whip", dir: true, d: {strength: 16, period: 1200}}
_E "Ripple Center", "Wave", "Circular ripple radiating from the drawing center.", {kind: "field", mode: "ripple", d: {strength: 8, frequency: 3, period: 900}}
_E "Ripple Point", "Wave", "Circular ripple from an adjustable off-center origin.", {kind: "field", mode: "ripple_point", off: true, d: {strength: 8, frequency: 3, period: 900, x_offset: -30, y_offset: -20}}
_E "Ripple Rain", "Wave", "New ripple origins keep appearing at random spots.", {kind: "field", mode: "ripple_rain", d: {strength: 7, frequency: 4, period: 700}}
_E "Cross Ripple", "Wave", "Two ripple origins interfering across the shape.", {kind: "field", mode: "ripple_cross", off: true, d: {strength: 7, frequency: 3, period: 900, x_offset: -35, y_offset: 35}}
_E "Bounce Wave", "Wave", "Rectified wave; crests bounce instead of swinging through.", {kind: "field", mode: "wave_bounce", d: {strength: 12, frequency: 2, period: 800}}
_E "Wave Settle In", "Wave", "Enters waving hard, then the wave dies down to the clean shape.", {kind: "field", mode: "wave_h", phase: "in", d: {strength: 16, frequency: 2, period: 700}}
_E "Wave Break Out", "Wave", "The wave grows until it breaks the shape apart on exit.", {kind: "field", mode: "wave_h", phase: "out", d: {strength: 22, frequency: 2, period: 700}}

_E "Twist Sway", "Radial", "The shape twists back and forth around its center.", {kind: "field", mode: "twist_sway", d: {strength: 20, period: 1300}}
_E "Vortex Swirl", "Radial", "Continuous circulation around the center with radial falloff.", {kind: "field", mode: "vortex_swirl", d: {strength: 14, period: 1600}}
_E "Magnet Pulse", "Radial", "An off-center attractor pulls the outline in pulses.", {kind: "field", mode: "magnet", off: true, d: {strength: 14, period: 1100, x_offset: -25, y_offset: -10}}
_E "Pinch Pulse", "Radial", "The shape rhythmically pinches toward its center.", {kind: "field", mode: "pinch_pulse", d: {strength: 25, period: 1000}}
_E "Bulge Pulse", "Radial", "The shape rhythmically bulges outward from its center.", {kind: "field", mode: "bulge_pulse", d: {strength: 25, period: 1000}}
_E "Heartbeat", "Radial", "Double-thump radial pulse per period, like a heartbeat.", {kind: "field", mode: "heartbeat_r", d: {strength: 18, period: 1200}}
_E "Spring Boing", "Radial", "Squash-and-stretch spring bounce with damped recoil.", {kind: "field", mode: "spring", d: {strength: 20, period: 900}}
_E "Lens Sweep", "Radial", "A magnifying bulge sweeps across the shape each period.", {kind: "field", mode: "lens", off: true, d: {strength: 30, period: 1500}}
_E "Shockwave", "Radial", "A displacement ring travels outward once per period.", {kind: "field", mode: "shock", d: {strength: 14, period: 1300}}
_E "Pulse Rings", "Radial", "Concentric rings breathe in alternating directions.", {kind: "field", mode: "rings", d: {strength: 6, frequency: 4, period: 900}}
_E "Lag Orbit", "Radial", "The shape orbits a small circle; inner points lag behind, jelly-like.", {kind: "field", mode: "lag_orbit", d: {strength: 10, period: 1000}}

_E "Rough Edge", "Edge", "Multi-octave roughening along the outline normal.", {kind: "field", mode: "rough", d: {strength: 5, noise_scale: 30, period: 600}}
_E "Rough Edge Progressive", "Edge", "Rough edge grows from clean to fully rough over the line.", {kind: "field", mode: "rough", env: "grow", d: {strength: 7, noise_scale: 30, period: 600}}
_E "Rough Edge Calming", "Edge", "Rough edge settles down to clean over the line.", {kind: "field", mode: "rough", env: "fade", d: {strength: 7, noise_scale: 30, period: 600}}
_E "Serrated Edge", "Edge", "Regular symmetric saw teeth along the outline.", {kind: "field", mode: "serrate", d: {strength: 5, frequency: 26, period: 1200}}
_E "Sawtooth Edge", "Edge", "Asymmetric leaning teeth along the outline.", {kind: "field", mode: "sawtooth", d: {strength: 6, frequency: 22, period: 1200}}
_E "Bitten Edge", "Edge", "A few deep smooth bites dent the outline.", {kind: "field", mode: "bitten", d: {strength: 9, frequency: 7, period: 1600}}
_E "Corroded Edge", "Edge", "High-frequency inward pitting, like rust eating the edge.", {kind: "field", mode: "corrode", d: {strength: 6, noise_scale: 14, period: 900}}
_E "Charcoal Edge", "Edge", "Grainy layered noise with per-frame flicker, like charcoal strokes.", {kind: "field", mode: "charcoal", d: {strength: 5, noise_scale: 20, period: 180}}
_E "Chalk Edge", "Edge", "Broken chalky edge; short runs shift sideways off the line.", {kind: "field", mode: "chalk", d: {strength: 5, frequency: 30, period: 700}}
_E "Crayon Edge", "Edge", "Waxy low-frequency lateral wobble, like crayon pressure.", {kind: "field", mode: "crayon", d: {strength: 4, frequency: 8, period: 1000}}
_E "Dry Brush Edge", "Edge", "Streaks dragged along the outline tangent, like a dry brush.", {kind: "field", mode: "drybrush", d: {strength: 7, noise_scale: 24, period: 800}}
_E "Spray Edge", "Edge", "Outward-only fuzz spikes, like spray paint bleed.", {kind: "field", mode: "spray", d: {strength: 8, noise_scale: 10, period: 300}}
_E "Living Edge", "Edge", "Edge noise crawls along the outline instead of boiling in place.", {kind: "field", mode: "living", d: {strength: 6, frequency: 8, period: 800}}
_E "Electric Edge", "Edge", "Sharp lightning zigzags flickering along the outline.", {kind: "field", mode: "electric_edge", d: {strength: 8, frequency: 18, period: 140}}
_E "Fur Edge", "Edge", "Dense swaying hair spikes along the outline.", {kind: "field", mode: "fur", d: {strength: 9, frequency: 40, period: 900}}
_E "Frost Edge", "Edge", "Angular crystalline jitter with sparkle flicker.", {kind: "field", mode: "frost", d: {strength: 6, frequency: 24, period: 400}}
_E "Torn Edge", "Edge", "Sparse deep tears rip the outline, like torn paper.", {kind: "field", mode: "torn", d: {strength: 14, frequency: 5, period: 1400}}
_E "Postage Stamp", "Edge", "Regular semicircular perforations along the outline.", {kind: "field", mode: "stamp", d: {strength: 6, frequency: 18, period: 2000}}
_E "Cloud Edge", "Edge", "Bulbous rounded lobes swell outward along the outline.", {kind: "field", mode: "cloud", d: {strength: 10, frequency: 8, period: 1800}}
_E "Thorn Edge", "Edge", "Sparse long thorn spikes grow outward.", {kind: "field", mode: "thorn", d: {strength: 16, frequency: 9, period: 1600}}
_E "Scallop Edge", "Edge", "Regular scalloped arcs along the outline.", {kind: "field", mode: "scallop", d: {strength: 7, frequency: 14, period: 2000}}
_E "Bubble Edge", "Edge", "Foamy bubbles keep swelling and popping along the edge.", {kind: "field", mode: "bubble", d: {strength: 8, frequency: 12, period: 600}}

_E "Ink Spread In", "Ink", "Ink soaks outward along the outline normals until it lands.", {kind: "field", mode: "spread", phase: "in", d: {strength: 10}}
_E "Ink Dry Out", "Ink", "The outline dries and crumbles inward as it leaves.", {kind: "field", mode: "dry", phase: "out", d: {strength: 10}}
_E "Wet Ink", "Ink", "Wet ink swells and settles cyclically while wobbling.", {kind: "field", mode: "wet", d: {strength: 7, period: 1200}}
_E "Watercolor Bloom In", "Ink", "Blotchy lobed blooming into place, like watercolor on paper.", {kind: "field", mode: "bloom", phase: "in", d: {strength: 14, frequency: 5}}
_E "Ink Absorb Out", "Ink", "The shape sinks and shrinks as paper absorbs it.", {kind: "field", mode: "absorb", phase: "out", d: {strength: 12}}
_E "Smoke Away Out", "Ink", "The outline drifts upward and swirls apart like smoke.", {kind: "field", mode: "smoke", phase: "out", d: {strength: 26, noise_scale: 70}}
_E "Steam Rise", "Ink", "Gentle rising shimmer lobes, like steam off the shape.", {kind: "field", mode: "steam", d: {strength: 8, period: 1500}}
_E "Burn Away Out", "Ink", "A burn front eats the shape from one side with ember flicker.", {kind: "field", mode: "burn", phase: "out", dir: true, d: {strength: 12}}
_E "Boil Away Out", "Ink", "Boils harder and harder until it evaporates upward.", {kind: "field", mode: "boiloff", phase: "out", d: {strength: 14, period: 300}}
_E "Bleed Through In", "Ink", "Ink bleeds in from scattered seed patches along the outline.", {kind: "field", mode: "bleed", phase: "in", d: {strength: 12, frequency: 6}}
_E "Frost Creep In", "Ink", "Crystalline frost creeps over the outline into place.", {kind: "field", mode: "frost_creep", phase: "in", d: {strength: 8, frequency: 20}}

_E "Ink Drip", "Drip", "Discrete drip fingers grow from the lower outline.", {kind: "field", mode: "drip", env: "grow", d: {strength: 26, frequency: 7}}
_E "Bottom Drips", "Drip", "Heavier drips pull from the bottom edge.", {kind: "field", mode: "bottom", env: "grow", d: {strength: 34, frequency: 6}}
_E "Side Drips", "Drip", "Drips run sideways off the outer edges.", {kind: "field", mode: "side", env: "grow", d: {strength: 26, frequency: 7}}
_E "Falling Stain", "Drip", "The whole outline smears downward into a falling stain.", {kind: "field", mode: "stain", env: "grow", d: {strength: 40}}
_E "Melt Down", "Drip", "Melts downward and pools on an invisible floor.", {kind: "field", mode: "melt", env: "grow", d: {strength: 50}}
_E "Diagonal Melt", "Drip", "Melts diagonally, dragging sideways while it sags.", {kind: "field", mode: "melt_diag", env: "grow", d: {strength: 45}}
_E "Rain Wash", "Drip", "Vertical streak columns wash the shape downward.", {kind: "field", mode: "rainwash", env: "grow", d: {strength: 36, frequency: 9}}
_E "Slime Stretch", "Drip", "Lower outline stretches like slime and recoils, cyclically.", {kind: "field", mode: "slime", d: {strength: 30, period: 1400}}
_E "Slime Snap In", "Drip", "Enters overstretched like slime and snaps into shape.", {kind: "field", mode: "slime_snap", phase: "in", d: {strength: 36}}
_E "Puddle Expansion", "Drip", "The lower part spreads out into a widening puddle.", {kind: "field", mode: "puddle", env: "grow", d: {strength: 30}}
_E "Icicle Growth", "Drip", "Icicle spikes grow downward from the lower outline.", {kind: "field", mode: "icicle", env: "grow", d: {strength: 24, frequency: 8}}
_E "Candle Melt", "Drip", "Slow cyclic sag and recovery, like softening candle wax.", {kind: "field", mode: "candle", d: {strength: 18, period: 2600}}
_E "Drip Loop", "Drip", "Drip fingers form, fall and reset every period.", {kind: "field", mode: "drip_loop", d: {strength: 28, frequency: 6, period: 1600}}

_E "Wave Along Path", "Path", "A wave travels along the outline arc length itself.", {kind: "field", mode: "path_wave", d: {strength: 6, frequency: 6, period: 900}}
_E "Traveling Bulge", "Path", "A single lump laps the outline each period, like a swallowed pulse.", {kind: "field", mode: "path_bulge", d: {strength: 10, period: 1400}}
_E "Peristalsis", "Path", "Several lumps crawl along the outline in sequence.", {kind: "field", mode: "path_peristalsis", d: {strength: 8, frequency: 4, period: 1200}}
_E "Path Flow", "Path", "Points advect along the outline tangent; the contour crawls over itself.", {kind: "field", mode: "path_flow", d: {strength: 8, period: 1000}}
_E "Snake Run", "Path", "One visible segment laps the outline like a snake.", {kind: "subpath", mode: "snake", d: {strength: 30, period: 1600}}
_E "Snake Chase", "Path", "Two segments chase each other around the outline in opposite phase.", {kind: "subpath", mode: "snake_chase", d: {strength: 24, period: 1600}}
_E "Dash March", "Path", "The outline becomes marching dashes, ant-trail style.", {kind: "subpath", mode: "dash_march", d: {frequency: 9, period: 1000}}
_E "Dotted March", "Path", "The outline becomes marching dots.", {kind: "subpath", mode: "dot_march", d: {frequency: 22, period: 1000, strength: 4}}
_E "Morse Flicker", "Path", "Random dash-dot patterns retile the outline every beat.", {kind: "subpath", mode: "morse", d: {frequency: 10, period: 400}}
_E "Segment Flicker", "Path", "Random outline segments cut out per frame, like a failing neon sign.", {kind: "subpath", mode: "seg_flicker", d: {period: 160}}
_E "Path Retract", "Path", "A running segment grows and shrinks while lapping the outline.", {kind: "subpath", mode: "path_retract", d: {period: 1800}}
_E "Crawl Bugs", "Path", "Many short wiggling dashes crawl along the outline.", {kind: "subpath", mode: "crawl", d: {frequency: 14, period: 900, strength: 3}}

_E "Stroke Reveal In", "Reveal", "Every contour draws itself on in parallel.", {kind: "subpath", mode: "prefix_parallel", phase: "in"}
_E "Stroke Reveal Out", "Reveal", "Every contour erases itself in parallel.", {kind: "subpath", mode: "prefix_parallel", phase: "out"}
_E "Handwriting Reveal In", "Reveal", "Contours draw on one after another by arc length, like real writing.", {kind: "subpath", mode: "prefix_sequential", phase: "in"}
_E "Handwriting Reveal Out", "Reveal", "Contours erase sequentially, unwriting the drawing.", {kind: "subpath", mode: "prefix_sequential", phase: "out"}
_E "Segment Pop In", "Reveal", "Path chunks pop on in drawing order, stepped.", {kind: "subpath", mode: "prefix_chunk", phase: "in", d: {frequency: 8}}
_E "Segment Pop Out", "Reveal", "Path chunks pop off in drawing order, stepped.", {kind: "subpath", mode: "prefix_chunk", phase: "out", d: {frequency: 8}}
_E "Random Segment In", "Reveal", "Randomized outline segments accumulate until the drawing completes.", {kind: "subpath", mode: "prefix_random", phase: "in"}
_E "Random Segment Out", "Reveal", "Randomized outline segments drop until nothing remains.", {kind: "subpath", mode: "prefix_random", phase: "out"}
_E "Dash Reveal In", "Reveal", "A dash pattern whose gaps close until the outline is solid.", {kind: "subpath", mode: "prefix_dash", phase: "in", d: {frequency: 12}}
_E "Dash Reveal Out", "Reveal", "Gaps open across the outline until it dissolves into dashes.", {kind: "subpath", mode: "prefix_dash", phase: "out", d: {frequency: 12}}
_E "Organic Wipe In", "Reveal", "Directional wipe with an irregular organic frontier.", {kind: "field", mode: "wipe_organic", phase: "in", dir: true, d: {strength: 60}}
_E "Organic Wipe Out", "Reveal", "Directional wipe-out with an irregular organic frontier.", {kind: "field", mode: "wipe_organic", phase: "out", dir: true, d: {strength: 60}}
_E "Wavy Wipe In", "Reveal", "Directional wipe with a sine-wave frontier.", {kind: "field", mode: "wipe_wavy", phase: "in", dir: true, d: {strength: 50, frequency: 3}}
_E "Wavy Wipe Out", "Reveal", "Directional wipe-out with a sine-wave frontier.", {kind: "field", mode: "wipe_wavy", phase: "out", dir: true, d: {strength: 50, frequency: 3}}
_E "Shaky Wipe In", "Reveal", "Wipe whose frontier trembles every frame.", {kind: "field", mode: "wipe_shaky", phase: "in", dir: true, d: {strength: 60, period: 120}}
_E "Shaky Wipe Out", "Reveal", "Wipe-out whose frontier trembles every frame.", {kind: "field", mode: "wipe_shaky", phase: "out", dir: true, d: {strength: 60, period: 120}}
_E "Ink Wipe In", "Reveal", "Wipe with long ink fingers reaching ahead of the frontier.", {kind: "field", mode: "wipe_ink", phase: "in", dir: true, d: {strength: 80, frequency: 5}}
_E "Ink Wipe Out", "Reveal", "Wipe-out with trailing ink fingers.", {kind: "field", mode: "wipe_ink", phase: "out", dir: true, d: {strength: 80, frequency: 5}}
_E "Iris Reveal In", "Reveal", "Radial reveal expanding from an adjustable center.", {kind: "field", mode: "wipe_iris", phase: "in", off: true, d: {strength: 50}}
_E "Iris Reveal Out", "Reveal", "Radial collapse toward an adjustable center.", {kind: "field", mode: "wipe_iris", phase: "out", off: true, d: {strength: 50}}
_E "Swirl Wipe In", "Reveal", "Angular sweep reveal with points swirling onto the frontier.", {kind: "field", mode: "wipe_swirl", phase: "in", d: {strength: 60}}
_E "Swirl Wipe Out", "Reveal", "Angular sweep erase with points swirling off the frontier.", {kind: "field", mode: "wipe_swirl", phase: "out", d: {strength: 60}}
_E "Diagonal Wipe In", "Reveal", "Wipe along the diagonal with a soft collapsing frontier.", {kind: "field", mode: "wipe_diag", phase: "in", d: {strength: 50}}
_E "Diagonal Wipe Out", "Reveal", "Wipe-out along the diagonal with a soft collapsing frontier.", {kind: "field", mode: "wipe_diag", phase: "out", d: {strength: 50}}

_E "Noise Dissolve In", "Dissolve", "Points condense from noise-scattered clusters into the drawing.", {kind: "field", mode: "ds_noise", phase: "in", d: {strength: 60}}
_E "Noise Dissolve Out", "Dissolve", "Points scatter into noise clusters until the drawing dissolves.", {kind: "field", mode: "ds_noise", phase: "out", d: {strength: 60}}
_E "Erode In", "Dissolve", "The shape rebuilds from an eroded crumble.", {kind: "field", mode: "ds_erode", phase: "in", d: {strength: 30}}
_E "Erode Out", "Dissolve", "Noise erodes the shape inward until it crumbles away.", {kind: "field", mode: "ds_erode", phase: "out", d: {strength: 30}}
_E "Split Wipe In", "Dissolve", "Opens from the center line outward to both sides.", {kind: "field", mode: "ds_split", phase: "in", dir: true, d: {strength: 50}}
_E "Split Wipe Out", "Dissolve", "Closes from both sides into the center line.", {kind: "field", mode: "ds_split", phase: "out", dir: true, d: {strength: 50}}
_E "Band Dissolve In", "Dissolve", "Alternating bands slide into place from opposite sides.", {kind: "field", mode: "ds_band", phase: "in", dir: true, d: {strength: 60, frequency: 6}}
_E "Band Dissolve Out", "Dissolve", "Alternating bands slide apart to opposite sides.", {kind: "field", mode: "ds_band", phase: "out", dir: true, d: {strength: 60, frequency: 6}}
_E "Checker Dissolve In", "Dissolve", "Grid cells assemble in a staggered checkerboard order.", {kind: "field", mode: "ds_checker", phase: "in", d: {strength: 50, frequency: 5}}
_E "Checker Dissolve Out", "Dissolve", "Grid cells collapse in a staggered checkerboard order.", {kind: "field", mode: "ds_checker", phase: "out", d: {strength: 50, frequency: 5}}
_E "Crystallize In", "Dissolve", "Enters as coarse crystal facets that refine into the drawing.", {kind: "field", mode: "ds_crystal", phase: "in", d: {strength: 14}}
_E "Crystallize Out", "Dissolve", "Coordinates snap to coarser and coarser crystal facets.", {kind: "field", mode: "ds_crystal", phase: "out", d: {strength: 14}}

_E "Accordion Fold In", "Fold", "Unfolds from compressed zigzag pleats.", {kind: "field", mode: "accordion", phase: "in", dir: true, d: {frequency: 5, strength: 20}}
_E "Accordion Fold Out", "Fold", "Compresses into zigzag pleats toward one edge.", {kind: "field", mode: "accordion", phase: "out", dir: true, d: {frequency: 5, strength: 20}}
_E "Roll In", "Fold", "Unrolls from a cylinder rolled at one edge.", {kind: "field", mode: "roll", phase: "in", dir: true, d: {strength: 30}}
_E "Roll Out", "Fold", "Rolls up into a cylinder toward one edge.", {kind: "field", mode: "roll", phase: "out", dir: true, d: {strength: 30}}
_E "Twist Collapse In", "Fold", "Untwists from a corkscrew along the axis into place.", {kind: "field", mode: "twistc", phase: "in", dir: true, d: {frequency: 1.5}}
_E "Twist Collapse Out", "Fold", "Twists into a corkscrew along the axis and collapses.", {kind: "field", mode: "twistc", phase: "out", dir: true, d: {frequency: 1.5}}
_E "Fan Unfold In", "Fold", "Opens like fan blades rotating from a corner pivot.", {kind: "field", mode: "fan", phase: "in", dir: true, d: {strength: 90}}
_E "Fan Fold Out", "Fold", "Folds shut like fan blades into a corner pivot.", {kind: "field", mode: "fan", phase: "out", dir: true, d: {strength: 90}}
_E "Blinds In", "Fold", "Venetian slats rotate open into the drawing.", {kind: "field", mode: "blinds", phase: "in", dir: true, d: {frequency: 6}}
_E "Blinds Out", "Fold", "Venetian slats rotate shut and flatten the drawing.", {kind: "field", mode: "blinds", phase: "out", dir: true, d: {frequency: 6}}
_E "Crumple In", "Fold", "Uncrumples from a balled-up wad into the drawing.", {kind: "field", mode: "crumple", phase: "in", d: {frequency: 6, strength: 60}}
_E "Crumple Out", "Fold", "Crumples into a balled-up wad along random creases.", {kind: "field", mode: "crumple", phase: "out", d: {frequency: 6, strength: 60}}

_E "Jelly Impact In", "Impact", "Drops in and rings out with damped jelly wobbles.", {kind: "field", mode: "jelly", phase: "in", d: {strength: 22, frequency: 3}}
_E "Jelly Release Out", "Impact", "Starts ringing and springs away like released jelly.", {kind: "field", mode: "jelly", phase: "out", d: {strength: 22, frequency: 3}}
_E "Radial Burst Out", "Impact", "Every point flies straight out from the center.", {kind: "field", mode: "burst", phase: "out", d: {strength: 80}}
_E "Radial Gather In", "Impact", "Points fly in from far outside and lock into the drawing.", {kind: "field", mode: "burst", phase: "in", d: {strength: 80}}
_E "Vortex In", "Impact", "Points spiral inward from a wide orbit into place.", {kind: "field", mode: "vortexp", phase: "in", d: {strength: 70}}
_E "Vortex Out", "Impact", "Points spiral outward into a widening orbit.", {kind: "field", mode: "vortexp", phase: "out", d: {strength: 70}}
_E "Gravity Sag Out", "Impact", "The shape progressively sags and slumps downward.", {kind: "field", mode: "sag", phase: "out", d: {strength: 30}}
_E "Gravity Recover In", "Impact", "Starts slumped and straightens up into the drawing.", {kind: "field", mode: "sag", phase: "in", d: {strength: 30}}
_E "Wind Sweep Out", "Impact", "Wind shears the shape apart toward the chosen direction.", {kind: "field", mode: "wind", phase: "out", dir: true, d: {strength: 60}}
_E "Wind Settle In", "Impact", "Blown-away tatters settle back against the wind.", {kind: "field", mode: "wind", phase: "in", dir: true, d: {strength: 60}}
_E "Shiver In", "Impact", "Arrives trembling; the shiver dies down as it settles.", {kind: "field", mode: "shiver", phase: "in", d: {strength: 8, period: 100}}
_E "Shiver Out", "Impact", "A growing shiver shakes the shape apart.", {kind: "field", mode: "shiver", phase: "out", d: {strength: 8, period: 100}}
_E "Slam Shock In", "Impact", "Slams into place and fires one shock ring outward.", {kind: "field", mode: "slam", phase: "in", d: {strength: 26}}
_E "Kickback Out", "Impact", "Recoils opposite the direction, then snaps away along it.", {kind: "field", mode: "kickback", phase: "out", dir: true, d: {strength: 50}}

_E "Contour Bob", "Contour", "Each contour bobs up and down with its own phase.", {kind: "contour", mode: "c_bob", d: {strength: 6, period: 1000}}
_E "Contour Sway", "Contour", "Each contour rocks around its own centroid.", {kind: "contour", mode: "c_sway", d: {strength: 10, period: 1200}}
_E "Contour Orbit", "Contour", "Each contour circles a tiny orbit, phase-staggered.", {kind: "contour", mode: "c_orbit", d: {strength: 5, period: 1300}}
_E "Contour Breathe", "Contour", "Each contour pulses around its own centroid, staggered.", {kind: "contour", mode: "c_breathe", d: {strength: 8, period: 1400}}
_E "Contour Wave", "Contour", "A lift wave travels across the contours, stadium-wave style.", {kind: "contour", mode: "c_wave", dir: true, d: {strength: 12, period: 1100}}
_E "Contour Heartbeat", "Contour", "Contours thump with a double-beat pulse in sequence.", {kind: "contour", mode: "c_heart", d: {strength: 10, period: 1200}}
_E "Contour Jolt", "Contour", "Random contours jump to offset positions each beat.", {kind: "contour", mode: "c_jolt", d: {strength: 10, period: 200}}
_E "Contour Blink", "Contour", "Random contours cut out per beat, like broken sign letters.", {kind: "contour", mode: "c_blink", d: {period: 220}}
_E "Contour Carousel", "Contour", "Contours ride a slow circular conga around their positions.", {kind: "contour", mode: "c_carousel", d: {strength: 16, period: 2000}}
_E "Contour Pop In", "Contour", "Contours pop in from zero scale with overshoot, staggered.", {kind: "contour", mode: "c_pop", phase: "in", curve: "overshoot"}
_E "Contour Pop Out", "Contour", "Contours shrink away to zero scale, staggered.", {kind: "contour", mode: "c_pop", phase: "out", curve: "anticipation"}
_E "Contour Drop In", "Contour", "Contours fall in from above and bounce into place.", {kind: "contour", mode: "c_drop", phase: "in", curve: "bounce", d: {strength: 120}}
_E "Contour Drop Out", "Contour", "Contours drop off the layout downward, staggered.", {kind: "contour", mode: "c_drop", phase: "out", d: {strength: 120}}
_E "Contour Slide In", "Contour", "Contours slide in from the chosen direction, staggered.", {kind: "contour", mode: "c_slide", phase: "in", dir: true, d: {strength: 120}}
_E "Contour Slide Out", "Contour", "Contours slide out toward the chosen direction, staggered.", {kind: "contour", mode: "c_slide", phase: "out", dir: true, d: {strength: 120}}
_E "Contour Spin In", "Contour", "Contours spin in from a full rotation, staggered.", {kind: "contour", mode: "c_spin", phase: "in"}
_E "Contour Spin Out", "Contour", "Contours spin away, alternating turn directions.", {kind: "contour", mode: "c_spin", phase: "out"}
_E "Contour Scatter In", "Contour", "Contours fly in from random directions and rotations.", {kind: "contour", mode: "c_scatter", phase: "in", d: {strength: 140}}
_E "Contour Scatter Out", "Contour", "Contours scatter to random directions and rotations.", {kind: "contour", mode: "c_scatter", phase: "out", d: {strength: 140}}
_E "Contour Flip In", "Contour", "Contours flip in edge-on like turning cards, staggered.", {kind: "contour", mode: "c_flip", phase: "in"}
_E "Contour Flip Out", "Contour", "Contours flip away edge-on like turning cards.", {kind: "contour", mode: "c_flip", phase: "out"}
_E "Contour Zoom In", "Contour", "Contours zoom down from oversized into place, staggered.", {kind: "contour", mode: "c_zoom", phase: "in", d: {strength: 250}}
_E "Contour Zoom Out", "Contour", "Contours blow up past the camera, staggered.", {kind: "contour", mode: "c_zoom", phase: "out", d: {strength: 250}}
_E "Contour Typewriter In", "Contour", "Contours appear one by one in order, typewriter style.", {kind: "contour", mode: "c_type", phase: "in"}
_E "Contour Typewriter Out", "Contour", "Contours vanish one by one in order.", {kind: "contour", mode: "c_type", phase: "out"}
_E "Contour Domino In", "Contour", "Contours tip upright in sequence like falling dominoes reversed.", {kind: "contour", mode: "c_domino", phase: "in", dir: true}
_E "Contour Domino Out", "Contour", "Contours tip over in sequence like falling dominoes.", {kind: "contour", mode: "c_domino", phase: "out", dir: true}

_E "Shatter Out", "Shatter", "The filled shape breaks into spinning shards that burst outward.", {kind: "confetti", mode: "sh_burst", phase: "out", d: {strength: 60, layers: 6, alpha: 0}}
_E "Shatter In", "Shatter", "Spinning shards fly in and assemble the filled shape.", {kind: "confetti", mode: "sh_burst", phase: "in", d: {strength: 60, layers: 6, alpha: 0}}
_E "Crumble Down", "Shatter", "Shards break loose and pile up on an invisible floor.", {kind: "confetti", mode: "sh_crumble", phase: "out", d: {strength: 50, layers: 6, alpha: 0}}
_E "Sand Blow Out", "Shatter", "Grains blow away along the direction, front edge first.", {kind: "confetti", mode: "sh_sand", phase: "out", dir: true, d: {strength: 90, layers: 6, alpha: 0}}
_E "Sand Assemble In", "Shatter", "Grains blow in along the direction and settle into the shape.", {kind: "confetti", mode: "sh_sand", phase: "in", dir: true, d: {strength: 90, layers: 6, alpha: 0}}
_E "Dust Float Out", "Shatter", "Particles float up and drift apart like dust.", {kind: "confetti", mode: "sh_dust", phase: "out", d: {strength: 60, layers: 6, alpha: 0}}
_E "Dust Settle In", "Shatter", "Floating dust sinks and settles into the shape.", {kind: "confetti", mode: "sh_dust", phase: "in", d: {strength: 60, layers: 6, alpha: 0}}
_E "Swarm Out", "Shatter", "Particles spiral away like a startled swarm.", {kind: "confetti", mode: "sh_swarm", phase: "out", d: {strength: 90, layers: 6, alpha: 0}}
_E "Swarm In", "Shatter", "A swarm spirals in and condenses into the shape.", {kind: "confetti", mode: "sh_swarm", phase: "in", d: {strength: 90, layers: 6, alpha: 0}}
_E "Splash Out", "Shatter", "Droplets launch on ballistic arcs and fall away.", {kind: "confetti", mode: "sh_splash", phase: "out", d: {strength: 50, layers: 6, alpha: 0}}
_E "Confetti Rain In", "Shatter", "Pieces rain down from above and land into the shape.", {kind: "confetti", mode: "sh_rain", phase: "in", d: {strength: 120, layers: 6, alpha: 0}}
_E "Ember Drift", "Shatter", "Particles keep lifting off and rising like embers, cyclically.", {kind: "confetti", mode: "sh_ember", d: {strength: 60, layers: 6, alpha: 0, period: 1600}}
_E "Ash Fall Out", "Shatter", "The top edge flakes off first; ash flakes tumble down.", {kind: "confetti", mode: "sh_ash", phase: "out", d: {strength: 70, layers: 6, alpha: 0}}

_E "Corrupt Contour", "Glitch", "Short random coordinate bursts corrupt the outline per beat.", {kind: "field", mode: "g_corrupt", d: {strength: 14, period: 180}}
_E "Torn Static", "Glitch", "Ragged shear bursts with jagged torn edges, analog-static style.", {kind: "field", mode: "g_static", d: {strength: 12, period: 140}}
_E "Interlace Weave", "Glitch", "Odd and even scan rows shear in opposite directions.", {kind: "field", mode: "g_weave", d: {strength: 6, period: 400, frequency: 10}}
_E "Spike Burst", "Glitch", "Random single vertices spike out hard for a frame.", {kind: "field", mode: "g_spikes", d: {strength: 22, period: 200}}
_E "Dropout Holes", "Glitch", "Random point clusters collapse per beat, punching holes.", {kind: "field", mode: "g_dropout", d: {strength: 20, period: 240}}
_E "Quantize Pulse", "Glitch", "Coordinates snap to an oscillating grid, crystal-glitch style.", {kind: "field", mode: "g_quant", d: {strength: 10, period: 800}}
_E "Vertex Storm", "Glitch", "Vertices locally swap and churn positions every frame.", {kind: "field", mode: "g_storm", d: {strength: 12, period: 120}}

_E "Sketch Passes", "Sketch", "Stacked jittered pencil passes with blur and alpha.", {kind: "layer_deform", mode: "pencil", d: {layers: 3}}
_E "Scribble Passes", "Sketch", "Rougher stacked scribble passes with stronger offsets.", {kind: "layer_deform", mode: "scribble", d: {layers: 4, strength: 7}}

EFFECTS = [item[1] for item in *EFFECT_META]
EFFECT_SPECS = {}
EFFECT_CATEGORY = {}
EFFECT_HELP = {}
CATEGORIES = {}
CATEGORY_EFFECTS = {}
for item in *EFFECT_META
  EFFECT_SPECS[item[1]] = item[4]
  EFFECT_CATEGORY[item[1]] = item[2]
  EFFECT_HELP[item[1]] = item[3]
  unless CATEGORY_EFFECTS[item[2]]
    CATEGORY_EFFECTS[item[2]] = {}
    CATEGORIES[#CATEGORIES + 1] = item[2]
  list = CATEGORY_EFFECTS[item[2]]
  list[#list + 1] = item[1]

DIRECTIONS = {"Left to Right", "Right to Left", "Top to Bottom", "Bottom to Top"}
TIMING_MODES = {"Auto frame ranges", "Moments only"}
MOTION_MODES = {"Preserve source motion", "Bake AE position data"}

DEFAULTS = {
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

MAX_MOMENTS = 8
MAX_LAYERS = 16
MAX_OUTPUT_LINES = 2000
LARGE_OUTPUT_WARNING_LINES = 120
MAX_TEXT_CHARS = 80
MAX_SHAPE_NUMBERS = 7000
MAX_POINTS_PER_SHAPE = math.floor MAX_SHAPE_NUMBERS / 2
MIN_SAFE_SPLIT = 2
MORPH_SAFE_SPLIT = 4
MIN_RATIO = -1.5
MAX_RATIO = 2.5
MIN_MORPH_POINTS = 8
MIN_CONTOUR_POINTS = 3
MAX_MORPH_POINTS = 360
MAX_CONFETTI_SITES = 220
GEOMETRY_EPSILON = 0.000001
MORPH_STEP_COUNT = 4
MAX_SEED_ABS = 999999
MAX_TRACKING_FRAME = 999999
HOTKEY_MENU_ROOT = ": Kite Hotkeys :"
HOTKEY_MENU_SCRIPT = script_name
WINDOW_W = 30
PICKER_HELP_H = 5
OPTION_HELP_H = 4

finite_number = (value) ->
  value = tonumber value
  return nil unless value
  return nil if value != value or value == math.huge or value == -math.huge
  value

clamp = (value, min_value, max_value) ->
  value = finite_number(value) or min_value
  math.max min_value, math.min max_value, value

round = (value) ->
  value = finite_number(value) or 0
  math.floor(value + 0.5)

trim = (value) ->
  tostring(value or "")\match("^%s*(.-)%s*$") or ""

fmt_num = (value) ->
  value = finite_number(value) or 0
  s = "%.1f"\format value
  s = s\gsub("%.0$", "")
  s

export utf8_len = (text) ->
  count = 0
  for _ in tostring(text or "")\gmatch "[^\128-\191]"
    count += 1
  count

choice_or_default = (value, choices, default_value) ->
  value = tostring(value or "")
  for choice in *choices
    return choice if value == choice
  default_value

export window_error = (message) ->
  aegisub.dialog.display { {class: "label", label: tostring(message), x: 0, y: 0, width: 64, height: 2} }, {"OK"}
  aegisub.cancel!

export confirm_large_output = (line_count, context = "one run") ->
  count = finite_number(line_count) or 0
  return true if count <= LARGE_OUTPUT_WARNING_LINES
  if count > MAX_OUTPUT_LINES
    message = "#{script_name} will generate #{count} lines for #{context}, above the soft limit of #{MAX_OUTPUT_LINES}. This can be very slow while Aegisub inserts the result. Shape and text safety limits still remain enforced."
    button = aegisub.dialog.display {
      {class: "label", label: message, x: 0, y: 0, width: 72, height: 3}
    }, {"Continue anyway", "Cancel"}, {ok: "Continue anyway", close: "Cancel"}
    return button == "Continue anyway"
  button = aegisub.dialog.display {
    {class: "label", label: "#{script_name} will generate #{count} lines for #{context}. This can be slow while Aegisub inserts the result.", x: 0, y: 0, width: 72, height: 2}
  }, {"Run anyway", "Cancel"}, {ok: "Run anyway", close: "Cancel"}
  button == "Run anyway"

export progress_is_cancelled = ->
  aegisub.progress and aegisub.progress.is_cancelled and aegisub.progress.is_cancelled!

export progress_task = (text) ->
  aegisub.progress.task text if aegisub.progress and aegisub.progress.task

export progress_set = (value) ->
  aegisub.progress.set value if aegisub.progress and aegisub.progress.set

sorted_selection = (sel) ->
  return nil, "Select at least one dialogue line." unless sel and #sel >= 1
  sorted, seen = {}, {}
  for raw_index in *sel
    index = finite_number raw_index
    return nil, "Selection contains an invalid line index." unless index and index >= 1 and index == math.floor(index)
    return nil, "Selection contains duplicate line index #{index}." if seen[index]
    seen[index] = true
    sorted[#sorted + 1] = index
  table.sort sorted
  sorted

safe_collection = (sub, sel) ->
  ok, collection = pcall -> LineCollection sub, sel
  return nil, "LineCollection failed: #{collection}" unless ok and collection
  collection

safe_line = (source, collection, label = "Line") ->
  return nil, "#{label} is missing." unless source
  ok, line = pcall -> Line source, collection
  return nil, "#{label} could not be read: #{line}" unless ok and line
  line

effect_spec = (effect) ->
  EFFECT_SPECS[effect] or EFFECT_SPECS[DEFAULTS.effect] or {kind: "field", mode: "boil"}

spec_default = (effect, name) ->
  spec = EFFECT_SPECS[effect]
  if spec and spec.d and spec.d[name] != nil
    return spec.d[name]
  DEFAULTS[name]

effect_help_text = (effect) ->
  category = EFFECT_CATEGORY[effect] or "Effect"
  spec = effect_spec effect
  timing = if spec.phase == "in" then "Entrance"
  elseif spec.phase == "out" then "Exit"
  elseif spec.kind == "morph" or spec.kind == "pair_morph" then "Timed morph"
  else "Loop (Period ms per cycle)"
  help = EFFECT_HELP[effect] or ""
  "[#{category} - #{timing}] #{help}"

normalize_options = (result = {}) ->
  effect = choice_or_default result.effect or result.operation, EFFECTS, DEFAULTS.effect
  {
    effect: effect
    operation: effect
    category: choice_or_default result.category, CATEGORIES, EFFECT_CATEGORY[effect] or DEFAULTS.category
    target_font: trim(result.target_font or DEFAULTS.target_font)
    moments: round clamp result.moments or DEFAULTS.moments, 1, MAX_MOMENTS
    ratios: trim(result.ratios or DEFAULTS.ratios)
    split_len: clamp result.split_len or DEFAULTS.split_len, MIN_SAFE_SPLIT, 20
    strength: clamp result.strength or spec_default(effect, "strength"), 0, 400
    frequency: clamp result.frequency or spec_default(effect, "frequency"), 0, 100
    noise_scale: clamp result.noise_scale or spec_default(effect, "noise_scale"), 1, 2000
    period: round clamp result.period or spec_default(effect, "period"), 0, 60000
    seed: round clamp result.seed or spec_default(effect, "seed"), -MAX_SEED_ABS, MAX_SEED_ABS
    layers: round clamp result.layers or spec_default(effect, "layers"), 1, MAX_LAYERS
    blur: clamp result.blur or spec_default(effect, "blur"), 0, 20
    alpha: round clamp result.alpha or spec_default(effect, "alpha"), 0, 255
    x_offset: clamp result.x_offset or spec_default(effect, "x_offset"), -100, 100
    y_offset: clamp result.y_offset or spec_default(effect, "y_offset"), -100, 100
    direction: choice_or_default result.direction, DIRECTIONS, DEFAULTS.direction
    timing_mode: choice_or_default result.timing_mode, TIMING_MODES, DEFAULTS.timing_mode
    motion_mode: choice_or_default result.motion_mode, MOTION_MODES, DEFAULTS.motion_mode
    tracking_data: tostring(result.tracking_data or DEFAULTS.tracking_data)
    tracking_ref_frame: round clamp result.tracking_ref_frame or DEFAULTS.tracking_ref_frame, 1, MAX_TRACKING_FRAME
  }

config_section = (effect) ->
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

export picker_gui = (category = DEFAULTS.category, effect = DEFAULTS.effect) ->
  category = choice_or_default category, CATEGORIES, DEFAULTS.category
  pool = CATEGORY_EFFECTS[category] or EFFECTS
  effect = choice_or_default effect, pool, pool[1]
  {
    {class: "label", label: "Category", x: 0, y: 0, width: 4}
    {class: "dropdown", name: "category", items: CATEGORIES, value: category, x: 4, y: 0, width: WINDOW_W - 4}
    {class: "label", label: "Effect", x: 0, y: 1, width: 4}
    {class: "dropdown", name: "operation", items: pool, value: effect, x: 4, y: 1, width: WINDOW_W - 4}
    {class: "textbox", value: effect_help_text(effect), x: 0, y: 2, width: WINDOW_W, height: PICKER_HELP_H}
    {class: "label", label: "Filter re-lists effects for the chosen category.", x: 0, y: 2 + PICKER_HELP_H, width: WINDOW_W}
  }

export add_moment_controls = (gui, y, effect) ->
  gui[#gui + 1] = {class: "label", label: "Moments", x: 0, y: y, width: 3}
  gui[#gui + 1] = {class: "intedit", name: "moments", value: spec_default(effect, "moments"), min: 1, max: MAX_MOMENTS, x: 3, y: y, width: 2}
  gui[#gui + 1] = {class: "label", label: "Ratios", x: 6, y: y, width: 2}
  gui[#gui + 1] = {class: "edit", name: "ratios", value: spec_default(effect, "ratios"), x: 8, y: y, width: 8}

export add_shape_controls = (gui, y, effect) ->
  gui[#gui + 1] = {class: "label", label: "Split len", x: 0, y: y, width: 3}
  gui[#gui + 1] = {class: "floatedit", name: "split_len", value: spec_default(effect, "split_len"), min: MIN_SAFE_SPLIT, max: 20, step: 0.25, x: 3, y: y, width: 3}
  gui[#gui + 1] = {class: "label", label: "Strength", x: 7, y: y, width: 3}
  gui[#gui + 1] = {class: "floatedit", name: "strength", value: spec_default(effect, "strength"), min: 0, max: 400, step: 0.25, x: 10, y: y, width: 3}
  gui[#gui + 1] = {class: "label", label: "Freq", x: 14, y: y, width: 2}
  gui[#gui + 1] = {class: "floatedit", name: "frequency", value: spec_default(effect, "frequency"), min: 0, max: 100, step: 0.25, x: 16, y: y, width: 3}
  gui[#gui + 1] = {class: "label", label: "Scale", x: 20, y: y, width: 2}
  gui[#gui + 1] = {class: "floatedit", name: "noise_scale", value: spec_default(effect, "noise_scale"), min: 1, max: 2000, step: 1, x: 22, y: y, width: 4}

export add_seed_direction_controls = (gui, y, effect, spec) ->
  gui[#gui + 1] = {class: "label", label: "Seed", x: 0, y: y, width: 2}
  gui[#gui + 1] = {class: "intedit", name: "seed", value: spec_default(effect, "seed"), min: -MAX_SEED_ABS, max: MAX_SEED_ABS, x: 2, y: y, width: 4}
  gui[#gui + 1] = {class: "label", label: "Period ms", x: 7, y: y, width: 3}
  gui[#gui + 1] = {class: "intedit", name: "period", value: spec_default(effect, "period"), min: 0, max: 60000, x: 10, y: y, width: 4}
  if spec and spec.dir
    gui[#gui + 1] = {class: "label", label: "Direction", x: 15, y: y, width: 3}
    gui[#gui + 1] = {class: "dropdown", name: "direction", items: DIRECTIONS, value: spec_default(effect, "direction"), x: 18, y: y, width: 7}

export add_layer_controls = (gui, y, effect, label = "Pieces") ->
  gui[#gui + 1] = {class: "label", label: label, x: 0, y: y, width: 3}
  gui[#gui + 1] = {class: "intedit", name: "layers", value: spec_default(effect, "layers"), min: 1, max: MAX_LAYERS, x: 3, y: y, width: 2}
  gui[#gui + 1] = {class: "label", label: "Blur", x: 6, y: y, width: 2}
  gui[#gui + 1] = {class: "floatedit", name: "blur", value: spec_default(effect, "blur"), min: 0, max: 20, step: 0.1, x: 8, y: y, width: 3}
  gui[#gui + 1] = {class: "label", label: "Alpha", x: 12, y: y, width: 2}
  gui[#gui + 1] = {class: "intedit", name: "alpha", value: spec_default(effect, "alpha"), min: 0, max: 255, x: 14, y: y, width: 3}

export add_offset_controls = (gui, y, effect) ->
  gui[#gui + 1] = {class: "label", label: "Center X%", x: 0, y: y, width: 3}
  gui[#gui + 1] = {class: "floatedit", name: "x_offset", value: spec_default(effect, "x_offset"), min: -100, max: 100, step: 0.25, x: 3, y: y, width: 3}
  gui[#gui + 1] = {class: "label", label: "Y%", x: 7, y: y, width: 2}
  gui[#gui + 1] = {class: "floatedit", name: "y_offset", value: spec_default(effect, "y_offset"), min: -100, max: 100, step: 0.25, x: 9, y: y, width: 3}

export add_timing_controls = (gui, y, effect) ->
  gui[#gui + 1] = {class: "label", label: "Timing", x: 0, y: y, width: 3}
  gui[#gui + 1] = {class: "dropdown", name: "timing_mode", items: TIMING_MODES, value: spec_default(effect, "timing_mode"), x: 3, y: y, width: 9}
  gui[#gui + 1] = {class: "label", label: "Moments only overrides frame ranges", x: 13, y: y, width: 14}

export add_motion_controls = (gui, y, effect) ->
  gui[#gui + 1] = {class: "label", label: "Motion", x: 0, y: y, width: 3}
  gui[#gui + 1] = {class: "dropdown", name: "motion_mode", items: MOTION_MODES, value: spec_default(effect, "motion_mode"), x: 3, y: y, width: 9}
  gui[#gui + 1] = {class: "label", label: "Ref", x: 13, y: y, width: 2}
  gui[#gui + 1] = {class: "intedit", name: "tracking_ref_frame", value: spec_default(effect, "tracking_ref_frame"), min: 1, max: MAX_TRACKING_FRAME, x: 15, y: y, width: 3}
  gui[#gui + 1] = {class: "textbox", name: "tracking_data", value: spec_default(effect, "tracking_data"), x: 0, y: y + 1, width: WINDOW_W, height: 4}

export options_gui = (effect) ->
  effect = choice_or_default effect, EFFECTS, DEFAULTS.effect
  spec = effect_spec effect
  gui = {
    {class: "label", label: effect, x: 0, y: 0, width: WINDOW_W}
    {class: "textbox", value: effect_help_text(effect), x: 0, y: 1, width: WINDOW_W, height: OPTION_HELP_H}
  }
  y = OPTION_HELP_H + 2
  if spec.kind == "morph"
    gui[#gui + 1] = {class: "label", label: "Target font", x: 0, y: y, width: 4}
    gui[#gui + 1] = {class: "edit", name: "target_font", value: spec_default(effect, "target_font"), x: 4, y: y, width: 12}
    y += 1
  if spec.kind == "confetti"
    add_layer_controls gui, y, effect, "Pieces"
    y += 1
  elseif spec.kind == "layer_deform"
    add_layer_controls gui, y, effect, "Passes"
    y += 1
  add_moment_controls gui, y, effect
  y += 1
  add_shape_controls gui, y, effect
  y += 1
  unless spec.kind == "morph" or spec.kind == "pair_morph"
    add_seed_direction_controls gui, y, effect, spec
    y += 1
  if spec.off or spec.kind == "confetti"
    add_offset_controls gui, y, effect
    y += 1
  add_timing_controls gui, y, effect
  y += 1
  add_motion_controls gui, y, effect
  gui

export config_interface = (section = nil, gui = nil) ->
  interface = {main: config_entries_for_gui picker_gui(DEFAULTS.category, DEFAULTS.effect)}
  if section and gui
    interface[section] = config_entries_for_gui gui
  else
    for effect in *EFFECTS
      interface[config_section effect] = config_entries_for_gui options_gui(effect)
  interface

export read_configured_gui = (section, gui) ->
  return nil unless ConfigHandler
  ok, options = pcall -> ConfigHandler config_interface(section, gui), CONFIG_FILE, true, script_version
  return nil unless ok and options
  pcall -> options\read!
  pcall -> options\updateInterface section
  options

export save_configured_gui = (options, result, section) ->
  return true unless options and result
  ok, err = pcall ->
    options\updateConfiguration result, section
    options\write!
  unless ok
    aegisub.log "#{script_name}: could not save #{section} configuration: #{err}\n" if aegisub and aegisub.log
  ok

export effect_picker = ->
  category = DEFAULTS.category
  current = DEFAULTS.effect
  while true
    gui = picker_gui category, current
    options = read_configured_gui "main", gui
    category = choice_or_default control_value(gui, "category", category), CATEGORIES, category
    pool = CATEGORY_EFFECTS[category] or EFFECTS
    current = choice_or_default control_value(gui, "operation", current), pool, pool[1]
    gui[2].value = category
    gui[4].items = pool
    gui[4].value = current
    gui[5].value = effect_help_text current
    button, result = aegisub.dialog.display gui, {"Run", "Filter", "Cancel"}, {ok: "Run", close: "Cancel"}
    chosen_category = choice_or_default result and result.category or category, CATEGORIES, category
    pool = CATEGORY_EFFECTS[chosen_category] or EFFECTS
    chosen = choice_or_default result and result.operation or current, pool, pool[1]
    if button == "Filter"
      save_configured_gui options, {category: chosen_category, operation: chosen}, "main"
      category = chosen_category
      current = chosen
    elseif button == "Run"
      save_configured_gui options, {category: chosen_category, operation: chosen}, "main"
      return chosen
    else
      aegisub.cancel!

export show_effect_options = (effect) ->
  section = config_section effect
  while true
    gui = options_gui effect
    options = read_configured_gui section, gui
    button, result = aegisub.dialog.display gui, {"Apply", "Back", "Cancel"}, {ok: "Apply", close: "Cancel"}
    if button == "Apply"
      result or= {}
      result.effect = effect
      save_configured_gui options, result, section
      return normalize_options result
    elseif button == "Back"
      return "__back"
    else
      aegisub.cancel!

export read_options = ->
  while true
    effect = effect_picker!
    opts = show_effect_options effect
    return opts if opts != "__back"

export auto_ratios = (count) ->
  count = round clamp count, 1, MAX_MOMENTS
  return {1} if count <= 1
  ratios = {}
  for i = 1, count
    ratios[#ratios + 1] = (i - 1) / (count - 1)
  ratios

export same_ratio = (a, b) ->
  math.abs((finite_number(a) or 0) - (finite_number(b) or 0)) < GEOMETRY_EPSILON

export legacy_default_ratios = (ratios) ->
  #ratios == 3 and same_ratio(ratios[1], 0) and same_ratio(ratios[2], 0.5) and same_ratio(ratios[3], 1)

export parse_ratio_tokens = (text) ->
  ratios, invalid = {}, {}
  for token in tostring(text or "")\gmatch "[^,%s]+"
    value = finite_number token
    if not value
      invalid[#invalid + 1] = token
    elseif value < MIN_RATIO or value > MAX_RATIO
      invalid[#invalid + 1] = token
    else
      ratios[#ratios + 1] = value
  if #invalid > 0
    return nil, "Ratios contains invalid value(s): #{table.concat invalid, ", "}. Use numbers between #{MIN_RATIO} and #{MAX_RATIO}, or leave Ratios blank for automatic spacing."
  ratios

export parse_ratios = (text, count) ->
  count = round clamp count, 1, MAX_MOMENTS
  raw = trim text
  ratios, err = parse_ratio_tokens raw
  return nil, err unless ratios
  if raw == "" or legacy_default_ratios(ratios) and count != 3
    return auto_ratios count
  return ratios if #ratios == count
  return nil, "Ratios has #{#ratios} value(s), but Moments is #{count}. Leave Ratios blank for automatic spacing or provide exactly #{count} ratio values."

export elastic_ratios = (count) ->
  return {0} if count <= 1
  return {0, 1.12, 1} if count == 3
  ratios = {}
  for i = 1, count
    t = (i - 1) / (count - 1)
    if t < 0.7
      ratios[i] = (t / 0.7) * 0.75
    elseif t < 0.85
      ratios[i] = 0.75 + ((t - 0.7) / 0.15) * 0.37
    else
      ratios[i] = 1.12 + ((t - 0.85) / 0.15) * -0.12
  ratios

moment_ratios = (opts) ->
  spec = EFFECT_SPECS[opts.effect]
  if spec and spec.elastic
    elastic_ratios opts.moments
  else
    parse_ratios opts.ratios, opts.moments

collect_numbers = (shape) ->
  nums = {}
  for token in tostring(shape or "")\gmatch "%S+"
    value = finite_number token
    nums[#nums + 1] = value if value
  nums

count_numbers = (shape) ->
  #collect_numbers shape

clean_shape = (shape) ->
  shape = tostring(shape or "")
  shape = shape\gsub "^%s+", ""
  shape = shape\gsub "%s+$", ""
  tokens = {}
  for token in shape\gmatch "%S+"
    lower = token\lower!
    tokens[#tokens + 1] = if lower\match("^[mnlbspc]$") then lower else token
  table.concat tokens, " "

DRAW_COMMANDS = {
  m: true
  n: true
  l: true
  b: true
  s: true
  p: true
  c: true
}

shape_signature = (shape) ->
  signature = {}
  for token in tostring(shape or "")\gmatch "%S+"
    value = finite_number token
    unless value
      lower = token\lower!
      if DRAW_COMMANDS[lower]
        signature[#signature + 1] = lower
      else
        return nil, "invalid drawing token '#{token}'"
  table.concat signature, " "

validate_shape_structure = (shape, allow_empty = false) ->
  return true if allow_empty and clean_shape(shape) == ""
  current, count, saw_move, spline_open = nil, 0, false, false
  validate_group = ->
    return true unless current
    if current == "c"
      return nil, "command c cannot have coordinates" unless count == 0
      return nil, "command c needs a preceding spline" unless spline_open
      spline_open = false
    elseif current == "s"
      return nil, "command s needs at least three complete points" unless count >= 6 and count % 2 == 0
      spline_open = true
    elseif current == "p"
      return nil, "command p needs a preceding spline" unless spline_open
      return nil, "command p needs exactly one coordinate pair" unless count == 2
    elseif current == "b"
      return nil, "command b needs complete groups of three coordinate pairs" unless count >= 6 and count % 6 == 0
      spline_open = false
    elseif current == "l"
      return nil, "command l needs one or more complete coordinate pairs" unless count >= 2 and count % 2 == 0
      spline_open = false
    else
      return nil, "command #{current} needs exactly one coordinate pair" unless count == 2
      spline_open = false
    true
  for token in tostring(shape or "")\gmatch "%S+"
    if finite_number(token) != nil
      return nil, "numeric coordinate appears before a drawing command" unless current
      count += 1
    else
      ok, err = validate_group!
      return nil, err unless ok
      current = token\lower!
      return nil, "drawing must start with m or n" unless saw_move or current == "m" or current == "n"
      saw_move = true if current == "m" or current == "n"
      count = 0
  ok, err = validate_group!
  return nil, err unless ok
  return nil, "drawing has no move command" unless saw_move
  true

export shape_limit_error = (label, number_count) ->
  "#{label} is too complex (#{number_count} numeric coordinates; max #{MAX_SHAPE_NUMBERS}). Increase Split len, reduce text length, or apply #{script_name} to fewer/smaller shapes."

guard_shape = (shape, label = "Shape", allow_empty = false) ->
  shape = clean_shape shape
  signature, sig_err = shape_signature shape
  return nil, "#{label} has #{sig_err}." unless signature
  structured, structure_err = validate_shape_structure shape, allow_empty
  return nil, "#{label} has invalid drawing structure: #{structure_err}." unless structured
  number_count = count_numbers shape
  return nil, "#{label} has no numeric coordinates." if number_count == 0 and not allow_empty
  return nil, "#{label} has an odd number of numeric coordinates." if number_count % 2 != 0
  return nil, shape_limit_error(label, number_count) if number_count > MAX_SHAPE_NUMBERS
  shape, nil

shape_bbox = (shape) ->
  nums = collect_numbers shape
  return nil if #nums < 2
  min_x, max_x = nums[1], nums[1]
  min_y, max_y = nums[2], nums[2]
  for i = 1, #nums - 1, 2
    x, y = nums[i], nums[i + 1]
    if x and y
      min_x = math.min min_x, x
      max_x = math.max max_x, x
      min_y = math.min min_y, y
      max_y = math.max max_y, y
  {min_x: min_x, max_x: max_x, min_y: min_y, max_y: max_y, width: max_x - min_x, height: max_y - min_y}

parse_contours = (shape) ->
  contours, current, pending = {}, nil, nil
  for token in tostring(shape or "")\gmatch "%S+"
    value = finite_number token
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

contour_metrics = (points) ->
  n = #points
  segs, total = {}, 0
  for i = 1, n
    a = points[i]
    b = points[i == n and 1 or i + 1]
    dx, dy = b.x - a.x, b.y - a.y
    d = math.sqrt dx * dx + dy * dy
    segs[i] = d
    total += d
  segs, total

contour_centroid = (points) ->
  n = #points
  return {x: 0, y: 0} if n == 0
  sx, sy = 0, 0
  for p in *points
    sx += p.x
    sy += p.y
  {x: sx / n, y: sy / n}

signed_area = (points) ->
  area, n = 0, #points
  for i = 1, n
    a = points[i]
    b = points[i == n and 1 or i + 1]
    area += a.x * b.y - b.x * a.y
  area / 2

reverse_contour = (points) ->
  out = {}
  for i = #points, 1, -1
    out[#out + 1] = points[i]
  out

contour_bbox = (points) ->
  return nil if #points == 0
  min_x, max_x = points[1].x, points[1].x
  min_y, max_y = points[1].y, points[1].y
  for p in *points
    min_x = math.min min_x, p.x
    max_x = math.max max_x, p.x
    min_y = math.min min_y, p.y
    max_y = math.max max_y, p.y
  {min_x: min_x, max_x: max_x, min_y: min_y, max_y: max_y, width: max_x - min_x, height: max_y - min_y}

resample_contour = (points, count) ->
  n = #points
  count = math.max 3, round count
  return nil if n == 0
  out = {}
  if n == 1
    for i = 1, count
      out[i] = {x: points[1].x, y: points[1].y}
    return out
  segs, total = contour_metrics points
  if total <= 0
    for i = 1, count
      out[i] = {x: points[1].x, y: points[1].y}
    return out
  cum = {0}
  for i = 1, n
    cum[i + 1] = cum[i] + segs[i]
  step = total / count
  si = 1
  for k = 0, count - 1
    d = k * step
    while si < n and cum[si + 1] < d
      si += 1
    a = points[si]
    b = points[si == n and 1 or si + 1]
    seg_d = segs[si]
    t = if seg_d > 0 then (d - cum[si]) / seg_d else 0
    out[k + 1] = {x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t}
  out

align_contour = (reference, candidate) ->
  n = #reference
  return candidate if n != #candidate or n == 0
  ref_area, cand_area = signed_area(reference), signed_area(candidate)
  candidate = reverse_contour candidate if ref_area * cand_area < 0
  best_offset, best_cost = 0, math.huge
  for offset = 0, n - 1
    cost = 0
    for i = 1, n
      j = ((i - 1 + offset) % n) + 1
      dx = reference[i].x - candidate[j].x
      dy = reference[i].y - candidate[j].y
      cost += dx * dx + dy * dy
      break if cost >= best_cost
    if cost < best_cost
      best_cost, best_offset = cost, offset
  aligned = {}
  for i = 1, n
    j = ((i - 1 + best_offset) % n) + 1
    aligned[i] = candidate[j]
  aligned

contours_to_shape = (contours) ->
  parts = {}
  for contour in *contours
    continue if #contour == 0
    first = contour[1]
    parts[#parts + 1] = "m #{fmt_num first.x} #{fmt_num first.y} l"
    for i = 2, #contour
      p = contour[i]
      parts[#parts + 1] = "#{fmt_num p.x} #{fmt_num p.y}"
    if #contour == 1
      parts[#parts + 1] = "#{fmt_num first.x} #{fmt_num first.y}"
  table.concat parts, " "

sample_contour_any = (points, count) ->
  count = math.max 1, round count
  return nil if not points or #points == 0
  if count == 1
    return {contour_centroid points}
  if count == 2
    return {points[1], points[math.max(1, math.floor(#points / 2))]}
  resample_contour points, count

simplify_shape_to_limit = (shape, label = "Shape", max_numbers = MAX_SHAPE_NUMBERS) ->
  shape = clean_shape shape
  signature, sig_err = shape_signature shape
  return nil, nil, "#{label} has #{sig_err}." unless signature
  structured, structure_err = validate_shape_structure shape
  return nil, nil, "#{label} has invalid drawing structure: #{structure_err}." unless structured
  return nil, nil, "#{label} has an odd number of numeric coordinates." if count_numbers(shape) % 2 != 0
  contours = parse_contours shape
  return nil, nil, "#{label} has no drawable contours to simplify." if #contours == 0
  max_points = math.max 2, math.floor(max_numbers / 2)
  return nil, nil, "#{label} has an insufficient point budget." if max_points < MIN_CONTOUR_POINTS
  contours = [contour for contour in *contours when #contour >= MIN_CONTOUR_POINTS]
  return nil, nil, "#{label} has no non-degenerate contours to simplify." if #contours == 0
  max_contours = math.max 1, math.floor(max_points / MIN_CONTOUR_POINTS)
  if #contours > max_contours
    ranked = {}
    for i, contour in ipairs contours
      _, len = contour_metrics contour
      ranked[#ranked + 1] = {index: i, len: len}
    table.sort ranked, (a, b) -> a.len > b.len
    keep = {}
    for i = 1, max_contours
      keep[ranked[i].index] = true if ranked[i]
    filtered = {}
    for i, contour in ipairs contours
      filtered[#filtered + 1] = contour if keep[i]
    contours = filtered
  total_len = 0
  lengths = {}
  for i, contour in ipairs contours
    _, len = contour_metrics contour
    lengths[i] = len
    total_len += math.max 0.001, len
  min_points = MIN_CONTOUR_POINTS
  counts, used = {}, 0
  for i, contour in ipairs contours
    base = math.min #contour, min_points
    counts[i] = base
    used += base
  remaining = math.max 0, max_points - used
  for i, contour in ipairs contours
    break if remaining <= 0
    share = math.floor remaining * (math.max(0.001, lengths[i]) / total_len)
    add = math.min math.max(0, #contour - counts[i]), share
    counts[i] += add
    remaining -= add
  while remaining > 0
    progressed = false
    for i, contour in ipairs contours
      break if remaining <= 0
      if counts[i] < #contour
        counts[i] += 1
        remaining -= 1
        progressed = true
    break unless progressed
  out = {}
  for i, contour in ipairs contours
    if counts[i] >= #contour
      out[#out + 1] = contour
    else
      sampled = sample_contour_any contour, counts[i]
      return nil, nil, "#{label} simplification failed for contour #{i}." unless sampled
      out[#out + 1] = sampled
  simplified = contours_to_shape out
  simplified, err = guard_shape simplified, "#{label} simplified"
  return nil, nil, err unless simplified
  simplified, count_numbers(simplified)

confirm_shape_simplification = (opts, label, original_count, reduced_count) ->
  opts or= {}
  opts._shape_simplification_confirmed or= {}
  cache_key = "#{label}:#{original_count}:#{reduced_count}"
  return true if opts._shape_simplification_confirmed[cache_key]
  return true unless aegisub and aegisub.dialog and aegisub.dialog.display
  button = aegisub.dialog.display {
    {class: "label", label: "#{label} has #{original_count} numeric coordinates, above the safe limit of #{MAX_SHAPE_NUMBERS}. #{script_name} can simplify it to #{reduced_count} coordinates and continue. Fine detail may be lost, but this avoids a crash or very slow run.", x: 0, y: 0, width: 72, height: 4}
  }, {"Continue simplified", "Cancel"}, {ok: "Continue simplified", close: "Cancel"}
  if button == "Continue simplified"
    opts._shape_simplification_confirmed[cache_key] = true
    return true
  false

shape_for_geo = (shape, opts, label = "Shape") ->
  shape = clean_shape shape
  signature, sig_err = shape_signature shape
  return nil, "#{label} has #{sig_err}." unless signature
  structured, structure_err = validate_shape_structure shape
  return nil, "#{label} has invalid drawing structure: #{structure_err}." unless structured
  number_count = count_numbers shape
  return nil, "#{label} has no numeric coordinates." if number_count == 0
  return nil, "#{label} has an odd number of numeric coordinates." if number_count % 2 != 0
  return shape if number_count <= MAX_SHAPE_NUMBERS
  simplified, reduced_count, err = simplify_shape_to_limit shape, label
  return nil, err unless simplified
  return nil, "#{label} simplification cancelled." unless confirm_shape_simplification opts, label, number_count, reduced_count
  simplified

flatten_shape = (shape, label = "Shape") ->
  shape, err = guard_shape shape, label
  return nil, err unless shape
  return shape unless Yutils and Yutils.shape and Yutils.shape.flatten
  ok, result = pcall Yutils.shape.flatten, shape
  return nil, "Yutils.shape.flatten failed for #{label}: #{result}" unless ok
  result = clean_shape result
  signature, sig_err = shape_signature result
  return nil, "#{label} after flatten has #{sig_err}." unless signature
  result

allocate_contour_counts = (desired, max_points, label = "Shape") ->
  contour_count = #desired
  return {}, nil if contour_count == 0
  return nil, "#{label} has too many contours to keep #{MIN_CONTOUR_POINTS} points per contour within the shape limit." if contour_count * MIN_CONTOUR_POINTS > max_points

  base = if contour_count * MIN_MORPH_POINTS <= max_points then MIN_MORPH_POINTS else MIN_CONTOUR_POINTS
  counts, desired_extra, used = {}, 0, 0
  for i, wanted in ipairs desired
    wanted = math.max base, round wanted
    desired[i] = wanted
    counts[i] = base
    used += base
    desired_extra += wanted - base

  remaining = math.max 0, max_points - used
  initial_remaining = remaining
  if desired_extra > 0
    for i, wanted in ipairs desired
      share = math.floor initial_remaining * ((wanted - base) / desired_extra)
      add = math.min(wanted - counts[i], share)
      counts[i] += add
      remaining -= add

  while remaining > 0
    progressed = false
    for i, wanted in ipairs desired
      break if remaining <= 0
      if counts[i] < wanted
        counts[i] += 1
        remaining -= 1
        progressed = true
    break unless progressed
  counts, nil

normalize_pair = (shape_a, shape_b, opts) ->
  flat_a, err = flatten_shape shape_a, "Source shape"
  return nil, nil, err unless flat_a
  flat_b, err = flatten_shape shape_b, "Target shape"
  return nil, nil, err unless flat_b
  contours_a = parse_contours flat_a
  contours_b = parse_contours flat_b
  return nil, nil, "source shape has no drawable contours" if #contours_a == 0
  return nil, nil, "target shape has no drawable contours" if #contours_b == 0
  pair_count = math.max #contours_a, #contours_b
  for i = #contours_a + 1, pair_count
    contours_a[i] = {contour_centroid contours_b[i]}
  for i = #contours_b + 1, pair_count
    contours_b[i] = {contour_centroid contours_a[i]}
  seg_len = math.max MORPH_SAFE_SPLIT, finite_number(opts.split_len) or MORPH_SAFE_SPLIT
  desired = {}
  for i = 1, pair_count
    _, len_a = contour_metrics contours_a[i]
    _, len_b = contour_metrics contours_b[i]
    count = round clamp math.max(len_a, len_b) / seg_len, MIN_MORPH_POINTS, MAX_MORPH_POINTS
    desired[i] = count
  counts, allocation_err = allocate_contour_counts desired, MAX_POINTS_PER_SHAPE, "Shape pair"
  return nil, nil, allocation_err unless counts
  out_a, out_b = {}, {}
  for i = 1, pair_count
    sampled_a = resample_contour contours_a[i], counts[i]
    sampled_b = resample_contour contours_b[i], counts[i]
    return nil, nil, "shape morph resampling failed for contour #{i}" unless sampled_a and sampled_b
    out_a[i] = sampled_a
    out_b[i] = align_contour sampled_a, sampled_b
  result_a, err = guard_shape contours_to_shape(out_a), "Source shape after resample"
  return nil, nil, err unless result_a
  result_b, err = guard_shape contours_to_shape(out_b), "Target shape after resample"
  return nil, nil, err unless result_b
  result_a, result_b

lerp_shape = (shape_a, shape_b, ratio, nums_b = nil) ->
  ratio = clamp ratio, MIN_RATIO, MAX_RATIO
  nums_b = nums_b or collect_numbers shape_b
  result, ni = {}, 1
  for token in tostring(shape_a or "")\gmatch "%S+"
    value = finite_number token
    if value
      other = nums_b[ni]
      return nil, "missing target coordinate #{ni}" unless other
      result[#result + 1] = fmt_num value + (other - value) * ratio
      ni += 1
    else
      result[#result + 1] = token
  return nil, "source shape has fewer coordinates than target shape" if ni <= #nums_b
  guard_shape table.concat(result, " "), "Lerped shape"

noise_hash = (ix, iy, seed) ->
  raw = math.sin(ix * 127.1 + iy * 311.7 + seed * 74.7) * 43758.5453123
  raw - math.floor raw

smooth_noise = (x, y, seed) ->
  ix, iy = math.floor(x), math.floor(y)
  fx, fy = x - ix, y - iy
  sx = fx * fx * (3 - 2 * fx)
  sy = fy * fy * (3 - 2 * fy)
  n00, n10 = noise_hash(ix, iy, seed), noise_hash(ix + 1, iy, seed)
  n01, n11 = noise_hash(ix, iy + 1, seed), noise_hash(ix + 1, iy + 1, seed)
  nx0 = n00 + (n10 - n00) * sx
  nx1 = n01 + (n11 - n01) * sx
  nx0 + (nx1 - nx0) * sy

octave_noise = (x, y, seed, octaves = 3) ->
  total, amp, freq, norm = 0, 1, 1, 0
  for _ = 1, octaves
    total += (smooth_noise(x * freq, y * freq, seed) - 0.5) * amp
    norm += amp
    amp *= 0.5
    freq *= 2.1
  total / norm

norm_span = (value, min_value, max_value) ->
  span = max_value - min_value
  return 0 if math.abs(span) < GEOMETRY_EPSILON
  clamp (value - min_value) / span, 0, 1

shape_center = (bbox) ->
  {x: (bbox.min_x + bbox.max_x) / 2, y: (bbox.min_y + bbox.max_y) / 2}

unit_from_center = (x, y, center) ->
  dx, dy = x - center.x, y - center.y
  len = math.sqrt(dx * dx + dy * dy)
  return 0, -1, 0 if len <= GEOMETRY_EPSILON
  dx / len, dy / len, len

curve_ratio = (ratio, mode) ->
  ratio = clamp ratio, 0, 1
  switch mode
    when "linear" then ratio
    when "overshoot" then ratio + math.sin(ratio * math.pi) * 0.22
    when "anticipation" then ratio * ratio * 1.18 - math.sin((1 - ratio) * math.pi) * 0.12
    when "bounce" then ratio + math.sin(ratio * math.pi * 3) * (1 - ratio) * 0.16
    when "steps" then math.floor(ratio * MORPH_STEP_COUNT + GEOMETRY_EPSILON) / MORPH_STEP_COUNT
    when "rubber" then ratio + math.sin(ratio * math.pi * 2) * 0.10
    when "glitch" then ratio
    else ratio * ratio * (3 - 2 * ratio)

tri_wave = (t) ->
  t = t - math.floor t
  if t < 0.5 then t * 4 - 1 else 3 - t * 4

stagger_amount = (arrival, rank, spread = 0.6) ->
  clamp (arrival * (1 + spread) - rank * spread), 0, 1

prep_geo = (shape, opts, label = "Shape") ->
  flat, err = shape_for_geo shape, opts, label
  return nil, err unless flat
  if Yutils and Yutils.shape and Yutils.shape.flatten
    ok, result = pcall Yutils.shape.flatten, flat
    return nil, "Yutils.shape.flatten failed for #{label}: #{result}" unless ok
    flat, err = shape_for_geo result, opts, "#{label} after flatten"
    return nil, err unless flat
  base = flat
  if Yutils and Yutils.shape and Yutils.shape.split
    segment_len = math.max MIN_SAFE_SPLIT, finite_number(opts.split_len) or DEFAULTS.split_len
    ok, result = pcall Yutils.shape.split, flat, segment_len
    return nil, "Yutils.shape.split failed for #{label}: #{result}" unless ok
    base, err = shape_for_geo result, opts, "#{label} after split"
    return nil, err unless base
  raw = parse_contours base
  return nil, "#{label} has no drawable contours." if #raw == 0
  bbox = shape_bbox base
  return nil, "#{label} has no coordinate bounds." unless bbox
  contours, total_len = {}, 0
  for pts in *raw
    n = #pts
    if n > 2 and math.abs(pts[n].x - pts[1].x) < 0.001 and math.abs(pts[n].y - pts[1].y) < 0.001
      pts[n] = nil
      n -= 1
    continue if n == 0
    segs, len = contour_metrics pts
    cum = {0}
    for i = 1, n
      cum[i + 1] = cum[i] + segs[i]
    area = signed_area pts
    sign = area >= 0 and 1 or -1
    normals = {}
    for i = 1, n
      prev = pts[i == 1 and n or i - 1]
      nxt = pts[i == n and 1 or i + 1]
      tx, ty = nxt.x - prev.x, nxt.y - prev.y
      tl = math.sqrt tx * tx + ty * ty
      if tl < GEOMETRY_EPSILON
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
      centroid: contour_centroid pts
      cbox: contour_bbox pts
      normals: normals
      offset: total_len
    }
    total_len += len
  return nil, "#{label} has no usable contours." if #contours == 0
  {
    contours: contours
    cn: #contours
    bbox: bbox
    center: shape_center bbox
    width: math.max 1, bbox.width
    height: math.max 1, bbox.height
    total_len: math.max 1, total_len
  }

dir_axis = (direction, px, py) ->
  switch direction
    when "Right to Left" then 1 - px
    when "Top to Bottom" then py
    when "Bottom to Top" then 1 - py
    else px

dir_vector = (direction) ->
  switch direction
    when "Right to Left" then -1, 0
    when "Top to Bottom" then 0, 1
    when "Bottom to Top" then 0, -1
    else 1, 0

build_ctx = (geo, opts, slice, spec) ->
  prog = clamp slice.progress, 0, 1
  eased = curve_ratio prog, spec.curve
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
  t_ms = finite_number(slice.time_ms) or 0
  phi = if period and period > 0
    (t_ms / period) * math.pi * 2
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
    t: t_ms
    beat: beat
    frame_key: math.floor(period and period > 0 and (t_ms / math.max(1, period)) * 8 or slice.index)
    strength: opts.strength
    freq: math.max 0.01, opts.frequency
    scale: math.max 1, opts.noise_scale
    seed: opts.seed
    fx_center: {x: cx, y: cy}
    maxd: math.max(geo.width, geo.height) * 0.5
  }

timing_for_moment = (source, index, total) ->
  start_time = finite_number(source.start_time) or 0
  end_time = finite_number(source.end_time) or start_time + 1
  end_time = start_time + 1 if end_time <= start_time
  duration = math.max 1, end_time - start_time
  s = round start_time + duration * (index - 1) / total
  e = if index == total then end_time else round start_time + duration * index / total
  s, math.max(s + 1, e)

frame_timing_enabled = (opts) ->
  not opts or opts.timing_mode != "Moments only"

frame_api_available = ->
  aegisub and aegisub.frame_from_ms and aegisub.ms_from_frame

line_frame_bounds = (source) ->
  return nil unless frame_api_available!
  start_time = finite_number(source.start_time) or 0
  end_time = finite_number(source.end_time) or start_time + 1
  end_time = start_time + 1 if end_time <= start_time
  ok_start, start_frame = pcall aegisub.frame_from_ms, start_time
  ok_end, last_frame = pcall aegisub.frame_from_ms, math.max(start_time, end_time - 1)
  start_frame = ok_start and finite_number(start_frame) or nil
  last_frame = ok_end and finite_number(last_frame) or nil
  return nil unless start_frame and last_frame
  start_frame = round start_frame
  end_frame = round(last_frame) + 1
  end_frame = start_frame + 1 if end_frame <= start_frame
  start_frame, end_frame

line_frame_count = (source) ->
  start_frame, end_frame = line_frame_bounds source
  return 1 unless start_frame and end_frame
  math.max 1, end_frame - start_frame

line_duration_ms = (source) ->
  start_time = finite_number(source.start_time) or 0
  end_time = finite_number(source.end_time) or start_time + 1
  math.max 1, end_time - start_time

time_range_for_frame = (source, frame) ->
  return nil unless frame_api_available!
  source_start = finite_number(source.start_time) or 0
  source_end = finite_number(source.end_time) or source_start + 1
  source_end = source_start + 1 if source_end <= source_start
  ok_start, start_time = pcall aegisub.ms_from_frame, frame
  ok_end, end_time = pcall aegisub.ms_from_frame, frame + 1
  return nil unless ok_start and ok_end and start_time != nil and end_time != nil
  start_time = math.max source_start, round start_time
  end_time = math.min source_end, round end_time
  end_time = start_time + 1 if end_time <= start_time
  start_time, end_time

progress_for_moment = (index, total) ->
  total = round(finite_number(total) or 1)
  index = round(finite_number(index) or 1)
  return 1 if total <= 1
  clamp (index - 1) / (total - 1), 0, 1

moment_slices = (source, opts) ->
  ratios, err = moment_ratios opts
  return nil, err unless ratios
  source_start = finite_number(source.start_time) or 0
  slices = {}
  for i, ratio in ipairs ratios
    start_time, end_time = timing_for_moment source, i, #ratios
    slices[#slices + 1] = {
      index: i
      total: #ratios
      local_index: i
      local_total: #ratios
      ratio: ratio
      progress: progress_for_moment i, #ratios
      start_time: start_time
      end_time: end_time
      time_ms: start_time - source_start
      frame: nil
      mode: "moment"
    }
  slices

temporal_slices = (source, opts) ->
  return moment_slices source, opts unless frame_timing_enabled opts
  start_frame, end_frame = line_frame_bounds source
  return moment_slices source, opts unless start_frame and end_frame
  local_total = math.max 1, end_frame - start_frame
  context = opts and opts._frame_context or nil
  total = context and context.total_frames or local_total
  offset = context and context.frame_offset or 0
  time_offset = context and context.time_offset or 0
  source_start = finite_number(source.start_time) or 0
  slices = {}
  for i = 1, local_total
    frame = start_frame + i - 1
    start_time, end_time = time_range_for_frame source, frame
    return moment_slices source, opts unless start_time and end_time
    global_index = offset + i
    progress = if total <= 1 then 1 else clamp((global_index - 1) / (total - 1), 0, 1)
    slices[#slices + 1] = {
      index: global_index
      total: total
      local_index: i
      local_total: local_total
      ratio: progress
      progress: progress
      start_time: start_time
      end_time: end_time
      time_ms: time_offset + (start_time - source_start)
      frame: frame
      mode: "frame"
    }
  slices

FIELD_FX = {}

apply_field = (geo, ctx, mode, label = "Field shape") ->
  fx = FIELD_FX[mode]
  return nil, "Unknown field mode '#{mode}'." unless fx
  ctx.ca = math.cos(ctx.phi) * 1.3
  ctx.sa = math.sin(ctx.phi) * 1.3
  bbox = geo.bbox
  out = {}
  q = {}
  for ci, co in ipairs geo.contours
    pts, n = co.pts, co.n
    rank = ctx.ranks and ctx.ranks[ci] or 0
    new_pts = {}
    for i = 1, n
      p = pts[i]
      nor = co.normals[i]
      q.px = norm_span p.x, bbox.min_x, bbox.max_x
      q.py = norm_span p.y, bbox.min_y, bbox.max_y
      q.s = co.cum[i] / math.max(0.001, co.len)
      q.sg = (co.offset + co.cum[i]) / geo.total_len
      q.nx, q.ny = nor.x, nor.y
      q.tx, q.ty = nor.tx, nor.ty
      q.ci, q.i, q.n = ci, i, n
      q.co = co
      q.rank = rank
      q.ux, q.uy, q.dist = unit_from_center p.x, p.y, geo.center
      x, y = fx ctx, p.x, p.y, q
      new_pts[i] = {x: x, y: y}
    out[#out + 1] = new_pts
  guard_shape contours_to_shape(out), label

field_noise = (ctx, x, y, ox = 0, oy = 0) ->
  smooth_noise(x / ctx.scale + ctx.ca + ox, y / ctx.scale + ctx.sa + oy, ctx.seed) - 0.5

FIELD_FX.boil = (ctx, x, y, q) ->
  dx = field_noise(ctx, x, y) * ctx.strength * 2
  dy = field_noise(ctx, x, y, 37, 17) * ctx.strength * 2
  x + dx * ctx.m, y + dy * ctx.m

FIELD_FX.electric = (ctx, x, y, q) ->
  dx = (noise_hash(q.i * 7 + q.ci * 131, ctx.frame_key, ctx.seed) - 0.5) * 2
  dy = (noise_hash(q.i * 13 + q.ci * 57, ctx.frame_key + 41, ctx.seed) - 0.5) * 2
  x + dx * ctx.strength * ctx.m, y + dy * ctx.strength * ctx.m

FIELD_FX.handwriting = (ctx, x, y, q) ->
  dx = field_noise(ctx, x, y) * ctx.strength * 2
  dy = field_noise(ctx, x, y, 91, 43) * ctx.strength * 2
  wob = math.sin(q.s * math.pi * 4 + ctx.phi) * ctx.strength * 0.3
  x + (dx + q.nx * wob) * ctx.m, y + (dy + q.ny * wob) * ctx.m

FIELD_FX.wobble = (ctx, x, y, q) ->
  dx = math.sin(y * 0.02 * ctx.freq + ctx.phi) * ctx.strength
  dy = math.sin(x * 0.02 * ctx.freq + ctx.phi * 1.3) * ctx.strength
  x + dx * ctx.m, y + dy * ctx.m

FIELD_FX.fine_jitter = (ctx, x, y, q) ->
  dx = (noise_hash(q.i + q.ci * 89, ctx.frame_key, ctx.seed) - 0.5) * 1.4
  dy = (noise_hash(q.i + q.ci * 89, ctx.frame_key + 7, ctx.seed + 3) - 0.5) * 1.4
  sm = field_noise(ctx, x, y) * 0.8
  x + (dx + sm) * ctx.strength * ctx.m, y + (dy - sm) * ctx.strength * ctx.m

FIELD_FX.coarse_jitter = (ctx, x, y, q) ->
  cell = math.max 6, ctx.scale / 8
  jx = smooth_noise(math.floor(x / cell), math.floor(y / cell) + ctx.frame_key * 0.618, ctx.seed) - 0.5
  jy = smooth_noise(math.floor(x / cell) + 40, math.floor(y / cell) - 13 + ctx.frame_key * 0.618, ctx.seed + 7) - 0.5
  x + jx * ctx.strength * 2 * ctx.m, y + jy * ctx.strength * 2 * ctx.m

FIELD_FX.drift = (ctx, x, y, q) ->
  t = ctx.phi / (math.pi * 2)
  dx = (smooth_noise(x / ctx.scale + t * 0.7, y / ctx.scale, ctx.seed) - 0.5) * ctx.strength * 2
  dy = (smooth_noise(x / ctx.scale + t * 0.7 + 60, y / ctx.scale + 25, ctx.seed + 5) - 0.5) * ctx.strength * 2
  x + dx * ctx.m, y + dy * ctx.m

FIELD_FX.heat = (ctx, x, y, q) ->
  t = ctx.phi / math.pi
  dx = (smooth_noise(x / ctx.scale * ctx.freq, y / ctx.scale * ctx.freq + t, ctx.seed) - 0.5) * ctx.strength * 2
  dy = (smooth_noise(x / ctx.scale * ctx.freq + 33, y / ctx.scale * ctx.freq + t * 1.4, ctx.seed + 9) - 0.5) * ctx.strength * 0.6
  x + dx * ctx.m, y + (dy - ctx.strength * 0.15) * ctx.m

FIELD_FX.water = (ctx, x, y, q) ->
  t = ctx.phi / math.pi
  dx = (smooth_noise(x / ctx.scale + t, y / ctx.scale, ctx.seed) - 0.5) * ctx.strength * 1.2
  dy = math.sin(q.px * math.pi * 2 * ctx.freq + ctx.phi + field_noise(ctx, x, y) * 4) * ctx.strength * 0.8
  x + dx * ctx.m, y + dy * ctx.m

FIELD_FX.gelatin = (ctx, x, y, q) ->
  tp = ctx.phi / (math.pi * 2)
  tp = tp - math.floor tp
  damp = math.exp(-tp * 3) * math.sin(tp * math.pi * 2 * ctx.freq)
  dx = damp * (q.px - 0.5) * ctx.strength * 1.6
  dy = -damp * (q.py - 0.5) * ctx.strength * 1.2
  x + dx * ctx.m, y + dy * ctx.m

FIELD_FX.underwater = (ctx, x, y, q) ->
  sway = math.sin(q.py * math.pi * ctx.freq + ctx.phi) * ctx.strength
  fine = field_noise(ctx, x, y) * ctx.strength * 0.5
  lift = math.sin(q.px * math.pi * 2 + ctx.phi * 0.5) * ctx.strength * 0.3
  x + (sway + fine) * ctx.m, y + (lift - fine) * ctx.m

FIELD_FX.windblown = (ctx, x, y, q) ->
  dvx, dvy = dir_vector ctx.opts.direction
  ax = dir_axis ctx.opts.direction, q.px, q.py
  t = ctx.phi / (math.pi * 2)
  gust = math.max 0, octave_noise(t * 1.4 - ax * 0.8, q.ci * 0.31, ctx.seed, 2) * 2.4
  flut = field_noise(ctx, x, y) * 0.8
  amp = ctx.strength * (gust + 0.15) * ctx.m
  x + (dvx * amp) + flut * amp * 0.4, y + (dvy * amp) + flut * amp * 0.4

FIELD_FX.buzz = (ctx, x, y, q) ->
  step = ctx.frame_key % 4
  sign = step % 2 == 0 and 1 or -1
  dx = sign * ctx.strength * (0.5 + noise_hash(q.i, q.ci + step, ctx.seed))
  dy = -sign * ctx.strength * 0.4 * (0.5 + noise_hash(q.i + 9, q.ci + step, ctx.seed))
  x + dx * ctx.m, y + dy * ctx.m

FIELD_FX.wave_h = (ctx, x, y, q) ->
  x + math.sin(q.py * math.pi * 2 * ctx.freq - ctx.phi) * ctx.strength * ctx.m, y

FIELD_FX.wave_v = (ctx, x, y, q) ->
  x, y + math.sin(q.px * math.pi * 2 * ctx.freq - ctx.phi) * ctx.strength * ctx.m

FIELD_FX.wave_d = (ctx, x, y, q) ->
  w = math.sin((q.px + q.py) * math.pi * ctx.freq * 2 - ctx.phi) * ctx.strength * ctx.m
  x + w, y + w * 0.55

FIELD_FX.wave_standing = (ctx, x, y, q) ->
  x + math.sin(q.py * math.pi * 2 * ctx.freq) * math.cos(ctx.phi) * ctx.strength * ctx.m, y

FIELD_FX.flag = (ctx, x, y, q) ->
  ax = dir_axis ctx.opts.direction, q.px, q.py
  dvx, dvy = dir_vector ctx.opts.direction
  w = math.sin(ax * math.pi * 2 * ctx.freq - ctx.phi) * ctx.strength * ax * ax * ctx.m
  x + (-dvy) * w, y + dvx * w

FIELD_FX.skiprope = (ctx, x, y, q) ->
  swing = math.sin(ctx.phi) * math.sin(q.px * math.pi) * ctx.strength * ctx.m
  lean = math.cos(ctx.phi) * math.sin(q.px * math.pi) * ctx.strength * 0.25 * ctx.m
  x + lean, y + swing

FIELD_FX.seaweed = (ctx, x, y, q) ->
  h = 1 - q.py
  sway = math.sin(ctx.phi + q.px * 2 + h * 2.4) * ctx.strength * h * h * ctx.m
  x + sway, y + math.abs(sway) * 0.15

FIELD_FX.twist_wave = (ctx, x, y, q) ->
  ax = dir_axis ctx.opts.direction, q.px, q.py
  theta = math.sin(ax * math.pi * 2 * ctx.freq - ctx.phi) * (ctx.strength * math.pi / 180) * ctx.m
  horizontal = ctx.opts.direction == "Left to Right" or ctx.opts.direction == "Right to Left"
  if horizontal
    ry = y - ctx.geo.center.y
    x + ry * math.sin(theta) * 0.6, ctx.geo.center.y + ry * math.cos(theta)
  else
    rx = x - ctx.geo.center.x
    ctx.geo.center.x + rx * math.cos(theta), y + rx * math.sin(theta) * 0.6

FIELD_FX.whip = (ctx, x, y, q) ->
  ax = dir_axis ctx.opts.direction, q.px, q.py
  pos = ctx.phi / (math.pi * 2)
  pos = pos - math.floor pos
  d = ax - pos
  g = math.exp(-d * d * 60)
  w = g * ctx.strength * math.sin(ctx.phi * 3) * ctx.m
  dvx, dvy = dir_vector ctx.opts.direction
  x + (-dvy) * w, y + dvx * w

ripple_disp = (ctx, x, y, ox, oy, phase_shift = 0) ->
  vx, vy, d = unit_from_center x, y, {x: ox, y: oy}
  lam = math.max 8, ctx.maxd * 2 / math.max(0.5, ctx.freq)
  w = math.sin(d / lam * math.pi * 2 - ctx.phi + phase_shift) * ctx.strength
  atten = 1 / (1 + d / (ctx.maxd * 1.2))
  vx * w * atten, vy * w * atten

FIELD_FX.ripple = (ctx, x, y, q) ->
  dx, dy = ripple_disp ctx, x, y, ctx.geo.center.x, ctx.geo.center.y
  x + dx * ctx.m, y + dy * ctx.m

FIELD_FX.ripple_point = (ctx, x, y, q) ->
  dx, dy = ripple_disp ctx, x, y, ctx.fx_center.x, ctx.fx_center.y
  x + dx * ctx.m, y + dy * ctx.m

FIELD_FX.ripple_rain = (ctx, x, y, q) ->
  cycle = math.floor ctx.phi / (math.pi * 2)
  dx, dy = 0, 0
  for k = 0, 2
    ck = cycle - k
    hx = ctx.geo.bbox.min_x + noise_hash(ck, 11 + k, ctx.seed) * ctx.geo.width
    hy = ctx.geo.bbox.min_y + noise_hash(ck, 29 + k, ctx.seed + 3) * ctx.geo.height
    rx, ry = ripple_disp ctx, x, y, hx, hy, -k * 2.1
    fade = 1 - k / 3
    dx += rx * fade
    dy += ry * fade
  x + dx * 0.6 * ctx.m, y + dy * 0.6 * ctx.m

FIELD_FX.ripple_cross = (ctx, x, y, q) ->
  ax, ay = ripple_disp ctx, x, y, ctx.fx_center.x, ctx.fx_center.y
  mirror_x = ctx.geo.center.x * 2 - ctx.fx_center.x
  mirror_y = ctx.geo.center.y * 2 - ctx.fx_center.y
  bx, by = ripple_disp ctx, x, y, mirror_x, mirror_y, math.pi
  x + (ax + bx) * 0.7 * ctx.m, y + (ay + by) * 0.7 * ctx.m

FIELD_FX.wave_bounce = (ctx, x, y, q) ->
  w = math.abs(math.sin(q.px * math.pi * ctx.freq - ctx.phi)) * ctx.strength * ctx.m
  x, y - w

FIELD_FX.twist_sway = (ctx, x, y, q) ->
  falloff = 1 - clamp(q.dist / (ctx.maxd * 1.4), 0, 1)
  theta = math.sin(ctx.phi) * (ctx.strength * math.pi / 180) * falloff * ctx.m
  rx, ry = x - ctx.geo.center.x, y - ctx.geo.center.y
  ca, sa = math.cos(theta), math.sin(theta)
  ctx.geo.center.x + rx * ca - ry * sa, ctx.geo.center.y + rx * sa + ry * ca

FIELD_FX.vortex_swirl = (ctx, x, y, q) ->
  falloff = 1 - clamp(q.dist / (ctx.maxd * 1.5), 0, 0.85)
  theta = ctx.phi * (ctx.strength / 60) * falloff * ctx.m
  rx, ry = x - ctx.geo.center.x, y - ctx.geo.center.y
  ca, sa = math.cos(theta), math.sin(theta)
  ctx.geo.center.x + rx * ca - ry * sa, ctx.geo.center.y + rx * sa + ry * ca

FIELD_FX.magnet = (ctx, x, y, q) ->
  vx, vy, d = unit_from_center ctx.fx_center.x, ctx.fx_center.y, {x: x, y: y}
  pulse = 0.5 + 0.5 * math.sin(ctx.phi)
  force = ctx.strength * pulse * (1 - clamp(d / (ctx.maxd * 2.4), 0, 1)) * ctx.m
  x + vx * force, y + vy * force

FIELD_FX.pinch_pulse = (ctx, x, y, q) ->
  force = (ctx.strength / 100) * (0.5 + 0.5 * math.sin(ctx.phi)) * ctx.m
  x - q.ux * q.dist * force, y - q.uy * q.dist * force

FIELD_FX.bulge_pulse = (ctx, x, y, q) ->
  force = (ctx.strength / 100) * (0.5 + 0.5 * math.sin(ctx.phi)) * ctx.m
  x + q.ux * q.dist * force, y + q.uy * q.dist * force

FIELD_FX.heartbeat_r = (ctx, x, y, q) ->
  tp = ctx.phi / (math.pi * 2)
  tp = tp - math.floor tp
  thump = math.exp(-((tp - 0.12) / 0.06) ^ 2) + 0.65 * math.exp(-((tp - 0.34) / 0.07) ^ 2)
  force = (ctx.strength / 100) * thump * ctx.m
  x + q.ux * q.dist * force, y + q.uy * q.dist * force

FIELD_FX.spring = (ctx, x, y, q) ->
  tp = ctx.phi / (math.pi * 2)
  tp = tp - math.floor tp
  osc = math.sin(tp * math.pi * 2 * 2) * math.exp(-tp * 3)
  sy = 1 + osc * (ctx.strength / 100) * ctx.m
  sx = 1 - osc * (ctx.strength / 140) * ctx.m
  floor_y = ctx.geo.bbox.max_y
  cx = ctx.geo.center.x
  cx + (x - cx) * sx, floor_y + (y - floor_y) * sy

FIELD_FX.lens = (ctx, x, y, q) ->
  tp = ctx.phi / (math.pi * 2)
  tp = tp - math.floor tp
  lx = ctx.geo.bbox.min_x + tp * ctx.geo.width
  ly = ctx.fx_center.y
  vx, vy, d = unit_from_center x, y, {x: lx, y: ly}
  radius = math.max 8, ctx.geo.width * 0.18
  g = math.exp(-(d / radius) ^ 2)
  x + vx * ctx.strength * g * 0.5 * ctx.m, y + vy * ctx.strength * g * 0.5 * ctx.m

FIELD_FX.shock = (ctx, x, y, q) ->
  tp = ctx.phi / (math.pi * 2)
  tp = tp - math.floor tp
  ring = tp * ctx.maxd * 1.3
  band = math.max 4, ctx.maxd * 0.1
  g = math.exp(-((q.dist - ring) / band) ^ 2) * (1 - tp)
  x + q.ux * ctx.strength * g * ctx.m, y + q.uy * ctx.strength * g * ctx.m

FIELD_FX.rings = (ctx, x, y, q) ->
  w = math.sin(q.dist / ctx.maxd * math.pi * ctx.freq - ctx.phi) * ctx.strength * ctx.m
  x + q.ux * w, y + q.uy * w

FIELD_FX.lag_orbit = (ctx, x, y, q) ->
  delay = q.dist / math.max(1, ctx.maxd) * 1.3
  x + math.cos(ctx.phi - delay) * ctx.strength * ctx.m, y + math.sin(ctx.phi - delay) * ctx.strength * 0.8 * ctx.m

edge_out = (ctx, x, y, q, amount) ->
  x + q.nx * amount, y + q.ny * amount

FIELD_FX.rough = (ctx, x, y, q) ->
  amount = octave_noise(x / ctx.scale + ctx.ca, y / ctx.scale + ctx.sa, ctx.seed, 3) * ctx.strength * 2.4 * ctx.m
  edge_out ctx, x, y, q, amount

FIELD_FX.serrate = (ctx, x, y, q) ->
  amount = tri_wave(q.s * ctx.freq) * ctx.strength * 0.5 * ctx.m
  edge_out ctx, x, y, q, amount

FIELD_FX.sawtooth = (ctx, x, y, q) ->
  ph = q.s * ctx.freq
  ph = ph - math.floor ph
  amount = (ph * 2 - 1) * ctx.strength * 0.6 * ctx.m
  x + q.nx * amount + q.tx * amount * 0.5, y + q.ny * amount + q.ty * amount * 0.5

FIELD_FX.bitten = (ctx, x, y, q) ->
  b = math.max(0, smooth_noise(q.s * ctx.freq, q.ci * 5.3, ctx.seed) - 0.6) / 0.4
  edge_out ctx, x, y, q, -b * b * ctx.strength * 2 * ctx.m

FIELD_FX.corrode = (ctx, x, y, q) ->
  pit = math.abs(octave_noise(x / ctx.scale + ctx.ca * 0.4, y / ctx.scale + ctx.sa * 0.4, ctx.seed, 3))
  edge_out ctx, x, y, q, -pit * ctx.strength * 2.2 * ctx.m

FIELD_FX.charcoal = (ctx, x, y, q) ->
  grain = octave_noise(x / ctx.scale, y / ctx.scale, ctx.seed, 4) * 1.6
  flick = (noise_hash(q.i * 3 + q.ci * 71, ctx.frame_key, ctx.seed) - 0.5) * 0.9
  edge_out ctx, x, y, q, (grain + flick) * ctx.strength * ctx.m

FIELD_FX.chalk = (ctx, x, y, q) ->
  run = noise_hash(math.floor(q.s * ctx.freq), q.ci * 13, ctx.seed) - 0.5
  x + q.tx * run * ctx.strength * 2 * ctx.m + q.nx * run * ctx.strength * 0.6 * ctx.m, y + q.ty * run * ctx.strength * 2 * ctx.m + q.ny * run * ctx.strength * 0.6 * ctx.m

FIELD_FX.crayon = (ctx, x, y, q) ->
  w = (smooth_noise(q.s * ctx.freq + ctx.ca * 0.3, q.ci * 3.7, ctx.seed) - 0.5) * 2
  x + q.tx * w * ctx.strength * ctx.m + q.nx * w * ctx.strength * 0.8 * ctx.m, y + q.ty * w * ctx.strength * ctx.m + q.ny * w * ctx.strength * 0.8 * ctx.m

FIELD_FX.drybrush = (ctx, x, y, q) ->
  streak = (smooth_noise(q.s * 40, q.ci * 2.9 + ctx.ca * 0.2, ctx.seed) - 0.5) * 3
  x + q.tx * streak * ctx.strength * ctx.m + q.nx * streak * ctx.strength * 0.25 * ctx.m, y + q.ty * streak * ctx.strength * ctx.m + q.ny * streak * ctx.strength * 0.25 * ctx.m

FIELD_FX.spray = (ctx, x, y, q) ->
  amount = math.max(0, noise_hash(q.i * 11 + q.ci * 43, ctx.frame_key, ctx.seed) - 0.35) * ctx.strength * 1.8 * ctx.m
  edge_out ctx, x, y, q, amount

FIELD_FX.living = (ctx, x, y, q) ->
  amount = (smooth_noise(q.s * ctx.freq - ctx.phi / math.pi, q.ci * 4.7, ctx.seed) - 0.5) * ctx.strength * 2.2 * ctx.m
  edge_out ctx, x, y, q, amount

FIELD_FX.electric_edge = (ctx, x, y, q) ->
  cellk = math.floor(q.s * ctx.freq * 2) + ctx.frame_key * 13
  zig = (noise_hash(cellk, q.ci * 3, ctx.seed) - 0.5) * 2
  gate = noise_hash(cellk, ctx.frame_key + q.ci, ctx.seed + 9) > 0.45 and 1 or 0.15
  edge_out ctx, x, y, q, zig * gate * ctx.strength * ctx.m

FIELD_FX.fur = (ctx, x, y, q) ->
  spike = math.abs(math.sin(q.s * math.pi * ctx.freq)) ^ 3
  sway = math.sin(ctx.phi + q.s * 20 + q.ci) * 0.35
  amount = spike * ctx.strength * (1 + sway) * ctx.m
  x + (q.nx + q.tx * sway) * amount, y + (q.ny + q.ty * sway) * amount

FIELD_FX.frost = (ctx, x, y, q) ->
  facet = math.floor(noise_hash(math.floor(q.s * ctx.freq), q.ci * 7, ctx.seed) * 3) - 1
  sparkle = noise_hash(math.floor(q.s * ctx.freq), ctx.frame_key, ctx.seed + 4) > 0.85 and 1.8 or 1
  edge_out ctx, x, y, q, facet * ctx.strength * 0.6 * sparkle * ctx.m

FIELD_FX.torn = (ctx, x, y, q) ->
  g = math.max(0, smooth_noise(q.s * ctx.freq * 0.7, q.ci * 7.7, ctx.seed) - 0.55) * 2.2
  jag = (noise_hash(q.i, q.ci * 19, ctx.seed) - 0.5) * 0.7
  edge_out ctx, x, y, q, -(g * (1 + jag)) * ctx.strength * 1.6 * ctx.m

FIELD_FX.stamp = (ctx, x, y, q) ->
  ph = q.s * ctx.freq
  ph = ph - math.floor ph
  notch = math.sqrt(math.max(0, 0.25 - (ph - 0.5) ^ 2)) * 2
  edge_out ctx, x, y, q, -notch * ctx.strength * ctx.m

FIELD_FX.cloud = (ctx, x, y, q) ->
  lobe = math.abs(math.sin(q.s * math.pi * ctx.freq + q.ci)) ^ 1.4
  edge_out ctx, x, y, q, lobe * ctx.strength * ctx.m

FIELD_FX.thorn = (ctx, x, y, q) ->
  ph = q.s * ctx.freq
  ph = ph - math.floor ph
  spike = math.max(0, 1 - math.abs(ph - 0.5) * 8)
  len = 0.5 + noise_hash(math.floor(q.s * ctx.freq), q.ci * 3, ctx.seed)
  edge_out ctx, x, y, q, spike * len * ctx.strength * ctx.m

FIELD_FX.scallop = (ctx, x, y, q) ->
  arc = math.abs(math.sin(q.s * math.pi * ctx.freq)) - 0.5
  edge_out ctx, x, y, q, arc * ctx.strength * ctx.m

FIELD_FX.bubble = (ctx, x, y, q) ->
  k = math.floor q.s * ctx.freq
  ph = ctx.phi / (math.pi * 2) + noise_hash(k, q.ci * 11, ctx.seed)
  ph = ph - math.floor ph
  grow = ph < 0.8 and ph / 0.8 or (1 - ph) / 0.2
  lobe = math.abs(math.sin(q.s * math.pi * ctx.freq))
  edge_out ctx, x, y, q, lobe * grow * ctx.strength * ctx.m

FIELD_FX.spread = (ctx, x, y, q) ->
  amount = ctx.strength * (0.6 + smooth_noise(q.s * 9, q.ci * 3, ctx.seed)) * ctx.m
  edge_out ctx, x, y, q, amount

FIELD_FX.dry = (ctx, x, y, q) ->
  pit = math.abs(octave_noise(x / ctx.scale, y / ctx.scale, ctx.seed, 3)) * 1.4
  amount = -(0.5 + pit) * ctx.strength * ctx.m
  edge_out ctx, x, y, q, amount

FIELD_FX.wet = (ctx, x, y, q) ->
  swell = (0.3 + 0.7 * (0.5 + 0.5 * math.sin(ctx.phi))) * ctx.strength * (0.5 + field_noise(ctx, x, y) * 0.9)
  wob = math.sin(q.s * math.pi * 6 + ctx.phi) * ctx.strength * 0.25
  x + q.nx * (swell + wob) * ctx.m, y + q.ny * (swell + wob) * ctx.m + swell * 0.12 * ctx.m

FIELD_FX.bloom = (ctx, x, y, q) ->
  ang = math.atan2 y - q.co.centroid.y, x - q.co.centroid.x
  lobes = 0.5 + 0.5 * math.sin(ang * ctx.freq + q.ci * 2.1)
  amount = ctx.strength * (0.3 + lobes) * (0.5 + smooth_noise(q.s * 5, q.ci, ctx.seed) * 0.8) * ctx.m
  edge_out ctx, x, y, q, amount

FIELD_FX.absorb = (ctx, x, y, q) ->
  pull = ctx.strength * ctx.m
  x - q.nx * pull * 0.8, y - q.ny * pull * 0.8 + pull * 0.5

FIELD_FX.smoke = (ctx, x, y, q) ->
  swirl = octave_noise(x / ctx.scale, y / ctx.scale - ctx.m * 2, ctx.seed, 3) * ctx.strength * 1.6
  x + swirl * ctx.m, y - ctx.strength * ctx.m * (1 + q.py) - math.abs(swirl) * ctx.m * 0.4

FIELD_FX.steam = (ctx, x, y, q) ->
  t = ctx.phi / math.pi
  lift = (0.5 + 0.5 * math.sin(ctx.phi + q.py * 4)) * ctx.strength
  wob = (smooth_noise(x / ctx.scale, y / ctx.scale + t, ctx.seed) - 0.5) * ctx.strength * 1.4
  x + wob * ctx.m, y - lift * (1 - q.py) * 0.6 * ctx.m

FIELD_FX.burn = (ctx, x, y, q) ->
  ax = dir_axis ctx.opts.direction, q.px, q.py
  finger = (smooth_noise(q.px * 6, q.py * 6, ctx.seed) - 0.5) * 0.25
  e = 1 - ctx.m + finger
  k = clamp((ax - e) / 0.22, 0, 1)
  return x, y if k <= 0
  ember = (noise_hash(q.i, ctx.frame_key, ctx.seed) - 0.5) * ctx.strength * k
  x - q.nx * k * ctx.strength * 1.6 + ember, y - q.ny * k * ctx.strength * 1.6 - k * ctx.strength * 0.8 + ember * 0.5

FIELD_FX.boiloff = (ctx, x, y, q) ->
  boil = field_noise(ctx, x, y) * ctx.strength * 2 * (0.4 + ctx.m * 1.6)
  x + boil, y + field_noise(ctx, x, y, 37, 17) * ctx.strength * 2 * (0.4 + ctx.m * 1.6) - ctx.m * ctx.m * ctx.strength * 3

FIELD_FX.bleed = (ctx, x, y, q) ->
  seedv = smooth_noise(q.s * ctx.freq, q.ci * 3.3, ctx.seed)
  k = clamp((seedv + 0.35 - ctx.m * 1.4) * 3, 0, 1)
  amount = (1 - k) * ctx.strength * (0.5 + seedv)
  edge_out ctx, x, y, q, amount

FIELD_FX.frost_creep = (ctx, x, y, q) ->
  reach = (1 - ctx.m) * 1.25
  g = clamp((reach - q.sg) * 6, 0, 1)
  facet = math.floor(noise_hash(math.floor(q.s * ctx.freq), q.ci * 7, ctx.seed) * 3) - 1
  loose = (1 - g) * ctx.strength
  x + q.nx * facet * loose + (noise_hash(q.i, q.ci, ctx.seed) - 0.5) * loose, y + q.ny * facet * loose + (noise_hash(q.i + 5, q.ci, ctx.seed + 2) - 0.5) * loose

drip_finger = (ctx, q, cols) ->
  math.max(0, smooth_noise(q.px * cols, q.ci * 5.1, ctx.seed) - 0.55) / 0.45

FIELD_FX.drip = (ctx, x, y, q) ->
  lower = q.py * q.py
  f = drip_finger ctx, q, ctx.freq
  x, y + ctx.strength * ctx.m * lower * (0.25 + f * 2.2)

FIELD_FX.bottom = (ctx, x, y, q) ->
  lower = q.py ^ 3
  f = drip_finger ctx, q, ctx.freq
  x, y + ctx.strength * ctx.m * lower * (0.5 + f * 1.8) * 1.4

FIELD_FX.side = (ctx, x, y, q) ->
  edge_w = math.abs(q.px - 0.5) * 2
  f = math.max(0, smooth_noise(q.py * ctx.freq, q.ci * 4.3, ctx.seed) - 0.5) * 2.2
  run = ctx.strength * ctx.m * edge_w * (0.3 + f) * q.py
  x + (q.px < 0.5 and -run or run), y + run * 0.5

FIELD_FX.stain = (ctx, x, y, q) ->
  lower = q.py * q.py
  n = smooth_noise(q.px * 8, q.py * 8, ctx.seed)
  x + (n - 0.5) * ctx.strength * ctx.m, y + ctx.strength * ctx.m * lower * 2.2 * (0.5 + n)

melt_floor = (ctx, x, y, dx, dy) ->
  floor_y = ctx.geo.bbox.max_y + ctx.strength * 0.25
  ny = y + dy
  if ny > floor_y
    over = ny - floor_y
    dx += (x >= ctx.geo.center.x and 1 or -1) * over * 0.55
    ny = floor_y + math.min(over * 0.08, ctx.strength * 0.1)
  x + dx, ny

FIELD_FX.melt = (ctx, x, y, q) ->
  lower = q.py * q.py
  n = 0.6 + smooth_noise(q.px * 5, q.ci * 3, ctx.seed) * 0.8
  melt_floor ctx, x, y, 0, ctx.strength * ctx.m * (0.35 + lower * 1.3) * n

FIELD_FX.melt_diag = (ctx, x, y, q) ->
  lower = q.py * q.py
  n = 0.6 + smooth_noise(q.px * 5, q.ci * 3, ctx.seed) * 0.8
  drop = ctx.strength * ctx.m * (0.35 + lower * 1.3) * n
  melt_floor ctx, x, y, drop * 0.5, drop

FIELD_FX.rainwash = (ctx, x, y, q) ->
  col = math.floor q.px * ctx.freq
  g = noise_hash col, 3, ctx.seed
  x, y + ctx.strength * ctx.m * (0.25 + g * 1.5) * (0.4 + q.py)

FIELD_FX.slime = (ctx, x, y, q) ->
  stretch = 0.5 - 0.5 * math.cos(ctx.phi)
  lower = q.py ^ 3
  x + (x - ctx.geo.center.x) * lower * stretch * 0.22 * ctx.m, y + ctx.strength * stretch * lower * 2 * ctx.m

FIELD_FX.slime_snap = (ctx, x, y, q) ->
  lower = q.py ^ 3
  x + (x - ctx.geo.center.x) * lower * ctx.m * 0.3, y + ctx.strength * ctx.m * lower * 2.4

FIELD_FX.puddle = (ctx, x, y, q) ->
  lower = q.py * q.py
  spread = (x - ctx.geo.center.x) * lower * ctx.m * 0.9
  squash = (ctx.geo.bbox.max_y - y) * ctx.m * lower * 0.45
  x + spread, y + squash + ctx.strength * ctx.m * lower * 0.3

FIELD_FX.icicle = (ctx, x, y, q) ->
  ph = q.px * ctx.freq
  ph = ph - math.floor ph
  spike = math.max(0, 1 - math.abs(ph - 0.5) * 5) ^ 1.5
  len = 0.4 + noise_hash(math.floor(q.px * ctx.freq), 7, ctx.seed)
  x, y + ctx.strength * ctx.m * spike * len * q.py * 2

FIELD_FX.candle = (ctx, x, y, q) ->
  sag = 0.5 - 0.5 * math.cos(ctx.phi)
  lower = q.py * q.py
  n = 0.5 + smooth_noise(q.px * 4, q.ci * 2, ctx.seed)
  melt_floor ctx, x, y, 0, ctx.strength * sag * lower * n * ctx.m

FIELD_FX.drip_loop = (ctx, x, y, q) ->
  tp = ctx.phi / (math.pi * 2)
  tp = tp - math.floor tp
  fall = tp < 0.7 and tp / 0.7 or 1 + ((tp - 0.7) / 0.3) ^ 2 * 2
  lower = q.py * q.py
  f = drip_finger ctx, q, ctx.freq
  x, y + ctx.strength * fall * lower * f * 2 * ctx.m

FIELD_FX.path_wave = (ctx, x, y, q) ->
  w = math.sin(q.s * math.pi * 2 * ctx.freq - ctx.phi) * ctx.strength * ctx.m
  x + q.nx * w, y + q.ny * w

FIELD_FX.path_bulge = (ctx, x, y, q) ->
  head = ctx.phi / (math.pi * 2)
  head = head - math.floor head
  d = math.abs q.s - head
  d = math.min d, 1 - d
  g = math.exp(-(d * 9) ^ 2)
  x + q.nx * g * ctx.strength * ctx.m, y + q.ny * g * ctx.strength * ctx.m

FIELD_FX.path_peristalsis = (ctx, x, y, q) ->
  w = math.max(0, math.sin(q.s * math.pi * 2 * ctx.freq - ctx.phi)) ^ 3 * ctx.strength * ctx.m
  x + q.nx * w, y + q.ny * w

FIELD_FX.path_flow = (ctx, x, y, q) ->
  flow = ctx.strength * (0.6 + 0.4 * math.sin(q.s * math.pi * 4 - ctx.phi)) * ctx.m
  x + q.tx * flow, y + q.ty * flow

wipe_jitter = (ctx, q, k) ->
  jx = (smooth_noise(q.px * 9, q.py * 9, ctx.seed + 9) - 0.5) * ctx.strength * 0.18 * k
  jy = (smooth_noise(q.px * 9 + 3, q.py * 9 - 4, ctx.seed + 13) - 0.5) * ctx.strength * 0.18 * k
  jx, jy

dir_project = (ctx, e, x, y) ->
  bbox = ctx.geo.bbox
  switch ctx.opts.direction
    when "Right to Left" then bbox.max_x - ctx.geo.width * e, y
    when "Top to Bottom" then x, bbox.min_y + ctx.geo.height * e
    when "Bottom to Top" then x, bbox.max_y - ctx.geo.height * e
    else bbox.min_x + ctx.geo.width * e, y

dir_wipe = (ctx, x, y, q, fnoise) ->
  e = clamp 1 - ctx.m, 0, 1
  ax = dir_axis(ctx.opts.direction, q.px, q.py) + fnoise
  return x, y if ax <= e
  k = clamp (ax - e) / math.max(0.05, 1 - e), 0, 1
  tx, ty = dir_project ctx, clamp(e + fnoise, 0, 1), x, y
  jx, jy = wipe_jitter ctx, q, k
  x + (tx - x) * k + jx, y + (ty - y) * k + jy

FIELD_FX.wipe_organic = (ctx, x, y, q) ->
  fnoise = (smooth_noise(q.px * 5 + 3, q.py * 5, ctx.seed) - 0.5) * 0.3
  dir_wipe ctx, x, y, q, fnoise

FIELD_FX.wipe_wavy = (ctx, x, y, q) ->
  perp = (ctx.opts.direction == "Left to Right" or ctx.opts.direction == "Right to Left") and q.py or q.px
  fnoise = math.sin(perp * math.pi * 2 * ctx.freq + ctx.prog * math.pi) * 0.16
  dir_wipe ctx, x, y, q, fnoise

FIELD_FX.wipe_shaky = (ctx, x, y, q) ->
  fnoise = (smooth_noise(q.px * 6, q.py * 6 + ctx.frame_key * 0.618, ctx.seed) - 0.5) * 0.34
  dir_wipe ctx, x, y, q, fnoise

FIELD_FX.wipe_ink = (ctx, x, y, q) ->
  perp = (ctx.opts.direction == "Left to Right" or ctx.opts.direction == "Right to Left") and q.py or q.px
  finger = math.max(0, smooth_noise(perp * ctx.freq, q.ci * 2.3, ctx.seed) - 0.42) * 1.9
  dir_wipe ctx, x, y, q, -finger * 0.45

FIELD_FX.wipe_diag = (ctx, x, y, q) ->
  e = clamp 1 - ctx.m, 0, 1
  fnoise = (smooth_noise(q.px * 5, q.py * 5, ctx.seed) - 0.5) * 0.22
  ax = (q.px + q.py) / 2 + fnoise
  return x, y if ax <= e
  k = clamp (ax - e) / math.max(0.05, 1 - e), 0, 1
  span = (ctx.geo.width + ctx.geo.height) * 0.5
  shift = (ax - e) * span * 0.707 * k
  jx, jy = wipe_jitter ctx, q, k
  x - shift + jx, y - shift + jy

FIELD_FX.wipe_iris = (ctx, x, y, q) ->
  e = clamp 1 - ctx.m, 0, 1
  vx, vy, d = unit_from_center x, y, ctx.fx_center
  reach = ctx.maxd * 1.35
  fnoise = (smooth_noise(q.px * 6, q.py * 6, ctx.seed) - 0.5) * 0.2
  ax = d / math.max(1, reach) + fnoise
  return x, y if ax <= e
  k = clamp (ax - e) / math.max(0.05, 1 - e), 0, 1
  target_d = clamp(e + fnoise, 0, 1) * reach
  jx, jy = wipe_jitter ctx, q, k
  x + (ctx.fx_center.x + vx * target_d - x) * k + jx, y + (ctx.fx_center.y + vy * target_d - y) * k + jy

FIELD_FX.wipe_swirl = (ctx, x, y, q) ->
  e = clamp 1 - ctx.m, 0, 1
  ang = math.atan2 y - ctx.geo.center.y, x - ctx.geo.center.x
  a0 = (ang + math.pi) / (math.pi * 2)
  fnoise = (smooth_noise(q.px * 4, q.py * 4, ctx.seed) - 0.5) * 0.12
  ax = clamp a0 + fnoise, 0, 1
  return x, y if ax <= e
  k = clamp (ax - e) / math.max(0.05, 1 - e), 0, 1
  theta_f = e * math.pi * 2 - math.pi
  theta = ang + (theta_f - ang) * k + k * 0.9
  d = q.dist * (1 - k * 0.3)
  jx, jy = wipe_jitter ctx, q, k
  ctx.geo.center.x + math.cos(theta) * d + jx, ctx.geo.center.y + math.sin(theta) * d + jy

FIELD_FX.ds_noise = (ctx, x, y, q) ->
  r = 1 - ctx.m
  h1 = noise_hash(q.i * 3 + q.ci * 101, 7, ctx.seed) - 0.5
  h2 = noise_hash(q.i * 3 + q.ci * 101, 19, ctx.seed + 5) - 0.5
  stagger = noise_hash(q.i + q.ci * 47, 3, ctx.seed + 11)
  k = stagger_amount r, stagger, 0.85
  sx = x + h1 * ctx.strength * 3
  sy = y + h2 * ctx.strength * 3
  sx + (x - sx) * k, sy + (y - sy) * k

FIELD_FX.ds_erode = (ctx, x, y, q) ->
  r = 1 - ctx.m
  g = smooth_noise(x / math.max(8, ctx.scale * 0.3), y / math.max(8, ctx.scale * 0.3), ctx.seed)
  eat = clamp((g + 0.2 - r * 1.4) * 2.4, 0, 1) * ctx.m
  crumb = (noise_hash(q.i, q.ci * 7, ctx.seed) - 0.5) * eat * ctx.strength * 0.5
  x - q.nx * eat * ctx.strength + crumb, y - q.ny * eat * ctx.strength + crumb * 0.7

FIELD_FX.ds_split = (ctx, x, y, q) ->
  e = clamp 1 - ctx.m, 0, 1
  ax0 = dir_axis ctx.opts.direction, q.px, q.py
  side = ax0 >= 0.5 and 1 or -1
  ax = math.abs(ax0 - 0.5) * 2
  fnoise = (smooth_noise(q.px * 5, q.py * 5, ctx.seed) - 0.5) * 0.18
  ax += fnoise
  return x, y if ax <= e
  k = clamp (ax - e) / math.max(0.05, 1 - e), 0, 1
  target_ax0 = 0.5 + side * clamp(e + fnoise, 0, 1) * 0.5
  tx, ty = dir_project ctx, target_ax0, x, y
  jx, jy = wipe_jitter ctx, q, k
  x + (tx - x) * k + jx, y + (ty - y) * k + jy

FIELD_FX.ds_band = (ctx, x, y, q) ->
  ax = dir_axis ctx.opts.direction, q.px, q.py
  band = math.floor ax * ctx.freq
  sign = band % 2 == 0 and 1 or -1
  stagger = noise_hash(band, 5, ctx.seed) * 0.3
  k = clamp ctx.m * (1 + stagger) - stagger, 0, 1
  horizontal = ctx.opts.direction == "Left to Right" or ctx.opts.direction == "Right to Left"
  if horizontal
    x, y + sign * k * ctx.geo.height * 1.4
  else
    x + sign * k * ctx.geo.width * 1.4, y

FIELD_FX.ds_checker = (ctx, x, y, q) ->
  cells = math.max 2, ctx.freq
  cw = ctx.geo.width / cells
  ch = ctx.geo.height / math.max(1, round(cells * ctx.geo.height / math.max(1, ctx.geo.width)))
  ch = cw if ch <= 0
  cxi = math.floor (x - ctx.geo.bbox.min_x) / math.max(1, cw)
  cyi = math.floor (y - ctx.geo.bbox.min_y) / math.max(1, ch)
  cc_x = ctx.geo.bbox.min_x + (cxi + 0.5) * cw
  cc_y = ctx.geo.bbox.min_y + (cyi + 0.5) * ch
  stagger = noise_hash(cxi * 7 + cyi * 13, (cxi + cyi) % 2, ctx.seed)
  r = 1 - ctx.m
  k = stagger_amount r, stagger, 0.8
  cc_x + (x - cc_x) * k, cc_y + (y - cc_y) * k

FIELD_FX.ds_crystal = (ctx, x, y, q) ->
  qsize = 1 + ctx.m * ctx.strength
  sx = math.floor(x / qsize + 0.5) * qsize
  sy = math.floor(y / qsize + 0.5) * qsize
  k = clamp ctx.m * 1.4, 0, 1
  x + (sx - x) * k, y + (sy - y) * k

axis_is_horizontal = (direction) ->
  direction == "Left to Right" or direction == "Right to Left"

FIELD_FX.accordion = (ctx, x, y, q) ->
  ax = dir_axis ctx.opts.direction, q.px, q.py
  pleat = tri_wave(ax * ctx.freq) * ctx.strength * ctx.m
  ax2 = ax * (1 - 0.85 * ctx.m)
  tx, ty = dir_project ctx, ax2, x, y
  if axis_is_horizontal ctx.opts.direction
    tx, y + pleat
  else
    x + pleat, ty

FIELD_FX.roll = (ctx, x, y, q) ->
  ax = dir_axis ctx.opts.direction, q.px, q.py
  front = 1 - ctx.m
  return x, y if ax <= front
  horizontal = axis_is_horizontal ctx.opts.direction
  axis_len = horizontal and ctx.geo.width or ctx.geo.height
  r = math.max 6, ctx.strength
  d_beyond = (ax - front) * axis_len
  theta = d_beyond / r
  new_ax = front + (r * math.sin(theta)) / math.max(1, axis_len)
  lift = r * (1 - math.cos(theta)) * 0.35
  tx, ty = dir_project ctx, new_ax, x, y
  if horizontal
    tx, y - lift
  else
    x - lift, ty

FIELD_FX.twistc = (ctx, x, y, q) ->
  ax = dir_axis ctx.opts.direction, q.px, q.py
  theta = (ax - 0.5) * ctx.freq * math.pi * 2 * ctx.m
  shrink = 1 - 0.3 * ctx.m
  if axis_is_horizontal ctx.opts.direction
    ry = (y - ctx.geo.center.y) * shrink
    x + ry * math.sin(theta) * 0.7, ctx.geo.center.y + ry * math.cos(theta)
  else
    rx = (x - ctx.geo.center.x) * shrink
    ctx.geo.center.x + rx * math.cos(theta), y + rx * math.sin(theta) * 0.7

FIELD_FX.fan = (ctx, x, y, q) ->
  ax = dir_axis ctx.opts.direction, q.px, q.py
  bbox = ctx.geo.bbox
  local pivot_x, pivot_y, sign
  switch ctx.opts.direction
    when "Right to Left"
      pivot_x, pivot_y, sign = bbox.max_x, bbox.max_y, 1
    when "Top to Bottom"
      pivot_x, pivot_y, sign = bbox.min_x, bbox.min_y, -1
    when "Bottom to Top"
      pivot_x, pivot_y, sign = bbox.min_x, bbox.max_y, 1
    else
      pivot_x, pivot_y, sign = bbox.min_x, bbox.max_y, -1
  alpha = (ctx.strength * math.pi / 180) * ctx.m * (0.15 + 0.85 * (1 - ax)) * sign
  rx, ry = x - pivot_x, y - pivot_y
  ca, sa = math.cos(alpha), math.sin(alpha)
  pivot_x + rx * ca - ry * sa, pivot_y + rx * sa + ry * ca

FIELD_FX.blinds = (ctx, x, y, q) ->
  ax = dir_axis ctx.opts.direction, q.px, q.py
  slats = math.max 2, ctx.freq
  slat = math.floor ax * slats
  w_s = ax * slats - slat
  w2 = 0.5 + (w_s - 0.5) * (1 - ctx.m)
  ax2 = (slat + w2) / slats
  tx, ty = dir_project ctx, ax2, x, y
  if axis_is_horizontal ctx.opts.direction
    tx, y
  else
    x, ty

FIELD_FX.crumple = (ctx, x, y, q) ->
  px, py = x, y
  folds = math.min 8, math.max 2, round ctx.freq
  for k = 1, folds
    ang = noise_hash(k, 3, ctx.seed) * math.pi * 2
    nkx, nky = math.cos(ang), math.sin(ang)
    ckx = ctx.geo.center.x + (noise_hash(k, 7, ctx.seed) - 0.5) * ctx.geo.width * 0.6
    cky = ctx.geo.center.y + (noise_hash(k, 11, ctx.seed) - 0.5) * ctx.geo.height * 0.6
    d = (px - ckx) * nkx + (py - cky) * nky
    if d > 0
      w = (0.4 + 0.6 * noise_hash(k, 17, ctx.seed)) * ctx.m
      px -= nkx * d * 1.6 * w
      py -= nky * d * 1.6 * w
  shrink = 1 - 0.3 * ctx.m
  ctx.geo.center.x + (px - ctx.geo.center.x) * shrink, ctx.geo.center.y + (py - ctx.geo.center.y) * shrink

FIELD_FX.jelly = (ctx, x, y, q) ->
  t = ctx.spec.phase == "out" and 1 - ctx.prog or ctx.prog
  ring = math.sin(t * math.pi * 2 * (ctx.freq + 1.5)) * math.exp(-t * 5)
  dy = ring * (1 - q.py) * ctx.strength * 0.7
  dx = -ring * (q.px - 0.5) * ctx.strength * 1.1
  drop = math.max(0, 1 - t * 4)
  x + dx, y + dy - drop * drop * ctx.geo.height * 1.2

FIELD_FX.burst = (ctx, x, y, q) ->
  h = noise_hash(q.i * 3 + q.ci * 91, 5, ctx.seed)
  d_extra = ctx.m * ctx.m * ctx.strength * (0.6 + h * 0.9)
  theta = ctx.m * (h - 0.5) * 1.4
  rx, ry = x - ctx.geo.center.x, y - ctx.geo.center.y
  ca, sa = math.cos(theta), math.sin(theta)
  nx0 = ctx.geo.center.x + rx * ca - ry * sa
  ny0 = ctx.geo.center.y + rx * sa + ry * ca
  nx0 + q.ux * d_extra, ny0 + q.uy * d_extra

FIELD_FX.vortexp = (ctx, x, y, q) ->
  h = noise_hash(q.ci * 31, 3, ctx.seed)
  r = q.dist * (1 + ctx.m * (ctx.strength / 30))
  ang = math.atan2(y - ctx.geo.center.y, x - ctx.geo.center.x) + ctx.m * (2.2 + h)
  ctx.geo.center.x + math.cos(ang) * r, ctx.geo.center.y + math.sin(ang) * r

FIELD_FX.sag = (ctx, x, y, q) ->
  n = 0.6 + smooth_noise(q.px * 4, q.ci * 2, ctx.seed) * 0.8
  x + (q.px - 0.5) * ctx.strength * ctx.m * 0.3, y + ctx.strength * ctx.m * q.py * q.py * n

FIELD_FX.wind = (ctx, x, y, q) ->
  dvx, dvy = dir_vector ctx.opts.direction
  h = noise_hash(q.i + q.ci * 61, 9, ctx.seed)
  tat = math.max(0, octave_noise(q.px * 3, q.py * 3, ctx.seed, 2) * 2 + 0.3)
  amp = ctx.m * ctx.m * ctx.strength * (0.5 + q.py * 0.5) * (0.6 + h) * tat
  x + dvx * amp + (h - 0.5) * ctx.m * ctx.strength * 0.2, y + dvy * amp + (noise_hash(q.i, 3, ctx.seed) - 0.5) * ctx.m * ctx.strength * 0.35

FIELD_FX.shiver = (ctx, x, y, q) ->
  dx = (noise_hash(q.i * 5 + q.ci * 113, ctx.frame_key, ctx.seed) - 0.5) * 2
  dy = (noise_hash(q.i * 5 + q.ci * 113, ctx.frame_key + 3, ctx.seed + 7) - 0.5) * 2
  x + dx * ctx.strength * ctx.m, y + dy * ctx.strength * ctx.m

FIELD_FX.slam = (ctx, x, y, q) ->
  s = 1 + ctx.m * 2
  g = math.exp(-((ctx.prog - 0.3) * 6) ^ 2)
  ring = g * math.sin(math.min(1.2, q.dist / math.max(1, ctx.maxd)) * math.pi * 2 - ctx.prog * 6) * ctx.strength * 0.4
  nx0 = ctx.geo.center.x + (x - ctx.geo.center.x) * s
  ny0 = ctx.geo.center.y + (y - ctx.geo.center.y) * s
  nx0 + q.ux * ring, ny0 + q.uy * ring

FIELD_FX.kickback = (ctx, x, y, q) ->
  dvx, dvy = dir_vector ctx.opts.direction
  recoil = math.sin(math.min(1, ctx.prog / 0.3) * math.pi) * ctx.strength * 0.25
  shoot = math.max(0, (ctx.prog - 0.3) / 0.7) ^ 2 * ctx.strength * 3
  x - dvx * recoil + dvx * shoot, y - dvy * recoil + dvy * shoot

FIELD_FX.g_corrupt = (ctx, x, y, q) ->
  gate = noise_hash(ctx.frame_key, q.ci * 3, ctx.seed) < 0.4
  return x, y unless gate
  dx = (smooth_noise(math.floor(y / 8), ctx.frame_key * 3, ctx.seed) - 0.5) * ctx.strength * 3 * ctx.m
  dy = (noise_hash(q.i, ctx.frame_key, ctx.seed + 3) - 0.5) * ctx.strength * 0.5 * ctx.m
  x + dx, y + dy

FIELD_FX.g_static = (ctx, x, y, q) ->
  band = math.floor q.py * (6 + ctx.freq)
  g = noise_hash(band, ctx.frame_key, ctx.seed)
  return x, y if g <= 0.7
  rag = (noise_hash(q.i, ctx.frame_key, ctx.seed + 5) - 0.5) * ctx.strength * 0.9
  x + (g - 0.85) * ctx.strength * 6 * ctx.m + rag, y + rag * 0.4

FIELD_FX.g_weave = (ctx, x, y, q) ->
  row = math.floor q.py * ctx.freq * 2
  sign = row % 2 == 0 and 1 or -1
  x + sign * ctx.strength * (0.5 + 0.5 * math.sin(ctx.phi)) * ctx.m, y

FIELD_FX.g_spikes = (ctx, x, y, q) ->
  sp = noise_hash(q.i * 7 + q.ci * 113, ctx.frame_key, ctx.seed)
  return x, y if sp <= 0.985
  amp = ctx.strength * (1 + noise_hash(q.i, ctx.frame_key + 1, ctx.seed) * 2) * ctx.m
  x + q.nx * amp, y + q.ny * amp

FIELD_FX.g_dropout = (ctx, x, y, q) ->
  cluster = math.floor q.s * 12
  gate = noise_hash(cluster + q.ci * 7, ctx.frame_key, ctx.seed) < 0.15
  return x, y unless gate
  cc = q.co.centroid
  x + (cc.x - x) * 0.8 * ctx.m, y + (cc.y - y) * 0.8 * ctx.m

FIELD_FX.g_quant = (ctx, x, y, q) ->
  qsize = 2 + (0.5 + 0.5 * math.sin(ctx.phi)) * ctx.strength * ctx.m
  math.floor(x / qsize + 0.5) * qsize, math.floor(y / qsize + 0.5) * qsize

FIELD_FX.g_storm = (ctx, x, y, q) ->
  dx = (noise_hash(q.i, ctx.frame_key, ctx.seed) - 0.5) * ctx.strength * 2 * ctx.m
  dy = (noise_hash(q.i * 3, ctx.frame_key, ctx.seed + 9) - 0.5) * ctx.strength * 2 * ctx.m
  qs = 2
  math.floor((x + dx) / qs + 0.5) * qs, math.floor((y + dy) / qs + 0.5) * qs

SUBPATH_FX = {}

SUBPATH_FX.prefix_parallel = (ctx, q) -> q.s <= ctx.reveal
SUBPATH_FX.prefix_sequential = (ctx, q) -> q.sg <= ctx.reveal
SUBPATH_FX.prefix_chunk = (ctx, q) ->
  chunks = math.max 2, round ctx.freq * ctx.geo.cn
  math.floor(q.sg * chunks) / chunks < ctx.reveal
SUBPATH_FX.prefix_random = (ctx, q) ->
  smooth_noise(q.i * 0.35, q.ci * 3.1, ctx.seed) <= ctx.reveal * 1.02
SUBPATH_FX.prefix_dash = (ctx, q) ->
  ph = q.s * ctx.freq
  ph - math.floor(ph) < ctx.reveal * 1.01
SUBPATH_FX.snake = (ctx, q) ->
  head = ctx.phi / (math.pi * 2)
  d = (q.sg - head) % 1
  d < clamp(ctx.strength / 100, 0.05, 0.9)
SUBPATH_FX.snake_chase = (ctx, q) ->
  head = ctx.phi / (math.pi * 2)
  lf = clamp(ctx.strength / 100, 0.05, 0.45)
  d1 = (q.sg - head) % 1
  d2 = (q.sg + head) % 1
  d1 < lf or d2 < lf
SUBPATH_FX.dash_march = (ctx, q) ->
  ph = q.s * ctx.freq - ctx.phi / (math.pi * 2)
  ph - math.floor(ph) < 0.55
SUBPATH_FX.morse = (ctx, q) ->
  cell = math.floor q.s * ctx.freq * 2
  noise_hash(cell, q.ci * 5 + math.floor(ctx.phi / math.pi), ctx.seed) < 0.62
SUBPATH_FX.seg_flicker = (ctx, q) ->
  cell = math.floor(q.s * 10) + q.ci * 31
  noise_hash(cell, ctx.frame_key, ctx.seed) < 0.82
SUBPATH_FX.path_retract = (ctx, q) ->
  tp = ctx.phi / (math.pi * 2)
  tp = tp - math.floor tp
  duty = 0.12 + 0.76 * (0.5 - 0.5 * math.cos(tp * math.pi * 2))
  d = (q.sg - tp * 2) % 1
  d < duty
SUBPATH_FX.crawl = (ctx, q) ->
  ph = q.sg * ctx.freq - ctx.phi / (math.pi * 2)
  keep = ph - math.floor(ph) < 0.35
  return false unless keep
  w = math.sin(ctx.phi * 2 + q.sg * 40) * ctx.strength
  true, q.nx * w, q.ny * w

apply_dots = (geo, ctx, label) ->
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
      seg_d = co.segs[si]
      t = seg_d > 0 and (d - co.cum[si]) / seg_d or 0
      x = a.x + (b.x - a.x) * t
      y = a.y + (b.y - a.y) * t
      out[#out + 1] = {
        {x: x - r, y: y}
        {x: x, y: y - r}
        {x: x + r, y: y}
        {x: x, y: y + r}
      }
    si = 1
  if #out == 0
    p = geo.contours[1].pts[1]
    out[1] = {{x: p.x, y: p.y}, {x: p.x, y: p.y}}
  guard_shape contours_to_shape(out), label

apply_subpath = (geo, ctx, mode, label = "Subpath shape") ->
  return apply_dots geo, ctx, label if mode == "dot_march"
  fx = SUBPATH_FX[mode]
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
    run = nil
    for i = 1, co.n
      p = co.pts[i]
      q.px = norm_span p.x, bbox.min_x, bbox.max_x
      q.py = norm_span p.y, bbox.min_y, bbox.max_y
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
  guard_shape contours_to_shape(cleaned), label

CONTOUR_FX = {}

contour_local = (ctx, rank) ->
  la = stagger_amount ctx.prog, rank, 0.6
  el = curve_ratio la, ctx.spec.curve
  if ctx.spec.phase == "in" then 1 - el, el else el, el

CONTOUR_FX.c_bob = (ctx, co, ci, rank) ->
  {dy: math.sin(ctx.phi + ci * 0.9) * ctx.strength * 0.6}
CONTOUR_FX.c_sway = (ctx, co, ci, rank) ->
  {rot: math.sin(ctx.phi + ci * 0.9) * ctx.strength * math.pi / 180}
CONTOUR_FX.c_orbit = (ctx, co, ci, rank) ->
  ang = ctx.phi + ci * math.pi * 2 / math.max(1, ctx.geo.cn)
  {dx: math.cos(ang) * ctx.strength * 0.5, dy: math.sin(ang) * ctx.strength * 0.5}
CONTOUR_FX.c_breathe = (ctx, co, ci, rank) ->
  s = 1 + math.sin(ctx.phi + ci * 0.8) * ctx.strength / 100
  {sx: s, sy: s}
CONTOUR_FX.c_wave = (ctx, co, ci, rank) ->
  pos = ctx.phi / (math.pi * 2)
  pos = (pos - math.floor(pos)) * 1.4 - 0.2
  d = rank - pos
  {dy: -math.exp(-(d * 3.5) ^ 2) * ctx.strength}
CONTOUR_FX.c_heart = (ctx, co, ci, rank) ->
  tp = ctx.phi / (math.pi * 2) - rank * 0.12
  tp = tp - math.floor tp
  thump = math.exp(-((tp - 0.12) / 0.06) ^ 2) + 0.65 * math.exp(-((tp - 0.34) / 0.07) ^ 2)
  s = 1 + thump * ctx.strength / 100
  {sx: s, sy: s}
CONTOUR_FX.c_jolt = (ctx, co, ci, rank) ->
  h = noise_hash(ci * 7, ctx.frame_key, ctx.seed)
  return {} if h >= 0.3
  qs = 2
  dx = math.floor(((noise_hash(ci, ctx.frame_key, ctx.seed + 3) - 0.5) * ctx.strength * 2) / qs + 0.5) * qs
  dy = math.floor(((noise_hash(ci, ctx.frame_key, ctx.seed + 9) - 0.5) * ctx.strength) / qs + 0.5) * qs
  {dx: dx, dy: dy}
CONTOUR_FX.c_blink = (ctx, co, ci, rank) ->
  {vis: noise_hash(ci * 13, ctx.frame_key, ctx.seed) > 0.25}
CONTOUR_FX.c_carousel = (ctx, co, ci, rank) ->
  ang0 = math.pi * 2 * rank
  ang = ang0 + ctx.phi
  {dx: (math.cos(ang) - math.cos(ang0)) * ctx.strength, dy: (math.sin(ang) - math.sin(ang0)) * ctx.strength * 0.6}
CONTOUR_FX.c_pop = (ctx, co, ci, rank) ->
  am, el = contour_local ctx, rank
  s = math.max 0.001, ctx.spec.phase == "in" and el or 1 - el
  {sx: s, sy: s}
CONTOUR_FX.c_drop = (ctx, co, ci, rank) ->
  am = contour_local ctx, rank
  h = noise_hash(ci * 3, 7, ctx.seed)
  sign = ctx.spec.phase == "in" and -1 or 1
  {dy: sign * am * ctx.strength * (1 + h * 0.4), rot: sign * am * 0.25 * (h - 0.5)}
CONTOUR_FX.c_slide = (ctx, co, ci, rank) ->
  am = contour_local ctx, rank
  dvx, dvy = dir_vector ctx.opts.direction
  sign = ctx.spec.phase == "in" and -1 or 1
  {dx: sign * dvx * am * ctx.strength, dy: sign * dvy * am * ctx.strength}
CONTOUR_FX.c_spin = (ctx, co, ci, rank) ->
  am = contour_local ctx, rank
  sign = noise_hash(ci * 11, 3, ctx.seed) > 0.5 and 1 or -1
  {rot: am * math.pi * 2 * sign, sx: math.max(0.05, 1 - am * 0.4), sy: math.max(0.05, 1 - am * 0.4)}
CONTOUR_FX.c_scatter = (ctx, co, ci, rank) ->
  am = contour_local ctx, rank
  h = noise_hash(ci * 17, 5, ctx.seed)
  ang = h * math.pi * 2
  {dx: math.cos(ang) * am * ctx.strength, dy: math.sin(ang) * am * ctx.strength, rot: am * 6 * (h - 0.5)}
CONTOUR_FX.c_flip = (ctx, co, ci, rank) ->
  am, el = contour_local ctx, rank
  sx = if ctx.spec.phase == "in" then math.sin(el * math.pi / 2) else math.cos(el * math.pi / 2)
  {sx: math.max(0.02, sx), rot: am * 0.2}
CONTOUR_FX.c_zoom = (ctx, co, ci, rank) ->
  am = contour_local ctx, rank
  s = 1 + am * ctx.strength / 60
  {sx: s, sy: s}
CONTOUR_FX.c_type = (ctx, co, ci, rank) ->
  order = (ci - 1) / math.max(1, ctx.geo.cn)
  visible = if ctx.spec.phase == "in" then order < ctx.prog + GEOMETRY_EPSILON else order < 1 - ctx.prog - GEOMETRY_EPSILON
  {vis: visible}
CONTOUR_FX.c_domino = (ctx, co, ci, rank) ->
  am = contour_local ctx, rank
  dvx, dvy = dir_vector ctx.opts.direction
  sign = (dvx + dvy) >= 0 and 1 or -1
  {rot: am * math.pi / 2 * sign, px: (co.cbox.min_x + co.cbox.max_x) / 2, py: co.cbox.max_y}

apply_contour = (geo, ctx, mode, label = "Contour shape") ->
  fx = CONTOUR_FX[mode]
  return nil, "Unknown contour mode '#{mode}'." unless fx
  out = {}
  for ci, co in ipairs geo.contours
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
    new_pts = {}
    for i = 1, co.n
      p = co.pts[i]
      rx = (p.x - px) * sx
      ry = (p.y - py) * sy
      new_pts[i] = {
        x: px + rx * ca - ry * sa + dx
        y: py + rx * sa + ry * ca + dy
      }
    out[#out + 1] = new_pts
  if #out == 0
    p = geo.contours[1].pts[1]
    out[1] = {{x: p.x, y: p.y}, {x: p.x, y: p.y}}
  guard_shape contours_to_shape(out), label

confetti_sites = (shape, geo) ->
  return nil, "Yutils.shape.to_pixels is not available" unless Yutils and Yutils.shape and Yutils.shape.to_pixels
  ok, pixels = pcall Yutils.shape.to_pixels, shape
  return nil, "Yutils.shape.to_pixels failed: #{pixels}" unless ok and pixels
  solid = {}
  for px in *pixels
    solid[#solid + 1] = px if (px.alpha or 0) >= 96
  solid = pixels if #solid == 0
  return nil, "Confetti effects found no filled pixels in the shape." if #solid == 0
  stride = math.max 1, math.floor #solid / MAX_CONFETTI_SITES
  jitter_pick = stride > 1
  sites = {}
  bbox = geo.bbox
  idx = 1
  while idx <= #solid
    px = solid[idx]
    h1 = noise_hash idx, 3, 51
    sites[#sites + 1] = {
      x: px.x
      y: px.y
      px: norm_span px.x, bbox.min_x, bbox.max_x
      py: norm_span px.y, bbox.min_y, bbox.max_y
      h1: h1
      h2: noise_hash idx, 17, 52
      h3: noise_hash idx, 29, 53
    }
    idx += stride + (jitter_pick and math.floor(h1 * stride * 0.5) or 0)
  sites

CONFETTI_FX = {}

confetti_k = (ctx, rank) ->
  la = stagger_amount ctx.prog, rank, 0.55
  el = curve_ratio la, ctx.spec.curve
  if ctx.spec.phase == "in" then 1 - el else el

CONFETTI_FX.sh_burst = (ctx, s) ->
  k = confetti_k ctx, s.h1 * 0.7
  ux, uy = unit_from_center s.x, s.y, ctx.geo.center
  d = k * k * ctx.strength * (0.6 + s.h2)
  s.x + ux * d, s.y + uy * d, k * math.pi * 2 * (s.h3 - 0.5) * 2, 1, true

CONFETTI_FX.sh_crumble = (ctx, s) ->
  k = confetti_k ctx, (1 - s.py) * 0.6 + s.h1 * 0.4
  floor_y = ctx.geo.bbox.max_y + 4
  ny = math.min s.y + k * k * (floor_y - s.y + 30 + s.h2 * 50), floor_y + (s.h3 - 0.5) * 6
  s.x + (s.h2 - 0.5) * k * 20, ny, k * (s.h1 - 0.5) * 6, 1, true

CONFETTI_FX.sh_sand = (ctx, s) ->
  ax = dir_axis ctx.opts.direction, s.px, s.py
  k = confetti_k ctx, (1 - ax) * 0.7 + s.h1 * 0.3
  dvx, dvy = dir_vector ctx.opts.direction
  d = k * ctx.strength * (1 + s.h2 * 1.2)
  wob = math.sin(k * 6 + s.h3 * 9) * 8 * k
  s.x + dvx * d - dvy * wob, s.y + dvy * d + dvx * wob, k * (s.h1 - 0.5) * 3, 1 - k * 0.3, k < 0.98

CONFETTI_FX.sh_dust = (ctx, s) ->
  k = confetti_k ctx, s.h1
  s.x + math.sin(k * 5 + s.h2 * 7) * ctx.strength * 0.25, s.y - k * ctx.strength * (0.6 + s.h2), k * 4 * (s.h1 - 0.5), 1 - k * 0.4, k < 0.97

CONFETTI_FX.sh_swarm = (ctx, s) ->
  k = confetti_k ctx, s.h1 * 0.5
  ang = s.h2 * math.pi * 2 + k * (3 + s.h3 * 2)
  r = k * ctx.strength * (0.5 + s.h2)
  s.x + math.cos(ang) * r, s.y + math.sin(ang) * r, ang * 0.5, 1, true

CONFETTI_FX.sh_splash = (ctx, s) ->
  k = confetti_k ctx, s.h1 * 0.4
  vx = (s.h2 - 0.5) * 2 * ctx.strength * 1.2
  vy0 = -ctx.strength * (0.8 + s.h3 * 0.8)
  s.x + vx * k, s.y + vy0 * k + ctx.strength * 2.4 * k * k, k * (s.h1 - 0.5) * 5, 1, true

CONFETTI_FX.sh_rain = (ctx, s) ->
  k = confetti_k ctx, s.h1 * 0.6 + s.px * 0.2
  s.x + math.sin(k * 4 + s.h2 * 8) * 10 * k, s.y - k * ctx.strength * (1 + s.h3 * 0.8), k * (s.h2 - 0.5) * 4, 1, true

CONFETTI_FX.sh_ember = (ctx, s) ->
  c = ctx.phi / (math.pi * 2) * (0.5 + s.h1 * 0.8) + s.h2
  c = c - math.floor c
  s.x + math.sin(c * 7 + s.h3 * 9) * ctx.strength * 0.2, s.y - c * ctx.strength, c * 3, 1 - c * 0.5, c < 0.85

CONFETTI_FX.sh_ash = (ctx, s) ->
  k = confetti_k ctx, s.py * 0.7 + s.h1 * 0.3
  sway = octave_noise(k * 2 + s.h2 * 4, s.h3 * 5, 7, 2) * ctx.strength * 0.8
  s.x + sway * k, s.y + k * k * ctx.strength * (0.8 + s.h1), k * (s.h2 - 0.5) * 4, 1 - k * 0.3, k < 0.98

confetti_piece_shape = (ctx, sites, piece, pieces, mode, size_base) ->
  fx = CONFETTI_FX[mode]
  return nil, "Unknown confetti mode '#{mode}'." unless fx
  out = {}
  for idx, s in ipairs sites
    continue unless (idx - 1) % pieces + 1 == piece
    x, y, rot, scale, vis = fx ctx, s
    continue if vis == false
    r = size_base * (0.7 + s.h3 * 0.6) * math.max(0.05, scale or 1)
    ca, sa = math.cos(rot or 0), math.sin(rot or 0)
    quad = {}
    corners = {{-r, 0}, {0, -r}, {r, 0}, {0, r}}
    for c in *corners
      quad[#quad + 1] = {x: x + c[1] * ca - c[2] * sa, y: y + c[1] * sa + c[2] * ca}
    out[#out + 1] = quad
  if #out == 0
    s = sites[1]
    out[1] = {{x: s.x, y: s.y}, {x: s.x, y: s.y}}
  guard_shape contours_to_shape(out), "#{mode} confetti"

SHAPE_TARGET_BUILDERS = {}

SHAPE_TARGET_BUILDERS.blob = (src, co_meta, ci, opts) ->
  n = #src
  centroid = contour_centroid src
  _, len = contour_metrics src
  r = math.max 2, len / (math.pi * 2)
  sign = signed_area(src) >= 0 and 1 or -1
  ang0 = math.atan2 src[1].y - centroid.y, src[1].x - centroid.x
  out = {}
  for k = 0, n - 1
    ang = ang0 + sign * math.pi * 2 * k / n
    out[k + 1] = {x: centroid.x + math.cos(ang) * r, y: centroid.y + math.sin(ang) * r}
  out

SHAPE_TARGET_BUILDERS.line = (src, co_meta, ci, opts) ->
  n = #src
  centroid = contour_centroid src
  _, len = contour_metrics src
  half = math.max 2, len * 0.25
  out = {}
  for k = 0, n - 1
    t = k / n
    u = t < 0.5 and t * 2 or 2 - t * 2
    side = t < 0.5 and -0.6 or 0.6
    out[k + 1] = {x: centroid.x + (u - 0.5) * half * 2, y: centroid.y + side}
  out

SHAPE_TARGET_BUILDERS.star = (src, co_meta, ci, opts) ->
  n = #src
  centroid = contour_centroid src
  _, len = contour_metrics src
  rb = math.max 2, len / (math.pi * 2)
  spikes = math.max 3, round opts.frequency
  sign = signed_area(src) >= 0 and 1 or -1
  ang0 = math.atan2 src[1].y - centroid.y, src[1].x - centroid.x
  out = {}
  for k = 0, n - 1
    ang = ang0 + sign * math.pi * 2 * k / n
    r = rb * (0.45 + 1.15 * math.max(0, math.cos(spikes * (ang - ang0))) ^ 1.6)
    out[k + 1] = {x: centroid.x + math.cos(ang) * r, y: centroid.y + math.sin(ang) * r}
  out

SHAPE_TARGET_BUILDERS.scribble = (src, co_meta, ci, opts) ->
  n = #src
  centroid = contour_centroid src
  cbox = contour_bbox src
  w = math.max 6, cbox.width
  h = math.max 6, cbox.height
  out = {}
  for k = 0, n - 1
    out[k + 1] = {
      x: centroid.x + (smooth_noise(k * 0.11, ci * 3.3, opts.seed) - 0.5) * w * 2.2
      y: centroid.y + (smooth_noise(k * 0.11 + 50, ci * 3.3 + 9, opts.seed) - 0.5) * h * 2.2
    }
  out

shape_morph_pair = (shape, opts, mode) ->
  builder = SHAPE_TARGET_BUILDERS[mode]
  return nil, nil, "Unknown shape morph mode '#{mode}'." unless builder
  flat, err = flatten_shape shape, "Shape morph source"
  return nil, nil, err unless flat
  contours = parse_contours flat
  return nil, nil, "Shape morph source has no contours." if #contours == 0
  seg_len = math.max MORPH_SAFE_SPLIT, finite_number(opts.split_len) or MORPH_SAFE_SPLIT
  desired = {}
  for ci, contour in ipairs contours
    _, len = contour_metrics contour
    desired[ci] = round clamp len / seg_len, MIN_MORPH_POINTS, MAX_MORPH_POINTS
  counts, allocation_err = allocate_contour_counts desired, MAX_POINTS_PER_SHAPE, "Shape morph"
  return nil, nil, allocation_err unless counts
  out_src, out_tgt = {}, {}
  for ci, contour in ipairs contours
    count = counts[ci]
    sampled = resample_contour contour, count
    return nil, nil, "Shape morph resampling failed for contour #{ci}." unless sampled
    out_src[ci] = sampled
    out_tgt[ci] = builder sampled, nil, ci, opts
  src_shape, err = guard_shape contours_to_shape(out_src), "Shape morph source after resample"
  return nil, nil, err unless src_shape
  tgt_shape, err = guard_shape contours_to_shape(out_tgt), "Shape morph target"
  return nil, nil, err unless tgt_shape
  src_shape, tgt_shape

export collect_initial_tag_blocks = (text) ->
  text = tostring(text or "")
  blocks, pos = {}, 1
  while text\sub(pos, pos) == "{"
    close_pos = text\find("}", pos, true)
    break unless close_pos
    block = text\sub(pos + 1, close_pos - 1)
    blocks[#blocks + 1] = block if block\match "^%s*\\"
    pos = close_pos + 1
  table.concat blocks, ""

strip_initial_tags = (text, drop_placement = false) ->
  body = collect_initial_tag_blocks text
  wrapped = "{" .. body .. "}"
  wrapped = LineOps.removeTagCalls wrapped, {"fn", "fsp", "fscx", "fscy", "fs", "b", "i", "u", "s", "p", "k", "K", "kf", "ko"}
  wrapped = LineOps.removeTagCalls(wrapped, {"an", "pos", "move"}) if drop_placement
  wrapped\match("^%{(.*)%}$") or ""

export alpha_tag = (alpha) ->
  "\\alpha&H%02X&"\format round clamp(alpha, 0, 255)

drawing_text = (source_text, shape, extra_tags = "", placement_tags = "") ->
  placement_tags = placement_tags or ""
  tags = strip_initial_tags source_text, placement_tags != ""
  "{#{tags}#{placement_tags}#{extra_tags}\\fscx100\\fscy100\\p1}#{clean_shape shape}{\\p0}"

visible_text = (text) -> LineOps.visibleText text

export tag_bool = (value) ->
  return false if value == nil or value == false
  return value != 0 if type(value) == "number"
  tostring(value) != "0"

export raw_num_tag = (tag_block, name, default_value) ->
  value = LineOps.tagNumber tag_block, name, default_value, true
  finite_number(value) or default_value

export raw_bool_tag = (tag_block, name, default_value) ->
  value, call = LineOps.tagNumber tag_block, name, nil, true
  return default_value unless call and finite_number(value) != nil
  tag_bool finite_number(value)

export raw_font_tag = (tag_block, default_value) ->
  call = LineOps.lastTagCall tag_block, "fn", true
  value = trim(call and call.value or "")
  if value == "" then default_value else value

export style_number = (style, field, default_value) ->
  finite_number(style and style[field]) or default_value

export style_bool = (style, field, default_value) ->
  value = style and style[field]
  return default_value if value == nil
  tag_bool value

style_from_line = (source) ->
  style = source.styleRef or source.styleref or source.style_ref
  if not style and source.parentCollection and source.parentCollection.styles
    style = source.parentCollection.styles[source.style]
  tag_block = "{" .. collect_initial_tag_blocks(source.text) .. "}"
  {
    fontname: raw_font_tag tag_block, tostring(style and style.fontname or "Arial")
    bold: raw_bool_tag tag_block, "b", style_bool(style, "bold", false)
    italic: raw_bool_tag tag_block, "i", style_bool(style, "italic", false)
    underline: raw_bool_tag tag_block, "u", style_bool(style, "underline", false)
    strikeout: raw_bool_tag tag_block, "s", style_bool(style, "strikeout", false)
    fontsize: raw_num_tag tag_block, "fs", style_number(style, "fontsize", 40)
    scale_x: raw_num_tag tag_block, "fscx", style_number(style, "scale_x", 100)
    scale_y: raw_num_tag tag_block, "fscy", style_number(style, "scale_y", 100)
    spacing: raw_num_tag tag_block, "fsp", style_number(style, "spacing", 0)
  }

TEXT_STYLE_TAGS = {"fn", "fs", "fscx", "fscy", "fsp", "b", "i", "u", "s"}

uniform_text_style_error = (text) ->
  visible_started = false
  for section in *LineOps.scanSections text
    if section.type == "override"
      wrapped = "{#{section.text}}"
      return "Style resets (\\r) are not supported while converting text to one shape; split the line into uniform runs first." if LineOps.hasTag wrapped, "r", false
      for call in *LineOps.tagCalls wrapped, TEXT_STYLE_TAGS
        return "Animated typography is not supported while converting text to one shape; remove typography changes inside \\t first." unless call.top_level
        return "Inline typography changes are not supported while converting text to one shape; split the line into uniform runs first." if visible_started
    elseif section.type == "text"
      plain = tostring(section.text or "")\gsub "\\[Nnh]", ""
      visible_started = true if plain != ""
  nil

text_to_shape = (text, style, fontname = nil) ->
  text = tostring(text or "")
  style = style or {}
  char_count = utf8_len text
  return nil, "Text is too long for path conversion (#{char_count} characters; max #{MAX_TEXT_CHARS}). Apply #{script_name} to shorter selected text or convert smaller chunks." if char_count > MAX_TEXT_CHARS
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
  guard_shape shape, "Text shape"

drawing_scale_value = (section) ->
  ok, result = pcall ->
    scale_tag = section.scale
    return 1 unless scale_tag
    if type(scale_tag) == "table"
      if scale_tag.get
        scale_tag\get!
      else
        scale_tag.value
    else
      scale_tag
  value = ok and finite_number(result) or nil
  return 1 unless value and value >= 1
  math.floor value

scale_shape = (shape, factor_x, factor_y) ->
  return shape if factor_x == 1 and factor_y == 1
  result, is_x = {}, true
  for token in tostring(shape or "")\gmatch "%S+"
    value = finite_number token
    if value
      if is_x
        result[#result + 1] = fmt_num value * factor_x
      else
        result[#result + 1] = fmt_num value * factor_y
      is_x = not is_x
    else
      result[#result + 1] = token
  table.concat result, " "

source_info = (source, opts) ->
  ok_parse, data = pcall -> ASS\parse source
  return nil, "ASS parse failed: #{data}" unless ok_parse and data
  return nil, "ASS parser did not return section accessors." unless data.getSectionCount and data.callback
  info = {kind: nil, shape: nil, text: "", style: nil, data: data}
  ok_count, drawing_count = pcall -> data\getSectionCount ASS.Section.Drawing
  return nil, "ASS drawing section detection failed: #{drawing_count}" unless ok_count
  drawing_count = tonumber(drawing_count) or 0
  ok_text_count, text_count = pcall -> data\getSectionCount ASS.Section.Text
  return nil, "ASS text section detection failed: #{text_count}" unless ok_text_count
  text_count = tonumber(text_count) or 0
  visible_source = visible_text source.text
  style_err = uniform_text_style_error source.text
  return nil, style_err if style_err
  if drawing_count > 0 and text_count > 0 and visible_source != ""
    return nil, "Mixed drawing and visible text runs are not supported; split them into separate lines first."
  if drawing_count > 0
    sections = {}
    ok_callback, callback_err = pcall ->
      data\callback ((section) ->
        sections[#sections + 1] = section
        true), ASS.Section.Drawing
    return nil, "ASS drawing extraction failed: #{callback_err}" unless ok_callback
    return nil, "ASS drawing extraction failed: no drawing section captured." if #sections == 0
    return nil, "Line has #{#sections} drawing sections; #{script_name} supports exactly one drawing per line." if #sections > 1
    raw_shape = nil
    ok_string, string_err = pcall -> raw_shape = clean_shape sections[1]\toString!
    return nil, "ASS drawing extraction failed: #{string_err}" unless ok_string
    p_scale = drawing_scale_value sections[1]
    info.style = style_from_line source
    factor = 2 ^ (p_scale - 1)
    shape = scale_shape raw_shape, (info.style.scale_x / 100) / factor, (info.style.scale_y / 100) / factor
    info.shape, err = guard_shape shape, "Drawing shape"
    return nil, err unless info.shape
    info.kind = "drawing"
    return info
  if text_count > 0
    info.text = visible_source
    return nil, "Text line has no visible text." if info.text == ""
    info.style = style_from_line source
    shape, err = text_to_shape info.text, info.style
    return nil, err unless shape and shape != ""
    info.shape = shape
    info.kind = "text"
    return info
  nil, "Line has neither text nor drawing."

target_shape_for = (info, opts) ->
  return nil, "Font morph requires text input." unless info.kind == "text"
  return nil, "Target font is empty." if trim(opts.target_font) == ""
  text_to_shape info.text, info.style, opts.target_font

extract_pos = (text) ->
  x, y, call = LineOps.tagPair text, "pos", nil, nil, true
  return nil unless call and x != nil and y != nil
  finite_number(x), finite_number(y)

export has_move = (text) -> LineOps.hasTag text, "move", true

extract_move = (text) ->
  args, call = LineOps.tagArguments text, "move", true
  return nil unless call
  values = {}
  for token in *args
    value = finite_number token
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

move_position_at = (move, rel_time, source_duration) ->
  return nil unless move
  rel_time = finite_number(rel_time) or 0
  source_duration = math.max 1, finite_number(source_duration) or 1
  t1 = finite_number(move.t1) or 0
  t2 = finite_number(move.t2) or source_duration
  if t2 <= t1
    return move.x1, move.y1 if rel_time < t1
    return move.x2, move.y2
  return move.x1, move.y1 if rel_time <= t1
  return move.x2, move.y2 if rel_time >= t2
  ratio = (rel_time - t1) / (t2 - t1)
  move.x1 + (move.x2 - move.x1) * ratio, move.y1 + (move.y2 - move.y1) * ratio

export format_pos_tag = (x, y) ->
  "\\pos(#{fmt_num x},#{fmt_num y})"

export format_move_tag = (x1, y1, x2, y2, t1 = nil, t2 = nil) ->
  if t1 != nil and t2 != nil
    return "\\move(#{fmt_num x1},#{fmt_num y1},#{fmt_num x2},#{fmt_num y2},#{round t1},#{round t2})"
  "\\move(#{fmt_num x1},#{fmt_num y1},#{fmt_num x2},#{fmt_num y2})"

tracking_active = (opts) ->
  opts and opts.motion_mode == "Bake AE position data" and trim(opts.tracking_data) != ""

parse_tracking_points = (text) ->
  text = tostring(text or "")
  points = {}
  has_header = text\match "[\r\n]Position[\r\n]" or text\match "[\r\n]Anchor Point[\r\n]" or text\match "^Position[\r\n]" or text\match "^Anchor Point[\r\n]"
  collecting = not has_header
  for raw in text\gmatch "[^\r\n]+"
    line = trim raw
    if line == "Position" or line == "Anchor Point"
      collecting = true
      continue
    if line\match "End of Keyframe Data"
      break
    continue unless collecting
    continue if not has_header and line\match "%a"
    nums = {}
    for token in line\gmatch "[%+%-]?%d+%.?%d*"
      nums[#nums + 1] = finite_number token
    if #nums >= 3
      points[#points + 1] = {frame: nums[1], x: nums[#nums - 1], y: nums[#nums]}
    elseif #nums == 2
      points[#points + 1] = {x: nums[1], y: nums[2]}
  return nil, "Tracking data has no usable Position/Anchor Point rows." if #points == 0
  frame_rows = 0
  for point in *points
    frame_rows += 1 if point.frame != nil
  if frame_rows > 0
    return nil, "Tracking data mixes rows with and without frame numbers. Paste dense Position rows or run Aegisub-Motion first." if frame_rows != #points
    for i = 2, #points
      expected = points[i - 1].frame + 1
      unless math.abs(points[i].frame - expected) < GEOMETRY_EPSILON
        return nil, "Tracking data has non-contiguous frame rows at #{points[i - 1].frame} -> #{points[i] and points[i].frame or "?"}. Run Aegisub-Motion FBF first or paste dense per-frame Position rows."
  points

tracking_points_for = (opts) ->
  return nil unless tracking_active opts
  return opts._tracking_points if opts._tracking_points
  points, err = parse_tracking_points opts.tracking_data
  return nil, err unless points
  opts._tracking_points = points
  points

tracking_sample_index = (source, abs_time, points) ->
  abs_time = finite_number(abs_time) or finite_number(source.start_time) or 0
  if aegisub and aegisub.frame_from_ms
    ok1, frame = pcall aegisub.frame_from_ms, abs_time
    ok2, start_frame = pcall aegisub.frame_from_ms, finite_number(source.start_time) or 0
    if ok1 and ok2 and frame and start_frame
      return round(frame - start_frame + 1)
  duration = math.max 1, (finite_number(source.end_time) or abs_time + 1) - (finite_number(source.start_time) or 0)
  progress = clamp (abs_time - (finite_number(source.start_time) or 0)) / duration, 0, 1
  round(progress * math.max(0, #points - 1)) + 1

tracking_offset_at = (source, abs_time, opts) ->
  points, err = tracking_points_for opts
  return nil, nil, err unless points
  ref = round clamp opts.tracking_ref_frame or 1, 1, #points
  index = round clamp tracking_sample_index(source, abs_time, points), 1, #points
  points[index].x - points[ref].x, points[index].y - points[ref].y

motion_point = (source, anchor, rel_time, abs_time, dx, dy, opts) ->
  source_start = finite_number(source.start_time) or 0
  source_duration = math.max 1, (finite_number(source.end_time) or source_start + 1) - source_start
  local x, y
  if anchor.kind == "move"
    x, y = move_position_at anchor.move, rel_time, source_duration
  else
    x, y = anchor.x, anchor.y
  x += dx or 0
  y += dy or 0
  if tracking_active opts
    ox, oy, err = tracking_offset_at source, abs_time, opts
    return nil, nil, err unless ox
    x += ox
    y += oy
  x, y

motion_tag_for = (source, anchor, dx, dy, line_start, line_end, opts) ->
  source_start = finite_number(source.start_time) or 0
  line_start = finite_number(line_start) or source_start
  line_end = finite_number(line_end) or finite_number(source.end_time) or line_start + 1
  line_end = line_start + 1 if line_end <= line_start
  rel_start = line_start - source_start
  rel_end = line_end - source_start
  sample_end = math.max line_start, line_end - 1
  x1, y1, err = motion_point source, anchor, rel_start, line_start, dx, dy, opts
  return nil, nil, err unless x1
  x2, y2, err = motion_point source, anchor, rel_end, sample_end, dx, dy, opts
  return nil, nil, err unless x2
  moving = not same_point x1, y1, x2, y2
  return format_pos_tag(x1, y1), false if not moving
  if anchor.kind == "move" and anchor.move.t1 and anchor.move.t2 and not tracking_active(opts)
    seg_duration = line_end - line_start
    active_start = clamp anchor.move.t1 - rel_start, 0, seg_duration
    active_end = clamp anchor.move.t2 - rel_start, 0, seg_duration
    if active_end > active_start
      ax1, ay1 = move_position_at anchor.move, rel_start + active_start, (finite_number(source.end_time) or source_start + 1) - source_start
      ax2, ay2 = move_position_at anchor.move, rel_start + active_end, (finite_number(source.end_time) or source_start + 1) - source_start
      return format_move_tag(ax1 + dx, ay1 + dy, ax2 + dx, ay2 + dy, active_start, active_end), true
  format_move_tag(x1, y1, x2, y2), true

effective_align = (source) ->
  found = nil
  for value in tostring(source.text or "")\gmatch "\\an([1-9])%f[^%d]"
    found = finite_number value
  unless found
    style = source.styleRef or source.styleref or source.style_ref
    if not style and source.parentCollection and source.parentCollection.styles
      style = source.parentCollection.styles[source.style]
    found = finite_number(style and style.align)
  found or 2

align_to_top_left_offset = (align, bbox) ->
  align = round clamp align, 1, 9
  col = ((align - 1) % 3) + 1
  row = math.floor((align - 1) / 3) + 1
  dx = if col == 1 then 0 elseif col == 2 then -bbox.width / 2 else -bbox.width
  dy = if row == 1 then -bbox.height elseif row == 2 then -bbox.height / 2 else 0
  dx, dy

line_default_position = (source) ->
  return nil unless source and source.getDefaultPosition
  ok, x, y = pcall -> source\getDefaultPosition!
  return nil unless ok
  x, y = finite_number(x), finite_number(y)
  return nil unless x and y
  x, y

export has_org = (text) ->
  text = tostring(text or "")
  text\match("\\org%(") != nil

export has_origin_sensitive_tags = (text) ->
  text = tostring(text or "")
  text\match("\\fr[xyz][%-%d%.]+") != nil or text\match("\\fa[xy][%-%d%.]+") != nil

origin_tag_for = (source, anchor_x, anchor_y, moving = false) ->
  return "" if has_org source.text
  return "" unless has_origin_sensitive_tags source.text
  if moving
    return nil, "Text line uses \\move with rotation/shear and no explicit \\org; add \\org before running #{script_name} so the transform origin can be preserved."
  "\\org(#{fmt_num anchor_x},#{fmt_num anchor_y})"

anchor_position = (source) ->
  x, y = extract_pos source.text
  return {kind: "pos", x: x, y: y} if x and y
  move, err = extract_move source.text
  return nil, err if err
  return {kind: "move", move: move} if move
  x, y = line_default_position source
  return {kind: "pos", x: x, y: y, default_position: true} if x and y
  nil, "Could not resolve original line position. Use explicit \\pos or run with a LineCollection that exposes PlayRes/style margins."

placement_tags_for = (source, shape, line_start = nil, line_end = nil, opts = nil) ->
  align = effective_align source
  move, move_err = extract_move source.text
  return nil, move_err if move_err
  needs_rewrite = move or tracking_active(opts) or align != 7
  return "" unless needs_rewrite
  bbox = shape_bbox shape
  return nil, "Could not read generated shape bounds for alignment compensation." if align != 7 and not bbox
  dx, dy = 0, 0
  dx, dy = align_to_top_left_offset align, bbox if align != 7
  anchor, err = anchor_position source
  return nil, err unless anchor
  if anchor.kind == "move" or tracking_active(opts)
    tag, moving, tag_err = motion_tag_for source, anchor, dx, dy, line_start, line_end, opts
    return nil, tag_err unless tag
    org, org_err = origin_tag_for source, anchor.kind == "move" and anchor.move.x1 or anchor.x, anchor.kind == "move" and anchor.move.y1 or anchor.y, moving
    return nil, org_err unless org
    return "\\an7#{tag}#{org}" if align != 7
    return "#{tag}#{org}"
  if align == 7
    return ""
  org, org_err = origin_tag_for source, anchor.x, anchor.y, false
  return nil, org_err unless org
  "\\an7\\pos(#{fmt_num(anchor.x + dx)},#{fmt_num(anchor.y + dy)})#{org}"

clear_a_mo_extra = (line) ->
  if line and line.extra
    line.extra["a-mo"] = nil
  line

export same_merge_value = (a, b) ->
  tostring(a or "") == tostring(b or "")

export can_merge_generated_lines = (last, line) ->
  return false unless last and line
  return false unless same_merge_value last.text, line.text
  return false unless same_merge_value last.style, line.style
  return false unless same_merge_value last.layer, line.layer
  return false unless finite_number(last.end_time) and finite_number(line.start_time)
  finite_number(last.end_time) == finite_number(line.start_time)

compress_contiguous_lines = (lines) ->
  result = {}
  for line in *(lines or {})
    merged = false
    for i = #result, 1, -1
      if can_merge_generated_lines result[i], line
        result[i].end_time = line.end_time
        merged = true
        break
    unless merged
      result[#result + 1] = line
  result

clone_options = (opts) ->
  copy = {}
  for key, value in pairs opts or {}
    copy[key] = value
  copy

export line_extra_value = (line, key) ->
  return nil unless line
  if line.extra and line.extra[key] != nil
    return line.extra[key]
  if line.getExtraData
    ok, value = pcall -> line\getExtraData key
    return value if ok and value != nil
  nil

a_mo_uuid = (line) ->
  extra = line_extra_value line, "a-mo"
  return nil unless extra
  if type(extra) == "table"
    return tostring(extra.uuid) if extra.uuid
  text = tostring(extra)
  uuid = text\match '"uuid"%s*:%s*"([^"]+)"'
  uuid or= text\match "'uuid'%s*:%s*'([^']+)'"
  uuid or "__a-mo:" .. text

frame_contexts_for_selection = (sub, sorted_sel, collection) ->
  groups, order = {}, {}
  for index in *sorted_sel
    line = safe_line sub[index], collection, "Selected line #{index}"
    continue unless line
    uuid = a_mo_uuid line
    continue unless uuid
    group = groups[uuid]
    unless group
      group = {uuid: uuid, items: {}, total_frames: 0}
      groups[uuid] = group
      order[#order + 1] = group
    count = line_frame_count line
    group.items[#group.items + 1] = {index: index, count: count, duration: line_duration_ms line}
    group.total_frames += count
  contexts = {}
  for group in *order
    continue unless group.total_frames > 1
    offset = 0
    time_offset = 0
    for item in *group.items
      contexts[item.index] = {frame_offset: offset, total_frames: group.total_frames, time_offset: time_offset, a_mo_uuid: group.uuid}
      offset += item.count
      time_offset += item.duration
  contexts

contour_ranks = (geo, direction) ->
  cn = geo.cn
  ranks = {}
  return ranks if cn == 0
  if cn == 1
    ranks[1] = 0
    return ranks
  order = {}
  for ci, co in ipairs geo.contours
    px = norm_span co.centroid.x, geo.bbox.min_x, geo.bbox.max_x
    py = norm_span co.centroid.y, geo.bbox.min_y, geo.bbox.max_y
    order[#order + 1] = {ci: ci, axis: dir_axis direction, px, py}
  table.sort order, (a, b) -> a.axis < b.axis
  for pos, entry in ipairs order
    ranks[entry.ci] = (pos - 1) / (cn - 1)
  ranks

make_ctx = (geo, opts, slice, spec) ->
  ctx = build_ctx geo, opts, slice, spec
  ctx.ranks = contour_ranks geo, opts.direction
  ctx

new_line = (source, collection, shape, opts, marker, start_time = nil, end_time = nil, extra_tags = "", layer_delta = 0, info = nil, placement_shape = nil) ->
  line, err = safe_line source, collection, "Generated line base"
  return nil, err unless line
  clear_a_mo_extra line
  placement_tags = ""
  if info and (info.kind == "text" or has_move(source.text) or tracking_active(opts))
    placement_tags, err = placement_tags_for source, placement_shape or shape, start_time, end_time, opts
    return nil, err unless placement_tags != nil
  line.start_time = start_time if start_time
  line.end_time = end_time if end_time
  line.layer = (finite_number(source.layer) or 0) + layer_delta
  line.comment = false
  line.effect = "[#{script_name} - #{opts.effect}]#{marker}"
  line.text = drawing_text source.text, shape, extra_tags, placement_tags
  line

slice_marker = (slice, prefix = "") ->
  if slice.mode == "frame" then "[#{prefix}f#{slice.index}/#{slice.total}]" else "[#{prefix}m#{slice.index}/#{slice.total}]"

moment_outputs = (source, collection, info, opts) ->
  spec = effect_spec opts.effect
  slices, err = temporal_slices source, opts
  return nil, err unless slices
  local base_shape, target_shape, target_nums, geo
  if spec.kind == "morph"
    target_shape, err = target_shape_for info, opts
    return nil, err unless target_shape
    base_shape, target_shape, err = normalize_pair info.shape, target_shape, opts
    return nil, err unless base_shape and target_shape
    target_nums = collect_numbers target_shape
  elseif spec.kind == "shape_morph"
    base_shape, target_shape, err = shape_morph_pair info.shape, opts, spec.mode
    return nil, err unless base_shape and target_shape
    target_nums = collect_numbers target_shape
    geo, err = prep_geo info.shape, opts, "Shape morph base"
    return nil, err unless geo
  else
    geo, err = prep_geo info.shape, opts, "Moment base shape"
    return nil, err unless geo
    base_shape = info.shape
  lines = {}
  for slice in *slices
    local shape
    if spec.kind == "morph"
      morph_ratio = if spec.elastic then curve_ratio(slice.progress, "overshoot") else curve_ratio(slice.ratio, spec.curve or "linear")
      shape, err = lerp_shape base_shape, target_shape, morph_ratio, target_nums
      return nil, err unless shape
      if spec.curve == "glitch" or spec.curve == "rubber"
        post_geo, post_err = prep_geo shape, opts, "Morph post shape"
        return nil, post_err unless post_geo
        post_mode = spec.curve == "glitch" and "g_corrupt" or "gelatin"
        post_ctx = make_ctx post_geo, opts, slice, {curve: "linear"}
        shape, err = apply_field post_geo, post_ctx, post_mode, "Morph post shape"
        return nil, err unless shape
    elseif spec.kind == "shape_morph"
      ctx = make_ctx geo, opts, slice, spec
      r = if spec.phase then ctx.m else 0.55 * (0.5 - 0.5 * math.cos(ctx.phi))
      shape, err = lerp_shape base_shape, target_shape, r, target_nums
      return nil, err unless shape
    elseif spec.kind == "subpath"
      ctx = make_ctx geo, opts, slice, spec
      shape, err = apply_subpath geo, ctx, spec.mode, "#{spec.mode} shape"
      return nil, err unless shape
    elseif spec.kind == "contour"
      ctx = make_ctx geo, opts, slice, spec
      shape, err = apply_contour geo, ctx, spec.mode, "#{spec.mode} shape"
      return nil, err unless shape
    else
      ctx = make_ctx geo, opts, slice, spec
      shape, err = apply_field geo, ctx, spec.mode, "#{spec.mode} shape"
      return nil, err unless shape
    line, err = new_line source, collection, shape, opts, slice_marker(slice), slice.start_time, slice.end_time, "", 0, info, base_shape
    return nil, err unless line
    lines[#lines + 1] = line
  compress_contiguous_lines lines

SKETCH_FIELD_MODES = {pencil: "handwriting", scribble: "boil"}

layer_deform_outputs = (source, collection, info, opts) ->
  spec = effect_spec opts.effect
  slices, err = temporal_slices source, opts
  return nil, err unless slices
  geo, err = prep_geo info.shape, opts, "Sketch base shape"
  return nil, err unless geo
  field_mode = SKETCH_FIELD_MODES[spec.mode] or "handwriting"
  lines = {}
  for slice in *slices
    for i = 1, opts.layers
      ctx = make_ctx geo, opts, slice, spec
      ctx.seed = opts.seed + i * 101
      ctx.m = 1
      shape, err = apply_field geo, ctx, field_mode, "Sketch pass shape"
      return nil, err unless shape
      extra = "\\blur#{fmt_num(opts.blur)}#{alpha_tag math.floor(opts.alpha * 0.75)}"
      line, err = new_line source, collection, shape, opts, slice_marker(slice, "pass#{i} "), slice.start_time, slice.end_time, extra, i - 1, info, info.shape
      return nil, err unless line
      lines[#lines + 1] = line
  compress_contiguous_lines lines

confetti_outputs = (source, collection, info, opts) ->
  spec = effect_spec opts.effect
  slices, err = temporal_slices source, opts
  return nil, err unless slices
  geo, err = prep_geo info.shape, opts, "Confetti base shape"
  return nil, err unless geo
  sites, err = confetti_sites info.shape, geo
  return nil, err unless sites
  pieces = math.max 1, math.min opts.layers, math.floor(MAX_OUTPUT_LINES / math.max(1, #slices))
  size_base = math.max 1.5, opts.split_len * 0.9
  extra = opts.alpha > 0 and alpha_tag(opts.alpha) or ""
  lines = {}
  for slice in *slices
    ctx = make_ctx geo, opts, slice, spec
    for piece = 1, pieces
      shape, err = confetti_piece_shape ctx, sites, piece, pieces, spec.mode, size_base
      return nil, err unless shape
      line, err = new_line source, collection, shape, opts, slice_marker(slice, "piece#{piece} "), slice.start_time, slice.end_time, extra, piece - 1, info, info.shape
      return nil, err unless line
      lines[#lines + 1] = line
  compress_contiguous_lines lines

pair_morph_outputs = (source, target, collection, opts) ->
  src_info, err = source_info source, opts
  return nil, err unless src_info
  tgt_info, err = source_info target, opts
  return nil, err unless tgt_info
  base_shape, target_shape, err = normalize_pair src_info.shape, tgt_info.shape, opts
  return nil, err unless base_shape and target_shape
  target_nums = collect_numbers target_shape
  spec = effect_spec opts.effect
  source_copy = {}
  source_copy[key] = value for key, value in pairs source
  timed_source, err = safe_line source_copy, collection, "Pair morph timing source"
  return nil, err unless timed_source
  source_start = finite_number(source.start_time) or 0
  target_start = finite_number(target.start_time) or source_start
  source_end = finite_number(source.end_time) or source_start + 1
  target_end = finite_number(target.end_time) or source_end
  timed_source.start_time = math.min source_start, target_start
  timed_source.end_time = math.max source_end, target_end
  slices, err = temporal_slices timed_source, opts
  return nil, err unless slices
  lines = {}
  for slice in *slices
    morph_ratio = if spec.elastic then curve_ratio(slice.progress, "overshoot") else curve_ratio(slice.ratio, spec.curve or "linear")
    shape, err = lerp_shape base_shape, target_shape, morph_ratio, target_nums
    return nil, err unless shape
    line, err = new_line timed_source, collection, shape, opts, slice_marker(slice, "pair "), slice.start_time, slice.end_time, "", 0, src_info, base_shape
    return nil, err unless line
    lines[#lines + 1] = line
  compress_contiguous_lines lines

outputs_for = (source, collection, opts) ->
  info, err = source_info source, opts
  return nil, err unless info
  spec = effect_spec opts.effect
  lines = nil
  if spec.kind == "layer_deform"
    lines, err = layer_deform_outputs source, collection, info, opts
  elseif spec.kind == "confetti"
    lines, err = confetti_outputs source, collection, info, opts
  else
    lines, err = moment_outputs source, collection, info, opts
  return nil, err unless lines
  lines

safe_outputs_for = (source, collection, opts) ->
  ok, lines, err = pcall -> outputs_for source, collection, opts
  return nil, "#{script_name} failed while generating output: #{lines}" unless ok
  lines, err

safe_pair_morph_outputs = (source, target, collection, opts) ->
  ok, lines, err = pcall -> pair_morph_outputs source, target, collection, opts
  return nil, "#{script_name} failed while generating pair morph output: #{lines}" unless ok
  lines, err

estimated_output_count = (opts) ->
  spec = effect_spec opts.effect
  if spec.kind == "confetti" or spec.kind == "layer_deform"
    opts.moments * opts.layers
  else
    opts.moments

validate = (sub, sel) ->
  return false unless sub and sel and #sel >= 1
  for index in *sel
    line = sub[index]
    return false unless line and line.class == "dialogue" and not line.comment
  true

run_with_options = (sub, sel, opts) ->
  return unless opts
  sorted_sel, err = sorted_selection sel
  return window_error err unless sorted_sel
  spec = effect_spec opts.effect
  estimated_total = if spec.kind == "pair_morph" then estimated_output_count(opts) else #sorted_sel * estimated_output_count(opts)
  return unless confirm_large_output estimated_total, "the estimated run"
  return window_error "Subtitle object has no insert method." unless sub and sub.insert
  collection, err = safe_collection sub, sorted_sel
  return window_error err unless collection
  frame_contexts = frame_contexts_for_selection sub, sorted_sel, collection
  if spec.kind == "pair_morph"
    return window_error "#{opts.effect} needs exactly two selected dialogue lines: source first, target second." unless #sorted_sel == 2
    source, err = safe_line sub[sorted_sel[1]], collection, "Source line #{sorted_sel[1]}"
    return window_error err unless source
    target, err = safe_line sub[sorted_sel[2]], collection, "Target line #{sorted_sel[2]}"
    return window_error err unless target
    return window_error "#{opts.effect} needs two uncommented dialogue lines." unless source.class == "dialogue" and target.class == "dialogue" and not source.comment and not target.comment
    if collection.styles
      source.styleRef = collection.styles[source.style] if not source.styleRef
      target.styleRef = collection.styles[target.style] if not target.styleRef
    lines, err = safe_pair_morph_outputs source, target, collection, opts
    return window_error err unless lines and #lines > 0
    return unless confirm_large_output #lines, "this pair"
    commented_source, err = safe_line source, collection, "Commented source line"
    return window_error err unless commented_source
    commented_target, err = safe_line target, collection, "Commented target line"
    return window_error err unless commented_target
    commented_source.comment = true
    commented_target.comment = true
    ok_apply, generated_or_error = pcall ->
      LineOps.transaction sub, script_name, ->
        sub[sorted_sel[1]] = commented_source
        sub[sorted_sel[2]] = commented_target
        generated_selection = {}
        insert_at = sorted_sel[2] + 1
        for line in *lines
          sub.insert insert_at, line
          generated_selection[#generated_selection + 1] = insert_at
          insert_at += 1
        generated_selection
    return window_error "Could not apply pair morph atomically: #{generated_or_error}" unless ok_apply
    return generated_or_error
  plans = {}
  for i, index in ipairs sorted_sel
    aegisub.cancel! if progress_is_cancelled!
    progress_task "Preparing line #{i} of #{#sorted_sel}"
    progress_set math.floor(50 * i / #sorted_sel)
    source, err = safe_line sub[index], collection, "Selected line #{index}"
    return window_error err unless source
    unless source and source.class == "dialogue" and not source.comment
      return window_error "Selection contains a non-dialogue or commented line."
    if collection.styles and not source.styleRef
      source.styleRef = collection.styles[source.style]
    source_opts = opts
    if frame_contexts[index]
      source_opts = clone_options opts
      source_opts._frame_context = frame_contexts[index]
    lines, err = safe_outputs_for source, collection, source_opts
    return window_error err unless lines and #lines > 0
    plans[#plans + 1] = {index: index, source: source, lines: lines}
  actual_total = 0
  for plan in *plans
    actual_total += #plan.lines
  return unless confirm_large_output actual_total, "the actual output"
  ok_apply, generated_or_error = pcall ->
    LineOps.transaction sub, script_name, ->
      inserted = 0
      generated_selection = {}
      for i, plan in ipairs plans
        source_index = plan.index + inserted
        commented, comment_err = safe_line plan.source, collection, "Commented source line"
        error comment_err unless commented
        commented.comment = true
        sub[source_index] = commented
        insert_at = source_index + 1
        for line in *plan.lines
          sub.insert insert_at, line
          generated_selection[#generated_selection + 1] = insert_at
          insert_at += 1
        inserted += #plan.lines
        progress_set 50 + math.floor(50 * i / #plans)
      generated_selection
  return window_error "Could not apply generated lines atomically: #{generated_or_error}" unless ok_apply
  generated_or_error

main = (sub, sel) ->
  opts = read_options!
  run_with_options sub, sel, opts

validate_any = -> true

validate_effect = (effect) ->
  spec = effect_spec effect
  if spec.kind == "pair_morph"
    (sub, sel) -> validate(sub, sel) and #sel == 2
  else
    validate

hotkey_menu_path = (effect) ->
  HOTKEY_MENU_ROOT .. "/" .. HOTKEY_MENU_SCRIPT .. "/" .. (EFFECT_CATEGORY[effect] or "Other") .. "/" .. effect

action_macro = (effect) ->
  (sub, sel) ->
    opts = show_effect_options effect
    return if opts == "__back"
    run_with_options sub, sel, opts

help_macro = ->
  category = DEFAULTS.category
  current = DEFAULTS.effect
  while true
    gui = picker_gui category, current
    button, result = aegisub.dialog.display gui, {"Refresh", "Close"}, {ok: "Refresh", close: "Close"}
    return unless button == "Refresh"
    category = choice_or_default result and result.category or category, CATEGORIES, category
    pool = CATEGORY_EFFECTS[category] or EFFECTS
    current = choice_or_default result and result.operation or current, pool, pool[1]

register_macro = (name, description, process, validate_fn) ->
  if depctrl and depctrl.registerMacro
    depctrl\registerMacro name, description, process, validate_fn, nil, false
  else
    aegisub.register_macro name, description, process, validate_fn

register_macro script_name, script_description, main, validate
register_macro "#{script_name}/Help", "Show #{script_name} effect help.", help_macro, validate_any
for effect in *EFFECTS
  register_macro hotkey_menu_path(effect), EFFECT_HELP[effect] or script_description, action_macro(effect), validate_effect(effect)
