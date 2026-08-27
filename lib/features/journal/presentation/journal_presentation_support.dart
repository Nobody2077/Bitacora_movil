import 'package:flutter/material.dart';

import '../../../app/theme/terminal_foundations.dart';
import '../domain/models/journal_entry.dart';

String journalMoodLabel(JournalMood? value) => switch (value) {
  JournalMood.focused => 'Enfocado',
  JournalMood.normal => 'Normal',
  JournalMood.tired => 'Cansado',
  null => 'Sin estado',
};

IconData journalMoodIcon(JournalMood? value) => switch (value) {
  JournalMood.focused => Icons.center_focus_strong,
  JournalMood.normal => Icons.sentiment_satisfied_alt_outlined,
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
