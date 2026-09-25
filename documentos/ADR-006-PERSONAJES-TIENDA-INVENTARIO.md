# ADR-006 — Personaje, Contactos, Inventario y Tienda

- Estado: **propuesto — decisiones de producto resueltas el 24 de septiembre
  de 2026**. Falta el esquema concreto y la comprobación del snapshot v4 para
  pasar a «aceptado». **No autoriza código** hasta cerrar A8/G8
- Fecha: abierto el 13 de septiembre de 2026; reescrito el 24 de septiembre de
  2026 con las respuestas del usuario
- Alcance: ficha del usuario, contactos vinculados a misiones, inventario de
  pertenencias con equipado por zona del cuerpo, tienda con dinero real, y la
  migración de esquema v3 → v4 que implican
- Depende de: ADR-001 (persistencia), ADR-002 (acceso), ADR-003 (títulos,
  rachas y niveles), ADR-005 (retiro de A6)
- Precedencia: no altera ADR-001 a ADR-005; los amplía. Si algún punto entra
  en conflicto, prevalece el ADR anterior hasta que este se acepte

## Contexto

`DECISIONES_PRE_A0.md` dejó Personajes, Tienda e Inventario como post-MVP. El
7 de septiembre de 2026 el usuario acotó ese post-MVP a **esos tres y nada
más**: loadouts, servidor y sincronización quedan **descartados**, no
aplazados. El proyecto sigue siendo local-first, de un solo usuario y **sin
permiso `INTERNET`**.

El 24 de septiembre de 2026 el usuario fijó el diseño tomando como referencia
el menú de *Cyberpunk 2077* (pestañas Ciberware, Inventario, Mapa, Personaje y
Diario). La correspondencia acordada es:

| En el juego | En Bitácora | Base existente | Qué es nuevo |
|---|---|---|---|
| **Personaje**: hexágono de atributos con el nivel global al centro | **Mi ficha**: cada atributo es un área de vida (`life_areas`) con su nivel; el nivel global en el centro | XP y nivel por área en Progreso, `RpgLevel.fromTotalXp` | Nada en el esquema: presentación |
| **Diario**: fichas de personas (foto a la izquierda, biografía a la derecha) | **Contactos**: personas reales con nombre, descripción y foto | Ninguna | Tabla de contactos y vínculo con misiones |
| **Diario**: la miniatura del contacto bajo la descripción de la misión | Detalle de misión y «Mostrar más detalles»: miniaturas de sus contactos, que abren la ficha | Detalle de misión | Solo el vínculo |
| **Diario**: Tipo, Objetivo, Ubicación, Detalles | `mission_type`, `mission_objectives`, **ubicación**, `description` | Todo salvo la ubicación | Columna de ubicación en texto |
| **Inventario**: casillas por categoría con miniatura | **Inventario**: pertenencias por categoría, con foto | Ninguna | Tabla de objetos |
| **Ciberware**: silueta con zonas del cuerpo | **Equipado**: accesorios que el usuario lleva puestos, por zona | Ninguna | Zona opcional por objeto |
| `€$` en la cabecera | Dinero real de Economía | `transactions` | Tienda |
| **Mapa** | **Descartado** | — | — |

## Decisiones del usuario

### D1. La Tienda se paga con dinero real — RESUELTA

La Tienda registra compras reales. Cada compra es un gasto (`EXPENSE`) en
`transactions` **y** crea el objeto correspondiente en el inventario, en una
única unidad de trabajo.

Consecuencias:

- **`xp_transactions` y el cálculo de nivel no se tocan.** El hallazgo del
  borrador —que gastar XP de ese libro bajaría el nivel al comprar, porque
  `progress_dao.dart:173` suma el libro entero— deja de aplicar: aquí no se
  gasta XP. El contrato de ADR-003 queda intacto y Progreso no se revalida.
- «Tienda» deja de ser una mecánica de juego y es la puerta de entrada de
  compras al inventario. Su nombre en pantalla puede revisarse al diseñarla.

### D2. Copia de seguridad: se construye al final — RESUELTA, con riesgo aceptado

El usuario decidió que la falta de copia de seguridad **se cierra al final**,
después de Personaje, Contactos, Inventario y Tienda. Hasta entonces:

- **La migración v3 → v4 se ejecuta sin volcado previo.** El usuario acepta
  por escrito el riesgo: si la migración falla sobre datos reales, esos datos
  **no se pueden recuperar** (sin exportación por ADR-005, con
  `allowBackup="false"`, y con las claves en AndroidKeyStore).
- La copia **no reabre A6 tal como era**. Su alcance —volcado técnico o
  exportación completa con restauración— se decide cuando llegue su turno.
- Mitigación que sí se mantiene: las pruebas `migrateAndValidate` de v1→v4,
  v2→v4 y v3→v4 deben pasar antes de instalar la versión con v4 en el
  dispositivo principal, y la primera instalación con v4 se prueba antes en el
  flavor `dev`.

Esta decisión queda anotada en todos los documentos que mencionan A6.

### D3. Personaje es la ficha del usuario; las personas reales son Contactos — RESUELTA

El usuario planteó primero «personaje» como una persona real vinculada a
misiones. Al revisar el juego, separó dos cosas:

**Mi ficha** (pestaña Personaje, vista principal):

- Hexágono de atributos al estilo del juego. **Cada atributo es un área de
  vida** activa y visible, con su nivel; el nivel global en el centro.
- **Los atributos suben automáticamente con el XP** de las misiones de su
  área, como ya hace Progreso. No hay puntos que asignar a mano.
- Reúne también títulos, rachas, nombre y foto de perfil, que ya existen.
- Sin tabla nueva. Las áreas son configurables por el usuario, así que la
  disposición debe admitir un número variable de atributos, no cinco fijos.

**Contactos** (pestaña propia dentro de Personaje):

- Una persona real con **nombre, descripción y foto, todo opcional** al
  crearla, y editable, modificable y eliminable después.
- **Varias personas por misión** y varias misiones por persona (relación N:M).
- En el detalle de la misión y en «Mostrar más detalles» se ven las miniaturas
  de sus contactos; al tocar una se abre su ficha (foto y descripción, como
  las fichas del Diario del juego). La Bitácora refleja qué misión fue con
  quién.
- Eliminar un contacto no borra misiones: solo retira el vínculo. Como el
  resto del proyecto, se archiva lógicamente (ver decisión propuesta 8).

### D4. Inventario de pertenencias independientes, con Equipado — RESUELTA

- El inventario registra **las pertenencias del usuario**, compradas o no. Una
  compra en la Tienda crea un objeto; también se pueden añadir a mano cosas que
  ya se tenían o que fueron regaladas.
- Cada objeto tiene categoría y foto opcional, y se muestra en casillas por
  categoría, como el Inventario del juego.
- **Equipado**, inspirado en Ciberware: una silueta con zonas del cuerpo
  (cabeza, rostro, cuello, muñecas, manos…) donde se ven los accesorios que el
  usuario lleva puestos. Es **una zona opcional por objeto**, no conjuntos
  guardados: **no son loadouts**, que siguen descartados.

### D5. Mapa — DESCARTADO

Un mapa con calles exige descargar teselas de internet, y la aplicación no
tiene permiso `INTERNET` por diseño; el propio gate G8 falla si aparece. El
usuario lo descartó el 24 de septiembre de 2026. Lo que queda es un **campo
«Ubicación» de texto libre y opcional en la misión**, sin botón ni
integración con aplicaciones de mapas.

## Decisiones propuestas

1. **El bloque no empieza hasta que A8/G8 esté cerrada.** Regla ya vigente en
   `DECISIONES_PRE_A0.md`; se reafirma.
2. **Una sola migración v3 → v4**, no una por funcionalidad. Contactos,
   inventario, tienda y la columna de ubicación entran en el mismo salto, con
   un único `drift_schema_v4.json` y pruebas `migrateAndValidate` de v1→v4,
   v2→v4 y v3→v4.
3. **`xp_transactions` y el cálculo de nivel no se tocan** (consecuencia de
   D1 y D3).
4. **Los enums nuevos se declaran como `TEXT` ASCII mayúscula con `CHECK`**,
   según ADR-001 §3: categorías de objeto y zonas del cuerpo, si se fijan como
   lista cerrada.
5. **Los importes se guardan como enteros** en `amount_minor`, como en
   `transactions`. El precio de un objeto comprado es el de su transacción; no
   se duplica.
6. **Idempotencia de compra.** Gasto y objeto se crean en una única unidad de
   trabajo con `operation_id UNIQUE`, siguiendo el precedente
   `drift_complete_mission_unit_of_work.dart`.
7. **Una sola área de navegación nueva** (`AppArea`), Personaje, con Mi ficha
   y Contactos. Inventario, Equipado y Tienda se ubican al diseñar las
   pantallas, evitando inflar la barra lateral.
8. **Sin borrado físico.** Contactos y objetos se archivan lógicamente, como
   Misiones y Bitácora. Un objeto que se deja de tener queda con su fecha.
9. **Las fotos reutilizan el almacenamiento cifrado de las fotografías
   privadas** de Bitácora (`journal_attachments`: fichero cifrado,
   `cipher_sha256`, tipos MIME cerrados), con tablas de adjuntos propias o una
   generalizada. Se decide en el esquema.

## Riesgos y consecuencias

- **Irreversibilidad (aceptada en D2).** La migración v3 → v4 es la operación
  más peligrosa que ha hecho el proyecto y se hará sin copia. El incidente del
  24 de septiembre de 2026, en el que el gate G8 borró la instalación de la
  tablet, demuestra que la pérdida es real y total.
- **Toolchain de snapshots.** ADR-001 §13 documenta que el ejecutable de
  `drift_dev 2.34.0` no compila junto a `drift 2.34.3`, y que v1 se exportó
  con un procedimiento controlado y temporal. Generar `drift_schema_v4.json`
  volverá a chocar con eso. No se edita el JSON a mano. Comprobarlo antes de
  comprometer fechas.
- **Superficie de producto.** Cuatro vistas nuevas (Mi ficha, Contactos,
  Inventario/Equipado, Tienda) sobre un sistema visual ya fijado
  (`ESTADO_VISUAL.md`). La referencia de Cyberpunk encaja con Terminal V2,
  pero el coste de diseño no está estimado aquí.
- **Número variable de atributos.** El hexágono del juego tiene cinco
  atributos fijos; las áreas de vida son configurables. La disposición debe
  degradar bien con tres, cinco u ocho áreas.

## Fuera de alcance, explícitamente

Loadouts, servidor, sincronización, multiusuario, **mapa** y cualquier
elemento que requiera red. Descartados por decisión del usuario el 7 y el 24 de
septiembre de 2026, no aplazados.

## Qué falta para que este ADR pase a «aceptado»

1. Esquema concreto: contactos, vínculo misión–contacto, objetos, categorías,
   zonas del cuerpo, fotos y columna de ubicación. Pendiente de fijar si
   categorías y zonas son lista cerrada o configurables.
2. Comprobación del procedimiento de snapshot v4 contra la irregularidad de
   `drift_dev` documentada en ADR-001 §13.
3. Plan de migración con las tres rutas (v1→v4, v2→v4, v3→v4) y sus pruebas.
