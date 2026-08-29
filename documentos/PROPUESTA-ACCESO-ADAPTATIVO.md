# Terminal de acceso adaptable

Estado: **implementada y verificada automáticamente; validación física pendiente**.

Fecha de registro: 29 de agosto de 2026.

Esta especificación traduce los dos bocetos entregados para mejorar la pantalla
de PIN sin modificar el contrato de acceso y privacidad de `ADR-002`.

## Objetivo

- Conservar la identidad Terminal V2 y reforzar la sensación de terminal local.
- Mostrar teclado, búfer y acciones esenciales sin recortes en una tablet
  horizontal con escala de texto normal.
- Aprovechar el ancho en horizontal sin perjudicar la lectura secuencial en
  vertical.
- Mantener PIN, recuperación, biometría, espera progresiva y transición de
  validación existentes.

## Composición vertical

La disposición vertical seguirá el primer boceto:

1. Cabecera `BITÁCORA // ACCESO` y estado local protegido.
2. Estado de espera, visible únicamente cuando exista un bloqueo temporal real.
3. Título `ENLACE DE ACCESO` y explicación breve.
4. Búfer de seis posiciones.
5. Matriz numérica 3×4 con `C`, `0` y retroceso.
6. Resumen compacto del protocolo de acceso.
7. Biometría, cuando esté habilitada y disponible, y recuperación de acceso.

En alturas reducidas se omitirán primero los datos técnicos decorativos. El
teclado y las acciones de recuperación nunca deben sacrificarse para conservar
ornamentos.

## Composición horizontal

La disposición horizontal seguirá el segundo boceto y usará dos columnas:

- Franja superior: identidad, espera de seguridad real y búfer de seis
  posiciones.
- Columna izquierda: matriz numérica completa.
- Columna derecha: título, explicación y protocolo de acceso.
- Franja inferior: biometría condicional y recuperación de acceso.

El objetivo es que la matriz completa sea visible sin desplazamiento en la
tablet de referencia y con escala normal. Si el alto disponible o la escala de
texto no permiten una interacción segura, la pantalla podrá desplazarse o
volver a la composición vertical; nunca debe recortar controles.

## Estados reales y ambientación

- `TIEMPO RESTANTE` o, preferentemente, `ESPERA DE SEGURIDAD`, mostrará el
  contador real de la espera progresiva aplicada desde el quinto fallo. No se
  presentará un valor ficticio durante el acceso normal.
- No se mostrará `INTENTOS RESTANTES: 05`: el contrato no establece un máximo y
  ningún número de fallos elimina datos. Puede mostrarse un aviso neutral de
  intento no válido o el tiempo de espera real.
- `VALIDACIÓN LOCAL CIFRADA` es válido porque la comprobación ocurre en el
  dispositivo. Se evitarán textos que sugieran una conexión remota.
- `ACCESO AUTORIZADO` solo aparecerá después de una verificación correcta.
- Códigos hexadecimales, versiones y diagramas periféricos serán decorativos,
  no contendrán PIN, identificadores, claves ni información privada.
- La animación terminal existente seguirá vinculada a trabajo real y no
  impondrá demoras artificiales.

## Accesibilidad y comportamiento

- Objetivos táctiles de al menos 48×48 dp y separación suficiente entre teclas.
- Orden de foco lógico y soporte completo para teclado físico.
- TalkBack anunciará cada número, `Limpiar código`, `Borrar último dígito`,
  `Usar biometría` y `Recuperar acceso`.
- El búfer anunciará cantidad de dígitos ingresados, nunca sus valores.
- Los elementos periféricos quedarán fuera del árbol semántico.
- Movimiento reducido usará una composición estática; alto contraste conservará
  bordes y estados distinguibles.
- El color seguirá la preferencia actual de acceso: amarillo, rojo o gris.
- Con texto ampliado hasta 2.0× se permitirá desplazamiento antes que recorte,
  solapamiento o reducción ilegible.

## Criterios de aceptación

1. Vertical y horizontal muestran las doce teclas y las acciones esenciales.
2. La tablet de referencia no requiere desplazamiento horizontal.
3. Un PIN correcto, uno erróneo, una espera progresiva, biometría y recuperación
   mantienen exactamente el comportamiento actual.
4. Ningún estado visual revela el PIN ni simula seguridad inexistente.
5. Las pruebas cubren ancho compacto, dos columnas, texto 2.0×, movimiento
   reducido, alto contraste y TalkBack/semántica.
6. `flutter analyze`, pruebas automatizadas y recorrido físico quedan en verde.

## Fuera de alcance de esta propuesta

- Cambiar la longitud o política del PIN.
- Añadir un límite fijo de intentos o borrar datos automáticamente.
- Modificar cifrado, recuperación o almacenamiento de credenciales.
- Generar una APK antes de completar la validación física y recibir autorización.

## Evidencia automatizada

- Golden vertical de tablet en 800×1280.
- Golden horizontal en 1280×800 con matriz a la izquierda y protocolo a la
  derecha.
- Prueba compacta con texto 2.0× y recuperación alcanzable mediante
  desplazamiento.
- Prueba del contador ligado a una espera progresiva real.
- `flutter analyze` limpio y suite completa de 215 pruebas aprobada.
