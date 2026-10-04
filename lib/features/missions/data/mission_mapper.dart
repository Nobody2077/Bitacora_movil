import '../../../infrastructure/database/app_database.dart' as drift;
import '../domain/models/mission.dart';

abstract final class MissionMapper {
  static Mission fromDrift(
    drift.Mission value, {
    Iterable<drift.MissionObjective> objectives =
        const <drift.MissionObjective>[],
    Iterable<drift.TimeEntry> timeEntries = const <drift.TimeEntry>[],
  }) => Mission(
    id: value.id,
    templateId: value.templateId,
    areaId: value.areaId,
    title: value.title,
    description: value.description,
    location: value.location,
    type: _missionType(value.missionType),
    importance: _importance(value.importance),
    priority: _priority(value.priority),
    difficulty: _difficulty(value.difficulty),
    isRequired: value.isRequired == 1,
    status: _status(value.status),
    scheduledAtUtc: _utc(value.scheduledAt),
    availableFromUtc: _utc(value.availableFrom),
    expiresAtUtc: _utc(value.expiresAt),
    estimatedMinutes: value.estimatedMinutes,
    budgetMinor: value.budgetMinor,
    xpPlanned: value.xpPlanned,
    actualResult: value.actualResult,
    convenienceRating: _convenience(value.convenienceRating),
    completedAtUtc: _utc(value.completedAt),
    archivedAtUtc: _utc(value.archivedAt),
    rowVersion: value.rowVersion,
    objectives: objectives.map(_objective).toList(growable: false),
    timeEntries: timeEntries.map(_timeEntry).toList(growable: false),
  );

  static MissionObjective _objective(drift.MissionObjective value) =>
      MissionObjective(
        id: value.id,
        description: value.description,
        position: value.position,
        createdAtUtc: _requiredUtc(value.createdAt),
        completedAtUtc: _utc(value.completedAt),
      );

  static MissionTimeEntry _timeEntry(drift.TimeEntry value) => MissionTimeEntry(
    id: value.id,
    source: switch (value.source) {
      'TIMER' => MissionTimeSource.timer,
      'MANUAL' => MissionTimeSource.manual,
      _ => throw FormatException(
        'Unknown persisted time source: ${value.source}',
      ),
    },
    segmentType: switch (value.segmentType) {
      'WORK' => MissionTimeSegmentType.work,
      'BREAK' => MissionTimeSegmentType.breakTime,
      _ => throw FormatException(
        'Unknown persisted segment type: ${value.segmentType}',
      ),
    },
    startedAtUtc: _utc(value.startedAt),
    endedAtUtc: _utc(value.endedAt),
    durationSeconds: value.durationSeconds,
    note: value.note,
    createdAtUtc: _requiredUtc(value.createdAt),
  );

  static DateTime _requiredUtc(int milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);

  static DateTime? _utc(int? milliseconds) => milliseconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);

  static MissionType _missionType(String value) => switch (value) {
    'PRIMARY' => MissionType.primary,
    'SECONDARY' => MissionType.secondary,
    'ERRAND' => MissionType.errand,
    'DAILY' => MissionType.daily,
    'RECURRING' => MissionType.recurring,
    'EVENT' => MissionType.event,
    'CHALLENGE' => MissionType.challenge,
    'CUSTOM' => MissionType.custom,
    _ => throw FormatException('Unknown persisted mission type: $value'),
  };

  static MissionImportance _importance(String value) => switch (value) {
    'MINOR' => MissionImportance.minor,
    'NORMAL' => MissionImportance.normal,
    'IMPORTANT' => MissionImportance.important,
    'VERY_IMPORTANT' => MissionImportance.veryImportant,
    'CRITICAL' => MissionImportance.critical,
    _ => throw FormatException('Unknown persisted mission importance: $value'),
  };

  static MissionPriority _priority(String value) => switch (value) {
    'LOW' => MissionPriority.low,
    'NORMAL' => MissionPriority.normal,
    'HIGH' => MissionPriority.high,
    'URGENT' => MissionPriority.urgent,
    _ => throw FormatException('Unknown persisted mission priority: $value'),
  };

  static MissionDifficulty? _difficulty(String? value) => switch (value) {
    null => null,
    'EASY' => MissionDifficulty.easy,
    'MEDIUM' => MissionDifficulty.medium,
    'HARD' => MissionDifficulty.hard,
    _ => throw FormatException('Unknown persisted mission difficulty: $value'),
  };

  static MissionStatus _status(String value) => switch (value) {
    'DRAFT' => MissionStatus.draft,
    'SCHEDULED' => MissionStatus.scheduled,
    'AVAILABLE' => MissionStatus.available,
    'ACTIVE' => MissionStatus.active,
    'PAUSED' => MissionStatus.paused,
    'RESCHEDULED' => MissionStatus.rescheduled,
    'EXPIRED' => MissionStatus.expired,
    'ABANDONED' => MissionStatus.abandoned,
    'CANCELLED' => MissionStatus.cancelled,
    'PARTIAL' => MissionStatus.partial,
    'COMPLETED' => MissionStatus.completed,
    _ => throw FormatException('Unknown persisted mission status: $value'),
  };

  static ConvenienceRating? _convenience(String? value) => switch (value) {
    null => null,
    'TOTALLY_WORTH_IT' => ConvenienceRating.totallyWorthIt,
    'WORTH_IT_BUT_COSTLY' => ConvenienceRating.worthItButCostly,
    'PARTIALLY_WORTH_IT' => ConvenienceRating.partiallyWorthIt,
    'BARELY_WORTH_IT' => ConvenienceRating.barelyWorthIt,
    'WOULD_NOT_REPEAT' => ConvenienceRating.wouldNotRepeat,
    _ => throw FormatException('Unknown persisted convenience rating: $value'),
  };
}
