import 'dart:io';

import 'package:path/path.dart' as path;

import '../../features/settings/domain/models/app_preferences.dart';

abstract interface class AccessAccentPreferenceStore {
  Future<AppAccentColor> read();

  Future<void> write(AppAccentColor color);
}

/// Espejo no sensible disponible antes de abrir la base cifrada.
///
/// Solo conserva una de las tres opciones de color admitidas. No almacena PIN,
/// credenciales ni contenido privado.
final class FileAccessAccentPreferenceStore
    implements AccessAccentPreferenceStore {
  const FileAccessAccentPreferenceStore({required this.directoryLocator});

  static const String fileName = 'access_accent_v1.txt';

  final Future<Directory> Function() directoryLocator;

  @override
  Future<AppAccentColor> read() async {
    final File file = await _file();
    if (!await file.exists()) {
      return AppAccentColor.red;
    }
    return AppAccentColor.fromHex((await file.readAsString()).trim());
  }

  @override
  Future<void> write(AppAccentColor color) async {
    final File file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(color.hex, flush: true);
  }

  Future<File> _file() async =>
      File(path.join((await directoryLocator()).path, fileName));
}
