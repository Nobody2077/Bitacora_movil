import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/persistence_providers.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../features/missions/application/mission_providers.dart';
import '../../../features/missions/domain/models/mission.dart';
import '../../../features/missions/presentation/mission_presentation_support.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/recurrence_application_service.dart';
import '../application/recurrence_providers.dart';
import '../domain/models/recurrence_template.dart';

class RecurrenceFormPage extends ConsumerStatefulWidget {
  const RecurrenceFormPage({super.key, this.templateId});

  final String? templateId;

  bool get isEditing => templateId != null;

  @override
  ConsumerState<RecurrenceFormPage> createState() => _RecurrenceFormPageState();
}

class _RecurrenceFormPageState extends ConsumerState<RecurrenceFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _xpController = TextEditingController(text: '25');
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _intervalController = TextEditingController(
    text: '1',
  );
  final List<_ObjectiveEditor> _objectives = <_ObjectiveEditor>[];

  RecurrenceTemplate? _existing;
  String? _areaId;
  MissionType _type = MissionType.recurring;
  MissionImportance _importance = MissionImportance.normal;
  MissionPriority _priority = MissionPriority.normal;
  MissionDifficulty? _difficulty;
  bool _isRequired = false;
  RecurrenceFrequency _frequency = RecurrenceFrequency.daily;
  int _weekdaysMask = 0x1F; // lunes–viernes por defecto
  TimeOfDay? _localTime;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _xpController.dispose();
    _durationController.dispose();
    _budgetController.dispose();
    _intervalController.dispose();
    for (final o in _objectives) {
      o.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<MissionArea>> areas = ref.watch(missionAreasProvider);
    final AsyncValue<RecurrenceTemplate?>? existing = widget.isEditing
        ? ref.watch(templateDetailProvider(widget.templateId!))
        : null;

    if (areas.isLoading || existing?.isLoading == true) {
      return const Center(child: CircularProgressIndicator());
    }
    if (areas.hasError || existing?.hasError == true) {
      return _FormUnavailable(
        message: 'No se pudieron cargar los datos de la plantilla.',
        onBack: _cancel,
      );
    }

    final List<MissionArea> availableAreas =
        areas.value ?? const <MissionArea>[];
    final RecurrenceTemplate? template = existing?.value;
    if (widget.isEditing && template == null) {
      return _FormUnavailable(
        message: 'La plantilla que intentas editar ya no existe.',
        onBack: _cancel,
      );
    }
    _initialize(availableAreas, template);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 850;
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TerminalPageHeader(
                      title: widget.isEditing
                          ? 'Editar plantilla'
                          : 'Nueva plantilla recurrente',
                      subtitle: widget.isEditing
                          ? 'Actualiza la configuración de recurrencia'
                          : 'Define la misión que se repetirá automáticamente',
                    ),
                    const SizedBox(height: 22),
                    if (compact) ...<Widget>[
                      _InfoPanel(
                        titleController: _titleController,
                        descriptionController: _descriptionController,
                        areas: availableAreas,
                        areaId: _areaId,
                        type: _type,
                        importance: _importance,
                        priority: _priority,
                        difficulty: _difficulty,
                        isRequired: _isRequired,
                        onAreaChanged: (v) => setState(() => _areaId = v),
                        onTypeChanged: (v) => setState(() => _type = v),
                        onImportanceChanged: (v) {
                          setState(() {
                            _importance = v;
                            if (!widget.isEditing) {
                              _xpController.text = _suggestedXp(v).toString();
                            }
                          });
                        },
                        onPriorityChanged: (v) => setState(() => _priority = v),
                        onDifficultyChanged: (v) =>
                            setState(() => _difficulty = v),
                        onRequiredChanged: (v) =>
                            setState(() => _isRequired = v),
                      ),
                      const SizedBox(height: 18),
                      _RecurrencePanel(
                        frequency: _frequency,
                        intervalController: _intervalController,
                        weekdaysMask: _weekdaysMask,
                        localTime: _localTime,
                        startDate: _startDate,
                        endDate: _endDate,
                        xpController: _xpController,
                        durationController: _durationController,
                        budgetController: _budgetController,
                        onFrequencyChanged: (v) =>
                            setState(() => _frequency = v),
                        onWeekdayMaskChanged: (v) =>
                            setState(() => _weekdaysMask = v),
                        onPickTime: _pickLocalTime,
                        onClearTime: () => setState(() => _localTime = null),
                        onPickStartDate: _pickStartDate,
                        onPickEndDate: _pickEndDate,
                        onClearEndDate: () => setState(() => _endDate = null),
                      ),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            flex: 3,
                            child: _InfoPanel(
                              titleController: _titleController,
                              descriptionController: _descriptionController,
                              areas: availableAreas,
                              areaId: _areaId,
                              type: _type,
                              importance: _importance,
                              priority: _priority,
                              difficulty: _difficulty,
                              isRequired: _isRequired,
                              onAreaChanged: (v) => setState(() => _areaId = v),
                              onTypeChanged: (v) => setState(() => _type = v),
                              onImportanceChanged: (v) {
                                setState(() {
                                  _importance = v;
                                  if (!widget.isEditing) {
                                    _xpController.text = _suggestedXp(
                                      v,
                                    ).toString();
                                  }
                                });
                              },
                              onPriorityChanged: (v) =>
                                  setState(() => _priority = v),
                              onDifficultyChanged: (v) =>
                                  setState(() => _difficulty = v),
                              onRequiredChanged: (v) =>
                                  setState(() => _isRequired = v),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 2,
                            child: _RecurrencePanel(
                              frequency: _frequency,
                              intervalController: _intervalController,
                              weekdaysMask: _weekdaysMask,
                              localTime: _localTime,
                              startDate: _startDate,
                              endDate: _endDate,
                              xpController: _xpController,
                              durationController: _durationController,
                              budgetController: _budgetController,
                              onFrequencyChanged: (v) =>
                                  setState(() => _frequency = v),
                              onWeekdayMaskChanged: (v) =>
                                  setState(() => _weekdaysMask = v),
                              onPickTime: _pickLocalTime,
                              onClearTime: () =>
                                  setState(() => _localTime = null),
                              onPickStartDate: _pickStartDate,
                              onPickEndDate: _pickEndDate,
                              onClearEndDate: () =>
                                  setState(() => _endDate = null),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    _ObjectivesPanel(
                      objectives: _objectives,
                      onAdd: _addObjective,
                      onRemove: _removeObjective,
                    ),
                    const SizedBox(height: 18),
                    _FormActions(
                      saving: _saving,
                      editing: widget.isEditing,
                      onCancel: _saving ? null : _cancel,
                      onSave: _saving ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _initialize(List<MissionArea> areas, RecurrenceTemplate? existing) {
    if (_initialized) {
      return;
    }
    _existing = existing;
    _areaId =
        existing?.areaId ??
        _defaultArea(areas)?.id ??
        (areas.isEmpty ? null : areas.first.id);

    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = existing.description ?? '';
      _xpController.text = existing.xpReward.toString();
      _durationController.text = existing.estimatedMinutes?.toString() ?? '';
      _budgetController.text = existing.budgetMinor == null
          ? ''
          : missionMoneyLabel(existing.budgetMinor!);
      _type = existing.missionType;
      _importance = existing.importance;
      _priority = existing.priority;
      _difficulty = existing.difficulty;
      _isRequired = existing.isRequired;

      final RecurrenceRule? rule = existing.rule;
      if (rule != null) {
        _frequency = rule.frequency;
        _intervalController.text = rule.intervalValue.toString();
        _weekdaysMask = rule.weekdaysMask ?? 0x1F;
        if (rule.localTimeMinutes != null) {
          _localTime = TimeOfDay(
            hour: rule.localTimeMinutes! ~/ 60,
            minute: rule.localTimeMinutes! % 60,
          );
        }
        _startDate = DateTime.parse(rule.startDate);
        if (rule.endDate != null) {
          _endDate = DateTime.parse(rule.endDate!);
        }
      }

      _objectives.addAll(
        existing.objectives.map(
          (o) => _ObjectiveEditor(
            controller: TextEditingController(text: o.description),
            id: o.id,
          ),
        ),
      );
    }
    _initialized = true;
  }

  MissionArea? _defaultArea(List<MissionArea> areas) {
    for (final a in areas) {
      if (a.isDefault) return a;
    }
    return null;
  }

  void _addObjective() {
    setState(
      () => _objectives.add(
        _ObjectiveEditor(controller: TextEditingController()),
      ),
    );
  }

  void _removeObjective(int index) {
    setState(() {
      final _ObjectiveEditor removed = _objectives.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _pickLocalTime() async {
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: _localTime ?? TimeOfDay.now(),
    );
    if (selected != null && mounted) {
      setState(() => _localTime = selected);
    }
  }

  Future<void> _pickStartDate() async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) {
      setState(() => _startDate = selected);
    }
  }

  Future<void> _pickEndDate() async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) {
      setState(() => _endDate = selected);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _areaId == null) {
      return;
    }
    if (_frequency == RecurrenceFrequency.specificDays && _weekdaysMask == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un día de la semana.'),
        ),
      );
      return;
    }

    final int interval = int.parse(_intervalController.text.trim());
    final int xp = int.parse(_xpController.text.trim());
    final int? duration = _optionalInt(_durationController.text);
    final int? budgetMinor = _optionalMoneyMinor(_budgetController.text);
    final int? localTimeMinutes = _localTime == null
        ? null
        : _localTime!.hour * 60 + _localTime!.minute;

    late final String timezone;
    try {
      timezone = await ref
          .read(recurrenceCivilTimeProvider)
          .currentTimeZoneId();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo determinar la zona horaria del equipo.'),
          ),
        );
      }
      return;
    }

    setState(() => _saving = true);

    final Result<RecurrenceTemplate> result = await ref
        .read(recurrenceApplicationServiceProvider)
        .saveTemplate(
          SaveTemplateRequest(
            existing: _existing,
            areaId: _areaId!,
            title: _titleController.text,
            description: _descriptionController.text,
            missionType: _type,
            importance: _importance,
            priority: _priority,
            difficulty: _difficulty,
            isRequired: _isRequired,
            xpReward: xp,
            estimatedMinutes: duration,
            budgetMinor: budgetMinor,
            frequency: _frequency,
            intervalValue: interval,
            weekdaysMask: _frequency == RecurrenceFrequency.specificDays
                ? _weekdaysMask
                : null,
            localTimeMinutes: localTimeMinutes,
            startDate: _dateToString(_startDate),
            endDate: _endDate == null ? null : _dateToString(_endDate!),
            timezoneId: timezone,
            objectives: <RecurrenceObjectiveDraft>[
              for (final o in _objectives)
                RecurrenceObjectiveDraft(
                  id: o.id,
                  description: o.controller.text,
                ),
            ],
          ),
        );

    if (!mounted) return;
    setState(() => _saving = false);

    result.fold<void>(
      onSuccess: (template) {
        unawaited(
          ref
              .read(recurrenceApplicationServiceProvider)
              .generatePendingOccurrences()
              .then(
                (_) => ref
                    .read(notificationReconciliationServiceProvider)
                    .reconcile(),
              ),
        );
        ref.invalidate(allTemplatesProvider);
        ref.invalidate(activeTemplatesProvider);
        context.goNamed('missionsRecurring');
      },
      onFailure: (AppFailure failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  void _cancel() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('missionsRecurring');
    }
  }

  static String _dateToString(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static int? _optionalInt(String value) {
    final String t = value.trim();
    return t.isEmpty ? null : int.tryParse(t);
  }

  static int? _optionalMoneyMinor(String value) {
    final String n = value.trim().replaceAll(',', '.');
    if (n.isEmpty) return null;
    final double? amount = double.tryParse(n);
    return amount == null ? null : (amount * 100).round();
  }

  static int _suggestedXp(MissionImportance importance) => switch (importance) {
    MissionImportance.minor => 10,
    MissionImportance.normal => 25,
    MissionImportance.important => 50,
    MissionImportance.veryImportant => 80,
    MissionImportance.critical => 100,
  };
}

// ── Widgets internos ────────────────────────────────────────────────────────

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.titleController,
    required this.descriptionController,
    required this.areas,
    required this.areaId,
    required this.type,
    required this.importance,
    required this.priority,
    required this.isRequired,
    required this.onAreaChanged,
    required this.onTypeChanged,
    required this.onImportanceChanged,
    required this.onPriorityChanged,
    required this.onRequiredChanged,
    this.difficulty,
    this.onDifficultyChanged,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final List<MissionArea> areas;
  final String? areaId;
  final MissionType type;
  final MissionImportance importance;
  final MissionPriority priority;
  final MissionDifficulty? difficulty;
  final bool isRequired;
  final ValueChanged<String?> onAreaChanged;
  final ValueChanged<MissionType> onTypeChanged;
  final ValueChanged<MissionImportance> onImportanceChanged;
  final ValueChanged<MissionPriority> onPriorityChanged;
  final ValueChanged<MissionDifficulty?>? onDifficultyChanged;
  final ValueChanged<bool> onRequiredChanged;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      borderColor: tokens.structuralRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PanelTitle(label: 'Información', icon: Icons.info_outline),
          const SizedBox(height: 16),
          TextFormField(
            controller: titleController,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'Título'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Escribe un título.'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: areaId,
            decoration: const InputDecoration(labelText: 'Área'),
            items: <DropdownMenuItem<String>>[
              for (final area in areas)
                DropdownMenuItem<String>(
                  value: area.id,
                  child: Text(area.name),
                ),
            ],
            onChanged: onAreaChanged,
            validator: (value) => value == null ? 'Selecciona un área.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MissionImportance>(
            initialValue: importance,
            decoration: const InputDecoration(labelText: 'Importancia'),
            items: <DropdownMenuItem<MissionImportance>>[
              for (final v in MissionImportance.values)
                DropdownMenuItem<MissionImportance>(
                  value: v,
                  child: Text(missionImportanceLabel(v)),
                ),
            ],
            onChanged: (v) {
              if (v != null) onImportanceChanged(v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MissionPriority>(
            initialValue: priority,
            decoration: const InputDecoration(labelText: 'Prioridad'),
            items: <DropdownMenuItem<MissionPriority>>[
              for (final v in MissionPriority.values)
                DropdownMenuItem<MissionPriority>(
                  value: v,
                  child: Text(missionPriorityLabel(v)),
                ),
            ],
            onChanged: (v) {
              if (v != null) onPriorityChanged(v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MissionType>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: <DropdownMenuItem<MissionType>>[
              for (final v in MissionType.values)
                DropdownMenuItem<MissionType>(
                  value: v,
                  child: Text(missionTypeLabel(v)),
                ),
            ],
            onChanged: (v) {
              if (v != null) onTypeChanged(v);
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Misión obligatoria'),
            value: isRequired,
            onChanged: onRequiredChanged,
          ),
        ],
      ),
    );
  }
}

class _RecurrencePanel extends StatelessWidget {
  const _RecurrencePanel({
    required this.frequency,
    required this.intervalController,
    required this.weekdaysMask,
    required this.startDate,
    required this.xpController,
    required this.durationController,
    required this.budgetController,
    required this.onFrequencyChanged,
    required this.onWeekdayMaskChanged,
    required this.onPickTime,
    required this.onClearTime,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onClearEndDate,
    this.localTime,
    this.endDate,
  });

  final RecurrenceFrequency frequency;
  final TextEditingController intervalController;
  final int weekdaysMask;
  final TimeOfDay? localTime;
  final DateTime startDate;
  final DateTime? endDate;
  final TextEditingController xpController;
  final TextEditingController durationController;
  final TextEditingController budgetController;
  final ValueChanged<RecurrenceFrequency> onFrequencyChanged;
  final ValueChanged<int> onWeekdayMaskChanged;
  final VoidCallback onPickTime;
  final VoidCallback onClearTime;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onClearEndDate;

  static const List<_WeekdayOption> _weekdays = <_WeekdayOption>[
    _WeekdayOption(label: 'L', bit: 0),
    _WeekdayOption(label: 'M', bit: 1),
    _WeekdayOption(label: 'X', bit: 2),
    _WeekdayOption(label: 'J', bit: 3),
    _WeekdayOption(label: 'V', bit: 4),
    _WeekdayOption(label: 'S', bit: 5),
    _WeekdayOption(label: 'D', bit: 6),
  ];

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PanelTitle(label: 'Recurrencia', icon: Icons.repeat),
          const SizedBox(height: 16),
          DropdownButtonFormField<RecurrenceFrequency>(
            initialValue: frequency,
            decoration: const InputDecoration(labelText: 'Frecuencia'),
            items: <DropdownMenuItem<RecurrenceFrequency>>[
              for (final v in RecurrenceFrequency.values)
                DropdownMenuItem<RecurrenceFrequency>(
                  value: v,
                  child: Text(_frequencyLabel(v)),
                ),
            ],
            onChanged: (v) {
              if (v != null) onFrequencyChanged(v);
            },
          ),
          const SizedBox(height: 12),
          if (frequency != RecurrenceFrequency.specificDays) ...<Widget>[
            TextFormField(
              controller: intervalController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cada cuántos ${_intervalUnit(frequency)}',
              ),
              validator: (v) {
                final int? n = int.tryParse(v?.trim() ?? '');
                return n == null || n < 1 ? 'Debe ser al menos 1.' : null;
              },
            ),
            const SizedBox(height: 12),
          ],
          if (frequency == RecurrenceFrequency.specificDays) ...<Widget>[
            Text(
              'DÍAS DE LA SEMANA',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tokens.infoCyan,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final day in _weekdays)
                  _DayToggle(
                    label: day.label,
                    selected: (weekdaysMask & (1 << day.bit)) != 0,
                    onToggle: () {
                      onWeekdayMaskChanged(weekdaysMask ^ (1 << day.bit));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // Fecha de inicio
          OutlinedButton.icon(
            onPressed: onPickStartDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('Desde: ${_dateLabel(startDate)}'),
          ),
          const SizedBox(height: 10),
          // Fecha de fin (opcional)
          if (endDate != null) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickEndDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text('Hasta: ${_dateLabel(endDate!)}'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Sin fecha de fin',
                  icon: const Icon(Icons.close),
                  onPressed: onClearEndDate,
                ),
              ],
            ),
          ] else
            TextButton.icon(
              onPressed: onPickEndDate,
              icon: const Icon(Icons.event_outlined),
              label: const Text('Añadir fecha de fin (opcional)'),
            ),
          const SizedBox(height: 10),
          // Hora local (opcional)
          if (localTime != null) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickTime,
                    icon: const Icon(Icons.schedule),
                    label: Text('Hora: ${localTime!.format(context)}'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Sin hora fija',
                  icon: const Icon(Icons.close),
                  onPressed: onClearTime,
                ),
              ],
            ),
          ] else
            TextButton.icon(
              onPressed: onPickTime,
              icon: const Icon(Icons.schedule),
              label: const Text('Fijar hora (opcional)'),
            ),
          const SizedBox(height: 14),
          // XP, duración, presupuesto
          TextFormField(
            controller: xpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Recompensa',
              suffixText: 'XP',
            ),
            validator: (v) {
              final int? n = int.tryParse(v?.trim() ?? '');
              return n == null || n < 0 ? 'Escribe un XP válido.' : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: durationController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Duración estimada',
              suffixText: 'min',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final int? n = int.tryParse(v.trim());
              return n == null || n <= 0 ? 'Debe ser mayor que cero.' : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: budgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Presupuesto',
              prefixText: 'Bs ',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final double? n = double.tryParse(v.trim().replaceAll(',', '.'));
              return n == null || n < 0 ? 'Importe inválido.' : null;
            },
          ),
        ],
      ),
    );
  }

  static String _frequencyLabel(RecurrenceFrequency v) => switch (v) {
    RecurrenceFrequency.daily => 'Diaria',
    RecurrenceFrequency.weekly => 'Semanal',
    RecurrenceFrequency.specificDays => 'Días específicos',
    RecurrenceFrequency.everyNDays => 'Cada N días',
  };

  static String _intervalUnit(RecurrenceFrequency v) => switch (v) {
    RecurrenceFrequency.daily => 'días',
    RecurrenceFrequency.weekly => 'semanas',
    RecurrenceFrequency.everyNDays => 'días',
    RecurrenceFrequency.specificDays => 'días',
  };

  static String _dateLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.label,
    required this.selected,
    required this.onToggle,
  });

  final String label;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return InkWell(
      onTap: onToggle,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? tokens.infoCyan : Colors.transparent,
          border: Border.all(color: selected ? tokens.infoCyan : tokens.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ObjectivesPanel extends StatelessWidget {
  const _ObjectivesPanel({
    required this.objectives,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_ObjectiveEditor> objectives;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) => TerminalPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _PanelTitle(
          label: 'Objetivos por defecto',
          icon: Icons.checklist,
        ),
        const SizedBox(height: 6),
        const Text(
          'Estos objetivos se copiarán a cada ocurrencia generada.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < objectives.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 14, right: 10),
                  child: Text('${i + 1}'.padLeft(2, '0')),
                ),
                Expanded(
                  child: TextFormField(
                    controller: objectives[i].controller,
                    maxLength: 240,
                    decoration: const InputDecoration(
                      labelText: 'Descripción del objetivo',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Escribe el objetivo o elimínalo.'
                        : null,
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: () => onRemove(i),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        TerminalOutlineButton(
          label: 'Añadir objetivo',
          icon: Icons.add,
          onPressed: onAdd,
        ),
      ],
    ),
  );
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.label, required this.icon});

  final String label;
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
          label.toUpperCase(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: tokens.infoCyan,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _FormActions extends StatelessWidget {
  const _FormActions({
    required this.saving,
    required this.editing,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final bool editing;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) => TerminalPanel(
    child: Wrap(
      alignment: WrapAlignment.end,
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        TerminalOutlineButton(
          label: 'Cancelar',
          icon: Icons.close,
          color: Colors.white60,
          onPressed: onCancel,
        ),
        TerminalPrimaryButton(
          label: saving
              ? 'Guardando'
              : editing
              ? 'Guardar cambios'
              : 'Crear plantilla',
          icon: saving ? Icons.hourglass_top : Icons.save_outlined,
          onPressed: onSave,
        ),
      ],
    ),
  );
}

class _FormUnavailable extends StatelessWidget {
  const _FormUnavailable({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: TerminalPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 16),
            TerminalPrimaryButton(
              label: 'Volver',
              icon: Icons.arrow_back,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    ),
  );
}

final class _ObjectiveEditor {
  _ObjectiveEditor({required this.controller, this.id});

  final TextEditingController controller;
  final String? id;

  void dispose() => controller.dispose();
}

final class _WeekdayOption {
  const _WeekdayOption({required this.label, required this.bit});

  final String label;
  final int bit;
}
