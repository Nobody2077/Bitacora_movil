# ADR-002 — Contrato de acceso y privacidad v1

Fecha: 25 de agosto de 2026  
Estado: aceptado e implementado en A2
Alcance: Android MVP, local-first y de un solo usuario

## 1. Contexto

A1 dejó la base Drift cifrada con SQLite3MC y una clave aleatoria de 256 bits
envuelta por AndroidKeyStore. A2 debe impedir que una sesión bloqueada construya
contenido protegido, abrir la base solo después de resolver el acceso, ocultar
la aplicación al salir de primer plano y ofrecer recuperación local sin derivar
la clave de la base desde un PIN de baja entropía.

Los documentos vigentes fijaban PBKDF2-HMAC-SHA256, biometría opcional,
recuperación externa, autobloqueo y cubierta de privacidad, pero no fijaban la
longitud del PIN ni el formato de recuperación.

## 2. Modelo de amenaza v1

A2 protege frente a acceso casual, dispositivo compartido, exposición en
recientes, capturas, copias de archivos y arranques de proceso sin autenticar.
El cifrado en reposo continúa perteneciendo a A1.

La versión v1 no promete resistencia frente a un dispositivo con root,
instrumentación del proceso, código malicioso ejecutado con el UID de la
aplicación o compromiso del sistema operativo. `local_auth` confirma una
autenticación al proceso, pero no entrega un `CryptoObject` ligado a la clave
SQLite. Fortalecer esa frontera requerirá otro ADR y una migración nativa.

## 3. PIN

- Es obligatorio y contiene exactamente seis dígitos.
- Se rechazan seis cifras iguales y las secuencias `012345`, `123456`,
  `234567`, `345678`, `456789`, `987654`, `876543`, `765432`, `654321`,
  `543210`.
- El alta y el cambio exigen doble confirmación.
- Nunca se almacena ni registra el PIN.
- El verificador usa PBKDF2-HMAC-SHA256, 600.000 iteraciones, salt CSPRNG de
  16 bytes y salida de 32 bytes.
- La derivación se ejecuta fuera del isolate de interfaz.
- La comparación se realiza en tiempo constante.
- Cada alta o recuperación genera un salt nuevo.

## 4. Recuperación externa

- Se generan 20 bytes CSPRNG, equivalentes a 160 bits.
- Se presentan como 32 caracteres Crockford Base32, agrupados de cuatro.
- El código se muestra una sola vez y debe confirmarse antes de terminar el
  alta.
- Solo se conserva otro verificador PBKDF2 con salt independiente; nunca el
  código recuperable.
- Un código válido permite definir un PIN nuevo sin cambiar la clave SQLite ni
  borrar datos.
- Al usarse se invalida y se genera un código nuevo.
- Perder PIN y código de recuperación solo permite un borrado local destructivo
  explícito. No existen PIN maestro, preguntas de seguridad ni puerta trasera.

### 4.1 Copiar y pegar el código (adenda del 30 de septiembre de 2026, `1.5.1+10`)

A petición del usuario, escribir 32 caracteres a mano dejó de ser la única
vía. El riesgo nuevo es el portapapeles de Android, legible por el teclado y,
en algunos teclados, guardado en un historial. Reglas:

- **Copiar** solo existe donde el código se muestra una vez (alta y rotación).
  El contenido se marca como sensible (`ClipDescription.EXTRA_IS_SENSITIVE`,
  Android 13+): el sistema no lo previsualiza y los teclados que respetan la
  marca no lo guardan. En Android 12 o anterior la marca no tiene efecto.
- **El portapapeles se borra a los 60 segundos**, y solo si todavía contiene
  ese mismo código: nunca se pisa algo que el usuario copió después. Si el
  proceso muere antes, el código queda hasta la siguiente copia; es un riesgo
  aceptado.
- **Pegar** es un botón explícito en cada campo del código, además del menú
  estándar. El texto se sanea (mayúsculas, alfabeto permitido, 39 caracteres)
  antes de llegar al campo; la validación sigue siendo la del verificador.
- La confirmación del alta acepta el código pegado: su función pasa a ser
  «pégalo desde donde lo guardaste». La pantalla recomienda un gestor de
  contraseñas o papel, no una nota sin protección.
- Ni el código ni nada derivado de él pasa por logs ni por Dart fuera de
  `SensitiveClipboard`.

## 5. Estado de acceso y AndroidKeyStore

- El estado de acceso es un registro versionado, cifrado y autenticado con
  AES-256-GCM mediante un alias AndroidKeyStore distinto al de la base.
- El registro contiene parámetros, salts, verificadores y política de espera;
  nunca PIN, recovery code ni clave SQLite.
- El estado `unlocked` existe solo en memoria y nunca se restaura después de
  morir el proceso.
- Si existe la base, pero falta el estado, el blob, el alias o la autenticación
  GCM, el sistema falla cerrado. Nunca regenera credenciales ni interpreta la
  corrupción como instalación nueva.
- No se usa `flutter_secure_storage`.

## 6. Intentos y espera progresiva

Desde el quinto fallo se aplica:

```text
segundos = min(30 × 2^(fallos - 5), 900)
```

- Contador, último intento y límite se conservan dentro del registro protegido
  y sobreviven al reinicio.
- Un retroceso del reloj civil no puede acortar una espera ya registrada.
- PIN y recovery code comparten el contador para impedir una segunda vía de
  fuerza bruta.
- Un acierto restablece los fallos.
- Ningún número de fallos borra datos automáticamente.

## 7. Biometría

- Es opcional y solo se activa después de configurar el PIN.
- Se ofrece únicamente si el dispositivo soporta biometría y existe al menos
  una credencial biométrica enrolada.
- Se invoca con `biometricOnly: true`; el PIN, patrón o contraseña del sistema
  no sustituyen el PIN propio.
- Nunca es método de recuperación ni acceso único. Ante cancelación, lockout,
  cambio de enrolamiento o error se conserva el bloqueo y se ofrece el PIN.
- Solo existe una solicitud biométrica concurrente.
- Activar o desactivar biometría exige reautenticación con el PIN.

Dependencias exactas de A2:

- `local_auth 3.0.2`;
- resolución Android esperada `local_auth_android 2.0.8`;
- `cryptography 2.9.0`, sin `cryptography_flutter` mientras `minSdk` sea 24.

Android usa `FlutterFragmentActivity`, permiso `USE_BIOMETRIC` y temas de
lanzamiento AppCompat. `local_auth_android 2.0.9` queda excluido porque exige
Flutter 3.44 y Dart 3.12.

## 8. Sesión y apertura operacional de la base

Estados cerrados:

```text
bootstrapping
setupRequired
locked
authenticating
recovering
corrupted
```

El único estado que permite construir contenido protegido es `unlocked`.

- Un arranque con credenciales configuradas comienza siempre bloqueado.
- La base y los repositorios sensibles no se instancian durante bootstrap,
  alta, desbloqueo o recuperación.
- A2 no deriva la clave SQLite desde el PIN ni la vincula a la biometría. El PIN
  controla cuándo la aplicación solicita y conserva operacionalmente la clave
  de A1.
- Cada operación asíncrona captura una revisión de sesión. Un resultado tardío
  se descarta si hubo bloqueo, background o una operación posterior.
- Bloquear invalida operaciones pendientes; el cambio de estado invalida y
  cierra la base compartida mediante el grafo de providers.

## 9. Guard de rutas

- `/lock` y `/lock/recovery` son las únicas puertas públicas.
- El redirect global se ejecuta antes de resolver cualquier builder protegido.
- Cada builder protegido tiene además una comprobación de defensa en
  profundidad y no instancia pantalla, repositorio ni watch si la sesión no
  está desbloqueada.
- Un destino protegido pendiente vive solo en memoria como
  `PendingDestination(navId, location)`.
- `location` se acepta únicamente después de coincidir con el catálogo interno;
  se eliminan fragmentos, `extra` y parámetros de consulta.
- No se admite `returnTo` externo, no se registra el destino y su representación
  de diagnóstico queda redactada.
- El destino se consume una sola vez. Si no puede validarse, se degrada a la
  raíz de su dominio o a Inicio.
- Al autenticar se reemplaza la puerta; `/lock` no permanece en Back.

## 10. Autobloqueo y cubierta de privacidad

ADR-001 y el snapshot v1 ya fijaron `auto_lock_minutes` como entero y el seed en
5 minutos. A2 conserva ese contrato para no inventar una migración.

- El tiempo predeterminado fuera de primer plano es 5 minutos.
- Opciones persistibles: inmediato (`0`), 1, 5 y 15 minutos.
- La cubierta opaca aparece inmediatamente en `inactive`, `hidden`, `paused` y
  `detached`, independientemente del timeout.
- La decisión durante el proceso usa un reloj monotónico inyectable. La hora
  civil solo conserva la espera progresiva de intentos entre procesos.
- En `resumed` se resuelve primero la sesión. La cubierta solo se retira después
  de que exista un frame público o desbloqueado seguro.
- La cubierta empieza activa, bloquea punteros y excluye el contenido inferior
  del árbol semántico.
- Android mantiene `FLAG_SECURE` para impedir capturas y miniaturas recientes.

## 11. Notificaciones y contenido fuera de la app

Mientras la aplicación esté bloqueada, las notificaciones usan texto genérico y
no incluyen nombres de misiones, cantidades, notas ni contenido de Bitácora. Las
fotos y futuros adjuntos continúan sujetos al cifrado privado previsto para A5.

## 12. Gate G2

G2 exige:

1. vectores y parámetros exactos PBKDF2, salts únicos y ausencia de secretos en
   texto plano;
2. alta, confirmación, cambio de PIN, recuperación y rotación del código;
3. PIN y recuperación erróneos incapaces de abrir la base;
4. espera progresiva exacta y persistente;
5. inicio frío bloqueado y fallo de estado externo siempre cerrado;
6. biometría opcional, exclusivamente biométrica y con fallback al PIN propio;
7. deep links protegidos con contador de builders igual a cero mientras está
   bloqueado;
8. ningún DAO, repositorio ni watch construido antes de desbloquear;
9. destino pendiente validado, consumido una vez y sin open redirect;
10. autobloqueo en los límites `timeout - 1`, `timeout` y `timeout + 1`;
11. cubierta desde el primer frame y antes de reanudar contenido sensible;
12. `FLAG_SECURE`, cierre de base y reinicio de proceso comprobados en Android;
13. regresión G1 completa, `flutter analyze`, pruebas unitarias/widget e
    integración Android verdes;
14. APK debug de los flavors `dev` y `prod` construidas.

No se autoriza A3 mientras uno de estos puntos esté rojo.

## 13. Precedencia

Este ADR prevalece para A2. ADR-001 conserva autoridad sobre cifrado, esquema y
el valor inicial de `auto_lock_minutes`.
