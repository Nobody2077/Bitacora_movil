import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/access/presentation/privacy_boundary.dart';
import '../features/settings/domain/models/app_preferences.dart';
import 'config/app_environment.dart';
import 'providers/app_preferences_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/app_ui_preferences.dart';

class BitacoraApp extends ConsumerWidget {
  const BitacoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppEnvironment environment = ref.watch(appEnvironmentProvider);
    final router = ref.watch(appRouterProvider);
    final AppPreferences preferences =
        ref.watch(appPreferencesProvider).value ?? AppPreferences.defaults;
    final AppUiPreferences uiPreferences = AppUiPreferences(
      largeText: preferences.largeText,
      reduceMotion: preferences.reduceMotion,
      highContrast: preferences.highContrast,
      hideAmounts: preferences.hideAmounts,
    );

    return MaterialApp.router(
      title: environment.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const <Locale>[Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.dark(highContrast: uiPreferences.highContrast),
      routerConfig: router,
      builder: (context, child) => AppUiPreferencesBoundary(
        preferences: uiPreferences,
        child: AppPrivacyBoundary(
          allowScreenshots: preferences.allowScreenshots,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
