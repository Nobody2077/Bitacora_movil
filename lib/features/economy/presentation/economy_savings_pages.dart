import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/economy_application_service.dart';
import '../application/economy_providers.dart';
import '../domain/models/economy_models.dart';
import 'economy_presentation_support.dart';

class EconomySavingsPage extends ConsumerWidget {
  const EconomySavingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingsGoalsProvider);
    return _SavingsFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TerminalPageHeader(
            title: 'Ahorro y reservas',
            subtitle: 'Separa fondos sin crear cuentas ni saldos paralelos',
            action: TerminalPrimaryButton(
              label: 'Nueva meta',
              icon: Icons.add,
              onPressed: () => context.pushNamed('financeSavingsNew'),
            ),
          ),
          const SizedBox(height: TerminalSpace.md),
          goals.when(
            data: (items) => items.isEmpty
                ? TerminalEmptyState(
                    title: 'Aún no hay metas',
                    description:
                        'Crea una meta y reserva parte de tu saldo para ella.',
                    icon: Icons.savings_outlined,
                    action: TerminalPrimaryButton(
                      label: 'Crear meta',
                      icon: Icons.add,
                      onPressed: () => context.pushNamed('financeSavingsNew'),
                    ),
                  )
                : Column(
                    children: <Widget>[
                      for (final goal in items) ...<Widget>[
                        _GoalCard(goal: goal),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => TerminalEmptyState(
              title: 'No se pudieron leer las metas',
              description: 'Reintenta la consulta local.',
              icon: Icons.error_outline,
              action: TerminalOutlineButton(
                label: 'Reintentar',
                icon: Icons.refresh,
                onPressed: () => ref.invalidate(savingsGoalsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});

  final SavingsGoalSummary goal;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final color = goal.status == SavingsGoalStatus.achieved
        ? tokens.progressGreen
        : goal.status == SavingsGoalStatus.paused
        ? tokens.attentionOrange
        : tokens.infoCyan;
    return TerminalCard(
      onTap: () => context.pushNamed(
        'financeSavingsDetail',
        pathParameters: <String, String>{'goalId': goal.id},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  goal.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TerminalBadge(
                label: economyGoalStatusLabel(goal.status),
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 14),
          TerminalProgress(value: goal.progress, color: color),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text('${economyMoney(goal.reservedMinor)} reservados'),
              ),
              Text(
                'Meta ${economyMoney(goal.targetMinor)}',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ],
          ),
          if (goal.dueDate != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Fecha objetivo: ${goal.dueDate}',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class EconomyGoalFormPage extends ConsumerStatefulWidget {
  const EconomyGoalFormPage({super.key, this.goalId});

  final String? goalId;
  bool get isEditing => goalId != null;

  @override
  ConsumerState<EconomyGoalFormPage> createState() =>
      _EconomyGoalFormPageState();
}

class _EconomyGoalFormPageState extends ConsumerState<EconomyGoalFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _target = TextEditingController();
  DateTime? _dueDate;
  SavingsGoalStatus _status = SavingsGoalStatus.active;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SavingsGoalSummary?>? goal = widget.goalId == null
        ? null
        : ref.watch(savingsGoalDetailProvider(widget.goalId!));
    if (goal?.isLoading == true) {
      return const Center(child: CircularProgressIndicator());
    }
    if (goal?.hasError == true || (widget.isEditing && goal?.value == null)) {
      return const _GoalUnavailable();
    }
    _initialize(goal?.value);
    return _SavingsFrame(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TerminalPageHeader(
              title: widget.isEditing ? 'Editar meta' : 'Nueva meta de ahorro',
              subtitle: 'El monto reservado seguirá derivado de asignaciones',
            ),
            const SizedBox(height: TerminalSpace.md),
            TerminalPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    controller: _title,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la meta',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Escribe un nombre.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _target,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monto objetivo',
                      prefixText: 'Bs ',
                    ),
                    validator: economyPositiveMoneyValidator,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _dueDate == null
                          ? 'Sin fecha límite'
                          : _civilDate(_dueDate!),
                    ),
                  ),
                  if (widget.isEditing) ...<Widget>[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SavingsGoalStatus>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Estado'),
                      items: <DropdownMenuItem<SavingsGoalStatus>>[
                        for (final value in SavingsGoalStatus.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(economyGoalStatusLabel(value)),
                          ),
                      ],
                      onChanged: (value) => setState(() => _status = value!),
                    ),
                  ],
                ],
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
                  label: _saving
                      ? 'Guardando'
                      : (widget.isEditing ? 'Guardar cambios' : 'Crear meta'),
                  icon: _saving ? Icons.hourglass_top : Icons.save_outlined,
                  onPressed: _saving ? null : () => _save(goal?.value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _initialize(SavingsGoalSummary? goal) {
    if (_initialized) return;
    if (goal != null) {
      _title.text = goal.title;
      _target.text =
          '${goal.targetMinor ~/ 100},${(goal.targetMinor % 100).toString().padLeft(2, '0')}';
      _status = goal.status;
      _dueDate = goal.dueDate == null ? null : DateTime.tryParse(goal.dueDate!);
    }
    _initialized = true;
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (mounted) setState(() => _dueDate = selected);
  }

  Future<void> _save(SavingsGoalSummary? existing) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final result = await ref
        .read(economyApplicationServiceProvider)
        .saveGoal(
          SaveGoalRequest(
            existing: existing,
            title: _title.text,
            targetMinor: parseEconomyMoney(_target.text)!,
            dueDate: _dueDate == null ? null : _civilDate(_dueDate!),
            status: _status,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold<void>(
      onSuccess: (value) {
        ref.invalidate(savingsGoalsProvider);
        ref.invalidate(savingsGoalDetailProvider(value.id));
        context.goNamed(
          'financeSavingsDetail',
          pathParameters: <String, String>{'goalId': value.id},
        );
      },
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  void _cancel() =>
      context.canPop() ? context.pop() : context.goNamed('financeSavings');

  static String _civilDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class EconomyGoalDetailPage extends ConsumerStatefulWidget {
  const EconomyGoalDetailPage({required this.goalId, super.key});
  final String goalId;

  @override
  ConsumerState<EconomyGoalDetailPage> createState() =>
      _EconomyGoalDetailPageState();
}

class _EconomyGoalDetailPageState extends ConsumerState<EconomyGoalDetailPage> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(savingsGoalDetailProvider(widget.goalId));
    return goal.when(
      data: (value) => value == null
          ? const _GoalUnavailable()
          : _SavingsFrame(child: _content(value)),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _GoalUnavailable(),
    );
  }

  Widget _content(SavingsGoalSummary goal) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TerminalPageHeader(
          title: goal.title,
          subtitle: 'Meta de ahorro y reserva derivada',
        ),
        const SizedBox(height: TerminalSpace.md),
        TerminalPanel(
          borderColor: tokens.structuralRed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 32,
                runSpacing: 18,
                children: <Widget>[
                  TerminalMetric(
                    icon: Icons.lock_outline,
                    value: economyMoney(goal.reservedMinor),
                    label: 'Reservado',
                    color: tokens.valueYellow,
                  ),
                  TerminalMetric(
                    icon: Icons.flag_outlined,
                    value: economyMoney(goal.targetMinor),
                    label: 'Objetivo',
                    color: tokens.infoCyan,
                  ),
                  TerminalMetric(
                    icon: Icons.trending_up,
                    value: economyMoney(goal.remainingMinor),
                    label: 'Faltante',
                    color: tokens.progressGreen,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TerminalProgress(
                value: goal.progress,
                color: tokens.progressGreen,
                label: '${(goal.progress * 100).round()}% completado',
              ),
              const SizedBox(height: 14),
              Text('Estado: ${economyGoalStatusLabel(goal.status)}'),
              if (goal.dueDate != null) Text('Fecha objetivo: ${goal.dueDate}'),
            ],
          ),
        ),
        const SizedBox(height: TerminalSpace.md),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            TerminalPrimaryButton(
              label: 'Reservar',
              icon: Icons.lock_outline,
              onPressed: _working || goal.status == SavingsGoalStatus.archived
                  ? null
                  : () => _allocate(goal, GoalAllocationDirection.reserve),
            ),
            TerminalOutlineButton(
              label: 'Liberar',
              icon: Icons.lock_open_outlined,
              onPressed:
                  _working ||
                      goal.reservedMinor == 0 ||
                      goal.status == SavingsGoalStatus.archived
                  ? null
                  : () => _allocate(goal, GoalAllocationDirection.release),
            ),
            TerminalOutlineButton(
              label: 'Editar meta',
              icon: Icons.edit_outlined,
              onPressed: _working
                  ? null
                  : () => context.pushNamed(
                      'financeSavingsEdit',
                      pathParameters: <String, String>{'goalId': goal.id},
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _allocate(
    SavingsGoalSummary goal,
    GoalAllocationDirection direction,
  ) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          direction == GoalAllocationDirection.reserve
              ? 'Reservar fondos'
              : 'Liberar fondos',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: 'Bs ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Nota (opcional)'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => dialogContext.pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    final int? parsed = parseEconomyMoney(amount.text);
    amount.dispose();
    final String noteValue = note.text;
    note.dispose();
    if (accepted != true || parsed == null || parsed <= 0 || !mounted) {
      if (accepted == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escribe un monto válido.')),
        );
      }
      return;
    }
    setState(() => _working = true);
    final Result<SavingsGoalSummary> result = await ref
        .read(economyApplicationServiceProvider)
        .allocate(
          AllocateGoalRequest(
            goal: goal,
            direction: direction,
            amountMinor: parsed,
            note: noteValue,
          ),
        );
    if (!mounted) return;
    setState(() => _working = false);
    result.fold<void>(
      onSuccess: (updated) {
        ref.invalidate(savingsGoalDetailProvider(updated.id));
        ref.invalidate(savingsGoalsProvider);
        ref.invalidate(economySnapshotProvider);
      },
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }
}

class _SavingsFrame extends StatelessWidget {
  const _SavingsFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: constraints.maxWidth < 820
          ? TerminalSpace.pageCompact
          : TerminalSpace.pageTablet,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: child,
        ),
      ),
    ),
  );
}

class _GoalUnavailable extends StatelessWidget {
  const _GoalUnavailable();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: TerminalEmptyState(
        title: 'Meta no disponible',
        description: 'No se pudo encontrar o leer esta meta.',
        icon: Icons.error_outline,
        action: TerminalPrimaryButton(
          label: 'Volver a metas',
          icon: Icons.arrow_back,
          onPressed: () => context.goNamed('financeSavings'),
        ),
      ),
    ),
  );
}
