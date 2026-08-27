import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/economy_application_service.dart';
import '../application/economy_providers.dart';
import '../domain/models/economy_models.dart';
import 'economy_overview_page.dart';
import 'economy_presentation_support.dart';

class EconomyTransactionsPage extends ConsumerWidget {
  const EconomyTransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(economyTransactionsProvider);
    return _EconomyPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const TerminalPageHeader(
            title: 'Movimientos',
            subtitle: 'Historial inmutable del ledger económico',
          ),
          const SizedBox(height: TerminalSpace.md),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              TerminalPrimaryButton(
                label: 'Nuevo gasto',
                icon: Icons.remove_circle_outline,
                onPressed: () => context.pushNamed('financeNewExpense'),
              ),
              TerminalOutlineButton(
                label: 'Nuevo ingreso',
                icon: Icons.add_circle_outline,
                onPressed: () => context.pushNamed('financeNewIncome'),
              ),
              TerminalOutlineButton(
                label: 'Nuevo ajuste',
                icon: Icons.tune,
                onPressed: () => context.pushNamed('financeNewAdjustment'),
              ),
            ],
          ),
          const SizedBox(height: TerminalSpace.md),
          transactions.when(
            data: (items) => items.isEmpty
                ? const TerminalEmptyState(
                    title: 'Sin movimientos',
                    description: 'El ledger todavía está vacío.',
                    icon: Icons.receipt_long_outlined,
                  )
                : Column(
                    children: <Widget>[
                      for (final item in items) ...<Widget>[
                        EconomyTransactionCard(transaction: item),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => TerminalEmptyState(
              title: 'No se pudo leer el ledger',
              description: 'Reintenta la consulta local.',
              icon: Icons.error_outline,
              action: TerminalOutlineButton(
                label: 'Reintentar',
                icon: Icons.refresh,
                onPressed: () => ref.invalidate(economyTransactionsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EconomyTransactionFormPage extends ConsumerStatefulWidget {
  const EconomyTransactionFormPage({
    required this.initialType,
    super.key,
    this.transactionId,
    this.missionId,
  });

  final EconomyTransactionType initialType;
  final String? transactionId;
  final String? missionId;

  bool get isCorrection => transactionId != null;

  @override
  ConsumerState<EconomyTransactionFormPage> createState() =>
      _EconomyTransactionFormPageState();
}

class _EconomyTransactionFormPageState
    extends ConsumerState<EconomyTransactionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _category = TextEditingController();
  final _note = TextEditingController();
  late EconomyTransactionType _type = widget.initialType;
  EconomyPaymentMethod _payment = EconomyPaymentMethod.cash;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _category.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<EconomyTransaction?>? original =
        widget.transactionId == null
        ? null
        : ref.watch(economyTransactionDetailProvider(widget.transactionId!));
    if (original?.isLoading == true) {
      return const Center(child: CircularProgressIndicator());
    }
    if (original?.hasError == true ||
        (widget.isCorrection && original?.value == null)) {
      return const _Unavailable(
        message: 'El movimiento que deseas corregir no está disponible.',
      );
    }
    _initialize(original?.value);
    final bool needsPayment =
        _type == EconomyTransactionType.expense ||
        _type == EconomyTransactionType.adjustmentDebit;
    return _EconomyPageFrame(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TerminalPageHeader(
              title: widget.isCorrection ? 'Corregir movimiento' : _title,
              subtitle: widget.isCorrection
                  ? 'El original se compensará y el reemplazo se guardará atómicamente'
                  : 'Registra un hecho real en el ledger',
            ),
            const SizedBox(height: TerminalSpace.md),
            TerminalPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_isAdjustment)
                    DropdownButtonFormField<EconomyTransactionType>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'Efecto del ajuste',
                      ),
                      items: const <DropdownMenuItem<EconomyTransactionType>>[
                        DropdownMenuItem(
                          value: EconomyTransactionType.adjustmentCredit,
                          child: Text('A favor (+)'),
                        ),
                        DropdownMenuItem(
                          value: EconomyTransactionType.adjustmentDebit,
                          child: Text('En contra (-)'),
                        ),
                      ],
                      onChanged: (value) => setState(() => _type = value!),
                    ),
                  if (_isAdjustment) const SizedBox(height: 12),
                  TextFormField(
                    controller: _amount,
                    autofocus: !widget.isCorrection,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monto',
                      prefixText: 'Bs ',
                    ),
                    validator: economyPositiveMoneyValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _category,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Categoría (opcional)',
                    ),
                  ),
                  if (needsPayment) ...<Widget>[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<EconomyPaymentMethod>(
                      initialValue: _payment,
                      decoration: const InputDecoration(
                        labelText: 'Medio de pago',
                      ),
                      items: <DropdownMenuItem<EconomyPaymentMethod>>[
                        for (final value in EconomyPaymentMethod.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(economyPaymentLabel(value)),
                          ),
                      ],
                      onChanged: (value) => setState(() => _payment = value!),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _note,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Nota (opcional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule),
                        label: Text(_time.format(context)),
                      ),
                    ],
                  ),
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
                      : (widget.isCorrection
                            ? 'Guardar corrección'
                            : 'Registrar'),
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

  bool get _isAdjustment =>
      _type == EconomyTransactionType.adjustmentCredit ||
      _type == EconomyTransactionType.adjustmentDebit;

  String get _title => switch (_type) {
    EconomyTransactionType.income => 'Registrar ingreso',
    EconomyTransactionType.expense => 'Registrar gasto',
    _ => 'Registrar ajuste',
  };

  void _initialize(EconomyTransaction? original) {
    if (_initialized) return;
    if (original != null) {
      _type = original.type == EconomyTransactionType.refund
          ? EconomyTransactionType.adjustmentCredit
          : original.type;
      _amount.text =
          '${original.amountMinor ~/ 100},${(original.amountMinor % 100).toString().padLeft(2, '0')}';
      _category.text = original.category ?? '';
      _note.text = original.note ?? '';
      _payment = original.paymentMethod ?? EconomyPaymentMethod.cash;
      final local = original.occurredAtUtc.toLocal();
      _date = local;
      _time = TimeOfDay.fromDateTime(local);
    }
    _initialized = true;
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null && mounted) setState(() => _time = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final request = SaveTransactionRequest(
      type: _type,
      amountMinor: parseEconomyMoney(_amount.text)!,
      paymentMethod:
          _type == EconomyTransactionType.expense ||
              _type == EconomyTransactionType.adjustmentDebit
          ? _payment
          : null,
      category: _category.text,
      note: _note.text,
      missionId: widget.missionId,
      occurredAtUtc: DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      ).toUtc(),
    );
    final service = ref.read(economyApplicationServiceProvider);
    final Result<EconomyTransaction> result;
    if (widget.transactionId != null) {
      final originalResult = await ref.read(
        economyTransactionDetailProvider(widget.transactionId!).future,
      );
      if (originalResult == null) {
        result = const Failure<EconomyTransaction>(
          ValidationFailure('El movimiento original ya no existe.'),
        );
      } else {
        result = await service.correctTransaction(originalResult, request);
      }
    } else {
      result = await service.saveTransaction(request);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold<void>(
      onSuccess: (value) {
        ref.invalidate(economyTransactionsProvider);
        ref.invalidate(economySnapshotProvider);
        context.goNamed(
          'financeTransactionDetail',
          pathParameters: <String, String>{'transactionId': value.id},
        );
      },
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  void _cancel() =>
      context.canPop() ? context.pop() : context.goNamed('finance');
}

class EconomyTransactionDetailPage extends ConsumerStatefulWidget {
  const EconomyTransactionDetailPage({
    required this.transactionId,
    super.key,
    this.requestVoid = false,
  });

  final String transactionId;
  final bool requestVoid;

  @override
  ConsumerState<EconomyTransactionDetailPage> createState() =>
      _EconomyTransactionDetailPageState();
}

class _EconomyTransactionDetailPageState
    extends ConsumerState<EconomyTransactionDetailPage> {
  bool _voidPrompted = false;
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final transaction = ref.watch(
      economyTransactionDetailProvider(widget.transactionId),
    );
    return transaction.when(
      data: (value) {
        if (value == null) {
          return const _Unavailable(message: 'El movimiento no existe.');
        }
        if (widget.requestVoid && !_voidPrompted) {
          _voidPrompted = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _confirmVoid(value),
          );
        }
        return _EconomyPageFrame(child: _detail(context, value));
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const _Unavailable(message: 'No se pudo leer el movimiento.'),
    );
  }

  Widget _detail(BuildContext context, EconomyTransaction value) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final Color effectColor = value.isCredit
        ? tokens.progressGreen
        : tokens.attentionOrange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const TerminalPageHeader(
          title: 'Detalle de movimiento',
          subtitle: 'Registro histórico del ledger',
        ),
        const SizedBox(height: TerminalSpace.md),
        TerminalPanel(
          borderColor: value.isReversed
              ? tokens.terminalRed
              : tokens.structuralRed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  TerminalBadge(
                    label: economyTransactionTypeLabel(value.type),
                    color: effectColor,
                  ),
                  if (value.isReversed)
                    TerminalBadge(label: 'Anulado', color: tokens.terminalRed),
                  if (value.isReversal)
                    TerminalBadge(
                      label: 'Compensación',
                      color: tokens.infoCyan,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                economyMoney(
                  value.isCredit ? value.amountMinor : -value.amountMinor,
                  signed: true,
                ),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: effectColor,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
              const SizedBox(height: 16),
              _DetailLine(
                label: 'Fecha',
                value: economyDateTimeLabel(value.occurredAtUtc),
              ),
              _DetailLine(
                label: 'Categoría',
                value: value.category ?? 'Sin categoría',
              ),
              if (value.paymentMethod != null)
                _DetailLine(
                  label: 'Medio',
                  value: economyPaymentLabel(value.paymentMethod!),
                ),
              if (value.note != null)
                _DetailLine(label: 'Nota', value: value.note!),
              if (value.relatedTransactionId != null)
                const _DetailLine(
                  label: 'Relación',
                  value: 'Compensa otro movimiento',
                ),
            ],
          ),
        ),
        const SizedBox(height: TerminalSpace.md),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            TerminalOutlineButton(
              label: 'Volver al ledger',
              icon: Icons.arrow_back,
              onPressed: () => context.goNamed('financeTransactions'),
            ),
            if (!value.isReversal && !value.isReversed) ...<Widget>[
              TerminalPrimaryButton(
                label: 'Corregir',
                icon: Icons.edit_outlined,
                onPressed: _working
                    ? null
                    : () => context.pushNamed(
                        'financeTransactionCorrect',
                        pathParameters: <String, String>{
                          'transactionId': value.id,
                        },
                      ),
              ),
              TerminalCriticalButton(
                label: _working ? 'Anulando' : 'Anular',
                icon: Icons.block,
                onPressed: _working ? null : () => _confirmVoid(value),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _confirmVoid(EconomyTransaction transaction) async {
    if (!mounted || transaction.isReversal || transaction.isReversed) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Anular movimiento?'),
        content: const Text(
          'No se borrará. Se registrará un movimiento compensatorio con el efecto opuesto.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _working = true);
    final result = await ref
        .read(economyApplicationServiceProvider)
        .reverseTransaction(transaction);
    if (!mounted) return;
    setState(() => _working = false);
    result.fold<void>(
      onSuccess: (_) {
        ref.invalidate(economyTransactionDetailProvider(transaction.id));
        ref.invalidate(economyTransactionsProvider);
        ref.invalidate(economySnapshotProvider);
        context.goNamed('financeTransactions');
      },
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: 105, child: TerminalLabel(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _EconomyPageFrame extends StatelessWidget {
  const _EconomyPageFrame({required this.child});
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

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: TerminalEmptyState(
        title: 'No disponible',
        description: message,
        icon: Icons.error_outline,
        action: TerminalPrimaryButton(
          label: 'Volver a Economía',
          icon: Icons.arrow_back,
          onPressed: () => context.goNamed('finance'),
        ),
      ),
    ),
  );
}
