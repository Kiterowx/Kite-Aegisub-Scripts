# Dependencies

English | [Español](es/Dependencies.md) | [Index](../README.md#documentation)

The scripts require these 12 included modules. Copy the complete `Modules/kite/` folder to `automation/include/kite/` and update them together. Follow the [installation steps](../README.md#installation) to set up Aegisub and DependencyControl.

## Included modules

| Module | Version | Responsibility |
| --- | --- | --- |
| `kite.Core` | 1.1.0 | Numbers and ASS formatting. |
| `kite.AssDrawing` | 1.0.3 | Drawings and conversion profiles. |
| `kite.LineOps` | 1.7.4 | Line selection and editing. |
| `kite.AssContext` | 1.1.3 | ASS styles, tags and timing. |
| `kite.Color` | 1.2.2 | Colors and palettes. |
| `kite.EventOps` | 1.3.1 | Subtitle properties and cleanup. |
| `kite.Media` | 1.4.0 | Video, audio and timecodes. |
| `kite.PyBridge` | 1.7.2 | External processes and Python backends. |
| `kite.ShapeOptimizer` | 1.3.2 | Drawing and gradient optimization. |
| `kite.Timing` | 1.4.3 | Timing and karaoke reconstruction. |
| `kite.Settings` | 1.0.1 | Configuration. |
| `kite.UI` | 1.5.1 | Dialogs, favorites and shortcuts. |

[DependencyControl.json](../DependencyControl.json) lists the minimum versions required by each script.

## Lua libraries

Install the libraries listed for each script in the [main table](../README.md#scripts). The [library links](../README.md#lua-libraries) point to their repositories. Keep Aegisub’s bundled Automation files. Yutils requires LuaJIT and libpng for PNG reading.

## Python backends

AutoMask and PNG2ASS require 64-bit Python 3.10 or newer. Install Git for package downloads from GitHub. OpenCV and the libraries below are installed automatically; install FFmpeg separately.

| Backend | Version | Dependencies |
| --- | --- | --- |
| `kite-png2ass` | 1.4.2 | Pillow, OpenCV, NumPy, svg2ssa, defusedxml and vtracer. |
| `kite-automask` | 0.4.2 | NumPy, OpenCV, ONNX Runtime, PySide6 and PNG2ASS. |

For AutoMask’s EfficientSAM and LaMa tools, install the models from **Backend/Install Models**. Gradients work without them.
