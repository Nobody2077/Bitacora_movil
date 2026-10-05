import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';
import '../../app/theme/terminal_foundations.dart';
import '../widgets/terminal/terminal_widgets.dart';

/// Cabecera técnica persistente del shell de tablet.
///
/// Mantiene el contexto de la aplicación visible sin depender de cada módulo.
class TerminalApplicationHeader extends StatefulWidget {
  const TerminalApplicationHeader({
    required this.location,
    super.key,
    this.sidebarVisible = true,
    this.onToggleSidebar,
  });

  final String location;

  /// Estado de la barra lateral, para el texto del botón ☰ (ADR-006 D13).
  final bool sidebarVisible;

  /// Sin él no se muestra el botón ☰.
  final VoidCallback? onToggleSidebar;

  @override
  State<TerminalApplicationHeader> createState() =>
      _TerminalApplicationHeaderState();
}

class _TerminalApplicationHeaderState extends State<TerminalApplicationHeader> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
              TerminalSpace.lg,
              TerminalSpace.md,
              TerminalSpace.lg,
              TerminalSpace.sm,
            ),
            child: Row(
              children: <Widget>[
                if (widget.onToggleSidebar != null) ...<Widget>[
                  IconButton(
                    key: const Key('sidebar-toggle'),
                    tooltip: widget.sidebarVisible
                        ? 'Ocultar barra lateral'
                        : 'Mostrar barra lateral',
                    onPressed: widget.onToggleSidebar,
                    color: tokens.terminalRed,
                    icon: Icon(
                      widget.sidebarVisible ? Icons.menu_open : Icons.menu,
                    ),
                  ),
                  const SizedBox(width: TerminalSpace.xs),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'BITÁCORA RPG PERSONAL',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: tokens.terminalRed,
                              letterSpacing: 0.8,
                            ),
                      ),
                      const SizedBox(height: TerminalSpace.xxs),
                      TerminalLabel(
                        'Datos locales · ${_locationLabel(widget.location)}',
                        color: tokens.textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: TerminalSpace.md),
                _LocalStatus(now: _now),
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

class _LocalStatus extends StatelessWidget {
  const _LocalStatus({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final String time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    final String date =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.terminal, color: tokens.terminalRed, size: 18),
        const SizedBox(width: TerminalSpace.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            TerminalLabel('Terminal local', color: tokens.terminalRed),
            Text(
              time,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: tokens.infoCyan,
                fontFamily: 'JetBrains Mono',
              ),
            ),
            TerminalLabel(date, color: tokens.textSecondary),
          ],
        ),
      ],
    );
  }
}

String _locationLabel(String location) {
  if (location.startsWith('/missions')) return 'Centro de misiones';
  if (location.startsWith('/journal')) return 'Bitácora';
  if (location.startsWith('/character')) return 'Personaje';
  if (location.startsWith('/finance')) return 'Economía';
  if (location.startsWith('/dashboard')) return 'Progreso';
  if (location.startsWith('/settings')) return 'Ajustes';
  return 'Centro de operaciones';
}
