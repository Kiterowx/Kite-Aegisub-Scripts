# Dependencias

[English](../Dependencies.md) | Español

Instala la macro desde su entrada normal o el catálogo Kite y actualiza las bibliotecas requeridas con DependencyControl. Las dependencias de terceros se resuelven desde sus propios catálogos. [Instalación](../../README.es.md#instalación).

## Dependencias por script

La tabla incluye las dependencias declaradas directamente y las que llegan a través de los módulos Kite. Las bibliotecas de Aegisub pertenecen al entorno de Automation.

| Script | Módulos de terceros |
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

**Auto Blur → Use tracking data** solicita **DataWrapper** de forma opcional. Sus dependencias se resuelven desde Aegisub-Motion. `tstools.Yutils` proporciona Yutils; la distribución mantiene compatibilidad con `require("Yutils")`. DependencyControl incluye `l0.dkjson`. Timing y algunas dependencias usan además LuaJSON (`json`); conserva su paquete completo y LPeg, como se explica en la instalación. Conserva las bibliotecas incluidas con Aegisub (`karaskel`, `utils`, `aegisub.*`, LPeg y MoonScript).

## Catálogos de terceros

En **DependencyControl → Install Script**, usa **Modules:** para las bibliotecas y **Automation Scripts:** para las macros. Añade los feeds necesarios desde **Manage Feeds**. Un módulo instalado se revisa desde las opciones de actualización.

| Nombre en Modules | Identificador | Catálogo |
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

<a id="modulos-incluidos"></a>

## Módulos incluidos

Se distribuyen **siete módulos comunes**, más Automatons y MotionEngine.

| Módulo | Versión | Función |
| --- | --- | --- |
| `kite.Core` | 2.0.0 | Primitivas, texto ASS y `Core.LineOps`. |
| `kite.UI` | 2.0.3 | Diálogos, acciones, atajos y `UI.Settings`. |
| `kite.PyBridge` | 2.0.1 | Procesos, archivos y `PyBridge.Media`. |
| `kite.AssContext` | 2.0.1 | Estado ASS, evaluación temporal y `AssContext.Color`. |
| `kite.ShapeOptimizer` | 2.0.1 | Optimización geométrica y `ShapeOptimizer.AssDrawing`. |
| `kite.EventOps` | 1.4.0 | Operaciones sobre eventos, limpieza y Final Data. |
| `kite.Timing` | 1.5.0 | Timing, karaoke, lectura de waveform y localización compartida. |
| `kite.Automatons` | 1.2.1 | Instalación, diagnóstico y configuración de Fansub Automatons. |
| `kite.MotionEngine` | 3.8.2 | Motor común de Moka Motion y Auto Motion. |

## Migración

Actualiza las macros y sus módulos juntos. Para scripts propios, sustituye las importaciones anteriores por estas APIs:

| Anterior | Actual |
| --- | --- |
| `require("kite.LineOps")` | `require("kite.Core").LineOps` |
| `require("kite.Settings")` | `require("kite.UI").Settings` |
| `require("kite.Media")` | `require("kite.PyBridge").Media` |
| `require("kite.Color")` | `require("kite.AssContext").Color` |
| `require("kite.AssDrawing")` | `require("kite.ShapeOptimizer").AssDrawing` |

Guarda las copias sustituidas en **Documents**, después de comprobar los scripts que las usan. Mantén una sola copia activa de cada macro. Los controladores de Auto Timing, audio y waveform se encuentran en Hephaestus; Timing comparte sus utilidades y Automatons administra el backend.

## Backend compartido

[Hephaestus](Hephaestus.md) administra **Fansub Automatons** desde Install, Check y Configure. El paquete incorpora Auto Drawing, Auto Mask, Auto Motion y las herramientas de audio de Auto Timing en un entorno común; Auto Blur analiza el vídeo desde Aegisub. Consulta [instalación, espacio y recuperación](FansubAutomatons.md).
