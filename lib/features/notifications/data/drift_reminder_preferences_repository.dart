import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/app_database.dart';
import '../../../infrastructure/database/daos/settings_dao.dart';
import '../domain/reminder_preferences.dart';
import '../domain/reminder_preferences_repository.dart';

final class DriftReminderPreferencesRepository
    implements ReminderPreferencesRepository {
  const DriftReminderPreferencesRepository(this._dao);

  static const String _leadKey = 'notification_lead_minutes';
  static const String _quietEnabledKey = 'notification_quiet_enabled';
  static const String _quietStartKey = 'notification_quiet_start_minutes';
  static const String _quietEndKey = 'notification_quiet_end_minutes';

  final SettingsDao _dao;

  @override
  Future<Result<ReminderPreferences>> load() async {
    try {
      final List<SchemaMetadataData> rows = await _dao.getMetadataEntries(
        const <String>{
          _leadKey,
          _quietEnabledKey,
          _quietStartKey,
          _quietEndKey,
        },
      );
      return _decode(rows);
    } on Object catch (error) {
      return Failure<ReminderPreferences>(
        StorageFailure('No se pudieron leer los recordatorios.', cause: error),
      );
    }
  }

  @override
  Stream<Result<ReminderPreferences>> watch() async* {
    try {
      await for (final List<SchemaMetadataData> rows in _dao.watchMetadata()) {
        yield _decode(rows);
      }
    } on Object catch (error) {
      yield Failure<ReminderPreferences>(
        StorageFailure(
          'No se pudieron observar los recordatorios.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> save(ReminderPreferences preferences) async {
    if (!preferences.isValid) {
      return const Failure<void>(
        ValidationFailure('La configuración de recordatorios no es válida.'),
      );
    }
    try {
      await _dao.putMetadataBatch(<String, String>{
        _leadKey: '${preferences.leadMinutes}',
        _quietEnabledKey: preferences.quietHoursEnabled ? '1' : '0',
        _quietStartKey: '${preferences.quietStartMinutes}',
        _quietEndKey: '${preferences.quietEndMinutes}',
      }, updatedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch);
      return const Success<void>(null);
    } on Object catch (error) {
      return Failure<void>(
        StorageFailure(
          'No se pudieron guardar los recordatorios.',
          cause: error,
        ),
      );
    }
  }

  Result<ReminderPreferences> _decode(List<SchemaMetadataData> rows) {
    final Map<String, String> values = <String, String>{
      for (final SchemaMetadataData row in rows) row.key: row.value,
    };
    final ReminderPreferences defaults = ReminderPreferences.defaults;
    final ReminderPreferences preferences = ReminderPreferences(
      leadMinutes: int.tryParse(values[_leadKey] ?? '') ?? defaults.leadMinutes,
      quietHoursEnabled: switch (values[_quietEnabledKey]) {
        '1' => true,
        '0' => false,
        _ => defaults.quietHoursEnabled,
      },
      quietStartMinutes:
          int.tryParse(values[_quietStartKey] ?? '') ??
          defaults.quietStartMinutes,
      quietEndMinutes:
          int.tryParse(values[_quietEndKey] ?? '') ?? defaults.quietEndMinutes,
    );
    if (!preferences.isValid) {
      return const Failure<ReminderPreferences>(
        ValidationFailure(
          'La configuración de recordatorios almacenada no es válida.',
        ),
      );
    }
    return Success<ReminderPreferences>(preferences);
  }
}
