import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../economy/presentation/economy_presentation_support.dart';
import '../application/daily_close_application_service.dart';
import '../application/journal_providers.dart';
import '../domain/models/daily_close.dart';
import '../domain/models/journal_entry.dart';
import 'journal_presentation_support.dart';

class DailyClosePage extends ConsumerStatefulWidget {
  const DailyClosePage({required this.localDay, super.key});

  final DateTime localDay;

  @override
  ConsumerState<DailyClosePage> createState() => _DailyClosePageState();
}

class _DailyClosePageState extends ConsumerState<DailyClosePage> {
  final TextEditingController _reflectionController = TextEditingController();
  bool _initializedText = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final AsyncValue<DailyCloseViewData> closeData = ref.watch(
      dailyCloseProvider(widget.localDay),
    );

    return JournalPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TerminalPageHeader(
            title: dailyCloseTitle(widget.localDay),
            subtitle: 'Balance operativo y reflexión del día',
          ),
          const SizedBox(height: TerminalSpace.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TerminalOutlineButton(
              label: 'Volver a Bitácora',
              icon: Icons.arrow_back,
              color: tokens.textSecondary,
              onPressed: () => context.goNamed('journal'),
            ),
          ),
          const SizedBox(height: TerminalSpace.md),
          closeData.when(
            data: (DailyCloseViewData data) {
              if (!_initializedText) {
                _reflectionController.text =
                    data.reflectionEntry?.body?.trim() ?? '';
                _initializedText = true;
              }
              return _buildContent(context, tokens, data);
            },
            loading: () => const TerminalPanel(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (error, _) => TerminalEmptyState(
              title: 'No se pudo cargar el cierre',
              description: 'Ocurrió un error al consultar los datos del día.',
              icon: Icons.error_outline,
              action: TerminalOutlineButton(
                label: 'Reintentar',
                icon: Icons.refresh,
                onPressed: () =>
                    ref.invalidate(dailyCloseProvider(widget.localDay)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppThemeTokens tokens,
    DailyCloseViewData data,
  ) {
    final DailyCloseSummary summary = data.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SummaryMetricsPanel(summary: summary, tokens: tokens),
        const SizedBox(height: TerminalSpace.md),
        _MissionsSummarySection(summary: summary, tokens: tokens),
        const SizedBox(height: TerminalSpace.md),
        _ReflectionPanel(
          controller: _reflectionController,
          isSaving: _isSaving,
          tokens: tokens,
          onSave: () => _saveReflection(data.reflectionEntry),
        ),
      ],
    );
  }

  Future<void> _saveReflection(JournalEntry? existing) async {
    setState(() => _isSaving = true);
    final Result<JournalEntry?> result = await ref
        .read(dailyCloseApplicationServiceProvider)
        .saveReflection(
          localDay: widget.localDay,
          reflection: _reflectionController.text,
        );
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    result.fold<void>(
      onSuccess: (_) {
        ref.invalidate(dailyCloseProvider(widget.localDay));
        ref.invalidate(journalEntriesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reflexión diaria guardada.')),
        );
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }
}

class _SummaryMetricsPanel extends StatelessWidget {
  const _SummaryMetricsPanel({required this.summary, required this.tokens});

  final DailyCloseSummary summary;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return TerminalPanel(
      borderColor: tokens.structuralRed,
      child: Wrap(
        spacing: 32,
        runSpacing: 18,
        children: <Widget>[
          TerminalMetric(
            icon: Icons.military_tech_outlined,
            value: '+${summary.xpEarned} XP',
            label: 'XP Obtenido',
            color: summary.xpEarned > 0
                ? tokens.progressGreen
                : tokens.infoCyan,
          ),
          TerminalMetric(
            icon: Icons.timer_outlined,
            value: _formatWorkTime(summary.workSeconds),
            label: 'Tiempo enfocado',
            color: tokens.infoCyan,
          ),
          TerminalMetric(
            icon: Icons.check_circle_outline,
            value: '${summary.completedMissions.length}',
            label: 'Misiones logradas',
            color: tokens.progressGreen,
          ),
          if (summary.requiredPendingMissions.isNotEmpty)
            TerminalMetric(
              icon: Icons.warning_amber_outlined,
              value: '${summary.requiredPendingMissions.length}',
              label: 'Pendientes obligatorias',
              color: tokens.terminalRed,
            ),
          TerminalMetric(
            icon: Icons.account_balance_wallet_outlined,
            value: economyMoney(summary.balanceMinor, signed: true),
            label: 'Balance económico',
            color: summary.balanceMinor >= 0
                ? tokens.progressGreen
                : tokens.attentionOrange,
          ),
          if (summary.mainAreaName != null)
            TerminalMetric(
              icon: Icons.category_outlined,
              value: summary.mainAreaName!,
              label: 'Área destacada',
              color: tokens.valueYellow,
            ),
        ],
      ),
    );
  }

  String _formatWorkTime(int seconds) {
    if (seconds <= 0) {
      return '0 min';
    }
    final int minutes = (seconds / 60).floor();
    final int hours = (minutes / 60).floor();
    final int remainingMinutes = minutes % 60;
    if (hours == 0) {
      return '$minutes min';
    }
    if (remainingMinutes == 0) {
      return '$hours h';
    }
    return '$hours h $remainingMinutes min';
  }
}

class _MissionsSummarySection extends StatelessWidget {
  const _MissionsSummarySection({required this.summary, required this.tokens});

  final DailyCloseSummary summary;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (summary.completedMissions.isNotEmpty) ...<Widget>[
          const TerminalSectionTitle(
            overline: 'Misiones',
            title: 'Completadas en el día',
          ),
          const SizedBox(height: TerminalSpace.sm),
          for (final DailyCloseMission mission
              in summary.completedMissions) ...<Widget>[
            _MissionItemTile(
              mission: mission,
              tokens: tokens,
              isCompleted: true,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: TerminalSpace.md),
        ],
        if (summary.requiredPendingMissions.isNotEmpty) ...<Widget>[
          const TerminalSectionTitle(
            overline: 'Atención',
            title: 'Misiones obligatorias pendientes',
          ),
          const SizedBox(height: TerminalSpace.sm),
          for (final DailyCloseMission mission
              in summary.requiredPendingMissions) ...<Widget>[
            _MissionItemTile(
              mission: mission,
              tokens: tokens,
              isCompleted: false,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _MissionItemTile extends StatelessWidget {
  const _MissionItemTile({
    required this.mission,
    required this.tokens,
    required this.isCompleted,
  });

  final DailyCloseMission mission;
  final AppThemeTokens tokens;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      onTap: () => context.pushNamed(
        'missionDetail',
        pathParameters: <String, String>{'missionId': mission.id},
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isCompleted
                ? (mission.isPartial
                      ? Icons.timelapse_outlined
                      : Icons.check_circle_outline)
                : Icons.pending_actions_outlined,
            color: isCompleted
                ? (mission.isPartial
                      ? tokens.valueYellow
                      : tokens.progressGreen)
                : tokens.terminalRed,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mission.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Icon(Icons.chevron_right, color: tokens.infoCyan),
        ],
      ),
    );
  }
}

class _ReflectionPanel extends StatelessWidget {
  const _ReflectionPanel({
    required this.controller,
    required this.isSaving,
    required this.tokens,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool isSaving;
  final AppThemeTokens tokens;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return TerminalPanel(
      borderColor: tokens.infoCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const TerminalSectionTitle(
            overline: 'Memoria y aprendizaje',
            title: 'Reflexión del día',
            description:
                'Resume tus lecciones, pensamientos o conclusiones del día (hasta 4000 caracteres).',
          ),
          const SizedBox(height: TerminalSpace.md),
          TextField(
            controller: controller,
            maxLength: DailyCloseApplicationService.maxReflectionLength,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText:
                  '¿Qué aprendiste hoy? ¿Qué salió bien y qué puedes mejorar?',
            ),
          ),
          const SizedBox(height: TerminalSpace.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TerminalPrimaryButton(
              label: isSaving ? 'Guardando...' : 'Guardar reflexión',
              icon: Icons.save_outlined,
              onPressed: isSaving ? null : onSave,
            ),
          ),
        ],
      ),
    );
  }
}
