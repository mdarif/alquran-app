import 'package:al_quran/features/reader/data/repositories/last_read_repository_impl.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LastReadRepositoryImpl> _repo() async {
  SharedPreferences.setMockInitialValues(const {});
  return LastReadRepositoryImpl(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LastReadRepository', () {
    test('returns null when nothing has been read', () async {
      final repo = await _repo();
      expect(await repo.load(), isNull);
    });

    test('round-trips a surah target', () async {
      final repo = await _repo();
      await repo.save(const ReaderTarget.surah(2, 'Al-Baqarah'));
      expect(await repo.load(), const ReaderTarget.surah(2, 'Al-Baqarah'));
    });

    test('round-trips an index target', () async {
      final repo = await _repo();
      await repo.save(const ReaderTarget.juz(5));
      expect(await repo.load(), const ReaderTarget.juz(5));
    });

    test('latest save wins', () async {
      final repo = await _repo();
      await repo.save(const ReaderTarget.page(100));
      await repo.save(const ReaderTarget.hizb(7));
      expect(await repo.load(), const ReaderTarget.hizb(7));
    });
  });
}
