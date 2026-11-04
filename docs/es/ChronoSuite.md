# Chrono Suite 1.8.0

Chrono tiene botones directos para **Cleanup**, **Joinator** y **Final Data**. Los demás editores permanecen en Tools.

**Import Lines**, en Data Import, sustituye cada diálogo seleccionado por una copia completa del grupo ASS pegado. Conserva los tiempos de cada destino y todos los demás campos de las filas pegadas, incluidos comentarios, tags y espacios. Same Layers e Import as comments no alteran esta copia.

**Final Data** usa un solo cuadro con ocho filas: título, guion original, traducción, edición, tiempos, punto de sincronía, actualizado por y detalles. Cada fila vacía conserva la posición de su campo. Se puede copiar o pegar el bloque completo.

[English](../ChronoSuite.md) | Español | [Índice](../../README.es.md#documentación)

Chrono Suite reúne herramientas de sincronización, revisión, limpieza, importación y edición. Abre **Chrono Suite** para usar el panel, o **Chrono Suite/Config** y **Chrono Suite/Help**. Bajo **: Kite Hotkeys :/Chrono Suite/** están Audit Markers, las utilidades y las herramientas adicionales. [Auto Timing](AutoTiming.md) se abre desde Hephaestus.

La interfaz admite inglés, español y portugués. Los identificadores de las acciones permanecen en inglés para conservar atajos. Esta guía mantiene los nombres ingleses como referencia.

## Elegir una operación

- Para revisar tiempos, selecciona diálogos, aplica un preajuste de Audit y revisa las marcas de Effect. Usa esas marcas para orientar la revisión de la escena.
- Para ajustar al audio, abre [Auto Timing en Hephaestus](AutoTiming.md), elige Lazy o Busy y aporta sus datos. Comprueba primero Raw voice antes de añadir márgenes y ajustes a fotogramas clave.
- Para editar texto, activa la utilidad deseada. Las secciones no vacías se ejecutan en el orden del panel; deja vacías las demás.
- Para preparar créditos y propiedades, abre Final Data. Su limpieza opcional afecta al archivo completo.

La mayoría de las utilidades de texto excluyen comentarios y dibujos. Las operaciones de tiempo y etiquetas pueden incluir dibujos; ordenación, plegado y gestión de comentarios tienen su propio alcance. Borrado y división actualizan la selección. Count CPS, Select Time Range y Copy Fold permiten consultar o seleccionar datos. Usa Deshacer para revisar cambios, especialmente si combinas utilidades.

## Panel principal

Audit Markers aparece a la izquierda; Utility Tools, a la derecha; Data Import y Extra Tools, abajo. **EXECUTE** aplica las secciones activas. Los botones están ordenados **Execute, Cleanup, Joinator, Final Data, Config, Help, Cancel**. Cleanup abre Text and Tag Cleanup.

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
| Add Stutter / Normalize Stutter | Añade tartamudeo / normaliza iniciales y aplica [TT]. |
| Add Ah Prefix | Añade «ah» al inicio. |

### Tags / Comments

| Acción | Resultado |
| --- | --- |
| Fold by Identifier | Pliega grupos de al menos dos líneas con el mismo identificador. |
| Extract Tags | Traslada etiquetas del texto a Effect. |
| Reinsert Tags | Devuelve etiquetas de Effect al texto y cambia punto y coma por coma dentro de los bloques. |
| Remove Tags | Retira bloques de etiquetas. |
| Merge Tags | Une bloques de etiquetas adyacentes: `{\an5}{\blur2}` pasa a `{\an5\blur2}`. Conserva comentarios y bloques separados. |
| Remove Inline Comments | Retira comentarios internos. |
| Extract Actors and Split | Extrae información del actor del texto. |
| Swap Text and Comments | Intercambia texto visible y comentarios internos; conserva los tags. |
| Delete Comment Lines | Elimina filas comentadas. |
| Comments to Top / Bottom | Lleva comentarios al inicio / final de la selección. |
| Effects to Top | Lleva arriba las filas con Effect, conservando su orden relativo. |

### Smart

| Acción | Resultado |
| --- | --- |
| Smart Break | Equilibra ancho visual y pausas. |
| Smart Split | Divide frases con la onda de audio. |
| Bidirectional Snapping | Ajusta inicio y fin al fotograma clave más próximo dentro del alcance configurado. |
| Remove Honorifics | Encierra honoríficos japoneses en `{…}` para ocultarlos sin borrarlos de la fuente. |
| Caption Clarifier | Normaliza corchetes e indicaciones. |
| Complete Sentences | Une una oración incompleta con la siguiente si empieza en minúscula. Los solapes o continuaciones distintas se marcan `[POSSIBLE-JOIN]`. |
| Erase Blank Lines | Elimina líneas vacías. |
| Current Frame to Effect | Añade el fotograma actual del vídeo a Effect. |
| Copy Fold | Muestra filas ASS del pliegue de la primera línea seleccionada para copiarlas y selecciona ese pliegue. |

### Split / Join

| Acción | Resultado |
| --- | --- |
| Split by Sentence / Comma | Divide por oración / coma. |
| Pivot `\N` | Desplaza el salto. |
| Remove `\N` | Retira los saltos y consolida espacios. |
| Join Same Text | Une filas seleccionadas adyacentes con texto idéntico y estilo compatible. |
| Join Overlaps | Une grupos superpuestos, abarca sus límites y separa textos con `\N`. |
| Join Overlap Sentences | Une grupos superpuestos como oración en orden de filas; conserva la primera como base y amplía el final. |
| Divide by `\N` | Divide en cada salto existente. |

### Time / Sort

| Acción | Resultado |
| --- | --- |
| Copy Times | Copia tiempos de una línea a otras. |
| Select Time Range | Selecciona por intervalo. |
| Sort by Text Length / CPS | Ordena por longitud visible / velocidad de lectura. |
| Sort Odd Even | Ordena según el valor numérico par o impar de Effect. |
| Count CPS | Muestra CPS promedio. |
| Import Text | Importa texto externo para sustitución controlada. |
| Kite Timing | Aplica márgenes adaptables, encadenado y protección de bordes con los valores de Config. |
| Align to First Start | Desplaza desde la segunda fila para alinear su inicio al de la primera, conservando las distancias relativas. |
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
| Import Tags | Reemplaza tags iniciales desde una sola fuente con máximo solapamiento positivo; empates por orden pegado. |
| Song Sync | Duplica o sincroniza grupos usando una línea Comment de capa 50 como referencia. Añade el Effect seleccionado a las líneas importadas conservando sus Effects de origen. |
| Same Layers | Exige la misma capa para las cuatro importaciones anteriores. |
| Import as comments | Encierra el texto importado en `{…}`. |

## Tools y botones directos

- **After Effects Keyframes** se encuentra en [Rhea Signs → Tools](RheaSigns.md#after-effects-keyframes).
- **Text Replacer**: sustituye texto visible conservando etiquetas.
- **mpv QC**: lee `[hh:mm:ss.ms] [Type] Observation {suggested text}`. Añade `[QC: …]` a Effect y la sugerencia como comentario en el texto. La tolerancia se expresa en milisegundos.
- **Text and Tag Cleanup**: elimina los signos, espacios, comentarios y etiquetas elegidos.
- **Final Data**: edita título y créditos, con limpieza opcional de todo el archivo.

## Config

Guarda idioma (`en`, `es`, `pt`), pasos Lead-In/Lead-Out, distancias Chain, parámetros Kite Timing y alcances de ajuste a fotogramas clave. Audit Presets guarda umbrales Twin/Miss, duración, CPS, huecos, overtime y ancho.

## Final Data

Edita Title, Original Script, Original Translation, Original Editing, Original Timing, Synch Point, Script Updated By y Update Details. **Add episode from filename** requiere un archivo guardado con número de episodio y título no vacío. Reconoce SxxExx, omite sufijos de resolución/hash entre corchetes y conserva números de episodio largos. Un error mantiene el formulario; Save aplica y Cancel no cambia las propiedades.

**Clean the whole subtitle file** retira rutas del proyecto, datos extra, eventos comentados y comentarios internos; vacía Actor y Effect y elimina diálogos vacíos. Afecta a todos los eventos. Conserva una copia editable si esos campos contienen notas necesarias. La limpieza se puede cancelar y restaura el archivo si falla.

## Ejemplos y límites

- Joinator con filas a 4–5 s y 1–2 s produce un evento a 1–5 s y mantiene el texto en orden de filas. Conserva etiquetas iniciales y metadatos de la primera, no todo el formato intermedio de las demás.

## Preferencias y soporte

Se guardan las preferencias de cada herramienta.

[Discord de soporte](https://discord.gg/Egq8us4xZC).

## Unión, división y desplazamiento

**Joinator** sustituye a ChronoJoin. Tiene botones directos y una explicación fija:

- **Join:** combina texto visible, conserva los tags iniciales de la primera fila y baja la inicial tras coma o puntos suspensivos.
- **Keep Second:** exige dos filas y copia el segundo texto completo.
- **Keep Last:** copia el texto completo de la última fila seleccionada.
- **No Inner ...:** une y retira los puntos suspensivos internos.
- **One Phrase:** cambia puntos entre oraciones por comas y baja la inicial siguiente: `Hola. ¿Cómo estás?` → `Hola, ¿cómo estás?`. También acepta una sola fila. Conserva abreviaturas comunes, decimales, siglas y puntos suspensivos; revisa los nombres propios.

Todos conservan los demás campos de la primera fila y abarcan el inicio mínimo y el final máximo. El orden del texto es el orden de filas.

**Smart → Smart Split** sustituye a ChronoSplit. Comparte la lectura de waveform con Auto Timing, elige el nivel más fino y respeta el desplazamiento de exportaciones parciales. **Continuo** conserva los extremos y enlaza frases; **Raw** recorta cada frase a la actividad asignada. Los marcadores `[CS-*]` en Effect señalan estimaciones o dudas. Omite dibujos, karaoke y texto con animación temporal. **Smart Break** también está en Smart y equilibra ancho visual y pausas, respetando los saltos existentes.

**Karaoke → Shift Following Lines** sustituye a ChronoK. Desde la fila activa desplaza todas las filas de diálogo posteriores, incluidos comentarios, para dejar **100 ms** antes de la primera. Conserva duraciones y distancias relativas, sigue el orden de la lista y rechaza toda la operación si genera tiempos negativos.

**Import Tags** elige una única fuente por el mayor solapamiento positivo. En empate gana la primera en el texto pegado; las líneas que solo se tocan no coinciden. Reemplaza todos los tags iniciales del destino con el bloque de esa fuente; una fuente ganadora sin tags los elimina. Conserva comentarios, texto y tags internos del destino. Sin solapamiento no modifica nada. No combina fuentes ni acumula tags al repetir la importación.

**Normalize Stutter** normaliza las iniciales repetidas y aplica tartamudeo a las líneas con `[TT]`; es una acción directa.
