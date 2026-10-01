import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/profile/data/drift_user_profile_repository.dart';
import 'package:bitacora_rpg_personal/features/profile/domain/models/user_profile.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/settings_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftUserProfileRepository repository;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => 1787600000000,
    );
    repository = DriftUserProfileRepository(SettingsDao(database));
  });

  tearDown(() => database.close());

  test('expone el perfil local por defecto sin migrar el esquema', () async {
    final Result<UserProfile> result = await repository.load();

    expect(result, isA<Success<UserProfile>>());
    final UserProfile profile = (result as Success<UserProfile>).value;
    expect(profile.displayName, 'Usuario local');
    expect(profile.avatarPath, isNull);
    expect(database.schemaVersion, 4);
  });

  test('persiste nombre y ruta privada como un único valor JSON', () async {
    const UserProfile expected = UserProfile(
      displayName: 'Sensei',
      avatarPath: '/private/profile/avatar.jpg',
    );

    expect(await repository.save(expected), isA<Success<void>>());
    final Result<UserProfile> result = await repository.load();

    expect(result, isA<Success<UserProfile>>());
    final UserProfile actual = (result as Success<UserProfile>).value;
    expect(actual.displayName, expected.displayName);
    expect(actual.avatarPath, expected.avatarPath);
  });

  test('rechaza un nombre vacío sin escribir metadatos', () async {
    final Result<void> result = await repository.save(
      const UserProfile(displayName: '   '),
    );

    expect(result, isA<Failure<void>>());
    expect(
      await SettingsDao(
        database,
      ).getMetadata(DriftUserProfileRepository.metadataKey),
      isNull,
    );
  });
}
