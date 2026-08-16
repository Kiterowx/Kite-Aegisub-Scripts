# AddTexture 2.0.13

AddTexture applies pasted ASS drawing textures to selected text outlines.

Menu root: `AddTexture`

The `AddTexture` entry itself can be assigned as a hotkey in Aegisub.

Namespace: `kite.AddTexture`

## Workflow

- Paste or prepare ASS drawing texture data.
- Select dialogue lines with text outlines.
- Run `AddTexture` to clip the texture to the selected text shape.

Large output is confirmed with a warning instead of being rejected. Empty texture/text intersections are skipped and reported without inserting invalid lines.

## Configuration

Settings persist through ConfigHandler in the Aegisub user directory.
