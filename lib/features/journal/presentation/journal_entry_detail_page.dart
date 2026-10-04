import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/app_preferences_provider.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../contacts/application/contact_providers.dart';
import '../../contacts/domain/models/contact.dart';
import '../../contacts/presentation/contact_widgets.dart';
import '../../economy/application/economy_providers.dart';
import '../../economy/domain/models/economy_models.dart';
import '../../economy/presentation/economy_presentation_support.dart';
import '../../missions/application/mission_providers.dart';
import '../../missions/domain/models/mission.dart';
import '../../missions/presentation/mission_presentation_support.dart';
import '../application/journal_providers.dart';
import '../domain/models/journal_entry.dart';
import '../domain/models/journal_photo.dart';
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
      loading: () => const TerminalAsyncStatePage(
        child: TerminalLoadingState(message: 'Cargando entrada de Bitácora…'),
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
            if (!entry.isArchived)
              TerminalPrimaryButton(
                label: 'Editar entrada',
                icon: Icons.edit_outlined,
                onPressed: () => context.pushNamed(
                  'journalEdit',
                  pathParameters: <String, String>{'entryId': entry.id},
                ),
              ),
            if (entry.isArchived)
              TerminalPrimaryButton(
                label: 'Restaurar entrada',
                icon: Icons.restore,
                onPressed: () => _restore(context, ref, entry),
              )
            else
              TerminalCriticalButton(
                label: 'Archivar entrada',
                icon: Icons.archive_outlined,
                onPressed: () => _confirmArchive(context, ref, entry),
              ),
            TerminalOutlineButton(
              label: entry.isArchived
                  ? 'Volver al archivo'
                  : 'Volver a Bitácora',
              icon: Icons.arrow_back,
              color: tokens.textSecondary,
              onPressed: () => context.goNamed(
                entry.isArchived ? 'journalArchive' : 'journal',
              ),
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
        const SizedBox(height: TerminalSpace.md),
        _EntryContactsPanel(entryId: entry.id),
        const SizedBox(height: TerminalSpace.md),
        _JournalPhotosPanel(entry: entry),
        if (entry.origin == JournalOrigin.mission ||
            entry.origin == JournalOrigin.transaction) ...<Widget>[
          const SizedBox(height: TerminalSpace.md),
          _SourcePanel(entry: entry),
        ],
      ],
    );
  }

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    JournalEntry entry,
  ) async {
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('¿Archivar entrada?'),
        content: const Text(
          'Se ocultará de la cronología y de las búsquedas normales. '
          'El contenido, sus vínculos y fotografías se conservarán.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) {
      return;
    }
    final result = await ref
        .read(journalApplicationServiceProvider)
        .archive(entry);
    if (!context.mounted) {
      return;
    }
    result.fold<void>(
      onSuccess: (_) {
        _invalidateEntryLists(ref, entry.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Entrada archivada.')));
        context.goNamed('journalArchive');
      },
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    JournalEntry entry,
  ) async {
    final result = await ref
        .read(journalApplicationServiceProvider)
        .restore(entry);
    if (!context.mounted) {
      return;
    }
    result.fold<void>(
      onSuccess: (_) {
        _invalidateEntryLists(ref, entry.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Entrada restaurada.')));
        context.goNamed(
          'journalDetail',
          pathParameters: <String, String>{'entryId': entry.id},
        );
      },
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  void _invalidateEntryLists(WidgetRef ref, String entryId) {
    ref.invalidate(journalEntryDetailProvider(entryId));
    ref.invalidate(journalEntriesProvider);
    ref.invalidate(journalSearchProvider);
    ref.invalidate(archivedJournalEntriesProvider);
  }
}

/// Personajes de la entrada: los suyos más los de su misión (ADR-006).
class _EntryContactsPanel extends ConsumerWidget {
  const _EntryContactsPanel({required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final AsyncValue<Map<String, List<Contact>>> contacts = ref.watch(
      journalEntriesContactsProvider(IdSet(<String>[entryId])),
    );
    return TerminalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const TerminalSectionTitle(overline: 'Diario', title: 'Personajes'),
          const SizedBox(height: TerminalSpace.sm),
          contacts.when(
            data: (Map<String, List<Contact>> grouped) {
              final List<Contact> items = grouped[entryId] ?? const <Contact>[];
              return items.isEmpty
                  ? Text(
                      'Sin personajes. Puedes elegirlos al editar la entrada.',
                      style: TextStyle(color: tokens.textSecondary),
                    )
                  : ContactThumbnailRow(contacts: items);
            },
            loading: () =>
                const TerminalInlineLoadingState(message: 'Cargando…'),
            error: (_, _) => const TerminalInlineErrorState(
              message: 'No se pudieron leer los personajes.',
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalPhotosPanel extends ConsumerStatefulWidget {
  const _JournalPhotosPanel({required this.entry});

  final JournalEntry entry;

  @override
  ConsumerState<_JournalPhotosPanel> createState() =>
      _JournalPhotosPanelState();
}

class _JournalPhotosPanelState extends ConsumerState<_JournalPhotosPanel> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final AsyncValue<List<JournalPhoto>> photos = ref.watch(
      journalPhotosProvider(widget.entry.id),
    );
    return TerminalPanel(
      borderColor: tokens.infoCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: TerminalSectionTitle(
                  overline: 'Archivo privado cifrado',
                  title: 'Fotografías',
                ),
              ),
              if (!widget.entry.isArchived)
                TerminalOutlineButton(
                  label: _working ? 'Procesando' : 'Agregar foto',
                  icon: _working
                      ? Icons.hourglass_top
                      : Icons.add_photo_alternate_outlined,
                  onPressed: _working ? null : _addPhoto,
                ),
            ],
          ),
          const SizedBox(height: TerminalSpace.sm),
          Text(
            'Se elimina EXIF y la imagen se cifra antes de guardarse.',
            style: TextStyle(color: tokens.textSecondary),
          ),
          const SizedBox(height: TerminalSpace.md),
          photos.when(
            data: (List<JournalPhoto> items) => items.isEmpty
                ? const Text('Todavía no hay fotografías adjuntas.')
                : LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints bounds) {
                      final int columns = bounds.maxWidth >= 900
                          ? 4
                          : bounds.maxWidth >= 560
                          ? 3
                          : 2;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                        ),
                        itemBuilder: (BuildContext context, int index) =>
                            _PrivatePhotoTile(
                              photo: items[index],
                              disabled: _working || widget.entry.isArchived,
                              onRemove: () => _removePhoto(items[index]),
                            ),
                      );
                    },
                  ),
            loading: () => const TerminalInlineLoadingState(
              message: 'Cargando fotografías privadas…',
            ),
            error: (_, _) => TerminalInlineErrorState(
              message: 'No se pudieron leer las fotografías privadas.',
              onRetry: () =>
                  ref.invalidate(journalPhotosProvider(widget.entry.id)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addPhoto() async {
    bool useCamera = false;
    final bool allowCamera =
        ref.read(appPreferencesProvider).value?.allowCameraAttachments ?? false;
    if (allowCamera) {
      final bool? selectedSource = await _pickPhotoSource();
      if (selectedSource == null || !mounted) return;
      useCamera = selectedSource;
    }
    setState(() => _working = true);
    final result = await ref
        .read(journalPhotoApplicationServiceProvider)
        .pickAndAdd(widget.entry.id, useCamera: useCamera);
    if (!mounted) {
      return;
    }
    setState(() => _working = false);
    result.fold<void>(
      onSuccess: (JournalPhoto? photo) {
        if (photo != null) {
          _refresh();
          _showMessage('Fotografía normalizada, cifrada y adjuntada.');
        }
      },
      onFailure: (failure) => _showMessage(failure.message),
    );
  }

  Future<bool?> _pickPhotoSource() => showModalBottomSheet<bool>(
    context: context,
    builder: (BuildContext sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            key: const Key('attach-from-camera'),
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Sacar foto'),
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
          ListTile(
            key: const Key('attach-from-gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    ),
  );

  Future<void> _removePhoto(JournalPhoto photo) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Retirar fotografía'),
        content: const Text(
          'La fotografía dejará de aparecer en esta entrada y se quitará su archivo cifrado local.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _working = true);
    final result = await ref
        .read(journalPhotoApplicationServiceProvider)
        .remove(photo);
    if (!mounted) {
      return;
    }
    setState(() => _working = false);
    result.fold<void>(
      onSuccess: (_) {
        _refresh();
        _showMessage('Fotografía retirada.');
      },
      onFailure: (failure) => _showMessage(failure.message),
    );
  }

  void _refresh() {
    ref.invalidate(journalPhotosProvider(widget.entry.id));
    ref.invalidate(journalEntryDetailProvider(widget.entry.id));
    ref.invalidate(journalEntriesProvider);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PrivatePhotoTile extends ConsumerWidget {
  const _PrivatePhotoTile({
    required this.photo,
    required this.disabled,
    required this.onRemove,
  });

  final JournalPhoto photo;
  final bool disabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final AsyncValue<Uint8List> bytes = ref.watch(
      journalPhotoBytesProvider(photo),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            bytes.when(
              data: (Uint8List value) => InkWell(
                onTap: () => _showFullPhoto(context, value),
                child: Image.memory(
                  value,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
              loading: () => Semantics(
                liveRegion: true,
                label: 'Cargando fotografía privada',
                child: ExcludeSemantics(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, _) => Semantics(
                label: 'Fotografía privada no disponible',
                child: ExcludeSemantics(
                  child: Center(
                    child: Icon(Icons.broken_image_outlined, size: 36),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton.filledTonal(
                tooltip: 'Retirar fotografía',
                onPressed: disabled ? null : onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ),
            const Positioned(
              left: 7,
              bottom: 7,
              child: Icon(Icons.lock, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullPhoto(BuildContext context, Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: <Widget>[
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton.filled(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
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
            loading: () => const TerminalInlineLoadingState(
              message: 'Cargando misión vinculada…',
            ),
            error: (_, _) => TerminalInlineErrorState(
              message: 'No se pudo leer la misión vinculada.',
              onRetry: () => ref.invalidate(missionDetailProvider(id)),
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
                    context,
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
          loading: () => const TerminalInlineLoadingState(
            message: 'Cargando movimiento vinculado…',
          ),
          error: (_, _) => TerminalInlineErrorState(
            message: 'No se pudo leer el movimiento vinculado.',
            onRetry: () => ref.invalidate(economyTransactionDetailProvider(id)),
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
  JournalMood.happy => tokens.valueYellow,
  JournalMood.motivated => tokens.progressGreen,
  JournalMood.focused => tokens.progressGreen,
  JournalMood.calm => tokens.infoCyan,
  JournalMood.normal => tokens.infoCyan,
  JournalMood.anxious => tokens.attentionOrange,
  JournalMood.sad => tokens.structuralRed,
  JournalMood.tired => tokens.attentionOrange,
  null => tokens.textDisabled,
};
