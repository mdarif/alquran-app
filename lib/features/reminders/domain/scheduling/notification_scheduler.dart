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

  /// Cancel every pending reminder (before rescheduling the rolling window).
  Future<void> cancelAll();

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
