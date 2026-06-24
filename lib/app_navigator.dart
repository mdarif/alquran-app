import 'package:flutter/material.dart';

import 'features/reader/domain/entities/reader_target.dart';
import 'features/reader/presentation/pages/reader_page.dart';
import 'features/reminders/domain/scheduling/reminder_payload.dart';

/// App-level navigation glue. A global navigator key lets us route from OUTSIDE
/// the widget tree — specifically, a tapped Sunnah-reminder notification. Lives
/// at the app composition layer (not `core/`, which must not import features).
final navigatorKey = GlobalKey<NavigatorState>();

/// Route a tapped notification's [payload] into the app. v1: the Al-Kahf
/// reminder opens Surah 18; everything else is informational (no route).
void routeFromPayload(String? payload) {
  if (payload == openAlKahfPayload) {
    navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const ReaderPage(target: ReaderTarget.surah(18, 'Al-Kahf')),
      ),
    );
  }
}
