# Social Clip 1.0.3

[English](../SocialClip.md) | Español | [Índice](../../README.es.md#documentación)

Social Clip construye un vídeo continuo a partir de intervalos definidos por máscaras ASS. Cada máscara señala qué región del vídeo debe ocupar la salida. Los intervalos se ordenan, se reparten los solapes dobles y se eliminan los huecos entre escenas. El movimiento del recorte se calcula cuadro por cuadro con el mapa temporal del vídeo abierto en Aegisub.

La macro está registrada como **Social Clip**. Conserva la acción **`: Kite Hotkeys :/Social Clip/Execute`** y funciona sin instalar el editor de Hotkeys.

## Preparación

1. Abre un vídeo real en Aegisub y comprueba el PlayRes del guion.
2. Selecciona las líneas cuyos tiempos definirán las escenas.
3. Ejecuta **Crear máscaras**. Elige el formato de salida y las X inicial y final del centro de cada máscara.
4. Revisa las máscaras sobre el vídeo. Puedes ajustar sus tiempos y su movimiento.
5. Ejecuta **Exportar vídeo** o **Solo ASS**.

FFmpeg debe incluir los filtros `subtitles`, `sendcmd`, `crop`, `scale` y `concat`, además de libass y libx264. FFprobe se utiliza para identificar la pista de audio; si falla, se intenta la inspección con FFmpeg. La medición de máscaras complejas utiliza ASSFoundation y SubInspector instalados en Aegisub.

## Ventana principal

| Control | Funcionamiento |
| --- | --- |
| Formato | 1080×1920, 720×1280, 1080×1350 o resolución personalizada. |
| Personalizado | Ancho y alto positivos. Se redondean al entero par más cercano para la codificación YUV 4:2:0. |
| Pista | Número de pista de audio, empezando en 1. |
| Salida | Uno de los tres perfiles descritos abajo. |
| FPS | `Origen`, 30 o 60. `Origen` conserva una salida con tiempos variables; las otras opciones convierten a frecuencia constante. |
| CRF | Calidad de libx264 entre 0 y 51. Menor valor produce mayor calidad y normalmente archivos mayores; 0 solicita codificación sin pérdida. |
| Relación | Expandir la caja hasta ajustarla al formato, o exigir que máscara y salida tengan la misma proporción. |
| Margen lateral | Porcentaje de cada lado reservado al diálogo adaptado: desde 0 hasta menos de 50. |
| Margen inferior | Porcentaje de altura reservado debajo del diálogo adaptado: desde 0 hasta menos de 100. |
| Fuente máxima | Tamaño de fuente adaptada como porcentaje de la altura de salida. Debe ser positivo. |
| Guardar ASS adaptado | Conserva un archivo adicional de diálogo adaptado junto al vídeo. |
| Centro X inicial/final | Coordenadas del centro de las máscaras nuevas en PlayRes. La geometría debe caber en el vídeo. |
| Alpha | Transparencia del relleno de las máscaras nuevas: 0 opaco, 255 transparente. No cambia la caja utilizada para recortar. |

Los valores no finitos y los porcentajes que dejarían un área vacía se notifican antes de ejecutar la acción.

## Crear máscaras

Crea una máscara por cada diálogo seleccionado con duración positiva, omitiendo comentarios. La selección se normaliza para evitar duplicados y mantener el orden del guion. Las máscaras se añaden al final y quedan seleccionadas.

La caja utiliza el mayor recorte del formato elegido que cabe en el vídeo. Su posición vertical inicial aprovecha el cuadro; sus X inicial y final proceden del formulario. Si coinciden, se escribe `\pos`; de lo contrario, `\move` durante toda la línea. Los dibujos se expresan en PlayRes y se ajustan a la resolución real del vídeo.

Las máscaras nuevas tienen actor `SocialClip`, efecto **`Kite Social Mask`**, alineación `\an5`, escala explícita y rotaciones neutralizadas. Su capa se sitúa por encima de la mayor capa existente. El color y el borde facilitan su inspección en el editor; estas líneas no aparecen en la exportación.

## Reconocimiento y medición de máscaras

La búsqueda automática utilizada para exportar y centrar subtítulos toma las líneas con efecto `Kite Social Mask`. Si no encuentra ninguna, admite las antiguas líneas `Kite Social Y Preview`. Los ayudantes que reciben una selección explícita priorizan sus dibujos válidos.

Una máscara contiene dibujo activo `\p` y no texto visible. Los comentarios y las instrucciones anidadas en `\t` no activan dibujo. `\r` termina ese modo. Las variantes `\P` y `\R` no sustituyen a los tags minúsculos de ASS. Una línea que mezcla dibujo y texto se rechaza cuando impide obtener una máscara válida.

Las máscaras poligonales simples se miden directamente con la gramática de `kite.AssDrawing` y el contexto de `kite.AssContext`. Esta ruta reconoce números con exponentes, escala de dibujo, escala del estilo, alineación, márgenes y posición heredada del estilo cuando falta `\pos`. Los tiempos especiales de `\move`, incluidos `(0,0)`, se evalúan con la función compartida.

Las curvas, clips, transformaciones y geometrías que necesitan renderizado pasan a ASSFoundation/SubInspector. Para medir, se utiliza una copia opaca sin bordes ni desenfoque, conservando geometría y comentarios. La línea de origen queda intacta incluso si la medición falla.

El exportador utiliza una caja rectangular de tamaño constante por escena. Puede seguir su desplazamiento y corregir Y cuando la caja rebasa arriba o abajo. No encoge una caja que no cabe ni sustituye silenciosamente un cambio real de tamaño por un recorte distinto. Los cambios de escala o rotación que alteran la caja dentro del cuadro se notifican. Una salida por X fuera del vídeo también se notifica; la corrección automática de Y no cambia esa regla.

## Intervalos y movimiento

Las escenas se ordenan por inicio y final. Un solape entre dos escenas se divide en la frontera de cuadro más cercana a su mitad temporal. Una máscara completamente anidada o un solape triple no tienen ese reparto único y requieren ajustar los intervalos.

Los huecos se eliminan tanto del vídeo como del audio y del diálogo adaptado. Por ejemplo, escenas de 0–400 ms y 600–1000 ms generan una salida continua de 800 ms. Las trayectorias se calculan con el tiempo real de cada cuadro y se comprimen únicamente cuando la posición no cambia. No hay un límite fijo de escenas o cuadros.

## Corregir Y

Modifica únicamente las máscaras seleccionadas con uno de los efectos reconocidos. Conserva X, ajusta Y al área disponible y normaliza el origen a `\an5`. Divide una trayectoria en tramos cuando el ajuste vertical deja de ser lineal, con tolerancia de 0.25 unidades PlayRes. Los fundidos se desplazan al reloj de cada fragmento para evitar que reinicien.

Esta modificación directa exige geometría poligonal que pueda reconstruirse mediante posición y alineación. Para máscaras con curvas, clips, transformaciones o rotación, la exportación sigue pudiendo medir y ajustar el recorte en Y; la acción de edición avisa en lugar de reemplazar tags que podrían cambiar el dibujo. Las antiguas vistas Y se eliminan y se remapea la selección después de corregir.

## Centrar subs X

Centra los subtítulos seleccionados sobre la X de su máscara. Conserva la fila de alineación y la posición vertical: una línea superior sigue arriba; una central sigue en el centro; una inferior sigue abajo. Si no hay posición explícita, utiliza el estilo y los márgenes. Conserva comentarios y tags ajenos al posicionamiento.

Cada subtítulo debe pertenecer a una sola escena y su trayectoria X debe representarse mediante un `\pos` o un único `\move`. Los subtítulos que cruzan máscaras o huecos se notifican. Una animación temporal en Y puede conservarse si es compatible con el movimiento X requerido. `\org` y clips necesitan un tratamiento geométrico adicional y se notifican antes de alterar esa línea.

Las líneas centradas llevan el dato persistente `_kite_socialclip_centered`, que permite reconocerlas después como diálogo adaptable. Se mantiene el contenido anterior de `extra`.

## Perfiles de exportación

| Perfil | Resultado |
| --- | --- |
| MP4 · pegados y adaptados | Dibuja carteles y efectos en el vídeo original antes de recortar. Recoloca el diálogo tradicional en la resolución de salida y lo pega después de unir las escenas. |
| MP4 · pegados exactos | Dibuja toda la composición ASS seleccionable para exportación sobre el vídeo original, conservando sus capas, estilos y reloj. Después realiza los recortes y la concatenación. |
| MKV · diálogo ASS flotante | Pega carteles y efectos antes del recorte. Incluye el diálogo adaptado como pista ASS activable y conserva las fuentes adjuntas disponibles. |

El perfil exacto conserva la composición ASS dentro de las áreas recortadas; el vídeo se vuelve a codificar. El resultado visual depende de las fuentes disponibles y de libass.

El diálogo tradicional es texto sin dibujo, transformación, karaoke, clips, rotaciones ni posicionamiento complejo, normalmente con alineación inferior centrada. Las líneas marcadas mediante **Centrar subs X** pueden llevar posición y escalas propias. Los carteles y efectos que no cumplen la clasificación se mantienen en la composición visual; **Solo ASS** los omite y comunica cuántos fueron excluidos.

Al adaptar, se escalan fuente, espaciado, borde, sombra y desenfoque. Se conservan colores, transparencias y comentarios. Los números completos con exponentes se procesan sin dejar sufijos residuales; las variaciones relativas `\fs+…` no se convierten en tamaños absolutos. Si el texto no cabe, el ajuste utiliza las medidas de Aegisub y puede reducir el tamaño de fuente según el espacio disponible. Sin medidas disponibles, se utiliza una estimación por grafemas, no por bytes UTF-8.

Las líneas que atraviesan varias escenas se dividen y recolocan en la salida continua. Sus `\fad` y `\fade` conservan el reloj de origen, incluso cuando el fragmento comienza dentro del fundido. Los fragmentos de menos de 10 ms se omiten porque ASS serializa en centésimas; esta precisión del formato se conserva como límite explícito.

## Audio y fuentes

Si Aegisub tiene un archivo de audio real cargado, se toma ese origen; de lo contrario, se utiliza el vídeo. Se recorta la pista solicitada por los mismos intervalos y se codifica como AAC estéreo a 48 kHz, con la tasa elegida en Configuración. Un vídeo sin audio puede exportarse con la pista predeterminada y se informa de ello. Si se solicita una pista superior que no existe, se notifica antes de exportar.

Los subtítulos temporales se empaquetan con los adjuntos del vídeo de origen. El perfil MKV conserva la pista adaptada en español y sus fuentes disponibles. Las fuentes externas no adjuntas deben estar instaladas o disponibles para el renderizador.

## Archivos, cancelación y configuración

**Solo ASS** guarda el diálogo adaptado sin codificar vídeo. **Guardar ASS adaptado** añade ese archivo durante la exportación de vídeo; puede existir aunque una codificación posterior falle. El guion activo y el vídeo de origen no pueden elegirse como archivos de salida correspondientes. Sobrescribir otro archivo existente requiere la confirmación de la ventana del script.

El vídeo se codifica en un archivo temporal y sustituye la salida solamente después de finalizar correctamente. Las escrituras ASS se realizan de forma atómica. Se limpian filtros, trayectorias, contenedores de subtítulos y vídeos temporales al finalizar o fallar. La cancelación del proceso la gestiona `kite.PyBridge.runProcess`, compartido con Moka Motion y Snapshoter: ejecuta sin ventana de consola en Windows y recoge el diagnóstico del proceso.

**Configuración** guarda las rutas de FFmpeg y FFprobe, el preset de libx264 y la tasa AAC. Cancelar vuelve a la ventana principal sin guardar los cambios.

Las modificaciones de subtítulos se protegen con una transacción que restaura el guion si una operación falla o se cancela. La selección se remapea después de insertar o eliminar líneas.
