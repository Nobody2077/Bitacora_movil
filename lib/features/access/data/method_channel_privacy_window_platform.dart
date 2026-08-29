import 'package:flutter/services.dart';

import '../domain/privacy_window_platform.dart';

final class MethodChannelPrivacyWindowPlatform
    implements PrivacyWindowPlatform {
  const MethodChannelPrivacyWindowPlatform();

  static const MethodChannel _channel = MethodChannel(
    'com.jcyq.bitacorarpg/privacy_window',
  );

  @override
  Future<void> setScreenshotProtectionEnabled(bool enabled) =>
      _channel.invokeMethod<void>('setFlagSecureEnabled', <String, bool>{
        'enabled': enabled,
      });
}
