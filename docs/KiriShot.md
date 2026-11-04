# Kiri-Shot 1.0.0

English | [Español](es/KiriShot.md) | [Index](../README.md#documentation)

Kiri-Shot combines PNG captures, sequences, alpha crops, ASS masks and social-video exports. Install `automation/autoload/kite.KiriShot.lua`. It uses the shared suite libraries and does not load either former macro. Keep the replaced `kite.Snapshoter.moon` and `kite.SocialClip.lua` files outside active autoload paths.

## Task interface

Open **Kiri-Shot**, choose a task and press **Abrir tarea**. The header shows the loaded video, resolution and selected dialogue count. Each panel displays the controls relevant to that task. The interface labels are Spanish.

| Task | Output |
| --- | --- |
| Capturas · líneas seleccionadas | PNG captures at each selected event's midpoint, start/end, start/middle/end or current video frame. |
| Capturas · lista de fotogramas | Explicit zero-based frame indices, including `120f, 130f` and the previously supported annotations. |
| Capturas · secuencia PNG | Entire selection interval, with clean video, burned subtitles and/or transparent subtitles. |
| Recorte · clip o dibujo | Clip rectangle or rendered clip/drawing alpha, cropped or full frame. |
| Recorte · rectángulo manual | X/Y/width/height crop in video pixels. |
| Captura · mayor superposición | First frame containing the highest selected-dialogue overlap. |
| Vídeo social | MP4/MKV or adapted ASS export, using the script's masks. |
| Preparar máscaras | Create masks, correct Y, center subtitles in X or remove legacy Y previews. |

**Cambiar tarea** returns to the task selector and retains the session draft. **Ajustes** opens shared configuration; cancelling it discards only its pending changes. **Cerrar** executes nothing. Captures leave subtitle events unchanged. Mask and subtitle edits retain transactional rollback and undo.

## Capture and video workflows

Use **Capturar PNG** for captures and sequences. Files go to the project's `Snapshots` directory, falling back to the script/video folder. Naming and grouping options retain the former behavior. Frame-list drafts survive panel navigation but are regenerated for a new macro invocation. Rectangle validation applies only to tasks using rectangles. A sequence requires at least one output and verifies every generated PNG.

See the [capture engine details](KiriShotCaptures.md) for timing, alpha, sequence coverage and cancellation behavior.

Use **Aplicar** in the mask panel. Creating masks preserves the source events; Y correction and X centering operate on the selection. Explicit preview cleanup only removes recognized legacy helper events and works without a video. Existing `Kite Social Mask`, `Kite Social Y Preview` and `_kite_socialclip_centered` identifiers remain compatible.

The mask and video panels share the output format. **Exportar vídeo** retains adapted MP4, exact-composition MP4 and MKV with switchable ASS dialogue. **Solo ASS** exports adapted dialogue without encoding video. Output selection, active-file protection, scene normalization, audio and temporary-file handling retain their established behavior. See the [social-video engine details](KiriShotVideo.md).

## Shared settings and migration

**Ajustes** contains FFmpeg, FFprobe, the libx264 speed preset and AAC bitrate. One FFmpeg path serves both engines. FFmpeg must support PNG, libass and the operation's required filters; video encoding uses libx264 and AAC.

Preferences use `kite.KiriShot`, with separate capture, social and shared sections. The first session reads both former namespaces and their legacy JSON configurations while retaining the source preferences. Settings are saved when executing a task or choosing **Guardar** in the settings panel.

When both macros had different custom FFmpeg paths, Social Clip's path takes priority and the task selector displays a notice. When it used the default, Snapshoter's custom path is retained. The chosen path can be changed in shared settings.

Existing shortcuts/favorites migrate on load to **`: Kite Hotkeys :/Kiri-Shot/Capturas`** and **`: Kite Hotkeys :/Kiri-Shot/Vídeo social`**. Retired action catalogs are cleared to prevent duplicate entries.

The nine direct libraries are `kite.UI`, `kite.Core`, `kite.PyBridge`, `kite.ShapeOptimizer`, `kite.AssContext`, `a-mo.LineCollection`, `l0.ASSFoundation`, `myaa.ASSParser` and `tstools.Yutils`. DependencyControl manages them; transitive dependencies such as SubInspector retain their usual requirements.
