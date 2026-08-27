import 'package:drift/drift.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/app_database.dart' as drift;
import '../../../infrastructure/database/daos/economy_dao.dart';
import '../domain/models/economy_models.dart';
import '../domain/models/economy_snapshot.dart';
import '../domain/repositories/economy_repository.dart';

final class DriftEconomyRepository implements EconomyRepository {
  const DriftEconomyRepository(this._dao);

  final EconomyDao _dao;

  @override
  Future<Result<EconomySnapshot>> loadSnapshot({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required DateTime monthStartUtc,
    required DateTime monthEndUtc,
  }) async {
    if (!_validRange(dayStartUtc, dayEndUtc) ||
        !_validRange(monthStartUtc, monthEndUtc)) {
      return const Failure<EconomySnapshot>(
        ValidationFailure(
          'Los períodos económicos deben usar límites UTC válidos.',
        ),
      );
    }

    try {
      final balanceFuture = _dao.watchBalance().first;
      final monthFuture = _dao.totalsForPeriod(
        startUtcMs: monthStartUtc.millisecondsSinceEpoch,
        endUtcMs: monthEndUtc.millisecondsSinceEpoch,
      );
      final dayFuture = _dao.totalsForPeriod(
        startUtcMs: dayStartUtc.millisecondsSinceEpoch,
        endUtcMs: dayEndUtc.millisecondsSinceEpoch,
      );

      final balance = await balanceFuture;
      final month = await monthFuture;
      final day = await dayFuture;
      return Success<EconomySnapshot>(
        EconomySnapshot(
          totalMinor: balance.totalMinor,
          reservedMinor: balance.reservedMinor,
          monthIncomeMinor: month.incomeMinor,
          monthExpenseMinor: month.expenseMinor,
          dayIncomeMinor: day.incomeMinor,
          dayExpenseMinor: day.expenseMinor,
        ),
      );
    } on Object catch (error) {
      return Failure<EconomySnapshot>(
        StorageFailure('No se pudo leer el resumen económico.', cause: error),
      );
    }
  }

  static bool _validRange(DateTime start, DateTime end) =>
      start.isUtc && end.isUtc && end.isAfter(start);

  @override
  Stream<Result<EconomySnapshot>> watchSnapshot({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required DateTime monthStartUtc,
    required DateTime monthEndUtc,
  }) async* {
    if (!_validRange(dayStartUtc, dayEndUtc) ||
        !_validRange(monthStartUtc, monthEndUtc)) {
      yield const Failure<EconomySnapshot>(
        ValidationFailure(
          'Los períodos económicos deben usar límites UTC válidos.',
        ),
      );
      return;
    }
    try {
      await for (final _ in _dao.watchBalance()) {
        yield await loadSnapshot(
          dayStartUtc: dayStartUtc,
          dayEndUtc: dayEndUtc,
          monthStartUtc: monthStartUtc,
          monthEndUtc: monthEndUtc,
        );
      }
    } on Object catch (error) {
      yield Failure<EconomySnapshot>(
        StorageFailure(
          'No se pudo observar el resumen económico.',
          cause: error,
        ),
      );
    }
  }

  @override
  Stream<Result<List<EconomyTransaction>>> watchTransactions({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 100,
  }) async* {
    if (!_validRange(startUtc, endUtc) || limit <= 0) {
      yield const Failure<List<EconomyTransaction>>(
        ValidationFailure('El período o límite de movimientos no es válido.'),
      );
      return;
    }
    try {
      await for (final rows in _dao.watchLedger(
        startUtcMs: startUtc.millisecondsSinceEpoch,
        endUtcMs: endUtc.millisecondsSinceEpoch,
        limit: limit,
      )) {
        yield Success<List<EconomyTransaction>>(
          rows.map(_transaction).toList(growable: false),
        );
      }
    } on Object catch (error) {
      yield Failure<List<EconomyTransaction>>(
        StorageFailure(
          'No se pudieron observar los movimientos.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<EconomyTransaction?>> findTransaction(String id) async {
    if (id.trim().isEmpty) {
      return const Failure<EconomyTransaction?>(
        ValidationFailure('El movimiento no tiene un identificador válido.'),
      );
    }
    try {
      final row = await _dao.findTransaction(id);
      return Success<EconomyTransaction?>(
        row == null ? null : _transaction(row),
      );
    } on Object catch (error) {
      return Failure<EconomyTransaction?>(
        StorageFailure('No se pudo leer el movimiento.', cause: error),
      );
    }
  }

  @override
  Future<Result<EconomyTransaction>> createTransaction({
    required EconomyTransaction transaction,
  }) async {
    try {
      final result = await _dao.writeTransaction(
        _transactionInput(transaction),
      );
      return Success<EconomyTransaction>(_transaction(result.value));
    } on Object catch (error) {
      return Failure<EconomyTransaction>(
        StorageFailure('No se pudo registrar el movimiento.', cause: error),
      );
    }
  }

  @override
  Future<Result<EconomyTransaction>> reverseTransaction({
    required EconomyTransaction original,
    required EconomyTransaction reversal,
    required DateTime reversedAtUtc,
  }) async {
    if (!reversedAtUtc.isUtc) {
      return const Failure<EconomyTransaction>(
        ValidationFailure('La fecha de anulación debe estar en UTC.'),
      );
    }
    try {
      final result = await _dao.reverseTransactionAtomically(
        originalTransactionId: original.id,
        reversal: _transactionInput(reversal),
        reversedAtUtcMs: reversedAtUtc.millisecondsSinceEpoch,
      );
      return Success<EconomyTransaction>(_transaction(result.reversal));
    } on Object catch (error) {
      return Failure<EconomyTransaction>(
        StorageFailure('No se pudo anular el movimiento.', cause: error),
      );
    }
  }

  @override
  Future<Result<EconomyTransaction>> correctTransaction({
    required EconomyTransaction original,
    required EconomyTransaction reversal,
    required EconomyTransaction replacement,
    required DateTime reversedAtUtc,
  }) async {
    if (!reversedAtUtc.isUtc) {
      return const Failure<EconomyTransaction>(
        ValidationFailure('La fecha de corrección debe estar en UTC.'),
      );
    }
    try {
      final result = await _dao.correctTransactionAtomically(
        originalTransactionId: original.id,
        reversal: _transactionInput(reversal),
        replacement: _transactionInput(replacement),
        reversedAtUtcMs: reversedAtUtc.millisecondsSinceEpoch,
      );
      return Success<EconomyTransaction>(_transaction(result.replacement));
    } on Object catch (error) {
      return Failure<EconomyTransaction>(
        StorageFailure('No se pudo corregir el movimiento.', cause: error),
      );
    }
  }

  @override
  Stream<Result<List<SavingsGoalSummary>>> watchGoals() async* {
    try {
      await for (final rows in _dao.watchGoalBalances()) {
        yield Success<List<SavingsGoalSummary>>(
          rows.map(_goal).toList(growable: false),
        );
      }
    } on Object catch (error) {
      yield Failure<List<SavingsGoalSummary>>(
        StorageFailure('No se pudieron observar las metas.', cause: error),
      );
    }
  }

  @override
  Future<Result<SavingsGoalSummary?>> findGoal(String id) async {
    if (id.trim().isEmpty) {
      return const Failure<SavingsGoalSummary?>(
        ValidationFailure('La meta no tiene un identificador válido.'),
      );
    }
    try {
      final row = await _dao.findGoalBalance(id);
      return Success<SavingsGoalSummary?>(row == null ? null : _goal(row));
    } on Object catch (error) {
      return Failure<SavingsGoalSummary?>(
        StorageFailure('No se pudo leer la meta.', cause: error),
      );
    }
  }

  @override
  Future<Result<SavingsGoalSummary>> createGoal(SavingsGoalSummary goal) async {
    try {
      final row = await _dao.insertGoal(
        drift.SavingsGoalsCompanion.insert(
          id: goal.id,
          title: goal.title.trim(),
          targetMinor: goal.targetMinor,
          status: _goalStatus(goal.status),
          dueDate: Value<String?>(goal.dueDate),
          createdAt: goal.createdAtUtc.millisecondsSinceEpoch,
          archivedAt: Value<int?>(goal.archivedAtUtc?.millisecondsSinceEpoch),
        ),
      );
      return Success<SavingsGoalSummary>(
        _goal(SavingsGoalBalance(goal: row, reservedMinor: 0)),
      );
    } on Object catch (error) {
      return Failure<SavingsGoalSummary>(
        StorageFailure('No se pudo crear la meta.', cause: error),
      );
    }
  }

  @override
  Future<Result<SavingsGoalSummary>> updateGoal(SavingsGoalSummary goal) async {
    try {
      await _dao.updateGoal(
        goalId: goal.id,
        changes: drift.SavingsGoalsCompanion(
          title: Value<String>(goal.title.trim()),
          targetMinor: Value<int>(goal.targetMinor),
          status: Value<String>(_goalStatus(goal.status)),
          dueDate: Value<String?>(goal.dueDate),
          archivedAt: Value<int?>(goal.archivedAtUtc?.millisecondsSinceEpoch),
        ),
      );
      final updated = await _dao.findGoalBalance(goal.id);
      if (updated == null) {
        throw StateError('Updated goal is not readable.');
      }
      return Success<SavingsGoalSummary>(_goal(updated));
    } on Object catch (error) {
      return Failure<SavingsGoalSummary>(
        StorageFailure('No se pudo actualizar la meta.', cause: error),
      );
    }
  }

  @override
  Future<Result<SavingsGoalSummary>> allocate({
    required String allocationId,
    required String operationId,
    required String goalId,
    required GoalAllocationDirection direction,
    required int amountMinor,
    required DateTime occurredAtUtc,
    String? note,
  }) async {
    try {
      await _dao.allocate(
        GoalAllocationInput(
          id: allocationId,
          operationId: operationId,
          goalId: goalId,
          direction: direction == GoalAllocationDirection.reserve
              ? 'RESERVE'
              : 'RELEASE',
          amountMinor: amountMinor,
          note: _trimmedOrNull(note),
          occurredAtUtcMs: occurredAtUtc.millisecondsSinceEpoch,
          createdAtUtcMs: occurredAtUtc.millisecondsSinceEpoch,
        ),
      );
      final updated = await _dao.findGoalBalance(goalId);
      if (updated == null) {
        throw StateError('Allocated goal is not readable.');
      }
      return Success<SavingsGoalSummary>(_goal(updated));
    } on Object catch (error) {
      return Failure<SavingsGoalSummary>(
        StorageFailure('No se pudo actualizar la reserva.', cause: error),
      );
    }
  }

  static EconomyTransaction _transaction(drift.Transaction value) =>
      EconomyTransaction(
        id: value.id,
        operationId: value.operationId,
        missionId: value.missionId,
        relatedTransactionId: value.relatedTransactionId,
        type: _transactionType(value.transactionType),
        amountMinor: value.amountMinor,
        paymentMethod: _paymentMethod(value.paymentMethod),
        category: value.category,
        note: value.note,
        occurredAtUtc: _utc(value.occurredAt),
        createdAtUtc: _utc(value.createdAt),
        reversedAtUtc: value.reversedAt == null
            ? null
            : _utc(value.reversedAt!),
      );

  static LedgerTransactionInput _transactionInput(EconomyTransaction value) =>
      LedgerTransactionInput(
        id: value.id,
        operationId: value.operationId,
        missionId: value.missionId,
        relatedTransactionId: value.relatedTransactionId,
        transactionType: _transactionTypeToken(value.type),
        amountMinor: value.amountMinor,
        paymentMethod: _paymentMethodToken(value.paymentMethod),
        category: _trimmedOrNull(value.category),
        note: _trimmedOrNull(value.note),
        occurredAtUtcMs: value.occurredAtUtc.millisecondsSinceEpoch,
        createdAtUtcMs: value.createdAtUtc.millisecondsSinceEpoch,
      );

  static SavingsGoalSummary _goal(SavingsGoalBalance value) =>
      SavingsGoalSummary(
        id: value.goal.id,
        title: value.goal.title,
        targetMinor: value.goal.targetMinor,
        reservedMinor: value.reservedMinor,
        status: _goalStatusValue(value.goal.status),
        dueDate: value.goal.dueDate,
        createdAtUtc: _utc(value.goal.createdAt),
        archivedAtUtc: value.goal.archivedAt == null
            ? null
            : _utc(value.goal.archivedAt!),
      );

  static DateTime _utc(int milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static EconomyTransactionType _transactionType(String value) =>
      switch (value) {
        'INCOME' => EconomyTransactionType.income,
        'EXPENSE' => EconomyTransactionType.expense,
        'REFUND' => EconomyTransactionType.refund,
        'ADJUSTMENT_CREDIT' => EconomyTransactionType.adjustmentCredit,
        'ADJUSTMENT_DEBIT' => EconomyTransactionType.adjustmentDebit,
        _ => throw StateError('Unknown transaction type.'),
      };

  static String _transactionTypeToken(EconomyTransactionType value) =>
      switch (value) {
        EconomyTransactionType.income => 'INCOME',
        EconomyTransactionType.expense => 'EXPENSE',
        EconomyTransactionType.refund => 'REFUND',
        EconomyTransactionType.adjustmentCredit => 'ADJUSTMENT_CREDIT',
        EconomyTransactionType.adjustmentDebit => 'ADJUSTMENT_DEBIT',
      };

  static EconomyPaymentMethod? _paymentMethod(String? value) => switch (value) {
    null => null,
    'CASH' => EconomyPaymentMethod.cash,
    'BANK' => EconomyPaymentMethod.bank,
    'WALLET' => EconomyPaymentMethod.wallet,
    _ => throw StateError('Unknown payment method.'),
  };

  static String? _paymentMethodToken(EconomyPaymentMethod? value) =>
      switch (value) {
        null => null,
        EconomyPaymentMethod.cash => 'CASH',
        EconomyPaymentMethod.bank => 'BANK',
        EconomyPaymentMethod.wallet => 'WALLET',
      };

  static SavingsGoalStatus _goalStatusValue(String value) => switch (value) {
    'ACTIVE' => SavingsGoalStatus.active,
    'ACHIEVED' => SavingsGoalStatus.achieved,
    'PAUSED' => SavingsGoalStatus.paused,
    'ARCHIVED' => SavingsGoalStatus.archived,
    _ => throw StateError('Unknown goal status.'),
  };

  static String _goalStatus(SavingsGoalStatus value) => switch (value) {
    SavingsGoalStatus.active => 'ACTIVE',
    SavingsGoalStatus.achieved => 'ACHIEVED',
    SavingsGoalStatus.paused => 'PAUSED',
    SavingsGoalStatus.archived => 'ARCHIVED',
  };
}
