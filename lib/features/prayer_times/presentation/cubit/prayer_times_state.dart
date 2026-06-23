import 'package:equatable/equatable.dart';

import '../../domain/entities/daily_prayer_times.dart';
import '../../domain/entities/forbidden_window.dart';
import '../../domain/entities/next_prayer.dart';
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
    this.next,
    this.forbidden,
    this.hasLocation = false,
    this.status,
  });

  const PrayerTimesState.unset()
      : today = null,
        next = null,
        forbidden = null,
        hasLocation = false,
        status = null;

  final DailyPrayerTimes? today;
  final NextPrayer? next;
  final ForbiddenWindow? forbidden;
  final bool hasLocation;
  final LocationStatus? status;

  PrayerTimesState copyWith({LocationStatus? status}) => PrayerTimesState(
        today: today,
        next: next,
        forbidden: forbidden,
        hasLocation: hasLocation,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props =>
      [today?.date, next?.prayer, next?.at, forbidden, hasLocation, status];
}
