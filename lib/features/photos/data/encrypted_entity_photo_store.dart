import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../../infrastructure/photos/encrypted_photo_vault.dart';
import '../../../infrastructure/security/database_key_store.dart';
import '../domain/entity_photo.dart';

/// Fotos de personajes y misiones (ADR-006): carpeta y clave `entity_photos`,
/// separadas de las de Bitácora para que ninguna limpieza borre las de otra.
final class EncryptedEntityPhotoStore implements EntityPhotoStore {
  EncryptedEntityPhotoStore({
    required DatabaseKeyStore keyStore,
    required Future<Directory> Function() directoryLocator,
    Random? random,
  }) : _vault = EncryptedPhotoVault(
         keyStore: keyStore,
         directoryLocator: directoryLocator,
         directoryName: storageId,
         storageId: storageId,
         random: random,
       );

  /// Debe figurar en la lista permitida de `DatabaseKeyStoreBridge.kt`; si
  /// no, las compilaciones release rechazan la clave.
  static const String storageId = 'entity_photos';

  final EncryptedPhotoVault _vault;

  @override
  Future<PreparedEntityPhoto> importPhoto(String sourcePath) async {
    final PreparedEncryptedPhoto prepared = await _vault.import(sourcePath);
    return PreparedEntityPhoto(
      storageName: prepared.storageName,
      mimeType: prepared.mimeType,
      byteLength: prepared.byteLength,
      cipherSha256: prepared.cipherSha256,
      widthPx: prepared.widthPx,
      heightPx: prepared.heightPx,
    );
  }

  @override
  Future<void> commitPhoto(String storageName) => _vault.commit(storageName);

  @override
  Future<Uint8List> readPhoto(EntityPhoto photo) => _vault.read(
    storageName: photo.storageName,
    byteLength: photo.byteLength,
    cipherSha256: photo.cipherSha256,
  );

  @override
  Future<void> deletePhoto(String storageName) => _vault.delete(storageName);

  @override
  Future<int> cleanOrphans(Set<String> activeStorageNames) =>
      _vault.cleanOrphans(activeStorageNames);
}
