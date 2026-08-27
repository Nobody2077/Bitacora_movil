import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/journal_providers.dart';
import '../domain/models/journal_entry.dart';
import 'journal_presentation_support.dart';

class JournalTimelinePage extends ConsumerStatefulWidget {
  const JournalTimelinePage({super.key});

  @override
  ConsumerState<JournalTimelinePage> createState() =>
      _JournalTimelinePageState();
}

class _JournalTimelinePageState extends ConsumerState<JournalTimelinePage> {
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    ref.watch(journalPhotoCleanupProvider);
    final JournalRange range = journalDayRange(_selectedDay);
    final AsyncValue<List<JournalEntry>> entries = ref.watch(
      journalEntriesProvider(range),
    );
    final bool compact = MediaQuery.sizeOf(context).width < 700;
    return ListView(
      padding: compact ? TerminalSpace.pageCompact : TerminalSpace.pageTablet,
      children: <Widget>[
        const TerminalPageHeader(
          title: 'Bitácora',
          subtitle: 'Memoria diaria local, privada y vinculada a tus acciones',
        ),
        const SizedBox(height: TerminalSpace.md),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            TerminalPrimaryButton(
              label: 'Nueva entrada',
              icon: Icons.edit_note,
              onPressed: () => context.pushNamed('journalNew'),
            ),
            TerminalOutlineButton(
              label: 'Buscar',
              icon: Icons.search,
              onPressed: () => context.pushNamed('journalSearch'),
            ),
            TerminalOutlineButton(
              label: 'Archivo',
              icon: Icons.inventory_2_outlined,
              onPressed: () => context.pushNamed('journalArchive'),
            ),
            TerminalOutlineButton(
              label: 'Hoy',
              icon: Icons.today_outlined,
              onPressed: journalSameDay(_selectedDay, DateTime.now())
                  ? null
                  : () => setState(() => _selectedDay = DateTime.now()),
            ),
          ],
        ),
        const SizedBox(height: TerminalSpace.md),
        _DayNavigator(
          selectedDay: _selectedDay,
          onPrevious: () => setState(
            () => _selectedDay = DateTime(
              _selectedDay.year,
              _selectedDay.month,
              _selectedDay.day - 1,
            ),
          ),
          onNext: journalSameDay(_selectedDay, DateTime.now())
              ? null
              : () => setState(
                  () => _selectedDay = DateTime(
                    _selectedDay.year,
                    _selectedDay.month,
                    _selectedDay.day + 1,
                  ),
                ),
        ),
        const SizedBox(height: TerminalSpace.md),
        entries.when(
          data: (List<JournalEntry> items) => _JournalDayContent(items: items),
          loading: () => const TerminalPanel(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => TerminalEmptyState(
            title: 'No se pudo abrir este día',
            description: 'Reintenta la lectura desde la base local cifrada.',
            icon: Icons.error_outline,
            action: TerminalOutlineButton(
              label: 'Reintentar',
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(journalEntriesProvider(range)),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayNavigator extends StatelessWidget {
  const _DayNavigator({
    required this.selectedDay,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime selectedDay;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Día anterior',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            color: tokens.terminalRed,
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  journalSameDay(selectedDay, DateTime.now())
                      ? 'HOY'
                      : 'DÍA SELECCIONADO',
                  style: TextStyle(
                    color: tokens.infoCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  journalDayLabel(selectedDay),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Día siguiente',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            color: tokens.terminalRed,
          ),
        ],
      ),
    );
  }
}

class _JournalDayContent extends StatelessWidget {
  const _JournalDayContent({required this.items});

  final List<JournalEntry> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return TerminalEmptyState(
        title: 'Este día aún está en blanco',
        description:
            'Registra una idea, una reflexión o un hecho importante del día.',
        icon: Icons.menu_book_outlined,
        action: TerminalPrimaryButton(
          label: 'Escribir entrada',
          icon: Icons.edit_outlined,
          onPressed: () => context.pushNamed('journalNew'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DaySummary(items: items),
        const SizedBox(height: TerminalSpace.md),
        const TerminalSectionTitle(
          overline: 'Cronología',
          title: 'Entradas del día',
          description: 'Ordenadas desde el registro más reciente.',
        ),
        const SizedBox(height: TerminalSpace.sm),
        for (final JournalEntry item in items) ...<Widget>[
          _JournalEntryCard(entry: item),
          const SizedBox(height: TerminalSpace.sm),
        ],
      ],
    );
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.items});

  final List<JournalEntry> items;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final int linked = items.where((JournalEntry item) => item.isLinked).length;
    final JournalMood? mood = _dominantMood(items);
    return TerminalPanel(
      borderColor: tokens.structuralRed,
      child: Wrap(
        spacing: 36,
        runSpacing: 20,
        children: <Widget>[
          TerminalMetric(
            icon: Icons.library_books_outlined,
            value: '${items.length}',
            label: items.length == 1 ? 'Entrada' : 'Entradas',
            color: tokens.infoCyan,
          ),
          TerminalMetric(
            icon: Icons.link,
            value: '$linked',
            label: 'Vinculadas',
            color: tokens.valueYellow,
          ),
          TerminalMetric(
            icon: journalMoodIcon(mood),
            value: journalMoodLabel(mood),
            label: 'Estado del día',
            color: _moodColor(tokens, mood),
          ),
        ],
      ),
    );
  }

  JournalMood? _dominantMood(List<JournalEntry> entries) {
    final Map<JournalMood, int> counts = <JournalMood, int>{};
    for (final JournalEntry entry in entries) {
      final JournalMood? mood = entry.mood;
      if (mood != null) {
        counts[mood] = (counts[mood] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) {
      return null;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

class _JournalEntryCard extends StatelessWidget {
  const _JournalEntryCard({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final Color originColor = _originColor(tokens, entry.origin);
    return TerminalCard(
      onTap: () => context.pushNamed(
        'journalDetail',
        pathParameters: <String, String>{'entryId': entry.id},
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            journalMoodIcon(entry.mood),
            color: _moodColor(tokens, entry.mood),
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      entry.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TerminalBadge(
                      label: journalOriginLabel(entry.origin),
                      color: originColor,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  journalBodyPreview(entry.body),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: <Widget>[
                    _Meta(
                      icon: Icons.schedule,
                      label: journalDateTimeLabel(entry.occurredAtUtc),
                    ),
                    _Meta(
                      icon: entry.isPrivate
                          ? Icons.lock_outline
                          : Icons.lock_open_outlined,
                      label: entry.isPrivate ? 'Privada' : 'Visible',
                    ),
                    if (entry.attachmentCount > 0)
                      _Meta(
                        icon: Icons.photo_outlined,
                        label: '${entry.attachmentCount}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: originColor),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15, color: tokens.textDisabled),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: tokens.textDisabled, fontSize: 12)),
      ],
    );
  }
}

Color _originColor(AppThemeTokens tokens, JournalOrigin origin) =>
    switch (origin) {
      JournalOrigin.manual => tokens.infoCyan,
      JournalOrigin.mission => tokens.progressGreen,
      JournalOrigin.transaction => tokens.valueYellow,
      JournalOrigin.system => tokens.textSecondary,
    };

Color _moodColor(AppThemeTokens tokens, JournalMood? mood) => switch (mood) {
  JournalMood.focused => tokens.progressGreen,
  JournalMood.normal => tokens.infoCyan,
  JournalMood.tired => tokens.attentionOrange,
  null => tokens.textDisabled,
};
