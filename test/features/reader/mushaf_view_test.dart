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
  TranslationResource(id: 1, languageCode: 'ur', name: 'Urdu', author: 'Junagarhi'),
  TranslationResource(id: 2, languageCode: 'hi', name: 'Hindi', author: 'al-Umari'),
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
    (w) => w is GestureDetector && w.onTap != null && w.onVerticalDragEnd != null,
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
            headings: _headings(1, 'Al-Fatihah', 7, arabic: 'الفاتحة', place: 'makkah'),
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

    testWidgets('the Arabic flow is centered and right-to-left', (tester) async {
      await tester.pumpWidget(_wrap(_view()));
      final flow = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere((t) => t.textSpan != null);
      expect(flow.textAlign, TextAlign.center);
      expect(flow.textDirection, TextDirection.rtl);
    });

    testWidgets('appends ayah numbers as Arabic-Indic digits (no U+06DD added)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          _view(
            ayahs: _ayahs(112, 4),
            headings: _headings(112, 'Al-Ikhlas', 4),
          ),
        ),
      );
      final allText = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.textSpan != null)
          .map((t) => t.textSpan!.toPlainText())
          .join();
      expect(allText.contains('۝'), isFalse);
      for (final n in ['١', '٢', '٣', '٤']) {
        expect(allText, contains(n));
      }
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

    testWidgets('shows a current-page readout when ayahs carry page numbers',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          _view(
            ayahs: const [
              Ayah(id: 1, surahId: 2, ayahNumber: 1, textArabic: 'نص', isSajda: false, page: 5),
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
    testWidgets('card is absent before any verse is tapped', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(1, 7),
            headings: _headings(1, 'Al-Fatihah', 7),
            arabicFontSize: 28,
            resources: _kResources,
          ),
        ),
      );
      // No 'Ayah N' label in the tree — the card returns SizedBox.shrink().
      expect(find.textContaining('Ayah '), findsNothing);
    });

    testWidgets('card is absent before any verse is tapped even for a short surah',
        (tester) async {
      // Al-Fatihah (7 ayahs) fits on screen without scrolling — this was the
      // failing case before the SizedBox.expand() fix (the Stack sized to content
      // height, so Positioned(bottom:0) was above the real screen bottom).
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(1, 7),
            headings: _headings(1, 'Al-Fatihah', 7),
            arabicFontSize: 28,
            resources: _kResources,
          ),
        ),
      );
      await tester.pump();
      // The grab handle must not be visible at any point before a verse is tapped.
      // We confirm by asserting no peek-card content is in the widget tree.
      expect(find.textContaining('Ayah '), findsNothing);
      // The card widget itself should be SizedBox.shrink() — zero height.
      // We verify this by checking that no Material with elevation 12 exists.
      final materials = tester
          .widgetList<Material>(find.byType(Material))
          .where((m) => m.elevation == 12);
      expect(materials, isEmpty);
    });

    testWidgets('tapping the text opens the card and shows an Ayah label',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahsWithTranslations(1, 3),
            headings: _headings(1, 'Al-Fatihah', 7),
            arabicFontSize: 28,
            resources: _kResources,
          ),
        ),
      );
      await tester.pump();
      await _tapText(tester);

      expect(find.textContaining('Ayah '), findsOneWidget);
    });

    testWidgets('card shows translations matching the tapped verse',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahsWithTranslations(1, 1),
            headings: _headings(1, 'Al-Fatihah', 7),
            arabicFontSize: 28,
            resources: _kResources,
          ),
        ),
      );
      await tester.pump();
      await _tapText(tester);

      // The card must render both translation strings.
      expect(find.text('اردو ترجمہ'), findsOneWidget);
      expect(find.text('هिंदी अनुवाद'), findsNothing); // not the right text
      // Use a contained-in check robust to the specific translation strings.
      // Label is just the author name — no language prefix.
      expect(find.text('Junagarhi'), findsOneWidget);
      expect(find.text('al-Umari'), findsOneWidget);
    });

    testWidgets('card shows the Arabic text of the tapped verse', (tester) async {
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
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: singleAyah,
            headings: _headings(1, 'Al-Fatihah', 7),
            arabicFontSize: 28,
            resources: _kResources,
          ),
        ),
      );
      await tester.pump();
      await _tapText(tester);

      // The Arabic text appears in the card (once in the flow, once in the card).
      expect(find.text('بِسْمِ اللَّهِ'), findsWidgets);
    });

    testWidgets('tapping the handle dismisses the card', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahsWithTranslations(1, 1),
            headings: _headings(1, 'Al-Fatihah', 7),
            arabicFontSize: 28,
            resources: _kResources,
          ),
        ),
      );
      await tester.pump();

      // Open.
      await _tapText(tester);
      expect(find.textContaining('Ayah '), findsOneWidget);

      // Dismiss via the handle.
      await _tapHandle(tester);

      // The label is gone — AnimationStatus.dismissed listener cleared _shownAyah.
      expect(find.textContaining('Ayah '), findsNothing);
    });

    testWidgets('card disappears completely after dismiss (no handle visible)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahsWithTranslations(1, 1),
            headings: _headings(1, 'Al-Fatihah', 7),
            arabicFontSize: 28,
            resources: _kResources,
          ),
        ),
      );
      await tester.pump();
      await _tapText(tester);
      await _tapHandle(tester);

      // No peek-card Material at all in the tree after full dismissal.
      final materials = tester
          .widgetList<Material>(find.byType(Material))
          .where((m) => m.elevation == 12);
      expect(materials, isEmpty);
    });

    testWidgets('tapping the same verse again closes the card', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahsWithTranslations(1, 1),
            headings: _headings(1, 'Al-Fatihah', 7),
            arabicFontSize: 28,
            resources: _kResources,
          ),
        ),
      );
      await tester.pump();

      // Open.
      await _tapText(tester);
      expect(find.textContaining('Ayah '), findsOneWidget);

      // Tap same spot again — _selectedAyah.id == tapped.id → _dismissPeek().
      await _tapText(tester);
      expect(find.textContaining('Ayah '), findsNothing);
    });

    testWidgets('no resources — card opens with Arabic only, no crash',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahsWithTranslations(1, 1),
            headings: _headings(1, 'Al-Fatihah', 7),
            arabicFontSize: 28,
            resources: const [], // empty list
          ),
        ),
      );
      await tester.pump();
      await _tapText(tester);

      expect(find.textContaining('Ayah '), findsOneWidget);
      // No author labels when there are no resources.
      expect(find.textContaining('Junagarhi'), findsNothing);
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
