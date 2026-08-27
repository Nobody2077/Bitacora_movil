import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/access/application/access_session_controller.dart';
import '../../features/access/application/access_session_state.dart';
import '../../features/economy/data/drift_economy_repository.dart';
import '../../features/economy/domain/repositories/economy_repository.dart';
import '../../features/journal/data/drift_journal_repository.dart';
import '../../features/journal/domain/repositories/journal_repository.dart';
import '../../features/missions/application/mission_application_service.dart'
    show SecureMissionIdGenerator, SystemMissionClock;
import '../../features/missions/data/drift_mission_repository.dart';
import '../../features/missions/domain/repositories/mission_repository.dart';
import '../../features/notifications/application/notification_reconciliation_service.dart';
import '../../features/notifications/data/method_channel_mission_notification_platform.dart';
import '../../features/notifications/domain/mission_notification_platform.dart';
import '../../features/progress/data/drift_progress_repository.dart';
import '../../features/progress/domain/repositories/progress_repository.dart';
import '../../features/recurrences/application/recurrence_application_service.dart';
import '../../features/recurrences/data/drift_recurrence_repository.dart';
import '../../features/recurrences/data/method_channel_recurrence_civil_time.dart';
import '../../features/recurrences/domain/repositories/recurrence_repository.dart';
import '../../features/settings/data/drift_settings_repository.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../infrastructure/database/app_database.dart';
import '../../infrastructure/database/connection/encrypted_database_connection.dart';
import '../../infrastructure/database/daos/economy_dao.dart';
import '../../infrastructure/database/daos/journal_dao.dart';
import '../../infrastructure/database/daos/mission_dao.dart';
import '../../infrastructure/database/daos/notification_dao.dart';
import '../../infrastructure/database/daos/progress_dao.dart';
import '../../infrastructure/database/daos/recurrence_dao.dart';
import '../../infrastructure/database/daos/settings_dao.dart';
import '../../infrastructure/database/database_file_locator.dart';
import '../../infrastructure/database/units_of_work/drift_complete_mission_unit_of_work.dart';
import '../../infrastructure/security/database_key_store.dart';
import '../../infrastructure/security/method_channel_database_key_store.dart';
import '../application/commands/complete_mission.dart';
import 'access_dependencies.dart';

final class AccessDatabaseLockedException implements Exception {
  const AccessDatabaseLockedException();

  @override
  String toString() => 'AccessDatabaseLockedException(DATABASE_LOCKED)';
}

/// Punto sustituible para pruebas del límite Android Keystore.
final Provider<DatabaseKeyStore> databaseKeyStoreProvider =
    Provider<DatabaseKeyStore>(
      (Ref ref) => const MethodChannelDatabaseKeyStore(),
    );

/// Identificador estable del material de clave de la base.
///
/// Producción usa exclusivamente `primary`; las pruebas Android debug lo
/// sustituyen por un `test_*` aislado para comprobar el grafo real sin tocar la
/// base del usuario.
final Provider<String> databaseStorageIdProvider = Provider<String>(
  (Ref ref) => 'primary',
);

/// Executor sustituible para pruebas de persistencia sin plugins de plataforma.
///
/// [LazyDatabase] posterga Keystore y apertura de archivo hasta la
/// primera consulta. Por eso declarar estos providers no cambia aún el arranque
/// productivo de la aplicación.
final Provider<QueryExecutor> databaseExecutorProvider =
    Provider<QueryExecutor>((Ref ref) {
      final bool accessGranted = ref.watch(
        accessSessionProvider.select(
          (AccessSessionState session) => session.canBuildProtected,
        ),
      );
      if (!accessGranted) {
        throw const AccessDatabaseLockedException();
      }

      final keyStore = ref.watch(databaseKeyStoreProvider);
      final DatabaseFileLocator locator = ref.watch(
        databaseFileLocatorProvider,
      );
      final String storageId = ref.watch(databaseStorageIdProvider);
      final _DatabaseAccessLease lease = _DatabaseAccessLease();
      ref.onDispose(lease.invalidate);
      return LazyDatabase(() async {
        lease.ensureValid();
        final databaseFile = await locator.resolve();
        lease.ensureValid();
        final QueryExecutor executor = await EncryptedDatabaseConnection(
          keyStore: keyStore,
        ).open(databaseFile: databaseFile, storageId: storageId);
        if (!lease.isValid) {
          await executor.close();
          throw const AccessDatabaseLockedException();
        }
        return executor;
      });
    });

/// Única instancia de base de datos por [ProviderContainer].
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((
  Ref ref,
) {
  final database = AppDatabase(ref.watch(databaseExecutorProvider));
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

/// Mantiene activa la frontera sesión→persistencia desde la raíz visual.
///
/// Los providers normales pueden quedar pausados si solo fueron leídos. Esta
/// escucha activa fuerza su destrucción al cerrar la sesión, incluso cuando no
/// queda ningún consumidor de repositorios montado. Destruir primero la base
/// inicia el cierre del executor; invalidar después el executor cancela además
/// cualquier apertura perezosa que todavía estuviera en curso.
final Provider<void> persistenceAccessGuardProvider = Provider<void>((Ref ref) {
  ref.listen<bool>(
    accessSessionProvider.select(
      (AccessSessionState session) => session.canBuildProtected,
    ),
    (bool? previous, bool next) {
      if (previous == true && !next) {
        ref.invalidate(appDatabaseProvider);
        ref.invalidate(databaseExecutorProvider);
      }
    },
  );
});

/// Dispara la generación de ocurrencias recurrentes pendientes cada vez que
/// la sesión pasa de bloqueada a desbloqueada. La generación es best-effort:
/// un fallo no afecta la sesión ni bloquea la apertura de la app.
final Provider<void> recurrenceGenerationGuardProvider = Provider<void>((
  Ref ref,
) {
  ref.listen<bool>(
    accessSessionProvider.select(
      (AccessSessionState session) => session.canBuildProtected,
    ),
    (bool? previous, bool next) {
      if (next && previous != true) {
        Future.microtask(() async {
          try {
            final RecurrenceDao dao = ref.read(recurrenceDaoProvider);
            final service = RecurrenceApplicationService(
              repository: DriftRecurrenceRepository(dao),
              dao: dao,
              clock: const SystemMissionClock(),
              idGenerator: SecureMissionIdGenerator(),
              civilTime: const MethodChannelRecurrenceCivilTime(),
            );
            await service.generatePendingOccurrences();
            await ref
                .read(notificationReconciliationServiceProvider)
                .reconcile();
          } on Object {
            // best-effort
          }
        });
      }
    },
  );
});

final Provider<MissionDao> missionDaoProvider = Provider<MissionDao>(
  (Ref ref) => MissionDao(ref.watch(appDatabaseProvider)),
);

final Provider<RecurrenceDao> recurrenceDaoProvider = Provider<RecurrenceDao>(
  (Ref ref) => RecurrenceDao(ref.watch(appDatabaseProvider)),
);

final Provider<NotificationDao> notificationDaoProvider =
    Provider<NotificationDao>(
      (Ref ref) => NotificationDao(ref.watch(appDatabaseProvider)),
    );

final Provider<MissionNotificationPlatform>
missionNotificationPlatformProvider = Provider<MissionNotificationPlatform>(
  (Ref ref) => const MethodChannelMissionNotificationPlatform(),
);

final Provider<NotificationReconciliationService>
notificationReconciliationServiceProvider =
    Provider<NotificationReconciliationService>(
      (Ref ref) => NotificationReconciliationService(
        notificationDao: ref.watch(notificationDaoProvider),
        settingsDao: ref.watch(settingsDaoProvider),
        platform: ref.watch(missionNotificationPlatformProvider),
        nowUtc: () => DateTime.now().toUtc(),
      ),
    );

final Provider<EconomyDao> economyDaoProvider = Provider<EconomyDao>(
  (Ref ref) => EconomyDao(ref.watch(appDatabaseProvider)),
);

final Provider<JournalDao> journalDaoProvider = Provider<JournalDao>(
  (Ref ref) => JournalDao(ref.watch(appDatabaseProvider)),
);

final Provider<ProgressDao> progressDaoProvider = Provider<ProgressDao>(
  (Ref ref) => ProgressDao(ref.watch(appDatabaseProvider)),
);

final Provider<SettingsDao> settingsDaoProvider = Provider<SettingsDao>(
  (Ref ref) => SettingsDao(ref.watch(appDatabaseProvider)),
);

final Provider<CompleteMissionUnitOfWork> completeMissionUnitOfWorkProvider =
    Provider<CompleteMissionUnitOfWork>(
      (Ref ref) =>
          DriftCompleteMissionUnitOfWork(ref.watch(appDatabaseProvider)),
    );

final Provider<MissionRepository> missionRepositoryProvider =
    Provider<MissionRepository>(
      (Ref ref) => DriftMissionRepository(ref.watch(missionDaoProvider)),
    );

final Provider<RecurrenceRepository> recurrenceRepositoryProvider =
    Provider<RecurrenceRepository>(
      (Ref ref) => DriftRecurrenceRepository(ref.watch(recurrenceDaoProvider)),
    );

final Provider<EconomyRepository> economyRepositoryProvider =
    Provider<EconomyRepository>(
      (Ref ref) => DriftEconomyRepository(ref.watch(economyDaoProvider)),
    );

final Provider<JournalRepository> journalRepositoryProvider =
    Provider<JournalRepository>(
      (Ref ref) => DriftJournalRepository(ref.watch(journalDaoProvider)),
    );

final Provider<ProgressRepository> progressRepositoryProvider =
    Provider<ProgressRepository>(
      (Ref ref) => DriftProgressRepository(ref.watch(progressDaoProvider)),
    );

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (Ref ref) => DriftSettingsRepository(ref.watch(settingsDaoProvider)),
    );

final class _DatabaseAccessLease {
  bool _valid = true;

  bool get isValid => _valid;

  void invalidate() => _valid = false;

  void ensureValid() {
    if (!_valid) {
      throw const AccessDatabaseLockedException();
    }
  }
}
