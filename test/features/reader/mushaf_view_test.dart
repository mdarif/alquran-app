import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/presentation/widgets/mushaf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _bismillahKey = Key('mushaf-bismillah');

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

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('MushafView', () {
    testWidgets('renders chapter header with number, name, and ayah count',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(2, 3),
            arabicFontSize: 28,
            surahNumber: 2,
            surahName: 'Al-Baqarah',
          ),
        ),
      );

      expect(find.text('Al-Baqarah'), findsOneWidget);
      expect(find.text('Surah 2 · 3 ayahs'), findsOneWidget);
    });

    testWidgets('renders an English medallion number for each ayah',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(112, 4),
            arabicFontSize: 28,
            surahNumber: 112,
            surahName: 'Al-Ikhlas',
          ),
        ),
      );

      for (final n in ['1', '2', '3', '4']) {
        expect(find.text(n), findsOneWidget);
      }
    });

    testWidgets('shows the Bismillah header for an ordinary surah',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(2, 3),
            arabicFontSize: 28,
            surahNumber: 2,
            surahName: 'Al-Baqarah',
          ),
        ),
      );

      expect(find.byKey(_bismillahKey), findsOneWidget);
    });

    testWidgets('hides the Bismillah for Al-Fatihah (it is ayah 1)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(1, 7),
            arabicFontSize: 28,
            surahNumber: 1,
            surahName: 'Al-Fatihah',
          ),
        ),
      );

      expect(find.byKey(_bismillahKey), findsNothing);
    });

    testWidgets('hides the Bismillah for At-Tawbah (it has none)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MushafView(
            ayahs: _ayahs(9, 5),
            arabicFontSize: 28,
            surahNumber: 9,
            surahName: 'At-Tawbah',
          ),
        ),
      );

      expect(find.byKey(_bismillahKey), findsNothing);
    });
  });
}
