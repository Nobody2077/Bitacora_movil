import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';
import '../../app/theme/terminal_foundations.dart';
import '../widgets/terminal/terminal_widgets.dart';

/// Navegación persistente para superficies de tablet y escritorio.
///
/// No conoce rutas: el shell conserva esa responsabilidad y solamente recibe
/// el índice seleccionado y el evento de selección.
class TerminalSidebar extends StatelessWidget {
  const TerminalSidebar({
    required this.selectedIndex,
    required this.onSelected,
    required this.extended,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool extended;

  static const List<_TerminalNavigationItem> _items = <_TerminalNavigationItem>[
    _TerminalNavigationItem('Inicio', Icons.home_outlined),
    _TerminalNavigationItem('Misiones', Icons.flag_outlined),
    _TerminalNavigationItem('Bitácora', Icons.menu_book_outlined),
    _TerminalNavigationItem('Economía', Icons.account_balance_wallet_outlined),
    _TerminalNavigationItem('Progreso', Icons.query_stats),
    _TerminalNavigationItem('Ajustes', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final double width = extended ? 248 : 84;
    return Material(
      color: tokens.surfaceLow,
      child: SizedBox(
        width: width,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TerminalSpace.md,
                  TerminalSpace.lg,
                  TerminalSpace.md,
                  TerminalSpace.md,
                ),
                child: _TerminalBrand(extended: extended),
              ),
              TerminalDivider(
                indent: TerminalSpace.sm,
                endIndent: TerminalSpace.sm,
              ),
              const SizedBox(height: TerminalSpace.sm),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TerminalSpace.sm,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (BuildContext context, int index) {
                    final _TerminalNavigationItem item = _items[index];
                    return _SidebarDestination(
                      item: item,
                      extended: extended,
                      selected: index == selectedIndex,
                      onTap: () => onSelected(index),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(TerminalSpace.md),
                child: TerminalLabel(
                  extended ? 'BITÁCORA · V2' : 'V2',
                  color: tokens.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TerminalBrand extends StatelessWidget {
  const _TerminalBrand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Row(
      mainAxisAlignment: extended
          ? MainAxisAlignment.start
          : MainAxisAlignment.center,
      children: <Widget>[
        DecoratedBox(
          decoration: ShapeDecoration(
            color: tokens.terminalRed.withValues(alpha: 0.12),
            shape: TerminalCutCornerBorder(
              cut: 7,
              side: BorderSide(color: tokens.terminalRed),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(TerminalSpace.xs),
            child: Icon(Icons.terminal, color: tokens.terminalRed, size: 22),
          ),
        ),
        if (extended) ...<Widget>[
          const SizedBox(width: TerminalSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'BITÁCORA',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TerminalLabel('SISTEMA PERSONAL', color: tokens.infoCyan),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.item,
    required this.extended,
    required this.selected,
    required this.onTap,
  });

  final _TerminalNavigationItem item;
  final bool extended;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final Color foreground = selected ? tokens.infoCyan : tokens.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Padding(
        padding: const EdgeInsets.only(bottom: TerminalSpace.xs),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: AnimatedContainer(
              duration: TerminalMotion.standard,
              curve: Curves.easeOut,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? tokens.structuralRed.withValues(alpha: 0.5)
                    : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: selected ? tokens.terminalRed : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: extended ? TerminalSpace.sm : 0,
                ),
                child: Row(
                  mainAxisAlignment: extended
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(item.icon, color: foreground, size: 22),
                    if (extended) ...<Widget>[
                      const SizedBox(width: TerminalSpace.sm),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: foreground),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TerminalNavigationItem {
  const _TerminalNavigationItem(this.label, this.icon);

  final String label;
  final IconData icon;
}
