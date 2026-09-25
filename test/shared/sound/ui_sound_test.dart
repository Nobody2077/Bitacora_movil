import 'dart:io';

import 'package:bitacora_rpg_personal/features/missions/application/mission_completion_sound.dart';
import 'package:bitacora_rpg_personal/shared/sound/ui_sound.dart';
import 'package:bitacora_rpg_personal/shared/sound/ui_sound_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileUiSoundPreferenceStore', () {
    test('sin espejo, ambos grupos quedan desactivados', () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'bitacora-sound-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final FileUiSoundPreferenceStore store = FileUiSoundPreferenceStore(
        directoryLocator: () async => directory,
      );

      expect(await store.read(), UiSoundPreferences.defaults);
      expect(UiSoundPreferences.defaults.rewardEnabled, isFalse);
      expect(UiSoundPreferences.defaults.interfaceEnabled, isFalse);
    });

    test('persiste cada interruptor por separado', () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'bitacora-sound-roundtrip-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final FileUiSoundPreferenceStore store = FileUiSoundPreferenceStore(
        directoryLocator: () async => directory,
      );
      const UiSoundPreferences next = UiSoundPreferences(
        rewardEnabled: true,
        interfaceEnabled: false,
      );

      await store.write(next);

      expect(await store.read(), next);
      final File mirror = File(
        '${directory.path}${Platform.pathSeparator}'
        '${FileUiSoundPreferenceStore.fileName}',
      );
      expect(await mirror.readAsString(), 'reward=1\ninterface=0\n');
    });

    test('un contenido desconocido falla de forma segura a silencio', () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'bitacora-sound-invalid-',
      );
      addTearDown(() => directory.delete(recursive: true));
      await File(
        '${directory.path}${Platform.pathSeparator}'
        '${FileUiSoundPreferenceStore.fileName}',
      ).writeAsString('reward=si\nbasura');
      final FileUiSoundPreferenceStore store = FileUiSoundPreferenceStore(
        directoryLocator: () async => directory,
      );

      expect(await store.read(), UiSoundPreferences.defaults);
    });
  });

  group('UiSoundService', () {
    test('solo reproduce los grupos activados', () async {
      final _RecordingPlayer player = _RecordingPlayer();
      final UiSoundService service = UiSoundService(
        readPreferences: () async => const UiSoundPreferences(
          rewardEnabled: true,
          interfaceEnabled: false,
        ),
        player: player,
      );

      await service.play(UiSound.navigation);
      await service.play(UiSound.missionCompleted);

      expect(player.played, <UiSound>[UiSound.missionCompleted]);
    });

    test('con los valores por defecto no suena nada', () async {
      final _RecordingPlayer player = _RecordingPlayer();
      final UiSoundService service = UiSoundService(
        readPreferences: () async => UiSoundPreferences.defaults,
        player: player,
      );

      for (final UiSound sound in UiSound.values) {
        await service.play(sound);
      }

      expect(player.played, isEmpty);
    });

    test('un fallo del reproductor o de las preferencias no se propaga', () {
      final UiSoundService brokenPlayer = UiSoundService(
        readPreferences: () async => const UiSoundPreferences(
          rewardEnabled: true,
          interfaceEnabled: true,
        ),
        player: _ThrowingPlayer(),
      );
      final UiSoundService brokenPreferences = UiSoundService(
        readPreferences: () async => throw StateError('sin espejo'),
        player: _RecordingPlayer(),
      );

      expect(brokenPlayer.play(UiSound.levelUp), completes);
      expect(brokenPreferences.play(UiSound.levelUp), completes);
    });
  });

  group('missionCompletionSound', () {
    test('suena subida de nivel al cruzar un umbral', () {
      // Nivel 2 empieza en 100 XP: 90 + 20 = 110 lo cruza.
      expect(
        missionCompletionSound(totalXpAfter: 110, xpAwarded: 20),
        UiSound.levelUp,
      );
    });

    test('suena misión completada si no cambia el nivel', () {
      expect(
        missionCompletionSound(totalXpAfter: 150, xpAwarded: 20),
        UiSound.missionCompleted,
      );
    });

    test('sin XP otorgado o sin total conocido, misión completada', () {
      expect(
        missionCompletionSound(totalXpAfter: 100, xpAwarded: 0),
        UiSound.missionCompleted,
      );
      expect(
        missionCompletionSound(totalXpAfter: null, xpAwarded: 50),
        UiSound.missionCompleted,
      );
    });

    test('no consulta el XP si los sonidos de logros están apagados', () async {
      final _RecordingPlayer player = _RecordingPlayer();
      bool loaded = false;

      await playMissionCompletionSound(
        sounds: UiSoundService(
          readPreferences: () async => UiSoundPreferences.defaults,
          player: player,
        ),
        loadTotalXp: () async {
          loaded = true;
          return 110;
        },
        xpAwarded: 20,
      );

      expect(loaded, isFalse);
      expect(player.played, isEmpty);
    });

    test('reproduce un único efecto al subir de nivel', () async {
      final _RecordingPlayer player = _RecordingPlayer();

      await playMissionCompletionSound(
        sounds: UiSoundService(
          readPreferences: () async => const UiSoundPreferences(
            rewardEnabled: true,
            interfaceEnabled: false,
          ),
          player: player,
        ),
        loadTotalXp: () async => 110,
        xpAwarded: 20,
      );

      expect(player.played, <UiSound>[UiSound.levelUp]);
    });
  });
}

final class _RecordingPlayer implements UiSoundPlayer {
  final List<UiSound> played = <UiSound>[];

  @override
  Future<void> play(UiSound sound) async => played.add(sound);
}

final class _ThrowingPlayer implements UiSoundPlayer {
  @override
  Future<void> play(UiSound sound) async => throw StateError('sin audio');
}
