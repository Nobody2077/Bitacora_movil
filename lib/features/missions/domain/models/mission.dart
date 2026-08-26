/// Tipos de misión reconocidos por el dominio v1.
enum MissionType {
  primary,
  secondary,
  errand,
  daily,
  recurring,
  event,
  challenge,
  custom,
}

enum MissionImportance { minor, normal, important, veryImportant, critical }

enum MissionPriority { low, normal, high, urgent }

enum MissionDifficulty { easy, medium, hard }

enum MissionStatus {
  draft,
  scheduled,
  available,
  active,
  paused,
  rescheduled,
  expired,
  abandoned,
  cancelled,
  partial,
  completed,
}

enum ConvenienceRating {
  totallyWorthIt,
  worthItButCostly,
  partiallyWorthIt,
  barelyWorthIt,
  wouldNotRepeat,
}

/// Área de vida disponible para clasificar una misión.
final class MissionArea {
  const MissionArea({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorHex,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String iconKey;
  final String colorHex;
  final bool isDefault;
}

/// Objetivo perteneciente al agregado de una misión.
final class MissionObjective {
  const MissionObjective({
    required this.id,
    required this.description,
    required this.position,
    required this.createdAtUtc,
    this.completedAtUtc,
  });

  final String id;
  final String description;
  final int position;
  final DateTime createdAtUtc;
  final DateTime? completedAtUtc;

  bool get isCompleted => completedAtUtc != null;
}

/// Agregado de misión independiente del formato de persistencia.
final class Mission {
  const Mission({
    required this.id,
    required this.areaId,
    required this.title,
    required this.type,
    required this.importance,
    required this.priority,
    required this.isRequired,
    required this.status,
    required this.xpPlanned,
    required this.rowVersion,
    this.templateId,
    this.description,
    this.difficulty,
    this.scheduledAtUtc,
    this.availableFromUtc,
    this.expiresAtUtc,
    this.estimatedMinutes,
    this.budgetMinor,
    this.actualResult,
    this.convenienceRating,
    this.completedAtUtc,
    this.objectives = const <MissionObjective>[],
  });

  final String id;
  final String? templateId;
  final String areaId;
  final String title;
  final String? description;
  final MissionType type;
  final MissionImportance importance;
  final MissionPriority priority;
  final MissionDifficulty? difficulty;
  final bool isRequired;
  final MissionStatus status;
  final DateTime? scheduledAtUtc;
  final DateTime? availableFromUtc;
  final DateTime? expiresAtUtc;
  final int? estimatedMinutes;
  final int? budgetMinor;
  final int xpPlanned;
  final String? actualResult;
  final ConvenienceRating? convenienceRating;
  final DateTime? completedAtUtc;
  final int rowVersion;
  final List<MissionObjective> objectives;

  Mission copyWith({
    String? areaId,
    String? title,
    String? description,
    MissionType? type,
    MissionImportance? importance,
    MissionPriority? priority,
    MissionDifficulty? difficulty,
    bool? isRequired,
    DateTime? scheduledAtUtc,
    int? estimatedMinutes,
    int? budgetMinor,
    int? xpPlanned,
    List<MissionObjective>? objectives,
  }) => Mission(
    id: id,
    templateId: templateId,
    areaId: areaId ?? this.areaId,
    title: title ?? this.title,
    description: description,
    type: type ?? this.type,
    importance: importance ?? this.importance,
    priority: priority ?? this.priority,
    difficulty: difficulty,
    isRequired: isRequired ?? this.isRequired,
    status: status,
    scheduledAtUtc: scheduledAtUtc ?? this.scheduledAtUtc,
    availableFromUtc: availableFromUtc,
    expiresAtUtc: expiresAtUtc,
    estimatedMinutes: estimatedMinutes,
    budgetMinor: budgetMinor,
    xpPlanned: xpPlanned ?? this.xpPlanned,
    actualResult: actualResult,
    convenienceRating: convenienceRating,
    completedAtUtc: completedAtUtc,
    rowVersion: rowVersion,
    objectives: objectives ?? this.objectives,
  );
}
