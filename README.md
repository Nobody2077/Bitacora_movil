# Bitácora RPG Personal

Aplicación Android privada, local-first y sin dependencia de red para convertir la organización personal en un sistema RPG: misiones, tiempo, economía, Bitácora y progreso en un solo espacio.

El proyecto está construido con Flutter, Riverpod, GoRouter y Drift sobre una base SQLite cifrada. Los datos y las credenciales permanecen en el dispositivo; el acceso se protege con PIN, recuperación y biometría opcional.

> **Estado actual:** la base técnica, la persistencia cifrada y el acceso privado están terminados. La siguiente etapa es construir la experiencia funcional de Misiones. La mayoría de las rutas de negocio todavía muestran una pantalla temporal.

## Qué busca ofrecer

- Misiones únicas y recurrentes, objetivos, prioridades, importancia y cronómetro.
- Economía personal con movimientos, reservas y metas de ahorro.
- Bitácora vinculable con misiones y movimientos.
- XP, niveles y paneles diarios y semanales.
- Funcionamiento completamente local y adaptable a teléfono y tablet.
- PIN obligatorio, recuperación, biometría opcional, autobloqueo y protección de capturas.
- Base SQLite cifrada con claves protegidas por Android Keystore.

## Estado del desarrollo

| Fase | Estado | Resultado |
| --- | --- | --- |
| A0 — Base del proyecto | Completada | Flavors, tema, navegación, shell adaptable y arquitectura base |
| A1 — Persistencia | Completada | Drift v1, 19 tablas, DAOs, repositorios y SQLite cifrado |
| A2 — Acceso y privacidad | Completada | PIN, recuperación, biometría, guard global, autobloqueo y `FLAG_SECURE` |
| A3 — Misiones | Autorizada | Siguiente implementación: pantallas, controladores, tiempo, recurrencia y `CompleteMission` |
| A4–A8 | Pendientes | Economía, Bitácora/progreso, copias, UI final y release |

La capa visual disponible hoy cubre acceso, recuperación y ajustes de privacidad. De los 60 patrones de ruta registrados, 53 siguen conectados a `FeaturePlaceholderPage`; esto incluye Inicio y las superficies funcionales de Misiones, Bitácora, Economía y Dashboard.

Para conocer el punto exacto de continuación, las piezas protegidas y lo que aún no tiene consumidor en producción, leer [`ESTADO_ACTUAL.md`](ESTADO_ACTUAL.md).

## Arquitectura resumida

```text
lib/
├── app/                 bootstrap, configuración, providers, router y tema
├── core/                Result<T> y errores comunes
├── features/
│   ├── access/          acceso y privacidad implementados
│   ├── missions/        dominio y datos parciales; UI/application pendientes
│   ├── economy/         dominio y datos preparados para A4
│   ├── journal/         dominio y datos preparados para A5
│   ├── progress/        dominio y datos preparados para A5
│   └── settings/        preferencias y pantallas de privacidad
├── infrastructure/     Drift, esquema, DAOs, cifrado y seguridad
└── shared/              shell adaptable y widgets compartidos
```

La aplicación usa Clean Lite + feature-first. El dominio no depende de Flutter, Riverpod ni Drift; la UI no debe acceder directamente a los DAOs.

## Documentación para personas y agentes

Orden recomendado de lectura:

1. [`ESTADO_ACTUAL.md`](ESTADO_ACTUAL.md): relevo operativo y mapa de conexiones.
2. [`documentos/DECISIONES_PRE_A0.md`](documentos/DECISIONES_PRE_A0.md): decisiones vinculantes y secuencia A0–A8.
3. [`documentos/ADR-001-CONTRATO_PERSISTENCIA_V1.md`](documentos/ADR-001-CONTRATO_PERSISTENCIA_V1.md): persistencia y cifrado.
4. [`documentos/ADR-002-CONTRATO_ACCESO_PRIVACIDAD_V1.md`](documentos/ADR-002-CONTRATO_ACCESO_PRIVACIDAD_V1.md): acceso y privacidad.
5. [`documentos/ESTADO_FASES.md`](documentos/ESTADO_FASES.md): evidencia de gates completados.
6. [`documentos/`](documentos/): especificación, UML, diseño, navegación y arquitectura originales.

Cuando un documento fuente contradiga una decisión posterior, prevalecen `DECISIONES_PRE_A0.md` y los ADR aplicables.

## Requisitos

- Flutter 3.41.5 stable.
- Dart 3.11.3.
- JDK 17.
- Android SDK con API 24 o superior.
- Emulador o dispositivo Android para ejecutar los plugins de Keystore y biometría.

Las versiones de paquetes están fijadas en [`pubspec.yaml`](pubspec.yaml) y `pubspec.lock`.

## Ejecutar

```powershell
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart
```

Producción local:

```powershell
flutter run --flavor prod -t lib/main_prod.dart
```

## Generar APK

```powershell
flutter build apk --debug --flavor dev -t lib/main_dev.dart
flutter build apk --debug --flavor prod -t lib/main_prod.dart
```

Hay APK debug dev y prod almacenados localmente bajo `build/app/outputs/`. Pesan aproximadamente 201 MiB cada uno. `build/` está ignorado por Git y esos binarios superan el límite de 100 MiB para archivos normales de GitHub; por eso no forman parte del repositorio. Sus rutas y hashes están registrados en [`ESTADO_ACTUAL.md`](ESTADO_ACTUAL.md#apk-almacenados-localmente).

Si se necesita distribuirlos, deben publicarse como assets de una GitHub Release o regenerarse con separación por ABI; no deben añadirse a Git mediante `force-add`.

## Verificación disponible

Análisis estático rápido:

```powershell
flutter analyze
```

Verificación completa existente:

```powershell
powershell -ExecutionPolicy Bypass -File tool/quality.ps1
```

Gate Android de acceso y privacidad:

```powershell
powershell -ExecutionPolicy Bypass -File tool/gate_g2.ps1 -DeviceId emulator-5554
```

La prioridad actual es avanzar la aplicación funcional. Las pruebas existentes se conservan como red de seguridad y las verificaciones deben ser proporcionales al cambio.

## Repositorio

[github.com/Nobody2077/Bitacora_movil](https://github.com/Nobody2077/Bitacora_movil)
