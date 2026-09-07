import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/features/missions/application/mission_providers.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/models/mission.dart';
import 'package:bitacora_rpg_personal/features/missions/presentation/mission_board_page.dart';
import 'package:bitacora_rpg_personal/features/recurrences/application/recurrence_providers.dart';
import 'package:bitacora_rpg_personal/features/recurrences/domain/models/recurrence_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra disponibles y tomadas sin huecos en el tablón', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          missionAreasProvider.overrideWith(
            (ref) => const <MissionArea>[
              MissionArea(
                id: 'area',
                name: 'Salud',
                iconKey: 'favorite',
                colorHex: '#00FFFF',
                isDefault: true,
              ),
            ],
          ),
          missionBoardProvider.overrideWith(
            (ref) => Stream.value(<MissionBoardEntry>[
              MissionBoardEntry(template: _template('available', 'Caminar')),
              MissionBoardEntry(
                template: _template('taken', 'Beber agua'),
                missionId: 'mission-taken',
                missionStatus: MissionStatus.available,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: MissionBoardPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TABLÓN DIARIO'), findsOneWidget);
    expect(find.text('Caminar'), findsOneWidget);
    expect(find.text('Beber agua'), findsOneWidget);
    expect(find.text('TOMAR MISIÓN'), findsOneWidget);
    expect(find.text('ABRIR MISIÓN'), findsOneWidget);
    expect(find.text('DISPONIBLES'), findsOneWidget);
    expect(find.text('EN CURSO'), findsOneWidget);
    expect(find.text('COMPLETADAS HOY'), findsOneWidget);
  });

  testWidgets('una misión resuelta deja el tablón y solo queda su contador', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          missionAreasProvider.overrideWith((ref) => const <MissionArea>[]),
          missionBoardProvider.overrideWith(
            (ref) => Stream.value(<MissionBoardEntry>[
              MissionBoardEntry(template: _template('available', 'Caminar')),
              MissionBoardEntry(
                template: _template('done', 'Beber agua'),
                missionId: 'mission-done',
                missionStatus: MissionStatus.completed,
              ),
              MissionBoardEntry(
                template: _template('partial', 'Leer'),
                missionId: 'mission-partial',
                missionStatus: MissionStatus.partial,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: MissionBoardPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Completada y parcial salen de la lista: su registro vive en Hoy.
    expect(find.text('Beber agua'), findsNothing);
    expect(find.text('Leer'), findsNothing);
    expect(find.text('Caminar'), findsOneWidget);
    expect(find.text('ABRIR MISIÓN'), findsNothing);

    // El contador conserva el registro visual sin ocupar la lista, y es el
    // acceso accesible a Hoy › Completadas.
    expect(find.text('COMPLETADAS HOY'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Completadas hoy: 2')),
      findsOneWidget,
    );
  });

  testWidgets('el tablón despejado invita a revisar las completadas', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          missionAreasProvider.overrideWith((ref) => const <MissionArea>[]),
          missionBoardProvider.overrideWith(
            (ref) => Stream.value(<MissionBoardEntry>[
              MissionBoardEntry(
                template: _template('done', 'Beber agua'),
                missionId: 'mission-done',
                missionStatus: MissionStatus.completed,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: MissionBoardPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No es el vacío de "sin plantillas": distingue haberlas resuelto.
    expect(find.text('TABLÓN DESPEJADO'), findsOneWidget);
    expect(find.text('EL TABLÓN ESTÁ VACÍO'), findsNothing);
    expect(find.text('VER COMPLETADAS DE HOY'), findsOneWidget);
  });
}

RecurrenceTemplate _template(String id, String title) => RecurrenceTemplate(
  id: id,
  areaId: 'area',
  title: title,
  missionType: MissionType.daily,
  importance: MissionImportance.normal,
  priority: MissionPriority.normal,
  isRequired: false,
  xpReward: 25,
  availabilityMode: TemplateAvailabilityMode.board,
  isActive: true,
  objectives: const <RecurrenceObjective>[],
  rule: RecurrenceRule(
    id: 'rule-$id',
    templateId: id,
    frequency: RecurrenceFrequency.daily,
    intervalValue: 1,
    startDate: '2026-08-29',
    timezoneId: 'UTC',
  ),
);
