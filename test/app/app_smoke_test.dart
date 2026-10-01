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
import 'package:bitacora_rpg_personal/features/progress/application/progress_providers.dart';
import 'package:bitacora_rpg_personal/features/progress/domain/models/progress_models.dart';
import 'package:bitacora_rpg_personal/features/progress/domain/models/rpg_level.dart';
import 'package:bitacora_rpg_personal/features/settings/domain/models/app_preferences.dart';
import 'package:bitacora_rpg_personal/shared/adaptive/app_exit.dart';
import 'package:bitacora_rpg_personal/shared/adaptive/terminal_sidebar.dart';
import 'package:bitacora_rpg_personal/shared/device/device_battery.dart';
import 'package:bitacora_rpg_personal/shared/sound/ui_sound.dart';
import 'package:bitacora_rpg_personal/shared/sound/ui_sound_preferences.dart';
import 'package:bitacora_rpg_personal/shared/widgets/terminal/terminal_widgets.dart';
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
      expect(
        find.byKey(const ValueKey<String>('sidebar-global-level-panel')),
        findsNothing,
      );

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
      await tester.pumpWidget(
        _testApp(
          initialLocation: AppRoutes.journal,
          todayMissions: _sidebarMissions(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TerminalSidebar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      for (final MapEntry<String, String> item in const <String, String>{
        'Inicio': 'INICIO',
        'Misiones': 'MISIONES',
        'Bitácora': 'BITÁCORA',
        'Economía': 'ECONOMÍA',
        'Progreso': 'PROGRESO',
        'Ajustes': 'AJUSTES',
      }.entries) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey<String>('sidebar-destination-${item.key}')),
            matching: find.text(item.value),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Usuario local'), findsOneWidget);
      expect(find.text('SISTEMA PERSONAL'), findsNothing);

      final BuildContext sidebarContext = tester.element(
        find.byType(TerminalSidebar),
      );
      final AppThemeTokens tokens = Theme.of(
        sidebarContext,
      ).extension<AppThemeTokens>()!;
      final Text missionsLabel = tester.widget<Text>(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('sidebar-destination-Misiones'),
          ),
          matching: find.text('MISIONES'),
        ),
      );
      final Text journalLabel = tester.widget<Text>(
        find.descendant(
          of: find.byType(TerminalSidebar),
          matching: find.text('BITÁCORA'),
        ),
      );
      final Text profileName = tester.widget<Text>(
        find.byKey(const ValueKey<String>('sidebar-profile-name')),
      );
      expect(missionsLabel.style?.color, tokens.terminalRed);
      expect(missionsLabel.style?.fontSize, 16);
      expect(journalLabel.style?.color, tokens.valueYellow);
      expect(profileName.style?.color, tokens.valueYellow);
      expect(find.text('PERFIL LOCAL'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TerminalSidebar),
          matching: find.byIcon(Icons.edit_outlined),
        ),
        findsNothing,
      );
      expect(find.text('SALUD'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('sidebar-health-icon')),
        findsOneWidget,
      );
      expect(find.text('1/2'), findsOneWidget);
      final LinearProgressIndicator healthProgress = tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey<String>('sidebar-health-progress')),
          );
      expect(healthProgress.value, 0.5);
      expect(
        find.byKey(const ValueKey<String>('sidebar-profile-missions-label')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('sidebar-device-battery')),
        findsOneWidget,
      );
      for (int index = 0; index < 13; index++) {
        expect(
          find.byKey(
            ValueKey<String>('sidebar-device-battery-segment-$index-filled'),
          ),
          findsOneWidget,
        );
      }
      for (int index = 13; index < 20; index++) {
        expect(
          find.byKey(
            ValueKey<String>('sidebar-device-battery-segment-$index-empty'),
          ),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey<String>('sidebar-mission-segments-overflow')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('sidebar-global-level-panel')),
        findsOneWidget,
      );
      expect(find.text('NIVEL GLOBAL'), findsOneWidget);
      expect(find.text('07'), findsOneWidget);
      expect(find.text('400 / 1300'), findsOneWidget);
      final LinearProgressIndicator globalProgress = tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey<String>('sidebar-global-level-progress')),
          );
      expect(globalProgress.value, closeTo(400 / 1300, 0.0001));
      final AnimatedContainer selectedDestination = tester
          .widget<AnimatedContainer>(
            find.byKey(const ValueKey<String>('sidebar-destination-Bitácora')),
          );
      final ShapeDecoration selectedDecoration =
          selectedDestination.decoration! as ShapeDecoration;
      final BeveledRectangleBorder selectedShape =
          selectedDecoration.shape as BeveledRectangleBorder;
      expect(selectedShape.side.color, tokens.valueYellow);
      expect(selectedShape.side.width, 1.5);
      expect(
        selectedShape.borderRadius,
        const BorderRadius.only(bottomRight: Radius.circular(10)),
      );
      await expectLater(
        find.byType(TerminalSidebar),
        matchesGoldenFile('goldens/sidebar_modular_battery.png'),
      );
      final TerminalDivider profileDivider = tester.widget<TerminalDivider>(
        find.byKey(const ValueKey<String>('sidebar-profile-divider')),
      );
      final TerminalDivider headerDivider = tester.widget<TerminalDivider>(
        find.byKey(const ValueKey<String>('application-header-divider')),
      );
      final VerticalDivider shellDivider = tester.widget<VerticalDivider>(
        find.byKey(const ValueKey<String>('sidebar-content-divider')),
      );
      expect(profileDivider.color, tokens.structuralRed);
      expect(headerDivider.color, tokens.structuralRed);
      expect(shellDivider.color, tokens.structuralRed);

      await tester.tap(find.text('Usuario local'));
      await tester.pumpAndSettle();
      expect(find.text('Tu perfil local'), findsOneWidget);
      expect(find.text('Elegir foto'), findsOneWidget);
      expect(find.text('Guardar nombre'), findsOneWidget);
    });

    testWidgets('Salir pide confirmación, bloquea la sesión y cierra la app', (
      WidgetTester tester,
    ) async {
      _ensureResumed(tester);
      _setSurface(tester, const Size(1280, 800));
      var exits = 0;
      await tester.pumpWidget(
        _testApp(
          initialLocation: AppRoutes.journal,
          onAppExit: () async => exits++,
        ),
      );
      await tester.pumpAndSettle();

      final Finder exit = find.byKey(
        const ValueKey<String>('sidebar-destination-Salir'),
      );
      expect(
        find.descendant(of: exit, matching: find.text('SALIR')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(exit).dy,
        greaterThan(
          tester
              .getTopLeft(
                find.byKey(
                  const ValueKey<String>('sidebar-destination-Ajustes'),
                ),
              )
              .dy,
        ),
      );

      await tester.tap(exit);
      await tester.pumpAndSettle();
      expect(find.text('¿Deseas salir?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('exit-cancel')));
      await tester.pumpAndSettle();
      expect(exits, 0);
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(TerminalSidebar)),
      );
      expect(
        container.read(accessSessionProvider).phase,
        AccessSessionPhase.unlocked,
      );

      await tester.tap(exit);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exit-confirm')));
      await tester.pumpAndSettle();

      expect(exits, 1);
      expect(
        container.read(accessSessionProvider).phase,
        AccessSessionPhase.locked,
      );
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

    testWidgets(
      'Sonido arranca apagado y al activar logros guarda y da una muestra',
      (WidgetTester tester) async {
        _ensureResumed(tester);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1280, 800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final _MemorySoundStore store = _MemorySoundStore();
        final _RecordingSoundPlayer player = _RecordingSoundPlayer();

        await tester.pumpWidget(
          _testApp(
            initialLocation: AppRoutes.settingsSound,
            soundStore: store,
            soundPlayer: player,
          ),
        );
        await tester.pumpAndSettle();

        final Finder reward = find.byKey(const Key('reward-sound-switch'));
        final Finder interface = find.byKey(
          const Key('interface-sound-switch'),
        );
        expect(tester.widget<Switch>(reward).value, isFalse);
        expect(tester.widget<Switch>(interface).value, isFalse);

        await tester.tap(reward);
        await tester.pumpAndSettle();

        expect(store.value.rewardEnabled, isTrue);
        expect(store.value.interfaceEnabled, isFalse);
        expect(tester.widget<Switch>(reward).value, isTrue);
        expect(player.played, <UiSound>[UiSound.missionCompleted]);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

final class _MemorySoundStore implements UiSoundPreferenceStore {
  UiSoundPreferences value = UiSoundPreferences.defaults;

  @override
  Future<UiSoundPreferences> read() async => value;

  @override
  Future<void> write(UiSoundPreferences preferences) async {
    value = preferences;
  }
}

final class _RecordingSoundPlayer implements UiSoundPlayer {
  final List<UiSound> played = <UiSound>[];

  @override
  Future<void> play(UiSound sound) async => played.add(sound);

  @override
  Future<void> stop(UiSound sound) async {}
}

Widget _testApp({
  required String initialLocation,
  List<Mission> todayMissions = const <Mission>[],
  int batteryLevel = 62,
  UiSoundPreferenceStore? soundStore,
  UiSoundPlayer? soundPlayer,
  Future<void> Function()? onAppExit,
}) => ProviderScope(
  overrides: [
    appExitProvider.overrideWithValue(onAppExit ?? () async {}),
    uiSoundPreferenceStoreProvider.overrideWithValue(
      soundStore ?? _MemorySoundStore(),
    ),
    uiSoundPlayerProvider.overrideWithValue(
      soundPlayer ?? _RecordingSoundPlayer(),
    ),
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
      (ref) => Stream<List<Mission>>.value(todayMissions),
    ),
    deviceBatteryLevelProvider.overrideWith(
      (ref) => Stream<int?>.value(batteryLevel),
    ),
    upcomingMissionsProvider.overrideWith(
      (ref) => Stream<List<Mission>>.value(const <Mission>[]),
    ),
    missionAreasProvider.overrideWith(
      (ref) async => const <MissionArea>[
        MissionArea(
          id: 'health',
          name: 'Salud',
          iconKey: 'favorite',
          colorHex: '#22C55E',
          isDefault: false,
        ),
      ],
    ),
    activeTimerMissionProvider.overrideWith((ref) async => null),
    userProfileProvider.overrideWith(
      (ref) async => const UserProfile.localDefault(),
    ),
    overallProgressProvider.overrideWith(
      (ref) async => OverallProgressViewData(
        rpgLevel: RpgLevel.fromTotalXp(4000),
        totalXp: 4000,
        todayXp: 0,
        weekXp: 0,
        areaBreakdown: const <AreaProgressItem>[],
      ),
    ),
    journalRepositoryProvider.overrideWithValue(
      const _SmokeJournalRepository(),
    ),
  ],
  child: const BitacoraApp(),
);

List<Mission> _sidebarMissions() => List<Mission>.generate(
  7,
  (int index) => Mission(
    id: 'mission-$index',
    areaId: index < 2 ? 'health' : 'other',
    title: 'Misión $index',
    type: MissionType.daily,
    importance: MissionImportance.normal,
    priority: MissionPriority.normal,
    isRequired: false,
    status: index == 0 || index == 2
        ? MissionStatus.completed
        : MissionStatus.scheduled,
    xpPlanned: 25,
    rowVersion: 1,
  ),
  growable: false,
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
