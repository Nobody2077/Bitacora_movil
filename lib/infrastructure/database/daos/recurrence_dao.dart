import 'package:drift/drift.dart';

import '../app_database.dart';
import 'dao_support.dart';

final class MissionTemplateBundle {
  const MissionTemplateBundle({
    required this.template,
    required this.objectives,
    required this.rule,
  });

  final MissionTemplate template;
  final List<MissionTemplateObjective> objectives;
  final RecurrenceRule? rule;
}

final class MissionBoardLink {
  const MissionBoardLink({
    required this.templateId,
    this.missionId,
    this.scheduledAt,
    this.status,
  });

  final String templateId;
  final String? missionId;
  final int? scheduledAt;
  final String? status;
}

final class RecurrenceDao {
  RecurrenceDao(this._database);

  final AppDatabase _database;

  Stream<List<MissionTemplate>> watchActiveTemplates({String? areaId}) {
    final query = _database.select(_database.missionTemplates)
      ..where((table) {
        var predicate = table.isActive.equals(1);
        if (areaId != null) {
          predicate = predicate & table.areaId.equals(areaId);
        }
        return predicate;
      })
      ..orderBy(<OrderingTerm Function(MissionTemplates)>[
        (table) => OrderingTerm.asc(table.title),
        (table) => OrderingTerm.asc(table.id),
      ]);
    return query.watch();
  }

  Future<MissionTemplateBundle?> findTemplateBundle(String templateId) {
    return _database.transaction(() => _findTemplateBundle(templateId));
  }

  Future<bool> templateHasMissions(String templateId) async {
    final count = _database.missions.id.count();
    final row =
        await (_database.selectOnly(_database.missions)
              ..addColumns(<Expression<Object>>[count])
              ..where(_database.missions.templateId.equals(templateId)))
            .getSingle();
    return (row.read(count) ?? 0) > 0;
  }

  Future<MissionTemplateBundle?> _findTemplateBundle(String templateId) async {
    final template = await (_database.select(
      _database.missionTemplates,
    )..where((table) => table.id.equals(templateId))).getSingleOrNull();
    if (template == null) {
      return null;
    }

    final objectives =
        await (_database.select(_database.missionTemplateObjectives)
              ..where((table) => table.templateId.equals(templateId))
              ..orderBy(<OrderingTerm Function(MissionTemplateObjectives)>[
                (table) => OrderingTerm.asc(table.position),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    final rule = await (_database.select(
      _database.recurrenceRules,
    )..where((table) => table.templateId.equals(templateId))).getSingleOrNull();
    return MissionTemplateBundle(
      template: template,
      objectives: objectives,
      rule: rule,
    );
  }

  Stream<List<MissionBoardLink>> watchBoardLinks() => _database
      .customSelect(
        '''
          SELECT
            mt.id AS template_id,
            m.id AS mission_id,
            m.scheduled_at AS scheduled_at,
            m.status AS mission_status
          FROM mission_templates AS mt
          LEFT JOIN missions AS m ON m.template_id = mt.id
          WHERE mt.is_active = 1
            AND mt.availability_mode = 'BOARD'
          ORDER BY mt.title COLLATE NOCASE, mt.id, m.scheduled_at DESC
        ''',
        readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
          _database.missionTemplates,
          _database.missions,
        },
      )
      .watch()
      .map(
        (rows) => rows
            .map(
              (row) => MissionBoardLink(
                templateId: row.read<String>('template_id'),
                missionId: row.readNullable<String>('mission_id'),
                scheduledAt: row.readNullable<int>('scheduled_at'),
                status: row.readNullable<String>('mission_status'),
              ),
            )
            .toList(growable: false),
      );

  Future<MissionTemplateBundle> insertTemplateAggregate({
    required MissionTemplatesCompanion template,
    Iterable<MissionTemplateObjectivesCompanion> objectives =
        const <MissionTemplateObjectivesCompanion>[],
    RecurrenceRulesCompanion? rule,
  }) {
    if (!template.id.present) {
      throw ArgumentError('Template id must be present.');
    }
    final templateId = template.id.value;

    return _database.transaction(() async {
      await _database.into(_database.missionTemplates).insert(template);
      for (final objective in objectives) {
        _requireTemplateId(objective.templateId, templateId, 'objective');
        await _database
            .into(_database.missionTemplateObjectives)
            .insert(objective);
      }
      if (rule != null) {
        _requireTemplateId(rule.templateId, templateId, 'recurrence rule');
        await _database.into(_database.recurrenceRules).insert(rule);
      }

      final inserted = await _findTemplateBundle(templateId);
      if (inserted == null) {
        throw RecordNotFoundException(
          table: 'mission_templates',
          key: templateId,
        );
      }
      return inserted;
    });
  }

  Future<MissionTemplateBundle> updateTemplateAggregate({
    required MissionTemplatesCompanion template,
    required Iterable<MissionTemplateObjectivesCompanion> objectives,
    required RecurrenceRulesCompanion rule,
  }) {
    if (!template.id.present) {
      throw ArgumentError('Template id must be present.');
    }
    final String templateId = template.id.value;
    _requireTemplateId(rule.templateId, templateId, 'recurrence rule');
    final List<MissionTemplateObjectivesCompanion> objectiveList = objectives
        .toList(growable: false);
    for (final objective in objectiveList) {
      _requireTemplateId(objective.templateId, templateId, 'objective');
    }

    return _database.transaction(() async {
      final int updated = await (_database.update(
        _database.missionTemplates,
      )..where((table) => table.id.equals(templateId))).write(template);
      if (updated != 1) {
        throw RecordNotFoundException(
          table: 'mission_templates',
          key: templateId,
        );
      }

      await (_database.delete(
        _database.missionTemplateObjectives,
      )..where((table) => table.templateId.equals(templateId))).go();
      for (final objective in objectiveList) {
        await _database
            .into(_database.missionTemplateObjectives)
            .insert(objective);
      }
      await _database
          .into(_database.recurrenceRules)
          .insertOnConflictUpdate(rule);

      final MissionTemplateBundle? stored = await _findTemplateBundle(
        templateId,
      );
      if (stored == null) {
        throw RecordNotFoundException(
          table: 'mission_templates',
          key: templateId,
        );
      }
      return stored;
    });
  }

  Future<RecurrenceRule> putRule(RecurrenceRulesCompanion rule) async {
    if (!rule.templateId.present) {
      throw ArgumentError('Recurrence rule template_id must be present.');
    }
    await _database
        .into(_database.recurrenceRules)
        .insertOnConflictUpdate(rule);
    final stored =
        await (_database.select(
              _database.recurrenceRules,
            )..where((table) => table.templateId.equals(rule.templateId.value)))
            .getSingleOrNull();
    if (stored == null) {
      throw RecordNotFoundException(
        table: 'recurrence_rules',
        key: rule.templateId.value,
      );
    }
    return stored;
  }

  Future<void> replaceTemplateObjectives({
    required String templateId,
    required Iterable<MissionTemplateObjectivesCompanion> objectives,
  }) {
    return _database.transaction(() async {
      final templateExists =
          await (_database.selectOnly(_database.missionTemplates)
                ..addColumns(<Expression<Object>>[
                  _database.missionTemplates.id,
                ])
                ..where(_database.missionTemplates.id.equals(templateId)))
              .getSingleOrNull();
      if (templateExists == null) {
        throw RecordNotFoundException(
          table: 'mission_templates',
          key: templateId,
        );
      }

      await (_database.delete(
        _database.missionTemplateObjectives,
      )..where((table) => table.templateId.equals(templateId))).go();
      for (final objective in objectives) {
        _requireTemplateId(objective.templateId, templateId, 'objective');
        await _database
            .into(_database.missionTemplateObjectives)
            .insert(objective);
      }
    });
  }

  Future<DaoWriteResult<Mission>> generateOccurrenceAtomically({
    required MissionsCompanion occurrence,
    required int createdAtUtcMs,
    required String processedLocalDate,
    required String Function() objectiveIdFactory,
    required MissionEventsCompanion createdEvent,
    Iterable<NotificationSchedulesCompanion> notifications =
        const <NotificationSchedulesCompanion>[],
  }) {
    _validateOccurrence(occurrence);
    final occurrenceId = occurrence.id.value;
    final templateId = occurrence.templateId.value!;
    final occurrenceStatus = occurrence.status;
    if (!createdEvent.id.present ||
        !createdEvent.eventType.present ||
        createdEvent.eventType.value != 'CREATED' ||
        !createdEvent.occurredAt.present ||
        !createdEvent.missionId.present ||
        createdEvent.missionId.value != occurrenceId ||
        !createdEvent.toStatus.present ||
        !occurrenceStatus.present ||
        createdEvent.toStatus.value != occurrenceStatus.value) {
      throw ArgumentError(
        'CREATED event must reference the occurrence and its initial status.',
      );
    }
    final schedules = notifications.toList(growable: false);
    for (final schedule in schedules) {
      if (!schedule.id.present ||
          !schedule.missionId.present ||
          schedule.missionId.value != occurrenceId ||
          !schedule.notificationType.present ||
          !schedule.notifyAt.present ||
          !schedule.status.present ||
          !schedule.createdAt.present ||
          !schedule.updatedAt.present) {
        throw ArgumentError(
          'Every notification must be complete and reference occurrence '
          '$occurrenceId.',
        );
      }
    }

    return _database.transaction(() async {
      final rule =
          await (_database.select(_database.recurrenceRules)
                ..where((table) => table.templateId.equals(templateId)))
              .getSingleOrNull();
      if (rule == null) {
        throw RecordNotFoundException(
          table: 'recurrence_rules',
          key: templateId,
        );
      }

      final result = await _createOccurrenceIfAbsent(
        occurrence: occurrence,
        createdAtUtcMs: createdAtUtcMs,
        objectiveIdFactory: objectiveIdFactory,
      );
      if (result.created) {
        await _database.into(_database.missionEvents).insert(createdEvent);
        for (final schedule in schedules) {
          await _database
              .into(_database.notificationSchedules)
              .insert(schedule);
        }
      } else {
        _validateSameOccurrence(result.value, occurrence);
        await _verifyGeneratedAggregate(
          mission: result.value,
          createdAtUtcMs: createdAtUtcMs,
          createdEvent: createdEvent,
          notifications: schedules,
        );
      }

      if (rule.lastGeneratedOn == null ||
          rule.lastGeneratedOn!.compareTo(processedLocalDate) < 0) {
        final updated =
            await (_database.update(
              _database.recurrenceRules,
            )..where((table) => table.templateId.equals(templateId))).write(
              RecurrenceRulesCompanion(
                lastGeneratedOn: Value<String?>(processedLocalDate),
              ),
            );
        if (updated != 1) {
          throw RecordNotFoundException(
            table: 'recurrence_rules',
            key: templateId,
          );
        }
      }
      return result;
    });
  }

  Future<DaoWriteResult<Mission>> takeBoardMissionAtomically({
    required MissionsCompanion occurrence,
    required int createdAtUtcMs,
    required String Function() objectiveIdFactory,
    required MissionEventsCompanion createdEvent,
  }) {
    _validateOccurrence(occurrence);
    final String missionId = occurrence.id.value;
    final String templateId = occurrence.templateId.value!;
    final int scheduledAt = occurrence.scheduledAt.value!;
    if (occurrence.status.value != 'AVAILABLE' ||
        !createdEvent.id.present ||
        createdEvent.missionId.value != missionId ||
        createdEvent.eventType.value != 'CREATED' ||
        createdEvent.toStatus.value != 'AVAILABLE') {
      throw ArgumentError('Invalid board occurrence aggregate.');
    }

    return _database.transaction(() async {
      final MissionTemplate? template = await (_database.select(
        _database.missionTemplates,
      )..where((table) => table.id.equals(templateId))).getSingleOrNull();
      if (template == null ||
          template.isActive != 1 ||
          template.availabilityMode != 'BOARD') {
        throw RecordNotFoundException(
          table: 'mission_templates',
          key: templateId,
        );
      }

      final Mission? existing =
          await (_database.select(_database.missions)..where(
                (table) =>
                    table.templateId.equals(templateId) &
                    table.scheduledAt.equals(scheduledAt),
              ))
              .getSingleOrNull();
      if (existing != null) {
        return DaoWriteResult<Mission>(value: existing, created: false);
      }

      final Mission inserted = await _database
          .into(_database.missions)
          .insertReturning(occurrence);
      final objectives =
          await (_database.select(_database.missionTemplateObjectives)
                ..where((table) => table.templateId.equals(templateId))
                ..orderBy(<OrderingTerm Function(MissionTemplateObjectives)>[
                  (table) => OrderingTerm.asc(table.position),
                ]))
              .get();
      for (final MissionTemplateObjective objective in objectives) {
        await _database
            .into(_database.missionObjectives)
            .insert(
              MissionObjectivesCompanion.insert(
                id: objectiveIdFactory(),
                missionId: missionId,
                description: objective.description,
                position: objective.position,
                createdAt: createdAtUtcMs,
              ),
            );
      }
      await _database.into(_database.missionEvents).insert(createdEvent);
      return DaoWriteResult<Mission>(value: inserted, created: true);
    });
  }

  Future<DaoWriteResult<Mission>> _createOccurrenceIfAbsent({
    required MissionsCompanion occurrence,
    required int createdAtUtcMs,
    required String Function() objectiveIdFactory,
  }) async {
    final occurrenceId = occurrence.id.value;
    final templateId = occurrence.templateId.value!;
    final scheduledAt = occurrence.scheduledAt.value!;

    final inserted = await _database
        .into(_database.missions)
        .insertReturningOrNull(occurrence, mode: InsertMode.insertOrIgnore);

    if (inserted != null) {
      final defaults =
          await (_database.select(_database.missionTemplateObjectives)
                ..where((table) => table.templateId.equals(templateId))
                ..orderBy(<OrderingTerm Function(MissionTemplateObjectives)>[
                  (table) => OrderingTerm.asc(table.position),
                ]))
              .get();
      for (final objective in defaults) {
        await _database
            .into(_database.missionObjectives)
            .insert(
              MissionObjectivesCompanion.insert(
                id: objectiveIdFactory(),
                missionId: occurrenceId,
                description: objective.description,
                position: objective.position,
                createdAt: createdAtUtcMs,
              ),
            );
      }
      return DaoWriteResult<Mission>(value: inserted, created: true);
    }

    final existing =
        await (_database.select(_database.missions)..where(
              (table) =>
                  table.templateId.equals(templateId) &
                  table.scheduledAt.equals(scheduledAt),
            ))
            .getSingleOrNull();
    if (existing == null) {
      throw IdempotencyConflictException(
        operationId: '$templateId@$scheduledAt',
        entity: 'mission occurrence',
      );
    }
    return DaoWriteResult<Mission>(value: existing, created: false);
  }

  Future<void> _verifyGeneratedAggregate({
    required Mission mission,
    required int createdAtUtcMs,
    required MissionEventsCompanion createdEvent,
    required List<NotificationSchedulesCompanion> notifications,
  }) async {
    final templateObjectives =
        await (_database.select(_database.missionTemplateObjectives)
              ..where((table) => table.templateId.equals(mission.templateId!))
              ..orderBy(<OrderingTerm Function(MissionTemplateObjectives)>[
                (table) => OrderingTerm.asc(table.position),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    final missionObjectives =
        await (_database.select(_database.missionObjectives)
              ..where((table) => table.missionId.equals(mission.id))
              ..orderBy(<OrderingTerm Function(MissionObjectives)>[
                (table) => OrderingTerm.asc(table.position),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    if (missionObjectives.length != templateObjectives.length) {
      _throwOccurrenceConflict(mission);
    }
    for (var index = 0; index < templateObjectives.length; index++) {
      final templateObjective = templateObjectives[index];
      final missionObjective = missionObjectives[index];
      if (missionObjective.description != templateObjective.description ||
          missionObjective.position != templateObjective.position ||
          missionObjective.completedAt != null ||
          missionObjective.createdAt != createdAtUtcMs) {
        _throwOccurrenceConflict(mission);
      }
    }

    final createdEvents =
        await (_database.select(_database.missionEvents)..where(
              (table) =>
                  table.missionId.equals(mission.id) &
                  table.eventType.equals('CREATED'),
            ))
            .get();
    if (createdEvents.length != 1 ||
        !_matchesCreatedEvent(createdEvents.single, createdEvent)) {
      _throwOccurrenceConflict(mission);
    }

    final storedNotifications =
        await (_database.select(_database.notificationSchedules)
              ..where((table) => table.missionId.equals(mission.id))
              ..orderBy(<OrderingTerm Function(NotificationSchedules)>[
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    if (storedNotifications.length != notifications.length) {
      _throwOccurrenceConflict(mission);
    }
    final expectedById = <String, NotificationSchedulesCompanion>{
      for (final notification in notifications)
        notification.id.value: notification,
    };
    for (final stored in storedNotifications) {
      final expected = expectedById[stored.id];
      if (expected == null || !_matchesNotification(stored, expected)) {
        _throwOccurrenceConflict(mission);
      }
    }
  }

  void _validateSameOccurrence(Mission stored, MissionsCompanion requested) {
    final matches =
        stored.id == requested.id.value &&
        stored.templateId == requested.templateId.value &&
        stored.areaId == requested.areaId.value &&
        stored.title == requested.title.value &&
        stored.description ==
            (requested.description.present
                ? requested.description.value
                : null) &&
        stored.missionType == requested.missionType.value &&
        stored.importance ==
            (requested.importance.present
                ? requested.importance.value
                : 'NORMAL') &&
        stored.priority ==
            (requested.priority.present
                ? requested.priority.value
                : 'NORMAL') &&
        stored.difficulty ==
            (requested.difficulty.present
                ? requested.difficulty.value
                : null) &&
        stored.isRequired == requested.isRequired.value &&
        stored.status == requested.status.value &&
        stored.scheduledAt == requested.scheduledAt.value &&
        stored.availableFrom ==
            (requested.availableFrom.present
                ? requested.availableFrom.value
                : null) &&
        stored.expiresAt ==
            (requested.expiresAt.present ? requested.expiresAt.value : null) &&
        stored.estimatedMinutes ==
            (requested.estimatedMinutes.present
                ? requested.estimatedMinutes.value
                : null) &&
        stored.budgetMinor ==
            (requested.budgetMinor.present
                ? requested.budgetMinor.value
                : null) &&
        stored.xpPlanned == requested.xpPlanned.value &&
        stored.actualResult ==
            (requested.actualResult.present
                ? requested.actualResult.value
                : null) &&
        stored.convenienceRating ==
            (requested.convenienceRating.present
                ? requested.convenienceRating.value
                : null) &&
        stored.completedAt ==
            (requested.completedAt.present
                ? requested.completedAt.value
                : null) &&
        stored.archivedAt ==
            (requested.archivedAt.present
                ? requested.archivedAt.value
                : null) &&
        stored.rowVersion ==
            (requested.rowVersion.present ? requested.rowVersion.value : 1);
    if (!matches) {
      _throwOccurrenceConflict(stored);
    }
  }

  bool _matchesCreatedEvent(
    MissionEvent stored,
    MissionEventsCompanion expected,
  ) {
    return stored.id == expected.id.value &&
        stored.missionId == expected.missionId.value &&
        stored.eventType == expected.eventType.value &&
        stored.fromStatus ==
            (expected.fromStatus.present ? expected.fromStatus.value : null) &&
        stored.toStatus == expected.toStatus.value &&
        stored.reason ==
            (expected.reason.present ? expected.reason.value : null) &&
        stored.snapshotJson ==
            (expected.snapshotJson.present
                ? expected.snapshotJson.value
                : null) &&
        stored.occurredAt == expected.occurredAt.value;
  }

  bool _matchesNotification(
    NotificationSchedule stored,
    NotificationSchedulesCompanion expected,
  ) {
    return stored.missionId == expected.missionId.value &&
        stored.notificationType == expected.notificationType.value &&
        stored.notifyAt == expected.notifyAt.value &&
        stored.status == expected.status.value &&
        stored.systemNotificationId ==
            (expected.systemNotificationId.present
                ? expected.systemNotificationId.value
                : null) &&
        stored.createdAt == expected.createdAt.value &&
        stored.updatedAt == expected.updatedAt.value;
  }

  Never _throwOccurrenceConflict(Mission mission) {
    throw IdempotencyConflictException(
      operationId: '${mission.templateId}@${mission.scheduledAt}',
      entity: 'mission occurrence aggregate',
    );
  }

  void _validateOccurrence(MissionsCompanion occurrence) {
    if (!occurrence.id.present ||
        !occurrence.templateId.present ||
        occurrence.templateId.value == null ||
        !occurrence.areaId.present ||
        !occurrence.title.present ||
        !occurrence.missionType.present ||
        !occurrence.isRequired.present ||
        !occurrence.status.present ||
        !occurrence.scheduledAt.present ||
        occurrence.scheduledAt.value == null ||
        !occurrence.xpPlanned.present) {
      throw ArgumentError('Occurrence requires its complete insert payload.');
    }
  }

  Future<void> deleteUnusedTemplate(String templateId) {
    return _database.transaction(() async {
      final generatedCount = _database.missions.id.count();
      final countRow =
          await (_database.selectOnly(_database.missions)
                ..addColumns(<Expression<Object>>[generatedCount])
                ..where(_database.missions.templateId.equals(templateId)))
              .getSingle();
      if ((countRow.read(generatedCount) ?? 0) != 0) {
        throw const DatabaseInvariantException(
          'A template with generated missions cannot be physically deleted.',
        );
      }

      final deleted = await (_database.delete(
        _database.missionTemplates,
      )..where((table) => table.id.equals(templateId))).go();
      if (deleted != 1) {
        throw RecordNotFoundException(
          table: 'mission_templates',
          key: templateId,
        );
      }
    });
  }

  // ── métodos de escritura de plantilla ──────────────────────────────────

  /// Stream de todas las plantillas, activas y pausadas, ordenadas por título.
  Stream<List<MissionTemplate>> watchAllTemplates() {
    return (_database.select(_database.missionTemplates)
          ..orderBy(<OrderingTerm Function(MissionTemplates)>[
            (table) => OrderingTerm.asc(table.title),
            (table) => OrderingTerm.asc(table.id),
          ]))
        .watch();
  }

  /// Actualiza los campos de una plantilla existente sin tocar objetivos ni
  /// regla. Lanza [RecordNotFoundException] si no existe.
  Future<void> updateTemplate(MissionTemplatesCompanion patch) async {
    if (!patch.id.present) {
      throw ArgumentError('Template id must be present.');
    }
    final updated = await (_database.update(
      _database.missionTemplates,
    )..where((table) => table.id.equals(patch.id.value))).write(patch);
    if (updated != 1) {
      throw RecordNotFoundException(
        table: 'mission_templates',
        key: patch.id.value,
      );
    }
  }

  /// Activa (`isActive = 1`) o pausa (`isActive = 0`) una plantilla.
  Future<void> setTemplateActive(
    String templateId, {
    required bool isActive,
  }) async {
    final updated =
        await (_database.update(
          _database.missionTemplates,
        )..where((table) => table.id.equals(templateId))).write(
          MissionTemplatesCompanion(isActive: Value<int>(isActive ? 1 : 0)),
        );
    if (updated != 1) {
      throw RecordNotFoundException(
        table: 'mission_templates',
        key: templateId,
      );
    }
  }

  void _requireTemplateId(
    Value<String> actual,
    String expected,
    String childName,
  ) {
    if (!actual.present || actual.value != expected) {
      throw ArgumentError('$childName must reference template $expected.');
    }
  }
}
