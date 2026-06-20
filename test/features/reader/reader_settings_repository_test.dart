import 'package:al_quran/features/reader/data/repositories/reader_settings_repository_impl.dart';
import 'package:al_quran/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ReaderSettingsRepositoryImpl> _repo() async {
  SharedPreferences.setMockInitialValues(const {});
  return ReaderSettingsRepositoryImpl(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderSettingsRepository', () {
    test('defaults: 28pt font, Mushaf (not detailed)', () async {
      final repo = await _repo();
      expect(repo.fontSize, ReaderSettingsRepository.defaultFontSize);
      expect(repo.fontSize, 28);
      expect(repo.detailed, isFalse);
    });

    test('persists the font size', () async {
      final repo = await _repo();
      await repo.setFontSize(42);
      expect(repo.fontSize, 42);
    });

    test('persists the viewport preference', () async {
      final repo = await _repo();
      await repo.setDetailed(true);
      expect(repo.detailed, isTrue);
      await repo.setDetailed(false);
      expect(repo.detailed, isFalse);
    });
  });
}
