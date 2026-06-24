# iOS home-screen widgets — Xcode setup (one-time)

The Swift/plist/entitlements here are code-complete, but a WidgetKit widget needs
an **extension target** in the Xcode project, which must be added in Xcode (it
can't be safely scripted into `project.pbxproj`). ~5 minutes.

App Group used everywhere: **`group.com.almarfa.alQuran`** (matches the
`com.almarfa.alQuran` bundle id and `WidgetPublisher.appGroupId` in Dart).

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
