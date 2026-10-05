import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/app_preferences_provider.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../core/result/result.dart';
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

/// Una entrada abierta al estilo del Diario del juego (ADR-006 D18): título
/// rojo, objetivos de su misión con ◆, texto, ánimo, fotos y personajes. La
/// usan el panel derecho del Diario y la pantalla completa del teléfono.
class JournalEntryView extends ConsumerWidget {
  const JournalEntryView({
    required this.entry,
    super.key,
    this.onBack,
    this.onArchived,
  });

  final JournalEntry entry;

  /// Muestra la flecha de volver (pantalla completa).
  final VoidCallback? onBack;

  /// Qué hacer tras archivarla; si falta, solo se avisa.
  final VoidCallback? onArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Column(
      key: ValueKey<String>('journal-entry-view-${entry.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (onBack != null)
              IconButton(
                tooltip: 'Volver',
                onPressed: onBack,
                color: tokens.terminalRed,
                icon: const Icon(Icons.arrow_back),
              ),
            Expanded(
              child: Text(
                entry.title.toUpperCase(),
                key: const Key('journal-entry-title'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: tokens.terminalRed,
                  letterSpacing: 1.2,
                  height: 1.05,
                ),
              ),
            ),
            if (!entry.isArchived) ...<Widget>[
              _ActionIcon(
                key: const Key('journal-entry-edit'),
                tooltip: 'Editar entrada',
                icon: Icons.edit_outlined,
                onPressed: () => context.pushNamed(
                  'journalEdit',
                  pathParameters: <String, String>{'entryId': entry.id},
                ),
              ),
              _ActionIcon(
                key: const Key('journal-entry-add-photo'),
                tooltip: 'Agregar foto (sin EXIF, cifrada)',
                icon: Icons.add_a_photo_outlined,
                onPressed: () => addJournalPhoto(context, ref, entry),
              ),
            ],
            if (entry.isArchived)
              _ActionIcon(
                key: const Key('journal-entry-restore'),
                tooltip: 'Restaurar entrada',
                icon: Icons.restore,
                onPressed: () => _restore(context, ref),
              )
            else
              _ActionIcon(
                key: const Key('journal-entry-archive'),
                tooltip: 'Archivar entrada',
                icon: Icons.archive_outlined,
                onPressed: () => _confirmArchive(context, ref),
              ),
          ],
        ),
        const SizedBox(height: TerminalSpace.xs),
        Wrap(
          spacing: TerminalSpace.md,
          runSpacing: TerminalSpace.xxs,
          children: <Widget>[
            _Meta(journalDateTimeLabel(entry.occurredAtUtc)),
            _Meta(
              journalEntryKindLabel(entry.origin),
              color: tokens.valueYellow,
            ),
            _Meta(entry.isPrivate ? 'Privada' : 'Visible'),
            if (entry.isArchived)
              _Meta('Archivada', color: tokens.attentionOrange),
          ],
        ),
        // Solo se muestra lo que la entrada tiene: nada de «Sin…».
        if (entry.origin == JournalOrigin.mission && entry.missionId != null)
          _MissionObjectives(missionId: entry.missionId!),
        if (entry.body?.trim().isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.only(top: TerminalSpace.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SelectableText(
                entry.body!.trim(),
                key: const Key('journal-entry-body'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: tokens.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
          ),
        if (entry.mood != null)
          Padding(
            padding: const EdgeInsets.only(top: TerminalSpace.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TerminalBadge(
                key: const Key('journal-entry-mood'),
                label: journalMoodLabel(entry.mood),
                color: journalMoodColor(tokens, entry.mood),
                icon: journalMoodIcon(entry.mood),
              ),
            ),
          ),
        _JournalPhotosPanel(entry: entry),
        _EntryContacts(entryId: entry.id),
        if (entry.origin == JournalOrigin.transaction) ...<Widget>[
          const SizedBox(height: TerminalSpace.lg),
          _SourcePanel(entry: entry),
        ],
      ],
    );
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('¿Archivar entrada?'),
        content: const Text(
          'Se ocultará del Diario y de las búsquedas normales. El contenido, '
          'sus vínculos y fotografías se conservarán en el archivo.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            key: const Key('journal-entry-archive-confirm'),
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
    final Result<JournalEntry> result = await ref
        .read(journalApplicationServiceProvider)
        .archive(entry);
    if (!context.mounted) {
      return;
    }
    result.fold<void>(
      onSuccess: (_) {
        _invalidateEntryLists(ref);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Entrada archivada.')));
        onArchived?.call();
      },
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final Result<JournalEntry> result = await ref
        .read(journalApplicationServiceProvider)
        .restore(entry);
    if (!context.mounted) {
      return;
    }
    result.fold<void>(
      onSuccess: (_) {
        _invalidateEntryLists(ref);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Entrada restaurada.')));
      },
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  void _invalidateEntryLists(WidgetRef ref) {
    ref.invalidate(journalEntryDetailProvider(entry.id));
    ref.invalidate(journalEntriesProvider);
    ref.invalidate(journalTimelineProvider);
    ref.invalidate(journalSearchProvider);
    ref.invalidate(archivedJournalEntriesProvider);
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Padding(
      padding: const EdgeInsets.only(left: TerminalSpace.xs),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        // Acciones en rojo, como pidió el usuario (5 oct).
        color: tokens.terminalRed,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            side: BorderSide(color: tokens.border),
            borderRadius: BorderRadius.circular(TerminalRadius.control),
          ),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: 12,
      color:
          color ?? Theme.of(context).extension<AppThemeTokens>()!.textSecondary,
    ),
  );
}

/// Etiqueta pequeña de sección (FOTOGRAFÍAS, PERSONAJES…).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: TerminalLabel(
          text,
          color: Theme.of(context).extension<AppThemeTokens>()!.textSecondary,
        ),
      ),
      ?trailing,
    ],
  );
}

/// ◆ Objetivos de la misión de la entrada (en cian; los cumplidos, tachados)
/// y, debajo, la descripción de la misión en rojo. Lo que no exista no se
/// muestra.
class _MissionObjectives extends ConsumerWidget {
  const _MissionObjectives({required this.missionId});

  final String missionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final Mission? mission = ref.watch(missionDetailProvider(missionId)).value;
    if (mission == null) {
      return const SizedBox.shrink();
    }
    final List<MissionObjective> objectives =
        List<MissionObjective>.of(mission.objectives)..sort(
          (MissionObjective a, MissionObjective b) =>
              a.position.compareTo(b.position),
        );
    final String? description = mission.description?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (objectives.isNotEmpty)
          Container(
            key: const Key('journal-entry-objectives'),
            margin: const EdgeInsets.only(top: TerminalSpace.md),
            padding: const EdgeInsets.all(TerminalSpace.sm),
            constraints: const BoxConstraints(maxWidth: 720),
            decoration: BoxDecoration(border: Border.all(color: tokens.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SectionLabel(
                  'Objetivos',
                  trailing: IconButton(
                    key: const Key('journal-entry-open-mission'),
                    tooltip: 'Abrir misión',
                    visualDensity: VisualDensity.compact,
                    color: tokens.terminalRed,
                    onPressed: () => context.pushNamed(
                      'missionDetail',
                      pathParameters: <String, String>{'missionId': missionId},
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                  ),
                ),
                for (final MissionObjective objective in objectives)
                  _Objective(
                    text: objective.description,
                    done: objective.completedAtUtc != null,
                  ),
              ],
            ),
          ),
        if (description != null && description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: TerminalSpace.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Text(
                description,
                key: const Key('journal-entry-mission-description'),
                style: TextStyle(color: tokens.terminalRed, height: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _Objective extends StatelessWidget {
  const _Objective({required this.text, required this.done});

  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // El mismo amarillo que la «!» de las misiones en la lista.
          Text('◆', style: TextStyle(color: tokens.valueYellow)),
          const SizedBox(width: TerminalSpace.xs),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: tokens.infoCyan,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: tokens.infoCyan,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Personajes de la entrada (los suyos más los de su misión), con el nombre
/// en rojo. Sin personajes, no se muestra nada.
class _EntryContacts extends ConsumerWidget {
  const _EntryContacts({required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final List<Contact> items =
        ref
            .watch(journalEntriesContactsProvider(IdSet(<String>[entryId])))
            .value?[entryId] ??
        const <Contact>[];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: const Key('journal-entry-contacts'),
      padding: const EdgeInsets.only(top: TerminalSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _SectionLabel('Personajes'),
          const SizedBox(height: TerminalSpace.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: ContactThumbnailRow(
              contacts: items,
              nameColor: tokens.terminalRed,
            ),
          ),
        ],
      ),
    );
  }
}

/// Elige una foto (y, si está permitido, la cámara), la cifra y la adjunta.
Future<void> addJournalPhoto(
  BuildContext context,
  WidgetRef ref,
  JournalEntry entry,
) async {
  bool useCamera = false;
  final bool allowCamera =
      ref.read(appPreferencesProvider).value?.allowCameraAttachments ?? false;
  if (allowCamera) {
    final bool? selectedSource = await showModalBottomSheet<bool>(
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
    if (selectedSource == null || !context.mounted) return;
    useCamera = selectedSource;
  }
  final result = await ref
      .read(journalPhotoApplicationServiceProvider)
      .pickAndAdd(entry.id, useCamera: useCamera);
  if (!context.mounted) {
    return;
  }
  result.fold<void>(
    onSuccess: (JournalPhoto? photo) {
      if (photo == null) return;
      ref.invalidate(journalPhotosProvider(entry.id));
      ref.invalidate(journalEntryDetailProvider(entry.id));
      ref.invalidate(journalEntriesProvider);
      ref.invalidate(journalTimelineProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotografía normalizada, cifrada y adjuntada.'),
        ),
      );
    },
    onFailure: (failure) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failure.message))),
  );
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
    final List<JournalPhoto> items =
        ref.watch(journalPhotosProvider(widget.entry.id)).value ??
        const <JournalPhoto>[];
    // Sin fotos no se muestra nada; se añaden con la cámara de arriba.
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: const Key('journal-entry-photos'),
      padding: const EdgeInsets.only(top: TerminalSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _SectionLabel('Fotografías'),
          const SizedBox(height: TerminalSpace.xs),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            // Miniaturas pequeñas, como en el Diario del juego.
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 170,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.25,
            ),
            itemBuilder: (BuildContext context, int index) => _PrivatePhotoTile(
              photo: items[index],
              disabled: _working || widget.entry.isArchived,
              onRemove: () => _removePhoto(items[index]),
            ),
          ),
        ],
      ),
    );
  }

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
