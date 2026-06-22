/// Persists the user's global reading preferences (zoom level + viewport) so
/// they survive app restarts. Reads are synchronous (defaulted); writes async.
abstract interface class ReaderSettingsRepository {
  /// Arabic font size in points; defaults to [defaultFontSize].
  double get fontSize;

  /// Whether the Detailed (translation) viewport is preferred over Mushaf.
  bool get detailed;

  /// Language code of the translation last shown in the Reading-view tap-to-peek
  /// card (e.g. 'ur'); null until the reader picks one (then seeded from locale).
  String? get peekTranslation;

  Future<void> setFontSize(double value);
  Future<void> setDetailed(bool value);
  Future<void> setPeekTranslation(String languageCode);

  static const double defaultFontSize = 28;
}
