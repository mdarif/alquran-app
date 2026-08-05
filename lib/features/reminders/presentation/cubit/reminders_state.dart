import 'package:equatable/equatable.dart';

import '../../domain/entities/reminder_occurrence.dart';
import '../../domain/scheduling/notification_delivery_status.dart';

/// What the Sunnah-reminders sheet renders. [enabled] is the persisted master
/// switch; [permissionGranted] reflects the live OS state; [delivery] holds the
/// Android reliability gates surfaced as a hint/debug readout; [upcoming] is
/// the next reminders to surface (lingering through each event's own day).
class RemindersState extends Equatable {
  const RemindersState({
    this.enabled = false,
    this.permissionGranted = false,
    this.delivery = const NotificationDeliveryStatus(),
    this.upcoming = const [],
  });

  final bool enabled;
  final bool permissionGranted;
  final NotificationDeliveryStatus delivery;
  final List<ReminderOccurrence> upcoming;

  bool get batteryOptimized => delivery.batteryOptimized;
  bool get exactAlarmsAllowed => delivery.exactAlarmsAllowed;

  RemindersState copyWith({
    bool? enabled,
    bool? permissionGranted,
    NotificationDeliveryStatus? delivery,
    List<ReminderOccurrence>? upcoming,
  }) =>
      RemindersState(
        enabled: enabled ?? this.enabled,
        permissionGranted: permissionGranted ?? this.permissionGranted,
        delivery: delivery ?? this.delivery,
        upcoming: upcoming ?? this.upcoming,
      );

  @override
  List<Object?> get props => [
        enabled,
        permissionGranted,
        delivery.exactAlarmsAllowed,
        delivery.batteryOptimizationExempt,
        // ReminderOccurrence isn't Equatable — compare by (event id, fireAt).
        [for (final o in upcoming) (o.event.id, o.fireAt)],
      ];
}
