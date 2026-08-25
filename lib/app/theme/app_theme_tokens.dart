import 'package:flutter/material.dart';

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.background,
    required this.surfaceLow,
    required this.surfaceHigh,
    required this.border,
    required this.terminalRed,
    required this.structuralRed,
    required this.infoCyan,
    required this.valueYellow,
    required this.progressGreen,
    required this.attentionOrange,
  });

  static const AppThemeTokens terminal = AppThemeTokens(
    background: Color(0xFF08090D),
    surfaceLow: Color(0xFF11151C),
    surfaceHigh: Color(0xFF171D25),
    border: Color(0xFF2A3340),
    terminalRed: Color(0xFFFF3B3B),
    structuralRed: Color(0xFF7A2631),
    infoCyan: Color(0xFF55E6E6),
    valueYellow: Color(0xFFF5D547),
    progressGreen: Color(0xFF45D483),
    attentionOrange: Color(0xFFFF9F43),
  );

  final Color background;
  final Color surfaceLow;
  final Color surfaceHigh;
  final Color border;
  final Color terminalRed;
  final Color structuralRed;
  final Color infoCyan;
  final Color valueYellow;
  final Color progressGreen;
  final Color attentionOrange;

  @override
  AppThemeTokens copyWith({
    Color? background,
    Color? surfaceLow,
    Color? surfaceHigh,
    Color? border,
    Color? terminalRed,
    Color? structuralRed,
    Color? infoCyan,
    Color? valueYellow,
    Color? progressGreen,
    Color? attentionOrange,
  }) => AppThemeTokens(
    background: background ?? this.background,
    surfaceLow: surfaceLow ?? this.surfaceLow,
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    border: border ?? this.border,
    terminalRed: terminalRed ?? this.terminalRed,
    structuralRed: structuralRed ?? this.structuralRed,
    infoCyan: infoCyan ?? this.infoCyan,
    valueYellow: valueYellow ?? this.valueYellow,
    progressGreen: progressGreen ?? this.progressGreen,
    attentionOrange: attentionOrange ?? this.attentionOrange,
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
      border: Color.lerp(border, other.border, t)!,
      terminalRed: Color.lerp(terminalRed, other.terminalRed, t)!,
      structuralRed: Color.lerp(structuralRed, other.structuralRed, t)!,
      infoCyan: Color.lerp(infoCyan, other.infoCyan, t)!,
      valueYellow: Color.lerp(valueYellow, other.valueYellow, t)!,
      progressGreen: Color.lerp(progressGreen, other.progressGreen, t)!,
      attentionOrange: Color.lerp(attentionOrange, other.attentionOrange, t)!,
    );
  }
}
