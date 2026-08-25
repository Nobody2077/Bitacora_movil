import 'dart:collection';
import 'dart:convert';

import 'access_credential_exception.dart';

/// Version 1 persisted credential envelope. The version fixes PBKDF2-HMAC-
/// SHA256 at 600,000 iterations, 16-byte salts and 32-byte verifiers.
final class AccessCredentialRecord {
  AccessCredentialRecord({
    required List<int> pinSalt,
    required List<int> pinVerifier,
    required List<int> recoverySalt,
    required List<int> recoveryVerifier,
    required this.biometricsEnabled,
    required this.failedAttempts,
    required this.blockedUntilEpochMillis,
    required this.lastFailureEpochMillis,
  }) : pinSalt = UnmodifiableListView<int>(List<int>.of(pinSalt)),
       pinVerifier = UnmodifiableListView<int>(List<int>.of(pinVerifier)),
       recoverySalt = UnmodifiableListView<int>(List<int>.of(recoverySalt)),
       recoveryVerifier = UnmodifiableListView<int>(
         List<int>.of(recoveryVerifier),
       ) {
    _validate();
  }

  static const int currentVersion = 1;
  static const String kdf = 'PBKDF2-HMAC-SHA256';
  static const int iterations = 600000;
  static const int saltLength = 16;
  static const int verifierLength = 32;
  static const int _maximumFailedAttempts = 1000000;
  static const int _maximumEpochMillis = 9223372036854775807;

  static const Set<String> _jsonKeys = <String>{
    'version',
    'kdf',
    'iterations',
    'pin_salt',
    'pin_verifier',
    'recovery_salt',
    'recovery_verifier',
    'biometrics_enabled',
    'failed_attempts',
    'blocked_until_epoch_millis',
    'last_failure_epoch_millis',
  };

  final List<int> pinSalt;
  final List<int> pinVerifier;
  final List<int> recoverySalt;
  final List<int> recoveryVerifier;
  final bool biometricsEnabled;
  final int failedAttempts;
  final int? blockedUntilEpochMillis;
  final int? lastFailureEpochMillis;

  void _validate() {
    if (!_validBytes(pinSalt, saltLength) ||
        !_validBytes(recoverySalt, saltLength) ||
        !_validBytes(pinVerifier, verifierLength) ||
        !_validBytes(recoveryVerifier, verifierLength) ||
        failedAttempts < 0 ||
        failedAttempts > _maximumFailedAttempts ||
        !_validEpoch(blockedUntilEpochMillis) ||
        !_validEpoch(lastFailureEpochMillis)) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.invalidCredentialRecord,
      );
    }

    final stateIsConsistent = switch (failedAttempts) {
      0 => blockedUntilEpochMillis == null && lastFailureEpochMillis == null,
      < 5 => blockedUntilEpochMillis == null && lastFailureEpochMillis != null,
      _ =>
        blockedUntilEpochMillis != null &&
            lastFailureEpochMillis != null &&
            blockedUntilEpochMillis! >= lastFailureEpochMillis!,
    };
    if (!stateIsConsistent) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.invalidCredentialRecord,
      );
    }
  }

  static bool _validBytes(List<int> bytes, int length) =>
      bytes.length == length &&
      bytes.every((value) => value >= 0 && value <= 255);

  static bool _validEpoch(int? value) =>
      value == null || (value >= 0 && value <= _maximumEpochMillis);

  AccessCredentialRecord copyWith({
    List<int>? pinSalt,
    List<int>? pinVerifier,
    List<int>? recoverySalt,
    List<int>? recoveryVerifier,
    bool? biometricsEnabled,
    int? failedAttempts,
    Object? blockedUntilEpochMillis = _notProvided,
    Object? lastFailureEpochMillis = _notProvided,
  }) => AccessCredentialRecord(
    pinSalt: pinSalt ?? this.pinSalt,
    pinVerifier: pinVerifier ?? this.pinVerifier,
    recoverySalt: recoverySalt ?? this.recoverySalt,
    recoveryVerifier: recoveryVerifier ?? this.recoveryVerifier,
    biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    blockedUntilEpochMillis: identical(blockedUntilEpochMillis, _notProvided)
        ? this.blockedUntilEpochMillis
        : blockedUntilEpochMillis as int?,
    lastFailureEpochMillis: identical(lastFailureEpochMillis, _notProvided)
        ? this.lastFailureEpochMillis
        : lastFailureEpochMillis as int?,
  );

  static const Object _notProvided = Object();

  Map<String, Object?> toJson() => <String, Object?>{
    'version': currentVersion,
    'kdf': kdf,
    'iterations': iterations,
    'pin_salt': base64.encode(pinSalt),
    'pin_verifier': base64.encode(pinVerifier),
    'recovery_salt': base64.encode(recoverySalt),
    'recovery_verifier': base64.encode(recoveryVerifier),
    'biometrics_enabled': biometricsEnabled,
    'failed_attempts': failedAttempts,
    'blocked_until_epoch_millis': blockedUntilEpochMillis,
    'last_failure_epoch_millis': lastFailureEpochMillis,
  };

  String toJsonString() => jsonEncode(toJson());

  factory AccessCredentialRecord.fromJsonString(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      return AccessCredentialRecord.fromJson(decoded);
    } on AccessCredentialException {
      rethrow;
    } catch (_) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.invalidCredentialRecord,
      );
    }
  }

  factory AccessCredentialRecord.fromJson(Map<String, dynamic> json) {
    try {
      if (json.keys.toSet().difference(_jsonKeys).isNotEmpty ||
          _jsonKeys.difference(json.keys.toSet()).isNotEmpty ||
          json['version'] is! int ||
          json['version'] != currentVersion ||
          json['kdf'] != kdf ||
          json['iterations'] is! int ||
          json['iterations'] != iterations ||
          json['biometrics_enabled'] is! bool ||
          json['failed_attempts'] is! int ||
          (json['blocked_until_epoch_millis'] != null &&
              json['blocked_until_epoch_millis'] is! int) ||
          (json['last_failure_epoch_millis'] != null &&
              json['last_failure_epoch_millis'] is! int)) {
        throw const FormatException();
      }
      return AccessCredentialRecord(
        pinSalt: _decodeCanonicalBase64(json['pin_salt'], saltLength),
        pinVerifier: _decodeCanonicalBase64(
          json['pin_verifier'],
          verifierLength,
        ),
        recoverySalt: _decodeCanonicalBase64(json['recovery_salt'], saltLength),
        recoveryVerifier: _decodeCanonicalBase64(
          json['recovery_verifier'],
          verifierLength,
        ),
        biometricsEnabled: json['biometrics_enabled'] as bool,
        failedAttempts: json['failed_attempts'] as int,
        blockedUntilEpochMillis: json['blocked_until_epoch_millis'] as int?,
        lastFailureEpochMillis: json['last_failure_epoch_millis'] as int?,
      );
    } on AccessCredentialException {
      rethrow;
    } catch (_) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.invalidCredentialRecord,
      );
    }
  }

  static List<int> _decodeCanonicalBase64(Object? value, int length) {
    if (value is! String) {
      throw const FormatException();
    }
    final decoded = base64.decode(value);
    if (decoded.length != length || base64.encode(decoded) != value) {
      throw const FormatException();
    }
    return decoded;
  }

  @override
  String toString() =>
      'AccessCredentialRecord(version: $currentVersion, '
      'biometricsEnabled: $biometricsEnabled, failedAttempts: '
      '$failedAttempts, blocked: ${blockedUntilEpochMillis != null})';
}
