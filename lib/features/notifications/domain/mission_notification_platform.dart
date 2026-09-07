final class MissionNotificationRequest {
  const MissionNotificationRequest({
    required this.scheduleId,
    required this.notifyAtUtcMs,
    required this.soundEnabled,
    required this.showDetails,
    this.missionTitle,
    this.systemNotificationId,
  });

  final String scheduleId;
  final int notifyAtUtcMs;
  final bool soundEnabled;
  final bool showDetails;
  final String? missionTitle;
  final int? systemNotificationId;
}

/// Una alarma tal y como sobrevive a un reinicio del teléfono.
///
/// Android borra las alarmas de `AlarmManager` al arrancar, y el receiver que
/// las repone no puede abrir la base cifrada: por ADR-002 sigue cerrada hasta
/// que el usuario introduce su PIN. Por eso este espejo vive fuera de la base.
///
/// **No lleva el título de la misión, y no debe llevarlo nunca.** Es el término
/// exacto que el usuario aceptó el 7 de septiembre de 2026 al aprobar el
/// espejo. La consecuencia visible es que, tras un reinicio y hasta que se
/// abra la aplicación, los avisos salen con el texto genérico aunque «mostrar
/// detalles» esté activo.
final class MissionNotificationMirrorEntry {
  const MissionNotificationMirrorEntry({
    required this.scheduleId,
    required this.systemNotificationId,
    required this.notifyAtUtcMs,
    required this.soundEnabled,
    required this.showDetails,
  });

  final String scheduleId;
  final int systemNotificationId;
  final int notifyAtUtcMs;
  final bool soundEnabled;
  final bool showDetails;
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
