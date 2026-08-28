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

class MissionSwitchTimerPage extends ConsumerStatefulWidget {
  const MissionSwitchTimerPage({required this.missionId, super.key});

  final String missionId;

  @override
  ConsumerState<MissionSwitchTimerPage> createState() =>
      _MissionSwitchTimerPageState();
}

class _MissionSwitchTimerPageState
    extends ConsumerState<MissionSwitchTimerPage> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Mission?> target = ref.watch(
      missionDetailProvider(widget.missionId),
    );
    final AsyncValue<Mission?> active = ref.watch(activeTimerMissionProvider);
    if (target.isLoading || active.isLoading) {
      return const TerminalAsyncStatePage(
        child: TerminalLoadingState(
          message: 'Preparando cambio de cronómetro…',
        ),
      );
    }
    if (target.hasError || active.hasError) {
      return TerminalAsyncStatePage(
        child: TerminalErrorState(
          title: 'Cronómetro no disponible',
          description: 'No se pudo preparar el cambio de cronómetro.',
          onRetry: () {
            ref.invalidate(missionDetailProvider(widget.missionId));
            ref.invalidate(activeTimerMissionProvider);
          },
        ),
      );
    }
    if (target.value == null) {
      return _SwitchUnavailable(onBack: () => context.goNamed('missionsToday'));
    }

    final Mission targetMission = target.value!;
    final Mission? activeMission = active.value;
    final bool sameMission = activeMission?.id == targetMission.id;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TerminalPageHeader(
                title: sameMission ? 'Cronómetro activo' : 'Cambiar cronómetro',
                subtitle: sameMission
                    ? 'Esta misión ya está registrando tiempo'
                    : 'Solo una misión puede registrar tiempo a la vez',
              ),
              const SizedBox(height: 20),
              if (activeMission != null && !sameMission) ...<Widget>[
                _MissionTimerCard(
                  label: 'Se pausará',
                  mission: activeMission,
                  active: true,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Icon(Icons.south, color: Colors.white54),
                ),
              ],
              _MissionTimerCard(
                label: sameMission
                    ? 'En ejecución'
                    : activeMission == null
                    ? 'Se iniciará'
                    : 'Nueva misión activa',
                mission: targetMission,
                active: sameMission,
              ),
              const SizedBox(height: 18),
              TerminalPanel(
                child: Text(
                  sameMission
                      ? 'Puedes volver al cronómetro sin cambiar ningún dato.'
                      : activeMission == null
                      ? 'No hay otro cronómetro activo. Se iniciará esta misión.'
                      : 'La pausa y el inicio se guardan juntos. Si una operación '
                            'falla, ninguna de las dos queda aplicada.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.end,
                children: <Widget>[
                  TerminalOutlineButton(
                    label: 'Cancelar',
                    icon: Icons.close,
                    onPressed: _saving ? null : () => context.pop(),
                  ),
                  TerminalPrimaryButton(
                    label: _saving
                        ? 'Guardando'
                        : sameMission
                        ? 'Continuar'
                        : activeMission == null
                        ? 'Iniciar misión'
                        : 'Cambiar cronómetro',
                    icon: sameMission ? Icons.timer_outlined : Icons.swap_horiz,
                    onPressed: _saving
                        ? null
                        : () => _confirm(activeMission, targetMission),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(Mission? active, Mission target) async {
    if (active?.id == target.id) {
      _openTimer(target.id);
      return;
    }
    setState(() => _saving = true);
    final Result<Mission> result = active == null
        ? await ref.read(missionApplicationServiceProvider).startTimer(target)
        : await ref
              .read(missionApplicationServiceProvider)
              .switchTimer(activeMission: active, targetMission: target);
    if (!mounted) {
      return;
    }
    result.fold<void>(
      onSuccess: (updated) {
        ref.invalidate(activeTimerMissionProvider);
        ref.invalidate(todayMissionsProvider);
        ref.invalidate(missionDetailProvider(target.id));
        if (active != null) {
          ref.invalidate(missionDetailProvider(active.id));
        }
        _openTimer(updated.id);
      },
      onFailure: (AppFailure failure) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  void _openTimer(String missionId) {
    context.goNamed(
      'missionActive',
      pathParameters: <String, String>{'missionId': missionId},
    );
  }
}

class _MissionTimerCard extends StatelessWidget {
  const _MissionTimerCard({
    required this.label,
    required this.mission,
    required this.active,
  });

  final String label;
  final Mission mission;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final int seconds = mission.elapsedWorkSecondsAt(DateTime.now().toUtc());
    return TerminalPanel(
      borderColor: active ? tokens.progressGreen : tokens.infoCyan,
      child: Row(
        children: <Widget>[
          Icon(
            active ? Icons.timer : Icons.flag_outlined,
            color: active ? tokens.progressGreen : tokens.infoCyan,
            size: 38,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: active ? tokens.progressGreen : tokens.infoCyan,
                    fontFamily: 'JetBrains Mono',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  mission.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                Text(
                  '${missionStatusLabel(mission.status)} · '
                  '${missionDurationLabel(seconds)}',
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchUnavailable extends StatelessWidget {
  const _SwitchUnavailable({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: TerminalPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.timer_off_outlined, size: 46),
            const SizedBox(height: 12),
            const Text('No se pudo preparar el cambio de cronómetro.'),
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
