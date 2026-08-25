import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../application/access_session_state.dart';

class AccessScaffold extends StatelessWidget {
  const AccessScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.leading,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens =
        Theme.of(context).extension<AppThemeTokens>() ??
        AppThemeTokens.terminal;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (leading != null) ...<Widget>[
                    Align(alignment: Alignment.centerLeft, child: leading),
                    const SizedBox(height: 20),
                  ],
                  Row(
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: tokens.structuralRed,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: tokens.terminalRed),
                        ),
                        child: Icon(
                          Icons.shield_outlined,
                          color: tokens.infoCyan,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'BITÁCORA // ACCESO',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: tokens.infoCyan,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: tokens.surfaceLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tokens.border),
                    ),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PinTextField extends StatelessWidget {
  const PinTextField({
    required this.controller,
    required this.label,
    this.enabled = true,
    this.onSubmitted,
    this.autofocus = false,
    this.fieldKey,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    textField: true,
    child: TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: true,
      obscuringCharacter: '●',
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      maxLength: 6,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: null,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(labelText: label, counterText: ''),
      onSubmitted: onSubmitted,
    ),
  );
}

class RecoveryCodeField extends StatelessWidget {
  const RecoveryCodeField({
    required this.controller,
    required this.label,
    this.enabled = true,
    this.fieldKey,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    textField: true,
    child: TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.visiblePassword,
      textCapitalization: TextCapitalization.characters,
      enableSuggestions: false,
      autocorrect: false,
      maxLength: 39,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 -]')),
        LengthLimitingTextInputFormatter(39),
      ],
      decoration: InputDecoration(labelText: label, counterText: ''),
    ),
  );
}

class OneTimeRecoveryCode extends StatelessWidget {
  const OneTimeRecoveryCode({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens =
        Theme.of(context).extension<AppThemeTokens>() ??
        AppThemeTokens.terminal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.valueYellow),
      ),
      child: Text(
        code,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: tokens.valueYellow,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class AccessNoticeBanner extends StatelessWidget {
  const AccessNoticeBanner({
    required this.notice,
    this.blockedUntilEpochMillis,
    super.key,
  });

  final AccessNotice? notice;
  final int? blockedUntilEpochMillis;

  @override
  Widget build(BuildContext context) {
    final AccessNotice? value = notice;
    if (value == null) {
      return const SizedBox.shrink();
    }
    final AppThemeTokens tokens =
        Theme.of(context).extension<AppThemeTokens>() ??
        AppThemeTokens.terminal;
    final String text = switch (value) {
      AccessNotice.pinMismatch => 'Los dos PIN no coinciden.',
      AccessNotice.pinPolicyRejected =>
        'Usa seis dígitos no repetidos y evita secuencias obvias.',
      AccessNotice.invalidCredential => 'La credencial no es válida.',
      AccessNotice.progressiveWait => _blockedMessage(),
      AccessNotice.recoveryCodeMismatch =>
        'El código escrito no coincide con el código mostrado.',
      AccessNotice.biometricUnavailable =>
        'La biometría no está disponible o no está configurada.',
      AccessNotice.biometricCancelled => 'Autenticación biométrica cancelada.',
      AccessNotice.biometricLockedOut =>
        'La biometría está bloqueada. Usa tu PIN de la app.',
      AccessNotice.biometricFailed =>
        'No se pudo confirmar la biometría. Usa tu PIN.',
      AccessNotice.credentialStateCorrupted =>
        'El estado de acceso no es legible. La aplicación permanece cerrada.',
      AccessNotice.pinChanged => 'PIN actualizado correctamente.',
      AccessNotice.biometricsEnabled => 'Biometría activada.',
      AccessNotice.biometricsDisabled => 'Biometría desactivada.',
      AccessNotice.sessionTimedOut =>
        'La sesión se bloqueó por permanecer fuera de la app.',
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.structuralRed.withValues(alpha: 0.4),
        border: Border.all(color: tokens.attentionOrange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text),
    );
  }

  String _blockedMessage() {
    final int? until = blockedUntilEpochMillis;
    if (until == null) {
      return 'Demasiados intentos. Espera antes de volver a probar.';
    }
    final Duration remaining = DateTime.fromMillisecondsSinceEpoch(
      until,
    ).difference(DateTime.now());
    final int seconds = remaining.inSeconds.clamp(1, 900);
    return 'Demasiados intentos. Vuelve a probar en aproximadamente '
        '$seconds segundos.';
  }
}
