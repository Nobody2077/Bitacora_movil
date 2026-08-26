import 'package:bitacora_rpg_personal/features/access/application/access_session_controller.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_state.dart';
import 'package:bitacora_rpg_personal/features/access/application/monotonic_clock.dart';
import 'package:bitacora_rpg_personal/features/access/application/privacy_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrivacyController', () {
    test('timeout - 1 conserva sesión', () async {
      expect(
        await _phaseAfterBackground(
          timeoutMinutes: 5,
          elapsed: const Duration(minutes: 5) - const Duration(milliseconds: 1),
        ),
        AccessSessionPhase.unlocked,
      );
    });

    test('timeout bloquea exactamente en el límite', () async {
      expect(
        await _phaseAfterBackground(
          timeoutMinutes: 5,
          elapsed: const Duration(minutes: 5),
        ),
        AccessSessionPhase.locked,
      );
    });

    test('timeout + 1 bloquea', () async {
      expect(
        await _phaseAfterBackground(
          timeoutMinutes: 5,
          elapsed: const Duration(minutes: 5, milliseconds: 1),
        ),
        AccessSessionPhase.locked,
      );
    });

    test('cero bloquea al cubrir, sin esperar resume', () {
      final _FakeMonotonicClock clock = _FakeMonotonicClock();
      final ProviderContainer container = _privacyContainer(clock);
      addTearDown(container.dispose);
      container.read(accessSessionProvider);
      container.read(autoLockMinutesProvider.notifier).setMinutes(0);

      container.read(privacyControllerProvider.notifier).coverForBackground();

      expect(
        container.read(accessSessionProvider).phase,
        AccessSessionPhase.locked,
      );
      expect(container.read(privacyControllerProvider).covered, isTrue);
    });

    test('política aún no cargada falla segura y bloquea al cubrir', () {
      final _FakeMonotonicClock clock = _FakeMonotonicClock();
      final ProviderContainer container = _privacyContainer(clock);
      addTearDown(container.dispose);
      container.read(accessSessionProvider);

      container.read(privacyControllerProvider.notifier).coverForBackground();

      expect(container.read(autoLockMinutesProvider), 0);
      expect(
        container.read(accessSessionProvider).phase,
        AccessSessionPhase.locked,
      );
    });

    test('recargar política descarta un valor anterior más permisivo', () {
      final _FakeMonotonicClock clock = _FakeMonotonicClock();
      final ProviderContainer container = _privacyContainer(clock);
      addTearDown(container.dispose);
      container.read(accessSessionProvider);
      final AutoLockPolicyController policy = container.read(
        autoLockMinutesProvider.notifier,
      );
      policy.setMinutes(15);

      policy.useSafeFallback();
      container.read(privacyControllerProvider.notifier).coverForBackground();

      expect(container.read(autoLockMinutesProvider), 0);
      expect(
        container.read(accessSessionProvider).phase,
        AccessSessionPhase.locked,
      );
    });
  });
}

Future<AccessSessionPhase> _phaseAfterBackground({
  required int timeoutMinutes,
  required Duration elapsed,
}) async {
  final _FakeMonotonicClock clock = _FakeMonotonicClock();
  final ProviderContainer container = _privacyContainer(clock);
  container.read(accessSessionProvider);
  container.read(autoLockMinutesProvider.notifier).setMinutes(timeoutMinutes);
  final PrivacyController privacy = container.read(
    privacyControllerProvider.notifier,
  );
  privacy.coverForBackground();
  clock.advance(elapsed);
  await privacy.resume();
  final AccessSessionPhase phase = container.read(accessSessionProvider).phase;
  container.dispose();
  return phase;
}

ProviderContainer _privacyContainer(_FakeMonotonicClock clock) =>
    ProviderContainer(
      overrides: [
        accessSessionSeedProvider.overrideWithValue(
          const AccessSessionState.unlockedForTesting(),
        ),
        monotonicClockProvider.overrideWithValue(clock),
      ],
    );

final class _FakeMonotonicClock implements MonotonicClock {
  Duration _now = Duration.zero;

  void advance(Duration duration) => _now += duration;

  @override
  Duration now() => _now;
}
