import 'package:bitacora_rpg_personal/app/providers/persistence_providers.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme_tokens.dart';
import 'package:bitacora_rpg_personal/core/errors/app_failure.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/contacts/application/contact_providers.dart';
import 'package:bitacora_rpg_personal/features/contacts/domain/models/contact.dart';
import 'package:bitacora_rpg_personal/features/journal/application/journal_providers.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/journal_entry.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/journal_photo.dart';
import 'package:bitacora_rpg_personal/features/journal/presentation/journal_diary_view.dart';
import 'package:bitacora_rpg_personal/features/missions/application/mission_providers.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/models/mission.dart';
import 'package:bitacora_rpg_personal/features/photos/domain/entity_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final DateTime _now = DateTime.now();
final DateTime _today = DateTime(_now.year, _now.month, _now.day, 10, 40);
final DateTime _yesterday = DateTime(_now.year, _now.month, _now.day - 1, 19);

void main() {
  group('etiquetas de día', () {
    final DateTime today = DateTime(2026, 10, 5, 12);

    test('hoy, ayer y otras fechas', () {
      expect(diaryDayLabel(DateTime(2026, 10, 5), today), 'HOY');
      expect(diaryDayLabel(DateTime(2026, 10, 4), today), 'AYER');
      expect(diaryDayLabel(DateTime(2026, 10, 3), today), '03 OCT');
      expect(diaryDayLabel(DateTime(2025, 12, 31), today), '31 DIC 2025');
    });

    test('el resumen cuenta y elige el ánimo que más se repite', () {
      expect(
        diaryDaySummary(<JournalEntry>[
          _entry('a', mood: JournalMood.motivated),
          _entry('b', mood: JournalMood.motivated),
          _entry('c', mood: JournalMood.tired),
        ]),
        '3 entradas · Motivado',
      );
      expect(diaryDaySummary(<JournalEntry>[_entry('a')]), '1 entrada');
    });
  });

  testWidgets('tablet: lista por fechas y la más reciente abierta al lado', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _sample());

    expect(find.text('HOY'), findsOneWidget);
    expect(find.text('AYER'), findsOneWidget);
    expect(find.text('2 entradas · Motivado'), findsOneWidget);
    expect(find.byKey(const Key('diary-entry-pane')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('journal-entry-title'))).data,
      'CONSULTA DEL PROYECTO FINAL',
    );
    final Color red = AppTheme.dark().extension<AppThemeTokens>()!.terminalRed;
    expect(
      tester
          .widget<Text>(find.byKey(const Key('journal-entry-title')))
          .style
          ?.color,
      red,
    );

    await tester.tap(find.byKey(const ValueKey<String>('diary-entry-free')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('journal-entry-title'))).data,
      'ALMUERZO CON MAMÁ',
    );
  });

  testWidgets('la entrada de una misión muestra sus objetivos con ◆', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _sample());

    expect(find.byKey(const Key('journal-entry-objectives')), findsOneWidget);
    expect(find.text('Llevar el diagrama corregido'), findsOneWidget);
    final Text pending = tester.widget<Text>(find.text('Acordar la API'));
    final Text done = tester.widget<Text>(
      find.text('Llevar el diagrama corregido'),
    );
    final AppThemeTokens tokens = AppTheme.dark().extension<AppThemeTokens>()!;
    expect(pending.style?.decoration, isNull);
    expect(done.style?.decoration, TextDecoration.lineThrough);
    // Todos los objetivos en cian, los cumplidos también (tachados).
    expect(pending.style?.color, tokens.infoCyan);
    expect(done.style?.color, tokens.infoCyan);
    expect(find.text('◆'), findsNWidgets(2));
    // Sin la etiqueta «Misión»: solo «Objetivos».
    expect(find.text('MISIÓN'), findsNothing);
    // La descripción de la misión, en rojo, debajo del recuadro.
    final Text description = tester.widget<Text>(
      find.byKey(const Key('journal-entry-mission-description')),
    );
    expect(description.data, 'Cálculo II · entrega el martes');
    expect(description.style?.color, tokens.terminalRed);
  });

  testWidgets('solo muestra lo que la entrada tiene', (
    WidgetTester tester,
  ) async {
    await _pump(tester, <JournalEntry>[_entry('bare', withBody: false)]);

    expect(find.byKey(const Key('journal-entry-title')), findsOneWidget);
    expect(find.byKey(const Key('journal-entry-body')), findsNothing);
    expect(find.byKey(const Key('journal-entry-mood')), findsNothing);
    expect(find.byKey(const Key('journal-entry-photos')), findsNothing);
    expect(find.byKey(const Key('journal-entry-contacts')), findsNothing);
    expect(find.byKey(const Key('journal-entry-objectives')), findsNothing);
    expect(find.textContaining('Sin '), findsNothing);

    // Editar, agregar foto y archivar, en rojo.
    final Color red = AppTheme.dark().extension<AppThemeTokens>()!.terminalRed;
    for (final String key in <String>[
      'journal-entry-edit',
      'journal-entry-add-photo',
      'journal-entry-archive',
    ]) {
      final IconButton button = tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.color, red, reason: key);
    }
  });

  testWidgets('los nombres de los personajes van en rojo', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      _sample(),
      contacts: <String, List<Contact>>{
        'mission': <Contact>[
          Contact(
            id: 'carlos',
            displayName: 'Carlos',
            createdAtUtc: _today.toUtc(),
            updatedAtUtc: _today.toUtc(),
            rowVersion: 1,
          ),
        ],
      },
    );

    expect(find.byKey(const Key('journal-entry-contacts')), findsOneWidget);
    final Text name = tester.widget<Text>(find.text('Carlos'));
    expect(
      name.style?.color,
      AppTheme.dark().extension<AppThemeTokens>()!.terminalRed,
    );
  });

  testWidgets('los filtros separan misiones, libres y movimientos', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _sample());

    await tester.tap(
      find.byKey(const ValueKey<String>('diary-filter-movements')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('diary-entry-money')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('diary-entry-mission')),
      findsNothing,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('journal-entry-title'))).data,
      'COMPRA: MONITOR',
    );

    await tester.tap(find.byKey(const ValueKey<String>('diary-filter-free')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('diary-entry-free')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('diary-entry-close')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('diary-entry-money')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('diary-filter-missions')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('diary-entry-mission')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('diary-entry-free')),
      findsNothing,
    );
  });

  testWidgets('«Cargar más» pide la siguiente tanda', (
    WidgetTester tester,
  ) async {
    final List<int> limits = <int>[];
    await _pump(
      tester,
      const <JournalEntry>[],
      timeline: (int limit) {
        limits.add(limit);
        return List<JournalEntry>.generate(
          limit == 100 ? 100 : 130,
          (int i) => _entry('e$i', at: _today.subtract(Duration(minutes: i))),
        );
      },
    );

    expect(find.text('ENTRADAS · 100+'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('diary-load-more')),
      400,
      scrollable: find.descendant(
        of: find.byKey(const Key('diary-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('diary-load-more')));
    await tester.pumpAndSettle();

    expect(limits, containsAllInOrder(<int>[100, 200]));
    expect(find.text('ENTRADAS · 130'), findsOneWidget);
    expect(find.byKey(const Key('diary-load-more')), findsNothing);
  });

  testWidgets('teléfono: la entrada se abre a pantalla completa', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _sample(), size: const Size(412, 900));

    expect(find.byKey(const Key('diary-entry-pane')), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('diary-entry-free')));
    await tester.pumpAndSettle();

    expect(find.text('detalle free'), findsOneWidget);
  });

  testWidgets('Diario vacío invita a escribir', (WidgetTester tester) async {
    await _pump(tester, const <JournalEntry>[]);

    expect(find.text('Tu Diario está en blanco'), findsOneWidget);
  });
}

List<JournalEntry> _sample() => <JournalEntry>[
  _entry(
    'mission',
    title: 'Consulta del proyecto final',
    origin: JournalOrigin.mission,
    missionId: 'm1',
    mood: JournalMood.motivated,
    at: _today,
  ),
  _entry(
    'money',
    title: 'Compra: monitor',
    origin: JournalOrigin.transaction,
    mood: JournalMood.motivated,
    at: _today.subtract(const Duration(hours: 1)),
  ),
  _entry(
    'free',
    title: 'Almuerzo con mamá',
    mood: JournalMood.calm,
    at: _yesterday,
  ),
  _entry(
    'close',
    title: 'Cierre del día',
    origin: JournalOrigin.system,
    at: _yesterday.subtract(const Duration(hours: 2)),
  ),
];

JournalEntry _entry(
  String id, {
  String? title,
  JournalOrigin origin = JournalOrigin.manual,
  String? missionId,
  JournalMood? mood,
  DateTime? at,
  bool withBody = true,
}) {
  final DateTime when = (at ?? _today).toUtc();
  return JournalEntry(
    id: id,
    origin: origin,
    missionId: missionId,
    transactionId: origin == JournalOrigin.transaction ? 'tx-$id' : null,
    title: title ?? 'Entrada $id',
    body: withBody ? 'Texto de $id' : null,
    mood: mood,
    isPrivate: true,
    occurredAtUtc: when,
    createdAtUtc: when,
    updatedAtUtc: when,
    attachmentCount: 0,
  );
}

Future<void> _pump(
  WidgetTester tester,
  List<JournalEntry> entries, {
  List<JournalEntry> Function(int limit)? timeline,
  Size size = const Size(1280, 900),
  Map<String, List<Contact>> contacts = const <String, List<Contact>>{},
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final GoRouter router = GoRouter(
    initialLocation: '/diary',
    routes: <RouteBase>[
      GoRoute(
        path: '/diary',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: JournalDiaryView()),
      ),
      GoRoute(
        path: '/entries/:entryId',
        name: 'journalDetail',
        builder: (BuildContext context, GoRouterState state) =>
            Scaffold(body: Text('detalle ${state.pathParameters['entryId']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        journalTimelineProvider.overrideWith(
          (Ref ref, int limit) => Stream<List<JournalEntry>>.value(
            timeline?.call(limit) ?? entries,
          ),
        ),
        journalPhotoCleanupProvider.overrideWith((Ref ref) async => 0),
        journalPhotosProvider.overrideWith(
          (Ref ref, String id) async => const <JournalPhoto>[],
        ),
        journalEntriesContactsProvider.overrideWith(
          (Ref ref, IdSet ids) =>
              Stream<Map<String, List<Contact>>>.value(contacts),
        ),
        entityPhotoRepositoryProvider.overrideWithValue(
          const _PhotoRepository(),
        ),
        activeContactsProvider.overrideWith(
          (Ref ref) => Stream<List<Contact>>.value(const <Contact>[]),
        ),
        missionDetailProvider.overrideWith(
          (Ref ref, String id) async => Mission(
            id: id,
            areaId: 'studies',
            title: 'Proyecto final',
            type: MissionType.primary,
            importance: MissionImportance.important,
            priority: MissionPriority.high,
            isRequired: true,
            status: MissionStatus.completed,
            xpPlanned: 80,
            description: 'Cálculo II · entrega el martes',
            rowVersion: 1,
            objectives: <MissionObjective>[
              MissionObjective(
                id: 'o2',
                description: 'Acordar la API',
                position: 1,
                createdAtUtc: _today.toUtc(),
              ),
              MissionObjective(
                id: 'o1',
                description: 'Llevar el diagrama corregido',
                position: 0,
                createdAtUtc: _today.toUtc(),
                completedAtUtc: _today.toUtc(),
              ),
            ],
          ),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
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
