import 'package:bitacora_rpg_personal/app/providers/persistence_providers.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme_tokens.dart';
import 'package:bitacora_rpg_personal/core/errors/app_failure.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/contacts/application/contact_application_service.dart';
import 'package:bitacora_rpg_personal/features/contacts/application/contact_providers.dart';
import 'package:bitacora_rpg_personal/features/contacts/domain/models/contact.dart';
import 'package:bitacora_rpg_personal/features/contacts/domain/repositories/contact_repository.dart';
import 'package:bitacora_rpg_personal/features/contacts/presentation/contact_pages.dart';
import 'package:bitacora_rpg_personal/features/journal/application/journal_application_service.dart';
import 'package:bitacora_rpg_personal/features/photos/domain/entity_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final DateTime _now = DateTime.utc(2026, 10, 5, 12);
final AppThemeTokens _tokens = AppTheme.dark().extension<AppThemeTokens>()!;

void main() {
  test('el código decorativo sale del identificador', () {
    expect(
      contactDossierCode('4f2a91c7-0000-4000-8000-000000000000'),
      'PJ_4F2A91',
    );
    expect(contactDossierCode('ab'), 'PJ_AB');
  });

  testWidgets(
    'tablet: foto al lado y panel con nombre cian y descripción roja',
    (WidgetTester tester) async {
      await _pump(tester, _rocio());

      final Text name = tester.widget<Text>(
        find.byKey(const Key('contact-dossier-name')),
      );
      expect(name.data, 'LIC. ROCÍO MAMANI');
      expect(name.style?.color, _tokens.infoCyan);
      final Text role = tester.widget<Text>(
        find.byKey(const Key('contact-dossier-role')),
      );
      expect(role.data, 'DOCENTE · CÁLCULO II');
      expect(role.style?.color, _tokens.valueYellow);
      final SelectableText description = tester.widget<SelectableText>(
        find.byKey(const Key('contact-dossier-description')),
      );
      expect(description.style?.color, _tokens.terminalRed);
      expect(
        tester.widget<Text>(find.byKey(const Key('contact-dossier-code'))).data,
        'TRN_PJ_4F2A91',
      );
      expect(find.text('IMAGEN: SIN FOTO'), findsOneWidget);
      expect(find.textContaining('Aparece'), findsNothing);

      // Foto a la izquierda del panel.
      final Offset photo = tester.getTopLeft(
        find.byKey(const Key('contact-dossier-photo')),
      );
      final Offset panel = tester.getTopLeft(
        find.byKey(const Key('contact-dossier-panel')),
      );
      expect(photo.dx, lessThan(panel.dx));

      for (final String key in <String>[
        'contact-edit',
        'contact-photo',
        'contact-archive',
      ]) {
        final IconButton button = tester.widget<IconButton>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(IconButton),
          ),
        );
        expect(button.color, _tokens.terminalRed, reason: key);
      }
    },
  );

  testWidgets('sin rol ni descripción, esas partes no aparecen', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _contact('a1b2c3d4', name: 'Diego'));

    expect(find.text('DIEGO'), findsOneWidget);
    expect(find.byKey(const Key('contact-dossier-role')), findsNothing);
    expect(find.byKey(const Key('contact-dossier-description')), findsNothing);
    expect(find.textContaining('Sin '), findsNothing);
  });

  testWidgets('archivado: solo restaurar y la marca ARCHIVADO', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _contact('a1b2c3d4', name: 'Diego', archived: true));

    expect(find.text('ARCHIVADO'), findsOneWidget);
    expect(find.byKey(const Key('contact-restore')), findsOneWidget);
    expect(find.byKey(const Key('contact-edit')), findsNothing);
    expect(find.byKey(const Key('contact-archive')), findsNothing);
  });

  testWidgets('eliminar pide confirmación y archiva', (
    WidgetTester tester,
  ) async {
    final _Repository repository = _Repository();
    await _pump(tester, _rocio(), repository: repository);

    await tester.tap(find.byKey(const Key('contact-archive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contact-confirm')));
    await tester.pumpAndSettle();

    expect(repository.archived.single.id, _rocio().id);
    expect(find.text('Personaje archivado.'), findsOneWidget);
  });

  testWidgets('CERRAR vuelve a la lista', (WidgetTester tester) async {
    await _pump(tester, _rocio(), startInList: true);

    expect(find.text('lista'), findsOneWidget);
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contact-dossier-panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('contact-dossier-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contact-dossier-panel')), findsNothing);
    expect(find.text('lista'), findsOneWidget);
  });

  testWidgets('teléfono: la foto arriba y el panel debajo', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _rocio(), size: const Size(412, 1400));

    final Offset photo = tester.getTopLeft(
      find.byKey(const Key('contact-dossier-photo')),
    );
    final Offset panel = tester.getTopLeft(
      find.byKey(const Key('contact-dossier-panel')),
    );
    expect(photo.dy, lessThan(panel.dy));
  });
}

Contact _rocio() => _contact(
  '4f2a91c7-0000-4000-8000-000000000000',
  name: 'Lic. Rocío Mamani',
  role: 'Docente · Cálculo II',
  description: 'Revisa los avances del proyecto final los martes.',
);

Contact _contact(
  String id, {
  String? name,
  String? role,
  String? description,
  bool archived = false,
}) => Contact(
  id: id,
  displayName: name,
  role: role,
  description: description,
  createdAtUtc: _now,
  updatedAtUtc: _now,
  archivedAtUtc: archived ? _now : null,
  rowVersion: 1,
);

Future<void> _pump(
  WidgetTester tester,
  Contact contact, {
  _Repository? repository,
  Size size = const Size(1280, 1000),
  bool startInList = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final _Repository repo = repository ?? _Repository();
  final GoRouter router = GoRouter(
    initialLocation: startInList ? '/list' : '/contacts/${contact.id}',
    routes: <RouteBase>[
      GoRoute(
        path: '/list',
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: Column(
            children: <Widget>[
              const Text('lista'),
              TextButton(
                onPressed: () => context.push('/contacts/${contact.id}'),
                child: const Text('abrir'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/contacts/:contactId',
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
      overrides: <Override>[
        contactProvider.overrideWith(
          (Ref ref, String id) => Stream<Contact?>.value(contact),
        ),
        contactApplicationServiceProvider.overrideWithValue(
          ContactApplicationService(
            repository: repo,
            clock: const _Clock(),
            idGenerator: const _Ids(),
          ),
        ),
        entityPhotoRepositoryProvider.overrideWithValue(
          const _PhotoRepository(),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

final class _Clock implements JournalClock {
  const _Clock();

  @override
  DateTime nowUtc() => _now;
}

final class _Ids implements JournalIdGenerator {
  const _Ids();

  @override
  String nextId() => 'id';
}

final class _Repository implements ContactRepository {
  final List<Contact> archived = <Contact>[];

  @override
  Future<Result<Contact>> archive(
    Contact contact, {
    required DateTime atUtc,
  }) async {
    archived.add(contact);
    return Success<Contact>(contact);
  }

  @override
  Future<Result<Contact>> restore(
    Contact contact, {
    required DateTime atUtc,
  }) async => Success<Contact>(contact);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
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
