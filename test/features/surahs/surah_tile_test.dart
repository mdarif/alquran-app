import 'package:al_quran/features/surahs/domain/entities/surah.dart';
import 'package:al_quran/features/surahs/presentation/widgets/surah_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('SurahTile', () {
    testWidgets('renders names + Makki/Madani revelation and the ayah count',
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
      expect(find.text('Makki · 7 Ayah'), findsOneWidget);
    });

    testWidgets('Arabic chapter name is rendered prominently', (tester) async {
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

      expect(tester.widget<Text>(find.text('الفاتحة')).style?.fontSize, 30);
    });

    testWidgets('keeps minimum row height compact enough for fast scanning',
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

      final tileConstraint = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox && widget.constraints.minHeight > 0,
      );
      final minHeights = [
        for (final element in tileConstraint.evaluate())
          (element.widget as ConstrainedBox).constraints.minHeight,
      ];
      expect(
        minHeights,
        contains(70),
      );
    });

    testWidgets('falls back to the ayah count when revelationPlace is null',
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

      expect(find.text('Al-Baqarah'), findsOneWidget);
      expect(find.text('286 Ayah'), findsOneWidget);
      expect(find.textContaining('Madani'), findsNothing);
    });

    testWidgets('a verse hit replaces the count, keeping the line to two parts',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SurahTile(
            surah: const Surah(
              id: 18,
              nameArabic: 'الكهف',
              nameEnglish: 'Al-Kahf',
              totalAyahs: 110,
              revelationPlace: 'makkah',
            ),
            verse: 5,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Makki · Ayah 5'), findsOneWidget);
      expect(find.textContaining('110'), findsNothing);
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
