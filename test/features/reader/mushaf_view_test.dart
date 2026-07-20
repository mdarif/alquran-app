import 'package:al_quran/core/audio/ayah_recitation_player.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/core/theme/mushaf_palette.dart';
import 'package:al_quran/features/reader/presentation/cubit/ayah_audio_cubit.dart';
import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/surah_heading.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/presentation/widgets/mushaf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<Ayah> _ayahs(int surahId, int count) => [
      for (var n = 1; n <= count; n++)
        Ayah(
          id: surahId * 1000 + n,
          surahId: surahId,
          ayahNumber: n,
          textArabic: 'نص$n',
          // 8 verses per Mushaf page, so the Reading view chunks into several
          // lazy paragraphs (mirrors the real DB, where every ayah has a page).
          page: surahId * 100 + (n - 1) ~/ 8,
          isSajda: false,
        ),
    ];

// Same verse ids as [_ayahs] but much longer Arabic text — simulates reloading
// a section in a different script (e.g. IndoPak), where the verses are identical
// but the glyph runs are longer.
List<Ayah> _ayahsLongText(int surahId, int count) => [
      for (var n = 1; n <= count; n++)
        Ayah(
          id: surahId * 1000 + n,
          surahId: surahId,
          ayahNumber: n,
          textArabic: 'نص طويل جدا للآية رقم $n مع كلمات إضافية كثيرة هنا',
          // Same verse→page mapping as [_ayahs] so a script reload keeps each
          // verse on its page (the re-anchor test relies on that).
          page: surahId * 100 + (n - 1) ~/ 8,
          isSajda: false,
        ),
    ];

List<Ayah> _ayahsWithTranslations(int surahId, int count) => [
      for (var n = 1; n <= count; n++)
        Ayah(
          id: surahId * 1000 + n,
          surahId: surahId,
          ayahNumber: n,
          textArabic: 'نص$n',
          isSajda: false,
          translations: const {
            1: 'اردو ترجمہ',
            2: 'हिंदी अनुवाद',
          },
        ),
    ];

Map<int, SurahHeading> _headings(
  int surahId,
  String name,
  int count, {
  String? arabic,
  String? place,
}) =>
    {
      surahId: SurahHeading(
        number: surahId,
        nameEnglish: name,
        totalAyahs: count,
        nameArabic: arabic,
        revelationPlace: place,
      ),
    };

const _kResources = <TranslationResource>[
  TranslationResource(
    id: 1,
    languageCode: 'ur',
    name: 'Urdu',
    author: 'Junagarhi',
  ),
  TranslationResource(
    id: 2,
    languageCode: 'hi',
    name: 'Hindi',
    author: 'al-Umari',
  ),
];

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

MushafView _view({
  List<Ayah>? ayahs,
  Map<int, SurahHeading>? headings,
  List<TranslationResource> resources = const [],
  double fontSize = 28,
  int surahId = 2,
  int ayahCount = 3,
}) =>
    MushafView(
      ayahs: ayahs ?? _ayahs(surahId, ayahCount),
      headings: headings ?? _headings(surahId, 'Al-Baqarah', 286),
      arabicFontSize: fontSize,
      resources: resources,
    );

// Scroll the reader by [totalDy] logical px in small steps, like a real finger,
// then let the fling/settle finish. A single huge tester.drag offset can outrun
// the reader's bouncing/edge-clamping physics boundary checks within one frame
// (the boundary is re-evaluated incrementally), so it fails to settle into a
// ScrollEndNotification / lands somewhere a real touch drag never would — these
// small steps mirror on-device input. Negative dy scrolls forward (down the
// list); positive dy scrolls back toward the start.
Future<void> _scrollBy(
  WidgetTester tester,
  double totalDy, {
  int steps = 12,
  Finder? finder,
}) async {
  final target = finder ?? find.byType(MushafView);
  final gesture = await tester.startGesture(tester.getCenter(target));
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, totalDy / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pump(const Duration(seconds: 1));
}

// Tap the reading text area (the GestureDetector on Text.rich).
Future<void> _tapText(WidgetTester tester) async {
  final detector = find.byWidgetPredicate(
    (w) => w is GestureDetector && w.onTapUp != null && w.onTap == null,
  );
  await tester.tap(detector.first);
  await tester.pumpAndSettle();
}

// Tap the handle bar of the open peek card.
Future<void> _tapHandle(WidgetTester tester) async {
  final handle = find.byWidgetPredicate(
    (w) =>
        w is GestureDetector && w.onTap != null && w.onVerticalDragEnd != null,
  );
  await tester.tap(handle.first);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MushafView — chapter headers and Arabic flow', () {
    testWidgets('renders chapter header with the English name', (tester) async {
      await tester.pumpWidget(_wrap(_view()));
      expect(find.text('Al-Baqarah'), findsOneWidget);
    });

    testWidgets('shows Arabic surah name and revelation/verse meta line',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          _view(
            ayahs: _ayahs(1, 7),
            headings: _headings(
              1,
              'Al-Fatihah',
              7,
              arabic: 'الفاتحة',
              place: 'makkah',
            ),
          ),
        ),
      );
      expect(find.text('الفاتحة'), findsOneWidget);
      expect(find.text('Meccan · 7 Verses'), findsOneWidget);
    });

    testWidgets('omits the meta line when surah metadata is unavailable',
        (tester) async {
      await tester.pumpWidget(
        _wrap(_view(headings: const {}, surahId: 2, ayahCount: 3)),
      );
      expect(find.textContaining('verses'), findsNothing);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('the Arabic flow is centered and right-to-left',
        (tester) async {
      await tester.pumpWidget(_wrap(_view()));
      final flow = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere((t) => t.textSpan != null);
      expect(flow.textAlign, TextAlign.center);
      expect(flow.textDirection, TextDirection.rtl);
    });

    testWidgets(
        'marks each ayah with the U+06DD medallion + overlaid Western digit',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          _view(
            ayahs: _ayahs(112, 4),
            headings: _headings(112, 'Al-Ikhlas', 4),
          ),
        ),
      );
      await tester.pumpAndSettle(); // let the medallion overlay measure + place

      // The continuous paragraph carries the empty ayah medallion (U+06DD); the
      // verse number is drawn as a separate overlaid Text on top of it.
      final paragraph = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.textSpan != null)
          .map((t) => t.textSpan!.toPlainText())
          .join();
      expect(paragraph, contains('۝'));

      // Each verse number is a Western digit 1-4 (consistent with the TOC and
      // Detailed badges) — overlaid, NOT inline in the Arabic paragraph, and NOT
      // the canonical Arabic-Indic ٢ rosette (which reads as "4" to Urdu readers).
      final overlays = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      for (final n in ['1', '2', '3', '4']) {
        expect(overlays, contains(n));
      }
      expect(paragraph.contains('١'), isFalse);
      expect(paragraph.contains('٢'), isFalse);
    });

    testWidgets('shows the Bismillah for an ordinary surah starting at ayah 1',
        (tester) async {
      await tester.pumpWidget(_wrap(_view()));
      expect(find.byType(Bismillah), findsOneWidget);
    });

    testWidgets('hides the Bismillah for Al-Fatihah (it is ayah 1)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          _view(ayahs: _ayahs(1, 7), headings: _headings(1, 'Al-Fatihah', 7)),
        ),
      );
      expect(find.byType(Bismillah), findsNothing);
    });

    testWidgets('hides the Bismillah for At-Tawbah (it has none)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          _view(ayahs: _ayahs(9, 5), headings: _headings(9, 'At-Tawbah', 129)),
        ),
      );
      expect(find.byType(Bismillah), findsNothing);
    });

    testWidgets('the Bismillah ornament uses the surface gold', (tester) async {
      final palette = MushafPalette.of(DayPhase.duha);
      await tester.pumpWidget(
        MaterialApp(theme: palette.toTheme(), home: Scaffold(body: _view())),
      );
      // The rub-el-hizb stars ۞ are tinted with the palette's gold (via the
      // MushafColors theme extension), not a hard-coded colour.
      final stars = tester.widgetList<Text>(find.text('۞'));
      expect(stars, isNotEmpty);
      expect(stars.every((s) => s.style?.color == palette.gold), isTrue);
    });

    testWidgets('shows a current-page readout when ayahs carry page numbers',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          _view(
            ayahs: const [
              Ayah(
                id: 1,
                surahId: 2,
                ayahNumber: 1,
                textArabic: 'نص',
                isSajda: false,
                page: 5,
              ),
            ],
          ),
        ),
      );
      expect(find.text('Page 5'), findsOneWidget);
    });

    testWidgets('renders a header per surah when a section spans surahs',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          _view(
            ayahs: [..._ayahs(1, 2), ..._ayahs(2, 2)],
            headings: {
              ..._headings(1, 'Al-Fatihah', 7),
              ..._headings(2, 'Al-Baqarah', 286),
            },
          ),
        ),
      );
      expect(find.text('Al-Fatihah'), findsOneWidget);
      expect(find.text('Al-Baqarah'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------

  group('MushafView — tap-to-peek translation card', () {
    // The peek card is the only Material with elevation 12 — a robust "is the
    // card visible" probe independent of its text content.
    bool cardVisible(WidgetTester tester) => tester
        .widgetList<Material>(find.byType(Material))
        .any((m) => m.elevation == 12);

    // Build the Reading view with a fixed selection (Urdu) so content
    // assertions are deterministic regardless of the test host's locale.
    Widget reader(
      List<Ayah> ayahs, {
      List<TranslationResource> resources = _kResources,
      Set<String> selected = const {'ur'},
      ValueChanged<String>? onToggleLanguage,
    }) =>
        _wrap(
          MushafView(
            ayahs: ayahs,
            headings: _headings(1, 'Al-Fatihah', 7),
            arabicFontSize: 28,
            resources: resources,
            selectedLanguages: selected,
            onToggleLanguage: onToggleLanguage,
            showPeek: true, // this group exercises the (opt-in) peek card
          ),
        );

    testWidgets('card is absent before any verse is tapped', (tester) async {
      await tester.pumpWidget(reader(_ayahs(1, 7)));
      await tester.pump();
      expect(cardVisible(tester), isFalse);
    });

    testWidgets('card is absent before any tap even for a short surah',
        (tester) async {
      // Al-Fatihah (7 ayahs) fits on screen without scrolling — the case that
      // exposed the old Positioned(bottom:0) / Stack-sizing bug.
      await tester.pumpWidget(reader(_ayahs(1, 7)));
      await tester.pump();
      expect(cardVisible(tester), isFalse);
    });

    testWidgets('tapping a verse opens the translation card', (tester) async {
      await tester.pumpWidget(reader(_ayahsWithTranslations(1, 3)));
      await tester.pump();
      await _tapText(tester);

      expect(cardVisible(tester), isTrue);
      // Translation-only now (no verse ref / ‹/› steppers): the Urdu text shows.
      expect(find.text('اردو ترجمہ'), findsOneWidget);
    });

    testWidgets('card does NOT repeat the Arabic of the tapped verse',
        (tester) async {
      final singleAyah = [
        const Ayah(
          id: 1001,
          surahId: 1,
          ayahNumber: 1,
          textArabic: 'بِسْمِ اللَّهِ',
          isSajda: false,
          translations: {1: 'ترجمہ', 2: 'अनुवाद'},
        ),
      ];
      await tester.pumpWidget(reader(singleAyah));
      await tester.pump();
      await _tapText(tester);

      // The flow renders Arabic via Text.rich (which find.text ignores); the card
      // no longer adds a plain Arabic Text, so this exact string is nowhere.
      expect(find.text('بِسْمِ اللَّهِ'), findsNothing);
    });

    testWidgets('inline language chips report toggles to the parent',
        (tester) async {
      final toggled = <String>[];
      await tester.pumpWidget(
        reader(_ayahsWithTranslations(1, 1), onToggleLanguage: toggled.add),
      );
      await tester.pump();
      await _tapText(tester);

      // Both available editions appear as inline chips in the peek card.
      expect(find.byKey(WidgetKeys.peekLangOption('ur')), findsOneWidget);
      expect(find.byKey(WidgetKeys.peekLangOption('hi')), findsOneWidget);

      // Tapping one reports it up (the reader persists the shared selection).
      await tester.tap(find.byKey(WidgetKeys.peekLangOption('hi')));
      await tester.pump();
      expect(toggled, ['hi']);
    });

    testWidgets('no inline chips when the toggle is not wired', (tester) async {
      await tester.pumpWidget(reader(_ayahsWithTranslations(1, 1)));
      await tester.pump();
      await _tapText(tester);
      expect(find.byKey(WidgetKeys.peekLangOption('ur')), findsNothing);
    });

    testWidgets('shows only the selected translation(s)', (tester) async {
      await tester.pumpWidget(reader(_ayahsWithTranslations(1, 1)));
      await tester.pump();
      await _tapText(tester);

      // Urdu selected → its text + author show; Hindi's do not.
      expect(find.text('اردو ترجمہ'), findsOneWidget);
      expect(find.text('हिंदी अनुवाद'), findsNothing);
      expect(find.text('Junagarhi'), findsOneWidget);
      expect(find.text('al-Umari'), findsNothing);
    });

    testWidgets('shows multiple translations when multiple are selected',
        (tester) async {
      await tester.pumpWidget(
        reader(_ayahsWithTranslations(1, 1), selected: const {'ur', 'hi'}),
      );
      await tester.pump();
      await _tapText(tester);

      expect(find.text('اردو ترجمہ'), findsOneWidget);
      expect(find.text('हिंदी अनुवाद'), findsOneWidget);
    });

    testWidgets('tapping the handle dismisses the card', (tester) async {
      await tester.pumpWidget(reader(_ayahsWithTranslations(1, 1)));
      await tester.pump();

      await _tapText(tester);
      expect(cardVisible(tester), isTrue);

      await _tapHandle(tester);
      // _shownAyah cleared once the slide-out completes → card is gone entirely.
      expect(cardVisible(tester), isFalse);
    });

    testWidgets('tapping the same verse again closes the card', (tester) async {
      await tester.pumpWidget(reader(_ayahsWithTranslations(1, 1)));
      await tester.pump();

      await _tapText(tester);
      expect(cardVisible(tester), isTrue);

      await _tapText(tester); // same verse → _dismissPeek()
      expect(cardVisible(tester), isFalse);
    });

    testWidgets('no resources — card opens without chips/translation, no crash',
        (tester) async {
      await tester.pumpWidget(
        reader(_ayahsWithTranslations(1, 1), resources: const []),
      );
      await tester.pump();
      await _tapText(tester);

      expect(cardVisible(tester), isTrue);
      expect(find.text('No translation available'), findsOneWidget);
      expect(find.textContaining('Junagarhi'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------

  group('MushafView — render settles with audio active (no loop)', () {
    // Guards against a real render/animation/timer LOOP: at a real 60fps the
    // reader must stop scheduling frames after audio starts. (We assert at the
    // real ~16ms frame cadence on purpose — pumpAndSettle's coarse 100ms fake
    // time-steps mis-settle the scroll/peek animation and can false-time-out
    // even though nothing actually loops; that's why audio tests pump manually.)
    testWidgets('reader stops scheduling frames after tap then playing',
        (tester) async {
      var audio = const AyahAudioState();
      late StateSetter setOuter;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return MushafView(
                ayahs: _ayahsWithTranslations(1, 3),
                headings: _headings(1, 'Al-Fatihah', 7),
                arabicFontSize: 28,
                resources: _kResources,
                selectedLanguages: const {'ur'},
                onToggleLanguage: (_) {},
                showPeek: true,
                onVisibleAyah: (_) {},
                audioState: audio,
              );
            },
          ),
        ),
      );
      await tester.pump();
      await _tapText(tester); // open the peek on a verse

      // Now start playback → now-playing tint + the audio-follow scroll.
      setOuter(
        () => audio = const AyahAudioState(
          playingAyahId: 1002,
          status: RecitationStatus.playing,
        ),
      );

      // At a real frame cadence the reader must settle (stop scheduling frames)
      // well within ~3s. A perpetual scheduler (render loop) never would.
      var settled = false;
      for (var i = 0; i < 200; i++) {
        if (!tester.binding.hasScheduledFrame) {
          settled = true;
          break;
        }
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        settled,
        isTrue,
        reason:
            'reader kept scheduling frames with audio active — a render loop',
      );

      // Drain the one-shot highlight-flash timer so teardown is clean.
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('MushafView — reciter follow across advances', () {
    // The Reading view follows the reciter by scrolling the playing verse to the
    // top of its flowing page-paragraph (no splitting), measuring each verse's
    // position as the paragraph lays out. This drives continuous playback across a
    // page boundary and asserts the follow + per-verse measurement never throws.
    testWidgets('advancing the playing verse across a page never throws',
        (tester) async {
      var audio = const AyahAudioState();
      late StateSetter setOuter;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return MushafView(
                ayahs: _ayahs(1, 24), // 3 Mushaf pages (1–8, 9–16, 17–24)
                headings: _headings(1, 'Al-Fatihah', 24),
                arabicFontSize: 28,
                resources: const [],
                onVisibleAyah: (_) {},
                audioState: audio,
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Play a MID-page verse, then advance verse-by-verse across the page
      // boundary (5,6,7,8 on page 0, then 9 on page 1) — each advance re-splits.
      for (final n in [5, 6, 7, 8, 9]) {
        setOuter(
          () => audio = AyahAudioState(
            playingAyahId: 1000 + n,
            status: RecitationStatus.playing,
          ),
        );
        // Let the re-chunk build, the follow-scroll run, and re-measure settle.
        for (var i = 0; i < 40; i++) {
          if (!tester.binding.hasScheduledFrame) break;
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(
          tester.takeException(),
          isNull,
          reason: 'the per-verse re-split for verse $n threw',
        );
      }

      // Drain the one-shot highlight-flash timer so teardown is clean.
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets(
        'Last Read advances to the playing verse even when it fits on '
        'screen', (tester) async {
      // Regression: a short surah (everything visible) makes the follow skip the
      // scroll (no pointless jump) — but Last Read must STILL track the reciter,
      // so a resume lands on the verse you were hearing, not an earlier one.
      Ayah? reported;
      var audio = const AyahAudioState();
      late StateSetter setOuter;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return MushafView(
                ayahs: _ayahs(1, 5), // Al-Fatihah-ish; fits on screen
                headings: _headings(1, 'Al-Fatihah', 5),
                arabicFontSize: 28,
                resources: const [],
                onVisibleAyah: (a) => reported = a,
                audioState: audio,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final n in [1, 2, 3]) {
        setOuter(
          () => audio = AyahAudioState(
            playingAyahId: 1000 + n,
            status: RecitationStatus.playing,
          ),
        );
        await tester.pump(); // didUpdateWidget
        await tester.pump(); // post-frame follow + report
        await tester.pump(const Duration(milliseconds: 500)); // debounce
      }
      await tester.pump(const Duration(seconds: 2)); // drain flash timer

      expect(
        reported?.id,
        1003,
        reason: 'Last Read froze on an earlier verse while audio advanced',
      );
    });
  });

  group('MushafView — now-playing tint + peek follow', () {
    // Tinted verse texts → the exact background color, so a test can tell the
    // now-playing tint (gold) from the cue tint (green).
    Map<String, Color> tintByText(WidgetTester tester) {
      final paragraph = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere((t) => t.textSpan != null);
      final out = <String, Color>{};
      void walk(InlineSpan span) {
        if (span is TextSpan) {
          final bg = span.style?.backgroundColor;
          if (span.text != null && bg != null) out[span.text!] = bg;
          span.children?.forEach(walk);
        }
      }

      walk(paragraph.textSpan!);
      return out;
    }

    testWidgets('the now-playing (gold) tint persists while paused',
        (tester) async {
      var audio = const AyahAudioState();
      late StateSetter setOuter;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return MushafView(
                ayahs: _ayahsWithTranslations(1, 3),
                headings: _headings(1, 'Al-Fatihah', 7),
                arabicFontSize: 28,
                resources: _kResources,
                selectedLanguages: const {'ur'},
                onToggleLanguage: (_) {},
                audioState: audio,
              );
            },
          ),
        ),
      );
      await tester.pump();

      Future<void> setAudio(AyahAudioState s) async {
        setOuter(() => audio = s);
        await tester.pump();
        await tester.pump();
      }

      final cs = Theme.of(tester.element(find.byType(MushafView))).colorScheme;
      final gold = cs.tertiary.withValues(alpha: 0.18);

      await setAudio(
        const AyahAudioState(
          playingAyahId: 1001,
          status: RecitationStatus.playing,
        ),
      );
      expect(tintByText(tester)['نص1'], gold, reason: 'playing → gold');

      // Pause → the gold tint PERSISTS (a resume anchor, matching Detailed).
      await setAudio(
        const AyahAudioState(
          playingAyahId: 1001,
          status: RecitationStatus.paused,
        ),
      );
      expect(tintByText(tester)['نص1'], gold, reason: 'paused → still gold');

      // Stop → the tint clears (after the brief follow-flash drains).
      await setAudio(const AyahAudioState());
      await tester.pump(const Duration(seconds: 2)); // drain the follow-flash
      expect(tintByText(tester)['نص1'], isNull, reason: 'stopped → no tint');
    });

    testWidgets(
        'the green cue shows only while idle — suppressed once audio plays',
        (tester) async {
      var audio = const AyahAudioState();
      late StateSetter setOuter;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return MushafView(
                ayahs: _ayahsWithTranslations(1, 3),
                headings: _headings(1, 'Al-Fatihah', 7),
                arabicFontSize: 28,
                resources: _kResources,
                selectedLanguages: const {'ur'},
                onToggleLanguage: (_) {},
                audioState: audio,
              );
            },
          ),
        ),
      );
      await tester.pump();
      await _tapText(tester); // select a verse → green cue

      final cs = Theme.of(tester.element(find.byType(MushafView))).colorScheme;
      final green = cs.primary.withValues(alpha: 0.16);

      final idle = tintByText(tester);
      expect(
        idle.length,
        1,
        reason: 'only the tapped verse is tinted while idle',
      );
      final mText = idle.keys.first;
      expect(
        idle[mText],
        green,
        reason: 'the tapped verse is green while idle',
      );

      // Play a DIFFERENT verse → gold on it, and the stale green cue is
      // suppressed (so it never lingers on the tapped verse during prev/next).
      const allTexts = ['نص1', 'نص2', 'نص3'];
      final nText = allTexts.firstWhere((t) => t != mText);
      final nId = 1000 + (allTexts.indexOf(nText) + 1);
      setOuter(
        () => audio = AyahAudioState(
          playingAyahId: nId,
          status: RecitationStatus.playing,
        ),
      );
      await tester.pump();
      await tester.pump();

      final playing = tintByText(tester);
      expect(
        playing[nText],
        cs.tertiary.withValues(alpha: 0.18),
        reason: 'the playing verse is gold',
      );
      expect(
        playing[mText],
        isNull,
        reason: 'the green cue is suppressed while audio plays',
      );

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('with the peek on, it follows the playing verse',
        (tester) async {
      var audio = const AyahAudioState();
      late StateSetter setOuter;
      final ayahs = [
        for (var n = 1; n <= 3; n++)
          Ayah(
            id: 1000 + n,
            surahId: 1,
            ayahNumber: n,
            textArabic: 'نص$n',
            isSajda: false,
            translations: {1: 'ترجمہ $n'},
          ),
      ];
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return MushafView(
                ayahs: ayahs,
                headings: _headings(1, 'Al-Fatihah', 7),
                arabicFontSize: 28,
                resources: _kResources,
                selectedLanguages: const {'ur'},
                onToggleLanguage: (_) {},
                showPeek: true,
                audioState: audio,
              );
            },
          ),
        ),
      );
      await tester.pump();

      Future<void> setAudio(AyahAudioState s) async {
        setOuter(() => audio = s);
        await tester.pump();
        await tester.pump();
      }

      await setAudio(
        const AyahAudioState(
          playingAyahId: 1001,
          status: RecitationStatus.playing,
        ),
      );
      expect(find.text('ترجمہ 1'), findsOneWidget, reason: 'peek shows v1');

      await setAudio(
        const AyahAudioState(
          playingAyahId: 1002,
          status: RecitationStatus.playing,
        ),
      );
      expect(
        find.text('ترجمہ 2'),
        findsOneWidget,
        reason: 'peek followed to v2',
      );
      expect(find.text('ترجمہ 1'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('starting playback after a tap does not corrupt the tree',
        (tester) async {
      // Regression: MushafView.didUpdateWidget must not notify the parent
      // (onSelectVerse → its setState) when playback starts — that runs inside
      // the parent's rebuild and threw "_elements.contains(element)" on device.
      var audio = const AyahAudioState();
      int? queued;
      late StateSetter setOuter;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return MushafView(
                ayahs: _ayahsWithTranslations(1, 3),
                headings: _headings(1, 'Al-Fatihah', 7),
                arabicFontSize: 28,
                resources: _kResources,
                selectedLanguages: const {'ur'},
                onToggleLanguage: (_) {},
                // Mirrors the reader: a selection cues a parent rebuild.
                onSelectVerse: (a) => setState(() => queued = a?.id),
                audioState: audio,
              );
            },
          ),
        ),
      );
      await tester.pump();
      // Select a verse → onSelectVerse → parent setState.
      await _tapText(tester);
      expect(queued, isNotNull);

      // Now start playback on the cued verse (the exact on-device sequence).
      setOuter(
        () => audio = AyahAudioState(
          playingAyahId: queued,
          status: RecitationStatus.playing,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 2));
    });
  });

  // -------------------------------------------------------------------------

  group('MushafView — resume-point reporting (Last Read)', () {
    testWidgets('reports the topmost verse as soon as scrolling settles',
        (tester) async {
      // Guards the bug where the resume point only updated on a 1200ms idle
      // timer, so leaving right after scrolling saved a much earlier verse.
      final reported = <int>[];
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(2, 60),
            headings: _headings(2, 'Al-Baqarah', 286),
            arabicFontSize: 24,
            resources: const [],
            onVisibleAyah: (a) => reported.add(a.ayahNumber),
          ),
        ),
      );
      await tester.pump();
      reported.clear();

      // Drag to scroll: the report fires on the scroll-end notification (NOT a
      // long idle timeout) — _scrollBy settles the fling within ~1s.
      await _scrollBy(tester, -1500);

      expect(reported, isNotEmpty);
      // Tracked the scroll, not stuck at verse 1.
      expect(reported.last, greaterThan(1));
    });
  });

  group('MushafView — font-size re-anchor (Last Read)', () {
    testWidgets('changing font size does not drift the reading position back',
        (tester) async {
      final reported = <int>[];
      var fontSize = 24.0;
      late StateSetter setOuter;
      // One list instance reused across rebuilds — mirrors the app (the cubit
      // hands back the same ayahs on a font change, so only the size differs).
      final ayahs = _ayahs(2, 60);

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return MushafView(
                ayahs: ayahs,
                headings: _headings(2, 'Al-Baqarah', 286),
                arabicFontSize: fontSize,
                resources: const [],
                onVisibleAyah: (a) => reported.add(a.ayahNumber),
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Scroll well into the surah and let the resume-point report fire.
      await _scrollBy(tester, -1500);
      expect(reported, isNotEmpty);
      final before = reported.last;
      expect(before, greaterThan(1)); // genuinely scrolled past verse 1

      // Enlarge the font — without re-anchoring, the same pixel offset would now
      // sit at an earlier verse, so a subsequent report would drift backwards.
      setOuter(() => fontSize = 44);
      await tester.pump(); // didUpdateWidget + relayout
      // The re-anchor is debounced (settles once font-change ticks stop, so a
      // live pinch doesn't jumpTo(0) on every intermediate frame) — wait it out.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(); // post-frame re-anchor

      // Re-trigger a report from the (re-anchored) position: it must not have
      // drifted to an earlier verse than before the font change.
      await _scrollBy(tester, -40, steps: 4);

      expect(reported.last, greaterThanOrEqualTo(before));
    });

    testWidgets('reloading the section in another script keeps the verse',
        (tester) async {
      // A script switch (Uthmani <-> IndoPak) reloads the SAME verses with
      // different-length text. Without a re-anchor, the same pixel offset lands
      // on an earlier verse and Last Read drifts back.
      final reported = <int>[];
      var ayahs = _ayahs(2, 60);
      late StateSetter setOuter;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return MushafView(
                ayahs: ayahs,
                headings: _headings(2, 'Al-Baqarah', 286),
                arabicFontSize: 24,
                resources: const [],
                onVisibleAyah: (a) => reported.add(a.ayahNumber),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await _scrollBy(tester, -1500);
      expect(reported, isNotEmpty);
      final before = reported.last;
      expect(before, greaterThan(1));

      // Switch script: same verse ids, longer text — a same-section reload.
      setOuter(() => ayahs = _ayahsLongText(2, 60));
      await tester.pump(); // didUpdateWidget + relayout
      await tester.pump(); // post-frame re-anchor

      await _scrollBy(tester, -40, steps: 4);

      expect(
        reported.last,
        greaterThanOrEqualTo(before),
        reason: 'script reload drifted from $before to ${reported.last}',
      );
    });

    // Regression: deep in a long surah, BOTH enlarging and shrinking the font
    // must keep the reader on (or very near) the same verse — not jump to v1.
    for (final change in const [
      ('enlarge', 24.0, 40.0),
      ('shrink', 40.0, 24.0),
    ]) {
      testWidgets('${change.$1} font keeps the verse (deep scroll, 286 verses)',
          (tester) async {
        final reported = <int>[];
        var fontSize = change.$2;
        late StateSetter setOuter;
        final ayahs = _ayahs(2, 286);

        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (context, setState) {
                setOuter = setState;
                return MushafView(
                  ayahs: ayahs,
                  headings: _headings(2, 'Al-Baqarah', 286),
                  arabicFontSize: fontSize,
                  resources: const [],
                  onVisibleAyah: (a) => reported.add(a.ayahNumber),
                );
              },
            ),
          ),
        );
        await tester.pump();

        // Scroll deep into the surah.
        await _scrollBy(tester, -4000, steps: 24);
        // Nudge to fire a fresh report of where we actually are.
        await _scrollBy(tester, -20, steps: 3);
        final before = reported.last;
        expect(before, greaterThan(10), reason: 'should be deep in the surah');

        reported.clear();
        setOuter(() => fontSize = change.$3);
        await tester.pump(); // didUpdateWidget + relayout
        await tester
            .pump(const Duration(milliseconds: 150)); // reanchor debounce
        await tester.pump(); // post-frame re-anchor
        // Read the ACTUAL position after the change (not the re-anchor's own
        // report) by nudging the scroll.
        await _scrollBy(tester, -20, steps: 3);

        // The position must not have collapsed back toward verse 1 — some
        // drift is expected now that the re-anchor is debounced (settles
        // ~120ms after the last font-change tick, rather than synchronously),
        // so the tolerance is wider than a same-frame re-anchor would need.
        expect(
          reported.last,
          greaterThan(before * 0.5),
          reason: '${change.$1}: jumped from ~$before to ${reported.last}',
        );
      });
    }
  });

  // -------------------------------------------------------------------------

  group('MushafView — pinch-zoom re-anchor is debounced', () {
    // Regression: a live pinch fires many rapid font-size ticks (one per
    // pointer-move). Re-anchoring on every tick called ItemScrollController's
    // jumpTo, which resets the list to pixel 0 before re-rooting at the held
    // index — so each intermediate tick flashed the list back to its start
    // before snapping forward, reading as content "shifting down" mid-pinch.
    // The fix debounces _reanchor so only the settled font size re-anchors.
    testWidgets(
        'rapid font-size ticks settle to one re-anchor, no mid-pinch drift',
        (tester) async {
      final reported = <int>[];
      var fontSize = 24.0;
      late StateSetter setOuter;
      final ayahs = _ayahs(2, 60);

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return MushafView(
                ayahs: ayahs,
                headings: _headings(2, 'Al-Baqarah', 286),
                arabicFontSize: fontSize,
                resources: const [],
                onVisibleAyah: (a) => reported.add(a.ayahNumber),
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Scroll deep into the surah first.
      await _scrollBy(tester, -1500);
      final before = reported.last;
      expect(before, greaterThan(1));

      // Simulate a live pinch: many font-size ticks in quick succession, each
      // well within the debounce window (no time advances between them).
      for (final size in [26.0, 28.0, 30.0, 32.0, 34.0]) {
        setOuter(() => fontSize = size);
        await tester.pump(); // didUpdateWidget fires per tick
      }

      // Only after the pinch settles does the debounced re-anchor run once.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(); // post-frame jumpTo

      await _scrollBy(tester, -20, steps: 3);
      expect(
        reported.last,
        greaterThanOrEqualTo(before),
        reason: 'settled pinch should not have drifted the reading position',
      );
    });

    testWidgets(
        'a short surah that fits the viewport stays pinned to the top across '
        'zoom (no vertical-centre drift)', (tester) async {
      // Regression: Al-Fatihah fits on screen, so the list can't scroll. The
      // re-anchor used to jumpTo the captured (padding-induced, non-zero) top
      // alignment, nudging the content DOWN a little on every zoom until it
      // looked vertically centred. Zooming in then back to the SAME size must
      // return the top row to exactly where it started.
      var fontSize = 24.0;
      late StateSetter setOuter;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return MushafView(
                ayahs: _ayahs(1, 7),
                headings: _headings(1, 'Al-Fatihah', 7),
                arabicFontSize: fontSize,
                resources: const [],
              );
            },
          ),
        ),
      );
      await tester.pump();
      final startY = tester.getTopLeft(find.text('Al-Fatihah')).dy;

      // Zoom in, settle the debounced re-anchor, then zoom back to 24.
      setOuter(() => fontSize = 40);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      setOuter(() => fontSize = 24);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(
        tester.getTopLeft(find.text('Al-Fatihah')).dy,
        moreOrLessEquals(startY, epsilon: 0.5),
        reason: 'short surah drifted from the top after a zoom round-trip',
      );
    });
  });

  // -------------------------------------------------------------------------

  group('MushafView — no rubber-band past the surah edges', () {
    // The Reading list hard-clamps at the surah's first/last ayah (no
    // overscroll bounce there — mid-content still bounces), matching the
    // "Al Quran word-by-word" feel. Drive it with realistic small-step drags,
    // like a real finger — a single huge synthetic tester.drag offset can
    // outrun a bouncing-physics boundary check in one frame and misrepresent
    // the on-device behaviour.

    ScrollPosition positionOf(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(MushafView),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    testWidgets('pulling down at the surah start does not overscroll',
        (tester) async {
      await tester.pumpWidget(_wrap(_view(ayahs: _ayahs(2, 60))));
      await tester.pump();
      final position = positionOf(tester);
      expect(position.pixels, 0); // opens at the true top

      // Pull DOWN (positive dy) at the very start — would rubber-band under
      // plain bouncing physics.
      await _scrollBy(tester, 400, steps: 10);

      expect(
        position.pixels,
        lessThanOrEqualTo(position.minScrollExtent),
        reason: 'no rubber-band below the surah start',
      );
    });

    testWidgets('a downward pull at the start still holds no overscroll',
        (tester) async {
      // The clamp must not break normal forward scrolling afterward.
      await tester.pumpWidget(_wrap(_view(ayahs: _ayahs(2, 60))));
      await tester.pump();
      final position = positionOf(tester);

      await _scrollBy(tester, 400, steps: 10); // pull down (clamped)
      await _scrollBy(tester, -600, steps: 10); // forward into content

      expect(
        position.pixels,
        greaterThan(0),
        reason: 'forward scroll after an edge clamp still works',
      );
    });

    testWidgets('pulling up at the surah end does not overscroll',
        (tester) async {
      // A short surah so a couple of drags reliably reach the true bottom.
      await tester.pumpWidget(_wrap(_view(ayahs: _ayahs(1, 7))));
      await tester.pump();
      final position = positionOf(tester);

      // Scroll to the very end first.
      await _scrollBy(tester, -2000, steps: 10);
      final maxAtBottom = position.maxScrollExtent;

      // Pull UP (negative dy) past the last ayah — would rubber-band under
      // plain bouncing physics.
      await _scrollBy(tester, -400, steps: 10);

      expect(
        position.pixels,
        lessThanOrEqualTo(maxAtBottom),
        reason: 'no rubber-band past the surah end',
      );
    });
  });

  // -------------------------------------------------------------------------

  group('page pill visibility', () {
    // Long Arabic + page metadata so the view actually scrolls and _onScroll
    // runs. [pages] assigns each verse's Mushaf page.
    List<Ayah> scrollable(int count, int Function(int n) pages) => [
          for (var n = 1; n <= count; n++)
            Ayah(
              id: 2000 + n,
              surahId: 2,
              ayahNumber: n,
              textArabic: 'نص طويل جدا للآية رقم $n مع كلمات إضافية كثيرة هنا',
              isSajda: false,
              page: pages(n),
            ),
        ];

    double pillOpacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.textContaining('Page '),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    testWidgets('stays hidden while scrolling a single-page section',
        (tester) async {
      await tester.pumpWidget(_wrap(_view(ayahs: scrollable(30, (_) => 1))));
      await tester.drag(
        find.byType(MushafView),
        const Offset(0, -400),
      );
      await tester.pump();
      expect(pillOpacity(tester), 0.0);
    });

    testWidgets('appears while scrolling a multi-page section', (tester) async {
      await tester.pumpWidget(
        _wrap(_view(ayahs: scrollable(30, (n) => (n + 4) ~/ 5))),
      );
      await tester.drag(
        find.byType(MushafView),
        const Offset(0, -400),
      );
      await tester.pump();
      expect(pillOpacity(tester), greaterThan(0));
    });
  });

  // -------------------------------------------------------------------------

  group('groupAyahsBySurah', () {
    test('single surah → one group', () {
      final groups = groupAyahsBySurah(_ayahs(2, 5));
      expect(groups.length, 1);
      expect(groups.first.length, 5);
    });

    test('two surahs → two groups in order', () {
      final groups = groupAyahsBySurah([..._ayahs(1, 3), ..._ayahs(2, 2)]);
      expect(groups.length, 2);
      expect(groups[0].first.surahId, 1);
      expect(groups[1].first.surahId, 2);
    });

    test('empty input → empty output', () {
      expect(groupAyahsBySurah([]), isEmpty);
    });
  });
}
