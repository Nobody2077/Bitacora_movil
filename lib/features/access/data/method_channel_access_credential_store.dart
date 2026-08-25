import 'package:flutter/services.dart';

import '../domain/access_credential_record.dart';
import '../domain/access_credential_store.dart';

typedef DatabaseExistsProbe = Future<bool> Function();

/// AndroidKeyStore-backed adapter for the external access-state envelope.
final class MethodChannelAccessCredentialStore
    implements AccessCredentialStore {
  const MethodChannelAccessCredentialStore({
    required DatabaseExistsProbe databaseExists,
    String storageId = 'primary',
    MethodChannel channel = const MethodChannel(_channelName),
  }) : _databaseExists = databaseExists,
       _storageId = storageId,
       _channel = channel;

  static const String _channelName =
      'com.jcyq.bitacorarpg/access_credential_store';
  static final RegExp _storageIdPattern = RegExp(r'^[a-z0-9_]{1,32}$');

  final DatabaseExistsProbe _databaseExists;
  final String _storageId;
  final MethodChannel _channel;

  @override
  Future<AccessCredentialRecord?> read() async {
    _validateStorageId();
    final bool databaseExists;
    try {
      databaseExists = await _databaseExists();
    } on Object {
      throw const AccessCredentialStoreException(
        'DATABASE_PRESENCE_UNAVAILABLE',
      );
    }

    final Object? payload = await _invoke<Object?>('readAccessState', {
      'databaseExists': databaseExists,
      'storageId': _storageId,
    });
    if (payload == null) {
      return null;
    }
    if (payload is! String) {
      throw const AccessCredentialStoreException('ACCESS_PAYLOAD_INVALID');
    }
    return AccessCredentialRecord.fromJsonString(payload);
  }

  @override
  Future<void> write(AccessCredentialRecord record) async {
    _validateStorageId();
    await _invoke<void>('writeAccessState', <String, Object?>{
      'storageId': _storageId,
      'payload': record.toJsonString(),
    });
  }

  /// Removes isolated debug-test state. Native code rejects primary/release.
  Future<void> clearTestMaterial() async {
    _validateStorageId();
    await _invoke<void>('clearTestMaterial', <String, Object?>{
      'storageId': _storageId,
    });
  }

  /// Creates a fail-closed state for Android integration tests.
  Future<void> corruptTestMaterial({required String mode}) async {
    _validateStorageId();
    if (mode != 'blob' && mode != 'alias') {
      throw const AccessCredentialStoreException('INVALID_TEST_MODE');
    }
    await _invoke<void>('corruptTestMaterial', <String, Object?>{
      'storageId': _storageId,
      'mode': mode,
    });
  }

  Future<T?> _invoke<T>(String method, Map<String, Object?> arguments) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw AccessCredentialStoreException(error.code);
    } on MissingPluginException {
      throw const AccessCredentialStoreException('ACCESS_CHANNEL_UNAVAILABLE');
    } on AccessCredentialStoreException {
      rethrow;
    } on Object {
      throw const AccessCredentialStoreException('ACCESS_BRIDGE_FAILURE');
    }
  }

  void _validateStorageId() {
    if (!_storageIdPattern.hasMatch(_storageId)) {
      throw const AccessCredentialStoreException('INVALID_STORAGE_ID');
    }
  }
}

/// Fail-closed platform/storage failure without credential material.
final class AccessCredentialStoreException implements Exception {
  const AccessCredentialStoreException(this.code);

  final String code;

  @override
  String toString() => 'AccessCredentialStoreException($code)';
}
