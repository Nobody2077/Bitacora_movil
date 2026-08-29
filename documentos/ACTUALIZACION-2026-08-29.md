# Actualización funcional — 29 de agosto de 2026

Estado: implementación y verificación automatizada completas. No se generó APK.

## Misiones

- El formulario permite guardar una misión sin fecha, con solo fecha o con
  fecha y hora.
- Una misión de solo fecha queda disponible durante el día y no crea una alarma
  artificial a medianoche.
- Elegir la categoría diaria en el formulario crea una plantilla recurrente;
  sus ocurrencias aparecen en el tablón de misiones diarias.
- Las colecciones muestran por separado las misiones sin programación.

## Barra lateral

- Se eliminó el texto `BITÁCORA · V2`.
- La etiqueta `SALUD` se reemplazó por un corazón rojo.
- El indicador segmentado de misiones se sustituyó por una batería vertical
  continua conectada al nivel real que publica Android. No realiza sondeo
  periódico: reacciona a los cambios del sistema.

## Ajustes configurables

### Privacidad y acceso

- **Permitir capturas de pantalla** controla `FLAG_SECURE` en tiempo real. La
  pantalla bloqueada mantiene la protección.
- **Permitir cámara al adjuntar** añade la elección Cámara/Galería al adjuntar
  fotografías en Bitácora y al cambiar el avatar. Desactivada conserva el flujo
  exclusivo de galería.

### Notificaciones

- **Mostrar detalles de la misión** incluye únicamente el título en el aviso.
- Desactivada usa el texto genérico anterior y visibilidad privada.
- Activada usa un canal separado con visibilidad pública, sujeto a la
  configuración final de pantalla bloqueada de Android.
- Las notas, importes e identificadores nunca se envían al aviso.

Las tres preferencias están desactivadas inicialmente y se persisten como
metadata dentro de la base cifrada.

## Bitácora y esquema v2

El selector “Estado del momento” ofrece:

1. Feliz
2. Motivado
3. Enfocado
4. Tranquilo
5. Neutral
6. Ansioso
7. Triste
8. Cansado

“Sin estado” continúa disponible. Se eligieron ocho valores para cubrir ánimo,
energía y tensión sin saturar el formulario.

El esquema Drift pasa de v1 a v2 mediante una ampliación compatible:

- `journal_entries.mood` permanece intacta para datos anteriores.
- `journal_entries.mood_detail` es una columna opcional con los ocho valores.
- La lectura prioriza `mood_detail` y usa `mood` como fallback histórico.
- La migración añade la columna sin reconstruir tablas ni modificar claves
  foráneas.
- Se conservan `drift_schema_v1.json` y el nuevo `drift_schema_v2.json`.

## Evidencia

- `flutter analyze`: sin problemas.
- `flutter test`: 212/212 pruebas aprobadas.
- Prueba v1→v2 con una entrada previa real y posterior escritura/lectura de un
  nuevo estado.
- Prueba de identidad y persistencia para los ocho estados.
- Contrato v2, restricciones, integridad, claves foráneas y reapertura
  idempotente verificados.
- Integración Kotlin Android compilada para los puentes de batería, privacidad
  y notificaciones.
- No se ejecutó una tarea de ensamblado de APK.
