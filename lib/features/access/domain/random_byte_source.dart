/// Source of bytes used for salts and recovery credentials.
abstract interface class RandomByteSource {
  List<int> nextBytes(int length);
}
