import '../../../../core/result/result.dart';
import '../models/app_preferences.dart';

abstract interface class SettingsRepository {
  Future<Result<AppPreferences>> load();

  Future<Result<void>> save(AppPreferences preferences);
}
