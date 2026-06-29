import 'package:flutter/widgets.dart';

/// Bundled Material Symbols Rounded subset (see tools/icon/subset_symbols.py — a correct, tiny replacement for the
/// package font, which Flutter's release tree-shaking corrupts).
const String _kSymbolFamily = 'MaterialSymbolsRounded';

/// The app's single in-app icon family: **Material Symbols Rounded**.
///
/// Every in-app icon is referenced through [AppIcons] (a semantic name → glyph),
/// rendered via the [AppIcon] widget at a size from [AppIconSize]. Routing all
/// icons through one place keeps the icon language consistent — one family, one
/// weight — and enforceable from a single file.
///
/// Style convention: glyphs are **outlined by default**; pass `filled: true` to
/// [AppIcon] for an *active / selected* state (the Material Symbols FILL axis) —
/// e.g. the on-state of the reminders bell, the Last-Read bookmark, a selected
/// status indicator.
///
/// Each glyph is an [IconData] codepoint from **Material Symbols Rounded**,
/// rendered from a tiny bundled subset ([_kSymbolFamily]) rather than the
/// `material_symbols_icons` package font — Flutter's release icon tree-shaking
/// corrupts that 4-axis variable font's variation data, blanking every `filled`
/// / non-default-size icon. The trailing `// name` comments are the source
/// glyph names; regenerate the subset after adding/removing an icon with
/// `python3 tools/icon/subset_symbols.py` (and build release with
/// `--no-tree-shake-icons`). See docs/brand.md.
class AppIcons {
  AppIcons._();

  // ── Reader: viewport + text controls ──────────────────────────────────────
  // App-bar toggle showing the view you'll switch TO: an open book for Reading
  // (Arabic only) vs. stacked rows for Detailed (per-ayah translation cards).
  // (Avoids `translate` here on purpose — its 文/A glyph reads as "Chinese"; see
  // LEARNINGS.md §3.)
  static const IconData viewReading = IconData(
    0xe0e0,
    fontFamily: _kSymbolFamily,
  ); // import_contacts_rounded
  static const IconData viewDetailed = IconData(
    0xe896,
    fontFamily: _kSymbolFamily,
  ); // list_rounded
  static const IconData textSize = IconData(
    0xeae2,
    fontFamily: _kSymbolFamily,
  ); // text_increase_rounded
  static const IconData settings = IconData(
    0xe8b8,
    fontFamily: _kSymbolFamily,
  ); // settings_rounded
  static const IconData close = IconData(
    0xe5cd,
    fontFamily: _kSymbolFamily,
  ); // close_rounded

  // ── Translation ───────────────────────────────────────────────────────────
  /// Reading peek card's show/hide-translation toggle: an open eye when the
  /// translation is shown, the slashed eye ([visibilityOff]) when hidden — the
  /// universal, unambiguous "hide" affordance. (Avoids the `translate` 文/A glyph,
  /// which reads as "Chinese", and the `subtitles` glyph, which reads as a note —
  /// see LEARNINGS.md §3.)
  static const IconData visibility = IconData(
    0xe8f4,
    fontFamily: _kSymbolFamily,
  ); // visibility_rounded
  static const IconData visibilityOff = IconData(
    0xe8f5,
    fontFamily: _kSymbolFamily,
  ); // visibility_off_rounded
  static const IconData expand = IconData(
    0xe5cf,
    fontFamily: _kSymbolFamily,
  ); // expand_more_rounded
  static const IconData chipSelected = IconData(
    0xe668,
    fontFamily: _kSymbolFamily,
  ); // check_rounded
  static const IconData chipAdd = IconData(
    0xe145,
    fontFamily: _kSymbolFamily,
  ); // add_rounded

  // ── Verse actions ─────────────────────────────────────────────────────────
  /// Prostration-verse marker (rendered filled).
  static const IconData sajda = IconData(
    0xf09a,
    fontFamily: _kSymbolFamily,
  ); // star_rounded
  static const IconData more = IconData(
    0xe5d3,
    fontFamily: _kSymbolFamily,
  ); // more_horiz_rounded
  static const IconData overflow = IconData(
    0xe5d4,
    fontFamily: _kSymbolFamily,
  ); // more_vert_rounded
  static const IconData about = IconData(
    0xe88e,
    fontFamily: _kSymbolFamily,
  ); // info_rounded
  static const IconData copy = IconData(
    0xe14d,
    fontFamily: _kSymbolFamily,
  ); // content_copy_rounded
  static const IconData share = IconData(
    0xe80d,
    fontFamily: _kSymbolFamily,
  ); // share_rounded

  // ── Audio recitation ──────────────────────────────────────────────────────
  /// Inline (Detailed tile) arrow controls.
  static const IconData play = IconData(
    0xe037,
    fontFamily: _kSymbolFamily,
  ); // play_arrow_rounded
  static const IconData pause = IconData(
    0xe034,
    fontFamily: _kSymbolFamily,
  ); // pause_rounded

  /// Prominent (peek card) circular controls — rendered filled.
  static const IconData playCircle = IconData(
    0xe1c4,
    fontFamily: _kSymbolFamily,
  ); // play_circle_rounded
  static const IconData pauseCircle = IconData(
    0xe1a2,
    fontFamily: _kSymbolFamily,
  ); // pause_circle_rounded
  static const IconData audioError = IconData(
    0xf8b6,
    fontFamily: _kSymbolFamily,
  ); // error_rounded

  // ── Navigation ────────────────────────────────────────────────────────────
  /// AppBar back button — wired into the theme's [ActionIconThemeData] so the
  /// auto-generated leading button joins the family instead of the platform
  /// default (the bare iOS chevron / Android arrow).
  static const IconData back = IconData(
    0xe5c4,
    fontFamily: _kSymbolFamily,
  ); // arrow_back_rounded
  static const IconData chevronLeft = IconData(
    0xe5cb,
    fontFamily: _kSymbolFamily,
  ); // chevron_left_rounded

  /// Forward / drill-in chevron.
  static const IconData chevronRight = IconData(
    0xe5cc,
    fontFamily: _kSymbolFamily,
  ); // chevron_right_rounded
  static const IconData scrollTop = IconData(
    0xe316,
    fontFamily: _kSymbolFamily,
  ); // keyboard_arrow_up_rounded

  /// Last-Read marker (rendered filled).
  static const IconData bookmark = IconData(
    0xe8e7,
    fontFamily: _kSymbolFamily,
  ); // bookmark_rounded

  /// "Jump to" (Page · Juz · Hizb · Ruku) entry, then the four divisions.
  static const IconData jumpMenu = IconData(
    0xe242,
    fontFamily: _kSymbolFamily,
  ); // format_list_numbered_rounded
  static const IconData page = IconData(
    0xe666,
    fontFamily: _kSymbolFamily,
  ); // auto_stories_rounded
  static const IconData juz = IconData(
    0xf53e,
    fontFamily: _kSymbolFamily,
  ); // book_2_rounded
  static const IconData hizb = IconData(
    0xe98b,
    fontFamily: _kSymbolFamily,
  ); // bookmarks_rounded
  static const IconData ruku = IconData(
    0xe94b,
    fontFamily: _kSymbolFamily,
  ); // segment_rounded

  // ── Light of Day: reading-light phases (dawn → night) ─────────────────────
  static const IconData phaseFajr = IconData(
    0xe1c6,
    fontFamily: _kSymbolFamily,
  ); // wb_twilight_rounded
  static const IconData phaseDuha = IconData(
    0xe518,
    fontFamily: _kSymbolFamily,
  ); // light_mode_rounded
  static const IconData phaseAsr = IconData(
    0xe430,
    fontFamily: _kSymbolFamily,
  ); // wb_sunny_rounded

  /// Dusk shares the twilight glyph with Fajr but is rendered **filled** — the
  /// golden going-down light vs. the rising dawn.
  static const IconData phaseMaghrib = IconData(
    0xe1c6,
    fontFamily: _kSymbolFamily,
  ); // wb_twilight_rounded
  static const IconData phaseIsha = IconData(
    0xe51c,
    fontFamily: _kSymbolFamily,
  ); // dark_mode_rounded

  /// "Light of Day (auto)" selected check (rendered filled).
  static const IconData autoSelected = IconData(
    0xf0be,
    fontFamily: _kSymbolFamily,
  ); // check_circle_rounded

  // ── Reminders ─────────────────────────────────────────────────────────────
  /// Reminders bell — filled when reminders are on.
  static const IconData reminders = IconData(
    0xe7f5,
    fontFamily: _kSymbolFamily,
  ); // notifications_rounded
  static const IconData alKahf = IconData(
    0xea19,
    fontFamily: _kSymbolFamily,
  ); // menu_book_rounded
  static const IconData batteryAlert = IconData(
    0xe19c,
    fontFamily: _kSymbolFamily,
  ); // battery_alert_rounded
  static const IconData scheduleTest = IconData(
    0xea0a,
    fontFamily: _kSymbolFamily,
  ); // schedule_send_rounded

  /// Debug status indicators (rendered filled).
  static const IconData statusPass = IconData(
    0xf0be,
    fontFamily: _kSymbolFamily,
  ); // check_circle_rounded
  static const IconData statusFail = IconData(
    0xe888,
    fontFamily: _kSymbolFamily,
  ); // cancel_rounded

  // ── Prayer times ──────────────────────────────────────────────────────────
  static const IconData sunrise = IconData(
    0xe1c6,
    fontFamily: _kSymbolFamily,
  ); // wb_twilight_rounded
  static const IconData forbidden = IconData(
    0xf08f,
    fontFamily: _kSymbolFamily,
  ); // do_not_disturb_on_rounded
  static const IconData locationSearch = IconData(
    0xe1b7,
    fontFamily: _kSymbolFamily,
  ); // location_searching_rounded
}

/// The fixed in-app icon size scale. Use these instead of bare numbers so icons
/// stay visually consistent across screens.
class AppIconSize {
  AppIconSize._();

  /// Tiny inline marker (e.g. the forbidden-window note).
  static const double dense = 14;

  /// Inside text / pills / chips, and list chevrons.
  static const double inline = 16;

  /// Beside a label (Last Read, reliability hints, status rows).
  static const double label = 18;

  /// In-row tap targets (play / pause / more).
  static const double action = 22;

  /// App-bar actions and `ListTile` leading — the default.
  static const double bar = 24;

  /// The peek card's primary audio control.
  static const double prominent = 30;
}

/// Renders an [AppIcons] glyph in the app's house style: Material Symbols
/// Rounded at one default weight/grade, with [filled] driving the FILL axis for
/// active/selected states. Drops in anywhere an [Icon] does (`IconButton`,
/// `PopupMenuButton.icon`, `ListTile.leading`, `OutlinedButton.icon`, …).
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    this.size = AppIconSize.bar,
    this.color,
    this.filled = false,
    this.weight = _defaultWeight,
    this.semanticLabel,
    super.key,
  });

  static const double _defaultWeight = 400;

  final IconData icon;
  final double size;
  final Color? color;

  /// Active/selected state → solid glyph (Material Symbols FILL axis).
  final bool filled;
  final double weight;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color,
      fill: filled ? 1 : 0,
      weight: weight,
      grade: 0,
      // Match the optical size to the rendered size for crisp strokes, clamped
      // to the font's supported opsz axis (20–48).
      opticalSize: size < 20 ? 20 : (size > 48 ? 48 : size),
      semanticLabel: semanticLabel,
    );
  }
}
