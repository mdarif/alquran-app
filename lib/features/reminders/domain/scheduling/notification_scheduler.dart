/// Abstraction over the local-notification plugin so the cubit is unit-testable
/// with a fake (no platform channel) — mirrors the `LocationProvider` seam. The
/// concrete impl (data layer) wraps `flutter_local_notifications` + `timezone`.
abstract interface class NotificationScheduler {
  /// Initialise the plugin + channel. [onSelect] receives a tapped
  /// notification's payload (for routing). Safe to call once at startup even
  /// when reminders are off.
  Future<void> init({void Function(String? payload)? onSelect});

  /// Ask the OS for notification permission; returns whether it's granted.
  Future<bool> requestPermission();

  /// Whether the app may currently post notifications.
  Future<bool> hasPermission();

  /// Ask the OS to permit EXACT alarms (Android 14+ opens the system setting).
  /// Self-guarding + best-effort: a no-op where exact alarms are already allowed
  /// (older Android, iOS). Without this, reminders fall back to inexact timing.
  Future<void> requestExactAlarmPermission();

  /// Whether the OS will honor EXACT alarm timing right now (Android 12+ gate;
  /// always true where not applicable). When false, scheduled reminders fall back
  /// to inexact timing that Doze can defer. Surfaced in the debug delivery panel.
  Future<bool> canScheduleExact();

  /// Whether the app is exempt from battery optimization (Android). Aggressive
  /// OEMs freeze non-exempt apps and drop their scheduled alarms. Always true
  /// where not applicable (iOS / pre-Android-6).
  Future<bool> isBatteryOptimizationExempt();

  /// Prompt the user to exempt the app from battery optimization (Android shows a
  /// one-tap system dialog). Self-guarding + best-effort; no-op on iOS.
  Future<void> requestBatteryOptimizationExemption();

  /// Cancel every pending reminder (before rescheduling the rolling window).
  Future<void> cancelAll();

  /// DEBUG: how many notifications the OS currently has queued (-1 on error).
  /// Lets the debug panel confirm a scheduled test actually landed in the queue
  /// — distinguishing "scheduling failed" from "OS dropped a queued alarm".
  Future<int> pendingCount();

  /// DEBUG: like [scheduleOneShot] but RETURNS the captured error (null on
  /// success) instead of swallowing it — reveals a silent scheduling failure.
  Future<String?> scheduleOneShotDebug({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
  });

  /// Schedule a one-shot notification at [fireAt] (local wall-clock).
  Future<void> scheduleOneShot({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
    String? payload,
  });

  /// Schedule a weekly-repeating notification (used for Al-Kahf).
  Future<void> scheduleWeekly({
    required int id,
    required int weekday, // DateTime.monday … DateTime.sunday
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  });

  /// The payload of a notification that cold-launched the app, or null. Consumed
  /// once (call after the first frame to route a tap that opened the app).
  Future<String?> consumeLaunchPayload();
}
