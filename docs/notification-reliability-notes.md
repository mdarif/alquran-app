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

- Repeat killed-app tests on at least one stock Android/Pixel device and one
  Samsung device before trusting the behavior broadly.
- Keep the debug scheduled test button available for internal QA until the
  notification flow has been validated across devices.

## 2026-08-05: guided sound-check implemented

Built the two follow-ups queued above:

- `MainActivity.kt` exposes `openNotificationSettings` on the existing
  `com.almarfa.al_quran/reminders` MethodChannel — deep-links to
  `Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS` for the Salat channel on
  Android 8+ (falls back to `ACTION_APP_NOTIFICATION_SETTINGS`).
- `NotificationScheduler.openNotificationSettings` / `.salatChannelId` wrap
  that channel from Dart (`LocalNotificationScheduler`).
- Enabling Salat Notifications now fires an immediate test notification
  (`PrayerNotificationsCubit.sendSoundCheck`) and asks "Did you hear or feel
  it?" — answering "No" opens the Salat channel's settings directly
  (`openSoundSettings`). A persistent "Didn't hear the test?" row lets a user
  re-run the check later (`reminders_settings_page.dart`,
  `_SoundCheckHint`/`_runSoundCheck`).

Still open: the on-device Samsung/stock-Android pass above hasn't been
repeated with this flow yet.

## 2026-08-06: root cause found — the alarms were never exact (OnePlus 15R)

`adb dumpsys` on the connected OnePlus (OxygenOS, app v1.2.4, targetSdk 36,
battery-exempt, `appops SCHEDULE_EXACT_ALARM: allow`) settled the "notification
shows up but stays silent / doesn't fire" report. What the device actually said:

- Channel state was **healthy**: `salat_notifications_nature_v4`, importance 4,
  `mSound=android.resource://com.almarfa.alquran/raw/salat_nudge`, vibration
  pattern intact, "Set as silent" off, Banner + Lock screen on.
- The WAV is **fine and playable**: stored uncompressed in the APK, and
  `dumpsys audio` shows one successful notification player at 48 kHz stereo —
  our file's exact format, unique on this device.
- But **every pending salat alarm was inexact**:
  `window=+1h0m0s0ms ... flags=0x8` (ALLOW_WHILE_IDLE without STANDALONE),
  i.e. `setAndAllowWhileIdle`. A sibling prayer app on the same phone schedules
  `windowLength 0 ... flags=0x9` — exact. Re-toggling Salat off/on and
  re-dumping reproduced it: freshly scheduled, still a 1-hour window.

So `canScheduleExactNotifications()` was returning false and `_scheduleMode()`
silently degraded to `AndroidScheduleMode.inexactAllowWhileIdle`. On Android 14+
`SCHEDULE_EXACT_ALARM` is **not** auto-granted, and the appop line above is the
default uid mode, not an effective grant. A prayer nudge then lands up to an
hour late, batched with whatever else AlarmManager is delivering, and in a Doze
batch the OS posts it without alerting — exactly "the notification is there but
it never made a sound".

Fixes (this commit):

- **`USE_EXACT_ALARM`** declared in the manifest (and in
  `tool/apply_notification_config.py`, since `android/` can be regenerated),
  with `SCHEDULE_EXACT_ALARM` capped at `maxSdkVersion="32"` — Play rejects both
  declared unbounded. USE_EXACT_ALARM is granted at install; prayer times are
  wall-clock alarms, which is the permission's intended use case. **Owner call:**
  this is a Play-policy-relevant declaration (allowed for alarm/clock/reminder
  apps) — flagged before the next release.
  Guarded by `test/tool/android_exact_alarm_permissions_test.dart`.
- **Sound check now posts immediately** (`NotificationScheduler.showNow` →
  `FlutterLocalNotificationsPlugin.show`) instead of scheduling itself "3 seconds
  out" through AlarmManager. With inexact alarms nothing was posted within the
  4 s the dialog waits — reproduced live: the "Did you hear or feel it?" prompt
  appeared while `dumpsys notification` still showed **no** notification for the
  app, so a user answering "No" was being sent to fix a setting that was fine.
- **`notificationIds` now includes `soundCheckId` + `debugTestId`.** Salat
  notifications are `autoCancel: false`, and those two ids were never in the
  cancel set — so every test left a notification in the shade permanently. The
  device dump showed the app already folded into the OS's autogroup bundle
  (`GroupHelper` → `g:Aggregate_AlertingSection`), which is its own alerting
  penalty.

### The permission alone wasn't enough — OxygenOS batches exact alarms too

Verified by installing each step on the device. `USE_EXACT_ALARM` flipped the
system's "Alarms & reminders" screen to ON-and-greyed-out (its locked state) and
changed `exactAllowReason` from `permission` to `policy_permission`, but the
alarms still came out windowed:

| scheduling mode | what `dumpsys alarm` showed |
| --- | --- |
| `inexactAllowWhileIdle` (old pre-flight downgrade) | `windowLength 3600000  flags 0x8` |
| `exactAllowWhileIdle` (accepted, no exception) | `windowLength 89680  flags 0x8` |
| **`alarmClock`** | **`windowLength 0  flags 0x9`** |

So OxygenOS accepts `setExactAndAllowWhileIdle` and then applies its own
batching window anyway. Only `setAlarmClock` — the user-visible alarm-clock path
the OS may not defer — lands unbatched, which is what the sibling prayer app on
the same phone (`com.moh.nusukapp`, `flags 0x9`) uses. `_zonedSchedule` now
tries `alarmClock` → `exactAllowWhileIdle` → `inexactAllowWhileIdle`, taking the
first the platform accepts, and records which one landed
(`lastScheduleWasExact`) so the debug delivery test reports
`Scheduled (exact)` vs `Scheduled (INEXACT - OS refused exact alarms)` instead of
us reading `dumpsys`.

Trade-off to watch: `setAlarmClock` can surface a system alarm indicator and is
visible to the user as a pending alarm. Acceptable for prayer times; revisit if
it looks wrong on other OEMs.

### Second cause: the OS was bundling our notifications, and bundled = silent

With delivery fixed, a scheduled salat notification posted at exactly its second
(verified, screen off) and was still **completely silent**. `dumpsys notification`
showed why: `GroupHelper → Autogrouped notifications` listed
`com.almarfa.alquran|20098` and `|20099` under `g:Aggregate_AlertingSection`.
Android only autogroups *ungrouped* notifications, and once ours were folded into
that bundle the children stopped alerting — the summary alerts instead, silently.
The trigger was our own leftovers: `autoCancel: false` plus test ids that nothing
cancelled meant a sound check sitting in the shade was enough to bundle the next
real prayer nudge.

Fix: salat and Sunnah notifications now carry their OWN `groupKey`
(`com.almarfa.alquran.salat` / `.sunnah`) with `GroupAlertBehavior.all`, so the
OS never force-bundles them.

### Verified end-to-end on the OnePlus (2026-08-06, debug build installed)

- All 8 pending salat alarms: `windowLength 0  flags 0x9`.
- Delivery test scheduled for 12:49:52 posted at **12:49:52**, screen off.
- `dumpsys audio` logged a notification player at **48000 Hz** (our
  `salat_nudge.wav`; every other notification sound on that phone is 44.1 kHz)
  — the nudge was audible.
- The immediate sound check posts and rings as a heads-up.

### Why the in-app sound check still seems silent (OEM foreground muting)

Reported after the fixes: tapping "Didn't hear the test notification?" produces
no sound. Measured — it is the OEM muting alerts for the app on screen, not a
bug in the notification:

| test | app state | result |
| --- | --- | --- |
| delivery test @ 12:49:52 | backgrounded, screen off | posted 12:49:52, **48 kHz player = audible** |
| delivery test @ 13:20:33 | kept in foreground | posted 13:20:33, **no player at all** |
| immediate sound check | foreground (always) | posted, no player |

The foreground record itself is healthy (`isNoisy=true`, `mIntercept=false`,
`mHidden=false`, channel sound resolved, and with its own `groupKey` it is no
longer autogrouped) — OxygenOS simply does not alert for the focused app. Real
prayer notifications arrive while the user is elsewhere, so they sound.

Consequence for the guided check: an immediate in-app notification can never
prove audibility on this OEM. The dialog copy now says so and points at
"Schedule salat test" + lock the phone as the real verification. If we want an
in-app check that always makes noise, it has to play the asset through the app's
own audio — but that would no longer test the notification channel, so it was
not done.

### The actual silencer on the OnePlus: app-level Ring / Vibrate were OFF

The owner found it in Settings → Apps → Al Quran → Notifications: **`Ring` and
`Vibrate` were both off** (other apps on the same phone had them on and were
audible). These ColorOS/OxygenOS switches sit ABOVE the channels and silence
every notification the app posts, whatever the channel says.

This is why the whole investigation kept showing a healthy channel: the toggles
appear in **no** `dumpsys` output and in **no** Android API, so neither the app
nor `adb` can read or set them. It also supersedes the "foreground muting"
reading of the silent 13:20:33 test — same silence, simpler cause. (One loose
end: `dumpsys audio` did log a 48 kHz player right after the 12:49:52 delivery,
which shouldn't happen with Ring off; either the toggle changed during the
session or that player belonged to something else. Not resolved.)

**Confirmed by the owner: with `Ring` + `Vibrate` switched on, the salat
notification is audible.** Combined with the alarm fixes above, prayer nudges
now arrive on the exact minute AND make a sound on this device.

Code consequence — `openSoundSettings()` now opens the **app-level**
notification settings instead of deep-linking to the Salat channel. The channel
page only offers "Allow notifications / Set as silent / Lock screen / Banner":
answering "No, didn't notice" used to land the user on the one screen where the
real cause is invisible. Covered by
`prayer_notifications_cubit_test.dart` and `reminders_settings_page_test.dart`.
