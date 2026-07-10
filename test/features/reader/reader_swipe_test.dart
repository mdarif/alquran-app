import 'dart:async';

import 'package:al_quran/core/audio/ayah_recitation_player.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/reader/domain/entities/arabic_script.dart';
import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/last_read.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:al_quran/features/reader/domain/entities/surah_heading.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/last_read_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/reader_settings_repository.dart';
import 'package:al_quran/features/reader/presentation/cubit/ayah_audio_cubit.dart';
import 'package:al_quran/features/reader/presentation/cubit/reader_cubit.dart';
import 'package:al_quran/features/reader/presentation/pages/reader_page.dart';
import 'package:al_quran/features/reader/presentation/widgets/mushaf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// Fake repo: one ayah per surah, headings named "Chapter N".
class _FakeAyahRepository implements AyahRepository {
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async {
    final surahId = target.value; // surah dimension: value == surah id
    return [
      Ayah(
        id: surahId * 100 + 1,
        surahId: surahId,
        ayahNumber: 1,
        textArabic: 'نص',
        isSajda: false,
      ),
    ];
  }

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => {
        for (var i = 1; i <= 114; i++)
          i: SurahHeading(number: i, nameEnglish: 'Chapter $i', totalAyahs: 3),
      };

  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [];
}

class _FakeLastReadRepository implements LastReadRepository {
  LastRead? saved;
  @override
  Future<void> save(LastRead value) async => saved = value;
  @override
  Future<LastRead?> load() async => saved;
}

/// Repo with two translations (Urdu + English) for the Detailed-view filter test.
class _FakeAyahRepoWithTranslations implements AyahRepository {
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async => const [
        Ayah(
          id: 201,
          surahId: 2,
          ayahNumber: 1,
          textArabic: 'نص',
          isSajda: false,
          translations: {1: 'اردو متن', 3: 'english body'},
        ),
      ];

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => {
        2: const SurahHeading(
          number: 2,
          nameEnglish: 'Al-Baqarah',
          totalAyahs: 3,
        ),
      };

  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [
        TranslationResource(
          id: 1,
          languageCode: 'ur',
          name: 'Urdu',
          author: 'Junagarhi',
        ),
        TranslationResource(
          id: 3,
          languageCode: 'en',
          name: 'English',
          author: 'Khan',
        ),
      ];
}

/// Repo with English + Hindi but NO Urdu — exercises the last-resort
/// "no Urdu edition → first available" default.
class _FakeAyahRepoEnOnly implements AyahRepository {
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async => const [
        Ayah(
          id: 201,
          surahId: 2,
          ayahNumber: 1,
          textArabic: 'نص',
          isSajda: false,
          translations: {3: 'english body', 2: 'हिंदी अनुवाद'},
        ),
      ];

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => {
        2: const SurahHeading(
          number: 2,
          nameEnglish: 'Al-Baqarah',
          totalAyahs: 3,
        ),
      };

  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [
        TranslationResource(
          id: 3,
          languageCode: 'en',
          name: 'English',
          author: 'Khan',
        ),
        TranslationResource(
          id: 2,
          languageCode: 'hi',
          name: 'Hindi',
          author: 'al-Umari',
        ),
      ];
}

/// Repo with many verses per surah so the Reading list actually SCROLLS — the
/// default one-ayah repo can't reproduce a scroll-vs-page-turn gesture conflict.
class _ScrollableAyahRepository implements AyahRepository {
  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async {
    final surahId = target.value;
    return [
      for (var n = 1; n <= 40; n++)
        Ayah(
          id: surahId * 100 + n,
          surahId: surahId,
          ayahNumber: n,
          textArabic: 'نص الآية رقم $n في هذه السورة الطويلة',
          page: surahId * 100 + (n - 1) ~/ 8,
          isSajda: false,
        ),
    ];
  }

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => {
        for (var i = 1; i <= 114; i++)
          i: SurahHeading(number: i, nameEnglish: 'Chapter $i', totalAyahs: 40),
      };

  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [];
}

class _FakeSettings implements ReaderSettingsRepository {
  _FakeSettings({
    this.fontSize = 28,
    this.detailed = false,
    this.selectedTranslations,
  });
  @override
  double fontSize;
  @override
  bool detailed;
  @override
  List<String>? selectedTranslations;
  @override
  ArabicScript script = ArabicScript.uthmani;
  @override
  Future<void> setScript(ArabicScript value) async => script = value;
  @override
  Future<void> setFontSize(double value) async => fontSize = value;
  @override
  Future<void> setDetailed(bool value) async => detailed = value;
  @override
  Future<void> setSelectedTranslations(List<String> codes) async =>
      selectedTranslations = codes;
  @override
  bool readingTranslationVisible = true;
  @override
  Future<void> setReadingTranslationVisible(bool value) async =>
      readingTranslationVisible = value;
}

Future<void> _pumpReader(WidgetTester tester, ReaderTarget target) async {
  await tester.pumpWidget(MaterialApp(home: ReaderPage(target: target)));
  await tester.pumpAndSettle();
}

/// No-op player so ReaderPage's audio branch (behind FeatureFlags.audioRecitation)
/// can resolve an AyahAudioCubit from GetIt — these tests don't exercise audio.
class _SilentPlayer implements AyahRecitationPlayer {
  @override
  Stream<RecitationPlayback> get playbackStream =>
      const Stream<RecitationPlayback>.empty();
  @override
  Future<void> play(int ayahId) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> prefetch(int ayahId) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  setUp(() {
    GetIt.I
      ..registerFactory<ReaderCubit>(
        () => ReaderCubit(_FakeAyahRepository(), _FakeLastReadRepository()),
      )
      ..registerLazySingleton<ReaderSettingsRepository>(_FakeSettings.new)
      ..registerFactory<AyahAudioCubit>(() => AyahAudioCubit(_SilentPlayer()));
  });
  tearDown(GetIt.I.reset);

  group('Reader swipe navigation', () {
    testWidgets('swipe left advances to the next surah', (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      expect(find.text('Chapter 2'), findsOneWidget);

      await tester.fling(find.byType(MushafView), const Offset(-400, 0), 1200);
      await tester.pumpAndSettle();

      expect(find.text('Chapter 3'), findsWidgets); // header + app bar
      expect(find.text('Chapter 2'), findsNothing);
    });

    testWidgets('swipe right goes to the previous surah', (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(3, 'Ali Imran'));
      expect(find.text('Chapter 3'), findsOneWidget);

      await tester.fling(find.byType(MushafView), const Offset(400, 0), 1200);
      await tester.pumpAndSettle();

      expect(find.text('Chapter 2'), findsWidgets);
      expect(find.text('Chapter 3'), findsNothing);
    });

    testWidgets('swipe right on the first surah is a no-op (no wrap)',
        (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(1, 'Al-Fatihah'));
      expect(find.text('Chapter 1'), findsOneWidget);

      await tester.fling(find.byType(MushafView), const Offset(400, 0), 1200);
      await tester.pumpAndSettle();

      expect(find.text('Chapter 1'), findsOneWidget); // unchanged
    });

    testWidgets('a short drag below the distance threshold does not navigate',
        (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));

      // Small horizontal nudge (< threshold) should not change section.
      await tester.drag(find.byType(MushafView), const Offset(-30, 0));
      await tester.pumpAndSettle();

      expect(find.text('Chapter 2'), findsOneWidget);
    });

    testWidgets('a mostly-vertical drag does not navigate', (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));

      // Big vertical, small horizontal — a scroll, not a swipe.
      await tester.drag(find.byType(MushafView), const Offset(-40, 400));
      await tester.pumpAndSettle();

      expect(find.text('Chapter 2'), findsOneWidget);
    });

    testWidgets('a drag past the half-way point advances (no fling needed)',
        (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      expect(find.text('Chapter 2'), findsOneWidget);

      // Past half the page width, with no fling, the PageView snaps forward.
      await tester.drag(find.byType(MushafView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Chapter 3'), findsWidgets);
      expect(find.text('Chapter 2'), findsNothing);
    });

    testWidgets('swipe left on the last surah is a no-op (no wrap)',
        (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(114, 'An-Nas'));
      expect(find.text('Chapter 114'), findsOneWidget);

      await tester.fling(find.byType(MushafView), const Offset(-400, 0), 1200);
      await tester.pumpAndSettle();

      expect(find.text('Chapter 114'), findsOneWidget); // unchanged
    });
  });

  // A real thumb drag while reading is never perfectly vertical — it arcs and
  // drifts sideways. Such a drag must SCROLL, not turn the page. The section swipe
  // is a DIRECTIONAL recognizer (_HorizontalSwipeRecognizer): it only wins the
  // gesture arena when the drag is decisively horizontal, so any vertical/diagonal
  // scroll falls through to the reading list — however far it drifts sideways.
  // A straight `tester.drag` can't exercise this (its synthetic first move resolves
  // to one axis); these use multi-phase TestGestures pumped frame-by-frame.
  group('Gesture disambiguation — curved/diagonal drag scrolls, not page-turn',
      () {
    Future<void> pumpScrollableReader(WidgetTester tester) async {
      GetIt.I
        ..unregister<ReaderCubit>()
        ..registerFactory<ReaderCubit>(
          () => ReaderCubit(
            _ScrollableAyahRepository(),
            _FakeLastReadRepository(),
          ),
        );
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      expect(find.byType(SurahHeaderCard), findsOneWidget);
      expect(find.text('Chapter 2'), findsWidgets);
    }

    testWidgets('sideways drift then vertical → scrolls, stays on the surah',
        (tester) async {
      await pumpScrollableReader(tester);

      // A pronounced sideways drift that then arcs down into a long vertical scroll.
      final g = await tester.startGesture(
        tester.getCenter(find.byType(MushafView)),
      );
      await g.moveBy(const Offset(-40, 12)); // sideways lead
      await tester.pump();
      await g.moveBy(const Offset(-10, -80)); // arcs downward
      await tester.pump();
      await g.moveBy(const Offset(0, -600)); // long vertical scroll
      await g.up();
      await tester.pumpAndSettle();

      expect(
        find.byType(SurahHeaderCard),
        findsNothing,
        reason:
            'the vertical travel must scroll the surah (header off the top)',
      );
      expect(
        find.text('Chapter 3'),
        findsNothing,
        reason: 'a mostly-vertical arc must not turn the page',
      );
    });

    testWidgets('a diagonal drag (big sideways component) still scrolls',
        (tester) async {
      await pumpScrollableReader(tester);
      // Vertical-DOMINANT but with a large, sustained sideways component — exactly
      // the thumb arc that defeated an absolute slop. |dy| stays > |dx| throughout,
      // so the swipe recognizer must never claim it; the list scrolls.
      final g = await tester.startGesture(
        tester.getCenter(find.byType(MushafView)),
      );
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(-30, -80)); // dx grows, but dy grows faster
        await tester.pump();
      }
      await g.up();
      await tester.pumpAndSettle();

      expect(
        find.byType(SurahHeaderCard),
        findsNothing,
        reason:
            'a diagonal (vertical-dominant) drag must scroll, not page-turn',
      );
      expect(find.text('Chapter 3'), findsNothing);
    });

    testWidgets('a deliberate horizontal swipe still turns the page',
        (tester) async {
      await pumpScrollableReader(tester);
      // Clearly-horizontal fling — must still navigate (the recognizer must not
      // over-reject a genuine swipe).
      await tester.fling(find.byType(MushafView), const Offset(-500, 0), 1400);
      await tester.pumpAndSettle();
      expect(find.text('Chapter 3'), findsWidgets);
    });
  });

  group('Reader default viewport', () {
    testWidgets('opens in Reading (Mushaf) view by default', (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      expect(find.byType(MushafView), findsOneWidget);
    });

    testWidgets('always opens in Reading view, even if detailed was last used',
        (tester) async {
      // The viewport is no longer restored from settings — every fresh open
      // (e.g. tapping a surah from the index) lands in Reading view.
      GetIt.I.unregister<ReaderSettingsRepository>();
      GetIt.I.registerLazySingleton<ReaderSettingsRepository>(
        () => _FakeSettings(detailed: true),
      );

      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      expect(find.byType(MushafView), findsOneWidget);
    });
  });

  group('Translation languages (Display sheet)', () {
    // Register the translations repo + a settings fake with both editions
    // selected (the default is a single language), then open Detailed view.
    Future<void> openDetailed(
      WidgetTester tester, {
      List<String> selected = const ['ur', 'en'],
    }) async {
      // A phone-height surface so the (now taller, with About at the bottom)
      // Settings sheet doesn't fill the screen — keeps the scrim tappable to
      // close it, as on a real device.
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      GetIt.I
        ..unregister<ReaderCubit>()
        ..registerFactory<ReaderCubit>(
          () => ReaderCubit(
            _FakeAyahRepoWithTranslations(),
            _FakeLastReadRepository(),
          ),
        )
        ..unregister<ReaderSettingsRepository>()
        ..registerLazySingleton<ReaderSettingsRepository>(
          () => _FakeSettings(selectedTranslations: selected),
        );
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      await tester.tap(find.byTooltip('Detailed view'));
      await tester.pumpAndSettle();
    }

    // Open the Display sheet, tap each given language row, then close the sheet.
    Future<void> toggleLanguages(
      WidgetTester tester,
      List<String> codes,
    ) async {
      await tester.tap(find.byKey(WidgetKeys.settingsButton)); // open Settings
      await tester.pumpAndSettle();
      for (final code in codes) {
        await tester.tap(find.byKey(WidgetKeys.langOption(code)));
        await tester.pumpAndSettle();
      }
      await tester.tapAt(const Offset(400, 20)); // tap the scrim to close
      await tester.pumpAndSettle();
    }

    testWidgets('unticking a language hides that translation', (tester) async {
      await openDetailed(tester);
      expect(find.text('اردو متن'), findsOneWidget);
      expect(find.text('english body'), findsOneWidget);

      await toggleLanguages(tester, ['en']); // turn English off

      expect(find.text('english body'), findsNothing);
      expect(find.text('اردو متن'), findsOneWidget); // Urdu stays
    });

    testWidgets('the last remaining language cannot be turned off',
        (tester) async {
      await openDetailed(tester);

      // Turn English off, then try Urdu too — the last one must stay on.
      await toggleLanguages(tester, ['en', 'ur']);

      expect(find.text('اردو متن'), findsOneWidget);
    });

    testWidgets('the selection is shared with the Reading peek card',
        (tester) async {
      await openDetailed(tester);

      await toggleLanguages(tester, ['en']); // Urdu only
      expect(find.text('english body'), findsNothing);

      // Back to Reading, tap the verse — the peek shows Urdu only (shared).
      await tester.tap(find.byTooltip('Reading view'));
      await tester.pumpAndSettle();
      final flow = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onTapUp != null && w.onTap == null,
      );
      await tester.tap(flow.first);
      await tester.pumpAndSettle();

      expect(find.text('اردو متن'), findsOneWidget);
      expect(find.text('english body'), findsNothing);
    });
  });

  group('Default translation selection', () {
    // No saved selection (the default _FakeSettings) → the reader resolves a
    // single default: Urdu (the flagship), regardless of device language, per
    // owner decision. Only falls through to the first edition when Urdu is absent.
    Future<void> openDetailed(WidgetTester tester, AyahRepository repo) async {
      GetIt.I
        ..unregister<ReaderCubit>()
        ..registerFactory<ReaderCubit>(
          () => ReaderCubit(repo, _FakeLastReadRepository()),
        );
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      await tester.tap(find.byTooltip('Detailed view'));
      await tester.pumpAndSettle();
    }

    testWidgets('defaults to Urdu even when the device-language edition exists',
        (tester) async {
      // Test host locale is en and English is available, but the fresh-install
      // default is Urdu-only regardless of device language.
      await openDetailed(tester, _FakeAyahRepoWithTranslations());
      expect(find.text('اردو متن'), findsOneWidget);
      expect(find.text('english body'), findsNothing);
    });

    testWidgets('falls back to the first edition when Urdu has no edition',
        (tester) async {
      // No Urdu edition available → last-resort first available (English here).
      await openDetailed(tester, _FakeAyahRepoEnOnly());
      expect(find.text('english body'), findsOneWidget);
    });
  });

  group('Last Read viewport resume', () {
    testWidgets('resumes in Detailed when that was the saved viewport',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReaderPage(
            target: ReaderTarget.surah(2, 'Al-Baqarah'),
            focusAyahId: 201,
            initialDetailed: true, // came from Detailed view
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Detailed view → no Mushaf flow.
      expect(find.byType(MushafView), findsNothing);
    });

    testWidgets('resumes in Reading when that was the saved viewport',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReaderPage(
            target: ReaderTarget.surah(2, 'Al-Baqarah'),
            focusAyahId: 201,
            initialDetailed: false, // came from Reading view
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MushafView), findsOneWidget);
    });
  });

  // Regression for the v1.0.0 field bug: fling across many surahs, stop, tap
  // Detailed → endless spinner. Straggler warms from the fling evicted the
  // on-screen section from the LRU; the toggle's cache read missed; and the
  // silent re-warm never woke the spinner page.
  group('Viewport toggle after a fast fling (regression)', () {
    testWidgets('Detailed shows verses even after a straggler-warm storm',
        (tester) async {
      late ReaderCubit cubit;
      GetIt.I
        ..unregister<ReaderCubit>()
        ..registerFactory<ReaderCubit>(() {
          cubit = ReaderCubit(_FakeAyahRepository(), _FakeLastReadRepository());
          return cubit;
        });

      await _pumpReader(tester, const ReaderTarget.surah(9, 'At-Tawbah'));
      expect(find.text('Chapter 9'), findsWidgets);

      // The straggler warms of a fast multi-page fling: far more sections
      // than the cache cap, all landing after At-Tawbah's own store.
      for (var s = 20; s < 40; s++) {
        cubit.warm(ReaderTarget.surah(s, 'Surah $s'));
      }
      await tester.pumpAndSettle();

      // Reading ⇄ Detailed — this used to stick on a spinner forever.
      await tester.tap(find.byKey(WidgetKeys.viewportToggle));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('نص'), findsWidgets); // the verses are on screen
      expect(find.byType(MushafView), findsNothing); // and we ARE in Detailed
    });

    testWidgets('toggling Detailed after a swipe stays on the swiped surah',
        (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      await tester.fling(find.byType(MushafView), const Offset(-400, 0), 1200);
      await tester.pumpAndSettle();
      expect(find.text('Chapter 3'), findsWidgets);

      await tester.tap(find.byKey(WidgetKeys.viewportToggle));
      await tester.pumpAndSettle();

      // The Detailed view must show surah 3 — not silently jump back to the
      // surah the reader was opened on (the PageView used to remount on the
      // toggle because the tree shape changed, re-attaching at initialPage).
      expect(find.byType(MushafView), findsNothing); // in Detailed
      expect(find.text('Chapter 3'), findsWidgets); // app bar + section header
      expect(find.text('Chapter 2'), findsNothing); // no jump-back
    });
  });

  // Power-user gauntlet: rapid gesture/toggle combinations that stress the
  // PageView position, the section cache, and their interplay.
  group('Power-user stress (rapid toggles and flings)', () {
    testWidgets('rapid triple-toggle keeps the swiped surah', (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      await tester.fling(find.byType(MushafView), const Offset(-400, 0), 1200);
      await tester.pumpAndSettle();
      expect(find.text('Chapter 3'), findsWidgets);

      // Mash the viewport toggle: Detailed → Reading → Detailed.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(WidgetKeys.viewportToggle));
        await tester.pumpAndSettle();
      }

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Chapter 3'), findsWidgets); // still the swiped surah
      expect(find.text('Chapter 2'), findsNothing);
      expect(find.byType(MushafView), findsNothing); // odd count → Detailed
    });

    testWidgets('toggling mid-fling settles with title matching content',
        (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      // Start a fling and toggle while the page animation is still in flight.
      await tester.fling(find.byType(MushafView), const Offset(-400, 0), 1200);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.byKey(WidgetKeys.viewportToggle));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(MushafView), findsNothing); // Detailed now
      // Wherever the fling settled, the app bar and the visible section header
      // must agree — no title/content desync.
      final title = tester
          .widget<Text>(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.textContaining('Chapter'),
            ),
          )
          .data!;
      expect(
        find.descendant(of: find.byType(PageView), matching: find.text(title)),
        findsWidgets,
      );
    });

    testWidgets('swiping in Detailed then returning to Reading keeps place',
        (tester) async {
      await _pumpReader(tester, const ReaderTarget.surah(2, 'Al-Baqarah'));
      await tester.tap(find.byKey(WidgetKeys.viewportToggle));
      await tester.pumpAndSettle();
      expect(find.byType(MushafView), findsNothing);

      // Swipe forward INSIDE Detailed (the PageView spans both viewports).
      // Regression: SelectionArea used to claim horizontal drags on Android
      // (eager victory), so Detailed could not be swiped at all.
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
      await tester.pumpAndSettle();
      expect(find.text('Chapter 3'), findsWidgets);

      // Back to Reading — must stay on the swiped surah.
      await tester.tap(find.byKey(WidgetKeys.viewportToggle));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(MushafView), findsOneWidget);
      expect(find.text('Chapter 3'), findsWidgets);
      expect(find.text('Chapter 2'), findsNothing);
    });
  });
}
