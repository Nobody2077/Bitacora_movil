import 'dart:math' as math;

/// Representación del nivel RPG calculado dinámicamente según la fórmula cuadrática:
/// `level = floor(sqrt(effectiveXp / 100)) + 1`
final class RpgLevel {
  const RpgLevel({
    required this.effectiveXp,
    required this.level,
    required this.currentThreshold,
    required this.nextThreshold,
    required this.currentLevelXp,
    required this.xpToNextLevel,
    required this.progressRatio,
  });

  factory RpgLevel.fromTotalXp(int totalXp) {
    final int effectiveXp = totalXp < 0 ? 0 : totalXp;
    final int level = (math.sqrt(effectiveXp / 100.0)).floor() + 1;
    final int currentThreshold = 100 * (level - 1) * (level - 1);
    final int nextThreshold = 100 * level * level;
    final int levelSpan = nextThreshold - currentThreshold;
    final int currentLevelXp = effectiveXp - currentThreshold;
    final int xpToNextLevel = nextThreshold - effectiveXp;
    final double progressRatio = levelSpan <= 0
        ? 0.0
        : (currentLevelXp / levelSpan).clamp(0.0, 1.0);

    return RpgLevel(
      effectiveXp: effectiveXp,
      level: level,
      currentThreshold: currentThreshold,
      nextThreshold: nextThreshold,
      currentLevelXp: currentLevelXp,
      xpToNextLevel: xpToNextLevel,
      progressRatio: progressRatio,
    );
  }

  final int effectiveXp;
  final int level;
  final int currentThreshold;
  final int nextThreshold;
  final int currentLevelXp;
  final int xpToNextLevel;
  final double progressRatio;

  int get levelSpan => nextThreshold - currentThreshold;
  int get progressPercentage => (progressRatio * 100).round();
}
