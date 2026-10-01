import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'ui_sound_preferences.dart';

enum UiSoundGroup { reward, interface, access }

/// Paleta cerrada de efectos. Cada nombre coincide con un fichero de
/// `android/app/src/main/res/raw` registrado en `UiSoundBridge`.
enum UiSound {
  accessGranted('ACCESS_GRANTED', UiSoundGroup.reward),
  navigation('NAVIGATION', UiSoundGroup.interface),
  missionCreated('MISSION_CREATED', UiSoundGroup.reward),
  missionCompleted('MISSION_COMPLETED', UiSoundGroup.reward),
  levelUp('LEVEL_UP', UiSoundGroup.reward),

  // Acceso: todas las teclas usan el mismo efecto, también borrar, para que
  // el sonido no distinga dígitos (PROPUESTA-SONIDO, criterio 5).
  accessKeypad('ACCESS_KEYPAD', UiSoundGroup.access),
  accessLoading('ACCESS_LOADING', UiSoundGroup.access),
  accessDenied('ACCESS_DENIED', UiSoundGroup.access);

  const UiSound(this.channelName, this.group);

  final String channelName;
  final UiSoundGroup group;
}

abstract interface class UiSoundPlayer {
  Future<void> play(UiSound sound);

  Future<void> stop(UiSound sound);
}

final class MethodChannelUiSoundPlayer implements UiSoundPlayer {
  const MethodChannelUiSoundPlayer({
    MethodChannel channel = const MethodChannel(_channelName),
  }) : _channel = channel;

  static const String _channelName = 'com.jcyq.bitacorarpg/ui_sound';

  final MethodChannel _channel;

  @override
  Future<void> play(UiSound sound) => _channel.invokeMethod<void>(
    'play',
    <String, Object?>{'sound': sound.channelName},
  );

  @override
  Future<void> stop(UiSound sound) => _channel.invokeMethod<void>(
    'stop',
    <String, Object?>{'sound': sound.channelName},
  );
}

/// Decide si un efecto suena y lo reproduce.
///
/// El sonido es siempre refuerzo, nunca la única señal: cualquier fallo se
/// descarta en silencio y la acción que lo disparó no se entera.
final class UiSoundService {
  const UiSoundService({
    required Future<UiSoundPreferences> Function() readPreferences,
    required UiSoundPlayer player,
  }) : _readPreferences = readPreferences,
       _player = player;

  final Future<UiSoundPreferences> Function() _readPreferences;
  final UiSoundPlayer _player;

  Future<bool> isEnabled(UiSound sound) async {
    try {
      final UiSoundPreferences preferences = await _readPreferences();
      return switch (sound.group) {
        UiSoundGroup.reward => preferences.rewardEnabled,
        UiSoundGroup.interface => preferences.interfaceEnabled,
        UiSoundGroup.access => preferences.accessEnabled,
      };
    } on Object {
      return false;
    }
  }

  Future<void> play(UiSound sound) async {
    if (!await isEnabled(sound)) {
      return;
    }
    try {
      await _player.play(sound);
    } on Object {
      // Sin sonido: la acción ya se completó y se ve en pantalla.
    }
  }

  /// Corta un efecto largo, como la carga de la terminal. No consulta las
  /// preferencias: cortar algo que no suena no tiene efecto.
  Future<void> stop(UiSound sound) async {
    try {
      await _player.stop(sound);
    } on Object {
      // Nada que hacer: el efecto termina solo.
    }
  }
}

final Provider<UiSoundPreferenceStore> uiSoundPreferenceStoreProvider =
    Provider<UiSoundPreferenceStore>(
      (Ref ref) => FileUiSoundPreferenceStore(
        directoryLocator: getApplicationSupportDirectory,
      ),
    );

final FutureProvider<UiSoundPreferences> uiSoundPreferencesProvider =
    FutureProvider<UiSoundPreferences>(
      (Ref ref) => ref.watch(uiSoundPreferenceStoreProvider).read(),
    );

final Provider<UiSoundPlayer> uiSoundPlayerProvider = Provider<UiSoundPlayer>(
  (Ref ref) => const MethodChannelUiSoundPlayer(),
);

final Provider<UiSoundService> uiSoundServiceProvider =
    Provider<UiSoundService>(
      (Ref ref) => UiSoundService(
        readPreferences: () => ref.read(uiSoundPreferencesProvider.future),
        player: ref.watch(uiSoundPlayerProvider),
      ),
    );
