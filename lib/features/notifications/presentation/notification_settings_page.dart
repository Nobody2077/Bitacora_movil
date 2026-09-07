import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_preferences_provider.dart';
import '../../../app/providers/persistence_providers.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../shared/adaptive/app_breakpoints.dart';
import '../../../shared/widgets/terminal/terminal_widgets.dart';
import '../../settings/domain/models/app_preferences.dart';
import '../application/notification_providers.dart';
import '../domain/reminder_preferences.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  bool _saving = false;

  Future<void> _saveAppPreferences(AppPreferences preferences) async {
    if (_saving) return;
    setState(() => _saving = true);
    AppFailure? failure;
    final Result<void> result = await ref
        .read(settingsRepositoryProvider)
        .save(preferences.copyWith(updatedAtUtc: DateTime.now().toUtc()));
    result.fold<void>(
      onSuccess: (_) {},
      onFailure: (AppFailure value) => failure = value,
    );
    if (failure == null) {
      _reconcileBestEffort();
    }
    _finishSave(failure);
  }

  Future<void> _saveReminderPreferences(ReminderPreferences preferences) async {
    if (_saving) return;
    setState(() => _saving = true);
    AppFailure? failure;
    final Result<void> result = await ref
        .read(reminderPreferencesRepositoryProvider)
        .save(preferences);
    result.fold<void>(
      onSuccess: (_) {},
      onFailure: (AppFailure value) => failure = value,
    );
    if (failure == null) {
      _reconcileBestEffort();
    }
    _finishSave(failure);
  }

  void _finishSave(AppFailure? failure) {
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  void _reconcileBestEffort() {
    unawaited(
      Future<void>(() async {
        try {
          await ref.read(notificationReconciliationServiceProvider).reconcile();
        } on Object {
          // La intención queda persistida y se reintentará al desbloquear.
        }
      }),
    );
  }

  Future<void> _pickQuietTime({
    required ReminderPreferences preferences,
    required bool start,
  }) async {
    final int current = start
        ? preferences.quietStartMinutes
        : preferences.quietEndMinutes;
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (selected == null || !mounted) return;
    final int minutes = selected.hour * 60 + selected.minute;
    final ReminderPreferences next = start
        ? preferences.copyWith(quietStartMinutes: minutes)
        : preferences.copyWith(quietEndMinutes: minutes);
    if (!next.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El inicio y el fin no pueden tener la misma hora.'),
        ),
      );
      return;
    }
    await _saveReminderPreferences(next);
  }

  Future<void> _pickSummaryTime(ReminderPreferences preferences) async {
    final int current = preferences.dailySummaryMinutes;
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (selected == null || !mounted) return;
    await _saveReminderPreferences(
      preferences.copyWith(
        dailySummaryMinutes: selected.hour * 60 + selected.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppPreferences> appPreferences = ref.watch(
      appPreferencesProvider,
    );
    final AsyncValue<ReminderPreferences> reminders = ref.watch(
      reminderPreferencesProvider,
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final EdgeInsets padding =
                constraints.maxWidth < AppBreakpoints.compact
                ? TerminalSpace.pageCompact
                : TerminalSpace.pageTablet;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: ListView(
                  padding: padding,
                  children: <Widget>[
                    const TerminalPageHeader(
                      title: 'Notificaciones',
                      subtitle:
                          'Recordatorios locales, privados y sin Internet',
                    ),
                    const SizedBox(height: TerminalSpace.lg),
                    if (_saving) ...<Widget>[
                      const LinearProgressIndicator(
                        key: Key('notification-saving-indicator'),
                      ),
                      const SizedBox(height: TerminalSpace.sm),
                    ],
                    appPreferences.when(
                      loading: () => const TerminalLoadingState(
                        message: 'Cargando notificaciones…',
                      ),
                      error: (Object error, StackTrace stackTrace) =>
                          TerminalErrorState(
                            title: 'Ajustes no disponibles',
                            description:
                                'No fue posible leer las preferencias locales.',
                            onRetry: () =>
                                ref.invalidate(appPreferencesProvider),
                          ),
                      data: (AppPreferences app) => reminders.when(
                        loading: () => const TerminalLoadingState(
                          message: 'Cargando horario de recordatorios…',
                        ),
                        error: (Object error, StackTrace stackTrace) =>
                            TerminalErrorState(
                              title: 'Recordatorios no disponibles',
                              description:
                                  'No fue posible leer la planificación local.',
                              onRetry: () =>
                                  ref.invalidate(reminderPreferencesProvider),
                            ),
                        data: (ReminderPreferences reminder) =>
                            _content(app, reminder),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _content(AppPreferences app, ReminderPreferences reminder) {
    final bool enabled = app.missionNotifications && !_saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _NotificationSwitchCard(
          switchKey: const Key('mission-notifications-switch'),
          icon: Icons.notifications_active_outlined,
          title: 'Recordatorios de misiones',
          description:
              'Programa avisos locales para misiones con fecha y hora.',
          value: app.missionNotifications,
          enabled: !_saving,
          onChanged: (bool value) =>
              _saveAppPreferences(app.copyWith(missionNotifications: value)),
        ),
        const SizedBox(height: TerminalSpace.sm),
        _NotificationSwitchCard(
          switchKey: const Key('notification-sound-switch'),
          icon: Icons.volume_up_outlined,
          title: 'Sonido',
          description:
              'Usa sonido fuera del horario silencioso configurado abajo.',
          value: app.soundEnabled,
          enabled: enabled,
          onChanged: (bool value) =>
              _saveAppPreferences(app.copyWith(soundEnabled: value)),
        ),
        const SizedBox(height: TerminalSpace.md),
        _ReminderTimingPanel(
          preferences: reminder,
          enabled: enabled,
          onLeadChanged: (int value) =>
              _saveReminderPreferences(reminder.copyWith(leadMinutes: value)),
          onQuietChanged: (bool value) => _saveReminderPreferences(
            reminder.copyWith(quietHoursEnabled: value),
          ),
          onPickStart: () => _pickQuietTime(preferences: reminder, start: true),
          onPickEnd: () => _pickQuietTime(preferences: reminder, start: false),
          onSummaryChanged: (bool value) => _saveReminderPreferences(
            reminder.copyWith(dailySummaryEnabled: value),
          ),
          onPickSummary: () => _pickSummaryTime(reminder),
        ),
        const SizedBox(height: TerminalSpace.md),
        _NotificationSwitchCard(
          switchKey: const Key('notification-details-switch'),
          icon: Icons.visibility_outlined,
          title: 'Mostrar detalles de la misión',
          description: app.showNotificationDetails
              ? 'El aviso muestra el título de la misión, incluso en la pantalla bloqueada si Android lo permite.'
              : 'El aviso oculta el título y usa un mensaje genérico.',
          value: app.showNotificationDetails,
          enabled: enabled,
          onChanged: (bool value) =>
              _saveAppPreferences(app.copyWith(showNotificationDetails: value)),
        ),
        const SizedBox(height: TerminalSpace.md),
        TerminalPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.shield_outlined),
              const SizedBox(width: TerminalSpace.sm),
              Expanded(
                child: TerminalSectionTitle(
                  title: app.showNotificationDetails
                      ? 'Detalles visibles'
                      : 'Privacidad por defecto',
                  description: app.showNotificationDetails
                      ? 'Se muestra únicamente el título. Las notas y otros datos siguen ocultos; Android conserva el control final de la pantalla bloqueada.'
                      : 'La pantalla bloqueada no recibe el título, las notas ni otros datos de la misión. El aviso solo indica que existe una misión programada.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TerminalSpace.md),
        _GenericTextPanel(
          text: reminder.genericText,
          enabled: enabled,
          onChanged: (String value) =>
              _saveReminderPreferences(reminder.copyWith(genericText: value)),
        ),
        const SizedBox(height: TerminalSpace.md),
        TerminalPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.restart_alt_outlined),
              const SizedBox(width: TerminalSpace.sm),
              Expanded(
                child: TerminalSectionTitle(
                  title: 'Después de reiniciar el teléfono',
                  description: app.showNotificationDetails
                      ? 'Los recordatorios se reponen solos al encender, pero hasta que abras la aplicación salen sin el título: leerlo exigiría abrir la base cifrada, y eso pide tu PIN. Al abrir la aplicación recuperan el título.'
                      : 'Los recordatorios se reponen solos al encender el teléfono, con el mismo mensaje genérico de siempre.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReminderTimingPanel extends StatelessWidget {
  const _ReminderTimingPanel({
    required this.preferences,
    required this.enabled,
    required this.onLeadChanged,
    required this.onQuietChanged,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onSummaryChanged,
    required this.onPickSummary,
  });

  final ReminderPreferences preferences;
  final bool enabled;
  final ValueChanged<int> onLeadChanged;
  final ValueChanged<bool> onQuietChanged;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final ValueChanged<bool> onSummaryChanged;
  final VoidCallback onPickSummary;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalPanel(
      borderColor: tokens.infoCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const TerminalSectionTitle(
            title: 'Planificación del aviso',
            description:
                'La hora de la misión no cambia; solo cambia cuándo te avisamos.',
          ),
          const SizedBox(height: TerminalSpace.md),
          DropdownButtonFormField<int>(
            key: const Key('notification-lead-selector'),
            initialValue: preferences.leadMinutes,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Avisar antes de comenzar',
              prefixIcon: Icon(Icons.schedule_outlined),
            ),
            items: <DropdownMenuItem<int>>[
              for (final int minutes
                  in ReminderPreferences.supportedLeadMinutes)
                DropdownMenuItem<int>(
                  value: minutes,
                  child: Text(
                    _leadLabel(minutes),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            selectedItemBuilder: (BuildContext context) => <Widget>[
              for (final int minutes
                  in ReminderPreferences.supportedLeadMinutes)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _leadLabel(minutes),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: enabled
                ? (int? value) {
                    if (value != null) onLeadChanged(value);
                  }
                : null,
          ),
          const SizedBox(height: TerminalSpace.md),
          SwitchListTile.adaptive(
            key: const Key('quiet-hours-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Horario silencioso'),
            subtitle: const Text(
              'Los avisos llegan sin sonido durante este intervalo.',
            ),
            value: preferences.quietHoursEnabled,
            onChanged: enabled ? onQuietChanged : null,
          ),
          if (preferences.quietHoursEnabled) ...<Widget>[
            const SizedBox(height: TerminalSpace.sm),
            Wrap(
              spacing: TerminalSpace.sm,
              runSpacing: TerminalSpace.sm,
              children: <Widget>[
                TerminalOutlineButton(
                  key: const Key('quiet-start-button'),
                  label: 'Desde ${_timeLabel(preferences.quietStartMinutes)}',
                  icon: Icons.bedtime_outlined,
                  onPressed: enabled ? onPickStart : null,
                ),
                TerminalOutlineButton(
                  key: const Key('quiet-end-button'),
                  label: 'Hasta ${_timeLabel(preferences.quietEndMinutes)}',
                  icon: Icons.wb_sunny_outlined,
                  onPressed: enabled ? onPickEnd : null,
                ),
              ],
            ),
          ],
          const SizedBox(height: TerminalSpace.md),
          SwitchListTile.adaptive(
            key: const Key('daily-summary-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Resumen diario'),
            subtitle: const Text(
              'Un solo aviso al día con cuántas misiones te esperan.',
            ),
            value: preferences.dailySummaryEnabled,
            onChanged: enabled ? onSummaryChanged : null,
          ),
          if (preferences.dailySummaryEnabled) ...<Widget>[
            const SizedBox(height: TerminalSpace.sm),
            TerminalOutlineButton(
              key: const Key('daily-summary-time-button'),
              label: 'A las ${_timeLabel(preferences.dailySummaryMinutes)}',
              icon: Icons.summarize_outlined,
              onPressed: enabled ? onPickSummary : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationSwitchCard extends StatelessWidget {
  const _NotificationSwitchCard({
    required this.switchKey,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final Key switchKey;
  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    return TerminalCard(
      padding: const EdgeInsets.all(TerminalSpace.sm),
      borderColor: value ? tokens.infoCyan : tokens.border,
      child: SwitchListTile.adaptive(
        key: switchKey,
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, color: value ? tokens.infoCyan : null),
        title: Text(title),
        subtitle: Text(description),
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

String _leadLabel(int minutes) => switch (minutes) {
  0 => 'Al comenzar',
  5 => '5 min antes',
  15 => '15 min antes',
  30 => '30 min antes',
  60 => '1 h antes',
  _ => '$minutes min antes',
};

String _timeLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

/// Campo para el texto de los avisos que no muestran el título.
///
/// Tiene estado propio porque necesita su `TextEditingController`: guarda al
/// confirmar o al perder el foco, no en cada tecla, para no escribir en la base
/// cifrada una vez por carácter.
class _GenericTextPanel extends StatefulWidget {
  const _GenericTextPanel({
    required this.text,
    required this.enabled,
    required this.onChanged,
  });

  final String text;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_GenericTextPanel> createState() => _GenericTextPanelState();
}

class _GenericTextPanelState extends State<_GenericTextPanel> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChange);

  @override
  void didUpdateWidget(_GenericTextPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text && !_focusNode.hasFocus) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _submit(_controller.text);
    }
  }

  void _submit(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      _controller.text = widget.text;
      return;
    }
    if (trimmed == widget.text) {
      return;
    }
    widget.onChanged(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return TerminalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const TerminalSectionTitle(
            title: 'Texto sin detalles',
            description:
                'Lo que dice el aviso cuando no muestra el título de la misión, '
                'incluso después de reiniciar el teléfono.',
          ),
          const SizedBox(height: TerminalSpace.md),
          TextField(
            key: const Key('notification-generic-text-field'),
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            maxLength: ReminderPreferences.genericTextMaxLength,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Mensaje del aviso',
              prefixIcon: Icon(Icons.short_text_outlined),
            ),
            onSubmitted: _submit,
          ),
        ],
      ),
    );
  }
}
