import 'package:flutter/services.dart';

import '../application/recurrence_civil_time.dart';

final class MethodChannelRecurrenceCivilTime implements RecurrenceCivilTime {
  const MethodChannelRecurrenceCivilTime();

  static const MethodChannel _channel = MethodChannel(
    'com.jcyq.bitacorarpg/recurrence_civil_time',
  );

  @override
  Future<String> currentTimeZoneId() async {
    final String? value = await _channel.invokeMethod<String>(
      'currentTimeZoneId',
    );
    if (value == null || value.trim().isEmpty) {
      throw const FormatException('Android no devolvió una zona horaria IANA.');
    }
    return value;
  }

  @override
  Future<String> localDateForUtc({
    required int utcEpochMillis,
    required String timeZoneId,
  }) async {
    final String? value = await _channel.invokeMethod<String>(
      'localDateForUtc',
      <String, Object>{
        'utcEpochMillis': utcEpochMillis,
        'timeZoneId': timeZoneId,
      },
    );
    if (value == null) {
      throw const FormatException('Android no pudo resolver la fecha civil.');
    }
    return value;
  }

  @override
  Future<int> localDateTimeToUtcEpochMillis({
    required String localDate,
    required int localTimeMinutes,
    required String timeZoneId,
  }) async {
    final int? value = await _channel
        .invokeMethod<int>('localDateTimeToUtcEpochMillis', <String, Object>{
          'localDate': localDate,
          'localTimeMinutes': localTimeMinutes,
          'timeZoneId': timeZoneId,
        });
    if (value == null) {
      throw const FormatException('Android no pudo resolver el instante UTC.');
    }
    return value;
  }
}
