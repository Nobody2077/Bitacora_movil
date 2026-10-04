import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/app_preferences_provider.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../journal/application/journal_providers.dart';
import '../../journal/domain/models/journal_entry.dart';
import '../../journal/presentation/journal_presentation_support.dart';
import '../../missions/application/mission_providers.dart';
import '../../missions/domain/models/mission.dart';
import '../../photos/application/entity_photo_providers.dart';
import '../../photos/domain/entity_photo.dart';
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

/// Ficha de un personaje: foto, datos, misiones y entradas donde aparece.
class ContactDetailPage extends ConsumerStatefulWidget {
  const ContactDetailPage({required this.contactId, super.key});

  final String contactId;

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
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
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
    final Widget photo = EntityPhotoAvatar(
      owner: EntityPhotoOwner.contact,
      ownerId: contact.id,
      fallbackLabel: contact.displayName ?? '',
      width: 240,
      height: 320,
      dimmed: contact.isArchived,
    );
    final Widget data = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TerminalPageHeader(
          title: contactName(contact),
          subtitle: contact.role ?? 'Personaje del Diario',
        ),
        if (contact.isArchived) ...<Widget>[
          const SizedBox(height: TerminalSpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TerminalBadge(
              label: 'Archivado',
              color: tokens.attentionOrange,
              icon: Icons.inventory_2_outlined,
            ),
          ),
        ],
        const SizedBox(height: TerminalSpace.md),
        if (contact.description != null)
          Text(
            contact.description!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          )
        else
          Text(
            'Sin descripción.',
            style: TextStyle(color: tokens.textSecondary),
          ),
        const SizedBox(height: TerminalSpace.md),
        Wrap(
          spacing: TerminalSpace.sm,
          runSpacing: TerminalSpace.sm,
          children: <Widget>[
            if (!contact.isArchived) ...<Widget>[
              TerminalPrimaryButton(
                key: const Key('contact-edit'),
                label: 'Editar',
                icon: Icons.edit_outlined,
                onPressed: _working
                    ? null
                    : () => context.pushNamed(
                        'contactEdit',
                        pathParameters: <String, String>{
                          'contactId': contact.id,
                        },
                      ),
              ),
              TerminalOutlineButton(
                key: const Key('contact-photo'),
                label: hasPhoto ? 'Cambiar foto' : 'Añadir foto',
                icon: Icons.add_a_photo_outlined,
                onPressed: _working ? null : () => _pickPhoto(contact),
              ),
              if (hasPhoto)
                TerminalOutlineButton(
                  key: const Key('contact-photo-remove'),
                  label: 'Quitar foto',
                  icon: Icons.hide_image_outlined,
                  color: tokens.textSecondary,
                  onPressed: _working ? null : () => _removePhoto(contact),
                ),
              TerminalOutlineButton(
                key: const Key('contact-archive'),
                label: 'Eliminar',
                icon: Icons.inventory_2_outlined,
                color: tokens.attentionOrange,
                onPressed: _working ? null : () => _archive(contact),
              ),
            ] else
              TerminalPrimaryButton(
                key: const Key('contact-restore'),
                label: 'Restaurar',
                icon: Icons.unarchive_outlined,
                onPressed: _working ? null : () => _restore(contact),
              ),
          ],
        ),
      ],
    );

    return JournalPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                constraints.maxWidth < 640
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Center(child: photo),
                      const SizedBox(height: TerminalSpace.md),
                      data,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      photo,
                      const SizedBox(width: TerminalSpace.lg),
                      Expanded(child: data),
                    ],
                  ),
          ),
          const SizedBox(height: TerminalSpace.lg),
          _LinkedMissions(contactId: contact.id),
          const SizedBox(height: TerminalSpace.md),
          _LinkedEntries(contactId: contact.id),
        ],
      ),
    );
  }

  Future<void> _pickPhoto(Contact contact) async {
    bool useCamera = false;
    final bool allowCamera =
        ref.read(appPreferencesProvider).value?.allowCameraAttachments ?? false;
    if (allowCamera) {
      final bool? fromCamera = await showModalBottomSheet<bool>(
        context: context,
        builder: (BuildContext sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Sacar foto'),
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de la galería'),
                onTap: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ),
      );
      if (fromCamera == null || !mounted) return;
      useCamera = fromCamera;
    }
    await _run(
      () => ref
          .read(entityPhotoApplicationServiceProvider)
          .pickAndSet(
            EntityPhotoOwner.contact,
            contact.id,
            useCamera: useCamera,
          ),
      success: 'Foto cifrada y guardada.',
      cancelled: (EntityPhoto? photo) => photo == null,
    );
  }

  Future<void> _removePhoto(Contact contact) async {
    final bool confirmed = await _confirm(
      title: 'Quitar foto',
      message: 'Se borrará el archivo cifrado de la foto de este personaje.',
      action: 'Quitar',
    );
    if (!confirmed) return;
    await _run(
      () => ref
          .read(entityPhotoApplicationServiceProvider)
          .remove(EntityPhotoOwner.contact, contact.id),
      success: 'Foto quitada.',
    );
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
    bool Function(T value)? cancelled,
  }) async {
    setState(() => _working = true);
    final Result<T> result = await action();
    if (!mounted) return;
    setState(() => _working = false);
    final String message = result.fold(
      onSuccess: (T value) =>
          cancelled != null && cancelled(value) ? '' : success,
      onFailure: (AppFailure failure) => failure.message,
    );
    if (message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
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

class _LinkedMissions extends ConsumerWidget {
  const _LinkedMissions({required this.contactId});

  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<String>> ids = ref.watch(
      contactMissionIdsProvider(contactId),
    );
    return _LinkedSection(
      title: 'Misiones',
      emptyMessage: 'Todavía no aparece en ninguna misión.',
      ids: ids,
      itemBuilder: (String id) => _MissionLink(missionId: id),
    );
  }
}

class _LinkedEntries extends ConsumerWidget {
  const _LinkedEntries({required this.contactId});

  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<String>> ids = ref.watch(
      contactJournalEntryIdsProvider(contactId),
    );
    return _LinkedSection(
      title: 'Entradas del Diario',
      emptyMessage: 'Todavía no aparece en ninguna entrada.',
      ids: ids,
      itemBuilder: (String id) => _EntryLink(entryId: id),
    );
  }
}

class _LinkedSection extends StatelessWidget {
  const _LinkedSection({
    required this.title,
    required this.emptyMessage,
    required this.ids,
    required this.itemBuilder,
  });

  final String title;
  final String emptyMessage;
  final AsyncValue<List<String>> ids;
  final Widget Function(String id) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TerminalSectionTitle(
            title: title,
            overline: ids.value == null ? null : '${ids.value!.length}',
          ),
          const SizedBox(height: TerminalSpace.sm),
          ids.when(
            data: (List<String> values) => values.isEmpty
                ? Text(
                    emptyMessage,
                    style: TextStyle(color: tokens.textSecondary),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final String id in values) itemBuilder(id),
                    ],
                  ),
            loading: () =>
                const TerminalInlineLoadingState(message: 'Cargando…'),
            error: (_, _) => const TerminalInlineErrorState(
              message: 'No se pudo leer esta lista.',
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionLink extends ConsumerWidget {
  const _MissionLink({required this.missionId});

  final String missionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Mission? mission = ref.watch(missionDetailProvider(missionId)).value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.flag_outlined),
      title: Text(mission?.title ?? '…'),
      subtitle: mission?.location == null ? null : Text(mission!.location!),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.pushNamed(
        'missionDetail',
        pathParameters: <String, String>{'missionId': missionId},
      ),
    );
  }
}

class _EntryLink extends ConsumerWidget {
  const _EntryLink({required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JournalEntry? entry = ref
        .watch(journalEntryDetailProvider(entryId))
        .value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(entry?.title ?? '…'),
      subtitle: entry == null
          ? null
          : Text(journalDayLabel(entry.occurredAtUtc.toLocal())),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.pushNamed(
        'journalDetail',
        pathParameters: <String, String>{'entryId': entryId},
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
