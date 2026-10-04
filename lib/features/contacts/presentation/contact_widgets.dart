import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../photos/domain/entity_photo.dart';
import '../../photos/presentation/entity_photo_avatar.dart';
import '../application/contact_providers.dart';
import '../domain/models/contact.dart';

/// Nombre visible: los personajes pueden no tener nombre (ADR-006 D3).
String contactName(Contact contact) =>
    contact.displayName ?? 'Personaje sin nombre';

/// Fila de miniaturas con nombre, como en la ficha de una entrada. Tocar una
/// abre la ficha del personaje.
class ContactThumbnailRow extends StatelessWidget {
  const ContactThumbnailRow({
    required this.contacts,
    super.key,
    this.size = 56,
  });

  final List<Contact> contacts;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Wrap(
      spacing: TerminalSpace.sm,
      runSpacing: TerminalSpace.sm,
      children: <Widget>[
        for (final Contact contact in contacts)
          Semantics(
            button: true,
            label: 'Abrir ficha de ${contactName(contact)}',
            child: InkWell(
              key: ValueKey<String>('contact-thumb-${contact.id}'),
              onTap: () => context.pushNamed(
                'contactDetail',
                pathParameters: <String, String>{'contactId': contact.id},
              ),
              child: SizedBox(
                width: size + 16,
                child: Column(
                  children: <Widget>[
                    EntityPhotoAvatar(
                      owner: EntityPhotoOwner.contact,
                      ownerId: contact.id,
                      fallbackLabel: contact.displayName ?? '',
                      width: size,
                      height: size,
                      dimmed: contact.isArchived,
                    ),
                    const SizedBox(height: TerminalSpace.xxs),
                    Text(
                      contactName(contact),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tokens.infoCyan, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Miniaturas pequeñas superpuestas para tarjetas de lista. Muestra hasta
/// [max] y un «+N» con el resto.
class ContactAvatarStrip extends StatelessWidget {
  const ContactAvatarStrip({
    required this.contacts,
    super.key,
    this.size = 28,
    this.max = 4,
  });

  final List<Contact> contacts;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return const SizedBox.shrink();
    }
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final List<Contact> shown = contacts.take(max).toList(growable: false);
    final int rest = contacts.length - shown.length;
    return Semantics(
      label: 'Personajes: ${contacts.map(contactName).join(', ')}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final Contact contact in shown)
              Padding(
                padding: const EdgeInsets.only(right: TerminalSpace.xxs),
                child: EntityPhotoAvatar(
                  owner: EntityPhotoOwner.contact,
                  ownerId: contact.id,
                  fallbackLabel: contact.displayName ?? '',
                  width: size,
                  height: size,
                  dimmed: contact.isArchived,
                ),
              ),
            if (rest > 0)
              Text(
                '+$rest',
                style: TextStyle(
                  color: tokens.infoCyan,
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Campo de formulario para elegir personajes: muestra los elegidos y abre un
/// diálogo con los activos. Los ya vinculados que luego se archivaron siguen
/// apareciendo y se pueden quitar.
class ContactPickerField extends ConsumerWidget {
  const ContactPickerField({
    required this.selectedIds,
    required this.onChanged,
    super.key,
    this.enabled = true,
    this.knownContacts = const <Contact>[],
    this.helper,
  });

  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;

  /// Personajes ya vinculados (pueden estar archivados y no salir en la
  /// lista de activos).
  final List<Contact> knownContacts;
  final String? helper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final List<Contact> active =
        ref.watch(activeContactsProvider).value ?? const <Contact>[];
    final Map<String, Contact> byId = <String, Contact>{
      for (final Contact contact in knownContacts) contact.id: contact,
      for (final Contact contact in active) contact.id: contact,
    };
    final List<Contact> selected = <Contact>[
      for (final String id in selectedIds)
        if (byId[id] != null) byId[id]!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.groups_outlined, color: tokens.infoCyan),
            const SizedBox(width: TerminalSpace.xs),
            Expanded(
              child: Text(
                'PERSONAJES',
                style: TextStyle(
                  color: tokens.infoCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            TextButton.icon(
              key: const Key('contact-picker-open'),
              onPressed: enabled
                  ? () => _openPicker(context, active, byId)
                  : null,
              icon: const Icon(Icons.person_add_alt_outlined),
              label: Text(selected.isEmpty ? 'Elegir' : 'Cambiar'),
            ),
          ],
        ),
        if (helper != null)
          Text(
            helper!,
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
        const SizedBox(height: TerminalSpace.xs),
        if (selected.isEmpty)
          Text('Sin personajes.', style: TextStyle(color: tokens.textSecondary))
        else
          Wrap(
            spacing: TerminalSpace.xs,
            runSpacing: TerminalSpace.xs,
            children: <Widget>[
              for (final Contact contact in selected)
                InputChip(
                  key: ValueKey<String>('contact-chip-${contact.id}'),
                  avatar: EntityPhotoAvatar(
                    owner: EntityPhotoOwner.contact,
                    ownerId: contact.id,
                    fallbackLabel: contact.displayName ?? '',
                    width: 24,
                    height: 24,
                    dimmed: contact.isArchived,
                  ),
                  label: Text(contactName(contact)),
                  onDeleted: enabled
                      ? () => onChanged(
                          <String>{...selectedIds}..remove(contact.id),
                        )
                      : null,
                  deleteButtonTooltipMessage: 'Quitar',
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _openPicker(
    BuildContext context,
    List<Contact> active,
    Map<String, Contact> byId,
  ) async {
    final Set<String>? result = await showDialog<Set<String>>(
      context: context,
      builder: (BuildContext dialogContext) => _ContactPickerDialog(
        active: active,
        initial: selectedIds,
        archivedSelected: <Contact>[
          for (final String id in selectedIds)
            if (byId[id]?.isArchived == true) byId[id]!,
        ],
      ),
    );
    if (result != null) {
      onChanged(result);
    }
  }
}

class _ContactPickerDialog extends StatefulWidget {
  const _ContactPickerDialog({
    required this.active,
    required this.initial,
    required this.archivedSelected,
  });

  final List<Contact> active;
  final Set<String> initial;
  final List<Contact> archivedSelected;

  @override
  State<_ContactPickerDialog> createState() => _ContactPickerDialogState();
}

class _ContactPickerDialogState extends State<_ContactPickerDialog> {
  late final Set<String> _selected = <String>{...widget.initial};

  @override
  Widget build(BuildContext context) {
    final List<Contact> options = <Contact>[
      ...widget.active,
      ...widget.archivedSelected,
    ];
    return AlertDialog(
      title: const Text('Elegir personajes'),
      content: SizedBox(
        width: 420,
        child: options.isEmpty
            ? const Text(
                'Aún no tienes personajes. Créalos en Personaje → Diario → '
                'Personajes.',
              )
            : ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final Contact contact in options)
                    CheckboxListTile(
                      key: ValueKey<String>('contact-option-${contact.id}'),
                      value: _selected.contains(contact.id),
                      secondary: EntityPhotoAvatar(
                        owner: EntityPhotoOwner.contact,
                        ownerId: contact.id,
                        fallbackLabel: contact.displayName ?? '',
                        width: 40,
                        height: 40,
                        dimmed: contact.isArchived,
                      ),
                      title: Text(contactName(contact)),
                      subtitle: contact.isArchived
                          ? const Text('Archivado')
                          : (contact.role == null ? null : Text(contact.role!)),
                      onChanged: (bool? value) => setState(() {
                        if (value == true) {
                          _selected.add(contact.id);
                        } else {
                          _selected.remove(contact.id);
                        }
                      }),
                    ),
                ],
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('contact-picker-accept'),
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

/// Tarjeta de personaje en la cuadrícula del Diario.
class ContactCard extends StatelessWidget {
  const ContactCard({required this.contact, super.key});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalCard(
      key: ValueKey<String>('contact-card-${contact.id}'),
      padding: const EdgeInsets.all(TerminalSpace.sm),
      onTap: () => context.pushNamed(
        'contactDetail',
        pathParameters: <String, String>{'contactId': contact.id},
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          EntityPhotoAvatar(
            owner: EntityPhotoOwner.contact,
            ownerId: contact.id,
            fallbackLabel: contact.displayName ?? '',
            dimmed: contact.isArchived,
          ),
          const SizedBox(width: TerminalSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  contactName(contact).toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: contact.displayName == null
                        ? tokens.textSecondary
                        : tokens.infoCyan,
                    letterSpacing: 0.6,
                  ),
                ),
                if (contact.role != null) ...<Widget>[
                  const SizedBox(height: TerminalSpace.xxs),
                  Text(
                    contact.role!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                  ),
                ],
                if (contact.isArchived) ...<Widget>[
                  const SizedBox(height: TerminalSpace.xxs),
                  TerminalBadge(
                    label: 'Archivado',
                    color: tokens.textSecondary,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
