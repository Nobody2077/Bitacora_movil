import 'package:bitacora_rpg_personal/app/providers/persistence_providers.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_controller.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_state.dart';
import 'package:bitacora_rpg_personal/features/access/domain/biometric_authenticator.dart';
import 'package:bitacora_rpg_personal/infrastructure/security/database_key_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bloqueado rechaza DB antes de construir Keystore', () {
    var keyStoreBuilds = 0;
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accessSessionSeedProvider.overrideWithValue(_lockedSession),
        databaseKeyStoreProvider.overrideWith((Ref ref) {
          keyStoreBuilds += 1;
          return const _NeverDatabaseKeyStore();
        }),
      ],
    );
    addTearDown(container.dispose);

    Object? thrown;
    try {
      container.read(databaseExecutorProvider);
    } on Object catch (error) {
      thrown = error;
    }
    expect(thrown, isNotNull);
    expect(thrown.toString(), contains('DATABASE_LOCKED'));
    expect(keyStoreBuilds, 0);
  });

  test('bloquear invalida y cierra la base compartida ya abierta', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accessSessionProvider.overrideWith(_LockableSessionController.new),
        databaseExecutorProvider.overrideWith((Ref ref) {
          final bool accessGranted = ref.watch(
            accessSessionProvider.select(
              (AccessSessionState session) => session.canBuildProtected,
            ),
          );
          if (!accessGranted) {
            throw const AccessDatabaseLockedException();
          }
          return NativeDatabase.memory();
        }),
      ],
    );
    addTearDown(container.dispose);

    final guardSubscription = container.listen(
      persistenceAccessGuardProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(guardSubscription.close);
    final database = container.read(appDatabaseProvider);
    expect(
      await database.customSelect('SELECT 1 AS value').getSingle(),
      isNotNull,
    );

    container.read(accessSessionProvider.notifier).lock();
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      database.customSelect('SELECT 1 AS value').getSingle(),
      throwsStateError,
    );
    expect(
      () => container.read(appDatabaseProvider),
      throwsA(
        predicate<Object>(
          (Object error) => error.toString().contains('DATABASE_LOCKED'),
        ),
      ),
    );
  });
}

const AccessSessionState _lockedSession = AccessSessionState(
  phase: AccessSessionPhase.locked,
  revision: 1,
  setupStep: AccessSetupStep.enterPin,
  recoveryStep: AccessRecoveryStep.enterRecoveryAndPin,
  biometricsEnabled: false,
  biometricAvailability: BiometricAvailability.unavailable,
  isBusy: false,
  failedAttempts: 0,
  blockedUntilEpochMillis: null,
  notice: null,
  oneTimeRecoveryCode: null,
);

final class _NeverDatabaseKeyStore implements DatabaseKeyStore {
  const _NeverDatabaseKeyStore();

  @override
  Future<String> getOrCreateDatabaseKey({
    required bool databaseExists,
    required String storageId,
  }) => throw StateError('No debe construirse ni invocarse.');
}

final class _LockableSessionController extends AccessSessionController {
  @override
  AccessSessionState build() => const AccessSessionState.unlockedForTesting();

  @override
  void lock({AccessLockReason reason = AccessLockReason.manual}) {
    state = _lockedSession;
  }
}
