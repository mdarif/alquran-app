import 'package:al_quran/features/prayer_times/data/repositories/prayer_notification_settings_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PrayerNotificationSettingsRepositoryImpl> repo([
    Map<String, Object> prefs = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(prefs);
    return PrayerNotificationSettingsRepositoryImpl(
      await SharedPreferences.getInstance(),
    );
  }

  test('defaults off', () async {
    expect((await repo()).enabled, isFalse);
  });

  test('reads and writes the salat notification toggle', () async {
    final r = await repo({'prayer_notifications_enabled': true});
    expect(r.enabled, isTrue);

    await r.setEnabled(false);
    expect(r.enabled, isFalse);
  });
}

