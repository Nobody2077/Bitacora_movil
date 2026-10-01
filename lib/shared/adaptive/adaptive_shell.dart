import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import '../../app/theme/app_theme_tokens.dart';
import '../../core/errors/app_failure.dart';
import '../../core/result/result.dart';
import '../../features/access/application/access_session_controller.dart';
import '../../features/missions/application/mission_providers.dart';
import '../../features/missions/domain/models/mission.dart';
import '../../features/missions/presentation/mission_presentation_support.dart';
import '../../features/profile/application/user_profile_providers.dart';
import '../../features/profile/domain/models/user_profile.dart';
import '../../features/profile/presentation/user_profile_edit_dialog.dart';
import '../../features/progress/application/progress_providers.dart';
import '../../features/progress/domain/models/progress_models.dart';
import '../device/device_battery.dart';
import '../sound/ui_sound.dart';
import 'app_breakpoints.dart';
import 'app_exit.dart';
import 'terminal_application_header.dart';
import 'terminal_sidebar.dart';

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

class _CompactShell extends ConsumerWidget {
  const _CompactShell({required this.location, required this.navigationShell});

  final String location;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: Text(_sectionTitle(location))),
    body: Column(
      children: <Widget>[
        Expanded(child: navigationShell),
        const _GlobalActiveTimerBar(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _compactIndex(location),
      onDestinationSelected: (int index) {
        if (index != _compactIndex(location)) {
          unawaited(ref.read(uiSoundServiceProvider).play(UiSound.navigation));
        }
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

class _RailShell extends ConsumerWidget {
  const _RailShell({
    required this.location,
    required this.navigationShell,
    required this.extended,
  });

  final String location;
  final StatefulNavigationShell navigationShell;
  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final UserProfile profile =
        ref.watch(userProfileProvider).value ??
        const UserProfile.localDefault();
    final OverallProgressViewData? overallProgress = extended
        ? ref.watch(overallProgressProvider).value
        : null;
    final List<Mission>? todayMissions = extended
        ? ref.watch(todayMissionsProvider).value
        : null;
    final List<MissionArea>? missionAreas = extended
        ? ref.watch(missionAreasProvider).value
        : null;
    final SidebarMissionVitals? missionVitals = _sidebarMissionVitals(
      todayMissions,
      missionAreas,
    );
    final int? batteryLevel = extended
        ? ref.watch(deviceBatteryLevelProvider).value
        : null;

    return Scaffold(
      body: Row(
        children: <Widget>[
          TerminalSidebar(
            selectedIndex: _railIndex(location),
            extended: extended,
            displayName: profile.displayName,
            avatarPath: profile.avatarPath,
            globalLevel: overallProgress?.rpgLevel,
            missionVitals: missionVitals,
            batteryLevel: batteryLevel,
            onProfilePressed: () => showDialog<void>(
              context: context,
              builder: (BuildContext context) =>
                  UserProfileEditDialog(initialProfile: profile),
            ),
            onExit: () => unawaited(_confirmExit(context, ref)),
            onSelected: (int index) {
              if (index != _railIndex(location)) {
                unawaited(
                  ref.read(uiSoundServiceProvider).play(UiSound.navigation),
                );
              }
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
          ),
          VerticalDivider(
            key: const ValueKey<String>('sidebar-content-divider'),
            width: 1,
            color: tokens.structuralRed,
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                TerminalApplicationHeader(location: location),
                Expanded(child: navigationShell),
                const _GlobalActiveTimerBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloquea la sesión (cierra la base cifrada) y cierra la app. Al volver se
/// pedirá el PIN. Es reversible, así que la acción usa el estilo normal.
Future<void> _confirmExit(BuildContext context, WidgetRef ref) async {
  final bool? accepted = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('¿Deseas salir?'),
      content: const Text(
        'La app se bloqueará y se cerrará. Para volver a entrar necesitarás '
        'tu PIN.',
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('exit-cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          key: const Key('exit-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          icon: const Icon(Icons.logout),
          label: const Text('Salir'),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) {
    return;
  }
  ref
      .read(accessSessionProvider.notifier)
      .lock(reason: AccessLockReason.manual);
  context.go(AppRoutes.lock);
  await ref.read(appExitProvider)();
}

SidebarMissionVitals? _sidebarMissionVitals(
  List<Mission>? todayMissions,
  List<MissionArea>? missionAreas,
) {
  if (todayMissions == null || missionAreas == null) return null;

  String? healthAreaId;
  for (final MissionArea area in missionAreas) {
    if (area.iconKey == 'favorite' ||
        area.name.trim().toLowerCase() == 'salud') {
      healthAreaId = area.id;
      break;
    }
  }

  final List<Mission> visibleMissions = todayMissions
      .where(
        (Mission mission) =>
            mission.status != MissionStatus.cancelled &&
            mission.status != MissionStatus.abandoned,
      )
      .toList(growable: false);
  final List<Mission> healthMissions = healthAreaId == null
      ? const <Mission>[]
      : visibleMissions
            .where((Mission mission) => mission.areaId == healthAreaId)
            .toList(growable: false);

  return SidebarMissionVitals(
    healthCompleted: healthMissions
        .where((Mission mission) => mission.status == MissionStatus.completed)
        .length,
    healthTotal: healthMissions.length,
  );
}

class _GlobalActiveTimerBar extends ConsumerStatefulWidget {
  const _GlobalActiveTimerBar();

  @override
  ConsumerState<_GlobalActiveTimerBar> createState() =>
      _GlobalActiveTimerBarState();
}

class _GlobalActiveTimerBarState extends ConsumerState<_GlobalActiveTimerBar>
    with WidgetsBindingObserver {
  Timer? _ticker;
  DateTime _nowUtc = DateTime.now().toUtc();
  bool _shouldTick = false;
  bool _pausing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _nowUtc = DateTime.now().toUtc();
      if (_shouldTick) {
        _startTicker();
      }
      ref.invalidate(activeTimerMissionProvider);
      return;
    }
    _ticker?.cancel();
    _ticker = null;
  }

  void _startTicker() {
    if (_ticker != null) {
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _shouldTick) {
        setState(() => _nowUtc = DateTime.now().toUtc());
      }
    });
  }

  void _syncTicker(bool shouldTick) {
    _shouldTick = shouldTick;
    if (shouldTick) {
      _startTicker();
      return;
    }
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Mission?> activeTimer = ref.watch(
      activeTimerMissionProvider,
    );
    final Mission? mission = activeTimer.value;
    _syncTicker(mission?.status == MissionStatus.active);
    if (mission == null || mission.status != MissionStatus.active) {
      return const SizedBox.shrink();
    }

    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return SafeArea(
      top: false,
      child: Material(
        color: tokens.surfaceHigh,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: tokens.progressGreen)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 580;
                final Widget details = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'CRONÓMETRO ACTIVO · '
                      '${missionDurationLabel(mission.elapsedWorkSecondsAt(_nowUtc))}',
                      style: TextStyle(
                        color: tokens.progressGreen,
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mission.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                );
                final Widget actions = Wrap(
                  spacing: 4,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Abrir cronómetro',
                      icon: const Icon(Icons.open_in_new),
                      color: tokens.infoCyan,
                      onPressed: () => context.goNamed(
                        'missionActive',
                        pathParameters: <String, String>{
                          'missionId': mission.id,
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Pausar cronómetro',
                      icon: _pausing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.pause),
                      color: tokens.valueYellow,
                      onPressed: _pausing ? null : () => _pause(mission),
                    ),
                  ],
                );
                if (compact) {
                  return Row(
                    children: <Widget>[
                      Icon(Icons.timer_outlined, color: tokens.progressGreen),
                      const SizedBox(width: 10),
                      Expanded(child: details),
                      actions,
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Icon(Icons.timer_outlined, color: tokens.progressGreen),
                    const SizedBox(width: 12),
                    Expanded(child: details),
                    actions,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pause(Mission mission) async {
    setState(() => _pausing = true);
    final Result<Mission> result = await ref
        .read(missionApplicationServiceProvider)
        .pauseTimer(mission);
    if (!mounted) {
      return;
    }
    result.fold<void>(
      onSuccess: (_) {
        ref.invalidate(activeTimerMissionProvider);
        ref.invalidate(missionDetailProvider(mission.id));
        ref.invalidate(todayMissionsProvider);
      },
      onFailure: (AppFailure failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
    if (mounted) {
      setState(() => _pausing = false);
    }
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
