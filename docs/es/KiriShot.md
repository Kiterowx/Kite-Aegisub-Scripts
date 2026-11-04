# Kiri-Shot 1.0.0

[English](../KiriShot.md) | Español | [Índice](../../README.es.md#documentación)

Kiri-Shot reúne capturas PNG, secuencias, recortes con alfa, preparación de máscaras y exportación de vídeo social. Se instala como `automation/autoload/kite.KiriShot.lua`. Usa las bibliotecas compartidas de la suite; no carga Social Clip ni Snapshoter. Guarda las copias anteriores fuera de las rutas activas de autoload.

## Interfaz por tareas

Abre **Kiri-Shot**, elige una tarea y pulsa **Abrir tarea**. La cabecera muestra el vídeo, su resolución y la cantidad de diálogos seleccionados. Cada panel presenta los controles de su tarea.

| Tarea | Resultado |
| --- | --- |
| Capturas · líneas seleccionadas | PNG en el punto medio, inicio/final, inicio/medio/final o fotograma actual de los diálogos seleccionados. |
| Capturas · lista de fotogramas | PNG de los índices indicados, desde cero. Acepta `120f, 130f` y las anotaciones compatibles del gestor anterior. |
| Capturas · secuencia PNG | Intervalo completo de la selección. Puede generar vídeo limpio, vídeo con subtítulos y subtítulos transparentes. |
| Recorte · clip o dibujo | Rectángulo del clip o alfa renderizado de clip/dibujo; con recorte o cuadro completo. |
| Recorte · rectángulo manual | PNG de una región X/Y/ancho/alto, expresada en píxeles del vídeo. |
| Captura · mayor superposición | Primer fotograma con más diálogos seleccionados simultáneos. |
| Vídeo social | Exportación MP4/MKV o del diálogo adaptado como ASS, usando las máscaras del guion. |
| Preparar máscaras | Crear máscaras, corregir su Y, centrar los subtítulos en X o retirar las antiguas vistas Y. |

**Cambiar tarea** vuelve al selector y conserva el borrador de la sesión. **Ajustes** abre la configuración común; cancelar ese panel descarta solo sus cambios. **Cerrar** no ejecuta ninguna operación. Las capturas no modifican eventos; las operaciones sobre máscaras y subtítulos conservan sus transacciones y puntos de deshacer.

## Capturas y secuencias

Pulsa **Capturar PNG** para ejecutar. Las capturas se guardan en `Snapshots`, junto al proyecto, con la carpeta del script o vídeo como alternativa. Puedes añadir el texto del subtítulo al nombre y agrupar las imágenes en la raíz. Los lotes reciben nombres que evitan colisiones.

Una secuencia requiere al menos una salida activada. Incluye los huecos entre los eventos seleccionados. La selección define el intervalo; la variante con subtítulos renderiza todos los eventos no comentados que coinciden con él. Se comprueba cada PNG generado.

La lista de fotogramas se conserva al navegar entre paneles de la misma sesión y se regenera al volver a ejecutar la macro. Los rectángulos se validan únicamente en las tareas que los utilizan.

Consulta los [detalles del motor de capturas](KiriShotCaptures.md) para la precisión temporal, clips animados, alfa, nombres y archivos parciales al cancelar.

## Máscaras y vídeo social

En **Preparar máscaras**, elige la operación y pulsa **Aplicar**. Crear máscaras utiliza los tiempos seleccionados y conserva los eventos de origen. Corregir Y y centrar X actúan sobre la selección. Limpiar vistas Y retira únicamente los eventos auxiliares con el efecto antiguo reconocido y puede utilizarse sin vídeo cargado.

El formato de salida se comparte entre la preparación de máscaras y el panel de vídeo. Se conservan los identificadores `Kite Social Mask`, `Kite Social Y Preview` y `_kite_socialclip_centered` para reconocer proyectos anteriores.

**Vídeo social** ofrece **Exportar vídeo** y **Solo ASS**. Elige el archivo al exportar. Los perfiles conservan las opciones anteriores: MP4 con diálogo adaptado, MP4 con la composición ASS exacta y MKV con diálogo ASS activable. Se mantienen el recorte animado, reparto de solapes, eliminación de huecos, audio, fuentes disponibles y protección del guion activo.

Consulta los [detalles del motor de vídeo social](KiriShotVideo.md) para las restricciones de geometría, adaptación de subtítulos y perfiles.

## Ajustes, migración y atajos

**Ajustes** contiene una ruta común de FFmpeg, FFprobe, velocidad de libx264 y tasa AAC. FFmpeg se usa tanto en capturas como en vídeo. FFmpeg debe incluir PNG, libass y los filtros de cada operación; el vídeo usa libx264 y AAC.

Las preferencias se guardan bajo `kite.KiriShot`, separadas en captura, vídeo social y ajustes comunes. En la primera sesión se leen las preferencias anteriores de ambas macros, incluidas sus configuraciones JSON antiguas. Las preferencias de origen se conservan. Se guardan al ejecutar una tarea o pulsar **Guardar** en Ajustes.

Si las dos macros tenían rutas personalizadas de FFmpeg diferentes, se toma la de Social Clip y se muestra un aviso en el selector. Si Social Clip usaba el valor predeterminado, se toma la ruta de Snapshoter. Puedes cambiar la ruta común en Ajustes.

Se registran los accesos directos **`: Kite Hotkeys :/Kiri-Shot/Capturas`** y **`: Kite Hotkeys :/Kiri-Shot/Vídeo social`**. Los atajos y favoritos anteriores se reasignan a esos destinos al cargar Kiri-Shot. Las entradas obsoletas de sus catálogos se vacían para evitar acciones duplicadas.

La macro depende de `kite.UI`, `kite.Core`, `kite.PyBridge`, `kite.ShapeOptimizer`, `kite.AssContext`, `a-mo.LineCollection`, `l0.ASSFoundation`, `myaa.ASSParser` y `tstools.Yutils`. DependencyControl gestiona estas bibliotecas; las dependencias transitivas, como SubInspector, conservan sus requisitos habituales.
