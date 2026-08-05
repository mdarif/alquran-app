# Notification Reliability Notes

## 2026-08-05: ColorOS / OnePlus CPH2767 Salat notification test

Device testing showed that Salat scheduled notifications can fire after the app
is killed, but audible presentation depends on ColorOS app-level notification
settings that the app cannot force on.

What was verified:

- `POST_NOTIFICATIONS` granted.
- `SCHEDULE_EXACT_ALARM` app-op allowed.
- `RUN_ANY_IN_BACKGROUND` allowed.
- Battery optimization exemption granted.
- Scheduled test notification posted after the app was killed.
- Fresh Salat channel created with max importance, sound, banner, and vibration:
  `salat_notifications_nature_v4`.
- Fresh Sunnah channel created with max importance:
  `sunnah_reminders_v2`.

Observed ColorOS behavior:

- Al Quran's top-level notification settings could still show `Ring` and
  `Vibrate` disabled even when Android's channel dump reported sound and
  vibration enabled.
- Manually enabling top-level `Ring` / `Vibrate` made the Salat notification
  audible.
- Uninstall/reinstall did not fully clear old ColorOS notification preference
  records; `adb dumpsys notification` showed older Al Quran app settings entries
  for previous install UIDs.

Current code mitigation:

- Salat and Sunnah notification channels use fresh ids and `Importance.max`.
- Salat notifications explicitly set custom sound and vibration.
- Salat enable flow requests exact alarm permission and battery optimization
  exemption, matching Sunnah reminders.
- `salat_nudge.wav` was raised by +3 dB from the original; +6 dB tested too
  loud once ColorOS `Ring` was enabled.

Open concern:

- We are not fully confident in notification UX on Oppo/OnePlus/ColorOS. The app
  likely needs a future user-facing "sound/reliability" helper that deep-links to
  Android notification settings when users do not hear the scheduled test.

Recommended future work:

- Add a native method to open app notification settings, and ideally Salat
  channel settings (`Settings.ACTION_APP_NOTIFICATION_SETTINGS` /
  `Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS`).
- Add an in-app hint near Salat notifications: if the scheduled test appears but
  is silent, enable `Ring` / `Vibrate` in Al Quran notification settings.
- Repeat killed-app tests on at least one stock Android/Pixel device and one
  Samsung device before trusting the behavior broadly.
- Keep the debug scheduled test button available for internal QA until the
  notification flow has been validated across devices.
