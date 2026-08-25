import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_routes.dart';

enum AppFlavor { development, production }

class AppEnvironment {
  const AppEnvironment({
    required this.flavor,
    required this.appName,
    required this.enableRouterDiagnostics,
    this.initialLocation = AppRoutes.home,
  });

  static const AppEnvironment development = AppEnvironment(
    flavor: AppFlavor.development,
    appName: 'Bitácora RPG DEV',
    enableRouterDiagnostics: true,
  );

  static const AppEnvironment production = AppEnvironment(
    flavor: AppFlavor.production,
    appName: 'Bitácora RPG Personal',
    enableRouterDiagnostics: false,
  );

  final AppFlavor flavor;
  final String appName;
  final bool enableRouterDiagnostics;
  final String initialLocation;
}

final Provider<AppEnvironment> appEnvironmentProvider =
    Provider<AppEnvironment>(
      (Ref ref) => throw StateError(
        'AppEnvironment debe inyectarse en el ProviderScope raíz.',
      ),
    );
