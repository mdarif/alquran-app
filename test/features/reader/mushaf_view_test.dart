import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/surah_heading.dart';
import 'package:al_quran/features/reader/presentation/widgets/mushaf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('MushafView', () {
    testWidgets('renders chapter header with the name (no ayah count)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(2, 3),
            headings: _headings(2, 'Al-Baqarah', 286),
            arabicFontSize: 28,
          ),
        ),
      );

      expect(find.text('Al-Baqarah'), findsOneWidget);
      expect(find.textContaining('ayahs'), findsNothing);
    });

    testWidgets('shows the Arabic surah name and a revelation/verses meta line',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(1, 7),
            headings: _headings(
              1,
              'Al-Fatihah',
              7,
              arabic: 'الفاتحة',
              place: 'makkah',
            ),
            arabicFontSize: 28,
          ),
        ),
      );

      expect(find.text('الفاتحة'), findsOneWidget);
      expect(find.text('Meccan · 7 Verses'), findsOneWidget);
    });

    testWidgets('omits the meta line when surah metadata is unavailable',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(2, 3),
            headings: const {}, // no heading → fallback name, no meta
            arabicFontSize: 28,
          ),
        ),
      );

      expect(find.textContaining('verses'), findsNothing);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('the Arabic flow is centered and right-to-left',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(2, 3),
            headings: _headings(2, 'Al-Baqarah', 286),
            arabicFontSize: 28,
          ),
        ),
      );

      // Each surah group is one Text.rich; pick the first one.
      final flow = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere((t) => t.textSpan != null);
      expect(flow.textAlign, TextAlign.center);
      expect(flow.textDirection, TextDirection.rtl);
    });

    testWidgets('appends each ayah number as Arabic-Indic digits (font draws '
        'the rosette around them)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(112, 4),
            headings: _headings(112, 'Al-Ikhlas', 4),
            arabicFontSize: 28,
          ),
        ),
      );

      // The number is plain text in the surah paragraph (the KFGQPC font composes
      // the digits into the ayah rosette at render time). No U+06DD is added.
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

    testWidgets('shows the Bismillah for an ordinary surah from ayah 1',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(2, 3),
            headings: _headings(2, 'Al-Baqarah', 286),
            arabicFontSize: 28,
          ),
        ),
      );

      expect(find.byType(Bismillah), findsOneWidget);
    });

    testWidgets('hides the Bismillah for Al-Fatihah (it is ayah 1)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(1, 7),
            headings: _headings(1, 'Al-Fatihah', 7),
            arabicFontSize: 28,
          ),
        ),
      );

      expect(find.byType(Bismillah), findsNothing);
    });

    testWidgets('hides the Bismillah for At-Tawbah (it has none)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(9, 5),
            headings: _headings(9, 'At-Tawbah', 129),
            arabicFontSize: 28,
          ),
        ),
      );

      expect(find.byType(Bismillah), findsNothing);
    });

    testWidgets('shows a current-page readout when ayahs carry page numbers',
        (tester) async {
      const ayahs = [
        Ayah(
          id: 1,
          surahId: 2,
          ayahNumber: 1,
          textArabic: 'نص',
          isSajda: false,
          page: 5,
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: ayahs,
            headings: _headings(2, 'Al-Baqarah', 286),
            arabicFontSize: 28,
          ),
        ),
      );

      expect(find.text('Page 5'), findsOneWidget);
    });

    testWidgets('renders a header per surah when a section spans surahs',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: [..._ayahs(1, 2), ..._ayahs(2, 2)],
            headings: {
              ..._headings(1, 'Al-Fatihah', 7),
              ..._headings(2, 'Al-Baqarah', 286),
            },
            arabicFontSize: 28,
          ),
        ),
      );

      expect(find.text('Al-Fatihah'), findsOneWidget);
      expect(find.text('Al-Baqarah'), findsOneWidget);
    });
  });
}
