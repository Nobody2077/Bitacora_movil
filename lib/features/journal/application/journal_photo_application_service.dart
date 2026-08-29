import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../domain/models/journal_photo.dart';
import '../domain/repositories/journal_repository.dart';
import 'journal_application_service.dart';

abstract interface class JournalPhotoPicker {
  Future<String?> pickPhotoPath({bool useCamera = false});
}

final class ImagePickerJournalPhotoPicker implements JournalPhotoPicker {
  ImagePickerJournalPhotoPicker(this._picker);

  final ImagePicker _picker;

  @override
  Future<String?> pickPhotoPath({bool useCamera = false}) async {
    final XFile? photo = await _picker.pickImage(
      source: useCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 4096,
      maxHeight: 4096,
      imageQuality: 95,
    );
    return photo?.path;
  }
}

final class JournalPhotoApplicationService {
  const JournalPhotoApplicationService({
    required JournalRepository repository,
    required JournalPhotoStore photoStore,
    required JournalPhotoPicker picker,
    required JournalClock clock,
    required JournalIdGenerator idGenerator,
  }) : _repository = repository,
       _photoStore = photoStore,
       _picker = picker,
       _clock = clock,
       _idGenerator = idGenerator;

  final JournalRepository _repository;
  final JournalPhotoStore _photoStore;
  final JournalPhotoPicker _picker;
  final JournalClock _clock;
  final JournalIdGenerator _idGenerator;

  Future<Result<JournalPhoto?>> pickAndAdd(
    String entryId, {
    bool useCamera = false,
  }) async {
    if (entryId.trim().isEmpty) {
      return const Failure<JournalPhoto?>(
        ValidationFailure('La entrada de Bitácora no es válida.'),
      );
    }
    try {
      final String? sourcePath = await _picker.pickPhotoPath(
        useCamera: useCamera,
      );
      if (sourcePath == null) {
        return const Success<JournalPhoto?>(null);
      }
      final Result<List<JournalPhoto>> currentResult = await _repository
          .findPhotos(entryId);
      final List<JournalPhoto>? current = currentResult.fold(
        onSuccess: (value) => value,
        onFailure: (_) => null,
      );
      if (current == null) {
        return Failure<JournalPhoto?>(
          currentResult.fold(
            onSuccess: (_) =>
                const UnexpectedFailure('No se pudo preparar la fotografía.'),
            onFailure: (failure) => failure,
          ),
        );
      }

      final PreparedJournalPhoto prepared = await _photoStore.importPhoto(
        sourcePath,
      );
      final int nextPosition = current.isEmpty
          ? 0
          : current
                    .map((photo) => photo.position)
                    .reduce((left, right) => left > right ? left : right) +
                1;
      final JournalPhoto photo = JournalPhoto(
        id: _idGenerator.nextId(),
        journalEntryId: entryId,
        storageName: prepared.storageName,
        mimeType: prepared.mimeType,
        byteLength: prepared.byteLength,
        cipherSha256: prepared.cipherSha256,
        widthPx: prepared.widthPx,
        heightPx: prepared.heightPx,
        position: nextPosition,
        createdAtUtc: _clock.nowUtc(),
      );
      final Result<JournalPhoto> saved = await _repository.addPhoto(photo);
      return await saved.fold<Future<Result<JournalPhoto?>>>(
        onSuccess: (value) async {
          try {
            await _photoStore.commitPhoto(prepared.storageName);
            return Success<JournalPhoto?>(value);
          } on Object catch (error) {
            await _repository.archivePhoto(
              attachmentId: value.id,
              archivedAtUtc: _clock.nowUtc(),
            );
            await _photoStore.deletePhoto(prepared.storageName);
            return Failure<JournalPhoto?>(
              StorageFailure(
                'No se pudo confirmar el archivo cifrado.',
                cause: error,
              ),
            );
          }
        },
        onFailure: (failure) async {
          await _photoStore.deletePhoto(prepared.storageName);
          return Failure<JournalPhoto?>(failure);
        },
      );
    } on Object catch (error) {
      return Failure<JournalPhoto?>(
        StorageFailure(
          'No se pudo importar y cifrar la fotografía.',
          cause: error,
        ),
      );
    }
  }

  Future<Result<Uint8List>> read(JournalPhoto photo) async {
    try {
      return Success<Uint8List>(await _photoStore.readPhoto(photo));
    } on Object catch (error) {
      return Failure<Uint8List>(
        StorageFailure('No se pudo descifrar la fotografía.', cause: error),
      );
    }
  }

  Future<Result<void>> remove(JournalPhoto photo) async {
    final Result<JournalPhoto?> archived = await _repository.archivePhoto(
      attachmentId: photo.id,
      archivedAtUtc: _clock.nowUtc(),
    );
    return await archived.fold<Future<Result<void>>>(
      onSuccess: (JournalPhoto? value) async {
        if (value != null) {
          await _photoStore.deletePhoto(value.storageName);
        }
        return const Success<void>(null);
      },
      onFailure: (failure) async => Failure<void>(failure),
    );
  }

  Future<Result<int>> cleanOrphans() async {
    final Result<Set<String>> active = await _repository
        .findActivePhotoStorageNames();
    return await active.fold<Future<Result<int>>>(
      onSuccess: (names) async {
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
      onFailure: (failure) async => Failure<int>(failure),
    );
  }
}
