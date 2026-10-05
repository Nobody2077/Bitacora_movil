import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../contacts/application/contact_providers.dart';
import '../../contacts/presentation/contact_pages.dart';
import '../application/daily_close_application_service.dart';
import '../application/journal_providers.dart';
import '../domain/models/journal_entry.dart';
import 'journal_entry_view.dart';
import 'journal_presentation_support.dart';

/// Filtros del Diario por origen de la entrada (ADR-006 D18).
enum DiaryFilter {
  all('TODAS'),
  missions('MISIONES'),
  free('LIBRES'),
  movements('MOVIMIENTOS');

  const DiaryFilter(this.label);

  final String label;

  bool matches(JournalEntry entry) => switch (this) {
    DiaryFilter.all => true,
    DiaryFilter.missions => entry.origin == JournalOrigin.mission,
    DiaryFilter.free =>
      entry.origin == JournalOrigin.manual ||
          entry.origin == JournalOrigin.system,
    DiaryFilter.movements => entry.origin == JournalOrigin.transaction,
  };
}

/// DIARIO al estilo del juego (ADR-006 D18): en tablet, la lista continua
/// por fechas a la izquierda y la entrada abierta a la derecha; en teléfono,
/// la lista y la entrada a pantalla completa. Por dentro es la Bitácora.
class JournalDiaryView extends ConsumerStatefulWidget {
  const JournalDiaryView({super.key});

  /// Ancho desde el que la entrada se abre al lado de la lista.
  static const double twoColumnsFrom = 840;

  /// Entradas que se cargan cada vez.
  static const int pageSize = 100;

  @override
  ConsumerState<JournalDiaryView> createState() => _JournalDiaryViewState();
}

class _JournalDiaryViewState extends ConsumerState<JournalDiaryView> {
  bool _showContacts = false;
  DiaryFilter _filter = DiaryFilter.all;
  String? _selectedId;
  int _limit = JournalDiaryView.pageSize;

  @override
  Widget build(BuildContext context) {
    ref.watch(journalPhotoCleanupProvider);
    final AsyncValue<List<JournalEntry>> entries = ref.watch(
      journalTimelineProvider(_limit),
    );
    final int? contactCount = ref.watch(activeContactsProvider).value?.length;
    final List<JournalEntry>? loaded = entries.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Toolbar(
          showContacts: _showContacts,
          filter: _filter,
          entriesLabel: loaded == null
              ? 'ENTRADAS'
              : 'ENTRADAS · ${loaded.length}${loaded.length >= _limit ? '+' : ''}',
          contactsLabel: contactCount == null
              ? 'PERSONAJES'
              : 'PERSONAJES · $contactCount',
          onMode: (bool contacts) => setState(() => _showContacts = contacts),
          onFilter: (DiaryFilter filter) => setState(() => _filter = filter),
        ),
        Divider(
          height: 1,
          color: Theme.of(context).extension<AppThemeTokens>()!.border,
        ),
        Expanded(
          child: _showContacts
              ? ListView(
                  padding: TerminalSpace.pageTablet,
                  children: const <Widget>[ContactsSection()],
                )
              : entries.when(
                  data: (List<JournalEntry> items) => _entries(items),
                  loading: () => const TerminalLoadingState(
                    message: 'Cargando el Diario…',
                  ),
                  error: (_, _) => TerminalErrorState(
                    title: 'No se pudo abrir el Diario',
                    description:
                        'Reintenta la lectura desde la base local cifrada.',
                    onRetry: () =>
                        ref.invalidate(journalTimelineProvider(_limit)),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _entries(List<JournalEntry> items) {
    if (items.isEmpty) {
      return ListView(
        padding: TerminalSpace.pageTablet,
        children: <Widget>[
          TerminalEmptyState(
            title: 'Tu Diario está en blanco',
            description:
                'Registra una idea, una reflexión o un hecho importante. Las '
                'misiones y los movimientos también dejan aquí su entrada.',
            icon: Icons.menu_book_outlined,
            action: TerminalPrimaryButton(
              label: 'Escribir entrada',
              icon: Icons.edit_outlined,
              onPressed: () => context.pushNamed('journalNew'),
            ),
          ),
        ],
      );
    }
    final List<JournalEntry> visible = items
        .where(_filter.matches)
        .toList(growable: false);
    final bool canLoadMore = items.length >= _limit;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool twoColumns =
            constraints.maxWidth >= JournalDiaryView.twoColumnsFrom;
        final JournalEntry? selected = twoColumns ? _selectedIn(visible) : null;
        final Widget list = _DiaryList(
          entries: visible,
          selectedId: selected?.id,
          canLoadMore: canLoadMore,
          onLoadMore: () => setState(() => _limit += JournalDiaryView.pageSize),
          onOpen: (JournalEntry entry) {
            if (twoColumns) {
              setState(() => _selectedId = entry.id);
            } else {
              context.pushNamed(
                'journalDetail',
                pathParameters: <String, String>{'entryId': entry.id},
              );
            }
          },
        );
        if (!twoColumns) {
          return list;
        }
        final AppThemeTokens tokens = Theme.of(
          context,
        ).extension<AppThemeTokens>()!;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(width: 380, child: list),
            VerticalDivider(width: 1, color: tokens.structuralRed),
            Expanded(
              child: selected == null
                  ? Center(
                      child: Text(
                        'No hay entradas con este filtro.',
                        style: TextStyle(color: tokens.textSecondary),
                      ),
                    )
                  : SingleChildScrollView(
                      key: const Key('diary-entry-pane'),
                      padding: const EdgeInsets.fromLTRB(
                        TerminalSpace.lg,
                        TerminalSpace.md,
                        TerminalSpace.lg,
                        TerminalSpace.xl,
                      ),
                      child: JournalEntryView(
                        entry: selected,
                        onArchived: () => setState(() => _selectedId = null),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  /// La elegida si sigue visible; si no, la más reciente.
  JournalEntry? _selectedIn(List<JournalEntry> visible) {
    for (final JournalEntry entry in visible) {
      if (entry.id == _selectedId) return entry;
    }
    return visible.isEmpty ? null : visible.first;
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.showContacts,
    required this.filter,
    required this.entriesLabel,
    required this.contactsLabel,
    required this.onMode,
    required this.onFilter,
  });

  final bool showContacts;
  final DiaryFilter filter;
  final String entriesLabel;
  final String contactsLabel;
  final ValueChanged<bool> onMode;
  final ValueChanged<DiaryFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TerminalSpace.lg,
        TerminalSpace.sm,
        TerminalSpace.lg,
        TerminalSpace.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Wrap(
              spacing: TerminalSpace.xs,
              runSpacing: TerminalSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _Chip(
                  key: const Key('diary-mode-entries'),
                  label: entriesLabel,
                  selected: !showContacts,
                  color: tokens.valueYellow,
                  onPressed: () => onMode(false),
                ),
                _Chip(
                  key: const Key('diary-mode-contacts'),
                  label: contactsLabel,
                  selected: showContacts,
                  color: tokens.valueYellow,
                  onPressed: () => onMode(true),
                ),
                if (!showContacts) ...<Widget>[
                  SizedBox(
                    height: 24,
                    child: VerticalDivider(width: 12, color: tokens.border),
                  ),
                  for (final DiaryFilter value in DiaryFilter.values)
                    _Chip(
                      key: ValueKey<String>('diary-filter-${value.name}'),
                      label: value.label,
                      selected: value == filter,
                      color: tokens.infoCyan,
                      onPressed: () => onFilter(value),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(width: TerminalSpace.sm),
          if (!showContacts)
            Wrap(
              spacing: TerminalSpace.xs,
              children: <Widget>[
                _ToolIcon(
                  key: const Key('diary-search'),
                  tooltip: 'Buscar',
                  icon: Icons.search,
                  onPressed: () => context.pushNamed('journalSearch'),
                ),
                _ToolIcon(
                  key: const Key('diary-archive'),
                  tooltip: 'Archivo',
                  icon: Icons.inventory_2_outlined,
                  onPressed: () => context.pushNamed('journalArchive'),
                ),
                _ToolIcon(
                  key: const Key('diary-daily-close'),
                  tooltip: 'Cierre del día',
                  icon: Icons.assignment_turned_in_outlined,
                  onPressed: () => context.pushNamed(
                    'journalDailyClose',
                    pathParameters: <String, String>{
                      'date': dailyCloseDateKey(DateTime.now()),
                    },
                  ),
                ),
                _ToolIcon(
                  key: const Key('diary-new-entry'),
                  tooltip: 'Nueva entrada',
                  icon: Icons.add,
                  primary: true,
                  onPressed: () => context.pushNamed('journalNew'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? color : tokens.textSecondary,
          backgroundColor: selected ? color.withValues(alpha: 0.08) : null,
          side: BorderSide(color: selected ? color : tokens.border),
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: const RoundedRectangleBorder(),
          textStyle: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
    this.primary = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: tokens.infoCyan,
      style: IconButton.styleFrom(
        backgroundColor: primary
            ? tokens.infoCyan.withValues(alpha: 0.12)
            : null,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: primary ? tokens.infoCyan : tokens.border),
        ),
      ),
      icon: Icon(icon),
    );
  }
}

/// Un día de la lista: su etiqueta, su resumen y sus entradas.
typedef _DayGroup = ({DateTime day, List<JournalEntry> entries});

List<_DayGroup> _groupByDay(List<JournalEntry> entries) {
  final List<_DayGroup> groups = <_DayGroup>[];
  for (final JournalEntry entry in entries) {
    final DateTime local = entry.occurredAtUtc.toLocal();
    final DateTime day = DateTime(local.year, local.month, local.day);
    if (groups.isEmpty || groups.last.day != day) {
      groups.add((day: day, entries: <JournalEntry>[entry]));
    } else {
      groups.last.entries.add(entry);
    }
  }
  return groups;
}

/// «HOY», «AYER», «03 OCT» o, de otro año, «03 OCT 2025».
String diaryDayLabel(DateTime day, DateTime today) {
  const List<String> months = <String>[
    'ENE',
    'FEB',
    'MAR',
    'ABR',
    'MAY',
    'JUN',
    'JUL',
    'AGO',
    'SEP',
    'OCT',
    'NOV',
    'DIC',
  ];
  final DateTime todayDay = DateTime(today.year, today.month, today.day);
  if (day == todayDay) return 'HOY';
  if (day == DateTime(today.year, today.month, today.day - 1)) return 'AYER';
  final String base =
      '${day.day.toString().padLeft(2, '0')} ${months[day.month - 1]}';
  return day.year == today.year ? base : '$base ${day.year}';
}

/// «2 entradas · Motivado»: cuántas hay y el ánimo que más se repite.
String diaryDaySummary(List<JournalEntry> entries) {
  final Map<JournalMood, int> counts = <JournalMood, int>{};
  for (final JournalEntry entry in entries) {
    final JournalMood? mood = entry.mood;
    if (mood != null) counts[mood] = (counts[mood] ?? 0) + 1;
  }
  final String count = entries.length == 1
      ? '1 entrada'
      : '${entries.length} entradas';
  if (counts.isEmpty) return count;
  final JournalMood dominant = counts.entries
      .reduce((a, b) => a.value >= b.value ? a : b)
      .key;
  return '$count · ${journalMoodLabel(dominant)}';
}

class _DiaryList extends StatelessWidget {
  const _DiaryList({
    required this.entries,
    required this.selectedId,
    required this.canLoadMore,
    required this.onLoadMore,
    required this.onOpen,
  });

  final List<JournalEntry> entries;
  final String? selectedId;
  final bool canLoadMore;
  final VoidCallback onLoadMore;
  final ValueChanged<JournalEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final DateTime today = DateTime.now();
    final List<Widget> children = <Widget>[];
    for (final _DayGroup group in _groupByDay(entries)) {
      children.add(
        Container(
          key: ValueKey<String>('diary-day-${group.day.toIso8601String()}'),
          padding: const EdgeInsets.fromLTRB(2, TerminalSpace.sm, 2, 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Text(
                  diaryDayLabel(group.day, today),
                  style: TextStyle(
                    color: tokens.terminalRed,
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Text(
                diaryDaySummary(group.entries),
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
      for (final JournalEntry entry in group.entries) {
        children.add(
          _DiaryRow(
            entry: entry,
            selected: entry.id == selectedId,
            onTap: () => onOpen(entry),
          ),
        );
      }
    }
    if (entries.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(TerminalSpace.md),
          child: Text(
            'No hay entradas con este filtro.',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
      );
    }
    if (canLoadMore) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: TerminalSpace.md),
          child: TerminalOutlineButton(
            key: const Key('diary-load-more'),
            label: 'Cargar más',
            icon: Icons.expand_more,
            onPressed: onLoadMore,
          ),
        ),
      );
    }
    return ListView(
      key: const Key('diary-list'),
      padding: const EdgeInsets.fromLTRB(
        TerminalSpace.lg,
        TerminalSpace.xxs,
        TerminalSpace.sm,
        TerminalSpace.xl,
      ),
      children: children,
    );
  }
}

class _DiaryRow extends StatelessWidget {
  const _DiaryRow({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final JournalEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final (String mark, Color markColor) = switch (entry.origin) {
      JournalOrigin.mission => ('!', tokens.valueYellow),
      JournalOrigin.transaction => (r'$', tokens.progressGreen),
      JournalOrigin.manual || JournalOrigin.system => ('·', tokens.infoCyan),
    };
    final DateTime local = entry.occurredAtUtc.toLocal();
    final String time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    final String subtitle = entry.mood == null
        ? journalEntryKindLabel(entry.origin)
        : '${journalEntryKindLabel(entry.origin)} · '
              '${journalMoodLabel(entry.mood)}';
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey<String>('diary-entry-${entry.id}'),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? tokens.valueYellow.withValues(alpha: 0.10) : null,
            border: Border.all(
              color: selected ? tokens.valueYellow : Colors.transparent,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: markColor),
                ),
                child: Text(
                  mark,
                  style: TextStyle(
                    color: markColor,
                    fontFamily: 'JetBrains Mono',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: tokens.infoCyan,
                        letterSpacing: 0.8,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                time,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
