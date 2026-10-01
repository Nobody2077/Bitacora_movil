import 'dart:async';

import 'package:flutter/services.dart';

/// Portapapeles para el código de recuperación.
///
/// Copiar marca el contenido como sensible y programa su borrado; el borrado
/// solo ocurre si el portapapeles aún contiene ese mismo código. Pegar lee
/// texto plano con la API estándar de Flutter.
abstract interface class SensitiveClipboard {
  Future<void> copy(String text);

  Future<String?> readText();
}

final class MethodChannelSensitiveClipboard implements SensitiveClipboard {
  MethodChannelSensitiveClipboard({
    MethodChannel channel = const MethodChannel(_channelName),
    this.clearAfter = defaultClearAfter,
  }) : _channel = channel;

  static const String _channelName = 'com.jcyq.bitacorarpg/sensitive_clipboard';
  static const Duration defaultClearAfter = Duration(seconds: 60);

  final MethodChannel _channel;
  final Duration clearAfter;
  Timer? _clearTimer;

  @override
  Future<void> copy(String text) async {
    await _channel.invokeMethod<void>('copySensitive', <String, Object?>{
      'text': text,
    });
    _clearTimer?.cancel();
    _clearTimer = Timer(clearAfter, () {
      _clearTimer = null;
      unawaited(_clearIfMatches(text));
    });
  }

  Future<void> _clearIfMatches(String text) async {
    try {
      await _channel.invokeMethod<bool>('clearIfMatches', <String, Object?>{
        'text': text,
      });
    } on Object {
      // Si Android no deja leer el portapapeles en segundo plano, el código
      // permanece hasta que el usuario copie otra cosa. No es un error.
    }
  }

  @override
  Future<String?> readText() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }
}
