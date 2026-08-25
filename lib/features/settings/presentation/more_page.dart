import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: <Widget>[
      Text('Más', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Text(
        'Contenedor compacto para destinos que permanecen visibles en tablet.',
      ),
      const SizedBox(height: 24),
      Card(
        child: ListTile(
          minTileHeight: 64,
          leading: const Icon(Icons.query_stats),
          title: const Text('Dashboard y progreso'),
          subtitle: const Text('Patrones diarios, semanales, XP y niveles.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(AppRoutes.dashboardDaily),
        ),
      ),
      Card(
        child: ListTile(
          minTileHeight: 64,
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Ajustes'),
          subtitle: const Text('Privacidad, datos, apariencia y reglas.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(AppRoutes.settings),
        ),
      ),
    ],
  );
}
