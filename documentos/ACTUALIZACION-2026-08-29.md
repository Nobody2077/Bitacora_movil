# Actualización funcional — 29 de agosto de 2026

Estado: implementación y verificación automatizada completas. APK
`prodRelease` `1.2.0+5` firmada; validación física pendiente.

## Misiones

- El formulario permite guardar una misión sin fecha, con solo fecha o con
  fecha y hora.
- Una misión de solo fecha queda disponible durante el día y no crea una alarma
  artificial a medianoche.
- Elegir la categoría diaria permite crearla automáticamente o publicarla en el
  tablón. En modo tablón solo pasa a Hoy cuando el usuario la toma.
- El tablón se ubica dentro de Misiones junto a Hoy, Próximas, Todas y
  Calendario; una misión solo puede tomarse una vez por día civil.
- Las colecciones muestran por separado las misiones sin programación.

## Barra lateral

- Se eliminó el texto `BITÁCORA · V2`.
- La etiqueta `SALUD` se reemplazó por un corazón rojo.
- El indicador de misiones se sustituyó por veinte módulos cian de batería real.
  Se llenan consecutivamente y reaccionan a Android sin sondeo periódico.
- El acceso PIN usa una columna en vertical y dos columnas en horizontal; el
  teclado, búfer, protocolo y recuperación quedan visibles en tablet.

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

## Bitácora y esquema v3

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
- La segunda ampliación añade `mission_templates.availability_mode`; las bases
  v1 y v2 migran a v3 y las plantillas existentes conservan modo automático.
- Se añade `drift_schema_v3.json` sin eliminar los snapshots anteriores.

## Evidencia

- `flutter analyze`: sin problemas.
- `flutter test`: 219/219 pruebas aprobadas.
- Pruebas v1→v3 y v2→v3 con datos previos, además de escritura/lectura de un
  nuevo estado.
- Prueba de identidad y persistencia para los ocho estados.
- Contrato v3, restricciones, integridad, claves foráneas y reapertura
  idempotente verificados.
- Integración Kotlin Android compilada para los puentes de batería, privacidad
  y notificaciones.
- APK `prodRelease`: 72.741.699 bytes, firma v2 válida, versión `1.2.0+5`, sin
  permiso `INTERNET`; SHA-256
  `35191226ac66eb6076303faf478f0ffeda166a8536db31f70a5060b64c856a0f`.
