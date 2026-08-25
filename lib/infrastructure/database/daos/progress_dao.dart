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
