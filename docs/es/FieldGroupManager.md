# Field Group Manager 1.1.8

[English](../FieldGroupManager.md) | Español | [Índice](../../README.es.md#documentación)

Field Group Manager asigna un valor de destino a cada valor distinto de un campo de origen. Trabaja con eventos de diálogo y puede incluir los comentados. Menú: **Field Group Manager**.

## Uso

Elige **Group by**, **Write field**, **Scope** y **Mode**. Por ejemplo, agrupa por Actor y escribe en Layer: si la lista izquierda contiene Alice, Bob y Narrator y la derecha contiene `1`, `2` y `3`, cada grupo recibirá su capa correspondiente. Los textos se ordenan alfabéticamente; los números y tiempos, numéricamente. El orden de selección no determina el orden de la lista.

**Parallel list** asigna una fila derecha a cada grupo. **Single value** escribe el mismo valor en todos. La lista izquierda es una referencia: editarla no cambia los nombres de los grupos.

Cambiar origen, destino, alcance o filtros vuelve a generar las listas antes de ejecutar. **Refresh list** también las regenera y descarta las asignaciones editadas. Revisa la correspondencia y ejecuta de nuevo. Los valores inválidos regresan al borrador; cancelar deja los subtítulos intactos.

## Campos y valores

| Campo | Valores aceptados |
| --- | --- |
| Effect, Actor, Style, Text | Texto literal. Text incluye todas las etiquetas y escapes ASS. |
| Layer | Entero no negativo. |
| Start, End | Milisegundos enteros no negativos, `h:mm:ss.cc` o `mm:ss.cc`. Los segundos y los minutos del formato de reloj deben ser menores que 60 cuando corresponda. |
| Margin L, Margin R, Margin V | Enteros no negativos. Cero mantiene el uso de márgenes del estilo. Margin V actualiza los campos verticales compatibles. |
| Comment | Comment/Dialogue, yes/no, true/false, 1/0; también y/n, si y commented/dialog. |

Los tiempos de la lista se muestran en centésimas. Los que se redondean al mismo valor forman un grupo. Un valor introducido en milisegundos conserva toda su precisión: cambiar 1001 a 1004 sí modifica la línea aunque ambos se muestren como `0:00:01.00`. Se rechazan números no finitos y desbordamientos. Ningún inicio puede superar su fin; se comprueba el plan completo antes de escribir.

Style asigna el nombre literal y no crea una definición de estilo. En **Parallel list**, cada asignación ocupa una fila física del cuadro; usa `\N` para saltos dentro de Text.

## Grupos vacíos y mixtos

**Include empty source** incluye orígenes vacíos con la etiqueta `<empty>`. **Include comments** añade los diálogos comentados. **Selection** usa las filas seleccionadas y **Whole script**, todos los eventos admitidos. Si no hay selección, el alcance inicial es Whole script.

Si un grupo contiene varios valores de destino, su entrada es `<mixed>`. Dejarla intacta omite ese grupo. Escribe `\<mixed>` para asignar literalmente `<mixed>`. Una fila de destino vacía borra los campos de texto y asigna cero a los numéricos o temporales. La lista paralela debe cubrir todos los grupos; se admiten filas vacías al final, pero no filas adicionales con contenido.

## Aplicación y preferencias

Todos los cambios se preparan antes de escribir. Se puede cancelar durante la preparación y la inserción; los errores o cancelaciones restauran lo ya modificado. Quedan seleccionadas solo las filas cambiadas. Si no hubo cambios, se conserva la selección. El informe cuenta grupos y líneas modificados, y grupos omitidos.

Se guardan las seis opciones de agrupación. Las listas pegadas y el texto de Single value se introducen en cada ejecución. La lista admite cualquier cantidad de grupos.
