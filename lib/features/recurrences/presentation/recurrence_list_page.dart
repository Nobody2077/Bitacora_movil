import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../features/missions/application/mission_providers.dart';
import '../../../features/missions/domain/models/mission.dart';
import '../../../features/missions/presentation/mission_presentation_support.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../application/recurrence_providers.dart';
import '../domain/models/recurrence_template.dart';

class RecurrenceListPage extends ConsumerWidget {
  const RecurrenceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RecurrenceTemplate>> templates = ref.watch(
      allTemplatesProvider,
    );
    final AsyncValue<List<MissionArea>> areas = ref.watch(missionAreasProvider);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TerminalPageHeader(
                    title: 'Misiones recurrentes',
                    subtitle: 'Plantillas que generan ocurrencias automáticas',
                    action: TerminalPrimaryButton(
                      label: 'Nueva plantilla',
                      icon: Icons.add,
                      onPressed: () => context.pushNamed('missionTemplateNew'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _TemplateSummary(templates: templates),
                  const SizedBox(height: 16),
                  templates.when(
                    data: (items) => _TemplateList(
                      templates: items,
                      areas: areas.value ?? const <MissionArea>[],
                      onPause: (id) => _pause(context, ref, id),
                      onResume: (id) => _resume(context, ref, id),
                      onDelete: (id) => _confirmDelete(context, ref, id),
                    ),
                    loading: () => const TerminalLoadingState(
                      message: 'Cargando plantillas recurrentes…',
                    ),
                    error: (Object error, _) => TerminalErrorState(
                      title: 'Plantillas no disponibles',
                      description: 'No se pudieron cargar las plantillas.',
                      onRetry: () => ref.invalidate(allTemplatesProvider),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pause(
    BuildContext context,
    WidgetRef ref,
    String templateId,
  ) async {
    final result = await ref
        .read(recurrenceApplicationServiceProvider)
        .pauseTemplate(templateId);
    if (!context.mounted) return;
    result.fold<void>(
      onSuccess: (_) {
        ref.invalidate(allTemplatesProvider);
        ref.invalidate(activeTemplatesProvider);
      },
      onFailure: (AppFailure f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  Future<void> _resume(
    BuildContext context,
    WidgetRef ref,
    String templateId,
  ) async {
    final result = await ref
        .read(recurrenceApplicationServiceProvider)
        .resumeTemplate(templateId);
    if (!context.mounted) return;
    result.fold<void>(
      onSuccess: (_) {
        ref.invalidate(allTemplatesProvider);
        ref.invalidate(activeTemplatesProvider);
        // Dispara generación inmediata para la plantilla reactivada
        ref
            .read(recurrenceApplicationServiceProvider)
            .generatePendingOccurrences();
      },
      onFailure: (AppFailure f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String templateId,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar plantilla'),
        content: const Text(
          'Solo se puede eliminar si no tiene misiones generadas. '
          '¿Confirmas?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(recurrenceApplicationServiceProvider)
        .deleteTemplateIfUnused(templateId);
    if (!context.mounted) return;
    result.fold<void>(
      onSuccess: (_) {
        ref.invalidate(allTemplatesProvider);
        ref.invalidate(activeTemplatesProvider);
      },
      onFailure: (AppFailure f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }
}

// ── Métricas de resumen ─────────────────────────────────────────────────────

class _TemplateSummary extends StatelessWidget {
  const _TemplateSummary({required this.templates});

  final AsyncValue<List<RecurrenceTemplate>> templates;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final List<RecurrenceTemplate> items =
        templates.value ?? const <RecurrenceTemplate>[];
    final int active = items.where((t) => t.isActive).length;
    final int paused = items.where((t) => !t.isActive).length;

    return TerminalPanel(
      borderColor: tokens.structuralRed,
      child: Wrap(
        spacing: 34,
        runSpacing: 16,
        children: <Widget>[
          TerminalMetric(
            icon: Icons.repeat,
            value: '${items.length}',
            label: 'Plantillas',
            color: tokens.infoCyan,
          ),
          TerminalMetric(
            icon: Icons.play_circle_outline,
            value: '$active',
            label: 'Activas',
            color: tokens.progressGreen,
          ),
          TerminalMetric(
            icon: Icons.pause_circle_outline,
            value: '$paused',
            label: 'Pausadas',
            color: tokens.valueYellow,
          ),
        ],
      ),
    );
  }
}

// ── Lista de plantillas ─────────────────────────────────────────────────────

class _TemplateList extends StatelessWidget {
  const _TemplateList({
    required this.templates,
    required this.areas,
    required this.onPause,
    required this.onResume,
    required this.onDelete,
  });

  final List<RecurrenceTemplate> templates;
  final List<MissionArea> areas;
  final ValueChanged<String> onPause;
  final ValueChanged<String> onResume;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return TerminalPanel(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          children: <Widget>[
            const Icon(Icons.repeat_outlined, size: 52, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              'NO HAY PLANTILLAS RECURRENTES',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea una plantilla para generar misiones automáticamente.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        for (final template in templates) ...<Widget>[
          _TemplateCard(
            template: template,
            area: _areaFor(template.areaId),
            onPause: () => onPause(template.id),
            onResume: () => onResume(template.id),
            onEdit: () {},
            onDelete: () => onDelete(template.id),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  MissionArea? _areaFor(String areaId) {
    for (final a in areas) {
      if (a.id == areaId) return a;
    }
    return null;
  }
}

// ── Tarjeta de plantilla ────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.area,
    required this.onPause,
    required this.onResume,
    required this.onEdit,
    required this.onDelete,
  });

  final RecurrenceTemplate template;
  final MissionArea? area;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final Color areaColor = area == null
        ? tokens.infoCyan
        : missionAreaColor(area!.colorHex, tokens.infoCyan);
    final Color statusColor = template.isActive
        ? tokens.progressGreen
        : tokens.valueYellow;

    return InkWell(
      customBorder: const TerminalCutCornerBorder(cut: 14),
      onTap: () => context.pushNamed(
        'missionTemplateEdit',
        pathParameters: <String, String>{'templateId': template.id},
      ),
      child: TerminalPanel(
        borderColor: template.isActive ? tokens.infoCyan : tokens.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Badges de estado
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                TerminalBadge(
                  label: template.isActive ? 'Activa' : 'Pausada',
                  color: statusColor,
                  icon: template.isActive
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                ),
                TerminalBadge(
                  label: area?.name ?? 'Área',
                  color: areaColor,
                  icon: missionAreaIcon(area?.iconKey ?? ''),
                ),
                TerminalBadge(
                  label: _frequencyLabel(template.rule?.frequency),
                  color: tokens.attentionOrange,
                  icon: Icons.repeat,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              template.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (template.description != null &&
                template.description!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                template.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 14),
            // Métricas compactas
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: <Widget>[
                TerminalMetric(
                  icon: Icons.star_outline,
                  value: '${template.xpReward}',
                  label: 'XP',
                  color: tokens.valueYellow,
                ),
                if (template.objectives.isNotEmpty)
                  TerminalMetric(
                    icon: Icons.checklist,
                    value: '${template.objectives.length}',
                    label: 'Objetivos',
                    color: tokens.infoCyan,
                  ),
                if (template.rule?.lastGeneratedOn != null)
                  TerminalMetric(
                    icon: Icons.update,
                    value: template.rule!.lastGeneratedOn!,
                    label: 'Último gen.',
                    color: Colors.white54,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // Acciones
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                if (template.isActive)
                  TerminalOutlineButton(
                    label: 'Pausar',
                    icon: Icons.pause_outlined,
                    color: tokens.valueYellow,
                    onPressed: onPause,
                  )
                else
                  TerminalOutlineButton(
                    label: 'Reactivar',
                    icon: Icons.play_arrow_outlined,
                    color: tokens.progressGreen,
                    onPressed: onResume,
                  ),
                TerminalOutlineButton(
                  label: 'Editar',
                  icon: Icons.edit_outlined,
                  onPressed: () => context.pushNamed(
                    'missionTemplateEdit',
                    pathParameters: <String, String>{'templateId': template.id},
                  ),
                ),
                TerminalOutlineButton(
                  label: 'Eliminar',
                  icon: Icons.delete_outline,
                  color: Colors.white38,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _frequencyLabel(RecurrenceFrequency? v) {
    if (v == null) return 'Sin regla';
    return switch (v) {
      RecurrenceFrequency.daily => 'Diaria',
      RecurrenceFrequency.weekly => 'Semanal',
      RecurrenceFrequency.specificDays => 'Días específicos',
      RecurrenceFrequency.everyNDays => 'Cada N días',
    };
  }
}
