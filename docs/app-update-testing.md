# Soft Update Reminder — Local Testing

The soft update reminder is controlled by `FeatureFlags.softUpdateReminder` and
reads a tiny JSON file from `APP_UPDATE_CONFIG_URL`.

## Serve a Local Config

Terminal 1:

```bash
make serve-update-config
```

This serves `dev/app-update/update-available.json` at:

```text
http://127.0.0.1:8787/app-update.json
```

For a physical Android device connected over USB, first forward the port:

```bash
make android-update-reverse
```

Then run the app in Terminal 2:

```bash
make run-update-local
```

For Android emulator, use the host bridge instead of `adb reverse`:

```bash
make run-update-local UPDATE_CONFIG_HOST=10.0.2.2
```

For iOS simulator, the default `127.0.0.1` is fine.

## Scenarios

Update banner appears:

```bash
make serve-update-config UPDATE_CONFIG=update-available.json
```

Tapping `Update` should open:

```text
https://play.google.com/store/apps/details?id=com.almarfa.alquran
```

No banner because the app is current:

```bash
make serve-update-config UPDATE_CONFIG=current-version.json
```

No banner because config is malformed:

```bash
make serve-update-config UPDATE_CONFIG=malformed.json
```

Offline/failure behavior:

1. Stop `make serve-update-config`.
2. Relaunch with `make run-update-local`.
3. Home should show no update banner and no error.

Dismiss behavior:

1. Serve `update-available.json`.
2. Launch with `make run-update-local`.
3. Tap `Later`.
4. Relaunch with the same config: the banner should stay hidden.
5. Increase `latestVersion` in `dev/app-update/update-available.json`.
6. Restart the fixture server and app: the banner should appear again.

The local fixture's `latestVersion` is intentionally ahead of `pubspec.yaml`
(`1.2.1+5` at the time this doc was written).

## Troubleshooting

If a physical Android device shows no banner:

1. Confirm the fixture is reachable on the Mac:
   `curl http://127.0.0.1:8787/app-update.json`
2. Confirm USB forwarding is active:
   `adb reverse --list`
3. Run `make android-update-reverse`, then fully restart the app.
4. If you previously tapped `Later`, bump `latestVersion` in the fixture or clear
   app data before retesting.
