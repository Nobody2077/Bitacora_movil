import 'package:bitacora_rpg_personal/app/app.dart';
import 'package:bitacora_rpg_personal/app/config/app_environment.dart';
import 'package:bitacora_rpg_personal/app/providers/app_preferences_provider.dart';
import 'package:bitacora_rpg_personal/app/router/app_route_contract.dart';
import 'package:bitacora_rpg_personal/app/router/app_router.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_controller.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_state.dart';
import 'package:bitacora_rpg_personal/features/access/domain/biometric_authenticator.dart';
import 'package:bitacora_rpg_personal/features/settings/domain/models/app_preferences.dart';
import 'package:bitacora_rpg_personal/shared/widgets/feature_placeholder_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('deep link bloqueado no construye ninguna superficie protegida', (
    WidgetTester tester,
  ) async {
    var protectedBuilds = 0;
    await tester.pumpWidget(
      _app(
        initialLocation: '/missions/private-id/edit?returnTo=/finance',
        session: _lockedSession,
        onProtectedBuild: (_) => protectedBuilds += 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ENLACE DE ACCESO'), findsOneWidget);
    expect(find.byType(FeaturePlaceholderPage), findsNothing);
    expect(protectedBuilds, 0);
  });

  testWidgets('desbloqueado sí construye el destino protegido exacto', (
    WidgetTester tester,
  ) async {
    final List<String> builtRoutes = <String>[];
    await tester.pumpWidget(
      _app(
        initialLocation: '/missions/private-id/edit',
        session: const AccessSessionState.unlockedForTesting(),
        onProtectedBuild: (AppRouteContract route) =>
            builtRoutes.add(route.name),
      ),
    );
    await tester.pumpAndSettle();

    expect(builtRoutes, <String>['missionEdit']);
  });
}

Widget _app({
  required String initialLocation,
  required AccessSessionState session,
  required ProtectedRouteBuildObserver onProtectedBuild,
}) => ProviderScope(
  overrides: [
    accessSessionSeedProvider.overrideWithValue(session),
    protectedRouteBuildObserverProvider.overrideWithValue(onProtectedBuild),
    appEnvironmentProvider.overrideWithValue(
      AppEnvironment(
        flavor: AppFlavor.development,
        appName: 'Bitácora TEST',
        enableRouterDiagnostics: false,
        initialLocation: initialLocation,
      ),
    ),
    appPreferencesProvider.overrideWith(
      (ref) => Stream<AppPreferences>.value(AppPreferences.defaults),
    ),
    accessAccentProvider.overrideWith((ref) async => AppAccentColor.red),
  ],
  child: const BitacoraApp(),
);

const AccessSessionState _lockedSession = AccessSessionState(
  phase: AccessSessionPhase.locked,
  revision: 1,
  setupStep: AccessSetupStep.enterPin,
  recoveryStep: AccessRecoveryStep.enterRecoveryAndPin,
  biometricsEnabled: false,
  biometricAvailability: BiometricAvailability.unavailable,
  isBusy: false,
  failedAttempts: 0,
  blockedUntilEpochMillis: null,
  notice: null,
  oneTimeRecoveryCode: null,
);
