import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_catalogue_entry.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_entry.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_resource.dart';
import 'package:al_quran/features/tafsir/domain/repositories/tafsir_repository.dart';
import 'package:al_quran/features/tafsir/presentation/cubit/tafsir_cubit.dart';
import 'package:al_quran/features/tafsir/presentation/tafsir_sheet.dart';
import 'package:al_quran/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  tearDown(GetIt.I.reset);

  testWidgets('ayah Tafsir sheet shows Arabic and enabled translations',
      (tester) async {
    GetIt.I
      ..registerLazySingleton<TafsirRepository>(_FakeTafsirRepository.new)
      ..registerLazySingleton<TafsirCubit>(
        () => TafsirCubit(GetIt.I<TafsirRepository>()),
      );

    const ayah = Ayah(
      id: 1,
      surahId: 1,
      ayahNumber: 1,
      textArabic: 'بِسْمِ اللَّهِ',
      isSajda: false,
      translations: {
        'ur-test': 'اللہ کے نام سے',
        'en-test': 'In the name of Allah',
        'hidden-test': 'Hidden translation',
      },
    );
    const resources = [
      TranslationResource(
        id: 1,
        slug: 'ur-test',
        languageCode: 'ur',
        name: 'Urdu',
        author: 'Junagarhi',
        direction: 'rtl',
      ),
      TranslationResource(
        id: 2,
        slug: 'en-test',
        languageCode: 'en',
        name: 'English',
        author: 'Saheeh International',
        experimental: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTafsirForAyahSheet(
              context,
              ayah: ayah,
              resources: resources,
              surahName: 'Al-Fatihah',
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('بِسْمِ اللَّهِ'), findsOneWidget);
    expect(find.text('اللہ کے نام سے'), findsOneWidget);
    expect(find.text('In the name of Allah'), findsOneWidget);
    expect(find.text('Experimental'), findsOneWidget);
    expect(find.text('Hidden translation'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'Al-Fatihah 1:1',
        description: 'Al-Fatihah 1:1 title',
      ),
      findsOneWidget,
    );
    expect(
      find.text('English - Tafsir Ibn Kathir (Abridged)', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Urdu - Tafsir Ibn Kathir', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text(
        'تحقیقات کتاب',
        findRichText: true,
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    final urduHeading = tester.widget<SelectableText>(
      _selectableText('تحقیقات کتاب'),
    );
    expect(
      urduHeading.textSpan?.style?.fontFamily,
      AppTheme.urduFontFamily,
    );
    expect(
      find.text(
        'اردو تفسیر «ذَلِكَ»۔',
        findRichText: true,
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    final urduCommentary = tester.widget<SelectableText>(
      _selectableText('اردو تفسیر «ذَلِكَ»۔'),
    );
    final urduSpan = urduCommentary.textSpan!;
    expect(urduSpan.style?.fontFamily, AppTheme.urduFontFamily);
    final arabicQuote = urduSpan.children!
        .whereType<TextSpan>()
        .singleWhere((span) => span.text == '«ذَلِكَ»');
    expect(arabicQuote.style?.fontFamily, AppTheme.arabicFontFamily);

    await tester.tap(
      find.text(
        'English - Tafsir Ibn Kathir (Abridged)',
        skipOffstage: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Guidance is granted to Those Who have Taqwa',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Commentary body.', findRichText: true), findsOneWidget);

    final heading = tester.widget<SelectableText>(
      _selectableText('Guidance is granted to Those Who have Taqwa'),
    );
    expect(heading.textSpan?.style?.fontWeight, FontWeight.w700);

    final arabicBlock = tester.widget<SelectableText>(_selectableText('الم'));
    expect(arabicBlock.textDirection, TextDirection.rtl);
    expect(arabicBlock.textAlign, TextAlign.right);
  });
}

Finder _selectableText(String text) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is SelectableText &&
        (widget.data == text || widget.textSpan?.toPlainText() == text),
    description: 'SelectableText("$text")',
  );
}

class _FakeTafsirRepository implements TafsirRepository {
  @override
  Future<TafsirCatalogue> catalogue() async =>
      const TafsirCatalogue(resources: []);

  @override
  Future<TafsirEntry?> entryForAyah({
    required String slug,
    required int surah,
    required int ayah,
  }) async {
    if (slug == 'ur-ibn-kathir') {
      return const TafsirEntry(
        resource: 'ur-ibn-kathir',
        ayahKey: '1:1',
        groupAyahKey: '1:1',
        fromAyah: '1:1',
        toAyah: '1:1',
        ayahKeys: ['1:1'],
        text: 'تحقیقات کتاب ٭٭'
            '<div lang="ur" class="ur"><p class="ur">اردو تفسیر '
            '<span class="arabic qpc-hafs">«ذَلِكَ»</span>۔</p></div>',
      );
    }
    return const TafsirEntry(
      resource: 'en-ibn-kathir-abridged',
      ayahKey: '1:1',
      groupAyahKey: '1:1',
      fromAyah: '1:1',
      toAyah: '1:1',
      ayahKeys: ['1:1'],
      text: '<div lang="en" class="en">'
          '<h2>Guidance is granted to Those Who have Taqwa</h2></div>'
          '<p>Commentary body.</p><p>الم</p>',
    );
  }

  @override
  Future<void> install(
    TafsirCatalogueEntry entry, {
    void Function(double progress)? onProgress,
  }) async {}

  @override
  Future<List<TafsirResource>> installed() async => const [
        TafsirResource(
          slug: 'en-ibn-kathir-abridged',
          languageCode: 'en',
          name: 'Tafsir Ibn Kathir',
          nativeName: 'English',
          abridged: true,
          ayahCount: 6236,
          bytes: 512,
        ),
        TafsirResource(
          slug: 'ur-ibn-kathir',
          languageCode: 'ur',
          name: 'Tafsir Ibn Kathir',
          nativeName: 'اردو',
          direction: 'rtl',
          ayahCount: 6236,
          bytes: 512,
        ),
      ];
}
