import 'package:al_quran/core/data/surah_meanings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('has exactly 114 entries, one per surah id 1..114', () {
    expect(surahMeanings, hasLength(114));
    expect(surahMeanings.keys.toSet(), Set.of(List.generate(114, (i) => i + 1)));
  });

  test('no entry is blank', () {
    for (final entry in surahMeanings.entries) {
      expect(
        entry.value.trim(),
        isNotEmpty,
        reason: 'surah ${entry.key} has a blank meaning',
      );
    }
  });

  test('matches the quran.com API wording for known reference surahs', () {
    // Regression guard for the earlier "The Originator" vs quran.com's
    // "Originator" mismatch — pin a few well-known ids to the exact
    // translated_name.name values from api.quran.com/api/v4/chapters.
    expect(surahMeanings[1], 'The Opener');
    expect(surahMeanings[35], 'Originator');
    expect(surahMeanings[40], 'The Forgiver');
    expect(surahMeanings[112], 'The Sincerity');
    expect(surahMeanings[114], 'Mankind');
  });
}
