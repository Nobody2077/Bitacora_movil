# ADR-006 — Personajes, Tienda e Inventario

- Estado: **propuesto (borrador)** — no implementar hasta que el usuario
  resuelva las decisiones abiertas D1, D2 y D3
- Fecha: 13 de septiembre de 2026
- Alcance: ficha de personaje, tienda de recompensas, inventario y la
  migración de esquema v3 → v4 que implican
- Depende de: ADR-001 (persistencia), ADR-002 (acceso), ADR-003 (títulos,
  rachas y niveles), ADR-005 (retiro de A6)
- Precedencia: no altera ADR-001 a ADR-005; los amplía. Si algún punto entra
  en conflicto, prevalece el ADR anterior hasta que este se acepte

## Contexto

`DECISIONES_PRE_A0.md` dejó Personajes, Tienda e Inventario como post-MVP. El
7 de septiembre de 2026 el usuario acotó ese post-MVP a **esos tres y nada
más**: loadouts, servidor y sincronización quedan **descartados**, no
aplazados. El proyecto sigue siendo local-first y de un solo usuario por
decisión.

Este bloque no se abre hasta cerrar A11 (notificaciones) y A8 (release). El
presente documento existe para que la conversación de diseño llegue con los
hechos delante, no para autorizar código.

### Qué hay ya construido que sirve de base

Media ficha de personaje existe, repartida por el proyecto:

| Pieza | Dónde vive | Qué aporta a la ficha |
|---|---|---|
| XP total y por área | `xp_transactions`, `progress_dao.dart` | La métrica de progreso |
| Nivel global y por área | `RpgLevel.fromTotalXp` | `floor(sqrt(xp / 100)) + 1` |
| Títulos | `title_definitions`, `title_history` | Permanentes, dinámicos y temporales |
| Rachas | Progreso, contrato en ADR-003 | Racha actual y mejor racha |
| Nombre y avatar | `UserProfile`, barra lateral de tablet | Identidad visible |

**Personajes sería sobre todo reunir eso en una ficha, no inventarlo.** El
trabajo real de esa parte es de presentación y de agregación, no de dominio
nuevo.

### Qué falta de verdad

No existe ninguna tabla de tienda ni de inventario. El esquema v3 tiene 19
tablas y ninguna sirve de base: `transactions` es dinero real y
`xp_transactions` es un libro mayor de puntos ganados. Añadirlas significa
**la primera migración v3 → v4 del proyecto**, con snapshot
`drift_schemas/drift_schema_v4.json` nuevo y pruebas `migrateAndValidate`.

## Hallazgo bloqueante: el XP actual no se puede gastar tal cual

Esto no es una preferencia de diseño, es una restricción del código vigente y
condiciona la decisión D1.

**El nivel se calcula sobre la suma completa del libro mayor.**
`progress_dao.dart:173` hace `COALESCE(SUM(amount), 0)` sobre
`xp_transactions` sin filtrar, y `rpg_level.dart:18` deriva el nivel de ese
total. Los umbrales son `100 * (n - 1)²`.

**Consecuencia directa:** si una compra insertara un asiento negativo en
`xp_transactions`, el personaje **perdería niveles al comprar**. Gastar 400 XP
a nivel 3 devuelve al usuario a nivel 2. Eso destruye el sentido del progreso:
el jugador aprende a no comprar nunca.

**Además, el esquema lo impide hoy.** `xp_transactions` obliga a
`amount > 0` salvo cuando `source_type = 'MANUAL_ADJUSTMENT'`, y ese caso
exige `reason` no vacío. Un asiento de compra tendría que disfrazarse de
ajuste manual, que es exactamente lo que ADR-001 §3 quiso cerrar. Abrir un
`source_type` nuevo requiere tocar el `CHECK`, y eso ya es migración.

**Las tres salidas posibles**, para tenerlas presentes al decidir D1:

1. **Moneda separada.** El XP nunca se gasta y sigue midiendo el nivel; las
   misiones acreditan además monedas en un libro mayor propio. Es el modelo
   RPG clásico (XP y oro son cosas distintas) y **no toca `xp_transactions`
   ni el cálculo de nivel**. Es la más barata y la única que deja intacto el
   contrato de ADR-003.
2. **Dos sumas sobre el mismo libro.** El nivel pasa a usar «XP ganado»
   (`SUM` de los positivos) y el saldo gastable usa el neto. Reutiliza la
   tabla, pero **cambia el significado de una consulta ya validada**, obliga a
   revisar niveles por área y títulos, y deja dos números parecidos con
   nombres parecidos. Riesgo alto de confusión, poco ahorro real.
3. **Pagar con dinero real** (`transactions`). Ya no es un juego, es
   contabilidad. Se trata aparte, en D1.

## Decisiones abiertas — las resuelve el usuario

### D1. ¿Con qué se paga en la Tienda?

**Es la decisión estructural.** De ella cuelga todo lo demás, y son dos
productos distintos:

- **Con XP o una moneda derivada del XP.** Sistema cerrado y coherente con el
  marco RPG: cumples misiones, ganas puntos, los cambias por recompensas que
  tú mismo defines («dos horas de videojuegos», «una cena fuera»). No mezcla
  el juego con la contabilidad. Requiere elegir entre las salidas 1 y 2 de
  arriba; **la recomendación es la 1, moneda separada.**
- **Con dinero real** (`transactions`). La Tienda se convertiría en un
  registro de caprichos con presupuesto: reservas dinero, lo gastas, queda
  anotado como `EXPENSE`. Es defendible, pero entonces «Tienda» es una vista
  de Economía y no una mecánica de juego, e Inventario pasa a ser un historial
  de compras. Cambia el producto, no solo el esquema.

No se da por hecha ninguna de las dos.

### D2. ¿Se puede volcar la base antes de migrar?

**Este es el riesgo real del bloque, y hay que resolverlo antes de migrar, no
después.**

ADR-005 retiró la exportación y el proyecto declara
`android:allowBackup="false"`: **no hay copia de seguridad de nada**. Hoy eso
es asumible porque el esquema está quieto. Una migración v3 → v4 que salga mal
sobre datos reales **no tiene vuelta atrás**, y los datos reales ya son meses
de bitácora, misiones y economía.

Conviene poder volcar la base a un fichero cifrado antes de tocar el esquema,
aunque no exista pantalla de restauración. **No es reabrir A6**: A6 era
exportación e importación con interfaz e historial. Esto sería un volcado
técnico, de un solo sentido, sin pantalla, ejecutado una vez antes de la
migración. Es la diferencia entre un error recuperable y perder meses.

Opciones: (a) volcado cifrado mínimo previo a la migración; (b) migrar sin
red, aceptando el riesgo por escrito; (c) posponer el bloque entero.

### D3. ¿Qué es exactamente «un personaje»?

El nombre está en plural desde `DECISIONES_PRE_A0.md`, pero el proyecto es de
un solo usuario. Hay que fijar si es:

- **una ficha única** que reúne lo ya existente (recomendado: coherente con
  local-first y de un solo usuario, y no necesita tabla nueva); o
- **varias fichas** entre las que se alterna, lo que sí implica tabla propia y
  obliga a decidir qué se reparte entre ellas: ¿el XP?, ¿los títulos?, ¿la
  bitácora? Esa pregunta arrastra a casi todo el esquema.

## Decisiones propuestas (sujetas a D1–D3)

Estas se proponen ya porque no dependen del sentido de D1, salvo donde se
indica.

1. **El bloque no empieza hasta que A11 y A8/G8 estén cerradas.** Regla ya
   vigente en `DECISIONES_PRE_A0.md`; se reafirma.
2. **Una sola migración v3 → v4**, no una por funcionalidad. Personajes,
   Tienda e Inventario entran en el mismo salto de esquema, con un único
   `drift_schema_v4.json` y pruebas `migrateAndValidate` de v1→v4, v2→v4 y
   v3→v4. Encadenar tres migraciones sobre datos sin copia multiplica el
   riesgo sin ganar nada.
3. **`xp_transactions` y el cálculo de nivel no se tocan** si D1 elige la
   salida 1. El contrato de ADR-003 queda intacto y Progreso no se revalida.
4. **Los enums nuevos se declaran como `TEXT` ASCII mayúscula con `CHECK`**,
   según ADR-001 §3. Nada de índices ordinales.
5. **Los importes de tienda se guardan como enteros**, con la misma disciplina
   que `amount_minor`: sin coma flotante, sin negativos, el sentido lo marca
   un campo de tipo.
6. **Idempotencia de compra.** Una compra es una operación con efectos en dos
   sitios (descuento e inventario) y debe ejecutarse en una única unidad de
   trabajo, con `operation_id UNIQUE`, igual que `transactions` y
   `goal_allocations`. Ya existe el precedente
   `drift_complete_mission_unit_of_work.dart`.
7. **Nueva área de navegación.** `AppArea` no tiene valor para este bloque.
   Se añade uno solo —no tres— y las tres pantallas cuelgan de él, para no
   inflar la barra lateral de un producto de un solo usuario.
8. **Sin borrado físico.** El inventario archiva lógicamente, como ya hacen
   Misiones y Bitácora. Un objeto consumido queda con su fecha, no desaparece.

## Riesgos y consecuencias

- **Irreversibilidad.** Sin D2 resuelta, la migración es la operación más
  peligrosa que ha hecho el proyecto. Es el único punto de este ADR que puede
  causar pérdida definitiva de datos del usuario.
- **Toolchain de snapshots.** ADR-001 §13 documenta que el ejecutable de
  `drift_dev 2.34.0` no compila junto a `drift 2.34.3`, y que v1 se exportó
  con un procedimiento controlado y temporal. **Generar `drift_schema_v4.json`
  volverá a chocar con eso**, y ADR-001 exige actualizar el toolchain mediante
  un ADR o repetir el procedimiento controlado validando ambos snapshots. No
  se edita el JSON a mano. Conviene comprobarlo antes de comprometer fechas.
- **Superficie de producto.** Tres pantallas nuevas sobre un sistema visual ya
  fijado (`ESTADO_VISUAL.md`). El coste de diseño no es despreciable y no está
  estimado aquí.
- **Coherencia del marco.** Si D1 elige dinero real, «Tienda» e «Inventario»
  dejan de ser mecánicas RPG y pasan a ser vistas de Economía. Merece un
  nombre distinto si se toma ese camino.

## Fuera de alcance, explícitamente

Loadouts, servidor, sincronización, multiusuario, tienda con contenido
descargable o cualquier elemento que requiera red. Descartados por decisión
del usuario el 7 de septiembre de 2026, no aplazados.

## Qué falta para que este ADR pase a «aceptado»

1. Respuesta del usuario a D1, D2 y D3.
2. Esquema concreto de las tablas nuevas, derivado de esas respuestas.
3. Comprobación del procedimiento de snapshot v4 contra la irregularidad de
   `drift_dev` documentada en ADR-001 §13.
4. Plan de migración con las tres rutas (v1→v4, v2→v4, v3→v4) y sus pruebas.
