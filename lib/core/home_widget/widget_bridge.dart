import '../../features/prayer_times/domain/entities/geo_location.dart';
import '../../features/prayer_times/domain/entities/prayer.dart';
import '../../features/prayer_times/domain/repositories/prayer_times_repository.dart';
import 'widget_payload.dart';

/// Builds the home-screen widget's data payload from the (offline) prayer-times
/// repository. PURE: it reads only the repo + an injected clock and returns a
/// [WidgetPayload]. Pushing that payload to the OS widget (via the `home_widget`
/// plugin) is a separate, platform-bound step layered on top later — so this
/// half is fully unit-testable with no plugin, and the creed math has exactly
/// one home.
///
/// Lives in `core/` because the widget surface is cross-cutting (prayer times
/// today, hijri/theme later); it depends *inward* on the prayer-times domain,
/// never on another feature — mirroring how `ThemeCubit`'s phase resolver reads
/// this same repo in DI.
class WidgetBridge {
  WidgetBridge(this._repo, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final PrayerTimesRepository _repo;
  final DateTime Function() _clock;

  /// Days of schedule to serialise: today + the next two. A multi-day horizon
  /// keeps the native timeline correct for ~2 days with no background refresh —
  /// enough for v1, which only re-syncs on app launch / resume / location change.
  static const int _horizonDays = 3;

  /// Snapshot the current schedule. With no saved location yet, returns a
  /// payload flagged `hasLocation: false` and no days.
  WidgetPayload buildPayload() {
    final now = _clock();
    final location = _repo.location;
    if (location == null) {
      return WidgetPayload(
        schemaVersion: WidgetPayload.currentSchemaVersion,
        generatedAt: now,
        hasLocation: false,
        locationLabel: null,
        days: const [],
      );
    }

    final today = DateTime(now.year, now.month, now.day);
    return WidgetPayload(
      schemaVersion: WidgetPayload.currentSchemaVersion,
      generatedAt: now,
      hasLocation: true,
      locationLabel: location.label,
      days: [
        for (var i = 0; i < _horizonDays; i++)
          _dayFor(location, today.add(Duration(days: i))),
      ],
    );
  }

  WidgetDay _dayFor(GeoLocation location, DateTime date) {
    final t = _repo.timesFor(location, date);
    return WidgetDay(
      date: DateTime(date.year, date.month, date.day),
      markers: [
        _marker(Prayer.fajr, t.fajr),
        _marker(Prayer.sunrise, t.sunrise),
        _marker(Prayer.dhuhr, t.dhuhr),
        _marker(Prayer.asr, t.asr),
        _marker(Prayer.maghrib, t.maghrib),
        _marker(Prayer.isha, t.isha),
      ],
    );
  }

  WidgetMarker _marker(Prayer prayer, DateTime at) =>
      WidgetMarker(name: prayer.label, isSalah: prayer.isSalah, at: at);
}
