import 'dart:typed_data';

import 'package:bitacora_rpg_personal/core/errors/app_failure.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/journal/application/journal_application_service.dart';
import 'package:bitacora_rpg_personal/features/journal/application/journal_photo_application_service.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/journal_entry.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/journal_photo.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/repositories/journal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removes encrypted file if database insert fails', () async {
    final _PhotoRepository repository = _PhotoRepository(failInsert: true);
    final _PhotoStore store = _PhotoStore();
    final JournalPhotoApplicationService service = _service(repository, store);

    final Result<JournalPhoto?> result = await service.pickAndAdd('entry-1');

    expect(result, isA<Failure<JournalPhoto?>>());
    expect(store.deleted, <String>['prepared.brpa']);
  });

  test('archives metadata before deleting encrypted file', () async {
    final _PhotoRepository repository = _PhotoRepository();
    final _PhotoStore store = _PhotoStore();
    final JournalPhoto photo = _photo();
    repository.photos.add(photo);
    final JournalPhotoApplicationService service = _service(repository, store);

    final Result<void> result = await service.remove(photo);

    expect(result, isA<Success<void>>());
    expect(repository.archived, <String>['photo-1']);
    expect(store.deleted, <String>['prepared.brpa']);
  });

  test('archives metadata if final atomic rename fails', () async {
    final _PhotoRepository repository = _PhotoRepository();
    final _PhotoStore store = _PhotoStore(failCommit: true);
    final JournalPhotoApplicationService service = _service(repository, store);

    final Result<JournalPhoto?> result = await service.pickAndAdd('entry-1');

    expect(result, isA<Failure<JournalPhoto?>>());
    expect(repository.archived, <String>['photo-1']);
    expect(store.deleted, <String>['prepared.brpa']);
  });

  test('forwards the enabled camera source to the picker', () async {
    final _PhotoRepository repository = _PhotoRepository();
    final _PhotoStore store = _PhotoStore();
    final _TrackingPicker picker = _TrackingPicker();
    final JournalPhotoApplicationService service = _service(
      repository,
      store,
      picker: picker,
    );

    final Result<JournalPhoto?> result = await service.pickAndAdd(
      'entry-1',
      useCamera: true,
    );

    expect(result, isA<Success<JournalPhoto?>>());
    expect(picker.usedCamera, isTrue);
  });
}

JournalPhotoApplicationService _service(
  _PhotoRepository repository,
  _PhotoStore store, {
  JournalPhotoPicker picker = const _Picker(),
}) => JournalPhotoApplicationService(
  repository: repository,
  photoStore: store,
  picker: picker,
  clock: const _Clock(),
  idGenerator: const _Ids(),
);

JournalPhoto _photo() => JournalPhoto(
  id: 'photo-1',
  journalEntryId: 'entry-1',
  storageName: 'prepared.brpa',
  mimeType: 'image/jpeg',
  byteLength: 100,
  cipherSha256: List<String>.filled(64, 'a').join(),
  widthPx: 20,
  heightPx: 10,
  position: 0,
  createdAtUtc: DateTime.utc(2026, 8, 27),
);

final class _Picker implements JournalPhotoPicker {
  const _Picker();

  @override
  Future<String?> pickPhotoPath({bool useCamera = false}) async => 'source.png';
}

final class _TrackingPicker implements JournalPhotoPicker {
  bool? usedCamera;

  @override
  Future<String?> pickPhotoPath({bool useCamera = false}) async {
    usedCamera = useCamera;
    return 'source.png';
  }
}

final class _Clock implements JournalClock {
  const _Clock();

  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 27, 12);
}

final class _Ids implements JournalIdGenerator {
  const _Ids();

  @override
  String nextId() => 'photo-1';
}

final class _PhotoStore implements JournalPhotoStore {
  _PhotoStore({this.failCommit = false});

  final bool failCommit;
  final List<String> deleted = <String>[];

  @override
  Future<int> cleanOrphans(Set<String> activeStorageNames) async => 0;

  @override
  Future<void> commitPhoto(String storageName) async {
    if (failCommit) {
      throw StateError('rename failed');
    }
  }

  @override
  Future<void> deletePhoto(String storageName) async =>
      deleted.add(storageName);

  @override
  Future<PreparedJournalPhoto> importPhoto(String sourcePath) async =>
      PreparedJournalPhoto(
        storageName: 'prepared.brpa',
        mimeType: 'image/jpeg',
        byteLength: 100,
        cipherSha256: List<String>.filled(64, 'a').join(),
        widthPx: 20,
        heightPx: 10,
      );

  @override
  Future<Uint8List> readPhoto(JournalPhoto photo) async => Uint8List(0);
}

final class _PhotoRepository implements JournalRepository {
  _PhotoRepository({this.failInsert = false});

  final bool failInsert;
  final List<JournalPhoto> photos = <JournalPhoto>[];
  final List<String> archived = <String>[];

  @override
  Future<Result<JournalPhoto>> addPhoto(JournalPhoto photo) async {
    if (failInsert) {
      return const Failure<JournalPhoto>(StorageFailure('insert failed'));
    }
    photos.add(photo);
    return Success<JournalPhoto>(photo);
  }

  @override
  Future<Result<JournalPhoto?>> archivePhoto({
    required String attachmentId,
    required DateTime archivedAtUtc,
  }) async {
    archived.add(attachmentId);
    return Success<JournalPhoto?>(
      photos.where((photo) => photo.id == attachmentId).firstOrNull,
    );
  }

  @override
  Future<Result<Set<String>>> findActivePhotoStorageNames() async =>
      Success<Set<String>>(photos.map((photo) => photo.storageName).toSet());

  @override
  Future<Result<List<JournalPhoto>>> findPhotos(String entryId) async =>
      Success<List<JournalPhoto>>(List<JournalPhoto>.from(photos));

  @override
  Future<Result<JournalEntry>> create(
    JournalEntry entry, {
    Iterable<String> contactIds = const <String>[],
  }) => throw UnimplementedError();

  @override
  Future<Result<JournalEntry?>> findById(String id) =>
      throw UnimplementedError();

  @override
  Future<Result<List<JournalEntry>>> findRecent({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 100,
  }) => throw UnimplementedError();

  @override
  Future<Result<JournalEntry>> update(
    JournalEntry entry, {
    Iterable<String>? contactIds,
  }) => throw UnimplementedError();

  @override
  Stream<Result<List<JournalEntry>>> watchRecent({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 100,
  }) => throw UnimplementedError();

  @override
  Future<Result<JournalEntry>> archiveEntry({
    required String entryId,
    required DateTime archivedAtUtc,
    required DateTime updatedAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<JournalEntry>> restoreEntry({
    required String entryId,
    required DateTime updatedAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<List<JournalEntry>>> search(JournalSearchCriteria criteria) =>
      throw UnimplementedError();

  @override
  Stream<Result<List<JournalEntry>>> watchArchived({int limit = 200}) =>
      throw UnimplementedError();
}
