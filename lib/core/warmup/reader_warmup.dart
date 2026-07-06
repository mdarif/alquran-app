import 'package:get_it/get_it.dart';

import '../../features/reader/domain/repositories/ayah_repository.dart';
import '../../features/reader/domain/repositories/last_read_repository.dart';

/// Best-effort background prime of the reader's session caches so the first open
/// — especially "Continue reading", the most common daily open — is instant with
/// no loading flash. Reads run on the DB's background isolate; failures are
/// swallowed (the reader just loads on demand as before). Safe to call once at
/// launch, after the first frame, so it never competes with the TOC's own load.
Future<void> warmReaderCache() async {
  // Everything here is defensive: an isolated pump (widget test) may not register
  // the reader repos, and the DB read can fail — in every case the reader simply
  // loads on demand, exactly as before.
  final AyahRepository repo;
  try {
    repo = GetIt.I<AyahRepository>();
  } catch (_) {
    return;
  }
  // Mushaf-wide constants (headers + translation editions) — memoised in the
  // singleton repo, so this is the one query the first open would otherwise pay.
  try {
    await repo.getSurahHeadings();
    await repo.getTranslationResources();
  } catch (_) {
    // Reader still fetches these on demand.
  }
  // The verses of wherever the reader left off, so tapping "Continue reading"
  // resolves from cache instead of a DB round trip.
  try {
    final last = await GetIt.I<LastReadRepository>().load();
    if (last != null) await repo.getAyahs(last.target);
  } catch (_) {
    // No resume point, or it loads on demand.
  }
}
