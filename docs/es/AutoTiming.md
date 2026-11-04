# Auto Timing

[English](../AutoTiming.md) | Español | [Índice](../../README.es.md#documentación)

Parte de [Hephaestus Fansubber](Hephaestus.md) **1.2.1**. Reúne el ajuste de tiempos de Chrono, Scream Detector, Chrono Audio, SCXvid y Wave2json en **Hephaestus Fansubber → Automatons → Auto Timing**.

| Entrada | Función |
| --- | --- |
| Timing | Ajusta las líneas con Lazy, Busy o Legacy. |
| Scream Detector | Marca intervalos de intensidad elevada para revisión. |
| Audio → Isolator | Separa voces conservando la línea de tiempo completa. |
| Audio → Signals | Genera señales desde una pista vocal sincronizada. |
| Audio → Complete | Combina separación y señales; admite vídeo para keyframes. |
| Keyframes | Extrae un registro SCXvid del vídeo elegido. |
| Waveform | Exporta el audio completo, un intervalo o un archivo por línea. |
| Settings | Elige idioma y sufijo del archivo de keyframes. |

## Preparar el audio

Instala desde **Hephaestus Fansubber → Install → Auto Timing** y revisa **Check → Auto Timing**. Las herramientas usan el entorno compartido y los medios del proyecto.

1. Abre **Audio → Isolator**, elige el audio o vídeo de entrada y la carpeta de salida.
2. Escoge **quality** (BS-RoFormer) o **fast** (MDX-Net), y el formato vocal `opus` o `wav`. El primer uso puede descargar el modelo del perfil.
3. Ejecuta **Audio → Signals** sobre las voces aisladas. Mantén el inicio y los silencios del medio original para conservar la sincronía.
4. Usa el JSON en Lazy o los archivos de señales en **Busy Files...**.

**Audio → Complete** realiza separación y generación en una sola operación. El campo **Video for keyframes (optional)** añade SCXvid cuando eliges un vídeo. **Replace existing generated files** autoriza reemplazar los resultados existentes. Revisa la carpeta y esa opción antes de ejecutar un procesamiento largo.

| Salida de Signals | Contenido |
| --- | --- |
| `*_Retimes_30.txt`, `*_Retimes_40.txt`, `*_Retimes_50.txt` | Silencios con tres umbrales. |
| `*_Retimes_vad.tsv` | Intervalos de actividad vocal. |
| `*_Retimes_flux.tsv` | Cambios de energía espectral. |
| `*_Retimes_spectrum.tsv` | Características espectrales para el análisis. |
| `*.waveform.json` | Picos de amplitud. |
| `*_envelope.tsv` | Envolvente RMS. |

Los nombres parten del archivo procesado. La separación puede conservar música o retirar parte de una voz: escucha los límites problemáticos antes de aplicar los tiempos al episodio.

## Timing

La ventana guarda sus propios valores de fuente, método, modo, detección, márgenes y silencios.

| Método | Datos |
| --- | --- |
| Lazy | Actividad de voz a partir de un JSON de picos. |
| Busy | Combina silencio, VAD, flujo, envolvente RMS y forma de onda opcional. Usa el módulo compartido Timing. |
| Legacy | Usa grupos de silencios, sin fotogramas clave, y escribe marcas `[LZ ...]`. Se abre desde Legacy... |

| Modo de Lazy/Busy | Operación |
| --- | --- |
| Full + polish | Detecta voz, añade márgenes, encadena y ajusta a fotogramas clave. |
| Raw voice | Ajusta a inicio/fin de voz sin márgenes ni fotogramas clave. |
| Post current | Conserva los tiempos como punto de partida y aplica solo márgenes, encadenado y fotogramas clave. |

**Waveform JSON** admite una ruta escrita o elegida con Browse. Se mantiene en caché durante la sesión; **Reload waveform cache** fuerza la lectura. Cambiar la ruta invalida la caché. Full + polish y Post current necesitan los fotogramas clave cargados en Aegisub. Raw voice trabaja con los límites de la voz detectada.

**Busy Files...** abre los archivos de entrada de Busy y aparece si faltan sus datos. El filtro de estilos admite All, All Default, Default+Alt o un estilo exacto, con otro estilo exacto adicional. Los problemas se marcan como `[TM-...]` en Effect —voz ausente, coincidencia débil, solape, duración corta o CPS alto— y se limpian en la siguiente ejecución.

## Detección y márgenes

Lazy suaviza la envolvente, aplica un umbral, limpia la máscara y obtiene el intervalo de voz. Busy comparte el ajuste final de márgenes.

- **Search ± (ms)**: cuánto buscar fuera de los límites actuales; cero limita la búsqueda a la línea.
- **Smoothing (ms)**: ancho del suavizado.
- **Auto threshold (Otsu)**: calcula el umbral voz/silencio; desactivado usa sensibilidad por percentil.
- **Bridge gaps / Drop islands (ms)**: cierra microsilencios y retira señales muy breves.
- **Trim small edge spill**: retira una señal débil y separada junto al borde para conservar el intervalo de la actividad principal.
- **Margins · post-timing**: lead-in/out, máximos de encadenado, ajustes a fotogramas clave, límite de corte de voz, duración mínima y aviso CPS.

Las duraciones parten de cero; suavizado e islas conservan mínimos útiles y los porcentajes permanecen entre 0 y 100. Ampliar la búsqueda puede incorporar voz ajena: ajústala a la escena.

## Keyframes

Abre **Keyframes**, selecciona el vídeo y la carpeta de salida. FFmpeg decodifica el medio y SCXvid genera el registro. Carga ese registro en Aegisub para usarlo en los modos de ajuste a fotogramas clave. **Settings** controla su sufijo; el predeterminado es `_keyframes.log`.

La exportación **After Effects Keyframes**, destinada a datos de movimiento, está en [Rhea Signs](RheaSigns.md#after-effects-keyframes).

## Scream Detector

Ejecuta `astats` de FFmpeg sobre el audio/vídeo y marca `[SCREAM]` en líneas con intensidad elevada según los criterios configurados y el conjunto analizado. Su criterio es la intensidad relativa; la identificación de voces y emociones requiere escuchar el audio.

| Control | Función |
| --- | --- |
| Average line dB | Potencia media del intervalo; un valor más cercano a cero exige mayor intensidad. |
| Strong sample dB | Umbral para contar muestras fuertes. |
| Strong sample ratio (%) | Proporción mínima de muestras fuertes. |
| Minimum samples | Cantidad mínima de muestras. |
| Robust z-score | Comparación con mediana y MAD del conjunto. |
| Apply to | Todo el diálogo o solo la selección. |
| Clear previous SCREAM marks | Retira marcas anteriores dentro del alcance. |
| Reuse existing analysis log | Reutiliza el registro sin ejecutar FFmpeg, útil al recalibrar. |

## Waveform

| Comando | Exportación |
| --- | --- |
| Full audio | Todo el audio activo. |
| Selected span | Del inicio más temprano al final más tardío de la selección, incluidos los huecos. |
| Each selected line | Un archivo por diálogo seleccionado. |

La herramienta usa el audio cargado o el del vídeo y obtiene FFmpeg desde la configuración compartida. Guarda los JSON junto al ASS o, si el proyecto todavía carece de ruta, junto al medio. El audio completo usa `Project.waveform.json`; las exportaciones parciales añaden sus tiempos.

Al terminar correctamente, cada exportación reemplaza el archivo del mismo nombre. En **Each selected line**, los archivos ya completados permanecen si una línea posterior falla.

FFmpeg convierte a PCM mono de 48 kHz y 16 bits. El nivel base resume 48 muestras por punto: un par mínimo/máximo por milisegundo. Los niveles siguientes agrupan pares vecinos. `sourceStartMs` sitúa las exportaciones parciales en el tiempo original; Timing y Smart Split de Chrono respetan ese desplazamiento.

`peaks` contiene pares enteros mínimo/máximo; `pointMs` debe ser positivo y finito. La amplitud ayuda a localizar actividad. La interpretación lingüística requiere revisar el audio.

### Ejemplo de una exportación parcial

Selecciona dos líneas de 10.0 a 11.5 s y de 12.0 a 13.0 s. **Selected span** exporta de 10.0 a 13.0 s, incluido el hueco. El lector usa el desplazamiento de 10.0 s para colocar los picos en el episodio. **Each selected line** genera dos archivos independientes con sus propios intervalos.

## Ajustes y revisión

Timing conserva método, archivos, sensibilidad y márgenes. Scream Detector guarda sus criterios. Al migrar, los valores reconocidos de Chrono se importan una vez. **Settings** ofrece inglés, español y portugués y permite ajustar el sufijo de keyframes.

Para empezar, prueba **Raw voice** en un tramo corto y escucha los bordes. Ajusta la búsqueda y los umbrales; después usa **Full + polish** para añadir márgenes, encadenado y keyframes. Las marcas `[TM-...]` y `[SCREAM]` señalan intervalos que requieren revisión.

## Validación de los tiempos

Antes de aplicar los tiempos, se comprueban los posibles solapes posteriores, aunque afecten a más de tres filas. Las líneas que ya estaban superpuestas conservan su tratamiento específico. El lector de waveform rechaza pares incompletos o amplitudes inválidas; `pointMs` admite notación científica completa y debe ser positivo y finito.
