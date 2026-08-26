# Estado visual — Sistema Terminal V2

Actualizado: 26 de agosto de 2026.

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
- `FeaturePlaceholderPage` y el contenedor «Más» ya usan las superficies
  terminales. Las rutas aún pendientes siguen siendo funcionalmente
  identificables, pero ahora respetan el sistema visual común.

## Reglas que se deben conservar

1. La capa de widgets no accede a DAOs: mantiene el flujo feature → aplicación
   → repositorio → infraestructura.
2. El shell conserva la responsabilidad de elegir la ruta; `TerminalSidebar`
   solo muestra el estado y devuelve un índice.
3. El color rojo es estructural/selección, el cian comunica información y
   acción, y el amarillo se reserva para etiquetas o valores técnicos.
4. No añadir fuentes o paquetes solo para simular el diseño. Las familias
   declaradas usan la plataforma hasta que se incorpore una licencia y assets
   de fuente reales.
5. No usar medidas absolutas para construir pantallas; usar `LayoutBuilder`,
   `Expanded`, `Wrap`, límites máximos y los tokens de espaciado.

## Migración pendiente

El sistema base está operativo, pero no todas las rutas funcionales han sido
migradas a componentes específicos todavía. Los siguientes incrementos deben
migrar, sin alterar sus casos de uso ni sus pruebas:

1. Acceso y ajustes de privacidad: sustituir las combinaciones restantes de
   `Card` y `ListTile` por tarjetas de configuración terminales.
2. Formularios y detalle de Misiones: consolidar campos, secciones, acciones
   destructivas y diálogos con el kit compartido.
3. Rutas de Bitácora, Economía y Progreso a medida que se implementen
   funcionalmente: cada una debe nacer sobre este sistema, no como una pantalla
   Material genérica que luego requiera una reescritura visual.
4. Estados de carga, vacío y error por módulo, con mensajes accionables y el
   mismo orden: contexto → título → explicación → información → acción.

## Verificación de este incremento

Se ejecutó `flutter analyze` después de aplicar el tema, el shell y los
componentes. Resultado: sin incidencias.
