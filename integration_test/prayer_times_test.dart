import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers/app_harness.dart';

/// P0 end-to-end for prayer times — the suite's first NATIVE-permission flows
/// (geolocator's location dialog). Patrol drives the OS dialog; the Dart side
/// asserts the indicator and sheet.
///
/// Run: `patrol test -t integration_test/prayer_times_test.dart`.
///
/// Caveats (see docs/E2E.md):
///  * The grant path needs the device/emulator to actually have a location fix
///    (Android: Extended controls → Location → set/send). Without one the coarse
///    request times out (10s) and degrades to the enable affordance — by design,
///    but the schedule won't appear.
///  * Native permission state PERSISTS across runs (bootstrapApp only clears
///    Dart prefs). The `isPermissionDialogVisible` guards keep tests from
///    hanging when a prior run already granted/denied; reset with
///    `adb shell pm reset-permissions` (Android) for a clean grant/deny.
void main() {
  patrolTest('Home shows the prayer-times indicator on launch', ($) async {
    await bootstrapApp($);

    // Clean install → no saved location yet → the discreet enable affordance.
    // (Same key on every form of the pill, so this holds once located too.)
    expect($(WidgetKeys.nextPrayerPill), findsOneWidget);
  });

  patrolTest('granting location reveals the all-times sheet', ($) async {
    await bootstrapApp($);

    // Tap the indicator → geolocator asks for permission → grant it natively.
    await $(WidgetKeys.nextPrayerPill).tap();
    if (await $.platformAutomator.mobile.isPermissionDialogVisible(
      timeout: const Duration(seconds: 10),
    )) {
      await $.platformAutomator.mobile.grantPermissionWhenInUse();
    }
    // Allow the coarse fix to resolve (bounded by the provider's 10s timeLimit).
    await $.pump(const Duration(seconds: 12));
    await $.pumpAndSettle();

    // The indicator is now the next-prayer pill; tapping opens the schedule.
    await $(WidgetKeys.nextPrayerPill).tap();
    expect($(WidgetKeys.prayerTimesSheet), findsOneWidget);
    // The five obligatory prayers plus the Sunrise marker are all listed.
    for (final name in ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      expect($(name), findsOneWidget);
    }
  });

  patrolTest('denying location degrades gracefully (no crash)', ($) async {
    await bootstrapApp($);

    await $(WidgetKeys.nextPrayerPill).tap();
    if (await $.platformAutomator.mobile.isPermissionDialogVisible(
      timeout: const Duration(seconds: 10),
    )) {
      await $.platformAutomator.mobile.denyPermission();
    }
    await $.pumpAndSettle();

    // Still alive, indicator still present — a wrong time is never shown.
    expect($(WidgetKeys.nextPrayerPill), findsOneWidget);
  });
}
