import 'package:al_quran/core/theme/mushaf_palette.dart';
import 'package:al_quran/core/theme/prayer_phase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = DateTime(2026, 6, 23);
  DateTime at(int h, [int m = 0]) => base.add(Duration(hours: h, minutes: m));

  final fajr = at(4, 30);
  final sunrise = at(6);
  final asr = at(15, 30);
  final maghrib = at(18, 45);
  final isha = at(20, 15);

  DayPhase phaseAt(DateTime now) => phaseForBoundaries(
        fajr: fajr,
        sunrise: sunrise,
        asr: asr,
        maghrib: maghrib,
        isha: isha,
        now: now,
      );

  test('maps each prayer window to its surface', () {
    expect(phaseAt(at(3)), DayPhase.isha); // pre-dawn = night
    expect(phaseAt(at(5)), DayPhase.fajr); // Fajr → Sunrise
    expect(phaseAt(at(10)), DayPhase.duha); // Sunrise → Asr (incl. Dhuhr)
    expect(phaseAt(at(16)), DayPhase.asr); // Asr → Maghrib
    expect(phaseAt(at(19)), DayPhase.maghrib); // Maghrib → Isha
    expect(phaseAt(at(22)), DayPhase.isha); // after Isha = night
  });

  test('a boundary belongs to the window it opens', () {
    expect(phaseAt(fajr), DayPhase.fajr);
    expect(phaseAt(sunrise), DayPhase.duha);
    expect(phaseAt(asr), DayPhase.asr);
    expect(phaseAt(maghrib), DayPhase.maghrib);
    expect(phaseAt(isha), DayPhase.isha);
  });
}
