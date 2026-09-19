# Pointiac 1.1.7

[English](../Pointiac.md) | Español | [Índice](../../README.es.md#documentación)

Pointiac añade dos círculos pequeños a cada diálogo seleccionado: uno en su primer fotograma visible y otro en el último. Conserva la fuente. Menú: **Pointiac**. DependencyControl puede añadir un prefijo de menú guardado.

## Uso

1. Selecciona los diálogos. También se admiten comentarios; sus marcadores serán diálogos visibles.
2. Abre Pointiac y elige color, posición, desplazamiento horizontal y diferencia de capa.
3. Pulsa **Execute** para insertar dos marcadores después de cada fuente. **Cancel** no inserta ni guarda preferencias.

Los marcadores quedan seleccionados y el primero pasa a ser la línea activa. Se normalizan los índices repetidos o desordenados y se excluyen filas que no sean diálogos. Las fuentes conservan texto, tiempos, comentario y demás propiedades.

## Controles

| Control | Función |
| --- | --- |
| Color | Color primario de ambos círculos. Acepta RGB HTML y color ASS. |
| FPS* | Tasa positiva usada si no hay códigos de tiempo utilizables. |
| X/Y | Esquina superior izquierda del primer círculo, en coordenadas ASS. |
| Offset X | Desplazamiento horizontal del segundo; admite valores positivos, negativos y cero. |
| Layer + | Entero que se suma a cada capa fuente; la capa final nunca es negativa. |

El diámetro nominal es 9.314 unidades. La posición inicial centra el par completo, contando el diámetro y el desplazamiento con su signo. X/Y se recalculan con la resolución actual; se guardan color, FPS, desplazamiento y capa. Cambiar Offset X no reescribe una X introducida manualmente.

Con X=100, Y=200 y Offset X=-20, los marcadores aparecen en (100,200) y (80,200). Cero los coloca juntos. En una fuente de un fotograma pueden verse ambos a la vez.

No se exige una separación mínima ni se limita la diferencia de capa a ±100. Los números no finitos usan su valor predeterminado. FPS cero o negativo pasa a 24. La duración alternativa se redondea a milisegundos enteros, con un mínimo de uno.

## Tiempos

Con códigos de tiempo, se toma el fotograma que contiene el inicio y el que contiene el último milisegundo anterior al fin. El primer marcador termina en el siguiente límite de fotograma o al final de la fuente, lo que ocurra antes. El último empieza en su límite de fotograma o al inicio de la fuente, lo que ocurra después. Se respetan los fragmentos parciales y las duraciones variables.

Si falla una conversión necesaria, el cálculo completo utiliza FPS. Con 25 FPS, el intervalo nominal es de 40 ms. Los eventos cortos se limitan a su duración disponible. Si la fuente no tiene duración positiva, el marcador usa la duración alternativa desde el inicio no negativo.

## Apariencia e inserción

Cada marcador sustituye el texto copiado por un círculo vectorial fijo. Especifica alineación, posición, borde y sombra cero, escala y giro neutros, alfa visible y color primario. El estilo original se conserva como referencia, pero esas propiedades impiden que sus giros, escalas o transparencias alteren el marcador.

La generación permite cancelar. La inserción se realiza en una transacción con lotes de argumentos, sin un máximo fijo de salida. Un fallo o cancelación restaura el documento. Los fallos al guardar preferencias se notifican; los valores actuales pueden usarse en esa ejecución y conservarse durante la sesión.

## Dependencias

Requiere UI, LineOps, Core y Color. Si están instalados, puede registrarse directamente sin DependencyControl. No necesita Hotkeys.
