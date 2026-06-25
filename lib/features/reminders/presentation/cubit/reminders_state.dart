import 'package:equatable/equatable.dart';

import '../../domain/entities/reminder_occurrence.dart';

/// What the Sunnah-reminders sheet renders. [enabled] is the persisted master
/// switch; [permissionGranted] reflects the live OS state; [batteryOptimized] is
/// true when the OS may still throttle/drop reminders (not exempt from battery
/// optimization) — surfaced as a reliability hint; [exactAlarmsAllowed] mirrors
/// the OS exact-alarm grant (debug delivery panel only); [upcoming] is the next
/// reminders to surface (lingering through each event's own day).
class RemindersState extends Equatable {
  const RemindersState({
    this.enabled = false,
    this.permissionGranted = false,
    this.batteryOptimized = false,
    this.exactAlarmsAllowed = false,
    this.upcoming = const [],
  });

  final bool enabled;
  final bool permissionGranted;
  final bool batteryOptimized;
  final bool exactAlarmsAllowed;
  final List<ReminderOccurrence> upcoming;

  RemindersState copyWith({
    bool? enabled,
    bool? permissionGranted,
    bool? batteryOptimized,
    bool? exactAlarmsAllowed,
    List<ReminderOccurrence>? upcoming,
  }) =>
      RemindersState(
        enabled: enabled ?? this.enabled,
        permissionGranted: permissionGranted ?? this.permissionGranted,
        batteryOptimized: batteryOptimized ?? this.batteryOptimized,
        exactAlarmsAllowed: exactAlarmsAllowed ?? this.exactAlarmsAllowed,
        upcoming: upcoming ?? this.upcoming,
      );

  @override
  List<Object?> get props => [
        enabled,
        permissionGranted,
        batteryOptimized,
        exactAlarmsAllowed,
        // ReminderOccurrence isn't Equatable — compare by (event id, fireAt).
        [for (final o in upcoming) (o.event.id, o.fireAt)],
      ];
}
