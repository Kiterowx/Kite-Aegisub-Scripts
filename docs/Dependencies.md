# Dependencies

English | [Español](es/Dependencies.md)

Install a macro through its normal entry or the Kite catalog and update its required libraries with DependencyControl. Third-party dependencies resolve from their own feeds. See [installation](../README.md#installation).

## Dependencies by script

This table includes direct declarations and dependencies inherited through Kite modules. Aegisub libraries belong to the Automation environment.

| Script | Third-party modules |
| --- | --- |
| [AddTexture](AddTexture.md) | **ZF main**, **aka.command**, **ASSFoundation**, **Yutils (tstools)** |
| [Allure](Allure.md) | **aka.command**, **dkjson** |
| [Chrono Suite](ChronoSuite.md) | **aka.command** |
| [Cliptomaniac](Cliptomaniac.md) | **ZF main**, **Line**, **aka.command**, **Perspective**, **Util**, **ASSFoundation**, **(Almost) Functional Suite**, **Yutils (tstools)** |
| [Gradient Row](GradientRow.md) | **SubInspector**, **Line**, **LineCollection**, **aka.command**, **Perspective**, **ASSFoundation**, **Yutils (tstools)** |
| [Hotkeys](Hotkeys.md) | **aka.command** |
| [Moka Motion](MokaMotion.md) | **ZF main**, **LineCollection**, **Tags**, **aka.command**, **ArchMath**, **Perspective**, **Util**, **ASSFoundation**, **Yutils (tstools)** |
| [Obake](Obake.md) | **Line**, **aka.command**, **ASSFoundation**, **Yutils (tstools)** |
| [Rhea Signs](RheaSigns.md) | **Line**, **LineCollection**, **aka.command**, **Perspective**, **Util**, **ASSFoundation**, **(Almost) Functional Suite**, **Yutils (tstools)** |
| [Selesub](Selesub.md) | **aka.command**, **ASS Parser** |
| [Kiri-Shot](KiriShot.md) | **LineCollection**, **aka.command**, **ASSFoundation**, **ASS Parser**, **Yutils (tstools)** |
| [Zheus Color](Zheus.md) | **aka.command** |
| [Hephaestus Fansubber](Hephaestus.md) | **ZF main**, **LineCollection**, **Tags**, **aka.command**, **ArchMath**, **Perspective**, **Util**, **ASSFoundation**, **dkjson**, **Yutils (tstools)** |

**Auto Blur → Use tracking data** optionally requests **DataWrapper** and its dependencies from Aegisub-Motion. `tstools.Yutils` provides Yutils; the distribution retains compatibility with `require("Yutils")`. DependencyControl includes `l0.dkjson`. Timing and some dependencies also use LuaJSON (`json`); keep its complete package and LPeg as described in the installation guide. Keep the libraries supplied with Aegisub (`karaskel`, `utils`, `aegisub.*`, LPeg and MoonScript).

## Third-party catalogs

In **DependencyControl → Install Script**, use **Modules:** for libraries and **Automation Scripts:** for macros. Add required feeds through **Manage Feeds**. Installed modules can be inspected in the update options.

| Name in Modules | Identifier | Catalog |
| --- | --- | --- |
| **Yutils (tstools)** | `tstools.Yutils` | [TypesettingTools/Yutils](https://github.com/TypesettingTools/Yutils) · [feed](https://raw.githubusercontent.com/TypesettingTools/Yutils/master/DependencyControl.json) |
| **ZF main** | `ZF.main` | [zeref](https://github.com/TypesettingTools/zeref-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/TypesettingTools/zeref-Aegisub-Scripts/main/DependencyControl.json) |
| **ASSFoundation** | `l0.ASSFoundation` | [ASSFoundation](https://github.com/TypesettingTools/ASSFoundation) · [feed](https://raw.githubusercontent.com/TypesettingTools/ASSFoundation/master/DependencyControl.json) |
| **(Almost) Functional Suite** | `l0.Functional` | [Functional](https://github.com/TypesettingTools/Functional) · [feed](https://raw.githubusercontent.com/TypesettingTools/Functional/master/DependencyControl.json) |
| **Line** | `a-mo.Line` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **LineCollection** | `a-mo.LineCollection` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **Log** | `a-mo.Log` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **Tags** | `a-mo.Tags` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **ArchMath** | `arch.Math` | [arch1t3cht](https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json) |
| **Perspective** | `arch.Perspective` | [arch1t3cht](https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json) |
| **Util** | `arch.Util` | [arch1t3cht](https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/TypesettingTools/arch1t3cht-Aegisub-Scripts/main/DependencyControl.json) |
| **SubInspector** | `SubInspector.Inspector` | [SubInspector](https://github.com/TypesettingTools/SubInspector) · [feed](https://raw.githubusercontent.com/TypesettingTools/SubInspector/master/DependencyControl.json) |
| **aka.command** | `aka.command` | [Akatsumekusa](https://github.com/Akatmks/Akatsumekusa-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/Akatmks/Akatsumekusa-Aegisub-Scripts/master/DependencyControl.json) |
| **ASS Parser** | `myaa.ASSParser` | [Myaamori](https://github.com/TypesettingTools/Myaamori-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/TypesettingTools/Myaamori-Aegisub-Scripts/master/DependencyControl.json) |
| **dkjson** | `l0.dkjson` | [DependencyControl](https://github.com/TypesettingTools/DependencyControl) · [feed](https://raw.githubusercontent.com/TypesettingTools/DependencyControl/publish/DependencyControl.json) |
| **DataWrapper** | `a-mo.DataWrapper` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **polyclipping** | `zpolyclipping.polyclipping` | [zeref](https://github.com/TypesettingTools/zeref-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/TypesettingTools/zeref-Aegisub-Scripts/main/DependencyControl.json) |
| **zimg** | `zimg.main` | [zeref](https://github.com/TypesettingTools/zeref-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/TypesettingTools/zeref-Aegisub-Scripts/main/DependencyControl.json) |
| **Transform** | `a-mo.Transform` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **petzkuLib** | `petzku.util` | [petzku](https://github.com/petzku/Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/petzku/Aegisub-Scripts/refs/heads/master/DependencyControl.json) |
| **DataHandler** | `a-mo.DataHandler` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **ShakeShapeHandler** | `a-mo.ShakeShapeHandler` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **requireffi** | `requireffi.requireffi` | [ffi-experiments](https://github.com/TypesettingTools/ffi-experiments) · [feed](https://raw.githubusercontent.com/TypesettingTools/ffi-experiments/master/DependencyControl.json) |

## Included modules

The distribution includes **seven common modules**, plus Automatons and MotionEngine.

| Module | Version | Responsibility |
| --- | --- | --- |
| `kite.Core` | 2.0.0 | Primitives and ASS text; Core.LineOps. |
| `kite.UI` | 2.0.3 | Dialogs, actions, shortcuts and UI.Settings. |
| `kite.PyBridge` | 2.0.1 | Processes, files and PyBridge.Media. |
| `kite.AssContext` | 2.0.1 | ASS state, temporal evaluation and AssContext.Color. |
| `kite.ShapeOptimizer` | 2.0.1 | Geometry optimization and ShapeOptimizer.AssDrawing. |
| `kite.EventOps` | 1.4.0 | Event operations, cleanup and Final Data. |
| `kite.Timing` | 1.5.0 | Timing, karaoke, waveform reading and localization. |
| `kite.Automatons` | 1.2.1 | Fansub Automatons installation, diagnosis and configuration. |
| `kite.MotionEngine` | 3.8.2 | Shared Moka Motion and Auto Motion engine. |

## Migration

Update macros and modules together. In custom scripts, replace former imports with these APIs:

| Previous | Current |
| --- | --- |
| `require("kite.LineOps")` | `require("kite.Core").LineOps` |
| `require("kite.Settings")` | `require("kite.UI").Settings` |
| `require("kite.Media")` | `require("kite.PyBridge").Media` |
| `require("kite.Color")` | `require("kite.AssContext").Color` |
| `require("kite.AssDrawing")` | `require("kite.ShapeOptimizer").AssDrawing` |

Store replaced copies in **Documents**, after checking their consumers. Keep one active copy of each macro. Auto Timing, audio and waveform controllers are integrated in Hephaestus; Timing supplies shared utilities and Automatons manages the backend.

## Shared backend

[Hephaestus](Hephaestus.md) manages **Fansub Automatons** through Install, Check and Configure. The package provides Auto Drawing, Auto Mask, Auto Motion and Auto Timing audio tools in one environment; Auto Blur analyzes video inside Aegisub. See [installation, space and recovery](FansubAutomatons.md).
