# Hotkeys 2.0.2

[English](../Hotkeys.md) | Español | [Índice](../../README.es.md#documentación)

Hotkeys permite consultar acciones, gestionar favoritos, migrar atajos y editar preferencias compartidas. Sus entradas predeterminadas son **: Kite Hotkeys :/Sync** y **: Kite Hotkeys :/Config**. La raíz guardada o un menú personalizado de DependencyControl pueden cambiar su ubicación. Requiere UI 1.5.1; las demás macros funcionan sin este editor.

## Sincronizar atajos existentes

Sync lee el JSON de atajos de Aegisub y la configuración de DependencyControl. Propone actualizar rutas por cambios conocidos de nombre, espacio de nombres o menú personalizado. Conserva cada contexto de teclado y sus teclas; para asignar teclas nuevas, usa las preferencias de Aegisub.

La revisión muestra todas las rutas anteriores y propuestas. **Apply** aplica la migración; **Close/Cancel** deja el archivo intacto. Si varias rutas apuntan al mismo comando, sus teclas se combinan sin duplicados. En una cadena A → B y B → C, cada asignación se toma del estado original: las teclas de A no se desplazan dos veces. Una correspondencia que no cambia de ruta conserva el atajo.

Antes de escribir se comprueba que el archivo siga igual que al preparar la revisión. Si Aegisub u otro editor lo cambió, hay que generar otro plan. Se crea una copia `.bak-...` con fecha y hora; las escrituras del mismo segundo reciben sufijos distintos. Un fallo de copia impide la migración. La escritura es atómica y el informe indica dónde quedó el respaldo. Reinicia Aegisub si los atajos no se activan de inmediato.

La migración depende de los registros de DependencyControl y de las rutas reconocidas. Revisa los cambios de menú propuestos; los comandos ausentes de esos registros pueden necesitar reasignación manual. Sync no modifica la preferencia `customMenu` de DependencyControl.

## Rutas y favoritos

Config contiene las rutas del archivo de atajos y de DependencyControl, y las raíces del menú y de favoritos. Los valores iniciales usan las carpetas de usuario de Aegisub. **Registered** muestra acciones de los catálogos registrados por los scripts, las asignaciones existentes y los favoritos guardados. Un catálogo puede seguir presente después de retirar una macro o antes de volver a cargarla.

Elige **Source**, escribe **Favorite path** y pulsa **Add Favorite**. La ruta es relativa a la raíz de favoritos: `Timing/Join` crea un subgrupo. Si está vacía, se usa el nombre final de la acción. Reutilizar una ruta cambia su origen. Las rutas completas se normalizan para evitar raíces duplicadas, incluso cuando contienen varios niveles.

Cada favorito ejecuta la acción original y su validación. Recarga Automation para que el script de origen registre el favorito. Si ese script falta, la asignación permanece guardada hasta que se instale y cargue. Leer el catálogo no permite ejecutar directamente una acción de otro contexto Lua.

**Remove Favorite** borra la asignación guardada; recarga para retirar una entrada ya registrada. **Save** guarda rutas y raíces. **Registered** y **Settings** regresan al formulario conservando los cambios pendientes. Cerrar descarta esos cambios, pero no revierte favoritos ya guardados por Add/Remove. Los fallos de escritura vuelven al borrador con un mensaje.

## Preferencias compartidas

**Settings** muestra los espacios de nombres y sus secciones. Selecciona una y pulsa Edit para cambiar sus valores JSON. Conserva claves y tipos: el JSON inválido o los cambios de estructura se rechazan sin perder el borrador. Save guarda la sección; Back vuelve sin guardarla. Puede ser necesario reabrir o recargar la macro propietaria para que lea los valores nuevos.

La configuración, los favoritos y los catálogos de acciones se guardan en `kite.settings.json`. Puedes usar los demás scripts sin instalar Hotkeys.
