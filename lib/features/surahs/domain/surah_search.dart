import 'entities/surah.dart';

/// Find-as-you-type surah matching for the Home list. Pure Dart (no Flutter /
/// Drift), so it stays testable and lives in the domain layer.
///
/// Mirrors the web reader's `quickMatch` (al-quran-web `src/pages/search.astro`):
/// normalize to bare `a–z`, strip a leading "al", and score the English name by
/// exact / prefix / substring / first-4-chars tiers — plus this app's number and
/// Arabic-name matching, and verse-reference parsing ("18:5", "kahf 5").

/// One search result: a surah, optionally with a specific verse to open at.
class SurahHit {
  const SurahHit(this.surah, [this.verse]);

  final Surah surah;

  /// A verse to jump to within [surah], or null for a whole-surah result.
  final int? verse;

  @override
  bool operator ==(Object other) =>
      other is SurahHit && other.surah == surah && other.verse == verse;

  @override
  int get hashCode => Object.hash(surah, verse);
}

/// Lowercase, then drop everything that isn't a latin letter — so "Al-Baqarah",
/// "al baqarah" and "albaqarah" all normalize to the same "albaqarah".
String _normalize(String s) {
  final buffer = StringBuffer();
  for (final ch in s.toLowerCase().codeUnits) {
    if (ch >= 0x61 && ch <= 0x7a) buffer.writeCharCode(ch); // a–z only
  }
  return buffer.toString();
}

/// Drop a leading "al" so "Baqarah" matches "Al-Baqarah".
String _stripAl(String normalized) =>
    normalized.startsWith('al') ? normalized.substring(2) : normalized;

bool _hasArabic(String s) => s.runes.any((r) => r >= 0x0600 && r <= 0x06ff);

/// Score one surah against an already-normalized latin query (0 = no match).
int _nameScore(Surah surah, String nq) {
  final ne = _normalize(surah.nameEnglish);
  final bare = _stripAl(ne);
  for (final name in [ne, bare]) {
    if (name == nq) return 100;
  }
  for (final name in [ne, bare]) {
    if (name.startsWith(nq)) return 80;
  }
  for (final name in [ne, bare]) {
    if (name.contains(nq)) return 60;
  }
  if (nq.length >= 4) {
    final head = nq.substring(0, 4);
    for (final name in [ne, bare]) {
      if (name.contains(head)) return 30;
    }
  }
  return 0;
}

/// Clamp a parsed verse to the surah's length; a verse past the end is dropped
/// (→ open the surah at the top) rather than being an invalid target.
int? _clampVerse(int? verse, Surah surah) =>
    (verse != null && verse >= 1 && verse <= surah.totalAyahs) ? verse : null;

/// The best (highest-scored) name matches, best first, then by id.
List<Surah> _byName(List<Surah> all, String nq) {
  final scored = <(Surah, int)>[];
  for (final s in all) {
    final score = _nameScore(s, nq);
    if (score > 0) scored.add((s, score));
  }
  scored.sort((a, b) {
    if (a.$2 != b.$2) return b.$2.compareTo(a.$2); // score desc
    return a.$1.id.compareTo(b.$1.id); // then natural order
  });
  return [for (final e in scored) e.$1];
}

/// Search [all] by [query], best matches first, each carrying an optional verse
/// to open at. A blank query returns every surah (no verse) in id order.
///
/// Supported queries: a name ("kahf"), a number ("18"), an Arabic name ("الكهف"),
/// a reference ("18:5" / "18.5"), or a name/number + verse ("kahf 5",
/// "surah 15 verse 5", "ya-sin 12").
List<SurahHit> searchSurahs(List<Surah> all, String query) {
  final raw = query.trim();
  if (raw.isEmpty) return [for (final s in all) SurahHit(s)];

  // Arabic query → match the Arabic name directly, preserving id order.
  if (_hasArabic(raw)) {
    return [
      for (final s in all)
        if (s.nameArabic.contains(raw)) SurahHit(s),
    ];
  }

  // A compact reference "18:5" or "18.5" → that surah + verse.
  final ref = RegExp(r'^(\d{1,3})\s*[:.]\s*(\d{1,3})$').firstMatch(raw);
  if (ref != null) {
    final surah = _byId(all, int.parse(ref.group(1)!));
    if (surah == null) return const [];
    return [SurahHit(surah, _clampVerse(int.parse(ref.group(2)!), surah))];
  }

  // A lone number → surahs whose id starts with it (exact first), no verse.
  if (RegExp(r'^\d{1,3}$').hasMatch(raw)) {
    final matches = [
      for (final s in all)
        if ('${s.id}'.startsWith(raw)) s,
    ];
    matches.sort((a, b) {
      final ae = a.id == int.parse(raw) ? 0 : 1;
      final be = b.id == int.parse(raw) ? 0 : 1;
      return ae != be ? ae - be : a.id.compareTo(b.id);
    });
    return [for (final s in matches) SurahHit(s)];
  }

  // Otherwise: pull a verse out of natural phrasing, then match the remainder
  // (a name or number) as the surah.
  var q = raw.toLowerCase();
  int? verse;

  // "verse 5", "ayah no 5", "aya 5", "v 5" …
  final vm = RegExp(
    r'\b(?:verse|ayat|ayah|aya|v)\b\s*(?:no\.?|number|#)?\s*(\d{1,3})',
  ).firstMatch(q);
  if (vm != null) {
    verse = int.parse(vm.group(1)!);
    q = q.replaceFirst(vm.group(0)!, ' ');
  }

  // Strip filler words (incl. common misspellings of "surah").
  q = q.replaceAll(
    RegExp(
      r'\b(surah|surat|sura|surha|soorah|chapter|quran|qur|holy|the|of|no|number)\b',
    ),
    ' ',
  );

  // A trailing number becomes the verse only if a name precedes it ("kahf 5").
  final tail = RegExp(r'(\d{1,3})\s*$').firstMatch(q);
  if (tail != null && verse == null && RegExp(r'[a-z]').hasMatch(q)) {
    verse = int.parse(tail.group(1)!);
    q = q.replaceFirst(RegExp(r'(\d{1,3})\s*$'), ' ');
  }

  final nq = _normalize(q);

  // Nothing but filler/number left → a bare surah number (e.g. "surah 15").
  if (nq.isEmpty) {
    final n = RegExp(r'\b(\d{1,3})\b').firstMatch(raw);
    final surah = n == null ? null : _byId(all, int.parse(n.group(1)!));
    if (surah == null) return const [];
    return [SurahHit(surah, _clampVerse(verse, surah))];
  }

  // Name match, with the extracted verse attached (clamped per surah).
  return [for (final s in _byName(all, nq)) SurahHit(s, _clampVerse(verse, s))];
}

Surah? _byId(List<Surah> all, int id) {
  for (final s in all) {
    if (s.id == id) return s;
  }
  return null;
}

/// Convenience for callers that only care about the surahs (no verse).
List<Surah> filterSurahs(List<Surah> all, String query) =>
    [for (final h in searchSurahs(all, query)) h.surah];

/// The global ayah id (1..6236, the reader's scroll target) of [verse] in
/// [surahId], computed from the full [all] surah list — the id is the running
/// ayah count of every preceding surah plus the verse number. [all] must be the
/// complete, id-ordered surah list.
int globalAyahId(List<Surah> all, int surahId, int verse) {
  var before = 0;
  for (final s in all) {
    if (s.id < surahId) before += s.totalAyahs;
  }
  return before + verse;
}
