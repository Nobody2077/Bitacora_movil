import 'dart:math';

import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../domain/models/economy_models.dart';
import '../domain/models/economy_snapshot.dart';
import '../domain/repositories/economy_repository.dart';

abstract interface class EconomyClock {
  DateTime nowUtc();
}

final class SystemEconomyClock implements EconomyClock {
  const SystemEconomyClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

abstract interface class EconomyIdGenerator {
  String nextId();
}

final class SecureEconomyIdGenerator implements EconomyIdGenerator {
  SecureEconomyIdGenerator() : _random = Random.secure();

  final Random _random;

  @override
  String nextId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

final class SaveTransactionRequest {
  const SaveTransactionRequest({
    required this.type,
    required this.amountMinor,
    this.paymentMethod,
    this.category,
    this.note,
    this.missionId,
    this.occurredAtUtc,
  });

  final EconomyTransactionType type;
  final int amountMinor;
  final EconomyPaymentMethod? paymentMethod;
  final String? category;
  final String? note;
  final String? missionId;
  final DateTime? occurredAtUtc;
}

final class SaveGoalRequest {
  const SaveGoalRequest({
    required this.title,
    required this.targetMinor,
    this.existing,
    this.dueDate,
    this.status = SavingsGoalStatus.active,
  });

  final SavingsGoalSummary? existing;
  final String title;
  final int targetMinor;
  final String? dueDate;
  final SavingsGoalStatus status;
}

final class AllocateGoalRequest {
  const AllocateGoalRequest({
    required this.goal,
    required this.direction,
    required this.amountMinor,
    this.note,
  });

  final SavingsGoalSummary goal;
  final GoalAllocationDirection direction;
  final int amountMinor;
  final String? note;
}

final class EconomyApplicationService {
  const EconomyApplicationService({
    required EconomyRepository repository,
    required EconomyClock clock,
    required EconomyIdGenerator idGenerator,
  }) : _repository = repository,
       _clock = clock,
       _idGenerator = idGenerator;

  final EconomyRepository _repository;
  final EconomyClock _clock;
  final EconomyIdGenerator _idGenerator;

  Future<Result<EconomyTransaction>> saveTransaction(
    SaveTransactionRequest request,
  ) {
    final failure = _validateTransaction(request);
    if (failure != null) {
      return Future<Result<EconomyTransaction>>.value(
        Failure<EconomyTransaction>(failure),
      );
    }
    final DateTime nowUtc = _clock.nowUtc();
    final DateTime occurredAtUtc = request.occurredAtUtc ?? nowUtc;
    return _repository.createTransaction(
      transaction: EconomyTransaction(
        id: _idGenerator.nextId(),
        operationId: _idGenerator.nextId(),
        missionId: _trimmedOrNull(request.missionId),
        type: request.type,
        amountMinor: request.amountMinor,
        paymentMethod: request.paymentMethod,
        category: _trimmedOrNull(request.category),
        note: _trimmedOrNull(request.note),
        occurredAtUtc: occurredAtUtc,
        createdAtUtc: nowUtc,
      ),
    );
  }

  Future<Result<EconomyTransaction>> reverseTransaction(
    EconomyTransaction original,
  ) {
    if (original.isReversal || original.isReversed) {
      return Future<Result<EconomyTransaction>>.value(
        const Failure<EconomyTransaction>(
          ValidationFailure('Este movimiento no admite otra anulación.'),
        ),
      );
    }
    final DateTime nowUtc = _clock.nowUtc();
    return _repository.reverseTransaction(
      original: original,
      reversal: EconomyTransaction(
        id: _idGenerator.nextId(),
        operationId: _idGenerator.nextId(),
        relatedTransactionId: original.id,
        type: _reversalType(original.type),
        amountMinor: original.amountMinor,
        paymentMethod: original.paymentMethod,
        category: original.category,
        note: 'Anulación compensatoria',
        occurredAtUtc: nowUtc,
        createdAtUtc: nowUtc,
      ),
      reversedAtUtc: nowUtc,
    );
  }

  Future<Result<EconomyTransaction>> correctTransaction(
    EconomyTransaction original,
    SaveTransactionRequest request,
  ) {
    final failure = _validateTransaction(request);
    if (failure != null) {
      return Future<Result<EconomyTransaction>>.value(
        Failure<EconomyTransaction>(failure),
      );
    }
    if (original.isReversal || original.isReversed) {
      return Future<Result<EconomyTransaction>>.value(
        const Failure<EconomyTransaction>(
          ValidationFailure('Este movimiento no admite corrección.'),
        ),
      );
    }
    final DateTime nowUtc = _clock.nowUtc();
    final DateTime reversedAtUtc = nowUtc.isBefore(original.occurredAtUtc)
        ? original.occurredAtUtc
        : nowUtc;
    return _repository.correctTransaction(
      original: original,
      reversal: EconomyTransaction(
        id: _idGenerator.nextId(),
        operationId: _idGenerator.nextId(),
        relatedTransactionId: original.id,
        type: _reversalType(original.type),
        amountMinor: original.amountMinor,
        paymentMethod: original.paymentMethod,
        category: original.category,
        note: 'Compensación por corrección',
        occurredAtUtc: reversedAtUtc,
        createdAtUtc: nowUtc,
      ),
      replacement: EconomyTransaction(
        id: _idGenerator.nextId(),
        operationId: _idGenerator.nextId(),
        missionId: _trimmedOrNull(request.missionId) ?? original.missionId,
        type: request.type,
        amountMinor: request.amountMinor,
        paymentMethod: request.paymentMethod,
        category: _trimmedOrNull(request.category),
        note: _trimmedOrNull(request.note),
        occurredAtUtc: request.occurredAtUtc ?? original.occurredAtUtc,
        createdAtUtc: nowUtc,
      ),
      reversedAtUtc: reversedAtUtc,
    );
  }

  Future<Result<SavingsGoalSummary>> saveGoal(SaveGoalRequest request) {
    final String title = request.title.trim();
    if (title.isEmpty ||
        title.length > 160 ||
        request.targetMinor <= 0 ||
        (request.existing != null &&
            request.targetMinor < request.existing!.reservedMinor)) {
      return Future<Result<SavingsGoalSummary>>.value(
        const Failure<SavingsGoalSummary>(
          ValidationFailure(
            'La meta requiere nombre y monto objetivo válidos.',
          ),
        ),
      );
    }
    final String? dueDate = _trimmedOrNull(request.dueDate);
    if (dueDate != null && !_isCivilDate(dueDate)) {
      return Future<Result<SavingsGoalSummary>>.value(
        const Failure<SavingsGoalSummary>(
          ValidationFailure('La fecha límite no es válida.'),
        ),
      );
    }
    final DateTime nowUtc = _clock.nowUtc();
    final existing = request.existing;
    final goal = SavingsGoalSummary(
      id: existing?.id ?? _idGenerator.nextId(),
      title: title,
      targetMinor: request.targetMinor,
      reservedMinor: existing?.reservedMinor ?? 0,
      status: request.status,
      dueDate: dueDate,
      createdAtUtc: existing?.createdAtUtc ?? nowUtc,
      archivedAtUtc: request.status == SavingsGoalStatus.archived
          ? existing?.archivedAtUtc ?? nowUtc
          : null,
    );
    return existing == null
        ? _repository.createGoal(goal)
        : _repository.updateGoal(goal);
  }

  Future<Result<SavingsGoalSummary>> allocate(
    AllocateGoalRequest request,
  ) async {
    if (request.amountMinor <= 0 ||
        request.goal.status == SavingsGoalStatus.archived ||
        (request.direction == GoalAllocationDirection.reserve &&
            request.goal.status == SavingsGoalStatus.paused) ||
        (request.direction == GoalAllocationDirection.reserve &&
            request.amountMinor > request.goal.remainingMinor) ||
        (request.direction == GoalAllocationDirection.release &&
            request.amountMinor > request.goal.reservedMinor)) {
      return const Failure<SavingsGoalSummary>(
        ValidationFailure('El cambio de reserva no es válido.'),
      );
    }
    if (request.direction == GoalAllocationDirection.reserve) {
      final nowUtc = _clock.nowUtc();
      final startUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final snapshot = await _repository.loadSnapshot(
        dayStartUtc: startUtc,
        dayEndUtc: startUtc.add(const Duration(days: 1)),
        monthStartUtc: DateTime.utc(nowUtc.year, nowUtc.month),
        monthEndUtc: DateTime.utc(nowUtc.year, nowUtc.month + 1),
      );
      if (snapshot is Failure<EconomySnapshot>) {
        return Failure<SavingsGoalSummary>(snapshot.failure);
      }
      final available =
          (snapshot as Success<EconomySnapshot>).value.availableMinor;
      if (request.amountMinor > available) {
        return const Failure<SavingsGoalSummary>(
          ValidationFailure('El monto supera el saldo disponible.'),
        );
      }
    }
    return _repository.allocate(
      allocationId: _idGenerator.nextId(),
      operationId: _idGenerator.nextId(),
      goalId: request.goal.id,
      direction: request.direction,
      amountMinor: request.amountMinor,
      occurredAtUtc: _clock.nowUtc(),
      note: _trimmedOrNull(request.note),
    );
  }

  ValidationFailure? _validateTransaction(SaveTransactionRequest request) {
    if (request.amountMinor <= 0 ||
        (request.occurredAtUtc != null && !request.occurredAtUtc!.isUtc)) {
      return const ValidationFailure('El monto o la fecha no son válidos.');
    }
    if (const <EconomyTransactionType>{
          EconomyTransactionType.expense,
          EconomyTransactionType.adjustmentDebit,
        }.contains(request.type) &&
        request.paymentMethod == null) {
      return const ValidationFailure(
        'Selecciona un medio de pago para el débito.',
      );
    }
    if ((_trimmedOrNull(request.category)?.length ?? 0) > 120 ||
        (_trimmedOrNull(request.note)?.length ?? 0) > 2000) {
      return const ValidationFailure(
        'La categoría o nota supera el tamaño permitido.',
      );
    }
    if (request.type == EconomyTransactionType.refund) {
      return const ValidationFailure(
        'Los reembolsos se crean anulando el gasto original.',
      );
    }
    return null;
  }

  static EconomyTransactionType _reversalType(EconomyTransactionType value) =>
      switch (value) {
        EconomyTransactionType.expense ||
        EconomyTransactionType.adjustmentDebit => EconomyTransactionType.refund,
        EconomyTransactionType.income ||
        EconomyTransactionType.refund ||
        EconomyTransactionType.adjustmentCredit =>
          EconomyTransactionType.adjustmentDebit,
      };

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static bool _isCivilDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return false;
    }
    final parsed = DateTime.tryParse('${value}T00:00:00Z');
    return parsed != null &&
        '${parsed.year.toString().padLeft(4, '0')}-'
                '${parsed.month.toString().padLeft(2, '0')}-'
                '${parsed.day.toString().padLeft(2, '0')}' ==
            value;
  }
}
