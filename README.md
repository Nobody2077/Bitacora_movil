# Bitácora RPG Personal

Aplicación Android privada, local-first y sin dependencia de red para convertir la organización personal en un sistema RPG: misiones, tiempo, economía, Bitácora y progreso en un solo espacio.

El proyecto está construido con Flutter, Riverpod, GoRouter y Drift sobre una base SQLite cifrada. Los datos y las credenciales permanecen en el dispositivo; el acceso se protege con PIN, recuperación y biometría opcional.

> **Estado actual (29 de agosto de 2026):** A0–A5 y A7 están completadas; G7 quedó verde con la
> aprobación física del usuario el 28 de agosto de 2026. A6 fue retirada del
> MVP y G6 no aplica. A8 está en progreso: preflight, firma permanente y
> APK/AAB release están verificados; la instalación limpia y la actualización
> conservando datos fueron aprobadas. Solo faltan métricas físicas y el respaldo
> externo de la firma. A9 añade calendario día/semana/mes y recordatorios
> configurables. El incremento local más reciente añade planificación flexible,
> batería real, controles configurables de privacidad/cámara/notificaciones y
> ocho estados de ánimo con migración Drift v1→v2. La matriz está verde con
> 212 pruebas; todavía no se generó una APK de este incremento.

## Qué busca ofrecer

- Misiones únicas y recurrentes, objetivos, prioridades, importancia y cronómetro.
- Economía personal con movimientos, reservas y metas de ahorro.
- Bitácora vinculable con misiones y movimientos.
- XP, niveles y paneles diarios y semanales.
- Funcionamiento completamente local y adaptable a teléfono y tablet.
- PIN obligatorio mediante BÚFER y matriz numérica táctil, recuperación,
  biometría opcional, autobloqueo y protección de capturas.
- Base SQLite cifrada con claves protegidas por Android Keystore.

## Estado del desarrollo

| Fase | Estado | Resultado |
| --- | --- | --- |
| A0 — Base del proyecto | Completada | Flavors, tema, navegación, shell adaptable y arquitectura base |
| A1 — Persistencia | Completada | Drift v2 compatible con v1, 19 tablas, DAOs, repositorios y SQLite cifrado |
| A2 — Acceso y privacidad | Completada | PIN, recuperación, biometría, guard global, autobloqueo y `FLAG_SECURE` |
| A3 — Misiones | Completada | G3 verde; además incluye archivado lógico seguro con cancelación de avisos |
| A4 — Economía | Completada | G4 verde: código, gate y validación física aprobados |
| A5 — Bitácora y progreso | Completada | G5 verde: evidencia automatizada y validación física aprobadas |
| A6 — Copia y restauración | Retirada del MVP | ADR-005; G6 retirada / no aplica |
| A7 — UI v2 y accesibilidad | Completada | G7 verde: auditoría, 3 goldens, 182 pruebas y validación física |
| A8 — Release | En progreso | Instalación y actualización release aprobadas; faltan métricas físicas y respaldo de firma |
| A9 — Calendario y recordatorios | En validación | Día/semana/mes, planificación flexible, anticipación, privacidad configurable y 212 pruebas verdes |

La capa visual disponible cubre acceso, recuperación, ajustes de privacidad, el ciclo completo de Misiones, las rutas canónicas de Economía y la base funcional de Bitácora. Todo el lienzo visual —fondo, barra lateral, paneles, tarjetas y superficies elevadas— usa negro puro. El acceso bloqueado usa BÚFER y una matriz numérica táctil sin teclado del sistema; su color dominante se elige en Apariencia entre amarillo, rojo y gris. Durante la validación muestra una transición terminal con códigos, barrido y estados reales, sin demoras artificiales ni datos sensibles. Inicio muestra el saldo disponible real y ofrece accesos directos para registrar gasto e ingreso. En tablet, la barra lateral incluye un perfil local editable con nombre y foto privada, navegación inactiva roja y selección amarilla con marco completo y esquina inferior derecha recortada.

Para conocer el punto exacto de continuación, las piezas protegidas y lo que aún no tiene consumidor en producción, leer [`ESTADO_ACTUAL.md`](ESTADO_ACTUAL.md).

El estado del sistema visual real y las reglas para extenderlo sin romper la
coherencia de tablet y móvil están en
[`documentos/ESTADO_VISUAL.md`](documentos/ESTADO_VISUAL.md).

G7 es el último gate cerrado físicamente. A8 prepara la versión `1.0.0+2`, protege
la firma release sin fallback debug, desactiva tráfico claro y toda extracción
Android, ejecuta Lint de `prodRelease` y comprueba los índices de consultas
críticas. El gate final mide la base cifrada con 1.000 misiones y 5.000
movimientos en un dispositivo Android y verifica APK/AAB firmados.
El usuario aprobó físicamente la candidata `prod-debug` y la instalación limpia
de la release `1.0.0+1` el 28 de agosto de 2026. Después instaló `1.0.0+2`,
firmada con el mismo certificado, encima de esa instalación y confirmó que todo
funciona correctamente. Aún no se declara G8 verde hasta medirla en dispositivo
y respaldar externamente la firma.

A9 amplía el calendario a vistas diaria, semanal y mensual. Crear desde una
fecha la precarga en el formulario. Ajustes > Notificaciones permite activar
avisos, elegir 0/5/15/30/60 minutos de anticipación y definir un horario
silencioso. El título permanece oculto por defecto y solo se incluye cuando el
usuario habilita expresamente “Mostrar detalles de la misión”.

La actualización del 29 de agosto añade fechas opcionales o sin hora, convierte
las misiones diarias manuales en recurrencias, muestra la batería real en la
barra lateral y permite configurar capturas y cámara. Bitácora ofrece ocho
estados de ánimo y migra el esquema local de v1 a v2 sin descartar entradas.
El detalle técnico está en
[`documentos/ACTUALIZACION-2026-08-29.md`](documentos/ACTUALIZACION-2026-08-29.md).

## Arquitectura resumida

```text
lib/
├── app/                 bootstrap, configuración, providers, router y tema
├── core/                Result<T> y errores comunes
├── features/
│   ├── access/          acceso y privacidad implementados
│   ├── missions/        flujo base, cronómetro y cierre transaccional
│   ├── economy/         dominio, datos, aplicación y UI funcional de A4
│   ├── journal/         cronología, fotos, búsqueda y archivo A5.1–A5.3
│   ├── progress/        XP, niveles, títulos, rachas y dashboards reactivos
│   ├── profile/         nombre y avatar local de la barra de tablet
│   └── settings/        preferencias, apariencia accesible y privacidad
├── infrastructure/     Drift, esquema, DAOs, cifrado y seguridad
└── shared/              shell adaptable y widgets compartidos
```

La aplicación usa Clean Lite + feature-first. El dominio no depende de Flutter, Riverpod ni Drift; la UI no debe acceder directamente a los DAOs.

## Documentación para personas y agentes

Orden recomendado de lectura:

1. [`ESTADO_ACTUAL.md`](ESTADO_ACTUAL.md): relevo operativo y mapa de conexiones.
2. [`documentos/DECISIONES_PRE_A0.md`](documentos/DECISIONES_PRE_A0.md): decisiones vinculantes y secuencia A0–A8.
3. [`documentos/ADR-001-CONTRATO_PERSISTENCIA_V1.md`](documentos/ADR-001-CONTRATO_PERSISTENCIA_V1.md): contrato base de persistencia y cifrado; su ampliación compatible v2 se registra en la actualización del 29 de agosto.
4. [`documentos/ADR-002-CONTRATO_ACCESO_PRIVACIDAD_V1.md`](documentos/ADR-002-CONTRATO_ACCESO_PRIVACIDAD_V1.md): acceso y privacidad.
5. [`documentos/ADR-003-CONTRATO_TITULOS_RACHAS_V1.md`](documentos/ADR-003-CONTRATO_TITULOS_RACHAS_V1.md): reglas de títulos, rachas y niveles.
6. [`documentos/ADR-005-RETIRO-A6-MVP.md`](documentos/ADR-005-RETIRO-A6-MVP.md): retiro de A6 y secuencia vigente hacia A8.
7. [`documentos/ADR-004-DIFERIMIENTO_A6_ACTIVACION_A7.md`](documentos/ADR-004-DIFERIMIENTO_A6_ACTIVACION_A7.md): antecedente histórico superado por ADR-005.
8. [`documentos/ESTADO_FASES.md`](documentos/ESTADO_FASES.md): evidencia de gates completados.
9. [`documentos/G7-VALIDACION-FISICA.md`](documentos/G7-VALIDACION-FISICA.md): recorrido físico aprobado que cerró A7.
10. [`documentos/A8-VALIDACION-RELEASE.md`](documentos/A8-VALIDACION-RELEASE.md): gate, métricas y recorrido pendiente para cerrar G8.
11. [`documentos/`](documentos/): especificación, UML, diseño, navegación y arquitectura originales.
12. [`documentos/ACTUALIZACION-2026-08-29.md`](documentos/ACTUALIZACION-2026-08-29.md): planificación flexible, batería, controles y esquema v2.
13. [`documentos/ESTADO_VISUAL.md`](documentos/ESTADO_VISUAL.md): componentes,
   reglas visuales y próxima migración de pantallas.

Cuando un documento fuente contradiga una decisión posterior, prevalecen `DECISIONES_PRE_A0.md` y los ADR aplicables.

## Requisitos

- Flutter 3.41.5 stable.
- Dart 3.11.3.
- JDK 17.
- Android SDK con API 24 o superior.
- Emulador o dispositivo Android para ejecutar los plugins de Keystore y biometría.

Las versiones de paquetes están fijadas en [`pubspec.yaml`](pubspec.yaml) y `pubspec.lock`.

## Ejecutar

```powershell
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart
```

Producción local:

```powershell
flutter run --flavor prod -t lib/main_prod.dart
```

## Generar APK debug

```powershell
flutter build apk --debug --flavor dev -t lib/main_dev.dart
flutter build apk --debug --flavor prod -t lib/main_prod.dart
```

No se conservan APK dentro del proyecto. `build/` está ignorado por Git y sus artefactos son reproducibles; los APK debug anteriores se eliminaron porque estaban duplicados y ocupaban aproximadamente 804 MiB. Si se necesita distribuir una versión, debe generarse desde el commit elegido y publicarse como asset de una GitHub Release o con separación por ABI; no debe añadirse al repositorio mediante `force-add`.

## Generar release firmado

Copiar `android/signing.properties.example` como `android/signing.properties` y
completarlo con una llave de producción privada, o definir las cuatro variables
`BITACORA_RELEASE_*`. El archivo y las llaves están ignorados por Git. Sin esa
configuración, las tareas APK/AAB release fallan de forma deliberada.

```powershell
flutter build apk --release --flavor prod -t lib/main_prod.dart
flutter build appbundle --release --flavor prod -t lib/main_prod.dart
```

No desinstalar una APK `prod` firmada con debug si contiene datos valiosos: una
APK con la nueva firma de producción no puede actualizarla y A6 fue retirada.
Usar un dispositivo limpio dedicado para el primer smoke release.

## Verificación disponible

Análisis estático rápido:

```powershell
flutter analyze
```

Verificación completa existente:

```powershell
powershell -ExecutionPolicy Bypass -File tool/quality.ps1
```

Gate Android de acceso y privacidad:

```powershell
powershell -ExecutionPolicy Bypass -File tool/gate_g2.ps1 -DeviceId emulator-5554
```

Preflight A8 sin secretos ni dispositivo:

```powershell
powershell -ExecutionPolicy Bypass -File tool/a8_preflight.ps1
```

Gate G8 completo con firma y dispositivo dedicado:

```powershell
powershell -ExecutionPolicy Bypass -File tool/gate_g8.ps1 -DeviceId <serial-adb>
```

La prioridad actual es avanzar la aplicación funcional. Las pruebas existentes se conservan como red de seguridad y las verificaciones deben ser proporcionales al cambio.

## Repositorio

[github.com/Nobody2077/Bitacora_movil](https://github.com/Nobody2077/Bitacora_movil)
