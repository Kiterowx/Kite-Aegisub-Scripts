# Rhea Signs 1.8.5

Rhea Signs is a typesetting and sign-operations suite.

Menu root: `Rhea Signs`

Namespace: `kite.RheaSigns`

## Main panel

The main panel combines:

- Transform chains, FX, presets, borders, and generated-layer cleanup.
- Perspective copying, projection, scaling, and extradata workflows.
- Mask creation, replacement, storage, and cleanup.
- Sign operations such as typewriter, vertical drop, circle/curve text, and clip alignment.
- Drawing position unification, perimeter placement, and shape-color optimization.
- An integrated font and style manager for swapping, editing, recoloring, and cloning styles.
- Frame-based fades, continuous-fade cleanup, and line-text shuffling.

## Dedicated entries

- `Rhea Signs`
- `: Kite Hotkeys :/Rhea Signs/TagOps`
- `: Kite Hotkeys :/Rhea Signs/Fast Signs`
- `: Kite Hotkeys :/Rhea Signs/Signs Editor`
- `: Kite Hotkeys :/Rhea Signs/Shapes/Unify Positions`
- `: Kite Hotkeys :/Rhea Signs/Shapes/Place on Perimeter`
- `: Kite Hotkeys :/Rhea Signs/Shapes/Shape Color Optimizer`
- `: Kite Hotkeys :/Rhea Signs/Font and Style Manager`
- `: Kite Hotkeys :/Rhea Signs/Fast Fades`
- `: Kite Hotkeys :/Rhea Signs/Fast Fades/In`
- `: Kite Hotkeys :/Rhea Signs/Fast Fades/Out`
- `: Kite Hotkeys :/Rhea Signs/Fast Fades/Clean`
- `: Kite Hotkeys :/Rhea Signs/Shuffle Line Text`

TagOps includes tag copying/filtering, numeric adjustment, in/out transforms, and position alignment. Clip-focused workflows are provided by Cliptomaniac.

Reusable styling and rigid sign posing are provided by the separate `MakeupnPosing` macro.

Shape geometry and optimization are provided by `kite.ShapeOptimizer`. Fade cleanup and text shuffling use `kite.EventOps`; common subtitle operations use `kite.LineOps`. The menu and hotkey paths remain part of Rhea Signs.

## Configuration

Settings persist through ConfigHandler in `rhea_signs_config.json`. The script includes English, Spanish, and Portuguese interface text.
