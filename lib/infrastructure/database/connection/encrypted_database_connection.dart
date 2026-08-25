import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../security/database_key_store.dart';

/// Builds the production Drift executor backed by SQLite3MultipleCiphers.
final class EncryptedDatabaseConnection {
  const EncryptedDatabaseConnection({required DatabaseKeyStore keyStore})
    : _keyStore = keyStore;

  static final RegExp _keyPattern = RegExp(r'^[0-9a-f]{64}$');

  final DatabaseKeyStore _keyStore;

  /// Obtains the platform-protected key and prepares a background connection.
  ///
  /// SQLite is configured when Drift first opens this executor. The setup
  /// callback runs before Drift reads `user_version`, migrates, or accesses any
  /// application table. Setup errors therefore fail the open operation closed.
  Future<QueryExecutor> open({
    required File databaseFile,
    String storageId = 'primary',
  }) async {
    final bool fileExists = await databaseFile.exists();
    final bool databaseExists = fileExists && await databaseFile.length() > 0;
    final String keyHex = await _keyStore.getOrCreateDatabaseKey(
      databaseExists: databaseExists,
      storageId: storageId,
    );

    if (!_keyPattern.hasMatch(keyHex)) {
      throw const EncryptedDatabaseOpenException(
        EncryptedDatabaseOpenFailure.invalidKeyMaterial,
      );
    }

    final QueryExecutor executor = NativeDatabase.createInBackground(
      databaseFile,
      logStatements: false,
      setup: (Database database) =>
          _configureEncryptedDatabase(database, keyHex),
    );
    return executor.interceptWith(_EncryptedOpenFailureInterceptor());
  }
}

/// Failure categories that are safe to surface without leaking key material.
enum EncryptedDatabaseOpenFailure {
  invalidKeyMaterial,
  cipherConfigurationFailed,
  cipherUnavailable,
  schemaUnreadable,
  foreignKeysUnavailable,
}

/// A generic, non-secret-bearing error raised before Drift accesses the schema.
final class EncryptedDatabaseOpenException implements Exception {
  const EncryptedDatabaseOpenException(this.failure);

  final EncryptedDatabaseOpenFailure failure;

  @override
  String toString() => 'EncryptedDatabaseOpenException(${failure.name})';
}

void _configureEncryptedDatabase(Database database, String keyHex) {
  if (!EncryptedDatabaseConnection._keyPattern.hasMatch(keyHex)) {
    throw const EncryptedDatabaseOpenException(
      EncryptedDatabaseOpenFailure.invalidKeyMaterial,
    );
  }

  try {
    database.execute("PRAGMA cipher = 'chacha20'");
    database.execute("PRAGMA key = 'raw:$keyHex'");
    database.execute('PRAGMA memory_security = ON');
  } on Object {
    throw const EncryptedDatabaseOpenException(
      EncryptedDatabaseOpenFailure.cipherConfigurationFailed,
    );
  }

  final Object? selectedCipher;
  try {
    final ResultSet rows = database.select('PRAGMA cipher');
    selectedCipher = rows.isEmpty ? null : rows.first.values.firstOrNull;
  } on Object {
    throw const EncryptedDatabaseOpenException(
      EncryptedDatabaseOpenFailure.cipherUnavailable,
    );
  }

  if (selectedCipher is! String ||
      selectedCipher.trim().toLowerCase() != 'chacha20') {
    throw const EncryptedDatabaseOpenException(
      EncryptedDatabaseOpenFailure.cipherUnavailable,
    );
  }

  try {
    final ResultSet rows = database.select(
      'SELECT count(*) AS object_count FROM sqlite_master',
    );
    if (rows.length != 1 || rows.first.values.firstOrNull is! int) {
      throw const EncryptedDatabaseOpenException(
        EncryptedDatabaseOpenFailure.schemaUnreadable,
      );
    }
  } on EncryptedDatabaseOpenException {
    rethrow;
  } on Object {
    throw const EncryptedDatabaseOpenException(
      EncryptedDatabaseOpenFailure.schemaUnreadable,
    );
  }

  try {
    database.execute('PRAGMA foreign_keys = ON');
    final ResultSet rows = database.select('PRAGMA foreign_keys');
    final Object? enabled = rows.isEmpty ? null : rows.first.values.firstOrNull;
    if (enabled != 1) {
      throw const EncryptedDatabaseOpenException(
        EncryptedDatabaseOpenFailure.foreignKeysUnavailable,
      );
    }
  } on EncryptedDatabaseOpenException {
    rethrow;
  } on Object {
    throw const EncryptedDatabaseOpenException(
      EncryptedDatabaseOpenFailure.foreignKeysUnavailable,
    );
  }
}

/// Restores the typed setup error lost at Drift's isolate serialization edge.
final class _EncryptedOpenFailureInterceptor extends QueryInterceptor {
  @override
  Future<bool> ensureOpen(
    QueryExecutor executor,
    QueryExecutorUser user,
  ) async {
    try {
      return await executor.ensureOpen(user);
    } on DriftRemoteException catch (error) {
      final EncryptedDatabaseOpenFailure? failure = _remoteFailure(
        error.remoteCause.toString(),
      );
      if (failure != null) {
        throw EncryptedDatabaseOpenException(failure);
      }
      rethrow;
    }
  }

  static EncryptedDatabaseOpenFailure? _remoteFailure(String remoteCause) {
    for (final EncryptedDatabaseOpenFailure failure
        in EncryptedDatabaseOpenFailure.values) {
      if (remoteCause == 'EncryptedDatabaseOpenException(${failure.name})') {
        return failure;
      }
    }
    return null;
  }
}
