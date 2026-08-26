# Estado actual y guía de relevo

- Última revisión: **26 de agosto de 2026**
- Repositorio: [`Nobody2077/Bitacora_movil`](https://github.com/Nobody2077/Bitacora_movil)
- Rama de trabajo: `main`

Este documento permite que Claude Code, Antigravity, Codex u otro agente continúe el proyecto sin reconstruir su historia ni desmontar accidentalmente decisiones ya validadas.

## Resumen ejecutivo

- La aplicación es Flutter Android, local-first, privada y de un solo usuario.
- A0, A1 y A2 están completadas.
- A3 — Misiones está en desarrollo y sigue siendo la única fase de implementación inmediata.
- La infraestructura contiene el esquema completo v1 y DAOs adelantados para varias fases.
- Acceso, recuperación, biometría, privacidad y persistencia cifrada sí están conectados al arranque real.
- Misiones ya permite listar el día, crear, abrir, editar, iniciar, pausar y reanudar registros reales; Inicio, Bitácora, Economía y Dashboard todavía no tienen experiencia funcional.
- Existen 60 patrones de ruta; 12 producen pantallas específicas y 48 producen `FeaturePlaceholderPage`.
- `flutter analyze` y la compilación `devDebug` fueron ejecutados el 26 de agosto de 2026 y terminaron sin problemas.
- La prioridad del usuario es construir funcionalidad real. No se deben borrar las pruebas existentes, pero tampoco convertir cada avance en una fase dedicada únicamente a pruebas.

## Qué funciona actualmente

### Base de aplicación

- Entradas separadas `main_dev.dart` y `main_prod.dart`.
- `ProviderScope` raíz con entorno inyectado.
- Tema oscuro y shell adaptable para teléfono y tablet.
- GoRouter con seis ramas de dominio y una rama técnica `/more`.
- Localización española.
- `Result<T>` y jerarquía tipada de fallos.

### Persistencia

- Esquema Drift v1 de 19 tablas.
- 21 índices explícitos y 19 claves foráneas.
- Seeds iniciales idempotentes.
- DAOs para misiones, recurrencia, notificaciones, economía, Bitácora, progreso y ajustes.
- Repositorios Drift para Misiones, Economía, Bitácora, Progreso y Ajustes.
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

### Incrementos funcionales de Misiones

- Capa `application` con reloj e identificadores inyectables.
- Consulta reactiva de las misiones programadas para el día local.
- Lectura de áreas de vida desde los seeds de la base.
- Creación atómica de Mission, objetivos y evento `CREATED`.
- Edición atómica con `row_version`, reemplazo de objetivos y evento `UPDATED`.
- Pantallas adaptables de Misiones de hoy, nueva/editar y detalle.
- Componentes reutilizables de panel, botón, badge y métrica con geometría Terminal.
- Rutas reales conectadas sin debilitar el guard de acceso.
- Inicio, pausa y reanudación atómicos con eventos `STARTED`, `PAUSED` y `RESUMED`.
- Recuperación del cronómetro mediante timestamps persistidos, sin proceso permanente ni escrituras por segundo.
- Refresco visual cancelado cuando la app deja de estar visible.
- Regla global de un solo cronómetro activo validada dentro de la transacción.
- Pantalla adaptable de misión activa conectada a `/missions/:missionId/active`.

## Qué todavía no está implementado

### A3 — Misiones

Ya está conectado:

- `Mission`, `MissionObjective` y enums del dominio.
- `MissionMapper`.
- `MissionRepository` con lecturas, observación del día, áreas y escrituras.
- `MissionDao` con inserción de agregados, edición optimista, transiciones, eventos y tiempo.
- `RecurrenceDao` con plantillas, reglas y generación idempotente de apariciones.
- Lista de hoy, formulario crear/editar y detalle con datos cifrados reales.
- `NotificationDao` con agenda y transiciones de estado.

Falta:

- Flujo para cambiar desde una misión hacia el único cronómetro ya activo.
- Pantallas próximas, todas, calendario, recurrentes, revisión y resultado.
- `lib/app/application/commands/complete_mission.dart` y su unidad de trabajo Drift.
- Coordinación atómica de misión, tiempo, evento, XP, Bitácora y movimiento económico opcional.
- Reconciliador Android para notificaciones programadas.

### Fases posteriores

- Economía tiene modelo, repositorio y DAO, pero no UI ni controlador de producción.
- Bitácora tiene modelo, mapper, repositorio y DAO, pero no UI ni adjuntos funcionales.
- Progreso tiene modelo, repositorio y DAO, pero no Dashboard funcional.
- Copia/restauración, UI v2 final, accesibilidad completa y release pertenecen a A6–A8.

## Mapa de conexión en producción

```text
main_dev/main_prod
    └── bootstrap(AppEnvironment)
        └── ProviderScope
            └── BitacoraApp
                ├── appRouterProvider
                │   ├── accessSessionProvider
                │   ├── guard de rutas
                │   └── shell adaptable / Misiones reales / placeholders
                └── AppPrivacyBoundary
                    ├── auto-lock
                    ├── privacy cover
                    └── persistenceAccessGuardProvider
                        └── AppDatabase cifrada solo al desbloquear
```

Conexiones activas importantes:

- `settingsRepositoryProvider` alimenta las preferencias de privacidad.
- `accessSessionProvider` alimenta router, privacidad y frontera de persistencia.
- `appDatabaseProvider` se crea perezosamente y se invalida al bloquear.
- `missionRepositoryProvider` alimenta la lista, el detalle y las escrituras de Misiones mediante la capa `application`.
- Los bridges Kotlin conectan credenciales, clave de base y seguridad de ventana con Android.

## Registrado, pero todavía sin consumidor funcional

Estas piezas no deben borrarse solo porque hoy no aparecen en una pantalla. Son infraestructura preparada para las siguientes fases.

| Pieza | Situación actual | Destino previsto |
| --- | --- | --- |
| `recurrenceDaoProvider` | Solo registrado y comprobado por pruebas | A3 |
| `notificationDaoProvider` | Solo registrado y comprobado por pruebas | A3 |
| `economyRepositoryProvider` | Solo declaración en `lib` | A4 |
| `journalRepositoryProvider` | Solo declaración en `lib` | A5 |
| `progressRepositoryProvider` | Solo declaración en `lib` | A5 |
| Rutas de negocio con placeholder | Contrato de navegación ya congelado | A3–A7 |

No se encontraron archivos Dart aislados dentro de `lib`; los únicos archivos sin importador son `main.dart`, `main_dev.dart` y `main_prod.dart`, porque son puntos de entrada.

`drift_flutter` no se importa directamente en el código actual. Su permanencia está documentada en ADR-001 por la resolución nativa y las dependencias transitivas; no debe retirarse como una limpieza automática.

## Estructura que debe preservarse

### Nivel 1 — No modificar sin motivo contractual, corrección demostrada o migración

| Área | Rutas principales | Razón |
| --- | --- | --- |
| Decisiones | `documentos/DECISIONES_PRE_A0.md`, `ADR-001`, `ADR-002` | Son la fuente de verdad vigente |
| Esquema v1 | `lib/infrastructure/database/schema.drift` | Cambiarlo exige migración, snapshot y revisión de contrato |
| Código Drift generado | `lib/infrastructure/database/app_database.g.dart` | Se regenera; no se edita manualmente |
| Snapshots Drift | `drift_schemas/` | Evidencia y base de migraciones |
| Cifrado de base | `encrypted_database_connection.dart`, `DatabaseKeyStoreBridge.kt` | Una alteración puede volver ilegible o exponer la base |
| Credenciales | `features/access/domain`, `features/access/data`, `AccessCredentialStoreBridge.kt` | Lógica criptográfica y fail-closed |
| Sesión y privacidad | `access_session_controller.dart`, `privacy_controller.dart`, `privacy_boundary.dart` | Evitan reapertura tardía y exposición visual |
| Frontera de persistencia | `app/providers/persistence_providers.dart` | Impide abrir DAOs o base con sesión cerrada |
| Seguridad Android | `MainActivity.kt`, `PrivacyWindowBridge.kt`, `AndroidManifest.xml` | Keystore, biometría, `FLAG_SECURE` y `allowBackup=false` |

Si una tarea necesita revisar estas áreas, primero debe leer el ADR correspondiente y conservar el comportamiento fail-closed.

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
- APK dentro de `build/`: artefactos locales reproducibles.
- `.idea/`: configuración local ignorada.
- `.vscode/`: configuración compartida; revisar antes de cambiar.

Las carpetas `test/`, `integration_test/` y `tool/` no son código muerto. Contienen la evidencia de A0–A2 y deben conservarse aunque el foco inmediato esté en funcionalidad.

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

## Secuencia recomendada para continuar A3

1. Implementar revisión, resultado y `CompleteMission` como comando transaccional transversal.
2. Implementar cambio seguro hacia el único cronómetro activo y su acceso global.
3. Conectar plantillas y generación recurrente.
4. Implementar agenda/reconciliación de notificaciones.
5. Sustituir las rutas avanzadas de Misiones que aún usan placeholder.

El flujo base y el cronómetro persistente ya están conectados. El siguiente incremento debe cerrar la misión y coordinar tiempo, XP, Bitácora y economía sin saltar las garantías transaccionales.

## APK y artefactos locales

El 26 de agosto de 2026 se eliminaron cuatro APK debug reproducibles: dev y prod estaban duplicados entre las salidas de Flutter y Gradle. La limpieza liberó aproximadamente 804 MiB y no eliminó código fuente ni datos de la aplicación.

Después del incremento de cronómetro se compiló correctamente una APK `devDebug` como verificación. Las dos copias producidas por Flutter y Gradle se eliminaron al terminar; no se almacenan binarios de verificación.

Consideraciones:

- `build/` está excluido por `.gitignore`.
- No hay APK almacenados actualmente dentro del proyecto.
- No usar `git add -f` para incluirlos.
- Si se desea distribución desde GitHub, usar assets de una Release.
- Generar el APK únicamente cuando exista un commit que se quiera instalar o distribuir.

## Comandos operativos

Preparar dependencias:

```powershell
flutter pub get
```

Ejecutar desarrollo:

```powershell
flutter run --flavor dev -t lib/main_dev.dart
```

Análisis rápido:

```powershell
flutter analyze
```

Generar APK dev:

```powershell
flutter build apk --debug --flavor dev -t lib/main_dev.dart
```

Verificación completa ya disponible:

```powershell
powershell -ExecutionPolicy Bypass -File tool/quality.ps1
```

## Lista de lectura antes de cambiar arquitectura

1. Este documento.
2. `documentos/DECISIONES_PRE_A0.md`.
3. ADR-001 si se toca base, DAOs, cifrado, claves o esquema.
4. ADR-002 si se toca acceso, sesión, router protegido, autobloqueo o privacidad.
5. El documento fuente específico de UX, navegación o datos cuando se implemente una pantalla.

Si una pieza parece no usada, buscar referencias tanto en `lib/` como en `test/` e `integration_test/` y revisar su fase prevista antes de eliminarla.
