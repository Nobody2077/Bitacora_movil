import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/mission_providers.dart';
import '../domain/models/mission.dart';
import 'mission_presentation_support.dart';

class MissionDetailPage extends ConsumerWidget {
  const MissionDetailPage({required this.missionId, super.key});

  final String missionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Mission?> mission = ref.watch(
      missionDetailProvider(missionId),
    );
    final AsyncValue<List<MissionArea>> areas = ref.watch(missionAreasProvider);
    return mission.when(
      data: (value) {
        if (value == null) {
          return _MissingMission(
            onBack: () => context.goNamed('missionsToday'),
          );
        }
        return _MissionDetailContent(
          mission: value,
          area: _findArea(areas.value, value.areaId),
          onEdit: () => context.pushNamed(
            'missionEdit',
            pathParameters: <String, String>{'missionId': value.id},
          ),
          onTimer: () => context.pushNamed(
            'missionActive',
            pathParameters: <String, String>{'missionId': value.id},
          ),
          onComplete: () => context.pushNamed(
            'missionReview',
            pathParameters: <String, String>{'missionId': value.id},
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => _MissingMission(
        message: 'No se pudo abrir la misión.',
        onBack: () => context.goNamed('missionsToday'),
      ),
    );
  }

  static MissionArea? _findArea(List<MissionArea>? areas, String areaId) {
    if (areas == null) {
      return null;
    }
    for (final area in areas) {
      if (area.id == areaId) {
        return area;
      }
    }
    return null;
  }
}

class _MissionDetailContent extends StatelessWidget {
  const _MissionDetailContent({
    required this.mission,
    required this.area,
    required this.onEdit,
    required this.onTimer,
    required this.onComplete,
  });

  final Mission mission;
  final MissionArea? area;
  final VoidCallback onEdit;
  final VoidCallback onTimer;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final bool compact = constraints.maxWidth < 820;
      return SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 16 : 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _DetailHeader(mission: mission, onEdit: onEdit),
                const SizedBox(height: 20),
                _IdentityPanel(mission: mission, area: area),
                const SizedBox(height: 18),
                if (compact) ...<Widget>[
                  _ObjectivesPanel(mission: mission),
                  const SizedBox(height: 18),
                  _ExecutionPanel(mission: mission),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: _ObjectivesPanel(mission: mission)),
                      const SizedBox(width: 18),
                      Expanded(child: _ExecutionPanel(mission: mission)),
                    ],
                  ),
                const SizedBox(height: 18),
                _ActionPanel(
                  mission: mission,
                  onEdit: onEdit,
                  onTimer: onTimer,
                  onComplete: onComplete,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.mission, required this.onEdit});

  final Mission mission;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final Widget action = TerminalOutlineButton(
      label: 'Editar',
      icon: Icons.edit_outlined,
      onPressed: onEdit,
    );
    if (MediaQuery.sizeOf(context).width < 620) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TerminalPageHeader(
            title: 'Detalle de misión',
            subtitle: 'Misiones · ${missionStatusLabel(mission.status)}',
          ),
          const SizedBox(height: 14),
          action,
        ],
      );
    }
    return TerminalPageHeader(
      title: 'Detalle de misión',
      subtitle: 'Misiones · ${missionStatusLabel(mission.status)}',
      action: action,
    );
  }
}

class _IdentityPanel extends StatelessWidget {
  const _IdentityPanel({required this.mission, required this.area});

  final Mission mission;
  final MissionArea? area;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final Color areaColor = area == null
        ? tokens.infoCyan
        : missionAreaColor(area!.colorHex, tokens.infoCyan);
    return TerminalPanel(
      borderColor: tokens.terminalRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              TerminalBadge(
                label: missionStatusLabel(mission.status),
                color: tokens.terminalRed,
                icon: Icons.track_changes_outlined,
              ),
              TerminalBadge(
                label: area?.name ?? 'Área',
                color: areaColor,
                icon: missionAreaIcon(area?.iconKey ?? ''),
              ),
              TerminalBadge(
                label: missionImportanceLabel(mission.importance),
                color: tokens.valueYellow,
              ),
              TerminalBadge(
                label: missionTypeLabel(mission.type),
                color: tokens.infoCyan,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            mission.title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (mission.description?.trim().isNotEmpty == true) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              mission.description!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ],
      ),
    );
  }
}

class _ObjectivesPanel extends StatelessWidget {
  const _ObjectivesPanel({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final int completed = mission.objectives
        .where((objective) => objective.isCompleted)
        .length;
    return TerminalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'OBJETIVOS',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: tokens.infoCyan,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          if (mission.objectives.isEmpty)
            const Text(
              'Esta misión no tiene objetivos adicionales.',
              style: TextStyle(color: Colors.white54),
            )
          else
            for (final objective in mission.objectives)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: <Widget>[
                    Icon(
                      objective.isCompleted
                          ? Icons.check_box_outlined
                          : Icons.check_box_outline_blank,
                      color: objective.isCompleted
                          ? tokens.progressGreen
                          : tokens.infoCyan,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(objective.description)),
                  ],
                ),
              ),
          if (mission.objectives.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              'PROGRESO $completed/${mission.objectives.length}',
              style: TextStyle(
                color: tokens.progressGreen,
                fontFamily: 'JetBrains Mono',
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: completed / mission.objectives.length,
              color: tokens.progressGreen,
              backgroundColor: tokens.border,
            ),
          ],
        ],
      ),
    );
  }
}

class _ExecutionPanel extends StatelessWidget {
  const _ExecutionPanel({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'PLAN DE EJECUCIÓN',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: tokens.infoCyan,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          _PlanRow(
            icon: Icons.calendar_today_outlined,
            label: 'Fecha',
            value: missionDateLabel(mission.scheduledAtUtc),
          ),
          _PlanRow(
            icon: Icons.schedule,
            label: 'Duración',
            value: mission.estimatedMinutes == null
                ? 'Sin estimar'
                : '${mission.estimatedMinutes} min',
          ),
          _PlanRow(
            icon: Icons.savings_outlined,
            label: 'Presupuesto',
            value: mission.budgetMinor == null
                ? 'Sin presupuesto'
                : 'Bs ${missionMoneyLabel(mission.budgetMinor!)}',
          ),
          _PlanRow(
            icon: Icons.bolt_outlined,
            label: 'Recompensa',
            value: '${mission.xpPlanned} XP',
          ),
          _PlanRow(
            icon: Icons.priority_high,
            label: 'Prioridad',
            value: missionPriorityLabel(mission.priority),
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: tokens.infoCyan),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          Text(value, style: const TextStyle(fontFamily: 'JetBrains Mono')),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.mission,
    required this.onEdit,
    required this.onTimer,
    required this.onComplete,
  });

  final Mission mission;
  final VoidCallback onEdit;
  final VoidCallback onTimer;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => TerminalPanel(
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        TerminalPrimaryButton(
          label: 'Editar misión',
          icon: Icons.edit_outlined,
          onPressed: onEdit,
        ),
        TerminalOutlineButton(
          label: mission.status == MissionStatus.active
              ? 'Cronómetro activo'
              : 'Abrir cronómetro',
          icon: Icons.timer_outlined,
          onPressed:
              const <MissionStatus>{
                MissionStatus.scheduled,
                MissionStatus.available,
                MissionStatus.active,
                MissionStatus.paused,
                MissionStatus.rescheduled,
              }.contains(mission.status)
              ? onTimer
              : null,
        ),
        TerminalOutlineButton(
          label: 'Registrar resultado',
          icon: Icons.flag_outlined,
          color: Theme.of(context).extension<AppThemeTokens>()!.progressGreen,
          onPressed:
              const <MissionStatus>{
                MissionStatus.scheduled,
                MissionStatus.available,
                MissionStatus.active,
                MissionStatus.paused,
                MissionStatus.rescheduled,
              }.contains(mission.status)
              ? onComplete
              : null,
        ),
      ],
    ),
  );
}

class _MissingMission extends StatelessWidget {
  const _MissingMission({required this.onBack, this.message});

  final VoidCallback onBack;
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: TerminalPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.search_off, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            Text(message ?? 'La misión no existe.'),
            const SizedBox(height: 16),
            TerminalPrimaryButton(
              label: 'Volver a misiones',
              icon: Icons.arrow_back,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    ),
  );
}
