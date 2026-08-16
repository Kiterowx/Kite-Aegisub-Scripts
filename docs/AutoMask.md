# AutoMask 2.4.7

AutoMask detects, cleans, and reconstructs guided surfaces from the current video frame through the `kite-automask` 0.4.1 backend.

Menu root: `AutoMask`

Namespace: `kite.AutoMask`

## Commands

- `AutoMask` opens the guided editor workflow.
- `AutoMask/Find surface inside clip` treats each `\clip` as a search guide and detects the distinct surface contained inside it.
- `AutoMask/Classic AutoGrask` runs the original clip-guided profile.
- `AutoMask/Backend/Check` reports installation, runtime readiness, and updates; it offers installation, repair, or update when needed.
- `AutoMask/Backend/Install or Update` installs or updates the backend from the configured repository.
- `AutoMask/Backend/Configure` sets the Python interpreter and the install source.
- `AutoMask/Backend/Install Models` downloads and verifies the supported models.

Every command in the AutoMask submenu can be assigned directly as a hotkey in Aegisub.

## Editor

The panel exposes Regions, View, Output, Clip usage, Engine, Tool, and the Brush, Sensitivity and Simplify sliders. Every control is in English and every selection is stored as a stable key, so the labels can change without affecting behaviour. Moving the sensitivity slider re-thresholds the ink in place; releasing it rebuilds the vectors.

Region entries are marked `·` when pending, `✓` when reconstructed, and `!` when the region reported an error.

Keyboard: `1` to `7` select tools, `Ctrl+Z` and `Ctrl+Y` undo and redo, `Space` cycles the view, `A` searches the area, `S` refines with SAM, `D` detects ink, `R` rebuilds, `Ctrl+Enter` applies, `Esc` cancels.

The status area shows the engine, line count, and p90 reconstruction error. The backend enforces explicit limits for frame pixels, regions, geometry, text, generated lines, and JSON size.

## Output modes

- `ASS fill` replaces each selected line with the reconstructed drawing lines.
- `Shape` inserts the region contour as a drawing on the layer above.
- `\clip` and `\iclip` apply the region contour as a clip tag on the selected line.

The backend interprets rectangular, vector, and inverted clips, together with `\p`, `\pbo`, `\pos`, alignment, and B-spline commands. The dedicated **Find surface inside clip** and **Classic AutoGrask** entries require an ordinary `\clip`; the main editor can process inverted guide geometry.

## Validation

- Model names and download URLs are validated before use.
- Model downloads require HTTPS and are checked by size and SHA-256.
- Frame dimensions are checked before full decoding.
- Ambiguous transforms or unsupported geometry are rejected explicitly.
- Request and result JSON files are written through temporary files and atomic replacement.

## Configuration

The Python interpreter and the install source are stored by namespace in `?user/config/kite.settings.json`. Settings under the former `kite.Automask` namespace and an existing `?user/kite.automask.conf` are imported once on first read.

FFmpeg is resolved from `?user/kite-snapshoter.json` when Snapshoter is configured, and falls back to `ffmpeg` on `PATH`.

Temporary exchange files use the first writable location available from Aegisub, the operating system, or the Aegisub user directory.

## Requirements

- FFmpeg
- `aka.command`, `kite.UI`, `kite.PyBridge`, and `kite.LineOps`
- Python package `kite-automask` 0.4.1
- EfficientSAM and LaMa models for the segmentation and inpainting workflows
