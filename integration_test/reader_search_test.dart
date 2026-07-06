import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/reader/presentation/pages/reader_page.dart';
import 'package:al_quran/features/reader/presentation/widgets/mushaf_view.dart';
import 'package:al_quran/features/surahs/presentation/widgets/surah_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers/app_harness.dart';

/// P0 end-to-end for the Home surah search + verse-jump — the flow fixed this
/// cycle: a name/number search opens the surah, and a verse reference
/// ("muhammad 10") opens it scrolled to that exact ayah. Drives the real app
/// against the bundled DB. (Run: `patrol test -t integration_test/reader_search_test.dart`.)
void main() {
  patrolTest('the search icon opens a field and filters the list', ($) async {
    await bootstrapApp($);

    // Normal bar: no field yet.
    expect($(WidgetKeys.surahSearchField), findsNothing);
    await $(WidgetKeys.surahSearchButton).tap();

    // Search mode: the field + back arrow show.
    expect($(WidgetKeys.surahSearchField), findsOneWidget);
    expect($(WidgetKeys.surahSearchBack), findsOneWidget);

    // Typing a name narrows the list to that surah.
    await $(WidgetKeys.surahSearchField).enterText('muhammad');
    await $.pumpAndSettle();
    expect($(WidgetKeys.surahTile(47)), findsOneWidget); // Muhammad
    expect($(WidgetKeys.surahTile(1)), findsNothing); // Al-Fatihah filtered out
  });

  patrolTest('a name search opens that surah in Reading view', ($) async {
    await bootstrapApp($);

    await $(WidgetKeys.surahSearchButton).tap();
    await $(WidgetKeys.surahSearchField).enterText('muhammad');
    await $.pumpAndSettle();
    await $(WidgetKeys.surahTile(47)).tap();

    expect($(ReaderPage), findsOneWidget);
    expect($(MushafView), findsOneWidget);
    expect($('Muhammad'), findsWidgets); // the app-bar title
  });

  patrolTest('a verse reference "muhammad 10" opens scrolled to ayah 10',
      ($) async {
    await bootstrapApp($);

    // Search a verse reference and open the single hit.
    await $(WidgetKeys.surahSearchButton).tap();
    await $(WidgetKeys.surahSearchField).enterText('muhammad 10');
    await $.pumpAndSettle();
    // The result row advertises the verse it will open at.
    expect($('Ayah 10'), findsWidgets);
    await $(WidgetKeys.surahTile(47)).tap();
    expect($(MushafView), findsOneWidget);

    // The reader opened focused on ayah 10, so the resume point is recorded
    // there (not verse 1) — the deterministic verse-jump this cycle fixed. Pop
    // back and read it off the Last Read card.
    await $.tester.pageBack();
    await $.pumpAndSettle();
    expect($(WidgetKeys.lastReadCard), findsOneWidget);
    expect($('Muhammad · Ayah 10'), findsOneWidget);
  });

  patrolTest('a non-matching query shows the empty placeholder', ($) async {
    await bootstrapApp($);

    await $(WidgetKeys.surahSearchButton).tap();
    await $(WidgetKeys.surahSearchField).enterText('zzzzz');
    await $.pumpAndSettle();
    expect($(SurahTile), findsNothing);
    expect(find.textContaining('No surah matches'), findsOneWidget);
  });

  patrolTest('the back arrow exits search and restores the full list',
      ($) async {
    await bootstrapApp($);

    await $(WidgetKeys.surahSearchButton).tap();
    await $(WidgetKeys.surahSearchField).enterText('muhammad');
    await $.pumpAndSettle();
    expect($(WidgetKeys.surahTile(1)), findsNothing);

    await $(WidgetKeys.surahSearchBack).tap();
    // Back to the normal bar with the whole list (Al-Fatihah on top again).
    expect($(WidgetKeys.surahSearchField), findsNothing);
    expect($(WidgetKeys.surahTile(1)), findsOneWidget);
  });
}
