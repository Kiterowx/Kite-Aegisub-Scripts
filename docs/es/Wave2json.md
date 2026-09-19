# Wave2json 1.3.6

[English](../Wave2json.md) | Español | [Índice](../../README.es.md#documentación)

Wave2json exporta una forma de onda como pirámide JSON: una serie detallada de amplitudes mínimas y máximas, seguida de niveles cada vez menos detallados. Lee PCM y escribe niveles temporales por partes para no mantener todo el audio y sus niveles en memoria.

Se distribuye en `Macros-Lite` y registra tres acciones bajo **Wave2json**. No tiene ventana de configuración. Los atajos se asignan a las acciones; la raíz del menú no es ejecutable.

## Acciones

| Acción | Exportación |
| --- | --- |
| Full audio | Todo el audio activo. |
| Selected span | Un intervalo continuo del inicio más temprano al fin más tardío de la selección, incluidos sus huecos. |
| Each selected line | Un JSON por diálogo, en orden de filas. Las líneas superpuestas se exportan por separado. |

El archivo de audio activo tiene prioridad. Si no hay uno separado, se usa el audio del vídeo. La fuente debe existir. FFmpeg se busca en `PATH` y decodifica la primera pista de audio, `0:a:0`.

Las acciones de selección requieren diálogos sin comentar con tiempos finitos y duración positiva. Se eliminan índices duplicados y se notifican filas inválidas. Los inicios negativos se ajustan a cero. Si una línea queda vacía al ajustar o redondear a milisegundos, se rechaza.

## Archivos de salida

Los JSON se escriben junto al ASS guardado o, si no tiene ruta, junto al audio o vídeo. El nombre parte del ASS y, en su ausencia, del archivo multimedia.

- Audio completo: `Project.waveform.json`.
- Intervalo: `Project_1200-2800ms.waveform.json`.
- Por línea: `Project_1200-2800ms_line001_1200-2800ms.waveform.json`, seguido de `line002`, etc. El prefijo común procede de la primera línea; el sufijo final describe el intervalo de cada archivo.

Se normalizan los caracteres no admitidos por Windows y los nombres reservados, incluso antes de una extensión. Un JSON existente se sustituye de forma atómica cuando el nuevo se ha escrito correctamente. Estas acciones no muestran una confirmación de sobrescritura.

## Audio y tiempos

FFmpeg decodifica PCM mono de 48 kHz, 16 bits con signo y orden little-endian. Mezcla a mono las fuentes estéreo o multicanal; no se genera una serie por canal original.

Los intervalos usan búsqueda precisa después de inicializar el decodificador para conservar las muestras solicitadas en formatos comprimidos como AAC. Un intervalo tardío puede requerir decodificar audio anterior. El proceso permite cancelar.

El nivel base contiene un par mínimo/máximo por 48 muestras, equivalente a 1 ms. El grupo final se conserva aunque tenga menos muestras. Cada nivel siguiente combina pares vecinos con el mínimo menor y el máximo mayor, hasta llegar a un punto. Un punto impar final pasa al nivel siguiente.

`durationMs` procede de la cantidad real de muestras, con hasta seis decimales. Puede diferir del intervalo solicitado si la fuente termina antes. Los metadatos de origen registran lo solicitado y `totalSamples`, lo decodificado.

## Formato JSON

El esquema utiliza la **versión 1**, independiente de la versión de la macro.

```json
{
  "type": "waveform",
  "version": 1,
  "sampleRate": 48000,
  "channels": 1,
  "bits": 16,
  "amplitudeFormat": "s16",
  "amplitudeMin": -32768,
  "amplitudeMax": 32767,
  "pointLayout": "interleavedMinMax",
  "durationMs": 2,
  "totalSamples": 96,
  "levels": [
    {
      "scale": 1,
      "pointMs": 1,
      "samplesPerPoint": 48,
      "points": 2,
      "peaks": [-100, 200, -300, 400]
    },
    {
      "scale": 2,
      "pointMs": 2,
      "samplesPerPoint": 96,
      "points": 1,
      "peaks": [-300, 400]
    }
  ]
}
```

Las exportaciones de selección también incluyen `sourceStartMs`, `sourceEndMs`, `sourceDurationMs` y `sourceLineCount`. `peaks` es una lista plana que alterna mínimo y máximo; debe contener el doble de elementos que `points`. `samplesPerPoint` describe un grupo completo; el último puede ser menor.

Una decodificación vacía, un número impar de bytes PCM, un fallo de lectura, un cambio de tamaño del PCM o un nivel temporal incompleto hacen fallar la exportación.

## Cancelación y errores

`kite.PyBridge.runProcess` ejecuta FFmpeg sin consola visible en Windows, supervisa la cancelación y recoge su diagnóstico. No requiere Python para procesar la forma de onda.

Los PCM y niveles temporales se eliminan al terminar, cancelar o fallar. El JSON se construye por lotes y permite cancelar durante análisis y escritura. Si falla la escritura, se conserva el JSON anterior. En **Each selected line**, los archivos ya completados permanecen si falla una línea posterior; el mensaje identifica esa línea.

No se fija una duración máxima, un número de puntos o una cantidad de niveles. El espacio en disco, el tiempo de procesamiento, el sistema de archivos y los códecs de FFmpeg siguen limitando el trabajo. La pirámide conserva extremos de amplitud; no representa sonoridad RMS ni un espectro de frecuencias.
