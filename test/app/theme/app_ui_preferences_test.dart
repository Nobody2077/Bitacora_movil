import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme_tokens.dart';
import 'package:bitacora_rpg_personal/app/theme/app_ui_preferences.dart';
import 'package:bitacora_rpg_personal/features/economy/presentation/economy_presentation_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('texto grande establece 1.3x y reducir movimiento es global', (
    WidgetTester tester,
  ) async {
    late double scale;
    late bool disableAnimations;
    late AppUiPreferences inherited;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: AppUiPreferencesBoundary(
          preferences: const AppUiPreferences(
            largeText: true,
            reduceMotion: true,
            highContrast: false,
            hideAmounts: true,
          ),
          child: Builder(
            builder: (BuildContext context) {
              scale = MediaQuery.textScalerOf(context).scale(1);
              disableAnimations = MediaQuery.disableAnimationsOf(context);
              inherited = context.uiPreferences;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(scale, 1.3);
    expect(disableAnimations, isTrue);
    expect(inherited.hideAmounts, isTrue);
  });

  testWidgets('texto grande conserva una escala del sistema de 2.0x', (
    WidgetTester tester,
  ) async {
    late double scale;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: AppUiPreferencesBoundary(
          preferences: const AppUiPreferences(
            largeText: true,
            reduceMotion: false,
            highContrast: false,
            hideAmounts: false,
          ),
          child: Builder(
            builder: (BuildContext context) {
              scale = MediaQuery.textScalerOf(context).scale(1);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(scale, 2);
  });

  testWidgets('ocultar importes evita renderizar el valor monetario', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppUiPreferencesBoundary(
          preferences: const AppUiPreferences(
            largeText: false,
            reduceMotion: false,
            highContrast: false,
            hideAmounts: true,
          ),
          child: Builder(
            builder: (BuildContext context) =>
                Text(economyMoney(context, 12345)),
          ),
        ),
      ),
    );

    expect(find.text('Bs •••'), findsOneWidget);
    expect(find.textContaining('123'), findsNothing);
  });

  test('alto contraste selecciona la paleta reforzada', () {
    final AppThemeTokens tokens = AppTheme.dark(
      highContrast: true,
    ).extension<AppThemeTokens>()!;

    expect(tokens.background, AppThemeTokens.terminalHighContrast.background);
    expect(tokens.border, AppThemeTokens.terminalHighContrast.border);
    expect(tokens.infoCyan, AppThemeTokens.terminalHighContrast.infoCyan);
  });
}
