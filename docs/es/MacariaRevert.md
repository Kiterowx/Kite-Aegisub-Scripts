# Macaria Revert 1.0.2

[English](../MacariaRevert.md) | Español | [Índice](../../README.es.md#documentación)

Macaria Revert reconstruye líneas base de karaoke a partir de eventos generados. Complementa [Alecto KFX](AlectoKFX.md) y [Zagreo Glyphs](ZagreoGlyphs.md). Usa las relaciones temporales y espaciales presentes en el efecto; no puede recuperar información que se haya descartado.

Comandos predeterminados: **Macaria Revert** y **: Kite Hotkeys :/Macaria Revert/Reconstruct**. Un menú personalizado de DependencyControl puede añadir un prefijo.

## Uso

1. Selecciona los eventos del karaoke que quieras recuperar, incluyendo sus capas y fases cuando sea posible.
2. Abre Macaria Revert y ajusta tolerancias, espacios y alineación.
3. Pulsa **Preview** para revisar la cantidad y el texto ASS completo de las bases propuestas.
4. Ajusta y vuelve a previsualizar si hace falta.
5. Pulsa **Reconstruct** para guardar las opciones e insertar las bases.

Los originales se conservan. Las bases se insertan comentadas, con `Effect=karaoke`, después del último diálogo seleccionado. Quedan seleccionadas y la primera pasa a estar activa. La inserción tiene una sola acción de Deshacer y restaura los cambios si falla o se cancela. Los índices repetidos, desordenados o fuera de rango se normalizan.

Preview no edita ni guarda preferencias. El informe es de consulta: modificar su texto no cambia las propuestas. Reconstruct vuelve a analizar la entrada con las opciones actuales. Cancel descarta el borrador.

Si no se encuentra una cadena válida o hay un error de análisis, la ventana conserva las opciones y muestra el informe. Si falla el guardado de preferencias, no se insertan líneas y se conserva el borrador. La cancelación durante el análisis se comunica como tal.

## Controles

| Control | Función | Valor inicial |
| --- | --- | --- |
| Position tolerance | Diferencia máxima por coordenada al relacionar posiciones y fases. | 4 unidades ASS. |
| Row tolerance | Separación vertical admitida al agrupar fragmentos en una fila. | 20 unidades ASS. |
| Time tolerance | Diferencia admitida entre límites temporales vecinos. | 10 ms. |
| Infer word spacing | Usa medidas de estilo y separaciones entre capas para deducir espacios. | Activado. |
| Include alignment tags | Escribe la alineación deducida si difiere del estilo base. | Activado. |

Las tolerancias deben ser finitas y no negativas; cero exige coincidencia exacta. Valores grandes pueden unir fragmentos ajenos. Las coordenadas y la alineación utilizan la resolución del documento actual, aunque una configuración antigua conserve 1280×720.

El informe desplazable muestra todos los eventos propuestos. El tamaño físico de la ventana depende de Aegisub y de su fuente de interfaz.

## Patrones reconocidos

| Patrón | Datos necesarios | Tiempos recuperados |
| --- | --- | --- |
| Fases de transformación emparejadas | Eventos previos y activos coincidentes, con una transformación activa utilizable. | Intervalos contiguos de la transformación activa. |
| Capas activas repetidas seguidas de un cuerpo | Al menos tres copias móviles coincidentes y un cuerpo fijo con final común. | Inicios activos y final del cuerpo. |
| Cadena de eventos contiguos | Fragmentos ordenados espacialmente, tiempos vecinos y fases repetidas. | Tiempos de fragmentos e intervalo de fase deducido. |

Se prueban en ese orden. Las capas equivalentes se agrupan para evitar bases duplicadas. Recuperar un intervalo no impide recuperar otro posterior en la misma fila. La búsqueda termina cuando no quedan candidatos; la longitud mínima y la cobertura exigidas sirven para reconocer el patrón.

Los comentarios del texto no aportan etiquetas. Solo `\pos` o `\move` válidos fuera de transformaciones aportan la posición del fragmento. El movimiento se evalúa al inicio del evento; `\an`, `\a` y la alineación del estilo usan AssContext. Los eventos con posición exclusivamente implícita se omiten porque no revelan la distribución de fragmentos separados. Se conserva el texto fuera del modo de dibujo, incluidas fases invisibles y escapes ASS. Los resets terminan el modo de dibujo. Se interpretan transformaciones con aceleración o duración implícita.

La salida usa `\k` en centésimas. Se cuantizan límites acumulados para conservar la duración total: 33, 33 y 34 ms producen `\k3`, `\k4` y `\k3`. El estilo pertenece al grupo recuperado; se toma la capa más baja y los valores más frecuentes de actor y márgenes. El resultado es una base editable, sin reproducir la apariencia del efecto.

## Ejemplo

Supón que A aparece de 0 a 500 ms y B, más a la derecha, de 500 a 1000 ms, con fases repetidas 1000 ms después. Si se reconoce el patrón y no se deduce un espacio, se puede proponer esta base comentada de 0 a 1000 ms:

```ass
{\k50}A{\k50}B
```

Revisa tiempos y texto antes de reutilizarla. Si falta un espacio, comprueba las separaciones y medidas de fuente. Si se omite una fila, revisa posiciones, duraciones y fases antes de ampliar tolerancias.

## Acceso directo y preferencias

El comando directo ejecuta inmediatamente con los valores predeterminados del motor; no reutiliza los ajustes guardados de la ventana. Si falla o no encuentra bases, no inserta nada. Usa la ventana para configurar y revisar.

Instala los módulos incluidos en el repositorio. Las preferencias de reconstrucción se guardan entre sesiones.

## Límites

La reconstrucción es aproximada y los patrones ordinarios y emparejados ordenan las cadenas horizontalmente. Fragmentos superpuestos, movimientos poco habituales, selecciones incompletas, fuentes ausentes o tiempos originales perdidos pueden requerir correcciones manuales.
