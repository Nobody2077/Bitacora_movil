# G7 — Validación física de UI v2 y accesibilidad

Estado: pendiente de ejecución en dispositivo Android real.

## Preparación

1. Instalar `build/app/outputs/flutter-apk/app-prod-debug.apk` como actualización;
   no desinstalar ni limpiar datos.
2. Confirmar que la app inicia bloqueada, acepta el PIN y conserva los datos.
3. Usar orientación vertical y horizontal cuando el dispositivo lo permita.

## Recorrido mínimo

1. En **Ajustes → Apariencia**, activar y desactivar Texto grande, Reducir
   movimiento, Alto contraste y Ocultar importes. Cerrar y abrir la app para
   confirmar persistencia.
2. Abrir Misiones de hoy, Calendario, Detalle, Nueva/Editar, Cronómetro y
   Revisión. Confirmar que no hay texto cortado ni acciones inaccesibles.
3. Abrir Economía, un movimiento, su corrección, Metas y una meta concreta.
4. Abrir Bitácora, una entrada, su edición, fotografías y una fuente vinculada.
5. Abrir el diálogo del perfil local, mostrar el teclado, desplazar el contenido
   y comprobar que Cerrar y Guardar nombre siguen alcanzables.
6. Con TalkBack, recorrer al menos Apariencia, un detalle y un formulario.
   Confirmar orden lógico, etiquetas comprensibles y anuncio de carga/error.
7. Con la fuente del sistema al tamaño máximo, repetir Apariencia, un formulario
   y el diálogo de perfil. No debe existir desbordamiento ni contenido atrapado.

## Criterio de cierre

G7 queda verde cuando el recorrido anterior no presenta bloqueos, pérdida de
contenido, importes visibles al estar ocultos, controles sin etiqueta ni fallos
de navegación. Registrar dispositivo, versión de Android, fecha y aprobación
del usuario en `ESTADO_FASES.md`.

Las cargas y errores difíciles de provocar físicamente ya están cubiertos por
pruebas automatizadas; el objetivo del recorrido real es validar Android,
TalkBack, teclado, toque, orientación y escala del sistema.
