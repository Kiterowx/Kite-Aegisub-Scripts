# Dependencies

## Common requirement

- Aegisub Automation 4 with DependencyControl installed.

`DependencyControl.json` is the authoritative package manifest. It contains the exact version, download path, SHA-1, and required modules for each macro.

## Shared Kite modules

### `kite.LineOps` 1.5.3

Provides validated selections, safe access to the Automation 4 subtitle object, grouped insertions, transactions, rollback, visible-text analysis, drawing state, and lightweight ASS tag operations.

ASSFoundation remains the structural parser for effective tags, style cascades, typed tag classes, complete drawing geometry, and semantic serialization.

### `kite.EventOps` 1.0.3

Provides shared event transformations used by Rhea Signs, including visible-text cloning, Unicode stutter detection, frame-based fade updates, continuous-fade cleanup, and deterministic text shuffling.

### `kite.Media` 1.2.2

Resolves project video, audio, timecodes, subtitle paths, selected frame windows, and CFR/VFR behavior. Chrono Suite and Moka Motion use it for media operations.

### `kite.PyBridge` 1.5.0

Provides platform-aware command execution through `aka.command`, Python resolution, path handling, writable temporary-folder fallback, cleanup, bounded reads, and atomic replacement. It is used by AutoMask, Chrono Suite, Moka Motion, PNG2ASS, Rhea Signs, Snapshoter, Wave2json, and Zheus.

### `kite.ShapeOptimizer` 1.1.0

Provides shared drawing geometry, position unification, perimeter placement, color clustering, and horizontal or vertical gradient reduction for Rhea Signs.

### `kite.Timing` 1.2.2

Provides shared timing, readability, signal, waveform, keyframe, and file-discovery utilities for Chrono Suite.

### `kite.UI` 1.1.3

Provides settings by namespace, migration from supported legacy formats, deep copies, in-memory fallback, dialog helpers, and atomic settings persistence in `?user/config/kite.settings.json`.

## External Automation modules

- `l0.ASSFoundation` and `l0.Functional` provide structured ASS parsing and functional collection helpers.
- `a-mo.LineCollection`, `a-mo.Line`, `a-mo.Tags`, and related Aegisub-Motion modules provide complex line collections and motion data.
- `arch.Math`, `arch.Perspective`, and `arch.Util` provide matrix and perspective operations.
- `ZF.main` provides shared typesetting and geometry components.
- `aka.command` provides hidden process execution for `kite.PyBridge`.
- `SubInspector.Inspector` is optional for Gradient Row bounds.
- `myaa.ASSParser` is required by Selesub.
- `aegisub.re`, `aegisub.unicode`, `aegisub.clipboard`, `aegisub.util`, `json`, `karaskel`, and `Yutils` are used where declared by the feed.

## Python backends

AutoMask uses `kite-automask` 0.4.1 and FFmpeg. EfficientSAM and LaMa are optional model downloads for segmentation and inpainting. AutoMask and PNG2ASS expose backend checks that report package readiness and compare the installed version with the configured local or GitHub source. AutoMask uses `kite-png2ass` for contour vectorization.

PNG2ASS uses `kite-png2ass` 1.4.1, exposed as the Python module `ass_png2ass`.

Both backends require 64-bit Python 3.10 or newer. Their `pyproject.toml` files contain the reproducible Python dependency lists.
