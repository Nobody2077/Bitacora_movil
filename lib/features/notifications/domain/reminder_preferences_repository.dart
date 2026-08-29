import '../../../core/result/result.dart';
import 'reminder_preferences.dart';

abstract interface class ReminderPreferencesRepository {
  Future<Result<ReminderPreferences>> load();

  Stream<Result<ReminderPreferences>> watch();

  Future<Result<void>> save(ReminderPreferences preferences);
}
