# Selesub 2.1.8

[English](../Selesub.md) | Español | [Índice](../../README.es.md#documentación)

Selesub busca eventos, selecciona o comenta coincidencias, elimina coincidencias confirmadas, gestiona grupos de valores y transfiere eventos mediante archivos ASS. Incluye veinte acciones de navegación asignables a atajos.

Menú: `Selesub`.

## Buscar y actuar

1. Elige el alcance **All** o **Selection**. Participan Dialogue y Comment, no cabeceras ni estilos.
2. Elige **Select**, **Comment** o **Delete**.
3. Introduce valores exactos o una búsqueda avanzada. Un desplegable vacío no restringe; `<empty>` busca un campo realmente vacío.
4. Pulsa **Run**. Una consulta inválida o sin resultados vuelve a la ventana conservando los valores.

Todos los campos exactos activos deben coincidir: Effect, Actor, Layer y Style. Comparan mayúsculas y espacios. Los desplegables muestran valores del archivo completo aunque el alcance sea Selection. Las etiquetas visuales que coinciden reciben un sufijo numérico, sin alterar el valor real.

La condición avanzada se combina con esos campos. **Invert advanced** invierte solo la condición avanzada, incluida su exclusión; no invierte desplegables ni filtro de comentarios. **Include comments** permite incluir Comment. **First match** se detiene en la primera coincidencia en orden de filas.

**Select** devuelve las coincidencias. **Comment** comenta las que aún no lo estén y las selecciona. **Delete** solicita confirmación con la cantidad encontrada y deja la selección vacía tras borrar. Cerrar la confirmación conserva la selección de entrada. Los cambios se pueden deshacer.

## Campos avanzados

| Campo | Valor examinado |
| --- | --- |
| Text | Texto completo, con etiquetas y comentarios ASS. |
| Visible Text | Texto sin bloques de etiquetas, comentarios ni dibujos. Los saltos y espacios duros se convierten en espacios. No evalúa la transparencia en un fotograma. |
| ASS Comments | Contenido de bloques `{comentario}`, unido con saltos de línea; excluye bloques de etiquetas. |
| Style, Actor, Effect | Propiedad correspondiente. |
| Type | `Dialogue` o `Comment`. |
| Text+Actor+Effect | Los tres campos unidos con saltos de línea. |
| Text+Actor+Effect+Style | Los cuatro campos unidos con saltos de línea. |
| Layer | Capa. |
| Duration | Fin menos inicio, en milisegundos. |
| Word Count | Unidades separadas por espacios del texto visible; no aplica segmentación lingüística. |
| Character Count | Grafemas visibles, excluidos espacios y `. , ? ! ' " —`. Otras puntuaciones cuentan. Conserva juntas marcas combinantes y secuencias de emoji. |
| CPS | Character Count dividido entre segundos de duración, redondeado hacia arriba. Duración no positiva produce cero. |
| Blur | Último `\blur` explícito fuera de transformaciones, o cero si falta. No evalúa transformaciones ni borde del estilo. |
| Margin L, Margin R, Margin V | Márgenes del evento; cero no se sustituye por el margen del estilo. |
| Start, End | Tiempo absoluto. |
| Event Number | Número de evento desde 1 en el archivo completo, sin cabeceras ni estilos. La selección no reinicia la numeración. |

Se rechazan resultados numéricos no finitos. No hay un máximo de coincidencias.

## Operadores

Los campos de texto admiten **Contains**, **Exact**, **Regex**, **All Words** y **Starts With**. **Match case** controla las mayúsculas de la búsqueda avanzada. All Words exige que aparezca cada fragmento de la consulta separado por espacios, sin exigir palabras completas ni orden.

**Exclude** descarta valores que contengan el texto indicado. En Regex también es una expresión regular. Se utiliza el motor de Aegisub y se compila antes de buscar; un error no modifica líneas. Las búsquedas numéricas ignoran Exclude y Match case.

Los campos numéricos y temporales admiten `=`, `>=`, `<=`, **Range**, **Nonzero <=**, **Even** y **Odd**. Range incluye los extremos y acepta invertirlos. Even/Odd solo coinciden con enteros y no requieren consulta. Si el operador guardado no sirve para el campo, se usa Contains para texto y `=` para números o tiempos.

| Tarea | Controles |
| --- | --- |
| Seleccionar carteles de un actor | Actor exacto = actor; Action = Select. |
| Buscar líneas largas en la selección | Scope = Selection; Field = Character Count; Match = `>=`; Find = `45`. |
| Buscar líneas rápidas | Field = CPS; Match = `>=`; Find = `20`. |
| Buscar clips | Field = Text; Match = Contains; Find = `\clip(`. |
| Buscar inicios en un intervalo | Field = Start; Match = Range; Find = `1:02:00.00-1:03:00.00`. Compara el inicio, no el solape de todo el evento. |
| Comparar valores con signo o fracción | Range admite `-3--1` y `1e-3-2e-3`. |

Start y End aceptan milisegundos enteros, `h:mm:ss.fraction`, `m:ss.fraction`, `1h2m3.5s`, `2m3.5s` y `3.5s`. Duration utiliza milisegundos numéricos. En formato con dos puntos, los segundos deben ser menores que 60; también los minutos intermedios del formato de tres partes. Los minutos iniciales del formato de dos partes pueden superar 59. Se rechazan valores inválidos y desbordamientos.

## Gestor de valores

**Values** abre el gestor. Elige **Nature** (Style, Actor, Effect o Layer), **Scope** (Selection o All) y acción. La lista muestra cada valor y su número de eventos.

La lista editable contiene los valores que se van a **conservar**. Elimina uno de ella para actuar sobre sus eventos. La columna de cantidades es informativa. Conserva exactamente las etiquetas, sus espacios y sufijos. Las etiquetas duplicadas no duplican eventos. Una etiqueta desconocida produce un error y conserva el borrador.

| Botón | Resultado |
| --- | --- |
| Apply | Actúa sobre grupos omitidos de la lista. Select los selecciona. Comment/Delete confirman cantidades conservadas y afectadas. Se avisa si una lista vacía afectará a todo el alcance. |
| Current | Usa directamente la selección inicial, sin depender de la lista ni de Nature. Select la devuelve, Comment la comenta y Delete pide confirmación. |
| Refresh | Reconstruye los grupos y vuelve a incluir todos los valores. |
| Close | Regresa sin aplicar el borrador. |

Cambiar Nature o Scope reconstruye la lista antes de actuar. Edita la lista nueva y pulsa Apply otra vez. El gestor incluye comentarios. Guarda su propio alcance y acción; al abrirlo toma inicialmente la acción del panel principal.

## Exportar e importar

**Export** escribe la selección de entrada, no los resultados de filtros que todavía no hayas ejecutado. Primero selecciona eventos. Se añade `.ass` a la ruta si falta. Se exportan información del script, datos del proyecto, todos los estilos y eventos seleccionados en orden. Los datos extra se regeneran con sus referencias. La escritura es atómica y no cambia el texto de origen.

**Import** lee ASS con `myaa.ASSParser`, añade eventos al final e inserta los estilos ausentes antes del primer evento. Reutiliza estilos existentes con el mismo nombre, sin distinguir mayúsculas y sin reemplazar sus propiedades. Por tanto, una línea importada puede adoptar la apariencia del estilo del documento actual. No importa resolución ni metadatos de proyecto. Los resets con nombre se conservan tal como están.

Estado Dialogue/Comment, texto, campos y datos extra proceden del analizador. La selección final contiene los eventos importados y tiene en cuenta los estilos insertados. Fallos de lectura o importaciones vacías no cambian el archivo. El analizador puede omitir registros ASS mal formados; no convierte otros formatos ni importa fuentes o gráficos incrustados.

Una importación o exportación correcta cierra la ventana. Cancelar el selector o fallar devuelve al borrador de búsqueda.

## Atajos

Bajo `: Kite Hotkeys :/Selesub`, **Style**, **Actor** y **Effect** ofrecen seis acciones basadas en el valor exacto de la línea activa:

| Acción | Comportamiento |
| --- | --- |
| Select All | Selecciona todos los eventos con ese valor y conserva la línea activa. |
| Previous / Next | Salta a la coincidencia anterior o siguiente, sin volver al otro extremo del archivo. |
| Block Start / Block End | Selecciona el primer o último evento del bloque contiguo de la línea activa. |
| Select Block | Selecciona todo ese bloque y conserva la línea activa. |

`Range/To Start` selecciona desde el primer evento hasta el activo; `Range/To End`, desde el activo hasta el último. Ambos incluyen la línea activa. Los comentarios participan en todas las acciones. Una línea activa inválida no altera la selección. No se requiere la macro Hotkeys.

## Preferencias y dependencias

Tras Run correcto se guardan alcance, acción, campo, operador y casillas. No se guardan valores exactos ni textos de búsqueda o exclusión. El gestor guarda Nature, Scope y Action. Los fallos de escritura se notifican.

La búsqueda y las ediciones permiten cancelar. Comentar, borrar e importar usan transacciones; exportar usa escritura atómica. No hay un máximo fijo de eventos ni de tamaño de importación.

Instala `myaa.ASSParser` y sigue los pasos de [instalación](../../README.es.md#instalación).
