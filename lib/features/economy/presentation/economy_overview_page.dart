import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/economy_providers.dart';
import '../domain/models/economy_models.dart';
import '../domain/models/economy_snapshot.dart';
import 'economy_presentation_support.dart';

class EconomyOverviewPage extends ConsumerWidget {
  const EconomyOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(economySnapshotProvider);
    final transactions = ref.watch(economyTransactionsProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 820;
        return SingleChildScrollView(
          padding: compact
              ? TerminalSpace.pageCompact
              : TerminalSpace.pageTablet,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const TerminalPageHeader(
                    title: 'Economía',
                    subtitle: 'Ledger local, saldo disponible y reservas',
                  ),
                  const SizedBox(height: TerminalSpace.md),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      TerminalPrimaryButton(
                        label: 'Registrar gasto',
                        icon: Icons.remove_circle_outline,
                        onPressed: () => context.pushNamed('financeNewExpense'),
                      ),
                      TerminalOutlineButton(
                        label: 'Registrar ingreso',
                        icon: Icons.add_circle_outline,
                        onPressed: () => context.pushNamed('financeNewIncome'),
                      ),
                      TerminalOutlineButton(
                        label: 'Ahorro y reservas',
                        icon: Icons.savings_outlined,
                        onPressed: () => context.pushNamed('financeSavings'),
                      ),
                    ],
                  ),
                  const SizedBox(height: TerminalSpace.md),
                  snapshot.when(
                    data: (value) => _BalanceSummary(value: value),
                    loading: () => const _LoadingPanel(),
                    error: (_, _) => _ErrorPanel(
                      label: 'No se pudo calcular el saldo.',
                      onRetry: () => ref.invalidate(economySnapshotProvider),
                    ),
                  ),
                  const SizedBox(height: TerminalSpace.md),
                  TerminalSectionTitle(
                    overline: 'Actividad',
                    title: 'Movimientos recientes',
                    description:
                        'Cada cambio modifica el saldo únicamente a través del ledger.',
                  ),
                  const SizedBox(height: TerminalSpace.sm),
                  transactions.when(
                    data: (items) =>
                        _RecentTransactions(items: items.take(6).toList()),
                    loading: () => const _LoadingPanel(),
                    error: (_, _) => _ErrorPanel(
                      label: 'No se pudieron leer los movimientos.',
                      onRetry: () =>
                          ref.invalidate(economyTransactionsProvider),
                    ),
                  ),
                  const SizedBox(height: TerminalSpace.md),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      TerminalOutlineButton(
                        label: 'Ver movimientos',
                        icon: Icons.receipt_long_outlined,
                        onPressed: () =>
                            context.pushNamed('financeTransactions'),
                      ),
                      TerminalOutlineButton(
                        label: 'Análisis',
                        icon: Icons.query_stats_outlined,
                        onPressed: () => context.pushNamed('financeAnalysis'),
                      ),
                      TerminalOutlineButton(
                        label: 'Registrar ajuste',
                        icon: Icons.tune,
                        onPressed: () =>
                            context.pushNamed('financeNewAdjustment'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({required this.value});

  final EconomySnapshot value;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TerminalPanel(
          borderColor: tokens.structuralRed,
          child: Wrap(
            spacing: 38,
            runSpacing: 22,
            children: <Widget>[
              TerminalMetric(
                icon: Icons.account_balance_wallet_outlined,
                value: economyMoney(context, value.totalMinor),
                label: 'Saldo total',
                color: tokens.infoCyan,
              ),
              TerminalMetric(
                icon: Icons.lock_outline,
                value: economyMoney(context, value.reservedMinor),
                label: 'Reservado',
                color: tokens.valueYellow,
              ),
              TerminalMetric(
                icon: Icons.payments_outlined,
                value: economyMoney(context, value.availableMinor),
                label: 'Disponible',
                color: value.availableMinor < 0
                    ? tokens.terminalRed
                    : tokens.progressGreen,
              ),
            ],
          ),
        ),
        const SizedBox(height: TerminalSpace.sm),
        TerminalPanel(
          child: Wrap(
            spacing: 38,
            runSpacing: 20,
            children: <Widget>[
              TerminalMetric(
                icon: Icons.today_outlined,
                value: economyMoney(context, value.dayNetMinor, signed: true),
                label: 'Neto de hoy',
                color: value.dayNetMinor < 0
                    ? tokens.attentionOrange
                    : tokens.progressGreen,
              ),
              TerminalMetric(
                icon: Icons.calendar_month_outlined,
                value: economyMoney(context, value.monthNetMinor, signed: true),
                label: 'Neto del mes',
                color: value.monthNetMinor < 0
                    ? tokens.attentionOrange
                    : tokens.progressGreen,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.items});

  final List<EconomyTransaction> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return TerminalEmptyState(
        title: 'Aún no hay movimientos',
        description: 'Registra un ingreso o gasto para iniciar el ledger.',
        icon: Icons.receipt_long_outlined,
        action: TerminalPrimaryButton(
          label: 'Registrar ingreso',
          icon: Icons.add,
          onPressed: () => context.pushNamed('financeNewIncome'),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final item in items) ...<Widget>[
          EconomyTransactionCard(transaction: item),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class EconomyTransactionCard extends StatelessWidget {
  const EconomyTransactionCard({required this.transaction, super.key});

  final EconomyTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final Color color = transaction.isCredit
        ? tokens.progressGreen
        : tokens.attentionOrange;
    return TerminalCard(
      onTap: () => context.pushNamed(
        'financeTransactionDetail',
        pathParameters: <String, String>{'transactionId': transaction.id},
      ),
      child: Row(
        children: <Widget>[
          Icon(
            transaction.isCredit ? Icons.south_west : Icons.north_east,
            color: color,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  transaction.category ??
                      economyTransactionTypeLabel(transaction.type),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '${economyTransactionTypeLabel(transaction.type)} · ${economyDateTimeLabel(transaction.occurredAtUtc)}',
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                economyMoney(
                  context,
                  transaction.isCredit
                      ? transaction.amountMinor
                      : -transaction.amountMinor,
                  signed: true,
                ),
                style: TextStyle(
                  color: color,
                  fontFamily: 'JetBrains Mono',
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (transaction.isReversed)
                Text(
                  'ANULADO',
                  style: TextStyle(color: tokens.terminalRed, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) => const TerminalPanel(
    padding: EdgeInsets.all(36),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.label, required this.onRetry});

  final String label;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => TerminalEmptyState(
    title: 'Datos no disponibles',
    description: label,
    icon: Icons.error_outline,
    action: TerminalOutlineButton(
      label: 'Reintentar',
      icon: Icons.refresh,
      onPressed: onRetry,
    ),
  );
}
