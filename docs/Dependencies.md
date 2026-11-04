# Dependencies

English | [Español](es/Dependencies.md) | [Index](../README.md#documentation)

The [installation guide](../README.md#installation) separates DependencyControl modules, environment libraries and external programs. Install third-party modules before copying macros into `autoload`.

## Dependencies by script

**aka.command** is a shared dependency of the scripts through the Kite modules. **dkjson** is bundled with DependencyControl and explicitly declared by Allure. This table adds script-specific modules using their **Modules:** names; the [name and identifier map](../README.md#3-third-party-modules-from-dependencycontrol) includes their feeds. Internal dependencies of those libraries are resolved from their catalogs.

| Script | Additional modules in **Modules:** |
| --- | --- |
| AddTexture | **ASSFoundation**, **ZF main** |
| Allure | **dkjson** |
| Chrono Suite | None beyond the shared dependency. |
| Cliptomaniac | **(Almost) Functional Suite**, **ASSFoundation**, **Line**, **Perspective**, **Util**, **ZF main** |
| Gradient Row | **ASSFoundation**, **Line**, **LineCollection**, **Perspective**, **SubInspector** |
| Hotkeys | None beyond the shared dependency. |
| Moka Motion | **ArchMath**, **ASSFoundation**, **LineCollection**, **Perspective**, **Tags**, **Util**, **ZF main** |
| Obake | **ASSFoundation**, **Line** |
| Rhea Signs | **(Almost) Functional Suite**, **ASSFoundation**, **Line**, **LineCollection**, **Perspective**, **Util** |
| Selesub | **ASS Parser** |
| Zheus Colormanager | None beyond the shared dependency. |

**SubInspector** is also installed as an **ASSFoundation** dependency. **Yutils** is required by **ZF main**, and used by ASSFoundation curve operations. **LuaJSON** (`json`) is needed by **Line** and to read waveforms in Chrono’s Smart Split. Yutils and LuaJSON are installed separately from this selector. The `aegisub.*` modules belong to the Aegisub environment.

## Included modules

Copy the complete repository folder `automation/include/kite` to Aegisub’s `automation/include/kite`. Scripts load the modules they need; the modules are distributed together to keep compatible versions.

| Module | Version | Responsibility |
| --- | --- | --- |
| `kite.AssContext` | 1.1.3 | ASS styles, tags and timing. |
| `kite.Core` | 1.1.0 | Numbers and ASS formatting. |
| `kite.EventOps` | 1.3.1 | Subtitle fields and cleanup. |
| `kite.PyBridge` | 1.7.2 | External processes and Python backends. |
| `kite.ShapeOptimizer` | 1.3.3 | Drawing and gradient optimization. |
| `kite.Timing` | 1.4.3 | Timing and karaoke reconstruction. |
| `kite.UI` | 1.5.2 | Dialogs, favorites and shortcuts. |

[DependencyControl.json](../DependencyControl.json) lists minimum versions by script. Installable files are under `automation/autoload` and `automation/include/kite`.

FFmpeg, FFprobe, SCXvid, fonts and renderer support are covered by the [installation requirements](../README.md#5-external-programs-by-feature).
