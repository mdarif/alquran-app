import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/about/presentation/pages/about_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('About surfaces the required attributions', (tester) async {
    // Tall surface so the lazy ListView builds every credit row.
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: AboutPage()));
    await tester.pumpAndSettle();

    expect(find.byKey(WidgetKeys.aboutPage), findsOneWidget);
    expect(find.text('Al Quran'), findsOneWidget);
    expect(find.textContaining('Version 1.0.0'), findsOneWidget);

    // Qur'an text + translations.
    expect(find.textContaining('KFGQPC'), findsWidgets);
    expect(find.textContaining('Junagarhi'), findsOneWidget);
    expect(find.textContaining('Suhel Farooq Khan'), findsOneWidget);
    expect(find.textContaining('Hilali'), findsOneWidget);
    expect(find.textContaining('tanzil.net'), findsWidgets);

    // Fonts + the OSS-licenses entry point.
    expect(find.text('Noorehuda (IndoPak)'), findsOneWidget);
    expect(find.textContaining('Open Font License'), findsWidgets);
    expect(find.byKey(WidgetKeys.aboutLicenses), findsOneWidget);
  });
}
