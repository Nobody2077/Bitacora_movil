import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return ListView(
      padding: TerminalSpace.pageTablet,
      children: <Widget>[
        const TerminalPageHeader(
          title: 'Más',
          subtitle: 'Destinos de administración y análisis',
        ),
        const SizedBox(height: TerminalSpace.xl),
        _MoreDestination(
          icon: Icons.hexagon_outlined,
          title: 'Personaje',
          description: 'Tus áreas de vida, el Diario y sus personajes.',
          color: tokens.infoCyan,
          onTap: () => context.go(AppRoutes.character),
        ),
        const SizedBox(height: TerminalSpace.sm),
        _MoreDestination(
          icon: Icons.query_stats,
          title: 'Dashboard y progreso',
          description: 'Patrones diarios, semanales, XP y niveles.',
          color: tokens.infoCyan,
          onTap: () => context.go(AppRoutes.dashboardDaily),
        ),
        const SizedBox(height: TerminalSpace.sm),
        _MoreDestination(
          icon: Icons.settings_outlined,
          title: 'Ajustes',
          description: 'Privacidad, datos, apariencia y reglas.',
          color: tokens.valueYellow,
          onTap: () => context.go(AppRoutes.settings),
        ),
      ],
    );
  }
}

class _MoreDestination extends StatelessWidget {
  const _MoreDestination({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TerminalCard(
    onTap: onTap,
    padding: const EdgeInsets.all(TerminalSpace.md),
    child: Row(
      children: <Widget>[
        Icon(icon, color: color, size: 30),
        const SizedBox(width: TerminalSpace.md),
        Expanded(
          child: TerminalSectionTitle(title: title, description: description),
        ),
        const SizedBox(width: TerminalSpace.sm),
        Icon(Icons.chevron_right, color: color),
      ],
    ),
  );
}
