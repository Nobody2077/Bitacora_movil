import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/journal/application/journal_application_service.dart';
import 'package:bitacora_rpg_personal/features/journal/data/drift_journal_repository.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/journal_entry.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart'
    as drift;
import 'package:bitacora_rpg_personal/infrastructure/database/daos/journal_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/default_seed_v1.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime nowUtc = DateTime.utc(2026, 8, 27, 18);
  late drift.AppDatabase database;
  late DriftJournalRepository repository;
  late JournalApplicationService service;

  setUp(() {
    database = drift.AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => nowUtc.millisecondsSinceEpoch,
    );
    repository = DriftJournalRepository(JournalDao(database));
    service = JournalApplicationService(
      repository: repository,
      clock: _FixedJournalClock(nowUtc),
      idGenerator: _SequenceJournalIds(),
    );
  });

  tearDown(() => database.close());

  test('crea una entrada manual normalizada y privada', () async {
    final Result<JournalEntry> result = await service.save(
      SaveJournalEntryRequest(
        title: '  Aprendizaje del día  ',
        body: '  Practiqué persistencia local.  ',
        mood: JournalMood.focused,
        isPrivate: true,
        occurredAtUtc: nowUtc,
      ),
    );

    expect(result, isA<Success<JournalEntry>>());
    final JournalEntry entry = (result as Success<JournalEntry>).value;
    expect(entry.title, 'Aprendizaje del día');
    expect(entry.body, 'Practiqué persistencia local.');
    expect(entry.origin, JournalOrigin.manual);
    expect(entry.isPrivate, isTrue);
    expect(await database.select(database.journalEntries).get(), hasLength(1));
  });

  test('vincula una entrada con una misión existente', () async {
    await _insertMission(database, nowUtc);

    final Result<JournalEntry> result = await service.save(
      SaveJournalEntryRequest(
        title: 'Resultado de la misión',
        isPrivate: true,
        occurredAtUtc: nowUtc,
        origin: JournalOrigin.mission,
        missionId: 'mission-source',
      ),
    );

    expect(result, isA<Success<JournalEntry>>());
    final JournalEntry entry = (result as Success<JournalEntry>).value;
    expect(entry.origin, JournalOrigin.mission);
    expect(entry.missionId, 'mission-source');
    expect(entry.transactionId, isNull);
  });

  test('rechaza un vínculo sin identificador antes de escribir', () async {
    final Result<JournalEntry> result = await service.save(
      SaveJournalEntryRequest(
        title: 'Entrada incompleta',
        isPrivate: true,
        occurredAtUtc: nowUtc,
        origin: JournalOrigin.transaction,
      ),
    );

    expect(result, isA<Failure<JournalEntry>>());
    expect(await database.select(database.journalEntries).get(), isEmpty);
  });

  test(
    'edita historia aunque la fuente vinculada haya sido eliminada',
    () async {
      await _insertTransaction(database, nowUtc);
      final JournalEntry created =
          (await service.save(
                    SaveJournalEntryRequest(
                      title: 'Movimiento importante',
                      isPrivate: true,
                      occurredAtUtc: nowUtc,
                      origin: JournalOrigin.transaction,
                      transactionId: 'transaction-source',
                    ),
                  )
                  as Success<JournalEntry>)
              .value;
      await database.customStatement(
        'DELETE FROM transactions WHERE id = ?',
        <Object?>['transaction-source'],
      );
      final JournalEntry withoutSource =
          (await repository.findById(created.id) as Success<JournalEntry?>)
              .value!;
      expect(withoutSource.origin, JournalOrigin.transaction);
      expect(withoutSource.transactionId, isNull);

      final Result<JournalEntry> edited = await service.save(
        SaveJournalEntryRequest(
          existing: withoutSource,
          title: 'Movimiento recordado',
          body: 'La fuente ya no existe, pero la memoria permanece.',
          mood: JournalMood.normal,
          isPrivate: true,
          occurredAtUtc: nowUtc,
        ),
      );

      expect(edited, isA<Success<JournalEntry>>());
      expect(
        (edited as Success<JournalEntry>).value.title,
        'Movimiento recordado',
      );
    },
  );

  test('la cronología reacciona después de crear una entrada', () async {
    final Future<List<Result<List<JournalEntry>>>> emissions = repository
        .watchRecent(
          startUtc: DateTime.utc(2026, 8, 27),
          endUtc: DateTime.utc(2026, 8, 28),
        )
        .take(2)
        .toList();
    await Future<void>.delayed(Duration.zero);

    await service.save(
      SaveJournalEntryRequest(
        title: 'Entrada reactiva',
        isPrivate: false,
        occurredAtUtc: nowUtc,
      ),
    );
    final List<Result<List<JournalEntry>>> values = await emissions;

    expect(values, hasLength(2));
    expect((values.first as Success<List<JournalEntry>>).value, isEmpty);
    expect((values.last as Success<List<JournalEntry>>).value, hasLength(1));
  });
}

Future<void> _insertMission(drift.AppDatabase database, DateTime nowUtc) async {
  await database.customStatement(
    '''
      INSERT INTO missions (
        id, area_id, title, mission_type, importance, priority,
        is_required, status, scheduled_at, xp_planned, row_version
      ) VALUES (?, ?, ?, 'CUSTOM', 'NORMAL', 'NORMAL', 0, 'SCHEDULED', ?, 10, 1)
    ''',
    <Object?>[
      'mission-source',
      DefaultSeedV1.personalAreaId,
      'Misión vinculable',
      nowUtc.millisecondsSinceEpoch,
    ],
  );
}

Future<void> _insertTransaction(
  drift.AppDatabase database,
  DateTime nowUtc,
) async {
  await database.customStatement(
    '''
      INSERT INTO transactions (
        id, operation_id, transaction_type, amount_minor,
        occurred_at, created_at
      ) VALUES (?, ?, 'INCOME', 1000, ?, ?)
    ''',
    <Object?>[
      'transaction-source',
      'transaction-operation',
      nowUtc.millisecondsSinceEpoch,
      nowUtc.millisecondsSinceEpoch,
    ],
  );
}

final class _FixedJournalClock implements JournalClock {
  const _FixedJournalClock(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _SequenceJournalIds implements JournalIdGenerator {
  int _value = 0;

  @override
  String nextId() => 'journal-${_value++}';
}
