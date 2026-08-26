# Bitácora RPG Personal — estado de fases

Última actualización: 26 de agosto de 2026

Este registro informa el avance; las decisiones de alcance y arquitectura viven en `DECISIONES_PRE_A0.md`. Una fase solo cambia a **completada** cuando toda su puerta de salida está en verde.

| Fase | Estado | Puerta |
| --- | --- | --- |
| A0 — Base del proyecto | **COMPLETADA** | G0 verde |
| A1 — Persistencia | **COMPLETADA** | G1 verde |
| A2 — Acceso y privacidad | **COMPLETADA** | G2 verde |
| A3 — Misiones | **EN DESARROLLO** | Ciclo base y cierre transaccional implementados; G3 pendiente |
| A4 — Economía | BLOQUEADA | Requiere G3 |
| A5 — Bitácora y progreso | BLOQUEADA | Requiere G4 |
| A6 — Copia y restauración | BLOQUEADA | Requiere G5 |
| A7 — UI v2 y accesibilidad | BLOQUEADA | Requiere G6 |
| A8 — Release | BLOQUEADA | Requiere G7 |

## Evidencia A3 en desarrollo

- Lista de hoy, creación, edición y detalle conectados a la persistencia cifrada.
- Flujo de planificación encadenado: crear vuelve a la lista actualizada y detalle/cronómetro permiten crear otra misión sin cerrar la anterior.
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
- `flutter analyze`: cero problemas el 26 de agosto de 2026.
- `assembleDevDebug`: compilado correctamente el 26 de agosto de 2026.
- APK `devDebug` compilada, instalada y abierta manualmente en una Redmi Pad 2. ADB aún no detecta el dispositivo USB para instalaciones desde la terminal.

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
