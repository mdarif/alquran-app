/// The SPL `ItemScrollController` `alignment` a scroll-to-focus should use so
/// the target verse's leading edge never renders BEHIND the app bar / status
/// bar.
///
/// Reading (Mushaf) uses `extendBodyBehindAppBar`/`extendBody`, so its
/// scrollable spans the FULL screen height — an `alignment` fraction is
/// measured against that whole height, not just the space below the chrome.
/// [preferred] (the reciter-follow/select default, 0.04 — "near the top of the
/// paragraph") is fine with no chrome reserved, but on a typical screen the
/// app bar + status bar reserve well over 4% of the height, so a bare 0.04
/// scrolls the verse to a point that's actually behind them — appearing to
/// "hide" at the top while the chrome is shown.
///
/// [contentInsetTop] is the reserved top inset (status bar + app bar height —
/// the same value the list's own top content padding uses). [margin] is a
/// small extra clearance (logical px) so the verse doesn't sit flush against
/// the chrome's bottom edge.
double safeFocusAlignment({
  required double contentInsetTop,
  required double viewportHeight,
  double preferred = 0.04,
  double margin = 8,
}) {
  if (viewportHeight <= 0) return preferred;
  final safe = (contentInsetTop + margin) / viewportHeight;
  return safe > preferred ? safe : preferred;
}
