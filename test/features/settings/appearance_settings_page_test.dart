import 'dart:async';

import 'package:bitacora_rpg_personal/app/providers/app_preferences_provider.dart';
import 'package:bitacora_rpg_personal/app/providers/persistence_providers.dart';
import 'package:bitacora_rpg_personal/app/theme/access_accent_preference_store.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/app/theme/app_ui_preferences.dart';
import 'package:bitacora_rpg_personal/app/theme/immersive_mode_preference_store.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/settings/domain/models/app_preferences.dart';
import 'package:bitacora_rpg_personal/features/settings/domain/repositories/settings_repository.dart';
import 'package:bitacora_rpg_personal/features/settings/presentation/appearance_settings_page.dart';
import 'package:bitacora_rpg_personal/shared/widgets/terminal/terminal_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra y persiste apariencia y accesibilidad', (
    WidgetTester tester,
  ) async {
    final _FakeSettingsRepository repository = _FakeSettingsRepository();
    addTearDown(repository.dispose);
    await _pumpAppearance(tester, repository: repository);

    expect(find.byKey(const Key('large-text-switch')), findsOneWidget);
    expect(find.byKey(const Key('reduce-motion-switch')), findsOneWidget);
    expect(find.byKey(const Key('high-contrast-switch')), findsOneWidget);
    expect(find.byKey(const Key('hide-amounts-switch')), findsOneWidget);
    expect(find.byKey(const Key('access-accent-yellow')), findsOneWidget);
    expect(find.byKey(const Key('access-accent-red')), findsOneWidget);
    expect(find.byKey(const Key('access-accent-gray')), findsOneWidget);

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

  testWidgets('persiste amarillo para el acceso previo a la base cifrada', (
    WidgetTester tester,
  ) async {
    final _FakeSettingsRepository repository = _FakeSettingsRepository();
    final _MemoryAccessAccentPreferenceStore accentStore =
        _MemoryAccessAccentPreferenceStore();
    addTearDown(repository.dispose);
    await _pumpAppearance(
      tester,
      repository: repository,
      accentStore: accentStore,
    );

    await tester.tap(find.byKey(const Key('access-accent-yellow')));
    await tester.pumpAndSettle();

    expect(repository.current.primaryColorHex, AppAccentColor.yellow.hex);
    expect(accentStore.current, AppAccentColor.yellow);
  });

  testWidgets('cumple objetivos táctiles, etiquetas y contraste en compacto', (
    WidgetTester tester,
  ) async {
    final _FakeSettingsRepository repository = _FakeSettingsRepository();
    addTearDown(repository.dispose);
    await _pumpAppearance(tester, repository: repository);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('texto 2.0x mantiene todos los controles alcanzables', (
    WidgetTester tester,
  ) async {
    final _FakeSettingsRepository repository = _FakeSettingsRepository();
    addTearDown(repository.dispose);
    await _pumpAppearance(tester, repository: repository, textScale: 2);

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('hide-amounts-switch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hide-amounts-switch')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cambia de una a dos columnas exactamente en 840 px', (
    WidgetTester tester,
  ) async {
    final _FakeSettingsRepository repository = _FakeSettingsRepository();
    addTearDown(repository.dispose);

    await _pumpAppearance(
      tester,
      repository: repository,
      size: const Size(839, 1400),
    );
    final double mediumFirstY = tester
        .getTopLeft(_cardFor(const Key('large-text-switch')))
        .dy;
    final double mediumSecondY = tester
        .getTopLeft(_cardFor(const Key('reduce-motion-switch')))
        .dy;
    expect(mediumSecondY, greaterThan(mediumFirstY));

    await _pumpAppearance(
      tester,
      repository: repository,
      size: const Size(840, 800),
    );
    final double expandedFirstY = tester
        .getTopLeft(_cardFor(const Key('large-text-switch')))
        .dy;
    final double expandedSecondY = tester
        .getTopLeft(_cardFor(const Key('reduce-motion-switch')))
        .dy;
    expect(expandedSecondY, expandedFirstY);
  });

  testWidgets('golden compacto', (WidgetTester tester) async {
    final _FakeSettingsRepository repository = _FakeSettingsRepository();
    addTearDown(repository.dispose);
    await _pumpAppearance(tester, repository: repository);

    await expectLater(
      find.byType(AppearanceSettingsPage),
      matchesGoldenFile('goldens/appearance_compact.png'),
    );
  });

  testWidgets('golden expandido con alto contraste', (
    WidgetTester tester,
  ) async {
    final _FakeSettingsRepository repository = _FakeSettingsRepository(
      initial: AppPreferences.defaults.copyWith(
        reduceMotion: true,
        highContrast: true,
        hideAmounts: true,
      ),
    );
    addTearDown(repository.dispose);
    await _pumpAppearance(
      tester,
      repository: repository,
      size: const Size(1280, 800),
    );

    await expectLater(
      find.byType(AppearanceSettingsPage),
      matchesGoldenFile('goldens/appearance_expanded_high_contrast.png'),
    );
  });

  testWidgets('golden compacto con texto 2.0x', (WidgetTester tester) async {
    final _FakeSettingsRepository repository = _FakeSettingsRepository();
    addTearDown(repository.dispose);
    await _pumpAppearance(tester, repository: repository, textScale: 2);

    await expectLater(
      find.byType(AppearanceSettingsPage),
      matchesGoldenFile('goldens/appearance_compact_text_2x.png'),
    );
  });
}

Finder _cardFor(Key switchKey) => find.ancestor(
  of: find.byKey(switchKey),
  matching: find.byType(TerminalCard),
);

Future<void> _pumpAppearance(
  WidgetTester tester, {
  required _FakeSettingsRepository repository,
  Size size = const Size(412, 915),
  double textScale = 1,
  AccessAccentPreferenceStore? accentStore,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final AppPreferences preferences = repository.current;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repository),
        accessAccentPreferenceStoreProvider.overrideWithValue(
          accentStore ?? _MemoryAccessAccentPreferenceStore(),
        ),
        immersiveModePreferenceStoreProvider.overrideWithValue(
          _MemoryImmersiveStore(),
        ),
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
        theme: AppTheme.dark(highContrast: preferences.highContrast),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: AppUiPreferencesBoundary(
            preferences: AppUiPreferences(
              largeText: preferences.largeText,
              reduceMotion: preferences.reduceMotion,
              highContrast: preferences.highContrast,
              hideAmounts: preferences.hideAmounts,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const AppearanceSettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _MemoryImmersiveStore implements ImmersiveModePreferenceStore {
  bool current = true;

  @override
  Future<bool> read() async => current;

  @override
  Future<void> write(bool enabled) async => current = enabled;
}

final class _MemoryAccessAccentPreferenceStore
    implements AccessAccentPreferenceStore {
  AppAccentColor current = AppAccentColor.red;

  @override
  Future<AppAccentColor> read() async => current;

  @override
  Future<void> write(AppAccentColor color) async => current = color;
}

final class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({AppPreferences? initial})
    : current = initial ?? AppPreferences.defaults;

  final StreamController<Result<AppPreferences>> _changes =
      StreamController<Result<AppPreferences>>.broadcast();

  AppPreferences current;
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
