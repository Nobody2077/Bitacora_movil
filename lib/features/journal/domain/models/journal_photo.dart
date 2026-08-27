import 'dart:typed_data';

final class JournalPhoto {
  const JournalPhoto({
    required this.id,
    required this.journalEntryId,
    required this.storageName,
    required this.mimeType,
    required this.byteLength,
    required this.cipherSha256,
    required this.widthPx,
    required this.heightPx,
    required this.position,
    required this.createdAtUtc,
  });

  final String id;
  final String journalEntryId;
  final String storageName;
  final String mimeType;
  final int byteLength;
  final String cipherSha256;
  final int widthPx;
  final int heightPx;
  final int position;
  final DateTime createdAtUtc;
}

final class PreparedJournalPhoto {
  const PreparedJournalPhoto({
    required this.storageName,
    required this.mimeType,
    required this.byteLength,
    required this.cipherSha256,
    required this.widthPx,
    required this.heightPx,
  });

  final String storageName;
  final String mimeType;
  final int byteLength;
  final String cipherSha256;
  final int widthPx;
  final int heightPx;
}

abstract interface class JournalPhotoStore {
  Future<PreparedJournalPhoto> importPhoto(String sourcePath);

  Future<void> commitPhoto(String storageName);

  Future<Uint8List> readPhoto(JournalPhoto photo);

  Future<void> deletePhoto(String storageName);

  Future<int> cleanOrphans(Set<String> activeStorageNames);
}
