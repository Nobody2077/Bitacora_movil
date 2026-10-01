import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_preferences_provider.dart';
import '../../../app/providers/persistence_providers.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../shared/adaptive/app_breakpoints.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../domain/models/app_preferences.dart';
import 'preference_switch_card.dart';

class AppearanceSettingsPage extends ConsumerStatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  ConsumerState<AppearanceSettingsPage> createState() =>
      _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState
    extends ConsumerState<AppearanceSettingsPage> {
  String? _savingPreference;

  /// Va a un espejo no sensible, no a la base: debe aplicarse también en la
  /// pantalla del PIN, antes de abrir los datos cifrados.
  Future<void> _saveImmersive(bool enabled) async {
    if (_savingPreference != null) {
      return;
    }
    setState(() => _savingPreference = 'immersive');
    bool saved = false;
    try {
      await ref.read(immersiveModePreferenceStoreProvider).write(enabled);
      ref.invalidate(immersiveModeProvider);
      saved = true;
    } on Object {
      saved = false;
    }
    if (!mounted) {
      return;
    }
    setState(() => _savingPreference = null);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la pantalla completa.'),
        ),
      );
    }
  }

  Future<void> _save(String preference, AppPreferences nextPreferences) async {
    if (_savingPreference != null) {
      return;
    }
    setState(() => _savingPreference = preference);

    AppFailure? failure;
    bool saved = false;
    try {
      final Result<void> result = await ref
          .read(settingsRepositoryProvider)
          .save(nextPreferences.copyWith(updatedAtUtc: DateTime.now().toUtc()));
      result.fold<void>(
        onSuccess: (_) => saved = true,
        onFailure: (AppFailure value) => failure = value,
      );
      if (saved && preference == 'primaryColorHex') {
        await ref
            .read(accessAccentPreferenceStoreProvider)
            .write(AppAccentColor.fromHex(nextPreferences.primaryColorHex));
        ref.invalidate(accessAccentProvider);
      }
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
            final EdgeInsets padding =
                constraints.maxWidth < AppBreakpoints.compact
                ? TerminalSpace.pageCompact
                : TerminalSpace.pageTablet;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: ListView(
                  padding: padding,
                  children: <Widget>[
                    const TerminalPageHeader(
                      title: 'Apariencia',
                      subtitle: 'Lectura, movimiento, contraste y privacidad',
                    ),
                    const SizedBox(height: TerminalSpace.lg),
                    preferences.when(
                      loading: () => const TerminalLoadingState(
                        message: 'Cargando preferencias…',
                      ),
                      error: (Object error, StackTrace stackTrace) =>
                          TerminalErrorState(
                            title: 'Preferencias no disponibles',
                            description:
                                'No fue posible leer los ajustes locales.',
                            retryButtonKey: const Key(
                              'appearance-retry-button',
                            ),
                            onRetry: () =>
                                ref.invalidate(appPreferencesProvider),
                          ),
                      data: (AppPreferences value) => _buildPreferences(
                        value,
                        expanded:
                            constraints.maxWidth >= AppBreakpoints.expanded,
                        availableWidth:
                            constraints.maxWidth.clamp(0, 1120).toDouble() -
                            padding.horizontal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreferences(
    AppPreferences preferences, {
    required bool expanded,
    required double availableWidth,
  }) {
    final bool saving = _savingPreference != null;
    final Widget immersiveCard = PreferenceSwitchCard(
      switchKey: const Key('immersive-mode-switch'),
      icon: Icons.fullscreen,
      title: 'Pantalla completa',
      description:
          'Oculta la barra de estado y la de navegación. Desliza desde el '
          'borde para verlas un momento.',
      value: ref.watch(immersiveModeProvider).value ?? true,
      enabled: !saving,
      onChanged: _saveImmersive,
    );
    final List<Widget> cards = <Widget>[
      PreferenceSwitchCard(
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
      PreferenceSwitchCard(
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
      PreferenceSwitchCard(
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
      PreferenceSwitchCard(
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
    ];
    final Widget content = expanded
        ? Wrap(
            spacing: TerminalSpace.md,
            runSpacing: TerminalSpace.md,
            children: <Widget>[
              for (final Widget card in cards)
                SizedBox(
                  width: (availableWidth - TerminalSpace.md) / 2,
                  child: card,
                ),
            ],
          )
        : Column(
            children: <Widget>[
              for (int index = 0; index < cards.length; index++) ...<Widget>[
                cards[index],
                if (index != cards.length - 1)
                  const SizedBox(height: TerminalSpace.sm),
              ],
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (saving) ...<Widget>[
          const LinearProgressIndicator(
            key: Key('appearance-saving-indicator'),
          ),
          const SizedBox(height: TerminalSpace.sm),
        ],
        _AccessAccentSelector(
          selected: AppAccentColor.fromHex(preferences.primaryColorHex),
          enabled: !saving,
          onSelected: (AppAccentColor color) => _save(
            'primaryColorHex',
            preferences.copyWith(primaryColorHex: color.hex),
          ),
        ),
        const SizedBox(height: TerminalSpace.lg),
        content,
        const SizedBox(height: TerminalSpace.md),
        immersiveCard,
      ],
    );
  }
}

class _AccessAccentSelector extends StatelessWidget {
  const _AccessAccentSelector({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final AppAccentColor selected;
  final bool enabled;
  final ValueChanged<AppAccentColor> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      padding: const EdgeInsets.all(TerminalSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const TerminalSectionTitle(
            title: 'Color de acceso',
            description:
                'Define el color dominante del BÚFER y la matriz al iniciar.',
          ),
          const SizedBox(height: TerminalSpace.md),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double itemWidth =
                  (constraints.maxWidth - TerminalSpace.sm * 2) / 3;
              return Wrap(
                spacing: TerminalSpace.sm,
                runSpacing: TerminalSpace.sm,
                children: <Widget>[
                  for (final AppAccentColor color in AppAccentColor.values)
                    SizedBox(
                      width: itemWidth,
                      child: _AccessAccentChoice(
                        color: color,
                        displayColor: _displayColor(color, tokens),
                        selected: color == selected,
                        enabled: enabled,
                        onTap: () => onSelected(color),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Color _displayColor(AppAccentColor color, AppThemeTokens tokens) =>
      switch (color) {
        AppAccentColor.yellow => tokens.valueYellow,
        AppAccentColor.red => tokens.terminalRed,
        AppAccentColor.gray => tokens.textSecondary,
      };
}

class _AccessAccentChoice extends StatelessWidget {
  const _AccessAccentChoice({
    required this.color,
    required this.displayColor,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final AppAccentColor color;
  final Color displayColor;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Color ${color.label}',
    selected: selected,
    enabled: enabled,
    button: true,
    excludeSemantics: true,
    child: TerminalCard(
      key: ValueKey<String>('access-accent-${color.name}'),
      onTap: enabled ? onTap : null,
      borderColor: selected ? displayColor : null,
      padding: const EdgeInsets.symmetric(
        horizontal: TerminalSpace.xs,
        vertical: TerminalSpace.sm,
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: displayColor.withValues(alpha: 0.18),
              border: Border.all(color: displayColor, width: 1.5),
            ),
            child: selected
                ? Icon(Icons.check, color: displayColor, size: 18)
                : null,
          ),
          const SizedBox(height: TerminalSpace.xs),
          Text(
            color.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: displayColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}
