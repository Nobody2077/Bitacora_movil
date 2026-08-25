import 'package:drift/drift.dart';

import '../app_database.dart';
import 'dao_support.dart';

final class LedgerTransactionInput {
  const LedgerTransactionInput({
    required this.id,
    required this.operationId,
    required this.transactionType,
    required this.amountMinor,
    required this.occurredAtUtcMs,
    required this.createdAtUtcMs,
    this.missionId,
    this.relatedTransactionId,
    this.paymentMethod,
    this.category,
    this.note,
  });

  final String id;
  final String operationId;
  final String? missionId;
  final String? relatedTransactionId;
  final String transactionType;
  final int amountMinor;
  final String? paymentMethod;
  final String? category;
  final String? note;
  final int occurredAtUtcMs;
  final int createdAtUtcMs;

  TransactionsCompanion toCompanion() => TransactionsCompanion.insert(
    id: id,
    operationId: operationId,
    missionId: Value<String?>(missionId),
    relatedTransactionId: Value<String?>(relatedTransactionId),
    transactionType: transactionType,
    amountMinor: amountMinor,
    paymentMethod: Value<String?>(paymentMethod),
    category: Value<String?>(category),
    note: Value<String?>(note),
    occurredAt: occurredAtUtcMs,
    createdAt: createdAtUtcMs,
  );
}

final class GoalAllocationInput {
  const GoalAllocationInput({
    required this.id,
    required this.operationId,
    required this.goalId,
    required this.direction,
    required this.amountMinor,
    required this.occurredAtUtcMs,
    required this.createdAtUtcMs,
    this.note,
  });

  final String id;
  final String operationId;
  final String goalId;
  final String direction;
  final int amountMinor;
  final String? note;
  final int occurredAtUtcMs;
  final int createdAtUtcMs;

  GoalAllocationsCompanion toCompanion() => GoalAllocationsCompanion.insert(
    id: id,
    operationId: operationId,
    goalId: goalId,
    direction: direction,
    amountMinor: amountMinor,
    note: Value<String?>(note),
    occurredAt: occurredAtUtcMs,
    createdAt: createdAtUtcMs,
  );
}

final class EconomyBalance {
  const EconomyBalance({required this.totalMinor, required this.reservedMinor});

  final int totalMinor;
  final int reservedMinor;

  int get availableMinor => totalMinor - reservedMinor;
}

final class EconomyPeriodTotals {
  const EconomyPeriodTotals({
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final int incomeMinor;
  final int expenseMinor;

  int get netMinor => incomeMinor - expenseMinor;
}

final class TransactionReversalResult {
  const TransactionReversalResult({
    required this.original,
    required this.reversal,
    required this.created,
  });

  final Transaction original;
  final Transaction reversal;
  final bool created;
}

final class EconomyDao {
  EconomyDao(this._database);

  final AppDatabase _database;

  Stream<List<Transaction>> watchLedger({
    required int startUtcMs,
    required int endUtcMs,
    int limit = 100,
    int offset = 0,
  }) {
    if (endUtcMs <= startUtcMs) {
      throw ArgumentError.value(
        endUtcMs,
        'endUtcMs',
        'Must exceed startUtcMs.',
      );
    }
    if (limit <= 0 || offset < 0) {
      throw ArgumentError('Pagination values are invalid.');
    }
    final query = _database.select(_database.transactions)
      ..where(
        (table) =>
            table.occurredAt.isBiggerOrEqualValue(startUtcMs) &
            table.occurredAt.isSmallerThanValue(endUtcMs),
      )
      ..orderBy(<OrderingTerm Function(Transactions)>[
        (table) => OrderingTerm.desc(table.occurredAt),
        (table) => OrderingTerm.desc(table.id),
      ])
      ..limit(limit, offset: offset);
    return query.watch();
  }

  Future<EconomyPeriodTotals> totalsForPeriod({
    required int startUtcMs,
    required int endUtcMs,
  }) {
    return _periodTotalsQuery(
      startUtcMs: startUtcMs,
      endUtcMs: endUtcMs,
    ).getSingle().then(_readPeriodTotals);
  }

  Stream<EconomyPeriodTotals> watchTotalsForPeriod({
    required int startUtcMs,
    required int endUtcMs,
  }) {
    return _periodTotalsQuery(
      startUtcMs: startUtcMs,
      endUtcMs: endUtcMs,
    ).watchSingle().map(_readPeriodTotals);
  }

  Selectable<QueryRow> _periodTotalsQuery({
    required int startUtcMs,
    required int endUtcMs,
  }) {
    if (endUtcMs <= startUtcMs) {
      throw ArgumentError.value(
        endUtcMs,
        'endUtcMs',
        'Must exceed startUtcMs.',
      );
    }
    return _database.customSelect(
      '''
        SELECT
          COALESCE(SUM(
            CASE
              WHEN transaction_type IN (
                'INCOME', 'REFUND', 'ADJUSTMENT_CREDIT'
              ) THEN amount_minor
              ELSE 0
            END
          ), 0) AS income_minor,
          COALESCE(SUM(
            CASE
              WHEN transaction_type IN ('EXPENSE', 'ADJUSTMENT_DEBIT')
                THEN amount_minor
              ELSE 0
            END
          ), 0) AS expense_minor
        FROM transactions
        WHERE occurred_at >= ? AND occurred_at < ?
      ''',
      variables: <Variable<Object>>[
        Variable<int>(startUtcMs),
        Variable<int>(endUtcMs),
      ],
      readsFrom: <ResultSetImplementation<Table, Object?>>{
        _database.transactions,
      },
    );
  }

  EconomyPeriodTotals _readPeriodTotals(QueryRow row) {
    return EconomyPeriodTotals(
      incomeMinor: row.read<int>('income_minor'),
      expenseMinor: row.read<int>('expense_minor'),
    );
  }

  Stream<EconomyBalance> watchBalance() {
    const sql = '''
      SELECT
        COALESCE((
          SELECT SUM(
            CASE
              WHEN transaction_type IN (
                'INCOME', 'REFUND', 'ADJUSTMENT_CREDIT'
              ) THEN amount_minor
              ELSE -amount_minor
            END
          )
          FROM transactions
        ), 0) AS total_minor,
        COALESCE((
          SELECT SUM(
            CASE direction
              WHEN 'RESERVE' THEN amount_minor
              ELSE -amount_minor
            END
          )
          FROM goal_allocations
        ), 0) AS reserved_minor
    ''';
    return _database
        .customSelect(
          sql,
          readsFrom: <ResultSetImplementation<Table, Object?>>{
            _database.transactions,
            _database.goalAllocations,
          },
        )
        .watchSingle()
        .map(
          (row) => EconomyBalance(
            totalMinor: row.read<int>('total_minor'),
            reservedMinor: row.read<int>('reserved_minor'),
          ),
        );
  }

  Future<DaoWriteResult<Transaction>> writeTransaction(
    LedgerTransactionInput input,
  ) {
    if (input.relatedTransactionId != null) {
      throw ArgumentError(
        'Related transactions are compensations and must use '
        'reverseTransactionAtomically.',
      );
    }
    return _database.transaction(() => _writeTransaction(input));
  }

  Future<DaoWriteResult<Transaction>> _writeTransaction(
    LedgerTransactionInput input,
  ) async {
    final existing = await _findTransactionByOperationId(input.operationId);
    if (existing != null) {
      _validateSameTransaction(existing, input);
      return DaoWriteResult<Transaction>(value: existing, created: false);
    }

    final inserted = await _database
        .into(_database.transactions)
        .insertReturningOrNull(
          input.toCompanion(),
          mode: InsertMode.insertOrIgnore,
        );
    if (inserted != null) {
      return DaoWriteResult<Transaction>(value: inserted, created: true);
    }

    final raced = await _findTransactionByOperationId(input.operationId);
    if (raced == null) {
      throw IdempotencyConflictException(
        operationId: input.operationId,
        entity: 'transaction',
      );
    }
    _validateSameTransaction(raced, input);
    return DaoWriteResult<Transaction>(value: raced, created: false);
  }

  Future<Transaction?> _findTransactionByOperationId(String operationId) {
    return (_database.select(_database.transactions)
          ..where((table) => table.operationId.equals(operationId)))
        .getSingleOrNull();
  }

  Future<DaoWriteResult<GoalAllocation>> allocate(GoalAllocationInput input) {
    return _database.transaction(() async {
      final existing = await _findAllocationByOperationId(input.operationId);
      if (existing != null) {
        _validateSameAllocation(existing, input);
        return DaoWriteResult<GoalAllocation>(value: existing, created: false);
      }

      if (input.direction == 'RELEASE') {
        final reserved = await reservedForGoal(input.goalId);
        if (input.amountMinor > reserved) {
          throw DatabaseInvariantException(
            'RELEASE ${input.amountMinor} exceeds reserved $reserved '
            'for goal ${input.goalId}.',
          );
        }
      }

      final inserted = await _database
          .into(_database.goalAllocations)
          .insertReturningOrNull(
            input.toCompanion(),
            mode: InsertMode.insertOrIgnore,
          );
      if (inserted != null) {
        return DaoWriteResult<GoalAllocation>(value: inserted, created: true);
      }

      final raced = await _findAllocationByOperationId(input.operationId);
      if (raced == null) {
        throw IdempotencyConflictException(
          operationId: input.operationId,
          entity: 'goal allocation',
        );
      }
      _validateSameAllocation(raced, input);
      return DaoWriteResult<GoalAllocation>(value: raced, created: false);
    });
  }

  Future<GoalAllocation?> _findAllocationByOperationId(String operationId) {
    return (_database.select(_database.goalAllocations)
          ..where((table) => table.operationId.equals(operationId)))
        .getSingleOrNull();
  }

  Future<int> reservedForGoal(String goalId) async {
    final row = await _database
        .customSelect(
          '''
        SELECT COALESCE(SUM(
          CASE direction
            WHEN 'RESERVE' THEN amount_minor
            ELSE -amount_minor
          END
        ), 0) AS reserved_minor
        FROM goal_allocations
        WHERE goal_id = ?
      ''',
          variables: <Variable<Object>>[Variable<String>(goalId)],
          readsFrom: <ResultSetImplementation<Table, Object?>>{
            _database.goalAllocations,
          },
        )
        .getSingle();
    return row.read<int>('reserved_minor');
  }

  Stream<List<SavingsGoal>> watchGoals({bool includeArchived = false}) {
    final query = _database.select(_database.savingsGoals);
    if (!includeArchived) {
      query.where((table) => table.archivedAt.isNull());
    }
    query.orderBy(<OrderingTerm Function(SavingsGoals)>[
      (table) => OrderingTerm.asc(table.status),
      (table) => OrderingTerm.asc(table.dueDate),
      (table) => OrderingTerm.asc(table.id),
    ]);
    return query.watch();
  }

  Future<SavingsGoal> insertGoal(SavingsGoalsCompanion goal) {
    return _database.into(_database.savingsGoals).insertReturning(goal);
  }

  Future<TransactionReversalResult> reverseTransactionAtomically({
    required String originalTransactionId,
    required LedgerTransactionInput reversal,
    required int reversedAtUtcMs,
  }) {
    return _database.transaction(() async {
      final original =
          await (_database.select(_database.transactions)
                ..where((table) => table.id.equals(originalTransactionId)))
              .getSingleOrNull();
      if (original == null) {
        throw RecordNotFoundException(
          table: 'transactions',
          key: originalTransactionId,
        );
      }
      _validateReversal(original, reversal, reversedAtUtcMs);

      if (original.reversedAt != null) {
        final existing = await _findTransactionByOperationId(
          reversal.operationId,
        );
        if (existing == null || original.reversedAt != reversedAtUtcMs) {
          throw const DatabaseInvariantException(
            'Transaction was already reversed by another operation.',
          );
        }
        _validateSameTransaction(existing, reversal);
        return TransactionReversalResult(
          original: original,
          reversal: existing,
          created: false,
        );
      }

      final result = await _writeTransaction(reversal);
      final affected =
          await (_database.update(_database.transactions)..where(
                (table) =>
                    table.id.equals(originalTransactionId) &
                    table.reversedAt.isNull(),
              ))
              .write(
                TransactionsCompanion(reversedAt: Value<int?>(reversedAtUtcMs)),
              );
      if (affected != 1) {
        throw const DatabaseInvariantException(
          'Transaction reversal lost an atomicity race.',
        );
      }
      final updatedOriginal = await (_database.select(
        _database.transactions,
      )..where((table) => table.id.equals(originalTransactionId))).getSingle();
      return TransactionReversalResult(
        original: updatedOriginal,
        reversal: result.value,
        created: result.created,
      );
    });
  }

  void _validateReversal(
    Transaction original,
    LedgerTransactionInput reversal,
    int reversedAtUtcMs,
  ) {
    if (reversal.id == original.id ||
        reversal.relatedTransactionId != original.id ||
        reversal.amountMinor != original.amountMinor ||
        reversal.occurredAtUtcMs < original.occurredAt ||
        reversedAtUtcMs < original.occurredAt) {
      throw const DatabaseInvariantException(
        'A reversal must reference and fully compensate the original movement.',
      );
    }

    const creditTypes = <String>{'INCOME', 'REFUND', 'ADJUSTMENT_CREDIT'};
    const debitTypes = <String>{'EXPENSE', 'ADJUSTMENT_DEBIT'};
    final originalIsCredit = creditTypes.contains(original.transactionType);
    final reversalIsCredit = creditTypes.contains(reversal.transactionType);
    final reversalIsDebit = debitTypes.contains(reversal.transactionType);
    if ((originalIsCredit && !reversalIsDebit) ||
        (!originalIsCredit && !reversalIsCredit)) {
      throw const DatabaseInvariantException(
        'Reversal must have the opposite ledger effect.',
      );
    }
  }

  void _validateSameTransaction(
    Transaction stored,
    LedgerTransactionInput input,
  ) {
    final matches =
        stored.id == input.id &&
        stored.missionId == input.missionId &&
        stored.relatedTransactionId == input.relatedTransactionId &&
        stored.transactionType == input.transactionType &&
        stored.amountMinor == input.amountMinor &&
        stored.paymentMethod == input.paymentMethod &&
        stored.category == input.category &&
        stored.note == input.note &&
        stored.occurredAt == input.occurredAtUtcMs &&
        stored.createdAt == input.createdAtUtcMs;
    if (!matches) {
      throw IdempotencyConflictException(
        operationId: input.operationId,
        entity: 'transaction',
      );
    }
  }

  void _validateSameAllocation(
    GoalAllocation stored,
    GoalAllocationInput input,
  ) {
    final matches =
        stored.id == input.id &&
        stored.goalId == input.goalId &&
        stored.direction == input.direction &&
        stored.amountMinor == input.amountMinor &&
        stored.note == input.note &&
        stored.occurredAt == input.occurredAtUtcMs &&
        stored.createdAt == input.createdAtUtcMs;
    if (!matches) {
      throw IdempotencyConflictException(
        operationId: input.operationId,
        entity: 'goal allocation',
      );
    }
  }
}
