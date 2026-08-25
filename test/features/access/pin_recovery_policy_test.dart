import 'package:bitacora_rpg_personal/features/access/domain/access_credential_exception.dart';
import 'package:bitacora_rpg_personal/features/access/domain/pin_policy.dart';
import 'package:bitacora_rpg_personal/features/access/domain/recovery_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PinPolicy', () {
    test('accepts only non-trivial six-digit PINs', () {
      expect(PinPolicy.validate('482951'), PinPolicyViolation.none);
      expect(PinPolicy.validate('12345'), PinPolicyViolation.wrongLength);
      expect(PinPolicy.validate('12a456'), PinPolicyViolation.nonNumeric);
      expect(PinPolicy.validate('777777'), PinPolicyViolation.repeatedDigit);
      expect(PinPolicy.validate('012345'), PinPolicyViolation.trivialSequence);
      expect(PinPolicy.validate('543210'), PinPolicyViolation.trivialSequence);
    });

    test('rejects every sequence frozen by ADR-002', () {
      for (final pin in <String>{
        '012345',
        '123456',
        '234567',
        '345678',
        '456789',
        '987654',
        '876543',
        '765432',
        '654321',
        '543210',
      }) {
        expect(PinPolicy.isAcceptable(pin), isFalse, reason: pin);
      }
    });
  });

  group('RecoveryCodeCodec', () {
    test('encodes exactly 160 bits as 32 Crockford characters', () {
      expect(
        RecoveryCodeCodec.encode160Bits(List<int>.filled(20, 0)),
        List<String>.filled(32, '0').join(),
      );
      expect(
        RecoveryCodeCodec.encode160Bits(List<int>.filled(20, 255)),
        List<String>.filled(32, 'Z').join(),
      );
      expect(
        RecoveryCodeCodec.format('0123456789ABCDEFGHJKMNPQRSTVWXYZ'),
        '0123-4567-89AB-CDEF-GHJK-MNPQ-RSTV-WXYZ',
      );
    });

    test('normalizes lowercase, spaces and hyphens only', () {
      const canonical = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
      expect(
        RecoveryCodeCodec.tryNormalize(
          '0123-4567 89ab-cdef ghjk-mnpq rstv-wxyz',
        ),
        canonical,
      );
      expect(
        RecoveryCodeCodec.tryNormalize(List.filled(32, 'I').join()),
        isNull,
      );
      expect(
        RecoveryCodeCodec.tryNormalize(List.filled(32, 'L').join()),
        isNull,
      );
      expect(
        RecoveryCodeCodec.tryNormalize(List.filled(32, 'O').join()),
        isNull,
      );
      expect(
        RecoveryCodeCodec.tryNormalize(List.filled(32, 'U').join()),
        isNull,
      );
      expect(
        RecoveryCodeCodec.tryNormalize(List.filled(31, '0').join()),
        isNull,
      );
      expect(
        RecoveryCodeCodec.tryNormalize('${List.filled(31, '0').join()}_'),
        isNull,
      );
    });

    test('rejects byte input other than exactly 20 octets', () {
      expect(
        () => RecoveryCodeCodec.encode160Bits(List<int>.filled(19, 0)),
        throwsA(
          isA<AccessCredentialException>().having(
            (error) => error.code,
            'code',
            AccessCredentialErrorCode.invalidRecoveryCode,
          ),
        ),
      );
    });
  });
}
