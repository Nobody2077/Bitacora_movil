import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/daos/settings_dao.dart';
import '../domain/models/app_preferences.dart';
import '../domain/repositories/settings_repository.dart';
import 'settings_mapper.dart';

final class DriftSettingsRepository implements SettingsRepository {
  const DriftSettingsRepository(this._dao);

  final SettingsDao _dao;

  @override
  Future<Result<AppPreferences>> load() async {
    try {
      return Success<AppPreferences>(
        SettingsMapper.fromDrift(await _dao.getSettings()),
      );
    } on Object catch (error) {
      return Failure<AppPreferences>(
        StorageFailure('No se pudieron leer los ajustes.', cause: error),
      );
    }
  }

  @override
  Future<Result<void>> save(AppPreferences preferences) async {
    if (!preferences.updatedAtUtc.isUtc ||
        preferences.themeKey.trim().isEmpty ||
        preferences.autoLockMinutes < 0) {
      return const Failure<void>(
        ValidationFailure('Los ajustes contienen valores inválidos.'),
      );
    }

    try {
      await _dao.updateSettings(SettingsMapper.toDrift(preferences));
      return const Success<void>(null);
    } on Object catch (error) {
      return Failure<void>(
        StorageFailure('No se pudieron guardar los ajustes.', cause: error),
      );
    }
  }
}
