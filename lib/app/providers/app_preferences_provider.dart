import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/access/application/access_session_controller.dart';
import '../../features/access/application/access_session_state.dart';
import '../../features/settings/domain/models/app_preferences.dart';
import '../theme/access_accent_preference_store.dart';
import '../theme/immersive_mode_preference_store.dart';
import 'persistence_providers.dart';

final Provider<AccessAccentPreferenceStore>
accessAccentPreferenceStoreProvider = Provider<AccessAccentPreferenceStore>(
  (Ref ref) => FileAccessAccentPreferenceStore(
    directoryLocator: getApplicationSupportDirectory,
  ),
);

final FutureProvider<AppAccentColor> accessAccentProvider =
    FutureProvider<AppAccentColor>(
      (Ref ref) => ref.watch(accessAccentPreferenceStoreProvider).read(),
    );

final Provider<ImmersiveModePreferenceStore>
immersiveModePreferenceStoreProvider = Provider<ImmersiveModePreferenceStore>(
  (Ref ref) => FileImmersiveModePreferenceStore(
    directoryLocator: getApplicationSupportDirectory,
  ),
);

final FutureProvider<bool> immersiveModeProvider = FutureProvider<bool>(
  (Ref ref) => ref.watch(immersiveModePreferenceStoreProvider).read(),
);

final StreamProvider<AppPreferences> appPreferencesProvider =
    StreamProvider<AppPreferences>((Ref ref) {
      final bool canReadProtected = ref.watch(
        accessSessionProvider.select(
          (AccessSessionState session) => session.canBuildProtected,
        ),
      );
      if (!canReadProtected) {
        return Stream<AppPreferences>.value(AppPreferences.defaults);
      }
      return ref
          .watch(settingsRepositoryProvider)
          .watch()
          .map(
            (result) => result.fold(
              onSuccess: (AppPreferences value) => value,
              onFailure: (failure) => throw failure,
            ),
          );
    });
