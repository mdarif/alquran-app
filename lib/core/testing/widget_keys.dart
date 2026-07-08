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
  static const surahSearchButton = Key('home-surah-search-button');
  static const surahSearchField = Key('home-surah-search');
  static const surahSearchBack = Key('home-surah-search-back');
  static const homeOverflowMenu = Key('home-overflow-menu');
  static const shareAppButton = Key('home-share-app-button');
  static const aboutMenuButton = Key('home-about-menu-button');

  // Reader chrome
  static const viewportToggle = Key('reader-viewport-toggle');
  static const settingsButton = Key('reader-settings-button');
  static const themeToggle = Key('reader-theme-toggle');
  // Uthmani/IndoPak script switch, inside the text-size panel (only rendered
  // while FeatureFlags.indopakScript is on) — this keys the two-card row.
  static const scriptToggle = Key('reader-script-toggle');
  // The individual script preview cards; pass the ArabicScript.name
  // ('uthmani' | 'indopak').
  static Key scriptCard(String script) => Key('reader-script-card-$script');
  // The A−/A+ size steppers flanking the slider in the text-size panel.
  static const fontDecrease = Key('reader-font-decrease');
  static const fontIncrease = Key('reader-font-increase');
  // Live sample text that resizes with the slider in the text-size panel.
  static const textSizePreview = Key('reader-text-size-preview');

  // Reader content
  static const peekCard = Key('reader-peek-card');
  static const peekPrevButton = Key('reader-peek-prev-button');
  static const peekNextButton = Key('reader-peek-next-button');
  // Translation language rows in the Display sheet ('ur' | 'hi' | 'en').
  static Key langOption(String languageCode) =>
      Key('lang-option-$languageCode');
  // Inline translation chips in the Reading peek card ('ur' | 'hi' | 'en').
  static Key peekLangOption(String languageCode) =>
      Key('peek-lang-option-$languageCode');
  // Collapse/expand the peek card's translation (read/listen to Arabic alone).
  static const peekTranslationToggle = Key('reader-peek-translation-toggle');

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

  // About / credits
  static const aboutButton =
      Key('home-about-button'); // invisible home-title tap
  static const aboutPage = Key('about-page');
  static const aboutCredits =
      Key('about-credits-link'); // About → Credits screen
  static const creditsPage = Key('credits-page');
  static const aboutLicenses = Key('about-licenses');
}
