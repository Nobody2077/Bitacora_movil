import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../economy/presentation/economy_presentation_support.dart';
import '../../journal/application/daily_close_application_service.dart';
import '../../journal/domain/models/daily_close.dart';
import '../../journal/presentation/journal_presentation_support.dart';
import '../application/progress_providers.dart';
import '../domain/models/progress_models.dart';
import 'progress_presentation_support.dart';

class DashboardDailyPage extends ConsumerStatefulWidget {
  const DashboardDailyPage({super.key});

  @override
  ConsumerState<DashboardDailyPage> createState() => _DashboardDailyPageState();
}

class _DashboardDailyPageState extends ConsumerState<DashboardDailyPage> {
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final AsyncValue<DailyDashboardViewData> dashboardData = ref.watch(
      dailyDashboardProvider(_selectedDay),
    );

    return ProgressPageFrame(
      currentRouteName: 'dashboardDaily',
      onRefresh: () => ref.invalidate(dailyDashboardProvider(_selectedDay)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _DaySelectorBar(
            selectedDay: _selectedDay,
            onPrevious: () => setState(
              () => _selectedDay = DateTime(
                _selectedDay.year,
                _selectedDay.month,
                _selectedDay.day - 1,
              ),
            ),
            onNext: journalSameDay(_selectedDay, DateTime.now())
                ? null
                : () => setState(
                    () => _selectedDay = DateTime(
                      _selectedDay.year,
                      _selectedDay.month,
                      _selectedDay.day + 1,
                    ),
                  ),
          ),
          const SizedBox(height: TerminalSpace.md),
          dashboardData.when(
            data: (DailyDashboardViewData data) => _DailyContent(
              data: data,
              tokens: tokens,
              onOpenDailyClose: () => context.pushNamed(
                'journalDailyClose',
                pathParameters: <String, String>{
                  'date': dailyCloseDateKey(_selectedDay),
                },
              ),
            ),
            loading: () => const TerminalPanel(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (_, _) => TerminalEmptyState(
              title: 'No se pudo cargar el dashboard diario',
              description:
                  'Ocurrió un error al consultar las métricas locales.',
              icon: Icons.error_outline,
              action: TerminalOutlineButton(
                label: 'Reintentar',
                icon: Icons.refresh,
                onPressed: () =>
                    ref.invalidate(dailyDashboardProvider(_selectedDay)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySelectorBar extends StatelessWidget {
  const _DaySelectorBar({
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
    return TerminalPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Día anterior',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            color: tokens.terminalRed,
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  journalSameDay(selectedDay, DateTime.now())
                      ? 'HOY'
                      : 'DÍA SELECCIONADO',
                  style: TextStyle(
                    color: tokens.infoCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  journalDayLabel(selectedDay),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Día siguiente',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            color: tokens.terminalRed,
          ),
        ],
      ),
    );
  }
}

class _DailyContent extends StatelessWidget {
  const _DailyContent({
    required this.data,
    required this.tokens,
    required this.onOpenDailyClose,
  });

  final DailyDashboardViewData data;
  final AppThemeTokens tokens;
  final VoidCallback onOpenDailyClose;

  @override
  Widget build(BuildContext context) {
    final DailyCloseSummary summary = data.dailyCloseSummary;
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const TerminalSectionTitle(
                    overline: 'Resumen operativo',
                    title: 'Rendimiento del día',
                  ),
                  TerminalOutlineButton(
                    label: 'Cierre del día',
                    icon: Icons.assignment_turned_in_outlined,
                    onPressed: onOpenDailyClose,
                  ),
                ],
              ),
              const SizedBox(height: TerminalSpace.md),
              Wrap(
                spacing: 32,
                runSpacing: 18,
                children: <Widget>[
                  TerminalMetric(
                    icon: Icons.military_tech_outlined,
                    value: '+${data.todayXp} XP',
                    label: 'XP de hoy',
                    color: data.todayXp > 0
                        ? tokens.progressGreen
                        : tokens.infoCyan,
                  ),
                  TerminalMetric(
                    icon: Icons.check_circle_outline,
                    value: '${summary.completedMissions.length}',
                    label: 'Completadas',
                    color: tokens.progressGreen,
                  ),
                  if (summary.requiredPendingMissions.isNotEmpty)
                    TerminalMetric(
                      icon: Icons.warning_amber_outlined,
                      value: '${summary.requiredPendingMissions.length}',
                      label: 'Obligatorias pendientes',
                      color: tokens.terminalRed,
                    ),
                  TerminalMetric(
                    icon: Icons.timer_outlined,
                    value: _formatWorkTime(summary.workSeconds),
                    label: 'Tiempo enfocado',
                    color: tokens.infoCyan,
                  ),
                  TerminalMetric(
                    icon: Icons.account_balance_wallet_outlined,
                    value: economyMoney(summary.balanceMinor, signed: true),
                    label: 'Balance económico',
                    color: summary.balanceMinor >= 0
                        ? tokens.progressGreen
                        : tokens.attentionOrange,
                  ),
                  if (summary.mainAreaName != null)
                    TerminalMetric(
                      icon: Icons.category_outlined,
                      value: summary.mainAreaName!,
                      label: 'Área destacada',
                      color: tokens.valueYellow,
                    ),
                ],
              ),
            ],
          ),
        ),
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
