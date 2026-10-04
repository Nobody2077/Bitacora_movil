/// Persona real del Diario (ADR-006 D3). Todo es opcional: un personaje puede
/// ser solo una foto.
final class Contact {
  const Contact({
    required this.id,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.rowVersion,
    this.displayName,
    this.role,
    this.description,
    this.archivedAtUtc,
  });

  static const int maxDisplayNameLength = 80;
  static const int maxRoleLength = 80;
  static const int maxDescriptionLength = 4000;

  final String id;
  final String? displayName;

  /// Subtítulo de la ficha («Docente · Cálculo II»).
  final String? role;
  final String? description;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? archivedAtUtc;
  final int rowVersion;

  bool get isArchived => archivedAtUtc != null;
}
