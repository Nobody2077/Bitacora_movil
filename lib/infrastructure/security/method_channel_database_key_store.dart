import 'package:flutter/services.dart';

import 'database_key_store.dart';

/// Android Keystore adapter for the native database-key bridge.
final class MethodChannelDatabaseKeyStore implements DatabaseKeyStore {
  const MethodChannelDatabaseKeyStore({
    MethodChannel channel = const MethodChannel(_channelName),
  }) : _channel = channel;

  static const String _channelName = 'com.jcyq.bitacorarpg/database_key_store';
  static final RegExp _storageIdPattern = RegExp(r'^[a-z0-9_]{1,32}$');
  static final RegExp _keyPattern = RegExp(r'^[0-9a-fA-F]{64}$');

  final MethodChannel _channel;

  @override
  Future<String> getOrCreateDatabaseKey({
    required bool databaseExists,
    required String storageId,
  }) async {
    _validateStorageId(storageId);

    final Object? result;
    try {
      result = await _channel.invokeMethod<Object?>(
        'getOrCreateDatabaseKey',
        <String, Object?>{
          'databaseExists': databaseExists,
          'storageId': storageId,
        },
      );
    } on PlatformException catch (error) {
      throw DatabaseKeyStoreException(error.code);
    } on MissingPluginException {
      throw const DatabaseKeyStoreException('KEYSTORE_CHANNEL_UNAVAILABLE');
    } on Object {
      throw const DatabaseKeyStoreException('KEYSTORE_BRIDGE_FAILURE');
    }

    if (result is! String || !_keyPattern.hasMatch(result)) {
      throw const DatabaseKeyStoreException('KEY_MATERIAL_INVALID');
    }

    return result.toLowerCase();
  }

  /// Removes isolated test key material through the debug-only native API.
  ///
  /// The Android bridge rejects this operation outside debug builds and for
  /// storage identifiers that do not start with `test_`.
  Future<void> clearTestMaterial({required String storageId}) async {
    _validateStorageId(storageId);

    try {
      await _channel.invokeMethod<void>('clearTestMaterial', <String, Object?>{
        'storageId': storageId,
      });
    } on PlatformException catch (error) {
      throw DatabaseKeyStoreException(error.code);
    } on MissingPluginException {
      throw const DatabaseKeyStoreException('KEYSTORE_CHANNEL_UNAVAILABLE');
    } on Object {
      throw const DatabaseKeyStoreException('KEYSTORE_BRIDGE_FAILURE');
    }
  }

  static void _validateStorageId(String storageId) {
    if (!_storageIdPattern.hasMatch(storageId)) {
      throw const DatabaseKeyStoreException('INVALID_STORAGE_ID');
    }
  }
}
