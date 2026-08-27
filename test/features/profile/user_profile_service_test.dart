import 'dart:io';

import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/profile/application/user_profile_service.dart';
import 'package:bitacora_rpg_personal/features/profile/domain/models/user_profile.dart';
import 'package:bitacora_rpg_personal/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('normaliza espacios antes de guardar el nombre', () async {
    final _MemoryProfileRepository repository = _MemoryProfileRepository();
    final UserProfileService service = UserProfileService(
      repository: repository,
      imagePicker: ImagePicker(),
      directoryLocator: () async => Directory.systemTemp,
    );

    final Result<UserProfile> result = await service.saveDisplayName(
      const UserProfile.localDefault(),
      '  Ada    Lovelace  ',
    );

    expect(result, isA<Success<UserProfile>>());
    expect(repository.saved?.displayName, 'Ada Lovelace');
  });

  test('rechaza un nombre vacío antes de consultar persistencia', () async {
    final _MemoryProfileRepository repository = _MemoryProfileRepository();
    final UserProfileService service = UserProfileService(
      repository: repository,
      imagePicker: ImagePicker(),
      directoryLocator: () async => Directory.systemTemp,
    );

    final Result<UserProfile> result = await service.saveDisplayName(
      const UserProfile.localDefault(),
      '   ',
    );

    expect(result, isA<Failure<UserProfile>>());
    expect(repository.saved, isNull);
  });
}

final class _MemoryProfileRepository implements UserProfileRepository {
  UserProfile? saved;

  @override
  Future<Result<UserProfile>> load() async =>
      const Success<UserProfile>(UserProfile.localDefault());

  @override
  Future<Result<void>> save(UserProfile profile) async {
    saved = profile;
    return const Success<void>(null);
  }
}
