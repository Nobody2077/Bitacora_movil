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
      final AppPreferences preferences = await _loadPreferences();
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
        final AppPreferences preferences = await _applyMetadata(
          SettingsMapper.fromDrift(value),
        );
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
      await _dao.updateSettingsWithMetadata(
        SettingsMapper.toDrift(preferences),
        <String, String>{
          AppPreferences.allowScreenshotsMetadataKey: _encodeBool(
            preferences.allowScreenshots,
          ),
          AppPreferences.showNotificationDetailsMetadataKey: _encodeBool(
            preferences.showNotificationDetails,
          ),
          AppPreferences.allowCameraAttachmentsMetadataKey: _encodeBool(
            preferences.allowCameraAttachments,
          ),
          AppPreferences.textColorMetadataKey: preferences.cyanText
              ? 'cyan'
              : 'white',
        },
        updatedAtUtcMs: preferences.updatedAtUtc.millisecondsSinceEpoch,
      );
      return const Success<void>(null);
    } on Object catch (error) {
      return Failure<void>(
        StorageFailure('No se pudieron guardar los ajustes.', cause: error),
      );
    }
  }

  Future<AppPreferences> _loadPreferences() async =>
      _applyMetadata(SettingsMapper.fromDrift(await _dao.getSettings()));

  Future<AppPreferences> _applyMetadata(AppPreferences preferences) async {
    final entries = await _dao.getMetadataEntries(AppPreferences.metadataKeys);
    final Map<String, String> values = <String, String>{
      for (final entry in entries) entry.key: entry.value,
    };
    return preferences.copyWith(
      allowScreenshots: _decodeBool(
        values[AppPreferences.allowScreenshotsMetadataKey],
      ),
      showNotificationDetails: _decodeBool(
        values[AppPreferences.showNotificationDetailsMetadataKey],
      ),
      allowCameraAttachments: _decodeBool(
        values[AppPreferences.allowCameraAttachmentsMetadataKey],
      ),
      cyanText: values[AppPreferences.textColorMetadataKey] == 'cyan',
    );
  }

  static bool _decodeBool(String? value) => value == '1';

  static String _encodeBool(bool value) => value ? '1' : '0';
}
