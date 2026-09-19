# Gradient Row 1.8.9

[English](../GradientRow.md) | Español | [Índice](../../README.es.md#documentación)

Gradient Row crea degradados mediante copias recortadas en franjas o colores entre grafemas visibles. Selecciona uno o varios diálogos sin comentar y abre **Gradient Row**.

## Modos

| Modo | Resultado |
| --- | --- |
| Horizontal | Franjas que avanzan por el ancho. |
| Vertical | Franjas que avanzan por la altura. |
| Rotated | Franjas según el ángulo elegido y la orientación de la línea. |
| Char Line | Reinicia el degradado de caracteres en cada línea. |
| Char Selection | Extiende un degradado por las líneas en el orden recibido. |

Los modos espaciales comentan las fuentes e insertan copias recortadas y coloreadas, que quedan seleccionadas. Los modos de caracteres editan las líneas y conservan la selección; omiten dibujos vectoriales. Los espacios normales consumen una posición de color. `\N`, `\n` y `\h` se conservan sin consumirla. Los grafemas mantienen juntas las marcas combinantes, los emoji unidos y las parejas de bandera.

## Paleta y controles

La ventana agrupa tipo, grosor, aceleración, ángulo y colores en una columna. Cada página muestra hasta ocho colores. **Previous** y **Next** aparecen cuando hay varias páginas y conservan las ediciones. Colors indica el intervalo visible y el total; la ayuda de cada muestra indica su posición. **Add+** duplica el último color y abre su página. **Rem-** elimina el último y mantiene al menos dos. **Reset** restaura el borrador; **Cancel** lo descarta; **Execute** guarda y procesa. Los fallos al guardar preferencias se informan por separado.

**Pixels per strip** es un grosor entero de al menos un píxel. Aumentarlo reduce las líneas generadas y hace más visibles los escalones. **Acceleration** es un exponente positivo: 1 interpola linealmente; valores mayores prolongan los colores iniciales. Los valores guardados no positivos se sustituyen por 1. **Angle** se aplica a Rotated. Se pueden elegir los canales primario, secundario, borde y sombra; el alfa no cambia.

Entre negro y blanco, tres posiciones con aceleración 1 sitúan el centro cerca de RGB 128/128/128. La aceleración cambia el centro, pero conserva los extremos. La proporción se calcula antes de elevarla para evitar desbordamientos con exponentes grandes.

## Colores intermedios como puntos de referencia

**Inline color stops** funciona en Char Line y Char Selection. Usa etiquetas de color estáticas explícitas situadas antes o entre letras. Interpola los canales con al menos dos posiciones distintas y deja los demás intactos. Si coinciden varias etiquetas en una posición, prevalece la última. Se utilizan esos canales independientemente de las casillas de la paleta.

En `{\c&H000000&}AB{\c&HFFFFFF&}CD`, A y C son los puntos de referencia del color primario. Char Line reinicia el cálculo por línea; Char Selection usa posiciones acumuladas. Los colores dentro de transformaciones no se toman como referencias estáticas y se ignoran los escritos en comentarios ASS. Los resets se conservan, pero sus estilos no aportan colores implícitos: añade etiquetas explícitas si un reset debe marcar un límite.

## Geometría y perspectiva

Los modos espaciales admiten líneas sin clip, con un clip rectangular o con un clip vectorial de cuatro esquinas antes del texto visible. Se rechazan clips múltiples, intermedios, inversos o animados. Los clips curvos o con varios contornos deben convertirse antes a una geometría admitida.

Sin clip, se calculan los límites mediante ASSFoundation, SubInspector opcional y medidas de fuente, con una estimación aproximada como alternativa. AssContext resuelve posiciones desde estilo, alineación y márgenes. Giro y perspectiva usan geometría proyectada cuando está disponible. La subdivisión de cuadriláteros utiliza `arch.Perspective` o una alternativa geométrica. Un pequeño margen y la superposición entre franjas reducen las juntas visibles.

Las franjas usan geometría preparada para un estado del cartel. Si cambia con movimiento o transformaciones, revisa toda la duración o conviértela primero por fotogramas con [Cliptomaniac](Cliptomaniac.md). Las medidas aproximadas no son contornos exactos; fuentes y renderizador afectan al resultado.

Los comentarios iniciales se conservan al insertar clips y colores. La sustitución de colores estáticos respeta las transformaciones anidadas. Los demás campos y tiempos se copian a cada fila generada.

## Salida y preferencias

No hay un límite fijo de franjas por fuente ni de líneas por operación. Se puede cancelar durante la generación y la inserción; un error o cancelación restaura el archivo. Para reducir memoria y tiempo, aumenta el grosor de franja cuando el resultado visual lo permita.

Instala ASSFoundation, Aegisub-Motion y `arch.Perspective`. SubInspector permite medir el texto renderizado y es opcional.
