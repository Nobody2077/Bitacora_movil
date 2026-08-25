enum PinPolicyViolation {
  none,
  wrongLength,
  nonNumeric,
  repeatedDigit,
  trivialSequence,
}

abstract final class PinPolicy {
  static final RegExp _sixDigits = RegExp(r'^[0-9]{6}$');

  static const Set<String> _trivialSequences = <String>{
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
  };

  static PinPolicyViolation validate(String pin) {
    if (pin.length != 6) {
      return PinPolicyViolation.wrongLength;
    }
    if (!_sixDigits.hasMatch(pin)) {
      return PinPolicyViolation.nonNumeric;
    }
    if (pin.runes.toSet().length == 1) {
      return PinPolicyViolation.repeatedDigit;
    }
    if (_trivialSequences.contains(pin)) {
      return PinPolicyViolation.trivialSequence;
    }
    return PinPolicyViolation.none;
  }

  static bool isAcceptable(String pin) =>
      validate(pin) == PinPolicyViolation.none;
}
