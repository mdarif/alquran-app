import '../entities/reader_target.dart';

/// Persists the most recently opened reader target so the user can resume
/// (PRD §12 backlog: last-read resume).
abstract interface class LastReadRepository {
  Future<void> save(ReaderTarget target);

  /// The last opened target, or null if nothing has been read yet.
  Future<ReaderTarget?> load();
}
