import 'package:al_quran/core/scroll/quran_scroll_behavior.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Metrics with the current pixel offset placed anywhere relative to the (moving)
// min/max extents the ScrollablePositionedList reports around its anchor.
ScrollMetrics _metrics({
  required double pixels,
  required double min,
  required double max,
}) =>
    FixedScrollMetrics(
      minScrollExtent: min,
      maxScrollExtent: max,
      pixels: pixels,
      viewportDimension: 600,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );

void main() {
  group('QuranClampEdgesPhysics — applyBoundaryConditions', () {
    const physics = QuranClampEdgesPhysics();

    test('refuses the whole delta when pulling below the top edge', () {
      // At the true top (pixels == min == 0). A pull-down proposes a negative
      // new value (moving toward/under the top) — it must be fully refused so
      // no rubber-band appears.
      final m = _metrics(pixels: 0, min: 0, max: 1800);
      expect(physics.applyBoundaryConditions(m, -30), -30);
    });

    test('refuses the whole delta when pushing past the bottom edge', () {
      // At the true bottom (pixels == max). Near the surah's last ayah the SPL
      // reports the anchor-relative extents, e.g. min=-1720/max=80.
      final m = _metrics(pixels: 80, min: -1720, max: 80);
      expect(physics.applyBoundaryConditions(m, 110), 30);
    });

    test('allows normal in-range scrolling (no clamp)', () {
      // Mid-content: a forward scroll from a valid interior offset is untouched
      // (BouncingScrollPhysics returns 0 overscroll in range).
      final m = _metrics(pixels: 500, min: 0, max: 1800);
      expect(physics.applyBoundaryConditions(m, 560), 0);
    });

    test('allows scrolling AWAY from the top edge (into content)', () {
      // At the top, but proposing a positive value (scrolling forward into the
      // list) must not be clamped — only pulls further past the edge are.
      final m = _metrics(pixels: 0, min: 0, max: 1800);
      expect(physics.applyBoundaryConditions(m, 40), 0);
    });

    test('allows scrolling AWAY from the bottom edge (into content)', () {
      final m = _metrics(pixels: 80, min: -1720, max: 80);
      expect(physics.applyBoundaryConditions(m, 40), 0);
    });

    // The bug behind the "stuck gap above the first row": a single drag delta
    // that CROSSES the edge in one frame (rather than starting already at it)
    // must be clamped to the edge. Missing these two cases let `pixels` land
    // far out of range, where it stayed until an unrelated scroll nudged the
    // ballistic spring into running.
    test('clamps a delta that jumps past the top edge in one frame', () {
      // Just inside the top (pixels=5), proposing -300 — must refuse only the
      // part beyond min, landing exactly on the edge, not 300px past it.
      final m = _metrics(pixels: 5, min: 0, max: 1800);
      expect(physics.applyBoundaryConditions(m, -300), -300);
    });

    test('clamps a delta that jumps past the bottom edge in one frame', () {
      final m = _metrics(pixels: 1795, min: 0, max: 1800);
      expect(physics.applyBoundaryConditions(m, 2100), 300);
    });

    test('applyTo preserves the type through the physics chain', () {
      final applied = physics.applyTo(const AlwaysScrollableScrollPhysics());
      expect(applied, isA<QuranClampEdgesPhysics>());
    });
  });

  group('QuranScrollBehavior — overscroll indicator', () {
    testWidgets(
        'skips the platform stretch/glow indicator on Android '
        'so it can never fight the clamp physics', (tester) async {
      // On Android, ScrollPosition.setPixels still reports the full refused
      // delta as "overscroll" when a clamp physics rejects it (that's how the
      // clamp math works — pixels = newPixels - overscroll), so Material's
      // default StretchingOverscrollIndicator kept visibly stretching list
      // content on every pull-past-edge even though the list itself never
      // moved — a flicker that read as changing top padding on a real
      // device. We supply our own bounce/clamp feel via QuranScrollPhysics,
      // so the platform decoration must be fully suppressed.
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const QuranScrollBehavior(),
          home: Scaffold(
            body: ListView(
              physics: const QuranClampEdgesPhysics(),
              children: [
                for (var i = 0; i < 30; i++)
                  SizedBox(height: 80, child: Text('$i')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.byType(ListView))).platform,
        TargetPlatform.android,
        reason: 'sanity check — the indicator is Android-only by default',
      );
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      expect(find.byType(GlowingOverscrollIndicator), findsNothing);
    });
  });
}
