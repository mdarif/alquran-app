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
