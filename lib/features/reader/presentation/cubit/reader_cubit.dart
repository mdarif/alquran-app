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
  /// when a fast swipe outruns the automatic neighbour prefetch.
  void warm(ReaderTarget target) {
    if (!_ayahCache.containsKey(_key(target))) unawaited(_warm(target));
  }

  /// Drop every cached section. Call when the underlying text changes (e.g. the
  /// Arabic script switches column) so neighbours re-fetch instead of serving a
  /// stale render.
  void clearCache() {
    _ayahCache.clear();
    _cacheOrder.clear();
  }

  Future<void> load(ReaderTarget target) async {
    _target = target;
    final key = _key(target);
    final cached = _ayahCache[key];
    if (cached != null) {
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
      if (cached.isNotEmpty) saveProgress(cached.first);
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
      // the user scrolls (then [saveProgress] refines it).
      if (ayahs.isNotEmpty) saveProgress(ayahs.first);
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
      unawaited(_warm(next));
    }
  }

  Future<void> _warm(ReaderTarget target) async {
    try {
      _store(_key(target), await _repository.getAyahs(target));
    } catch (_) {
      // Ignore — the swipe will simply fall back to an on-demand load.
    }
  }

  void _store(String key, List<Ayah> ayahs) {
    _ayahCache[key] = ayahs;
    _touch(key);
    while (_cacheOrder.length > _cacheCap) {
      _ayahCache.remove(_cacheOrder.removeAt(0));
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

  /// Records [ayah] as the last-read verse within the current section, so the
  /// home "Last Read" card resumes exactly here (in the current viewport).
  void saveProgress(Ayah ayah) {
    _lastAyah = ayah;
    final target = _target;
    if (target == null) return;
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
}
