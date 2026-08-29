import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/persistence_providers.dart';
import '../domain/reminder_preferences.dart';

final StreamProvider<ReminderPreferences> reminderPreferencesProvider =
    StreamProvider<ReminderPreferences>((Ref ref) {
      return ref
          .watch(reminderPreferencesRepositoryProvider)
          .watch()
          .map(
            (result) => result.fold(
              onSuccess: (ReminderPreferences value) => value,
              onFailure: (failure) => throw failure,
            ),
          );
    });
