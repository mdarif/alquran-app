import 'package:al_quran/main_arabic_diag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Smoke test for the dev-only Arabic-rendering diagnostic — proves it builds the
// whole mark matrix (both fonts, light + dark) without throwing, so
// `make diag-arabic` won't white-screen.
void main() {
  testWidgets('ArabicDiagApp renders the mark matrix in both modes',
      (tester) async {
    await tester.pumpWidget(const ArabicDiagApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Arabic diag'), findsOneWidget);
    // Section headers + both font labels are present.
    expect(find.textContaining('Harakat'), findsOneWidget);
    expect(find.text('UthmanicHafs'), findsWidgets);
    expect(find.text('Noorehuda'), findsWidgets);

    // Flip to dark (the white-vs-black reproduction) — still no exception.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
