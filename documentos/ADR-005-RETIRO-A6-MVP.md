# ADR-005 — Retiro de A6 del MVP

- Estado: aceptado
- Fecha: 28 de agosto de 2026
- Alcance: copia/restauración y secuencia A6–A8
- Supera: ADR-004 para el estado y las dependencias de A6

## Contexto

A6 proponía exportación y restauración cifrada portable. El usuario decidió
retirarla del MVP para mantener la aplicación concentrada en su uso local,
evitar interfaz y mantenimiento innecesarios y no crear archivos o historiales
de copia que consuman espacio.

La funcionalidad nunca llegó a implementarse. Por tanto, retirarla no elimina
datos, no requiere migración y no cambia el esquema Drift v1.

## Decisión

- A6 queda **RETIRADA DEL MVP**, no diferida ni completada.
- G6 queda **RETIRADA / NO APLICA** y deja de ser requisito para A8.
- No se implementarán exportación, importación, restauración, copias
  programadas ni historial local de copias en la versión 1.0.
- A7 continúa hasta reunir G7. A8 podrá comenzar cuando G7 esté verde.
- `android:allowBackup="false"` se conserva: Android no debe copiar de forma
  automática los datos privados de la aplicación.
- Una futura copia portable requerirá una nueva decisión explícita y un nuevo
  alcance; no se reactivará A6 de manera implícita.

## Consecuencias

- La aplicación no reservará almacenamiento para copias ni crecerá por un
  historial interno de exportaciones.
- La recuperación de acceso continúa permitiendo reemplazar el PIN, pero no es
  una copia de los datos.
- Desinstalar la aplicación, perder el dispositivo o perder la clave local
  puede causar pérdida definitiva de la información. Esta limitación debe ser
  visible antes del release.
- El orden vigente queda: cerrar A7/G7 y después ejecutar A8.

## Adenda del 24 de septiembre de 2026 — la copia se cierra al final

Al resolver la decisión D2 de `ADR-006-PERSONAJES-TIENDA-INVENTARIO.md`, el
usuario decidió que **la falta de copia de seguridad se cierra al final**,
después de Personaje, Contactos, Inventario y Tienda. Esta adenda no revoca
ADR-005 —A6 sigue retirada del MVP y G6 sigue sin aplicar—, pero deja de ser
una retirada indefinida: la copia vuelve como **último bloque del post-MVP**,
con alcance propio por decidir entonces (volcado técnico o exportación con
restauración).

Mientras tanto, **la migración v3 → v4 de ADR-006 se ejecutará sin copia
previa**, con el riesgo aceptado por escrito por el usuario: un fallo sobre
datos reales es irrecuperable. El 24 de septiembre de 2026 el gate G8 borró la
instalación de la tablet (datos de prueba), lo que confirma que esta
limitación no es teórica.
