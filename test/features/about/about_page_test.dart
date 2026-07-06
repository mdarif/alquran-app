import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/about/presentation/pages/about_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  // Phone-height surface so the whole (short) About builds, incl. the bottom link.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // About reads the real version off the platform; mock it for the test env.
    PackageInfo.setMockInitialValues(
      appName: 'Al Quran',
      packageName: 'com.almarfa.alquran',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
  });

  testWidgets('About is brand-forward; attributions are NOT inlined here',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: AboutPage()));
    await tester.pumpAndSettle();

    expect(find.byKey(WidgetKeys.aboutPage), findsOneWidget);
    expect(find.text('Al Quran'), findsOneWidget);
    expect(find.textContaining('Version 1.0.0'), findsOneWidget);
    // Exactly one company mention — the footer link; the header pill is gone.
    expect(find.text('Al Marfa Technologies'), findsOneWidget);

    // The credits + open-source licenses now live one tap deeper, on Credits.
    expect(find.byKey(WidgetKeys.aboutCredits), findsOneWidget);
    expect(find.byKey(WidgetKeys.aboutLicenses), findsNothing);
    expect(find.textContaining('tanzil.net'), findsNothing);
    expect(find.textContaining('Junagarhi'), findsNothing);
  });

  testWidgets('the Licenses & credits link opens the Credits screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: AboutPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WidgetKeys.aboutCredits));
    await tester.pumpAndSettle();

    expect(find.byKey(WidgetKeys.creditsPage), findsOneWidget);
    expect(find.textContaining('tanzil.net'), findsWidgets);
  });
}
