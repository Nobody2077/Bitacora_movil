# Estado actual y guía de relevo

- Última revisión: **5 de octubre de 2026**
- Versión en `pubspec.yaml`: **`1.7.0+14`** (fase 1 de ADR-006), firmada y
  **aprobada en la tablet con datos reales** el 3 de octubre de 2026
- Repositorio: [`Nobody2077/Bitacora_movil`](https://github.com/Nobody2077/Bitacora_movil)
- Rama base: `main`, abierta en el worktree
  `G:\Desarrollo\Proyectos\bitacora-main-v3`. Cada fase sale de `main` en una
  rama nueva
- Pruebas: **356/356**, `flutter analyze` limpio (rama `feat/v4-fase2`)
- **Siguiente: fase 2 de ADR-006**, la Tienda (lista de deseos; ver D17)

Este documento guarda **solo lo vigente**, para que Claude Code u otro agente
continúe sin reconstruir la historia. La historia (cada sesión, relevos viejos,
razonamientos) está en `documentos/HISTORIAL-SESIONES.md`. Si algo de allí
contradice esto, manda esto.

---

## ▶ EMPEZAR AQUÍ

**Fase 2 de ADR-006: Tienda (lista de deseos), rehecha el 4 de octubre por
D17.** Ciberware, Inventario y Creación quedan fuera. Cada paso empieza con
una **mini-spec de 5–10 líneas** (qué hace, qué no, cómo se prueba, cuándo se
da por bueno) que el usuario aprueba **antes** de programar. Después:
pruebas, `dev` en la tablet, aprobación del usuario y commit.

0. ~~Rama y comprobaciones~~ **Hecho el 4 de octubre de 2026**: la rama
   `feat/v4-fase2` vive en la carpeta principal
   `G:\Desarrollo\Proyectos\Bicacora_movil` (el worktree de `main` sigue en
   `main`).
1. **Llave de firma: SIN RESPALDO** (verificado el 4 de octubre: solo está en
   el PC; ninguna copia en la tablet). El usuario no encuentra su pendrive y
   lo pospuso. **Obligatorio antes de instalar `1.8.0` en la prod**: dos
   copias (pendrive conectado al PC y nube con zip cifrado), comprobando la
   huella SHA-256 de cada una.
2. ~~Migración v5~~ **Hecho y aprobado el 5 de octubre de 2026**
   (`d66ac0a`): `area_id` opcional en `inventory_items` (FK a `life_areas`,
   `ON DELETE SET NULL`), snapshot `drift_schema_v5.json`, prueba v4 → v5.
   322/322. Ensayo en la tablet: `dev` v4 con datos → v5 desde Descargas
   (`adb install` falló otra vez), el usuario dijo «datos bien»; prod intacta
   en `1.7.0`.
3. ~~Datos~~ **Hecho el 5 de octubre de 2026** (mini-spec aprobada; sin
   instalación, no hay nada que ver). 346/346. Qué hay:
   - `WishDao` (`daos/wish_dao.dart`) sobre `inventory_items`: deseos
     activos (prioridad alta primero), archivados y comprados; crear
     idempotente por id, editar/archivar/restaurar con `row_version`.
   - `purchaseWish`: en una transacción escribe el gasto con
     `EconomyDao.writeTransaction` (idempotente por `operation_id`) y pasa
     el deseo a `OWNED`/`PURCHASE`. Repetir la misma operación devuelve lo
     existente; otro intento sobre un comprado o archivado se rechaza sin
     gasto; un fallo a mitad no deja nada.
   - `features/shop/`: `Wish` (tipo = categoría fija, da el icono; área
     opcional), `WishAffordability` (verde ≥ 100 %, ámbar ≥ 75 %, rojo, sin
     precio; contra `availableMinor`, sin metas), `DriftWishRepository`,
     `ShopApplicationService` (prioridad media por defecto; la compra va a
     Economía con categoría «Tienda» y el nombre como nota; no toca XP) y
     `shop_providers.dart`. `DriftEconomyRepository.ledgerInputOf` expone
     la traducción del gasto.
   - **Fuera de este paso:** anular el gasto en Economía no devuelve el
     deseo a la lista; `wish_goal_id` sin usar.
4. ~~Pantallas + animación del saldo~~ **Hecho y aprobado el 5 de octubre
   de 2026** («funciona bien», `dev` en la tablet desde Descargas). 356/356.
   Qué hay:
   - Pestañas **TIENDA · MAPA · PERSONAJE · DIARIO** (`CharacterTab.tienda`;
     `?tab=ciberware|inventario` ya no existen y abren PERSONAJE).
   - `features/shop/presentation/`: `ShopSection` (Deseos · Comprados ·
     Archivados y «Añadir deseo»), `WishCard` (icono Material por tipo,
     área, prioridad, precio y estado con color **y** texto; con importes
     ocultos la cifra sale tapada), `WishDetailPage`, `WishFormPage` y la
     ventana de compra (precio pagado y medio de pago).
   - Rutas `wishNew` (`/character/shop/new`), `wishDetail` y `wishEdit`:
     64 rutas.
   - Animación del saldo (D12): `purchaseFeedbackProvider` lleva la compra
     a `_AnimatedBalance` de la cabecera, que baja cifra a cifra en naranja
     con «− Bs X» flotando al volver a la Tienda; con movimiento reducido no
     anima.
5. **Avisos:** mensaje en la app cuando un movimiento deja un deseo al
   alcance y línea «N deseos a tu alcance» en el resumen diario (respeta
   «mostrar detalles»).
6. **☰ Barra lateral que se desliza** (ADR-006 D13): en tablet alterna
   expandida/oculta y se recuerda; en teléfono flota encima y se cierra al
   tocar fuera o con «atrás». Preferencia, no esquema.
7. **Tema Vino** (D13) en Ajustes → Apariencia, además del Negro. Alto
   contraste fuerza Negro; movimiento reducido quita las líneas de barrido.
   Medir antes el contraste del texto rojo sobre vino.
8. Versión `1.8.0`, APK release, instalación **encima** en la tablet y
   aprobación del usuario. **Antes, el respaldo de la llave (paso 1).**
   Después, fusionar la rama en `main`.

Referencias: `documentos/ADR-006-PERSONAJES-TIENDA-INVENTARIO.md` (es la spec
de la fase; no reabrir sus decisiones) y la maqueta privada «Bitácora ·
Personaje» v5 (solo orientativa; lo que contradiga a D17 no vale).

### Instalar en la tablet

Tablet Xiaomi `25040RP0AL`, HyperOS 3, serial `biuonrrcey45lvrs`. Es el
**dispositivo principal del usuario y tiene datos reales.** `adb` no está en el
PATH: `C:\Users\Usuario\AppData\Local\Android\Sdk\platform-tools\adb.exe`.

1. Intentar **una vez** `adb install -r <apk>`. Cada instalación pide
   confirmación en pantalla, que HyperOS cancela sola a los ~30 s: el usuario
   tiene que estar delante.
2. Si da `INSTALL_FAILED_USER_RESTRICTED` (lo habitual): `adb push` de la APK a
   `/sdcard/Download/`, avisar al escáner de medios
   (`adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Download/<nombre>.apk`),
   el usuario la instala desde el gestor de archivos, y borrar la APK después.
   En Git Bash, prefijar con `MSYS_NO_PATHCONV=1`.
3. Para probar un paso: flavor `dev` (`com.jcyq.bitacorarpg.dev`), que convive
   con la prod. Comprobar después con `adb shell pm path com.jcyq.bitacorarpg`
   que la prod sigue ahí.

### Pendientes del usuario

- **Respaldar la llave de firma. Es lo único irreparable del proyecto.** Dos
  ficheros, los dos, en dos sitios fuera del PC: `android/signing.properties`
  (ignorado por git, con las contraseñas) y
  `C:\Users\Usuario\.android\bitacora-rpg-release.jks`. Sin ellos no se puede
  volver a actualizar la app: solo desinstalar, que borra los datos y las
  claves de AndroidKeyStore que los descifran.
- **Mejorar los audios.** La carga suena baja y usa un sonido local de prueba,
  `android/app/src/main/res/raw/ui_access_loading_test.mp3`, en `.gitignore`,
  que **nunca se sube**.

---

## Qué hay hecho

- **MVP cerrado.** A0–A5, A7, A9, A10 y A11 completadas; A6 retirada
  (ADR-005); **G8 verde el 30 de septiembre de 2026** con la tablet (release
  `1.5.0+9`, detalle en `documentos/A8-VALIDACION-RELEASE.md`).
- **Post-MVP aprobado en la tablet:** sonido (`1.5.0+9`), copiar/pegar el
  código de recuperación y «Salir» (`1.5.1+10`), sonidos de acceso
  (`1.6.0+11`), sonidos elegidos por escucha y pantalla completa
  (`1.6.1+12`, `1.6.2+13`).
- **Fase 1 de ADR-006** (`1.7.0+14`, fusionada en `main` el 3 de octubre):
  - Esquema **v4**: 14 tablas nuevas y `location` en `missions` y
    `mission_templates`. Migraciones v1/v2/v3 → v4 probadas; snapshot en
    `drift_schemas/drift_schema_v4.json`.
  - Menú **Personaje** (cuarto en la barra lateral, en «Más» en teléfono):
    pestañas CIBERWARE e INVENTARIO vacías hasta la fase 2, MAPA aplazado,
    PERSONAJE (hexágono de áreas y panel) y DIARIO (entradas y personajes).
  - Personajes (`features/contacts/`) con foto, vinculados a misiones y
    entradas. Misiones con ubicación, foto y personajes.

**Notas técnicas de la fase 1 que importan para la fase 2:**

- `drift_dev` no se puede subir con Flutter 3.41.5. El snapshot de un esquema
  nuevo se genera con el procedimiento controlado: pubspec temporal con
  `drift: 2.34.0`, `schema dump` y restaurar `pubspec.yaml` y `pubspec.lock`.
- Fotos de entidades: `EntityPhotoDao` (una vigente; cambiarla archiva la
  anterior en la misma transacción; `revertReplacement` si el fichero no se
  confirma) y `features/photos/`. Se cifran con la clave **`entity_photos`**,
  que debe seguir en la lista permitida de `DatabaseKeyStoreBridge.kt` (la
  release rechazaría la clave; la debug no lo nota). Una clave nueva exige
  añadirla ahí.
- Acciones de foto comunes en `photos/presentation/entity_photo_actions.dart`.
- La limpieza de huérfanos de `entity_photos` (`entityPhotoCleanupProvider`)
  **aún no se dispara**.
- Los vínculos (personajes de misión o entrada) se escriben **dentro** de la
  transacción del agregado; `null` = no tocar. Patrón en
  `contact_link_support.dart`.
- Rutas del menú: `/character?tab=ciberware|inventario|mapa|personaje|diario`
  y `/character/contacts/...`. 61 rutas en total; `_railBranches` en
  `adaptive_shell.dart` traduce posición → rama.
- Aplazado a la fase 3 (proyectos): la foto de respaldo de D15.

Después de ADR-006, el último bloque del post-MVP es la **copia de seguridad**
(ADR-006 D2, adenda de ADR-005).

---

## Decisiones que NO se reabren

- **ADR-006:** dinero real (cada compra es un `EXPENSE` y crea un objeto; el XP
  no se gasta), migración a v4 sin copia previa (riesgo aceptado), Personaje =
  mi ficha (hexágono por áreas, sube solo con XP) + personajes, inventario con
  Equipado por zonas (una zona por objeto, sin loadouts), mapa descartado
  (exigiría `INTERNET`). El resto, en el ADR.
- **Espejo de alarmas: Opción A.** Espejo mínimo cifrado fuera de la base
  (`scheduleId`, `systemNotificationId`, `notifyAtUtcMs`, `soundEnabled`,
  `showDetails`, `kind`). **Nunca el título ni el recuento.**
- **El resumen diario vive fuera de `notification_schedules`**, en las
  preferencias cifradas. Reversible si el usuario lo pide.
- **Sin alarmas exactas** (batería). Se mantiene `setAndAllowWhileIdle`.
- **El receiver nunca abre la base cifrada** (ADR-002).
- **Descubrimiento al crear misiones:** se conserva la disposición actual.

---

## Reglas de trabajo vigentes

- **Una mini-spec aprobada por paso** antes de programar. El ADR de cada fase
  es la spec; no hace falta más documento por sesión.
- **Nunca instalar un APK `prod-debug` sobre la `prod-release` instalada.** Son
  la misma aplicación con llaves distintas y Android la rechaza; desinstalar
  para forzarlo borra la base **y** las claves que la descifran. Para probar:
  `--flavor dev`. Para la release: misma llave, comprobando antes con
  `apksigner verify --print-certs` que el SHA-256 coincide.
- **Nunca lanzar `flutter test`, `flutter drive`, `flutter run` ni el gate G8
  contra un dispositivo con la app prod instalada**, ni siquiera `--flavor
  dev`: si la instalación falla, Flutter puede desinstalar la prod. Ocurrió el
  24 de septiembre de 2026. El gate aborta solo si la encuentra; no añadirle
  un interruptor para saltarlo.
- **No apilar cambios sobre un APK que esté bajo prueba física.**
- **Documentar cada sesión:** entrada nueva arriba en
  `documentos/HISTORIAL-SESIONES.md` (parte 1) y, aquí, actualizar solo la
  cabecera y «▶ EMPEZAR AQUÍ». Este documento no vuelve a crecer con historia.
- El MP3 de prueba (`ui_access_loading_test.mp3`) **nunca se sube**.
- Si la release falla con
  `package dev.flutter.plugins.integration_test does not exist`: borrar
  `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`
  y repetir. Es un fichero generado que las compilaciones debug dejan obsoleto.
- Los ficheros Kotlin están en CRLF. Las sustituciones con `perl -0pi` que usen
  `\n` **no casan**: usar `\r?\n` o reescribir el fichero entero.

---

## Estructura que debe preservarse

### Nivel 1 — No modificar sin motivo contractual

| Área | Rutas principales | Razón |
|---|---|---|
| Decisiones | `documentos/DECISIONES_PRE_A0.md`, `ADR-001` a `ADR-006` | Son la fuente de verdad vigente |
| Esquema | `lib/infrastructure/database/schema.drift` | Cambiarlo exige migración, snapshot y revisión de contrato |
| Código Drift generado | `lib/infrastructure/database/app_database.g.dart` | Se regenera; no se edita manualmente |
| Snapshots Drift | `drift_schemas/` | Evidencia y base de migraciones |
| Cifrado | `encrypted_database_connection.dart`, `encrypted_photo_vault.dart`, `DatabaseKeyStoreBridge.kt` | Una alteración puede volver ilegible o exponer la base y las fotos |
| Credenciales | `features/access/domain`, `features/access/data`, `AccessCredentialStoreBridge.kt` | Lógica criptográfica y fail-closed |
| Sesión y privacidad | `access_session_controller.dart`, `privacy_controller.dart`, `privacy_boundary.dart` | Evitan reapertura tardía y exposición visual |
| Frontera de persistencia | `app/providers/persistence_providers.dart` | Impide abrir DAOs o base con sesión cerrada |
| Seguridad Android | `MainActivity.kt`, `PrivacyWindowBridge.kt`, `AndroidManifest.xml` | Keystore, biometría, `FLAG_SECURE` y `allowBackup=false` |

### Nivel 2 — Extender respetando contratos existentes

- `app/router/app_routes.dart`: cada `AppRouteContract` lleva su página en
  `builder`; dejarlo en `null` la deja como superficie diferida al
  placeholder. Las rutas `settingsData*` se retiraron con A6 (ADR-005); no
  re-añadirlas sin reabrir ese ADR.
- `app/router/app_router.dart`: solo aplica lo transversal (`ProtectedRouteGate`
  + observer) y delega en `contract.builder`. No mover el guard ni el observer
  fuera de este envoltorio.
- `test/app/router/app_routes_test.dart` fija las superficies diferidas sin
  `builder`: una ruta nueva sin página falla hasta reconocerla.
- `shared/adaptive/adaptive_shell.dart`: conserva breakpoints y ramas
  independientes.
- `app/theme/`: reutiliza tokens antes de crear estilos locales.
- `core/result/` y `core/errors/`: los repositorios devuelven resultados
  tipados.
- Repositorios y DAOs: pueden ampliarse, sin exponer Drift a la UI y con las
  operaciones multientidad atómicas.

### Nivel 3 — Temporal, generado o reemplazable

- `FeaturePlaceholderPage`: desaparece al implementar pantallas reales.
- `build/`, `.dart_tool/`, `.idea/`, `.vscode/`: no se versionan.

### Mapa de conexión en producción

```text
main_dev/main_prod
    └── bootstrap(AppEnvironment)
        └── ProviderScope
            └── BitacoraApp
                ├── appRouterProvider
                │   ├── accessSessionProvider
                │   ├── guard de rutas
                │   └── shell adaptable
                └── AppPrivacyBoundary
                    ├── auto-lock
                    ├── privacy cover
                    ├── persistenceAccessGuardProvider → cierra BD al bloquear
                    ├── recurrenceGenerationGuardProvider → genera ocurrencias y reconcilia avisos al desbloquear
                    └── appDatabaseProvider cifrada solo al desbloquear
```

---

## Reglas arquitectónicas

1. El dominio no importa Flutter, Riverpod, Drift ni plugins.
2. La UI consume application/casos de uso; nunca consume DAOs directamente.
3. Las operaciones que cruzan dominios (`CompleteMission`, la compra de la
   fase 2) van en una unidad de trabajo y una sola transacción.
4. No usar `FOR UPDATE`; SQLite usa `row_version` y actualización optimista.
5. Identificadores, query y fragmentos sensibles no aparecen en logs.
6. La base permanece cerrada cuando la sesión no está desbloqueada.
7. Las operaciones externas a SQLite ocurren después del commit.
8. No configurar firma release con la llave debug.
9. No actualizar dependencias fijadas ni Flutter sin revisar el contrato
   vigente.
10. Antes de editar, ejecutar `git status` y no sobrescribir cambios ajenos.

---

## Deudas abiertas

| Deuda | Qué hacer |
|---|---|
| Columna muerta `app_settings.daily_summary` | Mapeada en `AppPreferences` pero no decide nada. O se cablea o se retira; **no** reutilizarla como interruptor (su valor por defecto es verdadero). |
| Refactor aplazado hace varias sesiones | Se puede replantear; nadie lo ha pedido aún. |

---

## Comandos operativos

```powershell
flutter pub get
flutter analyze
flutter test                                                   # en el PC, nunca contra la tablet
flutter build apk --debug --flavor dev -t lib/main_dev.dart    # APK dev
powershell -ExecutionPolicy Bypass -File tool/quality.ps1      # verificación completa
powershell -ExecutionPolicy Bypass -File tool/a8_preflight.ps1 # preflight release
powershell -ExecutionPolicy Bypass -File tool/gate_g8.ps1 -DeviceId <serial-adb>  # solo sin la app prod instalada
```

---

## Lista de lectura antes de cambiar arquitectura

1. Este documento.
2. `documentos/DECISIONES_PRE_A0.md`.
3. ADR-001 si se toca base, DAOs, cifrado, claves o esquema.
4. ADR-002 si se toca acceso, sesión, router protegido, autobloqueo o
   privacidad.
5. ADR-003 si se tocan títulos, rachas, niveles por área o sus reglas.
6. ADR-006 para Personaje, personajes, inventario, ciberware, compra y tienda.
7. El documento fuente de UX, navegación o datos de la pantalla que se
   implemente.

Si una pieza parece no usada, buscar referencias en `lib/`, `test/` e
`integration_test/` y revisar su fase prevista antes de eliminarla.
