/// Conversión de fechas civiles recurrentes sin acoplar la aplicación a
/// Flutter ni a una biblioteca concreta de zonas horarias.
abstract interface class RecurrenceCivilTime {
  Future<String> currentTimeZoneId();

  Future<String> localDateForUtc({
    required int utcEpochMillis,
    required String timeZoneId,
  });

  Future<int> localDateTimeToUtcEpochMillis({
    required String localDate,
    required int localTimeMinutes,
    required String timeZoneId,
  });
}
