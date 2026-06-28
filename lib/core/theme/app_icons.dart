import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

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
/// NOTE: we deliberately use only the `_rounded` constants. In
/// `material_symbols_icons`, `Symbols.name` (no suffix) is the *Outlined* face
/// and `Symbols.name_rounded` is the *Rounded* one; referencing only Rounded
/// lets release builds tree-shake the Outlined/Sharp fonts away entirely.
class AppIcons {
  AppIcons._();

  // ── Reader: viewport + text controls ──────────────────────────────────────
  // App-bar toggle showing the view you'll switch TO: an open book for Reading
  // (Arabic only) vs. stacked rows for Detailed (per-ayah translation cards).
  // (Avoids `translate` here on purpose — its 文/A glyph reads as "Chinese"; see
  // LEARNINGS.md §3.)
  static const IconData viewReading = Symbols.import_contacts_rounded;
  static const IconData viewDetailed = Symbols.list_rounded;
  static const IconData textSize = Symbols.text_increase_rounded;
  static const IconData settings = Symbols.settings_rounded;
  static const IconData close = Symbols.close_rounded;

  // ── Translation filter (Detailed view) ────────────────────────────────────
  static const IconData translate = Symbols.translate_rounded;
  static const IconData expand = Symbols.expand_more_rounded;
  static const IconData chipSelected = Symbols.check_rounded;
  static const IconData chipAdd = Symbols.add_rounded;

  // ── Verse actions ─────────────────────────────────────────────────────────
  /// Prostration-verse marker (rendered filled).
  static const IconData sajda = Symbols.star_rounded;
  static const IconData more = Symbols.more_horiz_rounded;
  static const IconData overflow = Symbols.more_vert_rounded;
  static const IconData about = Symbols.info_rounded;
  static const IconData copy = Symbols.content_copy_rounded;
  static const IconData share = Symbols.share_rounded;

  // ── Audio recitation ──────────────────────────────────────────────────────
  /// Inline (Detailed tile) arrow controls.
  static const IconData play = Symbols.play_arrow_rounded;
  static const IconData pause = Symbols.pause_rounded;

  /// Prominent (peek card) circular controls — rendered filled.
  static const IconData playCircle = Symbols.play_circle_rounded;
  static const IconData pauseCircle = Symbols.pause_circle_rounded;
  static const IconData audioError = Symbols.error_rounded;

  // ── Navigation ────────────────────────────────────────────────────────────
  /// AppBar back button — wired into the theme's [ActionIconThemeData] so the
  /// auto-generated leading button joins the family instead of the platform
  /// default (the bare iOS chevron / Android arrow).
  static const IconData back = Symbols.arrow_back_rounded;
  static const IconData chevronLeft = Symbols.chevron_left_rounded;

  /// Forward / drill-in chevron.
  static const IconData chevronRight = Symbols.chevron_right_rounded;
  static const IconData scrollTop = Symbols.keyboard_arrow_up_rounded;

  /// Last-Read marker (rendered filled).
  static const IconData bookmark = Symbols.bookmark_rounded;

  /// "Jump to" (Page · Juz · Hizb · Ruku) entry, then the four divisions.
  static const IconData jumpMenu = Symbols.format_list_numbered_rounded;
  static const IconData page = Symbols.auto_stories_rounded;
  static const IconData juz = Symbols.book_2_rounded;
  static const IconData hizb = Symbols.bookmarks_rounded;
  static const IconData ruku = Symbols.segment_rounded;

  // ── Light of Day: reading-light phases (dawn → night) ─────────────────────
  static const IconData phaseFajr = Symbols.wb_twilight_rounded;
  static const IconData phaseDuha = Symbols.light_mode_rounded;
  static const IconData phaseAsr = Symbols.wb_sunny_rounded;

  /// Dusk shares the twilight glyph with Fajr but is rendered **filled** — the
  /// golden going-down light vs. the rising dawn.
  static const IconData phaseMaghrib = Symbols.wb_twilight_rounded;
  static const IconData phaseIsha = Symbols.dark_mode_rounded;

  /// "Light of Day (auto)" selected check (rendered filled).
  static const IconData autoSelected = Symbols.check_circle_rounded;

  // ── Reminders ─────────────────────────────────────────────────────────────
  /// Reminders bell — filled when reminders are on.
  static const IconData reminders = Symbols.notifications_rounded;
  static const IconData alKahf = Symbols.menu_book_rounded;
  static const IconData batteryAlert = Symbols.battery_alert_rounded;
  static const IconData scheduleTest = Symbols.schedule_send_rounded;

  /// Debug status indicators (rendered filled).
  static const IconData statusPass = Symbols.check_circle_rounded;
  static const IconData statusFail = Symbols.cancel_rounded;

  // ── Prayer times ──────────────────────────────────────────────────────────
  static const IconData sunrise = Symbols.wb_twilight_rounded;
  static const IconData forbidden = Symbols.do_not_disturb_on_rounded;
  static const IconData locationSearch = Symbols.location_searching_rounded;
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
