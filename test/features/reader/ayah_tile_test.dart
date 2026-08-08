import 'package:al_quran/core/theme/app_icons.dart';
import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/presentation/widgets/ayah_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Mirror the real DB shape: `name` is the language label, `author` the
// translator. The attribution line shows just the translator — the script
// already makes the language obvious.
const _urdu = TranslationResource(
  id: 1,
  slug: 'ur-test',
  languageCode: 'ur',
  name: 'Urdu',
  author: 'Junagarhi',
  direction: 'rtl',
);
const _hindi = TranslationResource(
  id: 2,
  slug: 'hi-test',
  languageCode: 'hi',
  name: 'Hindi',
  author: 'al-Umari',
);
const _english = TranslationResource(
  id: 3,
  slug: 'en-test',
  languageCode: 'en',
  name: 'English',
  author: 'Hilali & Khan',
);

/// A Latin-script pilot edition sharing languageCode 'ur' with [_urdu] but
/// direction 'ltr' — like ur-roman-abu-rayyan, whose author is a two-person
/// licensing credit too long for the reader, so creditName carries the short
/// display name instead.
const _romanUrdu = TranslationResource(
  id: 4,
  slug: 'ur-roman-test',
  languageCode: 'ur',
  name: 'Abu Rayyan',
  author: 'Muhammad Junagarhi; transliterated by Abu Rayyan',
  direction: 'ltr',
  creditName: 'Abu Rayyan',
  experimental: true,
);

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
        translations: {'ur-test': 'اللہ کے نام', 'hi-test': 'अल्लाह के नाम'},
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
      expect(find.byIcon(AppIcons.sajda), findsNothing);

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
      expect(find.byIcon(AppIcons.sajda), findsOneWidget);
    });

    testWidgets('omits a translation row when the ayah lacks that resource',
        (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 1,
        ayahNumber: 1,
        textArabic: 'نص',
        isSajda: false,
        translations: {'ur-test': 'اردو فقط'}, // Urdu only, no Hindi
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

    testWidgets(
        'shows the author attribution per translation (no language prefix)',
        (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 2,
        ayahNumber: 1,
        textArabic: 'الٓمٓ',
        isSajda: false,
        translations: {'ur-test': 'اردو', 'en-test': 'english'},
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

      expect(find.text('Junagarhi'), findsOneWidget);
      expect(find.text('Hilali & Khan'), findsOneWidget);
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

    testWidgets('offers visible Copy / Share actions', (tester) async {
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

      expect(find.byTooltip('Copy'), findsOneWidget);
      expect(find.byTooltip('Share'), findsOneWidget);
    });

    testWidgets(
        'ayah overflow menu uses compact rows instead of padded ListTiles',
        (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 2,
        ayahNumber: 1,
        textArabic: 'الٓمٓ',
        isSajda: false,
      );

      await tester.pumpWidget(
        _wrap(
          AyahTile(
            ayah: ayah,
            resources: const [],
            arabicFontSize: 24,
            onOpenTranslations: () {},
          ),
        ),
      );

      await tester.tap(find.byIcon(AppIcons.more));
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: find.text('Translations'),
          matching: find.byType(ListTile),
        ),
        findsNothing,
      );
    });

    testWidgets('Translations menu item opens the translation picker',
        (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 2,
        ayahNumber: 1,
        textArabic: 'الٓمٓ',
        isSajda: false,
      );
      var opened = false;

      await tester.pumpWidget(
        _wrap(
          AyahTile(
            ayah: ayah,
            resources: const [],
            arabicFontSize: 24,
            onOpenTranslations: () => opened = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(AppIcons.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Translations'));
      await tester.pumpAndSettle();

      expect(opened, isTrue);
    });

    testWidgets('shows a visible bookmark affordance when bookmark is wired',
        (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 2,
        ayahNumber: 1,
        textArabic: 'الٓمٓ',
        isSajda: false,
      );
      var toggled = false;

      await tester.pumpWidget(
        _wrap(
          AyahTile(
            ayah: ayah,
            resources: const [],
            arabicFontSize: 24,
            isBookmarked: true,
            onToggleBookmark: () => toggled = true,
          ),
        ),
      );

      final bookmark = find.byTooltip('Remove bookmark');
      expect(bookmark, findsOneWidget);

      await tester.tap(bookmark);
      await tester.pump();

      expect(toggled, isTrue);
    });

    testWidgets('Copy puts the ayah text on the clipboard and confirms',
        (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 2,
        ayahNumber: 1,
        textArabic: 'الٓمٓ',
        isSajda: false,
        translations: {'ur-test': 'اردو'},
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

      await tester.tap(find.byTooltip('Copy'));
      await tester.pumpAndSettle();

      expect(
        copied,
        'Al-Baqarah 2:1\n\nالٓمٓ\n\nJunagarhi\nاردو'
        '\n\nAl Quran · alquranreader.com',
      );
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

      await tester.tap(find.byTooltip('Share'));
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
        translations: {'ur-test': 'اردو ترجمہ'},
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

    testWidgets(
        'a Latin-script pilot edition sharing languageCode "ur" renders '
        'left-to-right with its short credit + Experimental pill',
        (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 1,
        ayahNumber: 1,
        textArabic: 'الٓمٓ',
        isSajda: false,
        translations: {'ur-roman-test': 'Alif Laam Meem'},
      );

      await tester.pumpWidget(
        _wrap(
          const AyahTile(
            ayah: ayah,
            resources: [_romanUrdu],
            arabicFontSize: 24,
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Alif Laam Meem'));
      expect(text.textDirection, TextDirection.ltr);
      expect(text.textAlign, TextAlign.left);
      // Short creditName ("Abu Rayyan"), not the full licensing author string.
      expect(find.text('Abu Rayyan'), findsOneWidget);
      expect(
        find.text('Muhammad Junagarhi; transliterated by Abu Rayyan'),
        findsNothing,
      );
      expect(find.text('Experimental'), findsOneWidget);
    });

    testWidgets('a non-experimental edition shows no Experimental pill',
        (tester) async {
      const ayah = Ayah(
        id: 1,
        surahId: 1,
        ayahNumber: 1,
        textArabic: 'الٓمٓ',
        isSajda: false,
        translations: {'ur-test': 'اردو ترجمہ'},
      );

      await tester.pumpWidget(
        _wrap(
          const AyahTile(ayah: ayah, resources: [_urdu], arabicFontSize: 24),
        ),
      );

      expect(find.text('Experimental'), findsNothing);
    });

    group('translation-audio toggle (Al-Fatihah POC)', () {
      const ayah = Ayah(
        id: 1,
        surahId: 1,
        ayahNumber: 1,
        textArabic: 'بِسْمِ ٱللَّهِ',
        isSajda: false,
      );

      testWidgets('hidden when onToggleTranslationAudio is null',
          (tester) async {
        await tester.pumpWidget(
          _wrap(
            const AyahTile(ayah: ayah, resources: [], arabicFontSize: 24),
          ),
        );
        expect(find.byIcon(AppIcons.translationAudio), findsNothing);
      });

      testWidgets('shown outlined when off, tap invokes the callback',
          (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _wrap(
            AyahTile(
              ayah: ayah,
              resources: const [],
              arabicFontSize: 24,
              onToggleTranslationAudio: () => taps++,
            ),
          ),
        );

        expect(find.byIcon(AppIcons.translationAudio), findsOneWidget);
        await tester.tap(find.byIcon(AppIcons.translationAudio));
        expect(taps, 1);
      });

      testWidgets('renders filled when translationAudioEnabled is true',
          (tester) async {
        await tester.pumpWidget(
          _wrap(
            AyahTile(
              ayah: ayah,
              resources: const [],
              arabicFontSize: 24,
              translationAudioEnabled: true,
              onToggleTranslationAudio: () {},
            ),
          ),
        );

        final icon =
            tester.widget<Icon>(find.byIcon(AppIcons.translationAudio));
        expect(icon.fill, 1);
      });
    });
  });
}
