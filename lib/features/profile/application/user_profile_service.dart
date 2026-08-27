import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../domain/models/user_profile.dart';
import '../domain/repositories/user_profile_repository.dart';

typedef ProfileDirectoryLocator = Future<Directory> Function();

final class UserProfileService {
  const UserProfileService({
    required UserProfileRepository repository,
    required ImagePicker imagePicker,
    required ProfileDirectoryLocator directoryLocator,
  }) : _repository = repository,
       _imagePicker = imagePicker,
       _directoryLocator = directoryLocator;

  final UserProfileRepository _repository;
  final ImagePicker _imagePicker;
  final ProfileDirectoryLocator _directoryLocator;

  Future<Result<UserProfile>> saveDisplayName(
    UserProfile current,
    String displayName,
  ) async {
    final String normalized = displayName.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (normalized.isEmpty || normalized.length > 60) {
      return const Failure<UserProfile>(
        ValidationFailure('El nombre debe tener entre 1 y 60 caracteres.'),
      );
    }
    final UserProfile updated = current.copyWith(displayName: normalized);
    return _saveAndReturn(updated);
  }

  Future<Result<UserProfile?>> pickAvatar(UserProfile current) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 768,
        maxHeight: 768,
        imageQuality: 88,
      );
      if (picked == null) {
        return const Success<UserProfile?>(null);
      }

      final Directory profileDirectory = await _profileDirectory();
      final String extension = _safeExtension(p.extension(picked.path));
      final String destinationPath = p.join(
        profileDirectory.path,
        'avatar_${DateTime.now().microsecondsSinceEpoch}$extension',
      );
      await picked.saveTo(destinationPath);

      final UserProfile updated = UserProfile(
        displayName: current.displayName,
        avatarPath: destinationPath,
      );
      final Result<void> saved = await _repository.save(updated);
      return saved.fold(
        onSuccess: (_) {
          _deleteManagedAvatarBestEffort(current.avatarPath, profileDirectory);
          return Success<UserProfile?>(updated);
        },
        onFailure: (AppFailure failure) {
          _deleteFileBestEffort(destinationPath);
          return Failure<UserProfile?>(failure);
        },
      );
    } on Object catch (error) {
      return Failure<UserProfile?>(
        UnexpectedFailure(
          'No se pudo seleccionar la foto del perfil.',
          cause: error,
        ),
      );
    }
  }

  Future<Result<UserProfile>> removeAvatar(UserProfile current) async {
    try {
      final Directory profileDirectory = await _profileDirectory();
      final UserProfile updated = current.withoutAvatar();
      final Result<void> saved = await _repository.save(updated);
      return saved.fold(
        onSuccess: (_) {
          _deleteManagedAvatarBestEffort(current.avatarPath, profileDirectory);
          return Success<UserProfile>(updated);
        },
        onFailure: Failure<UserProfile>.new,
      );
    } on Object catch (error) {
      return Failure<UserProfile>(
        StorageFailure('No se pudo quitar la foto del perfil.', cause: error),
      );
    }
  }

  Future<Result<UserProfile>> _saveAndReturn(UserProfile profile) async {
    final Result<void> result = await _repository.save(profile);
    return result.fold(
      onSuccess: (_) => Success<UserProfile>(profile),
      onFailure: Failure<UserProfile>.new,
    );
  }

  Future<Directory> _profileDirectory() async {
    final Directory supportDirectory = await _directoryLocator();
    final Directory profileDirectory = Directory(
      p.join(supportDirectory.path, 'profile'),
    );
    await profileDirectory.create(recursive: true);
    return profileDirectory;
  }

  static String _safeExtension(String extension) {
    final String normalized = extension.toLowerCase();
    return const <String>{'.jpg', '.jpeg', '.png', '.webp'}.contains(normalized)
        ? normalized
        : '.img';
  }

  static void _deleteManagedAvatarBestEffort(
    String? avatarPath,
    Directory profileDirectory,
  ) {
    if (avatarPath == null) {
      return;
    }
    final String normalizedDirectory = p.normalize(
      p.absolute(profileDirectory.path),
    );
    final String normalizedAvatar = p.normalize(p.absolute(avatarPath));
    if (p.isWithin(normalizedDirectory, normalizedAvatar)) {
      _deleteFileBestEffort(normalizedAvatar);
    }
  }

  static void _deleteFileBestEffort(String filePath) {
    try {
      final File file = File(filePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } on Object {
      // La persistencia del perfil ya terminó; la limpieza es best-effort.
    }
  }
}
