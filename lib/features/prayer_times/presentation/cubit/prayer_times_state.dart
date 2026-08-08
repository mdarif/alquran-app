import 'package:equatable/equatable.dart';

import '../../domain/entities/daily_prayer_times.dart';
import '../../domain/entities/forbidden_window.dart';
import '../../domain/entities/next_prayer.dart';
import '../../domain/entities/prayer.dart';
import '../../domain/location/location_provider.dart';

/// What the indicator renders. [today] is the active day's schedule (today, or
/// tomorrow once Isha has passed), [next] the upcoming prayer + countdown,
/// [forbidden] the prayer-prohibited window active right now (null when prayer
/// is permitted), and [status] the last location-acquire outcome (so the
/// no-location affordance can tell "tap to enable" from "denied — open
/// settings").
class PrayerTimesState extends Equatable {
  const PrayerTimesState({
    this.today,
    this.tomorrow,
    this.current,
    this.next,
    this.forbidden,
    this.hasLocation = false,
    this.timesUnavailable = false,
    this.status,
  });

  const PrayerTimesState.unset()
      : today = null,
        tomorrow = null,
        current = null,
        next = null,
        forbidden = null,
        hasLocation = false,
        timesUnavailable = false,
        status = null;

  final DailyPrayerTimes? today;
  final DailyPrayerTimes? tomorrow;
  final (Prayer, DateTime)? current;
  final NextPrayer? next;
  final ForbiddenWindow? forbidden;
  final bool hasLocation;

  /// True when the location is known but the day has no computable schedule —
  /// above the polar circles the sun may not rise or set. Distinct from "no
  /// location yet": re-fetching the location would not help, so the UI hides
  /// the prayer surface rather than offering to enable it.
  final bool timesUnavailable;

  final LocationStatus? status;

  PrayerTimesState copyWith({LocationStatus? status}) => PrayerTimesState(
        today: today,
        tomorrow: tomorrow,
        current: current,
        next: next,
        forbidden: forbidden,
        hasLocation: hasLocation,
        timesUnavailable: timesUnavailable,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [
        today?.date,
        tomorrow?.date,
        current?.$1,
        current?.$2,
        next?.prayer,
        next?.at,
        forbidden,
        hasLocation,
        timesUnavailable,
        status,
      ];
}
