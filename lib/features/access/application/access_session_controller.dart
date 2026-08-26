import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/access_dependencies.dart';
import '../../../app/router/pending_destination.dart';
import '../domain/access_credential_exception.dart';
import '../domain/access_credential_record.dart';
import '../domain/access_credential_store.dart';
import '../domain/biometric_authenticator.dart';
import '../domain/credential_service.dart';
import '../domain/pin_policy.dart';
import 'access_session_state.dart';

enum AccessLockReason { manual, timeout, backgroundOperation }

/// Test seam for surfaces that exercise navigation without platform plugins.
/// Production never overrides this provider.
final Provider<AccessSessionState?> accessSessionSeedProvider =
    Provider<AccessSessionState?>((Ref ref) => null);

final NotifierProvider<AccessSessionController, AccessSessionState>
accessSessionProvider =
    NotifierProvider<AccessSessionController, AccessSessionState>(
      AccessSessionController.new,
    );

class AccessSessionController extends Notifier<AccessSessionState> {
  late CredentialService _credentialService;
  late AccessCredentialStore _credentialStore;
  late BiometricAuthenticator _biometricAuthenticator;

  AccessEnrollmentDraft? _enrollmentDraft;
  AccessRecoveryDraft? _recoveryDraft;
  PendingDestination? _pendingDestination;
  bool _configured = false;
  bool _disposed = false;

  @override
  AccessSessionState build() {
    _credentialService = ref.read(credentialServiceProvider);
    _credentialStore = ref.read(accessCredentialStoreProvider);
    _biometricAuthenticator = ref.read(biometricAuthenticatorProvider);
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _credentialService.discardDrafts();
      unawaited(_biometricAuthenticator.cancelAuthentication());
    });

    final AccessSessionState? seed = ref.watch(accessSessionSeedProvider);
    if (seed != null) {
      _configured = seed.hasConfiguredCredentials;
      return seed;
    }

    scheduleMicrotask(initialize);
    return const AccessSessionState.bootstrapping();
  }

  Future<void> initialize() async {
    if (_disposed) {
      return;
    }
    final int operationRevision = state.revision;
    try {
      final AccessCredentialRecord? record = await _credentialStore.read();
      if (!_isCurrent(operationRevision)) {
        return;
      }
      if (record == null) {
        _configured = false;
        _replace(
          phase: AccessSessionPhase.setupRequired,
          setupStep: AccessSetupStep.enterPin,
        );
        return;
      }

      _configured = true;
      final BiometricAvailability availability = await _biometricAuthenticator
          .availability();
      if (!_isCurrent(operationRevision)) {
        return;
      }
      _replace(
        phase: AccessSessionPhase.locked,
        biometricsEnabled: record.biometricsEnabled,
        biometricAvailability: availability,
        failedAttempts: record.failedAttempts,
        blockedUntilEpochMillis: record.blockedUntilEpochMillis,
      );
    } on Object {
      if (_isCurrent(operationRevision)) {
        _configured = true;
        _replace(
          phase: AccessSessionPhase.corrupted,
          notice: AccessNotice.credentialStateCorrupted,
        );
      }
    }
  }

  Future<bool> prepareEnrollment({
    required String pin,
    required String confirmation,
  }) async {
    if (state.phase != AccessSessionPhase.setupRequired || state.isBusy) {
      return false;
    }
    if (pin != confirmation) {
      _replace(notice: AccessNotice.pinMismatch);
      return false;
    }
    if (!PinPolicy.isAcceptable(pin)) {
      _replace(notice: AccessNotice.pinPolicyRejected);
      return false;
    }

    final int operationRevision = _beginOperation(
      phase: AccessSessionPhase.setupRequired,
    );
    try {
      final AccessEnrollmentDraft draft = await _credentialService
          .createEnrollmentDraft(pin: pin);
      if (!_isCurrent(operationRevision)) {
        return false;
      }
      _enrollmentDraft = draft;
      _replace(
        phase: AccessSessionPhase.setupRequired,
        setupStep: AccessSetupStep.confirmRecoveryCode,
        oneTimeRecoveryCode: draft.recoveryCode,
      );
      return true;
    } on AccessCredentialException catch (error) {
      if (_isCurrent(operationRevision)) {
        _handleCredentialException(error);
      }
      return false;
    } on Object {
      if (_isCurrent(operationRevision)) {
        _failClosed();
      }
      return false;
    }
  }

  Future<bool> confirmEnrollment(String recoveryCode) async {
    final AccessEnrollmentDraft? draft = _enrollmentDraft;
    if (state.phase != AccessSessionPhase.setupRequired ||
        state.setupStep != AccessSetupStep.confirmRecoveryCode ||
        state.isBusy ||
        draft == null) {
      return false;
    }

    final int operationRevision = _beginOperation(
      phase: AccessSessionPhase.setupRequired,
    );
    try {
      await _credentialService.confirmEnrollment(
        draft: draft,
        recoveryCode: recoveryCode,
        canCommit: () => _isCurrent(operationRevision),
      );
      if (!_isCurrent(operationRevision)) {
        await _reconcileLockedState();
        return false;
      }
      _configured = true;
      _enrollmentDraft = null;
      _unlock();
      return true;
    } on AccessCredentialException catch (error) {
      if (_isCurrent(operationRevision)) {
        _replace(
          phase: AccessSessionPhase.setupRequired,
          setupStep: AccessSetupStep.confirmRecoveryCode,
          notice: error.code == AccessCredentialErrorCode.invalidRecoveryCode
              ? AccessNotice.recoveryCodeMismatch
              : AccessNotice.credentialStateCorrupted,
          oneTimeRecoveryCode: draft.recoveryCode,
        );
      }
      return false;
    } on Object {
      if (_isCurrent(operationRevision)) {
        _failClosed();
      }
      return false;
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    if (state.phase != AccessSessionPhase.locked || state.isBusy) {
      return false;
    }
    final int operationRevision = _beginOperation(
      phase: AccessSessionPhase.authenticating,
    );
    try {
      final CredentialAttemptResult result = await _credentialService.verifyPin(
        pin,
        canCommit: () => _isCurrent(operationRevision),
      );
      if (!_isCurrent(operationRevision)) {
        await _reconcileLockedState();
        return false;
      }
      if (result.isVerified) {
        _unlock();
        return true;
      }
      _applyRejectedAttempt(result, phase: AccessSessionPhase.locked);
      return false;
    } on Object {
      if (_isCurrent(operationRevision)) {
        _failClosed();
      }
      return false;
    }
  }

  Future<bool> unlockWithBiometrics() async {
    if (state.phase != AccessSessionPhase.locked ||
        state.isBusy ||
        !state.biometricsEnabled) {
      return false;
    }

    final int operationRevision = _beginOperation(
      phase: AccessSessionPhase.authenticating,
    );
    final BiometricAuthenticationOutcome outcome = await _biometricAuthenticator
        .authenticate();
    if (!_isCurrent(operationRevision)) {
      return false;
    }

    if (outcome == BiometricAuthenticationOutcome.authenticated) {
      try {
        await _credentialService.recordBiometricSuccess(
          canCommit: () => _isCurrent(operationRevision),
        );
        if (!_isCurrent(operationRevision)) {
          await _reconcileLockedState();
          return false;
        }
        _unlock();
        return true;
      } on Object {
        if (_isCurrent(operationRevision)) {
          _failClosed();
        }
        return false;
      }
    }
    final AccessNotice notice = switch (outcome) {
      BiometricAuthenticationOutcome.cancelled =>
        AccessNotice.biometricCancelled,
      BiometricAuthenticationOutcome.unavailable =>
        AccessNotice.biometricUnavailable,
      BiometricAuthenticationOutcome.lockedOut =>
        AccessNotice.biometricLockedOut,
      _ => AccessNotice.biometricFailed,
    };
    _replace(phase: AccessSessionPhase.locked, notice: notice);
    return false;
  }

  void beginRecovery() {
    if (state.phase != AccessSessionPhase.locked || state.isBusy) {
      return;
    }
    final AccessRecoveryDraft? previousDraft = _recoveryDraft;
    if (previousDraft != null) {
      _credentialService.discardRecoveryDraft(previousDraft);
    }
    _recoveryDraft = null;
    _replace(
      phase: AccessSessionPhase.recovering,
      recoveryStep: AccessRecoveryStep.enterRecoveryAndPin,
    );
  }

  void cancelRecovery() {
    if (state.phase != AccessSessionPhase.recovering) {
      return;
    }
    _credentialService.discardDrafts();
    final AccessRecoveryDraft? draft = _recoveryDraft;
    if (draft != null) {
      _credentialService.discardRecoveryDraft(draft);
    }
    _recoveryDraft = null;
    _replace(phase: AccessSessionPhase.locked);
  }

  Future<bool> prepareRecovery({
    required String recoveryCode,
    required String newPin,
    required String pinConfirmation,
  }) async {
    if (state.phase != AccessSessionPhase.recovering || state.isBusy) {
      return false;
    }
    if (newPin != pinConfirmation) {
      _replace(notice: AccessNotice.pinMismatch);
      return false;
    }
    if (!PinPolicy.isAcceptable(newPin)) {
      _replace(notice: AccessNotice.pinPolicyRejected);
      return false;
    }

    final int operationRevision = _beginOperation(
      phase: AccessSessionPhase.recovering,
    );
    try {
      final RecoveryDraftResult result = await _credentialService
          .createRecoveryDraft(recoveryCode: recoveryCode, newPin: newPin);
      if (!_isCurrent(operationRevision)) {
        await _reconcileLockedState();
        return false;
      }
      final AccessRecoveryDraft? draft = result.draft;
      if (draft == null) {
        _applyRejectedAttempt(
          result.attempt,
          phase: AccessSessionPhase.recovering,
        );
        return false;
      }
      _recoveryDraft = draft;
      _replace(
        phase: AccessSessionPhase.recovering,
        recoveryStep: AccessRecoveryStep.confirmReplacementCode,
        oneTimeRecoveryCode: draft.recoveryCode,
      );
      return true;
    } on AccessCredentialException catch (error) {
      if (_isCurrent(operationRevision)) {
        _handleCredentialException(error);
      }
      return false;
    } on Object {
      if (_isCurrent(operationRevision)) {
        _failClosed();
      }
      return false;
    }
  }

  Future<bool> confirmRecovery(String recoveryCode) async {
    final AccessRecoveryDraft? draft = _recoveryDraft;
    if (state.phase != AccessSessionPhase.recovering ||
        state.recoveryStep != AccessRecoveryStep.confirmReplacementCode ||
        state.isBusy ||
        draft == null) {
      return false;
    }

    final int operationRevision = _beginOperation(
      phase: AccessSessionPhase.recovering,
    );
    try {
      await _credentialService.confirmRecovery(
        draft: draft,
        recoveryCode: recoveryCode,
        canCommit: () => _isCurrent(operationRevision),
      );
      if (!_isCurrent(operationRevision)) {
        await _reconcileLockedState();
        return false;
      }
      _recoveryDraft = null;
      _configured = true;
      _unlock();
      return true;
    } on AccessCredentialException catch (error) {
      if (_isCurrent(operationRevision)) {
        if (error.code == AccessCredentialErrorCode.invalidRecoveryCode) {
          _replace(
            phase: AccessSessionPhase.recovering,
            recoveryStep: AccessRecoveryStep.confirmReplacementCode,
            notice: AccessNotice.recoveryCodeMismatch,
            oneTimeRecoveryCode: draft.recoveryCode,
          );
        } else {
          _failClosed();
        }
      }
      return false;
    } on Object {
      if (_isCurrent(operationRevision)) {
        _failClosed();
      }
      return false;
    }
  }

  Future<bool> changePin({
    required String currentPin,
    required String newPin,
    required String confirmation,
  }) async {
    if (!state.canBuildProtected || state.isBusy) {
      return false;
    }
    if (newPin != confirmation) {
      _replace(notice: AccessNotice.pinMismatch);
      return false;
    }
    if (!PinPolicy.isAcceptable(newPin)) {
      _replace(notice: AccessNotice.pinPolicyRejected);
      return false;
    }
    final int operationRevision = _beginOperation(
      phase: AccessSessionPhase.unlocked,
    );
    try {
      final CredentialAttemptResult result = await _credentialService.changePin(
        currentPin: currentPin,
        newPin: newPin,
        canCommit: () => _isCurrent(operationRevision),
      );
      if (!_isCurrent(operationRevision)) {
        await _reconcileLockedState();
        return false;
      }
      if (!result.isVerified) {
        _applyRejectedAttempt(result, phase: AccessSessionPhase.unlocked);
        return false;
      }
      _replace(
        phase: AccessSessionPhase.unlocked,
        notice: AccessNotice.pinChanged,
      );
      return true;
    } on Object {
      if (_isCurrent(operationRevision)) {
        _failClosed();
      }
      return false;
    }
  }

  Future<bool> setBiometricsEnabled({
    required String currentPin,
    required bool enabled,
  }) async {
    if (!state.canBuildProtected || state.isBusy) {
      return false;
    }
    final int operationRevision = _beginOperation(
      phase: AccessSessionPhase.unlocked,
    );
    if (enabled) {
      final BiometricAvailability availability = await _biometricAuthenticator
          .availability();
      if (!_isCurrent(operationRevision)) {
        return false;
      }
      if (availability != BiometricAvailability.available) {
        _replace(
          phase: AccessSessionPhase.unlocked,
          biometricAvailability: availability,
          notice: AccessNotice.biometricUnavailable,
        );
        return false;
      }
    }

    try {
      final CredentialAttemptResult result = await _credentialService
          .setBiometricsEnabled(
            currentPin: currentPin,
            enabled: enabled,
            canCommit: () => _isCurrent(operationRevision),
          );
      if (!_isCurrent(operationRevision)) {
        await _reconcileLockedState();
        return false;
      }
      if (!result.isVerified) {
        _applyRejectedAttempt(result, phase: AccessSessionPhase.unlocked);
        return false;
      }
      _replace(
        phase: AccessSessionPhase.unlocked,
        biometricsEnabled: enabled,
        biometricAvailability: enabled
            ? BiometricAvailability.available
            : state.biometricAvailability,
        notice: enabled
            ? AccessNotice.biometricsEnabled
            : AccessNotice.biometricsDisabled,
      );
      return true;
    } on Object {
      if (_isCurrent(operationRevision)) {
        _failClosed();
      }
      return false;
    }
  }

  void handleBackgrounded() {
    switch (state.phase) {
      case AccessSessionPhase.authenticating:
      case AccessSessionPhase.recovering:
        lock(reason: AccessLockReason.backgroundOperation);
      case AccessSessionPhase.setupRequired:
        if (state.isBusy ||
            state.setupStep == AccessSetupStep.confirmRecoveryCode) {
          _credentialService.discardDrafts();
          _enrollmentDraft = null;
          _replace(
            phase: AccessSessionPhase.setupRequired,
            setupStep: AccessSetupStep.enterPin,
            oneTimeRecoveryCode: null,
          );
        }
      case AccessSessionPhase.bootstrapping:
      case AccessSessionPhase.locked:
      case AccessSessionPhase.corrupted:
        break;
      case AccessSessionPhase.unlocked:
        if (state.isBusy) {
          lock(reason: AccessLockReason.backgroundOperation);
        } else {
          _replace(phase: AccessSessionPhase.unlocked);
        }
    }
  }

  void lock({AccessLockReason reason = AccessLockReason.manual}) {
    unawaited(_biometricAuthenticator.cancelAuthentication());
    _credentialService.discardDrafts();
    _enrollmentDraft = null;
    _recoveryDraft = null;
    if (!_configured) {
      if (state.phase != AccessSessionPhase.bootstrapping &&
          state.phase != AccessSessionPhase.corrupted) {
        _replace(
          phase: AccessSessionPhase.setupRequired,
          setupStep: AccessSetupStep.enterPin,
          oneTimeRecoveryCode: null,
        );
      }
      return;
    }
    if (state.phase == AccessSessionPhase.corrupted) {
      return;
    }
    _replace(
      phase: AccessSessionPhase.locked,
      notice: reason == AccessLockReason.timeout
          ? AccessNotice.sessionTimedOut
          : null,
      oneTimeRecoveryCode: null,
    );
  }

  void rememberPendingLocation(String location) {
    final PendingDestination? destination =
        PendingDestinationCatalog.fromLocation(location);
    if (destination != null) {
      _pendingDestination = destination;
    }
  }

  String? takePendingLocation() {
    final PendingDestination? destination = _pendingDestination;
    _pendingDestination = null;
    if (destination == null) {
      return null;
    }
    return PendingDestinationCatalog.fromLocation(
      destination.location,
    )?.location;
  }

  void clearNotice() {
    if (state.notice != null && !state.isBusy) {
      _replace(notice: null);
    }
  }

  int _beginOperation({required AccessSessionPhase phase}) {
    final int nextRevision = state.revision + 1;
    state = state.copyWith(
      phase: phase,
      revision: nextRevision,
      isBusy: true,
      notice: null,
      oneTimeRecoveryCode: null,
    );
    return nextRevision;
  }

  bool _isCurrent(int operationRevision) =>
      !_disposed && state.revision == operationRevision;

  void _unlock() {
    _replace(
      phase: AccessSessionPhase.unlocked,
      failedAttempts: 0,
      blockedUntilEpochMillis: null,
      notice: null,
      oneTimeRecoveryCode: null,
    );
  }

  void _applyRejectedAttempt(
    CredentialAttemptResult result, {
    required AccessSessionPhase phase,
  }) {
    _replace(
      phase: phase,
      failedAttempts: result.failedAttempts,
      blockedUntilEpochMillis: result.blockedUntilEpochMillis,
      notice:
          result.status == CredentialAttemptStatus.blocked ||
              result.blockedUntilEpochMillis != null
          ? AccessNotice.progressiveWait
          : AccessNotice.invalidCredential,
    );
  }

  void _handleCredentialException(AccessCredentialException error) {
    final AccessNotice notice = switch (error.code) {
      AccessCredentialErrorCode.invalidPin => AccessNotice.pinPolicyRejected,
      AccessCredentialErrorCode.invalidRecoveryCode =>
        AccessNotice.recoveryCodeMismatch,
      _ => AccessNotice.credentialStateCorrupted,
    };
    if (notice == AccessNotice.credentialStateCorrupted) {
      _failClosed();
    } else {
      _replace(notice: notice);
    }
  }

  void _failClosed() {
    _configured = true;
    _credentialService.discardDrafts();
    _enrollmentDraft = null;
    _recoveryDraft = null;
    _replace(
      phase: AccessSessionPhase.corrupted,
      notice: AccessNotice.credentialStateCorrupted,
      oneTimeRecoveryCode: null,
    );
  }

  Future<void> _reconcileLockedState() async {
    if (_disposed ||
        state.phase == AccessSessionPhase.unlocked ||
        state.isBusy) {
      return;
    }
    final int revision = state.revision;
    try {
      final AccessCredentialRecord? record = await _credentialStore.read();
      if (!_isCurrent(revision) ||
          state.phase == AccessSessionPhase.unlocked ||
          state.isBusy) {
        return;
      }
      if (record == null) {
        _configured = false;
        _replace(
          phase: AccessSessionPhase.setupRequired,
          setupStep: AccessSetupStep.enterPin,
          oneTimeRecoveryCode: null,
        );
        return;
      }
      _configured = true;
      _replace(
        phase: AccessSessionPhase.locked,
        biometricsEnabled: record.biometricsEnabled,
        failedAttempts: record.failedAttempts,
        blockedUntilEpochMillis: record.blockedUntilEpochMillis,
        oneTimeRecoveryCode: null,
      );
    } on Object {
      if (_isCurrent(revision)) {
        _failClosed();
      }
    }
  }

  void _replace({
    AccessSessionPhase? phase,
    AccessSetupStep? setupStep,
    AccessRecoveryStep? recoveryStep,
    bool? biometricsEnabled,
    BiometricAvailability? biometricAvailability,
    int? failedAttempts,
    Object? blockedUntilEpochMillis = _notProvided,
    Object? notice = _notProvided,
    Object? oneTimeRecoveryCode = _notProvided,
  }) {
    state = state.copyWith(
      phase: phase,
      revision: state.revision + 1,
      setupStep: setupStep,
      recoveryStep: recoveryStep,
      biometricsEnabled: biometricsEnabled,
      biometricAvailability: biometricAvailability,
      isBusy: false,
      failedAttempts: failedAttempts,
      blockedUntilEpochMillis: identical(blockedUntilEpochMillis, _notProvided)
          ? state.blockedUntilEpochMillis
          : blockedUntilEpochMillis,
      notice: identical(notice, _notProvided) ? state.notice : notice,
      oneTimeRecoveryCode: identical(oneTimeRecoveryCode, _notProvided)
          ? state.oneTimeRecoveryCode
          : oneTimeRecoveryCode,
    );
  }

  static const Object _notProvided = Object();
}
