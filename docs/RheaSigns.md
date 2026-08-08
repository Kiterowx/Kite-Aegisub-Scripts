# Rhea Signs 1.7.3

Rhea Signs is a typesetting and sign-operations suite.

Menu root: `Rhea Signs`

Namespace: `kite.RheaSigns`

## Main panel

The main panel combines:

- Transform chains, FX, presets, borders, and generated-layer cleanup.
- Perspective copying, projection, scaling, and extradata workflows.
- Mask creation, replacement, storage, and cleanup.
- Sign operations such as typewriter, vertical drop, circle/curve text, and clip alignment.
- A shape-color optimizer for merging nearby colors or reducing reliable gradients.
- An integrated font and style manager for swapping, editing, recoloring, and cloning styles.
- Continuous-fade cleanup and line-text shuffling.
- Makeup style and layer memories.

## Dedicated entries

- `Rhea Signs`
- `: Kite Hotkeys :/Rhea Signs/TagOps`
- `: Kite Hotkeys :/Rhea Signs/Fast Signs`
- `: Kite Hotkeys :/Rhea Signs/Signs Editor`
- `: Kite Hotkeys :/Rhea Signs/Makeup`
- `: Kite Hotkeys :/Rhea Signs/Shape Color Optimizer`
- `: Kite Hotkeys :/Rhea Signs/Font and Style Manager`
- `: Kite Hotkeys :/Rhea Signs/Continuous Fade Cleanup`
- `: Kite Hotkeys :/Rhea Signs/Shuffle Line Text`

TagOps includes tag copying/filtering, numeric adjustment, in/out transforms, and position alignment. Clip-focused workflows are provided by Cliptomaniac.

The toolbox and Makeup are embedded in Rhea Signs and do not require separate macro files.

Shape optimization is provided by `kite.ShapeOptimizer`. Fade cleanup and text shuffling use `kite.EventOps`; common subtitle operations use `kite.LineOps`. The menu and hotkey paths remain part of Rhea Signs.

## Configuration

Settings persist through ConfigHandler in `rhea_signs_config.json`. The script includes English, Spanish, and Portuguese interface text.
