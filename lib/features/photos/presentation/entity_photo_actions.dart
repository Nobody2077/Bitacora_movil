import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_preferences_provider.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../application/entity_photo_providers.dart';
import '../domain/entity_photo.dart';

/// Elige una foto (cámara solo si Privacidad lo permite), la cifra y la deja
/// como la vigente. Avisa del resultado; cancelar no muestra nada.
Future<void> pickEntityPhoto(
  BuildContext context,
  WidgetRef ref, {
  required EntityPhotoOwner owner,
  required String ownerId,
}) async {
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
    if (fromCamera == null || !context.mounted) return;
    useCamera = fromCamera;
  }
  final Result<EntityPhoto?> result = await ref
      .read(entityPhotoApplicationServiceProvider)
      .pickAndSet(owner, ownerId, useCamera: useCamera);
  if (!context.mounted) return;
  final String? message = result.fold(
    onSuccess: (EntityPhoto? photo) =>
        photo == null ? null : 'Foto cifrada y guardada.',
    onFailure: (AppFailure failure) => failure.message,
  );
  if (message != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Pide confirmación y quita la foto vigente con su archivo cifrado.
Future<void> removeEntityPhoto(
  BuildContext context,
  WidgetRef ref, {
  required EntityPhotoOwner owner,
  required String ownerId,
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('Quitar foto'),
      content: const Text('Se borrará el archivo cifrado de esta foto.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('photo-remove-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Quitar'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final Result<void> result = await ref
      .read(entityPhotoApplicationServiceProvider)
      .remove(owner, ownerId);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        result.fold(
          onSuccess: (_) => 'Foto quitada.',
          onFailure: (AppFailure failure) => failure.message,
        ),
      ),
    ),
  );
}
