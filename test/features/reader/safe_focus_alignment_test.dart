import 'package:al_quran/features/reader/presentation/safe_focus_alignment.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reading (Mushaf) uses `extendBodyBehindAppBar`, so its scroll list spans the
/// FULL screen height — a scroll-to `alignment` fraction is measured against
/// that whole height, not just the space below the app bar. A fixed small
/// fraction (the reciter-follow/select default, 0.04 — "near the top of the
/// paragraph") looks fine with no chrome, but with the app bar + status bar
/// showing (which reserve far more than 4% of most screens), the verse's
/// leading edge scrolls to a point that renders BEHIND them — the bug reported
/// as the selected/playing verse "hiding" at the top while chrome is on.
void main() {
  test('reserves at least the app-bar/status-bar height, plus a margin', () {
    // 100px reserved chrome, 800px tall screen: 4% (32px) is not enough —
    // must be pushed down to clear the 100px + margin.
    final alignment = safeFocusAlignment(
      contentInsetTop: 100,
      viewportHeight: 800,
    );
    expect(alignment, greaterThan(100 / 800));
  });

  test('never renders the verse behind the reserved top inset', () {
    const insets = [0.0, 40.0, 80.0, 100.0, 140.0];
    const heights = [600.0, 800.0, 932.0];
    for (final inset in insets) {
      for (final height in heights) {
        final alignment = safeFocusAlignment(
          contentInsetTop: inset,
          viewportHeight: height,
        );
        expect(
          alignment * height,
          greaterThanOrEqualTo(inset),
          reason: 'inset=$inset height=$height',
        );
      }
    }
  });

  test('keeps the original small alignment when there is no top inset', () {
    expect(
      safeFocusAlignment(contentInsetTop: 0, viewportHeight: 800),
      0.04,
    );
  });

  test('falls back to the preferred alignment on a zero/unknown viewport', () {
    expect(
      safeFocusAlignment(contentInsetTop: 100, viewportHeight: 0),
      0.04,
    );
  });

  test('honours a custom preferred alignment when it already clears the inset',
      () {
    expect(
      safeFocusAlignment(
        contentInsetTop: 8,
        viewportHeight: 800,
        preferred: 0.2,
      ),
      0.2,
    );
  });
}
