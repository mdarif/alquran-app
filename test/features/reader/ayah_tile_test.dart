import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/presentation/widgets/ayah_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _urdu = TranslationResource(id: 1, languageCode: 'ur', name: 'Junagarhi');
const _hindi = TranslationResource(id: 2, languageCode: 'hi', name: 'al-Umari');

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

Text _arabicTextOf(WidgetTester tester, String value) =>
    tester.widgetList<Text>(find.text(value)).single;

void main() {
  group('AyahTile', () {
    testWidgets('renders ayah number, Arabic, and both translations',
        (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 1,
        ayahNumber: 1,
        textArabic: 'بِسْمِ ٱللَّهِ',
        isSajda: false,
        translations: {1: 'اللہ کے نام', 2: 'अल्लाह के नाम'},
      );

      await tester.pumpWidget(
        _wrap(
          const AyahTile(
            ayah: ayah,
            resources: [_urdu, _hindi],
            arabicFontSize: 28,
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget); // ayah number badge
      expect(find.text('بِسْمِ ٱللَّهِ'), findsOneWidget);
      expect(find.text('اللہ کے نام'), findsOneWidget);
      expect(find.text('अल्लाह के नाम'), findsOneWidget);
    });

    testWidgets('applies the supplied Arabic font size (pinch-zoom)',
        (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 1,
        ayahNumber: 1,
        textArabic: 'نص',
        isSajda: false,
      );

      await tester.pumpWidget(
        _wrap(
          const AyahTile(ayah: ayah, resources: [], arabicFontSize: 42),
        ),
      );

      expect(_arabicTextOf(tester, 'نص').style?.fontSize, 42);
    });

    testWidgets('shows the sajda marker only when isSajda is true',
        (tester) async {
      const base = Ayah(
        id: 1,
        surahId: 1,
        ayahNumber: 1,
        textArabic: 'نص',
        isSajda: false,
      );

      await tester.pumpWidget(
        _wrap(
          const AyahTile(ayah: base, resources: [], arabicFontSize: 24),
        ),
      );
      expect(find.byIcon(Icons.star), findsNothing);

      await tester.pumpWidget(
        _wrap(
          const AyahTile(
            ayah: Ayah(
              id: 1,
              surahId: 1,
              ayahNumber: 1,
              textArabic: 'نص',
              isSajda: true,
            ),
            resources: [],
            arabicFontSize: 24,
          ),
        ),
      );
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('omits a translation row when the ayah lacks that resource',
        (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 1,
        ayahNumber: 1,
        textArabic: 'نص',
        isSajda: false,
        translations: {1: 'اردو فقط'}, // Urdu only, no Hindi
      );

      await tester.pumpWidget(
        _wrap(
          const AyahTile(
            ayah: ayah,
            resources: [_urdu, _hindi],
            arabicFontSize: 24,
          ),
        ),
      );

      expect(find.text('اردو فقط'), findsOneWidget);
      expect(find.text('अल्लाह के नाम'), findsNothing);
    });
  });
}
