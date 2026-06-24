import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/hijri/hijri_date.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/mushaf_palette.dart';
import '../cubit/prayer_times_cubit.dart';

/// An elegant Islamic dateline for the top of the home (TOC) page: the Hijri
/// date in the display serif over the weekday + Gregorian date, finished with a
/// small geometric gold rule. (No crescent glyph — it isn't a Salafi symbol;
/// the refinement is typographic.)
///
/// Reads the prayer cubit DEFENSIVELY for the Maghrib-rolled date (the Hijri day
/// begins at sunset), falling back to the civil "today" if it isn't provided.
class HijriDateHeader extends StatelessWidget {
  const HijriDateHeader({super.key});

  @override
  Widget build(BuildContext context) {
    PrayerTimesCubit? cubit;
    try {
      cubit = BlocProvider.of<PrayerTimesCubit>(context);
    } catch (_) {
      cubit = null;
    }
    final civilNow = _todayCivil();
    final base = cubit?.hijriBaseDate ?? civilNow;
    final civil = cubit?.gregorianDate ?? civilNow;
    final hijri = HijriDate.fromGregorian(base);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gold =
        theme.extension<MushafColors>()?.gold ?? const Color(0xFF9C6F02);

    return Padding(
      key: WidgetKeys.hijriDateHeader,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Column(
        children: [
          Text(
            hijri.formatted,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: AppTheme.displayFontFamily,
              color: cs.onSurface,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${weekdayName(civil)} · ${formatGregorianDate(civil)}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 1.5,
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  DateTime _todayCivil() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }
}
