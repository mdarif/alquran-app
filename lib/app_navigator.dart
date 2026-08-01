import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'features/reader/domain/entities/last_read.dart';
import 'features/reader/domain/entities/reader_target.dart';
import 'features/reader/domain/repositories/last_read_repository.dart';
import 'features/reader/presentation/pages/reader_page.dart';
import 'features/reminders/domain/scheduling/reminder_payload.dart';

/// App-level navigation glue. A global navigator key lets us route from OUTSIDE
/// the widget tree — specifically, a tapped Sunnah-reminder notification. Lives
/// at the app composition layer (not `core/`, which must not import features).
final navigatorKey = GlobalKey<NavigatorState>();

/// Route a tapped notification's [payload] into the app. v1: the Al-Kahf
/// reminder opens Surah 18; everything else is informational (no route).
Future<void> routeFromPayload(String? payload) async {
  if (payload != openAlKahfPayload) return;
  // If the reader is already partway through Al-Kahf, the Friday reminder should
  // continue it, not restart at ayah 1 (and not clobber that resume point with
  // the fresh open). Any other saved position is irrelevant here.
  final resume = await _lastReadInKahf();
  unawaited(
    navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => resume == null
            ? const ReaderPage(target: ReaderTarget.surah(18, 'Al-Kahf'))
            : ReaderPage(
                target: resume.target,
                focusAyahId: resume.ayahId,
                initialDetailed: resume.detailed,
              ),
      ),
    ),
  );
}

/// The saved resume point, but only when it sits inside Al-Kahf. Best-effort:
/// an unregistered repo (isolated widget test) or a read failure just means the
/// surah opens from the top, exactly as before.
Future<LastRead?> _lastReadInKahf() async {
  try {
    final last = await GetIt.I<LastReadRepository>().load();
    return last?.surahId == 18 ? last : null;
  } catch (_) {
    return null;
  }
}
