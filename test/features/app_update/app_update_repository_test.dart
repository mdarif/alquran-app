import 'package:al_quran/features/app_update/data/repositories/app_update_repository_impl.dart';
import 'package:al_quran/core/app_update_config.dart';
import 'package:al_quran/features/app_update/domain/entities/app_update_check_result.dart';
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
    test('reports up to date when the installed app is current', () async {
      final repo = await _repo(
        body: '{"latestVersion":"1.2.1","storeUrl":"https://example.test"}',
      );

      final result = await repo.check();

      expect(result.status, AppUpdateCheckStatus.upToDate);
      expect(result.prompt, isNull);
    });

    test(
        'reports up to date when the installed app is newer than the config',
        () async {
      final repo = await _repo(
        currentVersion: '1.2.2',
        body: '{"latestVersion":"1.2.1","storeUrl":"https://example.test"}',
      );

      final result = await repo.check();

      expect(result.status, AppUpdateCheckStatus.upToDate);
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

      final result = await repo.check();

      expect(result.status, AppUpdateCheckStatus.available);
      final prompt = result.prompt!;
      expect(prompt.currentVersion, '1.2.1');
      expect(prompt.latestVersion, '1.2.2');
      expect(prompt.storeUrl, Uri.parse(androidPlayStoreUrl));
      expect(prompt.message, 'A newer version is available.');
      expect(prompt.required, isFalse);
    });

    test(
        'suppresses (reports up to date for) a dismissed optional version '
        'inside the reminder window', () async {
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

      expect((await repo.check()).status, AppUpdateCheckStatus.upToDate);
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

      expect((await repo.check()).status, AppUpdateCheckStatus.available);
    });

    test(
        'a manual check (ignoreDismissal) always tells the truth, even for '
        'a dismissed optional version', () async {
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

      final passive = await repo.check();
      expect(passive.status, AppUpdateCheckStatus.upToDate);

      final manual = await repo.check(ignoreDismissal: true);
      expect(manual.status, AppUpdateCheckStatus.available);
      expect(manual.prompt!.latestVersion, '1.2.2');
    });

    test('falls back to calm default copy when the config has no message',
        () async {
      final repo = await _repo(
        body: '{"latestVersion":"1.2.2","storeUrl":"https://example.test"}',
      );

      final result = await repo.check();

      expect(result.prompt!.message, 'A new version is available.');
    });

    test(
        'a required update always says "please update", ignoring any '
        'custom config message', () async {
      final repo = await _repo(
        body: '''
          {
            "latestVersion": "1.2.2",
            "minimumSupportedVersion": "1.2.2",
            "storeUrl": "$androidPlayStoreUrl",
            "message": "Custom marketing copy that should not show for a required update."
          }
        ''',
      );

      final result = await repo.check();

      expect(result.prompt!.required, isTrue);
      expect(result.prompt!.message, 'Please update to continue.');
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
      final result = await repo.check();

      expect(result.status, AppUpdateCheckStatus.available);
      expect(result.prompt!.required, isTrue);
    });

    // "Later" must only ever hide the exact version it was tapped for — a
    // dismissal of 1.2.2 must never suppress a later 1.2.3 prompt, or a
    // regression here would silently stop reminding users forever.
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

      final result = await repo.check();

      expect(result.status, AppUpdateCheckStatus.available);
      expect(result.prompt!.latestVersion, '1.2.3');
    });

    test('falls back to the Play Store URL when config has no valid store URL',
        () async {
      final repo = await _repo(
        body: '{"latestVersion":"1.2.2","storeUrl":"not-a-url"}',
      );

      final result = await repo.check();

      expect(result.status, AppUpdateCheckStatus.available);
      expect(result.prompt!.storeUrl, Uri.parse(androidPlayStoreUrl));
    });

    test('reports an error on an HTTP failure', () async {
      final repo = await _repo(body: 'nope', status: 500);

      final result = await repo.check();

      expect(result.status, AppUpdateCheckStatus.error);
      expect(result.error, isNotNull);
    });

    test('reports an error on a malformed config body', () async {
      final repo = await _repo(body: 'not json');

      final result = await repo.check();

      expect(result.status, AppUpdateCheckStatus.error);
    });

    test('reports an error when the network request throws', () async {
      SharedPreferences.setMockInitialValues(const {});
      final repo = AppUpdateRepositoryImpl(
        prefs: await SharedPreferences.getInstance(),
        configUrl: Uri.parse('https://example.test/app-update.json'),
        currentVersion: () async => '1.2.1',
        now: () => DateTime.utc(2026, 7, 31),
        client: MockClient((_) async => throw Exception('offline')),
      );

      final result = await repo.check();

      expect(result.status, AppUpdateCheckStatus.error);
      expect(result.error, isNotNull);
    });
  });
}
