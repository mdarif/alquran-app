import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/about/presentation/pages/credits_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Credits surfaces the license-required attributions + licenses',
      (tester) async {
    // Tall surface so the lazy ListView builds every credit row.
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: CreditsPage(version: '1.0.0')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(WidgetKeys.creditsPage), findsOneWidget);

    // Qur'an text + translations (Tanzil / King Fahd).
    expect(find.textContaining('KFGQPC'), findsWidgets);
    expect(find.textContaining('Junagarhi'), findsOneWidget);
    expect(find.textContaining('Suhel Farooq Khan'), findsOneWidget);
    expect(find.textContaining('Hilali'), findsOneWidget);
    expect(find.textContaining('tanzil.net'), findsWidgets);

    // Fonts + the open-source licenses entry point.
    expect(find.text('Noorehuda (IndoPak)'), findsOneWidget);
    expect(find.textContaining('Open Font License'), findsWidgets);
    expect(find.byKey(WidgetKeys.aboutLicenses), findsOneWidget);

    // Attributions link out to their sources (external-link affordance).
    expect(find.byIcon(Icons.open_in_new_rounded), findsWidgets);
  });
}
