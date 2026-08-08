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
  static const startReadingSurah = Key('home-start-reading-surah');
  static const startReadingJuz = Key('home-start-reading-juz');
  static const startReadingPage = Key('home-start-reading-page');
  static Key surahTile(int surahId) => Key('surah-tile-$surahId');
  static const surahSearchButton = Key('home-surah-search-button');
  static const surahSearchField = Key('home-surah-search');
  static const surahSearchBack = Key('home-surah-search-back');
  static const appSettingsPage = Key('app-settings-page');
  static const tafsirPage = Key('tafsir-page');
  static const tafsirAyahSheet = Key('tafsir-ayah-sheet');
  static const tafsirEndMarker = Key('tafsir-end-marker');
  static const tafsirBackToTop = Key('tafsir-back-to-top');
  static const tafsirEntryList = Key('tafsir-entry-list');
  static const tafsirTextDecrease = Key('tafsir-text-decrease');
  static const tafsirTextIncrease = Key('tafsir-text-increase');
  static const tafsirInTextSearchField = Key('tafsir-in-text-search-field');
  static const tafsirSearchNext = Key('tafsir-search-next');
  static const tafsirSearchField = Key('tafsir-search-field');
  static const tafsirSearchClear = Key('tafsir-search-clear');
  static Key tafsirResourceRow(String slug) => Key('tafsir-row-$slug');
  static Key tafsirInstalled(String slug) => Key('tafsir-installed-$slug');
  static Key tafsirDownload(String slug) => Key('tafsir-download-$slug');
  static Key tafsirRemove(String slug) => Key('tafsir-remove-$slug');
  static Key tafsirLanguageFilter(String code) =>
      Key('tafsir-language-filter-$code');
  static const bookmarksPage = Key('bookmarks-page');
  static const appUpdateBanner = Key('app-update-banner');
  static const appUpdateNowButton = Key('app-update-now-button');
  static const appUpdateLaterButton = Key('app-update-later-button');
  static const appUpdateMenuButton = Key('home-app-update-menu-button');
  static const shareAppButton = Key('home-share-app-button');
  static const aboutMenuButton = Key('home-about-menu-button');

  // Reader chrome
  static const viewportToggle = Key('reader-viewport-toggle');
  static const settingsButton = Key('reader-settings-button');
  // The full-screen Settings page itself, and its Reset row.
  static const readerSettingsPage = Key('reader-settings-page');
  static const readerSettingsReset = Key('reader-settings-reset');
  static const themeToggle = Key('reader-theme-toggle');
  static const readerBookmarksButton = Key('reader-bookmarks-button');
  static const readingThemeMenuButton = Key('settings-reading-theme-button');
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
  // Translation rows in the Display sheet. Keyed by edition SLUG, not language
  // code — a language may carry several editions.
  static Key langOption(String slug) => Key('lang-option-$slug');
  // Inline translation chips in the Reading peek card, keyed by edition slug.
  static Key peekLangOption(String slug) => Key('peek-lang-option-$slug');
  // Translations screen: download / remove a downloadable edition.
  static Key editionRow(String slug) => Key('edition-row-$slug');
  static Key editionSelected(String slug) => Key('edition-selected-$slug');
  static Key editionDownload(String slug) => Key('edition-download-$slug');
  static Key editionRemove(String slug) => Key('edition-remove-$slug');
  static const translationsSearchField = Key('translations-search-field');
  static const translationsSearchClear = Key('translations-search-clear');
  static const translationsLanguageCount = Key(
    'translations-language-count',
  );
  static Key translationsLanguageFilter(String code) =>
      Key('translations-language-filter-$code');
  // Collapse/expand the peek card's translation (read/listen to Arabic alone).
  static const peekTranslationToggle = Key('reader-peek-translation-toggle');
  // Settings-sheet switch: open the translation peek on tap (default off).
  static const translationPeekToggle = Key('reader-translation-peek-toggle');
  // Settings-sheet switch (Detailed): show the Arabic matn above translations
  // (default on; off = translations-only reading).
  static const showArabicToggle = Key('reader-show-arabic-toggle');
  // The Arabic matn line inside a Detailed tile (shared by every verse); used to
  // observe the "Show Arabic" toggle hiding it.
  static const ayahArabicText = Key('ayah-arabic-text');
  static Key ayahBookmarkButton(int ayahId) => Key('ayah-bookmark-$ayahId');

  // Audio recitation (only rendered while FeatureFlags.audioRecitation is on).
  static Key ayahPlayButton(int ayahId) => Key('ayah-play-$ayahId');
  // Per-verse translation-audio toggle (Al-Fatihah POC only — mirrors
  // translationAudioPocToggle but lives on the verse row itself).
  static Key ayahTranslationAudioToggle(int ayahId) =>
      Key('ayah-translation-audio-$ayahId');
  static const peekPlayButton = Key('reader-peek-play-button');
  // Persistent single-row player bar + its inline transport controls.
  static const playerBar = Key('reader-player-bar');
  static const playerBarPlay = Key('reader-player-bar-play');
  static const playerBarPrev = Key('reader-player-bar-prev');
  static const playerBarNext = Key('reader-player-bar-next');
  static const playerSpeed = Key('reader-player-speed');
  static const playerRepeat = Key('reader-player-repeat');

  // Prayer times
  static const nextPrayerPill = Key('next-prayer-pill');
  static const prayerTimesSheet = Key('prayer-times-sheet');
  static const hijriDateLine = Key('hijri-date-line');

  // Reminders (Sunnah reminders + Salat notifications, one settings screen)
  static const remindersButton = Key('reminders-button');
  static const remindersPage = Key('reminders-page');
  static const sunnahRemindersToggle = Key('sunnah-reminders-toggle');
  static const sunnahRemindersInfoButton = Key('sunnah-reminders-info-button');
  static const prayerNotificationsToggle = Key('prayer-notifications-toggle');
  static const prayerNotificationsInfoButton =
      Key('prayer-notifications-info-button');
  static const prayerNotificationsTestButton =
      Key('prayer-notifications-test-button');

  // About / credits
  static const aboutPage = Key('about-page');
  static const aboutCredits =
      Key('about-credits-link'); // About → Credits screen
  static const creditsPage = Key('credits-page');
  static const aboutLicenses = Key('about-licenses');

  // Bottom navigation shell (Read / Prayer / Library / More)
  static const bottomNavChrome = Key('bottom-nav-chrome');
  static const bottomNavRead = Key('bottom-nav-read');
  static const bottomNavPrayer = Key('bottom-nav-prayer');
  static const bottomNavLibrary = Key('bottom-nav-library');
  static const bottomNavMore = Key('bottom-nav-more');
  static const prayerPage = Key('prayer-page');
  static const libraryPage = Key('library-page');
  static const libraryTranslationsRow = Key('library-translations-row');
  static const libraryTafsirRow = Key('library-tafsir-row');
  static const libraryBookmarksRow = Key('library-bookmarks-row');
  static const morePage = Key('more-page');
  static const moreReadingThemeRow = Key('more-reading-theme-row');
  static const moreSettingsRow = Key('more-settings-row');
  static const moreAboutRow = Key('more-about-row');
}
