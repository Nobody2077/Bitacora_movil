import 'dart:typed_data';

import 'package:bitacora_rpg_personal/core/errors/app_failure.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/journal/application/journal_application_service.dart';
import 'package:bitacora_rpg_personal/features/journal/application/journal_photo_application_service.dart';
import 'package:bitacora_rpg_personal/features/photos/application/entity_photo_application_service.dart';
import 'package:bitacora_rpg_personal/features/photos/domain/entity_photo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancelar la selección no toca nada', () async {
    final _Repository repository = _Repository();
    final _Store store = _Store();

    final Result<EntityPhoto?> result = await _service(
      repository,
      store,
      picker: const _Picker(null),
    ).pickAndSet(EntityPhotoOwner.contact, 'ana');

    expect((result as Success<EntityPhoto?>).value, isNull);
    expect(store.imported, isEmpty);
    expect(repository.replaced, isEmpty);
  });

  test('si la base falla, borra el fichero cifrado preparado', () async {
    final _Repository repository = _Repository(failReplace: true);
    final _Store store = _Store();

    final Result<EntityPhoto?> result = await _service(
      repository,
      store,
    ).pickAndSet(EntityPhotoOwner.mission, 'm1');

    expect(result, isA<Failure<EntityPhoto?>>());
    expect(store.deleted, <String>['new.brpa']);
    expect(store.committed, isEmpty);
  });

  test('si confirmar el fichero falla, deshace el cambio en la base', () async {
    final _Repository repository = _Repository(previous: _photo('old'));
    final _Store store = _Store(failCommit: true);

    final Result<EntityPhoto?> result = await _service(
      repository,
      store,
    ).pickAndSet(EntityPhotoOwner.contact, 'ana');

    expect(result, isA<Failure<EntityPhoto?>>());
    expect(repository.reverted, hasLength(1));
    expect(repository.reverted.single.previous?.id, 'old');
    // La foto anterior sigue intacta: solo se borra la nueva.
    expect(store.deleted, <String>['new.brpa']);
  });

  test('al terminar bien, borra el fichero de la foto sustituida', () async {
    final _Repository repository = _Repository(previous: _photo('old'));
    final _Store store = _Store();

    final Result<EntityPhoto?> result = await _service(
      repository,
      store,
    ).pickAndSet(EntityPhotoOwner.contact, 'ana', useCamera: true);

    expect((result as Success<EntityPhoto?>).value?.storageName, 'new.brpa');
    expect(store.committed, <String>['new.brpa']);
    expect(store.deleted, <String>['old.brpa']);
    expect(repository.reverted, isEmpty);
  });

  test('quitar archiva la fila antes de borrar el fichero', () async {
    final _Repository repository = _Repository(previous: _photo('old'));
    final _Store store = _Store();

    final Result<void> result = await _service(
      repository,
      store,
    ).remove(EntityPhotoOwner.contact, 'ana');

    expect(result, isA<Success<void>>());
    expect(repository.archivedOwners, <String>['ana']);
    expect(store.deleted, <String>['old.brpa']);
  });
}

EntityPhotoApplicationService _service(
  _Repository repository,
  _Store store, {
  JournalPhotoPicker picker = const _Picker('/tmp/source.jpg'),
}) => EntityPhotoApplicationService(
  repository: repository,
  photoStore: store,
  picker: picker,
  clock: const _Clock(),
  idGenerator: const _Ids(),
);

EntityPhoto _photo(String name) => EntityPhoto(
  id: name,
  owner: EntityPhotoOwner.contact,
  ownerId: 'ana',
  storageName: '$name.brpa',
  mimeType: 'image/jpeg',
  byteLength: 10,
  cipherSha256: 'b' * 64,
  widthPx: 1,
  heightPx: 1,
  createdAtUtc: DateTime.utc(2026, 10, 3),
);

final class _Repository implements EntityPhotoRepository {
  _Repository({this.failReplace = false, this.previous});

  final bool failReplace;
  final EntityPhoto? previous;
  final List<EntityPhoto> replaced = <EntityPhoto>[];
  final List<EntityPhotoReplaced> reverted = <EntityPhotoReplaced>[];
  final List<String> archivedOwners = <String>[];

  @override
  Future<Result<EntityPhotoReplaced>> replace(EntityPhoto photo) async {
    if (failReplace) {
      return const Failure<EntityPhotoReplaced>(StorageFailure('boom'));
    }
    replaced.add(photo);
    return Success<EntityPhotoReplaced>(
      EntityPhotoReplaced(current: photo, previous: previous),
    );
  }

  @override
  Future<Result<void>> revertReplacement(
    EntityPhotoReplaced replaced, {
    required DateTime atUtc,
  }) async {
    reverted.add(replaced);
    return const Success<void>(null);
  }

  @override
  Future<Result<EntityPhoto?>> archiveCurrent(
    EntityPhotoOwner owner,
    String ownerId, {
    required DateTime atUtc,
  }) async {
    archivedOwners.add(ownerId);
    return Success<EntityPhoto?>(previous);
  }

  @override
  Future<Result<EntityPhoto?>> findCurrent(
    EntityPhotoOwner owner,
    String ownerId,
  ) async => Success<EntityPhoto?>(previous);

  @override
  Stream<Result<Map<String, EntityPhoto>>> watchCurrent(
    EntityPhotoOwner owner,
    Set<String> ownerIds,
  ) => const Stream<Result<Map<String, EntityPhoto>>>.empty();

  @override
  Future<Result<Set<String>>> findActiveStorageNames() async =>
      const Success<Set<String>>(<String>{});
}

final class _Store implements EntityPhotoStore {
  _Store({this.failCommit = false});

  final bool failCommit;
  final List<String> imported = <String>[];
  final List<String> committed = <String>[];
  final List<String> deleted = <String>[];

  @override
  Future<PreparedEntityPhoto> importPhoto(String sourcePath) async {
    imported.add(sourcePath);
    return PreparedEntityPhoto(
      storageName: 'new.brpa',
      mimeType: 'image/jpeg',
      byteLength: 10,
      cipherSha256: 'c' * 64,
      widthPx: 2,
      heightPx: 2,
    );
  }

  @override
  Future<void> commitPhoto(String storageName) async {
    if (failCommit) {
      throw StateError('rename failed');
    }
    committed.add(storageName);
  }

  @override
  Future<void> deletePhoto(String storageName) async =>
      deleted.add(storageName);

  @override
  Future<Uint8List> readPhoto(EntityPhoto photo) async => Uint8List(0);

  @override
  Future<int> cleanOrphans(Set<String> activeStorageNames) async => 0;
}

final class _Picker implements JournalPhotoPicker {
  const _Picker(this.path);

  final String? path;

  @override
  Future<String?> pickPhotoPath({bool useCamera = false}) async => path;
}

final class _Clock implements JournalClock {
  const _Clock();

  @override
  DateTime nowUtc() => DateTime.utc(2026, 10, 3, 12);
}

final class _Ids implements JournalIdGenerator {
  const _Ids();

  @override
  String nextId() => 'photo-id';
}
