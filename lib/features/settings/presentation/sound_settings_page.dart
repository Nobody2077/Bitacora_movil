import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/adaptive/app_breakpoints.dart';
import '../../../shared/sound/ui_sound.dart';
import '../../../shared/sound/ui_sound_preferences.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import 'preference_switch_card.dart';

class SoundSettingsPage extends ConsumerStatefulWidget {
  const SoundSettingsPage({super.key});

  @override
  ConsumerState<SoundSettingsPage> createState() => _SoundSettingsPageState();
}

class _SoundSettingsPageState extends ConsumerState<SoundSettingsPage> {
  bool _saving = false;

  Future<void> _save(
    UiSoundPreferences next, {
    required UiSound? preview,
  }) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    bool saved = false;
    try {
      await ref.read(uiSoundPreferenceStoreProvider).write(next);
      ref.invalidate(uiSoundPreferencesProvider);
      saved = true;
    } on Object {
      saved = false;
    }
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar el ajuste de sonido.'),
        ),
      );
      return;
    }
    // Muestra del grupo recién activado, para oír cómo suena.
    if (preview != null) {
      unawaited(ref.read(uiSoundServiceProvider).play(preview));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<UiSoundPreferences> preferences = ref.watch(
      uiSoundPreferencesProvider,
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
                      title: 'Sonido',
                      subtitle:
                          'Efectos de la aplicación. No afecta al sonido de '
                          'las notificaciones.',
                    ),
                    const SizedBox(height: TerminalSpace.lg),
                    preferences.when(
                      loading: () => const TerminalLoadingState(
                        message: 'Cargando ajustes de sonido…',
                      ),
                      error: (Object error, StackTrace stackTrace) =>
                          TerminalErrorState(
                            title: 'Sonido no disponible',
                            description:
                                'No fue posible leer los ajustes de sonido.',
                            retryButtonKey: const Key('sound-retry-button'),
                            onRetry: () =>
                                ref.invalidate(uiSoundPreferencesProvider),
                          ),
                      data: _buildPreferences,
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

  Widget _buildPreferences(UiSoundPreferences preferences) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      if (_saving) ...<Widget>[
        const LinearProgressIndicator(key: Key('sound-saving-indicator')),
        const SizedBox(height: TerminalSpace.sm),
      ],
      PreferenceSwitchCard(
        switchKey: const Key('reward-sound-switch'),
        icon: Icons.military_tech_outlined,
        title: 'Sonidos de logros',
        description:
            'Acceso concedido, misión creada, misión completada y subida de '
            'nivel.',
        value: preferences.rewardEnabled,
        enabled: !_saving,
        onChanged: (bool value) => _save(
          preferences.copyWith(rewardEnabled: value),
          preview: value ? UiSound.missionCompleted : null,
        ),
      ),
      const SizedBox(height: TerminalSpace.sm),
      PreferenceSwitchCard(
        switchKey: const Key('interface-sound-switch'),
        icon: Icons.touch_app_outlined,
        title: 'Sonidos de interfaz',
        description: 'Un clic breve al cambiar de sección en el menú.',
        value: preferences.interfaceEnabled,
        enabled: !_saving,
        onChanged: (bool value) => _save(
          preferences.copyWith(interfaceEnabled: value),
          preview: value ? UiSound.navigation : null,
        ),
      ),
      const SizedBox(height: TerminalSpace.sm),
      PreferenceSwitchCard(
        switchKey: const Key('access-sound-switch'),
        icon: Icons.dialpad,
        title: 'Sonidos de acceso',
        description:
            'Un chasquido al pulsar cada tecla del PIN (el mismo para todas), '
            'la carga de la terminal y un aviso si el PIN es incorrecto.',
        value: preferences.accessEnabled,
        enabled: !_saving,
        onChanged: (bool value) => _save(
          preferences.copyWith(accessEnabled: value),
          preview: value ? UiSound.accessKeypad : null,
        ),
      ),
      const SizedBox(height: TerminalSpace.md),
      const Text(
        'Los efectos no pausan tu música y no suenan con el teléfono en '
        'silencio o vibración. Ninguna información depende de oírlos.',
      ),
    ],
  );
}
