# Zheus Colormanager 4.7.3

English | [Español](es/Zheus.md) | [Index](../README.md#documentation)

Zheus manages ASS colors by actor, four-corner gradients, color replacement and timed palette changes. It includes a segment editor and tools for comparing and adapting palettes through contrast, luminance and color-vision simulations. The interface uses Spanish labels, retained below.

## Input and scope

Select the events to inspect or modify. Duplicate indices are consolidated; headers and styles are not treated as dialogue. Empty actors are supported, and names retain whitespace and Unicode. Different names remain separate until explicitly merged.

Analysis starts from each line's style and reads its visible text or drawing spans, solid colors and ordered `\r`/`\rStyle` resets. An actor's representative color is the most frequent color among its static spans. Ties use the first line, then color value. The report retains differences within a line.

Tags following ignored text inside braces remain active: `{note \c&H0000FF&}` changes fill, while `{note about color}` is a comment. See the [Aegisub override-tag reference](https://aegisub.org/docs/latest/ass_tags/#override-tags).

Color animations are identified, but a static summary does not describe every moment of a transform; preview the scene to inspect it. Style colors and tag values are interpreted separately. Eight digits in `\c` do not automatically become transparency. Opacity comes from style alpha and the corresponding alpha tags.

## Panel and commands

The main command is **Zheus Colormanager**. The other 17 actions are under `: Kite Hotkeys :/Zheus Colormanager/`.

| Command | Function |
| --- | --- |
| Zheus Colormanager | Selection summary, managers, replacements and four quick gradients. |
| Editor de tramos | Edit a line's color spans and boundaries. |
| Colores | Fill, outline and shadow palettes by actor. |
| VSF | Four corners by actor and channel. |
| Actores | Rename, merge or clear actors in the selection. |
| Cambiar colores | Replace explicit values in selected channels. |
| ColorRelay | Build palette changes at control frames. |
| Daltonismo | Open analysis, profiles and import/export. |
| Daltonismo/Auditar | Report without editing subtitles. |
| Daltonismo/Aplicar Daltonismo | Open with the Daltonismo profile selected. |
| Daltonismo/Universal | Select Universal accesible. |
| Daltonismo/Protanopia | Select Protanopía. |
| Daltonismo/Deuteranopia | Select Deuteranopía. |
| Daltonismo/Tritanopia | Select Tritanopía. |
| Daltonismo/Monocromo | Select Monocromo. |
| Daltonismo/Alto contraste | Select Alto contraste. |
| Daltonismo/Calibrar perfil | Create or update Personalizado. |
| Daltonismo/Exportar accesible | Export the selected profile's adapted palette. |

Profile commands open a window before applying. **Cancelar** discards the pending edit; **Volver** returns to the previous window. Subtitle edits support Undo, and failures or cancellation during application restore the previous state.

## Actor colors

1. Open **Colores**, or choose **Colores por Actor** and press **Gestor**.
2. Edit `\c`, `\3c` and `\4c`: fill, outline and shadow. Each page holds eight actors; navigation preserves edits.
3. Choose **Etiquetas**, **Estilos** or **Limpiar**, then press **Aplicar**.

The lower selector and **Abrir** open VSF, Lista, Conflictos, Exportar or Importar while retaining application and cleanup options.

| Operation | Result |
| --- | --- |
| Etiquetas, with auto-cleanup | Removes existing fill, outline and shadow colors, including color transforms, and writes the chosen palette initially and after resets. Preserves `\2c`. |
| Etiquetas, without auto-cleanup | Changes the first block's base and retains later solid colors. Removes gradients in the three edited channels. Later overrides can still take precedence. |
| Estilos | Creates styles by actor and original style, retaining typography, alignment, margins, formatting and secondary color. Reapplies chosen colors after resets. |
| Limpiar | Removes all four solid colors and gradients, including those inside transforms. Retains other tags. |

Generated styles can be reused when only the target events reference them. Named resets also count as references: a style used outside the selection is not overwritten. Style insertion updates the returned selection indices.

Duplicate cleanup retains the last valid color's position in its group. It does not move colors across resets or transforms.

## Actors

Each page shows eight original actors and their destinations. Give several rows the same destination to merge them, or leave a destination empty to clear the actor. **Aplicar** changes only selected events; **Cancelar** preserves them.

## VSF gradients

The four-corner controls correspond to `\1vc`, `\2vc`, `\3vc` and `\4vc`. Corner order is top-left, top-right, bottom-left and bottom-right.

In the actor manager, select a channel and edit its corners. Changing channels saves the visible draft before showing the next channel. **Estilos** cannot store VSF gradients; use tags. Editing one channel preserves the others.

The main panel can apply several channels together. VSF cleanup removes previous gradients; enabled channels receive their new tuple after resets. Appearance requires VSFilterMod or a compatible renderer. libass does not render these extensions.

## Replacing colors

Select channels and press **Actualizar** after changing the filter. The list includes explicit colors, transform targets and VSF corners. Manage inherited colors through Colores or styles.

Pages hold eight replacements and retain edits across navigation. **Aplicar** applies the complete mapping once: red → blue and blue → green does not turn the newly replaced red into green. Unselected channels remain unchanged.

Short ASS colors are accepted and output is normalized. Higher color digits do not introduce alpha.

## ColorRelay

Requires video and frame/millisecond conversion. Frame durations use Aegisub timestamps, including variable frame rates.

1. Select the sequence lines.
2. Enter control frames and a default fade. Accepted forms include `120f, 150f`, `F120`, `120` and `120f fundido 6f`.
3. At each control, assign replacements for active colors. **Omitir** skips replacements at that control; **Volver** revisits the previous one.
4. After the controls, the complete program is validated and applied.

Fades accept milliseconds (`240`, `240ms`) or frames (`6f`) and are centered on the control time. Zero makes an instant change. `120f > P1 fundido 6f` is also accepted; P1 is descriptive text, not a saved palette selector.

Replacements persist into later controls. Invalid, repeated or out-of-selection frames are reported together. Each control uses the same paginated replacement window as Cambiar colores.

A fade crossing a cut keeps its complete color endpoints and relative times in both events, including negative times. It is not restarted from rounded intermediate colors at the cut.

ColorRelay needs uniform solid channels within each line. It supports initial resets and preserves motion, fades and transforms of unrelated properties. Before editing, it rejects later changes in selected channels, VSF gradients in them, transforms of those colors and overlapping fades on one channel. Use the segment editor or prepare uniform lines for these cases.

## Segment editor

Select one line and open **Editor de tramos** or **Cambios → Por tramos**. It uses `Color.segments`.

Change colors and boundaries, split spans, join a span with the next one, switch channels or reset a channel. Positions count graphemes; spaces and ASS escapes remain part of the content. Text and unrelated tags are preserved.

Known style resets form boundaries. Short colors and empty-argument color resets use their context. Animated channels are identified and protected from accidental static replacement; other channels remain editable. Drawings are not converted to text.

## Analysis and profiles

The report compares fill, secondary, outline and shadow colors and records the worst contrast among static spans. It identifies actor differences, transparency, drawings, animated colors and possible loss of separation in VSF. Actor comparisons use representative colors rather than every possible combination at every instant.

Color contrast alone does not establish readability over video: background, opacity and visible outline also matter. Simulations are visual approximations, and calibration records preferences rather than diagnosing vision.

| Profile | Behavior |
| --- | --- |
| Auditar (`NORMAL`) | Report metrics and potential problems without remapping. |
| Daltonismo (`DALTONICO`) | Prioritize tonal separation, outline and actor differences using the subtitle palette. |
| Universal accesible (`UNIVERSAL_SAFE`) | Include Okabe–Ito candidates while seeking to preserve color identity. |
| Protanopía (`PROTAN_SAFE`) | Prioritize protanopia simulation and tonal separation. |
| Deuteranopía (`DEUTAN_SAFE`) | Prioritize deuteranopia simulation and tonal separation. |
| Tritanopía (`TRITAN_SAFE`) | Prioritize tritanopia simulation and tonal separation. |
| Monocromo (`MONOCHROME`) | Convert fill to luminance-based gray and choose a contrasting outline. |
| Alto contraste (`HIGH_CONTRAST`) | Use white fill and black outline/shadow, retaining the secondary channel's role. |
| Personalizado (`CUSTOM`) | Store preferences derived from calibration pairs. |

Candidates are scored by contrast, OKLab distance, luminance and color preservation. Color and ShapeOptimizer share the sRGB/linear/OKLab conversions. Calculation caches do not limit palette size.

Adapted gradients retain each channel's role. Luminance distribution is calculated in linear light; even a black base can produce corners of different luminance. A profile cannot guarantee that every threshold will be met for any number of actors. Review the output and report.

### Application options

- **Etiquetas / Estilos**: choose how to write colors. Styles retain each original style and update selection indices; use tags for VSF.
- **Preservar alfa**: retain style opacity and alpha tags. Disabling it forces opacity, including after resets.
- **Forzar bord y shad**: replace outline and shadow with profile values. The choice persists between window openings.
- **Incluir dibujos**: include ASS drawings; otherwise skip and report them.

Auditar shows the report rather than applying. Calibrar, Importar and Exportar retain panel options. Calibration presents five pairs with different, same or unsure responses and saves Personalizado.

## Palettes and settings

Actor palettes use text format v3. Names are percent-encoded to preserve Unicode, separators and empty actors. A row contains `actor|fill,outline,shadow`, optionally followed by `|1vc:...` through `|4vc:...`. Import also reads v2. Invalid rows are skipped entirely without losing later valid rows. The last valid row wins for repeated actors.

Accessible palettes v3 contain version, profile, actors, original colors, remapping and gradients. Export saves remapped gradients. Import accepts v3 and legacy v2, applies actors present in the selection and reports the rest.

Legacy tables are parsed by `Settings.parseLiteralTable` without executing Lua. Tables, keys, escaped strings, booleans and finite numbers are accepted; programs and malformed data are rejected. Zheus imposes no fixed size, depth or actor-count limit. Exports are atomic and report write failures.

Your settings and custom profiles are saved between sessions. Previous settings are imported automatically.

## Examples

- One actor uses Arial and another font on different lines. Estilos creates the necessary styles while preserving both fonts and margins.
- `A{\rAlt}B` has two spans. Auto-cleanup applies the palette to both while the reset retains Alt's other properties.
- Red in `\c` and green inside `\t` both appear in Cambiar colores. Changing outline only retains the fill animation.
- A palette of 209 colors uses 27 eight-row pages. Applying includes edits from every page.
- A fade spanning 100–900 ms crosses a cut at 440 ms. The second event retains `\t(-340,460,...)` and the original color endpoints.
