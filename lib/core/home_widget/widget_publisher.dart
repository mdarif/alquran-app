import 'package:home_widget/home_widget.dart';

import 'widget_bridge.dart';

/// Thin seam over the `home_widget` plugin so [WidgetPublisher] is unit-testable
/// without a platform channel — mirrors how `LocationProvider` hides `geolocator`
/// from the prayer-times repo.
abstract interface class HomeWidgetClient {
  /// Persist [value] under [key] in the store the native widget reads.
  Future<void> saveData(String key, String value);

  /// Ask the platform to redraw the Android widget receiver.
  Future<void> updateWidget({required String qualifiedAndroidName});
}

/// Real implementation, backed by the plugin.
class PluginHomeWidgetClient implements HomeWidgetClient {
  const PluginHomeWidgetClient();

  @override
  Future<void> saveData(String key, String value) =>
      HomeWidget.saveWidgetData<String>(key, value);

  @override
  Future<void> updateWidget({required String qualifiedAndroidName}) =>
      HomeWidget.updateWidget(qualifiedAndroidName: qualifiedAndroidName);
}

/// Pushes the [WidgetBridge] payload to the OS home-screen widget, then asks the
/// platform to redraw it. The plugin-touching half is kept OUT of [WidgetBridge]
/// (which stays pure) and behind [HomeWidgetClient] (which keeps this testable).
///
/// Every call is best-effort and swallows errors: there may be no widget placed,
/// the plugin may be unavailable on a platform, etc. — none of that should ever
/// surface in a reading session.
class WidgetPublisher {
  WidgetPublisher(this._bridge, this._client);

  final WidgetBridge _bridge;
  final HomeWidgetClient _client;

  /// Key the native widget reads the JSON payload from.
  static const String payloadKey = 'prayer_widget_payload';

  /// Fully-qualified Android receiver, so the redraw targets the right provider
  /// regardless of launcher. (iOS adds its own name later.)
  static const String androidProvider =
      'com.almarfa.al_quran.PrayerWidgetProvider';

  /// Rebuild the payload from the current schedule and hand it to the widget.
  Future<void> publish() async {
    try {
      final payload = _bridge.buildPayload();
      await _client.saveData(payloadKey, payload.encode());
      await _client.updateWidget(qualifiedAndroidName: androidProvider);
    } catch (_) {
      // No widget on the home screen yet, plugin missing on this platform, etc.
    }
  }
}
