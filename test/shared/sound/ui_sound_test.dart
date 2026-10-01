import 'dart:io';

import 'package:bitacora_rpg_personal/features/access/application/access_session_sounds.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_state.dart';
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
      expect(await mirror.readAsString(), 'reward=1\ninterface=0\naccess=0\n');
    });

    test('un espejo anterior sin la clave de acceso la deja apagada', () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'bitacora-sound-legacy-',
      );
      addTearDown(() => directory.delete(recursive: true));
      await File(
        '${directory.path}${Platform.pathSeparator}'
        '${FileUiSoundPreferenceStore.fileName}',
      ).writeAsString('reward=1\ninterface=1\n');
      final FileUiSoundPreferenceStore store = FileUiSoundPreferenceStore(
        directoryLocator: () async => directory,
      );

      final UiSoundPreferences read = await store.read();

      expect(read.rewardEnabled, isTrue);
      expect(read.interfaceEnabled, isTrue);
      expect(read.accessEnabled, isFalse);

      await store.write(read.copyWith(accessEnabled: true));
      expect((await store.read()).accessEnabled, isTrue);
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
      expect(brokenPlayer.stop(UiSound.accessLoading), completes);
    });

    test('los sonidos de acceso dependen solo de su interruptor', () async {
      final _RecordingPlayer player = _RecordingPlayer();
      final UiSoundService service = UiSoundService(
        readPreferences: () async => const UiSoundPreferences(
          rewardEnabled: true,
          interfaceEnabled: true,
        ),
        player: player,
      );
      await service.play(UiSound.accessKeypad);
      await service.play(UiSound.accessLoading);
      await service.play(UiSound.accessDenied);
      expect(player.played, isEmpty);

      final UiSoundService accessOnly = UiSoundService(
        readPreferences: () async => const UiSoundPreferences(
          rewardEnabled: false,
          interfaceEnabled: false,
          accessEnabled: true,
        ),
        player: player,
      );
      await accessOnly.play(UiSound.accessKeypad);
      await accessOnly.play(UiSound.navigation);
      expect(player.played, <UiSound>[UiSound.accessKeypad]);
    });

    test('cortar un efecto no depende de las preferencias', () async {
      final _RecordingPlayer player = _RecordingPlayer();
      final UiSoundService service = UiSoundService(
        readPreferences: () async => UiSoundPreferences.defaults,
        player: player,
      );

      await service.stop(UiSound.accessLoading);

      expect(player.stopped, <UiSound>[UiSound.accessLoading]);
    });
  });

  group('accessSoundCommands', () {
    const AccessSessionState unlocked = AccessSessionState.unlockedForTesting();
    final AccessSessionState locked = unlocked.copyWith(
      phase: AccessSessionPhase.locked,
      notice: null,
    );
    final AccessSessionState validating = locked.copyWith(
      phase: AccessSessionPhase.authenticating,
      isBusy: true,
    );

    test('validar arranca la carga; abrir la corta y suena el acceso', () {
      expect(
        accessSoundCommands(locked, validating),
        const <AccessSoundCommand>[
          AccessSoundCommand(AccessSoundAction.play, UiSound.accessLoading),
        ],
      );
      expect(
        accessSoundCommands(validating, unlocked),
        const <AccessSoundCommand>[
          AccessSoundCommand(AccessSoundAction.stop, UiSound.accessLoading),
          AccessSoundCommand(AccessSoundAction.play, UiSound.accessGranted),
        ],
      );
    });

    test('un PIN rechazado corta la carga y suena el error', () {
      for (final AccessNotice notice in <AccessNotice>[
        AccessNotice.invalidCredential,
        AccessNotice.progressiveWait,
      ]) {
        expect(
          accessSoundCommands(validating, locked.copyWith(notice: notice)),
          const <AccessSoundCommand>[
            AccessSoundCommand(AccessSoundAction.stop, UiSound.accessLoading),
            AccessSoundCommand(AccessSoundAction.play, UiSound.accessDenied),
          ],
        );
      }
    });

    test('volver a bloqueado sin rechazo solo corta la carga', () {
      expect(
        accessSoundCommands(validating, locked),
        const <AccessSoundCommand>[
          AccessSoundCommand(AccessSoundAction.stop, UiSound.accessLoading),
        ],
      );
    });

    test('sin cambio de fase no suena nada', () {
      expect(accessSoundCommands(locked, locked), isEmpty);
      expect(accessSoundCommands(unlocked, unlocked), isEmpty);
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
  final List<UiSound> stopped = <UiSound>[];

  @override
  Future<void> play(UiSound sound) async => played.add(sound);

  @override
  Future<void> stop(UiSound sound) async => stopped.add(sound);
}

final class _ThrowingPlayer implements UiSoundPlayer {
  @override
  Future<void> play(UiSound sound) async => throw StateError('sin audio');

  @override
  Future<void> stop(UiSound sound) async => throw StateError('sin audio');
}
