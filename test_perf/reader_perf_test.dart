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
import 'package:al_quran/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:al_quran/features/reader/presentation/widgets/mushaf_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';

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

  testWidgets('real-data app and reader frame timings', (tester) async {
    // Boot the real app with its real DI graph and bundled quran.db. Deliberately
    // preserve preferences: this benchmark runs on the owner's everyday device
    // and must not erase reading position, settings, bookmarks, or reminders.
    await GetIt.instance.reset();
    final startupFrames = <FrameTiming>[];
    void startupCb(List<FrameTiming> frames) => startupFrames.addAll(frames);
    binding.addTimingsCallback(startupCb);
    final startupClock = Stopwatch()..start();
    await configureDependencies();
    await tester.pumpWidget(const AlQuranApp());
    await tester.pumpAndSettle();
    startupClock.stop();
    await tester.pump(const Duration(milliseconds: 200));
    binding.removeTimingsCallback(startupCb);
    _printTimings('startup', startupFrames);
    debugPrint(
      'PERF-RESULT startup wallMs=${startupClock.elapsedMilliseconds}',
    );

    // Pinch must start from a known size: repeated benchmark runs otherwise leave
    // the persisted font at its maximum and silently measure a no-op. Restore the
    // owner's real preference even if a later phase fails.
    final settings = GetIt.I<ReaderSettingsRepository>();
    final originalFontSize = settings.fontSize;
    addTearDown(() => settings.setFontSize(originalFontSize));
    await settings.setFontSize(ReaderSettingsRepository.defaultFontSize);

    // Measure a phase: collect FrameTimings only around [action], print, clear.
    Future<void> measure(
      String label,
      Future<void> Function() action, {
      Duration trailing = const Duration(milliseconds: 200),
    }) async {
      final timings = <FrameTiming>[];
      void cb(List<FrameTiming> frames) => timings.addAll(frames);
      binding.addTimingsCallback(cb);
      await action();
      if (trailing > Duration.zero) await tester.pump(trailing);
      binding.removeTimingsCallback(cb);
      _printTimings(label, timings);
    }

    final homeList = find.byType(Scrollable).last;
    await measure('home-scroll', () async {
      for (var i = 0; i < 4; i++) {
        await tester.fling(homeList, const Offset(0, -600), 2500);
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 2; i++) {
        await tester.fling(homeList, const Offset(0, 600), 2500);
        await tester.pumpAndSettle();
      }
    });

    // Open Al-Baqarah (surah 2) — 286 verses, the heaviest section.
    await tester.scrollUntilVisible(
      find.byKey(WidgetKeys.surahTile(2)),
      -500,
      scrollable: homeList,
    );
    await measure('reader-open', () async {
      await tester.tap(find.byKey(WidgetKeys.surahTile(2)));
      await tester.pumpAndSettle();
    });
    // One gesture target for every phase: the section PageView. find.byType(
    // MushafView) is ambiguous — the PageView keeps the neighbour sections built
    // (that's what makes the swipe smooth), so 2+ MushafViews are alive. A
    // vertical fling on the PageView falls through to the visible page's scroll
    // view; a horizontal fling page-swipes; a two-finger pinch at its centre hits
    // the reader's zoom Listener.
    expect(find.byType(MushafView), findsWidgets);
    final reader = find.byType(PageView).first;

    await measure('reading-scroll', () async {
      for (var i = 0; i < 6; i++) {
        await tester.fling(reader, const Offset(0, -500), 2500);
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 3; i++) {
        await tester.fling(reader, const Offset(0, 500), 2500);
        await tester.pumpAndSettle();
      }
    });

    await measure('surah-swipe', () async {
      for (var i = 0; i < 3; i++) {
        await tester.fling(reader, const Offset(400, 0), 1500);
        await tester.pumpAndSettle();
      }
    });

    await measure('pinch', () async {
      await _pinch(tester, reader);
    });

    await measure('detailed-open', () async {
      await tester.tap(find.byKey(WidgetKeys.viewportToggle));
      await tester.pumpAndSettle();
    });

    await measure('detailed-scroll', () async {
      for (var i = 0; i < 6; i++) {
        final flingFrames = <FrameTiming>[];
        void flingCb(List<FrameTiming> frames) => flingFrames.addAll(frames);
        binding.addTimingsCallback(flingCb);
        await tester.fling(reader, const Offset(0, -500), 2500);
        await tester.pumpAndSettle();
        binding.removeTimingsCallback(flingCb);
        _printTimings('detailed-fling-${i + 1}', flingFrames);
      }
    });

    final play = find.byTooltip('Play recitation').hitTestable().first;
    if (play.evaluate().isNotEmpty) {
      await measure(
        'audio-feedback',
        () async {
          await tester.tap(play);
          await tester.pump();
          // FrameTimings are delivered in a later engine callback. Wait in real
          // time without pumping playback readiness, so this phase captures the
          // immediate loading frame only—not the later codec/network state.
          await Future<void>.delayed(const Duration(milliseconds: 100));
        },
        trailing: Duration.zero,
      );
      await measure('audio-ready', () async {
        await tester.pump(const Duration(seconds: 2));
      });
    }

    debugPrint('PERF-RESULT done');
    if (const bool.fromEnvironment('PERF_DIAGNOSTICS_PAUSE')) {
      debugPrint('PERF-RESULT diagnostics-window 60s');
      await Future<void>.delayed(const Duration(seconds: 60));
    }
  });
}

void _printTimings(String label, List<FrameTiming> timings) {
  final build = timings
      .map((f) => f.buildDuration.inMicroseconds / 1000.0)
      .toList()
    ..sort();
  final raster = timings
      .map((f) => f.rasterDuration.inMicroseconds / 1000.0)
      .toList()
    ..sort();
  debugPrint('PERF-RESULT $label build  ${_fmt(build)}');
  debugPrint('PERF-RESULT $label raster ${_fmt(raster)}');
}
