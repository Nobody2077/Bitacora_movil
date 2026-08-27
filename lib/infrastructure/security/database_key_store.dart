/// Supplies isolated 256-bit key material protected by Android Keystore.
///
/// Implementations must never persist or log the returned hexadecimal value in
/// Dart. Key lifecycle and durable storage belong to the platform keystore.
/// Production storage identifiers are allow-listed by the native bridge so
/// the database and journal attachments never share key material.
abstract interface class DatabaseKeyStore {
  Future<String> getOrCreateDatabaseKey({
    required bool databaseExists,
    required String storageId,
  });
}

/// A fail-closed error while obtaining database key material.
final class DatabaseKeyStoreException implements Exception {
  const DatabaseKeyStoreException(this.code);

  /// Stable platform or adapter error code. It never contains key material.
  final String code;

  @override
  String toString() => 'DatabaseKeyStoreException($code)';
}
