// End-to-end verification (plain integration_test, runs the REAL app on a
// device/simulator — real rendering, real SystemChrome, real
// RepaintBoundary.toImage) for the three reader-feedback changes:
//   1. scroll-driven immersion (forward scroll hides the chrome; reverse shows),
//   2. Detailed "Show Arabic" toggle (translations-only reading),
//   3. whole-page "Screenshot page" from a verse's ⋯ menu.
//
// Run on the booted iPhone simulator:
//   flutter test integration_test/reader_feedback_e2e_test.dart -d <sim-id>
import 'dart:io';

import 'package:al_quran/app.dart';
import 'package:al_quran/core/di/injector.dart';
import 'package:al_quran/core/testing/widget_keys.dart';
import 'package:al_quran/features/reader/presentation/widgets/ayah_tile.dart';
import 'package:al_quran/features/reader/presentation/widgets/mushaf_view.dart';
import 'package:al_quran/features/reader/presentation/widgets/scroll_to_top_button.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show PopupMenuButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _boot(WidgetTester tester) async {
  await GetIt.instance.reset();
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await configureDependencies();
  await tester.pumpWidget(const AlQuranApp());
  await tester.pumpAndSettle();
}

/// Top edge of the reader app bar's view-toggle button — negative once the app
/// bar has slid up out of view (immersive), >= 0 while it's shown.
double _appBarToggleTop(WidgetTester tester) =>
    tester.getRect(find.byKey(WidgetKeys.viewportToggle)).top;

/// Whether the active page's back-to-top button is set to show.
bool _scrollTopVisible(WidgetTester tester) => tester
    .widget<ScrollToTopButton>(find.byType(ScrollToTopButton).first)
    .visible;

/// The verse ⋯ menu button nearest the vertical centre — clear of the app bar
/// (top) and player bar (bottom) overlays, so the tap actually lands.
Finder _centralMoreButton(WidgetTester tester) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final mid = size.height / 2;
  Element? best;
  var bestDist = double.infinity;
  for (final e in find.byWidgetPredicate((w) => w is PopupMenuButton).evaluate()) {
    final rect = tester.getRect(find.byElementPredicate((x) => identical(x, e)));
    final dist = (rect.center.dy - mid).abs();
    if (dist < bestDist) {
      bestDist = dist;
      best = e;
    }
  }
  return find.byElementPredicate((x) => identical(x, best));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'immersion: a forward scroll hides the chrome, a reverse shows it',
      (tester) async {
    await _boot(tester);
    await tester.tap(find.byKey(WidgetKeys.surahTile(2))); // Al-Baqarah (long)
    await tester.pumpAndSettle();
    expect(find.byType(MushafView), findsOneWidget);

    // At rest: the app bar is on-screen.
    expect(_appBarToggleTop(tester), greaterThanOrEqualTo(0));

    // Swipe UP (read forward), deep enough that the back-to-top button would
    // otherwise show → the app bar slides off AND the back-to-top button stays
    // hidden (it hides with the chrome in full-screen).
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(MushafView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(
      _appBarToggleTop(tester),
      lessThan(0),
      reason: 'app bar should slide up out of view on a forward scroll',
    );
    expect(
      _scrollTopVisible(tester),
      isFalse,
      reason: 'back-to-top button hides with the chrome in full-screen',
    );

    // Swipe DOWN (reverse), still deep → the chrome comes back AND the
    // back-to-top button returns with it.
    await tester.drag(find.byType(MushafView), const Offset(0, 320));
    await tester.pumpAndSettle();
    expect(
      _appBarToggleTop(tester),
      greaterThanOrEqualTo(0),
      reason: 'app bar should return on a reverse scroll',
    );
    expect(
      _scrollTopVisible(tester),
      isTrue,
      reason: 'back-to-top button returns with the chrome while still deep',
    );
  });

  testWidgets(
      'Detailed "Show Arabic" toggle hides the matn, keeps translations',
      (tester) async {
    await _boot(tester);
    await tester.tap(find.byKey(WidgetKeys.surahTile(2)));
    await tester.pumpAndSettle();

    // Reading → Detailed.
    await tester.tap(find.byKey(WidgetKeys.viewportToggle));
    await tester.pumpAndSettle();
    expect(find.byType(AyahTile), findsWidgets);
    expect(
      find.byKey(WidgetKeys.ayahArabicText),
      findsWidgets,
      reason: 'Arabic matn shows by default in Detailed',
    );

    // Settings → turn Show Arabic off.
    await tester.tap(find.byKey(WidgetKeys.settingsButton));
    await tester.pumpAndSettle();
    expect(find.byKey(WidgetKeys.showArabicToggle), findsOneWidget);
    await tester.tap(find.byKey(WidgetKeys.showArabicToggle));
    await tester.pumpAndSettle();
    // Dismiss the sheet (tap the scrim above it) to see the verses.
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    // Arabic gone; the verses (and their translations) remain.
    expect(
      find.byKey(WidgetKeys.ayahArabicText),
      findsNothing,
      reason: 'Show Arabic off → the matn is hidden',
    );
    expect(
      find.byType(AyahTile),
      findsWidgets,
      reason: 'translations-only tiles still render',
    );
  });

  testWidgets('Detailed ⋯ menu "Screenshot page" writes a shareable PNG',
      (tester) async {
    // Clear any PNGs a prior run left in the temp dir.
    final dir = await getTemporaryDirectory();
    for (final e in dir.listSync()) {
      if (e is File && e.path.contains('alquran_page_')) e.deleteSync();
    }

    await _boot(tester);
    await tester.tap(find.byKey(WidgetKeys.surahTile(2)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.viewportToggle)); // → Detailed
    await tester.pumpAndSettle();

    // Open a verse's ⋯ menu (one near screen centre, clear of the bar overlays)
    // and pick Screenshot page.
    expect(find.byWidgetPredicate((w) => w is PopupMenuButton), findsWidgets);
    await tester.tap(_centralMoreButton(tester));
    await tester.pumpAndSettle();
    expect(find.text('Screenshot page'), findsOneWidget);
    await tester.tap(find.text('Screenshot page'));
    // Don't settle (the native share sheet is out of Flutter's control); the PNG
    // is written before the share call, so poll the temp dir for it.
    File? png;
    await tester.runAsync(() async {
      for (var i = 0; i < 25 && png == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        for (final e in dir.listSync()) {
          if (e is File &&
              e.path.contains('alquran_page_') &&
              e.path.endsWith('.png')) {
            png = e;
            break;
          }
        }
      }
    });
    expect(
      png,
      isNotNull,
      reason: 'a captured page PNG should be written',
    );
    expect(
      png!.lengthSync(),
      greaterThan(1000),
      reason: 'the PNG should be a real, non-empty capture',
    );
  });
}
