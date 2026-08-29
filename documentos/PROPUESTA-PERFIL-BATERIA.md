# Perfil y batería modular

Estado: **implementada y verificada automáticamente; validación física pendiente**.

Fecha de registro: 29 de agosto de 2026.

## Intención

El bloque de identidad seguirá el boceto aportado:

- Avatar circular a la izquierda.
- Nombre de perfil grande en amarillo.
- Corazón rojo como símbolo de salud, sin la palabra `SALUD`.
- Valor de salud y barra roja en la misma línea visual.
- Franja modular cian debajo de la salud.

## Significado de la franja cian

La franja representa exclusivamente el nivel real de batería del dispositivo;
no representa misiones, salud ni XP.

- Los módulos se llenan de izquierda a derecha según el porcentaje recibido de
  Android.
- Nunca se alternarán módulos llenos y vacíos ni se dejarán huecos intermedios.
- Los módulos restantes conservarán una silueta tenue o un contorno, de modo que
  el total siga siendo comprensible sin parecer un fallo de diseño.
- El indicador reaccionará a los eventos del sistema, sin sondeo periódico.
- La semántica anunciará `Batería, N por ciento`, aunque el porcentaje pueda
  omitirse visualmente.
- El estado de carga podrá señalarse con un pequeño rayo; cualquier animación
  respetará la preferencia de movimiento reducido.
- Si Android no entrega un valor, se mostrará un estado neutral y no un
  porcentaje inventado.

## Adaptación por espacio

- En una cabecera de perfil amplia se usará la franja horizontal del boceto,
  con módulos verticales estrechos y una sola secuencia continua.
- En la barra lateral estrecha se conservará una variante compacta o vertical
  para no reducir el tamaño del avatar, nombre o destinos de navegación.
- La cantidad de módulos podrá disminuir en anchos pequeños, pero el porcentaje
  representado deberá conservarse.
- Con texto ampliado se priorizarán nombre, salud y porcentaje accesible frente
  a los detalles decorativos.

## Criterios de aceptación

1. 0 %, valores intermedios y 100 % se distinguen sin módulos aislados.
2. La franja coincide con la batería informada por Android.
3. El diseño no se confunde con progreso de misiones.
4. Funciona en horizontal, vertical, texto 2.0× y movimiento reducido.
5. TalkBack anuncia el valor sin leer cada módulo individualmente.
6. No se añade sondeo ni trabajo permanente que incremente el consumo.

## Evidencia automatizada

- La referencia de 62 % llena exactamente los primeros trece de veinte módulos.
- Los siete módulos restantes conservan contorno cian tenue y no existen huecos
  entre módulos llenos.
- Golden de la barra lateral completa en 1280×800.
- `flutter analyze` limpio y suite completa de 215 pruebas aprobada.
