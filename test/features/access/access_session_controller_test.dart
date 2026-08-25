import 'dart:async';

import 'package:bitacora_rpg_personal/app/providers/access_dependencies.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_controller.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_state.dart';
import 'package:bitacora_rpg_personal/features/access/domain/access_clock.dart';
import 'package:bitacora_rpg_personal/features/access/domain/access_credential_hasher.dart';
import 'package:bitacora_rpg_personal/features/access/domain/access_credential_record.dart';
import 'package:bitacora_rpg_personal/features/access/domain/access_credential_store.dart';
import 'package:bitacora_rpg_personal/features/access/domain/biometric_authenticator.dart';
import 'package:bitacora_rpg_personal/features/access/domain/random_byte_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccessSessionController', () {
    test('arranque frío configurado queda bloqueado', () async {
      final _FastHasher hasher = _FastHasher();
      final _MemoryCredentialStore store = _MemoryCredentialStore(
        await _record(hasher: hasher, biometricsEnabled: false),
      );
      final ProviderContainer container = _container(
        store: store,
        hasher: hasher,
      );
      addTearDown(container.dispose);

      container.read(accessSessionProvider);
      final AccessSessionState state = await _waitForPhase(
        container,
        AccessSessionPhase.locked,
      );

      expect(state.canBuildProtected, isFalse);
      expect(store.writeCount, 0);
    });

    test('alta persiste solo al confirmar y luego desbloquea', () async {
      final _MemoryCredentialStore store = _MemoryCredentialStore(null);
      final ProviderContainer container = _container(store: store);
      addTearDown(container.dispose);
      container.read(accessSessionProvider);
      await _waitForPhase(container, AccessSessionPhase.setupRequired);
      final AccessSessionController controller = container.read(
        accessSessionProvider.notifier,
      );

      expect(
        await controller.prepareEnrollment(
          pin: '246802',
          confirmation: '246802',
        ),
        isTrue,
      );
      expect(store.record, isNull);
      final String recoveryCode = container
          .read(accessSessionProvider)
          .oneTimeRecoveryCode!;

      expect(await controller.confirmEnrollment(recoveryCode), isTrue);
      expect(store.record, isNotNull);
      expect(
        container.read(accessSessionProvider).phase,
        AccessSessionPhase.unlocked,
      );
    });

    test('PIN erróneo no abre y el correcto sí', () async {
      final _FastHasher hasher = _FastHasher();
      final _MemoryCredentialStore store = _MemoryCredentialStore(
        await _record(hasher: hasher, biometricsEnabled: false),
      );
      final ProviderContainer container = _container(
        store: store,
        hasher: hasher,
      );
      addTearDown(container.dispose);
      container.read(accessSessionProvider);
      await _waitForPhase(container, AccessSessionPhase.locked);
      final AccessSessionController controller = container.read(
        accessSessionProvider.notifier,
      );

      expect(await controller.unlockWithPin('135790'), isFalse);
      expect(
        container.read(accessSessionProvider).phase,
        AccessSessionPhase.locked,
      );
      expect(store.record?.failedAttempts, 1);

      expect(await controller.unlockWithPin('246802'), isTrue);
      expect(container.read(accessSessionProvider).canBuildProtected, isTrue);
      expect(store.record?.failedAttempts, 0);
    });

    test('recuperación rota PIN y código solo después de confirmar', () async {
      final _FastHasher hasher = _FastHasher();
      final _MemoryCredentialStore store = _MemoryCredentialStore(
        await _record(hasher: hasher, biometricsEnabled: false),
      );
      final String baseline = store.record!.toJsonString();
      final ProviderContainer container = _container(
        store: store,
        hasher: hasher,
      );
      addTearDown(container.dispose);
      container.read(accessSessionProvider);
      await _waitForPhase(container, AccessSessionPhase.locked);
      final AccessSessionController controller = container.read(
        accessSessionProvider.notifier,
      );
      controller.beginRecovery();

      expect(
        await controller.prepareRecovery(
          recoveryCode: _formattedRecoveryCode,
          newPin: '975310',
          pinConfirmation: '975310',
        ),
        isTrue,
      );
      expect(store.record?.toJsonString(), baseline);
      final String replacement = container
          .read(accessSessionProvider)
          .oneTimeRecoveryCode!;
      expect(await controller.confirmRecovery('0000-0000'), isFalse);
      expect(store.record?.toJsonString(), baseline);

      expect(await controller.confirmRecovery(replacement), isTrue);
      expect(
        container.read(accessSessionProvider).phase,
        AccessSessionPhase.unlocked,
      );
      controller.lock();
      expect(await controller.unlockWithPin('246802'), isFalse);
      expect(await controller.unlockWithPin('975310'), isTrue);
    });

    test(
      'resultado biométrico tardío se descarta después de bloquear',
      () async {
        final _FastHasher hasher = _FastHasher();
        final _MemoryCredentialStore store = _MemoryCredentialStore(
          await _record(hasher: hasher, biometricsEnabled: true),
        );
        final _CompletingBiometric biometric = _CompletingBiometric();
        final ProviderContainer container = _container(
          store: store,
          hasher: hasher,
          biometric: biometric,
        );
        addTearDown(container.dispose);
        container.read(accessSessionProvider);
        await _waitForPhase(container, AccessSessionPhase.locked);
        final AccessSessionController controller = container.read(
          accessSessionProvider.notifier,
        );

        final Future<bool> attempt = controller.unlockWithBiometrics();
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(accessSessionProvider).phase,
          AccessSessionPhase.authenticating,
        );
        controller.lock();
        biometric.complete(BiometricAuthenticationOutcome.authenticated);

        expect(await attempt, isFalse);
        expect(
          container.read(accessSessionProvider).phase,
          AccessSessionPhase.locked,
        );
        expect(
          container.read(accessSessionProvider).canBuildProtected,
          isFalse,
        );
      },
    );

    test('background invalida una activación biométrica en curso', () async {
      final _FastHasher hasher = _FastHasher();
      final _MemoryCredentialStore store = _MemoryCredentialStore(
        await _record(hasher: hasher, biometricsEnabled: false),
      );
      final _CompletingAvailabilityBiometric biometric =
          _CompletingAvailabilityBiometric();
      final ProviderContainer container = _container(
        store: store,
        hasher: hasher,
        biometric: biometric,
        seed: const AccessSessionState.unlockedForTesting(),
      );
      addTearDown(container.dispose);
      final AccessSessionController controller = container.read(
        accessSessionProvider.notifier,
      );

      final Future<bool> attempt = controller.setBiometricsEnabled(
        currentPin: '246802',
        enabled: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(accessSessionProvider).isBusy, isTrue);
      controller.handleBackgrounded();
      biometric.complete(BiometricAvailability.available);

      expect(await attempt, isFalse);
      expect(
        container.read(accessSessionProvider).phase,
        AccessSessionPhase.locked,
      );
      expect(store.record?.biometricsEnabled, isFalse);
    });

    test(
      'destino pendiente se valida, redacta y consume una sola vez',
      () async {
        final _FastHasher hasher = _FastHasher();
        final ProviderContainer container = _container(
          store: _MemoryCredentialStore(
            await _record(hasher: hasher, biometricsEnabled: false),
          ),
          hasher: hasher,
        );
        addTearDown(container.dispose);
        container.read(accessSessionProvider);
        await _waitForPhase(container, AccessSessionPhase.locked);
        final AccessSessionController controller = container.read(
          accessSessionProvider.notifier,
        );

        controller.rememberPendingLocation('https://evil.test/home');
        expect(controller.takePendingLocation(), isNull);
        controller.rememberPendingLocation('/missions/m-42/edit?secret=value');
        expect(controller.takePendingLocation(), '/missions/m-42/edit');
        expect(controller.takePendingLocation(), isNull);
      },
    );

    test('estado externo ilegible falla cerrado', () async {
      final ProviderContainer container = _container(
        store: _ThrowingCredentialStore(),
      );
      addTearDown(container.dispose);
      container.read(accessSessionProvider);

      final AccessSessionState state = await _waitForPhase(
        container,
        AccessSessionPhase.corrupted,
      );

      expect(state.canBuildProtected, isFalse);
      expect(state.notice, AccessNotice.credentialStateCorrupted);
    });
  });
}

ProviderContainer _container({
  required AccessCredentialStore store,
  AccessCredentialHasher? hasher,
  BiometricAuthenticator? biometric,
  AccessSessionState? seed,
}) => ProviderContainer(
  overrides: [
    if (seed != null) accessSessionSeedProvider.overrideWithValue(seed),
    accessCredentialStoreProvider.overrideWithValue(store),
    accessCredentialHasherProvider.overrideWithValue(hasher ?? _FastHasher()),
    accessRandomByteSourceProvider.overrideWithValue(_FixedRandom()),
    accessClockProvider.overrideWithValue(_FakeClock()),
    biometricAuthenticatorProvider.overrideWithValue(
      biometric ?? const _UnavailableBiometric(),
    ),
  ],
);

Future<AccessSessionState> _waitForPhase(
  ProviderContainer container,
  AccessSessionPhase phase,
) async {
  for (var attempt = 0; attempt < 50; attempt += 1) {
    final AccessSessionState state = container.read(accessSessionProvider);
    if (state.phase == phase) {
      return state;
    }
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('La sesión no alcanzó ${phase.name}.');
}

Future<AccessCredentialRecord> _record({
  required AccessCredentialHasher hasher,
  required bool biometricsEnabled,
}) async {
  final List<int> pinSalt = hasher.generateSalt();
  final List<int> recoverySalt = List<int>.filled(16, 77);
  return AccessCredentialRecord(
    pinSalt: pinSalt,
    pinVerifier: await hasher.deriveVerifier(secret: '246802', salt: pinSalt),
    recoverySalt: recoverySalt,
    recoveryVerifier: await hasher.deriveVerifier(
      secret: _canonicalRecoveryCode,
      salt: recoverySalt,
    ),
    biometricsEnabled: biometricsEnabled,
    failedAttempts: 0,
    blockedUntilEpochMillis: null,
    lastFailureEpochMillis: null,
  );
}

const String _canonicalRecoveryCode = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const String _formattedRecoveryCode = '0123-4567-89AB-CDEF-GHJK-MNPQ-RSTV-WXYZ';

final class _MemoryCredentialStore implements AccessCredentialStore {
  _MemoryCredentialStore(this.record);

  AccessCredentialRecord? record;
  int writeCount = 0;

  @override
  Future<AccessCredentialRecord?> read() async => record;

  @override
  Future<void> write(AccessCredentialRecord value) async {
    record = value;
    writeCount += 1;
  }
}

final class _ThrowingCredentialStore implements AccessCredentialStore {
  @override
  Future<AccessCredentialRecord?> read() =>
      Future<AccessCredentialRecord?>.error(StateError('corrupt'));

  @override
  Future<void> write(AccessCredentialRecord record) async {}
}

final class _FastHasher implements AccessCredentialHasher {
  int _salt = 0;

  @override
  int get saltLength => 16;

  @override
  int get verifierLength => 32;

  @override
  List<int> generateSalt() =>
      List<int>.generate(saltLength, (int index) => (_salt++ + index) & 0xff);

  @override
  Future<List<int>> deriveVerifier({
    required String secret,
    required List<int> salt,
  }) async {
    final int seed = <int>[
      ...secret.codeUnits,
      ...salt,
    ].fold<int>(0, (int value, int byte) => ((value * 33) ^ byte) & 0xff);
    return List<int>.generate(32, (int index) => (seed + index * 17) & 0xff);
  }

  @override
  bool constantTimeEquals(List<int> left, List<int> right) {
    var difference = left.length ^ right.length;
    for (var index = 0; index < 32; index += 1) {
      difference |=
          (index < left.length ? left[index] : 0) ^
          (index < right.length ? right[index] : 0);
    }
    return difference == 0;
  }
}

final class _FixedRandom implements RandomByteSource {
  int _value = 1;

  @override
  List<int> nextBytes(int length) =>
      List<int>.generate(length, (int index) => (_value++ + index) & 0xff);
}

final class _FakeClock implements AccessClock {
  @override
  int nowEpochMillis() => 1787600000000;
}

final class _UnavailableBiometric implements BiometricAuthenticator {
  const _UnavailableBiometric();

  @override
  Future<BiometricAuthenticationOutcome> authenticate() async =>
      BiometricAuthenticationOutcome.unavailable;

  @override
  Future<BiometricAvailability> availability() async =>
      BiometricAvailability.unavailable;

  @override
  Future<void> cancelAuthentication() async {}
}

final class _CompletingBiometric implements BiometricAuthenticator {
  final Completer<BiometricAuthenticationOutcome> _completer =
      Completer<BiometricAuthenticationOutcome>();

  void complete(BiometricAuthenticationOutcome outcome) =>
      _completer.complete(outcome);

  @override
  Future<BiometricAuthenticationOutcome> authenticate() => _completer.future;

  @override
  Future<BiometricAvailability> availability() async =>
      BiometricAvailability.available;

  @override
  Future<void> cancelAuthentication() async {}
}

final class _CompletingAvailabilityBiometric
    implements BiometricAuthenticator {
  final Completer<BiometricAvailability> _availability =
      Completer<BiometricAvailability>();

  void complete(BiometricAvailability availability) =>
      _availability.complete(availability);

  @override
  Future<BiometricAuthenticationOutcome> authenticate() async =>
      BiometricAuthenticationOutcome.failed;

  @override
  Future<BiometricAvailability> availability() => _availability.future;

  @override
  Future<void> cancelAuthentication() async {}
}
