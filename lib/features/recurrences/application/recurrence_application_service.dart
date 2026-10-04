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
    this.location,
    this.weekdaysMask,
    this.localTimeMinutes,
    this.endDate,
    this.availabilityMode = TemplateAvailabilityMode.automatic,
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

  /// Se copia a cada misión que genera la plantilla (ADR-006).
  final String? location;
  final RecurrenceFrequency frequency;
  final int intervalValue;
  final int? weekdaysMask;
  final int? localTimeMinutes;
  final String startDate;
  final String? endDate;
  final String timezoneId;
  final List<RecurrenceObjectiveDraft> objectives;
  final TemplateAvailabilityMode availabilityMode;
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
    if ((_trimmedOrNull(request.location)?.length ?? 0) > 120) {
      return const Failure<RecurrenceTemplate>(
        ValidationFailure('La ubicación admite hasta 120 caracteres.'),
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
    if (request.availabilityMode == TemplateAvailabilityMode.board &&
        (request.missionType != MissionType.daily ||
            request.frequency != RecurrenceFrequency.daily ||
            request.intervalValue != 1 ||
            request.localTimeMinutes != null)) {
      return const Failure<RecurrenceTemplate>(
        ValidationFailure('El tablón admite misiones diarias sin hora fija.'),
      );
    }

    final RecurrenceTemplate? existing = request.existing;
    if (existing != null &&
        existing.availabilityMode != request.availabilityMode &&
        await _dao.templateHasMissions(existing.id)) {
      return const Failure<RecurrenceTemplate>(
        ConflictFailure(
          'No se puede cambiar el modo porque la plantilla ya tiene misiones. '
          'Páusala y crea una nueva plantilla con el modo deseado.',
        ),
      );
    }
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
      location: _trimmedOrNull(request.location),
      availabilityMode: request.availabilityMode,
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
        if (rawTemplate.availabilityMode == 'BOARD') {
          continue;
        }
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

  /// Emite el tablón del día y reacciona tanto a plantillas como a misiones
  /// tomadas. Las plantillas fuera de su período civil no se muestran.
  Stream<Result<List<MissionBoardEntry>>> watchMissionBoard() =>
      _dao.watchBoardLinks().asyncMap((List<MissionBoardLink> links) async {
        try {
          final List<MissionBoardEntry> entries = <MissionBoardEntry>[];
          final Set<String> templateIds = <String>{
            for (final MissionBoardLink link in links) link.templateId,
          };
          final int nowUtcMs = _clock.nowUtc().millisecondsSinceEpoch;
          for (final String templateId in templateIds) {
            final Result<RecurrenceTemplate?> loaded = await _repository
                .findById(templateId);
            final RecurrenceTemplate? template = loaded.fold(
              onSuccess: (RecurrenceTemplate? value) => value,
              onFailure: (AppFailure failure) => throw failure,
            );
            final RecurrenceRule? rule = template?.rule;
            if (template == null ||
                !template.isActive ||
                template.availabilityMode != TemplateAvailabilityMode.board ||
                rule == null) {
              continue;
            }
            final String localToday = await _civilTime.localDateForUtc(
              utcEpochMillis: nowUtcMs,
              timeZoneId: rule.timezoneId,
            );
            if (!_boardRuleIncludes(rule, localToday)) {
              continue;
            }
            final int dayStart = await _civilTime.localDateTimeToUtcEpochMillis(
              localDate: localToday,
              localTimeMinutes: 0,
              timeZoneId: rule.timezoneId,
            );
            final int nextDayStart = await _civilTime
                .localDateTimeToUtcEpochMillis(
                  localDate: _addCivilDays(localToday, 1),
                  localTimeMinutes: 0,
                  timeZoneId: rule.timezoneId,
                );
            MissionBoardLink? taken;
            for (final MissionBoardLink link in links) {
              final int? scheduledAt = link.scheduledAt;
              if (link.templateId == templateId &&
                  link.missionId != null &&
                  scheduledAt != null &&
                  scheduledAt >= dayStart &&
                  scheduledAt < nextDayStart) {
                taken = link;
                break;
              }
            }
            entries.add(
              MissionBoardEntry(
                template: template,
                missionId: taken?.missionId,
                missionStatus: taken?.status == null
                    ? null
                    : _missionStatusFromDb(taken!.status!),
              ),
            );
          }
          entries.sort(
            (MissionBoardEntry a, MissionBoardEntry b) => a.template.title
                .toLowerCase()
                .compareTo(b.template.title.toLowerCase()),
          );
          return Success<List<MissionBoardEntry>>(entries);
        } on AppFailure catch (failure) {
          return Failure<List<MissionBoardEntry>>(failure);
        } on Object catch (error) {
          return Failure<List<MissionBoardEntry>>(
            StorageFailure('No se pudo cargar el tablón diario.', cause: error),
          );
        }
      });

  /// Toma una misión una sola vez por plantilla y día civil.
  Future<Result<MissionBoardTake>> takeMissionFromBoard(
    String templateId,
  ) async {
    try {
      final MissionTemplateBundle? bundle = await _dao.findTemplateBundle(
        templateId,
      );
      final drift.RecurrenceRule? rule = bundle?.rule;
      if (bundle == null ||
          rule == null ||
          bundle.template.isActive != 1 ||
          bundle.template.availabilityMode != 'BOARD') {
        return const Failure<MissionBoardTake>(
          ValidationFailure('La misión ya no está disponible en el tablón.'),
        );
      }
      final int nowUtcMs = _clock.nowUtc().millisecondsSinceEpoch;
      final String localToday = await _civilTime.localDateForUtc(
        utcEpochMillis: nowUtcMs,
        timeZoneId: rule.timezoneId,
      );
      if (!_boardRuleIncludesRaw(rule, localToday)) {
        return const Failure<MissionBoardTake>(
          ValidationFailure('La misión no está disponible durante este día.'),
        );
      }
      final int dayStart = await _civilTime.localDateTimeToUtcEpochMillis(
        localDate: localToday,
        localTimeMinutes: 0,
        timeZoneId: rule.timezoneId,
      );
      final int nextDayStart = await _civilTime.localDateTimeToUtcEpochMillis(
        localDate: _addCivilDays(localToday, 1),
        localTimeMinutes: 0,
        timeZoneId: rule.timezoneId,
      );
      final String missionId = _idGenerator.nextId();
      final stored = await _dao.takeBoardMissionAtomically(
        occurrence: drift.MissionsCompanion(
          id: Value<String>(missionId),
          templateId: Value<String?>(bundle.template.id),
          areaId: Value<String>(bundle.template.areaId),
          title: Value<String>(bundle.template.title),
          description: Value<String?>(bundle.template.description),
          missionType: Value<String>(bundle.template.missionType),
          importance: Value<String>(bundle.template.importance),
          priority: Value<String>(bundle.template.priority),
          difficulty: Value<String?>(bundle.template.difficulty),
          isRequired: Value<int>(bundle.template.isRequired),
          status: const Value<String>('AVAILABLE'),
          scheduledAt: Value<int?>(dayStart),
          availableFrom: Value<int?>(dayStart),
          expiresAt: Value<int?>(nextDayStart - 1),
          xpPlanned: Value<int>(bundle.template.xpReward),
          estimatedMinutes: Value<int?>(bundle.template.estimatedMinutes),
          budgetMinor: Value<int?>(bundle.template.budgetMinor),
          location: Value<String?>(bundle.template.location),
        ),
        createdAtUtcMs: nowUtcMs,
        objectiveIdFactory: _idGenerator.nextId,
        createdEvent: drift.MissionEventsCompanion(
          id: Value<String>(_idGenerator.nextId()),
          missionId: Value<String>(missionId),
          eventType: const Value<String>('CREATED'),
          toStatus: const Value<String>('AVAILABLE'),
          occurredAt: Value<int>(nowUtcMs),
          reason: const Value<String?>('Tomada desde el tablón diario'),
        ),
      );
      return Success<MissionBoardTake>(
        MissionBoardTake(missionId: stored.value.id, created: stored.created),
      );
    } on Object catch (error) {
      return Failure<MissionBoardTake>(
        StorageFailure('No se pudo tomar la misión del tablón.', cause: error),
      );
    }
  }

  bool _boardRuleIncludes(RecurrenceRule rule, String localDate) =>
      rule.frequency == RecurrenceFrequency.daily &&
      rule.intervalValue == 1 &&
      rule.localTimeMinutes == null &&
      rule.startDate.compareTo(localDate) <= 0 &&
      (rule.endDate == null || rule.endDate!.compareTo(localDate) >= 0);

  bool _boardRuleIncludesRaw(drift.RecurrenceRule rule, String localDate) =>
      rule.frequency == 'DAILY' &&
      rule.intervalValue == 1 &&
      rule.localTimeMinutes == null &&
      rule.startDate.compareTo(localDate) <= 0 &&
      (rule.endDate == null || rule.endDate!.compareTo(localDate) >= 0);

  MissionStatus _missionStatusFromDb(String value) => switch (value) {
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
    _ => throw FormatException('Unknown mission status: $value'),
  };

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
      final bool hasFixedTime = rule.localTimeMinutes != null;
      final int? availableFromMs = hasFixedTime ? null : scheduledAtMs;
      final int? expiresAtMs = hasFixedTime
          ? null
          : (await _civilTime.localDateTimeToUtcEpochMillis(
                  localDate: _addCivilDays(localDate, 1),
                  localTimeMinutes: 0,
                  timeZoneId: rule.timezoneId,
                )) -
                1;
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
          availableFrom: Value<int?>(availableFromMs),
          expiresAt: Value<int?>(expiresAtMs),
          xpPlanned: Value<int>(bundle.template.xpReward),
          estimatedMinutes: Value<int?>(bundle.template.estimatedMinutes),
          budgetMinor: Value<int?>(bundle.template.budgetMinor),
          location: Value<String?>(bundle.template.location),
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
        notifications: hasFixedTime
            ? <drift.NotificationSchedulesCompanion>[
                drift.NotificationSchedulesCompanion.insert(
                  id: notificationId,
                  missionId: occurrenceId,
                  notificationType: 'START',
                  notifyAt: scheduledAtMs,
                  status: 'PENDING',
                  createdAt: nowUtcMs,
                  updatedAt: nowUtcMs,
                ),
              ]
            : const <drift.NotificationSchedulesCompanion>[],
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

  static String? _trimmedOrNull(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
