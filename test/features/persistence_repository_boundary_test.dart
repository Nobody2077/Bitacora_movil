import 'dart:io';

import 'package:bitacora_rpg_personal/app/providers/persistence_providers.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/economy/data/drift_economy_repository.dart';
import 'package:bitacora_rpg_personal/features/journal/data/drift_journal_repository.dart';
import 'package:bitacora_rpg_personal/features/missions/data/drift_mission_repository.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/models/mission.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/repositories/mission_repository.dart';
import 'package:bitacora_rpg_personal/features/progress/data/drift_progress_repository.dart';
import 'package:bitacora_rpg_personal/features/settings/data/drift_settings_repository.dart';
import 'package:bitacora_rpg_personal/features/settings/domain/models/app_preferences.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart'
    show AppDatabase;
import 'package:bitacora_rpg_personal/infrastructure/database/daos/economy_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/journal_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/mission_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/notification_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/progress_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/recurrence_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/settings_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/golden_scenario.dart';

void main() {
  test(
    'repositorios convierten Drift al dominio sin filtrar DataClass',
    () async {
      const scenario = GoldenScenario.standard;
      final database = AppDatabase(
        NativeDatabase.memory(),
        utcNowMilliseconds: () => scenario.nowUtcMs,
      );
      addTearDown(database.close);
      await scenario.seed(database);

      final missionRepository = DriftMissionRepository(MissionDao(database));
      final mission = _success(
        await missionRepository.findById(GoldenScenario.laboratoryMissionId),
      );
      expect(mission, isA<Mission>());
      expect(mission?.status, MissionStatus.active);
      expect(mission?.objectives.length, 3);
      expect(
        mission?.objectives.where((item) => item.isCompleted),
        hasLength(1),
      );

      final missions = _success(
        await missionRepository.findScheduledBetween(
          startUtc: _utc(GoldenScenario.localDayStartUtcMs),
          endUtc: _utc(GoldenScenario.localDayEndUtcMs),
        ),
      );
      expect(missions, hasLength(5));

      final economy = _success(
        await DriftEconomyRepository(EconomyDao(database)).loadSnapshot(
          dayStartUtc: _utc(GoldenScenario.localDayStartUtcMs),
          dayEndUtc: _utc(GoldenScenario.localDayEndUtcMs),
          monthStartUtc: _utc(GoldenScenario.localMonthStartUtcMs),
          monthEndUtc: _utc(GoldenScenario.localMonthEndUtcMs),
        ),
      );
      expect(economy.totalMinor, 154000);
      expect(economy.reservedMinor, 30000);
      expect(economy.availableMinor, 124000);
      expect(economy.dayNetMinor, -4200);

      final journal = _success(
        await DriftJournalRepository(JournalDao(database)).findRecent(
          startUtc: _utc(GoldenScenario.localMonthStartUtcMs),
          endUtc: _utc(GoldenScenario.localDayEndUtcMs),
        ),
      );
      expect(journal, hasLength(3));
      expect(
        journal.where((entry) => entry.attachmentCount == 1),
        hasLength(1),
      );

      final progress = _success(
        await DriftProgressRepository(ProgressDao(database)).loadSnapshot(
          dayStartUtc: _utc(GoldenScenario.localDayStartUtcMs),
          dayEndUtc: _utc(GoldenScenario.localDayEndUtcMs),
          weekStartUtc: _utc(GoldenScenario.localWeekStartUtcMs),
        ),
      );
      expect(progress.totalXp, 4450);
      expect(progress.todayXp, 125);
      expect(progress.weekXp, 325);
      expect(progress.byArea, hasLength(5));

      final settingsRepository = DriftSettingsRepository(SettingsDao(database));
      final original = _success(await settingsRepository.load());
      expect(original.hideAmounts, isFalse);

      final changed = AppPreferences(
        themeKey: original.themeKey,
        primaryColorHex: original.primaryColorHex,
        largeText: original.largeText,
        reduceMotion: original.reduceMotion,
        highContrast: original.highContrast,
        hideAmounts: true,
        missionNotifications: original.missionNotifications,
        dailySummary: original.dailySummary,
        soundEnabled: original.soundEnabled,
        autoLockMinutes: original.autoLockMinutes,
        updatedAtUtc: _utc(scenario.nowUtcMs + 1),
      );
      _success(await settingsRepository.save(changed));
      expect(_success(await settingsRepository.load()).hideAmounts, isTrue);
    },
  );

  test(
    'EconomyRepository agrega más de 100 movimientos sin truncarlos',
    () async {
      final database = AppDatabase(
        NativeDatabase.memory(),
        utcNowMilliseconds: () => GoldenScenario.standard.nowUtcMs,
      );
      addTearDown(database.close);
      final occurredAt = GoldenScenario.localDayStartUtcMs + 1000;

      await database.transaction(() async {
        for (var index = 0; index < 101; index++) {
          final suffix = index.toString().padLeft(3, '0');
          await database.customStatement(
            '''
            INSERT INTO transactions (
              id, operation_id, transaction_type, amount_minor,
              occurred_at, created_at
            ) VALUES (?, ?, 'INCOME', 100, ?, ?)
          ''',
            <Object?>[
              'bulk-income-$suffix',
              'bulk-income-operation-$suffix',
              occurredAt,
              occurredAt,
            ],
          );
          await database.customStatement(
            '''
            INSERT INTO transactions (
              id, operation_id, transaction_type, amount_minor,
              occurred_at, created_at
            ) VALUES (?, ?, 'EXPENSE', 30, ?, ?)
          ''',
            <Object?>[
              'bulk-expense-$suffix',
              'bulk-expense-operation-$suffix',
              occurredAt,
              occurredAt,
            ],
          );
        }
      });

      final snapshot = _success(
        await DriftEconomyRepository(EconomyDao(database)).loadSnapshot(
          dayStartUtc: _utc(GoldenScenario.localDayStartUtcMs),
          dayEndUtc: _utc(GoldenScenario.localDayEndUtcMs),
          monthStartUtc: _utc(GoldenScenario.localMonthStartUtcMs),
          monthEndUtc: _utc(GoldenScenario.localMonthEndUtcMs),
        ),
      );
      expect(snapshot.dayIncomeMinor, 10100);
      expect(snapshot.dayExpenseMinor, 3030);
      expect(snapshot.monthIncomeMinor, 10100);
      expect(snapshot.monthExpenseMinor, 3030);
      expect(snapshot.totalMinor, 7070);
    },
  );

  test('ProviderContainer comparte y cierra una sola AppDatabase', () async {
    final container = ProviderContainer(
      overrides: [
        databaseExecutorProvider.overrideWithValue(NativeDatabase.memory()),
      ],
    );

    final database = container.read(appDatabaseProvider);
    expect(identical(database, container.read(appDatabaseProvider)), isTrue);
    expect(container.read(missionDaoProvider), isA<MissionDao>());
    expect(container.read(recurrenceDaoProvider), isA<RecurrenceDao>());
    expect(container.read(notificationDaoProvider), isA<NotificationDao>());
    expect(container.read(economyDaoProvider), isA<EconomyDao>());
    expect(container.read(journalDaoProvider), isA<JournalDao>());
    expect(container.read(progressDaoProvider), isA<ProgressDao>());
    expect(container.read(settingsDaoProvider), isA<SettingsDao>());
    await database.customSelect('SELECT 1').getSingle();

    container.dispose();
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      database.customSelect('SELECT 1').getSingle(),
      throwsA(isA<StateError>()),
    );
  });

  test('contratos de dominio no importan Flutter, Riverpod ni Drift', () {
    final domainFiles = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.contains(
                '${Platform.pathSeparator}domain${Platform.pathSeparator}',
              ) &&
              file.path.endsWith('.dart'),
        );

    for (final file in domainFiles) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('package:flutter')), reason: file.path);
      expect(
        source,
        isNot(contains('package:flutter_riverpod')),
        reason: file.path,
      );
      expect(source, isNot(contains('package:drift')), reason: file.path);
      expect(source, isNot(contains('/infrastructure/')), reason: file.path);
      expect(source, isNot(contains('/data/')), reason: file.path);
    }
  });

  test('repositorios Riverpod admiten override sin abrir persistencia', () {
    final fake = _FakeMissionRepository();
    final container = ProviderContainer(
      overrides: [missionRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    expect(identical(container.read(missionRepositoryProvider), fake), isTrue);
  });
}

DateTime _utc(int milliseconds) =>
    DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);

T _success<T>(Result<T> result) => result.fold<T>(
  onSuccess: (value) => value,
  onFailure: (failure) => throw TestFailure(failure.toString()),
);

final class _FakeMissionRepository implements MissionRepository {
  @override
  Future<Result<Mission>> archive({
    required Mission mission,
    required String eventId,
    required DateTime occurredAtUtc,
  }) async => Success<Mission>(mission);

  @override
  Future<Result<Mission>> create(
    Mission mission, {
    required String eventId,
    required String notificationId,
    required DateTime occurredAtUtc,
  }) async => Success<Mission>(mission);

  @override
  Future<Result<Mission?>> findById(String id) async =>
      const Success<Mission?>(null);

  @override
  Future<Result<Mission?>> findActiveTimer() async =>
      const Success<Mission?>(null);

  @override
  Future<Result<List<MissionArea>>> findVisibleAreas() async =>
      const Success<List<MissionArea>>(<MissionArea>[]);

  @override
  Future<Result<List<Mission>>> findScheduledBetween({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async => const Success<List<Mission>>(<Mission>[]);

  @override
  Future<Result<Mission>> update(
    Mission mission, {
    required String eventId,
    required String notificationId,
    required DateTime occurredAtUtc,
  }) async => Success<Mission>(mission);

  @override
  Future<Result<Mission>> startTimer({
    required String missionId,
    required int expectedRowVersion,
    required MissionStatus expectedStatus,
    required String timeEntryId,
    required String eventId,
    required DateTime occurredAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<Mission>> pauseTimer({
    required String missionId,
    required int expectedRowVersion,
    required String eventId,
    required DateTime occurredAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<Mission>> switchTimer({
    required Mission activeMission,
    required Mission targetMission,
    required String pauseEventId,
    required String timeEntryId,
    required String startEventId,
    required DateTime occurredAtUtc,
  }) => throw UnimplementedError();

  @override
  Stream<Result<List<Mission>>> watchScheduledBetween({
    required DateTime startUtc,
    required DateTime endUtc,
  }) => Stream<Result<List<Mission>>>.value(
    const Success<List<Mission>>(<Mission>[]),
  );

  @override
  Stream<Result<List<Mission>>> watchUpcoming({required DateTime startUtc}) =>
      Stream<Result<List<Mission>>>.value(
        const Success<List<Mission>>(<Mission>[]),
      );

  @override
  Stream<Result<List<Mission>>> watchAll() =>
      Stream<Result<List<Mission>>>.value(
        const Success<List<Mission>>(<Mission>[]),
      );
}
