import 'package:bitacora_rpg_personal/app/app.dart';
import 'package:bitacora_rpg_personal/app/config/app_environment.dart';
import 'package:bitacora_rpg_personal/app/router/app_routes.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme_tokens.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_controller.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_state.dart';
import 'package:bitacora_rpg_personal/features/missions/application/mission_providers.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/models/mission.dart';
import 'package:bitacora_rpg_personal/features/profile/application/user_profile_providers.dart';
import 'package:bitacora_rpg_personal/features/profile/domain/models/user_profile.dart';
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
      await tester.pumpWidget(
        _testApp(initialLocation: AppRoutes.dashboardDaily),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TerminalSidebar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Dashboard diario'), findsOneWidget);
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
      final Text progressLabel = tester.widget<Text>(find.text('Progreso'));
      expect(missionsLabel.style?.color, tokens.terminalRed);
      expect(missionsLabel.style?.fontSize, 16);
      expect(progressLabel.style?.color, tokens.infoCyan);

      await tester.tap(find.text('Usuario local'));
      await tester.pumpAndSettle();
      expect(find.text('Tu perfil local'), findsOneWidget);
      expect(find.text('Elegir foto'), findsOneWidget);
      expect(find.text('Guardar nombre'), findsOneWidget);
    });
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
  ],
  child: const BitacoraApp(),
);

void _setSurface(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void _ensureResumed(WidgetTester tester) {
  if (tester.binding.lifecycleState != AppLifecycleState.resumed) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }
}
