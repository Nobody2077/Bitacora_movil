import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Un área de vida en el hexágono de PERSONAJE (ADR-006 D3).
final class HexagonArea {
  const HexagonArea({
    required this.name,
    required this.level,
    required this.progress,
  });

  final String name;
  final int level;

  /// Avance dentro del nivel actual, de 0 a 1.
  final double progress;
}

/// Núcleo con el nivel global y de 3 a 8 áreas en círculo, cada una con su
/// nivel y su barra, unidas al núcleo por conectores (maqueta v5).
class CharacterHexagon extends StatelessWidget {
  const CharacterHexagon({
    required this.globalLevel,
    required this.areas,
    required this.cyan,
    required this.red,
    required this.structuralRed,
    required this.yellow,
    required this.track,
    super.key,
    this.text = Colors.white,
  });

  /// Más de ocho no caben con un tamaño legible.
  static const int maxAreas = 8;

  final int globalLevel;
  final List<HexagonArea> areas;
  final Color cyan;
  final Color red;
  final Color structuralRed;
  final Color yellow;
  final Color track;

  /// Números de nivel; sigue el color del texto elegido en Apariencia.
  final Color text;

  @override
  Widget build(BuildContext context) {
    final List<HexagonArea> shown = areas.take(maxAreas).toList();
    return Semantics(
      label:
          'Nivel global $globalLevel. '
          '${shown.map((HexagonArea a) => '${a.name}, nivel ${a.level}').join('. ')}.',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 620 / 560,
          child: CustomPaint(
            painter: _HexagonPainter(
              globalLevel: globalLevel,
              areas: shown,
              cyan: cyan,
              red: red,
              structuralRed: structuralRed,
              yellow: yellow,
              track: track,
              text: text,
            ),
          ),
        ),
      ),
    );
  }
}

class _HexagonPainter extends CustomPainter {
  _HexagonPainter({
    required this.globalLevel,
    required this.areas,
    required this.cyan,
    required this.red,
    required this.structuralRed,
    required this.yellow,
    required this.track,
    required this.text,
  });

  final int globalLevel;
  final List<HexagonArea> areas;
  final Color cyan;
  final Color red;
  final Color structuralRed;
  final Color yellow;
  final Color track;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    // Se dibuja en el lienzo de la maqueta (620×560) y se escala.
    final double scale = size.width / 620;
    canvas.save();
    canvas.scale(scale);
    const Offset center = Offset(310, 280);
    final int count = areas.length;
    final bool dense = count > 5;
    final double orbit = dense ? 205 : 185;
    final double radius = dense ? 52 : 66;

    final Paint connector = Paint()
      ..color = structuralRed
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final List<Offset> positions = <Offset>[
      for (int i = 0; i < count; i++)
        center +
            Offset(
              orbit * math.cos(-math.pi / 2 + i * 2 * math.pi / count),
              orbit * math.sin(-math.pi / 2 + i * 2 * math.pi / count),
            ),
    ];
    for (final Offset position in positions) {
      final Path path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + (position.dx - center.dx) * 0.5, center.dy)
        ..lineTo(position.dx, position.dy);
      canvas.drawPath(path, connector);
    }

    final Path core = _hexagon(center, 78);
    canvas.drawPath(core, Paint()..color = Colors.black);
    canvas.drawPath(
      core,
      Paint()
        ..color = cyan
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    _text(canvas, '$globalLevel', center + const Offset(0, -6), 46, text);
    _text(canvas, 'NIVEL', center + const Offset(0, 26), 15, cyan);

    final Paint areaFill = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[Color(0xFF3A0F16), Color(0xFF120507)],
      ).createShader(Rect.fromCircle(center: center, radius: 300));
    final Paint areaStroke = Paint()
      ..color = red
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < count; i++) {
      final HexagonArea area = areas[i];
      final Offset position = positions[i];
      final Path hex = _hexagon(position, radius);
      canvas.drawPath(hex, areaFill);
      canvas.drawPath(hex, areaStroke);
      _text(
        canvas,
        area.name.toUpperCase(),
        position + Offset(0, -radius * 0.32),
        dense ? 12 : 14,
        cyan,
        maxWidth: radius * 1.6,
      );
      _text(
        canvas,
        '${area.level}',
        position + Offset(0, radius * 0.15),
        dense ? 24 : 30,
        text,
      );
      final double barWidth = radius * 1.1;
      final Rect bar = Rect.fromLTWH(
        position.dx - barWidth / 2,
        position.dy + radius * 0.48,
        barWidth,
        4,
      );
      canvas.drawRect(bar, Paint()..color = track);
      canvas.drawRect(
        Rect.fromLTWH(
          bar.left,
          bar.top,
          barWidth * area.progress.clamp(0.0, 1.0),
          4,
        ),
        Paint()..color = yellow,
      );
    }
    canvas.restore();
  }

  /// Hexágono con vértices arriba y abajo, como en la maqueta.
  static Path _hexagon(Offset center, double radius) {
    final Path path = Path();
    for (int i = 0; i < 6; i++) {
      final double angle = math.pi / 180 * (60 * i - 30);
      final Offset point =
          center + Offset(radius * math.cos(angle), radius * math.sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  void _text(
    Canvas canvas,
    String value,
    Offset center,
    double fontSize,
    Color color, {
    double maxWidth = 300,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
      // El dibujo ya escala con el ancho; ampliar más el texto lo
      // desbordaría de su hexágono. La lectura accesible va por Semantics.
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_HexagonPainter old) =>
      old.globalLevel != globalLevel ||
      old.areas.length != areas.length ||
      !_sameAreas(old.areas, areas) ||
      old.cyan != cyan ||
      old.red != red ||
      old.yellow != yellow ||
      old.track != track ||
      old.text != text;

  static bool _sameAreas(List<HexagonArea> a, List<HexagonArea> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i].name != b[i].name ||
          a[i].level != b[i].level ||
          a[i].progress != b[i].progress) {
        return false;
      }
    }
    return true;
  }
}
