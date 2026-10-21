# Dependencias

[English](../Dependencies.md) | Español | [Índice](../../README.es.md#documentación)

La [instalación](../../README.es.md#instalación) separa los módulos de DependencyControl, las bibliotecas del entorno y los programas externos. Los módulos de terceros se preparan antes de copiar las macros a `autoload`.

## Dependencias por script

**aka.command** es una dependencia común de los 22 scripts a través de los módulos Kite. **dkjson** viene con DependencyControl y Allure lo declara expresamente. La tabla añade los módulos específicos usando sus nombres en **Modules:**; el [mapa de nombres e identificadores](../../README.es.md#3-módulos-de-terceros-desde-dependencycontrol) incluye sus feeds. Las dependencias internas de cada biblioteca se resuelven desde esos catálogos.

| Script | Módulos adicionales en **Modules:** |
| --- | --- |
| AddTexture | **ASSFoundation**, **ZF main** |
| Alecto KFX | Ninguno además de la dependencia común. |
| Allure | **dkjson** |
| AutoBlur | **DataWrapper** (solo tracking). |
| AutoMask | Ninguno además de la dependencia común. |
| Chrono Suite | Ninguno además de la dependencia común. |
| Cliptomaniac | **(Almost) Functional Suite**, **ASSFoundation**, **Line**, **Perspective**, **Util**, **ZF main** |
| Field Group Manager | Ninguno además de la dependencia común. |
| Gradient Row | **ASSFoundation**, **Line**, **LineCollection**, **Perspective**, **SubInspector** |
| Hotkeys | Ninguno además de la dependencia común. |
| Macaria Revert | Ninguno además de la dependencia común. |
| Moka Motion | **ArchMath**, **ASSFoundation**, **LineCollection**, **Perspective**, **Tags**, **Util**, **ZF main** |
| Obake | **ASSFoundation**, **Line** |
| PNG2ASS | **ZF main** |
| Pointiac | Ninguno además de la dependencia común. |
| Rhea Signs | **(Almost) Functional Suite**, **ASSFoundation**, **Line**, **LineCollection**, **Perspective**, **Util** |
| Selesub | **ASS Parser** |
| Snapshoter | **ASS Parser**, **LineCollection**, **Log** |
| Social Clip | **ASS Parser**, **ASSFoundation**, **LineCollection**; **SubInspector** (máscaras complejas). |
| Wave2json | Ninguno además de la dependencia común. |
| Zagreo Glyphs | **ASSFoundation**, **Line**, **LineCollection** |
| Zheus Colormanager | Ninguno además de la dependencia común. |

**DataWrapper** (`a-mo.DataWrapper`, catálogo Aegisub-Motion) se necesita solo para **Use tracking data** en AutoBlur. **SubInspector** llega también como dependencia de **ASSFoundation**; Social Clip lo usa para ciertas máscaras complejas. **Yutils** es obligatorio para Zagreo Glyphs y **ZF main**, y se usa en operaciones de curvas de ASSFoundation. **LuaJSON** (`json`) es necesario para **Line** y para leer ondas en Smart Split de Chrono. Yutils y LuaJSON se instalan aparte de este selector. Los módulos `aegisub.*` pertenecen al entorno de Aegisub.

## Módulos incluidos

Se copia completa la carpeta `automation/include/kite` del repositorio a `automation/include/kite` de Aegisub. Los scripts cargan los módulos que necesitan; se distribuyen juntos para mantener versiones compatibles.

| Módulo | Versión | Función |
| --- | --- | --- |
| `kite.AssContext` | 1.1.3 | Estilos, tags y tiempos ASS. |
| `kite.AssDrawing` | 1.0.3 | Dibujos y perfiles de conversión. |
| `kite.Color` | 1.2.2 | Colores y paletas. |
| `kite.Core` | 1.1.0 | Números y formato ASS. |
| `kite.EventOps` | 1.3.1 | Campos y limpieza del subtítulo. |
| `kite.LineOps` | 1.7.4 | Selección y edición de líneas. |
| `kite.Media` | 1.4.0 | Vídeo, audio y códigos de tiempo. |
| `kite.PyBridge` | 1.7.2 | Procesos externos y backends de Python. |
| `kite.Settings` | 1.0.1 | Preferencias compartidas. |
| `kite.ShapeOptimizer` | 1.3.3 | Optimización de dibujos y degradados. |
| `kite.Timing` | 1.4.3 | Timing y reconstrucción de karaoke. |
| `kite.UI` | 1.5.2 | Ventanas, favoritos y atajos. |

[DependencyControl.json](../../DependencyControl.json) indica las versiones mínimas por script. Los archivos instalables están en `automation/autoload` y `automation/include/kite`.

## Backends de Python

AutoMask y PNG2ASS necesitan Python de 64 bits, 3.10 o posterior, y Git para instalar desde GitHub. **Backend/Install or Update** instala las bibliotecas de Python; **Backend/Check** comprueba el intérprete seleccionado. FFmpeg se instala aparte.

| Backend | Bibliotecas instaladas por pip |
| --- | --- |
| [kite-png2ass](https://github.com/Kiterowx/kite-png2ass) | Pillow, OpenCV, NumPy, svgelements, svg2ssa, defusedxml, vtracer. |
| [kite-automask](https://github.com/Kiterowx/kite-automask) | NumPy, OpenCV, ONNX Runtime, PySide6, PNG2ASS. |

Las versiones y restricciones concretas se declaran en el `pyproject.toml` de cada backend. Los modelos de EfficientSAM y LaMa se descargan desde **AutoMask/Backend/Install Models** y ocupan espacio en disco aparte del código Python. No se necesitan para reconstruir degradados.

FFmpeg, FFprobe, SCXvid, fuentes tipográficas y soporte del renderizador se detallan en los [requisitos de instalación](../../README.es.md#5-programas-externos-según-la-herramienta).
