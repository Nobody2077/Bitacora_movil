import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/progress_providers.dart';
import '../domain/models/progress_models.dart';
import '../domain/models/rpg_level.dart';
import 'progress_presentation_support.dart';

class DashboardProgressPage extends ConsumerWidget {
  const DashboardProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final AsyncValue<OverallProgressViewData> overallData = ref.watch(
      overallProgressProvider,
    );

    return ProgressPageFrame(
      currentRouteName: 'dashboardProgress',
      onRefresh: () => ref.invalidate(overallProgressProvider),
      child: overallData.when(
        data: (OverallProgressViewData data) =>
            _ProgressContent(data: data, tokens: tokens),
        loading: () => const TerminalPanel(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
        error: (_, _) => TerminalEmptyState(
          title: 'No se pudo cargar el progreso',
          description: 'Ocurrió un error al calcular los datos RPG.',
          icon: Icons.error_outline,
          action: TerminalOutlineButton(
            label: 'Reintentar',
            icon: Icons.refresh,
            onPressed: () => ref.invalidate(overallProgressProvider),
          ),
        ),
      ),
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({required this.data, required this.tokens});

  final OverallProgressViewData data;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final RpgLevel level = data.rpgLevel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RpgLevelCard(level: level),
        const SizedBox(height: TerminalSpace.md),
        TerminalPanel(
          borderColor: tokens.structuralRed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const TerminalSectionTitle(
                overline: 'Perfil del Aventurero',
                title: 'Estadísticas globales',
              ),
              const SizedBox(height: TerminalSpace.md),
              Wrap(
                spacing: 32,
                runSpacing: 18,
                children: <Widget>[
                  TerminalMetric(
                    icon: Icons.star_outline,
                    value: '${data.totalXp} XP',
                    label: 'XP Total',
                    color: tokens.progressGreen,
                  ),
                  TerminalMetric(
                    icon: Icons.today_outlined,
                    value: '+${data.todayXp} XP',
                    label: 'XP Hoy',
                    color: data.todayXp > 0
                        ? tokens.progressGreen
                        : tokens.infoCyan,
                  ),
                  TerminalMetric(
                    icon: Icons.date_range_outlined,
                    value: '+${data.weekXp} XP',
                    label: 'XP Esta Semana',
                    color: data.weekXp > 0
                        ? tokens.progressGreen
                        : tokens.infoCyan,
                  ),
                  TerminalMetric(
                    icon: Icons.trending_up,
                    value: '${level.currentLevelXp} / ${level.levelSpan}',
                    label: 'Progreso nivel',
                    color: tokens.valueYellow,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: TerminalSpace.md),
        const TerminalSectionTitle(
          overline: 'Balance RPG',
          title: 'Experiencia histórica por área',
          description: 'Distribución acumulada de todo tu recorrido.',
        ),
        const SizedBox(height: TerminalSpace.sm),
        AreaDistributionList(items: data.areaBreakdown),
      ],
    );
  }
}
