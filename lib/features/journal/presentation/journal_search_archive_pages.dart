import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/journal_providers.dart';
import '../domain/models/journal_entry.dart';
import 'journal_presentation_support.dart';

class JournalSearchPage extends ConsumerStatefulWidget {
  const JournalSearchPage({super.key});

  @override
  ConsumerState<JournalSearchPage> createState() => _JournalSearchPageState();
}

class _JournalSearchPageState extends ConsumerState<JournalSearchPage> {
  final TextEditingController _query = TextEditingController();
  final Set<JournalOrigin> _origins = <JournalOrigin>{};
  late DateTime _startDay;
  late DateTime _endDay;
  bool _withPhotosOnly = false;
  JournalSearchCriteria? _criteria;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _endDay = DateTime(now.year, now.month, now.day);
    _startDay = _endDay.subtract(const Duration(days: 29));
    _criteria = _currentCriteria();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final JournalSearchCriteria criteria = _criteria!;
    final AsyncValue<List<JournalEntry>> results = ref.watch(
      journalSearchProvider(criteria),
    );
    return JournalPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const TerminalPageHeader(
            title: 'Buscar en Bitácora',
            subtitle: 'Consulta privada por contenido, período y procedencia',
          ),
          const SizedBox(height: TerminalSpace.md),
          TerminalPanel(
            borderColor: tokens.infoCyan,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: _query,
                  maxLength: 160,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    labelText: 'Palabras en título o contenido',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => _pickDay(isStart: true),
                      icon: const Icon(Icons.first_page),
                      label: Text('Desde ${_dayLabel(_startDay)}'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickDay(isStart: false),
                      icon: const Icon(Icons.last_page),
                      label: Text('Hasta ${_dayLabel(_endDay)}'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'PROCEDENCIA',
                  style: TextStyle(
                    color: tokens.infoCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final JournalOrigin origin in JournalOrigin.values)
                      FilterChip(
                        label: Text(journalOriginLabel(origin)),
                        selected: _origins.contains(origin),
                        onSelected: (bool selected) {
                          setState(() {
                            selected
                                ? _origins.add(origin)
                                : _origins.remove(origin);
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Solo entradas con fotografías'),
                  subtitle: const Text(
                    'Comprueba los adjuntos activos sin descifrar archivos.',
                  ),
                  value: _withPhotosOnly,
                  onChanged: (bool value) =>
                      setState(() => _withPhotosOnly = value),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    TerminalOutlineButton(
                      label: 'Restablecer',
                      icon: Icons.restart_alt,
                      color: tokens.textSecondary,
                      onPressed: _reset,
                    ),
                    TerminalPrimaryButton(
                      label: 'Buscar',
                      icon: Icons.search,
                      onPressed: _search,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: TerminalSpace.md),
          results.when(
            data: (List<JournalEntry> entries) => _SearchResults(
              entries: entries,
              onBack: () => goToDiary(context),
            ),
            loading: () =>
                const TerminalLoadingState(message: 'Buscando en la Bitácora…'),
            error: (_, _) => TerminalErrorState(
              title: 'No se pudo completar la búsqueda',
              description: 'Revisa los filtros e inténtalo nuevamente.',
              onRetry: () => ref.invalidate(journalSearchProvider(criteria)),
            ),
          ),
        ],
      ),
    );
  }

  JournalSearchCriteria _currentCriteria() => JournalSearchCriteria(
    startUtc: DateTime(_startDay.year, _startDay.month, _startDay.day).toUtc(),
    endUtc: DateTime(_endDay.year, _endDay.month, _endDay.day + 1).toUtc(),
    query: _query.text.trim(),
    origins: _origins,
    withPhotosOnly: _withPhotosOnly,
  );

  void _search() => setState(() => _criteria = _currentCriteria());

  void _reset() {
    final DateTime now = DateTime.now();
    setState(() {
      _query.clear();
      _origins.clear();
      _withPhotosOnly = false;
      _endDay = DateTime(now.year, now.month, now.day);
      _startDay = _endDay.subtract(const Duration(days: 29));
      _criteria = _currentCriteria();
    });
  }

  Future<void> _pickDay({required bool isStart}) async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDay : _endDay,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      if (isStart) {
        _startDay = selected;
        if (_startDay.isAfter(_endDay)) {
          _endDay = selected;
        }
      } else {
        _endDay = selected;
        if (_endDay.isBefore(_startDay)) {
          _startDay = selected;
        }
      }
    });
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.entries, required this.onBack});

  final List<JournalEntry> entries;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return TerminalEmptyState(
        title: 'Sin coincidencias',
        description: 'Amplía el período o elimina algún filtro.',
        icon: Icons.manage_search,
        action: TerminalOutlineButton(
          label: 'Volver al Diario',
          icon: Icons.arrow_back,
          onPressed: onBack,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TerminalSectionTitle(
          overline: '${entries.length} coincidencias',
          title: 'Resultados',
          description: 'Ordenados desde la entrada más reciente.',
        ),
        const SizedBox(height: TerminalSpace.sm),
        for (final JournalEntry entry in entries) ...<Widget>[
          _JournalResultCard(entry: entry),
          const SizedBox(height: TerminalSpace.sm),
        ],
      ],
    );
  }
}

class JournalArchivePage extends ConsumerWidget {
  const JournalArchivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<JournalEntry>> entries = ref.watch(
      archivedJournalEntriesProvider,
    );
    return JournalPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const TerminalPageHeader(
            title: 'Archivo de Bitácora',
            subtitle: 'Entradas ocultas de la cronología, sin borrar historia',
          ),
          const SizedBox(height: TerminalSpace.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TerminalOutlineButton(
              label: 'Volver al Diario',
              icon: Icons.arrow_back,
              onPressed: () => goToDiary(context),
            ),
          ),
          const SizedBox(height: TerminalSpace.md),
          entries.when(
            data: (List<JournalEntry> items) => items.isEmpty
                ? const TerminalEmptyState(
                    title: 'El archivo está vacío',
                    description:
                        'Las entradas archivadas aparecerán aquí y podrán restaurarse.',
                    icon: Icons.inventory_2_outlined,
                  )
                : Column(
                    children: <Widget>[
                      for (final JournalEntry entry in items) ...<Widget>[
                        _ArchivedEntryCard(
                          entry: entry,
                          onRestore: () => _restore(context, ref, entry),
                        ),
                        const SizedBox(height: TerminalSpace.sm),
                      ],
                    ],
                  ),
            loading: () => const TerminalLoadingState(
              message: 'Cargando archivo de Bitácora…',
            ),
            error: (_, _) => TerminalErrorState(
              title: 'No se pudo abrir el archivo',
              description: 'Reintenta la lectura desde la base local.',
              onRetry: () => ref.invalidate(archivedJournalEntriesProvider),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    JournalEntry entry,
  ) async {
    final Result<JournalEntry> result = await ref
        .read(journalApplicationServiceProvider)
        .restore(entry);
    if (!context.mounted) {
      return;
    }
    result.fold<void>(
      onSuccess: (_) {
        ref.invalidate(archivedJournalEntriesProvider);
        ref.invalidate(journalEntryDetailProvider(entry.id));
        ref.invalidate(journalEntriesProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Entrada restaurada.')));
      },
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }
}

class _JournalResultCard extends StatelessWidget {
  const _JournalResultCard({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalCard(
      onTap: () => context.pushNamed(
        'journalDetail',
        pathParameters: <String, String>{'entryId': entry.id},
      ),
      child: Row(
        children: <Widget>[
          Icon(journalMoodIcon(entry.mood), color: tokens.infoCyan),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  journalBodyPreview(entry.body),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  '${journalDateTimeLabel(entry.occurredAtUtc)} · '
                  '${journalOriginLabel(entry.origin)}'
                  '${entry.attachmentCount > 0 ? ' · ${entry.attachmentCount} foto(s)' : ''}',
                  style: TextStyle(color: tokens.textDisabled, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: tokens.infoCyan),
        ],
      ),
    );
  }
}

class _ArchivedEntryCard extends StatelessWidget {
  const _ArchivedEntryCard({required this.entry, required this.onRestore});

  final JournalEntry entry;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(entry.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Archivada ${journalDateTimeLabel(entry.archivedAtUtc!)} · '
            '${journalOriginLabel(entry.origin)}',
            style: TextStyle(color: tokens.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              TerminalPrimaryButton(
                label: 'Restaurar',
                icon: Icons.restore,
                onPressed: onRestore,
              ),
              TerminalOutlineButton(
                label: 'Ver entrada',
                icon: Icons.open_in_new,
                onPressed: () => context.pushNamed(
                  'journalDetail',
                  pathParameters: <String, String>{'entryId': entry.id},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _dayLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';
