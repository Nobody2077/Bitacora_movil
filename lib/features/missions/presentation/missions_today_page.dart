import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/mission_providers.dart';
import '../domain/models/mission.dart';
import 'mission_presentation_support.dart';

class MissionsTodayPage extends ConsumerWidget {
  const MissionsTodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Mission>> missions = ref.watch(todayMissionsProvider);
    final AsyncValue<List<MissionArea>> areas = ref.watch(missionAreasProvider);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 680;
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Header(compact: compact),
                  const SizedBox(height: 24),
                  _MissionSummary(missions: missions),
                  const SizedBox(height: 16),
                  missions.when(
                    data: (items) => _MissionList(
                      missions: items,
                      areas: areas.value ?? const <MissionArea>[],
                    ),
                    loading: () => const _LoadingPanel(),
                    error: (Object error, StackTrace stackTrace) => _ErrorPanel(
                      message: 'No se pudieron cargar las misiones.',
                      onRetry: () => ref.invalidate(todayMissionsProvider),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget action = TerminalOutlineButton(
      label: 'Nueva misión',
      icon: Icons.add,
      onPressed: () => context.pushNamed('missionNew'),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const TerminalPageHeader(
            title: 'Centro de misiones',
            subtitle: 'Planificación local · Misiones de hoy',
          ),
          const SizedBox(height: 16),
          action,
        ],
      );
    }
    return TerminalPageHeader(
      title: 'Centro de misiones',
      subtitle: 'Planificación local · Misiones de hoy',
      action: action,
    );
  }
}

class _MissionSummary extends StatelessWidget {
  const _MissionSummary({required this.missions});

  final AsyncValue<List<Mission>> missions;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final List<Mission> items = missions.value ?? const <Mission>[];
    final int completed = items
        .where(
          (mission) =>
              mission.status == MissionStatus.completed ||
              mission.status == MissionStatus.partial,
        )
        .length;
    final int active = items
        .where(
          (mission) =>
              mission.status == MissionStatus.active ||
              mission.status == MissionStatus.paused,
        )
        .length;
    final int xp = items.fold<int>(
      0,
      (total, mission) => total + mission.xpPlanned,
    );
    return TerminalPanel(
      borderColor: tokens.structuralRed,
      child: Wrap(
        spacing: 36,
        runSpacing: 18,
        children: <Widget>[
          TerminalMetric(
            icon: Icons.track_changes_outlined,
            value: '${items.length}',
            label: 'Para hoy',
            color: tokens.infoCyan,
          ),
          TerminalMetric(
            icon: Icons.play_circle_outline,
            value: '$active',
            label: 'En progreso',
            color: tokens.valueYellow,
          ),
          TerminalMetric(
            icon: Icons.check_circle_outline,
            value: '$completed',
            label: 'Completadas',
            color: tokens.progressGreen,
          ),
          TerminalMetric(
            icon: Icons.bolt_outlined,
            value: '+$xp',
            label: 'XP posible',
            color: tokens.progressGreen,
          ),
        ],
      ),
    );
  }
}

class _MissionList extends StatelessWidget {
  const _MissionList({required this.missions, required this.areas});

  final List<Mission> missions;
  final List<MissionArea> areas;

  @override
  Widget build(BuildContext context) {
    if (missions.isEmpty) {
      return TerminalPanel(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          children: <Widget>[
            const Icon(Icons.radar, size: 52, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              'AÚN NO HAY MISIONES PARA HOY',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea la primera misión y aparecerá aquí inmediatamente.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TerminalPrimaryButton(
              label: 'Crear primera misión',
              icon: Icons.add,
              onPressed: () => context.pushNamed('missionNew'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        for (final mission in missions) ...<Widget>[
          _MissionCard(mission: mission, area: _areaFor(mission.areaId)),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  MissionArea? _areaFor(String areaId) {
    for (final area in areas) {
      if (area.id == areaId) {
        return area;
      }
    }
    return null;
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission, required this.area});

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
    final bool compact = MediaQuery.sizeOf(context).width < 700;
    return InkWell(
      customBorder: const TerminalCutCornerBorder(cut: 14),
      onTap: () => context.pushNamed(
        'missionDetail',
        pathParameters: <String, String>{'missionId': mission.id},
      ),
      child: TerminalPanel(
        borderColor: mission.status == MissionStatus.active
            ? tokens.terminalRed
            : tokens.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                TerminalBadge(
                  label: missionStatusLabel(mission.status),
                  color: mission.status == MissionStatus.completed
                      ? tokens.progressGreen
                      : tokens.terminalRed,
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
              ],
            ),
            const SizedBox(height: 14),
            Text(
              mission.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              missionDateLabel(mission.scheduledAtUtc),
              style: const TextStyle(
                color: Colors.white60,
                fontFamily: 'JetBrains Mono',
              ),
            ),
            if (mission.description?.trim().isNotEmpty == true) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                mission.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              alignment: compact
                  ? WrapAlignment.start
                  : WrapAlignment.spaceBetween,
              spacing: 28,
              runSpacing: 14,
              children: <Widget>[
                TerminalMetric(
                  icon: Icons.bolt_outlined,
                  value: '${mission.xpPlanned}',
                  label: 'XP',
                  color: tokens.infoCyan,
                ),
                if (mission.estimatedMinutes != null)
                  TerminalMetric(
                    icon: Icons.schedule,
                    value: '${mission.estimatedMinutes}',
                    label: 'Min',
                    color: tokens.valueYellow,
                  ),
                if (mission.budgetMinor != null)
                  TerminalMetric(
                    icon: Icons.savings_outlined,
                    value: missionMoneyLabel(mission.budgetMinor!),
                    label: 'Bs',
                    color: tokens.progressGreen,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) => const TerminalPanel(
    padding: EdgeInsets.all(36),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      borderColor: tokens.terminalRed,
      child: Column(
        children: <Widget>[
          Icon(Icons.error_outline, color: tokens.terminalRed, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TerminalOutlineButton(
            label: 'Reintentar',
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
