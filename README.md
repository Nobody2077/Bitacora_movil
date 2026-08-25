# Bitácora RPG Personal

Aplicación Flutter Android, local-first y privada para organizar misiones, registrar economía, construir una Bitácora personal y visualizar progreso.

## Estado

- Fases completadas: **A0 — Base del proyecto** y **A1 — Persistencia**.
- Siguiente fase autorizada: **A2 — Acceso y privacidad**.
- Contrato vinculante: [`documentos/DECISIONES_PRE_A0.md`](documentos/DECISIONES_PRE_A0.md).
- Evidencia y gates: [`documentos/ESTADO_FASES.md`](documentos/ESTADO_FASES.md).
- Documentación fuente: [`documentos/`](documentos/).

## Ejecutar

```powershell
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart
```

Build debug reproducible:

```powershell
flutter build apk --debug --flavor dev -t lib/main_dev.dart
```

Calidad completa:

```powershell
powershell -ExecutionPolicy Bypass -File tool/quality.ps1
```

Gate G1 completo con emulador Android activo:

```powershell
powershell -ExecutionPolicy Bypass -File tool/gate_g1.ps1 -DeviceId emulator-5554
```

No se inicia una fase si el gate inmediatamente anterior está rojo.
