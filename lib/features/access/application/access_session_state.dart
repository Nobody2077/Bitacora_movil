import 'package:flutter/foundation.dart';

import '../domain/biometric_authenticator.dart';

enum AccessSessionPhase {
  bootstrapping,
  setupRequired,
  locked,
  authenticating,
  recovering,
  unlocked,
  corrupted,
}

enum AccessSetupStep { enterPin, confirmRecoveryCode }

enum AccessRecoveryStep { enterRecoveryAndPin, confirmReplacementCode }

enum AccessNotice {
  pinMismatch,
  pinPolicyRejected,
  invalidCredential,
  progressiveWait,
  recoveryCodeMismatch,
  biometricUnavailable,
  biometricCancelled,
  biometricLockedOut,
  biometricFailed,
  credentialStateCorrupted,
  pinChanged,
  biometricsEnabled,
  biometricsDisabled,
  sessionTimedOut,
}

@immutable
final class AccessSessionState {
  const AccessSessionState({
    required this.phase,
    required this.revision,
    required this.setupStep,
    required this.recoveryStep,
    required this.biometricsEnabled,
    required this.biometricAvailability,
    required this.isBusy,
    required this.failedAttempts,
    required this.blockedUntilEpochMillis,
    required this.notice,
    required this.oneTimeRecoveryCode,
  });

  const AccessSessionState.bootstrapping()
    : this(
        phase: AccessSessionPhase.bootstrapping,
        revision: 0,
        setupStep: AccessSetupStep.enterPin,
        recoveryStep: AccessRecoveryStep.enterRecoveryAndPin,
        biometricsEnabled: false,
        biometricAvailability: BiometricAvailability.unavailable,
        isBusy: false,
        failedAttempts: 0,
        blockedUntilEpochMillis: null,
        notice: null,
        oneTimeRecoveryCode: null,
      );

  const AccessSessionState.unlockedForTesting()
    : this(
        phase: AccessSessionPhase.unlocked,
        revision: 1,
        setupStep: AccessSetupStep.enterPin,
        recoveryStep: AccessRecoveryStep.enterRecoveryAndPin,
        biometricsEnabled: false,
        biometricAvailability: BiometricAvailability.unavailable,
        isBusy: false,
        failedAttempts: 0,
        blockedUntilEpochMillis: null,
        notice: null,
        oneTimeRecoveryCode: null,
      );

  final AccessSessionPhase phase;
  final int revision;
  final AccessSetupStep setupStep;
  final AccessRecoveryStep recoveryStep;
  final bool biometricsEnabled;
  final BiometricAvailability biometricAvailability;
  final bool isBusy;
  final int failedAttempts;
  final int? blockedUntilEpochMillis;
  final AccessNotice? notice;

  /// Exists only while a one-time code is displayed for confirmation.
  /// [toString] never includes it.
  final String? oneTimeRecoveryCode;

  bool get canBuildProtected => phase == AccessSessionPhase.unlocked;

  bool get hasConfiguredCredentials => switch (phase) {
    AccessSessionPhase.bootstrapping ||
    AccessSessionPhase.setupRequired => false,
    _ => true,
  };

  bool get canRevealPrivacyShield => phase != AccessSessionPhase.bootstrapping;

  AccessSessionState copyWith({
    AccessSessionPhase? phase,
    int? revision,
    AccessSetupStep? setupStep,
    AccessRecoveryStep? recoveryStep,
    bool? biometricsEnabled,
    BiometricAvailability? biometricAvailability,
    bool? isBusy,
    int? failedAttempts,
    Object? blockedUntilEpochMillis = _notProvided,
    Object? notice = _notProvided,
    Object? oneTimeRecoveryCode = _notProvided,
  }) => AccessSessionState(
    phase: phase ?? this.phase,
    revision: revision ?? this.revision,
    setupStep: setupStep ?? this.setupStep,
    recoveryStep: recoveryStep ?? this.recoveryStep,
    biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
    biometricAvailability: biometricAvailability ?? this.biometricAvailability,
    isBusy: isBusy ?? this.isBusy,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    blockedUntilEpochMillis: identical(blockedUntilEpochMillis, _notProvided)
        ? this.blockedUntilEpochMillis
        : blockedUntilEpochMillis as int?,
    notice: identical(notice, _notProvided)
        ? this.notice
        : notice as AccessNotice?,
    oneTimeRecoveryCode: identical(oneTimeRecoveryCode, _notProvided)
        ? this.oneTimeRecoveryCode
        : oneTimeRecoveryCode as String?,
  );

  static const Object _notProvided = Object();

  @override
  String toString() =>
      'AccessSessionState(phase: ${phase.name}, revision: $revision, '
      'setupStep: ${setupStep.name}, recoveryStep: ${recoveryStep.name}, '
      'biometricsEnabled: $biometricsEnabled, isBusy: $isBusy, '
      'failedAttempts: $failedAttempts, '
      'blocked: ${blockedUntilEpochMillis != null}, notice: ${notice?.name}, '
      'oneTimeRecoveryCode: '
      '${oneTimeRecoveryCode == null ? 'none' : '<redacted>'})';
}
