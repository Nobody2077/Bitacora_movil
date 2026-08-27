import '../../../missions/domain/models/mission.dart';

/// Frecuencia de repetición de una plantilla recurrente.
enum RecurrenceFrequency { daily, weekly, specificDays, everyNDays }

/// Objetivo por defecto de la plantilla, copiado a cada ocurrencia generada.
final class RecurrenceObjective {
  const RecurrenceObjective({
    required this.id,
    required this.description,
    required this.position,
  });

  final String id;
  final String description;
  final int position;
}

/// Regla de recurrencia que determina cuándo se generan ocurrencias.
final class RecurrenceRule {
  const RecurrenceRule({
    required this.id,
    required this.templateId,
    required this.frequency,
    required this.intervalValue,
    required this.startDate,
    required this.timezoneId,
    this.weekdaysMask,
    this.localTimeMinutes,
    this.endDate,
    this.lastGeneratedOn,
  });

  final String id;
  final String templateId;
  final RecurrenceFrequency frequency;

  /// Intervalo entre ocurrencias (p. ej. cada 2 días → intervalValue = 2).
  final int intervalValue;

  /// Máscara de bits de días de la semana (bit 0=lunes … bit 6=domingo) para
  /// [RecurrenceFrequency.specificDays]. Siempre nulo para otras frecuencias.
  final int? weekdaysMask;

  /// Hora local en minutos desde medianoche (0–1439). Nulo → sin hora fija.
  final int? localTimeMinutes;

  /// Fecha de inicio en formato `YYYY-MM-DD` (hora local del usuario).
  final String startDate;

  /// Fecha de fin en formato `YYYY-MM-DD`. Nulo → sin fecha de fin.
  final String? endDate;

  /// Identificador IANA de zona horaria (p. ej. `America/Bogota`).
  final String timezoneId;

  /// Última fecha local procesada para esta regla (`YYYY-MM-DD`). Nulo si
  /// no se ha generado ninguna ocurrencia aún.
  final String? lastGeneratedOn;

  RecurrenceRule copyWith({
    RecurrenceFrequency? frequency,
    int? intervalValue,
    int? weekdaysMask,
    int? localTimeMinutes,
    String? startDate,
    String? endDate,
    String? timezoneId,
    String? lastGeneratedOn,
  }) => RecurrenceRule(
    id: id,
    templateId: templateId,
    frequency: frequency ?? this.frequency,
    intervalValue: intervalValue ?? this.intervalValue,
    weekdaysMask: weekdaysMask,
    localTimeMinutes: localTimeMinutes,
    startDate: startDate ?? this.startDate,
    endDate: endDate,
    timezoneId: timezoneId ?? this.timezoneId,
    lastGeneratedOn: lastGeneratedOn ?? this.lastGeneratedOn,
  );
}

/// Plantilla de misión recurrente.
final class RecurrenceTemplate {
  const RecurrenceTemplate({
    required this.id,
    required this.areaId,
    required this.title,
    required this.missionType,
    required this.importance,
    required this.priority,
    required this.isRequired,
    required this.xpReward,
    required this.isActive,
    required this.objectives,
    this.description,
    this.difficulty,
    this.estimatedMinutes,
    this.budgetMinor,
    this.rule,
  });

  final String id;
  final String areaId;
  final String title;
  final String? description;
  final MissionType missionType;
  final MissionImportance importance;
  final MissionPriority priority;
  final MissionDifficulty? difficulty;
  final bool isRequired;
  final int xpReward;
  final int? estimatedMinutes;
  final int? budgetMinor;

  /// `true` mientras la plantilla genera nuevas ocurrencias.
  final bool isActive;

  final List<RecurrenceObjective> objectives;

  /// Regla de recurrencia. Nulo sólo en caso excepcional.
  final RecurrenceRule? rule;

  RecurrenceTemplate copyWith({
    String? areaId,
    String? title,
    String? description,
    MissionType? missionType,
    MissionImportance? importance,
    MissionPriority? priority,
    MissionDifficulty? difficulty,
    bool? isRequired,
    int? xpReward,
    int? estimatedMinutes,
    int? budgetMinor,
    bool? isActive,
    List<RecurrenceObjective>? objectives,
    RecurrenceRule? rule,
  }) => RecurrenceTemplate(
    id: id,
    areaId: areaId ?? this.areaId,
    title: title ?? this.title,
    description: description,
    missionType: missionType ?? this.missionType,
    importance: importance ?? this.importance,
    priority: priority ?? this.priority,
    difficulty: difficulty,
    isRequired: isRequired ?? this.isRequired,
    xpReward: xpReward ?? this.xpReward,
    estimatedMinutes: estimatedMinutes,
    budgetMinor: budgetMinor,
    isActive: isActive ?? this.isActive,
    objectives: objectives ?? this.objectives,
    rule: rule ?? this.rule,
  );
}
