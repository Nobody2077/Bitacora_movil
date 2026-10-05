import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/access/application/access_session_controller.dart';
import '../../features/access/application/access_session_state.dart';
import '../../features/access/presentation/protected_route_gate.dart';
import '../../features/shop/presentation/wish_affordability_watcher.dart';
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
          builder: (context) => WishAffordabilityWatcher(
            child: AdaptiveShell(
              location: state.uri.path,
              navigationShell: navigationShell,
            ),
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
          _branch(ref, AppArea.character, AppRoutes.character),
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
    // Las rutas de acceso (lock y recuperación) son las superficies públicas
    // que permiten desbloquear la sesión: se construyen fuera del guard.
    if (contract.area == AppArea.access) {
      return _leafFor(contract, context, state);
    }
    return ProtectedRouteGate(
      builder: (context) {
        ref.read(protectedRouteBuildObserverProvider)(contract);
        return _leafFor(contract, context, state);
      },
    );
  },
);

/// Resuelve la hoja de una ruta a partir de su contrato. Si el contrato no
/// declara `builder` (superficie diferida) o su builder devuelve `null` (por
/// ejemplo, falta un parámetro obligatorio), muestra el placeholder.
Widget _leafFor(
  AppRouteContract contract,
  BuildContext context,
  GoRouterState state,
) {
  return contract.builder?.call(context, state) ??
      FeaturePlaceholderPage(
        contract: contract,
        location: state.uri.toString(),
      );
}

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
