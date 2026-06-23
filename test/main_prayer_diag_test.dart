import 'package:al_quran/main_prayer_diag.dart';
import 'package:flutter_test/flutter_test.dart';

// Smoke test for the dev-only preview screen — proves it renders every state
// (incl. the gold forbidden pill + sheet "No prayer" marks) without throwing, so
// `make diag-prayer` won't white-screen.
void main() {
  testWidgets('PrayerDiagApp renders all states', (tester) async {
    await tester.pumpWidget(const PrayerDiagApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Prayer-times diag'), findsOneWidget);
    expect(find.textContaining('Forbidden'), findsWidgets); // pill states
    expect(find.textContaining('No prayer'), findsWidgets); // sheet markers
    expect(find.text('Sunrise'), findsWidgets);
  });
}
