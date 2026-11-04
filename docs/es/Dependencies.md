# Dependencias

[English](../Dependencies.md) | Español | [Índice](../../README.es.md#documentación)

La [instalación](../../README.es.md#instalación) separa los módulos de DependencyControl, las bibliotecas del entorno y los programas externos. Los módulos de terceros se preparan antes de copiar las macros a `autoload`.

## Dependencias por script

**aka.command** es una dependencia común de los scripts a través de los módulos Kite. **dkjson** viene con DependencyControl y Allure lo declara expresamente. La tabla añade los módulos específicos usando sus nombres en **Modules:**; el [mapa de nombres e identificadores](../../README.es.md#3-módulos-de-terceros-desde-dependencycontrol) incluye sus feeds. Las dependencias internas de cada biblioteca se resuelven desde esos catálogos.

| Script | Módulos adicionales en **Modules:** |
| --- | --- |
| AddTexture | **ASSFoundation**, **ZF main** |
| Allure | **dkjson** |
| Chrono Suite | Ninguno además de la dependencia común. |
| Cliptomaniac | **(Almost) Functional Suite**, **ASSFoundation**, **Line**, **Perspective**, **Util**, **ZF main** |
| Gradient Row | **ASSFoundation**, **Line**, **LineCollection**, **Perspective**, **SubInspector** |
| Hotkeys | Ninguno además de la dependencia común. |
| Moka Motion | **ArchMath**, **ASSFoundation**, **LineCollection**, **Perspective**, **Tags**, **Util**, **ZF main** |
| Obake | **ASSFoundation**, **Line** |
| Rhea Signs | **(Almost) Functional Suite**, **ASSFoundation**, **Line**, **LineCollection**, **Perspective**, **Util** |
| Selesub | **ASS Parser** |
| Zheus Colormanager | Ninguno además de la dependencia común. |

**SubInspector** llega también como dependencia de **ASSFoundation**. **Yutils** es obligatorio para **ZF main**, y se usa en operaciones de curvas de ASSFoundation. **LuaJSON** (`json`) es necesario para **Line** y para leer ondas en Smart Split de Chrono. Yutils y LuaJSON se instalan aparte de este selector. Los módulos `aegisub.*` pertenecen al entorno de Aegisub.

## Módulos incluidos

Se copia completa la carpeta `automation/include/kite` del repositorio a `automation/include/kite` de Aegisub. Los scripts cargan los módulos que necesitan; se distribuyen juntos para mantener versiones compatibles.

| Módulo | Versión | Función |
| --- | --- | --- |
| `kite.AssContext` | 1.1.3 | Estilos, tags y tiempos ASS. |
| `kite.Core` | 1.1.0 | Números y formato ASS. |
| `kite.EventOps` | 1.3.1 | Campos y limpieza del subtítulo. |
| `kite.PyBridge` | 1.7.2 | Procesos externos y backends de Python. |
| `kite.ShapeOptimizer` | 1.3.3 | Optimización de dibujos y degradados. |
| `kite.Timing` | 1.4.3 | Timing y reconstrucción de karaoke. |
| `kite.UI` | 1.5.2 | Ventanas, favoritos y atajos. |

[DependencyControl.json](../../DependencyControl.json) indica las versiones mínimas por script. Los archivos instalables están en `automation/autoload` y `automation/include/kite`.

FFmpeg, FFprobe, SCXvid, fuentes tipográficas y soporte del renderizador se detallan en los [requisitos de instalación](../../README.es.md#5-programas-externos-según-la-herramienta).
