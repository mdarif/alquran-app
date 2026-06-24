/// Persists the Sunnah-reminders setting. v1 is a single master switch (sync
/// getter + async setter, like `ReaderSettingsRepository`). Per-event toggles
/// are the natural extension — a `Set<SunnahKind>` stored as a string list, like
/// `reader_selected_translations` — but are deferred.
abstract interface class ReminderSettingsRepository {
  /// Whether the user has turned reminders on. Default false (opt-in).
  bool get enabled;

  Future<void> setEnabled(bool value);
}
