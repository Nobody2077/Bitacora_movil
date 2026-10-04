import 'dart:typed_data';

import '../../../core/result/result.dart';

/// Quién lleva la foto única (ADR-006 D15/D16). Objetos del inventario: fase 2.
enum EntityPhotoOwner { contact, mission }

final class EntityPhoto {
  const EntityPhoto({
    required this.id,
    required this.owner,
    required this.ownerId,
    required this.storageName,
    required this.mimeType,
    required this.byteLength,
    required this.cipherSha256,
    required this.widthPx,
    required this.heightPx,
    required this.createdAtUtc,
  });

  final String id;
  final EntityPhotoOwner owner;
  final String ownerId;
  final String storageName;
  final String mimeType;
  final int byteLength;
  final String cipherSha256;
  final int widthPx;
  final int heightPx;
  final DateTime createdAtUtc;

  @override
  bool operator ==(Object other) =>
      other is EntityPhoto &&
      other.id == id &&
      other.owner == owner &&
      other.storageName == storageName &&
      other.cipherSha256 == cipherSha256;

  @override
  int get hashCode => Object.hash(id, owner, storageName, cipherSha256);
}

final class PreparedEntityPhoto {
  const PreparedEntityPhoto({
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

final class EntityPhotoReplaced {
  const EntityPhotoReplaced({required this.current, this.previous});

  final EntityPhoto current;
  final EntityPhoto? previous;
}

/// Ficheros cifrados de las fotos de personajes y misiones.
abstract interface class EntityPhotoStore {
  Future<PreparedEntityPhoto> importPhoto(String sourcePath);

  Future<void> commitPhoto(String storageName);

  Future<Uint8List> readPhoto(EntityPhoto photo);

  Future<void> deletePhoto(String storageName);

  Future<int> cleanOrphans(Set<String> activeStorageNames);
}

abstract interface class EntityPhotoRepository {
  Future<Result<EntityPhoto?>> findCurrent(
    EntityPhotoOwner owner,
    String ownerId,
  );

  Stream<Result<Map<String, EntityPhoto>>> watchCurrent(
    EntityPhotoOwner owner,
    Set<String> ownerIds,
  );

  Future<Result<EntityPhotoReplaced>> replace(EntityPhoto photo);

  Future<Result<void>> revertReplacement(
    EntityPhotoReplaced replaced, {
    required DateTime atUtc,
  });

  Future<Result<EntityPhoto?>> archiveCurrent(
    EntityPhotoOwner owner,
    String ownerId, {
    required DateTime atUtc,
  });

  Future<Result<Set<String>>> findActiveStorageNames();
}
