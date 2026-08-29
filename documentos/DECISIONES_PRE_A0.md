# Bitácora RPG Personal — decisiones vinculantes de construcción

Versión: 1.5
Fecha: 28 de agosto de 2026
Estado: vigente; A0–A5 y A7 completadas, A6 retirada y A8 en progreso

## 1. Propósito y precedencia

Este archivo cierra las decisiones que estaban abiertas entre la especificación, el UML, el sistema de diseño, el mapa de navegación, la arquitectura técnica y el plan. Si alguno de esos documentos contradice una decisión de este archivo, prevalece este archivo hasta que exista un ADR posterior explícito.

Precedencia por materia:

1. Este archivo y ADR posteriores. Para persistencia v1 prevalece `ADR-001-CONTRATO_PERSISTENCIA_V1.md`; para acceso y privacidad v1 prevalece `ADR-002-CONTRATO_ACCESO_PRIVACIDAD_V1.md`.
2. Mapa de Navegación Definitivo v1.0 para rutas, retorno y adaptación.
3. UML y Modelo de Datos v1.0 para entidades, con las ampliaciones de este archivo.
4. Sistema de Diseño y Alta Fidelidad v2.0 para UI.
5. Arquitectura Técnica Flutter v1.0 para capas y reglas de dependencia, con las correcciones aquí registradas.
6. Plan de Desarrollo y Pruebas v1.0 para la secuencia A0–A8.

El MVP permanece Android, local-first, de un solo usuario, tablet-first y adaptable a teléfono. Personajes, Tienda, Inventario, loadouts, servidor y sincronización quedan post-MVP.

## 2. Identidad y entorno del proyecto

| Decisión | Valor vinculante |
| --- | --- |
| Nombre visible | Bitácora RPG Personal |
| Paquete Dart | `bitacora_rpg_personal` |
| Android applicationId producción | `com.jcyq.bitacorarpg` |
| Flavor desarrollo | `dev`, sufijo `.dev`, nombre “Bitácora RPG DEV” |
| Flavor producción | `prod`, sin sufijo |
| Flutter | 3.41.5 stable |
| Dart | `>=3.11.3 <3.12.0` |
| Plataforma generada | Android/Kotlin |
| Android mínimo | API 24 / Android 7.0 (`flutter.minSdkVersion`) |

La firma de producción no usa la llave debug y se configura únicamente en A8.

## 3. Dependencias fijadas

### A0

- `flutter_riverpod 3.3.2`
- `go_router 17.5.0`
- `flutter_lints 6.0.0`
- `flutter_test` provisto por el SDK

Riverpod usará providers manuales durante el MVP. No se incorporan `riverpod_annotation` ni `riverpod_generator`: sus versiones actuales fuerzan una versión de Analyzer incompatible con Flutter 3.41.5 y Drift. No se permiten `dependency_overrides` para ocultar esa incompatibilidad.

### A1

- `drift 2.34.3`
- `drift_flutter 0.3.1`
- `sqlite3 3.5.2`
- `path 1.9.1`
- `path_provider 2.1.6`
- `drift_dev 2.34.0`
- `build_runner 2.15.1`
- `integration_test` provisto por el SDK

Todas las restricciones son exactas y `pubspec.lock` se versiona. La actualización de Flutter o paquetes requiere un ADR, changelog revisado y las pruebas de la fase afectada en verde.

### A2

- `cryptography 2.9.0`
- `local_auth 3.0.2`
- resolución Android fijada: `local_auth_android 2.0.8`
- sin `cryptography_flutter` mientras Android mínimo sea API 24

### A5

- `image_picker 1.2.3`
- `image 4.9.2` para normalizar orientación y recodificar sin EXIF antes del
  cifrado; su resolución ya formaba parte del lockfile de manera transitiva.

## 4. Navegación canónica

El catálogo inicial de la Arquitectura Técnica queda reemplazado por el Mapa de Navegación Definitivo.

Raíces de dominio:

- Inicio: `/home`
- Misiones: `/missions/today`
- Bitácora: `/journal`
- Economía: `/finance`
- Dashboard/Progreso: `/dashboard/daily`
- Ajustes: `/settings`

Puertas públicas: `/lock` y `/lock/recovery`. `/more` es un contenedor exclusivo de navegación compacta, no un séptimo dominio.

El mapa contiene 58 identificadores NAV y 60 patrones URI concretos, porque NAV-MIS-12 y NAV-ECO-10 agrupan dos rutas cada uno. El registro de código conserva los 60 patrones; no se usa el número editorial “59” como aserción técnica.

El shell usa `StatefulShellRoute.indexedStack` con seis ramas de dominio independientes y una rama técnica para `/more`:

- ancho `< 600`: NavigationBar con Inicio, Misiones, Bitácora, Economía y Más;
- ancho `600–839`: NavigationRail compacto;
- ancho `>= 840`: rail persistente, preparado para maestro/detalle;
- Dashboard y Ajustes seleccionan Más en compacto;
- al ensanchar mientras `/more` está activo, se normaliza a `/dashboard/daily`.

El guard real implementado en A2 cumple el contrato congelado desde A0: solo las dos rutas de acceso son públicas; un destino protegido se conserva como `PendingDestination(navId, location)` sin contenido sensible; al autenticar se reemplaza la puerta y `/lock` no permanece en Back.

## 5. Arquitectura y coordinación transversal

Se mantiene Clean Lite + feature-first y las capas `domain`, `application`, `data` y `presentation`. El dominio no importa Flutter, Riverpod, Drift ni plugins. La UI no accede a DAOs.

Los casos que cruzan varios dominios viven en `lib/app/application/commands/`. `CompleteMission` dependerá de un contrato de unidad de trabajo; su implementación Drift vivirá en infraestructura y ejecutará una sola transacción para Mission, tiempo, evento, XP, Bitácora y movimiento económico opcional.

SQLite no dispone de bloqueo de fila `FOR UPDATE`. `lockForUpdate` queda prohibido. La concurrencia usa actualización optimista:

```text
UPDATE missions
SET ..., row_version = row_version + 1
WHERE id = :id AND row_version = :expectedRowVersion
```

La operación exige exactamente una fila afectada. Las restricciones `UNIQUE` garantizan idempotencia. Dentro de una transacción Drift todas las operaciones se esperan con `await`; notificaciones del sistema, temporizadores, archivos y navegación ocurren después del commit. La tabla `notification_schedules` registra la intención dentro de la transacción y el reconciliador sincroniza Android posteriormente.

## 6. Decisiones del modelo de datos

### 6.1 Importancia y prioridad

Son conceptos distintos y obligatorios:

- `importance`: `MINOR`, `NORMAL`, `IMPORTANT`, `VERY_IMPORTANT`, `CRITICAL`;
- `priority`: `LOW`, `NORMAL`, `HIGH`, `URGENT`;
- ambos comienzan en `NORMAL`;
- importancia sugiere XP `10, 25, 50, 80, 100`, editable por el usuario;
- prioridad ordena urgencia y nunca modifica XP.

El formulario básico muestra Importancia. Prioridad, dificultad y obligatoriedad aparecen en opciones avanzadas. La pantalla HF-V2-MIS-03 debe cambiar el rótulo actual “Prioridad” por “Importancia”, agregar “Muy importante” y añadir Prioridad en avanzadas.

### 6.2 Fotografías de Bitácora

Las fotografías permanecen en el MVP y solo se adjuntan a `JournalEntry`. Una fotografía asociada a una misión se relaciona mediante `journal_entries.mission_id`; no se duplica la relación.

Se agrega `journal_attachments`:

- `id`, `journal_entry_id`, `kind`, `storage_name`, `mime_type`;
- `byte_length`, `cipher_sha256`, `width_px`, `height_px`, `position`;
- `created_at`, `archived_at`;
- `UNIQUE(journal_entry_id, position)`.

El binario no se almacena como BLOB. Se normaliza la orientación, se vuelve a codificar para retirar EXIF, se cifra y se guarda con nombre UUID relativo en el directorio privado. Las miniaturas son derivadas. La importación usa temporal + renombrado atómico y existe limpieza de huérfanos.

### 6.3 Objetivos de plantillas recurrentes

Se agrega `mission_template_objectives`:

- `id`, `template_id`, `description`, `position`;
- `created_at`, `updated_at`, `row_version`;
- `UNIQUE(template_id, position)`.

La generación crea Mission y sus objetivos copiados en una misma transacción. Editar la plantilla solo afecta apariciones futuras. Reprocesar `template_id + scheduled_at` no duplica misión ni objetivos.

### 6.4 Esquema v1

El esquema inicial pasa de 17 a 19 tablas:

1. `life_areas`
2. `mission_templates`
3. `mission_template_objectives`
4. `recurrence_rules`
5. `missions`
6. `mission_objectives`
7. `time_entries`
8. `mission_events`
9. `notification_schedules`
10. `transactions`
11. `savings_goals`
12. `goal_allocations`
13. `journal_entries`
14. `journal_attachments`
15. `xp_transactions`
16. `title_definitions`
17. `title_history`
18. `app_settings`
19. `schema_metadata`

## 7. XP, niveles y Dashboard

Se conserva la fórmula cuadrática y el nivel nunca se persiste:

```text
effectiveXp = max(0, sum(XPTransaction.amount))
level = floor(sqrt(effectiveXp / 100)) + 1
threshold(level) = 100 × (level - 1)²
nextThreshold = 100 × level²
progress = (effectiveXp - threshold(level)) / (nextThreshold - threshold(level))
```

Los ajustes negativos solo corrigen errores y el XP efectivo no baja de cero. Cancelar, fallar o abandonar una misión no resta XP.

El Dashboard analítico del MVP es diario y semanal. La vista mensual queda post-MVP; el gate A5 se corrige a “read models correctos para día y semana”. Bitácora y Economía pueden conservar filtros o resúmenes mensuales sin crear un Dashboard mensual.

## 8. Convenciones técnicas

- SQLite y JSON: `lower_snake_case` ASCII.
- Dart: `lowerCamelCase`; clases: `UpperCamelCase`.
- Archivos y rutas: minúsculas ASCII.
- Valores persistidos de enum: mayúsculas ASCII.
- Español con acentos: solo UI y documentación.

Reemplazos vinculantes: `area_id`, `row_version`, `schema_version`, `format_version`, `idx_missions_area_date`, `idx_xp_area_time` y archivo `bitacora_rpg.sqlite`.

## 9. Seguridad y recuperación

### 9.1 Base de datos

La base de producción estará cifrada desde A1 mediante `NativeDatabase` y SQLite3MultipleCiphers, configurado con el hook `sqlite3: source: sqlite3mc`. Se verifica el pragma de cipher y una lectura de `sqlite_master` antes de abrir el esquema. La clave es aleatoria de 256 bits, no deriva del PIN y queda envuelta por una clave AES-256-GCM no exportable de Android Keystore mediante el puente propio aprobado en ADR-001. No se usa `flutter_secure_storage` para esta clave en v1. Cambiar el PIN no vuelve a cifrar la base.

Pruebas Drift en memoria pueden usar SQLite sin cifrar; toda prueba de integración Android usa la variante cifrada. `android:allowBackup="false"` se aplica desde A0.

### 9.2 Credenciales y adjuntos

- PIN: PBKDF2-HMAC-SHA256, salt aleatorio de 16 bytes, 600.000 iteraciones y salida de 32 bytes; comparación constante y espera progresiva.
- Adjuntos: AES-256-GCM con clave distinta de la base, nonce único de 12 bytes y tag de 16 bytes.
- Las claves locales no se escriben en SQLite, logs ni copias exportadas.

### 9.3 Copia portátil

> Alcance retirado del MVP por ADR-005. El contrato siguiente se conserva solo
> como antecedente de seguridad para una eventual decisión futura y no autoriza
> implementar ni almacenar copias en la versión 1.0.

Toda exportación portable solicita una contraseña o frase de recuperación; no depende de una clave que solo exista en el teléfono. El contenedor v1 contiene manifiesto versionado, salt, parámetros KDF, nonces, bloques cifrados, tags y hashes.

La clave de copia deriva con PBKDF2-HMAC-SHA256, salt aleatorio de 16 bytes, al menos 600.000 iteraciones y salida de 32 bytes. El contenido usa AES-256-GCM por bloques con nonce único. A6 medirá el costo en dispositivo y solo podrá aumentar el trabajo, nunca reducirlo por debajo del mínimo registrado.

La restauración descifra a temporales, valida autenticación, hashes, `format_version` y `schema_version`, migra, verifica claves foráneas y recién entonces reemplaza la base. Los adjuntos se vuelven a cifrar con claves nuevas del dispositivo. No se exportan claves locales.

## 10. Escenario golden canónico

`GoldenScenario.standard` usa reloj `2026-08-23 17:42`, zona `America/La_Paz`, locale `es_BO`, moneda BOB e identificadores fijos.

- 8 misiones activas; 5 del día: 3 completadas, 1 en progreso y 1 pendiente.
- “Completar laboratorio de redes”: importancia `IMPORTANT`, prioridad `HIGH`, 50 XP, 90 minutos, Bs 35, tres objetivos y uno completado.
- 3 entradas de Bitácora: 2 manuales, 1 vinculada y al menos una fotografía.
- Economía: total Bs 1.540, reservado Bs 300, disponible Bs 1.240.
- Mes: +Bs 1.850/−Bs 610; día: +Bs 150/−Bs 192 = −Bs 42.
- XP global: 4.450; nivel 7; 850/1.300, 65 %, faltan 450.
- Áreas: Estudios 1.200; Salud 760; Proyectos 2.150; Hogar 215; Personal 125.
- XP de hoy: 125; semana: 325.

Variantes obligatorias: `412×915`, `1280×800`, texto `2.0×`, alto contraste y cantidades ocultas. Reloj, UUID y fuentes de datos siempre se inyectan; no hay red ni aleatoriedad real.

## 11. Secuencia y puertas de fase

| Fase | Resultado vinculante | No avanzar si… |
| --- | --- | --- |
| A0 | Proyecto, flavors, tema, router, ProviderScope, Result/AppFailure, shell y pruebas base | analyze, tests o build debug fallan |
| A1 | Drift cifrado, 19 tablas, DAOs, índices, seeds y snapshot v1 | esquema o integridad fallan |
| A2 | PIN, recovery, biometría opcional, sesión, guard, auto-lock y privacy cover | una ruta protegida se construye cerrada |
| A3 | Misiones, tiempo, recurrencia, avisos y CompleteMission | hay duplicación o escritura parcial |
| A4 | Ledger, reservas y saldos derivados | ledger y resúmenes divergen |
| A5 | Bitácora, adjuntos, XP, niveles y Dashboard diario/semanal | read models o navegación a fuente fallan |
| A6 | Retirada del MVP por ADR-005 | G6 retirada / no aplica |
| A7 | UI v2 adaptativa, accesible y goldens canónicos | compacto, expandido o texto 2.0 fallan |
| A8 | Rendimiento, regresión, APK/AAB y firma de producción | queda un caso bloqueante o evidencia incompleta |

Cada fase activa termina con formato, `flutter analyze`, `flutter test`, pruebas
específicas, build pertinente y actualización de este estado. No se inicia una
fase nueva con el gate anterior rojo, salvo una excepción explícita registrada
en un ADR. ADR-005 retira A6/G6 del MVP; A8 queda condicionada únicamente a G7.

## 12. Estado actual

- Decisiones C-01 a C-07: cerradas.
- Arquitectura: aprobada con las correcciones de este archivo.
- A0: completada; gate G0 en verde el 24 de agosto de 2026.
- A1: completada; gate G1 en verde el 24 de agosto de 2026.
- A2: completada; gate G2 en verde el 25 de agosto de 2026.
- A3: completada; gate G3 en verde el 26 de agosto de 2026.
- A4: completada; gate G4 en verde el 27 de agosto de 2026.
- A5: completada; G5 quedó verde el 27 de agosto de 2026 después de aprobar la
  matriz automatizada y la validación física final de Progreso.
- A6: retirada del MVP por decisión explícita; G6 retirada / no aplica.
- A7: completada; G7 verde el 28 de agosto de 2026.
- A8: en progreso; G8 permanece rojo hasta validar firma, artefactos,
  rendimiento, regresión y smoke en dispositivo dedicado.
