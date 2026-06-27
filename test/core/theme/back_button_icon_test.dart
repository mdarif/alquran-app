import 'dart:async';

import 'package:al_quran/core/theme/app_icons.dart';
import 'package:al_quran/core/theme/mushaf_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'AppBar back button uses the app icon family (not the platform '
      'default)', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        theme: MushafPalette.of(DayPhase.duha).toTheme(),
        home: const Scaffold(body: Text('home')),
      ),
    );

    // Push a route with an AppBar → Flutter implies the leading back button.
    unawaited(
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(appBar: AppBar(title: const Text('inner'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.back), findsOneWidget);
    // And the old platform chevron is gone.
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
  });
}
