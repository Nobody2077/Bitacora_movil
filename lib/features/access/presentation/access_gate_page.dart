import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/app_preferences_provider.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../shared/sound/ui_sound.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../settings/domain/models/app_preferences.dart';
import '../application/access_session_controller.dart';
import '../application/access_session_sounds.dart';
import '../application/access_session_state.dart';
import '../domain/biometric_authenticator.dart';
import 'access_widgets.dart';

class AccessGatePage extends ConsumerStatefulWidget {
  const AccessGatePage({super.key});

  @override
  ConsumerState<AccessGatePage> createState() => _AccessGatePageState();
}

class _AccessGatePageState extends ConsumerState<AccessGatePage> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _pinConfirmationController =
      TextEditingController();
  final TextEditingController _recoveryConfirmationController =
      TextEditingController();
  int _lastPinLength = 0;
  bool _clearingPinProgrammatically = false;

  @override
  void initState() {
    super.initState();
    _pinController.addListener(_onPinChanged);
  }

  /// Un chasquido por tecla: el mismo para cada dígito, borrar y limpiar, y
  /// solo con la pantalla bloqueada esperando el PIN. Los borrados que hace
  /// la propia app tras un intento no suenan.
  void _onPinChanged() {
    final int length = _pinController.text.length;
    if (length == _lastPinLength) {
      return;
    }
    _lastPinLength = length;
    if (_clearingPinProgrammatically) {
      return;
    }
    final AccessSessionState session = ref.read(accessSessionProvider);
    if (session.phase != AccessSessionPhase.locked || session.isBusy) {
      return;
    }
    unawaited(ref.read(uiSoundServiceProvider).play(UiSound.accessKeypad));
  }

  @override
  void dispose() {
    _pinController.removeListener(_onPinChanged);
    _pinController.clear();
    _pinConfirmationController.clear();
    _recoveryConfirmationController.clear();
    _pinController.dispose();
    _pinConfirmationController.dispose();
    _recoveryConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _prepareEnrollment() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final bool prepared = await ref
        .read(accessSessionProvider.notifier)
        .prepareEnrollment(
          pin: _pinController.text,
          confirmation: _pinConfirmationController.text,
        );
    if (prepared) {
      _pinController.clear();
      _pinConfirmationController.clear();
    }
  }

  Future<void> _confirmEnrollment() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final bool confirmed = await ref
        .read(accessSessionProvider.notifier)
        .confirmEnrollment(_recoveryConfirmationController.text);
    if (confirmed) {
      _recoveryConfirmationController.clear();
    }
  }

  Future<void> _unlockWithPin() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await ref
        .read(accessSessionProvider.notifier)
        .unlockWithPin(_pinController.text);
    _clearingPinProgrammatically = true;
    _pinController.clear();
    _clearingPinProgrammatically = false;
  }

  void _openRecovery() {
    ref.read(accessSessionProvider.notifier).beginRecovery();
    context.go(AppRoutes.lockRecovery);
  }

  @override
  Widget build(BuildContext context) {
    // Carga, acceso concedido y PIN rechazado; ver accessSoundCommands.
    ref.listen<AccessSessionState>(accessSessionProvider, (
      AccessSessionState? previous,
      AccessSessionState next,
    ) {
      final UiSoundService sounds = ref.read(uiSoundServiceProvider);
      for (final AccessSoundCommand command in accessSoundCommands(
        previous,
        next,
      )) {
        unawaited(switch (command.action) {
          AccessSoundAction.play => sounds.play(command.sound),
          AccessSoundAction.stop => sounds.stop(command.sound),
        });
      }
    });
    final AccessSessionState session = ref.watch(accessSessionProvider);
    final Color accentColor = _accessAccentColor();
    return switch (session.phase) {
      AccessSessionPhase.bootstrapping => const AccessScaffold(
        title: 'Verificando acceso',
        subtitle:
            'La base privada permanece cerrada durante esta comprobación.',
        child: TerminalInlineLoadingState(
          message: 'Verificando acceso privado…',
        ),
      ),
      AccessSessionPhase.setupRequired => _buildSetup(session),
      AccessSessionPhase.locked => _buildLocked(session, accentColor),
      AccessSessionPhase.authenticating => AccessTerminalTransition(
        accentColor: accentColor,
        stage: AccessTerminalStage.validating,
      ),
      AccessSessionPhase.corrupted => AccessScaffold(
        title: 'Acceso cerrado',
        subtitle:
            'No se abrió contenido privado ni se regeneraron credenciales.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AccessNoticeBanner(notice: session.notice),
            const Text(
              'Cierra y vuelve a abrir la aplicación. Si el problema persiste, '
              'conserva los archivos: cualquier borrado debe ser una decisión '
              'explícita.',
            ),
          ],
        ),
      ),
      AccessSessionPhase.recovering => const AccessScaffold(
        title: 'Abriendo recuperación',
        subtitle: 'Preparando la puerta de recuperación local.',
        child: TerminalInlineLoadingState(
          message: 'Abriendo recuperación local…',
        ),
      ),
      AccessSessionPhase.unlocked => AccessTerminalTransition(
        accentColor: accentColor,
        stage: AccessTerminalStage.opening,
      ),
    };
  }

  Color _accessAccentColor() {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final AppAccentColor accentChoice =
        ref.watch(accessAccentProvider).value ?? AppAccentColor.red;
    return switch (accentChoice) {
      AppAccentColor.yellow => tokens.valueYellow,
      AppAccentColor.red => tokens.terminalRed,
      AppAccentColor.gray => tokens.textSecondary,
    };
  }

  Widget _buildSetup(AccessSessionState session) {
    if (session.setupStep == AccessSetupStep.confirmRecoveryCode) {
      final String code = session.oneTimeRecoveryCode ?? '';
      return AccessScaffold(
        title: 'Guarda tu código de recuperación',
        subtitle:
            'Es la única vía local si olvidas el PIN. Cópialo a un gestor de '
            'contraseñas o escríbelo en papel, fuera del teléfono; no podremos '
            'volver a mostrarlo.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AccessNoticeBanner(notice: session.notice),
            OneTimeRecoveryCode(code: code),
            const SizedBox(height: 18),
            RecoveryCodeField(
              fieldKey: const Key('setup-recovery-confirmation'),
              controller: _recoveryConfirmationController,
              label: 'Pega o escribe el código desde donde lo guardaste',
              enabled: !session.isBusy,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('confirm-enrollment-button'),
              onPressed: session.isBusy ? null : _confirmEnrollment,
              icon: session.isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined),
              label: Text(
                session.isBusy
                    ? 'Confirmando acceso…'
                    : 'Confirmar y abrir Bitácora',
              ),
            ),
          ],
        ),
      );
    }

    return AccessScaffold(
      title: 'Crea tu PIN privado',
      subtitle:
          'Usaremos seis dígitos. La clave de la base sigue siendo aleatoria '
          'e independiente del PIN.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AccessNoticeBanner(notice: session.notice),
          PinTextField(
            fieldKey: const Key('setup-pin'),
            controller: _pinController,
            label: 'PIN de seis dígitos',
            enabled: !session.isBusy,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          PinTextField(
            fieldKey: const Key('setup-pin-confirmation'),
            controller: _pinConfirmationController,
            label: 'Repite el PIN',
            enabled: !session.isBusy,
            onSubmitted: (_) => _prepareEnrollment(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('prepare-enrollment-button'),
            onPressed: session.isBusy ? null : _prepareEnrollment,
            icon: session.isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.key_outlined),
            label: Text(session.isBusy ? 'Creando acceso…' : 'Crear acceso'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocked(AccessSessionState session, Color accentColor) {
    return AdaptiveAccessUnlock(
      controller: _pinController,
      accentColor: accentColor,
      enabled: !session.isBusy,
      onCompleted: (_) => _unlockWithPin(),
      onRecovery: _openRecovery,
      showBiometrics:
          session.biometricsEnabled &&
          session.biometricAvailability == BiometricAvailability.available,
      onBiometrics: ref
          .read(accessSessionProvider.notifier)
          .unlockWithBiometrics,
      notice: session.notice,
      failedAttempts: session.failedAttempts,
      blockedUntilEpochMillis: session.blockedUntilEpochMillis,
    );
  }
}
