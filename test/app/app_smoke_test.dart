import 'package:bitacora_rpg_personal/app/app.dart';
import 'package:bitacora_rpg_personal/app/config/app_environment.dart';
import 'package:bitacora_rpg_personal/app/providers/app_preferences_provider.dart';
import 'package:bitacora_rpg_personal/app/providers/persistence_providers.dart';
import 'package:bitacora_rpg_personal/app/router/app_routes.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme_tokens.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_controller.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_state.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/journal_entry.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/journal_photo.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/repositories/journal_repository.dart';
import 'package:bitacora_rpg_personal/features/missions/application/mission_providers.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/models/mission.dart';
import 'package:bitacora_rpg_personal/features/profile/application/user_profile_providers.dart';
import 'package:bitacora_rpg_personal/features/profile/domain/models/user_profile.dart';
import 'package:bitacora_rpg_personal/features/settings/domain/models/app_preferences.dart';
import 'package:bitacora_rpg_personal/shared/adaptive/terminal_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BitacoraApp', () {
    testWidgets('usa NavigationBar en teléfono y cambia de rama', (
      WidgetTester tester,
    ) async {
      _ensureResumed(tester);
      _setSurface(tester, const Size(412, 915));
      await tester.pumpWidget(_testApp(initialLocation: AppRoutes.home));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(TerminalSidebar), findsNothing);

      await tester.tap(find.text('Misiones'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
    });

    testWidgets('usa TerminalSidebar extendida en tablet', (
      WidgetTester tester,
    ) async {
      _ensureResumed(tester);
      _setSurface(tester, const Size(1280, 800));
      await tester.pumpWidget(_testApp(initialLocation: AppRoutes.journal));
      await tester.pumpAndSettle();

      expect(find.byType(TerminalSidebar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Bitácora'), findsWidgets);
      expect(find.text('Progreso'), findsOneWidget);
      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Usuario local'), findsOneWidget);
      expect(find.text('SISTEMA PERSONAL'), findsNothing);

      final BuildContext sidebarContext = tester.element(
        find.byType(TerminalSidebar),
      );
      final AppThemeTokens tokens = Theme.of(
        sidebarContext,
      ).extension<AppThemeTokens>()!;
      final Text missionsLabel = tester.widget<Text>(find.text('Misiones'));
      final Text journalLabel = tester.widget<Text>(
        find.descendant(
          of: find.byType(TerminalSidebar),
          matching: find.text('Bitácora'),
        ),
      );
      expect(missionsLabel.style?.color, tokens.terminalRed);
      expect(missionsLabel.style?.fontSize, 16);
      expect(journalLabel.style?.color, tokens.infoCyan);

      await tester.tap(find.text('Usuario local'));
      await tester.pumpAndSettle();
      expect(find.text('Tu perfil local'), findsOneWidget);
      expect(find.text('Elegir foto'), findsOneWidget);
      expect(find.text('Guardar nombre'), findsOneWidget);
    });

    testWidgets('conecta la raíz de Bitácora a la cronología funcional', (
      WidgetTester tester,
    ) async {
      _ensureResumed(tester);
      _setSurface(tester, const Size(1280, 800));
      await tester.pumpWidget(_testApp(initialLocation: AppRoutes.journal));
      await tester.pumpAndSettle();

      expect(find.text('BITÁCORA'), findsWidgets);
      expect(find.text('NUEVA ENTRADA'), findsOneWidget);
      expect(find.text('Este día aún está en blanco'), findsOneWidget);
    });

    testWidgets('conecta búsqueda y archivo de Bitácora a rutas reales', (
      WidgetTester tester,
    ) async {
      _ensureResumed(tester);
      _setSurface(tester, const Size(1280, 1000));
      await tester.pumpWidget(_testApp(initialLocation: AppRoutes.journal));
      await tester.pumpAndSettle();

      await tester.tap(find.text('BUSCAR'));
      await tester.pumpAndSettle();
      expect(find.text('BUSCAR EN BITÁCORA'), findsOneWidget);
      expect(find.text('Sin coincidencias'), findsOneWidget);

      await tester.pumpWidget(_testApp(initialLocation: '/journal/archive'));
      await tester.pumpAndSettle();
      expect(find.text('ARCHIVO DE BITÁCORA'), findsOneWidget);
      expect(find.text('El archivo está vacío'), findsOneWidget);
    });

    testWidgets(
      'Apariencia conserva el mismo estado lógico en phone y tablet',
      (WidgetTester tester) async {
        _ensureResumed(tester);
        for (final Size size in <Size>[
          const Size(412, 915),
          const Size(1280, 800),
        ]) {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            _testApp(initialLocation: AppRoutes.settingsAppearance),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('large-text-switch')), findsOneWidget);
          expect(find.byKey(const Key('reduce-motion-switch')), findsOneWidget);
          expect(find.byKey(const Key('high-contrast-switch')), findsOneWidget);
          expect(find.byKey(const Key('hide-amounts-switch')), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
      },
    );
  });
}

Widget _testApp({required String initialLocation}) => ProviderScope(
  overrides: [
    accessSessionSeedProvider.overrideWithValue(
      const AccessSessionState.unlockedForTesting(),
    ),
    appEnvironmentProvider.overrideWithValue(
      AppEnvironment(
        flavor: AppFlavor.development,
        appName: 'Bitácora RPG TEST',
        enableRouterDiagnostics: false,
        initialLocation: initialLocation,
      ),
    ),
    appPreferencesProvider.overrideWith(
      (ref) => Stream<AppPreferences>.value(AppPreferences.defaults),
    ),
    todayMissionsProvider.overrideWith(
      (ref) => Stream<List<Mission>>.value(const <Mission>[]),
    ),
    upcomingMissionsProvider.overrideWith(
      (ref) => Stream<List<Mission>>.value(const <Mission>[]),
    ),
    missionAreasProvider.overrideWith((ref) async => const <MissionArea>[]),
    activeTimerMissionProvider.overrideWith((ref) async => null),
    userProfileProvider.overrideWith(
      (ref) async => const UserProfile.localDefault(),
    ),
    journalRepositoryProvider.overrideWithValue(
      const _SmokeJournalRepository(),
    ),
  ],
  child: const BitacoraApp(),
);

void _setSurface(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

final class _SmokeJournalRepository implements JournalRepository {
  const _SmokeJournalRepository();

  @override
  Stream<Result<List<JournalEntry>>> watchRecent({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 100,
  }) => Stream<Result<List<JournalEntry>>>.value(
    const Success<List<JournalEntry>>(<JournalEntry>[]),
  );

  @override
  Future<Result<JournalEntry>> create(JournalEntry entry) =>
      throw UnimplementedError();

  @override
  Future<Result<List<JournalEntry>>> findRecent({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 100,
  }) async => const Success<List<JournalEntry>>(<JournalEntry>[]);

  @override
  Future<Result<JournalEntry?>> findById(String id) async =>
      const Success<JournalEntry?>(null);

  @override
  Future<Result<JournalEntry>> update(JournalEntry entry) =>
      throw UnimplementedError();

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
  ) async => const Success<List<JournalEntry>>(<JournalEntry>[]);

  @override
  Stream<Result<List<JournalEntry>>> watchArchived({int limit = 200}) =>
      Stream<Result<List<JournalEntry>>>.value(
        const Success<List<JournalEntry>>(<JournalEntry>[]),
      );
}

void _ensureResumed(WidgetTester tester) {
  if (tester.binding.lifecycleState != AppLifecycleState.resumed) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }
}
