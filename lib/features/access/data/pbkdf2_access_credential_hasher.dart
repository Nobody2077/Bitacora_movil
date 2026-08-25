import 'dart:convert';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';

import '../domain/access_credential_exception.dart';
import '../domain/access_credential_hasher.dart';
import '../domain/access_credential_record.dart';
import '../domain/random_byte_source.dart';
import 'secure_random_byte_source.dart';

final class Pbkdf2HashParameters {
  const Pbkdf2HashParameters({
    required this.iterations,
    required this.saltLength,
    required this.verifierLength,
  });

  static const Pbkdf2HashParameters production = Pbkdf2HashParameters(
    iterations: AccessCredentialRecord.iterations,
    saltLength: AccessCredentialRecord.saltLength,
    verifierLength: AccessCredentialRecord.verifierLength,
  );

  final int iterations;
  final int saltLength;
  final int verifierLength;
}

/// Pure-Dart PBKDF2 implementation. Production construction cannot override
/// the ADR parameters; the explicitly named testing constructor can.
final class Pbkdf2AccessCredentialHasher implements AccessCredentialHasher {
  Pbkdf2AccessCredentialHasher.production()
    : _parameters = Pbkdf2HashParameters.production,
      _randomByteSource = SecureRandomByteSource(),
      _runInIsolate = true;

  Pbkdf2AccessCredentialHasher.forTesting({
    required Pbkdf2HashParameters parameters,
    required RandomByteSource randomByteSource,
    bool runInIsolate = false,
  }) : _parameters = parameters,
       _randomByteSource = randomByteSource,
       _runInIsolate = runInIsolate {
    _validateParameters(parameters);
  }

  final Pbkdf2HashParameters _parameters;
  final RandomByteSource _randomByteSource;
  final bool _runInIsolate;

  Pbkdf2HashParameters get parameters => _parameters;

  @override
  int get saltLength => _parameters.saltLength;

  @override
  int get verifierLength => _parameters.verifierLength;

  @override
  List<int> generateSalt() {
    final salt = _randomByteSource.nextBytes(saltLength);
    if (salt.length != saltLength ||
        salt.any((value) => value < 0 || value > 255)) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.invalidHashParameters,
      );
    }
    return List<int>.of(salt);
  }

  @override
  Future<List<int>> deriveVerifier({
    required String secret,
    required List<int> salt,
  }) async {
    if (salt.length != saltLength ||
        salt.any((value) => value < 0 || value > 255)) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.invalidHashParameters,
      );
    }

    final request = _Pbkdf2Request(
      secretBytes: utf8.encode(secret),
      salt: List<int>.of(salt),
      iterations: _parameters.iterations,
      verifierLength: verifierLength,
    );
    if (_runInIsolate) {
      return Isolate.run<List<int>>(() => _derive(request));
    }
    return _derive(request);
  }

  @override
  bool constantTimeEquals(List<int> left, List<int> right) {
    var difference = left.length ^ right.length;
    final maximumLength = left.length > right.length
        ? left.length
        : right.length;
    for (var index = 0; index < maximumLength; index++) {
      final leftByte = index < left.length ? left[index] : 0;
      final rightByte = index < right.length ? right[index] : 0;
      difference |= leftByte ^ rightByte;
    }
    return difference == 0;
  }

  static Future<List<int>> _derive(_Pbkdf2Request request) async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: request.iterations,
      bits: request.verifierLength * 8,
    );
    final key = await algorithm.deriveKey(
      secretKey: SecretKey(request.secretBytes),
      nonce: request.salt,
    );
    return key.extractBytes();
  }

  static void _validateParameters(Pbkdf2HashParameters parameters) {
    if (parameters.iterations <= 0 ||
        parameters.saltLength <= 0 ||
        parameters.verifierLength <= 0) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.invalidHashParameters,
      );
    }
  }
}

final class _Pbkdf2Request {
  const _Pbkdf2Request({
    required this.secretBytes,
    required this.salt,
    required this.iterations,
    required this.verifierLength,
  });

  final List<int> secretBytes;
  final List<int> salt;
  final int iterations;
  final int verifierLength;
}
