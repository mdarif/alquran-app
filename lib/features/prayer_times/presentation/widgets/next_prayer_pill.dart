import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../domain/location/location_provider.dart';
import '../cubit/prayer_times_cubit.dart';
import '../cubit/prayer_times_state.dart';
import 'prayer_times_sheet.dart';

/// The subtle app-bar indicator: a static `Maghrib 6:42` pill (matching the
/// reader's `_PagePill` tone) that opens the all-five sheet on tap. When no
/// location is set yet, a discreet location icon offers one tap to enable.
///
/// Reads the cubit DEFENSIVELY (like [ThemeToggleButton]) so a screen pumped in
/// isolation doesn't crash.
class NextPrayerPill extends StatelessWidget {
  const NextPrayerPill({super.key});

  @override
  Widget build(BuildContext context) {
    PrayerTimesCubit? cubit;
    try {
      cubit = BlocProvider.of<PrayerTimesCubit>(context);
    } catch (_) {
      cubit = null;
    }
    if (cubit == null) return const SizedBox.shrink();

    final bloc = cubit;
    return BlocBuilder<PrayerTimesCubit, PrayerTimesState>(
      bloc: bloc,
      builder: (context, state) {
        final cs = Theme.of(context).colorScheme;

        if (!state.hasLocation || state.next == null) {
          return IconButton(
            key: WidgetKeys.nextPrayerPill,
            tooltip: 'Prayer times — set location',
            icon: const Icon(Icons.location_searching_rounded),
            onPressed: () => _enable(context, bloc),
          );
        }

        final next = state.next!;
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              key: WidgetKeys.nextPrayerPill,
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openSheet(context, bloc),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    '${next.prayer.label}  ${formatPrayerTime(next.at)}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _enable(BuildContext context, PrayerTimesCubit cubit) async {
    final messenger = ScaffoldMessenger.of(context);
    await cubit.enableLocation();
    final status = cubit.state.status;
    if (!context.mounted || status == null || status == LocationStatus.ok) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(_statusMessage(status)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openSheet(BuildContext context, PrayerTimesCubit cubit) {
    final state = cubit.state;
    final today = state.today;
    if (today == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // Size to the (small, fixed) content instead of the half-screen cap.
      isScrollControlled: true,
      builder: (_) => PrayerTimesSheet(times: today, next: state.next?.prayer),
    );
  }

  String _statusMessage(LocationStatus status) => switch (status) {
        LocationStatus.serviceOff =>
          'Turn on location services to see prayer times.',
        LocationStatus.deniedForever =>
          'Enable location for Al Quran in Settings to see prayer times.',
        _ => 'Location is needed to show prayer times.',
      };
}
