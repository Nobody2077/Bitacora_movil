import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/mission_providers.dart';
import '../domain/models/mission.dart';
import 'mission_presentation_support.dart';

class MissionActivePage extends ConsumerStatefulWidget {
  const MissionActivePage({required this.missionId, super.key});

  final String missionId;

  @override
  ConsumerState<MissionActivePage> createState() => _MissionActivePageState();
}

class _MissionActivePageState extends ConsumerState<MissionActivePage>
    with WidgetsBindingObserver {
  Timer? _ticker;
  DateTime _nowUtc = DateTime.now().toUtc();
  Mission? _currentMission;
  bool _shouldTick = false;
  bool _changing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
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
      _startTicker();
      ref.invalidate(missionDetailProvider(widget.missionId));
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
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

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Mission?> loaded = ref.watch(
      missionDetailProvider(widget.missionId),
    );
    final Mission? mission = _currentMission ?? loaded.value;
    if (mission == null) {
      if (loaded.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return _UnavailableMission(
        message: loaded.hasError
            ? 'No se pudo recuperar el cronómetro.'
            : 'La misión ya no está disponible.',
        onBack: () => context.goNamed('missionsToday'),
      );
    }
    _shouldTick = mission.status == MissionStatus.active;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TerminalPageHeader(
                    title: 'Misión activa',
                    subtitle: mission.title,
                  ),
                  const SizedBox(height: 20),
                  _TimerPanel(mission: mission, nowUtc: _nowUtc),
                  const SizedBox(height: 18),
                  _ExecutionActions(
                    mission: mission,
                    busy: _changing,
                    onToggle: () => _toggleTimer(mission),
                    onDetail: () => context.goNamed(
                      'missionDetail',
                      pathParameters: <String, String>{'missionId': mission.id},
                    ),
                    onFinish: () => context.pushNamed(
                      'missionReview',
                      pathParameters: <String, String>{'missionId': mission.id},
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _EfficiencyNote(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleTimer(Mission mission) async {
    if (_changing) {
      return;
    }
    setState(() => _changing = true);
    final Result<Mission> result = mission.status == MissionStatus.active
        ? await ref.read(missionApplicationServiceProvider).pauseTimer(mission)
        : await ref.read(missionApplicationServiceProvider).startTimer(mission);
    if (!mounted) {
      return;
    }
    result.fold<void>(
      onSuccess: (updated) {
        setState(() {
          _currentMission = updated;
          _nowUtc = DateTime.now().toUtc();
          _changing = false;
        });
        ref.invalidate(missionDetailProvider(widget.missionId));
        ref.invalidate(todayMissionsProvider);
      },
      onFailure: (AppFailure failure) {
        setState(() => _changing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }
}

class _TimerPanel extends StatelessWidget {
  const _TimerPanel({required this.mission, required this.nowUtc});

  final Mission mission;
  final DateTime nowUtc;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final int elapsedSeconds = mission.elapsedWorkSecondsAt(nowUtc);
    final int? targetSeconds = mission.estimatedMinutes == null
        ? null
        : mission.estimatedMinutes! * 60;
    final double? progress = targetSeconds == null || targetSeconds == 0
        ? null
        : (elapsedSeconds / targetSeconds).clamp(0, 1).toDouble();
    final bool active = mission.status == MissionStatus.active;
    return TerminalPanel(
      borderColor: active ? tokens.progressGreen : tokens.valueYellow,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: <Widget>[
          TerminalBadge(
            label: missionStatusLabel(mission.status),
            color: active ? tokens.progressGreen : tokens.valueYellow,
            icon: active ? Icons.play_arrow : Icons.pause,
          ),
          const SizedBox(height: 24),
          Text(
            missionDurationLabel(elapsedSeconds),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: active ? tokens.progressGreen : Colors.white,
              fontFamily: 'JetBrains Mono',
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            targetSeconds == null
                ? 'TIEMPO REGISTRADO'
                : 'OBJETIVO ${missionDurationLabel(targetSeconds)}',
            style: const TextStyle(
              color: Colors.white54,
              fontFamily: 'JetBrains Mono',
              letterSpacing: 1,
            ),
          ),
          if (progress != null) ...<Widget>[
            const SizedBox(height: 22),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: progress >= 1 ? tokens.valueYellow : tokens.infoCyan,
              backgroundColor: tokens.border,
            ),
          ],
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 16,
            children: <Widget>[
              TerminalMetric(
                icon: Icons.history,
                value: '${mission.timeEntries.length}',
                label: 'segmentos',
                color: tokens.infoCyan,
              ),
              TerminalMetric(
                icon: Icons.bolt_outlined,
                value: '${mission.xpPlanned}',
                label: 'XP previstos',
                color: tokens.valueYellow,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExecutionActions extends StatelessWidget {
  const _ExecutionActions({
    required this.mission,
    required this.busy,
    required this.onToggle,
    required this.onDetail,
    required this.onFinish,
  });

  final Mission mission;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onDetail;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final bool active = mission.status == MissionStatus.active;
    final bool canStart = const <MissionStatus>{
      MissionStatus.scheduled,
      MissionStatus.available,
      MissionStatus.rescheduled,
      MissionStatus.paused,
    }.contains(mission.status);
    final String toggleLabel = active
        ? 'Pausar'
        : mission.status == MissionStatus.paused
        ? 'Reanudar'
        : 'Iniciar';
    return TerminalPanel(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: <Widget>[
          TerminalPrimaryButton(
            label: busy ? 'Guardando' : toggleLabel,
            icon: active ? Icons.pause : Icons.play_arrow,
            onPressed: busy || (!active && !canStart) ? null : onToggle,
          ),
          TerminalOutlineButton(
            label: 'Ver detalle',
            icon: Icons.description_outlined,
            onPressed: busy ? null : onDetail,
          ),
          TerminalOutlineButton(
            label: 'Finalizar',
            icon: Icons.flag_outlined,
            onPressed: busy ? null : onFinish,
          ),
        ],
      ),
    );
  }
}

class _EfficiencyNote extends StatelessWidget {
  const _EfficiencyNote();

  @override
  Widget build(BuildContext context) => const TerminalPanel(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.battery_saver_outlined, color: Colors.white54),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'El tiempo se calcula desde el instante guardado. Al cerrar la app '
            'no queda un contador ejecutándose en segundo plano.',
            style: TextStyle(color: Colors.white60),
          ),
        ),
      ],
    ),
  );
}

class _UnavailableMission extends StatelessWidget {
  const _UnavailableMission({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: TerminalPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.timer_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 16),
            TerminalPrimaryButton(
              label: 'Volver a misiones',
              icon: Icons.arrow_back,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    ),
  );
}
