# Rhea Signs 2.1.4

[English](../RheaSigns.md) | Español | [Índice](../../README.es.md#documentación)

Rhea Signs edita texto de carteles, copia y ajusta etiquetas, construye máscaras, distribuye texto y gestiona perspectiva, fuentes y estilos. La interfaz admite inglés, español y portugués.

Menú principal: **Rhea Signs**. Las acciones están bajo `: Kite Hotkeys :/Rhea Signs`, con el prefijo personalizado de DependencyControl si existe. Hotkeys es opcional.

## Comandos

| Comando | Función |
| --- | --- |
| Rhea Signs | Panel para combinar operaciones. |
| TagOps | Copiar, conservar, redimensionar, transformar o alinear etiquetas. |
| Fast Signs | Crear fondo, brillo y texto. |
| Signs Editor | Sustituir texto repetido y regenerar degradados marcados. |
| Shapes/Unify Positions | Compartir pivote conservando colocación. |
| Shapes/Place on Perimeter | Repetir dibujos sobre contornos cerrados. |
| Shapes/Shape Color Optimizer | Combinar colores compatibles o reducir degradados. |
| Tools/Style to Tags | Convertir propiedades del estilo en etiquetas. |
| Font and Style Manager | Revisar o sustituir fuentes y editar o clonar estilos. |
| Fast Fades | Elegir fundidos por fotograma o limpieza de continuidad. |
| Fast Fades/In / Out | Fijar entrada / salida desde el fotograma actual. |
| Fast Fades/Clean | Retirar fundidos internos entre grupos continuos. |
| Shuffle Line Text | Mezclar textos conservando propiedades de cada evento. |

## Panel principal

Contiene Masks, Perspective, Shapes, Sign y Toolbox. Una acción vacía omite esa sección. **Execute** procesa Perspective, Masks, Shapes, Sign y Toolbox, en ese orden. La selección generada pasa a la operación siguiente. Un fallo de perspectiva detiene la cadena.

Cada operación tiene su propia restauración ante error o cancelación. Un fallo posterior no revierte las operaciones que ya terminaron. Las ventanas auxiliares conservan el borrador y regresan al panel cuando ese flujo lo admite. Los comandos directos abren su propia ventana.

## Signs Editor

Selecciona los eventos del cartel y configura la agrupación:

| Opción | Función |
| --- | --- |
| Skip vector drawings | Excluye eventos con dibujo activo. |
| Detect/regenerate GBC | Activa interpolación en líneas con marcador `{*...}`. |
| Character limit | Filtro opcional, desactivado inicialmente. |
| Limit value | 150 por defecto; cuenta grafemas y escapes ASS, no bytes UTF-8. |

Las líneas con texto visible idéntico comparten una fila editable, en orden de aparición. `\N`, `\n` y `\h` se conservan como escapes literales. El panel izquierdo es de consulta; el derecho define la sustitución.

Mantén una fila por grupo. Una cantidad incorrecta vuelve al borrador indicando lo esperado y recibido. Se ignoran filas vacías extra al final; una fila requerida vacía elimina su texto.

El texto se reparte proporcionalmente entre las secciones ASS existentes. Etiquetas, comentarios y dibujos conservan sus posiciones. Una sustitución corta puede dejar secciones vacías sin duplicar caracteres. Por ejemplo, cambiar `A{\b1}B{\i1}C` por `XY` asigna X a la primera sección, nada a la segunda e Y a la tercera.

La regeneración puede actuar aunque no cambie el texto visible. El marcador identifica la etiqueta que se interpola, con color primario como alternativa. Usa referencias efectivas, añade valores por grafema y elimina los marcadores automáticos. Conserva marcas combinantes, emoji unidos, saltos ASS y caracteres de uso privado.

## TagOps

### Copy tags

Elige categorías y **Copy tags**. Los eventos con igual Effect forman grupos; el primero seleccionado aporta etiquetas a los demás. Si ningún grupo tiene destino, el primero de toda la selección sirve de fuente.

- **Read all blocks** lee todos los bloques; desactivado, solo el primero.
- **Replace** retira etiquetas equivalentes antes de insertar, tratando juntas alternativas como pos/move y clip/iclip.
- **Append** añade al final del bloque inicial; desactivado, al principio.
- **Show result** informa de categorías y destinos modificados.

Se distinguen comentarios y argumentos anidados. Copiar `t` conserva la transformación. Una categoría ausente en la fuente se notifica sin escribir una sustitución vacía.

### Keep only

Conserva las categorías elegidas y retira las demás etiquetas. Mantiene texto y comentarios. Las transformaciones conservan el contenido seleccionado que admite el filtro. Revisa las categorías antes de aplicar esta eliminación.

### Resize / transform

Detecta propiedades habituales de tamaño, espaciado, escala, borde, sombra, desenfoque, giro e inclinación. Las casillas **alternan categorías respecto al conjunto detectado**; no son una lista simple de inclusión. Así se puede excluir `fs` y añadir `pos`.

| Modo | Cálculo |
| --- | --- |
| Add | `value + amount`. |
| Percent | `value × (1 + amount / 100)`. |
| Transform | Añade `\t(...)` durante todo el evento hacia valores escalares animables ajustados. |

Tamaño, espaciado, escala, borde y sombra ausentes pueden proceder del estilo. Cuando es posible, los cambios sensibles a perspectiva capturan y reproyectan el plano.

Los números se editan sin cambiar nombres de etiquetas, fuentes ni colores hexadecimales. Los exponentes se leen completos. Si se selecciona la transformación, sumar 1 a `\t(0,100,\1c&H123456&\fs1e2)` produce `\t(1,101,\1c&H123456&\fs101)`. Las coordenadas de clips vectoriales cambian sin alterar su escala de dibujo.

Se rechazan cantidades no finitas y desbordamientos. Al editar numéricamente etiquetas discretas, como alineación, el resultado debe seguir siendo un valor ASS válido.

### Pos Align

Requiere dos eventos como mínimo: el primero es fuente y el segundo referencia. Calcula `posición de fuente − posición de referencia` y desplaza por esa diferencia todos los destinos posteriores a la fuente.

La posición procede de `pos`, del inicio de `move` o del estilo, márgenes y resolución. Las posiciones implícitas pasan a ser explícitas al moverlas. **Keep org** mueve pos/move y conserva origen y clips. **Move org** mueve también orígenes y clips, incluidos los de transformaciones. Si coinciden posiciones, puede usar la diferencia entre orígenes explícitos.

Los dibujos mantienen coordenadas locales y no reciben el desplazamiento dos veces. Los clips escalados convierten el desplazamiento de pantalla a sus unidades.

## Masks

Las fuentes son **from clip** y la biblioteca. Formas incluidas: `square`, `rounded`, `circle`, `triangle`.

| Acción/control | Resultado |
| --- | --- |
| Apply Mask | Aplica la fuente con las opciones actuales. |
| Create Layer | Crea una máscara una capa por debajo. |
| Replace Mask | Sustituye la primera sección activa de dibujo. |
| Alignment | Alineación `an1`–`an9`. |
| Color / Alpha | Sustituye RGB / alfa cuando está activado. |
| q2 | Activa el modo ASS de ajuste de línea 2. |
| Save Shape | Guarda la geometría del primer evento con el nombre indicado. |
| Delete Shape | Retira la definición guardada. |

**from clip** convierte rectángulos, Bézier, contornos separados y clips escalados a dibujo local. Un clip inverso aporta el mismo contorno, no el complemento del cuadro.

Create Layer retira el clip de origen después de construir la máscara. Si la fuente está en capa cero, la lleva a uno y coloca la máscara en cero. Las máscaras de biblioteca conservan el clip. Las generadas desde clips neutralizan giro, inclinación y escala heredados para conservar coordenadas de pantalla.

La colocación de biblioteca usa posición explícita o estilo/márgenes, y conserva orígenes y giros explícitos admitidos. Replace Mask acepta escalas mayores que `p1`, normaliza la sección sustituida a `p1` y escala 100 %, y conserva texto posterior.

La biblioteca está en `dramaturgy_masks.txt`, dentro de la carpeta de usuario de Aegisub. Al guardar se normaliza a `p1`, se valida todo el trayecto y se actualiza el nombre existente. Admite LF y CRLF. Los nombres no pueden contener dos puntos ni saltos; `from clip` está reservado.

Puedes guardar una forma con nombre de una incorporada para sustituirla. Borrar esa definición vuelve a mostrar la incorporada. Se guarda geometría, no tiempos ni todo el conjunto de etiquetas.

## Distribución del texto

Se usa el estado inicial, teniendo en cuenta fuentes, tamaños, escalas, espaciado y resets intermedios. Si la geometría cambia durante el evento, conviértela o divídela antes cuando necesites una distribución distinta por fotograma.

### Typewriter

Revela grafemas con transformaciones de alfa, retirando los alfas anteriores. Marcas combinantes y emoji unidos cuentan como una unidad. Los saltos ASS no consumen pasos y los dibujos no cuentan como caracteres.

**Frame** usa el mapa del vídeo, también con tasa variable, hasta el último milisegundo utilizable. **Duration** reparte los pasos por duración y sirve como alternativa si no hay conversión por fotogramas. El primer carácter empieza al inicio. Solo se admiten diálogos sin comentar y de duración positiva; tiempos, estilo y contenido ajeno al alfa se conservan.

### Vertical Drop

Crea un evento por grafema en un eje vertical. Parte de la posición, movimiento o estilo, y avanza la altura medida de cada carácter más **Vertical gap**, que puede ser negativo. La escala se aplica una vez mediante la medida de Aegisub.

Sustituye la fuente y selecciona el último carácter generado por cada una. Los espacios pueden producir eventos; los saltos no.

### Circle Text

Requiere `pos` y `org` explícitos. Su distancia, más el desplazamiento de radio, debe producir un radio positivo. Tracking añade separación. Los giros pueden ser normal, invertido o vertical; Invert cambia el sentido del recorrido. Delete original elige sustituir la fuente o conservarla. Los espacios consumen ancho sin generar un carácter visible.

La compensación de tamaño de fuente forma parte de su modelo de composición; revisa el resultado en escrituras conectadas.

### Curve Text

Usa el clip vectorial propio o el primero válido como guía compartida. Centra el texto sobre el trayecto y gira cada carácter visible según su tangente. Sustituye la fuente y genera en la capa siguiente.

Las rectas usan sus extremos; las curvas cúbicas, 40 subdivisiones. Los ángulos interpolan por el arco más corto. Los trayectos no admitidos o inutilizables se rechazan.

## Perspective

Los planos se resuelven con estilo, resolución y geometría existente. Deben ser finitos, no degenerados y tener escala positiva.

| Modo | Operación |
| --- | --- |
| Copy Exact (same plane) | Copia perspectiva, posición y origen. |
| Copy Static Plane (keep `pos`) | Copia el plano y conserva la posición de destino. |
| Copy Move Plane (whole plane) | Traslada plano y origen a la posición de destino. |
| Copy w/ corner swap | Reordena esquinas según la permutación. |
| Mass FSC (lock quad) | Cambia escalas X/Y y reproyecta para conservar el cuadrilátero. |
| Scale Quad (3D Box) | Escala alrededor del centro. |
| Bake Extradata | Convierte el plano guardado en marcador de texto transportable. |
| Restore Extradata | Devuelve el marcador a los datos extra. |
| Identity reproject | Recalcula etiquetas del plano actual. |

Los modos de copia siguen los grupos de fuente/destino descritos en TagOps. Hay copias exactas, espejos, giros y permutaciones. Se omiten cuadriláteros inválidos.

El origen puede conservar el del destino, usar el centro o minimizar fax. La escala compara PlayResY con LayoutResY o, si falta, con la altura de vídeo. Rhea consulta las diferencias relevantes y recuerda el aviso durante la sesión.

Los metadatos requieren cuatro pares de coordenadas y admiten signo, decimales y exponentes. Bake usa el formato `_persp` compatible con archivos existentes.

## Shapes

### Unify Positions

Selecciona al menos dos dibujos estáticos. La línea activa seleccionada aporta el pivote; si no pertenece al grupo, se elige una referencia de la selección. Se reescriben posiciones compensando coordenadas locales para conservar colocación.

Requiere una posición estática y una sección de dibujo inequívocas. Se rechazan movimientos, animación dependiente del origen, transformaciones no admitidas o giro heredado cuando un único pivote no pueda conservar el aspecto. La compensación de 1/64 de píxel responde a la precisión del renderizador.

### Place on Perimeter

El primer dibujo es el contorno base. Los demás forman unidades; las capas que comparten posición pertenecen a la misma. Su orden sigue la selección. La base se conserva y las plantillas se sustituyen por la distribución.

Puedes recorrer solo exteriores o también huecos. Orientación y contención distinguen los contornos; cada uno cierra su período por separado. Elige un patrón sugerido o **Custom**, con números separados por espacios o comas, como `1, 2, 2, 3`. No hay un máximo de 16 pasos. Los números inválidos vuelven al borrador.

Repeticiones y huecos se calculan desde longitud del contorno y ancho de unidades. No hay un máximo fijo de 4000 salidas. Se puede cancelar. Un avance no positivo, tangente inválida o cierre imposible se rechaza.

### Shape Color Optimizer

Optimiza dibujos estáticos compatibles mediante `kite.ShapeOptimizer`. Modos: Auto, Similar colors y Full gradient. Intensidades: Balanced, Fidelity y Aggressive. El umbral OKLab cero usa la intensidad elegida; su tolerancia está acotada para limitar el error de color.

**Max. bands** pide al menos dos bandas y no puede superar la cantidad de elementos de entrada. Se admiten escalas de dibujo altas, incluida `p7`, mientras el factor sea finito.

Se muestra la reducción propuesta y, si está activada, se confirma antes de aplicar. Si las formas son incompatibles o no existe una reducción aceptable, se conservan los originales.

## Fast Signs

Agrupa eventos sin comentar que se superponen, coloca sus cajas lado a lado junto al desplazamiento superior y crea tres capas: fondo en la original, borde/brillo en la siguiente y texto arriba. La fuente se comenta y sus tiempos se conservan. Cada fundido se limita a la mitad de la duración.

Configura colores RGB, alfas independientes de caja y brillo, color/alfa del texto, fundidos, márgenes, posición superior, separación, ancho máximo de caja como porcentaje, borde y desenfoque. Se neutraliza el giro heredado. El alfa del texto procede de su selector de color.

El ancho máximo limita la caja; no reduce automáticamente el texto largo. Se retira el formato intermedio para crear esta composición uniforme. Las líneas nuevas quedan seleccionadas.

## Font and Style Manager

Lee estilos y etiquetas `fn` reales fuera de transformaciones. Omite nombres aparentes dentro de comentarios o transformaciones.

| Acción | Función |
| --- | --- |
| Swap font | Sustituye fuente en estilos y, opcionalmente, etiquetas intermedias coincidentes. |
| Refresh | Actualiza el resumen. |
| Edit properties | Edita en varios estilos solo los campos marcados. |
| Edit colors | Aplica los canales elegidos. |
| Clone style | Crea un estilo con colores originales o editados. |

La selección admite un estilo por fila y avisa de nombres desconocidos. Los valores mixtos se marcan. Una casilla Apply desactivada conserva el campo; los booleanos admiten sin cambios, activado y desactivado.

Se pueden editar fuente, tamaño, escalas, espaciado, ángulo, borde, sombra, márgenes, codificación, negrita, cursiva, subrayado, tachado, tipo de borde y alineación. Se exigen números finitos y valores ASS válidos, como tamaño positivo y márgenes no negativos.

Los formularios inválidos conservan el borrador. Los nombres clonados deben ser únicos, no vacíos y sin comas ni saltos. Insertar estilos ajusta selección y fila activa. La ventana permanece abierta; cerrarla conserva operaciones ya completadas.

## Toolbox

**Style to Tags** usa `AssContext.styleBake`. Permite elegir propiedades, proteger familias existentes, omitir ceros y expandir resets. La alineación explícita conserva su prioridad; los resets no introducen otra alineación de línea. Los resets activos usan sus estilos reales; se conservan comentarios y resets anidados. El acceso antiguo Taggerize abre esta herramienta.

**Fast Fades/In** usa `tiempo del fotograma − inicio`; **Out**, `fin − tiempo del fotograma`. El cursor debe estar dentro de todos los diálogos sin comentar seleccionados. Se conserva el otro componente del fundido. Datos inválidos cancelan antes de editar.

**Continuous Fade Cleanup** agrupa intervalos iguales y retira fundidos en los límites interiores de grupos continuos, conservando los exteriores. Requiere más de un grupo temporal. **Shuffle Line Text** mezcla solo texto; tiempos y otros campos permanecen en sus filas.

## Configuración

La configuración se guarda entre sesiones. Los ajustes anteriores se importan automáticamente.
