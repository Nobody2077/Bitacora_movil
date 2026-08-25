import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../application/access_session_controller.dart';
import '../application/access_session_state.dart';
import 'access_widgets.dart';

class RecoveryPage extends ConsumerStatefulWidget {
  const RecoveryPage({super.key});

  @override
  ConsumerState<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends ConsumerState<RecoveryPage> {
  final TextEditingController _recoveryController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _pinConfirmationController =
      TextEditingController();
  final TextEditingController _replacementConfirmationController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          ref.read(accessSessionProvider).phase == AccessSessionPhase.locked) {
        ref.read(accessSessionProvider.notifier).beginRecovery();
      }
    });
  }

  @override
  void dispose() {
    _recoveryController.clear();
    _newPinController.clear();
    _pinConfirmationController.clear();
    _replacementConfirmationController.clear();
    _recoveryController.dispose();
    _newPinController.dispose();
    _pinConfirmationController.dispose();
    _replacementConfirmationController.dispose();
    super.dispose();
  }

  void _cancel() {
    ref.read(accessSessionProvider.notifier).cancelRecovery();
    context.go(AppRoutes.lock);
  }

  Future<void> _prepare() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final bool prepared = await ref
        .read(accessSessionProvider.notifier)
        .prepareRecovery(
          recoveryCode: _recoveryController.text,
          newPin: _newPinController.text,
          pinConfirmation: _pinConfirmationController.text,
        );
    if (prepared) {
      _recoveryController.clear();
      _newPinController.clear();
      _pinConfirmationController.clear();
    }
  }

  Future<void> _confirm() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final bool confirmed = await ref
        .read(accessSessionProvider.notifier)
        .confirmRecovery(_replacementConfirmationController.text);
    if (confirmed) {
      _replacementConfirmationController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AccessSessionState session = ref.watch(accessSessionProvider);
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _cancel();
        }
      },
      child: _buildContent(session),
    );
  }

  Widget _buildContent(AccessSessionState session) {
    if (session.phase != AccessSessionPhase.recovering) {
      return AccessScaffold(
        title: 'Preparando recuperación',
        subtitle: 'La base continúa cerrada.',
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: _cancel,
          icon: const Icon(Icons.arrow_back),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (session.recoveryStep == AccessRecoveryStep.confirmReplacementCode) {
      return AccessScaffold(
        title: 'Guarda el código nuevo',
        subtitle:
            'El código anterior aún no se invalida. La rotación se confirmará '
            'solo cuando escribas este código completo.',
        leading: IconButton(
          tooltip: 'Cancelar recuperación',
          onPressed: session.isBusy ? null : _cancel,
          icon: const Icon(Icons.close),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AccessNoticeBanner(notice: session.notice),
            OneTimeRecoveryCode(code: session.oneTimeRecoveryCode ?? ''),
            const SizedBox(height: 18),
            RecoveryCodeField(
              fieldKey: const Key('replacement-recovery-confirmation'),
              controller: _replacementConfirmationController,
              label: 'Confirma el código nuevo',
              enabled: !session.isBusy,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('confirm-recovery-button'),
              onPressed: session.isBusy ? null : _confirm,
              icon: session.isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restart_alt),
              label: const Text('Rotar credenciales y abrir'),
            ),
          ],
        ),
      );
    }

    return AccessScaffold(
      title: 'Recupera tu acceso',
      subtitle:
          'Escribe el código externo y define un PIN nuevo. Los datos no se '
          'borran ni cambia la clave cifrada de la base.',
      leading: IconButton(
        tooltip: 'Volver al PIN',
        onPressed: session.isBusy ? null : _cancel,
        icon: const Icon(Icons.arrow_back),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AccessNoticeBanner(
            notice: session.notice,
            blockedUntilEpochMillis: session.blockedUntilEpochMillis,
          ),
          RecoveryCodeField(
            fieldKey: const Key('recovery-code'),
            controller: _recoveryController,
            label: 'Código de recuperación',
            enabled: !session.isBusy,
          ),
          const SizedBox(height: 12),
          PinTextField(
            fieldKey: const Key('recovery-new-pin'),
            controller: _newPinController,
            label: 'PIN nuevo',
            enabled: !session.isBusy,
          ),
          const SizedBox(height: 12),
          PinTextField(
            fieldKey: const Key('recovery-new-pin-confirmation'),
            controller: _pinConfirmationController,
            label: 'Repite el PIN nuevo',
            enabled: !session.isBusy,
            onSubmitted: (_) => _prepare(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('prepare-recovery-button'),
            onPressed: session.isBusy ? null : _prepare,
            icon: session.isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.key_outlined),
            label: const Text('Validar y preparar rotación'),
          ),
        ],
      ),
    );
  }
}
