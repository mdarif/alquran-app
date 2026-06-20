import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/presentation/widgets/ayah_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _urdu = TranslationResource(id: 1, languageCode: 'ur', name: 'Junagarhi');
const _hindi = TranslationResource(id: 2, languageCode: 'hi', name: 'al-Umari');
const _english =
    TranslationResource(id: 3, languageCode: 'en', name: 'Hilali & Khan');

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

    testWidgets('shows a language + author attribution per translation',
        (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 2,
        ayahNumber: 1,
        textArabic: 'الٓمٓ',
        isSajda: false,
        translations: {1: 'اردو', 3: 'english'},
      );

      await tester.pumpWidget(
        _wrap(
          const AyahTile(
            ayah: ayah,
            resources: [_urdu, _english],
            arabicFontSize: 24,
          ),
        ),
      );

      expect(find.text('Urdu · Junagarhi'), findsOneWidget);
      expect(find.text('English · Hilali & Khan'), findsOneWidget);
    });

    testWidgets('does not show the page number', (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 2,
        ayahNumber: 1,
        textArabic: 'الٓمٓ',
        isSajda: false,
        page: 2,
      );

      await tester.pumpWidget(
        _wrap(
          const AyahTile(ayah: ayah, resources: [], arabicFontSize: 24),
        ),
      );

      expect(find.textContaining('p. 2'), findsNothing);
    });

    testWidgets('offers a Copy / Share menu', (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 2,
        ayahNumber: 1,
        textArabic: 'الٓمٓ',
        isSajda: false,
      );

      await tester.pumpWidget(
        _wrap(
          const AyahTile(ayah: ayah, resources: [], arabicFontSize: 24),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('Copy puts the ayah text on the clipboard and confirms',
        (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 2,
        ayahNumber: 1,
        textArabic: 'الٓمٓ',
        isSajda: false,
        translations: {1: 'اردو'},
      );

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(
        _wrap(
          const AyahTile(
            ayah: ayah,
            resources: [_urdu],
            arabicFontSize: 24,
            surahName: 'Al-Baqarah',
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(copied, 'الٓمٓ\n\nاردو\n\n— Al-Baqarah 2:1');
      expect(find.text('Ayah copied'), findsOneWidget);
    });

    testWidgets('a failing Share is handled gracefully (no crash)',
        (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 2,
        ayahNumber: 1,
        textArabic: 'الٓمٓ',
        isSajda: false,
      );

      // Simulate the share plugin being unavailable (MissingPluginException).
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (call) async => throw MissingPluginException('no share'),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          null,
        ),
      );

      await tester.pumpWidget(
        _wrap(
          const AyahTile(ayah: ayah, resources: [], arabicFontSize: 24),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull); // no unhandled exception
      expect(find.text('Could not share'), findsOneWidget);
    });

    testWidgets('renders Urdu translation right-to-left', (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 2,
        ayahNumber: 1,
        textArabic: 'الٓمٓ',
        isSajda: false,
        translations: {1: 'اردو ترجمہ'},
      );

      await tester.pumpWidget(
        _wrap(
          const AyahTile(ayah: ayah, resources: [_urdu], arabicFontSize: 24),
        ),
      );

      final urduText = tester.widget<Text>(find.text('اردو ترجمہ'));
      expect(urduText.textDirection, TextDirection.rtl);
      expect(urduText.textAlign, TextAlign.right);
    });
  });
}
