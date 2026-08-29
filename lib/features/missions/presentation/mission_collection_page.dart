import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/mission_providers.dart';
import '../domain/models/mission.dart';
import 'mission_presentation_support.dart';

enum MissionCollection { upcoming, all }

class MissionCollectionPage extends ConsumerWidget {
  const MissionCollectionPage({required this.collection, super.key});

  final MissionCollection collection;

  bool get _isUpcoming => collection == MissionCollection.upcoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Mission>> missions = ref.watch(
      _isUpcoming ? upcomingMissionsProvider : allMissionsProvider,
    );
    final AsyncValue<List<MissionArea>> areas = ref.watch(missionAreasProvider);
    final String title = _isUpcoming
        ? 'Próximas misiones'
        : 'Todas las misiones';
    final String subtitle = _isUpcoming
        ? 'Planificadas desde mañana'
        : 'Historial y planificación sin archivar';

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TerminalPageHeader(title: title, subtitle: subtitle),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      TerminalOutlineButton(
                        label: 'Misiones de hoy',
                        icon: Icons.today_outlined,
                        onPressed: () => context.goNamed('missionsToday'),
                      ),
                      TerminalOutlineButton(
                        label: _isUpcoming ? 'Todas' : 'Próximas',
                        icon: _isUpcoming
                            ? Icons.list_alt_outlined
                            : Icons.event_outlined,
                        onPressed: () => context.goNamed(
                          _isUpcoming ? 'missionsAll' : 'missionsUpcoming',
                        ),
                      ),
                      TerminalPrimaryButton(
                        label: 'Nueva misión',
                        icon: Icons.add,
                        onPressed: () => context.pushNamed('missionNew'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _CollectionSummary(missions: missions),
                  const SizedBox(height: 16),
                  missions.when(
                    data: (items) => _isUpcoming
                        ? _CollectionList(
                            missions: items,
                            areas: areas.value ?? const <MissionArea>[],
                            emptyTitle:
                                'NO HAY MISIONES PROGRAMADAS DESDE MAÑANA',
                            emptyDescription:
                                'Las misiones que programes para otra fecha aparecerán aquí.',
                          )
                        : _AllMissionSections(
                            missions: items,
                            areas: areas.value ?? const <MissionArea>[],
                          ),
                    loading: () => const TerminalLoadingState(
                      message: 'Cargando colección de misiones…',
                    ),
                    error: (Object error, StackTrace stackTrace) =>
                        TerminalErrorState(
                          title: 'Colección no disponible',
                          description: 'No se pudieron cargar las misiones.',
                          onRetry: () => ref.invalidate(
                            _isUpcoming
                                ? upcomingMissionsProvider
                                : allMissionsProvider,
                          ),
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

class _AllMissionSections extends StatelessWidget {
  const _AllMissionSections({required this.missions, required this.areas});

  final List<Mission> missions;
  final List<MissionArea> areas;

  @override
  Widget build(BuildContext context) {
    if (missions.isEmpty) {
      return _CollectionList(
        missions: missions,
        areas: areas,
        emptyTitle: 'AÚN NO HAY MISIONES REGISTRADAS',
        emptyDescription: 'Crea una misión para iniciar tu historial.',
      );
    }
    final List<Mission> unscheduled = missions
        .where((mission) => mission.isUnscheduled)
        .toList(growable: false);
    final List<Mission> planned = missions
        .where((mission) => !mission.isUnscheduled)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (unscheduled.isNotEmpty) ...<Widget>[
          _SectionTitle(
            label: 'Sin planificar',
            count: unscheduled.length,
            icon: Icons.inbox_outlined,
          ),
          const SizedBox(height: 12),
          _CollectionList(
            missions: unscheduled,
            areas: areas,
            emptyTitle: '',
            emptyDescription: '',
          ),
          const SizedBox(height: 10),
        ],
        if (planned.isNotEmpty) ...<Widget>[
          _SectionTitle(
            label: 'Con planificación',
            count: planned.length,
            icon: Icons.event_available_outlined,
          ),
          const SizedBox(height: 12),
          _CollectionList(
            missions: planned,
            areas: areas,
            emptyTitle: '',
            emptyDescription: '',
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.label,
    required this.count,
    required this.icon,
  });

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Row(
      children: <Widget>[
        Icon(icon, color: tokens.infoCyan),
        const SizedBox(width: 8),
        Text(
          '${label.toUpperCase()} · $count',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: tokens.infoCyan,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _CollectionSummary extends StatelessWidget {
  const _CollectionSummary({required this.missions});

  final AsyncValue<List<Mission>> missions;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final List<Mission> items = missions.value ?? const <Mission>[];
    final int pending = items
        .where(
          (mission) =>
              mission.status == MissionStatus.scheduled ||
              mission.status == MissionStatus.available ||
              mission.status == MissionStatus.rescheduled ||
              mission.status == MissionStatus.paused ||
              mission.status == MissionStatus.active,
        )
        .length;
    final int completed = items
        .where(
          (mission) =>
              mission.status == MissionStatus.completed ||
              mission.status == MissionStatus.partial,
        )
        .length;
    return TerminalPanel(
      borderColor: tokens.structuralRed,
      child: Wrap(
        spacing: 34,
        runSpacing: 16,
        children: <Widget>[
          TerminalMetric(
            icon: Icons.flag_outlined,
            value: '${items.length}',
            label: 'Mostradas',
            color: tokens.infoCyan,
          ),
          TerminalMetric(
            icon: Icons.pending_actions_outlined,
            value: '$pending',
            label: 'Pendientes',
            color: tokens.valueYellow,
          ),
          TerminalMetric(
            icon: Icons.check_circle_outline,
            value: '$completed',
            label: 'Cerradas',
            color: tokens.progressGreen,
          ),
        ],
      ),
    );
  }
}

class _CollectionList extends StatelessWidget {
  const _CollectionList({
    required this.missions,
    required this.areas,
    required this.emptyTitle,
    required this.emptyDescription,
  });

  final List<Mission> missions;
  final List<MissionArea> areas;
  final String emptyTitle;
  final String emptyDescription;

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
              emptyTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(emptyDescription, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final mission in missions) ...<Widget>[
          _CollectionMissionCard(
            mission: mission,
            area: _areaFor(mission.areaId),
          ),
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

class _CollectionMissionCard extends StatelessWidget {
  const _CollectionMissionCard({required this.mission, required this.area});

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
    final Color statusColor =
        mission.status == MissionStatus.completed ||
            mission.status == MissionStatus.partial
        ? tokens.progressGreen
        : mission.status == MissionStatus.active
        ? tokens.terminalRed
        : tokens.valueYellow;
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
                  color: statusColor,
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
              missionScheduleLabel(mission),
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
          ],
        ),
      ),
    );
  }
}
