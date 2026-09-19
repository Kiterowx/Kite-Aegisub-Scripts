# Kite Aegisub Scripts

[English](README.md) | Español

Scripts de Aegisub para timing, carteles, karaoke y edición de subtítulos. En cada guía encontrarás las herramientas disponibles y cómo usarlas.

## Scripts

Sigue primero los pasos de [instalación](#instalación). La tabla indica los requisitos adicionales de cada script.

| Script | Versión | Idiomas de la interfaz | Requisitos |
| --- | --- | --- | --- |
| AddTexture | 2.1.8 | Inglés | ZF, ASSFoundation y un dibujo ASS en el portapapeles. |
| Alecto KFX | 3.4.3 | Español | `karaskel.lua`, incluido en Aegisub; karaoke temporizado para los efectos por sílaba. |
| Allure | 1.2.4 | Inglés y español | `l0.dkjson` y las fuentes del subtítulo. |
| AutoBlur | 2.1.4 | Inglés | Aegisub de arch1t3cht y vídeo cargado. |
| AutoMask | 2.5.5 | Inglés | Python 3.10+, backend de AutoMask, FFmpeg y vídeo cargado. |
| Chrono Suite | 1.5.3 | Inglés, español y portugués | JSON de Wave2json para Auto Timing; FFmpeg para Scream Detector; FFmpeg y SCXvid para Extract KF. |
| Cliptomaniac | 0.4.4 | Inglés y español | ZF, ASSFoundation, Functional, Aegisub-Motion y bibliotecas de arch. |
| Field Group Manager | 1.1.8 | Inglés | Sin requisitos adicionales. |
| Gradient Row | 1.8.9 | Inglés | Aegisub-Motion, ASSFoundation y arch.Perspective; SubInspector para medir el texto renderizado. |
| Hotkeys | 2.0.2 | Inglés | Sin requisitos adicionales. |
| Macaria Revert | 1.0.2 | Inglés | Líneas de karaoke generadas que quieras reconstruir. |
| Moka Motion | 3.7.6 | Inglés | Aegisub-Motion, ASSFoundation, bibliotecas de arch y ZF; FFmpeg para exportar. |
| Obake | 0.4.5 | Inglés y español | ASSFoundation y Aegisub-Motion. |
| PNG2ASS | 1.6.4 | Inglés | Python 3.10+ y backend de PNG2ASS. |
| Pointiac | 1.1.7 | Inglés | Vídeo cargado para los marcadores por fotograma. |
| Rhea Signs | 2.1.4 | Inglés, español y portugués | ASSFoundation, Functional, Aegisub-Motion y arch.Perspective. |
| Selesub | 2.1.8 | Inglés | `myaa.ASSParser`. |
| Snapshoter | 1.6.8 | Inglés | Aegisub-Motion, `myaa.ASSParser`, FFmpeg y vídeo cargado. |
| Social Clip | 1.0.3 | Español | Aegisub-Motion, ASSFoundation, `myaa.ASSParser`, FFmpeg/FFprobe y vídeo cargado; SubInspector para máscaras complejas. |
| Wave2json | 1.3.6 | Sin interfaz gráfica | FFmpeg en `PATH` y audio cargado. |
| Zagreo Glyphs | 1.2.3 | Inglés | Aegisub-Motion, ASSFoundation y Yutils. |
| Zheus Colormanager | 4.7.3 | Español | VSFilterMod para degradados de cuatro esquinas; vídeo cargado para ColorRelay. |

## Instalación

### 1. Aegisub y DependencyControl

Instala [Aegisub de arch1t3cht — Migration Release 04](https://github.com/arch1t3cht/Aegisub/releases/tag/migration04-01), basado en [TypesettingTools/Aegisub](https://github.com/TypesettingTools/Aegisub). Incluye las herramientas adicionales que utilizan estos scripts. También puedes consultar las [versiones de TypesettingTools](https://github.com/TypesettingTools/Aegisub/releases).

Instala [DependencyControl](https://github.com/TypesettingTools/DependencyControl#installation) y conserva los archivos de Automation incluidos con Aegisub. Estas instrucciones usan la carpeta de automatización de Windows: `%APPDATA%\Aegisub\automation`. Si usas una instalación portátil, sigue la ruta configurada en ella.

### 2. Scripts y módulos

Descarga este repositorio y copia:

| Origen en el repositorio | Destino en la carpeta de automatización |
| --- | --- |
| Los scripts que quieras de `Macros/` y `Macros-Lite/` | `autoload/` |
| La carpeta completa `Modules/kite/` | `include/kite/` |

**Copia los 12 módulos en `include/kite`, conservando la carpeta `kite`.** Los scripts necesitan los 12 módulos incluidos en el repositorio. Al actualizar, reemplaza tanto los scripts como los módulos. Retira las copias duplicadas y reinicia Aegisub o selecciona **Automation > Rescan Autoload Dir**.

### Bibliotecas Lua

Instala las bibliotecas indicadas para cada script mediante DependencyControl o desde sus repositorios. Si las copias manualmente, conserva su estructura de carpetas en `include`.

| Biblioteca | Módulos |
| --- | --- |
| [ASSFoundation](https://github.com/TypesettingTools/ASSFoundation) | `l0.ASSFoundation` |
| [Functional](https://github.com/TypesettingTools/Functional) | `l0.Functional` |
| [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) | `a-mo.*` |
| [Bibliotecas de arch](https://github.com/TypesettingTools/arch1t3cht-Aegisub-Scripts) | `arch.Math`, `arch.Perspective`, `arch.Util` |
| [ZF](https://github.com/TypesettingTools/zeref-Aegisub-Scripts) | `ZF.main` |
| [Scripts de Akatsumekusa](https://github.com/Akatmks/Akatsumekusa-Aegisub-Scripts) | `aka.command` |
| [Scripts de Myaamori](https://github.com/TypesettingTools/Myaamori-Aegisub-Scripts) | `myaa.ASSParser` |
| [SubInspector](https://github.com/TypesettingTools/SubInspector) | `SubInspector.Inspector` |
| [Yutils](https://github.com/Youka/Yutils) | `Yutils.lua` |

Instala `aka.command` para los procesos externos y `l0.dkjson` mediante DependencyControl. Usa las fuentes de los estilos del subtítulo. La [guía de dependencias](docs/es/Dependencies.md) recoge los módulos incluidos y los paquetes de Python.

### 3. Backends de Python

AutoMask y PNG2ASS necesitan **[Python](https://www.python.org/downloads/) de 64 bits, versión 3.10 o posterior**, con `pip`, y [Git](https://git-scm.com/downloads) en `PATH`.

1. Abre **AutoMask/Backend/Configure** o **PNG2ASS/Backend/Configure** y selecciona Python.
2. Ejecuta **Backend/Install or Update**.
3. Comprueba la instalación con **Backend/Check**.

**El instalador se encarga de OpenCV y las demás bibliotecas de Python.** Para usar EfficientSAM y LaMa en AutoMask, ejecuta también **AutoMask/Backend/Install Models**. La reconstrucción de degradados funciona sin esos modelos.

Para instalar desde una terminal:

```text
python -m pip install --upgrade "git+https://github.com/Kiterowx/kite-png2ass.git"
python -m pip install --upgrade "git+https://github.com/Kiterowx/kite-automask.git"
```

Ejecuta el comando del backend que necesites; AutoMask también instala PNG2ASS. Usa el mismo intérprete de Python en la terminal y en Aegisub.

### 4. FFmpeg y SCXvid

Instala [FFmpeg](https://ffmpeg.org/download.html), incluido FFprobe, y añádelo a `PATH` o selecciona su ejecutable en la configuración del script. Usa una compilación con libass y libx264 para renderizar subtítulos y exportar vídeo. Reinicia Aegisub después de cambiar `PATH`.

Para **Chrono Suite/Extract KF**, instala también el ejecutable de consola de SCXvid y configura ambas rutas en **Chrono Suite/Config > SCXvid**. Exporta el audio con Wave2json para obtener el JSON de forma de onda que utiliza Auto Timing.

El instalador de Python no instala FFmpeg ni SCXvid. Conserva Windows PowerShell para ejecutar los procesos externos.

## DependencyControl

El catálogo de actualizaciones contiene los 22 scripts y los 12 módulos de este repositorio:

```text
https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json
```

## Soporte

Para consultas y avisos de errores, entra al [Discord de soporte](https://discord.gg/Egq8us4xZC). Indica la macro, su versión, la versión de Aegisub y los pasos para reproducir el problema.

## Enlaces

- [Sitio del catálogo](https://kiterowx.github.io/Guide-Aegisub-Scripts/).
- [Chrono Generators](https://github.com/Kiterowx/Chrono-Generators-Scripts).
- [Guía de timing](https://kiterowx.github.io/Arquitectura-del-Timing/).

## Documentación

- [AddTexture](docs/es/AddTexture.md)
- [Alecto KFX](docs/es/AlectoKFX.md)
- [Allure](docs/es/Allure.md)
- [AutoBlur](docs/es/AutoBlur.md)
- [AutoMask](docs/es/AutoMask.md)
- [Chrono Suite](docs/es/ChronoSuite.md)
- [Cliptomaniac](docs/es/Cliptomaniac.md)
- [Dependencias](docs/es/Dependencies.md)
- [Field Group Manager](docs/es/FieldGroupManager.md)
- [Gradient Row](docs/es/GradientRow.md)
- [Hotkeys](docs/es/Hotkeys.md)
- [Macaria Revert](docs/es/MacariaRevert.md)
- [Moka Motion](docs/es/MokaMotion.md)
- [Obake](docs/es/Obake.md)
- [PNG2ASS](docs/es/PNG2ASS.md)
- [Pointiac](docs/es/Pointiac.md)
- [Rhea Signs](docs/es/RheaSigns.md)
- [Selesub](docs/es/Selesub.md)
- [Snapshoter](docs/es/Snapshoter.md)
- [Social Clip](docs/es/SocialClip.md)
- [Wave2json](docs/es/Wave2json.md)
- [Zagreo Glyphs](docs/es/ZagreoGlyphs.md)
- [Zheus Colormanager](docs/es/Zheus.md)

## Licencia

MIT. Consulta [LICENSE](LICENSE).
