import 'package:bitacora_rpg_personal/core/errors/app_failure.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/contacts/application/contact_application_service.dart';
import 'package:bitacora_rpg_personal/features/contacts/data/drift_contact_repository.dart';
import 'package:bitacora_rpg_personal/features/contacts/domain/models/contact.dart';
import 'package:bitacora_rpg_personal/features/journal/application/journal_application_service.dart';
import 'package:bitacora_rpg_personal/features/journal/data/drift_journal_repository.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/journal_entry.dart';
import 'package:bitacora_rpg_personal/features/missions/application/mission_application_service.dart';
import 'package:bitacora_rpg_personal/features/missions/data/drift_mission_repository.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/models/mission.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart'
    show AppDatabase;
import 'package:bitacora_rpg_personal/infrastructure/database/daos/contact_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/journal_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/mission_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/default_seed_v1.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _nowUtc = DateTime.utc(2026, 10, 3, 12);

void main() {
  late AppDatabase database;
  late DriftContactRepository contactRepository;
  late ContactApplicationService contacts;
  late MissionApplicationService missions;
  late JournalApplicationService journal;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => _nowUtc.millisecondsSinceEpoch,
    );
    final _Ids ids = _Ids();
    contactRepository = DriftContactRepository(ContactDao(database));
    contacts = ContactApplicationService(
      repository: contactRepository,
      clock: const _Clock(),
      idGenerator: ids,
    );
    missions = MissionApplicationService(
      repository: DriftMissionRepository(MissionDao(database)),
      clock: const _Clock(),
      idGenerator: ids,
    );
    journal = JournalApplicationService(
      repository: DriftJournalRepository(JournalDao(database)),
      clock: const _Clock(),
      idGenerator: ids,
    );
  });

  tearDown(() => database.close());

  group('personajes', () {
    test('todo es opcional y los textos en blanco se guardan vacíos', () async {
      final Contact saved = _value(
        await contacts.save(
          const SaveContactRequest(
            displayName: '  Ana  ',
            role: '   ',
            description: '',
          ),
        ),
      );

      expect(saved.displayName, 'Ana');
      expect(saved.role, isNull);
      expect(saved.description, isNull);

      final Contact onlyPhoto = _value(
        await contacts.save(const SaveContactRequest()),
      );
      expect(onlyPhoto.displayName, isNull);
    });

    test('rechaza un nombre demasiado largo sin escribir', () async {
      final Result<Contact> result = await contacts.save(
        SaveContactRequest(displayName: 'x' * 81),
      );

      expect(result, isA<Failure<Contact>>());
      expect(await database.select(database.contacts).get(), isEmpty);
    });

    test('editar con una versión vieja da conflicto', () async {
      final Contact created = _value(
        await contacts.save(const SaveContactRequest(displayName: 'Ana')),
      );
      _value(
        await contacts.save(
          SaveContactRequest(existing: created, displayName: 'Ana María'),
        ),
      );

      final Result<Contact> stale = await contacts.save(
        SaveContactRequest(existing: created, displayName: 'Otra'),
      );

      expect((stale as Failure<Contact>).failure, isA<ConflictFailure>());
    });

    test('un personaje archivado no se edita hasta restaurarlo', () async {
      final Contact created = _value(
        await contacts.save(const SaveContactRequest(displayName: 'Ana')),
      );
      final Contact archived = _value(await contacts.archive(created));

      expect(
        await contacts.save(
          SaveContactRequest(existing: archived, displayName: 'Ana'),
        ),
        isA<Failure<Contact>>(),
      );

      final Contact restored = _value(await contacts.restore(archived));
      expect(restored.isArchived, isFalse);
    });
  });

  group('misión con ubicación y personajes', () {
    test('se guardan al crear y se mantienen al editar sin tocarlos', () async {
      final Contact ana = _value(
        await contacts.save(const SaveContactRequest(displayName: 'Ana')),
      );

      final Mission created = _value(
        await missions.save(
          _missionRequest(
            location: '  Taller de arte ',
            contactIds: <String>[ana.id],
          ),
        ),
      );
      expect(created.location, 'Taller de arte');
      expect(
        _value(await contactRepository.findForMission(created.id)),
        hasLength(1),
      );

      final Mission edited = _value(
        await missions.save(
          _missionRequest(existing: created, location: 'Casa'),
        ),
      );
      expect(edited.location, 'Casa');
      expect(
        _value(await contactRepository.findForMission(created.id)),
        hasLength(1),
      );

      final Mission cleared = _value(
        await missions.save(
          _missionRequest(existing: edited, contactIds: const <String>[]),
        ),
      );
      expect(cleared.location, isNull);
      expect(
        _value(await contactRepository.findForMission(created.id)),
        isEmpty,
      );
    });

    test('rechaza una ubicación de más de 120 caracteres', () async {
      final Result<Mission> result = await missions.save(
        _missionRequest(location: 'x' * 121),
      );

      expect(result, isA<Failure<Mission>>());
      expect(await database.select(database.missions).get(), isEmpty);
    });

    test('un personaje archivado no se puede elegir', () async {
      final Contact ana = _value(
        await contacts.save(const SaveContactRequest(displayName: 'Ana')),
      );
      await contacts.archive(ana);

      final Result<Mission> result = await missions.save(
        _missionRequest(contactIds: <String>[ana.id]),
      );

      expect((result as Failure<Mission>).failure, isA<ConflictFailure>());
      expect(await database.select(database.missions).get(), isEmpty);
    });
  });

  test('una entrada guarda sus personajes propios', () async {
    final Contact ana = _value(
      await contacts.save(const SaveContactRequest(displayName: 'Ana')),
    );

    final JournalEntry entry = _value(
      await journal.save(
        SaveJournalEntryRequest(
          title: 'Café con Ana',
          isPrivate: false,
          occurredAtUtc: _nowUtc,
          contactIds: <String>[ana.id],
        ),
      ),
    );

    expect(
      _value(await contactRepository.findOwnForJournalEntry(entry.id)),
      hasLength(1),
    );
  });
}

SaveMissionRequest _missionRequest({
  Mission? existing,
  String? location,
  List<String>? contactIds,
}) => SaveMissionRequest(
  existing: existing,
  areaId: DefaultSeedV1.studiesAreaId,
  title: 'Pintar el cuadro',
  type: MissionType.primary,
  importance: MissionImportance.normal,
  priority: MissionPriority.normal,
  isRequired: false,
  xpPlanned: 25,
  objectives: const <MissionObjectiveDraft>[],
  location: location,
  contactIds: contactIds,
);

T _value<T>(Result<T> result) => result.fold(
  onSuccess: (T value) => value,
  onFailure: (AppFailure failure) => throw failure,
);

final class _Clock implements JournalClock, MissionClock {
  const _Clock();

  @override
  DateTime nowUtc() => _nowUtc;
}

final class _Ids implements JournalIdGenerator, MissionIdGenerator {
  int _next = 0;

  @override
  String nextId() => 'id-${_next++}';
}
