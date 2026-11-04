# Auto Motion

Part of [Hephaestus Fansubber](Hephaestus.md) **1.2.1**. English | [Español](es/AutoMotion.md)

Auto Motion tracks a region of the video and applies the motion to selected lines. It shares MotionEngine with [Moka Motion](MokaMotion.md): Moka imports tracking data, while Auto Motion calculates it from the video.

## Generate and apply

1. Save the ASS so its library can be created beside the project, then load the corresponding video.
2. Select the sign lines. The range must cover **2–5000 frames**; split longer tracking jobs by scene.
3. Open **Hephaestus Fansubber → Automatons → Auto Motion → Generar y aplicar**.
4. Define the area in the tracking window. The backend uses CPU or CUDA according to **Hephaestus → Configure**.
5. Review the rendered result, particularly occlusions, region edges and scene changes.

The result contains continuous samples for the selected interval. Original lines are recorded for restoration. Authored `\fax`, `\fay`, `\frx` and `\fry` perspective values are preserved, with a notice; `\pos` and `\org` follow the calculated motion.

## Project library

`AutoMotion Library.index.json` and an `AutoMotion Library` folder are created beside the ASS. Keep them with the project: each tracking JSON contains AE data, its reference and original lines.

In **Historial del proyecto**, select a record and use **Reaplicar**:

| Mapping | Behavior |
| --- | --- |
| Fotogramas originales | Reuse the original frame interval and check the source video reference. |
| Alinear al inicio de la selección | Align the saved track to the selected interval for explicit reuse elsewhere. |

Destination lines must fit inside the track. Reapplication uses the saved samples and avoids recalculating motion.

## Restore

**Quitar motion de la selección** restores originals from one tracking record. Select every fragment of each line you intend to restore.

**Borrar y restaurar** restores linked lines in the project and deletes the tracking JSON. Restoration replaces edits made after application. **Undo restores subtitle lines; recovering a deleted JSON requires a library backup.**

## Example

For a sign covering frames 120–167, select its lines, mark a detailed region that remains visible and generate the track. To apply the same path to another sign layer, select that layer and use the history with **Fotogramas originales**. Restore existing fragments before generating a replacement track.

Use **Hephaestus Fansubber → Install → Auto Motion** and **Check → Auto Motion** to prepare or inspect the shared backend.
