# Obake 0.4.5

[English](../Obake.md) | Español | [Índice](../../README.es.md#documentación)

Obake crea cadenas de transformaciones, aplica animaciones y capas, conecta pares de estados visuales y genera secuencias aleatorias o alternadas.

## Comandos

**Obake** abre el selector de acciones. **Execute** abre las opciones o ejecuta la acción directa. **Help** muestra ayuda contextual. **Language** cambia entre inglés y español sin perder la acción elegida. Cancelar las opciones regresa al selector; cancelar el selector sale. **Obake/Help** no requiere selección.

Las ocho acciones también están bajo `: Kite Hotkeys :/Obake/`, con el prefijo personalizado de DependencyControl si existe. Necesitan diálogos sin comentar; ZigZag requiere dos o más y In-Out, pares válidos.

| Acción | Entrada | Salida |
| --- | --- | --- |
| Apply chain | Líneas y estados temporales. | Etiquetas iniciales y transformaciones. |
| Animation FX | Líneas y preajuste. | Líneas editadas o capas del efecto. |
| Color preset | Líneas. | Capas de relleno, borde, brillo, sombra o limpieza. |
| Border layers | Líneas y bordes activos. | Un relleno y bordes acumulados. |
| Retime transforms | Transformaciones con tiempos explícitos. | Tiempos adaptados a la duración. |
| In-Out tags | Dos líneas por valor de Effect. | Una transición y fuentes comentadas. |
| Gunfight of Tags | Etiquetas numéricas o hexadecimales. | Estados aleatorios o fragmentos por fotograma. |
| ZigZag lines | Dos o más estados visuales. | Alternancia en su intervalo combinado. |

Las ediciones tienen una acción de Deshacer y se restauran al fallar o cancelar. La selección sigue a las sustituciones; In-Out selecciona las líneas nuevas. La API `dispatch` devuelve éxito como booleano y los comandos de Aegisub devuelven selección y línea activa.

Las preferencias se guardan entre sesiones. Cancelar cierra el formulario sin aplicarlo.

## Cadenas de transformaciones

La cuadrícula de etiquetas sirve para copiarlas a las filas de estados. Cada fila contiene tiempo y etiquetas sin llaves. Se muestran ocho por página. **Previous/Next** conserva ediciones; **Add+** duplica la última y abre su página; **Rem-** elimina la última, con un mínimo de dos; **Reset** restaura la cadena inicial. No hay un máximo de estados.

**Strip existing transforms** elimina `\t` fuera de transformaciones, respetando comentarios. La cadena se inserta en el bloque inicial o en uno nuevo antes del texto. Acceleration admite valores finitos positivos; los no positivos usan el predeterminado. Los valores pequeños no se redondean a cero.

| Shape | Interpretación de Value |
| --- | --- |
| Manual keyframes | Usa todas las filas; Value y Delay no definen sus tiempos. |
| Once (one-way) | Del primer al último estado durante el intervalo disponible. |
| Out and back | Ida y vuelta en dos mitades iguales. |
| Yoyo (N cycles) | Cantidad entera de ciclos, al menos uno. |
| Pulse (ms) | Duración de cada medio ciclo, al menos un milisegundo. |
| Steps (N) | Número de destinos interpolados, al menos dos. |

Los tiempos manuales usan **Percent** o **Milliseconds** y se limitan al intervalo de la línea. Las filas se ordenan; en tiempos repetidos prevalece la última. El primer contenido es el estado inicial y los siguientes son destinos de transformaciones. Un único contenido no vacío queda estático.

Los demás modos usan el primer y último contenido. Delay puede ser cero, milisegundos, porcentaje o fotograma actual. Desplaza el inicio de la animación, no el del evento. Un retraso situado al final no deja intervalo para animar.

Steps evalúa etiquetas escalares, colores, clips rectangulares, estilos y resets ordenados mediante ASSFoundation y AssContext. Cuatro pasos entre `\fscx100\fscy50` y `\fscx200\fscy150` generan destinos 125/75, 150/100, 175/125 y 200/150. Son transformaciones sucesivas, no estados mantenidos instantáneos. Siguen vigentes los límites de ASS sobre propiedades animables.

Se comprueba toda la selección antes de editar. Una línea de duración cero impide una aplicación parcial.

## Animation FX

El formulario contiene Preset, Strip existing transforms, Acceleration opcional, Step en milisegundos, Amount y dos colores. Cada efecto usa solo sus controles correspondientes. El texto se conserva salvo en efectos que lo dividen.

Con karaoke válido, el inicio del segundo bloque define un punto temporal interior. `\kt` fija un inicio absoluto y, si un bloque contiene varias duraciones, se usa la última. Comentarios y etiquetas dentro de transformaciones no crean puntos de karaoke. Los efectos que utilizan ese punto retiran las etiquetas de karaoke y conservan el resto. Sin él, las operaciones por fotograma usan el cursor de vídeo.

| Preajuste | Resultado y controles |
| --- | --- |
| Blur In / Blur Out | Desenfoque 8 → 0 o 0 → 8; aceleración opcional. |
| Fade In / Fade Out | Alfa global FF → 00 o 00 → FF; aceleración opcional. |
| Scale Up / Scale Down | Escala X/Y 100 → 115 o 115 → 100; aceleración opcional. |
| Pop In / Pop Out | Escala 40 → 100 con aparición, o 100 → 40 con desaparición; aceleración opcional. |
| Color Flash | Color 1 → Color 2 en el primer 30 % y regreso. |
| Color Pulse | Alterna Color 1/2; Step dura medio ciclo. |
| To Color (frame) | Lleva relleno, borde y sombra a Color 1 desde el punto de karaoke/cursor hasta el final. |
| To Style (frame) | Parte de Color 1 y alcanza los colores del estilo en ese punto. |
| Border Pulse | Una transición de borde 2 → 6; aceleración opcional. |
| Glow Pulse | Una transición de desenfoque 1 → 8 y borde 2 → 4; aceleración opcional. |
| Shake V / H / XY | Giro Z alternado alrededor de un origen desplazado; Step controla medio ciclo y Amount, el ángulo. |
| Wobble (frz) | Giro Z positivo/negativo; Step y Amount. |
| Glitch | Inclinación aleatoria y espaciado entero; Step y Amount. |
| Dramatic Pulse | Brillo que se expande y desvanece, con otra capa que pulsa y se estabiliza; Color 1 y Step. |
| Flashback (fad) | Entrada y salida de 200 ms. |
| Split Line | Revela la segunda parte en el punto temporal mediante dos eventos consecutivos. |
| Split Line Fad | Conserva la primera parte y añade la segunda en una capa superior con entrada de 250 ms. |
| Split Title | Dos capas simultáneas: relleno oculto abajo y borde cero arriba. |

Color Pulse, Shake, Wobble y Glitch admiten pasos desde un milisegundo. Dramatic Pulse mantiene un mínimo de expansión de 120 ms y un final de estabilización de 180 ms, también calculado a partir de 1.8 veces Step. Border Pulse y Glow Pulse realizan una sola transición pese a sus nombres.

Shake resuelve la posición con AssContext, incluidos estilo, márgenes y resolución. Crea un origen distante y gira alrededor de él; su movimiento aparente depende de los ejes y la geometría. No equivale a un seguimiento de traslación.

Para Split Line/Split Line Fad, usa `{\k20}First{\k80}Second` o coloca `|` entre las partes y el cursor dentro del evento. Se retira la barra. Un punto fuera del intervalo se rechaza. La división normal desplaza relojes de transformaciones, movimiento, desvanecimiento y karaoke para no reiniciarlos. Split Line Fad sustituye el desvanecimiento de la capa nueva por su propia entrada. Etiquetas intermedias pueden modificar el aspecto inicial del efecto.

## Capas de color y borde

| Color preset | Capas |
| --- | --- |
| Decompose (Fill + Border) | Abajo oculta relleno y conserva borde/sombra; arriba conserva relleno y elimina borde/sombra. |
| Blur + Glow | Abajo usa blur 3 y alfa global 80; arriba añade blur 0.6 si no existe un blur explícito fuera de transformaciones. |
| Shadtrick (Shadow Layer) | Abajo muestra la sombra con un pequeño desplazamiento X; arriba elimina sombra. |
| Double Border Blur | Relleno arriba, borde normal con blur 0.4 en medio y borde doble con blur 2 abajo. |
| Clean Layers (Flatten) | Retira alfas y marcadores CAL, y lleva cada línea a capa 0. |

Double Border Blur toma el mayor componente explícito no negativo de borde; si falta, usa el estilo y, si tampoco está disponible, 2. Clean Layers trata cada línea por separado y no reconstruye grupos ni une textos.

Border layers ofrece B1–B4 con activación, tamaño no negativo y color propios. Los tamaños se acumulan en el orden activo: B1=1 y B2=2 producen bordes 1 y 3. El relleno queda arriba. Sin bordes activos no hay sustitución. Los grupos reciben `[CAL-NNN]` conservando el resto de Effect.

Las capas retiran las propiedades que entran en conflicto, incluidas sus animaciones, y añaden los valores requeridos después de los resets. Las demás etiquetas y comentarios permanecen.

## Retime transforms

La acción directa toma el mayor fin explícito de transformación como duración de origen y escala los tiempos de `\t(t1,t2,...)` a la duración actual. No modifica tiempos del evento. La API también admite `retime_source`, `retime_target` y `retime_info`.

`\t(tags)` y `\t(accel,tags)` siguen ligados a la duración de la línea. Se conservan argumentos anidados y se ignoran ejemplos dentro de comentarios. Si no hay transformaciones temporizadas que cambiar, se informa.

## In-Out tags

Selecciona exactamente dos diálogos sin comentar por valor distinto de Effect. El valor vacío también forma un grupo: cuatro líneas con Effect vacío no se dividen en dos pares. Se ordenan por tiempo y, en empate, por fila.

Cada par debe tener estilo, capa y márgenes compatibles. Sus bloques iniciales aportan los estados. Las diferencias animables pasan a transformaciones y las posiciones, a movimiento. Las propiedades no animables deben coincidir. Los clips rectangulares solo interpolan si tienen el mismo tipo; se rechazan diferencias de trayectos vectoriales.

Posiciones y argumentos de clip/desvanecimiento deben ser números finitos completos, con signos o exponentes si hace falta. `1x` no se interpreta como 1. Ambos extremos deben tener posición explícita o ambos heredada.

Antes de combinar, convierte a estados estáticos o retira transformaciones existentes, desvanecimientos completos y karaoke. Se admite `\fad` inicial: la primera línea aporta entrada y la segunda, salida. Se notifican etiquetas intermedias distintas en textos visibles iguales. Si difiere el texto visible, una ventana permite elegir uno o cancelar.

La salida abarca del primer inicio al último fin, incluidos los huecos. Las fuentes se comentan y conservan sus datos. Todos los pares deben ser válidos antes de aplicar.

## Gunfight of Tags

Muestra las etiquetas numéricas y hexadecimales presentes con sus cantidades. Elígelas o usa **All/Clear**. No crea etiquetas ausentes a partir de los estilos.

| Control | Función |
| --- | --- |
| Min / Max | Variación aleatoria aditiva; se normaliza el orden. |
| Step | Cuantización de la variación; cero permite valores continuos. |
| Dec | Precisión de 0–8 decimales. |
| Seed | Semilla repetible; cero elige una nueva. |
| Link | Comparte variación por valor, línea, etiqueta, eje de línea o eje de etiqueta. |
| X / Y | Activa componentes de coordenadas. |
| Scalar/discrete | Activa valores escalares, discretos y color/alfa. |
| Times | Activa argumentos temporales admitidos. |
| Inside `\t` | Cambia etiquetas objetivo dentro de transformaciones. |
| `\t args` | Cambia tiempos/aceleración según categorías activas. |
| `{*}` blocks | Incluye esos bloques especiales en la lectura numérica. |
| Clamp ≥0 | Evita negativos en propiedades que los prohíben. |
| Discrete safe | Redondea valores discretos. |
| FBF period | Fotogramas por fragmento o filas por grupo enlazado. |
| Count selection as FBF unit | Trata una selección múltiple como secuencia existente. |
| Report | Muestra cambios, fuentes, semilla e información de fotogramas. |

Con varias líneas y Count selection activo, se usa el orden normalizado de filas. El período agrupa esa cantidad de filas bajo la misma secuencia aleatoria. Sus tiempos no cambian. El informe reconoce eventos de un fotograma, pero no los exige.

Con una fuente o Count selection desactivado, cada evento se divide usando los códigos de tiempo. Se conservan límites parciales. La variación se aplica antes de evaluar el estado al inicio de cada fragmento, con transformaciones ordenadas, movimiento, desvanecimientos, resets y karaoke. Los efectos no se reinician por fragmento.

Un período mayor que uno mantiene el estado muestreado durante ese tramo. Usa 1 para muestrear cada fotograma. No hay un máximo fijo de período o eventos. Se puede cancelar y la inserción usa lotes para respetar los argumentos de Lua. Memoria y fotogramas disponibles limitan el trabajo.

El generador aleatorio es independiente del estado global de Lua. Se respetan los rangos de bytes de color/alfa, dominios discretos ASS, semilla y precisión.

## ZigZag lines

Selecciona dos o más estados. Se alternan en orden de filas desde el inicio mínimo hasta el fin máximo, incluidos huecos. El período fija la longitud de cada fragmento en fotogramas. Las fuentes se sustituyen y la secuencia queda seleccionada.

Las etiquetas temporales se evalúan en el tiempo absoluto del fragmento respecto al inicio original de su plantilla. Una animación puede haber terminado si se usa después del fin de esa fuente; no se reinicia cada vez que reaparece. Usa intervalos coincidentes si todos los estados deben compartir el mismo reloj.

## Dependencias

Requiere ASSFoundation, `a-mo.Line`, Core, UI, LineOps, AssContext y Color. `AssContext.retimeSlice` conserva los relojes de transformaciones, movimiento, desvanecimientos y karaoke; normaliza intervalos de movimiento invertidos antes de desplazarlos.
