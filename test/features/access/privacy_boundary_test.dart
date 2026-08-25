import 'package:bitacora_rpg_personal/features/access/application/access_session_controller.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_state.dart';
import 'package:bitacora_rpg_personal/features/access/presentation/privacy_boundary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cubre el primer frame, bloquea punteros y cubre al pausar', (
    WidgetTester tester,
  ) async {
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

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.byKey(privacyShieldKey), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  });
}
