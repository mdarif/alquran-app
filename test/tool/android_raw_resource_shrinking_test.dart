import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Release builds run Android's resource shrinker, which only keeps
/// resources it can prove are referenced by a static `R.raw.*` lookup.
/// `salat_nudge` is looked up by STRING NAME at runtime
/// (`RawResourceAndroidNotificationSound('salat_nudge')` inside
/// flutter_local_notifications), so the shrinker can't see the reference and
/// silently drops the file from release APKs.
///
/// Confirmed on-device: every `scheduleOneShot` call in a release build threw
/// `PlatformException(invalid_sound, ...)` — swallowed by the scheduler's own
/// `catch (_) {}` — so Salat notifications were completely unscheduled with
/// no visible error, while the identical debug build worked. `flutter
/// analyze` and `flutter test` do not catch this: it's a release-only Gradle
/// packaging difference, not a Dart issue.
///
/// Fix: `android/app/src/main/res/raw/keep.xml` with `tools:keep`, the
/// standard Android resource-shrinker keep rule
/// (https://developer.android.com/build/shrink-code#keep-resources).
void main() {
  test('res/raw/keep.xml keeps salat_nudge from the release resource shrinker',
      () {
    final keepFile = File('android/app/src/main/res/raw/keep.xml');
    expect(
      keepFile.existsSync(),
      isTrue,
      reason: 'Without this keep rule, release builds silently strip '
          'salat_nudge.wav and every Salat notification fails to schedule.',
    );
    expect(keepFile.readAsStringSync(), contains('@raw/salat_nudge'));
  });

  test('the salat_nudge raw resource this keep rule protects still exists', () {
    expect(
      File('android/app/src/main/res/raw/salat_nudge.wav').existsSync(),
      isTrue,
    );
  });
}
