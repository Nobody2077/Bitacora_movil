import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/journal/application/daily_close_application_service.dart';
import 'package:bitacora_rpg_personal/features/journal/application/journal_application_service.dart';
import 'package:bitacora_rpg_personal/features/journal/data/drift_daily_close_repository.dart';
import 'package:bitacora_rpg_personal/features/journal/data/drift_journal_repository.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/journal_entry.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart'
    as drift;
import 'package:bitacora_rpg_personal/infrastructure/database/daos/daily_close_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/journal_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/default_seed_v1.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime fixedUtc = DateTime.utc(2026, 8, 27, 21);
  final DateTime localDay = DateTime(2026, 8, 27);
  late drift.AppDatabase database;
  late DriftDailyCloseRepository dailyCloseRepository;
  late DriftJournalRepository journalRepository;
  late DailyCloseApplicationService service;

  setUp(() {
    database = drift.AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => fixedUtc.millisecondsSinceEpoch,
    );
    dailyCloseRepository = DriftDailyCloseRepository(DailyCloseDao(database));
    journalRepository = DriftJournalRepository(JournalDao(database));
    service = DailyCloseApplicationService(
      dailyCloseRepository: dailyCloseRepository,
      journalRepository: journalRepository,
      clock: _FixedJournalClock(fixedUtc),
    );
  });

  tearDown(() => database.close());

  test('carga resumen del día con misiones, XP, tiempo y finanzas', () async {
    await _insertCompletedMission(database, fixedUtc);
    await _insertPendingRequiredMission(database, fixedUtc);
    await _insertXpTransaction(database, fixedUtc, 50);
    await _insertFinancialTransaction(database, fixedUtc, 1000, 'INCOME');

    final Result<DailyCloseViewData> result = await service.load(localDay);

    expect(result, isA<Success<DailyCloseViewData>>());
    final DailyCloseViewData data =
        (result as Success<DailyCloseViewData>).value;
    expect(data.summary.completedMissions, hasLength(1));
    expect(data.summary.completedMissions.first.title, 'Misión completada');
    expect(data.summary.requiredPendingMissions, hasLength(1));
    expect(
      data.summary.requiredPendingMissions.first.title,
      'Misión pendiente obligatoria',
    );
    expect(data.summary.xpEarned, 50);
    expect(data.summary.incomeMinor, 1000);
    expect(data.summary.expenseMinor, 0);
    expect(data.summary.balanceMinor, 1000);
    expect(data.reflectionEntry, isNull);
  });

  test('guarda y actualiza la reflexión diaria en Bitácora', () async {
    final Result<JournalEntry?> createResult = await service.saveReflection(
      localDay: localDay,
      reflection: 'Hoy fue un día de gran avance en arquitectura local.',
    );

    expect(createResult, isA<Success<JournalEntry?>>());
    final JournalEntry? created =
        (createResult as Success<JournalEntry?>).value;
    expect(created, isNotNull);
    expect(created!.id, dailyCloseEntryId(localDay));
    expect(created.title, dailyCloseTitle(localDay));
    expect(
      created.body,
      'Hoy fue un día de gran avance en arquitectura local.',
    );
    expect(created.origin, JournalOrigin.system);

    // Cargar nuevamente el cierre diario confirma que la reflexión se recupera
    final Result<DailyCloseViewData> loaded = await service.load(localDay);
    expect(loaded, isA<Success<DailyCloseViewData>>());
    expect(
      (loaded as Success<DailyCloseViewData>).value.reflectionEntry?.body,
      'Hoy fue un día de gran avance en arquitectura local.',
    );

    // Actualizar reflexión
    final Result<JournalEntry?> updateResult = await service.saveReflection(
      localDay: localDay,
      reflection: 'Reflexión actualizada con nuevas conclusiones.',
    );
    expect(updateResult, isA<Success<JournalEntry?>>());
    expect(
      (updateResult as Success<JournalEntry?>).value?.body,
      'Reflexión actualizada con nuevas conclusiones.',
    );
  });

  test('rechaza una reflexión que supere los 4000 caracteres', () async {
    final String tooLong = List.filled(4001, 'a').join();
    final Result<JournalEntry?> result = await service.saveReflection(
      localDay: localDay,
      reflection: tooLong,
    );

    expect(result, isA<Failure<JournalEntry?>>());
  });
}

Future<void> _insertCompletedMission(
  drift.AppDatabase database,
  DateTime timeUtc,
) async {
  await database.customStatement(
    '''
      INSERT INTO missions (
        id, area_id, title, mission_type, importance, priority,
        is_required, status, scheduled_at, completed_at, xp_planned, row_version
      ) VALUES (?, ?, ?, 'CUSTOM', 'NORMAL', 'NORMAL', 0, 'COMPLETED', ?, ?, 10, 1)
    ''',
    <Object?>[
      'mission-completed-1',
      DefaultSeedV1.personalAreaId,
      'Misión completada',
      timeUtc.millisecondsSinceEpoch,
      timeUtc.millisecondsSinceEpoch,
    ],
  );
}

Future<void> _insertPendingRequiredMission(
  drift.AppDatabase database,
  DateTime timeUtc,
) async {
  await database.customStatement(
    '''
      INSERT INTO missions (
        id, area_id, title, mission_type, importance, priority,
        is_required, status, scheduled_at, xp_planned, row_version
      ) VALUES (?, ?, ?, 'CUSTOM', 'NORMAL', 'NORMAL', 1, 'SCHEDULED', ?, 10, 1)
    ''',
    <Object?>[
      'mission-pending-req-1',
      DefaultSeedV1.personalAreaId,
      'Misión pendiente obligatoria',
      timeUtc.millisecondsSinceEpoch,
    ],
  );
}

Future<void> _insertXpTransaction(
  drift.AppDatabase database,
  DateTime timeUtc,
  int amount,
) async {
  await database.customStatement(
    '''
      INSERT INTO xp_transactions (
        id, area_id, source_type, amount, occurred_at
      ) VALUES (?, ?, 'MISSION', ?, ?)
    ''',
    <Object?>[
      'xp-trans-1',
      DefaultSeedV1.personalAreaId,
      amount,
      timeUtc.millisecondsSinceEpoch,
    ],
  );
}

Future<void> _insertFinancialTransaction(
  drift.AppDatabase database,
  DateTime timeUtc,
  int amountMinor,
  String type,
) async {
  await database.customStatement(
    '''
      INSERT INTO transactions (
        id, operation_id, transaction_type, amount_minor,
        occurred_at, created_at
      ) VALUES (?, ?, ?, ?, ?, ?)
    ''',
    <Object?>[
      'trans-fin-1',
      'op-fin-1',
      type,
      amountMinor,
      timeUtc.millisecondsSinceEpoch,
      timeUtc.millisecondsSinceEpoch,
    ],
  );
}

final class _FixedJournalClock implements JournalClock {
  const _FixedJournalClock(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}
