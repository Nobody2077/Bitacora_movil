import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';
import '../../app/theme/terminal_foundations.dart';
import '../../features/shop/presentation/animated_balance.dart';
import '../widgets/terminal/terminal_widgets.dart';
import 'shell_chrome.dart';

/// Barra superior del shell de tablet (opción B, elegida el 5 de octubre de
/// 2026): el ☰ a la izquierda y la hora y el saldo a la derecha. El título
/// lo pone cada pantalla; Personaje lleva su propia cabecera y no la usa.
class TerminalApplicationHeader extends StatelessWidget {
  const TerminalApplicationHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TerminalSpace.sm,
              TerminalSpace.xs,
              TerminalSpace.lg,
              TerminalSpace.xs,
            ),
            child: Row(
              children: <Widget>[
                const SidebarToggleButton(),
                const Spacer(),
                const HeaderClock(),
                const SizedBox(width: TerminalSpace.sm),
                const HeaderSeparator(),
                const SizedBox(width: TerminalSpace.sm),
                Tooltip(
                  message: 'Saldo disponible de Economía',
                  child: const AnimatedBalance(),
                ),
              ],
            ),
          ),
          TerminalDivider(
            key: const ValueKey<String>('application-header-divider'),
            indent: TerminalSpace.lg,
            endIndent: TerminalSpace.lg,
            color: tokens.structuralRed,
          ),
        ],
      ),
    );
  }
}
