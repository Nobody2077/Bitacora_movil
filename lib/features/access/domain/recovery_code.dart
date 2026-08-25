import 'access_credential_exception.dart';
import 'random_byte_source.dart';

final class RecoveryCode {
  const RecoveryCode({required this.canonical, required this.formatted});

  final String canonical;
  final String formatted;

  @override
  String toString() => 'RecoveryCode(<redacted>)';
}

/// Strict Crockford Base32 codec. Ambiguous aliases I/L/O and U are rejected
/// instead of silently mapped to other characters.
abstract final class RecoveryCodeCodec {
  static const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static final Set<int> _alphabetRunes = alphabet.runes.toSet();

  static String encode160Bits(List<int> bytes) {
    if (bytes.length != 20 || bytes.any((value) => value < 0 || value > 255)) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.invalidRecoveryCode,
      );
    }

    var buffer = 0;
    var bitsInBuffer = 0;
    final output = StringBuffer();
    for (final byte in bytes) {
      buffer = (buffer << 8) | byte;
      bitsInBuffer += 8;
      while (bitsInBuffer >= 5) {
        bitsInBuffer -= 5;
        output.write(alphabet[(buffer >> bitsInBuffer) & 0x1f]);
        buffer &= (1 << bitsInBuffer) - 1;
      }
    }
    if (bitsInBuffer != 0 || output.length != 32) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.invalidRecoveryCode,
      );
    }
    return output.toString();
  }

  static String? tryNormalize(String input) {
    final normalized = input.replaceAll(RegExp('[ -]'), '').toUpperCase();
    if (normalized.length != 32) {
      return null;
    }
    for (final rune in normalized.runes) {
      if (!_alphabetRunes.contains(rune)) {
        return null;
      }
    }
    return normalized;
  }

  static String normalize(String input) {
    final normalized = tryNormalize(input);
    if (normalized == null) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.invalidRecoveryCode,
      );
    }
    return normalized;
  }

  static String format(String canonical) {
    final normalized = normalize(canonical);
    return List<String>.generate(
      8,
      (index) => normalized.substring(index * 4, index * 4 + 4),
      growable: false,
    ).join('-');
  }
}

final class RecoveryCodeGenerator {
  const RecoveryCodeGenerator(this._randomByteSource);

  final RandomByteSource _randomByteSource;

  RecoveryCode generate() {
    final canonical = RecoveryCodeCodec.encode160Bits(
      _randomByteSource.nextBytes(20),
    );
    return RecoveryCode(
      canonical: canonical,
      formatted: RecoveryCodeCodec.format(canonical),
    );
  }
}
