# PNG2ASS 1.7.1

[English](../PNG2ASS.md) | Español | [Índice](../../README.es.md#documentación)

PNG2ASS convierte imágenes y archivos SVG en dibujos ASS mediante `kite-png2ass` 1.5.1. Una imagen suelta hereda los tiempos de la línea activa seleccionada. Varias imágenes forman una secuencia asociada a los fotogramas de las líneas seleccionadas. Los originales se conservan.

## Convertir una imagen

1. Selecciona un diálogo sin comentar. Su estilo, tiempos y propiedades serán la base de los dibujos.
2. Abre PNG2ASS y elige una imagen o SVG. Admite PNG, JPEG, WebP, BMP, TIFF, GIF y TGA. Exporta antes las animaciones o imágenes multipágina como archivos independientes.
3. Elige modo, color y posición. Execute inicia un proceso de Python supervisado sin consola visible.
4. Revisa motor, número de líneas y caracteres, duración y avisos. Insert añade los dibujos después de la fuente, una capa por encima. Cancel no modifica el subtítulo.

Se utiliza la línea activa si pertenece a la selección; en caso contrario, el primer diálogo seleccionado. Las filas nuevas quedan seleccionadas y la inserción crea una acción de Deshacer. Cancelarla restaura el documento.

## Modos

| Modo | Interpretación | Motor |
| --- | --- | --- |
| auto | Usa alfa si hay transparencia, máscaras si predomina blanco/negro y color para las demás imágenes opacas. | Depende del modo detectado. |
| alpha | Píxeles cuyo alfa supera el umbral. | OpenCV. |
| white-matte | Primer plano claro sobre negro; compone la transparencia sobre negro. | OpenCV. |
| dark-matte / luma | Primer plano oscuro sobre blanco; compone la transparencia sobre blanco. | OpenCV. |
| color | Contenido visible separado en capas de color. | VTracer + svg2ssa. |

Elige **source** con **auto** para pedir conversión de color. Los modos explícitos de máscara usan el color del estilo; color conserva los originales. SVG pasa directamente a svgelements. En SVG, **style** elimina los colores de origen y conserva la opacidad.

OpenCV conserva los huecos mediante la orientación de los contornos. En la salida de VTracer se eliminan elementos de trayecto vacíos y se conservan los datos válidos.

## Fidelidad del SVG

La importación SVG comienza con colores de origen y posición 0,0. Iguala PlayRes con el lienzo SVG. Las transformaciones anidadas matrix/translate/scale/rotate/skew se aplican a los paths; se conservan rectángulos, círculos, elipses y polígonos. SVG decimals (0–5) y Arc degrees (1–90) controlan la precisión y la subdivisión de arcos. Los controles de trazado raster no afectan al SVG.

Se admiten un clip en coordenadas de usuario y Gaussian blur isotrópico simple. Blur, opacidad de grupo y bordes ASS son aproximados; convierte trazos a contornos para reproducir extremos, uniones y paths abiertos. Expande texto vivo, imágenes, use/symbol, gradientes, máscaras, filtros complejos, rellenos evenodd, trazos discontinuos y clips anidados a paths compatibles antes de importar. Los componentes no admitidos provocan un error. No se incluyen presets de compresión SVGO ni el control epsilon de la web.

Antes de insertar, PNG2ASS aplica los clips del SVG a la geometría mediante la biblioteca de Shape Clipper de Everything Shape (ZF.main 2.3.0). No quedan tags de clip. Las curvas se conservan intactas si toda la figura está dentro del recorte; las intersecciones reales convierten las curvas a segmentos con tolerancia máxima de 1/32 de píxel del script. Los resultados vacíos se omiten. El desenfoque y el borde ASS se dibujan después del corte geométrico y pueden extenderse fuera de él; la vista previa avisa de esta limitación.

Los tags generados se comparan con el estilo de cada línea de destino. Se omiten bord0, shad0, escala, rotación, colores y alfa cuando repiten sus valores; se mantienen las anulaciones necesarias. Por ejemplo, bord0 se conserva si el estilo tiene borde. Cada fotograma de una secuencia utiliza su propio estilo de destino.

## Opciones

| Opción | Función |
| --- | --- |
| Threshold | Porcentaje de 0 a 100 para formar una máscara binaria. No cuantiza imágenes de color. |
| Scale | Precisión del dibujo entre `\p1` y `\p6`; no cambia su tamaño visible. |
| Simplify | Tolerancia de contornos de OpenCV; valores menores conservan más vértices. |
| Min area | Descarta contornos de área menor. Cero permite revisar detalles pequeños; los contornos degenerados no forman polígonos rellenos. |
| VTracer balanced / quality | Preajustes de color. Quality conserva detalles pequeños y puede producir más capas. |
| Position | Origen 0,0, `\pos` explícito de la línea activa o coordenadas manuales. |
| X / Y | Coordenadas manuales con fracciones; se conservan seis decimales. |
| Blur | Desenfoque de los dibujos. |
| Denoise | Radio del filtro de mediana previo al trazado. |
| Warn chars / Warn lines | Umbrales de aviso; superarlos no cancela una conversión válida. |
| Max pixels | Límite de decodificación comprobado en la cabecera de imagen. |
| Python | Intérprete de esta conversión y de futuras ejecuciones guardadas. |

Rangos: Simplify hasta 1000, Min area hasta mil millones, coordenadas entre ±10 millones, Blur hasta 100 y Denoise hasta 50. Los valores grandes pueden eliminar detalle o requerir más trabajo. Las preferencias se guardan después de insertar; un fallo de guardado no descarta los dibujos.

**Active pos** solo lee una posición estática explícita. No deduce la del estilo ni evalúa `\move`; usa Manual si necesitas otro punto. La posición se refiere al lienzo original. Al recortar márgenes transparentes se conserva su desplazamiento.

## Secuencias

Selecciona las líneas fuente y varios archivos de imagen. PNG2ASS elimina rutas duplicadas y ordena por número: frame2 precede a frame10. Todos los archivos deben existir y tener extensión admitida. Las rutas con saltos de línea se rechazan.

Cada línea genera trabajos desde `frame_from_ms(start_time)` hasta antes de `frame_from_ms(end_time)`. El tiempo de cada trabajo es la intersección entre el fotograma y la línea. No se añade un fotograma final fuera de ese intervalo. El número de imágenes debe coincidir con el de trabajos mostrado; las líneas superpuestas aportan trabajos independientes.

Cada imagen corresponde a un trabajo. Una máscara vacía se registra como `LINES 0`: deja un hueco sin desplazar las imágenes siguientes. Una imagen suelta vacía informa de que no hay dibujo utilizable. Si toda la secuencia está vacía, el subtítulo y la selección se conservan.

En una secuencia visible/transparente/visible de tres trabajos se insertan dibujos para el primero y el tercero, con sus propios tiempos. Cancelar la revisión final no inserta ninguno.

No hay un máximo fijo de archivos o fotogramas. La lista de entrada admite 16 MiB y limita la longitud de cada ruta. La salida acumulada se detiene en los límites de protección de 500 000 líneas ASS o 100 000 000 de caracteres. También se valida el tamaño y la sintaxis de cada dibujo.

## Backend y cancelación

| Comando | Función |
| --- | --- |
| Backend/Check | Revisa paquete, dependencias y versión disponible en la fuente. |
| Backend/Configure | Guarda Python y la fuente de instalación; cerrar cancela. |
| Backend/Install or Update | Muestra el comando de instalación, lo ejecuta y permite revisar el resultado. |

En Windows se necesita PowerShell para supervisar el proceso de Python. Las rutas admiten acentos y apóstrofos. Cancel puede detener el proceso aunque esté dentro de una llamada nativa de trazado. Los archivos de progreso, resultado y supervisión son temporales y se limpian; los registros de instalación se retiran después de leerlos.

Los índices, cantidades y dibujos se validan antes de editar. Imágenes sueltas y secuencias comparten revisión, inserción y limpieza. Los archivos de salida se sustituyen de forma atómica: un fallo conserva el destino anterior y elimina el temporal.
