import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../shared/adaptive/shell_chrome.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../contacts/application/contact_providers.dart';
import '../../contacts/presentation/contact_pages.dart';
import '../../journal/presentation/journal_timeline_page.dart';
import '../../missions/application/mission_providers.dart';
import '../../missions/domain/models/mission.dart';
import '../../progress/application/progress_providers.dart';
import '../../progress/domain/models/progress_models.dart';
import '../../progress/domain/models/rpg_level.dart';
import '../../shop/presentation/animated_balance.dart';
import '../../shop/presentation/shop_pages.dart';
import 'character_hexagon.dart';

/// Pestañas del menú tipo juego (ADR-006 D6). TIENDA ocupa desde D17 el sitio
/// de CIBERWARE e INVENTARIO, retiradas.
enum CharacterTab {
  tienda('tienda', 'Tienda'),
  personaje('personaje', 'Personaje'),
  diario('diario', 'Diario');

  const CharacterTab(this.query, this.label);

  final String query;
  final String label;

  /// Abre en PERSONAJE salvo que la ruta pida otra (`?tab=diario`).
  static CharacterTab fromQuery(String? value) =>
      CharacterTab.values.firstWhere(
        (CharacterTab tab) => tab.query == value,
        orElse: () => CharacterTab.personaje,
      );
}

/// Menú Personaje (ADR-006 D6 y D17): cabecera con nivel, reputación y saldo,
/// y las pestañas TIENDA, PERSONAJE y DIARIO (MAPA descartado, D18).
class CharacterMenuPage extends ConsumerStatefulWidget {
  const CharacterMenuPage({
    super.key,
    this.initialTab = CharacterTab.personaje,
  });

  final CharacterTab initialTab;

  @override
  ConsumerState<CharacterMenuPage> createState() => _CharacterMenuPageState();
}

class _CharacterMenuPageState extends ConsumerState<CharacterMenuPage> {
  late CharacterTab _tab = widget.initialTab;

  @override
  void didUpdateWidget(CharacterMenuPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _tab = widget.initialTab;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _MenuHeader(
          selected: _tab,
          onSelected: (CharacterTab tab) => setState(() => _tab = tab),
        ),
        Divider(height: 1, thickness: 1, color: tokens.terminalRed),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey<CharacterTab>(_tab),
            child: switch (_tab) {
              CharacterTab.tienda => const ShopSection(),
              CharacterTab.personaje => const _CharacterSheet(),
              CharacterTab.diario => const _DiaryView(),
            },
          ),
        ),
      ],
    );
  }
}

class _MenuHeader extends ConsumerWidget {
  const _MenuHeader({required this.selected, required this.onSelected});

  final CharacterTab selected;
  final ValueChanged<CharacterTab> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final RpgLevel? level = ref.watch(overallProgressProvider).value?.rpgLevel;

    final Widget stats = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // ☰ de la barra lateral: esta cabecera sustituye a la de la app.
        const SidebarToggleButton(),
        _HeaderStat(
          key: const Key('character-level'),
          value: level == null ? '--' : '${level.level}',
          label: 'NIVEL',
          color: tokens.infoCyan,
        ),
        const SizedBox(width: TerminalSpace.lg),
        // ADR-006 D11: la reputación se calcula en la fase 3.
        _HeaderStat(
          key: const Key('character-reputation'),
          value: '--',
          label: 'REPUTACIÓN',
          color: tokens.textSecondary,
          tooltip: 'La reputación llega en la fase 3.',
        ),
      ],
    );
    final Widget money = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const HeaderClock(),
        const SizedBox(width: TerminalSpace.sm),
        const HeaderSeparator(),
        const SizedBox(width: TerminalSpace.sm),
        Tooltip(
          message: 'Saldo disponible de Economía',
          child: const AnimatedBalance(),
        ),
      ],
    );
    final Widget tabs = _TabStrip(selected: selected, onSelected: onSelected);

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TerminalSpace.lg,
          TerminalSpace.sm,
          TerminalSpace.lg,
          0,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: stats,
                        ),
                      ),
                      const SizedBox(width: TerminalSpace.sm),
                      money,
                    ],
                  ),
                  const SizedBox(height: TerminalSpace.xs),
                  tabs,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: TerminalSpace.sm),
                  child: stats,
                ),
                Expanded(child: Center(child: tabs)),
                Padding(
                  padding: const EdgeInsets.only(bottom: TerminalSpace.sm),
                  child: money,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.value,
    required this.label,
    required this.color,
    super.key,
    this.tooltip,
  });

  final String value;
  final String label;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            fontFamily: 'JetBrains Mono',
          ),
        ),
        const SizedBox(width: TerminalSpace.xxs),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
    return tooltip == null
        ? content
        : Tooltip(message: tooltip!, child: content);
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.selected, required this.onSelected});

  final CharacterTab selected;
  final ValueChanged<CharacterTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final CharacterTab tab in CharacterTab.values)
            Semantics(
              selected: tab == selected,
              button: true,
              child: InkWell(
                key: ValueKey<String>('character-tab-${tab.query}'),
                onTap: () => onSelected(tab),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: tab == selected
                            ? tokens.infoCyan
                            : tokens.structuralRed,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    tab.label.toUpperCase(),
                    style: TextStyle(
                      color: tab == selected
                          ? tokens.infoCyan
                          : tokens.terminalRed,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// PERSONAJE: el hexágono de áreas y el panel lateral (ADR-006 D3).
class _CharacterSheet extends ConsumerWidget {
  const _CharacterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<OverallProgressViewData> progress = ref.watch(
      overallProgressProvider,
    );
    final AsyncValue<List<MissionArea>> areas = ref.watch(missionAreasProvider);
    if (progress.hasError || areas.hasError) {
      return ListView(
        padding: TerminalSpace.pageTablet,
        children: <Widget>[
          TerminalErrorState(
            title: 'No se pudo leer tu progreso',
            description: 'Reintenta la lectura desde la base local cifrada.',
            onRetry: () {
              ref.invalidate(overallProgressProvider);
              ref.invalidate(missionAreasProvider);
            },
          ),
        ],
      );
    }
    final OverallProgressViewData? data = progress.value;
    final List<MissionArea>? visibleAreas = areas.value;
    if (data == null || visibleAreas == null) {
      return const TerminalLoadingState(message: 'Cargando tu personaje…');
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 980;
        final Widget hexagon = _AreasHexagon(
          data: data,
          visibleAreas: visibleAreas,
        );
        final Widget panel = _SidePanel(data: data);
        return ListView(
          padding: constraints.maxWidth < 700
              ? TerminalSpace.pageCompact
              : TerminalSpace.pageTablet,
          children: <Widget>[
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: hexagon,
                      ),
                    ),
                  ),
                  const SizedBox(width: TerminalSpace.lg),
                  SizedBox(width: 300, child: panel),
                ],
              )
            else ...<Widget>[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: hexagon,
                ),
              ),
              const SizedBox(height: TerminalSpace.lg),
              panel,
            ],
          ],
        );
      },
    );
  }
}

class _AreasHexagon extends StatelessWidget {
  const _AreasHexagon({required this.data, required this.visibleAreas});

  final OverallProgressViewData data;
  final List<MissionArea> visibleAreas;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final Map<String, AreaProgressItem> byArea = <String, AreaProgressItem>{
      for (final AreaProgressItem item in data.areaBreakdown) item.areaId: item,
    };
    // Todas las áreas visibles, en su orden; las que aún no tienen XP salen
    // en nivel 1.
    final List<HexagonArea> areas = <HexagonArea>[
      for (final MissionArea area in visibleAreas)
        () {
          final RpgLevel level =
              byArea[area.id]?.rpgLevel ?? RpgLevel.fromTotalXp(0);
          return HexagonArea(
            name: area.name,
            level: level.level,
            progress: level.progressRatio,
          );
        }(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CharacterHexagon(
          key: const Key('character-hexagon'),
          globalLevel: data.rpgLevel.level,
          areas: areas,
          cyan: tokens.infoCyan,
          red: tokens.terminalRed,
          structuralRed: tokens.structuralRed,
          yellow: tokens.valueYellow,
          track: tokens.surfaceHigh,
          text: tokens.textPrimary,
        ),
        if (areas.length > CharacterHexagon.maxAreas)
          Text(
            'Se muestran las primeras ${CharacterHexagon.maxAreas} áreas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
        const SizedBox(height: TerminalSpace.xs),
        Text(
          'Las áreas suben solas con el XP de sus misiones.',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.data});

  final OverallProgressViewData data;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final RpgLevel level = data.rpgLevel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PanelCard(
          title: 'Nivel ${level.level} → ${level.level + 1}',
          children: <Widget>[
            _PanelRow(
              label: '${level.currentLevelXp} / ${level.levelSpan} XP',
              value: '${level.progressPercentage}%',
            ),
            const SizedBox(height: TerminalSpace.xs),
            TerminalProgress(
              value: level.progressRatio,
              color: tokens.valueYellow,
            ),
          ],
        ),
        const SizedBox(height: TerminalSpace.sm),
        _PanelCard(
          title: 'Reputación',
          children: <Widget>[
            Text(
              'Contará las misiones cumplidas antes de su fecha límite. '
              'Llega en la fase 3.',
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: TerminalSpace.sm),
        _PanelCard(
          title: 'Constancia',
          children: <Widget>[
            _PanelRow(label: 'Racha actual', value: _days(data.currentStreak)),
            _PanelRow(label: 'Mejor racha', value: _days(data.bestStreak)),
            _PanelRow(label: 'XP total', value: '${data.totalXp}'),
          ],
        ),
        const SizedBox(height: TerminalSpace.sm),
        _PanelCard(
          title: 'Títulos',
          children: data.activeTitles.isEmpty
              ? <Widget>[
                  Text(
                    'Sin títulos activos todavía.',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                  ),
                ]
              : <Widget>[
                  for (final TitleProgressItem title in data.activeTitles)
                    _PanelRow(
                      label: title.name,
                      value: title.bestStreak > 0
                          ? _days(title.bestStreak)
                          : '',
                    ),
                ],
        ),
      ],
    );
  }

  static String _days(int value) => value == 1 ? '1 día' : '$value días';
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      padding: const EdgeInsets.all(TerminalSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: tokens.terminalRed,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: TerminalSpace.xs),
          ...children,
        ],
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              color: tokens.valueYellow,
              fontFamily: 'JetBrains Mono',
            ),
          ),
        ],
      ),
    );
  }
}

/// DIARIO = la Bitácora con otro nombre (ADR-006 D7), más los personajes.
class _DiaryView extends ConsumerStatefulWidget {
  const _DiaryView();

  @override
  ConsumerState<_DiaryView> createState() => _DiaryViewState();
}

class _DiaryViewState extends ConsumerState<_DiaryView> {
  bool _showContacts = false;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final int? contactCount = ref.watch(activeContactsProvider).value?.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TerminalSpace.lg,
            TerminalSpace.md,
            TerminalSpace.lg,
            0,
          ),
          child: Wrap(
            spacing: TerminalSpace.xs,
            children: <Widget>[
              _ModeButton(
                key: const Key('diary-mode-entries'),
                label: 'ENTRADAS',
                selected: !_showContacts,
                color: tokens.infoCyan,
                onPressed: () => setState(() => _showContacts = false),
              ),
              _ModeButton(
                key: const Key('diary-mode-contacts'),
                label: contactCount == null
                    ? 'PERSONAJES'
                    : 'PERSONAJES · $contactCount',
                selected: _showContacts,
                color: tokens.infoCyan,
                onPressed: () => setState(() => _showContacts = true),
              ),
            ],
          ),
        ),
        Expanded(
          child: _showContacts
              ? ListView(
                  padding: TerminalSpace.pageTablet,
                  children: const <Widget>[ContactsSection()],
                )
              : const JournalTimelinePage(title: 'Diario'),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? color : tokens.textSecondary,
          side: BorderSide(color: selected ? color : tokens.border),
          minimumSize: const Size(48, 44),
          textStyle: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
