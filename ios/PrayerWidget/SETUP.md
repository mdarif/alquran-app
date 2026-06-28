# iOS home-screen widgets — setup

App Group used everywhere: **`group.com.almarfa.alQuran`** — a shared-container
id, independent of the bundle id (`com.almarfa.alquran`), so it keeps its
original `alQuran` spelling; it must match `WidgetPublisher.appGroupId` in Dart.

## Automated (done)

The WidgetKit **extension target** is created by a script (using the `xcodeproj`
gem that ships with CocoaPods) rather than by hand in Xcode:

```bash
ruby ios/PrayerWidget/add_target.rb   # idempotent; re-run if ios/ is regenerated
```

It adds the `PrayerWidget` app-extension target (bundle id
`com.almarfa.alquran.PrayerWidget`), compiles `PrayerWidget.swift`, embeds it in
Runner, and sets the App Group entitlement on both targets.

- **Simulator:** no code signing needed — just `flutter run`.
- **Real device:** open `ios/Runner.xcworkspace` and set your Team on the
  **PrayerWidget** target (Signing & Capabilities) once.

## Manual fallback (if you ever need to redo it in Xcode)

## Steps

1. **Open the workspace** (not the project): `open ios/Runner.xcworkspace`.

2. **Add the target:** File ▸ New ▸ Target… ▸ iOS ▸ **Widget Extension**.
   - Product Name: **`PrayerWidget`** (must match — it's the WidgetKit bundle).
   - **Uncheck** "Include Live Activity" and "Include Configuration App Intent"
     (these are static widgets).
   - Finish ▸ **Activate** the scheme if prompted.

3. **Use this code, not the generated stub:** Xcode generates `PrayerWidget.swift`
   (+ maybe `*Bundle.swift` / `AppIntent.swift`). Delete those and add this
   folder's **`PrayerWidget.swift`** to the PrayerWidget target (or paste its
   contents over the generated file). There must be exactly **one `@main`**
   (`PrayerWidgetBundle`, here). You can likewise use this folder's `Info.plist`.

4. **App Group on BOTH targets** (Signing & Capabilities ▸ + Capability ▸ App
   Groups), add the same group to each:
   - **Runner** → `group.com.almarfa.alQuran`
   - **PrayerWidget** → `group.com.almarfa.alQuran`
   Point each target's "Code Signing Entitlements" build setting at the matching
   file here (`Runner/Runner.entitlements`, `PrayerWidget/PrayerWidget.entitlements`)
   if Xcode doesn't wire them automatically.

5. **Signing:** set the same Team on the PrayerWidget target as Runner.
   (Deployment target 14.0+ is fine — the default for a Widget Extension.)

## Notes

- The extension only **reads** `UserDefaults(suiteName:)` — it does **not** need
  the `home_widget` pod. Only the Runner app writes (via `WidgetPublisher`).
- Run the app once and grant location so it writes the shared payload, then add
  the widgets: long-press home screen ▸ + ▸ search **Al Quran** ▸ **Next prayer**
  (small) and **Today's prayers** (medium).
- We commit `ios/`, so this target survives. If you ever re-run `flutter create`
  for the desktop/web runners, it won't touch `ios/`.
