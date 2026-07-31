import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Scroll feel for the whole app (reading is the primary gesture, so it should
/// feel premium and identical on every platform).
///
/// - iOS-style [BouncingScrollPhysics] everywhere (Android's default clamp +
///   edge glow feels stiff for a long-form reader).
/// - A gentler, critically-damped spring so a fast fling settles with a smooth
///   glide instead of snapping to a stop.
class QuranScrollPhysics extends BouncingScrollPhysics {
  const QuranScrollPhysics({super.parent});

  @override
  QuranScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      QuranScrollPhysics(parent: buildParent(ancestor));

  // Softer than the default (stiffness 100, ratio 1.1): a lower stiffness and
  // critical damping make the end-of-fling and overscroll return ease in
  // smoothly with no abrupt halt or overshoot.
  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: 0.5,
        stiffness: 70,
        ratio: 1.0,
      );
}

/// [QuranScrollPhysics] that keeps the fling glide/settle feel of bouncing
/// physics but HARD-CLAMPS at the true content edges — no rubber-band when you
/// pull down at a surah's first ayah, nor up at its last (like the "Al Quran
/// word-by-word" reader). Mid-content scrolling is unaffected.
///
/// Used for the reader's page list ([ScrollablePositionedList]). That widget
/// lays its slivers out around a moving center anchor, so [ScrollMetrics.pixels]
/// is NOT an absolute offset — but at every moment `min`/`maxScrollExtent` are
/// reported RELATIVE to the current anchor (e.g. min=0/max=1800 at the top,
/// min=-1720/max=80 at the bottom). So `pixels <= minScrollExtent` and
/// `pixels >= maxScrollExtent` are still exact "at the true top / bottom" tests,
/// and clamping in [applyBoundaryConditions] (as [ClampingScrollPhysics] does)
/// works without any external position tracking. [applyBoundaryConditions] is
/// the amount of the requested delta to REFUSE; returning `value - pixels`
/// refuses all of it (a full clamp), matching [ClampingScrollPhysics].
class QuranClampEdgesPhysics extends QuranScrollPhysics {
  const QuranClampEdgesPhysics({super.parent});

  @override
  QuranClampEdgesPhysics applyTo(ScrollPhysics? ancestor) =>
      QuranClampEdgesPhysics(parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Underscroll: moving toward, and already at/past, the top edge.
    if (value < position.pixels &&
        position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    // Overscroll: moving toward, and already at/past, the bottom edge.
    if (value > position.pixels &&
        position.pixels >= position.maxScrollExtent) {
      return value - position.pixels;
    }
    // Hit the top edge THIS frame: a single delta can cross the boundary from
    // inside (e.g. pixels=5 → value=-300). Without this case the call fell
    // through to BouncingScrollPhysics, which refuses nothing (returns 0.0) —
    // so `pixels` landed far out of range and STAYED there, since only a later
    // ballistic run springs it back. On devices whose OEM touch layer drops the
    // final pointer-up, that ballistic never runs, leaving a permanent gap above
    // the first row until an unrelated scroll nudged it. Refuse only the part
    // beyond the edge, exactly as [ClampingScrollPhysics] does.
    if (value < position.minScrollExtent &&
        position.minScrollExtent < position.pixels) {
      return value - position.minScrollExtent;
    }
    // Hit the bottom edge this frame (mirror of the above).
    if (position.pixels < position.maxScrollExtent &&
        position.maxScrollExtent < value) {
      return value - position.maxScrollExtent;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

/// Applies [QuranScrollPhysics] globally and lets pointer/trackpad drag scroll
/// too (so the same feel carries to desktop/web if the app expands there).
class QuranScrollBehavior extends MaterialScrollBehavior {
  const QuranScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const QuranScrollPhysics();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  // Android's stock stretch/glow indicator reacts to the raw overscroll
  // delta ScrollPosition reports on every boundary hit — including from
  // QuranClampEdgesPhysics, which hard-clamps `pixels` but still reports the
  // refused delta (that's how the clamp math works: pixels = newPixels -
  // overscroll). So the indicator kept visibly stretching/squashing list
  // content on pull-past-edge even though the list itself never moved,
  // reading as flickering top padding on real Android devices. We already
  // supply our own bounce/clamp feel via [QuranScrollPhysics], so skip the
  // platform decoration entirely.
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
