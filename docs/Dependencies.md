# Dependencies

English | [Español](es/Dependencies.md) | [Index](../README.md#documentation)

The [installation guide](../README.md#installation) separates DependencyControl modules, environment libraries and external programs. Install third-party modules before copying macros into `autoload`.

## Dependencies by script

**aka.command** is a shared dependency of all 22 scripts through the Kite modules. **dkjson** is bundled with DependencyControl and explicitly declared by Allure. This table adds script-specific modules using their **Modules:** names; the [name and identifier map](../README.md#3-third-party-modules-from-dependencycontrol) includes their feeds. Internal dependencies of those libraries are resolved from their catalogs.

| Script | Additional modules in **Modules:** |
| --- | --- |
| AddTexture | **ASSFoundation**, **ZF main** |
| Alecto KFX | None beyond the shared dependency. |
| Allure | **dkjson** |
| AutoBlur | **DataWrapper** (tracking only). |
| AutoMask | None beyond the shared dependency. |
| Chrono Suite | None beyond the shared dependency. |
| Cliptomaniac | **(Almost) Functional Suite**, **ASSFoundation**, **Line**, **Perspective**, **Util**, **ZF main** |
| Field Group Manager | None beyond the shared dependency. |
| Gradient Row | **ASSFoundation**, **Line**, **LineCollection**, **Perspective**, **SubInspector** |
| Hotkeys | None beyond the shared dependency. |
| Macaria Revert | None beyond the shared dependency. |
| Moka Motion | **ArchMath**, **ASSFoundation**, **LineCollection**, **Perspective**, **Tags**, **Util**, **ZF main** |
| Obake | **ASSFoundation**, **Line** |
| PNG2ASS | **ZF main** |
| Pointiac | None beyond the shared dependency. |
| Rhea Signs | **(Almost) Functional Suite**, **ASSFoundation**, **Line**, **LineCollection**, **Perspective**, **Util** |
| Selesub | **ASS Parser** |
| Snapshoter | **ASS Parser**, **LineCollection**, **Log** |
| Social Clip | **ASS Parser**, **ASSFoundation**, **LineCollection**; **SubInspector** (complex masks). |
| Wave2json | None beyond the shared dependency. |
| Zagreo Glyphs | **ASSFoundation**, **Line**, **LineCollection** |
| Zheus Colormanager | None beyond the shared dependency. |

**DataWrapper** (`a-mo.DataWrapper`, Aegisub-Motion catalog) is only needed for AutoBlur’s **Use tracking data** option. **SubInspector** is also installed as an **ASSFoundation** dependency; Social Clip uses it for certain complex masks. **Yutils** is required by Zagreo Glyphs and **ZF main**, and used by ASSFoundation curve operations. **LuaJSON** (`json`) is needed by **Line** and to read waveforms in Chrono’s Smart Split. Yutils and LuaJSON are installed separately from this selector. The `aegisub.*` modules belong to the Aegisub environment.

## Included modules

Copy the complete repository folder `automation/include/kite` to Aegisub’s `automation/include/kite`. Scripts load the modules they need; the modules are distributed together to keep compatible versions.

| Module | Version | Responsibility |
| --- | --- | --- |
| `kite.AssContext` | 1.1.3 | ASS styles, tags and timing. |
| `kite.AssDrawing` | 1.0.3 | Drawings and conversion profiles. |
| `kite.Color` | 1.2.2 | Colors and palettes. |
| `kite.Core` | 1.1.0 | Numbers and ASS formatting. |
| `kite.EventOps` | 1.3.1 | Subtitle fields and cleanup. |
| `kite.LineOps` | 1.7.4 | Line selection and editing. |
| `kite.Media` | 1.4.0 | Video, audio and timecodes. |
| `kite.PyBridge` | 1.7.2 | External processes and Python backends. |
| `kite.Settings` | 1.0.1 | Shared settings. |
| `kite.ShapeOptimizer` | 1.3.3 | Drawing and gradient optimization. |
| `kite.Timing` | 1.4.3 | Timing and karaoke reconstruction. |
| `kite.UI` | 1.5.2 | Dialogs, favorites and shortcuts. |

[DependencyControl.json](../DependencyControl.json) lists minimum versions by script. Installable files are under `automation/autoload` and `automation/include/kite`.

## Python backends

AutoMask and PNG2ASS need 64-bit Python 3.10 or newer and Git for installation from GitHub. **Backend/Install or Update** installs Python libraries; **Backend/Check** checks the selected interpreter. FFmpeg is installed separately.

| Backend | Libraries installed by pip |
| --- | --- |
| [kite-png2ass](https://github.com/Kiterowx/kite-png2ass) | Pillow, OpenCV, NumPy, svgelements, svg2ssa, defusedxml, vtracer. |
| [kite-automask](https://github.com/Kiterowx/kite-automask) | NumPy, OpenCV, ONNX Runtime, PySide6, PNG2ASS. |

Each backend’s `pyproject.toml` declares exact version constraints. EfficientSAM and LaMa models are downloaded through **AutoMask/Backend/Install Models** and use disk space separately from the Python code. Gradient reconstruction does not require them.

FFmpeg, FFprobe, SCXvid, fonts and renderer support are covered by the [installation requirements](../README.md#5-external-programs-by-feature).
