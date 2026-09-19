# AutoMask 2.5.5

[English](../AutoMask.md) | Español | [Índice](../../README.es.md#documentación)

AutoMask captura el fotograma actual y envía una región por línea seleccionada a `kite-automask` 0.4.2. Permite cubrir letras o defectos de una superficie y obtener su contorno como dibujo o clip ASS.

## Operaciones

| Comando | Uso | Resultado |
| --- | --- | --- |
| AutoMask | Revisar o pintar máscaras antes de aplicar. | Abre el editor. |
| Find surface inside clip | Un clip normal rodea la superficie y deja un margen. | Detecta la superficie dentro de la guía y abre el editor. |
| Classic AutoGrask | Un clip normal encierra papel claro con letras oscuras. | Reconstruye la superficie sin abrir el editor. |
| Backend/Check | Consultar versión y dependencias. | Muestra disponibilidad y versión de la fuente, si puede consultarse. |
| Backend/Configure | Elegir Python u otra fuente de instalación. | Guarda intérprete y fuente. |
| Backend/Install or Update | Instalar o actualizar el paquete. | Ejecuta el instalador con el Python configurado. |
| Backend/Install Models | Usar SAM o LaMa. | Descarga y verifica los modelos compatibles. |

Carga un vídeo, selecciona diálogos sin comentar y coloca el cursor en el fotograma que quieras reconstruir. La captura se ajusta a PlayRes; el editor trabaja en coordenadas del script. Todas las regiones usan ese mismo fotograma. La operación no sigue una superficie en movimiento.

## Guías y geometría

Un único `\clip` rectangular o vectorial define la región. El editor principal también acepta `\iclip` y usa el exterior del contorno. Los comandos Inside y Classic requieren un clip normal; Classic exige exactamente uno.

La posición, el movimiento, el giro, la escala y las animaciones de color del texto no desplazan un clip absoluto. Un clip animado debe convertirse antes al estado del fotograma deseado. Se rechazan clips múltiples por la ambigüedad de su precedencia y clips completamente fuera de la imagen.

Los dibujos ASS necesitan `\pos` explícito y `\an7`. Se leen escala, `\pbo`, curvas cúbicas y B-splines. Antes de usarlos como guía, convierte a geometría estática las transformaciones, movimientos, giros, inclinaciones y resets que afecten al dibujo. Los tokens no admitidos y las curvas incompletas se notifican. Sin clip ni dibujo se intenta detectar el área; puedes completarla con **Box** o **Region +**.

## Editor

1. Selecciona una región en **Regions**. `·` indica pendiente; `✓`, reconstruida; `!`, un fallo informado.
2. Elige **Clip usage**. **Whole clip** conserva la guía; **Find surface inside** busca una superficie distinta dentro de ella. El cambio actualiza las regiones guiadas y se puede deshacer.
3. Elige motor: **Automatic** decide entre degradado e inpainting; **Full AutoMask** usa inpainting; **Improved AutoGrask** ajusta un degradado de color; **Classic AutoGrask** usa el ajuste para papel claro.
4. Corrige el área con **Region + / −** o **Box**, y los defectos con **Ink + / −**. **Detect ink** sustituye la máscara de tinta según la sensibilidad. Las ediciones manuales invalidan la vista previa anterior y se conservan al deshacer y reconstruir.
5. Añade **Point + / −** o una caja y pulsa **Refine with SAM**. El modelo admite seis posiciones de indicación; una caja ocupa dos. Si se supera el límite aparece un mensaje. Deshacer restaura puntos, cajas y máscaras.
6. Compara **Original**, **Mask**, **Fill** y **Vector**. **Rebuild** recalcula la reconstrucción. **Sensitivity** muestra la detección al arrastrar y reconstruye al soltar. **Simplify** controla la tolerancia del contorno; un valor menor conserva más detalle.
7. Elige **Output** y pulsa **Apply**. Cancelar o cerrar deja intactos los subtítulos.

El panel lateral permite desplazamiento en pantallas pequeñas. Durante el trabajo inicial se desactivan los atajos de edición, pero se puede cancelar. Una inferencia nativa en curso puede terminar antes de que salga el proceso.

| Atajo | Acción |
| --- | --- |
| 1–7 | Elegir herramienta. |
| Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z | Deshacer / rehacer. |
| Espacio | Cambiar vista previa. |
| A / S / D / R | Buscar área / refinar con SAM / detectar tinta / reconstruir. |
| Ctrl+Enter | Aplicar. |
| Esc | Cancelar. |
| Rueda / arrastre con botón central | Zoom / desplazamiento. |

## Salidas

| Salida | Cambio en el subtítulo |
| --- | --- |
| ASS fill | Sustituye cada línea por sus dibujos. Copia tiempos, capa y propiedades; selecciona las filas generadas. |
| Shape | Inserta un contorno después de cada fuente, con los mismos tiempos y una capa superior. Conserva el original. |
| `\clip` / `\iclip` | Sustituye el clip y conserva las demás etiquetas, texto y propiedades. |

Shape y los clips solo necesitan un contorno válido: no requieren ajuste de superficie, cuantización ni LaMa. Un contorno pequeño puede ser útil aunque no alcance las muestras mínimas del motor de relleno.

La respuesta completa se valida antes de editar. Regiones ausentes, grupos incompletos, órdenes duplicados o dibujos inválidos impiden aplicar cambios parciales. Los temporales de solicitud, fotograma y respuesta se eliminan al terminar o cancelar. Si se editan subtítulos, se crea una sola acción de Deshacer.

## Calidad, recursos y modelos

Las bandas de degradado siguen el rango ajustado con un paso objetivo de 2.5 unidades. La cuantización de inpainting usa 48 colores. No hay un límite fijo de 48 líneas por región, 512 por trabajo o 128 regiones.

Los límites de entrada son: JSON de 8 MiB, texto de región de 262 144 caracteres y fotogramas de hasta 512 MiB y 67 108 864 píxeles. El análisis geométrico también tiene límites de recursos. Lua admite respuestas de hasta 100 000 000 bytes. El historial usa 64 MiB de máscaras comprimidas por región y puede liberar los estados más antiguos al alcanzar ese tamaño. Los trabajos grandes consumen más memoria y tiempo de renderizado.

La detección de áreas y los degradados funcionan sin modelos. El refinamiento SAM usa EfficientSAM. El inpainting intenta usar LaMa y recurre a OpenCV si no está disponible, indicando la causa en el diagnóstico. Los modelos se verifican con SHA-256 y solo sustituyen al archivo anterior después de una descarga completa y válida.

La configuración se guarda entre sesiones. El backend incluye PNG2ASS para convertir las máscaras en dibujos.

## Ejemplo

En una línea con los tiempos de un aviso de papel, dibuja `\clip(100,80,420,240)`. Abre AutoMask con Whole clip y Automatic. Revisa la tinta, añade las letras omitidas con Ink + y reconstruye. Usa ASS fill para cubrirlas, o Shape/`\clip` para obtener solo el contorno. Revisa toda la duración de la línea: la reconstrucción procede de un único fotograma.
