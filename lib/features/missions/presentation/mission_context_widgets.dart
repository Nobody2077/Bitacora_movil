import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../contacts/application/contact_providers.dart';
import '../../contacts/domain/models/contact.dart';
import '../../contacts/presentation/contact_widgets.dart';
import '../../photos/application/entity_photo_providers.dart';
import '../../photos/domain/entity_photo.dart';
import '../../photos/presentation/entity_photo_actions.dart';
import '../../photos/presentation/entity_photo_avatar.dart';
import '../domain/models/mission.dart';

/// Panel del detalle de misión: foto (con cambiar y quitar), ubicación y
/// personajes con su ficha a un toque.
class MissionContextPanel extends ConsumerWidget {
  const MissionContextPanel({required this.mission, super.key});

  final Mission mission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final bool hasPhoto =
        ref
            .watch(
              entityPhotoProvider((
                owner: EntityPhotoOwner.mission,
                ownerId: mission.id,
              )),
            )
            .value !=
        null;
    final List<Contact> contacts =
        ref
            .watch(missionsContactsProvider(IdSet(<String>[mission.id])))
            .value?[mission.id] ??
        const <Contact>[];
    final bool editable = mission.archivedAtUtc == null;

    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.place_outlined, color: tokens.valueYellow, size: 20),
            const SizedBox(width: TerminalSpace.xs),
            Expanded(
              child: Text(
                mission.location ?? 'Sin ubicación',
                key: const Key('mission-detail-location'),
                style: TextStyle(
                  color: mission.location == null
                      ? tokens.textSecondary
                      : tokens.valueYellow,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: TerminalSpace.md),
        if (contacts.isEmpty)
          Text(
            'Sin personajes. Puedes elegirlos al editar la misión.',
            style: TextStyle(color: tokens.textSecondary),
          )
        else
          ContactThumbnailRow(contacts: contacts),
        if (editable) ...<Widget>[
          const SizedBox(height: TerminalSpace.md),
          Wrap(
            spacing: TerminalSpace.sm,
            runSpacing: TerminalSpace.sm,
            children: <Widget>[
              TerminalOutlineButton(
                key: const Key('mission-photo'),
                label: hasPhoto ? 'Cambiar foto' : 'Añadir foto',
                icon: Icons.add_a_photo_outlined,
                color: tokens.infoCyan,
                onPressed: () => pickEntityPhoto(
                  context,
                  ref,
                  owner: EntityPhotoOwner.mission,
                  ownerId: mission.id,
                ),
              ),
              if (hasPhoto)
                TerminalOutlineButton(
                  key: const Key('mission-photo-remove'),
                  label: 'Quitar foto',
                  icon: Icons.hide_image_outlined,
                  color: tokens.textSecondary,
                  onPressed: () => removeEntityPhoto(
                    context,
                    ref,
                    owner: EntityPhotoOwner.mission,
                    ownerId: mission.id,
                  ),
                ),
            ],
          ),
        ],
      ],
    );

    return TerminalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const TerminalSectionTitle(
            overline: 'Contexto',
            title: 'Lugar, foto y personajes',
          ),
          const SizedBox(height: TerminalSpace.sm),
          if (!hasPhoto)
            details
          else
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Widget photo = EntityPhotoAvatar(
                  owner: EntityPhotoOwner.mission,
                  ownerId: mission.id,
                  fallbackLabel: mission.title,
                  width: 200,
                  height: 150,
                );
                return constraints.maxWidth < 560
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          photo,
                          const SizedBox(height: TerminalSpace.md),
                          details,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          photo,
                          const SizedBox(width: TerminalSpace.md),
                          Expanded(child: details),
                        ],
                      );
              },
            ),
        ],
      ),
    );
  }
}

/// Foto, ubicación y miniaturas de personajes de una misión (ADR-006 D15),
/// para el pie de sus tarjetas. No ocupa espacio si la misión no tiene nada.
class MissionContextStrip extends ConsumerWidget {
  const MissionContextStrip({required this.mission, super.key});

  final Mission mission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final bool hasPhoto =
        ref
            .watch(
              entityPhotoProvider((
                owner: EntityPhotoOwner.mission,
                ownerId: mission.id,
              )),
            )
            .value !=
        null;
    final List<Contact> contacts =
        ref
            .watch(missionsContactsProvider(IdSet(<String>[mission.id])))
            .value?[mission.id] ??
        const <Contact>[];
    final String? location = mission.location;
    if (!hasPhoto && contacts.isEmpty && location == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: ValueKey<String>('mission-context-${mission.id}'),
      padding: const EdgeInsets.only(top: TerminalSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (hasPhoto) ...<Widget>[
            EntityPhotoAvatar(
              owner: EntityPhotoOwner.mission,
              ownerId: mission.id,
              fallbackLabel: mission.title,
              width: 72,
              height: 72,
            ),
            const SizedBox(width: TerminalSpace.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (location != null)
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: tokens.valueYellow,
                      ),
                      const SizedBox(width: TerminalSpace.xxs),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: tokens.valueYellow),
                        ),
                      ),
                    ],
                  ),
                if (location != null && contacts.isNotEmpty)
                  const SizedBox(height: TerminalSpace.xs),
                if (contacts.isNotEmpty) ContactAvatarStrip(contacts: contacts),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
