import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/journal_providers.dart';
import '../domain/models/journal_entry.dart';
import 'journal_entry_view.dart';
import 'journal_presentation_support.dart';

/// Una entrada a pantalla completa: en el teléfono, desde el archivo o la
/// búsqueda y por enlace. En la tablet, el Diario la abre en su panel.
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
          : JournalPageFrame(
              child: JournalEntryView(
                entry: value,
                onBack: () => _back(context, value),
                onArchived: () => context.goNamed('journalArchive'),
              ),
            ),
      loading: () => const TerminalAsyncStatePage(
        child: TerminalLoadingState(message: 'Cargando entrada del Diario…'),
      ),
      error: (_, _) => TerminalAsyncStatePage(
        child: TerminalErrorState(
          title: 'Entrada no disponible',
          description: 'No se pudo leer la entrada desde la base local.',
          onRetry: () => ref.invalidate(journalEntryDetailProvider(entryId)),
        ),
      ),
    );
  }

  void _back(BuildContext context, JournalEntry entry) {
    if (context.canPop()) {
      context.pop();
    } else if (entry.isArchived) {
      context.goNamed('journalArchive');
    } else {
      goToDiary(context);
    }
  }
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
        label: 'Volver al Diario',
        icon: Icons.arrow_back,
        onPressed: () => goToDiary(context),
      ),
    ),
  );
}
