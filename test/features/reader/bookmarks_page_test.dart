import 'package:al_quran/features/reader/domain/entities/ayah.dart';
import 'package:al_quran/features/reader/domain/entities/reader_target.dart';
import 'package:al_quran/features/reader/domain/entities/surah_heading.dart';
import 'package:al_quran/features/reader/domain/entities/translation_resource.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_bookmark_repository.dart';
import 'package:al_quran/features/reader/domain/repositories/ayah_repository.dart';
import 'package:al_quran/features/reader/presentation/pages/bookmarks_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Bookmarks implements AyahBookmarkRepository {
  const _Bookmarks(this.ayahs);

  final List<Ayah> ayahs;

  @override
  Set<int> get bookmarkedAyahIds => {for (final ayah in ayahs) ayah.id};

  @override
  Future<List<Ayah>> bookmarkedAyahs() async => ayahs;

  @override
  bool isBookmarked(int ayahId) => bookmarkedAyahIds.contains(ayahId);

  @override
  Future<void> setBookmarked(int ayahId, bool bookmarked) async {}
}

class _Ayahs implements AyahRepository {
  const _Ayahs();

  @override
  Future<List<Ayah>> getAyahs(ReaderTarget target) async => const [];

  @override
  Future<Map<int, SurahHeading>> getSurahHeadings() async => const {
        2: SurahHeading(
          number: 2,
          nameEnglish: 'Al-Baqarah',
          totalAyahs: 286,
        ),
      };

  @override
  Future<List<TranslationResource>> getTranslationResources() async => const [];
}

void main() {
  testWidgets('empty bookmarks explain how to save one', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BookmarksPage(bookmarks: _Bookmarks([]), ayahs: _Ayahs()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No bookmarks yet'), findsOneWidget);
    expect(find.text('Bookmark an ayah from Detailed mode.'), findsOneWidget);
  });

  testWidgets('lists bookmarked ayahs as compact index rows', (tester) async {
    const ayah = Ayah(
      id: 8,
      surahId: 2,
      ayahNumber: 1,
      textArabic: 'الٓمٓ',
      isSajda: false,
      page: 2,
      juz: 1,
      translations: {'ur-test': 'اردو ترجمہ'},
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: BookmarksPage(bookmarks: _Bookmarks([ayah]), ayahs: _Ayahs()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ayah Bookmarks'), findsOneWidget);
    expect(find.text('Surah Al-Baqarah'), findsOneWidget);
    expect(find.text('Ayah 2:1 · Page 2 · Juz 1'), findsOneWidget);
    expect(find.text('2:1'), findsOneWidget);
    expect(find.text('الٓمٓ'), findsNothing);
    expect(find.text('اردو ترجمہ'), findsNothing);
  });
}
