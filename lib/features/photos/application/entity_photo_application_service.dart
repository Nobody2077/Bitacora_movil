import 'dart:typed_data';

import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../journal/application/journal_application_service.dart'
    show JournalClock, JournalIdGenerator;
import '../../journal/application/journal_photo_application_service.dart'
    show JournalPhotoPicker;
import '../domain/entity_photo.dart';

/// Foto única de un personaje o una misión, con el mismo orden de escritura
/// que las fotos de Bitácora: fichero temporal cifrado → fila en la base →
/// confirmar el fichero. Si algo falla a mitad, se deshace lo hecho.
final class EntityPhotoApplicationService {
  const EntityPhotoApplicationService({
    required EntityPhotoRepository repository,
    required EntityPhotoStore photoStore,
    required JournalPhotoPicker picker,
    required JournalClock clock,
    required JournalIdGenerator idGenerator,
  }) : _repository = repository,
       _photoStore = photoStore,
       _picker = picker,
       _clock = clock,
       _idGenerator = idGenerator;

  final EntityPhotoRepository _repository;
  final EntityPhotoStore _photoStore;
  final JournalPhotoPicker _picker;
  final JournalClock _clock;
  final JournalIdGenerator _idGenerator;

  /// Elige una foto y la deja como la vigente de [ownerId], sustituyendo la
  /// anterior. Devuelve `null` si el usuario cancela.
  Future<Result<EntityPhoto?>> pickAndSet(
    EntityPhotoOwner owner,
    String ownerId, {
    bool useCamera = false,
  }) async {
    if (ownerId.trim().isEmpty) {
      return const Failure<EntityPhoto?>(
        ValidationFailure('El dueño de la fotografía no es válido.'),
      );
    }
    final PreparedEntityPhoto prepared;
    try {
      final String? sourcePath = await _picker.pickPhotoPath(
        useCamera: useCamera,
      );
      if (sourcePath == null) {
        return const Success<EntityPhoto?>(null);
      }
      prepared = await _photoStore.importPhoto(sourcePath);
    } on Object catch (error) {
      return Failure<EntityPhoto?>(
        StorageFailure(
          'No se pudo importar y cifrar la fotografía.',
          cause: error,
        ),
      );
    }

    final Result<EntityPhotoReplaced> saved = await _repository.replace(
      EntityPhoto(
        id: _idGenerator.nextId(),
        owner: owner,
        ownerId: ownerId,
        storageName: prepared.storageName,
        mimeType: prepared.mimeType,
        byteLength: prepared.byteLength,
        cipherSha256: prepared.cipherSha256,
        widthPx: prepared.widthPx,
        heightPx: prepared.heightPx,
        createdAtUtc: _clock.nowUtc(),
      ),
    );
    return saved.fold<Future<Result<EntityPhoto?>>>(
      onSuccess: (EntityPhotoReplaced replaced) async {
        try {
          await _photoStore.commitPhoto(prepared.storageName);
        } on Object catch (error) {
          await _repository.revertReplacement(replaced, atUtc: _clock.nowUtc());
          await _deleteBestEffort(prepared.storageName);
          return Failure<EntityPhoto?>(
            StorageFailure(
              'No se pudo confirmar el archivo cifrado.',
              cause: error,
            ),
          );
        }
        final EntityPhoto? previous = replaced.previous;
        if (previous != null) {
          await _deleteBestEffort(previous.storageName);
        }
        return Success<EntityPhoto?>(replaced.current);
      },
      onFailure: (AppFailure failure) async {
        await _deleteBestEffort(prepared.storageName);
        return Failure<EntityPhoto?>(failure);
      },
    );
  }

  Future<Result<Uint8List>> read(EntityPhoto photo) async {
    try {
      return Success<Uint8List>(await _photoStore.readPhoto(photo));
    } on Object catch (error) {
      return Failure<Uint8List>(
        StorageFailure('No se pudo descifrar la fotografía.', cause: error),
      );
    }
  }

  /// Quita la foto vigente: primero la fila, después el fichero.
  Future<Result<void>> remove(EntityPhotoOwner owner, String ownerId) async {
    final Result<EntityPhoto?> archived = await _repository.archiveCurrent(
      owner,
      ownerId,
      atUtc: _clock.nowUtc(),
    );
    return archived.fold<Future<Result<void>>>(
      onSuccess: (EntityPhoto? photo) async {
        if (photo != null) {
          await _deleteBestEffort(photo.storageName);
        }
        return const Success<void>(null);
      },
      onFailure: (AppFailure failure) async => Failure<void>(failure),
    );
  }

  Future<Result<int>> cleanOrphans() async {
    final Result<Set<String>> active = await _repository
        .findActiveStorageNames();
    return active.fold<Future<Result<int>>>(
      onSuccess: (Set<String> names) async {
        try {
          return Success<int>(await _photoStore.cleanOrphans(names));
        } on Object catch (error) {
          return Failure<int>(
            StorageFailure(
              'No se pudo limpiar el almacén de fotografías.',
              cause: error,
            ),
          );
        }
      },
      onFailure: (AppFailure failure) async => Failure<int>(failure),
    );
  }

  /// Un fichero cifrado que sobra no expone nada; la limpieza de huérfanos lo
  /// recoge en otro arranque si aquí falla.
  Future<void> _deleteBestEffort(String storageName) async {
    try {
      await _photoStore.deletePhoto(storageName);
    } on Object {
      // Se reintenta con cleanOrphans.
    }
  }
}
