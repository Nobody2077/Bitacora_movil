/// Stable, non-sensitive error codes for the access credential boundary.
enum AccessCredentialErrorCode {
  invalidPin,
  alreadyConfigured,
  notConfigured,
  invalidCredentialRecord,
  invalidHashParameters,
  invalidRecoveryCode,
  staleDraft,
  biometricsNotEnabled,
}

/// An access error whose string representation never includes a credential.
final class AccessCredentialException implements Exception {
  const AccessCredentialException(this.code);

  final AccessCredentialErrorCode code;

  @override
  String toString() => 'AccessCredentialException(${code.name})';
}
