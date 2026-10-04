import 'dart:async';

import 'package:bitacora_rpg_personal/app/providers/persistence_providers.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/core/errors/app_failure.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/character/presentation/character_menu_page.dart';
import 'package:bitacora_rpg_personal/features/contacts/domain/models/contact.dart';
import 'package:bitacora_rpg_personal/features/contacts/domain/repositories/contact_repository.dart';
import 'package:bitacora_rpg_personal/features/contacts/presentation/contact_pages.dart';
import 'package:bitacora_rpg_personal/features/economy/application/economy_providers.dart';
import 'package:bitacora_rpg_personal/features/economy/domain/models/economy_snapshot.dart';
import 'package:bitacora_rpg_personal/features/missions/application/mission_providers.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/models/mission.dart';
import 'package:bitacora_rpg_personal/features/photos/domain/entity_photo.dart';
import 'package:bitacora_rpg_personal/features/progress/application/progress_providers.dart';
import 'package:bitacora_rpg_personal/features/progress/domain/models/progress_models.dart';
import 'package:bitacora_rpg_personal/features/progress/domain/models/rpg_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final DateTime _now = DateTime.utc(2026, 10, 3, 12);

void main() {
  setUp(() {});

  testWidgets('abre en PERSONAJE con nivel, hexágono y panel lateral', (
    WidgetTester tester,
  ) async {
    _tabletView(tester);
    await tester.pumpWidget(_app(_ContactRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('character-hexagon')), findsOneWidget);
    expect(find.text('NIVEL 3 → 4'), findsOneWidget);
    expect(find.text('5 días'), findsOneWidget);
    expect(find.text('Constante'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('character-level')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(find.text('Bs 1240,50'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Estudios, nivel 2.*Salud, nivel 1')),
      findsOneWidget,
    );
  });

  testWidgets('MAPA avisa que está aplazado y las fases 2 lo dicen', (
    WidgetTester tester,
  ) async {
    _tabletView(tester);
    await tester.pumpWidget(_app(_ContactRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('character-tab-mapa')));
    await tester.pumpAndSettle();
    expect(find.text('MAPA · APLAZADO'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('character-tab-ciberware')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('fase 2'), findsWidgets);
  });

  testWidgets('DIARIO muestra los personajes y su contador', (
    WidgetTester tester,
  ) async {
    _tabletView(tester);
    final _ContactRepository repository = _ContactRepository(
      active: <Contact>[
        _contact('ana', name: 'Ana', role: 'Docente · Cálculo II'),
        _contact('sin'),
      ],
    );
    await tester.pumpWidget(_app(repository, initialTab: CharacterTab.diario));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('diary-mode-contacts')));
    await tester.pumpAndSettle();

    expect(find.text('PERSONAJES · 2'), findsOneWidget);
    expect(find.text('ANA'), findsOneWidget);
    expect(find.text('Docente · Cálculo II'), findsOneWidget);
    expect(find.text('PERSONAJE SIN NOMBRE'), findsOneWidget);
    expect(find.byKey(const Key('contact-create')), findsOneWidget);
  });

  testWidgets('crear un personaje lleva a su ficha', (
    WidgetTester tester,
  ) async {
    _tabletView(tester);
    final _ContactRepository repository = _ContactRepository();
    final GoRouter router = GoRouter(
      initialLocation: '/new',
      routes: <RouteBase>[
        GoRoute(
          path: '/new',
          name: 'contactNew',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: ContactFormPage()),
        ),
        GoRoute(
          path: '/contacts/:contactId',
          name: 'contactDetail',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: ContactDetailPage(
              contactId: state.pathParameters['contactId']!,
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(repository),
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('contact-name')), '  Diego ');
    await tester.enterText(find.byKey(const Key('contact-role')), 'Amigo');
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();

    expect(repository.created.single.displayName, 'Diego');
    expect(find.text('DIEGO'), findsOneWidget);
    expect(find.text('AMIGO'), findsOneWidget);
    expect(find.text('AÑADIR FOTO'), findsOneWidget);
    expect(find.text('Todavía no aparece en ninguna misión.'), findsOneWidget);
  });
}

void _tabletView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1400, 1600);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _app(
  _ContactRepository repository, {
  CharacterTab initialTab = CharacterTab.personaje,
}) => ProviderScope(
  overrides: _overrides(repository),
  child: MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: CharacterMenuPage(initialTab: initialTab)),
  ),
);

List<Override> _overrides(_ContactRepository repository) => <Override>[
  contactRepositoryProvider.overrideWithValue(repository),
  entityPhotoRepositoryProvider.overrideWithValue(const _PhotoRepository()),
  overallProgressProvider.overrideWith(
    (Ref ref) async => OverallProgressViewData(
      rpgLevel: RpgLevel.fromTotalXp(450),
      totalXp: 450,
      todayXp: 20,
      weekXp: 90,
      areaBreakdown: <AreaProgressItem>[
        AreaProgressItem(
          areaId: 'studies',
          areaName: 'Estudios',
          colorHex: '#55E6E6',
          iconKey: 'school',
          amount: 150,
          percentage: 33,
          rpgLevel: RpgLevel.fromTotalXp(150),
        ),
      ],
      activeTitles: <TitleProgressItem>[
        TitleProgressItem(
          id: 't1',
          name: 'Constante',
          description: null,
          kind: ProgressTitleKind.dynamic,
          status: ProgressTitleStatus.active,
          activatedAtUtc: _now,
          bestStreak: 7,
        ),
      ],
      currentStreak: 5,
      bestStreak: 9,
    ),
  ),
  missionAreasProvider.overrideWith(
    (Ref ref) async => const <MissionArea>[
      MissionArea(
        id: 'studies',
        name: 'Estudios',
        iconKey: 'school',
        colorHex: '#55E6E6',
        isDefault: true,
      ),
      MissionArea(
        id: 'health',
        name: 'Salud',
        iconKey: 'favorite',
        colorHex: '#45D483',
        isDefault: true,
      ),
      MissionArea(
        id: 'projects',
        name: 'Proyectos',
        iconKey: 'build',
        colorHex: '#F5D547',
        isDefault: true,
      ),
    ],
  ),
  economySnapshotProvider.overrideWith(
    (Ref ref) => Stream<EconomySnapshot>.value(
      const EconomySnapshot(
        totalMinor: 150050,
        reservedMinor: 26000,
        monthIncomeMinor: 0,
        monthExpenseMinor: 0,
        dayIncomeMinor: 0,
        dayExpenseMinor: 0,
      ),
    ),
  ),
];

Contact _contact(String id, {String? name, String? role}) => Contact(
  id: id,
  displayName: name,
  role: role,
  createdAtUtc: _now,
  updatedAtUtc: _now,
  rowVersion: 1,
);

final class _ContactRepository implements ContactRepository {
  _ContactRepository({List<Contact> active = const <Contact>[]})
    : _active = <Contact>[...active];

  final List<Contact> _active;
  final List<Contact> created = <Contact>[];
  final StreamController<List<Contact>> _changes =
      StreamController<List<Contact>>.broadcast();

  @override
  Stream<Result<List<Contact>>> watchActive() async* {
    yield Success<List<Contact>>(List<Contact>.of(_active));
    yield* _changes.stream.map(Success<List<Contact>>.new);
  }

  @override
  Stream<Result<List<Contact>>> watchArchived() =>
      Stream<Result<List<Contact>>>.value(
        const Success<List<Contact>>(<Contact>[]),
      );

  @override
  Future<Result<Contact>> create(Contact contact) async {
    created.add(contact);
    _active.add(contact);
    _changes.add(List<Contact>.of(_active));
    return Success<Contact>(contact);
  }

  @override
  Future<Result<Contact?>> findById(String id) async => Success<Contact?>(
    _active.where((Contact contact) => contact.id == id).firstOrNull,
  );

  @override
  Stream<Result<Contact?>> watchById(String id) =>
      Stream<Result<Contact?>>.fromFuture(findById(id));

  @override
  Future<Result<Contact>> update(Contact contact) async =>
      Success<Contact>(contact);

  @override
  Future<Result<Contact>> archive(
    Contact contact, {
    required DateTime atUtc,
  }) async => Success<Contact>(contact);

  @override
  Future<Result<Contact>> restore(
    Contact contact, {
    required DateTime atUtc,
  }) async => Success<Contact>(contact);

  @override
  Future<Result<List<Contact>>> findForMission(String missionId) async =>
      const Success<List<Contact>>(<Contact>[]);

  @override
  Future<Result<List<Contact>>> findOwnForJournalEntry(String entryId) async =>
      const Success<List<Contact>>(<Contact>[]);

  @override
  Stream<Result<Map<String, List<Contact>>>> watchForMissions(
    Set<String> missionIds,
  ) => Stream<Result<Map<String, List<Contact>>>>.value(
    const Success<Map<String, List<Contact>>>(<String, List<Contact>>{}),
  );

  @override
  Stream<Result<Map<String, List<Contact>>>> watchForJournalEntries(
    Set<String> entryIds,
  ) => Stream<Result<Map<String, List<Contact>>>>.value(
    const Success<Map<String, List<Contact>>>(<String, List<Contact>>{}),
  );

  @override
  Stream<Result<List<String>>> watchMissionIdsForContact(String contactId) =>
      Stream<Result<List<String>>>.value(
        const Success<List<String>>(<String>[]),
      );

  @override
  Stream<Result<List<String>>> watchJournalEntryIdsForContact(
    String contactId,
  ) => Stream<Result<List<String>>>.value(
    const Success<List<String>>(<String>[]),
  );
}

final class _PhotoRepository implements EntityPhotoRepository {
  const _PhotoRepository();

  @override
  Stream<Result<Map<String, EntityPhoto>>> watchCurrent(
    EntityPhotoOwner owner,
    Set<String> ownerIds,
  ) => Stream<Result<Map<String, EntityPhoto>>>.value(
    const Success<Map<String, EntityPhoto>>(<String, EntityPhoto>{}),
  );

  @override
  Future<Result<Set<String>>> findActiveStorageNames() async =>
      const Success<Set<String>>(<String>{});

  @override
  Future<Result<EntityPhoto?>> findCurrent(
    EntityPhotoOwner owner,
    String ownerId,
  ) async => const Success<EntityPhoto?>(null);

  @override
  Future<Result<EntityPhotoReplaced>> replace(EntityPhoto photo) async =>
      const Failure<EntityPhotoReplaced>(StorageFailure('no'));

  @override
  Future<Result<void>> revertReplacement(
    EntityPhotoReplaced replaced, {
    required DateTime atUtc,
  }) async => const Success<void>(null);

  @override
  Future<Result<EntityPhoto?>> archiveCurrent(
    EntityPhotoOwner owner,
    String ownerId, {
    required DateTime atUtc,
  }) async => const Success<EntityPhoto?>(null);
}
