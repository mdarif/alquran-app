import 'package:al_quran/core/database/db_seeder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldReseed', () {
    test('re-seeds when the writable copy does not exist yet', () {
      expect(
        shouldReseed(
          fileExists: false,
          bundledVersion: 'v1',
          installedVersion: 'v1',
        ),
        isTrue,
      );
    });

    test('does not re-seed when the file exists and versions match', () {
      expect(
        shouldReseed(
          fileExists: true,
          bundledVersion: 'v1',
          installedVersion: 'v1',
        ),
        isFalse,
      );
    });

    test('re-seeds when the bundled DB version changed', () {
      expect(
        shouldReseed(
          fileExists: true,
          bundledVersion: 'v2',
          installedVersion: 'v1',
        ),
        isTrue,
      );
    });

    test('re-seeds an existing install that has no recorded version', () {
      expect(
        shouldReseed(
          fileExists: true,
          bundledVersion: 'v1',
          installedVersion: null,
        ),
        isTrue,
      );
    });
  });
}
