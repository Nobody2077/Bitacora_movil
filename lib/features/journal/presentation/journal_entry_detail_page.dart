import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../economy/application/economy_providers.dart';
import '../../economy/domain/models/economy_models.dart';
import '../../economy/presentation/economy_presentation_support.dart';
import '../../missions/application/mission_providers.dart';
import '../../missions/domain/models/mission.dart';
import '../../missions/presentation/mission_presentation_support.dart';
import '../application/journal_providers.dart';
import '../domain/models/journal_entry.dart';
import 'journal_presentation_support.dart';

class JournalEntryDetailPage extends ConsumerWidget {
  const JournalEntryDetailPage({required this.entryId, super.key});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<JournalEntry?> entry = ref.watch(
      journalEntryDetailProvider(entryId),
    );
    return entry.when(
      data: (JournalEntry? value) => value == null
          ? const _Unavailable()
          : JournalPageFrame(child: _detail(context, ref, value)),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _Unavailable(),
    );
  }

  Widget _detail(BuildContext context, WidgetRef ref, JournalEntry entry) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TerminalPageHeader(
          title: entry.title,
          subtitle: 'Entrada histórica de ${journalOriginLabel(entry.origin)}',
        ),
        const SizedBox(height: TerminalSpace.md),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            TerminalPrimaryButton(
              label: 'Editar entrada',
              icon: Icons.edit_outlined,
              onPressed: () => context.pushNamed(
                'journalEdit',
                pathParameters: <String, String>{'entryId': entry.id},
              ),
            ),
            TerminalOutlineButton(
              label: 'Volver a Bitácora',
              icon: Icons.arrow_back,
              color: tokens.textSecondary,
              onPressed: () => context.goNamed('journal'),
            ),
          ],
        ),
        const SizedBox(height: TerminalSpace.md),
        TerminalPanel(
          borderColor: tokens.structuralRed,
          child: Wrap(
            spacing: 30,
            runSpacing: 18,
            children: <Widget>[
              TerminalMetric(
                icon: journalMoodIcon(entry.mood),
                value: journalMoodLabel(entry.mood),
                label: 'Estado',
                color: _moodColor(tokens, entry.mood),
              ),
              TerminalMetric(
                icon: Icons.schedule,
                value: journalDateTimeLabel(entry.occurredAtUtc),
                label: 'Ocurrió',
                color: tokens.infoCyan,
              ),
              TerminalMetric(
                icon: entry.isPrivate
                    ? Icons.lock_outline
                    : Icons.lock_open_outlined,
                value: entry.isPrivate ? 'Privada' : 'Visible',
                label: 'Privacidad',
                color: entry.isPrivate
                    ? tokens.valueYellow
                    : tokens.textSecondary,
              ),
              if (entry.attachmentCount > 0)
                TerminalMetric(
                  icon: Icons.photo_outlined,
                  value: '${entry.attachmentCount}',
                  label: 'Fotografías',
                  color: tokens.attentionOrange,
                ),
            ],
          ),
        ),
        const SizedBox(height: TerminalSpace.md),
        TerminalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const TerminalSectionTitle(
                overline: 'Contenido',
                title: 'Registro',
              ),
              const SizedBox(height: TerminalSpace.sm),
              SelectableText(
                journalBodyPreview(entry.body),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: entry.body == null
                      ? tokens.textDisabled
                      : tokens.textPrimary,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        if (entry.origin == JournalOrigin.mission ||
            entry.origin == JournalOrigin.transaction) ...<Widget>[
          const SizedBox(height: TerminalSpace.md),
          _SourcePanel(entry: entry),
        ],
      ],
    );
  }
}

class _SourcePanel extends ConsumerWidget {
  const _SourcePanel({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entry.origin == JournalOrigin.mission) {
      final String? id = entry.missionId;
      if (id == null) {
        return const _MissingSource(label: 'La misión de origen ya no existe.');
      }
      return ref
          .watch(missionDetailProvider(id))
          .when(
            data: (Mission? mission) => mission == null
                ? const _MissingSource(
                    label: 'La misión de origen ya no está disponible.',
                  )
                : _LinkedSource(
                    icon: Icons.flag_outlined,
                    overline: 'Misión vinculada',
                    title: mission.title,
                    description: missionStatusLabel(mission.status),
                    onOpen: () => context.pushNamed(
                      'missionDetail',
                      pathParameters: <String, String>{'missionId': id},
                    ),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const _MissingSource(
              label: 'No se pudo leer la misión vinculada.',
            ),
          );
    }

    final String? id = entry.transactionId;
    if (id == null) {
      return const _MissingSource(
        label: 'El movimiento de origen ya no existe.',
      );
    }
    return ref
        .watch(economyTransactionDetailProvider(id))
        .when(
          data: (EconomyTransaction? transaction) => transaction == null
              ? const _MissingSource(
                  label: 'El movimiento de origen ya no está disponible.',
                )
              : _LinkedSource(
                  icon: Icons.receipt_long_outlined,
                  overline: 'Movimiento vinculado',
                  title:
                      transaction.category ??
                      economyTransactionTypeLabel(transaction.type),
                  description: economyMoney(
                    transaction.isCredit
                        ? transaction.amountMinor
                        : -transaction.amountMinor,
                    signed: true,
                  ),
                  onOpen: () => context.pushNamed(
                    'financeTransactionDetail',
                    pathParameters: <String, String>{'transactionId': id},
                  ),
                ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const _MissingSource(
            label: 'No se pudo leer el movimiento vinculado.',
          ),
        );
  }
}

class _LinkedSource extends StatelessWidget {
  const _LinkedSource({
    required this.icon,
    required this.overline,
    required this.title,
    required this.description,
    required this.onOpen,
  });

  final IconData icon;
  final String overline;
  final String title;
  final String description;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalCard(
      onTap: onOpen,
      borderColor: tokens.infoCyan,
      child: Row(
        children: <Widget>[
          Icon(icon, color: tokens.infoCyan, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TerminalLabel(overline, color: tokens.infoCyan),
                const SizedBox(height: 4),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  description,
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.open_in_new, color: tokens.infoCyan),
        ],
      ),
    );
  }
}

class _MissingSource extends StatelessWidget {
  const _MissingSource({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => TerminalPanel(
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.link_off),
      title: const Text('Fuente histórica'),
      subtitle: Text(label),
    ),
  );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) => JournalPageFrame(
    child: TerminalEmptyState(
      title: 'Entrada no disponible',
      description: 'No existe o no se pudo leer desde la base local.',
      icon: Icons.error_outline,
      action: TerminalOutlineButton(
        label: 'Volver a Bitácora',
        icon: Icons.arrow_back,
        onPressed: () => context.goNamed('journal'),
      ),
    ),
  );
}

Color _moodColor(AppThemeTokens tokens, JournalMood? mood) => switch (mood) {
  JournalMood.focused => tokens.progressGreen,
  JournalMood.normal => tokens.infoCyan,
  JournalMood.tired => tokens.attentionOrange,
  null => tokens.textDisabled,
};
