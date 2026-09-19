# Dependencias

[English](../Dependencies.md) | Español | [Índice](../../README.es.md#documentación)

Los scripts necesitan estos 12 módulos incluidos en el repositorio. Copia la carpeta completa `Modules/kite/` en `automation/include/kite/` y actualízalos juntos. Sigue los pasos de [instalación](../../README.es.md#instalación) para preparar Aegisub y DependencyControl.

## Módulos incluidos

| Módulo | Versión | Función |
| --- | --- | --- |
| `kite.Core` | 1.1.0 | Números y formato ASS. |
| `kite.AssDrawing` | 1.0.3 | Dibujos y perfiles de conversión. |
| `kite.LineOps` | 1.7.4 | Selección y edición de líneas. |
| `kite.AssContext` | 1.1.3 | Estilos, etiquetas y tiempos ASS. |
| `kite.Color` | 1.2.2 | Colores y paletas. |
| `kite.EventOps` | 1.3.1 | Propiedades y limpieza del subtítulo. |
| `kite.Media` | 1.4.0 | Vídeo, audio y códigos de tiempo. |
| `kite.PyBridge` | 1.7.2 | Procesos externos y backends de Python. |
| `kite.ShapeOptimizer` | 1.3.2 | Optimización de dibujos y degradados. |
| `kite.Timing` | 1.4.3 | Timing y reconstrucción de karaoke. |
| `kite.Settings` | 1.0.1 | Configuración. |
| `kite.UI` | 1.5.1 | Ventanas, favoritos y atajos. |

[DependencyControl.json](../../DependencyControl.json) indica las versiones mínimas que necesita cada script.

## Bibliotecas Lua

Instala las bibliotecas indicadas para cada script en la [tabla principal](../../README.es.md#scripts). Los [enlaces de bibliotecas](../../README.es.md#bibliotecas-lua) llevan a sus repositorios. Conserva los archivos de Automation incluidos en Aegisub. Yutils necesita LuaJIT y libpng para leer PNG.

## Backends de Python

AutoMask y PNG2ASS necesitan Python de 64 bits, versión 3.10 o posterior. Instala Git para descargar los paquetes desde GitHub. OpenCV y las bibliotecas de la tabla se instalan automáticamente; FFmpeg se instala por separado.

| Backend | Versión | Dependencias |
| --- | --- | --- |
| `kite-png2ass` | 1.4.2 | Pillow, OpenCV, NumPy, svg2ssa, defusedxml y vtracer. |
| `kite-automask` | 0.4.2 | NumPy, OpenCV, ONNX Runtime, PySide6 y PNG2ASS. |

Para usar EfficientSAM y LaMa en AutoMask, instala los modelos desde **Backend/Install Models**. Los degradados funcionan sin ellos.
