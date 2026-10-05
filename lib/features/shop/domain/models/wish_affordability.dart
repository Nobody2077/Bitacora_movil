enum WishAffordabilityLevel {
  /// El saldo disponible alcanza el precio.
  affordable,

  /// Falta poco: el saldo cubre al menos [WishAffordability.closePercent] %.
  close,

  /// Falta mucho.
  far,

  /// El deseo no tiene precio y no se puede comparar.
  unpriced,
}

/// Si un deseo está al alcance del saldo disponible (ADR-006 D17). Se calcula
/// al vuelo; nunca se guarda.
final class WishAffordability {
  const WishAffordability._(this.level, this.missingMinor);

  /// Compara el precio con el saldo disponible (saldo menos lo reservado en
  /// metas). Las metas vinculadas no cuentan.
  factory WishAffordability.evaluate({
    required int? priceMinor,
    required int availableMinor,
  }) {
    if (priceMinor == null || priceMinor <= 0) {
      return const WishAffordability._(WishAffordabilityLevel.unpriced, 0);
    }
    if (availableMinor >= priceMinor) {
      return const WishAffordability._(WishAffordabilityLevel.affordable, 0);
    }
    final int missingMinor = priceMinor - availableMinor;
    final bool close = availableMinor * 100 >= priceMinor * closePercent;
    return WishAffordability._(
      close ? WishAffordabilityLevel.close : WishAffordabilityLevel.far,
      missingMinor,
    );
  }

  /// Umbral del ámbar, aprobado por el usuario el 5 de octubre de 2026.
  static const int closePercent = 75;

  final WishAffordabilityLevel level;

  /// Lo que falta para poder comprarlo; 0 si alcanza o no tiene precio.
  final int missingMinor;

  bool get isAffordable => level == WishAffordabilityLevel.affordable;
}
