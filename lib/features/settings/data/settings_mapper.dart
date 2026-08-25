import 'package:drift/drift.dart';

import '../../../infrastructure/database/app_database.dart' as drift;
import '../domain/models/app_preferences.dart';

abstract final class SettingsMapper {
  static AppPreferences fromDrift(drift.AppSetting value) => AppPreferences(
    themeKey: value.themeKey,
    primaryColorHex: value.primaryColor,
    largeText: value.largeText == 1,
    reduceMotion: value.reduceMotion == 1,
    highContrast: value.highContrast == 1,
    hideAmounts: value.hideAmounts == 1,
    missionNotifications: value.missionNotifications == 1,
    dailySummary: value.dailySummary == 1,
    soundEnabled: value.soundEnabled == 1,
    autoLockMinutes: value.autoLockMinutes,
    updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
      value.updatedAt,
      isUtc: true,
    ),
  );

  static drift.AppSettingsCompanion toDrift(AppPreferences value) =>
      drift.AppSettingsCompanion(
        themeKey: Value<String>(value.themeKey),
        primaryColor: Value<String>(value.primaryColorHex),
        largeText: Value<int>(_flag(value.largeText)),
        reduceMotion: Value<int>(_flag(value.reduceMotion)),
        highContrast: Value<int>(_flag(value.highContrast)),
        hideAmounts: Value<int>(_flag(value.hideAmounts)),
        missionNotifications: Value<int>(_flag(value.missionNotifications)),
        dailySummary: Value<int>(_flag(value.dailySummary)),
        soundEnabled: Value<int>(_flag(value.soundEnabled)),
        autoLockMinutes: Value<int>(value.autoLockMinutes),
        updatedAt: Value<int>(value.updatedAtUtc.millisecondsSinceEpoch),
      );

  static int _flag(bool value) => value ? 1 : 0;
}
