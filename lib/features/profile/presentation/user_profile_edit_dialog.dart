import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_preferences_provider.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../application/user_profile_providers.dart';
import '../domain/models/user_profile.dart';

class UserProfileEditDialog extends ConsumerStatefulWidget {
  const UserProfileEditDialog({required this.initialProfile, super.key});

  final UserProfile initialProfile;

  @override
  ConsumerState<UserProfileEditDialog> createState() =>
      _UserProfileEditDialogState();
}

class _UserProfileEditDialogState extends ConsumerState<UserProfileEditDialog> {
  late UserProfile _profile;
  late final TextEditingController _nameController;
  bool _savingName = false;
  bool _updatingAvatar = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _nameController = TextEditingController(text: _profile.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final String? avatarPath = _existingAvatarPath(_profile.avatarPath);
    final bool busy = _savingName || _updatingAvatar;

    return AlertDialog(
      scrollable: true,
      title: const Text('Tu perfil local'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              image: true,
              label: avatarPath == null
                  ? 'Perfil local sin fotografía'
                  : 'Fotografía del perfil local',
              child: ExcludeSemantics(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: tokens.terminalRed.withValues(alpha: 0.14),
                  foregroundImage: avatarPath == null
                      ? null
                      : FileImage(File(avatarPath)),
                  child: avatarPath == null
                      ? Icon(
                          Icons.person_outline,
                          color: tokens.terminalRed,
                          size: 48,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: busy ? null : _pickAvatar,
                  icon: _updatingAvatar
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(
                    _updatingAvatar ? 'Actualizando foto' : 'Elegir foto',
                  ),
                ),
                if (avatarPath != null)
                  TextButton.icon(
                    onPressed: busy ? null : _removeAvatar,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Quitar foto'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              enabled: !busy,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Tu nombre',
                hintText: 'Ejemplo: Alex',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              onSubmitted: (_) {
                if (!busy) {
                  _saveName();
                }
              },
            ),
            const SizedBox(height: 4),
            Text(
              'La foto queda guardada únicamente en el espacio privado de la app.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: busy ? null : _saveName,
          icon: _savingName
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_savingName ? 'Guardando nombre' : 'Guardar nombre'),
        ),
      ],
    );
  }

  Future<void> _pickAvatar() async {
    bool useCamera = false;
    final bool allowCamera =
        ref.read(appPreferencesProvider).value?.allowCameraAttachments ?? false;
    if (allowCamera) {
      final bool? selectedSource = await _pickPhotoSource();
      if (selectedSource == null || !mounted) return;
      useCamera = selectedSource;
    }
    setState(() => _updatingAvatar = true);
    final Result<UserProfile?> result = await ref
        .read(userProfileServiceProvider)
        .pickAvatar(_profile, useCamera: useCamera);
    if (!mounted) {
      return;
    }
    result.fold<void>(
      onSuccess: (UserProfile? profile) {
        if (profile != null) {
          setState(() => _profile = profile);
          ref.invalidate(userProfileProvider);
        }
      },
      onFailure: _showFailure,
    );
    if (mounted) {
      setState(() => _updatingAvatar = false);
    }
  }

  Future<bool?> _pickPhotoSource() => showModalBottomSheet<bool>(
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

  Future<void> _removeAvatar() async {
    setState(() => _updatingAvatar = true);
    final Result<UserProfile> result = await ref
        .read(userProfileServiceProvider)
        .removeAvatar(_profile);
    if (!mounted) {
      return;
    }
    result.fold<void>(
      onSuccess: (UserProfile profile) {
        setState(() => _profile = profile);
        ref.invalidate(userProfileProvider);
      },
      onFailure: _showFailure,
    );
    if (mounted) {
      setState(() => _updatingAvatar = false);
    }
  }

  Future<void> _saveName() async {
    setState(() => _savingName = true);
    final Result<UserProfile> result = await ref
        .read(userProfileServiceProvider)
        .saveDisplayName(_profile, _nameController.text);
    if (!mounted) {
      return;
    }
    result.fold<void>(
      onSuccess: (UserProfile profile) {
        _profile = profile;
        ref.invalidate(userProfileProvider);
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Perfil actualizado.')),
        );
      },
      onFailure: _showFailure,
    );
    if (mounted) {
      setState(() => _savingName = false);
    }
  }

  void _showFailure(AppFailure failure) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failure.message)));
  }

  static String? _existingAvatarPath(String? path) {
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    return File(path).existsSync() ? path : null;
  }
}
