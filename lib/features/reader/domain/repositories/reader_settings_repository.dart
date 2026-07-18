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

  /// Recitation playback rate (1.0 = normal); defaults to [defaultRecitationSpeed].
  double get recitationSpeed;

  /// Whether tapping a verse in Reading opens the translation peek card. Defaults
  /// to **false** — the always-on player owns playback, so a tap just selects the
  /// verse (queues it for the player). Turning this on brings back the peek as a
  /// translation-only reading aid (no play control). Reading-only.
  bool get showTranslationPeek;

  /// Whether the Detailed view renders the Arabic matn above each translation.
  /// Defaults to **true**; turning it off gives a translations-only reading (the
  /// Arabic line is hidden). Detailed-only.
  bool get showArabicMatn;

  Future<void> setFontSize(double value);
  Future<void> setDetailed(bool value);
  Future<void> setSelectedTranslations(List<String> languageCodes);
  Future<void> setRecitationSpeed(double value);
  Future<void> setShowTranslationPeek(bool value);
  Future<void> setShowArabicMatn(bool value);

  static const double defaultFontSize = 28;
  static const double defaultRecitationSpeed = 1.0;
}
