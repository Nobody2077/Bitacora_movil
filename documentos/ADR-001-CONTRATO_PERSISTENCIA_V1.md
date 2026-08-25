# ADR-001 — Contrato de persistencia y cifrado v1

Fecha: 24 de agosto de 2026  
Estado: aceptado para A1  
Decide sobre: UML y Modelo de Datos v1.0, Arquitectura Técnica Flutter v1.0 y `DECISIONES_PRE_A0.md`

## Contexto

La auditoría previa al snapshot encontró contradicciones que no pueden resolverse de forma implícita dentro del código:

- UML, Arquitectura y Plan describen 17 tablas; la decisión posterior exige 19.
- Las dos tablas nuevas no tienen tipos, nulabilidad ni acciones de FK completos.
- `ADJUSTMENT` con `amount_minor > 0` no expresa si el saldo sube o baja.
- La arquitectura exige `operationId`, pero el UML no lo persiste.
- Varios enums están abiertos y la unidad de epoch no está fijada.
- SQLite no permite una acción FK “CASCADE solo si es borrador”.
- Los checks de origen contradicen algunas FK `ON DELETE SET NULL`.
- `flutter_secure_storage 11.0.0` requiere Android compileSdk 37, mientras el toolchain aprobado usa 36.
- `flutter_secure_storage 10.3.1` presenta un fallo reproducible de migración en instalación limpia con la política segura de no restablecer secretos automáticamente.

Congelar el snapshot antes de cerrar estos puntos obligaría a crear una migración artificial antes de distribuir la primera base.

## Decisiones

### 1. Esquema inicial

El schema v1 nace directamente con las 19 tablas enumeradas en `DECISIONES_PRE_A0.md`. No existe ni se simula una migración desde una versión de 17 tablas que nunca fue distribuida.

`PRAGMA user_version`, administrado por Drift, es la autoridad para migraciones. `schema_metadata['schema_version']` es un espejo para exportaciones y diagnósticos; nunca decide un upgrade.

### 2. Tiempo

Todos los instantes `*_at` se guardan como `INTEGER` de milisegundos Unix UTC. Las fechas civiles de recurrencia permanecen como `TEXT` `YYYY-MM-DD` y siempre llevan `timezone_id` IANA cuando requieren interpretación local.

Las consultas de período usan límites UTC semiabiertos `[startUtc, endUtc)`. No se usa `localtime` de SQLite para reglas del producto.

### 3. Enums persistidos

Los enums se guardan como `TEXT` ASCII mayúscula y se protegen con `CHECK`. No se usa el índice ordinal de un enum ni `textEnum()` sin conversor.

Valores cerrados adicionales:

- `mission_type`: `PRIMARY`, `SECONDARY`, `ERRAND`, `DAILY`, `RECURRING`, `EVENT`, `CHALLENGE`, `CUSTOM`.
- `difficulty`: `EASY`, `MEDIUM`, `HARD`.
- `mission_status`: `DRAFT`, `SCHEDULED`, `AVAILABLE`, `ACTIVE`, `PAUSED`, `RESCHEDULED`, `EXPIRED`, `ABANDONED`, `CANCELLED`, `PARTIAL`, `COMPLETED`.
- `mission_event_type`: `CREATED`, `UPDATED`, `AVAILABLE`, `STARTED`, `PAUSED`, `RESUMED`, `RESCHEDULED`, `EXPIRED`, `ABANDONED`, `CANCELLED`, `PARTIALLY_COMPLETED`, `COMPLETED`, `CORRECTED`, `ARCHIVED`.
- `mood`: `FOCUSED`, `NORMAL`, `TIRED`.
- `convenience_rating`: `TOTALLY_WORTH_IT`, `WORTH_IT_BUT_COSTLY`, `PARTIALLY_WORTH_IT`, `BARELY_WORTH_IT`, `WOULD_NOT_REPEAT`.

Agregar un valor futuro requiere incremento de schema y prueba de migración.

### 4. Ajustes económicos e idempotencia

`amount_minor` permanece positivo. `transaction_type` queda cerrado como:

- créditos: `INCOME`, `REFUND`, `ADJUSTMENT_CREDIT`;
- débitos: `EXPENSE`, `ADJUSTMENT_DEBIT`.

Se elimina el valor ambiguo `ADJUSTMENT`.

Se añaden:

- `transactions.operation_id TEXT NOT NULL UNIQUE`;
- `goal_allocations.operation_id TEXT NOT NULL UNIQUE`.

Las FK de movimientos, XP y asignaciones históricas usan `RESTRICT` o `SET NULL`; nunca `CASCADE`.

### 5. Objetivos de plantilla

`mission_template_objectives` queda definido como:

```text
id            TEXT PRIMARY KEY NOT NULL
template_id   TEXT NOT NULL REFERENCES mission_templates(id) ON DELETE CASCADE
description   TEXT NOT NULL CHECK length(trim(description)) BETWEEN 1 AND 240
position      INTEGER NOT NULL CHECK position >= 0
created_at    INTEGER NOT NULL
updated_at    INTEGER NOT NULL
row_version   INTEGER NOT NULL DEFAULT 1 CHECK row_version >= 1
UNIQUE(template_id, position)
```

La eliminación física de una plantilla solo se permite mientras sea un borrador sin historia; el caso de uso autoriza la operación y la FK elimina regla y objetivos.

### 6. Adjuntos de Bitácora

`journal_attachments` queda definido como:

```text
id                 TEXT PRIMARY KEY NOT NULL
journal_entry_id   TEXT NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE
kind               TEXT NOT NULL CHECK kind = 'PHOTO'
storage_name       TEXT NOT NULL UNIQUE
mime_type          TEXT NOT NULL CHECK mime_type IN ('image/jpeg','image/png','image/webp')
byte_length        INTEGER NOT NULL CHECK byte_length > 0
cipher_sha256      TEXT NOT NULL CHECK length(cipher_sha256) = 64
width_px           INTEGER NOT NULL CHECK width_px > 0
height_px          INTEGER NOT NULL CHECK height_px > 0
position           INTEGER NOT NULL CHECK position >= 0
created_at         INTEGER NOT NULL
archived_at        INTEGER NULL
UNIQUE(journal_entry_id, position)
```

Nonce y tag AES-GCM pertenecen al encabezado versionado del archivo cifrado, no a SQLite. El hash se expresa como 64 caracteres hexadecimales minúsculos. Las miniaturas son derivadas y no forman parte del esquema fuente.

### 7. Borrado de borradores

La frase “CASCADE solo si es borrador” no se traduce a una FK condicional. Para `mission_objectives` y `notification_schedules` se usa `ON DELETE RESTRICT`; el borrado autorizado de un borrador elimina hijos y padre explícitamente, en ese orden y dentro de una transacción.

`mission_template_objectives`, `recurrence_rules` y `journal_attachments` sí usan `CASCADE`, porque son componentes privados de su agregado y su raíz solo puede eliminarse físicamente como borrador.

### 8. Orígenes históricos

`origin_type` y `source_type` conservan la procedencia aunque una FK permitida pase a `NULL`. Por ello no existe un `CHECK` que exija permanentemente una FK no nula para `MISSION`, `TRANSACTION` o `JOURNAL`.

El DAO valida la referencia al insertar. El borrado posterior conserva el token histórico y pierde únicamente la navegación a la fuente.

### 9. Índices corregidos

Bitácora usa tres índices independientes:

- `idx_journal_time(occurred_at)`;
- `idx_journal_mission(mission_id)`;
- `idx_journal_transaction(transaction_id)`.

No se usa el índice compuesto `(mission_id, transaction_id)`, porque no optimiza una búsqueda aislada por `transaction_id`.

El nombre de área es único sin distinguir mayúsculas entre áreas activas. Solo puede existir un área predeterminada no archivada.

También se garantiza en SQLite que solo exista un `TIMER/WORK` abierto por misión mediante un índice único parcial. Los historiales continúan permitiendo cualquier cantidad de segmentos ya cerrados.

Un segundo índice único parcial impide dos registros vigentes (`ACTIVE` o `EARNED`, sin `deactivated_at`) para la misma definición de título.

### 9.1 Validaciones estructurales complementarias

- títulos de misión y Bitácora: entre 1 y 160 caracteres después de `trim`;
- fechas civiles: patrón `YYYY-MM-DD`, fecha SQLite válida y representación canónica;
- ventanas de misión: `available_from <= scheduled_at <= expires_at` para cada límite presente, y `available_from <= expires_at`;
- una reversión económica no puede anteceder al movimiento original;
- umbrales, rachas y recuperaciones no pueden ser negativos;
- la desactivación de un título no puede anteceder a su activación;
- colores persistidos usan exactamente `#RRGGBB`.

### 10. Settings iniciales

El singleton `app_settings` usa:

```text
id = 1
theme_key = terminal_reinforced
primary_color = #FF3B3B
large_text = false
reduce_motion = false
high_contrast = false
hide_amounts = false
mission_notifications = true
daily_summary = true
sound_enabled = true
auto_lock_minutes = 5
```

La preferencia de notificaciones no equivale a permiso Android concedido.

Las cinco áreas iniciales usan identificadores deterministas y no se duplican al reabrir:

| Orden | ID final | Nombre | `icon_key` | Color | Predeterminada |
| --- | --- | --- | --- | --- | --- |
| 0 | `00000000-0000-4000-8000-000000000001` | Estudios | `school` | `#38BDF8` | no |
| 1 | `00000000-0000-4000-8000-000000000002` | Salud | `favorite` | `#22C55E` | no |
| 2 | `00000000-0000-4000-8000-000000000003` | Proyectos | `code` | `#A855F7` | no |
| 3 | `00000000-0000-4000-8000-000000000004` | Hogar | `home` | `#F59E0B` | no |
| 4 | `00000000-0000-4000-8000-000000000005` | Personal | `person` | `#FF3B3B` | sí |

`schema_metadata` nace con `schema_version=1`, `seed_version=1` y `created_with=0.1.0+1`. El último valor conserva la versión que creó la base.

### 11. Clave de base de datos

No se usa `flutter_secure_storage` para la clave v1 por las incompatibilidades y el fallo de migración descritos en Contexto.

Se implementa un puente Kotlin mínimo sobre AndroidKeyStore:

1. genera una clave AES-256-GCM no exportable con alias versionado;
2. genera 32 bytes aleatorios para SQLite con `SecureRandom`;
3. envuelve esos bytes con la clave Keystore y guarda versión, IV y ciphertext autenticado en preferencias privadas;
4. nunca restablece, elimina ni reemplaza una clave al encontrar un error;
5. si existe una base y falta el material envuelto, falla cerrado;
6. verifica la escritura releyendo y descifrando antes de entregar la clave a Dart.

El puente no implementa PIN ni biometría; esas funciones permanecen en A2. `KeyGenParameterSpec` con AES-GCM requiere API 23; Flutter 3.41.5 fija un mínimo más estricto de API 24, que se conserva mediante `flutter.minSdkVersion`.

### 12. SQLite3MultipleCiphers

El build usa el hook `sqlite3: source: sqlite3mc`. Cada conexión ejecuta, antes de cualquier acceso al esquema:

```text
PRAGMA cipher = 'chacha20'
PRAGMA key = 'raw:<64 hex>'
PRAGMA memory_security = ON
SELECT * FROM sqlite_master
PRAGMA foreign_keys = ON
```

Se exige resultado válido de `PRAGMA cipher`. El pragma de clave por sí solo no prueba que la clave sea correcta; la lectura de `sqlite_master` es obligatoria. Esta forma exacta fue validada en Android 14/API 34 y en build release con SQLite3MultipleCiphers.

La clave, los pragmas con clave y el contenido de Keystore nunca se registran en logs.

`drift_flutter 0.3.1` conserva dependencias transitivas marcadas EOL (`sqlcipher_flutter_libs` y `sqlite3_flutter_libs`), pero en estas versiones son stubs sin binarios. No se declaran como dependencias directas; la biblioteca nativa efectiva proviene exclusivamente del hook `sqlite3mc`.

### 13. Snapshot y migraciones

G1 valida creación limpia, `foreign_key_check`, `integrity_check`, equivalencia con `drift_schema_v1.json` y reapertura idempotente. Las pruebas `migrateAndValidate` empiezan cuando exista v2; no se inventa una migración v0→v1.

Irregularidad de tooling: el ejecutable independiente de `drift_dev 2.34.0` no compila junto a `drift 2.34.3` por un cambio interno de la vista previa Drift 3; `drift_dev >=2.34.1+1` tampoco resuelve con el `meta` fijado por Flutter 3.41.5. Para exportar v1 se usó temporalmente `drift 2.34.0`, se generó el archivo oficial y se restauró inmediatamente `drift 2.34.3` y su lockfile, sin `dependency_overrides`. La prueba `schema_snapshot_v1_test.dart` compara después, sobre 2.34.3, las 19 tablas, los 21 índices y todo el SQL fijo del snapshot con el esquema realmente creado.

La generación ordinaria permanece en `dart run build_runner build`. Antes de crear v2 se deberá actualizar el toolchain mediante un ADR o repetir el procedimiento controlado y validar ambos snapshots; nunca se edita el JSON a mano.

### 14. Precedencia

Este ADR prevalece sobre cualquier definición anterior en conflicto. Todo punto no modificado conserva la precedencia definida en `DECISIONES_PRE_A0.md`.

## Consecuencias

- Se corrigen las contradicciones antes del primer archivo de usuario.
- Android 7.0/API 24 es la versión mínima efectiva del MVP por el toolchain Flutter fijado.
- La seguridad de la clave queda bajo código pequeño, auditable y probado por el proyecto.
- A2 deberá decidir por separado dónde persiste el verificador de PIN y cómo se recupera el acceso.
- Cambiar enums, cifrado o estructura después de G1 exige schema v2 y pruebas de migración.
