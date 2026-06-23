import 'package:equatable/equatable.dart';

/// Which of the three daily periods this is. Prayer is prohibited at these times
/// per the hadith of ʿUqba ibn ʿĀmir (Muslim): after sunrise until the sun has
/// risen high, when the sun is at its zenith until it passes the meridian, and
/// as the sun yellows before it sets.
enum ForbiddenReason {
  afterSunrise('After sunrise'),
  zenith('Zenith (Istiwāʾ)'),
  beforeSunset('Before sunset');

  const ForbiddenReason(this.label);

  final String label;
}

/// One forbidden-for-prayer window — a [start]–[end] span and its [reason]. The
/// spans are approximations: the calc lib exposes only the final times (not the
/// sun's elevation), so "a spear's length" after sunrise and the yellowing
/// before sunset use documented fixed durations (see [DailyPrayerTimes]).
class ForbiddenWindow extends Equatable {
  const ForbiddenWindow({
    required this.reason,
    required this.start,
    required this.end,
  });

  final ForbiddenReason reason;
  final DateTime start; // local
  final DateTime end; // local

  /// `start <= t < end` — the moment a window ends (e.g. Dhuhr enters) is no
  /// longer forbidden.
  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  @override
  List<Object?> get props => [reason, start, end];
}
