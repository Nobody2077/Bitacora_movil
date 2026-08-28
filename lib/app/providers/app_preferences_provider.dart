import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/access/application/access_session_controller.dart';
import '../../features/access/application/access_session_state.dart';
import '../../features/settings/domain/models/app_preferences.dart';
import 'persistence_providers.dart';

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
