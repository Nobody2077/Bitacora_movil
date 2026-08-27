import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/economy/application/economy_application_service.dart';
import 'package:bitacora_rpg_personal/features/economy/data/drift_economy_repository.dart';
import 'package:bitacora_rpg_personal/features/economy/domain/models/economy_models.dart';
import 'package:bitacora_rpg_personal/features/economy/domain/models/economy_snapshot.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/economy_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime nowUtc = DateTime.utc(2026, 8, 27, 14);
  late AppDatabase database;
  late DriftEconomyRepository repository;
  late EconomyApplicationService service;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => nowUtc.millisecondsSinceEpoch,
    );
    repository = DriftEconomyRepository(EconomyDao(database));
    service = EconomyApplicationService(
      repository: repository,
      clock: _FixedEconomyClock(nowUtc),
      idGenerator: _SequenceEconomyIds(),
    );
  });

  tearDown(() => database.close());

  test('ledger y resumen derivado permanecen iguales', () async {
    expect(
      await service.saveTransaction(
        const SaveTransactionRequest(
          type: EconomyTransactionType.income,
          amountMinor: 10000,
          category: 'Trabajo',
        ),
      ),
      isA<Success<EconomyTransaction>>(),
    );
    expect(
      await service.saveTransaction(
        const SaveTransactionRequest(
          type: EconomyTransactionType.expense,
          amountMinor: 2500,
          paymentMethod: EconomyPaymentMethod.wallet,
          category: 'Comida',
        ),
      ),
      isA<Success<EconomyTransaction>>(),
    );

    final snapshot = await repository.loadSnapshot(
      dayStartUtc: DateTime.utc(2026, 8, 27),
      dayEndUtc: DateTime.utc(2026, 8, 28),
      monthStartUtc: DateTime.utc(2026, 8),
      monthEndUtc: DateTime.utc(2026, 9),
    );
    final EconomySnapshot value = (snapshot as Success<EconomySnapshot>).value;
    expect(value.totalMinor, 7500);
    expect(value.dayIncomeMinor, 10000);
    expect(value.dayExpenseMinor, 2500);
    expect(value.monthNetMinor, 7500);
  });

  test('anular crea compensación opuesta sin borrar historia', () async {
    final created = await service.saveTransaction(
      const SaveTransactionRequest(
        type: EconomyTransactionType.expense,
        amountMinor: 3200,
        paymentMethod: EconomyPaymentMethod.cash,
      ),
    );
    final original = (created as Success<EconomyTransaction>).value;

    final reversed = await service.reverseTransaction(original);

    expect(reversed, isA<Success<EconomyTransaction>>());
    final compensation = (reversed as Success<EconomyTransaction>).value;
    expect(compensation.type, EconomyTransactionType.refund);
    expect(compensation.relatedTransactionId, original.id);
    expect(await database.select(database.transactions).get(), hasLength(2));
    expect(
      (await repository.findTransaction(original.id)
              as Success<EconomyTransaction?>)
          .value!
          .isReversed,
      isTrue,
    );
  });

  test('corregir compensa y sustituye dentro del mismo ledger', () async {
    final created = await service.saveTransaction(
      const SaveTransactionRequest(
        type: EconomyTransactionType.expense,
        amountMinor: 3200,
        paymentMethod: EconomyPaymentMethod.cash,
      ),
    );
    final original = (created as Success<EconomyTransaction>).value;

    final corrected = await service.correctTransaction(
      original,
      const SaveTransactionRequest(
        type: EconomyTransactionType.expense,
        amountMinor: 2800,
        paymentMethod: EconomyPaymentMethod.wallet,
        category: 'Comida',
      ),
    );

    expect(corrected, isA<Success<EconomyTransaction>>());
    expect((corrected as Success<EconomyTransaction>).value.amountMinor, 2800);
    final rows = await database.select(database.transactions).get();
    expect(rows, hasLength(3));
    expect(
      rows.where((row) => row.relatedTransactionId == original.id),
      hasLength(1),
    );
    expect(rows.where((row) => row.amountMinor == 2800), hasLength(1));

    final snapshot = await repository.loadSnapshot(
      dayStartUtc: DateTime.utc(2026, 8, 27),
      dayEndUtc: DateTime.utc(2026, 8, 28),
      monthStartUtc: DateTime.utc(2026, 8),
      monthEndUtc: DateTime.utc(2026, 9),
    );
    expect((snapshot as Success<EconomySnapshot>).value.totalMinor, -2800);
  });

  test('reservas se derivan y liberar más de lo reservado falla', () async {
    await service.saveTransaction(
      const SaveTransactionRequest(
        type: EconomyTransactionType.income,
        amountMinor: 20000,
      ),
    );
    final created = await service.saveGoal(
      const SaveGoalRequest(
        title: 'Fondo de emergencia',
        targetMinor: 50000,
        dueDate: '2026-12-31',
      ),
    );
    final goal = (created as Success<SavingsGoalSummary>).value;

    final reserved = await service.allocate(
      AllocateGoalRequest(
        goal: goal,
        direction: GoalAllocationDirection.reserve,
        amountMinor: 10000,
      ),
    );
    final updated = (reserved as Success<SavingsGoalSummary>).value;
    expect(updated.reservedMinor, 10000);

    final rejected = await service.allocate(
      AllocateGoalRequest(
        goal: updated,
        direction: GoalAllocationDirection.release,
        amountMinor: 10001,
      ),
    );
    expect(rejected, isA<Failure<SavingsGoalSummary>>());
    final foundGoal = await repository.findGoal(goal.id);
    expect(
      (foundGoal as Success<SavingsGoalSummary?>).value!.reservedMinor,
      10000,
    );
  });

  test('reservar no supera ni el objetivo ni el saldo disponible', () async {
    await service.saveTransaction(
      const SaveTransactionRequest(
        type: EconomyTransactionType.income,
        amountMinor: 5000,
      ),
    );
    final created = await service.saveGoal(
      const SaveGoalRequest(title: 'Equipo', targetMinor: 4000),
    );
    final goal = (created as Success<SavingsGoalSummary>).value;

    final tooLarge = await service.allocate(
      AllocateGoalRequest(
        goal: goal,
        direction: GoalAllocationDirection.reserve,
        amountMinor: 4001,
      ),
    );
    expect(tooLarge, isA<Failure<SavingsGoalSummary>>());

    final first = await service.allocate(
      AllocateGoalRequest(
        goal: goal,
        direction: GoalAllocationDirection.reserve,
        amountMinor: 4000,
      ),
    );
    expect(first, isA<Success<SavingsGoalSummary>>());
    final achieved = (first as Success<SavingsGoalSummary>).value;
    expect(achieved.status, SavingsGoalStatus.achieved);

    final invalidTarget = await service.saveGoal(
      SaveGoalRequest(
        existing: achieved,
        title: achieved.title,
        targetMinor: 3999,
      ),
    );
    expect(invalidTarget, isA<Failure<SavingsGoalSummary>>());

    final otherCreated = await service.saveGoal(
      const SaveGoalRequest(title: 'Otro', targetMinor: 2000),
    );
    final other = (otherCreated as Success<SavingsGoalSummary>).value;
    final noBalance = await service.allocate(
      AllocateGoalRequest(
        goal: other,
        direction: GoalAllocationDirection.reserve,
        amountMinor: 1001,
      ),
    );
    expect(noBalance, isA<Failure<SavingsGoalSummary>>());
  });
}

final class _FixedEconomyClock implements EconomyClock {
  const _FixedEconomyClock(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _SequenceEconomyIds implements EconomyIdGenerator {
  int _next = 0;

  @override
  String nextId() => 'economy-id-${_next++}';
}
