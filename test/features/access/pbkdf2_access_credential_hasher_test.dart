import 'dart:convert';

import 'package:bitacora_rpg_personal/features/access/data/pbkdf2_access_credential_hasher.dart';
import 'package:bitacora_rpg_personal/features/access/domain/access_credential_record.dart';
import 'package:flutter_test/flutter_test.dart';

import 'access_test_fakes.dart';

void main() {
  test('production construction freezes ADR-002 parameters', () {
    final hasher = Pbkdf2AccessCredentialHasher.production();
    expect(hasher.parameters.iterations, AccessCredentialRecord.iterations);
    expect(hasher.parameters.saltLength, AccessCredentialRecord.saltLength);
    expect(
      hasher.parameters.verifierLength,
      AccessCredentialRecord.verifierLength,
    );
    expect(hasher.parameters.iterations, 600000);
  });

  test('matches PBKDF2-HMAC-SHA256 standard vectors', () async {
    final first = Pbkdf2AccessCredentialHasher.forTesting(
      parameters: const Pbkdf2HashParameters(
        iterations: 1,
        saltLength: 4,
        verifierLength: 32,
      ),
      randomByteSource: DeterministicRandomByteSource(),
    );
    final second = Pbkdf2AccessCredentialHasher.forTesting(
      parameters: const Pbkdf2HashParameters(
        iterations: 2,
        saltLength: 4,
        verifierLength: 32,
      ),
      randomByteSource: DeterministicRandomByteSource(),
    );

    expect(
      _hex(
        await first.deriveVerifier(
          secret: 'password',
          salt: utf8.encode('salt'),
        ),
      ),
      '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
    );
    expect(
      _hex(
        await second.deriveVerifier(
          secret: 'password',
          salt: utf8.encode('salt'),
        ),
      ),
      'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
    );
  });

  test('comparison handles equal, unequal and different-length inputs', () {
    final hasher = Pbkdf2AccessCredentialHasher.forTesting(
      parameters: const Pbkdf2HashParameters(
        iterations: 1,
        saltLength: 16,
        verifierLength: 32,
      ),
      randomByteSource: DeterministicRandomByteSource(),
    );
    expect(hasher.constantTimeEquals(<int>[1, 2], <int>[1, 2]), isTrue);
    expect(hasher.constantTimeEquals(<int>[1, 2], <int>[1, 3]), isFalse);
    expect(hasher.constantTimeEquals(<int>[1, 2], <int>[1, 2, 0]), isFalse);
  });

  test('derivation request is transferable to a worker isolate', () async {
    final hasher = Pbkdf2AccessCredentialHasher.forTesting(
      parameters: const Pbkdf2HashParameters(
        iterations: 1,
        saltLength: 4,
        verifierLength: 32,
      ),
      randomByteSource: DeterministicRandomByteSource(),
      runInIsolate: true,
    );
    expect(
      _hex(
        await hasher.deriveVerifier(
          secret: 'password',
          salt: utf8.encode('salt'),
        ),
      ),
      '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
    );
  });
}

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
