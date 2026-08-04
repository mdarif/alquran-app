import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'core/feature_flags.dart';
import 'features/prayer_times/domain/scheduling/prayer_notification_payload.dart';
import 'features/prayer_times/presentation/cubit/prayer_times_cubit.dart';
import 'features/prayer_times/presentation/widgets/prayer_times_sheet.dart';
import 'features/reader/domain/entities/last_read.dart';
import 'features/reader/domain/entities/reader_target.dart';
import 'features/reader/domain/repositories/last_read_repository.dart';
import 'features/reader/presentation/pages/reader_page.dart';
import 'features/reminders/domain/scheduling/reminder_payload.dart';

/// App-level navigation glue. A global navigator key lets us route from OUTSIDE
/// the widget tree — specifically, a tapped Sunnah-reminder or salat-time
/// notification. Lives at the app composition layer (not `core/`, which must
/// not import features).
final navigatorKey = GlobalKey<NavigatorState>();

/// Route a tapped notification's [payload] into the app: the Al-Kahf reminder
/// opens Surah 18, a salat-time notification opens the Prayer Times sheet;
/// everything else is informational (no route).
Future<void> routeFromPayload(String? payload) async {
  if (payload == openPrayerTimesPayload) {
    _openPrayerTimesSheet();
    return;
  }
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

/// Opens the same sheet [NextPrayerPill] does — best-effort: if the cubit
/// isn't reachable from the navigator's context, or today's times aren't
/// computed yet (no location), it's a silent no-op rather than a crash.
void _openPrayerTimesSheet() {
  final context = navigatorKey.currentContext;
  if (context == null) return;
  PrayerTimesCubit? cubit;
  try {
    cubit = BlocProvider.of<PrayerTimesCubit>(context);
  } catch (_) {
    cubit = null;
  }
  final today = cubit?.state.today;
  if (cubit == null || today == null) return;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => PrayerTimesSheet(
      times: today,
      next: cubit!.state.next?.prayer,
      hijriBaseDate: FeatureFlags.hijriDate ? cubit.hijriBaseDate : null,
      gregorianDate: cubit.gregorianDate,
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
