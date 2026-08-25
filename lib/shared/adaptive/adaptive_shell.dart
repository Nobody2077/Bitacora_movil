import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import '../../app/theme/app_theme_tokens.dart';
import 'app_breakpoints.dart';

class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    required this.location,
    required this.navigationShell,
    super.key,
  });

  final String location;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      if (constraints.maxWidth < AppBreakpoints.compact) {
        return _CompactShell(
          location: location,
          navigationShell: navigationShell,
        );
      }

      if (location == AppRoutes.more) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go(AppRoutes.dashboardDaily);
          }
        });
      }

      return _RailShell(
        location: location,
        navigationShell: navigationShell,
        extended: constraints.maxWidth >= AppBreakpoints.expanded,
      );
    },
  );
}

class _CompactShell extends StatelessWidget {
  const _CompactShell({required this.location, required this.navigationShell});

  final String location;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_sectionTitle(location))),
    body: navigationShell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: _compactIndex(location),
      onDestinationSelected: (int index) {
        if (index == 4) {
          navigationShell.goBranch(6, initialLocation: true);
          return;
        }
        navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        );
      },
      destinations: const <NavigationDestination>[
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
        NavigationDestination(
          icon: Icon(Icons.flag_outlined),
          label: 'Misiones',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          label: 'Bitácora',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          label: 'Economía',
        ),
        NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Más'),
      ],
    ),
  );
}

class _RailShell extends StatelessWidget {
  const _RailShell({
    required this.location,
    required this.navigationShell,
    required this.extended,
  });

  final String location;
  final StatefulNavigationShell navigationShell;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;

    return Scaffold(
      body: Row(
        children: <Widget>[
          NavigationRail(
            extended: extended,
            selectedIndex: _railIndex(location),
            onDestinationSelected: (int index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Icon(Icons.terminal, color: tokens.terminalRed, size: 30),
            ),
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                label: Text('Inicio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.flag_outlined),
                label: Text('Misiones'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.menu_book_outlined),
                label: Text('Bitácora'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                label: Text('Economía'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.query_stats),
                label: Text('Progreso'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                label: Text('Ajustes'),
              ),
            ],
          ),
          VerticalDivider(width: 1, color: tokens.border),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

int _compactIndex(String location) {
  if (location.startsWith('/missions') ||
      location.startsWith('/mission-templates')) {
    return 1;
  }
  if (location.startsWith('/journal')) {
    return 2;
  }
  if (location.startsWith('/finance')) {
    return 3;
  }
  if (location.startsWith('/dashboard') ||
      location.startsWith('/settings') ||
      location == AppRoutes.more) {
    return 4;
  }
  return 0;
}

int _railIndex(String location) {
  if (location.startsWith('/missions') ||
      location.startsWith('/mission-templates')) {
    return 1;
  }
  if (location.startsWith('/journal')) {
    return 2;
  }
  if (location.startsWith('/finance')) {
    return 3;
  }
  if (location.startsWith('/dashboard') || location == AppRoutes.more) {
    return 4;
  }
  if (location.startsWith('/settings')) {
    return 5;
  }
  return 0;
}

String _sectionTitle(String location) {
  switch (_compactIndex(location)) {
    case 1:
      return 'Misiones';
    case 2:
      return 'Bitácora';
    case 3:
      return 'Economía';
    case 4:
      return 'Más';
    default:
      return 'Inicio';
  }
}
