import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../../infrastructure/photos/encrypted_photo_vault.dart';
import '../../../infrastructure/security/database_key_store.dart';
import '../domain/models/journal_photo.dart';

typedef JournalPhotoDirectoryLocator = Future<Directory> Function();

/// Fotos de Bitácora: carpeta y clave `journal_attachments`, sin cambios
/// desde v1. El cifrado vive en [EncryptedPhotoVault].
final class EncryptedJournalPhotoStore implements JournalPhotoStore {
  EncryptedJournalPhotoStore({
    required DatabaseKeyStore keyStore,
    required JournalPhotoDirectoryLocator directoryLocator,
    Random? random,
  }) : _vault = EncryptedPhotoVault(
         keyStore: keyStore,
         directoryLocator: directoryLocator,
         directoryName: storageId,
         storageId: storageId,
         random: random,
       );

  static const String storageId = 'journal_attachments';

  final EncryptedPhotoVault _vault;

  @override
  Future<PreparedJournalPhoto> importPhoto(String sourcePath) =>
      _guard(() async {
        final PreparedEncryptedPhoto prepared = await _vault.import(sourcePath);
        return PreparedJournalPhoto(
          storageName: prepared.storageName,
          mimeType: prepared.mimeType,
          byteLength: prepared.byteLength,
          cipherSha256: prepared.cipherSha256,
          widthPx: prepared.widthPx,
          heightPx: prepared.heightPx,
        );
      });

  @override
  Future<void> commitPhoto(String storageName) =>
      _guard(() => _vault.commit(storageName));

  @override
  Future<Uint8List> readPhoto(JournalPhoto photo) => _guard(
    () => _vault.read(
      storageName: photo.storageName,
      byteLength: photo.byteLength,
      cipherSha256: photo.cipherSha256,
    ),
  );

  @override
  Future<void> deletePhoto(String storageName) =>
      _guard(() => _vault.delete(storageName));

  @override
  Future<int> cleanOrphans(Set<String> activeStorageNames) =>
      _guard(() => _vault.cleanOrphans(activeStorageNames));

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on EncryptedPhotoVaultException catch (error) {
      throw JournalPhotoStoreException(error.code);
    }
  }
}

final class JournalPhotoStoreException implements Exception {
  const JournalPhotoStoreException(this.code);

  final String code;

  @override
  String toString() => 'JournalPhotoStoreException($code)';
}
