import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/providers/persistence_providers.dart';
import '../../../core/result/result.dart';
import '../../journal/application/journal_photo_application_service.dart'
    show ImagePickerJournalPhotoPicker;
import '../../journal/application/journal_providers.dart';
import '../data/encrypted_entity_photo_store.dart';
import '../domain/entity_photo.dart';
import 'entity_photo_application_service.dart';

final Provider<EntityPhotoStore> entityPhotoStoreProvider =
    Provider<EntityPhotoStore>(
      (Ref ref) => EncryptedEntityPhotoStore(
        keyStore: ref.watch(databaseKeyStoreProvider),
        directoryLocator: getApplicationSupportDirectory,
      ),
    );

final Provider<EntityPhotoApplicationService>
entityPhotoApplicationServiceProvider = Provider<EntityPhotoApplicationService>(
  (Ref ref) => EntityPhotoApplicationService(
    repository: ref.watch(entityPhotoRepositoryProvider),
    photoStore: ref.watch(entityPhotoStoreProvider),
    picker: ImagePickerJournalPhotoPicker(ImagePicker()),
    clock: ref.watch(journalClockProvider),
    idGenerator: ref.watch(journalIdGeneratorProvider),
  ),
);

typedef EntityPhotoKey = ({EntityPhotoOwner owner, String ownerId});

/// Foto vigente de un personaje o una misión; se actualiza sola al cambiarla.
final entityPhotoProvider = StreamProvider.family<EntityPhoto?, EntityPhotoKey>(
  (Ref ref, EntityPhotoKey key) => ref
      .watch(entityPhotoRepositoryProvider)
      .watchCurrent(key.owner, <String>{key.ownerId})
      .map(
        (Result<Map<String, EntityPhoto>> result) => result.fold(
          onSuccess: (Map<String, EntityPhoto> photos) => photos[key.ownerId],
          onFailure: (failure) => throw failure,
        ),
      ),
);

final entityPhotoBytesProvider = FutureProvider.family<Uint8List, EntityPhoto>((
  Ref ref,
  EntityPhoto photo,
) async {
  final Result<Uint8List> result = await ref
      .watch(entityPhotoApplicationServiceProvider)
      .read(photo);
  return result.fold(
    onSuccess: (Uint8List bytes) => bytes,
    onFailure: (failure) => throw failure,
  );
});

final FutureProvider<int> entityPhotoCleanupProvider = FutureProvider<int>((
  Ref ref,
) async {
  final Result<int> result = await ref
      .watch(entityPhotoApplicationServiceProvider)
      .cleanOrphans();
  return result.fold(
    onSuccess: (int removed) => removed,
    onFailure: (failure) => throw failure,
  );
});
