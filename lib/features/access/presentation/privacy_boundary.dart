import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/persistence_providers.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/result/result.dart';
import '../../settings/domain/models/app_preferences.dart';
import '../application/access_session_controller.dart';
import '../application/access_session_state.dart';
import '../application/privacy_controller.dart';

const Key privacyShieldKey = Key('privacy-shield');

class AppPrivacyBoundary extends ConsumerStatefulWidget {
  const AppPrivacyBoundary({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppPrivacyBoundary> createState() => _AppPrivacyBoundaryState();
}

class _AppPrivacyBoundaryState extends ConsumerState<AppPrivacyBoundary> {
  late final AppLifecycleListener _lifecycleListener;
  bool _revealScheduled = false;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _handleLifecycleState,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_resumeAndScheduleReveal());
      }
    });
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _handleLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      unawaited(_resumeAndScheduleReveal());
      return;
    }
    ref.read(privacyControllerProvider.notifier).coverForBackground();
  }

  Future<void> _resumeAndScheduleReveal() async {
    await ref.read(privacyControllerProvider.notifier).resume();
    if (!mounted) {
      return;
    }
    _scheduleReveal();
  }

  void _scheduleReveal() {
    if (_revealScheduled) {
      return;
    }
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (mounted) {
        ref.read(privacyControllerProvider.notifier).revealAfterSafeFrame();
      }
    });
  }

  Future<void> _loadAutoLockPolicy(int sessionRevision) async {
    ref.read(autoLockMinutesProvider.notifier).useSafeFallback();
    try {
      final Result<AppPreferences> result = await ref
          .read(settingsRepositoryProvider)
          .load();
      if (!mounted) {
        return;
      }
      final AccessSessionState session = ref.read(accessSessionProvider);
      if (!session.canBuildProtected || session.revision != sessionRevision) {
        return;
      }
      result.fold<void>(
        onSuccess: (AppPreferences preferences) {
          ref
              .read(autoLockMinutesProvider.notifier)
              .setMinutes(preferences.autoLockMinutes);
        },
        onFailure: (_) {
          ref.read(autoLockMinutesProvider.notifier).useSafeFallback();
        },
      );
    } on Object {
      if (mounted) {
        ref.read(autoLockMinutesProvider.notifier).useSafeFallback();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(persistenceAccessGuardProvider);
    ref.listen<AccessSessionState>(accessSessionProvider, (previous, next) {
      if (next.canRevealPrivacyShield) {
        _scheduleReveal();
      }
      if (next.canBuildProtected && previous?.canBuildProtected != true) {
        unawaited(_loadAutoLockPolicy(next.revision));
      }
    });
    final bool covered = ref.watch(
      privacyControllerProvider.select(
        (PrivacyShieldState value) => value.covered,
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        TickerMode(
          enabled: !covered,
          child: ExcludeSemantics(excluding: covered, child: widget.child),
        ),
        if (covered) const _PrivacyShield(),
      ],
    );
  }
}

class _PrivacyShield extends StatelessWidget {
  const _PrivacyShield();

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens =
        Theme.of(context).extension<AppThemeTokens>() ??
        AppThemeTokens.terminal;
    return Positioned.fill(
      key: privacyShieldKey,
      child: AbsorbPointer(
        absorbing: true,
        child: ExcludeSemantics(
          child: ColoredBox(
            color: tokens.background,
            child: Center(
              child: Icon(
                Icons.shield_outlined,
                color: tokens.structuralRed,
                size: 44,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
