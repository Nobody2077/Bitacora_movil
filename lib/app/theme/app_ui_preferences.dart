import 'package:flutter/material.dart';

@immutable
final class AppUiPreferences {
  const AppUiPreferences({
    required this.largeText,
    required this.reduceMotion,
    required this.highContrast,
    required this.hideAmounts,
  });

  const AppUiPreferences.defaults()
    : largeText = false,
      reduceMotion = false,
      highContrast = false,
      hideAmounts = false;

  final bool largeText;
  final bool reduceMotion;
  final bool highContrast;
  final bool hideAmounts;
}

class AppUiPreferencesBoundary extends StatelessWidget {
  const AppUiPreferencesBoundary({
    required this.preferences,
    required this.child,
    super.key,
  });

  final AppUiPreferences preferences;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double currentScale = media.textScaler.scale(1);
    final TextScaler textScaler = preferences.largeText && currentScale < 1.3
        ? const TextScaler.linear(1.3)
        : media.textScaler;
    return MediaQuery(
      data: media.copyWith(
        textScaler: textScaler,
        disableAnimations: media.disableAnimations || preferences.reduceMotion,
      ),
      child: _AppUiPreferencesScope(preferences: preferences, child: child),
    );
  }
}

class _AppUiPreferencesScope extends InheritedWidget {
  const _AppUiPreferencesScope({
    required this.preferences,
    required super.child,
  });

  final AppUiPreferences preferences;

  @override
  bool updateShouldNotify(_AppUiPreferencesScope oldWidget) =>
      preferences.largeText != oldWidget.preferences.largeText ||
      preferences.reduceMotion != oldWidget.preferences.reduceMotion ||
      preferences.highContrast != oldWidget.preferences.highContrast ||
      preferences.hideAmounts != oldWidget.preferences.hideAmounts;
}

extension AppUiPreferencesContext on BuildContext {
  AppUiPreferences get uiPreferences =>
      dependOnInheritedWidgetOfExactType<_AppUiPreferencesScope>()
          ?.preferences ??
      const AppUiPreferences.defaults();
}
