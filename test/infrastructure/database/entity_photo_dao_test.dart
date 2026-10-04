import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/dao_support.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/entity_photo_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/default_seed_v1.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const int _now = 1790000000000;

void main() {
  late AppDatabase database;
  late EntityPhotoDao photos;

  setUp(() async {
    database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => _now,
    );
    photos = EntityPhotoDao(database);
    await database
        .into(database.contacts)
        .insert(
          ContactsCompanion.insert(
            id: 'ana',
            displayName: const Value<String?>('Ana'),
            createdAt: _now,
            updatedAt: _now,
          ),
        );
    await database
        .into(database.missions)
        .insert(
          MissionsCompanion.insert(
            id: 'm1',
            areaId: DefaultSeedV1.studiesAreaId,
            title: 'Pintar el cuadro',
            missionType: 'PRIMARY',
            isRequired: 0,
            status: 'DRAFT',
            xpPlanned: 25,
          ),
        );
  });

  tearDown(() => database.close());

  test('cambiar la foto archiva la anterior y deja una sola vigente', () async {
    final first = await photos.replaceCurrent(
      PhotoOwnerKind.contact,
      _photo('p1', 'ana'),
    );
    expect(first.previous, isNull);

    final second = await photos.replaceCurrent(
      PhotoOwnerKind.contact,
      _photo('p2', 'ana', createdAt: _now + 10),
    );

    expect(second.current.id, 'p2');
    expect(second.previous?.id, 'p1');
    expect(second.previous?.archivedAt, _now + 10);
    expect((await photos.findCurrent(PhotoOwnerKind.contact, 'ana'))?.id, 'p2');
    expect(await database.select(database.contactPhotos).get(), hasLength(2));
  });

  test('deshacer el cambio vuelve a dejar vigente la anterior', () async {
    await photos.replaceCurrent(PhotoOwnerKind.mission, _photo('p1', 'm1'));
    final replaced = await photos.replaceCurrent(
      PhotoOwnerKind.mission,
      _photo('p2', 'm1', createdAt: _now + 10),
    );

    await photos.revertReplacement(
      PhotoOwnerKind.mission,
      newPhotoId: replaced.current.id,
      previousPhotoId: replaced.previous?.id,
      archivedAtUtcMs: _now + 20,
    );

    expect((await photos.findCurrent(PhotoOwnerKind.mission, 'm1'))?.id, 'p1');
    expect(await photos.findActiveStorageNames(), <String>{_storage('p1')});
  });

  test('no pone foto a un dueño archivado o inexistente', () async {
    await (database.update(database.contacts)
          ..where((table) => table.id.equals('ana')))
        .write(const ContactsCompanion(archivedAt: Value<int?>(_now)));

    await expectLater(
      photos.replaceCurrent(PhotoOwnerKind.contact, _photo('p1', 'ana')),
      throwsA(isA<DatabaseInvariantException>()),
    );
    await expectLater(
      photos.replaceCurrent(PhotoOwnerKind.mission, _photo('p2', 'nadie')),
      throwsA(isA<RecordNotFoundException>()),
    );
    expect(await database.select(database.contactPhotos).get(), isEmpty);
    expect(await database.select(database.missionPhotos).get(), isEmpty);
  });

  test(
    'quitar la foto la archiva y la saca de los ficheros vigentes',
    () async {
      await photos.replaceCurrent(PhotoOwnerKind.contact, _photo('p1', 'ana'));
      await photos.replaceCurrent(PhotoOwnerKind.mission, _photo('p2', 'm1'));
      expect(await photos.findActiveStorageNames(), <String>{
        _storage('p1'),
        _storage('p2'),
      });

      final removed = await photos.archiveCurrent(
        PhotoOwnerKind.contact,
        'ana',
        archivedAtUtcMs: _now + 5,
      );

      expect(removed?.archivedAt, _now + 5);
      expect(await photos.findCurrent(PhotoOwnerKind.contact, 'ana'), isNull);
      expect(
        await photos.archiveCurrent(
          PhotoOwnerKind.contact,
          'ana',
          archivedAtUtcMs: _now + 6,
        ),
        isNull,
      );
      expect(await photos.findActiveStorageNames(), <String>{_storage('p2')});
    },
  );

  test('vigila las fotos de varios dueños a la vez', () async {
    await photos.replaceCurrent(PhotoOwnerKind.mission, _photo('p1', 'm1'));

    final current = await photos.watchCurrent(PhotoOwnerKind.mission, <String>{
      'm1',
      'm2',
    }).first;

    expect(current.keys, <String>['m1']);
    expect(current['m1']?.widthPx, 640);
  });
}

String _storage(String id) =>
    '00000000-0000-4000-8000-${id.padLeft(12, '0')}.brpa';

EntityPhotoRow _photo(String id, String ownerId, {int createdAt = _now}) =>
    EntityPhotoRow(
      id: id,
      ownerId: ownerId,
      storageName: _storage(id),
      mimeType: 'image/jpeg',
      byteLength: 1024,
      cipherSha256: 'a' * 64,
      widthPx: 640,
      heightPx: 480,
      createdAt: createdAt,
    );
