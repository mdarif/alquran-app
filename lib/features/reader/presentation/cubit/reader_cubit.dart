import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/ayah.dart';
import '../../domain/entities/last_read.dart';
import '../../domain/entities/reader_target.dart';
import '../../domain/entities/surah_heading.dart';
import '../../domain/entities/translation_resource.dart';
import '../../domain/reader_navigation.dart';
import '../../domain/repositories/ayah_repository.dart';
import '../../domain/repositories/last_read_repository.dart';

part 'reader_state.dart';

class ReaderCubit extends Cubit<ReaderState> {
  ReaderCubit(this._repository, this._lastRead) : super(const ReaderState());

  final AyahRepository _repository;
  final LastReadRepository _lastRead;

  /// The section currently shown — needed to record last-read progress.
  ReaderTarget? _target;

  /// The viewport the reader is in (true = Detailed) and the last verse reported,
  /// so Last Read records which view to resume in — and so a viewport switch
  /// re-stamps the existing resume point with the new view.
  bool _detailed = false;
  Ayah? _lastAyah;

  /// How long a freshly opened section must stay on screen before its first
  /// verse is written as the resume point. Long enough that browsing the TOC or
  /// flinging between surahs leaves Continue Reading alone, short enough that
  /// actually settling in to read is recorded even without a scroll.
  static const Duration openDwell = Duration(seconds: 3);
  Timer? _openStampTimer;

  // --- Section cache (keeps swipes instant) ---------------------------------
  // The translation editions and surah headers are mushaf-wide constants, so we
  // fetch them once and reuse. Ayahs are cached per section and the immediate
  // neighbours are warmed in the background, so swiping to an adjacent section
  // resolves from memory — no DB round-trip, no loading flash, no stutter under
  // the slide animation.
  List<TranslationResource>? _resources;
  Map<int, SurahHeading>? _headings;
  final Map<String, List<Ayah>> _ayahCache = {};
  final List<String> _cacheOrder = []; // LRU, oldest first
  static const int _cacheCap = 7;

  String _key(ReaderTarget t) => '${t.dimension.index}:${t.value}';

  /// Warmed ayahs for [target], or null if not cached yet. Lets the reader render
  /// the peeking neighbour during a finger-following swipe without a DB round
  /// trip (the neighbours are prefetched after every [load]).
  List<Ayah>? cachedAyahs(ReaderTarget target) => _ayahCache[_key(target)];

  /// Load [target] into the cache in the background if it isn't there yet — used
  /// when a fast swipe outruns the automatic neighbour prefetch. An empty entry
  /// counts as missing (the page renders nothing from it), so it is refetched
  /// rather than left to spin forever.
  void warm(ReaderTarget target) {
    final cached = _ayahCache[_key(target)];
    if (cached == null || cached.isEmpty) {
      unawaited(_warm(target, notifyListeners: true));
    }
  }

  /// Drop every cached section. Call when the underlying text changes (e.g. the
  /// Arabic script switches column) so neighbours re-fetch instead of serving a
  /// stale render.
  void clearCache() {
    _ayahCache.clear();
    _cacheOrder.clear();
  }

  Future<void> refreshTranslations() async {
    _resources = null;
    clearCache();
    final target = _target;
    if (target == null) return;
    await load(target);
  }

  Future<void> load(ReaderTarget target) async {
    _target = target;
    final key = _key(target);
    final cached = _ayahCache[key];
    if (cached != null && cached.isNotEmpty) {
      // Cache hit: skip the loading emit so the section key flips at once and
      // the slide animation starts immediately. The constants are present
      // because a prior load already warmed this entry.
      _touch(key);
      emit(
        state.copyWith(
          status: ReaderStatus.loaded,
          ayahs: cached,
          resources: _resources ?? state.resources,
          headings: _headings ?? state.headings,
        ),
      );
      if (cached.isNotEmpty) _stampOpen(cached.first);
      _prefetchNeighbours(target);
      return;
    }

    emit(state.copyWith(status: ReaderStatus.loading));
    try {
      // The constants are fetched once and reused on every later section.
      final resources =
          _resources ??= await _repository.getTranslationResources();
      final headings = _headings ??= await _repository.getSurahHeadings();
      final ayahs = await _repository.getAyahs(target);
      _store(key, ayahs);
      emit(
        state.copyWith(
          status: ReaderStatus.loaded,
          ayahs: ayahs,
          resources: resources,
          headings: headings,
        ),
      );
      // Remember the resume point: the section opened, at its first verse until
      // the user scrolls (then [saveProgress] refines it) — written only once
      // the reader has dwelt here, so a peek doesn't overwrite it.
      if (ayahs.isNotEmpty) _stampOpen(ayahs.first);
      _prefetchNeighbours(target);
    } catch (e) {
      emit(state.copyWith(status: ReaderStatus.error, error: e.toString()));
    }
  }

  /// Warm the two adjacent sections (previous + next) into the cache in the
  /// background, so the next swipe is served from memory. Best-effort: a failure
  /// just means that swipe loads on demand.
  void _prefetchNeighbours(ReaderTarget target) {
    final headings = _headings;
    if (headings == null) return;
    for (final delta in const [-1, 1]) {
      final next = adjacentTarget(target, delta, headings);
      if (next == null || _ayahCache.containsKey(_key(next))) continue;
      // Speculative neighbours are not represented by a visible spinner, so
      // completing them must not rebuild the active reader mid-gesture.
      unawaited(_warm(next, notifyListeners: false));
    }
  }

  Future<void> _warm(
    ReaderTarget target, {
    required bool notifyListeners,
  }) async {
    try {
      _store(_key(target), await _repository.getAyahs(target));
      // An explicit warm comes from a page showing a cache-miss spinner, so bump
      // the epoch to let it recover. Speculative neighbour prefetches have no
      // waiting UI and stay silent. Guarded because either can outlive the reader.
      if (notifyListeners && !isClosed) {
        emit(state.copyWith(cacheEpoch: state.cacheEpoch + 1));
      }
    } catch (_) {
      // Ignore — the swipe will simply fall back to an on-demand load.
    }
  }

  void _store(String key, List<Ayah> ayahs) {
    _ayahCache[key] = ayahs;
    _touch(key);
    // Evict oldest-first, but never the section being read. A fast multi-page
    // fling fires many racing loads/warms; stragglers completing AFTER the
    // settled section's store used to push it out of the LRU — the on-screen
    // widget kept rendering (it holds the list), but the next cache read (e.g.
    // the Reading⇄Detailed toggle) missed and stuck on a spinner.
    final current = _target == null ? null : _key(_target!);
    var i = 0;
    while (_cacheOrder.length > _cacheCap && i < _cacheOrder.length) {
      final victim = _cacheOrder[i];
      if (victim == current) {
        i++; // skip the live section; evict the next-oldest instead
        continue;
      }
      _cacheOrder.removeAt(i);
      _ayahCache.remove(victim);
    }
  }

  void _touch(String key) {
    _cacheOrder
      ..remove(key)
      ..add(key);
  }

  /// Records the active viewport (true = Detailed) so Last Read resumes in the
  /// same view. Re-stamps the existing resume point when it changes, so leaving
  /// right after switching views still records the new view.
  void setViewportDetailed(bool detailed) {
    if (_detailed == detailed) return;
    _detailed = detailed;
    final ayah = _lastAyah;
    if (ayah != null) saveProgress(ayah);
  }

  /// Provisionally marks a freshly opened section at [ayah] (its first verse),
  /// but only persists it once the reader has *dwelt* here — see [openDwell].
  /// Peeking at a surah from the TOC, or flinging through several sections, must
  /// not destroy a deep resume point ("Continue Reading: Al-Baqarah 255" is worth
  /// more than a two-second glance at Al-Fatihah). Any real signal — a scroll
  /// report, a resume pin, a viewport toggle — goes through [saveProgress] and
  /// writes at once, cancelling this.
  void _stampOpen(Ayah ayah) {
    _lastAyah = ayah;
    _openStampTimer?.cancel();
    final target = _target;
    if (target == null) return;
    _openStampTimer = Timer(openDwell, () => _persist(target, ayah));
  }

  /// Records [ayah] as the last-read verse within the current section, so the
  /// home "Last Read" card resumes exactly here (in the current viewport).
  void saveProgress(Ayah ayah) {
    // A definite position supersedes any pending open stamp — including a
    // just-scheduled first-verse one, which must never land on top of it.
    _openStampTimer?.cancel();
    _lastAyah = ayah;
    final target = _target;
    if (target == null) return;
    _persist(target, ayah);
  }

  void _persist(ReaderTarget target, Ayah ayah) {
    unawaited(
      _lastRead.save(
        LastRead(
          target: target,
          ayahId: ayah.id,
          surahId: ayah.surahId,
          ayahNumber: ayah.ayahNumber,
          detailed: _detailed,
        ),
      ),
    );
  }

  @override
  Future<void> close() {
    // Leaving before the dwell elapsed means this was a peek, not a read — drop
    // the pending stamp (and never let a timer outlive the cubit).
    _openStampTimer?.cancel();
    return super.close();
  }
}
