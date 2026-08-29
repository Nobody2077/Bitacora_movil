# Estado visual — Sistema Terminal V2

Actualizado: 28 de agosto de 2026.

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
  inactivos usan rojo y el seleccionado usa amarillo con marco completo y una
  esquina inferior derecha recortada; etiquetas de 16 px, iconos de 24 px y
  filas de 52 px mejoran la legibilidad en tablet.
- Cabecera técnica persistente en tablet: identidad, contexto del módulo,
  estado de terminal local, fecha y hora. Es parte del shell, no de una
  pantalla aislada. Sus divisores estructurales, el separador del perfil y la
  división vertical entre navegación y contenido usan `structuralRed`.
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
- Bitácora A5.2 añade al detalle una galería adaptable de fotografías privadas,
  indicador de cifrado, vista ampliada, acción de agregar y retiro confirmado.
  El formulario guía al usuario a guardar la entrada antes de adjuntar.
- Bitácora A5.3 incorpora formulario adaptable de búsqueda, chips de procedencia,
  rango de fechas, filtro de fotografías y resultados operativos. El Archivo
  muestra entradas ocultas con acciones de restaurar/ver; el detalle usa rojo
  crítico para archivar y modo lectura cuando la entrada ya está archivada.
- El cierre diario presenta métricas, misiones completadas y pendientes, área
  destacada y reflexión persistida. Dashboard diario, semanal y de nivel RPG
  usan el mismo sistema Terminal V2 y navegación canónica.
- Progreso muestra títulos vigentes, racha actual, mejor racha y nivel
  independiente por área. El semanal completa sus seis bloques con las dos
  métricas de constancia; los read models se refrescan por cambios persistidos.
- `FeaturePlaceholderPage` y el contenedor «Más» ya usan las superficies
  terminales. Las rutas aún pendientes siguen siendo funcionalmente
  identificables, pero ahora respetan el sistema visual común.
- A7 conecta `/settings/appearance` como superficie Terminal V2 adaptable con
  controles persistentes para texto grande, movimiento reducido, alto
  contraste e importes ocultos. Ajustes dejó de usar un destino genérico para
  Apariencia y sus controles declaran estado, etiqueta y objetivo táctil.
- Apariencia añade un selector amarillo/rojo/gris para la superficie de acceso.
  La pantalla bloqueada presenta seis posiciones bajo `BÚFER` y una matriz
  numérica táctil encabezada por `MATRIZ DE CÓDIGO`; no invoca el teclado del
  sistema y conserva recuperación, biometría y validación existentes.
- `AccessTerminalTransition` sustituye la matriz solo durante los estados reales
  de autenticación y apertura. Usa códigos decorativos no sensibles, barrido y
  carga segmentada; no impone una duración mínima y se vuelve estática cuando
  el usuario activa movimiento reducido.
- La política visual es global: texto grande fija un mínimo de 1.3× sin reducir
  escalas del sistema de 2.0×, movimiento reducido elimina las transiciones
  Terminal instrumentadas, alto contraste cambia a una paleta reforzada e
  importes ocultos enmascara valores y campos monetarios.
- La superficie de Apariencia mantiene una columna en compacto/medio, cambia a
  dos columnas exactamente desde 840 px y limita el ancho de lectura a 1120 px.
- Los estados compartidos `TerminalLoadingState`, `TerminalEmptyState` y
  `TerminalErrorState` anuncian cambios como regiones vivas. Error diferencia
  título/explicación y ofrece reintento enfocable; carga siempre comunica qué
  operación está en curso. El patrón ya cubre las listas y resúmenes principales
  de Misiones, Recurrencias, Economía, Bitácora y Progreso.

## Reglas que se deben conservar

1. La capa de widgets no accede a DAOs: mantiene el flujo feature → aplicación
   → repositorio → infraestructura.
2. El shell conserva la responsabilidad de elegir la ruta; `TerminalSidebar`
   solo muestra el estado y devuelve un índice.
3. El color rojo es identidad, estructura y navegación inactiva; el amarillo
   identifica la opción activa de la barra lateral y también valores técnicos;
   el cian comunica foco e información en el resto de la interfaz.
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
| Todos los fondos y superficies | `background` / `surfaceLow` / `surfaceHigh` / `surfaceOverlay` | `#000000` |
| Borde neutral | `border` | `#2A3340` |
| Rojo de identidad y estructura | `terminalRed` | `#FF3B3B` |
| Acción crítica o destructiva | `criticalAction` | `#D00000` |
| Marco rojo secundario | `structuralRed` | `#7A2631` |
| Foco y texto informativo | `infoCyan` | `#55E6E6` |
| CTA normal sólido | `primaryAction` | `#1EC2C6` |
| Navegación lateral activa / prioridad / tiempo / economía | `valueYellow` | `#F5D547` |
| Progreso / éxito / ingreso | `progressGreen` | `#45D483` |
| Atención / reserva | `attentionOrange` | `#FF9F43` |

El CTA normal reversible de una pantalla es siempre cian sólido. El rojo sólido
se usa exclusivamente para seguridad, destrucción o una confirmación
irreversible, incluida la creación definitiva de una misión desde su formulario.
Todos los estados combinan color con texto, icono o forma. Los controles
mantienen un objetivo táctil mínimo de 48 × 48 y las transiciones usan 120,
180 o 240 ms.

## Cierre A7

La auditoría transversal y su validación física están cerradas. Se conservan
las siguientes decisiones para mejoras posteriores:

1. Acceso y privacidad conservan sus controles Material validados en G2; una
   futura sustitución visual de `Card`/`ListTile` no bloqueó G7.
2. Detalles y formularios usan estados de página accesibles; cargas de
   selectores, calendario, vínculos y fotos privadas usan estados en línea.
3. El diálogo de perfil es desplazable con texto 2.0× y sus operaciones cambian
   de etiqueta mientras están activas. Los diálogos Material mantienen su
   contención y orden de foco nativos.
4. Los tres goldens de Apariencia siguen siendo la matriz canónica contractual.

## Verificación de este incremento

A5 y G5 fueron aprobadas técnica y físicamente en la Redmi Pad el 27 de agosto
de 2026. A7.4 aprobó `flutter analyze`, 182 pruebas, tres goldens canónicos y la
APK `prod-debug`. El usuario aprobó la validación física el 28 de agosto de 2026;
A7 queda completada y G7 verde. A6/G6 fueron retiradas del MVP por ADR-005 y A8
queda autorizada.
