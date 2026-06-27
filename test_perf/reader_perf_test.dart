// Reader performance benchmark — opens the 286-verse Al-Baqarah (the heaviest
// section) and measures frame build + raster timings while fling-scrolling,
// swiping between surahs, and pinch-zooming.
//
// Lives in test_perf/ (NOT integration_test/) on purpose: integration_test/ is
// the Patrol e2e bundle, and `patrol test` regenerates test_bundle.dart by
// importing every *_test.dart it finds there. This is a plain
// IntegrationTestWidgetsFlutterBinding test (not a patrolTest), so bundling it
// would clash with PatrolBinding. test_perf/ is invisible to both `patrol test`
// and bare `flutter test` (which only scans test/).
//
// Run on a device in PROFILE mode via flutter drive (plain `flutter test` can't
// do --profile, and watchPerformance's VM-service timeline doesn't connect under
// drive — so we read FrameTimings straight from the engine):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=test_perf/reader_perf_test.dart --profile -d <device>
//   (or: make perf DEVICE=<id>)
//
// Each phase prints "PERF-RESULT <phase> ..." as it finishes, so a failure in a
// later phase still leaves the earlier phases' numbers in the log. An iOS
// *simulator* can't run profile mode at all, and a sim/emulator isn't
// representative — use a physical device for trustworthy numbers.
import 'dart:ui' show FrameTiming;

import 'package:al_quran/app.dart';
import 'package:al_quran/core/di/injector.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/reader/presentation/widgets/mushaf_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _avg(List<double> xs) =>
    xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
double _pct(List<double> xs, double p) =>
    xs.isEmpty ? 0 : xs[(p * (xs.length - 1)).round()];
int _over(List<double> xs, double t) => xs.where((x) => x > t).length;
String _fmt(List<double> xs) =>
    'n=${xs.length} avg=${_avg(xs).toStringAsFixed(1)} '
    'p50=${_pct(xs, .5).toStringAsFixed(1)} '
    'p90=${_pct(xs, .9).toStringAsFixed(1)} '
    'p99=${_pct(xs, .99).toStringAsFixed(1)} '
    'max=${(xs.isEmpty ? 0.0 : xs.last).toStringAsFixed(1)} '
    'over16=${_over(xs, 16)} over8=${_over(xs, 8)}';

Future<void> _pinch(WidgetTester tester, Finder target) async {
  final c = tester.getCenter(target);
  final f1 = await tester.startGesture(c + const Offset(-20, 0));
  final f2 = await tester.startGesture(c + const Offset(20, 0));
  for (var i = 0; i < 8; i++) {
    await f1.moveBy(const Offset(-10, 0));
    await f2.moveBy(const Offset(10, 0));
    await tester.pump();
  }
  await f1.up();
  await f2.up();
  await tester.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reader scroll / swipe / pinch frame timings', (tester) async {
    // --- boot the real app (real DI + bundled quran.db), clean prefs ---
    await GetIt.instance.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await configureDependencies();
    await tester.pumpWidget(const AlQuranApp());
    await tester.pumpAndSettle();

    // Open Al-Baqarah (surah 2) — 286 verses, the heaviest section.
    await tester.tap(find.byKey(WidgetKeys.surahTile(2)));
    await tester.pumpAndSettle();
    // One gesture target for every phase: the section PageView. find.byType(
    // MushafView) is ambiguous — the PageView keeps the neighbour sections built
    // (that's what makes the swipe smooth), so 2+ MushafViews are alive. A
    // vertical fling on the PageView falls through to the visible page's scroll
    // view; a horizontal fling page-swipes; a two-finger pinch at its centre hits
    // the reader's zoom Listener.
    expect(find.byType(MushafView), findsWidgets);
    final reader = find.byType(PageView).first;

    // Measure a phase: collect FrameTimings only around [action], print, clear.
    Future<void> measure(String label, Future<void> Function() action) async {
      final t = <FrameTiming>[];
      void cb(List<FrameTiming> x) => t.addAll(x);
      binding.addTimingsCallback(cb);
      await action();
      await tester.pump(const Duration(milliseconds: 200)); // flush trailing
      binding.removeTimingsCallback(cb);
      final build = t
          .map((f) => f.buildDuration.inMicroseconds / 1000.0)
          .toList()
        ..sort();
      final raster = t
          .map((f) => f.rasterDuration.inMicroseconds / 1000.0)
          .toList()
        ..sort();
      debugPrint('PERF-RESULT $label build  ${_fmt(build)}');
      debugPrint('PERF-RESULT $label raster ${_fmt(raster)}');
    }

    await measure('scroll', () async {
      for (var i = 0; i < 6; i++) {
        await tester.fling(reader, const Offset(0, -500), 2500);
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 3; i++) {
        await tester.fling(reader, const Offset(0, 500), 2500);
        await tester.pumpAndSettle();
      }
    });

    await measure('swipe', () async {
      for (var i = 0; i < 3; i++) {
        await tester.fling(reader, const Offset(-400, 0), 1500);
        await tester.pumpAndSettle();
      }
    });

    await measure('pinch', () async {
      await _pinch(tester, reader);
    });

    debugPrint('PERF-RESULT done');
  });
}
