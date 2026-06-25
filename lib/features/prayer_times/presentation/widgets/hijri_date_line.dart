import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/hijri/hijri_date.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/mushaf_palette.dart';
import '../../../reminders/presentation/sunnah_occasion.dart';
import '../cubit/prayer_times_cubit.dart';

/// A tiny Hijri dateline (`08 Muharram 1448 AH`) — small and muted, sized to sit
/// as an overline above the home title. Reads the prayer cubit DEFENSIVELY for
/// the Maghrib-rolled date (the Hijri day begins at sunset), falling back to the
/// civil "today" when it isn't provided.
class HijriDateLine extends StatelessWidget {
  const HijriDateLine({super.key});

  @override
  Widget build(BuildContext context) {
    PrayerTimesCubit? cubit;
    try {
      cubit = BlocProvider.of<PrayerTimesCubit>(context);
    } catch (_) {
      cubit = null;
    }
    final now = DateTime.now();
    final base = cubit?.hijriBaseDate ?? DateTime(now.year, now.month, now.day);
    final theme = Theme.of(context);

    // On a Sunnah occasion (Ashura, Ayyam al-Bid …) the date itself is gilded —
    // gold + a touch bolder — to mark the day's importance. No extra element.
    final isSunnah = sunnahOccasionName(base) != null;
    final gold =
        theme.extension<MushafColors>()?.gold ?? const Color(0xFF9C6F02);

    return Text(
      HijriDate.fromGregorian(base).formatted,
      key: WidgetKeys.hijriDateLine,
      style: theme.textTheme.labelSmall?.copyWith(
        color: isSunnah ? gold : theme.colorScheme.onSurfaceVariant,
        fontWeight: isSunnah ? FontWeight.w700 : null,
        letterSpacing: 0.2,
      ),
    );
  }
}
