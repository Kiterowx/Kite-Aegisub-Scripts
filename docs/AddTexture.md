# AddTexture 2.1.8

English | [Español](es/AddTexture.md) | [Index](../README.md#documentation)

AddTexture fits pasted ASS textures over selected text outlines. It preserves the source events and inserts generated texture lines with the chosen layer offset.

## Workflow

1. Copy raw ASS drawing data, a `\p` drawing, a vector clip or Dialogue/Comment rows containing drawings.
2. Select uncommented dialogue lines and run **AddTexture**.
3. Inspect the drawing input. **Paste clipboard** explicitly reloads the clipboard and keeps the other window choices. Execute uses the displayed input, including any edits.
4. Set the simplification, color and clipping options, then Execute.
5. Review the inserted lines. They are selected, with the first generated line active. The originals remain available and one undo reverses insertion.

For a clipboard larger than 12,000 characters, the window displays a preview. Executing the unchanged preview uses the full captured payload. Editing that preview replaces the payload with the edited text; changing the external clipboard has no effect until Paste clipboard is pressed.

## Input interpretation

Drawings are normalized to `\p1` coordinates. Their explicit position, alignment and scale are applied when present; texture groups share a common bounding box so their relative placement is retained. Clip coordinates are absolute and do not inherit the surrounding text's scale or alignment. Animated clip payloads are not treated as additional static textures.

ASSFoundation parses structured drawing sections when available; the fallback uses LineOps for top-level clip calls. The texture interpretation is static: it is not a renderer for arbitrary animated input or a substitute for baking perspective and motion before pasting a texture.

## Options and results

| Option | Behavior |
| --- | --- |
| Preserve colors | Keeps source primary colors and groups drawings by color. Otherwise the texture uses the target text's primary color. |
| Clip to text | Intersects texture geometry with the text outline. Without this option, generated lines carry the text outline as a clip. |
| Copy alpha/fad | Copies visibility tags, including visibility transforms, using the shared tag parser. Other transform contents are omitted. |
| Extra tags | Inserts the supplied overrides into generated drawings. Default: zero border and shadow. |
| Text simplify / Shape simplify | Nonnegative tolerances for outlines and pasted textures. Zero allows the finest available geometry. |
| Layer offset | Nonnegative integer added to the source layer. |

The texture is scaled uniformly to cover the target bounding box and centered over it. Empty intersections are valid: they are skipped and counted in the completion message. If none intersect, no line is inserted. Visibility copying applies to the generated texture line as a whole; it does not reproduce separate opacity regions within individual text glyphs.

Large output prompts for review above 20,000 estimated lines and can continue. Processing checks cancellation while preparing groups and while inserting. The insertion transaction restores subtitles if it fails or is cancelled. Increasing tolerances can remove detail; retaining more geometry increases processing and rendering cost.

## Configuration and dependencies

Your options are saved for the next run. Paste the drawing again when starting a new texture.

## Example

Paste a two-color stripe drawing, select a sign line, enable Preserve colors and keep Clip to text off. AddTexture creates color groups fitted to the sign and clips them to its outline. Enable Clip to text when you need the intersection baked into drawing geometry instead. Use Copy alpha/fad for a uniform fade matching the sign.
