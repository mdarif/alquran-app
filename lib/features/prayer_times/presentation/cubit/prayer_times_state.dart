import 'package:equatable/equatable.dart';

import '../../domain/entities/daily_prayer_times.dart';
import '../../domain/entities/next_prayer.dart';
import '../../domain/location/location_provider.dart';

/// What the indicator renders. [today] is the active day's schedule (today, or
/// tomorrow once Isha has passed), [next] the upcoming prayer + countdown, and
/// [status] the last location-acquire outcome (so the no-location affordance can
/// tell "tap to enable" from "denied — open settings").
class PrayerTimesState extends Equatable {
  const PrayerTimesState({
    this.today,
    this.next,
    this.hasLocation = false,
    this.status,
  });

  const PrayerTimesState.unset()
      : today = null,
        next = null,
        hasLocation = false,
        status = null;

  final DailyPrayerTimes? today;
  final NextPrayer? next;
  final bool hasLocation;
  final LocationStatus? status;

  PrayerTimesState copyWith({LocationStatus? status}) => PrayerTimesState(
        today: today,
        next: next,
        hasLocation: hasLocation,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props =>
      [today?.date, next?.prayer, next?.at, hasLocation, status];
}
