import '../../../../core/database/app_database.dart';
import '../../../../core/feature_flags.dart';
import '../../domain/entities/arabic_script.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/reader_target.dart';
import '../../domain/entities/surah_heading.dart';
import '../../domain/entities/translation_resource.dart';
import '../../domain/repositories/ayah_repository.dart';
import '../../domain/repositories/reader_settings_repository.dart';

class AyahRepositoryImpl implements AyahRepository {
  AyahRepositoryImpl(this._db, this._settings);

  final AppDatabase _db;
  final ReaderSettingsRepository _settings;

  // Surah headers + translation editions are mushaf-wide constants that never
  // change with the script or section — but the ReaderCubit is a per-page
  // factory, so without this every reader open re-queried all 114 headings and
  // the resources. Memoise the FUTURE (this repo is a lazySingleton) so they hit
  // the DB once per session and concurrent openers share the same in-flight read.
  Future<Map<int, SurahHeading>>? _headingsFuture;
  Future<List<TranslationResource>>? _resourcesFuture;

  // Section verses, cached for the session so a re-open (or a neighbour that was
  // prefetched under a since-discarded per-page cubit) is served from memory with
  // no DB round-trip. Keyed by section AND script (the two scripts read different
  // columns), so a script switch keys to a different entry rather than serving
  // stale text. LRU-capped — the whole mushaf is small, but this bounds memory.
  final Map<String, List<Ayah>> _ayahCache = {};
  final List<String> _ayahCacheOrder = []; // LRU, oldest first
  static const int _ayahCacheCap = 40;

  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async {
    // IndoPak column only when the feature is ON and the reader chose it; the
    // `?? uthmani` fallback guarantees non-null text even if the column is
    // unexpectedly empty. Flag off => always Uthmani (current behaviour).
    final indopak =
        FeatureFlags.indopakScript && _settings.script == ArabicScript.indopak;

    final cacheKey = '${target.dimension.index}:${target.value}:$indopak';
    final cached = _ayahCache[cacheKey];
    if (cached != null) {
      _touchAyahCache(cacheKey);
      return cached;
    }

    final rows = await switch (target.dimension) {
      ReaderDimension.surah => _db.ayahsForSurah(target.value),
      ReaderDimension.juz => _db.ayahsForJuz(target.value),
      ReaderDimension.hizb => _db.ayahsForHizb(target.value),
      ReaderDimension.page => _db.ayahsForPage(target.value),
      ReaderDimension.ruku => _db.ayahsForRuku(target.value),
    };

    final translations =
        await _db.translationsForAyahIds([for (final r in rows) r.id]);

    final ayahs = [
      for (final r in rows)
        Ayah(
          id: r.id,
          surahId: r.surahId,
          ayahNumber: r.ayahNumber,
          textArabic: indopak
              ? (r.textArabicIndopak ?? r.textArabicUthmani)
              : r.textArabicUthmani,
          isSajda: r.sajda == 1,
          page: r.pageNumber,
          juz: r.juzNumber,
          hizb: r.hizbNumber,
          rubElHizb: r.rubElHizb,
          ruku: r.rukuNumber,
          translations: translations[r.id] ?? const {},
        ),
    ];
    _storeAyahCache(cacheKey, ayahs);
    return ayahs;
  }

  void _touchAyahCache(String key) {
    _ayahCacheOrder
      ..remove(key)
      ..add(key);
  }

  void _storeAyahCache(String key, List<Ayah> ayahs) {
    _ayahCache[key] = ayahs;
    _touchAyahCache(key);
    while (_ayahCacheOrder.length > _ayahCacheCap) {
      _ayahCache.remove(_ayahCacheOrder.removeAt(0));
    }
  }

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() =>
      _headingsFuture ??= _fetchSurahHeadings();

  Future<Map<int, SurahHeading>> _fetchSurahHeadings() async {
    final rows = await _db.allSurahs();
    return {
      for (final s in rows)
        s.id: SurahHeading(
          number: s.id,
          nameEnglish: s.nameEnglish,
          totalAyahs: s.totalAyahs,
          nameArabic: s.nameArabic,
          revelationPlace: s.revelationPlace,
        ),
    };
  }

  @override
  Future<List<TranslationResource>> getTranslationResources() =>
      _resourcesFuture ??= _fetchTranslationResources();

  Future<List<TranslationResource>> _fetchTranslationResources() async {
    final rows = await _db.translationResources();
    return [
      for (final r in rows)
        TranslationResource(
          id: r.id,
          languageCode: r.languageCode,
          name: r.name,
          author: r.author,
        ),
    ];
  }
}
