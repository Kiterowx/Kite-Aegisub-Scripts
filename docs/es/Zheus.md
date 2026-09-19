# Zheus Colormanager 4.7.3

[English](../Zheus.md) | Español | [Índice](../../README.es.md#documentación)

Gestiona colores ASS por actor, degradados de cuatro esquinas, sustituciones de color y cambios temporales. Incluye el editor de tramos y herramientas para comparar y adaptar paletas mediante contraste, luminancia y simulaciones de visión del color.

## Entradas y alcance

Selecciona los eventos que quieras revisar o modificar. Los índices duplicados se consolidan; las cabeceras y los estilos no se tratan como diálogos. El gestor admite actores vacíos y conserva los nombres completos, incluidos espacios y Unicode. Dos nombres distintos siguen siendo actores distintos hasta que los fusiones expresamente.

El análisis parte del estilo de cada línea y recorre sus tramos visibles o de dibujo. Lee los colores sólidos y los resets `\r` y `\rNombre` en orden. El color representativo de un actor es el más frecuente entre sus tramos estáticos; los empates se resuelven por primera línea y después por valor de color. El informe conserva las diferencias entre tramos de una misma línea.

Las etiquetas que aparecen después de texto ignorado dentro de llaves siguen activas. Por ejemplo, `{nota \c&H0000FF&}` modifica el relleno, mientras que `{nota sobre el color}` es un comentario. Consulta la [descripción de los bloques ASS de Aegisub](https://aegisub.org/docs/latest/ass_tags/#override-tags).

Las animaciones de color se identifican. El resumen estático no representa todos los instantes de una transformación: para comprobar su evolución usa la previsualización de la escena. Los valores de estilos y los parámetros de etiquetas se interpretan por separado; un número de ocho dígitos en `\c` no se convierte automáticamente en transparencia. La opacidad se conserva mediante los campos de estilo y las etiquetas de alfa correspondientes.

## Panel y comandos

El menú principal es **Zheus Colormanager**. Los otros 17 accesos están bajo `: Kite Hotkeys :/Zheus Colormanager/`. Los nombres registrados se mantienen para conservar los atajos existentes.

| Acceso | Función |
| --- | --- |
| Zheus Colormanager | Panel con resumen de selección, gestores, cambios y cuatro degradados rápidos. |
| Editor de tramos | Edita fronteras y colores de los tramos de una línea. |
| Colores | Abre la paleta de relleno, borde y sombra por actor. |
| VSF | Abre las cuatro esquinas por actor y canal. |
| Actores | Renombra, fusiona o vacía actores de la selección. |
| Cambiar colores | Sustituye valores explícitos en los canales elegidos. |
| ColorRelay | Construye cambios de paleta en fotogramas de control. |
| Daltonismo | Abre el panel de auditoría, perfiles e importación/exportación. |
| Daltonismo/Auditar | Muestra el informe sin modificar subtítulos. |
| Daltonismo/Aplicar Daltonismo | Preselecciona el perfil Daltonismo. |
| Daltonismo/Universal | Preselecciona Universal accesible. |
| Daltonismo/Protanopia | Preselecciona Protanopía. |
| Daltonismo/Deuteranopia | Preselecciona Deuteranopía. |
| Daltonismo/Tritanopia | Preselecciona Tritanopía. |
| Daltonismo/Monocromo | Preselecciona Monocromo. |
| Daltonismo/Alto contraste | Preselecciona Alto contraste. |
| Daltonismo/Calibrar perfil | Crea o actualiza el perfil Personalizado. |
| Daltonismo/Exportar accesible | Exporta la paleta accesible del perfil elegido. |

Los accesos de perfil abren una ventana antes de aplicar. **Cancelar** descarta la edición pendiente. **Volver** regresa a la ventana anterior. Una operación que modifica líneas registra deshacer; los errores y las cancelaciones durante una aplicación restauran el estado previo.

## Colores por actor

1. Abre **Colores** o elige **Colores por Actor** en el panel y pulsa **Gestor**.
2. Edita `\c`, `\3c` y `\4c`: relleno, borde y sombra. Hay ocho actores por página; las flechas conservan lo editado.
3. Elige **Etiquetas**, **Estilos** o **Limpiar** y pulsa **Aplicar**.

El selector inferior y **Abrir** permiten visitar VSF, Lista, Conflictos, Exportar o Importar sin añadir una fila extensa de botones. El modo de aplicación y la opción de limpieza se conservan al navegar.

| Operación | Resultado |
| --- | --- |
| Etiquetas, con auto-limpieza | Quita los colores de relleno, borde y sombra existentes, incluidas sus transformaciones de color, y establece la paleta elegida al inicio y después de resets. Conserva `\2c`. |
| Etiquetas, sin auto-limpieza | Cambia la base del primer bloque y conserva los colores sólidos posteriores. Los degradados de los tres canales editados se retiran para usar colores sólidos. Las etiquetas posteriores pueden seguir prevaleciendo. |
| Estilos | Genera estilos por actor **y por estilo de origen**. Conserva fuente, tamaño, alineación, márgenes, formato y color secundario de cada origen. Los colores elegidos se reiteran después de resets. |
| Limpiar | Quita los cuatro colores sólidos y los cuatro degradados, también dentro de transformaciones. Las demás etiquetas se conservan. |

Los estilos generados pueden reutilizarse cuando su uso está contenido en las líneas de destino. También se consideran las referencias mediante `\rNombre`: un estilo usado fuera de la selección no se sobrescribe. Cuando se insertan estilos, la selección se devuelve con los índices desplazados correctamente.

La limpieza de duplicados conserva la posición del último color válido dentro de su grupo. No desplaza colores a través de resets o transformaciones, que pueden depender del estado anterior.

## Actores

Cada fila muestra el actor original y su destino. Hay ocho filas por página. Escribe el mismo destino en varias filas para fusionarlas, o deja el destino vacío para quitar el actor. **Aplicar** modifica únicamente los eventos seleccionados; **Cancelar** conserva los originales.

## Degradados VSF

Los controles de cuatro esquinas corresponden a `\1vc`, `\2vc`, `\3vc` y `\4vc`. El orden es superior izquierda, superior derecha, inferior izquierda e inferior derecha.

En el gestor por actor, elige el canal y ajusta sus esquinas. Si cambias el canal, primero se guarda el borrador mostrado y luego se presenta el nuevo. El modo **Estilos** no admite degradados VSF: estos se escriben como etiquetas. Cambiar un canal no elimina los colores de los canales restantes.

El panel principal permite activar varios canales y aplicarlos juntos. La opción de limpiar VSF retira los degradados previos; los canales activados reciben su nueva tupla después de los resets. Su apariencia requiere VSFilterMod o un renderizador compatible; libass no renderiza estas extensiones.

## Cambiar colores

Elige los canales que participarán y pulsa **Actualizar** cuando cambies el filtro. Se enumeran los colores explícitos de esos canales, incluidos los destinos de `\t` y las esquinas VSF. Los colores heredados que no están escritos como etiquetas se gestionan desde **Colores** o desde los estilos.

Cada página muestra hasta ocho sustituciones. Los cambios de páginas anteriores permanecen en el borrador. **Aplicar** realiza el mapa completo de sustituciones una sola vez: sustituir rojo por azul y azul por verde no vuelve a transformar en verde el rojo recién sustituido. Los canales desmarcados conservan sus valores.

Se aceptan colores ASS cortos al leer etiquetas y se emiten colores normalizados. Las sustituciones no añaden alfa derivada de los dígitos superiores de un color.

## ColorRelay

ColorRelay necesita vídeo y conversiones de fotograma/milisegundo disponibles. Utiliza las marcas temporales de Aegisub; no presupone una tasa fija cuando se pide una duración en fotogramas.

1. Selecciona las líneas que forman la secuencia.
2. Introduce fotogramas de control y un fundido predeterminado. Puedes escribir `120f, 150f`, `F120`, `120` o una línea como `120f fundido 6f`.
3. Para cada control, asigna nuevos valores a los colores activos. **Omitir** deja ese control sin sustituciones; **Volver** permite revisar el anterior.
4. Al terminar los controles se valida el programa completo y se aplica a la selección.

El fundido admite milisegundos (`240`, `240ms`) o fotogramas (`6f`). Se centra en el instante del control. Cero produce un cambio instantáneo. Una notación como `120f > P1 fundido 6f` también es aceptada; `P1` es texto descriptivo y no selecciona una paleta guardada.

Las sustituciones son persistentes: los controles anteriores se tienen en cuenta al determinar los colores de los posteriores. Los fotogramas inválidos, repetidos o fuera de la selección se informan en conjunto. Los colores de cada control usan la misma ventana paginada que Cambiar colores.

Si un fundido cruza el corte entre dos líneas, ambas conservan sus extremos completos y sus tiempos relativos, incluso negativos. No se reconstruye un segundo fundido a partir de colores redondeados en el corte.

ColorRelay trabaja con canales sólidos uniformes dentro de cada línea. Admite resets iniciales y preserva movimiento, fades y transformaciones de otras propiedades. Antes de modificar nada rechaza cambios posteriores de los canales seleccionados, degradados VSF en ellos, transformaciones de esos colores y fundidos que se solapen en el mismo canal. En esos casos usa el editor de tramos o prepara líneas uniformes; el script no aplana silenciosamente el programa existente.

## Editor de tramos

Elige una línea y abre **Editor de tramos** o **Cambios → Por tramos**. El motor es `Color.segments`.

Puedes cambiar colores y fronteras, dividir un tramo o unirlo con el siguiente, navegar entre canales y restablecer un canal. Las posiciones cuentan grafemas; los espacios y los escapes ASS forman parte del contenido. Se mantienen texto y etiquetas ajenas al canal editado.

Los resets con estilo conocido forman fronteras. Los colores abreviados y los colores restablecidos mediante una etiqueta sin argumento se interpretan en su contexto. Los canales animados se identifican y se protegen frente a una sustitución estática involuntaria; los otros canales siguen disponibles. El editor no convierte dibujos en texto.

## Auditoría y perfiles

El informe compara relleno, secundario, borde y sombra, y recoge el peor contraste de los tramos estáticos. Identifica diferencias entre actores, transparencias, dibujos, colores animados y posibles pérdidas de separación en VSF. La comparación entre actores utiliza sus colores representativos; no enumera cada combinación posible de cada instante.

El contraste de los colores no describe por sí solo la legibilidad sobre el vídeo: influyen el fondo, la opacidad y la presencia real del borde. Las simulaciones son aproximaciones visuales y la calibración registra preferencias; no determina una condición visual.

| Perfil | Comportamiento |
| --- | --- |
| Auditar (`NORMAL`) | Presenta métricas y riesgos sin remapear. |
| Daltonismo (`DALTONICO`) | Prioriza separación tonal, contorno y diferencias entre actores usando la paleta de subtítulos. |
| Universal accesible (`UNIVERSAL_SAFE`) | Incluye candidatos Okabe–Ito y procura conservar identidad cromática. |
| Protanopía (`PROTAN_SAFE`) | Prioriza la simulación de protanopia y separación tonal. |
| Deuteranopía (`DEUTAN_SAFE`) | Prioriza la simulación de deuteranopia y separación tonal. |
| Tritanopía (`TRITAN_SAFE`) | Prioriza la simulación de tritanopia y separación tonal. |
| Monocromo (`MONOCHROME`) | Convierte el relleno a gris según luminancia y elige un contorno contrastante. |
| Alto contraste (`HIGH_CONTRAST`) | Fuerza relleno blanco, borde y sombra negros; conserva el papel del canal secundario. |
| Personalizado (`CUSTOM`) | Se crea con Calibrar y guarda las preferencias derivadas de los pares elegidos. |

El motor puntúa candidatos por contraste, separación en OKLab, luminancia y conservación del color. Las conversiones sRGB/lineal/OKLab pertenecen a `Color` y son las mismas que usa `ShapeOptimizer`. Las cachés de cálculo no limitan el tamaño de la paleta.

En los degradados adaptados, relleno, secundario, borde y sombra conservan su papel. La distribución de luminancia se calcula en luz lineal; una base negra también puede producir esquinas con distinta luminancia. Los perfiles no garantizan que cualquier cantidad de actores alcance todos los umbrales: revisa el resultado y su informe.

### Opciones de aplicación

- **Etiquetas / Estilos:** elige la forma de escribir los colores. Estilos conserva cada estilo de origen y devuelve la selección actualizada; para VSF usa Etiquetas.
- **Preservar alfa:** mantiene los campos de opacidad del estilo y las etiquetas de alfa. Al desactivarlo se fuerza opacidad, también después de resets.
- **Forzar bord y shad:** reemplaza bordes y sombras por los valores del perfil. Desmarcarlo se respeta al volver a abrir la ventana.
- **Incluir dibujos:** permite modificar dibujos ASS. Si está desactivado, se omiten y se informa su cantidad.

El perfil Auditar vuelve a mostrar el informe en lugar de aplicar. Calibrar, Importar y Exportar conservan las opciones del panel. La calibración presenta cinco pares, con respuestas diferentes, iguales o duda; guarda su resultado como Personalizado.

## Paletas y configuración

Las paletas de actores usan el formato de texto v3. Los nombres se codifican por porcentaje para conservar Unicode, separadores y el actor vacío. Una fila contiene `actor|relleno,borde,sombra`, seguida opcionalmente por las tuplas `|1vc:...` hasta `|4vc:...`. La importación también lee v2. Una fila inválida se omite completa; las filas válidas posteriores siguen disponibles. Para un actor repetido prevalece la última fila válida.

Las paletas accesibles v3 son tablas de datos con versión, perfil, actores, colores originales, remapeo y degradados. Al exportar un resultado se guardan sus degradados remapeados. La importación acepta v3 y el formato antiguo v2; aplica los actores presentes en la selección e informa los demás.

Las tablas antiguas se leen con `Settings.parseLiteralTable`, sin ejecutar código Lua. Se admiten tablas, claves, cadenas escapadas, booleanos y números finitos. No hay un tope de tamaño, profundidad o cantidad de actores impuesto por Zheus; se siguen rechazando programas y datos malformados. Las exportaciones se escriben de forma atómica y notifican fallos de escritura.

La configuración y los perfiles personalizados se guardan entre sesiones. Los ajustes anteriores se importan automáticamente.

## Ejemplos de resultado

- Un actor usa Arial en una línea y otra fuente en la siguiente. **Estilos** genera los estilos necesarios y cambia los tres colores elegidos conservando ambas tipografías y sus márgenes.
- `A{\rAlt}B` se analiza como dos tramos. Con auto-limpieza, ambos reciben la nueva paleta, mientras que el reset conserva los demás atributos de Alt.
- Rojo en `\c` y verde dentro de `\t` aparecen en **Cambiar colores**. Cambiar solo el canal de borde deja esa animación del relleno intacta.
- Una lista de 209 colores se edita en 27 páginas de ocho filas. Al aplicar se incluyen las modificaciones de la primera y la última página.
- Un control con fundido entre 100 y 900 ms cruza un corte a 440 ms. La segunda línea conserva `\t(-340,460,...)`, con los extremos originales del color.
