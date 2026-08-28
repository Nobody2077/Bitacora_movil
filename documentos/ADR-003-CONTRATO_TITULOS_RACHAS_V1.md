# ADR-003 — Contrato de títulos, rachas y niveles v1

- Estado: aceptado
- Fecha: 27 de agosto de 2026
- Alcance: cierre técnico de A5 / G5

## Contexto

La especificación original distingue títulos permanentes, dinámicos y
temporales, exige conservar activaciones, desactivaciones, mejor racha y
recuperaciones, y define el ejemplo permanente «Centinela del hogar» al
completar 100 misiones domésticas. No fija una regla general de racha, un
calendario de temporadas ni todos los umbrales.

El esquema Drift v1 ya contiene `title_definitions` y `title_history`. Este
incremento debe conectar ese contrato sin modificar el esquema aprobado ni
inventar temporadas que todavía no tienen fechas configurables.

## Decisión

### Títulos canónicos iniciales

Se incorporan dos definiciones idempotentes al seed v1:

| Título | Tipo | `rule_key` | Umbral |
| --- | --- | --- | ---: |
| Centinela del hogar | `PERMANENT` | `missions.completed.area.hogar` | 100 |
| Ritmo constante | `DYNAMIC` | `missions.completed.daily_streak` | 7 días |

Una misión `COMPLETED` o `PARTIAL` cuenta como completada. «Centinela del
hogar» queda en estado `EARNED` y nunca se desactiva.

### Racha diaria

«Ritmo constante» cuenta días civiles locales distintos con al menos una
misión completada. La racha actual termina hoy si ya existe una finalización;
de lo contrario puede terminar ayer, evitando perder el título durante el día
antes de tener oportunidad de actuar. Un hueco civil posterior rompe la racha.

Esta racha mide actividad global y no fallos de una recurrencia concreta. Una
misión pausada no registra un fallo ni altera por sí misma el historial. Las
reglas futuras por recurrencia deberán tratar las pausas programadas de forma
explícita antes de reutilizar este cálculo.

Al dejar de cumplir el umbral, el historial actual pasa a `INACTIVE` con fecha
de desactivación y conserva `best_streak`. Una activación posterior crea otra
fila, incrementa `recovery_count` y mantiene la mejor racha histórica.

### Títulos temporales

El enum, la persistencia y la sincronización admiten `TEMPORARY`, con el mismo
ciclo activo/inactivo que un título dinámico. No se crea un título temporal por
defecto hasta contar con un período o temporada configurado; generar uno sin
fechas haría que el significado dependiera del código y no de sus datos.

### Niveles y actualización

La fórmula cuadrática vigente se aplica tanto al XP global como al XP
independiente de cada área. Los dashboards escuchan cambios de las tablas que
alimentan Progreso y recalculan sus read models sin reconstruir globalmente la
aplicación. La UI consume únicamente el servicio de aplicación y el repositorio
de dominio.

## Consecuencias

- No cambia `schemaVersion=1` ni el snapshot Drift.
- Las bases existentes reciben las definiciones faltantes mediante el seed
  idempotente ejecutado en `beforeOpen`.
- El Dashboard semanal expone racha actual y mejor racha; Progreso muestra
  además niveles por área y títulos vigentes.
- Las pruebas cubren activación, desactivación, recuperación, permanencia,
  seed idempotente y actualización reactiva.

