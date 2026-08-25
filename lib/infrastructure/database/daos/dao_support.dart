final class DaoWriteResult<T> {
  const DaoWriteResult({required this.value, required this.created});

  final T value;
  final bool created;
}

sealed class DatabaseContractException implements Exception {
  const DatabaseContractException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class RecordNotFoundException extends DatabaseContractException {
  const RecordNotFoundException({required String table, required Object key})
    : super('$table record not found for key $key.');
}

final class OptimisticLockException extends DatabaseContractException {
  const OptimisticLockException({
    required String table,
    required String id,
    required int expectedRowVersion,
  }) : super('$table/$id no longer has row_version $expectedRowVersion.');
}

final class IdempotencyConflictException extends DatabaseContractException {
  const IdempotencyConflictException({
    required String operationId,
    required String entity,
  }) : super(
         'Operation $operationId already belongs to different $entity data.',
       );
}

final class DatabaseInvariantException extends DatabaseContractException {
  const DatabaseInvariantException(super.message);
}
