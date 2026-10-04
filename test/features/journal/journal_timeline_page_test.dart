import 'package:bitacora_rpg_personal/app/providers/persistence_providers.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/journal_entry.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/journal_photo.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/repositories/journal_repository.dart';
import 'package:bitacora_rpg_personal/features/journal/presentation/journal_timeline_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra resumen diario y entradas reales', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime nowUtc = DateTime.now().toUtc();
    final _JournalRepository repository = _JournalRepository(<JournalEntry>[
      _entry(
        id: 'entry-1',
        title: 'Sesión enfocada',
        mood: JournalMood.focused,
        occurredAtUtc: nowUtc,
      ),
      _entry(
        id: 'entry-2',
        title: 'Misión terminada',
        mood: JournalMood.focused,
        origin: JournalOrigin.mission,
        missionId: 'mission-1',
        occurredAtUtc: nowUtc.subtract(const Duration(hours: 1)),
      ),
      _entry(
        id: 'entry-3',
        title: 'Ingreso registrado',
        mood: JournalMood.normal,
        origin: JournalOrigin.transaction,
        transactionId: 'transaction-1',
        occurredAtUtc: nowUtc.subtract(const Duration(hours: 2)),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [journalRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: JournalTimelinePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BITÁCORA'), findsOneWidget);
    expect(find.text('Sesión enfocada'), findsOneWidget);
    expect(find.text('Misión terminada'), findsOneWidget);
    expect(find.text('Ingreso registrado'), findsOneWidget);
    expect(find.text('Enfocado'), findsOneWidget);
    expect(find.text('VINCULADAS'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(repository.startUtc, isNotNull);
    expect(repository.endUtc, isNotNull);
  });

  testWidgets('ofrece crear cuando el día está vacío', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalRepositoryProvider.overrideWithValue(
            _JournalRepository(const <JournalEntry>[]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: JournalTimelinePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Este día aún está en blanco'), findsOneWidget);
    expect(find.text('ESCRIBIR ENTRADA'), findsOneWidget);
  });
}

JournalEntry _entry({
  required String id,
  required String title,
  required JournalMood mood,
  required DateTime occurredAtUtc,
  JournalOrigin origin = JournalOrigin.manual,
  String? missionId,
  String? transactionId,
}) => JournalEntry(
  id: id,
  origin: origin,
  missionId: missionId,
  transactionId: transactionId,
  title: title,
  body: 'Contenido de prueba',
  mood: mood,
  isPrivate: true,
  occurredAtUtc: occurredAtUtc,
  createdAtUtc: occurredAtUtc,
  updatedAtUtc: occurredAtUtc,
  attachmentCount: 0,
);

final class _JournalRepository implements JournalRepository {
  _JournalRepository(this.entries);

  final List<JournalEntry> entries;
  DateTime? startUtc;
  DateTime? endUtc;

  @override
  Stream<Result<List<JournalEntry>>> watchRecent({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 100,
  }) {
    this.startUtc = startUtc;
    this.endUtc = endUtc;
    return Stream<Result<List<JournalEntry>>>.value(
      Success<List<JournalEntry>>(entries),
    );
  }

  @override
  Future<Result<JournalEntry>> create(
    JournalEntry entry, {
    Iterable<String> contactIds = const <String>[],
  }) => throw UnimplementedError();

  @override
  Future<Result<List<JournalEntry>>> findRecent({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 100,
  }) async => Success<List<JournalEntry>>(entries);

  @override
  Future<Result<JournalEntry?>> findById(String id) async =>
      const Success<JournalEntry?>(null);

  @override
  Future<Result<JournalEntry>> update(
    JournalEntry entry, {
    Iterable<String>? contactIds,
  }) => throw UnimplementedError();

  @override
  Future<Result<JournalPhoto>> addPhoto(JournalPhoto photo) =>
      throw UnimplementedError();

  @override
  Future<Result<JournalPhoto?>> archivePhoto({
    required String attachmentId,
    required DateTime archivedAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<Set<String>>> findActivePhotoStorageNames() async =>
      const Success<Set<String>>(<String>{});

  @override
  Future<Result<List<JournalPhoto>>> findPhotos(String entryId) async =>
      const Success<List<JournalPhoto>>(<JournalPhoto>[]);

  @override
  Future<Result<JournalEntry>> archiveEntry({
    required String entryId,
    required DateTime archivedAtUtc,
    required DateTime updatedAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<JournalEntry>> restoreEntry({
    required String entryId,
    required DateTime updatedAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<List<JournalEntry>>> search(
    JournalSearchCriteria criteria,
  ) async => Success<List<JournalEntry>>(entries);

  @override
  Stream<Result<List<JournalEntry>>> watchArchived({int limit = 200}) =>
      Stream<Result<List<JournalEntry>>>.value(
        const Success<List<JournalEntry>>(<JournalEntry>[]),
      );
}
