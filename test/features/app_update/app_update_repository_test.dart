import 'package:al_quran/features/app_update/data/repositories/app_update_repository_impl.dart';
import 'package:al_quran/core/app_update_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppUpdateRepositoryImpl> _repo({
  required String body,
  int status = 200,
  String currentVersion = '1.2.1',
  DateTime? now,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  return AppUpdateRepositoryImpl(
    prefs: await SharedPreferences.getInstance(),
    configUrl: Uri.parse('https://example.test/app-update.json'),
    currentVersion: () async => currentVersion,
    now: () => now ?? DateTime.utc(2026, 7, 31),
    client: MockClient((_) async => http.Response(body, status)),
  );
}

void main() {
  group('AppUpdateRepositoryImpl', () {
    test('returns null when the installed app is current', () async {
      final repo = await _repo(
        body: '{"latestVersion":"1.2.1","storeUrl":"https://example.test"}',
      );

      expect(await repo.check(), isNull);
    });

    test('returns null when the installed app is newer than the config',
        () async {
      final repo = await _repo(
        currentVersion: '1.2.2',
        body: '{"latestVersion":"1.2.1","storeUrl":"https://example.test"}',
      );

      expect(await repo.check(), isNull);
    });

    test('returns an optional prompt when a newer version exists', () async {
      final repo = await _repo(
        body: '''
          {
            "latestVersion": "1.2.2",
            "minimumSupportedVersion": "1.0.0",
            "storeUrl": "$androidPlayStoreUrl",
            "message": "A newer version is available."
          }
        ''',
      );

      final prompt = await repo.check();

      expect(prompt, isNotNull);
      expect(prompt!.currentVersion, '1.2.1');
      expect(prompt.latestVersion, '1.2.2');
      expect(prompt.storeUrl, Uri.parse(androidPlayStoreUrl));
      expect(prompt.message, 'A newer version is available.');
      expect(prompt.required, isFalse);
    });

    test('suppresses a dismissed optional version inside the reminder window',
        () async {
      final repo = await _repo(
        body: '''
          {
            "latestVersion": "1.2.2",
            "storeUrl": "https://example.test",
            "remindAfterDays": 30
          }
        ''',
      );

      await repo.dismiss('1.2.2');

      expect(await repo.check(), isNull);
    });

    test('shows a dismissed optional version after the reminder window',
        () async {
      SharedPreferences.setMockInitialValues({
        'dismissed_update_version': '1.2.2',
        'dismissed_update_at': DateTime.utc(2026, 7, 1).toIso8601String(),
      });
      final repo = AppUpdateRepositoryImpl(
        prefs: await SharedPreferences.getInstance(),
        configUrl: Uri.parse('https://example.test/app-update.json'),
        currentVersion: () async => '1.2.1',
        now: () => DateTime.utc(2026, 7, 31, 0, 0, 1),
        client: MockClient(
          (_) async => http.Response(
            '''
              {
                "latestVersion": "1.2.2",
                "storeUrl": "https://example.test",
                "remindAfterDays": 30
              }
            ''',
            200,
          ),
        ),
      );

      expect(await repo.check(), isNotNull);
    });

    test('does not suppress a required update after dismissal', () async {
      final repo = await _repo(
        body: '''
          {
            "latestVersion": "1.2.2",
            "minimumSupportedVersion": "1.2.2",
            "storeUrl": "$androidPlayStoreUrl"
          }
        ''',
      );

      await repo.dismiss('1.2.2');
      final prompt = await repo.check();

      expect(prompt, isNotNull);
      expect(prompt!.required, isTrue);
    });

    test('does not suppress a later version after dismissing an older one',
        () async {
      SharedPreferences.setMockInitialValues({
        'dismissed_update_version': '1.2.2',
      });
      final repo = AppUpdateRepositoryImpl(
        prefs: await SharedPreferences.getInstance(),
        configUrl: Uri.parse('https://example.test/app-update.json'),
        currentVersion: () async => '1.2.1',
        now: () => DateTime.utc(2026, 7, 31),
        client: MockClient(
          (_) async => http.Response(
            '{"latestVersion":"1.2.3","storeUrl":"https://example.test"}',
            200,
          ),
        ),
      );

      expect(await repo.check(), isNotNull);
    });

    test('falls back to the Play Store URL when config has no valid store URL',
        () async {
      final repo = await _repo(
        body: '{"latestVersion":"1.2.2","storeUrl":"not-a-url"}',
      );

      final prompt = await repo.check();

      expect(prompt, isNotNull);
      expect(prompt!.storeUrl, Uri.parse(androidPlayStoreUrl));
    });

    test('returns null on network or malformed config failures', () async {
      final repo = await _repo(body: 'nope', status: 500);

      expect(await repo.check(), isNull);
    });
  });
}
