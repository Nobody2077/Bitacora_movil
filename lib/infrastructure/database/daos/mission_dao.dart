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

  Future<MissionAggregate> getAggregate(String missionId) {
    return _database.transaction(() => _getAggregate(missionId));
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
      return _getAggregate(missionId);
    });
  }

  Future<Mission> updateWithRowVersion({
    required String missionId,
    required int expectedRowVersion,
    required MissionsCompanion changes,
  }) async {
    if (expectedRowVersion < 1) {
      throw ArgumentError.value(expectedRowVersion, 'expectedRowVersion');
    }
    if (changes.id.present ||
        changes.rowVersion.present ||
        changes.status.present ||
        changes.completedAt.present) {
      throw ArgumentError(
        'id, row_version, status and completed_at are controlled by MissionDao. '
        'Use transitionStatusWithEvent for state changes.',
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
