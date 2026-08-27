# Estado actual y guía de relevo

- Última revisión: **27 de agosto de 2026** (A3/G3 completados; A4 en validación)
- Repositorio: [`Nobody2077/Bitacora_movil`](https://github.com/Nobody2077/Bitacora_movil)
- Rama de trabajo: `main`

Este documento permite que Claude Code, Antigravity, Codex u otro agente continúe el proyecto sin reconstruir su historia ni desmontar accidentalmente decisiones ya validadas.

## Resumen ejecutivo

- La aplicación es Flutter Android, local-first, privada y de un solo usuario.
- A0, A1, A2 y A3 están completadas; G3 quedó verde el 26 de agosto de 2026.
- A4 — Economía está en validación y es la única fase autorizada. Código, rutas,
  pruebas y APK están verdes; A5 continúa bloqueada hasta la aprobación física G4.
- La infraestructura contiene el esquema completo v1 y DAOs adelantados para varias fases.
- Acceso, recuperación, biometría, privacidad y persistencia cifrada sí están conectados al arranque real.
- El gate automatizado actual ejecutó formato, generación Drift,
  `flutter analyze` y 125 pruebas sin fallos; las APK debug `dev` y `prod` se
  generaron el 27 de agosto de 2026 con Economía integrada.
- La prioridad del usuario es construir funcionalidad real. No se deben borrar las pruebas existentes, pero tampoco convertir cada avance en una fase dedicada únicamente a pruebas.
- Incremento actual: Economía funcional completa en código; queda recorrer la
  lista de prueba física y registrar la aprobación del usuario para cerrar G4.

## Relevo inmediato — diseño Terminal V2

Los siguientes cambios visuales están **en el árbol local sin commit**. Leer
también `documentos/ESTADO_VISUAL.md` antes de tocar UI:

- Shell de tablet: cabecera técnica persistente y `TerminalSidebar` propia.
- La cabecera de `TerminalSidebar` ya no muestra la marca fija: presenta el
  nombre y la foto del perfil local, ambos editables al tocarla. El nombre se
  guarda en la base cifrada y la imagen se copia al directorio privado de la
  aplicación sin modificar el esquema Drift v1.
- Los destinos no seleccionados de la barra usan rojo de identidad; el destino
  seleccionado conserva cian. Texto a 16 px, iconos a 24 px y objetivos táctiles
  de 52 px mejoran la lectura en tablet.
- Inicio (`HomeOperationsPage`): Centro de Operaciones con datos reales de
  Misiones y saldo disponible real de Economía, con accesos a gasto e ingreso.
- Centro de Misiones: filtros por estado y área, búsqueda local, tarjetas
  operativas compactas, resumen lateral y estados vacíos reales.
- Detalle de misión: identidad, objetivos/progreso, plan de ejecución,
  acciones existentes y registro basado en segmentos de tiempo.
- Nueva/Editar misión: Información y Objetivos a la izquierda, Planificación
  a la derecha y creación definitiva con acción roja.
- Paleta vinculante: `primaryAction` es cian (`#1EC2C6`) para CTA reversible;
  `criticalAction` es rojo (`#D00000`) para seguridad, destrucción o creación
  definitiva. Ver la tabla completa en `ESTADO_VISUAL.md`.

### Antes de continuar o generar APK

1. Revisar físicamente Inicio, Misiones, Detalle, Nueva misión y Recurrencias
   en tablet
   horizontal. No limpiar datos de la app: es almacenamiento local cifrado.
3. No implementar aún la pantalla de Bitácora como mockup. Para la lámina
   HF-V2-BIT-01 falta primero A5 funcional: casos de uso, providers, entradas
   manuales/vinculadas, resumen diario, estado del día y XP registrado.

### Cambios locales ajenos que se deben preservar

Además del rediseño y recurrencias hay modificaciones locales de iconos Android,
`assets/` y `pubspec.yaml`/`pubspec.lock`. Su origen no fue este incremento.
No añadirlas, revertirlas ni combinarlas con commits de UI sin revisarlas con el
usuario.

---

## Correcciones de paleta Terminal V2 (esta sesión)

Se detectaron y corrigieron dos incumplimientos de la jerarquía de color definida en `ESTADO_VISUAL.md` y la especificación del agente previo:

| Archivo | Antes | Después | Regla aplicada |
|---------|-------|---------|----------------|
| `lib/features/access/presentation/privacy_settings_pages.dart:237` | `FilledButton` (cian `primaryAction`) para "Actualizar PIN" | `TerminalCriticalButton` (rojo `criticalAction` `#D00000`) | **El rojo sólido se reserva para acciones que crean, confirman seguridad o destruyen datos**. Cambiar PIN es acción de seguridad. |
| `lib/features/access/presentation/access_widgets.dart:256` | `AccessNoticeBanner` usaba rojo/naranja para TODOS los avisos (incluyendo éxitos) | Detección de `isSuccess` (`pinChanged`, `biometricsEnabled`, `biometricsDisabled`) → fondo/borde `progressGreen` (`#45D483`) | **Verde = progreso, éxito**. Los avisos de éxito no deben parecer errores. |

### Verificaciones tras corrección

- `flutter analyze`: limpio en código principal (4 errores pre-existentes solo en tests de calendario/fakes)
- `flutter test test/features/access/`: 50 tests PASS
- `flutter test test/features/settings/`: 2 tests PASS
- `flutter build apk --debug --flavor prod`: Built successfully

### Archivos modificados

| Archivo | Cambio |
|---------|--------|
| `lib/features/access/presentation/privacy_settings_pages.dart` | Import `terminal_widgets.dart` + `TerminalCriticalButton` en ChangePinPage |
| `lib/features/access/presentation/access_widgets.dart` | Lógica `isSuccess` + colores diferenciados en `AccessNoticeBanner` |

---

---

## Qué fue implementado en la última sesión (recurrencias)

### Archivos NUEVOS creados

| Archivo | Contenido |
|---|---|
| `lib/features/recurrences/domain/models/recurrence_template.dart` | `RecurrenceFrequency` (enum), `RecurrenceObjective`, `RecurrenceRule`, `RecurrenceTemplate` (modelos de dominio inmutables) |
| `lib/features/recurrences/domain/repositories/recurrence_repository.dart` | Interfaz `RecurrenceRepository` con `watchActiveTemplates`, `watchAllTemplates`, `findById`, `create`, `update`, `pause`, `resume`, `deleteIfUnused` |
| `lib/features/recurrences/data/recurrence_mapper.dart` | `RecurrenceMapper` — mapea `MissionTemplateBundle` → `RecurrenceTemplate` y enums Drift ↔ dominio |
| `lib/features/recurrences/data/drift_recurrence_repository.dart` | `DriftRecurrenceRepository implements RecurrenceRepository` — wrappea `RecurrenceDao`, todos los métodos retornan `Result<T>` |
| `lib/features/recurrences/application/recurrence_application_service.dart` | `RecurrenceApplicationService` con `saveTemplate`, `pauseTemplate`, `resumeTemplate`, `deleteTemplateIfUnused`, `generatePendingOccurrences` (ventana 30 días, idempotente). También contiene el DTO `SaveTemplateRequest` y `RecurrenceObjectiveDraft` |
| `lib/features/recurrences/application/recurrence_providers.dart` | `recurrenceApplicationServiceProvider`, `allTemplatesProvider`, `activeTemplatesProvider`, `templateDetailProvider` |
| `lib/features/recurrences/presentation/recurrence_form_page.dart` | Formulario adaptable para crear/editar plantillas recurrentes. Tiene `_InfoPanel`, `_RecurrencePanel` (frecuencia, días de la semana, fechas, hora), `_ObjectivesPanel`, `_FormActions` |
| `lib/features/recurrences/presentation/recurrence_list_page.dart` | Lista de todas las plantillas con tarjetas, métricas resumidas, botones pausa/reactivar/editar/eliminar |

### Archivos MODIFICADOS

| Archivo | Qué se añadió |
|---|---|
| `lib/infrastructure/database/daos/recurrence_dao.dart` | Tres métodos nuevos al final: `watchAllTemplates()`, `updateTemplate(patch)`, `setTemplateActive(templateId, {isActive})` |
| `lib/app/providers/persistence_providers.dart` | Imports de `RecurrenceApplicationService`, `DriftRecurrenceRepository`, `RecurrenceRepository`, `SystemMissionClock`, `SecureMissionIdGenerator`. Proveedor `recurrenceRepositoryProvider`. Guard `recurrenceGenerationGuardProvider` (dispara generación al desbloquear) |
| `lib/features/access/presentation/privacy_boundary.dart` | `ref.watch(recurrenceGenerationGuardProvider)` junto a `persistenceAccessGuardProvider` en el método `build` |
| `lib/app/router/app_router.dart` | Imports de `RecurrenceFormPage` y `RecurrenceListPage`. Rutas `missionsRecurring` → `RecurrenceListPage`, `missionTemplateNew` → `RecurrenceFormPage()`, `missionTemplateEdit` → `RecurrenceFormPage(templateId:)`, `missionTemplatePause` → `RecurrenceListPage` |

---

## Qué funciona actualmente

### Base de aplicación

- Entradas separadas `main_dev.dart` y `main_prod.dart`.
- `ProviderScope` raíz con entorno inyectado.
- Tema oscuro y shell adaptable para teléfono y tablet.
- GoRouter con seis ramas de dominio y una rama técnica `/more`.
- Localización española.
- `Result<T>` y jerarquía tipada de fallos.
- Perfil local editable desde la barra lateral de tablet: nombre persistente,
  selector de foto del sistema, copia privada y opción para retirar la imagen.

### Persistencia

- Esquema Drift v1 de 19 tablas.
- 21 índices explícitos y 19 claves foráneas.
- Seeds iniciales idempotentes.
- DAOs para misiones, recurrencia, notificaciones, economía, Bitácora, progreso y ajustes.
- Repositorios Drift para Misiones, Recurrencias, Economía, Bitácora, Progreso y Ajustes.
- SQLite3MultipleCiphers con ChaCha20.
- Clave de base aleatoria de 256 bits protegida mediante Android Keystore.
- Base cerrada e inaccesible mientras la sesión está bloqueada.

### Acceso y privacidad

- Configuración y cambio de PIN obligatorio de seis dígitos.
- Código de recuperación Crockford Base32.
- PBKDF2-HMAC-SHA256 con 600.000 iteraciones.
- Espera progresiva persistente ante fallos.
- Biometría opcional y exclusivamente biométrica.
- Estado de acceso cifrado mediante AES-256-GCM y Android Keystore.
- Autobloqueo configurable.
- Cubierta opaca al pausar la aplicación.
- `FLAG_SECURE` contra capturas y vistas recientes.
- Guard global que impide construir rutas y persistencia protegidas con sesión cerrada.

### Incrementos funcionales de Misiones (completados antes de esta sesión)

- Capa `application` con reloj e identificadores inyectables.
- Consulta reactiva de las misiones programadas para el día local.
- Lectura de áreas de vida desde los seeds de la base.
- Creación atómica de Mission, objetivos y evento `CREATED`.
- Edición atómica con `row_version`, reemplazo de objetivos y evento `UPDATED`.
- Pantallas adaptables de Misiones de hoy, nueva/editar y detalle.
- Consultas reactivas para Misiones de hoy, Próximas desde mañana y Todas las no archivadas.
- Inicio, pausa y reanudación atómicos con eventos `STARTED`, `PAUSED` y `RESUMED`.
- Recuperación del cronómetro mediante timestamps persistidos.
- Regla global de un solo cronómetro activo validada dentro de la transacción.
- Consulta global del cronómetro abierto y barra persistente en todo módulo protegido.
- Cambio atómico de cronómetro.
- `CompleteMission` transversal con una sola transacción Drift.
- Pantallas adaptables de revisión y resultado.
- Calendario mensual funcional conectado a `/missions/calendar`, con consulta
  reactiva del rango, selección diaria, estados y navegación al detalle.
- XP parcial editable entre 0 y el valor planificado; el comando valida el
  rango y la transacción lo registra en ledger, evento y recibo.
- El resultado narrativo del cierre es opcional: vacío se persiste como `NULL`
  y no deja un bloque en blanco en la pantalla de resultado.
- El detalle permite archivar una misión con confirmación. La operación conserva
  estado e historial, registra `ARCHIVED`, cancela avisos abiertos y la oculta
  de Hoy, Próximas, Todas y Calendario. Un cronómetro activo bloquea el archivo.

### Incrementos de Recurrencias (implementados, corregidos y probados)

- Modelo de dominio completo: `RecurrenceFrequency`, `RecurrenceObjective`, `RecurrenceRule`, `RecurrenceTemplate`.
- Interfaz `RecurrenceRepository` con contrato completo.
- `DriftRecurrenceRepository` con todos los métodos.
- `RecurrenceApplicationService` con los 3 casos de uso: guardar plantilla, pausar/reanudar, generar ocurrencias.
- Providers Riverpod para plantillas activas, todas, detalle.
- Guard post-unlock que dispara generación automática al desbloquear la app.
- `RecurrenceFormPage` — formulario adaptable crear/editar plantilla.
- `RecurrenceListPage` — lista con tarjetas, métricas, acciones.
- 4 rutas reales conectadas: `missionsRecurring`, `missionTemplateNew`, `missionTemplateEdit`, `missionTemplatePause`.
- Ventana exacta de 30 fechas civiles calculada con el reloj inyectado.
- Reglas cada N días y semanales ancladas en `startDate`, sin desplazamiento al
  reanudar una generación.
- Conversión Android mediante zona IANA persistida, incluida resolución de
  fechas civiles a UTC sin depender de la zona actual del proceso Dart.
- Edición de raíz, objetivos y regla en una única transacción Drift.
- Cuatro pruebas específicas cubren ventana, idempotencia, anclaje, pausa y
  rollback del agregado.

---

## Qué todavía no está implementado

### A3 — Misiones

Ya está conectado en código:

- Todo lo listado en "Incrementos funcionales de Misiones" y "Recurrencias".
- Intención `START` atómica para misiones manuales y recurrentes.
- Reconciliación Android post-commit: permiso, programación, entrega idempotente,
  cancelación, preferencia de avisos, sonido y texto privado genérico.

G3 fue aprobado físicamente en la Redmi Pad. La notificación se recibió en
pantalla bloqueada con contenido genérico y privado, como exige ADR-002.

### A4 — Economía en desarrollo

- Modelo de dominio tipado para movimientos, medios de pago, metas y asignaciones.
- Repositorio Drift ampliado con consultas reactivas y comandos de producción.
- Servicio de aplicación con validación de ingresos, gastos, ajustes, anulaciones
  compensatorias, corrección atómica, creación/edición de metas y reservas.
- Providers Riverpod para resumen, ledger, detalle y metas.
- El saldo total, reservado y disponible se deriva del ledger y las asignaciones;
  no existen cuentas ni saldos mutables paralelos.
- Resumen, historial, formularios, detalle, corrección, anulación, análisis,
  metas y reserva/liberación conectados a todas las rutas canónicas de A4.
- Inicio consume el resumen económico real y permite registrar gasto/ingreso.
- Las reservas no pueden superar la meta ni el saldo disponible; SQLite vuelve
  a comprobar ambas reglas dentro de la transacción.
- Las metas sincronizan automáticamente `ACTIVE`/`ACHIEVED`; las pausadas no
  reciben nuevas reservas y el objetivo no puede quedar debajo de lo reservado.
- Verificación posterior del perfil/barra: `flutter analyze` limpio y 125
  pruebas verdes
  el 27 de agosto de 2026.
- APK debug `dev` y `prod` compiladas correctamente el 27 de agosto de 2026;
  `prod` se recompiló después de integrar el selector de foto.
- Pendiente único para G4: validación física y aprobación del usuario.

### Fases posteriores

- Bitácora tiene modelo, mapper, repositorio y DAO, pero no UI ni adjuntos funcionales.
- Progreso tiene modelo, repositorio y DAO, pero no Dashboard funcional.
- Copia/restauración, UI v2 final, accesibilidad completa y release pertenecen a A6–A8.

---

## Mapa de conexión en producción

```text
main_dev/main_prod
    └── bootstrap(AppEnvironment)
        └── ProviderScope
            └── BitacoraApp
                ├── appRouterProvider
                │   ├── accessSessionProvider
                │   ├── guard de rutas
                │   └── shell adaptable / Misiones reales / Economía real / placeholders posteriores
                └── AppPrivacyBoundary
                    ├── auto-lock
                    ├── privacy cover
                    ├── persistenceAccessGuardProvider → cierra BD al bloquear
                    ├── recurrenceGenerationGuardProvider → genera ocurrencias y reconcilia avisos al desbloquear
                    └── appDatabaseProvider cifrada solo al desbloquear
```

---

## Estructura que debe preservarse

### Nivel 1 — No modificar sin motivo contractual

| Área | Rutas principales | Razón |
|---|---|---|
| Decisiones | `documentos/DECISIONES_PRE_A0.md`, `ADR-001`, `ADR-002` | Son la fuente de verdad vigente |
| Esquema v1 | `lib/infrastructure/database/schema.drift` | Cambiarlo exige migración, snapshot y revisión de contrato |
| Código Drift generado | `lib/infrastructure/database/app_database.g.dart` | Se regenera; no se edita manualmente |
| Snapshots Drift | `drift_schemas/` | Evidencia y base de migraciones |
| Cifrado de base | `encrypted_database_connection.dart`, `DatabaseKeyStoreBridge.kt` | Una alteración puede volver ilegible o exponer la base |
| Credenciales | `features/access/domain`, `features/access/data`, `AccessCredentialStoreBridge.kt` | Lógica criptográfica y fail-closed |
| Sesión y privacidad | `access_session_controller.dart`, `privacy_controller.dart`, `privacy_boundary.dart` | Evitan reapertura tardía y exposición visual |
| Frontera de persistencia | `app/providers/persistence_providers.dart` | Impide abrir DAOs o base con sesión cerrada |
| Seguridad Android | `MainActivity.kt`, `PrivacyWindowBridge.kt`, `AndroidManifest.xml` | Keystore, biometría, `FLAG_SECURE` y `allowBackup=false` |

### Nivel 2 — Extender respetando contratos existentes

- `app/router/app_routes.dart`: conserva los 60 patrones URI y sus parámetros permitidos.
- `app/router/app_router.dart`: reemplaza placeholders por páginas reales sin debilitar el guard.
- `shared/adaptive/adaptive_shell.dart`: conserva breakpoints y ramas independientes.
- `app/theme/`: reutiliza tokens antes de crear estilos locales.
- `core/result/` y `core/errors/`: los repositorios devuelven resultados tipados.
- Repositorios de dominio: pueden ampliarse para los casos de uso, sin exponer Drift.
- DAOs: pueden ampliarse, pero las operaciones multientidad deben permanecer atómicas.

### Nivel 3 — Temporal, generado o reemplazable

- `FeaturePlaceholderPage`: debe desaparecer progresivamente al implementar pantallas reales.
- `build/` y `.dart_tool/`: artefactos generados; no se versionan.
- `.idea/`, `.vscode/`: configuración local.

---

## Reglas arquitectónicas que continúan vigentes

1. El dominio no importa Flutter, Riverpod, Drift ni plugins.
2. La UI consume application/casos de uso; nunca consume DAOs directamente.
3. `CompleteMission` cruza dominios mediante una unidad de trabajo y una sola transacción.
4. No usar `FOR UPDATE`; SQLite usa `row_version` y actualización optimista.
5. Identificadores, query y fragmentos sensibles no deben aparecer en logs.
6. La base debe permanecer cerrada cuando la sesión no está desbloqueada.
7. Las operaciones externas a SQLite ocurren después del commit.
8. No configurar firma release con la llave debug.
9. No actualizar dependencias fijadas ni Flutter sin revisar el contrato vigente.
10. Antes de editar, ejecutar `git status` y no sobrescribir cambios ajenos.

---

## Secuencia recomendada para continuar

### Secuencia recomendada para continuar (próxima sesión)

El punto de entrada inmediato es validar A4 — Economía en el dispositivo físico
sin borrar los datos locales. Tras la aprobación se documenta G4 verde y recién
entonces puede comenzar A5 — Bitácora y progreso.

---

## Registrado, pero todavía sin consumidor funcional

| Pieza | Situación actual | Destino previsto |
|---|---|---|
| `recurrenceDaoProvider` | Registrado y usado por `recurrenceRepositoryProvider` | A3 ✓ conectado |
| `notificationDaoProvider` | Consumido por el reconciliador Android post-commit | A3 ✓ conectado |
| `economyRepositoryProvider` | Consumido por providers, servicio, Inicio y UI de Economía | A4 en validación |
| `journalRepositoryProvider` | Solo declaración en `lib` | A5 |
| `progressRepositoryProvider` | Solo declaración en `lib` | A5 |
| Rutas de negocio con placeholder restantes | Contrato de navegación ya congelado | A3–A7 |

---

## Comandos operativos

Preparar dependencias:

```powershell
flutter pub get
```

Análisis rápido:

```powershell
flutter analyze
```

Ejecutar en desarrollo:

```powershell
flutter run --flavor dev -t lib/main_dev.dart
```

Generar APK dev:

```powershell
flutter build apk --debug --flavor dev -t lib/main_dev.dart
```

Verificación completa:

```powershell
powershell -ExecutionPolicy Bypass -File tool/quality.ps1
```

---

## Lista de lectura antes de cambiar arquitectura

1. Este documento.
2. `documentos/DECISIONES_PRE_A0.md`.
3. ADR-001 si se toca base, DAOs, cifrado, claves o esquema.
4. ADR-002 si se toca acceso, sesión, router protegido, autobloqueo o privacidad.
5. El documento fuente específico de UX, navegación o datos cuando se implemente una pantalla.

Si una pieza parece no usada, buscar referencias tanto en `lib/` como en `test/` e `integration_test/` y revisar su fase prevista antes de eliminarla.
