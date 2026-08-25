import 'package:bitacora_rpg_personal/features/access/data/method_channel_access_credential_store.dart';
import 'package:bitacora_rpg_personal/features/access/domain/access_credential_record.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'com.jcyq.bitacorarpg/access_credential_store',
  );
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('read envía presencia de DB y valida el JSON versionado', () async {
    final AccessCredentialRecord record = _record();
    MethodCall? observed;
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      observed = call;
      return record.toJsonString();
    });
    final MethodChannelAccessCredentialStore store =
        MethodChannelAccessCredentialStore(
          databaseExists: () async => true,
          storageId: 'test_adapter',
        );

    final AccessCredentialRecord? loaded = await store.read();

    expect(observed?.method, 'readAccessState');
    expect(observed?.arguments, <String, Object?>{
      'databaseExists': true,
      'storageId': 'test_adapter',
    });
    expect(loaded?.toJsonString(), record.toJsonString());
  });

  test('write nunca agrega campos de secretos en texto plano', () async {
    String? payload;
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      payload = (call.arguments as Map<Object?, Object?>)['payload'] as String?;
      return null;
    });
    final MethodChannelAccessCredentialStore store =
        MethodChannelAccessCredentialStore(
          databaseExists: () async => false,
          storageId: 'test_adapter',
        );

    await store.write(_record());

    expect(payload, isNotNull);
    expect(payload, isNot(contains('pin_plaintext')));
    expect(payload, isNot(contains('recovery_code')));
    expect(payload, contains('pin_verifier'));
  });

  test('conserva solo el código estable de PlatformException', () async {
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      throw PlatformException(
        code: 'ACCESS_STATE_UNREADABLE',
        message: 'mensaje potencialmente variable',
      );
    });
    final MethodChannelAccessCredentialStore store =
        MethodChannelAccessCredentialStore(
          databaseExists: () async => true,
          storageId: 'test_adapter',
        );

    await expectLater(
      store.read(),
      throwsA(
        isA<AccessCredentialStoreException>().having(
          (AccessCredentialStoreException error) => error.code,
          'code',
          'ACCESS_STATE_UNREADABLE',
        ),
      ),
    );
  });
}

AccessCredentialRecord _record() => AccessCredentialRecord(
  pinSalt: List<int>.generate(16, (int index) => index),
  pinVerifier: List<int>.generate(32, (int index) => index + 1),
  recoverySalt: List<int>.generate(16, (int index) => index + 16),
  recoveryVerifier: List<int>.generate(32, (int index) => 255 - index),
  biometricsEnabled: true,
  failedAttempts: 0,
  blockedUntilEpochMillis: null,
  lastFailureEpochMillis: null,
);
