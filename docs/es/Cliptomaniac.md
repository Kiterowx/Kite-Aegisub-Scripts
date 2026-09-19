# Cliptomaniac 0.4.4

[English](../Cliptomaniac.md) | Español | [Índice](../../README.es.md#documentación)

Cliptomaniac edita clips ASS, usa guías para colocar o transformar texto y convierte líneas animadas en eventos por fotograma. **Cliptomaniac** abre el selector; **Cliptomaniac/Help**, la referencia. Las 39 acciones individuales están bajo **: Kite Hotkeys :/Cliptomaniac/**. Las barras dentro de un nombre usan el carácter de ancho completo para no crear otro submenú.

## Elegir la geometría de origen

| Objetivo | Entrada y acción |
| --- | --- |
| Ajustar un recorte al texto | Autofit clip to text ajusta uno existente; Create clip around text puede empezar sin clip. |
| Usar contornos | Text to clip usa la fuente; Shape to clip usa el dibujo ASS. |
| Mover varias líneas juntas | Guía recta de dos puntos y Clip to reposition. |
| Cambiar giro o inclinación | Una guía define FRZ, FAX o FAY. Debe tener longitud y dirección utilizables. |
| Ajustar perspectiva | Clip to perspective usa cuatro esquinas; Complete quadrilateral parte de tres. |
| Convertir animación | Animated clip to FBF muestrea por fotogramas; Export clip track to AE exporta datos. |
| Revisar geometría | Clip diagnostics informa del clip; Measure clip mide longitudes y ángulos. |

La mayoría de las acciones toma el primer clip o guía utilizable. Rectángulos, vectores y clips inversos son entradas distintas. La posición de una línea puede proceder del estilo, alineación, márgenes y resolución sin `\pos` explícito. Los márgenes de evento tienen prioridad. La escala vectorial debe convertirse antes de interpretar coordenadas como píxeles. AssContext, ASSFoundation y las herramientas de perspectiva resuelven resets y estados temporales.

Selecciona diálogos y abre una acción. Las directas se ejecutan inmediatamente; las demás muestran controles. Cancelar opciones regresa al selector si se abrió desde el panel principal. Language cambia inglés/español. Las preferencias se guardan por acción y migran desde `kite-cliptomaniac.json`; los fallos de escritura se notifican. Hotkeys es opcional.

## Fotogramas y franjas

FBF usa los tiempos del vídeo y excluye el límite final. Clip only conserva el texto original cuando solo se anima el clip; si otras etiquetas temporales necesitan evaluarse, usa el estado completo. Los tiempos de karaoke se ajustan a cada fragmento. Merge identical une eventos vecinos solo si coinciden su contenido y campos relevantes. Max frames limita la salida después de unir: empieza en 400, admite enteros no negativos y **0** lo desactiva.

Create lines inserta una copia por franja y conserva la fuente; Comment source la comenta. Sin Create lines se aplica la primera franja a la fuente. Horizontal avanza en X y Vertical, en Y. Las franjas rectangulares vecinas se solapan medio píxel para reducir juntas. No hay un máximo fijo de filas. Se puede cancelar durante generación e inserción; un error o cancelación restaura el archivo.

## Acciones

Los nombres siguientes coinciden con la interfaz inglesa. Las acciones indicadas como directas no abren opciones.

### Add clip points

Añade puntos conservando la forma. **Add by** elige distancia o cantidad. **Distance** inserta cada intervalo de píxeles y conserva el resto antes del siguiente punto original. **Points** añade esa cantidad uniformemente por segmento.

### Adjust by clip scale

Usa dos trazos como medidas de origen y destino. **Axis** elige ancho, alto o ambos. Puedes modificar `fscx`, `fscy`, `fs`, `fsp`, `bord`, `shad` y `blur` —incluido edge blur—. **Show report** muestra el porcentaje aplicado.

### Align to clip

Acción directa. Lleva la posición al punto más cercano del trayecto.

### Animated clip to FBF

Convierte la línea animada en eventos por fotograma. **Bake source** elige estado completo o solo clip. **Max frames** limita la salida; cero desactiva el límite. **Merge identical** une estados vecinos equivalentes. **Comment source** conserva el original comentado.

### Autofit clip to text

Ajusta el clip al texto. **Mode** elige la parte; **Section axis**, división horizontal o vertical; **Margin**, expansión o reducción; **Tolerance**, simplificación; **Sections**, cantidad; **Index**, sección personalizada; **Bleed**, solape entre secciones; **No shrink**, impide reducir respecto al clip anterior; **Style pad**, incluye borde, sombra y desenfoque.

**Transform maxima** mide los límites renderizados de todos los fotogramas, respeta `\an` e ignora clips solo durante la medida. Necesita vídeo. No añade dos veces el margen de estilo. Consolida clips en uno estático conservando su tipo.

### Bezier clip to curved text

Convierte una Bézier cúbica en giro y espaciado por carácter. **Curve depth** al 100 % genera un arco circular compensado; al 0 %, una recta; valores mayores aumentan la profundidad. **Extra fsp** añade espaciado. **Remove guide clip** retira la guía.

### Calibrate clip X

Acción directa. Hace horizontal el primer trazo.

### Calibrate clip Y

Acción directa. Hace vertical el primer trazo.

### Circle from 2 points

Acción directa. Usa el primer trazo como diámetro de un círculo.

### Clip boolean with text/shape

Combina el clip con el contorno del texto o dibujo. **Boolean mode** conserva la intersección o resta la forma al clip. **Tolerance** simplifica y **Close paths** cierra contornos abiertos antes de combinar.

### Clip diagnostics

Acción directa. Muestra tipo, tamaño, puntos y estado del plano de perspectiva.

### Clip to FAX

Convierte el primer trazo en inclinación X. **Remove guide clip** retira la guía.

### Clip to FAY

Convierte el primer trazo vertical en inclinación Y. **Remove guide clip** retira la guía.

### Clip to FRZ

Convierte el primer trazo en giro Z. **Remove guide clip** retira la guía.

### Clip to move

Convierte una posición fija en movimiento usando el primer trazo. **Remove guide clip** retira la guía.

### Clip to perspective

Usa cuatro esquinas como plano de perspectiva. **Corner order** define su lectura; **Origin**, el anclaje resultante; **Remove guide clip**, la retirada de la guía.

### Clip to reposition

El primer clip recto seleccionado de dos puntos define un desplazamiento común para todas las líneas. Conserva su disposición relativa. **Remove guide clip** retira solo esa referencia; los demás clips se desplazan con sus líneas.

### Clip to shape

Acción directa. Convierte el primer clip en dibujo editable.

### Complete quadrilateral

Acción directa. Añade D a A-B-C cerrando direcciones opuestas en el plano de perspectiva.

### Copy clip/iclip

Acción directa. Copia el primer clip a los destinos seleccionados correspondientes o de la primera línea al resto.

### Create clip around text

Crea un clip alrededor del texto, incluida inclinación y perspectiva. **Margin** amplía o reduce; **Tolerance** simplifica; **Style pad** incluye borde, sombra y desenfoque. **Replace existing clip** sustituye el primero.

**Transform maxima** combina los límites renderizados de todos los fotogramas, con vídeo cargado. Respeta `\an`, ignora clips durante la medida y ya incluye la apariencia visible del estilo. Al reemplazar, consolida todos los clips en uno estático y conserva clip o iclip.

### Create strip clips

Divide un clip o el área del texto en franjas. **Strip mode** elige dirección; giro y perspectiva se detectan. **Strip size** fija el tamaño aproximado. **Create new lines** duplica por franja; **Comment source** comenta el original. Sin guía, **Transform maxima** puede medir toda la animación; requiere vídeo.

### Expand clip margin

**Margin** positivo amplía el clip y negativo lo reduce. **Tolerance** controla la simplificación.

### Export clip track to AE

Acción directa. Concatena las duraciones seleccionadas y muestra Position, Scale y Rotation de After Effects en la consola.

### Extract clip as mask line

Acción directa. Crea una línea de dibujo a partir del primer clip.

### Fit text to clip guide

Usa la primera guía clip/iclip para ajustar texto. En **X axis**, su distancia horizontal define el ancho máximo; en **Y axis**, la vertical define y equilibra los renglones. Conserva alineación y tipo de clip sin retirarlo.

### Measure & transform clip

Usa dos trazos como medidas anterior y posterior para añadir una animación de tamaño. **Axis** elige ancho o alto; **Angle mode** decide si también cambia el giro; **Show report** muestra las medidas.

### Measure clip

Acción directa. Muestra longitud y ángulo de los dos primeros trazos.

### New clip shape

Acción directa. Inicia otra forma desde el último punto del trayecto.

### Perspective to clip

Acción directa. Reconstruye cuatro puntos desde el plano guardado o la geometría proyectada actual.

### Position at clip midpoint

Acción directa. Lleva las líneas al punto medio de su clip o del primero seleccionado.

### Rect clip to vector

Acción directa. Convierte un rectángulo en trayecto editable.

### Rectangle from diagonal

Acción directa. Construye un rectángulo a partir del primer trazo diagonal.

### Remove clip points

Acción directa. Elimina puntos alternos conservando la validez de cada forma.

### Rescale by rectangle clip

Ajusta etiquetas de tamaño al rectángulo. **Fit** mantiene todo el texto dentro; **Fill** cubre el área; **Stretch** usa factores distintos para ancho y alto. **Center** lleva `\pos` al anclaje del rectángulo según la alineación. **Remove guide clip** retira la guía. Puedes escalar `\fscx`, `\fscy`, espaciado, borde, sombra y desenfoque.

Requiere un clip rectangular; se rechazan vectores. Si lo necesitas vectorial, conviértelo después.

### Shape to clip

Acción directa. Usa el dibujo como área de recorte.

### Text to clip

Usa el contorno real de texto o dibujo. **Clip type** elige clip, iclip o tipo actual. **Margin** ajusta el borde; **Tolerance** simplifica; **Close paths** cierra huecos; **Replace existing clip** sustituye el primero; **Comment source** conserva el original comentado y crea una copia recortada.

### Toggle clip/iclip

Acción directa. Alterna entre mostrar y ocultar el interior.

### Vector clip to rect

Acción directa. Convierte el trayecto en su rectángulo envolvente mínimo.

## Ejemplos y límites

- Una guía de (100,200) a (140,220) representa (+40,+20) en Clip to reposition; no sitúa todas las líneas en el punto final.
- Trazos de longitud 100 y 150 dan una proporción 1.5. Adjust by clip scale la aplica; Measure & transform clip la anima.
- Un evento de 120 ms a 25 FPS genera tres intervalos por fotograma sin unir. Un límite de 2 lo rechaza sin editar; cero lo permite.
- Las medidas aproximadas de fuente requieren revisión visual. Transform maxima mide cada fotograma y puede tardar en eventos largos.
- Se admiten inclinaciones de magnitud superior a 100 si son finitas y no singulares. Guías degeneradas, denominadores casi nulos y dimensiones inutilizables se rechazan.

## Dependencias

Requiere ZF, ASSFoundation, `arch.Perspective`, `arch.Util`, Functional, `a-mo.Line`, Core, UI, LineOps y AssContext según el catálogo. Contornos y perspectiva dependen de la fuente instalada, el renderizador y el cartel.
