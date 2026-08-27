import 'dart:convert';

import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/daos/settings_dao.dart';
import '../domain/models/user_profile.dart';
import '../domain/repositories/user_profile_repository.dart';

final class DriftUserProfileRepository implements UserProfileRepository {
  const DriftUserProfileRepository(this._dao);

  static const String metadataKey = 'user_profile_v1';

  final SettingsDao _dao;

  @override
  Future<Result<UserProfile>> load() async {
    try {
      return _decode(await _dao.getMetadata(metadataKey));
    } on Object catch (error) {
      return Failure<UserProfile>(
        StorageFailure('No se pudo leer el perfil local.', cause: error),
      );
    }
  }

  @override
  Future<Result<void>> save(UserProfile profile) async {
    final String name = profile.displayName.trim();
    if (name.isEmpty || name.length > 60) {
      return const Failure<void>(
        ValidationFailure('El nombre debe tener entre 1 y 60 caracteres.'),
      );
    }

    try {
      await _dao.putMetadata(
        key: metadataKey,
        value: jsonEncode(<String, Object?>{
          'displayName': name,
          'avatarPath': profile.avatarPath,
        }),
        updatedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      return const Success<void>(null);
    } on Object catch (error) {
      return Failure<void>(
        StorageFailure('No se pudo guardar el perfil local.', cause: error),
      );
    }
  }

  Result<UserProfile> _decode(String? encoded) {
    if (encoded == null) {
      return const Success<UserProfile>(UserProfile.localDefault());
    }

    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Profile payload is not an object.');
      }
      final Object? rawName = decoded['displayName'];
      final Object? rawAvatarPath = decoded['avatarPath'];
      if (rawName is! String ||
          rawName.trim().isEmpty ||
          rawName.trim().length > 60 ||
          rawAvatarPath != null && rawAvatarPath is! String) {
        throw const FormatException('Profile payload is invalid.');
      }
      return Success<UserProfile>(
        UserProfile(
          displayName: rawName.trim(),
          avatarPath: rawAvatarPath as String?,
        ),
      );
    } on Object catch (error) {
      return Failure<UserProfile>(
        StorageFailure('El perfil local guardado no es válido.', cause: error),
      );
    }
  }
}
