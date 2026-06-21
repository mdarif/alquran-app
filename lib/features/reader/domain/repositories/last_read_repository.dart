import '../entities/last_read.dart';

/// Persists where the user left off so they can resume at the exact verse
/// (PRD §12 backlog: last-read resume).
abstract interface class LastReadRepository {
  Future<void> save(LastRead value);

  /// The last read position, or null if nothing has been read yet.
  Future<LastRead?> load();
}
