import '../entities/prayer.dart';

/// Legacy tap-routing payload for a salat-time notification. Kept readable so
/// notifications already scheduled before an app update still open the sheet.
const String openPrayerTimesPayload = 'open:prayer_times';

class PrayerNotificationTap {
  const PrayerNotificationTap({this.prayer, this.fireAt});

  final Prayer? prayer;
  final DateTime? fireAt;
}

String prayerTimesPayload({required Prayer prayer, required DateTime fireAt}) {
  return Uri(
    scheme: 'open',
    path: 'prayer_times',
    queryParameters: {
      'prayer': prayer.name,
      'at': fireAt.toIso8601String(),
    },
  ).toString();
}

PrayerNotificationTap? parsePrayerTimesPayload(String? payload) {
  if (payload == null) return null;
  if (payload == openPrayerTimesPayload) return const PrayerNotificationTap();

  final uri = Uri.tryParse(payload);
  if (uri == null || uri.scheme != 'open' || uri.path != 'prayer_times') {
    return null;
  }

  final prayerName = uri.queryParameters['prayer'];
  Prayer? prayer;
  if (prayerName != null) {
    for (final candidate in Prayer.values) {
      if (candidate.name == prayerName) {
        prayer = candidate;
        break;
      }
    }
  }
  final at = DateTime.tryParse(uri.queryParameters['at'] ?? '');
  return PrayerNotificationTap(prayer: prayer, fireAt: at);
}
