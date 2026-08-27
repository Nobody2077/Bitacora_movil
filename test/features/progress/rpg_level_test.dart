import 'package:bitacora_rpg_personal/features/progress/domain/models/rpg_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RpgLevel', () {
    test('calcula nivel 1 para 0 XP o valores negativos', () {
      final RpgLevel zero = RpgLevel.fromTotalXp(0);
      expect(zero.level, 1);
      expect(zero.effectiveXp, 0);
      expect(zero.currentThreshold, 0);
      expect(zero.nextThreshold, 100);
      expect(zero.currentLevelXp, 0);
      expect(zero.xpToNextLevel, 100);
      expect(zero.progressRatio, 0.0);
      expect(zero.progressPercentage, 0);

      final RpgLevel negative = RpgLevel.fromTotalXp(-50);
      expect(negative.level, 1);
      expect(negative.effectiveXp, 0);
    });

    test('calcula nivel 2 para 100 XP', () {
      final RpgLevel lvl2 = RpgLevel.fromTotalXp(100);
      expect(lvl2.level, 2);
      expect(lvl2.effectiveXp, 100);
      expect(lvl2.currentThreshold, 100);
      expect(lvl2.nextThreshold, 400);
      expect(lvl2.currentLevelXp, 0);
      expect(lvl2.xpToNextLevel, 300);
      expect(lvl2.progressRatio, 0.0);
    });

    test('calcula nivel 5 para 2450 XP', () {
      final RpgLevel lvl5 = RpgLevel.fromTotalXp(2450);
      expect(lvl5.level, 5);
      expect(lvl5.currentThreshold, 1600);
      expect(lvl5.nextThreshold, 2500);
      expect(lvl5.currentLevelXp, 850);
      expect(lvl5.xpToNextLevel, 50);
      expect(lvl5.levelSpan, 900);
      expect(lvl5.progressPercentage, 94);
    });

    test(
      'calcula exactamente el caso canónico GoldenScenario (4450 XP = Nivel 7)',
      () {
        final RpgLevel lvl7 = RpgLevel.fromTotalXp(4450);
        expect(lvl7.level, 7);
        expect(lvl7.effectiveXp, 4450);
        expect(lvl7.currentThreshold, 3600);
        expect(lvl7.nextThreshold, 4900);
        expect(lvl7.currentLevelXp, 850);
        expect(lvl7.xpToNextLevel, 450);
        expect(lvl7.levelSpan, 1300);
        expect(lvl7.progressPercentage, 65);
      },
    );
  });
}
