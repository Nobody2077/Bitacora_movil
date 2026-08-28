import 'dart:async';

import 'package:bitacora_rpg_personal/app/providers/app_preferences_provider.dart';
import 'package:bitacora_rpg_personal/app/providers/persistence_providers.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/settings/domain/models/app_preferences.dart';
import 'package:bitacora_rpg_personal/features/settings/domain/repositories/settings_repository.dart';
import 'package:bitacora_rpg_personal/features/settings/presentation/appearance_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra y persiste las cuatro preferencias de A7', (
    WidgetTester tester,
  ) async {
    final _FakeSettingsRepository repository = _FakeSettingsRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
          appPreferencesProvider.overrideWith(
            (ref) => repository.watch().map(
              (Result<AppPreferences> result) => result.fold(
                onSuccess: (AppPreferences value) => value,
                onFailure: (failure) => throw failure,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const AppearanceSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('large-text-switch')), findsOneWidget);
    expect(find.byKey(const Key('reduce-motion-switch')), findsOneWidget);
    expect(find.byKey(const Key('high-contrast-switch')), findsOneWidget);
    expect(find.byKey(const Key('hide-amounts-switch')), findsOneWidget);

    await tester.tap(find.byKey(const Key('high-contrast-switch')));
    await tester.pumpAndSettle();

    expect(repository.current.highContrast, isTrue);
    expect(repository.saveCount, 1);
    expect(
      tester
          .widget<Switch>(find.byKey(const Key('high-contrast-switch')))
          .value,
      isTrue,
    );
  });
}

final class _FakeSettingsRepository implements SettingsRepository {
  final StreamController<Result<AppPreferences>> _changes =
      StreamController<Result<AppPreferences>>.broadcast();

  AppPreferences current = AppPreferences.defaults;
  int saveCount = 0;

  @override
  Future<Result<AppPreferences>> load() async =>
      Success<AppPreferences>(current);

  @override
  Future<Result<void>> save(AppPreferences preferences) async {
    current = preferences;
    saveCount += 1;
    _changes.add(Success<AppPreferences>(current));
    return const Success<void>(null);
  }

  @override
  Stream<Result<AppPreferences>> watch() async* {
    yield Success<AppPreferences>(current);
    yield* _changes.stream;
  }

  Future<void> dispose() => _changes.close();
}
