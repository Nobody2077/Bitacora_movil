# Estado actual y guía de relevo

- Última revisión: **6 de septiembre de 2026** (`1.2.1+6` aprobada físicamente;
  siguiente incremento: notificaciones)
- Repositorio: [`Nobody2077/Bitacora_movil`](https://github.com/Nobody2077/Bitacora_movil)
- Rama de trabajo: `main` (`feat/misiones-recurrentes-tablon` ya fusionada)

Este documento permite que Claude Code, Antigravity, Codex u otro agente continúe el proyecto sin reconstruir su historia ni desmontar accidentalmente decisiones ya validadas.

## Resumen ejecutivo

- La aplicación es Flutter Android, local-first, privada y de un solo usuario.
- A0–A5 están completadas. G3 quedó verde el 26 de agosto de 2026 y G4 fue
  aprobado físicamente el 27 de agosto de 2026.
- A5.1–A5.3 y la ampliación final de Progreso fueron aprobadas físicamente el
  27 de agosto de 2026. A5 está completada y G5 está verde.
- ADR-005 retira A6 del MVP y deja G6 sin aplicación. No habrá exportación,
  restauración ni historial local de copias.
- La infraestructura contiene el esquema v3, compatible mediante migración con
  datos v1 y v2, y DAOs adelantados para varias fases.
- Acceso, recuperación, biometría, privacidad y persistencia cifrada sí están conectados al arranque real.
- La consolidación de A5.3 aprobó formato, `flutter analyze`, 158 pruebas y la
  compilación de la APK `prod-debug` el 27 de agosto de 2026.
- La ampliación final de Progreso aprobó formato, `flutter analyze`, 161 pruebas
  y `assembleProdDebug` el 27 de agosto de 2026.
- La prioridad del usuario es construir funcionalidad real. No se deben borrar las pruebas existentes, pero tampoco convertir cada avance en una fase dedicada únicamente a pruebas.
- Último incremento: **A7.4**. Los estados accesibles se extendieron a detalles,
  formularios, selectores en línea, fotografías privadas y acceso. El diálogo
  de perfil admite desplazamiento con texto 2.0× y comunica sus operaciones.
  La matriz está verde con 182 pruebas y APK `prod-debug`. El usuario aprobó la
  validación física el 28 de agosto de 2026: A7 está completada y G7 verde.
- Base release: **A8.1**. La versión `1.0.0+2`; firma release
  falla cerrada sin credenciales y nunca usa la llave debug. `prod` rechaza
  tráfico claro, Android excluye todos los dominios de backup/transferencia y
  `java.time` queda desugared para API 24–25. El preflight de hardening, planes
  de consulta, **183/183 pruebas** y Lint `prodRelease` está verde; la APK
  `prod-debug` también compila y fue aprobada físicamente por el usuario.
  Se creó la firma permanente y se verificaron APK/AAB release `1.0.0+1`, sin
  permiso `INTERNET`. El usuario aprobó la instalación limpia y los flujos de
  la release. La candidata `1.0.0+2`, compilada y verificada con la misma firma,
  se instaló encima de `1.0.0+1`; el usuario confirmó que todo funciona y no
  reportó pérdida de datos. Faltan las métricas cifradas y el respaldo externo
  de la firma.
- Incremento actual: **A9.1**. La candidata `1.1.1+4` amplía el calendario a
  Día/Semana/Mes, crea misiones con la fecha seleccionada y activa la pantalla
  real de Notificaciones con anticipación y horario silencioso. Las preferencias
  usan metadata cifrada y no cambian el esquema v1. El BÚFER táctil y el color
  de acceso configurable, la transición terminal y el fondo negro elevan la
  matriz a **202/202 pruebas** con análisis limpio. El APK `1.1.1+4` está
  firmado y verificado; el AAB `1.1.0+3` es anterior a estos ajustes visuales.
  Falta validación física G9.
- Incremento local del **29 de agosto de 2026**: las misiones diarias creadas
  desde el formulario generan recurrencia; la planificación admite sin fecha,
  solo fecha o fecha y hora. La barra lateral usa una batería real modular cian
  y un corazón rojo, sin el pie `BITÁCORA · V2`. El acceso PIN se adapta a una
  columna vertical o dos columnas horizontales sin cambiar su seguridad.
  Ajustes incorpora permisos locales
  para capturas, título en notificaciones y cámara al adjuntar. Bitácora ofrece
  ocho estados de ánimo. Misiones añade un tablón interno para tomar rutinas
  diarias sin crearlas por anticipado; el esquema migra de v1/v2 a v3 sin
  perder entradas. La matriz está verde con 219 pruebas y análisis limpio. La
  APK `prodRelease` `1.2.0+5` está firmada y verificada; aún requiere recorrido
  físico en dispositivo.
- Mantenimiento del **5 de septiembre de 2026** (sin cambios funcionales ni de
  versión): se retiraron las cinco rutas huérfanas `settingsData*` de A6
  (ADR-005) y se refactorizó el router a builder-por-contrato. `_buildRoute`
  dejó de despachar por nombre con ~40 `if`; ahora cada `AppRouteContract`
  declara su página en `builder` y el router solo aplica el envoltorio
  transversal (guard + observer). Se añadió una prueba que fija las superficies
  diferidas sin página para evitar rutas huérfanas silenciosas. Detalle en
  "Nivel 2" más abajo. La matriz quedó en 221 pruebas con análisis limpio.
- Sesión del **6 de septiembre de 2026**: la rama
  `feat/misiones-recurrentes-tablon` lleva `1.2.1+6` a validación física. El
  detalle de cada sesión, con lo decidido y lo que queda abierto, vive ahora
  en "Bitácora de sesiones", justo debajo.

## Bitácora de sesiones

Registro cronológico y detallado de cada sesión de trabajo. Entrada nueva
arriba. Sirve para retomar el hilo cuando se pierde el contexto de una sesión:
qué se tocó, qué se decidió, qué quedó abierto.

### 2026-09-06 — Validación física de `1.2.1+6` y hallazgo de descubrimiento

**Rama:** `feat/misiones-recurrentes-tablon`, fusionada a `main` al cerrar el recorrido.

**Commits de la rama:**

| Commit | Contenido |
|---|---|
| `96a4a37` | `feat(misiones)`: sección propia "Recurrentes" en la navegación interna, tablón deja de listar misiones ya resueltas, `MissionCardGrid` reparte en 1–3 columnas, el fallo de generación de ocurrencias deja de ser silencioso. 222 pruebas verdes. |
| `cc3635a` | `chore(release)`: `pubspec.yaml` a `1.2.1+6` para el recorrido físico. |

**Recorrido físico de `1.2.1+6`: CERRADO Y APROBADO por el usuario.**

Validado en dispositivo:

- Crear una plantilla recurrente y verla aparecer en los días correspondientes.
- Sección **Recurrentes** alcanzable desde la navegación interna de Misiones.
- Tablón, cuadrícula y el resto de la aplicación sin fallos reportados.
- El usuario aprueba explícitamente la disposición actual: **"me gusta dónde
  está todo, dejemos como está actualmente"**. No se reordena nada.

**Hallazgo confirmado — descubrimiento al crear misiones (registrado, NO se corrige por ahora):**

El único hallazgo del recorrido. El usuario, que es quien construye la
aplicación, no encontró al crear una misión ni la recurrencia ni el tablón.
Son **dos mecanismos distintos de ocultación**, no uno:

1. **Recurrencia — ausente del formulario.** `MissionType.recurring` está oculto
   al crear: `if (editing || value != MissionType.recurring)`
   (`mission_form_page.dart:758`). Solo el tipo **Diaria** genera plantilla, con
   `frequency: daily, intervalValue: 1` fijo (`mission_form_page.dart:502-511`).
   El formulario real con Semanal y **Días específicos** (chips de lunes a
   domingo) vive en otra pantalla: `recurrence_form_page.dart:791` y `:828`,
   accesible por Misiones → Recurrentes → "Nueva plantilla"
   (`recurrence_list_page.dart:95`).
2. **Tablón — presente pero en el panel equivocado.** El selector
   Automática/Tablón sí está en el formulario (`mission_form_page.dart:837`),
   pero solo aparece al elegir "Diaria" y lo hace en el panel de
   **Planificación**, mientras que el tipo se elige en el panel de
   **Información** (`:753`). El usuario cambia algo en una columna y la opción
   brota en la otra.

Efecto común: la opción existe, pero no está donde se la busca. Quien quiere
"materia de universidad todos los lunes" entra por "Crear misión" y no llega.

**Propuesta registrada, sin implementar:** enlace en el formulario del tipo
"¿Se repite en días concretos? → Crear plantilla recurrente" que navegue a
`missionTemplateNew` arrastrando título y área. **El usuario decidió mantener
la disposición actual**, así que esto queda como deuda de UX consciente, no
como tarea pendiente. Reabrir solo si aparecen usuarios distintos del autor.

**Decisiones de esta sesión:**

- No apilar cambios nuevos sobre el APK bajo prueba física: mientras código y
  dispositivo coincidan, cada anomalía es atribuible sin ambigüedad. Regla
  respetada; el recorrido se cerró antes de tocar código.
- El refactor mencionado en la sesión anterior queda **después** de cerrar los
  cambios funcionales en curso. No se abre todavía.
- A partir de esta entrada, cada sesión documenta aquí sus cambios en detalle.
- **Alarmas exactas descartadas** por consumo de batería, a petición del
  usuario. Se mantiene `setAndAllowWhileIdle`.

**Siguiente incremento acordado — notificaciones.** Orden pactado:

1. Reprogramar alarmas tras reinicio del teléfono (`RECEIVE_BOOT_COMPLETED` +
   receiver). Android borra todas las alarmas de `AlarmManager` al arrancar y
   hoy no hay nada que las reponga: `reconcile()` solo corre al desbloquear
   (`persistence_providers.dart:225`). Coste de batería nulo; es el cimiento
   del resto.
2. Resumen diario configurable ("hoy tienes 8 misiones") a la hora que elija el
   usuario. Una sola alarma al día.
3. Aviso de vencimiento para misiones urgentes. Hoy el único tipo emitido es
   `'START'` (`drift_mission_repository.dart:365`).
4. Texto personalizable y pulido de "mostrar detalles".

**Restricción de diseño que condiciona todo lo anterior:** la base está cifrada
y cerrada mientras la sesión está bloqueada (ADR-002), así que el receiver
nativo **no puede contar misiones al disparar**. El sistema actual ya resuelve
esto precocinando el texto en Dart y pasándolo por el canal
(`MissionAlarmReceiver.kt:76`). El resumen diario debe seguir el mismo patrón:
conteo precalculado con la app desbloqueada. Consecuencia aceptada: el número
es una foto del último uso, no del amanecer.

**Decisión de esquema pendiente:** `notification_schedules` exige `missionId` y
su clave única es `{missionId, notificationType, notifyAt}`. El resumen diario
no pertenece a ninguna misión. Hay que elegir a propósito entre migrar el
esquema (v3 → v4) o usar un identificador sintético.

**Abierto / por recordar:**

- El contenido del "commit 2" planificado en la sesión anterior se perdió al
  cerrarse esa sesión. Sigue sin reconstruirse.
- El golden `sidebar_modular_battery` ya fallaba en `main` antes de `96a4a37`
  (0,26 % por antialiasing de fuente). Se dejó intacto a propósito.
- El repositorio es **privado**: las contribuciones no aparecen en el perfil sin
  activar "Include private contributions on my profile", y solo cuentan los
  commits que llegan a la rama por defecto. El usuario fusiona a `main` a mano.
- No se reportó el resultado de la prueba de reinicio del Bloque 4. La conducta
  de Android está documentada, así que no bloquea el punto 1.

## Relevo inmediato — diseño Terminal V2

Los siguientes cambios visuales están integrados en `main` desde el commit
`11cbaa4`. Leer también `documentos/ESTADO_VISUAL.md` antes de tocar UI:

- Shell de tablet: cabecera técnica persistente y `TerminalSidebar` propia.
- La cabecera de `TerminalSidebar` ya no muestra la marca fija: presenta el
  nombre y la foto del perfil local, ambos editables al tocarla. El nombre se
  guarda en la base cifrada y la imagen se copia al directorio privado de la
  aplicación sin modificar el esquema Drift v1.
- Los destinos no seleccionados de la barra usan rojo de identidad; el destino
  seleccionado usa amarillo con marco completo y esquina inferior derecha
  recortada. Texto a 16 px, iconos a 24 px y objetivos táctiles de 52 px
  mejoran la lectura en tablet. Los tres divisores principales del shell usan
  rojo estructural.
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

1. No limpiar datos de la app: es almacenamiento local cifrado.
2. A5 y G5 están cerradas, incluida la validación física de títulos, rachas y
   niveles por área el 27 de agosto de 2026.
3. A6 fue retirada del MVP según ADR-005. G7 está verde y A8 está en progreso.
4. No desinstalar una APK `prod` debug que contenga datos: Android no permite
   actualizarla con la nueva firma y A6 no ofrece migración/exportación.

### Cambios locales ajenos que se deben preservar

El árbol estaba limpio al iniciar A7. Cualquier cambio local futuro que no esté
descrito en este relevo debe considerarse del usuario y preservarse.

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
- Fondo negro puro `#000000` en lienzo, barra lateral, paneles, tarjetas y
  superficies elevadas; la jerarquía depende de bordes, forma y color de texto.
- GoRouter con seis ramas de dominio y una rama técnica `/more`.
- Localización española.
- `Result<T>` y jerarquía tipada de fallos.
- Perfil local editable desde la barra lateral de tablet: nombre persistente,
  selector de foto del sistema, copia privada y opción para retirar la imagen.

### Persistencia

- Esquema Drift v3 de 19 tablas, con snapshots v1/v2 preservados y migraciones
  probadas.
- 21 índices explícitos y 19 claves foráneas.
- Seeds iniciales idempotentes.
- DAOs para misiones, recurrencia, notificaciones, economía, Bitácora, progreso y ajustes.
- Repositorios Drift para Misiones, Recurrencias, Economía, Bitácora, Progreso y Ajustes.
- SQLite3MultipleCiphers con ChaCha20.
- Clave de base aleatoria de 256 bits protegida mediante Android Keystore.
- Base cerrada e inaccesible mientras la sesión está bloqueada.

### Acceso y privacidad

- Configuración y cambio de PIN obligatorio de seis dígitos.
- La pantalla bloqueada captura el PIN mediante una matriz numérica táctil; no
  monta un `TextField` ni abre el teclado del sistema. El BÚFER oculta cada
  dígito y valida automáticamente al completar seis posiciones.
- Mientras la autenticación real está activa, una transición terminal muestra
  lluvia de códigos, barrido, segmentos y los estados de validación/apertura.
  No añade demora, no usa datos sensibles y queda estática con movimiento
  reducido.
- Apariencia permite elegir amarillo, rojo o gris para esta superficie. Un
  espejo local no sensible conserva únicamente esa elección para poder leerla
  antes de abrir la base cifrada; nunca contiene PIN ni datos privados.
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

### A4 — Economía completada

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
- Validación física aprobada por el usuario el 27 de agosto de 2026, incluida
  persistencia correcta después de salir de la aplicación. G4 está verde.

### A5 — Completada; G5 verde

- Bitácora tiene cronología diaria reactiva, resumen/estado del día, creación,
  edición, detalle y vínculos navegables con misiones o movimientos.
- Se conectaron `JournalApplicationService`, providers y las rutas `journal`,
  `journalNew`, `journalEdit` y `journalDetail` sobre la persistencia cifrada.
- La procedencia histórica no cambia al editar y una fuente eliminada no impide
  corregir el contenido de la entrada.
- A5.1 fue aprobada físicamente por el usuario el 27 de agosto de 2026,
  incluida la persistencia de las entradas al salir de la aplicación.
- A5.2 permite elegir una fotografía desde el sistema, normalizar orientación,
  limitar el lado mayor a 4096 px, recodificar JPEG sin EXIF y cifrar con
  AES-256-GCM usando una clave Android Keystore distinta de la base.
- Los archivos usan nombre UUID opaco, encabezado versionado con nonce/tag y
  SHA-256 verificable. Se prepara un temporal autenticado, se confirma SQLite y
  recién entonces se renombra; el arranque recupera interrupciones y limpia
  huérfanos. La vista descifra en memoria; retirar archiva primero la fila y
  limpia después el archivo cifrado.
- A5.2 fue aprobada físicamente por el usuario el 27 de agosto de 2026.
- A5.3 conecta `/journal/search` con búsqueda SQLite por rango inclusivo de
  fechas civiles, texto literal en título/contenido, procedencia y presencia de
  fotografías. `%` y `_` no se interpretan como comodines introducidos por el
  usuario y los resultados excluyen entradas archivadas.
- `/journal/archive` muestra entradas ocultas de la cronología, conserva
  contenido, vínculos y fotografías, y permite restaurarlas. El detalle exige
  confirmación antes de archivar y queda en modo lectura mientras está archivado.
- **Cierre diario implementado y validado** (`/journal/daily-close/:date`) con métricas, lista de misiones y reflexión persistida.
- **Dashboards implementados**: Diario (`/dashboard/daily`), Semanal (`/dashboard/weekly`) y Progreso/Nivel RPG (`/dashboard/progress`).
- Progreso tiene modelo, repositorio, DAO y **Dashboard funcional y reactivo**.
- XP global y por área usan la fórmula cuadrática de nivel. El semanal muestra
  racha actual/mejor racha y Progreso expone títulos vigentes con historial de
  activación, desactivación y recuperación.
- `Centinela del hogar` queda ganado al completar 100 misiones de Hogar;
  `Ritmo constante` permanece activo con una racha diaria de siete días. El
  contrato y el alcance temporal están documentados en ADR-003.
- La matriz automatizada final aprobó formato, análisis, **161 pruebas** y APK
  `prod-debug`; la validación física final fue aprobada el 27 de agosto de 2026.
- UI v2, accesibilidad y release pertenecen a A7–A8. Copia/restauración fue
  retirada del MVP por ADR-005.

### A6 retirada y A7 completada

- ADR-005 retira A6 y G6 del MVP. La aplicación no crea copias ni reserva
  espacio para un historial de exportaciones.
- `/settings/appearance` es una ruta funcional con estados de carga, error y
  guardado para las cuatro preferencias visuales persistidas.
- La raíz observa Ajustes únicamente con la sesión desbloqueada. Texto grande
  garantiza al menos 1.3× y conserva una escala del sistema de 2.0×; reducir
  movimiento alimenta `MediaQuery.disableAnimations` y las animaciones
  Terminal consultan esa política.
- Alto contraste selecciona una paleta Terminal reforzada. Ocultar importes
  enmascara saldos, movimientos, presupuestos y métricas monetarias, y oscurece
  los campos de edición de importes.
- Ajustes usa una columna compacta/media, dos columnas desde 840 px, contenido
  limitado a 1120 px, controles de al menos 48 × 48 y semántica redundante.
- Tres goldens protegen compacto, expandido con alto contraste y compacto con
  texto 2.0×. Las guías Flutter de toque Android, etiquetado y contraste pasan;
  teléfono y tablet construyen la misma ruta y el mismo estado lógico.
- A7.3 incorpora `TerminalLoadingState` y `TerminalErrorState`, y convierte
  `TerminalEmptyState` en región viva. Misiones de hoy/colecciones/recurrencias,
  Economía resumen/movimientos/ahorros/análisis, Bitácora cronología/búsqueda/
  archivo/cierre y los tres dashboards comparten ahora el mismo patrón con
  reintento recuperable.
- Las pruebas verifican anuncio semántico de carga/vacío/error, entrada del
  reintento en el orden de foco y accesibilidad con texto 2.0×.
- A7.4 incorpora estados de página e internos en detalles y formularios de
  Misiones, Recurrencias, Economía y Bitácora. Acceso anuncia sus transiciones;
  el diálogo de perfil es desplazable y accesible en compacto con texto 2.0×.
- Los tres goldens canónicos existentes cubren las variantes contractuales; la
  auditoría no encontró necesario duplicarlos por cada ruta secundaria.
- `flutter analyze`: limpio; `flutter test`: **182/182**; `assembleProdDebug`:
  aprobado el 28 de agosto de 2026.
- El usuario aprobó el recorrido físico G7 el 28 de agosto de 2026. Este mensaje
  no volvió a especificar modelo ni versión Android; la referencia registrada
  en los gates físicos anteriores es una Redmi Pad 2. **A7 queda completada y
  G7 verde.**

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
| Decisiones | `documentos/DECISIONES_PRE_A0.md`, `ADR-001`, `ADR-002`, `ADR-003` | Son la fuente de verdad vigente |
| Esquema v1 | `lib/infrastructure/database/schema.drift` | Cambiarlo exige migración, snapshot y revisión de contrato |
| Código Drift generado | `lib/infrastructure/database/app_database.g.dart` | Se regenera; no se edita manualmente |
| Snapshots Drift | `drift_schemas/` | Evidencia y base de migraciones |
| Cifrado de base | `encrypted_database_connection.dart`, `DatabaseKeyStoreBridge.kt` | Una alteración puede volver ilegible o exponer la base |
| Credenciales | `features/access/domain`, `features/access/data`, `AccessCredentialStoreBridge.kt` | Lógica criptográfica y fail-closed |
| Sesión y privacidad | `access_session_controller.dart`, `privacy_controller.dart`, `privacy_boundary.dart` | Evitan reapertura tardía y exposición visual |
| Frontera de persistencia | `app/providers/persistence_providers.dart` | Impide abrir DAOs o base con sesión cerrada |
| Seguridad Android | `MainActivity.kt`, `PrivacyWindowBridge.kt`, `AndroidManifest.xml` | Keystore, biometría, `FLAG_SECURE` y `allowBackup=false` |

### Nivel 2 — Extender respetando contratos existentes

- `app/router/app_routes.dart`: conserva 56 patrones URI y sus parámetros
  permitidos. Las cinco rutas de datos/continuidad (`settingsData*`) se retiraron
  con A6 por ADR-005; no re-añadirlas sin reabrir ese ADR. Desde el refactor
  builder-por-contrato, cada `AppRouteContract` lleva su propia página en el
  campo `builder` (fuente única: ruta y página juntas) y `AppRoutes.all` pasó de
  `const` a `static final`. Añadir una ruta con página real es declarar su
  `builder` aquí; dejarlo en `null` la deja como superficie diferida al
  placeholder.
- `app/router/app_router.dart`: ya no despacha por nombre. Solo aplica lo
  transversal —`ProtectedRouteGate` + observer para rutas protegidas y
  construcción directa para las de acceso— y delega la hoja en
  `contract.builder` vía `_leafFor`. El `FeaturePlaceholderPage` es el fallback
  natural cuando falta `builder` o un parámetro obligatorio. No mover el guard
  ni el observer fuera de este envoltorio central.
- Guardarraíl anti-huérfanos: `test/app/router/app_routes_test.dart` fija el
  conjunto exacto de superficies diferidas sin `builder`. Una ruta funcional
  nueva sin página falla la prueba hasta reconocerla explícitamente.
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

Continuar A8 ejecutando `tool/gate_g8.ps1` con credenciales de firma y un
dispositivo ADB. La firma ya está configurada localmente; registrar métricas y completar
`documentos/A8-VALIDACION-RELEASE.md`. No cerrar G8 sin APK/AAB firmados,
regresión Android, smoke y matriz física. A6/G6 no forman parte del MVP.

---

## Registrado, pero todavía sin consumidor funcional

| Pieza | Situación actual | Destino previsto |
|---|---|---|
| `recurrenceDaoProvider` | Registrado y usado por `recurrenceRepositoryProvider` | A3 ✓ conectado |
| `notificationDaoProvider` | Consumido por el reconciliador Android post-commit | A3 ✓ conectado |
| `economyRepositoryProvider` | Consumido por providers, servicio, Inicio y UI de Economía | A4 ✓ conectado |
| `journalRepositoryProvider` | Entradas, fotos, búsqueda y archivo/restauración | A5.1–A5.3 ✓ conectado |
| `progressRepositoryProvider` | Dashboards reactivos, XP, niveles, títulos y rachas | A5 ✓ conectado |
| `settingsRepositoryProvider` | Preferencias reactivas en raíz y `/settings/appearance` | A7 ✓ conectado |
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

Preflight release A8:

```powershell
powershell -ExecutionPolicy Bypass -File tool/a8_preflight.ps1
```

Gate G8 completo (requiere firma y dispositivo dedicado):

```powershell
powershell -ExecutionPolicy Bypass -File tool/gate_g8.ps1 -DeviceId <serial-adb>
```

---

## Lista de lectura antes de cambiar arquitectura

1. Este documento.
2. `documentos/DECISIONES_PRE_A0.md`.
3. ADR-001 si se toca base, DAOs, cifrado, claves o esquema.
4. ADR-002 si se toca acceso, sesión, router protegido, autobloqueo o privacidad.
5. ADR-003 si se tocan títulos, rachas, niveles por área o sus reglas.
6. El documento fuente específico de UX, navegación o datos cuando se implemente una pantalla.

Si una pieza parece no usada, buscar referencias tanto en `lib/` como en `test/` e `integration_test/` y revisar su fase prevista antes de eliminarla.
