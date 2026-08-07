import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/feature_flags.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../prayer_times/domain/location/location_provider.dart';
import '../../../prayer_times/presentation/cubit/prayer_times_cubit.dart';
import '../../../prayer_times/presentation/cubit/prayer_times_state.dart';
import '../../../prayer_times/presentation/widgets/prayer_times_sheet.dart';
import 'reminders_settings_page.dart';

/// The Prayer tab: today's schedule (Phase 1 scope — current/next prayer,
/// all five times, Hijri date) promoted from the old bottom sheet into a full
/// page, plus an entry point into Reminders. Reads [PrayerTimesCubit]
/// DEFENSIVELY (like [NextPrayerPill]) so an isolated pump doesn't crash.
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
      appBar: AppBar(title: const Text('Prayer')),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrayerTimesSheet(
                times: today,
                next: state.next?.prayer,
                hijriBaseDate: FeatureFlags.hijriDate ? cubit.hijriBaseDate : null,
                gregorianDate: cubit.gregorianDate,
              ),
              const Divider(height: 1),
              ListTile(
                key: WidgetKeys.remindersButton,
                leading: const AppIcon(AppIcons.reminders),
                title: const Text('Reminders'),
                subtitle: const Text('Sunnah occasions + Salat notifications'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RemindersSettingsPage(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
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
              child: const Text('Enable location'),
            ),
          ],
        ),
      ),
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

  String _statusMessage(LocationStatus status) => switch (status) {
        LocationStatus.serviceOff =>
          'Turn on location services to see prayer times.',
        LocationStatus.deniedForever =>
          'Enable location for Al Quran in Settings to see prayer times.',
        _ => 'Location is needed to show prayer times.',
      };
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
