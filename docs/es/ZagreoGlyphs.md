# Zagreo Glyphs 1.2.3

[English](../ZagreoGlyphs.md) | Español | [Índice](../../README.es.md#documentación)

Zagreo Glyphs convierte texto uniforme o dibujos ASS en geometría vectorial y la deforma en el tiempo. Comenta las fuentes e inserta y selecciona los resultados después de cada una. Pair Morph comenta ambas entradas e inserta después de la segunda.

## Uso y menús

1. Selecciona diálogos sin comentar. Pair Morph requiere dos: la fila de menor índice es el origen y la otra, el destino.
2. Abre **Zagreo Glyphs**, elige categoría y efecto, y pulsa **Filter** para actualizar la lista de esa categoría.
3. **Run** abre parámetros; **Apply** valida y genera; **Back** regresa al selector; **Cancel** no modifica subtítulos.

Cada efecto tiene una acción bajo `: Kite Hotkeys :/Zagreo Glyphs/<Category>/<Effect>`. **Zagreo Glyphs/Help** recorre el mismo catálogo sin generar. Hay 230 efectos y 232 registros de menú.

El selector y los ajustes de cada efecto se guardan por separado. Si un valor no es válido, el formulario permanece abierto para corregirlo.

## Interpretación de fuentes

El estilo procede del documento. Se leen en orden las etiquetas iniciales y los resets `\r`/`\rStyle`. `\fs+N` y `\fs-N` siguen el tamaño relativo de ASS. La posición usa el primer `\pos`/`\move` efectivo, `\a`, alineación, márgenes y resolución. Sin posición explícita, el centro horizontal está entre los márgenes izquierdo y derecho.

ASSFoundation lee dibujos, convierte su escala `\p` y la escala de fuente a `\p1`, y AssDrawing valida el trayecto. Se conservan todos los contornos. Yutils aproxima curvas y divide segmentos para los efectos sobre vértices. Si un campo no cambia el resultado, se reutiliza el trayecto original para evitar diferencias de remuestreo.

La conversión de fuentes usa `Yutils.decode.create_font` y `font.text_to_shape`. Depende de las fuentes instaladas y de ese motor. En Windows, su conversión admite hasta 8192 unidades UTF-16; Zagreo no añade un límite de 80 caracteres ni de 7000 coordenadas.

Cada trayecto de salida tiene una apariencia. Se notifican mezclas de texto y dibujo, varios dibujos, cambios tipográficos o de apariencia intermedios, tipografía animada y saltos explícitos. Sepáralos antes en líneas uniformes. Revisa la conversión y el ajuste automático de renglones con el renderizador de Aegisub.

## Parámetros

| Control | Función |
| --- | --- |
| Target font | Fuente de destino, obligatoria en Font Morph. |
| Moments | Cantidad entera positiva de intervalos iguales en Moments only o sin tiempos de vídeo. |
| Ratios | Vacío reparte valores entre 0 y 1; un momento usa 1. Si se indica, debe haber una proporción finita por momento, separada por espacios o comas. El valor antiguo `0, 0.5, 1` se adapta al cambiar la cantidad. Los morph lineales admiten extrapolación; los elásticos y con curvas propias utilizan sus funciones. |
| Split len | Distancia positiva de muestreo en unidades del script. Valores pequeños generan más detalle y coste. Los contornos de morph mantienen al menos ocho muestras. |
| Strength | Amplitud no negativa: desplazamiento, porcentaje de escala, giro u otra magnitud según el efecto. Cero no siempre conserva la forma; en Boiling Line sí. |
| Frequency | Frecuencia espacial o cantidad no negativa según el efecto; los algoritmos de cantidad la redondean. |
| Scale | Escala positiva de muestreo del ruido; valores grandes suelen producir deformaciones más amplias. |
| Seed | Entero para ruido determinista. Misma fuente y opciones producen la misma salida. |
| Period ms | Duración no negativa del ciclo; cero usa la proporción del fragmento. |
| Pieces / Passes | Capas positivas por fragmento para Shatter / Sketch. |
| Blur | Desenfoque no negativo de Sketch. |
| Alpha | Entero 0–255: opaco–transparente. Sketch aplica su regla del 75 %; Shatter añade el alfa cuando no es cero. |
| Center X% / Y% | Desplazamiento del centro respecto a la mitad del ancho/alto; admite valores fuera de ±100. |
| Direction | Left to Right, Right to Left, Top to Bottom o Bottom to Top. |
| Timing | Auto frame ranges o Moments only. |
| Motion | Preserve source motion o Bake AE position data. |
| Ref frame | Fotograma de referencia desde 1, relativo al inicio del intervalo importado. |

No hay máximos fijos del script para momentos, capas, tamaño, período, semilla, fuerza, frecuencia, desenfoque o desplazamientos. Se requieren números finitos y cantidades enteras representables. Cada momento debe disponer de al menos un milisegundo entero. Memoria y precisión del renderizador siguen limitando el trabajo. Los bucles Lua permiten cancelar; una llamada nativa de Yutils debe terminar antes de detectar esa cancelación.

## Tiempos y movimiento

**Auto frame ranges** genera un estado por fotograma dentro del evento y usa Moments si faltan tiempos de vídeo. **Moments only** divide por igual. Pedir más momentos que milisegundos enteros produce un error, sin alargar la línea.

La geometría cambia entre fragmentos. Colores, borde, clips y otras animaciones `\t` admitidas conservan su reloj, igual que `\fad`, `\fade` y `\move`. Se mantienen extremos y tiempos de movimiento y la prioridad de la primera posición. Un origen explícito se conserva. Una línea móvil con giro/inclinación y sin `\org` necesita definirlo antes de cambiar de alineación.

Los eventos seleccionados con el mismo UUID `a-mo` comparten progreso en orden temporal. Se concatenan sus duraciones y no se suman los huecos. Las copias generadas pierden el marcador de seguimiento `a-mo`, conservando otros datos extra; los originales mantienen los suyos.

**Bake AE position data** suma desplazamiento importado al movimiento original. Admite filas `X Y`, `Frame X Y` y `Frame X Y Z`, con exponentes. En bloques AE, Position tiene prioridad sobre Anchor Point y la lectura termina en la siguiente propiedad. Z se ignora. Las filas numeradas deben crecer estrictamente; los huecos se interpolan linealmente y fuera del intervalo se mantiene el extremo más cercano. Usa coordenadas del script, sin deducir escala, giro o perspectiva de la composición AE. Para eso utiliza Moka Motion.

## Familias y representación

| Familia | Operación |
| --- | --- |
| Morph | Font Morph usa el mismo texto en otra fuente; Pair Morph interpola las dos selecciones durante su intervalo combinado; Shape Morph crea destinos por contorno. Los contornos se emparejan por índice, se muestrean por longitud y se ajustan en orientación e inicio. No se identifican letras equivalentes por significado. |
| Surface, Wave, Radial, Edge, Ink, Drip | Desplazan vértices según fase, límites, normales, tangentes, ruido y controles. |
| Path, Reveal | Conservan fragmentos, crean puntos o desplazan una frontera. ASS cierra los subtrayectos rellenos; no son trazos centrales de grosor automático. |
| Dissolve, Fold, Impact, Glitch | Transiciones geométricas, pliegues, impactos y alteraciones de coordenadas. |
| Contour | Transforma cada contorno alrededor de su propio centro. El exterior y los huecos de una letra pueden ser contornos distintos. |
| Shatter | Muestrea píxeles rellenos y crea partículas romboidales. Split len controla distancia y tamaño; Pieces reparte partículas entre capas. Es una aproximación del relleno. |
| Sketch | Superpone pasadas con ruido, desenfoque y alfa. |

Solo se unen eventos vecinos visualmente estáticos con texto, estilo, capa, actor, márgenes, comentario y datos extra iguales. Las etiquetas temporales impiden uniones que cambien su interpretación. Effect conserva la procedencia y el primer fragmento del grupo unido. Toda la salida se prepara antes de editar; un fallo de inserción restaura el archivo.

## Ejemplos

- Para animar un contorno uniforme, usa Boiling Line, Strength 3–6, Split len 4 y Auto frame ranges. Aumenta Split len para reducir vértices.
- Para tres estados de fuente, usa Font Morph, Target font, Moments only, Moments 3 y Ratios vacío: origen, intermedio y destino ocupan intervalos iguales.
- Con filas `10 100 200` y `14 140 240`, Bake AE position data y Ref 1, el fotograma relativo 3 toma (120,220) y suma (+20,+20) a la posición original.
- Los dibujos con más de 7000 coordenadas conservan sus contornos. El efecto puede aumentar la geometría y el tiempo necesario.

## Catálogo de efectos

Los nombres de categoría y efecto coinciden con los menús. Las descripciones indican el movimiento previsto; consulta los límites de representación de cada familia.

| Categoría | Efecto | Operación |
| --- | --- | --- |
| Morph | Font Morph | Transforma el mismo texto entre dos fuentes mediante estados vectoriales intermedios. |
| Morph | Font Morph Elastic | Transforma entre fuentes con sobrepaso y retroceso elástico. |
| Morph | Font Morph Overshoot | Sobrepasa la fuente de destino antes de estabilizarse. |
| Morph | Font Morph Anticipation | Retrocede brevemente antes de transformarse a la fuente de destino. |
| Morph | Font Morph Bounce | Llega a la fuente de destino con rebotes. |
| Morph | Font Morph Steps | Transforma entre fuentes mediante estados escalonados. |
| Morph | Font Morph Glitch | Altera las coordenadas de los estados intermedios de fuente. |
| Morph | Font Morph Rubber | Estira los estados intermedios como material elástico. |
| Morph | Pair Morph | Transforma la primera línea seleccionada en la segunda. |
| Morph | Pair Morph Elastic | Transforma las selecciones con sobrepaso y retroceso elástico. |
| Morph | Pair Morph Overshoot | Sobrepasa la segunda selección antes de estabilizarse. |
| Morph | Pair Morph Bounce | Llega a la segunda selección con rebotes. |
| Morph | Blob Morph In | Cada contorno entra como una masa redondeada y adopta la forma original. |
| Morph | Blob Morph Out | Los contornos se redondean en masas durante la salida. |
| Morph | Blob Pulse | Alterna entre contornos originales y masas redondeadas. |
| Morph | Line Sweep In | Despliega los contornos desde trazos horizontales planos. |
| Morph | Line Sweep Out | Colapsa los contornos en trazos horizontales planos. |
| Morph | Spike Morph In | Convierte estallidos de puntas en los contornos originales. |
| Morph | Spike Morph Out | Transforma los contornos en estallidos de puntas al salir. |
| Morph | Scribble Morph In | Ordena garabatos hasta formar el dibujo. |
| Morph | Scribble Morph Out | Deshace los contornos en garabatos. |
| Surface | Boiling Line | Oscilación orgánica de todos los puntos, sincronizada con el período. |
| Surface | Electric Jitter | Sacudidas bruscas por fotograma, sin suavizado. |
| Surface | Handwriting Noise | Oscilación lenta del contorno con apariencia de dibujo manual. |
| Surface | Ink Wobble | Balanceo sinusoidal del contorno. |
| Surface | Fine Contour Jitter | Sacudidas pequeñas y rápidas por punto. |
| Surface | Coarse Zone Jitter | Desplaza juntas regiones amplias de la forma. |
| Surface | Organic Drift | Deformación lenta y errante sin repetición periódica. |
| Surface | Heat Haze | Bandas de distorsión que ascienden como aire caliente. |
| Surface | Water Flow | Ondulación de refracción que se desplaza lateralmente. |
| Surface | Gelatin Wobble | Oscilación lenta elástica con retorno amortiguado. |
| Surface | Underwater Sway | Balanceo amplio y lento con refracción fina. |
| Surface | Windblown Turbulence | Ráfagas direccionales que deforman el contorno. |
| Surface | Static Buzz | Alterna desplazamientos cada fotograma. |
| Wave | Wave Horizontal | Onda horizontal que atraviesa el dibujo. |
| Wave | Wave Vertical | Onda vertical que atraviesa el dibujo. |
| Wave | Wave Diagonal | Onda diagonal que atraviesa el dibujo. |
| Wave | Standing Wave | Onda estacionaria con nodos fijos y vientres oscilantes. |
| Wave | Flag Wave | La onda aumenta al alejarse del borde sujeto. |
| Wave | Skip Rope | Balancea la forma como una cuerda sujeta por ambos extremos. |
| Wave | Seaweed Sway | Mantiene la base fija y aumenta el balanceo hacia arriba. |
| Wave | Twist Wave | Propaga variaciones de giro como una cinta retorcida. |
| Wave | Whip Crack | Un pico de amplitud atraviesa la forma por período. |
| Wave | Ripple Center | Onda circular desde el centro. |
| Wave | Ripple Point | Onda circular desde un punto ajustable. |
| Wave | Ripple Rain | Crea ondas desde puntos aleatorios sucesivos. |
| Wave | Cross Ripple | Interferencia entre ondas de dos orígenes. |
| Wave | Bounce Wave | Onda rectificada cuyas crestas rebotan. |
| Wave | Wave Settle In | Entra con una onda intensa que se amortigua. |
| Wave | Wave Break Out | La onda crece hasta deshacer la forma al salir. |
| Radial | Twist Sway | Tuerce la forma hacia ambos lados alrededor del centro. |
| Radial | Vortex Swirl | Circulación continua alrededor del centro con atenuación radial. |
| Radial | Magnet Pulse | Un punto desplazado atrae el contorno mediante pulsos. |
| Radial | Pinch Pulse | Contrae rítmicamente hacia el centro. |
| Radial | Bulge Pulse | Expande rítmicamente desde el centro. |
| Radial | Heartbeat | Dos pulsos radiales por período. |
| Radial | Spring Boing | Compresión y estiramiento con rebote amortiguado. |
| Radial | Lens Sweep | Una protuberancia de aumento recorre la forma. |
| Radial | Shockwave | Un anillo de desplazamiento avanza hacia fuera por período. |
| Radial | Pulse Rings | Anillos concéntricos alternan expansión y contracción. |
| Radial | Lag Orbit | Órbita pequeña con retraso de los puntos interiores. |
| Edge | Rough Edge | Rugosidad de varias escalas sobre la normal del contorno. |
| Edge | Rough Edge Progressive | La rugosidad aumenta durante la línea. |
| Edge | Rough Edge Calming | La rugosidad disminuye hasta recuperar el contorno. |
| Edge | Serrated Edge | Dientes de sierra simétricos regulares. |
| Edge | Sawtooth Edge | Dientes asimétricos inclinados. |
| Edge | Bitten Edge | Muescas suaves y profundas en el contorno. |
| Edge | Corroded Edge | Pequeñas cavidades frecuentes hacia el interior. |
| Edge | Charcoal Edge | Ruido granulado por capas con parpadeo. |
| Edge | Chalk Edge | Tramos cortos desplazados lateralmente como tiza quebrada. |
| Edge | Crayon Edge | Ondulación lateral amplia como presión de crayón. |
| Edge | Dry Brush Edge | Arrastra vetas por la tangente del contorno. |
| Edge | Spray Edge | Puntas finas hacia fuera como pintura pulverizada. |
| Edge | Living Edge | El ruido avanza por el borde. |
| Edge | Electric Edge | Zigzags angulosos que parpadean en el borde. |
| Edge | Fur Edge | Puntas densas que se balancean como pelo. |
| Edge | Frost Edge | Variaciones angulosas con destellos. |
| Edge | Torn Edge | Desgarros profundos y espaciados. |
| Edge | Postage Stamp | Perforaciones semicirculares regulares. |
| Edge | Cloud Edge | Lóbulos redondeados que crecen hacia fuera. |
| Edge | Thorn Edge | Espinas largas y espaciadas. |
| Edge | Scallop Edge | Arcos festoneados regulares. |
| Edge | Bubble Edge | Burbujas que crecen y desaparecen en el borde. |
| Ink | Ink Spread In | La tinta se expande por las normales hasta formar el dibujo. |
| Ink | Ink Dry Out | El contorno se seca y deshace hacia dentro al salir. |
| Ink | Wet Ink | La tinta se hincha y asienta cíclicamente mientras oscila. |
| Ink | Watercolor Bloom In | Forma el dibujo mediante manchas lobuladas de acuarela. |
| Ink | Ink Absorb Out | La forma se hunde y reduce como tinta absorbida. |
| Ink | Smoke Away Out | El contorno asciende y se dispersa en remolinos. |
| Ink | Steam Rise | Lóbulos de distorsión ascendente suaves. |
| Ink | Burn Away Out | Una frontera de quemado avanza lateralmente con parpadeo. |
| Ink | Boil Away Out | La oscilación crece hasta evaporar la forma hacia arriba. |
| Ink | Bleed Through In | La tinta aparece desde puntos dispersos del contorno. |
| Ink | Frost Creep In | La escarcha cristalina recorre el contorno hasta formarlo. |
| Drip | Ink Drip | Gotas alargadas crecen desde la parte inferior. |
| Drip | Bottom Drips | Gotas más pesadas tiran del borde inferior. |
| Drip | Side Drips | Las gotas avanzan lateralmente desde los bordes. |
| Drip | Falling Stain | Arrastra todo el contorno hacia abajo. |
| Drip | Melt Down | Derrite hacia abajo y acumula en un suelo implícito. |
| Drip | Diagonal Melt | Derrite en diagonal con arrastre lateral. |
| Drip | Rain Wash | Columnas verticales arrastran la forma hacia abajo. |
| Drip | Slime Stretch | Estira y recupera cíclicamente el borde inferior. |
| Drip | Slime Snap In | Entra sobreestirada y recupera la forma de golpe. |
| Drip | Puddle Expansion | La parte inferior se expande como un charco. |
| Drip | Icicle Growth | Puntas de carámbano crecen hacia abajo. |
| Drip | Candle Melt | Hundimiento lento y recuperación cíclica de cera. |
| Drip | Drip Loop | Las gotas se forman, caen y reinician por período. |
| Path | Wave Along Path | Una onda recorre la longitud del contorno. |
| Path | Traveling Bulge | Una protuberancia completa una vuelta por período. |
| Path | Peristalsis | Varias protuberancias avanzan en secuencia. |
| Path | Path Flow | Los puntos avanzan por la tangente del trayecto. |
| Path | Snake Run | Un segmento visible recorre el contorno. |
| Path | Snake Chase | Dos segmentos se persiguen con fases opuestas. |
| Path | Dash March | Guiones en movimiento recorren el contorno. |
| Path | Dotted March | Puntos en movimiento recorren el contorno. |
| Path | Morse Flicker | Renueva patrones aleatorios de puntos y guiones por pulso. |
| Path | Segment Flicker | Oculta segmentos aleatorios por fotograma. |
| Path | Path Retract | Un segmento crece y se reduce mientras recorre el contorno. |
| Path | Crawl Bugs | Muchos guiones cortos y ondulantes recorren el contorno. |
| Reveal | Stroke Reveal In | Revela todos los contornos en paralelo. |
| Reveal | Stroke Reveal Out | Borra todos los contornos en paralelo. |
| Reveal | Handwriting Reveal In | Revela contornos sucesivos según su longitud. |
| Reveal | Handwriting Reveal Out | Borra contornos sucesivos. |
| Reveal | Segment Pop In | Añade fragmentos por pasos en orden de dibujo. |
| Reveal | Segment Pop Out | Retira fragmentos por pasos en orden de dibujo. |
| Reveal | Random Segment In | Acumula segmentos aleatorios hasta completar el dibujo. |
| Reveal | Random Segment Out | Retira segmentos aleatorios hasta vaciar el dibujo. |
| Reveal | Dash Reveal In | Cierra los huecos de un patrón de guiones. |
| Reveal | Dash Reveal Out | Abre huecos hasta disolver el contorno en guiones. |
| Reveal | Organic Wipe In | Revela con una frontera direccional irregular. |
| Reveal | Organic Wipe Out | Borra con una frontera direccional irregular. |
| Reveal | Wavy Wipe In | Revela con una frontera sinusoidal. |
| Reveal | Wavy Wipe Out | Borra con una frontera sinusoidal. |
| Reveal | Shaky Wipe In | Revela con una frontera que tiembla por fotograma. |
| Reveal | Shaky Wipe Out | Borra con una frontera que tiembla por fotograma. |
| Reveal | Ink Wipe In | Revela con prolongaciones de tinta por delante de la frontera. |
| Reveal | Ink Wipe Out | Borra dejando prolongaciones de tinta tras la frontera. |
| Reveal | Iris Reveal In | Revela radialmente desde un centro ajustable. |
| Reveal | Iris Reveal Out | Colapsa radialmente hacia un centro ajustable. |
| Reveal | Swirl Wipe In | Revela con un barrido angular y puntos en remolino. |
| Reveal | Swirl Wipe Out | Borra con un barrido angular y puntos en remolino. |
| Reveal | Diagonal Wipe In | Revela en diagonal con una frontera que se repliega. |
| Reveal | Diagonal Wipe Out | Borra en diagonal con una frontera que se repliega. |
| Dissolve | Noise Dissolve In | Reúne grupos de puntos dispersos por ruido. |
| Dissolve | Noise Dissolve Out | Dispersa puntos en grupos de ruido. |
| Dissolve | Erode In | Reconstruye la forma desde restos erosionados. |
| Dissolve | Erode Out | Erosiona hacia dentro hasta deshacer la forma. |
| Dissolve | Split Wipe In | Abre desde la línea central hacia ambos lados. |
| Dissolve | Split Wipe Out | Cierra desde ambos lados hacia la línea central. |
| Dissolve | Band Dissolve In | Bandas alternas entran desde lados opuestos. |
| Dissolve | Band Dissolve Out | Bandas alternas salen hacia lados opuestos. |
| Dissolve | Checker Dissolve In | Ensambla celdas escalonadas como un tablero. |
| Dissolve | Checker Dissolve Out | Colapsa celdas escalonadas como un tablero. |
| Dissolve | Crystallize In | Refina facetas gruesas hasta recuperar el dibujo. |
| Dissolve | Crystallize Out | Ajusta coordenadas a facetas cada vez mayores. |
| Fold | Accordion Fold In | Despliega pliegues comprimidos en zigzag. |
| Fold | Accordion Fold Out | Comprime en pliegues en zigzag hacia un borde. |
| Fold | Roll In | Desenrolla desde un cilindro en un borde. |
| Fold | Roll Out | Enrolla hacia un cilindro en un borde. |
| Fold | Twist Collapse In | Deshace una torsión helicoidal a lo largo del eje. |
| Fold | Twist Collapse Out | Retuerce y colapsa en una hélice a lo largo del eje. |
| Fold | Fan Unfold In | Abre piezas como un abanico desde una esquina. |
| Fold | Fan Fold Out | Cierra piezas como un abanico hacia una esquina. |
| Fold | Blinds In | Gira lamas de persiana para revelar el dibujo. |
| Fold | Blinds Out | Cierra lamas de persiana hasta aplanar el dibujo. |
| Fold | Crumple In | Despliega una forma arrugada hasta recuperar el dibujo. |
| Fold | Crumple Out | Arruga la forma mediante pliegues aleatorios. |
| Impact | Jelly Impact In | Cae y se estabiliza con oscilaciones amortiguadas. |
| Impact | Jelly Release Out | Oscila y sale con un impulso elástico. |
| Impact | Radial Burst Out | Lanza cada punto hacia fuera desde el centro. |
| Impact | Radial Gather In | Reúne puntos lejanos hasta formar el dibujo. |
| Impact | Vortex In | Los puntos entran en espiral desde una órbita amplia. |
| Impact | Vortex Out | Los puntos salen en espiral hacia una órbita creciente. |
| Impact | Gravity Sag Out | La forma cede y se hunde gradualmente. |
| Impact | Gravity Recover In | Recupera el dibujo desde una forma hundida. |
| Impact | Wind Sweep Out | Dispersa la forma por inclinación en la dirección elegida. |
| Impact | Wind Settle In | Reúne fragmentos arrastrados por el viento. |
| Impact | Shiver In | Entra temblando y se estabiliza. |
| Impact | Shiver Out | Un temblor creciente deshace la forma. |
| Impact | Slam Shock In | Llega de golpe y emite un anillo de choque. |
| Impact | Kickback Out | Retrocede brevemente y sale en la dirección elegida. |
| Contour | Contour Bob | Cada contorno sube y baja con su propia fase. |
| Contour | Contour Sway | Cada contorno oscila alrededor de su centroide. |
| Contour | Contour Orbit | Cada contorno sigue una órbita pequeña con fase distinta. |
| Contour | Contour Breathe | Cada contorno pulsa alrededor de su centroide. |
| Contour | Contour Wave | Una onda de elevación recorre los contornos. |
| Contour | Contour Heartbeat | Los contornos emiten pulsos dobles sucesivos. |
| Contour | Contour Jolt | Contornos aleatorios saltan de posición por pulso. |
| Contour | Contour Blink | Contornos aleatorios se ocultan por pulso. |
| Contour | Contour Carousel | Los contornos recorren lentamente círculos alrededor de su posición. |
| Contour | Contour Pop In | Los contornos crecen desde cero con sobrepaso escalonado. |
| Contour | Contour Pop Out | Los contornos se reducen a cero sucesivamente. |
| Contour | Contour Drop In | Los contornos caen desde arriba y rebotan en su lugar. |
| Contour | Contour Drop Out | Los contornos caen fuera de la composición sucesivamente. |
| Contour | Contour Slide In | Los contornos entran escalonados desde la dirección elegida. |
| Contour | Contour Slide Out | Los contornos salen escalonados hacia la dirección elegida. |
| Contour | Contour Spin In | Los contornos entran completando un giro. |
| Contour | Contour Spin Out | Los contornos salen girando en sentidos alternos. |
| Contour | Contour Scatter In | Los contornos entran desde direcciones y giros aleatorios. |
| Contour | Contour Scatter Out | Los contornos se dispersan con direcciones y giros aleatorios. |
| Contour | Contour Flip In | Los contornos aparecen al girar desde el canto como tarjetas. |
| Contour | Contour Flip Out | Los contornos desaparecen al girar hacia el canto. |
| Contour | Contour Zoom In | Los contornos se reducen desde un tamaño grande hasta su lugar. |
| Contour | Contour Zoom Out | Los contornos crecen hasta salir de la vista. |
| Contour | Contour Typewriter In | Los contornos aparecen uno por uno en orden. |
| Contour | Contour Typewriter Out | Los contornos desaparecen uno por uno en orden. |
| Contour | Contour Domino In | Los contornos se incorporan en secuencia. |
| Contour | Contour Domino Out | Los contornos se tumban en secuencia. |
| Shatter | Shatter Out | El relleno se divide en partículas que giran y salen. |
| Shatter | Shatter In | Partículas giratorias entran y reconstruyen el relleno. |
| Shatter | Crumble Down | Las partículas se desprenden y acumulan en un suelo implícito. |
| Shatter | Sand Blow Out | Los granos salen por la dirección elegida, empezando por el frente. |
| Shatter | Sand Assemble In | Los granos entran en la dirección elegida y se asientan. |
| Shatter | Dust Float Out | Las partículas ascienden y se dispersan como polvo. |
| Shatter | Dust Settle In | El polvo desciende y forma el dibujo. |
| Shatter | Swarm Out | Las partículas salen en espiral como un enjambre. |
| Shatter | Swarm In | Las partículas entran en espiral y se agrupan. |
| Shatter | Splash Out | Las gotas siguen arcos balísticos y caen. |
| Shatter | Confetti Rain In | Las piezas llueven desde arriba y se colocan. |
| Shatter | Ember Drift | Las partículas se desprenden y ascienden cíclicamente. |
| Shatter | Ash Fall Out | El borde superior se desprende primero y cae como ceniza. |
| Glitch | Corrupt Contour | Ráfagas cortas alteran coordenadas del contorno. |
| Glitch | Torn Static | Ráfagas de inclinación con bordes rasgados. |
| Glitch | Interlace Weave | Las filas pares e impares se inclinan en sentidos opuestos. |
| Glitch | Spike Burst | Vértices aislados saltan hacia fuera durante un fotograma. |
| Glitch | Dropout Holes | Grupos de puntos colapsan por pulso y crean huecos. |
| Glitch | Quantize Pulse | Las coordenadas se ajustan a una cuadrícula oscilante. |
| Glitch | Vertex Storm | Los vértices intercambian posiciones locales por fotograma. |
| Sketch | Sketch Passes | Superpone pasadas de lápiz con ruido, desenfoque y alfa. |
| Sketch | Scribble Passes | Superpone garabatos con desplazamientos más intensos. |
