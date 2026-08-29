import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';

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
    this.padding = TerminalSpace.panel,
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
              const SizedBox(height: TerminalSpace.xxs),
              Text(
                subtitle.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: tokens.textSecondary,
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
        foregroundColor: tokens.background,
        backgroundColor: tokens.primaryAction,
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

/// Acción irreversible o de seguridad. No usar para el CTA normal de pantalla.
class TerminalCriticalButton extends StatelessWidget {
  const TerminalCriticalButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon = Icons.warning_amber_outlined,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label.toUpperCase()),
      style: FilledButton.styleFrom(
        minimumSize: const Size(144, 52),
        foregroundColor: tokens.textPrimary,
        backgroundColor: tokens.criticalAction,
        disabledBackgroundColor: tokens.border,
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
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: color, size: 24),
        const SizedBox(width: TerminalSpace.xs),
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
                color: tokens.textSecondary,
                fontFamily: 'JetBrains Mono',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TerminalSectionTitle extends StatelessWidget {
  const TerminalSectionTitle({
    required this.title,
    super.key,
    this.overline,
    this.description,
  });

  final String title;
  final String? overline;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (overline != null) ...<Widget>[
          TerminalLabel(overline!, color: tokens.infoCyan),
          const SizedBox(height: TerminalSpace.xs),
        ],
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (description != null) ...<Widget>[
          const SizedBox(height: TerminalSpace.xs),
          Text(
            description!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
        ],
      ],
    );
  }
}

class TerminalLabel extends StatelessWidget {
  const TerminalLabel(this.value, {super.key, this.color});

  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Text(
      value.toUpperCase(),
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: color ?? tokens.valueYellow),
    );
  }
}

class TerminalCard extends StatelessWidget {
  const TerminalCard({
    required this.child,
    super.key,
    this.onTap,
    this.padding = TerminalSpace.panel,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final TerminalCutCornerBorder shape = TerminalCutCornerBorder(
      cut: TerminalRadius.panelCut,
      side: BorderSide(color: borderColor ?? tokens.border),
    );
    return Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: ShapeDecoration(color: tokens.surfaceHigh, shape: shape),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class TerminalDivider extends StatelessWidget {
  const TerminalDivider({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
    this.color,
  });

  final double indent;
  final double endIndent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Divider(
      color: color ?? tokens.border,
      indent: indent,
      endIndent: endIndent,
    );
  }
}

class TerminalProgress extends StatelessWidget {
  const TerminalProgress({
    required this.value,
    super.key,
    this.color,
    this.label,
  });

  final double value;
  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final Color effectiveColor = color ?? tokens.infoCyan;
    final double safeValue = value.clamp(0, 1).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null) ...<Widget>[
          TerminalLabel(label!, color: tokens.textSecondary),
          const SizedBox(height: TerminalSpace.xs),
        ],
        ClipPath(
          clipper: const ShapeBorderClipper(
            shape: TerminalCutCornerBorder(cut: 3),
          ),
          child: LinearProgressIndicator(
            value: safeValue,
            minHeight: 8,
            color: effectiveColor,
            backgroundColor: tokens.border,
          ),
        ),
      ],
    );
  }
}

class TerminalEmptyState extends StatelessWidget {
  const TerminalEmptyState({
    required this.title,
    required this.description,
    super.key,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TerminalSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Semantics(
                container: true,
                liveRegion: true,
                label: '$title. $description',
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, color: tokens.infoCyan, size: 36),
                      const SizedBox(height: TerminalSpace.md),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: TerminalSpace.xs),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (action != null) ...<Widget>[
                const SizedBox(height: TerminalSpace.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TerminalLoadingState extends StatelessWidget {
  const TerminalLoadingState({super.key, this.message = 'Cargando datos…'});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: message,
    child: ExcludeSemantics(
      child: TerminalPanel(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: TerminalSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircularProgressIndicator(),
                const SizedBox(height: TerminalSpace.md),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class TerminalAsyncStatePage extends StatelessWidget {
  const TerminalAsyncStatePage({
    required this.child,
    super.key,
    this.maxWidth = 720,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) =>
        SingleChildScrollView(
          padding: constraints.maxWidth < 700
              ? TerminalSpace.pageCompact
              : TerminalSpace.pageTablet,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ),
  );
}

class TerminalInlineLoadingState extends StatelessWidget {
  const TerminalInlineLoadingState({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: message,
    child: ExcludeSemantics(
      child: Row(
        children: <Widget>[
          const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: TerminalSpace.sm),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class TerminalInlineErrorState extends StatelessWidget {
  const TerminalInlineErrorState({
    required this.message,
    super.key,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          container: true,
          liveRegion: true,
          label: message,
          child: ExcludeSemantics(
            child: Row(
              children: <Widget>[
                Icon(Icons.error_outline, color: tokens.criticalAction),
                const SizedBox(width: TerminalSpace.xs),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        ),
        if (onRetry != null)
          Padding(
            padding: const EdgeInsets.only(top: TerminalSpace.sm),
            child: TerminalOutlineButton(
              label: 'Reintentar',
              icon: Icons.refresh,
              color: tokens.infoCyan,
              onPressed: onRetry,
            ),
          ),
      ],
    );
  }
}

class TerminalErrorState extends StatelessWidget {
  const TerminalErrorState({
    required this.title,
    required this.description,
    super.key,
    this.onRetry,
    this.retryLabel = 'Reintentar',
    this.retryButtonKey,
  });

  final String title;
  final String description;
  final VoidCallback? onRetry;
  final String retryLabel;
  final Key? retryButtonKey;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      borderColor: tokens.criticalAction,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TerminalSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Semantics(
                container: true,
                liveRegion: true,
                label: '$title. $description',
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.error_outline,
                        color: tokens.criticalAction,
                        size: 40,
                      ),
                      const SizedBox(height: TerminalSpace.sm),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: TerminalSpace.xs),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: TerminalSpace.lg),
                TerminalOutlineButton(
                  key: retryButtonKey,
                  label: retryLabel,
                  icon: Icons.refresh,
                  color: tokens.infoCyan,
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
