import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/mission_providers.dart';
import '../domain/models/mission.dart';
import 'mission_presentation_support.dart';

class MissionCalendarPage extends ConsumerStatefulWidget {
  const MissionCalendarPage({super.key});

  @override
  ConsumerState<MissionCalendarPage> createState() =>
      _MissionCalendarPageState();
}

class _MissionCalendarPageState extends ConsumerState<MissionCalendarPage> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final DateTime monthEnd = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
    );
    final MissionCalendarRange range = (
      startUtc: _visibleMonth.toUtc(),
      endUtc: monthEnd.toUtc(),
    );
    final AsyncValue<List<Mission>> missions = ref.watch(
      calendarMissionsProvider(range),
    );
    final AsyncValue<List<MissionArea>> areas = ref.watch(missionAreasProvider);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 920;
        final Widget calendar = _CalendarPanel(
          month: _visibleMonth,
          selectedDay: _selectedDay,
          missions: missions.value ?? const <Mission>[],
          onSelected: (DateTime value) => setState(() => _selectedDay = value),
        );
        final Widget agenda = _DayAgenda(
          day: _selectedDay,
          missions: missions,
          areas: areas.value ?? const <MissionArea>[],
          onRetry: () {
            ref.invalidate(calendarMissionsProvider(range));
            ref.invalidate(missionAreasProvider);
          },
        );
        return SingleChildScrollView(
          padding: wide ? TerminalSpace.pageTablet : TerminalSpace.pageCompact,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _CalendarHeader(
                    month: _visibleMonth,
                    onPrevious: () => _changeMonth(-1),
                    onNext: () => _changeMonth(1),
                    onToday: _goToday,
                    onCreate: () => context.pushNamed('missionNew'),
                  ),
                  const SizedBox(height: TerminalSpace.md),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 3, child: calendar),
                        const SizedBox(width: TerminalSpace.md),
                        Expanded(flex: 2, child: agenda),
                      ],
                    )
                  else ...<Widget>[
                    calendar,
                    const SizedBox(height: TerminalSpace.md),
                    agenda,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _changeMonth(int delta) {
    final DateTime next = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + delta,
    );
    setState(() {
      _visibleMonth = next;
      _selectedDay = DateTime(next.year, next.month, 1);
    });
  }

  void _goToday() {
    final DateTime now = DateTime.now();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onCreate,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final Widget title = TerminalPageHeader(
        title: 'Calendario de misiones',
        subtitle: '${_monthLabel(month)} · planificación local',
      );
      final Widget actions = Wrap(
        spacing: TerminalSpace.xs,
        runSpacing: TerminalSpace.xs,
        children: <Widget>[
          IconButton(
            tooltip: 'Mes anterior',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          TerminalOutlineButton(
            label: 'Hoy',
            icon: Icons.today_outlined,
            onPressed: onToday,
          ),
          IconButton(
            tooltip: 'Mes siguiente',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
          TerminalPrimaryButton(
            label: 'Nueva misión',
            icon: Icons.add,
            onPressed: onCreate,
          ),
        ],
      );
      if (constraints.maxWidth < 720) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            title,
            const SizedBox(height: TerminalSpace.sm),
            actions,
          ],
        );
      }
      return TerminalPageHeader(
        title: 'Calendario de misiones',
        subtitle: '${_monthLabel(month)} · planificación local',
        action: actions,
      );
    },
  );
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.month,
    required this.selectedDay,
    required this.missions,
    required this.onSelected,
  });

  final DateTime month;
  final DateTime selectedDay;
  final List<Mission> missions;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final int days = DateTime(month.year, month.month + 1, 0).day;
    final int leading = DateTime(month.year, month.month, 1).weekday - 1;
    final int cells = ((leading + days + 6) ~/ 7) * 7;
    final Map<int, List<Mission>> byDay = <int, List<Mission>>{};
    for (final Mission mission in missions) {
      final DateTime? local = mission.scheduledAtUtc?.toLocal();
      if (local != null &&
          local.year == month.year &&
          local.month == month.month) {
        byDay.putIfAbsent(local.day, () => <Mission>[]).add(mission);
      }
    }

    return TerminalPanel(
      borderColor: tokens.structuralRed,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              for (final String label in <String>[
                'L',
                'M',
                'X',
                'J',
                'V',
                'S',
                'D',
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: TerminalSpace.sm),
                    child: Text(label, textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.92,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: cells,
            itemBuilder: (BuildContext context, int index) {
              final int day = index - leading + 1;
              if (day < 1 || day > days) {
                return const SizedBox.shrink();
              }
              final DateTime date = DateTime(month.year, month.month, day);
              final List<Mission> dayMissions = byDay[day] ?? const <Mission>[];
              return _CalendarDay(
                date: date,
                missions: dayMissions,
                selected: _sameDay(date, selectedDay),
                today: _sameDay(date, DateTime.now()),
                onTap: () => onSelected(date),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.missions,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime date;
  final List<Mission> missions;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final bool completed =
        missions.isNotEmpty &&
        missions.every(
          (mission) =>
              mission.status == MissionStatus.completed ||
              mission.status == MissionStatus.partial,
        );
    return Semantics(
      button: true,
      selected: selected,
      label: '${date.day} de ${_monthLabel(date)}, ${missions.length} misiones',
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: TerminalMotion.resolve(context, TerminalMotion.quick),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? tokens.infoCyan.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? tokens.infoCyan
                  : today
                  ? tokens.terminalRed
                  : tokens.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${date.day}',
                style: TextStyle(
                  color: selected ? tokens.infoCyan : tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (missions.isNotEmpty)
                Row(
                  children: <Widget>[
                    Icon(
                      completed ? Icons.check_circle : Icons.flag,
                      size: 13,
                      color: completed
                          ? tokens.progressGreen
                          : tokens.valueYellow,
                    ),
                    const SizedBox(width: 3),
                    Text('${missions.length}'),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayAgenda extends StatelessWidget {
  const _DayAgenda({
    required this.day,
    required this.missions,
    required this.areas,
    required this.onRetry,
  });

  final DateTime day;
  final AsyncValue<List<Mission>> missions;
  final List<MissionArea> areas;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      borderColor: tokens.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TerminalSectionTitle(
            title: '${day.day} de ${_monthLabel(day)}',
            overline: 'Agenda del día',
          ),
          const SizedBox(height: TerminalSpace.md),
          missions.when(
            data: (List<Mission> values) {
              final List<Mission> selected = values
                  .where((mission) {
                    final DateTime? local = mission.scheduledAtUtc?.toLocal();
                    return local != null && _sameDay(local, day);
                  })
                  .toList(growable: false);
              if (selected.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: TerminalSpace.lg),
                  child: Text(
                    'No hay misiones programadas para este día.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return Column(
                children: <Widget>[
                  for (final Mission mission in selected) ...<Widget>[
                    _AgendaMission(
                      mission: mission,
                      area: _area(mission.areaId),
                    ),
                    const SizedBox(height: TerminalSpace.xs),
                  ],
                ],
              );
            },
            loading: () => const TerminalInlineLoadingState(
              message: 'Cargando agenda del día…',
            ),
            error: (Object error, StackTrace stackTrace) =>
                TerminalInlineErrorState(
                  message: 'No se pudo cargar el calendario.',
                  onRetry: onRetry,
                ),
          ),
        ],
      ),
    );
  }

  MissionArea? _area(String id) {
    for (final MissionArea area in areas) {
      if (area.id == id) return area;
    }
    return null;
  }
}

class _AgendaMission extends StatelessWidget {
  const _AgendaMission({required this.mission, required this.area});

  final Mission mission;
  final MissionArea? area;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return InkWell(
      onTap: () => context.pushNamed(
        'missionDetail',
        pathParameters: <String, String>{'missionId': mission.id},
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surfaceLow,
          border: Border(left: BorderSide(color: tokens.infoCyan, width: 2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(TerminalSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                mission.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${_timeLabel(mission.scheduledAtUtc)} · '
                '${area?.name ?? 'Área'} · ${missionStatusLabel(mission.status)}',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _timeLabel(DateTime? utc) {
  if (utc == null) return 'Sin hora';
  final DateTime local = utc.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _monthLabel(DateTime date) {
  const List<String> months = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${months[date.month - 1]} ${date.year}';
}
