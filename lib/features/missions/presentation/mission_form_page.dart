import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/mission_application_service.dart';
import '../application/mission_providers.dart';
import '../domain/models/mission.dart';
import 'mission_presentation_support.dart';

class MissionFormPage extends ConsumerStatefulWidget {
  const MissionFormPage({super.key, this.missionId});

  final String? missionId;

  bool get isEditing => missionId != null;

  @override
  ConsumerState<MissionFormPage> createState() => _MissionFormPageState();
}

class _MissionFormPageState extends ConsumerState<MissionFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _xpController = TextEditingController(text: '25');
  final List<_ObjectiveEditor> _objectives = <_ObjectiveEditor>[];

  Mission? _existing;
  String? _areaId;
  MissionType _type = MissionType.custom;
  MissionImportance _importance = MissionImportance.normal;
  MissionPriority _priority = MissionPriority.normal;
  bool _isRequired = false;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _budgetController.dispose();
    _xpController.dispose();
    for (final objective in _objectives) {
      objective.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<MissionArea>> areas = ref.watch(missionAreasProvider);
    final AsyncValue<Mission?>? mission = widget.missionId == null
        ? null
        : ref.watch(missionDetailProvider(widget.missionId!));

    if (areas.isLoading || mission?.isLoading == true) {
      return const Center(child: CircularProgressIndicator());
    }
    if (areas.hasError || mission?.hasError == true) {
      return _FormUnavailable(
        message: 'No se pudieron preparar los datos de la misión.',
        onBack: _cancel,
      );
    }

    final List<MissionArea> availableAreas =
        areas.value ?? const <MissionArea>[];
    final Mission? existing = mission?.value;
    if (widget.isEditing && existing == null) {
      return _FormUnavailable(
        message: 'La misión que intentas editar ya no existe.',
        onBack: _cancel,
      );
    }
    _initialize(availableAreas, existing);

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
                          ? 'Editar misión'
                          : 'Nueva misión',
                      subtitle: widget.isEditing
                          ? 'Actualiza el objetivo y su plan de ejecución'
                          : 'Configura el objetivo y su plan de ejecución',
                    ),
                    const SizedBox(height: 22),
                    if (compact) ...<Widget>[
                      _InformationPanel(
                        titleController: _titleController,
                        descriptionController: _descriptionController,
                        areas: availableAreas,
                        areaId: _areaId,
                        type: _type,
                        importance: _importance,
                        priority: _priority,
                        isRequired: _isRequired,
                        onAreaChanged: (value) =>
                            setState(() => _areaId = value),
                        onTypeChanged: (value) => setState(() => _type = value),
                        onImportanceChanged: (value) => setState(() {
                          _importance = value;
                          if (!widget.isEditing) {
                            _xpController.text = _suggestedXp(value).toString();
                          }
                        }),
                        onPriorityChanged: (value) =>
                            setState(() => _priority = value),
                        onRequiredChanged: (value) =>
                            setState(() => _isRequired = value),
                      ),
                      const SizedBox(height: 18),
                      _PlanningPanel(
                        date: _date,
                        time: _time,
                        durationController: _durationController,
                        budgetController: _budgetController,
                        xpController: _xpController,
                        onPickDate: _pickDate,
                        onPickTime: _pickTime,
                      ),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            flex: 3,
                            child: _InformationPanel(
                              titleController: _titleController,
                              descriptionController: _descriptionController,
                              areas: availableAreas,
                              areaId: _areaId,
                              type: _type,
                              importance: _importance,
                              priority: _priority,
                              isRequired: _isRequired,
                              onAreaChanged: (value) =>
                                  setState(() => _areaId = value),
                              onTypeChanged: (value) =>
                                  setState(() => _type = value),
                              onImportanceChanged: (value) => setState(() {
                                _importance = value;
                                if (!widget.isEditing) {
                                  _xpController.text = _suggestedXp(
                                    value,
                                  ).toString();
                                }
                              }),
                              onPriorityChanged: (value) =>
                                  setState(() => _priority = value),
                              onRequiredChanged: (value) =>
                                  setState(() => _isRequired = value),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 2,
                            child: _PlanningPanel(
                              date: _date,
                              time: _time,
                              durationController: _durationController,
                              budgetController: _budgetController,
                              xpController: _xpController,
                              onPickDate: _pickDate,
                              onPickTime: _pickTime,
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

  void _initialize(List<MissionArea> areas, Mission? existing) {
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
      _durationController.text = existing.estimatedMinutes?.toString() ?? '';
      _budgetController.text = existing.budgetMinor == null
          ? ''
          : missionMoneyLabel(existing.budgetMinor!);
      _xpController.text = existing.xpPlanned.toString();
      _type = existing.type;
      _importance = existing.importance;
      _priority = existing.priority;
      _isRequired = existing.isRequired;
      final DateTime localDate =
          existing.scheduledAtUtc?.toLocal() ?? DateTime.now();
      _date = localDate;
      _time = TimeOfDay.fromDateTime(localDate);
      _objectives.addAll(
        existing.objectives.map(
          (objective) => _ObjectiveEditor(
            controller: TextEditingController(text: objective.description),
            id: objective.id,
            createdAtUtc: objective.createdAtUtc,
            completedAtUtc: objective.completedAtUtc,
          ),
        ),
      );
    }
    _initialized = true;
  }

  MissionArea? _defaultArea(List<MissionArea> areas) {
    for (final area in areas) {
      if (area.isDefault) {
        return area;
      }
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

  Future<void> _pickDate() async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
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
    if (!_formKey.currentState!.validate() || _areaId == null) {
      return;
    }
    final DateTime scheduledLocal = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final int? duration = _optionalInt(_durationController.text);
    final int? budgetMinor = _optionalMoneyMinor(_budgetController.text);
    final int xp = int.parse(_xpController.text.trim());
    setState(() => _saving = true);

    final Result<Mission> result = await ref
        .read(missionApplicationServiceProvider)
        .save(
          SaveMissionRequest(
            existing: _existing,
            areaId: _areaId!,
            title: _titleController.text,
            description: _descriptionController.text,
            type: _type,
            importance: _importance,
            priority: _priority,
            isRequired: _isRequired,
            scheduledAtUtc: scheduledLocal.toUtc(),
            estimatedMinutes: duration,
            budgetMinor: budgetMinor,
            xpPlanned: xp,
            objectives: <MissionObjectiveDraft>[
              for (final objective in _objectives)
                MissionObjectiveDraft(
                  id: objective.id,
                  description: objective.controller.text,
                  createdAtUtc: objective.createdAtUtc,
                  completedAtUtc: objective.completedAtUtc,
                ),
            ],
          ),
        );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    result.fold<void>(
      onSuccess: (mission) {
        ref.invalidate(missionDetailProvider(mission.id));
        context.goNamed(
          'missionDetail',
          pathParameters: <String, String>{'missionId': mission.id},
        );
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
      context.goNamed('missionsToday');
    }
  }

  static int? _optionalInt(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : int.tryParse(trimmed);
  }

  static int? _optionalMoneyMinor(String value) {
    final String normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    final double? amount = double.tryParse(normalized);
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

class _InformationPanel extends StatelessWidget {
  const _InformationPanel({
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
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final List<MissionArea> areas;
  final String? areaId;
  final MissionType type;
  final MissionImportance importance;
  final MissionPriority priority;
  final bool isRequired;
  final ValueChanged<String?> onAreaChanged;
  final ValueChanged<MissionType> onTypeChanged;
  final ValueChanged<MissionImportance> onImportanceChanged;
  final ValueChanged<MissionPriority> onPriorityChanged;
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
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MissionImportance>(
            initialValue: importance,
            decoration: const InputDecoration(labelText: 'Importancia'),
            items: <DropdownMenuItem<MissionImportance>>[
              for (final value in MissionImportance.values)
                DropdownMenuItem<MissionImportance>(
                  value: value,
                  child: Text(missionImportanceLabel(value)),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onImportanceChanged(value);
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MissionPriority>(
            initialValue: priority,
            decoration: const InputDecoration(labelText: 'Prioridad'),
            items: <DropdownMenuItem<MissionPriority>>[
              for (final value in MissionPriority.values)
                DropdownMenuItem<MissionPriority>(
                  value: value,
                  child: Text(missionPriorityLabel(value)),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onPriorityChanged(value);
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MissionType>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: <DropdownMenuItem<MissionType>>[
              for (final value in MissionType.values)
                DropdownMenuItem<MissionType>(
                  value: value,
                  child: Text(missionTypeLabel(value)),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onTypeChanged(value);
              }
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

class _PlanningPanel extends StatelessWidget {
  const _PlanningPanel({
    required this.date,
    required this.time,
    required this.durationController,
    required this.budgetController,
    required this.xpController,
    required this.onPickDate,
    required this.onPickTime,
  });

  final DateTime date;
  final TimeOfDay time;
  final TextEditingController durationController;
  final TextEditingController budgetController;
  final TextEditingController xpController;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return TerminalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PanelTitle(label: 'Planificación', icon: Icons.calendar_month),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onPickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('$day/$month/${date.year}'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onPickTime,
            icon: const Icon(Icons.schedule),
            label: Text(time.format(context)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: durationController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Duración estimada',
              suffixText: 'min',
            ),
            validator: _positiveOptionalInt,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: budgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Presupuesto',
              prefixText: 'Bs ',
            ),
            validator: _nonNegativeOptionalMoney,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: xpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Recompensa',
              suffixText: 'XP',
            ),
            validator: (value) {
              final int? parsed = int.tryParse(value?.trim() ?? '');
              return parsed == null || parsed < 0
                  ? 'Escribe un XP válido.'
                  : null;
            },
          ),
        ],
      ),
    );
  }

  static String? _positiveOptionalInt(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final int? parsed = int.tryParse(value.trim());
    return parsed == null || parsed <= 0 ? 'Debe ser mayor que cero.' : null;
  }

  static String? _nonNegativeOptionalMoney(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final double? parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    return parsed == null || parsed < 0 ? 'Escribe un importe válido.' : null;
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
        const _PanelTitle(label: 'Objetivos', icon: Icons.checklist),
        const SizedBox(height: 14),
        if (objectives.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Puedes crear la misión sin objetivos o añadir una lista concreta.',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        for (var index = 0; index < objectives.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 14, right: 10),
                  child: Text('${index + 1}'.padLeft(2, '0')),
                ),
                Expanded(
                  child: TextFormField(
                    controller: objectives[index].controller,
                    maxLength: 240,
                    decoration: const InputDecoration(
                      labelText: 'Descripción del objetivo',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Escribe el objetivo o elimínalo.'
                        : null,
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar objetivo',
                  onPressed: () => onRemove(index),
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
              : 'Crear misión',
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
  const _ObjectiveEditor({
    required this.controller,
    this.id,
    this.createdAtUtc,
    this.completedAtUtc,
  });

  final TextEditingController controller;
  final String? id;
  final DateTime? createdAtUtc;
  final DateTime? completedAtUtc;

  void dispose() => controller.dispose();
}
