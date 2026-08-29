import 'dart:io';

import 'package:bitacora_rpg_personal/app/theme/access_accent_preference_store.dart';
import 'package:bitacora_rpg_personal/features/settings/domain/models/app_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('usa rojo sin espejo y persiste únicamente el color elegido', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'bitacora-accent-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final FileAccessAccentPreferenceStore store =
        FileAccessAccentPreferenceStore(
          directoryLocator: () async => directory,
        );

    expect(await store.read(), AppAccentColor.red);

    await store.write(AppAccentColor.yellow);

    expect(await store.read(), AppAccentColor.yellow);
    final File mirror = File(
      '${directory.path}${Platform.pathSeparator}'
      '${FileAccessAccentPreferenceStore.fileName}',
    );
    expect(await mirror.readAsString(), AppAccentColor.yellow.hex);
    expect(await mirror.readAsString(), isNot(contains('PIN')));
  });

  test('un valor desconocido falla de forma segura al rojo', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'bitacora-accent-invalid-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File mirror = File(
      '${directory.path}${Platform.pathSeparator}'
      '${FileAccessAccentPreferenceStore.fileName}',
    );
    await mirror.writeAsString('#123456');
    final FileAccessAccentPreferenceStore store =
        FileAccessAccentPreferenceStore(
          directoryLocator: () async => directory,
        );

    expect(await store.read(), AppAccentColor.red);
  });
}
