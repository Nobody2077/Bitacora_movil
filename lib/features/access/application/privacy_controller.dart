import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/domain/models/app_preferences.dart';
import 'access_session_controller.dart';
import 'monotonic_clock.dart';

const Set<int> supportedAutoLockMinutes =
    AppPreferences.supportedAutoLockMinutes;

final Provider<MonotonicClock> monotonicClockProvider =
    Provider<MonotonicClock>((Ref ref) => StopwatchMonotonicClock());

final NotifierProvider<AutoLockPolicyController, int> autoLockMinutesProvider =
    NotifierProvider<AutoLockPolicyController, int>(
      AutoLockPolicyController.new,
    );

class AutoLockPolicyController extends Notifier<int> {
  @override
  int build() => 0;

  bool setMinutes(int minutes) {
    if (!supportedAutoLockMinutes.contains(minutes)) {
      return false;
    }
    state = minutes;
    return true;
  }

  /// Estado conservador mientras la preferencia cifrada aún no pudo leerse.
  ///
  /// El valor persistido nuevo sigue siendo cinco minutos; usar cero solo en
  /// memoria evita debilitar una preferencia previa de cero o un minuto si la
  /// app sale a segundo plano durante la carga o si esa lectura falla.
  void useSafeFallback() => state = 0;
}

@immutable
final class PrivacyShieldState {
  const PrivacyShieldState({required this.covered, required this.revision});

  const PrivacyShieldState.initial() : covered = true, revision = 0;

  final bool covered;
  final int revision;

  PrivacyShieldState copyWith({bool? covered}) => PrivacyShieldState(
    covered: covered ?? this.covered,
    revision: revision + 1,
  );
}

final NotifierProvider<PrivacyController, PrivacyShieldState>
privacyControllerProvider =
    NotifierProvider<PrivacyController, PrivacyShieldState>(
      PrivacyController.new,
    );

class PrivacyController extends Notifier<PrivacyShieldState> {
  late MonotonicClock _clock;
  Duration? _backgroundStartedAt;
  bool _foreground = false;

  @override
  PrivacyShieldState build() {
    _clock = ref.read(monotonicClockProvider);
    return const PrivacyShieldState.initial();
  }

  void coverForBackground() {
    _foreground = false;
    if (_backgroundStartedAt == null) {
      _backgroundStartedAt = _clock.now();
      ref.read(accessSessionProvider.notifier).handleBackgrounded();
      if (ref.read(autoLockMinutesProvider) == 0 &&
          ref.read(accessSessionProvider).canBuildProtected) {
        ref
            .read(accessSessionProvider.notifier)
            .lock(reason: AccessLockReason.timeout);
      }
    }
    if (!state.covered) {
      state = state.copyWith(covered: true);
    }
  }

  Future<void> resume() async {
    _foreground = true;
    final Duration? backgroundStartedAt = _backgroundStartedAt;
    _backgroundStartedAt = null;
    if (backgroundStartedAt == null ||
        !ref.read(accessSessionProvider).canBuildProtected) {
      return;
    }

    final int timeoutMinutes = ref.read(autoLockMinutesProvider);
    final Duration timeout = Duration(minutes: timeoutMinutes);
    final Duration now = _clock.now();
    final bool clockMovedBackwards = now < backgroundStartedAt;
    final Duration elapsed = clockMovedBackwards
        ? timeout
        : now - backgroundStartedAt;
    if (elapsed >= timeout) {
      ref
          .read(accessSessionProvider.notifier)
          .lock(reason: AccessLockReason.timeout);
    }
  }

  void revealAfterSafeFrame() {
    if (!_foreground ||
        !ref.read(accessSessionProvider).canRevealPrivacyShield) {
      return;
    }
    if (state.covered) {
      state = state.copyWith(covered: false);
    }
  }
}
