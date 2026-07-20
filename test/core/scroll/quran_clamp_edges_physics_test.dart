import 'package:al_quran/core/scroll/quran_scroll_behavior.dart';
import 'package:flutter/widgets.dart';
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

    test('applyTo preserves the type through the physics chain', () {
      final applied = physics.applyTo(const AlwaysScrollableScrollPhysics());
      expect(applied, isA<QuranClampEdgesPhysics>());
    });
  });
}
