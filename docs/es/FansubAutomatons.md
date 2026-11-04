# Fansub Automatons

[English](../FansubAutomatons.md) | Español | [Hephaestus](Hephaestus.md)

**Fansub Automatons** es el backend compartido que administra Hephaestus Fansubber. El paquete `fansub-automatons` reúne conversión de dibujos, reconstrucción de superficies, seguimiento y procesamiento de audio. Auto Blur analiza el vídeo dentro de Aegisub.

## Instalar desde Hephaestus

Abre **Hephaestus Fansubber → Install → All automatons** y después **Check → All automatons**. Install también ofrece herramientas individuales, medios y modelos de Auto Mask. **Configure** selecciona la carpeta de instalación y el dispositivo.

La instalación integrada descarga la última versión estable compatible de [Fansub Automatons](https://github.com/Kiterowx/Fansub-Automatons/releases), comprueba el ZIP y su SHA-256 y prepara el entorno. Requiere una versión del backend igual o posterior a **1.2.1**.

Si GitHub no ofrece una release estable compatible con el ZIP y su archivo `.sha256`, **Install** se detiene y muestra el diagnóstico. Para instalar desde los archivos del repositorio, usa `Install.cmd` en una copia completa de [Fansub Automatons](https://github.com/Kiterowx/Fansub-Automatons).

## Instalar desde el paquete

En Windows x64, extrae la distribución en una ubicación que puedas conservar y ejecuta **Install.cmd**. Prepara Python 3.13.7 privado, FFmpeg, FFprobe, dependencias Lua y las funciones Python elegidas. Usa Internet para los paquetes y modelos requeridos. SCXvid se obtiene de la release de su autor y se verifica antes de extraerlo con `tar.exe` de Windows.

```text
Install.cmd --modules all --compute auto
Install.cmd --modules chrono_audio --compute cpu
```

Los identificadores son `autoblur`, `automotion`, `automask`, `png2ass`, `chrono_audio` y `all`. `png2ass` corresponde a Auto Drawing y `chrono_audio`, a Auto Timing. `--home` selecciona la ubicación compartida y `--aegisub`, el perfil que contiene `automation` y `config`.

Un perfil nuevo recibe Hephaestus. Si Chrono ya está instalado, se actualiza con su integración correspondiente. Los archivos de terceros ausentes se obtienen del paquete verificado; se conservan las bibliotecas existentes. La entrada de compatibilidad de Yutils usa `tstools.Yutils`.

## Entorno, dispositivo y espacio

La ubicación predeterminada es `%LOCALAPPDATA%\Kiterow\Fansub Automatons`. `auto` elige el perfil de cómputo según el controlador disponible; `cpu` y `cuda` lo seleccionan explícitamente.

Crear un runtime requiere **14 GiB libres con CUDA** o **6 GiB con CPU**, con una reserva de **2 GiB**. Son umbrales del instalador; los medios, modelos y resultados de cada proyecto necesitan espacio adicional. Un entorno existente que coincide y está verificado se reutiliza.

El instalador comprueba los archivos registrados de los paquetes compatibles antes de reutilizarlos. Los archivos nativos pueden usar enlaces físicos cuando el volumen lo permite; los demás se copian al entorno privado. Los requisitos ausentes o incompatibles se instalan con la caché de pip desactivada. El Python original y el controlador de NVIDIA se conservan.

Auto Mask instala sus modelos con esa función y permite reponerlos mediante **Install → Auto Mask models**. La separación de audio obtiene el modelo elegido en el primer uso. Conserva las carpetas compartidas para reutilizarlas.

## Recuperación y migración

El runtime nuevo se verifica antes de activarlo. Los archivos sustituidos, la configuración y los diarios de recuperación se guardan en **Documents/Aegisub Maintenance/Fansub Automatons**. La activación usa reemplazos atómicos y reintenta bloqueos breves. Si falla, restaura el estado anterior; la siguiente ejecución puede recuperar una activación interrumpida. Los runtimes anteriores permanecen disponibles.

La configuración conserva `olympus.json` y los identificadores internos anteriores para migrar instalaciones. Los nombres de uso son Fansub Automatons y Hephaestus. Actualiza la macro y los [nueve módulos Kite distribuidos](Dependencies.md#modulos-incluidos) juntos; guarda las versiones sustituidas fuera de las rutas activas de autoload/include.

## Diagnóstico

**Check** revisa scripts, archivos de módulos, dependencias Python, herramientas y modelos. **Details** abre el diagnóstico técnico. Comprueba los scripts cargados desde Automation en Aegisub y verifica la operación con los medios del proyecto.

El paquete mantiene sus ejecutables en carpetas privadas y conserva PATH y las protecciones de Windows. Si una herramienta queda bloqueada, guarda el diagnóstico y revisa su origen y las políticas del equipo.

## Fuentes y licencias

SCXvid procede de [soyokaze, release r1](https://github.com/soyokaze/SCXvid-standalone/releases/tag/r1). El manifiesto identifica los archivos de Python y medios; las licencias Lua están en `LICENSES` y las de FFmpeg acompañan a sus herramientas.
