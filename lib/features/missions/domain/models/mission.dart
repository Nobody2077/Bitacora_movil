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

enum MissionTimeSource { timer, manual }

enum MissionTimeSegmentType { work, breakTime }

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

/// Segmento de tiempo registrado para una misión.
final class MissionTimeEntry {
  const MissionTimeEntry({
    required this.id,
    required this.source,
    required this.segmentType,
    required this.durationSeconds,
    required this.createdAtUtc,
    this.startedAtUtc,
    this.endedAtUtc,
    this.note,
  });

  final String id;
  final MissionTimeSource source;
  final MissionTimeSegmentType segmentType;
  final DateTime? startedAtUtc;
  final DateTime? endedAtUtc;
  final int durationSeconds;
  final String? note;
  final DateTime createdAtUtc;

  bool get isOpen =>
      source == MissionTimeSource.timer &&
      segmentType == MissionTimeSegmentType.work &&
      endedAtUtc == null;

  int elapsedSecondsAt(DateTime nowUtc) {
    final DateTime? startedAt = startedAtUtc;
    if (!isOpen || startedAt == null) {
      return durationSeconds;
    }
    final int elapsed = nowUtc.difference(startedAt).inSeconds;
    return elapsed < 0 ? 0 : elapsed;
  }
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
    this.location,
    this.difficulty,
    this.scheduledAtUtc,
    this.availableFromUtc,
    this.expiresAtUtc,
    this.estimatedMinutes,
    this.budgetMinor,
    this.actualResult,
    this.convenienceRating,
    this.completedAtUtc,
    this.archivedAtUtc,
    this.objectives = const <MissionObjective>[],
    this.timeEntries = const <MissionTimeEntry>[],
  });

  static const int maxLocationLength = 120;

  final String id;
  final String? templateId;
  final String areaId;
  final String title;
  final String? description;

  /// Ubicación en texto libre (ADR-006 D5); el mapa queda aplazado.
  final String? location;
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
  final DateTime? archivedAtUtc;
  final int rowVersion;
  final List<MissionObjective> objectives;
  final List<MissionTimeEntry> timeEntries;

  /// Una planificación de día completo usa [scheduledAtUtc] como ancla para
  /// conservar orden, calendario e idempotencia, y la ventana completa como
  /// marcador persistente de que el usuario no eligió una hora.
  bool get isDateOnly =>
      scheduledAtUtc != null &&
      availableFromUtc != null &&
      expiresAtUtc != null &&
      scheduledAtUtc == availableFromUtc;

  bool get hasScheduledTime => scheduledAtUtc != null && !isDateOnly;

  bool get isUnscheduled =>
      scheduledAtUtc == null &&
      availableFromUtc == null &&
      expiresAtUtc == null;

  MissionTimeEntry? get openWorkTimer {
    for (final entry in timeEntries.reversed) {
      if (entry.isOpen) {
        return entry;
      }
    }
    return null;
  }

  int elapsedWorkSecondsAt(DateTime nowUtc) => timeEntries
      .where((entry) => entry.segmentType == MissionTimeSegmentType.work)
      .fold<int>(0, (total, entry) => total + entry.elapsedSecondsAt(nowUtc));

  Mission copyWith({
    String? areaId,
    String? title,
    String? description,
    String? location,
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
    List<MissionTimeEntry>? timeEntries,
  }) => Mission(
    id: id,
    templateId: templateId,
    areaId: areaId ?? this.areaId,
    title: title ?? this.title,
    description: description,
    location: location,
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
    archivedAtUtc: archivedAtUtc,
    rowVersion: rowVersion,
    objectives: objectives ?? this.objectives,
    timeEntries: timeEntries ?? this.timeEntries,
  );
}
