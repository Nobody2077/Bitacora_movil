import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/providers/persistence_providers.dart';
import '../../../core/result/result.dart';
import '../data/drift_user_profile_repository.dart';
import '../domain/models/user_profile.dart';
import '../domain/repositories/user_profile_repository.dart';
import 'user_profile_service.dart';

final Provider<UserProfileRepository> userProfileRepositoryProvider =
    Provider<UserProfileRepository>(
      (Ref ref) => DriftUserProfileRepository(ref.watch(settingsDaoProvider)),
    );

final FutureProvider<UserProfile> userProfileProvider =
    FutureProvider<UserProfile>((Ref ref) async {
      final Result<UserProfile> result = await ref
          .watch(userProfileRepositoryProvider)
          .load();
      return result.fold(
        onSuccess: (UserProfile profile) => profile,
        onFailure: (failure) => throw failure,
      );
    });

final Provider<ImagePicker> profileImagePickerProvider = Provider<ImagePicker>(
  (Ref ref) => ImagePicker(),
);

final Provider<ProfileDirectoryLocator> profileDirectoryLocatorProvider =
    Provider<ProfileDirectoryLocator>(
      (Ref ref) =>
          () async => Directory((await getApplicationSupportDirectory()).path),
    );

final Provider<UserProfileService> userProfileServiceProvider =
    Provider<UserProfileService>(
      (Ref ref) => UserProfileService(
        repository: ref.watch(userProfileRepositoryProvider),
        imagePicker: ref.watch(profileImagePickerProvider),
        directoryLocator: ref.watch(profileDirectoryLocatorProvider),
      ),
    );
