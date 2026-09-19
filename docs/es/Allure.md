# Allure 1.2.4

[English](../Allure.md) | Español | [Índice](../../README.es.md#documentación)

Allure guarda estilos reutilizables de carteles ASS y transforma sus capas alrededor de un pivote común. La interfaz está disponible en inglés y español.

Menú: `Allure`.

## Makeup

Makeup guarda dos tipos de registros:

- `[TAG] Name`: preajuste adaptable. Conserva estilos, etiquetas, dibujos, geometría, clips y referencias estructurales, y adapta el tratamiento al texto nuevo.
- `[GROUP] Name`: grupo exacto. Conserva los eventos ASS completos, con texto, dibujos, etiquetas intermedias, perspectiva, Actor, Effect, comentarios, relaciones temporales y orden de capas.

La línea activa es la referencia de captura. Al insertar, posiciones, movimientos, orígenes, perspectiva y clips se desplazan a la referencia de destino. Las diferencias de capa se conservan en todo el grupo.

La biblioteca se guarda junto al subtítulo: `Makeup Library.index.json` contiene el índice y `Makeup Library` contiene un JSON por preajuste. Los registros se cargan cuando se necesitan.

## Capturar e insertar

1. Guarda el ASS para que Allure pueda localizar la biblioteca.
2. Selecciona las capas de origen y activa la línea que servirá de referencia.
3. Escribe un nombre, elige **Save style**, **Save group** o **Save both**, y pulsa **Makeup**.
4. La ventana actualiza la biblioteca. Ciérrala, selecciona el texto de destino, vuelve a abrir Allure y elige el registro.
5. Selecciona **Insert preset**, elige el modo de inserción y pulsa **Makeup**. La salida nueva queda seleccionada.

La captura adaptable agrupa textos visibles idénticos en espacios reutilizables. **Create from targets** necesita un destino por espacio y genera las capas guardadas para cada grupo. Si hay varios espacios, cada grupo de destinos debe ser contiguo y tener el número de líneas requerido. **Replace selected layers** sustituye grupos contiguos completos con tantas filas como el preajuste. Se admite cualquier cantidad de grupos completos.

Usa **Save group** para carteles formados solo por dibujos o para conservar el texto y los campos exactos. Cada destino recibe un grupo completo. Las diferencias de capa, inicio y fin se miden desde la fuente activa: una capa que empieza 200 ms después y termina 100 ms antes conserva esos desplazamientos. Si el destino es demasiado corto, la operación se rechaza y se restauran los cambios.

## Adaptación al texto

Allure respeta los grafemas y compara tokens, puntuación, palabras y frases para colocar las etiquetas en fragmentos equivalentes. Si cambia la estructura, usa posiciones relativas dentro de los tramos disponibles. La geometría protegida del destino tiene prioridad cuando corresponde; las otras capas conservan su desplazamiento respecto a la referencia original. Si un estilo importado debe renombrarse por una coincidencia, también se actualizan sus resets con nombre.

Las bandas de clips rectangulares pueden reconocerse como una familia horizontal o vertical. Los clips que coinciden con el rectángulo del texto pueden adaptarse al nuevo tamaño. Esta detección es aproximada: revisa fuentes, texto multilínea, perspectiva y clips grandes o alejados. **Save group** conserva una composición fija.

## Posing

Posing transforma las capas seleccionadas con un pivote compartido. Permite moverlas en X/Y, cambiar su tamaño por un porcentaje relativo y girarlas alrededor del centro del grupo, de la primera línea o de un punto personalizado. Puede girar el conjunto como una composición rígida o cada línea alrededor de su centro. Los pasos positivos y negativos de X, Y y Z tienen acciones asignables a atajos.

El cambio de tamaño actualiza posiciones, extremos de movimiento, orígenes, clips, dibujos y valores existentes de `\fscx`/`\fscy`. La operación completa se cancela si la geometría es inválida.

Si una línea no tiene `\pos` ni `\move`, su posición se obtiene de PlayRes, la alineación `\a`/`\an` y los márgenes de línea y estilo. Una línea que solo contiene un clip sigue teniendo un punto de referencia de texto. Los extremos de `\move` se desplazan juntos y conservan sus tiempos.

El centro del grupo se calcula con los puntos de referencia y extremos de movimiento seleccionados; no mide el centro visual de todos los caracteres. **First line** usa la primera fila seleccionada. La captura de preajustes usa la línea activa. El pivote personalizado se expresa en coordenadas del script. Un porcentaje positivo amplía el grupo; `-50` reduce su tamaño a la mitad. El resultado debe tener tamaño positivo.

Girar o redimensionar actualiza las etiquetas de apariencia, sus valores en transformaciones anidadas y los resets con nombre. Un clip rectangular estático girado pasa a ser vectorial. Si el rectángulo se anima dentro de `\t`, el giro se rechaza: conviértelo antes a fotogramas independientes. El giro individual de una línea con movimiento y clip requiere un `\org` fijo. Se rechazan líneas con `\pos` y `\move` simultáneos por su ambigüedad.

La escala de un clip vectorial debe ser un entero positivo cuyo factor sea finito. Los valores extremos siguen sujetos a la precisión de Lua y a los límites del renderizador.

## Ventanas, preferencias y recuperación

Config permite elegir idioma, pasos de atajos, modo de giro y pivote. Los valores inválidos mantienen abierta la ventana y conservan el resto de las ediciones. Help, Config y las operaciones sobre la biblioteca regresan al borrador principal. Cerrar cancela la operación actual. Se admiten pasos positivos pequeños.

Los registros y el índice se escriben mediante sustitución atómica. Al reemplazar un preajuste, primero se crea el nuevo registro y después se actualiza el índice; si este falla, el anterior sigue disponible. **Save both** guarda dos registros independientes. Al trasladar una biblioteca, copia juntos el índice y la carpeta de registros.

La inserción y Posing restauran los subtítulos si hay errores o cancelación. Posing excluye comentarios y permite cancelar durante la preparación y la escritura. Un fallo de inserción se informa en la ventana después de restaurar el archivo.

## Dependencias

Sigue los pasos de [instalación](../../README.es.md#instalación) e instala `l0.dkjson` mediante DependencyControl.
