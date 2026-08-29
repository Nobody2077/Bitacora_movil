import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';
import '../../app/theme/terminal_foundations.dart';
import '../../features/progress/domain/models/rpg_level.dart';
import '../widgets/terminal/terminal_widgets.dart';

final class SidebarMissionVitals {
  const SidebarMissionVitals({
    required this.healthCompleted,
    required this.healthTotal,
  });

  final int healthCompleted;
  final int healthTotal;
  double? get healthRatio =>
      healthTotal == 0 ? null : (healthCompleted / healthTotal).clamp(0.0, 1.0);
}

/// Navegación persistente para superficies de tablet y escritorio.
///
/// No conoce rutas: el shell conserva esa responsabilidad y solamente recibe
/// el índice seleccionado y el evento de selección.
class TerminalSidebar extends StatelessWidget {
  const TerminalSidebar({
    required this.selectedIndex,
    required this.onSelected,
    required this.extended,
    required this.displayName,
    required this.avatarPath,
    required this.onProfilePressed,
    super.key,
    this.globalLevel,
    this.missionVitals,
    this.batteryLevel,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool extended;
  final String displayName;
  final String? avatarPath;
  final RpgLevel? globalLevel;
  final SidebarMissionVitals? missionVitals;
  final int? batteryLevel;
  final VoidCallback onProfilePressed;

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
                child: _TerminalProfileHeader(
                  extended: extended,
                  displayName: displayName,
                  avatarPath: avatarPath,
                  missionVitals: missionVitals,
                  batteryLevel: batteryLevel,
                  onPressed: onProfilePressed,
                ),
              ),
              TerminalDivider(
                key: const ValueKey<String>('sidebar-profile-divider'),
                indent: TerminalSpace.sm,
                endIndent: TerminalSpace.sm,
                color: tokens.structuralRed,
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
              if (extended)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TerminalSpace.sm,
                    TerminalSpace.xs,
                    TerminalSpace.sm,
                    0,
                  ),
                  child: _GlobalLevelPanel(level: globalLevel),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalLevelPanel extends StatelessWidget {
  const _GlobalLevelPanel({required this.level});

  final RpgLevel? level;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final String levelLabel = level == null
        ? '--'
        : level!.level.toString().padLeft(2, '0');
    final String xpLabel = level == null
        ? '-- / --'
        : '${level!.currentLevelXp} / ${level!.levelSpan}';
    final String percentageLabel = level == null
        ? '--%'
        : '${level!.progressPercentage}%';

    return TerminalPanel(
      key: const ValueKey<String>('sidebar-global-level-panel'),
      padding: const EdgeInsets.all(TerminalSpace.sm),
      borderColor: tokens.structuralRed,
      backgroundColor: Colors.black,
      cut: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'NIVEL GLOBAL',
                style: TextStyle(
                  color: tokens.terminalRed,
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: TerminalSpace.xs),
              Text(
                levelLabel,
                key: const ValueKey<String>('sidebar-global-level-value'),
                style: TextStyle(
                  color: tokens.infoCyan,
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: TerminalSpace.sm),
          Row(
            children: <Widget>[
              Text(
                'XP',
                style: TextStyle(
                  color: tokens.infoCyan,
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: TerminalSpace.xs),
              Expanded(
                child: Text(
                  xpLabel,
                  key: const ValueKey<String>('sidebar-global-xp-value'),
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TerminalSpace.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  height: 10,
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: tokens.border),
                  ),
                  child: LinearProgressIndicator(
                    key: const ValueKey<String>(
                      'sidebar-global-level-progress',
                    ),
                    value: level?.progressRatio ?? 0,
                    backgroundColor: Colors.black,
                    valueColor: AlwaysStoppedAnimation<Color>(tokens.infoCyan),
                  ),
                ),
              ),
              const SizedBox(width: TerminalSpace.xs),
              SizedBox(
                width: 34,
                child: Text(
                  percentageLabel,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: tokens.infoCyan,
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TerminalProfileHeader extends StatelessWidget {
  const _TerminalProfileHeader({
    required this.extended,
    required this.displayName,
    required this.avatarPath,
    required this.missionVitals,
    required this.batteryLevel,
    required this.onPressed,
  });

  final bool extended;
  final String displayName;
  final String? avatarPath;
  final SidebarMissionVitals? missionVitals;
  final int? batteryLevel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final String? usableAvatarPath =
        avatarPath != null &&
            avatarPath!.trim().isNotEmpty &&
            File(avatarPath!).existsSync()
        ? avatarPath
        : null;
    final String initial = displayName.trim().isEmpty
        ? 'U'
        : displayName.trim().characters.first.toUpperCase();
    return Tooltip(
      message: 'Editar nombre y foto',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: TerminalSpace.xs),
            child: Row(
              mainAxisAlignment: extended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: <Widget>[
                CircleAvatar(
                  radius: 22,
                  backgroundColor: tokens.terminalRed.withValues(alpha: 0.14),
                  foregroundImage: usableAvatarPath == null
                      ? null
                      : FileImage(File(usableAvatarPath)),
                  child: usableAvatarPath == null
                      ? Text(
                          initial,
                          style: TextStyle(
                            color: tokens.terminalRed,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                if (extended) ...<Widget>[
                  const SizedBox(width: TerminalSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          displayName,
                          key: const ValueKey<String>('sidebar-profile-name'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: tokens.valueYellow,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                        ),
                        const SizedBox(height: TerminalSpace.xxs),
                        _ProfileHealthBar(vitals: missionVitals),
                        const SizedBox(height: TerminalSpace.xs),
                        _ModularDeviceBattery(level: batteryLevel),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHealthBar extends StatelessWidget {
  const _ProfileHealthBar({required this.vitals});

  final SidebarMissionVitals? vitals;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final double? ratio = vitals?.healthRatio;
    final String value = vitals == null || vitals!.healthTotal == 0
        ? '—'
        : '${vitals!.healthCompleted}/${vitals!.healthTotal}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Icon(
              Icons.favorite,
              key: const ValueKey<String>('sidebar-health-icon'),
              semanticLabel: 'Salud',
              color: tokens.terminalRed,
              size: 11,
            ),
            Text(
              value,
              key: const ValueKey<String>('sidebar-health-value'),
              style: TextStyle(
                color: ratio == null ? tokens.textDisabled : tokens.terminalRed,
                fontFamily: 'JetBrains Mono',
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          height: 6,
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(
              color: tokens.terminalRed.withValues(alpha: 0.65),
            ),
          ),
          child: LinearProgressIndicator(
            key: const ValueKey<String>('sidebar-health-progress'),
            value: ratio ?? 0,
            backgroundColor: Colors.black,
            valueColor: AlwaysStoppedAnimation<Color>(tokens.terminalRed),
          ),
        ),
      ],
    );
  }
}

class _ModularDeviceBattery extends StatelessWidget {
  const _ModularDeviceBattery({required this.level});

  static const int segmentCount = 20;

  final int? level;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final int? safeLevel = level?.clamp(0, 100).toInt();
    final Color color = safeLevel == null
        ? tokens.textDisabled
        : tokens.infoCyan;
    final int filledSegments = safeLevel == null
        ? 0
        : ((safeLevel / 100) * segmentCount).ceil().clamp(0, segmentCount);
    final String label = safeLevel == null
        ? 'Batería no disponible'
        : 'Batería, $safeLevel por ciento';

    return Semantics(
      label: label,
      value: safeLevel == null ? null : '$safeLevel%',
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: SizedBox(
            key: const ValueKey<String>('sidebar-device-battery'),
            height: 18,
            child: Row(
              children: List<Widget>.generate(segmentCount, (int index) {
                final bool filled = index < filledSegments;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == segmentCount - 1 ? 0 : 2,
                    ),
                    child: Container(
                      key: ValueKey<String>(
                        'sidebar-device-battery-segment-$index-'
                        '${filled ? 'filled' : 'empty'}',
                      ),
                      decoration: ShapeDecoration(
                        color: filled
                            ? color.withValues(alpha: 0.94)
                            : color.withValues(alpha: 0.035),
                        shape: TerminalCutCornerBorder(
                          cut: 2,
                          side: BorderSide(
                            color: color.withValues(
                              alpha: filled ? 0.95 : 0.28,
                            ),
                            width: filled ? 1 : 0.7,
                          ),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 2,
                          height: 2,
                          margin: const EdgeInsets.only(top: 2),
                          color: filled
                              ? Colors.black.withValues(alpha: 0.65)
                              : color.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
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
    final Color foreground = selected ? tokens.valueYellow : tokens.terminalRed;
    const BeveledRectangleBorder interactionShape = BeveledRectangleBorder(
      borderRadius: BorderRadius.only(bottomRight: Radius.circular(10)),
    );
    final BeveledRectangleBorder selectionShape = BeveledRectangleBorder(
      borderRadius: const BorderRadius.only(bottomRight: Radius.circular(10)),
      side: BorderSide(
        color: selected ? tokens.valueYellow : Colors.transparent,
        width: 1.5,
      ),
    );
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Padding(
        padding: const EdgeInsets.only(bottom: TerminalSpace.xs),
        child: Material(
          color: Colors.transparent,
          shape: interactionShape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: interactionShape,
            child: AnimatedContainer(
              key: ValueKey<String>('sidebar-destination-${item.label}'),
              duration: TerminalMotion.resolve(
                context,
                TerminalMotion.standard,
              ),
              curve: Curves.easeOut,
              height: 52,
              decoration: ShapeDecoration(
                color: selected
                    ? tokens.valueYellow.withValues(alpha: 0.08)
                    : Colors.transparent,
                shape: selectionShape,
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
                    Icon(item.icon, color: foreground, size: 24),
                    if (extended) ...<Widget>[
                      const SizedBox(width: TerminalSpace.sm),
                      Expanded(
                        child: Text(
                          item.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: foreground,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
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
