import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/contact_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/contact_link_support.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/dao_support.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/journal_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/mission_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/default_seed_v1.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const int _now = 1790000000000;

void main() {
  late AppDatabase database;
  late ContactDao contacts;
  late MissionDao missions;
  late JournalDao journal;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => _now,
    );
    contacts = ContactDao(database);
    missions = MissionDao(database);
    journal = JournalDao(database);
  });

  tearDown(() => database.close());

  group('personajes', () {
    test('repetir la misma inserción es idempotente', () async {
      final first = await contacts.insertContact(_contact('c1', name: 'Ana'));
      final retried = await contacts.insertContact(_contact('c1', name: 'Ana'));

      expect(first.created, isTrue);
      expect(retried.created, isFalse);
      expect(retried.value.rowVersion, 1);
      expect(await database.select(database.contacts).get(), hasLength(1));
    });

    test('el mismo id con otros datos es un conflicto', () async {
      await contacts.insertContact(_contact('c1', name: 'Ana'));

      await expectLater(
        contacts.insertContact(_contact('c1', name: 'Beto')),
        throwsA(isA<IdempotencyConflictException>()),
      );
    });

    test('editar exige la versión vigente', () async {
      await contacts.insertContact(_contact('c1', name: 'Ana'));

      final updated = await contacts.updateContact(
        contactId: 'c1',
        expectedRowVersion: 1,
        changes: const ContactsCompanion(
          role: Value<String?>('Docente · Cálculo II'),
          updatedAt: Value<int>(_now + 1),
        ),
      );
      expect(updated.role, 'Docente · Cálculo II');
      expect(updated.rowVersion, 2);

      await expectLater(
        contacts.updateContact(
          contactId: 'c1',
          expectedRowVersion: 1,
          changes: const ContactsCompanion(updatedAt: Value<int>(_now + 2)),
        ),
        throwsA(isA<OptimisticLockException>()),
      );
      await expectLater(
        contacts.updateContact(
          contactId: 'missing',
          expectedRowVersion: 1,
          changes: const ContactsCompanion(updatedAt: Value<int>(_now + 2)),
        ),
        throwsA(isA<RecordNotFoundException>()),
      );
    });

    test('archivar y restaurar mueve al personaje entre listas', () async {
      await contacts.insertContact(_contact('c1', name: 'Ana'));

      final archived = await contacts.archiveContact(
        contactId: 'c1',
        expectedRowVersion: 1,
        archivedAtUtcMs: _now + 10,
      );
      expect(archived.archivedAt, _now + 10);
      expect(await contacts.watchActive().first, isEmpty);
      expect(await contacts.watchArchived().first, hasLength(1));
      await expectLater(
        contacts.archiveContact(
          contactId: 'c1',
          expectedRowVersion: 2,
          archivedAtUtcMs: _now + 11,
        ),
        throwsA(isA<DatabaseInvariantException>()),
      );

      final restored = await contacts.restoreContact(
        contactId: 'c1',
        expectedRowVersion: 2,
        updatedAtUtcMs: _now + 20,
      );
      expect(restored.archivedAt, isNull);
      expect(restored.rowVersion, 3);
      expect(await contacts.watchActive().first, hasLength(1));
    });

    test(
      'lista por nombre sin distinguir mayúsculas; sin nombre al final',
      () async {
        await contacts.insertContact(_contact('c1', createdAt: _now + 1));
        await contacts.insertContact(_contact('c2', name: 'beto'));
        await contacts.insertContact(_contact('c3', name: 'Ana'));
        await contacts.insertContact(_contact('c4', createdAt: _now - 1));

        final active = await contacts.watchActive().first;

        expect(active.map((Contact row) => row.id), <String>[
          'c3',
          'c2',
          'c4',
          'c1',
        ]);
      },
    );
  });

  group('vínculos con misiones', () {
    setUp(() async {
      await contacts.insertContact(_contact('ana', name: 'Ana'));
      await contacts.insertContact(_contact('beto', name: 'Beto'));
      await contacts.insertContact(_contact('caro', name: 'Caro'));
    });

    test(
      'crear la misión guarda sus personajes en la misma transacción',
      () async {
        await missions.insertAggregate(
          mission: _mission('m1'),
          contacts: ContactLinksWrite(
            contactIds: <String>['beto', 'ana'],
            createdAtUtcMs: _now,
          ),
        );

        final linked = await contacts.findForMission('m1');
        expect(linked.map((Contact row) => row.id).toSet(), <String>{
          'ana',
          'beto',
        });
      },
    );

    test(
      'un personaje archivado no se puede vincular y nada se guarda',
      () async {
        await contacts.archiveContact(
          contactId: 'caro',
          expectedRowVersion: 1,
          archivedAtUtcMs: _now,
        );

        await expectLater(
          missions.insertAggregate(
            mission: _mission('m1'),
            contacts: ContactLinksWrite(
              contactIds: <String>['ana', 'caro'],
              createdAtUtcMs: _now,
            ),
          ),
          throwsA(isA<InactiveContactLinkException>()),
        );
        expect(await missions.findById('m1'), isNull);
        expect(await database.select(database.missionContacts).get(), isEmpty);
      },
    );

    test(
      'editar reemplaza el conjunto y conserva la fecha de los que siguen',
      () async {
        await missions.insertAggregate(
          mission: _mission('m1'),
          contacts: ContactLinksWrite(
            contactIds: <String>['ana', 'beto'],
            createdAtUtcMs: _now,
          ),
        );

        await _updateMission(
          missions,
          'm1',
          rowVersion: 1,
          contacts: ContactLinksWrite(
            contactIds: <String>['ana', 'caro'],
            createdAtUtcMs: _now + 500,
          ),
        );

        final rows = await database.select(database.missionContacts).get();
        final Map<String, int> createdByContact = <String, int>{
          for (final MissionContact row in rows) row.contactId: row.createdAt,
        };
        expect(createdByContact, <String, int>{
          'ana': _now,
          'caro': _now + 500,
        });
      },
    );

    test('editar sin personajes (null) no toca los vínculos', () async {
      await missions.insertAggregate(
        mission: _mission('m1'),
        contacts: ContactLinksWrite(
          contactIds: <String>['ana'],
          createdAtUtcMs: _now,
        ),
      );

      await _updateMission(missions, 'm1', rowVersion: 1);

      expect(await contacts.findForMission('m1'), hasLength(1));
    });

    test('archivar un personaje no lo quita de sus misiones', () async {
      await missions.insertAggregate(
        mission: _mission('m1'),
        contacts: ContactLinksWrite(
          contactIds: <String>['ana'],
          createdAtUtcMs: _now,
        ),
      );
      await contacts.archiveContact(
        contactId: 'ana',
        expectedRowVersion: 1,
        archivedAtUtcMs: _now + 1,
      );

      final linked = await contacts.findForMission('m1');
      expect(linked.single.archivedAt, _now + 1);

      // Y se puede seguir guardando la misión con él ya vinculado.
      await _updateMission(
        missions,
        'm1',
        rowVersion: 1,
        contacts: ContactLinksWrite(
          contactIds: <String>['ana', 'beto'],
          createdAtUtcMs: _now + 2,
        ),
      );
      expect(await contacts.findForMission('m1'), hasLength(2));
    });

    test('agrupa por misión y omite las que no tienen personajes', () async {
      await missions.insertAggregate(
        mission: _mission('m1'),
        contacts: ContactLinksWrite(
          contactIds: <String>['ana'],
          createdAtUtcMs: _now,
        ),
      );
      await missions.insertAggregate(
        mission: _mission('m2'),
        contacts: ContactLinksWrite(
          contactIds: <String>['beto', 'caro'],
          createdAtUtcMs: _now,
        ),
      );
      await missions.insertAggregate(mission: _mission('m3'));

      final grouped = await contacts.watchForMissions(<String>{
        'm1',
        'm2',
        'm3',
      }).first;

      expect(grouped.keys.toSet(), <String>{'m1', 'm2'});
      expect(grouped['m2'], hasLength(2));
      expect(await contacts.watchMissionIdsForContact('beto').first, <String>[
        'm2',
      ]);
    });
  });

  group('vínculos con entradas del Diario', () {
    setUp(() async {
      await contacts.insertContact(_contact('ana', name: 'Ana'));
      await contacts.insertContact(_contact('beto', name: 'Beto'));
      await missions.insertAggregate(
        mission: _mission('m1'),
        contacts: ContactLinksWrite(
          contactIds: <String>['ana'],
          createdAtUtcMs: _now,
        ),
      );
    });

    test('la entrada suma los de su misión sin repetir', () async {
      await journal.insertAggregate(
        entry: _entry('e1', missionId: 'm1'),
        contacts: ContactLinksWrite(
          contactIds: <String>['ana', 'beto'],
          createdAtUtcMs: _now,
        ),
      );
      await journal.insertAggregate(entry: _entry('e2', missionId: 'm1'));
      await journal.insertAggregate(entry: _entry('e3'));

      final grouped = await contacts.watchForJournalEntries(<String>{
        'e1',
        'e2',
        'e3',
      }).first;

      expect(grouped['e1']!.map((Contact row) => row.id).toList(), <String>[
        'ana',
        'beto',
      ]);
      expect(grouped['e2']!.map((Contact row) => row.id), <String>['ana']);
      expect(grouped.containsKey('e3'), isFalse);

      final own = await contacts.findOwnForJournalEntry('e2');
      expect(own, isEmpty);
    });

    test('las entradas de un personaje incluyen las de sus misiones', () async {
      await journal.insertAggregate(entry: _entry('e1', missionId: 'm1'));
      await journal.insertAggregate(
        entry: _entry('e2'),
        contacts: ContactLinksWrite(
          contactIds: <String>['ana'],
          createdAtUtcMs: _now,
        ),
      );
      await journal.insertAggregate(entry: _entry('e3'));

      expect(
        (await contacts.watchJournalEntryIdsForContact('ana').first).toSet(),
        <String>{'e1', 'e2'},
      );
    });

    test('editar la entrada reemplaza sus personajes propios', () async {
      await journal.insertAggregate(
        entry: _entry('e1'),
        contacts: ContactLinksWrite(
          contactIds: <String>['ana'],
          createdAtUtcMs: _now,
        ),
      );

      await journal.updateEntry(
        entryId: 'e1',
        changes: const JournalEntriesCompanion(updatedAt: Value<int>(_now + 1)),
        contacts: ContactLinksWrite(
          contactIds: <String>['beto'],
          createdAtUtcMs: _now + 1,
        ),
      );

      expect(
        (await contacts.findOwnForJournalEntry('e1')).map((Contact c) => c.id),
        <String>['beto'],
      );
    });
  });
}

ContactsCompanion _contact(String id, {String? name, int createdAt = _now}) =>
    ContactsCompanion.insert(
      id: id,
      displayName: Value<String?>(name),
      createdAt: createdAt,
      updatedAt: createdAt,
    );

MissionsCompanion _mission(String id) => MissionsCompanion.insert(
  id: id,
  areaId: DefaultSeedV1.studiesAreaId,
  title: 'Misión $id',
  missionType: 'PRIMARY',
  isRequired: 0,
  status: 'DRAFT',
  xpPlanned: 25,
);

JournalEntriesCompanion _entry(String id, {String? missionId}) =>
    JournalEntriesCompanion.insert(
      id: id,
      originType: missionId == null ? 'MANUAL' : 'MISSION',
      missionId: Value<String?>(missionId),
      title: 'Entrada $id',
      isPrivate: 0,
      occurredAt: _now,
      createdAt: _now,
      updatedAt: _now,
    );

Future<void> _updateMission(
  MissionDao missions,
  String id, {
  required int rowVersion,
  ContactLinksWrite? contacts,
}) => missions.updateAggregate(
  missionId: id,
  expectedRowVersion: rowVersion,
  changes: MissionsCompanion(title: Value<String>('Misión $id editada')),
  objectives: const <MissionObjectivesCompanion>[],
  event: MissionEventsCompanion.insert(
    id: 'event-$id-$rowVersion',
    missionId: id,
    eventType: 'UPDATED',
    occurredAt: _now,
  ),
  notificationIntents: const <String, NotificationSchedulesCompanion?>{},
  notificationUpdatedAtUtcMs: _now,
  contacts: contacts,
);
