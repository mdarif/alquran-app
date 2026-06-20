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

Map<int, SurahHeading> _headings(int surahId, String name, int count) => {
      surahId: SurahHeading(
        number: surahId,
        nameEnglish: name,
        totalAyahs: count,
      ),
    };

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('MushafView', () {
    testWidgets('renders chapter header with name and ayah count',
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
      expect(find.text('Surah 2 · 286 ayahs'), findsOneWidget);
    });

    testWidgets('renders an English medallion number for each ayah',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(112, 4),
            headings: _headings(112, 'Al-Ikhlas', 4),
            arabicFontSize: 28,
          ),
        ),
      );

      for (final n in ['1', '2', '3', '4']) {
        expect(find.text(n), findsOneWidget);
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
