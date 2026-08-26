import 'package:bitacora_rpg_personal/app/providers/access_dependencies.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_controller.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_state.dart';
import 'package:bitacora_rpg_personal/features/access/data/method_channel_access_credential_store.dart';
import 'package:bitacora_rpg_personal/features/access/data/pbkdf2_access_credential_hasher.dart';
import 'package:bitacora_rpg_personal/features/access/domain/access_credential_record.dart';
import 'package:bitacora_rpg_personal/features/access/domain/biometric_authenticator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const String processRestartStorageId = 'test_access_restart_g2';
const String processRestartPin = '246802';

MethodChannelAccessCredentialStore processRestartStore() =>
    MethodChannelAccessCredentialStore(
      databaseExists: () async => false,
      storageId: processRestartStorageId,
    );

Pbkdf2AccessCredentialHasher processRestartHasher() =>
    Pbkdf2AccessCredentialHasher.production();

Future<AccessCredentialRecord> createProcessRestartRecord(
  Pbkdf2AccessCredentialHasher hasher,
) async {
  final List<int> pinSalt = List<int>.generate(16, (int index) => index + 1);
  final List<int> recoverySalt = List<int>.generate(
    16,
    (int index) => index + 33,
  );
  final List<int> pinVerifier = await hasher.deriveVerifier(
    secret: processRestartPin,
    salt: pinSalt,
  );
  final List<int> recoveryVerifier = await hasher.deriveVerifier(
    secret: '0123456789ABCDEFGHJKMNPQRSTVWXYZ',
    salt: recoverySalt,
  );

  return AccessCredentialRecord(
    pinSalt: pinSalt,
    pinVerifier: pinVerifier,
    recoverySalt: recoverySalt,
    recoveryVerifier: recoveryVerifier,
    biometricsEnabled: false,
    failedAttempts: 0,
    blockedUntilEpochMillis: null,
    lastFailureEpochMillis: null,
  );
}

ProviderContainer processRestartSessionContainer({
  required MethodChannelAccessCredentialStore store,
  required Pbkdf2AccessCredentialHasher hasher,
}) => ProviderContainer(
  overrides: [
    accessCredentialStoreProvider.overrideWithValue(store),
    accessCredentialHasherProvider.overrideWithValue(hasher),
    biometricAuthenticatorProvider.overrideWithValue(
      const _UnavailableBiometricAuthenticator(),
    ),
  ],
);

Future<AccessSessionState> waitForProcessRestartPhase({
  required WidgetTester tester,
  required ProviderContainer container,
  required AccessSessionPhase phase,
}) async {
  for (var attempt = 0; attempt < 200; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 25));
    final AccessSessionState state = container.read(accessSessionProvider);
    if (state.phase == phase) {
      return state;
    }
    if (state.phase == AccessSessionPhase.corrupted) {
      throw TestFailure('Cold session failed closed as corrupted: $state');
    }
  }
  throw TestFailure(
    'Timed out waiting for ${phase.name}; current state: '
    '${container.read(accessSessionProvider)}',
  );
}

final class _UnavailableBiometricAuthenticator
    implements BiometricAuthenticator {
  const _UnavailableBiometricAuthenticator();

  @override
  Future<BiometricAuthenticationOutcome> authenticate() async =>
      BiometricAuthenticationOutcome.unavailable;

  @override
  Future<BiometricAvailability> availability() async =>
      BiometricAvailability.unavailable;

  @override
  Future<void> cancelAuthentication() async {}
}
