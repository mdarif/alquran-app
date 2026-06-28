import 'package:al_quran/core/feature_flags.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/reader/presentation/widgets/mushaf_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers/app_harness.dart';

/// P0/P1 reader interactions: peek-card dismiss and swipe navigation between
/// surahs. (Run on a device: `patrol test -t integration_test/reader_interactions_test.dart`.)
void main() {
  patrolTest('the peek card toggles off when the same verse is tapped again',
      ($) async {
    await bootstrapApp($);
    await $(WidgetKeys.surahTile(1)).tap(); // Al-Fatihah
    expect($(MushafView), findsOneWidget);

    // Tap a verse → peek card appears.
    await $(MushafView).tap();
    expect($(WidgetKeys.peekCard), findsOneWidget);

    // Tap the same verse again → it dismisses.
    await $(MushafView).tap();
    await $.pumpAndSettle();
    expect($(WidgetKeys.peekCard), findsNothing);
  });

  patrolTest('swiping left advances to the next surah', ($) async {
    await bootstrapApp($);
    await $(WidgetKeys.surahTile(1)).tap(); // Al-Fatihah
    expect($(MushafView), findsOneWidget);

    // A horizontal fling moves to the adjacent (next) section.
    await $.tester.fling(
      find.byType(MushafView),
      const Offset(-400, 0),
      1000,
    );
    await $.pumpAndSettle();

    // Al-Baqarah (surah 2) is now shown.
    expect($('Al-Baqarah'), findsWidgets);
  });

  patrolTest('the Uthmani/IndoPak script toggle switches the reader and back',
      ($) async {
    if (!FeatureFlags.indopakScript) return; // feature shipped dark
    await bootstrapApp($);
    await $(WidgetKeys.surahTile(2)).tap(); // Al-Baqarah
    expect($(MushafView), findsOneWidget);

    // The script switch lives inside the Settings sheet.
    await $(WidgetKeys.settingsButton).tap();
    expect($(WidgetKeys.scriptToggle), findsOneWidget);

    // Switch to IndoPak, then back to Uthmani — the reader stays stable and the
    // current section keeps rendering.
    await $('IndoPak').tap();
    await $.pumpAndSettle();
    expect($(MushafView), findsOneWidget);

    await $('Uthmani').tap();
    await $.pumpAndSettle();
    expect($(MushafView), findsOneWidget);
  });
}
