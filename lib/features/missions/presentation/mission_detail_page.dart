import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/persistence_providers.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../core/result/result.dart';
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
          onMissions: () => context.goNamed('missionsToday'),
          onNew: () => context.pushNamed('missionNew'),
          onArchive: () => _confirmArchive(context, ref, value),
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

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    Mission mission,
  ) async {
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('¿Archivar misión?'),
        content: const Text(
          'La misión desaparecerá de tus listas y calendario. Su historial '
          'se conservará y cualquier aviso pendiente será cancelado.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => dialogContext.pop(true),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) {
      return;
    }
    final Result<Mission> result = await ref
        .read(missionApplicationServiceProvider)
        .archiveMission(mission);
    if (!context.mounted) {
      return;
    }
    result.fold<void>(
      onSuccess: (_) {
        unawaited(
          ref.read(notificationReconciliationServiceProvider).reconcile(),
        );
        ref.invalidate(missionDetailProvider(mission.id));
        ref.invalidate(todayMissionsProvider);
        ref.invalidate(upcomingMissionsProvider);
        ref.invalidate(allMissionsProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Misión archivada.')));
        context.goNamed('missionsToday');
      },
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }
}

class _MissionDetailContent extends StatelessWidget {
  const _MissionDetailContent({
    required this.mission,
    required this.area,
    required this.onEdit,
    required this.onTimer,
    required this.onComplete,
    required this.onMissions,
    required this.onNew,
    required this.onArchive,
  });

  final Mission mission;
  final MissionArea? area;
  final VoidCallback onEdit;
  final VoidCallback onTimer;
  final VoidCallback onComplete;
  final VoidCallback onMissions;
  final VoidCallback onNew;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final bool compact = constraints.maxWidth < 820;
      return SingleChildScrollView(
        padding: compact ? TerminalSpace.pageCompact : TerminalSpace.pageTablet,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _DetailHeader(
                  mission: mission,
                  onMissions: onMissions,
                  onNew: onNew,
                ),
                const SizedBox(height: TerminalSpace.lg),
                _IdentityPanel(mission: mission, area: area),
                const SizedBox(height: TerminalSpace.md),
                if (compact) ...<Widget>[
                  _ObjectivesPanel(mission: mission),
                  const SizedBox(height: TerminalSpace.md),
                  _ExecutionPanel(mission: mission),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: _ObjectivesPanel(mission: mission)),
                      const SizedBox(width: TerminalSpace.md),
                      Expanded(child: _ExecutionPanel(mission: mission)),
                    ],
                  ),
                const SizedBox(height: TerminalSpace.md),
                _ActionPanel(
                  mission: mission,
                  onEdit: onEdit,
                  onTimer: onTimer,
                  onComplete: onComplete,
                  onArchive: onArchive,
                ),
                const SizedBox(height: TerminalSpace.md),
                _ActivityPanel(mission: mission),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.mission,
    required this.onMissions,
    required this.onNew,
  });

  final Mission mission;
  final VoidCallback onMissions;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final Widget actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        TerminalOutlineButton(
          label: 'Misiones',
          icon: Icons.list_alt_outlined,
          onPressed: onMissions,
        ),
        TerminalPrimaryButton(
          label: 'Nueva misión',
          icon: Icons.add,
          onPressed: onNew,
        ),
      ],
    );
    if (MediaQuery.sizeOf(context).width < 820) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TerminalPageHeader(
            title: 'Detalle de misión',
            subtitle: 'Misiones · ${missionStatusLabel(mission.status)}',
          ),
          const SizedBox(height: TerminalSpace.sm),
          actions,
        ],
      );
    }
    return TerminalPageHeader(
      title: 'Detalle de misión',
      subtitle: 'Misiones · ${missionStatusLabel(mission.status)}',
      action: actions,
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
          const SizedBox(height: TerminalSpace.md),
          Text(
            mission.title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (mission.description?.trim().isNotEmpty == true) ...<Widget>[
            const SizedBox(height: TerminalSpace.sm),
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
          const TerminalSectionTitle(title: 'Objetivos', overline: 'Ejecución'),
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
            TerminalProgress(
              value: completed / mission.objectives.length,
              label: 'Progreso $completed/${mission.objectives.length}',
              color: tokens.progressGreen,
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
    return TerminalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const TerminalSectionTitle(
            title: 'Plan de ejecución',
            overline: 'Trazabilidad',
          ),
          const SizedBox(height: 14),
          _PlanRow(
            icon: Icons.calendar_today_outlined,
            label: 'Fecha',
            value: missionDateLabel(mission.scheduledAtUtc),
          ),
          const TerminalDivider(),
          _PlanRow(
            icon: Icons.schedule,
            label: 'Duración',
            value: mission.estimatedMinutes == null
                ? 'Sin estimar'
                : '${mission.estimatedMinutes} min',
          ),
          const TerminalDivider(),
          _PlanRow(
            icon: Icons.savings_outlined,
            label: 'Presupuesto',
            value: mission.budgetMinor == null
                ? 'Sin presupuesto'
                : 'Bs ${missionMoneyLabel(mission.budgetMinor!)}',
          ),
          const TerminalDivider(),
          _PlanRow(
            icon: Icons.bolt_outlined,
            label: 'Recompensa',
            value: '${mission.xpPlanned} XP',
          ),
          const TerminalDivider(),
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
    required this.onArchive,
  });

  final Mission mission;
  final VoidCallback onEdit;
  final VoidCallback onTimer;
  final VoidCallback onComplete;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) => TerminalPanel(
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        TerminalOutlineButton(
          label: mission.status == MissionStatus.active
              ? 'Abrir cronómetro'
              : 'Cronómetro',
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
        TerminalPrimaryButton(
          label: 'Completar misión',
          icon: Icons.flag_outlined,
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
        TerminalOutlineButton(
          label: 'Editar',
          icon: Icons.more_horiz,
          onPressed: onEdit,
        ),
        TerminalCriticalButton(
          label: 'Archivar misión',
          icon: Icons.archive_outlined,
          onPressed: mission.status == MissionStatus.active ? null : onArchive,
        ),
      ],
    ),
  );
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final List<MissionTimeEntry> entries = mission.timeEntries.reversed.toList(
      growable: false,
    );
    return TerminalPanel(
      borderColor: tokens.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const TerminalSectionTitle(
            title: 'Registro de actividad',
            overline: 'Trazabilidad local',
          ),
          const SizedBox(height: TerminalSpace.md),
          if (entries.isEmpty)
            Text(
              'Aún no hay segmentos de tiempo registrados.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
            )
          else
            for (final MissionTimeEntry entry in entries.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: TerminalSpace.sm),
                child: Row(
                  children: <Widget>[
                    Icon(
                      entry.segmentType == MissionTimeSegmentType.work
                          ? Icons.play_circle_outline
                          : Icons.pause_circle_outline,
                      color: entry.segmentType == MissionTimeSegmentType.work
                          ? tokens.infoCyan
                          : tokens.valueYellow,
                    ),
                    const SizedBox(width: TerminalSpace.sm),
                    Expanded(
                      child: Text(
                        entry.segmentType == MissionTimeSegmentType.work
                            ? 'Trabajo · ${missionDurationLabel(entry.durationSeconds)}'
                            : 'Pausa · ${missionDurationLabel(entry.durationSeconds)}',
                      ),
                    ),
                    TerminalLabel(
                      _activityTime(entry.createdAtUtc),
                      color: tokens.textSecondary,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  static String _activityTime(DateTime instant) =>
      '${instant.toLocal().hour.toString().padLeft(2, '0')}:'
      '${instant.toLocal().minute.toString().padLeft(2, '0')}';
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
