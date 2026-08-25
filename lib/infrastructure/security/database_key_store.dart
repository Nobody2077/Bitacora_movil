/// Supplies the 256-bit key used to open the encrypted application database.
///
/// Implementations must never persist or log the returned hexadecimal value in
/// Dart. Key lifecycle and durable storage belong to the platform keystore.
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
