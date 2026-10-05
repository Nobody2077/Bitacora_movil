import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../economy/presentation/economy_presentation_support.dart';
import '../../missions/domain/models/mission.dart';
import '../../missions/presentation/mission_presentation_support.dart';
import '../domain/models/wish.dart';
import '../domain/models/wish_affordability.dart';

/// Icono de cada tipo, de los Material Icons que ya trae Flutter (D17).
IconData wishKindIcon(WishKind kind) => switch (kind) {
  WishKind.technology => Icons.devices_outlined,
  WishKind.clothing => Icons.checkroom_outlined,
  WishKind.accessory => Icons.watch_outlined,
  WishKind.book => Icons.menu_book_outlined,
  WishKind.part => Icons.build_outlined,
  WishKind.home => Icons.chair_outlined,
  WishKind.other => Icons.category_outlined,
};

String wishKindLabel(WishKind kind) => switch (kind) {
  WishKind.technology => 'Tecnología',
  WishKind.clothing => 'Ropa',
  WishKind.accessory => 'Accesorio',
  WishKind.book => 'Libro',
  WishKind.part => 'Pieza',
  WishKind.home => 'Hogar',
  WishKind.other => 'Otro',
};

String wishPriorityLabel(WishPriority priority) => switch (priority) {
  WishPriority.high => 'Prioridad alta',
  WishPriority.medium => 'Prioridad media',
  WishPriority.low => 'Prioridad baja',
};

Color wishPriorityColor(AppThemeTokens tokens, WishPriority priority) =>
    switch (priority) {
      WishPriority.high => tokens.attentionOrange,
      WishPriority.medium => tokens.infoCyan,
      WishPriority.low => tokens.textSecondary,
    };

/// Color de la ficha según el saldo (D17). Siempre va con
/// [wishAffordabilityLabel]: el color nunca informa solo.
Color wishAffordabilityColor(
  AppThemeTokens tokens,
  WishAffordabilityLevel level,
) => switch (level) {
  WishAffordabilityLevel.affordable => tokens.progressGreen,
  WishAffordabilityLevel.close => tokens.valueYellow,
  WishAffordabilityLevel.far => tokens.terminalRed,
  WishAffordabilityLevel.unpriced => tokens.textSecondary,
};

/// «Te alcanza», «Faltan Bs 120,00» o «Sin precio». Con los importes
/// ocultos, la cifra sale tapada pero la frase se mantiene.
String wishAffordabilityLabel(
  BuildContext context,
  WishAffordability affordability,
) => switch (affordability.level) {
  WishAffordabilityLevel.affordable => 'Te alcanza',
  WishAffordabilityLevel.close || WishAffordabilityLevel.far =>
    'Faltan ${economyMoney(context, affordability.missingMinor).trim()}',
  WishAffordabilityLevel.unpriced => 'Sin precio',
};

MissionArea? wishAreaOf(Wish wish, List<MissionArea>? areas) {
  if (wish.areaId == null || areas == null) return null;
  for (final MissionArea area in areas) {
    if (area.id == wish.areaId) return area;
  }
  return null;
}

/// Tarjeta de un deseo para las listas de la Tienda.
class WishCard extends StatelessWidget {
  const WishCard({
    required this.wish,
    required this.areas,
    required this.availableMinor,
    required this.onTap,
    super.key,
    this.trailing,
  });

  final Wish wish;
  final List<MissionArea>? areas;

  /// Saldo disponible; nulo mientras carga o si el deseo ya está comprado.
  final int? availableMinor;
  final VoidCallback onTap;

  /// Sustituye al precio y al estado (por ejemplo, en Comprados).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final WishAffordability? affordability = availableMinor == null
        ? null
        : WishAffordability.evaluate(
            priceMinor: wish.priceMinor,
            availableMinor: availableMinor!,
          );
    final Color accent = affordability == null
        ? tokens.border
        : wishAffordabilityColor(tokens, affordability.level);
    final MissionArea? area = wishAreaOf(wish, areas);
    return TerminalCard(
      key: ValueKey<String>('wish-card-${wish.id}'),
      onTap: onTap,
      borderColor: accent,
      padding: const EdgeInsets.all(TerminalSpace.md),
      child: Row(
        children: <Widget>[
          Icon(wishKindIcon(wish.kind), size: 32, color: accent),
          const SizedBox(width: TerminalSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  wish.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: TerminalSpace.xxs),
                Wrap(
                  spacing: TerminalSpace.xs,
                  runSpacing: TerminalSpace.xxs,
                  children: <Widget>[
                    if (area != null)
                      TerminalBadge(
                        label: area.name,
                        color: missionAreaColor(area.colorHex, tokens.infoCyan),
                      ),
                    if (wish.priority != null)
                      TerminalBadge(
                        label: wishPriorityLabel(wish.priority!),
                        color: wishPriorityColor(tokens, wish.priority!),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: TerminalSpace.sm),
          trailing ??
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (wish.priceMinor != null)
                    Text(
                      economyMoney(context, wish.priceMinor!).trim(),
                      style: TextStyle(
                        color: tokens.valueYellow,
                        fontFamily: 'JetBrains Mono',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (affordability != null) ...<Widget>[
                    const SizedBox(height: TerminalSpace.xxs),
                    Text(
                      wishAffordabilityLabel(context, affordability),
                      key: ValueKey<String>('wish-affordability-${wish.id}'),
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
        ],
      ),
    );
  }
}
