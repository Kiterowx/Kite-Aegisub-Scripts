# Pointiac 1.1.0

Pointiac creates two compact ASS point markers for every selected dialogue line: one on its first frame and another on its last frame.

Menu root: `Pointiac`

The `Pointiac` entry itself can be assigned as a hotkey in Aegisub.

Namespace: `kite.Pointiac`

Pointiac is distributed as a Lite script.

## Workflow

1. Select one or more dialogue lines.
2. Run **Pointiac**.
3. Choose the color, position, horizontal separation, fallback FPS, and layer offset.
4. Press **Execute**.

The source lines remain unchanged. Pointiac inserts the two generated marker lines immediately after each source.

## Behavior

- Uses Aegisub's video frame mapping when available.
- Falls back to the configured FPS when frame mapping is unavailable.
- Keeps both circles spatially separate, enforcing a minimum horizontal distance based on the drawing size.
- Preserves the source style and metadata while replacing the generated text with a fixed `\p1` circle.
- Stores stable color, FPS, separation, and layer-offset preferences.

## Requirements

- `kite.UI` 1.1.0
- `kite.LineOps` 1.5.0
