import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../economy/presentation/economy_presentation_support.dart';
import '../application/progress_providers.dart';
import '../domain/models/progress_models.dart';
import 'progress_presentation_support.dart';

class DashboardWeeklyPage extends ConsumerStatefulWidget {
  const DashboardWeeklyPage({super.key});

  @override
  ConsumerState<DashboardWeeklyPage> createState() =>
      _DashboardWeeklyPageState();
}

class _DashboardWeeklyPageState extends ConsumerState<DashboardWeeklyPage> {
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final AsyncValue<WeeklyDashboardViewData> weeklyData = ref.watch(
      weeklyDashboardProvider(_selectedDay),
    );

    return ProgressPageFrame(
      currentRouteName: 'dashboardWeekly',
      onRefresh: () => ref.invalidate(weeklyDashboardProvider(_selectedDay)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _WeekSelectorBar(
            selectedDay: _selectedDay,
            onPrevious: () => setState(
              () =>
                  _selectedDay = _selectedDay.subtract(const Duration(days: 7)),
            ),
            onNext: _isCurrentWeek(_selectedDay)
                ? null
                : () => setState(
                    () => _selectedDay = _selectedDay.add(
                      const Duration(days: 7),
                    ),
                  ),
          ),
          const SizedBox(height: TerminalSpace.md),
          weeklyData.when(
            data: (WeeklyDashboardViewData data) =>
                _WeeklyContent(data: data, tokens: tokens),
            loading: () => const TerminalPanel(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (_, _) => TerminalEmptyState(
              title: 'No se pudo cargar el dashboard semanal',
              description:
                  'Ocurrió un error al consultar las métricas semanales.',
              icon: Icons.error_outline,
              action: TerminalOutlineButton(
                label: 'Reintentar',
                icon: Icons.refresh,
                onPressed: () =>
                    ref.invalidate(weeklyDashboardProvider(_selectedDay)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isCurrentWeek(DateTime day) {
    final DateTime now = DateTime.now();
    final DateTime currentMonday = now.subtract(
      Duration(days: now.weekday - 1),
    );
    final DateTime dayMonday = day.subtract(Duration(days: day.weekday - 1));
    return currentMonday.year == dayMonday.year &&
        currentMonday.month == dayMonday.month &&
        currentMonday.day == dayMonday.day;
  }
}

class _WeekSelectorBar extends StatelessWidget {
  const _WeekSelectorBar({
    required this.selectedDay,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime selectedDay;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final DateTime monday = selectedDay.subtract(
      Duration(days: selectedDay.weekday - 1),
    );
    final DateTime sunday = monday.add(const Duration(days: 6));

    return TerminalPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Semana anterior',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            color: tokens.terminalRed,
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  'SEMANA',
                  style: TextStyle(
                    color: tokens.infoCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDate(monday)} al ${_formatDate(sunday)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Semana siguiente',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            color: tokens.terminalRed,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _WeeklyContent extends StatelessWidget {
  const _WeeklyContent({required this.data, required this.tokens});

  final WeeklyDashboardViewData data;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RpgLevelCard(level: data.rpgLevel),
        const SizedBox(height: TerminalSpace.md),
        TerminalPanel(
          borderColor: tokens.structuralRed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const TerminalSectionTitle(
                overline: 'Rendimiento consolidado',
                title: 'Totales de la semana',
              ),
              const SizedBox(height: TerminalSpace.md),
              Wrap(
                spacing: 32,
                runSpacing: 18,
                children: <Widget>[
                  TerminalMetric(
                    icon: Icons.military_tech_outlined,
                    value: '+${data.weekXp} XP',
                    label: 'XP Semanal',
                    color: data.weekXp > 0
                        ? tokens.progressGreen
                        : tokens.infoCyan,
                  ),
                  TerminalMetric(
                    icon: Icons.check_circle_outline,
                    value: '${data.completedMissionsCount}',
                    label: 'Misiones logradas',
                    color: tokens.progressGreen,
                  ),
                  TerminalMetric(
                    icon: Icons.timer_outlined,
                    value: _formatWorkTime(data.totalWorkSeconds),
                    label: 'Tiempo enfocado',
                    color: tokens.infoCyan,
                  ),
                  TerminalMetric(
                    icon: Icons.account_balance_wallet_outlined,
                    value: economyMoney(
                      context,
                      data.weekBalanceMinor,
                      signed: true,
                    ),
                    label: 'Balance semanal',
                    color: data.weekBalanceMinor >= 0
                        ? tokens.progressGreen
                        : tokens.attentionOrange,
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
          overline: 'Balance de vida',
          title: 'Distribución de experiencia',
          description: 'Experiencia acumulada por área de vida.',
        ),
        const SizedBox(height: TerminalSpace.sm),
        AreaDistributionList(items: data.areaBreakdown),
      ],
    );
  }

  String _formatWorkTime(int seconds) {
    if (seconds <= 0) {
      return '0 min';
    }
    final int minutes = (seconds / 60).floor();
    final int hours = (minutes / 60).floor();
    final int remainingMinutes = minutes % 60;
    if (hours == 0) {
      return '$minutes min';
    }
    if (remainingMinutes == 0) {
      return '$hours h';
    }
    return '$hours h $remainingMinutes min';
  }
}
