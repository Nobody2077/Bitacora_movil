sealed class AppFailure implements Exception {
  const AppFailure(this.code, this.message, {this.cause});

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType($code): $message';
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(String message)
    : super('validation_failure', message);
}

final class ConflictFailure extends AppFailure {
  const ConflictFailure(String message) : super('conflict_failure', message);
}

final class ActiveTimerFailure extends AppFailure {
  const ActiveTimerFailure({required this.activeMissionId})
    : super(
        'active_timer_failure',
        'Ya existe otra misión con el cronómetro activo.',
      );

  final String activeMissionId;
}

final class StorageFailure extends AppFailure {
  const StorageFailure(String message, {Object? cause})
    : super('storage_failure', message, cause: cause);
}

final class PermissionFailure extends AppFailure {
  const PermissionFailure(String message)
    : super('permission_failure', message);
}

final class CorruptBackupFailure extends AppFailure {
  const CorruptBackupFailure(String message)
    : super('corrupt_backup_failure', message);
}

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(String message, {Object? cause})
    : super('unexpected_failure', message, cause: cause);
}
