import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/reader/presentation/pages/reader_page.dart';
import 'package:al_quran/features/reader/presentation/widgets/mushaf_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers/app_harness.dart';

/// P0 "Last Read" end-to-end flows — lock the resume behaviour we just fixed:
/// progress is recorded, and resuming returns to the SAME viewport the reader
/// left off in. (Run on a device: `patrol test -t integration_test/reader_resume_test.dart`.)
void main() {
  patrolTest('reading then leaving shows a Last Read card that resumes',
      ($) async {
    await bootstrapApp($);

    // Open Al-Baqarah and read a little (scroll the Mushaf flow).
    await $(WidgetKeys.surahTile(2)).scrollTo().tap();
    expect($(MushafView), findsOneWidget);
    await $.tester.drag(find.byType(MushafView), const Offset(0, -700));
    await $.pumpAndSettle();

    // Back to home — the Last Read card is now shown for Al-Baqarah.
    await $.tester.pageBack();
    await $.pumpAndSettle();
    expect($(WidgetKeys.lastReadCard), findsOneWidget);
    expect($('Al-Baqarah'), findsWidgets);

    // Tapping it reopens the reader.
    await $(WidgetKeys.lastReadCard).tap();
    expect($(ReaderPage), findsOneWidget);
  });

  patrolTest('resumes in Reading when you left from Reading', ($) async {
    await bootstrapApp($);
    await $(WidgetKeys.surahTile(2)).scrollTo().tap(); // opens in Reading
    expect($(MushafView), findsOneWidget);

    await $.tester.pageBack();
    await $.pumpAndSettle();
    await $(WidgetKeys.lastReadCard).tap();

    // Reading view → the Mushaf flow is present.
    expect($(MushafView), findsOneWidget);
  });

  patrolTest('resumes in Detailed when you left from Detailed', ($) async {
    await bootstrapApp($);
    await $(WidgetKeys.surahTile(2)).scrollTo().tap();
    expect($(MushafView), findsOneWidget);

    // Switch to Detailed, then leave — the resume point records Detailed.
    await $(WidgetKeys.viewportToggle).tap();
    expect($(MushafView), findsNothing);
    await $.tester.pageBack();
    await $.pumpAndSettle();

    // Resuming returns to Detailed (no Mushaf flow), not Reading.
    await $(WidgetKeys.lastReadCard).tap();
    expect($(ReaderPage), findsOneWidget);
    expect($(MushafView), findsNothing);
  });
}
