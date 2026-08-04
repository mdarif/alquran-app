import 'package:al_quran/app.dart';
import 'package:al_quran/core/di/injector.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/reader/presentation/widgets/ayah_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _boot(WidgetTester tester) async {
  await GetIt.instance.reset();
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await configureDependencies();
  await tester.pumpWidget(const AlQuranApp());
  await tester.pumpAndSettle();
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('downloads, selects, renders, and removes a catalogue edition',
      (tester) async {
    const slug = 'en-sahih-international';

    await _boot(tester);

    await tester.tap(find.byKey(WidgetKeys.homeOverflowMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.translationsMenuButton));
    await tester.pumpAndSettle();

    await _pumpUntil(tester, find.byKey(WidgetKeys.translationsSearchField));
    await tester.enterText(
      find.byKey(WidgetKeys.translationsSearchField),
      'sahih',
    );
    await tester.pumpAndSettle();

    final download = find.byKey(WidgetKeys.editionDownload(slug));
    await _pumpUntil(tester, download);
    await tester.tap(download);
    await _pumpUntil(tester, find.byKey(WidgetKeys.editionSelected(slug)));
    expect(find.byKey(WidgetKeys.editionRemove(slug)), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.surahTile(1)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.viewportToggle));
    await tester.pumpAndSettle();

    expect(find.byType(AyahTile), findsWidgets);
    expect(find.textContaining('Sahih International'), findsWidgets);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.homeOverflowMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.translationsMenuButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(WidgetKeys.translationsSearchField),
      'sahih',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WidgetKeys.editionRemove(slug)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await _pumpUntil(tester, find.byKey(WidgetKeys.editionDownload(slug)));
  });
}
