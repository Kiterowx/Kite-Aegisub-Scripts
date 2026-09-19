# Chrono Suite 1.5.3

[English](../ChronoSuite.md) | Español | [Índice](../../README.es.md#documentación)

Chrono Suite reúne herramientas de sincronización, revisión, limpieza, importación y edición. Abre **Chrono Suite** para usar el panel, o **Chrono Suite/Config** y **Chrono Suite/Help**. Bajo **: Kite Hotkeys :/Chrono Suite/** hay 83 acciones: Auto Timing, Extract KF, Scream Detector, Audit Markers, 74 utilidades y cinco herramientas adicionales.

La interfaz admite inglés, español y portugués. Los identificadores de las acciones permanecen en inglés para conservar atajos. Esta guía mantiene los nombres ingleses como referencia.

## Elegir una operación

- Para revisar tiempos, selecciona diálogos, aplica un preajuste de Audit y revisa las marcas de Effect. Son criterios de revisión, no diagnósticos definitivos.
- Para ajustar al audio, abre Auto Timing, elige Lazy o Busy y aporta sus datos. Comprueba primero Raw voice antes de añadir márgenes y ajustes a fotogramas clave.
- Para editar texto, activa la utilidad deseada. Las secciones no vacías se ejecutan en el orden del panel; deja vacías las demás.
- Para preparar créditos y propiedades, abre Properties and Cleanup. Su limpieza opcional afecta al archivo completo.

La mayoría de las utilidades de texto excluyen comentarios y dibujos. Las operaciones de tiempo y etiquetas pueden incluir dibujos; ordenación, plegado y gestión de comentarios tienen su propio alcance. Borrado y división actualizan la selección. Count CPS, Time Picker, Copy Fold y AE Export no editan el texto. Usa Deshacer para revisar cambios, especialmente si combinas utilidades.

## Panel principal

Audit Markers aparece a la izquierda; Utility Tools, a la derecha; Data Import y Extra Tools, abajo. **EXECUTE** aplica las secciones activas. Auto Timing, Extract KF, Config y Help abren sus ventanas. Auto Timing respeta Apply to y Filter.

**Text as {...}**, mostrado como **Texto en {...}** en español, introduce el texto importado en bloques de comentario. **Keyframe seal** muestra los códigos de sus marcas en la ayuda emergente.

## Apply to y Filter

| Apply to | Selección utilizada |
| --- | --- |
| All Selected | Toda la selección. |
| By Style | Estilo igual a Filter. |
| By Actor | Actor igual a Filter. |
| By Effect | Effect contiene el texto de Filter. |
| By Layer | Capa igual al número de Filter. |

## Preajustes de revisión

Los umbrales se definen en **Config > Audit Presets** y las marcas se escriben en Effect.

| Preajuste | Revisión |
| --- | --- |
| Ends Only / Start Only | Fin o inicio respecto a fotogramas clave cercanos; escribe Miss KF y Twin KF. |
| Full Audit | Texto, composición, tiempos, CPS, huecos y estructura. |
| Duration | Duraciones frente a Short y Long. |
| CPS | Velocidad frente al máximo configurado. |
| Short Gaps / Large Gaps | Huecos cortos o largos. |
| Both Gaps | Ambas comprobaciones; marca las dos líneas vecinas con el valor en milisegundos. |
| Overtime | Duración por encima de su máximo específico. |

Campos numéricos: **Short/Long** para duración; **Twin KF** para dos bordes próximos al mismo fotograma clave; **Miss KF** para fotogramas clave cercanos no alcanzados; **Overtime** para su preajuste; **Min/Max CPS** para lectura; **Short/Large gap** para huecos; **Max Width** para ancho visual en píxeles. Los tiempos se expresan en milisegundos.

## Fotogramas clave

- **KF Mode**: Start Only, End Only o Both.
- **KF Dir**: búsqueda hacia Back, Forward o Both. Vacío utiliza Back.
- **Keyframe Seal**: añade `START-ON-KF` o `END-ON-KF` si el borde coincide.
- **Mark continuous (0 ms)**: incluye huecos de cero milisegundos.
- **Ignore gap on KF**: omite huecos cuyo borde coincide con un fotograma clave.
- **Clear previous markers**: retira las marcas anteriores antes de escribir otras.

## Single Marker

Sustituye al preajuste por una comprobación individual. Las marcas se escriben en Effect.

| Marca o acción | Criterio |
| --- | --- |
| Number Effects | Numeración consecutiva. |
| Add Identifier | Identificador único de 14 dígitos por línea. |
| UPPERCASE | Texto completo en mayúsculas. |
| THREE-LINES | Texto mostrado en tres renglones. |
| NO-END-PUNCT / FINAL-COMMA | Ausencia de puntuación final / coma final. |
| UNPAIRED-PUNCT | Signos sin pareja. |
| STRONG-EXCL | Exclamación visible, incluida su variante de ancho completo. |
| STRONG-QUEST | Palabra con apertura `¿` y cierre `?`. |
| MIXED-EMPHASIS | Palabra con aperturas `¡¿` o cierres `?!` combinados. |
| SEMICOLON | Presencia de `;`. |
| STUTTER | Patrón X-X con la misma letra y un guion. |
| SHORT-LAST-LINE | Último renglón visualmente corto. |
| BROKEN-TAG | Bloque de etiquetas vacío o mal formado. |
| OVERLAP | Solape con otra línea. |
| DEFAULT-STYLE | Estilo Default. |
| ITALIC-ERROR | Inconsistencia de cursiva. |
| PARENTHESES | Paréntesis sin pareja. |
| NAME-PREFIX | Prefijo de nombre de hablante. |
| MULTI-SENTENCE | Más de una oración. |
| LINE-BREAK, POSITION-TAG, CLIP-TAG, FADE-TAG, TRANSFORM-TAG, KARAOKE-TAG | Presencia de salto o etiqueta correspondiente. |
| DRAWING-CLIP | Dibujo vectorial que también tiene `\clip` o `\iclip`. |
| COMMENT-BLOCK / HAS-DIGITS / HAS-CJK | Comentario interno / dígitos / caracteres CJK o kana. |
| FULL-ITALIC | Línea completa en cursiva. |
| DOUBLE-SPACE / EDGE-SPACE | Espacios dobles / espacios iniciales o finales. |

## Utility Tools

Cada sección tiene un desplegable independiente. Dejarlo vacío omite la sección.

### Case

| Acción | Resultado |
| --- | --- |
| Toggle `\an8` / Toggle Italics | Alterna alineación superior / cursiva. |
| Uppercase / Lowercase | Convierte todo el texto a mayúsculas / minúsculas. |
| Title Case | Inicial mayúscula por palabra. |
| Sentence Case | Inicial mayúscula por oración. |
| Capitalize First / Lowercase First | Cambia el primer carácter visible. |

### Punct / Text

| Acción | Resultado |
| --- | --- |
| Toggle ¡! / Toggle ¿? / Toggle ¡¿?! | Alterna signos de apertura. |
| Normalize Ellipsis | Unifica puntos suspensivos. |
| Add Ellipsis | Añade puntos suspensivos al final. |
| Erase Leading Ellipsis | Retira los iniciales. |
| Erase Inner Ellipsis | Retira los interiores y conserva los finales. |
| Ellipsis to Comma / Ellipsis to Period | Cambia los finales por coma / punto. |
| Unify Quotes / Latin Quotes («») | Unifica comillas / usa comillas angulares. |
| Normalize Dashes | Normaliza guiones y rayas. |
| Trim Trailing Spaces | Elimina espacios finales. |
| Remove Duplicate Letters | Elimina letras consecutivas repetidas. |
| Add Stutter / Stutter Manager | Añade tartamudeo / abre su gestor. |
| Add Ah Prefix | Añade «ah» al inicio. |

### Tags / Comments

| Acción | Resultado |
| --- | --- |
| Fold by Identifier | Pliega grupos de al menos dos líneas con el mismo identificador. |
| Extract Tags | Traslada etiquetas del texto a Effect. |
| Reinsert Tags | Devuelve etiquetas de Effect al texto y cambia punto y coma por coma dentro de los bloques. |
| Remove Tags | Retira bloques de etiquetas. |
| Merge Tags | Une bloques de etiquetas adyacentes: `{\an5}{\blur2}` pasa a `{\an5\blur2}`. Conserva comentarios y bloques separados. |
| Remove Comments | Retira comentarios internos. |
| Actor Parser | Extrae información del actor del texto. |
| Swap Comment | Alterna el estado de comentario. |
| Delete Comment Lines | Elimina filas comentadas. |
| Comments to Top / Bottom | Lleva comentarios al inicio / final de la selección. |
| Effects to Top | Lleva arriba las filas con Effect, conservando su orden relativo. |

### Smart

| Acción | Resultado |
| --- | --- |
| Bidirectional Snapping | Ajusta inicio y fin al fotograma clave más próximo dentro del alcance configurado. |
| Remove Honorifics | Encierra honoríficos japoneses en `{…}` para ocultarlos sin borrarlos de la fuente. |
| Caption Clarifier | Normaliza corchetes e indicaciones. |
| Complete Sentences | Une una oración incompleta con la siguiente si empieza en minúscula. Los solapes o continuaciones distintas se marcan `[POSSIBLE-JOIN]`. |
| Erase Blank Lines | Elimina líneas vacías. |
| Frame Effect | Escribe el fotograma inicial en Effect. |
| Copy Fold | Muestra filas ASS del pliegue de la primera línea seleccionada para copiarlas y selecciona ese pliegue. |

### Split / Join

| Acción | Resultado |
| --- | --- |
| Smart Break | Inserta `\N` si el ancho renderizado supera el disponible. |
| Split by Sentence / Comma | Divide por oración / coma. |
| Pivot `\N` | Desplaza el salto. |
| Remove `\N` | Retira los saltos y consolida espacios. |
| Join Lines | Une textos en orden de filas; abarca inicio mínimo y fin máximo y conserva metadatos de la primera fila. |
| Join Same Text | Une filas seleccionadas adyacentes con texto idéntico y estilo compatible. |
| Join Overlaps | Une grupos superpuestos, abarca sus límites y separa textos con `\N`. |
| Join Overlap Sentences | Une grupos superpuestos como oración en orden de filas; conserva la primera como base y amplía el final. |
| Divide by `\N` | Divide en cada salto existente. |

### Time / Sort

| Acción | Resultado |
| --- | --- |
| Copy Times | Copia tiempos de una línea a otras. |
| Time Picker | Selecciona por intervalo. |
| Sort by Length / CPS | Ordena por longitud visible / velocidad de lectura. |
| Sort Odd Even | Ordena según el valor numérico par o impar de Effect. |
| Count CPS | Muestra CPS promedio. |
| Import Text | Importa texto externo para sustitución controlada. |
| Kite Timing | Aplica márgenes adaptables, encadenado y protección de bordes con los valores de Config. |
| Shift First | Desplaza la selección para alinear la primera línea con el inicio de la segunda. |
| Start Snap Back / Forward | Lleva el inicio al fotograma clave anterior / siguiente. |
| End Snap Back / Forward | Lleva el fin al fotograma clave anterior / siguiente. |
| Add Lead-In Left / Right | Mueve el inicio atrás / adelante según el paso configurado. Si la anterior está encadenada a hueco cero, mueve también su fin. Con hueco positivo, el desplazamiento hacia atrás se detiene al tocarla. |
| Add Lead-Out Left / Right | Mueve el fin atrás / adelante y desplaza el inicio de la siguiente si están encadenadas. |
| Chain Left / Right | Extiende inicio / fin hasta la vecina dentro de la distancia máxima configurada. |

### Karaoke

**Romaji Karaoker (Word → `\k`)** genera karaoke de romaji por palabra con etiquetas `{\k}`.

## Data Import

Usa el texto pegado en su cuadro. Vacío omite la sección.

| Opción | Función |
| --- | --- |
| Import Effects / Import Text | Copia Effect / texto visible por solape temporal. |
| Import Actor | Copia el actor de la mejor coincidencia temporal. |
| Import Tags | Copia etiquetas iniciales y sustituye las equivalentes del destino. Ignora las posteriores al texto visible. |
| Song Sync | Duplica o sincroniza grupos usando una línea Comment de capa 50 como referencia. Añade el Effect seleccionado a las líneas importadas conservando sus Effects de origen. |
| Same Layers | Exige la misma capa para las cuatro importaciones anteriores. |
| Import as comments | Encierra el texto importado en `{…}`. |

## Extra Tools

- **AE Export**: exporta movimiento compatible con After Effects.
- **Text Replacer**: sustituye texto visible conservando etiquetas.
- **mpv QC**: lee `[hh:mm:ss.ms] [Type] Observation {suggested text}`. Añade `[QC: …]` a Effect y la sugerencia como comentario en el texto. La tolerancia se expresa en milisegundos.
- **Remover Assistant**: elimina los signos, espacios, comentarios y etiquetas elegidos; no los activa si faltan.
- **Properties and Cleanup**: edita título y créditos, con limpieza opcional de todo el archivo.

## Auto Timing

La ventana guarda sus propios valores de fuente, método, modo, detección, márgenes y silencios.

| Método | Datos |
| --- | --- |
| Lazy | Actividad de voz a partir de un JSON de picos. No necesita otro módulo de detección. |
| Busy | Combina silencio, VAD, flujo, envolvente RMS y forma de onda opcional. Requiere el módulo Kite Timing. |
| Legacy | Usa grupos de silencios, sin fotogramas clave, y escribe marcas `[LZ ...]`. Se abre desde Legacy... |

| Modo de Lazy/Busy | Operación |
| --- | --- |
| Full + polish | Detecta voz, añade márgenes, encadena y ajusta a fotogramas clave. |
| Raw voice | Ajusta a inicio/fin de voz sin márgenes ni fotogramas clave. |
| Post current | Conserva los tiempos como punto de partida y aplica solo márgenes, encadenado y fotogramas clave. |

**Waveform JSON** admite una ruta escrita o elegida con Browse. Se mantiene en caché durante la sesión; **Reload waveform cache** fuerza la lectura. Cambiar la ruta invalida la caché. Full + polish y Post current necesitan los fotogramas clave del vídeo; Raw voice no.

**Busy Files...** abre los archivos de entrada de Busy y aparece si faltan sus datos. El filtro de estilos admite All, All Default, Default+Alt o un estilo exacto, con otro estilo exacto adicional. Los problemas se marcan como `[TM-...]` en Effect —voz ausente, coincidencia débil, solape, duración corta o CPS alto— y se limpian en la siguiente ejecución.

## Detección y márgenes

Lazy suaviza la envolvente, aplica un umbral, limpia la máscara y obtiene el intervalo de voz. Busy comparte el ajuste final de márgenes.

- **Search ± (ms)**: cuánto buscar fuera de los límites actuales; cero limita la búsqueda a la línea.
- **Smoothing (ms)**: ancho del suavizado.
- **Auto threshold (Otsu)**: calcula el umbral voz/silencio; desactivado usa sensibilidad por percentil.
- **Bridge gaps / Drop islands (ms)**: cierra microsilencios y retira señales muy breves.
- **Trim small edge spill**: retira una señal débil y separada junto al borde para que no amplíe el intervalo.
- **Margins · post-timing**: lead-in/out, máximos de encadenado, ajustes a fotogramas clave, límite de corte de voz, duración mínima y aviso CPS.

Las duraciones son no negativas; suavizado e islas conservan mínimos útiles y los porcentajes permanecen entre 0 y 100. Ampliar la búsqueda puede incorporar voz ajena: ajústala a la escena.

## Extract KF

Genera un registro de fotogramas clave con SCXvid y FFmpeg para decodificar. Configura sus ejecutables y el sufijo del registro en **Config > SCXvid**.

## Scream Detector

Ejecuta `astats` de FFmpeg sobre el audio/vídeo y marca `[SCREAM]` en líneas con intensidad elevada según los criterios configurados y el conjunto analizado. No identifica emociones ni hablantes.

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

## Config

Guarda idioma (`en`, `es`, `pt`), rutas SCXvid/FFmpeg, sufijo del registro, pasos Lead-In/Lead-Out, distancias Chain, parámetros Kite Timing y alcances de ajuste a fotogramas clave. Audit Presets guarda umbrales Twin/Miss, duración, CPS, huecos, overtime y ancho. Auto Timing conserva sus opciones en su propia ventana.

## Properties and Cleanup

Edita Title, Original Script, Original Translation, Original Editing, Original Timing, Synch Point, Script Updated By y Update Details. **Add episode from filename** requiere un archivo guardado con número de episodio y título no vacío. Reconoce SxxExx, omite sufijos de resolución/hash entre corchetes y conserva números de episodio largos. Un error mantiene el formulario; Save aplica y Cancel no cambia las propiedades.

**Clean the whole subtitle file** retira rutas del proyecto, datos extra, eventos comentados y comentarios internos; vacía Actor y Effect y elimina diálogos vacíos. Afecta a todos los eventos. Conserva una copia editable si esos campos contienen notas necesarias. La limpieza se puede cancelar y restaura el archivo si falla.

## Ejemplos y límites

- Join Lines con filas a 4–5 s y 1–2 s produce un evento a 1–5 s y mantiene el texto en orden de filas. Conserva etiquetas iniciales y metadatos de la primera, no todo el formato intermedio de las demás.
- Auto Timing comprueba los posibles solapes posteriores, aunque impliquen más de tres filas. Las líneas originalmente superpuestas mantienen su tratamiento específico.
- Un JSON de forma de onda necesita `pointMs` positivo y finito y pares enteros mínimo/máximo en `peaks`. Se rechazan valores inválidos y pares incompletos. `pointMs` admite notación científica completa.
- FFmpeg y SCXvid necesitan archivos legibles y rutas configuradas. Su instalación es independiente de los módulos Lua.

## Preferencias y soporte

Se guardan las preferencias de cada herramienta.

[Discord de soporte](https://discord.gg/Egq8us4xZC).
