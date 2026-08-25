import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

const String applicationDatabaseFileName = 'bitacora_rpg.sqlite';

/// Locates the application database without opening it or requesting its key.
abstract interface class DatabaseFileLocator {
  Future<File> resolve();

  Future<bool> exists();
}

final class AppSupportDatabaseFileLocator implements DatabaseFileLocator {
  const AppSupportDatabaseFileLocator();

  @override
  Future<File> resolve() async {
    final Directory supportDirectory = await getApplicationSupportDirectory();
    return File(path.join(supportDirectory.path, applicationDatabaseFileName));
  }

  @override
  Future<bool> exists() async => (await resolve()).exists();
}
