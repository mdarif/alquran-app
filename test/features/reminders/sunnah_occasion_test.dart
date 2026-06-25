import 'package:al_quran/features/reminders/presentation/sunnah_occasion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('names the occasion on a special date, null otherwise', () {
    // 2026-06-25 is 9 Muharram → Ashura; 2026-06-24 is 8 Muharram → ordinary.
    expect(sunnahOccasionName(DateTime(2026, 6, 25)), 'Ashura');
    expect(sunnahOccasionName(DateTime(2026, 6, 24)), isNull);
  });
}
