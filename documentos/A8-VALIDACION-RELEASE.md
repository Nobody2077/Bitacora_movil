# A8 — validación de release 1.0.0

Estado: instalación limpia y actualización aprobadas; métricas pendientes. G8 permanece rojo.

## Precaución de datos y firma

La APK `prod-debug` usada durante el desarrollo tiene una firma distinta a la
llave de producción. Android no permite actualizarla con `prod-release`. Como
A6 fue retirada, desinstalar la app elimina datos sin una vía portable de
restauración. La primera validación release debe hacerse en un dispositivo
limpio dedicado. No desinstalar la instalación de uso real.

## Preparación

1. Crear y custodiar una llave release fuera del repositorio.
2. Copiar `android/signing.properties.example` como
   `android/signing.properties`, o definir las cuatro variables
   `BITACORA_RELEASE_*`.
3. Conectar por ADB un teléfono y una tablet de prueba sin datos valiosos.
4. Registrar modelo, versión Android, ABI y serial ADB de cada equipo.

## Gate automatizado

Ejecutar en cada dispositivo objetivo:

```powershell
powershell -ExecutionPolicy Bypass -File tool/gate_g8.ps1 -DeviceId <serial-adb>
```

El gate debe aprobar calidad completa, Lint release, cifrado, acceso,
reinicio real, métricas, APK/AAB firmados, ausencia de `INTERNET`, hashes y
smoke no destructivo. Conservar `build/a8_evidence/release_manifest.json` con
los artefactos publicados, fuera de Git.

## Evidencia de artefactos 1.0.0+1

- Certificado SHA-256:
  `a6092c6c05727240487247f71ecedee1ecc4d8ed0d61775d014e6512a4d116b8`.
- APK: 71.937.139 bytes; SHA-256
  `63af346221f2ac62fcb7c51f6fd3f0b8610089abfb262043b0ec70fcbd078f82`.
- AAB: 55.545.407 bytes; SHA-256
  `856b895b0306c12305568ee0143110d661c3a90fdf0957c6b0f2dce02d0d3bbe`.
- APK: firma v2 válida, versión `1.0.0+1`, paquete
  `com.jcyq.bitacorarpg` y ausencia de `android.permission.INTERNET`.
- El usuario aprobó la candidata `prod-debug` antes de generar estos artefactos.
- El usuario instaló desde cero la APK release `1.0.0+1` y confirmó el 28 de
  agosto de 2026 que todos los flujos probados funcionan correctamente.

## Evidencia de artefactos 1.0.0+2

- Certificado SHA-256 (idéntico a `1.0.0+1`):
  `a6092c6c05727240487247f71ecedee1ecc4d8ed0d61775d014e6512a4d116b8`.
- APK: 71.937.139 bytes; SHA-256
  `37c4163bf8350ae94bf8f3e8aa77faca0b12eb4fb7a4fa72db61e35deabfb50f`.
- AAB: 55.545.412 bytes; SHA-256
  `317a503b57982fdfacb52cd47befb8831462920d0bad96153b19edb84ae60ae9`.
- APK: firma v2 válida, versión `1.0.0+2`, paquete
  `com.jcyq.bitacorarpg` y ausencia de `android.permission.INTERNET`.
- AAB: firma JAR verificada. Las advertencias de certificado autofirmado y sin
  sello de tiempo son esperadas para esta llave de distribución privada.
- El usuario instaló esta APK encima de `1.0.0+1` el 28 de agosto de 2026 y
  confirmó que todo funciona correctamente, sin reportar pérdida de datos.
- La conexión USB no está disponible; las métricas requieren ADB inalámbrico u
  otro dispositivo accesible para instrumentación.

## Métricas obligatorias

Registrar la línea `A8_METRICS` emitida por el gate para cada dispositivo.

| Dispositivo | Android | Arranque cifrado (<1 s) | Primera lectura (<300 ms) | Dashboard (<150 ms) | Memoria adicional (<128 MiB) | Resultado |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| Pendiente | Pendiente | — | — | — | — | Pendiente |

## Recorrido manual

En teléfono y tablet, sin red:

1. Confirmar instalación limpia, primer alta de PIN y arranque bloqueado.
2. Crear/editar/completar misión; pausar y recuperar cronómetro tras reinicio.
3. Crear ingreso, gasto, reserva y anulación; comprobar saldos derivados.
4. Crear entrada con foto privada, buscarla, archivarla y restaurarla.
5. Revisar dashboards, niveles, rachas y títulos.
6. Probar biometría opcional, recuperación, autobloqueo y `FLAG_SECURE`.
7. Repetir con texto 2.0×, alto contraste, movimiento reducido e importes ocultos.
8. Confirmar que no aparecen títulos, notas, importes, PIN ni identificadores
   sensibles en notificaciones, capturas o logs.
9. Reinstalar con `adb install -r` usando otra APK firmada con la misma llave y
   confirmar que datos, acceso y esquema v1 se conservan.

## Criterio de cierre G8

G8 solo queda verde cuando no hay defectos S0/S1, ambos factores de forma pasan,
las métricas cumplen, APK y AAB están firmados/verificados, los hashes quedan
registrados y el usuario aprueba este recorrido. Una prueba omitida mantiene A8
en progreso.
