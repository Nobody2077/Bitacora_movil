import 'package:bitacora_rpg_personal/app/app.dart';
import 'package:bitacora_rpg_personal/app/config/app_environment.dart';
import 'package:bitacora_rpg_personal/app/router/app_routes.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_controller.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_state.dart';
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
      expect(find.byType(NavigationRail), findsNothing);

      await tester.tap(find.text('Misiones'));
      await tester.pumpAndSettle();

      expect(find.text('Misiones de hoy'), findsOneWidget);
      expect(find.text('/missions/today'), findsOneWidget);
    });

    testWidgets('usa NavigationRail extendido en tablet', (
      WidgetTester tester,
    ) async {
      _ensureResumed(tester);
      _setSurface(tester, const Size(1280, 800));
      await tester.pumpWidget(
        _testApp(initialLocation: AppRoutes.dashboardDaily),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Dashboard diario'), findsOneWidget);
      expect(find.text('Progreso'), findsOneWidget);
      expect(find.text('Ajustes'), findsOneWidget);
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
