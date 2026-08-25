enum BiometricAvailability { available, unavailable, unsupported }

enum BiometricAuthenticationOutcome {
  authenticated,
  cancelled,
  unavailable,
  lockedOut,
  failed,
}

/// Platform-neutral biometric boundary. Implementations must request
/// biometrics only and must never fall back to the device credential.
abstract interface class BiometricAuthenticator {
  Future<BiometricAvailability> availability();

  Future<BiometricAuthenticationOutcome> authenticate();

  Future<void> cancelAuthentication();
}
