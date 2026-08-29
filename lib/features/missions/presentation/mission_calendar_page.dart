import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/mission_providers.dart';
import '../domain/models/mission.dart';
import 'mission_presentation_support.dart';

enum MissionCalendarViewMode { day, week, month }

class MissionCalendarPage extends ConsumerStatefulWidget {
  const MissionCalendarPage({super.key, this.initialDay});

  final DateTime? initialDay;

  @override
  ConsumerState<MissionCalendarPage> createState() =>
      _MissionCalendarPageState();
}

class _MissionCalendarPageState extends ConsumerState<MissionCalendarPage> {
  late DateTime _selectedDay;
  MissionCalendarViewMode _view = MissionCalendarViewMode.month;

  @override
  void initState() {
    super.initState();
    final DateTime initial = widget.initialDay?.toLocal() ?? DateTime.now();
    _selectedDay = DateTime(initial.year, initial.month, initial.day);
  }

  @override
  Widget build(BuildContext context) {
    final ({DateTime start, DateTime end}) localRange = _visibleRange();
    final MissionCalendarRange range = (
      startUtc: localRange.start.toUtc(),
      endUtc: localRange.end.toUtc(),
    );
    final AsyncValue<List<Mission>> missions = ref.watch(
      calendarMissionsProvider(range),
    );
    final AsyncValue<List<MissionArea>> areas = ref.watch(missionAreasProvider);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 920;
        final Widget? calendar = switch (_view) {
          MissionCalendarViewMode.month => _CalendarPanel(
            month: DateTime(_selectedDay.year, _selectedDay.month),
            selectedDay: _selectedDay,
            missions: missions.value ?? const <Mission>[],
            onSelected: _selectDay,
          ),
          MissionCalendarViewMode.week => _WeekPanel(
            weekStart: localRange.start,
            selectedDay: _selectedDay,
            missions: missions.value ?? const <Mission>[],
            onSelected: _selectDay,
          ),
          MissionCalendarViewMode.day => null,
        };
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
                    periodLabel: _periodLabel(localRange.start),
                    onPrevious: () => _movePeriod(-1),
                    onNext: () => _movePeriod(1),
                    onToday: _goToday,
                    onCreate: _createMission,
                  ),
                  const SizedBox(height: TerminalSpace.sm),
                  _CalendarViewSelector(
                    value: _view,
                    onChanged: (MissionCalendarViewMode value) =>
                        setState(() => _view = value),
                  ),
                  const SizedBox(height: TerminalSpace.md),
                  if (calendar == null)
                    agenda
                  else if (wide)
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

  ({DateTime start, DateTime end}) _visibleRange() {
    final DateTime weekStart = _startOfWeek(_selectedDay);
    return switch (_view) {
      MissionCalendarViewMode.day => (
        start: _selectedDay,
        end: _addCivilDays(_selectedDay, 1),
      ),
      MissionCalendarViewMode.week => (
        start: weekStart,
        end: _addCivilDays(weekStart, 7),
      ),
      MissionCalendarViewMode.month => (
        start: DateTime(_selectedDay.year, _selectedDay.month),
        end: DateTime(_selectedDay.year, _selectedDay.month + 1),
      ),
    };
  }

  void _movePeriod(int delta) {
    final DateTime next = switch (_view) {
      MissionCalendarViewMode.day => _addCivilDays(_selectedDay, delta),
      MissionCalendarViewMode.week => _addCivilDays(_selectedDay, 7 * delta),
      MissionCalendarViewMode.month => _shiftMonth(_selectedDay, delta),
    };
    setState(() => _selectedDay = next);
  }

  void _goToday() {
    final DateTime now = DateTime.now();
    setState(() => _selectedDay = DateTime(now.year, now.month, now.day));
  }

  void _selectDay(DateTime value) {
    setState(() => _selectedDay = DateTime(value.year, value.month, value.day));
  }

  void _createMission() {
    context.pushNamed(
      'missionNew',
      queryParameters: <String, String>{
        'origin': 'calendar',
        'date': _dateParameter(_selectedDay),
      },
    );
  }

  String _periodLabel(DateTime rangeStart) => switch (_view) {
    MissionCalendarViewMode.day =>
      '${_weekdayLabel(_selectedDay)}, ${_selectedDay.day} de '
          '${_monthName(_selectedDay)} ${_selectedDay.year}',
    MissionCalendarViewMode.week =>
      '${rangeStart.day} ${_monthName(rangeStart)} — '
          '${_addCivilDays(rangeStart, 6).day} '
          '${_monthName(_addCivilDays(rangeStart, 6))}',
    MissionCalendarViewMode.month => _monthLabel(_selectedDay),
  };
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.periodLabel,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onCreate,
  });

  final String periodLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final Widget title = TerminalPageHeader(
        title: 'Calendario de misiones',
        subtitle: '$periodLabel · planificación local',
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
        subtitle: '$periodLabel · planificación local',
        action: actions,
      );
    },
  );
}

class _CalendarViewSelector extends StatelessWidget {
  const _CalendarViewSelector({required this.value, required this.onChanged});

  final MissionCalendarViewMode value;
  final ValueChanged<MissionCalendarViewMode> onChanged;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<MissionCalendarViewMode>(
        key: const Key('calendar-view-selector'),
        segments: const <ButtonSegment<MissionCalendarViewMode>>[
          ButtonSegment<MissionCalendarViewMode>(
            value: MissionCalendarViewMode.day,
            icon: Icon(Icons.view_day_outlined),
            label: Text('Día'),
          ),
          ButtonSegment<MissionCalendarViewMode>(
            value: MissionCalendarViewMode.week,
            icon: Icon(Icons.view_week_outlined),
            label: Text('Semana'),
          ),
          ButtonSegment<MissionCalendarViewMode>(
            value: MissionCalendarViewMode.month,
            icon: Icon(Icons.calendar_view_month_outlined),
            label: Text('Mes'),
          ),
        ],
        selected: <MissionCalendarViewMode>{value},
        onSelectionChanged: (Set<MissionCalendarViewMode> selection) =>
            onChanged(selection.single),
      ),
    ),
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

class _WeekPanel extends StatelessWidget {
  const _WeekPanel({
    required this.weekStart,
    required this.selectedDay,
    required this.missions,
    required this.onSelected,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final List<Mission> missions;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final List<Widget> days = <Widget>[
      for (int offset = 0; offset < 7; offset++)
        _WeekDayTile(
          date: _addCivilDays(weekStart, offset),
          selected: _sameDay(_addCivilDays(weekStart, offset), selectedDay),
          today: _sameDay(_addCivilDays(weekStart, offset), DateTime.now()),
          missions: missions
              .where((Mission mission) {
                final DateTime? local = mission.scheduledAtUtc?.toLocal();
                return local != null &&
                    _sameDay(local, _addCivilDays(weekStart, offset));
              })
              .toList(growable: false),
          onTap: () => onSelected(_addCivilDays(weekStart, offset)),
        ),
    ];
    return TerminalPanel(
      borderColor: tokens.structuralRed,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 680) {
            return Column(
              children: <Widget>[
                for (int index = 0; index < days.length; index++) ...<Widget>[
                  days[index],
                  if (index != days.length - 1)
                    const SizedBox(height: TerminalSpace.xs),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int index = 0; index < days.length; index++) ...<Widget>[
                Expanded(child: days[index]),
                if (index != days.length - 1)
                  const SizedBox(width: TerminalSpace.xs),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WeekDayTile extends StatelessWidget {
  const _WeekDayTile({
    required this.date,
    required this.selected,
    required this.today,
    required this.missions,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool today;
  final List<Mission> missions;
  final VoidCallback onTap;

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
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${_weekdayLabel(date)} ${date.day}, ${missions.length} misiones, '
          '$completed completadas',
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: TerminalMotion.resolve(context, TerminalMotion.quick),
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.all(TerminalSpace.sm),
          decoration: BoxDecoration(
            color: selected
                ? tokens.infoCyan.withValues(alpha: 0.12)
                : tokens.surfaceLow,
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
                _weekdayLabel(date).substring(0, 3).toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                '${date.day}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: selected ? tokens.infoCyan : tokens.textPrimary,
                ),
              ),
              Text(
                missions.isEmpty
                    ? 'Sin misiones'
                    : '${missions.length} · $completed listas',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
        ),
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
  return '${_monthName(date)} ${date.year}';
}

String _monthName(DateTime date) {
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
  return months[date.month - 1];
}

String _weekdayLabel(DateTime date) => const <String>[
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
][date.weekday - 1];

DateTime _shiftMonth(DateTime date, int delta) {
  final DateTime targetMonth = DateTime(date.year, date.month + delta);
  final int lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
  final int day = date.day > lastDay ? lastDay : date.day;
  return DateTime(targetMonth.year, targetMonth.month, day);
}

DateTime _startOfWeek(DateTime date) => DateTime(
  date.year,
  date.month,
  date.day - (date.weekday - DateTime.monday),
);

DateTime _addCivilDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

String _dateParameter(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
