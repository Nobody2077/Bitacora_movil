import 'package:drift/drift.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../features/missions/application/mission_application_service.dart';
import '../../../features/missions/domain/models/mission.dart';
import '../../../infrastructure/database/app_database.dart' as drift;
import '../../../infrastructure/database/daos/recurrence_dao.dart';
import '../domain/models/recurrence_template.dart';
import '../domain/repositories/recurrence_repository.dart';
import 'recurrence_civil_time.dart';

// ── DTOs ────────────────────────────────────────────────────────────────────

/// Objetivo incluido en la solicitud de guardar una plantilla.
final class RecurrenceObjectiveDraft {
  const RecurrenceObjectiveDraft({required this.description, this.id});

  final String? id;
  final String description;
}

/// Datos necesarios para crear o editar una plantilla recurrente.
final class SaveTemplateRequest {
  const SaveTemplateRequest({
    required this.areaId,
    required this.title,
    required this.missionType,
    required this.importance,
    required this.priority,
    required this.isRequired,
    required this.xpReward,
    required this.frequency,
    required this.intervalValue,
    required this.startDate,
    required this.timezoneId,
    required this.objectives,
    this.existing,
    this.description,
    this.difficulty,
    this.estimatedMinutes,
    this.budgetMinor,
    this.weekdaysMask,
    this.localTimeMinutes,
    this.endDate,
  });

  final RecurrenceTemplate? existing;
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
  final RecurrenceFrequency frequency;
  final int intervalValue;
  final int? weekdaysMask;
  final int? localTimeMinutes;
  final String startDate;
  final String? endDate;
  final String timezoneId;
  final List<RecurrenceObjectiveDraft> objectives;
}

// ── Servicio de aplicación ──────────────────────────────────────────────────

final class RecurrenceApplicationService {
  const RecurrenceApplicationService({
    required RecurrenceRepository repository,
    required RecurrenceDao dao,
    required MissionClock clock,
    required MissionIdGenerator idGenerator,
    required RecurrenceCivilTime civilTime,
  }) : _repository = repository,
       _dao = dao,
       _clock = clock,
       _idGenerator = idGenerator,
       _civilTime = civilTime;

  final RecurrenceRepository _repository;
  final RecurrenceDao _dao;
  final MissionClock _clock;
  final MissionIdGenerator _idGenerator;
  final RecurrenceCivilTime _civilTime;

  // ── Caso de uso 1: Guardar plantilla ────────────────────────────────────

  Future<Result<RecurrenceTemplate>> saveTemplate(
    SaveTemplateRequest request,
  ) async {
    if (request.title.trim().isEmpty) {
      return const Failure<RecurrenceTemplate>(
        ValidationFailure('El título de la plantilla es obligatorio.'),
      );
    }
    if (request.intervalValue < 1) {
      return const Failure<RecurrenceTemplate>(
        ValidationFailure('El intervalo de recurrencia debe ser al menos 1.'),
      );
    }
    if (request.areaId.trim().isEmpty || request.timezoneId.trim().isEmpty) {
      return const Failure<RecurrenceTemplate>(
        ValidationFailure('El área y la zona horaria son obligatorias.'),
      );
    }
    if (request.xpReward < 0 ||
        (request.estimatedMinutes != null && request.estimatedMinutes! <= 0) ||
        (request.budgetMinor != null && request.budgetMinor! < 0)) {
      return const Failure<RecurrenceTemplate>(
        ValidationFailure('XP, duración o presupuesto no son válidos.'),
      );
    }
    if (!_isCivilDate(request.startDate) ||
        (request.endDate != null && !_isCivilDate(request.endDate!)) ||
        (request.endDate != null &&
            request.endDate!.compareTo(request.startDate) < 0)) {
      return const Failure<RecurrenceTemplate>(
        ValidationFailure('El período de recurrencia no es válido.'),
      );
    }
    if (request.localTimeMinutes != null &&
        (request.localTimeMinutes! < 0 || request.localTimeMinutes! > 1439)) {
      return const Failure<RecurrenceTemplate>(
        ValidationFailure('La hora local no es válida.'),
      );
    }
    if (request.objectives.any(
      (objective) =>
          objective.description.trim().isEmpty ||
          objective.description.trim().length > 240,
    )) {
      return const Failure<RecurrenceTemplate>(
        ValidationFailure(
          'Los objetivos deben contener entre 1 y 240 caracteres.',
        ),
      );
    }
    if (request.frequency == RecurrenceFrequency.specificDays) {
      final int? mask = request.weekdaysMask;
      if (mask == null || mask < 1 || mask > 127) {
        return const Failure<RecurrenceTemplate>(
          ValidationFailure(
            'Se debe seleccionar al menos un día de la semana.',
          ),
        );
      }
    }

    final RecurrenceTemplate? existing = request.existing;
    final String templateId = existing?.id ?? _idGenerator.nextId();
    final String ruleId = existing?.rule?.id ?? _idGenerator.nextId();

    final List<RecurrenceObjective> objectives = <RecurrenceObjective>[
      for (var i = 0; i < request.objectives.length; i++)
        RecurrenceObjective(
          id: request.objectives[i].id ?? _idGenerator.nextId(),
          description: request.objectives[i].description.trim(),
          position: i,
        ),
    ];

    final RecurrenceRule rule = RecurrenceRule(
      id: ruleId,
      templateId: templateId,
      frequency: request.frequency,
      intervalValue: request.intervalValue,
      weekdaysMask: request.frequency == RecurrenceFrequency.specificDays
          ? request.weekdaysMask
          : null,
      localTimeMinutes: request.localTimeMinutes,
      startDate: request.startDate,
      endDate: request.endDate,
      timezoneId: request.timezoneId,
      lastGeneratedOn: existing?.rule?.lastGeneratedOn,
    );

    final String? trimmedDesc = request.description?.trim();
    final RecurrenceTemplate template = RecurrenceTemplate(
      id: templateId,
      areaId: request.areaId,
      title: request.title.trim(),
      description: trimmedDesc?.isEmpty == true ? null : trimmedDesc,
      missionType: request.missionType,
      importance: request.importance,
      priority: request.priority,
      difficulty: request.difficulty,
      isRequired: request.isRequired,
      xpReward: request.xpReward,
      estimatedMinutes: request.estimatedMinutes,
      budgetMinor: request.budgetMinor,
      isActive: existing?.isActive ?? true,
      objectives: objectives,
      rule: rule,
    );

    return existing == null
        ? _repository.create(template, ruleId: ruleId)
        : _repository.update(template);
  }

  // ── Caso de uso 2: Pausar / reanudar plantilla ───────────────────────────

  Future<Result<RecurrenceTemplate>> pauseTemplate(String templateId) =>
      _repository.pause(templateId);

  Future<Result<RecurrenceTemplate>> resumeTemplate(String templateId) =>
      _repository.resume(templateId);

  Future<Result<void>> deleteTemplateIfUnused(String templateId) =>
      _repository.deleteIfUnused(templateId);

  // ── Caso de uso 3: Generar ocurrencias (ventana de 30 días) ─────────────

  /// Genera todas las ocurrencias pendientes dentro de una ventana de 30 días
  /// para todas las plantillas activas. Idempotente.
  Future<Result<int>> generatePendingOccurrences({
    String? localTodayOverride,
  }) async {
    try {
      final DateTime nowUtc = _clock.nowUtc();
      final int nowUtcMs = nowUtc.millisecondsSinceEpoch;

      final List<drift.MissionTemplate> activeTemplates = await _dao
          .watchActiveTemplates()
          .first;

      int created = 0;
      for (final rawTemplate in activeTemplates) {
        final bundle = await _dao.findTemplateBundle(rawTemplate.id);
        if (bundle == null || bundle.rule == null) {
          continue;
        }
        final String localToday =
            localTodayOverride ??
            await _civilTime.localDateForUtc(
              utcEpochMillis: nowUtcMs,
              timeZoneId: bundle.rule!.timezoneId,
            );
        created += await _generateForTemplate(
          bundle: bundle,
          rule: bundle.rule!,
          localToday: localToday,
          nowUtcMs: nowUtcMs,
        );
      }
      return Success<int>(created);
    } on Object catch (error) {
      return Failure<int>(
        StorageFailure(
          'Error al generar ocurrencias recurrentes.',
          cause: error,
        ),
      );
    }
  }

  Future<int> _generateForTemplate({
    required MissionTemplateBundle bundle,
    required drift.RecurrenceRule rule,
    required String localToday,
    required int nowUtcMs,
  }) async {
    final String windowEnd = _addCivilDays(localToday, 29);
    final String from = _maxDate(rule.startDate, localToday);
    final String to = rule.endDate == null
        ? windowEnd
        : _minDate(rule.endDate!, windowEnd);

    final List<String> dates = _occurrenceDates(
      rule: rule,
      from: from,
      to: to,
      alreadyGenerated: rule.lastGeneratedOn,
    );

    int created = 0;
    for (final localDate in dates) {
      final int scheduledAtMs = await _localDateToUtcMs(localDate, rule);
      final String occurrenceId = _idGenerator.nextId();
      final String eventId = _idGenerator.nextId();
      final String notificationId = _idGenerator.nextId();
      final String statusStr = scheduledAtMs > nowUtcMs
          ? 'SCHEDULED'
          : 'AVAILABLE';

      final result = await _dao.generateOccurrenceAtomically(
        occurrence: drift.MissionsCompanion(
          id: Value<String>(occurrenceId),
          templateId: Value<String?>(bundle.template.id),
          areaId: Value<String>(bundle.template.areaId),
          title: Value<String>(bundle.template.title),
          description: Value<String?>(bundle.template.description),
          missionType: Value<String>(bundle.template.missionType),
          importance: Value<String>(bundle.template.importance),
          priority: Value<String>(bundle.template.priority),
          difficulty: Value<String?>(bundle.template.difficulty),
          isRequired: Value<int>(bundle.template.isRequired),
          status: Value<String>(statusStr),
          scheduledAt: Value<int?>(scheduledAtMs),
          xpPlanned: Value<int>(bundle.template.xpReward),
          estimatedMinutes: Value<int?>(bundle.template.estimatedMinutes),
          budgetMinor: Value<int?>(bundle.template.budgetMinor),
        ),
        createdAtUtcMs: nowUtcMs,
        processedLocalDate: localDate,
        objectiveIdFactory: _idGenerator.nextId,
        createdEvent: drift.MissionEventsCompanion(
          id: Value<String>(eventId),
          missionId: Value<String>(occurrenceId),
          eventType: const Value<String>('CREATED'),
          toStatus: Value<String>(statusStr),
          occurredAt: Value<int>(nowUtcMs),
        ),
        notifications: <drift.NotificationSchedulesCompanion>[
          drift.NotificationSchedulesCompanion.insert(
            id: notificationId,
            missionId: occurrenceId,
            notificationType: 'START',
            notifyAt: scheduledAtMs,
            status: 'PENDING',
            createdAt: nowUtcMs,
            updatedAt: nowUtcMs,
          ),
        ],
      );
      if (result.created) {
        created++;
      }
    }
    return created;
  }

  // ── Cálculo de fechas ────────────────────────────────────────────────────

  List<String> _occurrenceDates({
    required drift.RecurrenceRule rule,
    required String from,
    required String to,
    String? alreadyGenerated,
  }) {
    if (from.compareTo(to) > 0) return const <String>[];
    if (alreadyGenerated != null && alreadyGenerated.compareTo(to) >= 0) {
      return const <String>[];
    }

    String effectiveFrom = from;
    if (alreadyGenerated != null && alreadyGenerated.compareTo(from) >= 0) {
      effectiveFrom = _addCivilDays(alreadyGenerated, 1);
    }
    if (effectiveFrom.compareTo(to) > 0) return const <String>[];

    final List<String> dates = <String>[];

    switch (rule.frequency) {
      case 'DAILY':
        _addAnchoredDates(
          dates: dates,
          anchor: rule.startDate,
          from: effectiveFrom,
          to: to,
          stepDays: rule.intervalValue,
        );
      case 'WEEKLY':
        _addAnchoredDates(
          dates: dates,
          anchor: rule.startDate,
          from: effectiveFrom,
          to: to,
          stepDays: 7 * rule.intervalValue,
        );
      case 'SPECIFIC_DAYS':
        final int mask = rule.weekdaysMask ?? 0;
        String cursor = effectiveFrom;
        while (cursor.compareTo(to) <= 0) {
          final int weekday = _parseCivilDate(cursor).weekday;
          if ((mask & (1 << (weekday - 1))) != 0) {
            dates.add(cursor);
          }
          cursor = _addCivilDays(cursor, 1);
        }
      case 'EVERY_N_DAYS':
        _addAnchoredDates(
          dates: dates,
          anchor: rule.startDate,
          from: effectiveFrom,
          to: to,
          stepDays: rule.intervalValue,
        );
    }
    return dates;
  }

  void _addAnchoredDates({
    required List<String> dates,
    required String anchor,
    required String from,
    required String to,
    required int stepDays,
  }) {
    String cursor = from;
    final int anchorDay = _civilDayNumber(anchor);
    while ((_civilDayNumber(cursor) - anchorDay) % stepDays != 0) {
      cursor = _addCivilDays(cursor, 1);
    }
    while (cursor.compareTo(to) <= 0) {
      dates.add(cursor);
      cursor = _addCivilDays(cursor, stepDays);
    }
  }

  Future<int> _localDateToUtcMs(String localDate, drift.RecurrenceRule rule) =>
      _civilTime.localDateTimeToUtcEpochMillis(
        localDate: localDate,
        localTimeMinutes: rule.localTimeMinutes ?? 0,
        timeZoneId: rule.timezoneId,
      );

  static DateTime _parseCivilDate(String value) {
    final List<int> parts = value.split('-').map(int.parse).toList();
    return DateTime.utc(parts[0], parts[1], parts[2]);
  }

  static bool _isCivilDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return false;
    }
    try {
      return _dateStr(_parseCivilDate(value)) == value;
    } on Object {
      return false;
    }
  }

  static int _civilDayNumber(String value) =>
      _parseCivilDate(value).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  static String _addCivilDays(String value, int days) {
    final DateTime date = _parseCivilDate(value).add(Duration(days: days));
    return _dateStr(date);
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _maxDate(String a, String b) => a.compareTo(b) >= 0 ? a : b;
  static String _minDate(String a, String b) => a.compareTo(b) <= 0 ? a : b;
}
