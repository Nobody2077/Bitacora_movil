import 'package:flutter/material.dart';

import 'app_theme_tokens.dart';
import 'terminal_backdrop.dart';
import 'terminal_foundations.dart';

abstract final class AppTheme {
  /// [wine] y [cyanText] vienen de Apariencia (ADR-006 D13); alto contraste
  /// los anula.
  static ThemeData dark({
    bool highContrast = false,
    bool wine = false,
    bool cyanText = false,
  }) {
    final AppThemeTokens tokens = AppThemeTokens.resolve(
      highContrast: highContrast,
      wine: wine,
      cyanText: cyanText,
    );
    final bool wineBackdrop = wine && !highContrast;
    final ColorScheme colors = ColorScheme.dark(
      primary: tokens.infoCyan,
      onPrimary: tokens.background,
      secondary: tokens.terminalRed,
      onSecondary: tokens.textPrimary,
      tertiary: tokens.valueYellow,
      onTertiary: tokens.background,
      // Menús, hojas y diálogos siempre opacos, también en Vino.
      surface: tokens.surfaceOverlay,
      onSurface: tokens.textPrimary,
      error: tokens.attentionOrange,
      onError: tokens.background,
      outline: tokens.border,
    );
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colors,
      // En Vino, las páginas dejan ver el degradado que pinta el shell.
      scaffoldBackgroundColor: wineBackdrop
          ? Colors.transparent
          : tokens.background,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,
    );
    final TextTheme body = base.textTheme.apply(
      fontFamily: 'Inter',
      bodyColor: tokens.textPrimary,
      displayColor: tokens.textPrimary,
    );
    final TextTheme textTheme = body.copyWith(
      displayLarge: _terminalHeading(body.displayLarge),
      displayMedium: _terminalHeading(body.displayMedium),
      headlineLarge: _terminalHeading(body.headlineLarge),
      headlineMedium: _terminalHeading(body.headlineMedium),
      headlineSmall: _terminalHeading(body.headlineSmall),
      titleLarge: _terminalHeading(body.titleLarge),
      titleMedium: _terminalHeading(body.titleMedium),
      labelLarge: body.labelLarge?.copyWith(
        fontFamily: 'JetBrains Mono',
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
      labelMedium: body.labelMedium?.copyWith(
        fontFamily: 'JetBrains Mono',
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
      labelSmall: body.labelSmall?.copyWith(
        fontFamily: 'JetBrains Mono',
        letterSpacing: 0.5,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[
        tokens,
        TerminalBackdropTheme(wine: wineBackdrop),
      ],
      focusColor: tokens.borderFocused,
      dividerColor: tokens.border,
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: tokens.infoCyan,
          letterSpacing: 1,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surfaceHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: tokens.border),
          borderRadius: BorderRadius.circular(TerminalRadius.control),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surfaceLow,
        indicatorColor: tokens.structuralRed,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
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
      inputDecorationTheme: _inputTheme(tokens),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(144, 48),
          foregroundColor: tokens.background,
          backgroundColor: tokens.primaryAction,
          disabledForegroundColor: tokens.textDisabled,
          disabledBackgroundColor: tokens.border,
          textStyle: const TextStyle(
            fontFamily: 'Rajdhani',
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(144, 48),
          foregroundColor: tokens.terminalRed,
          side: BorderSide(color: tokens.terminalRed),
          textStyle: const TextStyle(
            fontFamily: 'Rajdhani',
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.infoCyan,
          textStyle: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: tokens.surfaceOverlay),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surfaceOverlay,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceOverlay,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: tokens.border),
          borderRadius: BorderRadius.circular(TerminalRadius.control),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.surfaceOverlay,
        contentTextStyle: TextStyle(color: tokens.textPrimary),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: tokens.border),
          borderRadius: BorderRadius.circular(TerminalRadius.control),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.infoCyan,
        linearTrackColor: tokens.border,
      ),
    );
  }

  static TextStyle? _terminalHeading(TextStyle? source) => source?.copyWith(
    fontFamily: 'Rajdhani',
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );

  static InputDecorationTheme _inputTheme(AppThemeTokens tokens) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderSide: BorderSide(color: color, width: width),
          borderRadius: BorderRadius.circular(TerminalRadius.control),
        );
    return InputDecorationTheme(
      filled: true,
      fillColor: tokens.surfaceHigh,
      labelStyle: TextStyle(
        color: tokens.textSecondary,
        fontFamily: 'JetBrains Mono',
        fontSize: 13,
      ),
      floatingLabelStyle: TextStyle(
        color: tokens.infoCyan,
        fontFamily: 'JetBrains Mono',
        fontWeight: FontWeight.w700,
      ),
      border: border(tokens.border),
      enabledBorder: border(tokens.border),
      focusedBorder: border(tokens.borderFocused, 1.5),
      errorBorder: border(tokens.terminalRed),
      focusedErrorBorder: border(tokens.attentionOrange, 1.5),
    );
  }
}
