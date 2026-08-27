import 'package:drift/drift.dart';

import '../app_database.dart';

final class DailyCloseMissionRow {
  const DailyCloseMissionRow({
    required this.id,
    required this.title,
    required this.status,
  });

  final String id;
  final String title;
  final String status;
}

final class DailyCloseData {
  const DailyCloseData({
    required this.completedMissions,
    required this.requiredPendingMissions,
    required this.xpEarned,
    required this.workSeconds,
    required this.incomeMinor,
    required this.expenseMinor,
    this.mainAreaName,
  });

  final List<DailyCloseMissionRow> completedMissions;
  final List<DailyCloseMissionRow> requiredPendingMissions;
  final int xpEarned;
  final int workSeconds;
  final int incomeMinor;
  final int expenseMinor;
  final String? mainAreaName;
}

final class DailyCloseDao {
  const DailyCloseDao(this._database);

  final AppDatabase _database;

  Future<DailyCloseData> load({
    required int dayStartUtcMs,
    required int dayEndUtcMs,
    required int referenceUtcMs,
  }) {
    if (dayEndUtcMs <= dayStartUtcMs) {
      throw ArgumentError.value(dayEndUtcMs, 'dayEndUtcMs');
    }
    final int effectiveReference = referenceUtcMs.clamp(
      dayStartUtcMs,
      dayEndUtcMs,
    );
    return _database.transaction(() async {
      final completed =
          await (_database.select(_database.missions)
                ..where(
                  (table) =>
                      table.completedAt.isBiggerOrEqualValue(dayStartUtcMs) &
                      table.completedAt.isSmallerThanValue(dayEndUtcMs) &
                      table.status.isIn(const <String>{'COMPLETED', 'PARTIAL'}),
                )
                ..orderBy(<OrderingTerm Function(Missions)>[
                  (table) => OrderingTerm.asc(table.completedAt),
                  (table) => OrderingTerm.asc(table.id),
                ]))
              .get();
      final pending =
          await (_database.select(_database.missions)
                ..where(
                  (table) =>
                      table.scheduledAt.isBiggerOrEqualValue(dayStartUtcMs) &
                      table.scheduledAt.isSmallerThanValue(dayEndUtcMs) &
                      table.isRequired.equals(1) &
                      table.archivedAt.isNull() &
                      table.status.isNotIn(const <String>{
                        'COMPLETED',
                        'PARTIAL',
                        'CANCELLED',
                        'ABANDONED',
                      }),
                )
                ..orderBy(<OrderingTerm Function(Missions)>[
                  (table) => OrderingTerm.asc(table.scheduledAt),
                  (table) => OrderingTerm.asc(table.id),
                ]))
              .get();
      final totals = await _database
          .customSelect(
            '''
          SELECT
            COALESCE((
              SELECT SUM(amount)
              FROM xp_transactions
              WHERE occurred_at >= ? AND occurred_at < ?
            ), 0) AS xp_earned,
            COALESCE((
              SELECT SUM(
                CASE
                  WHEN source = 'MANUAL' THEN duration_seconds
                  ELSE MAX(
                    0,
                    MIN(COALESCE(ended_at, ?), ?) - MAX(started_at, ?)
                  ) / 1000
                END
              )
              FROM time_entries
              WHERE segment_type = 'WORK'
                AND (
                  (source = 'MANUAL' AND created_at >= ? AND created_at < ?)
                  OR
                  (source = 'TIMER' AND started_at < ?
                    AND COALESCE(ended_at, ?) > ?)
                )
            ), 0) AS work_seconds,
            COALESCE(SUM(
              CASE WHEN transaction_type IN (
                'INCOME', 'REFUND', 'ADJUSTMENT_CREDIT'
              ) THEN amount_minor ELSE 0 END
            ), 0) AS income_minor,
            COALESCE(SUM(
              CASE WHEN transaction_type IN (
                'EXPENSE', 'ADJUSTMENT_DEBIT'
              ) THEN amount_minor ELSE 0 END
            ), 0) AS expense_minor
          FROM transactions
          WHERE occurred_at >= ? AND occurred_at < ?
        ''',
            variables: <Variable<Object>>[
              Variable<int>(dayStartUtcMs),
              Variable<int>(dayEndUtcMs),
              Variable<int>(effectiveReference),
              Variable<int>(dayEndUtcMs),
              Variable<int>(dayStartUtcMs),
              Variable<int>(dayStartUtcMs),
              Variable<int>(dayEndUtcMs),
              Variable<int>(dayEndUtcMs),
              Variable<int>(effectiveReference),
              Variable<int>(dayStartUtcMs),
              Variable<int>(dayStartUtcMs),
              Variable<int>(dayEndUtcMs),
            ],
            readsFrom: <ResultSetImplementation<Table, Object?>>{
              _database.xpTransactions,
              _database.timeEntries,
              _database.transactions,
            },
          )
          .getSingle();
      final mainArea = await _database
          .customSelect(
            '''
          SELECT area.name
          FROM xp_transactions AS xp
          INNER JOIN life_areas AS area ON area.id = xp.area_id
          WHERE xp.occurred_at >= ? AND xp.occurred_at < ?
          GROUP BY area.id, area.name
          ORDER BY SUM(xp.amount) DESC, area.name ASC
          LIMIT 1
        ''',
            variables: <Variable<Object>>[
              Variable<int>(dayStartUtcMs),
              Variable<int>(dayEndUtcMs),
            ],
            readsFrom: <ResultSetImplementation<Table, Object?>>{
              _database.xpTransactions,
              _database.lifeAreas,
            },
          )
          .getSingleOrNull();
      return DailyCloseData(
        completedMissions: completed
            .map(
              (mission) => DailyCloseMissionRow(
                id: mission.id,
                title: mission.title,
                status: mission.status,
              ),
            )
            .toList(growable: false),
        requiredPendingMissions: pending
            .map(
              (mission) => DailyCloseMissionRow(
                id: mission.id,
                title: mission.title,
                status: mission.status,
              ),
            )
            .toList(growable: false),
        xpEarned: totals.read<int>('xp_earned'),
        workSeconds: totals.read<int>('work_seconds'),
        incomeMinor: totals.read<int>('income_minor'),
        expenseMinor: totals.read<int>('expense_minor'),
        mainAreaName: mainArea?.read<String>('name'),
      );
    });
  }
}
