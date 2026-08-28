import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/persistence_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../core/result/result.dart';
import '../../../shared/adaptive/app_breakpoints.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../settings/domain/models/app_preferences.dart';
import '../application/access_session_controller.dart';
import '../application/access_session_state.dart';
import '../application/privacy_controller.dart';
import '../domain/biometric_authenticator.dart';
import 'access_widgets.dart';

class SettingsLandingPage extends StatelessWidget {
  const SettingsLandingPage({super.key});

  @override
  Widget build(BuildContext context) => _SettingsSurface(
    title: 'Ajustes',
    subtitle: 'Control local de apariencia, privacidad y continuidad.',
    children: <Widget>[
      _SettingsDestination(
        key: const Key('open-appearance-settings'),
        icon: Icons.palette_outlined,
        title: 'Apariencia y accesibilidad',
        description: 'Texto, movimiento, contraste e importes privados.',
        onTap: () => context.go(AppRoutes.settingsAppearance),
      ),
      const SizedBox(height: TerminalSpace.sm),
      _SettingsDestination(
        key: const Key('open-privacy-settings'),
        icon: Icons.shield_outlined,
        title: 'Privacidad y acceso',
        description: 'PIN, biometría, bloqueo y cubierta segura.',
        onTap: () => context.go(AppRoutes.settingsPrivacy),
      ),
    ],
  );
}

class PrivacySettingsPage extends ConsumerStatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  ConsumerState<PrivacySettingsPage> createState() =>
      _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends ConsumerState<PrivacySettingsPage> {
  bool _saving = false;

  Future<void> _saveAutoLock(int minutes) async {
    if (_saving) {
      return;
    }
    final int previous = ref.read(autoLockMinutesProvider);
    if (minutes == previous) {
      return;
    }
    if (!ref.read(autoLockMinutesProvider.notifier).setMinutes(minutes)) {
      return;
    }
    setState(() => _saving = true);

    bool saved = false;
    try {
      final Result<AppPreferences> loaded = await ref
          .read(settingsRepositoryProvider)
          .load();
      AppPreferences? preferences;
      loaded.fold<void>(
        onSuccess: (AppPreferences value) => preferences = value,
        onFailure: (_) {},
      );
      final AppPreferences? current = preferences;
      if (current != null) {
        final Result<void> result = await ref
            .read(settingsRepositoryProvider)
            .save(
              current.copyWith(
                autoLockMinutes: minutes,
                updatedAtUtc: DateTime.now().toUtc(),
              ),
            );
        result.fold<void>(onSuccess: (_) => saved = true, onFailure: (_) {});
      }
    } on Object {
      saved = false;
    }

    if (!mounted) {
      return;
    }
    if (!saved) {
      ref.read(autoLockMinutesProvider.notifier).setMinutes(previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el autobloqueo.')),
      );
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final int autoLockMinutes = ref.watch(autoLockMinutesProvider);
    return _SettingsSurface(
      title: 'Privacidad y acceso',
      subtitle: 'Estas reglas se aplican antes de construir contenido privado.',
      children: <Widget>[
        Text('AUTOBLOQUEO', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        SegmentedButton<int>(
          key: const Key('auto-lock-selector'),
          segments: const <ButtonSegment<int>>[
            ButtonSegment<int>(value: 0, label: Text('Ahora')),
            ButtonSegment<int>(value: 1, label: Text('1 min')),
            ButtonSegment<int>(value: 5, label: Text('5 min')),
            ButtonSegment<int>(value: 15, label: Text('15 min')),
          ],
          selected: <int>{autoLockMinutes},
          onSelectionChanged: _saving
              ? null
              : (Set<int> selection) => _saveAutoLock(selection.single),
        ),
        if (_saving) ...<Widget>[
          const SizedBox(height: 10),
          const TerminalInlineLoadingState(
            message: 'Guardando tiempo de autobloqueo…',
          ),
        ],
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            key: const Key('open-change-pin'),
            leading: const Icon(Icons.password),
            title: const Text('Cambiar PIN'),
            subtitle: const Text('Exige el PIN actual y dos copias del nuevo.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.settingsPrivacyPin),
          ),
        ),
        Card(
          child: ListTile(
            key: const Key('open-biometric-settings'),
            leading: const Icon(Icons.fingerprint),
            title: const Text('Biometría'),
            subtitle: const Text('Opcional; nunca sustituye la recuperación.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.settingsPrivacyBiometrics),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          key: const Key('manual-lock-button'),
          onPressed: () {
            ref
                .read(accessSessionProvider.notifier)
                .lock(reason: AccessLockReason.manual);
            context.go(AppRoutes.lock);
          },
          icon: const Icon(Icons.lock_outline),
          label: const Text('Bloquear ahora'),
        ),
      ],
    );
  }
}

class ChangePinPage extends ConsumerStatefulWidget {
  const ChangePinPage({super.key});

  @override
  ConsumerState<ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState extends ConsumerState<ChangePinPage> {
  final TextEditingController _currentPin = TextEditingController();
  final TextEditingController _newPin = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();

  @override
  void dispose() {
    _currentPin.clear();
    _newPin.clear();
    _confirmation.clear();
    _currentPin.dispose();
    _newPin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final bool changed = await ref
        .read(accessSessionProvider.notifier)
        .changePin(
          currentPin: _currentPin.text,
          newPin: _newPin.text,
          confirmation: _confirmation.text,
        );
    _currentPin.clear();
    if (changed) {
      _newPin.clear();
      _confirmation.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AccessSessionState session = ref.watch(accessSessionProvider);
    return _SettingsSurface(
      title: 'Cambiar PIN',
      subtitle:
          'El nuevo PIN recibe un salt independiente y un verificador nuevo.',
      children: <Widget>[
        AccessNoticeBanner(
          notice: session.notice,
          blockedUntilEpochMillis: session.blockedUntilEpochMillis,
        ),
        PinTextField(
          fieldKey: const Key('current-pin'),
          controller: _currentPin,
          label: 'PIN actual',
          enabled: !session.isBusy,
        ),
        const SizedBox(height: 12),
        PinTextField(
          fieldKey: const Key('new-pin'),
          controller: _newPin,
          label: 'PIN nuevo',
          enabled: !session.isBusy,
        ),
        const SizedBox(height: 12),
        PinTextField(
          fieldKey: const Key('new-pin-confirmation'),
          controller: _confirmation,
          label: 'Repite el PIN nuevo',
          enabled: !session.isBusy,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        TerminalCriticalButton(
          key: const Key('change-pin-button'),
          label: 'Actualizar PIN',
          icon: Icons.password,
          onPressed: session.isBusy ? null : _submit,
        ),
      ],
    );
  }
}

class BiometricsSettingsPage extends ConsumerStatefulWidget {
  const BiometricsSettingsPage({super.key});

  @override
  ConsumerState<BiometricsSettingsPage> createState() =>
      _BiometricsSettingsPageState();
}

class _BiometricsSettingsPageState
    extends ConsumerState<BiometricsSettingsPage> {
  final TextEditingController _currentPin = TextEditingController();

  @override
  void dispose() {
    _currentPin.clear();
    _currentPin.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool enabled) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await ref
        .read(accessSessionProvider.notifier)
        .setBiometricsEnabled(currentPin: _currentPin.text, enabled: enabled);
    _currentPin.clear();
  }

  @override
  Widget build(BuildContext context) {
    final AccessSessionState session = ref.watch(accessSessionProvider);
    final bool enabled = session.biometricsEnabled;
    final String capability = switch (session.biometricAvailability) {
      BiometricAvailability.available => 'Disponible y enrolada',
      BiometricAvailability.unavailable => 'No enrolada o no disponible',
      BiometricAvailability.unsupported => 'No compatible',
    };
    return _SettingsSurface(
      title: 'Biometría',
      subtitle:
          'Se solicita solo biometría. El PIN o patrón del sistema nunca abre '
          'Bitácora por esta vía.',
      children: <Widget>[
        AccessNoticeBanner(
          notice: session.notice,
          blockedUntilEpochMillis: session.blockedUntilEpochMillis,
        ),
        Card(
          child: ListTile(
            leading: Icon(
              enabled ? Icons.fingerprint : Icons.fingerprint_outlined,
            ),
            title: Text(
              enabled ? 'Biometría activada' : 'Biometría desactivada',
            ),
            subtitle: Text(capability),
            trailing: Icon(
              enabled ? Icons.check_circle : Icons.remove_circle_outline,
            ),
          ),
        ),
        const SizedBox(height: 16),
        PinTextField(
          fieldKey: const Key('biometrics-current-pin'),
          controller: _currentPin,
          label: 'Confirma tu PIN de Bitácora',
          enabled: !session.isBusy,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('toggle-biometrics-button'),
          onPressed: session.isBusy ? null : () => _toggle(!enabled),
          icon: session.isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.fingerprint),
          label: Text(
            session.isBusy
                ? 'Actualizando biometría…'
                : enabled
                ? 'Desactivar biometría'
                : 'Activar biometría',
          ),
        ),
      ],
    );
  }
}

class _SettingsSurface extends StatelessWidget {
  const _SettingsSurface({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => ListView(
          padding: constraints.maxWidth < AppBreakpoints.compact
              ? TerminalSpace.pageCompact
              : TerminalSpace.pageTablet,
          children: <Widget>[
            TerminalPageHeader(title: title, subtitle: subtitle),
            const SizedBox(height: TerminalSpace.lg),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _SettingsDestination extends StatelessWidget {
  const _SettingsDestination({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalCard(
      onTap: onTap,
      padding: const EdgeInsets.all(TerminalSpace.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: <Widget>[
            Icon(icon, color: tokens.infoCyan, size: 30),
            const SizedBox(width: TerminalSpace.md),
            Expanded(
              child: TerminalSectionTitle(
                title: title,
                description: description,
              ),
            ),
            const SizedBox(width: TerminalSpace.sm),
            Icon(Icons.chevron_right, color: tokens.infoCyan),
          ],
        ),
      ),
    );
  }
}
