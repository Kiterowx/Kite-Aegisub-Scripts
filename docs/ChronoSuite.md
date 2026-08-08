# Chrono Suite 1.3.2

Chrono Suite provides timing, audit, cleanup, data-import, and workflow tools.

Menu root: `Chrono Suite`

Namespace: `kite.ChronoSuite`

Public URL: <https://github.com/Kiterowx/Kite-Aegisub-Scripts/blob/main/docs/ChronoSuite.md>

## Main areas

- Audit markers with presets and configurable thresholds.
- Utility groups for case, punctuation, tags, smart cleanup, split/join, timing, and karaoke.
- Data Import modes for Effects, Text, Actor, initial Tags, and Song Sync.
- Cue Timer with optional data-file auto-search on open.
- Auto Timing with Lazy, Busy, and Legacy workflows.
- Extra tools including AE Export, Text Replacer, mpv QC, and Remover Assistant.

## Dedicated entries

- `Chrono Suite/Config`
- `Chrono Suite/Help`
- `Chrono Suite/Cue Timer`
- `Chrono Suite/Auto Timing`
- `Chrono Suite/Extract KF (SCXvid)`
- `Chrono Suite/Scream Detector`
- `Chrono Suite/Audit/Markers`

Additional utility and tool entries are registered beneath the same root for direct hotkey assignment.
Hotkey-oriented entries are also registered under `: Kite Hotkeys :/Chrono Suite/...`.

## Auto Timing

- Lazy uses waveform JSON directly.
- Busy uses the `kite.Timing` module and Busy timing files; waveform JSON is optional.
- Legacy uses the `kite.Timing` module and the legacy silence-based path.

Waveform input is validated for a positive point interval and complete min/max pairs. Silent waveforms no longer become full-span speech, and zero lead-in plus zero lead-out uses a stable midpoint instead of an undefined division.

## ASS and workflow integrity

- Dialogue selections are deduplicated and validated before tools run.
- Karaoke conversion preserves inline ASS blocks, comments, whitespace, and explicit line-break escapes.
- AE Export reads `\move` trajectories per frame and safely falls back to script-center coordinates when video geometry is unavailable.
- Text replacement preserves every leading ASS/comment block.
- Hotkey migration edits only exact command keys, preserving unknown contexts and JSON structure.
- Read-only tools such as AE Export, Time Picker, Count CPS, and Copy Fold do not create undo points.

## Configuration and external tools

Settings persist in the Aegisub user directory as `chrono_suite_config.lua`. FFmpeg, SCXvid, keyframes, and external timing-analysis files are required only by the features that use them.

Chrono Suite uses `kite.Timing` for shared timing engines, `kite.Media` for project media and frame ranges, `kite.LineOps` for subtitle operations, `kite.PyBridge` for external processes, and `kite.UI` for shared settings behavior. CFR sources can pass their verified frame rate to the encoder; VFR sources keep their original timestamps.

- FFmpeg download: <https://ffmpeg.org/download.html>
- Chrono Generators: <https://github.com/Kiterowx/Chrono-Generators-Scripts>
- Timing guide: <https://kiterowx.github.io/Arquitectura-del-Timing/>

The script includes English, Spanish, and Portuguese interface text.
