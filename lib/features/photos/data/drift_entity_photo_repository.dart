import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/daos/dao_support.dart';
import '../../../infrastructure/database/daos/entity_photo_dao.dart';
import '../domain/entity_photo.dart';

final class DriftEntityPhotoRepository implements EntityPhotoRepository {
  const DriftEntityPhotoRepository(this._dao);

  final EntityPhotoDao _dao;

  @override
  Future<Result<EntityPhoto?>> findCurrent(
    EntityPhotoOwner owner,
    String ownerId,
  ) async {
    if (ownerId.trim().isEmpty) {
      return const Failure<EntityPhoto?>(
        ValidationFailure('El dueño de la fotografía no es válido.'),
      );
    }
    try {
      final EntityPhotoRow? row = await _dao.findCurrent(_kind(owner), ownerId);
      return Success<EntityPhoto?>(row == null ? null : _fromRow(owner, row));
    } on Object catch (error) {
      return Failure<EntityPhoto?>(
        StorageFailure('No se pudo leer la fotografía.', cause: error),
      );
    }
  }

  @override
  Stream<Result<Map<String, EntityPhoto>>> watchCurrent(
    EntityPhotoOwner owner,
    Set<String> ownerIds,
  ) async* {
    try {
      await for (final Map<String, EntityPhotoRow> rows in _dao.watchCurrent(
        _kind(owner),
        ownerIds,
      )) {
        yield Success<Map<String, EntityPhoto>>(
          Map<String, EntityPhoto>.unmodifiable(
            rows.map(
              (String key, EntityPhotoRow row) =>
                  MapEntry<String, EntityPhoto>(key, _fromRow(owner, row)),
            ),
          ),
        );
      }
    } on Object catch (error) {
      yield Failure<Map<String, EntityPhoto>>(
        StorageFailure('No se pudieron leer las fotografías.', cause: error),
      );
    }
  }

  @override
  Future<Result<EntityPhotoReplaced>> replace(EntityPhoto photo) async {
    if (!_isValid(photo)) {
      return const Failure<EntityPhotoReplaced>(
        ValidationFailure('La fotografía contiene valores inválidos.'),
      );
    }
    try {
      final EntityPhotoReplacement replacement = await _dao.replaceCurrent(
        _kind(photo.owner),
        EntityPhotoRow(
          id: photo.id,
          ownerId: photo.ownerId,
          storageName: photo.storageName,
          mimeType: photo.mimeType,
          byteLength: photo.byteLength,
          cipherSha256: photo.cipherSha256,
          widthPx: photo.widthPx,
          heightPx: photo.heightPx,
          createdAt: photo.createdAtUtc.millisecondsSinceEpoch,
        ),
      );
      final EntityPhotoRow? previous = replacement.previous;
      return Success<EntityPhotoReplaced>(
        EntityPhotoReplaced(
          current: _fromRow(photo.owner, replacement.current),
          previous: previous == null ? null : _fromRow(photo.owner, previous),
        ),
      );
    } on RecordNotFoundException {
      return const Failure<EntityPhotoReplaced>(
        ConflictFailure('Ya no existe a quién poner la fotografía.'),
      );
    } on DatabaseInvariantException {
      return const Failure<EntityPhotoReplaced>(
        ConflictFailure('No se puede poner fotografía a algo archivado.'),
      );
    } on Object catch (error) {
      return Failure<EntityPhotoReplaced>(
        StorageFailure('No se pudo registrar la fotografía.', cause: error),
      );
    }
  }

  @override
  Future<Result<void>> revertReplacement(
    EntityPhotoReplaced replaced, {
    required DateTime atUtc,
  }) async {
    try {
      await _dao.revertReplacement(
        _kind(replaced.current.owner),
        newPhotoId: replaced.current.id,
        previousPhotoId: replaced.previous?.id,
        archivedAtUtcMs: atUtc.millisecondsSinceEpoch,
      );
      return const Success<void>(null);
    } on Object catch (error) {
      return Failure<void>(
        StorageFailure('No se pudo deshacer la fotografía.', cause: error),
      );
    }
  }

  @override
  Future<Result<EntityPhoto?>> archiveCurrent(
    EntityPhotoOwner owner,
    String ownerId, {
    required DateTime atUtc,
  }) async {
    if (ownerId.trim().isEmpty || !atUtc.isUtc) {
      return const Failure<EntityPhoto?>(
        ValidationFailure('La fotografía no es válida.'),
      );
    }
    try {
      final EntityPhotoRow? row = await _dao.archiveCurrent(
        _kind(owner),
        ownerId,
        archivedAtUtcMs: atUtc.millisecondsSinceEpoch,
      );
      return Success<EntityPhoto?>(row == null ? null : _fromRow(owner, row));
    } on Object catch (error) {
      return Failure<EntityPhoto?>(
        StorageFailure('No se pudo retirar la fotografía.', cause: error),
      );
    }
  }

  @override
  Future<Result<Set<String>>> findActiveStorageNames() async {
    try {
      return Success<Set<String>>(await _dao.findActiveStorageNames());
    } on Object catch (error) {
      return Failure<Set<String>>(
        StorageFailure(
          'No se pudo verificar el almacén privado.',
          cause: error,
        ),
      );
    }
  }

  static bool _isValid(EntityPhoto photo) =>
      photo.id.trim().isNotEmpty &&
      photo.ownerId.trim().isNotEmpty &&
      photo.storageName.trim().isNotEmpty &&
      photo.mimeType == 'image/jpeg' &&
      photo.byteLength > 0 &&
      RegExp(r'^[0-9a-f]{64}$').hasMatch(photo.cipherSha256) &&
      photo.widthPx > 0 &&
      photo.heightPx > 0 &&
      photo.createdAtUtc.isUtc;

  static PhotoOwnerKind _kind(EntityPhotoOwner owner) => switch (owner) {
    EntityPhotoOwner.contact => PhotoOwnerKind.contact,
    EntityPhotoOwner.mission => PhotoOwnerKind.mission,
  };

  static EntityPhoto _fromRow(EntityPhotoOwner owner, EntityPhotoRow row) =>
      EntityPhoto(
        id: row.id,
        owner: owner,
        ownerId: row.ownerId,
        storageName: row.storageName,
        mimeType: row.mimeType,
        byteLength: row.byteLength,
        cipherSha256: row.cipherSha256,
        widthPx: row.widthPx,
        heightPx: row.heightPx,
        createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
          row.createdAt,
          isUtc: true,
        ),
      );
}
