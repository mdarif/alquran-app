import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/geo_location.dart';
import '../../domain/entities/next_prayer.dart';
import '../../domain/entities/prayer.dart';
import '../../domain/location/location_provider.dart';
import '../../domain/repositories/prayer_times_repository.dart';
import 'prayer_times_state.dart';

/// Drives the next-prayer indicator. Mirrors [ThemeCubit]'s discipline: an
/// injected clock for testability and **no internal Timer** (the pill is static,
/// so the cubit can't leak). Recomputes on [refresh] (app-resume / theme tick).
class PrayerTimesCubit extends Cubit<PrayerTimesState> {
  PrayerTimesCubit(
    this._repo, {
    DateTime Function()? clock,
    VoidCallback? onLocationFixed,
  })  : _clock = clock ?? DateTime.now,
        _onLocationFixed = onLocationFixed,
        super(_initial(_repo, clock ?? DateTime.now));

  final PrayerTimesRepository _repo;
  final DateTime Function() _clock;

  /// Called after a fresh location is saved, so the theme can re-resolve to a
  /// prayer-based phase (wired to `ThemeCubit.refresh` in DI — keeps this cubit
  /// free of any cross-feature/theme import).
  final VoidCallback? _onLocationFixed;

  static PrayerTimesState _initial(
    PrayerTimesRepository repo,
    DateTime Function() clock,
  ) {
    final location = repo.location;
    if (location == null) return const PrayerTimesState.unset();
    return _compute(repo, location, clock());
  }

  static PrayerTimesState _compute(
    PrayerTimesRepository repo,
    GeoLocation location,
    DateTime now,
  ) {
    var day = repo.timesFor(location, now);
    // Whether prayer is prohibited right now — from TODAY's windows, before any
    // rollover below swaps `day` for tomorrow.
    final forbidden = day.forbiddenAt(now);
    var upcoming = day.nextAfter(now);
    if (upcoming == null) {
      // Every prayer today has passed → the next is tomorrow's Fajr.
      day = repo.timesFor(location, now.add(const Duration(days: 1)));
      upcoming = (Prayer.fajr, day.fajr);
    }
    final remaining = upcoming.$2.difference(now);
    return PrayerTimesState(
      today: day,
      next: NextPrayer(
        prayer: upcoming.$1,
        at: upcoming.$2,
        remaining: remaining.isNegative ? Duration.zero : remaining,
      ),
      forbidden: forbidden,
      hasLocation: true,
    );
  }

  /// The Gregorian date the Islamic (Hijri) date should reflect — rolled to the
  /// NEXT day once Maghrib has passed, because the Hijri day begins at sunset.
  /// Uses today's civil schedule (not [state.today], which is already tomorrow's
  /// after Isha), so it stays correct all evening.
  DateTime get hijriBaseDate {
    final now = _clock();
    final civil = DateTime(now.year, now.month, now.day);
    final location = _repo.location;
    if (location == null) return civil;
    final sunset = _repo.timesFor(location, now).maghrib;
    return now.isBefore(sunset) ? civil : civil.add(const Duration(days: 1));
  }

  /// The civil (wall-calendar) date, for the Gregorian line beneath the Hijri.
  DateTime get gregorianDate {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// The user's Hijri ± day correction (to match a local moon-sighting).
  int get hijriAdjustment => _repo.hijriAdjustment;

  /// Persist a new Hijri correction.
  Future<void> setHijriAdjustment(int days) => _repo.setHijriAdjustment(days);

  /// Re-resolve against the current clock (catches a passed prayer / midnight).
  void refresh() {
    final location = _repo.location;
    if (location == null) {
      emit(const PrayerTimesState.unset());
      return;
    }
    emit(_compute(_repo, location, _clock()));
  }

  /// Request the device location; on success persist + recompute + nudge theme.
  Future<void> enableLocation() async {
    final result = await _repo.acquireLocation();
    if (result.status == LocationStatus.ok) {
      refresh();
      _onLocationFixed?.call();
    } else {
      emit(state.copyWith(status: result.status));
    }
  }
}
