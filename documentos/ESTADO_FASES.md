# Bitácora RPG Personal — estado de fases

Última actualización: 7 de septiembre de 2026

Este registro informa el avance; las decisiones de alcance y arquitectura viven en `DECISIONES_PRE_A0.md`. Una fase solo cambia a **completada** cuando toda su puerta de salida está en verde.

| Fase | Estado | Puerta |
| --- | --- | --- |
| A0 — Base del proyecto | **COMPLETADA** | G0 verde |
| A1 — Persistencia | **COMPLETADA** | G1 verde |
| A2 — Acceso y privacidad | **COMPLETADA** | G2 verde |
| A3 — Misiones | **COMPLETADA** | G3 verde el 26 de agosto de 2026 |
| A4 — Economía | **COMPLETADA** | G4 verde el 27 de agosto de 2026 |
| A5 — Bitácora y progreso | **COMPLETADA** | G5 verde el 27 de agosto de 2026 |
| A6 — Copia y restauración | **RETIRADA DEL MVP** | G6 retirada / no aplica; ADR-005 |
| A7 — UI v2 y accesibilidad | **COMPLETADA** | G7 verde el 28 de agosto de 2026 |
| A8 — Release | **EN PROGRESO** | Preflight verde; G8 pendiente |
| A9 — Calendario y recordatorios | **PARCIAL** | El calendario y las recurrencias quedaron aprobados físicamente con `1.2.1+6` el 6 de septiembre de 2026. Los recordatorios se separaron a A11 y siguen abiertos: G9 no se cierra hasta que A11 esté verde |
| A10 — Tablón de misiones | **COMPLETADA** | Recorrido físico de `1.2.1+6` cerrado y aprobado por el usuario el 6 de septiembre de 2026 |
| A11 — Notificaciones | **EN PROGRESO** | Punto 1 validado con `1.3.0+7`; puntos 2, 3 y 4 implementados y a validar juntos con `1.4.0+8` |

## A11 — Notificaciones: los cuatro puntos pactados

Orden acordado con el usuario. Cada punto se cierra antes de abrir el siguiente.

| Punto | Estado | Detalle |
| --- | --- | --- |
| 1. Reponer alarmas tras reinicio | **COMPLETADO** | `RECEIVE_BOOT_COMPLETED`, `BootAlarmRestoreReceiver` y espejo cifrado fuera de la base (Opción A). Validado en dispositivo el 7 de septiembre de 2026 con `1.3.0+7`: misión a las 10:00, reinicio a las 9:30, aviso recibido a las ~9:47 sin abrir la aplicación, y con texto genérico pese a tener «mostrar detalles» activado |
| 2. Resumen diario configurable | **IMPLEMENTADO, SIN VALIDAR** | Vive fuera de `notification_schedules`, en las preferencias cifradas de A9.1. El esquema v3 no se toca. Interruptor y hora propios en Ajustes; recuento precalculado con la app desbloqueada. 230 pruebas verdes |
| 3. Aviso de vencimiento | **IMPLEMENTADO, SIN VALIDAR** | Usa `CRITICAL`, que el `CHECK` ya admitía: sin migración. Solo para misiones con hora y vencimiento real; las de solo fecha se excluyen porque su `expiresAt` es el final del día |
| 4. Texto personalizable | **IMPLEMENTADO, SIN VALIDAR** | El texto se cocina en Dart y viaja por el canal; configurable en Ajustes. La constante de Kotlin queda como red de seguridad |

**Restricciones que no se negocian en A11:**

- Alarmas exactas descartadas por consumo de batería, a petición del usuario. Se mantiene `setAndAllowWhileIdle`.
- El receiver nunca abre la base cifrada (ADR-002).
- El texto en pantalla bloqueada respeta «mostrar detalles».

## Alcance post-MVP acordado el 7 de septiembre de 2026

`DECISIONES_PRE_A0.md` dejaba fuera del MVP «Personajes, Tienda, Inventario, loadouts, servidor y sincronización». El usuario **redujo esa lista el 7 de septiembre de 2026**: quiere **Personajes, Tienda e Inventario**, y solo eso. Loadouts, servidor y sincronización quedan descartados, no aplazados.

No se abre hasta cerrar A11 y A8. Cuando se abra necesitará su propio ADR: no hay tablas de tienda ni inventario en el esquema, así que implica migración v3 → v4, y hay una decisión de diseño pendiente sobre con qué se paga (XP ganado en misiones frente al dinero real de `transactions`).

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
  inactivos rojos, selección amarilla, tipografía ampliada y perfil local editable.
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
- **A5.3 validada físicamente**. La ampliación final de Progreso conecta el
  alcance de títulos/rachas y niveles por área sin cambiar el esquema v1.

## Evidencia técnica final A5 / G5

- `ADR-003-CONTRATO_TITULOS_RACHAS_V1.md` fija las reglas canónicas y deja los
  títulos temporales sin seed hasta disponer de períodos configurables.
- El seed v1 incorpora idempotentemente `Centinela del hogar` (100 misiones de
  Hogar, permanente) y `Ritmo constante` (racha diaria de 7 días, dinámico).
- El servicio de Progreso evalúa días civiles locales, conserva mejor racha,
  desactiva el título dinámico y registra recuperaciones sin reducir XP.
- El Dashboard semanal muestra racha actual y mejor racha. Progreso muestra
  niveles independientes por área y títulos vigentes.
- Los providers escuchan cambios de las tablas fuente y recalculan los read
  models sin reconstrucción global.
- Las pruebas nuevas cubren seed idempotente, nivel por área, activación,
  pérdida, recuperación, permanencia y refresco reactivo.
- `dart format --set-exit-if-changed`: 193 archivos, sin cambios pendientes.
- `flutter analyze`: cero problemas.
- `flutter test`: **161/161 pruebas aprobadas**.
- `assembleProdDebug`: APK compilada correctamente el 27 de agosto de 2026.
- El usuario aprobó físicamente títulos, rachas y niveles por área el 27 de
  agosto de 2026. **A5 queda completada y G5 queda verde.**

## Retiro de A6 y evidencia técnica A7

- `ADR-005-RETIRO-A6-MVP.md` registra la decisión explícita de retirar A6 del
  MVP. G6 deja de aplicar y A8 queda condicionada únicamente a G7.
- `/settings/appearance` dejó de ser placeholder y persiste Texto grande,
  Reducir movimiento, Alto contraste y Ocultar importes.
- La raíz observa los ajustes solo con sesión desbloqueada y aplica texto de
  al menos 1.3× conservando escalas del sistema de 2.0×, movimiento reducido y
  paleta reforzada de alto contraste.
- Los importes monetarios se enmascaran en Economía, Inicio, Bitácora, Progreso
  y Misiones; los campos de edición monetaria usan ocultación visual.
- Ajustes usa composición Terminal V2 adaptable y controles con objetivo táctil
  mínimo de 48 × 48, semántica de estado y estados de carga/error/guardado.
- A7.2 fija una columna entre compacto y medio y dos columnas desde 840 px, con
  ancho de lectura máximo de 1120 px y equivalencia lógica de ruta entre phone
  y tablet.
- Tres goldens canónicos cubren compacto, expandido con alto contraste y texto
  2.0×. Las guías automáticas de toque Android, etiquetado y contraste pasan.
- A7.3 centraliza carga y error/reintento, y añade anuncio de región viva al
  estado vacío. El reintento entra en el orden de foco y los tres estados pasan
  accesibilidad automática con texto 2.0×.
- El patrón compartido ya se usa en las rutas principales de Misiones,
  Recurrencias, Economía, Bitácora y Progreso.
- A7.4 extiende estados de página e internos a detalles y formularios de
  Misiones, Recurrencias, Economía y Bitácora, incluido calendario, fuentes
  vinculadas y fotografías privadas.
- Las transiciones de Acceso tienen mensajes anunciables. El diálogo de perfil
  es desplazable y pasa su variante compacta con texto 2.0×.
- Los tres goldens canónicos existentes cubren compacto, expandido/alto
  contraste y texto 2.0×; la auditoría secundaria no exige duplicarlos por ruta.
- `flutter analyze`: cero problemas.
- `flutter test`: **182/182 pruebas aprobadas**.
- `assembleProdDebug`: APK compilada correctamente el 28 de agosto de 2026.
- El usuario aprobó el recorrido físico el 28 de agosto de 2026. Este mensaje no
  volvió a especificar modelo ni versión Android; la referencia de los gates
  físicos anteriores es una Redmi Pad 2. No declaró bloqueos.
- **A7 queda completada y G7 queda verde. A8 está autorizada.**

## Evidencia parcial A8 — hardening y preflight release

- Versión candidata fijada en `1.0.0+2`; esquema Drift y espejo de metadata
  permanecen explícitamente en v1.
- Firma release configurable por archivo privado ignorado o variables de
  entorno. Una tarea APK/AAB release sin las cuatro credenciales falla y nunca
  reutiliza la llave debug.
- El flavor `prod` rechaza tráfico claro y no solicita `INTERNET`.
- Backup, extracción cloud y transferencia dispositivo a dispositivo excluyen
  todos los dominios de datos, además de `allowBackup=false`.
- Core library desugaring protege el uso de `java.time` en Android API 24–25;
  este defecto fue descubierto por Lint release durante A8.
- Una regresión `EXPLAIN QUERY PLAN` exige índices para Misiones, Economía,
  Bitácora y XP; aprobada el 28 de agosto de 2026.
- Formato: 202 archivos sin cambios; `flutter analyze`: cero problemas;
  `flutter test`: **183/183 pruebas aprobadas**; `lintProdRelease`: aprobado sin
  errores; APK `prod-debug`: compilada correctamente.
- `tool/a8_preflight.ps1` automatiza versionado, hardening, logs, calidad y
  Lint. `tool/gate_g8.ps1` añade regresión Android, métricas cifradas sobre
  1.000 misiones/5.000 movimientos, APK/AAB, firma, permisos, hashes y smoke.
- El usuario aprobó físicamente la APK `prod-debug` actual el 28 de agosto de
  2026 y autorizó eliminar sus datos para probar la firma real desde cero.
- Llave release permanente RSA-4096 creada fuera del repositorio. Certificado
  SHA-256: `a6092c6c05727240487247f71ecedee1ecc4d8ed0d61775d014e6512a4d116b8`.
- APK release `1.0.0+1`: 71.937.139 bytes, firma v2 válida, sin `INTERNET`,
  SHA-256 `63af346221f2ac62fcb7c51f6fd3f0b8610089abfb262043b0ec70fcbd078f82`.
- AAB release `1.0.0+1`: 55.545.407 bytes, firma JAR verificada, SHA-256
  `856b895b0306c12305568ee0143110d661c3a90fdf0957c6b0f2dce02d0d3bbe`.
- El usuario desinstaló la variante debug, instaló desde cero la release
  `1.0.0+1` y confirmó que todo funciona correctamente.
- APK release `1.0.0+2`: 71.937.139 bytes, firma v2 válida con el mismo
  certificado, sin `INTERNET`, SHA-256
  `37c4163bf8350ae94bf8f3e8aa77faca0b12eb4fb7a4fa72db61e35deabfb50f`.
- AAB release `1.0.0+2`: 55.545.412 bytes, firma JAR verificada, SHA-256
  `317a503b57982fdfacb52cd47befb8831462920d0bad96153b19edb84ae60ae9`.
- El usuario instaló `1.0.0+2` encima de `1.0.0+1` y confirmó que todo funciona,
  sin reportar pérdida de datos. La actualización con la misma firma queda
  aprobada. La conexión USB no está disponible.
- Pendiente: respaldo externo de llave/credenciales, métricas físicas mediante
  ADB inalámbrico u otro dispositivo accesible y cierre documental. **A8 y G8
  no están cerradas.**

## Evidencia parcial A9 — calendario y recordatorios

- Candidata instalada `1.1.1+4`; el checkpoint A9 usaba esquema v2 con
  migración compatible desde v1. La candidata posterior `1.2.0+5` incorpora
  esquema v3 y el tablón de misiones.
- Calendario reactivo con vistas Día, Semana y Mes y rangos civiles locales.
- Crear desde el calendario precarga la fecha elegida y vuelve al mismo día.
- Ajustes > Notificaciones ya es funcional: activación, sonido, anticipación de
  0/5/15/30/60 minutos y horario silencioso que puede cruzar medianoche.
- El aviso Android conserva por defecto texto genérico y visibilidad privada;
  una preferencia opcional permite mostrar únicamente el título.
- Las misiones admiten planificación sin fecha, con solo fecha o con fecha y
  hora. La categoría diaria crea una plantilla y sus ocurrencias cotidianas.
- Ajustes permite habilitar capturas, cámara al adjuntar imágenes y detalle en
  notificaciones; las tres opciones comienzan desactivadas.
- Bitácora ofrece ocho estados de ánimo y conserva los valores anteriores
  mediante la migración v1→v2.
- Preferencias nuevas persistidas en `schema_metadata` dentro de la base cifrada.
- `flutter analyze`: cero problemas; `flutter test`: **215/215 aprobadas** tras
  la extensión funcional del 29 de agosto.
- APK `1.1.0+3`: 71.986.819 bytes, firma v2 válida con el certificado de
  producción, sin `INTERNET`, SHA-256
  `47a068089aa7f2dcd48801e92f4e7f471c46b47ad84eade121687df03b891ef3`.
- AAB `1.1.0+3`: 55.605.200 bytes, firma JAR verificada, SHA-256
  `a9237ec6c7bbe6e4c1b921fe2de0c9eb03900e00f954b66745d4bf4acb1a5b5b`.
- APK `1.1.1+4`: 72.232.747 bytes, firma v2 válida con el mismo certificado de
  producción, sin `INTERNET`, SHA-256
  `4735193a6e574be1cca51a8ac39fb7ea843cf467f78c61e4bf35fbfe8a903313`.
- No se generó un AAB `1.1.1+4`; el bundle anterior precede los últimos ajustes
  visuales.
- Pendiente: recorrido físico de `A9-CALENDARIO-RECORDATORIOS.md`.
  **A9/G9 no están cerradas.**

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
