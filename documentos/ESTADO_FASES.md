# Bitácora RPG Personal — estado de fases

Última actualización: 24 de agosto de 2026

Este registro informa el avance; las decisiones de alcance y arquitectura viven en `DECISIONES_PRE_A0.md`. Una fase solo cambia a **completada** cuando toda su puerta de salida está en verde.

| Fase | Estado | Puerta |
| --- | --- | --- |
| A0 — Base del proyecto | **COMPLETADA** | G0 verde |
| A1 — Persistencia | **COMPLETADA** | G1 verde |
| A2 — Acceso y privacidad | **AUTORIZADA** | En espera de ejecución |
| A3 — Misiones | BLOQUEADA | Requiere G2 |
| A4 — Economía | BLOQUEADA | Requiere G3 |
| A5 — Bitácora y progreso | BLOQUEADA | Requiere G4 |
| A6 — Copia y restauración | BLOQUEADA | Requiere G5 |
| A7 — UI v2 y accesibilidad | BLOQUEADA | Requiere G6 |
| A8 — Release | BLOQUEADA | Requiere G7 |

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

No se implementaron PIN, biometría, sesión, guard de rutas ni privacy cover durante A1; comienzan en A2.
