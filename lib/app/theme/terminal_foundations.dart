import 'package:flutter/material.dart';

/// Valores no cromáticos del sistema visual Terminal V2.
///
/// Mantenerlos aquí evita que cada pantalla invente sus propios espacios,
/// radios y velocidades de interacción.
abstract final class TerminalSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const EdgeInsets pageCompact = EdgeInsets.all(md);
  static const EdgeInsets pageTablet = EdgeInsets.all(28);
  static const EdgeInsets panel = EdgeInsets.all(lg);
}

abstract final class TerminalRadius {
  static const double control = 8;
  static const double panelCut = 14;
  static const double cardCut = 18;
}

abstract final class TerminalMotion {
  static const Duration quick = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 180);
  static const Duration deliberate = Duration(milliseconds: 240);

  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
