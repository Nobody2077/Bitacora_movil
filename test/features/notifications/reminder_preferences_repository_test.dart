import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/notifications/data/drift_reminder_preferences_repository.dart';
import 'package:bitacora_rpg_personal/features/notifications/domain/reminder_preferences.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/settings_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftReminderPreferencesRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftReminderPreferencesRepository(SettingsDao(database));
  });

  tearDown(() => database.close());

  test('usa valores seguros cuando todavía no existe configuración', () async {
    final Result<ReminderPreferences> result = await repository.load();

    expect(result, isA<Success<ReminderPreferences>>());
    final ReminderPreferences preferences =
        (result as Success<ReminderPreferences>).value;
    expect(preferences.leadMinutes, 15);
    expect(preferences.quietHoursEnabled, isFalse);
    expect(preferences.quietStartMinutes, 22 * 60);
    expect(preferences.quietEndMinutes, 7 * 60);
  });

  test('persiste anticipación y horario silencioso en metadata', () async {
    const ReminderPreferences expected = ReminderPreferences(
      leadMinutes: 30,
      quietHoursEnabled: true,
      quietStartMinutes: 21 * 60 + 30,
      quietEndMinutes: 6 * 60 + 45,
      dailySummaryEnabled: false,
      dailySummaryMinutes: 6 * 60,
      genericText: ReminderPreferences.defaultGenericText,
    );

    expect(await repository.save(expected), isA<Success<void>>());
    final Result<ReminderPreferences> loaded = await repository.load();

    expect(loaded, isA<Success<ReminderPreferences>>());
    final ReminderPreferences actual =
        (loaded as Success<ReminderPreferences>).value;
    expect(actual.leadMinutes, expected.leadMinutes);
    expect(actual.quietHoursEnabled, isTrue);
    expect(actual.quietStartMinutes, expected.quietStartMinutes);
    expect(actual.quietEndMinutes, expected.quietEndMinutes);
    expect(await SettingsDao(database).getSchemaVersionMirror(), 3);
  });

  test('rechaza anticipación y horas no soportadas', () async {
    const ReminderPreferences invalid = ReminderPreferences(
      leadMinutes: 17,
      quietHoursEnabled: true,
      quietStartMinutes: 300,
      quietEndMinutes: 300,
      dailySummaryEnabled: false,
      dailySummaryMinutes: 6 * 60,
      genericText: ReminderPreferences.defaultGenericText,
    );

    expect(await repository.save(invalid), isA<Failure<void>>());
  });

  test('detecta horario silencioso que cruza medianoche', () {
    const ReminderPreferences preferences = ReminderPreferences(
      leadMinutes: 15,
      quietHoursEnabled: true,
      quietStartMinutes: 22 * 60,
      quietEndMinutes: 7 * 60,
      dailySummaryEnabled: false,
      dailySummaryMinutes: 6 * 60,
      genericText: ReminderPreferences.defaultGenericText,
    );
    final DateTime now = DateTime.now();
    final DateTime late = DateTime(now.year, now.month, now.day, 23);
    final DateTime morning = DateTime(now.year, now.month, now.day, 6, 59);
    final DateTime daytime = DateTime(now.year, now.month, now.day, 12);

    expect(
      preferences.isQuietAtUtcMs(late.toUtc().millisecondsSinceEpoch),
      isTrue,
    );
    expect(
      preferences.isQuietAtUtcMs(morning.toUtc().millisecondsSinceEpoch),
      isTrue,
    );
    expect(
      preferences.isQuietAtUtcMs(daytime.toUtc().millisecondsSinceEpoch),
      isFalse,
    );
  });
}
