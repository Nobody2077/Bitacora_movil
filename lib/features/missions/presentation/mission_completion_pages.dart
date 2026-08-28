import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/application/command_providers.dart';
import '../../../app/application/commands/complete_mission.dart';
import '../../../app/providers/persistence_providers.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/app_ui_preferences.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/mission_providers.dart';
import '../domain/models/mission.dart';
import 'mission_presentation_support.dart';

class MissionReviewPage extends ConsumerStatefulWidget {
  const MissionReviewPage({required this.missionId, super.key});

  final String missionId;

  @override
  ConsumerState<MissionReviewPage> createState() => _MissionReviewPageState();
}

class _MissionReviewPageState extends ConsumerState<MissionReviewPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _resultController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _expenseController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _xpController = TextEditingController();
  final Set<String> _completedObjectiveIds = <String>{};

  MissionCompletionOutcome _outcome = MissionCompletionOutcome.completed;
  ConvenienceRating? _convenienceRating;
  CompletionMovementType _movementType = CompletionMovementType.expense;
  CompletionPaymentMethod _paymentMethod = CompletionPaymentMethod.cash;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _resultController.dispose();
    _noteController.dispose();
    _expenseController.dispose();
    _categoryController.dispose();
    _xpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Mission?> loaded = ref.watch(
      missionDetailProvider(widget.missionId),
    );
    return loaded.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => _ReviewUnavailable(
        message: 'No se pudo preparar la revisión.',
        onBack: _backToMission,
      ),
      data: (Mission? mission) {
        if (mission == null) {
          return _ReviewUnavailable(
            message: 'La misión ya no está disponible.',
            onBack: () => context.goNamed('missionsToday'),
          );
        }
        if (const <MissionStatus>{
          MissionStatus.completed,
          MissionStatus.partial,
        }.contains(mission.status)) {
          return _ReviewUnavailable(
            message: 'La misión ya tiene un resultado guardado.',
            actionLabel: 'Ver resultado',
            onBack: () => context.goNamed(
              'missionResult',
              pathParameters: <String, String>{'missionId': mission.id},
            ),
          );
        }
        _initialize(mission);
        return _ReviewContent(
          formKey: _formKey,
          mission: mission,
          outcome: _outcome,
          completedObjectiveIds: _completedObjectiveIds,
          resultController: _resultController,
          noteController: _noteController,
          expenseController: _expenseController,
          categoryController: _categoryController,
          xpController: _xpController,
          convenienceRating: _convenienceRating,
          paymentMethod: _paymentMethod,
          movementType: _movementType,
          saving: _saving,
          onOutcomeChanged: (MissionCompletionOutcome value) {
            setState(() {
              _outcome = value;
              if (value == MissionCompletionOutcome.completed) {
                _xpController.text = mission.xpPlanned.toString();
                _completedObjectiveIds
                  ..clear()
                  ..addAll(mission.objectives.map((objective) => objective.id));
              } else {
                _xpController.text = '0';
                _completedObjectiveIds
                  ..clear()
                  ..addAll(
                    mission.objectives
                        .where((objective) => objective.isCompleted)
                        .map((objective) => objective.id),
                  );
              }
            });
          },
          onObjectiveChanged: (String id, bool selected) {
            setState(() {
              if (selected) {
                _completedObjectiveIds.add(id);
              } else {
                if (_outcome == MissionCompletionOutcome.completed) {
                  _xpController.text = '0';
                }
                _completedObjectiveIds.remove(id);
                _outcome = MissionCompletionOutcome.partial;
              }
            });
          },
          onConvenienceChanged: (value) =>
              setState(() => _convenienceRating = value),
          onPaymentChanged: (value) => setState(() => _paymentMethod = value),
          onMovementChanged: (value) => setState(() => _movementType = value),
          onXpChanged: (_) => setState(() {}),
          onCancel: _saving ? null : _backToMission,
          onSave: _saving ? null : () => _complete(mission),
        );
      },
    );
  }

  void _initialize(Mission mission) {
    if (_initialized) {
      return;
    }
    _resultController.text = mission.actualResult ?? '';
    _convenienceRating = mission.convenienceRating;
    _xpController.text = mission.xpPlanned.toString();
    _completedObjectiveIds.addAll(
      mission.objectives.map((objective) => objective.id),
    );
    _initialized = true;
  }

  Future<void> _complete(Mission mission) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final Result<MissionCompletionReceipt> result = await ref
        .read(completeMissionCommandProvider)
        .call(
          CompleteMissionRequest(
            mission: mission,
            outcome: _outcome,
            actualResult: _resultController.text,
            convenienceRating: _convenienceRating,
            completedObjectiveIds: Set<String>.unmodifiable(
              _completedObjectiveIds,
            ),
            xpAwarded: int.parse(_xpController.text.trim()),
            journalNote: _noteController.text,
            movementMinor: _moneyMinor(_expenseController.text),
            movementCategory: _categoryController.text,
            movementType: _movementType,
            paymentMethod: _expenseController.text.trim().isEmpty
                ? null
                : _paymentMethod,
          ),
        );
    if (!mounted) {
      return;
    }
    result.fold<void>(
      onSuccess: (MissionCompletionReceipt receipt) {
        unawaited(
          ref.read(notificationReconciliationServiceProvider).reconcile(),
        );
        ref.invalidate(missionDetailProvider(mission.id));
        ref.invalidate(missionCompletionReceiptProvider(mission.id));
        ref.invalidate(todayMissionsProvider);
        ref.invalidate(activeTimerMissionProvider);
        context.goNamed(
          'missionResult',
          pathParameters: <String, String>{'missionId': mission.id},
        );
      },
      onFailure: (AppFailure failure) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  void _backToMission() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(
        'missionDetail',
        pathParameters: <String, String>{'missionId': widget.missionId},
      );
    }
  }

  static int? _moneyMinor(String value) {
    final String normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    final double? amount = double.tryParse(normalized);
    return amount == null ? null : (amount * 100).round();
  }
}

class _ReviewContent extends StatelessWidget {
  const _ReviewContent({
    required this.formKey,
    required this.mission,
    required this.outcome,
    required this.completedObjectiveIds,
    required this.resultController,
    required this.noteController,
    required this.expenseController,
    required this.categoryController,
    required this.xpController,
    required this.convenienceRating,
    required this.paymentMethod,
    required this.movementType,
    required this.saving,
    required this.onOutcomeChanged,
    required this.onObjectiveChanged,
    required this.onConvenienceChanged,
    required this.onPaymentChanged,
    required this.onMovementChanged,
    required this.onXpChanged,
    required this.onCancel,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final Mission mission;
  final MissionCompletionOutcome outcome;
  final Set<String> completedObjectiveIds;
  final TextEditingController resultController;
  final TextEditingController noteController;
  final TextEditingController expenseController;
  final TextEditingController categoryController;
  final TextEditingController xpController;
  final ConvenienceRating? convenienceRating;
  final CompletionPaymentMethod paymentMethod;
  final CompletionMovementType movementType;
  final bool saving;
  final ValueChanged<MissionCompletionOutcome> onOutcomeChanged;
  final void Function(String id, bool selected) onObjectiveChanged;
  final ValueChanged<ConvenienceRating?> onConvenienceChanged;
  final ValueChanged<CompletionPaymentMethod> onPaymentChanged;
  final ValueChanged<CompletionMovementType> onMovementChanged;
  final ValueChanged<String> onXpChanged;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final bool compact = constraints.maxWidth < 840;
      final Widget resultPanel = _ResultInputPanel(
        mission: mission,
        outcome: outcome,
        completedObjectiveIds: completedObjectiveIds,
        resultController: resultController,
        noteController: noteController,
        convenienceRating: convenienceRating,
        onOutcomeChanged: onOutcomeChanged,
        onObjectiveChanged: onObjectiveChanged,
        onConvenienceChanged: onConvenienceChanged,
      );
      final Widget economyPanel = _CompletionEconomyPanel(
        mission: mission,
        outcome: outcome,
        expenseController: expenseController,
        categoryController: categoryController,
        xpController: xpController,
        paymentMethod: paymentMethod,
        movementType: movementType,
        onPaymentChanged: onPaymentChanged,
        onMovementChanged: onMovementChanged,
        onXpChanged: onXpChanged,
      );
      return SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 16 : 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TerminalPageHeader(
                    title: 'Revisar misión',
                    subtitle: mission.title,
                  ),
                  const SizedBox(height: 20),
                  if (compact) ...<Widget>[
                    resultPanel,
                    const SizedBox(height: 18),
                    economyPanel,
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 3, child: resultPanel),
                        const SizedBox(width: 18),
                        Expanded(flex: 2, child: economyPanel),
                      ],
                    ),
                  const SizedBox(height: 18),
                  TerminalPanel(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        TerminalOutlineButton(
                          label: 'Cancelar',
                          icon: Icons.close,
                          onPressed: onCancel,
                        ),
                        TerminalPrimaryButton(
                          label: saving
                              ? 'Guardando resultado'
                              : outcome == MissionCompletionOutcome.completed
                              ? 'Completar misión'
                              : 'Guardar parcial',
                          icon: Icons.flag_outlined,
                          onPressed: onSave,
                        ),
                      ],
                    ),
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

class _ResultInputPanel extends StatelessWidget {
  const _ResultInputPanel({
    required this.mission,
    required this.outcome,
    required this.completedObjectiveIds,
    required this.resultController,
    required this.noteController,
    required this.convenienceRating,
    required this.onOutcomeChanged,
    required this.onObjectiveChanged,
    required this.onConvenienceChanged,
  });

  final Mission mission;
  final MissionCompletionOutcome outcome;
  final Set<String> completedObjectiveIds;
  final TextEditingController resultController;
  final TextEditingController noteController;
  final ConvenienceRating? convenienceRating;
  final ValueChanged<MissionCompletionOutcome> onOutcomeChanged;
  final void Function(String id, bool selected) onObjectiveChanged;
  final ValueChanged<ConvenienceRating?> onConvenienceChanged;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      borderColor: tokens.progressGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'RESULTADO REAL',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: tokens.progressGreen,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<MissionCompletionOutcome>(
            segments: const <ButtonSegment<MissionCompletionOutcome>>[
              ButtonSegment<MissionCompletionOutcome>(
                value: MissionCompletionOutcome.completed,
                label: Text('Completa'),
                icon: Icon(Icons.check_circle_outline),
              ),
              ButtonSegment<MissionCompletionOutcome>(
                value: MissionCompletionOutcome.partial,
                label: Text('Parcial'),
                icon: Icon(Icons.timelapse),
              ),
            ],
            selected: <MissionCompletionOutcome>{outcome},
            onSelectionChanged: (values) => onOutcomeChanged(values.single),
          ),
          if (mission.objectives.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Text(
              'OBJETIVOS',
              style: TextStyle(color: tokens.infoCyan, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            for (final objective in mission.objectives)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(objective.description),
                value: completedObjectiveIds.contains(objective.id),
                onChanged: (value) =>
                    onObjectiveChanged(objective.id, value ?? false),
              ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: resultController,
            minLines: 4,
            maxLines: 7,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: '¿Qué resultado obtuviste? (opcional)',
              helperText: 'Puedes dejarlo vacío y finalizar directamente.',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ConvenienceRating>(
            initialValue: convenienceRating,
            decoration: const InputDecoration(
              labelText: 'Conveniencia (opcional)',
            ),
            items: <DropdownMenuItem<ConvenienceRating>>[
              for (final value in ConvenienceRating.values)
                DropdownMenuItem<ConvenienceRating>(
                  value: value,
                  child: Text(missionConvenienceLabel(value)),
                ),
            ],
            onChanged: onConvenienceChanged,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: noteController,
            minLines: 2,
            maxLines: 5,
            maxLength: 4000,
            decoration: const InputDecoration(
              labelText: 'Nota para la Bitácora (opcional)',
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionEconomyPanel extends StatelessWidget {
  const _CompletionEconomyPanel({
    required this.mission,
    required this.outcome,
    required this.expenseController,
    required this.categoryController,
    required this.xpController,
    required this.paymentMethod,
    required this.movementType,
    required this.onPaymentChanged,
    required this.onMovementChanged,
    required this.onXpChanged,
  });

  final Mission mission;
  final MissionCompletionOutcome outcome;
  final TextEditingController expenseController;
  final TextEditingController categoryController;
  final TextEditingController xpController;
  final CompletionPaymentMethod paymentMethod;
  final CompletionMovementType movementType;
  final ValueChanged<CompletionPaymentMethod> onPaymentChanged;
  final ValueChanged<CompletionMovementType> onMovementChanged;
  final ValueChanged<String> onXpChanged;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final int awardedXp = int.tryParse(xpController.text.trim()) ?? 0;
    return TerminalPanel(
      borderColor: tokens.valueYellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'RESUMEN Y ECONOMÍA',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: tokens.valueYellow,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 18),
          TerminalMetric(
            icon: Icons.bolt_outlined,
            value: '$awardedXp',
            label: 'XP a otorgar',
            color: tokens.valueYellow,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: xpController,
            readOnly: outcome == MissionCompletionOutcome.completed,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: outcome == MissionCompletionOutcome.completed
                  ? 'XP completo'
                  : 'XP parcial otorgado',
              helperText: 'Rango permitido: 0–${mission.xpPlanned} XP',
              suffixText: 'XP',
            ),
            onChanged: onXpChanged,
            validator: (String? value) {
              final int? parsed = int.tryParse(value?.trim() ?? '');
              if (parsed == null || parsed < 0 || parsed > mission.xpPlanned) {
                return 'Escribe un XP entre 0 y ${mission.xpPlanned}.';
              }
              if (outcome == MissionCompletionOutcome.completed &&
                  parsed != mission.xpPlanned) {
                return 'La misión completa otorga todo el XP.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text(
            mission.budgetMinor == null
                ? 'Sin presupuesto estimado'
                : 'Presupuesto: ${missionMoneyDisplay(context, mission.budgetMinor!)}',
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<CompletionMovementType>(
            initialValue: movementType,
            decoration: const InputDecoration(
              labelText: 'Tipo de movimiento opcional',
            ),
            items: <DropdownMenuItem<CompletionMovementType>>[
              for (final value in CompletionMovementType.values)
                DropdownMenuItem<CompletionMovementType>(
                  value: value,
                  child: Text(completionMovementTypeLabel(value)),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onMovementChanged(value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: expenseController,
            obscureText: context.uiPreferences.hideAmounts,
            obscuringCharacter: '•',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: movementType == CompletionMovementType.expense
                  ? 'Gasto real en Bs (opcional)'
                  : 'Ingreso real en Bs (opcional)',
            ),
            validator: (value) {
              final String normalized =
                  value?.trim().replaceAll(',', '.') ?? '';
              if (normalized.isEmpty) {
                return null;
              }
              final double? amount = double.tryParse(normalized);
              return amount == null || amount <= 0
                  ? 'Introduce un monto mayor que cero.'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CompletionPaymentMethod>(
            initialValue: paymentMethod,
            decoration: const InputDecoration(labelText: 'Medio de pago'),
            items: <DropdownMenuItem<CompletionPaymentMethod>>[
              for (final value in CompletionPaymentMethod.values)
                DropdownMenuItem<CompletionPaymentMethod>(
                  value: value,
                  child: Text(completionPaymentMethodLabel(value)),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onPaymentChanged(value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: categoryController,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Categoría del gasto (opcional)',
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'El presupuesto es una estimación. Solo un movimiento real confirmado modifica el saldo.',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class MissionResultPage extends ConsumerWidget {
  const MissionResultPage({required this.missionId, super.key});

  final String missionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MissionCompletionReceipt?> result = ref.watch(
      missionCompletionReceiptProvider(missionId),
    );
    return result.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => _ReviewUnavailable(
        message: 'No se pudo recuperar el resultado.',
        onBack: () => context.goNamed('missionsToday'),
      ),
      data: (receipt) => receipt == null
          ? _ReviewUnavailable(
              message: 'La misión todavía no tiene un resultado.',
              onBack: () => context.goNamed(
                'missionDetail',
                pathParameters: <String, String>{'missionId': missionId},
              ),
            )
          : _MissionResultContent(receipt: receipt),
    );
  }
}

class _MissionResultContent extends StatelessWidget {
  const _MissionResultContent({required this.receipt});

  final MissionCompletionReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final Mission mission = receipt.mission;
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final int completedObjectives = mission.objectives
        .where((objective) => objective.isCompleted)
        .length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TerminalPageHeader(
                title: mission.status == MissionStatus.completed
                    ? 'Misión completada'
                    : 'Progreso guardado',
                subtitle: mission.title,
              ),
              const SizedBox(height: 20),
              TerminalPanel(
                borderColor: tokens.progressGreen,
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: <Widget>[
                    Icon(
                      mission.status == MissionStatus.completed
                          ? Icons.verified_outlined
                          : Icons.timelapse,
                      size: 72,
                      color: tokens.progressGreen,
                    ),
                    const SizedBox(height: 18),
                    if (mission.actualResult case final result?
                        when result.trim().isNotEmpty) ...<Widget>[
                      Text(
                        result,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 24),
                    ],
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 28,
                      runSpacing: 18,
                      children: <Widget>[
                        TerminalMetric(
                          icon: Icons.bolt_outlined,
                          value: '${receipt.xpAwarded}',
                          label: 'XP obtenidos',
                          color: tokens.valueYellow,
                        ),
                        TerminalMetric(
                          icon: Icons.timer_outlined,
                          value: missionDurationLabel(receipt.totalWorkSeconds),
                          label: 'tiempo real',
                          color: tokens.infoCyan,
                        ),
                        TerminalMetric(
                          icon: Icons.checklist,
                          value:
                              '$completedObjectives/${mission.objectives.length}',
                          label: 'objetivos',
                          color: tokens.progressGreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      receipt.movementMinor == null
                          ? 'Sin movimiento económico durante el cierre.'
                          : '${receipt.movementType == CompletionMovementType.income ? 'Ingreso' : 'Gasto'} registrado: ${missionMoneyDisplay(context, receipt.movementMinor!)}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    if (mission.convenienceRating != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        missionConvenienceLabel(mission.convenienceRating!),
                        style: TextStyle(color: tokens.infoCyan),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TerminalPrimaryButton(
                label: 'Volver a Misiones',
                icon: Icons.arrow_back,
                expanded: true,
                onPressed: () => context.goNamed('missionsToday'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewUnavailable extends StatelessWidget {
  const _ReviewUnavailable({
    required this.message,
    required this.onBack,
    this.actionLabel = 'Volver',
  });

  final String message;
  final String actionLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: TerminalPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.assignment_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 16),
            TerminalPrimaryButton(
              label: actionLabel,
              icon: Icons.arrow_back,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    ),
  );
}
