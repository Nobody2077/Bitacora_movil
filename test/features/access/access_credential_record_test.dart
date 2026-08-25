import 'dart:convert';

import 'package:bitacora_rpg_personal/features/access/domain/access_credential_exception.dart';
import 'package:bitacora_rpg_personal/features/access/domain/access_credential_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AccessCredentialRecord record;

  setUp(() {
    record = AccessCredentialRecord(
      pinSalt: List<int>.generate(16, (index) => index),
      pinVerifier: List<int>.generate(32, (index) => index + 16),
      recoverySalt: List<int>.generate(16, (index) => index + 48),
      recoveryVerifier: List<int>.generate(32, (index) => index + 64),
      biometricsEnabled: false,
      failedAttempts: 0,
      blockedUntilEpochMillis: null,
      lastFailureEpochMillis: null,
    );
  });

  test('round-trips its exact versioned JSON contract', () {
    final restored = AccessCredentialRecord.fromJsonString(
      record.toJsonString(),
    );
    expect(restored.toJsonString(), record.toJsonString());
    expect(restored.pinSalt, record.pinSalt);
    expect(restored.recoveryVerifier, record.recoveryVerifier);
  });

  test('contains no plaintext PIN or recovery fields', () {
    final encoded = record.toJsonString();
    expect(encoded, isNot(contains('482951')));
    expect(encoded, isNot(contains('recovery_code')));
    expect(encoded, isNot(contains('pin_plaintext')));
    expect(
      record.toString(),
      isNot(contains(base64.encode(record.pinVerifier))),
    );
  });

  test('fails closed on unknown, missing, malformed and downgraded data', () {
    final valid = record.toJson();
    final cases = <Map<String, dynamic>>[
      <String, dynamic>{...valid, 'extra': true},
      <String, dynamic>{...valid}..remove('pin_salt'),
      <String, dynamic>{...valid, 'version': 2},
      <String, dynamic>{...valid, 'version': 1.0},
      <String, dynamic>{...valid, 'iterations': 1},
      <String, dynamic>{...valid, 'iterations': 600000.0},
      <String, dynamic>{...valid, 'pin_salt': 'not-base64'},
      <String, dynamic>{
        ...valid,
        'pin_verifier': base64.encode(<int>[1]),
      },
      <String, dynamic>{...valid, 'failed_attempts': -1},
      <String, dynamic>{
        ...valid,
        'failed_attempts': 5,
        'last_failure_epoch_millis': 1000,
        'blocked_until_epoch_millis': null,
      },
    ];

    for (final value in cases) {
      expect(
        () => AccessCredentialRecord.fromJson(value),
        throwsA(
          isA<AccessCredentialException>().having(
            (error) => error.code,
            'code',
            AccessCredentialErrorCode.invalidCredentialRecord,
          ),
        ),
        reason: jsonEncode(value),
      );
    }
  });

  test('lists are defensive and unmodifiable', () {
    final source = List<int>.filled(16, 1);
    final value = AccessCredentialRecord(
      pinSalt: source,
      pinVerifier: List<int>.filled(32, 2),
      recoverySalt: List<int>.filled(16, 3),
      recoveryVerifier: List<int>.filled(32, 4),
      biometricsEnabled: false,
      failedAttempts: 0,
      blockedUntilEpochMillis: null,
      lastFailureEpochMillis: null,
    );
    source[0] = 99;
    expect(value.pinSalt.first, 1);
    expect(() => value.pinSalt[0] = 2, throwsUnsupportedError);
  });
}
