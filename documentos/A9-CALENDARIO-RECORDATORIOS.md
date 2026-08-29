# A9 — calendario y recordatorios

Estado: implementación automatizada completa; validación física pendiente.

## Alcance

- Calendario de misiones con vistas diaria, semanal y mensual.
- Rangos basados en fechas civiles locales y semana iniciada en lunes.
- Agenda reactiva del día seleccionado.
- Creación contextual: el formulario recibe la fecha elegida y vuelve al mismo
  día del calendario después de guardar.
- Ajustes de notificaciones para activar avisos y sonido.
- Anticipación disponible: al comenzar, 5, 15, 30 o 60 minutos antes.
- Horario silencioso configurable, incluso cuando cruza medianoche.
- Por defecto, notificación genérica y privada, sin título, descripción ni
  identificadores.
- Extensión del 29 de agosto: el título puede mostrarse únicamente cuando el
  usuario activa la preferencia; notas e identificadores siguen excluidos.
- Planificación de misiones sin fecha, con solo fecha o con fecha y hora.
- Las misiones de categoría diaria creadas desde el formulario se convierten en
  plantillas recurrentes y generan ocurrencias diarias.

Las preferencias nuevas se guardan en `schema_metadata`, dentro de la misma base
cifrada. El esquema pasó posteriormente a v2 para ampliar los estados de ánimo
de Bitácora; la migración v1→v2 conserva los datos de instalaciones anteriores.

## Evidencia automatizada

- `flutter analyze`: cero problemas.
- `flutter test`: 215/215 pruebas aprobadas tras la extensión del 29 de agosto,
  incluida la matriz táctil, su
  transición terminal y la verificación del fondo negro puro.
- `lintProdRelease`: aprobado sin errores.
- Cobertura añadida para rangos mes/semana/día, fecha contextual, valores por
  defecto, persistencia cifrada, anticipación, horario que cruza medianoche y
  pantalla compacta con texto 2.0×.

## Artefactos 1.1.0+3

- Certificado SHA-256:
  `a6092c6c05727240487247f71ecedee1ecc4d8ed0d61775d014e6512a4d116b8`.
- APK: 71.986.819 bytes; firma v2 válida; SHA-256
  `47a068089aa7f2dcd48801e92f4e7f471c46b47ad84eade121687df03b891ef3`.
- AAB: 55.605.200 bytes; firma JAR verificada; SHA-256
  `a9237ec6c7bbe6e4c1b921fe2de0c9eb03900e00f954b66745d4bf4acb1a5b5b`.
- Paquete `com.jcyq.bitacorarpg`, versión `1.1.0+3` y ausencia de permiso
  `android.permission.INTERNET`.

## Artefacto visual 1.1.1+4

- APK: 72.232.747 bytes; firma v2 válida con el mismo certificado; SHA-256
  `4735193a6e574be1cca51a8ac39fb7ea843cf467f78c61e4bf35fbfe8a903313`.
- Paquete `com.jcyq.bitacorarpg`, versión `1.1.1+4` y ausencia de permiso
  `android.permission.INTERNET`.
- No se generó AAB para esta prueba visual.

## Recorrido físico G9

1. Instalar `1.1.1+4` encima de la release existente, sin borrar datos.
2. Confirmar que el PIN y los datos anteriores se conservan.
3. Abrir Misiones > Calendario y alternar Día, Semana y Mes.
4. Elegir una fecha futura, crear una misión y confirmar que el formulario usa
   esa fecha y vuelve al calendario al guardar.
5. Abrir Ajustes > Notificaciones, habilitar avisos, elegir 5 minutos y aceptar
   el permiso del sistema si Android lo solicita.
6. Crear una misión al menos 10 minutos en el futuro y confirmar que el aviso
   llega aproximadamente 5 minutos antes.
7. Activar horario silencioso incluyendo la hora de prueba y confirmar que un
   aviso posterior llega sin sonido.
8. Verificar que la notificación solo dice que existe una misión programada y
   no revela su contenido.

G9 queda verde cuando el recorrido no presenta pérdida de datos, bloqueos ni
contenido sensible en notificaciones.
