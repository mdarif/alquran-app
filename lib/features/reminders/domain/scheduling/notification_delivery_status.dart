import 'notification_scheduler.dart';

/// Live OS gates that affect scheduled notification delivery.
class NotificationDeliveryStatus {
  const NotificationDeliveryStatus({
    this.exactAlarmsAllowed = true,
    this.batteryOptimizationExempt = true,
  });

  final bool exactAlarmsAllowed;
  final bool batteryOptimizationExempt;

  bool get batteryOptimized => !batteryOptimizationExempt;

  static Future<NotificationDeliveryStatus> read(
    NotificationScheduler scheduler,
  ) async {
    final exempt = await scheduler.isBatteryOptimizationExempt();
    final exact = await scheduler.canScheduleExact();
    return NotificationDeliveryStatus(
      exactAlarmsAllowed: exact,
      batteryOptimizationExempt: exempt,
    );
  }
}

Future<void> requestReliableNotificationDelivery(
  NotificationScheduler scheduler,
) async {
  await scheduler.requestExactAlarmPermission();
  if (!await scheduler.isBatteryOptimizationExempt()) {
    await scheduler.requestBatteryOptimizationExemption();
  }
}
