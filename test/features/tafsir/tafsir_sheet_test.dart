import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_catalogue_entry.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_entry.dart';
import 'package:al_quran/features/tafsir/domain/entities/tafsir_resource.dart';
import 'package:al_quran/features/tafsir/domain/repositories/tafsir_repository.dart';
import 'package:al_quran/features/tafsir/presentation/cubit/tafsir_cubit.dart';
import 'package:al_quran/features/tafsir/presentation/tafsir_sheet.dart';
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
      find.text(
        'Guidance is granted to Those Who have Taqwa',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Commentary body.', findRichText: true), findsOneWidget);

    final heading = tester.widget<RichText>(
      find.text(
        'Guidance is granted to Those Who have Taqwa',
        findRichText: true,
      ),
    );
    expect(heading.text.style?.fontWeight, FontWeight.w700);

    final arabicQuote = tester.widget<Text>(find.text('الم'));
    expect(arabicQuote.textDirection, TextDirection.rtl);
    expect(arabicQuote.textAlign, TextAlign.right);
  });
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
  }) async =>
      const TafsirEntry(
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
      ];
}
