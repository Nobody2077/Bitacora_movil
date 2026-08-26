import 'dart:async';
import 'dart:convert';

import 'access_clock.dart';
import 'access_credential_exception.dart';
import 'access_credential_hasher.dart';
import 'access_credential_record.dart';
import 'access_credential_store.dart';
import 'pin_policy.dart';
import 'recovery_code.dart';

enum CredentialAttemptStatus { verified, rejected, blocked }

typedef CredentialCommitGuard = bool Function();

/// Non-sensitive verification metadata; it never carries a credential.
final class CredentialAttemptResult {
  const CredentialAttemptResult._({
    required this.status,
    required this.failedAttempts,
    required this.blockedUntilEpochMillis,
  });

  factory CredentialAttemptResult.verified() => CredentialAttemptResult._(
    status: CredentialAttemptStatus.verified,
    failedAttempts: 0,
    blockedUntilEpochMillis: null,
  );

  factory CredentialAttemptResult.rejected({
    required int failedAttempts,
    required int? blockedUntilEpochMillis,
  }) => CredentialAttemptResult._(
    status: CredentialAttemptStatus.rejected,
    failedAttempts: failedAttempts,
    blockedUntilEpochMillis: blockedUntilEpochMillis,
  );

  factory CredentialAttemptResult.blocked({
    required int failedAttempts,
    required int blockedUntilEpochMillis,
  }) => CredentialAttemptResult._(
    status: CredentialAttemptStatus.blocked,
    failedAttempts: failedAttempts,
    blockedUntilEpochMillis: blockedUntilEpochMillis,
  );

  final CredentialAttemptStatus status;
  final int failedAttempts;
  final int? blockedUntilEpochMillis;

  bool get isVerified => status == CredentialAttemptStatus.verified;

  @override
  String toString() =>
      'CredentialAttemptResult(status: ${status.name}, failedAttempts: '
      '$failedAttempts, blocked: ${blockedUntilEpochMillis != null})';
}

/// In-memory enrollment material. It is intentionally not serializable and
/// its diagnostic representation redacts the one-time recovery credential.
final class AccessEnrollmentDraft {
  AccessEnrollmentDraft._({
    required AccessCredentialRecord record,
    required String recoveryCode,
  }) : _record = record,
       _recoveryCode = recoveryCode;

  final AccessCredentialRecord _record;
  final String _recoveryCode;

  String get recoveryCode => RecoveryCodeCodec.format(_recoveryCode);

  @override
  String toString() => 'AccessEnrollmentDraft(<redacted>)';
}

/// In-memory result of a valid recovery attempt. Nothing is persisted until
/// its replacement recovery code is confirmed.
final class AccessRecoveryDraft {
  AccessRecoveryDraft._({
    required AccessCredentialRecord baseline,
    required AccessCredentialRecord replacement,
    required String recoveryCode,
  }) : _baselineJson = baseline.toJsonString(),
       _replacement = replacement,
       _recoveryCode = recoveryCode;

  final String _baselineJson;
  final AccessCredentialRecord _replacement;
  final String _recoveryCode;

  String get recoveryCode => RecoveryCodeCodec.format(_recoveryCode);

  @override
  String toString() => 'AccessRecoveryDraft(<redacted>)';
}

final class RecoveryDraftResult {
  const RecoveryDraftResult._({required this.attempt, required this.draft});

  factory RecoveryDraftResult.rejected(CredentialAttemptResult attempt) =>
      RecoveryDraftResult._(attempt: attempt, draft: null);

  factory RecoveryDraftResult.created(AccessRecoveryDraft draft) =>
      RecoveryDraftResult._(
        attempt: CredentialAttemptResult.verified(),
        draft: draft,
      );

  final CredentialAttemptResult attempt;
  final AccessRecoveryDraft? draft;

  bool get hasDraft => draft != null;

  @override
  String toString() =>
      'RecoveryDraftResult(attempt: $attempt, draft: '
      '${draft == null ? 'none' : '<redacted>'})';
}

/// Owns all verifier transitions and serializes them to avoid lost failure
/// counters. It has no dependency on Flutter, Riverpod or platform channels.
final class CredentialService {
  CredentialService({
    required AccessCredentialStore store,
    required AccessCredentialHasher hasher,
    required RecoveryCodeGenerator recoveryCodeGenerator,
    required AccessClock clock,
  }) : _store = store,
       _hasher = hasher,
       _recoveryCodeGenerator = recoveryCodeGenerator,
       _clock = clock;

  static const int maximumFailedAttempts = 1000000;

  final AccessCredentialStore _store;
  final AccessCredentialHasher _hasher;
  final RecoveryCodeGenerator _recoveryCodeGenerator;
  final AccessClock _clock;
  final _mutex = _AsyncMutex();
  final Set<AccessEnrollmentDraft> _activeDrafts =
      Set<AccessEnrollmentDraft>.identity();
  final Set<AccessRecoveryDraft> _activeRecoveryDrafts =
      Set<AccessRecoveryDraft>.identity();
  // Epoch común para material de un solo uso y commits de credenciales. Toda
  // transición de sesión cerrada lo incrementa mediante [discardDrafts].
  int _operationEpoch = 0;

  /// Invalidates one-time plaintext material, for example on lock/background.
  /// Session code must still discard any late future through its own revision.
  void discardDrafts() {
    _operationEpoch += 1;
    _activeDrafts.clear();
    _activeRecoveryDrafts.clear();
  }

  void discardEnrollmentDraft(AccessEnrollmentDraft draft) {
    if (_activeDrafts.remove(draft)) {
      _operationEpoch += 1;
    }
  }

  void discardRecoveryDraft(AccessRecoveryDraft draft) {
    if (_activeRecoveryDrafts.remove(draft)) {
      _operationEpoch += 1;
    }
  }

  /// Derives the initial verifiers but does not persist them. The caller must
  /// show and confirm [AccessEnrollmentDraft.recoveryCode] first.
  Future<AccessEnrollmentDraft> createEnrollmentDraft({required String pin}) {
    _requireAcceptablePin(pin);
    return _mutex.protect(() async {
      final draftRevision = _operationEpoch;
      if (await _store.read() != null) {
        throw const AccessCredentialException(
          AccessCredentialErrorCode.alreadyConfigured,
        );
      }

      final recovery = _recoveryCodeGenerator.generate();
      final pinSalt = _hasher.generateSalt();
      final recoverySalt = _hasher.generateSalt();
      final verifiers = await Future.wait<List<int>>(<Future<List<int>>>[
        _hasher.deriveVerifier(secret: pin, salt: pinSalt),
        _hasher.deriveVerifier(secret: recovery.canonical, salt: recoverySalt),
      ]);
      if (draftRevision != _operationEpoch) {
        throw const AccessCredentialException(
          AccessCredentialErrorCode.staleDraft,
        );
      }
      final draft = AccessEnrollmentDraft._(
        record: AccessCredentialRecord(
          pinSalt: pinSalt,
          pinVerifier: verifiers[0],
          recoverySalt: recoverySalt,
          recoveryVerifier: verifiers[1],
          biometricsEnabled: false,
          failedAttempts: 0,
          blockedUntilEpochMillis: null,
          lastFailureEpochMillis: null,
        ),
        recoveryCode: recovery.canonical,
      );
      _activeDrafts.add(draft);
      return draft;
    });
  }

  /// Persists an enrollment only after the exact one-time code is confirmed.
  Future<void> confirmEnrollment({
    required AccessEnrollmentDraft draft,
    required String recoveryCode,
    CredentialCommitGuard? canCommit,
  }) => _mutex.protect(() async {
    final draftRevision = _operationEpoch;
    if (!_activeDrafts.contains(draft)) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.invalidRecoveryCode,
      );
    }
    final normalized = RecoveryCodeCodec.tryNormalize(recoveryCode);
    final matches =
        normalized != null &&
        _hasher.constantTimeEquals(
          utf8.encode(normalized),
          utf8.encode(draft._recoveryCode),
        );
    if (!matches) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.invalidRecoveryCode,
      );
    }
    final existing = await _store.read();
    if (draftRevision != _operationEpoch || !_activeDrafts.contains(draft)) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.staleDraft,
      );
    }
    if (existing != null) {
      _activeDrafts.remove(draft);
      throw const AccessCredentialException(
        AccessCredentialErrorCode.alreadyConfigured,
      );
    }
    _requireCurrentMutation(draftRevision, canCommit: canCommit);
    await _store.write(draft._record);
    _activeDrafts.remove(draft);
  });

  Future<CredentialAttemptResult> verifyPin(
    String pin, {
    CredentialCommitGuard? canCommit,
  }) {
    final mutationRevision = _operationEpoch;
    return _mutex.protect(() async {
      final record = await _requireRecord();
      final blocked = _blockedResult(record);
      if (blocked != null) {
        return blocked;
      }
      final candidate = await _hasher.deriveVerifier(
        secret: pin,
        salt: record.pinSalt,
      );
      final matches =
          PinPolicy.isAcceptable(pin) &&
          _hasher.constantTimeEquals(candidate, record.pinVerifier);
      return matches
          ? _accept(
              record,
              mutationRevision: mutationRevision,
              canCommit: canCommit,
            )
          : _reject(record);
    });
  }

  Future<CredentialAttemptResult> changePin({
    required String currentPin,
    required String newPin,
    CredentialCommitGuard? canCommit,
  }) {
    _requireAcceptablePin(newPin);
    final mutationRevision = _operationEpoch;
    return _mutex.protect(() async {
      final record = await _requireRecord();
      final blocked = _blockedResult(record);
      if (blocked != null) {
        return blocked;
      }
      final currentVerifier = await _hasher.deriveVerifier(
        secret: currentPin,
        salt: record.pinSalt,
      );
      if (!PinPolicy.isAcceptable(currentPin) ||
          !_hasher.constantTimeEquals(currentVerifier, record.pinVerifier)) {
        return _reject(record);
      }
      final salt = _hasher.generateSalt();
      final verifier = await _hasher.deriveVerifier(secret: newPin, salt: salt);
      _requireCurrentMutation(mutationRevision, canCommit: canCommit);
      await _store.write(
        _resetAttempts(record.copyWith(pinSalt: salt, pinVerifier: verifier)),
      );
      return CredentialAttemptResult.verified();
    });
  }

  /// Validates recovery and prepares replacement verifiers without persisting
  /// them. Invalid attempts are persisted before this future completes.
  Future<RecoveryDraftResult> createRecoveryDraft({
    required String recoveryCode,
    required String newPin,
  }) {
    _requireAcceptablePin(newPin);
    return _mutex.protect(() async {
      final draftRevision = _operationEpoch;
      final record = await _requireRecord();
      final blocked = _blockedResult(record);
      if (blocked != null) {
        return RecoveryDraftResult.rejected(blocked);
      }
      final normalized = RecoveryCodeCodec.tryNormalize(recoveryCode);
      final candidate = await _hasher.deriveVerifier(
        secret: normalized ?? recoveryCode,
        salt: record.recoverySalt,
      );
      if (normalized == null ||
          !_hasher.constantTimeEquals(candidate, record.recoveryVerifier)) {
        return RecoveryDraftResult.rejected(await _reject(record));
      }

      final replacement = _recoveryCodeGenerator.generate();
      final pinSalt = _hasher.generateSalt();
      final recoverySalt = _hasher.generateSalt();
      final verifiers = await Future.wait<List<int>>(<Future<List<int>>>[
        _hasher.deriveVerifier(secret: newPin, salt: pinSalt),
        _hasher.deriveVerifier(
          secret: replacement.canonical,
          salt: recoverySalt,
        ),
      ]);
      if (draftRevision != _operationEpoch) {
        throw const AccessCredentialException(
          AccessCredentialErrorCode.staleDraft,
        );
      }
      final draft = AccessRecoveryDraft._(
        baseline: record,
        replacement: AccessCredentialRecord(
          pinSalt: pinSalt,
          pinVerifier: verifiers[0],
          recoverySalt: recoverySalt,
          recoveryVerifier: verifiers[1],
          biometricsEnabled: record.biometricsEnabled,
          failedAttempts: 0,
          blockedUntilEpochMillis: null,
          lastFailureEpochMillis: null,
        ),
        recoveryCode: replacement.canonical,
      );
      _activeRecoveryDrafts.add(draft);
      return RecoveryDraftResult.created(draft);
    });
  }

  /// Confirms the displayed replacement code and then atomically rotates the
  /// PIN and recovery verifiers. A changed baseline fails closed.
  Future<void> confirmRecovery({
    required AccessRecoveryDraft draft,
    required String recoveryCode,
    CredentialCommitGuard? canCommit,
  }) => _mutex.protect(() async {
    final draftRevision = _operationEpoch;
    if (!_activeRecoveryDrafts.contains(draft)) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.invalidRecoveryCode,
      );
    }
    final normalized = RecoveryCodeCodec.tryNormalize(recoveryCode);
    final matches =
        normalized != null &&
        _hasher.constantTimeEquals(
          utf8.encode(normalized),
          utf8.encode(draft._recoveryCode),
        );
    if (!matches) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.invalidRecoveryCode,
      );
    }
    final baseline = await _requireRecord();
    if (draftRevision != _operationEpoch ||
        !_activeRecoveryDrafts.contains(draft) ||
        baseline.toJsonString() != draft._baselineJson) {
      _activeRecoveryDrafts.remove(draft);
      throw const AccessCredentialException(
        AccessCredentialErrorCode.staleDraft,
      );
    }
    _requireCurrentMutation(draftRevision, canCommit: canCommit);
    await _store.write(draft._replacement);
    _activeRecoveryDrafts.remove(draft);
  });

  /// Changes the preference only after a successful app-PIN check.
  Future<CredentialAttemptResult> setBiometricsEnabled({
    required String currentPin,
    required bool enabled,
    CredentialCommitGuard? canCommit,
  }) {
    final mutationRevision = _operationEpoch;
    return _mutex.protect(() async {
      final record = await _requireRecord();
      final blocked = _blockedResult(record);
      if (blocked != null) {
        return blocked;
      }
      final currentVerifier = await _hasher.deriveVerifier(
        secret: currentPin,
        salt: record.pinSalt,
      );
      if (!PinPolicy.isAcceptable(currentPin) ||
          !_hasher.constantTimeEquals(currentVerifier, record.pinVerifier)) {
        return _reject(record);
      }
      _requireCurrentMutation(mutationRevision, canCommit: canCommit);
      await _store.write(
        _resetAttempts(record.copyWith(biometricsEnabled: enabled)),
      );
      return CredentialAttemptResult.verified();
    });
  }

  /// Clears persisted PIN/recovery throttling only after the caller has
  /// received an authenticated result from the biometric platform boundary.
  Future<void> recordBiometricSuccess({CredentialCommitGuard? canCommit}) {
    final mutationRevision = _operationEpoch;
    return _mutex.protect(() async {
      final record = await _requireRecord();
      if (!record.biometricsEnabled) {
        throw const AccessCredentialException(
          AccessCredentialErrorCode.biometricsNotEnabled,
        );
      }
      _requireCurrentMutation(mutationRevision, canCommit: canCommit);
      await _store.write(_resetAttempts(record));
    });
  }

  Future<AccessCredentialRecord> _requireRecord() async {
    final record = await _store.read();
    if (record == null) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.notConfigured,
      );
    }
    return record;
  }

  CredentialAttemptResult? _blockedResult(AccessCredentialRecord record) {
    final blockedUntil = record.blockedUntilEpochMillis;
    if (blockedUntil == null) {
      return null;
    }
    final now = _clock.nowEpochMillis();
    final effectiveNow = _maximum(now, record.lastFailureEpochMillis ?? now);
    if (effectiveNow >= blockedUntil) {
      return null;
    }
    return CredentialAttemptResult.blocked(
      failedAttempts: record.failedAttempts,
      blockedUntilEpochMillis: blockedUntil,
    );
  }

  Future<CredentialAttemptResult> _accept(
    AccessCredentialRecord record, {
    required int mutationRevision,
    CredentialCommitGuard? canCommit,
  }) async {
    _requireCurrentMutation(mutationRevision, canCommit: canCommit);
    await _store.write(_resetAttempts(record));
    return CredentialAttemptResult.verified();
  }

  Future<CredentialAttemptResult> _reject(AccessCredentialRecord record) async {
    final now = _clock.nowEpochMillis();
    final effectiveNow = _maximum(now, record.lastFailureEpochMillis ?? now);
    final failedAttempts = record.failedAttempts >= maximumFailedAttempts
        ? maximumFailedAttempts
        : record.failedAttempts + 1;
    final delayMillis = lockoutDelayMillis(failedAttempts);
    final blockedUntil = delayMillis == 0 ? null : effectiveNow + delayMillis;
    final updated = record.copyWith(
      failedAttempts: failedAttempts,
      blockedUntilEpochMillis: blockedUntil,
      lastFailureEpochMillis: effectiveNow,
    );
    await _store.write(updated);
    return CredentialAttemptResult.rejected(
      failedAttempts: failedAttempts,
      blockedUntilEpochMillis: blockedUntil,
    );
  }

  static int lockoutDelayMillis(int failedAttempts) {
    if (failedAttempts < 5) {
      return 0;
    }
    final seconds = switch (failedAttempts) {
      5 => 30,
      6 => 60,
      7 => 120,
      8 => 240,
      9 => 480,
      _ => 900,
    };
    return seconds * Duration.millisecondsPerSecond;
  }

  static AccessCredentialRecord _resetAttempts(AccessCredentialRecord record) =>
      record.copyWith(
        failedAttempts: 0,
        blockedUntilEpochMillis: null,
        lastFailureEpochMillis: null,
      );

  static void _requireAcceptablePin(String pin) {
    if (!PinPolicy.isAcceptable(pin)) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.invalidPin,
      );
    }
  }

  void _requireCurrentMutation(
    int mutationRevision, {
    CredentialCommitGuard? canCommit,
  }) {
    if (mutationRevision != _operationEpoch || canCommit?.call() == false) {
      throw const AccessCredentialException(
        AccessCredentialErrorCode.staleOperation,
      );
    }
  }

  static int _maximum(int left, int right) => left > right ? left : right;
}

final class _AsyncMutex {
  Future<void> _tail = Future<void>.value();

  Future<T> protect<T>(Future<T> Function() action) async {
    final predecessor = _tail;
    final release = Completer<void>();
    _tail = predecessor.then((_) => release.future);
    await predecessor;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }
}
