# Kite Aegisub Scripts

[English](README.md) | Español

Desarrollo estas herramientas para trabajar con carteles, texto, timing y exportación en Aegisub. En este repositorio mantengo los scripts, sus módulos compartidos y las guías de uso. Puedes instalar cada macro por separado con sus dependencias.

## Scripts

| Script | Versión | Función |
| --- | --- | --- |
| [AddTexture](docs/es/AddTexture.md) | 2.2.1 | Texturas, patrones y efectos de dibujo. |
| [Allure](docs/es/Allure.md) | 1.2.8 | Biblioteca de carteles, movimiento y animación. |
| [Chrono Suite](docs/es/ChronoSuite.md) | 1.8.0 | Revisión, utilidades de texto, Import Lines, Cleanup, Joinator y Final Data. |
| [Cliptomaniac](docs/es/Cliptomaniac.md) | 0.4.8 | Editar clips rectangulares y vectoriales. |
| [Gradient Row](docs/es/GradientRow.md) | 1.9.2 | Degradados entre líneas y texto. |
| [Hephaestus Fansubber](docs/es/Hephaestus.md) | 1.2.1 | Los cinco Autos y la instalación del backend compartido. |
| [Hotkeys](docs/es/Hotkeys.md) | 2.0.4 | Atajos, favoritos y preferencias compartidas. |
| [Kiri-Shot](docs/es/KiriShot.md) | 1.0.0 | Capturas PNG, secuencias, máscaras y vídeo social. |
| [Moka Motion](docs/es/MokaMotion.md) | 3.8.2 | Aplicar el seguimiento de Mocha a la posición, escala, rotación y perspectiva de los subtítulos. |
| [Obake](docs/es/Obake.md) | 0.4.8 | Cadenas de transformaciones y transiciones. |
| [Rhea Signs](docs/es/RheaSigns.md) | 2.4.0 | Edición de carteles, etiquetas, dibujos, fuentes, fundidos y After Effects Keyframes. |
| [Selesub](docs/es/Selesub.md) | 2.2.0 | Filtrar, seleccionar y asignar campos por grupos con Fields. |
| [Zheus Color](docs/es/Zheus.md) | 1.0.0 | Paletas por actor, degradados y comparación de colores. |

### Hephaestus Fansubber

- [Auto Drawing](docs/es/AutoDrawing.md): Imágenes, SVG y secuencias.
- [Auto Mask](docs/es/AutoMask.md): Detección y reconstrucción de superficies.
- [Auto Blur](docs/es/AutoBlur.md): Curvas de desenfoque desde el vídeo.
- [Auto Motion](docs/es/AutoMotion.md): Seguimiento, historial y restauración.
- [Auto Timing](docs/es/AutoTiming.md): Lazy/Busy/Legacy, voces, señales, Scream Detector, keyframes y waveform.

## Instalación

El orden es: **Aegisub y DependencyControl → bibliotecas del entorno → módulos de terceros → scripts y módulos Kite → programas externos según el uso**. La entrada normal de las macros actuales permite resolver dependencias pendientes con DependencyControl. También puedes preparar los módulos desde el catálogo antes de copiar los scripts. Si la entrada no aparece, consulta los errores de carga de Automation.

### 1. Aegisub y DependencyControl

La distribución recomendada es [Aegisub de arch1t3cht — Migration Release 04](https://github.com/arch1t3cht/Aegisub/releases/tag/migration04-01), basada en [TypesettingTools/Aegisub](https://github.com/TypesettingTools/Aegisub). Auto Blur usa funciones de vídeo de la versión de arch1t3cht. Se conservan las carpetas y bibliotecas de Automation incluidas en Aegisub.

Si DependencyControl no aparece o falla después de instalar Aegisub Migration, puede repararse con la [versión 0.9.1](https://github.com/TypesettingTools/DependencyControl/releases/tag/v0.9.1):

1. Descargar **[DependencyControl-v0.9.1.zip](https://github.com/TypesettingTools/DependencyControl/releases/download/v0.9.1/DependencyControl-v0.9.1.zip)** desde los assets de la versión. Los enlaces **Source code** contienen el repositorio, no el paquete de instalación.
2. Cerrar Aegisub y extraer el contenido del paquete en `%APPDATA%\Aegisub\automation`, fusionando sus carpetas `autoload` e `include` con las existentes. No debe quedar otro nivel `automation\automation`.
3. Abrir Aegisub y comprobar que esté disponible **DependencyControl → Install Script** dentro de Automation. Para recargar scripts también se puede usar **Automation → Rescan Autoload Dir**.

Se utiliza la carpeta del perfil de usuario, no la de `Program Files`, donde las actualizaciones pueden fallar por permisos. Una instalación portátil debe usar sus rutas de Automation configuradas. En Linux la ruta habitual es `~/.aegisub/automation`; en macOS, `~/Library/Application Support/Aegisub/automation`.

La versión 0.9.1 corrige un caso de **Bad DependencyControl record** causado por módulos instalados manualmente cuya versión no se podía interpretar. No corrige una ruta equivocada ni instala programas externos. En Aegisub 3.4 o posterior, el paquete actual de DependencyControl para Windows/macOS incorpora sus componentes necesarios: ya no requiere instalar por separado DownloadManager, BadMutex ni PreciseTimer. Otras bibliotecas aún pueden necesitar **requireffi**, que se instala como dependencia de ZF. [Instrucciones oficiales](https://github.com/TypesettingTools/DependencyControl/blob/v0.9.1/README.md).

### 2. Bibliotecas del entorno

Estas bibliotecas se comprueban aparte de la lista anterior:

| Componente | Dónde se obtiene y cuándo se necesita |
| --- | --- |
| `karaskel.lua`, `utils.lua`, `aegisub.re`, `aegisub.unicode`, `aegisub.clipboard` y cargador de MoonScript | Forman parte del entorno de Automation de Aegisub. Se conservan los archivos de su distribución; no se buscan como módulos de este catálogo. |
| [Yutils (tstools)](https://github.com/TypesettingTools/Yutils) | Se instala como **Yutils (tstools)** (`tstools.Yutils`) desde DependencyControl. Lo requieren las macros de geometría y las bibliotecas que usan Yutils. Los scripts conservan compatibilidad con `require("Yutils")`. Requiere LuaJIT; libpng solo se necesita para su lector de PNG. |
| [LuaJSON](https://github.com/harningt/luajson) (`json`) | Lo necesitan **Line** de Aegisub-Motion, Smart Split de Chrono y Auto Timing para leer las ondas. Si falta, se copian `json.lua` y la carpeta `json` del directorio [lua del proyecto](https://github.com/harningt/luajson/tree/master/lua) a `automation/include`. Necesita LPeg (`lpeg`), incluido en el entorno Lua de las distribuciones recomendadas. Se conserva completa la carpeta `json`: dkjson no sustituye su API. |
| Fuentes tipográficas | Deben estar disponibles tanto para Aegisub como para el renderizador usado al exportar. |
| VSFilterMod | Los degradados de cuatro esquinas de Zheus requieren un renderizador compatible con esas extensiones. Instalar un módulo Lua no añade ese soporte a libass. |

### 3. Módulos de terceros desde DependencyControl

En **DependencyControl → Install Script** se elige el desplegable **Modules:**. **Automation Scripts:** es otro selector y contiene macros, no las bibliotecas de esta tabla. El nombre suele ir seguido de la versión y, si procede, del canal.

Se instala **aka.command** como dependencia común de los módulos Kite. Después se añaden los módulos de los scripts elegidos según la [tabla por script](docs/es/Dependencies.md#dependencias-por-script). **dkjson** viene en el paquete de DependencyControl; Allure lo declara expresamente. No hace falta instalar todas las bibliotecas del catálogo para usar una sola macro, revisa qué necesita.

| Nombre en **Modules** | Identificador en el código | Catálogo de origen |
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
| **dkjson** | `l0.dkjson` | [DependencyControl](https://github.com/TypesettingTools/DependencyControl) · [feed](https://raw.githubusercontent.com/TypesettingTools/DependencyControl/v0.9.1/DependencyControl.json) |
| **DataWrapper** | `a-mo.DataWrapper` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **polyclipping** | `zpolyclipping.polyclipping` | [zeref](https://github.com/TypesettingTools/zeref-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/TypesettingTools/zeref-Aegisub-Scripts/main/DependencyControl.json) |
| **zimg** | `zimg.main` | [zeref](https://github.com/TypesettingTools/zeref-Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/TypesettingTools/zeref-Aegisub-Scripts/main/DependencyControl.json) |
| **Transform** | `a-mo.Transform` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **petzkuLib** | `petzku.util` | [petzku](https://github.com/petzku/Aegisub-Scripts) · [feed](https://raw.githubusercontent.com/petzku/Aegisub-Scripts/refs/heads/master/DependencyControl.json) |
| **DataHandler** | `a-mo.DataHandler` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **ShakeShapeHandler** | `a-mo.ShakeShapeHandler` | [Aegisub-Motion](https://github.com/TypesettingTools/Aegisub-Motion) · [feed](https://raw.githubusercontent.com/TypesettingTools/Aegisub-Motion/DepCtrl/DependencyControl.json) |
| **requireffi** | `requireffi.requireffi` | [ffi-experiments](https://github.com/TypesettingTools/ffi-experiments) · [feed](https://raw.githubusercontent.com/TypesettingTools/ffi-experiments/master/DependencyControl.json) |

Por ejemplo, `l0.Functional` se busca como **(Almost) Functional Suite** y `myaa.ASSParser` como **ASS Parser**.

Si falta un catálogo, su enlace **feed** se añade desde **Manage Feeds**. Se revisan los avisos de confianza y se actualiza la lista. Un módulo ya instalado puede no aparecer en el selector de instalación: se comprueba en las opciones de actualización de DependencyControl. Las dependencias que requieran esas bibliotecas se resuelven desde sus propios feeds; no es necesario instalar la macro Aegisub-Motion para obtener **LineCollection**, por ejemplo.

La tabla también incluye dependencias indirectas: **petzkuLib** se instala con **aka.command**; **polyclipping**, **zimg** y **requireffi**, con **ZF main**; **Transform**, con **Line**. **DataWrapper** solo se necesita para el tracking de Auto Blur y añade **DataHandler** y **ShakeShapeHandler**. **SubInspector** forma parte de las dependencias de **ASSFoundation**, aunque no todas sus funciones lo utilicen.

### 4. Copiar la carpeta de Automation

El [repositorio](https://github.com/Kiterowx/Kite-Aegisub-Scripts) contiene una sola estructura de instalación:

```text
automation/
├── autoload/           13 scripts públicos (.lua y .moon)
└── include/
    └── kite/          9 módulos compartidos
```

Se copia la carpeta `automation` sobre `%APPDATA%\Aegisub\automation`, fusionando el contenido. También se pueden copiar sus dos carpetas por separado:

| Origen en el repositorio | Destino en Aegisub |
| --- | --- |
| `automation/autoload/` | `%APPDATA%\Aegisub\automation\autoload\` |
| `automation/include/kite/` | `%APPDATA%\Aegisub\automation\include\kite\` |

Para una instalación parcial, se dejan en la copia de `autoload` solo los scripts que se vayan a usar y se conserva completa la carpeta `include/kite`. Los archivos `.moon` se copian tal cual. Las bibliotecas de `include` no van dentro de `autoload`.

Al actualizar, se reemplazan scripts y módulos Kite juntos. Se retiran las copias antiguas de esas mismas macros para evitar registros duplicados y se reinicia Aegisub o se vuelve a escanear Automation. Las demás bibliotecas que ya haya en `include` se conservan.

El feed de Kite sirve para instalar y actualizar las macros y sus módulos desde DependencyControl:

```text
https://raw.githubusercontent.com/Kiterowx/Kite-Aegisub-Scripts/main/DependencyControl.json
```

### 5. Programas externos y backend compartido

| Programa | Uso |
| --- | --- |
| Python privado de 64 bits y bibliotecas Python | Fansub Automatons los prepara para Auto Drawing, Auto Mask, Auto Motion y el procesamiento de audio de Auto Timing. |
| FFmpeg y FFprobe | Procesamiento de medios en Hephaestus y exportaciones de Moka Motion y Kiri-Shot. FFprobe lee pistas y metadatos. El render ASS necesita libass y la exportación H.264, libx264. |
| SCXvid | **Hephaestus Fansubber → Automatons → Auto Timing → Keyframes**, junto con FFmpeg. El instalador obtiene y verifica el ejecutable. |
| x264 | Alternativa opcional en **Moka Motion → Create Video Clip**. |

Para los Autos, abre **Hephaestus Fansubber → Install → All automatons**, o selecciona una herramienta. Ejecuta después **Check → All automatons**. Auto Blur analiza los fotogramas dentro de Aegisub y requiere su API de vídeo.

La instalación integrada descarga la última versión estable compatible de [Fansub Automatons](https://github.com/Kiterowx/Fansub-Automatons/releases), comprueba el ZIP y su SHA-256 y prepara el entorno. Requiere una versión del backend igual o posterior a **1.2.1**. **Configure** permite elegir la carpeta de instalación y el dispositivo `auto`, `cpu` o `cuda`.

El instalador usa Windows x64. Un entorno nuevo requiere **6 GiB libres con CPU** o **14 GiB con CUDA**; estas cifras incluyen una reserva de **2 GiB**. Los modelos y los medios de trabajo requieren espacio adicional. Los componentes compatibles se verifican y reutilizan. Consulta la [instalación y recuperación de Fansub Automatons](docs/es/FansubAutomatons.md).

Para instalar desde un paquete, descarga y extrae la distribución de Fansub Automatons y ejecuta `Install.cmd`. Elige la misma carpeta de instalación al actualizar para reutilizar el entorno.

Moka Motion y Kiri-Shot permiten elegir FFmpeg en sus ajustes. También puedes añadirlo a `PATH`; reinicia Aegisub después de cambiar esa variable. En Windows se necesita PowerShell para supervisar los procesos externos. Auto Drawing puede convertir imágenes sin FFmpeg.

### Actualizar scripts y módulos

Distribuyo **siete módulos comunes** —Core, UI, PyBridge, AssContext, ShapeOptimizer, EventOps y Timing—, más **Automatons** y **MotionEngine**. Actualiza las macros y los nueve módulos juntos. La [referencia de dependencias](docs/es/Dependencies.md#modulos-incluidos) detalla sus versiones, funciones y migración.

Guarda las versiones sustituidas fuera de las rutas activas de Automation y conserva una sola copia de cada macro. Mantén las bibliotecas de terceros y los módulos que utilicen otros proyectos. Las guías de [Hephaestus](docs/es/Hephaestus.md), [Kiri-Shot](docs/es/KiriShot.md) y [Selesub](docs/es/Selesub.md#asignar-campos-con-fields) explican la migración de sus funciones integradas.

## Consultar dependencias en el código

Los `.lua` y `.moon` se pueden abrir con un editor de texto. Cerca del inicio suele estar el bloque `DependencyControl`, con los nombres de módulo y sus versiones mínimas. También se pueden buscar `require`, `requireModules` e `include`. Por ejemplo, `a-mo.LineCollection` se instala como **LineCollection**, aunque el identificador y el nombre del archivo sean distintos.

En [DependencyControl.json](DependencyControl.json), cada script declara `requiredModules`. Cuando aparece un módulo `kite.*`, se sigue su entrada en `modules` para consultar sus dependencias. Las bibliotecas de terceros también pueden requerir otros módulos. Una carga dentro de `pcall` puede corresponder a una función opcional; se contrasta con la guía del script antes de instalarla. No hace falta editar esos bloques para instalar una dependencia.

## Problemas de instalación

| Síntoma | Qué revisar |
| --- | --- |
| DependencyControl no aparece | Usar el ZIP de la versión, comprobar la ruta de usuario y los errores de carga en Automation. Evitar carpetas anidadas de más y copias antiguas del Toolbox en otra ruta de autoload. |
| **Bad DependencyControl record** | Actualizar al paquete 0.9.1 y volver a cargar. Si persiste, conservar el mensaje completo: hay otras causas posibles aparte de la corregida en esa versión. |
| `module '…' not found` o una macro no aparece | Buscar el identificador en la tabla, instalar el módulo correspondiente y revisar `include/kite`. Para `Yutils` o bibliotecas incluidas con Aegisub, revisar su instalación por separado. |
| Un módulo no sale en **Modules:** | Comprobar si ya está instalado, si su feed está añadido y habilitado, y si hay un aviso de confianza o un fallo de red. Revisar también que se esté usando **Modules:** y no **Automation Scripts:**. |
| Error HTTP, TLS o al descargar | Revisar conexión, proxy, antivirus y acceso al feed indicado por el error. El registro de DependencyControl está en la carpeta `log` del perfil de Aegisub. |
| Error de DLL, FFI o carga de una biblioteca nativa | Comprobar la compatibilidad del módulo con la versión y arquitectura de Aegisub. Reinstalar el paquete completo adecuado; cambiar de nombre una DLL no resuelve esa incompatibilidad. |
| Función inexistente en `kite.UI` u otro módulo Kite | Actualizar también los nueve módulos de `include/kite`; copiar solo la macro puede mezclar versiones incompatibles. |
| Entradas duplicadas en Automation | Buscar copias de la misma macro en las rutas de autoload configuradas. Conservar una sola copia activa. |
| El backend funciona en la terminal, pero falla en Aegisub | Comprobar la carpeta compartida en **Hephaestus Fansubber → Configure**, ejecutar **Check** y conservar el diagnóstico. |
| No se encuentra FFmpeg, FFprobe o SCXvid | Revisar el ejecutable configurado o `PATH` y reiniciar Aegisub tras cambiarlo. No se instalan con los módulos Lua. |

## Inicio, memoria y caché

Cada macro de `autoload` se carga al iniciar o volver a escanear Automation. Aegisub crea un entorno Lua por script, de modo que las bibliotecas usadas por varias macros pueden cargarse en varios entornos. El tiempo y la memoria dependen del conjunto instalado y del equipo; no hay un coste fijo por archivo.

Para reducir la carga, se mantienen en `autoload` solo las macros necesarias. Las demás pueden guardarse fuera de todas las rutas de autoload configuradas. Se conservan los módulos que necesiten las macros activas: estar en `include` no los convierte en macros que se ejecuten por sí solas.

DependencyControl guarda los catálogos descargados en `%APPDATA%\Aegisub\cache\l0.DependencyControl\feeds` con la configuración predeterminada. Esa caché evita repetir descargas; borrarla en cada inicio puede provocar más trabajo de red. La primera consulta de feeds, una actualización o una conexión lenta pueden añadir espera. Esta caché es distinta de la de audio/vídeo de Aegisub y de los modelos descargados por Auto Mask.

La política de actualización se guarda en `%APPDATA%\Aegisub\config\l0.DependencyControl.json`. En `updates.mode`, `auto-update` permite comprobaciones automáticas; `dependency-resolution` instala lo requerido sin las comprobaciones periódicas; `user-requested` limita la actividad a las acciones solicitadas en el Toolbox. Este último modo exige instalar manualmente las dependencias que falten. `off` también impide instalaciones. Los valores y sus efectos se describen en la [documentación de DependencyControl](https://github.com/TypesettingTools/DependencyControl/blob/v0.9.1/README.md#configuration).

## Soporte

El [Discord de soporte](https://discord.gg/Egq8us4xZC) recibe consultas sobre los scripts. Para revisar un fallo se necesitan el nombre y versión de la macro, la versión de Aegisub, el mensaje completo y los pasos que lo producen.

## Enlaces

- [Sitio del catálogo](https://kiterowx.github.io/Kite-Aegisub-Scripts-Guide/)
- [Chrono Generators](https://github.com/Kiterowx/Chrono-Generators-Scripts)
- [Arquitectura del Timing](https://kiterowx.github.io/Arquitectura-del-Timing/)

## Documentación

Las guías de cada script están enlazadas en el [catálogo de scripts](#scripts). La [guía de dependencias](docs/es/Dependencies.md) detalla los módulos necesarios para cada uno.

## Licencia

MIT. Véase [LICENSE](LICENSE).
