import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/app_update_config_builder.dart';

void main() {
  group('buildAppUpdateConfigJson', () {
    test('builds the production soft-update config', () {
      final json = buildAppUpdateConfigJson(latestVersion: '1.2.2');

      final decoded = jsonDecode(json) as Map<String, Object?>;

      expect(decoded['latestVersion'], '1.2.2');
      expect(decoded['minimumSupportedVersion'], '1.0.0');
      expect(decoded['storeUrl'], defaultStoreUrl);
      expect(decoded['message'], 'A newer version is available.');
      expect(decoded['remindAfterDays'], 7);
    });

    test('rejects invalid versions and reminder windows', () {
      expect(
        () => buildAppUpdateConfigJson(latestVersion: '1.2'),
        throwsArgumentError,
      );
      expect(
        () => buildAppUpdateConfigJson(
          latestVersion: '1.2.3',
          remindAfterDays: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
