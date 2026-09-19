# Moka Motion 3.7.6

[English](../MokaMotion.md) | Español | [Índice](../../README.es.md#documentación)

Moka Motion aplica e invierte movimiento de Mocha, convierte máscaras en clips o dibujos, aplica perspectiva de cuatro esquinas, corrige seguimientos por fotogramas y exporta material para tracking.

Menú: **Moka Motion**, con el prefijo personalizado de DependencyControl si está configurado.

## Comandos

| Comando | Entrada | Resultado |
| --- | --- | --- |
| Motion/Apply Motion | Datos AE Transform y líneas seleccionadas. | Líneas con seguimiento. |
| Motion/Revert Motion | Los mismos datos y las líneas correspondientes. | Una aplicación inversa. |
| Shapes/Create Clip | Exportación de máscara admitida. | `\clip` animado. |
| Shapes/Create Inverse Clip | Exportación de máscara admitida. | `\iclip` animado. |
| Shapes/Create Vector Drawing | Exportación de máscara admitida. | Dibujos ASS posicionados. |
| Perspective/Apply Power Pin | CC Power Pin o Corner Pin. | Perspectiva y clips opcionales con seguimiento. |
| Track Refinery | Líneas por fotograma con posición explícita. | Análisis, suavizado, reparación de duplicados o ajuste de extremos. |
| Utilities/Optimizer | Estados consecutivos compatibles. | Menos eventos. |
| Utilities/Inspect Mocha Data | Exportación admitida. | Diagnóstico de formato, muestras, tiempos y canales. |
| Utilities/Create Video Clip | Intervalo seleccionado y vídeo local. | MP4 H.264 verificado. |
| Utilities/Create Exact PNG Sequence | Intervalo seleccionado y vídeo local. | Secuencia PNG numerada por fotogramas de origen. |
| Utilities/Trim Settings | Rutas de codificadores. | Configuración de FFmpeg/x264. |

## Intervalo y correspondencia de datos

Las herramientas de tracking y exportación usan diálogos sin comentar de duración positiva y requieren códigos de tiempo del vídeo. La selección se normaliza y abarca desde el inicio más temprano hasta el fin más tardío, incluidos los huecos. El final de fotograma es exclusivo: del 103 al 160 hay 58 fotogramas y el límite final es 161.

Pega la exportación o escribe la ruta de un archivo de texto. El valor inicial procede del portapapeles. Se admiten BOM UTF-8 y finales de línea CRLF, CR o LF. **First data row** empieza en 1 y designa una entrada de la lista interpretada, no el número de la columna Frame.

**Reference row** elige la muestra neutra después de recortar desde First data row. Su valor inicial sigue el cursor de vídeo si está dentro de la selección; si no, usa 1. Se limita a las muestras disponibles.

| Correspondencia | Uso |
| --- | --- |
| Selection timeline | Un seguimiento para toda la selección, incluidos los huecos. |
| Restart on each line | Cada línea empieza en la primera muestra recortada. Se necesitan datos para la línea más larga. |

Motion y Shapes ofrecen ambos modos. Power Pin utiliza Selection timeline. Si faltan datos, se indican cantidades disponibles y necesarias. Una máscara estática puede mantenerse durante todo el intervalo.

La sincronización estricta rechaza fotogramas ausentes o interpolados, saltos ambiguos de giro, fases incompatibles de FPS/códigos de tiempo y diferencias de proporción de píxel entre fuente y composición. Reconoce tasas redondeadas habituales, como 23.976 para 24000/1001. El reinicio por línea y las formas estáticas usan su contexto temporal correspondiente. Desactivar este control permite las aproximaciones notificadas.

Los errores devuelven al formulario conservando texto y opciones. Cancel lo cierra. La aplicación tiene una acción de Deshacer; errores o cancelaciones restauran el subtítulo. La selección final sigue las filas generadas o reemplazadas.

## Aplicar e invertir Transform

AE Transform admite Position, Scale, Rotation, Anchor Point y Opacity. Debe existir al menos Position, Scale o Rotation. Una escala única se usa en X/Y. Sin Position, el centro de origen exportado sirve de pivote. Las muestras ausentes se interpolan y se notifican. Los números de fotograma deben ser enteros finitos representables; se rechazan celdas numéricas inválidas y fotogramas duplicados.

El giro distingue cruces habituales de ±180/360 grados de vueltas acumuladas explícitas. Los saltos ambiguos se conservan y se notifican. Anchor Point se guarda para diagnóstico y no se aplica dos veces. Opacity se lee, pero no cambia la geometría ASS.

| Control | Función |
| --- | --- |
| X / Y | Aplica el componente de posición. |
| Scale / Rotation | Aplica proporciones de escala y giro respecto a la referencia. |
| Move `\org` | Desplaza el origen explícito. |
| Transform clips | Aplica seguimiento a clips rectangulares o vectoriales. |
| Clips only | Cambia clips y conserva la geometría del texto. |
| Borders / Shadows / Blur | Escala las propiedades elegidas con el seguimiento. |
| Absolute position | Usa la posición exportada sin conservar el desplazamiento relativo. |
| Compact linear motion | Usa una representación lineal compacta cuando los canales y etiquetas lo permiten. |
| Optimize FBF states | Aplica después el optimizador conservador de 0.05 unidades. |

Las coordenadas se convierten del tamaño exportado a PlayRes. Estilos y etiquetas estáticas definen la geometría inicial; las temporales se evalúan para cada estado. Se conservan los límites parciales del primer y último evento, y se desplazan los tiempos de karaoke para cada fragmento.

Se admiten números finitos con signo, decimales y exponentes. Los comentarios no aportan geometría. Los clips vectoriales se validan y transforman por pares de coordenadas; su escala explícita se convierte primero a escala 1. Se respetan los argumentos anidados de etiquetas y transformaciones.

Revert aplica la inversa matemática de los datos, correspondencia y referencia elegidos, sin depender de una copia oculta. Usa las mismas opciones que en la aplicación. Una escala cero se rechaza porque no tiene inversa. Algunas combinaciones de escala anisótropa y giro necesitan inclinación que Transform no puede expresar exactamente; el informe remite a Power Pin/Perspective. La inversa no recupera detalle perdido por redondeo o aproximación.

## Corregir datos de entrada

**Duplicate sample** ofrece Off, Detect only y Repair duplicate sample. Busca una pausa aislada en posición seguida de movimiento, con datos compatibles de escala/giro. Detect only informa. Repair retira la muestra repetida de la progresión y extrapola una nueva al final para conservar la cantidad. Revisa las pausas intencionales antes de reparar.

**Cleanup** ofrece Off, Protective y Local regression. Protective evalúa residuos por canal para estabilizar valores casi constantes, ajustar tramos suficientemente lineales o corregir un valor aislado. Local regression usa **Window** y **Degree**. El ajuste permanece anclado a la referencia y el informe cuenta los valores cambiados.

Window utiliza como máximo las muestras disponibles. Degree 1–3 corresponde a ajuste lineal, cuadrático o cúbico. El formulario aplica la intensidad completa; Track Refinery tiene un control de intensidad independiente. Cleanup es opcional y empieza en Off.

## Clips y dibujos

Admite bloques AE Mask `Shape` con vértices y tangentes opcionales, `Bezier(Point(...))` antiguo y Shake RotoShape SSF 4.0. Se validan cantidades de tangentes y coordenadas finitas.

Los datos AE y antiguos conservan la forma previa en fotogramas ausentes. Shake interpola disposiciones de puntos compatibles y mantiene la geometría disponible en los demás casos. Las muestras interpoladas o mantenidas se identifican y la sincronización estricta puede rechazarlas porque no se conoce su aceleración original. Algunos estados invisibles o no admitidos necesitan edición en la exportación.

| Control | Función |
| --- | --- |
| Placement: Replace selection | Sustituye las fuentes seleccionadas. |
| Placement: Insert new lines | Conserva fuentes e inserta después de ellas. |
| Offset X / Y | Añade desplazamiento después de escalar coordenadas. |
| Tangent epsilon | Decide cuándo una Bézier casi recta puede escribirse como segmento. |
| Inserted layer + | Diferencia de capa de la salida insertada. |
| Drawing tags | Etiquetas adicionales; inicialmente borde y sombra cero. |
| Use exported source size | Prefiere las dimensiones exportadas a Source W/H. |
| Scale to target | Convierte al tamaño Target W/H. |
| Source W/H / Target W/H | Sistemas de coordenadas de entrada y salida. |
| Decimals | Precisión de 0 a 6 decimales. |

Los clips siguen el estado temporal del texto. Los dibujos reciben `\an7`, posición, escala unitaria y modo de dibujo propios, con trayectos en coordenadas locales. Los estados estáticos consecutivos idénticos pueden unirse si ninguna etiqueta dependiente de la duración lo impide.

## Power Pin

Se reconocen las cuatro esquinas CC Power Pin o Corner Pin y se ordenan para resolver la perspectiva. Todos los canales deben existir. Solo se interpolan muestras ausentes si lo permite la sincronización estricta. Se rechazan cuadriláteros cruzados, cóncavos, inválidos o numéricamente degenerados; se admiten cuadriláteros subpíxel válidos.

**Perspective** controla la perspectiva; **Position**, **Border / shadow** y **Clips**, sus componentes asociados. **Origin mode** ofrece Keep `\org`, Force stable center y Try `\fax0`. El cálculo considera PlayRes/LayoutRes y el tamaño del vídeo. Cada fuente usa una referencia dentro de su propio intervalo. Los estados no admitidos se notifican antes de insertar.

Esta operación utiliza AssContext y la biblioteca de perspectiva. Puede expresar deformaciones que exceden escala X/Y y giro, pero requiere una referencia válida y geometría compatible. Revisa visualmente el resultado.

## Track Refinery

Selecciona diálogos por fotograma con `\pos` explícito. Se agrupan por capa, estilo, actor, texto e intervalos de fotogramas contiguos. Se excluyen líneas sin posición utilizable, duración positiva o tiempos de vídeo.

| Operación | Función |
| --- | --- |
| Analyze | Informa de tamaños, pasos, ciclos y posibles duplicados. |
| Smooth / Denoise | Ajusta movimiento local, solo anomalías o el seguimiento completo. |
| Repair Duplicate Frame | Repara una muestra duplicada detectada. |
| Retarget Start | Lleva el inicio hacia Target X/Y y conserva gradualmente el final. |
| Retarget End | Conserva el inicio y lleva gradualmente el final hacia Target X/Y. |

Window define el vecindario; Degree, el grado del ajuste. Strength admite 0–100 %. Min residual fija el umbral base para anomalías. **Preserve authored zig-zag / cycles** detecta patrones repetidos y fases geométricas, incluidos ciclos de más de ocho fotogramas. No puede reconocer cualquier movimiento intencional.

**Shift linked `\org` and clips** desplaza su geometría con la corrección de posición. **Smooth scale / rotation / styling geometry** considera canales estáticos completos de escala, giro, borde, sombra y desenfoque. Se omiten canales ausentes y etiquetas escritas en comentarios.

El informe cuenta líneas distintas cambiadas, también si solo cambia una propiedad escalar. Todos los cambios permiten deshacer y restaurar. Retarget admite uno o dos fotogramas; suavizar y reparar duplicados necesita al menos tres muestras.

## Optimizer

Ofrece Exact (0), Conservative (0.05) y Subpixel (0.10). Compara estados consecutivos con la referencia conservada para impedir que pequeñas diferencias acumulen desplazamiento. Mantiene diferencias de metadatos y datos extra, y protege movimiento, transformaciones, desvanecimientos y karaoke dependientes de la duración. Algunos dibujos o estados de perspectiva no se pueden combinar.

Informa de cantidades iniciales/finales, estados unidos, secuencia más larga, seguimientos temporales y estados protegidos. Sin grupos compatibles no edita ni crea Deshacer. La tolerancia se mide en coordenadas del script.

## Inspeccionar una exportación

Inspect muestra formato, muestras, primer y último fotograma de origen, FPS y tamaño. En Transform también analiza duplicados. Notifica canales desconocidos, interpolación, escala uniforme expandida, giros ambiguos y datos no admitidos. No edita los subtítulos.

## Exportar material para seguimiento

**Create Video Clip** toma el intervalo seleccionado y el vídeo local. Prefiere FFmpeg con libx264 y recurre al ejecutable x264 si hace falta. La alternativa extrae MKV sin pérdida cuando x264 puede leerlo, o Y4M. No incluye audio. Los tiempos irregulares se convierten a una tasa constante indicada para MP4.

El intermedio codificado y el MP4 final se decodifican para verificar su cantidad de fotogramas. Solo un MP4 válido se traslada a la carpeta de origen. Su nombre incluye el primer y último fotograma, con sufijo numérico si ya existe. Un error deja un registro y puede conservar un MKV intermedio útil; retira extracciones temporales y MP4 incompletos. No sustituye una exportación anterior.

**Create Exact PNG Sequence** solicita un nombre base y crea una carpeta `_frames`, o una variante numerada si existe. Los nombres `frame_%08d.png` empiezan en el número de fotograma original. Se conserva la correspondencia temporal y se valida cada PNG. Una salida incompleta se conserva para revisión y se notifica.

**Trim Settings** guarda rutas de FFmpeg y x264 en `kite.MokaMotion`. Vacías usan `PATH`. Cancelar el selector conserva lo escrito; un fallo de guardado mantiene el formulario. Las opciones de movimiento y formas son borradores de cada ejecución.

En Windows los procesos externos no abren consola, admiten rutas Unicode, espacios y apóstrofos, y recogen diagnósticos. La cancelación puede esperar a que termine el proceso nativo y se informa con código 130. PyBridge gestiona argumentos, finalización y cancelación; AssDrawing transforma trayectos ASS completos, incluidos splines.
