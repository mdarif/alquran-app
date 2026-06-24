import 'package:equatable/equatable.dart';

import '../../domain/entities/reminder_occurrence.dart';

/// What the Home "Upcoming Sunnah Reminders" section renders. [enabled] is the
/// persisted master switch; [permissionGranted] reflects the live OS state;
/// [upcoming] is the next few occurrences (for display).
class RemindersState extends Equatable {
  const RemindersState({
    this.enabled = false,
    this.permissionGranted = false,
    this.upcoming = const [],
  });

  final bool enabled;
  final bool permissionGranted;
  final List<ReminderOccurrence> upcoming;

  RemindersState copyWith({
    bool? enabled,
    bool? permissionGranted,
    List<ReminderOccurrence>? upcoming,
  }) =>
      RemindersState(
        enabled: enabled ?? this.enabled,
        permissionGranted: permissionGranted ?? this.permissionGranted,
        upcoming: upcoming ?? this.upcoming,
      );

  @override
  List<Object?> get props => [
        enabled,
        permissionGranted,
        // ReminderOccurrence isn't Equatable — compare by (kind, fireAt).
        [for (final o in upcoming) (o.kind, o.fireAt)],
      ];
}
