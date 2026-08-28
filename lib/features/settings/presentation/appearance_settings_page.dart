import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_preferences_provider.dart';
import '../../../app/providers/persistence_providers.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../domain/models/app_preferences.dart';

class AppearanceSettingsPage extends ConsumerStatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  ConsumerState<AppearanceSettingsPage> createState() =>
      _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState
    extends ConsumerState<AppearanceSettingsPage> {
  String? _savingPreference;

  Future<void> _save(String preference, AppPreferences nextPreferences) async {
    if (_savingPreference != null) {
      return;
    }
    setState(() => _savingPreference = preference);

    AppFailure? failure;
    try {
      final Result<void> result = await ref
          .read(settingsRepositoryProvider)
          .save(nextPreferences.copyWith(updatedAtUtc: DateTime.now().toUtc()));
      result.fold<void>(
        onSuccess: (_) {},
        onFailure: (AppFailure value) => failure = value,
      );
    } on Object catch (error) {
      failure = UnexpectedFailure(
        'No se pudo actualizar la apariencia.',
        cause: error,
      );
    }

    if (!mounted) {
      return;
    }
    setState(() => _savingPreference = null);
    if (failure case final AppFailure value) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppPreferences> preferences = ref.watch(
      appPreferencesProvider,
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final EdgeInsets padding = constraints.maxWidth < 600
                ? TerminalSpace.pageCompact
                : TerminalSpace.pageTablet;
            return ListView(
              padding: padding,
              children: <Widget>[
                const TerminalPageHeader(
                  title: 'Apariencia',
                  subtitle: 'Lectura, movimiento, contraste y privacidad',
                ),
                const SizedBox(height: TerminalSpace.lg),
                preferences.when(
                  loading: () => const _AppearanceLoadingState(),
                  error: (Object error, StackTrace stackTrace) =>
                      _AppearanceErrorState(
                        onRetry: () => ref.invalidate(appPreferencesProvider),
                      ),
                  data: _buildPreferences,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreferences(AppPreferences preferences) {
    final bool saving = _savingPreference != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (saving) ...<Widget>[
          const LinearProgressIndicator(
            key: Key('appearance-saving-indicator'),
          ),
          const SizedBox(height: TerminalSpace.sm),
        ],
        _PreferenceSwitchCard(
          switchKey: const Key('large-text-switch'),
          icon: Icons.text_increase,
          title: 'Texto grande',
          description:
              'Eleva el texto como mínimo a 1.3× sin reducir el tamaño del sistema.',
          value: preferences.largeText,
          enabled: !saving,
          onChanged: (bool value) =>
              _save('largeText', preferences.copyWith(largeText: value)),
        ),
        const SizedBox(height: TerminalSpace.sm),
        _PreferenceSwitchCard(
          switchKey: const Key('reduce-motion-switch'),
          icon: Icons.motion_photos_off_outlined,
          title: 'Reducir movimiento',
          description:
              'Elimina transiciones decorativas y conserva la respuesta inmediata.',
          value: preferences.reduceMotion,
          enabled: !saving,
          onChanged: (bool value) =>
              _save('reduceMotion', preferences.copyWith(reduceMotion: value)),
        ),
        const SizedBox(height: TerminalSpace.sm),
        _PreferenceSwitchCard(
          switchKey: const Key('high-contrast-switch'),
          icon: Icons.contrast,
          title: 'Alto contraste',
          description:
              'Refuerza bordes, texto y estados sin depender solo del color.',
          value: preferences.highContrast,
          enabled: !saving,
          onChanged: (bool value) =>
              _save('highContrast', preferences.copyWith(highContrast: value)),
        ),
        const SizedBox(height: TerminalSpace.sm),
        _PreferenceSwitchCard(
          switchKey: const Key('hide-amounts-switch'),
          icon: Icons.visibility_off_outlined,
          title: 'Ocultar importes',
          description:
              'Sustituye importes monetarios por una máscara en todas las pantallas.',
          value: preferences.hideAmounts,
          enabled: !saving,
          onChanged: (bool value) =>
              _save('hideAmounts', preferences.copyWith(hideAmounts: value)),
        ),
      ],
    );
  }
}

class _PreferenceSwitchCard extends StatelessWidget {
  const _PreferenceSwitchCard({
    required this.switchKey,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final Key switchKey;
  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final VoidCallback? toggle = enabled ? () => onChanged(!value) : null;
    return Semantics(
      label: title,
      hint: description,
      toggled: value,
      enabled: enabled,
      button: true,
      onTap: toggle,
      excludeSemantics: true,
      child: TerminalCard(
        onTap: toggle,
        padding: const EdgeInsets.symmetric(
          horizontal: TerminalSpace.md,
          vertical: TerminalSpace.sm,
        ),
        borderColor: value ? tokens.infoCyan : tokens.border,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: <Widget>[
              Icon(icon, color: value ? tokens.infoCyan : tokens.textSecondary),
              const SizedBox(width: TerminalSpace.md),
              Expanded(
                child: TerminalSectionTitle(
                  title: title,
                  description: description,
                ),
              ),
              const SizedBox(width: TerminalSpace.sm),
              Switch(
                key: switchKey,
                value: value,
                onChanged: enabled ? onChanged : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppearanceLoadingState extends StatelessWidget {
  const _AppearanceLoadingState();

  @override
  Widget build(BuildContext context) => const TerminalPanel(
    child: Row(
      children: <Widget>[
        SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: TerminalSpace.md),
        Expanded(child: Text('Cargando preferencias…')),
      ],
    ),
  );
}

class _AppearanceErrorState extends StatelessWidget {
  const _AppearanceErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      borderColor: tokens.criticalAction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const TerminalSectionTitle(
            title: 'Preferencias no disponibles',
            description:
                'No fue posible leer los ajustes locales. Puedes volver a intentarlo.',
          ),
          const SizedBox(height: TerminalSpace.md),
          TerminalOutlineButton(
            key: const Key('appearance-retry-button'),
            label: 'Reintentar',
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
