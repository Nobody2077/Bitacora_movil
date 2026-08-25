/// Derives and compares PIN/recovery verifiers without retaining plaintext.
abstract interface class AccessCredentialHasher {
  int get saltLength;

  int get verifierLength;

  List<int> generateSalt();

  Future<List<int>> deriveVerifier({
    required String secret,
    required List<int> salt,
  });

  bool constantTimeEquals(List<int> left, List<int> right);
}
