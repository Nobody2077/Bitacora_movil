import 'package:flutter/material.dart';

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.background,
    required this.surfaceLow,
    required this.surfaceHigh,
    required this.surfaceOverlay,
    required this.border,
    required this.borderFocused,
    required this.terminalRed,
    required this.criticalAction,
    required this.structuralRed,
    required this.infoCyan,
    required this.primaryAction,
    required this.valueYellow,
    required this.progressGreen,
    required this.attentionOrange,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
  });

  static const AppThemeTokens terminal = AppThemeTokens(
    background: Color(0xFF08090D),
    surfaceLow: Color(0xFF11151C),
    surfaceHigh: Color(0xFF171D25),
    surfaceOverlay: Color(0xFF202833),
    border: Color(0xFF2A3340),
    borderFocused: Color(0xFF55E6E6),
    terminalRed: Color(0xFFFF3B3B),
    criticalAction: Color(0xFFD00000),
    structuralRed: Color(0xFF7A2631),
    infoCyan: Color(0xFF55E6E6),
    primaryAction: Color(0xFF1EC2C6),
    valueYellow: Color(0xFFF5D547),
    progressGreen: Color(0xFF45D483),
    attentionOrange: Color(0xFFFF9F43),
    textPrimary: Color(0xFFF4F7FA),
    textSecondary: Color(0xFFB6C0CD),
    textDisabled: Color(0xFF657080),
  );

  static const AppThemeTokens terminalHighContrast = AppThemeTokens(
    background: Color(0xFF000000),
    surfaceLow: Color(0xFF080A0D),
    surfaceHigh: Color(0xFF10141A),
    surfaceOverlay: Color(0xFF18202A),
    border: Color(0xFFA7B5C5),
    borderFocused: Color(0xFF80FFFF),
    terminalRed: Color(0xFFFF6B6B),
    criticalAction: Color(0xFFFF4D4D),
    structuralRed: Color(0xFFB74655),
    infoCyan: Color(0xFF80FFFF),
    primaryAction: Color(0xFF4DE7EA),
    valueYellow: Color(0xFFFFE66D),
    progressGreen: Color(0xFF66F2A3),
    attentionOrange: Color(0xFFFFB86B),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFE2E8F0),
    textDisabled: Color(0xFFA0AEC0),
  );

  final Color background;
  final Color surfaceLow;
  final Color surfaceHigh;
  final Color surfaceOverlay;
  final Color border;
  final Color borderFocused;
  final Color terminalRed;
  final Color criticalAction;
  final Color structuralRed;
  final Color infoCyan;
  final Color primaryAction;
  final Color valueYellow;
  final Color progressGreen;
  final Color attentionOrange;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  @override
  AppThemeTokens copyWith({
    Color? background,
    Color? surfaceLow,
    Color? surfaceHigh,
    Color? surfaceOverlay,
    Color? border,
    Color? borderFocused,
    Color? terminalRed,
    Color? criticalAction,
    Color? structuralRed,
    Color? infoCyan,
    Color? primaryAction,
    Color? valueYellow,
    Color? progressGreen,
    Color? attentionOrange,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
  }) => AppThemeTokens(
    background: background ?? this.background,
    surfaceLow: surfaceLow ?? this.surfaceLow,
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
    border: border ?? this.border,
    borderFocused: borderFocused ?? this.borderFocused,
    terminalRed: terminalRed ?? this.terminalRed,
    criticalAction: criticalAction ?? this.criticalAction,
    structuralRed: structuralRed ?? this.structuralRed,
    infoCyan: infoCyan ?? this.infoCyan,
    primaryAction: primaryAction ?? this.primaryAction,
    valueYellow: valueYellow ?? this.valueYellow,
    progressGreen: progressGreen ?? this.progressGreen,
    attentionOrange: attentionOrange ?? this.attentionOrange,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textDisabled: textDisabled ?? this.textDisabled,
  );

  @override
  AppThemeTokens lerp(AppThemeTokens? other, double t) {
    if (other is! AppThemeTokens) {
      return this;
    }

    return AppThemeTokens(
      background: Color.lerp(background, other.background, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceOverlay: Color.lerp(surfaceOverlay, other.surfaceOverlay, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderFocused: Color.lerp(borderFocused, other.borderFocused, t)!,
      terminalRed: Color.lerp(terminalRed, other.terminalRed, t)!,
      criticalAction: Color.lerp(criticalAction, other.criticalAction, t)!,
      structuralRed: Color.lerp(structuralRed, other.structuralRed, t)!,
      infoCyan: Color.lerp(infoCyan, other.infoCyan, t)!,
      primaryAction: Color.lerp(primaryAction, other.primaryAction, t)!,
      valueYellow: Color.lerp(valueYellow, other.valueYellow, t)!,
      progressGreen: Color.lerp(progressGreen, other.progressGreen, t)!,
      attentionOrange: Color.lerp(attentionOrange, other.attentionOrange, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
    );
  }
}
