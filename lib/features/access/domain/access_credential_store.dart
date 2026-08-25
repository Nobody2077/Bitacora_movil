import 'access_credential_record.dart';

/// Encrypted external persistence boundary implemented by the Android bridge.
abstract interface class AccessCredentialStore {
  Future<AccessCredentialRecord?> read();

  Future<void> write(AccessCredentialRecord record);
}
