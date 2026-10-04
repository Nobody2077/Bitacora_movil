import 'package:bitacora_rpg_personal/app/providers/persistence_providers.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/models/mission.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/repositories/mission_repository.dart';
import 'package:bitacora_rpg_personal/features/missions/presentation/mission_calendar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('muestra el mes real y la agenda del día seleccionado', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final DateTime now = DateTime.now();
    final DateTime scheduledLocal = DateTime(
      now.year,
      now.month,
      now.day,
      9,
      30,
    );
    final _CalendarRepository repository = _CalendarRepository(
      Mission(
        id: 'calendar-mission',
        areaId: 'area',
        title: 'Misión visible en agenda',
        type: MissionType.custom,
        importance: MissionImportance.normal,
        priority: MissionPriority.normal,
        isRequired: false,
        status: MissionStatus.scheduled,
        scheduledAtUtc: scheduledLocal.toUtc(),
        xpPlanned: 25,
        rowVersion: 1,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [missionRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: MissionCalendarPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CALENDARIO DE MISIONES'), findsOneWidget);
    expect(find.text('Misión visible en agenda'), findsOneWidget);
    expect(repository.startUtc, DateTime(now.year, now.month).toUtc());
    expect(repository.endUtc, DateTime(now.year, now.month + 1).toUtc());
  });

  testWidgets('cambia entre rangos mensual, semanal y diario', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime selected = DateTime(2026, 8, 28);
    final _CalendarRepository repository = _CalendarRepository(
      Mission(
        id: 'range-mission',
        areaId: 'area',
        title: 'Rango visible',
        type: MissionType.custom,
        importance: MissionImportance.normal,
        priority: MissionPriority.normal,
        isRequired: false,
        status: MissionStatus.scheduled,
        scheduledAtUtc: selected.toUtc(),
        xpPlanned: 25,
        rowVersion: 1,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [missionRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: MissionCalendarPage(initialDay: selected)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.startUtc, DateTime(2026, 8).toUtc());
    expect(repository.endUtc, DateTime(2026, 9).toUtc());

    await tester.tap(find.byIcon(Icons.view_week_outlined));
    await tester.pumpAndSettle();
    final DateTime monday = selected.subtract(
      Duration(days: selected.weekday - DateTime.monday),
    );
    expect(repository.startUtc, monday.toUtc());
    expect(repository.endUtc, monday.add(const Duration(days: 7)).toUtc());
    expect(find.textContaining('listas'), findsWidgets);

    await tester.tap(find.byIcon(Icons.view_day_outlined));
    await tester.pumpAndSettle();
    expect(repository.startUtc, selected.toUtc());
    expect(repository.endUtc, selected.add(const Duration(days: 1)).toUtc());
    expect(find.text('Rango visible'), findsOneWidget);
  });

  testWidgets('crea una misión usando la fecha seleccionada', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime selected = DateTime(2026, 9, 14);
    final _CalendarRepository repository = _CalendarRepository(
      Mission(
        id: 'context-mission',
        areaId: 'area',
        title: 'Contexto',
        type: MissionType.custom,
        importance: MissionImportance.normal,
        priority: MissionPriority.normal,
        isRequired: false,
        status: MissionStatus.scheduled,
        scheduledAtUtc: selected.toUtc(),
        xpPlanned: 25,
        rowVersion: 1,
      ),
    );
    Uri? destination;
    final GoRouter router = GoRouter(
      initialLocation: '/calendar',
      routes: <RouteBase>[
        GoRoute(
          path: '/calendar',
          builder: (context, state) =>
              Scaffold(body: MissionCalendarPage(initialDay: selected)),
        ),
        GoRoute(
          name: 'missionNew',
          path: '/missions/new',
          builder: (context, state) {
            destination = state.uri;
            return const Scaffold(body: Text('Formulario contextual'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [missionRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('NUEVA MISIÓN'));
    await tester.pumpAndSettle();

    expect(find.text('Formulario contextual'), findsOneWidget);
    expect(destination?.queryParameters['origin'], 'calendar');
    expect(destination?.queryParameters['date'], '2026-09-14');
  });
}

final class _CalendarRepository implements MissionRepository {
  _CalendarRepository(this.mission);

  final Mission mission;
  DateTime? startUtc;
  DateTime? endUtc;

  @override
  Future<Result<Mission>> archive({
    required Mission mission,
    required String eventId,
    required DateTime occurredAtUtc,
  }) => throw UnimplementedError();

  @override
  Stream<Result<List<Mission>>> watchScheduledBetween({
    required DateTime startUtc,
    required DateTime endUtc,
  }) {
    this.startUtc = startUtc;
    this.endUtc = endUtc;
    return Stream<Result<List<Mission>>>.value(
      Success<List<Mission>>(<Mission>[mission]),
    );
  }

  @override
  Future<Result<List<MissionArea>>> findVisibleAreas() async =>
      const Success<List<MissionArea>>(<MissionArea>[]);

  @override
  Future<Result<Mission?>> findById(String id) async =>
      const Success<Mission?>(null);

  @override
  Future<Result<Mission?>> findActiveTimer() async =>
      const Success<Mission?>(null);

  @override
  Future<Result<List<Mission>>> findScheduledBetween({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async => Success<List<Mission>>(<Mission>[mission]);

  @override
  Stream<Result<List<Mission>>> watchUpcoming({required DateTime startUtc}) =>
      const Stream<Result<List<Mission>>>.empty();

  @override
  Stream<Result<List<Mission>>> watchAll() =>
      const Stream<Result<List<Mission>>>.empty();

  @override
  Future<Result<Mission>> create(
    Mission mission, {
    required String eventId,
    required String notificationId,
    required String expiryNotificationId,
    required DateTime occurredAtUtc,
    Iterable<String> contactIds = const <String>[],
  }) => throw UnimplementedError();

  @override
  Future<Result<Mission>> update(
    Mission mission, {
    required String eventId,
    required String notificationId,
    required String expiryNotificationId,
    required DateTime occurredAtUtc,
    Iterable<String>? contactIds,
  }) => throw UnimplementedError();

  @override
  Future<Result<Mission>> startTimer({
    required String missionId,
    required int expectedRowVersion,
    required MissionStatus expectedStatus,
    required String timeEntryId,
    required String eventId,
    required DateTime occurredAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<Mission>> pauseTimer({
    required String missionId,
    required int expectedRowVersion,
    required String eventId,
    required DateTime occurredAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<Mission>> switchTimer({
    required Mission activeMission,
    required Mission targetMission,
    required String pauseEventId,
    required String timeEntryId,
    required String startEventId,
    required DateTime occurredAtUtc,
  }) => throw UnimplementedError();
}
