import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/economy_providers.dart';
import '../domain/models/economy_snapshot.dart';
import 'economy_presentation_support.dart';

class EconomyAnalysisPage extends ConsumerWidget {
  const EconomyAnalysisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(economySnapshotProvider);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: constraints.maxWidth < 820
            ? TerminalSpace.pageCompact
            : TerminalSpace.pageTablet,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const TerminalPageHeader(
                  title: 'Análisis financiero',
                  subtitle:
                      'Lectura del día y del mes calculada desde el ledger',
                ),
                const SizedBox(height: TerminalSpace.md),
                snapshot.when(
                  data: (value) => _Analysis(value: value),
                  loading: () => const TerminalLoadingState(
                    message: 'Calculando análisis financiero…',
                  ),
                  error: (_, _) => TerminalErrorState(
                    title: 'Análisis no disponible',
                    description: 'No se pudo calcular el resumen local.',
                    onRetry: () => ref.invalidate(economySnapshotProvider),
                  ),
                ),
                const SizedBox(height: TerminalSpace.md),
                TerminalOutlineButton(
                  label: 'Volver a Economía',
                  icon: Icons.arrow_back,
                  onPressed: () => context.goNamed('finance'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Analysis extends StatelessWidget {
  const _Analysis({required this.value});

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
            spacing: 34,
            runSpacing: 20,
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
        const SizedBox(height: TerminalSpace.md),
        _PeriodPanel(
          title: 'Hoy',
          income: value.dayIncomeMinor,
          expense: value.dayExpenseMinor,
          net: value.dayNetMinor,
        ),
        const SizedBox(height: TerminalSpace.sm),
        _PeriodPanel(
          title: 'Mes actual',
          income: value.monthIncomeMinor,
          expense: value.monthExpenseMinor,
          net: value.monthNetMinor,
        ),
        const SizedBox(height: TerminalSpace.sm),
        TerminalPanel(
          child: Text(
            'Los reembolsos y ajustes a favor cuentan como entradas; los gastos y ajustes en contra como salidas. Las anulaciones nunca borran historia: agregan una compensación opuesta.',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _PeriodPanel extends StatelessWidget {
  const _PeriodPanel({
    required this.title,
    required this.income,
    required this.expense,
    required this.net,
  });

  final String title;
  final int income;
  final int expense;
  final int net;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    return TerminalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TerminalSectionTitle(title: title, overline: 'Periodo'),
          const SizedBox(height: 18),
          Wrap(
            spacing: 34,
            runSpacing: 20,
            children: <Widget>[
              TerminalMetric(
                icon: Icons.south_west,
                value: economyMoney(context, income),
                label: 'Entradas',
                color: tokens.progressGreen,
              ),
              TerminalMetric(
                icon: Icons.north_east,
                value: economyMoney(context, expense),
                label: 'Salidas',
                color: tokens.attentionOrange,
              ),
              TerminalMetric(
                icon: Icons.balance_outlined,
                value: economyMoney(context, net, signed: true),
                label: 'Neto',
                color: net < 0 ? tokens.terminalRed : tokens.infoCyan,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
