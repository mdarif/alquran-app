import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/geo_location.dart';
import '../../domain/entities/next_prayer.dart';
import '../../domain/entities/prayer.dart';
import '../../domain/location/location_provider.dart';
import '../../domain/repositories/prayer_times_repository.dart';
import 'prayer_times_state.dart';

/// Drives the next-prayer indicator. Mirrors [ThemeCubit]'s discipline: an
/// injected clock for testability. Recomputes on [refresh] (app-resume), and
/// re-arms a single one-shot [Timer] to wake exactly when the upcoming prayer
/// enters — the app holds a wakelock, so it can sit foregrounded across a
/// prayer time and must not keep naming one that has passed. The timer is
/// cancelled in [close], so the cubit still can't leak.
class PrayerTimesCubit extends Cubit<PrayerTimesState> {
  PrayerTimesCubit(
    this._repo, {
    DateTime Function()? clock,
    VoidCallback? onLocationFixed,
    bool autoRefresh = true,
  })  : _clock = clock ?? DateTime.now,
        _onLocationFixed = onLocationFixed,
        _autoRefresh = autoRefresh,
        super(_initial(_repo, clock ?? DateTime.now)) {
    _scheduleNextTick();
  }

  final PrayerTimesRepository _repo;
  final DateTime Function() _clock;

  /// One-shot wake-up at the next prayer boundary (see [_scheduleNextTick]).
  Timer? _tick;

  /// Whether to arm that wake-up. Widget tests that pump this cubit with a
  /// frozen clock set it false — a live timer they never advance would just
  /// fail the framework's "pending timer" check at the end of the test.
  final bool _autoRefresh;

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
    // No computable schedule for this day (polar latitude) — the location is
    // fine, the times simply don't exist. Report "unavailable" so the UI hides
    // the prayer surface instead of offering to re-fetch the location.
    if (day == null) {
      return const PrayerTimesState(hasLocation: true, timesUnavailable: true);
    }
    // Whether prayer is prohibited right now — from TODAY's windows, before any
    // rollover below swaps `day` for tomorrow.
    final forbidden = day.forbiddenAt(now);
    final current = day.currentSalahAt(now);
    final tomorrow = repo.timesFor(location, now.add(const Duration(days: 1)));
    var upcoming = day.nextAfter(now);
    if (upcoming == null) {
      // Every prayer today has passed → the next is tomorrow's Fajr.
      if (tomorrow == null) {
        return const PrayerTimesState(
          hasLocation: true,
          timesUnavailable: true,
        );
      }
      day = tomorrow;
      upcoming = (Prayer.fajr, day.fajr);
    }
    final remaining = upcoming.$2.difference(now);
    return PrayerTimesState(
      today: day,
      tomorrow: tomorrow,
      current: current == null ? null : (current.$1, current.$2),
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
    // No schedule for this day → no sunset to roll on; the civil date stands.
    final sunset = _repo.timesFor(location, now)?.maghrib;
    if (sunset == null) return civil;
    return now.isBefore(sunset) ? civil : civil.add(const Duration(days: 1));
  }

  /// The civil (wall-calendar) date, for the Gregorian line beneath the Hijri.
  DateTime get gregorianDate {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// Re-resolve against the current clock (catches a passed prayer / midnight).
  void refresh() {
    final location = _repo.location;
    if (location == null) {
      _tick?.cancel();
      emit(const PrayerTimesState.unset());
      return;
    }
    emit(_compute(_repo, location, _clock()));
    _scheduleNextTick();
  }

  /// Wake once, exactly when the upcoming prayer enters, and re-resolve. The app
  /// holds a wakelock, so it can sit foregrounded for hours: without this the
  /// pill kept naming a prayer whose time had already passed (a lifecycle
  /// `resume` was the only thing that refreshed it). One-shot rather than
  /// periodic — no polling, and it re-arms itself from the new state.
  void _scheduleNextTick() {
    _tick?.cancel();
    if (!_autoRefresh) return;
    final at = state.next?.at;
    if (at == null) return; // nothing upcoming (no location / no schedule)
    final delay = at.difference(_clock()) + const Duration(seconds: 1);
    _tick = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (!isClosed) refresh();
    });
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

  @override
  Future<void> close() {
    _tick?.cancel();
    return super.close();
  }
}
