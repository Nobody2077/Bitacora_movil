import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/settings/data/drift_settings_repository.dart';
import 'package:bitacora_rpg_personal/features/settings/domain/models/app_preferences.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/settings_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftSettingsRepository repository;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => 1787600000000,
    );
    repository = DriftSettingsRepository(SettingsDao(database));
  });

  tearDown(() => database.close());

  test('rechaza guardar un timeout fuera de 0, 1, 5 y 15', () async {
    final Result<AppPreferences> loaded = await repository.load();
    expect(loaded, isA<Success<AppPreferences>>());
    final AppPreferences baseline = (loaded as Success<AppPreferences>).value;

    final Result<void> saved = await repository.save(
      baseline.copyWith(
        autoLockMinutes: 2,
        updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
          1787600000001,
          isUtc: true,
        ),
      ),
    );

    expect(saved, isA<Failure<void>>());
    final AppPreferences after =
        (await repository.load() as Success<AppPreferences>).value;
    expect(after.autoLockMinutes, 5);
  });

  test('un timeout persistido no soportado se carga como fallo', () async {
    await database.customStatement(
      'UPDATE app_settings SET auto_lock_minutes = 2 WHERE id = 1',
    );

    expect(await repository.load(), isA<Failure<AppPreferences>>());
  });
}
