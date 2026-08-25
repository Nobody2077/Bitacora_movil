import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/default_seed_v1.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const int _now = 1787521320000;

void main() {
  group('schema v1 constraints', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(
        NativeDatabase.memory(),
        utcNowMilliseconds: () => _now,
      );
    });

    tearDown(() => database.close());

    test('rejects invalid enums, booleans and numeric ranges', () async {
      await _expectConstraint(
        _insertMission(database, id: 'enum-type', missionType: 'UNKNOWN'),
      );
      await _expectConstraint(
        _insertMission(database, id: 'enum-status', status: 'UNKNOWN'),
      );
      await _expectConstraint(
        _insertTransaction(
          database,
          id: 'enum-transaction',
          operationId: 'enum-transaction-op',
          transactionType: 'ADJUSTMENT',
        ),
      );
      await _expectConstraint(
        database.customStatement(
          'UPDATE app_settings SET large_text = 2 WHERE id = 1',
        ),
      );
      await _expectConstraint(
        database.customStatement(
          'UPDATE life_areas SET sort_order = -1 '
          'WHERE id = ?',
          <Object?>[DefaultSeedV1.personalAreaId],
        ),
      );
      await _expectConstraint(
        _insertTransaction(
          database,
          id: 'zero-amount',
          operationId: 'zero-amount-op',
          amountMinor: 0,
        ),
      );

      await _insertMission(database, id: 'range-parent');
      await _expectConstraint(
        _insertTimeEntry(
          database,
          id: 'negative-duration',
          missionId: 'range-parent',
          durationSeconds: -1,
        ),
      );
      await _expectConstraint(
        database.customStatement(
          'UPDATE missions SET row_version = 0 WHERE id = ?',
          const <Object?>['range-parent'],
        ),
      );
    });

    test('rejects invalid civil dates and temporal windows', () async {
      await _insertTemplate(database, id: 'date-template');
      await _expectConstraint(
        _insertRecurrence(
          database,
          id: 'bad-start-date',
          templateId: 'date-template',
          startDate: '2026-02-30',
        ),
      );
      await _expectConstraint(
        _insertRecurrence(
          database,
          id: 'bad-date-window',
          templateId: 'date-template',
          startDate: '2026-08-24',
          endDate: '2026-08-23',
        ),
      );
      await _expectConstraint(
        _insertSavingsGoal(database, id: 'bad-due-date', dueDate: '2026-13-01'),
      );
      await _expectConstraint(
        _insertMission(
          database,
          id: 'bad-availability-window',
          availableFrom: 20,
          scheduledAt: 10,
        ),
      );
      await _expectConstraint(
        _insertMission(
          database,
          id: 'bad-schedule-window',
          scheduledAt: 20,
          expiresAt: 10,
        ),
      );
      await _expectConstraint(
        _insertMission(
          database,
          id: 'bad-expiry-window',
          availableFrom: 20,
          expiresAt: 10,
        ),
      );

      await _insertMission(database, id: 'time-window-parent');
      await _expectConstraint(
        _insertTimeEntry(
          database,
          id: 'bad-time-window',
          missionId: 'time-window-parent',
          startedAt: 20,
          endedAt: 10,
        ),
      );
      await _expectConstraint(
        _insertTransaction(
          database,
          id: 'bad-reversal-window',
          operationId: 'bad-reversal-window-op',
          occurredAt: 20,
          reversedAt: 10,
        ),
      );

      await _insertTitleDefinition(database, id: 'window-title');
      await _expectConstraint(
        database.customStatement(
          '''
            INSERT INTO title_history (
              id, title_id, status, activated_at, deactivated_at
            ) VALUES (?, ?, 'INACTIVE', 20, 10)
          ''',
          const <Object?>['bad-title-window', 'window-title'],
        ),
      );
    });

    test('enforces recurrence mask and local-time boundaries', () async {
      for (final int mask in <int>[0, 128]) {
        final String templateId = 'invalid-mask-template-$mask';
        await _insertTemplate(database, id: templateId);
        await _expectConstraint(
          _insertRecurrence(
            database,
            id: 'invalid-mask-$mask',
            templateId: templateId,
            frequency: 'SPECIFIC_DAYS',
            weekdaysMask: mask,
          ),
        );
      }
      for (final int mask in <int>[1, 127]) {
        final String templateId = 'valid-mask-template-$mask';
        await _insertTemplate(database, id: templateId);
        await _insertRecurrence(
          database,
          id: 'valid-mask-$mask',
          templateId: templateId,
          frequency: 'SPECIFIC_DAYS',
          weekdaysMask: mask,
        );
      }

      for (final int minutes in <int>[-1, 1440]) {
        final String templateId = 'invalid-time-template-$minutes';
        await _insertTemplate(database, id: templateId);
        await _expectConstraint(
          _insertRecurrence(
            database,
            id: 'invalid-time-$minutes',
            templateId: templateId,
            localTimeMinutes: minutes,
          ),
        );
      }
      for (final int minutes in <int>[0, 1439]) {
        final String templateId = 'valid-time-template-$minutes';
        await _insertTemplate(database, id: templateId);
        await _insertRecurrence(
          database,
          id: 'valid-time-$minutes',
          templateId: templateId,
          localTimeMinutes: minutes,
        );
      }

      expect(await _count(database, 'recurrence_rules'), 4);
    });

    test('enforces completed_at in both directions', () async {
      await _expectConstraint(
        _insertMission(
          database,
          id: 'completed-without-date',
          status: 'COMPLETED',
        ),
      );
      await _expectConstraint(
        _insertMission(
          database,
          id: 'active-with-date',
          status: 'ACTIVE',
          completedAt: _now,
        ),
      );

      await _insertMission(
        database,
        id: 'completed-valid',
        status: 'COMPLETED',
        completedAt: _now,
      );
      await _insertMission(
        database,
        id: 'partial-valid',
        status: 'PARTIAL',
        completedAt: _now,
      );
      expect(await _count(database, 'missions'), 2);
    });

    test('enforces approved active and domain uniqueness rules', () async {
      await _expectConstraint(
        database.customStatement(
          '''
            INSERT INTO life_areas (
              id, name, icon_key, color_hex, is_default, is_visible, sort_order
            ) VALUES (?, 'PERSONAL', 'duplicate', '#112233', 0, 1, 10)
          ''',
          const <Object?>['duplicate-active-name'],
        ),
      );
      await _expectConstraint(
        database.customStatement(
          '''
            INSERT INTO life_areas (
              id, name, icon_key, color_hex, is_default, is_visible, sort_order
            ) VALUES (?, 'Another default', 'duplicate', '#112233', 1, 1, 10)
          ''',
          const <Object?>['duplicate-active-default'],
        ),
      );

      await _insertTemplate(database, id: 'unique-template');
      await _insertMission(
        database,
        id: 'occurrence-one',
        templateId: 'unique-template',
        scheduledAt: 100,
      );
      await _expectConstraint(
        _insertMission(
          database,
          id: 'occurrence-two',
          templateId: 'unique-template',
          scheduledAt: 100,
        ),
      );

      await _insertMission(database, id: 'objective-parent');
      await _insertMissionObjective(
        database,
        id: 'objective-one',
        missionId: 'objective-parent',
        position: 0,
      );
      await _expectConstraint(
        _insertMissionObjective(
          database,
          id: 'objective-two',
          missionId: 'objective-parent',
          position: 0,
        ),
      );

      await _insertNotification(
        database,
        id: 'notification-one',
        missionId: 'objective-parent',
      );
      await _expectConstraint(
        _insertNotification(
          database,
          id: 'notification-two',
          missionId: 'objective-parent',
        ),
      );

      await _insertTitleDefinition(database, id: 'unique-current-title');
      await database.customStatement(
        '''
          INSERT INTO title_history (
            id, title_id, status, activated_at, deactivated_at
          ) VALUES (?, ?, 'INACTIVE', 10, 20)
        ''',
        const <Object?>['closed-title-history', 'unique-current-title'],
      );
      await database.customStatement(
        '''
          INSERT INTO title_history (
            id, title_id, status, activated_at, deactivated_at
          ) VALUES (?, ?, 'ACTIVE', 30, NULL)
        ''',
        const <Object?>['active-title-history', 'unique-current-title'],
      );
      await _expectConstraint(
        database.customStatement(
          '''
            INSERT INTO title_history (
              id, title_id, status, activated_at, deactivated_at
            ) VALUES (?, ?, 'EARNED', 40, NULL)
          ''',
          const <Object?>[
            'second-current-title-history',
            'unique-current-title',
          ],
        ),
      );
    });

    test('applies RESTRICT, SET NULL and CASCADE actions', () async {
      await _insertMission(database, id: 'restricted-mission');
      await _insertMissionObjective(
        database,
        id: 'restricted-objective',
        missionId: 'restricted-mission',
        position: 0,
      );
      await _expectConstraint(
        database.customStatement(
          'DELETE FROM missions WHERE id = ?',
          const <Object?>['restricted-mission'],
        ),
      );

      await _insertTemplate(database, id: 'fk-template');
      await database.customStatement(
        '''
          INSERT INTO mission_template_objectives (
            id, template_id, description, position, created_at, updated_at
          ) VALUES (?, ?, 'Child', 0, ?, ?)
        ''',
        const <Object?>['template-child', 'fk-template', _now, _now],
      );
      await _insertRecurrence(
        database,
        id: 'template-recurrence',
        templateId: 'fk-template',
      );
      await _insertMission(
        database,
        id: 'template-occurrence',
        templateId: 'fk-template',
        scheduledAt: 200,
      );

      await database.customStatement(
        'DELETE FROM mission_templates WHERE id = ?',
        const <Object?>['fk-template'],
      );
      final occurrence = await database.customSelect('''
        SELECT template_id FROM missions WHERE id = 'template-occurrence'
      ''').getSingle();
      expect(occurrence.readNullable<String>('template_id'), isNull);
      expect(await _count(database, 'mission_template_objectives'), 0);
      expect(await _count(database, 'recurrence_rules'), 0);
    });

    test(
      'sets nullable transaction, journal and XP references to null',
      () async {
        await _insertMission(database, id: 'set-null-mission');
        await _insertTransaction(
          database,
          id: 'set-null-transaction',
          operationId: 'set-null-transaction-op',
          missionId: 'set-null-mission',
        );
        await _insertJournalEntry(
          database,
          id: 'set-null-journal',
          missionId: 'set-null-mission',
          transactionId: 'set-null-transaction',
        );
        await _insertXp(
          database,
          id: 'set-null-xp',
          sourceType: 'JOURNAL',
          amount: 1,
          journalEntryId: 'set-null-journal',
        );

        await database.customStatement(
          'DELETE FROM missions WHERE id = ?',
          const <Object?>['set-null-mission'],
        );
        final transactionAfterMission = await database.customSelect('''
        SELECT mission_id FROM transactions WHERE id = 'set-null-transaction'
      ''').getSingle();
        final journalAfterMission = await database.customSelect('''
        SELECT mission_id FROM journal_entries WHERE id = 'set-null-journal'
      ''').getSingle();
        expect(
          transactionAfterMission.readNullable<String>('mission_id'),
          isNull,
        );
        expect(journalAfterMission.readNullable<String>('mission_id'), isNull);

        await database.customStatement(
          'DELETE FROM transactions WHERE id = ?',
          const <Object?>['set-null-transaction'],
        );
        final journalAfterTransaction = await database.customSelect('''
        SELECT transaction_id
        FROM journal_entries
        WHERE id = 'set-null-journal'
      ''').getSingle();
        expect(
          journalAfterTransaction.readNullable<String>('transaction_id'),
          isNull,
        );

        await database.customStatement(
          'DELETE FROM journal_entries WHERE id = ?',
          const <Object?>['set-null-journal'],
        );
        final xpAfterJournal = await database.customSelect('''
        SELECT journal_entry_id FROM xp_transactions WHERE id = 'set-null-xp'
      ''').getSingle();
        expect(xpAfterJournal.readNullable<String>('journal_entry_id'), isNull);
      },
    );

    test(
      'enforces singleton settings, colors, parents and title counters',
      () async {
        await _expectConstraint(
          database.customStatement('''
          INSERT INTO app_settings (
            id, theme_key, primary_color, large_text, reduce_motion,
            high_contrast, hide_amounts, mission_notifications, daily_summary,
            sound_enabled, auto_lock_minutes, updated_at
          ) VALUES (2, 'other', '#112233', 0, 0, 0, 0, 1, 1, 1, 5, $_now)
        '''),
        );
        await _expectConstraint(
          database.customStatement(
            '''
            INSERT INTO life_areas (
              id, name, icon_key, color_hex, is_default, is_visible, sort_order
            ) VALUES (?, 'Invalid color', 'test', '#GGGGGG', 0, 1, 10)
          ''',
            const <Object?>['invalid-color'],
          ),
        );
        await _expectConstraint(
          _insertMissionObjective(
            database,
            id: 'orphan-objective',
            missionId: 'missing-mission',
            position: 0,
          ),
        );
        await _expectConstraint(
          database.customStatement(
            '''
            INSERT INTO title_definitions (
              id, name, title_kind, rule_key, threshold, is_active
            ) VALUES (?, 'Invalid threshold', 'PERMANENT', ?, -1, 1)
          ''',
            const <Object?>['invalid-threshold', 'invalid-threshold-rule'],
          ),
        );

        await _insertTitleDefinition(database, id: 'counter-title');
        for (final ({int bestStreak, int recoveryCount, String id}) values
            in <({int bestStreak, int recoveryCount, String id})>[
              (id: 'negative-streak', bestStreak: -1, recoveryCount: 0),
              (id: 'negative-recovery', bestStreak: 0, recoveryCount: -1),
            ]) {
          await _expectConstraint(
            database.customStatement(
              '''
              INSERT INTO title_history (
                id, title_id, status, activated_at,
                best_streak, recovery_count
              ) VALUES (?, 'counter-title', 'INACTIVE', ?, ?, ?)
            ''',
              <Object?>[
                values.id,
                _now,
                values.bestStreak,
                values.recoveryCount,
              ],
            ),
          );
        }
      },
    );

    test(
      'validates journal attachments and cascades them with their entry',
      () async {
        await _insertJournalEntry(database, id: 'attachment-journal');
        await _expectConstraint(
          _insertAttachment(
            database,
            id: 'invalid-mime',
            journalEntryId: 'attachment-journal',
            mimeType: 'image/gif',
          ),
        );
        for (final String hash in <String>['a' * 63, 'A' * 64]) {
          await _expectConstraint(
            _insertAttachment(
              database,
              id: 'invalid-hash-${hash.length}-${hash.codeUnitAt(0)}',
              journalEntryId: 'attachment-journal',
              cipherSha256: hash,
            ),
          );
        }
        await _expectConstraint(
          _insertAttachment(
            database,
            id: 'invalid-position',
            journalEntryId: 'attachment-journal',
            position: -1,
          ),
        );
        await _insertAttachment(
          database,
          id: 'valid-attachment',
          journalEntryId: 'attachment-journal',
        );

        await database.customStatement(
          'DELETE FROM journal_entries WHERE id = ?',
          const <Object?>['attachment-journal'],
        );
        expect(await _count(database, 'journal_attachments'), 0);
      },
    );

    test('allows only one open TIMER WORK segment per mission', () async {
      await _insertMission(database, id: 'timer-parent');
      await _insertTimeEntry(
        database,
        id: 'open-timer',
        missionId: 'timer-parent',
      );
      await _expectConstraint(
        _insertTimeEntry(
          database,
          id: 'second-open-timer',
          missionId: 'timer-parent',
        ),
      );

      await _insertTimeEntry(
        database,
        id: 'open-manual',
        missionId: 'timer-parent',
        source: 'MANUAL',
      );
      await _insertTimeEntry(
        database,
        id: 'open-break',
        missionId: 'timer-parent',
        segmentType: 'BREAK',
      );
      await _insertTimeEntry(
        database,
        id: 'closed-timer',
        missionId: 'timer-parent',
        endedAt: _now,
      );
      expect(await _count(database, 'time_entries'), 4);
    });

    test('enforces operation_id and explicit adjustment direction', () async {
      await _insertTransaction(
        database,
        id: 'adjustment-credit',
        operationId: 'adjustment-credit-op',
        transactionType: 'ADJUSTMENT_CREDIT',
      );
      await _insertTransaction(
        database,
        id: 'adjustment-debit',
        operationId: 'adjustment-debit-op',
        transactionType: 'ADJUSTMENT_DEBIT',
      );
      await _expectConstraint(
        _insertTransaction(
          database,
          id: 'ambiguous-adjustment',
          operationId: 'ambiguous-adjustment-op',
          transactionType: 'ADJUSTMENT',
        ),
      );
      await _expectConstraint(
        _insertTransaction(
          database,
          id: 'duplicate-operation',
          operationId: 'adjustment-credit-op',
        ),
      );

      await _insertSavingsGoal(database, id: 'operation-goal');
      await _insertGoalAllocation(
        database,
        id: 'allocation-one',
        operationId: 'allocation-op',
        goalId: 'operation-goal',
      );
      await _expectConstraint(
        _insertGoalAllocation(
          database,
          id: 'allocation-two',
          operationId: 'allocation-op',
          goalId: 'operation-goal',
        ),
      );

      final types = await database.customSelect('''
        SELECT transaction_type FROM transactions ORDER BY id
      ''').get();
      expect(
        types.map((row) => row.read<String>('transaction_type')).toSet(),
        <String>{'ADJUSTMENT_CREDIT', 'ADJUSTMENT_DEBIT'},
      );
    });

    test('enforces XP sign, reason and mission idempotency', () async {
      await _insertMission(database, id: 'xp-mission-one');
      await _insertMission(database, id: 'xp-mission-two');
      await _insertXp(
        database,
        id: 'xp-mission-award',
        sourceType: 'MISSION',
        amount: 10,
        missionId: 'xp-mission-one',
      );
      await _expectConstraint(
        _insertXp(
          database,
          id: 'xp-mission-duplicate',
          sourceType: 'MISSION',
          amount: 20,
          missionId: 'xp-mission-one',
        ),
      );
      await _expectConstraint(
        _insertXp(
          database,
          id: 'xp-negative-mission',
          sourceType: 'MISSION',
          amount: -1,
          missionId: 'xp-mission-two',
        ),
      );
      await _insertXp(
        database,
        id: 'xp-manual-negative',
        sourceType: 'MANUAL_ADJUSTMENT',
        amount: -5,
        reason: 'Correction',
      );
      await _expectConstraint(
        _insertXp(
          database,
          id: 'xp-manual-without-reason',
          sourceType: 'MANUAL_ADJUSTMENT',
          amount: -5,
          reason: '   ',
        ),
      );
      await _expectConstraint(
        _insertXp(
          database,
          id: 'xp-zero',
          sourceType: 'MANUAL_ADJUSTMENT',
          amount: 0,
          reason: 'Correction',
        ),
      );

      expect(await _count(database, 'xp_transactions'), 2);
    });
  });
}

Future<void> _expectConstraint(Future<void> operation) => expectLater(
  operation,
  throwsA(
    isA<SqliteException>().having(
      (SqliteException error) => error.resultCode,
      'resultCode',
      19,
    ),
  ),
);

Future<void> _insertTemplate(AppDatabase database, {required String id}) =>
    database.customStatement(
      '''
    INSERT INTO mission_templates (
      id, area_id, title, mission_type, is_required, xp_reward, is_active
    ) VALUES (?, ?, ?, 'CUSTOM', 0, 0, 1)
  ''',
      <Object?>[id, DefaultSeedV1.personalAreaId, 'Template $id'],
    );

Future<void> _insertRecurrence(
  AppDatabase database, {
  required String id,
  required String templateId,
  String frequency = 'DAILY',
  int intervalValue = 1,
  int? weekdaysMask,
  int? localTimeMinutes,
  String startDate = '2026-08-24',
  String? endDate,
}) => database.customStatement(
  '''
    INSERT INTO recurrence_rules (
      id, template_id, frequency, interval_value, weekdays_mask,
      local_time_minutes, start_date, end_date, timezone_id
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'America/La_Paz')
  ''',
  <Object?>[
    id,
    templateId,
    frequency,
    intervalValue,
    weekdaysMask,
    localTimeMinutes,
    startDate,
    endDate,
  ],
);

Future<void> _insertMission(
  AppDatabase database, {
  required String id,
  String? templateId,
  String missionType = 'CUSTOM',
  String status = 'DRAFT',
  int? scheduledAt,
  int? availableFrom,
  int? expiresAt,
  int? completedAt,
}) => database.customStatement(
  '''
    INSERT INTO missions (
      id, template_id, area_id, title, mission_type, is_required, status,
      scheduled_at, available_from, expires_at, xp_planned, completed_at
    ) VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, ?, 0, ?)
  ''',
  <Object?>[
    id,
    templateId,
    DefaultSeedV1.personalAreaId,
    'Mission $id',
    missionType,
    status,
    scheduledAt,
    availableFrom,
    expiresAt,
    completedAt,
  ],
);

Future<void> _insertMissionObjective(
  AppDatabase database, {
  required String id,
  required String missionId,
  required int position,
}) => database.customStatement(
  '''
    INSERT INTO mission_objectives (
      id, mission_id, description, position, created_at
    ) VALUES (?, ?, 'Objective', ?, ?)
  ''',
  <Object?>[id, missionId, position, _now],
);

Future<void> _insertTimeEntry(
  AppDatabase database, {
  required String id,
  required String missionId,
  String source = 'TIMER',
  String segmentType = 'WORK',
  int? startedAt = _now,
  int? endedAt,
  int durationSeconds = 0,
}) => database.customStatement(
  '''
    INSERT INTO time_entries (
      id, mission_id, source, segment_type, started_at, ended_at,
      duration_seconds, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  ''',
  <Object?>[
    id,
    missionId,
    source,
    segmentType,
    startedAt,
    endedAt,
    durationSeconds,
    _now,
  ],
);

Future<void> _insertNotification(
  AppDatabase database, {
  required String id,
  required String missionId,
}) => database.customStatement(
  '''
    INSERT INTO notification_schedules (
      id, mission_id, notification_type, notify_at, status,
      created_at, updated_at
    ) VALUES (?, ?, 'START', ?, 'PENDING', ?, ?)
  ''',
  <Object?>[id, missionId, _now, _now, _now],
);

Future<void> _insertTransaction(
  AppDatabase database, {
  required String id,
  required String operationId,
  String? missionId,
  String transactionType = 'INCOME',
  int amountMinor = 1,
  int occurredAt = _now,
  int? reversedAt,
}) => database.customStatement(
  '''
    INSERT INTO transactions (
      id, operation_id, mission_id, transaction_type, amount_minor,
      occurred_at, created_at, reversed_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  ''',
  <Object?>[
    id,
    operationId,
    missionId,
    transactionType,
    amountMinor,
    occurredAt,
    _now,
    reversedAt,
  ],
);

Future<void> _insertSavingsGoal(
  AppDatabase database, {
  required String id,
  String? dueDate,
}) => database.customStatement(
  '''
    INSERT INTO savings_goals (
      id, title, target_minor, status, due_date, created_at
    ) VALUES (?, ?, 100, 'ACTIVE', ?, ?)
  ''',
  <Object?>[id, 'Goal $id', dueDate, _now],
);

Future<void> _insertGoalAllocation(
  AppDatabase database, {
  required String id,
  required String operationId,
  required String goalId,
}) => database.customStatement(
  '''
    INSERT INTO goal_allocations (
      id, operation_id, goal_id, direction, amount_minor,
      occurred_at, created_at
    ) VALUES (?, ?, ?, 'RESERVE', 1, ?, ?)
  ''',
  <Object?>[id, operationId, goalId, _now, _now],
);

Future<void> _insertTitleDefinition(
  AppDatabase database, {
  required String id,
}) => database.customStatement(
  '''
    INSERT INTO title_definitions (
      id, name, title_kind, rule_key, is_active
    ) VALUES (?, ?, 'TEMPORARY', ?, 1)
  ''',
  <Object?>[id, 'Title $id', 'rule-$id'],
);

Future<void> _insertJournalEntry(
  AppDatabase database, {
  required String id,
  String? missionId,
  String? transactionId,
}) => database.customStatement(
  '''
    INSERT INTO journal_entries (
      id, origin_type, mission_id, transaction_id, title, is_private,
      occurred_at, created_at, updated_at
    ) VALUES (?, 'SYSTEM', ?, ?, ?, 0, ?, ?, ?)
  ''',
  <Object?>[id, missionId, transactionId, 'Journal $id', _now, _now, _now],
);

Future<void> _insertAttachment(
  AppDatabase database, {
  required String id,
  required String journalEntryId,
  String mimeType = 'image/jpeg',
  String cipherSha256 =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  int position = 0,
}) => database.customStatement(
  '''
    INSERT INTO journal_attachments (
      id, journal_entry_id, kind, storage_name, mime_type, byte_length,
      cipher_sha256, width_px, height_px, position, created_at
    ) VALUES (?, ?, 'PHOTO', ?, ?, 1, ?, 1, 1, ?, ?)
  ''',
  <Object?>[
    id,
    journalEntryId,
    '$id.enc',
    mimeType,
    cipherSha256,
    position,
    _now,
  ],
);

Future<void> _insertXp(
  AppDatabase database, {
  required String id,
  required String sourceType,
  required int amount,
  String? missionId,
  String? journalEntryId,
  String? reason,
}) => database.customStatement(
  '''
    INSERT INTO xp_transactions (
      id, area_id, mission_id, journal_entry_id, source_type, amount,
      reason, occurred_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  ''',
  <Object?>[
    id,
    DefaultSeedV1.personalAreaId,
    missionId,
    journalEntryId,
    sourceType,
    amount,
    reason,
    _now,
  ],
);

Future<int> _count(AppDatabase database, String table) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS value FROM "$table"')
      .getSingle();
  return row.read<int>('value');
}
