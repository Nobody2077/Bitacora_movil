import 'dart:io';

import 'package:bitacora_rpg_personal/features/access/data/local_biometric_authenticator.dart';
import 'package:bitacora_rpg_personal/features/access/data/method_channel_access_credential_store.dart';
import 'package:bitacora_rpg_personal/features/access/domain/access_credential_record.dart';
import 'package:bitacora_rpg_personal/features/access/domain/biometric_authenticator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String storageId = 'test_access_a2';
  final MethodChannelAccessCredentialStore cleanStore =
      MethodChannelAccessCredentialStore(
        databaseExists: () async => false,
        storageId: storageId,
      );

  setUp(cleanStore.clearTestMaterial);
  tearDown(cleanStore.clearTestMaterial);

  testWidgets(
    'Keystore externo, fail-closed, FLAG_SECURE y biometría responden en Android',
    (WidgetTester _) async {
      const MethodChannel privacyChannel = MethodChannel(
        'com.jcyq.bitacorarpg/privacy_window',
      );
      expect(
        await privacyChannel.invokeMethod<bool>('isFlagSecureEnabled'),
        isTrue,
      );
      expect(
        await privacyChannel.invokeMethod<bool>('usesFragmentActivity'),
        isTrue,
      );

      final AccessCredentialRecord record = _record();
      await cleanStore.write(record);
      expect((await cleanStore.read())?.toJsonString(), record.toJsonString());

      final Directory supportDirectory = await getApplicationSupportDirectory();
      final File preferencesFile = File(
        path.join(
          supportDirectory.parent.path,
          'shared_prefs',
          'access_credential_store_v1_$storageId.xml',
        ),
      );
      expect(await preferencesFile.exists(), isTrue);
      final String persistedXml = await preferencesFile.readAsString();
      expect(persistedXml, contains('wrapped_access_state'));
      expect(persistedXml, isNot(contains('pin_verifier')));
      expect(persistedXml, isNot(contains('recovery_verifier')));
      expect(persistedXml, isNot(contains('246802')));

      await cleanStore.corruptTestMaterial(mode: 'blob');
      await expectLater(
        cleanStore.read(),
        throwsA(
          isA<AccessCredentialStoreException>().having(
            (AccessCredentialStoreException error) => error.code,
            'code',
            'ACCESS_STATE_INVALID',
          ),
        ),
      );

      await cleanStore.clearTestMaterial();
      await cleanStore.write(record);
      await cleanStore.corruptTestMaterial(mode: 'alias');
      await expectLater(
        cleanStore.read(),
        throwsA(
          isA<AccessCredentialStoreException>().having(
            (AccessCredentialStoreException error) => error.code,
            'code',
            'ACCESS_WRAPPING_KEY_MISSING',
          ),
        ),
      );

      await cleanStore.clearTestMaterial();
      final MethodChannelAccessCredentialStore existingDatabaseStore =
          MethodChannelAccessCredentialStore(
            databaseExists: () async => true,
            storageId: storageId,
          );
      await expectLater(
        existingDatabaseStore.read(),
        throwsA(
          isA<AccessCredentialStoreException>().having(
            (AccessCredentialStoreException error) => error.code,
            'code',
            'ACCESS_STATE_MISSING_FOR_EXISTING_DATABASE',
          ),
        ),
      );

      final BiometricAvailability availability =
          await LocalBiometricAuthenticator().availability();
      expect(availability, isIn(BiometricAvailability.values));
    },
    skip: !Platform.isAndroid,
  );
}

AccessCredentialRecord _record() => AccessCredentialRecord(
  pinSalt: List<int>.generate(16, (int index) => index),
  pinVerifier: List<int>.generate(32, (int index) => 31 - index),
  recoverySalt: List<int>.generate(16, (int index) => index + 32),
  recoveryVerifier: List<int>.generate(32, (int index) => 255 - index),
  biometricsEnabled: false,
  failedAttempts: 0,
  blockedUntilEpochMillis: null,
  lastFailureEpochMillis: null,
);
