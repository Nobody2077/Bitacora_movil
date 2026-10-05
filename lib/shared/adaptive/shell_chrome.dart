import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';

/// Lo que el shell de tablet ofrece a las cabeceras: el ☰ de la barra
/// lateral (ADR-006 D13). Sin él (teléfono o pruebas aisladas) no hay ☰.
class ShellChrome extends InheritedWidget {
  const ShellChrome({
    required this.sidebarVisible,
    required this.onToggleSidebar,
    required super.child,
    super.key,
  });

  final bool sidebarVisible;
  final VoidCallback onToggleSidebar;

  static ShellChrome? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellChrome>();

  @override
  // La acción del ☰ es siempre la misma; solo importa si está visible.
  bool updateShouldNotify(ShellChrome oldWidget) =>
      sidebarVisible != oldWidget.sidebarVisible;
}

/// El ☰ que esconde o muestra la barra lateral.
class SidebarToggleButton extends StatelessWidget {
  const SidebarToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final ShellChrome? chrome = ShellChrome.maybeOf(context);
    if (chrome == null) {
      return const SizedBox.shrink();
    }
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return IconButton(
      key: const Key('sidebar-toggle'),
      tooltip: chrome.sidebarVisible
          ? 'Ocultar barra lateral'
          : 'Mostrar barra lateral',
      onPressed: chrome.onToggleSidebar,
      color: tokens.terminalRed,
      icon: Icon(chrome.sidebarVisible ? Icons.menu_open : Icons.menu),
    );
  }
}

/// Hora local en 24 horas, junto al saldo. Se actualiza cada minuto.
class HeaderClock extends StatefulWidget {
  const HeaderClock({super.key});

  @override
  State<HeaderClock> createState() => _HeaderClockState();
}

class _HeaderClockState extends State<HeaderClock> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
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
    return Text(
      '${_now.hour.toString().padLeft(2, '0')}:'
      '${_now.minute.toString().padLeft(2, '0')}',
      key: const Key('header-clock'),
      style: TextStyle(
        color: tokens.infoCyan,
        fontFamily: 'JetBrains Mono',
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Separador fino entre la hora y el saldo.
class HeaderSeparator extends StatelessWidget {
  const HeaderSeparator({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 22,
    child: VerticalDivider(
      width: 1,
      thickness: 1,
      color: Theme.of(context).extension<AppThemeTokens>()!.structuralRed,
    ),
  );
}
