import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../recurrences/application/recurrence_providers.dart';
import '../../recurrences/domain/models/recurrence_template.dart';
import '../application/mission_providers.dart';
import '../domain/models/mission.dart';
import 'mission_presentation_support.dart';

class MissionBoardPage extends ConsumerStatefulWidget {
  const MissionBoardPage({super.key});

  @override
  ConsumerState<MissionBoardPage> createState() => _MissionBoardPageState();
}

class _MissionBoardPageState extends ConsumerState<MissionBoardPage> {
  final Set<String> _taking = <String>{};

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<MissionBoardEntry>> board = ref.watch(
      missionBoardProvider,
    );
    final List<MissionArea> areas =
        ref.watch(missionAreasProvider).value ?? const <MissionArea>[];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: compact
              ? TerminalSpace.pageCompact
              : TerminalSpace.pageTablet,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TerminalPageHeader(
                    title: 'Tablón diario',
                    subtitle: 'Elige qué misiones quieres asumir hoy',
                    action: compact
                        ? null
                        : TerminalPrimaryButton(
                            label: 'Nueva para el tablón',
                            icon: Icons.add_box_outlined,
                            onPressed: _createBoardMission,
                          ),
                  ),
                  if (compact) ...<Widget>[
                    const SizedBox(height: TerminalSpace.sm),
                    TerminalPrimaryButton(
                      label: 'Nueva para el tablón',
                      icon: Icons.add_box_outlined,
                      expanded: true,
                      onPressed: _createBoardMission,
                    ),
                  ],
                  const SizedBox(height: TerminalSpace.md),
                  const MissionSectionNavigation(
                    selected: MissionSection.board,
                  ),
                  const SizedBox(height: TerminalSpace.md),
                  board.when(
                    data: (entries) => _BoardContent(
                      entries: entries,
                      areas: areas,
                      taking: _taking,
                      onTake: _take,
                      onOpen: _openMission,
                      onCreate: _createBoardMission,
                    ),
                    loading: () => const TerminalLoadingState(
                      message: 'Consultando misiones disponibles…',
                    ),
                    error: (Object _, StackTrace _) => TerminalErrorState(
                      title: 'Tablón no disponible',
                      description:
                          'No se pudieron consultar las misiones de hoy.',
                      onRetry: () => ref.invalidate(missionBoardProvider),
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

  void _createBoardMission() => context.pushNamed(
    'missionNew',
    queryParameters: const <String, String>{'board': '1'},
  );

  void _openMission(String missionId) => context.pushNamed(
    'missionDetail',
    pathParameters: <String, String>{'missionId': missionId},
  );

  Future<void> _take(MissionBoardEntry entry) async {
    if (!_taking.add(entry.template.id)) return;
    setState(() {});
    final result = await ref
        .read(recurrenceApplicationServiceProvider)
        .takeMissionFromBoard(entry.template.id);
    if (!mounted) return;
    setState(() => _taking.remove(entry.template.id));
    result.fold<void>(
      onSuccess: (taken) {
        ref.invalidate(missionBoardProvider);
        ref.invalidate(todayMissionsProvider);
        ref.invalidate(allMissionsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              taken.created
                  ? 'Misión añadida a Hoy.'
                  : 'Esta misión ya estaba tomada hoy.',
            ),
            action: SnackBarAction(
              label: 'ABRIR',
              onPressed: () => _openMission(taken.missionId),
            ),
          ),
        );
      },
      onFailure: (AppFailure failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }
}

class _BoardContent extends StatelessWidget {
  const _BoardContent({
    required this.entries,
    required this.areas,
    required this.taking,
    required this.onTake,
    required this.onOpen,
    required this.onCreate,
  });

  final List<MissionBoardEntry> entries;
  final List<MissionArea> areas;
  final Set<String> taking;
  final ValueChanged<MissionBoardEntry> onTake;
  final ValueChanged<String> onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return TerminalEmptyState(
        icon: Icons.dashboard_customize_outlined,
        title: 'EL TABLÓN ESTÁ VACÍO',
        description:
            'Crea una misión diaria y elige “Ofrecer en el tablón”. Aquí aparecerá cada día sin ocupar tu lista hasta que la tomes.',
        action: TerminalPrimaryButton(
          label: 'Crear misión de tablón',
          icon: Icons.add_box_outlined,
          onPressed: onCreate,
        ),
      );
    }
    final int taken = entries.where((entry) => entry.isTakenToday).length;
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TerminalPanel(
          borderColor: tokens.infoCyan,
          child: Wrap(
            spacing: 34,
            runSpacing: 16,
            children: <Widget>[
              TerminalMetric(
                icon: Icons.inventory_2_outlined,
                value: '${entries.length - taken}',
                label: 'Disponibles',
                color: tokens.infoCyan,
              ),
              TerminalMetric(
                icon: Icons.task_alt,
                value: '$taken',
                label: 'Tomadas hoy',
                color: tokens.progressGreen,
              ),
            ],
          ),
        ),
        const SizedBox(height: TerminalSpace.md),
        for (final entry in entries) ...<Widget>[
          _BoardMissionCard(
            entry: entry,
            area: _areaFor(entry.template.areaId),
            taking: taking.contains(entry.template.id),
            onTake: () => onTake(entry),
            onOpen: entry.missionId == null
                ? null
                : () => onOpen(entry.missionId!),
          ),
          const SizedBox(height: TerminalSpace.sm),
        ],
      ],
    );
  }

  MissionArea? _areaFor(String id) {
    for (final area in areas) {
      if (area.id == id) return area;
    }
    return null;
  }
}

class _BoardMissionCard extends StatelessWidget {
  const _BoardMissionCard({
    required this.entry,
    required this.taking,
    required this.onTake,
    this.area,
    this.onOpen,
  });

  final MissionBoardEntry entry;
  final MissionArea? area;
  final bool taking;
  final VoidCallback onTake;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final RecurrenceTemplate template = entry.template;
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final Color accent = area == null
        ? tokens.infoCyan
        : missionAreaColor(area!.colorHex, tokens.infoCyan);
    return TerminalPanel(
      borderColor: entry.isTakenToday ? tokens.progressGreen : accent,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 650;
          final Widget details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (area != null)
                    TerminalBadge(label: area!.name, color: accent),
                  TerminalBadge(
                    label: entry.isTakenToday ? 'TOMADA HOY' : 'DISPONIBLE',
                    color: entry.isTakenToday
                        ? tokens.progressGreen
                        : tokens.infoCyan,
                  ),
                  TerminalBadge(
                    label: '${template.xpReward} XP',
                    color: tokens.valueYellow,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                template.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (template.description?.trim().isNotEmpty == true) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  template.description!,
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: <Widget>[
                  Text(missionImportanceLabel(template.importance)),
                  if (template.estimatedMinutes != null)
                    Text('${template.estimatedMinutes} min'),
                  if (template.objectives.isNotEmpty)
                    Text('${template.objectives.length} objetivos'),
                ],
              ),
            ],
          );
          final Widget action = entry.isTakenToday
              ? TerminalOutlineButton(
                  label: 'Abrir misión',
                  icon: Icons.open_in_new,
                  color: tokens.progressGreen,
                  onPressed: onOpen,
                )
              : TerminalPrimaryButton(
                  label: taking ? 'Tomando…' : 'Tomar misión',
                  icon: Icons.add_task,
                  onPressed: taking ? null : onTake,
                );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[details, const SizedBox(height: 16), action],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: details),
              const SizedBox(width: 20),
              action,
            ],
          );
        },
      ),
    );
  }
}
