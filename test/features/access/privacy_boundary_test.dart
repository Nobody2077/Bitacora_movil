import 'package:bitacora_rpg_personal/features/access/application/access_session_controller.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_state.dart';
import 'package:bitacora_rpg_personal/features/access/domain/privacy_window_platform.dart';
import 'package:bitacora_rpg_personal/features/access/presentation/privacy_boundary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cubre el primer frame, bloquea punteros y cubre al pausar', (
    WidgetTester tester,
  ) async {
    _transitionToResumed(tester.binding);
    var taps = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accessSessionSeedProvider.overrideWithValue(
            const AccessSessionState.unlockedForTesting(),
          ),
        ],
        child: MaterialApp(
          home: AppPrivacyBoundary(
            child: Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('sensitive-action'),
                  onPressed: () => taps += 1,
                  child: const Text('Acción sensible'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(privacyShieldKey), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('sensitive-action')),
      warnIfMissed: false,
    );
    expect(taps, 0);

    await tester.pumpAndSettle();
    expect(find.byKey(privacyShieldKey), findsNothing);
    await tester.tap(find.byKey(const Key('sensitive-action')));
    expect(taps, 1);

    _transitionToPaused(tester.binding);
    await tester.pump();
    expect(find.byKey(privacyShieldKey), findsOneWidget);

    _transitionToResumed(tester.binding);
    await tester.pumpAndSettle();
  });

  testWidgets('no reanuda ni revela si nace mientras la app está pausada', (
    WidgetTester tester,
  ) async {
    _transitionToResumed(tester.binding);
    addTearDown(() {
      _transitionToResumed(tester.binding);
    });

    await tester.pumpWidget(
      _PauseBeforeChildPostFrame(
        onPostFrame: () => _transitionToPaused(tester.binding),
        child: ProviderScope(
          overrides: [
            accessSessionSeedProvider.overrideWithValue(
              const AccessSessionState.unlockedForTesting(),
            ),
          ],
          child: const MaterialApp(
            home: AppPrivacyBoundary(
              child: Scaffold(body: Text('Contenido privado')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(privacyShieldKey), findsOneWidget);

    _transitionToResumed(tester.binding);
    await tester.pumpAndSettle();
    expect(find.byKey(privacyShieldKey), findsNothing);
  });

  testWidgets('desactiva FLAG_SECURE cuando el usuario permite capturas', (
    WidgetTester tester,
  ) async {
    _transitionToResumed(tester.binding);
    final _FakePrivacyWindowPlatform platform = _FakePrivacyWindowPlatform();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accessSessionSeedProvider.overrideWithValue(
            const AccessSessionState.unlockedForTesting(),
          ),
          privacyWindowPlatformProvider.overrideWithValue(platform),
        ],
        child: const MaterialApp(
          home: AppPrivacyBoundary(
            allowScreenshots: true,
            child: Scaffold(body: Text('Contenido privado')),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(platform.protectionValues, <bool>[false]);
  });
}

void _transitionToPaused(TestWidgetsFlutterBinding binding) {
  if (binding.lifecycleState == AppLifecycleState.paused) {
    return;
  }
  if (binding.lifecycleState != AppLifecycleState.resumed) {
    _transitionToResumed(binding);
  }
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void _transitionToResumed(TestWidgetsFlutterBinding binding) {
  switch (binding.lifecycleState) {
    case AppLifecycleState.paused:
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      return;
    case AppLifecycleState.hidden:
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      return;
    case AppLifecycleState.inactive:
    case AppLifecycleState.detached:
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      return;
    case AppLifecycleState.resumed:
      return;
    case null:
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      return;
  }
}

final class _PauseBeforeChildPostFrame extends StatefulWidget {
  const _PauseBeforeChildPostFrame({
    required this.onPostFrame,
    required this.child,
  });

  final VoidCallback onPostFrame;
  final Widget child;

  @override
  State<_PauseBeforeChildPostFrame> createState() =>
      _PauseBeforeChildPostFrameState();
}

final class _FakePrivacyWindowPlatform implements PrivacyWindowPlatform {
  final List<bool> protectionValues = <bool>[];

  @override
  Future<void> setScreenshotProtectionEnabled(bool enabled) async {
    protectionValues.add(enabled);
  }
}

final class _PauseBeforeChildPostFrameState
    extends State<_PauseBeforeChildPostFrame> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onPostFrame());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
