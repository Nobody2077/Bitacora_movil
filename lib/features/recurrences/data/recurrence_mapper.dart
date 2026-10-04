import '../../../features/missions/domain/models/mission.dart';
import '../../../infrastructure/database/app_database.dart' as drift;
import '../../../infrastructure/database/daos/recurrence_dao.dart';
import '../domain/models/recurrence_template.dart';

abstract final class RecurrenceMapper {
  static RecurrenceTemplate fromBundle(MissionTemplateBundle bundle) {
    final drift.MissionTemplate t = bundle.template;
    final drift.RecurrenceRule? r = bundle.rule;
    return RecurrenceTemplate(
      id: t.id,
      areaId: t.areaId,
      title: t.title,
      description: t.description,
      missionType: _missionType(t.missionType),
      importance: _importance(t.importance),
      priority: _priority(t.priority),
      difficulty: _difficulty(t.difficulty),
      isRequired: t.isRequired == 1,
      xpReward: t.xpReward,
      estimatedMinutes: t.estimatedMinutes,
      budgetMinor: t.budgetMinor,
      location: t.location,
      availabilityMode: _availabilityMode(t.availabilityMode),
      isActive: t.isActive == 1,
      objectives: bundle.objectives
          .map(
            (o) => RecurrenceObjective(
              id: o.id,
              description: o.description,
              position: o.position,
            ),
          )
          .toList(growable: false),
      rule: r == null ? null : _rule(r),
    );
  }

  static RecurrenceRule _rule(drift.RecurrenceRule r) => RecurrenceRule(
    id: r.id,
    templateId: r.templateId,
    frequency: _frequency(r.frequency),
    intervalValue: r.intervalValue,
    weekdaysMask: r.weekdaysMask,
    localTimeMinutes: r.localTimeMinutes,
    startDate: r.startDate,
    endDate: r.endDate,
    timezoneId: r.timezoneId,
    lastGeneratedOn: r.lastGeneratedOn,
  );

  static RecurrenceFrequency _frequency(String value) => switch (value) {
    'DAILY' => RecurrenceFrequency.daily,
    'WEEKLY' => RecurrenceFrequency.weekly,
    'SPECIFIC_DAYS' => RecurrenceFrequency.specificDays,
    'EVERY_N_DAYS' => RecurrenceFrequency.everyNDays,
    _ => throw FormatException('Unknown persisted frequency: $value'),
  };

  static String frequencyToDb(RecurrenceFrequency value) => switch (value) {
    RecurrenceFrequency.daily => 'DAILY',
    RecurrenceFrequency.weekly => 'WEEKLY',
    RecurrenceFrequency.specificDays => 'SPECIFIC_DAYS',
    RecurrenceFrequency.everyNDays => 'EVERY_N_DAYS',
  };

  static TemplateAvailabilityMode _availabilityMode(String value) =>
      switch (value) {
        'AUTOMATIC' => TemplateAvailabilityMode.automatic,
        'BOARD' => TemplateAvailabilityMode.board,
        _ => throw FormatException(
          'Unknown persisted availability mode: $value',
        ),
      };

  static String availabilityModeToDb(TemplateAvailabilityMode value) =>
      switch (value) {
        TemplateAvailabilityMode.automatic => 'AUTOMATIC',
        TemplateAvailabilityMode.board => 'BOARD',
      };

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

  static String missionTypeToDb(MissionType value) => switch (value) {
    MissionType.primary => 'PRIMARY',
    MissionType.secondary => 'SECONDARY',
    MissionType.errand => 'ERRAND',
    MissionType.daily => 'DAILY',
    MissionType.recurring => 'RECURRING',
    MissionType.event => 'EVENT',
    MissionType.challenge => 'CHALLENGE',
    MissionType.custom => 'CUSTOM',
  };

  static MissionImportance _importance(String value) => switch (value) {
    'MINOR' => MissionImportance.minor,
    'NORMAL' => MissionImportance.normal,
    'IMPORTANT' => MissionImportance.important,
    'VERY_IMPORTANT' => MissionImportance.veryImportant,
    'CRITICAL' => MissionImportance.critical,
    _ => throw FormatException('Unknown persisted importance: $value'),
  };

  static String importanceToDb(MissionImportance value) => switch (value) {
    MissionImportance.minor => 'MINOR',
    MissionImportance.normal => 'NORMAL',
    MissionImportance.important => 'IMPORTANT',
    MissionImportance.veryImportant => 'VERY_IMPORTANT',
    MissionImportance.critical => 'CRITICAL',
  };

  static MissionPriority _priority(String value) => switch (value) {
    'LOW' => MissionPriority.low,
    'NORMAL' => MissionPriority.normal,
    'HIGH' => MissionPriority.high,
    'URGENT' => MissionPriority.urgent,
    _ => throw FormatException('Unknown persisted priority: $value'),
  };

  static String priorityToDb(MissionPriority value) => switch (value) {
    MissionPriority.low => 'LOW',
    MissionPriority.normal => 'NORMAL',
    MissionPriority.high => 'HIGH',
    MissionPriority.urgent => 'URGENT',
  };

  static MissionDifficulty? _difficulty(String? value) => switch (value) {
    null => null,
    'EASY' => MissionDifficulty.easy,
    'MEDIUM' => MissionDifficulty.medium,
    'HARD' => MissionDifficulty.hard,
    _ => throw FormatException('Unknown persisted difficulty: $value'),
  };

  static String? difficultyToDb(MissionDifficulty? value) => switch (value) {
    null => null,
    MissionDifficulty.easy => 'EASY',
    MissionDifficulty.medium => 'MEDIUM',
    MissionDifficulty.hard => 'HARD',
  };
}
