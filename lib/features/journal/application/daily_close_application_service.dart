import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../domain/models/daily_close.dart';
import '../domain/models/journal_entry.dart';
import '../domain/repositories/daily_close_repository.dart';
import '../domain/repositories/journal_repository.dart';
import 'journal_application_service.dart';

final class DailyCloseViewData {
  const DailyCloseViewData({required this.summary, this.reflectionEntry});

  final DailyCloseSummary summary;
  final JournalEntry? reflectionEntry;
}

final class DailyCloseApplicationService {
  const DailyCloseApplicationService({
    required DailyCloseRepository dailyCloseRepository,
    required JournalRepository journalRepository,
    required JournalClock clock,
  }) : _dailyCloseRepository = dailyCloseRepository,
       _journalRepository = journalRepository,
       _clock = clock;

  static const int maxReflectionLength = 4000;

  final DailyCloseRepository _dailyCloseRepository;
  final JournalRepository _journalRepository;
  final JournalClock _clock;

  Future<Result<DailyCloseViewData>> load(DateTime localDay) async {
    final period = dailyClosePeriod(localDay);
    final summaryResult = await _dailyCloseRepository.loadSummary(
      dayStartUtc: period.startUtc,
      dayEndUtc: period.endUtc,
      referenceUtc: _clock.nowUtc(),
    );
    if (summaryResult is Failure<DailyCloseSummary>) {
      return Failure<DailyCloseViewData>(summaryResult.failure);
    }
    final entryResult = await _journalRepository.findById(
      dailyCloseEntryId(localDay),
    );
    if (entryResult is Failure<JournalEntry?>) {
      return Failure<DailyCloseViewData>(entryResult.failure);
    }
    return Success<DailyCloseViewData>(
      DailyCloseViewData(
        summary: (summaryResult as Success<DailyCloseSummary>).value,
        reflectionEntry: (entryResult as Success<JournalEntry?>).value,
      ),
    );
  }

  Future<Result<JournalEntry?>> saveReflection({
    required DateTime localDay,
    required String reflection,
  }) async {
    final String normalized = reflection.trim();
    if (normalized.length > maxReflectionLength) {
      return const Failure<JournalEntry?>(
        ValidationFailure('La reflexión no debe superar 4000 caracteres.'),
      );
    }
    final String entryId = dailyCloseEntryId(localDay);
    final existingResult = await _journalRepository.findById(entryId);
    if (existingResult is Failure<JournalEntry?>) {
      return Failure<JournalEntry?>(existingResult.failure);
    }
    final JournalEntry? existing =
        (existingResult as Success<JournalEntry?>).value;
    if (existing == null && normalized.isEmpty) {
      return const Success<JournalEntry?>(null);
    }

    final DateTime nowUtc = _clock.nowUtc();
    final DateTime occurredAtUtc = DateTime(
      localDay.year,
      localDay.month,
      localDay.day,
      20,
    ).toUtc();
    final JournalEntry entry = JournalEntry(
      id: entryId,
      origin: JournalOrigin.system,
      title: dailyCloseTitle(localDay),
      body: normalized.isEmpty ? null : normalized,
      mood: existing?.mood,
      isPrivate: true,
      occurredAtUtc: occurredAtUtc,
      createdAtUtc: existing?.createdAtUtc ?? nowUtc,
      updatedAtUtc: nowUtc,
      attachmentCount: existing?.attachmentCount ?? 0,
      archivedAtUtc: existing?.archivedAtUtc,
    );
    final Result<JournalEntry> result = existing == null
        ? await _journalRepository.create(entry)
        : await _journalRepository.update(entry);
    return result.fold<Result<JournalEntry?>>(
      onSuccess: (saved) => Success<JournalEntry?>(saved),
      onFailure: (failure) => Failure<JournalEntry?>(failure),
    );
  }
}

typedef DailyClosePeriod = ({DateTime startUtc, DateTime endUtc});

DailyClosePeriod dailyClosePeriod(DateTime localDay) => (
  startUtc: DateTime(localDay.year, localDay.month, localDay.day).toUtc(),
  endUtc: DateTime(localDay.year, localDay.month, localDay.day + 1).toUtc(),
);

String dailyCloseDateKey(DateTime localDay) =>
    '${localDay.year.toString().padLeft(4, '0')}-'
    '${localDay.month.toString().padLeft(2, '0')}-'
    '${localDay.day.toString().padLeft(2, '0')}';

String dailyCloseEntryId(DateTime localDay) =>
    'daily-close:${dailyCloseDateKey(localDay)}';

String dailyCloseTitle(DateTime localDay) =>
    'Cierre diario · ${localDay.day.toString().padLeft(2, '0')}/'
    '${localDay.month.toString().padLeft(2, '0')}/${localDay.year}';

DateTime? parseDailyCloseDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    return null;
  }
  final int year = int.parse(match.group(1)!);
  final int month = int.parse(match.group(2)!);
  final int day = int.parse(match.group(3)!);
  final DateTime parsed = DateTime(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day
      ? parsed
      : null;
}
