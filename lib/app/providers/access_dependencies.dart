import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/access/data/local_biometric_authenticator.dart';
import '../../features/access/data/method_channel_access_credential_store.dart';
import '../../features/access/data/pbkdf2_access_credential_hasher.dart';
import '../../features/access/data/secure_random_byte_source.dart';
import '../../features/access/domain/access_clock.dart';
import '../../features/access/domain/access_credential_hasher.dart';
import '../../features/access/domain/access_credential_store.dart';
import '../../features/access/domain/biometric_authenticator.dart';
import '../../features/access/domain/credential_service.dart';
import '../../features/access/domain/random_byte_source.dart';
import '../../features/access/domain/recovery_code.dart';
import '../../infrastructure/database/database_file_locator.dart';

final Provider<DatabaseFileLocator> databaseFileLocatorProvider =
    Provider<DatabaseFileLocator>(
      (Ref ref) => const AppSupportDatabaseFileLocator(),
    );

final Provider<AccessCredentialStore> accessCredentialStoreProvider =
    Provider<AccessCredentialStore>((Ref ref) {
      final DatabaseFileLocator locator = ref.watch(
        databaseFileLocatorProvider,
      );
      return MethodChannelAccessCredentialStore(databaseExists: locator.exists);
    });

final Provider<AccessCredentialHasher> accessCredentialHasherProvider =
    Provider<AccessCredentialHasher>(
      (Ref ref) => Pbkdf2AccessCredentialHasher.production(),
    );

final Provider<RandomByteSource> accessRandomByteSourceProvider =
    Provider<RandomByteSource>((Ref ref) => SecureRandomByteSource());

final Provider<RecoveryCodeGenerator> recoveryCodeGeneratorProvider =
    Provider<RecoveryCodeGenerator>(
      (Ref ref) =>
          RecoveryCodeGenerator(ref.watch(accessRandomByteSourceProvider)),
    );

final Provider<AccessClock> accessClockProvider = Provider<AccessClock>(
  (Ref ref) => const SystemAccessClock(),
);

final Provider<CredentialService> credentialServiceProvider =
    Provider<CredentialService>(
      (Ref ref) => CredentialService(
        store: ref.watch(accessCredentialStoreProvider),
        hasher: ref.watch(accessCredentialHasherProvider),
        recoveryCodeGenerator: ref.watch(recoveryCodeGeneratorProvider),
        clock: ref.watch(accessClockProvider),
      ),
    );

final Provider<BiometricAuthenticator> biometricAuthenticatorProvider =
    Provider<BiometricAuthenticator>(
      (Ref ref) => LocalBiometricAuthenticator(),
    );
