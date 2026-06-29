import 'package:al_quran/core/database/app_database.dart';
import 'package:al_quran/core/feature_flags.dart';
import 'package:al_quran/features/reader/data/repositories/ayah_repository_impl.dart';
import 'package:al_quran/features/reader/domain/entities/arabic_script.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:al_quran/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Settings fake — only [script] drives column selection; the rest is inert.
class _Settings implements ReaderSettingsRepository {
  _Settings(this.script);
  @override
  ArabicScript script;
  @override
  Future<void> setScript(ArabicScript value) async => script = value;
  @override
  double get fontSize => 28;
  @override
  bool get detailed => false;
  @override
  List<String>? get selectedTranslations => null;
  @override
  bool get readingTranslationVisible => true;
  @override
  Future<void> setFontSize(double value) async {}
  @override
  Future<void> setDetailed(bool value) async {}
  @override
  Future<void> setSelectedTranslations(List<String> codes) async {}
  @override
  Future<void> setReadingTranslationVisible(bool value) async {}
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Prod onCreate is a deliberate no-op (the seed DB already has the tables),
    // so an in-memory DB must create the schema itself.
    await db.createMigrator().createAll();
    // Ayah 1 carries BOTH scripts; ayah 2 has NO IndoPak text (column NULL).
    await db.into(db.ayahs).insert(
          AyahsCompanion.insert(
            id: const Value(1),
            surahId: 1,
            ayahNumber: 1,
            textArabicUthmani: 'UTHMANI-1',
            textArabicIndopak: const Value('INDOPAK-1'),
          ),
        );
    await db.into(db.ayahs).insert(
          AyahsCompanion.insert(
            id: const Value(2),
            surahId: 1,
            ayahNumber: 2,
            textArabicUthmani: 'UTHMANI-2',
          ),
        );
  });
  tearDown(() => db.close());

  Future<String> textFor(int ayahNumber, ArabicScript script) async {
    final repo = AyahRepositoryImpl(db, _Settings(script));
    final ayahs =
        await repo.getAyahs(const ReaderTarget.surah(1, 'Al-Fatihah'));
    return ayahs.firstWhere((a) => a.ayahNumber == ayahNumber).textArabic;
  }

  test('Uthmani script reads the Uthmani column', () async {
    expect(await textFor(1, ArabicScript.uthmani), 'UTHMANI-1');
  });

  test('IndoPak script reads the IndoPak column (when the feature is on)',
      () async {
    // Robust to the compile-time flag: IndoPak text only when the flag is on,
    // otherwise the gate keeps it on Uthmani.
    const expected = FeatureFlags.indopakScript ? 'INDOPAK-1' : 'UTHMANI-1';
    expect(await textFor(1, ArabicScript.indopak), expected);
  });

  test('IndoPak script falls back to Uthmani when the IndoPak column is null',
      () async {
    expect(await textFor(2, ArabicScript.indopak), 'UTHMANI-2');
  });
}
