/// Preferencias de entrega de recordatorios de misiones.
///
/// Se almacenan como metadata para mantener intacto el esquema Drift v1.
///
/// El resumen diario vive aquí, y no como fila de `notification_schedules`, por
/// decisión tomada al implementar el punto 2 de A11. Esa tabla exige
/// `mission_id NOT NULL` con clave foránea, tiene un `CHECK` cerrado sobre
/// `notification_type` que SQLite no deja alterar sin recrear la tabla entera, y
/// su `UNIQUE` dejaría de proteger las filas del resumen en cuanto `mission_id`
/// admitiera NULL. El resumen no es un recordatorio de una misión: es una alarma
/// diaria fija, y modelarla como fila era forzarla.
final class ReminderPreferences {
  /// Texto de los avisos que no muestran el titulo de la mision.
  static const String defaultGenericText = 'Tienes una misión programada.';

  /// Limite del texto personalizado. El canal lo recorta igual; se valida
  /// aqui para que el usuario vea el limite en vez de perder caracteres.
  static const int genericTextMaxLength = 120;

  static const Set<int> supportedLeadMinutes = <int>{0, 5, 15, 30, 60};

  static const ReminderPreferences defaults = ReminderPreferences(
    leadMinutes: 15,
    quietHoursEnabled: false,
    quietStartMinutes: 22 * 60,
    quietEndMinutes: 7 * 60,
    dailySummaryEnabled: false,
    dailySummaryMinutes: 6 * 60,
    genericText: defaultGenericText,
  );

  const ReminderPreferences({
    required this.leadMinutes,
    required this.quietHoursEnabled,
    required this.quietStartMinutes,
    required this.quietEndMinutes,
    required this.dailySummaryEnabled,
    required this.dailySummaryMinutes,
    required this.genericText,
  });

  final int leadMinutes;
  final bool quietHoursEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;

  /// Si se envía un aviso diario con el recuento de misiones del día.
  final bool dailySummaryEnabled;

  /// Minuto del día local en que se envía el resumen.
  final int dailySummaryMinutes;

  /// Texto que se muestra cuando el aviso no lleva el título de la misión.
  final String genericText;

  bool get isValid =>
      supportedLeadMinutes.contains(leadMinutes) &&
      quietStartMinutes >= 0 &&
      quietStartMinutes <= 1439 &&
      quietEndMinutes >= 0 &&
      quietEndMinutes <= 1439 &&
      quietStartMinutes != quietEndMinutes &&
      dailySummaryMinutes >= 0 &&
      dailySummaryMinutes <= 1439 &&
      genericText.trim().isNotEmpty &&
      genericText.trim().length <= genericTextMaxLength;

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

  /// Próxima ocurrencia del resumen, en tiempo civil local.
  ///
  /// Si la hora de hoy ya pasó, devuelve la de mañana. Se calcula sobre fecha
  /// civil y no sumando 24 horas, para que los cambios de horario de verano no
  /// desplacen el aviso.
  int nextSummaryUtcMs(int nowUtcMs) {
    final DateTime nowLocal = DateTime.fromMillisecondsSinceEpoch(
      nowUtcMs,
      isUtc: true,
    ).toLocal();
    final int hour = dailySummaryMinutes ~/ 60;
    final int minute = dailySummaryMinutes % 60;
    DateTime candidate = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      hour,
      minute,
    );
    if (!candidate.isAfter(nowLocal)) {
      candidate = DateTime(
        nowLocal.year,
        nowLocal.month,
        nowLocal.day + 1,
        hour,
        minute,
      );
    }
    return candidate.toUtc().millisecondsSinceEpoch;
  }

  ReminderPreferences copyWith({
    int? leadMinutes,
    bool? quietHoursEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
    bool? dailySummaryEnabled,
    int? dailySummaryMinutes,
    String? genericText,
  }) => ReminderPreferences(
    leadMinutes: leadMinutes ?? this.leadMinutes,
    quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
    quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
    dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
    dailySummaryMinutes: dailySummaryMinutes ?? this.dailySummaryMinutes,
    genericText: genericText ?? this.genericText,
  );
}
