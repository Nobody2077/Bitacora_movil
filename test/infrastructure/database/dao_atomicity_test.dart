import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/economy_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/journal_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/mission_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/notification_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/progress_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/recurrence_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/settings_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/default_seed_v1.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const int _now = 1787521320000;

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => _now,
    );
  });

  tearDown(() => database.close());

  test(
    'mission and notification intent commit or roll back together',
    () async {
      final dao = MissionDao(database);
      await database
          .into(database.missions)
          .insert(
            _mission(
              id: 'existing-mission',
              status: 'SCHEDULED',
              scheduledAt: _now + 3600000,
            ),
          );
      await database
          .into(database.notificationSchedules)
          .insert(
            NotificationSchedulesCompanion.insert(
              id: 'duplicate-notification',
              missionId: 'existing-mission',
              notificationType: 'START',
              notifyAt: _now + 3600000,
              status: 'PENDING',
              createdAt: _now,
              updatedAt: _now,
            ),
          );

      await expectLater(
        dao.insertAggregate(
          mission: _mission(
            id: 'new-mission',
            status: 'SCHEDULED',
            scheduledAt: _now + 7200000,
          ),
          objectives: <MissionObjectivesCompanion>[
            MissionObjectivesCompanion.insert(
              id: 'new-objective',
              missionId: 'new-mission',
              description: 'Objetivo atómico',
              position: 0,
              createdAt: _now,
            ),
          ],
          events: <MissionEventsCompanion>[
            MissionEventsCompanion.insert(
              id: 'new-event',
              missionId: 'new-mission',
              eventType: 'CREATED',
              toStatus: const Value<String?>('SCHEDULED'),
              occurredAt: _now,
            ),
          ],
          notifications: <NotificationSchedulesCompanion>[
            NotificationSchedulesCompanion.insert(
              id: 'duplicate-notification',
              missionId: 'new-mission',
              notificationType: 'START',
              notifyAt: _now + 7200000,
              status: 'PENDING',
              createdAt: _now,
              updatedAt: _now,
            ),
          ],
        ),
        throwsA(anything),
      );

      expect(await dao.findById('new-mission'), null);
      expect(
        await (database.select(
          database.missionObjectives,
        )..where((table) => table.missionId.equals('new-mission'))).get(),
        isEmpty,
      );
      expect(
        await (database.select(
          database.missionEvents,
        )..where((table) => table.missionId.equals('new-mission'))).get(),
        isEmpty,
      );
    },
  );

  test('status and MissionEvent commit or roll back together', () async {
    final dao = MissionDao(database);
    await database.into(database.missions).insert(_mission(id: 'mission-1'));

    final transitioned = await dao.transitionStatusWithEvent(
      missionId: 'mission-1',
      expectedRowVersion: 1,
      expectedStatus: 'DRAFT',
      nextStatus: 'SCHEDULED',
      completedAt: const Value<int?>(null),
      event: MissionEventsCompanion.insert(
        id: 'event-1',
        missionId: 'mission-1',
        eventType: 'UPDATED',
        fromStatus: const Value<String?>('DRAFT'),
        toStatus: const Value<String?>('SCHEDULED'),
        occurredAt: _now,
      ),
    );

    expect(transitioned.status, 'SCHEDULED');
    expect(transitioned.rowVersion, 2);
    expect(await database.select(database.missionEvents).get(), hasLength(1));

    await database
        .into(database.missionEvents)
        .insert(
          MissionEventsCompanion.insert(
            id: 'duplicate-event',
            missionId: 'mission-1',
            eventType: 'UPDATED',
            fromStatus: const Value<String?>('SCHEDULED'),
            toStatus: const Value<String?>('AVAILABLE'),
            occurredAt: _now + 1,
          ),
        );

    await expectLater(
      dao.transitionStatusWithEvent(
        missionId: 'mission-1',
        expectedRowVersion: 2,
        expectedStatus: 'SCHEDULED',
        nextStatus: 'AVAILABLE',
        completedAt: const Value<int?>(null),
        event: MissionEventsCompanion.insert(
          id: 'duplicate-event',
          missionId: 'mission-1',
          eventType: 'AVAILABLE',
          fromStatus: const Value<String?>('SCHEDULED'),
          toStatus: const Value<String?>('AVAILABLE'),
          occurredAt: _now + 2,
        ),
      ),
      throwsA(anything),
    );

    final afterRollback = await dao.findById('mission-1');
    expect(afterRollback?.status, 'SCHEDULED');
    expect(afterRollback?.rowVersion, 2);

    expect(
      () => dao.updateWithRowVersion(
        missionId: 'mission-1',
        expectedRowVersion: 2,
        changes: const MissionsCompanion(status: Value<String>('AVAILABLE')),
      ),
      throwsArgumentError,
    );
  });

  test(
    'recurrence generation coordinates occurrence, children and recovery date',
    () async {
      final dao = RecurrenceDao(database);
      await database
          .into(database.missionTemplates)
          .insert(
            MissionTemplatesCompanion.insert(
              id: 'template-1',
              areaId: DefaultSeedV1.studiesAreaId,
              title: 'Estudiar redes',
              missionType: 'RECURRING',
              isRequired: 1,
              xpReward: 50,
              isActive: 1,
            ),
          );
      await database
          .into(database.missionTemplateObjectives)
          .insert(
            MissionTemplateObjectivesCompanion.insert(
              id: 'template-objective-1',
              templateId: 'template-1',
              description: 'Leer capítulo',
              position: 0,
              createdAt: _now,
              updatedAt: _now,
            ),
          );
      await database
          .into(database.recurrenceRules)
          .insert(
            RecurrenceRulesCompanion.insert(
              id: 'rule-1',
              templateId: 'template-1',
              frequency: 'DAILY',
              intervalValue: 1,
              startDate: '2026-08-24',
              timezoneId: 'America/La_Paz',
            ),
          );

      final occurrence = _mission(
        id: 'occurrence-1',
        templateId: 'template-1',
        status: 'SCHEDULED',
        scheduledAt: _now + 3600000,
      );
      final first = await dao.generateOccurrenceAtomically(
        occurrence: occurrence,
        createdAtUtcMs: _now,
        processedLocalDate: '2026-08-24',
        objectiveIdFactory: () => 'objective-1',
        createdEvent: MissionEventsCompanion.insert(
          id: 'created-event-1',
          missionId: 'occurrence-1',
          eventType: 'CREATED',
          toStatus: const Value<String?>('SCHEDULED'),
          occurredAt: _now,
        ),
        notifications: <NotificationSchedulesCompanion>[
          NotificationSchedulesCompanion.insert(
            id: 'notification-1',
            missionId: 'occurrence-1',
            notificationType: 'START',
            notifyAt: _now + 3600000,
            status: 'PENDING',
            createdAt: _now,
            updatedAt: _now,
          ),
        ],
      );

      expect(first.created, isTrue);
      expect(await database.select(database.missions).get(), hasLength(1));
      expect(
        await database.select(database.missionObjectives).get(),
        hasLength(1),
      );
      expect(await database.select(database.missionEvents).get(), hasLength(1));
      expect(
        await database.select(database.notificationSchedules).get(),
        hasLength(1),
      );
      expect(
        (await database.select(database.recurrenceRules).getSingle())
            .lastGeneratedOn,
        '2026-08-24',
      );

      final repeated = await dao.generateOccurrenceAtomically(
        occurrence: occurrence,
        createdAtUtcMs: _now,
        processedLocalDate: '2026-08-24',
        objectiveIdFactory: () => throw StateError('must not copy twice'),
        createdEvent: MissionEventsCompanion.insert(
          id: 'created-event-1',
          missionId: 'occurrence-1',
          eventType: 'CREATED',
          toStatus: const Value<String?>('SCHEDULED'),
          occurredAt: _now,
        ),
        notifications: <NotificationSchedulesCompanion>[
          NotificationSchedulesCompanion.insert(
            id: 'notification-1',
            missionId: 'occurrence-1',
            notificationType: 'START',
            notifyAt: _now + 3600000,
            status: 'PENDING',
            createdAt: _now,
            updatedAt: _now,
          ),
        ],
      );
      expect(repeated.created, isFalse);
      expect(await database.select(database.missionEvents).get(), hasLength(1));

      await expectLater(
        dao.generateOccurrenceAtomically(
          occurrence: occurrence.copyWith(
            title: const Value<String>('Payload divergente'),
          ),
          createdAtUtcMs: _now,
          processedLocalDate: '2026-08-24',
          objectiveIdFactory: () => throw StateError('must not copy twice'),
          createdEvent: MissionEventsCompanion.insert(
            id: 'created-event-1',
            missionId: 'occurrence-1',
            eventType: 'CREATED',
            toStatus: const Value<String?>('SCHEDULED'),
            occurredAt: _now,
          ),
          notifications: <NotificationSchedulesCompanion>[
            NotificationSchedulesCompanion.insert(
              id: 'notification-1',
              missionId: 'occurrence-1',
              notificationType: 'START',
              notifyAt: _now + 3600000,
              status: 'PENDING',
              createdAt: _now,
              updatedAt: _now,
            ),
          ],
        ),
        throwsA(anything),
      );

      final failingOccurrence = _mission(
        id: 'occurrence-2',
        templateId: 'template-1',
        status: 'SCHEDULED',
        scheduledAt: _now + 86400000,
      );
      await expectLater(
        dao.generateOccurrenceAtomically(
          occurrence: failingOccurrence,
          createdAtUtcMs: _now,
          processedLocalDate: '2026-08-25',
          objectiveIdFactory: () => 'objective-2',
          createdEvent: MissionEventsCompanion.insert(
            id: 'created-event-1',
            missionId: 'occurrence-2',
            eventType: 'CREATED',
            toStatus: const Value<String?>('SCHEDULED'),
            occurredAt: _now,
          ),
        ),
        throwsA(anything),
      );

      expect(await database.select(database.missions).get(), hasLength(1));
      expect(
        await database.select(database.missionObjectives).get(),
        hasLength(1),
      );
      expect(
        (await database.select(database.recurrenceRules).getSingle())
            .lastGeneratedOn,
        '2026-08-24',
      );
    },
  );

  test(
    'period totals aggregate the full interval without pagination',
    () async {
      final dao = EconomyDao(database);
      final movements = <LedgerTransactionInput>[
        const LedgerTransactionInput(
          id: 'income-1',
          operationId: 'income-operation-1',
          transactionType: 'INCOME',
          amountMinor: 1000,
          occurredAtUtcMs: _now,
          createdAtUtcMs: _now,
        ),
        const LedgerTransactionInput(
          id: 'refund-1',
          operationId: 'refund-operation-1',
          transactionType: 'REFUND',
          amountMinor: 250,
          occurredAtUtcMs: _now + 1,
          createdAtUtcMs: _now + 1,
        ),
        const LedgerTransactionInput(
          id: 'expense-1',
          operationId: 'expense-operation-1',
          transactionType: 'EXPENSE',
          amountMinor: 400,
          occurredAtUtcMs: _now + 2,
          createdAtUtcMs: _now + 2,
        ),
        const LedgerTransactionInput(
          id: 'outside-1',
          operationId: 'outside-operation-1',
          transactionType: 'ADJUSTMENT_CREDIT',
          amountMinor: 9999,
          occurredAtUtcMs: _now + 10,
          createdAtUtcMs: _now + 10,
        ),
      ];
      for (final movement in movements) {
        await dao.writeTransaction(movement);
      }

      final totals = await dao.totalsForPeriod(
        startUtcMs: _now,
        endUtcMs: _now + 10,
      );
      expect(totals.incomeMinor, 1250);
      expect(totals.expenseMinor, 400);
      expect(totals.netMinor, 850);

      final watched = await dao
          .watchTotalsForPeriod(startUtcMs: _now, endUtcMs: _now + 10)
          .first;
      expect(watched.incomeMinor, totals.incomeMinor);
      expect(watched.expenseMinor, totals.expenseMinor);
    },
  );

  test(
    'RELEASE is bounded and reversal is the only compensation path',
    () async {
      final dao = EconomyDao(database);
      await dao.insertGoal(
        SavingsGoalsCompanion.insert(
          id: 'goal-1',
          title: 'Fondo de emergencia',
          targetMinor: 5000,
          status: 'ACTIVE',
          createdAt: _now,
        ),
      );
      await dao.writeTransaction(
        const LedgerTransactionInput(
          id: 'reserve-funds',
          operationId: 'reserve-funds-operation',
          transactionType: 'INCOME',
          amountMinor: 1000,
          occurredAtUtcMs: _now,
          createdAtUtcMs: _now,
        ),
      );
      await dao.allocate(
        const GoalAllocationInput(
          id: 'reserve-1',
          operationId: 'reserve-operation-1',
          goalId: 'goal-1',
          direction: 'RESERVE',
          amountMinor: 500,
          occurredAtUtcMs: _now,
          createdAtUtcMs: _now,
        ),
      );
      await expectLater(
        dao.allocate(
          const GoalAllocationInput(
            id: 'release-too-much',
            operationId: 'release-too-much-operation',
            goalId: 'goal-1',
            direction: 'RELEASE',
            amountMinor: 501,
            occurredAtUtcMs: _now + 1,
            createdAtUtcMs: _now + 1,
          ),
        ),
        throwsA(anything),
      );
      expect(await dao.reservedForGoal('goal-1'), 500);

      const original = LedgerTransactionInput(
        id: 'expense-original',
        operationId: 'expense-original-operation',
        transactionType: 'EXPENSE',
        amountMinor: 700,
        occurredAtUtcMs: _now,
        createdAtUtcMs: _now,
      );
      const reversal = LedgerTransactionInput(
        id: 'expense-reversal',
        operationId: 'expense-reversal-operation',
        relatedTransactionId: 'expense-original',
        transactionType: 'REFUND',
        amountMinor: 700,
        occurredAtUtcMs: _now + 2,
        createdAtUtcMs: _now + 2,
      );
      await dao.writeTransaction(original);
      expect(() => dao.writeTransaction(reversal), throwsArgumentError);

      final reversed = await dao.reverseTransactionAtomically(
        originalTransactionId: original.id,
        reversal: reversal,
        reversedAtUtcMs: _now + 2,
      );
      expect(reversed.created, isTrue);
      expect(reversed.original.reversedAt, _now + 2);

      final retry = await dao.reverseTransactionAtomically(
        originalTransactionId: original.id,
        reversal: reversal,
        reversedAtUtcMs: _now + 2,
      );
      expect(retry.created, isFalse);
      expect(await database.select(database.transactions).get(), hasLength(3));
    },
  );

  test(
    'journal history remains editable after its source is SET NULL',
    () async {
      final economyDao = EconomyDao(database);
      await economyDao.writeTransaction(
        const LedgerTransactionInput(
          id: 'journal-source',
          operationId: 'journal-source-operation',
          transactionType: 'INCOME',
          amountMinor: 100,
          occurredAtUtcMs: _now,
          createdAtUtcMs: _now,
        ),
      );
      final journalDao = JournalDao(database);
      await journalDao.insertAggregate(
        entry: JournalEntriesCompanion.insert(
          id: 'journal-1',
          originType: 'TRANSACTION',
          transactionId: const Value<String?>('journal-source'),
          title: 'Ingreso registrado',
          isPrivate: 1,
          occurredAt: _now,
          createdAt: _now,
          updatedAt: _now,
        ),
      );

      await (database.delete(
        database.transactions,
      )..where((table) => table.id.equals('journal-source'))).go();
      expect(
        (await database.select(database.journalEntries).getSingle())
            .transactionId,
        equals(null),
      );

      final archived = await journalDao.archiveEntry(
        entryId: 'journal-1',
        archivedAtUtcMs: _now + 1,
        updatedAtUtcMs: _now + 1,
      );
      expect(archived.archivedAt, _now + 1);
      await expectLater(
        journalDao.updateEntry(
          entryId: 'journal-1',
          changes: const JournalEntriesCompanion(
            transactionId: Value<String?>('missing-transaction'),
          ),
        ),
        throwsA(anything),
      );
    },
  );

  test(
    'current titles reject closed or divergent idempotent payloads',
    () async {
      final dao = ProgressDao(database);
      await dao.putTitleDefinition(
        TitleDefinitionsCompanion.insert(
          id: 'title-1',
          name: 'Constante',
          titleKind: 'DYNAMIC',
          ruleKey: 'streak.current',
          isActive: 1,
        ),
      );
      final current = TitleHistoryCompanion.insert(
        id: 'title-history-1',
        titleId: 'title-1',
        status: 'ACTIVE',
        activatedAt: _now,
        bestStreak: const Value<int>(4),
      );
      await dao.recordCurrentTitle(history: current, replacedAtUtcMs: _now);
      final retry = await dao.recordCurrentTitle(
        history: current,
        replacedAtUtcMs: _now,
      );
      expect(retry.bestStreak, 4);

      await expectLater(
        dao.recordCurrentTitle(
          history: current.copyWith(bestStreak: const Value<int>(5)),
          replacedAtUtcMs: _now,
        ),
        throwsA(anything),
      );
      expect(
        () => dao.recordCurrentTitle(
          history: TitleHistoryCompanion.insert(
            id: 'closed-current',
            titleId: 'title-1',
            status: 'ACTIVE',
            activatedAt: _now,
            deactivatedAt: Value<int?>(_now + 1),
          ),
          replacedAtUtcMs: _now,
        ),
        throwsArgumentError,
      );
    },
  );

  test('notification deletion requires DRAFT and terminal schedules', () async {
    final missionDao = MissionDao(database);
    final notificationDao = NotificationDao(database);
    await database.into(database.missions).insert(_mission(id: 'draft-1'));
    await notificationDao.scheduleIfAbsent(
      NotificationSchedulesCompanion.insert(
        id: 'draft-notification',
        missionId: 'draft-1',
        notificationType: 'START',
        notifyAt: _now,
        status: 'PENDING',
        createdAt: _now,
        updatedAt: _now,
      ),
    );
    await expectLater(
      notificationDao.deleteForDraftMission('draft-1'),
      throwsA(anything),
    );
    await notificationDao.transitionStatus(
      scheduleId: 'draft-notification',
      allowedCurrentStatuses: const <String>{'PENDING'},
      nextStatus: 'CANCELLED',
      updatedAtUtcMs: _now + 1,
    );
    expect(await notificationDao.deleteForDraftMission('draft-1'), 1);

    await database
        .into(database.missionEvents)
        .insert(
          MissionEventsCompanion.insert(
            id: 'draft-history',
            missionId: 'draft-1',
            eventType: 'CREATED',
            toStatus: const Value<String?>('DRAFT'),
            occurredAt: _now,
          ),
        );
    await expectLater(
      missionDao.deleteDraftAggregate('draft-1'),
      throwsA(anything),
    );
    expect(await missionDao.findById('draft-1'), isA<Mission>());

    await database
        .into(database.missions)
        .insert(
          _mission(id: 'scheduled-1', status: 'SCHEDULED', scheduledAt: _now),
        );
    await notificationDao.scheduleIfAbsent(
      NotificationSchedulesCompanion.insert(
        id: 'scheduled-notification',
        missionId: 'scheduled-1',
        notificationType: 'START',
        notifyAt: _now,
        status: 'CANCELLED',
        createdAt: _now,
        updatedAt: _now,
      ),
    );
    await expectLater(
      notificationDao.deleteForDraftMission('scheduled-1'),
      throwsA(anything),
    );
  });

  test('empty due filter emits and reserved metadata stays internal', () async {
    final notificationDao = NotificationDao(database);
    expect(
      await notificationDao
          .watchDue(throughUtcMs: _now, statuses: const <String>{})
          .first,
      isEmpty,
    );

    final settingsDao = SettingsDao(database);
    final schemaVersion = await settingsDao.getMetadata('schema_version');
    await expectLater(
      settingsDao.putMetadata(
        key: 'schema_version',
        value: '999',
        updatedAtUtcMs: _now,
      ),
      throwsArgumentError,
    );
    expect(await settingsDao.getMetadata('schema_version'), schemaVersion);
  });
}

MissionsCompanion _mission({
  required String id,
  String? templateId,
  String status = 'DRAFT',
  int? scheduledAt,
}) {
  return MissionsCompanion.insert(
    id: id,
    templateId: Value<String?>(templateId),
    areaId: DefaultSeedV1.studiesAreaId,
    title: 'Misión $id',
    missionType: templateId == null ? 'PRIMARY' : 'RECURRING',
    isRequired: 0,
    status: status,
    scheduledAt: Value<int?>(scheduledAt),
    xpPlanned: 25,
  );
}
