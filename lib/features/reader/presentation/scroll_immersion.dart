import 'package:flutter/widgets.dart';

/// Turns raw scroll notifications into "hide/show the reader chrome" intents for
/// immersive reading (like the Al Quran word-by-word app): reading forward — a
/// finger swipe **up**, the content scrolling on — hides the app bar, player bar,
/// and OS system bars; a reverse swipe **down** brings them back; and the very top
/// always shows them.
///
/// Small per-frame deltas are accumulated (and the accumulator resets on a
/// direction change), so a little jitter never flips the bars — only a sustained
/// drag past [threshold] toggles. Only finger-driven drags move the chrome:
/// programmatic focus/reciter scrolls (no `dragDetails`) are ignored, except the
/// top guard which always reveals.
class ScrollImmersionDetector {
  ScrollImmersionDetector({this.threshold = 24});

  /// Sustained drag distance (logical px, one direction) that toggles the chrome.
  final double threshold;

  double _accum = 0;
  bool _hidden = false;

  /// Feed a notification. Returns the new *hidden* state only when it CHANGES
  /// (true = chrome hidden, false = chrome shown), else null (no change).
  bool? update(ScrollNotification n) {
    // At/above the top the chrome is always shown, whatever moved the list.
    if (n.metrics.pixels <= n.metrics.minScrollExtent + 4) {
      _accum = 0;
      if (_hidden) {
        _hidden = false;
        return false;
      }
      return null;
    }
    if (n is! ScrollUpdateNotification) return null;
    // Only a real finger drag moves the chrome — a programmatic scroll
    // (focus/reciter follow) carries no dragDetails and must not toggle it.
    if (n.dragDetails == null) return null;
    final delta = n.scrollDelta ?? 0;
    if (delta == 0) return null;
    // Measure a sustained move in ONE direction: reset when the sign flips.
    if (delta.sign != _accum.sign) _accum = 0;
    _accum += delta;
    if (_accum >= threshold && !_hidden) {
      _hidden = true;
      return true;
    }
    if (_accum <= -threshold && _hidden) {
      _hidden = false;
      return false;
    }
    return null;
  }
}
