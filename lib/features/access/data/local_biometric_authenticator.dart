import 'package:local_auth/local_auth.dart';

import '../domain/biometric_authenticator.dart';

/// Biometric-only adapter. It never accepts the operating-system PIN/pattern
/// as a substitute for the application's six-digit PIN.
final class LocalBiometricAuthenticator implements BiometricAuthenticator {
  LocalBiometricAuthenticator({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;
  bool _authenticationInProgress = false;

  @override
  Future<BiometricAvailability> availability() async {
    try {
      if (!await _authentication.canCheckBiometrics) {
        return BiometricAvailability.unsupported;
      }
      final List<BiometricType> enrolled = await _authentication
          .getAvailableBiometrics();
      return enrolled.isEmpty
          ? BiometricAvailability.unavailable
          : BiometricAvailability.available;
    } on Object {
      return BiometricAvailability.unavailable;
    }
  }

  @override
  Future<BiometricAuthenticationOutcome> authenticate() async {
    if (_authenticationInProgress) {
      return BiometricAuthenticationOutcome.failed;
    }
    _authenticationInProgress = true;
    try {
      final bool authenticated = await _authentication.authenticate(
        localizedReason: 'Confirma tu identidad para abrir Bitácora RPG.',
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: false,
      );
      return authenticated
          ? BiometricAuthenticationOutcome.authenticated
          : BiometricAuthenticationOutcome.failed;
    } on LocalAuthException catch (error) {
      return switch (error.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.userRequestedFallback =>
          BiometricAuthenticationOutcome.cancelled,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          BiometricAuthenticationOutcome.lockedOut,
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
        LocalAuthExceptionCode.uiUnavailable =>
          BiometricAuthenticationOutcome.unavailable,
        _ => BiometricAuthenticationOutcome.failed,
      };
    } on Object {
      return BiometricAuthenticationOutcome.failed;
    } finally {
      _authenticationInProgress = false;
    }
  }

  @override
  Future<void> cancelAuthentication() async {
    if (!_authenticationInProgress) {
      return;
    }
    try {
      await _authentication.stopAuthentication();
    } on Object {
      // Lock/background already invalidates the session revision. Cancellation
      // is best-effort and must not expose plugin details to the UI.
    }
  }
}
