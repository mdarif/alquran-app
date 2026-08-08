import '../../../reminders/domain/scheduling/notification_delivery_status.dart';

class PrayerNotificationsState {
  const PrayerNotificationsState({
    this.enabled = false,
    this.permissionGranted = true,
    this.hasLocation = true,
    this.delivery = const NotificationDeliveryStatus(),
    this.scheduledCount = 0,
    this.zoneMismatch = false,
  });

  final bool enabled;
  final bool permissionGranted;
  final bool hasLocation;
  final NotificationDeliveryStatus delivery;
  final int scheduledCount;
  final bool zoneMismatch;

  bool get batteryOptimized => delivery.batteryOptimized;
  bool get exactAlarmsAllowed => delivery.exactAlarmsAllowed;
}
