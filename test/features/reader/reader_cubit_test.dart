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
}
