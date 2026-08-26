import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/access/application/access_session_controller.dart';
import '../../features/access/application/access_session_state.dart';
import '../../features/access/presentation/access_gate_page.dart';
import '../../features/access/presentation/privacy_settings_pages.dart';
import '../../features/access/presentation/protected_route_gate.dart';
import '../../features/access/presentation/recovery_page.dart';
import '../../features/missions/presentation/mission_detail_page.dart';
import '../../features/missions/presentation/mission_form_page.dart';
import '../../features/missions/presentation/missions_today_page.dart';
import '../../features/settings/presentation/more_page.dart';
import '../../shared/adaptive/adaptive_shell.dart';
import '../../shared/widgets/feature_placeholder_page.dart';
import '../config/app_environment.dart';
import 'app_route_contract.dart';
import 'app_routes.dart';

typedef ProtectedRouteBuildObserver = void Function(AppRouteContract contract);

final Provider<ProtectedRouteBuildObserver>
protectedRouteBuildObserverProvider = Provider<ProtectedRouteBuildObserver>(
  (Ref ref) => (_) {},
);

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final AppEnvironment environment = ref.watch(appEnvironmentProvider);
  final _RouterRefreshNotifier refreshNotifier = _RouterRefreshNotifier();
  ref.listen<AccessSessionState>(accessSessionProvider, (previous, next) {
    if (previous?.phase != next.phase) {
      refreshNotifier.refresh();
    }
  });
  final GoRouter router = GoRouter(
    initialLocation: environment.initialLocation,
    debugLogDiagnostics: environment.enableRouterDiagnostics,
    refreshListenable: refreshNotifier,
    redirect: (context, state) => _accessRedirect(ref, state),
    routes: <RouteBase>[
      GoRoute(path: '/', redirect: (context, state) => AppRoutes.home),
      ..._routesFor(ref, const <AppArea>{AppArea.access}),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => ProtectedRouteGate(
          builder: (context) => AdaptiveShell(
            location: state.uri.path,
            navigationShell: navigationShell,
          ),
        ),
        branches: <StatefulShellBranch>[
          _branch(ref, AppArea.home, AppRoutes.home),
          _branch(ref, AppArea.missions, AppRoutes.missionsToday),
          _branch(ref, AppArea.journal, AppRoutes.journal),
          _branch(ref, AppArea.finance, AppRoutes.finance),
          _branch(ref, AppArea.dashboard, AppRoutes.dashboardDaily),
          _branch(ref, AppArea.settings, AppRoutes.settings),
          _branch(ref, AppArea.navigation, AppRoutes.more),
        ],
      ),
    ],
    errorBuilder: (context, state) => FeaturePlaceholderPage.error(
      location: state.uri.toString(),
      error: state.error,
    ),
  );

  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });
  return router;
});

StatefulShellBranch _branch(Ref ref, AppArea area, String initialLocation) =>
    StatefulShellBranch(
      initialLocation: initialLocation,
      routes: _routesFor(ref, <AppArea>{area}),
    );

List<GoRoute> _routesFor(Ref ref, Set<AppArea> areas) => AppRoutes.all
    .where((AppRouteContract route) => areas.contains(route.area))
    .map((AppRouteContract route) => _buildRoute(ref, route))
    .toList(growable: false);

GoRoute _buildRoute(Ref ref, AppRouteContract contract) => GoRoute(
  name: contract.name,
  path: contract.path,
  builder: (context, state) {
    if (contract.path == AppRoutes.lock) {
      return const AccessGatePage();
    }
    if (contract.path == AppRoutes.lockRecovery) {
      return const RecoveryPage();
    }
    return ProtectedRouteGate(
      builder: (context) {
        ref.read(protectedRouteBuildObserverProvider)(contract);
        if (contract.path == AppRoutes.more) {
          return const MorePage();
        }
        if (contract.name == 'missionsToday') {
          return const MissionsTodayPage();
        }
        if (contract.name == 'missionNew') {
          return const MissionFormPage();
        }
        if (contract.name == 'missionEdit') {
          return MissionFormPage(missionId: state.pathParameters['missionId']);
        }
        if (contract.name == 'missionDetail') {
          final String? missionId = state.pathParameters['missionId'];
          if (missionId != null) {
            return MissionDetailPage(missionId: missionId);
          }
        }
        if (contract.path == AppRoutes.settings) {
          return const SettingsLandingPage();
        }
        if (contract.path == AppRoutes.settingsPrivacy) {
          return const PrivacySettingsPage();
        }
        if (contract.path == AppRoutes.settingsPrivacyPin) {
          return const ChangePinPage();
        }
        if (contract.path == AppRoutes.settingsPrivacyBiometrics) {
          return const BiometricsSettingsPage();
        }
        return FeaturePlaceholderPage(
          contract: contract,
          location: state.uri.toString(),
        );
      },
    );
  },
);

String? _accessRedirect(Ref ref, GoRouterState state) {
  final AccessSessionState session = ref.read(accessSessionProvider);
  final AccessSessionController controller = ref.read(
    accessSessionProvider.notifier,
  );
  final String path = state.uri.path;
  final bool isLock = path == AppRoutes.lock;
  final bool isRecovery = path == AppRoutes.lockRecovery;
  final bool isPublic = isLock || isRecovery;

  if (!session.canBuildProtected && !isPublic) {
    controller.rememberPendingLocation(state.uri.toString());
  }

  return switch (session.phase) {
    AccessSessionPhase.bootstrapping => isLock ? null : AppRoutes.lock,
    AccessSessionPhase.setupRequired => isLock ? null : AppRoutes.lock,
    AccessSessionPhase.corrupted => isLock ? null : AppRoutes.lock,
    AccessSessionPhase.locked => isPublic ? null : AppRoutes.lock,
    AccessSessionPhase.authenticating => isLock ? null : AppRoutes.lock,
    AccessSessionPhase.recovering => isRecovery ? null : AppRoutes.lockRecovery,
    AccessSessionPhase.unlocked =>
      isPublic ? controller.takePendingLocation() ?? AppRoutes.home : null,
  };
}

final class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
