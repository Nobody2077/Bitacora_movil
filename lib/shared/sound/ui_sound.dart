import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'ui_sound_preferences.dart';

enum UiSoundGroup { reward, interface }

/// Paleta cerrada de efectos. Cada nombre coincide con un fichero de
/// `android/app/src/main/res/raw` registrado en `UiSoundBridge`.
enum UiSound {
  accessGranted('ACCESS_GRANTED', UiSoundGroup.reward),
  navigation('NAVIGATION', UiSoundGroup.interface),
  missionCreated('MISSION_CREATED', UiSoundGroup.reward),
  missionCompleted('MISSION_COMPLETED', UiSoundGroup.reward),
  levelUp('LEVEL_UP', UiSoundGroup.reward);

  const UiSound(this.channelName, this.group);

  final String channelName;
  final UiSoundGroup group;
}

abstract interface class UiSoundPlayer {
  Future<void> play(UiSound sound);
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
