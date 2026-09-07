import 'package:drift/drift.dart';

import '../app_database.dart';
import 'dao_support.dart';

final class MissionAggregate {
  const MissionAggregate({
    required this.mission,
    required this.objectives,
    required this.timeEntries,
    required this.events,
    required this.notifications,
  });

  final Mission mission;
  final List<MissionObjective> objectives;
  final List<TimeEntry> timeEntries;
  final List<MissionEvent> events;
  final List<NotificationSchedule> notifications;
}

final class MissionDao {
  MissionDao(this._database);

  final AppDatabase _database;

  Future<List<LifeArea>> findVisibleAreas() {
    return (_database.select(_database.lifeAreas)
          ..where(
            (table) => table.isVisible.equals(1) & table.archivedAt.isNull(),
          )
          ..orderBy(<OrderingTerm Function(LifeAreas)>[
            (table) => OrderingTerm.asc(table.sortOrder),
            (table) => OrderingTerm.asc(table.name),
          ]))
        .get();
  }

  Future<Mission?> findById(String id) {
    return (_database.select(
      _database.missions,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Stream<Mission?> watchById(String id) {
    return (_database.select(
      _database.missions,
    )..where((table) => table.id.equals(id))).watchSingleOrNull();
  }

  Stream<List<Mission>> watchPeriod({
    required int startUtcMs,
    required int endUtcMs,
    String? areaId,
    Set<String> statuses = const <String>{},
  }) {
    if (endUtcMs <= startUtcMs) {
      throw ArgumentError.value(
        endUtcMs,
        'endUtcMs',
        'Must exceed startUtcMs.',
      );
    }

    final query = _database.select(_database.missions)
      ..where((table) {
        var predicate =
            table.scheduledAt.isBiggerOrEqualValue(startUtcMs) &
            table.scheduledAt.isSmallerThanValue(endUtcMs) &
            table.archivedAt.isNull();
        if (areaId != null) {
          predicate = predicate & table.areaId.equals(areaId);
        }
        if (statuses.isNotEmpty) {
          predicate = predicate & table.status.isIn(statuses);
        }
        return predicate;
      })
      ..orderBy(<OrderingTerm Function(Missions)>[
        (table) => OrderingTerm.asc(table.scheduledAt),
        (table) => OrderingTerm.asc(table.id),
      ]);
    return query.watch();
  }

  Stream<List<Mission>> watchUpcoming({required int startUtcMs}) {
    final query = _database.select(_database.missions)
      ..where(
        (table) =>
            table.scheduledAt.isBiggerOrEqualValue(startUtcMs) &
            table.archivedAt.isNull(),
      )
      ..orderBy(<OrderingTerm Function(Missions)>[
        (table) => OrderingTerm.asc(table.scheduledAt),
        (table) => OrderingTerm.asc(table.id),
      ]);
    return query.watch();
  }

  Stream<List<Mission>> watchAll() {
    final query = _database.select(_database.missions)
      ..where((table) => table.archivedAt.isNull())
      ..orderBy(<OrderingTerm Function(Missions)>[
        (table) => OrderingTerm.desc(table.scheduledAt),
        (table) => OrderingTerm.desc(table.id),
      ]);
    return query.watch();
  }

  Future<MissionAggregate> getAggregate(String missionId) {
    return _database.transaction(() => _getAggregate(missionId));
  }

  Future<MissionAggregate?> findActiveTimerAggregate() {
    return _database.transaction(() async {
      final TimeEntry? timer =
          await (_database.select(_database.timeEntries)
                ..where(
                  (table) =>
                      table.source.equals('TIMER') &
                      table.segmentType.equals('WORK') &
                      table.endedAt.isNull(),
                )
                ..limit(1))
              .getSingleOrNull();
      return timer == null ? null : _getAggregate(timer.missionId);
    });
  }

  Future<MissionAggregate> _getAggregate(String missionId) async {
    final mission = await findById(missionId);
    if (mission == null) {
      throw RecordNotFoundException(table: 'missions', key: missionId);
    }

    final objectives =
        await (_database.select(_database.missionObjectives)
              ..where((table) => table.missionId.equals(missionId))
              ..orderBy(<OrderingTerm Function(MissionObjectives)>[
                (table) => OrderingTerm.asc(table.position),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    final timeEntries =
        await (_database.select(_database.timeEntries)
              ..where((table) => table.missionId.equals(missionId))
              ..orderBy(<OrderingTerm Function(TimeEntries)>[
                (table) => OrderingTerm.asc(table.startedAt),
                (table) => OrderingTerm.asc(table.createdAt),
              ]))
            .get();
    final events =
        await (_database.select(_database.missionEvents)
              ..where((table) => table.missionId.equals(missionId))
              ..orderBy(<OrderingTerm Function(MissionEvents)>[
                (table) => OrderingTerm.asc(table.occurredAt),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    final notifications =
        await (_database.select(_database.notificationSchedules)
              ..where((table) => table.missionId.equals(missionId))
              ..orderBy(<OrderingTerm Function(NotificationSchedules)>[
                (table) => OrderingTerm.asc(table.notifyAt),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();

    return MissionAggregate(
      mission: mission,
      objectives: objectives,
      timeEntries: timeEntries,
      events: events,
      notifications: notifications,
    );
  }

  Future<MissionAggregate> insertAggregate({
    required MissionsCompanion mission,
    Iterable<MissionObjectivesCompanion> objectives =
        const <MissionObjectivesCompanion>[],
    Iterable<MissionEventsCompanion> events = const <MissionEventsCompanion>[],
    Iterable<NotificationSchedulesCompanion> notifications =
        const <NotificationSchedulesCompanion>[],
  }) {
    if (!mission.id.present) {
      throw ArgumentError('Mission id must be present.');
    }
    final missionId = mission.id.value;

    return _database.transaction(() async {
      await _database.into(_database.missions).insert(mission);
      for (final objective in objectives) {
        _requireMissionId(objective.missionId, missionId, 'objective');
        await _database.into(_database.missionObjectives).insert(objective);
      }
      for (final event in events) {
        _requireMissionId(event.missionId, missionId, 'event');
        await _database.into(_database.missionEvents).insert(event);
      }
      for (final notification in notifications) {
        _requireMissionId(notification.missionId, missionId, 'notification');
        await _database
            .into(_database.notificationSchedules)
            .insert(notification);
      }
      return _getAggregate(missionId);
    });
  }

  Future<Mission> updateWithRowVersion({
    required String missionId,
    required int expectedRowVersion,
    required MissionsCompanion changes,
    bool allowPlanningStatus = false,
  }) async {
    if (expectedRowVersion < 1) {
      throw ArgumentError.value(expectedRowVersion, 'expectedRowVersion');
    }
    final bool validPlanningStatus =
        allowPlanningStatus &&
        changes.status.present &&
        const <String>{'SCHEDULED', 'AVAILABLE'}.contains(changes.status.value);
    if (changes.id.present ||
        changes.rowVersion.present ||
        (changes.status.present && !validPlanningStatus) ||
        changes.completedAt.present) {
      throw ArgumentError(
        'id, row_version and completed_at are controlled by MissionDao. '
        'status only accepts planning transitions inside aggregate updates.',
      );
    }

    final affected =
        await (_database.update(_database.missions)..where(
              (table) =>
                  table.id.equals(missionId) &
                  table.rowVersion.equals(expectedRowVersion),
            ))
            .write(
              changes.copyWith(rowVersion: Value<int>(expectedRowVersion + 1)),
            );
    if (affected != 1) {
      throw OptimisticLockException(
        table: 'missions',
        id: missionId,
        expectedRowVersion: expectedRowVersion,
      );
    }

    final updated = await findById(missionId);
    if (updated == null) {
      throw RecordNotFoundException(table: 'missions', key: missionId);
    }
    return updated;
  }

  Future<MissionAggregate> updateAggregate({
    required String missionId,
    required int expectedRowVersion,
    required MissionsCompanion changes,
    required Iterable<MissionObjectivesCompanion> objectives,
    required MissionEventsCompanion event,
    required Map<String, NotificationSchedulesCompanion?> notificationIntents,
    required int notificationUpdatedAtUtcMs,
  }) {
    _requireMissionId(event.missionId, missionId, 'event');
    if (!event.id.present ||
        !event.eventType.present ||
        event.eventType.value != 'UPDATED' ||
        !event.occurredAt.present) {
      throw ArgumentError(
        'Update event must include id, UPDATED type and occurred_at.',
      );
    }

    return _database.transaction(() async {
      await updateWithRowVersion(
        missionId: missionId,
        expectedRowVersion: expectedRowVersion,
        changes: changes,
        allowPlanningStatus: true,
      );

      await (_database.delete(
        _database.missionObjectives,
      )..where((table) => table.missionId.equals(missionId))).go();
      for (final objective in objectives) {
        _requireMissionId(objective.missionId, missionId, 'objective');
        await _database.into(_database.missionObjectives).insert(objective);
      }
      await _database.into(_database.missionEvents).insert(event);
      await _replaceNotificationIntents(
        missionId: missionId,
        replacements: notificationIntents,
        updatedAtUtcMs: notificationUpdatedAtUtcMs,
      );
      return _getAggregate(missionId);
    });
  }

  Future<void> _replaceNotificationIntents({
    required String missionId,
    required Map<String, NotificationSchedulesCompanion?> replacements,
    required int updatedAtUtcMs,
  }) async {
    // Solo se tocan los tipos que esta llamada gestiona. Antes se cancelaba
    // cualquier intención abierta de la misión, lo cual era equivalente cuando
    // START era el único tipo emitido; con el aviso de vencimiento ya no lo es.
    final List<String> managedTypes = replacements.keys.toList();
    final Map<String, NotificationSchedule> matching =
        <String, NotificationSchedule>{};

    for (final MapEntry<String, NotificationSchedulesCompanion?> entry
        in replacements.entries) {
      final NotificationSchedulesCompanion? replacement = entry.value;
      if (replacement == null) {
        continue;
      }
      _requireMissionId(replacement.missionId, missionId, 'notification');
      if (!replacement.id.present ||
          !replacement.notificationType.present ||
          replacement.notificationType.value != entry.key ||
          !replacement.notifyAt.present ||
          !replacement.status.present ||
          replacement.status.value != 'PENDING') {
        throw ArgumentError(
          '${entry.key} notification replacement is incomplete.',
        );
      }
      final NotificationSchedule? existing =
          await (_database.select(_database.notificationSchedules)..where(
                (table) =>
                    table.missionId.equals(missionId) &
                    table.notificationType.equals(entry.key) &
                    table.notifyAt.equals(replacement.notifyAt.value),
              ))
              .getSingleOrNull();
      if (existing != null) {
        matching[entry.key] = existing;
      }
    }

    final List<String> keepIds = <String>[
      for (final NotificationSchedule row in matching.values) row.id,
    ];
    await (_database.update(_database.notificationSchedules)..where((table) {
          var predicate =
              table.missionId.equals(missionId) &
              table.status.isIn(const <String>{'PENDING', 'SCHEDULED'}) &
              table.notificationType.isIn(managedTypes);
          if (keepIds.isNotEmpty) {
            predicate = predicate & table.id.isIn(keepIds).not();
          }
          return predicate;
        }))
        .write(
          NotificationSchedulesCompanion(
            status: const Value<String>('CANCELLED'),
            updatedAt: Value<int>(updatedAtUtcMs),
          ),
        );

    for (final MapEntry<String, NotificationSchedulesCompanion?> entry
        in replacements.entries) {
      final NotificationSchedulesCompanion? replacement = entry.value;
      if (replacement == null) {
        continue;
      }
      final NotificationSchedule? existing = matching[entry.key];
      if (existing == null) {
        await _database
            .into(_database.notificationSchedules)
            .insert(replacement);
        continue;
      }
      if (!const <String>{'PENDING', 'SCHEDULED'}.contains(existing.status)) {
        await (_database.update(
          _database.notificationSchedules,
        )..where((table) => table.id.equals(existing.id))).write(
          NotificationSchedulesCompanion(
            status: const Value<String>('PENDING'),
            systemNotificationId: const Value<int?>(null),
            updatedAt: Value<int>(updatedAtUtcMs),
          ),
        );
      }
    }
  }

  Future<MissionAggregate> startWorkTimer({
    required String missionId,
    required int expectedRowVersion,
    required String expectedStatus,
    required TimeEntriesCompanion timeEntry,
    required MissionEventsCompanion event,
  }) {
    if (!const <String>{
      'SCHEDULED',
      'AVAILABLE',
      'RESCHEDULED',
      'PAUSED',
    }.contains(expectedStatus)) {
      throw ArgumentError.value(expectedStatus, 'expectedStatus');
    }
    _requireMissionId(timeEntry.missionId, missionId, 'time entry');
    _requireMissionId(event.missionId, missionId, 'event');
    final String expectedEventType = expectedStatus == 'PAUSED'
        ? 'RESUMED'
        : 'STARTED';
    if (!timeEntry.id.present ||
        !timeEntry.source.present ||
        timeEntry.source.value != 'TIMER' ||
        !timeEntry.segmentType.present ||
        timeEntry.segmentType.value != 'WORK' ||
        !timeEntry.startedAt.present ||
        timeEntry.endedAt.present ||
        !timeEntry.durationSeconds.present ||
        timeEntry.durationSeconds.value != 0 ||
        !timeEntry.createdAt.present ||
        !event.eventType.present ||
        event.eventType.value != expectedEventType) {
      throw ArgumentError(
        'A work timer requires an open TIMER/WORK entry and a matching event.',
      );
    }
    _validateTransitionEvent(
      event: event,
      missionId: missionId,
      expectedStatus: expectedStatus,
      nextStatus: 'ACTIVE',
    );

    return _database.transaction(() async {
      final TimeEntry? activeTimer =
          await (_database.select(_database.timeEntries)
                ..where(
                  (table) =>
                      table.source.equals('TIMER') &
                      table.segmentType.equals('WORK') &
                      table.endedAt.isNull(),
                )
                ..limit(1))
              .getSingleOrNull();
      if (activeTimer != null) {
        throw ActiveTimerConflictException(
          activeMissionId: activeTimer.missionId,
        );
      }

      final int affected =
          await (_database.update(_database.missions)..where(
                (table) =>
                    table.id.equals(missionId) &
                    table.rowVersion.equals(expectedRowVersion) &
                    table.status.equals(expectedStatus),
              ))
              .write(
                MissionsCompanion(
                  status: const Value<String>('ACTIVE'),
                  rowVersion: Value<int>(expectedRowVersion + 1),
                ),
              );
      if (affected != 1) {
        throw OptimisticLockException(
          table: 'missions',
          id: missionId,
          expectedRowVersion: expectedRowVersion,
        );
      }

      await _database.into(_database.timeEntries).insert(timeEntry);
      await _database.into(_database.missionEvents).insert(event);
      return _getAggregate(missionId);
    });
  }

  Future<MissionAggregate> pauseWorkTimer({
    required String missionId,
    required int expectedRowVersion,
    required int occurredAtUtcMs,
    required MissionEventsCompanion event,
  }) {
    _validateTransitionEvent(
      event: event,
      missionId: missionId,
      expectedStatus: 'ACTIVE',
      nextStatus: 'PAUSED',
    );

    return _database.transaction(() async {
      final TimeEntry? openEntry =
          await (_database.select(_database.timeEntries)..where(
                (table) =>
                    table.missionId.equals(missionId) &
                    table.source.equals('TIMER') &
                    table.segmentType.equals('WORK') &
                    table.endedAt.isNull(),
              ))
              .getSingleOrNull();
      if (openEntry?.startedAt == null) {
        throw const DatabaseInvariantException(
          'An ACTIVE mission must have one open TIMER/WORK entry.',
        );
      }

      final int safeEndedAt = occurredAtUtcMs < openEntry!.startedAt!
          ? openEntry.startedAt!
          : occurredAtUtcMs;
      final int durationSeconds = (safeEndedAt - openEntry.startedAt!) ~/ 1000;
      final int closed =
          await (_database.update(_database.timeEntries)..where(
                (table) =>
                    table.id.equals(openEntry.id) & table.endedAt.isNull(),
              ))
              .write(
                TimeEntriesCompanion(
                  endedAt: Value<int?>(safeEndedAt),
                  durationSeconds: Value<int>(durationSeconds),
                ),
              );
      if (closed != 1) {
        throw OptimisticLockException(
          table: 'time_entries',
          id: openEntry.id,
          expectedRowVersion: expectedRowVersion,
        );
      }

      final int affected =
          await (_database.update(_database.missions)..where(
                (table) =>
                    table.id.equals(missionId) &
                    table.rowVersion.equals(expectedRowVersion) &
                    table.status.equals('ACTIVE'),
              ))
              .write(
                MissionsCompanion(
                  status: const Value<String>('PAUSED'),
                  rowVersion: Value<int>(expectedRowVersion + 1),
                ),
              );
      if (affected != 1) {
        throw OptimisticLockException(
          table: 'missions',
          id: missionId,
          expectedRowVersion: expectedRowVersion,
        );
      }

      await _database.into(_database.missionEvents).insert(event);
      return _getAggregate(missionId);
    });
  }

  Future<MissionAggregate> switchWorkTimer({
    required String activeMissionId,
    required int activeRowVersion,
    required MissionEventsCompanion pauseEvent,
    required int occurredAtUtcMs,
    required String targetMissionId,
    required int targetRowVersion,
    required String targetStatus,
    required TimeEntriesCompanion targetTimeEntry,
    required MissionEventsCompanion startEvent,
  }) {
    if (activeMissionId == targetMissionId) {
      throw ArgumentError('Active and target missions must be different.');
    }
    return _database.transaction(() async {
      await pauseWorkTimer(
        missionId: activeMissionId,
        expectedRowVersion: activeRowVersion,
        occurredAtUtcMs: occurredAtUtcMs,
        event: pauseEvent,
      );
      return startWorkTimer(
        missionId: targetMissionId,
        expectedRowVersion: targetRowVersion,
        expectedStatus: targetStatus,
        timeEntry: targetTimeEntry,
        event: startEvent,
      );
    });
  }

  Future<Mission> transitionStatusWithEvent({
    required String missionId,
    required int expectedRowVersion,
    required String expectedStatus,
    required String nextStatus,
    required Value<int?> completedAt,
    required MissionEventsCompanion event,
    Value<String?> actualResult = const Value<String?>.absent(),
    Value<String?> convenienceRating = const Value<String?>.absent(),
  }) {
    if (expectedRowVersion < 1) {
      throw ArgumentError.value(expectedRowVersion, 'expectedRowVersion');
    }
    _validateTransitionEvent(
      event: event,
      missionId: missionId,
      expectedStatus: expectedStatus,
      nextStatus: nextStatus,
    );

    return _database.transaction(() async {
      final affected =
          await (_database.update(_database.missions)..where(
                (table) =>
                    table.id.equals(missionId) &
                    table.rowVersion.equals(expectedRowVersion) &
                    table.status.equals(expectedStatus),
              ))
              .write(
                MissionsCompanion(
                  status: Value<String>(nextStatus),
                  completedAt: completedAt,
                  actualResult: actualResult,
                  convenienceRating: convenienceRating,
                  rowVersion: Value<int>(expectedRowVersion + 1),
                ),
              );
      if (affected != 1) {
        throw OptimisticLockException(
          table: 'missions',
          id: missionId,
          expectedRowVersion: expectedRowVersion,
        );
      }

      await _database.into(_database.missionEvents).insert(event);
      final updated = await findById(missionId);
      if (updated == null) {
        throw RecordNotFoundException(table: 'missions', key: missionId);
      }
      return updated;
    });
  }

  Future<Mission> archiveWithRowVersion({
    required String missionId,
    required int expectedRowVersion,
    required int archivedAtUtcMs,
  }) {
    return updateWithRowVersion(
      missionId: missionId,
      expectedRowVersion: expectedRowVersion,
      changes: MissionsCompanion(archivedAt: Value<int>(archivedAtUtcMs)),
    );
  }

  Future<MissionAggregate> archiveAggregate({
    required String missionId,
    required int expectedRowVersion,
    required int archivedAtUtcMs,
    required MissionEventsCompanion event,
  }) {
    _requireMissionId(event.missionId, missionId, 'event');
    if (!event.id.present ||
        !event.eventType.present ||
        event.eventType.value != 'ARCHIVED' ||
        !event.occurredAt.present) {
      throw ArgumentError(
        'Archive event must include id, ARCHIVED type and occurred_at.',
      );
    }
    return _database.transaction(() async {
      final mission = await findById(missionId);
      if (mission == null) {
        throw RecordNotFoundException(table: 'missions', key: missionId);
      }
      if (mission.archivedAt != null || mission.status == 'ACTIVE') {
        throw const DatabaseInvariantException(
          'An archived or active mission cannot be archived.',
        );
      }
      final openTimer =
          await (_database.selectOnly(_database.timeEntries)
                ..addColumns(<Expression<Object>>[_database.timeEntries.id])
                ..where(
                  _database.timeEntries.missionId.equals(missionId) &
                      _database.timeEntries.source.equals('TIMER') &
                      _database.timeEntries.segmentType.equals('WORK') &
                      _database.timeEntries.endedAt.isNull(),
                )
                ..limit(1))
              .getSingleOrNull();
      if (openTimer != null) {
        throw const DatabaseInvariantException(
          'A mission with an open timer cannot be archived.',
        );
      }

      await updateWithRowVersion(
        missionId: missionId,
        expectedRowVersion: expectedRowVersion,
        changes: MissionsCompanion(archivedAt: Value<int>(archivedAtUtcMs)),
      );
      await _database.into(_database.missionEvents).insert(event);
      await (_database.update(_database.notificationSchedules)..where(
            (table) =>
                table.missionId.equals(missionId) &
                table.status.isIn(const <String>{'PENDING', 'SCHEDULED'}),
          ))
          .write(
            NotificationSchedulesCompanion(
              status: const Value<String>('CANCELLED'),
              updatedAt: Value<int>(archivedAtUtcMs),
            ),
          );
      return _getAggregate(missionId);
    });
  }

  Future<void> appendEvent(MissionEventsCompanion event) async {
    await _database.into(_database.missionEvents).insert(event);
  }

  Future<void> appendTimeEntry(TimeEntriesCompanion entry) async {
    await _database.into(_database.timeEntries).insert(entry);
  }

  Future<void> deleteDraftAggregate(String missionId) {
    return _database.transaction(() async {
      final mission = await findById(missionId);
      if (mission == null) {
        return;
      }
      if (mission.status != 'DRAFT') {
        throw const DatabaseInvariantException(
          'Only a DRAFT mission may be physically deleted.',
        );
      }

      final history = await _database
          .customSelect(
            '''
              SELECT EXISTS(
                SELECT 1 FROM mission_events WHERE mission_id = ?
                UNION ALL
                SELECT 1 FROM time_entries WHERE mission_id = ?
                UNION ALL
                SELECT 1 FROM transactions WHERE mission_id = ?
                UNION ALL
                SELECT 1 FROM journal_entries WHERE mission_id = ?
                UNION ALL
                SELECT 1 FROM xp_transactions WHERE mission_id = ?
                LIMIT 1
              ) AS has_history
            ''',
            variables: <Variable<Object>>[
              for (var index = 0; index < 5; index++)
                Variable<String>(missionId),
            ],
            readsFrom: <ResultSetImplementation<Table, Object?>>{
              _database.missionEvents,
              _database.timeEntries,
              _database.transactions,
              _database.journalEntries,
              _database.xpTransactions,
            },
          )
          .getSingle();
      if (history.read<int>('has_history') != 0) {
        throw const DatabaseInvariantException(
          'A DRAFT mission with historical events, time, economy, journal or '
          'XP records cannot be physically deleted.',
        );
      }

      final openNotification =
          await (_database.selectOnly(_database.notificationSchedules)
                ..addColumns(<Expression<Object>>[
                  _database.notificationSchedules.id,
                ])
                ..where(
                  _database.notificationSchedules.missionId.equals(missionId) &
                      _database.notificationSchedules.status.isIn(
                        const <String>{'PENDING', 'SCHEDULED'},
                      ),
                )
                ..limit(1))
              .getSingleOrNull();
      if (openNotification != null) {
        throw const DatabaseInvariantException(
          'Open notifications must be cancelled before deleting a DRAFT '
          'mission.',
        );
      }

      await (_database.delete(
        _database.notificationSchedules,
      )..where((table) => table.missionId.equals(missionId))).go();
      await (_database.delete(
        _database.missionObjectives,
      )..where((table) => table.missionId.equals(missionId))).go();
      final deleted = await (_database.delete(
        _database.missions,
      )..where((table) => table.id.equals(missionId))).go();
      if (deleted != 1) {
        throw RecordNotFoundException(table: 'missions', key: missionId);
      }
    });
  }

  void _requireMissionId(
    Value<String> actual,
    String expected,
    String childName,
  ) {
    if (!actual.present || actual.value != expected) {
      throw ArgumentError('$childName must reference mission $expected.');
    }
  }

  void _validateTransitionEvent({
    required MissionEventsCompanion event,
    required String missionId,
    required String expectedStatus,
    required String nextStatus,
  }) {
    _requireMissionId(event.missionId, missionId, 'event');
    if (!event.id.present ||
        !event.eventType.present ||
        !event.occurredAt.present ||
        !event.fromStatus.present ||
        event.fromStatus.value != expectedStatus ||
        !event.toStatus.present ||
        event.toStatus.value != nextStatus) {
      throw ArgumentError(
        'Transition event must include id, type, time and matching statuses.',
      );
    }
  }
}
