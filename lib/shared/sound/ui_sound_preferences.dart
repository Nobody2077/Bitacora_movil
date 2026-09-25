import 'dart:io';

import 'package:path/path.dart' as path;

/// Qué grupos de efectos de sonido están activos. Ambos, desactivados por
/// defecto: el sonido lo oyen terceros y debe ser una elección explícita.
final class UiSoundPreferences {
  const UiSoundPreferences({
    required this.rewardEnabled,
    required this.interfaceEnabled,
  });

  static const UiSoundPreferences defaults = UiSoundPreferences(
    rewardEnabled: false,
    interfaceEnabled: false,
  );

  /// Acceso, misión creada, misión completada y subida de nivel.
  final bool rewardEnabled;

  /// Cambio de sección en el menú. Separado porque es frecuente y puede
  /// cansar sin que por ello se quiera perder el resto.
  final bool interfaceEnabled;

  UiSoundPreferences copyWith({bool? rewardEnabled, bool? interfaceEnabled}) =>
      UiSoundPreferences(
        rewardEnabled: rewardEnabled ?? this.rewardEnabled,
        interfaceEnabled: interfaceEnabled ?? this.interfaceEnabled,
      );

  @override
  bool operator ==(Object other) =>
      other is UiSoundPreferences &&
      other.rewardEnabled == rewardEnabled &&
      other.interfaceEnabled == interfaceEnabled;

  @override
  int get hashCode => Object.hash(rewardEnabled, interfaceEnabled);
}

abstract interface class UiSoundPreferenceStore {
  Future<UiSoundPreferences> read();

  Future<void> write(UiSoundPreferences preferences);
}

/// Espejo no sensible disponible antes de abrir la base cifrada, igual que el
/// color de acceso: el sonido de acceso concedido suena justo al desbloquear.
///
/// Solo guarda dos interruptores. No almacena PIN, credenciales ni contenido
/// privado.
final class FileUiSoundPreferenceStore implements UiSoundPreferenceStore {
  const FileUiSoundPreferenceStore({required this.directoryLocator});

  static const String fileName = 'ui_sound_v1.txt';
  static const String _rewardKey = 'reward';
  static const String _interfaceKey = 'interface';

  final Future<Directory> Function() directoryLocator;

  @override
  Future<UiSoundPreferences> read() async {
    final File file = await _file();
    if (!await file.exists()) {
      return UiSoundPreferences.defaults;
    }
    final Map<String, String> values = <String, String>{
      for (final String line in await file.readAsLines())
        if (line.contains('='))
          line.substring(0, line.indexOf('=')).trim(): line
              .substring(line.indexOf('=') + 1)
              .trim(),
    };
    return UiSoundPreferences(
      rewardEnabled: values[_rewardKey] == '1',
      interfaceEnabled: values[_interfaceKey] == '1',
    );
  }

  @override
  Future<void> write(UiSoundPreferences preferences) async {
    final File file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '$_rewardKey=${preferences.rewardEnabled ? 1 : 0}\n'
      '$_interfaceKey=${preferences.interfaceEnabled ? 1 : 0}\n',
      flush: true,
    );
  }

  Future<File> _file() async =>
      File(path.join((await directoryLocator()).path, fileName));
}
