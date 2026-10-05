# Historial de sesiones y relevos antiguos

Movido desde `ESTADO_ACTUAL.md` el 4 de octubre de 2026, sin cambios en el
texto. `ESTADO_ACTUAL.md` guarda solo lo vigente; aquí vive la historia.

- **Parte 1 — Bitácora de sesiones:** registro de cada sesión. **Entrada nueva
  arriba**, justo debajo del encabezado de la parte 1.
- **Parte 2 — Relevos antiguos:** los bloques de relevo, resúmenes y secciones
  de estado que dejaron de estar vigentes. Solo consulta; pueden contradecirse
  con el estado actual, que manda siempre.

---

# Parte 1 — Bitácora de sesiones

Registro cronológico y detallado de cada sesión de trabajo. Entrada nueva
arriba. Sirve para retomar el hilo cuando se pierde el contexto de una sesión:
qué se tocó, qué se decidió, qué quedó abierto.

### 2026-10-04/05 — Fase 2 de ADR-006 completa y `1.8.0+15` en la tablet

- `ESTADO_ACTUAL.md` adelgazado (2059 → ~300 líneas); la historia vino aquí.
- **D17**: fuera Ciberware, Inventario y Creación; la fase 2 pasa a ser la
  **Tienda = lista de deseos** (área de vida + tipo, color según saldo,
  comprar = gasto en Economía, avisos «ya puedes comprarlo»). Esquema **v5**
  (`area_id` en `inventory_items`), ensayado en `dev` con datos.
- Además, pedidos por el usuario: ☰ barra lateral deslizable, tema **Vino**
  y texto **Cian**, cabecera limpia (☰ + hora + saldo), **D18** (fuera MAPA y
  «Bitácora» del lateral), **Diario** y **ficha de personaje** al estilo del
  juego (maquetas privadas «Cabecera de Bitácora», «Diario de Bitácora» y
  «Ficha de personaje»; referencia: captura del juego de Claire Russell).
- Cada paso con mini-spec aprobada, pruebas, `dev` en la tablet y commit.
  Lección: una vez el usuario aprobó sin haber instalado la APK; desde
  entonces se compara la **huella** del `base.apk` instalado antes de
  aceptar.
- `1.8.0+15`: preflight A8 verde, release con la misma llave, instalada
  encima de `1.7.0` en la prod (03:16). **Pendiente**: «datos bien» del
  usuario, fusionar en `main` y el **respaldo de la llave** (pendrive).
  7-Zip instalado (winget) para un posible respaldo en la nube.
- 425/425 pruebas.

### 2026-10-03 — Fase 1 de ADR-006 terminada: `1.7.0+14` en la tablet y en `main`

**Qué pidió el usuario.** Retomar la fase 1 donde quedó (ensayo de migración
superado el 1 de octubre) y completarla: datos, pantallas, misiones y versión.
Cada paso se revisó en la tablet antes de seguir.

**Qué se hizo, paso a paso (todo en `feat/v4-fase1`, ya fusionada):**

1. **Datos (`8b818cb`).** `ContactDao` y `features/contacts/` (crear
   idempotente por id, editar con `row_version`, archivar/restaurar);
   vínculos con misiones y entradas escritos **dentro** de la transacción de
   la misión o la entrada (`contact_link_support.dart`; solo los vínculos
   nuevos exigen personaje activo); foto única de personaje y misión
   (`EntityPhotoDao`, `features/photos/`) en su **propia carpeta y clave
   `entity_photos`**, añadida a la lista permitida de
   `DatabaseKeyStoreBridge.kt`; el cifrado de Bitácora pasó a
   `infrastructure/photos/encrypted_photo_vault.dart` sin cambiar carpeta,
   clave ni formato; `location` en misiones y plantillas (la plantilla la
   copia a cada misión generada o tomada del tablón).
2. **Pantallas (`5c8f637`).** Entrada **Personaje** en la barra lateral
   (cuarta; rama 7 del shell, traducida con `_railBranches`) y en «Más» en
   teléfono; rutas `/character…` (61 en total); menú con NIVEL, REPUTACIÓN
   («--»), saldo y cinco pestañas; hexágono de áreas (`CustomPainter`) y
   panel; DIARIO = Bitácora con miniaturas de personajes + vista Personajes
   (cuadrícula, archivados, ficha, formulario); selector de personajes en
   las entradas. Golden de la barra lateral regenerado a propósito.
   **Aprobado en la tablet (dev).**
3. **Misiones (`ae08ba7`).** Panel «Lugar y personajes» en el formulario
   (la ubicación se precarga al editar; los personajes solo cambian si se
   tocan; las diarias nuevas, que son plantillas, solo ofrecen ubicación);
   ubicación en el formulario de plantilla; panel de foto, ubicación y
   personajes en el detalle; franja en las tarjetas de Hoy y colecciones;
   acciones de foto comunes (`entity_photo_actions.dart`).
   **Aprobado en la tablet (dev).**
4. **Versión (`43dfd42`).** `1.7.0+14`, preflight A8 verde, release firmada
   (SHA-256 `62db5848…7c6095`, certificado `a6092c6c…16b8`, sin
   `INTERNET`), instalada **encima** de `1.6.2+13` con datos reales:
   `firstInstallTime` intacto, versión 14 y el usuario confirmó «mis datos
   siguen acá». `main` avanzó por fast-forward hasta `43dfd42`.

**Decisiones de esta sesión.**

- La foto de personaje y de misión se pone desde su ficha o detalle, no al
  crear, porque necesita que el registro exista (igual que en Bitácora).
- REPUTACIÓN se muestra como «--» y no hay «+ Compra» ni «Tiempo
  registrado» hasta sus fases; la foto de respaldo «del proyecto» (D15)
  espera a la fase 3.
- En la barra lateral, Personaje va entre Bitácora y Economía. La Bitácora
  sigue en la barra hasta que el usuario confirme que DIARIO la sustituye.

**Incidencias.** `adb install -r` dio `INSTALL_FAILED_USER_RESTRICTED` en
todas las instalaciones de hoy (dos `dev` y la release); la tablet además pidió
reautorizar la depuración USB. Todas se instalaron por Descargas sin pérdida
de datos. `main` estaba abierta en el worktree `bitacora-main-v3`, así que la
fusión se hizo desde allí.

**Verificación.** `flutter analyze` limpio y **320/320 pruebas** (44 nuevas
sobre las 276 del inicio de la sesión).

**Qué queda abierto.** Ver «▶ EMPEZAR AQUÍ»: fase 2, respaldo de la llave de
firma, audios y la retirada de «Bitácora» de la barra cuando el usuario lo
decida.

### 2026-09-25 — Efectos de sonido, candidata `1.5.0+9`

**Qué pidió el usuario.** Sonido al entrar (login), al cambiar de sección en
el menú, al crear una misión, al completarla y al subir de nivel, con estilo
futurista. Se retomó `documentos/PROPUESTA-SONIDO.md` (15 de septiembre) en
lugar de empezar de cero, y el usuario aceptó sus condiciones: dos
interruptores, apagados por defecto, y antes de ADR-006 porque no toca el
esquema.

**Qué se hizo.** Todo el detalle está en la sección «Implementación» de la
propuesta. En resumen:

- `UiSoundBridge.kt` con `SoundPool`: sin foco de audio (no corta la música)
  y sin sonar si el teléfono no está en modo normal. Sin paquete nuevo.
- Cinco `.ogg` de Kenney (CC0) en `res/raw`, 77 KB. **Elegidos por nombre,
  sin escucharlos**: se validan en el recorrido y se cambian sustituyendo el
  fichero.
- **Ajustes → Sonido** (`/settings/sound`, ruta 57): «Sonidos de logros» y
  «Sonidos de interfaz». Al activar uno suena una muestra.
- La subida de nivel se detecta comparando el nivel del XP total con el del
  total menos lo otorgado. Si sube, suena solo el efecto de nivel.
- `PreferenceSwitchCard` se extrajo de Apariencia para compartirla con Sonido.

**Desviación documentada.** Las preferencias viven en un fichero no sensible
(`ui_sound_v1.txt`), como el color de acceso, y no en la metadata cifrada: el
sonido de acceso se decide al desbloquear.

**Verificación.** `flutter analyze` limpio, **250/250 pruebas** (12 nuevas),
APK `prodRelease` `1.5.0+9` de 73.000.867 bytes, SHA-256
`2e1c1069a2f1c0f0cd42c047272c1bf38e995447f778d69033cb643f226b9202`, firmada con
`a6092c6c…`, con los cinco `.ogg` dentro y **sin permiso `INTERNET`**.

**Validada en dispositivo el mismo día.** El usuario instaló `1.5.0+9` en la
tablet y aprobó los sonidos tal como están: la selección hecha por nombre se
queda. Se comprobó por ADB que es `1.5.0` (código 9), con la firma de siempre y
como actualización (`firstInstallTime` sin cambiar), así que no se perdió
nada.

**Cómo se instaló, y por qué importa para G8.** HyperOS 3 rechazó **tanto
`adb install` como `pm install` desde `adb shell`**, al instante y sin mostrar
ningún aviso: `PKMSImpl: assertCallerAndPackage: uid=2000 … Install canceled
by user`, con `persist.security.adbinstall=1`. El `pm install` del 24 de
septiembre sí funcionó, así que la condición cambia entre sesiones; la
sospecha sigue siendo la cuenta Mi o la conexión. **Lo que funcionó fue
copiar la APK a `Descargas` con `adb push`, avisar al escáner de medios
(`am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE`) e instalarla
el usuario desde el gestor de archivos.** Sirve para actualizar, pero no para
G8: el gate instala por USB y seguirá fallando hasta resolver HyperOS.

**Qué queda abierto.**

- **G8 sigue bloqueado** por la instalación USB de HyperOS, además de exigir un
  dispositivo sin la app prod. Validará `1.5.0+9`, no `1.4.0+8`.
- No quedó registrado por separado si se probó con música de fondo o en
  silencio; el código cubre ambos casos.

### 2026-09-24 — Incidente: el gate G8 borró la app prod de la tablet

**Qué pasó.** Con la tablet conectada por USB (Xiaomi `25040RP0AL`, Android 16,
serial `biuonrrcey45lvrs`) se comprobó que tenía instalada la release
`1.4.0+8` con el certificado de siempre (`a6092c6c…`) y se lanzó
`tool/gate_g8.ps1`. El preflight salió verde entero (238/238 y
`lintProdRelease`). En el primer paso con dispositivo, MIUI rechazó la
instalación de `app-dev-debug.apk` con `INSTALL_FAILED_USER_RESTRICTED`, y
**Flutter, como recuperación, desinstaló `com.jcyq.bitacorarpg` —el paquete
prod, sin sufijo `.dev`—**. Logcat de la tablet:

```
22:09:35.873 PKMSImpl: ... packageName: com.jcyq.bitacorarpg.dev, msg=Install canceled by user
22:09:36.292 PackageManager: Uninstall pkg: com.jcyq.bitacorarpg u0 flags:2 from u2000/27237
22:09:36.706 RollbackManager: broadcast=ACTION_PACKAGE_FULLY_REMOVED pkg=com.jcyq.bitacorarpg
```

`FULLY_REMOVED` significa base cifrada y claves de AndroidKeyStore borradas.
Sin `allowBackup` ni exportación (ADR-005) **no hay recuperación posible**.

**Consecuencia.** El usuario confirmó que eran **datos de prueba** y que
recrearlos le sirve para encontrar fallos. Se reinstaló `1.4.0+8` desde
`build/app/outputs/flutter-apk/app-prod-release.apk`: versión 8, misma firma
(`cfba7fb9`), así que las próximas release siguen instalándose encima.

**Por qué el relevo no lo evitó.** `A8-VALIDACION-RELEASE.md` pedía «un
dispositivo limpio dedicado», pero este relevo decía que instalar el flavor
`dev` era «seguro» y que el `install -r` final era la única precaución. Nada en
los scripts lo comprobaba. Además, tras el primer fallo se afirmó al usuario
que su app no se había tocado **sin verificarlo en el dispositivo**; se
descubrió al revisar `pm path` después de la segunda pasada.

**Causa probable, no confirmada en el código de Flutter.** En la primera pasada
la APK `dev` aún no existía cuando Flutter resolvió el paquete, y tomó el
`applicationId` del proyecto sin el sufijo del flavor. En la segunda pasada,
con la APK ya construida, el `uninstall` de recuperación apuntó correctamente a
`.dev`, que no existía, y no hizo daño.

**Qué se cambió.** `tool/gate_g8.ps1` y `tool/process_restart_g2.ps1` tienen
`Assert-ProdPackageAbsent`: antes de lanzar Flutter contra el dispositivo,
listan los paquetes y **abortan si `com.jcyq.bitacorarpg` está instalado**, o
si `adb` no puede listarlos. Probado aislado: bloquea con la tablet real, deja
pasar con solo `.dev` o dispositivo vacío. Sin interruptor para saltárselo, a
propósito.

**MIUI y la instalación por USB.** Con «Instalar vía USB» activado, `adb
install` siguió fallando con `INSTALL_FAILED_USER_RESTRICTED`. Lo que sí
funcionó fue copiar la APK a `/data/local/tmp` y lanzar `pm install` desde
`adb shell`. Flutter usa `adb install`, así que para que el gate funcione en
esta tablet hay que resolver el aviso de MIUI (suele pedir cuenta Mi con
sesión iniciada y conexión a internet), no rodearlo.

**Qué queda abierto.**

- **G8 sigue rojo.** Para correrlo en la tablet ahora hace falta que no tenga
  la app prod: la instalación actual está vacía, así que es el momento de
  decidir si se desinstala para el gate antes de volver a meter datos.
- La instalación por USB en MIUI, sin resolver.
- Una copia `Descargas/Bitacora-1.4.0+8.apk` quedó en la tablet; se puede
  borrar.

**Más tarde, esa misma sesión: G8 en la tablet y ADR-006.**

- El usuario decidió usar **la tablet como dispositivo principal** y cerrar G8
  en ella, autorizando desinstalar la instalación vacía para correr el gate.
  **No se desinstaló**: una prueba inofensiva (`adb install` directo de la APK
  `dev`, sin Flutter de por medio) volvió a dar
  `INSTALL_FAILED_USER_RESTRICTED`, así que el gate fallaría igual. Pendiente
  del usuario: sesión de cuenta Mi, conexión a internet y reactivar «Instalar
  vía USB» (o desactivar la optimización de MIUI). Repetir la misma prueba
  antes de desinstalar nada.
- **ADR-006 reescrito con todas las decisiones de producto** a partir de
  capturas de *Cyberpunk 2077* que aportó el usuario. Resumen en el RELEVO,
  «Personaje, Contactos, Inventario y Tienda».
- **D2 anotada en todos los `.md` que mencionan A6**, con una adenda en
  ADR-005: la copia de seguridad vuelve como último bloque del post-MVP.

### 2026-09-23 — A11 cerrada, el golden resuelto y el gate G8 desbloqueado

**A11 y G9 cerradas.** El usuario confirmó que el recorrido físico de
`1.4.0+8` salió sin incidencias. Los cuatro puntos quedan validados en
dispositivo y `ESTADO_FASES.md` los marca con fecha. A9 cierra con A11, porque
su propia puerta decía que G9 no se cerraba hasta que A11 estuviera verde.

**El golden `sidebar_modular_battery` no fallaba por antialiasing.** El relevo
lo arrastraba como deuda «preexistente» desde el 15 de septiembre, con la
hipótesis del antialiasing y la recomendación de decidir si regenerarlo. La
causa real es otra: `matchesGoldenFile` aplicado a un `Finder` no captura ese
widget, sino el `RepaintBoundary` más cercano hacia arriba. `TerminalSidebar`
no tenía ninguno, así que la captura subía hasta la raíz y fotografiaba la
pantalla entera —incluido el navegador de día de Bitácora, que imprime la fecha
de hoy—. El test fallaba **todos los días salvo el de su regeneración**, y el
tamaño del diff seguía a la longitud del nombre del día: 0,26 % / 2676 px el 15
de septiembre, 0,45 % / 4644 px el 23. Regenerarlo lo habría dejado verde un
solo día.

Se confirmó midiendo: dos pasadas consecutivas dieron cifras idénticas —luego
no era ruido de renderizado— y un volcado temporal de los `Text` de esa banda
imprimió `miércoles, 23 de septiembre de 2026` justo en la fila que cambiaba.

La corrección es un `RepaintBoundary` en `TerminalSidebar`. Acota la captura a
los 248 px de la barra, que es lo que el test dice medir, y de paso evita que
la barra se repinte cuando cambia el módulo abierto, cosa que no necesita.
Golden regenerado y matriz en **238/238**.

**El gate G8 llevaba inejecutable desde agosto.** Al ir a cerrar A8 salió que
`tool/a8_preflight.ps1` no podía completarse por tres motivos independientes:

1. `flutter test` estaba rojo por el golden, y `quality.ps1` aborta con eso.
2. La aserción del esquema estaba fijada a `schemaVersion => 1`, escrita en
   agosto. El esquema va por **v3** desde A10, así que el preflight moría en su
   primera comprobación. Se cambió por una que lee la versión declarada y exige
   que exista `drift_schemas/drift_schema_v<N>.json`: así no vuelve a quedarse
   atrás en la próxima migración.
3. El barrido de `print`/`debugPrint` invocaba `rg`, que no está en el PATH de
   PowerShell. Sustituido por `Select-String`.

También se corrigió `gate_g8.ps1`, que escribía `schemaVersion = 1` fijo en el
manifiesto de evidencia; ahora lo lee del código.

Con eso, **el preflight pasa entero por primera vez**: formato, `build_runner`,
`analyze`, 238/238 pruebas, registro de plugins y `:app:lintProdRelease` con
`BUILD SUCCESSFUL` en 2 m 23 s.

**Todo subido.** Tres commits en `origin/main`, de `e8e4b3a` a `f16e1e1`. Se
arrastraba además la sección «Calidad» del `CHANGELOG.md` sin commitear desde
el 15 de septiembre; va incluida.

**Lo que quedó abierto.** G8 sigue rojo por una sola razón, y no es de código:
no hay dispositivo. `adb devices` salió vacío y el usuario no podía conectar
ese día. Falta también el AAB de `1.4.0+8`, que saldrá de la misma pasada del
gate.

**Decisión tomada:** el criterio de los dos factores de forma **se mantiene sin
acotar**. Se planteó rebajarlo a un solo factor o cubrir la tablet con un AVD,
y el usuario respondió que **tiene tablet real**, así que G8 se cerrará tal como
está escrito.

### 2026-09-13 — Sincronización con GitHub y apertura del ADR-006

Sesión de documentación. **Sin cambios de código ni de versión.** `1.4.0+8`
sigue esperando su recorrido físico: el usuario no llegó a responder si lo
hizo, así que la primera pregunta del próximo relevo sigue siendo la misma.

**Lo primero fue una corrección de estado.** El relevo daba por pendientes
siete commits sin subir. No lo estaban: `git fetch` confirmó que `main` y
`origin/main` apuntaban ambas a `9c35acb`, y que
`feat/misiones-recurrentes-tablon` también estaba sincronizada. El usuario los
había subido al cerrar la sesión anterior sin que quedara anotado. Se corrigió
en los tres sitios donde el pendiente seguía vivo —cabecera de estado, resumen
del RELEVO y lista de tareas del usuario— y se dejaron intactas las menciones
de la Bitácora de sesiones del 2026-09-06, que son registro histórico.

**Se abrió `documentos/ADR-006-PERSONAJES-TIENDA-INVENTARIO.md`**, en estado
propuesto (borrador). No autoriza código: el bloque sigue detrás de A11 y
A8/G8.

**El hallazgo de la sesión, y la razón de que el ADR valga la pena.** El nivel
se deriva de `SUM(amount)` sobre `xp_transactions` **sin filtrar**
(`progress_dao.dart:173` → `rpg_level.dart:18`, umbrales `100 * (n - 1)²`).
Si una compra insertara un asiento negativo en ese libro, el personaje
**perdería niveles al comprar**: gastar 400 XP en nivel 3 devuelve al nivel 2,
y el jugador aprende a no comprar nunca. El esquema además lo impide hoy,
porque `amount > 0` salvo `MANUAL_ADJUSTMENT`, que exige `reason` no vacío.

Eso convierte «pagar con XP» en tres salidas distintas, no una: moneda
separada (no toca `xp_transactions` ni ADR-003, **recomendada**), dos sumas
sobre el mismo libro (barata en apariencia, cambia el significado de una
consulta ya validada) o dinero real, que es otro producto.

**Segundo riesgo anotado.** ADR-001 §13 documenta que el ejecutable de
`drift_dev 2.34.0` no compila junto a `drift 2.34.3`, y que v1 se exportó con
un procedimiento controlado y temporal. Generar `drift_schema_v4.json` volverá
a chocar con eso. Conviene comprobarlo **antes** de comprometer fechas del
bloque, no al llegar.

**El ADR quedó enlazado** desde el README (punto 7 de la lista de lectura, con
el resto de ADR; se renumeraron los siguientes) y desde la sección del relevo
que antes decía «exige su propio ADR antes de escribir código». Sin ese enlace
el próximo relevo podía no encontrarlo y volver a empezarlo de cero.

**Decidido / por decidir:**

- El ADR deja tres decisiones al usuario: **D1** con qué se paga, **D2** si se
  hace un volcado cifrado antes de migrar, **D3** si «personaje» es una ficha
  o varias. Ninguna respondida.
- **D2 es el punto irreversible del bloque.** ADR-005 retiró la exportación y
  `allowBackup="false"`: no hay copia de nada. Una migración v3 → v4 que salga
  mal sobre datos reales no tiene vuelta atrás. El volcado propuesto no es
  reabrir A6 —sería técnico, de un solo sentido y sin pantalla—, pero exige
  decisión explícita.
- Ocho decisiones propuestas que **no** dependen de D1–D3 quedan escritas en el
  ADR: una sola migración v3 → v4 en vez de tres, idempotencia de compra con
  `operation_id UNIQUE`, un solo valor nuevo en `AppArea`, archivado lógico.

**Abierto / por recordar:**

- El recorrido de `1.4.0+8`. Sin él A11 no cierra.
- **El respaldo de la llave de firma sigue sin hacer.** Arrastrado desde A8 y
  lo único irreparable del proyecto.
- Las deudas de la tabla del relevo no se tocaron: golden
  `sidebar_modular_battery`, columna muerta `app_settings.daily_summary`,
  refactor aplazado.

### 2026-09-07 (sexta parte) — Puntos 3 y 4, y candidata `1.4.0+8`

El usuario pidió seguir con los puntos 3 y 4 y validar los tres juntos, para
ahorrar un ciclo de instalación.

**Punto 3 — Aviso de vencimiento. IMPLEMENTADO.**

No hizo falta migrar: el `CHECK` de `notification_type` ya admitía `CRITICAL`.
Lo que sí hizo falta fue generalizar el reemplazo de intenciones del DAO, que
estaba fijado a `START` por nombre. `_replaceStartNotificationIntent` pasó a
`_replaceNotificationIntents`, que recibe un mapa de tipo a intención y
**solo toca los tipos que gestiona**. Antes cancelaba cualquier intención
abierta de la misión, lo cual era equivalente cuando `START` era el único tipo
emitido; con dos tipos ya no lo es, y sin ese cambio editar la hora de inicio
habría cancelado el aviso de vencimiento en silencio.

**La trampa que se evitó:** `isDateOnly` usa `expiresAt` como final del día
civil, no como plazo del usuario (`mission.dart:177-179`). Un aviso de
vencimiento ingenuo habría sonado **cada noche por cada misión sin hora**. El
aviso solo se crea si hay vencimiento real, la misión no es de solo fecha y el
plazo aún no ha pasado. Hay cuatro pruebas que fijan esto, incluida la de mover
el plazo sin tocar el aviso de inicio.

**La anticipación no es propia.** El reconciliador resta la misma que al resto
de recordatorios, así que se configura desde el mismo sitio en Ajustes. Se evitó
inventar una segunda preferencia para lo mismo.

**Punto 4 — Texto configurable. IMPLEMENTADO.**

El texto ya no está fijo en Kotlin. `reconcile()` lo cocina en Dart y viaja
resuelto por el canal: el título si «mostrar detalles» está activo, y si no, el
texto que el usuario escriba en Ajustes → «Texto sin detalles». El campo guarda
al confirmar o al perder el foco, no en cada tecla, para no escribir en la base
cifrada una vez por carácter. Un texto vacío se rechaza y conserva el anterior.
La constante de Kotlin queda como red de seguridad, no como fuente.

**Hallazgo: hay una columna muerta que conviene retirar.** `app_settings` tiene
`daily_summary`, mapeada en `settings_mapper.dart` y expuesta en
`AppPreferences`, pero **no la usa nadie para decidir nada**. Es andamiaje de
A0/A1. **No se reutilizó como interruptor del resumen a propósito:** su valor
por defecto es verdadero, así que habría activado el resumen diario a todo el
mundo sin pedirlo. El interruptor real vive en las preferencias cifradas y es
opt-in. Queda anotado como deuda: o se cablea o se retira, pero tener dos cosas
llamadas «resumen diario» confunde.

**Candidata `1.4.0+8`, compilada, firmada y verificada.** `versionCode=8`,
firma `a6092c6c…16b8`, idéntica a `1.2.1+6` y `1.3.0+7`: se instala encima
conservando datos. **Sin permisos nuevos** respecto a `1.3.0+7`; sigue sin
`INTERNET`.

**Verificación:** `flutter analyze` limpio, **237 pruebas verdes** (eran 230),
siete nuevas. Único fallo el golden `sidebar_modular_battery`, preexistente.

**Recorrido físico pendiente, los tres puntos de una vez:**

1. Instalar encima de `1.3.0+7`. **No desinstalar.** Comprobar que los datos
   siguen.
2. **Resumen diario:** Ajustes → Notificaciones → activar «Resumen diario» y
   ponerlo unos minutos por delante. Debe llegar un solo aviso con el recuento.
3. **Texto configurable:** cambiar «Texto sin detalles», dejar «mostrar
   detalles» apagado, programar una misión y comprobar que el aviso usa el
   texto nuevo.
4. **Aviso de vencimiento:** crear una misión **con hora y con vencimiento**
   cercano, y comprobar que llegan dos avisos: el de inicio y el del plazo.
5. **Regresión del punto 1:** con el resumen activado, reiniciar el teléfono y
   comprobar que sigue llegando; el resumen dirá «Abre Bitácora para ver tu
   resumen de hoy» en vez del recuento, porque el número no vive en el espejo.

Con eso A11 quedaría cerrada y tocaría G8 y el respaldo de la firma antes de
abrir Personajes, Tienda e Inventario.

### 2026-09-07 (quinta parte) — Punto 2: resumen diario

**DECISIÓN DE ESQUEMA TOMADA: el resumen vive FUERA de
`notification_schedules`.** Se planteó al usuario y no respondió al cuadro de
decisión, así que se siguió la recomendación, que además es la reversible: si
más adelante se prefiere migrar, se puede; al revés no, porque una migración
sobre datos reales sin exportación (ADR-005) no tiene vuelta atrás. **Queda
abierto a revisión si el usuario prefiere lo contrario.**

Las razones, ya con la tabla real delante (`schema.drift:320-345`): `mission_id`
es `NOT NULL` con clave foránea, el `CHECK` de `notification_type` no admite un
tipo de resumen y SQLite no deja alterarlo sin recrear la tabla, y con
`mission_id` nulable el `UNIQUE` dejaría de proteger justo esas filas. El
resumen no es un recordatorio de una misión: es una alarma diaria fija.

**Dónde vive entonces.** En las preferencias cifradas que ya usaba A9.1. Se
**extendió `ReminderPreferences`** en vez de crear una clase paralela: misma
preocupación, mismo almacenamiento, mismo repositorio, misma pantalla. Dos
claves nuevas de metadata, `notification_daily_summary_enabled` y
`notification_daily_summary_minutes`. **El esquema v3 no se toca.**

**Ficheros modificados:**

| Fichero | Cambio |
|---|---|
| `reminder_preferences.dart` | `dailySummaryEnabled` y `dailySummaryMinutes`, más `nextSummaryUtcMs()`, que calcula la próxima ocurrencia sobre **fecha civil** y no sumando 24 horas, para que los cambios de horario no desplacen el aviso. |
| `drift_reminder_preferences_repository.dart` | Las dos claves nuevas. |
| `notification_dao.dart` | `countOpenMissionsBetween()`: cuenta misiones no archivadas del día en estados que aún piden acción. |
| `mission_notification_platform.dart` | `contentText` en la petición y `MissionNotificationKind` en petición y espejo. |
| `notification_reconciliation_service.dart` | Programa el resumen, lo cancela cuando está desactivado y lo mete en el espejo. |
| `MissionAlarmReceiver.kt` | `EXTRA_CONTENT_TEXT`: si viene texto cocinado, se usa tal cual. Es además el mecanismo que necesitará el punto 4. |
| `MissionAlarmScheduler.kt`, `MissionNotificationBridge.kt` | Pasan texto y tipo. |
| `BootAlarmMirror.kt`, `BootAlarmRestoreReceiver.kt` | El espejo guarda el **tipo** de aviso. |
| `notification_settings_page.dart` | Interruptor propio y selector de hora, con el mismo estilo que el horario silencioso. |

**Dos trampas que se evitaron a propósito:**

1. **El identificador lleva la fecha** (`daily-summary-2026-09-08`). El receiver
   descarta entregas repetidas del mismo `scheduleId` guardándolas en
   preferencias; con un identificador fijo, el resumen habría sonado el primer
   día y **nunca más**. Hay una prueba que fija esto.
2. **El identificador de sistema sí es fijo** (`747474747`). Así cada día
   reemplaza la notificación del anterior en vez de apilarlas, y se puede
   cancelar sin recordar qué día se programó.

**Ampliación mínima del espejo, que conviene mirar.** El espejo ganó un campo
`kind`, que distingue un recordatorio de misión de un resumen. **No es
contenido:** no dice qué misión es ni cuántas hay. Sirve para que, tras un
reinicio, el resumen diga *«Abre Bitácora para ver tu resumen de hoy.»* en vez
del texto de misión, que sería mentira. Los cinco campos acordados siguen sin
llevar dato alguno de la base. Se registra por transparencia: si el usuario
prefiere que el espejo no crezca ni en eso, se quita y el resumen simplemente no
sobrevive al reinicio.

**El recuento es una foto, no un dato en vivo.** Se calcula al programar la
alarma, con la aplicación desbloqueada, y viaja ya convertido en texto. El
receiver no puede abrir la base (ADR-002). Si creas misiones después de que se
programe el resumen y no abres la aplicación, el número se quedará corto. Es la
consecuencia aceptada desde el principio.

**Verificación:** `flutter analyze` limpio, **230 pruebas verdes** (eran 225),
seis nuevas sobre el resumen. APK `prod-debug` compila. El único fallo de la
matriz sigue siendo el golden `sidebar_modular_battery`, preexistente.

**Sin validar en dispositivo.** No se ha subido versión ni compilado release: el
punto 2 espera a que se decida si se valida junto con el 3 y el 4 o por
separado.

### 2026-09-07 (cuarta parte) — Punto 1 VALIDADO en dispositivo

**Recorrido físico de `1.3.0+7`: CERRADO Y APROBADO por el usuario.**

Instalada encima de `1.2.1+6` sin desinstalar nada. El usuario confirmó que
todos los datos siguen intactos y que la aplicación funciona con normalidad.

**La prueba del reinicio, que es la que valida el punto 1:**

| Momento | Hecho |
|---|---|
| 9:30 | Misión creada para las 10:00 y teléfono reiniciado acto seguido |
| ~9:47 | Llega la notificación, sin abrir la aplicación en ningún momento |

Contra un objetivo de 9:45 (10:00 menos los 15 minutos de anticipación por
defecto), dos minutos de retraso: exactamente el margen esperado de
`setAndAllowWhileIdle`. Las alarmas exactas siguen descartadas y no hacen falta.

**Lo que esto demuestra:** las alarmas murieron con el reinicio, el receiver de
arranque leyó el espejo cifrado **sin abrir la base**, y repuso la alarma. Todo
sin intervención del usuario.

**La degradación confirmada en la práctica.** El usuario tenía **«mostrar
detalles» activado** y aun así el aviso decía *«Tienes una misión programada.»*,
sin el título. Es la prueba de que el espejo lleva solo los cinco campos
acordados y de que ningún contenido de la base cifrada salió de ella. La Opción
A se comporta exactamente como se prometió al aceptarla.

**A11 punto 1: COMPLETADO.**

**Hallazgo de esquema que encarece la Opción «migrar» del punto 2.** Al preparar
el punto 2 se leyó la definición real de `notification_schedules`
(`schema.drift:320-345`) y aparecen tres obstáculos, no uno:

1. `mission_id TEXT NOT NULL REFERENCES missions(id)`. Habría que hacerlo
   nullable.
2. `notification_type` tiene un `CHECK` cerrado a `EARLY`, `PREPARATION`,
   `START`, `FOLLOW_UP`, `CRITICAL`. No admite un tipo de resumen diario, y
   **SQLite no permite alterar un `CHECK`**: exige recrear la tabla entera
   (crear, copiar, borrar, renombrar) con sus claves foráneas.
3. `UNIQUE (mission_id, notification_type, notify_at)`. Con `mission_id` en
   NULL, SQL considera los NULL distintos entre sí, así que **la unicidad
   dejaría de proteger justo a las filas del resumen**: se podrían duplicar.
   Haría falta un índice único parcial como compensación.

O sea: la migración es una reconstrucción completa de tabla más una garantía
debilitada, y todo por una fila al día.

**Buena noticia para el punto 3.** El `CHECK` ya admite `CRITICAL` y
`FOLLOW_UP`, y hoy solo se emite `START`. El aviso de vencimiento **no necesita
migración**: puede usar un tipo que el esquema ya permite. Donde el relevo decía
«requiere un tipo nuevo», se refería a emitir un tipo nuevo, no a añadirlo al
esquema.

### 2026-09-07 (tercera parte) — Candidata `1.3.0+7` y alcance post-MVP acotado

**Rama:** `main`. Preparación de la candidata release y actualización documental.

**Por qué release y no `prod-debug`.** El usuario preguntó si podía instalar el
APK `prod-debug` teniendo la release en el teléfono. **No puede, y el intento es
peligroso.** El flavor `prod` no tiene `applicationIdSuffix`
(`build.gradle.kts`), así que `prod-debug` y `prod-release` son la misma
aplicación para Android (`com.jcyq.bitacorarpg`) firmadas con llaves distintas.
Android rechaza la instalación con `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, lo cual
es una protección. El peligro es lo que uno hace después: desinstalar. Eso borra
la base cifrada **y las claves del AndroidKeyStore que la descifran**, así que ni
una copia del fichero serviría; y no hay red de seguridad, porque ADR-005 retiró
la exportación y `allowBackup="false"`.

Queda escrito para que nadie lo repita: **para probar en el dispositivo, o bien
`--flavor dev` (se instala al lado, con sufijo `.dev` y datos propios), o bien
una release firmada con la versión subida.** Nunca `prod-debug` encima de una
`prod-release` con datos.

**Candidata `1.3.0+7`.** Menor y no parche porque el receiver de arranque es
funcionalidad nueva, no una corrección. Contiene el punto 1 de A11.

**Documentos actualizados en esta sesión:**

| Documento | Cambio |
|---|---|
| `ESTADO_FASES.md` | Llevaba sin tocarse desde el 29 de agosto. A10 pasa a COMPLETADA por el recorrido de `1.2.1+6`; A9 pasa a PARCIAL porque su calendario sí se validó pero sus recordatorios se separaron; se abre **A11 — Notificaciones** con la tabla de los cuatro puntos y su estado real. |
| `CHANGELOG.md` | Se había quedado en `1.2.0`. Se añaden `1.2.1` (que nunca se documentó) y `1.3.0`. |
| `DECISIONES_PRE_A0.md` | Se precisa el alcance post-MVP bajo la línea original, sin borrarla. |
| `ESTADO_ACTUAL.md` | Esta entrada y las dos anteriores del día. |

**Alcance post-MVP acotado por el usuario.** La lista original decía
«Personajes, Tienda, Inventario, loadouts, servidor y sincronización quedan
post-MVP». El usuario quiere **Personajes, Tienda e Inventario, y solo eso**.
Loadouts, servidor y sincronización quedan **descartados**, no aplazados: la
aplicación seguirá siendo local-first y de un solo usuario por decisión.

**Orden acordado: notificaciones primero.** No se abre Personajes/Tienda hasta
cerrar A11. Los puntos 2, 3 y 4 **no se han empezado a propósito**: el punto 1
está en un APK que va camino del teléfono, y la regla de no apilar cambios sobre
un APK bajo prueba física sigue vigente. Escribir el resumen diario ahora haría
que, si algo falla en el recorrido, no se supiera a qué atribuirlo.

**Commits de la sesión:**

| Commit | Contenido |
|---|---|
| `73134ba` | `docs(estado)`: la decisión del espejo (Opción A) y el hallazgo de la clave foránea. |
| `3026fd7` | `feat(notificaciones)`: el punto 1 completo. 737 líneas, 11 ficheros. |

**Incidente al compilar la release, con solución conocida.** `assembleProdRelease`
falló con `package dev.flutter.plugins.integration_test does not exist` en
`GeneratedPluginRegistrant.java`. **No lo causaron los cambios de código.** Ese
fichero está en `android/.gitignore` y se regenera; las compilaciones debug y las
pasadas de `flutter test` de hoy lo dejaron con `integration_test` dentro, que es
dependencia de desarrollo y no existe en el classpath de release.
`.flutter-plugins-dependencies` lo marca bien (`dev_dependency: true`), así que
el fichero estaba simplemente obsoleto. **Solución:** borrar
`android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java` y
volver a compilar; Flutter lo regenera en contexto release. Si vuelve a pasar,
es esto, no una regresión.

**Verificaciones de la candidata `1.3.0+7`, sobre el APK ya construido:**

- `versionCode=7`, `versionName=1.3.0`.
- Permisos: `USE_BIOMETRIC`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`,
  `USE_FINGERPRINT` y el de receptor dinámico de Flutter. **Sigue sin
  `INTERNET`.**
- `BootAlarmRestoreReceiver` presente en el manifiesto del APK, `enabled=true`,
  `exported=true`.
- **Firma idéntica a la de `1.2.1+6`**: SHA-256 `a6092c6c…16b8` en ambos. Se
  instalará como actualización y conservará los datos.

**Recorrido físico pendiente para `1.3.0+7`:**

1. Instalar encima de `1.2.1+6`. **No desinstalar nada.**
2. Comprobar que los datos siguen ahí (misiones, bitácora, economía).
3. Ajustes → Notificaciones: leer el panel nuevo «Después de reiniciar el
   teléfono» y ver que su texto cambia al conmutar «mostrar detalles».
4. **La prueba que importa:** programar una misión con hora cercana, reiniciar
   el teléfono, y esperar sin abrir la aplicación. Debe llegar el aviso, con
   texto genérico.
5. Abrir la aplicación y comprobar que los avisos posteriores vuelven a mostrar
   el título si «mostrar detalles» está activo.

### 2026-09-07 (segunda parte) — Punto 1: reponer alarmas tras reinicio

**Rama:** `main`. Implementación del punto 1 del plan de notificaciones, ya
desbloqueado por la decisión de la primera parte de esta sesión.

**Ficheros nuevos (Kotlin):**

| Fichero | Contenido |
|---|---|
| `MissionAlarmScheduler.kt` | Programar y cancelar alarmas, extraído de `MissionNotificationBridge`. Existía atado a la `Activity`; el receiver de arranque no tiene Activity, solo contexto de aplicación. Mantiene `setAndAllowWhileIdle`. |
| `BootAlarmMirror.kt` | El espejo cifrado fuera de la base. AES/GCM con clave de AndroidKeyStore **sin** `setUserAuthenticationRequired`, formato `v1:iv:ciphertext` y JSON dentro. Mismo patrón que `DatabaseKeyStoreBridge`, a propósito: no se añadió `androidx.security` para no meter una segunda forma de cifrar en el proyecto. |
| `BootAlarmRestoreReceiver.kt` | Repone alarmas en `BOOT_COMPLETED` y `MY_PACKAGE_REPLACED`. Nunca abre la base. Lo vencido mientras el teléfono estaba apagado se entrega al momento; el resto se reprograma. |

**Ficheros modificados:**

| Fichero | Cambio |
|---|---|
| `AndroidManifest.xml` | Permiso `RECEIVE_BOOT_COMPLETED` y el receiver con su `intent-filter`, `exported="true"` (lo exige un broadcast del sistema). |
| `MissionNotificationBridge.kt` | Delega en `MissionAlarmScheduler` y gana el método `syncBootMirror`, que descarta cualquier campo fuera de los cinco acordados: el título ni siquiera se lee. |
| `mission_notification_platform.dart` | Nuevo `MissionNotificationMirrorEntry` y `syncBootMirror` en la interfaz. |
| `method_channel_mission_notification_platform.dart` | Implementa `syncBootMirror`. |
| `notification_reconciliation_service.dart` | Construye el espejo y lo sincroniza en **todas** las salidas de `reconcile()`. |
| `notification_settings_page.dart` | Panel «Después de reiniciar el teléfono» que explica la degradación. |

**Por qué el espejo se reemplaza entero.** `findReconciliationCandidates()` no
tiene ventana temporal: devuelve todas las filas PENDING/SCHEDULED. Así que
`reconcile()` ve el conjunto completo de alarmas vivas y sustituir el espejo es
correcto, además de evitar que queden restos de alarmas ya canceladas. Una
lista vacía lo borra, que es justo lo que debe pasar al apagar las
notificaciones.

**Un fallo del espejo no se traga en silencio.** El informe gana
`bootMirrorSynced`. Un espejo desincronizado no rompe nada hoy, pero significa
que el próximo reinicio pierde recordatorios, así que queda observable en vez
de desaparecer en un `catch` mudo.

**La degradación está contada al usuario, no escondida.** Es el término que se
aceptó al aprobar la Opción A. El panel nuevo de Ajustes cambia su texto según
«mostrar detalles»: con detalles activados avisa de que tras un reinicio los
avisos salen sin título hasta abrir la aplicación; sin detalles, dice
simplemente que se reponen solos.

**Verificación:**

- `flutter analyze`: limpio en todo el proyecto.
- `flutter test`: **225 pruebas verdes**, 3 de ellas nuevas sobre el espejo
  (guarda las alarmas vivas y nunca el título; desactivar notificaciones lo
  vacía; un fallo del espejo se reporta).
- `flutter build apk --debug --flavor prod`: compila.
- Manifiesto **fusionado** verificado: el APK lleva de verdad el permiso, el
  receiver y el `intent-filter` de `BOOT_COMPLETED`.

**Único fallo de la matriz: el golden `sidebar_modular_battery`, preexistente.**
Se comprobó guardando los cambios con `git stash`: falla idéntico sin ellos
(0,26 %, 2676 px). Sigue intacto a propósito, como venía de la sesión anterior.

**Lo que falta para cerrar el punto 1: la prueba física.** Programar un aviso,
reiniciar el teléfono y comprobar que llega. Es la única verificación real; las
pruebas de Dart cubren el contrato, no el comportamiento de Android al
arrancar. Hasta entonces el punto 1 está implementado pero **no validado**.

**No se tocó el esquema.** La decisión sobre dónde vive el resumen diario sigue
aplazada al punto 2, tal y como se acordó.

### 2026-09-07 — Decisiones desbloqueadas para notificaciones

**Rama:** `main`. Sin cambios de código; sesión de lectura, verificación y decisión.

**Verificación del estado real (no solo lo documentado):**

- Árbol limpio, `1.2.1+6`, coincide con el relevo.
- Tres commits de documentación seguían sin subir: `cf4101d`, `69eed05`,
  `62ab819`.
- `AndroidManifest.xml` declara `MissionAlarmReceiver` pero **no** tiene
  `RECEIVE_BOOT_COMPLETED` ni receiver de arranque. El punto 1 del plan es
  trabajo nuevo de Kotlin y manifiesto, confirmado.

**Hallazgo que invalida una opción del relevo anterior.** La columna
`mission_id` de `notification_schedules` es
`NOT NULL REFERENCES missions(id) ON DELETE RESTRICT`
(`app_database.g.dart:5324`). Por tanto el **identificador sintético NO es
viable**: la clave foránea exige una misión que exista de verdad, así que
habría que insertar una misión fantasma en `missions`, que aparecería en
listados, conteos y estadísticas salvo filtrarla en todas partes. Peor que
migrar. Las alternativas reales son dos: migrar v3 → v4 haciendo `mission_id`
nullable, o **sacar el resumen diario de `notification_schedules`** y guardar
hora y último conteo en las preferencias cifradas que ya usa A9.1 — sin
migración y compartiendo mecanismo con el espejo del punto 1.

**DECISIÓN TOMADA — espejo de alarmas: Opción A (espejo completo).**
El usuario **acepta** que un espejo mínimo y cifrado viva fuera de la base para
reponer las alarmas tras un reinicio. Queda cerrada la decisión que bloqueaba
todo el incremento de notificaciones. Términos:

- `EncryptedSharedPreferences` con clave de Keystore que **no** exige
  autenticación de usuario, para poder leerse al arrancar.
- El espejo guarda solo `scheduleId`, `notifyAtUtcMs`, `soundEnabled` y
  `showDetails`. **Nunca el título de la misión** ni ningún otro contenido.
- Se escribe en `reconcile()`, con la app desbloqueada.
- Tras un reinicio y hasta abrir la app, las notificaciones salen con texto
  genérico aunque "mostrar detalles" esté activo. **Esto debe explicarse en la
  pantalla de Ajustes**, no dejarse como sorpresa. Es parte del entregable, no
  un extra.

**Decisión de esquema: aplazada a propósito.** El usuario opta por decidir
dónde vive el resumen diario **al implementar el punto 2**, con el punto 1 ya
cerrado. No se decide por accidente al escribir el primer `INSERT`; se decide
entonces, y entre las dos opciones reales de arriba.

**Siguiente paso acordado:** punto 1 del plan — reprogramar alarmas tras
reinicio. Es el cimiento: sin él, los puntos 2 y 3 se evaporan en cada
reinicio del teléfono.

**Abierto / por recordar:**

- Sigue pendiente del usuario: `git push origin main` y activar "Include
  private contributions on my profile".
- La prueba empírica de reinicio (programar aviso → reiniciar → ver si llega)
  deja de ser curiosidad: será la forma de verificar el punto 1.

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


---

# Parte 2 — Relevos antiguos

## Cabecera del relevo hasta el 3 de octubre de 2026

- Última revisión: **3 de octubre de 2026**
- Versión en `pubspec.yaml`: **`1.7.0+14`** (menú Personaje y esquema v4,
  fase 1 de ADR-006), firmada y **aprobada en la tablet con datos reales** el
  3 de octubre de 2026
- Última versión aprobada en dispositivo: `1.7.0+14`
- Repositorio: [`Nobody2077/Bitacora_movil`](https://github.com/Nobody2077/Bitacora_movil)
- Rama de trabajo: `main` (incluye la fase 1), sincronizada con `origin/main`.
  `main` está abierta en el worktree `G:\Desarrollo\Proyectos\bitacora-main-v3`
- **Siguiente: fase 2 de ADR-006** (Inventario, Ciberware y + Compra). Ver
  «▶ EMPEZAR AQUÍ»
- Lo de abajo de esta lista es historia del MVP (ya cerrado: G8 verde el 30 de
  septiembre)
- **A11 — Notificaciones: COMPLETADA** el 23 de septiembre de 2026. El recorrido
  físico de `1.4.0+8` salió sin incidencias, así que los puntos 2, 3 y 4 quedan
  validados y **G9 cierra con ella**
- En curso: **A8 — Release**, cerrar G8
- **Incidente del 24 de septiembre de 2026:** al lanzar el gate G8 sobre la
  tablet, Flutter **desinstaló la app prod real** con sus datos. Eran datos de
  prueba y la app ya está reinstalada, pero **el gate solo puede correr en un
  dispositivo sin `com.jcyq.bitacorarpg` instalado**, y ahora lo comprueba él
  mismo. Detalle en «Bitácora de sesiones»

> **Si retomas el proyecto, salta a "RELEVO — empezar aquí la próxima
> sesión"**. Dice dónde quedamos, qué está decidido, qué falta y cómo hacerlo,
> incluido el punto de partida de Personajes/Tienda/Inventario. Lo demás es
> historia de referencia.
>
> **Lo primero es el bloque «▶ EMPEZAR AQUÍ»**, al principio del RELEVO: dice
> qué comprobar, qué preguntar al usuario y qué hacer según su respuesta.

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
- Sesión del **7 de septiembre de 2026**: se implementó **A11 — Notificaciones**
  entera. Punto 1 (reponer alarmas tras reinicio) validado en dispositivo con
  `1.3.0+7`; puntos 2 (resumen diario), 3 (aviso de vencimiento) y 4 (texto
  configurable) implementados y a la espera del recorrido de `1.4.0+8`. Se
  decidió que el espejo de alarmas viva fuera de la base (Opción A) y que el
  resumen diario **no** entre en `notification_schedules`, así que **el esquema
  v3 sigue intacto**. El post-MVP quedó acotado a Personajes, Tienda e
  Inventario. Matriz en **237 pruebas**. Detalle completo, con lo decidido y lo
  que queda abierto, en "Bitácora de sesiones".
- Sesión del **13 de septiembre de 2026**: sin cambios de código ni de
  versión. Se corrigió el relevo, que daba por pendientes siete commits ya
  subidos, y se abrió `documentos/ADR-006-PERSONAJES-TIENDA-INVENTARIO.md` en
  estado propuesto. El ADR documenta que el nivel se deriva de `SUM(amount)`
  sobre `xp_transactions` sin filtrar, así que gastar XP de ese libro bajaría
  el nivel al comprar, y deja tres decisiones al usuario (D1 con qué se paga,
  D2 volcado cifrado antes de migrar, D3 una ficha o varias).
- Sesión del **23 de septiembre de 2026**: el recorrido físico de `1.4.0+8`
  salió sin incidencias, así que **A11 queda cerrada y G9 con ella**. El golden
  `sidebar_modular_battery` se resolvió en origen —capturaba la pantalla entera
  con la fecha de hoy dentro, no era antialiasing— y la matriz sube a
  **238 pruebas**. Al abrir A8 se descubrió que el gate G8 llevaba inejecutable
  desde agosto por tres motivos ya corregidos; **el preflight pasa entero por
  primera vez**. G8 sigue rojo solo por falta de dispositivo.
- Sesión del **24 de septiembre de 2026**: primer intento real del gate G8,
  sobre la tablet. MIUI rechazó la instalación de la APK `dev` y **Flutter,
  al recuperarse, desinstaló el paquete prod** con su base cifrada. Los datos
  eran de prueba; se reinstaló `1.4.0+8` con la misma firma. `gate_g8.ps1` y
  `process_restart_g2.ps1` se niegan ahora a correr si el dispositivo tiene
  instalado `com.jcyq.bitacorarpg`. G8 sigue rojo. Después se reescribió
  **ADR-006 con todas las decisiones de producto** (dinero real, mi ficha y
  Contactos, inventario con Equipado, mapa descartado) y la copia de
  seguridad pasó a ser el último bloque del post-MVP.
- Sesión del **24–25 de septiembre de 2026** (continuación): **efectos de
  sonido implementados** en `1.5.0+9`, antes de ADR-006 por decisión del
  usuario. Cinco efectos futuristas CC0, dos interruptores apagados por
  defecto, sin paquete nuevo ni cambio de esquema. 250/250 pruebas; APK
  release firmada y sin `INTERNET`. **Aprobada en la tablet** el mismo día.

---

## RELEVO — empezar aquí la próxima sesión (reescrito el 2026-09-25)

Lee esta sección entera antes de tocar nada. Dice dónde quedamos, qué está
decidido, qué falta y **cómo** hacerlo. Lo demás del documento es historia.

### ▶ EMPEZAR AQUÍ — la próxima sesión, sea cuando sea

> **Actualización del 3 de octubre de 2026 — prevalece sobre todo lo de abajo.**
> - **FASE 1 DE ADR-006 CERRADA.** `1.7.0+14` (release firmada, SHA-256
>   `62db58482512d067c8056b411aed228a26d1cbc5bc43cba222b359d4f07c6095`,
>   misma llave que la instalada) instalada **encima** de `1.6.2+13` en la
>   tablet con datos reales: migración v3 → v4 sin pérdidas y el usuario
>   confirmó «mis datos siguen acá». Preflight A8 verde, 320/320.
> - `feat/v4-fase1` **fusionada en `main`** (avance rápido) el mismo día.
>   Las próximas fases salen de `main` en ramas nuevas.
> - **Siguiente: fase 2** de ADR-006 (Inventario, Ciberware y + Compra).
>   Plan propuesto para la próxima sesión, en orden:
>   **PRIMERO (pedido por el usuario el 3 de octubre): adelgazar este
>   documento.** Pasa de 2050 líneas. Dejar aquí solo lo vigente (estado,
>   «▶ EMPEZAR AQUÍ», reglas en pie, comandos; unas 150–200 líneas), mover
>   «Bitácora de sesiones» intacta a `documentos/HISTORIAL-SESIONES.md` y los
>   relevos viejos o cerrados (Terminal V2, recurrencias, A11, G8) a historia
>   o eliminarlos si ya están en ADR/CHANGELOG. Solo texto, sin código; commit
>   aparte. Desde ahí, cada paso de una fase empieza con una mini-spec de
>   5–10 líneas (qué hace, qué no, cómo se prueba, cuándo se da por bueno)
>   que el usuario aprueba antes de programar.
>   0. Comprobar: `git status` limpio y al día en el worktree de `main`,
>      `flutter analyze` y `flutter test` (320/320). Crear la rama
>      `feat/v4-fase2` desde `main`.
>   1. Preguntar al usuario si ya respaldó la llave de firma.
>   2. **Dependencias (D16):** `flutter_svg` y una biblioteca de iconos MIT
>      (Tabler o Phosphor). Antes de añadir cada una: editor verificado,
>      licencia, permisos del manifiesto fusionado y APK sin `INTERNET`.
>   3. **Datos:** DAO/repositorio de `inventory_items` (estados, categoría y
>      zona fijas, equipar con zona), foto de objeto (`item_photos`; añadir
>      `item` a `PhotoOwnerKind`/`EntityPhotoOwner`) y la unidad de trabajo
>      de **compra** (D1/D12): gasto `EXPENSE` en `transactions` **y** objeto
>      en el inventario, todo o nada, idempotente por `operation_id`.
>   4. **Pantallas:** CIBERWARE (silueta `escaner_corporal.svg` del usuario,
>      en `G:\Usuario\Downloadss\`, puntos por zona y línea de escaneo) e
>      INVENTARIO (ropa por zona, avatar fijo con prendas como iconos,
>      mochila); barras laterales de capacidad y resiliencia (D8, solo
>      avisan); botón **+ Compra** en la cabecera con el saldo bajando en
>      naranja (D12; sin animar con movimiento reducido, enmascarado con
>      importes ocultos).
>   5. Versión `1.8.0`, APK, instalación encima en la tablet y aprobación.
>   Cada paso, como en la fase 1: pruebas, `dev` en la tablet, aprobación y
>   commit.
> - **Instalar en la tablet:** `adb install -r` falla casi siempre con
>   `INSTALL_FAILED_USER_RESTRICTED`. Intentarlo una vez; si falla, `adb
>   push` a `/sdcard/Download/`, aviso al escáner de medios, que el usuario
>   instale desde el gestor de archivos, y borrar la APK después.
> - **Sigue pendiente:** respaldo de la llave de firma (dos sitios fuera del
>   PC) y mejorar los audios.
>
> **Actualización del 1 de octubre de 2026. La fase 1 de ADR-006 está en la rama `feat/v4-fase1`; ver «▶ FASE 1 — dónde quedó».**
> - **G8 VERDE: el MVP está cerrado.** Validado solo con la tablet (decisión
>   del usuario: no tiene teléfono). Gate, métricas, release `1.5.0+9`
>   firmada y verificada, recorrido manual, logcat y `install -r` con datos:
>   todo en verde. Detalle y hashes en `documentos/A8-VALIDACION-RELEASE.md`.
> - La tablet **ya instala por USB**, pero cada instalación pide confirmación.
>   Tiene la release con datos de uso real desde hoy: **no lanzar el gate ni
>   `flutter test` sobre ella** sin preguntar.
> - **La llave de firma sigue sin respaldo** (el usuario lo confirmó hoy).
> - Siguiente trabajo acordado, en orden:
>   1. ~~`1.5.1+10`~~ **Hecho y aprobado en la tablet el 1 de octubre de 2026**:
>      copiar/pegar el código de recuperación (ADR-002 §4.1) y botón «Salir»
>      bajo Ajustes. Instalada en la tablet con datos reales.
>   1b. ~~`1.6.0+11`~~ **Hecho y aprobado el 1 de octubre de 2026**: sonidos de
>      acceso (tecla del PIN igual para todas, carga que se corta, PIN
>      incorrecto) con su propio interruptor. La paleta llega a 8 efectos, el
>      tope del criterio 6 de PROPUESTA-SONIDO.
>   1c. ~~`1.6.1+12` y `1.6.2+13`~~ **Hechas y aprobadas el 1 de octubre**:
>      sonidos de acceso elegidos por escucha (la carga usa un sonido local de
>      prueba, ignorado por Git, que **nunca se sube**) y pantalla completa
>      (modo inmersivo, interruptor en Apariencia). Pendiente: la carga suena
>      baja; se mejorarán los audios más adelante.
>   2. **ADR-006 ACEPTADO el 1 de octubre de 2026** (`ecccec9` en `main`),
>      alcance de v4 congelado. **Fase 1 EN CURSO en la rama
>      `feat/v4-fase1`** (no fusionada en `main`).
>
> ### ▶ FASE 1 — dónde quedó (1 de octubre de 2026)
>
> **Hecho y probado (rama `feat/v4-fase1`):**
> - `schema.drift`: 14 tablas nuevas (`contacts`, `contact_photos`,
>   `mission_contacts`, `journal_entry_contacts`, `mission_photos`,
>   `inventory_items`, `item_photos`, `projects`, `project_items`,
>   `craft_operations`, `craft_component_ledger`, `reward_specs`,
>   `reward_spec_costs`, `reward_vouchers`) y `location` en `missions` y
>   `mission_templates`, al final de cada tabla como la deja `ALTER TABLE`.
> - `app_database.dart`: `schemaVersion = 4`; el paso `from <= 3` solo añade
>   (dos `addColumn` y `create` de las entidades de `_schemaV4Entities`).
> - `drift_schemas/drift_schema_v4.json` generado con el **procedimiento
>   controlado** (pubspec temporal con `drift: 2.34.0`, `schema dump`,
>   restaurar `pubspec.yaml` y `pubspec.lock` copiados). Subir `drift_dev` no
>   es posible con Flutter 3.41.5 (`meta 1.17.0`); comprobado.
> - Pruebas: `schema_migration_v3_to_v4_test.dart` (cada fila v3 idéntica tras
>   migrar; reabrir no remigra), v1→v4 y v2→v4, `schema_contract_test` (33
>   tablas, 34 índices, 43 FK exactas), snapshot v4 y
>   `schema_constraints_v4_test.dart` (un caso que falla por cada regla
>   nueva). Ayudante común: `schema_v4_expectations.dart`.
>   **276/276, `analyze` limpio.**
> - Aún **no hay** pantallas para las tablas nuevas, y la versión sigue en
>   `1.6.2+13`. La capa de datos de personajes ya existe (ver punto 2).
>
> **Pendiente de la fase 1, en este orden:**
> 1. **Prueba de migración en la tablet con el flavor `dev`** (ADR-006 D2),
>    antes de que v4 toque la app real. El flavor `dev` es otro paquete
>    (`com.jcyq.bitacorarpg.dev`), así que no toca los datos de prod:
>    1. ~~Instalar `dev` v3~~ **Hecho el 1 de octubre de 2026**: compilada desde
>       `main` en el worktree `G:DesarrolloProyectositacora-main-v3` e
>       instalada con `adb install` (nunca `flutter test`/`flutter run`). La
>       prod siguió intacta en `1.6.2`.
>    2. El usuario crea misiones, movimientos y una entrada con foto.
>    2–3. **Hecho el 1 de octubre de 2026**: el usuario creó PIN, misiones,
>       ingreso, gasto y entrada con foto en `dev` v3; se instaló encima la
>       `dev` v4 de esta rama (`adb install -r`, `firstInstallTime` intacto) y
>       el usuario confirmó «datos bien». **Ensayo de D2 superado.**
> 2. ~~**Datos**~~ **Hecho el 3 de octubre de 2026**, subido a GitHub en esta rama.
>    **312/312, `analyze` limpio.** Qué hay y dónde:
>    - `ContactDao` + `features/contacts/` (modelo, repositorio, servicio,
>      proveedores): crear (idempotente por id), editar con `row_version`,
>      archivar/restaurar; listas activos/archivados; personajes por misión,
>      por entrada (los suyos **más** los de su misión, sin repetir) y
>      misiones/entradas de un personaje.
>    - Vínculos: `contact_link_support.dart`. Se escriben **dentro** de la
>      transacción de la misión o la entrada (`contacts:` en
>      `MissionDao.insertAggregate/updateAggregate` y
>      `JournalDao.insertAggregate/updateEntry`; `null` = no tocar). Solo los
>      vínculos **nuevos** exigen personaje activo
>      (`InactiveContactLinkException`); archivar no quita a nadie de sus
>      misiones. Máximo 50 por registro.
>    - `SaveMissionRequest` y `SaveJournalEntryRequest` llevan `contactIds`
>      (`null` al editar = sin cambios); la misión y la plantilla recurrente
>      llevan `location` (1–120, en blanco = sin ubicación) y la plantilla la
>      copia a cada misión generada o tomada del tablón. **Ojo para el paso
>      4**: el formulario de misión aún no envía `location`, así que al
>      editar la borraría; hay que pasarla cuando se añada el campo.
>    - Fotos de personaje y misión: `EntityPhotoDao` (una vigente; cambiarla
>      archiva la anterior en la misma transacción; `revertReplacement` si el
>      fichero no se confirma) y `features/photos/`. Se cifran en su **propia
>      carpeta y clave `entity_photos`**, añadida a la lista permitida de
>      `DatabaseKeyStoreBridge.kt` (sin eso, la release rechazaría la clave;
>      la debug no lo nota). El cifrado de Bitácora pasó a
>      `infrastructure/photos/encrypted_photo_vault.dart` sin cambiar
>      carpeta, clave ni formato. La limpieza de huérfanos de `entity_photos`
>      (`entityPhotoCleanupProvider`) aún no se dispara: lo hará la pantalla
>      de Personajes.
> 3. **Pantallas**: entrada **Personaje** en la barra lateral con las cinco
>    pestañas (CIBERWARE e INVENTARIO vacías hasta la fase 2, MAPA
>    «aplazado», PERSONAJE con el hexágono de áreas y el panel lateral,
>    DIARIO = la Bitácora renombrada solo en lo visual + Personajes con su
>    ficha y «+ Crear personaje»). La Bitácora convive en la barra lateral
>    hasta que el usuario confirme que DIARIO la sustituye.
>    **Hecho y aprobado el 3 de octubre de 2026** (317/317, `analyze`
>    limpio, `5c8f637`): instalado en la tablet como `dev` encima de la
>    anterior (`firstInstallTime` intacto, prod intacta) y el usuario dijo
>    «se ve bien». `adb install` volvió a dar `INSTALL_FAILED_USER_RESTRICTED`
>    dos veces; se instaló desde Descargas. Qué hay:
>    - Rutas nuevas (área `character`, rama 7 del shell): `/character`
>      (`?tab=ciberware|inventario|mapa|personaje|diario`, abre en
>      PERSONAJE), `/character/contacts/new`, `…/:contactId` y
>      `…/:contactId/edit`. 61 rutas. En la barra lateral va **cuarta**
>      (`_railBranches` en `adaptive_shell.dart` traduce posición → rama); en
>      teléfono está en «Más». Golden `sidebar_modular_battery` regenerado a
>      propósito (una entrada más).
>    - `features/character/presentation/`: menú con NIVEL, REPUTACIÓN («--»
>      hasta la fase 3), saldo disponible y las cinco pestañas; hexágono
>      (`CustomPainter`, todas las áreas visibles, máx. 8, las sin XP en
>      nivel 1) y panel (nivel, reputación pendiente, constancia, títulos).
>      **Sin «+ Compra»** (fase 2) ni «tiempo registrado» (no hay dato global).
>    - DIARIO: ENTRADAS = `JournalTimelinePage(title: 'Diario')` con
>      miniaturas de personajes en cada tarjeta; PERSONAJES = cuadrícula,
>      archivados, ficha (foto, editar, quitar foto, «Eliminar» = archivar,
>      restaurar, misiones y entradas donde aparece) y formulario. La foto se
>      pone desde la ficha (necesita que el personaje exista).
>    - Formulario de entrada: selector de personajes (solo los propios; los de
>      la misión se suman al leer). Detalle de entrada: panel «Personajes».
> 4. **Misiones**: elegir personajes y ubicación al crear, foto opcional y
>    tarjeta con foto y miniaturas de personajes.
>    **Hecho y aprobado el 3 de octubre de 2026** (320/320, `ae08ba7`):
>    instalado como `dev` desde Descargas (`adb install` falló otra vez) y
>    el usuario dijo «funciona bien». Qué hay:
>    - Formulario de misión: panel «Lugar y personajes» con ubicación y
>      selector de personajes. Al editar, la ubicación se precarga (ya no se
>      borra) y los personajes solo se reescriben si se tocan. Una diaria
>      nueva se guarda como plantilla, que no tiene personajes: solo ofrece
>      ubicación. El formulario de plantilla recurrente también tiene
>      ubicación.
>    - Detalle de misión: panel «Lugar, foto y personajes» con añadir,
>      cambiar o quitar foto (no en archivadas) y miniaturas que abren la
>      ficha. La foto se pone desde el detalle, como en los personajes.
>    - Tarjetas de Hoy y de las colecciones: `MissionContextStrip` con foto,
>      ubicación y miniaturas; no ocupa sitio si la misión no tiene nada.
>    - Acciones de foto comunes en `photos/presentation/entity_photo_actions.dart`
>      (las usan la ficha de personaje y el detalle de misión).
>    - Aplazado a la fase 3 (proyectos): la foto de respaldo «del objeto que
>      se arma o del primer elemento del proyecto» de D15.
> 5. Versión `1.7.0`, APK, instalación **encima** en la tablet (con datos
>    reales) y aprobación del usuario. Después, fusionar la rama en `main`.
>    **Hecho y aprobado el 3 de octubre de 2026** y fusionado en `main`
>    (ver «▶ EMPEZAR AQUÍ»).
>
> Referencias: ADR-006 (contrato), maqueta privada «Bitácora · Personaje» v5
> (solo orientativa), `escaner_corporal.svg` del usuario en
> `G:\Usuario\Downloadss\` (fase 2).
>
> **Otros pendientes vivos:** respaldo de la llave de firma; mejorar los
> audios (la carga suena baja y usa un sonido local de prueba que **nunca se
> sube**: `res/raw/ui_access_loading_test.mp3`, en `.gitignore`).

**Estado al cerrar el 25 de septiembre de 2026:** `main` limpia y sincronizada
con `origin/main`. Versión **`1.5.0+9`** (efectos de sonido) instalada en la
tablet y **aprobada por el usuario**. 250/250 pruebas, `flutter analyze`
limpio. Lo único abierto del MVP es **G8**, bloqueado por el dispositivo, no
por código.

**Paso 0 — comprobar que nada cambió (2 minutos, lo hace el agente).**

```powershell
git status -sb            # debe decir: ## main...origin/main, sin cambios
git log --oneline -1      # el último commit de esta sesión, o uno posterior
flutter analyze           # No issues found!
```

Si hay commits posteriores a los del 25 de septiembre, lee primero su entrada
en «Bitácora de sesiones»: este bloque puede haberse quedado atrás.

**Paso 1 — preguntar al usuario dos cosas antes de nada.** Condicionan qué se
hace después y no se pueden deducir del código:

1. **¿Respaldó la llave de firma?** `android/signing.properties` y
   `C:\Users\Usuario\.android\bitacora-rpg-release.jks`, **los dos**, en dos
   sitios fuera del PC. Es lo único irreparable del proyecto. Si no, recordarlo
   primero.
2. **¿Ha metido ya datos reales en la tablet?** El usuario decidió el 24 de
   septiembre usarla **como dispositivo principal**. Si ya tiene datos, **no
   sirve para G8**: el gate exige un dispositivo sin `com.jcyq.bitacorarpg` y
   desinstalar borraría esos datos sin vuelta atrás. Entonces G8 necesita otro
   equipo limpio (su teléfono u otro), y el criterio de «teléfono y tablet
   físicos» tendría que revisarse con él. **No desinstalar nada sin su
   confirmación explícita.**

**Paso 2 — elegir el trabajo del día según las respuestas.** `adb` no está en
el PATH: usar `C:\Users\Usuario\AppData\Local\Android\Sdk\platform-tools\adb.exe`.

- **Si hay un dispositivo limpio disponible → G8.** Antes de lanzar el gate,
  comprobar que HyperOS acepta instalar por USB con una prueba inofensiva que
  no pase por Flutter:

  ```bash
  adb -s <serial> install build/app/outputs/flutter-apk/app-dev-debug.apk
  # si no existe: flutter build apk --debug --flavor dev -t lib/main_dev.dart
  ```

  Si responde `INSTALL_FAILED_USER_RESTRICTED`, **no lanzar el gate**: el
  usuario tiene que resolverlo en el dispositivo (cuenta Mi con sesión
  iniciada, conexión a internet, reactivar «Instalar vía USB» y, si no basta,
  desactivar la optimización de MIUI). Cuando la prueba pase, entonces sí:
  `powershell -ExecutionPolicy Bypass -File tool/gate_g8.ps1 -DeviceId <serial>`.
  El gate aborta solo si encuentra la app prod instalada.
- **Si no hay dispositivo limpio → ADR-006, diseño del esquema v4.** No
  necesita dispositivo y no es código de producción. Leer
  `documentos/ADR-006-PERSONAJES-TIENDA-INVENTARIO.md` (decisiones D1–D5 ya
  resueltas, **no reabrirlas**) y producir sus tres pendientes:
  1. Tablas concretas: contactos, vínculo misión–contacto (N:M), objetos de
     inventario, zona del cuerpo para Equipado, fotos cifradas (reutilizando el
     patrón de `journal_attachments`) y la columna «ubicación» de texto en
     `missions`. Preguntar al usuario si categorías y zonas del cuerpo son
     lista cerrada o configurables.
  2. Comprobar si `drift_dev` puede generar `drift_schema_v4.json` (ADR-001
     §13 documenta que falló con v1). No editar el JSON a mano.
  3. Plan de migración v1→v4, v2→v4 y v3→v4 con sus pruebas.

  **El código de ADR-006 no empieza hasta cerrar G8**, y la migración irá sin
  copia de seguridad (riesgo aceptado por el usuario, ADR-006 D2).

**Instalar una APK nueva en la tablet.** HyperOS 3 rechaza hoy toda
instalación por USB. La vía que funciona: `adb push` de la APK a
`/sdcard/Download/`, avisar al escáner de medios
(`adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Download/<nombre>.apk`)
y que el usuario la instale desde el gestor de archivos. En Git Bash, prefijar
con `MSYS_NO_PATHCONV=1` o las rutas `/sdcard` se reescriben.

### Estado en una línea

**MVP casi cerrado: solo falta G8**, con el preflight verde y la protección
contra borrar la app prod ya en el gate. Post-MVP: **sonido hecho y aprobado**
(`1.5.0+9`); **ADR-006** con decisiones de producto resueltas y sin esquema;
**copia de seguridad** al final de todo.

### Qué se subió el 24 y 25 de septiembre de 2026

- `2c5e9b2 fix(gate)` — el gate y `process_restart_g2.ps1` abortan si la app
  prod está instalada, tras el incidente de la tablet.
- `f399173 docs(adr-006)` — decisiones D1–D5 y la copia de seguridad al final,
  anotada en todos los `.md` que citan A6.
- `0724f20 feat(sonido)` — efectos de sonido, candidata `1.5.0+9`.
- `886f22a docs(sonido)` — aprobación física de `1.5.0+9`.
- Más dos commits de solo documentación: sincronización y este relevo.

### A8 / G8: qué falta de verdad

El 23 de septiembre de 2026 se desbloqueó el gate, que llevaba inejecutable
desde agosto sin que nadie lo supiera. Tres cosas lo impedían y las tres están
arregladas:

1. **`flutter test` estaba rojo** por el golden `sidebar_modular_battery`, así
   que `quality.ps1` abortaba y el preflight nunca pasaba de ahí. Resuelto: ver
   la tabla de deudas.
2. **`a8_preflight.ps1` exigía `schemaVersion => 1`.** La aserción se escribió
   en agosto y el esquema va por **v3** desde A10, así que fallaba en su primera
   comprobación. Ahora lee la versión declarada y exige que exista su snapshot
   en `drift_schemas/drift_schema_v<N>.json`, de modo que no vuelva a quedarse
   atrás en la próxima migración.
3. **El barrido de `print`/`debugPrint` invocaba `rg`**, que no está en el PATH
   de PowerShell. Sustituido por `Select-String`, sin herramientas externas.

Con eso, `tool/a8_preflight.ps1` pasa entero: formato, `build_runner`,
`analyze`, **238/238 pruebas**, registro de plugins y `:app:lintProdRelease`
con `BUILD SUCCESSFUL`.

**Lo que queda es material, no de código:**

- **Un dispositivo limpio por ADB en el que HyperOS deje instalar.** Desde el
  24 de septiembre la tablet conecta por USB (serial `biuonrrcey45lvrs`,
  Xiaomi `25040RP0AL`, HyperOS 3, Android 16), pero **tiene la app prod
  instalada**, es ya el dispositivo principal del usuario y **HyperOS rechaza
  toda instalación por USB**. Ver el paso 1 y el paso 2 de «▶ EMPEZAR AQUÍ».
- **Los dos factores de forma se mantienen.** El usuario confirmó el 23 de
  septiembre de 2026 que **tiene tablet real**, así que el criterio de cierre no
  se acota ni se sustituye por un emulador. Si la tablet queda como dispositivo
  de uso real, esto hay que volver a hablarlo con él.
- **Candidata actual: `1.5.0+9`**, no `1.4.0+8`. Su AAB aún no existe; el gate
  construye y verifica APK y AAB en la misma pasada.
- **El respaldo de la llave sigue pendiente** y es lo único irreparable.

Cuando haya dispositivo, el paso es uno solo, por cada equipo:

```powershell
powershell -ExecutionPolicy Bypass -File tool/gate_g8.ps1 -DeviceId <serial-adb>
```

**Solo en un dispositivo SIN la app prod instalada.** Hasta el 2026-09-24 este
párrafo decía que instalar el flavor `dev` era seguro. **No lo es:** si esa
instalación falla, Flutter puede desinstalar `com.jcyq.bitacorarpg` por su
cuenta, y así borró la instalación de la tablet (ver la entrada de sesión del
2026-09-24). Desde entonces el gate lo comprueba y aborta si el paquete prod
está presente. No añadirle un interruptor para saltarlo.

En Xiaomi, `adb install` puede fallar con `INSTALL_FAILED_USER_RESTRICTED`
aunque «Instalar vía USB» esté activado; hay que resolverlo antes de lanzar el
gate.

### El recorrido de `1.4.0+8`, ya HECHO el 2026-09-23

Se conserva porque describe qué se validó exactamente. Se instaló **encima** de
`1.3.0+7`, sin desinstalar, y los cinco pasos salieron correctos.

1. Datos intactos: misiones, bitácora, economía.
2. **Resumen diario:** Ajustes → Notificaciones → activar «Resumen diario» y
   ponerlo unos minutos por delante. Debe llegar **un solo** aviso con el
   recuento.
3. **Texto configurable:** cambiar «Texto sin detalles», dejar «mostrar
   detalles» apagado, programar una misión y comprobar que el aviso usa el
   texto nuevo.
4. **Aviso de vencimiento:** crear una misión **con hora y con vencimiento**
   cercano. Deben llegar **dos** avisos: inicio y plazo.
5. **Regresión del punto 1:** con el resumen activado, reiniciar el teléfono.
   Debe seguir llegando, pero diciendo «Abre Bitácora para ver tu resumen de
   hoy» en lugar del número: el recuento no vive en el espejo. **Eso es
   correcto, no un fallo.**

### Lo que el usuario debe hacer (pendiente de su lado)

1. **Respaldar la llave de firma. Es lo único irreparable del proyecto.**
   Son **dos ficheros en dos sitios distintos**, y hacen falta los dos:
   - `android/signing.properties`, dentro del repositorio pero ignorado por
     git, que contiene las contraseñas.
   - `C:\Users\Usuario\.android\bitacora-rpg-release.jks` (4.460 bytes), que
     es a donde apunta `storeFile`.

   Copiar ambos a dos sitios fuera del PC. Si se pierden, no se podrá volver a
   actualizar la aplicación nunca: la única salida sería desinstalar, que borra
   todos los datos **y las claves de AndroidKeyStore que los descifran**.
   Se arrastra como pendiente desde A8.
2. **Conectar un dispositivo por ADB** para poder cerrar G8. La tablet ya
   conecta por USB desde el 24 de septiembre de 2026, pero el gate exige que
   **no tenga la app prod instalada** y MIUI aún rechaza `adb install`. Es lo
   único que bloquea el MVP.
3. Opcional: activar «Include private contributions on my profile» en
   <https://github.com/settings/profile>. **El usuario lo dejó apagado el
   2026-09-07 creyendo que haría público el repositorio; no es así:** solo hace
   que los commits cuenten en el gráfico, sin revelar nombre ni contenido. El
   repositorio sigue privado. Queda a su criterio, ya sin el malentendido.

### Qué viene después, en orden

**1. Cerrar A8 / G8.** Es lo único abierto del MVP. Ver «A8 / G8: qué falta de
verdad» arriba: el preflight está verde y solo falta el dispositivo.

**2. Personaje, Contactos, Inventario y Tienda (ADR-006).** Solo después de 1.
Decisiones de producto ya resueltas; falta el esquema concreto.

**3. Copia de seguridad.** Último bloque del post-MVP, por decisión del
usuario del 2026-09-24 (ADR-006 D2, adenda de ADR-005).

### Personaje, Contactos, Inventario y Tienda — estado de ADR-006

**`documentos/ADR-006-PERSONAJES-TIENDA-INVENTARIO.md` se reescribió el
2026-09-24 con todas las decisiones del usuario.** Sigue «propuesto» solo por
lo técnico: esquema concreto, snapshot v4 y plan de migración. **Leerlo antes
de retomar; no reabrir las decisiones.** Resumen, tomando como referencia el
menú de *Cyberpunk 2077* que el usuario aportó en capturas:

- **D1 — dinero real.** Cada compra de la Tienda es un `EXPENSE` en
  `transactions` y crea un objeto en el inventario. El XP no se gasta, así que
  el problema de `progress_dao.dart:173` (comprar bajaría el nivel) desaparece.
- **D2 — copia al final.** La migración v3 → v4 se hace **sin copia**, con el
  riesgo aceptado por escrito. Anotado en todos los `.md` que citan A6.
- **D3 — Personaje = mi ficha + Contactos.** Mi ficha es un hexágono con cada
  **área de vida como atributo**, que sube **solo con el XP** (sin puntos
  manuales), y el nivel global al centro: sin tabla nueva. **Contactos** son
  personas reales (nombre, descripción, foto; todo opcional y editable), en
  pestaña propia dentro de Personaje, **varias por misión**; se ven como
  miniaturas en el detalle de la misión y en «Mostrar más detalles».
- **D4 — Inventario de pertenencias**, compradas o añadidas a mano, por
  categoría y con foto, más **Equipado**: una silueta con zonas del cuerpo
  para los accesorios que lleva puestos (una zona por objeto, **no loadouts**).
- **D5 — Mapa descartado** (exigiría `INTERNET`). Queda un campo
  **«Ubicación» de texto** en la misión.

### Decisiones ya tomadas que NO se reabren

- **Espejo de alarmas: Opción A**, aceptada el 2026-09-07. Espejo mínimo
  cifrado fuera de la base, con `scheduleId`, `systemNotificationId`,
  `notifyAtUtcMs`, `soundEnabled`, `showDetails` y `kind`. **Nunca el título ni
  el recuento.** Detalle en la sección «Decisión RESUELTA» más abajo.
- **El resumen diario vive fuera de `notification_schedules`**, en las
  preferencias cifradas. El esquema v3 no se toca. Razones en la entrada
  «2026-09-07 (quinta parte)». *Es reversible si el usuario prefiere migrar,
  pero él no llegó a responder al cuadro de decisión: se siguió la
  recomendación. Confirmarlo si surge.*
- **Alarmas exactas descartadas** por consumo de batería. Se mantiene
  `setAndAllowWhileIdle`. Un aviso a las 6:07 en vez de las 6:00 es aceptable.
- **El receiver nunca abre la base cifrada** (ADR-002).
- **Post-MVP acotado** a Personajes, Tienda e Inventario.

### Deudas anotadas, con su estado

| Deuda | Estado | Qué hacer |
|---|---|---|
| Golden `sidebar_modular_battery` falla | **RESUELTA** el 23 de septiembre de 2026 | No era antialiasing. `matchesGoldenFile` sobre un `Finder` captura el `RepaintBoundary` más cercano, y `TerminalSidebar` no tenía ninguno: fotografiaba la pantalla entera, con la fecha de hoy dentro. Por eso fallaba **todos los días salvo el de su regeneración**, y el diff crecía o menguaba con la longitud del nombre del día (0,26 % el 15 de septiembre, 0,45 % el 23). Se añadió `RepaintBoundary` en `TerminalSidebar` y se regeneró: ahora captura los 248 px de la barra y nada más. |
| Columna muerta `app_settings.daily_summary` | Mapeada y expuesta en `AppPreferences`, **no decide nada** | O se cablea o se retira. **No** se reutilizó como interruptor del resumen porque su valor por defecto es verdadero y lo habría activado a todo el mundo sin pedirlo. Tener dos cosas llamadas «resumen diario» confunde. |
| Descubrimiento al crear misiones | **No es tarea**: el usuario decidió conservar la disposición actual | Reabrir solo si él lo pide. Detalle en la entrada del 2026-09-06. |
| Refactor aplazado hace varias sesiones | Sigue aplazado | Estaba condicionado a cerrar los cambios funcionales en curso. Con A11 cerrada, se puede replantear. |
| «Commit 2» perdido de una sesión antigua | Sin reconstruir | Contenido desconocido. Si nadie lo echa en falta, se da por muerto. |
| Métricas cifradas y respaldo de firma (A8) | Pendientes | Bloquean G8. |

### Reglas de trabajo vigentes

- **Nunca instalar un APK `prod-debug` sobre la `prod-release` instalada.** El
  flavor `prod` no tiene sufijo de applicationId, así que son la misma
  aplicación firmada con llaves distintas: Android rechaza la instalación. El
  peligro es desinstalar para forzarlo, porque eso borra la base cifrada **y
  las claves de AndroidKeyStore que la descifran**; ni una copia del fichero
  serviría. Para probar sin riesgo: `--flavor dev`, que se instala al lado con
  sufijo `.dev` y datos propios. Para probar de verdad: release firmada con la
  versión subida, comprobando antes con
  `apksigner verify --print-certs` que el SHA-256 coincide con el instalado.
- **Nunca lanzar `flutter test`, `flutter drive`, `flutter run` ni el gate G8
  contra un dispositivo con la app prod instalada.** Aunque sea `--flavor dev`:
  si la instalación falla, Flutter puede desinstalar el paquete prod. Ocurrió
  el 2026-09-24. Y tras cualquier fallo en dispositivo, comprobar con
  `adb shell pm path com.jcyq.bitacorarpg` antes de afirmar que la app sigue
  intacta.
- **No apilar cambios sobre un APK que esté bajo prueba física.** Mientras
  código y dispositivo coincidan, cada anomalía es atribuible sin ambigüedad.
- **Documentar cada sesión** en «Bitácora de sesiones», entrada nueva arriba.
- Antes de compilar release, si falla con
  `package dev.flutter.plugins.integration_test does not exist`: borrar
  `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`
  y repetir. Es un fichero generado que las compilaciones debug dejan obsoleto,
  no una regresión.
- Los ficheros Kotlin del repositorio están en CRLF tras pasar por git. Las
  sustituciones con `perl -0pi` que usen `\n` **no casan**: usar `\r?\n` o
  reescribir el fichero entero.

### Mapa rápido de lo que se tocó en A11

| Fichero | Papel |
|---|---|
| `BootAlarmMirror.kt` | El espejo cifrado fuera de la base. AES/GCM con clave de AndroidKeyStore **sin** autenticación de usuario, para poder leerse al arrancar. |
| `BootAlarmRestoreReceiver.kt` | Repone alarmas en `BOOT_COMPLETED` y `MY_PACKAGE_REPLACED`. Nunca abre la base. |
| `MissionAlarmScheduler.kt` | Programar y cancelar, extraído del bridge porque el receiver no tiene Activity. |
| `MissionAlarmReceiver.kt` | `EXTRA_CONTENT_TEXT`: si viene texto cocinado desde Dart, se usa tal cual. |
| `reminder_preferences.dart` | Anticipación, horario silencioso, resumen diario y texto genérico. Todo en metadata cifrada, sin tocar el esquema. |
| `notification_reconciliation_service.dart` | El centro: programa, dispara, cancela, cocina el texto, calcula el resumen y sincroniza el espejo. |
| `mission_dao.dart` | `_replaceNotificationIntents`: reemplazo de intenciones por tipo, ya no fijado a `START`. |
| `drift_mission_repository.dart` | `_startNotification` y `_expiryNotification`. |

---


## Historia: el relevo anterior y su razonamiento

Lo que sigue se conserva porque explica **por qué** se decidió lo que se
decidió. Ya no es la guía de trabajo: esa es la sección RELEVO de arriba.

### Decisión RESUELTA (2026-09-07) — el receiver de arranque y la base cerrada

> **Resuelta: el usuario eligió la Opción A, espejo completo.** Lo que sigue se
> conserva como registro del razonamiento y de los términos aceptados. El
> recordatorio en Ajustes sobre el texto genérico tras un reinicio forma parte
> del entregable.

**El problema.** Android borra todas las alarmas de `AlarmManager` al reiniciar
el teléfono. Un receiver de `BOOT_COMPLETED` puede reponerlas, pero al arrancar
el usuario **no ha introducido el PIN**, y por ADR-002 la base está cifrada y
cerrada mientras la sesión está bloqueada. El receiver **no puede leer
`notification_schedules`** para saber qué reprogramar.

El sistema actual ya esquiva esto para las notificaciones normales: el texto se
precocina en Dart con la app abierta y viaja por el canal hasta el receiver, que
nunca toca la base (`MissionAlarmReceiver.kt:76`). Pero tras un reinicio no
queda nada que precocinar: las alarmas murieron y su contenido vivía en ellas.

Hace falta guardar algo **fuera de la base** para poder reponerlas. Qué
exactamente es la decisión.

**Opción A — Espejo mínimo cifrado (recomendada).**
Al ejecutarse `reconcile()` con la app desbloqueada, escribir un espejo de las
alarmas pendientes en `EncryptedSharedPreferences` (clave de Keystore que **no**
exige autenticación de usuario, para poder leerse al arrancar). El espejo guarda
solo `scheduleId`, `notifyAtUtcMs`, `soundEnabled` y `showDetails`. **Nunca el
título de la misión.** Al arrancar, el receiver repone las alarmas desde el
espejo y las notificaciones salen con el texto genérico
("Tienes una misión programada."). Al desbloquear la app, `reconcile()` las
vuelve a programar completas.
- A favor: los recordatorios sobreviven al reinicio; ningún dato sensible sale
  de la base; la degradación es visible y explicable.
- En contra: tras un reinicio y hasta abrir la app, las notificaciones pierden
  el título aunque "mostrar detalles" esté activo. Hay que contárselo al usuario
  en la pantalla de Ajustes, no dejarlo como sorpresa.

**Opción B — No reponer; avisar de que hay que abrir.**
Al arrancar, una única notificación genérica: "Abre Bitácora para restaurar tus
recordatorios".
- A favor: cero datos fuera de la base. Máxima pureza de ADR-002.
- En contra: experiencia pobre. Molesta sin informar, y si el usuario la ignora
  pierde los recordatorios igual. Traslada al usuario un problema técnico.

**Opción C — Reponer solo el resumen diario.**
El espejo guarda únicamente la hora del resumen y el último conteo conocido. Los
recordatorios por misión esperan al siguiente desbloqueo.
- A favor: el resumen diario es precisamente el que debe sobrevivir, porque es
  el que devuelve al usuario a la app. Su contenido ("tienes N misiones") es
  mucho menos sensible que el título de una misión concreta.
- En contra: los recordatorios individuales siguen perdiéndose tras reinicio.

**Recomendación:** **A**, y si el usuario quiere ser más conservador con la
privacidad, **A restringida a lo que describe C** (espejo solo del resumen).
Ambas son coherentes con ADR-002; B no resuelve el problema, solo lo nombra.

**Lo que hay que preguntarle al usuario:** ¿acepta que un espejo mínimo, cifrado
y sin títulos viva fuera de la base para que los recordatorios sobrevivan al
reinicio? Es un ablandamiento consciente de ADR-002 y por eso lo decide él.

### Plan de notificaciones acordado (orden pactado) — TODO IMPLEMENTADO

> Estado real al 2026-09-07: los cuatro puntos están escritos. El 1 validado en
> dispositivo; el 2, 3 y 4 esperan el recorrido de `1.4.0+8`. Lo que sigue es el
> plan tal como se pactó, conservado por su razonamiento.

1. **Reprogramar tras reinicio. COMPLETADO y validado el 2026-09-07.** `RECEIVE_BOOT_COMPLETED` + receiver + el
   espejo que salga de la decisión anterior. Toca `AndroidManifest.xml` y Kotlin
   nuevo; no toca esquema ni pantallas. Es el cimiento de los otros tres.
2. **Resumen diario configurable.** "Hoy tienes 8 misiones" a la hora que elija
   el usuario (pensaba en 5:00–6:00). Una sola alarma al día con
   `setAndAllowWhileIdle`. Conteo precalculado con la app desbloqueada.
3. **Aviso de vencimiento.** Para misiones urgentes antes de que expiren. Hoy el
   único tipo emitido es `'START'` (`drift_mission_repository.dart:365`);
   requiere un tipo nuevo.
4. **Texto personalizable y pulido de "mostrar detalles".** El texto genérico
   está fijo en Kotlin (`MissionAlarmReceiver.kt:76`); pasarlo desde Dart.

**Restricciones que no se negocian:**

- **Alarmas exactas descartadas** por consumo de batería, a petición expresa del
  usuario. Se mantiene `setAndAllowWhileIdle`. Un resumen que suena a las 6:07 en
  vez de a las 6:00 es aceptable; despertar el aparato al milisegundo, no.
- El receiver **nunca** abre la base cifrada.
- El texto que se ve en pantalla bloqueada respeta "mostrar detalles".

**Decisión de esquema, aplazada a propósito (2026-09-07):** el usuario decide
dónde vive el resumen diario **al implementar el punto 2**, no antes. Aviso
importante para quien lo implemente: el "identificador sintético" que se
proponía aquí **no es viable**. `mission_id` es
`NOT NULL REFERENCES missions(id) ON DELETE RESTRICT`
(`app_database.g.dart:5324`), así que exigiría insertar una misión fantasma en
`missions`, visible en listados, conteos y estadísticas. Las dos opciones
reales son: migrar v3 → v4 haciendo `mission_id` nullable, o sacar el resumen
de `notification_schedules` y guardar hora y último conteo en las preferencias
cifradas de A9.1 (sin migración, mismo mecanismo que el espejo del punto 1).
No decidir esto por accidente al escribir el primer `INSERT`.

### Deuda de UX registrada, que NO se toca

El único hallazgo del recorrido físico fue el descubrimiento al crear misiones
(detallado arriba en la entrada del 2026-09-06). **El usuario decidió conservar
la disposición actual** — "me gusta dónde está todo". Está documentado para que
no se confunda con un olvido, pero **no es una tarea pendiente**. Reabrir solo
si aparecen usuarios distintos del autor, o si el propio usuario lo pide.

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

