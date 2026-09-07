/// Qué clase de alarma es, para que el receiver de arranque sepa qué texto
/// genérico usar sin abrir la base cifrada.
///
/// No es contenido del usuario: no dice qué misión es ni cuántas hay, solo de
/// qué tipo de aviso se trata.
enum MissionNotificationKind {
  mission('mission'),
  dailySummary('dailySummary');

  const MissionNotificationKind(this.wireName);

  final String wireName;
}

final class MissionNotificationRequest {
  const MissionNotificationRequest({
    required this.scheduleId,
    required this.notifyAtUtcMs,
    required this.soundEnabled,
    required this.showDetails,
    this.missionTitle,
    this.contentText,
    this.systemNotificationId,
    this.kind = MissionNotificationKind.mission,
  });

  final String scheduleId;
  final int notifyAtUtcMs;
  final bool soundEnabled;
  final bool showDetails;
  final String? missionTitle;

  /// Texto ya cocinado en Dart, para avisos que no son de una misión concreta.
  ///
  /// Lo usa el resumen diario: su recuento se calcula con la aplicación
  /// desbloqueada y viaja hasta la alarma, porque el receiver que la entrega no
  /// puede abrir la base cifrada.
  final String? contentText;

  final int? systemNotificationId;
  final MissionNotificationKind kind;
}

/// Una alarma tal y como sobrevive a un reinicio del teléfono.
///
/// Android borra las alarmas de `AlarmManager` al arrancar, y el receiver que
/// las repone no puede abrir la base cifrada: por ADR-002 sigue cerrada hasta
/// que el usuario introduce su PIN. Por eso este espejo vive fuera de la base.
///
/// **No lleva el título de la misión, ni el recuento del resumen, ni ningún
/// otro contenido, y no debe llevarlo nunca.** Es el término exacto que el
/// usuario aceptó el 7 de septiembre de 2026 al aprobar el espejo. La
/// consecuencia visible es que, tras un reinicio y hasta que se abra la
/// aplicación, los avisos salen con texto genérico.
///
/// [kind] es la única ampliación posterior, y no rompe ese trato: distingue un
/// recordatorio de misión de un resumen diario para poder darles textos
/// genéricos distintos. No revela nada de la base.
final class MissionNotificationMirrorEntry {
  const MissionNotificationMirrorEntry({
    required this.scheduleId,
    required this.systemNotificationId,
    required this.notifyAtUtcMs,
    required this.soundEnabled,
    required this.showDetails,
    this.kind = MissionNotificationKind.mission,
  });

  final String scheduleId;
  final int systemNotificationId;
  final int notifyAtUtcMs;
  final bool soundEnabled;
  final bool showDetails;
  final MissionNotificationKind kind;
}

abstract interface class MissionNotificationPlatform {
  Future<bool> requestPermission();

  Future<int> schedule(MissionNotificationRequest request);

  Future<int> deliverIfNeeded(MissionNotificationRequest request);

  Future<void> cancel(int systemNotificationId);

  /// Reemplaza el espejo de arranque con el conjunto completo de alarmas vivas.
  ///
  /// Una lista vacía lo borra, que es lo correcto cuando no queda ninguna
  /// alarma programada.
  Future<void> syncBootMirror(List<MissionNotificationMirrorEntry> entries);
}
