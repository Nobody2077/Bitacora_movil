import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../contacts/application/contact_providers.dart';
import '../../contacts/domain/models/contact.dart';
import '../../contacts/presentation/contact_widgets.dart';
import '../../economy/application/economy_providers.dart';
import '../../economy/domain/models/economy_models.dart';
import '../../economy/presentation/economy_presentation_support.dart';
import '../../missions/application/mission_providers.dart';
import '../../missions/domain/models/mission.dart';
import '../application/journal_application_service.dart';
import '../application/journal_providers.dart';
import '../domain/models/journal_entry.dart';
import 'journal_presentation_support.dart';

class JournalEntryFormPage extends ConsumerStatefulWidget {
  const JournalEntryFormPage({super.key, this.entryId, this.originHint});

  final String? entryId;
  final String? originHint;

  bool get isEditing => entryId != null;

  @override
  ConsumerState<JournalEntryFormPage> createState() =>
      _JournalEntryFormPageState();
}

class _JournalEntryFormPageState extends ConsumerState<JournalEntryFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  JournalOrigin _origin = JournalOrigin.manual;
  JournalMood? _mood;
  String? _sourceId;
  bool _isPrivate = true;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _initialized = false;
  bool _saving = false;

  /// `null` mientras el usuario no toque los personajes: al editar, guardar
  /// sin tocarlos no los cambia.
  Set<String>? _contactIds;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<JournalEntry?>? existingAsync = widget.entryId == null
        ? null
        : ref.watch(journalEntryDetailProvider(widget.entryId!));
    if (existingAsync?.isLoading == true) {
      return const TerminalAsyncStatePage(
        child: TerminalLoadingState(message: 'Preparando entrada de Bitácora…'),
      );
    }
    if (existingAsync?.hasError == true) {
      return TerminalAsyncStatePage(
        child: TerminalErrorState(
          title: 'Entrada no disponible',
          description: 'No se pudo preparar la entrada para editarla.',
          onRetry: () =>
              ref.invalidate(journalEntryDetailProvider(widget.entryId!)),
        ),
      );
    }
    if (widget.isEditing &&
        (existingAsync?.value == null ||
            existingAsync?.value?.isArchived == true)) {
      return const _JournalUnavailable(
        message: 'La entrada que deseas editar no está disponible.',
      );
    }
    final JournalEntry? existing = existingAsync?.value;
    _initialize(existing);

    final AsyncValue<List<Mission>>? missions =
        !widget.isEditing && _origin == JournalOrigin.mission
        ? ref.watch(allMissionsProvider)
        : null;
    final AsyncValue<List<EconomyTransaction>>? transactions =
        !widget.isEditing && _origin == JournalOrigin.transaction
        ? ref.watch(economyTransactionsProvider)
        : null;

    return JournalPageFrame(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TerminalPageHeader(
              title: widget.isEditing ? 'Editar entrada' : 'Nueva entrada',
              subtitle: widget.isEditing
                  ? 'Actualiza el registro sin perder su procedencia'
                  : 'Registra una reflexión o vincúlala con un hecho real',
            ),
            const SizedBox(height: TerminalSpace.md),
            TerminalPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    controller: _title,
                    autofocus: !widget.isEditing,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (String? value) {
                      final String normalized = value?.trim() ?? '';
                      return normalized.isEmpty ? 'Escribe un título.' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _body,
                    minLines: 5,
                    maxLines: 10,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: '¿Qué quieres recordar? (opcional)',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<JournalMood?>(
                    initialValue: _mood,
                    decoration: const InputDecoration(
                      labelText: 'Estado del momento',
                      prefixIcon: Icon(Icons.psychology_alt_outlined),
                    ),
                    items: <DropdownMenuItem<JournalMood?>>[
                      const DropdownMenuItem<JournalMood?>(
                        child: Text('Sin estado'),
                      ),
                      for (final JournalMood value in JournalMood.values)
                        DropdownMenuItem<JournalMood?>(
                          value: value,
                          child: Text(journalMoodLabel(value)),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (JournalMood? value) => setState(() => _mood = value),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Entrada privada'),
                    subtitle: const Text(
                      'Marca explícitamente este contenido como privado.',
                    ),
                    value: _isPrivate,
                    onChanged: _saving
                        ? null
                        : (bool value) => setState(() => _isPrivate = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TerminalSpace.md),
            TerminalPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'FECHA Y PROCEDENCIA',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).extension<AppThemeTokens>()!.infoCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          '${_date.day.toString().padLeft(2, '0')}/'
                          '${_date.month.toString().padLeft(2, '0')}/'
                          '${_date.year}',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickTime,
                        icon: const Icon(Icons.schedule),
                        label: Text(_time.format(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (widget.isEditing)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.link),
                      title: Text(journalOriginLabel(_origin)),
                      subtitle: const Text(
                        'La procedencia histórica no cambia al editar.',
                      ),
                    )
                  else ...<Widget>[
                    DropdownButtonFormField<JournalOrigin>(
                      initialValue: _origin,
                      decoration: const InputDecoration(
                        labelText: 'Vincular entrada',
                        prefixIcon: Icon(Icons.link),
                      ),
                      items: const <DropdownMenuItem<JournalOrigin>>[
                        DropdownMenuItem<JournalOrigin>(
                          value: JournalOrigin.manual,
                          child: Text('Sin vínculo · entrada manual'),
                        ),
                        DropdownMenuItem<JournalOrigin>(
                          value: JournalOrigin.mission,
                          child: Text('Vincular con una misión'),
                        ),
                        DropdownMenuItem<JournalOrigin>(
                          value: JournalOrigin.transaction,
                          child: Text('Vincular con un movimiento'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (JournalOrigin? value) {
                              if (value != null) {
                                setState(() {
                                  _origin = value;
                                  _sourceId = null;
                                });
                              }
                            },
                    ),
                    if (_origin == JournalOrigin.mission) ...<Widget>[
                      const SizedBox(height: 12),
                      _MissionSourceField(
                        value: _sourceId,
                        missions: missions!,
                        onRetry: () => ref.invalidate(allMissionsProvider),
                        onChanged: (String? value) =>
                            setState(() => _sourceId = value),
                      ),
                    ],
                    if (_origin == JournalOrigin.transaction) ...<Widget>[
                      const SizedBox(height: 12),
                      _TransactionSourceField(
                        value: _sourceId,
                        transactions: transactions!,
                        onRetry: () =>
                            ref.invalidate(economyTransactionsProvider),
                        onChanged: (String? value) =>
                            setState(() => _sourceId = value),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: TerminalSpace.md),
            TerminalPanel(child: _buildContactPicker()),
            const SizedBox(height: TerminalSpace.md),
            TerminalPanel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Fotografías privadas'),
                subtitle: Text(
                  widget.isEditing
                      ? 'Se administran desde el detalle para proteger el archivo cifrado.'
                      : 'Guarda primero la entrada y podrás adjuntar fotografías en su detalle.',
                ),
                trailing: widget.isEditing
                    ? const Icon(Icons.arrow_forward)
                    : const Icon(Icons.lock_outline),
                onTap: widget.isEditing && !_saving
                    ? () => context.goNamed(
                        'journalDetail',
                        pathParameters: <String, String>{
                          'entryId': widget.entryId!,
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: TerminalSpace.md),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                TerminalOutlineButton(
                  label: 'Cancelar',
                  icon: Icons.close,
                  color: Theme.of(
                    context,
                  ).extension<AppThemeTokens>()!.textSecondary,
                  onPressed: _saving ? null : _cancel,
                ),
                TerminalPrimaryButton(
                  label: _saving ? 'Guardando' : 'Guardar entrada',
                  icon: _saving ? Icons.hourglass_top : Icons.save_outlined,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactPicker() {
    final List<Contact> linked = widget.entryId == null
        ? const <Contact>[]
        : ref.watch(journalEntryOwnContactsProvider(widget.entryId!)).value ??
              const <Contact>[];
    return ContactPickerField(
      selectedIds:
          _contactIds ?? linked.map((Contact contact) => contact.id).toSet(),
      knownContacts: linked,
      enabled: !_saving,
      helper: 'Los personajes de la misión vinculada se suman solos.',
      onChanged: (Set<String> ids) => setState(() => _contactIds = ids),
    );
  }

  void _initialize(JournalEntry? existing) {
    if (_initialized) {
      return;
    }
    if (existing != null) {
      _title.text = existing.title;
      _body.text = existing.body ?? '';
      _mood = existing.mood;
      _origin = existing.origin;
      _sourceId = existing.missionId ?? existing.transactionId;
      _isPrivate = existing.isPrivate;
      final DateTime local = existing.occurredAtUtc.toLocal();
      _date = local;
      _time = TimeOfDay.fromDateTime(local);
    } else {
      _origin = switch (widget.originHint?.toLowerCase()) {
        'mission' => JournalOrigin.mission,
        'transaction' => JournalOrigin.transaction,
        _ => JournalOrigin.manual,
      };
    }
    _initialized = true;
  }

  Future<void> _pickDate() async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) {
      setState(() => _date = selected);
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (selected != null && mounted) {
      setState(() => _time = selected);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if ((_origin == JournalOrigin.mission ||
            _origin == JournalOrigin.transaction) &&
        _sourceId == null) {
      _showMessage('Selecciona el registro que deseas vincular.');
      return;
    }
    setState(() => _saving = true);
    final JournalEntry? existing = widget.entryId == null
        ? null
        : await ref.read(journalEntryDetailProvider(widget.entryId!).future);
    if (widget.isEditing && existing == null) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage('La entrada original ya no está disponible.');
      }
      return;
    }
    final Result<JournalEntry> result = await ref
        .read(journalApplicationServiceProvider)
        .save(
          SaveJournalEntryRequest(
            existing: existing,
            title: _title.text,
            body: _body.text,
            mood: _mood,
            isPrivate: _isPrivate,
            occurredAtUtc: DateTime(
              _date.year,
              _date.month,
              _date.day,
              _time.hour,
              _time.minute,
            ).toUtc(),
            origin: _origin,
            missionId: _origin == JournalOrigin.mission ? _sourceId : null,
            transactionId: _origin == JournalOrigin.transaction
                ? _sourceId
                : null,
            contactIds: _contactIds?.toList(),
          ),
        );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    result.fold<void>(
      onSuccess: (JournalEntry entry) {
        ref.invalidate(journalEntryDetailProvider(entry.id));
        ref.invalidate(journalEntryOwnContactsProvider(entry.id));
        context.goNamed(
          'journalDetail',
          pathParameters: <String, String>{'entryId': entry.id},
        );
      },
      onFailure: (failure) => _showMessage(failure.message),
    );
  }

  void _cancel() => context.canPop() ? context.pop() : goToDiary(context);

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MissionSourceField extends StatelessWidget {
  const _MissionSourceField({
    required this.value,
    required this.missions,
    required this.onRetry,
    required this.onChanged,
  });

  final String? value;
  final AsyncValue<List<Mission>> missions;
  final VoidCallback onRetry;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => missions.when(
    data: (List<Mission> items) => DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Misión de origen',
        prefixIcon: Icon(Icons.flag_outlined),
      ),
      items: <DropdownMenuItem<String>>[
        for (final Mission item in items)
          DropdownMenuItem<String>(
            value: item.id,
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      validator: (String? selected) =>
          selected == null ? 'Selecciona una misión.' : null,
      onChanged: onChanged,
    ),
    loading: () => const TerminalInlineLoadingState(
      message: 'Cargando misiones disponibles…',
    ),
    error: (_, _) => TerminalInlineErrorState(
      message: 'No se pudieron cargar las misiones.',
      onRetry: onRetry,
    ),
  );
}

class _TransactionSourceField extends StatelessWidget {
  const _TransactionSourceField({
    required this.value,
    required this.transactions,
    required this.onRetry,
    required this.onChanged,
  });

  final String? value;
  final AsyncValue<List<EconomyTransaction>> transactions;
  final VoidCallback onRetry;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => transactions.when(
    data: (List<EconomyTransaction> items) => DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Movimiento de origen',
        prefixIcon: Icon(Icons.receipt_long_outlined),
      ),
      items: <DropdownMenuItem<String>>[
        for (final EconomyTransaction item in items)
          DropdownMenuItem<String>(
            value: item.id,
            child: Text(
              '${item.category ?? economyTransactionTypeLabel(item.type)} · '
              '${economyMoney(context, item.isCredit ? item.amountMinor : -item.amountMinor, signed: true)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      validator: (String? selected) =>
          selected == null ? 'Selecciona un movimiento.' : null,
      onChanged: onChanged,
    ),
    loading: () => const TerminalInlineLoadingState(
      message: 'Cargando movimientos disponibles…',
    ),
    error: (_, _) => TerminalInlineErrorState(
      message: 'No se pudieron cargar los movimientos.',
      onRetry: onRetry,
    ),
  );
}

class _JournalUnavailable extends StatelessWidget {
  const _JournalUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => JournalPageFrame(
    child: TerminalEmptyState(
      title: 'Entrada no disponible',
      description: message,
      icon: Icons.error_outline,
      action: TerminalOutlineButton(
        label: 'Volver al Diario',
        icon: Icons.arrow_back,
        onPressed: () => goToDiary(context),
      ),
    ),
  );
}
