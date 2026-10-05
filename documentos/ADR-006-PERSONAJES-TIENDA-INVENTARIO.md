# ADR-006 — Menú Personaje: Ciberware, Inventario, Personaje, Diario y Creación

- Estado: **ACEPTADO el 1 de octubre de 2026** por el usuario («aprobado,
  empieza la fase 1»). Alcance de v4 congelado el mismo día. Autoriza el
  código de la fase 1.
- Fechas: abierto el 13 de septiembre de 2026; decisiones de producto el 24 de
  septiembre; reescrito el 1 de octubre de 2026 con lo decidido el 30 de
  septiembre; **ampliado el mismo 1 de octubre** con Proyectos, foto de
  misión y las respuestas a las cinco preguntas (D14–D16).
- **Congelado** significa: lo que necesite tablas y no esté aquí espera a una
  v5, idealmente cuando exista la copia de seguridad. Lo que no toque el
  esquema (colores, animaciones, sonidos, pantallas) puede entrar en cualquier
  fase.
- Referencia visual: maqueta descartable `Bitácora · Personaje` (artefacto
  privado del usuario, v4) y la silueta `escaner_corporal.svg` que hizo el
  usuario. La maqueta no es contrato: donde discrepe, prevalece este ADR.
- Depende de: ADR-001 (persistencia), ADR-002 (acceso), ADR-003 (títulos,
  rachas y niveles), ADR-005 (retiro de A6).
- Precedencia: no altera ADR-001 a ADR-005; los amplía. Si algún punto entra
  en conflicto, prevalece el ADR anterior hasta que este se acepte.

## Contexto

`DECISIONES_PRE_A0.md` dejó Personajes, Tienda e Inventario como post-MVP. El
7 de septiembre de 2026 el usuario acotó el post-MVP a esos tres; loadouts,
servidor y sincronización quedan **descartados**. El proyecto sigue siendo
local-first, de un solo usuario y **sin permiso `INTERNET`**.

La referencia es el menú de *Cyberpunk 2077*. El 30 de septiembre de 2026, con
una maqueta navegable delante, el usuario fijó la estructura definitiva. Este
ADR la traduce a reglas, tablas y una sola migración v3 → v4.

## Decisiones del usuario

### D1. La compra se paga con dinero real — RESUELTA (24 sep)

Cada compra es un gasto (`EXPENSE`) en `transactions` **y** crea el objeto en
el inventario, en una única unidad de trabajo. **No se gasta XP**:
`xp_transactions` y el cálculo de nivel de ADR-003 no se tocan.

### D2. Copia de seguridad al final — RESUELTA, con riesgo aceptado (24 sep)

La migración v3 → v4 se ejecuta **sin volcado previo**; el usuario acepta por
escrito que un fallo sobre datos reales no tiene recuperación. Mitigación
obligatoria: pruebas `migrate` de v1 → v4, v2 → v4 y v3 → v4 en verde, y la
primera instalación con v4 se prueba en el flavor `dev` antes de la tablet.

### D3. Personaje es el usuario; las personas reales son personajes del Diario — RESUELTA (24 y 30 sep)

- **PERSONAJE** (pestaña): hexágono de atributos. Cada atributo es un área de
  vida con su nivel; el nivel global en el núcleo. Suben solos con el XP; **no
  hay puntos que asignar ni árbol de ventajas**. El panel lateral reúne nivel,
  reputación, constancia (rachas, tiempo registrado) y títulos. Sin tabla
  nueva. La disposición admite de 3 a 8 áreas en círculo.
- **Personajes** (en DIARIO): personas reales con nombre, descripción y foto,
  **todo opcional**. Relación N:M con misiones y también con entradas del
  Diario. Eliminar = archivar; nunca borra misiones ni entradas.

### D4. Inventario de pertenencias, con zona del cuerpo — RESUELTA (24 y 30 sep)

Pertenencias reales, compradas o no. Categoría y zona son **listas fijas**
(respuesta del 30 sep). Una zona opcional por objeto; **no hay loadouts**.

### D5. Mapa — APLAZADO (antes «descartado»; cambiado el 30 sep)

La pestaña MAPA existe en el menú pero muestra «aplazado». Más adelante: mapa
de OpenStreetMap **sin conexión**, importado por el usuario como fichero desde
el PC (sin `INTERNET`), con estilo del juego, puntos de referencia y misiones
por lugar. Costes conocidos: 50–300 MB por ciudad, atribución ODbL obligatoria
y, si se quiere «¿dónde estoy?», permiso de ubicación. **Fuera de v4.** Lo que
entra ahora es el campo **ubicación** de texto libre en la misión.

### D6. Menú tipo juego — RESUELTA (30 sep)

- Una sola entrada nueva en la barra lateral: **Personaje**. Dentro, pestañas
  en la cabecera central, en este orden:
  **CIBERWARE · INVENTARIO · MAPA · PERSONAJE · DIARIO**. Abre en PERSONAJE.
- Cabecera del menú: NIVEL y REPUTACIÓN a la izquierda; saldo disponible en
  Bs y el botón **+ Compra** a la derecha.
- Pestaña activa en cian con subrayado; inactivas en rojo (paleta vigente).

### D7. Diario = la Bitácora renombrada — RESUELTA (30 sep)

Solo cambian **el nombre visible y el lugar**. Por dentro sigue siendo
`journal` (tablas, rutas, servicios). DIARIO tiene dos vistas: **Entradas** (la
cronología actual, con miniaturas de personajes) y **Personajes** (fichas y
«+ Crear personaje»). Durante una versión conviven DIARIO y la entrada
«Bitácora» de la barra lateral; se retira de la barra cuando el usuario
confirme en la tablet que DIARIO la sustituye.

### D8. Ciberware e Inventario: dos siluetas y dos barras — RESUELTA (30 sep)

- **CIBERWARE**: tecnología por zona. Silueta de escáner = `escaner_corporal.svg`
  del usuario (`viewBox 0 0 200 480`, anclajes verificados). Puntos por zona
  (cian si hay algo, punteado si no), líneas conectoras y línea de escaneo.
- **INVENTARIO**: ropa por zona, avatar en el centro y la sección
  *Relacionado* (Mochila, Creación, Lista de deseos).
- **Barras laterales, solo con icono**, en los extremos de la pantalla:
  - Izquierda, amarilla (persona en hexágono): **capacidad** = tecnología
    equipada frente a las zonas desbloqueadas por nivel. La sobrecarga
    **solo avisa** (naranja y rojo); nunca impide registrar lo que se lleva.
  - Derecha, cian (chaleco): **resiliencia** = ropa equipada.
  - Los valores se derivan de `inventory_items`; no se persisten.
- **Avatar**: primera versión con imagen fija del usuario y **las prendas como
  iconos en sus casillas**, no dibujadas sobre el cuerpo (menor coste,
  decidido el 30 sep). El usuario produce los SVG con Claude chat. Las capas
  teñidas por tipo y color quedan para después; la columna `color_hex` ya
  existe para no migrar otra vez.
- Movimiento reducido apaga escaneo, respiración y animación de barras.

### D9. Creación — RESUELTA (30 sep)

Dos modos:

1. **Fabricar recompensas.** Completar una misión **creada o completada desde
   que exista v4** otorga componentes según su dificultad: `EASY` → común,
   `MEDIUM` → poco común, `HARD` → raro. **Épico y legendario solo se obtienen
   convirtiendo 5 → 1** de la rareza inferior (en una sola dirección). Las
   recompensas reales («Tarde libre», «Comprar un juego») las define el
   usuario con un coste en componentes; las más caras piden rarezas más altas.
   Canjear crea un **vale por usar**; usarlo lo registra; abandonar un vale no
   usado devuelve el 50 % de su coste.
2. **Proyectos** (ampliado en D14): agrupan varios elementos reales para
   **armar** algo nuevo o para **reunir** un conjunto. Sustituye al «armar
   con piezas» del primer borrador.

Recortes explícitos: sin «mejorar» con bonus de atributo (rompería ADR-003),
sin desarmar objetos reales a cambio de componentes, sin consumibles en el
inventario. Los colores de rareza llevan siempre su nombre escrito.

### D10. Lista de deseos — RESUELTA (30 sep)

Deseos con prioridad, precio orientativo y foto. Sin internet la app no sabe si
un artículo está disponible en una tienda; lo que sí sabe es el dinero: avisa
**«ya puedes comprarlo»** cuando el saldo disponible (o la meta de ahorro
vinculada) alcanza el precio. Comprar un deseo usa la acción **+ Compra**.

### D11. Reputación configurable — RESUELTA (30 sep)

Mide **cumplir**, no hacer: misiones del área elegida en Ajustes (o de todas)
completadas **antes de su fecha límite**. Se deriva de `missions`; el área
elegida vive en las preferencias cifradas existentes (no en el esquema).

### D12. La compra es una acción, no una pestaña — RESUELTA (30 sep)

**+ Compra** junto al saldo: foto opcional, nombre, categoría, precio, zona
opcional. Al confirmar, el saldo de la cabecera baja cifra a cifra en naranja
y sale «− Bs X» flotando. Con movimiento reducido cambia sin animar; con
importes ocultos sigue enmascarado.

### D13. Barra lateral con ☰ y tema Vino — RESUELTA (30 sep)

- Botón ☰ en la cabecera: en tablet alterna expandida/oculta y se recuerda; en
  teléfono la barra flota encima y se cierra al tocar fuera o con «atrás».
- Tema **Vino** en Ajustes → Apariencia, además del Negro vigente. Alto
  contraste fuerza Negro; movimiento reducido quita las líneas de barrido. Se
  medirá el contraste del texto rojo sobre vino antes de aceptarlo. Ambas son
  preferencias, no esquema.

### D14. Proyectos: Armar y Reunir — RESUELTA (1 oct)

Un proyecto agrupa elementos. Dos tipos:

| Tipo | Para qué | Al completarse | Ejemplos |
|---|---|---|---|
| **Armar** | Construir algo nuevo con piezas | Crea un objeto nuevo (`origin = 'ASSEMBLED'`); las piezas propias quedan integradas en él. Se puede **desarmar**: vuelven al inventario y el objeto queda retirado, sin borrarse | Robot, PC, un cuadro |
| **Reunir** | Juntar un conjunto de cosas que siguen siendo independientes | Queda «completo»; no crea objeto | Setup gamer, kit de viaje |

Cada elemento tiene **dueño**:

1. **Mío**: se **selecciona** algo del inventario (lo tengo) o de la lista de
   deseos, o se **crea en ese momento** como deseo con su precio (me falta).
2. **De un personaje** del Diario («Chasis → Diego»).
3. **De otra persona** con solo un nombre de texto, sin crear personaje
   (alguien a quien quizá no se vuelva a ver).

Lo ajeno no cuenta para el progreso ni para el dinero.

- **Progreso** «4 de 6» = elementos propios en el inventario sobre elementos
  propios.
- **Dificultad económica** = suma del precio orientativo de los deseos que
  faltan, con color según el **saldo disponible** de Economía: **verde** si es
  ≤ 50 % del saldo, **amarillo** si es ≤ 100 %, **rojo** si lo supera, **gris**
  si ningún elemento que falta tiene precio. Es un **indicador aparte**: la
  dificultad de la misión (esfuerzo, XP y componentes) **no cambia**
  (decisión del usuario). Se calcula al vuelo; no se guarda.
- **Misión ↔ proyecto**: una misión puede tener un proyecto. Al completar la
  misión, la app pregunta «¿Marcar el proyecto como terminado?».
- **Un objeto** puede estar en varios proyectos de tipo Reunir; en uno de tipo
  Armar queda integrado y solo pertenece a ese.
- **Lista de deseos** muestra los deseos sueltos **y** los proyectos con lo
  que les falta («Setup gamer · 4 de 6 · falta Bs 770»).
- **+ Compra** sobre un deseo de un proyecto lo pasa al inventario; el
  progreso sube solo.
- **Recompensas** de Creación pueden apuntar a **un deseo o a un proyecto**:
  al usar el vale se abre + Compra con lo que falta.
- **Diario**: terminar o armar un proyecto y usar un vale crean una entrada
  de origen `SYSTEM`.

### D15. Foto de la misión y tarjeta con personajes — RESUELTA (1 oct)

- **Foto opcional propia** en la misión (por ejemplo, la referencia del
  cuadro que se quiere pintar), cifrada como las demás.
- La **tarjeta de la misión** en Misiones muestra esa foto o, si no hay, la
  del objeto que se arma o del primer elemento del proyecto, y debajo las
  miniaturas de sus personajes.
- Al **crear la misión** se eligen sus personajes (relación N:M de D3).

### D16. Respuestas a las cinco preguntas — RESUELTAS (1 oct)

1. **Misiones sin dificultad** dan **1 componente común**, como las fáciles.
2. **Una foto opcional** por personaje, por objeto y por misión.
3. **Categorías y zonas** quedan como están; el usuario acepta que cambiarlas
   después exige otra migración.
4. **`flutter_svg` y una biblioteca de iconos MIT**: aprobadas, **siempre que
   sean seguras**. Antes de añadir cada una se comprueban editor verificado,
   licencia, que no añadan permisos al manifiesto fusionado y que la APK siga
   sin `INTERNET` (el gate ya lo exige).
5. **Usar un vale crea entrada en el Diario.**

### D17. Fuera Ciberware, Inventario y Creación; la Tienda es la lista de deseos — RESUELTA (4 oct)

Al ir a empezar la fase 2, el usuario decidió que Ciberware e Inventario no se
veían bien y serían solo visuales, y que la tienda de recompensas tampoco la
usaría. **Sustituye a D4, D8, D9 (recompensas y vales), D12 y a los puntos 1, 4
y 5 de D16** en lo que se contradigan.

- **Fuera:** las pestañas CIBERWARE e INVENTARIO, siluetas, avatar, barras de
  capacidad y resiliencia, equipar por zona, mochila, fotos de objetos,
  `flutter_svg`, la biblioteca de iconos externa, componentes, conversión,
  recompensas y vales. Sus tablas y columnas (`body_zone`, `is_equipped`,
  `item_photos`, `craft_*`, `reward_*`) **se quedan sin usar**: borrarlas
  exigiría otra migración y no molestan.
- **TIENDA = lista de deseos.** Ocupa en el menú Personaje el sitio de las dos
  pestañas retiradas. Cada deseo es una fila de `inventory_items` con
  `status = 'WISHED'`: nombre, información (texto en `description`, **sin
  imagen**), prioridad, precio orientativo y meta de ahorro opcional.
- **Clasificación doble (respuesta 1a):** el **área de vida** (Estudios, Salud,
  Proyectos, Hogar, Personal… las de `life_areas`) dice *para qué*; la
  categoría de objeto existente dice *qué es* y da el icono. Los iconos salen
  de los **Material Icons que ya trae Flutter**: no se añade dependencia.
- **Color según el saldo disponible (respuesta 2a):** verde si el saldo
  disponible alcanza el precio, ámbar si falta poco, rojo si falta mucho. El
  umbral es una constante de código que fija la mini-spec. **Siempre con
  texto** («Te alcanza», «Faltan Bs 120»).
- **«Ya puedes comprarlo» (respuesta 3a y 3c):** aviso dentro de la app cuando
  un movimiento hace que un deseo pase a estar al alcance, y una línea en el
  resumen diario existente («N deseos a tu alcance»), que respeta «mostrar
  detalles». Sin notificación propia nueva.
- **Comprar un deseo (respuesta 4a):** un solo paso que registra el `EXPENSE`
  en `transactions` y pasa el deseo a `OWNED` con `origin = 'PURCHASE'` y su
  `purchase_transaction_id`, todo o nada, idempotente (D1 sigue en pie: no se
  gasta XP). Queda una lista de **Comprados**.
- **Migración v5, solo aditiva:** `area_id` opcional en `inventory_items`
  (FK a `life_areas`, `ON DELETE SET NULL`). Como v4, **sin copia de
  seguridad**, con el riesgo aceptado por el usuario el 4 de octubre al elegir
  la respuesta 1a, y con sus pruebas de migración y el ensayo `dev` en la
  tablet antes de tocar la prod.

### D18. Fuera MAPA; «Bitácora» deja la barra lateral; Diario al estilo del juego — RESUELTA (5 oct)

Decisiones del usuario del 5 de octubre de 2026, con la maqueta privada
«Diario de Bitácora» delante. **Sustituye a D5** (mapa aplazado) y completa
D7.

- **MAPA, descartado.** Requiere demasiado trabajo para lo que aporta. Sale
  del menú Personaje, que queda en **TIENDA · PERSONAJE · DIARIO**.
- **«Bitácora» sale de la barra lateral**: DIARIO la sustituye. Por dentro
  sigue siendo `journal` (tablas, rutas, servicios, buscar, archivo y cierre
  del día); volver a la Bitácora es volver a Personaje → DIARIO. En teléfono,
  su botón de la barra inferior pasa a ser «Personaje».
- **Diario como en el juego** (paso siguiente): dos columnas en tablet, lista
  continua por fechas con filtros por origen (misiones, libres, movimientos)
  y la entrada abierta al lado con título rojo, ◆ objetivos de su misión,
  texto, ánimo, fotos y personajes. Los personajes siguen el mismo patrón.
  En teléfono, lista y entrada a pantalla completa.

## Esquema v4

Una sola migración, con todo lo anterior (decisión propuesta 2 de la versión
previa, se mantiene). **Catorce tablas nuevas y dos columnas.** Convenciones de
ADR-001: ids `TEXT`, instantes en milisegundos UTC, enums `TEXT` ASCII
mayúscula con `CHECK`, importes enteros en `*_minor`, sin borrado físico
(`archived_at`), `operation_id UNIQUE` para idempotencia.

### Columnas nuevas

```sql
ALTER TABLE missions ADD COLUMN location TEXT
  CHECK (location IS NULL OR length(trim(location)) BETWEEN 1 AND 120);
ALTER TABLE mission_templates ADD COLUMN location TEXT
  CHECK (location IS NULL OR length(trim(location)) BETWEEN 1 AND 120);
```

La plantilla copia su ubicación a cada misión que genera.

### Personajes

```sql
CREATE TABLE contacts (
  id TEXT NOT NULL PRIMARY KEY,
  display_name TEXT CHECK (
    display_name IS NULL OR length(trim(display_name)) BETWEEN 1 AND 80
  ),
  role TEXT CHECK (role IS NULL OR length(trim(role)) BETWEEN 1 AND 80),
  description TEXT CHECK (description IS NULL OR length(description) <= 4000),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  archived_at INTEGER,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK (row_version >= 1)
);

CREATE TABLE mission_contacts (
  mission_id TEXT NOT NULL REFERENCES missions(id) ON DELETE CASCADE,
  contact_id TEXT NOT NULL REFERENCES contacts(id) ON DELETE RESTRICT,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (mission_id, contact_id)
);
CREATE INDEX idx_mission_contacts_contact ON mission_contacts(contact_id);

CREATE TABLE journal_entry_contacts (
  journal_entry_id TEXT NOT NULL
    REFERENCES journal_entries(id) ON DELETE CASCADE,
  contact_id TEXT NOT NULL REFERENCES contacts(id) ON DELETE RESTRICT,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (journal_entry_id, contact_id)
);
CREATE INDEX idx_journal_contacts_contact ON journal_entry_contacts(contact_id);
```

- `role` es el subtítulo de la ficha («Docente · Cálculo II»).
- Una entrada del Diario muestra sus personajes propios **más** los de su
  misión vinculada (unión en la consulta, sin duplicar filas).
- `CASCADE` solo borra el vínculo; las misiones y entradas nunca se borran
  físicamente (ADR-001), así que en la práctica no se dispara.

### Inventario y lista de deseos

Una sola tabla: un deseo es un objeto con `status = 'WISHED'`. Así comprar un
deseo, o una pieza que falta en un proyecto, es cambiar su estado y no copiar
filas.

```sql
CREATE TABLE inventory_items (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 120),
  description TEXT CHECK (description IS NULL OR length(description) <= 4000),
  category TEXT NOT NULL CHECK (category IN (
    'TECHNOLOGY', 'CLOTHING', 'ACCESSORY', 'BOOK', 'PART', 'HOME', 'OTHER'
  )),
  icon_key TEXT NOT NULL CHECK (length(icon_key) BETWEEN 1 AND 64),
  color_hex TEXT CHECK (
    color_hex IS NULL OR color_hex GLOB
    '#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'
  ),
  status TEXT NOT NULL CHECK (status IN (
    'WISHED', 'OWNED', 'INTEGRATED', 'RETIRED'
  )),
  origin TEXT CHECK (origin IS NULL OR origin IN (
    'PURCHASE', 'GIFT', 'PREEXISTING', 'ASSEMBLED'
  )),
  body_zone TEXT CHECK (body_zone IS NULL OR body_zone IN (
    'HEAD', 'EYES', 'EARS', 'TORSO', 'LEGS', 'FEET',
    'WRIST', 'HANDS', 'BACK', 'DEVICE'
  )),
  is_equipped INTEGER NOT NULL DEFAULT 0 CHECK (is_equipped IN (0, 1)),
  purchase_transaction_id TEXT UNIQUE
    REFERENCES transactions(id) ON DELETE RESTRICT,
  parent_item_id TEXT REFERENCES inventory_items(id) ON DELETE RESTRICT,
  wish_priority TEXT CHECK (wish_priority IS NULL OR wish_priority IN (
    'LOW', 'MEDIUM', 'HIGH'
  )),
  wish_price_minor INTEGER CHECK (
    wish_price_minor IS NULL OR wish_price_minor > 0
  ),
  wish_goal_id TEXT REFERENCES savings_goals(id) ON DELETE SET NULL,
  acquired_at INTEGER,
  retired_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  archived_at INTEGER,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK (row_version >= 1),
  CHECK ((status = 'WISHED') = (wish_priority IS NOT NULL)),
  CHECK (status <> 'WISHED' OR (origin IS NULL AND acquired_at IS NULL)),
  CHECK (status = 'WISHED' OR (origin IS NOT NULL AND acquired_at IS NOT NULL)),
  CHECK (is_equipped = 0 OR (status = 'OWNED' AND body_zone IS NOT NULL)),
  CHECK ((status = 'INTEGRATED') = (parent_item_id IS NOT NULL)),
  CHECK ((status = 'RETIRED') = (retired_at IS NOT NULL)),
  CHECK (purchase_transaction_id IS NULL OR origin = 'PURCHASE'),
  CHECK (parent_item_id IS NULL OR parent_item_id <> id)
);
CREATE INDEX idx_items_status_category ON inventory_items(status, category);
CREATE INDEX idx_items_equipped_zone
  ON inventory_items(body_zone) WHERE is_equipped = 1;
CREATE INDEX idx_items_parent ON inventory_items(parent_item_id);
```

- **Zonas** (lista fija). CIBERWARE muestra `EYES`, `EARS`, `DEVICE`,
  `WRIST`, `HANDS`, `BACK`; INVENTARIO muestra `HEAD`, `TORSO`, `LEGS`,
  `FEET`. Cuántas casillas tiene cada zona y cuáles se desbloquean por nivel
  son **constantes de código**, igual que los anclajes sobre el SVG. Un límite
  superado solo avisa, por eso no está en el esquema.
- **Iconos**: `icon_key` apunta a una biblioteca fija empaquetada en la app;
  la validación de que la clave existe es de la aplicación.
- **Precio**: el de un objeto comprado es el de su transacción (no se duplica).
  `wish_price_minor` es solo el precio orientativo de un deseo.
- **«Ya puedes comprarlo»**: se calcula al vuelo contra el saldo disponible o
  contra `savings_goals` (meta vinculada); no hay columna de estado de aviso.

### Fotos cifradas

Mismo patrón que `journal_attachments` (fichero cifrado, `cipher_sha256`,
MIME cerrado). Una foto vigente por personaje, por objeto y por misión (D15,
D16).

```sql
CREATE TABLE contact_photos (
  id TEXT NOT NULL PRIMARY KEY,
  contact_id TEXT NOT NULL REFERENCES contacts(id) ON DELETE RESTRICT,
  storage_name TEXT NOT NULL UNIQUE,
  mime_type TEXT NOT NULL CHECK (mime_type IN (
    'image/jpeg', 'image/png', 'image/webp'
  )),
  byte_length INTEGER NOT NULL CHECK (byte_length > 0),
  cipher_sha256 TEXT NOT NULL CHECK (
    length(cipher_sha256) = 64 AND cipher_sha256 NOT GLOB '*[^0-9a-f]*'
  ),
  width_px INTEGER NOT NULL CHECK (width_px > 0),
  height_px INTEGER NOT NULL CHECK (height_px > 0),
  created_at INTEGER NOT NULL,
  archived_at INTEGER
);
CREATE UNIQUE INDEX uq_contact_photo_current
  ON contact_photos(contact_id) WHERE archived_at IS NULL;

-- item_photos: idéntica, con item_id REFERENCES inventory_items(id)
-- ON DELETE RESTRICT y uq_item_photo_current sobre (item_id).
-- mission_photos: idéntica, con mission_id REFERENCES missions(id)
-- ON DELETE RESTRICT y uq_mission_photo_current sobre (mission_id).
```

### Creación

```sql
CREATE TABLE craft_operations (
  id TEXT NOT NULL PRIMARY KEY,
  operation_id TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL CHECK (kind IN (
    'MISSION_GRANT', 'CONVERT', 'REDEEM', 'ABANDON_REFUND',
    'ASSEMBLE', 'DISASSEMBLE', 'PROJECT_COMPLETE'
  )),
  mission_id TEXT REFERENCES missions(id) ON DELETE RESTRICT,
  occurred_at INTEGER NOT NULL,
  CHECK ((kind = 'MISSION_GRANT') = (mission_id IS NOT NULL))
);
CREATE UNIQUE INDEX uq_craft_mission_grant
  ON craft_operations(mission_id) WHERE kind = 'MISSION_GRANT';

CREATE TABLE craft_component_ledger (
  id TEXT NOT NULL PRIMARY KEY,
  craft_operation_id TEXT NOT NULL
    REFERENCES craft_operations(id) ON DELETE RESTRICT,
  rarity TEXT NOT NULL CHECK (rarity IN (
    'COMMON', 'UNCOMMON', 'RARE', 'EPIC', 'LEGENDARY'
  )),
  amount INTEGER NOT NULL CHECK (amount <> 0),
  UNIQUE (craft_operation_id, rarity)
);
CREATE INDEX idx_craft_ledger_rarity ON craft_component_ledger(rarity);

CREATE TABLE reward_specs (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 120),
  description TEXT CHECK (description IS NULL OR length(description) <= 2000),
  icon_key TEXT NOT NULL CHECK (length(icon_key) BETWEEN 1 AND 64),
  is_repeatable INTEGER NOT NULL DEFAULT 1 CHECK (is_repeatable IN (0, 1)),
  unlock_level INTEGER CHECK (unlock_level IS NULL OR unlock_level >= 1),
  target_item_id TEXT REFERENCES inventory_items(id) ON DELETE SET NULL,
  target_project_id TEXT REFERENCES projects(id) ON DELETE SET NULL,
  created_at INTEGER NOT NULL,
  archived_at INTEGER,
  CHECK (target_item_id IS NULL OR target_project_id IS NULL)
);

CREATE TABLE reward_spec_costs (
  reward_spec_id TEXT NOT NULL
    REFERENCES reward_specs(id) ON DELETE CASCADE,
  rarity TEXT NOT NULL CHECK (rarity IN (
    'COMMON', 'UNCOMMON', 'RARE', 'EPIC', 'LEGENDARY'
  )),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (reward_spec_id, rarity)
);

CREATE TABLE reward_vouchers (
  id TEXT NOT NULL PRIMARY KEY,
  reward_spec_id TEXT NOT NULL
    REFERENCES reward_specs(id) ON DELETE RESTRICT,
  redeem_operation_id TEXT NOT NULL UNIQUE
    REFERENCES craft_operations(id) ON DELETE RESTRICT,
  refund_operation_id TEXT UNIQUE
    REFERENCES craft_operations(id) ON DELETE RESTRICT,
  status TEXT NOT NULL CHECK (status IN ('AVAILABLE', 'USED', 'ABANDONED')),
  journal_entry_id TEXT REFERENCES journal_entries(id) ON DELETE SET NULL,
  redeemed_at INTEGER NOT NULL,
  used_at INTEGER,
  abandoned_at INTEGER,
  CHECK ((status = 'USED') = (used_at IS NOT NULL)),
  CHECK ((status = 'ABANDONED') = (abandoned_at IS NOT NULL)),
  CHECK ((status = 'ABANDONED') = (refund_operation_id IS NOT NULL))
);
CREATE INDEX idx_vouchers_status ON reward_vouchers(status, redeemed_at);

CREATE TABLE projects (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 120),
  description TEXT CHECK (description IS NULL OR length(description) <= 4000),
  icon_key TEXT NOT NULL CHECK (length(icon_key) BETWEEN 1 AND 64),
  kind TEXT NOT NULL CHECK (kind IN ('ASSEMBLY', 'COLLECTION')),
  status TEXT NOT NULL CHECK (status IN (
    'PLANNING', 'COMPLETED', 'ASSEMBLED', 'DISASSEMBLED'
  )),
  mission_id TEXT UNIQUE REFERENCES missions(id) ON DELETE SET NULL,
  result_item_id TEXT UNIQUE REFERENCES inventory_items(id) ON DELETE RESTRICT,
  completed_at INTEGER,
  disassembled_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  archived_at INTEGER,
  row_version INTEGER NOT NULL DEFAULT 1 CHECK (row_version >= 1),
  CHECK (kind = 'ASSEMBLY' OR status IN ('PLANNING', 'COMPLETED')),
  CHECK (kind = 'COLLECTION' OR status <> 'COMPLETED'),
  CHECK (kind = 'ASSEMBLY' OR result_item_id IS NULL),
  CHECK ((status = 'PLANNING') = (completed_at IS NULL)),
  CHECK ((status IN ('ASSEMBLED', 'DISASSEMBLED')) = (result_item_id IS NOT NULL)),
  CHECK ((status = 'DISASSEMBLED') = (disassembled_at IS NOT NULL))
);

CREATE TABLE project_items (
  id TEXT NOT NULL PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  owner_type TEXT NOT NULL CHECK (owner_type IN ('SELF', 'CONTACT', 'OTHER')),
  item_id TEXT REFERENCES inventory_items(id) ON DELETE RESTRICT,
  contact_id TEXT REFERENCES contacts(id) ON DELETE RESTRICT,
  owner_name TEXT CHECK (
    owner_name IS NULL OR length(trim(owner_name)) BETWEEN 1 AND 80
  ),
  label TEXT CHECK (label IS NULL OR length(trim(label)) BETWEEN 1 AND 120),
  position INTEGER NOT NULL CHECK (position >= 0),
  created_at INTEGER NOT NULL,
  CHECK ((owner_type = 'SELF') = (item_id IS NOT NULL)),
  CHECK ((owner_type = 'CONTACT') = (contact_id IS NOT NULL)),
  CHECK ((owner_type = 'OTHER') = (owner_name IS NOT NULL)),
  CHECK (owner_type = 'SELF' OR label IS NOT NULL),
  UNIQUE (project_id, position)
);
CREATE INDEX idx_project_items_item ON project_items(item_id);
CREATE INDEX idx_project_items_contact ON project_items(contact_id);

```

Reglas que el esquema no puede expresar y viven en unidades de trabajo
transaccionales (precedente: `drift_complete_mission_unit_of_work.dart`):

- **Saldo de componentes** = `SUM(amount)` por rareza. Ningún canje ni
  conversión puede dejarlo negativo; se comprueba dentro de la misma
  transacción que escribe el libro.
- **Completar misión** añade la fila `MISSION_GRANT` en la misma transacción
  que el XP. Una sola por misión (`uq_craft_mission_grant`). Solo para misiones
  completadas después de la migración: **no hay relleno retroactivo**.
- **Convertir**: una operación con dos filas (−5 de una rareza, +1 de la
  siguiente).
- **Canjear**: operación `REDEEM` con filas negativas por cada coste y un vale
  `AVAILABLE`. **Abandonar** un vale: operación `ABANDON_REFUND` con el 50 %
  de cada coste, redondeado hacia abajo, y el vale pasa a `ABANDONED`.
- **Usar un vale** crea una entrada del Diario de origen `SYSTEM` («Usaste:
  Tarde libre») y la enlaza en `journal_entry_id`.
- **Elemento de proyecto que me falta**: crear un elemento propio que aún no
  existe crea a la vez el deseo (`WISHED`, con precio orientativo y prioridad
  `MEDIUM` por defecto) y el `project_items` que lo apunta, en una
  transacción.
- **Armar** (`ASSEMBLY`): exige que todo elemento `SELF` esté `OWNED` y que
  ninguno esté ya integrado en otro proyecto; crea el objeto resultado
  (`origin = 'ASSEMBLED'`), marca las piezas `INTEGRATED` con
  `parent_item_id` y el proyecto `ASSEMBLED`. **Desarmar**: piezas de vuelta a
  `OWNED`, resultado a `RETIRED`, proyecto `DISASSEMBLED`.
- **Completar** (`COLLECTION`): exige que todo elemento `SELF` esté `OWNED`;
  el proyecto pasa a `COMPLETED` y los objetos no cambian (pueden estar en
  otros proyectos de tipo Reunir).
- Armar, desarmar y completar registran una operación en `craft_operations`
  (`ASSEMBLE`, `DISASSEMBLE`, `PROJECT_COMPLETE`) para la idempotencia, sin
  filas de libro, y una entrada del Diario de origen `SYSTEM`.
- **Completar la misión** de un proyecto no lo completa sola: la interfaz lo
  propone y el usuario confirma (D14).
- **Compra** (D1/D12): `transactions` (`EXPENSE`) + `inventory_items`
  (`OWNED`, `origin = 'PURCHASE'`, `purchase_transaction_id`) en una
  transacción con el `operation_id` del gasto. Comprar un deseo actualiza esa
  misma fila de `WISHED` a `OWNED`.

## Migración

`schemaVersion` pasa a **4**. `onUpgrade` conserva los pasos actuales y añade
uno nuevo, de modo que v1, v2 y v3 llegan a v4 por el mismo camino:

```dart
if (from < 1 || to != 4 || from >= to) throw UnsupportedError(...);
if (from == 1) { /* journal_entries.mood_detail (v2) */ }
if (from <= 2) { /* mission_templates.availability_mode (v3) */ }
if (from <= 3) {
  await migrator.addColumn(missions, missions.location);
  await migrator.addColumn(missionTemplates, missionTemplates.location);
  // createTable + createIndex de las 14 tablas nuevas, en orden de FK:
  // contacts, contact_photos, mission_contacts, journal_entry_contacts,
  // mission_photos, inventory_items, item_photos, projects, project_items,
  // craft_operations, craft_component_ledger,
  // reward_specs, reward_spec_costs, reward_vouchers.
}
```

Solo añade: ninguna tabla existente se reescribe, ningún dato se transforma.
Es la migración de menor riesgo posible para su tamaño. `beforeOpen` sigue
ejecutando `foreign_key_check` e `integrity_check`.

### Snapshot `drift_schema_v4.json` — comprobado el 1 de octubre de 2026

- `dart run drift_dev schema dump` **sigue fallando** con `drift 2.34.3` y
  `drift_dev 2.34.0` (`allSchemaEntities` no existe en la vista previa de
  Drift 3), igual que en ADR-001 §13.
- **Subir de versión no es posible hoy**: `drift_dev >= 2.34.6` exige
  `analyzer >= 13`, que necesita `meta ^1.18`, y Flutter 3.41.5 fija
  `meta 1.17.0`. Comprobado con `flutter pub add --dry-run`.
- Por tanto se repite el **procedimiento controlado** usado para v1–v3: fijar
  temporalmente `drift 2.34.0`, generar `drift_schema_v4.json`, restaurar
  `drift 2.34.3` y su lockfile en el mismo paso, sin `dependency_overrides`.
  **Nunca se edita el JSON a mano.** `a8_preflight.ps1` ya exige que exista el
  snapshot de la versión declarada.

### Pruebas obligatorias antes de instalar v4 en la tablet

1. `schema_migration_v3_to_v4_test.dart`: base v3 cruda con misiones,
   plantillas, movimientos, entradas y fotos → abre con `AppDatabase` v4;
   comprueba `user_version = 4`, las 14 tablas, las dos columnas en `NULL`,
   que **todas las filas previas siguen idénticas** y `foreign_key_check` /
   `integrity_check` limpios.
2. Lo mismo desde v1 y desde v2 (ampliando las pruebas existentes).
3. Prueba de snapshot v4: tablas, índices y SQL del snapshot frente al esquema
   creado.
4. Restricciones: un caso que falla por cada `CHECK` nuevo y por cada índice
   único.
5. Unidades de trabajo: compra, conversión, canje, abandono, elemento que
   falta, armar, desarmar, completar un proyecto y la concesión al completar
   misión, incluida su idempotencia.
6. Instalación en `dev` sobre una copia con datos antes de la tablet (D2).

## Dependencias nuevas

- **`flutter_svg`**: para la silueta del usuario. Es la opción estándar,
  funciona sin red y no pide permisos. Alternativa descartada: pasar el SVG a
  `CustomPainter` a mano.
- **Biblioteca de iconos** con licencia libre, empaquetada (Tabler o Phosphor,
  ambas MIT). Se elige una al empezar la fase 2.

Ninguna añade permisos ni red; el gate seguirá exigiendo que no aparezca
`INTERNET`.

## Fases de construcción

La migración entra entera en la fase 1, aunque cada pantalla llegue después.

1. **Esquema v4 + Personaje + Diario con personajes**: la migración y sus
   pruebas, el menú con sus cinco pestañas (MAPA en «aplazado»), el hexágono,
   personajes con foto y vínculos con misiones y entradas, ubicación y foto
   en misiones, tarjeta de misión con foto y personajes.
2. **Tienda (lista de deseos)**, rehecha el 4 de octubre por D17: migración
   v5 (`area_id`), deseos con área, tipo, prioridad y precio, color según el
   saldo, aviso «ya puedes comprarlo» en la app y en el resumen diario,
   comprar un deseo (gasto + comprado) y lista de Comprados. Se retiran las
   pestañas CIBERWARE e INVENTARIO.
3. **Proyectos y Reputación**: proyectos Armar y Reunir con dueños de cada
   elemento, progreso y dificultad económica, vínculo con la misión. Se
   revisan con el usuario antes de empezar, como la fase 2.
4. ~~**Creación**~~: **retirada por D17** (4 de octubre).
5. Después del bloque: ☰ y tema Vino pueden ir en cualquier fase porque no
   tocan el esquema. **Copia de seguridad** sigue siendo el último bloque
   (D2).

Cada fase termina con su APK, instalación encima en la tablet y aprobación del
usuario, como hasta ahora.

## Riesgos

- **Migración sin copia (aceptado, D2).** Mitigado por ser solo aditiva y por
  las pruebas desde las tres versiones anteriores.
- **Toolchain de snapshots.** Procedimiento manual repetido por cuarta vez;
  el día que Flutter libere `meta ^1.18` conviene subir `drift`/`drift_dev` y
  retirar la irregularidad con su propio ADR.
- **Tamaño del bloque.** Catorce tablas y cuatro fases. Las fases son
  independientes en interfaz, así que se pueden aprobar una a una.
- **Completar misión es lo más validado de la app.** La concesión de
  componentes se añade dentro de la misma unidad de trabajo, con pruebas
  propias, sin cambiar el cálculo de XP.

## Fuera de alcance, explícitamente

Loadouts, servidor, sincronización, multiusuario, consumibles, bonus de
atributo por objetos, «mejorar» con tiers y cualquier elemento que requiera
red. El mapa queda **aplazado** (D5), no dentro de v4.

## Aceptación

Aceptado el 1 de octubre de 2026. La fase 1 empieza por la migración y sus
pruebas, antes que cualquier pantalla.
