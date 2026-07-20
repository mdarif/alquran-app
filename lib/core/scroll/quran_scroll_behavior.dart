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
}
