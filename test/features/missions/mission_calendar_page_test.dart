import 'package:bitacora_rpg_personal/app/providers/persistence_providers.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/models/mission.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/repositories/mission_repository.dart';
import 'package:bitacora_rpg_personal/features/missions/presentation/mission_calendar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    required DateTime occurredAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<Mission>> update(
    Mission mission, {
    required String eventId,
    required String notificationId,
    required DateTime occurredAtUtc,
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
