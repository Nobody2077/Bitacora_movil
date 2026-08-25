# Bitácora RPG Personal — revisión inicial de insumos

Fecha de revisión: 24 de agosto de 2026

> **Estado histórico.** La Arquitectura Técnica Flutter v1.0 fue recibida después de esta revisión. Los bloqueantes B-01 y C-01 a C-07 ya están cerrados; el contrato vigente es [`DECISIONES_PRE_A0.md`](DECISIONES_PRE_A0.md) y el avance se registra en [`ESTADO_FASES.md`](ESTADO_FASES.md).

## Resultado ejecutivo

Los documentos disponibles permiten comprender con suficiente detalle el producto, la navegación, el modelo relacional, la identidad visual y el plan de pruebas. Sin embargo, todavía no conviene iniciar la fase A0 porque falta el documento que el propio plan declara como contrato vinculante: **Arquitectura técnica Flutter v1.0**.

También existen decisiones cruzadas que deben confirmarse o quedar resueltas por esa arquitectura antes de fijar el esquema Drift, las rutas, las pruebas golden y los paquetes del proyecto.

## Inventario y precedencia recomendada

| Documento | Uso recomendado | Estado de precedencia |
| --- | --- | --- |
| Sistema de diseño y alta fidelidad v2.0 | Tokens visuales, componentes, adaptación y pantallas de referencia | Vigente para UI |
| UML y modelo de datos v1.0 | Entidades, relaciones, invariantes, índices y transacciones | Vigente para datos, sujeto a los puntos abiertos |
| Plan de desarrollo y pruebas v1.0 | Secuencia A0–A8, gates y estrategia de pruebas | Vigente, pero depende de la arquitectura técnica faltante |
| Mapa de navegación definitivo v1.0 | Rutas, guard, retorno y comportamiento adaptativo | Vigente para navegación |
| Arquitectura UX/UI y navegación v0.2 | Antecedentes de decisiones de experiencia | Histórico; el mapa definitivo y la UI v2 prevalecen |
| Especificación v1.0 pre-wireframes | Visión, requisitos originales y glosario | Antecedente; los documentos finales posteriores prevalecen |
| Informe Bitácora RPG Personal | Versión conceptual anterior del 5 de agosto | Histórico; no usar como contrato de implementación |

## Bloqueante documental

### B-01 — Falta Arquitectura técnica Flutter v1.0

El Plan de desarrollo y pruebas declara este documento como arquitectura aprobada y lo usa para fijar capas, dependencias, gates y la secuencia A0–A8. No está incluido entre los siete archivos recibidos.

Sin ese documento quedarían asumidos, entre otros aspectos:

- estructura exacta de capas y reglas de imports;
- versiones y selección definitiva de paquetes;
- contratos de repositorios, servicios y providers;
- estrategia de cifrado, Secure Storage y recuperación;
- implementación de copias protegidas y restauración atómica;
- configuración de Drift, migraciones y generación de código;
- breakpoints y composición del shell adaptativo;
- estrategia de notificaciones, lifecycle, reloj y zona horaria.

## Inconsistencias que requieren resolución

### C-01 — Importancia y prioridad se mezclan en el formulario visual

El dominio distingue `importance`, `priority`, `difficulty`, `isRequired`, tipo y área. La pantalla de alta fidelidad de creación muestra un único control llamado **Prioridad** con valores **Menor, Normal, Importante y Crítica**, que corresponden a la escala de importancia y además omiten **Muy importante**.

Recomendación: conservar ambos conceptos. El formulario básico debe mostrar **Importancia**; prioridad, dificultad y obligatoriedad pueden ir en opciones avanzadas, pero deben estar presentes y tener una asignación inequívoca al modelo.

### C-02 — Fotografías de Bitácora no tienen contrato de persistencia

La especificación, la arquitectura UX/UI y el mapa definitivo incluyen fotografías en entradas y ajustes de Bitácora. El UML v1.0 no contiene tabla de adjuntos, referencia de archivo ni relación equivalente, y el plan A5 tampoco las enumera como entregable.

Recomendación: decidir antes de A1 entre:

1. mantener fotografías en el MVP y agregar un contrato de adjuntos/archivos privados, cifrado, copia y restauración; o
2. mover fotografías explícitamente a post-MVP y retirarlas de navegación y ajustes del MVP.

### C-03 — Objetivos predeterminados de misiones recurrentes

El modelo incluye objetivos para `Mission`, pero `MissionTemplate` no puede conservar una lista de objetivos predeterminados. El UML indica que una tabla hija futura podría agregarse “si se requiere”, aunque recurrencia y objetivos forman parte de la experiencia prevista.

Recomendación: confirmar si las plantillas recurrentes deben copiar objetivos. Si la respuesta es sí, agregar `mission_template_objectives` o documentar otra representación tipada antes de congelar las 17 tablas.

### C-04 — Fórmula de nivel y ejemplos de UI no coinciden

UML y Plan fijan `floor(sqrt(XP / 100)) + 1`. Con 2.450 XP esa fórmula produce nivel 5, mientras que las láminas visuales muestran nivel global 7. Las propias láminas también usan distintos rangos de XP para el nivel 7.

Recomendación: elegir una única fórmula o tabla de umbrales y generar un dataset canónico que alimente documentación, seeds, unit tests y goldens.

### C-05 — Dashboard mensual aparece dentro y fuera del MVP

La especificación consolidada y la arquitectura UX/UI limitan el MVP a vistas diaria y semanal; la mensual queda post-MVP. El Plan A5 exige read models correctos para día, semana y mes.

Recomendación: mantener el mensual post-MVP y corregir el gate A5 para probar solo diario y semanal, salvo decisión expresa de ampliar alcance.

### C-06 — Identificadores técnicos con acentos

El diccionario usa nombres como `área_id`, `row_versión`, `schema_versión` y `format_versión`. Aunque SQLite puede admitirlos, complican generación Drift, SQL, JSON, búsquedas y compatibilidad entre herramientas.

Recomendación: usar identificadores ASCII en código y persistencia (`area_id`, `row_version`, `schema_version`, `format_version`) y conservar español con acentos solo en etiquetas de interfaz y documentación.

### C-07 — Datos de muestra visuales no son canónicos

Las láminas reutilizan fechas, saldos, niveles y progreso que no siempre coinciden entre pantallas. No afecta la dirección visual, pero sí impediría convertirlas directamente en pruebas golden coherentes.

Recomendación: definir un único `GoldenScenario` con reloj fijo, misiones, transacciones, XP y ajustes compartidos.

## Decisiones vigentes que sí están claras

- Plataforma inicial: Android, con tablet como objetivo principal y adaptación a teléfono.
- Aplicación privada, local-first, de un solo usuario y funcional sin servidor.
- Flutter y Dart; Riverpod, GoRouter y Drift como base declarada.
- Seis destinos raíz en ancho amplio y cinco destinos inferiores en compacto mediante **Más**.
- `Mission`, `Transaction`, `JournalEntry` y `XPTransaction` son fuentes únicas; las pantallas consumen proyecciones.
- Saldo total, reservado y disponible derivan de ledgers; no existen cuentas financieras separadas en el modelo vigente.
- Misiones recurrentes usan `MissionTemplate` + `Mission`; no existe `MissionOccurrence`.
- PIN, biometría opcional, guard de rutas y contenido protegido forman parte del MVP.
- Personajes, Tienda, Inventario, mapa, servidor, sincronización y multiusuario quedan fuera del MVP.
- La UI usa la dirección **Terminal funcional reforzada**, con rojo estructural, foco cian y semántica redundante.

## Estado del entorno local

| Componente | Estado |
| --- | --- |
| Flutter | 3.41.5 stable instalado |
| Dart | 3.11.3 instalado |
| VS Code | 1.133.0 instalado |
| Extensión Dart | 3.140.0 instalada |
| Extensión Flutter | 3.140.0 instalada |
| Android SDK | Instalado; plataforma Android 36 |
| JDK usado por Flutter | Temurin 17.0.19 |
| Licencias Android | Pendientes o estado desconocido |
| Dispositivo Android conectado | Ninguno detectado durante la revisión |

Chrome no está instalado, pero no bloquea un MVP Android. Antes del primer build Android se deben aceptar las licencias del SDK y disponer de un emulador iniciado o un dispositivo conectado.

## Siguiente paso recomendado

1. Incorporar **Arquitectura técnica Flutter v1.0**.
2. Verificar si ese documento ya resuelve C-01 a C-07.
3. Registrar las decisiones restantes como correcciones documentales o un ADR inicial.
4. Iniciar A0 con versiones fijadas, estructura feature-first, shell adaptativo vacío, tema, GoRouter, ProviderScope y gates automatizados.
