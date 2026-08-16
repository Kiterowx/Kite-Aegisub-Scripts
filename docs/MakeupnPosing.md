# MakeupnPosing 1.0.0

MakeupnPosing combines reusable ASS sign styling with rigid posing for complete selected sign stacks. The interface is available in English and Spanish.

Menu root: `MakeupnPosing`

Namespace: `kite.MakeupnPosing`

## Makeup

Makeup stores two kinds of reusable records:

- `[TAG] Name` is an adaptive preset. It preserves styles, tags, drawings, geometry, clips, and structural anchors while adapting the saved treatment to new text.
- `[GROUP] Name` is an exact sign group. It preserves complete ASS events, including text, drawings, inline tags, perspective data, actor/effect fields, comments, timing relationships, and layer order.

The active source line is the capture anchor. On insertion, positions, moves, origins, perspective coordinates, and clips are translated to the destination anchor. Layer offsets are preserved for the complete stack.

The subtitle folder contains a small `Makeup Library.index.json` index and a `Makeup Library` directory with one JSON file per preset. Records are loaded only when needed.

## Posing

Posing transforms the complete selected sign stack around one shared pivot. It can:

- move the stack horizontally or vertically;
- rotate it around the stack center, the active-line anchor, or a custom pivot;
- rotate the group as one rigid composition or rotate individual lines around their own centers;
- expose direct hotkey actions for positive and negative X, Y, and Z steps.

The main dialog also provides configuration and help without opening a separate macro.

## Dependencies

DependencyControl installs and loads `kite.LineOps` 1.5.3, `kite.PyBridge` 1.4.5, `kite.UI` 1.1.2, `l0.dkjson` 0.8.0, and Aegisub's `aegisub.re` module.
