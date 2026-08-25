import 'dart:math';

import '../domain/access_credential_exception.dart';
import '../domain/random_byte_source.dart';

final class SecureRandomByteSource implements RandomByteSource {
  SecureRandomByteSource() : _random = Random.secure();

  final Random _random;

  @override
  List<int> nextBytes(int length) {
    if (length <= 0) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.invalidHashParameters,
      );
    }
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }
}
