import 'dart:io';
import 'dart:math';

import 'package:bitacora_rpg_personal/features/journal/data/encrypted_journal_photo_store.dart';
import 'package:bitacora_rpg_personal/features/photos/data/encrypted_entity_photo_store.dart';
import 'package:bitacora_rpg_personal/features/photos/domain/entity_photo.dart';
import 'package:bitacora_rpg_personal/infrastructure/security/database_key_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;

void main() {
  late Directory support;
  late _FakeKeyStore keyStore;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('entity_photo_store_');
    keyStore = _FakeKeyStore();
  });

  tearDown(() async {
    if (await support.exists()) {
      await support.delete(recursive: true);
    }
  });

  test('usa su propia carpeta y su propia clave, no las de Bitácora', () async {
    final EncryptedEntityPhotoStore store = EncryptedEntityPhotoStore(
      keyStore: keyStore,
      directoryLocator: () async => support,
      random: Random(7),
    );

    final PreparedEntityPhoto prepared = await store.importPhoto(
      (await _source(support)).path,
    );
    await store.commitPhoto(prepared.storageName);
    final EntityPhoto photo = EntityPhoto(
      id: 'photo',
      owner: EntityPhotoOwner.contact,
      ownerId: 'ana',
      storageName: prepared.storageName,
      mimeType: prepared.mimeType,
      byteLength: prepared.byteLength,
      cipherSha256: prepared.cipherSha256,
      widthPx: prepared.widthPx,
      heightPx: prepared.heightPx,
      createdAtUtc: DateTime.utc(2026, 10, 3),
    );

    expect(
      File(
        p.join(support.path, 'entity_photos', prepared.storageName),
      ).existsSync(),
      isTrue,
    );
    expect(keyStore.storageIds.toSet(), <String>{'entity_photos'});
    expect(await store.readPhoto(photo), isNotEmpty);
  });

  test('la limpieza de Bitácora no borra fotos de personajes', () async {
    final EncryptedEntityPhotoStore entityStore = EncryptedEntityPhotoStore(
      keyStore: keyStore,
      directoryLocator: () async => support,
    );
    final EncryptedJournalPhotoStore journalStore = EncryptedJournalPhotoStore(
      keyStore: keyStore,
      directoryLocator: () async => support,
    );
    final PreparedEntityPhoto prepared = await entityStore.importPhoto(
      (await _source(support)).path,
    );
    await entityStore.commitPhoto(prepared.storageName);

    expect(await journalStore.cleanOrphans(<String>{}), 0);
    expect(
      File(
        p.join(support.path, 'entity_photos', prepared.storageName),
      ).existsSync(),
      isTrue,
    );
  });
}

Future<File> _source(Directory directory) async {
  final image.Image source = image.Image(width: 4, height: 3);
  image.fill(source, color: image.ColorRgb8(20, 200, 220));
  final File file = File(p.join(directory.path, 'source.png'));
  await file.writeAsBytes(image.encodePng(source), flush: true);
  return file;
}

final class _FakeKeyStore implements DatabaseKeyStore {
  final List<String> storageIds = <String>[];

  @override
  Future<String> getOrCreateDatabaseKey({
    required bool databaseExists,
    required String storageId,
  }) async {
    storageIds.add(storageId);
    return List<String>.filled(32, '02').join();
  }
}
