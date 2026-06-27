import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';

/// A subtle "back to top" affordance for the reader. It fades and slides in
/// once the user has scrolled down a long surah, and smoothly returns them to
/// the top on tap. Visibility and action are owned by the host viewport (which
/// holds the scroll controller); this widget is purely presentational.
class ScrollToTopButton extends StatelessWidget {
  const ScrollToTopButton({
    required this.visible,
    required this.onPressed,
    super.key,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.4),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        // Ignore taps while hidden so the invisible button isn't a dead zone.
        child: IgnorePointer(
          ignoring: !visible,
          child: Material(
            color: cs.secondaryContainer,
            shape: const CircleBorder(),
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.25),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AppIcon(
                  AppIcons.scrollTop,
                  color: cs.onSecondaryContainer,
                  semanticLabel: 'Scroll to top',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
