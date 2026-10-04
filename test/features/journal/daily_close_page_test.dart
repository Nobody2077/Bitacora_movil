import 'package:bitacora_rpg_personal/app/providers/persistence_providers.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/daily_close.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/journal_entry.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/journal_photo.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/repositories/daily_close_repository.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/repositories/journal_repository.dart';
import 'package:bitacora_rpg_personal/features/journal/presentation/daily_close_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'muestra métricas de cierre del día y permite escribir reflexión',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 1400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final DateTime localDay = DateTime(2026, 8, 27);
      final _FakeDailyCloseRepository closeRepository =
          _FakeDailyCloseRepository(
            DailyCloseSummary(
              completedMissions: const <DailyCloseMission>[
                DailyCloseMission(id: 'm-1', title: 'Completar reporte'),
              ],
              requiredPendingMissions: const <DailyCloseMission>[
                DailyCloseMission(id: 'm-2', title: 'Revisión técnica'),
              ],
              xpEarned: 125,
              workSeconds: 3600,
              incomeMinor: 25000,
              expenseMinor: 5000,
              mainAreaName: 'Proyectos',
            ),
          );
      final _FakeJournalRepository journalRepository = _FakeJournalRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyCloseRepositoryProvider.overrideWithValue(closeRepository),
            journalRepositoryProvider.overrideWithValue(journalRepository),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(body: DailyClosePage(localDay: localDay)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CIERRE DIARIO · 27/08/2026'), findsOneWidget);
      expect(find.text('+125 XP'), findsOneWidget);
      expect(find.text('1 h'), findsOneWidget);
      expect(find.text('Completar reporte'), findsOneWidget);
      expect(find.text('Revisión técnica'), findsOneWidget);
      expect(find.text('Proyectos'), findsOneWidget);

      // Escribir reflexión
      await tester.enterText(
        find.byType(TextField),
        'Hoy aprendí a orquestar múltiples repositorios Drift.',
      );
      await tester.tap(find.text('GUARDAR REFLEXIÓN'));
      await tester.pumpAndSettle();

      expect(find.text('Reflexión diaria guardada.'), findsOneWidget);
    },
  );
}

final class _FakeDailyCloseRepository implements DailyCloseRepository {
  _FakeDailyCloseRepository(this.summary);

  final DailyCloseSummary summary;

  @override
  Future<Result<DailyCloseSummary>> loadSummary({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required DateTime referenceUtc,
  }) async => Success<DailyCloseSummary>(summary);
}

final class _FakeJournalRepository implements JournalRepository {
  final Map<String, JournalEntry> _entries = <String, JournalEntry>{};

  @override
  Future<Result<JournalEntry>> create(
    JournalEntry entry, {
    Iterable<String> contactIds = const <String>[],
  }) async {
    _entries[entry.id] = entry;
    return Success<JournalEntry>(entry);
  }

  @override
  Future<Result<JournalEntry>> update(
    JournalEntry entry, {
    Iterable<String>? contactIds,
  }) async {
    _entries[entry.id] = entry;
    return Success<JournalEntry>(entry);
  }

  @override
  Future<Result<JournalEntry?>> findById(String id) async =>
      Success<JournalEntry?>(_entries[id]);

  @override
  Future<Result<JournalEntry>> archiveEntry({
    required String entryId,
    required DateTime archivedAtUtc,
    required DateTime updatedAtUtc,
  }) async => throw UnimplementedError();

  @override
  Future<Result<JournalPhoto>> addPhoto(JournalPhoto photo) =>
      throw UnimplementedError();

  @override
  Future<Result<JournalPhoto?>> archivePhoto({
    required String attachmentId,
    required DateTime archivedAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<Set<String>>> findActivePhotoStorageNames() =>
      throw UnimplementedError();

  @override
  Future<Result<List<JournalPhoto>>> findPhotos(String entryId) =>
      throw UnimplementedError();

  @override
  Future<Result<List<JournalEntry>>> findRecent({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 100,
  }) => throw UnimplementedError();

  @override
  Future<Result<JournalEntry>> restoreEntry({
    required String entryId,
    required DateTime updatedAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<List<JournalEntry>>> search(JournalSearchCriteria criteria) =>
      throw UnimplementedError();

  @override
  Stream<Result<List<JournalEntry>>> watchArchived({int limit = 200}) =>
      throw UnimplementedError();

  @override
  Stream<Result<List<JournalEntry>>> watchRecent({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 100,
  }) => throw UnimplementedError();
}
