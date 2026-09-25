import '../../../shared/sound/ui_sound.dart';
import '../../progress/domain/models/rpg_level.dart';

/// Efecto al completar una misión: el de subida de nivel si el XP otorgado
/// cruzó un umbral, y el de misión completada en otro caso. Uno solo, para
/// que no se pisen.
///
/// `totalXpAfter` es el total ya confirmado, que incluye `xpAwarded`.
UiSound missionCompletionSound({
  required int? totalXpAfter,
  required int xpAwarded,
}) {
  if (totalXpAfter == null || xpAwarded <= 0) {
    return UiSound.missionCompleted;
  }
  final int levelAfter = RpgLevel.fromTotalXp(totalXpAfter).level;
  final int levelBefore = RpgLevel.fromTotalXp(totalXpAfter - xpAwarded).level;
  return levelAfter > levelBefore ? UiSound.levelUp : UiSound.missionCompleted;
}

/// Se llama después del commit de `CompleteMission`, nunca dentro de la
/// transacción. Si el total de XP no se puede leer, suena el efecto de misión
/// completada.
Future<void> playMissionCompletionSound({
  required UiSoundService sounds,
  required Future<int?> Function() loadTotalXp,
  required int xpAwarded,
}) async {
  if (!await sounds.isEnabled(UiSound.missionCompleted)) {
    return;
  }
  int? totalXpAfter;
  if (xpAwarded > 0) {
    try {
      totalXpAfter = await loadTotalXp();
    } on Object {
      totalXpAfter = null;
    }
  }
  await sounds.play(
    missionCompletionSound(totalXpAfter: totalXpAfter, xpAwarded: xpAwarded),
  );
}
