class PrayerNotificationsState {
  const PrayerNotificationsState({
    this.enabled = false,
    this.permissionGranted = true,
    this.hasLocation = true,
    this.scheduledCount = 0,
  });

  final bool enabled;
  final bool permissionGranted;
  final bool hasLocation;
  final int scheduledCount;
}

