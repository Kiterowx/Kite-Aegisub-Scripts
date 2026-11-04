# Kiri-Shot · Capturas y secuencias

[English](../KiriShotCaptures.md) | Español | [Índice](../../README.es.md#documentación)

Kiri-Shot exporta capturas PNG del vídeo cargado a partir de líneas seleccionadas, fotogramas explícitos, clips o dibujos. También exporta intervalos completos con o sin subtítulos. No modifica eventos.

Abre una tarea de **Capturas** o **Recorte** en [Kiri-Shot](KiriShot.md).

## Uso

1. Carga un archivo de vídeo real que FFmpeg pueda decodificar.
2. Para modos basados en líneas, selecciona diálogos de duración positiva. Se excluyen comentarios. Capturas · lista de fotogramas puede funcionar sin selección.
3. Elige la tarea de captura y, cuando corresponda, Instantes que se capturan y Forma y transparencia del recorte.
4. En **Ajustes**, selecciona FFmpeg o deja `ffmpeg` para buscarlo en `PATH`. Al regresar se conserva el borrador, incluida la lista de fotogramas.
5. Pulsa **Capturar PNG**. El informe muestra ubicación de salida, errores y líneas omitidas.

En Windows, PyBridge supervisa FFmpeg sin consola visible y permite cancelar. Se comprueban tanto su resultado como los PNG generados.

## Modos de captura

| Tarea | Resultado |
| --- | --- |
| Capturas · líneas seleccionadas | Captura el vídeo en los instantes elegidos de cada diálogo; no incrusta subtítulos. |
| Capturas · lista de fotogramas | Captura los fotogramas indicados en orden ascendente y sin duplicados. No depende de Instantes que se capturan ni de la selección. |
| Capturas · secuencia PNG | Exporta desde el primer fotograma activo hasta el último de la selección, incluidos los huecos. Utiliza las tres casillas de salida de secuencia. |
| Recorte · clip o dibujo | Utiliza clips o dibujos según Forma y transparencia del recorte. |
| Recorte · rectángulo manual | Aplica X/Y/W/H y margen a las capturas de los instantes elegidos. Usa píxeles del vídeo. |
| Captura · mayor superposición | Captura el primer fotograma con más diálogos seleccionados superpuestos. Cuenta intervalos, aunque el texto sea transparente. |

## Instantes

| Instantes que se capturan | Capturas |
| --- | --- |
| Punto medio | Fotograma que contiene el punto medio. |
| Inicio y final | Primero y último activos; no añade el fin exclusivo como fotograma nuevo. |
| Inicio, medio y final | Inicio, centro y último activo. En eventos cortos pueden repetirse fotogramas con nombres distintos. |
| Fotograma actual | Solo eventos seleccionados que contienen el fotograma actual. Avisa si no hay ninguno. |

Capturas · lista de fotogramas, Capturas · secuencia PNG y Captura · mayor superposición calculan sus propios fotogramas. La búsqueda usa los tiempos del vídeo cargado con una pequeña tolerancia al redondeo de Aegisub, sin decodificar desde cero para cada captura. FFmpeg y Aegisub deben usar la misma pista y correspondencia temporal. Unos códigos de tiempo externos distintos a los del archivo pueden alterar la coincidencia.

## Lista de fotogramas

Admite `120`, `120f`, `F120`, `120f, 130f` o una entrada por línea. Espacios, comas y punto y coma separan entradas. En anotaciones como `120f > P1 fade 6f` se ignora lo posterior a `>` y las anotaciones fade reconocidas. Se retira un `--` inicial por compatibilidad.

Los intervalos como `120-130` no se expanden. Se notifican números negativos, inválidos, desbordados o fuera del vídeo antes de procesar. La numeración empieza en cero y está limitada por la API entera de Aegisub, no por una cantidad máxima de capturas.

La lista inicial toma primero marcadores del campo Effect que caigan en los intervalos seleccionados. Si no hay, usa el fotograma actual cuando pertenece a ellos y, después, el inicio de cada intervalo combinado. Sin selección temporal usa el fotograma actual.

## Clips y alfa de dibujos

| Forma y transparencia del recorte | Comportamiento |
| --- | --- |
| Rectángulo del clip | Recorta el rectángulo envolvente de un clip normal estático. En vectores usa coordenadas y puntos de control, que pueden dejar espacio adicional junto a curvas. Clips inversos o animados necesitan salida alfa. |
| Alfa del clip · recortado | Usa la forma del clip como alfa y recorta sus límites visibles. Admite clips inversos y animación rectangular mediante libass. |
| Alfa del clip · cuadro completo | Aplica alfa y conserva las dimensiones del vídeo. |
| Alfa del dibujo · recortado | Renderiza los dibujos como máscara y recorta el área no transparente. |
| Alfa del dibujo · cuadro completo | Usa alfa del dibujo con el tamaño completo del vídeo. |

Las coordenadas de clip se convierten de PlayRes a píxeles del vídeo. Se admiten clips escalados, varios contornos, `m`/`n`, curvas y números finitos completos. Se rechazan trayectos inválidos o escalas desbordadas. Un clip rectangular introducido solo dentro de una transformación interpola desde el cuadro completo. Las transformaciones de clips vectoriales dependen de la compatibilidad ASS de libass.

Las máscaras de dibujo conservan estilo, márgenes, alineación, escala, giros, movimiento, resets y transparencia. Usan el reloj original del evento para evaluar clips, desvanecimientos y transformaciones. Se extrae alfa renderizado, con transparencias parciales y bordes suavizados independientes del color.

Solo contribuyen las secciones de dibujo; se omite texto normal. Retirarlo puede alterar la composición de eventos mixtos, por lo que se recomiendan líneas de dibujo independientes. Los comentarios y etiquetas dentro de transformaciones no activan accidentalmente el modo de dibujo. Los resets con nombre usan los estilos actuales.

El recorte alfa incluye todo píxel con alfa distinto de cero, también bordes tenues de un píxel y tamaños impares. Una máscara transparente informa de que no tiene área alfa. Las líneas sin clip o dibujo utilizable se omiten y se notifican.

## Rectángulos y márgenes

X/Y admiten negativos; W/H deben ser positivos y el margen, no negativo. El rectángulo ampliado se intersecta con el vídeo. Si queda completamente fuera, se informa de un error.

Los valores finitos y las dimensiones reales determinan la salida válida. El margen afecta a rectángulos manuales y Rectángulo del clip. Las salidas alfa usan sus propios límites y no se amplían con ese control.

## Salidas de secuencia

Activa al menos una:

| Casilla | Contenido |
| --- | --- |
| Vídeo sin subtítulos | Vídeo original. |
| Vídeo con subtítulos | Vídeo con todos los eventos sin comentar que coincidan con el intervalo. La selección define el intervalo, no cuáles se renderizan. |
| Subtítulos transparentes | Subtítulos sobre fondo transparente. |

Se conservan propiedades de estilo, incluidas `scale_x`/`scale_y`, y tiempos originales. Una línea iniciada antes del intervalo conserva el avance de su animación. Script Info y estilos se escriben en un ASS temporal. Si falta resolución, se usa la del vídeo. No se exportan fuentes ni gráficos incrustados; FFmpeg/libass utiliza las fuentes disponibles para su renderizador.

Se valida la estructura de cada PNG solicitado, incluidos los intermedios. El intervalo incluye el primer fotograma activo y excluye el siguiente al último activo.

## Carpetas y nombres

La raíz es `Snapshots`, junto al proyecto guardado, con la carpeta del script o vídeo como alternativa. No hay un selector de carpeta de salida independiente.

Las capturas sueltas se guardan en la raíz y los lotes grandes suelen recibir una subcarpeta única. **Todo en la carpeta raíz** usa la raíz con prefijos que evitan coincidencias. Una secuencia de una salida usa normalmente su carpeta; varias salidas usan `clean`, `with_subtitles` y `subtitles_only`, salvo que se aplanen.

Los nombres incluyen contador, línea o fotograma y tiempo. **Añadir texto del subtítulo al nombre** añade texto visible adaptado a nombres de archivo. Se corrigen caracteres y nombres reservados de Windows. El sufijo se acorta entre grafemas completos para limitar la ruta, sin recortar el contenido del subtítulo.

## Preferencias y errores

Las opciones y FFmpeg se guardan en los [ajustes compartidos de Kiri-Shot](KiriShot.md#ajustes-migración-y-atajos). La lista de fotogramas no persiste entre ejecuciones. Se informan los fallos al guardar. Cancelar Ajustes regresa al borrador; cerrar el panel no captura.

Las máscaras temporales y PNG alfa intermedios se eliminan después de cada captura, también si hay error. Una captura fallida retira su PNG parcial, pero las ya completadas se conservan. Una secuencia interrumpida puede dejar archivos completos o parciales y no se informa como terminada. Los ASS temporales se retiran en las rutas de error y cancelación previstas.

La supervisión de Windows conserva rutas Unicode y patrones literales como `%06d`. Fuera de Windows, el ejecutor alternativo puede responder a la cancelación solo entre llamadas a procesos.

## Requisitos

Instala los módulos de Aegisub-Motion indicados en las [dependencias de Kiri-Shot](Dependencies.md#dependencias-por-script), `myaa.ASSParser` y FFmpeg. Usa FFmpeg con libass y PNG para las capturas con subtítulos y transparencia.
