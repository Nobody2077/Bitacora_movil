# ADR-004 — Diferimiento de A6 y activación excepcional de A7

- Estado: superado por ADR-005
- Fecha: 27 de agosto de 2026
- Alcance: secuencia A6–A8

> Conservado como registro histórico. Desde el 28 de agosto de 2026,
> `ADR-005-RETIRO-A6-MVP.md` retira A6 del MVP y elimina G6 como requisito de
> A8.
>
> Adenda del 24 de septiembre de 2026: la copia de seguridad vuelve como
> último bloque del post-MVP, tras Personaje, Contactos, Inventario y Tienda
> (ADR-006, D2). Detalle en la adenda de ADR-005.

## Contexto

El usuario aprobó físicamente la ampliación final de Progreso el 27 de agosto
de 2026. Con la evidencia automatizada ya registrada, A5 y G5 quedan cerradas.

La secuencia original indicaba A6 — copia y restauración — antes de A7 — UI v2
y accesibilidad. El usuario decidió diferir A6 y continuar con A7 para completar
primero la experiencia visual y accesible. Esta decisión cambia el orden de
ejecución, pero no elimina alcance ni convierte una puerta no ejecutada en verde.

## Decisión

- A6 permanece **DIFERIDA/PENDIENTE** dentro del MVP. G6 no está ejecutada.
- A7 queda **EN CURSO POR EXCEPCIÓN EXPLÍCITA** desde el 27 de agosto de 2026.
- La excepción solo permite desarrollar y validar A7 antes de A6.
- A8 no puede comenzar ni declararse lista para release hasta que **G6 y G7**
  estén verdes.
- Al retomar A6, sus pantallas de exportación, importación, progreso, error y
  confirmación deben usar las convenciones Terminal V2 y de accesibilidad que
  A7 deje consolidadas.

## Consecuencias

- Los estados de fase deben distinguir “diferida” de “completada”.
- G7 puede reunir evidencia técnica y física propia, pero por sí sola no
  desbloquea A8.
- El orden de trabajo vigente es: continuar A7, retomar y cerrar A6/G6, cerrar
  cualquier evidencia pendiente de G7 y solo entonces iniciar A8.
- Esta excepción prevalece sobre la regla general de secuencia inmediata de
  `DECISIONES_PRE_A0.md`; todas las demás puertas siguen vigentes.
