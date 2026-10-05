/// Qué es el deseo. Es la categoría fija de `inventory_items` (ADR-006 D4) y
/// decide el icono (D17).
enum WishKind { technology, clothing, accessory, book, part, home, other }

enum WishPriority { low, medium, high }

/// Un deseo de la Tienda (ADR-006 D17). Mientras no se compra,
/// [purchasedAtUtc] y [purchaseTransactionId] son nulos.
final class Wish {
  const Wish({
    required this.id,
    required this.name,
    required this.kind,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.rowVersion,
    this.description,
    this.areaId,
    this.priority,
    this.priceMinor,
    this.archivedAtUtc,
    this.purchasedAtUtc,
    this.purchaseTransactionId,
  });

  static const int maxNameLength = 120;
  static const int maxDescriptionLength = 4000;

  final String id;
  final String name;

  /// Información del deseo, en texto (sin imagen).
  final String? description;

  /// Área de vida a la que pertenece; nula si no tiene o se borró el área.
  final String? areaId;
  final WishKind kind;

  /// Solo los deseos sin comprar tienen prioridad.
  final WishPriority? priority;

  /// Precio orientativo en unidades menores; nulo si no se puso.
  final int? priceMinor;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? archivedAtUtc;
  final DateTime? purchasedAtUtc;
  final String? purchaseTransactionId;
  final int rowVersion;

  bool get isArchived => archivedAtUtc != null;

  bool get isPurchased => purchaseTransactionId != null;
}
