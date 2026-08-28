import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/mission_providers.dart';
import '../domain/models/mission.dart';
import 'mission_presentation_support.dart';

/// Lista operativa: filtros, búsqueda y tarjetas trabajan sobre el stream real.
class MissionsTodayPage extends ConsumerStatefulWidget {
  const MissionsTodayPage({super.key});

  @override
  ConsumerState<MissionsTodayPage> createState() => _MissionsTodayPageState();
}

class _MissionsTodayPageState extends ConsumerState<MissionsTodayPage> {
  final TextEditingController _searchController = TextEditingController();
  _MissionFilter _filter = _MissionFilter.all;
  String? _areaId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Mission>> missions = ref.watch(todayMissionsProvider);
    final AsyncValue<List<MissionArea>> areas = ref.watch(missionAreasProvider);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 900;
        final List<Mission> source = missions.value ?? const <Mission>[];
        final List<MissionArea> knownAreas =
            areas.value ?? const <MissionArea>[];
        final Widget list = missions.when(
          data: (_) => _MissionList(
            missions: _visibleMissions(source),
            areas: knownAreas,
            hasFilters:
                _filter != _MissionFilter.all ||
                _areaId != null ||
                _searchController.text.trim().isNotEmpty,
            onClearFilters: _clearFilters,
          ),
          loading: () =>
              const TerminalLoadingState(message: 'Cargando misiones de hoy…'),
          error: (Object _, StackTrace _) => TerminalErrorState(
            title: 'Misiones no disponibles',
            description: 'No se pudieron cargar las misiones de hoy.',
            onRetry: () => ref.invalidate(todayMissionsProvider),
          ),
        );
        return SingleChildScrollView(
          padding: wide ? TerminalSpace.pageTablet : TerminalSpace.pageCompact,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _MissionHeader(
                    onCreate: () => context.pushNamed('missionNew'),
                    onCalendar: () => context.pushNamed('missionsCalendar'),
                  ),
                  const SizedBox(height: TerminalSpace.md),
                  _MissionControls(
                    selectedFilter: _filter,
                    selectedAreaId: _areaId,
                    areas: knownAreas,
                    controller: _searchController,
                    onFilterChanged: (_MissionFilter value) =>
                        setState(() => _filter = value),
                    onAreaChanged: (String? value) =>
                        setState(() => _areaId = value),
                    onSearchChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: TerminalSpace.md),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: list),
                        const SizedBox(width: TerminalSpace.md),
                        SizedBox(
                          width: 206,
                          child: _MissionSummary(missions: source),
                        ),
                      ],
                    )
                  else ...<Widget>[
                    list,
                    const SizedBox(height: TerminalSpace.md),
                    _MissionSummary(missions: source),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Mission> _visibleMissions(List<Mission> source) {
    final String query = _searchController.text.trim().toLowerCase();
    return source
        .where((Mission mission) {
          final bool matchesArea = _areaId == null || mission.areaId == _areaId;
          final bool matchesQuery =
              query.isEmpty ||
              mission.title.toLowerCase().contains(query) ||
              (mission.description?.toLowerCase().contains(query) ?? false);
          return matchesArea && matchesQuery && _matchesFilter(mission);
        })
        .toList(growable: false);
  }

  bool _matchesFilter(Mission mission) => switch (_filter) {
    _MissionFilter.all => true,
    _MissionFilter.today =>
      mission.status != MissionStatus.completed &&
          mission.status != MissionStatus.partial,
    _MissionFilter.active =>
      mission.status == MissionStatus.active ||
          mission.status == MissionStatus.paused,
    _MissionFilter.completed =>
      mission.status == MissionStatus.completed ||
          mission.status == MissionStatus.partial,
  };

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _filter = _MissionFilter.all;
      _areaId = null;
    });
  }
}

enum _MissionFilter { all, today, active, completed }

class _MissionHeader extends StatelessWidget {
  const _MissionHeader({required this.onCreate, required this.onCalendar});

  final VoidCallback onCreate;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final Widget title = const TerminalPageHeader(
        title: 'Centro de misiones',
        subtitle: 'Planificación local · misiones activas',
      );
      final Widget action = Wrap(
        spacing: TerminalSpace.xs,
        runSpacing: TerminalSpace.xs,
        children: <Widget>[
          TerminalOutlineButton(
            label: 'Calendario',
            icon: Icons.calendar_month_outlined,
            onPressed: onCalendar,
          ),
          TerminalPrimaryButton(
            label: 'Nueva misión',
            icon: Icons.add_box_outlined,
            onPressed: onCreate,
          ),
        ],
      );
      if (constraints.maxWidth < 600) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            title,
            const SizedBox(height: TerminalSpace.md),
            action,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: title),
          action,
        ],
      );
    },
  );
}

class _MissionControls extends StatelessWidget {
  const _MissionControls({
    required this.selectedFilter,
    required this.selectedAreaId,
    required this.areas,
    required this.controller,
    required this.onFilterChanged,
    required this.onAreaChanged,
    required this.onSearchChanged,
  });

  final _MissionFilter selectedFilter;
  final String? selectedAreaId;
  final List<MissionArea> areas;
  final TextEditingController controller;
  final ValueChanged<_MissionFilter> onFilterChanged;
  final ValueChanged<String?> onAreaChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: TerminalSpace.xs,
          runSpacing: TerminalSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            for (final _MissionFilter filter in _MissionFilter.values)
              _FilterTab(
                label: _filterLabel(filter),
                selected: selectedFilter == filter,
                onTap: () => onFilterChanged(filter),
              ),
            SizedBox(
              width: 230,
              child: TextField(
                controller: controller,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Buscar misión',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
          ],
        ),
        if (areas.isNotEmpty) ...<Widget>[
          const SizedBox(height: TerminalSpace.sm),
          Wrap(
            spacing: TerminalSpace.xs,
            runSpacing: TerminalSpace.xs,
            children: <Widget>[
              _AreaChip(
                label: 'Todas las áreas',
                icon: Icons.grid_view_outlined,
                color: tokens.textSecondary,
                selected: selectedAreaId == null,
                onTap: () => onAreaChanged(null),
              ),
              for (final MissionArea area in areas)
                _AreaChip(
                  label: area.name,
                  icon: missionAreaIcon(area.iconKey),
                  color: missionAreaColor(area.colorHex, tokens.infoCyan),
                  selected: selectedAreaId == area.id,
                  onTap: () => onAreaChanged(area.id),
                ),
            ],
          ),
        ],
      ],
    );
  }

  static String _filterLabel(_MissionFilter filter) => switch (filter) {
    _MissionFilter.all => 'Todas',
    _MissionFilter.today => 'Hoy',
    _MissionFilter.active => 'En progreso',
    _MissionFilter.completed => 'Completadas',
  };
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: TerminalMotion.resolve(context, TerminalMotion.quick),
          padding: const EdgeInsets.symmetric(
            horizontal: TerminalSpace.md,
            vertical: TerminalSpace.xs,
          ),
          decoration: ShapeDecoration(
            color: selected ? tokens.infoCyan.withValues(alpha: 0.1) : null,
            shape: TerminalCutCornerBorder(
              cut: 5,
              side: BorderSide(
                color: selected ? tokens.infoCyan : tokens.border,
              ),
            ),
          ),
          child: TerminalLabel(
            label,
            color: selected ? tokens.infoCyan : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: TerminalMotion.resolve(context, TerminalMotion.quick),
        padding: const EdgeInsets.symmetric(
          horizontal: TerminalSpace.sm,
          vertical: TerminalSpace.xs,
        ),
        decoration: ShapeDecoration(
          color: selected ? color.withValues(alpha: 0.11) : null,
          shape: TerminalCutCornerBorder(
            cut: 5,
            side: BorderSide(
              color: selected ? color : color.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: TerminalSpace.xs),
            TerminalLabel(label, color: color),
          ],
        ),
      ),
    ),
  );
}

class _MissionList extends StatelessWidget {
  const _MissionList({
    required this.missions,
    required this.areas,
    required this.hasFilters,
    required this.onClearFilters,
  });

  final List<Mission> missions;
  final List<MissionArea> areas;
  final bool hasFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    if (missions.isEmpty) {
      final AppThemeTokens tokens = Theme.of(
        context,
      ).extension<AppThemeTokens>()!;
      return TerminalEmptyState(
        title: hasFilters ? 'Sin coincidencias' : 'No hay misiones para hoy',
        description: hasFilters
            ? 'Prueba con otro filtro, área o búsqueda.'
            : 'Crea una misión y aparecerá en el centro de operaciones.',
        icon: hasFilters
            ? Icons.search_off_outlined
            : Icons.track_changes_outlined,
        action: hasFilters
            ? TerminalOutlineButton(
                label: 'Limpiar filtros',
                icon: Icons.filter_alt_off_outlined,
                color: tokens.infoCyan,
                onPressed: onClearFilters,
              )
            : TerminalPrimaryButton(
                label: 'Nueva misión',
                icon: Icons.add,
                onPressed: () => context.pushNamed('missionNew'),
              ),
      );
    }
    return Column(
      children: <Widget>[
        for (final Mission mission in missions) ...<Widget>[
          _MissionCard(mission: mission, area: _areaFor(mission.areaId)),
          const SizedBox(height: TerminalSpace.sm),
        ],
      ],
    );
  }

  MissionArea? _areaFor(String id) {
    for (final MissionArea area in areas) {
      if (area.id == id) return area;
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
    final int total = mission.objectives.length;
    final int completed = mission.objectives
        .where((MissionObjective objective) => objective.isCompleted)
        .length;
    final bool active = mission.status == MissionStatus.active;
    final bool isDone =
        mission.status == MissionStatus.completed ||
        mission.status == MissionStatus.partial;
    return TerminalPanel(
      padding: const EdgeInsets.all(TerminalSpace.md),
      borderColor: active ? tokens.terminalRed : tokens.border,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 610;
          final Widget identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _MissionAreaIcon(
                icon: missionAreaIcon(area?.iconKey ?? ''),
                color: areaColor,
              ),
              const SizedBox(width: TerminalSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TerminalLabel(
                      missionStatusLabel(mission.status),
                      color: active ? tokens.terminalRed : areaColor,
                    ),
                    const SizedBox(height: TerminalSpace.xxs),
                    Text(
                      mission.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: TerminalSpace.xxs),
                    Text(
                      '${area?.name ?? 'Área'} · '
                      '${missionImportanceLabel(mission.importance)} · '
                      '${missionDateLabel(mission.scheduledAtUtc)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final Widget values = Wrap(
            spacing: TerminalSpace.md,
            runSpacing: TerminalSpace.xs,
            children: <Widget>[
              _MiniValue(
                icon: Icons.bolt_outlined,
                value: '${mission.xpPlanned}',
                label: 'XP',
                color: tokens.infoCyan,
              ),
              if (mission.estimatedMinutes != null)
                _MiniValue(
                  icon: Icons.schedule_outlined,
                  value: '${mission.estimatedMinutes}',
                  label: 'Min',
                  color: tokens.valueYellow,
                ),
              if (mission.budgetMinor != null)
                _MiniValue(
                  icon: Icons.savings_outlined,
                  value: missionMoneyDisplay(context, mission.budgetMinor!),
                  label: 'Presupuesto',
                  color: tokens.progressGreen,
                ),
            ],
          );
          final Widget progress = total == 0
              ? const SizedBox.shrink()
              : SizedBox(
                  width: compact ? double.infinity : 118,
                  child: TerminalProgress(
                    value: completed / total,
                    label: '$completed/$total progreso',
                    color: tokens.progressGreen,
                  ),
                );
          final Widget action = TerminalPrimaryButton(
            label: active
                ? 'Continuar'
                : isDone
                ? 'Ver resultado'
                : 'Abrir',
            icon: Icons.arrow_forward,
            onPressed: () => context.pushNamed(
              active
                  ? 'missionActive'
                  : isDone
                  ? 'missionResult'
                  : 'missionDetail',
              pathParameters: <String, String>{'missionId': mission.id},
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                identity,
                const SizedBox(height: TerminalSpace.sm),
                values,
                if (total > 0) ...<Widget>[
                  const SizedBox(height: TerminalSpace.sm),
                  progress,
                ],
                const SizedBox(height: TerminalSpace.md),
                action,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              identity,
              const SizedBox(height: TerminalSpace.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(child: values),
                  if (total > 0) ...<Widget>[
                    const SizedBox(width: TerminalSpace.md),
                    progress,
                  ],
                  const SizedBox(width: TerminalSpace.md),
                  action,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MissionAreaIcon extends StatelessWidget {
  const _MissionAreaIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: color.withValues(alpha: 0.08),
      shape: TerminalCutCornerBorder(cut: 8, side: BorderSide(color: color)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(TerminalSpace.sm),
      child: Icon(icon, color: color, size: 23),
    ),
  );
}

class _MiniValue extends StatelessWidget {
  const _MiniValue({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(icon, size: 18, color: color),
      const SizedBox(width: TerminalSpace.xxs),
      Text(
        value,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
      ),
      const SizedBox(width: TerminalSpace.xxs),
      TerminalLabel(label, color: color),
    ],
  );
}

class _MissionSummary extends StatelessWidget {
  const _MissionSummary({required this.missions});

  final List<Mission> missions;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final int active = missions
        .where(
          (Mission m) =>
              m.status == MissionStatus.active ||
              m.status == MissionStatus.paused,
        )
        .length;
    final int xp = missions.fold<int>(
      0,
      (int total, Mission m) => total + m.xpPlanned,
    );
    return TerminalPanel(
      borderColor: tokens.terminalRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TerminalLabel('Resumen', color: tokens.terminalRed),
          const SizedBox(height: TerminalSpace.lg),
          _SummaryValue(
            icon: Icons.track_changes_outlined,
            label: 'Activas',
            value: '$active',
            color: tokens.infoCyan,
          ),
          const SizedBox(height: TerminalSpace.md),
          _SummaryValue(
            icon: Icons.today_outlined,
            label: 'Para hoy',
            value: '${missions.length}',
            color: tokens.valueYellow,
          ),
          const SizedBox(height: TerminalSpace.md),
          _SummaryValue(
            icon: Icons.bolt_outlined,
            label: 'XP posible',
            value: '+$xp',
            color: tokens.progressGreen,
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, color: color, size: 26),
      const SizedBox(width: TerminalSpace.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TerminalLabel(label, color: color),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    ],
  );
}
