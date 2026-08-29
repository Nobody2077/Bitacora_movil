import 'package:bitacora_rpg_personal/app/providers/app_preferences_provider.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme_tokens.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_controller.dart';
import 'package:bitacora_rpg_personal/features/access/application/access_session_state.dart';
import 'package:bitacora_rpg_personal/features/access/domain/biometric_authenticator.dart';
import 'package:bitacora_rpg_personal/features/access/presentation/access_gate_page.dart';
import 'package:bitacora_rpg_personal/features/access/presentation/access_widgets.dart';
import 'package:bitacora_rpg_personal/features/settings/domain/models/app_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ingresa seis dígitos sin abrir un teclado del sistema', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    String? completedCode;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              final AppThemeTokens tokens = Theme.of(
                context,
              ).extension<AppThemeTokens>()!;
              return SingleChildScrollView(
                child: AccessCodeMatrix(
                  controller: controller,
                  accentColor: tokens.valueYellow,
                  onCompleted: (String value) => completedCode = value,
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('BÚFER'), findsOneWidget);
    expect(find.text('MATRIZ DE CÓDIGO'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    for (final String digit in <String>['4', '8', '2', '9', '5', '1']) {
      await tester.tap(find.byKey(ValueKey<String>('access-code-key-$digit')));
      await tester.pump();
    }

    expect(controller.text, '482951');
    expect(completedCode, '482951');
  });

  testWidgets('permite borrar el último dígito y limpiar el búfer', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: AccessCodeMatrix(
          controller: controller,
          accentColor: AppThemeTokens.terminal.terminalRed,
          onCompleted: (_) {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('access-code-key-1')));
    await tester.tap(find.byKey(const Key('access-code-key-2')));
    await tester.tap(find.byKey(const Key('access-code-backspace')));
    await tester.pump();
    expect(controller.text, '1');

    await tester.tap(find.byKey(const Key('access-code-clear')));
    await tester.pump();
    expect(controller.text, isEmpty);
  });

  testWidgets('golden del acceso táctil amarillo', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1280);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accessSessionSeedProvider.overrideWithValue(_lockedSession),
          accessAccentProvider.overrideWith(
            (ref) async => AppAccentColor.yellow,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const AccessGatePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('BÚFER'), findsOneWidget);
    expect(find.text('MATRIZ DE CÓDIGO'), findsOneWidget);
    expect(
      tester.getBottomRight(find.byKey(const Key('open-recovery-button'))).dy,
      lessThanOrEqualTo(1280),
    );
    await expectLater(
      find.byType(AccessGatePage),
      matchesGoldenFile('goldens/access_matrix_yellow.png'),
    );
  });

  testWidgets('acceso horizontal usa dos columnas completas', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accessSessionSeedProvider.overrideWithValue(_lockedSession),
          accessAccentProvider.overrideWith(
            (ref) async => AppAccentColor.yellow,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const AccessGatePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('access-layout-wide')), findsOneWidget);
    expect(find.byKey(const Key('access-layout-portrait')), findsNothing);
    expect(find.byKey(const Key('access-code-key-0')), findsOneWidget);
    expect(find.byKey(const Key('access-code-backspace')), findsOneWidget);
    expect(find.byKey(const Key('open-recovery-button')), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const Key('unlock-code-matrix'))).dx,
      lessThan(
        tester.getCenter(find.byKey(const Key('access-protocol-panel'))).dx,
      ),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(AccessGatePage),
      matchesGoldenFile('goldens/access_matrix_wide_yellow.png'),
    );
  });

  testWidgets('texto 2.0 conserva teclado y recuperación accesibles', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accessSessionSeedProvider.overrideWithValue(_lockedSession),
          accessAccentProvider.overrideWith(
            (ref) async => AppAccentColor.yellow,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: AccessGatePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('access-layout-portrait')), findsOneWidget);
    expect(find.byKey(const Key('access-code-key-0')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-recovery-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('open-recovery-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra solo una espera de seguridad real', (
    WidgetTester tester,
  ) async {
    final AccessSessionState waitingSession = AccessSessionState(
      phase: AccessSessionPhase.locked,
      revision: 3,
      setupStep: AccessSetupStep.enterPin,
      recoveryStep: AccessRecoveryStep.enterRecoveryAndPin,
      biometricsEnabled: false,
      biometricAvailability: BiometricAvailability.unavailable,
      isBusy: false,
      failedAttempts: 5,
      blockedUntilEpochMillis: DateTime.now()
          .add(const Duration(seconds: 30))
          .millisecondsSinceEpoch,
      notice: AccessNotice.progressiveWait,
      oneTimeRecoveryCode: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accessSessionSeedProvider.overrideWithValue(waitingSession),
          accessAccentProvider.overrideWith(
            (ref) async => AppAccentColor.yellow,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const AccessGatePage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('ESPERA DE SEGURIDAD'), findsOneWidget);
    final Text countdown = tester.widget<Text>(
      find.byKey(const Key('access-security-status-value')),
    );
    expect(countdown.data, anyOf('29s', '30s'));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('transición terminal respeta movimiento reducido', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AccessTerminalTransition(
            accentColor: Color(0xFFF5D547),
            stage: AccessTerminalStage.validating,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ENLACE DE TERMINAL'), findsOneWidget);
    expect(find.text('VALIDANDO SECUENCIA'), findsOneWidget);
    expect(find.text('DERIVACIÓN SEGURA EN CURSO'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(AccessTerminalTransition),
      matchesGoldenFile('goldens/access_terminal_transition_yellow.png'),
    );
  });

  testWidgets('estado autenticando sustituye la matriz por la transición', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accessSessionSeedProvider.overrideWithValue(_authenticatingSession),
          accessAccentProvider.overrideWith(
            (ref) async => AppAccentColor.yellow,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: AccessGatePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AccessTerminalTransition), findsOneWidget);
    expect(find.byType(AccessCodeMatrix), findsNothing);
    expect(find.text('VALIDANDO SECUENCIA'), findsOneWidget);
  });
}

const AccessSessionState _lockedSession = AccessSessionState(
  phase: AccessSessionPhase.locked,
  revision: 1,
  setupStep: AccessSetupStep.enterPin,
  recoveryStep: AccessRecoveryStep.enterRecoveryAndPin,
  biometricsEnabled: false,
  biometricAvailability: BiometricAvailability.unavailable,
  isBusy: false,
  failedAttempts: 0,
  blockedUntilEpochMillis: null,
  notice: null,
  oneTimeRecoveryCode: null,
);

const AccessSessionState _authenticatingSession = AccessSessionState(
  phase: AccessSessionPhase.authenticating,
  revision: 2,
  setupStep: AccessSetupStep.enterPin,
  recoveryStep: AccessRecoveryStep.enterRecoveryAndPin,
  biometricsEnabled: false,
  biometricAvailability: BiometricAvailability.unavailable,
  isBusy: true,
  failedAttempts: 0,
  blockedUntilEpochMillis: null,
  notice: null,
  oneTimeRecoveryCode: null,
);
