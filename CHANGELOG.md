# Historial de cambios

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
- Una instalación `prod` antigua firmada con debug no puede actualizarse con la
  nueva firma de producción. No debe desinstalarse si contiene datos valiosos.
