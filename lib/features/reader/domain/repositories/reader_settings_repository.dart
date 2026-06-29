import '../entities/arabic_script.dart';

/// Persists the user's global reading preferences (zoom level + viewport) so
/// they survive app restarts. Reads are synchronous (defaulted); writes async.
abstract interface class ReaderSettingsRepository {
  /// The Arabic script the reader renders. Defaults to [ArabicScript.uthmani];
  /// only meaningful while `FeatureFlags.indopakScript` is on.
  ArabicScript get script;
  Future<void> setScript(ArabicScript value);

  /// Arabic font size in points; defaults to [defaultFontSize].
  double get fontSize;

  /// Whether the Detailed (translation) viewport is preferred over Mushaf.
  bool get detailed;

  /// The reader's chosen translation editions, shared by BOTH the Reading-view
  /// peek card and the Detailed view (e.g. ['ur'] or ['ur','en']) — set once,
  /// honoured everywhere. null until the reader picks (then seeded from locale).
  List<String>? get selectedTranslations;

  /// Whether the Reading-view peek card shows the translation text (and its
  /// language chips). Defaults to true; the reader can collapse it from the peek
  /// to read/listen to the Arabic alone. Reading-only — Detailed is unaffected.
  bool get readingTranslationVisible;

  Future<void> setFontSize(double value);
  Future<void> setDetailed(bool value);
  Future<void> setSelectedTranslations(List<String> languageCodes);
  Future<void> setReadingTranslationVisible(bool value);

  static const double defaultFontSize = 28;
}
