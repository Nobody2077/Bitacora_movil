import '../../../../core/result/result.dart';
import '../models/app_preferences.dart';

abstract interface class SettingsRepository {
  Future<Result<AppPreferences>> load();

  Stream<Result<AppPreferences>> watch();

  Future<Result<void>> save(AppPreferences preferences);
}
