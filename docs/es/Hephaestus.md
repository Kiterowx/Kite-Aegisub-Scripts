# Hephaestus Fansubber

[English](../Hephaestus.md) | Español | [Índice](../../README.es.md#documentación)

Versión **1.2.1**.

Hephaestus reúne los cinco Autos en `kite.Hephaestus.lua`. Abre **Hephaestus Fansubber → Automatons** para trabajar; **Install**, **Check** y **Configure** administran el backend compartido **Fansub Automatons**.

| Herramienta | Trabajo |
| --- | --- |
| [Auto Drawing](AutoDrawing.md) | Convierte imágenes, secuencias y SVG a dibujos ASS. Es el nombre actual de PNG2ASS. |
| [Auto Mask](AutoMask.md) | Detecta superficies, reconstruye fondos y genera rellenos, formas o clips. |
| [Auto Blur](AutoBlur.md) | Calcula una curva de desenfoque a partir del vídeo, con muestra fija o seguimiento. |
| [Auto Motion](AutoMotion.md) | Calcula seguimiento, lo aplica al cartel y guarda una biblioteca para reaplicar o restaurar. |
| [Auto Timing](AutoTiming.md) | Ajusta tiempos y reúne separación vocal, señales, Scream Detector, keyframes y waveform. |

<a id="instalacion"></a>

## Instalación

1. Prepara Aegisub y DependencyControl siguiendo la [guía de instalación](../../README.es.md#instalación).
2. Copia `kite.Hephaestus.lua` a `automation/autoload` o instálalo desde el catálogo Kite. Abre su entrada normal para resolver los módulos requeridos y vuelve a escanear Automation.
3. Abre **Hephaestus Fansubber → Install → All automatons**. Para preparar una función concreta, elígela dentro de **Install**.
4. Ejecuta **Check → All automatons** y revisa los componentes indicados. **Details** muestra el diagnóstico técnico.
5. Abre la herramienta desde **Automatons** y prepara sus entradas.

El instalador usa Windows x64 y un Python privado. Prepara FFmpeg, FFprobe, las bibliotecas y los modelos requeridos; obtiene SCXvid de la distribución de su autor y verifica los archivos descargados. Auto Blur analiza el vídeo con las funciones de Aegisub.

**Configure** permite elegir la carpeta de instalación y el dispositivo `auto`, `cpu` o `cuda`. El modo automático decide según el controlador disponible. Una instalación nueva usa `%LOCALAPPDATA%\Kiterow\Fansub Automatons`.

La instalación integrada descarga la última versión estable compatible de [Fansub Automatons](https://github.com/Kiterowx/Fansub-Automatons/releases), comprueba el ZIP y su SHA-256 y prepara el entorno. Requiere una versión del backend igual o posterior a **1.2.1**.

## Espacio y modelos

Un entorno nuevo requiere al menos **14 GiB libres con CUDA** o **6 GiB con CPU**; el instalador mantiene una reserva de **2 GiB**. Son umbrales de instalación, y el espacio de trabajo y los medios de cada proyecto necesitan margen adicional.

El instalador reutiliza un entorno compatible y verificado. Las descargas de paquetes se realizan con la caché de pip desactivada. Auto Mask prepara sus modelos desde el instalador; la separación vocal obtiene el modelo del perfil elegido en su primer uso. Conserva esos modelos para reutilizarlos entre proyectos.

Los archivos sustituidos y el diario de recuperación se guardan en **Documents/Aegisub Maintenance/Fansub Automatons**. Guarda también ahí las copias retiradas de tus macros y módulos, fuera de las rutas que Aegisub carga.

## Actualizar una instalación anterior

Actualiza la macro y sus módulos como conjunto. Los siete módulos comunes siguen en `include/kite`; [Automatons y MotionEngine](Dependencies.md#modulos-incluidos) completan la integración de la suite.

| Nombre anterior | Ubicación actual |
| --- | --- |
| PNG2ASS | Automatons → Auto Drawing |
| AutoMask / AutoBlur / AutoMotion | Automatons → Auto Mask / Auto Blur / Auto Motion |
| Auto Timing y Scream Detector de Chrono | Automatons → Auto Timing → Timing / Scream Detector |
| Extract KF de Chrono | Automatons → Auto Timing → Keyframes |
| Chrono Audio | Automatons → Auto Timing → Audio |
| Wave2json | Automatons → Auto Timing → Waveform |
| Olympus | Fansub Automatons; administración desde Hephaestus |

Los ajustes reconocidos, atajos y favoritos se migran a las rutas actuales. Los ajustes de timing y Scream se importan una vez desde Chrono. [Chrono](ChronoSuite.md) conserva revisión, edición e importación; [Rhea](RheaSigns.md) incorpora la exportación After Effects Keyframes.

## Diagnóstico

**Check** revisa componentes, archivos y capacidades del backend. La comprobación de carga de una macro se realiza desde Automation en Aegisub. Si una operación indica un componente ausente, usa la opción correspondiente de **Install**, revisa **Check** y vuelve a intentarlo.

Para soporte, conserva el diagnóstico, la versión de Aegisub y el nombre de la operación. Las [dependencias](../../README.es.md#instalación) se actualizan desde sus catálogos y los programas del backend se administran desde Hephaestus.
