import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../journal/presentation/journal_presentation_support.dart';
import '../../photos/application/entity_photo_providers.dart';
import '../../photos/domain/entity_photo.dart';
import '../../photos/presentation/entity_photo_actions.dart';
import '../../photos/presentation/entity_photo_avatar.dart';
import '../application/contact_application_service.dart';
import '../application/contact_providers.dart';
import '../domain/models/contact.dart';
import 'contact_widgets.dart';

/// Vista «Personajes» del Diario: cuadrícula, «+ Crear personaje» y archivo.
class ContactsSection extends ConsumerStatefulWidget {
  const ContactsSection({super.key});

  @override
  ConsumerState<ContactsSection> createState() => _ContactsSectionState();
}

class _ContactsSectionState extends ConsumerState<ContactsSection> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    // Recoge ficheros cifrados de fotos que quedaron sin fila (ADR-006).
    ref.watch(entityPhotoCleanupProvider);
    final AsyncValue<List<Contact>> contacts = ref.watch(
      _showArchived ? archivedContactsProvider : activeContactsProvider,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: TerminalSpace.sm,
          runSpacing: TerminalSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            TerminalPrimaryButton(
              key: const Key('contact-create'),
              label: 'Crear personaje',
              icon: Icons.person_add_alt_1_outlined,
              onPressed: () => context.pushNamed('contactNew'),
            ),
            TerminalOutlineButton(
              key: const Key('contact-toggle-archived'),
              label: _showArchived ? 'Ver activos' : 'Archivados',
              icon: _showArchived
                  ? Icons.groups_outlined
                  : Icons.inventory_2_outlined,
              onPressed: () => setState(() => _showArchived = !_showArchived),
            ),
          ],
        ),
        const SizedBox(height: TerminalSpace.md),
        contacts.when(
          data: (List<Contact> items) => items.isEmpty
              ? TerminalEmptyState(
                  title: _showArchived
                      ? 'No hay personajes archivados'
                      : 'Aún no hay personajes',
                  description: _showArchived
                      ? 'Los personajes que archives aparecerán aquí.'
                      : 'Personas reales de tu vida. Nombre, descripción y '
                            'foto son opcionales.',
                  icon: Icons.groups_outlined,
                )
              : _ContactGrid(contacts: items),
          loading: () =>
              const TerminalLoadingState(message: 'Cargando personajes…'),
          error: (_, _) => TerminalErrorState(
            title: 'No se pudieron leer los personajes',
            description: 'Reintenta la lectura desde la base local cifrada.',
            onRetry: () => ref.invalidate(
              _showArchived ? archivedContactsProvider : activeContactsProvider,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactGrid extends StatelessWidget {
  const _ContactGrid({required this.contacts});

  final List<Contact> contacts;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final int columns = (constraints.maxWidth / 260).floor().clamp(1, 4);
      const double gap = TerminalSpace.sm;
      final double width =
          (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: <Widget>[
          for (final Contact contact in contacts)
            SizedBox(
              width: width,
              child: ContactCard(contact: contact),
            ),
        ],
      );
    },
  );
}

/// Ficha de un personaje al estilo del juego (paso 10 de la fase 2): foto
/// grande a la izquierda y un panel de borde rojo con el nombre en cian, el
/// rol en amarillo y la descripción en rojo. Ocupa todo el contenido y
/// «CERRAR» vuelve a PERSONAJES. Solo se muestra lo que el personaje tiene.
class ContactDetailPage extends ConsumerStatefulWidget {
  const ContactDetailPage({required this.contactId, super.key});

  final String contactId;

  /// Desde este ancho, foto y panel van uno al lado del otro.
  static const double sideBySideFrom = 760;

  @override
  ConsumerState<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends ConsumerState<ContactDetailPage> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Contact?> contactAsync = ref.watch(
      contactProvider(widget.contactId),
    );
    return contactAsync.when(
      loading: () => const TerminalAsyncStatePage(
        child: TerminalLoadingState(message: 'Abriendo ficha…'),
      ),
      error: (_, _) => TerminalAsyncStatePage(
        child: TerminalErrorState(
          title: 'Ficha no disponible',
          description: 'No se pudo leer el personaje.',
          onRetry: () => ref.invalidate(contactProvider(widget.contactId)),
        ),
      ),
      data: (Contact? contact) => contact == null
          ? const TerminalAsyncStatePage(
              child: TerminalEmptyState(
                title: 'Personaje no encontrado',
                description: 'Puede que el enlace ya no sea válido.',
                icon: Icons.person_off_outlined,
              ),
            )
          : _buildDossier(context, contact),
    );
  }

  Widget _buildDossier(BuildContext context, Contact contact) {
    final bool hasPhoto =
        ref
            .watch(
              entityPhotoProvider((
                owner: EntityPhotoOwner.contact,
                ownerId: contact.id,
              )),
            )
            .value !=
        null;
    final String code = contactDossierCode(contact.id);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool sideBySide =
            constraints.maxWidth >= ContactDetailPage.sideBySideFrom;
        final double photoWidth = sideBySide
            ? 340
            : (constraints.maxWidth - 32).clamp(0, 420).toDouble();
        final Widget portrait = _DossierPortrait(
          contact: contact,
          code: code,
          width: photoWidth,
        );
        final Widget panel = _DossierPanel(
          contact: contact,
          code: code,
          hasPhoto: hasPhoto,
          working: _working,
          onEdit: () => context.pushNamed(
            'contactEdit',
            pathParameters: <String, String>{'contactId': contact.id},
          ),
          onPhoto: () => _photo(contact, hasPhoto),
          onArchive: () => _archive(contact),
          onRestore: () => _restore(contact),
        );
        return SingleChildScrollView(
          padding: sideBySide
              ? const EdgeInsets.fromLTRB(48, 40, 48, 32)
              : TerminalSpace.pageCompact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (sideBySide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    portrait,
                    const SizedBox(width: 36),
                    Expanded(child: panel),
                  ],
                )
              else ...<Widget>[
                Center(child: portrait),
                const SizedBox(height: TerminalSpace.lg),
                panel,
              ],
              const SizedBox(height: TerminalSpace.lg),
              Align(
                alignment: Alignment.centerRight,
                child: _CloseButton(onPressed: _close),
              ),
            ],
          ),
        );
      },
    );
  }

  void _close() => context.canPop()
      ? context.pop()
      : context.goNamed(
          'character',
          queryParameters: const <String, String>{'tab': 'diario'},
        );

  /// Sin foto, la elige; con foto, ofrece cambiarla o quitarla.
  Future<void> _photo(Contact contact, bool hasPhoto) async {
    if (!hasPhoto) {
      await _busy(
        () => pickEntityPhoto(
          context,
          ref,
          owner: EntityPhotoOwner.contact,
          ownerId: contact.id,
        ),
      );
      return;
    }
    final bool? change = await showModalBottomSheet<bool>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              key: const Key('contact-photo-change'),
              leading: const Icon(Icons.add_a_photo_outlined),
              title: const Text('Cambiar foto'),
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
            ListTile(
              key: const Key('contact-photo-remove'),
              leading: const Icon(Icons.hide_image_outlined),
              title: const Text('Quitar foto'),
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    );
    if (change == null || !mounted) return;
    await _busy(
      () => change
          ? pickEntityPhoto(
              context,
              ref,
              owner: EntityPhotoOwner.contact,
              ownerId: contact.id,
            )
          : removeEntityPhoto(
              context,
              ref,
              owner: EntityPhotoOwner.contact,
              ownerId: contact.id,
            ),
    );
  }

  Future<void> _busy(Future<void> Function() action) async {
    setState(() => _working = true);
    await action();
    if (mounted) setState(() => _working = false);
  }

  Future<void> _archive(Contact contact) async {
    final bool confirmed = await _confirm(
      title: 'Eliminar personaje',
      message:
          'Se archiva: deja de salir en la lista y al elegir personajes, pero '
          'sus misiones y entradas lo siguen mostrando. Puedes restaurarlo '
          'desde Archivados.',
      action: 'Eliminar',
    );
    if (!confirmed) return;
    await _run(
      () => ref.read(contactApplicationServiceProvider).archive(contact),
      success: 'Personaje archivado.',
    );
  }

  Future<void> _restore(Contact contact) => _run(
    () => ref.read(contactApplicationServiceProvider).restore(contact),
    success: 'Personaje restaurado.',
  );

  Future<void> _run<T>(
    Future<Result<T>> Function() action, {
    required String success,
  }) async {
    setState(() => _working = true);
    final Result<T> result = await action();
    if (!mounted) return;
    setState(() => _working = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.fold(
            onSuccess: (_) => success,
            onFailure: (AppFailure failure) => failure.message,
          ),
        ),
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('contact-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return accepted == true && mounted;
  }
}

/// Código decorativo de la ficha, sacado del identificador del personaje:
/// «PJ_4F2A91».
String contactDossierCode(String id) {
  final String compact = id.replaceAll(RegExp('[^A-Za-z0-9]'), '');
  final String head = compact.length > 6 ? compact.substring(0, 6) : compact;
  return 'PJ_${head.toUpperCase()}';
}

/// Texto pequeño de los códigos decorativos, en rojo apagado.
TextStyle _codeStyle(AppThemeTokens tokens) => TextStyle(
  color: tokens.terminalRed.withValues(alpha: 0.7),
  fontFamily: 'JetBrains Mono',
  fontSize: 10,
  letterSpacing: 0.6,
  height: 1.35,
);

class _DossierPortrait extends StatelessWidget {
  const _DossierPortrait({
    required this.contact,
    required this.code,
    required this.width,
  });

  final Contact contact;
  final String code;
  final double width;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final DateTime created = contact.createdAtUtc.toLocal();
    final String date =
        '${created.day.toString().padLeft(2, '0')}.'
        '${created.month.toString().padLeft(2, '0')}.'
        '${(created.year % 100).toString().padLeft(2, '0')}';
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          EntityPhotoAvatar(
            key: const Key('contact-dossier-photo'),
            owner: EntityPhotoOwner.contact,
            ownerId: contact.id,
            fallbackLabel: contact.displayName ?? '',
            width: width,
            height: width * 4 / 3,
            dimmed: contact.isArchived,
          ),
          const SizedBox(height: TerminalSpace.xs),
          Container(
            padding: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: tokens.structuralRed)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Text(
                    'PROTOCOLO\nARCHIVO LOCAL\nCIFRADO',
                    style: _codeStyle(tokens),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: tokens.structuralRed),
                  ),
                  child: Text(code, style: _codeStyle(tokens)),
                ),
                const SizedBox(width: TerminalSpace.sm),
                Text('FICHA · $date', style: _codeStyle(tokens)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DossierPanel extends StatelessWidget {
  const _DossierPanel({
    required this.contact,
    required this.code,
    required this.hasPhoto,
    required this.working,
    required this.onEdit,
    required this.onPhoto,
    required this.onArchive,
    required this.onRestore,
  });

  final Contact contact;
  final String code;
  final bool hasPhoto;
  final bool working;
  final VoidCallback onEdit;
  final VoidCallback onPhoto;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final String? role = contact.role?.trim();
    final String? description = contact.description?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Text(
                'TRN_$code',
                key: const Key('contact-dossier-code'),
                style: _codeStyle(tokens),
              ),
            ),
            Text(
              hasPhoto
                  ? 'IMAGEN: FOTO_CIFRADA\nTIPO: AES-GCM · SIN EXIF'
                  : 'IMAGEN: SIN FOTO',
              textAlign: TextAlign.right,
              style: _codeStyle(tokens),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          key: const Key('contact-dossier-panel'),
          constraints: const BoxConstraints(minHeight: 360),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
          decoration: ShapeDecoration(
            color: const Color(0xD108050A),
            shape: TerminalCutCornerBorder(
              cut: 14,
              side: BorderSide(color: tokens.structuralRed),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      contactName(contact).toUpperCase(),
                      key: const Key('contact-dossier-name'),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: tokens.infoCyan,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            height: 1.05,
                          ),
                    ),
                  ),
                  if (!contact.isArchived) ...<Widget>[
                    _RedIcon(
                      key: const Key('contact-edit'),
                      tooltip: 'Editar',
                      icon: Icons.edit_outlined,
                      onPressed: working ? null : onEdit,
                    ),
                    _RedIcon(
                      key: const Key('contact-photo'),
                      tooltip: hasPhoto
                          ? 'Cambiar o quitar foto'
                          : 'Añadir foto',
                      icon: Icons.add_a_photo_outlined,
                      onPressed: working ? null : onPhoto,
                    ),
                    _RedIcon(
                      key: const Key('contact-archive'),
                      tooltip: 'Eliminar (archivar)',
                      icon: Icons.archive_outlined,
                      onPressed: working ? null : onArchive,
                    ),
                  ] else
                    _RedIcon(
                      key: const Key('contact-restore'),
                      tooltip: 'Restaurar',
                      icon: Icons.unarchive_outlined,
                      onPressed: working ? null : onRestore,
                    ),
                ],
              ),
              if (contact.isArchived)
                Padding(
                  padding: const EdgeInsets.only(top: TerminalSpace.xs),
                  child: Text(
                    'ARCHIVADO',
                    style: TextStyle(
                      color: tokens.attentionOrange,
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              if (role != null && role.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: TerminalSpace.xs),
                  child: Text(
                    role.toUpperCase(),
                    key: const Key('contact-dossier-role'),
                    style: TextStyle(
                      color: tokens.valueYellow,
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              if (description != null && description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: TerminalSpace.md),
                  child: SelectableText(
                    description,
                    key: const Key('contact-dossier-description'),
                    style: TextStyle(
                      color: tokens.terminalRed,
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w500,
                      fontSize: 19,
                      height: 1.55,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text('TRN_$code', style: _codeStyle(tokens)),
        ),
      ],
    );
  }
}

class _RedIcon extends StatelessWidget {
  const _RedIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

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
        color: tokens.terminalRed,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            side: BorderSide(color: tokens.structuralRed),
          ),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

/// «◂ CERRAR», como en el juego: vuelve a PERSONAJES.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return InkWell(
      key: const Key('contact-dossier-close'),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(TerminalSpace.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: tokens.infoCyan),
              ),
              child: Text(
                '◂',
                style: TextStyle(color: tokens.infoCyan, fontSize: 12),
              ),
            ),
            const SizedBox(width: TerminalSpace.xs),
            Text(
              'CERRAR',
              style: TextStyle(
                color: tokens.terminalRed,
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Crear o editar nombre, rol y descripción. La foto se pone desde la ficha,
/// porque necesita que el personaje ya exista.
class ContactFormPage extends ConsumerStatefulWidget {
  const ContactFormPage({super.key, this.contactId});

  final String? contactId;

  @override
  ConsumerState<ContactFormPage> createState() => _ContactFormPageState();
}

class _ContactFormPageState extends ConsumerState<ContactFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _role = TextEditingController();
  final TextEditingController _description = TextEditingController();
  Contact? _existing;
  bool _initialized = false;
  bool _saving = false;

  bool get _isEditing => widget.contactId != null;

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      final AsyncValue<Contact?> existing = ref.watch(
        contactProvider(widget.contactId!),
      );
      if (existing.isLoading && !_initialized) {
        return const TerminalAsyncStatePage(
          child: TerminalLoadingState(message: 'Preparando personaje…'),
        );
      }
      final Contact? contact = existing.value;
      if (contact == null || contact.isArchived) {
        return const TerminalAsyncStatePage(
          child: TerminalEmptyState(
            title: 'Personaje no disponible',
            description: 'No existe o está archivado.',
            icon: Icons.person_off_outlined,
          ),
        );
      }
      if (!_initialized) {
        _existing = contact;
        _name.text = contact.displayName ?? '';
        _role.text = contact.role ?? '';
        _description.text = contact.description ?? '';
        _initialized = true;
      }
    }

    return JournalPageFrame(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TerminalPageHeader(
              title: _isEditing ? 'Editar personaje' : 'Crear personaje',
              subtitle: 'Todo es opcional: nombre, rol y descripción',
            ),
            const SizedBox(height: TerminalSpace.md),
            TerminalPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    key: const Key('contact-name'),
                    controller: _name,
                    autofocus: !_isEditing,
                    maxLength: Contact.maxDisplayNameLength,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: TerminalSpace.sm),
                  TextFormField(
                    key: const Key('contact-role'),
                    controller: _role,
                    maxLength: Contact.maxRoleLength,
                    decoration: const InputDecoration(
                      labelText: 'Rol (por ejemplo, «Docente · Cálculo II»)',
                      prefixIcon: Icon(Icons.work_outline),
                    ),
                  ),
                  const SizedBox(height: TerminalSpace.sm),
                  TextFormField(
                    key: const Key('contact-description'),
                    controller: _description,
                    minLines: 4,
                    maxLines: 10,
                    maxLength: Contact.maxDescriptionLength,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isEditing) ...<Widget>[
              const SizedBox(height: TerminalSpace.sm),
              Text(
                'Después de guardar podrás añadir su foto desde la ficha.',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).extension<AppThemeTokens>()!.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: TerminalSpace.md),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: TerminalSpace.sm,
              runSpacing: TerminalSpace.sm,
              children: <Widget>[
                TerminalOutlineButton(
                  label: 'Cancelar',
                  icon: Icons.close,
                  color: Theme.of(
                    context,
                  ).extension<AppThemeTokens>()!.textSecondary,
                  onPressed: _saving ? null : _close,
                ),
                TerminalPrimaryButton(
                  key: const Key('contact-save'),
                  label: _saving ? 'Guardando' : 'Guardar personaje',
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

  Future<void> _save() async {
    setState(() => _saving = true);
    final Result<Contact> result = await ref
        .read(contactApplicationServiceProvider)
        .save(
          SaveContactRequest(
            existing: _existing,
            displayName: _name.text,
            role: _role.text,
            description: _description.text,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold<void>(
      onSuccess: (Contact contact) {
        if (_isEditing) {
          _close();
        } else {
          context.pushReplacementNamed(
            'contactDetail',
            pathParameters: <String, String>{'contactId': contact.id},
          );
        }
      },
      onFailure: (AppFailure failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  void _close() => context.canPop()
      ? context.pop()
      : context.goNamed(
          'character',
          queryParameters: const <String, String>{'tab': 'diario'},
        );
}
