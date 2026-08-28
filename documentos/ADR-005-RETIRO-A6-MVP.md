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
