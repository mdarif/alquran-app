import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/core/theme/mushaf_palette.dart';
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

    testWidgets('tapping a verse opens the card with the verse reference',
        (tester) async {
      await tester.pumpWidget(reader(_ayahsWithTranslations(1, 3)));
      await tester.pump();
      await _tapText(tester);

      expect(cardVisible(tester), isTrue);
      // Reference like "Al-Fatihah · 1:2" — unique to the card (the header meta
      // line reads "Meccan · 7 Verses").
      expect(find.textContaining('Al-Fatihah · 1:'), findsOneWidget);
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

    testWidgets('‹/› step through verses and clamp at the section edges',
        (tester) async {
      await tester.pumpWidget(reader(_ayahsWithTranslations(1, 3)));
      await tester.pump();
      await _tapText(tester); // open the peek on a verse

      String ref() => tester
          .widgetList<Text>(find.textContaining('Al-Fatihah · 1:'))
          .first
          .data!;
      Future<void> step(Key k) async {
        await tester.tap(find.byKey(k));
        await tester.pumpAndSettle();
      }

      // Walk to the first verse; taps past the edge are no-ops (button disabled).
      for (var i = 0; i < 3; i++) {
        await step(WidgetKeys.peekPrevButton);
      }
      expect(ref(), 'Al-Fatihah · 1:1');

      // Next advances the peeked verse (reference + its translation update).
      await step(WidgetKeys.peekNextButton);
      expect(ref(), 'Al-Fatihah · 1:2');

      // Walk to the last verse; further next taps clamp at 1:3.
      for (var i = 0; i < 3; i++) {
        await step(WidgetKeys.peekNextButton);
      }
      expect(ref(), 'Al-Fatihah · 1:3');
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

      // Drag to scroll, then pump just one frame (NO 1200ms wait): the report
      // must already have fired on the scroll-end notification.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1500),
      );
      await tester.pump();

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
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1500),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(reported, isNotEmpty);
      final before = reported.last;
      expect(before, greaterThan(1)); // genuinely scrolled past verse 1

      // Enlarge the font — without re-anchoring, the same pixel offset would now
      // sit at an earlier verse, so a subsequent report would drift backwards.
      setOuter(() => fontSize = 44);
      await tester.pump(); // didUpdateWidget + relayout
      await tester.pump(); // post-frame re-anchor

      // Re-trigger a report from the (re-anchored) position: it must not have
      // drifted to an earlier verse than before the font change.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -40),
      );
      await tester.pump(const Duration(seconds: 2));

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

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1500),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(reported, isNotEmpty);
      final before = reported.last;
      expect(before, greaterThan(1));

      // Switch script: same verse ids, longer text — a same-section reload.
      setOuter(() => ayahs = _ayahsLongText(2, 60));
      await tester.pump(); // didUpdateWidget + relayout
      await tester.pump(); // post-frame re-anchor

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -40),
      );
      await tester.pump(const Duration(seconds: 2));

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
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -4000),
        );
        await tester.pump(const Duration(seconds: 2));
        // Nudge to fire a fresh report of where we actually are.
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -20),
        );
        await tester.pump(const Duration(seconds: 2));
        final before = reported.last;
        expect(before, greaterThan(10), reason: 'should be deep in the surah');

        reported.clear();
        setOuter(() => fontSize = change.$3);
        await tester.pump(); // didUpdateWidget + relayout
        await tester.pump(); // post-frame re-anchor
        // Read the ACTUAL position after the change (not the re-anchor's own
        // report) by nudging the scroll.
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -20),
        );
        await tester.pump(const Duration(seconds: 2));

        // The position must not have collapsed back toward verse 1.
        expect(
          reported.last,
          greaterThan(before - 15),
          reason: '${change.$1}: jumped from ~$before to ${reported.last}',
        );
      });
    }
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
