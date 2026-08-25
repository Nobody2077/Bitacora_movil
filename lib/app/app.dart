import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/access/presentation/privacy_boundary.dart';
import 'config/app_environment.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class BitacoraApp extends ConsumerWidget {
  const BitacoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppEnvironment environment = ref.watch(appEnvironmentProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: environment.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const <Locale>[Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.dark(),
      routerConfig: router,
      builder: (context, child) =>
          AppPrivacyBoundary(child: child ?? const SizedBox.shrink()),
    );
  }
}
