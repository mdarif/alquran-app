/// Persists the user's global reading preferences (zoom level + viewport) so
/// they survive app restarts. Reads are synchronous (defaulted); writes async.
abstract interface class ReaderSettingsRepository {
  /// Arabic font size in points; defaults to [defaultFontSize].
  double get fontSize;

  /// Whether the Detailed (translation) viewport is preferred over Mushaf.
  bool get detailed;

  Future<void> setFontSize(double value);
  Future<void> setDetailed(bool value);

  static const double defaultFontSize = 28;
}
