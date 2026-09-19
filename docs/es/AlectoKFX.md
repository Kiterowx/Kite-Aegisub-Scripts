# Alecto KFX 3.4.3

[English](../AlectoKFX.md) | Español | [Índice](../../README.es.md#documentación)

Alecto KFX genera efectos de karaoke y texto a partir de guías editables `intro`, `active` y `outro`. Adapta sus tiempos, posición, movimiento, clips, transformaciones, colores y desvanecimientos a sílabas, grafemas, palabras o líneas completas.

Menú: `Alecto KFX`.

## Comandos

- **Aplicar** genera los efectos y sustituye únicamente la salida asociada a los destinos seleccionados.
- **Generar líneas base** crea bloques de guías editables a partir de los destinos.
- **Validar selección** informa sobre sintaxis, geometría, espacios temporales, problemas de los destinos y cantidad estimada de eventos, sin editar el archivo.
- **Limpiar FX seleccionados** elimina la salida asociada a las fuentes o efectos seleccionados y restaura el estado de comentario original de la fuente.
- **Configurar** guarda los valores temporales predeterminados y el límite de eventos.

Cada comando admite un atajo propio en Aegisub.

## Uso

1. Selecciona una o varias líneas de destino.
2. Ejecuta **Generar líneas base**, o crea guías con `intro`, `active` u `outro` en el campo Effect.
3. Edita estilo, movimiento, clips, tiempos y opciones del campo Actor.
4. Selecciona guías y destinos.
5. Ejecuta **Validar selección** y después **Aplicar**.

Si no seleccionas guías, Alecto busca un bloque contiguo justo encima del primer destino. Una fase ausente utiliza una guía neutra en la capa original del destino.

## Opciones del campo Actor

Unidades: `char` o `grapheme`, `syl` o `syllable`, `word` y `line`.

Opciones disponibles:

- `nobase`, `nofade`, `nostagger`.
- `lead=`, `tail=`, `fade=`, `stagger=`, `gap=`.
- `order=ltr|rtl|center|edges`.
- `group=`, `channel=`.
- `inherit=static|none`.

Los valores de la guía tienen prioridad sobre los del destino; los del destino, sobre la configuración guardada.

## Reaplicación y limpieza

Cada fuente recibe un identificador persistente y sus efectos lo guardan en Effect. Así se distinguen fuentes idénticas y se reconoce la procedencia de un efecto aunque se mueva de fila. Conserva esos metadatos y el valor `alecto-fx`: se utilizan al reaplicar o limpiar.

Los marcadores de la versión 3.1 sin identificador se admiten si siguen junto a su fuente o si esta puede identificarse sin ambigüedad. Si un marcador antiguo movido coincide con varias fuentes idénticas, la operación se detiene sin modificar el archivo.

La generación, la planificación de guías y la comprobación del límite terminan antes de editar los subtítulos. Aplicar, limpiar e insertar guías restaura los cambios si hay un error o una cancelación. Al medir el espacio entre destinos solo se excluye la propia fila; dos destinos idénticos siguen limitándose entre sí. Las guías respetan el orden temporal de los destinos aunque se inserten de abajo hacia arriba.

## Requisitos

Sigue los pasos de [instalación](../../README.es.md#instalación) y conserva `karaskel.lua`, incluido en Aegisub.

Alecto carga primero `karaskel.lua` mediante `include("karaskel.lua")`; usa `require("karaskel")` como alternativa. Las medidas dependen de las fuentes instaladas.

## Unidades y límites

**Aplicar** selecciona los efectos nuevos; **Generar líneas base**, las guías; y **Limpiar FX seleccionados**, las fuentes restauradas.

`char` usa límites de grafemas que agrupan marcas combinantes, emoji unidos mediante ZWJ, banderas regionales y Hangul descompuesto. La agrupación es aproximada y no implementa íntegramente Unicode UAX #29. `\N`, `\n` y `\h` conservan su función de separación y no se convierten en muestras de animación. `syl` sigue los tiempos del karaoke; `word` agrupa palabras visibles; `line` mantiene unido el texto completo.

Los destinos de dibujo `\p` se rechazan. La geometría por unidades en texto multilínea es aproximada: usa `line` o eventos separados para controlar la composición.

## Tiempos, geometría y herencia

Los tiempos de la guía se expresan respecto a su duración. Alecto adapta posición, extremos de movimiento, origen y clips a cada unidad, y adapta los tiempos de transformaciones y desvanecimientos a cada fase. Una transformación entre 200 y 800 ms en una guía de 1000 ms pasa a 60–240 ms en una fase de 300 ms. Los argumentos anidados, nombres de fuentes y resets con nombre se conservan completos.

Intro empieza antes de la unidad; active sigue su intervalo de karaoke; outro empieza después. `lead`, `tail`, `fade` y `stagger` se expresan en milisegundos. `gap`/`respiro` reserva espacio entre destinos vecinos y `channel` determina cuáles comparten ese espacio. `group` selecciona las guías correspondientes. `inherit=none` omite las etiquetas estáticas iniciales del destino, pero conserva las de la guía.

Ejemplo de Actor: `char lead=300 fade=200 stagger=40 order=edges group=outline`. Usa `group=outline` tanto en las guías como en los destinos y valida la selección antes de aplicar.

## Límite de eventos y cancelación

El límite predeterminado es 20 000 eventos. Puedes cambiarlo y guardarlo; **0** lo desactiva. La validación estima la salida y la generación comprueba el límite antes de producir cada evento. Se puede cancelar durante la generación, inserción o eliminación, con restauración de los cambios iniciados. Una salida grande sigue consumiendo memoria y tiempo de procesamiento.
