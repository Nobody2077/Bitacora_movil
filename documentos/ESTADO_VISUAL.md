# Estado visual — Sistema Terminal V2

Actualizado: 27 de agosto de 2026.

Este documento complementa `ESTADO_ACTUAL.md`. Describe exclusivamente el
estado de la interfaz; no sustituye los ADR, el contrato de persistencia ni las
decisiones de producto.

## Implementado en código Flutter

- Tema oscuro centralizado en `lib/app/theme/`: colores semánticos, tipografía,
  superficies, foco, controles de entrada, botones, diálogos, avisos y progreso.
- Fundaciones reutilizables de espacio, radios y movimiento en
  `terminal_foundations.dart`; las pantallas nuevas no deben inventar valores
  locales para esos conceptos.
- Kit de widgets terminales: panel, tarjeta interactiva, encabezado, etiqueta
  técnica, insignia, métrica, divisor, progreso y estado vacío.
- Barra lateral propia para tablet/escritorio (`TerminalSidebar`), ya conectada
  a las seis ramas existentes de `StatefulNavigationShell`. Sustituye el
  `NavigationRail` genérico sin cambiar rutas ni lógica de navegación.
- La parte superior de la barra muestra el perfil local en vez de la marca
  fija: nombre, avatar o inicial y acceso al editor de nombre/foto. Los destinos
  inactivos usan rojo y el seleccionado conserva cian; etiquetas de 16 px,
  iconos de 24 px y filas de 52 px mejoran la legibilidad en tablet.
- Cabecera técnica persistente en tablet: identidad, contexto del módulo,
  estado de terminal local, fecha y hora. Es parte del shell, no de una
  pantalla aislada.
- Inicio dejó de ser un placeholder: `HomeOperationsPage` compone una misión
  prioritaria, siguiente misión y métricas reales. Desde A4 también muestra el
  saldo disponible derivado y activa los accesos de gasto e ingreso.
- El Centro de Misiones migró su resumen diario a tarjetas operativas
  compactas; añade filtros por estado/área, búsqueda local, resumen lateral y
  conserva sus flujos de crear, detalle y cronómetro.
- Detalle de Misión incorpora objetivos/progreso, plan de ejecución, acciones
  reales y registro de segmentos de tiempo; Nueva/Editar misión ubica
  Información y Objetivos junto a Planificación, sin perder validación.
- Detalle de Misión incorpora “Archivar misión” como acción crítica roja, con
  diálogo que explica que se oculta de las listas sin borrar el historial.
- Calendario de Misiones usa grilla mensual y agenda diaria reales, con
  composición compacta apilada y distribución de dos paneles en tablet.
- Economía implementa sobre Terminal V2 el resumen de total/reservado/disponible,
  actividad diaria y mensual, historial, formularios, detalle, análisis, metas
  y reservas. Ingreso usa verde, gasto/atención usa naranja, reserva amarillo y
  la anulación conserva el rojo crítico.
- Bitácora A5.1 implementa cronología diaria real, selector de día, resumen de
  entradas/vínculos/estado dominante, tarjetas por procedencia, formulario de
  alta/edición y detalle con navegación a misión o movimiento fuente.
- `FeaturePlaceholderPage` y el contenedor «Más» ya usan las superficies
  terminales. Las rutas aún pendientes siguen siendo funcionalmente
  identificables, pero ahora respetan el sistema visual común.

## Reglas que se deben conservar

1. La capa de widgets no accede a DAOs: mantiene el flujo feature → aplicación
   → repositorio → infraestructura.
2. El shell conserva la responsabilidad de elegir la ruta; `TerminalSidebar`
   solo muestra el estado y devuelve un índice.
3. El color rojo es identidad, estructura y navegación inactiva; el cian
   comunica foco, selección e información, y el amarillo se reserva para
   etiquetas o valores técnicos.
4. No añadir fuentes o paquetes solo para simular el diseño. Las familias
   declaradas usan la plataforma hasta que se incorpore una licencia y assets
   de fuente reales.
5. No usar medidas absolutas para construir pantallas; usar `LayoutBuilder`,
   `Expanded`, `Wrap`, límites máximos y los tokens de espaciado.

## Paleta vinculante

Esta paleta deriva de las láminas de alta fidelidad del Documento 13 y
prevalece sobre interpretaciones anteriores de la ficha de componentes:

| Uso | Token | Valor |
| --- | --- | --- |
| Fondo principal | `background` | `#08090D` |
| Superficie / elevada | `surfaceLow` / `surfaceHigh` | `#11151C` / `#171D25` |
| Borde neutral | `border` | `#2A3340` |
| Rojo de identidad y estructura | `terminalRed` | `#FF3B3B` |
| Acción crítica o destructiva | `criticalAction` | `#D00000` |
| Marco rojo secundario | `structuralRed` | `#7A2631` |
| Foco, selección y texto técnico | `infoCyan` | `#55E6E6` |
| CTA normal sólido | `primaryAction` | `#1EC2C6` |
| Prioridad / tiempo / economía | `valueYellow` | `#F5D547` |
| Progreso / éxito / ingreso | `progressGreen` | `#45D483` |
| Atención / reserva | `attentionOrange` | `#FF9F43` |

El CTA normal reversible de una pantalla es siempre cian sólido. El rojo sólido
se usa exclusivamente para seguridad, destrucción o una confirmación
irreversible, incluida la creación definitiva de una misión desde su formulario.
Todos los estados combinan color con texto, icono o forma. Los controles
mantienen un objetivo táctil mínimo de 48 × 48 y las transiciones usan 120,
180 o 240 ms.

## Migración pendiente

El sistema base está operativo, pero no todas las rutas funcionales han sido
migradas a componentes específicos todavía. Los siguientes incrementos deben
migrar, sin alterar sus casos de uso ni sus pruebas:

1. Acceso y ajustes de privacidad: sustituir las combinaciones restantes de
   `Card` y `ListTile` por tarjetas de configuración terminales.
2. Revisar físicamente Detalle y Nueva/Editar misión en tablet y terminar la
   migración de diálogos secundarios. Inicio, el resumen de Misiones, Detalle
   y Nueva/Editar ya usan la composición de operaciones del Documento 13.
3. Rutas de Bitácora y Progreso a medida que se implementen
   funcionalmente: cada una debe nacer sobre este sistema, no como una pantalla
   Material genérica que luego requiera una reescritura visual.
4. Estados de carga, vacío y error por módulo, con mensajes accionables y el
   mismo orden: contexto → título → explicación → información → acción.

## Verificación de este incremento

El gate automatizado está limpio con 133 pruebas y `flutter analyze` sin
incidencias. La APK `prod-debug` se recompiló correctamente con Bitácora A5.1 el
27 de agosto de 2026. Las revisiones físicas G3 y G4 fueron aprobadas en la Redmi
Pad; A5 continúa en desarrollo y aún no cumple G5.
