import 'package:drift/drift.dart';

import '../app_database.dart';
import 'dao_support.dart';

final class XpWriteInput {
  const XpWriteInput({
    required this.id,
    required this.areaId,
    required this.sourceType,
    required this.amount,
    required this.occurredAtUtcMs,
    this.missionId,
    this.journalEntryId,
    this.reason,
  });

  final String id;
  final String areaId;
  final String? missionId;
  final String? journalEntryId;
  final String sourceType;
  final int amount;
  final String? reason;
  final int occurredAtUtcMs;

  XpTransactionsCompanion toCompanion() => XpTransactionsCompanion.insert(
    id: id,
    areaId: areaId,
    missionId: Value<String?>(missionId),
    journalEntryId: Value<String?>(journalEntryId),
    sourceType: sourceType,
    amount: amount,
    reason: Value<String?>(reason),
    occurredAt: occurredAtUtcMs,
  );
}

final class XpTotals {
  const XpTotals({required this.rawTotal, required this.periodTotal});

  final int rawTotal;
  final int periodTotal;

  int get effectiveTotal => rawTotal < 0 ? 0 : rawTotal;
  int get effectivePeriodTotal => periodTotal < 0 ? 0 : periodTotal;
}

final class AreaXpTotal {
  const AreaXpTotal({required this.areaId, required this.rawTotal});

  final String areaId;
  final int rawTotal;

  int get effectiveTotal => rawTotal < 0 ? 0 : rawTotal;
}

final class TitleRuleFactsData {
  const TitleRuleFactsData({
    required this.definitions,
    required this.completedHomeMissions,
    required this.completionInstantsUtcMs,
  });

  final List<TitleDefinition> definitions;
  final int completedHomeMissions;
  final List<int> completionInstantsUtcMs;
}

final class TitleStateDecisionInput {
  const TitleStateDecisionInput({
    required this.titleId,
    required this.achieved,
    required this.bestStreak,
  });

  final String titleId;
  final bool achieved;
  final int bestStreak;
}

final class CurrentTitleData {
  const CurrentTitleData({required this.definition, required this.history});

  final TitleDefinition definition;
  final TitleHistoryData history;
}

final class ProgressDao {
  ProgressDao(this._database);

  final AppDatabase _database;

  Future<DaoWriteResult<XpTransaction>> writeMissionXp(XpWriteInput input) {
    if (input.sourceType != 'MISSION' || input.missionId == null) {
      throw ArgumentError(
        'Mission XP requires source_type MISSION and mission_id.',
      );
    }

    return _database.transaction(() async {
      final existing =
          await (_database.select(_database.xpTransactions)..where(
                (table) =>
                    table.sourceType.equals('MISSION') &
                    table.missionId.equals(input.missionId!),
              ))
              .getSingleOrNull();
      if (existing != null) {
        _validateSameMissionXp(existing, input);
        return DaoWriteResult<XpTransaction>(value: existing, created: false);
      }

      final inserted = await _database
          .into(_database.xpTransactions)
          .insertReturningOrNull(
            input.toCompanion(),
            mode: InsertMode.insertOrIgnore,
          );
      if (inserted != null) {
        return DaoWriteResult<XpTransaction>(value: inserted, created: true);
      }

      final raced =
          await (_database.select(_database.xpTransactions)..where(
                (table) =>
                    table.sourceType.equals('MISSION') &
                    table.missionId.equals(input.missionId!),
              ))
              .getSingleOrNull();
      if (raced == null) {
        throw IdempotencyConflictException(
          operationId: input.missionId!,
          entity: 'mission XP',
        );
      }
      _validateSameMissionXp(raced, input);
      return DaoWriteResult<XpTransaction>(value: raced, created: false);
    });
  }

  Future<XpTransaction> insertXp(XpWriteInput input) {
    if (input.sourceType == 'MISSION') {
      throw ArgumentError('Use writeMissionXp for MISSION source.');
    }
    if (input.sourceType == 'JOURNAL' && input.journalEntryId == null) {
      throw ArgumentError('JOURNAL XP requires journal_entry_id.');
    }
    if (input.sourceType == 'MANUAL_ADJUSTMENT' &&
        (input.reason == null || input.reason!.trim().isEmpty)) {
      throw ArgumentError('Manual XP adjustment requires a reason.');
    }
    return _database
        .into(_database.xpTransactions)
        .insertReturning(input.toCompanion());
  }

  Stream<XpTotals> watchTotals({
    required int periodStartUtcMs,
    required int periodEndUtcMs,
  }) {
    if (periodEndUtcMs <= periodStartUtcMs) {
      throw ArgumentError.value(
        periodEndUtcMs,
        'periodEndUtcMs',
        'Must exceed periodStartUtcMs.',
      );
    }
    return _database
        .customSelect(
          '''
            SELECT
              COALESCE(SUM(amount), 0) AS raw_total,
              COALESCE(SUM(
                CASE
                  WHEN occurred_at >= ? AND occurred_at < ? THEN amount
                  ELSE 0
                END
              ), 0) AS period_total
            FROM xp_transactions
          ''',
          variables: <Variable<Object>>[
            Variable<int>(periodStartUtcMs),
            Variable<int>(periodEndUtcMs),
          ],
          readsFrom: <ResultSetImplementation<Table, Object?>>{
            _database.xpTransactions,
          },
        )
        .watchSingle()
        .map(
          (row) => XpTotals(
            rawTotal: row.read<int>('raw_total'),
            periodTotal: row.read<int>('period_total'),
          ),
        );
  }

  Stream<List<AreaXpTotal>> watchAreaTotals() {
    return _database
        .customSelect(
          '''
            SELECT area_id, COALESCE(SUM(amount), 0) AS raw_total
            FROM xp_transactions
            GROUP BY area_id
            ORDER BY raw_total DESC, area_id ASC
          ''',
          readsFrom: <ResultSetImplementation<Table, Object?>>{
            _database.xpTransactions,
          },
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => AreaXpTotal(
                  areaId: row.read<String>('area_id'),
                  rawTotal: row.read<int>('raw_total'),
                ),
              )
              .toList(growable: false),
        );
  }

  Future<TitleRuleFactsData> loadTitleRuleFacts({required String homeAreaId}) {
    return _database.transaction(() async {
      final definitions =
          await (_database.select(_database.titleDefinitions)
                ..where((table) => table.isActive.equals(1))
                ..orderBy(<OrderingTerm Function(TitleDefinitions)>[
                  (table) => OrderingTerm.asc(table.titleKind),
                  (table) => OrderingTerm.asc(table.name),
                ]))
              .get();
      final completionRows = await _database
          .customSelect(
            '''
              SELECT area_id, completed_at
              FROM missions
              WHERE status IN ('COMPLETED', 'PARTIAL')
                AND completed_at IS NOT NULL
              ORDER BY completed_at ASC, id ASC
            ''',
            readsFrom: <ResultSetImplementation<Table, Object?>>{
              _database.missions,
            },
          )
          .get();
      return TitleRuleFactsData(
        definitions: definitions,
        completedHomeMissions: completionRows
            .where((row) => row.read<String>('area_id') == homeAreaId)
            .length,
        completionInstantsUtcMs: completionRows
            .map((row) => row.read<int>('completed_at'))
            .toList(growable: false),
      );
    });
  }

  Future<List<CurrentTitleData>> synchronizeTitleStates({
    required List<TitleStateDecisionInput> decisions,
    required int evaluatedAtUtcMs,
  }) {
    return _database.transaction(() async {
      for (final decision in decisions) {
        final definition =
            await (_database.select(_database.titleDefinitions)..where(
                  (table) =>
                      table.id.equals(decision.titleId) &
                      table.isActive.equals(1),
                ))
                .getSingleOrNull();
        if (definition == null) {
          continue;
        }

        final histories = await (_database.select(
          _database.titleHistory,
        )..where((table) => table.titleId.equals(decision.titleId))).get();
        TitleHistoryData? current;
        for (final history in histories) {
          if (history.deactivatedAt == null &&
              const <String>{'ACTIVE', 'EARNED'}.contains(history.status)) {
            current = history;
            break;
          }
        }
        final int historicalBest = histories.fold<int>(
          0,
          (best, history) =>
              history.bestStreak > best ? history.bestStreak : best,
        );
        final int bestStreak = decision.bestStreak > historicalBest
            ? decision.bestStreak
            : historicalBest;

        if (!decision.achieved) {
          if (current != null && current.status == 'ACTIVE') {
            final int deactivatedAt = evaluatedAtUtcMs < current.activatedAt
                ? current.activatedAt
                : evaluatedAtUtcMs;
            await (_database.update(
              _database.titleHistory,
            )..where((table) => table.id.equals(current!.id))).write(
              TitleHistoryCompanion(
                status: const Value<String>('INACTIVE'),
                deactivatedAt: Value<int?>(deactivatedAt),
                bestStreak: Value<int>(bestStreak),
              ),
            );
          }
          continue;
        }

        final String desiredStatus = definition.titleKind == 'PERMANENT'
            ? 'EARNED'
            : 'ACTIVE';
        if (current != null && current.status == desiredStatus) {
          if (bestStreak > current.bestStreak) {
            await (_database.update(
              _database.titleHistory,
            )..where((table) => table.id.equals(current!.id))).write(
              TitleHistoryCompanion(bestStreak: Value<int>(bestStreak)),
            );
          }
          continue;
        }
        if (current != null && current.status == 'EARNED') {
          continue;
        }
        if (current != null) {
          final int deactivatedAt = evaluatedAtUtcMs < current.activatedAt
              ? current.activatedAt
              : evaluatedAtUtcMs;
          await (_database.update(
            _database.titleHistory,
          )..where((table) => table.id.equals(current!.id))).write(
            TitleHistoryCompanion(
              status: const Value<String>('INACTIVE'),
              deactivatedAt: Value<int?>(deactivatedAt),
              bestStreak: Value<int>(bestStreak),
            ),
          );
        }

        final int previousRecoveryCount = histories.fold<int>(
          0,
          (highest, history) =>
              history.recoveryCount > highest ? history.recoveryCount : highest,
        );
        final int recoveryCount = histories.isEmpty
            ? 0
            : previousRecoveryCount + 1;
        await _database
            .into(_database.titleHistory)
            .insert(
              TitleHistoryCompanion.insert(
                id: 'title-history:${definition.id}:$evaluatedAtUtcMs:$recoveryCount',
                titleId: definition.id,
                status: desiredStatus,
                activatedAt: evaluatedAtUtcMs,
                bestStreak: Value<int>(bestStreak),
                recoveryCount: Value<int>(recoveryCount),
              ),
            );
      }

      return _loadCurrentTitleData();
    });
  }

  Future<List<CurrentTitleData>> _loadCurrentTitleData() async {
    final query = _database.select(_database.titleHistory).join([
      innerJoin(
        _database.titleDefinitions,
        _database.titleDefinitions.id.equalsExp(_database.titleHistory.titleId),
      ),
    ]);
    query
      ..where(
        _database.titleHistory.deactivatedAt.isNull() &
            _database.titleHistory.status.isIn(const <String>{
              'ACTIVE',
              'EARNED',
            }) &
            _database.titleDefinitions.isActive.equals(1),
      )
      ..orderBy(<OrderingTerm>[
        OrderingTerm.desc(_database.titleHistory.activatedAt),
        OrderingTerm.asc(_database.titleDefinitions.name),
      ]);
    final rows = await query.get();
    return rows
        .map(
          (row) => CurrentTitleData(
            definition: row.readTable(_database.titleDefinitions),
            history: row.readTable(_database.titleHistory),
          ),
        )
        .toList(growable: false);
  }

  Stream<void> watchChanges() {
    return _database
        .tableUpdates(
          TableUpdateQuery.onAllTables(
            <ResultSetImplementation<dynamic, dynamic>>[
              _database.lifeAreas,
              _database.missions,
              _database.timeEntries,
              _database.transactions,
              _database.xpTransactions,
              _database.titleDefinitions,
              _database.titleHistory,
            ],
          ),
        )
        .map((_) {});
  }

  Future<TitleDefinition> putTitleDefinition(
    TitleDefinitionsCompanion definition,
  ) async {
    await _database
        .into(_database.titleDefinitions)
        .insertOnConflictUpdate(definition);
    final ruleKey = definition.ruleKey;
    if (!ruleKey.present) {
      throw ArgumentError('Title definition rule_key must be present.');
    }
    final stored = await (_database.select(
      _database.titleDefinitions,
    )..where((table) => table.ruleKey.equals(ruleKey.value))).getSingleOrNull();
    if (stored == null) {
      throw RecordNotFoundException(
        table: 'title_definitions',
        key: ruleKey.value,
      );
    }
    return stored;
  }

  Stream<List<TitleDefinition>> watchActiveTitleDefinitions() {
    return (_database.select(_database.titleDefinitions)
          ..where((table) => table.isActive.equals(1))
          ..orderBy(<OrderingTerm Function(TitleDefinitions)>[
            (table) => OrderingTerm.asc(table.titleKind),
            (table) => OrderingTerm.asc(table.name),
          ]))
        .watch();
  }

  Future<TitleHistoryData> appendTitleHistory(TitleHistoryCompanion history) {
    if (!history.status.present ||
        history.status.value != 'INACTIVE' ||
        !history.deactivatedAt.present ||
        history.deactivatedAt.value == null) {
      throw ArgumentError(
        'appendTitleHistory only accepts closed INACTIVE rows. '
        'Use recordCurrentTitle for ACTIVE or EARNED rows.',
      );
    }
    return _database.into(_database.titleHistory).insertReturning(history);
  }

  Future<TitleHistoryData> recordCurrentTitle({
    required TitleHistoryCompanion history,
    required int replacedAtUtcMs,
  }) {
    if (!history.id.present ||
        !history.titleId.present ||
        !history.status.present ||
        !history.activatedAt.present ||
        (history.deactivatedAt.present &&
            history.deactivatedAt.value != null) ||
        !const <String>{'ACTIVE', 'EARNED'}.contains(history.status.value)) {
      throw ArgumentError(
        'Current title requires id, title_id, activated_at, ACTIVE/EARNED and '
        'no deactivation date.',
      );
    }

    return _database.transaction(() async {
      final existingById = await (_database.select(
        _database.titleHistory,
      )..where((table) => table.id.equals(history.id.value))).getSingleOrNull();
      if (existingById != null) {
        _validateSameCurrentTitle(existingById, history);
        return existingById;
      }

      final current =
          await (_database.select(_database.titleHistory)..where(
                (table) =>
                    table.titleId.equals(history.titleId.value) &
                    table.deactivatedAt.isNull() &
                    table.status.isIn(const <String>{'ACTIVE', 'EARNED'}),
              ))
              .getSingleOrNull();
      if (current != null) {
        if (current.status == 'EARNED') {
          throw const DatabaseInvariantException(
            'An EARNED title cannot be replaced by another current row.',
          );
        }
        final closed =
            await (_database.update(_database.titleHistory)..where(
                  (table) =>
                      table.id.equals(current.id) &
                      table.deactivatedAt.isNull(),
                ))
                .write(
                  TitleHistoryCompanion(
                    status: const Value<String>('INACTIVE'),
                    deactivatedAt: Value<int?>(replacedAtUtcMs),
                  ),
                );
        if (closed != 1) {
          throw const DatabaseInvariantException(
            'Current title changed during replacement.',
          );
        }
      }
      return _database.into(_database.titleHistory).insertReturning(history);
    });
  }

  Future<TitleHistoryData> deactivateCurrentTitle({
    required String titleId,
    required int deactivatedAtUtcMs,
    Value<int> bestStreak = const Value<int>.absent(),
    Value<int> recoveryCount = const Value<int>.absent(),
  }) {
    return _database.transaction(() async {
      final current =
          await (_database.select(_database.titleHistory)..where(
                (table) =>
                    table.titleId.equals(titleId) &
                    table.status.equals('ACTIVE') &
                    table.deactivatedAt.isNull(),
              ))
              .getSingleOrNull();
      if (current == null) {
        throw RecordNotFoundException(
          table: 'title_history.current',
          key: titleId,
        );
      }
      await (_database.update(
        _database.titleHistory,
      )..where((table) => table.id.equals(current.id))).write(
        TitleHistoryCompanion(
          status: const Value<String>('INACTIVE'),
          deactivatedAt: Value<int?>(deactivatedAtUtcMs),
          bestStreak: bestStreak,
          recoveryCount: recoveryCount,
        ),
      );
      return (_database.select(
        _database.titleHistory,
      )..where((table) => table.id.equals(current.id))).getSingle();
    });
  }

  Stream<List<TitleHistoryData>> watchCurrentTitles() {
    return (_database.select(_database.titleHistory)
          ..where(
            (table) =>
                table.status.isIn(const <String>{'ACTIVE', 'EARNED'}) &
                table.deactivatedAt.isNull(),
          )
          ..orderBy(<OrderingTerm Function(TitleHistory)>[
            (table) => OrderingTerm.desc(table.activatedAt),
            (table) => OrderingTerm.asc(table.id),
          ]))
        .watch();
  }

  void _validateSameCurrentTitle(
    TitleHistoryData stored,
    TitleHistoryCompanion requested,
  ) {
    final matches =
        stored.titleId == requested.titleId.value &&
        stored.status == requested.status.value &&
        stored.activatedAt == requested.activatedAt.value &&
        stored.deactivatedAt == null &&
        stored.bestStreak ==
            (requested.bestStreak.present ? requested.bestStreak.value : 0) &&
        stored.recoveryCount ==
            (requested.recoveryCount.present
                ? requested.recoveryCount.value
                : 0);
    if (!matches) {
      throw IdempotencyConflictException(
        operationId: requested.id.value,
        entity: 'current title history',
      );
    }
  }

  void _validateSameMissionXp(XpTransaction stored, XpWriteInput input) {
    final matches =
        stored.id == input.id &&
        stored.areaId == input.areaId &&
        stored.missionId == input.missionId &&
        stored.journalEntryId == input.journalEntryId &&
        stored.amount == input.amount &&
        stored.reason == input.reason &&
        stored.occurredAt == input.occurredAtUtcMs;
    if (!matches) {
      throw IdempotencyConflictException(
        operationId: input.missionId!,
        entity: 'mission XP',
      );
    }
  }
}
