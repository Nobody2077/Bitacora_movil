import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../app/theme/terminal_foundations.dart';
import '../domain/models/journal_entry.dart';

String journalMoodLabel(JournalMood? value) => switch (value) {
  JournalMood.happy => 'Feliz',
  JournalMood.motivated => 'Motivado',
  JournalMood.focused => 'Enfocado',
  JournalMood.calm => 'Tranquilo',
  JournalMood.normal => 'Neutral',
  JournalMood.anxious => 'Ansioso',
  JournalMood.sad => 'Triste',
  JournalMood.tired => 'Cansado',
  null => 'Sin estado',
};

IconData journalMoodIcon(JournalMood? value) => switch (value) {
  JournalMood.happy => Icons.sentiment_very_satisfied_outlined,
  JournalMood.motivated => Icons.local_fire_department_outlined,
  JournalMood.focused => Icons.center_focus_strong,
  JournalMood.calm => Icons.spa_outlined,
  JournalMood.normal => Icons.sentiment_satisfied_alt_outlined,
  JournalMood.anxious => Icons.sentiment_dissatisfied_outlined,
  JournalMood.sad => Icons.sentiment_very_dissatisfied_outlined,
  JournalMood.tired => Icons.battery_2_bar_outlined,
  null => Icons.remove_circle_outline,
};

String journalOriginLabel(JournalOrigin value) => switch (value) {
  JournalOrigin.manual => 'Manual',
  JournalOrigin.mission => 'Misión',
  JournalOrigin.transaction => 'Movimiento',
  JournalOrigin.system => 'Sistema',
};

String journalDateTimeLabel(DateTime utc) {
  final DateTime local = utc.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year} · '
      '${_two(local.hour)}:${_two(local.minute)}';
}

String journalDayLabel(DateTime local) {
  const List<String> weekdays = <String>[
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  const List<String> months = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${weekdays[local.weekday - 1]}, ${local.day} de '
      '${months[local.month - 1]} de ${local.year}';
}

String journalBodyPreview(String? body) {
  final String normalized = body?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  return normalized.isEmpty ? 'Sin contenido adicional.' : normalized;
}

bool journalSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _two(int value) => value.toString().padLeft(2, '0');

class JournalPageFrame extends StatelessWidget {
  const JournalPageFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) =>
        SingleChildScrollView(
          padding: constraints.maxWidth < 700
              ? TerminalSpace.pageCompact
              : TerminalSpace.pageTablet,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: child,
            ),
          ),
        ),
  );
}

/// La Bitácora vive dentro de Personaje → DIARIO (ADR-006 D18): volver a
/// ella es volver al Diario.
void goToDiary(BuildContext context) => context.goNamed(
  'character',
  queryParameters: const <String, String>{'tab': 'diario'},
);

/// Qué tipo de entrada es, como lo dice el Diario (ADR-006 D18).
String journalEntryKindLabel(JournalOrigin value) => switch (value) {
  JournalOrigin.mission => 'Misión',
  JournalOrigin.transaction => 'Movimiento',
  JournalOrigin.manual => 'Entrada libre',
  JournalOrigin.system => 'Reflexión diaria',
};

Color journalMoodColor(AppThemeTokens tokens, JournalMood? mood) =>
    switch (mood) {
      JournalMood.happy => tokens.valueYellow,
      JournalMood.motivated => tokens.progressGreen,
      JournalMood.focused => tokens.progressGreen,
      JournalMood.calm => tokens.infoCyan,
      JournalMood.normal => tokens.infoCyan,
      JournalMood.anxious => tokens.attentionOrange,
      JournalMood.sad => tokens.structuralRed,
      JournalMood.tired => tokens.attentionOrange,
      null => tokens.textDisabled,
    };
