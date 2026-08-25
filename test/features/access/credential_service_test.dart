import 'dart:async';

import 'package:bitacora_rpg_personal/features/access/data/pbkdf2_access_credential_hasher.dart';
import 'package:bitacora_rpg_personal/features/access/domain/access_credential_exception.dart';
import 'package:bitacora_rpg_personal/features/access/domain/access_credential_record.dart';
import 'package:bitacora_rpg_personal/features/access/domain/credential_service.dart';
import 'package:bitacora_rpg_personal/features/access/domain/recovery_code.dart';
import 'package:flutter_test/flutter_test.dart';

import 'access_test_fakes.dart';

void main() {
  group('enrollment', () {
    test('does not persist before exact recovery confirmation', () async {
      final store = MemoryAccessCredentialStore();
      final service = _service(store);

      final draft = await service.createEnrollmentDraft(pin: '482951');
      expect(store.record, isNull);
      expect(store.writes, isEmpty);
      expect(draft.toString(), isNot(contains(draft.recoveryCode)));

      await expectLater(
        service.confirmEnrollment(draft: draft, recoveryCode: 'wrong'),
        throwsA(_errorCode(AccessCredentialErrorCode.invalidRecoveryCode)),
      );
      expect(store.record, isNull);

      await service.confirmEnrollment(
        draft: draft,
        recoveryCode: draft.recoveryCode.toLowerCase().replaceAll('-', ' '),
      );
      expect(store.record, isNotNull);
      expect(store.writes, hasLength(1));

      await expectLater(
        service.confirmEnrollment(
          draft: draft,
          recoveryCode: draft.recoveryCode,
        ),
        throwsA(_errorCode(AccessCredentialErrorCode.invalidRecoveryCode)),
      );
    });

    test('rejects a weak PIN before generating or writing anything', () async {
      final store = MemoryAccessCredentialStore();
      final service = _service(store);
      expect(
        () => service.createEnrollmentDraft(pin: '123456'),
        throwsA(_errorCode(AccessCredentialErrorCode.invalidPin)),
      );
      expect(store.writes, isEmpty);
    });

    test('discarded enrollment material can never be confirmed', () async {
      final store = MemoryAccessCredentialStore();
      final service = _service(store);
      final draft = await service.createEnrollmentDraft(pin: '482951');
      service.discardEnrollmentDraft(draft);
      service.discardEnrollmentDraft(draft);
      await expectLater(
        service.confirmEnrollment(
          draft: draft,
          recoveryCode: draft.recoveryCode,
        ),
        throwsA(_errorCode(AccessCredentialErrorCode.invalidRecoveryCode)),
      );
      expect(store.record, isNull);
    });

    test('creates independent salts and no plaintext JSON secrets', () async {
      final store = MemoryAccessCredentialStore();
      final service = _service(store);
      final draft = await service.createEnrollmentDraft(pin: '482951');
      await service.confirmEnrollment(
        draft: draft,
        recoveryCode: draft.recoveryCode,
      );
      final record = store.record!;
      expect(record.pinSalt, isNot(orderedEquals(record.recoverySalt)));
      expect(record.toJsonString(), isNot(contains('482951')));
      expect(record.toJsonString(), isNot(contains(draft.recoveryCode)));
    });
  });

  group('verification and shared lockout', () {
    test(
      'correct PIN verifies and an incorrect PIN is persisted first',
      () async {
        final configured = await _configured();
        final store = configured.store;
        final service = configured.service;
        store.writes.clear();

        expect((await service.verifyPin('482951')).isVerified, isTrue);

        final barrier = Completer<void>();
        store.nextWriteBarrier = barrier;
        var returned = false;
        final pending = service.verifyPin('482952').then((result) {
          returned = true;
          return result;
        });
        await store.writeStarted.future;
        await Future<void>.delayed(Duration.zero);
        expect(returned, isFalse);
        barrier.complete();
        final result = await pending;
        expect(result.status, CredentialAttemptStatus.rejected);
        expect(store.record!.failedAttempts, 1);
        expect(store.writes.last.failedAttempts, 1);
      },
    );

    test(
      'applies exact boundaries and shares failures with recovery',
      () async {
        expect(CredentialService.lockoutDelayMillis(4), 0);
        expect(CredentialService.lockoutDelayMillis(5), 30000);
        expect(CredentialService.lockoutDelayMillis(6), 60000);
        expect(CredentialService.lockoutDelayMillis(7), 120000);
        expect(CredentialService.lockoutDelayMillis(8), 240000);
        expect(CredentialService.lockoutDelayMillis(9), 480000);
        expect(CredentialService.lockoutDelayMillis(10), 900000);
        expect(CredentialService.lockoutDelayMillis(100), 900000);

        final clock = FakeAccessClock(1000);
        final configured = await _configured(clock: clock);
        final service = configured.service;

        for (var failure = 1; failure <= 5; failure++) {
          final result = await service.verifyPin('482952');
          expect(result.status, CredentialAttemptStatus.rejected);
          expect(result.failedAttempts, failure);
        }
        expect(configured.store.record!.blockedUntilEpochMillis, 31000);
        expect(
          (await service.verifyPin('482951')).status,
          CredentialAttemptStatus.blocked,
        );

        clock.now = 31000;
        final recoveryFailure = await service.createRecoveryDraft(
          recoveryCode: 'invalid',
          newPin: '618204',
        );
        expect(
          recoveryFailure.attempt.status,
          CredentialAttemptStatus.rejected,
        );
        expect(recoveryFailure.attempt.failedAttempts, 6);
        expect(recoveryFailure.attempt.blockedUntilEpochMillis, 91000);
      },
    );

    test('clock rollback cannot shorten an active block', () async {
      final clock = FakeAccessClock(50000);
      final configured = await _configured(clock: clock);
      for (var index = 0; index < 5; index++) {
        await configured.service.verifyPin('482952');
      }
      expect(configured.store.record!.blockedUntilEpochMillis, 80000);

      clock.now = 0;
      expect(
        (await configured.service.verifyPin('482951')).status,
        CredentialAttemptStatus.blocked,
      );
      clock.now = 79999;
      expect(
        (await configured.service.verifyPin('482951')).status,
        CredentialAttemptStatus.blocked,
      );
      clock.now = 80000;
      expect((await configured.service.verifyPin('482951')).isVerified, isTrue);
      expect(configured.store.record!.failedAttempts, 0);
    });

    test('serializes concurrent failures without losing counters', () async {
      final configured = await _configured();
      final results = await Future.wait<CredentialAttemptResult>(
        List<Future<CredentialAttemptResult>>.generate(
          5,
          (_) => configured.service.verifyPin('482952'),
        ),
      );
      expect(
        results.map((result) => result.failedAttempts),
        orderedEquals(<int>[1, 2, 3, 4, 5]),
      );
      expect(configured.store.record!.failedAttempts, 5);
      expect(configured.store.record!.blockedUntilEpochMillis, 31000);
    });
  });

  group('credential rotation', () {
    test(
      'changes PIN with a fresh salt and preserves recovery verifier',
      () async {
        final configured = await _configured();
        final before = configured.store.record!;
        final result = await configured.service.changePin(
          currentPin: '482951',
          newPin: '618204',
        );
        expect(result.isVerified, isTrue);
        final after = configured.store.record!;
        expect(after.pinSalt, isNot(orderedEquals(before.pinSalt)));
        expect(after.recoverySalt, before.recoverySalt);
        expect(after.recoveryVerifier, before.recoveryVerifier);
        expect(
          (await configured.service.verifyPin('482951')).status,
          CredentialAttemptStatus.rejected,
        );
        expect(
          (await configured.service.verifyPin('618204')).isVerified,
          isTrue,
        );
      },
    );

    test('recovery remains unchanged until replacement is confirmed', () async {
      final configured = await _configured();
      final baseline = configured.store.record!.toJsonString();
      final outcome = await configured.service.createRecoveryDraft(
        recoveryCode: configured.recoveryCode,
        newPin: '618204',
      );
      expect(outcome.hasDraft, isTrue);
      final draft = outcome.draft!;
      expect(configured.store.record!.toJsonString(), baseline);

      await expectLater(
        configured.service.confirmRecovery(draft: draft, recoveryCode: 'wrong'),
        throwsA(_errorCode(AccessCredentialErrorCode.invalidRecoveryCode)),
      );
      expect(configured.store.record!.toJsonString(), baseline);

      await configured.service.confirmRecovery(
        draft: draft,
        recoveryCode: draft.recoveryCode,
      );
      expect(configured.store.record!.toJsonString(), isNot(baseline));
      expect((await configured.service.verifyPin('618204')).isVerified, isTrue);

      final reused = await configured.service.createRecoveryDraft(
        recoveryCode: configured.recoveryCode,
        newPin: '735190',
      );
      expect(reused.attempt.status, CredentialAttemptStatus.rejected);
    });

    test('abandoned recovery draft leaves old credentials usable', () async {
      final configured = await _configured();
      final baseline = configured.store.record!.toJsonString();
      final abandoned = await configured.service.createRecoveryDraft(
        recoveryCode: configured.recoveryCode,
        newPin: '618204',
      );
      expect(abandoned.hasDraft, isTrue);
      expect(configured.store.record!.toJsonString(), baseline);

      final restarted = _service(
        configured.store,
        clock: configured.clock,
        saltSeed: 80,
        recoverySeed: 180,
      );
      expect((await restarted.verifyPin('482951')).isVerified, isTrue);
      final retry = await restarted.createRecoveryDraft(
        recoveryCode: configured.recoveryCode,
        newPin: '735190',
      );
      expect(retry.hasDraft, isTrue);
    });

    test('changed baseline invalidates a recovery draft', () async {
      final configured = await _configured();
      final outcome = await configured.service.createRecoveryDraft(
        recoveryCode: configured.recoveryCode,
        newPin: '618204',
      );
      final draft = outcome.draft!;
      final changed = configured.store.record!.copyWith(
        biometricsEnabled: true,
      );
      await configured.store.write(changed);

      await expectLater(
        configured.service.confirmRecovery(
          draft: draft,
          recoveryCode: draft.recoveryCode,
        ),
        throwsA(_errorCode(AccessCredentialErrorCode.staleDraft)),
      );
      expect(configured.store.record!.biometricsEnabled, isTrue);
    });

    test('discarded recovery material can never be confirmed', () async {
      final configured = await _configured();
      final outcome = await configured.service.createRecoveryDraft(
        recoveryCode: configured.recoveryCode,
        newPin: '618204',
      );
      final draft = outcome.draft!;
      configured.service.discardRecoveryDraft(draft);
      configured.service.discardRecoveryDraft(draft);
      await expectLater(
        configured.service.confirmRecovery(
          draft: draft,
          recoveryCode: draft.recoveryCode,
        ),
        throwsA(_errorCode(AccessCredentialErrorCode.invalidRecoveryCode)),
      );
      expect((await configured.service.verifyPin('482951')).isVerified, isTrue);
    });

    test(
      'biometric success resets shared failures only when enabled',
      () async {
        final configured = await _configured();
        await configured.service.verifyPin('482952');
        await expectLater(
          configured.service.recordBiometricSuccess(),
          throwsA(_errorCode(AccessCredentialErrorCode.biometricsNotEnabled)),
        );
        expect(configured.store.record!.failedAttempts, 1);

        final enabled = await configured.service.setBiometricsEnabled(
          currentPin: '482951',
          enabled: true,
        );
        expect(enabled.isVerified, isTrue);
        await configured.service.verifyPin('482952');
        expect(configured.store.record!.failedAttempts, 1);
        await configured.service.recordBiometricSuccess();
        expect(configured.store.record!.failedAttempts, 0);
      },
    );
  });
}

Matcher _errorCode(AccessCredentialErrorCode code) =>
    isA<AccessCredentialException>().having(
      (error) => error.code,
      'code',
      code,
    );

CredentialService _service(
  MemoryAccessCredentialStore store, {
  FakeAccessClock? clock,
  int saltSeed = 0,
  int recoverySeed = 100,
}) {
  final hasher = Pbkdf2AccessCredentialHasher.forTesting(
    parameters: const Pbkdf2HashParameters(
      iterations: 2,
      saltLength: AccessCredentialRecord.saltLength,
      verifierLength: AccessCredentialRecord.verifierLength,
    ),
    randomByteSource: DeterministicRandomByteSource(saltSeed),
  );
  return CredentialService(
    store: store,
    hasher: hasher,
    recoveryCodeGenerator: RecoveryCodeGenerator(
      DeterministicRandomByteSource(recoverySeed),
    ),
    clock: clock ?? FakeAccessClock(1000),
  );
}

Future<_ConfiguredFixture> _configured({FakeAccessClock? clock}) async {
  final effectiveClock = clock ?? FakeAccessClock(1000);
  final store = MemoryAccessCredentialStore();
  final service = _service(store, clock: effectiveClock);
  final draft = await service.createEnrollmentDraft(pin: '482951');
  await service.confirmEnrollment(
    draft: draft,
    recoveryCode: draft.recoveryCode,
  );
  return _ConfiguredFixture(
    service: service,
    store: store,
    clock: effectiveClock,
    recoveryCode: draft.recoveryCode,
  );
}

final class _ConfiguredFixture {
  const _ConfiguredFixture({
    required this.service,
    required this.store,
    required this.clock,
    required this.recoveryCode,
  });

  final CredentialService service;
  final MemoryAccessCredentialStore store;
  final FakeAccessClock clock;
  final String recoveryCode;
}
