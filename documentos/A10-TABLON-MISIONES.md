# A10 — Tablón diario de misiones

Estado: implementación completa, verificación automatizada aprobada y APK
`prodRelease` `1.2.0+5` firmada. Validación física pendiente.

## Decisión de producto

El tablón vive dentro del módulo **Misiones**, no como destino adicional de la
barra lateral. La navegación interna queda ordenada como:

`HOY · TABLÓN · PRÓXIMAS · TODAS · CALENDARIO`

Esto mantiene la barra global reservada para dominios principales y permite
crecer el flujo de Misiones sin ocupar espacio permanente en teléfono o tablet.

## Comportamiento

- Una misión diaria puede usar disponibilidad **Automática** o **Tablón**.
- Automática conserva la generación recurrente existente.
- Tablón muestra la plantilla como una misión disponible cada día, sin hora
  fija y sin crear previamente una ocurrencia en `missions`.
- Al pulsar **Tomar misión**, se crea una misión `AVAILABLE` de día completo,
  se copian sus objetivos y aparece en **Hoy**.
- Una plantilla solo puede tomarse una vez por día civil. Repetir la acción
  devuelve la misma misión y no duplica objetivos ni eventos.
- Una plantilla que ya produjo misiones no puede alternar entre Automática y
  Tablón, evitando mezclar dos historiales. Se pausa y se crea otra plantilla.
- Al día siguiente vuelve a estar disponible mientras la plantilla siga activa
  y su fecha de inicio/fin incluya ese día.

## Persistencia y compatibilidad

El esquema Drift sube a v3 e incorpora
`mission_templates.availability_mode`, limitado a `AUTOMATIC` o `BOARD`.
Las bases v1 y v2 migran a v3; toda plantilla anterior recibe `AUTOMATIC` por
defecto, de modo que su comportamiento no cambia.

La unicidad parcial existente por `template_id + scheduled_at` sigue siendo la
última defensa contra duplicados. La toma del tablón además se ejecuta dentro de
una transacción y valida que la plantilla continúe activa.

Snapshots conservados:

- `drift_schema_v1.json`
- `drift_schema_v2.json`
- `drift_schema_v3.json`

## Evidencia automatizada

- Generación automática omite plantillas del tablón.
- Toma idempotente y copia de objetivos verificadas en servicio y base real en
  memoria.
- Migraciones v1→v3 y v2→v3 verificadas con datos anteriores.
- Pantalla probada con una misión disponible y otra ya tomada.
- Contrato de rutas actualizado a 61 patrones URI.
- `flutter analyze` sin problemas y 219 pruebas aprobadas.
- APK de 72.741.699 bytes, firma APK v2 válida con el certificado permanente,
  versión `1.2.0+5` y sin permiso `INTERNET`.
- SHA-256:
  `35191226ac66eb6076303faf478f0ffeda166a8536db31f70a5060b64c856a0f`.

La instalación y el recorrido físico continúan pendientes.
