import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../economy/application/economy_providers.dart';
import '../../economy/domain/models/economy_snapshot.dart';
import '../../economy/presentation/economy_presentation_support.dart';
import '../../missions/application/mission_providers.dart';
import '../../missions/domain/models/mission.dart';
import '../../missions/presentation/mission_presentation_support.dart';

/// Inicio operativo: resume datos existentes sin sustituir las pantallas de
/// Misiones ni inventar datos de módulos que aún no están implementados.
class HomeOperationsPage extends ConsumerWidget {
  const HomeOperationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Mission>> today = ref.watch(todayMissionsProvider);
    final AsyncValue<List<Mission>> upcoming = ref.watch(
      upcomingMissionsProvider,
    );
    final AsyncValue<Mission?> activeTimer = ref.watch(
      activeTimerMissionProvider,
    );
    final AsyncValue<EconomySnapshot> economy = ref.watch(
      economySnapshotProvider,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 920;
        final List<Mission> todayItems = today.value ?? const <Mission>[];
        final Mission? priority = _priorityMission(
          todayItems,
          activeTimer.value,
        );
        final Mission? next = upcoming.value?.isEmpty ?? true
            ? null
            : upcoming.value!.first;
        return SingleChildScrollView(
          padding: wide ? TerminalSpace.pageTablet : TerminalSpace.pageCompact,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const TerminalPageHeader(
                    title: 'Centro de operaciones',
                    subtitle: 'Panel local · prioridades y actividad',
                  ),
                  const SizedBox(height: TerminalSpace.xl),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 7,
                          child: _PriorityMissionPanel(mission: priority),
                        ),
                        const SizedBox(width: TerminalSpace.md),
                        Expanded(
                          flex: 4,
                          child: _NextMissionPanel(mission: next),
                        ),
                      ],
                    )
                  else ...<Widget>[
                    _PriorityMissionPanel(mission: priority),
                    const SizedBox(height: TerminalSpace.md),
                    _NextMissionPanel(mission: next),
                  ],
                  const SizedBox(height: TerminalSpace.md),
                  _OperationalMetrics(missions: todayItems, economy: economy),
                  const SizedBox(height: TerminalSpace.lg),
                  const _OperationActions(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Mission? _priorityMission(List<Mission> missions, Mission? active) {
    if (active != null) return active;
    for (final Mission mission in missions) {
      if (mission.status == MissionStatus.available ||
          mission.status == MissionStatus.scheduled) {
        return mission;
      }
    }
    return missions.isEmpty ? null : missions.first;
  }
}

class _PriorityMissionPanel extends StatelessWidget {
  const _PriorityMissionPanel({required this.mission});

  final Mission? mission;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    if (mission == null) {
      return TerminalEmptyState(
        title: 'Sin misión prioritaria',
        description: 'Crea una misión para comenzar tu jornada.',
        icon: Icons.track_changes_outlined,
        action: TerminalPrimaryButton(
          label: 'Nueva misión',
          icon: Icons.add,
          onPressed: () => context.pushNamed('missionNew'),
        ),
      );
    }
    return TerminalPanel(
      borderColor: tokens.terminalRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TerminalLabel('Misión prioritaria', color: tokens.terminalRed),
          const SizedBox(height: TerminalSpace.sm),
          Text(
            mission!.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: TerminalSpace.xs),
          Text(
            '${missionStatusLabel(mission!.status)} · '
            '${missionDateLabel(mission!.scheduledAtUtc)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
          ),
          if (mission!.description?.trim().isNotEmpty == true) ...<Widget>[
            const SizedBox(height: TerminalSpace.sm),
            Text(
              mission!.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.textSecondary),
            ),
          ],
          const SizedBox(height: TerminalSpace.md),
          Wrap(
            spacing: TerminalSpace.lg,
            runSpacing: TerminalSpace.sm,
            children: <Widget>[
              TerminalMetric(
                icon: Icons.bolt_outlined,
                value: '${mission!.xpPlanned}',
                label: 'XP',
                color: tokens.infoCyan,
              ),
              if (mission!.estimatedMinutes != null)
                TerminalMetric(
                  icon: Icons.schedule_outlined,
                  value: '${mission!.estimatedMinutes}',
                  label: 'Min',
                  color: tokens.valueYellow,
                ),
            ],
          ),
          const SizedBox(height: TerminalSpace.lg),
          TerminalPrimaryButton(
            label: mission!.status == MissionStatus.active
                ? 'Abrir cronómetro'
                : 'Abrir misión',
            icon: Icons.arrow_forward,
            onPressed: () => context.pushNamed(
              mission!.status == MissionStatus.active
                  ? 'missionActive'
                  : 'missionDetail',
              pathParameters: <String, String>{'missionId': mission!.id},
            ),
          ),
        ],
      ),
    );
  }
}

class _NextMissionPanel extends StatelessWidget {
  const _NextMissionPanel({required this.mission});

  final Mission? mission;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      borderColor: tokens.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TerminalLabel('Próxima misión', color: tokens.infoCyan),
          const SizedBox(height: TerminalSpace.sm),
          Text(
            mission?.title ?? 'Sin misiones programadas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: TerminalSpace.xs),
          Text(
            mission == null
                ? 'Las próximas misiones aparecerán aquí.'
                : missionDateLabel(mission!.scheduledAtUtc),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
          ),
          if (mission?.description?.trim().isNotEmpty == true) ...<Widget>[
            const SizedBox(height: TerminalSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.shopping_cart_outlined, color: tokens.valueYellow),
                const SizedBox(width: TerminalSpace.sm),
                Expanded(
                  child: Text(
                    mission!.description!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: TerminalSpace.md),
          if (mission != null)
            TerminalOutlineButton(
              label: 'Ver detalle',
              icon: Icons.arrow_forward,
              color: tokens.infoCyan,
              onPressed: () => context.pushNamed(
                'missionDetail',
                pathParameters: <String, String>{'missionId': mission!.id},
              ),
            )
          else
            TerminalOutlineButton(
              label: 'Ver próximas',
              icon: Icons.event_outlined,
              color: tokens.infoCyan,
              onPressed: () => context.goNamed('missionsUpcoming'),
            ),
        ],
      ),
    );
  }
}

class _OperationalMetrics extends StatelessWidget {
  const _OperationalMetrics({required this.missions, required this.economy});

  final List<Mission> missions;
  final AsyncValue<EconomySnapshot> economy;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final int completed = missions
        .where(
          (Mission mission) =>
              mission.status == MissionStatus.completed ||
              mission.status == MissionStatus.partial,
        )
        .length;
    final int xp = missions.fold<int>(
      0,
      (int total, Mission mission) => total + mission.xpPlanned,
    );
    return Wrap(
      spacing: TerminalSpace.md,
      runSpacing: TerminalSpace.md,
      children: <Widget>[
        _MetricPanel(
          icon: Icons.track_changes_outlined,
          label: 'Misiones',
          value: '$completed/${missions.length}',
          detail: 'Completadas hoy',
          color: tokens.infoCyan,
        ),
        _MetricPanel(
          icon: Icons.bolt_outlined,
          label: 'XP',
          value: '+$xp',
          detail: 'Posible hoy',
          color: tokens.valueYellow,
        ),
        _EconomyMetric(economy: economy),
      ],
    );
  }
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: TerminalCard(
      padding: const EdgeInsets.all(TerminalSpace.md),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 28),
          const SizedBox(width: TerminalSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TerminalLabel(label, color: color),
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _EconomyMetric extends StatelessWidget {
  const _EconomyMetric({required this.economy});

  final AsyncValue<EconomySnapshot> economy;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return SizedBox(
      width: 220,
      child: TerminalCard(
        padding: const EdgeInsets.all(TerminalSpace.md),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.account_balance_wallet_outlined,
              color: tokens.progressGreen,
            ),
            const SizedBox(width: TerminalSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TerminalLabel('Economía', color: tokens.progressGreen),
                  Text(
                    economy.when(
                      data: (value) => economyMoney(value.availableMinor),
                      loading: () => '…',
                      error: (_, _) => '—',
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    economy.hasError ? 'No disponible' : 'Saldo disponible',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationActions extends StatelessWidget {
  const _OperationActions();

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      borderColor: tokens.terminalRed,
      padding: const EdgeInsets.all(TerminalSpace.md),
      child: Wrap(
        spacing: TerminalSpace.sm,
        runSpacing: TerminalSpace.sm,
        children: <Widget>[
          TerminalPrimaryButton(
            label: 'Misión',
            icon: Icons.add,
            onPressed: () => context.pushNamed('missionNew'),
          ),
          TerminalOutlineButton(
            label: 'Gasto',
            icon: Icons.remove_circle_outline,
            onPressed: () => context.pushNamed('financeNewExpense'),
          ),
          TerminalOutlineButton(
            label: 'Entrada',
            icon: Icons.add_circle_outline,
            onPressed: () => context.pushNamed('financeNewIncome'),
          ),
        ],
      ),
    );
  }
}
