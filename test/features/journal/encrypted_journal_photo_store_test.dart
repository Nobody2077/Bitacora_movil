import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bitacora_rpg_personal/features/journal/data/encrypted_journal_photo_store.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/journal_photo.dart';
import 'package:bitacora_rpg_personal/infrastructure/security/database_key_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;

void main() {
  late Directory temporaryDirectory;
  late _FakeKeyStore keyStore;
  late EncryptedJournalPhotoStore store;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'journal_photo_store_test_',
    );
    keyStore = _FakeKeyStore();
    store = EncryptedJournalPhotoStore(
      keyStore: keyStore,
      directoryLocator: () async => temporaryDirectory,
      random: Random(47),
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('normalizes, encrypts and authenticates a private photo', () async {
    final File source = await _writeSource(temporaryDirectory);

    final PreparedJournalPhoto prepared = await store.importPhoto(source.path);
    final File temporary = File(
      p.join(
        temporaryDirectory.path,
        'journal_attachments',
        '${prepared.storageName}.tmp',
      ),
    );
    expect(temporary.existsSync(), isTrue);
    await store.commitPhoto(prepared.storageName);
    final File encrypted = File(
      p.join(
        temporaryDirectory.path,
        'journal_attachments',
        prepared.storageName,
      ),
    );
    final Uint8List cipherBytes = await encrypted.readAsBytes();
    final Uint8List sourceBytes = await source.readAsBytes();

    expect(prepared.mimeType, 'image/jpeg');
    expect(prepared.widthPx, 3);
    expect(prepared.heightPx, 2);
    expect(prepared.byteLength, cipherBytes.length);
    expect(prepared.cipherSha256, hasLength(64));
    expect(cipherBytes.take(5), <int>[0x42, 0x52, 0x50, 0x41, 1]);
    expect(cipherBytes, isNot(equals(sourceBytes)));
    expect(keyStore.storageIds, <String>['journal_attachments']);
    expect(keyStore.existingFlags, <bool>[false]);

    final Uint8List clear = await store.readPhoto(_photo(prepared));
    final image.Image? decoded = image.decodeJpg(clear);
    expect(decoded, isNotNull);
    expect(decoded!.width, 3);
    expect(decoded.height, 2);
    expect(keyStore.existingFlags.last, isTrue);
  });

  test('fails closed when encrypted bytes are altered', () async {
    final PreparedJournalPhoto prepared = await store.importPhoto(
      (await _writeSource(temporaryDirectory)).path,
    );
    await store.commitPhoto(prepared.storageName);
    final File encrypted = File(
      p.join(
        temporaryDirectory.path,
        'journal_attachments',
        prepared.storageName,
      ),
    );
    final Uint8List bytes = await encrypted.readAsBytes();
    bytes[bytes.length - 1] ^= 0xff;
    await encrypted.writeAsBytes(bytes, flush: true);

    await expectLater(
      store.readPhoto(_photo(prepared)),
      throwsA(
        isA<JournalPhotoStoreException>().having(
          (error) => error.code,
          'code',
          'PHOTO_INTEGRITY_FAILED',
        ),
      ),
    );
  });

  test('cleans orphan and interrupted temporary files only', () async {
    final PreparedJournalPhoto active = await store.importPhoto(
      (await _writeSource(temporaryDirectory)).path,
    );
    await store.commitPhoto(active.storageName);
    final PreparedJournalPhoto orphan = await store.importPhoto(
      (await _writeSource(temporaryDirectory, name: 'other.png')).path,
    );
    await store.commitPhoto(orphan.storageName);
    final Directory directory = Directory(
      p.join(temporaryDirectory.path, 'journal_attachments'),
    );
    final File temporary = File(p.join(directory.path, 'interrupted.brpa.tmp'));
    await temporary.writeAsBytes(<int>[1, 2, 3]);

    final int removed = await store.cleanOrphans(<String>{active.storageName});

    expect(removed, 2);
    expect(
      File(p.join(directory.path, active.storageName)).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(directory.path, orphan.storageName)).existsSync(),
      isFalse,
    );
    expect(temporary.existsSync(), isFalse);
  });

  test(
    'recovers an active import left between database and file commit',
    () async {
      final PreparedJournalPhoto prepared = await store.importPhoto(
        (await _writeSource(temporaryDirectory)).path,
      );

      expect(await store.cleanOrphans(<String>{prepared.storageName}), 0);

      final File recovered = File(
        p.join(
          temporaryDirectory.path,
          'journal_attachments',
          prepared.storageName,
        ),
      );
      expect(recovered.existsSync(), isTrue);
      expect(await store.readPhoto(_photo(prepared)), isNotEmpty);
    },
  );
}

Future<File> _writeSource(
  Directory directory, {
  String name = 'source.png',
}) async {
  final image.Image source = image.Image(width: 3, height: 2);
  image.fill(source, color: image.ColorRgb8(210, 35, 55));
  final File file = File(p.join(directory.path, name));
  await file.writeAsBytes(image.encodePng(source), flush: true);
  return file;
}

JournalPhoto _photo(PreparedJournalPhoto prepared) => JournalPhoto(
  id: 'photo-id',
  journalEntryId: 'entry-id',
  storageName: prepared.storageName,
  mimeType: prepared.mimeType,
  byteLength: prepared.byteLength,
  cipherSha256: prepared.cipherSha256,
  widthPx: prepared.widthPx,
  heightPx: prepared.heightPx,
  position: 0,
  createdAtUtc: DateTime.utc(2026, 8, 27),
);

final class _FakeKeyStore implements DatabaseKeyStore {
  final List<String> storageIds = <String>[];
  final List<bool> existingFlags = <bool>[];

  @override
  Future<String> getOrCreateDatabaseKey({
    required bool databaseExists,
    required String storageId,
  }) async {
    storageIds.add(storageId);
    existingFlags.add(databaseExists);
    return List<String>.filled(32, '01').join();
  }
}
