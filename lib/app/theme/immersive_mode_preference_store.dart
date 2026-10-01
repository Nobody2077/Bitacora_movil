import 'dart:io';

import 'package:path/path.dart' as path;

abstract interface class ImmersiveModePreferenceStore {
  Future<bool> read();

  Future<void> write(bool enabled);
}

/// Espejo no sensible disponible antes de abrir la base cifrada, como el color
/// de acceso: la pantalla completa se aplica también en la pantalla del PIN.
///
/// Solo guarda un interruptor. Activado por defecto (decisión del usuario del
/// 1 de octubre de 2026): la app ya muestra su propia hora y batería.
final class FileImmersiveModePreferenceStore
    implements ImmersiveModePreferenceStore {
  const FileImmersiveModePreferenceStore({required this.directoryLocator});

  static const String fileName = 'immersive_v1.txt';

  final Future<Directory> Function() directoryLocator;

  @override
  Future<bool> read() async {
    final File file = await _file();
    if (!await file.exists()) {
      return true;
    }
    return (await file.readAsString()).trim() != '0';
  }

  @override
  Future<void> write(bool enabled) async {
    final File file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(enabled ? '1' : '0', flush: true);
  }

  Future<File> _file() async =>
      File(path.join((await directoryLocator()).path, fileName));
}
