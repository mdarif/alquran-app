// Dev-only preview for the prayer-times UI. Run with:
//   flutter run -t lib/main_prayer_diag.dart      (or `make diag-prayer`)
//
// It renders every indicator state and the sheet with FIXED synthetic times —
// no GPS, no waiting for a real prayer / forbidden window — so the design can be
// eyeballed (and screenshotted) instantly. Not part of the shipped app.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/mushaf_palette.dart';
import 'features/prayer_times/domain/entities/daily_prayer_times.dart';
import 'features/prayer_times/domain/entities/geo_location.dart';
import 'features/prayer_times/domain/entities/prayer.dart';
import 'features/prayer_times/domain/location/location_provider.dart';
import 'features/prayer_times/domain/repositories/prayer_times_repository.dart';
import 'features/prayer_times/presentation/cubit/prayer_times_cubit.dart';
import 'features/prayer_times/presentation/widgets/next_prayer_pill.dart';
import 'features/prayer_times/presentation/widgets/prayer_times_sheet.dart';

void main() => runApp(const PrayerDiagApp());

const _loc = GeoLocation(latitude: 28.61, longitude: 77.21, label: 'New Delhi');

/// A fixed synthetic day. Sunrise/Maghrib are symmetric about Dhuhr so solar
/// noon == Dhuhr and all three forbidden windows are valid:
///   after sunrise 6:00–6:15 · zenith 11:55–12:00 · before sunset 17:45–18:00
class _DiagRepo implements PrayerTimesRepository {
  const _DiagRepo({this.loc});

  final GeoLocation? loc;

  @override
  GeoLocation? get location => loc;

  @override
  Future<LocationResult> acquireLocation() async => loc == null
      ? const LocationResult(LocationStatus.denied)
      : LocationResult(LocationStatus.ok, loc);

  @override
  DailyPrayerTimes timesFor(GeoLocation location, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    DateTime t(int h, int m) => d.add(Duration(hours: h, minutes: m));
    return DailyPrayerTimes(
      fajr: t(5, 0),
      sunrise: t(6, 0),
      dhuhr: t(12, 0),
      asr: t(15, 30),
      maghrib: t(18, 0),
      isha: t(19, 45),
      location: location,
      date: d,
    );
  }
}

class PrayerDiagApp extends StatelessWidget {
  const PrayerDiagApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MushafPalette.of(DayPhase.duha).toTheme(),
        home: const _DiagPage(),
      );
}

class _DiagPage extends StatefulWidget {
  const _DiagPage();

  @override
  State<_DiagPage> createState() => _DiagPageState();
}

class _DiagPageState extends State<_DiagPage> {
  // Each labelled state is a cubit pinned to a fixed clock (2026-06-23) that
  // lands inside the matching window of the synthetic day above.
  late final List<(String, PrayerTimesCubit)> _states;

  PrayerTimesCubit _cubit(int h, int m, {bool located = true}) =>
      PrayerTimesCubit(
        _DiagRepo(loc: located ? _loc : null),
        clock: () => DateTime(2026, 6, 23, h, m),
      );

  @override
  void initState() {
    super.initState();
    _states = [
      ('Next prayer (permitted) — 14:00', _cubit(14, 0)),
      ('Dawn → Sunrise next — 05:30', _cubit(5, 30)),
      ('Forbidden · after sunrise — 06:05', _cubit(6, 5)),
      ('Forbidden · zenith — 11:57', _cubit(11, 57)),
      ('Forbidden · before sunset — 17:50', _cubit(17, 50)),
      ('No location — tap to enable', _cubit(14, 0, located: false)),
    ];
  }

  @override
  void dispose() {
    for (final (_, cubit) in _states) {
      cubit.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sampleDay = const _DiagRepo(loc: _loc).timesFor(
      _loc,
      DateTime(2026, 6, 23),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer-times diag')),
      // SingleChildScrollView (not ListView) so every section builds eagerly —
      // screenshot-friendly, and the smoke test sees off-screen rows too.
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionLabel('Home app-bar pill — every state'),
            for (final (label, cubit) in _states)
              _PillRow(label: label, cubit: cubit),
            const Divider(height: 32),
            const _SectionLabel('Reader app-bar — compact (icon only)'),
            for (final (label, cubit) in _states.take(5))
              _PillRow(label: label, cubit: cubit, compact: true),
            const Divider(height: 32),
            const _SectionLabel('Sheet — light (Duha)'),
            _SheetDemo(phase: DayPhase.duha, day: sampleDay),
            const Divider(height: 32),
            const _SectionLabel('Sheet — night (Isha)'),
            _SheetDemo(phase: DayPhase.isha, day: sampleDay),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
}

class _PillRow extends StatelessWidget {
  const _PillRow({
    required this.label,
    required this.cubit,
    this.compact = false,
  });

  final String label;
  final PrayerTimesCubit cubit;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            BlocProvider<PrayerTimesCubit>.value(
              value: cubit,
              child: NextPrayerPill(compact: compact),
            ),
          ],
        ),
      );
}

class _SheetDemo extends StatelessWidget {
  const _SheetDemo({required this.phase, required this.day});

  final DayPhase phase;
  final DailyPrayerTimes day;

  @override
  Widget build(BuildContext context) => Theme(
        data: MushafPalette.of(phase).toTheme(),
        child: Builder(
          builder: (ctx) => Container(
            color: Theme.of(ctx).colorScheme.surface,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: PrayerTimesSheet(times: day, next: Prayer.asr),
          ),
        ),
      );
}
