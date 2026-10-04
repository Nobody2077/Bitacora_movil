import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../application/entity_photo_providers.dart';
import '../domain/entity_photo.dart';

/// Foto vigente de un personaje o una misión, descifrada en memoria. Sin foto
/// (o mientras carga, o si falla) muestra la inicial sobre el degradado de la
/// maqueta, para que la cuadrícula no salte.
class EntityPhotoAvatar extends ConsumerWidget {
  const EntityPhotoAvatar({
    required this.owner,
    required this.ownerId,
    required this.fallbackLabel,
    super.key,
    this.width = 64,
    this.height = 64,
    this.dimmed = false,
  });

  final EntityPhotoOwner owner;
  final String ownerId;

  /// Texto del que sale la inicial; vacío muestra un icono de persona.
  final String fallbackLabel;
  final double width;
  final double height;

  /// Personajes archivados: se ven apagados.
  final bool dimmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final EntityPhoto? photo = ref
        .watch(entityPhotoProvider((owner: owner, ownerId: ownerId)))
        .value;
    final Uint8List? bytes = photo == null
        ? null
        : ref.watch(entityPhotoBytesProvider(photo)).value;

    final Widget content = bytes != null
        ? Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            semanticLabel: 'Foto de $fallbackLabel',
          )
        : _Fallback(
            label: fallbackLabel,
            width: width,
            height: height,
            color: tokens.infoCyan,
          );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(border: Border.all(color: tokens.border)),
      child: Opacity(opacity: dimmed ? 0.45 : 1, child: content),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({
    required this.label,
    required this.width,
    required this.height,
    required this.color,
  });

  final String label;
  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final String trimmed = label.trim();
    final double size = (width < height ? width : height) * 0.42;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF16303A), Color(0xFF0B0F14)],
        ),
      ),
      child: Center(
        child: trimmed.isEmpty
            ? Icon(Icons.person_outline, color: color, size: size)
            : Text(
                trimmed.characters.first.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: size,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
      ),
    );
  }
}
