/// Preferencias de entrega de recordatorios de misiones.
///
/// Se almacenan como metadata para mantener intacto el esquema Drift v1.
final class ReminderPreferences {
  static const Set<int> supportedLeadMinutes = <int>{0, 5, 15, 30, 60};

  static const ReminderPreferences defaults = ReminderPreferences(
    leadMinutes: 15,
    quietHoursEnabled: false,
    quietStartMinutes: 22 * 60,
    quietEndMinutes: 7 * 60,
  );

  const ReminderPreferences({
    required this.leadMinutes,
    required this.quietHoursEnabled,
    required this.quietStartMinutes,
    required this.quietEndMinutes,
  });

  final int leadMinutes;
  final bool quietHoursEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;

  bool get isValid =>
      supportedLeadMinutes.contains(leadMinutes) &&
      quietStartMinutes >= 0 &&
      quietStartMinutes <= 1439 &&
      quietEndMinutes >= 0 &&
      quietEndMinutes <= 1439 &&
      quietStartMinutes != quietEndMinutes;

  int deliveryAtUtcMs(int missionStartUtcMs) =>
      missionStartUtcMs - Duration(minutes: leadMinutes).inMilliseconds;

  bool isQuietAtUtcMs(int utcMs) {
    if (!quietHoursEnabled) {
      return false;
    }
    final DateTime local = DateTime.fromMillisecondsSinceEpoch(
      utcMs,
      isUtc: true,
    ).toLocal();
    final int minute = local.hour * 60 + local.minute;
    if (quietStartMinutes < quietEndMinutes) {
      return minute >= quietStartMinutes && minute < quietEndMinutes;
    }
    return minute >= quietStartMinutes || minute < quietEndMinutes;
  }

  ReminderPreferences copyWith({
    int? leadMinutes,
    bool? quietHoursEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
  }) => ReminderPreferences(
    leadMinutes: leadMinutes ?? this.leadMinutes,
    quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
    quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
  );
}
