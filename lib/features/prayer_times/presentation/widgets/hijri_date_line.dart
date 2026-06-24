import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/hijri/hijri_date.dart';
import '../../../../core/testing/widget_keys.dart';
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

    return Text(
      HijriDate.fromGregorian(base).formatted,
      key: WidgetKeys.hijriDateLine,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.2,
      ),
    );
  }
}
