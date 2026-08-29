enum AppAccentColor {
  yellow('#F5D547', 'Amarillo'),
  red('#FF3B3B', 'Rojo'),
  gray('#B6C0CD', 'Gris');

  const AppAccentColor(this.hex, this.label);

  final String hex;
  final String label;

  static AppAccentColor fromHex(String value) => values.firstWhere(
    (AppAccentColor color) => color.hex.toUpperCase() == value.toUpperCase(),
    orElse: () => AppAccentColor.red,
  );
}

/// Preferencias persistidas del usuario. No representa permisos del sistema.
final class AppPreferences {
  static const Set<int> supportedAutoLockMinutes = <int>{0, 1, 5, 15};
  static final Set<String> supportedPrimaryColorHex = AppAccentColor.values
      .map((AppAccentColor color) => color.hex)
      .toSet();

  static final AppPreferences defaults = AppPreferences(
    themeKey: 'terminal_reinforced',
    primaryColorHex: '#FF3B3B',
    largeText: false,
    reduceMotion: false,
    highContrast: false,
    hideAmounts: false,
    missionNotifications: true,
    dailySummary: true,
    soundEnabled: true,
    autoLockMinutes: 5,
    updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  const AppPreferences({
    required this.themeKey,
    required this.primaryColorHex,
    required this.largeText,
    required this.reduceMotion,
    required this.highContrast,
    required this.hideAmounts,
    required this.missionNotifications,
    required this.dailySummary,
    required this.soundEnabled,
    required this.autoLockMinutes,
    required this.updatedAtUtc,
  });

  final String themeKey;
  final String primaryColorHex;
  final bool largeText;
  final bool reduceMotion;
  final bool highContrast;
  final bool hideAmounts;
  final bool missionNotifications;
  final bool dailySummary;
  final bool soundEnabled;
  final int autoLockMinutes;
  final DateTime updatedAtUtc;

  AppPreferences copyWith({
    String? themeKey,
    String? primaryColorHex,
    bool? largeText,
    bool? reduceMotion,
    bool? highContrast,
    bool? hideAmounts,
    bool? missionNotifications,
    bool? dailySummary,
    bool? soundEnabled,
    int? autoLockMinutes,
    DateTime? updatedAtUtc,
  }) => AppPreferences(
    themeKey: themeKey ?? this.themeKey,
    primaryColorHex: primaryColorHex ?? this.primaryColorHex,
    largeText: largeText ?? this.largeText,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    highContrast: highContrast ?? this.highContrast,
    hideAmounts: hideAmounts ?? this.hideAmounts,
    missionNotifications: missionNotifications ?? this.missionNotifications,
    dailySummary: dailySummary ?? this.dailySummary,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
}
