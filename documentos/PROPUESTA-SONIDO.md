# Propuesta — efectos de sonido

- Estado: **implementada en `1.5.0+9` y aprobada en dispositivo el 25 de
  septiembre de 2026**. Decisiones y desviaciones en «Implementación», al final
- Fecha de registro: 15 de septiembre de 2026
- Alcance: efectos de sonido de interfaz y de recompensa dentro de la
  aplicación. **No** cubre el sonido de las notificaciones Android, que ya
  existe y tiene interruptor propio
- Depende de: `DECISIONES_PRE_A0.md` §3 (dependencias fijadas), ADR-001
  (esquema y preferencias), ADR-002 (acceso y privacidad), `ESTADO_VISUAL.md`
- Precedencia: no altera ningún ADR. Si algún punto entrara en conflicto,
  prevalece el ADR anterior

## Contexto

La aplicación es una terminal muda. La pantalla de acceso ya tiene BÚFER,
matriz de código y una transición con barrido, códigos y estados reales
(`AccessTerminalTransition`), pero no emite ningún sonido. La estética
Terminal V2 y el marco RPG piden acompañamiento sonoro con más naturalidad
que casi cualquier otra ampliación pendiente.

Hay además un problema de producto que el sonido resuelve barato: **completar
una misión hoy es un cambio de estado en una lista.** El sistema entero —XP,
niveles, títulos, rachas— culmina en un evento que no se percibe. Un sonido de
recompensa es la forma más económica de que ese momento se sienta ganado.

Esta propuesta nace de una pregunta del usuario el 15 de septiembre de 2026:
añadir efectos de sonido a «todo»: acceso, menús, botones y cierre de misión.

## La decisión de diseño: dónde suena y dónde no

**La recomendación es NO sonorizar todo**, y es el punto más importante de
este documento.

El sonido ubicuo se apaga solo. Esta no es una aplicación que se use una hora
seguida: se abre varias veces al día para organizarse. Si suena cada botón,
cada navegación y cada guardado, el sonido pasa de recompensa a ruido en
pocos días y el usuario acaba desactivándolo entero, perdiendo también los
momentos que sí valían.

**El valor está en la escasez.** Cuando todo suena, nada se siente ganado,
que es exactamente lo contrario del efecto buscado. Por eso el peso se
concentra en los eventos raros y merecidos.

### Paleta propuesta

| Momento | Peso | Razón |
| --- | --- | --- |
| Misión completada | **Alto** — el sonido principal | Es el pago de todo el sistema de misiones |
| Subir de nivel / ganar título | **El mayor y el más raro** | Ocurre pocas veces; debe notarse cuando ocurre |
| Acceso concedido / denegado | Medio, dos timbres distintos | Cierra la ficción de terminal local |
| Tecla de la matriz PIN | Muy sutil, casi un clic | Confirma el tacto sin fatigar |
| Cronómetro iniciar / pausar | Medio | Utilidad real: confirma sin mirar la pantalla |
| Acción crítica (archivar, anular) | Distinto y más grave | Ya son rojas; el sonido refuerza el peso |

**Sin sonido, a propósito:** navegación entre módulos, menús, desplazamiento,
filtros, guardado de formularios ordinarios, apertura de detalles y cualquier
acción reversible y frecuente.

Total: entre seis y ocho ficheros. Si la paleta crece mucho más allá, la
propuesta ha perdido su criterio.

## Restricciones de este proyecto

Ocho puntos que condicionan la implementación. Casi todos derivan de
decisiones ya tomadas; ninguno es preferencia estética.

### 1. Sin paquete nuevo: puente Kotlin con SoundPool

`DECISIONES_PRE_A0.md` §3 fija las dependencias de forma exacta y exige que
toda incorporación pase por «un ADR, changelog revisado y las pruebas de la
fase afectada en verde». Añadir `audioplayers` o `just_audio` abriría esa
puerta a cambio de un puñado de efectos cortos.

El proyecto ya tiene once puentes Kotlin (`DeviceBatteryBridge`,
`PrivacyWindowBridge`, `MissionNotificationBridge`, `RecurrenceCivilTimeBridge`
y el resto). `SoundPool` está diseñado exactamente para este caso —efectos
breves, precargados, latencia baja, varios simultáneos— y un puente propio
es pequeño, auditable y coherente con el patrón ya establecido.

**Recomendación: puente propio, sin dependencia nueva.**

### 2. El esquema v3 no se toca

La preferencia vive en la metadata cifrada, como ya hacen `ReminderPreferences`
(A9.1) y el resumen diario (A11). Sin migración, sin snapshot nuevo, sin
pruebas `migrateAndValidate`.

Esto no es comodidad: la próxima migración del proyecto —la v3 → v4 de
Personajes/Tienda/Inventario— es la operación más peligrosa que tiene por
delante, porque ADR-005 retiró la exportación y `allowBackup="false"` deja la
base sin copia de ningún tipo —y el 24 de septiembre de 2026 el usuario decidió
migrar sin copia y construirla al final (ADR-006 D2)—. Cada cambio que **no**
toca el esquema es un
riesgo que no se acumula sobre aquel.

### 3. No reutilizar `sound_enabled`

`app_settings.sound_enabled` ya existe, viene sembrada en `true` desde
ADR-001 §10, y significa **sonido de las notificaciones Android**
(`notification_reconciliation_service.dart:189`), con interruptor propio y
visible en Ajustes → Notificaciones
(`notification_settings_page.dart:222`).

Colgar el sonido de interfaz de esa misma preferencia repetiría exactamente
la trampa ya anotada como deuda con la columna `app_settings.daily_summary`:
dos cosas distintas con el mismo nombre, y un valor por defecto que activa
algo que nadie pidió.

**Clave propia, nombre propio** —del estilo `ui_sound_enabled`— y sección
propia en Ajustes, separada de Notificaciones.

### 4. Desactivado por defecto

Es el criterio que el proyecto ya aplicó a capturas de pantalla, cámara al
adjuntar y detalles en notificaciones: «las tres preferencias quedan
desactivadas por defecto». El sonido es perceptible por terceros y debe ser
una elección explícita, no un descubrimiento.

### 5. No robar el foco de audio

Es el fallo clásico de los sonidos de interfaz y arruinaría la función: si el
efecto solicita *audio focus*, pausa la música o el pódcast del usuario cada
vez que pulsa una tecla del PIN.

- `AudioAttributes` con `USAGE_ASSISTANCE_SONIFICATION` y
  `CONTENT_TYPE_SONIFICATION`.
- **No** solicitar foco de audio, ni siquiera transitorio.
- Respetar el modo silencio y vibración del teléfono.
- Volumen propio moderado; los efectos no compiten con el contenido del
  usuario.

### 6. El sonido nunca es el único canal

`ESTADO_VISUAL.md` ya impone esta disciplina al color: «todos los estados
combinan color con texto, icono o forma». El sonido hereda la regla. Ningún
estado, error o confirmación puede depender de que se oiga: es refuerzo
redundante, jamás la señal única.

### 7. El sonido de misión completada se dispara después del commit

Regla arquitectónica 7 del proyecto: «las operaciones externas a SQLite
ocurren después del commit». `CompleteMission` coordina misión, tiempo,
objetivos, evento, XP, Bitácora y economía en una sola transacción. El efecto
se emite **después** de confirmarla, igual que hoy se hace con la
reconciliación de avisos. Nunca dentro de la transacción.

### 8. Assets con licencia comprobable

`ESTADO_VISUAL.md` regla 4 ya fija este criterio para las fuentes: «no añadir
fuentes o paquetes solo para simular el diseño… hasta que se incorpore una
licencia y assets reales». El audio sigue el mismo estándar: CC0 o comprados,
con su procedencia registrada en este documento. Nada descargado sin licencia
verificable.

Formato OGG Vorbis mono, efectos de menos de un segundo. Ocho ficheros así
pesan pocos KB; el tamaño del APK no es una preocupación real aquí. El
directorio `assets/` hoy solo contiene los iconos de lanzador, así que habría
que declarar la carpeta nueva en `pubspec.yaml`.

## Accesibilidad

- El interruptor de sonido es **independiente** de «reducir movimiento». Son
  necesidades distintas y agruparlas obligaría a renunciar a una para obtener
  la otra.
- Los efectos no interfieren con TalkBack ni se solapan con sus anuncios.
- Ningún efecto sustituye una etiqueta semántica existente.

## Criterios de aceptación

1. Con la preferencia desactivada —su estado inicial— la aplicación se
   comporta exactamente como hoy, sin ninguna reproducción.
2. Reproducir un efecto no pausa ni atenúa audio de otra aplicación.
3. El teléfono en silencio no emite efectos.
4. Ningún efecto se dispara dentro de una transacción Drift.
5. El sonido de acceso no revela información: no distingue dígitos, ni el
   progreso del PIN más allá de lo ya visible en el BÚFER.
6. La paleta completa no supera los ocho efectos.
7. `flutter analyze` limpio, matriz de pruebas en verde y un recorrido físico
   que confirme latencia aceptable y ausencia de interferencia con música.

## Fuera de alcance

- El sonido de las notificaciones Android, que ya existe y se gobierna aparte.
- Música de fondo o ambiente continuo.
- Sonido en navegación, menús, desplazamiento y formularios ordinarios.
- Efectos configurables o intercambiables por el usuario: la paleta es fija.
- Cualquier recurso que exija red.

## Orden y momento

**No se implementa todavía**, por dos razones documentadas:

1. La candidata `1.4.0+8` está construida y pendiente de recorrido físico. La
   regla vigente es no apilar cambios sobre un APK bajo prueba: mientras
   código y dispositivo coincidan, cada anomalía es atribuible sin ambigüedad.
2. El post-MVP quedó acotado el 7 de septiembre de 2026 a «Personajes, Tienda
   e Inventario, **y nada más**». El sonido no está en esa lista, así que
   incorporarlo es una decisión consciente de ampliar el alcance, no un extra
   que se cuela.

Orden propuesto: cerrar A11 con el recorrido, cerrar A8/G8, y entonces
decidir si este bloque va antes o después de Personajes/Tienda/Inventario.
A favor de ponerlo antes: no toca el esquema, es de riesgo bajo y es el único
de los dos que no depende de una migración sin red de seguridad.

## Decisiones abiertas — las resuelve el usuario

### D1. ¿Paleta concentrada o sonido general?

Este documento recomienda la paleta corta de seis a ocho efectos, con el peso
en misión completada y subida de nivel. La alternativa —sonorizar toda la
interfaz, como se planteó inicialmente— es viable técnicamente, pero se
considera peor producto por las razones de la sección «dónde suena y dónde
no». **Queda a decisión del usuario.**

### D2. ¿Un interruptor o varios?

- **Uno solo** (recomendado): sonido de interfaz sí o no. Simple y coherente
  con el resto de Ajustes.
- **Dos**: separar los efectos de recompensa (misión, nivel, título) de los
  de interacción (teclas, cronómetro), para poder conservar los primeros y
  silenciar los segundos. Más control, más superficie de ajustes.

### D3. ¿Cuándo entra?

Antes de Personajes/Tienda/Inventario, después, o no entra. Ver «Orden y
momento».

## Qué falta para que esta propuesta pase a implementable

1. Respuesta a D1, D2 y D3.
2. Selección de los efectos concretos, con licencia verificada y su
   procedencia anotada aquí.
3. Recorrido físico de `1.4.0+8` cerrado y A11 en verde.

## Implementación — 25 de septiembre de 2026

Decisiones del usuario del 24 de septiembre de 2026, tras revisar esta
propuesta:

- **D1 — cinco momentos**, pedidos por el usuario: acceso concedido, cambio
  de sección en el menú, misión creada, misión completada y subida de nivel.
  El menú contradice la recomendación de «sin sonido en navegación»; se
  aceptó con la condición de D2.
- **D2 — dos interruptores**, en **Ajustes → Sonido** (`/settings/sound`),
  ambos apagados por defecto:
  - «Sonidos de logros»: acceso, misión creada, misión completada, nivel.
  - «Sonidos de interfaz»: el clic del menú, que puede apagarse solo si cansa.
- **D3 — antes de Personajes/Tienda/Inventario**, porque no toca el esquema.
- Estilo **futurista**, a petición del usuario.

### Cómo quedó

| Pieza | Fichero |
| --- | --- |
| Puente `SoundPool` | `android/.../UiSoundBridge.kt`, registrado y liberado en `MainActivity` |
| Efectos | `android/app/src/main/res/raw/ui_*.ogg` (cinco, 77 KB en total) |
| Servicio, paleta y reproductor | `lib/shared/sound/ui_sound.dart` |
| Preferencias | `lib/shared/sound/ui_sound_preferences.dart` |
| Subida de nivel | `lib/features/missions/application/mission_completion_sound.dart` |
| Pantalla | `lib/features/settings/presentation/sound_settings_page.dart` |

Se cumplen las restricciones 1 y 3 a 8: sin paquete nuevo; clave propia sin
tocar `sound_enabled`; apagado por defecto; `USAGE_ASSISTANCE_SONIFICATION`
sin pedir foco de audio y sin sonar si el teléfono no está en modo normal;
refuerzo redundante, nunca señal única; misión completada después del commit;
y licencia verificada (abajo).

**Desviación de la restricción 2.** Las preferencias no viven en la metadata
cifrada sino en un espejo no sensible, `ui_sound_v1.txt`, igual que el color
de acceso (`access_accent_v1.txt`). El sonido de acceso concedido se decide en
el instante de desbloquear, cuando la preferencia tiene que poder leerse sin
depender de la base. Son dos interruptores sin contenido privado. El esquema v3
sigue sin tocarse, que era el propósito de la restricción.

**Subida de nivel.** No existe un evento de nivel: se deriva del XP. Tras el
commit de `CompleteMission` se lee el total y se compara
`RpgLevel.fromTotalXp(total)` con `RpgLevel.fromTotalXp(total - xpOtorgado)`.
Si cruza un umbral suena **solo** el efecto de nivel, no los dos, para que no
se pisen. Sin XP otorgado, o si el total no se puede leer, suena el de misión
completada.

**Acceso.** Un solo timbre al pasar a desbloqueado, con PIN o biometría. Nunca
por dígito (criterio de aceptación 5). No hay sonido de acceso denegado: no se
pidió.

**Al activar un interruptor** suena una muestra de su grupo, para oírlo sin
tener que provocar el evento.

### Procedencia y licencia de los efectos

Todos de **Kenney** (www.kenney.nl), licencia **Creative Commons CC0 1.0**
(dominio público; el crédito no es obligatorio). Descargados el 24 de
septiembre de 2026 de las páginas oficiales de cada pack, con su
`License.txt`.

| Fichero | Origen |
| --- | --- |
| `ui_access_granted.ogg` | *Sci-Fi Sounds* 1.0 — `forceField_003.ogg` (antes `forceField_001`; cambiado en `1.6.1`) |
| `ui_navigation.ogg` | *Interface Sounds* — `tick_001.ogg` |
| `ui_mission_created.ogg` | *Interface Sounds* — `confirmation_001.ogg` |
| `ui_mission_completed.ogg` | *Interface Sounds* — `confirmation_002.ogg` |
| `ui_level_up.ogg` | *Interface Sounds* — `maximize_005.ogg` |
| `ui_access_keypad.ogg` | *Interface Sounds* — `glitch_001.ogg` (en `1.6.0` era `click_001`) |
| `ui_access_loading.ogg` | *Sci-Fi Sounds* 1.0 — `computerNoise_000.ogg` (añadido en `1.6.0`) |
| `ui_access_denied.ogg` | *Interface Sounds* — `error_008.ogg` (en `1.6.0` era `error_006`) |

La selección se hizo por nombre, sin escucharlos. **Se valida en el recorrido
físico** y cualquiera se sustituye cambiando solo el fichero, con el mismo
nombre.

### Validación física — 25 de septiembre de 2026

`1.5.0+9` instalada en la tablet (Xiaomi `25040RP0AL`, HyperOS 3, Android 16)
como actualización desde Descargas, con la misma firma y sin perder datos. El
usuario revisó los sonidos y los aprobó tal como están: **la selección hecha
por nombre se queda**.

No quedó registrado por separado si se probó con música de fondo ni con el
teléfono en silencio; el código cubre ambos casos (sin foco de audio y sin
sonar fuera del modo normal). Si alguna vez la música se pausa o un efecto
suena en silencio, es un fallo de `UiSoundBridge.kt`.

## Adenda del 1 de octubre de 2026 — sonidos de acceso (`1.6.0`)

A petición del usuario, el acceso deja de tener un solo timbre:

- **Tercer interruptor, «Sonidos de acceso»**, desactivado por defecto como
  los otros dos. Se guarda en el mismo espejo no sensible
  (`ui_sound_v1.txt`, clave `access`); un espejo anterior sin la clave lo deja
  apagado.
- **Tecla del PIN**: un chasquido por pulsación, **el mismo para los diez
  dígitos, borrar y limpiar**. Cumple el criterio 5: el sonido no distingue
  dígitos; el número de pulsaciones ya es visible en el BÚFER y la longitud
  del PIN es fija y conocida. Solo suena con la pantalla bloqueada esperando
  el PIN; los borrados que hace la app tras un intento no suenan.
- **Carga de la terminal**: arranca al pasar a validación y **se corta** al
  salir de ella, para que el sonido nunca alargue la entrada (volumen 0,35).
- **PIN incorrecto**: suena al volver a bloqueado con «credencial no válida»
  o «espera progresiva». Solo dice lo que la pantalla ya muestra.
- Reglas sin cambio: no pide foco de audio, no suena en silencio ni en
  vibración, y ninguna información depende de oírlo.

**Criterio 6** (no más de ocho efectos): con estos tres la paleta llega
exactamente a **ocho**. Los efectos previstos para el menú Personaje (pestañas,
☰, compra, Creación) lo superan; se ampliará el criterio, con decisión del
usuario, cuando lleguen esas fases.

Selección por nombre y duración, sin escucharlos, igual que la primera vez:
se validan en la tablet y cualquiera se sustituye cambiando solo el fichero.
Packs descargados de nuevo el 1 de octubre de 2026 de las páginas oficiales,
con su `License.txt` CC0.

### Validación física — 1 de octubre de 2026

`1.6.0+11` instalada encima de `1.5.1+10` en la tablet, con datos reales. El
usuario probó teclas, carga y PIN incorrecto y **aprobó los tres sonidos tal
como están**.

## Adenda del 1 de octubre de 2026 — elección por escucha (`1.6.1`)

El usuario escuchó candidatos de Kenney en un banco de sonidos y eligió:
tecla `glitch_001`, acceso concedido `forceField_003` y PIN incorrecto
`error_008` (los de `1.6.0` sonaban «a Tetris»). Ningún candidato de carga le
convenció, ni de Kenney ni generados.

**Sonido de carga de prueba, local y fuera de Git.** Para probar en la tablet,
`UiSoundBridge` usa `res/raw/ui_access_loading_test.*` si existe y, si no,
`ui_access_loading.ogg` (CC0). El fichero de prueba es audio con derechos de
autor que el usuario aportó como referencia: está en `.gitignore`, junto con
el `keep_local_test.xml` que evita que el shrinker lo quite, y **nunca se
versiona**. Una compilación hecha desde el repositorio no lo lleva. Antes de
cualquier distribución hay que sustituirlo por un sonido propio o con
licencia. Pendiente: suena bajo (volumen de carga 0,35).
