import 'package:flutter/material.dart';

import '../../../app/application/commands/complete_mission.dart';
import '../../../app/theme/app_ui_preferences.dart';
import '../domain/models/mission.dart';

Color missionAreaColor(String colorHex, Color fallback) {
  final String normalized = colorHex.replaceFirst('#', '');
  final int? value = int.tryParse(normalized, radix: 16);
  return value == null ? fallback : Color(0xFF000000 | value);
}

IconData missionAreaIcon(String iconKey) => switch (iconKey) {
  'school' => Icons.school_outlined,
  'favorite' => Icons.favorite_outline,
  'code' => Icons.work_outline,
  'home' => Icons.home_outlined,
  'person' => Icons.person_outline,
  _ => Icons.track_changes_outlined,
};

String missionImportanceLabel(MissionImportance value) => switch (value) {
  MissionImportance.minor => 'Menor',
  MissionImportance.normal => 'Normal',
  MissionImportance.important => 'Importante',
  MissionImportance.veryImportant => 'Muy importante',
  MissionImportance.critical => 'Crítica',
};

String missionPriorityLabel(MissionPriority value) => switch (value) {
  MissionPriority.low => 'Baja',
  MissionPriority.normal => 'Normal',
  MissionPriority.high => 'Alta',
  MissionPriority.urgent => 'Urgente',
};

String missionStatusLabel(MissionStatus value) => switch (value) {
  MissionStatus.draft => 'Borrador',
  MissionStatus.scheduled => 'Programada',
  MissionStatus.available => 'Disponible',
  MissionStatus.active => 'En progreso',
  MissionStatus.paused => 'Pausada',
  MissionStatus.rescheduled => 'Reprogramada',
  MissionStatus.expired => 'Vencida',
  MissionStatus.abandoned => 'Abandonada',
  MissionStatus.cancelled => 'Cancelada',
  MissionStatus.partial => 'Parcial',
  MissionStatus.completed => 'Completada',
};

String missionTypeLabel(MissionType value) => switch (value) {
  MissionType.primary => 'Principal',
  MissionType.secondary => 'Secundaria',
  MissionType.errand => 'Diligencia',
  MissionType.daily => 'Diaria',
  MissionType.recurring => 'Recurrente',
  MissionType.event => 'Evento',
  MissionType.challenge => 'Desafío',
  MissionType.custom => 'Personalizada',
};

String missionDateLabel(DateTime? utc) {
  if (utc == null) {
    return 'Sin fecha';
  }
  final DateTime local = utc.toLocal();
  final String day = local.day.toString().padLeft(2, '0');
  final String month = local.month.toString().padLeft(2, '0');
  final String hour = local.hour.toString().padLeft(2, '0');
  final String minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} · $hour:$minute';
}

String missionScheduleLabel(Mission mission) {
  final DateTime? utc = mission.scheduledAtUtc;
  if (utc == null) {
    return 'Sin fecha';
  }
  final DateTime local = utc.toLocal();
  final String day = local.day.toString().padLeft(2, '0');
  final String month = local.month.toString().padLeft(2, '0');
  final String date = '$day/$month/${local.year}';
  if (mission.isDateOnly) {
    return '$date · Sin hora';
  }
  final String hour = local.hour.toString().padLeft(2, '0');
  final String minute = local.minute.toString().padLeft(2, '0');
  return '$date · $hour:$minute';
}

String missionMoneyLabel(int minor) {
  final double value = minor / 100;
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

String missionMoneyDisplay(BuildContext context, int minor) =>
    context.uiPreferences.hideAmounts
    ? 'Bs •••'
    : 'Bs ${missionMoneyLabel(minor)}';

String missionDurationLabel(int totalSeconds) {
  final int safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
  final int hours = safeSeconds ~/ 3600;
  final int minutes = (safeSeconds % 3600) ~/ 60;
  final int seconds = safeSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

String missionConvenienceLabel(ConvenienceRating value) => switch (value) {
  ConvenienceRating.totallyWorthIt => 'Valió completamente la pena',
  ConvenienceRating.worthItButCostly => 'Valió la pena, pero fue costosa',
  ConvenienceRating.partiallyWorthIt => 'Valió parcialmente la pena',
  ConvenienceRating.barelyWorthIt => 'No valió demasiado',
  ConvenienceRating.wouldNotRepeat => 'No lo repetiría',
};

String completionPaymentMethodLabel(CompletionPaymentMethod value) =>
    switch (value) {
      CompletionPaymentMethod.cash => 'Efectivo',
      CompletionPaymentMethod.bank => 'Banco',
      CompletionPaymentMethod.wallet => 'Billetera',
    };

String completionMovementTypeLabel(CompletionMovementType value) =>
    switch (value) {
      CompletionMovementType.expense => 'Gasto',
      CompletionMovementType.income => 'Ingreso',
    };
