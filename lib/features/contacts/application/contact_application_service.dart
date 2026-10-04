import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../journal/application/journal_application_service.dart'
    show JournalClock, JournalIdGenerator;
import '../domain/models/contact.dart';
import '../domain/repositories/contact_repository.dart';

final class SaveContactRequest {
  const SaveContactRequest({
    this.existing,
    this.displayName,
    this.role,
    this.description,
  });

  final Contact? existing;
  final String? displayName;
  final String? role;
  final String? description;
}

/// Personajes del Diario. Usa el reloj y los ids del Diario porque viven
/// dentro de él (ADR-006 D7).
final class ContactApplicationService {
  const ContactApplicationService({
    required ContactRepository repository,
    required JournalClock clock,
    required JournalIdGenerator idGenerator,
  }) : _repository = repository,
       _clock = clock,
       _idGenerator = idGenerator;

  final ContactRepository _repository;
  final JournalClock _clock;
  final JournalIdGenerator _idGenerator;

  Future<Result<Contact>> save(SaveContactRequest request) async {
    final String? displayName = _blankToNull(request.displayName);
    final String? role = _blankToNull(request.role);
    final String? description = _blankToNull(request.description);
    if ((displayName?.length ?? 0) > Contact.maxDisplayNameLength) {
      return const Failure<Contact>(
        ValidationFailure(
          'El nombre admite hasta ${Contact.maxDisplayNameLength} caracteres.',
        ),
      );
    }
    if ((role?.length ?? 0) > Contact.maxRoleLength) {
      return const Failure<Contact>(
        ValidationFailure(
          'El rol admite hasta ${Contact.maxRoleLength} caracteres.',
        ),
      );
    }
    if ((description?.length ?? 0) > Contact.maxDescriptionLength) {
      return const Failure<Contact>(
        ValidationFailure(
          'La descripción admite hasta '
          '${Contact.maxDescriptionLength} caracteres.',
        ),
      );
    }

    final DateTime nowUtc = _clock.nowUtc();
    final Contact? existing = request.existing;
    if (existing == null) {
      return _repository.create(
        Contact(
          id: _idGenerator.nextId(),
          displayName: displayName,
          role: role,
          description: description,
          createdAtUtc: nowUtc,
          updatedAtUtc: nowUtc,
          rowVersion: 1,
        ),
      );
    }
    if (existing.isArchived) {
      return const Failure<Contact>(
        ConflictFailure('Restaura el personaje antes de editarlo.'),
      );
    }
    return _repository.update(
      Contact(
        id: existing.id,
        displayName: displayName,
        role: role,
        description: description,
        createdAtUtc: existing.createdAtUtc,
        updatedAtUtc: nowUtc,
        rowVersion: existing.rowVersion,
      ),
    );
  }

  /// «Eliminar» un personaje: se archiva y sus misiones y entradas siguen
  /// mostrándolo (ADR-006 D3).
  Future<Result<Contact>> archive(Contact contact) =>
      _repository.archive(contact, atUtc: _clock.nowUtc());

  Future<Result<Contact>> restore(Contact contact) =>
      _repository.restore(contact, atUtc: _clock.nowUtc());

  static String? _blankToNull(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
