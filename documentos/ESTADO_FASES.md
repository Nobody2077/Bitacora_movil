# Bitácora RPG Personal — estado de fases

Última actualización: 27 de agosto de 2026

Este registro informa el avance; las decisiones de alcance y arquitectura viven en `DECISIONES_PRE_A0.md`. Una fase solo cambia a **completada** cuando toda su puerta de salida está en verde.

| Fase | Estado | Puerta |
| --- | --- | --- |
| A0 — Base del proyecto | **COMPLETADA** | G0 verde |
| A1 — Persistencia | **COMPLETADA** | G1 verde |
| A2 — Acceso y privacidad | **COMPLETADA** | G2 verde |
| A3 — Misiones | **COMPLETADA** | G3 verde el 26 de agosto de 2026 |
| A4 — Economía | **COMPLETADA** | G4 verde el 27 de agosto de 2026 |
| A5 — Bitácora y progreso | **EN DESARROLLO** | **A5.1–A5.3 cerradas y aprobadas físicamente (27 ago)**; cierre diario y dashboards funcionales; resta consolidar Progreso y cerrar G5 |
| A6 — Copia y restauración | BLOQUEADA | Requiere G5 |
| A7 — UI v2 y accesibilidad | BLOQUEADA | Requiere G6 |
| A8 — Release | BLOQUEADA | Requiere G7 |

## Evidencia G3 — A3 completada

- Lista de hoy, creación, edición y detalle conectados a la persistencia cifrada.
- Flujo de planificación encadenado: crear vuelve a la lista actualizada y detalle/cronómetro permiten crear otra misión sin cerrar la anterior.
- Pantallas reactivas de Próximas desde mañana y Todas las misiones no archivadas, conectadas a sus rutas canónicas.
- Plantillas y recurrencias conectadas y probadas: dominio, repositorio,
  servicio, formulario, lista, rutas y generación post-unlock. La ventana usa
  exactamente 30 fechas civiles, los intervalos permanecen anclados en la fecha
  inicial, la zona IANA se resuelve en Android y la edición del agregado es
  atómica.
- Cronómetro por timestamps con inicio, pausa, reanudación y recuperación después de cerrar la app.
- Transiciones, segmentos de tiempo y eventos escritos atómicamente con `row_version`.
- Regla de un solo cronómetro activo validada dentro de la transacción.
- Cambio atómico entre cronómetros conectado a su ruta canónica, con pausa e inicio/reanudación en una única transacción.
- Barra global del cronómetro en todos los módulos protegidos, con tiempo por timestamp y acciones para abrir o pausar.
- `flutter analyze` y `assembleDevDebug`: aprobados después de integrar la barra global el 26 de agosto de 2026.
- `flutter analyze` y `assembleDevDebug`: aprobados después de mejorar el flujo de creación encadenada el 26 de agosto de 2026.

- Refresco visual limitado al primer plano; no se usa servicio Android permanente.
- `CompleteMission` coordina misión, tiempo, objetivos, evento, XP, Bitácora, economía opcional y avisos en una sola transacción.
- Revisión completa/parcial y resultado conectados a las rutas canónicas.
- Calendario mensual conectado a su ruta canónica, con rango UTC derivado del
  mes local, agrupación por día, agenda y acceso al detalle.
- Cierre parcial con XP manual entre 0 y el planificado, validado antes de la
  unidad de trabajo y persistido atómicamente en ledger XP, snapshot de evento
  y recibo.
- El campo “¿Qué resultado obtuviste?” es opcional. Si queda vacío, misión y
  Bitácora conservan `NULL`; el límite de 2000 caracteres sigue validado.
- Corrección posterior a G3: el detalle incorpora archivado lógico confirmado.
  Misión, evento `ARCHIVED` y cancelación de avisos se confirman en una sola
  transacción; no se borra historia y una misión con cronómetro activo se rechaza.
- Cada misión manual o recurrente registra una intención `START` junto con su
  agregado dentro de la misma transacción Drift.
- Reconciliador post-commit conectado al desbloqueo, guardado, recurrencias y
  cierre de misión. Programa alarmas Android, dispara vencidas sin duplicar,
  cancela las obsoletas y respeta preferencia, sonido y permiso Android 13+.
- Los avisos usan contenido genérico y visibilidad privada; no exponen títulos,
  notas, importes ni identificadores en la pantalla bloqueada.
- Tres pruebas específicas cubren programación/disparo/cancelación, preferencia
  desactivada y permiso denegado. Otra prueba comprueba rollback conjunto de
  misión, objetivos, evento e intención de notificación.
- `tool/quality.ps1`: formato, generación Drift, `flutter analyze` y 113 pruebas
  aprobados el 26 de agosto de 2026.
- `assembleDevDebug` y `assembleProdDebug`: compilados correctamente el 26 de
  agosto de 2026.
- APK `devDebug` compilada, instalada y abierta manualmente en una Redmi Pad 2. ADB aún no detecta el dispositivo USB para instalaciones desde la terminal.

## Cierre físico de G3

El usuario aprobó la validación física completa el 26 de agosto de 2026. La
evidencia visual confirma una notificación recibida en la pantalla bloqueada de
la Redmi Pad con el texto genérico “Tienes una misión programada.”, sin título,
notas, importes ni detalles privados. El primer intento sin aviso quedó resuelto
al repetir la prueba con las condiciones Android correctas.

G3 queda **VERDE**. A4 — Economía pasa a ser la única fase autorizada; A5
permanece bloqueada hasta completar G4.

## Evidencia G4 — A4 completada

- Dominio tipado para movimientos, medios de pago, metas y asignaciones.
- Repositorio y DAO conectan ledger reactivo, totales por periodo, balance
  derivado, metas y reservas sin crear saldos paralelos.
- Servicio de aplicación valida ingresos, gastos, ajustes, anulaciones
  compensatorias, corrección atómica, metas y reserva/liberación de fondos.
- Providers Riverpod exponen resumen, ledger, detalle y metas a la UI real.
- Las anulaciones conservan el movimiento original y escriben una compensación;
  las reservas se derivan de asignaciones y no permiten liberar de más.
- `flutter analyze`: cero problemas el 27 de agosto de 2026.
- Corrección atómica: original, compensación y reemplazo se confirman o revierten
  como una sola operación.
- Reserva protegida por objetivo y saldo disponible tanto en aplicación como
  dentro de la transacción SQLite.
- Una meta pasa automáticamente a `ACHIEVED` al completar el objetivo y vuelve
  a `ACTIVE` si se liberan fondos; una meta pausada no admite nuevas reservas.
- Resumen, historial, ingreso, gasto, ajuste, detalle, corrección, anulación,
  análisis, metas y reservas conectados a las rutas canónicas de Economía.
- Inicio muestra el saldo disponible real y accesos de gasto/ingreso.
- Verificación posterior del perfil/barra lateral: `flutter analyze` y 125
  pruebas aprobados el 27 de agosto de 2026.
- `assembleDevDebug` y `assembleProdDebug`: compilados correctamente el 27 de
  agosto de 2026.
- Ajuste transversal aprobado en código: barra lateral de tablet con destinos
  inactivos rojos, selección cian, tipografía ampliada y perfil local editable.
  El nombre vive en la base cifrada y la foto se copia al almacenamiento privado
  mediante el selector del sistema; no hubo migración del esquema v1.
- `assembleProdDebug` volvió a aprobar después de integrar el perfil y
  `image_picker`.
- El usuario aprobó físicamente el 27 de agosto de 2026 el funcionamiento y la
  persistencia de Economía, perfil y las demás funciones del incremento después
  de salir y volver a entrar en la aplicación.

G4 queda **VERDE**. A5 — Bitácora y progreso pasa a ser la única fase
autorizada; A6 permanece bloqueada hasta completar G5.

## Evidencia parcial A5 — Bitácora funcional y fotografías privadas

- `JournalRepository` amplió su contrato con cronología reactiva y comandos de
  creación/edición, sin exponer DataClass de Drift.
- `JournalApplicationService` valida títulos, UTC, privacidad, procedencia y
  vínculos opcionales con una misión o un movimiento existente.
- Crear y editar usan `JournalDao` y la base cifrada v1; no se modificó el
  esquema ni fue necesaria una migración.
- Una entrada vinculada conserva `origin_type` aunque la FK pase a `NULL`, y su
  contenido permanece editable como exige ADR-001.
- `/journal` muestra cronología por día, navegación anterior/hoy/siguiente,
  resumen de entradas, cantidad vinculada y estado dominante del día.
- `/journal/new`, `/journal/:entryId/edit` y `/journal/:entryId` están conectadas
  a formulario y detalle reales. El detalle permite abrir la misión o el
  movimiento fuente cuando todavía existe.
- El formulario cubre título, contenido, estado `FOCUSED`/`NORMAL`/`TIRED`,
  privacidad, fecha/hora y vínculo opcional. La procedencia se vuelve histórica
  e inmutable después de crear.
- `flutter analyze`: cero problemas; `flutter test`: 133 pruebas aprobadas.
- `assembleProdDebug`: compilada correctamente el 27 de agosto de 2026.
- El usuario aprobó físicamente A5.1 el 27 de agosto de 2026: cronología, alta,
  edición, detalle, vínculos y persistencia funcionan correctamente.
- El usuario aprobó físicamente A5.2 el 27 de agosto de 2026: agregar, abrir,
  persistir y retirar fotografías funciona correctamente en la tablet.
- **El usuario aprobó físicamente A5.3 el 27 de agosto de 2026**: búsqueda por texto/rango/foto, archivo/restauración, cierre diario (métricas + reflexión) y dashboards (Diario, Semanal, Progreso/Nivel RPG) funcionan correctamente en la Redmi Pad 2.
- A5.3 conecta las rutas canónicas `NAV-BIT-04 /journal/search` y
  `NAV-BIT-06 /journal/archive` con pantallas reales sobre Terminal V2.
- La búsqueda consulta SQLite por texto literal en título/cuerpo, rango civil,
  procedencias y adjuntos activos; conserva orden cronológico y limita a 200
  resultados. Los caracteres `%`, `_` y `\` se escapan antes de `LIKE`.
- Archivar usa `journal_entries.archived_at`: excluye la entrada de cronología y
  búsqueda sin borrar vínculos ni fotografías. Archivo permite ver y restaurar;
  el detalle archivado es de solo lectura.
- Cierre diario (`/journal/daily-close/:date`) muestra resumen operativo (XP, tiempo, misiones, balance económico, área destacada), lista de completadas/pendientes obligatorias y panel de reflexión editable (4000 chars) persistido en Bitácora como entrada `SYSTEM`.
- Dashboards implementados y validados:
  - **Diario** (`/dashboard/daily`): selector de día, tarjeta nivel RPG, métricas del día, botón "Cierre del día" navega a cierre diario.
  - **Semanal** (`/dashboard/weekly`): selector de semana, XP semanal, misiones logradas, tiempo enfocado, balance semanal, distribución de XP por área.
  - **Progreso / Nivel RPG** (`/dashboard/progress`): XP total/hoy/semana, progreso de nivel actual, distribución histórica por área.
- Pruebas nuevas verifican filtros combinados, texto literal, adjuntos,
  exclusión de cronología, stream de archivo, restauración, cierre diario, dashboards y rutas reales.
- `dart format --set-exit-if-changed`: aprobado sobre `lib`, `test` e
  `integration_test`.
- `flutter analyze`: cero problemas; `flutter test`: 158 pruebas aprobadas.
- `assembleProdDebug`: compilada correctamente con A5.3, cierre diario y
  dashboards el 27 de agosto de 2026.
- **A5.3 validada físicamente**. XP, niveles y distribución por áreas ya tienen consumidor funcional. Restante para cerrar G5: decidir y conectar el alcance de títulos/rachas, ejecutar la matriz final y cerrar el gate.

## Evidencia G0

- Flutter 3.41.5 stable y Dart 3.11.3, fijados en `pubspec.yaml`.
- Proyecto Android/Kotlin con flavors `dev` y `prod`.
- ProviderScope raíz y entornos inyectados.
- tema oscuro y tokens de la dirección “Terminal funcional reforzada”.
- GoRouter con 60 patrones URI canónicos, seis ramas de dominio y `/more` técnico.
- shell adaptable probado en `412×915` y `1280×800`.
- jerarquía tipada `AppFailure` y `Result<T>`.
- `dart format --set-exit-if-changed`: aprobado.
- `flutter analyze`: cero problemas.
- `flutter test`: 8 pruebas aprobadas.
- `app-dev-debug.apk`: compilado.
- `app-prod-debug.apk`: compilado.
- flavor `dev`: instalado y abierto en el emulador Android Pixel 5; `/home` visible y arranque sin errores Flutter ni excepciones fatales.
- `android:allowBackup="false"`: aplicado.
- firma release debug: prohibida y no configurada.

## Evidencia G1

- `ADR-001-CONTRATO_PERSISTENCIA_V1.md`: contrato cerrado antes del snapshot.
- matriz A1 exacta, sin `dependency_overrides` ni generadores Riverpod incompatibles.
- Drift v1: 19 tablas, 21 índices explícitos y 19 claves foráneas.
- instantes UTC en epoch milisegundos, enums ASCII mayúscula y constraints cerrados.
- seeds idempotentes: cinco áreas, settings singleton y tres metadatos de esquema.
- `drift_schema_v1.json` oficial y comparación automática contra todo el SQL creado.
- Android 7/API 24 mínimo efectivo por Flutter 3.41.5.
- SQLite3MultipleCiphers ChaCha20 con clave aleatoria de 256 bits.
- clave SQLite envuelta por AES-256-GCM no exportable en AndroidKeyStore; fail-closed, sin reset automático.
- siete DAOs con unidades atómicas, idempotencia, `row_version`, reservas y reversión compensatoria.
- repositorios y mappers no exponen DataClass; dominio sin imports de Flutter, Riverpod o Drift.
- providers sustituibles comparten una sola `AppDatabase` y la cierran al descartar el contenedor.
- `GoldenScenario.standard`: misiones, Bitácora, economía, reserva y XP verificados.
- `dart format`: 61 archivos sin cambios pendientes.
- `flutter analyze`: cero problemas.
- `flutter test`: 41 pruebas aprobadas.
- integración Android API 34/dev: cifrado, reapertura, clave errónea sin mutación y pérdida de clave aprobados.
- `app-dev-debug.apk`: compilado.
- `app-prod-debug.apk`: compilado.

A2 no implementó lógica de Misiones; ese dominio comienza únicamente en A3.

## Evidencia G2

- `ADR-002-CONTRATO_ACCESO_PRIVACIDAD_V1.md`: contrato cerrado antes de implementar A2.
- PIN obligatorio de seis dígitos y recuperación Crockford Base32 de 160 bits, protegidos con PBKDF2-HMAC-SHA256 de 600.000 iteraciones, salts independientes y comparación constante.
- estado de acceso cifrado mediante AES-256-GCM con alias AndroidKeyStore independiente; corrupción, alias ausente y estado ausente con base existente fallan cerrados.
- espera progresiva compartida y persistente para PIN y recuperación, sin borrado automático.
- biometría opcional y exclusivamente biométrica; el PIN propio permanece como fallback y recuperación.
- sesión cerrada por defecto, commits asíncronos cercados por epoch/revisión y resultados tardíos incapaces de reabrir la app.
- base inaccesible antes de desbloquear y cierre de la `AppDatabase` cifrada ya abierta comprobado al bloquear en Android.
- guard global y defensa en profundidad: ningún builder protegido, DAO, repositorio ni watch se construye con la sesión cerrada.
- destino pendiente validado contra catálogo, sin query ni fragmento, redactado y consumido una sola vez.
- autobloqueo exacto en `timeout - 1`, `timeout` y `timeout + 1`; opciones persistibles limitadas a 0, 1, 5 y 15 minutos.
- política aún no cargada o inválida falla segura con bloqueo inmediato; cubierta opaca desde el primer frame y ante pausa previa al primer post-frame.
- Android API 34/dev: `FLAG_SECURE`, `FlutterFragmentActivity`, Keystore y biometría aprobados.
- reinicio real Android automatizado: estado cifrado sembrado, PID terminado con `adb force-stop`, ausencia del PID confirmada y nuevo proceso iniciado en `locked`; desbloqueo posterior con PIN válido aprobado.
- diagnósticos completos de GoRouter desactivados en dev y prod para no registrar locations sensibles.
- regresión cifrada G1 aprobada, incluida clave errónea sin mutación y pérdida de clave fail-closed.
- `dart format`: 106 archivos sin cambios.
- `flutter analyze`: cero problemas.
- `flutter test`: 101 pruebas aprobadas.
- integración Android: 2 pruebas de persistencia cifrada, 1 de seguridad nativa y 2 etapas de reinicio aprobadas.
- `app-dev-debug.apk` y `app-prod-debug.apk`: compiladas.
- `tool/gate_g2.ps1 -DeviceId emulator-5554`: aprobado de extremo a extremo el 25 de agosto de 2026.
