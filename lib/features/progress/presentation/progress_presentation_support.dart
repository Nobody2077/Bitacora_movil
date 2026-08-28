import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../domain/models/progress_models.dart';
import '../domain/models/rpg_level.dart';

class ProgressPageFrame extends StatelessWidget {
  const ProgressPageFrame({
    required this.child,
    required this.currentRouteName,
    super.key,
    this.onRefresh,
  });

  final Widget child;
  final String currentRouteName;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 700;
    return ListView(
      padding: compact ? TerminalSpace.pageCompact : TerminalSpace.pageTablet,
      children: <Widget>[
        TerminalPageHeader(
          title: 'Progreso y Dashboards',
          subtitle: 'Métricas operativas, nivel RPG y balance de vida',
          action: onRefresh == null
              ? null
              : TerminalOutlineButton(
                  label: 'Actualizar',
                  icon: Icons.refresh,
                  onPressed: onRefresh,
                ),
        ),
        const SizedBox(height: TerminalSpace.md),
        _DashboardNavigationTabs(currentRouteName: currentRouteName),
        const SizedBox(height: TerminalSpace.md),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _DashboardNavigationTabs extends StatelessWidget {
  const _DashboardNavigationTabs({required this.currentRouteName});

  final String currentRouteName;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _tabButton(
          context: context,
          tokens: tokens,
          label: 'Diario',
          icon: Icons.view_day_outlined,
          routeName: 'dashboardDaily',
          isSelected: currentRouteName == 'dashboardDaily',
        ),
        _tabButton(
          context: context,
          tokens: tokens,
          label: 'Semanal',
          icon: Icons.view_week_outlined,
          routeName: 'dashboardWeekly',
          isSelected: currentRouteName == 'dashboardWeekly',
        ),
        _tabButton(
          context: context,
          tokens: tokens,
          label: 'Nivel RPG',
          icon: Icons.military_tech_outlined,
          routeName: 'dashboardProgress',
          isSelected: currentRouteName == 'dashboardProgress',
        ),
      ],
    );
  }

  Widget _tabButton({
    required BuildContext context,
    required AppThemeTokens tokens,
    required String label,
    required IconData icon,
    required String routeName,
    required bool isSelected,
  }) {
    if (isSelected) {
      return TerminalPrimaryButton(label: label, icon: icon, onPressed: () {});
    }
    return TerminalOutlineButton(
      label: label,
      icon: icon,
      color: tokens.textSecondary,
      onPressed: () => context.goNamed(routeName),
    );
  }
}

class RpgLevelCard extends StatelessWidget {
  const RpgLevelCard({required this.level, super.key});

  final RpgLevel level;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      borderColor: tokens.infoCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: tokens.surfaceHigh,
                  border: Border.all(color: tokens.infoCyan, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'LVL',
                        style: TextStyle(
                          color: tokens.infoCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        '${level.level}',
                        style: TextStyle(
                          color: tokens.progressGreen,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Nivel ${level.level}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: tokens.textPrimary,
                              ),
                        ),
                        Text(
                          '${level.currentLevelXp} / ${level.levelSpan} XP (${level.progressPercentage}%)',
                          style: TextStyle(
                            color: tokens.infoCyan,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: level.progressRatio,
                        minHeight: 10,
                        backgroundColor: tokens.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          tokens.progressGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Faltan ${level.xpToNextLevel} XP para el nivel ${level.level + 1} · Total acumulado: ${level.effectiveXp} XP',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AreaDistributionList extends StatelessWidget {
  const AreaDistributionList({required this.items, super.key});

  final List<AreaProgressItem> items;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    if (items.isEmpty) {
      return TerminalEmptyState(
        title: 'Sin datos por área',
        description:
            'Aún no se ha registrado experiencia en ninguna área de vida.',
        icon: Icons.pie_chart_outline,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final AreaProgressItem item in items) ...<Widget>[
          _AreaProgressTile(item: item, tokens: tokens),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AreaProgressTile extends StatelessWidget {
  const _AreaProgressTile({required this.item, required this.tokens});

  final AreaProgressItem item;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final Color areaColor = _parseColor(item.colorHex, tokens.infoCyan);
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: areaColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.areaName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              Text(
                'Nivel ${item.rpgLevel.level} · ${item.amount} XP '
                '(${item.percentage.toStringAsFixed(1)}%)',
                style: TextStyle(
                  color: areaColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (item.percentage / 100.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: tokens.border,
              valueColor: AlwaysStoppedAnimation<Color>(areaColor),
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex, Color fallback) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('0xFF$clean'));
      }
    } catch (_) {}
    return fallback;
  }
}
