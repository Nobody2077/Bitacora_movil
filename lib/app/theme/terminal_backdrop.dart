import 'package:flutter/material.dart';

/// Fondo de las pantallas: negro liso o el Vino de la maqueta (ADR-006 D13).
@immutable
class TerminalBackdropTheme extends ThemeExtension<TerminalBackdropTheme> {
  const TerminalBackdropTheme({required this.wine});

  static const TerminalBackdropTheme black = TerminalBackdropTheme(wine: false);

  /// Degradado de arriba abajo de la maqueta: vino oscuro a negro.
  static const Color wineTop = Color(0xFF2A0E12);
  static const Color wineMiddle = Color(0xFF0A0405);
  static const Color scanline = Color(0x09FF3B3B);

  final bool wine;

  @override
  TerminalBackdropTheme copyWith({bool? wine}) =>
      TerminalBackdropTheme(wine: wine ?? this.wine);

  @override
  TerminalBackdropTheme lerp(TerminalBackdropTheme? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// Pinta el fondo detrás del contenido del shell. En Vino, el degradado y,
/// salvo con movimiento reducido, las líneas de barrido.
class TerminalBackdrop extends StatelessWidget {
  const TerminalBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TerminalBackdropTheme backdrop =
        Theme.of(context).extension<TerminalBackdropTheme>() ??
        TerminalBackdropTheme.black;
    if (!backdrop.wine) {
      return ColoredBox(
        key: const Key('backdrop-black'),
        color: Colors.black,
        child: child,
      );
    }
    final bool scanlines = !MediaQuery.disableAnimationsOf(context);
    return DecoratedBox(
      key: const Key('backdrop-wine'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            TerminalBackdropTheme.wineTop,
            TerminalBackdropTheme.wineMiddle,
            Colors.black,
          ],
          stops: <double>[0, 0.7, 1],
        ),
      ),
      child: scanlines
          ? CustomPaint(
              key: const Key('backdrop-scanlines'),
              foregroundPainter: const _ScanlinePainter(),
              child: child,
            )
          : child,
    );
  }
}

/// Una línea de 1 px cada 4 px, casi invisible, encima del contenido y sin
/// recibir toques.
class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()..color = TerminalBackdropTheme.scanline;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter oldDelegate) => false;
}
