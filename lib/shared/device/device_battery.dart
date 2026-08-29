import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class DeviceBatterySource {
  Stream<int?> watchLevel();
}

final class MethodChannelDeviceBatterySource implements DeviceBatterySource {
  const MethodChannelDeviceBatterySource({
    EventChannel channel = const EventChannel(_channelName),
  }) : _channel = channel;

  static const String _channelName = 'com.jcyq.bitacorarpg/device_battery';

  final EventChannel _channel;

  @override
  Stream<int?> watchLevel() async* {
    try {
      await for (final Object? event in _channel.receiveBroadcastStream()) {
        final int? level = switch (event) {
          final int value => value,
          final num value => value.round(),
          _ => null,
        };
        yield level?.clamp(0, 100).toInt();
      }
    } on MissingPluginException {
      yield null;
    } on PlatformException {
      yield null;
    }
  }
}

final Provider<DeviceBatterySource> deviceBatterySourceProvider =
    Provider<DeviceBatterySource>(
      (Ref ref) => const MethodChannelDeviceBatterySource(),
    );

final StreamProvider<int?> deviceBatteryLevelProvider = StreamProvider<int?>((
  Ref ref,
) {
  return ref.watch(deviceBatterySourceProvider).watchLevel();
});
