# AddTexture 2.1.8

[English](../AddTexture.md) | Español | [Índice](../../README.es.md#documentación)

AddTexture ajusta texturas ASS pegadas al contorno del texto seleccionado. Conserva los eventos originales e inserta las texturas en capas con el desplazamiento elegido.

## Uso

1. Copia un dibujo ASS, un dibujo con `\p`, un clip vectorial o filas Dialogue/Comment que contengan dibujos.
2. Selecciona líneas de diálogo sin comentar y ejecuta **AddTexture**.
3. Revisa el dibujo mostrado. **Paste clipboard** vuelve a leer el portapapeles sin cambiar las demás opciones. **Execute** usa el contenido del cuadro, incluso si lo has recortado o borrado.
4. Ajusta simplificación, color y recorte, y pulsa **Execute**.
5. Revisa las líneas insertadas. Quedan seleccionadas y la primera pasa a ser la activa. Una acción de Deshacer revierte la inserción.

Si el portapapeles supera los 12 000 caracteres, el cuadro muestra una vista abreviada. Ejecutarla sin editar utiliza el contenido completo. Si la editas, el texto editado sustituye al contenido completo. Los cambios posteriores del portapapeles solo se leen al pulsar **Paste clipboard**.

## Interpretación del dibujo

Los dibujos se normalizan a coordenadas `\p1`, aplicando la posición, alineación y escala explícitas. Los grupos de textura comparten un rectángulo envolvente para conservar sus posiciones relativas. Los clips usan coordenadas absolutas y no heredan la escala ni la alineación del texto. Los clips animados no se añaden como texturas estáticas.

ASSFoundation interpreta las secciones de dibujo; LineOps sirve como alternativa para los clips fuera de transformaciones. La textura se interpreta de forma estática. Antes de pegar material animado, convierte la perspectiva y el movimiento al estado que quieras usar.

## Opciones y resultados

| Opción | Comportamiento |
| --- | --- |
| Preserve colors | Conserva los colores primarios originales y agrupa los dibujos por color. Si se desactiva, usa el color primario del texto de destino. |
| Clip to text | Calcula la intersección entre la textura y el contorno del texto. Si se desactiva, añade el contorno como clip. |
| Copy alpha/fad | Copia las etiquetas de visibilidad, incluidas sus transformaciones; omite los demás cambios de esas transformaciones. |
| Extra tags | Añade las etiquetas indicadas a los dibujos. Por defecto, elimina borde y sombra. |
| Text simplify / Shape simplify | Tolerancias no negativas para el contorno y la textura. Cero conserva el mayor detalle disponible. |
| Layer offset | Entero no negativo que se suma a la capa original. |

La textura se escala uniformemente para cubrir el rectángulo del texto y se centra sobre él. Las intersecciones vacías se omiten y aparecen en el informe final. Si todas están vacías, no se inserta ninguna línea. **Copy alpha/fad** afecta a toda la textura generada; no reproduce transparencias independientes dentro de cada carácter.

Por encima de 20 000 líneas estimadas se solicita confirmación. Puedes cancelar durante la preparación o la inserción; un error o una cancelación restaura los subtítulos. Una tolerancia mayor puede eliminar detalle; conservar más geometría aumenta el coste de procesamiento y renderizado.

## Configuración y dependencias

Las opciones se guardan para la próxima ejecución. Pega el dibujo de nuevo cuando quieras aplicar otra textura.

## Ejemplo

Pega un dibujo de franjas de dos colores, selecciona un cartel y activa **Preserve colors**. Sin **Clip to text**, los grupos de color se ajustan al cartel y reciben su contorno como clip. Activa esa opción para incorporar el recorte a la geometría del dibujo. Usa **Copy alpha/fad** para copiar un desvanecimiento uniforme.
