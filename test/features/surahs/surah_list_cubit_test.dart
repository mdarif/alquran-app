import 'package:al_quran/features/surahs/domain/entities/surah.dart';
import 'package:al_quran/features/surahs/domain/repositories/surah_repository.dart';
import 'package:al_quran/features/surahs/presentation/cubit/surah_list_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake so the cubit can be exercised without Drift/SQLite.
class _FakeSurahRepository implements SurahRepository {
  _FakeSurahRepository({this.surahs = const [], this.error});

  final List<Surah> surahs;
  final Object? error;

  @override
  Future<List<Surah>> getSurahs() async {
    if (error != null) throw error!;
    return surahs;
  }
}

const _alFatiha = Surah(
  id: 1,
  nameArabic: 'الفاتحة',
  nameEnglish: 'Al-Fatihah',
  totalAyahs: 7,
  revelationPlace: 'makkah',
);

void main() {
  group('SurahListCubit', () {
    test('initial state is SurahListStatus.initial with no surahs', () {
      final cubit = SurahListCubit(_FakeSurahRepository());
      expect(cubit.state.status, SurahListStatus.initial);
      expect(cubit.state.surahs, isEmpty);
      expect(cubit.state.error, isNull);
      cubit.close();
    });

    test('load() emits loading then loaded with surahs', () async {
      final cubit = SurahListCubit(
        _FakeSurahRepository(surahs: const [_alFatiha]),
      );

      final expectation = expectLater(
        cubit.stream.map((s) => s.status),
        emitsInOrder([SurahListStatus.loading, SurahListStatus.loaded]),
      );

      await cubit.load();
      await expectation;

      expect(cubit.state.surahs, const [_alFatiha]);
      expect(cubit.state.error, isNull);
      await cubit.close();
    });

    test('load() emits loading then error when the repository throws',
        () async {
      final cubit = SurahListCubit(
        _FakeSurahRepository(error: Exception('db unavailable')),
      );

      final expectation = expectLater(
        cubit.stream.map((s) => s.status),
        emitsInOrder([SurahListStatus.loading, SurahListStatus.error]),
      );

      await cubit.load();
      await expectation;

      expect(cubit.state.error, contains('db unavailable'));
      expect(cubit.state.surahs, isEmpty);
      await cubit.close();
    });
  });
}
