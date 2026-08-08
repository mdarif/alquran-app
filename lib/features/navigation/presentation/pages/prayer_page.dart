// ignore_for_file: require_trailing_commas, unawaited_futures

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/feature_flags.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../prayer_times/domain/location/location_provider.dart';
import '../../../prayer_times/presentation/cubit/prayer_times_cubit.dart';
import '../../../prayer_times/presentation/cubit/prayer_notifications_cubit.dart';
import '../../../prayer_times/presentation/cubit/prayer_notifications_state.dart';
import '../../../prayer_times/presentation/cubit/prayer_times_state.dart';
import '../../../prayer_times/presentation/pages/prayer_location_page.dart';
import '../../../prayer_times/presentation/widgets/prayer_times_sheet.dart';

/// The Prayer tab: today's schedule (Phase 1 scope — current/next prayer,
/// all five times, Hijri date) promoted from the old bottom sheet into a full
/// page. Reads [PrayerTimesCubit] DEFENSIVELY (like [NextPrayerPill]) so an
/// isolated pump doesn't crash.
class PrayerPage extends StatelessWidget {
  const PrayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    PrayerTimesCubit? cubit;
    try {
      cubit = BlocProvider.of<PrayerTimesCubit>(context);
    } catch (_) {
      cubit = null;
    }
    return Scaffold(
      key: WidgetKeys.prayerPage,
      appBar: AppBar(
        title: const Text('Prayer'),
        actions: [
          if (cubit != null)
            _LocationPill(
              cubit: cubit,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const PrayerLocationPage(),
                ),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: cubit == null
          ? const _PrayerUnavailable()
          : _PrayerBody(cubit: cubit),
    );
  }
}

class _PrayerBody extends StatelessWidget {
  const _PrayerBody({required this.cubit});

  final PrayerTimesCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PrayerTimesCubit, PrayerTimesState>(
      bloc: cubit,
      builder: (context, state) {
        if (state.timesUnavailable) return const _PrayerUnavailable();
        final today = state.today;
        if (!state.hasLocation || today == null) {
          return _NoLocation(cubit: cubit);
        }
        return SingleChildScrollView(
          child: Column(
            children: [
              const _ZoneMismatchBanner(),
              PrayerTimesSheet(
                times: today,
                next: state.next?.prayer,
                hijriBaseDate:
                    FeatureFlags.hijriDate ? cubit.hijriBaseDate : null,
                gregorianDate: cubit.gregorianDate,
                nextFajr: state.tomorrow?.fajr,
                compact: false,
                showDetailedRows: false,
                showHeading: false,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ZoneMismatchBanner extends StatelessWidget {
  const _ZoneMismatchBanner();

  @override
  Widget build(BuildContext context) {
    PrayerNotificationsCubit? cubit;
    try {
      cubit = BlocProvider.of<PrayerNotificationsCubit>(context);
    } catch (_) {
      cubit = null;
    }
    if (cubit == null) return const SizedBox.shrink();
    return BlocBuilder<PrayerNotificationsCubit, PrayerNotificationsState>(
      bloc: cubit,
      builder: (context, state) {
        if (!state.zoneMismatch) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Alerts paused — this city is in a different timezone than your phone.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                ),
              ),
              TextButton(
                onPressed: () => cubit?.turnOnAnyway(),
                child: const Text('Turn on anyway'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LocationPill extends StatelessWidget {
  const _LocationPill({required this.cubit, required this.onTap});
  final PrayerTimesCubit cubit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<PrayerTimesCubit, PrayerTimesState>(
        bloc: cubit,
        builder: (context, state) {
          final label = state.today?.location.label;
          final scheme = Theme.of(context).colorScheme;
          final hasLabel = label != null && label.isNotEmpty;
          final pillLabel = hasLabel ? label : 'Location';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Material(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        AppIcons.editLocation,
                        size: AppIconSize.inline,
                        color: scheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        pillLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _NoLocation extends StatelessWidget {
  const _NoLocation({required this.cubit});

  final PrayerTimesCubit cubit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.locationSearch, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Enable location to see prayer times.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: () => _enable(context, cubit),
                child: const Text('Enable location')),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const PrayerLocationPage())),
              child: const Text('Set manually'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enable(BuildContext context, PrayerTimesCubit cubit) async {
    await cubit.enableLocation();
    final status = cubit.state.status;
    if (!context.mounted || status == null || status == LocationStatus.ok) {
      return;
    }
    Navigator.push(context,
        MaterialPageRoute<void>(builder: (_) => const PrayerLocationPage()));
  }
}

/// Shown when the cubit isn't reachable (isolated pump) or the location is
/// known but the day has no computable schedule (polar latitude) — matches
/// [NextPrayerPill]'s "nothing we can offer" fallback.
class _PrayerUnavailable extends StatelessWidget {
  const _PrayerUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Prayer times aren\'t available right now.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
