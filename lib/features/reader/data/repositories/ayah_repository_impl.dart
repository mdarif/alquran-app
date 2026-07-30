import '../../../../core/database/app_database.dart';
import '../../../../core/database/editions_database.dart';
import '../../../../core/feature_flags.dart';
import '../../../../core/translations/translation_metadata_overrides.dart';
import '../../domain/entities/arabic_script.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/reader_target.dart';
import '../../domain/entities/surah_heading.dart';
import '../../domain/entities/translation_resource.dart';
import '../../domain/repositories/ayah_repository.dart';
import '../../domain/repositories/reader_settings_repository.dart';

class AyahRepositoryImpl implements AyahRepository {
  AyahRepositoryImpl(this._db, this._settings, [this._editions]);

  final AppDatabase _db;
  final ReaderSettingsRepository _settings;

  /// Downloaded editions, in their own database so an app update's re-seed of
  /// `quran.db` cannot destroy them. Null where the feature isn't wired (tests,
  /// and any build without downloads), in which case only bundled editions
  /// exist and every code path below degrades to its previous behaviour.
  final EditionsDatabase? _editions;

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

    // Fold in any downloaded editions. They are addressed by (surah, ayah)
    // rather than the global ayah id: an installed edition outlives the build
    // that produced it, so it must not depend on an id space a later data
    // refresh could renumber.
    final downloaded = await _downloadedTexts(rows);
    if (downloaded.isNotEmpty) {
      for (final r in rows) {
        final forAyah = downloaded[(r.surahId, r.ayahNumber)];
        if (forAyah != null) {
          (translations[r.id] ??= <String, String>{}).addAll(forAyah);
        }
      }
    }

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

  /// Downloaded-edition text for these ayahs: (surah, ayah) -> (slug -> text).
  Future<Map<(int, int), Map<String, String>>> _downloadedTexts(
    List<AyahRow> rows,
  ) async {
    final editions = _editions;
    if (editions == null || rows.isEmpty) return const {};
    final installed = await editions.installed();
    if (installed.isEmpty) return const {};
    final slugs = [for (final e in installed) e.slug];
    final surahIds = {for (final r in rows) r.surahId};
    final out = <(int, int), Map<String, String>>{};
    // A section can span surahs (juz/hizb/page/ruku), so query each one it
    // touches — usually exactly one.
    for (final surahId in surahIds) {
      final bySlug = await editions.textsForSurahAll(slugs, surahId);
      for (final entry in bySlug.entries) {
        for (final verse in entry.value.entries) {
          (out[(surahId, verse.key)] ??= <String, String>{})[entry.key] =
              verse.value;
        }
      }
    }
    return out;
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

  void invalidateTranslations() {
    _resourcesFuture = null;
    _ayahCache.clear();
    _ayahCacheOrder.clear();
  }

  Future<List<TranslationResource>> _fetchTranslationResources() async {
    final rows = await _db.translationResources();
    final bundled = [
      for (final r in rows)
        TranslationResource(
          id: r.id,
          slug: r.slug,
          languageCode: r.languageCode,
          name: r.name,
          nativeName: r.nativeName,
          author: TranslationMetadataOverrides.author(r.slug, r.author),
          direction: r.direction,
          sortOrder: r.sortOrder,
          defaultOn: r.defaultOn == 1,
          license: r.license,
          sourceUrl: r.sourceUrl,
        ),
    ];

    final editions = _editions;
    if (editions == null) return bundled;

    // Downloaded editions are presented exactly like bundled ones, so nothing
    // downstream needs to know where a given text came from. Merged into the
    // same global sort order, which is what groups a language's editions
    // together in the picker. Key by slug while merging: an updated edition can
    // exist in `editions.db` with the same slug as a bundled edition, and the
    // reader must render that selected slug once.
    final installed = await editions.installed();
    if (installed.isEmpty) return bundled;
    final bySlug = <String, TranslationResource>{
      for (final r in bundled) r.slug: r,
    };
    for (final e in installed) {
      bySlug[e.slug] = TranslationResource(
        // No row in `resources`, so no meaningful id. Nothing may key on it —
        // the reader addresses editions by slug throughout.
        id: -1,
        slug: e.slug,
        languageCode: e.languageCode,
        name: e.name,
        nativeName: e.nativeName,
        author: TranslationMetadataOverrides.author(e.slug, e.author),
        direction: e.direction,
        sortOrder: e.sortOrder,
        license: e.license,
        sourceUrl: e.sourceUrl,
      );
    }
    final merged = bySlug.values.toList()
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.slug.compareTo(b.slug);
      });
    return merged;
  }
}
