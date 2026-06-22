import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/reader/presentation/pages/reader_page.dart';
import 'package:al_quran/features/reader/presentation/widgets/mushaf_view.dart';
import 'package:al_quran/features/surahs/presentation/widgets/surah_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers/app_harness.dart';

/// P0 end-to-end happy paths: the app launches against the real bundled DB, the
/// surah list opens a surah in Reading view, and a verse tap reveals the
/// translation peek card. (Run: `patrol test -t integration_test/reader_flow_test.dart`.)
void main() {
  patrolTest('launches to the surah list with all 114 chapters', ($) async {
    await bootstrapApp($);

    // The immersive surah list is the home; Al-Fatihah (1) is at the top.
    expect($(SurahTile), findsWidgets);
    expect($('Al-Fatihah'), findsWidgets);
    // The last chapter, An-Nas (114), is reachable by scrolling the list.
    await $(WidgetKeys.surahTile(114)).scrollTo();
    expect($(WidgetKeys.surahTile(114)), findsOneWidget);
  });

  patrolTest('tapping a surah opens it in Reading (Mushaf) view', ($) async {
    await bootstrapApp($);

    await $(WidgetKeys.surahTile(2)).scrollTo().tap(); // Al-Baqarah
    expect($(ReaderPage), findsOneWidget);
    expect($(MushafView), findsOneWidget); // Reading view, not Detailed
  });

  patrolTest('tapping a verse reveals the translation peek card', ($) async {
    await bootstrapApp($);
    await $(WidgetKeys.surahTile(1)).tap(); // Al-Fatihah
    expect($(MushafView), findsOneWidget);

    // Tap the Arabic flow — the peek card slides up with the translation.
    await $(MushafView).tap();
    expect($(WidgetKeys.peekCard), findsOneWidget);
  });

  patrolTest('switching to Detailed view shows stacked translations',
      ($) async {
    await bootstrapApp($);
    await $(WidgetKeys.surahTile(1)).tap(); // Al-Fatihah
    expect($(MushafView), findsOneWidget);

    // Toggle Reading -> Detailed; the Mushaf flow is replaced by the tile list.
    await $(WidgetKeys.viewportToggle).tap();
    expect($(MushafView), findsNothing);
  });
}
