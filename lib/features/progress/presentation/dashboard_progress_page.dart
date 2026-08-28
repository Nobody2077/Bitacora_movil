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
                  TerminalMetric(
                    icon: Icons.local_fire_department_outlined,
                    value: '${data.currentStreak} días',
                    label: 'Racha activa',
                    color: tokens.attentionOrange,
                  ),
                  TerminalMetric(
                    icon: Icons.emoji_events_outlined,
                    value: '${data.bestStreak} días',
                    label: 'Mejor racha',
                    color: tokens.valueYellow,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: TerminalSpace.md),
        const TerminalSectionTitle(
          overline: 'Reconocimientos',
          title: 'Títulos vigentes',
          description:
              'Los permanentes quedan ganados; los dinámicos pueden activarse de nuevo.',
        ),
        const SizedBox(height: TerminalSpace.sm),
        if (data.activeTitles.isEmpty)
          const TerminalEmptyState(
            title: 'Sin títulos vigentes',
            description:
                'Completa misiones y mantén tu racha para desbloquearlos.',
            icon: Icons.military_tech_outlined,
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              for (final TitleProgressItem title in data.activeTitles)
                _TitleCard(title: title, tokens: tokens),
            ],
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

class _TitleCard extends StatelessWidget {
  const _TitleCard({required this.title, required this.tokens});

  final TitleProgressItem title;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final bool permanent = title.kind == ProgressTitleKind.permanent;
    final Color accent = permanent ? tokens.valueYellow : tokens.infoCyan;
    final String kindLabel = switch (title.kind) {
      ProgressTitleKind.permanent => 'PERMANENTE',
      ProgressTitleKind.dynamic => 'DINÁMICO',
      ProgressTitleKind.temporary => 'TEMPORAL',
    };
    final String statusLabel = switch (title.status) {
      ProgressTitleStatus.active => 'ACTIVO',
      ProgressTitleStatus.earned => 'GANADO',
    };
    return SizedBox(
      width: 320,
      child: TerminalCard(
        borderColor: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.military_tech_outlined, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (title.description != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                title.description!,
                style: TextStyle(color: tokens.textSecondary, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '$kindLabel · $statusLabel'
              '${permanent ? '' : ' · Mejor racha: ${title.bestStreak}'}',
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
            if (title.recoveryCount > 0) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'Recuperado ${title.recoveryCount} vez${title.recoveryCount == 1 ? '' : 'es'}',
                style: TextStyle(color: tokens.textSecondary, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
