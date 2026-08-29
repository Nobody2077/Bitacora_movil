import 'dart:async';

import 'package:bitacora_rpg_personal/app/providers/app_preferences_provider.dart';
import 'package:bitacora_rpg_personal/app/providers/persistence_providers.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/notifications/application/notification_providers.dart';
import 'package:bitacora_rpg_personal/features/notifications/domain/reminder_preferences.dart';
import 'package:bitacora_rpg_personal/features/notifications/domain/reminder_preferences_repository.dart';
import 'package:bitacora_rpg_personal/features/notifications/presentation/notification_settings_page.dart';
import 'package:bitacora_rpg_personal/features/settings/domain/models/app_preferences.dart';
import 'package:bitacora_rpg_personal/features/settings/domain/repositories/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('configura anticipación y horario silencioso', (
    WidgetTester tester,
  ) async {
    final _FakeSettingsRepository settings = _FakeSettingsRepository();
    final _FakeReminderRepository reminders = _FakeReminderRepository();
    addTearDown(settings.dispose);
    addTearDown(reminders.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          reminderPreferencesRepositoryProvider.overrideWithValue(reminders),
          appPreferencesProvider.overrideWith(
            (ref) => settings.watch().map(
              (result) => result.fold(
                onSuccess: (AppPreferences value) => value,
                onFailure: (failure) => throw failure,
              ),
            ),
          ),
          reminderPreferencesProvider.overrideWith(
            (ref) => reminders.watch().map(
              (result) => result.fold(
                onSuccess: (ReminderPreferences value) => value,
                onFailure: (failure) => throw failure,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const NotificationSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NOTIFICACIONES'), findsOneWidget);
    expect(
      find.byKey(const Key('mission-notifications-switch')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('notification-lead-selector')), findsOneWidget);

    await tester.tap(find.byKey(const Key('quiet-hours-switch')));
    await tester.pumpAndSettle();

    expect(reminders.current.quietHoursEnabled, isTrue);
    expect(find.byKey(const Key('quiet-start-button')), findsOneWidget);
    expect(find.byKey(const Key('quiet-end-button')), findsOneWidget);
  });

  testWidgets('mantiene controles alcanzables con texto 2.0x', (
    WidgetTester tester,
  ) async {
    final _FakeSettingsRepository settings = _FakeSettingsRepository();
    final _FakeReminderRepository reminders = _FakeReminderRepository(
      initial: ReminderPreferences.defaults.copyWith(quietHoursEnabled: true),
    );
    addTearDown(settings.dispose);
    addTearDown(reminders.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          reminderPreferencesRepositoryProvider.overrideWithValue(reminders),
          appPreferencesProvider.overrideWith(
            (ref) => settings.watch().map(
              (result) => result.fold(
                onSuccess: (AppPreferences value) => value,
                onFailure: (failure) => throw failure,
              ),
            ),
          ),
          reminderPreferencesProvider.overrideWith(
            (ref) => reminders.watch().map(
              (result) => result.fold(
                onSuccess: (ReminderPreferences value) => value,
                onFailure: (failure) => throw failure,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const NotificationSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('quiet-end-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiet-end-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _FakeSettingsRepository implements SettingsRepository {
  AppPreferences current = AppPreferences.defaults;
  final StreamController<Result<AppPreferences>> _changes =
      StreamController<Result<AppPreferences>>.broadcast();

  @override
  Future<Result<AppPreferences>> load() async => Success(current);

  @override
  Future<Result<void>> save(AppPreferences preferences) async {
    current = preferences;
    _changes.add(Success(current));
    return const Success<void>(null);
  }

  @override
  Stream<Result<AppPreferences>> watch() async* {
    yield Success(current);
    yield* _changes.stream;
  }

  Future<void> dispose() => _changes.close();
}

final class _FakeReminderRepository implements ReminderPreferencesRepository {
  _FakeReminderRepository({ReminderPreferences? initial})
    : current = initial ?? ReminderPreferences.defaults;

  ReminderPreferences current;
  final StreamController<Result<ReminderPreferences>> _changes =
      StreamController<Result<ReminderPreferences>>.broadcast();

  @override
  Future<Result<ReminderPreferences>> load() async => Success(current);

  @override
  Future<Result<void>> save(ReminderPreferences preferences) async {
    current = preferences;
    _changes.add(Success(current));
    return const Success<void>(null);
  }

  @override
  Stream<Result<ReminderPreferences>> watch() async* {
    yield Success(current);
    yield* _changes.stream;
  }

  Future<void> dispose() => _changes.close();
}
