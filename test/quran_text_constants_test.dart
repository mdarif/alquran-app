import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// Guards the Qur'an text literals that are COPIED into source code against
/// drifting from the bundled DB. Al-Fatihah 1:1 exists in two encodings
/// (`text_arabic_uthmani` / `text_arabic_indopak`) and three widgets carry a
/// verbatim copy: the script-picker samples in reader_page.dart and the surah
/// Bismillah header in mushaf_view.dart. When a data fix rebuilds quran.db
/// (e.g. the 2026-07-05 bare-Allah fix) these copies do NOT update themselves —
/// this test is what fails instead of the owner's eyes in the settings sheet.
///
/// The constants are private, so the literals are extracted from the source
/// files. Byte equality is required, not just canonical equivalence: shaping
/// normalises mark order so a transposed shadda still renders, but keeping the
/// bytes identical to the DB means "diff == real difference" stays true.
void main() {
  late final String uthmani;
  late final String indopak;

  setUpAll(() {
    final db = sqlite3.open('assets/db/quran.db');
    final row = db
        .select('SELECT text_arabic_uthmani, text_arabic_indopak FROM ayahs '
            'WHERE surah_id = 1 AND ayah_number = 1')
        .single;
    uthmani = row['text_arabic_uthmani'] as String;
    indopak = row['text_arabic_indopak'] as String;
    db.close();
  });

  /// The value of `const String <name> = '…' ['…' …];` in [source], with
  /// adjacent string literals concatenated.
  String constant(String source, String name) {
    final decl = RegExp(
      "const String $name =((?:\\s*'[^']*')+);",
      multiLine: true,
    ).firstMatch(source);
    expect(decl, isNotNull, reason: '$name not found');
    return RegExp("'([^']*)'")
        .allMatches(decl!.group(1)!)
        .map((m) => m.group(1)!)
        .join();
  }

  test('script-picker samples match Al-Fatihah 1:1 in the bundled DB', () {
    final source =
        File('lib/features/reader/presentation/pages/reader_page.dart')
            .readAsStringSync();
    expect(constant(source, '_uthmaniSample'), uthmani);
    expect(constant(source, '_indopakSample'), indopak);
  });

  test('mushaf Bismillah header matches Al-Fatihah 1:1 (Uthmani)', () {
    final source =
        File('lib/features/reader/presentation/widgets/mushaf_view.dart')
            .readAsStringSync();
    expect(constant(source, '_bismillah'), uthmani);
  });
}
