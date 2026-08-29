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
      final AppPreferences preferences = SettingsMapper.fromDrift(
        await _dao.getSettings(),
      );
      if (!AppPreferences.supportedAutoLockMinutes.contains(
        preferences.autoLockMinutes,
      )) {
        return const Failure<AppPreferences>(
          ValidationFailure('El autobloqueo persistido no está soportado.'),
        );
      }
      return Success<AppPreferences>(preferences);
    } on Object catch (error) {
      return Failure<AppPreferences>(
        StorageFailure('No se pudieron leer los ajustes.', cause: error),
      );
    }
  }

  @override
  Stream<Result<AppPreferences>> watch() async* {
    try {
      await for (final value in _dao.watchSettings()) {
        final AppPreferences preferences = SettingsMapper.fromDrift(value);
        if (!AppPreferences.supportedAutoLockMinutes.contains(
          preferences.autoLockMinutes,
        )) {
          yield const Failure<AppPreferences>(
            ValidationFailure('El autobloqueo persistido no está soportado.'),
          );
          continue;
        }
        yield Success<AppPreferences>(preferences);
      }
    } on Object catch (error) {
      yield Failure<AppPreferences>(
        StorageFailure('No se pudieron observar los ajustes.', cause: error),
      );
    }
  }

  @override
  Future<Result<void>> save(AppPreferences preferences) async {
    if (!preferences.updatedAtUtc.isUtc ||
        preferences.themeKey.trim().isEmpty ||
        !AppPreferences.supportedPrimaryColorHex.contains(
          preferences.primaryColorHex.toUpperCase(),
        ) ||
        !AppPreferences.supportedAutoLockMinutes.contains(
          preferences.autoLockMinutes,
        )) {
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
