# Auto Motion

[English](../AutoMotion.md) | Español | [Índice](../../README.es.md#documentación)

Parte de [Hephaestus Fansubber](Hephaestus.md) **1.2.1**.

Auto Motion calcula el seguimiento de una región del vídeo y lo aplica a las líneas seleccionadas. Comparte con [Moka Motion](MokaMotion.md) el módulo [MotionEngine](Dependencies.md#modulos-incluidos): Moka importa datos de seguimiento y Auto Motion los calcula desde el vídeo.

## Generar y aplicar

1. Guarda el ASS para crear la biblioteca junto al proyecto y carga el vídeo correspondiente.
2. Selecciona las líneas del cartel. Su intervalo debe abarcar entre **2 y 5000 fotogramas**; divide los seguimientos largos por escenas.
3. Abre **Hephaestus Fansubber → Automatons → Auto Motion → Generar y aplicar**.
4. Define el área en la ventana de seguimiento. El backend calcula el movimiento con CPU o CUDA según **Hephaestus → Configure**.
5. Revisa el resultado en el vídeo, en especial los bordes de la región, las oclusiones y los cambios de escena.

El resultado conserva muestras continuas por fotograma y se aplica sobre el intervalo de la selección. Los originales quedan registrados para restaurarlos. Si el cartel contiene `\fax`, `\fay`, `\frx` o `\fry`, se conserva esa perspectiva y se muestra un aviso; `\pos` y `\org` siguen el movimiento calculado.

## Biblioteca del proyecto

Junto al ASS se crean `AutoMotion Library.index.json` y la carpeta `AutoMotion Library`, con un JSON por seguimiento. Guarda estos archivos con tu proyecto: contienen los datos AE, la referencia y las líneas originales.

**Historial del proyecto** permite seleccionar un seguimiento y **Reaplicar**:

| Sincronización | Uso |
| --- | --- |
| Fotogramas originales | Reutiliza el intervalo original y comprueba la referencia del vídeo. |
| Alinear al inicio de la selección | Desplaza el seguimiento para reutilizarlo de forma explícita en otro intervalo. |

La selección de destino debe caber dentro del seguimiento. Reaplicar usa las muestras guardadas, por lo que evita repetir el cálculo.

## Restaurar

**Quitar motion de la selección** restaura los originales de un solo seguimiento. Selecciona todos los fragmentos de cada línea que quieras recuperar.

**Borrar y restaurar**, dentro del historial, restaura las líneas vinculadas del proyecto y elimina el JSON de ese seguimiento. La restauración reemplaza las ediciones hechas después de aplicarlo. **Deshacer recupera las líneas, pero el JSON borrado requiere una copia de la biblioteca.**

## Ejemplo

Un cartel ocupa los fotogramas 120–167. Selecciona sus líneas, delimita una región con detalle que permanezca visible y genera el seguimiento. Para aplicar la misma trayectoria a otra capa del cartel, selecciónala y usa el historial con **Fotogramas originales**. Si necesitas empezar de nuevo, restaura los fragmentos antes de generar otro seguimiento.

## Instalación

Usa **Hephaestus Fansubber → Install → Auto Motion** y **Check → Auto Motion**. La biblioteca del proyecto y la configuración compartida permiten reutilizar un seguimiento guardado sin volver a analizar el vídeo.
