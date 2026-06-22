import 'package:al_quran/features/reader/data/repositories/last_read_repository_impl.dart';
import 'package:al_quran/features/reader/domain/entities/last_read.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LastReadRepositoryImpl> _repo() async {
  SharedPreferences.setMockInitialValues(const {});
  return LastReadRepositoryImpl(await SharedPreferences.getInstance());
}

LastRead _lr(
  ReaderTarget target, {
  int ayahId = 1,
  int surahId = 1,
  int ayah = 1,
  bool detailed = false,
}) =>
    LastRead(
      target: target,
      ayahId: ayahId,
      surahId: surahId,
      ayahNumber: ayah,
      detailed: detailed,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LastReadRepository', () {
    test('returns null when nothing has been read', () async {
      final repo = await _repo();
      expect(await repo.load(), isNull);
    });

    test('round-trips a surah target with the exact verse', () async {
      final repo = await _repo();
      final lr = _lr(
        const ReaderTarget.surah(2, 'Al-Baqarah'),
        ayahId: 262,
        surahId: 2,
        ayah: 255,
      );
      await repo.save(lr);
      expect(await repo.load(), lr);
    });

    test('round-trips an index target with its verse', () async {
      final repo = await _repo();
      final lr =
          _lr(const ReaderTarget.juz(5), ayahId: 600, surahId: 4, ayah: 24);
      await repo.save(lr);
      expect(await repo.load(), lr);
    });

    test('round-trips the viewport (Detailed) so resume reopens it', () async {
      final repo = await _repo();
      final lr = _lr(
        const ReaderTarget.surah(2, 'Al-Baqarah'),
        ayahId: 262,
        surahId: 2,
        ayah: 255,
        detailed: true,
      );
      await repo.save(lr);
      final loaded = await repo.load();
      expect(loaded, lr);
      expect(loaded!.detailed, isTrue);
    });

    test('a record without a viewport flag loads as Reading', () async {
      SharedPreferences.setMockInitialValues(const {
        'last_read_dimension': 0,
        'last_read_value': 2,
        'last_read_title': 'Al-Baqarah',
        'last_read_ayah_id': 262,
        'last_read_surah_id': 2,
        'last_read_ayah_number': 255,
        // no last_read_detailed key (older record)
      });
      final repo =
          LastReadRepositoryImpl(await SharedPreferences.getInstance());
      expect((await repo.load())!.detailed, isFalse);
    });

    test('latest save wins', () async {
      final repo = await _repo();
      await repo.save(_lr(const ReaderTarget.page(100)));
      final latest = _lr(const ReaderTarget.hizb(7), ayahId: 900);
      await repo.save(latest);
      expect(await repo.load(), latest);
    });

    test('a pre-verse record (older version) loads as null', () async {
      SharedPreferences.setMockInitialValues(const {
        'last_read_dimension': 0,
        'last_read_value': 2,
        'last_read_title': 'Al-Baqarah',
        // no verse keys
      });
      final repo =
          LastReadRepositoryImpl(await SharedPreferences.getInstance());
      expect(await repo.load(), isNull);
    });
  });
}
