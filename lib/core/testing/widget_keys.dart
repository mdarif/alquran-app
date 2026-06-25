import 'package:flutter/widgets.dart';

/// Stable widget keys for end-to-end (Patrol) finders, kept in one place so the
/// tests and the widgets can't drift apart. These are inert in production (a
/// [Key] has no runtime effect) and only exist to make E2E selectors robust to
/// copy/layout changes.
class WidgetKeys {
  WidgetKeys._();

  // Home / navigation
  static const jumpButton = Key('home-jump-button');
  static const lastReadCard = Key('home-last-read-card');
  static Key surahTile(int surahId) => Key('surah-tile-$surahId');

  // Reader chrome
  static const viewportToggle = Key('reader-viewport-toggle');
  static const fontSizeButton = Key('reader-font-size-button');
  static const themeToggle = Key('reader-theme-toggle');
  // Uthmani/IndoPak script switch, inside the text-size panel (only rendered
  // while FeatureFlags.indopakScript is on).
  static const scriptToggle = Key('reader-script-toggle');

  // Reader content
  static const peekCard = Key('reader-peek-card');
  static const peekPrevButton = Key('reader-peek-prev-button');
  static const peekNextButton = Key('reader-peek-next-button');
  static const langStripClose = Key('reader-lang-strip-close');
  static Key langChip(String languageCode) => Key('lang-chip-$languageCode');

  // Audio recitation (only rendered while FeatureFlags.audioRecitation is on).
  static Key ayahPlayButton(int ayahId) => Key('ayah-play-$ayahId');
  static const peekPlayButton = Key('reader-peek-play-button');

  // Prayer times
  static const nextPrayerPill = Key('next-prayer-pill');
  static const prayerTimesSheet = Key('prayer-times-sheet');
  static const hijriDateLine = Key('hijri-date-line');

  // Sunnah reminders
  static const remindersButton = Key('reminders-button');
  static const remindersSheet = Key('reminders-sheet');
}
