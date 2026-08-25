import 'package:drift/drift.dart';

import '../app_database.dart';
import 'dao_support.dart';

final class NotificationDao {
  NotificationDao(this._database);

  final AppDatabase _database;

  Stream<List<NotificationSchedule>> watchDue({
    required int throughUtcMs,
    Set<String> statuses = const <String>{'PENDING', 'SCHEDULED'},
  }) {
    if (statuses.isEmpty) {
      return Stream<List<NotificationSchedule>>.value(
        const <NotificationSchedule>[],
      );
    }
    final query = _database.select(_database.notificationSchedules)
      ..where(
        (table) =>
            table.status.isIn(statuses) &
            table.notifyAt.isSmallerOrEqualValue(throughUtcMs),
      )
      ..orderBy(<OrderingTerm Function(NotificationSchedules)>[
        (table) => OrderingTerm.asc(table.notifyAt),
        (table) => OrderingTerm.asc(table.id),
      ]);
    return query.watch();
  }

  Future<List<NotificationSchedule>> findForMission(String missionId) {
    return (_database.select(_database.notificationSchedules)
          ..where((table) => table.missionId.equals(missionId))
          ..orderBy(<OrderingTerm Function(NotificationSchedules)>[
            (table) => OrderingTerm.asc(table.notifyAt),
            (table) => OrderingTerm.asc(table.id),
          ]))
        .get();
  }

  Future<DaoWriteResult<NotificationSchedule>> scheduleIfAbsent(
    NotificationSchedulesCompanion schedule,
  ) {
    if (!schedule.missionId.present ||
        !schedule.notificationType.present ||
        !schedule.notifyAt.present) {
      throw ArgumentError(
        'Schedule requires mission_id, notification_type and notify_at.',
      );
    }

    return _database.transaction(() async {
      final inserted = await _database
          .into(_database.notificationSchedules)
          .insertReturningOrNull(schedule, mode: InsertMode.insertOrIgnore);
      if (inserted != null) {
        return DaoWriteResult<NotificationSchedule>(
          value: inserted,
          created: true,
        );
      }

      final existing =
          await (_database.select(_database.notificationSchedules)..where(
                (table) =>
                    table.missionId.equals(schedule.missionId.value) &
                    table.notificationType.equals(
                      schedule.notificationType.value,
                    ) &
                    table.notifyAt.equals(schedule.notifyAt.value),
              ))
              .getSingleOrNull();
      if (existing == null) {
        throw IdempotencyConflictException(
          operationId:
              '${schedule.missionId.value}/'
              '${schedule.notificationType.value}@${schedule.notifyAt.value}',
          entity: 'notification schedule',
        );
      }
      return DaoWriteResult<NotificationSchedule>(
        value: existing,
        created: false,
      );
    });
  }

  Future<NotificationSchedule> transitionStatus({
    required String scheduleId,
    required Set<String> allowedCurrentStatuses,
    required String nextStatus,
    required int updatedAtUtcMs,
    Value<int?> systemNotificationId = const Value<int?>.absent(),
  }) async {
    if (allowedCurrentStatuses.isEmpty) {
      throw ArgumentError.value(
        allowedCurrentStatuses,
        'allowedCurrentStatuses',
        'Must not be empty.',
      );
    }

    final affected =
        await (_database.update(_database.notificationSchedules)..where(
              (table) =>
                  table.id.equals(scheduleId) &
                  table.status.isIn(allowedCurrentStatuses),
            ))
            .write(
              NotificationSchedulesCompanion(
                status: Value<String>(nextStatus),
                systemNotificationId: systemNotificationId,
                updatedAt: Value<int>(updatedAtUtcMs),
              ),
            );
    if (affected != 1) {
      throw const DatabaseInvariantException(
        'Notification status transition rejected.',
      );
    }

    final updated = await (_database.select(
      _database.notificationSchedules,
    )..where((table) => table.id.equals(scheduleId))).getSingleOrNull();
    if (updated == null) {
      throw RecordNotFoundException(
        table: 'notification_schedules',
        key: scheduleId,
      );
    }
    return updated;
  }

  Future<int> cancelPendingForMission({
    required String missionId,
    required int updatedAtUtcMs,
  }) {
    return _database.transaction(() async {
      return (_database.update(_database.notificationSchedules)..where(
            (table) =>
                table.missionId.equals(missionId) &
                table.status.isIn(const <String>{'PENDING', 'SCHEDULED'}),
          ))
          .write(
            NotificationSchedulesCompanion(
              status: const Value<String>('CANCELLED'),
              systemNotificationId: const Value<int?>(null),
              updatedAt: Value<int>(updatedAtUtcMs),
            ),
          );
    });
  }

  Future<int> deleteForDraftMission(String missionId) {
    return _database.transaction(() async {
      final mission = await (_database.select(
        _database.missions,
      )..where((table) => table.id.equals(missionId))).getSingleOrNull();
      if (mission == null) {
        throw RecordNotFoundException(table: 'missions', key: missionId);
      }
      if (mission.status != 'DRAFT') {
        throw const DatabaseInvariantException(
          'Notification schedules can only be deleted for a DRAFT mission.',
        );
      }

      final openSchedule =
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
      if (openSchedule != null) {
        throw const DatabaseInvariantException(
          'Open notification schedules must reach a terminal status before '
          'physical deletion.',
        );
      }

      return (_database.delete(
        _database.notificationSchedules,
      )..where((table) => table.missionId.equals(missionId))).go();
    });
  }
}
