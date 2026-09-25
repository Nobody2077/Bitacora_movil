import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';

/// Tarjeta de ajuste con interruptor, compartida por Apariencia y Sonido.
class PreferenceSwitchCard extends StatelessWidget {
  const PreferenceSwitchCard({
    required this.switchKey,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
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
