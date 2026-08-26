import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';

final class TerminalCutCornerBorder extends OutlinedBorder {
  const TerminalCutCornerBorder({super.side = BorderSide.none, this.cut = 12});

  final double cut;

  @override
  TerminalCutCornerBorder copyWith({BorderSide? side}) =>
      TerminalCutCornerBorder(side: side ?? this.side, cut: cut);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _buildPath(rect.deflate(side.width), cut - side.width);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _buildPath(rect, cut);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) {
      return;
    }
    canvas.drawPath(
      getOuterPath(rect, textDirection: textDirection),
      Paint()
        ..color = side.color
        ..strokeWidth = side.width
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  ShapeBorder scale(double t) =>
      TerminalCutCornerBorder(side: side.scale(t), cut: cut * t);

  static Path _buildPath(Rect rect, double requestedCut) {
    final double safeCut = requestedCut
        .clamp(0, rect.shortestSide / 2)
        .toDouble();
    return Path()
      ..moveTo(rect.left + safeCut, rect.top)
      ..lineTo(rect.right - safeCut, rect.top)
      ..lineTo(rect.right, rect.top + safeCut)
      ..lineTo(rect.right, rect.bottom - safeCut)
      ..lineTo(rect.right - safeCut, rect.bottom)
      ..lineTo(rect.left + safeCut, rect.bottom)
      ..lineTo(rect.left, rect.bottom - safeCut)
      ..lineTo(rect.left, rect.top + safeCut)
      ..close();
  }
}

class TerminalPanel extends StatelessWidget {
  const TerminalPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.borderColor,
    this.backgroundColor,
    this.cut = 14,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? backgroundColor;
  final double cut;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: backgroundColor ?? tokens.surfaceLow,
        shape: TerminalCutCornerBorder(
          cut: cut,
          side: BorderSide(color: borderColor ?? tokens.border),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class TerminalPageHeader extends StatelessWidget {
  const TerminalPageHeader({
    required this.title,
    required this.subtitle,
    super.key,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: tokens.infoCyan,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white60,
                  fontFamily: 'JetBrains Mono',
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        if (action != null) ...<Widget>[const SizedBox(width: 16), action!],
      ],
    );
  }
}

class TerminalPrimaryButton extends StatelessWidget {
  const TerminalPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final Widget button = FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward),
      label: Text(label.toUpperCase()),
      style: FilledButton.styleFrom(
        minimumSize: const Size(144, 52),
        foregroundColor: Colors.black,
        backgroundColor: tokens.infoCyan,
        disabledBackgroundColor: tokens.border,
        textStyle: const TextStyle(
          fontFamily: 'Rajdhani',
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        shape: const TerminalCutCornerBorder(cut: 10),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class TerminalOutlineButton extends StatelessWidget {
  const TerminalOutlineButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final Color effectiveColor = color ?? tokens.terminalRed;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.add),
      label: Text(label.toUpperCase()),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(144, 52),
        foregroundColor: effectiveColor,
        side: BorderSide(color: effectiveColor),
        textStyle: const TextStyle(
          fontFamily: 'Rajdhani',
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        shape: const TerminalCutCornerBorder(cut: 10),
      ),
    );
  }
}

class TerminalBadge extends StatelessWidget {
  const TerminalBadge({
    required this.label,
    required this.color,
    super.key,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: color.withValues(alpha: 0.08),
      shape: TerminalCutCornerBorder(
        cut: 6,
        side: BorderSide(color: color.withValues(alpha: 0.8)),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class TerminalMetric extends StatelessWidget {
  const TerminalMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(icon, color: color, size: 24),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontFamily: 'JetBrains Mono',
            ),
          ),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white54,
              fontFamily: 'JetBrains Mono',
            ),
          ),
        ],
      ),
    ],
  );
}
