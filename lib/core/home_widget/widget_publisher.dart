import 'package:home_widget/home_widget.dart';

import 'widget_bridge.dart';

/// Thin seam over the `home_widget` plugin so [WidgetPublisher] is unit-testable
/// without a platform channel — mirrors how `LocationProvider` hides `geolocator`
/// from the prayer-times repo.
abstract interface class HomeWidgetClient {
  /// iOS: point the plugin at the shared App Group container so the widget
  /// extension can read what the app writes. No-op on Android.
  Future<void> setAppGroupId(String groupId);

  /// Persist [value] under [key] in the store the native widgets read.
  Future<void> saveData(String key, String value);

  /// Ask the platform to redraw a widget — an Android receiver
  /// ([qualifiedAndroidName]) and/or an iOS WidgetKit kind ([iOSName]).
  Future<void> update({String? qualifiedAndroidName, String? iOSName});
}

/// Real implementation, backed by the plugin.
class PluginHomeWidgetClient implements HomeWidgetClient {
  const PluginHomeWidgetClient();

  @override
  Future<void> setAppGroupId(String groupId) =>
      HomeWidget.setAppGroupId(groupId);

  @override
  Future<void> saveData(String key, String value) =>
      HomeWidget.saveWidgetData<String>(key, value);

  @override
  Future<void> update({String? qualifiedAndroidName, String? iOSName}) =>
      HomeWidget.updateWidget(
        qualifiedAndroidName: qualifiedAndroidName,
        iOSName: iOSName,
      );
}

/// Pushes the [WidgetBridge] payload to every home-screen widget (both Android
/// providers and both iOS kinds), then asks each to redraw. The plugin-touching
/// half is kept OUT of [WidgetBridge] (which stays pure) and behind
/// [HomeWidgetClient] (which keeps this testable).
///
/// Every call is best-effort and swallows errors: there may be no widget placed,
/// the plugin may be unavailable on a platform, etc. — none of that should ever
/// surface in a reading session.
class WidgetPublisher {
  WidgetPublisher(this._bridge, this._client);

  final WidgetBridge _bridge;
  final HomeWidgetClient _client;

  /// Key the native widgets read the JSON payload from.
  static const String payloadKey = 'prayer_widget_payload';

  /// iOS App Group shared by the app + widget extension. A shared-container id,
  /// independent of the bundle id (which is `com.almarfa.alquran`) — it keeps
  /// its original `alQuran` spelling, matching the entitlements + the widget's
  /// Swift. iOS-only; ignored on Android.
  static const String appGroupId = 'group.com.almarfa.alQuran';

  /// Fully-qualified Android receivers — both read the same payload.
  static const String nextPrayerProvider =
      'com.almarfa.al_quran.PrayerWidgetProvider';
  static const String scheduleProvider =
      'com.almarfa.al_quran.PrayerScheduleWidgetProvider';
  static const List<String> androidProviders = [
    nextPrayerProvider,
    scheduleProvider,
  ];

  /// WidgetKit "kind" strings for the two iOS widgets.
  static const List<String> iosWidgetKinds = [
    'PrayerWidget',
    'PrayerScheduleWidget',
  ];

  /// Rebuild the payload from the current schedule and hand it to every widget.
  Future<void> publish() async {
    try {
      await _client.setAppGroupId(appGroupId);
      final payload = _bridge.buildPayload();
      await _client.saveData(payloadKey, payload.encode());
      for (final provider in androidProviders) {
        await _client.update(qualifiedAndroidName: provider);
      }
      for (final kind in iosWidgetKinds) {
        await _client.update(iOSName: kind);
      }
    } catch (_) {
      // No widget on the home screen yet, plugin missing on this platform, etc.
    }
  }
}
