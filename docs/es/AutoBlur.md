# AutoBlur 2.1.4

[English](../AutoBlur.md) | Español | [Índice](../../README.es.md#documentación)

AutoBlur estima los cambios de nitidez del fondo durante un evento de diálogo y escribe una curva de desenfoque ASS. Abre **AutoBlur** o asígnale un atajo.

## Uso

1. Carga el vídeo y selecciona una línea de duración positiva.
2. Coloca el cursor de vídeo dentro de ella. Ese fotograma será la referencia del seguimiento.
3. Elige un punto con textura del fondo cercano al cartel. Evita el propio subtítulo, los cortes de escena y objetos móviles ajenos.
4. Ajusta el muestreo y la curva, y ejecuta. La línea conserva la selección; un fallo de lectura o muestreo la deja intacta.

El punto sugerido procede del primer punto de un clip vectorial estático, de la posición o movimiento en el instante actual, del portapapeles o de la alineación y márgenes. Se excluyen los clips dentro de transformaciones y el texto de comentarios ASS. Las coordenadas del script se convierten a coordenadas del vídeo para leer los píxeles. Revisa la sugerencia: el anclaje del texto puede caer sobre un fondo poco útil.

## Seguimiento

Activa **Use tracking data** y pega una exportación de Position de After Effects compatible con `a-mo.DataWrapper`. Debe cubrir exactamente el intervalo de fotogramas del evento. Los desplazamientos se calculan respecto al fotograma actual; el punto elegido corresponde a ese instante. Se rechazan datos vacíos, canales inutilizables y longitudes distintas. Sin seguimiento, se muestrea la misma coordenada durante todo el evento.

## Controles

| Control | Función |
| --- | --- |
| Patch radius | Radio en píxeles del vídeo de cinco zonas cercanas. El mínimo es 2 para disponer de muestras suficientes. |
| Max blur | Límite del desenfoque generado, también después de cuantizar. Cero produce desenfoque cero. |
| Curve exponent | Exponente positivo de la respuesta a la nitidez relativa. |
| Quant step | Separación entre niveles de desenfoque; 0 desactiva la cuantización. |
| Smooth window | Ventana de media móvil en fotogramas; 1 desactiva el suavizado. |
| Min run | Suprime tramos cortos de un nivel en modo Discrete; 1 los conserva. |
| Transition | Duración de la interpolación en milisegundos alrededor de cada cambio; 0 escribe un salto de un milisegundo. |
| Mode | Continuous conserva cada cambio cuantizado; Discrete elimina primero los tramos cortos. Ambos combinan valores consecutivos iguales. |

Las zonas grandes necesitan más tiempo y memoria. Puedes cancelar entre filas del muestreo. Los controles o coordenadas inválidos, y un seguimiento activado sin datos, regresan al borrador sin perder las demás opciones. Cerrar cancela.

## Muestreo y resultado

Por fotograma se calcula la luminancia y la varianza del laplaciano en cinco zonas. Sus resultados se combinan con una media recortada y se suavizan temporalmente. El percentil 95 sirve como referencia de nitidez. El desenfoque se calcula como `maxBlur * (1 - clamp(variance/reference, 0, 1)^curve)`; después se cuantiza y, si corresponde, se suprimen tramos cortos. Una zona plana con varianza cero en todos los fotogramas se rechaza porque no permite establecer una referencia.

El intervalo incluye el fotograma inicial y excluye el límite final. Los tiempos de las transformaciones se expresan respecto al inicio de la línea, aunque este caiga entre límites de fotograma. La curva se inserta en el primer bloque inicial de etiquetas, o en uno nuevo si falta. Los comentarios que lo preceden se conservan.

**Strip existing** elimina las etiquetas de desenfoque y de suavizado de bordes del primer bloque y de sus transformaciones. Elimina las transformaciones vacías y conserva las que contienen otros cambios. Las etiquetas intermedias y resets posteriores permanecen y pueden modificar el resultado en una parte del texto.

## Requisitos y preferencias

Usa Aegisub de arch1t3cht con el vídeo cargado. Puedes pegar datos de seguimiento si el punto de muestreo se mueve.

Las preferencias se guardan entre sesiones. La coordenada de muestreo y los datos pegados se eligen en cada ejecución.

## Límites de la estimación

La medida procede del contraste local; un cambio de textura o iluminación puede alterarla sin que cambie el desenfoque óptico. Revisa el cartel sobre su fondo en Aegisub.
