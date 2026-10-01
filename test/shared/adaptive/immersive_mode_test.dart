import 'dart:io';

import 'package:bitacora_rpg_personal/app/providers/app_preferences_provider.dart';
import 'package:bitacora_rpg_personal/app/theme/immersive_mode_preference_store.dart';
import 'package:bitacora_rpg_personal/shared/adaptive/immersive_mode_boundary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemoryImmersiveStore implements ImmersiveModePreferenceStore {
  _MemoryImmersiveStore(this.value);

  bool value;

  @override
  Future<bool> read() async => value;

  @override
  Future<void> write(bool enabled) async => value = enabled;
}

void main() {
  group('FileImmersiveModePreferenceStore', () {
    test('sin espejo, la pantalla completa queda activada', () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'bitacora-immersive-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final FileImmersiveModePreferenceStore store =
          FileImmersiveModePreferenceStore(
            directoryLocator: () async => directory,
          );

      expect(await store.read(), isTrue);

      await store.write(false);
      expect(await store.read(), isFalse);
      await store.write(true);
      expect(await store.read(), isTrue);
    });
  });

  testWidgets('aplica el modo guardado y lo repite al volver a la app', (
    WidgetTester tester,
  ) async {
    final List<bool> applied = <bool>[];
    final _MemoryImmersiveStore store = _MemoryImmersiveStore(true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          immersiveModePreferenceStoreProvider.overrideWithValue(store),
          systemUiModeApplierProvider.overrideWithValue(
            (bool immersive) async => applied.add(immersive),
          ),
        ],
        child: const ImmersiveModeBoundary(child: SizedBox()),
      ),
    );
    await tester.pumpAndSettle();
    expect(applied, <bool>[true]);

    // Repintar sin cambios no vuelve a llamar a la plataforma.
    await tester.pump();
    expect(applied, <bool>[true]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(applied, <bool>[true, true]);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(ImmersiveModeBoundary)),
    );
    await store.write(false);
    container.invalidate(immersiveModeProvider);
    await tester.pumpAndSettle();
    expect(applied, <bool>[true, true, false]);
  });
}
