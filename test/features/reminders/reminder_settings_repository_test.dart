import 'package:al_quran/features/reminders/data/repositories/reminder_settings_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ReminderSettingsRepositoryImpl> repo([
    Map<String, Object> prefs = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(prefs);
    return ReminderSettingsRepositoryImpl(
      await SharedPreferences.getInstance(),
    );
  }

  test('defaults to disabled (opt-in)', () async {
    expect((await repo()).enabled, isFalse);
  });

  test('reads a persisted value', () async {
    expect((await repo({'reminders_enabled': true})).enabled, isTrue);
  });

  test('setEnabled round-trips', () async {
    final r = await repo();
    await r.setEnabled(true);
    expect(r.enabled, isTrue);
    await r.setEnabled(false);
    expect(r.enabled, isFalse);
  });
}
