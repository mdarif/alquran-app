import 'dart:async';

import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/last_read.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:al_quran/features/reader/domain/entities/surah_heading.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/last_read_repository.dart';
import 'package:al_quran/features/reader/presentation/cubit/reader_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLastReadRepository implements LastReadRepository {
  LastRead? saved;

  @override
  Future<void> save(LastRead value) async => saved = value;

  @override
  Future<LastRead?> load() async => saved;
}

class _FakeAyahRepository implements AyahRepository {
  _FakeAyahRepository({
    this.ayahs = const [],
    this.resources = const [],
    this.error,
  });

  final List<Ayah> ayahs;
  final List<TranslationResource> resources;
  final Object? error;

  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async {
    if (error != null) throw error!;
    return ayahs;
  }

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async {
    if (error != null) throw error!;
    return const {};
  }

  @override
  Future<List<TranslationResource>> getTranslationResources() async {
    if (error != null) throw error!;
    return resources;
  }
}

/// Records every getAyahs call and returns a distinct ayah per section, so a
/// test can tell an on-demand fetch from a cache hit.
class _CountingAyahRepository implements AyahRepository {
  final List<int> fetched = [];

  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async {
    fetched.add(target.value);
    return [
      Ayah(
        id: target.value,
        surahId: target.value,
        ayahNumber: 1,
        textArabic: 'x',
        isSajda: false,
      ),
    ];
  }

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => const {};

  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [];
}

const _urdu = TranslationResource(id: 1, languageCode: 'ur', name: 'Junagarhi');
const _ayah = Ayah(
  id: 1,
  surahId: 1,
  ayahNumber: 1,
  textArabic: 'بِسْمِ ٱللَّهِ',
  isSajda: false,
  translations: {1: 'اللہ کے نام سے'},
);

void main() {
  group('ReaderCubit', () {
    test('initial state is ReaderStatus.initial', () {
      final cubit =
          ReaderCubit(_FakeAyahRepository(), _FakeLastReadRepository());
      expect(cubit.state.status, ReaderStatus.initial);
      expect(cubit.state.ayahs, isEmpty);
      expect(cubit.state.resources, isEmpty);
      cubit.close();
    });

    test('load() emits loading then loaded with ayahs and resources', () async {
      final cubit = ReaderCubit(
        _FakeAyahRepository(ayahs: const [_ayah], resources: const [_urdu]),
        _FakeLastReadRepository(),
      );

      final expectation = expectLater(
        cubit.stream.map((s) => s.status),
        emitsInOrder([ReaderStatus.loading, ReaderStatus.loaded]),
      );

      await cubit.load(const ReaderTarget.surah(1, 'Al-Fatihah'));
      await expectation;

      expect(cubit.state.ayahs, const [_ayah]);
      expect(cubit.state.resources, const [_urdu]);
      expect(cubit.state.error, isNull);
      await cubit.close();
    });

    test('load() records the section opened at its first verse', () async {
      final lastRead = _FakeLastReadRepository();
      final cubit = ReaderCubit(
        _FakeAyahRepository(ayahs: const [_ayah]),
        lastRead,
      );
      await cubit.load(const ReaderTarget.surah(1, 'Al-Fatihah'));

      expect(lastRead.saved?.target, const ReaderTarget.surah(1, 'Al-Fatihah'));
      expect(lastRead.saved?.ayahId, 1);
      await cubit.close();
    });

    test('saveProgress records the exact verse within the section', () async {
      final lastRead = _FakeLastReadRepository();
      final cubit = ReaderCubit(
        _FakeAyahRepository(ayahs: const [_ayah]),
        lastRead,
      );
      await cubit.load(const ReaderTarget.surah(2, 'Al-Baqarah'));
      cubit.saveProgress(
        const Ayah(
          id: 262,
          surahId: 2,
          ayahNumber: 255,
          textArabic: 'x',
          isSajda: false,
        ),
      );

      expect(lastRead.saved?.ayahId, 262);
      expect(lastRead.saved?.surahId, 2);
      expect(lastRead.saved?.ayahNumber, 255);
      expect(lastRead.saved?.detailed, isFalse); // Reading by default
      await cubit.close();
    });

    test('saveProgress records the active viewport (Detailed)', () async {
      final lastRead = _FakeLastReadRepository();
      final cubit = ReaderCubit(
        _FakeAyahRepository(ayahs: const [_ayah]),
        lastRead,
      );
      await cubit.load(const ReaderTarget.surah(2, 'Al-Baqarah'));
      cubit.setViewportDetailed(true);
      cubit.saveProgress(
        const Ayah(
          id: 262,
          surahId: 2,
          ayahNumber: 255,
          textArabic: 'x',
          isSajda: false,
        ),
      );

      expect(lastRead.saved?.detailed, isTrue);
      await cubit.close();
    });

    test('switching viewport re-stamps the existing resume point', () async {
      final lastRead = _FakeLastReadRepository();
      final cubit = ReaderCubit(
        _FakeAyahRepository(ayahs: const [_ayah]),
        lastRead,
      );
      await cubit.load(const ReaderTarget.surah(2, 'Al-Baqarah'));
      cubit.saveProgress(
        const Ayah(
          id: 262,
          surahId: 2,
          ayahNumber: 255,
          textArabic: 'x',
          isSajda: false,
        ),
      );
      expect(lastRead.saved?.detailed, isFalse);

      // Switching to Detailed re-saves the same verse with the new viewport,
      // so leaving immediately still records Detailed.
      cubit.setViewportDetailed(true);
      expect(lastRead.saved?.ayahId, 262);
      expect(lastRead.saved?.detailed, isTrue);
      await cubit.close();
    });

    test('prefetches neighbours so an adjacent load is served from cache',
        () async {
      final repo = _CountingAyahRepository();
      final cubit = ReaderCubit(repo, _FakeLastReadRepository());

      await cubit.load(const ReaderTarget.surah(1, 'Al-Fatihah'));
      // Let the background neighbour prefetch settle.
      await Future<void>.delayed(Duration.zero);
      // Surah 1 fetched on demand; surah 2 warmed in the background (surah 0 is
      // out of bounds, so only the forward neighbour is fetched).
      expect(repo.fetched, containsAll(<int>[1, 2]));

      // Swiping to surah 2 is served from the warm cache: no loading flash (it
      // emits loaded straight away) and no second fetch for surah 2.
      final statuses = <ReaderStatus>[];
      final sub = cubit.stream.listen((s) => statuses.add(s.status));
      await cubit.load(const ReaderTarget.surah(2, 'Al-Baqarah'));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(statuses.first, ReaderStatus.loaded); // skipped the loading state
      expect(
        repo.fetched.where((v) => v == 2).length,
        1,
      ); // fetched once (warm)
      expect(
        repo.fetched,
        contains(3),
      ); // surah 3 now warmed for the next swipe
      await cubit.close();
    });

    test('clearCache drops cached sections so a reload re-fetches', () async {
      final repo = _CountingAyahRepository();
      final cubit = ReaderCubit(repo, _FakeLastReadRepository());

      await cubit.load(const ReaderTarget.surah(1, 'Al-Fatihah'));
      // Settle the neighbour prefetch.
      await Future<void>.delayed(Duration.zero);
      expect(repo.fetched.where((v) => v == 1).length, 1);

      // A script switch clears the cache so neighbours/sections re-read the new
      // text column instead of serving the stale render.
      cubit.clearCache();
      await cubit.load(const ReaderTarget.surah(1, 'Al-Fatihah'));
      expect(
        repo.fetched.where((v) => v == 1).length,
        2,
        reason:
            'surah 1 should be re-fetched after clearCache, not served stale',
      );
      await cubit.close();
    });

    test('load() emits loading then error when the repository throws',
        () async {
      final cubit = ReaderCubit(
        _FakeAyahRepository(error: Exception('no surah 999')),
        _FakeLastReadRepository(),
      );

      final expectation = expectLater(
        cubit.stream.map((s) => s.status),
        emitsInOrder([ReaderStatus.loading, ReaderStatus.error]),
      );

      await cubit.load(const ReaderTarget.juz(99));
      await expectation;

      expect(cubit.state.error, contains('no surah 999'));
      await cubit.close();
    });
  });

  // Regressions for the v1.0.0 field bug: fast multi-page flings fire racing
  // loads/warms whose stragglers evicted the on-screen section from the LRU;
  // the next cache read (the Reading⇄Detailed toggle) then stuck on a spinner
  // forever, because warm() fills the cache without notifying the UI.
  group('ReaderCubit section cache (fast-fling regressions)', () {
    test('a background warm bumps cacheEpoch so cache-miss pages recover',
        () async {
      final repo = _CountingAyahRepository();
      final cubit = ReaderCubit(repo, _FakeLastReadRepository());
      await cubit.load(const ReaderTarget.surah(1, 'Al-Fatihah'));
      await Future<void>.delayed(Duration.zero);

      final before = cubit.state.cacheEpoch;
      cubit.warm(const ReaderTarget.surah(50, 'Qaf'));
      await Future<void>.delayed(Duration.zero);

      expect(
        cubit.cachedAyahs(const ReaderTarget.surah(50, 'Qaf')),
        isNotEmpty,
      );
      expect(
        cubit.state.cacheEpoch,
        greaterThan(before),
        reason: 'a silent warm must wake widgets that render from the cache, '
            'or a cache-miss spinner never resolves',
      );
      await cubit.close();
    });

    test('eviction never drops the section being read', () async {
      final repo = _CountingAyahRepository();
      final cubit = ReaderCubit(repo, _FakeLastReadRepository());
      // The reader settled on At-Tawbah (the section on screen).
      await cubit.load(const ReaderTarget.surah(9, 'At-Tawbah'));
      await Future<void>.delayed(Duration.zero);

      // A storm of straggler warms (a fast fling across many pages) lands
      // AFTER the settled section's store — far more than the cache cap.
      for (var s = 20; s < 40; s++) {
        cubit.warm(ReaderTarget.surah(s, 'Surah $s'));
      }
      await Future<void>.delayed(Duration.zero);

      // The viewport toggle re-reads the cache for the current section: it
      // must still be there (it used to get evicted → endless spinner).
      expect(
        cubit.cachedAyahs(const ReaderTarget.surah(9, 'At-Tawbah')),
        isNotEmpty,
        reason: 'the on-screen section must be immune to LRU eviction',
      );
      await cubit.close();
    });

    test('warm() and load() treat an empty cached entry as a miss', () async {
      final repo = _EmptyOnceAyahRepository();
      final cubit = ReaderCubit(repo, _FakeLastReadRepository());
      const target = ReaderTarget.surah(3, 'Aal-e-Imran');

      // First warm caches the (bad) empty result.
      cubit.warm(target);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.cachedAyahs(target), isEmpty);

      // A later warm must refetch rather than trust the empty entry (an empty
      // entry renders nothing — trusting it would spin forever).
      cubit.warm(target);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.cachedAyahs(target), isNotEmpty);

      // And load() must also refuse to treat empty as a hit.
      final repo2 = _EmptyOnceAyahRepository();
      final cubit2 = ReaderCubit(repo2, _FakeLastReadRepository());
      cubit2.warm(target);
      await Future<void>.delayed(Duration.zero);
      await cubit2.load(target);
      expect(cubit2.state.ayahs, isNotEmpty);

      await cubit.close();
      await cubit2.close();
    });

    test('a storm of concurrent loads settles on the last target, cached',
        () async {
      final repo = _CountingAyahRepository();
      final cubit = ReaderCubit(repo, _FakeLastReadRepository());

      // A power user flinging across many sections: every crossed page fires
      // load() without awaiting the previous one.
      for (var s = 2; s <= 12; s++) {
        unawaited(cubit.load(ReaderTarget.surah(s, 'Surah $s')));
      }
      // Let all loads + their neighbour prefetches settle.
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      // The state shows the LAST target and its section is (and stays) cached.
      expect(cubit.state.status, ReaderStatus.loaded);
      expect(cubit.state.ayahs.single.surahId, 12);
      expect(
        cubit.cachedAyahs(const ReaderTarget.surah(12, 'Surah 12')),
        isNotEmpty,
        reason: 'the settled section must survive the straggler stores',
      );
      await cubit.close();
    });
  });
}

/// Returns an empty ayah list on the first fetch, real data afterwards —
/// simulates a transient bad read being cached.
class _EmptyOnceAyahRepository implements AyahRepository {
  int _calls = 0;

  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async {
    _calls++;
    if (_calls == 1) return const [];
    return [
      Ayah(
        id: target.value,
        surahId: target.value,
        ayahNumber: 1,
        textArabic: 'x',
        isSajda: false,
      ),
    ];
  }

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => const {};

  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [];
}
