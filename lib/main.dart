import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get_it/get_it.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'app_navigator.dart';
import 'core/audio/audio_session_config.dart';
import 'core/di/injector.dart';
import 'core/feature_flags.dart';
import 'features/reminders/domain/scheduling/notification_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await _initReminders();
  if (FeatureFlags.audioRecitation) {
    // Best-effort: set the playback audio category so recitation is audible with
    // the iOS silent switch on and interruptions pause cleanly. Never blocks launch.
    try {
      await configureRecitationAudioSession();
    } catch (_) {
      // Falls back to the default session; playback still works.
    }
  }
  runApp(const AlQuranApp());
}

/// Timezone init (required by the notification scheduler's `zonedSchedule`) +
/// plugin init. Both are best-effort with a UTC fallback so a lookup failure
/// can never block launch — reminders just won't fire, the reader is unaffected.
Future<void> _initReminders() async {
  try {
    tzdata.initializeTimeZones();
    final local = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(local.identifier));
  } catch (_) {
    // tz.local defaults to UTC.
  }
  await GetIt.I<NotificationScheduler>().init(onSelect: routeFromPayload);
}
