import 'package:flutter/material.dart';

import 'app_theme_tokens.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    const AppThemeTokens tokens = AppThemeTokens.terminal;
    final ColorScheme colors = ColorScheme.fromSeed(
      seedColor: tokens.terminalRed,
      brightness: Brightness.dark,
      primary: tokens.terminalRed,
      secondary: tokens.infoCyan,
      tertiary: tokens.valueYellow,
      surface: tokens.surfaceLow,
      error: tokens.attentionOrange,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colors,
      scaffoldBackgroundColor: tokens.background,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    final TextTheme body = base.textTheme.apply(
      fontFamily: 'Inter',
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    );
    final TextTheme textTheme = body.copyWith(
      displayLarge: body.displayLarge?.copyWith(
        fontFamily: 'Rajdhani',
        fontWeight: FontWeight.w700,
      ),
      displayMedium: body.displayMedium?.copyWith(
        fontFamily: 'Rajdhani',
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: body.headlineLarge?.copyWith(
        fontFamily: 'Rajdhani',
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: body.headlineMedium?.copyWith(
        fontFamily: 'Rajdhani',
        fontWeight: FontWeight.w700,
      ),
      titleLarge: body.titleLarge?.copyWith(
        fontFamily: 'Rajdhani',
        fontWeight: FontWeight.w700,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      extensions: const <ThemeExtension<dynamic>>[tokens],
      focusColor: tokens.infoCyan,
      dividerColor: tokens.border,
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: colors.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: tokens.surfaceLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: tokens.border),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surfaceLow,
        indicatorColor: tokens.structuralRed,
        height: 72,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.surfaceLow,
        indicatorColor: tokens.structuralRed,
        selectedIconTheme: IconThemeData(color: tokens.infoCyan),
        selectedLabelTextStyle: TextStyle(
          color: tokens.infoCyan,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceHigh,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: tokens.infoCyan, width: 2),
        ),
      ),
    );
  }
}
