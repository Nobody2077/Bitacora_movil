import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/access_session_controller.dart';
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

  @override
  void dispose() {
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
    _pinController.clear();
  }

  void _openRecovery() {
    ref.read(accessSessionProvider.notifier).beginRecovery();
    context.go(AppRoutes.lockRecovery);
  }

  @override
  Widget build(BuildContext context) {
    final AccessSessionState session = ref.watch(accessSessionProvider);
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
      AccessSessionPhase.locked ||
      AccessSessionPhase.authenticating => _buildLocked(session),
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
      AccessSessionPhase.unlocked => const AccessScaffold(
        title: 'Acceso confirmado',
        subtitle: 'Restaurando el destino interno de forma segura.',
        child: TerminalInlineLoadingState(
          message: 'Restaurando destino protegido…',
        ),
      ),
    };
  }

  Widget _buildSetup(AccessSessionState session) {
    if (session.setupStep == AccessSetupStep.confirmRecoveryCode) {
      final String code = session.oneTimeRecoveryCode ?? '';
      return AccessScaffold(
        title: 'Guarda tu código de recuperación',
        subtitle:
            'Es la única vía local si olvidas el PIN. Guárdalo fuera del '
            'teléfono; no podremos volver a mostrarlo.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AccessNoticeBanner(notice: session.notice),
            OneTimeRecoveryCode(code: code),
            const SizedBox(height: 18),
            RecoveryCodeField(
              fieldKey: const Key('setup-recovery-confirmation'),
              controller: _recoveryConfirmationController,
              label: 'Escribe el código completo para confirmarlo',
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

  Widget _buildLocked(AccessSessionState session) => AccessScaffold(
    title: 'Bitácora bloqueada',
    subtitle:
        'Ninguna pantalla privada ni repositorio se construye hasta abrir.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AccessNoticeBanner(
          notice: session.notice,
          blockedUntilEpochMillis: session.blockedUntilEpochMillis,
        ),
        PinTextField(
          fieldKey: const Key('unlock-pin'),
          controller: _pinController,
          label: 'PIN de Bitácora',
          enabled: !session.isBusy,
          autofocus: true,
          onSubmitted: (_) => _unlockWithPin(),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('unlock-button'),
          onPressed: session.isBusy ? null : _unlockWithPin,
          icon: session.isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_open_outlined),
          label: Text(session.isBusy ? 'Abriendo Bitácora…' : 'Abrir Bitácora'),
        ),
        if (session.biometricsEnabled &&
            session.biometricAvailability ==
                BiometricAvailability.available) ...<Widget>[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('biometric-unlock-button'),
            onPressed: session.isBusy
                ? null
                : ref.read(accessSessionProvider.notifier).unlockWithBiometrics,
            icon: const Icon(Icons.fingerprint),
            label: const Text('Usar biometría'),
          ),
        ],
        const SizedBox(height: 10),
        TextButton(
          key: const Key('open-recovery-button'),
          onPressed: session.isBusy ? null : _openRecovery,
          child: const Text('Olvidé mi PIN'),
        ),
      ],
    ),
  );
}
