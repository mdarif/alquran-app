import 'package:al_quran/features/surahs/domain/entities/surah.dart';
import 'package:al_quran/features/surahs/presentation/widgets/surah_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('SurahTile', () {
    testWidgets('renders names, capitalised place, and ayah count',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SurahTile(
            surah: const Surah(
              id: 1,
              nameArabic: 'الفاتحة',
              nameEnglish: 'Al-Fatihah',
              totalAyahs: 7,
              revelationPlace: 'makkah',
            ),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Al-Fatihah'), findsOneWidget);
      expect(find.text('الفاتحة'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // leading badge
      expect(find.text('Makkah • 7 ayahs'), findsOneWidget);
    });

    testWidgets('omits the place segment when revelationPlace is null',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SurahTile(
            surah: const Surah(
              id: 2,
              nameArabic: 'البقرة',
              nameEnglish: 'Al-Baqarah',
              totalAyahs: 286,
            ),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('286 ayahs'), findsOneWidget);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          SurahTile(
            surah: const Surah(
              id: 1,
              nameArabic: 'الفاتحة',
              nameEnglish: 'Al-Fatihah',
              totalAyahs: 7,
              revelationPlace: 'makkah',
            ),
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(SurahTile));
      expect(tapped, isTrue);
    });
  });
}
