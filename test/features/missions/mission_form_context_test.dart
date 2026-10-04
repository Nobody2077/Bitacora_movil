import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/features/contacts/application/contact_providers.dart';
import 'package:bitacora_rpg_personal/features/contacts/domain/models/contact.dart';
import 'package:bitacora_rpg_personal/features/missions/application/mission_providers.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/models/mission.dart';
import 'package:bitacora_rpg_personal/features/missions/presentation/mission_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime.utc(2026, 10, 3, 12);

void main() {
  testWidgets('al editar precarga la ubicación y los personajes', (
    WidgetTester tester,
  ) async {
    _tabletView(tester);
    await tester.pumpWidget(
      _app(
        const MissionFormPage(missionId: 'm1'),
        mission: _mission(location: 'Taller de arte'),
        linked: <Contact>[_contact('ana', 'Ana')],
      ),
    );
    await tester.pumpAndSettle();

    final TextFormField location = tester.widget<TextFormField>(
      find.byKey(const Key('mission-location')),
    );
    expect(location.controller!.text, 'Taller de arte');
    expect(
      find.byKey(const ValueKey<String>('contact-chip-ana')),
      findsOneWidget,
    );
  });

  testWidgets('una diaria nueva solo ofrece ubicación, no personajes', (
    WidgetTester tester,
  ) async {
    _tabletView(tester);
    await tester.pumpWidget(
      _app(const MissionFormPage(initialBoard: true), mission: null),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mission-location')), findsOneWidget);
    expect(find.byKey(const Key('contact-picker-open')), findsNothing);
    expect(
      find.textContaining('Las misiones diarias no guardan personajes'),
      findsOneWidget,
    );
  });

  testWidgets('una misión nueva permite elegir personajes activos', (
    WidgetTester tester,
  ) async {
    _tabletView(tester);
    await tester.pumpWidget(
      _app(
        const MissionFormPage(),
        mission: null,
        active: <Contact>[_contact('ana', 'Ana'), _contact('beto', 'Beto')],
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('contact-picker-open')));
    await tester.tap(find.byKey(const Key('contact-picker-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('contact-option-beto')));
    await tester.tap(find.byKey(const Key('contact-picker-accept')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('contact-chip-beto')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('contact-chip-ana')),
      findsNothing,
    );
  });
}

void _tabletView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1400, 2400);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _app(
  Widget page, {
  required Mission? mission,
  List<Contact> linked = const <Contact>[],
  List<Contact> active = const <Contact>[],
}) => ProviderScope(
  overrides: <Override>[
    missionAreasProvider.overrideWith(
      (Ref ref) async => const <MissionArea>[
        MissionArea(
          id: 'studies',
          name: 'Estudios',
          iconKey: 'school',
          colorHex: '#55E6E6',
          isDefault: true,
        ),
      ],
    ),
    missionDetailProvider.overrideWith((Ref ref, String id) async => mission),
    missionContactsProvider.overrideWith((Ref ref, String id) async => linked),
    activeContactsProvider.overrideWith(
      (Ref ref) => Stream<List<Contact>>.value(<Contact>[...linked, ...active]),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: page),
  ),
);

Mission _mission({String? location}) => Mission(
  id: 'm1',
  areaId: 'studies',
  title: 'Pintar el cuadro',
  type: MissionType.primary,
  importance: MissionImportance.normal,
  priority: MissionPriority.normal,
  isRequired: false,
  status: MissionStatus.available,
  xpPlanned: 25,
  rowVersion: 1,
  location: location,
);

Contact _contact(String id, String name) => Contact(
  id: id,
  displayName: name,
  createdAtUtc: _now,
  updatedAtUtc: _now,
  rowVersion: 1,
);
