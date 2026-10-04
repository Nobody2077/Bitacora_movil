# Historial de cambios

## 1.7.0 — candidata `1.7.0+14`

### Menú Personaje y esquema v4 (ADR-006, fase 1)

- **Esquema v4**: catorce tablas nuevas (personajes, fotos, inventario,
  proyectos, creación) y la columna `location` en misiones y plantillas. La
  migración v1/v2/v3 → v4 **solo añade**; ensayada en `dev` sobre datos de
  prueba el 1 de octubre de 2026.
- Nueva entrada **Personaje** en la barra lateral (en teléfono, en «Más») con
  las pestañas CIBERWARE · INVENTARIO · MAPA · PERSONAJE · DIARIO.
  CIBERWARE e INVENTARIO llegan en la fase 2; MAPA está aplazado.
- **PERSONAJE**: hexágono con tus áreas de vida y su nivel, y panel de nivel,
  constancia y títulos. La reputación llega en la fase 3.
- **DIARIO**: la Bitácora con otro nombre, más **Personajes**: personas reales
  con nombre, rol, descripción y foto cifrada, todo opcional; «Eliminar»
  archiva. Las entradas eligen sus personajes y suman los de su misión.
- **Misiones**: ubicación en texto, foto cifrada opcional y personajes; las
  tarjetas muestran foto, ubicación y miniaturas. Las plantillas recurrentes
  copian su ubicación.
- Las fotos nuevas se cifran en su propia carpeta y clave (`entity_photos`).
- `flutter analyze` sin problemas y **320/320 pruebas**.
- Release firmada (misma llave, SHA-256 `62db5848…7c6095`), instalada encima
  de `1.6.2+13` con datos reales: migración v3 → v4 sin pérdidas y
  **aprobada en la tablet el 3 de octubre de 2026**.

## 1.6.2 — candidata `1.6.2+13`

### Pantalla completa

- Nuevo interruptor **Ajustes → Apariencia → «Pantalla completa»**,
  **activado por defecto**: oculta la barra de estado y la de navegación
  (modo inmersivo de Android). Un gesto desde el borde las muestra un momento
  y se ocultan solas.
- Se aplica también en la pantalla del PIN: la preferencia vive en un espejo
  no sensible (`immersive_v1.txt`), como el color de acceso. Se vuelve a
  aplicar al regresar a la app.
- La hora, la fecha y la batería ya las muestra la propia app en la cabecera
  y la barra lateral. **El esquema no cambia.**
- `flutter analyze` sin problemas y **268/268 pruebas**, tres nuevas; golden de
  Apariencia expandida regenerado (la tarjeta va a todo el ancho, debajo de la
  cuadrícula).
- Instalada encima de `1.6.1+12` con datos reales y **aprobada en la tablet
  el 1 de octubre de 2026**.

## 1.6.1 — candidata `1.6.1+12`

### Sonidos de acceso elegidos por el usuario

- Tecla del PIN: `glitch_001`; acceso concedido: `forceField_003`; PIN
  incorrecto: `error_008` (Kenney, CC0), elegidos escuchándolos.
- La carga admite un sonido **local de prueba**, ignorado por Git, que
  sustituye al de serie si existe. Detalle en `documentos/PROPUESTA-SONIDO.md`.
- Instalada en la tablet y **aprobada por el usuario el 1 de octubre de
  2026**. Pendiente: la carga suena baja.

## 1.6.0 — candidata `1.6.0+11`

### Sonidos de acceso

- Nuevo interruptor **Ajustes → Sonido → «Sonidos de acceso»**, desactivado
  por defecto.
- Un chasquido al pulsar cada tecla del PIN, **el mismo para todas**, también
  borrar y limpiar, para que el sonido no revele dígitos.
- Sonido de **terminal cargando** mientras se valida el PIN; se corta en
  cuanto termina.
- Aviso sonoro de **PIN incorrecto**.
- Efectos de Kenney (CC0): `click_001`, `computerNoise_000` y `error_006`.
  Procedencia en `documentos/PROPUESTA-SONIDO.md`. **El esquema no cambia.**

### Calidad

- `flutter analyze` sin problemas y **265/265 pruebas aprobadas**, siete nuevas
  (interruptor, espejo anterior y qué suena en cada cambio del acceso).
- APK release `1.6.0+11` firmada con el certificado de siempre y **sin permiso
  `INTERNET`**. Instalada encima de `1.5.1+10` con datos reales y **validada en
  la tablet el 1 de octubre de 2026**: el usuario aprobó los tres sonidos.

## 1.5.1 — candidata `1.5.1+10`

### Copiar y pegar el código de recuperación

- Botón **«Copiar código»** donde el código se muestra una sola vez (alta del
  PIN y rotación tras recuperar). El contenido se marca como sensible y **se
  borra del portapapeles a los 60 segundos** si sigue siendo ese código.
- Botón **«Pegar código»** en cada campo del código: recuperar acceso y las
  dos confirmaciones. Lo pegado se pasa a mayúsculas y se limpia.
- Los textos recomiendan guardarlo en un gestor de contraseñas o en papel.
- Contrato en ADR-002 §4.1. **El esquema no cambia.**

### Botón Salir

- Nueva entrada **«Salir»** en la barra lateral, justo debajo de Ajustes.
- Pide confirmación (**«¿Deseas salir?»**); al aceptar **bloquea la sesión**
  (cierra la base cifrada) **y cierra la app**. Al volver se pide el PIN.
- Golden `sidebar_modular_battery` regenerado por la entrada nueva.

### Calidad

- `flutter analyze` sin problemas y **258/258 pruebas aprobadas**, ocho nuevas
  (portapapeles sensible, pegar y Salir).
- APK release `1.5.1+10` firmada con el certificado de siempre y **sin permiso
  `INTERNET`**. Instalada encima de `1.5.0+9` con datos reales y **validada en
  la tablet el 1 de octubre de 2026**: datos intactos, Salir, copiar y pegar
  aprobados por el usuario.

## 1.5.0 — candidata `1.5.0+9`

### Efectos de sonido

- Nueva pantalla **Ajustes → Sonido** con dos interruptores, ambos
  **desactivados por defecto**:
  - **Sonidos de logros:** acceso concedido, misión creada, misión completada
    y subida de nivel.
  - **Sonidos de interfaz:** un clic breve al cambiar de sección en el menú.
- Al completar una misión que sube de nivel suena solo el efecto de nivel, no
  los dos.
- Al activar un interruptor suena una muestra de ese grupo.
- Los efectos no pausan la música de otras aplicaciones y no suenan con el
  teléfono en silencio o vibración. Ninguna información depende de oírlos.
- Efectos de estilo futurista de Kenney, con licencia CC0. Procedencia en
  `documentos/PROPUESTA-SONIDO.md`.
- **El esquema no cambia.** Los dos interruptores viven en un fichero no
  sensible, como el color de acceso, para que el sonido de acceso pueda
  decidirse al desbloquear.

### Calidad

- `flutter analyze` sin problemas y **250/250 pruebas aprobadas**, doce de
  ellas nuevas sobre las preferencias, el servicio, la subida de nivel y la
  pantalla de Sonido.
- APK release `1.5.0+9` firmada con el certificado de siempre y **sin permiso
  `INTERNET`**. **Validada en dispositivo el 25 de septiembre de 2026**: el
  usuario aprobó los cinco efectos tal como están.

## 1.4.0 — candidata `1.4.0+8`

### Resumen diario

- Un solo aviso al día con cuántas misiones te esperan, a la hora que elijas y
  con interruptor propio para silenciarlo sin tocar el resto de recordatorios.
- Vive fuera de `notification_schedules`, en las preferencias cifradas. **El
  esquema no cambia.**
- El recuento se calcula con la aplicación desbloqueada y viaja ya cocinado: el
  receiver no puede abrir la base cifrada. Es una foto del último uso, no del
  amanecer.

### Aviso de vencimiento

- Las misiones con hora y con plazo avisan también antes de vencer, con la
  misma anticipación configurada para el resto.
- Las misiones de solo fecha quedan excluidas a propósito: su vencimiento es el
  final del día civil, no un plazo puesto por ti, y avisar ahí sería sonar cada
  noche.
- Editar la hora de inicio ya no cancela el aviso de vencimiento, ni al revés.

### Texto configurable

- El mensaje de los avisos que no muestran el título se puede cambiar en
  Ajustes → Notificaciones. Antes estaba fijo en el código.
- El texto se resuelve en la aplicación y viaja ya cocinado hasta la alarma,
  de modo que el receiver no necesita abrir la base cifrada para escribirlo.
- **Tras reiniciar el teléfono, el texto propio no se conserva.** El espejo de
  arranque guarda solo seis campos y ninguno es el mensaje, así que los avisos
  repuestos usan el texto genérico fijo hasta que se abre la aplicación y se
  reprograman completos. El resumen diario repuesto dice «Abre Bitácora para
  ver tu resumen de hoy.». Es la misma degradación consciente que 1.3.0 ya
  documentó para el título de la misión.

### Calidad

- `flutter analyze` sin problemas y **238/238 pruebas aprobadas**, siete de
  ellas nuevas sobre el resumen, el vencimiento y el texto.
- **Validada en dispositivo el 23 de septiembre de 2026.** El recorrido cubrió
  el resumen diario, el texto configurable, el aviso de vencimiento y la
  regresión del reinicio. Sin incidencias: A11 queda cerrada y G9 con ella.
- El golden `sidebar_modular_battery` **ya no falla**. La causa no era el
  antialiasing que se sospechaba: `matchesGoldenFile` sobre un `Finder` captura
  el `RepaintBoundary` más cercano, y `TerminalSidebar` no tenía ninguno, así
  que fotografiaba la pantalla entera con la fecha de hoy dentro. Fallaba todos
  los días salvo el de su regeneración, y el tamaño del diff seguía a la
  longitud del nombre del día: 0,26 % el 15 de septiembre, 0,45 % el 23. Se
  añadió un `RepaintBoundary` a la barra lateral —que además no necesita
  repintarse cuando cambia el módulo abierto— y el golden pasa a capturar sus
  248 px y nada más.
- APK `prodRelease` firmada `1.4.0+8`: 72.905.847 bytes, firma v2 válida con el
  certificado permanente `a6092c6c…16b8`, sin permiso `INTERNET`; SHA-256
  `c49550f3eeebe628671641f1b4514c45949ea89f6e032e2523febcb305bbf9ed`.
- Ese hash corresponde a la recompilación del 15 de septiembre de 2026 sobre el
  mismo código, no al artefacto original del 7 de septiembre, cuyo hash no se
  llegó a registrar. Las compilaciones de Flutter no son reproducibles bit a
  bit —llevan marcas de tiempo y valores de firma distintos en cada pasada—,
  así que el tamaño coincide pero el hash no. El certificado sí es el mismo, de
  modo que ambas se instalan indistintamente sobre `1.3.0+7`.

## 1.3.0 — candidata `1.3.0+7`

### Notificaciones que sobreviven al reinicio

- Los recordatorios se reponen solos tras reiniciar el teléfono o actualizar la
  aplicación. Antes se perdían todos: Android borra las alarmas de
  `AlarmManager` al arrancar y nada las repoblaba, porque la reconciliación solo
  corre al desbloquear la aplicación.
- Para lograrlo se guarda un espejo mínimo **fuera** de la base cifrada, con
  solo el identificador del aviso, su hora, el sonido y la preferencia de
  detalles. **Nunca el título de la misión.** Va cifrado con AES/GCM y una clave
  de AndroidKeyStore, siguiendo el mismo patrón que ya usaba la clave de la
  base.
- Consecuencia visible y deliberada: tras un reinicio, y hasta que se abre la
  aplicación, los avisos salen con el mensaje genérico aunque «mostrar
  detalles» esté activo. Leer el título exigiría abrir la base cifrada, y eso
  pide el PIN. Ajustes lo explica en un panel nuevo en vez de dejarlo como
  sorpresa.
- El permiso nuevo es `RECEIVE_BOOT_COMPLETED`. No da acceso a red ni a datos;
  la aplicación sigue sin permiso de `INTERNET`.
- Un fallo al sincronizar el espejo se reporta en el informe de reconciliación
  en vez de pasar desapercibido.

## 1.2.1 — candidata `1.2.1+6`

Aprobada físicamente por el usuario el 6 de septiembre de 2026.

- Misiones gana una sección propia **Recurrentes** en su navegación interna,
  desde la que se crean y editan las plantillas.
- El tablón deja de listar las misiones ya resueltas.
- La cuadrícula de misiones reparte las tarjetas en una, dos o tres columnas
  según el ancho disponible.
- El fallo al generar ocurrencias de una plantilla deja de ser silencioso.

## 1.2.0 — candidata `1.2.0+5`

### Misiones y planificación

- Misiones incorpora navegación interna `Hoy · Tablón · Próximas · Todas ·
  Calendario` sin añadir otro destino a la barra lateral.
- Las misiones diarias pueden generarse automáticamente o quedar disponibles
  en el tablón para tomarlas. Tomarlas es idempotente por plantilla y día.
- Las misiones del tablón no ocupan la lista de Hoy hasta que el usuario las
  selecciona; se crean sin hora fija y copian sus objetivos.
- La planificación admite tres modalidades: sin fecha, solo fecha y fecha con
  hora. Las misiones de solo fecha no programan avisos a medianoche.
- Las colecciones distinguen las misiones sin programación y conservan la
  generación recurrente idempotente en fechas civiles.

### Barra lateral y dispositivo

- Se retiró el pie `BITÁCORA · V2` de la barra lateral.
- `SALUD` se sustituyó por un corazón rojo.
- Los segmentos de misiones se reemplazaron por veinte módulos cian que reflejan
  la batería real del dispositivo. Se llenan consecutivamente, sin huecos
  intermedios ni sondeo periódico.

### Acceso adaptable

- El PIN conserva su composición secuencial en vertical y usa matriz/protocolo
  en dos columnas a partir de 840 px cuando existe altura suficiente.
- El acceso horizontal muestra búfer, teclado completo, protocolo y recuperación
  sin recortes en 1280×800.
- La espera de seguridad muestra un contador únicamente durante un bloqueo
  progresivo real; no se añadieron límites ficticios ni demoras artificiales.
- Texto 2.0× vuelve a la composición desplazable antes de recortar controles.

### Privacidad, notificaciones e imágenes

- Ajustes > Privacidad permite habilitar capturas de pantalla. Al bloquear la
  aplicación se restablece la protección segura de la ventana.
- Ajustes > Notificaciones permite mostrar u ocultar el título de la misión;
  las notas y demás datos continúan fuera del aviso.
- Ajustes > Privacidad permite habilitar la cámara al adjuntar imágenes. Cuando
  está activa se puede elegir cámara o galería en Bitácora y perfil.
- Las tres preferencias quedan desactivadas por defecto y se guardan en la base
  local cifrada.

### Bitácora y persistencia v3

- El estado del momento se amplió de tres a ocho valores: Feliz, Motivado,
  Enfocado, Tranquilo, Neutral, Ansioso, Triste y Cansado.
- El esquema Drift sube a v2 con una columna opcional `mood_detail` y una
  migración v1→v2 que conserva las entradas anteriores.
- Se añadió el snapshot oficial `drift_schema_v2.json`, validación de contrato,
  restricciones, reapertura idempotente y prueba de migración con datos v1.
- Drift sube a v3 con `mission_templates.availability_mode`; las plantillas
  anteriores migran como automáticas y se conserva el snapshot v2.

### Calidad

- `flutter analyze` sin problemas y 219/219 pruebas aprobadas.
- La integración Kotlin Android de batería, capturas y notificaciones compila.
- APK `prodRelease` firmada `1.2.0+5`: 72.741.699 bytes, firma v2 válida,
  sin permiso `INTERNET`; SHA-256
  `35191226ac66eb6076303faf478f0ffeda166a8536db31f70a5060b64c856a0f`.

## 1.1.1 — candidata `1.1.1+4`, validación física pendiente

### Interfaz terminal

- Fondo negro puro en lienzo, barra lateral, paneles y tarjetas.
- Navegación lateral inactiva roja y selección amarilla con marco recortado.
- Divisores principales del shell en rojo estructural.
- Acceso táctil con BÚFER, matriz numérica y color amarillo/rojo/gris.
- Transición terminal ligada a la autenticación real, sin demora artificial y
  con alternativa estática cuando se reduce movimiento.

### Calidad

- `flutter analyze` sin problemas y 202/202 pruebas aprobadas.
- APK firmado `1.1.1+4`, sin permiso de Internet; SHA-256
  `4735193a6e574be1cca51a8ac39fb7ea843cf467f78c61e4bf35fbfe8a903313`.

## 1.1.0 — candidata `1.1.0+3`, validación física pendiente

### Calendario y recordatorios

- Calendario de misiones con vistas diaria, semanal y mensual.
- Navegación por periodo y agenda del día seleccionado en teléfono y tablet.
- Crear desde el calendario precarga la fecha elegida y regresa a ese día.
- Pantalla real de Notificaciones en Ajustes.
- Recordatorios configurables al comenzar o 5, 15, 30 y 60 minutos antes.
- Horario silencioso configurable; el aviso conserva contenido privado.
- Preferencias almacenadas en metadata cifrada sin cambiar el esquema Drift v1.

### Calidad

- `flutter analyze` sin problemas y 202/202 pruebas aprobadas.
- Pruebas de rangos civiles, fecha contextual, persistencia, anticipación,
  horario nocturno y accesibilidad con texto 2.0×.

## 1.0.0 — candidata `1.0.0+2`, actualización aprobada

### Incluido

- Misiones, recurrencias, cronómetro, recordatorios y cierre atómico.
- Economía con ledger, correcciones compensatorias, metas y reservas.
- Bitácora privada con fotografías, búsqueda, archivo y cierre diario.
- XP, niveles por área, rachas, títulos y dashboards diario/semanal.
- PIN, recuperación, biometría opcional, autobloqueo y base SQLite cifrada.
- Interfaz Terminal V2 adaptativa, accesible y con preferencias visuales.

### Release y seguridad

- Versión Android candidata `1.0.0+2` y esquema de datos v1.
- Firma de producción externa al repositorio y sin fallback a llave debug.
- Tráfico claro deshabilitado; sin permiso de Internet en producción.
- Backup cloud y transferencia entre dispositivos excluidos explícitamente.
- Compatibilidad `java.time` en API 24–25 mediante core library desugaring.
- Gate reproducible para regresión, rendimiento, firma, APK/AAB y smoke.

### Limitaciones conocidas

- A6 (copia/restauración) fue retirada del MVP; no existe exportación portable.
  *(Nota del 24-09-2026: la copia vuelve como último bloque del post-MVP,
  ADR-006 D2.)*
- Una instalación `prod` antigua firmada con debug no puede actualizarse con la
  nueva firma de producción. No debe desinstalarse si contiene datos valiosos.
